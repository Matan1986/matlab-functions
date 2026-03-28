function out = switching_relaxation_bridge_robustness_audit(cfg)
% switching_relaxation_bridge_robustness_audit
% Validate the empirical bridge X(T)=I_peak/(width*S_peak) against
% relaxation A(T) using saved run outputs only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('switch:%s | relax:%s | composite:%s | motion:%s', ...
    char(source.switchRunName), char(source.relaxRunName), ...
    char(source.compositeRunName), char(source.motionRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Bridge robustness audit run directory:\n%s\n', runDir);
fprintf('Switching source run: %s\n', source.switchRunName);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Composite source run: %s\n', source.compositeRunName);
fprintf('Motion source run: %s\n', source.motionRunName);

appendText(run.log_path, sprintf('[%s] bridge robustness audit started\n', stampNow()));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Composite source: %s\n', char(source.compositeRunName)));
appendText(run.log_path, sprintf('Motion source: %s\n', char(source.motionRunName)));

switching = loadSwitchingData(source.switchRunDir, cfg);
relax = loadRelaxationData(source.relaxRunDir);
composite = loadCompositeData(source.compositeRunDir, cfg);
motion = loadMotionData(source.motionRunDir, cfg);

baselineCfg = struct('case_name', "baseline", 'interp_method', "pchip", 'width_source', "chosen", 'I_source', "raw");
baselineTbl = buildBridgeTable(switching, relax, composite, motion, baselineCfg);
baselineSummary = summarizeBridgeCase(baselineTbl, baselineCfg.case_name);

looTbl = buildLeaveOneOutTable(baselineTbl);
trimTbl = buildEndpointTrimTable(baselineTbl, baselineSummary);
[subsamplingStatsTbl, subsetSamples] = buildSubsamplingStatistics(baselineTbl);
componentTbl = buildComponentComparisonTable(baselineTbl);
sensitivityTbl = buildSensitivityTable(switching, relax, composite, motion);
baselineCorrTbl = buildBaselineCorrelationTable(baselineSummary, baselineTbl, composite);
sourceManifestTbl = buildSourceManifestTable(source, cfg);

mergedPath = save_run_table(baselineTbl, 'merged_relaxation_switching_table.csv', runDir);
baselinePath = save_run_table(baselineCorrTbl, 'baseline_correlations.csv', runDir);
looPath = save_run_table(looTbl, 'leave_one_out_correlations.csv', runDir);
trimPath = save_run_table(trimTbl, 'endpoint_trim_correlations.csv', runDir);
subsetPath = save_run_table(subsamplingStatsTbl, 'subsampling_statistics.csv', runDir);
componentPath = save_run_table(componentTbl, 'component_comparison.csv', runDir);
sensitivityPath = save_run_table(sensitivityTbl, 'interpolation_sensitivity.csv', runDir);
manifestPath = save_run_table(sourceManifestTbl, 'source_run_manifest.csv', runDir);

figTemperature = saveBridgeVsTemperatureFigure(baselineTbl, runDir, 'bridge_vs_temperature');
figScatter = saveBridgeScatterFigure(baselineTbl, baselineSummary, runDir, 'bridge_scatter_vs_A');
figLoo = saveLeaveOneOutFigure(looTbl, runDir, 'leave_one_out_summary');
figTrim = saveEndpointTrimFigure(trimTbl, runDir, 'endpoint_trimming_summary');
figComponent = saveComponentComparisonFigure(componentTbl, runDir, 'component_comparison');
figSubset = saveSubsetDistributionFigure(subsetSamples, runDir, 'subsampling_distribution');

reportText = buildReportText(source, baselineTbl, baselineSummary, looTbl, trimTbl, ...
    subsamplingStatsTbl, componentTbl, sensitivityTbl, cfg);
reportPath = save_run_report(reportText, 'switching_relaxation_bridge_robustness_audit.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_relaxation_bridge_robustness_audit_bundle.zip');

appendText(run.notes_path, sprintf('Baseline Pearson = %.6g\n', baselineSummary.pearson_r));
appendText(run.notes_path, sprintf('Baseline Spearman = %.6g\n', baselineSummary.spearman_r));
appendText(run.notes_path, sprintf('LOO minimum Pearson = %.6g\n', min(looTbl.pearson_r)));
appendText(run.notes_path, sprintf('LOO minimum Spearman = %.6g\n', min(looTbl.spearman_r)));
appendText(run.notes_path, sprintf('Subset N-2 minimum Pearson = %.6g\n', subsamplingStatsTbl.min_pearson_r(subsamplingStatsTbl.points_kept == numel(baselineTbl.T_K)-2)));
appendText(run.notes_path, sprintf('Verdict = %s\n', char(classifyVerdict(baselineSummary, looTbl, subsamplingStatsTbl, sensitivityTbl))));

appendText(run.log_path, sprintf('[%s] bridge robustness audit complete\n', stampNow()));
appendText(run.log_path, sprintf('Merged table: %s\n', mergedPath));
appendText(run.log_path, sprintf('Baseline correlations: %s\n', baselinePath));
appendText(run.log_path, sprintf('Leave-one-out: %s\n', looPath));
appendText(run.log_path, sprintf('Endpoint trim: %s\n', trimPath));
appendText(run.log_path, sprintf('Subsampling: %s\n', subsetPath));
appendText(run.log_path, sprintf('Component comparison: %s\n', componentPath));
appendText(run.log_path, sprintf('Sensitivity: %s\n', sensitivityPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.baseline = baselineTbl;
out.baselineSummary = baselineSummary;
out.tables = struct('merged', string(mergedPath), 'baseline', string(baselinePath), ...
    'loo', string(looPath), 'trim', string(trimPath), 'subsampling', string(subsetPath), ...
    'component', string(componentPath), 'sensitivity', string(sensitivityPath), ...
    'manifest', string(manifestPath));
out.figures = struct('temperature', string(figTemperature.png), 'scatter', string(figScatter.png), ...
    'loo', string(figLoo.png), 'trim', string(figTrim.png), 'component', string(figComponent.png), ...
    'subset', string(figSubset.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Bridge robustness audit complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Baseline Pearson / Spearman: %.4f / %.4f\n', baselineSummary.pearson_r, baselineSummary.spearman_r);
fprintf('Verdict: %s\n', char(classifyVerdict(baselineSummary, looTbl, subsamplingStatsTbl, sensitivityTbl)));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_relaxation_bridge_robustness_audit');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'compositeRunName', 'run_2026_03_13_071713_switching_composite_observable_scan');
cfg = setDefaultField(cfg, 'motionRunName', 'run_2026_03_11_084425_relaxation_switching_motion_test');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'interpMethods', {"pchip", "linear"});
cfg = setDefaultField(cfg, 'widthSources', {"chosen", "fwhm", "sigma"});
cfg = setDefaultField(cfg, 'ISources', {"raw", "smooth"});
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.compositeRunName = string(cfg.compositeRunName);
source.motionRunName = string(cfg.motionRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.compositeRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.compositeRunName));
source.motionRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.motionRunName));

required = {
    fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv');
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
    fullfile(char(source.compositeRunDir), 'tables', 'composite_observables_table.csv');
    fullfile(char(source.compositeRunDir), 'tables', 'correlation_summary.csv');
    fullfile(char(source.motionRunDir), 'tables', 'relaxation_switching_motion_table.csv')
    };
for i = 1:numel(required)
    if exist(required{i}, 'file') ~= 2
        error('Required source file not found: %s', required{i});
    end
end
end

function switching = loadSwitchingData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'switching_full_scaling_parameters.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
tbl = sortrows(tbl(mask, :), 'T_K');
switching = struct();
switching.T = tbl.T_K(:);
switching.S = tbl.S_peak(:);
switching.I_raw = tbl.Ipeak_mA(:);
switching.width_chosen = tbl.width_chosen_mA(:);
switching.width_fwhm = tbl.width_fwhm_mA(:);
switching.width_sigma = tbl.width_sigma_mA(:);
switching.width_method = string(tbl.width_method(:));
end

function relax = loadRelaxationData(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
tbl = sortrows(tbl, 'T');
relax = struct();
relax.T = tbl.T(:);
relax.A = tbl.A_T(:);
relax.R = tbl.R_T(:);
relax.beta = tbl.Relax_beta_T(:);
relax.tau = tbl.Relax_tau_T(:);
end

function composite = loadCompositeData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'composite_observables_table.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
tbl = sortrows(tbl(mask, :), 'T_K');
composite = struct();
composite.T = tbl.T_K(:);
composite.A_interp = tbl.A_interp(:);
composite.X_saved = tbl.I_over_wS(:);
end

function motion = loadMotionData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'relaxation_switching_motion_table.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
tbl = sortrows(tbl(mask, :), 'T_K');
motion = struct();
motion.T = tbl.T_K(:);
motion.I_smooth = tbl.I_peak_smooth_mA(:);
motion.motion_abs = tbl.motion_abs_dI_peak_dT(:);
end

function bridgeTbl = buildBridgeTable(switching, relax, composite, motion, caseCfg)
T = switching.T(:);
bridgeTbl = table();
bridgeTbl.T_K = T;
bridgeTbl.A_interp = interp1(relax.T, relax.A, T, char(caseCfg.interp_method), NaN);
bridgeTbl.S_peak = switching.S(:);
bridgeTbl.I_peak_mA = selectISeries(switching, motion, caseCfg.I_source);
bridgeTbl.width_mA = selectWidthSeries(switching, caseCfg.width_source);
[canonicalT, canonicalX] = get_canonical_X();
% X is loaded from canonical run to avoid drift from duplicated implementations
bridgeTbl.X_bridge = interp1(canonicalT, canonicalX, T, char(caseCfg.interp_method), NaN);
bridgeTbl.case_name = repmat(string(caseCfg.case_name), height(bridgeTbl), 1);
bridgeTbl.interp_method = repmat(string(caseCfg.interp_method), height(bridgeTbl), 1);
bridgeTbl.width_source = repmat(string(caseCfg.width_source), height(bridgeTbl), 1);
bridgeTbl.I_source = repmat(string(caseCfg.I_source), height(bridgeTbl), 1);
bridgeTbl.X_saved_from_composite_run = NaN(height(bridgeTbl), 1);
bridgeTbl.X_delta_vs_saved = NaN(height(bridgeTbl), 1);

[lia, loc] = ismember(T, composite.T);
if any(lia)
    bridgeTbl.X_saved_from_composite_run(lia) = composite.X_saved(loc(lia));
    bridgeTbl.X_delta_vs_saved(lia) = bridgeTbl.X_bridge(lia) - bridgeTbl.X_saved_from_composite_run(lia);
end
end

function values = selectISeries(switching, motion, sourceName)
if strcmp(string(sourceName), "smooth")
    values = switching.I_raw(:);
    [lia, loc] = ismember(switching.T, motion.T);
    values(lia) = motion.I_smooth(loc(lia));
else
    values = switching.I_raw(:);
end
end

function values = selectWidthSeries(switching, sourceName)
switch string(sourceName)
    case "chosen"
        values = switching.width_chosen(:);
    case "fwhm"
        values = switching.width_fwhm(:);
    case "sigma"
        values = switching.width_sigma(:);
    otherwise
        error('Unknown width source: %s', char(string(sourceName)));
end
end

function summary = summarizeBridgeCase(bridgeTbl, caseName)
mask = isfinite(bridgeTbl.A_interp) & isfinite(bridgeTbl.X_bridge);
A = bridgeTbl.A_interp(mask);
X = bridgeTbl.X_bridge(mask);
fitInfo = fitDescriptiveBridge(X, A);
summary = struct();
summary.case_name = string(caseName);
summary.n_points = nnz(mask);
summary.pearson_r = corrSafe(X, A);
summary.spearman_r = spearmanSafe(X, A);
summary.A_peak_T_K = findPeakT(bridgeTbl.T_K, bridgeTbl.A_interp);
summary.X_peak_T_K = findPeakT(bridgeTbl.T_K, bridgeTbl.X_bridge);
summary.peak_delta_K = summary.X_peak_T_K - summary.A_peak_T_K;
summary.max_abs_delta_vs_saved = max(abs(bridgeTbl.X_delta_vs_saved), [], 'omitnan');
summary.linear_r2 = fitInfo.linear_r2;
summary.linear_rmse = fitInfo.linear_rmse;
summary.power_r2 = fitInfo.power_r2;
summary.power_rmse = fitInfo.power_rmse;
summary.power_alpha = fitInfo.power_alpha;
summary.best_fit_label = string(fitInfo.best_fit_label);
end

function fitInfo = fitDescriptiveBridge(X, A)
p = polyfit(X, A, 1);
AhatLinear = polyval(p, X);
power = fitPowerLaw(X, A);
fitInfo = struct();
fitInfo.linear_slope = p(1);
fitInfo.linear_intercept = p(2);
fitInfo.linear_r2 = computeR2(A, AhatLinear);
fitInfo.linear_rmse = computeRMSE(A, AhatLinear);
fitInfo.power_alpha = power.alpha;
fitInfo.power_coeff = power.coeff;
fitInfo.power_r2 = power.r2;
fitInfo.power_rmse = power.rmse;
if fitInfo.power_r2 > fitInfo.linear_r2
    fitInfo.best_fit_label = 'power_A_from_X';
else
    fitInfo.best_fit_label = 'linear_A_from_X';
end
end

function power = fitPowerLaw(X, A)
mask = isfinite(X) & isfinite(A) & X > 0 & A > 0;
if nnz(mask) < 3
    power = struct('alpha', NaN, 'coeff', NaN, 'r2', NaN, 'rmse', NaN);
    return;
end
p = polyfit(log(X(mask)), log(A(mask)), 1);
alpha = p(1);
coeff = exp(p(2));
Ahat = coeff .* X(mask) .^ alpha;
power = struct('alpha', alpha, 'coeff', coeff, 'r2', computeR2(A(mask), Ahat), 'rmse', computeRMSE(A(mask), Ahat));
end
function looTbl = buildLeaveOneOutTable(baselineTbl)
T = baselineTbl.T_K(:);
looTbl = table();
for i = 1:numel(T)
    mask = true(size(T));
    mask(i) = false;
    sub = baselineTbl(mask, :);
    looTbl = [looTbl; table(T(i), height(sub), corrSafe(sub.X_bridge, sub.A_interp), ...
        spearmanSafe(sub.X_bridge, sub.A_interp), ...
        'VariableNames', {'omitted_T_K','n_points','pearson_r','spearman_r'})]; %#ok<AGROW>
end
looTbl.pearson_delta_vs_baseline = looTbl.pearson_r - corrSafe(baselineTbl.X_bridge, baselineTbl.A_interp);
looTbl.spearman_delta_vs_baseline = looTbl.spearman_r - spearmanSafe(baselineTbl.X_bridge, baselineTbl.A_interp);
end

function trimTbl = buildEndpointTrimTable(baselineTbl, baselineSummary)
T = baselineTbl.T_K(:);
highestT = max(T);
lowestT = min(T);
caseDefs = {
    'baseline', [], 'baseline';
    'remove_highest_temperature', highestT, sprintf('highest temperature on filtered grid = %.0f K', highestT);
    'remove_lowest_temperature', lowestT, sprintf('lowest temperature on filtered grid = %.0f K', lowestT);
    'remove_both_extremes', [lowestT highestT], sprintf('remove %.0f K and %.0f K', lowestT, highestT);
    'remove_34K', 34, 'already absent from filtered switching source';
    'remove_32K', 32, 'already absent from filtered switching source';
    'remove_30K', 30, 'explicit 30 K trim'
    };

trimTbl = table();
for i = 1:size(caseDefs, 1)
    caseName = string(caseDefs{i, 1});
    removeTemps = caseDefs{i, 2};
    note = string(caseDefs{i, 3});
    mask = ~ismember(T, removeTemps);
    nRemoved = nnz(~mask);
    if strcmp(caseName, "baseline") || nRemoved > 0
        sub = baselineTbl(mask, :);
        pearsonR = corrSafe(sub.X_bridge, sub.A_interp);
        spearmanR = spearmanSafe(sub.X_bridge, sub.A_interp);
    else
        sub = baselineTbl;
        pearsonR = baselineSummary.pearson_r;
        spearmanR = baselineSummary.spearman_r;
    end
    trimTbl = [trimTbl; table(caseName, height(sub), nRemoved, pearsonR, spearmanR, note, ...
        'VariableNames', {'case_name','n_points','n_removed','pearson_r','spearman_r','note'})]; %#ok<AGROW>
end
trimTbl.pearson_delta_vs_baseline = trimTbl.pearson_r - baselineSummary.pearson_r;
trimTbl.spearman_delta_vs_baseline = trimTbl.spearman_r - baselineSummary.spearman_r;
end

function [statsTbl, subsetSamples] = buildSubsamplingStatistics(baselineTbl)
N = height(baselineTbl);
subsetSizes = [N-1, N-2];
subsetSamples = struct('points_kept', {}, 'pearson_r', {}, 'spearman_r', {});
statsTbl = table();
for i = 1:numel(subsetSizes)
    k = subsetSizes(i);
    combos = nchoosek(1:N, k);
    pearsonVals = NaN(size(combos, 1), 1);
    spearmanVals = NaN(size(combos, 1), 1);
    for j = 1:size(combos, 1)
        sub = baselineTbl(combos(j, :), :);
        pearsonVals(j) = corrSafe(sub.X_bridge, sub.A_interp);
        spearmanVals(j) = spearmanSafe(sub.X_bridge, sub.A_interp);
    end
    subsetSamples(i).points_kept = k;
    subsetSamples(i).pearson_r = pearsonVals;
    subsetSamples(i).spearman_r = spearmanVals;
    statsTbl = [statsTbl; table(k, size(combos, 1), ...
        mean(pearsonVals), std(pearsonVals), min(pearsonVals), max(pearsonVals), median(pearsonVals), ...
        mean(spearmanVals), std(spearmanVals), min(spearmanVals), max(spearmanVals), median(spearmanVals), ...
        string('exhaustive_subsets'), ...
        'VariableNames', {'points_kept','n_subsets','mean_pearson_r','std_pearson_r','min_pearson_r', ...
        'max_pearson_r','median_pearson_r','mean_spearman_r','std_spearman_r','min_spearman_r', ...
        'max_spearman_r','median_spearman_r','sampling_method'})]; %#ok<AGROW>
end
end

function componentTbl = buildComponentComparisonTable(baselineTbl)
defs = {
    'width', 'width(T)', baselineTbl.width_mA;
    'S_peak', 'S_{peak}(T)', baselineTbl.S_peak;
    'I_peak', 'I_{peak}(T)', baselineTbl.I_peak_mA;
    'inv_width', '1 / width(T)', 1 ./ baselineTbl.width_mA;
    'I_over_width', 'I_{peak} / width', baselineTbl.I_peak_mA ./ baselineTbl.width_mA;
    'width_over_S', 'width / S_{peak}', baselineTbl.width_mA ./ baselineTbl.S_peak;
    'S_over_width', 'S_{peak} / width', baselineTbl.S_peak ./ baselineTbl.width_mA;
    'I_over_S', 'I_{peak} / S_{peak}', baselineTbl.I_peak_mA ./ baselineTbl.S_peak;
    'I_over_wS', 'I_{peak} / (width S_{peak})', baselineTbl.X_bridge
    };

componentTbl = table();
for i = 1:size(defs, 1)
    x = defs{i, 3};
    componentTbl = [componentTbl; table(string(defs{i, 1}), string(defs{i, 2}), ...
        corrSafe(x, baselineTbl.A_interp), spearmanSafe(x, baselineTbl.A_interp), ...
        findPeakT(baselineTbl.T_K, x), findPeakT(baselineTbl.T_K, baselineTbl.A_interp), ...
        findPeakT(baselineTbl.T_K, x) - findPeakT(baselineTbl.T_K, baselineTbl.A_interp), ...
        relationLabel(corrSafe(x, baselineTbl.A_interp)), ...
        'VariableNames', {'observable_key','display_name','pearson_r','spearman_r', ...
        'observable_peak_T_K','A_peak_T_K','peak_delta_K','relation_class'})]; %#ok<AGROW>
end
componentTbl.abs_spearman_r = abs(componentTbl.spearman_r);
componentTbl.abs_pearson_r = abs(componentTbl.pearson_r);
componentTbl = sortrows(componentTbl, {'abs_spearman_r','abs_pearson_r'}, {'descend','descend'});
componentTbl.rank_abs_spearman = (1:height(componentTbl)).';
end

function sensitivityTbl = buildSensitivityTable(switching, relax, composite, motion)
caseDefs = {
    'baseline_pchip_chosen_rawI', 'pchip', 'chosen', 'raw';
    'linear_interp', 'linear', 'chosen', 'raw';
    'width_fwhm', 'pchip', 'fwhm', 'raw';
    'width_sigma', 'pchip', 'sigma', 'raw';
    'smooth_I_peak', 'pchip', 'chosen', 'smooth'
    };

baseCfg = struct('case_name', "baseline", 'interp_method', "pchip", 'width_source', "chosen", 'I_source', "raw");
baseTbl = buildBridgeTable(switching, relax, composite, motion, baseCfg);
baseX = baseTbl.X_bridge;
sensitivityTbl = table();
for i = 1:size(caseDefs, 1)
    caseCfg = struct('case_name', string(caseDefs{i, 1}), 'interp_method', string(caseDefs{i, 2}), ...
        'width_source', string(caseDefs{i, 3}), 'I_source', string(caseDefs{i, 4}));
    tbl = buildBridgeTable(switching, relax, composite, motion, caseCfg);
    summary = summarizeBridgeCase(tbl, caseCfg.case_name);
    sensitivityTbl = [sensitivityTbl; table(caseCfg.case_name, caseCfg.interp_method, caseCfg.width_source, ...
        caseCfg.I_source, summary.pearson_r, summary.spearman_r, summary.peak_delta_K, ...
        max(abs(tbl.X_bridge - baseX)), max(abs(tbl.X_delta_vs_saved), [], 'omitnan'), ...
        summary.linear_r2, summary.power_r2, summary.power_alpha, summary.best_fit_label, ...
        'VariableNames', {'case_name','interp_method','width_source','I_source','pearson_r','spearman_r', ...
        'peak_delta_K','max_abs_delta_vs_baseline_X','max_abs_delta_vs_saved_composite_X', ...
        'linear_r2','power_r2','power_alpha','best_fit_label'})]; %#ok<AGROW>
end
end

function baselineCorrTbl = buildBaselineCorrelationTable(summary, baselineTbl, composite)
baselineCorrTbl = table();
baselineCorrTbl.case_name = string(summary.case_name);
baselineCorrTbl.n_points = summary.n_points;
baselineCorrTbl.pearson_r = summary.pearson_r;
baselineCorrTbl.spearman_r = summary.spearman_r;
baselineCorrTbl.A_peak_T_K = summary.A_peak_T_K;
baselineCorrTbl.X_peak_T_K = summary.X_peak_T_K;
baselineCorrTbl.peak_delta_K = summary.peak_delta_K;
baselineCorrTbl.max_abs_delta_vs_saved_composite_X = summary.max_abs_delta_vs_saved;
baselineCorrTbl.linear_r2 = summary.linear_r2;
baselineCorrTbl.linear_rmse = summary.linear_rmse;
baselineCorrTbl.power_r2 = summary.power_r2;
baselineCorrTbl.power_rmse = summary.power_rmse;
baselineCorrTbl.power_alpha = summary.power_alpha;
baselineCorrTbl.best_fit_label = summary.best_fit_label;
baselineCorrTbl.saved_composite_run = repmat(string('run_2026_03_13_071713_switching_composite_observable_scan'), 1, 1);
baselineCorrTbl.n_matching_saved_points = nnz(isfinite(baselineTbl.X_saved_from_composite_run));
end

function sourceManifestTbl = buildSourceManifestTable(source, cfg)
sourceManifestTbl = table(string({'switching'; 'relaxation'; 'cross_experiment'; 'cross_experiment'}), ...
    [source.switchRunName; source.relaxRunName; source.compositeRunName; source.motionRunName], ...
    string({fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.compositeRunDir), 'tables', 'composite_observables_table.csv'); ...
    fullfile(char(source.motionRunDir), 'tables', 'relaxation_switching_motion_table.csv')}), ...
    string({'switching observables'; 'relaxation A(T) table'; 'saved composite bridge table'; 'saved smooth-I_peak / ridge-motion table'}), ...
    repmat(string(cfg.temperatureMinK) + "-" + string(cfg.temperatureMaxK) + " K", 4, 1), ...
    'VariableNames', {'experiment','source_run','source_file','role','temperature_window'});
end

function figPaths = saveBridgeVsTemperatureFigure(baselineTbl, runDir, figureName)
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 17.8 11]);
tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
plot(ax1, baselineTbl.T_K, baselineTbl.A_interp, '-o', 'Color', [0 0 0], 'LineWidth', 1.9, 'MarkerSize', 5, 'MarkerFaceColor', [0 0 0]);
grid(ax1, 'on');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'A(T)');
title(ax1, 'Relaxation activity versus temperature');

