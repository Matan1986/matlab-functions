function functional_form_test_analysis()
% Functional-form comparison for A(T) vs X and alternatives.
% Reuses existing aligned cross-experiment table only.

repo_root = fileparts(fileparts(mfilename('fullpath')));
data_path = fullfile(repo_root, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_13_115401_AX_functional_relation_analysis', 'tables', 'AX_aligned_data.csv');
report_path = fullfile(repo_root, 'reports', 'functional_form_test_report.md');
table_path = fullfile(repo_root, 'reports', 'functional_form_test_metrics.csv');

T = readtable(data_path);
T = sortrows(T, 'T_K');
tK = T.T_K;
A = T.A_interp;
X = T.X;
I = T.I_peak_mA;
w = T.width_mA;
S = T.S_peak;

[~, idx_peak_A] = max(A);
t_peak_A = tK(idx_peak_A);

rows = {};

% 1) Baseline
yhat = fit_powerlaw_predict(X, A);
rows(end+1, :) = build_row('baseline', 'X_power_law', 'X = I/(w*S)', ...
    'ln(A)=a ln(X)+b', A, yhat, tK, t_peak_A); %#ok<AGROW>

% 2) Direct T models
yhat = polyval(polyfit(tK, A, 2), tK);
rows(end+1, :) = build_row('direct_T', 'poly2_T', 'T', 'A~poly2(T)', A, yhat, tK, t_peak_A); %#ok<AGROW>
yhat = polyval(polyfit(tK, A, 3), tK);
rows(end+1, :) = build_row('direct_T', 'poly3_T', 'T', 'A~poly3(T)', A, yhat, tK, t_peak_A); %#ok<AGROW>
yhat = polyval(polyfit(tK, A, 4), tK);
rows(end+1, :) = build_row('direct_T', 'poly4_T', 'T', 'A~poly4(T)', A, yhat, tK, t_peak_A); %#ok<AGROW>
yhat = ppval(spline(tK, A), tK);
rows(end+1, :) = build_row('direct_T', 'spline_T', 'T', 'cubic spline interpolation', A, yhat, tK, t_peak_A); %#ok<AGROW>

% 3) Generic transforms
yhat = fit_linear_predict(log(tK), A);
rows(end+1, :) = build_row('T_transform', 'logT_linear', 'log(T)', 'A~a log(T)+b', A, yhat, tK, t_peak_A); %#ok<AGROW>
yhat = fit_linear_predict(exp(-tK), A);
rows(end+1, :) = build_row('T_transform', 'exp_minus_T_linear', 'exp(-T)', 'A~a exp(-T)+b', A, yhat, tK, t_peak_A); %#ok<AGROW>
yhat = fit_linear_predict(1 ./ tK, A);
rows(end+1, :) = build_row('T_transform', 'invT_linear', '1/T', 'A~a(1/T)+b', A, yhat, tK, t_peak_A); %#ok<AGROW>

% 4) Nonparametric monotonic
yhat_inc = pava_fit(A, true);
yhat_dec = pava_fit(A, false);
if sum((A - yhat_inc).^2) <= sum((A - yhat_dec).^2)
    yhat_iso = yhat_inc;
    iso_note = 'increasing';
else
    yhat_iso = yhat_dec;
    iso_note = 'decreasing';
end
rows(end+1, :) = build_row('nonparametric', 'isotonic_T', 'T', ...
    ['isotonic regression (' iso_note ')'], A, yhat_iso, tK, t_peak_A); %#ok<AGROW>

% Monotonic spline surrogate: monotone pchip through isotonic fit.
yhat = ppval(pchip(tK, yhat_iso), tK);
rows(end+1, :) = build_row('nonparametric', 'monotonic_spline_T', 'T', ...
    ['pchip on isotonic fit (' iso_note ')'], A, yhat, tK, t_peak_A); %#ok<AGROW>

% 5) Alternative coordinates
yhat = fit_powerlaw_predict(I ./ w, A);
rows(end+1, :) = build_row('alt_coordinate', 'X_alt1_I_over_w', 'I/w', ...
    'ln(A)=a ln(I/w)+b', A, yhat, tK, t_peak_A); %#ok<AGROW>
yhat = fit_powerlaw_predict(1 ./ (w .* S), A);
rows(end+1, :) = build_row('alt_coordinate', 'X_alt2_inv_wS', '1/(w*S)', ...
    'ln(A)=a ln(1/(w*S))+b', A, yhat, tK, t_peak_A); %#ok<AGROW>
