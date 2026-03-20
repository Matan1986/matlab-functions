function out = switching_creep_barrier_analysis(cfg)
% switching_creep_barrier_analysis
% Analyze whether X(T) = I_peak/(width*S_peak) is consistent with
% thermally activated barrier scaling using only saved observable tables.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg);
source = resolveSourceTable(repoRoot, cfg);
series = buildSeriesFromObservableTable(source.tablePath);

fprintf('Selected observable table: %s\n', char(source.tablePath));
fprintf('Column mapping: T<- %s, S_peak<- %s, I_peak<- %s, width<- %s\n', ...
    source.colMap.T, source.colMap.S_peak, source.colMap.I_peak, source.colMap.width);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('observable_table:%s', char(source.runName));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

appendLog(run.log_path, sprintf('[%s] switching_creep_barrier_analysis started', stampNow()));
appendLog(run.log_path, sprintf('Source run: %s', char(source.runName)));
appendLog(run.log_path, sprintf('Source table: %s', char(source.tablePath)));

fits = computeBarrierFits(series, cfg.muGrid);
fitTbl = buildFitSummaryTable(fits);
fitTblPath = save_run_table(fitTbl, 'switching_creep_barrier_fits.csv', runDir);

fig = buildDiagnosticFigure(series, fits);
figPaths = save_run_figure(fig, 'switching_creep_barrier_plots', runDir);
close(fig);

reportText = buildReport(source, series, fits, runDir, cfg);
reportPath = save_run_report(reportText, 'switching_creep_barrier_report.md', runDir);

appendLog(run.log_path, sprintf('Saved fit table: %s', fitTblPath));
appendLog(run.log_path, sprintf('Saved figure (png): %s', figPaths.png));
appendLog(run.log_path, sprintf('Saved report: %s', reportPath));
appendLog(run.log_path, sprintf('[%s] switching_creep_barrier_analysis complete', stampNow()));

out = struct();
out.runDir = string(runDir);
out.source = source;
out.series = series;
out.fits = fits;
out.outputs = struct( ...
    'fit_table', string(fitTblPath), ...
    'figure_png', string(figPaths.png), ...
    'report', string(reportPath));
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_creep_barrier_analysis');
cfg = setDefault(cfg, 'muGrid', 0.1:0.05:5.0);
end

function source = resolveSourceTable(repoRoot, cfg)
% Pick latest valid run table that contains required observable columns.
tableName = 'temperature_observable_bridge_table.csv';
candidates = dir(fullfile(repoRoot, 'results', '*', 'runs', 'run_*', 'tables', tableName));
if isempty(candidates)
    error('Could not find %s under results/*/runs.', tableName);
end

paths = strings(numel(candidates), 1);
runNames = strings(numel(candidates), 1);
runTs = NaT(numel(candidates), 1);
valid = false(numel(candidates), 1);
validRows = NaN(numel(candidates), 1);
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
        nValid = estimateValidRows(tbl, cols);
        colMaps{i} = cols;
        validRows(i) = nValid;
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
    error('Found %s files, but none include required columns: T, S_peak, I_peak, width.', tableName);
end

bestRows = max(validRows);
isBestRows = validRows == bestRows;

if any(isBestRows)
    bestPaths = paths(isBestRows);
    bestRuns = runNames(isBestRows);
    bestTs = runTs(isBestRows);
    bestMaps = colMaps(isBestRows);

    if all(isnat(bestTs))
        [~, idxLocal] = max(bestPaths);
    else
        [~, idxLocal] = max(bestTs);
    end

    selectedPath = bestPaths(idxLocal);
    selectedRun = bestRuns(idxLocal);
    selectedTs = bestTs(idxLocal);
    selectedMap = bestMaps{idxLocal};
else
    error('No suitable source table was found after alias resolution.');
end

source = struct();
source.tablePath = selectedPath;
source.runName = selectedRun;
source.runTimestamp = string(selectedTs);
source.colMap = selectedMap;
end

