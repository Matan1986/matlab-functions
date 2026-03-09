function out = diagnose_deltaM_svd_pca()
% diagnose_deltaM_svd_pca
% Diagnostics-only SVD/PCA audit of DeltaM curve families.
% Does not modify pipeline metrics or reconstruction code.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('aging', 'svd_pca');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

datasets = {
    'MG119_3sec',  '3 s',   3;
    'MG119_36sec', '36 s',  36;
    'MG119_6min',  '6 min', 360;
    'MG119_60min', '60 min', 3600
};

curves = struct('wait_time', {}, 'wait_seconds', {}, 'Tp', {}, 'T', {}, 'dM', {});

for d = 1:size(datasets, 1)
    datasetKey = datasets{d,1};
    waitLabel = datasets{d,2};
    waitSec = datasets{d,3};

    cfg = agingConfig(datasetKey);
    cfg.doPlotting = false;
    cfg.saveTableMode = 'none';
    if isfield(cfg, 'debug') && isstruct(cfg.debug)
        cfg.debug.enable = false;
        cfg.debug.plotGeometry = false;
        cfg.debug.plotSwitching = false;
        cfg.debug.saveOutputs = false;
    end

    cfg = stage0_setupPaths(cfg);
    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);

    pauseRuns = getPauseRuns(state);
    for i = 1:numel(pauseRuns)
        Tp = getScalarOrNaN(pauseRuns(i), 'waitK');
        [T, dM] = extractDeltaMCurve(pauseRuns(i));
        n = min(numel(T), numel(dM));
        if n < 10 || ~isfinite(Tp)
            continue;
        end
        T = T(1:n);
        dM = dM(1:n);
        valid = isfinite(T) & isfinite(dM);
        if nnz(valid) < 10
            continue;
        end
        T = T(valid);
        dM = dM(valid);

        c.wait_time = string(waitLabel);
        c.wait_seconds = waitSec;
        c.Tp = Tp;
        c.T = T(:);
        c.dM = dM(:);
        curves(end+1) = c; %#ok<AGROW>
    end
end

assert(~isempty(curves), 'No valid DeltaM curves were collected for SVD/PCA diagnostics.');

allT = {curves.T};
alldM = {curves.dM};
meta = struct();
meta.wait_time = string({curves.wait_time})';
meta.wait_seconds = [curves.wait_seconds]';
meta.Tp = [curves.Tp]';
meta.curve_index = (1:numel(curves))';

% VERSION A: raw T coordinate
Tgrid = buildCommonGrid(allT);
Xraw = interpolateMatrix(allT, alldM, Tgrid);
rawRes = analyzeMatrix(Xraw, Tgrid, meta, "raw_T", outDir);

% VERSION B: shifted coordinate x = T - Tp
xCells = cell(size(allT));
for i = 1:numel(allT)
    xCells{i} = allT{i} - meta.Tp(i);
end
xGrid = buildCommonGrid(xCells);
Xshift = interpolateMatrix(xCells, alldM, xGrid);
shiftRes = analyzeMatrix(Xshift, xGrid, meta, "shifted_Tp", outDir);

% Save CSV summaries
svdTbl = [rawRes.svdTable; shiftRes.svdTable]; %#ok<NASGU>
coeffTbl = [rawRes.coeffTable; shiftRes.coeffTable]; %#ok<NASGU>

svdCsv = fullfile(outDir, 'svd_summary.csv');
coeffCsv = fullfile(outDir, 'curve_mode_coefficients.csv');
writetable([rawRes.svdTable; shiftRes.svdTable], svdCsv);
writetable([rawRes.coeffTable; shiftRes.coeffTable], coeffCsv);

% Interpretation summary
summaryTxt = buildInterpretationSummary(rawRes, shiftRes);
summaryPath = fullfile(outDir, 'interpretation_summary.txt');
writeText(summaryPath, summaryTxt);

fprintf('\n=== DeltaM SVD/PCA summary ===\n');
fprintf('%s\n', summaryTxt);
fprintf('Saved: %s\n', svdCsv);
fprintf('Saved: %s\n', coeffCsv);
fprintf('Saved: %s\n', summaryPath);

out = struct('raw', rawRes, 'shifted', shiftRes, 'outDir', outDir);
end

function res = analyzeMatrix(X, axisGrid, meta, matrixName, outDir)
% Keep only rows that are fully finite on common grid.
rowValid = all(isfinite(X), 2);
Xv = X(rowValid, :);
if isempty(Xv)
    error('Matrix %s has no fully-finite rows after interpolation.', matrixName);
end

