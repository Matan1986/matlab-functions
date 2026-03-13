function out = switching_effective_observables(cfg)
% switching_effective_observables
% Extract reduced switching observables from saved collapse-ready inputs.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('full_scaling:%s | alignment:%s', ...
    char(source.fullScalingRunId), char(source.alignmentRunId));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching effective-observables run directory:\n%s\n', runDir);
fprintf('Full-scaling source run: %s\n', source.fullScalingRunId);
fprintf('Alignment source run: %s\n', source.alignmentRunId);

appendText(run.log_path, sprintf('[%s] switching effective observables started\n', stampNow()));
appendText(run.log_path, sprintf('Full-scaling source: %s\n', char(source.fullScalingRunId)));
appendText(run.log_path, sprintf('Alignment source: %s\n', char(source.alignmentRunId)));

paramsTbl = readtable(source.fullScalingParamsPath);
paramsTbl = sortrows(paramsTbl, 'T_K');
samplesTbl = readtable(source.alignmentSamplesPath);
sourceObsTbl = readtable(source.alignmentObservablesPath);

[tempsMap, currents, Smap] = buildSwitchingMapRounded(samplesTbl);
currents = currents(:)';

keepMask = paramsTbl.T_K >= cfg.temperatureMinK & paramsTbl.T_K <= cfg.temperatureMaxK;
paramsTbl = paramsTbl(keepMask, :);

[temps, iParams, iMap] = intersect(paramsTbl.T_K, tempsMap, 'stable');
assert(~isempty(temps), ...
    'No common temperatures between the saved full-scaling table and alignment map.');

paramsTbl = paramsTbl(iParams, :);
Smap = Smap(iMap, :);
temps = temps(:);

sourceCheckTbl = buildSourceConsistencyTable(paramsTbl, currents, Smap);
sourceCheckPath = save_run_table(sourceCheckTbl, 'switching_effective_source_consistency.csv', runDir);

wLeft = paramsTbl.Ipeak_mA - paramsTbl.left_half_current_mA;
wRight = paramsTbl.right_half_current_mA - paramsTbl.Ipeak_mA;
asym = (wRight - wLeft) ./ paramsTbl.width_chosen_mA;
X = paramsTbl.Ipeak_mA ./ (paramsTbl.width_chosen_mA .* paramsTbl.S_peak);

collapse = collectScaledCurves(paramsTbl, currents, Smap, paramsTbl.width_chosen_mA);
collapseMetrics = evaluateCollapseDetailed(collapse, cfg.collapseGridSize);
assert(numel(collapseMetrics.curve_rmse) == numel(temps), ...
    'Collapse residual count does not match the temperature grid.');

observablesTbl = table( ...
    temps, paramsTbl.Ipeak_mA, paramsTbl.width_chosen_mA, paramsTbl.S_peak, ...
    X, collapseMetrics.curve_rmse(:), asym(:), ...
    'VariableNames', {'T_K','I_peak_mA','width_mA','S_peak','X','collapse_defect','asym'});

observablesRootPath = fullfile(runDir, 'observables.csv');
writetable(observablesTbl, observablesRootPath);

effectiveObsPath = save_run_table(observablesTbl, 'switching_effective_observables_table.csv', runDir);
XTablePath = save_run_table(table(temps, X, 'VariableNames', {'T_K','X'}), ...
    'switching_effective_coordinate_x.csv', runDir);

collapseSummaryTbl = table( ...
    collapseMetrics.num_curves, collapseMetrics.common_range_min, collapseMetrics.common_range_max, ...
    collapseMetrics.mean_std, collapseMetrics.mean_variance, collapseMetrics.mean_rmse_to_mean, ...
    collapseMetrics.global_collapse_defect, ...
    'VariableNames', {'n_curves','common_range_min','common_range_max', ...
    'mean_intercurve_std','mean_intercurve_variance','mean_rmse_to_master', ...
    'collapse_defect_global'});
