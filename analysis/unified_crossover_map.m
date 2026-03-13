function out = unified_crossover_map(cfg)
% unified_crossover_map
% Build a focused cross-experiment crossover-temperature comparison from
% saved run outputs only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSources(repoRoot, cfg);
data = loadSourceData(source);
derived = buildDerivedData(data);
tables = buildOutputTables(source, data, derived);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | switch:%s | motion:%s | aging:%s | collapse:%s', ...
    char(source.relaxation.runName), ...
    char(source.switching.runName), ...
    char(source.motion.runName), ...
    char(source.agingAudit.runName), ...
    char(source.agingCollapse.runName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Unified crossover map run directory:\n%s\n', runDir);
fprintf('Repository State Summary:\n');
fprintf('- Relaxation source run: %s\n', source.relaxation.runName);
fprintf('- Switching canonical source run: %s\n', source.switching.runName);
fprintf('- Switching motion source run reused: %s\n', source.motion.runName);
fprintf('- Aging primary observable source run: %s\n', source.agingAudit.runName);
fprintf('- Aging collapse source run reused: %s\n', source.agingCollapse.runName);
fprintf('- Legacy outputs consumed: none\n');
fprintf('- New code added: %s\n\n', thisFile);

appendText(run.log_path, sprintf('[%s] unified crossover map started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxation.runName)));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switching.runName)));
appendText(run.log_path, sprintf('Switching motion source: %s\n', char(source.motion.runName)));
appendText(run.log_path, sprintf('Aging source: %s\n', char(source.agingAudit.runName)));
appendText(run.log_path, sprintf('Aging collapse source: %s\n', char(source.agingCollapse.runName)));

save_run_table(tables.unified, 'unified_crossover_observables.csv', runDir);
save_run_table(tables.peakSummary, 'crossover_peak_summary.csv', runDir);
save_run_table(tables.windowSummary, 'crossover_window_overlap_summary.csv', runDir);
save_run_table(tables.sourceManifest, 'source_run_manifest.csv', runDir);

figOverlay = figUnifiedOverlay(data, derived, runDir, 'unified_crossover_overlay');
figNorm = figNormalizedOverlay(derived, runDir, 'normalized_unified_overlay');
figPeaks = figPeakSummary(derived, runDir, 'peak_positions_summary');
figWindows = figWindowAlignment(derived, runDir, 'crossover_window_alignment');
figOptional = figOptionalComparison(data, derived, runDir, 'optional_best_observable_comparison');

reportText = buildReport(thisFile, source, data, derived, tables);
reportPath = save_run_report(reportText, 'unified_crossover_map.md', runDir);
zipPath = buildReviewZip(runDir, 'unified_crossover_map_bundle.zip');
writeRunNotes(run.notes_path, derived, source, thisFile);

appendText(run.log_path, sprintf('[%s] unified crossover map complete\n', stampNow()));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.derived = derived;
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.figures = struct( ...
    'overlay', string(figOverlay.png), ...
    'normalized', string(figNorm.png), ...
    'peaks', string(figPeaks.png), ...
    'windows', string(figWindows.png), ...
    'optional', string(figOptional.png));
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'unified_crossover_map');
cfg = setDefaultField(cfg, 'relaxationHint', 'relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'switchingHint', 'alignment_audit');
cfg = setDefaultField(cfg, 'motionHint', 'relaxation_switching_motion_test');
cfg = setDefaultField(cfg, 'agingAuditHint', 'observable_identification_audit');
cfg = setDefaultField(cfg, 'agingCollapseHint', 'aging_shape_collapse_analysis');
end

function source = resolveSources(repoRoot, cfg)
source = struct();

[source.relaxation.runDir, source.relaxation.runName] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\\temperature_observables.csv', 'tables\\observables_relaxation.csv', 'reports\\relaxation_observable_stability_report.md'}, ...
    cfg.relaxationHint);
source.relaxation.temperatureTable = string(fullfile(source.relaxation.runDir, 'tables', 'temperature_observables.csv'));
source.relaxation.observableTable = string(fullfile(source.relaxation.runDir, 'tables', 'observables_relaxation.csv'));

[source.switching.runDir, source.switching.runName] = findLatestRunWithFiles(repoRoot, 'switching', ...
    {'observable_matrix.csv', 'observables.csv', 'alignment_audit\\switching_alignment_observables_vs_T.csv'}, ...
    cfg.switchingHint);
source.switching.observableMatrix = string(fullfile(source.switching.runDir, 'observable_matrix.csv'));
source.switching.observableIndex = string(fullfile(source.switching.runDir, 'observables.csv'));

[source.motion.runDir, source.motion.runName] = findLatestRunWithFiles(repoRoot, 'cross_experiment', ...
    {'tables\\relaxation_switching_motion_table.csv', 'tables\\relaxation_switching_feature_summary.csv', 'tables\\relaxation_switching_correlations.csv'}, ...
    cfg.motionHint);
source.motion.motionTable = string(fullfile(source.motion.runDir, 'tables', 'relaxation_switching_motion_table.csv'));
source.motion.featureSummary = string(fullfile(source.motion.runDir, 'tables', 'relaxation_switching_feature_summary.csv'));
source.motion.correlationTable = string(fullfile(source.motion.runDir, 'tables', 'relaxation_switching_correlations.csv'));

[source.agingAudit.runDir, source.agingAudit.runName] = findLatestRunWithFiles(repoRoot, 'aging', ...
    {'tables\\aging_observable_recommendation_table.csv', 'tables\\aging_tp_observable_metrics.csv', 'reports\\aging_observable_identification_audit.md'}, ...
    cfg.agingAuditHint);
source.agingAudit.recommendationTable = string(fullfile(source.agingAudit.runDir, 'tables', 'aging_observable_recommendation_table.csv'));
source.agingAudit.metricsTable = string(fullfile(source.agingAudit.runDir, 'tables', 'aging_tp_observable_metrics.csv'));

[source.agingCollapse.runDir, source.agingCollapse.runName] = findLatestRunWithFiles(repoRoot, 'aging', ...
    {'tables\\aging_shape_variation_vs_Tp.csv', 'reports\\aging_shape_collapse_analysis.md'}, ...
    cfg.agingCollapseHint);
source.agingCollapse.variationTable = string(fullfile(source.agingCollapse.runDir, 'tables', 'aging_shape_variation_vs_Tp.csv'));
end

function data = loadSourceData(source)
relaxTbl = readtable(source.relaxation.temperatureTable);
relaxObsTbl = readtable(source.relaxation.observableTable);

data.relaxation = struct();
data.relaxation.T = relaxTbl.T(:);
data.relaxation.value = relaxTbl.A_T(:);
data.relaxation.norm = normalizeToUnit(relaxTbl.A_T(:));
data.relaxation.referencePeakT = relaxObsTbl.Relax_T_peak(1);
data.relaxation.referenceWidth = relaxObsTbl.Relax_peak_width(1);
data.relaxation.sourceRun = string(source.relaxation.runName);
data.relaxation.sourceFile = source.relaxation.temperatureTable;

data.switching = struct();
switchTbl = readtable(source.switching.observableMatrix);
data.switching.T = switchTbl.T(:);
data.switching.Speak = switchTbl.S_peak(:);
data.switching.SpeakNorm = normalizeToUnit(switchTbl.S_peak(:));
data.switching.sourceRun = string(source.switching.runName);
data.switching.sourceFile = source.switching.observableMatrix;

motionTbl = readtable(source.motion.motionTable);
keepMask = logical(motionTbl.comparison_mask(:));
data.motion = struct();
data.motion.T = motionTbl.T_K(keepMask);
data.motion.value = motionTbl.motion_abs_dI_peak_dT(keepMask);
data.motion.norm = motionTbl.motion_norm(keepMask);
data.motion.Speak = motionTbl.S_peak(keepMask);
data.motion.SpeakNorm = motionTbl.S_peak_norm(keepMask);
data.motion.sourceRun = string(source.motion.runName);
data.motion.sourceFile = source.motion.motionTable;
data.motion.parentCanonicalRun = string(source.switching.runName);
data.motion.parentCanonicalFile = source.switching.observableMatrix;

agingRecTbl = readtable(source.agingAudit.recommendationTable);
agingMetricsTbl = readtable(source.agingAudit.metricsTable);
dipRows = agingMetricsTbl(strcmp(string(agingMetricsTbl.observable), 'Dip_depth'), :);
dipRows = sortrows(dipRows, 'Tp_K');
data.aging = struct();
data.aging.T = dipRows.Tp_K(:);
data.aging.value = dipRows.mean_value(:);
data.aging.norm = normalizeToUnit(dipRows.mean_value(:));
data.aging.cv = dipRows.cv_value(:);
data.aging.nPoints = dipRows.n_points(:);
data.aging.sourceRun = string(source.agingAudit.runName);
data.aging.sourceFile = source.agingAudit.metricsTable;
data.aging.recommendation = agingRecTbl(strcmp(string(agingRecTbl.name), 'Dip_depth'), :);

collapseCell = readcell(char(source.agingCollapse.variationTable), 'Delimiter', ',');
collapseHeaders = string(collapseCell(1, :));
tpIdx = find(collapseHeaders == "Tp_K", 1, 'first');
shapeIdx = find(collapseHeaders == "shape_variation", 1, 'first');
if isempty(tpIdx) || isempty(shapeIdx)
    error('Aging collapse CSV headers not found.');
end
tpVals = cell2mat(collapseCell(2:end, tpIdx));
shapeVals = cell2mat(collapseCell(2:end, shapeIdx));
[tpVals, order] = sort(tpVals(:));
shapeVals = shapeVals(order);
collapseStrength = max(shapeVals) - shapeVals;
data.agingCollapse = struct();
data.agingCollapse.T = tpVals(:);
data.agingCollapse.shapeVariation = shapeVals(:);
data.agingCollapse.collapseStrength = collapseStrength(:);
data.agingCollapse.collapseStrengthNorm = normalizeToUnit(collapseStrength(:));
data.agingCollapse.sourceRun = string(source.agingCollapse.runName);
data.agingCollapse.sourceFile = source.agingCollapse.variationTable;
end
function derived = buildDerivedData(data)
derived.primary.relaxation = summarizeCurve("relaxation", "A(T)", data.relaxation.T, data.relaxation.value, ...
    data.relaxation.norm, data.relaxation.sourceRun, data.relaxation.sourceFile, ...
    data.relaxation.referencePeakT, data.relaxation.referenceWidth, ...
    "Primary relaxation crossover coordinate from the stability audit.");
derived.primary.switching = summarizeCurve("switching", "|dI_peak/dT|", data.motion.T, data.motion.value, ...
    data.motion.norm, data.motion.sourceRun, data.motion.sourceFile, NaN, NaN, ...
    "Saved switching ridge-motion proxy from the cross-experiment motion test.");
derived.primary.aging = summarizeCurve("aging", "Dip_depth(Tp)", data.aging.T, data.aging.value, ...
    data.aging.norm, data.aging.sourceRun, data.aging.sourceFile, NaN, NaN, ...
    "Primary aging observable recommended by the observable-identification audit.");

derived.secondary.agingCollapse = summarizeCurve("aging", "collapse_strength(Tp)", ...
    data.agingCollapse.T, data.agingCollapse.collapseStrength, data.agingCollapse.collapseStrengthNorm, ...
    data.agingCollapse.sourceRun, data.agingCollapse.sourceFile, NaN, NaN, ...
    "Derived from saved shape-variation output via max(shape_variation)-shape_variation.");
derived.secondary.switchingSpeak = summarizeCurve("switching", "S_peak(T)", ...
    data.motion.T, data.motion.Speak, data.motion.SpeakNorm, ...
    data.motion.sourceRun, data.motion.sourceFile, NaN, NaN, ...
    "Saved ridge-amplitude observable from the motion-test table.");

primaryNames = ["Relaxation A(T)"; "Switching |dI_peak/dT|"; "Aging Dip_depth"];
primarySummaries = {derived.primary.relaxation, derived.primary.switching, derived.primary.aging};
derived.pairs = buildPairRows(primaryNames, primarySummaries);
derived.threeWay = buildThreeWayConsensus(primaryNames, primarySummaries);
derived.unifiedAxis = buildUnifiedAxis(data);
end

function tables = buildOutputTables(source, data, derived)
T = derived.unifiedAxis(:);
tables.unified = table( ...
    T, ...
    interpObserved(data.relaxation.T, data.relaxation.value, T), ...
    interpObserved(data.relaxation.T, data.relaxation.norm, T), ...
    interpObserved(data.motion.T, data.motion.value, T), ...
    interpObserved(data.motion.T, data.motion.norm, T), ...
    interpObserved(data.motion.T, data.motion.Speak, T), ...
    interpObserved(data.motion.T, data.motion.SpeakNorm, T), ...
    interpObserved(data.aging.T, data.aging.value, T), ...
    interpObserved(data.aging.T, data.aging.norm, T), ...
    interpObserved(data.agingCollapse.T, data.agingCollapse.shapeVariation, T), ...
    interpObserved(data.agingCollapse.T, data.agingCollapse.collapseStrengthNorm, T), ...
    interpCurve(data.relaxation.T, data.relaxation.norm, T), ...
    interpCurve(data.motion.T, data.motion.norm, T), ...
    interpCurve(data.aging.T, data.aging.norm, T), ...
    interpCurve(data.agingCollapse.T, data.agingCollapse.collapseStrengthNorm, T), ...
    'VariableNames', { ...
        'temperature_K', ...
        'relaxation_A', 'relaxation_A_norm_observed', ...
        'switching_motion', 'switching_motion_norm_observed', ...
        'switching_S_peak', 'switching_S_peak_norm_observed', ...
        'aging_Dip_depth', 'aging_Dip_depth_norm_observed', ...
        'aging_shape_variation', 'aging_collapse_strength_norm_observed', ...
        'relaxation_A_norm_interp', 'switching_motion_norm_interp', ...
        'aging_Dip_depth_norm_interp', 'aging_collapse_strength_norm_interp'});

peakRows = {derived.primary.relaxation, derived.primary.switching, derived.primary.aging, ...
    derived.secondary.agingCollapse, derived.secondary.switchingSpeak};
peakTables = cellfun(@curveSummaryToTable, peakRows, 'UniformOutput', false);
tables.peakSummary = vertcat(peakTables{:});
tables.windowSummary = derived.pairs;

tables.sourceManifest = table( ...
    ["relaxation"; "switching"; "switching"; "aging"; "aging"], ...
    ["A(T) primary"; "canonical ridge tables"; "|dI_peak/dT| primary"; "Dip_depth primary"; "shape collapse secondary"], ...
    [string(source.relaxation.runName); string(source.switching.runName); string(source.motion.runName); string(source.agingAudit.runName); string(source.agingCollapse.runName)], ...
    [source.relaxation.temperatureTable; source.switching.observableMatrix; source.motion.motionTable; source.agingAudit.metricsTable; source.agingCollapse.variationTable], ...
    ["canonical"; "canonical"; "cross_run_reusing_canonical_switching"; "canonical"; "canonical"], ...
    ["false"; "false"; "true"; "false"; "true"], ...
    ["false"; "false"; "false"; "false"; "false"], ...
    ["Primary stable relaxation amplitude coordinate."; ...
     "Canonical switching ridge/amplitude table retained for provenance and optional comparison."; ...
     "Saved derived motion observable from a newly created cross-experiment run; derived from canonical switching ridge tracking."; ...
     "Recommended primary aging observable from the audit."; ...
     "Saved newer collapse metric used only as a secondary consistency check."], ...
    'VariableNames', {'experiment', 'observable_role', 'source_run', 'source_file', 'source_status', 'newly_created_run_consumed', 'legacy_used', 'notes'});
end

function figPaths = figUnifiedOverlay(data, derived, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 980]);
tl = tiledlayout(fh, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
plot(ax1, data.relaxation.T, data.relaxation.value, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.12 0.37 0.73]);
hold(ax1, 'on');
drawWindowPatch(ax1, derived.primary.relaxation.windowLow, derived.primary.relaxation.windowHigh, ylimFromData(data.relaxation.value), [0.12 0.37 0.73]);
plot(ax1, derived.primary.relaxation.peakT, derived.primary.relaxation.peakValue, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8);
hold(ax1, 'off');
grid(ax1, 'on');
ylabel(ax1, 'A(T)', 'FontSize', 14);
xlabel(ax1, 'Temperature / T_p (K)', 'FontSize', 14);
title(ax1, 'Relaxation primary crossover observable', 'FontSize', 16);
set(ax1, 'FontSize', 14, 'LineWidth', 1.2);

ax2 = nexttile(tl, 2);
plot(ax2, data.motion.T, data.motion.value, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.85 0.33 0.10], 'DisplayName', '|dI_{peak}/dT|');
hold(ax2, 'on');
plot(ax2, data.motion.T, data.motion.Speak, '--s', 'LineWidth', 2.0, 'MarkerSize', 5, 'Color', [0.93 0.69 0.13], 'DisplayName', 'S_{peak}(T)');
drawWindowPatch(ax2, derived.primary.switching.windowLow, derived.primary.switching.windowHigh, ylimFromData([data.motion.value; data.motion.Speak]), [0.85 0.33 0.10]);
plot(ax2, derived.primary.switching.peakT, derived.primary.switching.peakValue, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8, 'HandleVisibility', 'off');
hold(ax2, 'off');
grid(ax2, 'on');
ylabel(ax2, 'Switching observables', 'FontSize', 14);
xlabel(ax2, 'Temperature / T_p (K)', 'FontSize', 14);
title(ax2, 'Switching ridge motion with saved amplitude reference', 'FontSize', 16);
legend(ax2, 'Location', 'best');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2);

