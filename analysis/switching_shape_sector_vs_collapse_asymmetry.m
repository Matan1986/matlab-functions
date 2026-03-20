function out = switching_shape_sector_vs_collapse_asymmetry(cfg)
% switching_shape_sector_vs_collapse_asymmetry
% Compare collapse epsilon/asymmetry observables against switching chi_shape and chi_dyn.
%
% This analysis reuses saved run artifacts only:
% - collapse/asymmetry observables from a collapse-kernel run
% - effective asymmetry observables from a switching run
% - chi decomposition outputs from a cross-experiment run
%
% Outputs are written to a fresh run under:
% results/cross_experiment/runs/run_<timestamp>_switching_shape_sector_vs_collapse_asymmetry

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
source = resolveSources(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('collapse:%s | effective:%s | chi:%s', ...
    char(source.collapseRunName), char(source.effectiveRunName), char(source.chiRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Shape-vs-collapse run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] shape-vs-collapse analysis started\n', stampNow()));
appendText(run.log_path, sprintf('Collapse source: %s\n', char(source.collapseRunName)));
appendText(run.log_path, sprintf('Effective source: %s\n', char(source.effectiveRunName)));
appendText(run.log_path, sprintf('chi source: %s\n', char(source.chiRunName)));

collapseTbl = sortrows(readtable(source.collapseObservablesPath), 'T');
chiTbl = sortrows(readtable(source.chiDecompPath), 'T_K');

effectiveTbl = table();
if exist(source.effectiveAsymPath, 'file') == 2
    effectiveTbl = sortrows(readtable(source.effectiveAsymPath), 'T_K');
end

T = double(chiTbl.T_K(:));

alignedTbl = table(T, ...
    alignByT(T, double(chiTbl.T_K(:)), double(chiTbl.chi_dyn(:))), ...
    alignByT(T, double(chiTbl.T_K(:)), double(chiTbl.chi_shape(:))), ...
    alignByT(T, double(collapseTbl.T(:)), double(collapseTbl.shift_width_residual(:))), ...
    alignByT(T, double(collapseTbl.T(:)), double(collapseTbl.shift_width_amp_residual(:))), ...
    alignByT(T, double(collapseTbl.T(:)), double(collapseTbl.halfwidth_diff_norm_existing(:))), ...
    alignByT(T, double(collapseTbl.T(:)), double(collapseTbl.asym_area_ratio(:))), ...
    alignByT(T, double(collapseTbl.T(:)), double(collapseTbl.area_asymmetry_centered(:))), ...
    alignByT(T, double(collapseTbl.T(:)), double(collapseTbl.best_residual(:))), ...
    alignByT(T, double(collapseTbl.T(:)), double(collapseTbl.signal_fraction(:))), ...
    'VariableNames', {'T_K','chi_dyn','chi_shape', ...
    'shift_width_residual','shift_width_amp_residual','halfwidth_diff_norm_existing', ...
    'asym_area_ratio','area_asymmetry_centered','best_residual','signal_fraction'});

alignedTbl.epsilon_amp_gain = alignedTbl.shift_width_residual - alignedTbl.shift_width_amp_residual;
alignedTbl.epsilon_amp_gain_abs = abs(alignedTbl.epsilon_amp_gain);
alignedTbl.epsilon_amp_gain_rel = safeDivide(alignedTbl.epsilon_amp_gain, abs(alignedTbl.shift_width_residual));
alignedTbl.halfwidth_diff_norm_abs = abs(alignedTbl.halfwidth_diff_norm_existing);
alignedTbl.asym_area_dev_abs = abs(alignedTbl.asym_area_ratio - 1);
alignedTbl.area_asymmetry_centered_abs = abs(alignedTbl.area_asymmetry_centered);

if ~isempty(effectiveTbl)
    alignedTbl.asym_interp_halfwidth = alignByT(T, double(effectiveTbl.T_K(:)), double(effectiveTbl.asym_interp_halfwidth(:)));
    alignedTbl.asym_interp_halfwidth_abs = abs(alignedTbl.asym_interp_halfwidth);
    alignedTbl.area_ratio_asym_source = alignByT(T, double(effectiveTbl.T_K(:)), double(effectiveTbl.area_ratio_asym_source(:)));
    alignedTbl.area_ratio_asym_source_dev_abs = abs(alignedTbl.area_ratio_asym_source - 1);
    alignedTbl.halfwidth_diff_norm_source = alignByT(T, double(effectiveTbl.T_K(:)), double(effectiveTbl.halfwidth_diff_norm_source(:)));
    alignedTbl.halfwidth_diff_norm_source_abs = abs(alignedTbl.halfwidth_diff_norm_source);
else
    alignedTbl.asym_interp_halfwidth = NaN(size(T));
    alignedTbl.asym_interp_halfwidth_abs = NaN(size(T));
    alignedTbl.area_ratio_asym_source = NaN(size(T));
    alignedTbl.area_ratio_asym_source_dev_abs = NaN(size(T));
    alignedTbl.halfwidth_diff_norm_source = NaN(size(T));
    alignedTbl.halfwidth_diff_norm_source_abs = NaN(size(T));
end

metricNames = { ...
    'epsilon_amp_gain_abs', ...
    'epsilon_amp_gain_rel', ...
    'halfwidth_diff_norm_abs', ...
    'asym_area_dev_abs', ...
    'area_asymmetry_centered_abs', ...
    'asym_interp_halfwidth_abs', ...
    'area_ratio_asym_source_dev_abs', ...
    'halfwidth_diff_norm_source_abs'};
metricLabels = { ...
    'epsilon_amp_gain_abs', ...
    'epsilon_amp_gain_rel', ...
    'halfwidth_diff_norm_abs', ...
    'asym_area_dev_abs', ...
    'area_asymmetry_centered_abs', ...
    'asym_interp_halfwidth_abs', ...
    'area_ratio_asym_source_dev_abs', ...
    'halfwidth_diff_norm_source_abs'};
targetNames = {'chi_shape', 'chi_dyn'};

corrTbl = buildCorrelationTable(alignedTbl, metricNames, metricLabels, targetNames);
peakTbl = buildPeakTable(alignedTbl, [targetNames, metricNames]);

verdictShape = classifyPair(corrTbl, 'epsilon_amp_gain_abs', 'chi_shape');
verdictDyn = classifyPair(corrTbl, 'epsilon_amp_gain_abs', 'chi_dyn');
overallVerdict = summarizeOverall(verdictShape, verdictDyn);

alignedPath = save_run_table(alignedTbl, 'epsilon_asymmetry_vs_shape_aligned.csv', runDir);
corrPath = save_run_table(corrTbl, 'epsilon_asymmetry_vs_shape_correlations.csv', runDir);
peakPath = save_run_table(peakTbl, 'epsilon_asymmetry_vs_shape_peaks.csv', runDir);
sourcePath = save_run_table(buildSourceTable(source), 'source_run_manifest.csv', runDir);

figMain = saveOverlayFigureMain(alignedTbl, runDir, 'epsilon_shape_overlay_main');
figAux = saveOverlayFigureAux(alignedTbl, runDir, 'epsilon_shape_overlay_aux');

reportText = buildReport(alignedTbl, corrTbl, peakTbl, source, verdictShape, verdictDyn, overallVerdict);
reportPath = save_run_report(reportText, 'switching_shape_sector_vs_collapse_asymmetry.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_shape_sector_vs_collapse_asymmetry_bundle.zip');

appendText(run.notes_path, sprintf('epsilon_proxy = epsilon_amp_gain_abs\n'));
appendText(run.notes_path, sprintf('epsilon-vs-chi_shape verdict: %s\n', verdictShape.verdict));
appendText(run.notes_path, sprintf('epsilon-vs-chi_dyn verdict: %s\n', verdictDyn.verdict));
appendText(run.notes_path, sprintf('overall verdict: %s\n', overallVerdict));
appendText(run.log_path, sprintf('[%s] shape-vs-collapse analysis complete\n', stampNow()));
appendText(run.log_path, sprintf('Aligned table: %s\n', alignedPath));
appendText(run.log_path, sprintf('Correlation table: %s\n', corrPath));
appendText(run.log_path, sprintf('Peak table: %s\n', peakPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', sourcePath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.tables = struct('aligned', string(alignedPath), 'correlations', string(corrPath), ...
    'peaks', string(peakPath), 'manifest', string(sourcePath));
out.figures = struct('overlay_main', string(figMain.png), 'overlay_aux', string(figAux.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.verdict = struct('shape', verdictShape, 'dyn', verdictDyn, 'overall', string(overallVerdict));

fprintf('\n=== Shape-vs-collapse analysis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('epsilon-vs-chi_shape: %s\n', verdictShape.verdict);
fprintf('epsilon-vs-chi_dyn: %s\n', verdictDyn.verdict);
fprintf('Overall: %s\n', overallVerdict);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_shape_sector_vs_collapse_asymmetry');
cfg = setDefault(cfg, 'collapseRunName', 'run_2026_03_11_224153_switching_collapse_kernel_analysis');
cfg = setDefault(cfg, 'effectiveRunName', 'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefault(cfg, 'chiRunName', 'run_2026_03_14_121511_switching_chi_shift_shape_decomposition');
cfg = setDefault(cfg, 'trackPearsonStrong', 0.70);
cfg = setDefault(cfg, 'trackPearsonModerate', 0.50);
cfg = setDefault(cfg, 'trackPeakDeltaStrongK', 4.0);
cfg = setDefault(cfg, 'trackPeakDeltaModerateK', 8.0);
end

function cfg = setDefault(cfg, name, fallback)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = fallback;
end
end

function source = resolveSources(repoRoot, cfg)
source = struct();
source.collapseRunName = string(cfg.collapseRunName);
source.effectiveRunName = string(cfg.effectiveRunName);
source.chiRunName = string(cfg.chiRunName);
source.collapseRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.collapseRunName));
source.effectiveRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.effectiveRunName));
source.chiRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.chiRunName));
source.collapseObservablesPath = fullfile(source.collapseRunDir, 'tables', 'collapse_observables.csv');
source.effectiveAsymPath = fullfile(source.effectiveRunDir, 'tables', 'switching_effective_asymmetry_comparison.csv');
source.chiDecompPath = fullfile(source.chiRunDir, 'tables', 'chi_decomposition_vs_T.csv');

required = {source.collapseRunDir, source.collapseObservablesPath; ...
            source.chiRunDir, source.chiDecompPath};
for i = 1:size(required, 1)
    if exist(required{i, 1}, 'dir') ~= 7
        error('Missing source run directory: %s', required{i, 1});
    end
    if exist(required{i, 2}, 'file') ~= 2
        error('Missing source file: %s', required{i, 2});
    end
end

if exist(source.effectiveRunDir, 'dir') ~= 7
    warning('Effective asymmetry source run not found: %s', source.effectiveRunDir);
end
if exist(source.effectiveAsymPath, 'file') ~= 2
    warning('Effective asymmetry table not found: %s', source.effectiveAsymPath);
end
end

function y = alignByT(Ttarget, Tsource, values)
y = NaN(size(Ttarget));
if isempty(Tsource) || isempty(values)
    return;
end
[lia, loc] = ismember(Ttarget, Tsource);
y(lia) = values(loc(lia));
end

function out = safeDivide(num, den)
out = NaN(size(num));
mask = isfinite(num) & isfinite(den) & abs(den) > 0;
out(mask) = num(mask) ./ den(mask);
end

function corrTbl = buildCorrelationTable(alignedTbl, metricNames, metricLabels, targetNames)
rows = {};
for i = 1:numel(metricNames)
    metric = metricNames{i};
    label = metricLabels{i};
    x = double(alignedTbl.(metric));
    for j = 1:numel(targetNames)
        target = targetNames{j};
        y = double(alignedTbl.(target));
        mask = isfinite(x) & isfinite(y) & isfinite(alignedTbl.T_K);
        if nnz(mask) >= 3
            pearson = corr(x(mask), y(mask), 'Type', 'Pearson', 'Rows', 'complete');
            spearman = corr(x(mask), y(mask), 'Type', 'Spearman', 'Rows', 'complete');
        else
            pearson = NaN;
            spearman = NaN;
        end
        [peakMetricT, peakMetricVal] = peakOf(alignedTbl.T_K(mask), x(mask));
        [peakTargetT, peakTargetVal] = peakOf(alignedTbl.T_K(mask), y(mask));
        deltaT = peakMetricT - peakTargetT;
        rows(end + 1, :) = {label, target, nnz(mask), pearson, spearman, ...
            peakMetricT, peakTargetT, deltaT, peakMetricVal, peakTargetVal}; %#ok<AGROW>
    end
end

corrTbl = cell2table(rows, 'VariableNames', { ...
    'metric', 'target', 'n_points', 'pearson_r', 'spearman_rho', ...
    'metric_peak_T_K', 'target_peak_T_K', 'delta_peak_T_K', ...
    'metric_peak_value', 'target_peak_value'});
end

function peakTbl = buildPeakTable(alignedTbl, seriesNames)
rows = {};
for i = 1:numel(seriesNames)
    name = seriesNames{i};
    values = double(alignedTbl.(name));
    mask = isfinite(alignedTbl.T_K) & isfinite(values);
    [peakT, peakValue] = peakOf(alignedTbl.T_K(mask), values(mask));
    rows(end + 1, :) = {name, peakT, peakValue, nnz(mask)}; %#ok<AGROW>
end
peakTbl = cell2table(rows, 'VariableNames', {'series', 'peak_T_K', 'peak_value', 'n_points'});
end

function [peakT, peakValue] = peakOf(T, values)
peakT = NaN;
peakValue = NaN;
if isempty(T) || isempty(values)
    return;
end
[peakValue, idx] = max(values);
if ~isempty(idx) && isfinite(peakValue)
    peakT = T(idx);
end
end

function verdict = classifyPair(corrTbl, metricName, targetName)
row = corrTbl(strcmp(corrTbl.metric, metricName) & strcmp(corrTbl.target, targetName), :);
if isempty(row)
    verdict = struct('verdict', 'insufficient', 'reason', 'pair missing');
    return;
end

r = row.pearson_r(1);
rho = row.spearman_rho(1);
dT = abs(row.delta_peak_T_K(1));
n = row.n_points(1);

if ~(isfinite(r) && isfinite(rho) && isfinite(dT)) || n < 3
    verdict = struct('verdict', 'insufficient', 'reason', 'insufficient overlap');
    return;
end

if abs(r) >= 0.70 && abs(rho) >= 0.60 && dT <= 4
    tag = 'tracks_strongly';
elseif abs(r) >= 0.50 && dT <= 8
    tag = 'tracks_partially';
else
    tag = 'distinct';
end

reason = sprintf('|Pearson|=%.3f, |Spearman|=%.3f, |DeltaT|=%.3f K, n=%d', abs(r), abs(rho), dT, n);
verdict = struct('verdict', tag, 'reason', reason);
end

function text = summarizeOverall(vShape, vDyn)
if strcmp(vShape.verdict, 'tracks_strongly') || strcmp(vDyn.verdict, 'tracks_strongly')
    text = 'epsilon proxy is consistent with the switching shape sector';
elseif strcmp(vShape.verdict, 'tracks_partially') || strcmp(vDyn.verdict, 'tracks_partially')
    text = 'epsilon proxy shows partial overlap with the switching shape sector';
elseif strcmp(vShape.verdict, 'insufficient') && strcmp(vDyn.verdict, 'insufficient')
    text = 'insufficient overlap to determine correspondence';
else
    text = 'epsilon proxy appears distinct from the switching shape sector';
end
end

function figOut = saveOverlayFigureMain(tbl, runDir, baseName)
fig = create_figure('Visible', 'off');
ax = axes(fig); %#ok<LAXES>
hold(ax, 'on');
grid(ax, 'on');

plotNorm(ax, tbl.T_K, tbl.chi_dyn, '-', [0.10 0.10 0.10], 'chi_dyn');
plotNorm(ax, tbl.T_K, tbl.chi_shape, '--', [0.00 0.45 0.74], 'chi_shape');
plotNorm(ax, tbl.T_K, tbl.epsilon_amp_gain_abs, '-', [0.85 0.33 0.10], 'epsilon_amp_gain_abs');
plotNorm(ax, tbl.T_K, tbl.epsilon_amp_gain_rel, '-', [0.93 0.69 0.13], 'epsilon_amp_gain_rel');
plotNorm(ax, tbl.T_K, tbl.asym_interp_halfwidth_abs, '-', [0.47 0.67 0.19], 'asym_interp_halfwidth_abs');
plotNorm(ax, tbl.T_K, tbl.asym_area_dev_abs, '-', [0.49 0.18 0.56], 'asym_area_dev_abs');

xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalized value (max=1)', 'FontSize', 14);
title(ax, 'Normalized overlay: chi metrics and epsilon/asymmetry proxies', 'FontSize', 14);
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
legend(ax, 'Location', 'best', 'FontSize', 11);

figOut = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figOut = saveOverlayFigureAux(tbl, runDir, baseName)
fig = create_figure('Visible', 'off');
ax = axes(fig); %#ok<LAXES>
hold(ax, 'on');
grid(ax, 'on');

plotNorm(ax, tbl.T_K, tbl.chi_dyn, '-', [0.10 0.10 0.10], 'chi_dyn');
plotNorm(ax, tbl.T_K, tbl.chi_shape, '--', [0.00 0.45 0.74], 'chi_shape');
plotNorm(ax, tbl.T_K, tbl.halfwidth_diff_norm_abs, '-', [0.85 0.33 0.10], 'halfwidth_diff_norm_abs');
plotNorm(ax, tbl.T_K, tbl.area_asymmetry_centered_abs, '-', [0.47 0.67 0.19], 'area_asymmetry_centered_abs');
plotNorm(ax, tbl.T_K, tbl.area_ratio_asym_source_dev_abs, '-', [0.49 0.18 0.56], 'area_ratio_asym_source_dev_abs');

xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalized value (max=1)', 'FontSize', 14);
title(ax, 'Normalized overlay: asymmetry-only proxies vs chi metrics', 'FontSize', 14);
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
legend(ax, 'Location', 'best', 'FontSize', 11);

figOut = save_run_figure(fig, baseName, runDir);
close(fig);
end

function plotNorm(ax, x, y, style, color, labelText)
yNorm = normalizeToMax(y);
plot(ax, x, yNorm, style, 'Color', color, 'LineWidth', 2.2, 'DisplayName', labelText);
end

function yNorm = normalizeToMax(y)
y = double(y);
mask = isfinite(y);
yNorm = NaN(size(y));
if nnz(mask) < 1
    return;
end
m = max(y(mask));
if ~(isfinite(m) && m > 0)
    return;
end
yNorm(mask) = y(mask) ./ m;
end

function tbl = buildSourceTable(source)
rows = { ...
    'collapse_observables', char(source.collapseRunName), source.collapseRunDir, source.collapseObservablesPath; ...
    'effective_asymmetry', char(source.effectiveRunName), source.effectiveRunDir, source.effectiveAsymPath; ...
    'chi_decomposition', char(source.chiRunName), source.chiRunDir, source.chiDecompPath};
tbl = cell2table(rows, 'VariableNames', {'role','run_name','run_dir','key_table'});
end

function reportText = buildReport(alignedTbl, corrTbl, peakTbl, source, verdictShape, verdictDyn, overallVerdict)
line = strings(0,1);
line(end + 1) = "# Switching shape sector vs collapse epsilon/asymmetry";
line(end + 1) = "";
line(end + 1) = "## Repository scan and reused observables";
line(end + 1) = sprintf("- collapse observables run: `%s`", char(source.collapseRunName));
line(end + 1) = sprintf("  - table: `%s`", source.collapseObservablesPath);
line(end + 1) = "- extracted collapse-side observables:";
line(end + 1) = "  - `shift_width_residual(T)`";
line(end + 1) = "  - `shift_width_amp_residual(T)`";
line(end + 1) = "  - `halfwidth_diff_norm_existing(T)`";
line(end + 1) = "  - `asym_area_ratio(T)`";
line(end + 1) = "  - `area_asymmetry_centered(T)`";
line(end + 1) = sprintf("- effective asymmetry run: `%s`", char(source.effectiveRunName));
line(end + 1) = sprintf("  - table: `%s`", source.effectiveAsymPath);
line(end + 1) = "  - extracted: `asym_interp_halfwidth(T)`, `area_ratio_asym_source(T)`";
line(end + 1) = sprintf("- switching chi decomposition run: `%s`", char(source.chiRunName));
line(end + 1) = sprintf("  - table: `%s`", source.chiDecompPath);
line(end + 1) = "  - extracted: `chi_shape(T)`, `chi_dyn(T)`";
line(end + 1) = "";
line(end + 1) = "## Epsilon proxy used";
line(end + 1) = "- `epsilon_amp_gain(T) = shift_width_residual(T) - shift_width_amp_residual(T)`";
line(end + 1) = "- analysis uses `epsilon_amp_gain_abs(T)` as the main epsilon-style correction magnitude.";
line(end + 1) = "";
line(end + 1) = "## Quantitative comparison summary";
line(end + 1) = sprintf("- epsilon vs chi_shape: **%s** (%s)", verdictShape.verdict, verdictShape.reason);
line(end + 1) = sprintf("- epsilon vs chi_dyn: **%s** (%s)", verdictDyn.verdict, verdictDyn.reason);
line(end + 1) = sprintf("- overall: **%s**", overallVerdict);
line(end + 1) = "";
line(end + 1) = "## Peak temperatures (selected)";
line(end + 1) = peakLine(peakTbl, "chi_shape");
line(end + 1) = peakLine(peakTbl, "chi_dyn");
line(end + 1) = peakLine(peakTbl, "epsilon_amp_gain_abs");
line(end + 1) = peakLine(peakTbl, "asym_interp_halfwidth_abs");
line(end + 1) = peakLine(peakTbl, "asym_area_dev_abs");
line(end + 1) = "";
line(end + 1) = "## Interpretation";
line(end + 1) = "- If epsilon-proxy and chi-shape peaks are separated and correlations are weak/moderate, they likely reflect distinct shape observables.";
line(end + 1) = "- If one asymmetry proxy aligns better than others, that proxy is the strongest candidate bridge.";
line(end + 1) = "";
line(end + 1) = "## Output artifacts";
line(end + 1) = "- `tables/epsilon_asymmetry_vs_shape_aligned.csv`";
line(end + 1) = "- `tables/epsilon_asymmetry_vs_shape_correlations.csv`";
line(end + 1) = "- `tables/epsilon_asymmetry_vs_shape_peaks.csv`";
line(end + 1) = "- `figures/epsilon_shape_overlay_main.png`";
line(end + 1) = "- `figures/epsilon_shape_overlay_aux.png`";
line(end + 1) = "- `review/switching_shape_sector_vs_collapse_asymmetry_bundle.zip`";
line(end + 1) = "";
line(end + 1) = "## Visualization choices";
line(end + 1) = "- number of curves: 6 curves in main overlay, 5 curves in auxiliary overlay";
line(end + 1) = "- legend vs colormap: legends used (each panel has <= 6 curves)";
line(end + 1) = "- colormap used: not used for line overlays";
line(end + 1) = "- smoothing applied: none in this comparison layer (reused precomputed tables)";
line(end + 1) = "- justification: normalized overlays expose co-variation and peak alignment directly.";

reportText = strjoin(line, newline);
end

function line = peakLine(peakTbl, name)
row = peakTbl(strcmp(peakTbl.series, name), :);
if isempty(row) || ~isfinite(row.peak_T_K(1))
    line = sprintf('- `%s`: peak unavailable', name);
    return;
end
line = sprintf('- `%s`: peak at %.3f K (value = %.6g)', name, row.peak_T_K(1), row.peak_value(1));
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);

files = {};
cand = { ...
    fullfile(runDir, 'reports', 'switching_shape_sector_vs_collapse_asymmetry.md'), ...
    fullfile(runDir, 'tables', 'epsilon_asymmetry_vs_shape_aligned.csv'), ...
    fullfile(runDir, 'tables', 'epsilon_asymmetry_vs_shape_correlations.csv'), ...
    fullfile(runDir, 'tables', 'epsilon_asymmetry_vs_shape_peaks.csv'), ...
    fullfile(runDir, 'figures', 'epsilon_shape_overlay_main.png'), ...
    fullfile(runDir, 'figures', 'epsilon_shape_overlay_aux.png')};
for i = 1:numel(cand)
    if exist(cand{i}, 'file') == 2
        files{end + 1} = cand{i}; %#ok<AGROW>
    end
end

if exist(zipPath, 'file') == 2
    delete(zipPath);
end
if ~isempty(files)
    zip(zipPath, files, runDir);
end
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
clean = strrep(txt, sprintf('\r\n'), sprintf('\n'));
fprintf(fid, '%s', clean);
if ~endsWith(clean, newline)
    fprintf(fid, '\n');
end
fclose(fid);
end

function s = stampNow()
s = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end

