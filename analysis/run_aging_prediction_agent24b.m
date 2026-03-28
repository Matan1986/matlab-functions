function run_aging_prediction_agent24b(varargin)
%RUN_AGING_PREDICTION_AGENT24B  Agent 24B — predict aging R(T) from PT + state + trajectory (LOOCV)
%
% Read-only inputs (no PT recompute, no pipeline changes):
%   - Aging clock-ratio table (canonical structured run) for lineage
%   - barrier_descriptors.csv (R_T_interp, quantile PT geometry, pt_svd scores)
%   - energy_stats.csv (mean_E, std_E on aligned T_K grid)
%   - tables/alpha_structure.csv (kappa1, kappa2, alpha)
%   - tables/alpha_decomposition.csv (PT_geometry_valid)
%
% Outputs under results/cross_experiment/runs/<run_id>/ (+ optional mirror):
%   tables/aging_prediction_models.csv
%   tables/aging_prediction_ablation.csv
%   tables/aging_prediction_best_model.csv
%   figures/R_vs_prediction.png|pdf|fig
%   figures/residuals_vs_T.png|pdf|fig
%   reports/aging_prediction_report.md
%
% Name-value: 'repoRoot', 'barrierPath', 'energyStatsPath', 'clockRatioPath',
%             'alphaStructurePath', 'decompPath'

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

set(0, 'DefaultFigureVisible', 'off');

runCfg = struct('runLabel', 'aging_prediction_pt_state_trajectory', ...
    'dataset', 'R(T) LOOCV from PT + kappa state + trajectory (Agent 24B)');
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

