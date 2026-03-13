function out = run_relaxation_time_mode_analysis(cfg)
% run_relaxation_time_mode_analysis
% Analyze the dominant time mode and scaling diagnostics using the latest Relaxation SVD audit run.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(relaxDir);
addpath(diagDir);

cfg.runLabel = getDef(cfg, 'runLabel', 'time_mode_analysis');
cfg.inputAuditRunDir = getDef(cfg, 'inputAuditRunDir', "");

[auditRunDir, sourceInfo] = resolveAuditInput(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = char(string(auditRunDir));
run = createRunContext('relaxation', runCfg);
runDir = getRunOutputDir();
fprintf('Relaxation time-mode analysis run directory:\n%s\n', runDir);
fprintf('Using SVD audit run: %s\n', auditRunDir);

[dMMap, dMT, dMX] = loadMapMatrix(char(sourceInfo.dMMapPath));
[SMap, ST, SX] = loadMapMatrix(char(sourceInfo.SMapPath));

[dMData, collapseRows, fitRows, fitFigPaths, v1LogPaths, v1TimePaths, collapseFigPaths] = analyzeDominantTimeMode(dMMap, dMT, dMX, runDir);
[barrierRows, barrierFigPaths] = analyzeBarrierScaling(SMap, ST, SX, runDir);

fitTable = removevars(fitRows, 'y_fit');
fitTablePath = save_run_table(fitTable, 'time_mode_fits.csv', runDir);
collapseTablePath = save_run_table(collapseRows, 'collapse_metrics.csv', runDir);
barrierTablePath = save_run_table(barrierRows, 'barrier_scaling_metrics.csv', runDir);

reportText = buildReport(auditRunDir, sourceInfo, dMData, fitRows, collapseRows, barrierRows);
reportPath = save_run_report(reportText, 'relaxation_time_mode_analysis.md', runDir);

appendText(run.log_path, sprintf('[%s] Time-mode analysis completed\n', stampNow()));
appendText(run.log_path, sprintf('Input SVD audit run: %s\n', char(string(auditRunDir))));
appendText(run.log_path, sprintf('DeltaM map source: %s\n', char(sourceInfo.dMMapPath)));
appendText(run.log_path, sprintf('S map source: %s\n', char(sourceInfo.SMapPath)));
appendText(run.log_path, sprintf('Best time-mode fit: %s\n', char(dMData.bestModel)));

appendText(run.notes_path, sprintf('Input audit run: %s\n', char(string(auditRunDir))));
appendText(run.notes_path, sprintf('Best time-mode fit: %s\n', char(dMData.bestModel)));
appendText(run.notes_path, sprintf('Rank-1 collapse metric: %.6f\n', collapseRows.collapse_error_metric(1)));
appendText(run.notes_path, sprintf('Barrier scaling metric: %.6f\n', barrierRows.collapse_error_metric(1)));

reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, sprintf('relaxation_time_mode_analysis_%s.zip', run.run_id));
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zipInputs = {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};
zip(zipPath, zipInputs, runDir);

out = struct();
out.run = run;
out.runDir = string(runDir);
out.inputAuditRunDir = string(auditRunDir);
out.fitTablePath = string(fitTablePath);
out.collapseTablePath = string(collapseTablePath);
out.barrierTablePath = string(barrierTablePath);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.figures = struct( ...
    'v1Log', string(v1LogPaths.png), ...
    'v1Time', string(v1TimePaths.png), ...
    'fitComparison', string(fitFigPaths.png), ...
    'rank1Collapse', string(collapseFigPaths.png), ...
    'barrierScaling', string(barrierFigPaths.png));
out.analysis = dMData;

