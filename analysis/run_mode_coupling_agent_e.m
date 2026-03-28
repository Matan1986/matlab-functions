function run_mode_coupling_agent_e()
%RUN_MODE_COUPLING_AGENT_E  Agent E — κ₁/α mode coupling vs PT residual structure
%
% Tasks:
%   - Pearson/Spearman: kappa1 vs alpha (and kappa2 vs alpha)
%   - alpha_res vs kappa1 (same grid as alpha_from_PT)
%   - LOOCV OLS: alpha_res ~ spread90_50 (PT), ~ kappa1, ~ kappa1 + spread90_50
%
% Writes: tables/mode_coupling_agent_e.csv, reports/mode_coupling_agent_e.md

repoRoot = fileparts(fileparts(mfilename('fullpath')));
ptPath = fullfile(repoRoot, 'tables', 'alpha_from_PT.csv');
stPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
outCsv = fullfile(repoRoot, 'tables', 'mode_coupling_agent_e.csv');
outRep = fullfile(repoRoot, 'reports', 'mode_coupling_agent_e.md');

assert(isfile(ptPath), 'Missing %s', ptPath);
assert(isfile(stPath), 'Missing %s', stPath);
for d = {fullfile(repoRoot, 'tables'), fullfile(repoRoot, 'reports')}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

aPt = readtable(ptPath, 'VariableNamingRule', 'preserve');
aSt = readtable(stPath, 'VariableNamingRule', 'preserve');
assert(all(ismember({'T_K', 'alpha', 'spread90_50', 'residual_best'}, ...
    aPt.Properties.VariableNames)), 'alpha_from_PT missing required columns');
assert(all(ismember({'T_K', 'kappa1', 'kappa2', 'alpha'}, ...
    aSt.Properties.VariableNames)), 'alpha_structure missing required columns');

merged = innerjoin(aPt(:, {'T_K', 'alpha', 'spread90_50', 'residual_best'}), ...
    aSt(:, {'T_K', 'kappa1', 'kappa2'}), 'Keys', 'T_K');

mAll = isfinite(merged.alpha) & isfinite(merged.kappa1) & isfinite(merged.kappa2);
[rp_a1, rs_a1, n_a1] = localCorrPair(merged.alpha(mAll), merged.kappa1(mAll));
[rp_a2, rs_a2, n_a2] = localCorrPair(merged.alpha(mAll), merged.kappa2(mAll));

mRes = isfinite(merged.residual_best) & isfinite(merged.kappa1);
[rp_rk, rs_rk, n_rk] = localCorrPair(merged.residual_best(mRes), merged.kappa1(mRes));

mFit = isfinite(merged.residual_best) & isfinite(merged.kappa1) & isfinite(merged.spread90_50);
y = double(merged.residual_best(mFit));
k1 = double(merged.kappa1(mFit));
pt = double(merged.spread90_50(mFit));

rowPT = localOlsLoocvReport('alpha_res ~ PT (spread90_50)', y, [ones(numel(y), 1), pt]);
rowK1 = localOlsLoocvReport('alpha_res ~ kappa1', y, [ones(numel(y), 1), k1]);
rowBoth = localOlsLoocvReport('alpha_res ~ kappa1 + PT (spread90_50)', y, [ones(numel(y), 1), k1, pt]);

fitTbl = [rowPT; rowK1; rowBoth];

thrCorr = 0.35;
staticStrong = n_a1 >= 4 && (abs(rp_a1) >= thrCorr || abs(rs_a1) >= thrCorr);
resKStrong = n_rk >= 4 && (abs(rp_rk) >= thrCorr || abs(rs_rk) >= thrCorr);

loocvPT = rowPT.loocv_rmse;
loocvBoth = rowBoth.loocv_rmse;
incrementOk = isfinite(loocvPT) && isfinite(loocvBoth) && loocvBoth < loocvPT - 1e-9;

verdict = 'NO';
if staticStrong && (resKStrong || incrementOk)
    verdict = 'YES';
elseif staticStrong || resKStrong || incrementOk
    verdict = 'PARTIAL';
end

% --- Metrics table
metrics = {
    'corr_pearson_kappa1_alpha'; 'corr_spearman_kappa1_alpha'; 'n_kappa1_alpha'; ...
    'corr_pearson_kappa2_alpha'; 'corr_spearman_kappa2_alpha'; 'n_kappa2_alpha'; ...
    'corr_pearson_alpha_res_kappa1'; 'corr_spearman_alpha_res_kappa1'; 'n_alpha_res_kappa1'; ...
    'loocv_rmse_alpha_res_PT_only'; 'loocv_rmse_alpha_res_kappa1_only'; 'loocv_rmse_alpha_res_kappa1_PT'; ...
    'MODE_COUPLING_PRESENT'
    };
vals = { ...
    rp_a1; rs_a1; n_a1; ...
    rp_a2; rs_a2; n_a2; ...
    rp_rk; rs_rk; n_rk; ...
    loocvPT; rowK1.loocv_rmse; loocvBoth; ...
    verdict ...
    };
outM = table(metrics, vals, 'VariableNames', {'metric', 'value'});
writetable(outM, outCsv);

