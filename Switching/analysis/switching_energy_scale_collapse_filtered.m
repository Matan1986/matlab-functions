% switching_energy_scale_collapse_filtered
% Recompute the switching energy-scale collapse using only temperatures
% that remain inside the active switching regime.

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
if ~exist('forcedRemoveTemps_K', 'var') || isempty(forcedRemoveTemps_K)
    forcedRemoveTemps_K = 34;
end
if ~exist('highTempBoundary_K', 'var') || isempty(highTempBoundary_K)
    highTempBoundary_K = 30;
end

[sourceRunDir, sourceAnalysisDir, sourceManifest] = resolveSourceAlignmentRun(repoRoot, sourceRunId);

cfgRun = struct();
cfgRun.runLabel = 'switching_energy_scale_collapse_filtered';
cfgRun.dataset = getManifestField(sourceManifest, 'dataset', '');
cfgRun.sourceRunId = getManifestField(sourceManifest, 'run_id', '');
cfgRun.sourceRunDir = sourceRunDir;
cfgRun.forcedRemoveTemps_K = forcedRemoveTemps_K;
cfgRun.highTempBoundary_K = highTempBoundary_K;
cfgRun.selectionRule = ['Remove forced temperatures plus high-temperature curves with unresolved width ' ...
    'and a peak at the lowest measured current.'];
run = createSwitchingRunContext(repoRoot, cfgRun);
runDir = run.run_dir;

fprintf('switching run directory:\n%s\n', runDir);
fprintf('source alignment run:\n%s\n', sourceRunDir);

obsCsv = fullfile(sourceAnalysisDir, 'switching_alignment_observables_vs_T.csv');
samplesCsv = fullfile(sourceAnalysisDir, 'switching_alignment_samples.csv');

assert(isfile(obsCsv), 'Missing observables file: %s', obsCsv);
assert(isfile(samplesCsv), 'Missing samples file: %s', samplesCsv);

obsTbl = readtable(obsCsv);
samplesTbl = readtable(samplesCsv);

tempsObs = readNumericColumn(obsTbl, 'T_K');
IpeakObs = readNumericColumn(obsTbl, 'Ipeak');
SpeakObs = readNumericColumn(obsTbl, 'S_peak');
widthIObs = readNumericColumn(obsTbl, 'width_I');

[tempsMap, currents, Smap] = buildSwitchingMapRounded(samplesTbl);
[temps, iaObs, iaMap] = intersect(tempsObs, tempsMap, 'stable');
assert(~isempty(temps), 'No overlapping temperatures between observables and switching map.');

Ipeak = IpeakObs(iaObs);
S_peak = SpeakObs(iaObs);
width_I = widthIObs(iaObs);
Smap = Smap(iaMap, :);

decisionTbl = buildTemperatureDecisionTable( ...
    temps, currents, Smap, Ipeak, S_peak, width_I, forcedRemoveTemps_K, highTempBoundary_K);

includeMask = decisionTbl.include_flag ~= 0;
assert(any(includeMask), 'No temperatures remained after applying the switching-regime filter.');

tempsFiltered = temps(includeMask);
IpeakFiltered = Ipeak(includeMask);
SpeakFiltered = S_peak(includeMask);
SmapFiltered = Smap(includeMask, :);

collapseAll = collectCollapseCurves(temps, currents, Smap, Ipeak, S_peak);
collapseFiltered = collectCollapseCurves(tempsFiltered, currents, SmapFiltered, IpeakFiltered, SpeakFiltered);

metricsAll = evaluateCollapse(collapseAll, []);
metricsFiltered = evaluateCollapse(collapseFiltered, []);

sharedRange = [ ...
    max(metricsAll.common_range_min, metricsFiltered.common_range_min), ...
    min(metricsAll.common_range_max, metricsFiltered.common_range_max)];
metricsAllShared = evaluateCollapse(collapseAll, sharedRange);
metricsFilteredShared = evaluateCollapse(collapseFiltered, sharedRange);

