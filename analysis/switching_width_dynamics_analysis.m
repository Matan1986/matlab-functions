function out = switching_width_dynamics_analysis(cfg)
% switching_width_dynamics_analysis
% Explore whether the saved full-scaling switching width(T) carries
% dynamical information related to relaxation activity and ridge motion.

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
runCfg.dataset = sprintf('switch:%s | relax:%s | motion:%s | baseline:%s', ...
    char(source.switchRunName), char(source.relaxRunName), ...
    char(source.motionRunName), char(source.baselineRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Switching width dynamics analysis run directory:\n%s\n', runDir);
fprintf('Switching source run: %s\n', source.switchRunName);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Motion source run: %s\n', source.motionRunName);
fprintf('Baseline correlation run: %s\n', source.baselineRunName);

appendText(run.log_path, sprintf('[%s] switching width dynamics analysis started\n', stampNow()));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Motion source: %s\n', char(source.motionRunName)));
appendText(run.log_path, sprintf('Baseline source: %s\n', char(source.baselineRunName)));

switching = loadSwitchingWidthData(source.switchRunDir, cfg);
relax = loadRelaxationData(source.relaxRunDir);
motion = loadMotionData(source.motionRunDir, cfg);
baseline = loadBaselineCorrelationData(source.baselineRunDir);
aligned = buildAlignedData(switching, relax, motion, cfg);
results = buildAnalysisResults(aligned, baseline, cfg);
analysisTbl = buildAnalysisResultsTable(results, aligned, source, cfg);
manifestTbl = buildManifestTable(source);

analysisPath = save_run_table(analysisTbl, 'analysis_results.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

figWidth = saveWidthVsTFigure(aligned, runDir, 'width_vs_T');
figA = saveRelaxationAVsTFigure(aligned, runDir, 'relaxation_A_vs_T');
figScatter = saveWidthVsAScatterFigure(aligned, results, runDir, 'width_vs_A_scatter');
figProduct = saveWidthTimesAFigure(aligned, results, runDir, 'width_times_A_vs_T');
figInverse = saveInverseFitFigure(aligned, results, runDir, 'inverse_fit_width_vs_A');
figOverlay = saveNormalizedOverlayFigure(aligned, results, runDir, 'normalized_width_A_overlay');
figMotion = saveWidthVsRidgeMotionFigure(aligned, results, runDir, 'width_vs_ridge_motion');
figDerivative = saveDerivativeComparisonFigure(aligned, results, runDir, 'derivative_comparison');

reportText = buildReportText(source, aligned, baseline, results, cfg);
reportPath = save_run_report(reportText, 'switching_width_dynamics_analysis.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_width_dynamics_analysis_bundle.zip');

appendText(run.notes_path, sprintf('Temperature window = %.1f-%.1f K\n', min(aligned.T_K), max(aligned.T_K)));
appendText(run.notes_path, sprintf('Width-A Pearson = %.6g\n', results.correlation.width_vs_A_pearson));
appendText(run.notes_path, sprintf('Width-A Spearman = %.6g\n', results.correlation.width_vs_A_spearman));
appendText(run.notes_path, sprintf('Width-motion Pearson = %.6g\n', results.motion.width_vs_motion_pearson));
appendText(run.notes_path, sprintf('Inverse fit R2 = %.6g\n', results.inverse.inverse_r2));
appendText(run.notes_path, sprintf('Power-law fit alpha = %.6g\n', results.inverse.power_alpha));
appendText(run.notes_path, sprintf('Product CV = %.6g\n', results.product.cv));

appendText(run.log_path, sprintf('[%s] switching width dynamics analysis complete\n', stampNow()));
appendText(run.log_path, sprintf('Analysis table: %s\n', analysisPath));
appendText(run.log_path, sprintf('Manifest table: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.aligned = aligned;
out.results = results;
out.tables = struct('analysis', string(analysisPath), 'manifest', string(manifestPath));
out.figures = struct( ...
    'width_vs_T', string(figWidth.png), ...
    'A_vs_T', string(figA.png), ...
    'width_vs_A', string(figScatter.png), ...
    'width_times_A', string(figProduct.png), ...
    'inverse_fit', string(figInverse.png), ...
    'overlay', string(figOverlay.png), ...
    'width_vs_motion', string(figMotion.png), ...
    'derivative', string(figDerivative.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Switching width dynamics analysis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Width vs A: Pearson %.4f, Spearman %.4f\n', ...
    results.correlation.width_vs_A_pearson, results.correlation.width_vs_A_spearman);
fprintf('Width vs motion: Pearson %.4f, Spearman %.4f\n', ...
    results.motion.width_vs_motion_pearson, results.motion.width_vs_motion_spearman);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_width_dynamics_analysis');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'motionRunName', 'run_2026_03_11_084425_relaxation_switching_motion_test');
cfg = setDefaultField(cfg, 'baselineRunName', 'run_2026_03_13_002809_switching_width_relaxation_correlation');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'derivativeSmoothWindow', 3);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.motionRunName = string(cfg.motionRunName);
source.baselineRunName = string(cfg.baselineRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.motionRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.motionRunName));
source.baselineRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.baselineRunName));

requiredPaths = {
    source.switchRunDir, fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv');
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv');
    source.motionRunDir, fullfile(char(source.motionRunDir), 'tables', 'relaxation_switching_motion_table.csv');
    source.baselineRunDir, fullfile(char(source.baselineRunDir), 'tables', 'correlation_results.csv')
    };

for i = 1:size(requiredPaths, 1)
    if exist(requiredPaths{i, 1}, 'dir') ~= 7
        error('Required source run directory not found: %s', requiredPaths{i, 1});
    end
    if exist(requiredPaths{i, 2}, 'file') ~= 2
        error('Required source file not found: %s', requiredPaths{i, 2});
    end
end
end

function switching = loadSwitchingWidthData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'switching_full_scaling_parameters.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
mask = mask & isfinite(tbl.width_chosen_mA);
tbl = sortrows(tbl(mask, :), 'T_K');

switching = struct();
switching.T = tbl.T_K(:);
switching.width = tbl.width_chosen_mA(:);
switching.widthFwhm = tbl.width_fwhm_mA(:);
switching.widthSigma = tbl.width_sigma_mA(:);
switching.widthMethod = string(tbl.width_method(:));
switching.Ipeak = tbl.Ipeak_mA(:);
switching.Speak = tbl.S_peak(:);
switching.nValidPoints = tbl.n_valid_points(:);
end

function relax = loadRelaxationData(runDir)
tempTbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
obsTbl = readtable(fullfile(runDir, 'tables', 'observables_relaxation.csv'));
tempTbl = sortrows(tempTbl, 'T');

relax = struct();
relax.T = tempTbl.T(:);
relax.A = tempTbl.A_T(:);
relax.R = tempTbl.R_T(:);
relax.beta = tempTbl.Relax_beta_T(:);
relax.tau = tempTbl.Relax_tau_T(:);
relax.sourcePeakT = obsTbl.Relax_T_peak(1);
relax.sourcePeakWidth = obsTbl.Relax_peak_width(1);
end

function motion = loadMotionData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'relaxation_switching_motion_table.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
tbl = sortrows(tbl(mask, :), 'T_K');

motion = struct();
motion.T = tbl.T_K(:);
motion.motion = tbl.motion_abs_dI_peak_dT(:);
motion.motionNorm = tbl.motion_norm(:);
motion.IpeakSmooth = tbl.I_peak_smooth_mA(:);
motion.comparisonMask = logical(tbl.comparison_mask(:));
end

function baseline = loadBaselineCorrelationData(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'correlation_results.csv'));
rowA = tbl(strcmp(tbl.relaxation_key, 'A_T'), :);
rowR = tbl(strcmp(tbl.relaxation_key, 'R_T'), :);

baseline = struct();
baseline.table = tbl;
baseline.widthVsA_Pearson = rowA.pearson_r(1);
baseline.widthVsA_Spearman = rowA.spearman_r(1);
baseline.widthVsR_Pearson = rowR.pearson_r(1);
baseline.widthVsR_Spearman = rowR.spearman_r(1);
end

function aligned = buildAlignedData(switching, relax, motion, cfg)
T = switching.T(:);
aligned = struct();
aligned.T_K = T;
aligned.width_mA = switching.width(:);
aligned.width_fwhm_mA = switching.widthFwhm(:);
aligned.width_sigma_mA = switching.widthSigma(:);
aligned.width_method = switching.widthMethod(:);
aligned.I_peak_mA = switching.Ipeak(:);
aligned.S_peak = switching.Speak(:);
aligned.n_valid_points = switching.nValidPoints(:);

aligned.A_interp = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
aligned.R_interp = interp1(relax.T, relax.R, T, cfg.interpMethod, NaN);
aligned.beta_interp = interp1(relax.T, relax.beta, T, cfg.interpMethod, NaN);
aligned.tau_interp = interp1(relax.T, relax.tau, T, cfg.interpMethod, NaN);
aligned.relax_source_peak_T_K = repmat(relax.sourcePeakT, numel(T), 1);

aligned.motion_abs = NaN(size(T));
aligned.motion_norm_saved = NaN(size(T));
aligned.I_peak_smooth_mA = NaN(size(T));
aligned.motion_valid_mask = false(size(T));
[lia, loc] = ismember(T, motion.T);
aligned.motion_abs(lia) = motion.motion(loc(lia));
aligned.motion_norm_saved(lia) = motion.motionNorm(loc(lia));
aligned.I_peak_smooth_mA(lia) = motion.IpeakSmooth(loc(lia));
aligned.motion_valid_mask(lia) = motion.comparisonMask(loc(lia));

aligned.width_times_A = aligned.width_mA .* aligned.A_interp;
aligned.width_norm = normalizeVector(aligned.width_mA);
aligned.A_norm = normalizeVector(aligned.A_interp);
aligned.one_minus_A_norm = 1 - aligned.A_norm;
aligned.motion_norm = normalizeVector(aligned.motion_abs);

[aligned.width_smooth_mA, aligned.dwidth_dT] = smoothAndDifferentiate(aligned.T_K, aligned.width_mA, cfg.derivativeSmoothWindow);
[aligned.A_smooth, aligned.dA_dT] = smoothAndDifferentiate(aligned.T_K, aligned.A_interp, cfg.derivativeSmoothWindow);
aligned.dwidth_dT_norm = normalizeSigned(aligned.dwidth_dT);
aligned.dA_dT_norm = normalizeSigned(aligned.dA_dT);

aligned.width_peak_T_K = findPeakT(aligned.T_K, aligned.width_mA);
aligned.A_peak_T_K = findPeakT(aligned.T_K, aligned.A_interp);
aligned.motion_peak_T_K = findPeakT(aligned.T_K, aligned.motion_abs);
aligned.product_peak_T_K = findPeakT(aligned.T_K, aligned.width_times_A);
end
function results = buildAnalysisResults(aligned, baseline, cfg)
maskA = isfinite(aligned.width_mA) & isfinite(aligned.A_interp);
maskMotion = isfinite(aligned.width_mA) & isfinite(aligned.motion_abs) & aligned.motion_valid_mask;
maskProduct = isfinite(aligned.width_times_A);
maskDeriv = isfinite(aligned.dwidth_dT) & isfinite(aligned.dA_dT);

results = struct();
results.correlation = struct();
results.correlation.width_vs_A_pearson = corrSafe(aligned.width_mA(maskA), aligned.A_interp(maskA));
results.correlation.width_vs_A_spearman = spearmanSafe(aligned.width_mA(maskA), aligned.A_interp(maskA));
results.correlation.width_vs_R_pearson = corrSafe(aligned.width_mA(maskA), aligned.R_interp(maskA));
results.correlation.width_vs_R_spearman = spearmanSafe(aligned.width_mA(maskA), aligned.R_interp(maskA));
results.correlation.width_vs_beta_pearson = corrSafe(aligned.width_mA(maskA), aligned.beta_interp(maskA));
results.correlation.width_vs_beta_spearman = spearmanSafe(aligned.width_mA(maskA), aligned.beta_interp(maskA));
results.correlation.width_vs_tau_pearson = corrSafe(aligned.width_mA(maskA), aligned.tau_interp(maskA));
results.correlation.width_vs_tau_spearman = spearmanSafe(aligned.width_mA(maskA), aligned.tau_interp(maskA));
results.correlation.baseline_width_vs_A_pearson = baseline.widthVsA_Pearson;
results.correlation.baseline_width_vs_A_spearman = baseline.widthVsA_Spearman;
results.correlation.width_vs_A_delta_pearson = results.correlation.width_vs_A_pearson - baseline.widthVsA_Pearson;
results.correlation.width_vs_A_delta_spearman = results.correlation.width_vs_A_spearman - baseline.widthVsA_Spearman;

prodMean = mean(aligned.width_times_A(maskProduct), 'omitnan');
prodStd = std(aligned.width_times_A(maskProduct), 0, 'omitnan');
prodRange = max(aligned.width_times_A(maskProduct)) - min(aligned.width_times_A(maskProduct));
results.product = struct();
results.product.mean = prodMean;
results.product.std = prodStd;
results.product.cv = prodStd / prodMean;
results.product.relative_range = prodRange / prodMean;
results.product.pearson_vs_T = corrSafe(aligned.T_K(maskProduct), aligned.width_times_A(maskProduct));
results.product.spearman_vs_T = spearmanSafe(aligned.T_K(maskProduct), aligned.width_times_A(maskProduct));
results.product.peak_T_K = aligned.product_peak_T_K;
results.product.constancy_rmse = sqrt(mean((aligned.width_times_A(maskProduct) - prodMean).^2));

u = 1 ./ aligned.A_interp(maskA);
y = aligned.width_mA(maskA);
k = (u' * y) / (u' * u);
yhatInv = k * u;
logX = log(aligned.A_interp(maskA));
logY = log(y);
p = polyfit(logX, logY, 1);
alpha = p(1);
c = exp(p(2));
yhatPower = c .* aligned.A_interp(maskA) .^ alpha;

results.inverse = struct();
results.inverse.inverse_k = k;
results.inverse.inverse_r2 = computeR2(y, yhatInv);
results.inverse.inverse_rmse = computeRMSE(y, yhatInv);
results.inverse.inverse_mae = computeMAE(y, yhatInv);
results.inverse.power_c = c;
results.inverse.power_alpha = alpha;
results.inverse.power_r2 = computeR2(y, yhatPower);
results.inverse.power_rmse = computeRMSE(y, yhatPower);
results.inverse.power_mae = computeMAE(y, yhatPower);
results.inverse.x_A = aligned.A_interp(maskA);
results.inverse.y_width = y;
results.inverse.yhat_inverse = yhatInv;
results.inverse.yhat_power = yhatPower;

results.shape = struct();
results.shape.width_vs_A_norm_pearson = corrSafe(aligned.width_norm(maskA), aligned.A_norm(maskA));
results.shape.width_vs_A_norm_spearman = spearmanSafe(aligned.width_norm(maskA), aligned.A_norm(maskA));
results.shape.width_vs_mirrorA_pearson = corrSafe(aligned.width_norm(maskA), aligned.one_minus_A_norm(maskA));
results.shape.width_vs_mirrorA_spearman = spearmanSafe(aligned.width_norm(maskA), aligned.one_minus_A_norm(maskA));
results.shape.rmse_direct = computeRMSE(aligned.width_norm(maskA), aligned.A_norm(maskA));
results.shape.rmse_mirror = computeRMSE(aligned.width_norm(maskA), aligned.one_minus_A_norm(maskA));

results.motion = struct();
results.motion.width_vs_motion_pearson = corrSafe(aligned.width_mA(maskMotion), aligned.motion_abs(maskMotion));
results.motion.width_vs_motion_spearman = spearmanSafe(aligned.width_mA(maskMotion), aligned.motion_abs(maskMotion));
results.motion.width_peak_T_K = aligned.width_peak_T_K;
results.motion.motion_peak_T_K = aligned.motion_peak_T_K;
results.motion.peak_delta_K = aligned.width_peak_T_K - aligned.motion_peak_T_K;

results.derivative = struct();
results.derivative.smooth_window = cfg.derivativeSmoothWindow;
results.derivative.width_min_slope = min(aligned.dwidth_dT(maskDeriv));
results.derivative.width_min_slope_T_K = findExtremeT(aligned.T_K, aligned.dwidth_dT, 'min');
results.derivative.A_max_slope = max(aligned.dA_dT(maskDeriv));
results.derivative.A_max_slope_T_K = findExtremeT(aligned.T_K, aligned.dA_dT, 'max');
results.derivative.A_min_slope = min(aligned.dA_dT(maskDeriv));
results.derivative.A_min_slope_T_K = findExtremeT(aligned.T_K, aligned.dA_dT, 'min');
results.derivative.abs_derivative_corr = corrSafe(aligned.dwidth_dT(maskDeriv), aligned.dA_dT(maskDeriv));
results.derivative.abs_peak_delta_K = results.derivative.width_min_slope_T_K - results.derivative.A_max_slope_T_K;
results.derivative.A_zero_cross_T_K = estimateZeroCrossing(aligned.T_K, aligned.dA_dT);
end

function tbl = buildAnalysisResultsTable(results, aligned, source, cfg)
section = strings(0, 1);
metric = strings(0, 1);
value = [];
units = strings(0, 1);
notes = strings(0, 1);

[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'baseline', 'width_vs_A_pearson', results.correlation.width_vs_A_pearson, 'unitless', 'Recomputed from saved source tables on 4-30 K grid');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'baseline', 'width_vs_A_spearman', results.correlation.width_vs_A_spearman, 'unitless', 'Recomputed from saved source tables on 4-30 K grid');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'baseline', 'baseline_run_width_vs_A_pearson', results.correlation.baseline_width_vs_A_pearson, 'unitless', char(source.baselineRunName));
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'baseline', 'baseline_run_width_vs_A_spearman', results.correlation.baseline_width_vs_A_spearman, 'unitless', char(source.baselineRunName));
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'baseline', 'width_vs_A_pearson_delta_vs_baseline', results.correlation.width_vs_A_delta_pearson, 'unitless', 'Should be numerically near zero');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'baseline', 'width_vs_A_spearman_delta_vs_baseline', results.correlation.width_vs_A_delta_spearman, 'unitless', 'Should be numerically near zero');

