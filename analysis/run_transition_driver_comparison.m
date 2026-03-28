function run_transition_driver_comparison(varargin)
%RUN_TRANSITION_DRIVER_COMPARISON  Agent D — compare drivers of PT+kappa1+alpha aging residual near 22–24 K
%
% Loads the same merge as Agent 24I (barrier + energy + alpha_structure + alpha_decomposition).
% Baseline aging model: R ~ spread90_50 + kappa1 + alpha (LOOCV OLS, intercept).
%
% Compares |alpha_res|, kappa1, spread90_50 as explanations of the baseline residual in 20–26 K:
%   - Pearson / Spearman correlation with LOOCV residual (window + all rows)
%   - Univariate LOOCV: residual ~ 1 + driver (how well each scalar tracks miss)
%   - Full-model LOOCV: baseline vs baseline + |alpha_res| vs baseline + kappa1^2 vs baseline + spread90_50^2
%     (quadratic terms are the natural incremental DOF when the linear term is already in the fit)
%
% Outputs (repo root):
%   tables/transition_driver_per_T.csv
%   tables/transition_driver_comparison.csv
%   reports/transition_driver_report.md
%
% Name-value: 'repoRoot', 'barrierPath', 'energyStatsPath', 'clockRatioPath',
%             'alphaStructurePath', 'decompPath', 'T_lo', 'T_hi'

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

set(0, 'DefaultFigureVisible', 'off');

Tlo = opts.T_lo;
Thi = opts.T_hi;

%% Load (24I lineage)
clkPath = opts.clockRatioPath;
assert(isfile(clkPath), 'Missing clock ratio table: %s', clkPath);

bar = readtable(opts.barrierPath, 'VariableNamingRule', 'preserve');
en = readtable(opts.energyStatsPath, 'VariableNamingRule', 'preserve');
if ismember('T', en.Properties.VariableNames) && ~ismember('T_K', en.Properties.VariableNames)
    en.Properties.VariableNames{'T'} = 'T_K';
end
assert(ismember('T_K', en.Properties.VariableNames), 'energy_stats needs T_K or T column');
en = en(:, intersect({'T_K', 'mean_E', 'std_E'}, en.Properties.VariableNames, 'stable'));

bar = innerjoin(bar, en, 'Keys', 'T_K');
bar.spread90_50 = double(bar.q90_I_mA) - double(bar.q50_I_mA);

reqB = {'T_K', 'row_valid', 'R_T_interp', 'spread90_50', 'q90_I_mA', 'q50_I_mA'};
for k = 1:numel(reqB)
    assert(ismember(reqB{k}, bar.Properties.VariableNames), 'barrier_descriptors missing %s', reqB{k});
end

aS = readtable(opts.alphaStructurePath, 'VariableNamingRule', 'preserve');
aD = readtable(opts.decompPath, 'VariableNamingRule', 'preserve');
assert(all(ismember({'T_K', 'kappa1', 'kappa2', 'alpha'}, aS.Properties.VariableNames)), ...
    'alpha_structure missing kappa/alpha columns');
assert(all(ismember({'T_K', 'PT_geometry_valid'}, aD.Properties.VariableNames)), ...
    'alpha_decomposition missing PT_geometry_valid');

decompCols = {'T_K', 'PT_geometry_valid'};
if ismember('alpha_res', aD.Properties.VariableNames)
    decompCols{end + 1} = 'alpha_res'; %#ok<AGROW>
end
merged = innerjoin(aS(:, {'T_K', 'kappa1', 'kappa2', 'alpha'}), ...
    aD(:, decompCols), 'Keys', 'T_K');

bCols = intersect(reqB, bar.Properties.VariableNames, 'stable');
merged = innerjoin(merged, bar(:, bCols), 'Keys', 'T_K');

merged = merged(double(merged.PT_geometry_valid) ~= 0, :);
merged = merged(double(merged.row_valid) ~= 0, :);
merged = sortrows(merged, 'T_K');

