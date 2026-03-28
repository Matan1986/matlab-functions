function out = switching_creep_scaling_test(cfg)
% switching_creep_scaling_test
% Test collective creep scaling by fitting log(X) vs log(T), where
% X(T) = I_peak / (width * S_peak), using saved observable bridge tables only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(repoRoot));

cfg = applyDefaults(cfg);
source = resolveSourceTable(repoRoot);
series = buildSeries(source.tablePath);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('observable_table:%s', char(source.runName));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

appendLog(run.log_path, sprintf('[%s] switching_creep_scaling_test started', stampNow()));
appendLog(run.log_path, sprintf('Source run: %s', char(source.runName)));
appendLog(run.log_path, sprintf('Source table: %s', char(source.tablePath)));
appendLog(run.log_path, sprintf('Column mapping: T<- %s, S_peak<- %s, I_peak<- %s, width<- %s', ...
    source.colMap.T, source.colMap.S_peak, source.colMap.I_peak, source.colMap.width));

fprintf('Selected observable table: %s\n', char(source.tablePath));
fprintf('Column mapping: T<- %s, S_peak<- %s, I_peak<- %s, width<- %s\n', ...
    source.colMap.T, source.colMap.S_peak, source.colMap.I_peak, source.colMap.width);

fit = fitLogLog(series.logT, series.logX);
fitTbl = table(fit.slope_b, fit.intercept_a, fit.gamma, fit.R2, fit.RMSE, fit.N_points);
fitTbl.Properties.VariableNames = {'slope_b', 'intercept_a', 'gamma', 'R2', 'RMSE', 'N_points'};
fitPath = save_run_table(fitTbl, 'switching_creep_scaling_fit.csv', runDir);

fig = buildFigure(series.logT, series.logX, fit);
[figPngPath, figPaths] = saveFigureWithFallback(fig, runDir, run.log_path);
close(fig);

reportText = buildReport(source, series, fit, runDir);
reportPath = save_run_report(reportText, 'switching_creep_scaling_report.md', runDir);

appendLog(run.log_path, sprintf('Saved fit table: %s', fitPath));
appendLog(run.log_path, sprintf('Saved figure PNG: %s', figPngPath));
if isfield(figPaths, 'pdf') && ~isempty(figPaths.pdf)
    appendLog(run.log_path, sprintf('Saved figure PDF: %s', figPaths.pdf));
end
if isfield(figPaths, 'fig') && ~isempty(figPaths.fig)
    appendLog(run.log_path, sprintf('Saved figure FIG: %s', figPaths.fig));
end
appendLog(run.log_path, sprintf('Saved report: %s', reportPath));
appendLog(run.log_path, sprintf('[%s] switching_creep_scaling_test complete', stampNow()));

out = struct();
out.runDir = string(runDir);
out.source = source;
out.series = series;
out.fit = fit;
out.outputs = struct('fit_table', string(fitPath), 'figure_png', string(figPaths.png), 'report', string(reportPath));
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_creep_scaling_test');
end

function source = resolveSourceTable(repoRoot)
tableName = 'temperature_observable_bridge_table.csv';
candidates = dir(fullfile(repoRoot, 'results', '*', 'runs', 'run_*', 'tables', tableName));
if isempty(candidates)
    error('Could not find %s under results/*/runs.', tableName);
end

paths = strings(numel(candidates), 1);
runNames = strings(numel(candidates), 1);
runTs = NaT(numel(candidates), 1);
validRows = NaN(numel(candidates), 1);
valid = false(numel(candidates), 1);
colMaps = cell(numel(candidates), 1);

for i = 1:numel(candidates)
    p = fullfile(candidates(i).folder, candidates(i).name);
    [runName, ts] = inferRunInfoFromPath(p);
    paths(i) = string(p);
    runNames(i) = runName;
    runTs(i) = ts;

    try
        tbl = readtable(p, 'VariableNamingRule', 'preserve');
        cols = resolveColNames(tbl);
        validRows(i) = estimateValidRows(tbl, cols);
        colMaps{i} = cols;
        valid(i) = true;
    catch
        valid(i) = false;
    end
end

paths = paths(valid);
runNames = runNames(valid);
runTs = runTs(valid);
validRows = validRows(valid);
colMaps = colMaps(valid);

if isempty(paths)
    error('Found %s files, but none include required aliases for T, S_peak, I_peak, width.', tableName);
end

bestRows = max(validRows);
bestMask = validRows == bestRows;
bestPaths = paths(bestMask);
bestRuns = runNames(bestMask);
bestTs = runTs(bestMask);
bestMaps = colMaps(bestMask);