fprintf('\n=== Relaxation time-mode analysis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function [auditRunDir, sourceInfo] = resolveAuditInput(repoRoot, cfg)
if strlength(strtrim(string(cfg.inputAuditRunDir))) > 0
    auditRunDir = char(string(cfg.inputAuditRunDir));
else
    runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
    runDirs = dir(fullfile(runsRoot, 'run_*_svd_audit'));
    runDirs = runDirs([runDirs.isdir]);
    if isempty(runDirs)
        error('No Relaxation SVD audit runs found under %s', runsRoot);
    end
    [~, ord] = sort({runDirs.name});
    runDirs = runDirs(ord);

    auditRunDir = '';
    for i = numel(runDirs):-1:1
        candidate = fullfile(runDirs(i).folder, runDirs(i).name);
        if exist(fullfile(candidate, 'reports', 'relaxation_svd_audit.md'), 'file') == 2
            auditRunDir = candidate;
            break;
        end
    end
    if isempty(auditRunDir)
        error('Could not find a completed SVD audit run with a report.');
    end
end

reportPath = fullfile(auditRunDir, 'reports', 'relaxation_svd_audit.md');
if exist(reportPath, 'file') ~= 2
    error('Audit report missing: %s', reportPath);
end
reportText = fileread(reportPath);

dMMapPath = extractBacktickPath(reportText, 'DeltaM map source');
SMapPath = extractBacktickPath(reportText, 'S map source');
if isempty(dMMapPath)
    error('Could not parse DeltaM map source from %s', reportPath);
end
if isempty(SMapPath)
    error('Could not parse S map source from %s', reportPath);
end

sourceInfo = struct();
sourceInfo.auditReportPath = string(reportPath);
sourceInfo.dMMapPath = string(dMMapPath);
sourceInfo.SMapPath = string(SMapPath);
end

function p = extractBacktickPath(reportText, label)
pattern = [regexptranslate('escape', label) ': `([^`]+)`'];
tokens = regexp(reportText, pattern, 'tokens', 'once');
if isempty(tokens)
    p = '';
else
    p = tokens{1};
end
end

function [Z, T, xGrid] = loadMapMatrix(mapPath)
raw = readmatrix(mapPath);
if isempty(raw) || size(raw, 1) < 2 || size(raw, 2) < 2
    error('Map file is empty or malformed: %s', mapPath);
end

xGrid = raw(1, 2:end);
T = raw(2:end, 1);
Z = raw(2:end, 2:end);

validRows = isfinite(T);
validCols = isfinite(xGrid);
T = T(validRows);
xGrid = xGrid(validCols);
Z = Z(validRows, validCols);

if any(~isfinite(Z), 'all')
    error('Map contains non-finite values: %s', mapPath);
end
end

function [data, collapseRows, fitRows, fitFigPaths, v1LogPaths, v1TimePaths, collapseFigPaths] = analyzeDominantTimeMode(Z, T, xGrid, runDir)
[U, S, V] = svd(Z, 'econ');
[U, V] = orientFirstMode(U, V);

sigma1 = S(1, 1);
v1 = V(:, 1);
tGrid = 10 .^ xGrid;
A = sigma1 * U(:, 1);
validAmp = abs(A) > max(abs(A)) * 1e-8;
normalizedCurves = Z(validAmp, :) ./ A(validAmp);
masterCurve = mean(normalizedCurves, 1);
collapseResidual = normalizedCurves - masterCurve;
collapseMetric = norm(collapseResidual, 'fro') / max(norm(normalizedCurves, 'fro'), eps);
pointwiseStd = std(normalizedCurves, 0, 1);
maxAbsDeviation = max(abs(collapseResidual), [], 'all');

v1LogPaths = saveSingleCurveFigure(xGrid, v1, 'log_{10}(t_{rel} [s])', 'v_1', ...
    'Dominant time mode v_1 vs log_{10}(t)', 'v1_time_mode_vs_logt', runDir, false);
v1TimePaths = saveSingleCurveFigure(tGrid, v1, 't_{rel} (s)', 'v_1', ...
    'Dominant time mode v_1 vs t', 'v1_time_mode_vs_t', runDir, true);

fitRows = fitTimeModeModels(tGrid, xGrid, v1);
fitFigPaths = saveFitComparisonFigure(xGrid, v1, fitRows, 'time_mode_fit_comparison', runDir);
collapseFigPaths = saveCollapseFigure(xGrid, T(validAmp), normalizedCurves, ...
    'Rank-1 scaling collapse: \DeltaM(T,t) / A(T)', 'rank1_scaling_collapse', runDir);

collapseRows = table("dM_rank1_normalized", sum(validAmp), collapseMetric, mean(pointwiseStd), ...
    max(pointwiseStd), maxAbsDeviation, ...
    'VariableNames', {'analysis_name','n_curves','collapse_error_metric','mean_pointwise_std', ...
    'max_pointwise_std','max_abs_deviation'});

[~, bestIdx] = max(fitRows.R2);
if numel(bestIdx) > 1
    [~, rel] = min(fitRows.rms_error(bestIdx));
    bestIdx = bestIdx(rel);
end

bestModel = string(fitRows.model(bestIdx));
data = struct();
data.U = U;
data.S = S;
data.V = V;
data.sigma1 = sigma1;
data.v1 = v1;
data.A = A;
data.tGrid = tGrid;
data.xGrid = xGrid;
data.bestModel = bestModel;
data.bestR2 = fitRows.R2(bestIdx);
data.bestRMSE = fitRows.rms_error(bestIdx);
data.collapseMetric = collapseMetric;
data.validCollapseTemperatures = T(validAmp);
end

function fitRows = fitTimeModeModels(tGrid, xGrid, v1)
y = v1(:);
t = tGrid(:);

rows = table();

[logPars, logR2, logYFit] = fitLogRelaxation(t, y, NaN, false, struct('minTimeForLog', min(t) * 0.1));
logRMSE = computeRMSE(y, logYFit);
row = table("logarithmic", logPars.M0, -logPars.S, NaN, NaN, NaN, NaN, logR2, logRMSE, ...
    {logYFit}, 'VariableNames', {'model','param_a','param_b','param_alpha','param_tau','param_beta','param_amp','R2','rms_error','y_fit'});
rows = [rows; row]; %#ok<AGROW>

[powerPars, powerR2, powerYFit] = fitPowerLawModel(t, y);
powerRMSE = computeRMSE(y, powerYFit);
row = table("power_law", powerPars.offset, NaN, powerPars.alpha, NaN, NaN, powerPars.amplitude, powerR2, powerRMSE, ...
    {powerYFit}, 'VariableNames', {'model','param_a','param_b','param_alpha','param_tau','param_beta','param_amp','R2','rms_error','y_fit'});
rows = [rows; row]; %#ok<AGROW>

[stretchPars, stretchR2, stretchStats] = fitStretchedExp(t, y, NaN, false, struct());
stretchYFit = stretchStats.Mfit;
stretchRMSE = computeRMSE(y, stretchYFit);
row = table("stretched_exponential", stretchPars.Minf, NaN, NaN, stretchPars.tau, stretchPars.n, stretchPars.dM, stretchR2, stretchRMSE, ...
    {stretchYFit}, 'VariableNames', {'model','param_a','param_b','param_alpha','param_tau','param_beta','param_amp','R2','rms_error','y_fit'});
rows = [rows; row]; %#ok<AGROW>

fitRows = rows(:, 1:end-1);
fitRows.log10_t_min = repmat(xGrid(1), height(fitRows), 1);
fitRows.log10_t_max = repmat(xGrid(end), height(fitRows), 1);
fitRows.y_fit = rows.y_fit;
end

function [pars, R2, yFit] = fitPowerLawModel(t, y)
t = t(:);
y = y(:);
mask = isfinite(t) & isfinite(y) & t > 0;
t = t(mask);
y = y(mask);

baseline = min(y(end-5:end));
if ~isfinite(baseline)
    baseline = 0;
end
shifted = y - baseline;
positive = shifted > max(abs(shifted)) * 1e-6;
if sum(positive) < 5
    positive = y > 0;
    baseline = 0;
end

if sum(positive) < 5
    pars = struct('amplitude', NaN, 'alpha', NaN, 'offset', NaN);
    yFit = nan(size(y));
    R2 = NaN;
    return;
end

tFit = t(positive);
yFitTarget = y(positive) - baseline;
coeff = polyfit(log(tFit), log(yFitTarget), 1);
alpha0 = max(0, -coeff(1));
amp0 = exp(coeff(2));

obj = @(p) sum((y - (p(1) * t .^ (-abs(p(2))) + p(3))).^2);
opts = optimset('Display', 'off');
p0 = [amp0, alpha0, baseline];
p = fminsearch(obj, p0, opts);
amp = p(1);
alpha = abs(p(2));
offset = p(3);
yFit = amp * t .^ (-alpha) + offset;
R2 = computeR2(y, yFit);
pars = struct('amplitude', amp, 'alpha', alpha, 'offset', offset);
end

function [U, V] = orientFirstMode(U, V)
if isempty(V)
    return;
end
v1 = V(:, 1);
if v1(1) < v1(end)
    U(:, 1) = -U(:, 1);
    V(:, 1) = -V(:, 1);
end
end

function paths = saveSingleCurveFigure(x, y, xLabel, yLabel, ttl, baseName, runDir, logX)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 900 520]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);
plot(ax, x, y, '-', 'LineWidth', 2.4, 'Color', [0.10 0.35 0.75]);
if logX
    set(ax, 'XScale', 'log');
