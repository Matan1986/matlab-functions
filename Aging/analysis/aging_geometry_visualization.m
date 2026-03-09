% aging_geometry_visualization
% Exploratory geometry diagnostics for aging DeltaM(T, tw) data.
% This script reuses the staged aging loaders (stage0-3 only) and produces
% run-scoped diagnostic figures for physical intuition (not publication).

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot); %#ok<NASGU>
addpath(genpath(agingRoot));

% Auto-discover all configured wait-time datasets from agingConfig.
datasetSpecs = discoverDatasetSpecs(agingRoot);
if isempty(datasetSpecs)
    % Fallback list if config parsing fails.
    datasetSpecs = {
        'MG119_3sec',   3;
        'MG119_36sec',  36;
        'MG119_6min',   360;
        'MG119_60min',  3600
    };
end

preferredTpK = 22;
tpTolK = 0.35;
nCommonGrid = 450;
tpNormHalfWindowK = 0.5;
nTempSlicesDesired = 20;
nTempSlicesMin = 15;
nTempSlicesMax = 20;

loaded = struct('key', {}, 'fallbackTwSec', {}, 'pauseRuns', {}, 'tpVals', {});
runCtx = [];

for i = 1:size(datasetSpecs, 1)
    datasetKey = datasetSpecs{i, 1};
    fallbackTwSec = datasetSpecs{i, 2};

    try
        cfg = agingConfig(datasetKey);
        cfg.runLabel = 'geometry_visualization';
        cfg.doPlotting = false;
        cfg.saveTableMode = 'none';
        cfg.doFilterDeltaM = false; % keep raw geometry
        cfg.alignDeltaM = false;

        if isfield(cfg, 'debug') && isstruct(cfg.debug)
            cfg.debug.enable = false;
            cfg.debug.plotGeometry = false;
            cfg.debug.plotSwitching = false;
            cfg.debug.saveOutputs = false;
        end

        if ~isempty(runCtx)
            cfg.run = runCtx; % keep one run context for all datasets in this script
        end

        cfg = stage0_setupPaths(cfg);
        runCtx = cfg.run;

        state = stage1_loadData(cfg);
        state = stage2_preprocess(state, cfg);
        state = stage3_computeDeltaM(state, cfg);

        pauseRunsRaw = extractRawPauseRuns(state);
        tpVals = [pauseRunsRaw.waitK];
        tpVals = tpVals(isfinite(tpVals));
        tpVals = sort(unique(tpVals(:)));

        if isempty(tpVals)
            warning('Skipping dataset %s: no finite waitK values were found.', datasetKey);
            continue;
        end

        loaded(end + 1).key = datasetKey; %#ok<SAGROW>
        loaded(end).fallbackTwSec = fallbackTwSec;
        loaded(end).pauseRuns = pauseRunsRaw;
        loaded(end).tpVals = tpVals;
    catch ME
        warning('Skipping dataset %s due to load failure: %s', datasetKey, ME.message);
    end
end

assert(~isempty(loaded), 'No aging datasets could be loaded.');

outDir = getResultsDir('aging', 'geometry_visualization');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

activeRunCtx = [];
if isappdata(0, 'runContext')
    activeRunCtx = getappdata(0, 'runContext');
elseif isappdata(0, 'MATLAB_FUNCTIONS_ACTIVE_RUN_CONTEXT')
    activeRunCtx = getappdata(0, 'MATLAB_FUNCTIONS_ACTIVE_RUN_CONTEXT');
end

fprintf('Aging geometry outputs saved to:\n%s\n', outDir);
if ~isempty(activeRunCtx) && isstruct(activeRunCtx) && isfield(activeRunCtx, 'run_id') && ~isempty(activeRunCtx.run_id)
    fprintf('Run context active: YES\n');
    fprintf('Active run_id: %s\n', activeRunCtx.run_id);
    if isfield(activeRunCtx, 'run_dir') && ~isempty(activeRunCtx.run_dir)
        fprintf('Active run_dir: %s\n', activeRunCtx.run_dir);
    end
else
    fprintf('Run context active: NO (getResultsDir fallback path in use)\n');
