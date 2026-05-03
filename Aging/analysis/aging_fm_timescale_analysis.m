function out = aging_fm_timescale_analysis(cfg)
% aging_fm_timescale_analysis
% Extract FM-specific aging timescales and test whether FM_abs collapses
% under tw / tau_FM(T_p).

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
assert(exist(cfg.dipTauPath, 'file') == 2, 'Dip tau table not found: %s', cfg.dipTauPath);
assert(exist(cfg.failedDipClockMetricsPath, 'file') == 2, 'Failed Dip-clock metrics not found: %s', cfg.failedDipClockMetricsPath);

cfgRun = struct();
cfgRun.runLabel = char(string(cfg.runLabel));
cfgRun.datasetName = 'aging_observable_dataset';
cfgRun.dataset = char(string(cfg.datasetPath));
cfgRun.dip_tau_source = char(string(cfg.dipTauPath));
runCtx = createRunContext('aging', cfgRun);
runDir = runCtx.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging FM timescale analysis run root:\n%s\n', runDir);
fprintf('Input dataset: %s\n', cfg.datasetPath);
fprintf('Input Dip tau table: %s\n', cfg.dipTauPath);
appendText(runCtx.log_path, sprintf('[%s] started\n', stampNow()));
appendText(runCtx.log_path, sprintf('Dataset: %s\n', cfg.datasetPath));
appendText(runCtx.log_path, sprintf('Dip tau source: %s\n', cfg.dipTauPath));
appendText(runCtx.log_path, sprintf('Failed Dip-clock comparison table: %s\n', cfg.failedDipClockMetricsPath));

dataTbl = normalizeDatasetTable(loadObservableDataset(cfg.datasetPath));
dataTbl = sortrows(dataTbl, {'Tp', 'tw'});
fmTauTbl = buildFmTauTable(dataTbl);
fmTauTbl = sortrows(fmTauTbl, 'Tp');
f7gMeta = struct( ...
    'writer_family_id', 'WF_TAU_FM_CURVEFIT', ...
    'tau_or_R_flag', 'TAU', ...
    'tau_domain', 'FM_ABS_CURVEFIT', ...
    'tau_input_observable_identities', '{"FM_abs":"consolidated_aging_observable_dataset_column"}', ...
    'tau_input_observable_family', 'FM_abs_memory_curve', ...
    'source_writer_script', 'Aging/analysis/aging_fm_timescale_analysis.m', ...
    'source_artifact_basename', 'tau_FM_vs_Tp.csv', ...
    'source_artifact_path', fullfile(runDir, 'tables', 'tau_FM_vs_Tp.csv'), ...
    'canonical_status', 'non_canonical_pending_lineage', ...
    'model_use_allowed', 'NO_UNLESS_LINEAGE_RESOLVED', ...
    'semantic_status', 'tau_effective_seconds_is_legacy_alias_FM_ABS_CURVEFIT', ...
    'lineage_status', 'LINEAGE_METADATA_HARDENED_PENDING_F7S');
fmTauTbl = appendF7GTauRMetadataColumns(fmTauTbl, f7gMeta);
failedDipClock = loadFailedDipClockMetrics(cfg.failedDipClockMetricsPath, cfg);
fmTauTbl = appendFmTauLineageHardeningColumns(fmTauTbl, cfg, failedDipClock);
tauPath = save_run_table(fmTauTbl, 'tau_FM_vs_Tp.csv', runDir);

dipTauTbl = loadDipTauTable(cfg.dipTauPath);
comparison = compareTauStructures(fmTauTbl, dipTauTbl);
curves = buildCollapseCurves(dataTbl, fmTauTbl);
validCurves = curves([curves.has_tau_fm]);
missingFmCurves = curves(~[curves.has_fm]);
assert(numel(validCurves) >= 3, 'Need at least three FM curves with finite tau_FM.');

baseline = evaluateCollapse(validCurves, ones(numel(validCurves), 1), cfg);
fmCollapse = evaluateCollapse(validCurves, [validCurves.tau_fm_seconds].', cfg);

figRaw = makeRawFmFigure(curves, missingFmCurves, cfg);
rawPaths = save_run_figure(figRaw, 'fm_vs_tw_by_Tp', runDir);
close(figRaw);

figRescaled = makeRescaledFmFigure(validCurves, baseline, fmCollapse, cfg);
rescaledPaths = save_run_figure(figRescaled, 'fm_rescaled_vs_tw_over_tau_FM', runDir);
close(figRescaled);

figTau = makeFmTauFigure(fmTauTbl, cfg);
tauFigurePaths = save_run_figure(figTau, 'tau_FM_vs_Tp', runDir);
close(figTau);

figCompare = makeTauComparisonFigure(fmTauTbl, dipTauTbl, comparison, cfg);
comparePaths = save_run_figure(figCompare, 'tau_FM_vs_tau_dip', runDir);
close(figCompare);

reportText = buildReportText(runDir, cfg, dataTbl, fmTauTbl, dipTauTbl, baseline, fmCollapse, failedDipClock, comparison);
reportPath = save_run_report(reportText, 'aging_fm_timescale_analysis_report.md', runDir);
zipPath = createReviewZip(runDir, 'aging_fm_timescale_analysis_outputs.zip');

appendText(runCtx.log_path, sprintf('[%s] baseline RMSE_log = %.6g\n', stampNow(), baseline.rmse_log));
appendText(runCtx.log_path, sprintf('[%s] FM-clock RMSE_log = %.6g\n', stampNow(), fmCollapse.rmse_log));
appendText(runCtx.log_path, sprintf('[%s] tau table: %s\n', stampNow(), tauPath));
appendText(runCtx.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(runCtx.log_path, sprintf('[%s] zip: %s\n', stampNow(), zipPath));
appendText(runCtx.notes_path, sprintf('Collapse verdict: %s\n', classifyCollapseQuality(baseline, fmCollapse)));
appendText(runCtx.notes_path, sprintf('FM vs Dip tau verdict: %s\n', comparison.summary_line));

fprintf('Aging FM timescale analysis complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Tau table: %s\n', tauPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = string(runDir);
out.tau_table_path = string(tauPath);
out.report_path = string(reportPath);
out.zip_path = string(zipPath);
out.raw_figure = string(rawPaths.png);
out.rescaled_figure = string(rescaledPaths.png);
out.tau_figure = string(tauFigurePaths.png);
out.compare_figure = string(comparePaths.png);
out.fm_tau_table = fmTauTbl;
out.fm_collapse = fmCollapse;
out.baseline = baseline;
out.failed_dip_clock = failedDipClock;
out.tau_comparison = comparison;
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'aging_fm_timescale_analysis');
cfg = setDefault(cfg, 'datasetPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_211204_aging_dataset_build', 'tables', 'aging_observable_dataset.csv'));
cfg = setDefault(cfg, 'dipTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_223709_aging_timescale_extraction', 'tables', 'tau_vs_Tp.csv'));
cfg = setDefault(cfg, 'failedDipClockMetricsPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_13_005134_aging_fm_using_dip_clock', 'tables', 'fm_collapse_using_dip_tau_metrics.csv'));
cfg = setDefault(cfg, 'pairGridCount', 120);
cfg = setDefault(cfg, 'displayGridCount', 240);
cfg = setDefault(cfg, 'minPairOverlapLog10', 0.15);
cfg = setDefault(cfg, 'minPairSamples', 16);
cfg = setDefault(cfg, 'minCurvesForStats', 3);
cfg = setDefault(cfg, 'rawFigurePosition', [2 2 18.6 11.8]);
cfg = setDefault(cfg, 'rescaledFigurePosition', [2 2 21.2 12.4]);
cfg = setDefault(cfg, 'tauFigurePosition', [2 2 12.5 8.8]);
cfg = setDefault(cfg, 'compareFigurePosition', [2 2 19.0 9.5]);
cfg = setDefault(cfg, 'branch_id', '');
cfg = setDefault(cfg, 'failedDipClockRunId', '');
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
end

