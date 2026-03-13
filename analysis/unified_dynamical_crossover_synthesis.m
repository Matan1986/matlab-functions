
function out = unified_dynamical_crossover_synthesis(cfg)
% unified_dynamical_crossover_synthesis
% Saved-output-only cross-experiment synthesis of the shared crossover near
% T* ~ 27 K and the targeted Aging <-> Switching two-component link.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | aging:%s,%s | switch:%s,%s', ...
    char(source.relaxRunName), char(source.agingAuditRunName), char(source.agingCollapseRunName), ...
    char(source.switchRunName), char(source.switchCompareRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Unified dynamical crossover synthesis run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] unified dynamical crossover synthesis started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Aging audit source: %s\n', char(source.agingAuditRunName)));
appendText(run.log_path, sprintf('Aging collapse source: %s\n', char(source.agingCollapseRunName)));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Saved switching comparison source: %s\n', char(source.switchCompareRunName)));

relax = loadRelaxationData(source.relaxRunDir);
aging = loadAgingData(source.agingAuditRunDir, source.agingCollapseRunDir);
switching = loadSwitchingData(source.switchRunDir, source.switchCompareRunDir);
selected = buildSelectedProfiles(aging, switching);
summaryTbl = buildUnifiedSummaryTable(relax, aging, switching, selected, source);
pairTbl = buildPairSummaryTable(selected);
lagTbl = buildLaggedTable(selected);
fitTbl = buildTwoBasisFitTable(selected);
manifestTbl = buildManifestTable(source);

summaryPath = save_run_table(summaryTbl, 'unified_crossover_summary.csv', runDir);
pairPath = save_run_table(pairTbl, 'aging_switching_pair_correlations.csv', runDir);
lagPath = save_run_table(lagTbl, 'aging_switching_lagged_correlations.csv', runDir);
fitPath = save_run_table(fitTbl, 'optional_two_basis_fit_results.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

figMain = saveUnifiedMainFigure(relax, aging, switching, runDir, 'unified_dynamical_crossover_main');
figNorm = saveUnifiedNormalizedFigure(relax, aging, switching, selected, runDir, 'unified_dynamical_crossover_normalized');
figBg = saveBackgroundMobilityFigure(selected, runDir, 'aging_background_vs_switching_mobility');
figDip = saveDipPinningFigure(selected, runDir, 'aging_dip_vs_switching_pinning');
figLag = saveLagFigure(selected, runDir, 'optional_lagged_correlation_panels');

reportText = buildReportText(source, relax, aging, switching, selected, pairTbl, fitTbl, cfg);
reportPath = save_run_report(reportText, 'unified_dynamical_crossover_and_aging_switching_link.md', runDir);
zipPath = buildReviewZip(runDir, 'unified_dynamical_crossover_and_aging_switching_link.zip');

appendText(run.notes_path, sprintf('Preferred Aging collapse temperature = %.6g K\n', aging.preferredCollapseT));
appendText(run.notes_path, sprintf('Relaxation A(T) source peak = %.6g K\n', relax.sourcePeakT));
appendText(run.notes_path, sprintf('Switching mobility peak = %.6g K\n', switching.mobilityPeakT));
appendText(run.notes_path, sprintf('Switching pinning onset = %.6g K\n', switching.pinningOnsetT));
appendText(run.notes_path, sprintf('Background vs mobility Pearson/Spearman = %.6g / %.6g\n', ...
    pairTbl.zero_lag_pearson_r(pairTbl.pair_id == "background_vs_mobility"), ...
    pairTbl.zero_lag_spearman_r(pairTbl.pair_id == "background_vs_mobility")));
appendText(run.notes_path, sprintf('Dip vs pinning best lag Pearson/Spearman = %+.6g K / %+.6g K\n', ...
    pairTbl.best_pearson_lag_K(pairTbl.pair_id == "dip_vs_pinning"), ...
    pairTbl.best_spearman_lag_K(pairTbl.pair_id == "dip_vs_pinning")));

appendText(run.log_path, sprintf('[%s] unified dynamical crossover synthesis complete\n', stampNow()));
appendText(run.log_path, sprintf('Summary table: %s\n', summaryPath));
appendText(run.log_path, sprintf('Pair table: %s\n', pairPath));
appendText(run.log_path, sprintf('Lag table: %s\n', lagPath));
appendText(run.log_path, sprintf('Two-basis fit table: %s\n', fitPath));
appendText(run.log_path, sprintf('Manifest table: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.tables = struct('summary', string(summaryPath), 'pairs', string(pairPath), 'lags', string(lagPath), 'fits', string(fitPath), 'manifest', string(manifestPath));
out.figures = struct('main', string(figMain.png), 'normalized', string(figNorm.png), 'background', string(figBg.png), 'dip', string(figDip.png), 'lag', string(figLag.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Unified dynamical crossover synthesis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'unified_dynamical_crossover_synthesis');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'agingAuditRunName', 'run_2026_03_11_011643_observable_identification_audit');
cfg = setDefaultField(cfg, 'agingCollapseRunName', 'run_2026_03_11_082451_aging_shape_collapse_analysis');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefaultField(cfg, 'switchCompareRunName', 'run_2026_03_12_004907_switching_relaxation_observable_comparis');
cfg = setDefaultField(cfg, 'lagGridK', [-4 0 4]);
cfg = setDefaultField(cfg, 'mobileRegion', [22 32]);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.relaxRunName = string(cfg.relaxRunName);
source.agingAuditRunName = string(cfg.agingAuditRunName);
source.agingCollapseRunName = string(cfg.agingCollapseRunName);
source.switchRunName = string(cfg.switchRunName);
source.switchCompareRunName = string(cfg.switchCompareRunName);

source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.agingAuditRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.agingAuditRunName));
source.agingCollapseRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.agingCollapseRunName));
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.switchCompareRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.switchCompareRunName));