T_K = double(merged.T_K(:));
R = double(merged.R_T_interp(:));
k1 = double(merged.kappa1(:));
alp = double(merged.alpha(:));
spread90_50 = double(merged.spread90_50(:));
if ismember('alpha_res', merged.Properties.VariableNames)
    ares = double(merged.alpha_res(:));
else
    ares = nan(size(T_K));
end

mOverlap = isfinite(R) & isfinite(spread90_50) & isfinite(k1) & isfinite(alp);
absAres = abs(ares);
modelAresOk = ismember('alpha_res', merged.Properties.VariableNames) && all(isfinite(absAres(mOverlap)));

nOverlap = nnz(mOverlap);
assert(nOverlap >= 5, 'transition_driver: insufficient overlap rows (n=%d).', nOverlap);

Tplot = T_K(mOverlap);
y = R(mOverlap);
s = spread90_50(mOverlap);
k1v = k1(mOverlap);
av = alp(mOverlap);
aresAbs = absAres(mOverlap);
n = numel(y);

%% Baseline LOOCV: R ~ spread + kappa1 + alpha
Xbase = [s, k1v, av];
[rmseBase, ~, yhatBase] = localLoocvOls(y, Xbase);
assert(isfinite(rmseBase), 'Baseline LOOCV failed (rank/n).');
epsRes = y - yhatBase;
maeBaseWin = localMeanAbsRes(Tplot, y, yhatBase, @(t) t >= Tlo & t <= Thi);

mWin = (Tplot >= Tlo) & (Tplot <= Thi) & isfinite(epsRes);

%% Per-T table
inWin = (T_K >= Tlo) & (T_K <= Thi);
epsFull = nan(size(T_K));
epsFull(mOverlap) = epsRes;
perT = table(T_K, R, spread90_50, k1, alp, absAres, epsFull, inWin & mOverlap, ...
    'VariableNames', {'T_K', 'R', 'spread90_50', 'kappa1', 'alpha', 'abs_alpha_res', ...
    'aging_residual_loocv_baseline', 'in_transition_window_20_26'});
tblDir = fullfile(repoRoot, 'tables');
repDir = fullfile(repoRoot, 'reports');
if exist(tblDir, 'dir') ~= 7, mkdir(tblDir); end
if exist(repDir, 'dir') ~= 7, mkdir(repDir); end
writetable(perT, fullfile(tblDir, 'transition_driver_per_T.csv'));

%% Driver specs for correlation + epsilon prediction
% z_* columns aligned with mOverlap rows
drivers = struct('id', {}, 'z', {}, 'note', {});
drivers(end + 1) = struct('id', 'abs_alpha_res', 'z', aresAbs, 'note', '|alpha_res| (not in baseline)'); %#ok<AGROW>
drivers(end + 1) = struct('id', 'kappa1', 'z', k1v, 'note', 'linear term already in baseline'); %#ok<AGROW>
drivers(end + 1) = struct('id', 'spread90_50', 'z', s, 'note', 'linear term already in baseline'); %#ok<AGROW>

%% Full R-model extensions (incremental DOF)
extModels = struct('id', {}, 'Xextra', {});
if modelAresOk
    extModels(end + 1) = struct('id', 'baseline_plus_abs_alpha_res', 'Xextra', aresAbs(:)); %#ok<AGROW>
end
extModels(end + 1) = struct('id', 'baseline_plus_kappa1_squared', 'Xextra', (k1v(:)).^2); %#ok<AGROW>
extModels(end + 1) = struct('id', 'baseline_plus_spread90_50_squared', 'Xextra', (s(:)).^2); %#ok<AGROW>