function series = buildSeriesFromObservableTable(tablePath)
tbl = readtable(tablePath, 'VariableNamingRule', 'preserve');
cols = resolveColNames(tbl);

T = double(tbl.(cols.T)(:));
S_peak = double(tbl.(cols.S_peak)(:));
I_peak = double(tbl.(cols.I_peak)(:));
width = double(tbl.(cols.width)(:));

X = I_peak ./ (width .* S_peak);
U_eff = -log(X);

valid = isfinite(T) & isfinite(S_peak) & isfinite(I_peak) & isfinite(width) ...
    & isfinite(X) & isfinite(U_eff) ...
    & T > 0 & width > 0 & S_peak > 0 & I_peak > 0 & X > 0;

if nnz(valid) < 4
    error('Too few valid rows after filtering. Need at least 4 points for fitting.');
end

[T, ord] = sort(T(valid));
S_peak = S_peak(valid);
I_peak = I_peak(valid);
width = width(valid);
X = X(valid);
U_eff = U_eff(valid);

series = struct();
series.T = T(:);
series.S_peak = S_peak(ord);
series.I_peak = I_peak(ord);
series.width = width(ord);
series.X = X(ord);
series.U_eff = U_eff(ord);
series.invT = 1 ./ series.T;
series.lnX = log(series.X);
series.logT = log(series.T);
series.logU = log(abs(series.U_eff));  % abs to handle X>1 where U_eff<0
end

function fits = computeBarrierFits(series, muGrid)
arr = fitFixedMu(series.T, series.U_eff, 1.0);
arr.model = "Arrhenius_U=a*T^{-1}";
arr.best_mu = 1.0;

pow = fitBestMu(series.T, series.U_eff, muGrid);
pow.model = "PowerLaw_U=a*T^{-mu}";

fits = struct();
fits.arrhenius = arr;
fits.powerlaw = pow;
end

function fit = fitFixedMu(T, U, mu)
x = T .^ (-mu);
a = fitSlopeThroughOrigin(x, U);
yhat = a .* x;
[r2, rmse] = calcFitStats(U, yhat);

fit = struct();
fit.mu = mu;
fit.a = a;
fit.yhat = yhat;
fit.r2 = r2;
fit.rmse = rmse;
fit.n_points = numel(U);
fit.parameter_values = sprintf('a=%.12g; mu=%.6g', a, mu);
end

function best = fitBestMu(T, U, muGrid)
best = struct('mu', NaN, 'a', NaN, 'yhat', NaN(size(U)), ...
    'r2', -Inf, 'rmse', NaN, 'n_points', numel(U), 'parameter_values', "", 'best_mu', NaN);

for mu = muGrid
    cur = fitFixedMu(T, U, mu);
    if isfinite(cur.r2) && cur.r2 > best.r2
        best = cur;
    end
end

if ~isfinite(best.r2)
    best = fitFixedMu(T, U, muGrid(1));
end
best.parameter_values = sprintf('a=%.12g; mu=%.6g', best.a, best.mu);
best.best_mu = best.mu;
end

function a = fitSlopeThroughOrigin(x, y)
den = sum(x .^ 2);
if den <= 0
    a = NaN;
else
    a = sum(x .* y) / den;
end
end

function [r2, rmse] = calcFitStats(y, yhat)
res = y - yhat;
rmse = sqrt(mean(res .^ 2, 'omitnan'));

ssRes = sum((y - yhat) .^ 2, 'omitnan');
ssTot = sum((y - mean(y, 'omitnan')) .^ 2, 'omitnan');
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
end

function tbl = buildFitSummaryTable(fits)
model = ["Arrhenius_U=a*T^{-1}"; "PowerLaw_U=a*T^{-mu}"];
parameter_values = [string(fits.arrhenius.parameter_values); string(fits.powerlaw.parameter_values)];
R2 = [fits.arrhenius.r2; fits.powerlaw.r2];
RMSE = [fits.arrhenius.rmse; fits.powerlaw.rmse];
best_mu = [NaN; fits.powerlaw.best_mu];

