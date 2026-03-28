function out = relaxation_switching_bridge_visualization(cfg)
% relaxation_switching_bridge_visualization
% Build a clean two-panel visualization of the empirical bridge between
% relaxation activity A(T) and X(T)=I_peak/(width*S_peak).

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
runCfg.dataset = sprintf('switch:%s | relax:%s | composite:%s', ...
    char(source.switchRunName), char(source.relaxRunName), char(source.compositeRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Bridge visualization run directory:\n%s\n', runDir);
fprintf('Switching source run: %s\n', source.switchRunName);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Composite source run: %s\n', source.compositeRunName);

appendText(run.log_path, sprintf('[%s] bridge visualization started\n', stampNow()));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Composite source: %s\n', char(source.compositeRunName)));

switching = loadSwitchingData(source.switchRunDir, cfg);
relax = loadRelaxationData(source.relaxRunDir);
composite = loadCompositeData(source.compositeRunDir, cfg);
mergedTbl = buildMergedTable(switching, relax, composite, cfg);
summary = summarizeBridge(mergedTbl);
manifestTbl = buildSourceManifestTable(source, cfg);

mergedPath = save_run_table(mergedTbl, 'merged_relaxation_switching_table.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

figOverlay = saveOverlayFigure(mergedTbl, summary, runDir, 'relaxation_switching_bridge_overlay');
figScatter = saveScatterFigure(mergedTbl, summary, runDir, 'relaxation_switching_bridge_scatter');
figCombined = saveCombinedFigure(mergedTbl, summary, runDir, 'relaxation_switching_bridge_figure_combined');

reportText = buildReportText(source, mergedTbl, summary, cfg);
reportPath = save_run_report(reportText, 'relaxation_switching_bridge_visualization.md', runDir);
zipPath = buildReviewZip(runDir, 'relaxation_switching_bridge_visualization_bundle.zip');

appendText(run.notes_path, sprintf('Baseline Pearson = %.6g\n', summary.pearson_r));
appendText(run.notes_path, sprintf('Baseline Spearman = %.6g\n', summary.spearman_r));
appendText(run.notes_path, sprintf('A peak = %.0f K\n', summary.A_peak_T_K));
appendText(run.notes_path, sprintf('X peak = %.0f K\n', summary.X_peak_T_K));
appendText(run.notes_path, sprintf('Peak offset = %.0f K\n', summary.peak_delta_K));

appendText(run.log_path, sprintf('[%s] bridge visualization complete\n', stampNow()));
appendText(run.log_path, sprintf('Merged table: %s\n', mergedPath));
appendText(run.log_path, sprintf('Manifest table: %s\n', manifestPath));
appendText(run.log_path, sprintf('Overlay figure: %s\n', figOverlay.png));
appendText(run.log_path, sprintf('Scatter figure: %s\n', figScatter.png));
appendText(run.log_path, sprintf('Combined figure: %s\n', figCombined.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.summary = summary;
out.tables = struct('merged', string(mergedPath), 'manifest', string(manifestPath));
out.figures = struct('overlay', string(figOverlay.png), 'scatter', string(figScatter.png), 'combined', string(figCombined.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Bridge visualization complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson / Spearman: %.4f / %.4f\n', summary.pearson_r, summary.spearman_r);
fprintf('Combined figure: %s\n', figCombined.png);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'relaxation_switching_bridge_visualization');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'compositeRunName', 'run_2026_03_13_071713_switching_composite_observable_scan');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'crossoverTemperatureK', 26);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.compositeRunName = string(cfg.compositeRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.compositeRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.compositeRunName));

required = {
    fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv');
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
    fullfile(char(source.compositeRunDir), 'tables', 'composite_observables_table.csv')
    };
for i = 1:numel(required)
    if exist(required{i}, 'file') ~= 2
        error('Required source file not found: %s', required{i});
    end
end
end

function switching = loadSwitchingData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'switching_full_scaling_parameters.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
tbl = sortrows(tbl(mask, :), 'T_K');
switching = struct();
switching.T = tbl.T_K(:);
switching.I_peak = tbl.Ipeak_mA(:);
switching.width = tbl.width_chosen_mA(:);
switching.S_peak = tbl.S_peak(:);
end

function relax = loadRelaxationData(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
tbl = sortrows(tbl, 'T');
relax = struct();
relax.T = tbl.T(:);
relax.A = tbl.A_T(:);
end

function composite = loadCompositeData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'composite_observables_table.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
tbl = sortrows(tbl(mask, :), 'T_K');
composite = struct();
composite.T = tbl.T_K(:);
composite.X_saved = tbl.I_over_wS(:);
end

function mergedTbl = buildMergedTable(switching, relax, composite, cfg)
mergedTbl = table();
mergedTbl.Temperature_K = switching.T(:);
mergedTbl.A_T = interp1(relax.T, relax.A, switching.T, cfg.interpMethod, NaN);
mergedTbl.I_peak_mA = switching.I_peak(:);
mergedTbl.width_mA = switching.width(:);
mergedTbl.S_peak = switching.S_peak(:);
[canonicalT, canonicalX] = get_canonical_X();
% X is loaded from canonical run to avoid drift from duplicated implementations
mergedTbl.X_T = interp1(canonicalT, canonicalX, mergedTbl.Temperature_K, cfg.interpMethod, NaN);
mergedTbl.A_norm = normalizeByMax(mergedTbl.A_T);
mergedTbl.X_norm = normalizeByMax(mergedTbl.X_T);
mergedTbl.X_saved_from_composite_run = NaN(height(mergedTbl), 1);
[lia, loc] = ismember(mergedTbl.Temperature_K, composite.T);
mergedTbl.X_saved_from_composite_run(lia) = composite.X_saved(loc(lia));
mergedTbl.X_delta_vs_saved = mergedTbl.X_T - mergedTbl.X_saved_from_composite_run;
end

function summary = summarizeBridge(mergedTbl)
summary = struct();
summary.n_points = height(mergedTbl);
summary.pearson_r = corrSafe(mergedTbl.X_T, mergedTbl.A_T);
summary.spearman_r = spearmanSafe(mergedTbl.X_T, mergedTbl.A_T);
summary.A_peak_T_K = findPeakT(mergedTbl.Temperature_K, mergedTbl.A_T);
summary.X_peak_T_K = findPeakT(mergedTbl.Temperature_K, mergedTbl.X_T);
summary.peak_delta_K = summary.X_peak_T_K - summary.A_peak_T_K;
summary.max_abs_delta_vs_saved = max(abs(mergedTbl.X_delta_vs_saved), [], 'omitnan');
p = polyfit(mergedTbl.X_T, mergedTbl.A_T, 1);
summary.linear_slope = p(1);
summary.linear_intercept = p(2);
end

function manifestTbl = buildSourceManifestTable(source, cfg)
manifestTbl = table(string({'switching'; 'relaxation'; 'cross_experiment'}), ...
    [source.switchRunName; source.relaxRunName; source.compositeRunName], ...
    string({fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.compositeRunDir), 'tables', 'composite_observables_table.csv')}), ...
    string({'full-scaling switching observables'; 'relaxation temperature observables'; 'saved composite bridge reference'}), ...
    repmat(string(cfg.interpMethod), 3, 1), ...
    'VariableNames', {'experiment','source_run','source_file','role','interp_method'});
end
function figPaths = saveOverlayFigure(mergedTbl, summary, runDir, figureName)
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 12.5 8.4]);
ax = axes(fh);
hold(ax, 'on');
plot(ax, mergedTbl.Temperature_K, mergedTbl.A_norm, '-o', ...
    'Color', [0 0 0], 'LineWidth', 1.9, 'MarkerSize', 5, 'MarkerFaceColor', [0 0 0], ...
    'DisplayName', 'Relaxation activity A(T)');