rowsComp = table();
for d = 1:numel(drivers)
    z = drivers(d).z(:);
    id = drivers(d).id;

    [pAll, spAll] = localCorrSafe(epsRes, z);
    mW = mWin & isfinite(z);
    if nnz(mW) >= 3
        [pWin, spWin] = localCorrSafe(epsRes(mW), z(mW));
        nW = nnz(mW);
    else
        pWin = NaN;
        spWin = NaN;
        nW = nnz(mW);
    end

    [rmseEpsG, ~, ~] = localLoocvOls(epsRes, z);
    if nnz(mW) > 3
        [rmseEpsW, ~, ~] = localLoocvOls(epsRes(mW), z(mW));
    else
        rmseEpsW = NaN;
    end

    rowsComp = [rowsComp; table({id}, {drivers(d).note}, n, nW, pAll, spAll, pWin, spWin, ...
        rmseEpsG, rmseEpsW, ...
        'VariableNames', {'driver_id', 'note', 'n_overlap', 'n_window_20_26', ...
        'pearson_corr_eps_global', 'spearman_corr_eps_global', ...
        'pearson_corr_eps_window_20_26', 'spearman_corr_eps_window_20_26', ...
        'loocv_rmse_eps_univariate_global', 'loocv_rmse_eps_univariate_window'})]; %#ok<AGROW>
end

%% Extended R models
rowExt = table();
for e = 1:numel(extModels)
    Xe = [Xbase, extModels(e).Xextra];
    [rmseE, ~, yhatE] = localLoocvOls(y, Xe);
    maeEWin = localMeanAbsRes(Tplot, y, yhatE, @(t) t >= Tlo & t <= Thi);
    dRmse = rmseE - rmseBase;
    pctRmse = 100 * (rmseBase - rmseE) / max(rmseBase, eps);
    dMae = maeEWin - maeBaseWin;
    pctMae = 100 * (maeBaseWin - maeEWin) / max(maeBaseWin, eps);
    rowExt = [rowExt; table({extModels(e).id}, rmseBase, rmseE, dRmse, pctRmse, ...
        maeBaseWin, maeEWin, dMae, pctMae, ...
        'VariableNames', {'extended_model', 'loocv_rmse_R_baseline', 'loocv_rmse_R_extended', ...
        'delta_rmse_extended_minus_baseline', 'pct_rmse_improvement_vs_baseline', ...
        'mean_abs_res_R_window_baseline', 'mean_abs_res_R_window_extended', ...
        'delta_mae_window_extended_minus_baseline', 'pct_mae_window_improvement_vs_baseline'})]; %#ok<AGROW>
end

%% Unified comparison CSV: residual drivers + full-model extensions (one file)
nr = height(rowsComp);
ne = height(rowExt);
nanCol = @(m) NaN(m, 1);
rowsCompU = [table(repmat({'residual_correlation'}, nr, 1), rowsComp.driver_id, rowsComp.note, ...
    rowsComp.n_overlap, rowsComp.n_window_20_26, ...
    rowsComp.pearson_corr_eps_global, rowsComp.spearman_corr_eps_global, ...
    rowsComp.pearson_corr_eps_window_20_26, rowsComp.spearman_corr_eps_window_20_26, ...
    rowsComp.loocv_rmse_eps_univariate_global, rowsComp.loocv_rmse_eps_univariate_window, ...
    nanCol(nr), nanCol(nr), nanCol(nr), nanCol(nr), nanCol(nr), nanCol(nr), nanCol(nr), nanCol(nr), ...
    'VariableNames', {'row_kind', 'variable_id', 'note', 'n_overlap', 'n_window_20_26', ...
    'pearson_corr_eps_global', 'spearman_corr_eps_global', ...
    'pearson_corr_eps_window_20_26', 'spearman_corr_eps_window_20_26', ...
    'loocv_rmse_eps_univariate_global', 'loocv_rmse_eps_univariate_window', ...
    'loocv_rmse_R_baseline', 'loocv_rmse_R_extended', 'delta_rmse_extended_minus_baseline', ...
    'pct_rmse_improvement_vs_baseline', 'mean_abs_res_R_window_baseline', ...
    'mean_abs_res_R_window_extended', 'delta_mae_window_extended_minus_baseline', ...
    'pct_mae_window_improvement_vs_baseline'})];

