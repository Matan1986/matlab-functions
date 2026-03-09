function out = validate_relaxation_band_boundaries(dataDir, cfg)
% validate_relaxation_band_boundaries
% Validate whether detected relaxation band boundaries are robust and physical.

if nargin < 1 || isempty(dataDir)
    dataDir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";
end
if nargin < 2
    cfg = struct();
end

cfg = setDef(cfg, 'normalizeByMass', true);
cfg = setDef(cfg, 'convertToMuBCo', true);
cfg = setDef(cfg, 'tailFrac', 0.20);
cfg = setDef(cfg, 'smallFrac', 0.12);
cfg = setDef(cfg, 'spikeFrac', 0.92);
cfg = setDef(cfg, 'minRunFrac', 0.005);
cfg = setDef(cfg, 'edgePts', 9);
cfg = setDef(cfg, 'gridList', [220 320 480]);
cfg = setDef(cfg, 'gridRef', 320);

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
[outDir, run] = init_run_output_dir(repoRoot, 'relaxation', 'geometry_maps_relaxband_validation', dataDir); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

[fileList, ~, ~, ~, ~, ~] = getFileList_relaxation(char(dataDir), 'parula');
[Time_table, Temp_table, ~, Moment_table, ~] = ...
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
Tnom = nan(nCurves,1);
tMin = nan(nCurves,1);
tMax = nan(nCurves,1);
nPts = nan(nCurves,1);

rawT = cell(nCurves,1);
rawX = cell(nCurves,1);
rawM = cell(nCurves,1);
rawS = cell(nCurves,1);
rawC = cell(nCurves,1);

for i = 1:nCurves
    Tnom(i) = parseNominalTemp(fileList{i}, Temp_table{i});
    t = Time_table{i};
    m = Moment_table{i};
    if isempty(t) || isempty(m)
        continue;
    end

    ok = isfinite(t) & isfinite(m) & (t > 0);
    t = t(ok);
    m = m(ok);
    if isempty(t)
        continue;
    end

    [t, ord] = sort(t, 'ascend');
    m = m(ord);
    [t, iu] = unique(t, 'stable');
    m = m(iu);
    if numel(t) < 20
        continue;
    end

    x = log10(t);
    s = gradient(m, x);
    c = gradient(s, x);

    rawT{i} = t;
    rawX{i} = x;
    rawM{i} = m;
    rawS{i} = s;
    rawC{i} = c;

    tMin(i) = min(t);
    tMax(i) = max(t);
    nPts(i) = numel(t);
end

valid = isfinite(Tnom) & isfinite(tMin) & isfinite(tMax) & (tMax > tMin);
if ~any(valid)
    error('No valid curves for band validation.');
end

Ts = Tnom(valid);
[Ts, ordT] = sort(Ts, 'ascend');
validIdx = find(valid);
validIdx = validIdx(ordT);

% Detect band on native/raw curves (no common-grid truncation)
rawRows = repmat(emptyRow(), numel(validIdx), 1);
for r = 1:numel(validIdx)
    i = validIdx(r);
    x = rawX{i};
    s = rawS{i};
    c = rawC{i};

    row = detectBand1D(Ts(r), x, s, c, cfg);
    if isfinite(row.i_start)
        st = row.i_start;
        en = row.i_end;

        m = rawM{i};
        t = rawT{i};
        row.t_start_s = t(st);
        row.t_end_s = t(en);
        row.logt_start = x(st);
        row.logt_end = x(en);
        row.width_log10 = x(en) - x(st);
        row.center_log10 = 0.5 * (x(en) + x(st));
        row.width_s = t(en) - t(st);
        row.center_s = sqrt(max(t(st), eps) * max(t(en), eps));

        row.post_relax_frac = computePostRelaxFrac(m, st, en);
        [row.edge_ratio_start, row.edge_ratio_end] = edgeRatios(abs(s), st, en, cfg.edgePts);
    end
    rawRows(r) = row;
end
rawTbl = struct2table(rawRows);
rawTbl = sortrows(rawTbl, 'Temp_K');
writetable(rawTbl, fullfile(outDir, 'band_raw_detection_summary.csv'));

% Common-grid detections for interpolation sensitivity
allTmin = tMin(validIdx);
allTmax = tMax(validIdx);
tLo = max(allTmin);
tHi = min(allTmax);
if ~(isfinite(tLo) && isfinite(tHi) && (tHi > tLo))
    error('Invalid common overlap range for grid sensitivity.');