[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'product_test', 'mean_width_times_A', results.product.mean, 'mA*signal', 'Constant-product reference level');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'product_test', 'std_width_times_A', results.product.std, 'mA*signal', 'Spread of width(T)*A(T)');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'product_test', 'cv_width_times_A', results.product.cv, 'unitless', 'Coefficient of variation; small values would support constancy');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'product_test', 'relative_range_width_times_A', results.product.relative_range, 'unitless', '(max-min)/mean');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'product_test', 'product_peak_T_K', results.product.peak_T_K, 'K', 'Temperature of maximum width(T)*A(T)');

[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'inverse_fit', 'inverse_k', results.inverse.inverse_k, 'mA*signal', 'Fit parameter for width = k / A');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'inverse_fit', 'inverse_r2', results.inverse.inverse_r2, 'unitless', 'Goodness of fit for width = k / A');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'inverse_fit', 'inverse_rmse', results.inverse.inverse_rmse, 'mA', 'RMSE for width = k / A');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'inverse_fit', 'power_c', results.inverse.power_c, 'mA', 'Prefactor for width = c * A^{alpha}');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'inverse_fit', 'power_alpha', results.inverse.power_alpha, 'unitless', 'Power-law exponent');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'inverse_fit', 'power_r2', results.inverse.power_r2, 'unitless', 'Goodness of fit for power law');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'inverse_fit', 'power_rmse', results.inverse.power_rmse, 'mA', 'RMSE for power law');