extNote = cell(ne, 1);
for ii = 1:ne
    extNote{ii} = 'LOOCV: baseline + one extra column';
end
rowsExtU = [table(repmat({'full_model_extension'}, ne, 1), rowExt.extended_model, extNote, ...
    repmat(n, ne, 1), nan(ne, 1), nanCol(ne), nanCol(ne), nanCol(ne), nanCol(ne), nanCol(ne), nanCol(ne), ...
    rowExt.loocv_rmse_R_baseline, rowExt.loocv_rmse_R_extended, rowExt.delta_rmse_extended_minus_baseline, ...
    rowExt.pct_rmse_improvement_vs_baseline, rowExt.mean_abs_res_R_window_baseline, ...
    rowExt.mean_abs_res_R_window_extended, rowExt.delta_mae_window_extended_minus_baseline, ...
    rowExt.pct_mae_window_improvement_vs_baseline, ...
    'VariableNames', {'row_kind', 'variable_id', 'note', 'n_overlap', 'n_window_20_26', ...
    'pearson_corr_eps_global', 'spearman_corr_eps_global', ...
    'pearson_corr_eps_window_20_26', 'spearman_corr_eps_window_20_26', ...
    'loocv_rmse_eps_univariate_global', 'loocv_rmse_eps_univariate_window', ...
    'loocv_rmse_R_baseline', 'loocv_rmse_R_extended', 'delta_rmse_extended_minus_baseline', ...
    'pct_rmse_improvement_vs_baseline', 'mean_abs_res_R_window_baseline', ...
    'mean_abs_res_R_window_extended', 'delta_mae_window_extended_minus_baseline', ...
    'pct_mae_window_improvement_vs_baseline'})];

writetable([rowsCompU; rowsExtU], fullfile(tblDir, 'transition_driver_comparison.csv'));

%% Verdict: |alpha_res| vs quadratic k1 / spread extensions
verdict = localVerdictAlphaRes(rowExt, modelAresOk);

%% Report
rep = localBuildReport(opts, clkPath, Tlo, Thi, Tplot, y, epsRes, rmseBase, maeBaseWin, ...
    rowsComp, rowExt, verdict, modelAresOk);
fid = fopen(fullfile(repDir, 'transition_driver_report.md'), 'w');
assert(fid > 0, 'Could not open report for write');
fwrite(fid, rep);
fclose(fid);

fprintf(1, 'transition_driver: wrote %s\n', fullfile(tblDir, 'transition_driver_comparison.csv'));
fprintf(1, 'transition_driver: wrote %s\n', fullfile(repDir, 'transition_driver_report.md'));
fprintf(1, 'ALPHA_RES_DRIVES_TRANSITION: %s\n', verdict);
end

%% ------------------------------------------------------------------------
function m = localMeanAbsRes(T, y, yhat, maskFn)
msk = maskFn(T) & isfinite(T(:)) & isfinite(y(:)) & isfinite(yhat(:));
if ~any(msk)
    m = NaN;
else
    m = mean(abs(y(msk) - yhat(msk)), 'omitnan');
end
end

function [p, sp] = localCorrSafe(a, b)
a = double(a(:));
b = double(b(:));
m = isfinite(a) & isfinite(b);
if nnz(m) < 3
    p = NaN;
    sp = NaN;
    return
end
p = corr(a(m), b(m), 'type', 'Pearson', 'rows', 'complete');
sp = corr(a(m), b(m), 'type', 'Spearman', 'rows', 'complete');
end

function [rmse, rP, yhat] = localLoocvOls(y, X)
y = double(y(:));
X = double(X);
n = numel(y);
p = size(X, 2);
yhat = nan(n, 1);
rmse = NaN;
rP = NaN;
Z = [ones(n, 1), X];
if n <= p + 1 || any(~isfinite(Z), 'all') || any(~isfinite(y))
    return