plot(ax, mergedTbl.Temperature_K, mergedTbl.X_norm, '-s', ...
    'Color', [0 0.45 0.74], 'LineWidth', 1.9, 'MarkerSize', 5, 'MarkerFaceColor', [0 0.45 0.74], ...
    'DisplayName', 'Composite switching observable X(T)');
xline(ax, summary.A_peak_T_K, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2, ...
    'Label', sprintf('Crossover %.0f K', summary.A_peak_T_K), 'LabelOrientation', 'horizontal', ...
    'LabelVerticalAlignment', 'bottom');
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized value');
title(ax, 'Temperature overlay of A(T) and X(T)');
legend(ax, 'Location', 'best');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveScatterFigure(mergedTbl, summary, runDir, figureName)
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 12.5 8.4]);
ax = axes(fh);
scatter(ax, mergedTbl.X_T, mergedTbl.A_T, 54, 'filled', ...
    'MarkerFaceColor', [0 0.45 0.74], 'MarkerEdgeColor', [0 0.25 0.45]);
hold(ax, 'on');
xFit = linspace(min(mergedTbl.X_T), max(mergedTbl.X_T), 200);
plot(ax, xFit, summary.linear_slope .* xFit + summary.linear_intercept, '--', ...
    'Color', [0.15 0.15 0.15], 'LineWidth', 1.8);