removedTemps = temps(~includeMask);
keptTemps = temps(includeMask);

decisionOut = save_run_table(decisionTbl, ...
    'switching_energy_scale_collapse_temperature_decisions.csv', runDir);

metricsTbl = table( ...
    ["all_temperatures"; "filtered_temperatures"; "all_temperatures_shared_range"; "filtered_temperatures_shared_range"], ...
    [metricsAll.num_curves; metricsFiltered.num_curves; metricsAllShared.num_curves; metricsFilteredShared.num_curves], ...
    [metricsAll.common_range_min; metricsFiltered.common_range_min; metricsAllShared.common_range_min; metricsFilteredShared.common_range_min], ...
    [metricsAll.common_range_max; metricsFiltered.common_range_max; metricsAllShared.common_range_max; metricsFilteredShared.common_range_max], ...
    [metricsAll.mean_std; metricsFiltered.mean_std; metricsAllShared.mean_std; metricsFilteredShared.mean_std], ...
    [metricsAll.mean_rmse_to_mean; metricsFiltered.mean_rmse_to_mean; metricsAllShared.mean_rmse_to_mean; metricsFilteredShared.mean_rmse_to_mean], ...
    'VariableNames', {'selection_name','n_curves','common_range_min','common_range_max','mean_intercurve_std','mean_rmse_to_mean'});
metricsOut = save_run_table(metricsTbl, 'switching_energy_scale_collapse_metrics.csv', runDir);

plotLimits = computePlotLimits(collapseAll, collapseFiltered);

figFiltered = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 980 720]);
axFiltered = axes(figFiltered);
summaryFiltered = sprintf([ ...
    'Kept %d temperatures: %s\n' ...
    'Removed: %s\n' ...
    'Shared-range metric: %.4f'], ...
    numel(keptTemps), formatTempList(keptTemps), formatTempList(removedTemps), metricsFilteredShared.mean_std);
plotCollapseAxes(axFiltered, collapseFiltered, ...
    'Energy-scale collapse inside the switching regime', summaryFiltered, metricsFilteredShared, plotLimits);
filteredFigPaths = save_run_figure(figFiltered, 'switching_energy_scale_collapse_filtered', runDir);
close(figFiltered);