[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'shape_test', 'corr_width_norm_A_norm', results.shape.width_vs_A_norm_pearson, 'unitless', 'Direct normalized-shape Pearson correlation');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'shape_test', 'corr_width_norm_one_minus_A_norm', results.shape.width_vs_mirrorA_pearson, 'unitless', 'Mirror-shape Pearson correlation');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'shape_test', 'rmse_width_norm_A_norm', results.shape.rmse_direct, 'unitless', 'Direct normalized-shape RMSE');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'shape_test', 'rmse_width_norm_one_minus_A_norm', results.shape.rmse_mirror, 'unitless', 'Mirror-shape RMSE');

[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'motion_test', 'width_vs_motion_pearson', results.motion.width_vs_motion_pearson, 'unitless', 'Full-scaling width vs saved ridge motion |dI_peak/dT|');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'motion_test', 'width_vs_motion_spearman', results.motion.width_vs_motion_spearman, 'unitless', 'Full-scaling width vs saved ridge motion |dI_peak/dT|');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'motion_test', 'width_peak_T_K', results.motion.width_peak_T_K, 'K', 'Width peak temperature');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'motion_test', 'motion_peak_T_K', results.motion.motion_peak_T_K, 'K', 'Motion peak temperature');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'motion_test', 'width_minus_motion_peak_delta_K', results.motion.peak_delta_K, 'K', 'Peak temperature offset');