end

gridTblAll = table();
for g = 1:numel(cfg.gridList)
    nGrid = cfg.gridList(g);
    [gridTbl, ~] = detectOnCommonGrid(validIdx, Ts, rawT, rawM, nGrid, tLo, tHi, cfg);
    gridTbl.n_grid = repmat(nGrid, height(gridTbl), 1);
    gridTblAll = [gridTblAll; gridTbl]; %#ok<AGROW>
end
writetable(gridTblAll, fullfile(outDir, 'band_common_grid_sensitivity.csv'));

% Reference common-grid table
refIdx = find(cfg.gridList == cfg.gridRef, 1);
if isempty(refIdx)
    [~, refIdx] = min(abs(cfg.gridList - cfg.gridRef));
end
refGrid = cfg.gridList(refIdx);
[refTbl, xRef] = detectOnCommonGrid(validIdx, Ts, rawT, rawM, refGrid, tLo, tHi, cfg);
refTbl = sortrows(refTbl, 'Temp_K');
writetable(refTbl, fullfile(outDir, 'band_common_ref_summary.csv'));

% Compare raw-vs-common (start-window bias)
cmpTbl = table();
cmpTbl.Temp_K = rawTbl.Temp_K;
cmpTbl.raw_logt_start = rawTbl.logt_start;
cmpTbl.raw_logt_end = rawTbl.logt_end;
cmpTbl.common_logt_start = refTbl.logt_start;
cmpTbl.common_logt_end = refTbl.logt_end;
cmpTbl.d_start_log = cmpTbl.common_logt_start - cmpTbl.raw_logt_start;
cmpTbl.d_end_log = cmpTbl.common_logt_end - cmpTbl.raw_logt_end;
writetable(cmpTbl, fullfile(outDir, 'band_raw_vs_common_bias.csv'));

% Trend metrics for center/width
[centerCorr, centerSlope] = linTrend(rawTbl.Temp_K, rawTbl.center_log10);
[widthCorr, widthSlope] = linTrend(rawTbl.Temp_K, rawTbl.width_log10);

trendTbl = table(centerCorr, centerSlope, widthCorr, widthSlope, ...
    'VariableNames', {'center_corr','center_slope_perK','width_corr','width_slope_perK'});
writetable(trendTbl, fullfile(outDir, 'band_center_width_trends.csv'));

% Figure 1: raw M cuts with start/end overlays
f1 = fullfile(outDir, 'relaxation_band_overlay_rawcuts.png');
plotRawCutsWithBounds(validIdx, Ts, rawX, rawM, rawTbl, f1);

% Figure 2: raw slope cuts with start/end overlays
f2 = fullfile(outDir, 'relaxation_band_overlay_slopecuts.png');
plotSlopeCutsWithBounds(validIdx, Ts, rawX, rawS, rawTbl, f2);

% Figure 3: center(T), width(T)
f3 = fullfile(outDir, 'relaxation_band_center_width_vs_temp.png');
plotCenterWidth(rawTbl, trendTbl, f3);

% Figure 4: common-grid sensitivity (interpolation bias)
f4 = fullfile(outDir, 'relaxation_band_grid_sensitivity.png');
plotGridSensitivity(gridTblAll, f4);

% Figure 5: raw vs common bias (start-window bias)
f5 = fullfile(outDir, 'relaxation_band_common_vs_raw_bias.png');
plotRawVsCommonBias(cmpTbl, log10(tLo), f5);

% Figure 6: post-band relaxation fraction
f6 = fullfile(outDir, 'relaxation_band_postband_fraction_vs_temp.png');
plotPostRelax(rawTbl, f6);

zipPath = fullfile(outDir, 'relaxation_band_validation_figures.zip');
if exist(zipPath, 'file')
    delete(zipPath);
end
zipFiles = {f1,f2,f3,f4,f5,f6};
zip(zipPath, zipFiles);

out = struct();
out.dataDir = string(dataDir);
out.outDir = string(outDir);
out.zipPath = string(zipPath);
out.rawSummary = rawTbl;
out.commonRefSummary = refTbl;
out.biasSummary = cmpTbl;
out.gridSensitivity = gridTblAll;
out.trends = trendTbl;
out.figures = string(zipFiles);

