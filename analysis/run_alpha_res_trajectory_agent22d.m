function run_alpha_res_trajectory_agent22d()
%RUN_ALPHA_RES_TRAJECTORY_AGENT22D  Agent 22D — α_res vs κ trajectory (derivatives / curvature)
%
% Tests whether alpha_res aligns with trajectory dynamics (Δθ, curvature, arc length)
% rather than static state alone.
%
% Inputs (read-only): tables/alpha_structure.csv, tables/alpha_decomposition.csv
% Outputs: tables/alpha_res_vs_trajectory.csv, figures/alpha_res_vs_delta_theta.png,
%   reports/alpha_res_trajectory_report.md (+ run bundle under results/cross_experiment/runs/)
%
% If batch MATLAB cannot render figures, use tools/build_alpha_res_trajectory_outputs.ps1
% for the same tables/figures/report (smoothing may differ slightly from SG).

set(0, 'DefaultFigureVisible', 'off');

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

runCfg = struct('runLabel', 'alpha_res_trajectory', ...
    'dataset', 'alpha_res vs delta_theta, curvature, ds; state baseline for comparison');
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

assert(exist(alphaStructPath, 'file') == 2, 'Missing %s', alphaStructPath);
assert(exist(alphaDecPath, 'file') == 2, 'Missing %s', alphaDecPath);

aS = readtable(alphaStructPath, 'VariableNamingRule', 'preserve');
aD = readtable(alphaDecPath, 'VariableNamingRule', 'preserve');

decCols = intersect({'T_K', 'alpha_res', 'PT_geometry_valid'}, ...
    aD.Properties.VariableNames, 'stable');
aD2 = aD(:, decCols);

merged = innerjoin(aS, aD2, 'Keys', 'T_K');
merged = merged(isfinite(merged.alpha_res), :);
merged = sortrows(merged, 'T_K');
n = height(merged);
assert(n >= 4, 'Too few rows with finite alpha_res.');

T_K = double(merged.T_K(:));
k1 = double(merged.kappa1(:));
k2 = double(merged.kappa2(:));
ares = double(merged.alpha_res(:));

theta = atan2(k2, k1);
r = hypot(k1, k2);
thu = unwrap(theta(:));

dtheta = NaN(n, 1);
dk1 = NaN(n, 1);
dk2 = NaN(n, 1);
dT = NaN(n, 1);
if n >= 2
    dtheta(2:end) = diff(thu);
    dk1(2:end) = diff(k1);
    dk2(2:end) = diff(k2);
    dT(2:end) = diff(T_K);
end

ds = NaN(n, 1);
kappa_curve = NaN(n, 1);
if n >= 2
    ds(2:end) = sqrt(dk1(2:end).^2 + dk2(2:end).^2);
    kappa_curve(2:end) = abs(dtheta(2:end)) ./ max(dT(2:end), eps);
end

ths = localSmoothAngle(thu, n);
dtheta_sm = NaN(n, 1);
if n >= 2
    dtheta_sm(2:end) = diff(ths);
end

outRow = table(T_K, k1, k2, ares, theta, r, thu, dtheta, ths, dtheta_sm, ...
    kappa_curve, ds, dT, ...
    'VariableNames', {'T_K', 'kappa1', 'kappa2', 'alpha_res', 'theta_rad', 'r', ...
    'theta_unwrapped_rad', 'delta_theta_rad', 'theta_smoothed_unwrapped_rad', ...
    'delta_theta_smoothed_rad', 'kappa_curve', 'ds_step', 'delta_T_K'});

% --- Univariate correlations (trajectory features)
featNames = {'delta_theta_rad', 'delta_theta_smoothed_rad', 'kappa_curve', 'ds_step'};
uniPear = NaN(numel(featNames), 1);
uniSpear = NaN(numel(featNames), 1);
for u = 1:numel(featNames)
    xv = outRow.(featNames{u});
    m = isfinite(xv) & isfinite(ares);
    if nnz(m) >= 3
        uniPear(u) = corr(xv(m), ares(m), 'rows', 'complete');
        uniSpear(u) = corr(xv(m), ares(m), 'type', 'Spearman', 'rows', 'complete');
    end
end

% --- Trajectory models
trajModels = struct('id', {}, 'Xfn', {});
trajModels(end + 1) = struct('id', 'alpha_res ~ delta_theta_rad', ...
    'Xfn', @(dth, dths, kc, ds_, n_) localMaskCols([ones(n_, 1), dth], isfinite(dth)));