end

% Find common Tp across loaded wait-time datasets.
commonTp = loaded(1).tpVals;
for i = 2:numel(loaded)
    commonTp = intersectTol(commonTp, loaded(i).tpVals, tpTolK);
end
assert(~isempty(commonTp), 'No common Tp values found across loaded wait-time datasets.');

[~, iTp] = min(abs(commonTp - preferredTpK));
TpRef = commonTp(iTp);

% Build one DeltaM(T) curve per tw at selected Tp.
curves = struct('datasetKey', {}, 'twSec', {}, 'Tp', {}, 'T', {}, 'dM', {});
for i = 1:numel(loaded)
    pr = getPauseRunByTp(loaded(i).pauseRuns, TpRef, tpTolK);
    if isempty(pr)
        continue;
    end

    [T, dM] = extractDeltaMCurve(pr);
    if isempty(T) || isempty(dM)
        continue;
    end

    twSec = extractTwSeconds(pr, loaded(i).fallbackTwSec);
    if ~isfinite(twSec) || twSec <= 0
        continue;
    end

    c.datasetKey = loaded(i).key;
    c.twSec = twSec;
    c.Tp = getFieldOrNaN(pr, 'waitK');
    c.T = T(:);
    c.dM = dM(:);
    curves(end + 1) = c; %#ok<SAGROW>
end

assert(numel(curves) >= 2, 'Need at least two valid tw curves at common Tp to build M(T,tw).');

% Sort by tw.
[~, order] = sort([curves.twSec]);
curves = curves(order);
twSec = [curves.twSec].';
logTw = log10(twSec);
idxTwAll = 1:numel(twSec);

% Common T grid across all tw curves.
tMin = -Inf;
tMax = Inf;
for i = 1:numel(curves)
    tMin = max(tMin, min(curves(i).T));
    tMax = min(tMax, max(curves(i).T));
end
assert(tMax > tMin, 'No overlapping T-range across selected tw curves.');

Tgrid = linspace(tMin, tMax, nCommonGrid).';
M = nan(nCommonGrid, numel(curves)); % M(T,tw) = DeltaM
for i = 1:numel(curves)
    M(:, i) = interp1(curves(i).T, curves(i).dM, Tgrid, 'linear', NaN);
end

% Full-range temperature sampling for wait-time slices.
nTempSlices = min(nTempSlicesMax, max(nTempSlicesMin, nTempSlicesDesired));
nTempSlices = min(nTempSlices, numel(Tgrid));
targetTemps = linspace(min(Tgrid), max(Tgrid), nTempSlices);
idxTempSel = zeros(size(targetTemps));
for i = 1:numel(targetTemps)
    [~, idxTempSel(i)] = min(abs(Tgrid - targetTemps(i)));
end
idxTempSel = unique(idxTempSel, 'sorted');
if numel(idxTempSel) < nTempSlices
    idxTempSel = unique(round(linspace(1, numel(Tgrid), nTempSlices)), 'sorted');
end
actualTemps = Tgrid(idxTempSel).';
targetTemps = targetTemps(:).';

% Shared colormaps/limits.
cmapTw = getPerceptualColormap(256);
cmapTemp = getPerceptualColormap(256);
twMin = min(logTw);
twMax = max(logTw);
if ~isfinite(twMin) || ~isfinite(twMax) || twMax <= twMin
    twMin = min(logTw) - 0.5;
    twMax = max(logTw) + 0.5;
end

% ========================
% 1) Heatmap DeltaM(T,tw)
% ========================
fig1 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
imagesc(Tgrid, logTw, M.');
set(gca, 'YDir', 'normal');
colormap(getPerceptualColormap(256));
cb = colorbar;
ylabel(cb, '\DeltaM');
xlabel('T (K)');
ylabel('log_{10}(t_w [s])');
title(sprintf('Aging map: \\DeltaM(T, t_w), T_p = %.2f K', TpRef));
grid on;
saveas(fig1, fullfile(outDir, 'aging_map_heatmap.png'));
close(fig1);

% =========================================
% 1b) Heatmap derivative d(DeltaM)/dT(T,tw)
% =========================================
dMdT = nan(size(M));
for j = 1:size(M, 2)
    dMdT(:, j) = gradient(M(:, j), Tgrid);
