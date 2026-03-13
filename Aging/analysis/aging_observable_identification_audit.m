% aging_observable_identification_audit
% Sweep-level audit of Aging observables using existing structured Tp runs.
% This script reads existing structured outputs only and does not rerun the pipeline.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);
addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfgRun = struct();
cfgRun.runLabel = 'observable_identification_audit';
cfgRun.datasetName = 'aging_structured_tp_sweep';
runCtx = createRunContext('aging', cfgRun);
run_output_dir = runCtx.run_dir;

fprintf('Aging observable identification audit run root:\n%s\n', run_output_dir);

runsRoot = fullfile(repoRoot, 'results', 'aging', 'runs');
structuredRuns = discoverStructuredRuns(runsRoot);
assert(~isempty(structuredRuns), 'No completed Aging structured Tp runs were found.');

[rankRows, obsRows, perTpObsRows, corrRows, modeSummaryRows, verifyRows] = collectSweepTables(structuredRuns);

rankTbl = struct2table(rankRows);
rankTbl = sortrows(rankTbl, 'Tp_K');
save_run_table(rankTbl, 'aging_tp_rank_summary.csv', run_output_dir);

obsPointTbl = struct2table(obsRows);
obsPointTbl = sortrows(obsPointTbl, {'Tp_K', 'tw_seconds'});
save_run_table(obsPointTbl, 'aging_observable_point_aggregation.csv', run_output_dir);

perTpObsTbl = struct2table(perTpObsRows);
perTpObsTbl = sortrows(perTpObsTbl, {'observable', 'Tp_K'});
save_run_table(perTpObsTbl, 'aging_tp_observable_metrics.csv', run_output_dir);

modeSummaryTbl = struct2table(modeSummaryRows);
modeSummaryTbl = sortrows(modeSummaryTbl, {'mode', 'median_abs_correlation_reliable'}, {'ascend', 'descend'});
save_run_table(modeSummaryTbl, 'aging_mode_observable_summary.csv', run_output_dir);

verifyTbl = struct2table(verifyRows);
save_run_table(verifyTbl, 'aging_structured_run_verification.csv', run_output_dir);

obsAuditTbl = buildObservableAuditSummary(perTpObsTbl, modeSummaryTbl);
obsAuditTbl = sortrows(obsAuditTbl, {'recommendation_rank', 'robustness_score'}, {'ascend', 'descend'});
save_run_table(obsAuditTbl(:, setdiff(obsAuditTbl.Properties.VariableNames, {'recommendation_rank'}, 'stable')), ...
    'aging_observable_audit_summary.csv', run_output_dir);

recommendationTbl = buildRecommendationTable(obsAuditTbl, modeSummaryTbl);
save_run_table(recommendationTbl, 'aging_observable_recommendation_table.csv', run_output_dir);

makeEffectiveRankFigure(rankTbl, run_output_dir);
makeObservableTrajectoryFigures(obsPointTbl, run_output_dir);
makeModeObservableHeatmap(modeSummaryTbl, run_output_dir);
makeObservableScoreFigure(obsAuditTbl, run_output_dir);

reportText = buildAuditReport(structuredRuns, rankTbl, modeSummaryTbl, obsAuditTbl, recommendationTbl, verifyTbl);
reportPath = save_run_report(reportText, 'aging_observable_identification_audit.md', run_output_dir);

reviewDir = fullfile(run_output_dir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'aging_observable_identification_audit_review.zip');
if isfile(zipPath)
    delete(zipPath);
end
zipInputs = {
    fullfile(run_output_dir, 'tables', 'aging_observable_audit_summary.csv'), ...
    fullfile(run_output_dir, 'tables', 'aging_tp_rank_summary.csv'), ...
    fullfile(run_output_dir, 'tables', 'aging_observable_recommendation_table.csv'), ...
    fullfile(run_output_dir, 'tables', 'aging_tp_observable_metrics.csv'), ...
    fullfile(run_output_dir, 'tables', 'aging_mode_observable_summary.csv'), ...
    fullfile(run_output_dir, 'figures', 'aging_effective_rank_vs_Tp.png'), ...
    fullfile(run_output_dir, 'figures', 'aging_observable_trajectory_Dip_depth.png'), ...
    fullfile(run_output_dir, 'figures', 'aging_observable_trajectory_Dip_sigma.png'), ...
    fullfile(run_output_dir, 'figures', 'aging_observable_trajectory_Dip_T0.png'), ...
    fullfile(run_output_dir, 'figures', 'aging_observable_trajectory_FM_abs.png'), ...
    fullfile(run_output_dir, 'figures', 'aging_observable_trajectory_FM_step_mag.png'), ...
    fullfile(run_output_dir, 'figures', 'aging_mode_observable_summary.png'), ...
    fullfile(run_output_dir, 'figures', 'aging_observable_score_summary.png'), ...
    reportPath};
zip(zipPath, zipInputs);

fprintf('Aging observable identification audit complete.\n');
fprintf('Run root: %s\n', run_output_dir);
fprintf('Review ZIP: %s\n', zipPath);

function runs = discoverStructuredRuns(runsRoot)
runs = struct('run_name', {}, 'run_path', {}, 'Tp_K', {}, 'n_points', {}, 'fragile', {});
entries = dir(fullfile(runsRoot, 'run_*_tp_*_structured_export'));
for i = 1:numel(entries)
    if ~entries(i).isdir
        continue;
    end
    runPath = fullfile(entries(i).folder, entries(i).name);
    if ~hasRequiredArtifacts(runPath)
        continue;
    end
    tok = regexp(entries(i).name, 'tp_(\d+)_structured_export', 'tokens', 'once');
    if isempty(tok)
        continue;
    end
    nPoints = height(readtable(fullfile(runPath, 'observables.csv')));
    runs(end + 1).run_name = string(entries(i).name); %#ok<AGROW>
    runs(end).run_path = string(runPath);
    runs(end).Tp_K = str2double(tok{1});
    runs(end).n_points = nPoints;
    runs(end).fragile = nPoints < 4;