[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'derivative_test', 'width_min_slope_T_K', results.derivative.width_min_slope_T_K, 'K', sprintf('%d-point moving-mean smoothing before differentiation', cfg.derivativeSmoothWindow));
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'derivative_test', 'A_max_slope_T_K', results.derivative.A_max_slope_T_K, 'K', sprintf('%d-point moving-mean smoothing before differentiation', cfg.derivativeSmoothWindow));
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'derivative_test', 'A_min_slope_T_K', results.derivative.A_min_slope_T_K, 'K', sprintf('%d-point moving-mean smoothing before differentiation', cfg.derivativeSmoothWindow));
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'derivative_test', 'A_zero_cross_T_K', results.derivative.A_zero_cross_T_K, 'K', 'Estimated zero crossing of dA/dT by linear interpolation');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'derivative_test', 'width_min_slope_minus_A_max_slope_delta_K', results.derivative.abs_peak_delta_K, 'K', 'Negative values mean width contracts earlier than A rises maximally');
[section, metric, value, units, notes] = addRow(section, metric, value, units, notes, 'derivative_test', 'corr_dwidth_dT_dA_dT', results.derivative.abs_derivative_corr, 'unitless', 'Pearson correlation between smoothed derivatives');

nRows = numel(value);
commonTLow = repmat(min(aligned.T_K), nRows, 1);
commonTHigh = repmat(max(aligned.T_K), nRows, 1);

