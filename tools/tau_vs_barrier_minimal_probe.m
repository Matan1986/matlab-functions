function tau_vs_barrier_minimal_probe()
% Minimal diagnostic: link aging characteristic time to switching barrier landscape.
% Outputs:
%   tables/tau_vs_barrier_test.csv
%   reports/tau_vs_barrier_report.md
%
% Constraints:
% - Uses existing runs only (reads CSVs).
% - Linear models only; no feature engineering beyond log-time transform.
%
% Characteristic tau choice:
% - tau_mean := tau_effective_seconds from aging/tau_vs_Tp.csv
%   (finite-values filtering is applied per spec).

repo_root = fileparts(fileparts(mfilename('fullpath'))); % tools/.. => repo root

% Sentinel to confirm the script starts executing.
sentinel_path = fullfile(repo_root, 'tables', 'tau_vs_barrier_probe_sentinel.txt');
try
    fid = fopen(sentinel_path, 'w');
    if fid >= 0
        fprintf(fid, 'started');
        fclose(fid);
    end
catch
    % Ignore sentinel failures; analysis outputs are the real target.
end

aging_csv = fullfile(repo_root, 'results', 'aging', 'runs', 'run_2026_03_12_223709_aging_timescale_extraction', ...
    'tables', 'tau_vs_Tp.csv');
pt_csv = fullfile(repo_root, 'results', 'switching', 'runs', 'run_2026_03_25_013356_pt_robust_canonical', ...
    'tables', 'PT_summary.csv');

out_csv = fullfile(repo_root, 'tables', 'tau_vs_barrier_test.csv');
out_md = fullfile(repo_root, 'reports', 'tau_vs_barrier_report.md');

% Load
aging = readtable(aging_csv);
pt = readtable(pt_csv);

% Define tau_mean
if ~ismember('tau_effective_seconds', aging.Properties.VariableNames)
    error('Expected column tau_effective_seconds in aging csv.');
end
if ~ismember('Tp', aging.Properties.VariableNames)
    error('Expected column Tp in aging csv.');
end

if ~ismember('mean_threshold_mA', pt.Properties.VariableNames) || ~ismember('std_threshold_mA', pt.Properties.VariableNames)
    error('Expected columns mean_threshold_mA/std_threshold_mA in PT_summary csv.');
end
if ~ismember('T_K', pt.Properties.VariableNames)
    error('Expected column T_K in PT_summary csv.');
end

agingT = aging.Tp;
tau = aging.tau_effective_seconds;

log_tau = log(tau);

ptT = pt.T_K;
mean_E_all = pt.mean_threshold_mA;
std_E_all = pt.std_threshold_mA;

% Inner join on temperature with finite values only
[tf, loc] = ismember(agingT, ptT);
idxA = tf;
idxB = loc(tf);

T = agingT(idxA);
y = log_tau(idxA);
mean_E = mean_E_all(idxB);
std_E = std_E_all(idxB);

finite_mask = isfinite(y) & isfinite(mean_E) & isfinite(std_E);
T = T(finite_mask);
y = y(finite_mask);
mean_E = mean_E(finite_mask);
std_E = std_E(finite_mask);

n = numel(y);
if n < 3
    error('Not enough joined points after finite filtering. n=%d', n);
end

rmse = @(a,b) sqrt(mean((a-b).^2));

pearson_r = @(a,b) corr(a,b,'Type','Pearson');
spearman_r = @(a,b) corr(a,b,'Type','Spearman');

% LOOCV baseline: constant predictor = mean(log_tau) of training fold
baseline_pred = zeros(n,1);
for i = 1:n
    mask = true(n,1);
    mask(i) = false;
    baseline_pred(i) = mean(y(mask));
end
baseline_rmse = rmse(y, baseline_pred);
baseline_pear = pearson_r(y, baseline_pred);
baseline_spear = spearman_r(y, baseline_pred);

% LOOCV for linear model y ~ intercept + X (linear least squares)
fit_predict_loocv = @(X) loocv_linear_predict(X, y);

% Model (A1): log_tau ~ mean_E
X1 = mean_E(:);
pred1 = fit_predict_loocv(X1);
res1 = struct('model','log_tau ~ mean_E','predictors','mean_E', ...
    'n_T',n,'LOOCV_RMSE',rmse(y,pred1), ...
    'Pearson_r',pearson_r(y,pred1),'Spearman_r',spearman_r(y,pred1));

% Model (A2): log_tau ~ std_E
X2 = std_E(:);
pred2 = fit_predict_loocv(X2);
res2 = struct('model','log_tau ~ std_E','predictors','std_E', ...
    'n_T',n,'LOOCV_RMSE',rmse(y,pred2), ...
    'Pearson_r',pearson_r(y,pred2),'Spearman_r',spearman_r(y,pred2));