collapseSummaryPath = save_run_table(collapseSummaryTbl, 'switching_effective_collapse_metrics.csv', runDir);

curveResidualTbl = table( ...
    collapseMetrics.temps(:), collapseMetrics.curve_rmse(:), ...
    collapseMetrics.curve_mean_abs_residual(:), collapseMetrics.curve_max_abs_residual(:), ...
    collapseMetrics.curve_bias(:), collapseMetrics.n_common_samples(:), ...
    'VariableNames', {'T_K','collapse_defect','mean_abs_residual','max_abs_residual', ...
    'mean_signed_residual','n_common_samples'});
curveResidualPath = save_run_table(curveResidualTbl, 'switching_effective_collapse_defect_vs_T.csv', runDir);

masterCurveTbl = table( ...
    collapseMetrics.x_grid(:), collapseMetrics.mean_curve(:), ...
    collapseMetrics.point_std(:), collapseMetrics.point_variance(:), ...
    'VariableNames', {'x_scaled','master_curve','intercurve_std','intercurve_variance'});
masterCurvePath = save_run_table(masterCurveTbl, 'switching_effective_master_curve.csv', runDir);

residualProfileTbl = buildResidualProfileTable(collapseMetrics);
residualProfilePath = save_run_table(residualProfileTbl, ...
    'switching_effective_collapse_residual_profiles.csv', runDir);

mapLongTbl = buildMapLongTable(temps, currents, Smap);
mapLongPath = save_run_table(mapLongTbl, 'switching_effective_switching_map.csv', runDir);

sourceManifestTbl = buildSourceManifestTable(source);
sourceManifestPath = save_run_table(sourceManifestTbl, 'switching_effective_sources.csv', runDir);

alignmentAsymTbl = buildAlignmentAsymmetryComparison(temps, asym, sourceObsTbl);
alignmentAsymPath = save_run_table(alignmentAsymTbl, ...
    'switching_effective_asymmetry_comparison.csv', runDir);

figIpeak = plotObservableVsTemperature(temps, paramsTbl.Ipeak_mA, ...
    'switching_effective_Ipeak_vs_T', 'Temperature (K)', 'I_{peak} (mA)', ...
    'Peak current vs temperature', runDir, struct('color', [0.00 0.45 0.74]));

figWidth = plotObservableVsTemperature(temps, paramsTbl.width_chosen_mA, ...
    'switching_effective_width_vs_T', 'Temperature (K)', 'width(T) (mA)', ...
    'Collapse width vs temperature', runDir, struct('color', [0.85 0.33 0.10]));

figSpeak = plotObservableVsTemperature(temps, paramsTbl.S_peak, ...
    'switching_effective_Speak_vs_T', 'Temperature (K)', 'S_{peak} (P2P percent)', ...
    'Switching peak amplitude vs temperature', runDir, struct('color', [0.47 0.67 0.19]));

figX = plotObservableVsTemperature(temps, X, ...
    'switching_effective_X_vs_T', 'Temperature (K)', 'X(T) ((P2P percent)^{-1})', ...
    'Composite coordinate X(T)', runDir, struct('color', [0.49 0.18 0.56]));

figDefect = plotCollapseDefectFigure(temps, collapseMetrics, runDir, ...
    'switching_effective_collapse_defect_vs_T');

figAsym = plotObservableVsTemperature(temps, asym, ...
    'switching_effective_asymmetry_vs_T', 'Temperature (K)', 'asym(T) (dimensionless)', ...
    'Interpolated half-width asymmetry vs temperature', runDir, ...
    struct('color', [0.64 0.08 0.18], 'showZeroLine', true));

reportText = buildReportText(source, paramsTbl, collapseMetrics, observablesTbl, ...
    figIpeak, figWidth, figSpeak, figX, figDefect, figAsym, ...
    observablesRootPath, effectiveObsPath, XTablePath, collapseSummaryPath, ...
    curveResidualPath, residualProfilePath, mapLongPath, sourceManifestPath, ...
    sourceCheckPath, alignmentAsymPath);