text(ax, 0.05, 0.95, sprintf('Pearson = %.3f\nSpearman = %.3f', summary.pearson_r, summary.spearman_r), ...
    'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 8, ...
    'BackgroundColor', 'w', 'Margin', 4);
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'X(T) = I_{peak} / (width S_{peak})');
ylabel(ax, 'A(T)');
title(ax, 'Correlation between switching geometry and relaxation activity');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveCombinedFigure(mergedTbl, summary, runDir, figureName)
fh = create_figure('Visible', 'off');
set(fh, 'Units', 'centimeters', 'Position', [2 2 17.8 8.8]);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, mergedTbl.Temperature_K, mergedTbl.A_norm, '-o', ...
    'Color', [0 0 0], 'LineWidth', 1.9, 'MarkerSize', 5, 'MarkerFaceColor', [0 0 0], ...
    'DisplayName', 'Relaxation activity A(T)');
plot(ax1, mergedTbl.Temperature_K, mergedTbl.X_norm, '-s', ...
    'Color', [0 0.45 0.74], 'LineWidth', 1.9, 'MarkerSize', 5, 'MarkerFaceColor', [0 0.45 0.74], ...
    'DisplayName', 'Composite switching observable X(T)');
xline(ax1, summary.A_peak_T_K, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2);
text(ax1, 0.02, 0.98, '(a)', 'Units', 'normalized', 'FontWeight', 'bold', 'VerticalAlignment', 'top');
text(ax1, summary.A_peak_T_K + 0.4, 0.93, sprintf('Crossover %.0f K', summary.A_peak_T_K), 'Color', [0.35 0.35 0.35], 'FontSize', 8);
hold(ax1, 'off');
grid(ax1, 'on');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'Normalized value');
title(ax1, 'Temperature overlay');
legend(ax1, 'Location', 'southoutside');

ax2 = nexttile(tl, 2);
scatter(ax2, mergedTbl.X_T, mergedTbl.A_T, 54, 'filled', ...
    'MarkerFaceColor', [0 0.45 0.74], 'MarkerEdgeColor', [0 0.25 0.45]);
hold(ax2, 'on');
xFit = linspace(min(mergedTbl.X_T), max(mergedTbl.X_T), 200);
plot(ax2, xFit, summary.linear_slope .* xFit + summary.linear_intercept, '--', ...
    'Color', [0.15 0.15 0.15], 'LineWidth', 1.8);
text(ax2, 0.02, 0.98, '(b)', 'Units', 'normalized', 'FontWeight', 'bold', 'VerticalAlignment', 'top');
text(ax2, 0.05, 0.88, sprintf('Pearson = %.3f\nSpearman = %.3f', summary.pearson_r, summary.spearman_r), ...
    'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 8, ...
    'BackgroundColor', 'w', 'Margin', 4);