metaV.wait_time = meta.wait_time(rowValid);
metaV.wait_seconds = meta.wait_seconds(rowValid);
metaV.Tp = meta.Tp(rowValid);
metaV.curve_index = meta.curve_index(rowValid);

% Row-centering for PCA clarity.
rowMean = mean(Xv, 2, 'omitnan');
Xc = Xv - rowMean;

[U, S, V] = svd(Xc, 'econ');
s = diag(S);
varRatio = (s.^2) ./ (sum(s.^2) + eps);
cumRatio = cumsum(varRatio);

nModes = min(3, numel(s));
score = U(:,1:nModes) .* (s(1:nModes)');

% Reconstructions in original (un-centered) space.
err1 = reconstructionError(Xv, U, S, V, rowMean, 1);
err2 = reconstructionError(Xv, U, S, V, rowMean, min(2, nModes));
err3 = reconstructionError(Xv, U, S, V, rowMean, nModes);

coeff = nan(size(Xv,1), 3);
coeff(:,1:nModes) = score;

res.svdTable = table( ...
    repmat(string(matrixName), numel(s), 1), ...
    (1:numel(s))', s, varRatio, cumRatio, ...
    'VariableNames', {'matrix_name','singular_index','singular_value','explained_variance_ratio','cumulative_variance_ratio'});

res.coeffTable = table( ...
    metaV.wait_time, metaV.Tp, repmat(string(matrixName), numel(metaV.Tp), 1), ...
    coeff(:,1), coeff(:,2), coeff(:,3), ...
    err1, err2, err3, ...
    'VariableNames', {'wait_time','Tp','matrix_name','coeff_mode1','coeff_mode2','coeff_mode3', ...
                      'reconstruction_error_rank1','reconstruction_error_rank2','reconstruction_error_rank3'});

res.s = s;
res.varRatio = varRatio;
res.cumRatio = cumRatio;
res.U = U;
res.S = S;
res.V = V;
res.X = Xv;
res.rowMean = rowMean;
res.meta = metaV;
res.axisGrid = axisGrid(:);
res.matrixName = string(matrixName);

% Figures
makeScreeFigure(res, outDir);
makeScoreFigure(res, outDir);
makeModeFigure(res, outDir);
makeReconstructionFigure(res, outDir);
makeHeatmapFigure(res, outDir);
end

function e = reconstructionError(X, U, S, V, rowMean, k)
if k < 1
    e = sqrt(mean((X - rowMean).^2, 2, 'omitnan'));
    return;
end
Xhat = U(:,1:k) * S(1:k,1:k) * V(:,1:k)' + rowMean;
e = sqrt(mean((X - Xhat).^2, 2, 'omitnan'));
end

function makeScreeFigure(res, outDir)
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 1400 430]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

s = res.s(:);
vr = res.varRatio(:);
cr = res.cumRatio(:);
idx = (1:numel(s))';

nexttile;
plot(idx, s, 'o-', 'LineWidth', 1.6, 'MarkerSize', 6);
grid on;
xlabel('Mode index'); ylabel('Singular value');
title(sprintf('%s: singular values', res.matrixName), 'Interpreter', 'none');

nexttile;
bar(idx, vr, 'FaceColor', [0.2 0.5 0.85], 'EdgeColor', 'none');
grid on;
xlabel('Mode index'); ylabel('Explained variance ratio');
title('Explained variance ratio');

nexttile;
plot(idx, cr, 's-', 'LineWidth', 1.6, 'MarkerSize', 6, 'Color', [0.85 0.33 0.10]); hold on;
yline(0.9, ':k', '90%', 'LabelHorizontalAlignment', 'left');
yline(0.95, ':k', '95%', 'LabelHorizontalAlignment', 'left');
grid on;
xlabel('Mode index'); ylabel('Cumulative explained variance');
title('Cumulative explained variance');

sgtitle(sprintf('SVD Scree | %s', res.matrixName), 'Interpreter', 'none');
outPng = fullfile(outDir, sprintf('scree_%s.png', res.matrixName));
saveas(figH, outPng);
close(figH);
end

function makeScoreFigure(res, outDir)
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 1250 500]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