ax2 = nexttile(tl, 2);
plot(ax2, baselineTbl.T_K, baselineTbl.X_bridge, '-o', 'Color', [0 0.45 0.74], 'LineWidth', 1.9, 'MarkerSize', 5, 'MarkerFaceColor', [0 0.45 0.74]);
grid(ax2, 'on');
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, 'I_{peak} / (width S_{peak})');
title(ax2, 'Composite switching bridge versus temperature');

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveBridgeScatterFigure(baselineTbl, baselineSummary, runDir, figureName)
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 12 8.5]);
ax = axes(fh);
scatter(ax, baselineTbl.X_bridge, baselineTbl.A_interp, 52, baselineTbl.T_K, 'filled');
hold(ax, 'on');
p = polyfit(baselineTbl.X_bridge, baselineTbl.A_interp, 1);
xFit = linspace(min(baselineTbl.X_bridge), max(baselineTbl.X_bridge), 200);
plot(ax, xFit, polyval(p, xFit), '--', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.8, 'DisplayName', 'linear fit');
power = fitPowerLaw(baselineTbl.X_bridge, baselineTbl.A_interp);
if isfinite(power.coeff)
    plot(ax, xFit, power.coeff .* xFit .^ power.alpha, '-', 'Color', [0.85 0.33 0.1], 'LineWidth', 1.8, 'DisplayName', 'power fit');
