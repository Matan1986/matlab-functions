function out = motion_activity_comparison(cfg)
% motion_activity_comparison
% Compare relaxation activity against switching geometry and ridge motion.

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
runCfg.dataset = sprintf('relax:%s | switch:%s | composite:%s', ...
    char(source.relaxRunName), char(source.switchRunName), char(source.compositeRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Motion-activity comparison run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Switching source run: %s\n', source.switchRunName);
fprintf('Composite source run: %s\n', source.compositeRunName);

appendText(run.log_path, sprintf('[%s] motion-activity comparison started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Composite source: %s\n', char(source.compositeRunName)));

relax = loadRelaxationData(source.relaxRunDir);
switching = loadSwitchingData(source.switchRunDir, cfg);
composite = loadCompositeData(source.compositeRunDir, cfg);

curvesTbl = buildComparisonTable(relax, switching, composite, cfg);
correlationTbl = buildCorrelationTable(curvesTbl);
peakTbl = buildPeakTable(curvesTbl);
manifestTbl = buildSourceManifestTable(source, cfg);

curvesPath = save_run_table(curvesTbl, 'motion_activity_curves.csv', runDir);
correlationPath = save_run_table(correlationTbl, 'motion_activity_correlations.csv', runDir);
peakPath = save_run_table(peakTbl, 'motion_activity_peaks.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

fig1 = saveSingleCurveFigure(curvesTbl, runDir, 'A_norm_vs_T');
fig2 = saveOverlayFigure(curvesTbl, peakTbl, runDir, 'A_X_M_overlay');
fig3 = saveScatterFigure(curvesTbl, 'A_interp', 'X_T', 'A(T)', 'X(T) = I_{peak}/(w S_{peak})', runDir, 'A_vs_X_scatter');
fig4 = saveScatterFigure(curvesTbl, 'A_interp', 'M_T', 'A(T)', 'M(T) = |dI_{peak}/dT|', runDir, 'A_vs_M_scatter');
fig5 = saveScatterFigure(curvesTbl, 'X_T', 'M_T', 'X(T) = I_{peak}/(w S_{peak})', 'M(T) = |dI_{peak}/dT|', runDir, 'X_vs_M_scatter');

reportText = buildReportText(source, curvesTbl, correlationTbl, peakTbl, cfg);
reportPath = save_run_report(reportText, 'motion_vs_activity_analysis.md', runDir);
zipPath = buildReviewZip(runDir, 'motion_activity_comparison_bundle.zip');

bestPair = pickBestRelaxationTracker(correlationTbl);
appendText(run.notes_path, sprintf('A peak = %.6g K\n', peakTbl.peak_T_K(peakTbl.observable == "A")));
appendText(run.notes_path, sprintf('X peak = %.6g K\n', peakTbl.peak_T_K(peakTbl.observable == "X")));
appendText(run.notes_path, sprintf('M peak = %.6g K\n', peakTbl.peak_T_K(peakTbl.observable == "M")));
appendText(run.notes_path, sprintf('Best switching tracker of A(T) by |Pearson| = %s\n', char(bestPair.observable)));
appendText(run.notes_path, sprintf('Best switching tracker Pearson/Spearman = %.6g / %.6g\n', bestPair.pearson_r, bestPair.spearman_r));

appendText(run.log_path, sprintf('[%s] motion-activity comparison complete\n', stampNow()));
appendText(run.log_path, sprintf('Curves table: %s\n', curvesPath));
appendText(run.log_path, sprintf('Correlation table: %s\n', correlationPath));
appendText(run.log_path, sprintf('Peak table: %s\n', peakPath));
appendText(run.log_path, sprintf('Manifest table: %s\n', manifestPath));
appendText(run.log_path, sprintf('Figure 1: %s\n', fig1.png));
appendText(run.log_path, sprintf('Figure 2: %s\n', fig2.png));
appendText(run.log_path, sprintf('Figure 3: %s\n', fig3.png));
appendText(run.log_path, sprintf('Figure 4: %s\n', fig4.png));
appendText(run.log_path, sprintf('Figure 5: %s\n', fig5.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.tables = struct('curves', string(curvesPath), 'correlations', string(correlationPath), ...
    'peaks', string(peakPath), 'manifest', string(manifestPath));
out.figures = struct('A_norm', string(fig1.png), 'overlay', string(fig2.png), ...
    'A_vs_X', string(fig3.png), 'A_vs_M', string(fig4.png), 'X_vs_M', string(fig5.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.bestTracker = bestPair;

fprintf('\n=== Motion-activity comparison complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Best relaxation tracker: %s (Pearson %.4f, Spearman %.4f)\n', ...
    char(bestPair.observable), bestPair.pearson_r, bestPair.spearman_r);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'motion_activity_comparison');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'compositeRunName', 'run_2026_03_13_071713_switching_composite_observable_scan');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.compositeRunName = string(cfg.compositeRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.compositeRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.compositeRunName));

required = { ...
    fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.compositeRunDir), 'tables', 'composite_observables_table.csv')};
for i = 1:numel(required)
    if exist(required{i}, 'file') ~= 2
        error('Required source file not found: %s', required{i});
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
mask = mask & isfinite(tbl.T_K) & isfinite(tbl.Ipeak_mA) & isfinite(tbl.width_chosen_mA) & isfinite(tbl.S_peak);
tbl = sortrows(tbl(mask, :), 'T_K');
switching = struct();
switching.T = tbl.T_K(:);
switching.I_peak = tbl.Ipeak_mA(:);
switching.width = tbl.width_chosen_mA(:);
switching.S_peak = tbl.S_peak(:);
end

function composite = loadCompositeData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'composite_observables_table.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
tbl = sortrows(tbl(mask, :), 'T_K');
composite = struct();
composite.T = tbl.T_K(:);
composite.X_saved = tbl.I_over_wS(:);
end

function curvesTbl = buildComparisonTable(relax, switching, composite, cfg)
T = switching.T(:);
A = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
X = switching.I_peak ./ (switching.width .* switching.S_peak);
M = centralFiniteDifferenceAbs(T, switching.I_peak);

curvesTbl = table();
curvesTbl.T_K = T;
curvesTbl.A_interp = A;
curvesTbl.I_peak_mA = switching.I_peak(:);
curvesTbl.width_mA = switching.width(:);
curvesTbl.S_peak = switching.S_peak(:);
curvesTbl.X_T = X(:);
curvesTbl.M_T = M(:);
curvesTbl.A_norm = normalizeByMax(A);
curvesTbl.X_norm = normalizeByMax(X);
curvesTbl.M_norm = normalizeByMax(M);
curvesTbl.central_difference_defined = isfinite(curvesTbl.M_T);
curvesTbl.X_saved_from_composite_run = NaN(height(curvesTbl), 1);
[lia, loc] = ismember(curvesTbl.T_K, composite.T);
curvesTbl.X_saved_from_composite_run(lia) = composite.X_saved(loc(lia));
curvesTbl.X_delta_vs_saved = curvesTbl.X_T - curvesTbl.X_saved_from_composite_run;
end

function correlationTbl = buildCorrelationTable(curvesTbl)
pairs = {
    'X', 'A_vs_X', curvesTbl.A_interp, curvesTbl.X_T;
    'M', 'A_vs_M', curvesTbl.A_interp, curvesTbl.M_T;
    'M', 'X_vs_M', curvesTbl.X_T, curvesTbl.M_T
    };

pairName = strings(size(pairs, 1), 1);
observable = strings(size(pairs, 1), 1);
pearson_r = NaN(size(pairs, 1), 1);
spearman_r = NaN(size(pairs, 1), 1);
n_points = NaN(size(pairs, 1), 1);

for i = 1:size(pairs, 1)
    x = pairs{i, 3};
    y = pairs{i, 4};
    mask = isfinite(x) & isfinite(y);
    pairName(i) = string(pairs{i, 2});
    observable(i) = string(pairs{i, 1});
    n_points(i) = nnz(mask);
    pearson_r(i) = corrSafe(x(mask), y(mask), 'Pearson');
    spearman_r(i) = corrSafe(x(mask), y(mask), 'Spearman');
end

correlationTbl = table(pairName, observable, pearson_r, spearman_r, n_points, ...
    'VariableNames', {'pair_name', 'observable', 'pearson_r', 'spearman_r', 'n_points'});
end

function peakTbl = buildPeakTable(curvesTbl)
peakTbl = table( ...
    ["A"; "X"; "M"], ...
    [findPeakT(curvesTbl.T_K, curvesTbl.A_interp); ...
     findPeakT(curvesTbl.T_K, curvesTbl.X_T); ...
     findPeakT(curvesTbl.T_K, curvesTbl.M_T)], ...
    [max(curvesTbl.A_interp, [], 'omitnan'); ...
     max(curvesTbl.X_T, [], 'omitnan'); ...
     max(curvesTbl.M_T, [], 'omitnan')], ...
    'VariableNames', {'observable', 'peak_T_K', 'peak_value'});
end

function manifestTbl = buildSourceManifestTable(source, cfg)
manifestTbl = table( ...
    ["relaxation"; "switching"; "cross_experiment"], ...
    [source.relaxRunName; source.switchRunName; source.compositeRunName], ...
    string({fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    fullfile(char(source.compositeRunDir), 'tables', 'composite_observables_table.csv')}), ...
    ["A(T) source"; "I_peak(T), width(T), S_peak(T) source"; "Saved X(T) reference for validation"], ...
    repmat(string(cfg.interpMethod), 3, 1), ...
    'VariableNames', {'experiment', 'source_run', 'source_file', 'role', 'interp_method'});
end

function figPaths = saveSingleCurveFigure(curvesTbl, runDir, figureName)
fh = create_figure('Visible', 'off');
set(fh, 'Position', [2 2 10.5 7.6]);
ax = axes(fh);
plot(ax, curvesTbl.T_K, curvesTbl.A_norm, '-o', ...
    'Color', [0.00 0.00 0.00], 'LineWidth', 2.2, 'MarkerSize', 6, 'MarkerFaceColor', [0.00 0.00 0.00]);
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'A_{norm}(T)');
title(ax, 'Normalized relaxation activity');
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveOverlayFigure(curvesTbl, peakTbl, runDir, figureName)
fh = create_figure('Visible', 'off');
set(fh, 'Position', [2 2 11.2 7.8]);
ax = axes(fh);
hold(ax, 'on');
plot(ax, curvesTbl.T_K, curvesTbl.A_norm, '-o', ...
    'Color', [0.00 0.00 0.00], 'MarkerFaceColor', [0.00 0.00 0.00], ...
    'LineWidth', 2.2, 'MarkerSize', 5.5, 'DisplayName', 'A_{norm}(T)');
plot(ax, curvesTbl.T_K, curvesTbl.X_norm, '-s', ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'LineWidth', 2.2, 'MarkerSize', 5.5, 'DisplayName', 'X_{norm}(T)');
plot(ax, curvesTbl.T_K, curvesTbl.M_norm, '-^', ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', 'M_{norm}(T)');

for i = 1:height(peakTbl)
    xline(ax, peakTbl.peak_T_K(i), '--', 'LineWidth', 1.1, ...
        'Color', peakColor(peakTbl.observable(i)), ...
        'HandleVisibility', 'off');
end
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude');
title(ax, 'Relaxation, switching geometry, and switching motion on one temperature axis');
legend(ax, 'Location', 'northwest');
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveScatterFigure(curvesTbl, xField, yField, xLabel, yLabel, runDir, figureName)
x = curvesTbl.(xField);
y = curvesTbl.(yField);
mask = isfinite(x) & isfinite(y) & isfinite(curvesTbl.T_K);
T = curvesTbl.T_K(mask);
x = x(mask);
y = y(mask);

fh = create_figure('Visible', 'off');
set(fh, 'Position', [2 2 10.2 7.6]);
ax = axes(fh);
scatter(ax, x, y, 64, T, 'filled', 'MarkerEdgeColor', [0.20 0.20 0.20], 'LineWidth', 0.7);
grid(ax, 'on');
xlabel(ax, xLabel);
ylabel(ax, yLabel);
title(ax, sprintf('%s vs %s', yLabel, xLabel));
cb = colorbar(ax);
colormap(ax, parula);
cb.Label.String = 'Temperature (K)';
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReportText(source, curvesTbl, correlationTbl, peakTbl, cfg)
bestPair = pickBestRelaxationTracker(correlationTbl);
maxDelta = max(abs(curvesTbl.X_delta_vs_saved), [], 'omitnan');

lines = strings(0, 1);
lines(end + 1) = "# Motion vs Activity Analysis";
lines(end + 1) = "";
lines(end + 1) = "## Definitions of observables";
lines(end + 1) = "- Relaxation activity: `A(T)` from the relaxation observable-stability run.";
lines(end + 1) = "- Switching geometry composite: `X(T) = I_peak(T) / (width(T) * S_peak(T))`.";
lines(end + 1) = "- Switching motion: `M(T) = |dI_peak/dT|`, computed with central finite differences on the switching temperature grid.";
lines(end + 1) = "";
lines(end + 1) = "## Data sources";
lines(end + 1) = sprintf("- Relaxation run: `%s`.", source.relaxRunName);
lines(end + 1) = sprintf("- Switching full-scaling run: `%s`.", source.switchRunName);
lines(end + 1) = sprintf("- Composite-reference run: `%s`.", source.compositeRunName);
lines(end + 1) = sprintf("- Common temperature grid: `%s` on the switching grid.", formatTempList(curvesTbl.T_K));
lines(end + 1) = sprintf("- Interpolation used for `A(T)`: `%s`.", cfg.interpMethod);
lines(end + 1) = "- No smoothing was applied before differentiation so that `M(T)` matches the requested central-difference definition directly.";
lines(end + 1) = sprintf("- Reconstructed `X(T)` agrees with the saved composite run to max `|delta X| = %.3g`.", maxDelta);
lines(end + 1) = "";
lines(end + 1) = "## Correlation table";
lines(end + 1) = "";
lines(end + 1) = "| Pair | Pearson | Spearman | n |";
lines(end + 1) = "| --- | ---: | ---: | ---: |";
for i = 1:height(correlationTbl)
    lines(end + 1) = sprintf("| `%s` | %.4f | %.4f | %d |", ...
        correlationTbl.pair_name(i), correlationTbl.pearson_r(i), correlationTbl.spearman_r(i), correlationTbl.n_points(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Peak temperatures";
for i = 1:height(peakTbl)
    lines(end + 1) = sprintf("- `%s(T)` peaks at `%.1f K`.", peakTbl.observable(i), peakTbl.peak_T_K(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
if bestPair.observable == "X"
    lines(end + 1) = sprintf("- The switching geometry composite `X(T)` tracks relaxation activity better than `M(T)` in this comparison, with Pearson `%.4f` and Spearman `%.4f` against `A(T)`.", bestPair.pearson_r, bestPair.spearman_r);
    lines(end + 1) = "- This means the joint ridge-position/width/amplitude geometry carries more of the same temperature coordinate as relaxation than ridge motion alone.";
else
    lines(end + 1) = sprintf("- The switching motion observable `M(T)` tracks relaxation activity better than `X(T)` in this comparison, with Pearson `%.4f` and Spearman `%.4f` against `A(T)`.", bestPair.pearson_r, bestPair.spearman_r);
    lines(end + 1) = "- This means ridge mobility is the closer dynamical coordinate to relaxation, while the composite geometry is secondary or mixed.";
end
lines(end + 1) = sprintf("- `A(T)` and `X(T)` correlation: Pearson `%.4f`, Spearman `%.4f`.", ...
    correlationTbl.pearson_r(correlationTbl.pair_name == "A_vs_X"), correlationTbl.spearman_r(correlationTbl.pair_name == "A_vs_X"));
lines(end + 1) = sprintf("- `A(T)` and `M(T)` correlation: Pearson `%.4f`, Spearman `%.4f`.", ...
    correlationTbl.pearson_r(correlationTbl.pair_name == "A_vs_M"), correlationTbl.spearman_r(correlationTbl.pair_name == "A_vs_M"));
lines(end + 1) = sprintf("- `X(T)` and `M(T)` correlation: Pearson `%.4f`, Spearman `%.4f`.", ...
    correlationTbl.pearson_r(correlationTbl.pair_name == "X_vs_M"), correlationTbl.spearman_r(correlationTbl.pair_name == "X_vs_M"));
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 1 curve in Figure 1, 3 curves in Figure 2, and one scatter cloud in each pair plot.";
lines(end + 1) = "- legend vs colormap: explicit legend for the overlay figure; temperature-colored scatter markers with a labeled colorbar for the pair plots.";
lines(end + 1) = "- colormap used: `parula` for the scatter plots.";
lines(end + 1) = "- smoothing applied: none before differentiation, by design.";
lines(end + 1) = "- justification: the figure set separates temperature-profile comparison from pairwise-correlation comparison, which keeps the dynamical-coordinate question readable.";

reportText = strjoin(lines, newline);
end

function bestPair = pickBestRelaxationTracker(correlationTbl)
candidateTbl = correlationTbl(ismember(correlationTbl.pair_name, ["A_vs_X", "A_vs_M"]), :);
[~, idx] = max(abs(candidateTbl.pearson_r));
bestPair = candidateTbl(idx, :);
end

function y = centralFiniteDifferenceAbs(T, x)
T = T(:);
x = x(:);
y = NaN(size(x));
mask = isfinite(T) & isfinite(x);
if nnz(mask) < 3
    return;
end
idx = find(mask);
for k = 2:numel(idx) - 1
    i = idx(k);
    iPrev = idx(k - 1);
    iNext = idx(k + 1);
    denom = T(iNext) - T(iPrev);
    if isfinite(denom) && denom ~= 0
        y(i) = abs((x(iNext) - x(iPrev)) / denom);
    end
end
end

function yNorm = normalizeByMax(y)
y = y(:);
yNorm = NaN(size(y));
mask = isfinite(y);
if ~any(mask)
    return;
end
mx = max(y(mask), [], 'omitnan');
if isfinite(mx) && mx > 0
    yNorm(mask) = y(mask) ./ mx;
end
end

function value = corrSafe(x, y, corrType)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
value = NaN;
if nnz(mask) < 3
    return;
end
value = corr(x(mask), y(mask), 'Rows', 'complete', 'Type', corrType);
end

function peakT = findPeakT(T, y)
mask = isfinite(T) & isfinite(y);
peakT = NaN;
if ~any(mask)
    return;
end
[~, idx] = max(y(mask));
Tvalid = T(mask);
peakT = Tvalid(idx);
end

function color = peakColor(obs)
switch char(obs)
    case 'A'
        color = [0.00 0.00 0.00];
    case 'X'
        color = [0.00 0.45 0.74];
    otherwise
        color = [0.85 0.33 0.10];
end
end

function setAxisStyle(ax)
set(ax, 'FontName', 'Helvetica', 'FontSize', 14, 'LineWidth', 1.1, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
end

function txt = formatTempList(T)
txt = strjoin(compose('%.0f K', T(:).'), ', ');
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

function value = setDefaultField(cfg, fieldName, defaultValue)
if isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
    value = cfg;
    return;
end
cfg.(fieldName) = defaultValue;
value = cfg;
end
