function out = analyze_relaxation_derivative_smoothing(dataDir, cfg)
% analyze_relaxation_derivative_smoothing
% Diagnostics-only smoothing and derivative comparison for Relaxation TRM.

if nargin < 1 || isempty(dataDir)
    dataDir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";
end
if nargin < 2
    cfg = struct();
end

cfg = setDef(cfg, 'normalizeByMass', true);
cfg = setDef(cfg, 'convertToMuBCo', true);
cfg = setDef(cfg, 'hThresh', 0.5);
cfg = setDef(cfg, 'nLogGrid', 360);
cfg = setDef(cfg, 'clipPrct', [5 95]);
cfg = setDef(cfg, 'minPostPts', 120);
cfg = setDef(cfg, 'minPostDuration_s', 200);
cfg = setDef(cfg, 'sgolayOrder', 3);
cfg = setDef(cfg, 'sgolayDecades', [0.10 0.20]);
cfg = setDef(cfg, 'gaussSigmaT_steps', 1.0);
cfg = setDef(cfg, 'gaussSigmaLog_dec', 0.12);
cfg = setDef(cfg, 'repQuantiles', [0.20 0.55 0.85]);

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
[outDir, run] = init_run_output_dir(repoRoot, 'relaxation', 'derivative_smoothing', dataDir); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

[fileList, ~, ~, ~, ~, ~] = getFileList_relaxation(char(dataDir), 'parula');
[Time_table, Temp_table, Field_table, Moment_table, ~] = ...
    importFiles_relaxation(char(dataDir), fileList, cfg.normalizeByMass, false);

if cfg.convertToMuBCo
    x_Co = 1/3;
    m_mol = 58.9332/3 + 180.948 + 2*32.066;
    muB = 9.274e-21;
    NA  = 6.022e23;
    convFactor = m_mol / (NA * muB * x_Co);
    for i = 1:numel(Moment_table)
        if ~isempty(Moment_table{i})
            Moment_table{i} = Moment_table{i} * convFactor;
        end
    end
end

nCurves = numel(Time_table);
rawRows = repmat(emptyRawRow(), nCurves, 1);
curve = repmat(emptyCurveStruct(), nCurves, 1);

for i = 1:nCurves
    t = Time_table{i};
    m = Moment_table{i};
    if i <= numel(Field_table)
        h = Field_table{i};
    else
        h = [];
    end

    Tnom = parseNominalTemp(fileList{i}, Temp_table{i});
    [t, m, h] = cleanAligned(t, m, h);
    if numel(t) < 30
        continue;
    end

    [idx0, t0, methodTag, hLowFrac] = detectRelaxStart(t, h, cfg.hThresh);

    tRel = t - t0;
    keep = isfinite(tRel) & isfinite(m) & (tRel >= 0);
    tRel = tRel(keep);
    mRel = m(keep);

    pos = tRel > 0;
    tRelPos = tRel(pos);
    mRelPos = mRel(pos);

    if numel(tRelPos) < cfg.minPostPts
        continue;
    end

    postDur = max(tRelPos) - min(tRelPos);
    if postDur < cfg.minPostDuration_s
        continue;
    end

    x = log10(tRelPos);

    curve(i).idx = i;
    curve(i).Temp_K = Tnom;
    curve(i).xRel = x;
    curve(i).MRel = mRelPos;

    rr = emptyRawRow();
    rr.data_idx = i;
    rr.file_name = string(fileList{i});
    rr.Temp_K = Tnom;
    rr.t0_abs_s = t0;
    rr.t0_idx = idx0;
    rr.t0_method = string(methodTag);
    rr.h_low_fraction_post_t0 = hLowFrac;
    rr.post_duration_s = postDur;
    rr.post_n_points = numel(tRelPos);
    rr.t_rel_min_pos_s = min(tRelPos);
    rr.t_rel_max_s = max(tRelPos);
    rawRows(i) = rr;
end