end
hold(ax, 'off');
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
xlabel(ax, 'I_{peak} / (width S_{peak})');
ylabel(ax, 'A(T)');
title(ax, sprintf('Bridge scatter: Pearson %.3f, Spearman %.3f', baselineSummary.pearson_r, baselineSummary.spearman_r));
legend(ax, 'Location', 'best');
grid(ax, 'on');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end
function figPaths = saveLeaveOneOutFigure(looTbl, runDir, figureName)
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 17.8 8.8]);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
plot(ax1, looTbl.omitted_T_K, looTbl.pearson_r, '-o', 'Color', [0 0.45 0.74], 'LineWidth', 1.8, 'MarkerSize', 5, 'MarkerFaceColor', [0 0.45 0.74]);
yline(ax1, median(looTbl.pearson_r), '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.2);
grid(ax1, 'on');
xlabel(ax1, 'Omitted temperature (K)');
ylabel(ax1, 'Pearson r');
title(ax1, 'Leave-one-out Pearson stability');

ax2 = nexttile(tl, 2);
plot(ax2, looTbl.omitted_T_K, looTbl.spearman_r, '-o', 'Color', [0.85 0.33 0.1], 'LineWidth', 1.8, 'MarkerSize', 5, 'MarkerFaceColor', [0.85 0.33 0.1]);
yline(ax2, median(looTbl.spearman_r), '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.2);
grid(ax2, 'on');
xlabel(ax2, 'Omitted temperature (K)');
ylabel(ax2, 'Spearman \rho');
title(ax2, 'Leave-one-out Spearman stability');

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveEndpointTrimFigure(trimTbl, runDir, figureName)
plotTbl = trimTbl;
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 17.8 8.8]);
ax = axes(fh);
vals = [plotTbl.pearson_r, plotTbl.spearman_r];
bar(ax, vals, 'grouped');
grid(ax, 'on');
xticks(ax, 1:height(plotTbl));
xticklabels(ax, strrep(cellstr(plotTbl.case_name), '_', ' '));
xtickangle(ax, 25);
xlabel(ax, 'Trim case');
ylabel(ax, 'Correlation');
title(ax, 'Endpoint and explicit-temperature trimming tests');
legend(ax, {'Pearson r', 'Spearman \rho'}, 'Location', 'best');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveComponentComparisonFigure(componentTbl, runDir, figureName)
plotTbl = componentTbl;
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 17.8 9.5]);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
barh(ax1, plotTbl.pearson_r, 'FaceColor', [0 0.45 0.74]);
grid(ax1, 'on');
yticks(ax1, 1:height(plotTbl));
yticklabels(ax1, plotTbl.observable_key);
ylabel(ax1, 'Switching observable');
xlabel(ax1, 'Pearson r with A(T)');
title(ax1, 'Component comparison');