reportPath = save_run_report(reportText, 'switching_effective_observables.md', runDir);

appendText(run.notes_path, sprintf('Full-scaling source run = %s\n', char(source.fullScalingRunId)));
appendText(run.notes_path, sprintf('Alignment source run = %s\n', char(source.alignmentRunId)));
appendText(run.notes_path, sprintf('Global collapse_defect = %.6f\n', collapseMetrics.global_collapse_defect));
appendText(run.notes_path, sprintf('Mean RMSE to master = %.6f\n', collapseMetrics.mean_rmse_to_mean));
appendText(run.notes_path, sprintf('X(T) range = [%.6f, %.6f]\n', min(X), max(X)));

zipPath = buildReviewZip(runDir, 'switching_effective_observables_bundle.zip');

appendText(run.log_path, sprintf('[%s] switching effective observables complete\n', stampNow()));
appendText(run.log_path, sprintf('Observables root CSV: %s\n', observablesRootPath));
appendText(run.log_path, sprintf('Detailed observables table: %s\n', effectiveObsPath));
appendText(run.log_path, sprintf('X table: %s\n', XTablePath));
appendText(run.log_path, sprintf('Collapse metrics: %s\n', collapseSummaryPath));
appendText(run.log_path, sprintf('Collapse residuals by T: %s\n', curveResidualPath));
appendText(run.log_path, sprintf('Residual profiles: %s\n', residualProfilePath));
appendText(run.log_path, sprintf('Master curve: %s\n', masterCurvePath));
appendText(run.log_path, sprintf('Switching map table: %s\n', mapLongPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', sourceManifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.observables = observablesTbl;
out.collapseMetrics = collapseMetrics;
out.paths = struct( ...
    'observablesRoot', string(observablesRootPath), ...
    'observablesTable', string(effectiveObsPath), ...
    'XTable', string(XTablePath), ...
    'collapseSummary', string(collapseSummaryPath), ...
    'curveResiduals', string(curveResidualPath), ...
    'residualProfiles', string(residualProfilePath), ...
    'masterCurve', string(masterCurvePath), ...
    'map', string(mapLongPath), ...
    'sourceManifest', string(sourceManifestPath), ...
    'sourceConsistency', string(sourceCheckPath), ...
    'alignmentAsymmetry', string(alignmentAsymPath), ...
    'report', string(reportPath), ...
    'zip', string(zipPath));
out.figures = struct( ...
    'Ipeak', string(figIpeak.png), ...
    'width', string(figWidth.png), ...
    'Speak', string(figSpeak.png), ...
    'X', string(figX.png), ...
    'collapse_defect', string(figDefect.png), ...
    'asym', string(figAsym.png));

fprintf('\n=== Switching effective observables complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Global collapse_defect = %.6f\n', collapseMetrics.global_collapse_defect);
fprintf('Mean RMSE to master = %.6f\n', collapseMetrics.mean_rmse_to_mean);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_effective_observables');
cfg = setDefaultField(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'collapseGridSize', 200);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.fullScalingRunId = string(cfg.fullScalingRunId);
source.alignmentRunId = string(cfg.alignmentRunId);
source.fullScalingRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.fullScalingRunId));
source.alignmentRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.alignmentRunId));
source.fullScalingParamsPath = fullfile(char(source.fullScalingRunDir), 'tables', ...
    'switching_full_scaling_parameters.csv');
source.alignmentAnalysisDir = fullfile(char(source.alignmentRunDir), 'alignment_audit');
source.alignmentSamplesPath = fullfile(char(source.alignmentAnalysisDir), ...
    'switching_alignment_samples.csv');
source.alignmentObservablesPath = fullfile(char(source.alignmentAnalysisDir), ...
    'switching_alignment_observables_vs_T.csv');