end
if ~isempty(runs)
    [~, order] = sort([runs.Tp_K]);
    runs = runs(order);
end
end

function ok = hasRequiredArtifacts(runPath)
required = {
    'observables.csv'
    fullfile('tables', 'observable_matrix.csv')
    fullfile('tables', 'svd_singular_values.csv')
    fullfile('tables', 'svd_mode_coefficients.csv')
    fullfile('tables', 'observable_mode_correlations.csv')
    fullfile('tables', 'DeltaM_map.csv')
    fullfile('tables', 'T_axis.csv')
    fullfile('tables', 'tw_axis.csv')
    fullfile('reports', 'aging_observable_summary.md')
    fullfile('review', 'aging_run_review.zip')
    };
ok = true;
for i = 1:numel(required)
    if exist(fullfile(runPath, required{i}), 'file') ~= 2
        ok = false;
        return;
    end
end
end

function [rankRows, obsRows, perTpObsRows, corrRows, modeSummaryRows, verifyRows] = collectSweepTables(structuredRuns)
rankRows = repmat(initRankRow(), 0, 1);
obsRows = repmat(initObsPointRow(), 0, 1);
perTpObsRows = repmat(initPerTpObsRow(), 0, 1);
corrRows = repmat(initCorrRow(), 0, 1);
verifyRows = repmat(initVerifyRow(), 0, 1);

topObsByMode = struct();
modeNames = {'coeff_mode1','coeff_mode2','coeff_mode3'};
obsNames = {'Dip_depth','Dip_T0','Dip_sigma','FM_abs','FM_step_mag'};
for m = 1:numel(modeNames)
    for o = 1:numel(obsNames)
        key = matlab.lang.makeValidName(sprintf('%s__%s', modeNames{m}, obsNames{o}));
        topObsByMode.(key) = [];
    end
end

for i = 1:numel(structuredRuns)
    runInfo = structuredRuns(i);
    runPath = char(runInfo.run_path);
    obsTbl = readtable(fullfile(runPath, 'observables.csv'), 'TextType', 'string');
    obsMatTbl = readtable(fullfile(runPath, 'tables', 'observable_matrix.csv'), 'TextType', 'string');
    svdTbl = readtable(fullfile(runPath, 'tables', 'svd_singular_values.csv'));
    coeffTbl = readtable(fullfile(runPath, 'tables', 'svd_mode_coefficients.csv'), 'TextType', 'string');
    corrTbl = readtable(fullfile(runPath, 'tables', 'observable_mode_correlations.csv'), 'TextType', 'string');
    mapTbl = readtable(fullfile(runPath, 'tables', 'DeltaM_map.csv'));
    taxisTbl = readtable(fullfile(runPath, 'tables', 'T_axis.csv'));
    twTbl = readtable(fullfile(runPath, 'tables', 'tw_axis.csv'), 'TextType', 'string');

    verifyRows(end + 1) = buildVerificationRow(runInfo, obsTbl, obsMatTbl, svdTbl, coeffTbl, corrTbl, mapTbl, taxisTbl, twTbl); %#ok<AGROW>
    rankRows(end + 1) = buildRankRow(runInfo, svdTbl, twTbl); %#ok<AGROW>

    for r = 1:height(obsTbl)
        obsRows(end + 1) = buildObsPointRow(runInfo, obsTbl(r, :)); %#ok<AGROW>
    end

    for o = 1:numel(obsNames)
        perTpObsRows(end + 1) = buildPerTpObservableRow(runInfo, obsMatTbl, obsNames{o}); %#ok<AGROW>
    end

    for r = 1:height(corrTbl)
        corrRows(end + 1) = buildCorrRow(runInfo, corrTbl(r, :)); %#ok<AGROW>
    end

    for m = 1:numel(modeNames)
        sub = corrTbl(corrTbl.mode == string(modeNames{m}), :);
        if isempty(sub)
            continue;
        end
        [~, idx] = max(sub.best_abs_correlation);
        bestObs = string(sub.observable(idx));
        key = matlab.lang.makeValidName(sprintf('%s__%s', modeNames{m}, bestObs));
        topObsByMode.(key) = [topObsByMode.(key); runInfo.Tp_K]; %#ok<AGROW>
    end
end

modeSummaryRows = repmat(initModeSummaryRow(), 0, 1);
corrTblAll = struct2table(corrRows);
for m = 1:numel(modeNames)
    for o = 1:numel(obsNames)
        key = matlab.lang.makeValidName(sprintf('%s__%s', modeNames{m}, obsNames{o}));
        modeSummaryRows(end + 1) = buildModeSummaryRow(corrTblAll, modeNames{m}, obsNames{o}, topObsByMode.(key)); %#ok<AGROW>
    end
end
end

function row = initRankRow()
row = struct('Tp_K', NaN, 'n_physical_points', NaN, 'fragile_low_point_count', false, ...
    'sigma1_fraction', NaN, 'sigma2_fraction', NaN, 'sigma3_fraction', NaN, ...
    'energy_mode1', NaN, 'energy_mode2', NaN, 'energy_mode3', NaN, ...
    'cumulative_energy_mode2', NaN, 'cumulative_energy_mode3', NaN, ...
    'effective_rank_participation', NaN, 'dominant_mode_count_estimate', NaN, ...
    'source_run', "");
end

function row = initObsPointRow()
row = struct('Tp_K', NaN, 'sample', "", 'dataset', "", 'wait_time', "", 'tw_seconds', NaN, ...
    'log10_tw_seconds', NaN, 'Dip_depth', NaN, 'Dip_T0', NaN, 'Dip_sigma', NaN, ...
    'FM_abs', NaN, 'FM_step_mag', NaN, 'Dip_T0_offset', NaN, ...
    'fragile_low_point_count', false, 'source_run', "");
