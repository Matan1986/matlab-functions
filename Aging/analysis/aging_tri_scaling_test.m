function out = aging_tri_scaling_test(cfg)
% aging_tri_scaling_test
% Standalone TRI-style scaling audit for Aging structured DeltaM maps.

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
cfgRun.datasetName = 'aging_tri_scaling_test';
cfgRun.dip_tau_source = char(string(cfg.dipTauPath));
cfgRun.fm_tau_source = char(string(cfg.fmTauPath));
runCtx = createRunContext('aging', cfgRun);
runDir = runCtx.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging TRI scaling test run root:\n%s\n', runDir);
appendText(runCtx.log_path, sprintf('[%s] started\n', stampNow()));
appendText(runCtx.log_path, sprintf('Dip tau source: %s\n', cfg.dipTauPath));
appendText(runCtx.log_path, sprintf('FM tau source: %s\n', cfg.fmTauPath));

existingAnalyses = getExistingAnalysisSummary(cfg);
structuredRuns = resolveStructuredRuns(cfg);
rawData = loadStructuredRuns(structuredRuns);
commonT = buildCommonTemperatureGrid(rawData, cfg);
data = alignStructuredRuns(rawData, commonT);

dipTauTbl = loadTauTable(cfg.dipTauPath, 'tau_effective_seconds');
fmTauTbl = loadTauTable(cfg.fmTauPath, 'tau_effective_seconds');

[withinTbl, rankTbl, modeAggTbl, modeDetailTbl] = computePerTpMetrics(data);
[scenarioTbl, perTpTbl, perZTbl, scenarioMap] = computeCrossTemperatureMetrics(data, dipTauTbl, fmTauTbl, cfg);
summaryTbl = buildSummaryTable(withinTbl, rankTbl, modeAggTbl, dipTauTbl, fmTauTbl, perTpTbl, cfg);

summaryPath = save_run_table(summaryTbl, 'tri_scaling_summary.csv', runDir);
withinPath = save_run_table(withinTbl, 'waiting_time_collapse_metrics.csv', runDir);
rankPath = save_run_table(rankTbl, 'rank_structure_metrics.csv', runDir);
modeAggPath = save_run_table(modeAggTbl, 'mode_stability_metrics.csv', runDir);
modeDetailPath = save_run_table(modeDetailTbl, 'mode_stability_details.csv', runDir);
scenarioPath = save_run_table(scenarioTbl, 'cross_temperature_scenario_metrics.csv', runDir);
perTpPath = save_run_table(perTpTbl, 'cross_temperature_per_tp_quality.csv', runDir);
perZPath = save_run_table(perZTbl, 'cross_temperature_per_z_metrics.csv', runDir);

figSelected = makeSelectedTpOverlayFigure(data, cfg);
figSelectedPaths = save_run_figure(figSelected, 'within_tp_normalized_profiles_around_26K', runDir);
close(figSelected);

figWithin = makeWithinTpMetricFigure(withinTbl);
figWithinPaths = save_run_figure(figWithin, 'waiting_time_collapse_metrics_vs_Tp', runDir);
close(figWithin);

figRank = makeRankStructureFigure(rankTbl);
figRankPaths = save_run_figure(figRank, 'svd_spectrum_vs_temperature', runDir);
close(figRank);

figMode = makeModeStabilityFigure(modeAggTbl);
figModePaths = save_run_figure(figMode, 'mode_stability_vs_Tp', runDir);
close(figMode);

figScenario = makeScenarioMetricFigure(scenarioTbl, perTpTbl);
figScenarioPaths = save_run_figure(figScenario, 'tri_cross_temperature_metrics', runDir);
close(figScenario);

figDip = makeCrossTemperatureCollapseFigure(scenarioMap('tau_dip_native'), cfg);
figDipPaths = save_run_figure(figDip, 'tri_cross_temperature_collapse_tau_dip', runDir);
close(figDip);

figFm = makeCrossTemperatureCollapseFigure(scenarioMap('tau_fm_native'), cfg);
figFmPaths = save_run_figure(figFm, 'tri_cross_temperature_collapse_tau_fm', runDir);
close(figFm);

reportText = buildReportText(runDir, existingAnalyses, structuredRuns, dipTauTbl, fmTauTbl, ...
    withinTbl, rankTbl, modeAggTbl, scenarioTbl, perTpTbl, cfg);
reportPath = save_run_report(reportText, 'tri_scaling_test_report.md', runDir);

zipPath = createReviewZip(runDir, cfg.reviewZipName);
appendRunNotes(runCtx.notes_path, withinTbl, rankTbl, modeAggTbl, scenarioTbl);

appendText(runCtx.log_path, sprintf('[%s] summary table: %s\n', stampNow(), summaryPath));
appendText(runCtx.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(runCtx.log_path, sprintf('[%s] review zip: %s\n', stampNow(), zipPath));

fprintf('Aging TRI scaling test complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Summary table: %s\n', summaryPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = string(runDir);
out.report_path = string(reportPath);
out.zip_path = string(zipPath);
out.summary_table = string(summaryPath);
out.within_tp_table = string(withinPath);
out.rank_table = string(rankPath);
out.mode_table = string(modeAggPath);
out.mode_detail_table = string(modeDetailPath);
out.scenario_table = string(scenarioPath);
out.per_tp_table = string(perTpPath);
out.per_z_table = string(perZPath);
out.selected_overlay_figure = string(figSelectedPaths.png);
out.within_metric_figure = string(figWithinPaths.png);
out.rank_figure = string(figRankPaths.png);
out.mode_figure = string(figModePaths.png);
out.scenario_figure = string(figScenarioPaths.png);
out.tau_dip_figure = string(figDipPaths.png);
out.tau_fm_figure = string(figFmPaths.png);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'tri_scaling_test');
cfg = setDefault(cfg, 'tpValues', [6 10 14 18 22 26 30 34]);
cfg = setDefault(cfg, 'selectedTpOverlays', [22 26 30]);
cfg = setDefault(cfg, 'dipTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_223709_aging_timescale_extraction', 'tables', 'tau_vs_Tp.csv'));
cfg = setDefault(cfg, 'fmTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_13_013634_aging_fm_timescale_analysis', 'tables', 'tau_FM_vs_Tp.csv'));
cfg = setDefault(cfg, 'structuredRunsRoot', fullfile(repoRoot, 'results', 'aging', 'runs'));
cfg = setDefault(cfg, 'commonTemperatureCount', 400);
cfg = setDefault(cfg, 'zGridCount', 25);
cfg = setDefault(cfg, 'representativeSliceFractions', [0.15 0.50 0.85]);
cfg = setDefault(cfg, 'reviewZipName', 'TRI_scaling_test_bundle.zip');
cfg = setDefault(cfg, 'crossTemperatureMinTp', 3);
end

function validateInputs(cfg)
assert(exist(cfg.dipTauPath, 'file') == 2, 'Dip tau table not found: %s', cfg.dipTauPath);
assert(exist(cfg.fmTauPath, 'file') == 2, 'FM tau table not found: %s', cfg.fmTauPath);
assert(exist(cfg.structuredRunsRoot, 'dir') == 7, 'Structured-runs root not found: %s', cfg.structuredRunsRoot);
end

function ensureStandardSubdirs(runDir)
for folderName = ["figures", "tables", "reports", "review"]
    folderPath = fullfile(runDir, char(folderName));
    if exist(folderPath, 'dir') ~= 7
        mkdir(folderPath);
    end
end
end

function existing = getExistingAnalysisSummary(cfg)
existing = struct([]);

existing(end + 1).run_id = "run_2026_03_11_082451_aging_shape_collapse_analysis"; %#ok<AGROW>
existing(end).scope = "Structured-profile rank-1 audit and T_p=26 K collapse check.";
existing(end).gap = "Did not test cross-temperature collapse under extracted tau_dip or tau_FM.";

existing(end + 1).run_id = "run_2026_03_12_233710_aging_time_rescaling_collapse"; %#ok<AGROW>
existing(end).scope = "Strong scalar Dip_depth collapse under an optimized free tau(T_p).";
existing(end).gap = "Used Dip_depth only, not full DeltaM(T, t_w) maps, and the tau values were free-fit collapse shifts rather than the extracted tau_dip / tau_FM clocks.";

existing(end + 1).run_id = "run_2026_03_12_223709_aging_timescale_extraction"; %#ok<AGROW>
existing(end).scope = sprintf('Extracted tau_dip(T_p) from `%s`.', cfg.dipTauPath);
existing(end).gap = "Did not test full-profile collapse under the extracted dip clock.";