hold(ax2, 'off');
grid(ax2, 'on');
xlabel(ax2, 'X(T) = I_{peak} / (width S_{peak})');
ylabel(ax2, 'A(T)');
title(ax2, 'Correlation scatter');

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReportText(source, mergedTbl, summary, cfg)
lines = strings(0,1);
lines(end+1) = '# Relaxation-switching bridge visualization';
lines(end+1) = '';
lines(end+1) = '## Inputs';
lines(end+1) = sprintf('- Relaxation source: `%s`', char(source.relaxRunName));
lines(end+1) = sprintf('- Switching source: `%s`', char(source.switchRunName));
lines(end+1) = sprintf('- Composite reference run: `%s`', char(source.compositeRunName));
lines(end+1) = '';
lines(end+1) = '## Merged dataset construction';
lines(end+1) = sprintf('- Temperature grid: %s', formatTempList(mergedTbl.Temperature_K));
lines(end+1) = sprintf('- Relaxation values were interpolated onto the switching grid using `%s`.', cfg.interpMethod);
lines(end+1) = '- The switching observables were taken from the saved full-scaling parameter table: `I_peak(T)`, `width(T)`, and `S_peak(T)`.';
lines(end+1) = '- `X(T)` was loaded from the canonical switching X export and sampled on the switching temperature grid.';
lines(end+1) = sprintf('- Agreement with the saved composite run: max |delta X| = `%.3g`.', summary.max_abs_delta_vs_saved);
lines(end+1) = '';
lines(end+1) = '## Correlations';
lines(end+1) = sprintf('- Pearson correlation: `%.4f`', summary.pearson_r);
lines(end+1) = sprintf('- Spearman correlation: `%.4f`', summary.spearman_r);
lines(end+1) = sprintf('- Peak temperatures: `A(T)` at `%.0f K`, `X(T)` at `%.0f K`.', summary.A_peak_T_K, summary.X_peak_T_K);
lines(end+1) = '';
lines(end+1) = '## Figure description';
lines(end+1) = '- Panel (a) overlays the normalized temperature dependences of `A(T)` and `X(T)` on the same grid, with a guide line at the crossover temperature.';
lines(end+1) = '- Panel (b) shows the direct correlation scatter together with the best linear fit and the reported Pearson and Spearman values.';
lines(end+1) = '- The figure is intended as a clear presentation graphic showing both the shared temperature structure and the quantitative correlation.';
lines(end+1) = '';
lines(end+1) = '## Visualization choices';
lines(end+1) = '- Overlay panel: two curves, explicit legend, matched markers, minimal clutter.';
lines(end+1) = '- Scatter panel: measured points plus one linear reference fit.';
lines(end+1) = '- Combined figure: two-panel slide-ready layout suitable for supervisor review.';
reportText = strjoin(lines, newline);
end

function y = normalizeByMax(x)
x = x(:);
mask = isfinite(x);
y = NaN(size(x));
if ~any(mask)
    return;
end
xMax = max(x(mask));
if ~isfinite(xMax) || xMax == 0
    y(mask) = NaN;
else
    y(mask) = x(mask) ./ xMax;
end
end

function txt = formatTempList(T)
txt = strjoin(compose('%.0f K', T(:).'), ', ');
end

function value = setDefaultField(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s;
    return;
end
s.(fieldName) = defaultValue;
value = s;
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
zip(zipPath, {'tables', 'figures', 'reports'}, runDir);
end

function value = corrSafe(x, y)
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    value = NaN;
    return;
end
value = corr(x(mask), y(mask), 'Rows', 'complete', 'Type', 'Pearson');
end

function value = spearmanSafe(x, y)
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    value = NaN;
    return;
end
value = corr(x(mask), y(mask), 'Rows', 'complete', 'Type', 'Spearman');
end

function peakT = findPeakT(T, y)
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    peakT = NaN;
    return;
end
T = T(mask);
y = y(mask);
[~, idx] = max(y);
peakT = T(idx);
end
