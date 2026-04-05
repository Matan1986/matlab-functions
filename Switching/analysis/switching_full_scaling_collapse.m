% switching_full_scaling_collapse
% Test the stronger shift-and-scale collapse hypothesis for switching curves.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

if ~exist('sourceRunId', 'var') || isempty(sourceRunId)
    sourceRunId = "run_2026_03_10_112659_alignment_audit";
end
if ~exist('comparisonRunId', 'var') || isempty(comparisonRunId)
    comparisonRunId = "run_2026_03_12_231143_switching_energy_scale_collapse_filtered";
end
if ~exist('tempRange_K', 'var') || isempty(tempRange_K)
    tempRange_K = [4 30];
end
if ~exist('excludeTemps_K', 'var') || isempty(excludeTemps_K)
    excludeTemps_K = [32 34];
end
if ~exist('defaultPreviousMetric', 'var') || isempty(defaultPreviousMetric)
    defaultPreviousMetric = 0.1078;
end

[sourceRunDir, sourceAnalysisDir, sourceManifest] = resolveSourceAlignmentRun(repoRoot, sourceRunId);
previousMetricInfo = loadPreviousCollapseMetric(repoRoot, comparisonRunId, defaultPreviousMetric);

cfgRun = struct();
cfgRun.runLabel = 'switching_full_scaling_collapse';
cfgRun.dataset = getManifestField(sourceManifest, 'dataset', '');
cfgRun.sourceRunId = getManifestField(sourceManifest, 'run_id', '');
cfgRun.sourceRunDir = sourceRunDir;
cfgRun.comparisonRunId = comparisonRunId;
cfgRun.tempRange_K = tempRange_K;
cfgRun.excludeTemps_K = excludeTemps_K;
cfgRun.widthRule = 'Interpolated FWHM preferred; weighted local sigma fallback.';
run = createSwitchingRunContext(repoRoot, cfgRun);
runDir = run.run_dir;

fprintf('switching run directory:\n%s\n', runDir);
fprintf('source alignment run:\n%s\n', sourceRunDir);
fprintf('comparison filtered-collapse run:\n%s\n', previousMetricInfo.run_dir);

obsCsv = fullfile(sourceAnalysisDir, 'switching_alignment_observables_vs_T.csv');
samplesCsv = fullfile(sourceAnalysisDir, 'switching_alignment_samples.csv');
assert(isfile(obsCsv), 'Missing observables file: %s', obsCsv);
assert(isfile(samplesCsv), 'Missing samples file: %s', samplesCsv);

obsTbl = readtable(obsCsv);
samplesTbl = readtable(samplesCsv);

[tempsMap, currents, Smap] = buildSwitchingMapRounded(samplesTbl);
obsTemps = readNumericColumn(obsTbl, 'T_K');
[tempsAll, iaObs, iaMap] = intersect(obsTemps, tempsMap, 'stable');
assert(~isempty(tempsAll), 'No overlapping temperatures between observables and switching map.');
SmapAll = Smap(iaMap, :);

keepMask = tempsAll >= tempRange_K(1) & tempsAll <= tempRange_K(2) & ~ismember(round(tempsAll), round(excludeTemps_K));
assert(any(keepMask), 'No temperatures remain after applying the requested filter.');

temps = tempsAll(keepMask);
Smap = SmapAll(keepMask, :);

paramsTbl = buildScalingParametersTable(temps, currents, Smap);
assert(all(isfinite(paramsTbl.width_chosen_mA)), 'Chosen widths contain non-finite values.');
assert(all(isfinite(paramsTbl.width_sigma_mA)), 'Sigma widths contain non-finite values.');

paramsOut = save_run_table(paramsTbl, 'switching_full_scaling_parameters.csv', runDir);

collapseChosen = collectScaledCurves(paramsTbl, currents, Smap, paramsTbl.width_chosen_mA);
metricsChosen = evaluateCollapse(collapseChosen, []);

collapseSigma = collectScaledCurves(paramsTbl, currents, Smap, paramsTbl.width_sigma_mA);
metricsSigma = evaluateCollapse(collapseSigma, []);

exclude30Mask = abs(paramsTbl.T_K - 30) > 1e-9;
collapseNo30 = collectScaledCurves(paramsTbl(exclude30Mask, :), currents, Smap(exclude30Mask, :), paramsTbl.width_chosen_mA(exclude30Mask));
metricsNo30 = evaluateCollapse(collapseNo30, []);

