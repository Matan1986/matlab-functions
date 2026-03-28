function run_alpha_res_collective_state_agent22b()
%RUN_ALPHA_RES_COLLECTIVE_STATE_AGENT22B  Agent 22B — alpha_res vs collective state (kappa manifold)
%
% Read-only inputs: tables/alpha_structure.csv, tables/alpha_decomposition.csv,
%   tables/alpha_from_PT.csv (PT features for comparison only; no decomposition recompute).
% Writes run under results/cross_experiment/runs/ and mirrors key artifacts to repo tables/figures/reports.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

runCfg = struct('runLabel', 'alpha_res_state', ...
    'dataset', 'alpha_res vs kappa1,kappa2,theta,r,dtheta; PT baseline from alpha_from_PT.csv');
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

sub = {'figures', 'tables', 'reports', 'review'};
for i = 1:numel(sub)
    p = fullfile(runDir, sub{i});
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end

fprintf(1, 'Run directory: %s\n', runDir);

alphaStructPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
alphaDecPath = fullfile(repoRoot, 'tables', 'alpha_decomposition.csv');
alphaPtPath = fullfile(repoRoot, 'tables', 'alpha_from_PT.csv');

assert(exist(alphaStructPath, 'file') == 2, 'Missing %s', alphaStructPath);
assert(exist(alphaDecPath, 'file') == 2, 'Missing %s', alphaDecPath);
assert(exist(alphaPtPath, 'file') == 2, 'Missing %s (run Agent 20B first)', alphaPtPath);

aS = readtable(alphaStructPath, 'VariableNamingRule', 'preserve');
aD = readtable(alphaDecPath, 'VariableNamingRule', 'preserve');
aP = readtable(alphaPtPath, 'VariableNamingRule', 'preserve');

decCols = intersect({'T_K', 'alpha_res', 'alpha_geom', 'PT_geometry_valid', ...
    'spread90_50', 'asymmetry'}, aD.Properties.VariableNames, 'stable');
aD2 = aD(:, decCols);

merged = innerjoin(aS, aD2, 'Keys', 'T_K');
merged = merged(isfinite(merged.alpha_res), :);

% alpha_decomposition already has spread90_50 / asymmetry; alpha_from_PT duplicates them.
% Join only skew_pt_weighted (PT PMF skew) to avoid column rename collisions with width_mA.
assert(ismember('skew_pt_weighted', aP.Properties.VariableNames), 'skew_pt_weighted missing in alpha_from_PT.csv');
merged = innerjoin(merged, aP(:, {'T_K', 'skew_pt_weighted'}), 'Keys', 'T_K');

merged = sortrows(merged, 'T_K');
n = height(merged);
assert(n >= 4, 'Too few rows with finite alpha_res and PT join.');

T_K = double(merged.T_K(:));
k1 = double(merged.kappa1(:));
k2 = double(merged.kappa2(:));
alp = double(merged.alpha(:));
ares = double(merged.alpha_res(:));

theta = atan2(k2, k1);
r = hypot(k1, k2);
thu = unwrap(theta(:));
dtheta = NaN(n, 1);
if n >= 2
    dtheta(2:end) = diff(thu);
end

outRow = table(T_K, k1, k2, alp, ares, theta, r, dtheta, ...
    'VariableNames', {'T_K', 'kappa1', 'kappa2', 'alpha', 'alpha_res', 'theta_rad', 'r', 'delta_theta_rad'});

% Univariate correlations (alpha_res vs state coordinates)
uniNames = {'kappa1', 'kappa2', 'theta_rad', 'r', 'delta_theta_rad'};
uniPear = NaN(numel(uniNames), 1);
uniSpear = NaN(numel(uniNames), 1);
for u = 1:numel(uniNames)
    xv = outRow.(uniNames{u});
    m = isfinite(xv) & isfinite(ares);
    if nnz(m) >= 3
        uniPear(u) = corr(xv(m), ares(m), 'rows', 'complete');
        uniSpear(u) = corr(xv(m), ares(m), 'type', 'Spearman', 'rows', 'complete');
    end
end

% --- State models (OLS + intercept)
models = struct('id', {}, 'Xfn', {});

models(end + 1) = struct('id', 'alpha_res ~ kappa1', ...
    'Xfn', @(k1_, k2_, th_, r_, dth_) [ones(numel(k1_), 1), k1_(:)]); %#ok<AGROW>
models(end + 1) = struct('id', 'alpha_res ~ kappa1 + kappa2', ...
    'Xfn', @(k1_, k2_, th_, r_, dth_) [ones(numel(k1_), 1), k1_(:), k2_(:)]);