waitCats = unique(res.meta.wait_time, 'stable');
cols = lines(numel(waitCats));
score = zeros(size(res.meta.Tp,1), 3);
score(:,1:min(3,size(res.U,2))) = res.U(:,1:min(3,size(res.U,2))) .* (diag(res.S(1:min(3,size(res.S,1)),1:min(3,size(res.S,2))))');

pairs = [1 2; 1 3];
for p = 1:2
    nexttile;
    hold on;
    for w = 1:numel(waitCats)
        mask = res.meta.wait_time == waitCats(w);
        scatter(score(mask, pairs(p,1)), score(mask, pairs(p,2)), 36, cols(w,:), 'filled', ...
            'DisplayName', char(waitCats(w)));

        tpVals = res.meta.Tp(mask);
        sx = score(mask, pairs(p,1));
        sy = score(mask, pairs(p,2));
        for j = 1:numel(tpVals)
            text(sx(j), sy(j), sprintf(' %.0f', tpVals(j)), 'FontSize', 7, 'Color', cols(w,:));
        end
    end
    grid on;
    xlabel(sprintf('Score mode %d', pairs(p,1)));
    ylabel(sprintf('Score mode %d', pairs(p,2)));
    title(sprintf('%s: scores (%d vs %d)', res.matrixName, pairs(p,1), pairs(p,2)), 'Interpreter', 'none');
end
lg = legend('Location', 'bestoutside');
lg.FontSize = 9;
lg.Box = 'off';

outPng = fullfile(outDir, sprintf('scores_%s.png', res.matrixName));
saveas(figH, outPng);
close(figH);
end

function makeModeFigure(res, outDir)
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1100 460]);
axisVec = res.axisGrid(:);

h = gobjects(0);
l = {};
for k = 1:min(3, size(res.V,2))
    h(end+1) = plot(axisVec, res.V(:,k), 'LineWidth', 1.8); hold on; %#ok<AGROW>
    l{end+1} = sprintf('Mode %d', k); %#ok<AGROW>
end

if res.matrixName == "raw_T"
    xlabel('T (K)');
else
    xlabel('x = T - T_p (K)');
end
ylabel('Right singular vector amplitude');
grid on;
title(sprintf('First 3 right singular vectors | %s', res.matrixName), 'Interpreter', 'none');
lg = legend(h, l, 'Location', 'bestoutside');
lg.FontSize = 9;
lg.Box = 'off';

outPng = fullfile(outDir, sprintf('modes_%s.png', res.matrixName));
saveas(figH, outPng);
close(figH);
end

function makeReconstructionFigure(res, outDir)
idxRep = pickRepresentativeCurves(res.meta.wait_time, res.meta.Tp);
if isempty(idxRep)
    return;
end