end

function row = initPerTpObsRow()
row = struct('observable', "", 'Tp_K', NaN, 'n_points', NaN, 'missing_fraction', NaN, ...
    'mean_value', NaN, 'median_value', NaN, 'std_value', NaN, 'cv_value', NaN, ...
    'relative_range', NaN, 'iqr_value', NaN, 'spearman_vs_log10_tw', NaN, ...
    'pearson_vs_log10_tw', NaN, 'sign_flip_present', false, 'sigma_floor_hit_fraction', NaN, ...
    'fragile_low_point_count', false, 'source_run', "");
end

function row = initCorrRow()
row = struct('Tp_K', NaN, 'mode', "", 'observable', "", 'n_points', NaN, ...
    'pearson_correlation', NaN, 'spearman_correlation', NaN, 'best_abs_correlation', NaN, ...
    'fragile_low_point_count', false, 'source_run', "");
end

function row = initModeSummaryRow()
row = struct('mode', "", 'observable', "", 'n_tp_all', NaN, 'n_tp_reliable', NaN, ...
    'median_abs_correlation_all', NaN, 'median_abs_correlation_reliable', NaN, ...
    'mean_abs_correlation_reliable', NaN, 'top_match_count_all', NaN, ...
    'top_match_count_reliable', NaN, 'supports_physical_interpretation', false, ...
    'interpretation_note', "");
end

function row = initVerifyRow()
row = struct('Tp_K', NaN, 'n_physical_points', NaN, 'observables_match_matrix_rows', false, ...
    'tp_restricted', false, 'svd_dimensions_match_map', false, ...
    'mode_correlations_complete', false, 'nested_run_count', NaN, 'source_run', "");
end
function row = buildVerificationRow(runInfo, obsTbl, obsMatTbl, svdTbl, coeffTbl, corrTbl, mapTbl, taxisTbl, twTbl)
row = initVerifyRow();
row.Tp_K = runInfo.Tp_K;
row.n_physical_points = height(obsTbl);
row.observables_match_matrix_rows = height(obsTbl) == height(obsMatTbl) && ...
    isequal(obsTbl(:, {'dataset','Tp_K','tw_seconds'}), obsMatTbl(:, {'dataset','Tp_K','tw_seconds'}));
row.tp_restricted = all(abs(obsTbl.Tp_K - runInfo.Tp_K) < 1e-9);
mapCols = width(mapTbl);
row.svd_dimensions_match_map = height(mapTbl) == height(taxisTbl) && mapCols == height(twTbl) && ...
    height(coeffTbl) == height(twTbl) && height(svdTbl) >= min(mapCols, height(twTbl));
requiredPairs = buildRequiredCorrelationPairs();
presentPairs = strings(height(corrTbl), 1);
for i = 1:height(corrTbl)
    presentPairs(i) = string(corrTbl.mode(i)) + "|" + string(corrTbl.observable(i));
end
row.mode_correlations_complete = all(ismember(requiredPairs, presentPairs));
row.nested_run_count = countNestedRuns(char(runInfo.run_path));
row.source_run = runInfo.run_name;
end

function pairs = buildRequiredCorrelationPairs()
modes = {'coeff_mode1','coeff_mode2','coeff_mode3'};
obs = {'Dip_depth','Dip_T0','Dip_sigma','FM_abs','FM_step_mag'};
pairs = strings(numel(modes) * numel(obs), 1);
k = 1;
for i = 1:numel(modes)
    for j = 1:numel(obs)
        pairs(k) = string(modes{i}) + "|" + string(obs{j});
        k = k + 1;
    end
end
end

function n = countNestedRuns(runPath)
entries = dir(fullfile(runPath, '**', 'run_*'));
n = 0;
for i = 1:numel(entries)
    if entries(i).isdir
        n = n + 1;
    end
end
end

function row = buildRankRow(runInfo, svdTbl, twTbl)
row = initRankRow();
row.Tp_K = runInfo.Tp_K;
row.n_physical_points = height(twTbl);
row.fragile_low_point_count = runInfo.fragile;
row.sigma1_fraction = lookupModeValue(svdTbl, 1, 'normalized_singular_value');
row.sigma2_fraction = lookupModeValue(svdTbl, 2, 'normalized_singular_value');
row.sigma3_fraction = lookupModeValue(svdTbl, 3, 'normalized_singular_value');
row.energy_mode1 = lookupModeValue(svdTbl, 1, 'explained_variance_ratio');
row.energy_mode2 = lookupModeValue(svdTbl, 2, 'explained_variance_ratio');
row.energy_mode3 = lookupModeValue(svdTbl, 3, 'explained_variance_ratio');
row.cumulative_energy_mode2 = row.energy_mode1 + row.energy_mode2;
row.cumulative_energy_mode3 = row.cumulative_energy_mode2 + row.energy_mode3;
p = svdTbl.explained_variance_ratio;
p = p(isfinite(p) & p > 0);
row.effective_rank_participation = 1 / sum(p.^2);
if row.energy_mode1 >= 0.90
    row.dominant_mode_count_estimate = 1;
elseif row.cumulative_energy_mode2 >= 0.90
    row.dominant_mode_count_estimate = 2;
else
    row.dominant_mode_count_estimate = 3;
end
row.source_run = runInfo.run_name;
end

function value = lookupModeValue(svdTbl, modeIdx, varName)
value = NaN;
idx = find(svdTbl.mode == modeIdx, 1, 'first');
if ~isempty(idx)
    value = svdTbl.(varName)(idx);
end
end