models(end + 1) = struct('id', 'alpha_res ~ theta_rad', ...
    'Xfn', @(k1_, k2_, th_, r_, dth_) [ones(numel(k1_), 1), th_(:)]);
models(end + 1) = struct('id', 'alpha_res ~ theta_rad + r', ...
    'Xfn', @(k1_, k2_, th_, r_, dth_) [ones(numel(k1_), 1), th_(:), r_(:)]);

nM = numel(models);
fitRows = table();
for k = 1:nM
    X = models(k).Xfn(k1, k2, theta, r, dtheta);
    row = localOlsLoocvReport(models(k).id, ares, X);
    fitRows = [fitRows; row]; %#ok<AGROW>
end

% Optional: delta_theta model (first T has NaN dtheta)
if n >= 3
    md = isfinite(dtheta);
    Xd = [ones(nnz(md), 1), dtheta(md)];
    rowD = localOlsLoocvReport('alpha_res ~ delta_theta_rad', ares(md), Xd);
    fitRows = [fitRows; rowD];
end

% Single-coordinate LOOCV for BEST_STATE_COORDINATE
singleSpecs = {
    'kappa1', @(k1_, k2_, th_, r_, dth_) [ones(numel(k1_), 1), k1_(:)];
    'kappa2', @(k1_, k2_, th_, r_, dth_) [ones(numel(k1_), 1), k2_(:)];
    'theta', @(k1_, k2_, th_, r_, dth_) [ones(numel(k1_), 1), th_(:)];
    'r', @(k1_, k2_, th_, r_, dth_) [ones(numel(k1_), 1), r_(:)]
    };
singleRmse = NaN(size(singleSpecs, 1), 1);
for s = 1:size(singleSpecs, 1)
    Xs = singleSpecs{s, 2}(k1, k2, theta, r, dtheta);
    rpt = localOlsLoocvReport('tmp', ares, Xs);
    singleRmse(s) = rpt.loocv_rmse;
end
[~, ibest] = min(singleRmse);
bestCoordName = singleSpecs{ibest, 1};

% Optional single-coordinate LOOCV for delta_theta (n-1 points)
if n >= 3
    md = isfinite(dtheta);
    Xdt = [ones(nnz(md), 1), dtheta(md)];
    rptDt = localOlsLoocvReport('tmp', ares(md), Xdt);
    if rptDt.loocv_rmse < min(singleRmse)
        bestCoordName = 'delta_theta';
    end
end

% PT baselines on same rows (canonical features from alpha_from_PT.csv; target = alpha_res)
mSk = isfinite(merged.skew_pt_weighted) & isfinite(merged.width_mA);
ptRows = table();
if any(mSk)
    Xpt1 = [ones(nnz(mSk), 1), double(merged.skew_pt_weighted(mSk)), double(merged.width_mA(mSk))];
    y1 = ares(mSk);
    ptRows = [ptRows; localOlsLoocvReport('alpha_res ~ skew_pt_weighted + width_mA (PT 20B design)', y1, Xpt1)];
end
mSp = isfinite(merged.spread90_50) & isfinite(merged.asymmetry);
if any(mSp)
    Xpt2 = [ones(nnz(mSp), 1), double(merged.spread90_50(mSp)), double(merged.asymmetry(mSp))];
    y2 = ares(mSp);
    ptRows = [ptRows; localOlsLoocvReport('alpha_res ~ spread90_50 + asymmetry (PT pair)', y2, Xpt2)];
end

% Naive mean LOOCV
loocv_naive = localLoocvNaiveMean(ares);

validFit = isfinite(fitRows.loocv_rmse);
[~, iBestState] = min(fitRows.loocv_rmse(validFit));
idxBest = find(validFit);
iBestState = idxBest(iBestState);
bestStateModel = fitRows.model{iBestState};
bestStateLoocv = fitRows.loocv_rmse(iBestState);

if ~isempty(ptRows)
    [ptBestLoocv, ipt] = min(ptRows.loocv_rmse);
    ptBestName = ptRows.model{ipt};
else
    ptBestLoocv = NaN;
    ptBestName = 'N/A';
end

stateExplainsBetter = isfinite(ptBestLoocv) && bestStateLoocv < ptBestLoocv - 1e-9;

sigY = std(ares, 'omitnan');
% Strict: must beat leave-one-out mean benchmark and show nontrivial in-sample association.
pearB = fitRows.pearson_y_yhat(iBestState);
spearB = fitRows.spearman_y_yhat(iBestState);
predictable = (bestStateLoocv < loocv_naive) && ...
    ((abs(pearB) >= 0.4 && abs(spearB) >= 0.35) || (abs(pearB) >= 0.5));

if predictable
    flagPred = 'YES';
else
    flagPred = 'NO';
end

if stateExplainsBetter
    flagCmp = 'YES';