for s = ["figures", "tables", "reports", "review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7, mkdir(d); end
end

fprintf(1, 'Agent 24B run directory:\n%s\n', runDir);

appendText(run.log_path, sprintf('[%s] run_aging_prediction_agent24b started\n', datestr(now, 31)));

%% Load inputs
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
bar.asymmetry = double(bar.asym_q75_50_minus_q50_25);

reqB = {'T_K', 'row_valid', 'R_T_interp', 'mean_E', 'std_E', 'spread90_50', 'asymmetry', ...
    'pt_svd_score1', 'pt_svd_score2', 'q90_I_mA', 'q50_I_mA'};
for k = 1:numel(reqB)
    assert(ismember(reqB{k}, bar.Properties.VariableNames), 'barrier_descriptors missing %s', reqB{k});
end

aS = readtable(opts.alphaStructurePath, 'VariableNamingRule', 'preserve');
aD = readtable(opts.decompPath, 'VariableNamingRule', 'preserve');
assert(all(ismember({'T_K', 'kappa1', 'kappa2', 'alpha'}, aS.Properties.VariableNames)), ...
    'alpha_structure missing kappa columns');
assert(all(ismember({'T_K', 'PT_geometry_valid'}, aD.Properties.VariableNames)), ...
    'alpha_decomposition missing PT_geometry_valid');

merged = innerjoin(aS(:, {'T_K', 'kappa1', 'kappa2', 'alpha'}), ...
    aD(:, {'T_K', 'PT_geometry_valid'}), 'Keys', 'T_K');

bCols = intersect(reqB, bar.Properties.VariableNames, 'stable');
merged = innerjoin(merged, bar(:, bCols), 'Keys', 'T_K');

merged = merged(double(merged.PT_geometry_valid) ~= 0, :);
merged = merged(double(merged.row_valid) ~= 0, :);
merged = sortrows(merged, 'T_K');

T_K = double(merged.T_K(:));
R = double(merged.R_T_interp(:));
k1 = double(merged.kappa1(:));
k2 = double(merged.kappa2(:));
alp = double(merged.alpha(:));
mean_E = double(merged.mean_E(:));
std_E = double(merged.std_E(:));
spread90_50 = double(merged.spread90_50(:));
asym = double(merged.asymmetry(:));
pt1 = double(merged.pt_svd_score1(:));
pt2 = double(merged.pt_svd_score2(:));
theta = atan2(k2, k1);
r = hypot(k1, k2);

n0 = numel(T_K);
thu = unwrap(theta(:));
dtheta = nan(n0, 1);
dk1 = nan(n0, 1);
dk2 = nan(n0, 1);
dT = nan(n0, 1);
ds = nan(n0, 1);
kappa_curve = nan(n0, 1);
if n0 >= 2
    dtheta(2:end) = diff(thu);
    dk1(2:end) = diff(k1);
    dk2(2:end) = diff(k2);
    dT(2:end) = diff(T_K);
    ds(2:end) = sqrt(dk1(2:end).^2 + dk2(2:end).^2);
    kappa_curve(2:end) = abs(dtheta(2:end)) ./ max(dT(2:end), eps);
end
abs_dtheta = abs(dtheta);

% NOTE: column r_kappa = hypot(kappa1,kappa2); avoids R/r case clash in some CSV tools.
master = table(T_K, R, mean_E, std_E, spread90_50, asym, pt1, pt2, k1, k2, alp, theta, r, ...
    abs_dtheta, ds, kappa_curve, ...
    'VariableNames', {'T_K', 'R', 'mean_E', 'std_E', 'spread90_50', 'asymmetry', ...
    'pt_svd_score1', 'pt_svd_score2', 'kappa1', 'kappa2', 'alpha', 'theta_rad', 'r_kappa', ...
    'abs_delta_theta', 'ds', 'curvature_dtheta_over_dT'});

mBase = isfinite(R) & isfinite(mean_E) & isfinite(spread90_50) & isfinite(k1) & isfinite(k2) ...
    & isfinite(theta) & isfinite(r) & isfinite(pt1) & isfinite(pt2) & isfinite(asym) & isfinite(std_E);
mTraj = mBase & isfinite(abs_dtheta) & isfinite(ds) & isfinite(kappa_curve);
assert(nnz(mTraj) >= 5, 'Agent24B: insufficient rows with full PT+state+trajectory overlap (n=%d).', nnz(mTraj));

masterOut = master(mTraj, :);
save_run_table(masterOut, 'aging_prediction_master_table.csv', runDir);

%% ----- Models (max 3 predictors + intercept; evaluated on mTraj only) -----
y = R(mTraj);
Tplot = T_K(mTraj);
n = numel(y);

pred = struct('id', {}, 'category', {}, 'cols', {});

pred(end + 1) = struct('id', 'R ~ 1', 'category', 'baseline', 'cols', {{}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ mean_E', 'category', 'PT-only', 'cols', {{'mean_E'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50', 'category', 'PT-only', 'cols', {{'spread90_50'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ mean_E + spread90_50', 'category', 'PT-only', 'cols', {{'mean_E', 'spread90_50'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ kappa1', 'category', 'state-only', 'cols', {{'kappa1'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ r', 'category', 'state-only', 'cols', {{'r_kappa'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ theta_rad', 'category', 'state-only', 'cols', {{'theta_rad'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ abs_delta_theta', 'category', 'trajectory-only', 'cols', {{'abs_delta_theta'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ ds', 'category', 'trajectory-only', 'cols', {{'ds'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ mean_E + kappa1', 'category', 'PT+state', 'cols', {{'mean_E', 'kappa1'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1', 'category', 'PT+state', 'cols', {{'spread90_50', 'kappa1'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ mean_E + kappa1 + abs_delta_theta', 'category', 'PT+state+trajectory', ...
    'cols', {{'mean_E', 'kappa1', 'abs_delta_theta'}}); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ spread90_50 + kappa1 + ds', 'category', 'PT+state+trajectory', ...
    'cols', {{'spread90_50', 'kappa1', 'ds'}}); %#ok<AGROW>

rows = table();
bestRmse = inf;
bestRow = table();
bestYhat = nan(n, 1);

for k = 1:numel(pred)
    if isempty(pred(k).cols)
        [rmse, rP, rS, yhat] = localLoocvMean(y);
    else
        X = zeros(n, numel(pred(k).cols));
        ok = true(n, 1);
        for c = 1:numel(pred(k).cols)
            v = masterOut.(pred(k).cols{c});
            X(:, c) = v(:);
            ok = ok & isfinite(X(:, c));
        end
        if ~all(ok)
            rmse = NaN; rP = NaN; rS = NaN; yhat = nan(n, 1);
        else
            [rmse, rP, rS, yhat] = localLoocvOls(y, X);
        end
    end
    rows = [rows; table({pred(k).id}, {pred(k).category}, n, rmse, rP, rS, ...
        'VariableNames', {'model', 'category', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat'})]; %#ok<AGROW>
    if isfinite(rmse) && rmse < bestRmse && ~strcmp(pred(k).category, 'baseline')
        bestRmse = rmse;
        bestRow = rows(end, :);
        bestYhat = yhat;
    end
end

save_run_table(rows, 'aging_prediction_models.csv', runDir);

%% Baseline RMSE (same n)
idxBase = strcmp(rows.model, 'R ~ 1');
rmseBase = rows.loocv_rmse(find(idxBase, 1));

%% Category ablation (best per category)
cats = unique({pred.category}, 'stable');
abr = table();
for i = 1:numel(cats)
    msk = strcmp(rows.category, cats{i});
    sub = rows(msk, :);
    [mn, j] = min(sub.loocv_rmse, [], 'omitnan');
    if ~isfinite(mn)
        abr = [abr; table(string(cats{i}), NaN, NaN, NaN, NaN, ...
            'VariableNames', {'model_family', 'best_model', 'loocv_rmse', 'pearson', 'spearman', 'delta_rmse_vs_baseline'})]; %#ok<AGROW>
    else
        r = sub(j, :);
        abr = [abr; table(string(cats{i}), string(r.model), r.loocv_rmse, r.pearson_y_yhat, r.spearman_y_yhat, ...
            r.loocv_rmse - rmseBase, 'VariableNames', ...
            {'model_family', 'best_model', 'loocv_rmse', 'pearson', 'spearman', 'delta_rmse_vs_baseline'})]; %#ok<AGROW>
    end
end
save_run_table(abr, 'aging_prediction_ablation.csv', runDir);

%% Best model row
if isempty(bestRow) || ~isfinite(bestRmse)
    error('Agent24B: no valid best model.');
end
verd = localVerdicts(rows, abr, rmseBase, y);
bestTbl = table(string(bestRow.model), bestRow.loocv_rmse, bestRow.pearson_y_yhat, bestRow.spearman_y_yhat, ...
    string(verd.AGING_PREDICTED_FROM_PT), string(verd.STATE_REQUIRED_FOR_AGING), ...
    string(verd.TRAJECTORY_ADDS_INFORMATION), string(verd.FULL_CLOSURE_ACHIEVED), ...
    'VariableNames', {'best_model_loocv', 'loocv_rmse', 'pearson_loocv_yhat', 'spearman_loocv_yhat', ...
    'AGING_PREDICTED_FROM_PT', 'STATE_REQUIRED_FOR_AGING', 'TRAJECTORY_ADDS_INFORMATION', 'FULL_CLOSURE_ACHIEVED'});
save_run_table(bestTbl, 'aging_prediction_best_model.csv', runDir);

%% Figures (Name == file base)
fig1 = create_figure('Name', 'R_vs_prediction', 'NumberTitle', 'off');
ax = axes(fig1);
scatter(ax, y, bestYhat, 90, Tplot, 'filled', 'LineWidth', 1.5);
hold(ax, 'on');
lim = [min([y; bestYhat], [], 'omitnan'), max([y; bestYhat], [], 'omitnan')];
if isfinite(lim(1)) && isfinite(lim(2)) && lim(2) > lim(1)
    plot(ax, lim, lim, 'k--', 'LineWidth', 2);
end
hold(ax, 'off');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'T (K)';
grid(ax, 'on');
xlabel(ax, 'R measured (clock ratio, interp)', 'FontSize', 14);
ylabel(ax, 'R LOOCV prediction (best model)', 'FontSize', 14);
set(ax, 'FontSize', 14);
figPath1 = save_run_figure(fig1, 'R_vs_prediction', runDir);
close(fig1);

res = y - bestYhat;
fig2 = create_figure('Name', 'residuals_vs_T', 'NumberTitle', 'off');
ax2 = axes(fig2);
plot(ax2, Tplot, res, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.45 0.7]);
hold(ax2, 'on');
yline(ax2, 0, 'k--', 'LineWidth', 1.5);
xl = [22, 24];
yr = max(abs(res), [], 'omitnan');
if ~isfinite(yr) || yr <= 0, yr = 1; end
patch(ax2, [xl(1) xl(2) xl(2) xl(1)], yr * [1 1 -1 -1], [1 0.85 0.85], ...
    'FaceAlpha', 0.35, 'EdgeColor', 'none');
hold(ax2, 'off');
xlabel(ax2, 'T (K)', 'FontSize', 14);
ylabel(ax2, 'Residual R (meas - LOOCV pred)', 'FontSize', 14);
grid(ax2, 'on');
set(ax2, 'FontSize', 14);
figPath2 = save_run_figure(fig2, 'residuals_vs_T', runDir);
close(fig2);

%% Report
mae22 = mean(abs(res(Tplot >= 22 & Tplot <= 24)), 'omitnan');
maeOther = mean(abs(res(~(Tplot >= 22 & Tplot <= 24))), 'omitnan');
rep = localBuildReport(runDir, opts, masterOut, rows, abr, bestTbl, verd, ...
    mae22, maeOther, Tplot, res, figPath1, figPath2, clkPath);
save_run_report(rep, 'aging_prediction_report.md', runDir);

%% ZIP + mirror
zipPath = localBuildZip(runDir);
appendText(run.log_path, sprintf('[%s] complete; zip=%s\n', datestr(now, 31), zipPath));

mirrorTables = fullfile(repoRoot, 'tables');
mirrorFigs = fullfile(repoRoot, 'figures');
mirrorRep = fullfile(repoRoot, 'reports');
for d = {mirrorTables, mirrorFigs, mirrorRep}
    if exist(d{1}, 'dir') ~= 7, mkdir(d{1}); end
end
try
    copyfile(fullfile(runDir, 'tables', 'aging_prediction_models.csv'), fullfile(mirrorTables, 'aging_prediction_models.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_prediction_ablation.csv'), fullfile(mirrorTables, 'aging_prediction_ablation.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_prediction_best_model.csv'), fullfile(mirrorTables, 'aging_prediction_best_model.csv'));
    copyfile(fullfile(runDir, 'reports', 'aging_prediction_report.md'), fullfile(mirrorRep, 'aging_prediction_report.md'));
    copyfile(figPath1.png, fullfile(mirrorFigs, 'R_vs_prediction.png'));
    copyfile(figPath2.png, fullfile(mirrorFigs, 'residuals_vs_T.png'));
catch ME
    fprintf(2, 'Mirror copy skipped: %s\n', ME.message);
end

fprintf(1, 'Agent 24B complete. Report: %s\n', fullfile(runDir, 'reports', 'aging_prediction_report.md'));
end

%% ------------------------------------------------------------------------
function [rmse, rP, rS, yhat] = localLoocvMean(y)
y = double(y(:));
n = numel(y);
yhat = nan(n, 1);
if n < 2
    rmse = NaN; rP = NaN; rS = NaN; return
end
for i = 1:n
    yhat(i) = mean(y(setdiff(1:n, i)));
end
rmse = sqrt(mean((y - yhat).^2));
rP = corr(y, yhat, 'rows', 'complete');
rS = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
end

function [rmse, rP, rS, yhat] = localLoocvOls(y, X)
y = double(y(:));
X = double(X);
n = numel(y);
p = size(X, 2);
yhat = nan(n, 1);
rmse = NaN;
rP = NaN;
rS = NaN;
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
rS = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
end

function v = localVerdicts(rows, abr, rmseBase, y)
v = struct();
sigy = std(y, 'omitnan');

rmsePT = localAblationRmse(abr, "PT-only");
rmsePS = localAblationRmse(abr, "PT+state");
rmsePST = localAblationRmse(abr, "PT+state+trajectory");

% AGING_PREDICTED_FROM_PT
if isfinite(rmsePT) && rmsePT < rmseBase * 0.92 && abs(localGetPearsonFamily(rows, 'PT-only')) > 0.45
    v.AGING_PREDICTED_FROM_PT = "YES";
elseif isfinite(rmsePT) && (rmsePT < rmseBase || abs(localGetPearsonFamily(rows, 'PT-only')) > 0.3)
    v.AGING_PREDICTED_FROM_PT = "PARTIAL";
else
    v.AGING_PREDICTED_FROM_PT = "NO";
end

% STATE_REQUIRED
improvePS = (rmsePT - rmsePS) / max(rmsePT, eps);
if isfinite(rmsePS) && isfinite(rmsePT) && rmsePS < rmsePT * (1 - 0.03) && improvePS > 0.02
    v.STATE_REQUIRED_FOR_AGING = "YES";
else
    v.STATE_REQUIRED_FOR_AGING = "NO";
end

% TRAJECTORY_ADDS
if isfinite(rmsePST) && isfinite(rmsePS) && rmsePST < rmsePS - 1e-9
    v.TRAJECTORY_ADDS_INFORMATION = "YES";
else
    v.TRAJECTORY_ADDS_INFORMATION = "NO";
end

% FULL_CLOSURE (best non-baseline LOOCV RMSE vs total variability of R)
mskNonBase = ~strcmp(rows.model, 'R ~ 1');
bestAll = min(rows.loocv_rmse(mskNonBase), [], 'omitnan');
if bestAll < 0.2 * sigy
    v.FULL_CLOSURE_ACHIEVED = "YES";
elseif bestAll < 0.45 * sigy
    v.FULL_CLOSURE_ACHIEVED = "PARTIAL";
else
    v.FULL_CLOSURE_ACHIEVED = "NO";
end
end

function rm = localAblationRmse(abr, fam)
sub = abr(strcmp(abr.model_family, char(fam)), :);
if isempty(sub) || ~isfinite(sub.loocv_rmse(1))
    rm = NaN;
else
    rm = sub.loocv_rmse(1);
end
end

function p = localGetPearsonFamily(rows, fam)
r = rows(strcmp(rows.category, fam), :);
if isempty(r)
    p = NaN; return
end
[~, j] = min(r.loocv_rmse, [], 'omitnan');
p = r.pearson_y_yhat(j);
end

function txt = localBuildReport(runDir, opts, masterOut, rows, abr, bestTbl, verd, ...
    mae22, maeOther, Tplot, res, figPath1, figPath2, clkPath)

lines = {};
lines{end + 1} = '# Aging prediction from PT + state + trajectory (Agent 24B)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(runDir, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Data lineage (read-only)';
lines{end + 1} = sprintf('- **R(T):** `R_T_interp` from barrier merge (interpolation of sparse aging clock to the PT grid). Raw clock table: `%s`', ...
    strrep(clkPath, '\', '/'));
lines{end + 1} = sprintf('- **PT / quantiles / SVD:** `%s`', strrep(opts.barrierPath, '\', '/'));
lines{end + 1} = sprintf('- **mean_E / std_E:** `%s`', strrep(opts.energyStatsPath, '\', '/'));
lines{end + 1} = sprintf('- **State (kappa1, kappa2, alpha):** `%s` + geometry gate `%s`', ...
    strrep(opts.alphaStructurePath, '\', '/'), strrep(opts.decompPath, '\', '/'));
lines{end + 1} = '- **Trajectory:** forward differences along sorted `T_K` (`abs_delta_theta` on unwrapped θ, `ds` in (κ1,κ2), `curvature` = |Δθ|/ΔT).';
lines{end + 1} = '';
lines{end + 1} = sprintf('## Overlap rows (n = %d)', height(masterOut));
lines{end + 1} = 'All models use the same temperature rows: full PT + state + trajectory features finite (first temperature omits Δ by construction).';
lines{end + 1} = '';
lines{end + 1} = '## LOOCV models';
lines{end + 1} = '| model | family | n | LOOCV RMSE | Pearson | Spearman |';
lines{end + 1} = '|---|---|---:|---:|---:|---:|';
for k = 1:height(rows)
    lines{end + 1} = sprintf('| %s | %s | %d | %.6g | %.6g | %.6g |', ...
        rows.model{k}, rows.category{k}, rows.n(k), rows.loocv_rmse(k), ...
        rows.pearson_y_yhat(k), rows.spearman_y_yhat(k)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '## Ablation (best per family, ΔRMSE vs LOOCV mean baseline)';
lines{end + 1} = '| family | best model | LOOCV RMSE | Pearson | Spearman | ΔRMSE vs baseline |';
lines{end + 1} = '|---|---|---:|---:|---:|---:|';
for k = 1:height(abr)
    lines{end + 1} = sprintf('| %s | %s | %.6g | %.6g | %.6g | %.6g |', ...
        abr.model_family(k), abr.best_model(k), abr.loocv_rmse(k), abr.pearson(k), ...
        abr.spearman(k), abr.delta_rmse_vs_baseline(k)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '## Best LOOCV model';
lines{end + 1} = sprintf('- **Model:** `%s`', char(bestTbl.best_model_loocv(1)));
lines{end + 1} = sprintf('- **LOOCV RMSE:** %.6g; **Pearson:** %.6g; **Spearman:** %.6g', ...
    bestTbl.loocv_rmse(1), bestTbl.pearson_loocv_yhat(1), bestTbl.spearman_loocv_yhat(1));
lines{end + 1} = '';
lines{end + 1} = '## Temperature-local errors';
lines{end + 1} = sprintf('- Mean |residual| for **22–24 K:** %.6g; other T in fit: %.6g', mae22, maeOther);
lines{end + 1} = sprintf('- Residuals by T: `%s`', mat2str(res(:)', 4));
lines{end + 1} = sprintf('- T grid: `%s`', mat2str(Tplot(:)', 4));
lines{end + 1} = '';
lines{end + 1} = '## Figures';
lines{end + 1} = sprintf('- `%s`', strrep(figPath1.png, '\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(figPath2.png, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Mandatory verdicts';
lines{end + 1} = sprintf('- **AGING_PREDICTED_FROM_PT:** **%s**', char(verd.AGING_PREDICTED_FROM_PT));
lines{end + 1} = sprintf('- **STATE_REQUIRED_FOR_AGING:** **%s**', char(verd.STATE_REQUIRED_FOR_AGING));
lines{end + 1} = sprintf('- **TRAJECTORY_ADDS_INFORMATION:** **%s**', char(verd.TRAJECTORY_ADDS_INFORMATION));
lines{end + 1} = sprintf('- **FULL_CLOSURE_ACHIEVED:** **%s**', char(verd.FULL_CLOSURE_ACHIEVED));
lines{end + 1} = '';
lines{end + 1} = '## Interpretation';
lines{end + 1} = 'If PT + state + trajectory perform strongly (low LOOCV RMSE, high correlation), aging clock ratio is consistent with barrier geometry, collective kappa state, and the path of state evolution (memory / reorganization dynamics).';
lines{end + 1} = '';
lines{end + 1} = '*Auto-generated by `analysis/run_aging_prediction_agent24b.m`.*';

txt = strjoin(lines, newline);
end

function zipPath = localBuildZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7, mkdir(reviewDir); end
zipPath = fullfile(reviewDir, 'aging_prediction_agent24b_bundle.zip');
if exist(zipPath, 'file') == 2, delete(zipPath); end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid > 0, fwrite(fid, txt); fclose(fid); end
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
        otherwise
            error('Unknown option: %s', varargin{k});
    end
end
end