existing(end + 1).run_id = "run_2026_03_13_013634_aging_fm_timescale_analysis"; %#ok<AGROW>
existing(end).scope = sprintf('Extracted tau_FM(T_p) from `%s` and tested FM_abs collapse.', cfg.fmTauPath);
existing(end).gap = "Did not test full DeltaM(T, t_w) profile collapse or rank/mode stability under TRI-style rescaling.";

existing(end + 1).run_id = "run_2026_03_13_005134_aging_fm_using_dip_clock"; %#ok<AGROW>
existing(end).scope = "Transferred the Dip-derived clock to FM_abs and found poor FM collapse.";
existing(end).gap = "Still a scalar-observable transfer test, not a structured DeltaM-map TRI audit.";
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

function rawData = loadStructuredRuns(structuredRuns)
rawData = repmat(struct( ...
    'Tp', NaN, ...
    'run_id', "", ...
    'run_dir', "", ...
    'T_raw', [], ...
    'tw_seconds', [], ...
    'wait_time', strings(0, 1), ...
    'M_raw', []), numel(structuredRuns), 1);

for i = 1:numel(structuredRuns)
    runDir = structuredRuns(i).run_dir;
    tTbl = readtable(fullfile(runDir, 'tables', 'T_axis.csv'));
    twTbl = readtable(fullfile(runDir, 'tables', 'tw_axis.csv'));
    mapTbl = readtable(fullfile(runDir, 'tables', 'DeltaM_map.csv'));

    T = extractFirstNumericColumn(tTbl);
    tw = twTbl.tw_seconds;
    waitTime = string(twTbl.wait_time);
    M = table2array(mapTbl);

    assert(size(M, 1) == numel(T), 'DeltaM rows do not match T axis in %s.', runDir);
    assert(size(M, 2) == numel(tw), 'DeltaM columns do not match tw axis in %s.', runDir);

    rawData(i).Tp = structuredRuns(i).Tp;
    rawData(i).run_id = string(structuredRuns(i).run_id);
    rawData(i).run_dir = string(runDir);
    rawData(i).T_raw = T(:);
    rawData(i).tw_seconds = tw(:);
    rawData(i).wait_time = waitTime(:);
    rawData(i).M_raw = M;
end
end

function commonT = buildCommonTemperatureGrid(rawData, cfg)
tMin = -inf;
tMax = inf;
for i = 1:numel(rawData)
    tMin = max(tMin, min(rawData(i).T_raw, [], 'omitnan'));
    tMax = min(tMax, max(rawData(i).T_raw, [], 'omitnan'));
end
assert(isfinite(tMin) && isfinite(tMax) && tMax > tMin, ...
    'Could not determine a common temperature interval for structured runs.');
commonT = linspace(tMin, tMax, cfg.commonTemperatureCount).';
end

function data = alignStructuredRuns(rawData, commonT)
data = repmat(struct( ...
    'Tp', NaN, ...
    'run_id', "", ...
    'run_dir', "", ...
    'T_common', [], ...
    'tw_seconds', [], ...
    'wait_time', strings(0, 1), ...
    'M_common', [], ...
    'M_norm', [], ...
    'profile_amplitudes', [], ...
    'normalization_reference_index', NaN), numel(rawData), 1);

for i = 1:numel(rawData)
    MCommon = interp1(rawData(i).T_raw, rawData(i).M_raw, commonT, 'linear');
    [MNorm, amplitudes, refIdx] = normalizeProfileMatrix(MCommon);

    data(i).Tp = rawData(i).Tp;
    data(i).run_id = rawData(i).run_id;
    data(i).run_dir = rawData(i).run_dir;
    data(i).T_common = commonT;
    data(i).tw_seconds = rawData(i).tw_seconds;
    data(i).wait_time = rawData(i).wait_time;
    data(i).M_common = MCommon;
    data(i).M_norm = MNorm;
    data(i).profile_amplitudes = amplitudes(:);
    data(i).normalization_reference_index = refIdx;
end
end

function [MNorm, amplitudes, refIdx] = normalizeProfileMatrix(M)
amplitudes = max(abs(M), [], 1, 'omitnan');
finiteAmp = amplitudes;
finiteAmp(~isfinite(finiteAmp)) = -inf;
[~, refIdx] = max(finiteAmp);
if ~isfinite(finiteAmp(refIdx))
    refIdx = 1;
end

ref = M(:, refIdx);
refScale = max(abs(ref), [], 'omitnan');
if ~(isfinite(refScale) && refScale > 0)
    refScale = 1;
end
ref = ref ./ refScale;

MNorm = nan(size(M));
for j = 1:size(M, 2)
    profile = M(:, j);
    scale = max(abs(profile), [], 'omitnan');
    if ~(isfinite(scale) && scale > 0)
        continue;
    end

    profileNorm = profile ./ scale;
    valid = isfinite(profileNorm) & isfinite(ref);
    if nnz(valid) >= 2 && sum(profileNorm(valid) .* ref(valid)) < 0
        profileNorm = -profileNorm;
    end
    MNorm(:, j) = profileNorm;
end
end

function tauTbl = loadTauTable(pathStr, tauColumn)
tauTbl = readtable(pathStr, 'TextType', 'string', 'VariableNamingRule', 'preserve');
for vn = {'Tp', tauColumn}
    name = vn{1};
    if ismember(name, tauTbl.Properties.VariableNames) && ~isnumeric(tauTbl.(name))
        tauTbl.(name) = str2double(erase(string(tauTbl.(name)), '"'));
    end
end
if ismember('has_fm', tauTbl.Properties.VariableNames) && ~islogical(tauTbl.has_fm)
    tauTbl.has_fm = logical(str2double(string(tauTbl.has_fm)));
end
tauTbl = sortrows(tauTbl, 'Tp');
end

function [withinTbl, rankTbl, modeAggTbl, modeDetailTbl] = computePerTpMetrics(data)
withinRows = repmat(initWithinRow(), numel(data), 1);
rankRows = repmat(initRankRow(), numel(data), 1);
modeAggRows = repmat(initModeAggRow(), numel(data), 1);
modeDetailRows = repmat(initModeDetailRow(), 0, 1);

for i = 1:numel(data)
    withinRows(i) = computeWithinRow(data(i));
    rankRows(i) = computeRankRow(data(i));
    [modeAggRows(i), detailRows] = computeModeRows(data(i));
    modeDetailRows = [modeDetailRows; detailRows]; %#ok<AGROW>
end

withinTbl = sortrows(struct2table(withinRows), 'Tp');
rankTbl = sortrows(struct2table(rankRows), 'Tp');
modeAggTbl = sortrows(struct2table(modeAggRows), 'Tp');
modeDetailTbl = sortrows(struct2table(modeDetailRows), {'Tp', 'tw_seconds'});
end

function row = initWithinRow()
row = struct( ...
    'Tp', NaN, ...
    'n_profiles', NaN, ...
    'tw_values_seconds', "", ...
    'mean_pairwise_rmse', NaN, ...
    'max_pairwise_rmse', NaN, ...
    'mean_profile_variance', NaN, ...
    'source_run', "");
end