source.fullScalingReportPath = fullfile(char(source.fullScalingRunDir), 'reports', ...
    'switching_full_scaling_collapse.md');

requiredPaths = { ...
    source.fullScalingRunDir, source.fullScalingParamsPath; ...
    source.alignmentRunDir, source.alignmentSamplesPath; ...
    source.alignmentAnalysisDir, source.alignmentObservablesPath};

for i = 1:size(requiredPaths, 1)
    if exist(requiredPaths{i, 1}, 'dir') ~= 7
        error('Required source run directory not found: %s', requiredPaths{i, 1});
    end
    if exist(requiredPaths{i, 2}, 'file') ~= 2
        error('Required source file not found: %s', requiredPaths{i, 2});
    end
end
end

function tbl = buildSourceConsistencyTable(paramsTbl, currents, Smap)
nTemps = height(paramsTbl);
IpeakFromMap = NaN(nTemps, 1);
SpeakFromMap = NaN(nTemps, 1);

for it = 1:nTemps
    row = Smap(it, :);
    valid = isfinite(row) & isfinite(currents);
    currValid = currents(valid);
    rowValid = row(valid);
    [SpeakFromMap(it), idx] = max(rowValid);
    IpeakFromMap(it) = currValid(idx);
end

tbl = table( ...
    paramsTbl.T_K, IpeakFromMap, paramsTbl.Ipeak_mA, IpeakFromMap - paramsTbl.Ipeak_mA, ...
    SpeakFromMap, paramsTbl.S_peak, SpeakFromMap - paramsTbl.S_peak, ...
    'VariableNames', {'T_K','I_peak_from_map_mA','I_peak_from_full_scaling_mA','delta_I_peak_mA', ...
    'S_peak_from_map','S_peak_from_full_scaling','delta_S_peak'});
end

function collapse = collectScaledCurves(paramsTbl, currents, Smap, widthVec)
curveTemps = NaN(height(paramsTbl), 1);
xCurves = cell(height(paramsTbl), 1);
yCurves = cell(height(paramsTbl), 1);

for it = 1:height(paramsTbl)
    widthVal = widthVec(it);
    assert(isfinite(widthVal) && abs(widthVal) > eps, ...
        'Encountered a non-finite collapse width at T = %.2f K.', paramsTbl.T_K(it));

    row = Smap(it, :);
    valid = isfinite(row) & isfinite(currents);
    assert(nnz(valid) >= 2, 'Not enough valid S(I) points at T = %.2f K.', paramsTbl.T_K(it));

    x = (currents(valid) - paramsTbl.Ipeak_mA(it)) ./ widthVal;
    y = row(valid) ./ paramsTbl.S_peak(it);
    [x, sortIdx] = sort(x(:));
    y = y(sortIdx);
    [x, uniqueIdx] = unique(x, 'stable');
    y = y(uniqueIdx);

    curveTemps(it) = paramsTbl.T_K(it);
    xCurves{it} = x;
    yCurves{it} = y;
end

collapse = struct();
collapse.temps = curveTemps;
collapse.x = xCurves;
collapse.y = yCurves;
end

function metrics = evaluateCollapseDetailed(collapse, gridSize)
if nargin < 2 || isempty(gridSize)
    gridSize = 200;
end

metrics = struct( ...
    'temps', collapse.temps(:), ...
    'num_curves', numel(collapse.temps), ...
    'common_range_min', NaN, ...
    'common_range_max', NaN, ...
    'mean_std', NaN, ...
    'mean_variance', NaN, ...
    'mean_rmse_to_mean', NaN, ...
    'global_collapse_defect', NaN, ...
    'x_grid', [], ...
    'y_grid', [], ...
    'mean_curve', [], ...
    'point_std', [], ...
    'point_variance', [], ...
    'curve_rmse', [], ...
    'curve_mean_abs_residual', [], ...
    'curve_max_abs_residual', [], ...
    'curve_bias', [], ...
    'n_common_samples', []);