end

fig1b = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
imagesc(Tgrid, logTw, dMdT.');
set(gca, 'YDir', 'normal');
colormap(getPerceptualColormap(256));
cb1b = colorbar;
ylabel(cb1b, 'd\DeltaM/dT');
xlabel('T (K)');
ylabel('log_{10}(t_w [s])');
title(sprintf('Aging map derivative: d\\DeltaM/dT(T, t_w), T_p = %.2f K', TpRef));
grid on;
saveas(fig1b, fullfile(outDir, 'aging_dMdT_heatmap.png'));
close(fig1b);

% ================================================
% 2) Temperature slices: DeltaM(T) for all tw
% ================================================
fig2 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax2 = axes(fig2); hold(ax2, 'on');
twColorLims = [twMin, twMax];
for i = 1:numel(idxTwAll)
    j = idxTwAll(i);
    thisLogTw = logTw(j);
    colorThis = mapValueToColormap(thisLogTw, twColorLims, cmapTw);
    plot(ax2, Tgrid, M(:, j), '-', 'LineWidth', 1.2, 'Color', colorThis, 'HandleVisibility', 'off');
end
xline(ax2, TpRef, '--k', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xlabel(ax2, 'T (K)');
ylabel(ax2, '\DeltaM');
title(ax2, '\DeltaM(T) for all wait times');
grid(ax2, 'on');
colormap(ax2, cmapTw);
clim(ax2, twColorLims);
cb2 = colorbar(ax2);
ylabel(cb2, 'log_{10}(t_w [s])');
saveas(fig2, fullfile(outDir, 'aging_temperature_slices.png'));
close(fig2);

% =========================
% 3) Wait-time slices DeltaM(tw)
% =========================
fig3 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax3 = axes(fig3); hold(ax3, 'on');

tempMin = min(actualTemps);
tempMax = max(actualTemps);
if ~isfinite(tempMin) || ~isfinite(tempMax) || tempMax <= tempMin
    tempMin = min(Tgrid);
    tempMax = max(Tgrid);
end
for i = 1:numel(idxTempSel)
    thisTemp = actualTemps(i);
    colorThis = mapValueToColormap(thisTemp, [tempMin, tempMax], cmapTemp);
    plot(ax3, logTw, M(idxTempSel(i), :), '-o', 'LineWidth', 1.2, ...
        'Color', colorThis, 'HandleVisibility', 'off');
end
xlabel(ax3, 'log_{10}(t_w [s])');
ylabel(ax3, '\DeltaM');
title(ax3, sprintf('Wait-time slices across full T range (%.2f-%.2f K)', min(actualTemps), max(actualTemps)));
grid(ax3, 'on');
colormap(ax3, cmapTemp);
clim(ax3, [tempMin, tempMax]);
cb3 = colorbar(ax3);
ylabel(cb3, 'Temperature (K)');
saveas(fig3, fullfile(outDir, 'aging_waittime_slices.png'));
close(fig3);

% ==========================================
% 4) Centered axis: x = T - Tp, DeltaM(x,tw)
% ==========================================
xCentered = Tgrid - TpRef;
fig4 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax4 = axes(fig4); hold(ax4, 'on');
for i = 1:numel(idxTwAll)
    j = idxTwAll(i);
    thisLogTw = logTw(j);
    colorThis = mapValueToColormap(thisLogTw, [twMin, twMax], cmapTw);
    plot(ax4, xCentered, M(:, j), '-', 'LineWidth', 1.2, 'Color', colorThis, 'HandleVisibility', 'off');
