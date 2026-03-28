% RUN_AGING_KAPPA_COMPARISON Compare predictive power: kappa1 vs (kappa1 + kappa2)
%
% Goal:
%   Directly compare predictive power of kappa1 alone vs (kappa1 + kappa2)
%   for aging R(T), using temperature-aligned LOOCV.
%
% Models:
%   1) R ~ kappa1
%   2) R ~ kappa2
%   3) R ~ kappa1 + kappa2
%
% Metrics:
%   - LOOCV RMSE
%   - Pearson (y, yhat)
%   - Spearman (y, yhat)
%
% Critical comparison:
%   - RMSE improvement of (kappa1 + kappa2) vs kappa1 alone
%   - residual reduction in 22-24K (mean absolute residual)
%
% Outputs (repo root):
%   tables/aging_kappa_comparison.csv
%   reports/aging_kappa_comparison.md
%   tables/aging_kappa_comparison_status.csv

% NOTE: This script is executed by `tools/run_matlab_safe.bat` via `eval(fileread(...))`
% after `cd` into repo root. Using `pwd` makes the path logic robust under that execution mode.
repoRoot = pwd;
thisFile = fullfile(repoRoot, 'Switching', 'analysis', 'run_aging_kappa_comparison.m');

clockRatioPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_14_074613_aging_clock_ratio_analysis', 'tables', 'table_clock_ratio.csv');
alphaStructurePath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');

assert(isfile(clockRatioPath), 'Missing clock ratio table: %s', clockRatioPath);
assert(isfile(alphaStructurePath), 'Missing alpha structure table: %s', alphaStructurePath);

clk = readtable(clockRatioPath, 'VariableNamingRule', 'preserve');
alpha = readtable(alphaStructurePath, 'VariableNamingRule', 'preserve');

% Clock table -> R(T) on temperature grid
assert(ismember('Tp', clk.Properties.VariableNames), 'clock_ratio: need Tp column.');
assert(ismember('R_tau_FM_over_tau_dip', clk.Properties.VariableNames), ...
    'clock_ratio: need R_tau_FM_over_tau_dip column.');
clk.T_K = double(clk.Tp(:));
clk.R = double(clk.R_tau_FM_over_tau_dip(:));

% Alpha structure table -> kappa1/kappa2
assert(all(ismember({'T_K', 'kappa1', 'kappa2'}, alpha.Properties.VariableNames)), ...
    'alpha_structure: need columns T_K, kappa1, kappa2.');

merged = innerjoin(clk(:, {'T_K', 'R'}), alpha(:, {'T_K', 'kappa1', 'kappa2'}), ...
    'Keys', 'T_K');

merged.kappa1 = double(merged.kappa1(:));
merged.kappa2 = double(merged.kappa2(:));
merged.R = double(merged.R(:));
merged.T_K = double(merged.T_K(:));

mFinite = isfinite(merged.R) & isfinite(merged.kappa1) & isfinite(merged.kappa2);
master = merged(mFinite, :);
master = sortrows(master, 'T_K');

T_K = double(master.T_K(:));
y = double(master.R(:));
k1 = double(master.kappa1(:));
k2 = double(master.kappa2(:));

n = numel(y);
assert(n >= 4, 'Aging kappa comparison: need at least n=4 overlap rows (got n=%d).', n);

Twin = (T_K >= 22) & (T_K <= 24);
maskOther = ~Twin;