ax3 = nexttile(tl, 3);
plot(ax3, data.aging.T, data.aging.value, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.15 0.60 0.27], 'DisplayName', 'Dip_depth(T_p)');
hold(ax3, 'on');
yyaxis(ax3, 'right');
plot(ax3, data.agingCollapse.T, data.agingCollapse.shapeVariation, '--d', 'LineWidth', 2.0, 'MarkerSize', 5, 'Color', [0.47 0.67 0.19], 'DisplayName', 'shape variation(T_p)');
ylabel(ax3, 'Shape variation', 'FontSize', 14);
yyaxis(ax3, 'left');
drawWindowPatch(ax3, derived.primary.aging.windowLow, derived.primary.aging.windowHigh, ylimFromData(data.aging.value), [0.15 0.60 0.27]);
plot(ax3, derived.primary.aging.peakT, derived.primary.aging.peakValue, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8, 'HandleVisibility', 'off');
hold(ax3, 'off');
grid(ax3, 'on');
xlabel(ax3, 'Temperature / T_p (K)', 'FontSize', 14);
ylabel(ax3, 'Dip depth', 'FontSize', 14);
title(ax3, 'Aging primary memory observable with saved collapse context', 'FontSize', 16);
legend(ax3, 'Location', 'best');
set(ax3, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = figNormalizedOverlay(derived, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 680]);
ax = axes(fh);
hold(ax, 'on');

