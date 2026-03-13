% aging_geometry_visualization
% Exploratory geometry diagnostics for aging DeltaM(T, tw) data.
% Uses staged loading (stage0-3 only) and repository artifact helpers.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot); %#ok<NASGU>
addpath(genpath(agingRoot));

% Auto-discover configured wait-time datasets from agingConfig.
datasetSpecs = discoverDatasetSpecs(agingRoot);
if isempty(datasetSpecs)
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
fontSizeMain = 14;
lineWidthMain = 2.0;
lineStylesSmall = {'-', '--', ':', '-.', '-', '--'};

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
        cfg.doFilterDeltaM = false;
        cfg.alignDeltaM = false;

        if isfield(cfg, 'debug') && isstruct(cfg.debug)
            cfg.debug.enable = false;
            cfg.debug.plotGeometry = false;
            cfg.debug.plotSwitching = false;
            cfg.debug.saveOutputs = false;
        end

        if ~isempty(runCtx)
            cfg.run = runCtx;
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

run_output_dir = getRunOutputDir();
fprintf('Aging geometry run root:\n%s\n', run_output_dir);
fprintf('Figures dir: %s\n', fullfile(run_output_dir, 'figures'));
fprintf('Reports dir: %s\n', fullfile(run_output_dir, 'reports'));
fprintf('Review dir: %s\n', fullfile(run_output_dir, 'review'));

% Determine common Tp across loaded wait-time datasets.
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

    twSecThis = extractTwSeconds(pr, loaded(i).fallbackTwSec);
    if ~isfinite(twSecThis) || twSecThis <= 0
        continue;
    end

    c.datasetKey = loaded(i).key;
    c.twSec = twSecThis;
    c.Tp = getFieldOrNaN(pr, 'waitK');
    c.T = T(:);
    c.dM = dM(:);
    curves(end + 1) = c; %#ok<SAGROW>
end

assert(numel(curves) >= 2, 'Need at least two valid tw curves at common Tp to build M(T,tw).');

% Sort by tw and build map M(T,tw).
[~, order] = sort([curves.twSec]);
curves = curves(order);
twSec = [curves.twSec].';
logTw = log10(twSec);
idxTwAll = 1:numel(twSec);

Tmin = -Inf;
Tmax = Inf;
for i = 1:numel(curves)
    Tmin = max(Tmin, min(curves(i).T));
    Tmax = min(Tmax, max(curves(i).T));
end
assert(Tmax > Tmin, 'No overlapping T-range across selected tw curves.');

Tgrid = linspace(Tmin, Tmax, nCommonGrid).';
M = nan(nCommonGrid, numel(curves));
for i = 1:numel(curves)
    M(:, i) = interp1(curves(i).T, curves(i).dM, Tgrid, 'linear', NaN);
end

% Full-range temperature sampling (~20 evenly spaced values).
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

cmapTw = getPerceptualColormap(256);
cmapTemp = getPerceptualColormap(256);
twMin = min(logTw);
twMax = max(logTw);
if ~isfinite(twMin) || ~isfinite(twMax) || twMax <= twMin
    twMin = min(logTw) - 0.5;
    twMax = max(logTw) + 0.5;
end

figSaved = strings(0, 1);
nTwCurves = numel(idxTwAll);

% 1) Aging heatmap DeltaM(T,tw)
fig1 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax1 = axes(fig1);
imagesc(ax1, Tgrid, logTw, M.');
axis(ax1, 'xy');
colormap(ax1, cmapTw);
cb1 = colorbar(ax1);
ylabel(cb1, '\DeltaM');
xlabel(ax1, 'Temperature (K)', 'FontSize', fontSizeMain);
ylabel(ax1, 'log_{10}(t_w [s])', 'FontSize', fontSizeMain);
title(ax1, sprintf('Aging map: \\DeltaM(T, t_w), T_p = %.2f K', TpRef), 'FontSize', fontSizeMain);
grid(ax1, 'on');
set(ax1, 'FontSize', fontSizeMain);
p1 = save_run_figure(fig1, 'aging_map_heatmap', run_output_dir);
figSaved(end + 1, 1) = string(p1.png); %#ok<SAGROW>
close(fig1);

% 1b) Derivative heatmap dDeltaM/dT(T,tw)
% Light SG smoothing before derivative to reduce numerical noise.
M_smooth = M;
for j = 1:size(M, 2)
    y = M(:, j);
    if any(~isfinite(y))
        y = fillmissing(y, 'linear', 'EndValues', 'nearest');
    end
    if numel(y) >= 11
        y = sgolayfilt(y, 2, 11);
    end
    M_smooth(:, j) = y;