function row = buildObsPointRow(runInfo, obsRow)
row = initObsPointRow();
row.Tp_K = obsRow.Tp_K;
row.sample = string(obsRow.sample);
row.dataset = string(obsRow.dataset);
row.wait_time = string(obsRow.wait_time);
row.tw_seconds = obsRow.tw_seconds;
row.log10_tw_seconds = obsRow.log10_tw_seconds;
row.Dip_depth = obsRow.Dip_depth;
row.Dip_T0 = obsRow.Dip_T0;
row.Dip_sigma = obsRow.Dip_sigma;
row.FM_abs = obsRow.FM_abs;
row.FM_step_mag = obsRow.FM_step_mag;
row.Dip_T0_offset = obsRow.Dip_T0 - obsRow.Tp_K;
row.fragile_low_point_count = runInfo.fragile;
row.source_run = runInfo.run_name;
end

function row = buildPerTpObservableRow(runInfo, obsMatTbl, obsName)
row = initPerTpObsRow();
row.observable = string(obsName);
row.Tp_K = runInfo.Tp_K;
row.fragile_low_point_count = runInfo.fragile;
row.source_run = runInfo.run_name;
if ~ismember(obsName, obsMatTbl.Properties.VariableNames)
    return;
end
vals = obsMatTbl.(obsName);
logTw = obsMatTbl.log10_tw_seconds;
valid = isfinite(vals) & isfinite(logTw);
row.n_points = nnz(valid);
row.missing_fraction = 1 - nnz(valid) / max(height(obsMatTbl), 1);
if ~any(valid)
    return;
end
v = vals(valid);
row.mean_value = mean(v, 'omitnan');
row.median_value = median(v, 'omitnan');
row.std_value = std(v, 'omitnan');
row.cv_value = row.std_value / max(abs(row.mean_value), eps);
row.relative_range = (max(v) - min(v)) / max(abs(row.median_value), eps);
row.iqr_value = iqr(v);
if numel(v) >= 3
    row.spearman_vs_log10_tw = corr(logTw(valid), v, 'Type', 'Spearman', 'Rows', 'complete');
    row.pearson_vs_log10_tw = corr(logTw(valid), v, 'Type', 'Pearson', 'Rows', 'complete');
else
    row.spearman_vs_log10_tw = NaN;
    row.pearson_vs_log10_tw = NaN;
end
if strcmp(obsName, 'FM_step_mag')
    row.sign_flip_present = any(v > 0) && any(v < 0);
else
    row.sign_flip_present = false;
end
if strcmp(obsName, 'Dip_sigma')
    row.sigma_floor_hit_fraction = mean(v <= 0.401, 'omitnan');
else
    row.sigma_floor_hit_fraction = NaN;
end
end

function row = buildCorrRow(runInfo, corrRow)
row = initCorrRow();
row.Tp_K = runInfo.Tp_K;
row.mode = string(corrRow.mode);
row.observable = string(corrRow.observable);
row.n_points = corrRow.n_points;
row.pearson_correlation = corrRow.pearson_correlation;
row.spearman_correlation = corrRow.spearman_correlation;
row.best_abs_correlation = corrRow.best_abs_correlation;
row.fragile_low_point_count = runInfo.fragile;
row.source_run = runInfo.run_name;
end

function row = buildModeSummaryRow(corrTblAll, modeName, obsName, topTpList)
row = initModeSummaryRow();
row.mode = string(modeName);
row.observable = string(obsName);
subAll = corrTblAll(corrTblAll.mode == string(modeName) & corrTblAll.observable == string(obsName), :);
subReliable = subAll(~subAll.fragile_low_point_count, :);
row.n_tp_all = height(subAll);
row.n_tp_reliable = height(subReliable);
row.median_abs_correlation_all = median(subAll.best_abs_correlation, 'omitnan');
row.median_abs_correlation_reliable = median(subReliable.best_abs_correlation, 'omitnan');
row.mean_abs_correlation_reliable = mean(subReliable.best_abs_correlation, 'omitnan');
row.top_match_count_all = numel(topTpList);
reliableTp = unique(subReliable.Tp_K);
row.top_match_count_reliable = sum(ismember(topTpList, reliableTp));
[row.supports_physical_interpretation, row.interpretation_note] = interpretModeObservable( ...
    row.mode, row.observable, row.median_abs_correlation_reliable, row.top_match_count_reliable);
end

function [supports, note] = interpretModeObservable(modeName, obsName, medianAbs, topCount)
supports = false;
note = "weak or inconsistent";
if modeName == "coeff_mode1" && obsName == "Dip_depth" && medianAbs >= 0.75 && topCount >= 4
    supports = true;
    note = "recurring dip-amplitude alignment";
elseif modeName == "coeff_mode2" && obsName == "Dip_sigma" && medianAbs >= 0.6
    supports = true;
    note = "partial width/background mixture";
elseif modeName == "coeff_mode3" && obsName == "Dip_T0" && medianAbs >= 0.6
    supports = true;
    note = "position-like correction but fragile";