% ----------------------------
% Model 1: R ~ kappa1
% ----------------------------
X = k1(:);
p = size(X, 2);
Z = [ones(n, 1), X];
yhat_k1 = nan(n, 1);
rmse_k1 = NaN; pear_k1 = NaN; spear_k1 = NaN;
if ~(n <= p + 1 || any(~isfinite(Z), 'all') || any(~isfinite(y)) || rank(Z) < size(Z, 2))
    beta = Z \ y;
    yfit = Z * beta;
    e = y - yfit;
    H = Z * ((Z' * Z) \ Z');
    h = diag(H);
    loo = e ./ max(1 - h, 1e-12);
    yhat_k1 = y - loo;
    rmse_k1 = sqrt(mean(loo.^2, 'omitnan'));
    pear_k1 = corr(y, yhat_k1, 'rows', 'complete');
    spear_k1 = corr(y, yhat_k1, 'type', 'Spearman', 'rows', 'complete');
end
res_k1 = y - yhat_k1;
mae_k1_win = mean(abs(res_k1(Twin)), 'omitnan');
mae_k1_other = mean(abs(res_k1(maskOther)), 'omitnan');

% ----------------------------
% Model 2: R ~ kappa2
% ----------------------------
X = k2(:);
p = size(X, 2);
Z = [ones(n, 1), X];
yhat_k2 = nan(n, 1);
rmse_k2 = NaN; pear_k2 = NaN; spear_k2 = NaN;
if ~(n <= p + 1 || any(~isfinite(Z), 'all') || any(~isfinite(y)) || rank(Z) < size(Z, 2))
    beta = Z \ y;
    yfit = Z * beta;
    e = y - yfit;
    H = Z * ((Z' * Z) \ Z');
    h = diag(H);
    loo = e ./ max(1 - h, 1e-12);
    yhat_k2 = y - loo;
    rmse_k2 = sqrt(mean(loo.^2, 'omitnan'));
    pear_k2 = corr(y, yhat_k2, 'rows', 'complete');
    spear_k2 = corr(y, yhat_k2, 'type', 'Spearman', 'rows', 'complete');
end
res_k2 = y - yhat_k2;
mae_k2_win = mean(abs(res_k2(Twin)), 'omitnan');
mae_k2_other = mean(abs(res_k2(maskOther)), 'omitnan');

% ----------------------------
% Model 3: R ~ kappa1 + kappa2
% ----------------------------
X = [k1(:), k2(:)];
p = size(X, 2);
Z = [ones(n, 1), X];
yhat_k12 = nan(n, 1);
rmse_k12 = NaN; pear_k12 = NaN; spear_k12 = NaN;
if ~(n <= p + 1 || any(~isfinite(Z), 'all') || any(~isfinite(y)) || rank(Z) < size(Z, 2))
    beta = Z \ y;
    yfit = Z * beta;
    e = y - yfit;
    H = Z * ((Z' * Z) \ Z');
    h = diag(H);
    loo = e ./ max(1 - h, 1e-12);
    yhat_k12 = y - loo;
    rmse_k12 = sqrt(mean(loo.^2, 'omitnan'));
    pear_k12 = corr(y, yhat_k12, 'rows', 'complete');
    spear_k12 = corr(y, yhat_k12, 'type', 'Spearman', 'rows', 'complete');
end
res_k12 = y - yhat_k12;
mae_k12_win = mean(abs(res_k12(Twin)), 'omitnan');
mae_k12_other = mean(abs(res_k12(maskOther)), 'omitnan');

% Baseline: R ~ constant (LOOCV mean)
yhat_const = nan(n, 1);
for i = 1:n
    yhat_const(i) = mean(y(setdiff(1:n, i)), 'omitnan');
end
rmse_const = sqrt(mean((y - yhat_const).^2, 'omitnan'));

% ----------------------------
% Verdicts
% ----------------------------
tol = 1e-12;

KAPPA2_ADDS_INFORMATION = "NO";
if isfinite(rmse_k1) && isfinite(rmse_k12) && rmse_k12 < rmse_k1 - tol
    KAPPA2_ADDS_INFORMATION = "YES";
end

kappa1BeatsBaseline = isfinite(rmse_k1) && isfinite(rmse_const) && rmse_k1 < rmse_const - tol;
KAPPA1_SUFFICIENT = "NO";
if KAPPA2_ADDS_INFORMATION == "NO" && kappa1BeatsBaseline
    KAPPA1_SUFFICIENT = "YES";
end

% ----------------------------
% Output tables
% ----------------------------
rows = table();
rows.model = string(["R ~ 1 (baseline)"; "R ~ kappa1"; "R ~ kappa2"; "R ~ kappa1 + kappa2"]);
rows.n_rows_used = repmat(n, 4, 1);
rows.loocv_rmse = [rmse_const; rmse_k1; rmse_k2; rmse_k12];
rows.pearson_y_yhat = [NaN; pear_k1; pear_k2; pear_k12];
rows.spearman_y_yhat = [NaN; spear_k1; spear_k2; spear_k12];

% Mean absolute residual in windows (baseline uses yhat_const)
res_const = y - yhat_const;
mae_const_win = mean(abs(res_const(Twin)), 'omitnan');
mae_const_other = mean(abs(res_const(maskOther)), 'omitnan');
rows.mae_resid_22_24K = [mae_const_win; mae_k1_win; mae_k2_win; mae_k12_win];
rows.mae_resid_outside_22_24K = [mae_const_other; mae_k1_other; mae_k2_other; mae_k12_other];

% Critical comparison additions
rmse_improvement_abs = rmse_k1 - rmse_k12;
rmse_improvement_pct = 100 * (rmse_k1 - rmse_k12) / max(rmse_k1, eps);
resid_reduction_abs = mae_k1_win - mae_k12_win;
resid_reduction_pct = 100 * (mae_k1_win - mae_k12_win) / max(mae_k1_win, eps);

rows.delta_rmse_vs_kappa1 = rows.loocv_rmse - rmse_k1;

tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

compCsvPath = fullfile(tablesDir, 'aging_kappa_comparison.csv');
statusCsvPath = fullfile(tablesDir, 'aging_kappa_comparison_status.csv');
reportMdPath = fullfile(reportsDir, 'aging_kappa_comparison.md');

writetable(rows, compCsvPath);

statusTbl = table( ...
    string(KAPPA2_ADDS_INFORMATION), string(KAPPA1_SUFFICIENT), n, ...
    rmse_const, rmse_k1, rmse_k2, rmse_k12, ...
    pear_k1, pear_k2, pear_k12, ...
    spear_k1, spear_k2, spear_k12, ...
    rmse_improvement_abs, rmse_improvement_pct, ...
    resid_reduction_abs, resid_reduction_pct, ...
    'VariableNames', { ...
    'KAPPA2_ADDS_INFORMATION', 'KAPPA1_SUFFICIENT', 'n_rows_used', ...
    'rmse_R_constant', 'rmse_R_kappa1', 'rmse_R_kappa2', 'rmse_R_kappa1kappa2', ...
    'pearson_kappa1', 'pearson_kappa2', 'pearson_kappa1kappa2', ...
    'spearman_kappa1', 'spearman_kappa2', 'spearman_kappa1kappa2', ...
    'rmse_improvement_abs_kappa1_to_kappa1kappa2', 'rmse_improvement_pct_kappa1_to_kappa1kappa2', ...
    'mae_resid_reduction_abs_22_24K_kappa1_to_kappa1kappa2', 'mae_resid_reduction_pct_22_24K_kappa1_to_kappa1kappa2'} );

writetable(statusTbl, statusCsvPath);

% ----------------------------
% Markdown report
% ----------------------------
lines = {};
lines{end + 1} = '# Aging R(T) kappa comparison (LOOCV)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(reportMdPath, '\', '/'));
lines{end + 1} = sprintf('**Date:** %s', datestr(now, 31));
lines{end + 1} = '';

lines{end + 1} = '## Inputs (read-only)';
lines{end + 1} = sprintf('- **R(T):** `%s` (Tp -> T_K, R_tau_FM_over_tau_dip -> R)', ...
    strrep(clockRatioPath, '\', '/'));
lines{end + 1} = sprintf('- **kappa state:** `%s` (columns `kappa1`, `kappa2` on `T_K`)', ...
    strrep(alphaStructurePath, '\', '/'));
lines{end + 1} = '';

lines{end + 1} = '## Data alignment';
lines{end + 1} = sprintf('- Overlap rows used: n = %d', n);
lines{end + 1} = sprintf('- Temperatures (K): `%s`', mat2str(T_K(:)', 4));
lines{end + 1} = '';

lines{end + 1} = '## Models';
lines{end + 1} = '| model | LOOCV RMSE | Pearson | Spearman | mean|resid| 22-24K | mean|resid| outside 22-24K |';
lines{end + 1} = '|---|---:|---:|---:|---:|---:|';
for i = 1:height(rows)
    modelStr = char(rows.model(i));
    lines{end + 1} = sprintf('| %s | %.6g | %.6g | %.6g | %.6g | %.6g |', modelStr, ...
        rows.loocv_rmse(i), rows.pearson_y_yhat(i), rows.spearman_y_yhat(i), ...
        rows.mae_resid_22_24K(i), rows.mae_resid_outside_22_24K(i));
end
lines{end + 1} = '';

lines{end + 1} = '## Critical comparison';
lines{end + 1} = sprintf('- Constant baseline LOOCV RMSE: %.6g', rmse_const);
lines{end + 1} = sprintf('- kappa1 LOOCV RMSE: %.6g', rmse_k1);
lines{end + 1} = sprintf('- kappa2 LOOCV RMSE: %.6g', rmse_k2);
lines{end + 1} = sprintf('- kappa1+kappa2 LOOCV RMSE: %.6g', rmse_k12);
lines{end + 1} = sprintf('- RMSE improvement (kappa1+kappa2 vs kappa1): %.6g (%.3f%% reduction)', ...
    rmse_improvement_abs, rmse_improvement_pct);
lines{end + 1} = sprintf('- mean|LOOCV residual| in 22-24K: kappa1=%.6g, kappa1+kappa2=%.6g', mae_k1_win, mae_k12_win);
lines{end + 1} = sprintf('- residual reduction in 22-24K (abs + pct): %.6g (%.3f%%)', ...
    resid_reduction_abs, resid_reduction_pct);
lines{end + 1} = '';

lines{end + 1} = '## Verdicts';
lines{end + 1} = sprintf('- **KAPPA2_ADDS_INFORMATION:** **%s**', char(KAPPA2_ADDS_INFORMATION));
lines{end + 1} = sprintf('- **KAPPA1_SUFFICIENT:** **%s**', char(KAPPA1_SUFFICIENT));
lines{end + 1} = '';

lines{end + 1} = '## Interpretation (rule)';
lines{end + 1} = sprintf(['If kappa2 does not improve LOOCV (kappa1+kappa2 RMSE >= kappa1 RMSE within tolerance), ' ...
    'then kappa2 is treated as adding NO information even if correlation increases.']);
lines{end + 1} = '';
lines{end + 1} = sprintf('*Auto-generated by `%s`.*', strrep(thisFile, '\', '/'));

fid = fopen(reportMdPath, 'w');
if fid < 0
    error('Cannot write report: %s', reportMdPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', lines{:});

% End of script (no local functions).

