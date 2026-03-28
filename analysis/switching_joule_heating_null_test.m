function out = switching_joule_heating_null_test(cfg)
% switching_joule_heating_null_test
% Perform a Joule-heating null test for the switching dataset using saved
% run outputs only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);
prior = inspectExistingHeatingContext(repoRoot, source);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('switch:%s | align:%s | relax:%s | ax:%s', ...
    char(source.switchRunName), char(source.alignRunName), ...
    char(source.relaxRunName), char(source.axRunName));
runCfg.switchRunName = char(source.switchRunName);
runCfg.alignRunName = char(source.alignRunName);
runCfg.relaxRunName = char(source.relaxRunName);
runCfg.axRunName = char(source.axRunName);
runCfg.interpMethod = cfg.interpMethod;
runCfg.masterCurveSmoothPoints = cfg.masterCurveSmoothPoints;
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Switching Joule-heating null-test run directory:\n%s\n', runDir);
fprintf('Switching full-scaling source: %s\n', source.switchRunName);
fprintf('Switching alignment-map source: %s\n', source.alignRunName);
fprintf('Relaxation anchor source: %s\n', source.relaxRunName);

appendText(run.log_path, sprintf('[%s] switching Joule-heating null test started\n', stampNow()));
appendText(run.log_path, sprintf('Switching full-scaling source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Switching alignment-map source: %s\n', char(source.alignRunName)));
appendText(run.log_path, sprintf('Relaxation anchor source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('AX context source: %s\n', char(source.axRunName)));

switching = loadSwitchingData(source, cfg);
relax = loadRelaxationData(source.relaxRunDir);
aligned = buildAlignedDataset(switching, relax, cfg);

coordResults = evaluateCoordinateComparisons(aligned, cfg);
modelResults = evaluateModelComparisons(aligned, coordResults, cfg);
bridge = analyzeRelaxationBridge(aligned);
decision = determineDecision(modelResults, bridge, aligned, cfg);

sourceManifestTbl = buildSourceManifestTable(source, prior);
temperatureTbl = buildTemperatureObservableTable(aligned);
coordTbl = buildCoordinateSummaryTable(coordResults);
modelSummaryTbl = modelResults.summaryTable;
predictionTbl = modelResults.predictionTable;
masterCurveTbl = modelResults.masterCurveTable;
bridgeTbl = bridge.summaryTable;

sourceManifestPath = save_run_table(sourceManifestTbl, 'source_run_manifest.csv', runDir);
temperaturePath = save_run_table(temperatureTbl, 'temperature_observable_bridge_table.csv', runDir);
coordPath = save_run_table(coordTbl, 'coordinate_comparison_summary.csv', runDir);
modelSummaryPath = save_run_table(modelSummaryTbl, 'heating_model_summary.csv', runDir);
predictionPath = save_run_table(predictionTbl, 'heating_model_predictions.csv', runDir);
masterCurvePath = save_run_table(masterCurveTbl, 'master_curve_library.csv', runDir);
bridgePath = save_run_table(bridgeTbl, 'relaxation_bridge_correlations.csv', runDir);

figMaps = saveCoordinateHeatmaps(aligned, coordResults, runDir, 'switching_heating_coordinate_maps');
figShift = saveShiftCollapseFigure(coordResults, runDir, 'switching_heating_shifted_collapses');
figModels = saveModelCollapseFigure(aligned, modelResults, runDir, 'switching_heating_model_collapses');
figPredictions = savePredictionFigure(aligned, modelResults, runDir, 'switching_heating_model_predictions');
figBridgeScatter = saveBridgeScatterFigure(aligned, bridge, runDir, 'switching_heating_bridge_scatter');
figBridgeOverlay = saveBridgeOverlayFigure(aligned, bridge, runDir, 'switching_heating_bridge_overlay');

reportText = buildReportText(source, prior, aligned, coordResults, modelResults, bridge, decision, cfg);
reportPath = save_run_report(reportText, 'switching_joule_heating_null_test.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_joule_heating_null_test_bundle.zip');

appendText(run.notes_path, sprintf('Decision: %s\n', decision.label));
appendText(run.notes_path, sprintf('Best heating model: %s\n', char(modelResults.bestHeatingModel.display_name)));
appendText(run.notes_path, sprintf('Geometry benchmark CV RMSE = %.6g\n', modelResults.geometryModel.map_cv_rmse_raw));
appendText(run.notes_path, sprintf('Best heating CV RMSE = %.6g\n', modelResults.bestHeatingModel.map_cv_rmse_raw));
appendText(run.notes_path, sprintf('Best heating ridge RMSE = %.6g mA\n', modelResults.bestHeatingModel.ridge_rmse_mA));
appendText(run.notes_path, sprintf('Best heating width RMSE = %.6g mA\n', modelResults.bestHeatingModel.width_rmse_mA));
appendText(run.notes_path, sprintf('Best heating amplitude RMSE = %.6g\n', modelResults.bestHeatingModel.amplitude_rmse));
appendText(run.notes_path, sprintf('Bridge Pearson: X = %.4f, I^2 = %.4f, I^2R = %.4f\n', ...
    bridge.lookup.X.pearson_r, bridge.lookup.I2_peak.pearson_r, bridge.lookup.I2R_peak.pearson_r));

appendText(run.log_path, sprintf('[%s] switching Joule-heating null test complete\n', stampNow()));
appendText(run.log_path, sprintf('Source manifest: %s\n', sourceManifestPath));
appendText(run.log_path, sprintf('Temperature table: %s\n', temperaturePath));
appendText(run.log_path, sprintf('Coordinate summary: %s\n', coordPath));
appendText(run.log_path, sprintf('Model summary: %s\n', modelSummaryPath));
appendText(run.log_path, sprintf('Prediction table: %s\n', predictionPath));
appendText(run.log_path, sprintf('Master curves: %s\n', masterCurvePath));
appendText(run.log_path, sprintf('Bridge table: %s\n', bridgePath));
appendText(run.log_path, sprintf('Coordinate maps: %s\n', figMaps.png));
appendText(run.log_path, sprintf('Shift collapses: %s\n', figShift.png));
appendText(run.log_path, sprintf('Model collapses: %s\n', figModels.png));
appendText(run.log_path, sprintf('Model predictions: %s\n', figPredictions.png));
appendText(run.log_path, sprintf('Bridge scatter: %s\n', figBridgeScatter.png));
appendText(run.log_path, sprintf('Bridge overlay: %s\n', figBridgeOverlay.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.aligned = aligned;
out.coordinateSummary = coordTbl;
out.modelSummary = modelSummaryTbl;
out.bridgeSummary = bridgeTbl;
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Switching Joule-heating null test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Decision: %s\n', decision.label);
fprintf('Best heating model: %s\n', char(modelResults.bestHeatingModel.display_name));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_joule_heating_null_test');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'switchFigureRunName', 'run_2026_03_12_235922_switching_full_scaling_collapse_figure_r');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'axRunName', 'run_2026_03_13_115401_AX_functional_relation_analysis');
cfg = setDefaultField(cfg, 'compositeRunName', 'run_2026_03_13_071713_switching_composite_observable_scan');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'shiftGridCount', 240);
cfg = setDefaultField(cfg, 'masterCurveSmoothPoints', 7);
cfg = setDefaultField(cfg, 'denseCurrentCount', 400);
cfg = setDefaultField(cfg, 'geometryInferiorityMargin', 0.15);
cfg = setDefaultField(cfg, 'correlationMargin', 0.05);
cfg = setDefaultField(cfg, 'ridgeTolerance_mA', 2.5);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.switchFigureRunName = string(cfg.switchFigureRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.axRunName = string(cfg.axRunName);
source.compositeRunName = string(cfg.compositeRunName);

source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.switchFigureRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchFigureRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.axRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.axRunName));
source.compositeRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.compositeRunName));

assert(exist(source.switchRunDir, 'dir') == 7, 'Missing switching full-scaling run: %s', source.switchRunDir);
assert(exist(source.relaxRunDir, 'dir') == 7, 'Missing relaxation anchor run: %s', source.relaxRunDir);
assert(exist(source.axRunDir, 'dir') == 7, 'Missing AX context run: %s', source.axRunDir);