nRep = numel(idxRep);
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [60 60 1450 max(420, 280*nRep)]);
tiledlayout(nRep, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

axisVec = res.axisGrid(:)';

for ii = 1:nRep
    i = idxRep(ii);
    x = res.X(i,:);
    r1 = reconstructRow(res, i, 1);
    r2 = reconstructRow(res, i, min(2, size(res.U,2)));
    r3 = reconstructRow(res, i, min(3, size(res.U,2)));

    nexttile;
    plot(axisVec, x, 'k-', 'LineWidth', 1.3, 'DisplayName', 'original'); hold on;
    plot(axisVec, r1, '-', 'Color', [0.2 0.5 0.85], 'LineWidth', 1.2, 'DisplayName', 'rank-1');
    plot(axisVec, r2, '-', 'Color', [0.1 0.6 0.1], 'LineWidth', 1.2, 'DisplayName', 'rank-2');
    plot(axisVec, r3, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2, 'DisplayName', 'rank-3');
    grid on;

    if res.matrixName == "raw_T"
        xlabel('T (K)');
    else
        xlabel('x = T - T_p (K)');
    end
    ylabel('\Delta M');
    title(sprintf('%s | wait=%s | T_p=%.0f K', res.matrixName, res.meta.wait_time(i), res.meta.Tp(i)), 'Interpreter', 'none');

    if ii == 1
        lg = legend('Location', 'bestoutside');
        lg.FontSize = 9;
        lg.Box = 'off';
    end
end

outPng = fullfile(outDir, sprintf('recon_examples_%s.png', res.matrixName));
saveas(figH, outPng);
close(figH);
end

function makeHeatmapFigure(res, outDir)
waitCats = unique(res.meta.wait_time, 'stable');
TpVals = unique(res.meta.Tp(isfinite(res.meta.Tp)));
TpVals = sort(TpVals(:)');

score = zeros(size(res.meta.Tp,1), 3);
score(:,1:min(3,size(res.U,2))) = res.U(:,1:min(3,size(res.U,2))) .* (diag(res.S(1:min(3,size(res.S,1)),1:min(3,size(res.S,2))))');

figH = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 1350 560]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for k = 1:3
    M = nan(numel(waitCats), numel(TpVals));
    for i = 1:numel(waitCats)
        for j = 1:numel(TpVals)
            mask = (res.meta.wait_time == waitCats(i)) & (abs(res.meta.Tp - TpVals(j)) < 1e-6);
            if any(mask)
                M(i,j) = mean(score(mask, min(k, size(score,2))), 'omitnan');
            end
        end
    end

    nexttile;
    imagesc(TpVals, 1:numel(waitCats), M);
    set(gca, 'YTick', 1:numel(waitCats), 'YTickLabel', cellstr(waitCats));
    xlabel('T_p (K)');
    ylabel('wait time');
    title(sprintf('%s: coeff mode %d', res.matrixName, k), 'Interpreter', 'none');
    colormap(gca, parula);
    colorbar;
end

outPng = fullfile(outDir, sprintf('coeff_heatmap_%s.png', res.matrixName));
saveas(figH, outPng);
close(figH);
end

function y = reconstructRow(res, rowIdx, k)
Xhat = res.U(:,1:k) * res.S(1:k,1:k) * res.V(:,1:k)' + res.rowMean;
y = Xhat(rowIdx,:);
end

function idxRep = pickRepresentativeCurves(waitTime, Tp)
idxRep = [];
waitCats = unique(waitTime, 'stable');
for i = 1:numel(waitCats)
    mask = waitTime == waitCats(i);
    if ~any(mask)
        continue;
    end
    idx = find(mask);
    tpLoc = Tp(mask);

    [~, jMin] = min(tpLoc);
    [~, jMax] = max(tpLoc);

    idxRep(end+1) = idx(jMin); %#ok<AGROW>
    if idx(jMax) ~= idx(jMin)
        idxRep(end+1) = idx(jMax); %#ok<AGROW>
    end
end
idxRep = unique(idxRep, 'stable');
end

function summary = buildInterpretationSummary(rawRes, shiftRes)
r1_raw = getVarAt(rawRes.cumRatio, 1);
r2_raw = getVarAt(rawRes.cumRatio, 2);
r1_shift = getVarAt(shiftRes.cumRatio, 1);
r2_shift = getVarAt(shiftRes.cumRatio, 2);

imp_raw = median((rawRes.coeffTable.reconstruction_error_rank1 - rawRes.coeffTable.reconstruction_error_rank2) ./ ...
    max(rawRes.coeffTable.reconstruction_error_rank1, eps), 'omitnan');
imp_shift = median((shiftRes.coeffTable.reconstruction_error_rank1 - shiftRes.coeffTable.reconstruction_error_rank2) ./ ...
    max(shiftRes.coeffTable.reconstruction_error_rank1, eps), 'omitnan');

rank1_raw_flag = tf(r1_raw >= 0.8);
rank1_shift_flag = tf(r1_shift >= 0.8);
rank2_raw_flag = tf((r2_raw - r1_raw) >= 0.1);
rank2_shift_flag = tf((r2_shift - r1_shift) >= 0.1);

[interpRaw, interpShift] = modeInterpretabilityHeuristic(rawRes, shiftRes);

lines = [
    sprintf('raw_T: rank-1 variance=%.4f, rank-2 cumulative variance=%.4f', r1_raw, r2_raw)
    sprintf('shifted_Tp: rank-1 variance=%.4f, rank-2 cumulative variance=%.4f', r1_shift, r2_shift)
    sprintf('rank-1 dominant? raw=%s, shifted=%s', rank1_raw_flag, rank1_shift_flag)
    sprintf('rank-2 major incremental gain? raw=%s, shifted=%s', rank2_raw_flag, rank2_shift_flag)
    sprintf('median reconstruction improvement rank2 vs rank1: raw=%.4f, shifted=%.4f', imp_raw, imp_shift)
    sprintf('mode interpretability heuristic (raw_T): %s', interpRaw)
    sprintf('mode interpretability heuristic (shifted_Tp): %s', interpShift)
    sprintf('shifted-coordinate low-rank advantage (rank-2 cumulative): delta=%.4f', r2_shift - r2_raw)
    "Visual confirmation: inspect mode and reconstruction plots for dip-like + broad-like separation."
    ];
summary = strjoin(cellstr(lines), newline);
end

function [rawTxt, shiftTxt] = modeInterpretabilityHeuristic(rawRes, shiftRes)
rawTxt = classifyFirstTwoModes(rawRes.V, rawRes.axisGrid, false);
shiftTxt = classifyFirstTwoModes(shiftRes.V, shiftRes.axisGrid, true);
end

function txt = classifyFirstTwoModes(V, axisGrid, isShifted)
if size(V,2) < 2
    txt = 'insufficient modes';
    return;
end

m1 = V(:,1);
m2 = V(:,2);

if isShifted
    dip1 = isDipLike(m1, axisGrid);
    dip2 = isDipLike(m2, axisGrid);
    broad1 = isBroadLike(m1, axisGrid);
    broad2 = isBroadLike(m2, axisGrid);
else
    dip1 = hasLocalizedExtremum(m1);
    dip2 = hasLocalizedExtremum(m2);
    broad1 = isBroadLike(m1, axisGrid);
    broad2 = isBroadLike(m2, axisGrid);
end

txt = sprintf('mode1(dip=%s,broad=%s), mode2(dip=%s,broad=%s)', ...
    tf(dip1), tf(broad1), tf(dip2), tf(broad2));
end

function flag = isDipLike(v, axisGrid)
centerMask = isfinite(axisGrid) & abs(axisGrid) <= 8;
if ~any(centerMask)
    flag = false;
    return;
end
v = v(:);
energyAll = sum(v.^2);
energyCenter = sum(v(centerMask).^2);
[~, imax] = max(abs(v));
peakNearZero = abs(axisGrid(imax)) <= 6;
flag = peakNearZero && (energyCenter / (energyAll + eps) >= 0.45);
end

function flag = isBroadLike(v, axisGrid)
v = v(:);
ax = axisGrid(:);
valid = isfinite(v) & isfinite(ax);
if nnz(valid) < 5
    flag = false;
    return;
end
r = corr(v(valid), ax(valid), 'type', 'Pearson');
zc = sum(abs(diff(sign(v(valid)))) > 0);
flag = (abs(r) >= 0.45) || (zc <= 2);
end

function flag = hasLocalizedExtremum(v)
v = abs(v(:));
if numel(v) < 5
    flag = false;
    return;
end
[~, imax] = max(v);
mid = (numel(v)+1)/2;
flag = abs(imax - mid) <= 0.3*numel(v);
end

function g = buildCommonGrid(axisCells)
mins = nan(numel(axisCells),1);
maxs = nan(numel(axisCells),1);
steps = nan(numel(axisCells),1);
for i = 1:numel(axisCells)
    a = axisCells{i}(:);
    a = a(isfinite(a));
    if numel(a) < 3
        continue;
    end
    mins(i) = min(a);
    maxs(i) = max(a);
    da = diff(a);
    da = da(isfinite(da) & da > 0);
    if ~isempty(da)
        steps(i) = median(da);
    end
end

gMin = max(mins, [], 'omitnan');
gMax = min(maxs, [], 'omitnan');
dx = median(steps, 'omitnan');
if ~isfinite(dx) || dx <= 0
    dx = 0.1;
end
if ~isfinite(gMin) || ~isfinite(gMax) || gMax <= gMin
    error('Failed to build common grid for SVD/PCA diagnostics.');
end

g = (gMin:dx:gMax)';
if numel(g) < 20
    g = linspace(gMin, gMax, 200)';
end
end

function X = interpolateMatrix(axisCells, yCells, grid)
N = numel(axisCells);
M = numel(grid);
X = nan(N, M);
for i = 1:N
    x = axisCells{i}(:);
    y = yCells{i}(:);
    n = min(numel(x), numel(y));
    x = x(1:n);
    y = y(1:n);
    valid = isfinite(x) & isfinite(y);
    x = x(valid);
    y = y(valid);
    if numel(x) < 2
        continue;
    end
    [x, iu] = unique(x);
    y = y(iu);
    X(i,:) = interp1(x, y, grid, 'pchip', NaN);
end
end

function [T, dM] = extractDeltaMCurve(pr)
T = [];
dM = [];
if isfield(pr, 'T_common') && ~isempty(pr.T_common)
    T = pr.T_common(:);
elseif isfield(pr, 'T') && ~isempty(pr.T)
    T = pr.T(:);
end

if isfield(pr, 'DeltaM_aligned') && ~isempty(pr.DeltaM_aligned)
    dM = pr.DeltaM_aligned(:);
elseif isfield(pr, 'DeltaM') && ~isempty(pr.DeltaM)
    dM = pr.DeltaM(:);
end
end

function v = getScalarOrNaN(s, fieldName)
v = NaN;
if isfield(s, fieldName)
    x = s.(fieldName);
    if ~isempty(x) && isscalar(x) && isfinite(x)
        v = x;
    end
end
end

function v = getVarAt(cumRatio, k)
if numel(cumRatio) >= k && isfinite(cumRatio(k))
    v = cumRatio(k);
else
    v = NaN;
end
end

function s = tf(flag)
if flag
    s = 'yes';
else
    s = 'no';
end
end

function writeText(filePath, txt)
fid = fopen(filePath, 'w');
assert(fid >= 0, 'Failed to open summary file for writing: %s', filePath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', txt);
end