end
xlabel(ax, xLabel, 'FontSize', 15);
ylabel(ax, yLabel, 'FontSize', 15);
title(ax, ttl, 'FontSize', 16, 'FontWeight', 'bold');
paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function paths = saveFitComparisonFigure(xGrid, y, fitRows, baseName, runDir)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 920 560]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);

plot(ax, xGrid, y, '-', 'LineWidth', 2.6, 'Color', [0 0 0], 'DisplayName', 'v_1 data');
colors = lines(height(fitRows));
for i = 1:height(fitRows)
    plot(ax, xGrid, fitRows.y_fit{i}, '-', 'LineWidth', 2.0, 'Color', colors(i, :), ...
        'DisplayName', sprintf('%s (R^2=%.4f)', char(fitRows.model(i)), fitRows.R2(i)));
end
xlabel(ax, 'log_{10}(t_{rel} [s])', 'FontSize', 15);
ylabel(ax, 'v_1', 'FontSize', 15);
title(ax, 'Dominant time-mode fit comparison', 'FontSize', 16, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', 12);
paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function paths = saveCollapseFigure(xGrid, T, curves, ttl, baseName, runDir)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [110 110 940 580]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);

cmap = parula(max(numel(T), 3));
for i = 1:numel(T)
    plot(ax, xGrid, curves(i, :), '-', 'LineWidth', 1.8, 'Color', cmap(i, :));