ax2 = nexttile(tl, 2);
barh(ax2, plotTbl.spearman_r, 'FaceColor', [0.85 0.33 0.1]);
grid(ax2, 'on');
yticks(ax2, 1:height(plotTbl));
yticklabels(ax2, plotTbl.observable_key);
ylabel(ax2, 'Switching observable');
xlabel(ax2, 'Spearman \\rho with A(T)');
title(ax2, 'Rank-order comparison');

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveSubsetDistributionFigure(subsetSamples, runDir, figureName)
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 17.8 8.8]);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
for i = 1:numel(subsetSamples)
    x = repmat(subsetSamples(i).points_kept, numel(subsetSamples(i).pearson_r), 1);
    scatter(ax1, x, subsetSamples(i).pearson_r, 20, 'filled', 'MarkerFaceAlpha', 0.35);
end
hold(ax1, 'off');
grid(ax1, 'on');
xlabel(ax1, 'Points kept');
ylabel(ax1, 'Pearson r');
title(ax1, 'Exhaustive subset Pearson distribution');

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
for i = 1:numel(subsetSamples)
    x = repmat(subsetSamples(i).points_kept, numel(subsetSamples(i).spearman_r), 1);
    scatter(ax2, x, subsetSamples(i).spearman_r, 20, 'filled', 'MarkerFaceAlpha', 0.35);