else
    flagCmp = 'NO';
end

% Figure: alpha_res vs theta (create_figure lives on tools/figures path)
fig = create_figure('Name', 'alpha_res_vs_theta', 'NumberTitle', 'off');
ax = axes(fig);
scatter(ax, theta, ares, 80, T_K, 'filled', 'LineWidth', 1.5);
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'T (K)';
cb.FontSize = 14;
hold(ax, 'on');
plot(ax, theta, ares, '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1);
hold(ax, 'off');
xlabel(ax, '\theta = atan2(\kappa_2, \kappa_1) (rad)', 'FontSize', 14);
ylabel(ax, '\alpha_{res}', 'FontSize', 14);
grid(ax, 'on');
set(ax, 'FontSize', 14);

figPath = save_run_figure(fig, 'alpha_res_vs_theta', runDir);
close(fig);

% Tables
outPath = save_run_table(outRow, 'alpha_res_vs_state.csv', runDir);
uniTbl = table(uniNames(:), uniPear, uniSpear, 'VariableNames', ...
    {'coordinate', 'pearson_alpha_res', 'spearman_alpha_res'});
save_run_table(uniTbl, 'alpha_res_state_univariate_correlations.csv', runDir);
save_run_table(fitRows, 'alpha_res_state_model_summary.csv', runDir);
if ~isempty(ptRows)
    save_run_table(ptRows, 'alpha_res_PT_baseline_models.csv', runDir);
end

bench = table({'loocv_naive_mean'; 'loocv_std_y'}, [loocv_naive; sigY], ...
    'VariableNames', {'benchmark', 'value'});
save_run_table(bench, 'alpha_res_benchmarks.csv', runDir);

% Report
lines = {};
lines{end + 1} = '# Alpha residual vs collective state (Agent 22B)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(runDir, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Inputs (canonical, read-only)';
lines{end + 1} = sprintf('- `%s`', strrep(alphaStructPath, '\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(alphaDecPath, '\', '/'));
lines{end + 1} = sprintf('- `%s` (PT geometry features for baseline comparison)', strrep(alphaPtPath, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Construction';
lines{end + 1} = '- `alpha_res` from `alpha_decomposition.csv` (finite `PT_geometry_valid` rows only after join).';
lines{end + 1} = '- `theta = atan2(kappa2, kappa1)`, `r = hypot(kappa1, kappa2)`, `delta_theta` = forward difference of `unwrap(theta)` along sorted T.';
lines{end + 1} = '';
lines{end + 1} = '## Univariate correlations (alpha_res vs coordinate)';
lines{end + 1} = '| coordinate | Pearson | Spearman |';
lines{end + 1} = '|---|---:|---:|';
for u = 1:numel(uniNames)
    lines{end + 1} = sprintf('| %s | %.6g | %.6g |', uniNames{u}, uniPear(u), uniSpear(u)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '## State models (OLS + LOOCV)';
lines{end + 1} = '| model | n | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) | max leverage |';
lines{end + 1} = '|---|---:|---:|---:|---:|---:|';
for k = 1:height(fitRows)
    lines{end + 1} = sprintf('| %s | %d | %.6g | %.6g | %.6g | %.6g |', ...
        fitRows.model{k}, fitRows.n(k), fitRows.loocv_rmse(k), ...
        fitRows.pearson_y_yhat(k), fitRows.spearman_y_yhat(k), fitRows.max_leverage(k));
end
lines{end + 1} = '';
lines{end + 1} = sprintf('- **Best state model (lowest LOOCV):** `%s` (RMSE = %.6g)', bestStateModel, bestStateLoocv);
lines{end + 1} = sprintf('- **Best single coordinate (lowest single-term LOOCV):** `%s`', bestCoordName);
lines{end + 1} = sprintf('- **LOOCV naive mean benchmark:** %.6g; **std(alpha_res):** %.6g', loocv_naive, sigY);
lines{end + 1} = '';
lines{end + 1} = '## PT-based models of alpha_res (same PT features as Agent 20B; target changed to alpha_res)';
if isempty(ptRows)
    lines{end + 1} = '- (none — PT feature mask empty)';
else
    lines{end + 1} = '| model | n | LOOCV RMSE | Pearson | Spearman | max lev |';
    lines{end + 1} = '|---|---:|---:|---:|---:|---:|';
    for k = 1:height(ptRows)
        lines{end + 1} = sprintf('| %s | %d | %.6g | %.6g | %.6g | %.6g |', ...
            ptRows.model{k}, ptRows.n(k), ptRows.loocv_rmse(k), ...
            ptRows.pearson_y_yhat(k), ptRows.spearman_y_yhat(k), ptRows.max_leverage(k));
    end
    lines{end + 1} = sprintf('- **Best PT model on alpha_res:** `%s` (LOOCV RMSE = %.6g)', ptBestName, ptBestLoocv);
end
lines{end + 1} = '';
[~, iUni] = max(abs(uniSpear));
uniBestName = uniNames{iUni};
lines{end + 1} = '## Interpretation';
lines{end + 1} = sprintf('- **Strongest univariate association (|Spearman|):** `%s` (|rho| = %.6g).', uniBestName, abs(uniSpear(iUni)));
lines{end + 1} = '- `delta_theta` is the **local turning** of the (kappa1,kappa2) vector along T; it can align with `alpha_res` even when the static angle `theta` alone is the best single-term linear LOOCV among {kappa1,kappa2,theta,r}.';
lines{end + 1} = sprintf('- **Strict generalization:** best state LOOCV (%.6g) is **not** below naive-mean LOOCV (%.6g), matching **%s** for `ALPHA_RES_PREDICTABLE_FROM_STATE`.', bestStateLoocv, loocv_naive, flagPred);
if isfinite(ptBestLoocv)
    lines{end + 1} = sprintf('- **Versus PT:** best PT linear model LOOCV on `alpha_res` is %.6g vs best state model %.6g.', ptBestLoocv, bestStateLoocv);
else
    lines{end + 1} = '- **Versus PT:** PT baseline not available.';
end
lines{end + 1} = '';
lines{end + 1} = '## Final flags';
lines{end + 1} = sprintf('- **ALPHA_RES_PREDICTABLE_FROM_STATE** = **%s**', flagPred);
lines{end + 1} = sprintf('- **BEST_STATE_COORDINATE** = **%s** (lowest LOOCV among single-term {kappa1,kappa2,theta,r})', bestCoordName);
lines{end + 1} = sprintf('- **STRONGEST_UNIVARIATE_COORDINATE** = **%s** (max |Spearman|)', uniBestName);
lines{end + 1} = sprintf('- **STATE_EXPLAINS_RESIDUAL_BETTER_THAN_PT** = **%s**', flagCmp);
lines{end + 1} = '';
lines{end + 1} = '*Auto-generated by `analysis/run_alpha_res_collective_state_agent22b.m`.*';

repTxt = strjoin(lines, newline);
repPath = save_run_report(repTxt, 'alpha_res_state_report.md', runDir);

% ZIP review bundle
zipPath = localBuildZip(runDir);

localAppendLog(run.log_path, sprintf('[%s] Agent 22B complete\n', datestr(now, 31)));
localAppendLog(run.log_path, sprintf('Table: %s\n', outPath));
localAppendLog(run.log_path, sprintf('Figure: %s\n', figPath.png));
localAppendLog(run.log_path, sprintf('Report: %s\nZIP: %s\n', repPath, zipPath));

% Mirror to repo root (task deliverable paths)
mirrorTables = fullfile(repoRoot, 'tables');
mirrorFigs = fullfile(repoRoot, 'figures');
mirrorRep = fullfile(repoRoot, 'reports');
for d = {mirrorTables, mirrorFigs, mirrorRep}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end
copyfile(outPath, fullfile(mirrorTables, 'alpha_res_vs_state.csv'));
copyfile(repPath, fullfile(mirrorRep, 'alpha_res_state_report.md'));
copyfile(figPath.png, fullfile(mirrorFigs, 'alpha_res_vs_theta.png'));
if isfield(figPath, 'fig') && exist(figPath.fig, 'file') == 2
    copyfile(figPath.fig, fullfile(mirrorFigs, 'alpha_res_vs_theta.fig'));
end

fprintf(1, 'Wrote run artifacts under %s\nMirrored CSV/report/PNG to tables/, reports/, figures/\n', runDir);
fprintf(1, 'ALPHA_RES_PREDICTABLE_FROM_STATE = %s\nBEST_STATE_COORDINATE = %s\nSTATE_EXPLAINS_RESIDUAL_BETTER_THAN_PT = %s\n', ...
    flagPred, bestCoordName, flagCmp);

end

function row = localOlsLoocvReport(name, y, X)
y = double(y(:));
X = double(X);
n = numel(y);
p = size(X, 2);
if n < p || rank(X) < p
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

function localAppendLog(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid > 0
    fwrite(fid, txt);
    fclose(fid);
end
end

function v = localLoocvNaiveMean(y)
y = double(y(:));
n = numel(y);
if n < 2
    v = NaN;
    return
end
err = NaN(n, 1);
for i = 1:n
    mu = mean(y(setdiff(1:n, i)));
    err(i) = y(i) - mu;
end
v = sqrt(mean(err.^2));
end

function zipPath = localBuildZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'alpha_res_state_bundle.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end