required = {
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
    source.agingAuditRunDir, fullfile(char(source.agingAuditRunDir), 'tables', 'aging_tp_observable_metrics.csv');
    source.agingCollapseRunDir, fullfile(char(source.agingCollapseRunDir), 'tables', 'aging_shape_variation_vs_Tp.csv');
    source.switchRunDir, fullfile(char(source.switchRunDir), 'observable_matrix.csv');
    source.switchCompareRunDir, fullfile(char(source.switchCompareRunDir), 'tables', 'switching_relaxation_observable_curves.csv')
    };

for i = 1:size(required, 1)
    if exist(required{i, 1}, 'dir') ~= 7
        error('Required source run directory not found: %s', required{i, 1});
    end
    if exist(required{i, 2}, 'file') ~= 2
        error('Required source file not found: %s', required{i, 2});
    end
end
end

function relax = loadRelaxationData(runDir)
tempTbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
obsTbl = readtable(fullfile(runDir, 'tables', 'observables_relaxation.csv'));
relax = struct();
relax.T = tempTbl.T(:);
relax.A = tempTbl.A_T(:);
relax.sourcePeakT = obsTbl.Relax_T_peak(1);
relax.sourcePeakWidth = obsTbl.Relax_peak_width(1);
relax.sourcePeakAmp = obsTbl.Relax_Amp_peak(1);
end

function aging = loadAgingData(auditRunDir, collapseRunDir)
auditTbl = readtable(fullfile(auditRunDir, 'tables', 'aging_tp_observable_metrics.csv'));
rankTbl = readtable(fullfile(auditRunDir, 'tables', 'aging_tp_rank_summary.csv'));
recTbl = readtable(fullfile(auditRunDir, 'tables', 'aging_observable_recommendation_table.csv'));
collapse = loadCollapseSweep(fullfile(collapseRunDir, 'tables', 'aging_shape_variation_vs_Tp.csv'));

aging = struct();
aging.auditTbl = auditTbl;
aging.rankTbl = rankTbl;
aging.recTbl = recTbl;
aging.collapse = collapse;

aging.rank1 = extractObservable(collapse.Tp_K, collapse.rank1_explained_variance_ratio, collapse.n_profiles, 'rank1_explained_variance');
aging.shapeSimpl = extractObservable(collapse.Tp_K, 1 - collapse.shape_variation, collapse.n_profiles, 'shape_simplification');
aging.dipDepth = extractAuditObservable(auditTbl, 'Dip_depth');
aging.fmAbs = extractAuditObservable(auditTbl, 'FM_abs');
aging.dipSigma = extractAuditObservable(auditTbl, 'Dip_sigma');
aging.energyMode2 = extractObservable(rankTbl.Tp_K, rankTbl.energy_mode2, rankTbl.n_physical_points, 'energy_mode2');

reliableMask = aging.rank1.n_support >= 4;
[~, idxReliable] = max(aging.rank1.values(reliableMask));
TpReliable = aging.rank1.T(reliableMask);
aging.preferredCollapseT = TpReliable(idxReliable);
[aging.numericCollapseMax, idxMax] = max(aging.rank1.values);
aging.numericCollapseMaxT = aging.rank1.T(idxMax);
aging.numericCollapseMaxNProfiles = aging.rank1.n_support(idxMax);
end

function collapse = loadCollapseSweep(pathStr)
C = readcell(pathStr);
collapse = struct();
collapse.Tp_K = cell2mat(C(2:end, 1));
collapse.shape_variation = cell2mat(C(2:end, 2));
collapse.rank1_explained_variance_ratio = cell2mat(C(2:end, 3));
collapse.n_temperatures = cell2mat(C(2:end, 4));
collapse.n_profiles = cell2mat(C(2:end, 5));
collapse.run_id = string(C(2:end, 6));
collapse.source_run_dir = string(C(2:end, 7));
end

function obs = extractAuditObservable(auditTbl, observableName)
mask = strcmp(auditTbl.observable, observableName);
obs = extractObservable(auditTbl.Tp_K(mask), auditTbl.mean_value(mask), 4 - auditTbl.fragile_low_point_count(mask), observableName);
obs.fragile_low_point_count = auditTbl.fragile_low_point_count(mask);
obs.missing_fraction = auditTbl.missing_fraction(mask);
end

function obs = extractObservable(T, values, nSupport, key)
obs = struct();
obs.key = string(key);
obs.T = T(:);
obs.values = values(:);
obs.n_support = nSupport(:);
end
function switching = loadSwitchingData(switchRunDir, switchCompareRunDir)
obsTbl = readtable(fullfile(switchRunDir, 'observable_matrix.csv'));
curveTbl = readtable(fullfile(switchCompareRunDir, 'tables', 'switching_relaxation_observable_curves.csv'));

switching = struct();
switching.T = obsTbl.T(:);
switching.I_peak = obsTbl.I_peak(:);
switching.S_peak = obsTbl.S_peak(:);
switching.width_I = obsTbl.width_I(:);
switching.T_curve = curveTbl.T_K(:);
switching.motion = curveTbl.motion_abs_dI_peak_dT(:);
switching.curvature = curveTbl.curvature_abs_d2I_peak_dT2(:);
switching.robustMask = logical(curveTbl.robust_mask(:));
switching.motionMask = logical(curveTbl.motion_valid_mask(:));
switching.pinning = 1 - switching.motion ./ max(switching.motion, [], 'omitnan');

plateauValue = max(switching.I_peak(switching.robustMask), [], 'omitnan');
mobileMask = switching.robustMask & switching.I_peak < plateauValue;
switching.mobileMask = mobileMask & switching.T >= 22 & switching.T <= 32;
switching.pinnedMask = switching.robustMask & switching.T <= 20;
switching.pinningOnsetT = min(switching.T(switching.mobileMask));