end
hold(ax2, 'off');
grid(ax2, 'on');
xlabel(ax2, 'Points kept');
ylabel(ax2, 'Spearman \rho');
title(ax2, 'Exhaustive subset Spearman distribution');

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReportText(source, baselineTbl, baselineSummary, looTbl, trimTbl, subsetTbl, componentTbl, sensitivityTbl, cfg)
verdict = classifyVerdict(baselineSummary, looTbl, subsetTbl, sensitivityTbl);
bestComponent = componentTbl(1, :);
widthRow = componentTbl(strcmp(componentTbl.observable_key, "width"), :);
sensWorst = sortrows(sensitivityTbl, {'pearson_r'}, {'ascend'});
trimWorst = sortrows(trimTbl, {'pearson_r'}, {'ascend'});

lines = strings(0,1);
lines(end+1) = "# Switching-relaxation bridge robustness audit";
lines(end+1) = "";
lines(end+1) = "## Inputs";
lines(end+1) = sprintf("- Relaxation A(T): `%s`", char(source.relaxRunName));
lines(end+1) = sprintf("- Switching observables: `%s`", char(source.switchRunName));
lines(end+1) = sprintf("- Saved composite bridge reference: `%s`", char(source.compositeRunName));
lines(end+1) = sprintf("- Saved smooth-I_peak reference: `%s`", char(source.motionRunName));
lines(end+1) = sprintf("- Common temperature grid: %s", formatTempList(baselineTbl.T_K));
lines(end+1) = "";
lines(end+1) = "## Merged dataset construction";
lines(end+1) = "The baseline bridge uses the filtered full-scaling switching grid (4-30 K, step 2 K), `pchip` interpolation of `A(T)` onto that grid, raw `I_peak(T)`, and the saved `width_chosen(T)` values from the full-scaling collapse run.";
lines(end+1) = sprintf("The reconstructed `X(T)` matches the saved composite run with a maximum absolute pointwise difference of `%.3g`.", baselineSummary.max_abs_delta_vs_saved);
lines(end+1) = "";
lines(end+1) = "## Tests performed";
lines(end+1) = "- Baseline reproduction of Pearson and Spearman correlations";
lines(end+1) = "- Leave-one-temperature-out recomputation for every temperature";
lines(end+1) = "- Endpoint and explicit temperature trimming tests";
lines(end+1) = "- Exhaustive subset scans for N-1 and N-2 retained points";
lines(end+1) = "- Comparison against simpler switching observables and low-order ratios";
lines(end+1) = "- Sensitivity checks for interpolation method, width definition, and saved smoothed I_peak extraction";
lines(end+1) = "";
lines(end+1) = "## Empirical findings";
lines(end+1) = sprintf("- Baseline bridge: Pearson `%.4f`, Spearman `%.4f`.", baselineSummary.pearson_r, baselineSummary.spearman_r);
lines(end+1) = sprintf("- Peak alignment: `A(T)` peaks at `%.0f K`, `X(T)` peaks at `%.0f K`, so the peak offset is `%.0f K`.", baselineSummary.A_peak_T_K, baselineSummary.X_peak_T_K, baselineSummary.peak_delta_K);
lines(end+1) = sprintf("- Leave-one-out range: Pearson `%.4f` to `%.4f`, Spearman `%.4f` to `%.4f`; medians are `%.4f` and `%.4f`.", min(looTbl.pearson_r), max(looTbl.pearson_r), min(looTbl.spearman_r), max(looTbl.spearman_r), median(looTbl.pearson_r), median(looTbl.spearman_r));
lines(end+1) = sprintf("- Worst explicit trimming case by Pearson is `%s` with Pearson `%.4f` and Spearman `%.4f`.", char(trimWorst.case_name(1)), trimWorst.pearson_r(1), trimWorst.spearman_r(1));
lines(end+1) = sprintf("- Exhaustive N-2 subsets keep Pearson above `%.4f` and Spearman above `%.4f`.", subsetTbl.min_pearson_r(subsetTbl.points_kept == numel(baselineTbl.T_K)-2), subsetTbl.min_spearman_r(subsetTbl.points_kept == numel(baselineTbl.T_K)-2));
lines(end+1) = sprintf("- Best component in the comparison scan is `%s` with Pearson `%.4f` and Spearman `%.4f`.", char(bestComponent.observable_key(1)), bestComponent.pearson_r(1), bestComponent.spearman_r(1));
if ~isempty(widthRow)
    lines(end+1) = sprintf("- Width alone remains weaker: Pearson `%.4f`, Spearman `%.4f`.", widthRow.pearson_r(1), widthRow.spearman_r(1));