metricsTbl = table( ...
    ["previous_alignment_filtered"; "full_scaling_chosen"; "full_scaling_sigma"; "full_scaling_chosen_excluding_30K"], ...
    [previousMetricInfo.n_curves; metricsChosen.num_curves; metricsSigma.num_curves; metricsNo30.num_curves], ...
    [string(previousMetricInfo.width_definition); "fwhm_preferred_sigma_fallback"; "sigma_all_temperatures"; "fwhm_preferred_sigma_fallback"], ...
    [string(previousMetricInfo.temperature_selection); formatTempList(paramsTbl.T_K); formatTempList(paramsTbl.T_K); formatTempList(paramsTbl.T_K(exclude30Mask))], ...
    [previousMetricInfo.common_range_min; metricsChosen.common_range_min; metricsSigma.common_range_min; metricsNo30.common_range_min], ...
    [previousMetricInfo.common_range_max; metricsChosen.common_range_max; metricsSigma.common_range_max; metricsNo30.common_range_max], ...
    [previousMetricInfo.mean_std; metricsChosen.mean_std; metricsSigma.mean_std; metricsNo30.mean_std], ...
    [previousMetricInfo.mean_rmse_to_mean; metricsChosen.mean_rmse_to_mean; metricsSigma.mean_rmse_to_mean; metricsNo30.mean_rmse_to_mean], ...
    [0; metricsChosen.mean_std - previousMetricInfo.mean_std; metricsSigma.mean_std - previousMetricInfo.mean_std; metricsNo30.mean_std - previousMetricInfo.mean_std], ...
    'VariableNames', {'analysis_name','n_curves','width_definition','temperature_selection','common_range_min','common_range_max','mean_intercurve_std','mean_rmse_to_mean','delta_vs_previous_metric'});
metricsOut = save_run_table(metricsTbl, 'switching_full_scaling_metrics.csv', runDir);

plotLimits = computePlotLimits(collapseChosen, collapseSigma, collapseNo30);

figCollapse = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 980 720]);
axCollapse = axes(figCollapse);
summaryText = sprintf([ ...
    'Temperatures: %s\n' ...
    'Chosen width metric: %.4f\n' ...
    'Previous aligned metric: %.4f\n' ...
    'Sigma-width metric: %.4f\n' ...
    'Chosen metric without 30 K: %.4f'], ...
    formatTempList(paramsTbl.T_K), metricsChosen.mean_std, previousMetricInfo.mean_std, metricsSigma.mean_std, metricsNo30.mean_std);
plotCollapseAxes(axCollapse, collapseChosen, ...
    'Full scaling collapse: S/S_{peak} vs (I-I_{peak})/width', summaryText, metricsChosen, plotLimits, true);
collapseFigPaths = save_run_figure(figCollapse, 'switching_full_scaling_collapse', runDir);
close(figCollapse);

