function run_aging_vs_trajectory_agent23b(varargin)
%RUN_AGING_VS_TRAJECTORY_AGENT23B  Agent 23B — aging clock ratio R vs κ trajectory
%
% Tests whether R(T) (aging clock ratio from barrier alignment) depends on
% trajectory / reorganization (Δθ, curvature, arc-length) vs state-only (PT scores).
%
% Inputs (read-only):
%   tables/alpha_structure.csv
%   tables/alpha_decomposition.csv
%   barrier_descriptors.csv (default: newest run with R_T_interp under
%     results/cross_experiment/runs/*/tables/, or explicit path)
%
% Outputs (run bundle + mirror):
%   tables/R_vs_trajectory.csv
%   figures/R_vs_delta_theta.png
%   reports/R_trajectory_report.md
%
% Name-value: 'repoRoot', 'barrierPath', 'alphaStructurePath', 'decompPath'

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

runCfg = struct('runLabel', 'R_trajectory', ...
    'dataset', 'R vs delta_theta, curvature, ds; PT-only baseline');
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

alphaStructPath = opts.alphaStructurePath;
decompPath = opts.decompPath;
barrierPath = opts.barrierPath;

assert(exist(alphaStructPath, 'file') == 2, 'Missing %s', alphaStructPath);
assert(exist(decompPath, 'file') == 2, 'Missing %s', decompPath);
if ~isfile(barrierPath)
    barrierPath = localFindBarrierWithR(repoRoot);
end
assert(isfile(barrierPath), 'barrier_descriptors.csv not found (pass ''barrierPath'').');

aS = readtable(alphaStructPath, 'VariableNamingRule', 'preserve');
aD = readtable(decompPath, 'VariableNamingRule', 'preserve');
bTbl = readtable(barrierPath, 'VariableNamingRule', 'preserve');

Rcol = localPickRTColumn(bTbl.Properties.VariableNames);

decCols = intersect({'T_K', 'PT_geometry_valid'}, aD.Properties.VariableNames, 'stable');
aD2 = aD(:, decCols);

merged = innerjoin(aS, aD2, 'Keys', 'T_K');

bCols = {'T_K', Rcol};
if all(ismember({'pt_svd_score1', 'pt_svd_score2'}, bTbl.Properties.VariableNames))
    bCols = [bCols, {'pt_svd_score1', 'pt_svd_score2'}]; %#ok<AGROW>
end
b2 = bTbl(:, bCols);

merged = innerjoin(merged, b2, 'Keys', 'T_K');

if ismember('PT_geometry_valid', merged.Properties.VariableNames)
    merged = merged(double(merged.PT_geometry_valid) ~= 0, :);
end

merged = merged(isfinite(merged.(Rcol)), :);
merged = sortrows(merged, 'T_K');
n = height(merged);
assert(n >= 4, 'Too few rows with finite R(T).');

T_K = double(merged.T_K(:));
k1 = double(merged.kappa1(:));
k2 = double(merged.kappa2(:));
R = double(merged.(Rcol)(:));

pt1 = NaN(n, 1);
pt2 = NaN(n, 1);
if ismember('pt_svd_score1', merged.Properties.VariableNames)
    pt1 = double(merged.pt_svd_score1(:));
end
if ismember('pt_svd_score2', merged.Properties.VariableNames)
    pt2 = double(merged.pt_svd_score2(:));
end

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

s_cum = zeros(n, 1);
for ii = 2:n
    if isfinite(ds(ii))
        s_cum(ii) = s_cum(ii - 1) + ds(ii);
    else
        s_cum(ii) = s_cum(ii - 1);
    end
end

outRow = table(T_K, k1, k2, R, theta, r, thu, dtheta, ths, dtheta_sm, ...
    kappa_curve, ds, s_cum, dT, pt1, pt2, ...
    'VariableNames', {'T_K', 'kappa1', 'kappa2', 'R', 'theta_rad', 'r', ...
    'theta_unwrapped_rad', 'delta_theta_rad', 'theta_smoothed_unwrapped_rad', ...
    'delta_theta_smoothed_rad', 'kappa_curve', 'ds_step', 'arc_length_cumulative', ...
    'delta_T_K', 'pt_svd_score1', 'pt_svd_score2'});

% Common rows for Δθ-based models and PT baseline (apples-to-apples LOOCV)
mFit = isfinite(dtheta) & isfinite(R) & isfinite(pt1) & isfinite(pt2);
assert(nnz(mFit) >= 4, 'Too few rows with finite Delta_theta, R, and PT scores.');

% --- Univariate correlations: R vs trajectory features
featNames = {'delta_theta_rad', 'delta_theta_smoothed_rad', 'kappa_curve', 'ds_step'};
uniPear = NaN(numel(featNames), 1);
uniSpear = NaN(numel(featNames), 1);
for u = 1:numel(featNames)
    xv = outRow.(featNames{u});
    m = isfinite(xv) & isfinite(R);
    if nnz(m) >= 3
        uniPear(u) = corr(xv(m), R(m), 'rows', 'complete');
        uniSpear(u) = corr(xv(m), R(m), 'type', 'Spearman', 'rows', 'complete');
    end
end

% --- Core trajectory models (task); same row mask as PT baseline
trajModels = struct('id', {}, 'Xfn', {});
trajModels(end + 1) = struct('id', 'R ~ delta_theta_rad', ...
    'Xfn', @(dth, k1_, th_, mf, n_) localMaskCols([ones(n_, 1), dth], mf(:)));
trajModels(end + 1) = struct('id', 'R ~ delta_theta_rad + kappa1', ...
    'Xfn', @(dth, k1_, th_, mf, n_) localMaskCols([ones(n_, 1), dth, k1_(:)], ...
    mf(:) & isfinite(k1_(:))));
trajModels(end + 1) = struct('id', 'R ~ delta_theta_rad + theta_rad', ...
    'Xfn', @(dth, k1_, th_, mf, n_) localMaskCols([ones(n_, 1), dth, th_(:)], ...
    mf(:) & isfinite(th_(:))));

fitTraj = table();
for k = 1:numel(trajModels)
    Xfull = trajModels(k).Xfn(dtheta, k1, theta, mFit, n);
    fitTraj = [fitTraj; localOlsLoocvReport(trajModels(k).id, R(Xfull.m), Xfull.X)]; %#ok<AGROW>
end

% --- PT-only baseline (state in PT embedding), same rows as trajectory fits
fitPt = table();
Xpt = [ones(n, 1), pt1, pt2];
XptF = localMaskCols(Xpt, mFit);
fitPt = localOlsLoocvReport('R ~ pt_svd_score1 + pt_svd_score2', R(XptF.m), XptF.X);

loocv_naive = localLoocvNaiveMean(R(mFit));
sigY = std(R(mFit), 'omitnan');

validT = isfinite(fitTraj.loocv_rmse);
[~, iBestT] = min(fitTraj.loocv_rmse(validT));
idxT = find(validT);
iBestT = idxT(iBestT);
bestTrajModel = fitTraj.model{iBestT};
bestTrajLoocv = fitTraj.loocv_rmse(iBestT);
pearT = fitTraj.pearson_y_yhat(iBestT);
spearT = fitTraj.spearman_y_yhat(iBestT);

bestPtLoocv = fitPt.loocv_rmse(1);
if isempty(fitPt) || ~isfinite(bestPtLoocv)
    bestPtLoocv = NaN;
end

% Flags (see report)
maxUniPear = max(abs(uniPear), [], 'omitnan');
predictableTraj = isfinite(bestTrajLoocv) && (bestTrajLoocv < loocv_naive) && ...
    (((abs(pearT) >= 0.35 && abs(spearT) >= 0.3) || (abs(pearT) >= 0.45)) || ...
    (isfinite(maxUniPear) && maxUniPear >= 0.4));

if predictableTraj
    flagAgingTraj = 'YES';
else
    flagAgingTraj = 'NO';
end

trajectoryImproves = isfinite(bestTrajLoocv) && isfinite(bestPtLoocv) && ...
    bestTrajLoocv < bestPtLoocv - 1e-12;

if trajectoryImproves
    flagImproves = 'YES';
else
    flagImproves = 'NO';
end

% --- Figure (Name == saved base)
fig = create_figure('Name', 'R_vs_delta_theta', 'NumberTitle', 'off');
ax = axes(fig);
scatter(ax, dtheta, R, 80, T_K, 'filled', 'LineWidth', 1.5);
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'T (K)';
cb.FontSize = 14;
hold(ax, 'on');
ord = isfinite(dtheta) & isfinite(R);
plot(ax, dtheta(ord), R(ord), '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 2);
hold(ax, 'off');
xlabel(ax, '\Delta\theta (rad, forward diff on unwrapped \theta)', 'FontSize', 14);
ylabel(ax, 'R = \tau_{FM}/\tau_{dip} (interp)', 'FontSize', 14);
grid(ax, 'on');
set(ax, 'FontSize', 14);

figPath = save_run_figure(fig, 'R_vs_delta_theta', runDir);
close(fig);

outPath = save_run_table(outRow, 'R_vs_trajectory.csv', runDir);
uniTbl = table(featNames(:), uniPear, uniSpear, 'VariableNames', ...
    {'trajectory_feature', 'pearson_R', 'spearman_R'});
save_run_table(uniTbl, 'R_vs_trajectory_univariate_correlations.csv', runDir);
save_run_table(fitTraj, 'R_vs_trajectory_model_summary.csv', runDir);
save_run_table(fitPt, 'R_vs_trajectory_PT_baseline.csv', runDir);

bench = table({'loocv_naive_mean'; 'loocv_std_y'; 'best_trajectory_loocv'; 'PT_only_loocv'}, ...
    [loocv_naive; sigY; bestTrajLoocv; bestPtLoocv], ...
    'VariableNames', {'benchmark', 'value'});
save_run_table(bench, 'R_vs_trajectory_benchmarks.csv', runDir);

% --- Report
lines = {};
lines{end + 1} = '# Aging clock ratio vs κ trajectory (Agent 23B)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(runDir, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Inputs';
lines{end + 1} = sprintf('- `%s`', strrep(alphaStructPath, '\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(decompPath, '\', '/'));
lines{end + 1} = sprintf('- `%s` (`%s`)', strrep(barrierPath, '\', '/'), Rcol);
lines{end + 1} = '';
lines{end + 1} = '## Trajectory construction';
lines{end + 1} = '- `theta = atan2(kappa2, kappa1)`, `r = hypot(kappa1, kappa2)`, unwrapped along sorted `T_K`.';
lines{end + 1} = '- `delta_theta_rad`: forward difference of unwrapped θ.';
lines{end + 1} = '- `theta_smoothed_unwrapped_rad` / `delta_theta_smoothed_rad`: smoothed unwrapped θ (SG or moving average) and its forward difference.';
lines{end + 1} = '- `kappa_curve`: |Δθ| / ΔT (rad/K) at each T (NaN on first row).';
lines{end + 1} = '- `ds_step`: Euclidean step in (κ1, κ2) between successive T.';
lines{end + 1} = '- `arc_length_cumulative`: cumulative sum of `ds_step` along the temperature-ordered path.';
lines{end + 1} = '';
lines{end + 1} = sprintf('## Analysis rows (n = %d)', nnz(mFit));
lines{end + 1} = 'All LOOCV models use the same temperatures: finite `delta_theta_rad`, `R`, and PT scores (first `T_K` omits Δθ by construction).';
lines{end + 1} = '';
lines{end + 1} = '## Tests: R vs trajectory features (Pearson / Spearman)';
lines{end + 1} = '| feature | Pearson | Spearman |';
lines{end + 1} = '|---|---:|---:|';
for u = 1:numel(featNames)
    lines{end + 1} = sprintf('| %s | %.6g | %.6g |', featNames{u}, uniPear(u), uniSpear(u)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '## Fitted models (OLS + LOOCV RMSE)';
lines{end + 1} = '| model | n | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) | max leverage |';
lines{end + 1} = '|---|---:|---:|---:|---:|---:|';
for k = 1:height(fitTraj)
    lines{end + 1} = sprintf('| %s | %d | %.6g | %.6g | %.6g | %.6g |', ...
        fitTraj.model{k}, fitTraj.n(k), fitTraj.loocv_rmse(k), ...
        fitTraj.pearson_y_yhat(k), fitTraj.spearman_y_yhat(k), fitTraj.max_leverage(k));
end
lines{end + 1} = '';
lines{end + 1} = '## PT-only baseline (same rows)';
lines{end + 1} = '| model | n | LOOCV RMSE | Pearson | Spearman |';
lines{end + 1} = '|---|---:|---:|---:|---:|';
if height(fitPt) >= 1 && isfinite(fitPt.loocv_rmse(1))
    lines{end + 1} = sprintf('| %s | %d | %.6g | %.6g | %.6g |', ...
        fitPt.model{1}, fitPt.n(1), fitPt.loocv_rmse(1), ...
        fitPt.pearson_y_yhat(1), fitPt.spearman_y_yhat(1));
else
    lines{end + 1} = '| R ~ pt_svd_score1 + pt_svd_score2 | — | — | — | — |';
end
lines{end + 1} = '';
lines{end + 1} = sprintf('- **Best trajectory model:** `%s` (LOOCV RMSE = %.6g)', bestTrajModel, bestTrajLoocv);
lines{end + 1} = sprintf('- **LOOCV naive mean:** %.6g; **std(R):** %.6g', loocv_naive, sigY);
if isfinite(bestPtLoocv)
    lines{end + 1} = sprintf('- **PT-only LOOCV RMSE:** %.6g', bestPtLoocv);
end
lines{end + 1} = '';
lines{end + 1} = '## Final flags';
lines{end + 1} = sprintf('- **AGING_DEPENDS_ON_TRAJECTORY** = **%s** (trajectory models beat naive LOOCV + association / univariate signal)', flagAgingTraj);
lines{end + 1} = sprintf('- **TRAJECTORY_IMPROVES_OVER_STATE** = **%s** (best trajectory LOOCV vs PT-only `pt_svd_score1` + `pt_svd_score2`)', flagImproves);
lines{end + 1} = '';
lines{end + 1} = '*Auto-generated by `analysis/run_aging_vs_trajectory_agent23b.m`.*';

repTxt = strjoin(lines, newline);
repPath = save_run_report(repTxt, 'R_trajectory_report.md', runDir);

zipPath = localBuildZip(runDir);

localAppendLog(run.log_path, sprintf('[%s] Agent 23B complete\n', datestr(now, 31)));
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
copyfile(outPath, fullfile(mirrorTables, 'R_vs_trajectory.csv'));
copyfile(repPath, fullfile(mirrorRep, 'R_trajectory_report.md'));
copyfile(figPath.png, fullfile(mirrorFigs, 'R_vs_delta_theta.png'));
if isfield(figPath, 'fig') && exist(figPath.fig, 'file') == 2
    copyfile(figPath.fig, fullfile(mirrorFigs, 'R_vs_delta_theta.fig'));
end

fprintf(1, 'Wrote run artifacts under %s\nMirrored CSV/report/PNG to tables/, reports/, figures/\n', runDir);
fprintf(1, ['AGING_DEPENDS_ON_TRAJECTORY = %s\n' ...
    'TRAJECTORY_IMPROVES_OVER_STATE = %s\n'], flagAgingTraj, flagImproves);

end

function ths = localSmoothAngle(thu, n)
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
    if exist('smoothdata', 'file') == 2
        ths = smoothdata(thu, 'sgolay', wl);
    else
        ths = sgolayfilt(thu, 2, wl);
    end
catch
    ths = movmean(thu, min(3, n), 'Endpoints', 'shrink');
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
zipPath = fullfile(reviewDir, 'R_trajectory_bundle.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function col = localPickRTColumn(names)
cand = ["R_T_interp", "R_T", "R"];
for k = 1:numel(cand)
    if any(strcmp(names, cand(k)))
        col = char(cand(k));
        return
    end
end
error('No R(T) column (R_T_interp / R_T / R) in barrier table');
end

function pth = localFindBarrierWithR(repoRoot)
base = fullfile(repoRoot, 'results', 'cross_experiment', 'runs');
if exist(base, 'dir') ~= 7
    pth = '';
    return
end
d = dir(base);
best = '';
bestTime = datetime(1970, 1, 1);
for i = 1:numel(d)
    if ~d(i).isdir || strcmp(d(i).name, '.') || strcmp(d(i).name, '..')
        continue
    end
    cand = fullfile(base, d(i).name, 'tables', 'barrier_descriptors.csv');
    if exist(cand, 'file') ~= 2
        continue
    end
    t = dir(cand);
    if isempty(t), continue; end
    tt = datetime(t(1).date);
    try
        opts = detectImportOptions(cand, 'VariableNamingRule', 'preserve');
        vn = opts.VariableNames;
    catch
        continue
    end
    if ~any(ismember(vn, {'R_T_interp', 'R_T', 'R'}))
        continue
    end
    if isempty(best) || tt > bestTime
        best = cand;
        bestTime = tt;
    end
end
pth = best;
end

function opts = localParseOpts(varargin)
thisPath = mfilename('fullpath');
opts = struct();
opts.repoRoot = fileparts(fileparts(thisPath));
opts.alphaStructurePath = fullfile(opts.repoRoot, 'tables', 'alpha_structure.csv');
opts.decompPath = fullfile(opts.repoRoot, 'tables', 'alpha_decomposition.csv');
opts.barrierPath = fullfile(opts.repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv');

if mod(numel(varargin), 2) ~= 0
    error('Name-value pairs expected');
end
for k = 1:2:numel(varargin)
    nm = lower(string(varargin{k}));
    val = varargin{k + 1};
    switch nm
        case "reporoot"
            opts.repoRoot = char(string(val));
        case "alphastructurepath"
            opts.alphaStructurePath = char(string(val));
        case "decomppath"
            opts.decompPath = char(string(val));
        case "barrierpath"
            opts.barrierPath = char(string(val));
        otherwise
            error('Unknown option: %s', varargin{k});
    end
end
opts.alphaStructurePath = char(string(opts.alphaStructurePath));
opts.decompPath = char(string(opts.decompPath));
opts.barrierPath = char(string(opts.barrierPath));
end