end
lines(end+1) = sprintf("- Worst sensitivity case by Pearson is `%s` with Pearson `%.4f`, Spearman `%.4f`, and max pointwise deviation `%.4f` from baseline X(T).", char(sensWorst.case_name(1)), sensWorst.pearson_r(1), sensWorst.spearman_r(1), sensWorst.max_abs_delta_vs_baseline_X(1));
lines(end+1) = "";
lines(end+1) = "## Descriptive fits";
lines(end+1) = sprintf("- The bridge is strongly monotonic (Spearman `%.4f`).", baselineSummary.spearman_r);
lines(end+1) = sprintf("- Linear descriptive fit `A = a X + b`: `R^2 = %.4f`.", baselineSummary.linear_r2);
lines(end+1) = sprintf("- Power-law descriptive fit `A = c X^alpha`: `R^2 = %.4f`, `alpha = %.4f`.", baselineSummary.power_r2, baselineSummary.power_alpha);
lines(end+1) = sprintf("- Best descriptive fit label: `%s`.", char(baselineSummary.best_fit_label));
lines(end+1) = "";
lines(end+1) = "## Speculative interpretation";
lines(end+1) = "No new theory is introduced in this run. The result is treated only as an empirical bridge and a robustness-tested descriptive relationship.";
lines(end+1) = "";
lines(end+1) = "## Visualization choices";
lines(end+1) = "- `bridge_vs_temperature`: two single-curve panels, explicit axes, no colormap";
lines(end+1) = "- `bridge_scatter_vs_A`: one scatter cloud plus a temperature colorbar because there are 14 temperature points";
lines(end+1) = "- `leave_one_out_summary` and `endpoint_trimming_summary`: compact summary plots emphasizing correlation stability";
lines(end+1) = "- `component_comparison`: ranked bar comparison of simpler observables against the composite";
lines(end+1) = "- `subsampling_distribution`: exhaustive subset distributions for N-1 and N-2 retained points";
lines(end+1) = "- Smoothing applied: none beyond the saved smoothed `I_peak` alternative already present in the repository";
lines(end+1) = "";
lines(end+1) = "## Verdict";
lines(end+1) = sprintf("Final verdict: **%s**.", char(verdict));
if verdict == "robust"
    lines(end+1) = "The bridge remains strong under leave-one-out, endpoint trimming, exhaustive subset scans, and reasonable extraction alternatives.";