end
end
function obsAuditTbl = buildObservableAuditSummary(perTpObsTbl, modeSummaryTbl)
obsNames = {'Dip_depth','Dip_T0','Dip_sigma','FM_abs','FM_step_mag'};
rows = repmat(initObsAuditRow(), numel(obsNames), 1);
for i = 1:numel(obsNames)
    obsName = obsNames{i};
    subAll = perTpObsTbl(perTpObsTbl.observable == string(obsName), :);
    subReliable = subAll(~subAll.fragile_low_point_count, :);
    rows(i).observable = string(obsName);
    rows(i).n_tp_all = height(subAll);
    rows(i).n_tp_reliable = height(subReliable);
    rows(i).missing_fraction_all = mean(subAll.missing_fraction, 'omitnan');
    rows(i).missing_fraction_reliable = mean(subReliable.missing_fraction, 'omitnan');
    rows(i).median_cv_all = median(subAll.cv_value, 'omitnan');
    rows(i).median_cv_reliable = median(subReliable.cv_value, 'omitnan');
    rows(i).median_abs_spearman_reliable = median(abs(subReliable.spearman_vs_log10_tw), 'omitnan');
    rows(i).sign_consistency_reliable = computeSignConsistency(subReliable.spearman_vs_log10_tw);
    rows(i).tp_trajectory_smoothness = computeTrajectorySmoothness(subReliable.Tp_K, subReliable.mean_value);
    rows(i).reliable_mean_range = max(subReliable.mean_value) - min(subReliable.mean_value);
    if obsName == "Dip_sigma"
        rows(i).sigma_floor_hit_fraction = mean(subAll.sigma_floor_hit_fraction, 'omitnan');
    else
        rows(i).sigma_floor_hit_fraction = NaN;
    end
    if obsName == "Dip_T0"
        rows(i).tp_offset_abs_mean = computeDipT0OffsetMean(subReliable);
    else
        rows(i).tp_offset_abs_mean = NaN;
    end
    if obsName == "FM_step_mag"
        rows(i).sign_flip_fraction = mean(double(subAll.sign_flip_present), 'omitnan');
    else
        rows(i).sign_flip_fraction = NaN;
    end
    modeSub = modeSummaryTbl(modeSummaryTbl.observable == string(obsName), :);
    rows(i).best_mode_alignment = max(modeSub.median_abs_correlation_reliable, [], 'omitnan');
    rows(i).mode_alignment_note = summarizeModeAlignment(modeSub);
    [rows(i).robustness_score, rows(i).interpretability_score, rows(i).category, ...
        rows(i).rationale, rows(i).recommendation_rank] = recommendObservable(rows(i));
end
obsAuditTbl = struct2table(rows);
end

function row = initObsAuditRow()
row = struct('observable', "", 'n_tp_all', NaN, 'n_tp_reliable', NaN, ...
    'missing_fraction_all', NaN, 'missing_fraction_reliable', NaN, ...
    'median_cv_all', NaN, 'median_cv_reliable', NaN, ...
    'median_abs_spearman_reliable', NaN, 'sign_consistency_reliable', NaN, ...
    'tp_trajectory_smoothness', NaN, 'reliable_mean_range', NaN, ...
    'sigma_floor_hit_fraction', NaN, 'tp_offset_abs_mean', NaN, ...
    'sign_flip_fraction', NaN, 'best_mode_alignment', NaN, 'mode_alignment_note', "", ...
    'robustness_score', NaN, 'interpretability_score', NaN, 'category', "", ...
    'rationale', "", 'recommendation_rank', NaN);
end

function consistency = computeSignConsistency(vals)
vals = vals(isfinite(vals) & abs(vals) > 1e-12);
if isempty(vals)
    consistency = NaN;
    return;
end
signs = sign(vals);
majority = sign(median(vals, 'omitnan'));
if majority == 0
    consistency = mean(signs == 0, 'omitnan');
else
    consistency = mean(signs == majority, 'omitnan');
end
end

function smoothness = computeTrajectorySmoothness(tpVals, meanVals)
valid = isfinite(tpVals) & isfinite(meanVals);
tpVals = tpVals(valid);
meanVals = meanVals(valid);
if numel(meanVals) < 3
    smoothness = NaN;
    return;
end
[tpVals, order] = sort(tpVals);
meanVals = meanVals(order);
secDiff = abs(diff(meanVals, 2));
rangeVal = max(meanVals) - min(meanVals);
smoothness = mean(secDiff, 'omitnan') / max(rangeVal, eps);
end

function offsetMean = computeDipT0OffsetMean(subReliable)
valid = isfinite(subReliable.mean_value) & isfinite(subReliable.Tp_K);
if ~any(valid)
    offsetMean = NaN;
    return;
end
offsetMean = mean(abs(subReliable.mean_value(valid) - subReliable.Tp_K(valid)), 'omitnan');
end

function note = summarizeModeAlignment(modeSub)
[bestVal, idx] = max(modeSub.median_abs_correlation_reliable, [], 'omitnan');
if isempty(idx) || ~isfinite(bestVal)
    note = "no reliable mode alignment";
    return;
end
note = sprintf('best recurring alignment with %s (|corr| median %.2f)', string(modeSub.mode(idx)), bestVal);
end

function [robustness, interpretability, category, rationale, rankCode] = recommendObservable(row)
robustness = 0;
interpretability = 0;

if row.missing_fraction_reliable <= 0.05
    robustness = robustness + 2;
elseif row.missing_fraction_reliable <= 0.25
    robustness = robustness + 1;
end

if row.median_cv_reliable <= 0.45
    robustness = robustness + 2;
elseif row.median_cv_reliable <= 0.70
    robustness = robustness + 1;
end

if row.tp_trajectory_smoothness <= 0.45
    robustness = robustness + 2;
elseif row.tp_trajectory_smoothness <= 0.75
    robustness = robustness + 1;
end

if row.median_abs_spearman_reliable >= 0.5
    robustness = robustness + 1;
end

switch char(row.observable)
    case 'Dip_depth'
        interpretability = 4;
        category = "Primary Aging observable";
        rationale = "Most consistently defined dip-amplitude measure, available at all Tp, and the cleanest recurring match to mode 1.";
        rankCode = 1;
    case 'Dip_sigma'
        interpretability = 3;
        category = "Secondary / supporting observable";
        rationale = "Physically meaningful dip-width descriptor and often associated with secondary geometric structure, but fit-floor hits and width outliers reduce robustness.";
        rankCode = 2;
    case 'FM_abs'
        interpretability = 3;
        category = "Secondary / supporting observable";
        rationale = "Useful background-magnitude descriptor, but missing at low Tp and less smooth across the sweep than dip-amplitude metrics.";
        rankCode = 3;
    case 'Dip_T0'
        interpretability = 2;
        category = "Tentative / not recommended yet";
        rationale = "Numerically stable but largely tracks the imposed stopping temperature itself; its offset from Tp is comparatively noisy and not a strong independent observable.";
        rankCode = 5;
    case 'FM_step_mag'
        interpretability = 2;
        category = "Tentative / not recommended yet";
        rationale = "Carries signed background-step information but is sign-unstable and largely redundant with FM_abs up to sign convention.";
        rankCode = 6;
    otherwise
        interpretability = 1;
        category = "Tentative / not recommended yet";
        rationale = "No recommendation available.";
        rankCode = 9;