trajModels(end + 1) = struct('id', 'alpha_res ~ delta_theta_smoothed_rad', ...
    'Xfn', @(dth, dths, kc, ds_, n_) localMaskCols([ones(n_, 1), dths], isfinite(dths)));
trajModels(end + 1) = struct('id', 'alpha_res ~ kappa_curve', ...
    'Xfn', @(dth, dths, kc, ds_, n_) localMaskCols([ones(n_, 1), kc], isfinite(kc)));
trajModels(end + 1) = struct('id', 'alpha_res ~ ds_step', ...
    'Xfn', @(dth, dths, kc, ds_, n_) localMaskCols([ones(n_, 1), ds_], isfinite(ds_)));
trajModels(end + 1) = struct('id', 'alpha_res ~ delta_theta_rad + ds_step', ...
    'Xfn', @(dth, dths, kc, ds_, n_) localMaskCols([ones(n_, 1), dth, ds_], ...
    isfinite(dth) & isfinite(ds_)));

fitTraj = table();
nTM = numel(trajModels);
for k = 1:nTM
    Xfull = trajModels(k).Xfn(dtheta, dtheta_sm, kappa_curve, ds, n);
    row = localOlsLoocvReport(trajModels(k).id, ares(Xfull.m), Xfull.X);
    fitTraj = [fitTraj; row]; %#ok<AGROW>
end

% --- State models (static manifold; beat benchmark for TRAJECTORY_BEATS_STATE)
stateModels = struct('id', {}, 'Xfn', {});
stateModels(end + 1) = struct('id', 'alpha_res ~ kappa1', ...
    'Xfn', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), k1_(:)]);
stateModels(end + 1) = struct('id', 'alpha_res ~ kappa2', ...
    'Xfn', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), k2_(:)]);
stateModels(end + 1) = struct('id', 'alpha_res ~ theta_rad', ...
    'Xfn', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), th_(:)]);
stateModels(end + 1) = struct('id', 'alpha_res ~ r', ...
    'Xfn', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), r_(:)]);
stateModels(end + 1) = struct('id', 'alpha_res ~ theta_rad + r', ...
    'Xfn', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), th_(:), r_(:)]);

fitState = table();
for k = 1:numel(stateModels)
    X = stateModels(k).Xfn(k1, k2, theta, r);
    fitState = [fitState; localOlsLoocvReport(stateModels(k).id, ares, X)]; %#ok<AGROW>
end

loocv_naive = localLoocvNaiveMean(ares);
sigY = std(ares, 'omitnan');

validT = isfinite(fitTraj.loocv_rmse);
[~, iBestT] = min(fitTraj.loocv_rmse(validT));
idxT = find(validT);
iBestT = idxT(iBestT);
bestTrajModel = fitTraj.model{iBestT};
bestTrajLoocv = fitTraj.loocv_rmse(iBestT);
pearT = fitTraj.pearson_y_yhat(iBestT);
spearT = fitTraj.spearman_y_yhat(iBestT);

% Best univariate trajectory feature (first four models)
featShort = {'delta_theta_rad', 'delta_theta_smoothed_rad', 'kappa_curve', 'ds_step'};
fitUni = fitTraj(1:min(4, height(fitTraj)), :);
vu = isfinite(fitUni.loocv_rmse);
if any(vu)
    [~, j] = min(fitUni.loocv_rmse(vu));
    idxU = find(vu);
    bestFeat = featShort{idxU(j)};
else
    bestFeat = 'none';
end

validS = isfinite(fitState.loocv_rmse);
[~, iBestS] = min(fitState.loocv_rmse(validS));
idxS = find(validS);
iBestS = idxS(iBestS);
bestStateModel = fitState.model{iBestS};
bestStateLoocv = fitState.loocv_rmse(iBestS);

% Flags
trajectoryBeatsState = isfinite(bestTrajLoocv) && isfinite(bestStateLoocv) && ...
    bestTrajLoocv < bestStateLoocv - 1e-12;

predictableTraj = (bestTrajLoocv < loocv_naive) && ...
    ((abs(pearT) >= 0.35 && abs(spearT) >= 0.3) || (abs(pearT) >= 0.45));

if predictableTraj
    flagDep = 'YES';
else
    flagDep = 'NO';
