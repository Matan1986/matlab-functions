function run_aging_kappa1_prediction_agent24d(varargin)
%RUN_AGING_KAPPA1_PREDICTION_AGENT24D  Agent 24D — predict aging R(T) from κ1 only (LOOCV)
%
% Minimal model test: no PT, no trajectory, at most two nonlinear terms (κ1, κ1^2).
%
% Inputs (read-only):
%   - Aging clock ratio: R(T) (default: canonical aging run table_clock_ratio.csv; Tp column)
%   - tables/alpha_structure.csv → kappa1 on T_K
%
% Outputs (run dir + mirror to repo root):
%   tables/aging_kappa1_models.csv
%   tables/aging_kappa1_loocv.csv
%   figures/R_vs_kappa1.png
%   figures/R_vs_prediction.png
%   reports/aging_kappa1_prediction.md
%
% Name-value: 'repoRoot', 'clockRatioPath', 'alphaStructurePath'

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

set(0, 'DefaultFigureVisible', 'off');

runCfg = struct('runLabel', 'aging_kappa1_prediction_agent24d', ...
    'dataset', 'R(T) LOOCV from kappa1 only (Agent 24D)', ...
    'clock_ratio', opts.clockRatioPath, ...
    'alpha_structure', opts.alphaStructurePath);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

for s = ["figures", "tables", "reports", "review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7, mkdir(d); end
end

fprintf(1, 'Agent 24D run directory:\n%s\n', runDir);

appendText(run.log_path, sprintf('[%s] run_aging_kappa1_prediction_agent24d started\n', datestr(now, 31)));

%% Load and join on temperature
clk = readtable(opts.clockRatioPath, 'VariableNamingRule', 'preserve');
assert(ismember('Tp', clk.Properties.VariableNames), 'clock table needs Tp column');
assert(ismember('R_tau_FM_over_tau_dip', clk.Properties.VariableNames), ...
    'clock table needs R_tau_FM_over_tau_dip');

aS = readtable(opts.alphaStructurePath, 'VariableNamingRule', 'preserve');
assert(all(ismember({'T_K', 'kappa1'}, aS.Properties.VariableNames)), ...
    'alpha_structure needs T_K, kappa1');

clk.T_K = double(clk.Tp(:));
clk.R = double(clk.R_tau_FM_over_tau_dip(:));
merged = innerjoin(clk(:, {'T_K', 'R'}), aS(:, {'T_K', 'kappa1'}), 'Keys', 'T_K');
merged.kappa1 = double(merged.kappa1(:));

m = isfinite(merged.R) & isfinite(merged.kappa1);
master = merged(m, :);
master = sortrows(master, 'T_K');

T_K = double(master.T_K(:));
y = double(master.R(:));
k1 = double(master.kappa1(:));
n = numel(y);

assert(n >= 4, 'Agent24D: need at least n=4 rows with finite R and kappa1 (got n=%d).', n);

%% Models: baseline, linear, quadratic, isotonic (1D monotonic)
pred = struct('id', {}, 'category', {}, 'fitter', {});

pred(end + 1) = struct('id', 'R ~ 1', 'category', 'baseline', 'fitter', 'mean'); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ kappa1', 'category', 'linear', 'fitter', 'ols1'); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ kappa1 + kappa1^2', 'category', 'quadratic', 'fitter', 'ols2'); %#ok<AGROW>
pred(end + 1) = struct('id', 'R ~ isotonic(kappa1)', 'category', 'monotonic', 'fitter', 'isotonic'); %#ok<AGROW>

rows = table();
Yhat = nan(n, numel(pred));

for k = 1:numel(pred)
    switch pred(k).fitter
        case 'mean'
            [rmse, rP, rS, yhat] = localLoocvMean(y);
        case 'ols1'
            [rmse, rP, rS, yhat] = localLoocvOls(y, k1);
        case 'ols2'
            [rmse, rP, rS, yhat] = localLoocvOls(y, [k1, k1.^2]);
        case 'isotonic'
            [rmse, rP, rS, yhat] = localLoocvIsotonic(k1, y);
        otherwise
            error('Unknown fitter: %s', pred(k).fitter);
    end
    Yhat(:, k) = yhat;
    rows = [rows; table({pred(k).id}, {pred(k).category}, n, rmse, rP, rS, ...
        'VariableNames', {'model', 'category', 'n', 'loocv_rmse', 'pearson_y_yhat', 'spearman_y_yhat'})]; %#ok<AGROW>
end

save_run_table(rows, 'aging_kappa1_models.csv', runDir);

idxBase = find(strcmp(rows.model, 'R ~ 1'), 1);
rmseBase = rows.loocv_rmse(idxBase);