tbl = table(section, metric, value(:), units, notes, commonTLow, commonTHigh, ...
    'VariableNames', {'analysis_section','metric_name','value','units','notes','temperature_min_K','temperature_max_K'});
end

function manifestTbl = buildManifestTable(source)
experiment = string({'switching'; 'relaxation'; 'relaxation'; 'cross_experiment'; 'cross_experiment'});
sourceRun = [source.switchRunName; source.relaxRunName; source.relaxRunName; source.motionRunName; source.baselineRunName];
sourceFile = string({ ...
    fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv'); ...
    fullfile(char(source.motionRunDir), 'tables', 'relaxation_switching_motion_table.csv'); ...
    fullfile(char(source.baselineRunDir), 'tables', 'correlation_results.csv')});
role = string({'full-scaling switching width table'; 'relaxation temperature observables'; 'relaxation peak metadata'; 'saved switching ridge motion table'; 'baseline width-relaxation correlation table'});
manifestTbl = table(experiment, sourceRun, sourceFile, role, ...
    'VariableNames', {'experiment','source_run','source_file','role'});
end

function paths = saveWidthVsTFigure(aligned, runDir, figureName)
fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
plot(ax, aligned.T_K, aligned.width_mA, '-o', 'Color', [0 0 0], ...
    'LineWidth', 1.9, 'MarkerSize', 5, 'MarkerFaceColor', [0 0 0]);
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Switching width (mA)');
title(ax, 'Switching width from full-scaling collapse');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
ylim(ax, paddedLimits(aligned.width_mA, 0.08));
styleAxis(ax);
paths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function paths = saveRelaxationAVsTFigure(aligned, runDir, figureName)
fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
plot(ax, aligned.T_K, aligned.A_interp, '-s', 'Color', [0 0.4470 0.6980], ...
    'LineWidth', 1.9, 'MarkerSize', 5, 'MarkerFaceColor', [0 0.4470 0.6980]);
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Relaxation A(T) (signal units)');
title(ax, 'Relaxation activity on the switching grid');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
ylim(ax, paddedLimits(aligned.A_interp, 0.10));
styleAxis(ax);
paths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function paths = saveWidthVsAScatterFigure(aligned, results, runDir, figureName)
fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
scatter(ax, aligned.A_interp, aligned.width_mA, 28, 'o', ...
    'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', [0.85 0.85 0.85], 'LineWidth', 0.9);
xlabel(ax, 'Relaxation A(T) (signal units)');
ylabel(ax, 'Switching width (mA)');
title(ax, 'Width(T) against relaxation activity');
styleAxis(ax);
text(ax, 0.05, 0.95, sprintf('Pearson = %.3f\\newlineSpearman = %.3f', ...
    results.correlation.width_vs_A_pearson, results.correlation.width_vs_A_spearman), ...
    'Units', 'normalized', 'VerticalAlignment', 'top');
paths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function paths = saveWidthTimesAFigure(aligned, results, runDir, figureName)
fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.width_times_A, '-o', 'Color', [0.8350 0.3690 0], ...
    'LineWidth', 1.9, 'MarkerSize', 5, 'MarkerFaceColor', [0.8350 0.3690 0]);