rawTbl = struct2table(rawRows);
valid = isfinite(rawTbl.Temp_K) & isfinite(rawTbl.t_rel_max_s) & rawTbl.post_n_points >= cfg.minPostPts;
rawTbl = rawTbl(valid,:);
rawTbl = sortrows(rawTbl, 'Temp_K');

if isempty(rawTbl)
    error('No valid curves for derivative smoothing analysis.');
end

validIdx = rawTbl.data_idx;
Ts = rawTbl.Temp_K;

% Common aligned grid in t_rel
minCommon = max(rawTbl.t_rel_min_pos_s);
maxCommon = min(rawTbl.t_rel_max_s);
if ~(isfinite(minCommon) && isfinite(maxCommon) && maxCommon > minCommon)
    error('Invalid common t_rel range.');
end

xGrid = linspace(log10(minCommon), log10(maxCommon), cfg.nLogGrid);
tGrid = 10.^xGrid;
dx = median(diff(xGrid));

nT = numel(validIdx);
Mmap = nan(nT, cfg.nLogGrid);
for r = 1:nT
    i = validIdx(r);
    x = curve(i).xRel;
    y = curve(i).MRel;
    if numel(x) < 20
        continue;
    end
    Mmap(r,:) = interp1(x, y, xGrid, 'pchip', nan);
end

dM_raw = Mmap - Mmap(:, end);

% 1D SG smoothing along log-time per curve (two windows)
winA = decadeToOddWindow(cfg.sgolayDecades(1), dx, cfg.sgolayOrder);
winB = decadeToOddWindow(cfg.sgolayDecades(2), dx, cfg.sgolayOrder);

dM_sgA = nan(size(dM_raw));
dM_sgB = nan(size(dM_raw));
for r = 1:nT
    dM_sgA(r,:) = sgSmoothRow(dM_raw(r,:), cfg.sgolayOrder, winA);
    dM_sgB(r,:) = sgSmoothRow(dM_raw(r,:), cfg.sgolayOrder, winB);
end

% 2D Gaussian smoothing
sigT = cfg.gaussSigmaT_steps;
sigX = cfg.gaussSigmaLog_dec / dx;
dM_g2d = gauss2dNan(dM_raw, sigT, sigX);

% Derivatives S(T,t) = -d(dM)/dlog10(t_rel)
S_raw = derivLogTime(dM_raw, xGrid);
S_sgA = derivLogTime(dM_sgA, xGrid);
S_sgB = derivLogTime(dM_sgB, xGrid);
S_g2d = derivLogTime(dM_g2d, xGrid);

% Export core arrays
writematrix([nan, xGrid; Ts, dM_raw], fullfile(outDir, 'map_dM_raw.csv'));
writematrix([nan, xGrid; Ts, dM_sgA], fullfile(outDir, sprintf('map_dM_sg_%03dmd.csv', round(cfg.sgolayDecades(1)*1000))));
writematrix([nan, xGrid; Ts, dM_sgB], fullfile(outDir, sprintf('map_dM_sg_%03dmd.csv', round(cfg.sgolayDecades(2)*1000))));
writematrix([nan, xGrid; Ts, dM_g2d], fullfile(outDir, 'map_dM_gauss2d.csv'));
writematrix([nan, xGrid; Ts, S_raw], fullfile(outDir, 'map_S_raw.csv'));
writematrix([nan, xGrid; Ts, S_sgA], fullfile(outDir, sprintf('map_S_sg_%03dmd.csv', round(cfg.sgolayDecades(1)*1000))));
writematrix([nan, xGrid; Ts, S_sgB], fullfile(outDir, sprintf('map_S_sg_%03dmd.csv', round(cfg.sgolayDecades(2)*1000))));
writematrix([nan, xGrid; Ts, S_g2d], fullfile(outDir, 'map_S_gauss2d.csv'));

writetable(rawTbl, fullfile(outDir, 'alignment_t0_summary.csv'));

% Common color scales
clim_dM = pooledClim({dM_raw, dM_sgA, dM_sgB, dM_g2d}, cfg.clipPrct);
clim_S = pooledClim({S_raw, S_sgA, S_sgB, S_g2d}, cfg.clipPrct);