figComparison = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1500 640]);
tl = tiledlayout(figComparison, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axAll = nexttile(tl, 1);
summaryAll = sprintf([ ...
    'All temperatures: %s\n' ...
    'Shared-range metric: %.4f'], ...
    formatTempList(temps), metricsAllShared.mean_std);
plotCollapseAxes(axAll, collapseAll, 'Original collapse (all temperatures)', summaryAll, metricsAllShared, plotLimits);

axFiltCmp = nexttile(tl, 2);
summaryCmp = sprintf([ ...
    'Filtered temperatures: %s\n' ...
    'Removed: %s\n' ...
    'Shared-range metric: %.4f'], ...
    formatTempList(keptTemps), formatTempList(removedTemps), metricsFilteredShared.mean_std);
plotCollapseAxes(axFiltCmp, collapseFiltered, 'Filtered collapse (switching regime only)', summaryCmp, metricsFilteredShared, plotLimits);

comparisonFigPaths = save_run_figure(figComparison, 'switching_energy_scale_collapse_comparison', runDir);
close(figComparison);

reportText = buildReportText( ...
    sourceManifest, decisionTbl, keptTemps, removedTemps, metricsAll, metricsFiltered, ...
    metricsAllShared, metricsFilteredShared, decisionOut, metricsOut, ...
    filteredFigPaths.png, comparisonFigPaths.png);
reportOut = save_run_report(reportText, 'switching_energy_scale_collapse_filtered.md', runDir);

appendRunNotes(run.notes_path, reportText);
zipOut = buildReviewZip(runDir, 'switching_energy_scale_collapse_filtered_bundle.zip');

fprintf('Saved filtered collapse figure: %s\n', filteredFigPaths.png);
fprintf('Saved comparison figure: %s\n', comparisonFigPaths.png);
fprintf('Saved report: %s\n', reportOut);
fprintf('Saved decision table: %s\n', decisionOut);
fprintf('Saved metrics table: %s\n', metricsOut);
fprintf('Saved review ZIP: %s\n', zipOut);

function [runDir, analysisDir, manifest] = resolveSourceAlignmentRun(repoRoot, sourceRunId)
runsRoot = switchingCanonicalRunRoot(repoRoot);
manifest = struct();

if nargin >= 2 && strlength(string(sourceRunId)) > 0
    runDir = fullfile(runsRoot, char(string(sourceRunId)));
    analysisDir = fullfile(runDir, 'alignment_audit');
    assert(exist(runDir, 'dir') == 7, 'Requested source run does not exist: %s', runDir);
    assert(exist(analysisDir, 'dir') == 7, 'Requested source run lacks alignment_audit outputs: %s', analysisDir);
else
    runDir = '';
    analysisDir = '';
    runDirs = dir(fullfile(runsRoot, 'run_*'));
    runDirs = runDirs([runDirs.isdir]);
    [~, order] = sort({runDirs.name});
    runDirs = runDirs(order);
    for i = numel(runDirs):-1:1
        candidateRunDir = fullfile(runsRoot, runDirs(i).name);
        candidateAnalysisDir = fullfile(candidateRunDir, 'alignment_audit');
        candidateFigure = fullfile(candidateAnalysisDir, 'switching_alignment_energy_scale_collapse.png');
        candidateObs = fullfile(candidateAnalysisDir, 'switching_alignment_observables_vs_T.csv');
        candidateSamples = fullfile(candidateAnalysisDir, 'switching_alignment_samples.csv');
        if exist(candidateAnalysisDir, 'dir') == 7 && exist(candidateFigure, 'file') == 2 && ...
                exist(candidateObs, 'file') == 2 && exist(candidateSamples, 'file') == 2
            runDir = candidateRunDir;
            analysisDir = candidateAnalysisDir;
            break;
        end
    end
    assert(~isempty(runDir), 'Unable to locate a source alignment_audit run with the saved collapse figure.');
end

manifestPath = fullfile(runDir, 'run_manifest.json');
if exist(manifestPath, 'file') == 2
    manifest = jsondecode(fileread(manifestPath));
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

function decisionTbl = buildTemperatureDecisionTable( ...
    temps, currents, Smap, Ipeak, S_peak, width_I, forcedRemoveTemps_K, highTempBoundary_K)
nTemps = numel(temps);
includeFlag = true(nTemps, 1);
reason = strings(nTemps, 1);
peakAtLowest = false(nTemps, 1);
peakAtHighest = false(nTemps, 1);
widthMissing = ~isfinite(width_I);
lowAmplitude = false(nTemps, 1);
amplitudeFloor = 0.05 * max(S_peak(isfinite(S_peak)), [], 'omitnan');
if ~isfinite(amplitudeFloor)
    amplitudeFloor = NaN;
end

for it = 1:nTemps
    row = Smap(it, :);
    valid = isfinite(row) & isfinite(currents);
    currValid = currents(valid);
    rowValid = row(valid);
    if isempty(currValid)
        includeFlag(it) = false;
        reason(it) = "no_valid_curve";
        continue;
    end

    [~, idxPeak] = max(rowValid);
    peakCurrent = currValid(idxPeak);
    peakAtLowest(it) = abs(peakCurrent - min(currValid)) < 1e-9;
    peakAtHighest(it) = abs(peakCurrent - max(currValid)) < 1e-9;
    lowAmplitude(it) = isfinite(S_peak(it)) && isfinite(amplitudeFloor) && S_peak(it) <= amplitudeFloor;

    if ismember(round(temps(it)), round(forcedRemoveTemps_K))
        includeFlag(it) = false;
        reason(it) = "forced_remove_high_temperature";
    elseif temps(it) >= highTempBoundary_K && widthMissing(it) && peakAtLowest(it)
        includeFlag(it) = false;
        reason(it) = "outside_switching_peak_at_lowest_current";
    elseif temps(it) >= highTempBoundary_K && widthMissing(it) && lowAmplitude(it)
        includeFlag(it) = false;
        reason(it) = "outside_switching_low_amplitude";
    else
        includeFlag(it) = true;
        reason(it) = "included_switching_regime";
    end
end

decisionTbl = table( ...
    temps(:), includeFlag(:), reason(:), Ipeak(:), S_peak(:), width_I(:), ...
    peakAtLowest(:), peakAtHighest(:), widthMissing(:), lowAmplitude(:), ...
    'VariableNames', {'T_K','include_flag','decision_reason','Ipeak','S_peak','width_I', ...
    'peak_at_lowest_current','peak_at_highest_current','width_missing','low_amplitude'});
end

function collapse = collectCollapseCurves(temps, currents, Smap, Ipeak, S_peak)
curveTemps = [];
xCurves = {};
yCurves = {};

for it = 1:numel(temps)
    if ~isfinite(Ipeak(it)) || abs(Ipeak(it)) <= eps || ~isfinite(S_peak(it)) || S_peak(it) <= eps
        continue;
    end

    row = Smap(it, :);
    valid = isfinite(row) & isfinite(currents);
    if nnz(valid) < 2
        continue;
    end

    x = currents(valid) ./ Ipeak(it);
    y = row(valid) ./ S_peak(it);
    [x, sortIdx] = sort(x(:));
    y = y(sortIdx);
    [x, uniqueIdx] = unique(x, 'stable');
    y = y(uniqueIdx);
    if numel(x) < 2
        continue;
    end

    curveTemps(end+1, 1) = temps(it); %#ok<AGROW>
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
    x = collapse.x{it};
    y = collapse.y{it};
    Ygrid(it, :) = interp1(x, y, xGrid, 'linear', NaN);
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
    limits.x = [0 1];
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

function plotCollapseAxes(ax, collapse, plotTitleText, summaryText, metrics, limits)
hold(ax, 'on');
grid(ax, 'on');

nCurves = numel(collapse.temps);
assert(nCurves >= 1, 'plotCollapseAxes requires at least one curve.');

cmap = parula(256);
tMin = min(collapse.temps);
tMax = max(collapse.temps);

for it = 1:nCurves
    thisColor = mapTemperatureToColor(collapse.temps(it), tMin, tMax, cmap);
    plot(ax, collapse.x{it}, collapse.y{it}, '-', 'LineWidth', 1.8, 'Color', thisColor);
end

colormap(ax, cmap);
if tMax > tMin
    clim(ax, [tMin tMax]);
    cb = colorbar(ax);
    ylabel(cb, 'T (K)');
else
    cb = colorbar(ax);
    ylabel(cb, 'T (K)');
    clim(ax, [tMin - 0.5, tMax + 0.5]);
end

xlabel(ax, 'I / I_{peak}(T)');
ylabel(ax, 'S(T,I) / S_{peak}(T)');
title(ax, plotTitleText);
xlim(ax, limits.x);
ylim(ax, limits.y);

metricText = sprintf([ ...
    '%s\n' ...
    'Common x range: [%.2f, %.2f]'], ...
    summaryText, metrics.common_range_min, metrics.common_range_max);
text(ax, 0.03, 0.97, metricText, 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'BackgroundColor', 'w', ...
    'Margin', 6, 'FontSize', 9, 'Interpreter', 'none');
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
    sourceManifest, decisionTbl, keptTemps, removedTemps, metricsAll, metricsFiltered, ...
    metricsAllShared, metricsFilteredShared, decisionOut, metricsOut, filteredFigPath, comparisonFigPath)

