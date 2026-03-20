function out = aging_tri_clock_consistency_test(cfg)
% aging_tri_clock_consistency_test
% Test whether the structured Aging maps are consistent with a single
% effective clock near T_p ~= 26 K using rank-1 amplitude factorization.

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
validateInputs(cfg);

cfgRun = struct();
cfgRun.runLabel = char(string(cfg.runLabel));
cfgRun.datasetName = 'aging_tri_clock_consistency_test';
cfgRun.observable_dataset = char(string(cfg.observableDatasetPath));
cfgRun.dip_tau_source = char(string(cfg.dipTauPath));
cfgRun.fm_tau_source = char(string(cfg.fmTauPath));
runCtx = createRunContext('aging', cfgRun);
runDir = runCtx.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging TRI clock consistency run root:\n%s\n', runDir);
appendText(runCtx.log_path, sprintf('[%s] started\n', stampNow()));
appendText(runCtx.log_path, sprintf('Observable dataset: %s\n', cfg.observableDatasetPath));
appendText(runCtx.log_path, sprintf('Dip tau source: %s\n', cfg.dipTauPath));
appendText(runCtx.log_path, sprintf('FM tau source: %s\n', cfg.fmTauPath));

structuredRuns = resolveStructuredRuns(cfg);
structuredData = loadStructuredRuns(structuredRuns);
observableTbl = loadObservableDataset(cfg.observableDatasetPath);
dipTauTbl = loadTauTable(cfg.dipTauPath, 'tau_effective_seconds');
fmTauTbl = loadTauTable(cfg.fmTauPath, 'tau_effective_seconds');

[factorTbl, factorDetails] = computeFactorizations(structuredData, observableTbl);
localClockTbl = fitLocalClockTable(factorDetails);
amplitudeTbl = buildAmplitudeSampleTable(factorDetails, localClockTbl);

[collapseTbl, scenarioMap] = evaluateCollapseScenarios(factorDetails, dipTauTbl, fmTauTbl, localClockTbl, cfg);
windowTbl = buildWindowMetrics(factorTbl, factorDetails, dipTauTbl, fmTauTbl, localClockTbl, cfg);

factorPath = save_run_table(factorTbl, 'factorization_metrics.csv', runDir);
amplitudePath = save_run_table(amplitudeTbl, 'rank1_amplitude_curves.csv', runDir);
localClockPath = save_run_table(localClockTbl, 'local_clock_fit_parameters.csv', runDir);
collapsePath = save_run_table(collapseTbl, 'clock_collapse_metrics.csv', runDir);
windowPath = save_run_table(windowTbl, 'temperature_window_metrics.csv', runDir);

figAmpObs = makeAmplitudeObservableFigure(factorDetails, factorTbl, cfg);
ampObsPaths = save_run_figure(figAmpObs, 'amplitude_observable_alignment_around_26K', runDir);
close(figAmpObs);

figFactor = makeFactorizationMetricFigure(factorTbl, cfg);
factorFigurePaths = save_run_figure(figFactor, 'factorization_metrics_vs_Tp', runDir);
close(figFactor);

figRecon = makeReconstructionFigure(factorDetails, factorTbl, cfg);
reconPaths = save_run_figure(figRecon, 'reconstructed_vs_original_matrices_around_26K', runDir);
close(figRecon);

figDip = makeCollapseFigure(scenarioMap, 'tau_dip_native');
dipPaths = save_run_figure(figDip, 'clock_alignment_tau_dip', runDir);
close(figDip);

figFm = makeCollapseFigure(scenarioMap, 'tau_fm_native');
fmPaths = save_run_figure(figFm, 'clock_alignment_tau_FM', runDir);
close(figFm);

figLocal = makeCollapseFigure(scenarioMap, 'local_all');
localPaths = save_run_figure(figLocal, 'clock_alignment_local_clock', runDir);
close(figLocal);

figDiag = makeDiagnosticFigure(collapseTbl, windowTbl, cfg);
diagPaths = save_run_figure(figDiag, 'time_rescaling_diagnostics', runDir);
close(figDiag);

reportText = buildReportText(runDir, cfg, structuredRuns, factorTbl, localClockTbl, collapseTbl, windowTbl);
reportPath = save_run_report(reportText, 'tri_clock_consistency_report.md', runDir);
zipPath = createReviewZip(runDir, cfg.reviewZipName);

appendText(runCtx.log_path, sprintf('[%s] factor metrics: %s\n', stampNow(), factorPath));
appendText(runCtx.log_path, sprintf('[%s] amplitude curves: %s\n', stampNow(), amplitudePath));
appendText(runCtx.log_path, sprintf('[%s] local clock table: %s\n', stampNow(), localClockPath));
appendText(runCtx.log_path, sprintf('[%s] collapse metrics: %s\n', stampNow(), collapsePath));
appendText(runCtx.log_path, sprintf('[%s] window metrics: %s\n', stampNow(), windowPath));
appendText(runCtx.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(runCtx.log_path, sprintf('[%s] review zip: %s\n', stampNow(), zipPath));

appendText(runCtx.notes_path, sprintf('T_p = %.0f K rank-1 relative RMSE = %.4f\n', ...
    cfg.focusTp, lookupTableValue(factorTbl, cfg.focusTp, 'rank1_rmse_rel')));
appendText(runCtx.notes_path, sprintf('Overlap RMSE raw / tau_dip / tau_FM / local = %.4f / %.4f / %.4f / %.4f\n', ...
    lookupScenarioMetric(collapseTbl, "raw_overlap", 'mean_pairwise_rmse'), ...
    lookupScenarioMetric(collapseTbl, "tau_dip_overlap", 'mean_pairwise_rmse'), ...
    lookupScenarioMetric(collapseTbl, "tau_fm_overlap", 'mean_pairwise_rmse'), ...
    lookupScenarioMetric(collapseTbl, "local_overlap", 'mean_pairwise_rmse')));

fprintf('Aging TRI clock consistency analysis complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = string(runDir);
out.factor_table_path = string(factorPath);
out.amplitude_table_path = string(amplitudePath);
out.local_clock_path = string(localClockPath);
out.collapse_table_path = string(collapsePath);
out.window_table_path = string(windowPath);
out.report_path = string(reportPath);
out.zip_path = string(zipPath);
out.amplitude_figure = string(ampObsPaths.png);
out.factorization_figure = string(factorFigurePaths.png);
out.reconstruction_figure = string(reconPaths.png);
out.tau_dip_figure = string(dipPaths.png);
out.tau_fm_figure = string(fmPaths.png);
out.local_clock_figure = string(localPaths.png);
out.diagnostic_figure = string(diagPaths.png);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'TRI_clock_consistency_test');
cfg = setDefault(cfg, 'tpValues', [6 10 14 18 22 26 30 34]);
cfg = setDefault(cfg, 'focusTp', 26);
cfg = setDefault(cfg, 'selectedTpValues', [22 26 30]);
cfg = setDefault(cfg, 'windowSize', 3);
cfg = setDefault(cfg, 'structuredRunsRoot', fullfile(repoRoot, 'results', 'aging', 'runs'));
cfg = setDefault(cfg, 'observableDatasetPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_211204_aging_dataset_build', 'tables', 'aging_observable_dataset.csv'));
cfg = setDefault(cfg, 'dipTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_223709_aging_timescale_extraction', 'tables', 'tau_vs_Tp.csv'));
cfg = setDefault(cfg, 'fmTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_13_013634_aging_fm_timescale_analysis', 'tables', 'tau_FM_vs_Tp.csv'));
cfg = setDefault(cfg, 'pairGridCount', 160);
cfg = setDefault(cfg, 'displayGridCount', 240);
cfg = setDefault(cfg, 'minPairOverlapLog10', 0.15);
cfg = setDefault(cfg, 'minPairSamples', 16);
cfg = setDefault(cfg, 'minCurvesForStats', 3);
cfg = setDefault(cfg, 'reviewZipName', 'TRI_clock_consistency_bundle.zip');
end

function validateInputs(cfg)
assert(exist(cfg.structuredRunsRoot, 'dir') == 7, 'Structured-runs root not found: %s', cfg.structuredRunsRoot);
assert(exist(cfg.observableDatasetPath, 'file') == 2, 'Observable dataset not found: %s', cfg.observableDatasetPath);
assert(exist(cfg.dipTauPath, 'file') == 2, 'Dip tau table not found: %s', cfg.dipTauPath);
assert(exist(cfg.fmTauPath, 'file') == 2, 'FM tau table not found: %s', cfg.fmTauPath);
end

function ensureStandardSubdirs(runDir)
for folderName = ["figures", "tables", "reports", "review"]
    folderPath = fullfile(runDir, char(folderName));
    if exist(folderPath, 'dir') ~= 7
        mkdir(folderPath);
    end
end
end

function runs = resolveStructuredRuns(cfg)
entries = dir(fullfile(cfg.structuredRunsRoot, 'run_*_tp_*_structured_export'));
entries = entries([entries.isdir]);
names = string({entries.name});

runs = repmat(struct('Tp', NaN, 'run_id', "", 'run_dir', ""), numel(cfg.tpValues), 1);
for i = 1:numel(cfg.tpValues)
    tp = cfg.tpValues(i);
    token = sprintf('_tp_%g_structured_export', tp);
    matches = names(endsWith(names, token));
    assert(~isempty(matches), 'No structured export run found for T_p = %g K.', tp);
    matches = sort(matches);
    runId = matches(end);
    runs(i).Tp = tp;
    runs(i).run_id = runId;
    runs(i).run_dir = fullfile(cfg.structuredRunsRoot, char(runId));
end
end