end

if trajectoryBeatsState
    flagBeats = 'YES';
else
    flagBeats = 'NO';
end

% --- Figure
fig = create_figure('Name', 'alpha_res_vs_delta_theta', 'NumberTitle', 'off');
ax = axes(fig);
scatter(ax, dtheta, ares, 80, T_K, 'filled', 'LineWidth', 1.5);
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'T (K)';
cb.FontSize = 14;
hold(ax, 'on');
ord = isfinite(dtheta) & isfinite(ares);
plot(ax, dtheta(ord), ares(ord), '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1);
hold(ax, 'off');
xlabel(ax, '\Delta\theta (rad, forward diff on unwrapped \theta)', 'FontSize', 14);
ylabel(ax, '\alpha_{res}', 'FontSize', 14);
grid(ax, 'on');
set(ax, 'FontSize', 14);

figPath = save_run_figure(fig, 'alpha_res_vs_delta_theta', runDir);
close(fig);

outPath = save_run_table(outRow, 'alpha_res_vs_trajectory.csv', runDir);
uniTbl = table(featNames(:), uniPear, uniSpear, 'VariableNames', ...
    {'trajectory_feature', 'pearson_alpha_res', 'spearman_alpha_res'});
save_run_table(uniTbl, 'alpha_res_trajectory_univariate_correlations.csv', runDir);
save_run_table(fitTraj, 'alpha_res_trajectory_model_summary.csv', runDir);
save_run_table(fitState, 'alpha_res_trajectory_state_baseline_models.csv', runDir);

bench = table({'loocv_naive_mean'; 'loocv_std_y'; 'best_state_loocv'; 'best_trajectory_loocv'}, ...
    [loocv_naive; sigY; bestStateLoocv; bestTrajLoocv], ...
    'VariableNames', {'benchmark', 'value'});
save_run_table(bench, 'alpha_res_trajectory_benchmarks.csv', runDir);

% --- Report
lines = {};
lines{end + 1} = '# Alpha residual vs κ trajectory (Agent 22D)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(runDir, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Inputs';
lines{end + 1} = sprintf('- `%s`', strrep(alphaStructPath, '\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(alphaDecPath, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Trajectory construction';
lines{end + 1} = '- `theta = atan2(kappa2, kappa1)`, `r = hypot(kappa1, kappa2)`, unwrapped along sorted `T_K`.';
lines{end + 1} = '- `delta_theta_rad`: forward difference of unwrapped θ.';
lines{end + 1} = '- `theta_smoothed_unwrapped_rad`: Savitzky–Golay (or moving average fallback) on unwrapped θ; window = odd, ≤ n.';
lines{end + 1} = '- `delta_theta_smoothed_rad`: forward difference of smoothed unwrapped θ.';
lines{end + 1} = '- `kappa_curve`: |Δθ| / ΔT (rad/K) at each T (NaN on first row).';
lines{end + 1} = '- `ds_step`: Euclidean step in (κ1, κ2) between successive T.';
lines{end + 1} = '';
lines{end + 1} = '## Univariate correlations (α_res vs trajectory feature)';
lines{end + 1} = '| feature | Pearson | Spearman |';
lines{end + 1} = '|---|---:|---:|';
for u = 1:numel(featNames)
    lines{end + 1} = sprintf('| %s | %.6g | %.6g |', featNames{u}, uniPear(u), uniSpear(u)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '## Trajectory models (OLS + LOOCV)';
lines{end + 1} = '| model | n | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) | max leverage |';
lines{end + 1} = '|---|---:|---:|---:|---:|---:|';
for k = 1:height(fitTraj)
    lines{end + 1} = sprintf('| %s | %d | %.6g | %.6g | %.6g | %.6g |', ...
        fitTraj.model{k}, fitTraj.n(k), fitTraj.loocv_rmse(k), ...
        fitTraj.pearson_y_yhat(k), fitTraj.spearman_y_yhat(k), fitTraj.max_leverage(k));
end
lines{end + 1} = '';
lines{end + 1} = '## State baseline (same rows; for TRAJECTORY_BEATS_STATE)';
lines{end + 1} = '| model | n | LOOCV RMSE | Pearson | Spearman |';
lines{end + 1} = '|---|---:|---:|---:|---:|';
for k = 1:height(fitState)
    lines{end + 1} = sprintf('| %s | %d | %.6g | %.6g | %.6g |', ...
        fitState.model{k}, fitState.n(k), fitState.loocv_rmse(k), ...
        fitState.pearson_y_yhat(k), fitState.spearman_y_yhat(k));
end
lines{end + 1} = '';
lines{end + 1} = sprintf('- **Best trajectory model:** `%s` (LOOCV RMSE = %.6g)', bestTrajModel, bestTrajLoocv);
lines{end + 1} = sprintf('- **Best static-state model (same n):** `%s` (LOOCV RMSE = %.6g)', bestStateModel, bestStateLoocv);
lines{end + 1} = sprintf('- **LOOCV naive mean:** %.6g; **std(α_res):** %.6g', loocv_naive, sigY);
lines{end + 1} = '';
lines{end + 1} = '## Final flags';
lines{end + 1} = sprintf('- **ALPHA_RES_DEPENDS_ON_TRAJECTORY** = **%s** (best trajectory model beats naive LOOCV + association)', flagDep);
lines{end + 1} = sprintf('- **BEST_TRAJECTORY_FEATURE** = **%s** (lowest LOOCV among univariate Δθ, Δθ_sm, κ_curve, ds)', bestFeat);
lines{end + 1} = sprintf('- **Best overall trajectory model (incl. joint):** `%s`', bestTrajModel);
lines{end + 1} = sprintf('- **TRAJECTORY_BEATS_STATE** = **%s** (best trajectory LOOCV < best static-state LOOCV)', flagBeats);
lines{end + 1} = '';
lines{end + 1} = '*Auto-generated by `analysis/run_alpha_res_trajectory_agent22d.m`.*';

repTxt = strjoin(lines, newline);
repPath = save_run_report(repTxt, 'alpha_res_trajectory_report.md', runDir);

zipPath = localBuildZip(runDir);

localAppendLog(run.log_path, sprintf('[%s] Agent 22D complete\n', datestr(now, 31)));
localAppendLog(run.log_path, sprintf('Table: %s\n', outPath));
localAppendLog(run.log_path, sprintf('Figure: %s\n', figPath.png));
localAppendLog(run.log_path, sprintf('Report: %s\nZIP: %s\n', repPath, zipPath));

mirrorTables = fullfile(repoRoot, 'tables');
mirrorFigs = fullfile(repoRoot, 'figures');
mirrorRep = fullfile(repoRoot, 'reports');
for d = {mirrorTables, mirrorFigs, mirrorRep}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end
copyfile(outPath, fullfile(mirrorTables, 'alpha_res_vs_trajectory.csv'));
copyfile(repPath, fullfile(mirrorRep, 'alpha_res_trajectory_report.md'));
copyfile(figPath.png, fullfile(mirrorFigs, 'alpha_res_vs_delta_theta.png'));
if isfield(figPath, 'fig') && exist(figPath.fig, 'file') == 2
    copyfile(figPath.fig, fullfile(mirrorFigs, 'alpha_res_vs_delta_theta.fig'));
end

fprintf(1, 'Wrote run artifacts under %s\nMirrored CSV/report/PNG to tables/, reports/, figures/\n', runDir);
fprintf(1, ['ALPHA_RES_DEPENDS_ON_TRAJECTORY = %s\nBEST_TRAJECTORY_FEATURE = %s\n' ...
    'TRAJECTORY_BEATS_STATE = %s\n'], flagDep, bestFeat, flagBeats);

end

function ths = localSmoothAngle(thu, n)
% Smooth unwrapped angle along index (uniform T spacing not required for SG window in index).
if n < 3
    ths = thu;
    return
end
wl = min(9, 2 * floor(n / 2) - 1);
wl = max(wl, 3);
if mod(wl, 2) == 0
    wl = wl - 1;
end
wl = min(wl, n);
if mod(wl, 2) == 0
    wl = wl - 1;
end
try
    ths = smoothdata(thu, 'sgolay', wl);
catch
    try
        ths = sgolayfilt(thu, 2, wl);
    catch
        ths = movmean(thu, min(3, n), 'Endpoints', 'shrink');
    end
end
end

function S = localMaskCols(X, m)
S = struct('X', [], 'm', []);
S.m = m(:);
if ~any(m)
    S.X = zeros(0, size(X, 2));
    return
end
S.X = X(m, :);
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
zipPath = fullfile(reviewDir, 'alpha_res_trajectory_bundle.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end