end

dMdT = nan(size(M));
for j = 1:size(M, 2)
    dMdT(:, j) = gradient(M_smooth(:, j), Tgrid);
end

fig1b = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax1b = axes(fig1b);
imagesc(ax1b, Tgrid, logTw, dMdT.');
axis(ax1b, 'xy');
colormap(ax1b, cmapTw);
cb1b = colorbar(ax1b);
ylabel(cb1b, 'd\DeltaM/dT');
xlabel(ax1b, 'Temperature (K)', 'FontSize', fontSizeMain);
ylabel(ax1b, 'log_{10}(t_w [s])', 'FontSize', fontSizeMain);
title(ax1b, sprintf('Aging derivative map: d\\DeltaM/dT(T, t_w), T_p = %.2f K', TpRef), 'FontSize', fontSizeMain);
grid(ax1b, 'on');
set(ax1b, 'FontSize', fontSizeMain);
p1b = save_run_figure(fig1b, 'aging_dMdT_heatmap', run_output_dir);
figSaved(end + 1, 1) = string(p1b.png); %#ok<SAGROW>
close(fig1b);

% 2) Temperature slices DeltaM(T) for all wait times
fig2 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax2 = axes(fig2); hold(ax2, 'on');
if nTwCurves <= 6
    colsSmall = lines(nTwCurves);
    for i = 1:nTwCurves
        j = idxTwAll(i);
        plot(ax2, Tgrid, M(:, j), lineStylesSmall{i}, 'LineWidth', lineWidthMain, ...
            'Color', colsSmall(i, :), 'DisplayName', formatTwLabel(twSec(j)));
    end
else
    for i = 1:numel(idxTwAll)
        j = idxTwAll(i);
        colorThis = mapValueToColormap(logTw(j), [twMin, twMax], cmapTw);
        plot(ax2, Tgrid, M(:, j), '-', 'LineWidth', lineWidthMain, 'Color', colorThis, 'HandleVisibility', 'off');
    end
end
xline(ax2, TpRef, '--k', 'LineWidth', max(2.0, lineWidthMain), 'HandleVisibility', 'off');
xlabel(ax2, 'Temperature (K)', 'FontSize', fontSizeMain);
ylabel(ax2, '\DeltaM', 'FontSize', fontSizeMain);
title(ax2, '\DeltaM(T) for all wait times', 'FontSize', fontSizeMain);
grid(ax2, 'on');
if nTwCurves <= 6
    legend(ax2, 'Location', 'eastoutside');
else
    colormap(ax2, cmapTw);
    clim(ax2, [twMin, twMax]);
    cb2 = colorbar(ax2);
    ylabel(cb2, 'log_{10}(t_w [s])');
end
set(ax2, 'FontSize', fontSizeMain);
p2 = save_run_figure(fig2, 'aging_temperature_slices', run_output_dir);
figSaved(end + 1, 1) = string(p2.png); %#ok<SAGROW>
close(fig2);

% 3) Wait-time slices DeltaM(tw) for ~20 full-range temperatures
tempMin = min(actualTemps);
tempMax = max(actualTemps);
if ~isfinite(tempMin) || ~isfinite(tempMax) || tempMax <= tempMin
    tempMin = min(Tgrid);
    tempMax = max(Tgrid);
end

fig3 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax3 = axes(fig3); hold(ax3, 'on');
for i = 1:numel(idxTempSel)
    thisTemp = actualTemps(i);
    colorThis = mapValueToColormap(thisTemp, [tempMin, tempMax], cmapTemp);
    plot(ax3, logTw, M(idxTempSel(i), :), '-o', 'LineWidth', lineWidthMain, ...
        'Color', colorThis, 'HandleVisibility', 'off');
end
xlabel(ax3, 'log_{10}(t_w [s])', 'FontSize', fontSizeMain);
ylabel(ax3, '\DeltaM', 'FontSize', fontSizeMain);
title(ax3, sprintf('Wait-time slices across full T range (%.2f-%.2f K)', min(actualTemps), max(actualTemps)), ...
    'FontSize', fontSizeMain);
