function run_aging_R_vs_collective_state_agent23a(varargin)
%RUN_AGING_R_VS_COLLECTIVE_STATE_AGENT23A  Agent 23A — aging R(T) vs collective state (kappa manifold)
%
% Inputs (read-only):
%   tables/alpha_structure.csv  — kappa1, kappa2, alpha
%   barrier_descriptors.csv     — R(T) (R_T_interp preferred), merged on T_K
%
% Writes (mirrored to repo root):
%   tables/R_vs_state.csv
%   figures/R_vs_theta.png
%   reports/R_state_report.md
%
% Name-value:
%   'repoRoot', 'alphaStructurePath', 'barrierPath'

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

runCfg = struct('runLabel', 'aging_R_vs_state', ...
    'dataset', 'R(T) vs kappa1,kappa2,theta,r from alpha_structure + barrier_descriptors');
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

sub = {'figures', 'tables', 'reports'};
for i = 1:numel(sub)
    p = fullfile(runDir, sub{i});
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end

alphaPath = opts.alphaStructurePath;
barrierPath = opts.barrierPath;
if ~isfile(barrierPath)
    barrierPath = localFindBarrierWithR(repoRoot);
end
assert(isfile(alphaPath), 'Missing %s', alphaPath);
assert(isfile(barrierPath), 'Could not locate barrier_descriptors.csv with R(T) (pass barrierPath).');

aS = readtable(alphaPath, 'VariableNamingRule', 'preserve');
bTbl = readtable(barrierPath, 'VariableNamingRule', 'preserve');
Rcol = localPickRTColumn(bTbl.Properties.VariableNames);

reqA = {'T_K', 'kappa1', 'kappa2', 'alpha'};
for k = 1:numel(reqA)
    assert(ismember(reqA{k}, aS.Properties.VariableNames), 'Missing column %s in alpha_structure', reqA{k});
end

merged = innerjoin(aS(:, {'T_K', 'kappa1', 'kappa2', 'alpha'}), ...
    bTbl(:, [{'T_K'}, Rcol]), 'Keys', 'T_K');
merged = sortrows(merged, 'T_K');
merged.Properties.VariableNames{end} = 'R_T'; %#ok<NASGU> % canonical name in table

n = height(merged);
assert(n >= 4, 'Too few aligned rows (need n >= 4).');

T_K = double(merged.T_K(:));
k1 = double(merged.kappa1(:));
k2 = double(merged.kappa2(:));
alp = double(merged.alpha(:));
R = double(merged.R_T(:));

theta = atan2(k2, k1);
r = hypot(k1, k2);

outRow = table(T_K, k1, k2, alp, theta, r, R, ...
    'VariableNames', {'T_K', 'kappa1', 'kappa2', 'alpha', 'theta_rad', 'r', 'R_T'});

% Univariate correlations: R vs state coordinates
uniNames = {'kappa1', 'kappa2', 'theta_rad', 'r'};
uniPear = NaN(numel(uniNames), 1);
uniSpear = NaN(numel(uniNames), 1);
for u = 1:numel(uniNames)
    xv = outRow.(uniNames{u});
    m = isfinite(xv) & isfinite(R);
    if nnz(m) >= 3
        uniPear(u) = corr(xv(m), R(m), 'rows', 'complete');
        uniSpear(u) = corr(xv(m), R(m), 'type', 'Spearman', 'rows', 'complete');
    end
end

% Models (OLS + intercept)
models = struct('id', {}, 'Xfn', {});
models(end + 1) = struct('id', 'R ~ kappa1', ...
    'Xfn', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), k1_(:)]); %#ok<AGROW>
models(end + 1) = struct('id', 'R ~ kappa1 + kappa2', ...
    'Xfn', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), k1_(:), k2_(:)]);
models(end + 1) = struct('id', 'R ~ theta_rad', ...
    'Xfn', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), th_(:)]);