sourceRunId = string(getManifestField(sourceManifest, 'run_id', 'unknown'));
sourceDataset = string(getManifestField(sourceManifest, 'dataset', 'unknown'));
tempMin = min(keptTemps, [], 'omitnan');
tempMax = max(keptTemps, [], 'omitnan');

metricDelta = metricsAllShared.mean_std - metricsFilteredShared.mean_std;
metricImprovementPct = 100 * metricDelta / metricsAllShared.mean_std;
if ~isfinite(metricImprovementPct)
    metricImprovementPct = NaN;
end

if isfinite(metricDelta) && metricDelta > 0
    improvementLine = sprintf(['The shared-domain collapse metric improves from %.4f to %.4f ' ...
        '(lower is better, %.1f%% reduction).'], ...
        metricsAllShared.mean_std, metricsFilteredShared.mean_std, metricImprovementPct);
elseif isfinite(metricDelta) && metricDelta < 0
    improvementLine = sprintf(['The shared-domain collapse metric worsens slightly from %.4f to %.4f ' ...
        '(%.1f%% increase).'], ...
        metricsAllShared.mean_std, metricsFilteredShared.mean_std, abs(metricImprovementPct));
else
    improvementLine = sprintf('The shared-domain collapse metric is unchanged within numerical precision at %.4f.', ...
        metricsFilteredShared.mean_std);