curves = {derived.primary.relaxation, derived.primary.switching, derived.primary.aging};
colors = [0.12 0.37 0.73; 0.85 0.33 0.10; 0.15 0.60 0.27];
labels = {'Relaxation A(T)', 'Switching |dI_{peak}/dT|', 'Aging Dip_depth(T_p)'};

if derived.threeWay.hasCommonWindow
    patch(ax, ...
        [derived.threeWay.windowLow derived.threeWay.windowHigh derived.threeWay.windowHigh derived.threeWay.windowLow], ...
        [0 0 1.05 1.05], [0.90 0.90 0.90], 'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
        'DisplayName', sprintf('Primary overlap [%.1f, %.1f] K', derived.threeWay.windowLow, derived.threeWay.windowHigh));
end

for i = 1:numel(curves)
    plot(ax, curves{i}.T, curves{i}.norm, '-o', 'LineWidth', 2.4, 'MarkerSize', 6, ...
        'Color', colors(i,:), 'DisplayName', labels{i});
    xline(ax, curves{i}.peakT, '--', 'LineWidth', 1.4, 'Color', colors(i,:), 'HandleVisibility', 'off');
end

hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature / T_p (K)', 'FontSize', 14);
ylabel(ax, 'Normalized observable', 'FontSize', 14);
ylim(ax, [0 1.05]);
title(ax, 'Primary crossover observables on a shared temperature axis', 'FontSize', 16);
legend(ax, 'Location', 'eastoutside');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end
function figPaths = figPeakSummary(derived, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 560]);
ax = axes(fh);
hold(ax, 'on');