models(end + 1) = struct('id', 'R ~ theta_rad + r', ...
    'Xfn', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), th_(:), r_(:)]);

fitRows = table();
for k = 1:numel(models)
    X = models(k).Xfn(k1, k2, theta, r);
    row = localOlsLoocvReport(models(k).id, R, X);
    fitRows = [fitRows; row]; %#ok<AGROW>
end

loocv_naive = localLoocvNaiveMean(R);
sigY = std(R, 'omitnan');

% Best single coordinate (lowest LOOCV among univariate linear models)
singleSpecs = {
    'kappa1', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), k1_(:)];
    'kappa2', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), k2_(:)];
    'theta', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), th_(:)];
    'r', @(k1_, k2_, th_, r_) [ones(numel(k1_), 1), r_(:)]
    };
singleRmse = NaN(size(singleSpecs, 1), 1);
for s = 1:size(singleSpecs, 1)
    Xs = singleSpecs{s, 2}(k1, k2, theta, r);
    rpt = localOlsLoocvReport('tmp', R, Xs);
    singleRmse(s) = rpt.loocv_rmse;
end
[~, ibest] = min(singleRmse);
bestCoordName = singleSpecs{ibest, 1};

validFit = isfinite(fitRows.loocv_rmse);
[~, iBestState] = min(fitRows.loocv_rmse(validFit));
idxBest = find(validFit);
iBestState = idxBest(iBestState);
bestStateModel = fitRows.model{iBestState};
bestStateLoocv = fitRows.loocv_rmse(iBestState);
pearB = fitRows.pearson_y_yhat(iBestState);
spearB = fitRows.spearman_y_yhat(iBestState);

thrLink = 0.35;
maxUniSpear = max(abs(uniSpear), [], 'omitnan');
maxUniPear = max(abs(uniPear), [], 'omitnan');
linkedUni = (n >= 4) && ((isfinite(maxUniPear) && maxUniPear >= thrLink) || ...
    (isfinite(maxUniSpear) && maxUniSpear >= thrLink));

predictable = (bestStateLoocv < loocv_naive) && ...
    ((abs(pearB) >= 0.4 && abs(spearB) >= 0.35) || (abs(pearB) >= 0.5));

if predictable || linkedUni
    flagLinked = 'YES';
else
    flagLinked = 'NO';
end