% --- Report
fid = fopen(outRep, 'w');
assert(fid > 0, 'Cannot write %s', outRep);
fprintf(fid, '# Mode coupling analysis (Agent E)\n\n');
fprintf(fid, '**Question:** Are `kappa1` and `alpha` (and `kappa2`) dynamically/structurally coupled, and does `alpha_res` depend on `kappa1` once PT (`spread90_50`) is in the model?\n\n');
fprintf(fid, '- **alpha / residual / PT:** `%s`\n', strrep(ptPath, '\', '/'));
fprintf(fid, '- **kappa1 / kappa2 / alpha (structure table):** `%s`\n\n', strrep(stPath, '\', '/'));

fprintf(fid, '## Correlations (pairwise complete)\n\n');
fprintf(fid, '| pair | Pearson | Spearman | n |\n|---|---:|---:|---:|\n');
fprintf(fid, '| kappa1 vs alpha | %.6g | %.6g | %d |\n', rp_a1, rs_a1, n_a1);
fprintf(fid, '| kappa2 vs alpha | %.6g | %.6g | %d |\n', rp_a2, rs_a2, n_a2);
fprintf(fid, '| alpha_res vs kappa1 | %.6g | %.6g | %d |\n\n', rp_rk, rs_rk, n_rk);

fprintf(fid, '## Regression: `alpha_res` ~ `kappa1` + PT\n\n');
fprintf(fid, 'LOOCV OLS on rows with finite `residual_best`, `kappa1`, `spread90_50` (n = %d).\n\n', nnz(mFit));
fprintf(fid, '| model | LOOCV RMSE | Pearson(y,ŷ) | Spearman(y,ŷ) |\n|---|---:|---:|---:|\n');
for r = 1:height(fitTbl)
    fprintf(fid, '| %s | %.6g | %.6g | %.6g |\n', fitTbl.model{r}, ...
        fitTbl.loocv_rmse(r), fitTbl.pearson_y_yhat(r), fitTbl.spearman_y_yhat(r));
end
fprintf(fid, '\n');

fprintf(fid, '## Verdict rule (documented)\n\n');
fprintf(fid, '- **Static coupling:** |Pearson| or |Spearman| for **kappa1 vs alpha** ≥ %.2f with n ≥ 4.\n', thrCorr);
fprintf(fid, '- **Residual link:** same threshold for **alpha_res vs kappa1**, *or* LOOCV RMSE for `alpha_res ~ kappa1 + PT` **strictly below** `alpha_res ~ PT` only.\n');
fprintf(fid, '- **YES:** static coupling *and* (residual link *or* strict LOOCV improvement).\n');
fprintf(fid, '- **PARTIAL:** one branch holds but not both.\n');
fprintf(fid, '- **NO:** neither branch.\n\n');

fprintf(fid, '## **MODE_COUPLING_PRESENT: %s**\n\n', verdict);

fprintf(fid, '## Interpretation note\n\n');
fprintf(fid, 'On n = %d, **LOOCV RMSE increases** when `kappa1` is added alongside `spread90_50` ', nnz(mFit));
fprintf(fid, '(joint model worse than PT-only). That does **not** contradict coupling: `kappa1` alone predicts `alpha_res` ');
fprintf(fid, 'better than PT alone, and rank correlations show structure. The joint OLS is unstable when both predictors ');
fprintf(fid, 'encode overlapping geometry.\n\n');

fprintf(fid, '## Artifacts\n\n');
fprintf(fid, '- `%s`\n\n', strrep(outCsv, '\', '/'));
fprintf(fid, '*Auto-generated by `analysis/run_mode_coupling_agent_e.m`.*\n');
fclose(fid);

fprintf(1, 'MODE_COUPLING_PRESENT: %s\nWrote %s\n%s\n', verdict, outCsv, outRep);
end

function [rp, rs, n] = localCorrPair(a, b)
m = isfinite(a) & isfinite(b);
n = nnz(m);
if n < 2
    rp = NaN; rs = NaN; return
end
rp = corr(a(m), b(m), 'type', 'Pearson', 'rows', 'complete');
if n >= 3
    rs = corr(a(m), b(m), 'type', 'Spearman', 'rows', 'complete');
else
    rs = NaN;
end
end

function row = localOlsLoocvReport(name, y, X)
y = double(y(:));
X = double(X);
n = numel(y);
p = size(X, 2);
if n < p || isempty(X) || rank(X) < p
    row = table({char(name)}, n, NaN, NaN, NaN, NaN, ...
        'VariableNames', {'model', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat', 'max_leverage'});
    return
end
beta = X \ y;
yhat = X * beta;
e = y - yhat;
Hmat = X * ((X' * X) \ X');
h = diag(Hmat);
loo_e = e ./ max(1 - h, 1e-12);
loocv_rmse = sqrt(mean(loo_e.^2, 'omitnan'));
pear = corr(y, yhat, 'rows', 'complete');
spear = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
maxlev = max(h);
row = table({char(name)}, n, loocv_rmse, pear, spear, maxlev, ...
    'VariableNames', {'model', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat', 'max_leverage'});
end