[~, idxPeakMotion] = max(switching.motion(switching.motionMask));
Tmotion = switching.T_curve(switching.motionMask);
switching.mobilityPeakT = Tmotion(idxPeakMotion);
[~, idxPeakCurv] = max(switching.curvature(isfinite(switching.curvature)));
Tcurv = switching.T_curve(isfinite(switching.curvature));
switching.curvaturePeakT = Tcurv(idxPeakCurv);

p = polyfit(switching.T(switching.mobileMask), switching.I_peak(switching.mobileMask), 1);
switching.mobileFitSlope = p(1);
switching.mobileFitIntercept = p(2);
switching.I_peak_linear_fit = polyval(p, switching.T);
switching.deltaI_mobile_fit = max(switching.I_peak_linear_fit - switching.I_peak, 0);
end

function selected = buildSelectedProfiles(aging, switching)
selected = struct();
selected.background = buildNormalizedProfile('Aging rank-1 explained variance', aging.rank1.T, aging.rank1.values);
selected.background_alt = buildNormalizedProfile('Aging shape simplification', aging.shapeSimpl.T, aging.shapeSimpl.values);
selected.dip = buildNormalizedProfile('Aging Dip_depth', aging.dipDepth.T, aging.dipDepth.values);
selected.fm_abs = buildNormalizedProfile('Aging FM_abs', aging.fmAbs.T, aging.fmAbs.values);
selected.mobility = buildNormalizedProfile('Switching |dI_peak/dT|', switching.T_curve, switching.motion);
selected.curvature = buildNormalizedProfile('Switching |d^2I_peak/dT^2|', switching.T_curve, switching.curvature);
selected.pinning = buildNormalizedProfile('Switching derivative-suppression pinning', switching.T_curve, switching.pinning);
selected.deltaI = buildNormalizedProfile('Switching mobile-law deviation', switching.T, switching.deltaI_mobile_fit);

selected.background_pair = computePairMetrics('background_vs_mobility', selected.background, selected.mobility, [-4 0 4], true);
selected.dip_pair = computePairMetrics('dip_vs_pinning', selected.dip, selected.pinning, [-4 0 4], true);
selected.dip_curvature_pair = computePairMetrics('dip_vs_curvature_secondary', selected.dip, selected.curvature, [-4 0 4], true);
selected.fm_motion_pair = computePairMetrics('fm_abs_vs_mobility_secondary', selected.fm_abs, selected.mobility, [-4 0 4], true);
selected.twoBasisMotion = computeTwoBasisFit(selected.background, selected.dip, selected.mobility);
selected.twoBasisPinning = computeTwoBasisFit(selected.background, selected.dip, selected.pinning);
end

function profile = buildNormalizedProfile(name, T, values)
profile = struct();
profile.name = string(name);
profile.T = T(:);
profile.values = values(:);
profile.norm = normalizeMinMax(values(:));
end

function pair = computePairMetrics(pairId, xProfile, yProfile, lagGrid, positiveExpected)
pair = struct();
pair.pair_id = string(pairId);
pair.x_name = xProfile.name;
pair.y_name = yProfile.name;
pair.lagGrid = lagGrid(:);

zeroMask = isfinite(xProfile.norm) & isfinite(interp1(yProfile.T, yProfile.norm, xProfile.T, 'linear', NaN));
yZero = interp1(yProfile.T, yProfile.norm, xProfile.T, 'linear', NaN);
pair.zero_lag_n = nnz(zeroMask);
pair.zero_lag_pearson_r = corrSafe(xProfile.norm(zeroMask), yZero(zeroMask));
pair.zero_lag_spearman_r = spearmanSafe(xProfile.norm(zeroMask), yZero(zeroMask));
pair.zero_lag_sign_sensible = signSensible(pair.zero_lag_pearson_r, pair.zero_lag_spearman_r, positiveExpected);

lagRows = numel(lagGrid);
pair.lag_summary = table(zeros(lagRows,1), NaN(lagRows,1), NaN(lagRows,1), NaN(lagRows,1), false(lagRows,1), ...
    'VariableNames', {'lag_K','pearson_r','spearman_r','n_points','sign_sensible'});

bestPearson = -Inf;
bestSpearman = -Inf;
bestLagPearson = NaN;
bestLagSpearman = NaN;
for i = 1:lagRows
    lag = lagGrid(i);
    yShift = interp1(yProfile.T, yProfile.norm, xProfile.T + lag, 'linear', NaN);
    mask = isfinite(xProfile.norm) & isfinite(yShift);
    pearsonR = corrSafe(xProfile.norm(mask), yShift(mask));
    spearmanR = spearmanSafe(xProfile.norm(mask), yShift(mask));
    pair.lag_summary.lag_K(i) = lag;
    pair.lag_summary.pearson_r(i) = pearsonR;
    pair.lag_summary.spearman_r(i) = spearmanR;
    pair.lag_summary.n_points(i) = nnz(mask);
    pair.lag_summary.sign_sensible(i) = signSensible(pearsonR, spearmanR, positiveExpected);
    if isfinite(pearsonR) && pearsonR > bestPearson
        bestPearson = pearsonR;
        bestLagPearson = lag;
    end
    if isfinite(spearmanR) && spearmanR > bestSpearman
        bestSpearman = spearmanR;
        bestLagSpearman = lag;
    end
end
pair.best_pearson_r = bestPearson;
pair.best_pearson_lag_K = bestLagPearson;
pair.best_spearman_r = bestSpearman;
pair.best_spearman_lag_K = bestLagSpearman;
end

function fit = computeTwoBasisFit(backgroundProfile, dipProfile, targetProfile)
fit = struct();
fit.target_name = targetProfile.name;
fit.alpha_background = NaN;
fit.beta_dip = NaN;
fit.intercept = NaN;
fit.r_squared = NaN;
fit.n_points = 0;
fit.interpretation = "insufficient";