end
if rank(Z) < size(Z, 2)
    return
end
beta = Z \ y;
yfit = Z * beta;
e = y - yfit;
H = Z * ((Z' * Z) \ Z');
h = diag(H);
loo = e ./ max(1 - h, 1e-12);
yhat = y - loo;
rmse = sqrt(mean(loo.^2));
rP = corr(y, yhat, 'rows', 'complete');
end

function v = localVerdictAlphaRes(rowExt, modelAresOk)
% Compare abs_alpha_res extension vs kappa1^2 vs spread^2 on window MAE and global RMSE
v = "NO";
if ~modelAresOk
    v = "NO (alpha_res missing)";
    return
end
idxA = find(strcmp(rowExt.extended_model, 'baseline_plus_abs_alpha_res'), 1);
idxK = find(strcmp(rowExt.extended_model, 'baseline_plus_kappa1_squared'), 1);
idxS = find(strcmp(rowExt.extended_model, 'baseline_plus_spread90_50_squared'), 1);
if isempty(idxA)
    v = "NO";
    return
end
pctRmseA = rowExt.pct_rmse_improvement_vs_baseline(idxA);
pctMaeA = rowExt.pct_mae_window_improvement_vs_baseline(idxA);
pctRmseK = rowExt.pct_rmse_improvement_vs_baseline(idxK);
pctMaeK = rowExt.pct_mae_window_improvement_vs_baseline(idxK);
pctRmseS = rowExt.pct_rmse_improvement_vs_baseline(idxS);
pctMaeS = rowExt.pct_mae_window_improvement_vs_baseline(idxS);

bestMae = max([pctMaeA, pctMaeK, pctMaeS], [], 'omitnan');
bestRmse = max([pctRmseA, pctRmseK, pctRmseS], [], 'omitnan');
tol = 1e-6;
isBestMae = isfinite(pctMaeA) && isfinite(bestMae) && (pctMaeA >= bestMae - tol);
isBestRmse = isfinite(pctRmseA) && isfinite(bestRmse) && (pctRmseA >= bestRmse - tol);
strictGain = (isfinite(pctMaeA) && pctMaeA > tol) || (isfinite(pctRmseA) && pctRmseA > tol);

domK = isfinite(pctRmseK) && isfinite(pctMaeK) && isfinite(pctRmseA) && isfinite(pctMaeA) ...
    && (pctRmseK > pctRmseA + tol) && (pctMaeK > pctMaeA + tol);
domS = isfinite(pctRmseS) && isfinite(pctMaeS) && isfinite(pctRmseA) && isfinite(pctMaeA) ...
    && (pctRmseS > pctRmseA + tol) && (pctMaeS > pctMaeA + tol);

if domK || domS
    v = "NO";
elseif isBestMae && isBestRmse && strictGain
    v = "YES";
elseif strictGain && (isBestMae || isBestRmse)
    v = "PARTIAL";
elseif strictGain
    v = "PARTIAL";
else
    v = "NO";
end
end

function txt = localBuildReport(opts, clkPath, Tlo, Thi, Tplot, y, epsRes, rmseBase, maeBaseWin, ...
    rowsComp, rowExt, verdict, modelAresOk)

lines = {};
lines{end + 1} = '# Transition driver comparison (Agent D)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Question:** Does `|alpha_res|` explain the aging residual from `R ~ spread90_50 + kappa1 + alpha` better than other observables near the 22–24 K transition?');
lines{end + 1} = '';
lines{end + 1} = '## Setup';
lines{end + 1} = sprintf('- **Transition window (this run):** T ∈ [%.0f, %.0f] K', Tlo, Thi);
lines{end + 1} = sprintf('- **R(T) clock table:** `%s`', strrep(clkPath, '\', '/'));
lines{end + 1} = sprintf('- **Barrier / PT geometry:** `%s`', strrep(opts.barrierPath, '\', '/'));
lines{end + 1} = sprintf('- **Energy stats:** `%s`', strrep(opts.energyStatsPath, '\', '/'));
lines{end + 1} = sprintf('- **alpha_structure:** `%s`', strrep(opts.alphaStructurePath, '\', '/'));
lines{end + 1} = sprintf('- **alpha_decomposition:** `%s`', strrep(opts.decompPath, '\', '/'));
lines{end + 1} = '- **Baseline model:** OLS with intercept, LOOCV; `R ~ spread90_50 + kappa1 + alpha`.';
lines{end + 1} = '- **Aging residual:** `R - ŷ` from that LOOCV fit (same row set as Agent 24I overlap).';
lines{end + 1} = '';
lines{end + 1} = '## Per-temperature table';
lines{end + 1} = '- `tables/transition_driver_per_T.csv` — `T_K`, `R`, `spread90_50`, `kappa1`, `alpha`, `|alpha_res|`, baseline LOOCV residual, window flag.';
lines{end + 1} = '- `tables/transition_driver_comparison.csv` — block **`residual_correlation`** (ε vs observables) then **`full_model_extension`** (baseline + one extra term).';
lines{end + 1} = '';
lines{end + 1} = '## Correlation with baseline residual';
lines{end + 1} = '| driver | n (window) | Pearson ε (window) | Spearman ε (window) | Pearson ε (global) | Spearman ε (global) |';
lines{end + 1} = '|---|---:|---:|---:|---:|---:|';
for k = 1:height(rowsComp)
    lines{end + 1} = sprintf('| `%s` | %d | %.4g | %.4g | %.4g | %.4g |', ...
        rowsComp.driver_id{k}, rowsComp.n_window_20_26(k), ...
        rowsComp.pearson_corr_eps_window_20_26(k), rowsComp.spearman_corr_eps_window_20_26(k), ...
        rowsComp.pearson_corr_eps_global(k), rowsComp.spearman_corr_eps_global(k)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '*Note:* `kappa1` and `spread90_50` already enter the baseline linearly; their correlation with ε is **not** an independent predictive claim.';
lines{end + 1} = '';
lines{end + 1} = '## Univariate LOOCV: predict residual from one driver';
lines{end + 1} = 'Lower RMSE ⇒ the scalar tracks the baseline miss better (global and window subsets).';
lines{end + 1} = '| driver | LOOCV RMSE(ε~1+z) global | LOOCV RMSE(ε~1+z) window |';
lines{end + 1} = '|---|---:|---:|';
for k = 1:height(rowsComp)
    lines{end + 1} = sprintf('| `%s` | %.6g | %.6g |', ...
        rowsComp.driver_id{k}, rowsComp.loocv_rmse_eps_univariate_global(k), ...
        rowsComp.loocv_rmse_eps_univariate_window(k)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '## Full R model: incremental terms (LOOCV)';
lines{end + 1} = 'Fair comparison vs `|alpha_res|` uses **one extra column** beyond the baseline: `|alpha_res|`, or `kappa1^2`, or `spread90_50^2` (curvature along observables already in the linear fit).';
lines{end + 1} = sprintf('- **Baseline LOOCV RMSE:** %.6g', rmseBase);
lines{end + 1} = sprintf('- **Baseline mean |residual| in [%.0f,%.0f] K:** %.6g', Tlo, Thi, maeBaseWin);
lines{end + 1} = '| extended model | LOOCV RMSE(R) | % RMSE vs baseline | mean|res| window | % MAE window vs baseline |';
lines{end + 1} = '|---|---:|---:|---:|---:|';
for k = 1:height(rowExt)
    lines{end + 1} = sprintf('| `%s` | %.6g | %.4g | %.6g | %.4g |', ...
        rowExt.extended_model{k}, rowExt.loocv_rmse_R_extended(k), ...
        rowExt.pct_rmse_improvement_vs_baseline(k), rowExt.mean_abs_res_R_window_extended(k), ...
        rowExt.pct_mae_window_improvement_vs_baseline(k)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '## Temperature list';
lines{end + 1} = sprintf('- `%s`', mat2str(Tplot(:)', 4));
lines{end + 1} = '';
lines{end + 1} = '## Which extension best explains the transition residual?';
lines{end + 1} = 'Among **one** added column beyond the baseline, rank by **% MAE reduction in the 20–26 K window** (primary for local transition fit), then **% global LOOCV RMSE reduction**.';
[~, jRmse] = max(rowExt.pct_rmse_improvement_vs_baseline, [], 'omitnan');
[~, jMae] = max(rowExt.pct_mae_window_improvement_vs_baseline, [], 'omitnan');
lines{end + 1} = sprintf('- **Best window MAE improvement:** `%s` (%.4g%%)', rowExt.extended_model{jMae}, rowExt.pct_mae_window_improvement_vs_baseline(jMae));
lines{end + 1} = sprintf('- **Best global RMSE improvement:** `%s` (%.4g%%)', rowExt.extended_model{jRmse}, rowExt.pct_rmse_improvement_vs_baseline(jRmse));
lines{end + 1} = '';
lines{end + 1} = '## Final verdict';
if modelAresOk
    lines{end + 1} = sprintf('**ALPHA_RES_DRIVES_TRANSITION:** **%s**', char(string(verdict)));
else
    lines{end + 1} = '**ALPHA_RES_DRIVES_TRANSITION:** **NO (alpha_res missing / not finite on overlap)**';
end
lines{end + 1} = '';
lines{end + 1} = '*Interpretation:* **NO** if `kappa1^2` or `spread90_50^2` **strictly beats** `|alpha_res|` on **both** %RMSE and %window-MAE improvements; **YES** if `|alpha_res|` is best on both and improves; **PARTIAL** if `|alpha_res|` helps but does not strictly dominate.';
lines{end + 1} = '';
lines{end + 1} = '*Auto-generated by `analysis/run_transition_driver_comparison.m`.*';

txt = strjoin(lines, newline);
end

function opts = localParseOpts(varargin)
thisPath = mfilename('fullpath');
opts = struct();
opts.repoRoot = fileparts(fileparts(thisPath));
opts.barrierPath = fullfile(opts.repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv');
opts.energyStatsPath = fullfile(opts.repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_24_233256_energy_mapping', 'tables', 'energy_stats.csv');
opts.clockRatioPath = fullfile(opts.repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_14_074613_aging_clock_ratio_analysis', 'tables', 'table_clock_ratio.csv');
opts.alphaStructurePath = fullfile(opts.repoRoot, 'tables', 'alpha_structure.csv');
opts.decompPath = fullfile(opts.repoRoot, 'tables', 'alpha_decomposition.csv');
opts.T_lo = 20;
opts.T_hi = 26;

if mod(numel(varargin), 2) ~= 0
    error('Name-value pairs expected');
end
for k = 1:2:numel(varargin)
    nm = lower(string(varargin{k}));
    val = varargin{k + 1};
    switch nm
        case "reporoot"
            opts.repoRoot = char(string(val));
        case "barrierpath"
            opts.barrierPath = char(string(val));
        case "energystatspath"
            opts.energyStatsPath = char(string(val));
        case "clockratiopath"
            opts.clockRatioPath = char(string(val));
        case "alphastructurepath"
            opts.alphaStructurePath = char(string(val));
        case "decomppath"
            opts.decompPath = char(string(val));
        case "t_lo"
            opts.T_lo = double(val);
        case "t_hi"
            opts.T_hi = double(val);
        otherwise
            error('Unknown option: %s', varargin{k});
    end
end
end