function row = computeWithinRow(data)
row = initWithinRow();
pairRmse = computePairwiseProfileRmse(data.M_norm);
row.Tp = data.Tp;
row.n_profiles = size(data.M_norm, 2);
row.tw_values_seconds = join(string(data.tw_seconds.'), ';');
row.mean_pairwise_rmse = mean(pairRmse, 'omitnan');
row.max_pairwise_rmse = max(pairRmse, [], 'omitnan');
row.mean_profile_variance = mean(var(data.M_norm, 0, 2), 'omitnan');
row.source_run = data.run_id;
end

function values = computePairwiseProfileRmse(M)
nProfiles = size(M, 2);
values = nan(nchoosek(nProfiles, 2), 1);
cursor = 0;
for i = 1:(nProfiles - 1)
    for j = (i + 1):nProfiles
        cursor = cursor + 1;
        delta = M(:, i) - M(:, j);
        values(cursor) = sqrt(mean(delta .^ 2, 'omitnan'));
    end
end
values = values(1:cursor);
end

function row = initRankRow()
row = struct( ...
    'Tp', NaN, ...
    'n_profiles', NaN, ...
    'sigma1', NaN, ...
    'sigma2', NaN, ...
    'sigma3', NaN, ...
    'sigma4', NaN, ...
    'mode1_explained_variance', NaN, ...
    'sigma1_over_sigma2', NaN, ...
    'source_run', "");
end

function row = computeRankRow(data)
row = initRankRow();
[~, S, ~] = svd(data.M_common, 'econ');
s = diag(S);
ev = (s .^ 2) ./ max(sum(s .^ 2, 'omitnan'), eps);

row.Tp = data.Tp;
row.n_profiles = size(data.M_common, 2);
row.sigma1 = getSingularValue(s, 1);
row.sigma2 = getSingularValue(s, 2);
row.sigma3 = getSingularValue(s, 3);
row.sigma4 = getSingularValue(s, 4);
row.mode1_explained_variance = getSingularValue(ev, 1);
if isfinite(row.sigma1) && isfinite(row.sigma2) && abs(row.sigma2) > eps
    row.sigma1_over_sigma2 = row.sigma1 ./ row.sigma2;
end
row.source_run = data.run_id;
end

function value = getSingularValue(values, idx)
if idx <= numel(values)
    value = values(idx);
else
    value = NaN;
end
end

function row = initModeAggRow()
row = struct( ...
    'Tp', NaN, ...
    'n_profiles', NaN, ...
    'mean_cosine_similarity', NaN, ...
    'min_cosine_similarity', NaN, ...
    'mean_relative_residual', NaN, ...
    'max_relative_residual', NaN, ...
    'reference_wait_time', "", ...
    'source_run', "");
end

function row = initModeDetailRow()
row = struct( ...
    'Tp', NaN, ...
    'tw_seconds', NaN, ...
    'wait_time', "", ...
    'amplitude_coefficient', NaN, ...
    'cosine_similarity', NaN, ...
    'relative_residual', NaN, ...
    'source_run', "");
end

function [aggRow, detailRows] = computeModeRows(data)
[U, ~, ~] = svd(data.M_common, 'econ');
phi = U(:, 1);
refProfile = data.M_common(:, data.normalization_reference_index);
if sum(phi .* refProfile, 'omitnan') < 0
    phi = -phi;
end

phiNorm = phi ./ max(norm(phi), eps);
detailRows = repmat(initModeDetailRow(), size(data.M_common, 2), 1);
cosVals = nan(size(data.M_common, 2), 1);
resVals = nan(size(data.M_common, 2), 1);

for j = 1:size(data.M_common, 2)
    profile = data.M_common(:, j);
    coeff = (phi' * profile) ./ max(phi' * phi, eps);
    recon = coeff .* phi;
    resVals(j) = norm(profile - recon) ./ max(norm(profile), eps);

    profileNorm = profile ./ max(norm(profile), eps);
    cosVals(j) = phiNorm' * profileNorm;
    if cosVals(j) < 0
        cosVals(j) = -cosVals(j);
    end

    detailRows(j).Tp = data.Tp;
    detailRows(j).tw_seconds = data.tw_seconds(j);
    detailRows(j).wait_time = string(data.wait_time(j));
    detailRows(j).amplitude_coefficient = coeff;
    detailRows(j).cosine_similarity = cosVals(j);
    detailRows(j).relative_residual = resVals(j);
    detailRows(j).source_run = data.run_id;
end

aggRow = initModeAggRow();
aggRow.Tp = data.Tp;
aggRow.n_profiles = size(data.M_common, 2);
aggRow.mean_cosine_similarity = mean(cosVals, 'omitnan');
aggRow.min_cosine_similarity = min(cosVals, [], 'omitnan');
aggRow.mean_relative_residual = mean(resVals, 'omitnan');
aggRow.max_relative_residual = max(resVals, [], 'omitnan');
aggRow.reference_wait_time = string(data.wait_time(data.normalization_reference_index));
aggRow.source_run = data.run_id;
end

function [scenarioTbl, perTpTbl, perZTbl, scenarioMap] = computeCrossTemperatureMetrics(data, dipTauTbl, fmTauTbl, cfg)
allTp = sort([data.Tp]);
dipTp = sort(intersect(allTp, finiteTauTp(dipTauTbl, 'tau_effective_seconds', false)));
fmTp = sort(intersect(allTp, finiteTauTp(fmTauTbl, 'tau_effective_seconds', true)));
overlapTp = sort(intersect(dipTp, fmTp));

scenarioDefs = {
    'raw_tw_all',     'Raw t_w (all T_p)',          allTp,     'raw'
    'tau_dip_native', '\tau_{dip}(T_p)',            dipTp,     'dip'
    'tau_fm_native',  '\tau_{FM}(T_p)',             fmTp,      'fm'
    'raw_tw_overlap', 'Raw t_w (common overlap)',   overlapTp, 'raw'
    'tau_dip_overlap','\tau_{dip}(T_p) overlap',    overlapTp, 'dip'
    'tau_fm_overlap', '\tau_{FM}(T_p) overlap',     overlapTp, 'fm'
    };

scenarios = cell(0, 1);
for i = 1:size(scenarioDefs, 1)
    tpValues = scenarioDefs{i, 3};
    if numel(tpValues) < cfg.crossTemperatureMinTp
        continue;
    end
    scenarios{end + 1, 1} = evaluateCrossTemperatureScenario( ... %#ok<AGROW>
        data, tpValues, scenarioDefs{i, 1}, scenarioDefs{i, 2}, scenarioDefs{i, 4}, dipTauTbl, fmTauTbl, cfg);
end

scenarioRows = repmat(initScenarioRow(), 0, 1);
perTpRows = repmat(initPerTpRow(), 0, 1);
perZRows = repmat(initPerZRow(), 0, 1);
scenarioMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

for i = 1:numel(scenarios)
    scenario = scenarios{i};
    scenarioRows(end + 1, 1) = scenario.summaryRow; %#ok<AGROW>
    perTpRows = [perTpRows; scenario.perTpRows]; %#ok<AGROW>
    perZRows = [perZRows; scenario.perZRows]; %#ok<AGROW>
    scenarioMap(char(scenario.name)) = scenario;
end

scenarioTbl = struct2table(scenarioRows);
scenarioTbl = sortrows(scenarioTbl, 'scenario_name');
perTpTbl = struct2table(perTpRows);
perTpTbl = sortrows(perTpTbl, {'scenario_name', 'Tp'});
perZTbl = struct2table(perZRows);
perZTbl = sortrows(perZTbl, {'scenario_name', 'z_scaled'});
end

function tpValues = finiteTauTp(tauTbl, tauColumn, requireHasFm)
mask = isfinite(tauTbl.(tauColumn)) & tauTbl.(tauColumn) > 0;
if requireHasFm && ismember('has_fm', tauTbl.Properties.VariableNames)
    mask = mask & logical(tauTbl.has_fm);
end
tpValues = tauTbl.Tp(mask).';
end

function row = initScenarioRow()
row = struct( ...
    'scenario_name', "", ...
    'scenario_label', "", ...
    'tau_source', "", ...
    'tp_values', "", ...
    'n_tp', NaN, ...
    'z_min', NaN, ...
    'z_max', NaN, ...
    'n_z', NaN, ...
    'mean_pairwise_rmse', NaN, ...
    'mean_profile_variance', NaN, ...
    'mean_mode1_explained_variance', NaN, ...
    'stack_mode1_explained_variance', NaN);
end

function row = initPerTpRow()
row = struct( ...
    'scenario_name', "", ...
    'tau_source', "", ...
    'Tp', NaN, ...
    'n_z_contributing', NaN, ...
    'mean_rmse_to_master', NaN, ...
    'mean_correlation_to_master', NaN);
end

function row = initPerZRow()
row = struct( ...
    'scenario_name', "", ...
    'tau_source', "", ...
    'z_scaled', NaN, ...
    'mean_pairwise_rmse', NaN, ...
    'mean_profile_variance', NaN, ...
    'mode1_explained_variance', NaN);
end

function scenario = evaluateCrossTemperatureScenario(data, tpValues, name, label, tauSource, dipTauTbl, fmTauTbl, cfg)
selected = data(ismember([data.Tp], tpValues));
selected = sortStructByField(selected, 'Tp');
tauValues = resolveTauVector(selected, tauSource, dipTauTbl, fmTauTbl);

logZMin = -inf;
logZMax = inf;
for i = 1:numel(selected)
    logZ = log10(selected(i).tw_seconds ./ tauValues(i));
    logZMin = max(logZMin, min(logZ, [], 'omitnan'));
    logZMax = min(logZMax, max(logZ, [], 'omitnan'));
end
assert(isfinite(logZMin) && isfinite(logZMax) && logZMax > logZMin, ...
    'No common scaled-time overlap for scenario %s.', name);

logZGrid = linspace(logZMin, logZMax, cfg.zGridCount);
zGrid = 10 .^ logZGrid;
interpProfiles = cell(numel(selected), 1);
for i = 1:numel(selected)
    logZ = log10(selected(i).tw_seconds ./ tauValues(i));
    interpProfiles{i} = interp1(logZ, selected(i).M_norm.', logZGrid, 'linear', NaN).';
end

nTp = numel(selected);
nZ = numel(zGrid);
pairwiseRmse = nan(nZ, 1);
profileVar = nan(nZ, 1);
mode1Ev = nan(nZ, 1);

for k = 1:nZ
    stack = nan(size(selected(1).M_norm, 1), nTp);
    for i = 1:nTp
        stack(:, i) = interpProfiles{i}(:, k);
    end
    pairwiseRmse(k) = mean(computePairwiseProfileRmse(stack), 'omitnan');
    profileVar(k) = mean(var(stack, 0, 2), 'omitnan');
    [~, S, ~] = svd(stack, 'econ');
    s = diag(S);
    mode1Ev(k) = (s(1) ^ 2) ./ max(sum(s .^ 2, 'omitnan'), eps);
end

stackMatrix = [];
for k = 1:nZ
    for i = 1:nTp
        stackMatrix(:, end + 1) = interpProfiles{i}(:, k); %#ok<AGROW>
    end
end
stackMatrix = stackMatrix(:, all(isfinite(stackMatrix), 1));
stackS = svd(stackMatrix, 'econ');
stackMode1Ev = (stackS(1) ^ 2) ./ max(sum(stackS .^ 2, 'omitnan'), eps);

perTpRows = repmat(initPerTpRow(), nTp, 1);
for i = 1:nTp
    rmseVals = nan(nZ, 1);
    corrVals = nan(nZ, 1);
    for k = 1:nZ
        others = nan(size(selected(1).M_norm, 1), nTp - 1);
        cursor = 0;
        for j = 1:nTp
            if j == i
                continue;
            end
            cursor = cursor + 1;
            others(:, cursor) = interpProfiles{j}(:, k);
        end
        master = mean(others, 2, 'omitnan');
        rmseVals(k) = sqrt(mean((interpProfiles{i}(:, k) - master) .^ 2, 'omitnan'));
        corrVals(k) = safeCorrelation(interpProfiles{i}(:, k), master);
    end

    perTpRows(i).scenario_name = string(name);
    perTpRows(i).tau_source = string(tauSource);
    perTpRows(i).Tp = selected(i).Tp;
    perTpRows(i).n_z_contributing = nZ;
    perTpRows(i).mean_rmse_to_master = mean(rmseVals, 'omitnan');
    perTpRows(i).mean_correlation_to_master = mean(corrVals, 'omitnan');
end

perZRows = repmat(initPerZRow(), nZ, 1);
for k = 1:nZ
    perZRows(k).scenario_name = string(name);
    perZRows(k).tau_source = string(tauSource);
    perZRows(k).z_scaled = zGrid(k);
    perZRows(k).mean_pairwise_rmse = pairwiseRmse(k);
    perZRows(k).mean_profile_variance = profileVar(k);
    perZRows(k).mode1_explained_variance = mode1Ev(k);
end

summaryRow = initScenarioRow();
summaryRow.scenario_name = string(name);
summaryRow.scenario_label = string(label);
summaryRow.tau_source = string(tauSource);
summaryRow.tp_values = join(string([selected.Tp]), ';');
summaryRow.n_tp = nTp;
summaryRow.z_min = zGrid(1);
summaryRow.z_max = zGrid(end);
summaryRow.n_z = nZ;
summaryRow.mean_pairwise_rmse = mean(pairwiseRmse, 'omitnan');
summaryRow.mean_profile_variance = mean(profileVar, 'omitnan');
summaryRow.mean_mode1_explained_variance = mean(mode1Ev, 'omitnan');
summaryRow.stack_mode1_explained_variance = stackMode1Ev;

repIdx = representativeIndices(nZ, cfg.representativeSliceFractions);

scenario = struct();
scenario.name = string(name);
scenario.label = string(label);
scenario.tau_source = string(tauSource);
scenario.tp_values = [selected.Tp];
scenario.z_grid = zGrid(:);
scenario.log_z_grid = logZGrid(:);
scenario.selected = selected;
scenario.tau_values = tauValues(:);
scenario.interp_profiles = interpProfiles;
scenario.per_z_metrics = table(zGrid(:), pairwiseRmse(:), profileVar(:), mode1Ev(:), ...
    'VariableNames', {'z_scaled', 'mean_pairwise_rmse', 'mean_profile_variance', 'mode1_explained_variance'});
scenario.summaryRow = summaryRow;
scenario.perTpRows = perTpRows;
scenario.perZRows = perZRows;
scenario.rep_indices = repIdx;
end

function selected = sortStructByField(selected, fieldName)
[~, order] = sort([selected.(fieldName)]);
selected = selected(order);
end

function tauValues = resolveTauVector(selected, tauSource, dipTauTbl, fmTauTbl)
tauValues = nan(numel(selected), 1);
for i = 1:numel(selected)
    tp = selected(i).Tp;
    switch lower(char(tauSource))
        case 'raw'
            tauValues(i) = 1;
        case 'dip'
            tauValues(i) = lookupTau(dipTauTbl, tp);
        case 'fm'
            tauValues(i) = lookupTau(fmTauTbl, tp);
        otherwise
            error('Unsupported tau source: %s', tauSource);
    end
end
assert(all(isfinite(tauValues) & tauValues > 0), ...
    'Scenario contains non-finite or non-positive tau values.');
end

function tauValue = lookupTau(tauTbl, tp)
mask = abs(tauTbl.Tp - tp) < 1e-9;
assert(any(mask), 'Could not find tau entry for T_p = %g K.', tp);
tauValue = tauTbl.tau_effective_seconds(find(mask, 1, 'first'));
end

function idx = representativeIndices(nValues, fractions)
idx = round(1 + fractions(:) .* (nValues - 1));
idx = unique(min(max(idx, 1), nValues));
if numel(idx) < 3 && nValues >= 3
    idx = unique([1; round((nValues + 1) / 2); nValues]);
end
end

function r = safeCorrelation(x, y)
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if numel(x) < 2
    r = NaN;
    return;
end
x = x - mean(x);
y = y - mean(y);
denom = sqrt(sum(x .^ 2) * sum(y .^ 2));
if denom <= eps
    r = NaN;
else
    r = sum(x .* y) ./ denom;
end
end

function summaryTbl = buildSummaryTable(withinTbl, rankTbl, modeAggTbl, dipTauTbl, fmTauTbl, perTpTbl, cfg)
tpValues = cfg.tpValues(:);
summaryRows = repmat(initSummaryRow(), numel(tpValues), 1);

for i = 1:numel(tpValues)
    tp = tpValues(i);
    summaryRows(i).Tp = tp;

    w = withinTbl(withinTbl.Tp == tp, :);
    if ~isempty(w)
        summaryRows(i).n_profiles = w.n_profiles(1);
        summaryRows(i).tw_values_seconds = string(w.tw_values_seconds(1));
        summaryRows(i).mean_pairwise_rmse = w.mean_pairwise_rmse(1);
        summaryRows(i).mean_profile_variance = w.mean_profile_variance(1);
        summaryRows(i).source_run = string(w.source_run(1));
    end

    r = rankTbl(rankTbl.Tp == tp, :);
    if ~isempty(r)
        summaryRows(i).mode1_explained_variance = r.mode1_explained_variance(1);
        summaryRows(i).sigma1_over_sigma2 = r.sigma1_over_sigma2(1);
    end

    m = modeAggTbl(modeAggTbl.Tp == tp, :);
    if ~isempty(m)
        summaryRows(i).mode_mean_cosine = m.mean_cosine_similarity(1);
        summaryRows(i).mode_mean_relative_residual = m.mean_relative_residual(1);
    end

    summaryRows(i).tau_dip_seconds = lookupOptionalTau(dipTauTbl, tp);
    summaryRows(i).tau_fm_seconds = lookupOptionalTau(fmTauTbl, tp);
    summaryRows(i).tau_dip_native_rmse_to_master = lookupOptionalPerTp(perTpTbl, 'tau_dip_native', tp);
    summaryRows(i).tau_fm_native_rmse_to_master = lookupOptionalPerTp(perTpTbl, 'tau_fm_native', tp);
    summaryRows(i).tau_dip_overlap_rmse_to_master = lookupOptionalPerTp(perTpTbl, 'tau_dip_overlap', tp);
    summaryRows(i).tau_fm_overlap_rmse_to_master = lookupOptionalPerTp(perTpTbl, 'tau_fm_overlap', tp);
end

summaryTbl = struct2table(summaryRows);
summaryTbl = sortrows(summaryTbl, 'Tp');
end

function row = initSummaryRow()
row = struct( ...
    'Tp', NaN, ...
    'n_profiles', NaN, ...
    'tw_values_seconds', "", ...
    'tau_dip_seconds', NaN, ...
    'tau_fm_seconds', NaN, ...
    'mean_pairwise_rmse', NaN, ...
    'mean_profile_variance', NaN, ...
    'mode1_explained_variance', NaN, ...
    'sigma1_over_sigma2', NaN, ...
    'mode_mean_cosine', NaN, ...
    'mode_mean_relative_residual', NaN, ...
    'tau_dip_native_rmse_to_master', NaN, ...
    'tau_fm_native_rmse_to_master', NaN, ...
    'tau_dip_overlap_rmse_to_master', NaN, ...
    'tau_fm_overlap_rmse_to_master', NaN, ...
    'source_run', "");
end

function value = lookupOptionalTau(tauTbl, tp)
value = NaN;
if isempty(tauTbl)
    return;
end
mask = abs(tauTbl.Tp - tp) < 1e-9 & isfinite(tauTbl.tau_effective_seconds) & tauTbl.tau_effective_seconds > 0;
if any(mask)
    value = tauTbl.tau_effective_seconds(find(mask, 1, 'first'));
end
end

function value = lookupOptionalPerTp(perTpTbl, scenarioName, tp)
value = NaN;
if isempty(perTpTbl)
    return;
end
mask = string(perTpTbl.scenario_name) == string(scenarioName) & abs(perTpTbl.Tp - tp) < 1e-9;
if any(mask)
    value = perTpTbl.mean_rmse_to_master(find(mask, 1, 'first'));
end
end

function fig = makeSelectedTpOverlayFigure(data, cfg)
selectedTp = cfg.selectedTpOverlays(:).';
selected = data(ismember([data.Tp], selectedTp));
selected = sortStructByField(selected, 'Tp');

fig = create_figure('Visible', 'off', 'Position', [2 2 26 8.4]);
tlo = tiledlayout(fig, 1, numel(selected), 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numel(selected)
    ax = nexttile(tlo, i);
    hold(ax, 'on');
    colors = lines(numel(selected(i).tw_seconds));
    for j = 1:numel(selected(i).tw_seconds)
        plot(ax, selected(i).T_common, selected(i).M_norm(:, j), '-', ...
            'Color', colors(j, :), 'LineWidth', 2.2, ...
            'DisplayName', sprintf('%s', char(selected(i).wait_time(j))));
    end
    xlabel(ax, 'Temperature (K)');
    ylabel(ax, 'Normalized \DeltaM(T, t_w)');
    title(ax, sprintf('T_p = %.0f K', selected(i).Tp));
    grid(ax, 'on');
    set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
    ylim(ax, paddedLimits(selected(i).M_norm(:)));
    lg = legend(ax, 'Location', 'best');
    lg.Box = 'off';
    lg.Title.String = 't_w';
end

title(tlo, 'Amplitude-normalized within-T_p profile collapse around 26 K');
end

function fig = makeWithinTpMetricFigure(withinTbl)
fig = create_figure('Visible', 'off', 'Position', [2 2 20 8.4]);
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
plot(ax1, withinTbl.Tp, withinTbl.mean_pairwise_rmse, '-o', ...
    'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
    'LineWidth', 2.2, 'MarkerSize', 7);
hold(ax1, 'on');
highlightTp(ax1, withinTbl.Tp, withinTbl.mean_pairwise_rmse, 26);
xlabel(ax1, 'T_p (K)');
ylabel(ax1, 'Mean pairwise RMSE');
title(ax1, 'Within-T_p normalized profile mismatch');
grid(ax1, 'on');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');

ax2 = nexttile(tlo, 2);
plot(ax2, withinTbl.Tp, withinTbl.mean_profile_variance, '-s', ...
    'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
    'LineWidth', 2.2, 'MarkerSize', 7);
hold(ax2, 'on');
highlightTp(ax2, withinTbl.Tp, withinTbl.mean_profile_variance, 26);
xlabel(ax2, 'T_p (K)');
ylabel(ax2, 'Mean profile variance');
title(ax2, 'Within-T_p normalized profile variance');
grid(ax2, 'on');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');

title(tlo, 'Waiting-time collapse metrics from normalized \DeltaM(T, t_w) profiles');
end

function fig = makeRankStructureFigure(rankTbl)
heatData = [rankTbl.mode1_explained_variance, ...
    safeVarianceFromSigma(rankTbl.sigma2, rankTbl.sigma1, rankTbl.sigma2, rankTbl.sigma3, rankTbl.sigma4), ...
    safeVarianceFromSigma(rankTbl.sigma3, rankTbl.sigma1, rankTbl.sigma2, rankTbl.sigma3, rankTbl.sigma4), ...
    safeVarianceFromSigma(rankTbl.sigma4, rankTbl.sigma1, rankTbl.sigma2, rankTbl.sigma3, rankTbl.sigma4)];

fig = create_figure('Visible', 'off', 'Position', [2 2 23.5 9.4]);
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
imagesc(ax1, 1:4, rankTbl.Tp, heatData);
axis(ax1, 'xy');
colormap(ax1, parula(256));
cb = colorbar(ax1);
cb.Label.String = 'Explained variance ratio';
xlabel(ax1, 'SVD mode');
ylabel(ax1, 'T_p (K)');
title(ax1, 'SVD variance spectrum vs stopping temperature');
xticks(ax1, 1:4);
grid(ax1, 'off');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2, 'Box', 'on');

ax2 = nexttile(tlo, 2);
yyaxis(ax2, 'left');
plot(ax2, rankTbl.Tp, rankTbl.mode1_explained_variance, '-o', ...
    'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
    'LineWidth', 2.2, 'MarkerSize', 7, 'DisplayName', 'Mode-1 explained variance');
ylabel(ax2, 'Mode-1 explained variance');

yyaxis(ax2, 'right');
plot(ax2, rankTbl.Tp, log10(rankTbl.sigma1_over_sigma2), '-s', ...
    'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
    'LineWidth', 2.2, 'MarkerSize', 7, 'DisplayName', 'log_{10}(\sigma_1 / \sigma_2)');
ylabel(ax2, 'log_{10}(\sigma_1 / \sigma_2)');

highlightDualAxisTp(ax2, rankTbl.Tp, rankTbl.mode1_explained_variance, log10(rankTbl.sigma1_over_sigma2), 26);
xlabel(ax2, 'T_p (K)');
title(ax2, 'Near-rank-1 diagnostics');
grid(ax2, 'on');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
legend(ax2, 'Location', 'best', 'Box', 'off');

title(tlo, 'Rank-structure test for M(T, t_w)');
end

function values = safeVarianceFromSigma(targetSigma, sigma1, sigma2, sigma3, sigma4)
denom = zeros(size(targetSigma));
for series = {sigma1, sigma2, sigma3, sigma4}
    valuesIn = series{1};
    valuesIn(~isfinite(valuesIn)) = 0;
    denom = denom + valuesIn .^ 2;
end
num = targetSigma;
num(~isfinite(num)) = 0;
values = (num .^ 2) ./ max(denom, eps);
values(denom <= eps) = NaN;
end

function fig = makeModeStabilityFigure(modeAggTbl)
fig = create_figure('Visible', 'off', 'Position', [2 2 20.5 8.4]);
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
plot(ax1, modeAggTbl.Tp, modeAggTbl.mean_cosine_similarity, '-o', ...
    'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], ...
    'LineWidth', 2.2, 'MarkerSize', 7);
hold(ax1, 'on');
highlightTp(ax1, modeAggTbl.Tp, modeAggTbl.mean_cosine_similarity, 26);
xlabel(ax1, 'T_p (K)');
ylabel(ax1, 'Mean cosine similarity to \phi(T)');
title(ax1, 'SVD-mode stability across waiting times');
ylim(ax1, [0.7, 1.02]);
grid(ax1, 'on');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');

ax2 = nexttile(tlo, 2);
plot(ax2, modeAggTbl.Tp, modeAggTbl.mean_relative_residual, '-s', ...
    'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
    'LineWidth', 2.2, 'MarkerSize', 7);
hold(ax2, 'on');
highlightTp(ax2, modeAggTbl.Tp, modeAggTbl.mean_relative_residual, 26);
xlabel(ax2, 'T_p (K)');
ylabel(ax2, 'Mean relative residual');
title(ax2, 'Residual after rank-1 reconstruction');
grid(ax2, 'on');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');

title(tlo, 'Mode-stability check for M(T, t_w) \approx a(t_w)\phi(T)');
end

function fig = makeScenarioMetricFigure(scenarioTbl, perTpTbl)
overlapTbl = scenarioTbl(ismember(string(scenarioTbl.scenario_name), ...
    ["raw_tw_overlap", "tau_dip_overlap", "tau_fm_overlap"]), :);
order = ["raw_tw_overlap", "tau_dip_overlap", "tau_fm_overlap"];
overlapTbl = reorderScenarioTable(overlapTbl, order);

fig = create_figure('Visible', 'off', 'Position', [2 2 26 16]);
tlo = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
bar(ax1, categorical(shortScenarioLabels(overlapTbl.scenario_name)), overlapTbl.mean_pairwise_rmse, ...
    'FaceColor', [0 0.4470 0.7410]);
xlabel(ax1, 'Clock scenario');
ylabel(ax1, 'Mean pairwise RMSE');
title(ax1, 'Overlap-set cross-temperature RMSE');
grid(ax1, 'on');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2, 'Box', 'off');

ax2 = nexttile(tlo, 2);
bar(ax2, categorical(shortScenarioLabels(overlapTbl.scenario_name)), overlapTbl.mean_profile_variance, ...
    'FaceColor', [0.8500 0.3250 0.0980]);
xlabel(ax2, 'Clock scenario');
ylabel(ax2, 'Mean profile variance');
title(ax2, 'Overlap-set cross-temperature variance');
grid(ax2, 'on');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2, 'Box', 'off');

ax3 = nexttile(tlo, 3);
bar(ax3, categorical(shortScenarioLabels(overlapTbl.scenario_name)), overlapTbl.stack_mode1_explained_variance, ...
    'FaceColor', [0.00 0.62 0.45]);
xlabel(ax3, 'Clock scenario');
ylabel(ax3, 'Stack mode-1 explained variance');
ylim(ax3, [0, 1]);
title(ax3, 'Overlap-set stacked rank-1 score');
grid(ax3, 'on');
set(ax3, 'FontSize', 14, 'LineWidth', 1.2, 'Box', 'off');

ax4 = nexttile(tlo, 4);
hold(ax4, 'on');
plotPerTpScenario(ax4, perTpTbl, 'tau_dip_native', '\tau_{dip}(T_p)', [0 0.4470 0.7410], 'o');
plotPerTpScenario(ax4, perTpTbl, 'tau_fm_native', '\tau_{FM}(T_p)', [0.8500 0.3250 0.0980], 's');
xlabel(ax4, 'T_p (K)');
ylabel(ax4, 'Mean RMSE to leave-one-out master');
title(ax4, 'Per-T_p cross-temperature collapse quality');
grid(ax4, 'on');
set(ax4, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
legend(ax4, 'Location', 'best', 'Box', 'off');

title(tlo, 'TRI-like cross-temperature collapse metrics');
end

function tbl = reorderScenarioTable(tbl, order)
key = strings(height(tbl), 1);
for i = 1:height(tbl)
    key(i) = string(find(order == string(tbl.scenario_name(i)), 1, 'first'));
end
tbl.order_key = str2double(key);
tbl = sortrows(tbl, 'order_key');
tbl.order_key = [];
end

function labels = shortScenarioLabels(names)
labels = strings(size(names));
for i = 1:numel(names)
    switch string(names(i))
        case "raw_tw_overlap"
            labels(i) = "raw";
        case "tau_dip_overlap"
            labels(i) = "tau_dip";
        case "tau_fm_overlap"
            labels(i) = "tau_FM";
        otherwise
            labels(i) = string(names(i));
    end
end
end

function plotPerTpScenario(ax, perTpTbl, scenarioName, labelText, colorValue, markerSymbol)
sub = perTpTbl(string(perTpTbl.scenario_name) == string(scenarioName), :);
if isempty(sub)
    return;
end
sub = sortrows(sub, 'Tp');
plot(ax, sub.Tp, sub.mean_rmse_to_master, ['-' markerSymbol], ...
    'Color', colorValue, 'MarkerFaceColor', colorValue, ...
    'LineWidth', 2.2, 'MarkerSize', 7, 'DisplayName', labelText);
end

function fig = makeCrossTemperatureCollapseFigure(scenario, ~)
nTiles = numel(scenario.rep_indices);
fig = create_figure('Visible', 'off', 'Position', [2 2 28 8.8]);
tlo = tiledlayout(fig, 1, nTiles, 'TileSpacing', 'compact', 'Padding', 'compact');

nCurves = numel(scenario.selected);
colors = lines(max(nCurves, 1));

for tileIdx = 1:nTiles
    k = scenario.rep_indices(tileIdx);
    ax = nexttile(tlo, tileIdx);
    hold(ax, 'on');
    meanProfile = zeros(size(scenario.selected(1).T_common));

    for i = 1:nCurves
        profile = scenario.interp_profiles{i}(:, k);
        meanProfile = meanProfile + profile;
        plot(ax, scenario.selected(i).T_common, profile, '-', ...
            'Color', colors(i, :), 'LineWidth', 2.0, ...
            'DisplayName', sprintf('T_p = %.0f K', scenario.selected(i).Tp));
    end
    meanProfile = meanProfile ./ max(nCurves, 1);
    plot(ax, scenario.selected(1).T_common, meanProfile, '--', ...
        'Color', [0.05 0.05 0.05], 'LineWidth', 2.6, 'DisplayName', 'Mean profile');

    xlabel(ax, 'Temperature (K)');
    ylabel(ax, 'Normalized \DeltaM(T, z)');
    title(ax, sprintf('z = %.3g, RMSE = %.3f, EV_1 = %.3f', ...
        scenario.z_grid(k), ...
        scenario.per_z_metrics.mean_pairwise_rmse(k), ...
        scenario.per_z_metrics.mode1_explained_variance(k)));
    grid(ax, 'on');
    set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
    ylim(ax, paddedLimits(collectScenarioSliceValues(scenario, k)));
end

lg = legend(nexttile(tlo, nTiles), 'Location', 'eastoutside');
lg.Box = 'off';
title(tlo, sprintf('Cross-temperature collapse slices under %s', char(scenario.label)));
end

function values = collectScenarioSliceValues(scenario, idx)
values = [];
for i = 1:numel(scenario.interp_profiles)
    values = [values; scenario.interp_profiles{i}(:, idx)]; %#ok<AGROW>
end
end

function reportText = buildReportText(runDir, existingAnalyses, structuredRuns, dipTauTbl, fmTauTbl, ...
    withinTbl, rankTbl, modeAggTbl, scenarioTbl, perTpTbl, cfg)
lines = strings(0, 1);
lines(end + 1) = '# Aging TRI-style scaling test';
lines(end + 1) = '';
lines(end + 1) = sprintf('Generated: %s', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf('Run root: `%s`', string(runDir));
lines(end + 1) = '';
lines(end + 1) = '## Repository scan summary';
lines(end + 1) = '- I checked the existing Aging analyses before creating this run.';
for i = 1:numel(existingAnalyses)
    lines(end + 1) = sprintf('- `%s`: %s %s', existingAnalyses(i).run_id, ...
        existingAnalyses(i).scope, existingAnalyses(i).gap);
end
lines(end + 1) = '- Conclusion of the scan: the repository already had partial ingredients for a TRI-style audit, but not a single standalone analysis that tested structured `\DeltaM(T, t_w)` collapse against the extracted `\tau_{dip}(T_p)` and `\tau_{FM}(T_p)` clocks.';
lines(end + 1) = '';
lines(end + 1) = '## Runs used';
for i = 1:numel(structuredRuns)
    lines(end + 1) = sprintf('- Structured Aging map: `T_p = %.0f K` -> `%s`', ...
        structuredRuns(i).Tp, structuredRuns(i).run_id);
end
lines(end + 1) = sprintf('- Dip clock source: `%s`', cfg.dipTauPath);
lines(end + 1) = sprintf('- FM clock source: `%s`', cfg.fmTauPath);
lines(end + 1) = '';
lines(end + 1) = '## Methods';
lines(end + 1) = '- Each structured-export map was interpolated onto one common temperature grid over the shared overlap of all `T_p` runs.';
lines(end + 1) = '- For waiting-time collapse and cross-temperature profile comparisons, each `\DeltaM(T, t_w)` curve was amplitude-normalized by its own `max|\DeltaM|` so the metrics target shape rather than absolute magnitude.';
lines(end + 1) = '- Within a fixed `T_p`, replacing `t_w` by `t_w / \tau(T_p)` only relabels the waiting-time points by one common factor, so the intra-`T_p` shape-collapse metrics are identical for `\tau_{dip}` and `\tau_{FM}`. The clock choice becomes informative only in the cross-temperature tests.';
lines(end + 1) = '- Rank structure was measured from the raw matrix `M(T, t_w)` using SVD, with the mode-1 explained variance and the ratio `\sigma_1 / \sigma_2` recorded for each `T_p`.';
lines(end + 1) = '- TRI-like rescaling was tested by interpolating normalized profiles onto a common grid of the scaled variable `z = t_w / \tau(T_p)` and comparing the resulting profiles across temperatures.';
lines(end + 1) = '- Cross-temperature collapse quality was summarized by mean pairwise RMSE, mean profile variance, and the stacked mode-1 explained variance. A leave-one-out master-profile RMSE was also computed for each `T_p`.';
lines(end + 1) = '- Mode stability was checked by comparing each raw profile to the leading SVD spatial mode `\phi(T)` through cosine similarity and relative reconstruction residual.';
lines(end + 1) = '';

bestWithin = bestFiniteRow(withinTbl, 'mean_pairwise_rmse', 'ascend');
bestRank = bestFiniteRow(rankTbl, 'mode1_explained_variance', 'descend');
bestMode = bestFiniteRow(modeAggTbl, 'mean_cosine_similarity', 'descend');
tp26Mode = modeAggTbl(modeAggTbl.Tp == 26, :);
tp26Rank = rankTbl(rankTbl.Tp == 26, :);

lines(end + 1) = '## Waiting-time collapse test';
if ~isempty(bestWithin)
    lines(end + 1) = sprintf('- The strongest within-`T_p` normalized profile collapse occurs at `T_p = %.0f K`, where the mean pairwise RMSE is `%.4f` and the mean profile variance is `%.5f`.', ...
        bestWithin.Tp, bestWithin.mean_pairwise_rmse, bestWithin.mean_profile_variance);
end
lines(end + 1) = sprintf('- Over the tested temperatures, the minimum-to-maximum mean pairwise RMSE spans `%.4f` to `%.4f`.', ...
    min(withinTbl.mean_pairwise_rmse, [], 'omitnan'), max(withinTbl.mean_pairwise_rmse, [], 'omitnan'));
lines(end + 1) = '- Because the intra-`T_p` collapse metric is tau-invariant, the extracted clocks are evaluated by the cross-temperature tests below rather than by a separate within-`T_p` before/after comparison.';
lines(end + 1) = '';

lines(end + 1) = '## Rank-structure test';
if ~isempty(bestRank)
    lines(end + 1) = sprintf('- The largest mode-1 explained variance occurs at `T_p = %.0f K`, with `EV_1 = %.4f` and `\\sigma_1 / \\sigma_2 = %.3f`.', ...
        bestRank.Tp, bestRank.mode1_explained_variance, bestRank.sigma1_over_sigma2);
end
if ~isempty(tp26Rank)
    lines(end + 1) = sprintf('- At `T_p = 26 K`, the rank metrics are `EV_1 = %.4f` and `\\sigma_1 / \\sigma_2 = %.3f`.', ...
        tp26Rank.mode1_explained_variance, tp26Rank.sigma1_over_sigma2);
end
lines(end + 1) = '';

rawOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "raw_tw_overlap", :);
dipOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_dip_overlap", :);
fmOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_fm_overlap", :);
dipNative = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_dip_native", :);
fmNative = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_fm_native", :);

lines(end + 1) = '## TRI-like time-reparametrization test';
if ~isempty(rawOverlap)
    lines(end + 1) = sprintf('- On the common overlap set `%s K`, the raw-`t_w` baseline gives mean pairwise RMSE `%.4f`, mean variance `%.5f`, and stacked mode-1 explained variance `%.4f`.', ...
        rawOverlap.tp_values, rawOverlap.mean_pairwise_rmse, rawOverlap.mean_profile_variance, rawOverlap.stack_mode1_explained_variance);
end
if ~isempty(dipOverlap)
    lines(end + 1) = sprintf('- On the same overlap set, `\\tau_{dip}(T_p)` gives mean pairwise RMSE `%.4f`, mean variance `%.5f`, and stacked mode-1 explained variance `%.4f`.', ...
        dipOverlap.mean_pairwise_rmse, dipOverlap.mean_profile_variance, dipOverlap.stack_mode1_explained_variance);
end
if ~isempty(fmOverlap)
    lines(end + 1) = sprintf('- On the same overlap set, `\\tau_{FM}(T_p)` gives mean pairwise RMSE `%.4f`, mean variance `%.5f`, and stacked mode-1 explained variance `%.4f`.', ...
        fmOverlap.mean_pairwise_rmse, fmOverlap.mean_profile_variance, fmOverlap.stack_mode1_explained_variance);
end
if ~isempty(rawOverlap) && ~isempty(dipOverlap)
    lines(end + 1) = sprintf('- Relative to raw waiting time on the overlap set, `\\tau_{dip}` changes RMSE by `%.2f%%` and variance by `%.2f%%`.', ...
        percentReduction(rawOverlap.mean_pairwise_rmse, dipOverlap.mean_pairwise_rmse), ...
        percentReduction(rawOverlap.mean_profile_variance, dipOverlap.mean_profile_variance));
end
if ~isempty(rawOverlap) && ~isempty(fmOverlap)
    lines(end + 1) = sprintf('- Relative to raw waiting time on the overlap set, `\\tau_{FM}` changes RMSE by `%.2f%%` and variance by `%.2f%%`.', ...
        percentReduction(rawOverlap.mean_pairwise_rmse, fmOverlap.mean_pairwise_rmse), ...
        percentReduction(rawOverlap.mean_profile_variance, fmOverlap.mean_profile_variance));
end
if ~isempty(dipOverlap) && ~isempty(fmOverlap)
    lines(end + 1) = sprintf('- Head-to-head on the common overlap, the better clock by RMSE is `%s` and the better clock by variance is `%s`.', ...
        betterLabel(dipOverlap.mean_pairwise_rmse, fmOverlap.mean_pairwise_rmse, '\tau_{dip}', '\tau_{FM}'), ...
        betterLabel(dipOverlap.mean_profile_variance, fmOverlap.mean_profile_variance, '\tau_{dip}', '\tau_{FM}'));
end
if ~isempty(dipNative)
    lines(end + 1) = sprintf('- Native `\\tau_{dip}` coverage is `%s K`.', dipNative.tp_values);
end
if ~isempty(fmNative)
    lines(end + 1) = sprintf('- Native `\\tau_{FM}` coverage is `%s K`.', fmNative.tp_values);
end
lines(end + 1) = '';

lines(end + 1) = '## Mode-stability check';
if ~isempty(bestMode)
    lines(end + 1) = sprintf('- The largest mean cosine similarity to the leading SVD mode occurs at `T_p = %.0f K`, where the mean cosine is `%.4f` and the mean relative residual is `%.4f`.', ...
        bestMode.Tp, bestMode.mean_cosine_similarity, bestMode.mean_relative_residual);
end
if ~isempty(tp26Mode)
    lines(end + 1) = sprintf('- At `T_p = 26 K`, the mean cosine similarity is `%.4f`, the minimum cosine across waiting times is `%.4f`, and the mean relative residual is `%.4f`.', ...
        tp26Mode.mean_cosine_similarity, tp26Mode.min_cosine_similarity, tp26Mode.mean_relative_residual);
end
lines(end + 1) = '';
lines(end + 1) = '## TRI-style interpretation';
lines(end + 1) = buildTriInterpretation(rawOverlap, dipOverlap, fmOverlap, tp26Rank, tp26Mode);
lines(end + 1) = '- This remains a scaling audit only. The data are sparse in waiting time, `\tau_{dip}` is unresolved at high `T_p`, `\tau_{FM}` is absent at low `T_p`, and none of these metrics alone justifies a claim of TRI.';
lines(end + 1) = '';

lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- `within_tp_normalized_profiles_around_26K`: 3 panels with 3-4 curves each, explicit legends, no colormap, no smoothing, used to show the local profile collapse near the 26 K region.';
lines(end + 1) = '- `waiting_time_collapse_metrics_vs_Tp`: two metric curves, explicit markers, no colormap, no smoothing, used to summarize the within-`T_p` shape-collapse strength.';
lines(end + 1) = '- `svd_spectrum_vs_temperature`: a heatmap for the 4-mode SVD variance spectrum plus a dual-axis diagnostic line plot; `parula` is used for the heatmap.';
lines(end + 1) = '- `tri_cross_temperature_collapse_tau_dip` and `tri_cross_temperature_collapse_tau_fm`: 3 representative `z = t_w / \tau(T_p)` slices each, explicit legends because the curve count is <= 6.';
lines(end + 1) = '- `tri_cross_temperature_metrics`: bar charts for the overlap-set summary metrics plus a per-`T_p` line comparison for the native dip and FM clocks.';
lines(end + 1) = '- `mode_stability_vs_Tp`: two metric curves, explicit markers, no colormap, no smoothing.';
lines(end + 1) = '- Smoothing applied: none. The goal was to test the saved structured maps directly rather than to introduce post-processing that could mimic a collapse.';
lines(end + 1) = '';

lines(end + 1) = '## Outputs';
lines(end + 1) = '- `tables/tri_scaling_summary.csv`';
lines(end + 1) = '- `tables/waiting_time_collapse_metrics.csv`';
lines(end + 1) = '- `tables/rank_structure_metrics.csv`';
lines(end + 1) = '- `tables/mode_stability_metrics.csv`';
lines(end + 1) = '- `tables/mode_stability_details.csv`';
lines(end + 1) = '- `tables/cross_temperature_scenario_metrics.csv`';
lines(end + 1) = '- `tables/cross_temperature_per_tp_quality.csv`';
lines(end + 1) = '- `tables/cross_temperature_per_z_metrics.csv`';
lines(end + 1) = '- `figures/within_tp_normalized_profiles_around_26K.png`';
lines(end + 1) = '- `figures/waiting_time_collapse_metrics_vs_Tp.png`';
lines(end + 1) = '- `figures/svd_spectrum_vs_temperature.png`';
lines(end + 1) = '- `figures/tri_cross_temperature_collapse_tau_dip.png`';
lines(end + 1) = '- `figures/tri_cross_temperature_collapse_tau_fm.png`';
lines(end + 1) = '- `figures/tri_cross_temperature_metrics.png`';
lines(end + 1) = '- `figures/mode_stability_vs_Tp.png`';
lines(end + 1) = '- `reports/tri_scaling_test_report.md`';
lines(end + 1) = '- `review/TRI_scaling_test_bundle.zip`';

reportText = strjoin(lines, newline);
end

function line = buildTriInterpretation(rawOverlap, dipOverlap, fmOverlap, tp26Rank, tp26Mode)
if isempty(tp26Rank) || isempty(tp26Mode)
    line = '- The structured maps do not provide enough information to judge TRI-style scaling in a disciplined way.';
    return;
end

rankStrong = tp26Rank.mode1_explained_variance >= 0.90 && tp26Mode.mean_cosine_similarity >= 0.95;
dipImproves = ~isempty(rawOverlap) && ~isempty(dipOverlap) && ...
    dipOverlap.mean_pairwise_rmse < rawOverlap.mean_pairwise_rmse && ...
    dipOverlap.mean_profile_variance < rawOverlap.mean_profile_variance;
fmImproves = ~isempty(rawOverlap) && ~isempty(fmOverlap) && ...
    fmOverlap.mean_pairwise_rmse < rawOverlap.mean_pairwise_rmse && ...
    fmOverlap.mean_profile_variance < rawOverlap.mean_profile_variance;

if rankStrong && (dipImproves || fmImproves)
    line = '- The data show some TRI-like ingredients: near-rank-1 behavior around 26 K, a stable dominant spatial mode across waiting times there, and at least one extracted clock that improves cross-temperature profile alignment on the common overlap set. That is consistent with a one-clock scaling tendency, but it is still weaker than a TRI demonstration.';
elseif rankStrong
    line = '- The 26 K region is structurally close to rank-1 and the dominant spatial mode is stable, but the extracted clocks do not produce a clear cross-temperature collapse improvement. That points to separability without strong TRI-style time reparametrization evidence.';
else
    line = '- Neither the rank/mode diagnostics nor the cross-temperature clock rescaling provide a strong TRI-like signal. Any apparent collapse is better interpreted as a limited empirical similarity than as evidence for reparametrization invariance.';
end
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

function label = betterLabel(valueA, valueB, labelA, labelB)
if isfinite(valueA) && isfinite(valueB)
    if valueA < valueB
        label = labelA;
    elseif valueB < valueA
        label = labelB;
    else
        label = 'tie';
    end
else
    label = 'inconclusive';
end
end

function appendRunNotes(notesPath, withinTbl, rankTbl, modeAggTbl, scenarioTbl)
fid = fopen(notesPath, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

bestWithin = bestFiniteRow(withinTbl, 'mean_pairwise_rmse', 'ascend');
bestRank = bestFiniteRow(rankTbl, 'mode1_explained_variance', 'descend');
bestMode = bestFiniteRow(modeAggTbl, 'mean_cosine_similarity', 'descend');
dipOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_dip_overlap", :);
fmOverlap = scenarioTbl(string(scenarioTbl.scenario_name) == "tau_fm_overlap", :);

if ~isempty(bestWithin)
    fprintf(fid, 'Best within-Tp collapse: T_p = %.0f K, RMSE = %.4f\n', bestWithin.Tp, bestWithin.mean_pairwise_rmse);
end
if ~isempty(bestRank)
    fprintf(fid, 'Best rank-1 score: T_p = %.0f K, EV1 = %.4f\n', bestRank.Tp, bestRank.mode1_explained_variance);
end
if ~isempty(bestMode)
    fprintf(fid, 'Best mode stability: T_p = %.0f K, mean cosine = %.4f\n', bestMode.Tp, bestMode.mean_cosine_similarity);
end
if ~isempty(dipOverlap)
    fprintf(fid, 'tau_dip overlap RMSE = %.4f, variance = %.5f\n', ...
        dipOverlap.mean_pairwise_rmse, dipOverlap.mean_profile_variance);
end
if ~isempty(fmOverlap)
    fprintf(fid, 'tau_FM overlap RMSE = %.4f, variance = %.5f\n', ...
        fmOverlap.mean_pairwise_rmse, fmOverlap.mean_profile_variance);
end
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
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function values = extractFirstNumericColumn(tbl)
values = table2array(tbl(:, 1));
if ~isnumeric(values)
    values = str2double(string(values));
end
end

function highlightTp(ax, x, y, targetTp)
mask = abs(x - targetTp) < 1e-9;
if any(mask)
    plot(ax, x(mask), y(mask), 'o', 'Color', [0.20 0.20 0.20], ...
        'MarkerFaceColor', [1 0.85 0.2], 'MarkerSize', 10, 'LineWidth', 1.4, ...
        'HandleVisibility', 'off');
end
end

function highlightDualAxisTp(ax, x, yLeft, yRight, targetTp)
mask = abs(x - targetTp) < 1e-9;
if ~any(mask)
    return;
end
yyaxis(ax, 'left');
plot(ax, x(mask), yLeft(mask), 'o', 'Color', [0.20 0.20 0.20], ...
    'MarkerFaceColor', [1 0.85 0.2], 'MarkerSize', 10, 'LineWidth', 1.4, ...
    'HandleVisibility', 'off');
yyaxis(ax, 'right');
plot(ax, x(mask), yRight(mask), 'o', 'Color', [0.20 0.20 0.20], ...
    'MarkerFaceColor', [1 0.85 0.2], 'MarkerSize', 10, 'LineWidth', 1.4, ...
    'HandleVisibility', 'off');
end

function lims = paddedLimits(values)
values = values(isfinite(values));
if isempty(values)
    lims = [0, 1];
    return;
end
vMin = min(values);
vMax = max(values);
if abs(vMax - vMin) < 1e-12
    pad = max(abs(vMax), 1) * 0.1;
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