fprintf('\n=== Band-boundary validation complete ===\n');
fprintf('Output dir: %s\n', outDir);
fprintf('ZIP: %s\n\n', zipPath);

end

function row = detectBand1D(Tk, x, s, c, cfg)
row = emptyRow();
row.Temp_K = Tk;

x = x(:)';
s = s(:)';
if isempty(c)
    c = nan(size(s));
else
    c = c(:)';
end

finite = isfinite(x) & isfinite(s);
if nnz(finite) < 20
    return;
end

absS = abs(s);
n = numel(absS);
iTail = max(1, floor((1 - cfg.tailFrac) * n));
tailVals = absS(iTail:end);
tailVals = tailVals(isfinite(tailVals));
if isempty(tailVals)
    noise = median(absS(finite), 'omitnan');
else
    noise = median(tailVals, 'omitnan');
end
peak = prctile(absS(finite), 95);
if ~isfinite(noise), noise = 0; end
if ~isfinite(peak), peak = prctile(absS(finite), 75); end
if ~isfinite(peak) || peak <= noise
    peak = max(absS(finite));
end

smallThr = noise + cfg.smallFrac * max(peak - noise, eps);
spikeThr = noise + cfg.spikeFrac * max(peak - noise, eps);

active = finite & (absS > smallThr);
spike = false(size(active));
spike = spike | (absS > spikeThr);
if any(isfinite(c))
    cThr = prctile(abs(c(isfinite(c))), 99);
    if isfinite(cThr)
        spike = spike | (abs(c) > cThr);
    end
end
active(spike) = false;

minRun = max(3, round(cfg.minRunFrac * n));
active = removeShortRuns(active, minRun);
[st, en] = findRuns(active);
if isempty(st)
    return;
end

bestScore = -Inf;
bestIdx = 1;
for k = 1:numel(st)
    segAmp = sum(absS(st(k):en(k)), 'omitnan');
    segLen = en(k) - st(k) + 1;
    score = segAmp * log(1 + segLen);
    if score > bestScore
        bestScore = score;
        bestIdx = k;
    end
end

i0 = st(bestIdx);
i1 = en(bestIdx);
row.small_threshold = smallThr;
row.spike_threshold = spikeThr;
row.i_start = i0;
row.i_end = i1;
row.logt_start = x(i0);
row.logt_end = x(i1);
row.width_log10 = x(i1) - x(i0);
row.center_log10 = 0.5 * (x(i1) + x(i0));
row.coverage_frac = (i1 - i0 + 1) / n;
row.absSlope_median = median(absS(i0:i1), 'omitnan');
end

function row = emptyRow()
row = struct('Temp_K',NaN,'small_threshold',NaN,'spike_threshold',NaN, ...
    'i_start',NaN,'i_end',NaN,'logt_start',NaN,'logt_end',NaN,'width_log10',NaN, ...
    'center_log10',NaN,'coverage_frac',NaN,'absSlope_median',NaN, ...
    't_start_s',NaN,'t_end_s',NaN,'width_s',NaN,'center_s',NaN, ...
    'post_relax_frac',NaN,'edge_ratio_start',NaN,'edge_ratio_end',NaN);
end

function [tbl, xGrid] = detectOnCommonGrid(validIdx, Ts, rawT, rawM, nGrid, tLo, tHi, cfg)
xGrid = linspace(log10(tLo), log10(tHi), nGrid);
rows = repmat(emptyRow(), numel(validIdx), 1);
for r = 1:numel(validIdx)
    i = validIdx(r);
    t = rawT{i};
    m = rawM{i};
    x = log10(t);
    y = interp1(x, m, xGrid, 'pchip', nan);
    s = gradient(y, xGrid);
    c = gradient(s, xGrid);

    row = detectBand1D(Ts(r), xGrid, s, c, cfg);
    if isfinite(row.i_start)
        row.t_start_s = 10.^row.logt_start;
        row.t_end_s = 10.^row.logt_end;
        row.width_s = row.t_end_s - row.t_start_s;
        row.center_s = sqrt(max(row.t_start_s,eps) * max(row.t_end_s,eps));
    end
    rows(r) = row;
end

tbl = struct2table(rows);
tbl = sortrows(tbl, 'Temp_K');
end

function frac = computePostRelaxFrac(m, st, en)
frac = NaN;
n = numel(m);
if st < 1 || en > n || st >= en || en >= n
    return;