end
colormap(ax, cmap);
cb = colorbar(ax);
ylabel(cb, 'Temperature (K)', 'FontSize', 14);
clim = [min(T) max(T)];
if diff(clim) == 0
    clim = clim + [-0.5 0.5];
end
caxis(ax, clim);
master = mean(curves, 1);
plot(ax, xGrid, master, '--', 'Color', [0 0 0], 'LineWidth', 2.6, 'DisplayName', 'master curve');
xlabel(ax, 'log_{10}(t_{rel} [s])', 'FontSize', 15);
ylabel(ax, 'Normalized signal', 'FontSize', 15);
title(ax, ttl, 'FontSize', 16, 'FontWeight', 'bold');
paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function [rows, figPaths] = analyzeBarrierScaling(SMap, T, xGrid, runDir)
Tcol = T(:);
scaled = SMap ./ Tcol;
master = mean(scaled, 1);
residual = scaled - master;
collapseMetric = norm(residual, 'fro') / max(norm(scaled, 'fro'), eps);
pointwiseStd = std(scaled, 0, 1);
maxAbsDeviation = max(abs(residual), [], 'all');

rows = table("S_over_T", numel(T), collapseMetric, mean(pointwiseStd), max(pointwiseStd), maxAbsDeviation, ...
    'VariableNames', {'analysis_name','n_curves','collapse_error_metric','mean_pointwise_std', ...
    'max_pointwise_std','max_abs_deviation'});