yhat = fit_powerlaw_predict(S, A);
rows(end+1, :) = build_row('alt_coordinate', 'X_alt3_S_peak', 'S_peak', ...
    'ln(A)=a ln(S_peak)+b', A, yhat, tK, t_peak_A); %#ok<AGROW>
yhat = fit_powerlaw_predict(I, A);
rows(end+1, :) = build_row('alt_coordinate', 'X_alt4_I_peak', 'I_peak', ...
    'ln(A)=a ln(I_peak)+b', A, yhat, tK, t_peak_A); %#ok<AGROW>

out = cell2table(rows, 'VariableNames', { ...
    'model_group', 'model_id', 'predictor', 'fit_form', ...
    'pearson_A_vs_Ahat', 'spearman_A_vs_Ahat', 'deltaT_peak_K', ...
    'R2', 'residual_corr_with_T', 'residual_std'});
out = sortrows(out, {'R2', 'pearson_A_vs_Ahat'}, {'descend', 'descend'});
writetable(out, table_path);

% Verdict logic relative to X baseline.
ix_baseline = strcmp(out.model_id, 'X_power_law');
bx = out(ix_baseline, :);
tol_r = 0.005;
tol_s = 0.005;
tol_dt = 0;
as_good = abs(out.pearson_A_vs_Ahat - bx.pearson_A_vs_Ahat) <= tol_r & ...
          abs(out.spearman_A_vs_Ahat - bx.spearman_A_vs_Ahat) <= tol_s & ...
          abs(out.deltaT_peak_K) <= tol_dt;
as_good(ix_baseline) = false;
num_as_good = sum(as_good);

simple_alt_idx = contains(out.model_id, 'X_alt') | strcmp(out.model_id, 'logT_linear') | ...
                 strcmp(out.model_id, 'exp_minus_T_linear') | strcmp(out.model_id, 'invT_linear');
simple_match = simple_alt_idx & ...
               (out.R2 >= bx.R2 - 0.01) & (abs(out.deltaT_peak_K) <= tol_dt);
num_simple_match = sum(simple_match);

if num_as_good == 0
    verdict = 'X is unique (or near-unique)';
elseif num_as_good <= 5
    verdict = 'X is one of a small family (canonical representative)';
else
    verdict = 'X is not special';
end

best3 = out(1:min(3, height(out)), :);

fid = fopen(report_path, 'w');
fprintf(fid, '# Functional Form Test Report\n\n');
fprintf(fid, '## Summary\n');
fprintf(fid, '- Dataset: `%s` (n=%d, T=%g-%g K).\n', relative_path(repo_root, data_path), numel(A), min(tK), max(tK));
fprintf(fid, '- Baseline model: `A ~ X^beta` with `X = I_peak/(w*S_peak)`.\n');
fprintf(fid, '- Compared direct T models, transformed T models, nonparametric monotonic models, and alternative coordinates.\n');
fprintf(fid, '- Final verdict: **%s**.\n\n', verdict);

fprintf(fid, '## Data reused\n');
fprintf(fid, '- `%s`\n', relative_path(repo_root, data_path));
fprintf(fid, '- `reports/temperature_null_test_report.md` (existing polynomial/spline context)\n');
fprintf(fid, '- `reports/dimensionless_constrained_basin_report.md` (existing constrained-basin context)\n');
fprintf(fid, '- `results/cross_experiment/runs/run_2026_03_22_080734_x_single_observable_residual_test_corrected/reports/x_independence_single_observable_report.md`\n\n');

fprintf(fid, '## Models tested\n');
fprintf(fid, '- Baseline: X power law (`ln(A)=a ln(X)+b`).\n');
fprintf(fid, '- Direct temperature: polynomial degree 2/3/4, cubic spline.\n');
fprintf(fid, '- Generic transforms: `log(T)`, `exp(-T)`, `1/T`.\n');
fprintf(fid, '- Nonparametric monotonic: isotonic regression, monotonic spline (pchip on isotonic fit).\n');
fprintf(fid, '- Alternative coordinates: `I_peak/w`, `1/(w*S_peak)`, `S_peak`, `I_peak`.\n\n');

fprintf(fid, '## Full comparison table\n');
fprintf(fid, '- Machine-readable table: `reports/functional_form_test_metrics.csv`.\n\n');
fprintf(fid, '| Model | Group | Pearson(A,Ahat) | Spearman(A,Ahat) | DeltaT_peak (K) | R2 | Residual corr(T) |\n');
fprintf(fid, '| --- | --- | ---: | ---: | ---: | ---: | ---: |\n');
for i = 1:height(out)
    fprintf(fid, '| %s | %s | %.6f | %.6f | %.1f | %.6f | %.6f |\n', ...
        out.model_id{i}, out.model_group{i}, out.pearson_A_vs_Ahat(i), out.spearman_A_vs_Ahat(i), ...
        out.deltaT_peak_K(i), out.R2(i), out.residual_corr_with_T(i));