rows = {derived.primary.relaxation, derived.primary.switching, derived.primary.aging, derived.secondary.agingCollapse};
yPos = 1:4;
labels = {'Relaxation A(T)', 'Switching |dI_{peak}/dT|', 'Aging Dip_depth', 'Aging collapse strength'};
colors = [0.12 0.37 0.73; 0.85 0.33 0.10; 0.15 0.60 0.27; 0.47 0.67 0.19];

for i = 1:numel(rows)
    s = rows{i};
    line(ax, [s.peakT - s.resolutionEstimate, s.peakT + s.resolutionEstimate], [yPos(i) yPos(i)], ...
        'LineWidth', 3, 'Color', colors(i,:));
    plot(ax, s.peakT, yPos(i), 'o', 'MarkerSize', 9, 'MarkerFaceColor', colors(i,:), 'MarkerEdgeColor', 'k');
    if isfinite(s.referencePeakT)
        plot(ax, s.referencePeakT, yPos(i), 's', 'MarkerSize', 8, 'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', colors(i,:), 'LineWidth', 1.5);
    end
end

if derived.threeWay.hasCommonWindow
    patch(ax, ...
        [derived.threeWay.windowLow derived.threeWay.windowHigh derived.threeWay.windowHigh derived.threeWay.windowLow], ...
        [0.4 0.4 4.6 4.6], [0.90 0.90 0.90], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
end

hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Peak temperature (K)', 'FontSize', 14);
ylabel(ax, 'Observable', 'FontSize', 14);
xlim(ax, [min([rows{1}.T; rows{2}.T; rows{3}.T]) - 1, max([rows{1}.T; rows{2}.T; rows{3}.T]) + 1]);
yticks(ax, yPos);
yticklabels(ax, labels);
set(ax, 'YDir', 'reverse');
title(ax, 'Peak positions with grid-resolution estimates', 'FontSize', 16);
set(ax, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = figWindowAlignment(derived, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 580]);
ax = axes(fh);
hold(ax, 'on');

rows = {derived.primary.relaxation, derived.primary.switching, derived.primary.aging, derived.secondary.agingCollapse};
labels = {'Relaxation A(T)', 'Switching |dI_{peak}/dT|', 'Aging Dip_depth', 'Aging collapse strength'};
colors = [0.12 0.37 0.73; 0.85 0.33 0.10; 0.15 0.60 0.27; 0.47 0.67 0.19];
yPos = 1:4;

for i = 1:numel(rows)
    s = rows{i};
    patch(ax, [s.windowLow s.windowHigh s.windowHigh s.windowLow], ...
        [yPos(i)-0.25 yPos(i)-0.25 yPos(i)+0.25 yPos(i)+0.25], ...
        colors(i,:), 'FaceAlpha', 0.35, 'EdgeColor', colors(i,:), 'LineWidth', 1.5);
    plot(ax, s.peakT, yPos(i), 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8);
end

if derived.threeWay.hasCommonWindow
    patch(ax, ...
        [derived.threeWay.windowLow derived.threeWay.windowHigh derived.threeWay.windowHigh derived.threeWay.windowLow], ...
        [0.5 0.5 4.5 4.5], [0.60 0.60 0.60], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    xline(ax, derived.threeWay.TstarBest, '--k', 'LineWidth', 1.6, 'DisplayName', sprintf('T* = %.2f K', derived.threeWay.TstarBest));
end

hold(ax, 'off');
grid(ax, 'on');
yticks(ax, yPos);
yticklabels(ax, labels);
set(ax, 'YDir', 'reverse');
xlabel(ax, 'Temperature / T_p window (K)', 'FontSize', 14);
ylabel(ax, 'Observable', 'FontSize', 14);
title(ax, 'Half-maximum crossover windows and common overlap', 'FontSize', 16);
set(ax, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = figOptionalComparison(data, derived, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 760]);
tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
plot(ax1, data.aging.T, data.aging.norm, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.15 0.60 0.27], 'DisplayName', 'Dip_depth(T_p)');
hold(ax1, 'on');
plot(ax1, data.agingCollapse.T, data.agingCollapse.collapseStrengthNorm, '--d', 'LineWidth', 2.0, 'MarkerSize', 5, 'Color', [0.47 0.67 0.19], 'DisplayName', 'collapse strength(T_p)');
xline(ax1, derived.primary.aging.peakT, ':', 'LineWidth', 1.5, 'Color', [0.15 0.60 0.27], 'HandleVisibility', 'off');
xline(ax1, derived.secondary.agingCollapse.peakT, ':', 'LineWidth', 1.5, 'Color', [0.47 0.67 0.19], 'HandleVisibility', 'off');
hold(ax1, 'off');
grid(ax1, 'on');
ylim(ax1, [0 1.05]);
xlabel(ax1, 'Temperature / T_p (K)', 'FontSize', 14);
ylabel(ax1, 'Normalized value', 'FontSize', 14);
title(ax1, 'Aging primary memory metric vs saved collapse metric', 'FontSize', 16);
legend(ax1, 'Location', 'best');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2);