if all(isnat(bestTs))
    [~, idx] = max(bestPaths);
else
    [~, idx] = max(bestTs);
end

source = struct();
source.tablePath = bestPaths(idx);
source.runName = bestRuns(idx);
source.runTimestamp = string(bestTs(idx));
source.colMap = bestMaps{idx};
end

function series = buildSeries(tablePath)
tbl = readtable(tablePath, 'VariableNamingRule', 'preserve');
cols = resolveColNames(tbl);

T = double(tbl.(cols.T)(:));
S_peak = double(tbl.(cols.S_peak)(:));
I_peak = double(tbl.(cols.I_peak)(:));
width = double(tbl.(cols.width)(:));

[canonicalT, canonicalX] = get_canonical_X();
% X is loaded from canonical run to avoid drift from duplicated implementations
X = interp1(canonicalT, canonicalX, T, 'linear', NaN);

valid = isfinite(T) & isfinite(S_peak) & isfinite(I_peak) & isfinite(width) & isfinite(X) ...
    & T > 0 & S_peak > 0 & I_peak > 0 & width > 0 & X > 0;

if nnz(valid) < 3
    error('Too few valid rows after filtering. Need at least 3 points for fitting.');
end

T = T(valid);
X = X(valid);
[T, ord] = sort(T);
X = X(ord);

series = struct();
series.T = T;
series.X = X;
series.logT = log(T);
series.logX = log(X);
series.N = numel(T);
end

function fit = fitLogLog(logT, logX)
p = polyfit(logT, logX, 1);
yhat = polyval(p, logT);

res = logX - yhat;
ssRes = sum(res .^ 2);
ssTot = sum((logX - mean(logX)) .^ 2);
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
rmse = sqrt(mean(res .^ 2));

fit = struct();
fit.slope_b = p(1);
fit.intercept_a = p(2);
fit.gamma = -p(1);
fit.R2 = r2;
fit.RMSE = rmse;
fit.N_points = numel(logT);
fit.yhat = yhat;
end

function fig = buildFigure(logT, logX, fit)
fig = create_figure('Position', [2 2 14 10]);
ax = axes(fig);
hold(ax, 'on');

scatter(ax, logT, logX, 42, [0.20 0.20 0.20], 'filled', 'DisplayName', 'data');
xs = linspace(min(logT), max(logT), 200);
ys = fit.intercept_a + fit.slope_b .* xs;
plot(ax, xs, ys, '-', 'LineWidth', 2.1, 'Color', [0.85 0.33 0.10], 'DisplayName', 'linear fit');

hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'log(T)');
ylabel(ax, 'log(X)');
title(ax, sprintf('log(X) vs log(T), gamma=%.4f, R^2=%.4f', fit.gamma, fit.R2));
legend(ax, 'Location', 'best');
end

function [pngPath, paths] = saveFigureWithFallback(fig, runDir, logPath)
paths = struct();
try
    paths = save_run_figure(fig, 'switching_creep_scaling_plot', runDir);
    if isfield(paths, 'png') && exist(paths.png, 'file') == 2
        pngPath = paths.png;
        return;
    end
catch ME
    appendLog(logPath, sprintf('save_run_figure warning: %s', ME.message));
end

figuresDir = fullfile(char(runDir), 'figures');
if exist(figuresDir, 'dir') ~= 7
    mkdir(figuresDir);
end
pngPath = fullfile(figuresDir, 'switching_creep_scaling_plot.png');
set(fig, 'Color', 'w');
exportgraphics(fig, pngPath, 'Resolution', 300);
appendLog(logPath, sprintf('Fallback PNG export used: %s', pngPath));
end

function reportText = buildReport(source, series, fit, runDir)
if isfinite(fit.R2) && fit.R2 >= 0.7
    linearity = 'appears approximately linear';
elseif isfinite(fit.R2) && fit.R2 >= 0.5
    linearity = 'shows moderate linear trend';
else
    linearity = 'does not appear strongly linear';
end