elseif verdict == "promising_but_sensitive"
    lines(end+1) = "The bridge stays strong in baseline form, but one or more robustness checks show meaningful sensitivity that should be resolved before modeling.";
else
    lines(end+1) = "The bridge is too dependent on specific points or analysis choices to treat as a stable empirical result.";
end
lines(end+1) = "Recommended next step before theoretical modeling: test whether the same composite bridge survives when the switching observables are reconstructed from an independently chosen but still reasonable active-switching temperature window or from an adjacent switching run with the same processing rules.";

reportText = strjoin(lines, newline);
end

function verdict = classifyVerdict(baselineSummary, looTbl, subsetTbl, sensitivityTbl)
minLooPearson = min(looTbl.pearson_r);
minLooSpearman = min(looTbl.spearman_r);
minSubPearson = min(subsetTbl.min_pearson_r);
minSubSpearman = min(subsetTbl.min_spearman_r);
minSensPearson = min(sensitivityTbl.pearson_r);
minSensSpearman = min(sensitivityTbl.spearman_r);
if baselineSummary.pearson_r >= 0.95 && baselineSummary.spearman_r >= 0.98 && ...
        minLooPearson >= 0.93 && minLooSpearman >= 0.96 && ...
        minSubPearson >= 0.88 && minSubSpearman >= 0.92 && ...
        minSensPearson >= 0.90 && minSensSpearman >= 0.90
    verdict = "robust";
