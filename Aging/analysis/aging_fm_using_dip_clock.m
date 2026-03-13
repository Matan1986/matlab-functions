function out = aging_fm_using_dip_clock(cfg)
% aging_fm_using_dip_clock
% Test whether FM_abs collapses under the Dip-derived aging timescale.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg, repoRoot);
assert(exist(cfg.datasetPath, 'file') == 2, 'Dataset not found: %s', cfg.datasetPath);
assert(exist(cfg.tauPath, 'file') == 2, 'Tau table not found: %s', cfg.tauPath);

cfgRun = struct();
cfgRun.runLabel = char(string(cfg.runLabel));
cfgRun.datasetName = 'aging_observable_dataset';
cfgRun.dataset = char(string(cfg.datasetPath));
cfgRun.tau_source = char(string(cfg.tauPath));
runCtx = createRunContext('aging', cfgRun);
runDir = runCtx.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging FM-using-Dip-clock run root:\n%s\n', runDir);
fprintf('Input dataset: %s\n', cfg.datasetPath);
fprintf('Input tau table: %s\n', cfg.tauPath);
appendText(runCtx.log_path, sprintf('[%s] started\n', stampNow()));
appendText(runCtx.log_path, sprintf('Dataset: %s\n', cfg.datasetPath));
appendText(runCtx.log_path, sprintf('Tau source: %s\n', cfg.tauPath));

dataTbl = loadObservableDataset(cfg.datasetPath);
tauTbl = loadTauTable(cfg.tauPath);
matrixData = buildObservableMatrices(dataTbl);
tauModel = buildTauModel(tauTbl);
curves = buildFmCurves(matrixData, dataTbl, tauModel);
validCurves = curves([curves.has_fm]);
missingCurves = curves(~[curves.has_fm]);
assert(numel(validCurves) >= 3, 'Need at least three T_p values with finite FM_abs.');

baseline = evaluateScenario(validCurves, tauModel, cfg, 0, 'baseline_all_fm', 'All finite-FM temperatures');
exclude34 = evaluateScenario(validCurves(abs([validCurves.Tp] - 34) > 1e-9), tauModel, cfg, 0, 'exclude_tp_34', 'Exclude T_p = 34 K');
excludeFragile = evaluateScenario(validCurves(~ismember(round([validCurves.Tp]), [30 34])), tauModel, cfg, 0, 'exclude_tp_30_34', 'Exclude fragile 30 K and 34 K');
shiftResult = fitBestShift(validCurves, tauModel, cfg, baseline);
dominance = analyzeDominance(validCurves, tauModel, cfg, baseline);
rawDiag = buildRawDiagnostics(validCurves, baseline);
metricsTbl = buildMetricsTable(baseline, exclude34, excludeFragile, shiftResult, rawDiag, dominance);
metricsPath = save_run_table(metricsTbl, 'fm_collapse_using_dip_tau_metrics.csv', runDir);

figRaw = makeRawFigure(validCurves, missingCurves, rawDiag, cfg);
figRawPaths = save_run_figure(figRaw, 'fm_raw_vs_tw', runDir);
close(figRaw);

figRescaled = makeRescaledFigure(validCurves, baseline, cfg);
figRescaledPaths = save_run_figure(figRescaled, 'fm_rescaled_vs_tw_over_tau_dip', runDir);
close(figRescaled);

figTau = makeTauFigure(tauTbl, cfg);
figTauPaths = save_run_figure(figTau, 'tau_dip_vs_Tp', runDir);
close(figTau);

reportText = buildReportText(runDir, cfg, matrixData, validCurves, missingCurves, tauTbl, baseline, exclude34, excludeFragile, shiftResult, dominance, rawDiag);
reportPath = save_run_report(reportText, 'aging_fm_using_dip_clock_report.md', runDir);
zipPath = createReviewZip(runDir, 'aging_fm_using_dip_clock_outputs.zip');

appendText(runCtx.log_path, sprintf('[%s] baseline RMSE before = %.6g\n', stampNow(), baseline.before.rmse_log));
appendText(runCtx.log_path, sprintf('[%s] baseline RMSE after = %.6g\n', stampNow(), baseline.after.rmse_log));
appendText(runCtx.log_path, sprintf('[%s] metrics: %s\n', stampNow(), metricsPath));
appendText(runCtx.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(runCtx.log_path, sprintf('[%s] zip: %s\n', stampNow(), zipPath));
appendText(runCtx.notes_path, sprintf('Conclusion: %s\n', baseline.conclusion));

fprintf('Aging FM-using-Dip-clock analysis complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Metrics table: %s\n', metricsPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = string(runDir);
out.metrics_path = string(metricsPath);
out.report_path = string(reportPath);
out.zip_path = string(zipPath);
out.raw_figure = string(figRawPaths.png);
out.rescaled_figure = string(figRescaledPaths.png);
out.tau_figure = string(figTauPaths.png);
out.baseline = baseline;
out.shift = shiftResult;
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'aging_fm_using_dip_clock');
cfg = setDefault(cfg, 'datasetPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_211204_aging_dataset_build', 'tables', 'aging_observable_dataset.csv'));
cfg = setDefault(cfg, 'tauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_233710_aging_time_rescaling_collapse', 'tables', 'tau_rescaling_estimates.csv'));
cfg = setDefault(cfg, 'pairGridCount', 120);
cfg = setDefault(cfg, 'displayGridCount', 240);
cfg = setDefault(cfg, 'minPairOverlapLog10', 0.15);
cfg = setDefault(cfg, 'minPairSamples', 16);
cfg = setDefault(cfg, 'minCurvesForStats', 3);
cfg = setDefault(cfg, 'deltaTGrid', -2:0.05:2);
cfg = setDefault(cfg, 'rawFigurePosition', [2 2 16.5 11.0]);
cfg = setDefault(cfg, 'rescaledFigurePosition', [2 2 19.5 11.6]);
cfg = setDefault(cfg, 'tauFigurePosition', [2 2 14.5 10.2]);
end