lines = strings(0, 1);
lines(end + 1) = '# Switching Creep Scaling Test';
lines(end + 1) = '';
lines(end + 1) = '## Source';
lines(end + 1) = '- Source run: `' + source.runName + '`';
lines(end + 1) = '- Source table path: `' + source.tablePath + '`';
lines(end + 1) = '- Points used: ' + string(series.N);
lines(end + 1) = '';
lines(end + 1) = '## Model';
lines(end + 1) = '- Fit: log(X) = a + b * log(T)';
lines(end + 1) = sprintf('- a (intercept) = %.12g', fit.intercept_a);
lines(end + 1) = sprintf('- b (slope) = %.12g', fit.slope_b);
lines(end + 1) = sprintf('- gamma = -b = %.12g', fit.gamma);
lines(end + 1) = sprintf('- R^2 = %.6f', fit.R2);
lines(end + 1) = sprintf('- RMSE = %.6g', fit.RMSE);
lines(end + 1) = '';
lines(end + 1) = '## Interpretation';
lines(end + 1) = sprintf('- log(X) vs log(T) %s.', linearity);
lines(end + 1) = '';
lines(end + 1) = '## Outputs';
lines(end + 1) = '- `tables/switching_creep_scaling_fit.csv`';
lines(end + 1) = '- `figures/switching_creep_scaling_plot.png`';
lines(end + 1) = '- `reports/switching_creep_scaling_report.md`';
lines(end + 1) = '';
lines(end + 1) = '## Run Directory';
lines(end + 1) = '`' + string(runDir) + '`';

reportText = strjoin(lines, newline);
end

function cols = resolveColNames(tbl)
vars = tbl.Properties.VariableNames;

% Required mapping:
% T      <- {T, T_K, temperature}
% S_peak <- {S_peak, Speak}
% I_peak <- {I_peak, Ipeak}
% width  <- {width, width_I, widthI}
colT = pickAlias(vars, {'T', 'T_K', 'temperature', 'temperature_K'});
colS = pickAlias(vars, {'S_peak', 'Speak'});
colI = pickAlias(vars, {'I_peak', 'Ipeak', 'I_peak_mA', 'Ipeak_mA'});
colW = pickAlias(vars, {'width', 'width_I', 'widthI', 'width_mA'});

if isempty(colT) || isempty(colS) || isempty(colI) || isempty(colW)
    missing = {};
    if isempty(colT), missing{end + 1} = 'T|T_K|temperature|temperature_K'; end
    if isempty(colS), missing{end + 1} = 'S_peak|Speak'; end
    if isempty(colI), missing{end + 1} = 'I_peak|Ipeak|I_peak_mA|Ipeak_mA'; end
    if isempty(colW), missing{end + 1} = 'width|width_I|widthI|width_mA'; end
    error('resolveColNames failed. Missing aliases: %s', strjoin(missing, ', '));
end

cols = struct('T', colT, 'S_peak', colS, 'I_peak', colI, 'width', colW);
end

function name = pickAlias(vars, aliases)
name = '';
idx = find(ismember(vars, aliases), 1, 'first');
if ~isempty(idx)
    name = vars{idx};
    return;
end

varsLower = lower(string(vars));
aliasesLower = lower(string(aliases));
idxLower = find(ismember(varsLower, aliasesLower), 1, 'first');
if ~isempty(idxLower)
    name = vars{idxLower};
end
end

function nValid = estimateValidRows(tbl, cols)
T = double(tbl.(cols.T)(:));
S_peak = double(tbl.(cols.S_peak)(:));
I_peak = double(tbl.(cols.I_peak)(:));
width = double(tbl.(cols.width)(:));
[canonicalT, canonicalX] = get_canonical_X();
% X is loaded from canonical run to avoid drift from duplicated implementations
X = interp1(canonicalT, canonicalX, T, 'linear', NaN);

valid = isfinite(T) & isfinite(S_peak) & isfinite(I_peak) & isfinite(width) & isfinite(X) ...
    & T > 0 & S_peak > 0 & I_peak > 0 & width > 0 & X > 0;

nValid = nnz(valid);
end

function [runName, runTs] = inferRunInfoFromPath(tablePath)
parts = split(string(strrep(tablePath, '/', filesep)), filesep);
runIdx = find(startsWith(parts, 'run_'), 1, 'last');
if isempty(runIdx)
    runName = 'unknown_run';
    runTs = NaT;
    return;
end

runName = parts(runIdx);
tok = regexp(char(runName), '^run_(\d{4})_(\d{2})_(\d{2})_(\d{6})(?:_|$)', 'tokens', 'once');
if isempty(tok)
    runTs = NaT;
    return;
end

tsText = sprintf('%s-%s-%s %s:%s:%s', tok{1}, tok{2}, tok{3}, tok{4}(1:2), tok{4}(3:4), tok{4}(5:6));
runTs = datetime(tsText, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end

function appendLog(pathText, lineText)
fid = fopen(pathText, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', lineText);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