% Model (B): log_tau ~ mean_E + std_E
X3 = [mean_E(:), std_E(:)];
pred3 = fit_predict_loocv(X3);
res3 = struct('model','log_tau ~ mean_E + std_E','predictors','mean_E,std_E', ...
    'n_T',n,'LOOCV_RMSE',rmse(y,pred3), ...
    'Pearson_r',pearson_r(y,pred3),'Spearman_r',spearman_r(y,pred3));

models = [res1,res2,res3];
[~, best_idx] = min([models.LOOCV_RMSE]);
best = models(best_idx);
best_abs_pear = abs(best.Pearson_r);
best_rmse = best.LOOCV_RMSE;

rmse_improve_frac = (baseline_rmse - best_rmse)/baseline_rmse;

% Decision rule (minimal, deterministic)
if best_abs_pear >= 0.7 && best_rmse <= baseline_rmse * 0.85
    decision = 'YES';
elseif best_abs_pear >= 0.35 || rmse_improve_frac > 0.05
    decision = 'PARTIAL';
else
    decision = 'NO';
end

% Write tables/tau_vs_barrier_test.csv
rows = cell(4,1);
rows{1} = { 'baseline (LOOCV mean of log_tau)', '(constant)', n, baseline_rmse, baseline_pear, baseline_spear };
rows{2} = { res1.model, res1.predictors, res1.n_T, res1.LOOCV_RMSE, res1.Pearson_r, res1.Spearman_r };
rows{3} = { res2.model, res2.predictors, res2.n_T, res2.LOOCV_RMSE, res2.Pearson_r, res2.Spearman_r };
rows{4} = { res3.model, res3.predictors, res3.n_T, res3.LOOCV_RMSE, res3.Pearson_r, res3.Spearman_r };

out_table = cell2table(vertcat(rows{:}), 'VariableNames', ...
    {'model','predictors','n_T','LOOCV_RMSE','Pearson_r','Spearman_r'});

out_table.baseline_LOOCV_RMSE = baseline_rmse;
out_table.delta_RMSE_vs_baseline = out_table.LOOCV_RMSE - baseline_rmse;

% Round for readability
out_table.LOOCV_RMSE = round(out_table.LOOCV_RMSE, 6);
out_table.baseline_LOOCV_RMSE = round(out_table.baseline_LOOCV_RMSE, 6);
out_table.delta_RMSE_vs_baseline = round(out_table.delta_RMSE_vs_baseline, 6);
out_table.Pearson_r = round(out_table.Pearson_r, 6);
out_table.Spearman_r = round(out_table.Spearman_r, 6);

writetable(out_table, out_csv);

% Write reports/tau_vs_barrier_report.md (<= 10 lines interpretation)
interpret_lines = {};
interpret_lines{end+1} = sprintf('TAU_LINKED_TO_PT: %s', decision); %#ok<AGROW>
interpret_lines{end+1} = sprintf('Joined n_T=%d finite temperature points.', n);
interpret_lines{end+1} = sprintf('Baseline LOOCV RMSE=%g.', baseline_rmse);
interpret_lines{end+1} = sprintf('Best model=%s with LOOCV RMSE=%g.', best.model, best_rmse);
interpret_lines{end+1} = sprintf('Best Pearson |r|=%g (Spearman r=%g).', best_abs_pear, best.Spearman_r);
interpret_lines{end+1} = sprintf('RMSE improvement vs baseline=%g%%.', rmse_improve_frac*100);

% Keep report concise (interpret_lines is 6 lines total)
report = strjoin(interpret_lines, newline);
report = ["# tau vs barrier landscape (minimal probe)" newline newline report newline newline ...
    "Aging tau definition: tau_mean = tau_effective_seconds from tau_vs_Tp.csv; response is log(tau)." newline ...
    "Barrier proxies: mean_E = mean_threshold_mA and std_E = std_threshold_mA from PT_summary.csv." newline ...
    "Models tested (linear): log_tau~mean_E; log_tau~std_E; log_tau~mean_E+std_E." newline];

out_dir = fileparts(out_md);
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
fid = fopen(out_md, 'w');
fprintf(fid, '%s', report);
fclose(fid);

fprintf('JOINED_T_VALUES:'); disp(T(:)');
fprintf('DECISION: %s\n', decision);
fprintf('WROTE: %s\n', out_csv);
fprintf('WROTE: %s\n', out_md);
end

function pred = loocv_linear_predict(X_features, y)
% X_features: n x p (or n x 1)
n = numel(y);
if isvector(X_features)
    X_features = X_features(:);
end
if size(X_features,1) ~= n
    error('X_features rows (%d) must match y length (%d).', size(X_features,1), n);
end

pred = zeros(n,1);
for i = 1:n
    mask = true(n,1);
    mask(i) = false;
    X_train = X_features(mask,:);
    X_test = X_features(i,:);
    A_train = [ones(sum(mask),1), X_train];
    beta = A_train \ y(mask);
    A_test = [1, X_test];
    pred(i) = A_test * beta;
end
end

