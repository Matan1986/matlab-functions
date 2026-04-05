% switching_geometry_diagnostics
% Diagnose how switching-geometry observables evolve with temperature and
% which geometric element changes most strongly near the 26 K crossover.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

if ~exist('sourceScalingRunId', 'var') || isempty(sourceScalingRunId)
    sourceScalingRunId = "run_2026_03_12_234016_switching_full_scaling_collapse";
end
if ~exist('relaxationPeakTemp_K', 'var') || isempty(relaxationPeakTemp_K)
    relaxationPeakTemp_K = 26;
end
if ~exist('derivativeSmoothingWindow', 'var') || isempty(derivativeSmoothingWindow)
    derivativeSmoothingWindow = 3;
end

[sourceRunDir, sourceManifest, sourceCfg] = resolveScalingRun(repoRoot, sourceScalingRunId);
paramsPath = fullfile(sourceRunDir, 'tables', 'switching_full_scaling_parameters.csv');
assert(isfile(paramsPath), 'Missing scaling-parameters table: %s', paramsPath);

paramsTbl = readtable(paramsPath);
geometryTbl = buildGeometryTable(paramsTbl, derivativeSmoothingWindow);
featureTbl = buildCharacteristicPointsTable(geometryTbl, relaxationPeakTemp_K);
nearPeakTbl = buildNearPeakComparisonTable(geometryTbl, relaxationPeakTemp_K);
scatterTbl = buildScatterCorrelationTable(geometryTbl);

cfgRun = struct();
cfgRun.runLabel = 'switching_geometry_diagnostics';
cfgRun.dataset = getStructField(sourceManifest, 'dataset', '');
cfgRun.sourceScalingRunId = char(string(sourceScalingRunId));
cfgRun.sourceScalingRunDir = sourceRunDir;
cfgRun.relaxationPeakTemp_K = relaxationPeakTemp_K;
cfgRun.derivativeSmoothingMethod = 'movmean';
cfgRun.derivativeSmoothingWindow = derivativeSmoothingWindow;
cfgRun.widthRule = getStructField(sourceCfg, 'widthRule', 'width_chosen_mA from scaling-parameter table');

run = createSwitchingRunContext(repoRoot, cfgRun);
runDir = run.run_dir;

fprintf('switching run directory:\n%s\n', runDir);
fprintf('source scaling run:\n%s\n', sourceRunDir);

geometryOut = save_run_table(geometryTbl, 'switching_geometry_observables.csv', runDir);
featureOut = save_run_table(featureTbl, 'switching_geometry_characteristic_points.csv', runDir);
nearPeakOut = save_run_table(nearPeakTbl, 'switching_geometry_near_26K_comparison.csv', runDir);
scatterOut = save_run_table(scatterTbl, 'switching_geometry_scatter_correlations.csv', runDir);

figIpeak = create_figure('Visible', 'off', 'Position', [2 2 14 10]);
axIpeak = axes(figIpeak);
plotObservableVsTemperature(axIpeak, geometryTbl.T_K, geometryTbl.I_peak_mA, ...
    relaxationPeakTemp_K, 'I_{peak}(T)', 'I_{peak} (mA)', ...
    'Switching ridge position vs temperature');
figIpeakPaths = save_run_figure(figIpeak, 'switching_geometry_Ipeak_vs_T', runDir);
close(figIpeak);

figWidth = create_figure('Visible', 'off', 'Position', [2 2 14 10]);
axWidth = axes(figWidth);
plotObservableVsTemperature(axWidth, geometryTbl.T_K, geometryTbl.width_mA, ...
    relaxationPeakTemp_K, 'width(T)', 'width (mA)', ...
    'Switching ridge width vs temperature');
figWidthPaths = save_run_figure(figWidth, 'switching_geometry_width_vs_T', runDir);
close(figWidth);

figSpeak = create_figure('Visible', 'off', 'Position', [2 2 14 10]);
axSpeak = axes(figSpeak);
plotObservableVsTemperature(axSpeak, geometryTbl.T_K, geometryTbl.S_peak, ...
    relaxationPeakTemp_K, 'S_{peak}(T)', 'S_{peak}', ...
    'Switching ridge amplitude vs temperature');