tbl = table(model, parameter_values, R2, RMSE, best_mu);
end

function fig = buildDiagnosticFigure(series, fits)
fig = create_figure('Position', [2 2 20 16]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Switching Creep Barrier Diagnostics (Observable-Only)');

T = series.T;
X = series.X;
U = series.U_eff;
invT = series.invT;
lnX = series.lnX;
logT = series.logT;
logU = series.logU;

arrU = fits.arrhenius.yhat;
powU = fits.powerlaw.yhat;
arrLnX = -arrU;

nexttile(tl, 1);
plot(T, X, 'o-', 'LineWidth', 1.4, 'MarkerSize', 5, 'Color', [0.00 0.45 0.74], ...
    'MarkerFaceColor', [0.00 0.45 0.74]);
xlabel('T (K)');
ylabel('X(T) = I_{peak}/(width*S_{peak})');
title('X(T) vs T');
grid on;

nexttile(tl, 2);
scatter(invT, lnX, 34, [0.20 0.20 0.20], 'filled');
hold on;
plot(invT, arrLnX, '-', 'LineWidth', 1.5, 'Color', [0.85 0.33 0.10]);
hold off;
xlabel('1/T (1/K)');
ylabel('ln(X)');
title(sprintf('ln(X) vs 1/T (Arrhenius R^2=%.3f)', fits.arrhenius.r2));
legend({'data', 'Arrhenius fit'}, 'Location', 'best');
grid on;

nexttile(tl, 3);
plot(T, U, 'o', 'MarkerSize', 5, 'Color', [0.20 0.20 0.20], 'MarkerFaceColor', [0.20 0.20 0.20]);
hold on;
plot(T, arrU, '-', 'LineWidth', 1.5, 'Color', [0.85 0.33 0.10]);
plot(T, powU, '--', 'LineWidth', 1.6, 'Color', [0.00 0.50 0.15]);
hold off;
xlabel('T (K)');
ylabel('U_{eff}(T) = -ln(X)');
title('U_{eff}(T) vs T');
legend({'data', 'Arrhenius fit', sprintf('Power-law fit (mu=%.2f)', fits.powerlaw.mu)}, 'Location', 'best');
grid on;

nexttile(tl, 4);
scatter(logT, logU, 34, [0.20 0.20 0.20], 'filled');
hold on;
if all(isfinite(powU) & powU ~= 0)
    plot(logT, log(abs(powU)), '--', 'LineWidth', 1.6, 'Color', [0.00 0.50 0.15]);
end
hold off;
xlabel('log(T)');
ylabel('log|U_{eff}|');
title(sprintf('log(U_{eff}) vs log(T), best mu=%.2f', fits.powerlaw.mu));
legend({'data', 'Power-law fit'}, 'Location', 'best');
grid on;
end

function reportText = buildReport(source, series, fits, runDir, cfg)
if fits.powerlaw.r2 > fits.arrhenius.r2
    bestModel = 'generalized power-law barrier';
else
    bestModel = 'Arrhenius-type barrier';
end

if numel(cfg.muGrid) >= 2
    muStep = cfg.muGrid(2) - cfg.muGrid(1);
else
    muStep = NaN;
end

lines = strings(0, 1);
lines(end + 1) = "# Switching Creep Barrier Analysis";
lines(end + 1) = "";
lines(end + 1) = "## Source";
lines(end + 1) = "- Source run used: `" + source.runName + "`";
lines(end + 1) = "- Observable table path: `" + source.tablePath + "`";
lines(end + 1) = "- Data points used: " + string(numel(series.T));
lines(end + 1) = "";
lines(end + 1) = "## Models Tested";
lines(end + 1) = "- Arrhenius-type scaling: U_eff(T) = a * T^{-1}";
lines(end + 1) = "- Generalized power-law barrier: U_eff(T) = a * T^{-mu}";
lines(end + 1) = "- Mu scan range: [" + string(cfg.muGrid(1)) + ", " + string(cfg.muGrid(end)) + "] with step " + string(muStep);
lines(end + 1) = "";
lines(end + 1) = "## Best-Fit Parameters";
lines(end + 1) = sprintf('- Arrhenius: a = %.12g, R^2 = %.6f, RMSE = %.6g', fits.arrhenius.a, fits.arrhenius.r2, fits.arrhenius.rmse);
lines(end + 1) = sprintf('- Power-law: a = %.12g, mu = %.6g, R^2 = %.6f, RMSE = %.6g', ...
    fits.powerlaw.a, fits.powerlaw.mu, fits.powerlaw.r2, fits.powerlaw.rmse);
lines(end + 1) = "";
lines(end + 1) = "## Model Comparison";
lines(end + 1) = sprintf('- Best model by R^2: %s', bestModel);
lines(end + 1) = sprintf('- Delta R^2 (power-law - Arrhenius): %.6f', fits.powerlaw.r2 - fits.arrhenius.r2);
lines(end + 1) = sprintf('- Delta RMSE (power-law - Arrhenius): %.6g', fits.powerlaw.rmse - fits.arrhenius.rmse);
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
if fits.powerlaw.r2 > fits.arrhenius.r2
    lines(end + 1) = "Power-law scaling provides a better empirical description of U_eff(T), indicating non-Arrhenius barrier behavior across the sampled temperatures.";
else
    lines(end + 1) = "Arrhenius scaling is competitive or better, consistent with approximately activated behavior for this observable coordinate.";
end
lines(end + 1) = "";
lines(end + 1) = "## Outputs";
lines(end + 1) = "- `tables/switching_creep_barrier_fits.csv`";
lines(end + 1) = "- `figures/switching_creep_barrier_plots.png`";
lines(end + 1) = "- `reports/switching_creep_barrier_report.md`";
lines(end + 1) = "";
lines(end + 1) = "## Run Directory";
lines(end + 1) = "`" + string(runDir) + "`";

reportText = strjoin(lines, newline);
end

function cols = resolveColNames(tbl)
% Map canonical field names to the actual column names present in the table.
vars = tbl.Properties.VariableNames;
colT  = pickAlias(vars, {'T', 'T_K', 'temperature'});
colS  = pickAlias(vars, {'S_peak', 'Speak'});
colIp = pickAlias(vars, {'I_peak', 'Ipeak'});
colW  = pickAlias(vars, {'width', 'width_I', 'widthI'});

if isempty(colT) || isempty(colS) || isempty(colIp) || isempty(colW)
    missing = {};
    if isempty(colT),  missing{end+1} = 'T|T_K|temperature'; end
    if isempty(colS),  missing{end+1} = 'S_peak|Speak'; end
    if isempty(colIp), missing{end+1} = 'I_peak|Ipeak'; end
    if isempty(colW),  missing{end+1} = 'width|width_I|widthI'; end
    error('resolveColNames: cannot find required columns. Missing: %s', strjoin(missing, ', '));
end

cols = struct('T', colT, 'I_peak', colIp, 'width', colW, 'S_peak', colS);
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
X = I_peak ./ (width .* S_peak);

valid = isfinite(T) & isfinite(S_peak) & isfinite(I_peak) & isfinite(width) ...
    & isfinite(X) & T > 0 & S_peak > 0 & I_peak > 0 & width > 0 & X > 0;
nValid = nnz(valid);
end
end

function [runName, runTs] = inferRunInfoFromPath(tablePath)
parts = split(string(strrep(tablePath, '/', filesep)), filesep);
runIdx = find(startsWith(parts, "run_"), 1, 'last');

if isempty(runIdx)
    runName = "unknown_run";
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