if numel(collapse.temps) < 2
    return;
end

xMin = cellfun(@(x) min(x), collapse.x);
xMax = cellfun(@(x) max(x), collapse.x);
xLo = max(xMin);
xHi = min(xMax);

if ~isfinite(xLo) || ~isfinite(xHi) || xLo >= xHi
    return;
end

xGrid = linspace(xLo, xHi, gridSize);
Ygrid = NaN(numel(collapse.temps), numel(xGrid));
for it = 1:numel(collapse.temps)
    Ygrid(it, :) = interp1(collapse.x{it}, collapse.y{it}, xGrid, 'linear', NaN);
end

meanCurve = mean(Ygrid, 1, 'omitnan');
pointStd = std(Ygrid, 0, 1, 'omitnan');
pointVariance = pointStd .^ 2;
residuals = Ygrid - meanCurve;
curveRmse = sqrt(mean(residuals .^ 2, 2, 'omitnan'));
curveMeanAbs = mean(abs(residuals), 2, 'omitnan');
curveMaxAbs = max(abs(residuals), [], 2, 'omitnan');
curveBias = mean(residuals, 2, 'omitnan');
nCommonSamples = sum(isfinite(Ygrid), 2);

metrics.common_range_min = xLo;
metrics.common_range_max = xHi;
metrics.mean_std = mean(pointStd, 'omitnan');
metrics.mean_variance = mean(pointVariance, 'omitnan');
metrics.mean_rmse_to_mean = mean(curveRmse, 'omitnan');
metrics.global_collapse_defect = metrics.mean_std;
metrics.x_grid = xGrid(:);
metrics.y_grid = Ygrid;
metrics.mean_curve = meanCurve(:);
metrics.point_std = pointStd(:);
metrics.point_variance = pointVariance(:);
metrics.curve_rmse = curveRmse(:);
metrics.curve_mean_abs_residual = curveMeanAbs(:);
metrics.curve_max_abs_residual = curveMaxAbs(:);
metrics.curve_bias = curveBias(:);
metrics.n_common_samples = nCommonSamples(:);
end

function tbl = buildResidualProfileTable(collapseMetrics)
nTemps = numel(collapseMetrics.temps);
nGrid = numel(collapseMetrics.x_grid);