end
xline(ax4, 0, '--k', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xlabel(ax4, 'x = T - T_p (K)');
ylabel(ax4, '\DeltaM');
title(ax4, 'Centered temperature slices: all wait times');
grid(ax4, 'on');
colormap(ax4, cmapTw);
clim(ax4, [twMin, twMax]);
cb4 = colorbar(ax4);
ylabel(cb4, 'log_{10}(t_w [s])');
saveas(fig4, fullfile(outDir, 'aging_centered_temperature_slices.png'));
close(fig4);

% ==========================================================
% 5) Normalized dip shape: DeltaM / |mean_{Tp+-window}(DeltaM)|
% ==========================================================
tpNormMask = abs(Tgrid - TpRef) <= tpNormHalfWindowK;
if ~any(tpNormMask)
    [~, iTpNearest] = min(abs(Tgrid - TpRef));
    tpNormMask(iTpNearest) = true;
end

MtpAvg = mean(M(tpNormMask, idxTwAll), 1, 'omitnan');
normDen = abs(MtpAvg);
finiteDen = normDen(isfinite(normDen) & normDen > 0);
if isempty(finiteDen)
    normDenMin = eps;
else
    normDenMin = max(eps, 1e-3 * median(finiteDen, 'omitnan'));
end

Mnorm = nan(nCommonGrid, numel(idxTwAll));
normSkipped = 0;
for i = 1:numel(idxTwAll)
    den = normDen(i);
    if isfinite(den) && den > normDenMin
        Mnorm(:, i) = M(:, idxTwAll(i)) ./ den;
    else
        normSkipped = normSkipped + 1;
    end
end

fig5 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax5 = axes(fig5); hold(ax5, 'on');
for i = 1:numel(idxTwAll)
    j = idxTwAll(i);
    thisLogTw = logTw(j);
    colorThis = mapValueToColormap(thisLogTw, [twMin, twMax], cmapTw);
    plot(ax5, Tgrid, Mnorm(:, i), '-', 'LineWidth', 1.2, 'Color', colorThis, 'HandleVisibility', 'off');
end
xline(ax5, TpRef, '--k', 'LineWidth', 1.1, 'HandleVisibility', 'off');
xlabel(ax5, 'T (K)');
ylabel(ax5, '\DeltaM(T,t_w) / |\langle\DeltaM\rangle_{T_p\pm0.5K}|');
title(ax5, sprintf('Normalized dip-shape (robust window avg), skipped=%d', normSkipped));
grid(ax5, 'on');
colormap(ax5, cmapTw);
clim(ax5, [twMin, twMax]);
cb5 = colorbar(ax5);
ylabel(cb5, 'log_{10}(t_w [s])');
saveas(fig5, fullfile(outDir, 'aging_normalized_dip_shape.png'));
close(fig5);

% ===========================
% Text report
% ===========================
reportPath = fullfile(outDir, 'aging_geometry_report.txt');
fid = fopen(reportPath, 'w');
assert(fid >= 0, 'Failed to write report: %s', reportPath);

fprintf(fid, 'Aging Geometry Diagnostic Report\n');
fprintf(fid, 'Generated: %s\n\n', datestr(now, 31));
fprintf(fid, 'Output directory: %s\n\n', outDir);

fprintf(fid, 'Dataset keys loaded:\n');
for i = 1:numel(loaded)
    fprintf(fid, '  - %s\n', loaded(i).key);
end
fprintf(fid, '\n');

fprintf(fid, 'Selected common Tp for M(T,tw): %.4f K\n', TpRef);
fprintf(fid, 'Common-Tp tolerance used: %.3f K\n', tpTolK);
fprintf(fid, 'Preferred Tp target: %.2f K\n', preferredTpK);
fprintf(fid, 'Normalization window: [Tp-%.3f, Tp+%.3f] K\n', tpNormHalfWindowK, tpNormHalfWindowK);
fprintf(fid, 'Normalization points in T-grid: %d\n', nnz(tpNormMask));
fprintf(fid, 'Normalization denominator minimum threshold: %.6g\n\n', normDenMin);

fprintf(fid, 'All wait times used in geometry plots:\n');
for i = 1:numel(curves)
    fprintf(fid, '  - %s | %s | tw = %.6g s (%.6g h)\n', ...
        curves(i).datasetKey, formatTwLabel(curves(i).twSec), curves(i).twSec, curves(i).twSec / 3600);
end
fprintf(fid, '\n');