figCurves = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1450 620]);
tlCurves = tiledlayout(figCurves, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axRaw = nexttile(tlCurves, 1);
plotTemperatureCurves(axRaw, paramsTbl, currents, Smap);

axWidth = nexttile(tlCurves, 2);
plotWidthSummary(axWidth, paramsTbl);

tempCurvesFigPaths = save_run_figure(figCurves, 'switching_full_scaling_collapse_temperature_curves', runDir);
close(figCurves);

reportText = buildReportText( ...
    sourceManifest, previousMetricInfo, paramsTbl, metricsChosen, metricsSigma, metricsNo30, ...
    collapseFigPaths.png, tempCurvesFigPaths.png, paramsOut, metricsOut);
reportOut = save_run_report(reportText, 'switching_full_scaling_collapse.md', runDir);

appendRunNotes(run.notes_path, reportText);
zipOut = buildReviewZip(runDir, 'switching_full_scaling_collapse_bundle.zip');

fprintf('Saved collapse figure: %s\n', collapseFigPaths.png);
fprintf('Saved temperature-curves figure: %s\n', tempCurvesFigPaths.png);
fprintf('Saved parameters table: %s\n', paramsOut);
fprintf('Saved metrics table: %s\n', metricsOut);
fprintf('Saved report: %s\n', reportOut);
fprintf('Saved review ZIP: %s\n', zipOut);

function [runDir, analysisDir, manifest] = resolveSourceAlignmentRun(repoRoot, sourceRunId)
runsRoot = switchingCanonicalRunRoot(repoRoot);
runDir = fullfile(runsRoot, char(string(sourceRunId)));
analysisDir = fullfile(runDir, 'alignment_audit');
assert(exist(runDir, 'dir') == 7, 'Requested source run does not exist: %s', runDir);
assert(exist(analysisDir, 'dir') == 7, 'Requested source run lacks alignment_audit outputs: %s', analysisDir);
manifest = struct();
manifestPath = fullfile(runDir, 'run_manifest.json');
if exist(manifestPath, 'file') == 2
    manifest = jsondecode(fileread(manifestPath));
end
end

function info = loadPreviousCollapseMetric(repoRoot, comparisonRunId, defaultMetric)
info = struct();
info.run_id = char(string(comparisonRunId));
info.run_dir = fullfile(switchingCanonicalRunRoot(repoRoot), char(string(comparisonRunId)));
info.common_range_min = NaN;
info.common_range_max = NaN;
info.mean_std = defaultMetric;
info.mean_rmse_to_mean = NaN;
info.n_curves = 14;
info.width_definition = 'I_over_Ipeak_reference';
info.temperature_selection = '4 K, 6 K, 8 K, 10 K, 12 K, 14 K, 16 K, 18 K, 20 K, 22 K, 24 K, 26 K, 28 K, 30 K';

metricsPath = fullfile(info.run_dir, 'tables', 'switching_energy_scale_collapse_metrics.csv');
if exist(metricsPath, 'file') ~= 2
    return;
end

metricsTbl = readtable(metricsPath);
rowMask = strcmp(string(metricsTbl.selection_name), "filtered_temperatures_shared_range");
if any(rowMask)
    row = metricsTbl(find(rowMask, 1, 'first'), :);
    info.common_range_min = row.common_range_min;
    info.common_range_max = row.common_range_max;
    info.mean_std = row.mean_intercurve_std;
    info.mean_rmse_to_mean = row.mean_rmse_to_mean;
    info.n_curves = row.n_curves;
end
end

function value = getManifestField(manifest, fieldName, defaultValue)
if nargin < 3
    defaultValue = '';
end
if isstruct(manifest) && isfield(manifest, fieldName) && ~isempty(manifest.(fieldName))
    value = manifest.(fieldName);
else
    value = defaultValue;
end
end

function values = readNumericColumn(tbl, varName)
assert(ismember(varName, tbl.Properties.VariableNames), ...
    'Table is missing required column "%s".', varName);
values = tbl.(varName);
if iscell(values) || isstring(values) || iscategorical(values)
    values = str2double(string(values));
else
    values = double(values);
end
values = values(:);
end

function [temps, currents, Smap] = buildSwitchingMapRounded(samplesTbl)
tempsRaw = readNumericColumn(samplesTbl, 'T_K');
currentsRaw = readNumericColumn(samplesTbl, 'current_mA');
signalRaw = readNumericColumn(samplesTbl, 'S_percent');

tempsUnique = unique(tempsRaw(isfinite(tempsRaw)));
currents = unique(currentsRaw(isfinite(currentsRaw)));
tempsUnique = sort(tempsUnique(:));
currents = sort(currents(:));

SmapRaw = NaN(numel(tempsUnique), numel(currents));
for it = 1:numel(tempsUnique)
    for ii = 1:numel(currents)
        mask = abs(tempsRaw - tempsUnique(it)) < 1e-9 & abs(currentsRaw - currents(ii)) < 1e-9;
        if any(mask)
            SmapRaw(it, ii) = mean(signalRaw(mask), 'omitnan');
        end
    end
end

tempsRounded = round(tempsUnique);
[temps, ~, roundedIdx] = unique(tempsRounded, 'sorted');
Smap = NaN(numel(temps), numel(currents));
for k = 1:numel(temps)
    mask = roundedIdx == k;
    Smap(k, :) = mean(SmapRaw(mask, :), 1, 'omitnan');
end
temps = temps(:);
currents = currents(:)';
end

function paramsTbl = buildScalingParametersTable(temps, currents, Smap)
nTemps = numel(temps);
Ipeak = NaN(nTemps, 1);
S_peak = NaN(nTemps, 1);
leftHalf = NaN(nTemps, 1);
rightHalf = NaN(nTemps, 1);
widthFwhm = NaN(nTemps, 1);
widthSigma = NaN(nTemps, 1);
widthChosen = NaN(nTemps, 1);
widthMethod = strings(nTemps, 1);
nValidPoints = NaN(nTemps, 1);
peakIndex = NaN(nTemps, 1);

for it = 1:nTemps
    row = Smap(it, :);
    valid = isfinite(row) & isfinite(currents);
    currValid = currents(valid);
    rowValid = row(valid);
    nValidPoints(it) = nnz(valid);
    assert(numel(currValid) >= 3, 'Not enough valid current points at T = %.2f K.', temps(it));

    [S_peak(it), idxPeak] = max(rowValid);
    Ipeak(it) = currValid(idxPeak);
    peakIndex(it) = idxPeak;

    [widthFwhm(it), leftHalf(it), rightHalf(it)] = estimateFwhmWidth(currValid, rowValid, idxPeak, S_peak(it));
    widthSigma(it) = estimateSigmaWidth(currValid, rowValid, idxPeak, Ipeak(it), S_peak(it));

    if isfinite(widthFwhm(it)) && widthFwhm(it) > eps
        widthChosen(it) = widthFwhm(it);
        widthMethod(it) = "fwhm";
    elseif isfinite(widthSigma(it)) && widthSigma(it) > eps
        widthChosen(it) = widthSigma(it);
        widthMethod(it) = "sigma_fallback";
    else
        error('Unable to determine a finite width for T = %.2f K.', temps(it));
    end
end

paramsTbl = table( ...
    temps(:), Ipeak(:), S_peak(:), leftHalf(:), rightHalf(:), widthFwhm(:), ...
    widthSigma(:), widthChosen(:), widthMethod(:), nValidPoints(:), peakIndex(:), ...
    'VariableNames', {'T_K','Ipeak_mA','S_peak','left_half_current_mA','right_half_current_mA', ...
    'width_fwhm_mA','width_sigma_mA','width_chosen_mA','width_method','n_valid_points','peak_index'});
end

function [widthFwhm, leftCross, rightCross] = estimateFwhmWidth(curr, sig, idxPeak, sPeak)
widthFwhm = NaN;
leftCross = NaN;
rightCross = NaN;
if ~isfinite(sPeak) || sPeak <= eps
    return;
end

halfLevel = 0.5 * sPeak;

for j = idxPeak:-1:2
    y1 = sig(j-1);
    y2 = sig(j);
    if y1 < halfLevel && y2 >= halfLevel
        leftCross = linearCrossing(curr(j-1), y1, curr(j), y2, halfLevel);
        break;
    elseif y1 == halfLevel
        leftCross = curr(j-1);
        break;
    end
end

for j = idxPeak:(numel(curr)-1)
    y1 = sig(j);
    y2 = sig(j+1);
    if y1 >= halfLevel && y2 < halfLevel
        rightCross = linearCrossing(curr(j), y1, curr(j+1), y2, halfLevel);
        break;
    elseif y2 == halfLevel
        rightCross = curr(j+1);
        break;
    end
end

if isfinite(leftCross) && isfinite(rightCross) && rightCross > leftCross
    widthFwhm = rightCross - leftCross;
end
end

function xCross = linearCrossing(x1, y1, x2, y2, yTarget)
if abs(y2 - y1) <= eps
    xCross = 0.5 * (x1 + x2);
else
    xCross = x1 + (yTarget - y1) * (x2 - x1) / (y2 - y1);
end
end

function widthSigma = estimateSigmaWidth(curr, sig, idxPeak, Ipeak, sPeak)
widthSigma = NaN;
if ~isfinite(sPeak) || sPeak <= eps
    return;
end

mask = sig >= 0.5 * sPeak;
if nnz(mask) < 3
    left = max(1, idxPeak - 1);
    right = min(numel(curr), idxPeak + 1);
    mask = false(size(sig));
    mask(left:right) = true;
end
if nnz(mask) < 3
    left = max(1, idxPeak - 2);
    right = min(numel(curr), idxPeak + 2);
    mask = false(size(sig));
    mask(left:right) = true;
end

currLocal = curr(mask);
sigLocal = max(sig(mask), 0);
if numel(currLocal) < 2
    return;
end
if sum(sigLocal) <= eps
    sigLocal = ones(size(currLocal));
end

widthSigma = sqrt(sum(sigLocal .* (currLocal - Ipeak).^2) / sum(sigLocal));
end

function collapse = collectScaledCurves(paramsTbl, currents, Smap, widthVec)
curveTemps = [];
xCurves = {};
yCurves = {};

for it = 1:height(paramsTbl)
    widthVal = widthVec(it);
    if ~isfinite(widthVal) || abs(widthVal) <= eps
        continue;
    end

    row = Smap(it, :);
    valid = isfinite(row) & isfinite(currents);
    if nnz(valid) < 2
        continue;
    end

    x = (currents(valid) - paramsTbl.Ipeak_mA(it)) ./ widthVal;
    y = row(valid) ./ paramsTbl.S_peak(it);
    [x, sortIdx] = sort(x(:));
    y = y(sortIdx);
    [x, uniqueIdx] = unique(x, 'stable');
    y = y(uniqueIdx);
    if numel(x) < 2
        continue;
    end

    curveTemps(end+1, 1) = paramsTbl.T_K(it); %#ok<AGROW>
    xCurves{end+1, 1} = x; %#ok<AGROW>
    yCurves{end+1, 1} = y; %#ok<AGROW>
end

collapse = struct();
collapse.temps = curveTemps;
collapse.x = xCurves;
collapse.y = yCurves;
end

function metrics = evaluateCollapse(collapse, requestedRange)
metrics = struct( ...
    'num_curves', numel(collapse.temps), ...
    'common_range_min', NaN, ...
    'common_range_max', NaN, ...
    'mean_std', NaN, ...
    'mean_rmse_to_mean', NaN, ...
    'x_grid', [], ...
    'y_grid', []);

if numel(collapse.temps) < 2
    return;
end

xMin = cellfun(@(x) min(x), collapse.x);
xMax = cellfun(@(x) max(x), collapse.x);
commonMin = max(xMin);
commonMax = min(xMax);

if nargin < 2 || isempty(requestedRange)
    xLo = commonMin;
    xHi = commonMax;
else
    xLo = max(commonMin, requestedRange(1));
    xHi = min(commonMax, requestedRange(2));
end

if ~isfinite(xLo) || ~isfinite(xHi) || xLo >= xHi
    return;
end

xGrid = linspace(xLo, xHi, 200);
Ygrid = NaN(numel(collapse.temps), numel(xGrid));
for it = 1:numel(collapse.temps)
    Ygrid(it, :) = interp1(collapse.x{it}, collapse.y{it}, xGrid, 'linear', NaN);
end

meanCurve = mean(Ygrid, 1, 'omitnan');
pointStd = std(Ygrid, 0, 1, 'omitnan');
curveRmse = sqrt(mean((Ygrid - meanCurve).^2, 2, 'omitnan'));

metrics.common_range_min = xLo;
metrics.common_range_max = xHi;
metrics.mean_std = mean(pointStd, 'omitnan');
metrics.mean_rmse_to_mean = mean(curveRmse, 'omitnan');
metrics.x_grid = xGrid;
metrics.y_grid = Ygrid;
end

function limits = computePlotLimits(varargin)
allX = [];
allY = [];
for i = 1:nargin
    collapse = varargin{i};
    for k = 1:numel(collapse.x)
        allX = [allX; collapse.x{k}(:)]; %#ok<AGROW>
        allY = [allY; collapse.y{k}(:)]; %#ok<AGROW>
    end
end
allX = allX(isfinite(allX));
allY = allY(isfinite(allY));

if isempty(allX)
    limits.x = [-1 1];
else
    xPad = 0.05 * max(max(allX) - min(allX), eps);
    limits.x = [min(allX) - xPad, max(allX) + xPad];
end
if isempty(allY)
    limits.y = [0 1];
else
    yPad = 0.08 * max(max(allY) - min(allY), eps);
    limits.y = [min(allY) - yPad, max(allY) + yPad];
end
end

function plotCollapseAxes(ax, collapse, plotTitleText, summaryText, metrics, limits, showMeanCurve)
hold(ax, 'on');
grid(ax, 'on');

cmap = parula(256);
tMin = min(collapse.temps);
tMax = max(collapse.temps);
for it = 1:numel(collapse.temps)
    thisColor = mapTemperatureToColor(collapse.temps(it), tMin, tMax, cmap);
    plot(ax, collapse.x{it}, collapse.y{it}, '-', 'LineWidth', 1.8, 'Color', thisColor);
end
if nargin >= 7 && showMeanCurve && ~isempty(metrics.x_grid)
    meanCurve = mean(metrics.y_grid, 1, 'omitnan');
    plot(ax, metrics.x_grid, meanCurve, 'k--', 'LineWidth', 2.4);
end

colormap(ax, cmap);
if tMax > tMin
    clim(ax, [tMin tMax]);
else
    clim(ax, [tMin - 0.5, tMax + 0.5]);
end
cb = colorbar(ax);
ylabel(cb, 'T (K)');

xlabel(ax, '(I - I_{peak}(T)) / width(T)');
ylabel(ax, 'S(T,I) / S_{peak}(T)');
title(ax, plotTitleText);
xlim(ax, limits.x);
ylim(ax, limits.y);

metricText = sprintf([ ...
    '%s\n' ...
    'Common x range: [%.2f, %.2f]\n' ...
    'Black dashed line = mean collapsed curve'], ...
    summaryText, metrics.common_range_min, metrics.common_range_max);
text(ax, 0.03, 0.97, metricText, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'Margin', 6, 'FontSize', 9, 'Interpreter', 'none');
end

function plotTemperatureCurves(ax, paramsTbl, currents, Smap)
hold(ax, 'on');
grid(ax, 'on');
cmap = parula(256);
tMin = min(paramsTbl.T_K);
tMax = max(paramsTbl.T_K);
for it = 1:height(paramsTbl)
    row = Smap(it, :);
    valid = isfinite(row) & isfinite(currents);
    thisColor = mapTemperatureToColor(paramsTbl.T_K(it), tMin, tMax, cmap);
    plot(ax, currents(valid), row(valid) ./ paramsTbl.S_peak(it), '-', 'LineWidth', 1.6, 'Color', thisColor);
    scatter(ax, paramsTbl.Ipeak_mA(it), 1.0, 24, thisColor, 'filled');
    if isfinite(paramsTbl.left_half_current_mA(it)) && isfinite(paramsTbl.right_half_current_mA(it))
        plot(ax, [paramsTbl.left_half_current_mA(it) paramsTbl.right_half_current_mA(it)], [0.5 0.5], '-', ...
            'LineWidth', 1.4, 'Color', thisColor);
    end
end
colormap(ax, cmap);
if tMax > tMin
    clim(ax, [tMin tMax]);
else
    clim(ax, [tMin - 0.5, tMax + 0.5]);
end
cb = colorbar(ax);
ylabel(cb, 'T (K)');
xlabel(ax, 'Current I (mA)');
ylabel(ax, 'S(T,I) / S_{peak}(T)');
title(ax, 'Normalized temperature curves with I_{peak} and FWHM markers');
text(ax, 0.03, 0.97, 'Dots mark I_{peak}; horizontal segments mark the interpolated FWHM.', ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w', ...
    'Margin', 6, 'FontSize', 9, 'Interpreter', 'none');
end

function plotWidthSummary(ax, paramsTbl)
hold(ax, 'on');
grid(ax, 'on');
plot(ax, paramsTbl.T_K, paramsTbl.width_fwhm_mA, '-o', 'LineWidth', 1.8, 'DisplayName', 'FWHM width');
plot(ax, paramsTbl.T_K, paramsTbl.width_sigma_mA, '-s', 'LineWidth', 1.8, 'DisplayName', 'sigma width');
plot(ax, paramsTbl.T_K, paramsTbl.width_chosen_mA, '-^', 'LineWidth', 1.8, 'DisplayName', 'chosen width');
xlabel(ax, 'T (K)');
ylabel(ax, 'width(T) [mA]');
title(ax, 'Width definitions used in the scaling test');
legend(ax, 'Location', 'best');
methodSummary = sprintf('Chosen width methods: %s', strjoin(cellstr(paramsTbl.width_method), ', '));
text(ax, 0.03, 0.97, methodSummary, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'Margin', 6, 'FontSize', 9, 'Interpreter', 'none');
end

function color = mapTemperatureToColor(tempValue, tMin, tMax, cmap)
if ~isfinite(tMin) || ~isfinite(tMax) || tMax <= tMin
    color = cmap(round(size(cmap, 1) / 2), :);
    return;
end
fraction = (tempValue - tMin) / (tMax - tMin);
fraction = min(max(fraction, 0), 1);
idx = 1 + fraction * (size(cmap, 1) - 1);
idxLo = floor(idx);
idxHi = ceil(idx);
if idxLo == idxHi
    color = cmap(idxLo, :);
else
    wHi = idx - idxLo;
    wLo = 1 - wHi;
    color = wLo * cmap(idxLo, :) + wHi * cmap(idxHi, :);
end
end

function out = formatTempList(temps)
temps = temps(:)';
if isempty(temps)
    out = 'none';
    return;
end
out = strjoin(compose('%.0f K', temps), ', ');
end

function reportText = buildReportText( ...
    sourceManifest, previousMetricInfo, paramsTbl, metricsChosen, metricsSigma, metricsNo30, ...
    collapseFigPath, tempCurvesFigPath, paramsOut, metricsOut)

sourceRunId = string(getManifestField(sourceManifest, 'run_id', 'unknown'));
sourceDataset = string(getManifestField(sourceManifest, 'dataset', 'unknown'));
metricDelta = metricsChosen.mean_std - previousMetricInfo.mean_std;

if metricDelta < -0.01 && metricsSigma.mean_std <= metricsChosen.mean_std * 1.25 && metricsNo30.mean_std <= metricsChosen.mean_std * 1.25
    conclusion = 'The stronger shift-and-scale normalization improves on the previous alignment collapse and remains reasonably stable under the requested robustness checks. This supports a common master-curve description over 4-30 K.';
elseif metricDelta <= 0.01 && metricsSigma.mean_std <= metricsChosen.mean_std * 1.5 && metricsNo30.mean_std <= metricsChosen.mean_std * 1.5
    conclusion = 'The stronger scaling test is at best only marginally consistent with a universal master curve. The collapse is not decisively better than the simpler current-alignment collapse, so the evidence is mixed.';
else
    conclusion = 'The stronger shift-and-scale normalization does not robustly outperform the simpler current-alignment collapse. A single universal master curve is therefore not well supported by this dataset.';
end

lines = [
    "# Switching Full Scaling Collapse"
    ""
    "## Scaling Hypothesis"
    "We test the stronger canonical scaling form"
    ""
    "```text"
    "S(I,T) / S_peak(T)  vs  (I - I_peak(T)) / width(T)"
    "```"
    ""
    "where `width(T)` is taken from the interpolated FWHM when available, with a weighted local sigma only as a fallback."
    ""
    "## Source and Temperature Window"
    "- Source alignment run: `" + sourceRunId + "`"
    "- Dataset: `" + sourceDataset + "`"
    "- Temperatures included: " + formatTempList(paramsTbl.T_K)
    "- Excluded temperatures: 32 K, 34 K"
    ""
    "## Collapse Figure"
    "![Full scaling collapse](../figures/switching_full_scaling_collapse.png)"
    ""
    "## Width Extraction"
    "![Temperature curves and widths](../figures/switching_full_scaling_collapse_temperature_curves.png)"
    ""
    "## Quantitative Collapse Metric"
    "- Previous filtered alignment collapse metric: " + sprintf('%.4f', previousMetricInfo.mean_std)
    "- Full scaling metric with chosen widths: " + sprintf('%.4f', metricsChosen.mean_std)
    "- Full scaling metric with sigma widths for all temperatures: " + sprintf('%.4f', metricsSigma.mean_std)
    "- Full scaling metric with 30 K removed: " + sprintf('%.4f', metricsNo30.mean_std)
    "- Chosen-width common scaled-current range: " + sprintf('[%.2f, %.2f]', metricsChosen.common_range_min, metricsChosen.common_range_max)
    "- Comparison-run common range: " + sprintf('[%.2f, %.2f]', previousMetricInfo.common_range_min, previousMetricInfo.common_range_max)
    ""
    "## Interpretation"
    "- Relative to the previous `I/I_peak` alignment, the stronger scaling metric changes by " + sprintf('%.4f', metricDelta) + "."
    "- Width-definition sensitivity is captured by the difference between the chosen-width and sigma-width metrics above."
    "- The 30 K sensitivity check is captured by the `excluding_30K` metric above."
    ""
    "## Conclusion"
    conclusion
    ""
    "## Artifacts"
    "- Parameters table: `" + string(paramsOut) + "`"
    "- Metrics table: `" + string(metricsOut) + "`"
    "- Collapse figure: `" + string(collapseFigPath) + "`"
    "- Temperature/width figure: `" + string(tempCurvesFigPath) + "`"
    ""
    "---"
    "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))
];

reportText = strjoin(lines, newline);
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