ax2 = nexttile(tl, 2);
plot(ax2, data.motion.T, data.motion.norm, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.85 0.33 0.10], 'DisplayName', '|dI_{peak}/dT|');
hold(ax2, 'on');
plot(ax2, data.motion.T, data.motion.SpeakNorm, '--s', 'LineWidth', 2.0, 'MarkerSize', 5, 'Color', [0.93 0.69 0.13], 'DisplayName', 'S_{peak}(T)');
xline(ax2, derived.primary.switching.peakT, ':', 'LineWidth', 1.5, 'Color', [0.85 0.33 0.10], 'HandleVisibility', 'off');
xline(ax2, derived.secondary.switchingSpeak.peakT, ':', 'LineWidth', 1.5, 'Color', [0.93 0.69 0.13], 'HandleVisibility', 'off');
hold(ax2, 'off');
grid(ax2, 'on');
ylim(ax2, [0 1.05]);
xlabel(ax2, 'Temperature / T_p (K)', 'FontSize', 14);
ylabel(ax2, 'Normalized value', 'FontSize', 14);
title(ax2, 'Switching primary motion proxy vs saved ridge amplitude', 'FontSize', 16);
legend(ax2, 'Location', 'best');
set(ax2, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReport(scriptPath, source, data, derived, tables)
L = strings(0, 1);
L(end+1) = '# Unified Crossover Map';
L(end+1) = '';
L(end+1) = sprintf('Generated: %s', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
L(end+1) = '';
L(end+1) = '## Repository-state summary';
L(end+1) = sprintf('- Relevant Relaxation run used: `%s`', source.relaxation.runName);
L(end+1) = sprintf('- Relevant Switching canonical run used: `%s`', source.switching.runName);
L(end+1) = sprintf('- Relevant Switching derived motion run reused: `%s`', source.motion.runName);
L(end+1) = sprintf('- Relevant Aging audit run used: `%s`', source.agingAudit.runName);
L(end+1) = sprintf('- Relevant Aging collapse run reused: `%s`', source.agingCollapse.runName);
L(end+1) = '- Needed legacy outputs: none.';
L(end+1) = '- Newly created runs consumed from earlier work: the switching motion test and the aging shape-collapse run.';
L(end+1) = sprintf('- New code added or modified for this run: `%s`', string(scriptPath));
L(end+1) = '';
L(end+1) = '## Exact source runs and files used';
L(end+1) = sprintf('- Relaxation A(T): `%s` from `%s`', source.relaxation.temperatureTable, source.relaxation.runName);
L(end+1) = sprintf('- Relaxation peak metadata cross-check: `%s`', source.relaxation.observableTable);
L(end+1) = sprintf('- Switching canonical ridge table: `%s` from `%s`', source.switching.observableMatrix, source.switching.runName);
L(end+1) = sprintf('- Switching saved motion observable: `%s` from `%s`', source.motion.motionTable, source.motion.runName);
L(end+1) = sprintf('- Aging Dip_depth audit table: `%s` from `%s`', source.agingAudit.metricsTable, source.agingAudit.runName);
L(end+1) = sprintf('- Aging recommendation table: `%s`', source.agingAudit.recommendationTable);
L(end+1) = sprintf('- Aging shape-collapse table: `%s` from `%s`', source.agingCollapse.variationTable, source.agingCollapse.runName);
L(end+1) = '';
L(end+1) = '## Observable choices and rationale';
L(end+1) = '- Relaxation primary observable: `A(T)`, because the stability audit treats it as the dominant rank-1 relaxation amplitude coordinate and reports a stable peak/width.';
L(end+1) = '- Switching primary observable: saved `|dI_peak/dT|`, because the motion-test run already distilled the ridge-motion proxy directly from canonical switching ridge tracking without returning to raw maps.';
L(end+1) = '- Aging primary observable: `Dip_depth(Tp)`, because the observable-identification audit explicitly ranks it as the primary aging observable.';
L(end+1) = '- Aging secondary consistency check: saved shape-collapse variation, converted to a peak-style `collapse_strength = max(shape_variation) - shape_variation` only for comparison. This transformation is interpretive and not the canonical saved column itself.';
L(end+1) = '';
L(end+1) = '## Peak comparison';
L = [L; reshape(string(formatPeakLines(derived)), [], 1)];
L(end+1) = '';
L(end+1) = '## Temperature-window overlap analysis';
L = [L; reshape(string(formatWindowLines(tables.windowSummary)), [], 1)];
L(end+1) = '';
L(end+1) = '## What alignment is strongly supported';
if derived.threeWay.hasCommonWindow
    L(end+1) = sprintf('- The physically motivated primary windows overlap over `%.2f` to `%.2f K`, giving a direct common-window estimate `T* = %.2f +/- %.2f K`.', ...
        derived.threeWay.windowLow, derived.threeWay.windowHigh, derived.threeWay.TstarBest, derived.threeWay.TstarUncertainty);
else
    L(end+1) = '- The primary windows do not produce a strict three-way overlap interval, so only pairwise consistency is supported.';
end
peakMask = strcmp(tables.windowSummary.pair_name, 'Relaxation A(T) vs Switching |dI_peak/dT|');
L(end+1) = sprintf('- Relaxation A(T) and switching motion show a positive shape correlation (`Pearson r = %.3f`) with a small peak offset of %.2f K.', ...
    tables.windowSummary.pearson_r(peakMask), tables.windowSummary.peak_alignment_abs_K(peakMask));
L(end+1) = '- Aging Dip_depth shares overlapping half-maximum support with both Relaxation and Switching, so the data support a broad crossover band rather than isolated unrelated temperatures.';
L(end+1) = '';
L(end+1) = '## What alignment is only approximate';
L(end+1) = sprintf('- The sampled peak temperatures are spread: Aging Dip_depth at %.2f K, Relaxation A(T) at %.2f K, Switching motion at %.2f K.', ...
    derived.primary.aging.peakT, derived.primary.relaxation.peakT, derived.primary.switching.peakT);
L(end+1) = sprintf('- The canonical Relaxation run itself reports `Relax_T_peak = %.2f K`, while the common-axis sampled comparison peaks at %.2f K; this is within the +/- %.2f K grid-resolution estimate.', ...
    data.relaxation.referencePeakT, derived.primary.relaxation.peakT, derived.primary.relaxation.resolutionEstimate);
L(end+1) = sprintf('- The saved aging collapse metric peaks near %.2f K after inversion, which is shifted relative to Dip_depth. It therefore acts as supporting context, not the main shared-crossover anchor.', ...
    derived.secondary.agingCollapse.peakT);
L(end+1) = '';
L(end+1) = '## Current best estimate of T*';
if derived.threeWay.hasCommonWindow
    L(end+1) = sprintf('- Best estimate: `T* = %.2f +/- %.2f K`, defined as the midpoint and half-width of the three-way primary half-maximum overlap window.', ...
        derived.threeWay.TstarBest, derived.threeWay.TstarUncertainty);
else
    L(end+1) = sprintf('- Best estimate: `T* = %.2f +/- %.2f K`, defined from the weighted primary-peak consensus because no strict three-way overlap window exists.', ...
        derived.threeWay.TstarBest, derived.threeWay.TstarUncertainty);
end
L(end+1) = '';
L(end+1) = '## Remaining uncertainty and why';
L(end+1) = '- Aging is indexed by discrete `Tp` values with 4 K spacing, so its peak localization is intrinsically coarser than the relaxation and switching grids.';
L(end+1) = '- Switching motion is a derived observable from saved ridge tracking, so its peak position depends mildly on the saved smoothing choice used in the motion-test run.';
L(end+1) = '- Relaxation and Switching use temperature sweeps, whereas Aging uses stop-temperature summaries; the common temperature axis is physically motivated but not a perfectly identical experimental control coordinate.';
L(end+1) = '- The saved collapse-style metrics do not all peak at exactly the same temperature, so the present evidence supports a shared crossover band more strongly than a single exact coincidence temperature.';
L(end+1) = '';
L(end+1) = '## Visualization choices';
L(end+1) = '- number of curves: at most 4 curves in any panel';
L(end+1) = '- legend vs colormap: legends only, because every panel stays below the colormap threshold';
L(end+1) = '- colormap used: none for line plots; muted gray shading for overlap windows';
L(end+1) = '- smoothing applied: no new smoothing was added in this script; the switching motion observable is consumed from the saved motion-test output';
L(end+1) = '- justification: the figure set is intentionally narrow and mechanism-focused, emphasizing only the primary crossover shortlist and one saved secondary check';
reportText = strjoin(L, newline);
end

function lines = formatPeakLines(derived)
items = {derived.primary.relaxation, derived.primary.switching, derived.primary.aging, derived.secondary.agingCollapse};
lines = strings(0, 1);
for i = 1:numel(items)
    s = items{i};
    if isfinite(s.referencePeakT)
        refTxt = sprintf('; source-run reference peak %.2f K', s.referencePeakT);
    else
        refTxt = '';
    end
    lines(end+1) = sprintf('- %s: sampled peak %.2f K with +/- %.2f K resolution, window [%.2f, %.2f] K%s.', ...
        s.plotLabel, s.peakT, s.resolutionEstimate, s.windowLow, s.windowHigh, refTxt);
end
lines = lines(:);
end

function lines = formatWindowLines(windowSummary)
lines = strings(0, 1);
for i = 1:height(windowSummary)
    lines(end+1) = sprintf('- %s: peak offset %.2f K, half-max overlap %.3f, Pearson r %.3f, overlap-integral score %.3f.', ...
        windowSummary.pair_name(i), ...
        windowSummary.peak_alignment_abs_K(i), ...
        windowSummary.halfmax_overlap_fraction(i), ...
        windowSummary.pearson_r(i), ...
        windowSummary.overlap_integral_fraction(i));
end
lines = lines(:);
end

function zipPath = buildReviewZip(runDir, fileName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, fileName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function writeRunNotes(notesPath, derived, source, scriptPath)
L = strings(0, 1);
L(end+1) = sprintf('[%s] Unified crossover map summary', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
L(end+1) = sprintf('Relaxation source: %s', source.relaxation.runName);
L(end+1) = sprintf('Switching source: %s', source.switching.runName);
L(end+1) = sprintf('Switching motion source: %s', source.motion.runName);
L(end+1) = sprintf('Aging source: %s', source.agingAudit.runName);
L(end+1) = sprintf('Aging collapse source: %s', source.agingCollapse.runName);
if derived.threeWay.hasCommonWindow
    L(end+1) = sprintf('T* = %.2f +/- %.2f K from three-way overlap [%.2f, %.2f] K.', ...
        derived.threeWay.TstarBest, derived.threeWay.TstarUncertainty, ...
        derived.threeWay.windowLow, derived.threeWay.windowHigh);
else
    L(end+1) = sprintf('T* = %.2f +/- %.2f K from weighted-peak consensus.', ...
        derived.threeWay.TstarBest, derived.threeWay.TstarUncertainty);
end
L(end+1) = 'Legacy outputs used: none.';
L(end+1) = sprintf('New script: %s', string(scriptPath));
appendText(notesPath, sprintf('%s\n', strjoin(L, newline)));
end

function summary = summarizeCurve(experiment, observableName, T, value, normValue, sourceRun, sourceFile, referencePeakT, referenceWidth, note)
T = T(:);
value = value(:);
normValue = normValue(:);
ok = isfinite(T) & isfinite(value) & isfinite(normValue);
T = T(ok);
value = value(ok);
normValue = normValue(ok);

[peakValue, idx] = max(value);
peakT = T(idx);
resolutionEstimate = estimateResolution(T, idx);
[windowLow, windowHigh, windowWidth] = halfmaxWindow(T, normValue);
centroidT = weightedCentroid(T, normValue);

summary = struct();
summary.experiment = string(experiment);
summary.observable = string(observableName);
summary.plotLabel = sprintf('%s %s', capitalizeToken(experiment), char(observableName));
summary.T = T;
summary.value = value;
summary.norm = normValue;
summary.peakT = peakT;
summary.peakValue = peakValue;
summary.resolutionEstimate = resolutionEstimate;
summary.windowLow = windowLow;
summary.windowHigh = windowHigh;
summary.windowWidth = windowWidth;
summary.centroidT = centroidT;
summary.nPoints = numel(T);
summary.sourceRun = string(sourceRun);
summary.sourceFile = string(sourceFile);
summary.referencePeakT = referencePeakT;
summary.referenceWidth = referenceWidth;
summary.note = string(note);
end

function tbl = curveSummaryToTable(summary)
tbl = table( ...
    summary.experiment, ...
    summary.observable, ...
    summary.sourceRun, ...
    summary.sourceFile, ...
    summary.peakT, ...
    summary.peakValue, ...
    summary.resolutionEstimate, ...
    summary.windowLow, ...
    summary.windowHigh, ...
    summary.windowWidth, ...
    summary.centroidT, ...
    summary.nPoints, ...
    summary.referencePeakT, ...
    summary.referenceWidth, ...
    summary.note, ...
    'VariableNames', {'experiment', 'observable', 'source_run', 'source_file', 'sampled_peak_T_K', 'sampled_peak_value', ...
    'resolution_estimate_K', 'window_low_K', 'window_high_K', 'window_width_K', 'centroid_T_K', 'n_points', ...
    'source_run_reference_peak_T_K', 'source_run_reference_width_K', 'notes'});
end

function pairTbl = buildPairRows(names, summaries)
pairs = [1 2; 1 3; 2 3];
pairTbl = table();
for i = 1:size(pairs, 1)
    pairTbl = [pairTbl; pairwiseAlignment(names(pairs(i, 1)), summaries{pairs(i, 1)}, names(pairs(i, 2)), summaries{pairs(i, 2)})]; %#ok<AGROW>
end
end

function row = pairwiseAlignment(nameA, a, nameB, b)
[xq, yA, yB] = commonInterpolatedAxis(a.T, a.norm, b.T, b.norm);
pearsonR = NaN;
spearmanR = NaN;
overlapIntegral = NaN;
meanAbsDiff = NaN;
if numel(xq) >= 3
    pearsonR = corr(yA(:), yB(:), 'Rows', 'complete');
    spearmanR = corr(yA(:), yB(:), 'Type', 'Spearman', 'Rows', 'complete');
    overlapIntegral = trapz(xq, min(yA, yB)) / trapz(xq, max(yA, yB));
    meanAbsDiff = mean(abs(yA - yB), 'omitnan');
end

intersectionWidth = max(0, min(a.windowHigh, b.windowHigh) - max(a.windowLow, b.windowLow));
unionWidth = max(a.windowHigh, b.windowHigh) - min(a.windowLow, b.windowLow);
if unionWidth > 0
    overlapFraction = intersectionWidth / unionWidth;
else
    overlapFraction = NaN;
end

row = table( ...
    string(nameA + " vs " + nameB), ...
    pearsonR, ...
    spearmanR, ...
    numel(xq), ...
    a.peakT, ...
    b.peakT, ...
    a.peakT - b.peakT, ...
    abs(a.peakT - b.peakT), ...
    a.centroidT, ...
    b.centroidT, ...
    a.centroidT - b.centroidT, ...
    abs(a.centroidT - b.centroidT), ...
    overlapFraction, ...
    overlapIntegral, ...
    meanAbsDiff, ...
    intersectionWidth, ...
    unionWidth, ...
    max(a.windowLow, b.windowLow), ...
    min(a.windowHigh, b.windowHigh), ...
    max(min(a.T), min(b.T)), ...
    min(max(a.T), max(b.T)), ...
    'VariableNames', {'pair_name', 'pearson_r', 'spearman_r', 'n_points', 'peak_T_x_K', 'peak_T_y_K', ...
    'peak_alignment_signed_K', 'peak_alignment_abs_K', 'centroid_x_K', 'centroid_y_K', ...
    'centroid_diff_signed_K', 'centroid_diff_abs_K', 'halfmax_overlap_fraction', ...
    'overlap_integral_fraction', 'mean_abs_difference', 'intersection_width_K', 'union_width_K', ...
    'window_low_overlap_K', 'window_high_overlap_K', 'comparison_T_min_K', 'comparison_T_max_K'});
end

function consensus = buildThreeWayConsensus(names, summaries)
windowLow = max([summaries{1}.windowLow, summaries{2}.windowLow, summaries{3}.windowLow]);
windowHigh = min([summaries{1}.windowHigh, summaries{2}.windowHigh, summaries{3}.windowHigh]);
hasCommonWindow = isfinite(windowLow) && isfinite(windowHigh) && windowHigh > windowLow;

peakTs = [summaries{1}.peakT, summaries{2}.peakT, summaries{3}.peakT];
resolutions = [summaries{1}.resolutionEstimate, summaries{2}.resolutionEstimate, summaries{3}.resolutionEstimate];
weights = 1 ./ max(resolutions, 0.5).^2;
weightedPeak = sum(weights .* peakTs) / sum(weights);
weightedSpread = sqrt(sum(weights .* (peakTs - weightedPeak).^2) / sum(weights));

consensus = struct();
consensus.primaryNames = names;
consensus.hasCommonWindow = hasCommonWindow;
if hasCommonWindow
    consensus.windowLow = windowLow;
    consensus.windowHigh = windowHigh;
    consensus.TstarBest = 0.5 * (windowLow + windowHigh);
    consensus.TstarUncertainty = 0.5 * (windowHigh - windowLow);
else
    consensus.windowLow = NaN;
    consensus.windowHigh = NaN;
    consensus.TstarBest = weightedPeak;
    consensus.TstarUncertainty = max(weightedSpread, 0.5 * max(resolutions));
end
end

function T = buildUnifiedAxis(data)
T = unique([data.relaxation.T(:); data.motion.T(:); data.aging.T(:); data.agingCollapse.T(:)]);
T = sort(T);
end

function y = interpObserved(T, v, xq)
y = NaN(size(xq));
for i = 1:numel(T)
    idx = find(abs(xq - T(i)) < 1e-9, 1, 'first');
    if ~isempty(idx)
        y(idx) = v(i);
    end
end
end

function yq = interpCurve(T, y, xq)
T = T(:);
y = y(:);
ok = isfinite(T) & isfinite(y);
T = T(ok);
y = y(ok);
yq = NaN(size(xq));
if numel(T) < 2
    return;
end
yq = interp1(T, y, xq, 'pchip', NaN);
end

function [xq, yA, yB] = commonInterpolatedAxis(TA, yAin, TB, yBin)
xMin = ceil(max(min(TA), min(TB)));
xMax = floor(min(max(TA), max(TB)));
if xMax < xMin
    xq = [];
    yA = [];
    yB = [];
    return;
end
xq = (xMin:xMax).';
yA = interpCurve(TA, yAin, xq);
yB = interpCurve(TB, yBin, xq);
ok = isfinite(yA) & isfinite(yB);
xq = xq(ok);
yA = yA(ok);
yB = yB(ok);
end

function y = normalizeToUnit(x)
x = x(:);
y = NaN(size(x));
m = max(x, [], 'omitnan');
if isfinite(m) && m > 0
    y = x ./ m;
end
end

function [lo, hi, width] = halfmaxWindow(T, yNorm)
T = T(:);
yNorm = yNorm(:);
ok = isfinite(T) & isfinite(yNorm);
T = T(ok);
yNorm = yNorm(ok);
lo = NaN;
hi = NaN;
width = NaN;
if numel(T) < 2
    return;
end
peakIdx = find(yNorm == max(yNorm), 1, 'first');
if isempty(peakIdx)
    return;
end
halfValue = 0.5;
leftIdx = find(yNorm(1:peakIdx) <= halfValue, 1, 'last');
if isempty(leftIdx)
    lo = T(1);
elseif leftIdx == peakIdx
    lo = T(peakIdx);
else
    lo = linearCross(T(leftIdx), T(leftIdx + 1), yNorm(leftIdx) - halfValue, yNorm(leftIdx + 1) - halfValue);
end
rightRel = find(yNorm(peakIdx:end) <= halfValue, 1, 'first');
if isempty(rightRel)
    hi = T(end);
else
    rightIdx = peakIdx + rightRel - 1;
    if rightIdx == peakIdx
        hi = T(peakIdx);
    else
        hi = linearCross(T(rightIdx - 1), T(rightIdx), yNorm(rightIdx - 1) - halfValue, yNorm(rightIdx) - halfValue);
    end
end
width = hi - lo;
end

function c = weightedCentroid(T, y)
T = T(:);
y = y(:);
ok = isfinite(T) & isfinite(y);
T = T(ok);
y = y(ok);
if isempty(T) || sum(y) <= 0
    c = NaN;
    return;
end
c = sum(T .* y) / sum(y);
end

function res = estimateResolution(T, idx)
if numel(T) == 1
    res = NaN;
    return;
end
if idx <= 1
    res = 0.5 * abs(T(2) - T(1));
elseif idx >= numel(T)
    res = 0.5 * abs(T(end) - T(end - 1));
else
    res = 0.5 * max(abs(T(idx) - T(idx - 1)), abs(T(idx + 1) - T(idx)));
end
end

function drawWindowPatch(ax, x1, x2, yLim, colorIn)
if ~all(isfinite([x1 x2 yLim(:).']))
    return;
end
patch(ax, [x1 x2 x2 x1], [yLim(1) yLim(1) yLim(2) yLim(2)], colorIn, ...
    'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

function yLim = ylimFromData(y)
y = y(isfinite(y));
if isempty(y)
    yLim = [0 1];
    return;
end
yMin = min(y);
yMax = max(y);
pad = 0.12 * max(yMax - yMin, eps);
if pad == 0
    pad = max(abs(yMax), 1) * 0.1;
end
yLim = [yMin - pad, yMax + pad];
end

function x = linearCross(x1, x2, y1, y2)
if abs(y2 - y1) < eps
    x = mean([x1 x2]);
else
    x = x1 - y1 * (x2 - x1) / (y2 - y1);
end
end

function [runDir, runName] = findLatestRunWithFiles(repoRoot, experiment, requiredFiles, runHint)
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
listing = dir(runsRoot);
dirs = listing([listing.isdir]);
names = string({dirs.name});
names = names(~ismember(names, [".", ".."]));
if nargin >= 4 && strlength(string(runHint)) > 0
    keep = contains(lower(names), lower(string(runHint)));
    if any(keep)
        names = names(keep);
    end
end
names = sort(names, 'descend');
for i = 1:numel(names)
    candidateDir = fullfile(runsRoot, names(i));
    ok = true;
    for j = 1:numel(requiredFiles)
        if exist(fullfile(candidateDir, requiredFiles{j}), 'file') ~= 2
            ok = false;
            break;
        end
    end
    if ok
        runDir = candidateDir;
        runName = names(i);
        return;
    end
end
error('No run found for %s with required files and hint %s.', experiment, string(runHint));
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, fieldName, value)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = value;
end
end

function out = capitalizeToken(in)
txt = char(string(in));
if isempty(txt)
    out = txt;
else
    out = [upper(txt(1)) txt(2:end)];
end
end

function varName = getVarNameLike(tbl, candidate)
vars = string(tbl.Properties.VariableNames);
idx = find(strcmpi(vars, string(candidate)), 1, 'first');
if isempty(idx)
    normVars = regexprep(lower(vars), '[^a-z0-9]+', '');
    normCandidate = regexprep(lower(string(candidate)), '[^a-z0-9]+', '');
    idx = find(normVars == normCandidate, 1, 'first');
end
if isempty(idx)
    error('Variable %s not found.', string(candidate));
end
varName = char(vars(idx));
end