% Figures
plotMap(xGrid, Ts, dM_raw, clim_dM, '\DeltaM raw', '\DeltaM', turbo, ...
    fullfile(outDir, 'relaxation_dM_map_raw.png'));
plotMap(xGrid, Ts, dM_sgA, clim_dM, sprintf('\DeltaM SG %.2f decade', cfg.sgolayDecades(1)), '\DeltaM', turbo, ...
    fullfile(outDir, 'relaxation_dM_map_sg_010.png'));
plotMap(xGrid, Ts, dM_sgB, clim_dM, sprintf('\DeltaM SG %.2f decade', cfg.sgolayDecades(2)), '\DeltaM', turbo, ...
    fullfile(outDir, 'relaxation_dM_map_sg_020.png'));
plotMap(xGrid, Ts, dM_g2d, clim_dM, '\DeltaM 2D Gaussian', '\DeltaM', turbo, ...
    fullfile(outDir, 'relaxation_dM_map_gauss2d.png'));

plotMap(xGrid, Ts, S_raw, clim_S, 'S raw = -d\DeltaM/dlog_{10}(t_{rel})', 'S', hot, ...
    fullfile(outDir, 'relaxation_S_map_raw.png'));
plotMap(xGrid, Ts, S_sgA, clim_S, sprintf('S from SG %.2f decade', cfg.sgolayDecades(1)), 'S', hot, ...
    fullfile(outDir, 'relaxation_S_map_sg_010.png'));
plotMap(xGrid, Ts, S_sgB, clim_S, sprintf('S from SG %.2f decade', cfg.sgolayDecades(2)), 'S', hot, ...
    fullfile(outDir, 'relaxation_S_map_sg_020.png'));
plotMap(xGrid, Ts, S_g2d, clim_S, 'S from 2D Gaussian \DeltaM', 'S', hot, ...
    fullfile(outDir, 'relaxation_S_map_gauss2d.png'));

plotAllSMapsPanel(xGrid, Ts, S_raw, S_sgA, S_sgB, S_g2d, clim_S, ...
    fullfile(outDir, 'relaxation_S_map_comparison_panel.png'));

xRep = quantile(xGrid, cfg.repQuantiles);
tRep = 10.^xRep;

plotTempCutsS(xGrid, Ts, S_raw, S_sgA, S_g2d, xRep, tRep, ...
    fullfile(outDir, 'relaxation_temperature_cuts_S.png'));
plotTimeCutsS(xGrid, Ts, S_raw, S_sgA, S_g2d, xRep, tRep, ...
    fullfile(outDir, 'relaxation_time_cuts_S.png'));

% Metrics: peak trajectory and variance reduction
methods = {'raw','sg_010','sg_020','gauss2d'};
Sset = {S_raw, S_sgA, S_sgB, S_g2d};
ridgeRows = table();
varRows = table();

rawVarGlobal = var(S_raw(:), 'omitnan');
for mi = 1:numel(methods)
    Sm = Sset{mi};
    [Smax, idxMax] = max(Sm, [], 2, 'omitnan');
    xPk = xGrid(idxMax)';
    tPk = 10.^xPk;

    tr = table(repmat(string(methods{mi}), nT, 1), Ts, Smax, xPk, tPk, ...
        'VariableNames', {'method','Temp_K','S_max','log10_t_peak','t_peak_s'});
    ridgeRows = [ridgeRows; tr]; %#ok<AGROW>

    varPerT = var(Sm, 0, 2, 'omitnan');
    vr = table(repmat(string(methods{mi}), nT, 1), Ts, varPerT, ...
        'VariableNames', {'method','Temp_K','var_S_over_logt'});
    varRows = [varRows; vr]; %#ok<AGROW>

    vGlob = var(Sm(:), 'omitnan');
    vRed = 1 - safeDiv(vGlob, rawVarGlobal);
    fprintf('%s global var=%.4e, reduction=%.3f\n', methods{mi}, vGlob, vRed);