end

keep30 = any(abs(keptTemps - 30) < 1e-9);
remove32 = any(abs(removedTemps - 32) < 1e-9);
borderlineLine = "30 K was retained because the curve still shows a resolved interior peak near 20 mA, even though the half-maximum width is not resolved on the coarse current grid.";
if ~(keep30 && remove32)
    borderlineLine = "No additional borderline-temperature note was needed beyond the temperatures listed above.";
end

lines = [
    "# Switching Energy-Scale Collapse (Filtered)"
    ""
    "## Source"
    "- Source alignment run: `" + sourceRunId + "`"
    "- Dataset: `" + sourceDataset + "`"
    "- Reused processed inputs: `switching_alignment_samples.csv` and `switching_alignment_observables_vs_T.csv`"
    ""
    "## Temperature Selection"
    "- Temperatures available in the source run: " + formatTempList(decisionTbl.T_K)
    "- Removed from the collapse: " + formatTempList(removedTemps)
    "- Temperature range kept for the filtered collapse: " + sprintf('%.0f-%.0f K', tempMin, tempMax)
    "- Included temperatures: " + formatTempList(keptTemps)
    "- Selection rule: always remove `34 K`, then remove any higher-temperature curve with missing width and a peak pinned to the lowest measured current."
    ""
    "## Rationale"
    "- `34 K` was removed because its normalized signal is essentially absent (`S_peak` is only ~0.0011 on the original percent scale)."
    "- `32 K` was removed because the maximum has shifted to the lowest measured current (`15 mA`) and the curve no longer shows an internal switching peak."
    "- " + borderlineLine
    ""
    "## Collapse Quality"
    "- Self-consistent common range for all temperatures: " + sprintf('[%.2f, %.2f]', metricsAll.common_range_min, metricsAll.common_range_max)
    "- Self-consistent common range for filtered temperatures: " + sprintf('[%.2f, %.2f]', metricsFiltered.common_range_min, metricsFiltered.common_range_max)
    "- Shared comparison range used for the quantitative before/after metric: " + sprintf('[%.2f, %.2f]', metricsFilteredShared.common_range_min, metricsFilteredShared.common_range_max)
    "- " + improvementLine
    ""
    "## Outputs"
    "- Filtered collapse figure: `" + string(filteredFigPath) + "`"
    "- Comparison figure: `" + string(comparisonFigPath) + "`"
    "- Temperature-decision table: `" + string(decisionOut) + "`"
    "- Collapse-metrics table: `" + string(metricsOut) + "`"
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