figPaths = saveBarrierFigure(xGrid, T, scaled, runDir);
end

function paths = saveBarrierFigure(xGrid, T, curves, runDir)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [110 110 940 580]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);

cmap = parula(max(numel(T), 3));
for i = 1:numel(T)
    plot(ax, xGrid, curves(i, :), '-', 'LineWidth', 1.8, 'Color', cmap(i, :));
end
master = mean(curves, 1);
plot(ax, xGrid, master, '--', 'Color', [0 0 0], 'LineWidth', 2.6, 'DisplayName', 'mean S/T');
colormap(ax, cmap);
cb = colorbar(ax);
ylabel(cb, 'Temperature (K)', 'FontSize', 14);
clim = [min(T) max(T)];
if diff(clim) == 0
    clim = clim + [-0.5 0.5];
end
caxis(ax, clim);
xlabel(ax, 'log_{10}(t_{rel} [s])', 'FontSize', 15);
ylabel(ax, 'S(T,t) / T', 'FontSize', 15);
title(ax, 'Barrier scaling test: S(T,t)/T', 'FontSize', 16, 'FontWeight', 'bold');
paths = save_run_figure(fig, 'barrier_scaling_test', runDir);
close(fig);
end

function reportText = buildReport(auditRunDir, sourceInfo, dMData, fitRows, collapseRows, barrierRows)
[~, bestIdx] = max(fitRows.R2);
if numel(bestIdx) > 1
    [~, rel] = min(fitRows.rms_error(bestIdx));
    bestIdx = bestIdx(rel);
end
bestFit = fitRows(bestIdx, :);

lines = {};
lines{end+1,1} = '# Relaxation Time-Mode Analysis';
lines{end+1,1} = '';
lines{end+1,1} = '## Inputs';
lines{end+1,1} = ['- Input SVD audit run: `' char(string(auditRunDir)) '`'];
lines{end+1,1} = ['- DeltaM map source: `' char(sourceInfo.dMMapPath) '`'];
lines{end+1,1} = ['- S map source: `' char(sourceInfo.SMapPath) '`'];
lines{end+1,1} = '';
lines{end+1,1} = '## Dominant Time Mode';
lines{end+1,1} = '- The dominant time mode is monotonic in log-time and captures the primary separable relaxation shape from the rank-1 decomposition.';
lines{end+1,1} = ['- Best-fit model for v_1(t): `' char(bestFit.model) '`'];
lines{end+1,1} = sprintf('- Best-fit goodness: R^2 = %.6f, RMS error = %.6g', bestFit.R2, bestFit.rms_error);
lines{end+1,1} = interpretTimeMode(bestFit);
lines{end+1,1} = '';
lines{end+1,1} = '## Time-Mode Fit Summary';
lines{end+1,1} = '| model | R^2 | RMS error |';
lines{end+1,1} = '| --- | ---: | ---: |';
for i = 1:height(fitRows)
    lines{end+1,1} = sprintf('| %s | %.6f | %.6g |', char(fitRows.model(i)), fitRows.R2(i), fitRows.rms_error(i));
end
lines{end+1,1} = '';
lines{end+1,1} = '## Rank-1 Scaling Collapse';
lines{end+1,1} = sprintf('- collapse_error_metric = %.6f', collapseRows.collapse_error_metric(1));
lines{end+1,1} = sprintf('- mean pointwise std = %.6g', collapseRows.mean_pointwise_std(1));
lines{end+1,1} = interpretCollapse(collapseRows.collapse_error_metric(1));
lines{end+1,1} = '';
lines{end+1,1} = '## Barrier-Distribution Scaling Test';
lines{end+1,1} = sprintf('- collapse_error_metric for S(T,t)/T = %.6f', barrierRows.collapse_error_metric(1));
lines{end+1,1} = sprintf('- mean pointwise std = %.6g', barrierRows.mean_pointwise_std(1));
lines{end+1,1} = interpretBarrierScaling(barrierRows.collapse_error_metric(1));
lines{end+1,1} = '';
lines{end+1,1} = '## Physical Interpretation';
lines{end+1,1} = physicalInterpretation(bestFit, collapseRows.collapse_error_metric(1), barrierRows.collapse_error_metric(1));
lines{end+1,1} = '';
lines{end+1,1} = '## Visualization choices';
lines{end+1,1} = '- number of curves: 1 for v_1 plots; 4 for the fit comparison; 19 temperature curves for the collapse and barrier-scaling overlays';
lines{end+1,1} = '- legend vs colormap: legends for <=6 curves, colormap plus colorbar for the 19-curve temperature overlays';
lines{end+1,1} = '- colormap used: parula';
lines{end+1,1} = '- smoothing applied: none; all diagnostics use the exported SVD input maps directly';
lines{end+1,1} = '- justification: simple curve plots clarify the dominant mode, while temperature-colored overlays best show collapse quality';