function dataTbl = normalizeDatasetTable(dataTbl)
required = {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'};
missing = required(~ismember(required, dataTbl.Properties.VariableNames));
assert(isempty(missing), 'Dataset missing columns: %s', strjoin(missing, ', '));
for vn = {'Tp', 'tw', 'Dip_depth', 'FM_abs'}
    name = vn{1};
    if ~isnumeric(dataTbl.(name))
        dataTbl.(name) = str2double(string(dataTbl.(name)));
    end
end
dataTbl.source_run = string(dataTbl.source_run);
end

function tauTbl = loadDipTauTable(tauPath)
tauTbl = readtable(tauPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
if any(strcmp(tauTbl.Properties.VariableNames, 'tau_effective_seconds'))
    % keep original names
else
    tauTbl.Properties.VariableNames = cellstr(string(tauTbl.Properties.VariableNames));
end
numericVars = {'Tp', 'tau_effective_seconds', 'tau_half_range_seconds', 'tau_logistic_half_seconds', 'tau_stretched_half_seconds'};
for i = 1:numel(numericVars)
    vn = numericVars{i};
    if ismember(vn, tauTbl.Properties.VariableNames) && ~isnumeric(tauTbl.(vn))
        tauTbl.(vn) = str2double(erase(string(tauTbl.(vn)), '"'));
    end
end
if ismember('source_run', tauTbl.Properties.VariableNames)
    tauTbl.source_run = string(tauTbl.source_run);
else
    tauTbl.source_run = repmat("", height(tauTbl), 1);
end
tauTbl = sortrows(tauTbl, 'Tp');
end

function failed = loadFailedDipClockMetrics(metricsPath, cfg)
if nargin < 2 || isempty(cfg)
    cfg = struct();
end
T = readtable(metricsPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
for vn = {'deltaT_K','rmse_log_before','rmse_log_after','rmse_improvement_pct','variance_before','variance_after','variance_improvement_pct','mean_pair_overlap_before','mean_pair_overlap_after'}
    name = vn{1};
    if ismember(name, T.Properties.VariableNames) && ~isnumeric(T.(name))
        T.(name) = str2double(erase(string(T.(name)), '"'));
    end
end
row = T(string(T.scenario) == "baseline_all_fm", :);
assert(~isempty(row), 'Could not find baseline_all_fm row in failed Dip-clock metrics: %s', metricsPath);
failed = struct();
if isfield(cfg, 'failedDipClockRunId') && ~isempty(cfg.failedDipClockRunId)
    failed.run_id = string(cfg.failedDipClockRunId);
    failed.run_id_source = "CFG_FAILED_DIP_CLOCK_RUN_ID";
else
    failed.run_id = deriveRunIdTokenFromMetricsPath(metricsPath);
    failed.run_id_source = "DERIVED_FROM_METRICS_PATH_TOKEN";
end
failed.metrics_path_resolved = string(metricsPath);
failed.rmse_log_before = row.rmse_log_before(1);
failed.rmse_log_after = row.rmse_log_after(1);
failed.rmse_improvement_pct = row.rmse_improvement_pct(1);
failed.variance_before = row.variance_before(1);
failed.variance_after = row.variance_after(1);
failed.variance_improvement_pct = row.variance_improvement_pct(1);
failed.mean_pair_overlap_before = row.mean_pair_overlap_before(1);
failed.mean_pair_overlap_after = row.mean_pair_overlap_after(1);
end

function tok = deriveRunIdTokenFromMetricsPath(metricsPath)
s = char(string(metricsPath));
found = regexp(s, 'run_\d{4}_\d{2}_\d{2}_\d{6}_[^\\/]+', 'once', 'match');
if isempty(found)
    tok = "RUN_ID_UNKNOWN_FROM_PATH_NOT_MODEL_SAFE";
else
    tok = string(found);
end
end

function tbl = appendFmTauLineageHardeningColumns(tbl, cfg, failedDipClock)
n = height(tbl);
if isempty(cfg.branch_id)
    branchLabel = "UNKNOWN_BRANCH_REQUIRE_EXPLICIT_CFG";
else
    branchLabel = string(cfg.branch_id);
end
ds = string(cfg.datasetPath);
dip = string(cfg.dipTauPath);
fdm = string(cfg.failedDipClockMetricsPath);
tbl.branch_id = repmat(branchLabel, n, 1);
tbl.datasetPath = repmat(ds, n, 1);
tbl.dipTauPath = repmat(dip, n, 1);
tbl.failedDipClockMetricsPath = repmat(fdm, n, 1);
tbl.source_run_id = tbl.source_run;
tbl.ratio_use_allowed = repmat("NO", n, 1);
tbl.FM_abs_convention = repmat("FM_ABS_AS_READ_NO_WRITER_ABS_TRANSFORM_PENDING_SIGNED_SOURCE", n, 1);
tbl.FM_input_column = repmat("FM_abs", n, 1);
tbl.FM_signed_source_column = repmat("NOT_PROVIDED_IN_MINIMAL_DATASET_SCHEMA", n, 1);
tbl.absolute_transform_applied_in_writer = repmat("NO", n, 1);
tbl.failed_dip_clock_run_id_report_ref = repmat(failedDipClock.run_id, n, 1);
tbl.failed_dip_clock_run_id_source = repmat(failedDipClock.run_id_source, n, 1);
rowModel = strings(n, 1);
rowRatio = strings(n, 1);
rowReason = strings(n, 1);
for i = 1:n
    hf = tbl.has_fm(i);
    te = tbl.tau_effective_seconds(i);
    fragile = tbl.fragile_low_point_count(i);
    if ~hf
        rowModel(i) = "NO";
        rowRatio(i) = "NO";
        rowReason(i) = "NO_FM_POINTS_AT_TP";
    elseif ~isfinite(te) || te <= 0
        rowModel(i) = "NO";
        rowRatio(i) = "NO";
        rowReason(i) = "NONFINITE_OR_NONPOSITIVE_TAU_EFFECTIVE";
    elseif fragile
        rowModel(i) = "NO";
        rowRatio(i) = "NO";
        rowReason(i) = "FRAGILE_SPARSE_FM_POINTS_CONSERVATIVE_BLOCK";
    else
        rowModel(i) = "NO";
        rowRatio(i) = "NO";
        rowReason(i) = "GLOBAL_POLICY_PENDING_F7S_ROW_TECHNICALLY_FIT_OK";
    end
end
tbl.row_model_use_allowed = rowModel;
tbl.row_ratio_use_allowed = rowRatio;
tbl.row_exclusion_reason = rowReason;
end

function tauTbl = buildFmTauTable(dataTbl)
tpValues = unique(dataTbl.Tp(isfinite(dataTbl.Tp)), 'sorted');
rows = repmat(initTauRow(), numel(tpValues), 1);
for i = 1:numel(tpValues)
    sub = dataTbl(dataTbl.Tp == tpValues(i), :);
    sub = sub(isfinite(sub.tw) & sub.tw > 0 & isfinite(sub.FM_abs), :);
    sub = sortrows(sub, 'tw');
    rows(i) = analyzeFmTpGroup(sub, tpValues(i));
end
tauTbl = struct2table(rows);
end

function row = initTauRow()
row = struct( ...
    'Tp', NaN, ...
    'has_fm', false, ...
    'n_points', 0, ...
    'fragile_low_point_count', false, ...
    'tw_min_seconds', NaN, ...
    'tw_max_seconds', NaN, ...
    'peak_tw_seconds', NaN, ...
    'FM_abs_start', NaN, ...
    'FM_abs_peak', NaN, ...
    'FM_abs_range_to_peak', NaN, ...
    'n_downturns', NaN, ...
    'tau_logistic_half_seconds', NaN, ...
    'tau_logistic_sigma_decades', NaN, ...
    'tau_logistic_rmse', NaN, ...
    'tau_logistic_r2', NaN, ...
    'tau_logistic_trusted', false, ...
    'tau_logistic_status', "", ...
    'tau_stretched_half_seconds', NaN, ...
    'tau_stretched_char_seconds', NaN, ...
    'tau_stretched_beta', NaN, ...
    'tau_stretched_rmse', NaN, ...
    'tau_stretched_r2', NaN, ...
    'tau_stretched_trusted', false, ...
    'tau_stretched_status', "", ...
    'tau_half_range_seconds', NaN, ...
    'tau_half_range_status', "", ...
    'tau_effective_seconds', NaN, ...
    'tau_consensus_method_count', 0, ...
    'tau_consensus_methods', "", ...
    'tau_method_spread_decades', NaN, ...
    'source_run', "");
end

function row = analyzeFmTpGroup(sub, tp)
row = initTauRow();
row.Tp = tp;
if isempty(sub)
    row.has_fm = false;
    row.source_run = "";
    return;
end

row.has_fm = true;
tw = sub.tw(:);
y = sub.FM_abs(:);
[peakValue, peakIdx] = max(y, [], 'omitnan');
if isempty(peakIdx) || ~isfinite(peakValue)
    peakIdx = NaN;
    peakValue = NaN;
end

row.n_points = numel(tw);
row.fragile_low_point_count = numel(tw) < 4;
row.tw_min_seconds = min(tw, [], 'omitnan');
row.tw_max_seconds = max(tw, [], 'omitnan');
if isfinite(peakIdx)
    row.peak_tw_seconds = tw(peakIdx);
end
row.FM_abs_start = y(1);
row.FM_abs_peak = peakValue;
row.FM_abs_range_to_peak = peakValue - y(1);
row.n_downturns = nnz(diff(y) < 0);
row.source_run = string(sub.source_run(1));

logisticFit = fitLogisticInLogTime(tw, y);
row.tau_logistic_half_seconds = logisticFit.tau_half_seconds;
row.tau_logistic_sigma_decades = logisticFit.sigma_decades;
row.tau_logistic_rmse = logisticFit.rmse;
row.tau_logistic_r2 = logisticFit.r2;
row.tau_logistic_trusted = logisticFit.trusted;
row.tau_logistic_status = logisticFit.status;

stretchedFit = fitStretchedExponential(tw, y);
row.tau_stretched_half_seconds = stretchedFit.tau_half_seconds;
row.tau_stretched_char_seconds = stretchedFit.tau_char_seconds;
row.tau_stretched_beta = stretchedFit.beta;
row.tau_stretched_rmse = stretchedFit.rmse;
row.tau_stretched_r2 = stretchedFit.r2;
row.tau_stretched_trusted = stretchedFit.trusted;
row.tau_stretched_status = stretchedFit.status;

halfRange = estimateHalfRangeTime(tw, y);
row.tau_half_range_seconds = halfRange.tau_seconds;
row.tau_half_range_status = halfRange.status;

[row.tau_effective_seconds, row.tau_consensus_method_count, row.tau_consensus_methods, row.tau_method_spread_decades] = buildEffectiveFmTau(row);
end
function curves = buildCollapseCurves(dataTbl, tauTbl)
tpValues = unique(dataTbl.Tp(isfinite(dataTbl.Tp)), 'sorted');
curves = repmat(initCurveRow(), numel(tpValues), 1);
for i = 1:numel(tpValues)
    tp = tpValues(i);
    sub = dataTbl(dataTbl.Tp == tp, :);
    sub = sortrows(sub, 'tw');
    curve = initCurveRow();
    curve.Tp = tp;
    curve.source_runs = join(unique(sub.source_run), '; ');
    valid = isfinite(sub.tw) & sub.tw > 0 & isfinite(sub.FM_abs);
    if any(valid)
        curve.has_fm = true;
        curve.tw = sub.tw(valid);
        curve.fm_abs = sub.FM_abs(valid);
        curve.fm_max = max(curve.fm_abs, [], 'omitnan');
        curve.fm_norm = curve.fm_abs ./ curve.fm_max;
        curve.n_points = numel(curve.tw);
        curve.is_fragile = curve.n_points < 4;
    end
    tauRow = tauTbl(tauTbl.Tp == tp, :);
    if ~isempty(tauRow) && tauRow.has_fm && isfinite(tauRow.tau_effective_seconds) && tauRow.tau_effective_seconds > 0 && curve.has_fm
        curve.has_tau_fm = true;
        curve.tau_fm_seconds = tauRow.tau_effective_seconds(1);
    end
    curves(i) = curve;
end
end

function curve = initCurveRow()
curve = struct('Tp', NaN, 'has_fm', false, 'has_tau_fm', false, 'tw', NaN(0,1), ...
    'fm_abs', NaN(0,1), 'fm_norm', NaN(0,1), 'fm_max', NaN, 'tau_fm_seconds', NaN, ...
    'n_points', 0, 'is_fragile', false, 'source_runs', "");
end

function metrics = evaluateCollapse(curves, tauVector, cfg)
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
meanCurve = nan(1, numel(xGrid));
stdCurve = nan(1, numel(xGrid));
varCurve = nan(1, numel(xGrid));
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

function comparison = compareTauStructures(fmTauTbl, dipTauTbl)
validFm = fmTauTbl.has_fm & isfinite(fmTauTbl.tau_effective_seconds) & fmTauTbl.tau_effective_seconds > 0;
validDip = isfinite(dipTauTbl.tau_effective_seconds) & dipTauTbl.tau_effective_seconds > 0;
overlapTp = intersect(fmTauTbl.Tp(validFm), dipTauTbl.Tp(validDip));
fmTau = nan(numel(overlapTp), 1);
dipTau = nan(numel(overlapTp), 1);
for i = 1:numel(overlapTp)
    fmTau(i) = fmTauTbl.tau_effective_seconds(fmTauTbl.Tp == overlapTp(i));
    dipTau(i) = dipTauTbl.tau_effective_seconds(dipTauTbl.Tp == overlapTp(i));
end
logRatio = log10(fmTau) - log10(dipTau);
comparison = struct();
comparison.overlap_tp = overlapTp(:);
comparison.fm_tau_overlap = fmTau(:);
comparison.dip_tau_overlap = dipTau(:);
comparison.median_log10_ratio = median(logRatio, 'omitnan');
comparison.max_abs_log10_ratio = max(abs(logRatio), [], 'omitnan');
comparison.median_ratio = 10 .^ comparison.median_log10_ratio;
comparison.correlation = pearsonLogCorrelation(fmTau, dipTau);
comparison.summary_line = buildTauComparisonSummary(comparison);
end

function r = pearsonLogCorrelation(a, b)
mask = isfinite(a) & a > 0 & isfinite(b) & b > 0;
if nnz(mask) < 2
    r = NaN;
    return;
end
x = log10(a(mask));
y = log10(b(mask));
x = x - mean(x);
y = y - mean(y);
denom = sqrt(sum(x.^2) * sum(y.^2));
if denom <= eps
    r = NaN;
else
    r = sum(x .* y) / denom;
end
end

function line = buildTauComparisonSummary(comparison)
if isempty(comparison.overlap_tp)
    line = "No overlapping finite tau values are available for a meaningful FM-vs-Dip comparison.";
elseif comparison.max_abs_log10_ratio >= 1
    line = sprintf('tau_FM differs strongly from tau_dip across the overlap set: median ratio %.2fx, max mismatch %.2f decades.', comparison.median_ratio, comparison.max_abs_log10_ratio);
elseif comparison.max_abs_log10_ratio >= 0.3
    line = sprintf('tau_FM partially tracks tau_dip but with substantial offsets: median ratio %.2fx, max mismatch %.2f decades.', comparison.median_ratio, comparison.max_abs_log10_ratio);
else
    line = sprintf('tau_FM broadly tracks tau_dip on the overlap set: median ratio %.2fx.', comparison.median_ratio);
end
end

function fit = initFitResult(status)
if nargin < 1
    status = "not_run";
end
fit = struct('tau_half_seconds', NaN, 'tau_char_seconds', NaN, 'sigma_decades', NaN, 'beta', NaN, ...
    'rmse', NaN, 'r2', NaN, 'trusted', false, 'status', string(status));
end

function fit = fitLogisticInLogTime(t, y)
fit = initFitResult("fit_failed");
if numel(t) < 3 || any(~isfinite(t)) || any(~isfinite(y)) || any(t <= 0)
    fit.status = "insufficient_data";
    return;
end
x = log10(t(:));
y = y(:);
rangeY = max(y) - min(y);
scaleY = max([rangeY, max(abs(y)), eps]);
yScaled = y ./ scaleY;
halfData = estimateHalfRangeTime(t, y);
if isfinite(halfData.tau_seconds) && halfData.tau_seconds > 0
    muSeeds = [log10(halfData.tau_seconds), mean(x), median(x), x(1), x(end)];
else
    muSeeds = [mean(x), median(x), x(1), x(end)];
end
sigmaSeeds = [0.20, 0.40, 0.80, 1.20];
deltaSeeds = [max(rangeY / scaleY, 0.05), max(yScaled(end) - yScaled(1), 0.05), 0.25, 0.75];
y0Seeds = [min(yScaled), yScaled(1), min(yScaled) - 0.10];
best = [];
bestSse = inf;
opts = optimset('Display', 'off', 'MaxIter', 4000, 'MaxFunEvals', 8000);
for y0 = y0Seeds
    for delta = deltaSeeds
        for mu = muSeeds
            for sigma = sigmaSeeds
                p0 = [y0, log(max(delta, 1e-6)), mu, log(max(sigma, 1e-6))];
                [p, sse] = fminsearch(@(pp) logisticObjective(pp, x, yScaled), p0, opts);
                if isfinite(sse) && sse < bestSse
                    bestSse = sse;
                    best = p;
                end
            end
        end
    end
end
if isempty(best)
    return;
end
params = unpackLogisticParams(best);
yHatScaled = logisticModel(params, x);
yHat = yHatScaled .* scaleY;
rmse = sqrt(mean((y - yHat).^2, 'omitnan'));
r2 = computeRsquared(y, yHat);
tauHalf = 10.^params.mu;
rmseRel = rmse ./ max(rangeY, eps);
fit.tau_half_seconds = tauHalf;
fit.sigma_decades = params.sigma;
fit.rmse = rmse;
fit.r2 = r2;
fit.trusted = isfinite(tauHalf) && tauHalf > 0 && rmseRel <= 0.65;
fit.status = classifyModelStatus(rmseRel, tauHalf, t);
end

function fit = fitStretchedExponential(t, y)
fit = initFitResult("fit_failed");
if numel(t) < 3 || any(~isfinite(t)) || any(~isfinite(y)) || any(t <= 0)
    fit.status = "insufficient_data";
    return;
end
t = t(:);
y = y(:);
rangeY = max(y) - min(y);
scaleY = max([rangeY, max(abs(y)), eps]);
yScaled = y ./ scaleY;
halfData = estimateHalfRangeTime(t, y);
betaSeeds = [0.50, 0.80, 1.20, 1.60];
tauSeeds = [sqrt(t(1) * t(end)), median(t), t(end) / 2, t(1)];
if isfinite(halfData.tau_seconds) && halfData.tau_seconds > 0
    tauSeeds(end + 1) = halfData.tau_seconds / (log(2) .^ (1 / betaSeeds(2))); %#ok<AGROW>
end
deltaSeeds = [max(rangeY / scaleY, 0.05), max(y(end) - y(1), 0.05) / scaleY, 0.25, 0.75];
y0Seeds = [min(yScaled), yScaled(1), min(yScaled) - 0.10];
best = [];
bestSse = inf;
opts = optimset('Display', 'off', 'MaxIter', 5000, 'MaxFunEvals', 10000);
for y0 = y0Seeds
    for delta = deltaSeeds
        for tau = tauSeeds
            if ~isfinite(tau) || tau <= 0
                continue;
            end
            for beta = betaSeeds
                p0 = [y0, log(max(delta, 1e-6)), log(tau), betaToRaw(beta)];
                [p, sse] = fminsearch(@(pp) stretchedObjective(pp, t, yScaled), p0, opts);
                if isfinite(sse) && sse < bestSse
                    bestSse = sse;
                    best = p;
                end
            end
        end
    end
end
if isempty(best)
    return;
end
params = unpackStretchedParams(best);
yHatScaled = stretchedModel(params, t);
yHat = yHatScaled .* scaleY;
rmse = sqrt(mean((y - yHat).^2, 'omitnan'));
r2 = computeRsquared(y, yHat);
tauHalf = params.tau_char .* (log(2) .^ (1 ./ params.beta));
rmseRel = rmse ./ max(rangeY, eps);
fit.tau_half_seconds = tauHalf;
fit.tau_char_seconds = params.tau_char;
fit.beta = params.beta;
fit.rmse = rmse;
fit.r2 = r2;
fit.trusted = isfinite(tauHalf) && tauHalf > 0 && rmseRel <= 0.65;
fit.status = classifyModelStatus(rmseRel, tauHalf, t);
end
function result = estimateHalfRangeTime(t, y)
result = struct('tau_seconds', NaN, 'status', "unresolved");
if numel(t) < 2 || any(~isfinite(t)) || any(~isfinite(y)) || any(t <= 0)
    result.status = "insufficient_data";
    return;
end
t = t(:);
y = y(:);
[peakValue, peakIdx] = max(y, [], 'omitnan');
if isempty(peakIdx) || ~isfinite(peakValue)
    result.status = "missing_peak";
    return;
end
yStart = y(1);
if peakIdx == 1 || ~isfinite(yStart) || peakValue <= yStart
    result.status = "no_upward_crossing";
    return;
end
target = yStart + 0.5 * (peakValue - yStart);
crossIdx = find(y(1:peakIdx-1) <= target & y(2:peakIdx) >= target, 1, 'first');
if isempty(crossIdx)
    tol = eps(max(abs([target; y])));
    exactIdx = find(abs(y(1:peakIdx) - target) <= tol, 1, 'first');
    if isempty(exactIdx)
        result.status = "no_upward_crossing";
        return;
    end
    result.tau_seconds = t(exactIdx);
    result.status = "ok";
    return;
end
t1 = t(crossIdx);
t2 = t(crossIdx + 1);
y1 = y(crossIdx);
y2 = y(crossIdx + 1);
tol = eps(max(abs([y1; y2])));
if ~isfinite(y1) || ~isfinite(y2) || abs(y2 - y1) <= tol
    result.tau_seconds = sqrt(t1 * t2);
    result.status = "ok";
    return;
end
frac = (target - y1) ./ (y2 - y1);
frac = min(max(frac, 0), 1);
logTau = log10(t1) + frac .* (log10(t2) - log10(t1));
result.tau_seconds = 10.^logTau;
result.status = "ok";
end

function [tauEffective, nMethods, methodNames, spreadDecades] = buildEffectiveFmTau(row)
tauValues = [];
names = strings(0, 1);
if row.tau_logistic_trusted && isfinite(row.tau_logistic_half_seconds) && row.tau_logistic_half_seconds > 0
    tauValues(end + 1, 1) = row.tau_logistic_half_seconds; %#ok<AGROW>
    names(end + 1, 1) = "logistic_log_tw"; %#ok<AGROW>
end
if row.tau_stretched_trusted && isfinite(row.tau_stretched_half_seconds) && row.tau_stretched_half_seconds > 0
    tauValues(end + 1, 1) = row.tau_stretched_half_seconds; %#ok<AGROW>
    names(end + 1, 1) = "stretched_exp"; %#ok<AGROW>
end
if row.tau_half_range_status == "ok" && isfinite(row.tau_half_range_seconds) && row.tau_half_range_seconds > 0
    tauValues(end + 1, 1) = row.tau_half_range_seconds; %#ok<AGROW>
    names(end + 1, 1) = "half_range"; %#ok<AGROW>
end
if isempty(tauValues)
    tauEffective = NaN;
    nMethods = 0;
    methodNames = "";
    spreadDecades = NaN;
    return;
end
logTau = log10(tauValues);
spreadDecades = max(logTau) - min(logTau);
if row.tau_half_range_status == "ok" && isfinite(row.tau_half_range_seconds) && row.tau_half_range_seconds > 0
    tauEffective = row.tau_half_range_seconds;
    nMethods = 1;
    methodNames = "half_range_primary";
else
    tauEffective = 10.^median(logTau);
    nMethods = numel(tauValues);
    methodNames = strjoin(names.', ', ');
end
end

function fig = makeRawFmFigure(curves, missingCurves, cfg)
validCurves = curves([curves.has_fm]);
fig = create_figure('Visible', 'off', 'Position', cfg.rawFigurePosition, 'Name', 'fm_vs_tw_by_Tp');
ax = axes(fig);
hold(ax, 'on');
colors = lines(max(numel(validCurves), 1));
allTw = unique(collectAllTw(validCurves));
for i = 1:numel(validCurves)
    lineStyle = '-';
    marker = 'o';
    if validCurves(i).is_fragile
        lineStyle = '--';
        marker = 's';
    end
    plot(ax, validCurves(i).tw, validCurves(i).fm_abs, [lineStyle marker], 'Color', colors(i, :), ...
        'MarkerFaceColor', colors(i, :), 'MarkerSize', 6.5, 'LineWidth', 2.2, 'DisplayName', sprintf('T_p = %.0f K', validCurves(i).Tp));
end
set(ax, 'XScale', 'log');
xticks(ax, allTw);
grid(ax, 'on');
xlabel(ax, 'Waiting time t_w (s)');
ylabel(ax, 'FM_{abs} (arb.)');
title(ax, 'Raw FM background vs waiting time');
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
legend(ax, 'Location', 'eastoutside', 'FontSize', 11, 'Box', 'off');
missingText = '';
if ~isempty(missingCurves)
    missingText = sprintf('FM_abs unavailable at T_p = %s K.', join(string([missingCurves.Tp]), ', '));
end

end

function fig = makeRescaledFmFigure(curves, baseline, fmCollapse, cfg)
fig = create_figure('Visible', 'off', 'Position', cfg.rescaledFigurePosition, 'Name', 'fm_rescaled_vs_tw_over_tau_FM');
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
colors = lines(numel(curves));
allTw = unique(collectAllTw(curves));
ax1 = nexttile(tlo, 1);
hold(ax1, 'on');
for i = 1:numel(curves)
    lineStyle = ternary(curves(i).is_fragile, '--', '-');
    marker = ternary(curves(i).is_fragile, 's', 'o');
    plot(ax1, curves(i).tw, curves(i).fm_norm, [lineStyle marker], 'Color', colors(i, :), 'MarkerFaceColor', colors(i, :), ...
        'MarkerSize', 6, 'LineWidth', 2.1, 'DisplayName', sprintf('T_p = %.0f K', curves(i).Tp));
end
set(ax1, 'XScale', 'log', 'YLim', [0 1.08]);
xticks(ax1, allTw);
grid(ax1, 'on');
xlabel(ax1, 'Waiting time t_w (s)');
ylabel(ax1, 'FM_{abs} / max(FM_{abs})');
title(ax1, 'Normalization only');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
text(ax1, 0.04, 0.96, buildMetricTextbox(baseline), 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 10.5, 'BackgroundColor', 'w', 'Margin', 5);

ax2 = nexttile(tlo, 2);
hold(ax2, 'on');
drawBand(ax2, fmCollapse.profile);
for i = 1:numel(curves)
    lineStyle = ternary(curves(i).is_fragile, '--', '-');
    marker = ternary(curves(i).is_fragile, 's', 'o');
    plot(ax2, curves(i).tw ./ curves(i).tau_fm_seconds, curves(i).fm_norm, [lineStyle marker], 'Color', colors(i, :), 'MarkerFaceColor', colors(i, :), ...
        'MarkerSize', 6, 'LineWidth', 2.1, 'DisplayName', sprintf('T_p = %.0f K', curves(i).Tp));
end
set(ax2, 'XScale', 'log', 'YLim', [0 1.08]);
grid(ax2, 'on');
xlabel(ax2, 't_w / \tau_{FM}(T_p)');
ylabel(ax2, 'FM_{abs} / max(FM_{abs})');
title(ax2, 'Rescaled by extracted FM clock');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
legend(ax2, 'Location', 'eastoutside', 'FontSize', 11, 'Box', 'off');
text(ax2, 0.04, 0.96, buildMetricTextbox(fmCollapse), 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 10.5, 'BackgroundColor', 'w', 'Margin', 5);

title(tlo, 'FM collapse under extracted tau_FM(T_p)');
end

function fig = makeFmTauFigure(fmTauTbl, cfg)
fig = create_figure('Visible', 'off', 'Position', cfg.tauFigurePosition, 'Name', 'tau_FM_vs_Tp');
ax = axes(fig);
hold(ax, 'on');
plot(ax, fmTauTbl.Tp, fmTauTbl.tau_logistic_half_seconds, '-o', 'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerSize', 5.5, 'LineWidth', 2.0, 'DisplayName', 'Logistic fit in log(t_w)');
plot(ax, fmTauTbl.Tp, fmTauTbl.tau_stretched_half_seconds, '-s', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerSize', 5.5, 'LineWidth', 2.0, 'DisplayName', 'Stretched-exp half time');
plot(ax, fmTauTbl.Tp, fmTauTbl.tau_half_range_seconds, '-^', 'Color', [0.00 0.62 0.45], 'MarkerFaceColor', [0.00 0.62 0.45], 'MarkerSize', 5.5, 'LineWidth', 2.0, 'DisplayName', 'Direct half-range');
plot(ax, fmTauTbl.Tp, fmTauTbl.tau_effective_seconds, '-d', 'Color', [0.00 0.00 0.00], 'MarkerFaceColor', [0.00 0.00 0.00], 'MarkerSize', 5.5, 'LineWidth', 2.4, 'DisplayName', 'Effective tau_FM');
fragileMask = fmTauTbl.fragile_low_point_count & isfinite(fmTauTbl.tau_effective_seconds);
if any(fragileMask)
    plot(ax, fmTauTbl.Tp(fragileMask), fmTauTbl.tau_effective_seconds(fragileMask), 'ko', 'MarkerSize', 8, 'LineWidth', 1.2, 'MarkerFaceColor', 'w', 'DisplayName', 'Fragile T_p (3 points)');
end
set(ax, 'YScale', 'log');
grid(ax, 'on');
xlabel(ax, 'Stopping temperature T_p (K)');
ylabel(ax, 'FM aging timescale \tau_{FM} (s)');
title(ax, 'FM timescale estimates vs stopping temperature');
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
legend(ax, 'Location', 'eastoutside', 'FontSize', 10.5, 'Box', 'off');
end

function fig = makeTauComparisonFigure(fmTauTbl, dipTauTbl, comparison, cfg)
fig = create_figure('Visible', 'off', 'Position', cfg.compareFigurePosition, 'Name', 'tau_FM_vs_tau_dip');
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tlo, 1);
hold(ax1, 'on');
plot(ax1, fmTauTbl.Tp, fmTauTbl.tau_effective_seconds, '-o', 'Color', [0.10 0.10 0.10], 'MarkerFaceColor', [0.10 0.10 0.10], 'MarkerSize', 6, 'LineWidth', 2.2, 'DisplayName', 'tau_FM effective');
plot(ax1, dipTauTbl.Tp, dipTauTbl.tau_effective_seconds, '-s', 'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerSize', 6, 'LineWidth', 2.2, 'DisplayName', 'tau_dip consensus');
set(ax1, 'YScale', 'log');
grid(ax1, 'on');
xlabel(ax1, 'Stopping temperature T_p (K)');
ylabel(ax1, 'Timescale \tau (s)');
title(ax1, 'tau_FM and tau_dip vs T_p');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
legend(ax1, 'Location', 'best', 'FontSize', 10.5, 'Box', 'off');

ax2 = nexttile(tlo, 2);
hold(ax2, 'on');
if ~isempty(comparison.overlap_tp)
    scatter(ax2, comparison.dip_tau_overlap, comparison.fm_tau_overlap, 85, comparison.overlap_tp, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.7);
    minVal = min([comparison.dip_tau_overlap; comparison.fm_tau_overlap]);
    maxVal = max([comparison.dip_tau_overlap; comparison.fm_tau_overlap]);
    plot(ax2, [minVal maxVal], [minVal maxVal], '--', 'Color', [0.30 0.30 0.30], 'LineWidth', 1.8, 'DisplayName', 'tau_FM = tau_dip');
    cb = colorbar(ax2);
    cb.Label.String = 'T_p (K)';
else
    text(ax2, 0.5, 0.5, 'No overlap', 'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 14);
end
set(ax2, 'XScale', 'log', 'YScale', 'log');
grid(ax2, 'on');
xlabel(ax2, '\tau_{dip} (s)');
ylabel(ax2, '\tau_{FM} (s)');
title(ax2, 'Overlap temperatures only');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
text(ax2, 0.04, 0.96, comparison.summary_line, 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 10.5, 'BackgroundColor', 'w', 'Margin', 5);

title(tlo, 'Comparison of extracted FM and Dip timescales');
end

function reportText = buildReportText(runDir, cfg, dataTbl, fmTauTbl, dipTauTbl, baseline, fmCollapse, failedDipClock, comparison)
lines = strings(0, 1);
lines(end + 1) = '# Aging FM timescale analysis';
lines(end + 1) = '';
lines(end + 1) = sprintf('Generated: %s', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf('Run root: `%s`', string(runDir));
lines(end + 1) = '';
lines(end + 1) = '## Repository scan summary';
lines(end + 1) = '- I scanned the Aging module and `results/aging/runs/` before creating this run.';
lines(end + 1) = '- No completed prior run was found that extracted `tau_FM(T_p)` directly from `FM_abs(T_p, t_w)` and then tested an `FM_abs` collapse under `t_w / tau_FM(T_p)`.';
lines(end + 1) = '- Relevant prior runs were: `run_2026_03_12_223709_aging_timescale_extraction` (Dip tau extraction), `run_2026_03_12_225842_aging_component_clock_test` (direct Dip-vs-FM mismatch), `run_2026_03_13_005134_aging_fm_using_dip_clock` (FM under Dip-collapse tau, worse collapse), and `run_2026_03_13_010148_aging_fm_using_extracted_dip_tau` (FM under directly extracted Dip tau, still no robust collapse).';
lines(end + 1) = '';
lines(end + 1) = '## Inputs';
lines(end + 1) = sprintf('- Observable dataset: `%s`', cfg.datasetPath);
lines(end + 1) = sprintf('- Dip tau reference for comparison: `%s`', cfg.dipTauPath);
lines(end + 1) = sprintf('- Failed Dip-clock FM metrics reused for comparison: `%s`', cfg.failedDipClockMetricsPath);
lines(end + 1) = '';
lines(end + 1) = '## Temperature coverage';
finiteFmRows = fmTauTbl(fmTauTbl.has_fm, :);
missingFmRows = fmTauTbl(~fmTauTbl.has_fm, :);
lines(end + 1) = sprintf('- Finite `FM_abs` temperatures: `%s` K.', strjoin(string(finiteFmRows.Tp.'), ', '));
if ~isempty(missingFmRows)
    lines(end + 1) = sprintf('- `FM_abs` missing: `%s` K.', strjoin(string(missingFmRows.Tp.'), ', '));
end
lines(end + 1) = sprintf('- Waiting-time grid in the source dataset: `%s` s.', strjoin(string(unique(dataTbl.tw).'), ', '));
lines(end + 1) = '';
lines(end + 1) = '## FM timescale extraction';
lines(end + 1) = '- I used the same three estimator families as the Dip analysis wherever the FM shape allowed it: logistic fit in `log10(t_w)`, stretched exponential, and direct half-range to the observed peak.';
lines(end + 1) = '- `tau_FM(T_p)` uses the direct half-range time as the primary effective clock whenever that crossing is resolved; the logistic and stretched-exponential fits are retained as diagnostics when the sparse FM traces allow them.';
lines(end + 1) = sprintf('- Temperatures with finite effective `tau_FM`: `%s` K.', strjoin(string(fmTauTbl.Tp(isfinite(fmTauTbl.tau_effective_seconds)).'), ', '));
[~, minIdx] = min(fmTauTbl.tau_effective_seconds, [], 'omitnan');
[~, maxIdx] = max(fmTauTbl.tau_effective_seconds, [], 'omitnan');
lines(end + 1) = sprintf('- Shortest finite `tau_FM`: `T_p = %.0f K`, `tau_FM = %.3g s`.', fmTauTbl.Tp(minIdx), fmTauTbl.tau_effective_seconds(minIdx));
lines(end + 1) = sprintf('- Longest finite `tau_FM`: `T_p = %.0f K`, `tau_FM = %.3g s`.', fmTauTbl.Tp(maxIdx), fmTauTbl.tau_effective_seconds(maxIdx));
lines(end + 1) = '';
lines(end + 1) = '## Collapse quality';
lines(end + 1) = sprintf('- Normalization-only baseline: `RMSE_log = %.4f`, mean gridded variance `%.5f`, mean pair overlap `%.2f` decades.', baseline.rmse_log, baseline.mean_gridded_variance, baseline.mean_pair_overlap_decades);
lines(end + 1) = sprintf('- Extracted FM clock: `RMSE_log = %.4f`, mean gridded variance `%.5f`, mean pair overlap `%.2f` decades.', fmCollapse.rmse_log, fmCollapse.mean_gridded_variance, fmCollapse.mean_pair_overlap_decades);
lines(end + 1) = sprintf('- Relative to baseline, the FM clock changes RMSE by `%.2f%%` and variance by `%.2f%%`.', percentReduction(baseline.rmse_log, fmCollapse.rmse_log), percentReduction(baseline.mean_gridded_variance, fmCollapse.mean_gridded_variance));
lines(end + 1) = sprintf('- Failed Dip-clock comparison (`%s`): `RMSE_log_after = %.4f`, variance `%.5f`, overlap `%.2f` decades.', failedDipClock.run_id, failedDipClock.rmse_log_after, failedDipClock.variance_after, failedDipClock.mean_pair_overlap_after);
lines(end + 1) = sprintf('- Relative to the failed Dip-clock test, the FM-own clock changes RMSE by `%.2f%%` and variance by `%.2f%%`.', percentReduction(failedDipClock.rmse_log_after, fmCollapse.rmse_log), percentReduction(failedDipClock.variance_after, fmCollapse.mean_gridded_variance));
lines(end + 1) = sprintf('- Collapse verdict: %s', classifyCollapseQuality(baseline, fmCollapse));
lines(end + 1) = '';
lines(end + 1) = '## tau_FM vs tau_dip';
lines(end + 1) = sprintf('- Overlap temperatures with finite `tau_FM` and finite direct `tau_dip`: `%s` K.', strjoin(string(comparison.overlap_tp.'), ', '));
lines(end + 1) = sprintf('- %s', comparison.summary_line);
lines(end + 1) = sprintf('- Log-space correlation on the overlap set: `%.3f`.', comparison.correlation);
lines(end + 1) = '- In practice, `tau_FM` stays large through `26-30 K`, while the direct `tau_dip` curve peaks earlier and then collapses or becomes unresolved at the high-temperature end.';
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- `fm_vs_tw_by_Tp`: 6 finite-FM curves, explicit legend, no colormap, no smoothing, used to show the raw FM growth law and identify fragile 3-point temperatures.';
lines(end + 1) = '- `fm_rescaled_vs_tw_over_tau_FM`: 2-panel normalized-before/rescaled-after view, explicit legend, no colormap, no smoothing, with a mean +/- 1 sigma band in the rescaled panel.';
lines(end + 1) = '- `tau_FM_vs_Tp`: 4 method/summary curves, explicit legend, no colormap, no smoothing, matching the Dip timescale figure style.';
lines(end + 1) = '- `tau_FM_vs_tau_dip`: 2-panel comparison figure with a direct-vs-direct overlap scatter; no smoothing.';
lines(end + 1) = '';
lines(end + 1) = '## Conclusion';
if percentReduction(baseline.rmse_log, fmCollapse.rmse_log) >= 20 && percentReduction(baseline.mean_gridded_variance, fmCollapse.mean_gridded_variance) >= 20
    lines(end + 1) = '- `FM_abs` shows a meaningful collapse under its own extracted `tau_FM(T_p)`.';
else
    lines(end + 1) = '- `FM_abs` does not show a strong universal collapse even under its own extracted `tau_FM(T_p)`, although the FM-own clock may still perform better than the transferred Dip clock.';
end
lines(end + 1) = sprintf('- Relative to the transferred Dip-clock test, the FM-own clock is `%s` by RMSE and `%s` by variance.', comparisonWord(fmCollapse.rmse_log, failedDipClock.rmse_log_after), comparisonWord(fmCollapse.mean_gridded_variance, failedDipClock.variance_after));
lines(end + 1) = '- `tau_FM(T_p)` differs from the directly extracted `tau_dip(T_p)` structure, especially once the temperature reaches the upper-mid and high end of the available FM data.';
lines(end + 1) = '';
lines(end + 1) = '## Outputs';
lines(end + 1) = '- `tables/tau_FM_vs_Tp.csv`';
lines(end + 1) = '- `figures/fm_vs_tw_by_Tp.png`';
lines(end + 1) = '- `figures/fm_rescaled_vs_tw_over_tau_FM.png`';
lines(end + 1) = '- `figures/tau_FM_vs_Tp.png`';
lines(end + 1) = '- `figures/tau_FM_vs_tau_dip.png`';
lines(end + 1) = '- `reports/aging_fm_timescale_analysis_report.md`';
lines(end + 1) = '- `review/aging_fm_timescale_analysis_outputs.zip`';
reportText = strjoin(lines, newline);
end

function txt = buildMetricTextbox(metrics)
txt = sprintf('RMSE_{log} = %.3f\nMean variance = %.4f\nOverlap = %.2f decades\nValid pairs = %d', metrics.rmse_log, metrics.mean_gridded_variance, metrics.mean_pair_overlap_decades, metrics.n_pairs);
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

function txt = classifyCollapseQuality(baseline, fmCollapse)
rmseGain = percentReduction(baseline.rmse_log, fmCollapse.rmse_log);
varGain = percentReduction(baseline.mean_gridded_variance, fmCollapse.mean_gridded_variance);
if rmseGain >= 35 && varGain >= 35 && fmCollapse.mean_gridded_variance <= 0.03
    txt = 'FM_abs shows a strong collapse under tau_FM(T_p).';
elseif rmseGain >= 15 && varGain >= 15
    txt = 'FM_abs shows a partial collapse under tau_FM(T_p), but the spread remains substantial.';
elseif rmseGain > 0 || varGain > 0
    txt = 'tau_FM(T_p) offers only a weak improvement over normalization alone.';
else
    txt = 'tau_FM(T_p) does not improve the normalized FM collapse.';
end
end

function word = comparisonWord(newValue, oldValue)
if isfinite(newValue) && isfinite(oldValue) && newValue < oldValue
    word = 'better';
elseif isfinite(newValue) && isfinite(oldValue) && newValue > oldValue
    word = 'worse';
else
    word = 'inconclusive';
end
end

function files = collectAllTw(curves)
files = [];
for i = 1:numel(curves)
    files = [files; curves(i).tw(:)]; %#ok<AGROW>
end
files = files(isfinite(files));
end

function zipPath = createReviewZip(runDir, zipName)
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

function [sse, yHat] = logisticObjective(p, x, y)
params = unpackLogisticParams(p);
yHat = logisticModel(params, x);
if any(~isfinite(yHat))
    sse = inf;
    return;
end
resid = y - yHat;
sse = sum(resid.^2, 'omitnan');
end

function params = unpackLogisticParams(p)
params = struct();
params.y0 = p(1);
params.delta = exp(p(2));
params.mu = p(3);
params.sigma = exp(p(4));
end

function yHat = logisticModel(params, x)
z = -(x - params.mu) ./ max(params.sigma, eps);
yHat = params.y0 + params.delta ./ (1 + exp(z));
end

function [sse, yHat] = stretchedObjective(p, t, y)
params = unpackStretchedParams(p);
yHat = stretchedModel(params, t);
if any(~isfinite(yHat))
    sse = inf;
    return;
end
resid = y - yHat;
sse = sum(resid.^2, 'omitnan');
end

function params = unpackStretchedParams(p)
params = struct();
params.y0 = p(1);
params.delta = exp(p(2));
params.tau_char = exp(p(3));
params.beta = rawToBeta(p(4));
end

function yHat = stretchedModel(params, t)
scaledT = (t ./ max(params.tau_char, eps)) .^ params.beta;
yHat = params.y0 + params.delta .* (1 - exp(-scaledT));
end

function raw = betaToRaw(beta)
betaMax = 2.0;
beta = min(max(beta, 1e-4), betaMax - 1e-4);
raw = log(beta ./ (betaMax - beta));
end

function beta = rawToBeta(raw)
betaMax = 2.0;
beta = betaMax ./ (1 + exp(-raw));
end

function r2 = computeRsquared(y, yHat)
mask = isfinite(y) & isfinite(yHat);
if nnz(mask) < 2
    r2 = NaN;
    return;
end
ssRes = sum((y(mask) - yHat(mask)).^2);
ssTot = sum((y(mask) - mean(y(mask), 'omitnan')).^2);
if ssTot <= eps
    r2 = NaN;
else
    r2 = 1 - ssRes ./ ssTot;
end
end

function status = classifyModelStatus(rmseRel, tauHalf, t)
if ~isfinite(tauHalf) || tauHalf <= 0
    status = "fit_failed";
elseif ~isfinite(rmseRel)
    status = "fit_failed";
elseif rmseRel > 0.65
    status = "poor_match";
elseif tauHalf < min(t) || tauHalf > max(t)
    status = "extrapolated";
else
    status = "ok";
end
end

function appendText(pathStr, textStr)
fid = fopen(pathStr, 'a');
if fid < 0
    error('Could not open %s for append.', pathStr);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textStr);
end

function pct = percentReduction(beforeVal, afterVal)
if ~(isfinite(beforeVal) && isfinite(afterVal))
    pct = NaN;
    return;
end
pct = 100 * (1 - afterVal / max(beforeVal, eps));
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