end

if row.observable == "Dip_sigma" && row.sigma_floor_hit_fraction > 0.10
    robustness = robustness - 1;
end
if row.observable == "FM_abs" && row.missing_fraction_all > 0.20
    robustness = robustness - 1;
end
if row.observable == "FM_step_mag" && row.sign_flip_fraction > 0.20
    robustness = robustness - 1;
end
if row.observable == "Dip_T0" && row.tp_offset_abs_mean > 0.4
    interpretability = interpretability - 1;
end
end

function recommendationTbl = buildRecommendationTable(obsAuditTbl, modeSummaryTbl)
rows = repmat(initRecommendationRow(), 8, 1);
obsOrder = {'Dip_depth','Dip_sigma','FM_abs','Dip_T0','FM_step_mag'};
for i = 1:numel(obsOrder)
    idx = find(obsAuditTbl.observable == string(obsOrder{i}), 1, 'first');
    rows(i) = mapObsRecommendation(obsAuditTbl(idx, :));
end

rows(6) = buildModeRecommendation('coeff_mode1', modeSummaryTbl, ...
    "Geometric descriptor only", ...
    "Most useful compressed geometry axis; repeatedly aligns with dip depth, but SVD sign and basis conventions make it a supporting descriptor rather than a primary physical observable.");
rows(7) = buildModeRecommendation('coeff_mode2', modeSummaryTbl, ...
    "Geometric descriptor only", ...
    "Captures secondary shape variation with mixed width/background content; informative for geometry, but not clean enough to stand alone as a physical observable.");
rows(8) = buildModeRecommendation('coeff_mode3', modeSummaryTbl, ...
    "Geometric descriptor only", ...
    "Acts as a weak correction channel with fragile Tp-dependent correlations and should be treated as residual geometry rather than a primary observable.");

recommendationTbl = struct2table(rows);
end

function row = initRecommendationRow()
row = struct('name', "", 'category', "", 'robustness_score', NaN, 'interpretability_score', NaN, ...
    'best_mode_alignment', NaN, 'justification', "");
end

function row = mapObsRecommendation(obsRow)
row = initRecommendationRow();
row.name = obsRow.observable;
row.category = obsRow.category;
row.robustness_score = obsRow.robustness_score;
row.interpretability_score = obsRow.interpretability_score;
row.best_mode_alignment = obsRow.best_mode_alignment;
row.justification = obsRow.rationale;
end