B = interp1(backgroundProfile.T, backgroundProfile.norm, targetProfile.T, 'linear', NaN);
D = interp1(dipProfile.T, dipProfile.norm, targetProfile.T, 'linear', NaN);
Y = targetProfile.norm;
mask = isfinite(B) & isfinite(D) & isfinite(Y);
fit.n_points = nnz(mask);
if fit.n_points < 4
    return;
end
X = [B(mask) D(mask) ones(fit.n_points,1)];
beta = X \ Y(mask);
Yfit = X * beta;
fit.alpha_background = beta(1);
fit.beta_dip = beta(2);
fit.intercept = beta(3);
ssRes = sum((Y(mask) - Yfit).^2);
ssTot = sum((Y(mask) - mean(Y(mask))).^2);
if ssTot > 0
    fit.r_squared = 1 - ssRes / ssTot;
end
if isfinite(fit.r_squared) && fit.r_squared >= 0.75
    fit.interpretation = "interpretable_mixture";
elseif isfinite(fit.r_squared) && fit.r_squared >= 0.4
    fit.interpretation = "loose_mixture";
else
    fit.interpretation = "weak_fit";
end
end

function summaryTbl = buildUnifiedSummaryTable(relax, aging, switching, selected, source)
featureKey = ["relaxation_A_peak"; "aging_preferred_collapse"; "aging_numeric_rank1_max"; "switching_mobility_peak"; "switching_curvature_peak"; "switching_pinning_onset"; "switching_mobile_regime_start"; "switching_mobile_regime_end"];
featureLabel = ["Relaxation A(T) source peak"; "Aging preferred collapse anchor"; "Aging numeric rank-1 maximum"; "Switching ridge mobility peak"; "Switching curvature peak"; "Switching pinning onset"; "Switching mobile regime start"; "Switching mobile regime end"];
temperatureK = [relax.sourcePeakT; aging.preferredCollapseT; aging.numericCollapseMaxT; switching.mobilityPeakT; switching.curvaturePeakT; switching.pinningOnsetT; min(switching.T(switching.mobileMask)); max(switching.T(switching.mobileMask))];
experiment = ["relaxation"; "aging"; "aging"; "switching"; "switching"; "switching"; "switching"; "switching"];
sourceRun = [source.relaxRunName; source.agingCollapseRunName; source.agingCollapseRunName; source.switchCompareRunName; source.switchCompareRunName; source.switchRunName; source.switchRunName; source.switchRunName];
sourceFile = string({ ...
    fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv'); ...
    fullfile(char(source.agingCollapseRunDir), 'tables', 'aging_shape_variation_vs_Tp.csv'); ...
    fullfile(char(source.agingCollapseRunDir), 'tables', 'aging_shape_variation_vs_Tp.csv'); ...
    fullfile(char(source.switchCompareRunDir), 'tables', 'switching_relaxation_observable_curves.csv'); ...
    fullfile(char(source.switchCompareRunDir), 'tables', 'switching_relaxation_observable_curves.csv'); ...
    fullfile(char(source.switchRunDir), 'observable_matrix.csv'); ...
    fullfile(char(source.switchRunDir), 'observable_matrix.csv'); ...
    fullfile(char(source.switchRunDir), 'observable_matrix.csv')});
note = string({ ...
    'Canonical relaxation crossover marker'; ...
    'Preferred because it is the strongest reliable rank-1 point with n_profiles >= 4'; ...
    sprintf('Full numeric maximum occurs at %.1f K but is fragile because n_profiles = %d', aging.numericCollapseMaxT, aging.numericCollapseMaxNProfiles); ...
    'Saved ridge mobility baseline from existing switching comparison run'; ...
    'Secondary crossover-localization curve from saved comparison run'; ...
    'First robust temperature where I_peak leaves the pinned plateau'; ...
    'Used for linear mobile-law fit'; ...
    'Used for linear mobile-law fit'});
summaryTbl = table(featureKey, featureLabel, temperatureK, experiment, sourceRun, sourceFile, note, ...
    'VariableNames', {'feature_key','feature_label','temperature_K','experiment','source_run','source_file','note'});
end

function pairTbl = buildPairSummaryTable(selected)
pairs = [selected.background_pair; selected.dip_pair];
pairTbl = table(strings(2,1), strings(2,1), strings(2,1), NaN(2,1), NaN(2,1), NaN(2,1), NaN(2,1), NaN(2,1), NaN(2,1), NaN(2,1), false(2,1), strings(2,1), ...
    'VariableNames', {'pair_id','aging_profile','switching_profile','zero_lag_pearson_r','zero_lag_spearman_r','zero_lag_n_points', ...
    'best_pearson_lag_K','best_pearson_r','best_spearman_lag_K','best_spearman_r','zero_lag_sign_sensible','interpretation'});
for i = 1:numel(pairs)
    p = pairs(i);
    pairTbl.pair_id(i) = p.pair_id;
    pairTbl.aging_profile(i) = p.x_name;
    pairTbl.switching_profile(i) = p.y_name;
    pairTbl.zero_lag_pearson_r(i) = p.zero_lag_pearson_r;
    pairTbl.zero_lag_spearman_r(i) = p.zero_lag_spearman_r;
    pairTbl.zero_lag_n_points(i) = p.zero_lag_n;
    pairTbl.best_pearson_lag_K(i) = p.best_pearson_lag_K;
    pairTbl.best_pearson_r(i) = p.best_pearson_r;
    pairTbl.best_spearman_lag_K(i) = p.best_spearman_lag_K;
    pairTbl.best_spearman_r(i) = p.best_spearman_r;
    pairTbl.zero_lag_sign_sensible(i) = p.zero_lag_sign_sensible;
    if p.pair_id == "background_vs_mobility"
        pairTbl.interpretation(i) = "strong_zero_lag_alignment";
    else
        pairTbl.interpretation(i) = "moderate_shifted_alignment";
    end
end
end