idxLin = find(strcmp(rows.model, 'R ~ kappa1'), 1);
idxQuad = find(strcmp(rows.model, 'R ~ kappa1 + kappa1^2'), 1);
idxIso = find(strcmp(rows.model, 'R ~ isotonic(kappa1)'), 1);

rmseLin = rows.loocv_rmse(idxLin);
rmseQuad = rows.loocv_rmse(idxQuad);
rmseIso = rows.loocv_rmse(idxIso);
pLin = rows.pearson_y_yhat(idxLin);
pQuad = rows.pearson_y_yhat(idxQuad);

%% LOOCV detail table
loocvTbl = table(T_K, y, k1, ...
    Yhat(:, idxBase), Yhat(:, idxLin), Yhat(:, idxQuad), Yhat(:, idxIso), ...
    'VariableNames', {'T_K', 'R', 'kappa1', ...
    'yhat_loocv_baseline', 'yhat_loocv_linear', 'yhat_loocv_quadratic', 'yhat_loocv_isotonic'});
save_run_table(loocvTbl, 'aging_kappa1_loocv.csv', runDir);

%% Best LOOCV model (prefer κ1 family only if it beats baseline)
nonBase = rows(~strcmp(rows.model, 'R ~ 1'), :);
[~, jRow] = min(nonBase.loocv_rmse, [], 'omitnan');
bestKappaModel = nonBase.model{jRow};
rmseBestKappa = nonBase.loocv_rmse(jRow);
ids = arrayfun(@(s) char(string(s.id)), pred, 'UniformOutput', false);
if isfinite(rmseBestKappa) && rmseBestKappa < rmseBase - 1e-12
    bestModel = bestKappaModel;
    bestYhat = Yhat(:, strcmp(ids, bestModel));
else
    bestModel = 'R ~ 1 (baseline; κ1 models do not improve LOOCV RMSE)';
    bestYhat = Yhat(:, strcmp(ids, 'R ~ 1'));
end

%% Verdicts
verd = localVerdicts(rmseBase, rmseLin, rmseQuad, pLin, pQuad, y);