grid(ax3, 'on');
colormap(ax3, cmapTemp);
clim(ax3, [tempMin, tempMax]);
cb3 = colorbar(ax3);
ylabel(cb3, 'Temperature (K)');
set(ax3, 'FontSize', fontSizeMain);
p3 = save_run_figure(fig3, 'aging_waittime_slices', run_output_dir);
figSaved(end + 1, 1) = string(p3.png); %#ok<SAGROW>
close(fig3);

% 4) Centered representation DeltaM(T - Tp)
xCentered = Tgrid - TpRef;
fig4 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax4 = axes(fig4); hold(ax4, 'on');
if nTwCurves <= 6
    colsSmall = lines(nTwCurves);
    for i = 1:nTwCurves
        j = idxTwAll(i);
        plot(ax4, xCentered, M(:, j), lineStylesSmall{i}, 'LineWidth', lineWidthMain, ...
            'Color', colsSmall(i, :), 'DisplayName', formatTwLabel(twSec(j)));
    end
else
    for i = 1:numel(idxTwAll)
        j = idxTwAll(i);
        colorThis = mapValueToColormap(logTw(j), [twMin, twMax], cmapTw);
        plot(ax4, xCentered, M(:, j), '-', 'LineWidth', lineWidthMain, 'Color', colorThis, 'HandleVisibility', 'off');
    end
end
xline(ax4, 0, '--k', 'LineWidth', max(2.0, lineWidthMain), 'HandleVisibility', 'off');
xlabel(ax4, 'T - T_p (K)', 'FontSize', fontSizeMain);
ylabel(ax4, '\DeltaM', 'FontSize', fontSizeMain);
title(ax4, 'Centered temperature slices: all wait times', 'FontSize', fontSizeMain);
grid(ax4, 'on');
if nTwCurves <= 6
    legend(ax4, 'Location', 'eastoutside');
else
    colormap(ax4, cmapTw);
    clim(ax4, [twMin, twMax]);
    cb4 = colorbar(ax4);
    ylabel(cb4, 'log_{10}(t_w [s])');
end
set(ax4, 'FontSize', fontSizeMain);
p4 = save_run_figure(fig4, 'aging_centered_temperature_slices', run_output_dir);
figSaved(end + 1, 1) = string(p4.png); %#ok<SAGROW>
close(fig4);

% 5) Robust normalized dip shape
% M_norm(T,tw) = DeltaM(T,tw) / |mean_{Tp+-0.5K}(DeltaM)|
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
if nTwCurves <= 6
    colsSmall = lines(nTwCurves);
    for i = 1:nTwCurves
        j = idxTwAll(i);
        plot(ax5, Tgrid, Mnorm(:, i), lineStylesSmall{i}, 'LineWidth', lineWidthMain, ...
            'Color', colsSmall(i, :), 'DisplayName', formatTwLabel(twSec(j)));
    end
else
    for i = 1:numel(idxTwAll)
        j = idxTwAll(i);
        colorThis = mapValueToColormap(logTw(j), [twMin, twMax], cmapTw);
        plot(ax5, Tgrid, Mnorm(:, i), '-', 'LineWidth', lineWidthMain, 'Color', colorThis, 'HandleVisibility', 'off');
    end
end
xline(ax5, TpRef, '--k', 'LineWidth', max(2.0, lineWidthMain), 'HandleVisibility', 'off');
xlabel(ax5, 'Temperature (K)', 'FontSize', fontSizeMain);
ylabel(ax5, '\DeltaM(T,t_w) / |\langle\DeltaM\rangle_{T_p\pm0.5K}|', 'FontSize', fontSizeMain);
title(ax5, sprintf('Normalized dip-shape (robust window avg), skipped=%d', normSkipped), 'FontSize', fontSizeMain);
grid(ax5, 'on');
if nTwCurves <= 6
    legend(ax5, 'Location', 'eastoutside');
else
    colormap(ax5, cmapTw);
    clim(ax5, [twMin, twMax]);
    cb5 = colorbar(ax5);
    ylabel(cb5, 'log_{10}(t_w [s])');
end
set(ax5, 'FontSize', fontSizeMain);
p5 = save_run_figure(fig5, 'aging_normalized_dip_shape', run_output_dir);
figSaved(end + 1, 1) = string(p5.png); %#ok<SAGROW>
close(fig5);