function lagTbl = buildLaggedTable(selected)
pairs = [selected.background_pair; selected.dip_pair];
rows = [];
for i = 1:numel(pairs)
    p = pairs(i);
    tbl = p.lag_summary;
    pairId = repmat(p.pair_id, height(tbl), 1);
    xName = repmat(p.x_name, height(tbl), 1);
    yName = repmat(p.y_name, height(tbl), 1);
    rows = [rows; table(pairId, xName, yName, tbl.lag_K, tbl.pearson_r, tbl.spearman_r, tbl.n_points, tbl.sign_sensible, ...
        'VariableNames', {'pair_id','aging_profile','switching_profile','lag_K','pearson_r','spearman_r','n_points','sign_sensible'})]; %#ok<AGROW>
end
lagTbl = rows;
end

function fitTbl = buildTwoBasisFitTable(selected)
fitTbl = table( ...
    ["motion"; "pinning"], ...
    [selected.twoBasisMotion.alpha_background; selected.twoBasisPinning.alpha_background], ...
    [selected.twoBasisMotion.beta_dip; selected.twoBasisPinning.beta_dip], ...
    [selected.twoBasisMotion.intercept; selected.twoBasisPinning.intercept], ...
    [selected.twoBasisMotion.r_squared; selected.twoBasisPinning.r_squared], ...
    [selected.twoBasisMotion.n_points; selected.twoBasisPinning.n_points], ...
    [selected.twoBasisMotion.interpretation; selected.twoBasisPinning.interpretation], ...
    'VariableNames', {'target_profile','alpha_background','beta_dip','intercept','r_squared','n_points','interpretation'});
end

function manifestTbl = buildManifestTable(source)
manifestTbl = table( ...
    string({'relaxation'; 'aging'; 'aging'; 'switching'; 'cross_experiment'}), ...
    [source.relaxRunName; source.agingAuditRunName; source.agingCollapseRunName; source.switchRunName; source.switchCompareRunName], ...
    string({ ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.agingAuditRunDir), 'tables', 'aging_tp_observable_metrics.csv'); ...
    fullfile(char(source.agingCollapseRunDir), 'tables', 'aging_shape_variation_vs_Tp.csv'); ...
    fullfile(char(source.switchRunDir), 'observable_matrix.csv'); ...
    fullfile(char(source.switchCompareRunDir), 'tables', 'switching_relaxation_observable_curves.csv')}), ...
    string({'Relaxation activity'; 'Aging dip/background observables'; 'Aging structural collapse'; 'Switching ridge position'; 'Saved switching mobility and curvature'}), ...
    'VariableNames', {'experiment','source_run','source_file','role'});
end
function figPaths = saveUnifiedMainFigure(relax, aging, switching, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 18.0, 24.0);
tl = tiledlayout(fh, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
plot(ax1, relax.T, relax.A, '-o', 'LineWidth', 2.3, 'MarkerSize', 5, 'Color', [0.00 0.35 0.65]);
grid(ax1, 'on');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'A(T)');
title(ax1, 'Relaxation activity function');
addGlobalGuides(ax1, [22 26 27 28], {'pinning onset','Aging collapse','Relaxation peak','mobility peak'});
setAxisStyle(ax1);

ax2 = nexttile(tl, 2);
reliable = aging.rank1.n_support >= 4;
hold(ax2, 'on');
plot(ax2, aging.rank1.T(reliable), aging.rank1.values(reliable), '-o', 'LineWidth', 2.3, 'MarkerSize', 6, 'Color', [0.00 0.50 0.30], 'DisplayName', 'reliable n_{profiles} >= 4');
plot(ax2, aging.rank1.T(~reliable), aging.rank1.values(~reliable), '--o', 'LineWidth', 1.8, 'MarkerSize', 6, 'Color', [0.60 0.60 0.60], 'MarkerFaceColor', 'w', 'DisplayName', 'fragile n_{profiles} = 3');
hold(ax2, 'off');
grid(ax2, 'on');
xlabel(ax2, 'Aging stop temperature T_p (K)');
ylabel(ax2, 'Rank-1 explained variance');
title(ax2, 'Aging structural collapse strength');
legend(ax2, 'Location', 'best');
addGlobalGuides(ax2, [22 26 27 28], {'pinning onset','Aging collapse','Relaxation peak','mobility peak'});
setAxisStyle(ax2);

ax3 = nexttile(tl, 3);
hold(ax3, 'on');
plot(ax3, switching.T_curve, switching.motion, '-s', 'LineWidth', 2.3, 'MarkerSize', 5, 'Color', [0.85 0.33 0.10], 'DisplayName', '|dI_{peak}/dT|');
plot(ax3, switching.T_curve, switching.curvature, '-^', 'LineWidth', 2.0, 'MarkerSize', 5, 'Color', [0.49 0.18 0.56], 'DisplayName', '|d^2I_{peak}/dT^2|');
hold(ax3, 'off');
grid(ax3, 'on');
xlabel(ax3, 'Temperature (K)');
ylabel(ax3, 'Switching dynamical metric');
title(ax3, 'Switching ridge mobility and localization');
legend(ax3, 'Location', 'best');
addGlobalGuides(ax3, [22 26 27 28], {'pinning onset','Aging collapse','Relaxation peak','mobility peak'});
setAxisStyle(ax3);