%% Figures
fig0 = create_figure('Name', 'R_vs_kappa1', 'NumberTitle', 'off');
ax0 = axes(fig0);
scatter(ax0, k1, y, 90, T_K, 'filled', 'LineWidth', 1.5);
hold(ax0, 'on');
[k1s, ord] = sort(k1);
ys = y(ord);
if numel(k1s) >= 2
    plot(ax0, k1s, ys, '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
end
hold(ax0, 'off');
colormap(ax0, parula);
cb0 = colorbar(ax0);
cb0.Label.String = 'T (K)';
grid(ax0, 'on');
xlabel(ax0, '\kappa_1', 'FontSize', 14);
ylabel(ax0, 'R = \tau_{FM}/\tau_{dip}', 'FontSize', 14);
set(ax0, 'FontSize', 14);
figPath0 = save_run_figure(fig0, 'R_vs_kappa1', runDir);
close(fig0);

fig1 = create_figure('Name', 'R_vs_prediction', 'NumberTitle', 'off');
ax = axes(fig1);
scatter(ax, y, bestYhat, 90, T_K, 'filled', 'LineWidth', 1.5);
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
xlabel(ax, 'R measured (clock ratio)', 'FontSize', 14);
ylabel(ax, 'R LOOCV prediction', 'FontSize', 14);
title(ax, bestModel, 'FontSize', 11, 'Interpreter', 'none');
set(ax, 'FontSize', 14);
figPath1 = save_run_figure(fig1, 'R_vs_prediction', runDir);
close(fig1);

%% Report
rep = localBuildReport(runDir, opts, n, T_K, rows, verd, bestModel, bestKappaModel, ...
    rmseBase, rmseLin, rmseQuad, rmseIso, rmseBestKappa, figPath0, figPath1);
save_run_report(rep, 'aging_kappa1_prediction.md', runDir);

zipPath = localBuildZip(runDir);
appendText(run.log_path, sprintf('[%s] complete; zip=%s\n', datestr(now, 31), zipPath));

%% Mirror to repo root (tables / figures / reports)
mirrorTables = fullfile(repoRoot, 'tables');
mirrorFigs = fullfile(repoRoot, 'figures');
mirrorRep = fullfile(repoRoot, 'reports');
for d = {mirrorTables, mirrorFigs, mirrorRep}
    if exist(d{1}, 'dir') ~= 7, mkdir(d{1}); end
end
try
    copyfile(fullfile(runDir, 'tables', 'aging_kappa1_models.csv'), fullfile(mirrorTables, 'aging_kappa1_models.csv'));
    copyfile(fullfile(runDir, 'tables', 'aging_kappa1_loocv.csv'), fullfile(mirrorTables, 'aging_kappa1_loocv.csv'));
    copyfile(fullfile(runDir, 'reports', 'aging_kappa1_prediction.md'), fullfile(mirrorRep, 'aging_kappa1_prediction.md'));
    copyfile(figPath0.png, fullfile(mirrorFigs, 'R_vs_kappa1.png'));
    copyfile(figPath1.png, fullfile(mirrorFigs, 'R_vs_prediction.png'));
catch ME
    fprintf(2, 'Mirror copy skipped: %s\n', ME.message);
end

fprintf(1, 'Agent 24D complete. Report: %s\n', fullfile(runDir, 'reports', 'aging_kappa1_prediction.md'));
end

%% ------------------------------------------------------------------------
function v = localVerdicts(rmseBase, rmseLin, rmseQuad, pLin, pQuad, y)
v = struct();
sigy = std(y, 'omitnan');
bestK = min([rmseLin, rmseQuad], [], 'omitnan');
bestP = pLin;
if isfinite(rmseQuad) && isfinite(rmseLin) && rmseQuad <= rmseLin
    bestP = pQuad;
end

% KAPPA1_PREDICTS_AGING
if isfinite(bestK) && bestK < rmseBase * 0.85 && abs(bestP) >= 0.65
    v.KAPPA1_PREDICTS_AGING = "YES";
elseif isfinite(bestK) && (bestK < rmseBase * 0.95 || abs(bestP) >= 0.45)
    v.KAPPA1_PREDICTS_AGING = "PARTIAL";
else
    v.KAPPA1_PREDICTS_AGING = "NO";
end

% KAPPA1_BEATS_BASELINE
if isfinite(bestK) && bestK < rmseBase - 1e-12
    v.KAPPA1_BEATS_BASELINE = "YES";
else
    v.KAPPA1_BEATS_BASELINE = "NO";
end

% NONLINEAR_IMPROVES (quadratic vs linear)
if isfinite(rmseQuad) && isfinite(rmseLin) && rmseQuad < rmseLin - 1e-9
    v.NONLINEAR_IMPROVES = "YES";
else
    v.NONLINEAR_IMPROVES = "NO";
end

v.best_rmse_kappa_model = bestK;
v.rmse_baseline = rmseBase;
v.sigma_R = sigy;
end

function txt = localBuildReport(runDir, opts, n, T_K, rows, verd, bestModel, bestKappaModel, ...
    rmseBase, rmseLin, rmseQuad, rmseIso, rmseBestKappa, figPath0, figPath1)

lines = {};
lines{end + 1} = '# Aging prediction from κ1 only (Agent 24D)';
lines{end + 1} = '';
lines{end + 1} = sprintf('**Run:** `%s`', strrep(runDir, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Data (read-only)';
lines{end + 1} = sprintf('- **R(T):** `%s` (`R_tau_FM_over_tau_dip`, joined on `Tp` ≡ `T_K`).', ...
    strrep(opts.clockRatioPath, '\', '/'));
lines{end + 1} = sprintf('- **κ1:** `%s` (`kappa1` on `T_K`).', strrep(opts.alphaStructurePath, '\', '/'));
lines{end + 1} = sprintf('- **Overlap:** n = %d temperatures; grid: `%s`.', n, mat2str(T_K(:)', 4));
lines{end + 1} = '';
lines{end + 1} = '## Models';
lines{end + 1} = '- Baseline: R ~ constant (LOOCV mean).';
lines{end + 1} = '- Linear: R ~ κ1 (OLS, analytic LOOCV).';
lines{end + 1} = '- Quadratic: R ~ κ1 + κ1^2 (low-complexity; 2 slope terms + intercept).';
lines{end + 1} = '- Monotonic: isotonic regression on κ1 (increasing/decreasing chosen per training fold by sign of Pearson(x,y)); unique-κ aggregated means before PAV; interpolation prediction.';
lines{end + 1} = '';
lines{end + 1} = '## LOOCV metrics';
lines{end + 1} = '| model | category | n | LOOCV RMSE | Pearson | Spearman |';
lines{end + 1} = '|---|---|---:|---:|---:|---:|';
for k = 1:height(rows)
    lines{end + 1} = sprintf('| %s | %s | %d | %.6g | %.6g | %.6g |', ...
        rows.model{k}, rows.category{k}, rows.n(k), rows.loocv_rmse(k), ...
        rows.pearson_y_yhat(k), rows.spearman_y_yhat(k)); %#ok<AGROW>
end
lines{end + 1} = '';
lines{end + 1} = '## Comparison';
lines{end + 1} = sprintf('- **Baseline LOOCV RMSE:** %.6g', rmseBase);
lines{end + 1} = sprintf('- **Linear (κ1) LOOCV RMSE:** %.6g', rmseLin);
lines{end + 1} = sprintf('- **Quadratic LOOCV RMSE:** %.6g', rmseQuad);
lines{end + 1} = sprintf('- **Isotonic LOOCV RMSE:** %.6g', rmseIso);
lines{end + 1} = sprintf('- **Best κ1-family model (by LOOCV RMSE):** `%s` (RMSE = %.6g)', ...
    bestKappaModel, rmseBestKappa);
lines{end + 1} = sprintf('- **Figure / headline model:** `%s`', bestModel);
lines{end + 1} = '';
lines{end + 1} = '## Figures';
lines{end + 1} = sprintf('- `%s`', strrep(figPath0.png, '\', '/'));
lines{end + 1} = sprintf('- `%s`', strrep(figPath1.png, '\', '/'));
lines{end + 1} = '';
lines{end + 1} = '## Mandatory verdicts';
lines{end + 1} = sprintf('- **KAPPA1_PREDICTS_AGING:** **%s**', char(verd.KAPPA1_PREDICTS_AGING));
lines{end + 1} = sprintf('- **KAPPA1_BEATS_BASELINE:** **%s**', char(verd.KAPPA1_BEATS_BASELINE));
lines{end + 1} = sprintf('- **NONLINEAR_IMPROVES:** **%s**', char(verd.NONLINEAR_IMPROVES));
lines{end + 1} = '';
lines{end + 1} = '## Interpretation';
lines{end + 1} = 'If κ1 alone predicts R(T) strongly (LOOCV RMSE well below the constant baseline, Pearson ≳ 0.6–0.7), aging is plausibly controlled by the same collective response amplitude that enters switching corrections — a direct κ1–aging link without PT or trajectory variables.';
lines{end + 1} = '';
lines{end + 1} = '*Auto-generated by `analysis/run_aging_kappa1_prediction_agent24d.m`.*';

txt = strjoin(lines, newline);
end

function zipPath = localBuildZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7, mkdir(reviewDir); end
zipPath = fullfile(reviewDir, 'aging_kappa1_prediction_agent24d_bundle.zip');
if exist(zipPath, 'file') == 2, delete(zipPath); end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid > 0, fwrite(fid, txt); fclose(fid); end
end

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

function [rmse, rP, rS, yhat] = localLoocvIsotonic(x, y)
x = double(x(:));
y = double(y(:));
n = numel(y);
yhat = nan(n, 1);
for i = 1:n
    j = setdiff(1:n, i);
    xj = x(j);
    yj = y(j);
    [xu, ym] = localAggregateMean(xj, yj);
    if numel(xu) < 1
        yhat(i) = NaN;
        continue
    end
    if numel(xu) == 1
        yhat(i) = ym;
        continue
    end
    [xs, ord] = sort(xu);
    ys = ym(ord);
    rxy = corr(xs, ys, 'rows', 'complete');
    increasing = true;
    if isfinite(rxy) && rxy < 0
        increasing = false;
    end
    yiso = localPavaFit(ys, increasing);
    yhat(i) = interp1(xs, yiso, x(i), 'linear', 'extrap');
end
if any(~isfinite(yhat))
    rmse = NaN; rP = NaN; rS = NaN; return
end
rmse = sqrt(mean((y - yhat).^2));
rP = corr(y, yhat, 'rows', 'complete');
rS = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
end

function [xu, ym] = localAggregateMean(x, y)
[xu, ~, ic] = unique(x, 'stable');
ym = accumarray(ic, y, [], @mean);
end

function y_iso = localPavaFit(y, increasing)
y = y(:);
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

function opts = localParseOpts(varargin)
thisPath = mfilename('fullpath');
opts = struct();
opts.repoRoot = fileparts(fileparts(thisPath));
opts.clockRatioPath = fullfile(opts.repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_14_074613_aging_clock_ratio_analysis', 'tables', 'table_clock_ratio.csv');
opts.alphaStructurePath = fullfile(opts.repoRoot, 'tables', 'alpha_structure.csv');

if mod(numel(varargin), 2) ~= 0
    error('Name-value pairs expected');
end
for k = 1:2:numel(varargin)
    nm = lower(string(varargin{k}));
    val = varargin{k + 1};
    switch nm
        case "reporoot"
            opts.repoRoot = char(string(val));
        case "clockratiopath"
            opts.clockRatioPath = char(string(val));
        case "alphastructurepath"
            opts.alphaStructurePath = char(string(val));
        otherwise
            error('Unknown option: %s', varargin{k});
    end
end
end