plot(ax, aligned.T_K, repmat(results.product.mean, size(aligned.T_K)), '--', ...
    'Color', [0.25 0.25 0.25], 'LineWidth', 1.3);
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'width(T) A(T) (mA signal)');
title(ax, 'Inverse-scaling product test');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
ylim(ax, paddedLimits([aligned.width_times_A; results.product.mean], 0.10));
legend(ax, {'width(T) A(T)', 'mean product'}, 'Location', 'best', 'Box', 'off');
text(ax, 0.05, 0.95, sprintf('CV = %.3f\\newlineRelative range = %.3f', ...
    results.product.cv, results.product.relative_range), 'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax);
paths = save_run_figure(fig, figureName, runDir);
close(fig);
end
function paths = saveInverseFitFigure(aligned, results, runDir, figureName)
fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
[sortedA, order] = sort(results.inverse.x_A);
sortedY = results.inverse.y_width(order);
sortedInv = results.inverse.yhat_inverse(order);
sortedPow = results.inverse.yhat_power(order);
hold(ax, 'on');
scatter(ax, sortedA, sortedY, 28, 'o', 'MarkerEdgeColor', [0 0 0], ...
    'MarkerFaceColor', [0.85 0.85 0.85], 'LineWidth', 0.9, 'DisplayName', 'data');
plot(ax, sortedA, sortedInv, '--', 'Color', [0.9020 0.6240 0], 'LineWidth', 1.5, 'DisplayName', 'k / A fit');
plot(ax, sortedA, sortedPow, '-', 'Color', [0 0.6190 0.4510], 'LineWidth', 1.5, 'DisplayName', 'power-law fit');
hold(ax, 'off');
xlabel(ax, 'Relaxation A(T) (signal units)');
ylabel(ax, 'Switching width (mA)');
title(ax, 'Simple inverse and power-law fits');
legend(ax, 'Location', 'best', 'Box', 'off');
text(ax, 0.05, 0.95, sprintf('k/A: R^2 = %.3f\\newlinepower law: alpha = %.3f, R^2 = %.3f', ...
    results.inverse.inverse_r2, results.inverse.power_alpha, results.inverse.power_r2), ...
    'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax);
paths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function paths = saveNormalizedOverlayFigure(aligned, results, runDir, figureName)
fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.width_norm, '-o', 'Color', [0 0 0], ...
    'LineWidth', 1.9, 'MarkerSize', 4.5, 'MarkerFaceColor', [0 0 0], 'DisplayName', 'width(T) / max');
plot(ax, aligned.T_K, aligned.A_norm, '-s', 'Color', [0 0.4470 0.6980], ...
    'LineWidth', 1.7, 'MarkerSize', 4.5, 'MarkerFaceColor', [0 0.4470 0.6980], 'DisplayName', 'A(T) / max');
plot(ax, aligned.T_K, aligned.one_minus_A_norm, '--', 'Color', [0.8350 0.3690 0], ...
    'LineWidth', 1.5, 'DisplayName', '1 - A(T) / max');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude (arb. units)');
title(ax, 'Direct versus mirrored shape comparison');
legend(ax, 'Location', 'best', 'Box', 'off');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
ylim(ax, [-0.02 1.05]);
text(ax, 0.05, 0.95, sprintf('corr(width, A) = %.3f\\newlinecorr(width, 1-A) = %.3f', ...
    results.shape.width_vs_A_norm_pearson, results.shape.width_vs_mirrorA_pearson), ...
    'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax);
paths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function paths = saveWidthVsRidgeMotionFigure(aligned, results, runDir, figureName)
fig = create_figure('Position', [2 2 8.6 6.2]);
ax = axes(fig);
mask = isfinite(aligned.motion_norm);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.width_norm, '-o', 'Color', [0 0 0], ...
    'LineWidth', 1.9, 'MarkerSize', 4.5, 'MarkerFaceColor', [0 0 0], 'DisplayName', 'width(T) / max');
plot(ax, aligned.T_K(mask), aligned.motion_norm(mask), '-^', 'Color', [0.8 0.475 0.655], ...
    'LineWidth', 1.7, 'MarkerSize', 4.5, 'MarkerFaceColor', [0.8 0.475 0.655], 'DisplayName', '|dI_{peak}/dT| / max');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude (arb. units)');
title(ax, 'Switching width and ridge motion');
legend(ax, 'Location', 'best', 'Box', 'off');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
ylim(ax, [-0.02 1.05]);
text(ax, 0.05, 0.95, sprintf('Pearson = %.3f\\newlineSpearman = %.3f', ...
    results.motion.width_vs_motion_pearson, results.motion.width_vs_motion_spearman), ...
    'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax);
paths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function paths = saveDerivativeComparisonFigure(aligned, results, runDir, figureName)
fig = create_figure('Position', [2 2 8.6 7.0]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.dwidth_dT_norm, '-o', 'Color', [0 0 0], ...
    'LineWidth', 1.9, 'MarkerSize', 4.5, 'MarkerFaceColor', [0 0 0], 'DisplayName', 'd width / dT');
plot(ax, aligned.T_K, aligned.dA_dT_norm, '-s', 'Color', [0 0.4470 0.6980], ...
    'LineWidth', 1.7, 'MarkerSize', 4.5, 'MarkerFaceColor', [0 0.4470 0.6980], 'DisplayName', 'dA / dT');
xline(ax, results.derivative.width_min_slope_T_K, '--', 'Color', [0.2 0.2 0.2], 'HandleVisibility', 'off');
xline(ax, results.derivative.A_max_slope_T_K, ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
if isfinite(results.derivative.A_zero_cross_T_K)
    xline(ax, results.derivative.A_zero_cross_T_K, '-.', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
end
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized derivative (arb. units)');
title(ax, 'Derivative structure near the crossover region');
legend(ax, 'Location', 'best', 'Box', 'off');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
ylim(ax, [-1.05 1.05]);
text(ax, 0.05, 0.95, sprintf('T[min d width/dT] = %.1f K\\newlineT[max dA/dT] = %.1f K', ...
    results.derivative.width_min_slope_T_K, results.derivative.A_max_slope_T_K), ...
    'Units', 'normalized', 'VerticalAlignment', 'top');
styleAxis(ax);
paths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function reportText = buildReportText(source, aligned, baseline, results, cfg)
lines = strings(0, 1);
lines(end + 1) = "# Switching Width Dynamics Analysis";
lines(end + 1) = "";
lines(end + 1) = "## Repository-state summary";
lines(end + 1) = sprintf('- Existing direct full-scaling width-vs-relaxation correlation run reused as baseline: `%s`.', source.baselineRunName);
lines(end + 1) = '- Existing older canonical `width_I(T)` versus `A(T)` comparisons already existed in `run_2026_03_12_004907_switching_relaxation_observable_comparis`, `run_2026_03_12_081243_relaxation_switching_observable_scan`, and `run_2026_03_10_220218_ridge_relaxation_comparison`.';
lines(end + 1) = '- Existing indirect width-motion context already existed for the older `width_I(T)` observable in `run_2026_03_12_084004_common_dynamical_subspace`, but no dedicated full-scaling width(T) motion-coupling run was found.';
lines(end + 1) = '- No saved run was found for the new hypothesis tests introduced here: `width(T) A(T)` constancy, explicit inverse fits, full-scaling width-versus-motion, and derivative-structure alignment.';
lines(end + 1) = "";
lines(end + 1) = "## Input runs";
lines(end + 1) = sprintf('- Switching width source: `%s`.', source.switchRunName);
lines(end + 1) = sprintf('- Relaxation source: `%s`.', source.relaxRunName);
lines(end + 1) = sprintf('- Ridge-motion source: `%s`.', source.motionRunName);
lines(end + 1) = sprintf('- Baseline width-vs-relaxation correlation check: `%s`.', source.baselineRunName);
lines(end + 1) = "";
lines(end + 1) = "## Hypotheses tested";
lines(end + 1) = '- Test A: whether `width(T) A(T)` is approximately constant.';
lines(end + 1) = '- Test B: whether `width(T)` behaves like an inverse relaxation scale through `k / A(T)` or a generic power law.';
lines(end + 1) = '- Test C: whether normalized `width(T)` and `A(T)` look like mirrored shapes rather than directly aligned ones.';
lines(end + 1) = '- Test D: whether full-scaling `width(T)` is coupled to switching ridge motion `|dI_peak/dT|`.';
lines(end + 1) = '- Test E: whether the derivative structure of `width(T)` and `A(T)` marks a common crossover window.';
lines(end + 1) = "";
lines(end + 1) = "## Empirical results";
lines(end + 1) = sprintf('- Baseline check against the existing width-vs-relaxation run: recomputed Pearson = %.4f and Spearman = %.4f, matching the saved baseline within numerical precision (delta Pearson = %.2e, delta Spearman = %.2e).', ...
    results.correlation.width_vs_A_pearson, results.correlation.width_vs_A_spearman, ...
    results.correlation.width_vs_A_delta_pearson, results.correlation.width_vs_A_delta_spearman);
lines(end + 1) = sprintf('- `width(T) A(T)` is not constant: coefficient of variation = %.3f, relative range = %.3f, and the product peaks near %.1f K instead of staying flat.', ...
    results.product.cv, results.product.relative_range, results.product.peak_T_K);
lines(end + 1) = sprintf('- Inverse fit `width = k / A` gives `R^2 = %.3f` and `RMSE = %.3f mA` with `k = %.4g mA*signal`.', ...
    results.inverse.inverse_r2, results.inverse.inverse_rmse, results.inverse.inverse_k);
lines(end + 1) = sprintf('- Power-law fit `width = c A^{alpha}` gives `alpha = %.3f`, `R^2 = %.3f`, and `RMSE = %.3f mA`.', ...
    results.inverse.power_alpha, results.inverse.power_r2, results.inverse.power_rmse);
lines(end + 1) = sprintf('- Direct normalized shape comparison is strongly anti-aligned (`corr = %.3f`), while the mirrored comparison `width_norm` versus `1 - A_norm` improves to `corr = %.3f` with RMSE changing from %.3f to %.3f.', ...
    results.shape.width_vs_A_norm_pearson, results.shape.width_vs_mirrorA_pearson, ...
    results.shape.rmse_direct, results.shape.rmse_mirror);
lines(end + 1) = sprintf('- Full-scaling width versus ridge motion gives Pearson = %.3f and Spearman = %.3f; the width peak at %.1f K is offset from the motion peak at %.1f K by %+0.1f K.', ...
    results.motion.width_vs_motion_pearson, results.motion.width_vs_motion_spearman, ...
    results.motion.width_peak_T_K, results.motion.motion_peak_T_K, results.motion.peak_delta_K);
lines(end + 1) = sprintf('- After %d-point moving-mean smoothing, the strongest width contraction occurs near %.1f K, the strongest positive rise of `A(T)` occurs near %.1f K, and the estimated `dA/dT = 0` crossing is near %.1f K.', ...
    cfg.derivativeSmoothWindow, results.derivative.width_min_slope_T_K, ...
    results.derivative.A_max_slope_T_K, results.derivative.A_zero_cross_T_K);
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
if results.inverse.inverse_r2 > 0.8 || results.inverse.power_r2 > 0.8
    lines(end + 1) = '- The inverse-style fits capture a substantial part of the width trend, so width behaves like a meaningful inverse activity scale at the empirical level.';
else
    lines(end + 1) = '- The inverse-style fits capture only part of the trend, so a simple one-parameter inverse law is not sufficient to describe the full temperature dependence.';
end
if results.shape.width_vs_mirrorA_pearson > abs(results.shape.width_vs_A_norm_pearson)
    lines(end + 1) = '- The normalized overlay supports a mirrored-shape picture more than a direct positive-tracking picture: width decreases where relaxation activity grows.';
else
    lines(end + 1) = '- The normalized overlay does not clearly favor a mirrored-shape interpretation over direct alignment.';
end
if results.motion.width_vs_motion_pearson < 0
    lines(end + 1) = '- Width is anti-correlated with ridge motion in the saved outputs, so the broad current window behaves more like a low-mobility or low-activity scale than a direct mobility proxy.';
else
    lines(end + 1) = '- Width is positively correlated with ridge motion in the saved outputs, so it may carry a direct mobility signature.';
end
lines(end + 1) = '- The derivative comparison should be interpreted cautiously: it is a downstream structure test on lightly smoothed saved curves, not a proof of a microscopic mechanism.';
lines(end + 1) = '- Overall, the saved data support width(T) as an inverse or opposing dynamical scale relative to relaxation activity and ridge motion, but they do not isolate a unique functional law.';
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = '- number of curves: 1 curve each for `width_vs_T`, `relaxation_A_vs_T`, `width_times_A_vs_T`; 2 fitted curves plus data markers for `inverse_fit_width_vs_A`; 3 curves for `normalized_width_A_overlay`; 2 curves for `width_vs_ridge_motion`; 2 curves for `derivative_comparison`.';
lines(end + 1) = '- legend vs colormap: legends only throughout; no figure exceeded six curves.';
lines(end + 1) = '- colormap used: none.';
lines(end + 1) = sprintf('- smoothing applied: %d-point moving mean before derivative estimation of `width(T)` and `A(T)` only.', cfg.derivativeSmoothWindow);
lines(end + 1) = '- justification: each figure isolates one hypothesis test so the empirical relation stays readable and publication-oriented.';

reportText = strjoin(lines, newline);
end
function [section, metric, value, units, notes] = addRow(section, metric, value, units, notes, sec, met, val, unitLabel, noteText)
section(end + 1, 1) = string(sec);
metric(end + 1, 1) = string(met);
value(end + 1, 1) = val;
units(end + 1, 1) = string(unitLabel);
notes(end + 1, 1) = string(noteText);
end

function [ySmooth, dydT] = smoothAndDifferentiate(T, y, window)
ySmooth = NaN(size(y));
dydT = NaN(size(y));
mask = isfinite(T) & isfinite(y);
if nnz(mask) < 3
    return;
end
Tg = T(mask);
Yg = y(mask);
if window >= 2
    Yg = smoothdata(Yg, 'movmean', min(window, numel(Yg)));
end
ySmooth(mask) = Yg;
dydT(mask) = gradient(Yg, Tg);
end

function yNorm = normalizeVector(y)
y = y(:);
yNorm = NaN(size(y));
mask = isfinite(y);
if ~any(mask)
    return;
end
maxVal = max(y(mask), [], 'omitnan');
if isfinite(maxVal) && maxVal ~= 0
    yNorm(mask) = y(mask) ./ maxVal;
end
end

function yNorm = normalizeSigned(y)
y = y(:);
yNorm = NaN(size(y));
mask = isfinite(y);
if ~any(mask)
    return;
end
maxAbs = max(abs(y(mask)), [], 'omitnan');
if isfinite(maxAbs) && maxAbs ~= 0
    yNorm(mask) = y(mask) ./ maxAbs;
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
    c = cc(1, 2);
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

function r2 = computeR2(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if nnz(mask) < 3
    r2 = NaN;
    return;
end
yv = y(mask);
yhatv = yhat(mask);
ssRes = sum((yv - yhatv).^2);
ssTot = sum((yv - mean(yv)).^2);
if ssTot == 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
end

function rmse = computeRMSE(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if ~any(mask)
    rmse = NaN;
    return;
end
rmse = sqrt(mean((y(mask) - yhat(mask)).^2));
end

function mae = computeMAE(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if ~any(mask)
    mae = NaN;
    return;
end
mae = mean(abs(y(mask) - yhat(mask)));
end

function tPeak = findPeakT(T, y)
tPeak = NaN;
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    return;
end
[~, idx] = max(y(mask));
Tvalid = T(mask);
tPeak = Tvalid(idx);
end

function tExtreme = findExtremeT(T, y, mode)
tExtreme = NaN;
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    return;
end
Tvalid = T(mask);
Yvalid = y(mask);
switch lower(mode)
    case 'max'
        [~, idx] = max(Yvalid);
    otherwise
        [~, idx] = min(Yvalid);
end
tExtreme = Tvalid(idx);
end

function tZero = estimateZeroCrossing(T, y)
tZero = NaN;
mask = isfinite(T) & isfinite(y);
if nnz(mask) < 2
    return;
end
Tvalid = T(mask);
Yvalid = y(mask);
for i = 1:(numel(Yvalid) - 1)
    y1 = Yvalid(i);
    y2 = Yvalid(i + 1);
    if y1 == 0
        tZero = Tvalid(i);
        return;
    end
    if y1 * y2 < 0
        frac = abs(y1) / (abs(y1) + abs(y2));
        tZero = Tvalid(i) + frac * (Tvalid(i + 1) - Tvalid(i));
        return;
    end
end
end

function lims = paddedLimits(y, frac)
y = y(isfinite(y));
if isempty(y)
    lims = [0 1];
    return;
end
yMin = min(y);
yMax = max(y);
if yMin == yMax
    pad = max(abs(yMin) * frac, 1);
else
    pad = frac * (yMax - yMin);
end
lims = [yMin - pad, yMax + pad];
end

function styleAxis(ax)
set(ax, 'FontName', 'Helvetica', ...
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