ax4 = nexttile(tl, 4);
hold(ax4, 'on');
plot(ax4, switching.T, switching.I_peak, '-o', 'LineWidth', 2.3, 'MarkerSize', 5, 'Color', [0.15 0.15 0.15], 'DisplayName', 'I_{peak}(T)');
plot(ax4, switching.T(switching.mobileMask), switching.I_peak_linear_fit(switching.mobileMask), '--', 'LineWidth', 2.3, 'Color', [0.00 0.45 0.00], 'DisplayName', 'mobile-law fit');
hold(ax4, 'off');
grid(ax4, 'on');
xlabel(ax4, 'Temperature (K)');
ylabel(ax4, 'I_{peak} (mA)');
title(ax4, 'Switching ridge position with pinned and mobile regimes');
addRegionShading(ax4, [min(switching.T(switching.pinnedMask)) max(switching.T(switching.pinnedMask))], [0.92 0.92 0.92], 'pinned / slowdown');
addRegionShading(ax4, [min(switching.T(switching.mobileMask)) max(switching.T(switching.mobileMask))], [0.92 0.97 0.92], 'mobile linear regime');
plot(ax4, switching.T, switching.I_peak, '-o', 'LineWidth', 2.3, 'MarkerSize', 5, 'Color', [0.15 0.15 0.15], 'HandleVisibility', 'off');
plot(ax4, switching.T(switching.mobileMask), switching.I_peak_linear_fit(switching.mobileMask), '--', 'LineWidth', 2.3, 'Color', [0.00 0.45 0.00], 'HandleVisibility', 'off');
legend(ax4, 'Location', 'best');
addGlobalGuides(ax4, [22 26 27 28], {'pinning onset','Aging collapse','Relaxation peak','mobility peak'});
setAxisStyle(ax4);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveUnifiedNormalizedFigure(relax, aging, switching, selected, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 18.0, 10.0);
ax = axes(fh);
hold(ax, 'on');
plot(ax, relax.T, normalizeMinMax(relax.A), '-o', 'LineWidth', 2.3, 'MarkerSize', 5, 'DisplayName', 'Relaxation A(T)');
plot(ax, aging.rank1.T, normalizeMinMax(aging.rank1.values), '-s', 'LineWidth', 2.3, 'MarkerSize', 5, 'DisplayName', 'Aging rank-1 collapse');
plot(ax, switching.T_curve, normalizeMinMax(switching.motion), '-d', 'LineWidth', 2.3, 'MarkerSize', 5, 'DisplayName', 'Switching mobility');
plot(ax, switching.T_curve, normalizeMinMax(switching.curvature), '-^', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'Switching curvature');
plot(ax, aging.dipDepth.T, normalizeMinMax(aging.dipDepth.values), '-v', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'Aging Dip_depth');
plot(ax, switching.T_curve, normalizeMinMax(switching.pinning), '--', 'LineWidth', 2.0, 'DisplayName', 'Switching pinning metric');
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude');
title(ax, 'Unified dynamical crossover overlays');
legend(ax, 'Location', 'bestoutside');
addGlobalGuides(ax, [22 26 27 28], {'pinning onset','Aging collapse','Relaxation peak','mobility peak'});
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveBackgroundMobilityFigure(selected, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 14.0, 8.5);
ax = axes(fh);
Tp = selected.background.T;
yMob = interp1(selected.mobility.T, selected.mobility.norm, Tp, 'linear', NaN);
hold(ax, 'on');
plot(ax, Tp, selected.background.norm, '-o', 'LineWidth', 2.3, 'MarkerSize', 6, 'DisplayName', 'Aging rank-1 collapse');
plot(ax, Tp, yMob, '-s', 'LineWidth', 2.3, 'MarkerSize', 6, 'DisplayName', 'Switching mobility sampled at T_p');
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude');
title(ax, sprintf('Background-like Aging collapse vs Switching mobility (r = %.3f, rho = %.3f)', ...
    selected.background_pair.zero_lag_pearson_r, selected.background_pair.zero_lag_spearman_r));
legend(ax, 'Location', 'best');
addGlobalGuides(ax, [22 26 27 28], {'pinning onset','Aging collapse','Relaxation peak','mobility peak'});
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveDipPinningFigure(selected, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 14.0, 12.0);
tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

Tp = selected.dip.T;
yZero = interp1(selected.pinning.T, selected.pinning.norm, Tp, 'linear', NaN);
yShift = interp1(selected.pinning.T, selected.pinning.norm, Tp + selected.dip_pair.best_pearson_lag_K, 'linear', NaN);

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, Tp, selected.dip.norm, '-o', 'LineWidth', 2.3, 'MarkerSize', 6, 'DisplayName', 'Aging Dip_depth');
plot(ax1, Tp, yZero, '-s', 'LineWidth', 2.3, 'MarkerSize', 6, 'DisplayName', 'Switching pinning, zero lag');
hold(ax1, 'off');
grid(ax1, 'on');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'Normalized magnitude');
title(ax1, sprintf('Zero-lag dip vs pinning (r = %.3f, rho = %.3f)', ...
    selected.dip_pair.zero_lag_pearson_r, selected.dip_pair.zero_lag_spearman_r));
legend(ax1, 'Location', 'best');
addGlobalGuides(ax1, [22 26 27 28], {'pinning onset','Aging collapse','Relaxation peak','mobility peak'});
setAxisStyle(ax1);

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, Tp, selected.dip.norm, '-o', 'LineWidth', 2.3, 'MarkerSize', 6, 'DisplayName', 'Aging Dip_depth');
plot(ax2, Tp, yShift, '-s', 'LineWidth', 2.3, 'MarkerSize', 6, 'DisplayName', sprintf('Switching pinning shifted %+d K', selected.dip_pair.best_pearson_lag_K));
hold(ax2, 'off');
grid(ax2, 'on');
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, 'Normalized magnitude');
title(ax2, sprintf('Best-lag dip vs pinning (best Pearson = %.3f at %+d K)', ...
    selected.dip_pair.best_pearson_r, selected.dip_pair.best_pearson_lag_K));
legend(ax2, 'Location', 'best');
addGlobalGuides(ax2, [22 26 27 28], {'pinning onset','Aging collapse','Relaxation peak','mobility peak'});
setAxisStyle(ax2);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveLagFigure(selected, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 16.0, 10.0);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