fprintf(fid, 'Temperature coverage for wait-time slices:\n');
fprintf(fid, '  - target range: [%.4f, %.4f] K\n', min(targetTemps), max(targetTemps));
fprintf(fid, '  - number of temperature slices: %d\n', numel(actualTemps));
for i = 1:numel(actualTemps)
    tgt = targetTemps(min(i, numel(targetTemps)));
    fprintf(fid, '  - target %.4f K -> actual %.4f K\n', tgt, actualTemps(i));
end
fprintf(fid, '\n');

fprintf(fid, 'Matrix shape:\n');
fprintf(fid, '  - M size: %d x %d (T x tw)\n', size(M, 1), size(M, 2));
fprintf(fid, '  - T range: [%.4f, %.4f] K\n', min(Tgrid), max(Tgrid));
fprintf(fid, '  - log10(tw[s]) range: [%.4f, %.4f]\n', min(logTw), max(logTw));
fprintf(fid, '  - normalized curves skipped due small denominator: %d\n', normSkipped);
fprintf(fid, '\n');

fprintf(fid, 'Data-loading path reused:\n');
fprintf(fid, '  agingConfig -> stage0_setupPaths -> stage1_loadData -> stage2_preprocess -> stage3_computeDeltaM\n');
fprintf(fid, '  DeltaM source used here: state.pauseRuns_raw (pre-filter, exploratory geometry)\n');

fclose(fid);

reviewFiles = {
    'aging_map_heatmap.png'
    'aging_dMdT_heatmap.png'
    'aging_temperature_slices.png'
    'aging_waittime_slices.png'
    'aging_centered_temperature_slices.png'
    'aging_normalized_dip_shape.png'
    'aging_geometry_report.txt'
};
reviewZipPath = fullfile(outDir, 'aging_geometry_review.zip');
if isfile(reviewZipPath)
    delete(reviewZipPath);
end
zipPaths = strings(0, 1);
for i = 1:numel(reviewFiles)
    p = fullfile(outDir, reviewFiles{i});
    assert(isfile(p), 'Missing expected output for review ZIP: %s', p);
    zipPaths(end + 1, 1) = string(p); %#ok<AGROW>
end
zip(char(reviewZipPath), cellstr(zipPaths));
assert(isfile(reviewZipPath), 'Failed to create review ZIP: %s', reviewZipPath);
fprintf('Review ZIP created at:\n%s\n', reviewZipPath);

fprintf('Aging geometry diagnostics complete.\n');
fprintf('Output directory: %s\n', outDir);
fprintf('Report: %s\n', reportPath);
fprintf('Review ZIP: %s\n', reviewZipPath);

function pauseRunsRaw = extractRawPauseRuns(state)
if isfield(state, 'pauseRuns_raw') && ~isempty(state.pauseRuns_raw)
    pauseRunsRaw = state.pauseRuns_raw;
elseif isfield(state, 'pauseRuns') && ~isempty(state.pauseRuns)
    pauseRunsRaw = state.pauseRuns;
else
    error('No pause runs were found in stage3 output.');
end
end

function pr = getPauseRunByTp(pauseRuns, tpTarget, tol)
pr = [];
if isempty(pauseRuns)
    return;
end
tpVals = [pauseRuns.waitK];
idx = find(isfinite(tpVals) & abs(tpVals - tpTarget) <= tol, 1, 'first');
if ~isempty(idx)
    pr = pauseRuns(idx);
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

if isfield(pr, 'DeltaM') && ~isempty(pr.DeltaM)
    dM = pr.DeltaM(:);
elseif isfield(pr, 'DeltaM_aligned') && ~isempty(pr.DeltaM_aligned)
    dM = pr.DeltaM_aligned(:);
end

n = min(numel(T), numel(dM));
if n < 10
    T = [];
    dM = [];
    return;
end

T = T(1:n);
dM = dM(1:n);
ok = isfinite(T) & isfinite(dM);
T = T(ok);
dM = dM(ok);

if numel(T) < 10
    T = [];
    dM = [];
    return;
end

[T, idx] = unique(T, 'stable');
dM = dM(idx);
end