% Figure: R vs theta
fig = create_figure('Name', 'R_vs_theta', 'NumberTitle', 'off');
ax = axes(fig);
scatter(ax, theta, R, 80, T_K, 'filled', 'LineWidth', 1.5);
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'T (K)';
cb.FontSize = 14;
hold(ax, 'on');
plot(ax, theta, R, '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1);
hold(ax, 'off');
xlabel(ax, '\theta = atan2(\kappa_2, \kappa_1) (rad)', 'FontSize', 14);
ylabel(ax, 'R(T)', 'FontSize', 14);
grid(ax, 'on');
set(ax, 'FontSize', 14);

figPath = save_run_figure(fig, 'R_vs_theta', runDir);
close(fig);

% Save per-T table
outPathRun = save_run_table(outRow, 'R_vs_state.csv', runDir);

% Supplementary tables in run dir
uniTbl = table(uniNames(:), uniPear, uniSpear, 'VariableNames', ...
    {'coordinate', 'pearson_R', 'spearman_R'});
save_run_table(uniTbl, 'R_vs_state_univariate_correlations.csv', runDir);
save_run_table(fitRows, 'R_vs_state_model_summary.csv', runDir);

% Report
lines = {};
lines{end + 1} = '# Aging R(T) vs collective state (Agent 23A)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(runDir, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Inputs';
lines{end + 1} = sprintf('- **alpha_structure:** `%s`', strrep(alphaPath, '\', '/'));
lines{end + 1} = sprintf('- **barrier_descriptors:** `%s` (column `%s` → `R_T`)', strrep(barrierPath, '\', '/'), Rcol);
lines{end + 1} = '';
lines{end + 1} = '## Construction';
lines{end + 1} = '- Merge on `T_K`: `kappa1`, `kappa2`, `alpha` from `alpha_structure`; aging observable `R(T)` from barrier table.';
lines{end + 1} = '- `theta_rad = atan2(kappa2, kappa1)`, `r = hypot(kappa1, kappa2)`.';
lines{end + 1} = '';
lines{end + 1} = '## Univariate correlations (R vs coordinate)';
lines{end + 1} = '| coordinate | Pearson | Spearman |';
lines{end + 1} = '|---|---:|---:|';
for u = 1:numel(uniNames)
    lines{end + 1} = sprintf('| %s | %.6g | %.6g |', uniNames{u}, uniPear(u), uniSpear(u)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '## Linear models (OLS + LOOCV RMSE)';
lines{end + 1} = '| model | n | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) | max leverage |';
lines{end + 1} = '|---|---:|---:|---:|---:|---:|';
for k = 1:height(fitRows)
    lines{end + 1} = sprintf('| %s | %d | %.6g | %.6g | %.6g | %.6g |', ...
        fitRows.model{k}, fitRows.n(k), fitRows.loocv_rmse(k), ...
        fitRows.pearson_y_yhat(k), fitRows.spearman_y_yhat(k), fitRows.max_leverage(k));
end
lines{end + 1} = '';
lines{end + 1} = sprintf('- **Best model (lowest LOOCV among the four):** `%s` (RMSE = %.6g)', bestStateModel, bestStateLoocv);
lines{end + 1} = sprintf('- **LOOCV naive mean benchmark:** %.6g; **std(R):** %.6g', loocv_naive, sigY);
lines{end + 1} = '';
lines{end + 1} = '## Final flags';
lines{end + 1} = sprintf('- **AGING_LINKED_TO_STATE** = **%s** (YES if best multivariate model generalizes vs naive mean and/or max |ρ|,|ρ_s| ≥ %.2f on univariate tests; n ≥ 4)', flagLinked, thrLink);
lines{end + 1} = sprintf('- **BEST_STATE_COORDINATE_FOR_R** = **%s** (lowest LOOCV among single-term {kappa1, kappa2, theta, r})', bestCoordName);
lines{end + 1} = '';
lines{end + 1} = '*Auto-generated by `analysis/run_aging_R_vs_collective_state_agent23a.m`.*';

repTxt = strjoin(lines, newline);
repPathRun = save_run_report(repTxt, 'R_state_report.md', runDir);

% Mirror to repo deliverables
mirrorTables = fullfile(repoRoot, 'tables');
mirrorFigs = fullfile(repoRoot, 'figures');
mirrorRep = fullfile(repoRoot, 'reports');
for d = {mirrorTables, mirrorFigs, mirrorRep}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end
copyfile(outPathRun, fullfile(mirrorTables, 'R_vs_state.csv'));
copyfile(repPathRun, fullfile(mirrorRep, 'R_state_report.md'));
copyfile(figPath.png, fullfile(mirrorFigs, 'R_vs_theta.png'));
if isfield(figPath, 'fig') && exist(figPath.fig, 'file') == 2
    copyfile(figPath.fig, fullfile(mirrorFigs, 'R_vs_theta.fig'));
end

fprintf(1, 'Wrote run artifacts under %s\nMirrored to tables/R_vs_state.csv, figures/R_vs_theta.png, reports/R_state_report.md\n', runDir);
fprintf(1, 'AGING_LINKED_TO_STATE = %s\nBEST_STATE_COORDINATE_FOR_R = %s\n', flagLinked, bestCoordName);

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
        case "barrierpath"
            opts.barrierPath = char(string(val));
        otherwise
            error('Unknown option: %s', varargin{k});
    end
end
opts.alphaStructurePath = fullfile(opts.alphaStructurePath);
opts.barrierPath = char(string(opts.barrierPath));
end