end
m0 = m(st);
m1 = m(en);
mf = m(end);
tot = abs(m0 - mf);
post = abs(m1 - mf);
if tot > 0
    frac = post / tot;
end
end

function [rStart, rEnd] = edgeRatios(absS, st, en, w)
rStart = NaN;
rEnd = NaN;
n = numel(absS);

inStart = st:min(n, st + w - 1);
outStart = max(1, st - w):max(1, st - 1);
if ~isempty(outStart)
    a = median(absS(inStart), 'omitnan');
    b = median(absS(outStart), 'omitnan');
    if isfinite(a) && isfinite(b) && b > 0
        rStart = a / b;
    end
end

inEnd = max(st, en - w + 1):en;
outEnd = min(n, en + 1):min(n, en + w);
if ~isempty(outEnd)
    a = median(absS(inEnd), 'omitnan');
    b = median(absS(outEnd), 'omitnan');
    if isfinite(a) && isfinite(b) && b > 0
        rEnd = a / b;
    end
end
end

function [corrVal, slopeVal] = linTrend(x, y)
mask = isfinite(x) & isfinite(y);
x = x(mask);
y = y(mask);
if numel(x) < 3
    corrVal = NaN;
    slopeVal = NaN;
    return;
end
x = x(:);
y = y(:);
mx = mean(x);
my = mean(y);
sxy = sum((x - mx) .* (y - my));
sxx = sum((x - mx).^2);
syy = sum((y - my).^2);
if sxx > 0
    slopeVal = sxy / sxx;
else
    slopeVal = NaN;
end
if sxx > 0 && syy > 0
    corrVal = sxy / sqrt(sxx * syy);
else
    corrVal = NaN;
end
end

function plotRawCutsWithBounds(validIdx, Ts, rawX, rawM, rawTbl, outFile)
fig = figure('Color','w','Visible','off','Position',[100 100 960 620]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
cols = turbo(max(numel(validIdx),3));
for r = 1:numel(validIdx)
    i = validIdx(r);
    x = rawX{i};
    m = rawM{i};
    c = cols(r,:);
    plot(ax, x, m, '-', 'Color', c, 'LineWidth', 1.1);

    st = rawTbl.logt_start(r);
    en = rawTbl.logt_end(r);
    if isfinite(st)
        ys = interp1(x, m, st, 'linear', nan);
        plot(ax, st, ys, 'o', 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 5);
    end
    if isfinite(en)
        ye = interp1(x, m, en, 'linear', nan);
        plot(ax, en, ye, 's', 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 5);
    end
end
xlabel(ax, 'log_{10}(t [s])');
ylabel(ax, 'M');
title(ax, 'Raw temperature cuts: M vs log_{10}(t) with detected band boundaries');
text(ax, 0.02, 0.03, 'Markers: o=start, s=end', 'Units', 'normalized');
saveas(fig, outFile);
close(fig);
end

function plotSlopeCutsWithBounds(validIdx, Ts, rawX, rawS, rawTbl, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 960 620]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
cols = turbo(max(numel(validIdx),3));
for r = 1:numel(validIdx)
    i = validIdx(r);
    x = rawX{i};
    s = rawS{i};
    c = cols(r,:);
    plot(ax, x, abs(s), '-', 'Color', c, 'LineWidth', 1.1);

    st = rawTbl.logt_start(r);
    en = rawTbl.logt_end(r);
    if isfinite(st)
        ys = interp1(x, abs(s), st, 'linear', nan);
        plot(ax, st, ys, 'o', 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 5);
    end
    if isfinite(en)
        ye = interp1(x, abs(s), en, 'linear', nan);
        plot(ax, en, ye, 's', 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 5);
    end
end
xlabel(ax, 'log_{10}(t [s])');
ylabel(ax, '|dM/dlog_{10}(t)|');
title(ax, 'Raw slope cuts with detected boundaries');
text(ax, 0.02, 0.03, 'Markers: o=start, s=end', 'Units', 'normalized');
saveas(fig, outFile);
close(fig);
end

function plotCenterWidth(rawTbl, trendTbl, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 980 520]);
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
plot(ax1, rawTbl.Temp_K, rawTbl.center_log10, '-o', 'LineWidth', 1.5, 'MarkerSize', 5);
xlabel(ax1, 'Temperature [K]');
ylabel(ax1, 'band center log_{10}(t [s])');
title(ax1, sprintf('center(T): r = %.3f, slope = %.4f /K', trendTbl.center_corr, trendTbl.center_slope_perK));

ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
plot(ax2, rawTbl.Temp_K, rawTbl.width_log10, '-s', 'LineWidth', 1.5, 'MarkerSize', 5);
xlabel(ax2, 'Temperature [K]');
ylabel(ax2, 'band width (log_{10} decades)');
title(ax2, sprintf('width(T): r = %.3f, slope = %.4f /K', trendTbl.width_corr, trendTbl.width_slope_perK));