source.switchParamPath = fullfile(source.switchRunDir, 'tables', 'switching_full_scaling_parameters.csv');
source.switchMetricPath = fullfile(source.switchRunDir, 'tables', 'switching_full_scaling_metrics.csv');
source.switchConfigPath = fullfile(source.switchRunDir, 'config_snapshot.m');
source.relaxTempPath = fullfile(source.relaxRunDir, 'tables', 'temperature_observables.csv');
source.axReportPath = fullfile(source.axRunDir, 'reports', 'AX_functional_relation_analysis.md');

requiredFiles = {source.switchParamPath; source.switchMetricPath; source.switchConfigPath; source.relaxTempPath; source.axReportPath};
for i = 1:numel(requiredFiles)
    assert(exist(requiredFiles{i}, 'file') == 2, 'Missing required source file: %s', requiredFiles{i});
end

cfgStruct = parseConfigSnapshot(source.switchConfigPath);
assert(isfield(cfgStruct, 'sourceRunId') && ~isempty(cfgStruct.sourceRunId), ...
    'Could not resolve source alignment run from config snapshot: %s', source.switchConfigPath);
source.alignRunName = string(cfgStruct.sourceRunId);
source.alignRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.alignRunName));
source.alignSamplesPath = fullfile(source.alignRunDir, 'alignment_audit', 'switching_alignment_samples.csv');
source.alignObsPath = fullfile(source.alignRunDir, 'alignment_audit', 'switching_alignment_observables_vs_T.csv');
assert(exist(source.alignRunDir, 'dir') == 7, 'Missing switching alignment source run: %s', source.alignRunDir);
assert(exist(source.alignSamplesPath, 'file') == 2, 'Missing switching samples CSV: %s', source.alignSamplesPath);
assert(exist(source.alignObsPath, 'file') == 2, 'Missing switching observables CSV: %s', source.alignObsPath);
end

function cfgStruct = parseConfigSnapshot(cfgPath)
cfgStruct = struct();
cfgText = fileread(cfgPath);
tok = regexp(cfgText, 'cfg_snapshot_json = ''(.*)'';', 'tokens', 'once');
if isempty(tok)
    return;
end
try
    cfgStruct = jsondecode(tok{1});
catch
    cfgStruct = struct();
end
end

function prior = inspectExistingHeatingContext(repoRoot, source)
prior = struct();
prior.switchHeatingRuns = scanRuns(fullfile(repoRoot, 'results', 'switching', 'runs'));
prior.crossHeatingRuns = scanRuns(fullfile(repoRoot, 'results', 'cross_experiment', 'runs'));
prior.hasDedicatedHeatingRun = ~isempty(prior.switchHeatingRuns) || ~isempty(prior.crossHeatingRuns);
prior.compositeRunExists = exist(source.compositeRunDir, 'dir') == 7;
prior.compositeReportPath = fullfile(source.compositeRunDir, 'reports', 'switching_composite_observable_scan.md');
prior.compositeReportExists = exist(prior.compositeReportPath, 'file') == 2;
end

function names = scanRuns(rootDir)
names = strings(0, 1);
if exist(rootDir, 'dir') ~= 7
    return;
end
d = dir(fullfile(rootDir, 'run_*'));
for i = 1:numel(d)
    if ~d(i).isdir
        continue;
    end
    name = string(d(i).name);
    if contains(name, ["heating", "joule"], 'IgnoreCase', true) && ~contains(name, "switching_joule_heating_null_test", 'IgnoreCase', true)
        names(end + 1, 1) = name; %#ok<AGROW>
    end
end
end

function switching = loadSwitchingData(source, cfg)
paramsTbl = readtable(source.switchParamPath, 'VariableNamingRule', 'preserve', 'Delimiter', ',', 'ReadVariableNames', true);
paramsTbl = sortrows(paramsTbl, 'T_K');

metricTbl = readtable(source.switchMetricPath, 'VariableNamingRule', 'preserve', 'Delimiter', ',', 'ReadVariableNames', true);
metricMask = strcmp(string(metricTbl.analysis_name), "full_scaling_chosen");
assert(any(metricMask), 'Could not locate full_scaling_chosen benchmark in %s', source.switchMetricPath);
metricRow = metricTbl(find(metricMask, 1, 'first'), :);

samplesTbl = readtable(source.alignSamplesPath, 'VariableNamingRule', 'preserve', 'Delimiter', ',', 'ReadVariableNames', true);
[mapTemps, currents, Smap] = buildSwitchingMapRounded(samplesTbl);
paramsMask = paramsTbl.T_K >= cfg.temperatureMinK & paramsTbl.T_K <= cfg.temperatureMaxK;
paramsTbl = paramsTbl(paramsMask, :);

[tempsUse, iaParams, iaMap] = intersect(paramsTbl.T_K, mapTemps, 'stable');
assert(~isempty(tempsUse), 'No overlap between switching parameters and switching map temperatures.');

switching = struct();
switching.T = tempsUse(:);
switching.currents = currents(:).';
switching.Smap = Smap(iaMap, :);
switching.paramsTbl = paramsTbl(iaParams, :);
switching.I_peak = double(switching.paramsTbl.Ipeak_mA(:));
switching.width = double(switching.paramsTbl.width_chosen_mA(:));
switching.S_peak = double(switching.paramsTbl.S_peak(:));
switching.geometrySavedMeanStd = double(metricRow.mean_intercurve_std(1));
switching.geometrySavedMeanRmse = double(metricRow.mean_rmse_to_mean(1));
switching.geometrySavedRange = [double(metricRow.common_range_min(1)), double(metricRow.common_range_max(1))];
end