function twSec = extractTwSeconds(pr, fallbackTwSec)
twSec = NaN;
if isfield(pr, 'waitHours') && ~isempty(pr.waitHours) && isfinite(pr.waitHours) && pr.waitHours > 0
    twSec = 3600 * pr.waitHours;
elseif nargin >= 2
    twSec = fallbackTwSec;
end
end

function vals = intersectTol(a, b, tol)
a = unique(a(:).');
b = unique(b(:).');
vals = [];
for i = 1:numel(a)
    if any(abs(b - a(i)) <= tol)
        vals(end + 1) = a(i); %#ok<SAGROW>
    end
end
vals = unique(vals);
end

function x = getFieldOrNaN(s, fieldName)
x = NaN;
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    x = s.(fieldName);
end
end

function cmap = getPerceptualColormap(n)
if nargin < 1 || isempty(n)
    n = 256;
end
n = max(2, round(n));

if exist('turbo', 'file') == 2
    cmap = turbo(n);
elseif exist('parula', 'builtin') == 5 || exist('parula', 'file') == 2
    cmap = parula(n);
else
    cmap = jet(n);
end
end

function color = mapValueToColormap(val, lims, cmap)
if nargin < 3 || isempty(cmap)
    cmap = getPerceptualColormap(256);
end
if nargin < 2 || numel(lims) ~= 2 || ~all(isfinite(lims)) || lims(2) <= lims(1)
    color = cmap(max(1, round(size(cmap, 1) / 2)), :);
    return;
end

t = (val - lims(1)) / (lims(2) - lims(1));
t = max(0, min(1, t));
idx = 1 + round(t * (size(cmap, 1) - 1));
color = cmap(idx, :);
end

function lbl = formatTwLabel(twSec)
if ~isfinite(twSec) || twSec <= 0
    lbl = 'tw = NaN';
    return;
end

if twSec < 60
    lbl = sprintf('tw = %.0f s', twSec);
elseif twSec < 3600
    lbl = sprintf('tw = %.2f min', twSec / 60);
else
    lbl = sprintf('tw = %.2f h', twSec / 3600);
end
end

function datasetSpecs = discoverDatasetSpecs(agingRoot)
datasetSpecs = {};
cfgPath = fullfile(agingRoot, 'pipeline', 'agingConfig.m');
if ~isfile(cfgPath)
    return;
end

try
    txt = fileread(cfgPath);
catch
    return;
end

toks = regexp(txt, 'case\s+''([^'']+)''', 'tokens');
if isempty(toks)
    return;
end

keys = strings(0, 1);
for i = 1:numel(toks)
    keys(end + 1, 1) = string(toks{i}{1}); %#ok<SAGROW>
end
keys = unique(keys, 'stable');
keys = keys(contains(keys, 'MG119_'));
if isempty(keys)
    return;
end

fallbackSec = nan(numel(keys), 1);
for i = 1:numel(keys)
    fallbackSec(i) = parseDatasetWaitSeconds(keys(i));
end

sortKey = fallbackSec;
sortKey(~isfinite(sortKey)) = Inf;
[~, order] = sort(sortKey, 'ascend');
keys = keys(order);
fallbackSec = fallbackSec(order);

datasetSpecs = cell(numel(keys), 2);
for i = 1:numel(keys)
    datasetSpecs{i, 1} = char(keys(i));
    datasetSpecs{i, 2} = fallbackSec(i);
end
end

function twSec = parseDatasetWaitSeconds(datasetKey)
twSec = NaN;
k = lower(char(datasetKey));

tokSec = regexp(k, '(\d+(?:\.\d+)?)\s*sec', 'tokens', 'once');
if ~isempty(tokSec)
    twSec = str2double(tokSec{1});
    return;
end

tokMin = regexp(k, '(\d+(?:\.\d+)?)\s*min', 'tokens', 'once');
if ~isempty(tokMin)
    twSec = 60 * str2double(tokMin{1});
    return;
end

tokHour = regexp(k, '(\d+(?:\.\d+)?)\s*(?:hour|hr|h)', 'tokens', 'once');
if ~isempty(tokHour)
    twSec = 3600 * str2double(tokHour{1});
end
end