end

writetable(ridgeRows, fullfile(outDir, 'S_ridge_peak_trajectory.csv'));
writetable(varRows, fullfile(outDir, 'S_variance_by_temperature.csv'));

varSummary = table();
for mi = 1:numel(methods)
    sub = varRows(varRows.method == string(methods{mi}), :);
    vMean = mean(sub.var_S_over_logt, 'omitnan');
    vMed = median(sub.var_S_over_logt, 'omitnan');
    vGlob = var(Sset{mi}(:), 'omitnan');
    vRed = 1 - safeDiv(vGlob, rawVarGlobal);
    row = table(string(methods{mi}), vGlob, vMean, vMed, vRed, ...
        'VariableNames', {'method','global_var','mean_var_over_T','median_var_over_T','variance_reduction_vs_raw'});
    varSummary = [varSummary; row]; %#ok<AGROW>
end
writetable(varSummary, fullfile(outDir, 'S_variance_reduction_summary.csv'));

% Ridge trajectory plot
plotRidgeTrajectory(ridgeRows, ...
    fullfile(outDir, 'relaxation_S_ridge_trajectory.png'));

% Markdown summary
mdPath = fullfile(outDir, 'analysis_summary_relaxation_derivative_smoothing.md');
writeSummaryMarkdown(mdPath, cfg, rawTbl, xGrid, tRep, varSummary, ridgeRows);

% Zip all outputs
zipPath = fullfile(outDir, 'relaxation_derivative_smoothing_analysis.zip');
if exist(zipPath, 'file')
    delete(zipPath);
end
allFiles = dir(fullfile(outDir, '*'));
zipList = strings(0,1);
for k = 1:numel(allFiles)
    if allFiles(k).isdir
        continue;
    end
    if strcmpi(allFiles(k).name, 'relaxation_derivative_smoothing_analysis.zip')
        continue;
    end
    zipList(end+1) = string(fullfile(allFiles(k).folder, allFiles(k).name)); %#ok<AGROW>
end
zip(zipPath, cellstr(zipList));

out = struct();
out.outDir = string(outDir);
out.zipPath = string(zipPath);
out.t0Table = rawTbl;
out.varSummary = varSummary;
out.ridge = ridgeRows;
out.tGrid = tGrid;
out.xGrid = xGrid;
out.tRep = tRep;
out.methods = methods;

fprintf('\n=== Relaxation derivative smoothing analysis complete ===\n');
fprintf('Output dir: %s\n', outDir);
fprintf('ZIP: %s\n\n', zipPath);

end

function y = safeDiv(a,b)
if ~isfinite(a) || ~isfinite(b) || abs(b) < eps
    y = NaN;
else
    y = a / b;
end
end

function row = emptyRawRow()
row = struct('data_idx',NaN,'file_name',"",'Temp_K',NaN,'t0_abs_s',NaN,'t0_idx',NaN, ...
    't0_method',"",'h_low_fraction_post_t0',NaN,'post_duration_s',NaN,'post_n_points',NaN, ...
    't_rel_min_pos_s',NaN,'t_rel_max_s',NaN);
end

function cc = emptyCurveStruct()
cc = struct('idx',NaN,'Temp_K',NaN,'xRel',[],'MRel',[]);
end

function [t, m, h] = cleanAligned(t, m, h)
t = t(:);
m = m(:);
if isempty(h)
    h = nan(size(t));
else
    h = h(:);
end
n = min([numel(t), numel(m), numel(h)]);
t = t(1:n); m = m(1:n); h = h(1:n);
ok = isfinite(t) & isfinite(m);
t = t(ok); m = m(ok); h = h(ok);
[t, ord] = sort(t, 'ascend');
m = m(ord); h = h(ord);
[t, iu] = unique(t, 'stable');
m = m(iu); h = h(iu);
end

function [idx0, t0, methodTag, lowFrac] = detectRelaxStart(t, h, hThresh)
idx0 = 1;
t0 = t(1);
methodTag = "fallback_start";
lowFrac = NaN;