Tcol = repelem(collapseMetrics.temps(:), nGrid, 1);
xcol = repmat(collapseMetrics.x_grid(:), nTemps, 1);
ycol = reshape(collapseMetrics.y_grid.', [], 1);
masterCol = repmat(collapseMetrics.mean_curve(:), nTemps, 1);
residualCol = ycol - masterCol;

tbl = table(Tcol, xcol, ycol, masterCol, residualCol, ...
    'VariableNames', {'T_K','x_scaled','y_scaled','master_curve','residual'});
end

function tbl = buildMapLongTable(temps, currents, Smap)
[TT, II] = ndgrid(temps(:), currents(:));
tbl = table(TT(:), II(:), reshape(Smap, [], 1), ...
    'VariableNames', {'T_K','current_mA','S_percent'});
end

function tbl = buildSourceManifestTable(source)
runRole = string({'full_scaling_observables'; 'alignment_switching_map'; ...
    'alignment_observables_reference'; 'full_scaling_report'});
runId = [source.fullScalingRunId; source.alignmentRunId; ...
    source.alignmentRunId; source.fullScalingRunId];
filePath = string({source.fullScalingParamsPath; source.alignmentSamplesPath; ...
    source.alignmentObservablesPath; source.fullScalingReportPath});
tbl = table(runRole, runId, filePath(:), ...
    'VariableNames', {'role','source_run_id','source_file'});
end

function tbl = buildAlignmentAsymmetryComparison(temps, asymInterpHalfwidth, sourceObsTbl)
sourceTemps = numericColumn(sourceObsTbl, 'T_K');
legacyHalfwidth = numericColumn(sourceObsTbl, 'halfwidth_diff_norm');
legacyAreaRatio = numericColumn(sourceObsTbl, 'asym');

[commonTemps, iThis, iSource] = intersect(temps(:), sourceTemps(:), 'stable');
tbl = table( ...
    commonTemps, asymInterpHalfwidth(iThis), legacyHalfwidth(iSource), legacyAreaRatio(iSource), ...
    asymInterpHalfwidth(iThis) - legacyHalfwidth(iSource), ...
    'VariableNames', {'T_K','asym_interp_halfwidth','halfwidth_diff_norm_source', ...
    'area_ratio_asym_source','delta_vs_source_halfwidth'});
end

function figPaths = plotObservableVsTemperature(temps, values, figureName, xLabelText, yLabelText, titleText, runDir, opts)
if nargin < 8 || ~isstruct(opts)
    opts = struct();
end

color = getOpt(opts, 'color', [0.00 0.45 0.74]);
showZeroLine = logical(getOpt(opts, 'showZeroLine', false));

fig = figure('Color', 'w', 'Visible', 'off');
set(fig, 'Units', 'centimeters', 'Position', [2 2 8.6 6.2], ...
    'PaperUnits', 'centimeters', 'PaperPosition', [0 0 8.6 6.2], ...
    'PaperSize', [8.6 6.2]);
ax = axes(fig);
hold(ax, 'on');
if showZeroLine
    yline(ax, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.0);
end
plot(ax, temps, values, '-o', ...
    'Color', color, ...
    'MarkerFaceColor', color, ...
    'MarkerEdgeColor', [0.10 0.10 0.10], ...
    'LineWidth', 1.8, ...
    'MarkerSize', 5);
hold(ax, 'off');
xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
title(ax, titleText);
styleLineAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = plotCollapseDefectFigure(temps, collapseMetrics, runDir, figureName)
fig = figure('Color', 'w', 'Visible', 'off');
set(fig, 'Units', 'centimeters', 'Position', [2 2 8.6 6.2], ...
    'PaperUnits', 'centimeters', 'PaperPosition', [0 0 8.6 6.2], ...
    'PaperSize', [8.6 6.2]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, temps, collapseMetrics.curve_rmse, '-o', ...
    'Color', [0.85 0.33 0.10], ...
    'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerEdgeColor', [0.10 0.10 0.10], ...
    'LineWidth', 1.8, ...
    'MarkerSize', 5, ...
    'DisplayName', 'curve RMSE to master');
plot(ax, temps, repmat(collapseMetrics.global_collapse_defect, size(temps)), '--', ...
    'Color', [0 0 0], 'LineWidth', 1.4, 'DisplayName', 'global collapse_defect');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'collapse defect (dimensionless)');
title(ax, 'Temperature-resolved collapse defect');
legend(ax, 'Location', 'best');
styleLineAxes(ax);
text(ax, 0.04, 0.96, sprintf('global collapse_defect = %.4f\nmean RMSE = %.4f', ...
    collapseMetrics.global_collapse_defect, collapseMetrics.mean_rmse_to_mean), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'BackgroundColor', [1 1 1], 'Margin', 4, 'FontSize', 8);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function reportText = buildReportText(source, paramsTbl, collapseMetrics, observablesTbl, ...
    figIpeak, figWidth, figSpeak, figX, figDefect, figAsym, ...
    observablesRootPath, effectiveObsPath, XTablePath, collapseSummaryPath, ...
    curveResidualPath, residualProfilePath, mapLongPath, sourceManifestPath, ...
    sourceCheckPath, alignmentAsymPath)

widthMethods = unique(string(paramsTbl.width_method));
widthMethodText = strjoin(cellstr(widthMethods), ', ');
if all(string(paramsTbl.width_method) == "fwhm")
    widthSummary = "All temperatures in the 4-30 K collapse window used the interpolated FWHM width directly; the sigma fallback was not needed in this filtered window.";