figSpeakPaths = save_run_figure(figSpeak, 'switching_geometry_Speak_vs_T', runDir);
close(figSpeak);

figDerivatives = create_figure('Visible', 'off', 'Position', [2 2 15 20]);
tlDerivatives = tiledlayout(figDerivatives, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlDerivatives, 1);
plotDerivativePanel(ax1, geometryTbl.T_K, geometryTbl.dI_peak_dT_mA_per_K, ...
    relaxationPeakTemp_K, 'dI_{peak}/dT (mA/K)', 'dI_{peak}/dT');

ax2 = nexttile(tlDerivatives, 2);
plotDerivativePanel(ax2, geometryTbl.T_K, geometryTbl.dwidth_dT_mA_per_K, ...
    relaxationPeakTemp_K, 'dwidth/dT (mA/K)', 'dwidth/dT');

ax3 = nexttile(tlDerivatives, 3);
plotDerivativePanel(ax3, geometryTbl.T_K, geometryTbl.dS_peak_dT_per_K, ...
    relaxationPeakTemp_K, 'dS_{peak}/dT (1/K)', 'dS_{peak}/dT');

title(tlDerivatives, 'Temperature derivatives of switching-geometry observables');
figDerivativePaths = save_run_figure(figDerivatives, 'switching_geometry_derivatives_vs_T', runDir);
close(figDerivatives);

figNorm = create_figure('Visible', 'off', 'Position', [2 2 14 10]);
axNorm = axes(figNorm);
plotNormalizedOverlay(axNorm, geometryTbl, relaxationPeakTemp_K);
figNormPaths = save_run_figure(figNorm, 'switching_geometry_normalized_overlay', runDir);
close(figNorm);