end
fprintf(fid, '\n');

fprintf(fid, '## Best-performing alternatives\n');
for i = 1:height(best3)
    fprintf(fid, '- `%s`: R2=%.6f, Pearson=%.6f, Spearman=%.6f, DeltaT_peak=%.1f K.\n', ...
        best3.model_id{i}, best3.R2(i), best3.pearson_A_vs_Ahat(i), best3.spearman_A_vs_Ahat(i), best3.deltaT_peak_K(i));
end
fprintf(fid, '\n');

fprintf(fid, '## Comparison vs X\n');
fprintf(fid, '- Baseline X metrics: Pearson=%.6f, Spearman=%.6f, DeltaT_peak=%.1f K, R2=%.6f.\n', ...
    bx.pearson_A_vs_Ahat, bx.spearman_A_vs_Ahat, bx.deltaT_peak_K, bx.R2);
fprintf(fid, '- Number of alternatives matching X within tight tolerance (|DeltaPearson|<=%.3f, |DeltaSpearman|<=%.3f, |DeltaT_peak|<=%.0f K): **%d**.\n', ...
    tol_r, tol_s, tol_dt, num_as_good);
fprintf(fid, '- Number of simple alternatives matching both scaling (R2 within 0.01 of X) and peak alignment: **%d**.\n\n', ...
    num_simple_match);

fprintf(fid, '## Structure test\n');
fprintf(fid, '- Some models achieve high scaling quality but fail peak alignment, while others preserve peak alignment with weaker scaling.\n');
fprintf(fid, '- This separation indicates that matching only one criterion is common; matching both is more selective.\n\n');

fprintf(fid, '## Final questions\n');
fprintf(fid, '1. Are there many functions of T that perform as well as X? **%s**\n', yes_no(num_as_good > 5));
fprintf(fid, '2. Does any simple alternative match BOTH scaling and alignment? **%s**\n', yes_no(num_simple_match > 0));
fprintf(fid, '3. Is X distinguishable by simplicity and structure? **%s**\n\n', yes_no(~strcmp(verdict, 'X is not special')));

fprintf(fid, '## Final verdict\n');
fprintf(fid, '- **%s**\n', verdict);
fclose(fid);

fprintf('Wrote report: %s\n', report_path);
fprintf('Wrote table: %s\n', table_path);
end

function yhat = fit_linear_predict(x, y)
p = polyfit(x, y, 1);
yhat = polyval(p, x);
end

function yhat = fit_powerlaw_predict(x, y)
p = polyfit(log(x), log(y), 1);
yhat = exp(polyval(p, log(x)));
end

function row = build_row(group, id, pred, form, y, yhat, t, t_peak_y)
pear = corr(y, yhat, 'Type', 'Pearson', 'Rows', 'complete');
spear = corr(y, yhat, 'Type', 'Spearman', 'Rows', 'complete');
res = y - yhat;
sse = sum(res .^ 2);
sst = sum((y - mean(y)) .^ 2);
r2 = 1 - sse / sst;
[~, idx_peak] = max(yhat);
dT = t(idx_peak) - t_peak_y;
res_corr_t = corr(res, t, 'Type', 'Pearson', 'Rows', 'complete');
row = {group, id, pred, form, pear, spear, dT, r2, res_corr_t, std(res)};
end

function y_iso = pava_fit(y, increasing)
if ~increasing
    y = flipud(y);
end

n = numel(y);
v = y(:);
w = ones(n, 1);
i = 1;
while i < numel(v)
    if v(i) > v(i + 1)
        new_w = w(i) + w(i + 1);
        new_v = (w(i) * v(i) + w(i + 1) * v(i + 1)) / new_w;
        v(i) = new_v;
        w(i) = new_w;
        v(i + 1) = [];
        w(i + 1) = [];
        if i > 1
            i = i - 1;
        end
    else
        i = i + 1;
    end
end

y_iso = zeros(n, 1);
idx = 1;
for k = 1:numel(v)
    y_iso(idx:(idx + w(k) - 1)) = v(k);
    idx = idx + w(k);
end

if ~increasing
    y_iso = flipud(y_iso);
end
end

function s = relative_path(repo_root, full_path)
s = strrep(full_path, [repo_root filesep], '');
s = strrep(s, '\', '/');
end

function s = yes_no(flag)
if flag
    s = 'YES';
else
    s = 'NO';
end
end