else
    widthSummary = "The filtered window mixes interpolated FWHM widths with sigma fallbacks as recorded in the saved full-scaling parameter table.";
end

lines = strings(0, 1);
lines(end + 1) = "# Switching effective observables";
lines(end + 1) = "";
lines(end + 1) = "## 1. Repository state summary";
lines(end + 1) = "- Switching run used for `I_peak(T)`, `width(T)`, and `S_peak(T)`: `" + string(source.fullScalingRunId) + "`.";
lines(end + 1) = "- Upstream alignment-map run reused for `S(I,T)`: `" + string(source.alignmentRunId) + "`.";
lines(end + 1) = "- `I_peak(T)` was taken from the saved `Ipeak_mA` column in `switching_full_scaling_parameters.csv`, which is the current at the row maximum of the rounded switching map `S(I,T)`.";
lines(end + 1) = "- `S_peak(T)` was taken from the saved `S_peak` column in the same full-scaling table, i.e. the value of the row maximum of `S(I,T)`.";
lines(end + 1) = "- `width(T)` was taken from the saved `width_chosen_mA` column, produced in `switching_full_scaling_collapse.m` using interpolated FWHM crossings with a weighted local sigma fallback only when FWHM is unresolved.";
lines(end + 1) = "- Width methods present in this run: `" + string(widthMethodText) + "`.";
lines(end + 1) = "- " + widthSummary;
lines(end + 1) = "- Scripts/functions reused: `Switching/analysis/switching_full_scaling_collapse.m`, `Switching/analysis/switching_alignment_audit.m`, `Switching/utils/buildSwitchingMapRounded.m`, `tools/save_run_figure.m`, `tools/save_run_table.m`, `tools/save_run_report.m`, `Aging/utils/createRunContext.m`.";
lines(end + 1) = "- Source-artifact manifest: `" + string(sourceManifestPath) + "`.";
lines(end + 1) = "- Source-consistency check table: `" + string(sourceCheckPath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## 2. Primary effective coordinate";
lines(end + 1) = "- Definition: `X(T) = I_peak(T) / (width(T) * S_peak(T))`.";
lines(end + 1) = "- Temperature range analyzed: `" + sprintf('%.0f-%.0f K', min(observablesTbl.T_K), max(observablesTbl.T_K)) + "` (" + string(height(observablesTbl)) + " temperatures).";
lines(end + 1) = "- `X(T)` range in this run: `[" + sprintf('%.6f, %.6f', min(observablesTbl.X), max(observablesTbl.X)) + "]`.";
lines(end + 1) = "- X-table: `" + string(XTablePath) + "`.";
lines(end + 1) = "- Final observables table (also copied to run-root `observables.csv`): `" + string(effectiveObsPath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "![Ipeak](../figures/switching_effective_Ipeak_vs_T.png)";
lines(end + 1) = "";
lines(end + 1) = "![Width](../figures/switching_effective_width_vs_T.png)";
lines(end + 1) = "";
lines(end + 1) = "![Speak](../figures/switching_effective_Speak_vs_T.png)";
lines(end + 1) = "";
lines(end + 1) = "![X](../figures/switching_effective_X_vs_T.png)";
lines(end + 1) = "";
lines(end + 1) = "## 3. Collapse defect";
lines(end + 1) = "- Collapse normalization reused from the saved full-scaling run: `S(I,T) / S_peak(T)` versus `(I - I_peak(T)) / width(T)`.";
lines(end + 1) = "- Common scaled-current range across all retained temperatures: `[" + sprintf('%.4f, %.4f', collapseMetrics.common_range_min, collapseMetrics.common_range_max) + "]`.";
lines(end + 1) = "- Mean inter-curve standard deviation after collapse: `" + sprintf('%.6f', collapseMetrics.mean_std) + "`.";
lines(end + 1) = "- Mean inter-curve variance after collapse: `" + sprintf('%.6f', collapseMetrics.mean_variance) + "`.";
lines(end + 1) = "- Mean RMSE to the master curve: `" + sprintf('%.6f', collapseMetrics.mean_rmse_to_mean) + "`.";
lines(end + 1) = "- Global observable definition: `collapse_defect = mean inter-curve std = " + sprintf('%.6f', collapseMetrics.global_collapse_defect) + "`.";
lines(end + 1) = "- The per-temperature `collapse_defect` column in the final observables table is the RMSE of each collapsed curve to the master curve on the common scaled-current domain.";
lines(end + 1) = "- Global collapse table: `" + string(collapseSummaryPath) + "`.";
lines(end + 1) = "- Temperature-resolved defect table: `" + string(curveResidualPath) + "`.";
lines(end + 1) = "- Residual profiles on the shared scaled-current grid: `" + string(residualProfilePath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "![Collapse defect](../figures/switching_effective_collapse_defect_vs_T.png)";
lines(end + 1) = "";
lines(end + 1) = "## 4. Shape asymmetry";
lines(end + 1) = "- Adopted asymmetry coordinate: interpolated `halfwidth_diff_norm = (w_R - w_L) / (w_R + w_L)`, using the same left/right half-maximum crossings already saved in the full-scaling parameter table.";
lines(end + 1) = "- This matches the existing switching asymmetry family used in the alignment and mechanism analyses while staying consistent with the collapse width definition.";
lines(end + 1) = "- Comparison to the legacy alignment-audit asymmetry exports: `" + string(alignmentAsymPath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "![Asymmetry](../figures/switching_effective_asymmetry_vs_T.png)";
lines(end + 1) = "";
lines(end + 1) = "## 5. Output tables";
lines(end + 1) = "- Run-root observables index: `" + string(observablesRootPath) + "`.";
lines(end + 1) = "- Detailed observables table: `" + string(effectiveObsPath) + "`.";
lines(end + 1) = "- Saved switching map `S(I,T)` in long-table form: `" + string(mapLongPath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## 6. Figures";
lines(end + 1) = "- `I_peak(T)`: `" + string(figIpeak.png) + "`.";
lines(end + 1) = "- `width(T)`: `" + string(figWidth.png) + "`.";
lines(end + 1) = "- `S_peak(T)`: `" + string(figSpeak.png) + "`.";
lines(end + 1) = "- `X(T)`: `" + string(figX.png) + "`.";
lines(end + 1) = "- `collapse defect(T)`: `" + string(figDefect.png) + "`.";
lines(end + 1) = "- `asym(T)`: `" + string(figAsym.png) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: each exported figure is a single observable-versus-temperature curve, except the collapse-defect panel which overlays the temperature-resolved defect and one global-reference line";
lines(end + 1) = "- legend vs colormap: no colormap was needed because no panel contains more than two curves; the collapse-defect figure uses a legend";
lines(end + 1) = "- colormap used: none in the six requested summary figures";
lines(end + 1) = "- smoothing applied: none; all quantities were computed from saved immutable source tables and the rounded switching map";
lines(end + 1) = "- justification: single-panel observable figures best match the request for a reduced physical description and keep each exported artifact readable in isolation";
lines(end + 1) = "";
lines(end + 1) = "## Review bundle";
lines(end + 1) = "- ZIP bundle: `review/switching_effective_observables_bundle.zip`.";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end
function styleLineAxes(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 8, ...
    'LineWidth', 1.0, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top', ...
    'XMinorTick', 'off', ...
    'YMinorTick', 'off');
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(runDir, 'review', zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'observables.csv', ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function value = numericColumn(tbl, varName)
value = switchingNumericColumn(tbl, varName);
value = value(:);
end

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', char(string(textValue)));
end

function out = stampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end

function value = getOpt(opts, fieldName, defaultValue)
if isstruct(opts) && isfield(opts, fieldName) && ~isempty(opts.(fieldName))
    value = opts.(fieldName);
else
    value = defaultValue;
end
end