saveas(fig, outFile);
close(fig);
end

function plotGridSensitivity(gridTblAll, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 980 520]);
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

grids = unique(gridTblAll.n_grid);
cols = lines(max(numel(grids),3));

ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
for k = 1:numel(grids)
    g = grids(k);
    sub = gridTblAll(gridTblAll.n_grid == g, :);
    plot(ax1, sub.Temp_K, sub.logt_start, '-o', 'Color', cols(k,:), 'LineWidth', 1.4, ...
        'DisplayName', sprintf('nGrid=%d', g));
end
xlabel(ax1, 'Temperature [K]'); ylabel(ax1, 'log_{10}(t_{start})');
title(ax1, 'Grid sensitivity: start boundary');
legend(ax1, 'Location', 'best');

ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
for k = 1:numel(grids)
    g = grids(k);
    sub = gridTblAll(gridTblAll.n_grid == g, :);
    plot(ax2, sub.Temp_K, sub.logt_end, '-s', 'Color', cols(k,:), 'LineWidth', 1.4, ...
        'DisplayName', sprintf('nGrid=%d', g));
end
xlabel(ax2, 'Temperature [K]'); ylabel(ax2, 'log_{10}(t_{end})');
title(ax2, 'Grid sensitivity: end boundary');
legend(ax2, 'Location', 'best');

saveas(fig, outFile);
close(fig);
end

function plotRawVsCommonBias(cmpTbl, commonLogStart, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 980 520]);
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>

ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
plot(ax1, cmpTbl.Temp_K, cmpTbl.raw_logt_start, '-o', 'LineWidth', 1.5, 'DisplayName', 'raw start');
plot(ax1, cmpTbl.Temp_K, cmpTbl.common_logt_start, '-s', 'LineWidth', 1.5, 'DisplayName', 'common-grid start');
yline(ax1, commonLogStart, '--', 'common overlap start');
xlabel(ax1, 'Temperature [K]'); ylabel(ax1, 'log_{10}(t_{start})');
title(ax1, 'Start-boundary bias: raw vs common-grid');
legend(ax1, 'Location', 'best');

ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
plot(ax2, cmpTbl.Temp_K, cmpTbl.raw_logt_end, '-o', 'LineWidth', 1.5, 'DisplayName', 'raw end');
plot(ax2, cmpTbl.Temp_K, cmpTbl.common_logt_end, '-s', 'LineWidth', 1.5, 'DisplayName', 'common-grid end');
xlabel(ax2, 'Temperature [K]'); ylabel(ax2, 'log_{10}(t_{end})');
title(ax2, 'End-boundary comparison: raw vs common-grid');
legend(ax2, 'Location', 'best');

saveas(fig, outFile);
close(fig);
end

function plotPostRelax(rawTbl, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 760 520]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
plot(ax, rawTbl.Temp_K, rawTbl.post_relax_frac, '-o', 'LineWidth', 1.6, 'MarkerSize', 5);
yline(ax, 0.10, '--', '10%');
yline(ax, 0.25, '--', '25%');
xlabel(ax, 'Temperature [K]');
ylabel(ax, 'post-band relaxation fraction');
title(ax, 'Does relaxation continue beyond detected band?');

saveas(fig, outFile);
close(fig);
end

function maskOut = removeShortRuns(maskIn, minLen)
maskOut = false(size(maskIn));
[st, en] = findRuns(maskIn);
for k = 1:numel(st)
    if (en(k) - st(k) + 1) >= minLen
        maskOut(st(k):en(k)) = true;
    end
end
end

function [st, en] = findRuns(mask)
mask = logical(mask(:)');
d = diff([false, mask, false]);
st = find(d == 1);
en = find(d == -1) - 1;
end

function v = setDef(s, f, d)
if ~isfield(s, f)
    s.(f) = d;
end
v = s;
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