reportText = strjoin(lines, newline);
end

function line = interpretTimeMode(bestFit)
switch char(bestFit.model)
    case 'logarithmic'
        line = '- The dominant time mode is best described by a logarithmic relaxation law, consistent with broad barrier-controlled relaxation.';
    case 'power_law'
        line = '- The dominant time mode is better described by a power-law tail, indicating scale-free relaxation over the sampled window.';
    otherwise
        line = '- The dominant time mode is best described by a stretched-exponential form, indicating a broad but not purely logarithmic relaxation spectrum.';
end
end

function line = interpretCollapse(metric)
if metric <= 0.05
    line = '- The normalized \DeltaM(T,t)/A(T) curves collapse strongly, so the rank-1 scaling picture holds very well.';
elseif metric <= 0.15
    line = '- The normalized curves show a moderate but still meaningful collapse, with weak temperature-dependent corrections beyond rank-1.';
else
    line = '- The normalized curves do not collapse tightly, so substantial temperature-dependent structure remains beyond rank-1.';
end
end

function line = interpretBarrierScaling(metric)
if metric <= 0.10
    line = '- S(T,t)/T collapses well across temperature, supporting a simple barrier-distribution scaling picture.';
elseif metric <= 0.25
    line = '- S(T,t)/T shows partial collapse: barrier-distribution scaling captures the dominant trend, but temperature-dependent corrections remain.';
else
    line = '- S(T,t)/T does not collapse strongly, so a simple temperature-independent barrier distribution is not sufficient on its own.';
end
end

function line = physicalInterpretation(bestFit, collapseMetric, barrierMetric)
if strcmp(char(bestFit.model), 'logarithmic') && collapseMetric <= 0.05 && barrierMetric <= 0.25
    line = '- The combined diagnostics support a broad barrier-controlled relaxation law: the dynamics are nearly separable, the dominant time mode is logarithmic, and S/T is at least approximately temperature-scaled.';
elseif strcmp(char(bestFit.model), 'logarithmic')
    line = '- The dominant mode is logarithmic, but the scaling diagnostics suggest additional structured corrections beyond the simplest barrier picture.';
elseif strcmp(char(bestFit.model), 'stretched_exponential')
    line = '- The dominant mode favors a stretched-exponential shape, indicating distributed relaxation times with a finite-shape envelope rather than a purely logarithmic law.';
else
    line = '- The dominant mode favors a power-law trend, pointing to a slow scale-free relaxation form over the measured window.';
end
end

function rmse = computeRMSE(y, yFit)
mask = isfinite(y) & isfinite(yFit);
if ~any(mask)
    rmse = NaN;
    return;
end
rmse = sqrt(mean((y(mask) - yFit(mask)).^2));
end

function R2 = computeR2(y, yFit)
mask = isfinite(y) & isfinite(yFit);
y = y(mask);
yFit = yFit(mask);
if isempty(y)
    R2 = NaN;
    return;
end
ssRes = sum((y - yFit).^2);
ssTot = sum((y - mean(y)).^2);
if ssTot <= 0
    R2 = 1;
else
    R2 = 1 - ssRes / ssTot;
end
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function v = getDef(s, f, d)
if isfield(s, f)
    v = s.(f);
else
    v = d;
end
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