function data = loadStructuredRuns(structuredRuns)
data = repmat(struct( ...
    'Tp', NaN, ...
    'run_id', "", ...
    'run_dir', "", ...
    'T_K', NaN(0, 1), ...
    'tw_seconds', NaN(0, 1), ...
    'wait_time', strings(0, 1), ...
    'M', NaN(0, 0)), numel(structuredRuns), 1);

for i = 1:numel(structuredRuns)
    runDir = structuredRuns(i).run_dir;
    tTbl = readtable(fullfile(runDir, 'tables', 'T_axis.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    twTbl = readtable(fullfile(runDir, 'tables', 'tw_axis.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    mapTbl = readtable(fullfile(runDir, 'tables', 'DeltaM_map.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');

    T = extractFirstNumericColumn(tTbl);
    tw = toNumericColumn(twTbl.tw_seconds);
    waitTime = string(twTbl.wait_time);
    M = tableToNumericArray(mapTbl);

    assert(size(M, 1) == numel(T), 'DeltaM rows do not match temperature axis in %s.', runDir);
    assert(size(M, 2) == numel(tw), 'DeltaM columns do not match waiting-time axis in %s.', runDir);

    data(i).Tp = structuredRuns(i).Tp;
    data(i).run_id = string(structuredRuns(i).run_id);
    data(i).run_dir = string(runDir);
    data(i).T_K = T(:);
    data(i).tw_seconds = tw(:);
    data(i).wait_time = waitTime(:);
    data(i).M = M;
end
end

function tbl = loadObservableDataset(datasetPath)
fid = fopen(datasetPath, 'r', 'n', 'UTF-8');
assert(fid ~= -1, 'Could not open observable dataset: %s', datasetPath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

headerLine = fgetl(fid);
headerLine = erase(string(headerLine), char(65279));
assert(contains(headerLine, 'Tp') && contains(headerLine, 'Dip_depth') && contains(headerLine, 'FM_abs'), ...
    'Unexpected observable dataset header: %s', headerLine);

raw = textscan(fid, '%q%q%q%q%q', 'Delimiter', ',', 'ReturnOnError', false);
tbl = table(raw{1}, raw{2}, raw{3}, raw{4}, raw{5}, ...
    'VariableNames', {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'});
tbl.Tp = toNumericColumn(tbl.Tp);
tbl.tw = toNumericColumn(tbl.tw);
tbl.Dip_depth = toNumericColumn(tbl.Dip_depth);
tbl.FM_abs = toNumericColumn(tbl.FM_abs);
tbl.source_run = string(tbl.source_run);
tbl = sortrows(tbl, {'Tp', 'tw'});
end

function namesOut = standardizeVariableNames(namesIn)
namesIn = string(namesIn);
namesOut = strings(size(namesIn));
for i = 1:numel(namesIn)
    name = erase(namesIn(i), '"');
    name = regexprep(name, '^x_', '');
    name = regexprep(name, '_+$', '');
    lowerName = lower(name);
    switch lowerName
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
        otherwise
            namesOut(i) = string(matlab.lang.makeValidName(char(name)));
    end
end
namesOut = cellstr(namesOut);
end

function tauTbl = loadTauTable(pathStr, tauColumn)
tauTbl = readtable(pathStr, 'TextType', 'string', 'VariableNamingRule', 'preserve');
for vn = [{'Tp'}, {tauColumn}]
    name = vn{1};
    if ismember(name, tauTbl.Properties.VariableNames)
        tauTbl.(name) = toNumericColumn(tauTbl.(name));
    end
end
if ismember('has_fm', tauTbl.Properties.VariableNames) && ~islogical(tauTbl.has_fm)
    tauTbl.has_fm = logical(toNumericColumn(tauTbl.has_fm));
end
tauTbl = sortrows(tauTbl, 'Tp');
end

function [factorTbl, details] = computeFactorizations(structuredData, observableTbl)
rows = repmat(initFactorizationRow(), numel(structuredData), 1);
details = repmat(initFactorizationDetail(), numel(structuredData), 1);

for i = 1:numel(structuredData)
    [rows(i), details(i)] = factorizeSingleTp(structuredData(i), observableTbl);
end

factorTbl = sortrows(struct2table(rows), 'Tp');
end

function row = initFactorizationRow()
row = struct( ...
    'Tp', NaN, ...
    'n_temperatures', NaN, ...
    'n_wait_times', NaN, ...
    'tw_values_seconds', "", ...
    'rank1_rmse_abs', NaN, ...
    'rank1_rmse_rel', NaN, ...
    'rank1_explained_variance', NaN, ...
    'sigma1_over_sigma2', NaN, ...
    'phi_peak_temperature_K', NaN, ...
    'amplitude_peak_tw_seconds', NaN, ...
    'amplitude_downturn_count', NaN, ...
    'amplitude_vs_dip_r', NaN, ...
    'amplitude_vs_dip_rmse', NaN, ...
    'amplitude_vs_fm_r', NaN, ...
    'amplitude_vs_fm_rmse', NaN, ...
    'source_run', "");
end

function detail = initFactorizationDetail()
detail = struct( ...
    'Tp', NaN, ...
    'run_id', "", ...
    'run_dir', "", ...
    'T_K', NaN(0, 1), ...
    'tw_seconds', NaN(0, 1), ...
    'wait_time', strings(0, 1), ...
    'M', NaN(0, 0), ...
    'phi', NaN(0, 1), ...
    'a_raw', NaN(0, 1), ...
    'a_norm', NaN(0, 1), ...
    'M_rank1', NaN(0, 0), ...
    'residual', NaN(0, 0), ...
    'dip_norm', NaN(0, 1), ...
    'fm_norm', NaN(0, 1));
end

function [row, detail] = factorizeSingleTp(data, observableTbl)
row = initFactorizationRow();
detail = initFactorizationDetail();

M = data.M;
[U, S, V] = svd(M, 'econ');
s = diag(S);
phi = U(:, 1);
a = S(1, 1) .* V(:, 1);

[dipAligned, fmAligned] = alignObservableSeries(data.Tp, data.tw_seconds, observableTbl);
if shouldFlipSign(a, dipAligned)
    phi = -phi;
    a = -a;
end

phiScale = max(abs(phi), [], 'omitnan');
if ~(isfinite(phiScale) && phiScale > 0)
    phiScale = 1;
end
phi = phi ./ phiScale;
a = a .* phiScale;

MRank1 = phi * a.';
residual = M - MRank1;
froNorm = norm(M, 'fro');

aNorm = normalizeByFiniteMaximum(a);
dipNorm = normalizeByFiniteMaximum(dipAligned);
fmNorm = normalizeByFiniteMaximum(fmAligned);

row.Tp = data.Tp;
row.n_temperatures = size(M, 1);
row.n_wait_times = size(M, 2);
row.tw_values_seconds = join(string(data.tw_seconds.'), ';');
row.rank1_rmse_abs = sqrt(mean((residual(:)) .^ 2, 'omitnan'));
row.rank1_rmse_rel = norm(residual, 'fro') ./ max(froNorm, eps);
row.rank1_explained_variance = s(1) .^ 2 ./ max(sum(s .^ 2, 'omitnan'), eps);
row.sigma1_over_sigma2 = ratioOrNan(getValue(s, 1), getValue(s, 2));
row.phi_peak_temperature_K = data.T_K(argmax(abs(phi)));
row.amplitude_peak_tw_seconds = data.tw_seconds(argmax(a));
row.amplitude_downturn_count = nnz(diff(a) < 0);
row.amplitude_vs_dip_r = pearsonCorrelation(aNorm, dipNorm);
row.amplitude_vs_dip_rmse = curveRmse(aNorm, dipNorm);
row.amplitude_vs_fm_r = pearsonCorrelation(aNorm, fmNorm);
row.amplitude_vs_fm_rmse = curveRmse(aNorm, fmNorm);
row.source_run = data.run_id;

detail.Tp = data.Tp;
detail.run_id = data.run_id;
detail.run_dir = data.run_dir;
detail.T_K = data.T_K;
detail.tw_seconds = data.tw_seconds;
detail.wait_time = data.wait_time;
detail.M = M;
detail.phi = phi;
detail.a_raw = a(:);
detail.a_norm = aNorm(:);
detail.M_rank1 = MRank1;
detail.residual = residual;
detail.dip_norm = dipNorm(:);
detail.fm_norm = fmNorm(:);
end

function [dipAligned, fmAligned] = alignObservableSeries(tp, twSeconds, observableTbl)
sub = observableTbl(abs(observableTbl.Tp - tp) < 1e-9, :);
dipAligned = nan(size(twSeconds));
fmAligned = nan(size(twSeconds));
for i = 1:numel(twSeconds)
    idx = find(abs(sub.tw - twSeconds(i)) < 1e-9, 1, 'first');
    if isempty(idx)
        continue;
    end
    dipAligned(i) = sub.Dip_depth(idx);
    fmAligned(i) = sub.FM_abs(idx);
end
end

function tf = shouldFlipSign(a, dipAligned)
tf = false;
pairR = pearsonCorrelation(a, dipAligned);
if isfinite(pairR)
    tf = pairR < 0;
elseif mean(a, 'omitnan') < 0
    tf = true;
end
end

function valuesNorm = normalizeByFiniteMaximum(values)
values = values(:);
valuesNorm = nan(size(values));
valid = isfinite(values);
if ~any(valid)
    return;
end
scale = max(abs(values(valid)));
if ~(isfinite(scale) && scale > 0)
    return;
end
valuesNorm(valid) = values(valid) ./ scale;
end

function tbl = fitLocalClockTable(details)
rows = repmat(initLocalClockRow(), numel(details), 1);
for i = 1:numel(details)
    rows(i) = fitLocalClockCurve(details(i));
end
tbl = sortrows(struct2table(rows), 'Tp');
end

function row = initLocalClockRow()
row = struct( ...
    'Tp', NaN, ...
    'n_points', NaN, ...
    'tw_min_seconds', NaN, ...
    'tw_max_seconds', NaN, ...
    'tau_half_seconds', NaN, ...
    'mu_log10_seconds', NaN, ...
    'sigma_decades', NaN, ...
    'rmse', NaN, ...
    'r2', NaN, ...
    'fit_status', "", ...
    'source_run', "");
end

function row = fitLocalClockCurve(detail)
row = initLocalClockRow();
row.Tp = detail.Tp;
row.n_points = numel(detail.tw_seconds);
row.tw_min_seconds = min(detail.tw_seconds, [], 'omitnan');
row.tw_max_seconds = max(detail.tw_seconds, [], 'omitnan');
row.source_run = detail.run_id;

x = log10(detail.tw_seconds(:));
y = detail.a_norm(:);
valid = isfinite(x) & isfinite(y) & detail.tw_seconds(:) > 0;
x = x(valid);
y = y(valid);

if numel(x) < 3
    row.fit_status = "insufficient_points";
    return;
end

yMin = min(y, [], 'omitnan');
yMax = max(y, [], 'omitnan');
delta = yMax - yMin;
if ~(isfinite(delta) && delta > 0)
    row.fit_status = "flat_curve";
    return;
end

target = yMin + 0.5 * delta;
[~, midIdx] = min(abs(y - target));
mu0 = x(midIdx);
sigma0 = max((max(x) - min(x)) / 4, 0.10);
opts = optimset('Display', 'off', 'MaxFunEvals', 5000, 'MaxIter', 5000);

objective = @(p) localClockObjective(p, x, y, yMin, delta);
try
    [pBest, ~, exitflag] = fminsearch(objective, [mu0, log(sigma0)], opts);
catch
    pBest = [mu0, log(sigma0)];
    exitflag = -1;
end

mu = pBest(1);
sigma = exp(pBest(2));
yHat = localClockModel([mu, log(sigma)], x, yMin, delta);

row.tau_half_seconds = 10 .^ mu;
row.mu_log10_seconds = mu;
row.sigma_decades = sigma;
row.rmse = sqrt(mean((y - yHat) .^ 2, 'omitnan'));
row.r2 = computeRsquared(y, yHat);
if exitflag <= 0 || ~(isfinite(mu) && isfinite(sigma) && sigma > 0)
    row.fit_status = "fit_failed";
else
    row.fit_status = "ok";
end
end

function value = localClockObjective(p, x, y, yMin, delta)
yHat = localClockModel(p, x, yMin, delta);
resid = y - yHat;
value = sum(resid .^ 2, 'omitnan') + 1e-3 * p(2) .^ 2;
end

function yHat = localClockModel(p, x, yMin, delta)
mu = p(1);
sigma = exp(p(2));
z = -(x - mu) ./ max(sigma, eps);
yHat = yMin + delta ./ (1 + exp(z));
end

function amplitudeTbl = buildAmplitudeSampleTable(details, localClockTbl)
rows = repmat(initAmplitudeRow(), 0, 1);
for i = 1:numel(details)
    clockRow = localClockTbl(localClockTbl.Tp == details(i).Tp, :);
    hValues = nan(size(details(i).tw_seconds));
    hLog = nan(size(details(i).tw_seconds));
    if ~isempty(clockRow) && isfinite(clockRow.mu_log10_seconds) && isfinite(clockRow.sigma_decades) && clockRow.sigma_decades > 0
        hLog = (log10(details(i).tw_seconds) - clockRow.mu_log10_seconds) ./ clockRow.sigma_decades;
        hValues = 10 .^ hLog;
    end

    for j = 1:numel(details(i).tw_seconds)
        row = initAmplitudeRow();
        row.Tp = details(i).Tp;
        row.tw_seconds = details(i).tw_seconds(j);
        row.wait_time = string(details(i).wait_time(j));
        row.a_raw = details(i).a_raw(j);
        row.a_norm = details(i).a_norm(j);
        row.dip_norm = getValue(details(i).dip_norm, j);
        row.fm_norm = getValue(details(i).fm_norm, j);
        row.local_clock_h = getValue(hValues, j);
        row.local_clock_log10_h = getValue(hLog, j);
        row.source_run = details(i).run_id;
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
end
amplitudeTbl = sortrows(struct2table(rows), {'Tp', 'tw_seconds'});
end

function row = initAmplitudeRow()
row = struct( ...
    'Tp', NaN, ...
    'tw_seconds', NaN, ...
    'wait_time', "", ...
    'a_raw', NaN, ...
    'a_norm', NaN, ...
    'dip_norm', NaN, ...
    'fm_norm', NaN, ...
    'local_clock_h', NaN, ...
    'local_clock_log10_h', NaN, ...
    'source_run', "");
end

function [collapseTbl, scenarioMap] = evaluateCollapseScenarios(details, dipTauTbl, fmTauTbl, localClockTbl, cfg)
allTp = [details.Tp];
dipTp = finiteTauTp(dipTauTbl, 'tau_effective_seconds', false);
fmTp = finiteTauTp(fmTauTbl, 'tau_effective_seconds', true);
localTp = finiteLocalTp(localClockTbl);
overlapTp = intersect(intersect(dipTp, fmTp), localTp);

scenarioDefs = {
    'raw_all', 'Raw waiting time (all T_p)', allTp, 'raw'
    'local_all', 'Local clock h(t_w) (all T_p)', localTp, 'local'
    'raw_overlap', 'Raw waiting time (overlap)', overlapTp, 'raw'
    'tau_dip_overlap', 't_w / tau_dip(T_p)', overlapTp, 'dip'
    'tau_fm_overlap', 't_w / tau_FM(T_p)', overlapTp, 'fm'
    'local_overlap', 'Local clock h(t_w) overlap', overlapTp, 'local'
    'tau_dip_native', 't_w / tau_dip(T_p) native', dipTp, 'dip'
    'tau_fm_native', 't_w / tau_FM(T_p) native', fmTp, 'fm'
    };

scenarioRows = repmat(initScenarioRow(), 0, 1);
scenarioMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

for i = 1:size(scenarioDefs, 1)
    tpValues = sort(unique(scenarioDefs{i, 3}));
    if numel(tpValues) < cfg.minCurvesForStats
        continue;
    end
    scenario = evaluateScenario(details, tpValues, scenarioDefs{i, 1}, scenarioDefs{i, 2}, scenarioDefs{i, 4}, dipTauTbl, fmTauTbl, localClockTbl, cfg);
    scenarioRows(end + 1, 1) = scenario.summaryRow; %#ok<AGROW>
    scenarioMap(char(scenario.name)) = scenario;
end

collapseTbl = sortrows(struct2table(scenarioRows), 'scenario_name');
end

function row = initScenarioRow()
row = struct( ...
    'scenario_name', "", ...
    'scenario_label', "", ...
    'transform_type', "", ...
    'tp_values', "", ...
    'n_curves', NaN, ...
    'mean_pairwise_rmse', NaN, ...
    'mean_profile_variance', NaN, ...
    'mean_pair_overlap_decades', NaN, ...
    'valid_pair_count', NaN, ...
    'valid_grid_fraction', NaN);
end

function scenario = evaluateScenario(details, tpValues, name, label, transformType, dipTauTbl, fmTauTbl, localClockTbl, cfg)
selected = details(ismember([details.Tp], tpValues));
selected = sortStructByTp(selected);

xCurves = cell(numel(selected), 1);
yCurves = cell(numel(selected), 1);
tpCurveValues = nan(numel(selected), 1);
pairRmse = nan(numel(selected), numel(selected));
pairOverlap = nan(numel(selected), numel(selected));

for i = 1:numel(selected)
    xCurves{i} = computeTransformX(selected(i), transformType, dipTauTbl, fmTauTbl, localClockTbl);
    yCurves{i} = selected(i).a_norm(:);
    tpCurveValues(i) = selected(i).Tp;
end

for i = 1:(numel(selected) - 1)
    for j = (i + 1):numel(selected)
        [pairRmse(i, j), pairOverlap(i, j)] = pairwiseCurveRmse(xCurves{i}, yCurves{i}, xCurves{j}, yCurves{j}, cfg);
        pairRmse(j, i) = pairRmse(i, j);
        pairOverlap(j, i) = pairOverlap(i, j);
    end
end

upperMask = triu(true(numel(selected)), 1);
validPairs = upperMask & isfinite(pairRmse);
profile = buildCollapseProfile(xCurves, yCurves, cfg);

row = initScenarioRow();
row.scenario_name = string(name);
row.scenario_label = string(label);
row.transform_type = string(transformType);
row.tp_values = join(string(tpCurveValues.'), ';');
row.n_curves = numel(selected);
row.mean_pairwise_rmse = mean(pairRmse(validPairs), 'omitnan');
row.mean_profile_variance = profile.mean_variance;
row.mean_pair_overlap_decades = mean(pairOverlap(validPairs), 'omitnan');
row.valid_pair_count = nnz(validPairs);
row.valid_grid_fraction = profile.valid_grid_fraction;

scenario = struct();
scenario.name = string(name);
scenario.label = string(label);
scenario.transform_type = string(transformType);
scenario.selected = selected;
scenario.tp_values = tpCurveValues(:);
scenario.x_curves = xCurves;
scenario.y_curves = yCurves;
scenario.profile = profile;
scenario.summaryRow = row;
end

function profile = buildCollapseProfile(xCurves, yCurves, cfg)
xMin = inf;
xMax = -inf;
for i = 1:numel(xCurves)
    x = xCurves{i};
    valid = isfinite(x) & isfinite(yCurves{i});
    if ~any(valid)
        continue;
    end
    xMin = min(xMin, min(x(valid)));
    xMax = max(xMax, max(x(valid)));
end

if ~(isfinite(xMin) && isfinite(xMax) && xMax > xMin)
    profile = emptyProfile();
    return;
end

xGrid = linspace(xMin, xMax, cfg.displayGridCount);
Y = nan(numel(xCurves), numel(xGrid));
for i = 1:numel(xCurves)
    x = xCurves{i};
    y = yCurves{i};
    valid = isfinite(x) & isfinite(y);
    if nnz(valid) < 2
        continue;
    end
    Y(i, :) = interp1(x(valid), y(valid), xGrid, 'linear', NaN);
end

curveCount = sum(isfinite(Y), 1);
meanCurve = mean(Y, 1, 'omitnan');
stdCurve = std(Y, 0, 1, 'omitnan');
varCurve = var(Y, 0, 1, 'omitnan');
validMask = curveCount >= cfg.minCurvesForStats & isfinite(varCurve);

profile = struct();
profile.x_grid_log10 = xGrid;
profile.z_grid = 10 .^ xGrid;
profile.mean_curve = meanCurve;
profile.std_curve = stdCurve;
profile.valid_stat_mask = validMask;
profile.mean_variance = mean(varCurve(validMask), 'omitnan');
profile.valid_grid_fraction = nnz(validMask) ./ max(numel(validMask), 1);
end

function profile = emptyProfile()
profile = struct();
profile.x_grid_log10 = NaN(0, 1);
profile.z_grid = NaN(0, 1);
profile.mean_curve = NaN(0, 1);
profile.std_curve = NaN(0, 1);
profile.valid_stat_mask = false(0, 1);
profile.mean_variance = NaN;
profile.valid_grid_fraction = NaN;
end

function x = computeTransformX(detail, transformType, dipTauTbl, fmTauTbl, localClockTbl)
tw = detail.tw_seconds(:);
switch string(transformType)
    case "raw"
        x = log10(tw);
    case "dip"
        tau = lookupTableValue(dipTauTbl, detail.Tp, 'tau_effective_seconds');
        x = log10(tw ./ tau);
    case "fm"
        tau = lookupTableValue(fmTauTbl, detail.Tp, 'tau_effective_seconds');
        x = log10(tw ./ tau);
    case "local"
        mu = lookupTableValue(localClockTbl, detail.Tp, 'mu_log10_seconds');
        sigma = lookupTableValue(localClockTbl, detail.Tp, 'sigma_decades');
        x = (log10(tw) - mu) ./ sigma;
    otherwise
        error('Unsupported transform type: %s', char(string(transformType)));
end
end

function [rmseVal, overlapVal] = pairwiseCurveRmse(x1, y1, x2, y2, cfg)
rmseVal = NaN;
overlapVal = NaN;

valid1 = isfinite(x1) & isfinite(y1);
valid2 = isfinite(x2) & isfinite(y2);
if nnz(valid1) < 2 || nnz(valid2) < 2
    return;
end

x1 = x1(valid1);
y1 = y1(valid1);
x2 = x2(valid2);
y2 = y2(valid2);

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

function windowTbl = buildWindowMetrics(factorTbl, details, dipTauTbl, fmTauTbl, localClockTbl, cfg)
rows = repmat(initWindowRow(), 0, 1);
rows = [rows; buildFactorizationWindows(factorTbl, cfg)]; %#ok<AGROW>

scenarioDefs = {
    'raw', 'Raw waiting time', unique([details.Tp]), 'raw'
    'tau_dip', 't_w / tau_dip(T_p)', finiteTauTp(dipTauTbl, 'tau_effective_seconds', false), 'dip'
    'tau_fm', 't_w / tau_FM(T_p)', finiteTauTp(fmTauTbl, 'tau_effective_seconds', true), 'fm'
    'local', 'Local clock h(t_w)', finiteLocalTp(localClockTbl), 'local'
    };

for i = 1:size(scenarioDefs, 1)
    tpValues = sort(unique(scenarioDefs{i, 3}));
    if numel(tpValues) < cfg.windowSize
        continue;
    end
    for startIdx = 1:(numel(tpValues) - cfg.windowSize + 1)
        windowTp = tpValues(startIdx:(startIdx + cfg.windowSize - 1));
        scenario = evaluateScenario(details, windowTp, scenarioDefs{i, 1}, scenarioDefs{i, 2}, scenarioDefs{i, 4}, dipTauTbl, fmTauTbl, localClockTbl, cfg);
        row = initWindowRow();
        row.scenario_name = string(scenarioDefs{i, 1});
        row.scenario_label = string(scenarioDefs{i, 2});
        row.tp_values = join(string(windowTp), ';');
        row.window_center_K = mean(windowTp);
        row.contains_tp26 = any(abs(windowTp - cfg.focusTp) < 1e-9);
        row.n_curves = numel(windowTp);
        row.mean_pairwise_rmse = scenario.summaryRow.mean_pairwise_rmse;
        row.mean_profile_variance = scenario.summaryRow.mean_profile_variance;
        row.mean_rank1_rmse_rel = mean(lookupMany(factorTbl, windowTp, 'rank1_rmse_rel'), 'omitnan');
        row.mean_rank1_explained_variance = mean(lookupMany(factorTbl, windowTp, 'rank1_explained_variance'), 'omitnan');
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
end

windowTbl = sortrows(struct2table(rows), {'scenario_name', 'window_center_K'});
end

function rows = buildFactorizationWindows(factorTbl, cfg)
tpValues = factorTbl.Tp(:).';
rows = repmat(initWindowRow(), 0, 1);
if numel(tpValues) < cfg.windowSize
    return;
end
for startIdx = 1:(numel(tpValues) - cfg.windowSize + 1)
    windowTp = tpValues(startIdx:(startIdx + cfg.windowSize - 1));
    row = initWindowRow();
    row.scenario_name = "factorization";
    row.scenario_label = "Rank-1 factorization";
    row.tp_values = join(string(windowTp), ';');
    row.window_center_K = mean(windowTp);
    row.contains_tp26 = any(abs(windowTp - cfg.focusTp) < 1e-9);
    row.n_curves = numel(windowTp);
    row.mean_pairwise_rmse = NaN;
    row.mean_profile_variance = NaN;
    row.mean_rank1_rmse_rel = mean(lookupMany(factorTbl, windowTp, 'rank1_rmse_rel'), 'omitnan');
    row.mean_rank1_explained_variance = mean(lookupMany(factorTbl, windowTp, 'rank1_explained_variance'), 'omitnan');
    rows(end + 1, 1) = row; %#ok<AGROW>
end
end

function row = initWindowRow()
row = struct( ...
    'scenario_name', "", ...
    'scenario_label', "", ...
    'tp_values', "", ...
    'window_center_K', NaN, ...
    'contains_tp26', false, ...
    'n_curves', NaN, ...
    'mean_pairwise_rmse', NaN, ...
    'mean_profile_variance', NaN, ...
    'mean_rank1_rmse_rel', NaN, ...
    'mean_rank1_explained_variance', NaN);
end

function fig = makeAmplitudeObservableFigure(details, factorTbl, cfg)
selected = details(ismember([details.Tp], cfg.selectedTpValues));
selected = sortStructByTp(selected);

fig = create_figure('Visible', 'off', 'Position', [2 2 21.5 7.5]);
tlo = tiledlayout(fig, 1, numel(selected), 'TileSpacing', 'compact', 'Padding', 'compact');

legendHandles = gobjects(0);
legendLabels = strings(0, 1);

for i = 1:numel(selected)
    ax = nexttile(tlo, i);
    hold(ax, 'on');

    hAmp = plot(ax, selected(i).tw_seconds, selected(i).a_norm, '-o', ...
        'Color', [0.10 0.10 0.10], 'MarkerFaceColor', [0.10 0.10 0.10], ...
        'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', 'rank-1 amplitude');
    if i == 1
        legendHandles(end + 1) = hAmp; %#ok<AGROW>
        legendLabels(end + 1) = "rank-1 amplitude"; %#ok<AGROW>
    end

    if any(isfinite(selected(i).dip_norm))
        hDip = plot(ax, selected(i).tw_seconds, selected(i).dip_norm, '-s', ...
            'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
            'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName', 'Dip_depth');
        if i == 1
            legendHandles(end + 1) = hDip; %#ok<AGROW>
            legendLabels(end + 1) = "Dip_depth"; %#ok<AGROW>
        end
    end

    if any(isfinite(selected(i).fm_norm))
        hFm = plot(ax, selected(i).tw_seconds, selected(i).fm_norm, '-d', ...
            'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
            'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName', 'FM_abs');
        if i == 1
            legendHandles(end + 1) = hFm; %#ok<AGROW>
            legendLabels(end + 1) = "FM_abs"; %#ok<AGROW>
        end
    end

    set(ax, 'XScale', 'log', 'YLim', [0 1.08]);
    xlabel(ax, 'Waiting time t_w (s)');
    ylabel(ax, 'Normalized amplitude');
    title(ax, sprintf('T_p = %.0f K', selected(i).Tp));
    grid(ax, 'on');
    set(ax, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');

    row = factorTbl(factorTbl.Tp == selected(i).Tp, :);
    text(ax, 0.05, 0.95, sprintf('rel RMSE = %.3f\nEV_1 = %.3f', ...
        row.rank1_rmse_rel, row.rank1_explained_variance), ...
        'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
        'FontSize', 8, 'BackgroundColor', 'w', 'Margin', 4);
end

if ~isempty(legendHandles)
    legend(nexttile(tlo, numel(selected)), legendHandles, cellstr(legendLabels), ...
        'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
end
title(tlo, 'Rank-1 amplitude compared with scalar observables around 26 K');
end

function fig = makeFactorizationMetricFigure(factorTbl, cfg)
fig = create_figure('Visible', 'off', 'Position', [2 2 22 7.2]);
tlo = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
plot(ax1, factorTbl.Tp, factorTbl.rank1_rmse_rel, '-o', ...
    'Color', [0.10 0.10 0.10], 'MarkerFaceColor', [0.10 0.10 0.10], ...
    'LineWidth', 2.2, 'MarkerSize', 6);
highlightTp(ax1, factorTbl.Tp, factorTbl.rank1_rmse_rel, cfg.focusTp);
xlabel(ax1, 'T_p (K)');
ylabel(ax1, 'Rank-1 relative RMSE');
title(ax1, 'Factorization error');
grid(ax1, 'on');
set(ax1, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');

ax2 = nexttile(tlo, 2);
plot(ax2, factorTbl.Tp, factorTbl.rank1_explained_variance, '-o', ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'LineWidth', 2.2, 'MarkerSize', 6);
highlightTp(ax2, factorTbl.Tp, factorTbl.rank1_explained_variance, cfg.focusTp);
xlabel(ax2, 'T_p (K)');
ylabel(ax2, 'Explained variance EV_1');
title(ax2, 'Rank-1 dominance');
grid(ax2, 'on');
set(ax2, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
ylim(ax2, paddedLimits([0; factorTbl.rank1_explained_variance]));

ax3 = nexttile(tlo, 3);
hold(ax3, 'on');
plot(ax3, factorTbl.Tp, factorTbl.amplitude_vs_dip_rmse, '-s', ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName', 'vs Dip_depth');
plot(ax3, factorTbl.Tp, factorTbl.amplitude_vs_fm_rmse, '-d', ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName', 'vs FM_abs');
highlightTp(ax3, factorTbl.Tp, factorTbl.amplitude_vs_dip_rmse, cfg.focusTp);
highlightTp(ax3, factorTbl.Tp, factorTbl.amplitude_vs_fm_rmse, cfg.focusTp);
xlabel(ax3, 'T_p (K)');
ylabel(ax3, 'RMSE between normalized curves');
title(ax3, 'Amplitude vs scalar observables');
grid(ax3, 'on');
set(ax3, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
legend(ax3, 'Location', 'best', 'Box', 'off');

title(tlo, 'Amplitude factorization metrics across temperature');
end

function fig = makeReconstructionFigure(details, factorTbl, cfg)
selected = details(ismember([details.Tp], cfg.selectedTpValues));
selected = sortStructByTp(selected);

mapLimit = 0;
resLimit = 0;
for i = 1:numel(selected)
    mapLimit = max(mapLimit, max(abs([selected(i).M(:); selected(i).M_rank1(:)]), [], 'omitnan'));
    resLimit = max(resLimit, max(abs(selected(i).residual(:)), [], 'omitnan'));
end
if ~(isfinite(mapLimit) && mapLimit > 0)
    mapLimit = 1;
end
if ~(isfinite(resLimit) && resLimit > 0)
    resLimit = mapLimit;
end

fig = create_figure('Visible', 'off', 'Position', [2 2 23.5 16.8]);
tlo = tiledlayout(fig, numel(selected), 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numel(selected)
    row = factorTbl(factorTbl.Tp == selected(i).Tp, :);
    matrices = {selected(i).M, selected(i).M_rank1, selected(i).residual};
    titles = { ...
        sprintf('Original, T_p = %.0f K', selected(i).Tp), ...
        sprintf('Rank-1, rel RMSE = %.3f', row.rank1_rmse_rel), ...
        sprintf('Residual, EV_1 = %.3f', row.rank1_explained_variance)};
    limits = {[ -mapLimit mapLimit ], [ -mapLimit mapLimit ], [ -resLimit resLimit ]};
    cbarLabels = {'\DeltaM', 'Rank-1 \DeltaM', 'Residual \DeltaM'};

    for j = 1:3
        ax = nexttile(tlo, (i - 1) * 3 + j);
        imagesc(ax, selected(i).T_K, log10(selected(i).tw_seconds), matrices{j}.');
        axis(ax, 'xy');
        colormap(ax, blue_white_red_map(256));
        clim(ax, limits{j});
        cb = colorbar(ax);
        cb.Label.String = cbarLabels{j};
        xlabel(ax, 'Temperature (K)');
        ylabel(ax, 'log_{10}(t_w / s)');
        title(ax, titles{j});
        set(ax, 'FontSize', 8, 'Box', 'on', 'LineWidth', 1);
    end
end

title(tlo, 'Original, reconstructed, and residual matrices around 26 K');
end

function fig = makeCollapseFigure(scenarioMap, scenarioName)
assert(isKey(scenarioMap, scenarioName), 'Missing collapse scenario: %s', scenarioName);
scenario = scenarioMap(scenarioName);
curveCount = numel(scenario.selected);

fig = create_figure('Visible', 'off', 'Position', [2 2 18.8 8.2]);
ax = axes(fig);
hold(ax, 'on');

if curveCount <= 6
    colors = lines(max(curveCount, 1));
    for i = 1:curveCount
        plot(ax, 10 .^ scenario.x_curves{i}, scenario.y_curves{i}, '-o', ...
            'Color', colors(i, :), 'MarkerFaceColor', colors(i, :), ...
            'LineWidth', 2.0, 'MarkerSize', 6, ...
            'DisplayName', sprintf('T_p = %.0f K', scenario.selected(i).Tp));
    end
    legend(ax, 'Location', 'eastoutside', 'Box', 'off');
else
    cmap = parula(256);
    cVals = scenario.tp_values(:);
    cMin = min(cVals);
    cMax = max(cVals);
    for i = 1:curveCount
        colorIdx = 1 + round((size(cmap, 1) - 1) * (cVals(i) - cMin) / max(cMax - cMin, eps));
        colorIdx = min(max(colorIdx, 1), size(cmap, 1));
        thisColor = cmap(colorIdx, :);
        plot(ax, 10 .^ scenario.x_curves{i}, scenario.y_curves{i}, '-', ...
            'Color', thisColor, 'LineWidth', 2.0, 'HandleVisibility', 'off');
    end
    colormap(ax, cmap);
    caxis(ax, [cMin cMax]);
    cb = colorbar(ax);
    cb.Label.String = 'T_p (K)';
end

drawBand(ax, scenario.profile);
set(ax, 'XScale', 'log', 'YLim', [0 1.08]);
grid(ax, 'on');
set(ax, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
xlabel(ax, scenarioXAxisLabel(scenario));
ylabel(ax, 'a(t_w) / max[a(t_w)]');
title(ax, sprintf('%s: RMSE = %.3f, variance = %.4f', ...
    scenario.label, scenario.summaryRow.mean_pairwise_rmse, scenario.summaryRow.mean_profile_variance));
end

function label = scenarioXAxisLabel(scenario)
switch string(scenario.transform_type)
    case "raw"
        label = 'Waiting time t_w (s)';
    case "dip"
        label = 't_w / \tau_{dip}(T_p)';
    case "fm"
        label = 't_w / \tau_{FM}(T_p)';
    case "local"
        label = 'Local clock h(t_w)';
    otherwise
        label = 'Scaled waiting time';
end
end

function fig = makeDiagnosticFigure(collapseTbl, windowTbl, cfg)
fig = create_figure('Visible', 'off', 'Position', [2 2 22.5 15.6]);
tlo = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

overlapNames = ["raw_overlap", "tau_dip_overlap", "tau_fm_overlap", "local_overlap"];
overlapLabels = {'raw', '\tau_{dip}', '\tau_{FM}', 'local'};
overlapTbl = collapseTbl(ismember(string(collapseTbl.scenario_name), overlapNames), :);
overlapTbl = reorderScenarios(overlapTbl, overlapNames);

ax1 = nexttile(tlo, 1);
bar(ax1, overlapTbl.mean_pairwise_rmse, 'FaceColor', [0.35 0.35 0.35]);
set(ax1, 'XTick', 1:numel(overlapLabels), 'XTickLabel', overlapLabels);
xlabel(ax1, 'Clock scenario');
ylabel(ax1, 'Mean pairwise RMSE');
title(ax1, 'Common-overlap RMSE');
grid(ax1, 'on');
set(ax1, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');

ax2 = nexttile(tlo, 2);
bar(ax2, overlapTbl.mean_profile_variance, 'FaceColor', [0.00 0.45 0.74]);
set(ax2, 'XTick', 1:numel(overlapLabels), 'XTickLabel', overlapLabels);
xlabel(ax2, 'Clock scenario');
ylabel(ax2, 'Mean profile variance');
title(ax2, 'Common-overlap variance');
grid(ax2, 'on');
set(ax2, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');

ax3 = nexttile(tlo, 3);
hold(ax3, 'on');
plotWindowSeries(ax3, windowTbl, "raw", 'raw', [0.20 0.20 0.20], 'o');
plotWindowSeries(ax3, windowTbl, "tau_dip", '\tau_{dip}', [0.00 0.45 0.74], 's');
plotWindowSeries(ax3, windowTbl, "tau_fm", '\tau_{FM}', [0.85 0.33 0.10], 'd');
plotWindowSeries(ax3, windowTbl, "local", 'local', [0.00 0.62 0.45], '^');
xlabel(ax3, 'Window center (K)');
ylabel(ax3, 'Mean pairwise RMSE');
title(ax3, sprintf('Sliding %d-point window collapse quality', cfg.windowSize));
grid(ax3, 'on');
set(ax3, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
legend(ax3, 'Location', 'best', 'Box', 'off');
highlightVerticalTp(ax3, cfg.focusTp);

ax4 = nexttile(tlo, 4);
sub = windowTbl(string(windowTbl.scenario_name) == "factorization", :);
plot(ax4, sub.window_center_K, sub.mean_rank1_rmse_rel, '-o', ...
    'Color', [0.10 0.10 0.10], 'MarkerFaceColor', [0.10 0.10 0.10], ...
    'LineWidth', 2.1, 'MarkerSize', 6, 'DisplayName', 'mean rank-1 relative RMSE');
hold(ax4, 'on');
plot(ax4, sub.window_center_K, 1 - sub.mean_rank1_explained_variance, '-s', ...
    'Color', [0.60 0.20 0.20], 'MarkerFaceColor', [0.60 0.20 0.20], ...
    'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName', '1 - mean EV_1');
xlabel(ax4, 'Window center (K)');
ylabel(ax4, 'Window metric');
title(ax4, 'Where factorization is strongest');
grid(ax4, 'on');
set(ax4, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
legend(ax4, 'Location', 'best', 'Box', 'off');
highlightVerticalTp(ax4, cfg.focusTp);

title(tlo, 'Time-rescaling diagnostics and temperature-window analysis');
end

function plotWindowSeries(ax, windowTbl, scenarioName, labelText, colorValue, markerSymbol)
sub = windowTbl(string(windowTbl.scenario_name) == string(scenarioName), :);
if isempty(sub)
    return;
end
plot(ax, sub.window_center_K, sub.mean_pairwise_rmse, ['-' markerSymbol], ...
    'Color', colorValue, 'MarkerFaceColor', colorValue, ...
    'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName', labelText);
end

function tbl = reorderScenarios(tbl, order)
if isempty(tbl)
    return;
end
key = nan(height(tbl), 1);
for i = 1:height(tbl)
    key(i) = find(order == string(tbl.scenario_name(i)), 1, 'first');
end
tbl.order_key = key;
tbl = sortrows(tbl, 'order_key');
tbl.order_key = [];
end

function txt = buildReportText(runDir, cfg, structuredRuns, factorTbl, localClockTbl, collapseTbl, windowTbl)
lines = strings(0, 1);
lines(end + 1) = '# TRI clock consistency test';
lines(end + 1) = '';
lines(end + 1) = sprintf('Generated: %s', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf('Run root: `%s`', string(runDir));
lines(end + 1) = '';
lines(end + 1) = '## Inputs';
for i = 1:numel(structuredRuns)
    lines(end + 1) = sprintf('- Structured map: `T_p = %.0f K` -> `%s`', structuredRuns(i).Tp, structuredRuns(i).run_id);
end
lines(end + 1) = sprintf('- Observable dataset: `%s`', cfg.observableDatasetPath);
lines(end + 1) = sprintf('- Dip timescale table: `%s`', cfg.dipTauPath);
lines(end + 1) = sprintf('- FM timescale table: `%s`', cfg.fmTauPath);
lines(end + 1) = '';
lines(end + 1) = '## Methods';
lines(end + 1) = '- Each structured `DeltaM(T, t_w)` map was factorized with the optimal rank-1 SVD reconstruction `M(T, t_w) ~= a(t_w) phi(T)` at fixed `T_p`.';
lines(end + 1) = '- The reconstruction error was measured by absolute RMSE, Frobenius-relative RMSE, and the leading explained-variance fraction `EV_1`.';
lines(end + 1) = '- The extracted amplitude `a(t_w)` was normalized by its finite maximum and compared directly to normalized `Dip_depth(t_w)` and `FM_abs(t_w)` from the observable dataset.';
lines(end + 1) = '- Cross-temperature clock consistency was then tested by plotting the normalized amplitude curves against raw `t_w`, `t_w / tau_dip(T_p)`, `t_w / tau_FM(T_p)`, and a fitted local clock `h(t_w)` derived from a monotonic logistic fit in `log10(t_w)`.';
lines(end + 1) = '- For each clock scenario, the main collapse scores are the mean interpolated pairwise RMSE and the mean gridded variance of the collapsed amplitude family.';
lines(end + 1) = '- Temperature-window analysis used sliding 3-temperature windows to test whether the strongest factorization and collapse behavior sits near the 26 K region.';
lines(end + 1) = '';

tp26Row = factorTbl(factorTbl.Tp == cfg.focusTp, :);
bestFactorRow = bestFiniteRow(factorTbl, 'rank1_rmse_rel', 'ascend');
bestEvRow = bestFiniteRow(factorTbl, 'rank1_explained_variance', 'descend');

lines(end + 1) = '## Amplitude factorization test';
if ~isempty(tp26Row)
    lines(end + 1) = sprintf('- At `T_p = %.0f K`, the rank-1 reconstruction gives relative RMSE `%.4f` with `EV_1 = %.4f`.', ...
        cfg.focusTp, tp26Row.rank1_rmse_rel, tp26Row.rank1_explained_variance);
    lines(end + 1) = sprintf('- At `T_p = %.0f K`, the rank-1 amplitude matches normalized `Dip_depth` with RMSE `%.4f` and normalized `FM_abs` with RMSE `%.4f`.', ...
        cfg.focusTp, tp26Row.amplitude_vs_dip_rmse, tp26Row.amplitude_vs_fm_rmse);
end
if ~isempty(bestFactorRow)
    lines(end + 1) = sprintf('- The smallest rank-1 relative RMSE in the sweep occurs at `T_p = %.0f K` with `%.4f`.', ...
        bestFactorRow.Tp, bestFactorRow.rank1_rmse_rel);
end
if ~isempty(bestEvRow)
    lines(end + 1) = sprintf('- The largest rank-1 explained variance occurs at `T_p = %.0f K` with `EV_1 = %.4f`.', ...
        bestEvRow.Tp, bestEvRow.rank1_explained_variance);
end
lines(end + 1) = sprintf('- Factorization verdict near 26 K: %s', factorizationVerdict(tp26Row));
lines(end + 1) = '';

rawOverlap = scenarioRow(collapseTbl, "raw_overlap");
dipOverlap = scenarioRow(collapseTbl, "tau_dip_overlap");
fmOverlap = scenarioRow(collapseTbl, "tau_fm_overlap");
localOverlap = scenarioRow(collapseTbl, "local_overlap");

lines(end + 1) = '## Waiting-time scaling consistency';
if ~isempty(rawOverlap)
    lines(end + 1) = sprintf('- On the common overlap set `%s K`, raw waiting time gives RMSE `%.4f` and variance `%.5f`.', ...
        rawOverlap.tp_values, rawOverlap.mean_pairwise_rmse, rawOverlap.mean_profile_variance);
end
if ~isempty(dipOverlap)
    lines(end + 1) = sprintf('- On the same overlap set, `tau_dip` gives RMSE `%.4f` and variance `%.5f`.', ...
        dipOverlap.mean_pairwise_rmse, dipOverlap.mean_profile_variance);
end
if ~isempty(fmOverlap)
    lines(end + 1) = sprintf('- On the same overlap set, `tau_FM` gives RMSE `%.4f` and variance `%.5f`.', ...
        fmOverlap.mean_pairwise_rmse, fmOverlap.mean_profile_variance);
end
if ~isempty(localOverlap)
    lines(end + 1) = sprintf('- On the same overlap set, the fitted local clock gives RMSE `%.4f` and variance `%.5f`.', ...
        localOverlap.mean_pairwise_rmse, localOverlap.mean_profile_variance);
end
if ~isempty(rawOverlap) && ~isempty(dipOverlap)
    lines(end + 1) = sprintf('- Relative to raw waiting time on the overlap set, `tau_dip` changes RMSE by `%.2f%%` and variance by `%.2f%%`.', ...
        percentReduction(rawOverlap.mean_pairwise_rmse, dipOverlap.mean_pairwise_rmse), ...
        percentReduction(rawOverlap.mean_profile_variance, dipOverlap.mean_profile_variance));
end
if ~isempty(rawOverlap) && ~isempty(fmOverlap)
    lines(end + 1) = sprintf('- Relative to raw waiting time on the overlap set, `tau_FM` changes RMSE by `%.2f%%` and variance by `%.2f%%`.', ...
        percentReduction(rawOverlap.mean_pairwise_rmse, fmOverlap.mean_pairwise_rmse), ...
        percentReduction(rawOverlap.mean_profile_variance, fmOverlap.mean_profile_variance));
end
if ~isempty(rawOverlap) && ~isempty(localOverlap)
    lines(end + 1) = sprintf('- Relative to raw waiting time on the overlap set, the local clock changes RMSE by `%.2f%%` and variance by `%.2f%%`.', ...
        percentReduction(rawOverlap.mean_pairwise_rmse, localOverlap.mean_pairwise_rmse), ...
        percentReduction(rawOverlap.mean_profile_variance, localOverlap.mean_profile_variance));
end
lines(end + 1) = sprintf('- Clock comparison verdict: %s', clockVerdict(rawOverlap, dipOverlap, fmOverlap, localOverlap));
lines(end + 1) = '';

bestFactorWindow = bestWindow(windowTbl, "factorization", 'mean_rank1_rmse_rel');
bestRawWindow = bestWindow(windowTbl, "raw", 'mean_pairwise_rmse');
bestDipWindow = bestWindow(windowTbl, "tau_dip", 'mean_pairwise_rmse');
bestFmWindow = bestWindow(windowTbl, "tau_fm", 'mean_pairwise_rmse');
bestLocalWindow = bestWindow(windowTbl, "local", 'mean_pairwise_rmse');

lines(end + 1) = '## Local clock and temperature-window analysis';
if ~isempty(bestLocalWindow)
    lines(end + 1) = sprintf('- The best local-clock window is `%s K` with RMSE `%.4f` and variance `%.5f`.', ...
        bestLocalWindow.tp_values, bestLocalWindow.mean_pairwise_rmse, bestLocalWindow.mean_profile_variance);
end
if ~isempty(bestFactorWindow)
    lines(end + 1) = sprintf('- The best factorization window is `%s K` with mean rank-1 relative RMSE `%.4f` and mean `EV_1 = %.4f`.', ...
        bestFactorWindow.tp_values, bestFactorWindow.mean_rank1_rmse_rel, bestFactorWindow.mean_rank1_explained_variance);
end
if ~isempty(bestRawWindow)
    lines(end + 1) = sprintf('- The best raw-time collapse window is `%s K`.', bestRawWindow.tp_values);
end
if ~isempty(bestDipWindow)
    lines(end + 1) = sprintf('- The best `tau_dip` window is `%s K`.', bestDipWindow.tp_values);
end
if ~isempty(bestFmWindow)
    lines(end + 1) = sprintf('- The best `tau_FM` window is `%s K`.', bestFmWindow.tp_values);
end
lines(end + 1) = sprintf('- Window verdict near 26 K: %s', windowVerdict(bestFactorWindow, bestDipWindow, bestFmWindow, bestLocalWindow, cfg.focusTp));
lines(end + 1) = '';

bestLocalFit = bestFiniteRow(localClockTbl, 'rmse', 'ascend');
if ~isempty(bestLocalFit)
    lines(end + 1) = '## Local-clock fit summary';
    lines(end + 1) = sprintf('- The smallest local-clock fit RMSE occurs at `T_p = %.0f K`, with `tau_half = %.3g s` and `sigma = %.3f` decades.', ...
        bestLocalFit.Tp, bestLocalFit.tau_half_seconds, bestLocalFit.sigma_decades);
    if ~isempty(tp26Row)
        tp26Clock = localClockTbl(localClockTbl.Tp == cfg.focusTp, :);
        if ~isempty(tp26Clock)
            lines(end + 1) = sprintf('- At `T_p = %.0f K`, the fitted local clock has `tau_half = %.3g s`, `sigma = %.3f` decades, and fit RMSE `%.4f`.', ...
                cfg.focusTp, tp26Clock.tau_half_seconds, tp26Clock.sigma_decades, tp26Clock.rmse);
        end
    end
    lines(end + 1) = '';
end

lines(end + 1) = '## Interpretation';
lines(end + 1) = sprintf('- Single-clock approximation near 26 K: %s', overallVerdict(tp26Row, rawOverlap, dipOverlap, fmOverlap, localOverlap));
lines(end + 1) = sprintf('- `tau_dip` or `tau_FM`: %s', tauComparisonVerdict(dipOverlap, fmOverlap));
lines(end + 1) = '- This is a consistency audit only. The results test whether the structured maps and scalar observables are compatible with TRI-like time rescaling; they do not establish TRI.';
lines(end + 1) = '';

lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- `amplitude_observable_alignment_around_26K`: 3 panels with 2 to 3 curves each, explicit legend, no colormap, no smoothing, used to compare the matrix-derived amplitude against scalar observables near the 26 K region.';
lines(end + 1) = '- `factorization_metrics_vs_Tp`: three simple metric panels, explicit line markers, no colormap, no smoothing, used to show where rank-1 behavior and observable alignment are strongest.';
lines(end + 1) = '- `reconstructed_vs_original_matrices_around_26K`: heatmaps of original, rank-1 reconstructed, and residual maps for 22, 26, and 30 K; a signed blue-white-red colormap is used because the residuals carry positive and negative structure around zero.';
lines(end + 1) = '- `clock_alignment_tau_dip` and `clock_alignment_tau_FM`: 6 curves each, explicit legends, no smoothing, used to inspect how well the amplitude curves collapse under the observable-derived clocks.';
lines(end + 1) = '- `clock_alignment_local_clock`: 8 curves, `parula` colormap plus a labeled `T_p` colorbar, no smoothing, used because the curve count exceeds 6.';
lines(end + 1) = '- `time_rescaling_diagnostics`: summary bars for overlap-set RMSE and variance plus sliding-window traces; no smoothing.';
lines(end + 1) = '';

lines(end + 1) = '## Outputs';
lines(end + 1) = '- `tables/factorization_metrics.csv`';
lines(end + 1) = '- `tables/rank1_amplitude_curves.csv`';
lines(end + 1) = '- `tables/local_clock_fit_parameters.csv`';
lines(end + 1) = '- `tables/clock_collapse_metrics.csv`';
lines(end + 1) = '- `tables/temperature_window_metrics.csv`';
lines(end + 1) = '- `figures/amplitude_observable_alignment_around_26K.png`';
lines(end + 1) = '- `figures/factorization_metrics_vs_Tp.png`';
lines(end + 1) = '- `figures/reconstructed_vs_original_matrices_around_26K.png`';
lines(end + 1) = '- `figures/clock_alignment_tau_dip.png`';
lines(end + 1) = '- `figures/clock_alignment_tau_FM.png`';
lines(end + 1) = '- `figures/clock_alignment_local_clock.png`';
lines(end + 1) = '- `figures/time_rescaling_diagnostics.png`';
lines(end + 1) = '- `reports/tri_clock_consistency_report.md`';
lines(end + 1) = '- `review/TRI_clock_consistency_bundle.zip`';

txt = strjoin(lines, newline);
end

function verdict = factorizationVerdict(tp26Row)
if isempty(tp26Row)
    verdict = 'insufficient data at 26 K.';
    return;
end
if tp26Row.rank1_explained_variance >= 0.9 && tp26Row.rank1_rmse_rel <= 0.25
    verdict = 'the map is close to separable there, so one amplitude coordinate captures most of the 26 K structure.';
elseif tp26Row.rank1_explained_variance >= 0.8
    verdict = 'the map is partially separable there, but structured residuals remain.';
else
    verdict = 'the map is not close to rank-1 there.';
end
end

function verdict = clockVerdict(rawOverlap, dipOverlap, fmOverlap, localOverlap)
pieces = strings(0, 1);
if ~isempty(dipOverlap) && ~isempty(fmOverlap)
    if dipOverlap.mean_pairwise_rmse < fmOverlap.mean_pairwise_rmse && dipOverlap.mean_profile_variance < fmOverlap.mean_profile_variance
        pieces(end + 1) = "on the common overlap, tau_dip outperforms tau_FM by both RMSE and variance"; %#ok<AGROW>
    elseif fmOverlap.mean_pairwise_rmse < dipOverlap.mean_pairwise_rmse && fmOverlap.mean_profile_variance < dipOverlap.mean_profile_variance
        pieces(end + 1) = "on the common overlap, tau_FM outperforms tau_dip by both RMSE and variance"; %#ok<AGROW>
    else
        pieces(end + 1) = "tau_dip and tau_FM split the overlap-set metrics"; %#ok<AGROW>
    end
end
if ~isempty(rawOverlap) && ~isempty(localOverlap)
    if localOverlap.mean_pairwise_rmse < rawOverlap.mean_pairwise_rmse && localOverlap.mean_profile_variance < rawOverlap.mean_profile_variance
        pieces(end + 1) = "the fitted local clock improves on raw waiting time"; %#ok<AGROW>
    else
        pieces(end + 1) = "the fitted local clock does not beat raw waiting time cleanly"; %#ok<AGROW>
    end
end
if isempty(pieces)
    verdict = 'no overlap-set clock comparison was possible.';
else
    verdict = strjoin(cellstr(pieces), '; ');
end
end

function verdict = windowVerdict(bestFactorWindow, bestDipWindow, bestFmWindow, bestLocalWindow, focusTp)
hits = strings(0, 1);
for item = {bestFactorWindow, bestDipWindow, bestFmWindow, bestLocalWindow}
    row = item{1};
    if isempty(row)
        continue;
    end
    if row.contains_tp26
        hits(end + 1) = row.scenario_name; %#ok<AGROW>
    end
end
if isempty(hits)
    verdict = sprintf('none of the best windows explicitly contain %.0f K.', focusTp);
else
    verdict = sprintf('the best windows that include %.0f K appear in: `%s`.', focusTp, join(hits, ', '));
end
end

function verdict = overallVerdict(tp26Row, rawOverlap, dipOverlap, fmOverlap, localOverlap)
if isempty(tp26Row)
    verdict = 'not assessable because the 26 K map is missing.';
    return;
end

factorStrong = tp26Row.rank1_explained_variance >= 0.9 && tp26Row.rank1_rmse_rel <= 0.25;
dipImproves = improvesVsRaw(rawOverlap, dipOverlap);
fmImproves = improvesVsRaw(rawOverlap, fmOverlap);
localImproves = improvesVsRaw(rawOverlap, localOverlap);

if factorStrong && (dipImproves || localImproves)
    verdict = 'the data are consistent with a partial one-clock description near 26 K: the map is close to rank-1 there, and at least one reparametrization improves the amplitude collapse.';
elseif factorStrong
    verdict = 'a single amplitude mode captures much of the 26 K map, but the observable-derived clocks do not produce a comparably strong cross-temperature collapse.';
else
    verdict = 'the combination of factorization and collapse metrics does not support a strong single-clock approximation near 26 K.';
end

if fmImproves && ~dipImproves
    verdict = sprintf('%s In that limited sense, the FM-derived clock looks more compatible than the dip-derived one.', verdict);
elseif dipImproves && ~fmImproves
    verdict = sprintf('%s In that limited sense, the dip-derived clock looks more compatible than the FM-derived one.', verdict);
end
end

function verdict = tauComparisonVerdict(dipOverlap, fmOverlap)
if isempty(dipOverlap) || isempty(fmOverlap)
    verdict = 'the overlap set is incomplete, so no fair tau_dip versus tau_FM comparison is available.';
    return;
end

if dipOverlap.mean_pairwise_rmse < fmOverlap.mean_pairwise_rmse && dipOverlap.mean_profile_variance < fmOverlap.mean_profile_variance
    verdict = sprintf('`tau_dip` explains the amplitude scaling better on the fair overlap set (RMSE %.4f vs %.4f; variance %.5f vs %.5f).', ...
        dipOverlap.mean_pairwise_rmse, fmOverlap.mean_pairwise_rmse, ...
        dipOverlap.mean_profile_variance, fmOverlap.mean_profile_variance);
elseif fmOverlap.mean_pairwise_rmse < dipOverlap.mean_pairwise_rmse && fmOverlap.mean_profile_variance < dipOverlap.mean_profile_variance
    verdict = sprintf('`tau_FM` explains the amplitude scaling better on the fair overlap set (RMSE %.4f vs %.4f; variance %.5f vs %.5f).', ...
        fmOverlap.mean_pairwise_rmse, dipOverlap.mean_pairwise_rmse, ...
        fmOverlap.mean_profile_variance, dipOverlap.mean_profile_variance);
else
    verdict = sprintf('neither observable-derived clock dominates cleanly on the fair overlap set (tau_dip: RMSE %.4f, variance %.5f; tau_FM: RMSE %.4f, variance %.5f).', ...
        dipOverlap.mean_pairwise_rmse, dipOverlap.mean_profile_variance, ...
        fmOverlap.mean_pairwise_rmse, fmOverlap.mean_profile_variance);
end
end

function tf = improvesVsRaw(rawRow, scenarioRowIn)
tf = false;
if isempty(rawRow) || isempty(scenarioRowIn)
    return;
end
tf = scenarioRowIn.mean_pairwise_rmse < rawRow.mean_pairwise_rmse && ...
    scenarioRowIn.mean_profile_variance < rawRow.mean_profile_variance;
end

function row = scenarioRow(tbl, scenarioName)
row = [];
if isempty(tbl)
    return;
end
idx = find(string(tbl.scenario_name) == string(scenarioName), 1, 'first');
if isempty(idx)
    return;
end
row = tbl(idx, :);
end

function row = bestWindow(windowTbl, scenarioName, fieldName)
row = [];
sub = windowTbl(string(windowTbl.scenario_name) == string(scenarioName), :);
if isempty(sub)
    return;
end
valid = isfinite(sub.(fieldName));
if ~any(valid)
    return;
end
sub = sub(valid, :);
sub = sortrows(sub, fieldName, 'ascend');
row = sub(1, :);
end

function row = bestFiniteRow(tbl, fieldName, direction)
row = [];
if isempty(tbl)
    return;
end
valid = isfinite(tbl.(fieldName));
if ~any(valid)
    return;
end
sub = tbl(valid, :);
sub = sortrows(sub, fieldName, direction);
row = sub(1, :);
end

function drawBand(ax, profile)
valid = profile.valid_stat_mask & isfinite(profile.mean_curve) & isfinite(profile.std_curve);
if nnz(valid) < 2
    return;
end
z = profile.z_grid(valid);
yMean = profile.mean_curve(valid);
yStd = profile.std_curve(valid);
fill(ax, [z, fliplr(z)], [yMean - yStd, fliplr(yMean + yStd)], ...
    [0.85 0.85 0.85], 'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
plot(ax, z, yMean, '-', 'Color', [0.05 0.05 0.05], 'LineWidth', 2.4, ...
    'DisplayName', 'Mean +/- 1 sigma');
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
zipInputs = collectRelativeOutputFiles(runDir);
assert(~isempty(zipInputs), 'No output files found to package.');
zip(zipPath, cellstr(zipInputs), runDir);
end

function files = collectRelativeOutputFiles(runDir)
targetDirs = {'figures', 'tables', 'reports'};
files = strings(0, 1);
for i = 1:numel(targetDirs)
    thisDir = fullfile(runDir, targetDirs{i});
    if exist(thisDir, 'dir') ~= 7
        continue;
    end
    files = [files; collectFilesRecursively(thisDir, runDir)]; %#ok<AGROW>
end
files(end + 1, 1) = "run_manifest.json";
files(end + 1, 1) = "config_snapshot.m";
files(end + 1, 1) = "log.txt";
files(end + 1, 1) = "run_notes.txt";
end

function files = collectFilesRecursively(targetDir, rootDir)
entries = dir(targetDir);
files = strings(0, 1);
for i = 1:numel(entries)
    name = string(entries(i).name);
    if name == "." || name == ".."
        continue;
    end
    fullPath = fullfile(entries(i).folder, char(name));
    if entries(i).isdir
        files = [files; collectFilesRecursively(fullPath, rootDir)]; %#ok<AGROW>
    else
        files(end + 1, 1) = string(relativePathWithinRun(fullPath, rootDir)); %#ok<AGROW>
    end
end
end

function relPath = relativePathWithinRun(fullPath, rootDir)
fullPath = char(string(fullPath));
rootDir = char(string(rootDir));
if startsWith(lower(fullPath), lower(rootDir))
    relPath = fullPath(numel(rootDir) + 2:end);
else
    relPath = fullPath;
end
end

function values = extractFirstNumericColumn(tbl)
values = tbl{:, 1};
values = toNumericColumn(values);
end

function values = tableToNumericArray(tbl)
values = table2array(tbl);
if isnumeric(values)
    return;
end
values = str2double(string(values));
end

function values = toNumericColumn(valuesIn)
if isnumeric(valuesIn)
    values = double(valuesIn);
elseif islogical(valuesIn)
    values = double(valuesIn);
else
    values = str2double(erase(string(valuesIn), '"'));
end
end

function tpValues = finiteTauTp(tauTbl, tauColumn, requireHasFm)
mask = isfinite(tauTbl.(tauColumn)) & tauTbl.(tauColumn) > 0;
if requireHasFm && ismember('has_fm', tauTbl.Properties.VariableNames)
    mask = mask & tauTbl.has_fm;
end
tpValues = sort(tauTbl.Tp(mask));
end

function tpValues = finiteLocalTp(localClockTbl)
mask = isfinite(localClockTbl.mu_log10_seconds) & isfinite(localClockTbl.sigma_decades) & localClockTbl.sigma_decades > 0;
tpValues = sort(localClockTbl.Tp(mask));
end

function value = lookupTableValue(tbl, tp, fieldName)
value = NaN;
if isempty(tbl)
    return;
end
idx = find(abs(tbl.Tp - tp) < 1e-9, 1, 'first');
if isempty(idx)
    return;
end
value = tbl.(fieldName)(idx);
end

function values = lookupMany(tbl, tpValues, fieldName)
values = nan(numel(tpValues), 1);
for i = 1:numel(tpValues)
    values(i) = lookupTableValue(tbl, tpValues(i), fieldName);
end
end

function value = lookupScenarioMetric(tbl, scenarioName, fieldName)
row = scenarioRow(tbl, scenarioName);
if isempty(row)
    value = NaN;
else
    value = row.(fieldName);
end
end

function r = pearsonCorrelation(x, y)
x = x(:);
y = y(:);
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if numel(x) < 2
    r = NaN;
    return;
end
x = x - mean(x, 'omitnan');
y = y - mean(y, 'omitnan');
denom = sqrt(sum(x .^ 2) * sum(y .^ 2));
if denom <= eps
    r = NaN;
else
    r = sum(x .* y) ./ denom;
end
end

function value = curveRmse(x, y)
valid = isfinite(x) & isfinite(y);
if nnz(valid) < 2
    value = NaN;
    return;
end
value = sqrt(mean((x(valid) - y(valid)) .^ 2, 'omitnan'));
end

function value = computeRsquared(y, yHat)
valid = isfinite(y) & isfinite(yHat);
if nnz(valid) < 2
    value = NaN;
    return;
end
ssRes = sum((y(valid) - yHat(valid)) .^ 2, 'omitnan');
ssTot = sum((y(valid) - mean(y(valid), 'omitnan')) .^ 2, 'omitnan');
if ssTot <= eps
    value = NaN;
else
    value = 1 - ssRes ./ ssTot;
end
end

function idx = argmax(values)
[~, idx] = max(values, [], 'omitnan');
if isempty(idx) || ~isfinite(idx)
    idx = 1;
end
end

function value = ratioOrNan(a, b)
if isfinite(a) && isfinite(b) && abs(b) > eps
    value = a ./ b;
else
    value = NaN;
end
end

function value = getValue(values, idx)
if idx <= numel(values)
    value = values(idx);
else
    value = NaN;
end
end

function sorted = sortStructByTp(values)
[~, order] = sort([values.Tp]);
sorted = values(order);
end

function lims = paddedLimits(values)
values = values(isfinite(values));
if isempty(values)
    lims = [0 1];
    return;
end
vMin = min(values);
vMax = max(values);
if abs(vMax - vMin) < 1e-12
    pad = max(abs(vMax), 1) * 0.10;
else
    pad = 0.08 * (vMax - vMin);
end
lims = [vMin - pad, vMax + pad];
end

function pct = percentReduction(beforeVal, afterVal)
if ~(isfinite(beforeVal) && isfinite(afterVal))
    pct = NaN;
    return;
end
pct = 100 * (1 - afterVal ./ max(beforeVal, eps));
end

function highlightTp(ax, x, y, targetTp)
mask = abs(x - targetTp) < 1e-9 & isfinite(y);
if any(mask)
    plot(ax, x(mask), y(mask), 'o', ...
        'Color', [0.20 0.20 0.20], 'MarkerFaceColor', [1.0 0.85 0.20], ...
        'MarkerSize', 9, 'LineWidth', 1.4, 'HandleVisibility', 'off');
end
end

function highlightVerticalTp(ax, targetTp)
xline(ax, targetTp, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.3, 'HandleVisibility', 'off');
end

function cmap = blue_white_red_map(n)
if nargin < 1
    n = 256;
end
n = max(2, round(n));
half = floor(n / 2);
top = [linspace(0, 1, half)', linspace(0.2, 1, half)', ones(half, 1)];
bottom = [ones(n - half, 1), linspace(1, 0.2, n - half)', linspace(1, 0, n - half)'];
cmap = [top; flipud(bottom)];
if size(cmap, 1) > n
    cmap = cmap(1:n, :);
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

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