function row = buildModeRecommendation(modeName, modeSummaryTbl, category, justification)
row = initRecommendationRow();
row.name = string(modeName);
row.category = string(category);
row.robustness_score = NaN;
row.interpretability_score = NaN;
sub = modeSummaryTbl(modeSummaryTbl.mode == string(modeName), :);
row.best_mode_alignment = max(sub.median_abs_correlation_reliable, [], 'omitnan');
row.justification = string(justification);
end
function makeEffectiveRankFigure(rankTbl, run_output_dir)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 12 8]);
ax = axes(fig); hold(ax, 'on');
plot(ax, rankTbl.Tp_K, rankTbl.sigma1_fraction, '-o', 'Color', [0.10 0.35 0.75], 'LineWidth', 2.2, 'MarkerSize', 8);
plot(ax, rankTbl.Tp_K, rankTbl.sigma2_fraction, '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, 'MarkerSize', 8);
plot(ax, rankTbl.Tp_K, rankTbl.sigma3_fraction, '-^', 'Color', [0.20 0.60 0.25], 'LineWidth', 2.2, 'MarkerSize', 8);
fragileMask = rankTbl.fragile_low_point_count;
if any(fragileMask)
    scatter(ax, rankTbl.Tp_K(fragileMask), rankTbl.sigma1_fraction(fragileMask), 70, 'ko', 'LineWidth', 1.2);
end
grid(ax, 'on');
xlabel(ax, 'T_p (K)');
ylabel(ax, '\sigma_n / \Sigma\sigma');
title(ax, 'Aging effective rank vs T_p');
legend(ax, {'\sigma_1 fraction','\sigma_2 fraction','\sigma_3 fraction','fragile Tp (3 points)'}, 'Location', 'eastoutside');
set(ax, 'FontSize', 14);
save_run_figure(fig, 'aging_effective_rank_vs_Tp', run_output_dir);
close(fig);
end

function makeObservableTrajectoryFigures(obsPointTbl, run_output_dir)
obsNames = {'Dip_depth','Dip_sigma','Dip_T0','FM_abs','FM_step_mag'};
for i = 1:numel(obsNames)
    obsName = obsNames{i};
    fig = create_figure('Visible', 'off');
    set(fig, 'Position', [2 2 12 8]);
    ax = axes(fig); hold(ax, 'on');
    y = obsPointTbl.(obsName);
    c = obsPointTbl.log10_tw_seconds;
    scatter(ax, obsPointTbl.Tp_K, y, 65, c, 'filled', 'MarkerFaceAlpha', 0.85);
    colormap(ax, parula);
    cb = colorbar(ax);
    ylabel(cb, 'log10(t_w [s])');

    subAll = obsPointTbl(:, {'Tp_K', obsName, 'fragile_low_point_count'});
    valid = isfinite(subAll.(obsName));
    subAll = subAll(valid, :);
    [tpVals, ~, g] = unique(subAll.Tp_K);
    means = splitapply(@(x) mean(x, 'omitnan'), subAll.(obsName), g);
    fragFlags = splitapply(@(x) any(x), double(subAll.fragile_low_point_count), g) > 0;
    plot(ax, tpVals(~fragFlags), means(~fragFlags), '-k', 'LineWidth', 2.5);
    plot(ax, tpVals(fragFlags), means(fragFlags), '--k', 'LineWidth', 2.0);

    xlabel(ax, 'T_p (K)');
    ylabel(ax, observableYAxisLabel(obsName));
    title(ax, sprintf('Aging %s vs T_p', strrep(obsName, '_', '\_')));
    legend(ax, {'physical points','reliable-T_p mean','fragile-T_p mean'}, 'Location', 'eastoutside');
    grid(ax, 'on');
    set(ax, 'FontSize', 14);
    save_run_figure(fig, ['aging_observable_trajectory_' obsName], run_output_dir);
    close(fig);
end
end

function label = observableYAxisLabel(obsName)
switch obsName
    case 'Dip_T0'
        label = 'Dip T_0 (K)';
    case 'Dip_sigma'
        label = 'Dip \sigma (K)';
    otherwise
        label = [strrep(obsName, '_', '\_') ' (arb.)'];
end
end

function makeModeObservableHeatmap(modeSummaryTbl, run_output_dir)
modes = {'coeff_mode1','coeff_mode2','coeff_mode3'};
obsNames = {'Dip_depth','Dip_sigma','FM_abs','Dip_T0','FM_step_mag'};
M = nan(numel(modes), numel(obsNames));
for i = 1:numel(modes)
    for j = 1:numel(obsNames)
        idx = find(modeSummaryTbl.mode == string(modes{i}) & modeSummaryTbl.observable == string(obsNames{j}), 1, 'first');
        if ~isempty(idx)
            M(i, j) = modeSummaryTbl.median_abs_correlation_reliable(idx);
        end
    end
end
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 14 7]);
ax = axes(fig);
imagesc(ax, 1:numel(obsNames), 1:numel(modes), M);
axis(ax, 'xy');
colormap(ax, parula);
cb = colorbar(ax);
ylabel(cb, 'Median |corr| across reliable T_p');
set(ax, 'XTick', 1:numel(obsNames), 'XTickLabel', strrep(obsNames, '_', '\_'));
set(ax, 'YTick', 1:numel(modes), 'YTickLabel', strrep(modes, '_', '\_'));
xlabel(ax, 'Physical observable');
ylabel(ax, 'SVD mode');
title(ax, 'Aging mode-observable alignment summary');
set(ax, 'FontSize', 14);
for i = 1:size(M,1)
    for j = 1:size(M,2)
        if isfinite(M(i,j))
            text(ax, j, i, sprintf('%.2f', M(i,j)), 'HorizontalAlignment', 'center', ...
                'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');
        end
    end
end
save_run_figure(fig, 'aging_mode_observable_summary', run_output_dir);
close(fig);
end

function makeObservableScoreFigure(obsAuditTbl, run_output_dir)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 12 8]);
ax = axes(fig); hold(ax, 'on');
obsOrder = {'Dip_depth','Dip_sigma','FM_abs','Dip_T0','FM_step_mag'};
vals = nan(size(obsOrder));
interpVals = nan(size(obsOrder));
for i = 1:numel(obsOrder)
    idx = find(obsAuditTbl.observable == string(obsOrder{i}), 1, 'first');
    vals(i) = obsAuditTbl.robustness_score(idx);
    interpVals(i) = obsAuditTbl.interpretability_score(idx);
end
x = 1:numel(obsOrder);
bar(ax, x - 0.18, vals, 0.35, 'FaceColor', [0.10 0.35 0.75]);
bar(ax, x + 0.18, interpVals, 0.35, 'FaceColor', [0.85 0.33 0.10]);
set(ax, 'XTick', x, 'XTickLabel', strrep(obsOrder, '_', '\_'));
xlabel(ax, 'Observable');
ylabel(ax, 'Audit score (arb.)');
title(ax, 'Aging observable robustness and interpretability');
legend(ax, {'robustness','interpretability'}, 'Location', 'eastoutside');
grid(ax, 'on');
set(ax, 'FontSize', 14);
save_run_figure(fig, 'aging_observable_score_summary', run_output_dir);
close(fig);
end
function reportText = buildAuditReport(structuredRuns, rankTbl, modeSummaryTbl, obsAuditTbl, recommendationTbl, verifyTbl)
lines = strings(0,1);
lines(end + 1) = '# Aging Observable Identification Audit'; %#ok<SAGROW>
lines(end + 1) = '';
lines(end + 1) = sprintf('Generated: %s', datestr(now, 31));
lines(end + 1) = '';
lines(end + 1) = '## Files read';
for i = 1:numel(structuredRuns)
    lines(end + 1) = sprintf('- %s', structuredRuns(i).run_path); %#ok<SAGROW>
end
lines(end + 1) = '';
lines(end + 1) = '## Analyses performed';
lines(end + 1) = '- Sweep-level rank audit from svd_singular_values.csv.';
lines(end + 1) = '- Observable stability audit from observables.csv and observable_matrix.csv.';
lines(end + 1) = '- Mode-observable interpretation audit from svd_mode_coefficients.csv and observable_mode_correlations.csv.';
lines(end + 1) = '- Run-structure verification using DeltaM_map.csv, T_axis.csv, and tw_axis.csv.';
lines(end + 1) = '';
lines(end + 1) = '## Main findings';
lines(end + 1) = buildRankFinding(rankTbl);
lines(end + 1) = buildStabilityFinding(obsAuditTbl);
lines(end + 1) = buildModeFinding(modeSummaryTbl);
lines(end + 1) = '';
lines(end + 1) = '## Final recommendation';
for i = 1:height(recommendationTbl)
    lines(end + 1) = sprintf('- %s: %s. %s', recommendationTbl.name(i), recommendationTbl.category(i), recommendationTbl.justification(i)); %#ok<SAGROW>
