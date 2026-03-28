fprintf('[RUN] run_phi1_observable_phi2_driver_test\n');
clearvars;
repoRoot = 'C:/Dev/matlab-functions';
analysisDir = fullfile(repoRoot, 'Switching', 'analysis');
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
errorLogPath = fullfile(repoRoot, 'matlab_error.log');
byTPath = fullfile(tablesDir, 'phi1_phi2_driver_by_temperature.csv');
metricsPath = fullfile(tablesDir, 'phi1_phi2_driver_metrics.csv');
verdictPath = fullfile(tablesDir, 'phi1_phi2_driver_verdicts.csv');
reportPath = fullfile(reportsDir, 'run_phi1_observable_phi2_driver_test.md');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
core = table(NaN, NaN, NaN, NaN, 'VariableNames', {'T_K','observable_error','kappa2','alpha'});
metrics = table(NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, 'VariableNames', {'n_temperatures','corr_error_kappa2','corr_error_alpha','kappa2_abs_median_split','n_high_kappa2','n_low_kappa2','mean_error_high_kappa2','mean_error_low_kappa2','error_ratio_high_over_low','error_delta_high_minus_low','rank_sum_pvalue'});
verdictTbl = table("NO", "NO", 'VariableNames', {'OBSERVABLE_FAILURE_DRIVEN_BY_PHI2','PHI2_LIMITS_SCALAR_OBSERVABLE'});
try
addpath(genpath(fullfile(repoRoot, 'Aging'))); addpath(fullfile(repoRoot, 'tools')); addpath(fullfile(repoRoot, 'tools', 'figures')); addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin'); addpath(analysisDir, '-begin');
cfg = phi1_phi2_driver_helpers('apply_defaults', struct());
tblFailure = readtable(fullfile(repoRoot, 'tables', 'phi1_observable_failure_by_T.csv'), 'VariableNamingRule', 'preserve');
tblClosure = readtable(fullfile(repoRoot, 'tables', 'closure_metrics_per_temperature.csv'), 'VariableNamingRule', 'preserve');
tblAlpha = readtable(fullfile(repoRoot, 'tables', cfg.alphaTableName), 'VariableNamingRule', 'preserve');
Tfail = phi1_phi2_driver_helpers('numeric_column', tblFailure, ["T_K", "T"]);
residual = phi1_phi2_driver_helpers('numeric_column', tblFailure, [cfg.errorColumnName, "reconstruction_rmse_M2", "rmse_M2"]);
Tclose = phi1_phi2_driver_helpers('numeric_column', tblClosure, ["T_K", "T"]);
kappa2 = phi1_phi2_driver_helpers('numeric_column', tblClosure, ["kappa2_M3", "kappa2"]);
Talpha = phi1_phi2_driver_helpers('numeric_column', tblAlpha, ["T_K", "T"]);
alpha = phi1_phi2_driver_helpers('numeric_column', tblAlpha, ["alpha"]);
if all(~isfinite(residual)) || all(~isfinite(kappa2)) || all(~isfinite(alpha)), error('run_phi1_observable_phi2_driver_test:MissingColumns','Required columns missing.'); end
merged = table(Tfail(:), residual(:), 'VariableNames', {'T_K', 'observable_error'});
merged = phi1_phi2_driver_helpers('outer_join', merged, table(Tclose(:), kappa2(:), 'VariableNames', {'T_K', 'kappa2'}), 'T_K');
merged = phi1_phi2_driver_helpers('outer_join', merged, table(Talpha(:), alpha(:), 'VariableNames', {'T_K', 'alpha'}), 'T_K');
merged = sortrows(merged, 'T_K');
core = merged(isfinite(merged.observable_error) & isfinite(merged.kappa2) & isfinite(merged.alpha), :);
if height(core) < 6, error('run_phi1_observable_phi2_driver_test:InsufficientRows','Need at least 6 aligned temperatures.'); end
rErrK2 = corr(core.observable_error, core.kappa2, 'rows', 'pairwise');
rErrA = corr(core.observable_error, core.alpha, 'rows', 'pairwise');
absK2 = abs(core.kappa2); k2Cut = median(absK2, 'omitnan'); isHigh = absK2 >= k2Cut; isLow = absK2 < k2Cut;
errHigh = mean(core.observable_error(isHigh), 'omitnan'); errLow = mean(core.observable_error(isLow), 'omitnan'); errRatio = errHigh / max(errLow, eps); deltaErr = errHigh - errLow;
if nnz(isHigh) >= 3 && nnz(isLow) >= 3, pRank = ranksum(core.observable_error(isHigh), core.observable_error(isLow)); else, pRank = NaN; end
metrics = table(height(core), rErrK2, rErrA, k2Cut, nnz(isHigh), nnz(isLow), errHigh, errLow, errRatio, deltaErr, pRank, 'VariableNames', metrics.Properties.VariableNames);
drivenByPhi2 = (isfinite(rErrK2) && abs(rErrK2) >= cfg.corrPhi2Threshold) && (isfinite(errRatio) && errRatio >= cfg.errorRatioThreshold);
phi2LimitsScalar = (isfinite(rErrK2) && abs(rErrK2) > max(abs(rErrA), cfg.minCorrFloor)) && (isfinite(errRatio) && errRatio >= cfg.errorRatioThreshold);
verdictTbl = table(string(phi1_phi2_driver_helpers('yes_no', drivenByPhi2)), string(phi1_phi2_driver_helpers('yes_no', phi2LimitsScalar)), 'VariableNames', {'OBSERVABLE_FAILURE_DRIVEN_BY_PHI2', 'PHI2_LIMITS_SCALAR_OBSERVABLE'});
writetable(core, byTPath); writetable(metrics, metricsPath); writetable(verdictTbl, verdictPath); fid=fopen(reportPath,'w'); fprintf(fid,'SUCCESS\n'); fclose(fid);
catch ME
fid=fopen(errorLogPath,'a'); if fid ~= -1, fprintf(fid,'%s\n',getReport(ME)); fclose(fid); end
try, writetable(core, byTPath); writetable(metrics, metricsPath); writetable(verdictTbl, verdictPath); catch, end
fid=fopen(reportPath,'w'); if fid ~= -1, fprintf(fid,'FAIL\n'); fclose(fid); end
end