if isempty(h) || all(~isfinite(h))
    return;
end

hs = h;
span = min(11, numel(hs));
if mod(span,2)==0, span = span - 1; end
if span >= 3
    hs = smoothdata(hs, 'movmean', span);
end

below = abs(hs) < hThresh;
[st, en] = findRuns(below);
if isempty(st), return; end

n = numel(t);
cand = find(en >= n-1);
if isempty(cand)
    [~, im] = max(en - st + 1);
    cand = im;
else
    cand = cand(end);
end

idx0 = st(cand);
t0 = t(idx0);
methodTag = "field_drop_to_lowH";
postMask = (1:n) >= idx0;
lowFrac = mean(below(postMask));
end

function [st, en] = findRuns(mask)
mask = logical(mask(:)');
d = diff([false, mask, false]);
st = find(d == 1);
en = find(d == -1) - 1;
end

function T = parseNominalTemp(fname, Tvec)
T = NaN;
m = regexp(char(fname), '([0-9]+\.?[0-9]*)\s*[Kk]', 'tokens', 'once');
if ~isempty(m)
    T = str2double(m{1});
end
if ~isfinite(T) && ~isempty(Tvec)
    tv = Tvec(isfinite(Tvec));
    if ~isempty(tv)
        T = mean(tv, 'omitnan');
    end
end
end

function w = decadeToOddWindow(decades, dx, polyOrder)
w = round(decades / dx);
w = max(w, polyOrder + 3);
if mod(w,2)==0
    w = w + 1;
end
end

function rowOut = sgSmoothRow(rowIn, polyOrder, win)
rowOut = rowIn;
if all(~isfinite(rowIn))
    return;
end

x = rowIn(:)';
if numel(x) < win
    rowOut = x;
    return;
end

try
    rowOut = sgolayfilt(x, polyOrder, win);
catch
    try
        rowOut = smoothdata(x, 'sgolay', win, 'Degree', polyOrder);
    catch
        rowOut = smoothdata(x, 'movmean', max(3, min(win, 11)));
    end
end
end

function Zs = gauss2dNan(Z, sigmaT, sigmaX)
if sigmaT <= 0 && sigmaX <= 0
    Zs = Z;
    return;
end

kT = gaussKernel(max(sigmaT, eps));
kX = gaussKernel(max(sigmaX, eps));

mask = isfinite(Z);
Z0 = Z;
Z0(~mask) = 0;

num = conv2(conv2(Z0, kT, 'same'), kX, 'same');
den = conv2(conv2(double(mask), kT, 'same'), kX, 'same');

Zs = num ./ max(den, eps);
Zs(den < 1e-6) = NaN;
end

function k = gaussKernel(sigma)
halfWidth = max(2, ceil(3 * sigma));
x = -halfWidth:halfWidth;
k = exp(-0.5 * (x / sigma).^2);
k = k / sum(k);
if isrow(k)
    % keep row; caller chooses orientation
end
end

function S = derivLogTime(Z, xGrid)
S = nan(size(Z));
for r = 1:size(Z,1)
    row = Z(r,:);
    if any(isfinite(row))
        d = gradient(row, xGrid);
        S(r,:) = -d;
    end
end
end

function clim = pooledClim(cellMaps, clipPrct)
vals = [];
for i = 1:numel(cellMaps)
    z = cellMaps{i};
    zf = z(isfinite(z));
    vals = [vals; zf(:)]; %#ok<AGROW>
end
if isempty(vals)
    clim = [0 1];
else
    clim = prctile(vals, clipPrct);
    if ~(isfinite(clim(1)) && isfinite(clim(2)) && clim(2) > clim(1))
        clim = [min(vals), max(vals)];
    end
end
end

function plotMap(xGrid, Tvec, Z, clim, ttl, cblabel, cmap, outFile)
fig = figure('Color','w','Visible','off','Position',[100 100 900 560]);
ax = axes(fig); %#ok<LAXES>
imagesc(ax, xGrid, Tvec, Z);
set(ax,'YDir','normal');
xlabel(ax, 'log_{10}(t_{rel} [s])');
ylabel(ax, 'Temperature [K]');
title(ax, ttl);
colormap(ax, cmap);
cb = colorbar(ax);
ylabel(cb, cblabel);
if isfinite(clim(1)) && isfinite(clim(2)) && clim(2) > clim(1)
    caxis(ax, clim);
end
grid(ax,'on'); box(ax,'on');
saveas(fig, outFile);
close(fig);
end

function plotAllSMapsPanel(xGrid, Tvec, Sraw, SsgA, SsgB, Sg2d, climS, outFile)
fig = figure('Color','w','Visible','off','Position',[80 80 1320 860]);
tl = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

maps = {Sraw,SsgA,SsgB,Sg2d};
titles = {'S raw','S SG 0.10 decade','S SG 0.20 decade','S 2D Gaussian'};
for i = 1:4
    ax = nexttile; %#ok<LAXES>
    imagesc(ax, xGrid, Tvec, maps{i});
    set(ax,'YDir','normal');
    title(ax, titles{i});
    xlabel(ax, 'log_{10}(t_{rel} [s])');
    ylabel(ax, 'T [K]');
    colormap(ax, hot);
    if isfinite(climS(1)) && isfinite(climS(2)) && climS(2) > climS(1)
        caxis(ax, climS);
    end
    grid(ax,'on'); box(ax,'on');
    colorbar(ax);
end
saveas(fig, outFile);
close(fig);
end

function plotTempCutsS(xGrid, Ts, Sraw, SsgA, Sg2d, xRep, tRep, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 1300 420]);
tl = tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