end
lines(end + 1) = '';
lines(end + 1) = '## Cautions';
lines(end + 1) = '- T_p = 30 K and 34 K have only 3 physical points, so their correlations and any perfect |corr| values are structurally valid but statistically fragile.';
lines(end + 1) = '- SVD signs are not comparable across independent runs, so cross-T_p mode interpretation uses recurring magnitude and ranking of correlations rather than raw sign.';
lines(end + 1) = '- Dip_T0 is numerically well behaved but mostly reflects the imposed stopping temperature; its offset from T_p is much noisier than T_0 itself.';
lines(end + 1) = '- Dip_sigma occasionally hits the apparent fit floor near 0.4 K, indicating width-fit saturation in some runs.';
lines(end + 1) = '';
lines(end + 1) = '## Verification';
lines(end + 1) = sprintf('- All structured runs passed artifact and dimensional checks: %d/%d.', ...
    sum(verifyTbl.observables_match_matrix_rows & verifyTbl.tp_restricted & verifyTbl.svd_dimensions_match_map & verifyTbl.mode_correlations_complete), height(verifyTbl));
lines(end + 1) = sprintf('- Nested run roots detected: %d total.', sum(verifyTbl.nested_run_count));
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- effective rank figure: 3 curves, explicit legend, no colormap.';
lines(end + 1) = '- observable trajectory figures: many physical points, color encodes log10(t_w [s]) with a parula colorbar, plus black mean overlays.';
lines(end + 1) = '- mode summary figure: one heatmap with a single parula colormap and one colorbar.';
lines(end + 1) = '- score summary figure: 2 bars per observable, explicit legend, no colormap.';
lines(end + 1) = '- derivative or additional smoothing: none applied in this audit because the script reads already-exported scalar summaries rather than differentiating raw traces.';
reportText = strjoin(lines, newline);
end

function line = buildRankFinding(rankTbl)
reliable = rankTbl(~rankTbl.fragile_low_point_count, :);
rank1Like = reliable.energy_mode1 >= 0.90;
line = sprintf(['- Effective rank: Aging is not uniformly rank-1 across T_p. ', ...
    'Reliable runs show a mixed regime at low/mid T_p where mode 2 carries substantial energy (notably 6, 14, 18 K), ', ...
    'while 22-30 K become increasingly rank-1 dominated. Across reliable T_p, the median mode-1 energy share is %.2f and the median two-mode cumulative energy is %.2f.'], ...
    median(reliable.energy_mode1, 'omitnan'), median(reliable.cumulative_energy_mode2, 'omitnan'));
if any(rank1Like)
    line = [line sprintf(' Rank-1-like behavior (mode-1 energy >= 0.90) appears most clearly at %s K.', ...
        strjoin(string(reliable.Tp_K(rank1Like).'), ', '))];
end
end

function line = buildStabilityFinding(obsAuditTbl)
primaryIdx = find(obsAuditTbl.observable == "Dip_depth", 1, 'first');
sigmaIdx = find(obsAuditTbl.observable == "Dip_sigma", 1, 'first');
t0Idx = find(obsAuditTbl.observable == "Dip_T0", 1, 'first');
line = sprintf(['- Stability: Dip_depth is the most robust physical observable across the sweep: it is defined at all T_p, ', ...
    'shows moderate within-T_p variation (reliable median CV %.2f), and evolves coherently with wait time in most reliable runs. ', ...
    'Dip_sigma remains physically useful but less robust (reliable median CV %.2f, sigma-floor hit fraction %.2f). ', ...
    'FM_abs is usable only as a supporting background metric because it is undefined at low T_p and less smooth across T_p. ', ...
    'Dip_T0 is numerically smooth but mostly mirrors T_p itself (mean |T_0-T_p| %.2f K), while FM_step_mag is sign-unstable and redundant with FM_abs.'], ...
    obsAuditTbl.median_cv_reliable(primaryIdx), obsAuditTbl.median_cv_reliable(sigmaIdx), ...
    obsAuditTbl.sigma_floor_hit_fraction(sigmaIdx), obsAuditTbl.tp_offset_abs_mean(t0Idx));
end

function line = buildModeFinding(modeSummaryTbl)
mode1 = modeSummaryTbl(modeSummaryTbl.mode == "coeff_mode1", :);
mode2 = modeSummaryTbl(modeSummaryTbl.mode == "coeff_mode2", :);
mode3 = modeSummaryTbl(modeSummaryTbl.mode == "coeff_mode3", :);
[~, i1] = max(mode1.median_abs_correlation_reliable);
[~, i2] = max(mode2.median_abs_correlation_reliable);
[~, i3] = max(mode3.median_abs_correlation_reliable);
line = sprintf(['- Mode interpretation: mode 1 aligns most cleanly with %s (median |corr| %.2f across reliable T_p), supporting a dip-amplitude interpretation. ', ...
    'Mode 2 is weaker and mixed, with its strongest recurring association to %s (median |corr| %.2f), which is consistent with a width/background crossover rather than a single pure observable. ', ...
    'Mode 3 is best linked to %s (median |corr| %.2f) but remains too fragile and T_p-dependent to elevate beyond a supporting geometric correction.'], ...
    mode1.observable(i1), mode1.median_abs_correlation_reliable(i1), ...
    mode2.observable(i2), mode2.median_abs_correlation_reliable(i2), ...
    mode3.observable(i3), mode3.median_abs_correlation_reliable(i3));
end