figScatter = create_figure('Visible', 'off', 'Position', [2 2 20 7.8]);
tlScatter = tiledlayout(figScatter, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
plotScatterPanel(nexttile(tlScatter, 1), geometryTbl.I_peak_mA, geometryTbl.width_mA, geometryTbl.T_K, ...
    'I_{peak} (mA)', 'width (mA)', 'I_{peak} vs width');
plotScatterPanel(nexttile(tlScatter, 2), geometryTbl.width_mA, geometryTbl.S_peak, geometryTbl.T_K, ...
    'width (mA)', 'S_{peak}', 'width vs S_{peak}');
plotScatterPanel(nexttile(tlScatter, 3), geometryTbl.I_peak_mA, geometryTbl.S_peak, geometryTbl.T_K, ...
    'I_{peak} (mA)', 'S_{peak}', 'I_{peak} vs S_{peak}');
title(tlScatter, 'Switching-geometry scatter comparisons');
figScatterPaths = save_run_figure(figScatter, 'switching_geometry_scatter_comparisons', runDir);
close(figScatter);

reportText = buildReportText( ...
    sourceManifest, sourceCfg, geometryTbl, featureTbl, nearPeakTbl, scatterTbl, ...
    figIpeakPaths.png, figWidthPaths.png, figSpeakPaths.png, figDerivativePaths.png, ...
    figNormPaths.png, figScatterPaths.png, geometryOut, featureOut, nearPeakOut, scatterOut, ...
    relaxationPeakTemp_K, derivativeSmoothingWindow);
reportOut = save_run_report(reportText, 'switching_geometry_diagnostics.md', runDir);

appendRunNotes(run.notes_path, reportText);
zipOut = buildReviewZip(runDir, 'switching_geometry_diagnostics_bundle.zip');

fprintf('Saved observables table: %s\n', geometryOut);
fprintf('Saved characteristic-points table: %s\n', featureOut);
fprintf('Saved near-26K comparison table: %s\n', nearPeakOut);
fprintf('Saved scatter-correlation table: %s\n', scatterOut);
fprintf('Saved report: %s\n', reportOut);
fprintf('Saved review ZIP: %s\n', zipOut);

function [runDir, manifest, cfg] = resolveScalingRun(repoRoot, sourceScalingRunId)
runsRoot = switchingCanonicalRunRoot(repoRoot);
runDir = fullfile(runsRoot, char(string(sourceScalingRunId)));
assert(exist(runDir, 'dir') == 7, 'Requested scaling run does not exist: %s', runDir);

manifest = struct();
manifestPath = fullfile(runDir, 'run_manifest.json');
if exist(manifestPath, 'file') == 2
    manifest = jsondecode(fileread(manifestPath));
end

cfg = struct();
cfgPath = fullfile(runDir, 'config_snapshot.m');
if exist(cfgPath, 'file') == 2
    cfg = parseConfigSnapshot(cfgPath);
end
end

function cfg = parseConfigSnapshot(cfgPath)
cfg = struct();
cfgText = fileread(cfgPath);
tokens = regexp(cfgText, 'cfg_snapshot_json = ''(.*)'';', 'tokens', 'once');
if isempty(tokens)
    return;
end
try
    cfg = jsondecode(tokens{1});
catch
    cfg = struct();
end
end

function tbl = buildGeometryTable(paramsTbl, smoothingWindow)
requiredVars = {'T_K','Ipeak_mA','S_peak','width_chosen_mA'};
for i = 1:numel(requiredVars)
    assert(ismember(requiredVars{i}, paramsTbl.Properties.VariableNames), ...
        'Missing required column "%s" in scaling-parameters table.', requiredVars{i});
end

temps = double(paramsTbl.T_K(:));
[temps, sortIdx] = sort(temps);
Ipeak = double(paramsTbl.Ipeak_mA(sortIdx));
width = double(paramsTbl.width_chosen_mA(sortIdx));
Speak = double(paramsTbl.S_peak(sortIdx));

window = max(3, min(numel(temps), round(smoothingWindow)));
if mod(window, 2) == 0 && window > 1
    window = window - 1;
end

IpeakSmooth = smoothSeries(Ipeak, window);
widthSmooth = smoothSeries(width, window);
SpeakSmooth = smoothSeries(Speak, window);

[dIpeak, d2Ipeak] = computeDerivatives(temps, IpeakSmooth);
[dWidth, d2Width] = computeDerivatives(temps, widthSmooth);
[dSpeak, d2Speak] = computeDerivatives(temps, SpeakSmooth);

IpeakNorm = minMaxNormalize(Ipeak);
widthNorm = minMaxNormalize(width);
SpeakNorm = minMaxNormalize(Speak);

IpeakNormSmooth = smoothSeries(IpeakNorm, window);
widthNormSmooth = smoothSeries(widthNorm, window);
SpeakNormSmooth = smoothSeries(SpeakNorm, window);

[dIpeakNorm, ~] = computeDerivatives(temps, IpeakNormSmooth);
[dWidthNorm, ~] = computeDerivatives(temps, widthNormSmooth);
[dSpeakNorm, ~] = computeDerivatives(temps, SpeakNormSmooth);

tbl = table( ...
    temps, Ipeak, width, Speak, ...
    IpeakNorm, widthNorm, SpeakNorm, ...
    IpeakSmooth, widthSmooth, SpeakSmooth, ...
    dIpeak, dWidth, dSpeak, ...
    d2Ipeak, d2Width, d2Speak, ...
    dIpeakNorm, dWidthNorm, dSpeakNorm, ...
    'VariableNames', {'T_K','I_peak_mA','width_mA','S_peak', ...
    'I_peak_norm','width_norm','S_peak_norm', ...
    'I_peak_smooth','width_smooth','S_peak_smooth', ...
    'dI_peak_dT_mA_per_K','dwidth_dT_mA_per_K','dS_peak_dT_per_K', ...
    'd2I_peak_dT2','d2width_dT2','d2S_peak_dT2', ...
    'dI_peak_norm_dT_per_K','dwidth_norm_dT_per_K','dS_peak_norm_dT_per_K'});
end

function ySmooth = smoothSeries(y, window)
if numel(y) < 3
    ySmooth = y(:);
    return;
end
ySmooth = smoothdata(y(:), 'movmean', window);
end

function [d1, d2] = computeDerivatives(x, y)
d1 = gradient(y(:), x(:));
d2 = gradient(d1, x(:));
end

function yNorm = minMaxNormalize(y)
y = y(:);
yMin = min(y);
yMax = max(y);
if ~isfinite(yMin) || ~isfinite(yMax) || abs(yMax - yMin) <= eps
    yNorm = zeros(size(y));
else
    yNorm = (y - yMin) ./ (yMax - yMin);
end
end

function tbl = buildCharacteristicPointsTable(geometryTbl, relaxationPeakTemp_K)
observables = { ...
    'I_peak', geometryTbl.I_peak_mA, geometryTbl.I_peak_smooth, geometryTbl.dI_peak_dT_mA_per_K, geometryTbl.d2I_peak_dT2; ...
    'width', geometryTbl.width_mA, geometryTbl.width_smooth, geometryTbl.dwidth_dT_mA_per_K, geometryTbl.d2width_dT2; ...
    'S_peak', geometryTbl.S_peak, geometryTbl.S_peak_smooth, geometryTbl.dS_peak_dT_per_K, geometryTbl.d2S_peak_dT2};

rows = {};
for i = 1:size(observables, 1)
    obsName = observables{i, 1};
    rawVals = observables{i, 2};
    smoothVals = observables{i, 3};
    d1 = observables{i, 4};
    d2 = observables{i, 5};
    temps = geometryTbl.T_K;

    [maxVal, idxMax] = max(rawVals);
    rows(end+1, :) = makeFeatureRow(obsName, "global_maximum", temps(idxMax), maxVal, relaxationPeakTemp_K); %#ok<AGROW>

    [minVal, idxMin] = min(rawVals);
    rows(end+1, :) = makeFeatureRow(obsName, "global_minimum", temps(idxMin), minVal, relaxationPeakTemp_K); %#ok<AGROW>

    [maxSlope, idxSlopeMax] = max(d1);
    rows(end+1, :) = makeFeatureRow(obsName, "derivative_maximum", temps(idxSlopeMax), maxSlope, relaxationPeakTemp_K); %#ok<AGROW>

    [minSlope, idxSlopeMin] = min(d1);
    rows(end+1, :) = makeFeatureRow(obsName, "derivative_minimum", temps(idxSlopeMin), minSlope, relaxationPeakTemp_K); %#ok<AGROW>

    inflections = estimateZeroCrossings(temps, d2, smoothVals);
    if isempty(inflections)
        rows(end+1, :) = {string(obsName), "inflection", NaN, NaN, NaN, false}; %#ok<AGROW>
    else
        for j = 1:size(inflections, 1)
            rows(end+1, :) = {string(obsName), "inflection", inflections(j, 1), inflections(j, 2), ...
                inflections(j, 1) - relaxationPeakTemp_K, abs(inflections(j, 1) - relaxationPeakTemp_K) <= 2}; %#ok<AGROW>
        end
    end
end

tbl = cell2table(rows, 'VariableNames', ...
    {'observable','feature_type','temperature_K','value','delta_from_26K','within_2K_of_26K'});
end

function row = makeFeatureRow(observable, featureType, temperature, value, relaxationPeakTemp_K)
row = {string(observable), string(featureType), temperature, value, ...
    temperature - relaxationPeakTemp_K, abs(temperature - relaxationPeakTemp_K) <= 2};
end

function crossings = estimateZeroCrossings(x, y, refValues)
x = x(:);
y = y(:);
refValues = refValues(:);
crossings = zeros(0, 2);

for k = 1:(numel(x) - 1)
    y1 = y(k);
    y2 = y(k + 1);
    if ~isfinite(y1) || ~isfinite(y2)
        continue;
    end
    if y1 == 0
        crossings(end+1, :) = [x(k), refValues(k)]; %#ok<AGROW>
        continue;
    end
    if y1 * y2 < 0
        xCross = x(k) - y1 * (x(k + 1) - x(k)) / (y2 - y1);
        refCross = interp1(x([k k+1]), refValues([k k+1]), xCross, 'linear');
        crossings(end+1, :) = [xCross, refCross]; %#ok<AGROW>
    end
end
end

function tbl = buildNearPeakComparisonTable(geometryTbl, relaxationPeakTemp_K)
observableNames = ["I_peak", "width", "S_peak"]';
valuesAtPeak = [ ...
    interpolateAtTemperature(geometryTbl.T_K, geometryTbl.I_peak_mA, relaxationPeakTemp_K); ...
    interpolateAtTemperature(geometryTbl.T_K, geometryTbl.width_mA, relaxationPeakTemp_K); ...
    interpolateAtTemperature(geometryTbl.T_K, geometryTbl.S_peak, relaxationPeakTemp_K)];
rawSlopes = [ ...
    interpolateAtTemperature(geometryTbl.T_K, geometryTbl.dI_peak_dT_mA_per_K, relaxationPeakTemp_K); ...
    interpolateAtTemperature(geometryTbl.T_K, geometryTbl.dwidth_dT_mA_per_K, relaxationPeakTemp_K); ...
    interpolateAtTemperature(geometryTbl.T_K, geometryTbl.dS_peak_dT_per_K, relaxationPeakTemp_K)];
normSlopes = [ ...
    interpolateAtTemperature(geometryTbl.T_K, geometryTbl.dI_peak_norm_dT_per_K, relaxationPeakTemp_K); ...
    interpolateAtTemperature(geometryTbl.T_K, geometryTbl.dwidth_norm_dT_per_K, relaxationPeakTemp_K); ...
    interpolateAtTemperature(geometryTbl.T_K, geometryTbl.dS_peak_norm_dT_per_K, relaxationPeakTemp_K)];

windowMask = abs(geometryTbl.T_K - relaxationPeakTemp_K) <= 2;
windowTemps = geometryTbl.T_K(windowMask);
maxWindowNormSlope = [ ...
    max(abs(geometryTbl.dI_peak_norm_dT_per_K(windowMask))); ...
    max(abs(geometryTbl.dwidth_norm_dT_per_K(windowMask))); ...
    max(abs(geometryTbl.dS_peak_norm_dT_per_K(windowMask)))];
windowPeakTemp = [ ...
    findPeakSlopeTemperature(windowTemps, geometryTbl.dI_peak_norm_dT_per_K(windowMask)); ...
    findPeakSlopeTemperature(windowTemps, geometryTbl.dwidth_norm_dT_per_K(windowMask)); ...
    findPeakSlopeTemperature(windowTemps, geometryTbl.dS_peak_norm_dT_per_K(windowMask))];

geometricRole = ["ridge_position"; "ridge_width"; "ridge_amplitude"];
tbl = table(observableNames, geometricRole, valuesAtPeak, rawSlopes, normSlopes, maxWindowNormSlope, windowPeakTemp, ...
    'VariableNames', {'observable','geometric_role','value_at_26K','raw_derivative_at_26K', ...
    'normalized_derivative_at_26K','max_abs_normalized_derivative_within_24_28K','temperature_of_max_abs_slope_within_24_28K'});

[~, rankIdx] = sort(abs(tbl.normalized_derivative_at_26K), 'descend');
rank = zeros(height(tbl), 1);
rank(rankIdx) = 1:height(tbl);
tbl.rank_by_abs_normalized_derivative_at_26K = rank;
end

function value = interpolateAtTemperature(x, y, xq)
value = interp1(x(:), y(:), xq, 'linear', 'extrap');
end

function peakTemp = findPeakSlopeTemperature(temps, slopes)
if isempty(temps)
    peakTemp = NaN;
    return;
end
[~, idx] = max(abs(slopes));
peakTemp = temps(idx);
end

function tbl = buildScatterCorrelationTable(geometryTbl)
pairs = {
    'I_peak_vs_width', geometryTbl.I_peak_mA, geometryTbl.width_mA;
    'width_vs_S_peak', geometryTbl.width_mA, geometryTbl.S_peak;
    'I_peak_vs_S_peak', geometryTbl.I_peak_mA, geometryTbl.S_peak};

rows = cell(size(pairs, 1), 4);
for i = 1:size(pairs, 1)
    x = pairs{i, 2};
    y = pairs{i, 3};
    rows{i, 1} = string(pairs{i, 1});
    rows{i, 2} = corr(x, y, 'Rows', 'complete');
    rows{i, 3} = corr(x, y, 'Rows', 'complete', 'Type', 'Spearman');
    rows{i, 4} = nnz(isfinite(x) & isfinite(y));
end

tbl = cell2table(rows, 'VariableNames', {'comparison','pearson_r','spearman_rho','n_points'});
end

function plotObservableVsTemperature(ax, temps, values, relaxationPeakTemp_K, seriesLabel, yLabelText, titleText)
hold(ax, 'on');
grid(ax, 'on');
plot(ax, temps, values, '-o', 'MarkerFaceColor', [0.12 0.45 0.70], 'Color', [0.12 0.45 0.70], ...
    'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', seriesLabel);
xline(ax, relaxationPeakTemp_K, '--', sprintf('%.0f K relaxation peak', relaxationPeakTemp_K), ...
    'Color', [0.25 0.25 0.25], 'LineWidth', 1.8, 'LabelVerticalAlignment', 'bottom');
styleAxes(ax, 'T (K)', yLabelText, titleText);
end

function plotDerivativePanel(ax, temps, derivValues, relaxationPeakTemp_K, yLabelText, titleText)
hold(ax, 'on');
grid(ax, 'on');
plot(ax, temps, derivValues, '-o', 'Color', [0.80 0.27 0.24], 'MarkerFaceColor', [0.80 0.27 0.24], ...
    'LineWidth', 2.2, 'MarkerSize', 5);
yline(ax, 0, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
xline(ax, relaxationPeakTemp_K, '--', '26 K', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.6);
styleAxes(ax, 'T (K)', yLabelText, titleText);
end

function plotNormalizedOverlay(ax, geometryTbl, relaxationPeakTemp_K)
hold(ax, 'on');
grid(ax, 'on');
plot(ax, geometryTbl.T_K, geometryTbl.I_peak_norm, '-o', 'Color', [0.14 0.48 0.67], ...
    'MarkerFaceColor', [0.14 0.48 0.67], 'DisplayName', 'I_{peak} norm');
plot(ax, geometryTbl.T_K, geometryTbl.width_norm, '-s', 'Color', [0.20 0.63 0.17], ...
    'MarkerFaceColor', [0.20 0.63 0.17], 'DisplayName', 'width norm');
plot(ax, geometryTbl.T_K, geometryTbl.S_peak_norm, '-^', 'Color', [0.84 0.37 0.00], ...
    'MarkerFaceColor', [0.84 0.37 0.00], 'DisplayName', 'S_{peak} norm');
xline(ax, relaxationPeakTemp_K, '--', '26 K', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.6);
styleAxes(ax, 'T (K)', 'Normalized observable (0-1)', 'Normalized switching-geometry overlays');
legend(ax, 'Location', 'best');
end

function plotScatterPanel(ax, x, y, temps, xLabelText, yLabelText, titleText)
hold(ax, 'on');
grid(ax, 'on');
plot(ax, x, y, '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 1.4, 'HandleVisibility', 'off');
scatter(ax, x, y, 64, temps, 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.8);
colormap(ax, parula(256));
cb = colorbar(ax);
ylabel(cb, 'T (K)');
styleAxes(ax, xLabelText, yLabelText, titleText);
end

function styleAxes(ax, xLabelText, yLabelText, titleText)
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'Box', 'off');
xlabel(ax, xLabelText, 'FontSize', 16);
ylabel(ax, yLabelText, 'FontSize', 16);
title(ax, titleText, 'FontSize', 16);
end

function reportText = buildReportText( ...
    sourceManifest, sourceCfg, geometryTbl, featureTbl, nearPeakTbl, scatterTbl, ...
    figIpeakPath, figWidthPath, figSpeakPath, figDerivativePath, ...
    figNormPath, figScatterPath, geometryOut, featureOut, nearPeakOut, scatterOut, ...
    relaxationPeakTemp_K, derivativeSmoothingWindow)

dataset = string(getStructField(sourceManifest, 'dataset', 'unknown'));
sourceRunId = string(getStructField(sourceManifest, 'run_id', 'unknown'));
widthRule = string(getStructField(sourceCfg, 'widthRule', 'width_chosen_mA from scaling-parameter table'));

[~, driverIdx] = min(nearPeakTbl.rank_by_abs_normalized_derivative_at_26K);
driverObservable = string(nearPeakTbl.observable(driverIdx));
driverRole = string(nearPeakTbl.geometric_role(driverIdx));
driverSlope = nearPeakTbl.normalized_derivative_at_26K(driverIdx);

strongestScatterIdx = find(abs(scatterTbl.spearman_rho) == max(abs(scatterTbl.spearman_rho)), 1, 'first');
strongestScatter = scatterTbl(strongestScatterIdx, :);

summaryI = describeObservableEvolution('I_{peak}', geometryTbl.T_K, geometryTbl.I_peak_mA, 'mA');
summaryWidth = describeObservableEvolution('width', geometryTbl.T_K, geometryTbl.width_mA, 'mA');
summarySpeak = describeObservableEvolution('S_{peak}', geometryTbl.T_K, geometryTbl.S_peak, '');

inflectionLines = buildInflectionSummary(featureTbl);
nearPeakLines = buildNearPeakSummary(nearPeakTbl);

driverText = describeDriver(driverObservable, driverRole, driverSlope, relaxationPeakTemp_K);

lines = [
    "# Switching Geometry Diagnostics"
    ""
    "## Source"
    "- Input run: `" + sourceRunId + "`"
    "- Dataset: `" + dataset + "`"
    "- Width definition inherited from source run: " + widthRule
    "- Derivatives were computed after light `movmean` smoothing with a " + string(derivativeSmoothingWindow) + "-point window."
    ""
    "## Temperature Evolution of Switching Geometry"
    "- " + summaryI
    "- " + summaryWidth
    "- " + summarySpeak
    ""
    "## Observable Trends"
    "### I_{peak}(T)"
    "![Ipeak vs T](../figures/" + string(getFileName(figIpeakPath)) + ")"
    ""
    "### width(T)"
    "![width vs T](../figures/" + string(getFileName(figWidthPath)) + ")"
    ""
    "### S_{peak}(T)"
    "![Speak vs T](../figures/" + string(getFileName(figSpeakPath)) + ")"
    ""
    "## Derivatives vs Temperature"
    "![Derivatives vs T](../figures/" + string(getFileName(figDerivativePath)) + ")"
    ""
    "## Characteristic Points"
    inflectionLines
    ""
    "## Comparison with the Relaxation Peak near " + sprintf('%.0f', relaxationPeakTemp_K) + " K"
    nearPeakLines
    ""
    "## Normalized Overlays"
    "![Normalized overlays](../figures/" + string(getFileName(figNormPath)) + ")"
    ""
    "## Scatter Comparisons"
    "![Scatter comparisons](../figures/" + string(getFileName(figScatterPath)) + ")"
    "- Strongest monotonic scatter relation: `" + string(strongestScatter.comparison) + "` with Spearman rho = " + sprintf('%.3f', strongestScatter.spearman_rho) + "."
    ""
    "## Interpretation"
    driverText
    ""
    "## Visualization Choices"
    "- Number of curves: 1 curve in each single-observable panel, 3 curves in the normalized overlay, and 14 temperature-coded points in each scatter panel."
    "- Legend vs colormap: single-observable panels use no legend, the normalized overlay uses an explicit legend, and the scatter panels use a `parula` colorbar because more than 6 temperatures are shown."
    "- Colormap used: `parula` for temperature-coded scatter panels."
    "- Smoothing applied: `movmean` with a 3-point window before derivative evaluation."
    "- Justification: the derivative smoothing suppresses point-to-point noise without erasing the broad crossover-scale evolution around 26 K."
    ""
    "## Artifacts"
    "- Observables table: `" + string(geometryOut) + "`"
    "- Characteristic-points table: `" + string(featureOut) + "`"
    "- Near-26 K comparison table: `" + string(nearPeakOut) + "`"
    "- Scatter-correlation table: `" + string(scatterOut) + "`"
    ""
    "---"
    "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))
];

reportText = strjoin(lines, newline);
end

function textLine = describeObservableEvolution(nameText, temps, values, unitText)
[maxVal, idxMax] = max(values);
[minVal, idxMin] = min(values);
startVal = values(1);
endVal = values(end);
deltaVal = endVal - startVal;

if isempty(unitText)
    unitSuffix = '';
else
    unitSuffix = [' ' unitText];
end

textLine = sprintf('%s changes from %.4f%s at %.0f K to %.4f%s at %.0f K (delta = %.4f%s); global maximum at %.0f K and global minimum at %.0f K.', ...
    nameText, startVal, unitSuffix, temps(1), endVal, unitSuffix, temps(end), deltaVal, unitSuffix, temps(idxMax), temps(idxMin));
end

function summary = buildInflectionSummary(featureTbl)
lines = strings(0, 1);
observables = unique(featureTbl.observable, 'stable');
for i = 1:numel(observables)
    obsMask = featureTbl.observable == observables(i) & featureTbl.feature_type == "inflection" & isfinite(featureTbl.temperature_K);
    temps = featureTbl.temperature_K(obsMask);
    if isempty(temps)
        lines(end+1, 1) = "- `" + observables(i) + "`: no resolved inflection point from the smoothed second derivative."; %#ok<AGROW>
    else
        lines(end+1, 1) = "- `" + observables(i) + "` inflection temperatures: " + strjoin(compose('%.2f K', temps), ', ') + "."; %#ok<AGROW>
    end
end
summary = strjoin(lines, newline);
end

function summary = buildNearPeakSummary(nearPeakTbl)
tbl = sortrows(nearPeakTbl, 'rank_by_abs_normalized_derivative_at_26K', 'ascend');
lines = strings(height(tbl), 1);
for i = 1:height(tbl)
    lines(i) = "- `" + tbl.observable(i) + "` (" + tbl.geometric_role(i) + "): value at 26 K = " + ...
        sprintf('%.4f', tbl.value_at_26K(i)) + ", normalized derivative at 26 K = " + ...
        sprintf('%.4f', tbl.normalized_derivative_at_26K(i)) + ", strongest |normalized slope| within 24-28 K occurs at " + ...
        sprintf('%.0f K', tbl.temperature_of_max_abs_slope_within_24_28K(i)) + ".";
end
summary = strjoin(lines, newline);
end

function textLine = describeDriver(driverObservable, driverRole, driverSlope, relaxationPeakTemp_K)
switch driverObservable
    case "I_peak"
        roleDescription = 'the current position of the switching ridge';
    case "width"
        roleDescription = 'the current span / sharpness of the switching ridge';
    case "S_peak"
        roleDescription = 'the peak switching amplitude';
    otherwise
        roleDescription = char(driverRole);
end

direction = 'decreases';
if driverSlope > 0
    direction = 'increases';
end

textLine = "The largest absolute normalized derivative at " + sprintf('%.0f', relaxationPeakTemp_K) + ...
    " K belongs to `" + driverObservable + "`, so the dominant geometric change near the relaxation crossover is " + ...
    roleDescription + ". In the immediate 26 K neighborhood this observable " + direction + ...
    " most sharply, which points to " + roleDescription + " as the geometric element most likely controlling the switching crossover.";
end

function name = getFileName(filePath)
[~, baseName, ext] = fileparts(char(string(filePath)));
name = [baseName ext];
end

function appendRunNotes(notesPath, reportText)
fid = fopen(notesPath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append run notes at %s.', notesPath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', reportText);
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function value = getStructField(s, fieldName, defaultValue)
if nargin < 3
    defaultValue = '';
end
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
end
end