% Build report text and save via helper.
reportText = "";
reportText = reportText + "Aging Geometry Diagnostic Report" + newline;
reportText = reportText + sprintf('Generated: %s', datestr(now, 31)) + newline + newline;
reportText = reportText + "Plots generated:" + newline;
reportText = reportText + "- aging_map_heatmap" + newline;
reportText = reportText + "- aging_dMdT_heatmap" + newline;
reportText = reportText + "- aging_temperature_slices" + newline;
reportText = reportText + "- aging_waittime_slices" + newline;
reportText = reportText + "- aging_centered_temperature_slices" + newline;
reportText = reportText + "- aging_normalized_dip_shape" + newline + newline;

reportText = reportText + "Slicing strategy:" + newline;
reportText = reportText + "- Temperature slices: all available wait times" + newline;
reportText = reportText + sprintf('- Wait-time slices: %d temperatures evenly sampled across full T range', numel(actualTemps)) + newline;
reportText = reportText + sprintf('- Full T range used: [%.4f, %.4f] K', min(Tgrid), max(Tgrid)) + newline + newline;

reportText = reportText + "Normalization method:" + newline;
reportText = reportText + sprintf('- Tp selected: %.4f K', TpRef) + newline;
reportText = reportText + sprintf('- Robust window: [Tp-%.3f, Tp+%.3f] K', tpNormHalfWindowK, tpNormHalfWindowK) + newline;
reportText = reportText + sprintf('- Grid points in normalization window: %d', nnz(tpNormMask)) + newline;
reportText = reportText + sprintf('- Denominator threshold floor: %.6g', normDenMin) + newline;
reportText = reportText + sprintf('- Curves skipped due tiny denominator: %d', normSkipped) + newline + newline;

reportText = reportText + "Derivative method:" + newline;
reportText = reportText + "- Light smoothing before derivative: sgolayfilt(order=2, frame=11)" + newline;
reportText = reportText + "- Derivative computed along temperature axis via gradient(M_smooth(:,j), Tgrid)" + newline + newline;

reportText = reportText + "All wait times used:" + newline;
for i = 1:numel(curves)
    reportText = reportText + sprintf('- %s | %s | tw = %.6g s (%.6g h)', ...
        curves(i).datasetKey, formatTwLabel(curves(i).twSec), curves(i).twSec, curves(i).twSec / 3600) + newline;
end
reportText = reportText + newline;

reportText = reportText + "Anomalies observed:" + newline;
if normSkipped > 0
    reportText = reportText + sprintf('- %d normalized curves were skipped due tiny denominator.', normSkipped) + newline;
else
    reportText = reportText + "- No normalization-denominator anomalies detected." + newline;
end
if any(~isfinite(M(:)))
    reportText = reportText + "- Non-finite values exist in interpolated M matrix (likely interpolation boundaries)." + newline;
else
    reportText = reportText + "- No non-finite values in interpolated M matrix." + newline;
end
reportText = reportText + newline;

reportText = reportText + "Visualization issues fixed:" + newline;
reportText = reportText + "- Removed colormap/colorbar usage from low-curve wait-time overlays (4 curves)." + newline;
reportText = reportText + "- Kept colormap/colorbar only for dense wait-time slices and heatmaps." + newline + newline;

reportText = reportText + "Visualization choices:" + newline;
reportText = reportText + sprintf('- number of wait-time curves: %d', numel(idxTwAll)) + newline;
reportText = reportText + sprintf('- number of wait-time slice temperatures: %d', numel(actualTemps)) + newline;
reportText = reportText + "- legend vs colormap: explicit legends for <=6-curve overlays, colormap + colorbar for >6 curves" + newline;
reportText = reportText + "- colormap used: perceptual (turbo fallback to parula)" + newline;
reportText = reportText + "- smoothing applied: SG(2,11) before dDeltaM/dT" + newline;
reportText = reportText + "- rules applied: one visualization per figure, one colormap/colorbar per heatmap, low-curve overlays use legend" + newline;

reportPath = save_run_report(reportText, 'aging_geometry_report.txt', run_output_dir);

% Create review ZIP in canonical review/ folder.
reviewDir = fullfile(run_output_dir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
reviewZipPath = fullfile(reviewDir, 'aging_geometry_review.zip');
if isfile(reviewZipPath)
    delete(reviewZipPath);
end

zipInputs = [figSaved; string(reportPath)];
zip(char(reviewZipPath), cellstr(zipInputs));
assert(isfile(reviewZipPath), 'Failed to create review ZIP: %s', reviewZipPath);

fprintf('Review ZIP created at:\n%s\n', reviewZipPath);
fprintf('Aging geometry diagnostics complete.\n');
fprintf('Run root: %s\n', run_output_dir);
fprintf('Report: %s\n', reportPath);

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