elseif baselineSummary.pearson_r >= 0.9 && baselineSummary.spearman_r >= 0.93 && ...
        minLooPearson >= 0.8 && minSubPearson >= 0.75
    verdict = "promising_but_sensitive";
else
    verdict = "fragile";
end
end

function label = relationLabel(r)
if r >= 0.2
    label = "direct";
elseif r <= -0.2
    label = "inverse";
else
    label = "weak_or_neutral";
end
end

function txt = formatTempList(T)
txt = strjoin(compose('%.0f K', T(:).'), ', ');
end

function value = setDefaultField(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s;
    return;
end
s.(fieldName) = defaultValue;
value = s;
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

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'tables', 'figures', 'reports'}, runDir);
end

function value = corrSafe(x, y)
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    value = NaN;
    return;
end
x = x(mask);
y = y(mask);
if all(abs(x - x(1)) < 1e-12) || all(abs(y - y(1)) < 1e-12)
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
if all(abs(x - x(1)) < 1e-12) || all(abs(y - y(1)) < 1e-12)
    value = NaN;
    return;
end
value = corr(x(:), y(:), 'Rows', 'complete', 'Type', 'Spearman');
end

function rmse = computeRMSE(x, y)
mask = isfinite(x) & isfinite(y);
if ~any(mask)
    rmse = NaN;
    return;
end
rmse = sqrt(mean((x(mask) - y(mask)).^2));
end

function r2 = computeR2(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if nnz(mask) < 2
    r2 = NaN;
    return;
end
y = y(mask);
yhat = yhat(mask);
ssRes = sum((y - yhat).^2);
ssTot = sum((y - mean(y)).^2);
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
end

function peakT = findPeakT(T, y)
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    peakT = NaN;
    return;
end
T = T(mask);
y = y(mask);
[~, idx] = max(y);
peakT = T(idx);
end