function ensureStandardSubdirs(runDir)
for folderName = ["figures", "tables", "reports", "review"]
    folderPath = fullfile(runDir, char(folderName));
    if exist(folderPath, 'dir') ~= 7
        mkdir(folderPath);
    end
end
end

function dataTbl = loadObservableDataset(datasetPath)
fid = fopen(datasetPath, 'r', 'n', 'UTF-8');
assert(fid ~= -1, 'Could not open dataset: %s', datasetPath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
headerLine = fgetl(fid);
headerLine = erase(string(headerLine), char(65279));
assert(contains(headerLine, 'Tp') && contains(headerLine, 'Dip_depth') && contains(headerLine, 'FM_abs'), ...
    'Unexpected dataset header: %s', headerLine);
raw = textscan(fid, '%q%q%q%q%q', 'Delimiter', ',', 'ReturnOnError', false);
dataTbl = table(raw{1}, raw{2}, raw{3}, raw{4}, raw{5}, ...
    'VariableNames', {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'});
for vn = {'Tp', 'tw', 'Dip_depth', 'FM_abs'}
    name = vn{1};
    dataTbl.(name) = str2double(string(dataTbl.(name)));
end
dataTbl.source_run = string(dataTbl.source_run);
dataTbl = sortrows(dataTbl, {'Tp', 'tw'}, {'ascend', 'ascend'});
end

function tauTbl = loadTauTable(tauPath)
tauTbl = readtable(tauPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
tauTbl.Properties.VariableNames = standardizeVariableNames(tauTbl.Properties.VariableNames);
required = {'Tp', 'tau_estimate_seconds'};
missing = required(~ismember(required, tauTbl.Properties.VariableNames));
if ~isempty(missing) && width(tauTbl) >= 2
    fallbackNames = tauTbl.Properties.VariableNames;
    fallbackNames{1} = 'Tp';
    if width(tauTbl) >= 7
        fallbackNames{7} = 'tau_estimate_seconds';
    else
        fallbackNames{2} = 'tau_estimate_seconds';
    end
    if width(tauTbl) >= 2
        fallbackNames{2} = 'n_points';
    end
    tauTbl.Properties.VariableNames = fallbackNames;
    missing = required(~ismember(required, tauTbl.Properties.VariableNames));
end
assert(isempty(missing), 'Tau table missing columns: %s', strjoin(missing, ', '));
for vn = {'Tp', 'tau_estimate_seconds', 'n_points'}
    name = vn{1};
    if ismember(name, tauTbl.Properties.VariableNames) && ~isnumeric(tauTbl.(name))
        tauTbl.(name) = str2double(erase(string(tauTbl.(name)), '"'));
    end
end
if ~ismember('n_points', tauTbl.Properties.VariableNames)
    tauTbl.n_points = NaN(height(tauTbl), 1);
end
tauTbl = sortrows(tauTbl(isfinite(tauTbl.Tp), :), 'Tp');
end

function namesOut = standardizeVariableNames(namesIn)
namesIn = string(namesIn);
namesOut = strings(size(namesIn));
for i = 1:numel(namesIn)
    name = erase(namesIn(i), '"');
    name = regexprep(name, '^x_', '');
    name = regexprep(name, '_+$', '');
    switch lower(name)
        case 'tp'
            namesOut(i) = "Tp";
        case 'tw'
            namesOut(i) = "tw";
        case {'dip_depth', 'dipdepth'}
            namesOut(i) = "Dip_depth";
        case {'fm_abs', 'fmabs'}
            namesOut(i) = "FM_abs";
        case {'source_run', 'sourcerun'}
            namesOut(i) = "source_run";
        case {'tau_estimate_seconds', 'tauestimate_seconds'}
            namesOut(i) = "tau_estimate_seconds";
        case {'n_points', 'npoints'}
            namesOut(i) = "n_points";
        otherwise
            namesOut(i) = string(matlab.lang.makeValidName(char(name)));
    end
end
namesOut = cellstr(namesOut);
end

function matrixData = buildObservableMatrices(dataTbl)
tpValues = unique(dataTbl.Tp(isfinite(dataTbl.Tp)), 'sorted');
twValues = unique(dataTbl.tw(isfinite(dataTbl.tw) & dataTbl.tw > 0), 'sorted');
dipMatrix = nan(numel(tpValues), numel(twValues));
fmMatrix = nan(numel(tpValues), numel(twValues));
for i = 1:height(dataTbl)
    tpIdx = find(abs(tpValues - dataTbl.Tp(i)) < 1e-9, 1, 'first');
    twIdx = find(abs(twValues - dataTbl.tw(i)) < 1e-9, 1, 'first');
    if isempty(tpIdx) || isempty(twIdx)
        continue;
    end
    dipMatrix(tpIdx, twIdx) = dataTbl.Dip_depth(i);
    fmMatrix(tpIdx, twIdx) = dataTbl.FM_abs(i);
end
matrixData = struct();
matrixData.tp_values = tpValues(:);
matrixData.tw_values = twValues(:).';
matrixData.dip_matrix = dipMatrix;
matrixData.fm_matrix = fmMatrix;
matrixData.missing_dip_count = nnz(~isfinite(dipMatrix));
matrixData.missing_fm_count = nnz(~isfinite(fmMatrix));
end

function tauModel = buildTauModel(tauTbl)
valid = isfinite(tauTbl.Tp) & isfinite(tauTbl.tau_estimate_seconds) & tauTbl.tau_estimate_seconds > 0;
assert(nnz(valid) >= 2, 'Need at least two finite tau values.');
tp = tauTbl.Tp(valid);
tau = tauTbl.tau_estimate_seconds(valid);
[tp, idx] = unique(tp, 'stable');
tau = tau(idx);
logTau = log10(tau);
tauModel = struct();
tauModel.tp = tp(:);
tauModel.log10_tau = logTau(:);
tauModel.evaluate = @(tpQuery) 10 .^ interp1(tp, logTau, double(tpQuery), 'pchip', 'extrap');
end

function curves = buildFmCurves(matrixData, dataTbl, tauModel)
tpValues = matrixData.tp_values(:);
twValues = matrixData.tw_values(:);
fmMatrix = matrixData.fm_matrix;
maxCount = max(sum(isfinite(fmMatrix), 2));
curves = repmat(initCurveRow(), numel(tpValues), 1);
for i = 1:numel(tpValues)
    tp = tpValues(i);
    fmRow = fmMatrix(i, :).';
    valid = isfinite(fmRow) & twValues > 0;
    curve = initCurveRow();
    curve.Tp = tp;
    curve.tw_all = twValues;
    curve.fm_all = fmRow;
    curve.tau_dip_seconds = tauModel.evaluate(tp);
    curve.source_runs = join(unique(dataTbl.source_run(abs(dataTbl.Tp - tp) < 1e-9)), '; ');
    if any(valid)
        curve.has_fm = true;
        curve.tw = twValues(valid);
        curve.fm_abs = fmRow(valid);
        curve.fm_max = max(curve.fm_abs);
        curve.fm_norm = curve.fm_abs ./ curve.fm_max;
        curve.n_points = numel(curve.tw);
        curve.is_fragile = curve.n_points < maxCount;
        [~, idxPeak] = max(curve.fm_abs);
        curve.peak_tw_seconds = curve.tw(idxPeak);
    end
    curves(i) = curve;
end
end

function curve = initCurveRow()
curve = struct('Tp', NaN, 'has_fm', false, 'tw_all', NaN(0,1), 'fm_all', NaN(0,1), ...
    'tw', NaN(0,1), 'fm_abs', NaN(0,1), 'fm_norm', NaN(0,1), 'fm_max', NaN, ...
    'tau_dip_seconds', NaN, 'n_points', 0, 'is_fragile', false, 'peak_tw_seconds', NaN, 'source_runs', "");
end

function scenario = evaluateScenario(curves, tauModel, cfg, deltaT, name, note)
scenario = struct();
scenario.name = string(name);
scenario.note = string(note);
scenario.deltaT_K = deltaT;
scenario.curves = curves(:);
scenario.included_tp = [curves.Tp].';
scenario.tau_seconds = arrayfun(@(c) tauModel.evaluate(c.Tp + deltaT), curves(:));
scenario.before = computeCollapseMetrics(curves, ones(numel(curves), 1), cfg);
scenario.after = computeCollapseMetrics(curves, scenario.tau_seconds, cfg);
scenario.rmse_improvement_pct = percentReduction(scenario.before.rmse_log, scenario.after.rmse_log);
scenario.variance_improvement_pct = percentReduction(scenario.before.mean_gridded_variance, scenario.after.mean_gridded_variance);
scenario.conclusion = classifyScenario(scenario);
end

function metrics = computeCollapseMetrics(curves, tauVector, cfg)
n = numel(curves);
pairRmse = nan(n, n);
pairOverlap = nan(n, n);
for i = 1:(n - 1)
    x1 = log10(curves(i).tw ./ tauVector(i));
    y1 = curves(i).fm_norm;
    for j = (i + 1):n
        x2 = log10(curves(j).tw ./ tauVector(j));
        y2 = curves(j).fm_norm;
        [pairRmse(i, j), pairOverlap(i, j)] = pairwiseRmse(x1, y1, x2, y2, cfg);
        pairRmse(j, i) = pairRmse(i, j);
        pairOverlap(j, i) = pairOverlap(i, j);
    end
end
upperMask = triu(true(n), 1);
validPairs = upperMask & isfinite(pairRmse);
profile = buildProfile(curves, tauVector, cfg);
metrics = struct();
metrics.rmse_log = mean(pairRmse(validPairs), 'omitnan');
metrics.mean_pair_overlap_decades = mean(pairOverlap(validPairs), 'omitnan');
metrics.n_pairs = nnz(validPairs);
metrics.pairwise_rmse = pairRmse;
metrics.profile = profile;
metrics.mean_gridded_variance = profile.mean_variance;
metrics.valid_grid_fraction = profile.valid_grid_fraction;
end

function [rmseVal, overlapVal] = pairwiseRmse(x1, y1, x2, y2, cfg)
rmseVal = NaN;
overlapVal = NaN;
if numel(x1) < 2 || numel(x2) < 2
    return;
end
overlapStart = max(min(x1), min(x2));
overlapEnd = min(max(x1), max(x2));
overlapVal = overlapEnd - overlapStart;
if ~(isfinite(overlapVal) && overlapVal >= cfg.minPairOverlapLog10)
    return;
end
xGrid = linspace(overlapStart, overlapEnd, cfg.pairGridCount);
y1i = interp1(x1, y1, xGrid, 'linear', NaN);
y2i = interp1(x2, y2, xGrid, 'linear', NaN);
valid = isfinite(y1i) & isfinite(y2i);
if nnz(valid) < cfg.minPairSamples
    return;
end
rmseVal = sqrt(mean((y1i(valid) - y2i(valid)) .^ 2, 'omitnan'));
end

function profile = buildProfile(curves, tauVector, cfg)
xMin = inf;
xMax = -inf;
for i = 1:numel(curves)
    x = log10(curves(i).tw ./ tauVector(i));
    xMin = min(xMin, min(x));
    xMax = max(xMax, max(x));
end
xGrid = linspace(xMin, xMax, cfg.displayGridCount);
Y = nan(numel(curves), numel(xGrid));
for i = 1:numel(curves)
    x = log10(curves(i).tw ./ tauVector(i));
    Y(i, :) = interp1(x, curves(i).fm_norm, xGrid, 'linear', NaN);
end
curveCount = sum(isfinite(Y), 1);
varCurve = nan(1, numel(xGrid));
meanCurve = nan(1, numel(xGrid));
stdCurve = nan(1, numel(xGrid));
for k = 1:numel(xGrid)
    col = Y(:, k);
    col = col(isfinite(col));
    if isempty(col)
        continue;
    end
    meanCurve(k) = mean(col);
    if numel(col) >= 2
        stdCurve(k) = std(col, 0);
        varCurve(k) = var(col, 0);
    end
end
validMask = curveCount >= cfg.minCurvesForStats & isfinite(varCurve);
profile = struct();
profile.x_grid = xGrid;
profile.z_grid = 10 .^ xGrid;
profile.mean_curve = meanCurve;
profile.std_curve = stdCurve;
profile.valid_stat_mask = validMask;
profile.mean_variance = mean(varCurve(validMask), 'omitnan');
profile.valid_grid_fraction = nnz(validMask) / numel(validMask);
end
function txt = classifyScenario(scenario)
if scenario.rmse_improvement_pct >= 35 && scenario.variance_improvement_pct >= 35 && ...
        isfinite(scenario.after.mean_gridded_variance) && scenario.after.mean_gridded_variance <= 0.03
    txt = "FM_abs is broadly consistent with sharing the Dip-derived temperature clock, although not the same scaling function.";
elseif scenario.rmse_improvement_pct >= 15 && scenario.variance_improvement_pct >= 15
    txt = "FM_abs shows partial support for the Dip-derived clock, but the collapse remains imperfect.";
else
    txt = "FM_abs does not show a robust collapse under the Dip-derived clock.";
end
end

function shiftResult = fitBestShift(curves, tauModel, cfg, baseline)
deltaGrid = cfg.deltaTGrid(:);
rmseAfter = nan(numel(deltaGrid), 1);
varianceAfter = nan(numel(deltaGrid), 1);
for i = 1:numel(deltaGrid)
    tempScenario = evaluateScenario(curves, tauModel, cfg, deltaGrid(i), 'shift_scan', 'Temporary shift scan');
    rmseAfter(i) = tempScenario.after.rmse_log;
    varianceAfter(i) = tempScenario.after.mean_gridded_variance;
end
valid = find(isfinite(rmseAfter));
[bestRmse, localIdx] = min(rmseAfter(valid));
candidates = valid(abs(rmseAfter(valid) - bestRmse) <= 1e-12);
if numel(candidates) > 1
    [~, bestLocal] = min(abs(deltaGrid(candidates)));
    bestIdx = candidates(bestLocal);
else
    bestIdx = candidates(1);
end
shiftResult = evaluateScenario(curves, tauModel, cfg, deltaGrid(bestIdx), 'best_deltaT_shift', 'Best small T_p shift in tau_Dip(T_p + DeltaT)');
shiftResult.shift_grid = deltaGrid;
shiftResult.rmse_after_grid = rmseAfter;
shiftResult.variance_after_grid = varianceAfter;
shiftResult.additional_improvement_pct = percentReduction(baseline.after.rmse_log, shiftResult.after.rmse_log);
end

function dominance = analyzeDominance(curves, tauModel, cfg, baseline)
rmseDeltaPct = nan(numel(curves), 1);
for i = 1:numel(curves)
    keepMask = true(numel(curves), 1);
    keepMask(i) = false;
    loo = evaluateScenario(curves(keepMask), tauModel, cfg, 0, 'leave_one_out', 'Leave-one-out diagnostic');
    rmseDeltaPct(i) = 100 * (loo.after.rmse_log - baseline.after.rmse_log) / max(baseline.after.rmse_log, eps);
end
meanPairRmse = nan(numel(curves), 1);
for i = 1:numel(curves)
    row = baseline.after.pairwise_rmse(i, :);
    row = row(isfinite(row));
    if ~isempty(row)
        meanPairRmse(i) = mean(row);
    end
end
[~, maxImpactIdx] = max(abs(rmseDeltaPct));
[~, outlierIdx] = max(meanPairRmse);
dominance = struct();
dominance.max_impact_tp = curves(maxImpactIdx).Tp;
dominance.max_impact_rmse_delta_pct = rmseDeltaPct(maxImpactIdx);
dominance.outlier_tp = curves(outlierIdx).Tp;
dominance.outlier_pair_rmse = meanPairRmse(outlierIdx);
dominance.no_single_tp_dominates = max(abs(rmseDeltaPct)) < 20;
end

function rawDiag = buildRawDiagnostics(curves, baseline)
peaks = [curves.peak_tw_seconds].';
fmMax = [curves.fm_max].';
rawDiag = struct();
rawDiag.peak_tw_min = min(peaks, [], 'omitnan');
rawDiag.peak_tw_max = max(peaks, [], 'omitnan');
rawDiag.fm_amplitude_span_factor = max(fmMax, [], 'omitnan') / max(min(fmMax, [], 'omitnan'), eps);
rawDiag.normalization_only_rmse_log = baseline.before.rmse_log;
rawDiag.normalization_only_variance = baseline.before.mean_gridded_variance;
end

function tbl = buildMetricsTable(baseline, exclude34, excludeFragile, shiftResult, rawDiag, dominance)
rows = [
    scenarioRow(baseline, rawDiag, dominance);
    scenarioRow(exclude34, rawDiag, dominance);
    scenarioRow(excludeFragile, rawDiag, dominance);
    scenarioRow(shiftResult, rawDiag, dominance)
    ];
tbl = struct2table(rows);
end

function row = scenarioRow(scenario, rawDiag, dominance)
row = struct();
row.scenario = scenario.name;
row.note = scenario.note;
row.included_tp = join(string(scenario.included_tp.'), ';');
row.deltaT_K = scenario.deltaT_K;
row.rmse_log_before = scenario.before.rmse_log;
row.rmse_log_after = scenario.after.rmse_log;
row.rmse_improvement_pct = scenario.rmse_improvement_pct;
row.variance_before = scenario.before.mean_gridded_variance;
row.variance_after = scenario.after.mean_gridded_variance;
row.variance_improvement_pct = scenario.variance_improvement_pct;
row.mean_pair_overlap_before = scenario.before.mean_pair_overlap_decades;
row.mean_pair_overlap_after = scenario.after.mean_pair_overlap_decades;
row.valid_pairs_before = scenario.before.n_pairs;
row.valid_pairs_after = scenario.after.n_pairs;
row.valid_grid_fraction_before = scenario.before.valid_grid_fraction;
row.valid_grid_fraction_after = scenario.after.valid_grid_fraction;
row.fm_amplitude_span_factor = rawDiag.fm_amplitude_span_factor;
row.dominant_tp = dominance.outlier_tp;
row.max_leave_one_out_rmse_delta_pct = dominance.max_impact_rmse_delta_pct;
end

function fig = makeRawFigure(validCurves, missingCurves, rawDiag, cfg)
fig = create_figure('Visible', 'off', 'Position', cfg.rawFigurePosition);
ax = axes(fig);
hold(ax, 'on');
colors = lines(numel(validCurves));
allTw = unique(collectAllTw(validCurves));
for i = 1:numel(validCurves)
    marker = 'o';
    lineStyle = '-';
    if validCurves(i).is_fragile
        marker = 's';
        lineStyle = '--';
    end
    plot(ax, validCurves(i).tw, validCurves(i).fm_abs, [lineStyle marker], ...
        'Color', colors(i, :), 'MarkerFaceColor', colors(i, :), 'MarkerSize', 6.5, 'LineWidth', 2.2, ...
        'DisplayName', sprintf('T_p = %.0f K', validCurves(i).Tp));
end
set(ax, 'XScale', 'log');
xticks(ax, allTw);
grid(ax, 'on');
xlabel(ax, 't_w (s)');
ylabel(ax, 'FM_{abs}');
title(ax, 'Raw FM_{abs}(T_p, t_w)');
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
legend(ax, 'Location', 'eastoutside', 'FontSize', 11, 'Box', 'off');
missingText = '';
if ~isempty(missingCurves)
    missingText = sprintf('FM_abs unavailable at T_p = %s K.', join(string([missingCurves.Tp]), ', '));
end
annotation(fig, 'textbox', [0.12 0.02 0.72 0.11], 'String', sprintf(['Peak t_w spans %.0f to %.0f s.\n', ...
    'FM maxima span %.2fx across finite-FM temperatures.\n%s'], rawDiag.peak_tw_min, rawDiag.peak_tw_max, rawDiag.fm_amplitude_span_factor, missingText), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 10.5);
end

function fig = makeRescaledFigure(curves, baseline, cfg)
fig = create_figure('Visible', 'off', 'Position', cfg.rescaledFigurePosition);
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
colors = lines(numel(curves));
allTw = unique(collectAllTw(curves));

ax1 = nexttile(tlo, 1);
hold(ax1, 'on');
for i = 1:numel(curves)
    marker = ternary(curves(i).is_fragile, 's', 'o');
    lineStyle = ternary(curves(i).is_fragile, '--', '-');
    plot(ax1, curves(i).tw, curves(i).fm_norm, [lineStyle marker], 'Color', colors(i, :), ...
        'MarkerFaceColor', colors(i, :), 'MarkerSize', 6, 'LineWidth', 2.1, ...
        'DisplayName', sprintf('T_p = %.0f K', curves(i).Tp));
end
set(ax1, 'XScale', 'log', 'YLim', [0 1.08]);
xticks(ax1, allTw);
grid(ax1, 'on');
xlabel(ax1, 't_w (s)');
ylabel(ax1, 'FM_{abs} / max_{t_w} FM_{abs}');
title(ax1, 'Normalization only');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
text(ax1, 0.04, 0.96, metricText(baseline.before), 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', 'FontSize', 10.5, 'BackgroundColor', 'w', 'Margin', 5);

ax2 = nexttile(tlo, 2);
hold(ax2, 'on');
drawBand(ax2, baseline.after.profile);
for i = 1:numel(curves)
    marker = ternary(curves(i).is_fragile, 's', 'o');
    lineStyle = ternary(curves(i).is_fragile, '--', '-');
    plot(ax2, curves(i).tw ./ baseline.tau_seconds(i), curves(i).fm_norm, [lineStyle marker], 'Color', colors(i, :), ...
        'MarkerFaceColor', colors(i, :), 'MarkerSize', 6, 'LineWidth', 2.1, ...
        'DisplayName', sprintf('T_p = %.0f K', curves(i).Tp));
end
set(ax2, 'XScale', 'log', 'YLim', [0 1.08]);
grid(ax2, 'on');
xlabel(ax2, 't_w / \tau_{Dip}(T_p)');
ylabel(ax2, 'FM_{abs} / max_{t_w} FM_{abs}');
title(ax2, 'After applying Dip clock');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
legend(ax2, 'Location', 'eastoutside', 'FontSize', 11, 'Box', 'off');
text(ax2, 0.04, 0.96, metricText(baseline.after), 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', 'FontSize', 10.5, 'BackgroundColor', 'w', 'Margin', 5);

title(tlo, sprintf('Transferred Dip clock for FM: RMSE improvement %.1f%%, variance improvement %.1f%%', ...
    baseline.rmse_improvement_pct, baseline.variance_improvement_pct));
end

function fig = makeTauFigure(tauTbl, cfg)
fig = create_figure('Visible', 'off', 'Position', cfg.tauFigurePosition);
ax = axes(fig);
hold(ax, 'on');
valid = isfinite(tauTbl.Tp) & isfinite(tauTbl.tau_estimate_seconds) & tauTbl.tau_estimate_seconds > 0;
tp = tauTbl.Tp(valid);
logTau = log10(tauTbl.tau_estimate_seconds(valid));
fragile = tauTbl.n_points(valid) < max(tauTbl.n_points(valid), [], 'omitnan');
plot(ax, tp, logTau, '-', 'Color', [0.20 0.20 0.20], 'LineWidth', 2.2, 'DisplayName', 'log_{10} \tau_{Dip}');
scatter(ax, tp(~fragile), logTau(~fragile), 80, [0.10 0.45 0.82], 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', '4-point temperatures');
if any(fragile)
    scatter(ax, tp(fragile), logTau(fragile), 90, 'o', 'MarkerEdgeColor', [0.85 0.33 0.10], 'LineWidth', 1.6, 'DisplayName', 'Fragile 3-point temperatures');
end
grid(ax, 'on');
xlabel(ax, 'T_p (K)');
ylabel(ax, 'log_{10} \tau_{Dip} (s)');
title(ax, 'Reused Dip-derived timescale structure');
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
legend(ax, 'Location', 'best', 'FontSize', 11, 'Box', 'off');
annotation(fig, 'textbox', [0.14 0.02 0.72 0.10], 'String', 'Broad mid-temperature maximum/plateau with fragile 30-34 K endpoints; no simple monotonic low-T divergence is visible.', 'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 10.5);
end
function reportText = buildReportText(runDir, cfg, matrixData, validCurves, missingCurves, tauTbl, baseline, exclude34, excludeFragile, shiftResult, dominance, rawDiag)
lines = strings(0, 1);
lines(end + 1) = "# Aging FM collapse using the Dip clock";
lines(end + 1) = "";
lines(end + 1) = sprintf('Generated: %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf('Run root: `%s`', runDir);
lines(end + 1) = "";
lines(end + 1) = "## Repository scan summary";
lines(end + 1) = "- I scanned prior Aging runs for collapse, timescale, tau, and component-clock analyses before running this test.";
lines(end + 1) = "- `run_2026_03_11_082451_aging_shape_collapse_analysis`: structured-profile shape audit; not a transferred-clock FM test.";
lines(end + 1) = "- `run_2026_03_12_223709_aging_timescale_extraction`: direct Dip-depth timescale extraction by several fit/interpolation methods.";
lines(end + 1) = "- `run_2026_03_12_223712_aging_log_time_scaling_test`: Dip-depth versus log(t_w); useful phenomenology, but not a shared-clock transfer test.";
lines(end + 1) = "- `run_2026_03_12_225842_aging_component_clock_test`: direct Dip-versus-FM comparison; concluded the two components do not share one universal normalized curve.";
lines(end + 1) = "- `run_2026_03_12_233710_aging_time_rescaling_collapse`: strong Dip-depth collapse under t_w / tau_Dip(T_p); reused here via `tau_rescaling_estimates.csv`.";
lines(end + 1) = "- This run is logically different because it does not refit FM-specific taus: it transfers tau_Dip(T_p) from the Dip collapse run to FM_abs(T_p, t_w).";
lines(end + 1) = "";
lines(end + 1) = "## Reused prior outputs";
lines(end + 1) = sprintf('- Observable dataset: `%s`', cfg.datasetPath);
lines(end + 1) = sprintf('- Dip timescale table: `%s`', cfg.tauPath);
lines(end + 1) = "";
lines(end + 1) = "## Data matrices";
lines(end + 1) = sprintf('- `Dip_depth(T_p, t_w)` matrix size: `%d x %d` with %d missing entries.', size(matrixData.dip_matrix, 1), size(matrixData.dip_matrix, 2), matrixData.missing_dip_count);
lines(end + 1) = sprintf('- `FM_abs(T_p, t_w)` matrix size: `%d x %d` with %d missing entries.', size(matrixData.fm_matrix, 1), size(matrixData.fm_matrix, 2), matrixData.missing_fm_count);
lines(end + 1) = sprintf('- Matrix rows (`T_p`): `%s` K.', join(string(matrixData.tp_values.'), ', '));
lines(end + 1) = sprintf('- Matrix columns (`t_w`): `%s` s.', join(string(matrixData.tw_values), ', '));
lines(end + 1) = sprintf('- Finite-FM temperatures used in the collapse test: `%s` K.', join(string([validCurves.Tp]), ', '));
if ~isempty(missingCurves)
    lines(end + 1) = sprintf('- `FM_abs` is missing for `%s` K, so the low-T end cannot test the transferred clock directly.', join(string([missingCurves.Tp]), ', '));
end
lines(end + 1) = "";
lines(end + 1) = "## Collapse metrics";
lines(end + 1) = sprintf('- `RMSE_log_before = %.4f`, `RMSE_log_after = %.4f`, improvement `%.2f%%`.', baseline.before.rmse_log, baseline.after.rmse_log, baseline.rmse_improvement_pct);
lines(end + 1) = sprintf('- Mean gridded variance changed from `%.5f` to `%.5f`, improvement `%.2f%%`.', baseline.before.mean_gridded_variance, baseline.after.mean_gridded_variance, baseline.variance_improvement_pct);
lines(end + 1) = sprintf('- Mean pair overlap changed from `%.2f` to `%.2f` decades.', baseline.before.mean_pair_overlap_decades, baseline.after.mean_pair_overlap_decades);
lines(end + 1) = sprintf('- Baseline conclusion: %s', baseline.conclusion);
lines(end + 1) = "";
lines(end + 1) = "## Robustness checks";
lines(end + 1) = sprintf('- Raw FM curves are heterogeneous: peak waiting times span `%.0f` to `%.0f s`, and FM maxima span `%.2fx` across temperatures.', rawDiag.peak_tw_min, rawDiag.peak_tw_max, rawDiag.fm_amplitude_span_factor);
lines(end + 1) = sprintf('- Amplitude normalization alone is not sufficient: before any time rescaling, the normalized curves still have `RMSE_log = %.4f` and variance `%.5f`.', rawDiag.normalization_only_rmse_log, rawDiag.normalization_only_variance);
if dominance.no_single_tp_dominates
    lines(end + 1) = sprintf('- No single temperature dominates the result: the largest leave-one-out RMSE change is `%.2f%%` at `T_p = %.0f K`.', dominance.max_impact_rmse_delta_pct, dominance.max_impact_tp);
else
    lines(end + 1) = sprintf('- One temperature matters noticeably: removing `T_p = %.0f K` changes the post-rescaling RMSE by `%.2f%%`.', dominance.max_impact_tp, dominance.max_impact_rmse_delta_pct);
end
lines(end + 1) = sprintf('- The largest mean post-rescaling pairwise residual is attached to `T_p = %.0f K`.', dominance.outlier_tp);
lines(end + 1) = sprintf('- Excluding `34 K` gives `RMSE_log_after = %.4f` and variance `%.5f`.', exclude34.after.rmse_log, exclude34.after.mean_gridded_variance);
lines(end + 1) = sprintf('- Excluding the fragile `30 K` and `34 K` curves gives `RMSE_log_after = %.4f` and variance `%.5f`.', excludeFragile.after.rmse_log, excludeFragile.after.mean_gridded_variance);
lines(end + 1) = "";
lines(end + 1) = "## Tau structure";
lines(end + 1) = tauInterpretation(tauTbl);
lines(end + 1) = "- The reused tau values are gauge-fixed collapse times, so only their temperature dependence should be interpreted physically.";
lines(end + 1) = "";
lines(end + 1) = "## Optional shift test";
lines(end + 1) = sprintf('- Best small shift: `DeltaT = %.2f K`.', shiftResult.deltaT_K);
lines(end + 1) = sprintf('- Shifted-clock `RMSE_log_after = %.4f`, additional improvement over zero-shift `%.2f%%`.', shiftResult.after.rmse_log, shiftResult.additional_improvement_pct);
lines(end + 1) = sprintf('- Shifted-clock variance after rescaling = `%.5f`.', shiftResult.after.mean_gridded_variance);
if abs(shiftResult.deltaT_K) <= 0.25 || shiftResult.additional_improvement_pct < 5
    lines(end + 1) = "- The shift test changes the result only weakly, so the zero-shift Dip clock already captures most of the transferable timescale information.";
else
    lines(end + 1) = "- The shift test gives a modest improvement, so a small temperature offset may sharpen the FM transfer but is secondary to the zero-shift result.";
end
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- `fm_raw_vs_tw`: 6 curves, explicit legend, no colormap, no smoothing, used to expose amplitude and peak-time heterogeneity.";
lines(end + 1) = "- `fm_rescaled_vs_tw_over_tau_dip`: necessary 2-panel before/after comparison, explicit legend, no colormap, no smoothing, with a mean +/- 1 sigma band on the rescaled panel.";
lines(end + 1) = "- `tau_dip_vs_Tp`: single line plus fragile-point markers, no colormap, no smoothing, used to isolate tau_Dip(T_p) structure.";
lines(end + 1) = "";
lines(end + 1) = "## Conclusion";
lines(end + 1) = sprintf('- %s', baseline.conclusion);
if baseline.rmse_improvement_pct > 0
    lines(end + 1) = "- The transferred Dip timescale improves FM collapse relative to normalization alone, so the direct Dip-vs-FM mismatch does not by itself rule out a partially shared temperature-dependent clock.";
else
    lines(end + 1) = "- The transferred Dip timescale does not improve FM collapse, so the direct Dip-vs-FM mismatch remains the stronger conclusion.";
end
if exclude34.rmse_improvement_pct > baseline.rmse_improvement_pct
    lines(end + 1) = "- The shared-clock interpretation becomes cleaner once the fragile 34 K outlier is removed, so the evidence is strongest below 34 K.";
else
    lines(end + 1) = "- Removing 34 K does not qualitatively change the verdict, so the baseline conclusion is not driven by that single temperature.";
end
lines(end + 1) = "";
lines(end + 1) = "## Outputs";
lines(end + 1) = "- `tables/fm_collapse_using_dip_tau_metrics.csv`";
lines(end + 1) = "- `figures/fm_raw_vs_tw.png`";
lines(end + 1) = "- `figures/fm_rescaled_vs_tw_over_tau_dip.png`";
lines(end + 1) = "- `figures/tau_dip_vs_Tp.png`";
lines(end + 1) = "- `reports/aging_fm_using_dip_clock_report.md`";
lines(end + 1) = "- `review/aging_fm_using_dip_clock_outputs.zip`";
reportText = strjoin(lines, newline);
end

function txt = tauInterpretation(tauTbl)
valid = isfinite(tauTbl.Tp) & isfinite(tauTbl.tau_estimate_seconds) & tauTbl.tau_estimate_seconds > 0;
tp = tauTbl.Tp(valid);
tau = tauTbl.tau_estimate_seconds(valid);
[peakTau, peakIdx] = max(tau);
[minTau, minIdx] = min(tau);
txt = sprintf(['- `tau_Dip(T_p)` shows a broad maximum/plateau near `T_p = %.0f K` (`tau ~ %.3g s`) and a minimum near `T_p = %.0f K` (`tau ~ %.3g s`). ', ...
    'That shape is not consistent with simple monotonic barrier activation or a clean critical divergence across this window; it is more consistent with a crossover-limited effective clock peaking in the mid-temperature regime.'], ...
    tp(peakIdx), peakTau, tp(minIdx), minTau);
end

function txt = metricText(metrics)
txt = sprintf('RMSE_{log} = %.3f\nMean variance = %.4f\nOverlap = %.2f decades\nValid pairs = %d', ...
    metrics.rmse_log, metrics.mean_gridded_variance, metrics.mean_pair_overlap_decades, metrics.n_pairs);
end

function drawBand(ax, profile)
valid = profile.valid_stat_mask & isfinite(profile.mean_curve) & isfinite(profile.std_curve);
if nnz(valid) < 2
    return;
end
x = profile.z_grid(valid);
yMean = profile.mean_curve(valid);
yStd = profile.std_curve(valid);
fill(ax, [x, fliplr(x)], [yMean - yStd, fliplr(yMean + yStd)], [0.85 0.85 0.85], 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, yMean, '-', 'Color', [0.10 0.10 0.10], 'LineWidth', 2.3, 'DisplayName', 'Mean +/- 1 sigma');
end

function tw = collectAllTw(curves)
tw = [];
for i = 1:numel(curves)
    tw = [tw; curves(i).tw(:)]; %#ok<AGROW>
end
tw = tw(isfinite(tw));
end

function zipPath = createReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
inputs = collectRelativeFiles(runDir);
zip(zipPath, cellstr(inputs), runDir);
end

function files = collectRelativeFiles(runDir)
files = strings(0, 1);
for folderName = {'tables', 'figures', 'reports'}
    folderPath = fullfile(runDir, folderName{1});
    if exist(folderPath, 'dir') ~= 7
        continue;
    end
    files = [files; collectRelativeFilesRecursive(folderPath, runDir)]; %#ok<AGROW>
end
end

function files = collectRelativeFilesRecursive(targetDir, runDir)
entries = dir(targetDir);
files = strings(0, 1);
for i = 1:numel(entries)
    name = string(entries(i).name);
    if name == "." || name == ".."
        continue;
    end
    fullPath = fullfile(entries(i).folder, char(name));
    if entries(i).isdir
        files = [files; collectRelativeFilesRecursive(fullPath, runDir)]; %#ok<AGROW>
    else
        files(end + 1, 1) = string(relativePath(fullPath, runDir)); %#ok<AGROW>
    end
end
end

function rel = relativePath(fullPath, runDir)
if strncmpi(fullPath, runDir, numel(runDir))
    rel = fullPath(numel(runDir) + 2:end);
else
    rel = fullPath;
end
end

function pct = percentReduction(beforeVal, afterVal)
if ~(isfinite(beforeVal) && isfinite(afterVal))
    pct = NaN;
    return;
end
pct = 100 * (1 - afterVal / max(beforeVal, eps));
end

function appendText(pathStr, textStr)
fid = fopen(pathStr, 'a');
if fid < 0
    error('Could not open %s for append.', pathStr);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textStr);
end

function out = ternary(condition, a, b)
if condition
    out = a;
else
    out = b;
end
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end