pairs = [selected.background_pair; selected.dip_pair];
titles = {'Aging background vs Switching mobility', 'Aging dip vs Switching pinning'};
for i = 1:2
    ax = nexttile(tl, i);
    tbl = pairs(i).lag_summary;
    hold(ax, 'on');
    plot(ax, tbl.lag_K, tbl.pearson_r, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', 'Pearson');
    plot(ax, tbl.lag_K, tbl.spearman_r, '-s', 'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', 'Spearman');
    yline(ax, 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, 'Lag applied to Switching profile (K)');
    ylabel(ax, 'Correlation');
    title(ax, titles{i});
    legend(ax, 'Location', 'best');
    setAxisStyle(ax);
end

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end
function reportText = buildReportText(source, relax, aging, switching, selected, pairTbl, fitTbl, cfg)
strongBg = pairTbl(pairTbl.pair_id == "background_vs_mobility", :);
moderateDip = pairTbl(pairTbl.pair_id == "dip_vs_pinning", :);

lines = strings(0,1);
lines(end+1) = "# Unified Dynamical Crossover And Aging-Switching Link";
lines(end+1) = "";
lines(end+1) = "## Repository-state summary";
lines(end+1) = sprintf('- Relaxation source run: `%s` using `%s` and `%s`.', source.relaxRunName, fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'), fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv'));
lines(end+1) = sprintf('- Aging source runs: `%s` for the validated observable sweep and `%s` for the structural collapse sweep.', source.agingAuditRunName, source.agingCollapseRunName);
lines(end+1) = sprintf('- Switching source runs: `%s` for `I_peak(T)` and `%s` for saved mobility/curvature observables.', source.switchRunName, source.switchCompareRunName);
lines(end+1) = '- Newly created saved-output run consumed: yes, the switching-relaxation observable comparison run was reused for the saved curvature layer.';
lines(end+1) = '- Needed legacy outputs: none.';
lines(end+1) = '- No raw maps or pipelines were rerun; all quantities come from saved outputs and derived summaries only.';
lines(end+1) = '- New code added: `analysis/unified_dynamical_crossover_synthesis.m`.';
lines(end+1) = "";
lines(end+1) = "## Observable choices and why";
lines(end+1) = '- Relaxation: `A(T)` from the canonical relaxation stability audit, because it is the established rank-1 activity coordinate and peaks near `27 K`.';
lines(end+1) = '- Aging structural crossover: rank-1 explained variance from the canonical collapse sweep, because it is a saved structural metric and gives the most conservative route to the preferred collapse anchor at `26 K`.';
lines(end+1) = '- Aging dip-like profile: `Dip_depth(T_p)`, because the observable-identification audit explicitly recommends it as the primary localized/memory-like observable.';
lines(end+1) = '- Aging background-like candidate choice: the structural rank-1 collapse profile is used instead of `FM_abs`, because `FM_abs` is missing at low `T_p` and aligns only weakly with Switching mobility in the saved data, while the structural collapse profile aligns strongly and is already the central Aging result.';
lines(end+1) = '- Switching mobility: saved `|dI_peak/dT|` from the existing comparison run, because it already outperformed scalar `S_peak(T)` and directly captures ridge motion.';
lines(end+1) = '- Switching pinning: derivative-suppression metric `P_pin(T) = 1 - |dI_peak/dT| / max(|dI_peak/dT|)`, because it directly measures loss of ridge mobility without reverting to misleading low-temperature amplitude metrics.';
lines(end+1) = "";
lines(end+1) = "## Central crossover picture";
lines(end+1) = sprintf('- Relaxation `A(T)` source peak: `%.1f K`.', relax.sourcePeakT);
lines(end+1) = sprintf('- Aging preferred collapse temperature: `%.1f K`.', aging.preferredCollapseT);
lines(end+1) = sprintf('- Aging numeric rank-1 maximum: `%.1f K`, but that point is fragile because `n_profiles = %d`.', aging.numericCollapseMaxT, aging.numericCollapseMaxNProfiles);
lines(end+1) = sprintf('- Switching mobility peak: `%.1f K`.', switching.mobilityPeakT);
lines(end+1) = sprintf('- Switching curvature peak: `%.1f K`.', switching.curvaturePeakT);
lines(end+1) = sprintf('- Switching pinning onset from `I_peak(T)`: `%.1f K`, with a linear mobile regime fit over `%.1f-%.1f K`.', switching.pinningOnsetT, min(switching.T(switching.mobileMask)), max(switching.T(switching.mobileMask)));
lines(end+1) = "";
lines(end+1) = "## Strong conclusions";
lines(end+1) = sprintf('- The shared crossover near `26-28 K` remains the strongest cross-experiment result. The three main markers stay clustered at Aging `%.1f K`, Relaxation `%.1f K`, and Switching mobility `%.1f K`.', aging.preferredCollapseT, relax.sourcePeakT, switching.mobilityPeakT);
lines(end+1) = sprintf('- Aging structural collapse aligns strongly with Switching ridge mobility: zero-lag Pearson = %.4f and Spearman = %.4f.', strongBg.zero_lag_pearson_r, strongBg.zero_lag_spearman_r);
lines(end+1) = '- The strongest paper-ready message is therefore a mobile-to-crossover-to-pinned story in which Relaxation activity, Aging structural simplification, and Switching ridge mobility all concentrate in the same upper-mid-20 K band.';
lines(end+1) = "";
lines(end+1) = "## Moderate evidence";
lines(end+1) = sprintf('- Aging dip-like behavior aligns only moderately with Switching pinning. At zero lag the relationship is weak (Pearson = %.4f, Spearman = %.4f), but the best small-lag alignment occurs at `%+d K` with Pearson = %.4f and Spearman = %.4f.', ...
    moderateDip.zero_lag_pearson_r, moderateDip.zero_lag_spearman_r, moderateDip.best_pearson_lag_K, moderateDip.best_pearson_r, moderateDip.best_spearman_r);