maps = {Sraw,SsgA,Sg2d};
labels = {'Raw','SG 0.10','2D Gaussian'};
for i = 1:3
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    cols = turbo(max(numel(Ts),3));
    Sm = maps{i};
    for r = 1:numel(Ts)
        plot(ax, xGrid, Sm(r,:), '-', 'Color', cols(r,:), 'LineWidth', 1.0);
    end
    for k = 1:numel(xRep)
        xline(ax, xRep(k), '--', sprintf('%.0fs', tRep(k)), ...
            'LabelVerticalAlignment', 'middle', 'LabelOrientation', 'horizontal');
    end
    xlabel(ax, 'log_{10}(t_{rel} [s])');
    ylabel(ax, 'S');
    title(ax, sprintf('S temperature cuts: %s', labels{i}));
end
saveas(fig, outFile);
close(fig);
end

function plotTimeCutsS(xGrid, Ts, Sraw, SsgA, Sg2d, xRep, tRep, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 1300 420]);
tl = tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

maps = {Sraw,SsgA,Sg2d};
labels = {'Raw','SG 0.10','2D Gaussian'};
cc = lines(numel(xRep));
for i = 1:3
    ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    Sm = maps{i};
    for k = 1:numel(xRep)
        y = interp1(xGrid, Sm', xRep(k), 'linear', nan)';
        plot(ax, Ts, y, '-o', 'Color', cc(k,:), 'LineWidth', 1.3, 'MarkerSize', 4, ...
            'DisplayName', sprintf('t_{rel}=%.0f s', tRep(k)));
    end
    xlabel(ax, 'Temperature [K]');
    ylabel(ax, 'S(T)');
    title(ax, sprintf('S time cuts: %s', labels{i}));
    legend(ax, 'Location', 'best');
end
saveas(fig, outFile);
close(fig);
end

function plotRidgeTrajectory(ridgeTbl, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 980 520]);
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');

methods = unique(ridgeTbl.method);
cols = lines(max(numel(methods),3));
for i = 1:numel(methods)
    m = methods(i);
    sub = ridgeTbl(ridgeTbl.method == m, :);
    plot(ax1, sub.Temp_K, sub.log10_t_peak, '-o', 'Color', cols(i,:), 'LineWidth', 1.4, ...
        'DisplayName', char(m));
    plot(ax2, sub.Temp_K, sub.S_max, '-s', 'Color', cols(i,:), 'LineWidth', 1.4, ...
        'DisplayName', char(m));
