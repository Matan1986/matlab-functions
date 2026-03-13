function out = activation_coordinate_test(cfg)
% activation_coordinate_test
% Test whether X(T) = I_peak(T) / (width(T) * S_peak(T)) behaves like an
% activation coordinate for the saved relaxation activity observable A(T).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | switch:%s', char(source.relaxRunName), char(source.switchRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Activation-coordinate test run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Switching source run: %s\n', source.switchRunName);

appendText(run.log_path, sprintf('[%s] activation-coordinate test started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));

relax = loadRelaxationData(source.relaxRunDir);
switching = loadSwitchingData(source.switchRunDir, cfg);
aligned = buildAlignedData(relax, switching, cfg);
fitSummaryTbl = buildFitSummaryTable(aligned);
manifestTbl = buildSourceManifestTable(source);

alignedPath = save_run_table(aligned.table, 'activation_coordinate_aligned_data.csv', runDir);
fitPath = save_run_table(fitSummaryTbl, 'activation_coordinate_fit_summary.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

fig1 = savePrimaryScatterFigure(aligned, fitSummaryTbl, runDir, 'ln_A_vs_X');
fig2 = saveRawScatterFigure(aligned, fitSummaryTbl, runDir, 'A_vs_X');
fig3 = saveLogLogScatterFigure(aligned, fitSummaryTbl, runDir, 'ln_A_vs_ln_X');
fig4 = saveOverlayFigure(aligned, runDir, 'normalized_A_and_X_vs_temperature');

reportText = buildReportText(source, aligned, fitSummaryTbl, cfg);
reportPath = save_run_report(reportText, 'activation_coordinate_analysis.md', runDir);
zipPath = buildReviewZip(runDir, 'activation_coordinate_test_bundle.zip');

primaryRow = fitSummaryTbl(fitSummaryTbl.model_key == "ln_A_vs_X", :);
appendText(run.notes_path, sprintf('Composite coordinate = I_peak / (width * S_peak)\n'));
appendText(run.notes_path, sprintf('Common grid = switching temperatures, interpolation = %s\n', cfg.interpMethod));
appendText(run.notes_path, sprintf('Temperature range = %.1f-%.1f K (%d points)\n', min(aligned.T_K), max(aligned.T_K), height(aligned.table)));
appendText(run.notes_path, sprintf('Primary fit slope a = %.6g\n', primaryRow.slope(1)));
appendText(run.notes_path, sprintf('Primary fit intercept b = %.6g\n', primaryRow.intercept(1)));
appendText(run.notes_path, sprintf('Primary fit R^2 = %.6g\n', primaryRow.r_squared(1)));
appendText(run.notes_path, sprintf('Primary Pearson = %.6g\n', primaryRow.pearson_r(1)));
appendText(run.notes_path, sprintf('Primary Spearman = %.6g\n', primaryRow.spearman_r(1)));

appendText(run.log_path, sprintf('[%s] activation-coordinate test complete\n', stampNow()));
appendText(run.log_path, sprintf('Aligned table: %s\n', alignedPath));
appendText(run.log_path, sprintf('Fit summary: %s\n', fitPath));
appendText(run.log_path, sprintf('Manifest: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.aligned = aligned;
out.fitSummary = fitSummaryTbl;
out.tables = struct('aligned', string(alignedPath), 'fit', string(fitPath), 'manifest', string(manifestPath));
out.figures = struct('lnA_vs_X', string(fig1.png), 'A_vs_X', string(fig2.png), 'lnA_vs_lnX', string(fig3.png), 'overlay', string(fig4.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Activation-coordinate test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('ln(A) = a X + b: a = %.4g, b = %.4g, R^2 = %.4f\n', primaryRow.slope(1), primaryRow.intercept(1), primaryRow.r_squared(1));
fprintf('Pearson = %.4f, Spearman = %.4f\n', primaryRow.pearson_r(1), primaryRow.spearman_r(1));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'activation_coordinate_test');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'contextRunName', 'run_2026_03_13_071713_switching_composite_observable_scan');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.relaxRunName = string(cfg.relaxRunName);
source.switchRunName = string(cfg.switchRunName);
source.contextRunName = string(cfg.contextRunName);
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.contextRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.contextRunName));
source.relaxPath = fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
source.switchPath = fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv');
source.contextPath = fullfile(char(source.contextRunDir), 'tables', 'correlation_summary.csv');

requiredFiles = {source.relaxRunDir, source.relaxPath; source.switchRunDir, source.switchPath};
for i = 1:size(requiredFiles, 1)
    if exist(requiredFiles{i, 1}, 'dir') ~= 7
        error('Required source run directory not found: %s', requiredFiles{i, 1});
    end
    if exist(requiredFiles{i, 2}, 'file') ~= 2
        error('Required source file not found: %s', requiredFiles{i, 2});
    end
end
end

function relax = loadRelaxationData(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
tbl = sortrows(tbl, 'T');
relax = struct();
relax.T = tbl.T(:);
relax.A = tbl.A_T(:);
end

function switching = loadSwitchingData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'switching_full_scaling_parameters.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
mask = mask & isfinite(tbl.Ipeak_mA) & isfinite(tbl.width_chosen_mA) & isfinite(tbl.S_peak);
tbl = sortrows(tbl(mask, :), 'T_K');

switching = struct();
switching.T = tbl.T_K(:);
switching.I_peak_mA = tbl.Ipeak_mA(:);
switching.width_mA = tbl.width_chosen_mA(:);
switching.S_peak = tbl.S_peak(:);
end

function aligned = buildAlignedData(relax, switching, cfg)
T = switching.T(:);
A = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
X = switching.I_peak_mA ./ (switching.width_mA .* switching.S_peak);
mask = isfinite(T) & isfinite(A) & isfinite(X) & A > 0 & X > 0;
if nnz(mask) < 3
    error('Too few valid points remain after interpolation and positivity checks.');
end

aligned = struct();
aligned.T_K = T(mask);
aligned.A = A(mask);
aligned.lnA = log(aligned.A);
aligned.I_peak_mA = switching.I_peak_mA(mask);
aligned.width_mA = switching.width_mA(mask);
aligned.S_peak = switching.S_peak(mask);
aligned.X = X(mask);
aligned.lnX = log(aligned.X);
aligned.A_norm = normalize01(aligned.A);
aligned.X_norm = normalize01(aligned.X);
aligned.table = table(aligned.T_K, aligned.A, aligned.lnA, aligned.I_peak_mA, aligned.width_mA, aligned.S_peak, aligned.X, aligned.lnX, aligned.A_norm, aligned.X_norm, ...
    'VariableNames', {'T_K','A_interp','ln_A_interp','I_peak_mA','width_mA','S_peak','X','ln_X','A_norm','X_norm'});
end

function fitSummaryTbl = buildFitSummaryTable(aligned)
modelKeys = ["ln_A_vs_X"; "A_vs_X"; "ln_A_vs_ln_X"];
displayNames = ["ln(A) vs X"; "A vs X"; "ln(A) vs ln(X)"];
xCells = {aligned.X; aligned.X; aligned.lnX};
yCells = {aligned.lnA; aligned.A; aligned.lnA};
xLabels = ["X"; "X"; "ln(X)"];
yLabels = ["ln(A)"; "A"; "ln(A)"];

rows = repmat(struct('model_key', "", 'display_name', "", 'x_label', "", 'y_label', "", 'n_points', NaN, 'slope', NaN, 'intercept', NaN, 'r_squared', NaN, 'pearson_r', NaN, 'spearman_r', NaN, 'rmse', NaN), numel(modelKeys), 1);
for i = 1:numel(modelKeys)
    stats = fitLinearModel(xCells{i}, yCells{i});
    rows(i).model_key = modelKeys(i);
    rows(i).display_name = displayNames(i);
    rows(i).x_label = xLabels(i);
    rows(i).y_label = yLabels(i);
    rows(i).n_points = stats.n_points;
    rows(i).slope = stats.slope;
    rows(i).intercept = stats.intercept;
    rows(i).r_squared = stats.r_squared;
    rows(i).pearson_r = stats.pearson_r;
    rows(i).spearman_r = stats.spearman_r;
    rows(i).rmse = stats.rmse;
end
fitSummaryTbl = struct2table(rows);
end

function stats = fitLinearModel(x, y)
mask = isfinite(x) & isfinite(y);
x = x(mask);
y = y(mask);

stats = struct('n_points', numel(x), 'slope', NaN, 'intercept', NaN, 'r_squared', NaN, 'pearson_r', NaN, 'spearman_r', NaN, 'rmse', NaN);
if numel(x) < 2 || all(abs(x - x(1)) < 1e-12)
    return;
end

p = polyfit(x, y, 1);
yhat = polyval(p, x);
stats.slope = p(1);
stats.intercept = p(2);
stats.r_squared = computeR2(y, yhat);
stats.pearson_r = corrSafe(x, y);
stats.spearman_r = spearmanSafe(x, y);
stats.rmse = sqrt(mean((y - yhat).^2));
end

function manifestTbl = buildSourceManifestTable(source)
experiments = string({'relaxation'; 'switching'; 'cross_experiment'});
runs = [source.relaxRunName; source.switchRunName; source.contextRunName];
files = [string(source.relaxPath); string(source.switchPath); string(source.contextPath)];
roles = string({'source relaxation A(T) table'; 'source switching observable table'; 'context reference for prior composite ranking only'});
manifestTbl = table(experiments, runs, files, roles, 'VariableNames', {'experiment','source_run','source_file','role'});
end

function figPaths = savePrimaryScatterFigure(aligned, fitSummaryTbl, runDir, figureName)
row = fitSummaryTbl(fitSummaryTbl.model_key == "ln_A_vs_X", :);
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
scatter(ax, aligned.X, aligned.lnA, 52, aligned.T_K, 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.5);
hold(ax, 'on');
xFit = linspace(min(aligned.X), max(aligned.X), 200);
plot(ax, xFit, row.slope(1) .* xFit + row.intercept(1), '-', 'Color', [0 0 0], 'LineWidth', 1.8);
hold(ax, 'off');
xlabel(ax, 'Composite coordinate X(T) (signal^{-1})');
ylabel(ax, 'ln(A(T)) (dimensionless)');
title(ax, 'Activation-coordinate test: ln(A) vs X');
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
colormap(ax, parula(256));
annotateFitMetrics(ax, row);
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveRawScatterFigure(aligned, fitSummaryTbl, runDir, figureName)
row = fitSummaryTbl(fitSummaryTbl.model_key == "A_vs_X", :);
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
scatter(ax, aligned.X, aligned.A, 52, aligned.T_K, 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.5);
hold(ax, 'on');
xFit = linspace(min(aligned.X), max(aligned.X), 200);
plot(ax, xFit, row.slope(1) .* xFit + row.intercept(1), '-', 'Color', [0 0 0], 'LineWidth', 1.8);
hold(ax, 'off');
xlabel(ax, 'Composite coordinate X(T) (signal^{-1})');
ylabel(ax, 'A(T) (dimensionless)');
title(ax, 'Raw activity vs composite coordinate');
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
colormap(ax, parula(256));
annotateFitMetrics(ax, row);
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveLogLogScatterFigure(aligned, fitSummaryTbl, runDir, figureName)
row = fitSummaryTbl(fitSummaryTbl.model_key == "ln_A_vs_ln_X", :);
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
scatter(ax, aligned.lnX, aligned.lnA, 52, aligned.T_K, 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.5);
hold(ax, 'on');
xFit = linspace(min(aligned.lnX), max(aligned.lnX), 200);
plot(ax, xFit, row.slope(1) .* xFit + row.intercept(1), '-', 'Color', [0 0 0], 'LineWidth', 1.8);
hold(ax, 'off');
xlabel(ax, 'ln(X(T)) (dimensionless)');
ylabel(ax, 'ln(A(T)) (dimensionless)');
title(ax, 'Log-log activation-coordinate test');
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
colormap(ax, parula(256));
annotateFitMetrics(ax, row);
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveOverlayFigure(aligned, runDir, figureName)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.A_norm, '-o', 'Color', [0.78 0.21 0.10], 'MarkerFaceColor', [0.78 0.21 0.10], 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'A(T), min-max normalized');
plot(ax, aligned.T_K, aligned.X_norm, '-s', 'Color', [0.07 0.32 0.64], 'MarkerFaceColor', [0.07 0.32 0.64], 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'X(T), min-max normalized');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude (0-1)');
title(ax, 'Normalized A(T) and X(T) on the common grid');
legend(ax, 'Location', 'best');
set(ax, 'YLim', [0 1.05]);
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function reportText = buildReportText(source, aligned, fitSummaryTbl, cfg)
primaryRow = fitSummaryTbl(fitSummaryTbl.model_key == "ln_A_vs_X", :);
rawRow = fitSummaryTbl(fitSummaryTbl.model_key == "A_vs_X", :);
loglogRow = fitSummaryTbl(fitSummaryTbl.model_key == "ln_A_vs_ln_X", :);

if primaryRow.r_squared(1) >= 0.9 && primaryRow.pearson_r(1) >= 0.9
    interpretation = 'The saved data are consistent with a strong approximately linear ln(A) vs X relation on the common temperature grid. This supports using X as a descriptive activation-like coordinate for relaxation activity in this dataset.';
elseif primaryRow.r_squared(1) >= 0.7 && primaryRow.pearson_r(1) >= 0.8
    interpretation = 'The saved data show a meaningful but not perfect approximately linear ln(A) vs X trend. X is a plausible descriptive activation coordinate, but the evidence is not clean enough to treat it as a unique controlling variable.';
else
    interpretation = 'The saved data do not support a strong approximately linear ln(A) vs X relation. X may still correlate with relaxation activity, but the activation-coordinate interpretation is weak in this form.';
end

lines = strings(0, 1);
lines(end + 1) = '# Activation coordinate analysis';
lines(end + 1) = '';
lines(end + 1) = '## Data sources';
lines(end + 1) = sprintf('- Relaxation source run: `%s`.', char(source.relaxRunName));
lines(end + 1) = '- Relaxation file reused without modification: `tables/temperature_observables.csv` with `A(T) = A_T`.';
lines(end + 1) = sprintf('- Switching source run: `%s`.', char(source.switchRunName));
lines(end + 1) = '- Switching file reused without modification: `tables/switching_full_scaling_parameters.csv` with `I_peak(T) = Ipeak_mA`, `width(T) = width_chosen_mA`, and `S_peak(T) = S_peak`.';
lines(end + 1) = '- Context reference only: `run_2026_03_13_071713_switching_composite_observable_scan` previously identified `I/(w*S)` as the strongest saved low-order composite against `A(T)`.';
lines(end + 1) = '';
lines(end + 1) = '## Construction and interpolation';
lines(end + 1) = '- Composite observable definition: `X(T) = I_peak(T) / (width(T) * S_peak(T))`.';
lines(end + 1) = sprintf('- Common grid choice: the switching temperatures `%.0f-%.0f K` were used as the analysis grid because `X(T)` is defined directly on the switching full-scaling table.', min(aligned.T_K), max(aligned.T_K));
lines(end + 1) = sprintf('- Relaxation `A(T)` was interpolated from the relaxation table onto that grid using `%s` interpolation.', cfg.interpMethod);
lines(end + 1) = sprintf('- Kept points after finite-value and positivity checks for the logarithms: `%d`.', height(aligned.table));
lines(end + 1) = '- Natural logarithms were used for both `ln(A)` and `ln(X)` tests.';
lines(end + 1) = '';
lines(end + 1) = '## Fitting procedure';
lines(end + 1) = '- Primary hypothesis test: linear least-squares fit of `ln(A(T)) = a X(T) + b`.';
lines(end + 1) = '- Alternative descriptive fits: linear least-squares fits of `A(T) = a X(T) + b` and `ln(A(T)) = a ln(X(T)) + b`.';
lines(end + 1) = '- For each form, the run reports the fitted slope `a`, intercept `b`, coefficient of determination `R^2`, Pearson correlation, Spearman correlation, and RMSE on the fitted variables.';
lines(end + 1) = '';
lines(end + 1) = '## Fit summary';
lines(end + 1) = '| Form | n | slope a | intercept b | R^2 | Pearson | Spearman |';
lines(end + 1) = '| --- | ---: | ---: | ---: | ---: | ---: | ---: |';
for i = 1:height(fitSummaryTbl)
    lines(end + 1) = sprintf('| %s | %d | %.6g | %.6g | %.6f | %.6f | %.6f |', fitSummaryTbl.display_name(i), fitSummaryTbl.n_points(i), fitSummaryTbl.slope(i), fitSummaryTbl.intercept(i), fitSummaryTbl.r_squared(i), fitSummaryTbl.pearson_r(i), fitSummaryTbl.spearman_r(i));
end
lines(end + 1) = '';
lines(end + 1) = '## Goodness of fit and interpretation';
lines(end + 1) = sprintf('- Primary relation `ln(A)` vs `X`: `a = %.6g`, `b = %.6g`, `R^2 = %.6f`, Pearson `= %.6f`, Spearman `= %.6f`.', primaryRow.slope(1), primaryRow.intercept(1), primaryRow.r_squared(1), primaryRow.pearson_r(1), primaryRow.spearman_r(1));
lines(end + 1) = sprintf('- Raw relation `A` vs `X`: `R^2 = %.6f`, Pearson `= %.6f`, Spearman `= %.6f`.', rawRow.r_squared(1), rawRow.pearson_r(1), rawRow.spearman_r(1));
lines(end + 1) = sprintf('- Log-log relation `ln(A)` vs `ln(X)`: `R^2 = %.6f`, Pearson `= %.6f`, Spearman `= %.6f`.', loglogRow.r_squared(1), loglogRow.pearson_r(1), loglogRow.spearman_r(1));
lines(end + 1) = sprintf('- Interpretation: %s', interpretation);
lines(end + 1) = '- This should still be read as a descriptive relation between saved observables, not as proof of a unique microscopic activation law.';
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- number of curves: three single-scatter diagnostic panels with one fitted line each, plus one two-curve temperature overlay';
lines(end + 1) = '- legend vs colormap: temperature is encoded by a labeled colorbar in the scatter figures; the two-curve overlay uses a legend';
lines(end + 1) = '- colormap used: `parula`';
lines(end + 1) = '- smoothing applied: none; the analysis uses saved scalar observables from prior immutable runs';
lines(end + 1) = '- justification: these figures isolate the activation-coordinate hypothesis, its two alternative parameterizations, and the shared temperature dependence without recomputing earlier analyses';
lines(end + 1) = '';
lines(end + 1) = '## Output files';
lines(end + 1) = '- `tables/activation_coordinate_aligned_data.csv`';
lines(end + 1) = '- `tables/activation_coordinate_fit_summary.csv`';
lines(end + 1) = '- `figures/ln_A_vs_X.png`';
lines(end + 1) = '- `figures/A_vs_X.png`';
lines(end + 1) = '- `figures/ln_A_vs_ln_X.png`';
lines(end + 1) = '- `figures/normalized_A_and_X_vs_temperature.png`';
lines(end + 1) = '- `review/activation_coordinate_test_bundle.zip`';

reportText = strjoin(lines, newline);
end

function annotateFitMetrics(ax, row)
txt = sprintf('a = %.3g\\newlineb = %.3g\\newlineR^2 = %.3f\\newlinePearson = %.3f\\newlineSpearman = %.3f', row.slope(1), row.intercept(1), row.r_squared(1), row.pearson_r(1), row.spearman_r(1));
text(ax, 0.04, 0.96, txt, 'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1], 'Margin', 4, 'FontSize', 8);
end

function styleAxes(ax)
set(ax, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top', 'XMinorTick', 'off', 'YMinorTick', 'off');
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function yNorm = normalize01(y)
y = y(:);
yNorm = NaN(size(y));
mask = isfinite(y);
if ~any(mask)
    return;
end
yMin = min(y(mask));
yMax = max(y(mask));
if abs(yMax - yMin) < 1e-12
    yNorm(mask) = 0.5;
    return;
end
yNorm(mask) = (y(mask) - yMin) ./ (yMax - yMin);
end

function r = corrSafe(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
r = NaN;
if nnz(mask) < 2
    return;
end
x = x(mask);
y = y(mask);
if all(abs(x - x(1)) < 1e-12) || all(abs(y - y(1)) < 1e-12)
    return;
end
cc = corrcoef(x, y);
if numel(cc) >= 4
    r = cc(1, 2);
end
end

function rho = spearmanSafe(x, y)
rho = corrSafe(tiedRank(x), tiedRank(y));
end

function ranks = tiedRank(x)
x = x(:);
ranks = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end
[xs, order] = sort(x(valid));
rankVals = zeros(size(xs));
i = 1;
while i <= numel(xs)
    j = i;
    while j < numel(xs) && xs(j + 1) == xs(i)
        j = j + 1;
    end
    rankVals(i:j) = mean(i:j);
    i = j + 1;
end
tmp = zeros(size(xs));
tmp(order) = rankVals;
ranks(valid) = tmp;
end

function r2 = computeR2(y, yhat)
mask = isfinite(y) & isfinite(yhat);
r2 = NaN;
if nnz(mask) < 2
    return;
end
y = y(mask);
yhat = yhat(mask);
ssRes = sum((y - yhat).^2);
ssTot = sum((y - mean(y)).^2);
if ssTot > 0
    r2 = 1 - ssRes / ssTot;
end
end

function appendText(filePath, textToAppend)
fid = fopen(filePath, 'a');
if fid < 0
    error('Could not append to file: %s', filePath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textToAppend);
end

function stamp = stampNow()
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