function relax = loadRelaxationData(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'), 'VariableNamingRule', 'preserve', 'Delimiter', ',', 'ReadVariableNames', true);
tbl = sortrows(tbl, 'T');

relax = struct();
relax.T = double(tbl.T(:));
relax.A = double(tbl.A_T(:));
relax.R = double(tbl.R_T(:));
end

function aligned = buildAlignedDataset(switching, relax, cfg)
T = switching.T(:);
A = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
R = interp1(relax.T, relax.R, T, cfg.interpMethod, NaN);

mask = isfinite(T) & isfinite(A) & isfinite(R) & isfinite(switching.I_peak) & isfinite(switching.width) & isfinite(switching.S_peak);
assert(nnz(mask) >= 5, 'Too few finite temperatures remain after alignment.');

aligned = struct();
aligned.T_K = T(mask);
aligned.currentGrid_mA = switching.currents(:).';
aligned.Smap = switching.Smap(mask, :);
aligned.I_peak_mA = switching.I_peak(mask);
aligned.width_mA = switching.width(mask);
aligned.S_peak = switching.S_peak(mask);
[canonicalT, canonicalX] = get_canonical_X();
% X is loaded from canonical run to avoid drift from duplicated implementations
aligned.X = interp1(canonicalT, canonicalX, aligned.T_K, cfg.interpMethod, NaN);
aligned.A_interp = A(mask);
aligned.R_interp = R(mask);
aligned.I2_peak = aligned.I_peak_mA .^ 2;
aligned.I2R_peak = aligned.I2_peak .* aligned.R_interp;
aligned.SnormMap = aligned.Smap ./ aligned.S_peak;
aligned.geometrySavedMeanStd = switching.geometrySavedMeanStd;
aligned.geometrySavedMeanRmse = switching.geometrySavedMeanRmse;
aligned.geometrySavedRange = switching.geometrySavedRange;
end

function coordResults = evaluateCoordinateComparisons(aligned, cfg)
keys = {'I', 'I2', 'I2R'};
displayNames = {'Current I', 'Heating proxy I^2', 'Heating proxy I^2 R(T)'};
axisLabels = {'Current (mA)', 'I^2 (mA^2)', 'I^2 R(T) (arb. units)'};

coordResults = struct();
coordResults.items = struct('key', {}, 'display_name', {}, 'axis_label', {}, 'coordinate_matrix', {}, 'coordinate_peak', {}, 'ridge', {}, 'shiftCollapse', {});
for i = 1:numel(keys)
    item = struct();
    item.key = string(keys{i});
    item.display_name = string(displayNames{i});
    item.axis_label = string(axisLabels{i});
    [item.coordinate_matrix, item.coordinate_peak] = buildCoordinateMatrix(aligned, keys{i});
    item.ridge = fitRidgeEffectiveTemperature(aligned.T_K, item.coordinate_peak);
    item.shiftCollapse = evaluateShiftCollapse(item.coordinate_matrix, aligned.SnormMap, item.coordinate_peak, cfg);
    coordResults.items(end + 1, 1) = item; %#ok<AGROW>
end
end

function [coordMat, coordPeak] = buildCoordinateMatrix(aligned, key)
I = aligned.currentGrid_mA(:).';
nT = numel(aligned.T_K);
switch key
    case 'I'
        coordMat = repmat(I, nT, 1);
        coordPeak = aligned.I_peak_mA(:);
    case 'I2'
        coordMat = repmat(I .^ 2, nT, 1);
        coordPeak = aligned.I_peak_mA(:) .^ 2;
    case 'I2R'
        coordMat = aligned.R_interp(:) .* repmat(I .^ 2, nT, 1);
        coordPeak = (aligned.I_peak_mA(:) .^ 2) .* aligned.R_interp(:);
    otherwise
        error('Unsupported coordinate key: %s', key);
end
end

function ridge = fitRidgeEffectiveTemperature(T, coordPeak)
mask = isfinite(T) & isfinite(coordPeak);
assert(nnz(mask) >= 3, 'Need at least three points to fit ridge effective temperature.');
x = coordPeak(mask);
y = T(mask);
p = polyfit(x, y, 1);
a = -p(1);
Tstar = p(2);
teff = T + a .* coordPeak;
teffMask = isfinite(teff);

ridge = struct();
ridge.a = a;
ridge.T_star = Tstar;
ridge.pearson_r = corrSafe(coordPeak, T);
ridge.spearman_r = spearmanSafe(coordPeak, T);
ridge.teff_peak = teff;
ridge.teff_peak_std = std(teff(teffMask), 1);
ridge.teff_peak_span = max(teff(teffMask)) - min(teff(teffMask));
ridge.teff_peak_rmse_to_mean = sqrt(mean((teff(teffMask) - mean(teff(teffMask))).^2));
ridge.line_r2 = computeR2(y, polyval(p, x));
end

function collapse = evaluateShiftCollapse(coordMat, normMap, coordPeak, cfg)
nT = size(coordMat, 1);
shiftMat = coordMat - coordPeak(:);

xMin = -Inf;
xMax = Inf;
for it = 1:nT
    xRow = shiftMat(it, :);
    yRow = normMap(it, :);
    valid = isfinite(xRow) & isfinite(yRow);
    assert(nnz(valid) >= 3, 'Not enough valid points to evaluate shifted collapse at row %d.', it);
    xMin = max(xMin, min(xRow(valid)));
    xMax = min(xMax, max(xRow(valid)));
end
assert(isfinite(xMin) && isfinite(xMax) && xMax > xMin, 'Could not find common shifted-coordinate range.');

grid = linspace(xMin, xMax, cfg.shiftGridCount);
curveGrid = NaN(nT, numel(grid));
for it = 1:nT
    xRow = shiftMat(it, :);
    yRow = normMap(it, :);
    valid = isfinite(xRow) & isfinite(yRow);
    curveGrid(it, :) = interp1(xRow(valid), yRow(valid), grid, 'linear', NaN);
end

meanCurve = mean(curveGrid, 1, 'omitnan');
intercurveStd = std(curveGrid, 0, 1, 'omitnan');
rowRmse = NaN(nT, 1);
for it = 1:nT
    valid = isfinite(curveGrid(it, :)) & isfinite(meanCurve);
    rowRmse(it) = computeRMSE(curveGrid(it, valid), meanCurve(valid));
end

collapse = struct();
collapse.grid = grid;
collapse.curve_grid = curveGrid;
collapse.mean_curve = meanCurve;
collapse.mean_intercurve_std = mean(intercurveStd, 'omitnan');
collapse.mean_rmse_to_mean = mean(rowRmse, 'omitnan');
collapse.common_range_min = xMin;
collapse.common_range_max = xMax;
collapse.row_rmse = rowRmse;
end
function modelResults = evaluateModelComparisons(aligned, coordResults, cfg)
geometryModel = evaluateGeometryModel(aligned, cfg);
heatingItems = struct('key', {}, 'display_name', {}, 'coordinate_display', {}, 'a', {}, 'ridge', {}, 'master_all', {}, 'teff_matrix', {}, 'predicted_all', {}, 'map_cv_rmse_raw', {}, 'map_cv_nrmse', {}, 'map_cv_r2', {}, 'ridge_rmse_mA', {}, 'width_rmse_mA', {}, 'amplitude_rmse', {}, 'ridge_pearson_r', {}, 'width_pearson_r', {}, 'amplitude_pearson_r', {}, 'I_peak_pred', {}, 'width_pred', {}, 'S_peak_pred', {}, 'predictionTable', {});

for i = 1:numel(coordResults.items)
    key = char(coordResults.items(i).key);
    if strcmp(key, 'I')
        continue;
    end
    heatingItems(end + 1, 1) = evaluateHeatingModel(aligned, coordResults.items(i), cfg); %#ok<AGROW>
end

summaryTbl = packGeometrySummaryRow(geometryModel);
for i = 1:numel(heatingItems)
    summaryTbl = [summaryTbl; packHeatingSummaryRow(heatingItems(i))]; %#ok<AGROW>
end

predictionTbl = table();
for i = 1:numel(heatingItems)
    predictionTbl = [predictionTbl; heatingItems(i).predictionTable]; %#ok<AGROW>
end

masterCurveTbl = packMasterCurveTable(geometryModel, heatingItems);
rmseVals = [heatingItems.map_cv_rmse_raw];
[~, bestIdx] = min(rmseVals);

modelResults = struct();
modelResults.geometryModel = geometryModel;
modelResults.heatingModels = heatingItems;
modelResults.bestHeatingModel = heatingItems(bestIdx);
modelResults.summaryTable = summaryTbl;
modelResults.predictionTable = predictionTbl;
modelResults.masterCurveTable = masterCurveTbl;
end

function geometry = evaluateGeometryModel(aligned, cfg)
currents = aligned.currentGrid_mA(:).';
nT = numel(aligned.T_K);
currentMat = repmat(currents, nT, 1);
xiMat = (currentMat - aligned.I_peak_mA(:)) ./ aligned.width_mA(:);
normMap = aligned.SnormMap;

[masterAll, predAllNorm] = fitAndPredictAllRows(xiMat, normMap, cfg);
predAllRaw = predAllNorm .* aligned.S_peak;
cv = crossValidateGeometryRows(xiMat, normMap, aligned.S_peak, cfg);

geometry = struct();
geometry.key = "geometry";
geometry.display_name = "Existing geometric shift-scale baseline";
geometry.coordinate_matrix = xiMat;
geometry.master_all = masterAll;
geometry.predicted_all_raw = predAllRaw;
geometry.map_cv_rmse_raw = cv.mean_rmse_raw;
geometry.map_cv_nrmse = cv.mean_nrmse;
geometry.map_cv_r2 = cv.global_r2;
geometry.row_rmse_raw = cv.row_rmse_raw;
geometry.saved_mean_intercurve_std = aligned.geometrySavedMeanStd;
geometry.saved_mean_rmse = aligned.geometrySavedMeanRmse;
geometry.saved_range = aligned.geometrySavedRange;
end

function heating = evaluateHeatingModel(aligned, coordItem, cfg)
a = coordItem.ridge.a;
teffMat = aligned.T_K + a .* coordItem.coordinate_matrix;
[masterAll, predAll] = fitAndPredictAllRows(teffMat, aligned.Smap, cfg);
cv = crossValidateHeatingRows(teffMat, aligned.Smap, aligned.currentGrid_mA, ...
    aligned.T_K, a, coordItem.key, aligned.R_interp, aligned.I_peak_mA, aligned.width_mA, aligned.S_peak, cfg);

heating = struct();
heating.key = coordItem.key;
heating.display_name = coordItem.display_name + " heating-only model";
heating.coordinate_display = coordItem.display_name;
heating.a = a;
heating.ridge = coordItem.ridge;
heating.master_all = masterAll;
heating.teff_matrix = teffMat;
heating.predicted_all = predAll;
heating.map_cv_rmse_raw = cv.mean_rmse_raw;
heating.map_cv_nrmse = cv.mean_nrmse;
heating.map_cv_r2 = cv.global_r2;
heating.ridge_rmse_mA = computeRMSE(cv.I_peak_pred, aligned.I_peak_mA);
heating.width_rmse_mA = computeRMSE(cv.width_pred, aligned.width_mA);
heating.amplitude_rmse = computeRMSE(cv.S_peak_pred, aligned.S_peak);
heating.ridge_pearson_r = corrSafe(cv.I_peak_pred, aligned.I_peak_mA);
heating.width_pearson_r = corrSafe(cv.width_pred, aligned.width_mA);
heating.amplitude_pearson_r = corrSafe(cv.S_peak_pred, aligned.S_peak);
heating.I_peak_pred = cv.I_peak_pred;
heating.width_pred = cv.width_pred;
heating.S_peak_pred = cv.S_peak_pred;
heating.predictionTable = table( ...
    repmat(heating.key, numel(aligned.T_K), 1), aligned.T_K, aligned.I_peak_mA, cv.I_peak_pred, ...
    aligned.width_mA, cv.width_pred, aligned.S_peak, cv.S_peak_pred, cv.row_rmse_raw, cv.row_nrmse, ...
    'VariableNames', {'model_key','T_K','I_peak_obs_mA','I_peak_pred_mA','width_obs_mA','width_pred_mA', ...
    'S_peak_obs','S_peak_pred','row_rmse_raw','row_nrmse'});
end

function row = packGeometrySummaryRow(geometry)
row = table("geometry", geometry.display_name, NaN, NaN, NaN, ...
    geometry.saved_mean_intercurve_std, geometry.saved_mean_rmse, ...
    geometry.map_cv_rmse_raw, geometry.map_cv_nrmse, geometry.map_cv_r2, ...
    NaN, NaN, NaN, NaN, NaN, NaN, ...
    "Uses observed I_peak(T), width(T), and S_peak(T) from the saved geometric analysis as inputs.", ...
    'VariableNames', {'model_key','display_name','a_fit','ridge_teff_std','ridge_teff_span', ...
    'saved_collapse_mean_std','saved_collapse_mean_rmse','map_cv_rmse_raw','map_cv_nrmse','map_cv_r2', ...
    'ridge_rmse_mA','width_rmse_mA','amplitude_rmse','ridge_pearson_r','width_pearson_r','amplitude_pearson_r','notes'});
end

function row = packHeatingSummaryRow(heating)
row = table(heating.key, heating.display_name, heating.a, heating.ridge.teff_peak_std, heating.ridge.teff_peak_span, ...
    NaN, NaN, heating.map_cv_rmse_raw, heating.map_cv_nrmse, heating.map_cv_r2, ...
    heating.ridge_rmse_mA, heating.width_rmse_mA, heating.amplitude_rmse, ...
    heating.ridge_pearson_r, heating.width_pearson_r, heating.amplitude_pearson_r, ...
    "Heating-only null model S(I,T) = G(T + a H(I,T)) with a fixed scalar a from ridge alignment.", ...
    'VariableNames', {'model_key','display_name','a_fit','ridge_teff_std','ridge_teff_span', ...
    'saved_collapse_mean_std','saved_collapse_mean_rmse','map_cv_rmse_raw','map_cv_nrmse','map_cv_r2', ...
    'ridge_rmse_mA','width_rmse_mA','amplitude_rmse','ridge_pearson_r','width_pearson_r','amplitude_pearson_r','notes'});
end

function tbl = packMasterCurveTable(geometry, heatingItems)
tbl = localPackMaster("geometry", geometry.master_all);
for i = 1:numel(heatingItems)
    tbl = [tbl; localPackMaster(heatingItems(i).key, heatingItems(i).master_all)]; %#ok<AGROW>
end
end

function tbl = localPackMaster(modelKey, master)
tbl = table(repmat(string(modelKey), numel(master.x), 1), master.x(:), master.y(:), master.y_smooth(:), ...
    'VariableNames', {'model_key','x','y_mean','y_smooth'});
end

function [masterAll, predAll] = fitAndPredictAllRows(xMat, yMat, cfg)
masterAll = fitMasterCurve1D(xMat(:), yMat(:), cfg);
predAll = predictMasterCurve(masterAll, xMat);
end

function cv = crossValidateGeometryRows(xMat, normMap, Speak, cfg)
nT = size(xMat, 1);
predRaw = NaN(size(normMap));
rowRmseRaw = NaN(nT, 1);
rowNrmse = NaN(nT, 1);

for it = 1:nT
    keepRows = true(nT, 1);
    keepRows(it) = false;
    master = fitMasterCurve1D(xMat(keepRows, :), normMap(keepRows, :), cfg);
    predNorm = predictMasterCurve(master, xMat(it, :));
    predRaw(it, :) = Speak(it) .* predNorm;
    rowRmseRaw(it) = computeRMSE(Speak(it) .* normMap(it, :), predRaw(it, :));
    rowNrmse(it) = computeNRMSE(Speak(it) .* normMap(it, :), predRaw(it, :));
end

obsRaw = Speak .* normMap;
cv = struct();
cv.predRaw = predRaw;
cv.row_rmse_raw = rowRmseRaw;
cv.row_nrmse = rowNrmse;
cv.mean_rmse_raw = mean(rowRmseRaw, 'omitnan');
cv.mean_nrmse = mean(rowNrmse, 'omitnan');
cv.global_r2 = computeR2(obsRaw(:), predRaw(:));
end

function cv = crossValidateHeatingRows(teffMat, yMat, currents, T, a, modelKey, R, IpeakObs, widthObs, SpeakObs, cfg)
nT = size(teffMat, 1);
predMap = NaN(size(yMat));
rowRmseRaw = NaN(nT, 1);
rowNrmse = NaN(nT, 1);
IpeakPred = NaN(nT, 1);
widthPred = NaN(nT, 1);
SpeakPred = NaN(nT, 1);
currentDense = linspace(min(currents), max(currents), cfg.denseCurrentCount);

for it = 1:nT
    keepRows = true(nT, 1);
    keepRows(it) = false;
    master = fitMasterCurve1D(teffMat(keepRows, :), yMat(keepRows, :), cfg);
    predMap(it, :) = predictMasterCurve(master, teffMat(it, :));
    rowRmseRaw(it) = computeRMSE(yMat(it, :), predMap(it, :));
    rowNrmse(it) = computeNRMSE(yMat(it, :), predMap(it, :));

    teffDense = T(it) + a .* transformCoordinate(currentDense, modelKey, R(it));
    predDense = predictMasterCurve(master, teffDense);
    [IpeakPred(it), SpeakPred(it), widthPred(it)] = extractPeakMetrics(currentDense, predDense);
end

cv = struct();
cv.predMap = predMap;
cv.row_rmse_raw = rowRmseRaw;
cv.row_nrmse = rowNrmse;
cv.mean_rmse_raw = mean(rowRmseRaw, 'omitnan');
cv.mean_nrmse = mean(rowNrmse, 'omitnan');
cv.global_r2 = computeR2(yMat(:), predMap(:));
cv.I_peak_pred = IpeakPred;
cv.width_pred = widthPred;
cv.S_peak_pred = SpeakPred;
cv.I_peak_obs = IpeakObs;
cv.width_obs = widthObs;
cv.S_peak_obs = SpeakObs;
end

function values = transformCoordinate(currents, key, R)
switch char(key)
    case 'I2'
        values = currents .^ 2;
    case 'I2R'
        values = (currents .^ 2) .* R;
    otherwise
        error('Unsupported heating-model key: %s', char(key));
end
end

function [Ipeak, Speak, width] = extractPeakMetrics(currents, response)
currents = currents(:);
response = response(:);
valid = isfinite(currents) & isfinite(response);
currents = currents(valid);
response = response(valid);

if numel(currents) < 3
    Ipeak = NaN;
    Speak = NaN;
    width = NaN;
    return;
end

[Speak, idxPeak] = max(response);
Ipeak = currents(idxPeak);
width = computeHalfMaxWidth(currents, response, idxPeak, Speak);
end

function width = computeHalfMaxWidth(currents, response, idxPeak, Speak)
width = NaN;
if ~isfinite(Speak) || Speak <= 0
    return;
end
halfLevel = 0.5 * Speak;

leftX = NaN;
for k = idxPeak:-1:2
    y1 = response(k - 1);
    y2 = response(k);
    if (y1 <= halfLevel && y2 >= halfLevel) || (y1 >= halfLevel && y2 <= halfLevel)
        leftX = interpLinear(currents(k - 1), y1, currents(k), y2, halfLevel);
        break;
    end
end

rightX = NaN;
for k = idxPeak:(numel(currents) - 1)
    y1 = response(k);
    y2 = response(k + 1);
    if (y1 >= halfLevel && y2 <= halfLevel) || (y1 <= halfLevel && y2 >= halfLevel)
        rightX = interpLinear(currents(k), y1, currents(k + 1), y2, halfLevel);
        break;
    end
end

if isfinite(leftX) && isfinite(rightX)
    width = rightX - leftX;
end
end

function x = interpLinear(x1, y1, x2, y2, yTarget)
if abs(y2 - y1) < eps
    x = mean([x1, x2]);
    return;
end
t = (yTarget - y1) / (y2 - y1);
x = x1 + t * (x2 - x1);
end

function master = fitMasterCurve1D(x, y, cfg)
mask = isfinite(x) & isfinite(y);
x = double(x(mask));
y = double(y(mask));
assert(~isempty(x), 'Cannot fit master curve with no finite data.');

[x, order] = sort(x(:));
y = y(order);
[xUnique, yMean] = averageDuplicateX(x, y);

window = min(max(3, cfg.masterCurveSmoothPoints), numel(xUnique));
if mod(window, 2) == 0 && window > 1
    window = window - 1;
end
if numel(xUnique) < 3
    ySmooth = yMean;
else
    ySmooth = smoothdata(yMean, 'movmean', window);
end

master = struct();
master.x = xUnique(:);
master.y = yMean(:);
master.y_smooth = ySmooth(:);
end

function yq = predictMasterCurve(master, xq)
xqShape = size(xq);
xq = double(xq(:));

if numel(master.x) == 1
    yq = repmat(master.y_smooth(1), size(xq));
    yq = reshape(yq, xqShape);
    return;
end

xMin = master.x(1);
xMax = master.x(end);
xqClamped = min(max(xq, xMin), xMax);
yq = interp1(master.x, master.y_smooth, xqClamped, 'pchip');
yq = reshape(yq, xqShape);
end

function [xUnique, yMean] = averageDuplicateX(x, y)
xUnique = zeros(0, 1);
yMean = zeros(0, 1);
ii = 1;
while ii <= numel(x)
    jj = ii;
    while jj < numel(x) && abs(x(jj + 1) - x(ii)) < 1e-12
        jj = jj + 1;
    end
    xUnique(end + 1, 1) = mean(x(ii:jj)); %#ok<AGROW>
    yMean(end + 1, 1) = mean(y(ii:jj), 'omitnan'); %#ok<AGROW>
    ii = jj + 1;
end
end

function bridge = analyzeRelaxationBridge(aligned)
defs = {
    'X', 'Composite X(T)', aligned.X;
    'I2_peak', 'I_peak(T)^2', aligned.I2_peak;
    'I2R_peak', 'I_peak(T)^2 R(T)', aligned.I2R_peak
    };

summaryTbl = table('Size', [size(defs, 1), 10], ...
    'VariableTypes', {'string','string','double','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'observable_key','display_name','pearson_r','spearman_r','loglog_alpha','loglog_intercept', ...
    'loglog_r2','loglog_rmse','observable_peak_T_K','A_peak_T_K'});

lookup = struct();
for i = 1:size(defs, 1)
    key = string(defs{i, 1});
    displayName = string(defs{i, 2});
    x = defs{i, 3};
    y = aligned.A_interp;
    fit = fitLogLog(x, y);

    summaryTbl.observable_key(i) = key;
    summaryTbl.display_name(i) = displayName;
    summaryTbl.pearson_r(i) = corrSafe(x, y);
    summaryTbl.spearman_r(i) = spearmanSafe(x, y);
    summaryTbl.loglog_alpha(i) = fit.alpha;
    summaryTbl.loglog_intercept(i) = fit.intercept;
    summaryTbl.loglog_r2(i) = fit.r2;
    summaryTbl.loglog_rmse(i) = fit.rmse;
    summaryTbl.observable_peak_T_K(i) = findPeakTemperature(aligned.T_K, x);
    summaryTbl.A_peak_T_K(i) = findPeakTemperature(aligned.T_K, y);

    lookup.(char(key)) = table2struct(summaryTbl(i, :));
    lookup.(char(key)).fit = fit;
end

bridge = struct();
bridge.summaryTable = summaryTbl;
bridge.lookup = lookup;
end

function fit = fitLogLog(x, y)
mask = isfinite(x) & isfinite(y) & x > 0 & y > 0;
if nnz(mask) < 3
    fit = struct('alpha', NaN, 'intercept', NaN, 'r2', NaN, 'rmse', NaN);
    return;
end

lx = log(x(mask));
ly = log(y(mask));
p = polyfit(lx, ly, 1);
yhat = polyval(p, lx);

fit = struct();
fit.alpha = p(1);
fit.intercept = p(2);
fit.r2 = computeR2(ly, yhat);
fit.rmse = computeRMSE(ly, yhat);
end

function decision = determineDecision(modelResults, bridge, aligned, cfg)
bestHeat = modelResults.bestHeatingModel;
geometry = modelResults.geometryModel;
bestHeatBridge = max(abs([bridge.lookup.I2_peak.pearson_r, bridge.lookup.I2R_peak.pearson_r]));
bestGeomBridge = abs(bridge.lookup.X.pearson_r);
ratio = bestHeat.map_cv_rmse_raw / geometry.map_cv_rmse_raw;
hasGoodRidge = isfinite(bestHeat.ridge_rmse_mA) && bestHeat.ridge_rmse_mA <= cfg.ridgeTolerance_mA;

decision = struct();
decision.best_heating_model = bestHeat.key;
decision.rmse_ratio_vs_geometry = ratio;
decision.best_heating_bridge_pearson = bestHeatBridge;
decision.geometry_bridge_pearson = bestGeomBridge;

if ratio <= 0.95 && bestHeatBridge >= (bestGeomBridge - 0.02)
    decision.label = 'heating organizes the data better';
    decision.reason = sprintf(['The best heating-only model (%s) reduces map CV RMSE to %.4g relative to the geometric benchmark %.4g, ', ...
        'and its bridge correlation is not materially weaker than X(T).'], ...
        char(bestHeat.display_name), bestHeat.map_cv_rmse_raw, geometry.map_cv_rmse_raw);
elseif ratio >= (1 + cfg.geometryInferiorityMargin) && bestHeatBridge <= (bestGeomBridge - cfg.correlationMargin)
    decision.label = 'heating is clearly inferior to the geometric switching coordinate';
    decision.reason = sprintf(['The best heating-only model (%s) has a noticeably larger map CV RMSE (%.4g vs %.4g for the geometric benchmark), ', ...
        'and the strongest heating bridge remains weaker than X(T).'], ...
        char(bestHeat.display_name), bestHeat.map_cv_rmse_raw, geometry.map_cv_rmse_raw);
else
    if hasGoodRidge
        bridgeClause = 'Heating captures part of the ridge motion';
    else
        bridgeClause = 'Heating does not cleanly reproduce the ridge trajectory';
    end
    decision.label = 'heating partially contributes';
    decision.reason = sprintf(['%s, but the best heating-only model (%s) does not beat the geometric benchmark in full-map CV RMSE ', ...
        '(%.4g vs %.4g).'], bridgeClause, char(bestHeat.display_name), bestHeat.map_cv_rmse_raw, geometry.map_cv_rmse_raw);
end

decision.supporting_text = sprintf(['Geometric saved collapse metric = %.4g; geometric CV RMSE = %.4g; ', ...
    'best heating CV RMSE = %.4g; Pearson with A(T): X = %.4f, I^2 = %.4f, I^2R = %.4f.'], ...
    aligned.geometrySavedMeanStd, geometry.map_cv_rmse_raw, bestHeat.map_cv_rmse_raw, ...
    bridge.lookup.X.pearson_r, bridge.lookup.I2_peak.pearson_r, bridge.lookup.I2R_peak.pearson_r);
end

function sourceManifestTbl = buildSourceManifestTable(source, prior)
rows = {
    "switching", source.switchRunName, string(source.switchParamPath), "primary switching observables", "I_peak(T), width(T), and S_peak(T) come from switching_full_scaling_parameters.csv.";
    "switching", source.alignRunName, string(source.alignSamplesPath), "switching map source", "S(I,T) comes from the alignment-audit samples CSV referenced by the full-scaling run config.";
    "switching", source.switchFigureRunName, string(fullfile(source.switchFigureRunDir, 'run_manifest.json')), "figure-only context", "Latest figure-repair wrapper for the full-scaling collapse; not used for quantitative observables.";
    "relaxation", source.relaxRunName, string(source.relaxTempPath), "relaxation anchor", "A(T) = A_T and R(T) = R_T are loaded from the relaxation temperature-observable table.";
    "cross_experiment", source.axRunName, string(source.axReportPath), "AX provenance", "Used only to verify which relaxation anchor underlies the saved A-X relation.";
    "cross_experiment", source.compositeRunName, string(prior.compositeReportPath), "prior related scalar scan", "Closest prior power-like scan; includes I^2/w and I^2/S candidates but not an I^2 or I^2R map-level null model."
    };
sourceManifestTbl = cell2table(rows, 'VariableNames', {'experiment','source_run','source_file','role','notes'});
end

function temperatureTbl = buildTemperatureObservableTable(aligned)
temperatureTbl = table(aligned.T_K, aligned.I_peak_mA, aligned.width_mA, aligned.S_peak, ...
    aligned.X, aligned.A_interp, aligned.R_interp, aligned.I2_peak, aligned.I2R_peak, ...
    'VariableNames', {'T_K','I_peak_mA','width_mA','S_peak','X','A_interp','R_interp','I2_peak','I2R_peak'});
end

function coordTbl = buildCoordinateSummaryTable(coordResults)
coordTbl = table();
for i = 1:numel(coordResults.items)
    item = coordResults.items(i);
    row = table(item.key, item.display_name, item.ridge.a, item.ridge.teff_peak_std, item.ridge.teff_peak_span, ...
        item.ridge.pearson_r, item.ridge.spearman_r, item.shiftCollapse.mean_intercurve_std, item.shiftCollapse.mean_rmse_to_mean, ...
        item.shiftCollapse.common_range_min, item.shiftCollapse.common_range_max, ...
        'VariableNames', {'coordinate_key','display_name','ridge_a_fit','ridge_teff_std','ridge_teff_span', ...
        'peak_vs_T_pearson','peak_vs_T_spearman','shift_collapse_mean_std','shift_collapse_mean_rmse', ...
        'shift_common_range_min','shift_common_range_max'});
    coordTbl = [coordTbl; row]; %#ok<AGROW>
end
end
function figPaths = saveCoordinateHeatmaps(aligned, coordResults, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 36 10]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
cmap = parula(256);
cLim = [min(aligned.Smap(:), [], 'omitnan'), max(aligned.Smap(:), [], 'omitnan')];

for i = 1:numel(coordResults.items)
    item = coordResults.items(i);
    ax = nexttile(tl, i);
    hold(ax, 'on');
    surf(ax, item.coordinate_matrix, aligned.T_K .* ones(size(item.coordinate_matrix)), aligned.Smap, ...
        'EdgeColor', 'none', 'FaceColor', 'interp');
    view(ax, 2);
    plot(ax, item.coordinate_peak, aligned.T_K, 'w-', 'LineWidth', 2.2);
    hold(ax, 'off');
    colormap(ax, cmap);
    caxis(ax, cLim);
    xlabel(ax, char(item.axis_label));
    ylabel(ax, 'Temperature (K)');
    title(ax, sprintf('%s map', char(item.display_name)));
    setCommonAxisStyle(ax);
    set(ax, 'YDir', 'normal');
    cb = colorbar(ax);
    cb.Label.String = 'S(I,T)';
end

title(tl, 'Switching map organization under current and heating coordinates');
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveShiftCollapseFigure(coordResults, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 36 10]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numel(coordResults.items)
    item = coordResults.items(i);
    ax = nexttile(tl, i);
    hold(ax, 'on');
    cmap = parula(size(item.shiftCollapse.curve_grid, 1));
    for it = 1:size(item.shiftCollapse.curve_grid, 1)
        plot(ax, item.shiftCollapse.grid, item.shiftCollapse.curve_grid(it, :), '-', ...
            'Color', cmap(it, :), 'LineWidth', 1.7);
    end
    plot(ax, item.shiftCollapse.grid, item.shiftCollapse.mean_curve, 'k-', 'LineWidth', 2.7);
    hold(ax, 'off');
    xlabel(ax, sprintf('Shifted %s', char(item.axis_label)));
    ylabel(ax, 'S / S_{peak}');
    title(ax, sprintf('%s | std = %.3f, RMSE = %.3f', char(item.display_name), ...
        item.shiftCollapse.mean_intercurve_std, item.shiftCollapse.mean_rmse_to_mean));
    setCommonAxisStyle(ax);
    grid(ax, 'on');
    cb = colorbar(ax);
    cb.Label.String = 'Temperature index';
    colormap(ax, cmap);
end

title(tl, 'Shift-only normalized collapse comparisons');
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveModelCollapseFigure(aligned, modelResults, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 36 10]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
cmap = parula(numel(aligned.T_K));
xiMat = modelResults.geometryModel.coordinate_matrix;
for it = 1:size(xiMat, 1)
    plot(ax1, xiMat(it, :), aligned.SnormMap(it, :), '-', 'Color', cmap(it, :), 'LineWidth', 1.7);
end
plot(ax1, modelResults.geometryModel.master_all.x, modelResults.geometryModel.master_all.y_smooth, 'k-', 'LineWidth', 2.8);
hold(ax1, 'off');
xlabel(ax1, '(I - I_{peak}) / width');
ylabel(ax1, 'S / S_{peak}');
title(ax1, sprintf('Geometry baseline | saved std = %.3f, CV RMSE = %.3f', ...
    modelResults.geometryModel.saved_mean_intercurve_std, modelResults.geometryModel.map_cv_rmse_raw));
setCommonAxisStyle(ax1);
cb1 = colorbar(ax1);
cb1.Label.String = 'Temperature index';
colormap(ax1, cmap);

for i = 1:numel(modelResults.heatingModels)
    ax = nexttile(tl, i + 1);
    item = modelResults.heatingModels(i);
    scatter(ax, item.teff_matrix(:), aligned.Smap(:), 28, repelem(aligned.T_K, numel(aligned.currentGrid_mA)), 'filled', ...
        'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0.3);
    hold(ax, 'on');
    plot(ax, item.master_all.x, item.master_all.y_smooth, 'k-', 'LineWidth', 2.8);
    hold(ax, 'off');
    xlabel(ax, 'T + a H(I,T)');
    ylabel(ax, 'S(I,T)');
    title(ax, sprintf('%s | a = %.4g, CV RMSE = %.3f', char(item.coordinate_display), item.a, item.map_cv_rmse_raw));
    setCommonAxisStyle(ax);
    cb = colorbar(ax);
    cb.Label.String = 'Temperature (K)';
    colormap(ax, parula(256));
end

title(tl, 'Geometry collapse benchmark versus heating-only master-curve fits');
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = savePredictionFigure(aligned, modelResults, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 34 18]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
colors = lines(numel(modelResults.heatingModels));

obsDefs = {
    aligned.I_peak_mA, 'I_{peak} (mA)', 'ridge position';
    aligned.width_mA, 'width (mA)', 'ridge width';
    aligned.S_peak, 'S_{peak}', 'ridge amplitude'
    };

for p = 1:3
    ax = nexttile(tl, p);
    hold(ax, 'on');
    plot(ax, aligned.T_K, obsDefs{p, 1}, 'ko-', 'LineWidth', 2.4, 'MarkerFaceColor', 'w', 'DisplayName', 'Observed');
    for i = 1:numel(modelResults.heatingModels)
        item = modelResults.heatingModels(i);
        switch p
            case 1
                yPred = item.I_peak_pred;
            case 2
                yPred = item.width_pred;
            otherwise
                yPred = item.S_peak_pred;
        end
        plot(ax, aligned.T_K, yPred, '-s', 'LineWidth', 2.0, 'Color', colors(i, :), ...
            'MarkerFaceColor', colors(i, :), 'DisplayName', char(item.coordinate_display));
    end
    hold(ax, 'off');
    xlabel(ax, 'Temperature (K)');
    ylabel(ax, obsDefs{p, 2});
    title(ax, sprintf('Heating-only prediction of %s', obsDefs{p, 3}));
    setCommonAxisStyle(ax);
    grid(ax, 'on');
    if p == 1
        legend(ax, 'Location', 'bestoutside');
    end
end

title(tl, 'Heating-only prediction tests for ridge position, width, and amplitude');
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveBridgeScatterFigure(aligned, bridge, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 36 10]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
defs = {
    'X', aligned.X;
    'I2_peak', aligned.I2_peak;
    'I2R_peak', aligned.I2R_peak
    };

for i = 1:size(defs, 1)
    key = defs{i, 1};
    x = defs{i, 2};
    row = bridge.lookup.(key);
    ax = nexttile(tl, i);
    scatter(ax, x, aligned.A_interp, 56, aligned.T_K, 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.5);
    hold(ax, 'on');
    mask = isfinite(x) & isfinite(aligned.A_interp) & x > 0 & aligned.A_interp > 0;
    if nnz(mask) >= 3 && isfinite(row.fit.alpha)
        xFit = linspace(min(x(mask)), max(x(mask)), 200);
        yFit = exp(row.fit.intercept) .* xFit .^ row.fit.alpha;
        plot(ax, xFit, yFit, 'k-', 'LineWidth', 2.2);
        set(ax, 'XScale', 'log', 'YScale', 'log');
    end
    hold(ax, 'off');
    xlabel(ax, char(row.display_name));
    ylabel(ax, 'A(T)');
    title(ax, sprintf('r = %.3f, rho = %.3f, alpha = %.3f', row.pearson_r, row.spearman_r, row.loglog_alpha));
    setCommonAxisStyle(ax);
    grid(ax, 'on');
    cb = colorbar(ax);
    cb.Label.String = 'Temperature (K)';
    colormap(ax, parula(256));
end

title(tl, 'Relaxation-bridge scatter comparisons');
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end
function figPaths = saveBridgeOverlayFigure(aligned, bridge, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 18 11]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, aligned.T_K, normalize01(aligned.A_interp), 'k-o', 'LineWidth', 2.6, 'MarkerFaceColor', 'w', 'DisplayName', 'A(T)');
plot(ax, aligned.T_K, normalize01(aligned.X), '-s', 'LineWidth', 2.0, 'DisplayName', sprintf('X(T), r = %.3f', bridge.lookup.X.pearson_r));
plot(ax, aligned.T_K, normalize01(aligned.I2_peak), '-^', 'LineWidth', 2.0, 'DisplayName', sprintf('I_{peak}^2, r = %.3f', bridge.lookup.I2_peak.pearson_r));
plot(ax, aligned.T_K, normalize01(aligned.I2R_peak), '-d', 'LineWidth', 2.0, 'DisplayName', sprintf('I_{peak}^2 R(T), r = %.3f', bridge.lookup.I2R_peak.pearson_r));
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude');
title(ax, 'Temperature overlays for A(T) and candidate heating bridges');
setCommonAxisStyle(ax);
grid(ax, 'on');
legend(ax, 'Location', 'best');
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function setCommonAxisStyle(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.1, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top');
end

function reportText = buildReportText(source, prior, aligned, coordResults, modelResults, bridge, decision, cfg)
bestHeat = modelResults.bestHeatingModel;
lines = strings(0, 1);

lines(end + 1) = "# Switching Joule-heating null test";
lines(end + 1) = "";
lines(end + 1) = "## 1. Repository state summary";
lines(end + 1) = sprintf('- Switching run used for quantitative observables: `%s`.', char(source.switchRunName));
lines(end + 1) = sprintf('- Latest figure-only wrapper around that collapse: `%s`; it was not used for quantitative values.', char(source.switchFigureRunName));
lines(end + 1) = sprintf('- Relaxation anchor run used for the A-X relation: `%s`, verified from `%s`.', char(source.relaxRunName), char(source.axRunName));
lines(end + 1) = sprintf('- `S(I,T)` originates from `%s` because the full-scaling run points back to that immutable alignment-map source in its config snapshot.', fullfile(char(source.alignRunName), 'alignment_audit', 'switching_alignment_samples.csv'));
lines(end + 1) = sprintf('- `I_peak(T)`, `width(T)`, and `S_peak(T)` originate from `%s`.', fullfile(char(source.switchRunName), 'tables', 'switching_full_scaling_parameters.csv'));
lines(end + 1) = sprintf('- `X(T)` was loaded from the canonical switching X export on the saved switching temperature grid `%s`.', formatTemperatureList(aligned.T_K));
lines(end + 1) = sprintf('- `A(T)` and `R(T)` originate from `%s` via columns `A_T` and `R_T`, interpolated onto the switching grid with `%s`.', fullfile(char(source.relaxRunName), 'tables', 'temperature_observables.csv'), cfg.interpMethod);
if prior.hasDedicatedHeatingRun
    lines(end + 1) = sprintf('- Existing heating/Joule-labelled runs already exist: `%s`.', strjoin([prior.switchHeatingRuns; prior.crossHeatingRuns], '`, `'));
else
    lines(end + 1) = '- Existing heating or Joule-labelled runs found by run-name scan: none.';
end
if prior.compositeRunExists
    lines(end + 1) = sprintf(['- Closest prior related test: `%s`. It scanned scalar squared candidates such as `I^2/w` and `I^2/S`, ', ...
        'but it did not test `I^2` or `I^2R` as map coordinates and did not fit `S(I,T) = G(T + a H)` heating-only models.'], char(source.compositeRunName));
end
lines(end + 1) = "";

lines(end + 1) = "## 2. Heating proxies";
lines(end + 1) = "- `H1(I) = I^2` with `I` in the saved switching current grid (mA).";
lines(end + 1) = "- `H2(I,T) = I^2 R(T)` using the relaxation-anchor resistance curve already stored in the repository.";
lines(end + 1) = sprintf(['- `R(T)` was obtained by loading `%s`, reading column `R_T`, sorting by `T`, ', ...
    'and interpolating that saved resistance curve onto the switching temperatures with `%s`. No new resistance extraction was performed.'], ...
    fullfile(char(source.relaxRunName), 'tables', 'temperature_observables.csv'), cfg.interpMethod);
lines(end + 1) = "- Because all saved switching currents are positive, `I -> I^2` is a monotone reparameterization of the current axis. Any improvement from `I^2` therefore comes from nonlinear axis warping, not from a sign-symmetric power comparison.";
lines(end + 1) = "";

lines(end + 1) = "## 3. Map-level comparison";
lines(end + 1) = tableToMarkdown(buildCoordinateSummaryTable(coordResults));
lines(end + 1) = "";
lines(end + 1) = sprintf('- Saved geometric benchmark from the existing full-scaling run: mean intercurve std `%.4f`, mean RMSE-to-mean `%.4f`.', ...
    aligned.geometrySavedMeanStd, aligned.geometrySavedMeanRmse);
lines(end + 1) = '- Visual comparison figure:';
lines(end + 1) = '![Coordinate maps](../figures/switching_heating_coordinate_maps.png)';
lines(end + 1) = "";
lines(end + 1) = '- Shifted normalized collapse figure:';
lines(end + 1) = '![Shift collapses](../figures/switching_heating_shifted_collapses.png)';
lines(end + 1) = "";

lines(end + 1) = "## 4. Heating-only model test";
lines(end + 1) = "- Model form tested: `S(I,T) ~= G(T + a H(I,T))` with one fixed scalar `a` per heating coordinate, obtained from the ridge-alignment fit `T = T_* - a H_peak(T)`.";
lines(end + 1) = tableToMarkdown(modelResults.summaryTable);
lines(end + 1) = "";
lines(end + 1) = sprintf('- Best heating-only model by cross-validated raw-map RMSE: `%s` with `a = %.4g`, map CV RMSE `%.4f`, ridge RMSE `%.4f mA`, width RMSE `%.4f mA`, and amplitude RMSE `%.4f`.', ...
    char(bestHeat.display_name), bestHeat.a, bestHeat.map_cv_rmse_raw, bestHeat.ridge_rmse_mA, bestHeat.width_rmse_mA, bestHeat.amplitude_rmse);
lines(end + 1) = sprintf('- Geometric benchmark raw-map CV RMSE: `%.4f`.', modelResults.geometryModel.map_cv_rmse_raw);
lines(end + 1) = '- Collapse/model-comparison figure:';
lines(end + 1) = '![Model collapses](../figures/switching_heating_model_collapses.png)';
lines(end + 1) = "";
lines(end + 1) = '- Ridge, width, and amplitude prediction figure:';
lines(end + 1) = '![Model predictions](../figures/switching_heating_model_predictions.png)';
lines(end + 1) = "";

lines(end + 1) = "## 5. Relaxation bridge test";
lines(end + 1) = tableToMarkdown(bridge.summaryTable);
lines(end + 1) = "";
lines(end + 1) = sprintf('- `X(T)` bridge correlation: Pearson `%.4f`, Spearman `%.4f`, log-log exponent `%.4f`.', ...
    bridge.lookup.X.pearson_r, bridge.lookup.X.spearman_r, bridge.lookup.X.loglog_alpha);
lines(end + 1) = sprintf('- `I_peak^2` bridge correlation: Pearson `%.4f`, Spearman `%.4f`, log-log exponent `%.4f`.', ...
    bridge.lookup.I2_peak.pearson_r, bridge.lookup.I2_peak.spearman_r, bridge.lookup.I2_peak.loglog_alpha);
lines(end + 1) = sprintf('- `I_peak^2 R(T)` bridge correlation: Pearson `%.4f`, Spearman `%.4f`, log-log exponent `%.4f`.', ...
    bridge.lookup.I2R_peak.pearson_r, bridge.lookup.I2R_peak.spearman_r, bridge.lookup.I2R_peak.loglog_alpha);
lines(end + 1) = '- Log-log bridge figure:';
lines(end + 1) = '![Bridge scatter](../figures/switching_heating_bridge_scatter.png)';
lines(end + 1) = "";
lines(end + 1) = '- Temperature-overlay bridge figure:';
lines(end + 1) = '![Bridge overlay](../figures/switching_heating_bridge_overlay.png)';
lines(end + 1) = "";

lines(end + 1) = "## 6. Decision summary";
lines(end + 1) = sprintf('- Decision: **%s**.', decision.label);
lines(end + 1) = sprintf('- Main reason: %s', decision.reason);
lines(end + 1) = sprintf('- Supporting metrics: %s', decision.supporting_text);
lines(end + 1) = "";

lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: the shifted-collapse figure shows 14 normalized temperature curves in each coordinate panel; the prediction figure shows one observed curve plus two heating-model predictions per panel; the bridge overlay uses four normalized temperature traces.";
lines(end + 1) = "- legend vs colormap: the 14-curve collapse views and temperature-colored scatter plots use `parula` colorbars; the low-curve overlays use explicit legends.";
lines(end + 1) = "- colormap used: `parula` for all temperature-colored heatmaps and scatter plots.";
lines(end + 1) = sprintf('- smoothing applied: `%d`-point moving-mean smoothing on the pooled one-dimensional master curves `F` and `G`; no smoothing was applied to the saved source observables before fitting.', cfg.masterCurveSmoothPoints);
lines(end + 1) = "- justification: the figure set separates raw map organization, shifted collapse quality, heating-only master-curve fits, prediction diagnostics, and the relaxation bridge so each scientific question is visible on its own axis.";

reportText = strjoin(lines, newline);
end

function txt = formatTemperatureList(T)
txt = strjoin(compose('%.0f K', T(:).'), ', ');
end

function md = tableToMarkdown(tbl)
headers = string(tbl.Properties.VariableNames);
lines = strings(0, 1);
lines(end + 1) = '| ' + strjoin(headers, ' | ') + ' |';
lines(end + 1) = '| ' + strjoin(repmat("---", 1, numel(headers)), ' | ') + ' |';
for r = 1:height(tbl)
    vals = strings(1, width(tbl));
    for c = 1:width(tbl)
        vals(c) = formatMarkdownValue(tbl{r, c});
    end
    lines(end + 1) = '| ' + strjoin(vals, ' | ') + ' |';
end
md = strjoin(lines, newline);
end

function txt = formatMarkdownValue(value)
if iscell(value)
    value = value{1};
end
if isstring(value) || ischar(value)
    txt = string(value);
elseif islogical(value)
    txt = string(value);
elseif isnumeric(value)
    if isscalar(value)
        if ~isfinite(value)
            txt = "NaN";
        elseif abs(value) >= 1e3 || abs(value) <= 1e-3
            txt = string(sprintf('%.4g', value));
        else
            txt = string(sprintf('%.4f', value));
        end
    else
        txt = '[' + strjoin(compose('%.4g', value(:).'), ', ') + ']';
    end
else
    txt = string(value);
end
txt = replace(txt, '|', '\|');
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
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function value = corrSafe(x, y)
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    value = NaN;
    return;
end
x = x(mask);
y = y(mask);
if max(x) - min(x) < 1e-12 || max(y) - min(y) < 1e-12
    value = NaN;
    return;
end
value = corr(x(:), y(:), 'Rows', 'complete', 'Type', 'Pearson');
end

function value = spearmanSafe(x, y)
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    value = NaN;
    return;
end
x = x(mask);
y = y(mask);
if max(x) - min(x) < 1e-12 || max(y) - min(y) < 1e-12
    value = NaN;
    return;
end
value = corr(x(:), y(:), 'Rows', 'complete', 'Type', 'Spearman');
end

function value = computeR2(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if nnz(mask) < 2
    value = NaN;
    return;
end
y = y(mask);
yhat = yhat(mask);
sst = sum((y - mean(y)).^2);
if sst <= eps
    value = NaN;
    return;
end
sse = sum((y - yhat).^2);
value = 1 - sse / sst;
end

function value = computeRMSE(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if ~any(mask)
    value = NaN;
    return;
end
res = y(mask) - yhat(mask);
value = sqrt(mean(res.^2));
end

function value = computeNRMSE(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if ~any(mask)
    value = NaN;
    return;
end
y = y(mask);
yhat = yhat(mask);
scale = max(y) - min(y);
if ~isfinite(scale) || scale <= eps
    value = NaN;
else
    value = computeRMSE(y, yhat) / scale;
end
end

function Tpeak = findPeakTemperature(T, y)
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    Tpeak = NaN;
    return;
end
[~, idx] = max(y(mask));
Tvalid = T(mask);
Tpeak = Tvalid(idx);
end

function yNorm = normalize01(y)
mask = isfinite(y);
yNorm = NaN(size(y));
if ~any(mask)
    return;
end
yMin = min(y(mask));
yMax = max(y(mask));
if abs(yMax - yMin) < eps
    yNorm(mask) = 0;
else
    yNorm(mask) = (y(mask) - yMin) ./ (yMax - yMin);
end
end

function appendText(filePath, textToAppend)
fid = fopen(filePath, 'a');
if fid < 0
    error('Could not append to file: %s', filePath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textToAppend);
end

function stamp = stampNow()
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end