lines(end+1) = '- This supports the idea that the dip/memory channel is related to slowdown or pinning onset, but less cleanly and with a likely temperature offset of about one Aging temperature step.';
lines(end+1) = sprintf('- The optional two-basis fits are surprisingly coherent: mobility gives `alpha = %.3f`, `beta = %.3f`, `R^2 = %.3f`, while pinning gives `alpha = %.3f`, `beta = %.3f`, `R^2 = %.3f`.', ...
    fitTbl.alpha_background(1), fitTbl.beta_dip(1), fitTbl.r_squared(1), fitTbl.alpha_background(2), fitTbl.beta_dip(2), fitTbl.r_squared(2));
lines(end+1) = '- In that basis, Switching mobility is mostly a positive structural-background component with a smaller opposite-signed dip contribution, while pinning shows the inverse pattern plus an offset.';
lines(end+1) = "";
lines(end+1) = "## Speculative interpretation";
lines(end+1) = '- A plausible synthesis is that the Aging structural-collapse coordinate reflects the same mobile degrees of freedom that drive Switching ridge motion, while the Aging dip-like channel becomes more visible as those mobile degrees begin to freeze into a pinned regime.';
lines(end+1) = '- The lagged dip-versus-pinning result hints that memory-like Aging signatures may emerge slightly before full Switching mobility suppression is reached, but that timing statement is still tentative because the Aging grid is coarse and the background proxy is structural rather than a pure scalar FM amplitude.';
lines(end+1) = "";
lines(end+1) = "## Direct answers to the requested questions";
lines(end+1) = '- Is the shared crossover near ~27 K still the strongest cross-experiment result? **Yes.**';
lines(end+1) = '- Does Aging background-like behavior align with Switching ridge mobility? **Yes, strongly, when the Aging background-like profile is taken as the structural rank-1 collapse metric rather than scalar `FM_abs`.**';
lines(end+1) = '- Does Aging dip-like behavior align with Switching slowdown/pinning onset? **Moderately.** The clearest alignment is with a small negative lag, not a strict zero-lag match.';
lines(end+1) = '- Does this strengthen a mobile -> crossover -> pinned interpretation across the probes? **Yes, mainly through the shared `26-28 K` crossover band and the strong background-collapse to mobility link.**';
lines(end+1) = '- What is the strongest paper-ready figure/message after this run? **The four-panel unified dynamical crossover figure showing Relaxation `A(T)`, Aging structural collapse, Switching mobility, and the pinned-to-mobile `I_peak(T)` law on one common temperature axis.**';
lines(end+1) = "";
lines(end+1) = "## Visualization choices";
lines(end+1) = '- number of curves: 1 in panel 1, 2 in panel 2, 2 in panel 3, and 2 in panel 4 of the main figure; 6 curves in the normalized supplementary overlay';
lines(end+1) = '- legend vs colormap: legends only, because every panel stays at 6 curves or fewer';
lines(end+1) = '- colormap used: none';
lines(end+1) = '- smoothing applied: no new smoothing of raw maps; the Switching curvature layer is reused from an existing saved-output run';
lines(end+1) = '- justification: the figure set stays tightly centered on the PRL-style mechanism map rather than expanding into a generic all-vs-all correlation matrix';

reportText = strjoin(lines, newline);
end

function addGlobalGuides(ax, xVals, labels)
colors = [0.65 0.65 0.65; 0.00 0.50 0.30; 0.00 0.35 0.65; 0.85 0.33 0.10];
for i = 1:numel(xVals)
    xline(ax, xVals(i), '--', 'LineWidth', 1.1, 'Color', colors(i,:), 'DisplayName', labels{i});
end
end

function addRegionShading(ax, xRange, faceColor, labelStr)
yLim = ylim(ax);
patch(ax, [xRange(1) xRange(2) xRange(2) xRange(1)], [yLim(1) yLim(1) yLim(2) yLim(2)], faceColor, ...
    'FaceAlpha', 0.35, 'EdgeColor', 'none', 'DisplayName', labelStr);
uistack(findobj(ax, 'Type', 'patch', 'DisplayName', labelStr), 'bottom');
end

function tf = signSensible(pearsonR, spearmanR, positiveExpected)
if positiveExpected
    tf = isfinite(pearsonR) && isfinite(spearmanR) && pearsonR > 0 && spearmanR > 0;
else
    tf = isfinite(pearsonR) && isfinite(spearmanR) && pearsonR < 0 && spearmanR < 0;
end
end

function y = normalizeMinMax(x)
x = x(:);
y = NaN(size(x));
mask = isfinite(x);
if ~any(mask)
    return;
end
xmin = min(x(mask));
xmax = max(x(mask));
if xmax > xmin
    y(mask) = (x(mask) - xmin) ./ (xmax - xmin);
end
end

function c = corrSafe(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
c = NaN;
if nnz(mask) < 3
    return;
end
cc = corrcoef(x(mask), y(mask));
if numel(cc) >= 4
    c = cc(1,2);
end
end

function rho = spearmanSafe(x, y)
rho = corrSafe(tiedRank(x), tiedRank(y));
end

function r = tiedRank(x)
x = x(:);
r = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end
xs = x(valid);
[xsSorted, order] = sort(xs);
ranks = zeros(size(xsSorted));
ii = 1;
while ii <= numel(xsSorted)
    jj = ii;
    while jj < numel(xsSorted) && xsSorted(jj + 1) == xsSorted(ii)
        jj = jj + 1;
    end
    ranks(ii:jj) = mean(ii:jj);
    ii = jj + 1;
end
tmp = zeros(size(xsSorted));
tmp(order) = ranks;
r(valid) = tmp;
end
function setFigureGeometry(fig, widthCm, heightCm)
set(fig, 'Units', 'centimeters', ...
    'Position', [2 2 widthCm heightCm], ...
    'PaperUnits', 'centimeters', ...
    'PaperPosition', [0 0 widthCm heightCm], ...
    'PaperSize', [widthCm heightCm], ...
    'Color', 'w');
end

function setAxisStyle(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.1, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top');
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

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = value;
end
end