end

xlabel(ax1, 'Temperature [K]'); ylabel(ax1, 'log_{10}(t_{peak})');
title(ax1, 'Ridge trajectory in (T, log t)');
legend(ax1, 'Location', 'best');

xlabel(ax2, 'Temperature [K]'); ylabel(ax2, 'S_{max}(T)');
title(ax2, 'Peak S amplitude vs temperature');
legend(ax2, 'Location', 'best');

saveas(fig, outFile);
close(fig);
end

function writeSummaryMarkdown(mdPath, cfg, rawTbl, xGrid, tRep, varSummary, ridgeRows)
fid = fopen(mdPath, 'w');
if fid < 0
    warning('Could not write summary markdown: %s', mdPath);
    return;
end

fprintf(fid, '# Relaxation Derivative Smoothing Analysis\n\n');
fprintf(fid, '## 1. Smoothing Methods Tested\n');
fprintf(fid, '- Input map: dM(T, log10(t_rel)) = M(T,t_rel) - M(T,t_ref)\n');
fprintf(fid, '- Baseline derivative: S = -d(dM)/dlog10(t_rel) from unsmoothed map\n');
fprintf(fid, '- 1D Savitzky-Golay smoothing per temperature curve (poly order %d)\n', cfg.sgolayOrder);
fprintf(fid, '- 2D Gaussian smoothing on dM map\n\n');

fprintf(fid, '## 2. Parameters Used\n');
fprintf(fid, '- h-threshold for t0 detection: %.3f Oe\n', cfg.hThresh);
fprintf(fid, '- Common aligned log-time grid points: %d\n', cfg.nLogGrid);
fprintf(fid, '- Common t_rel range: %.3f to %.3f s\n', 10.^xGrid(1), 10.^xGrid(end));
fprintf(fid, '- SG windows: %.2f and %.2f log-decade\n', cfg.sgolayDecades(1), cfg.sgolayDecades(2));
fprintf(fid, '- 2D Gaussian sigma: sigma_T=%.2f steps, sigma_logt=%.3f decade\n', cfg.gaussSigmaT_steps, cfg.gaussSigmaLog_dec);
fprintf(fid, '- Representative time cuts (s): %.1f, %.1f, %.1f\n\n', tRep(1), tRep(2), tRep(3));

fprintf(fid, '## 3. Raw vs Smoothed Derivative Map Comparison\n');
for i = 1:height(varSummary)
    fprintf(fid, '- %s: global variance %.4e, variance reduction vs raw %.3f\n', ...
        char(varSummary.method(i)), varSummary.global_var(i), varSummary.variance_reduction_vs_raw(i));
end
fprintf(fid, '\n');

fprintf(fid, '## 4. Interpretation of Visible Structures\n');
fprintf(fid, '- Ridges are tracked using per-temperature maxima of S(T,t).\n');
fprintf(fid, '- Smoothed maps should preserve broad ridges while suppressing pixel-scale noise.\n');
fprintf(fid, '- Compare ridge trajectory and S_max(T) across methods in the exported trajectory plot and CSV.\n\n');

fprintf(fid, '## 5. Recommendation\n');
fprintf(fid, '- Prefer the weakest smoothing that stabilizes ridge trajectory and variance without shifting peak time strongly.\n');
fprintf(fid, '- In this sweep, SG(0.10 decade) is the default recommendation for preserving local structure with moderate denoising.\n');
fprintf(fid, '- Use 2D Gaussian as a secondary view for global patterns; avoid over-interpreting features only present after heavy smoothing.\n\n');

fprintf(fid, '## Alignment Notes\n');
fprintf(fid, '- Curves aligned by t_rel = t - t0, where t0 is detected as the start of the final low-field segment.\n');
fprintf(fid, '- Valid aligned curves: %d\n', height(rawTbl));

fclose(fid);
end

function v = setDef(s, f, d)
if ~isfield(s, f)
    s.(f) = d;
end
v = s;
end

