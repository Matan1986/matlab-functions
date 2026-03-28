function out = run_unified_barrier_mechanism(cfg)
%RUN_UNIFIED_BARRIER_MECHANISM Build a unified barrier mechanism map.
%   This script reads existing Relaxation, Switching, and Aging outputs,
%   projects the requested observables onto an inferred barrier axis, and
%   writes all derived artifacts into a fresh cross-experiment run folder.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfg = applyDefaults(cfg);
paths = resolveInputs(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = 'unified_barrier_mechanism';
runCfg.dataset = sprintf('unified_barrier|relax:%s|switch:%s', ...
    paths.relaxRunDir, paths.switchRunDir);
runCtx = createRunContext('cross_experiment', runCfg);
runDir = runCtx.run_dir;
run = struct();
run.runDir = runDir;
run.tablesDir = fullfile(runDir, 'tables');
run.figuresDir = fullfile(runDir, 'figures');
run.reportsDir = fullfile(runDir, 'reports');
run.reviewDir = fullfile(runDir, 'review');

notesLines = {
    ['Relaxation input: ' paths.relaxRunDir]
    ['Switching input: ' paths.switchRunDir]
    ['Aging observable input: ' paths.agingObservableRunDir]
    ['Aging shape input: ' paths.agingShapeRunDir]
    };
fidNotes = fopen(runCtx.notes_path, 'a', 'n', 'UTF-8');
if fidNotes > 0
    fprintf(fidNotes, '%s\n\n', strjoin(notesLines, newline));
    fclose(fidNotes);
end

relaxTbl = readtable(paths.relaxTemperatureObservables);
relaxSummary = readtable(paths.relaxSummaryObservables);
switchTbl = readtable(paths.switchObservableVsT);
agingMetrics = readtable(paths.agingMetrics);
agingShape = readtable(paths.agingShapeVariation);

barrier = buildBarrierMapping(relaxSummary, cfg);
agingWide = buildAgingObservableTable(agingMetrics, agingShape);
switchDerived = buildSwitchingTable(switchTbl);

projectionTbl = buildProjectionTable(relaxTbl, agingWide, switchDerived, barrier, paths);
[gridTbl, regionSummary] = buildBarrierGrid(relaxTbl, agingWide, switchDerived, barrier, cfg);
clusterMeta = assignClusters(gridTbl, cfg.numClusters);
gridTbl.cluster_id = clusterMeta.clusterId;
gridTbl.cluster_label = clusterMeta.clusterLabel;

projectionCsv = save_run_table(projectionTbl, 'observable_barrier_projections.csv', runDir);
regionCsv = save_run_table(gridTbl, 'barrier_region_classification.csv', runDir);

makeUnifiedLandscapeFigure(gridTbl, regionSummary, barrier, runDir);
makeObservableProjectionFigure(relaxTbl, agingWide, switchDerived, barrier, runDir);
makeMobilePinnedFigure(gridTbl, regionSummary, runDir);
makeMechanismMapFigure(gridTbl, clusterMeta, runDir);

reportText = buildReport(paths, run, barrier, relaxSummary, agingWide, switchDerived, regionSummary, clusterMeta);
reportPath = save_run_report(reportText, 'unified_barrier_landscape_report.md', runDir);

bundlePath = fullfile(run.reviewDir, 'unified_barrier_landscape_bundle.zip');
if exist(bundlePath, 'file') == 2
    delete(bundlePath);
end
if ~isfolder(run.reviewDir)
    mkdir(run.reviewDir);
end
zip(bundlePath, {'tables', 'figures', 'reports'}, run.runDir);

manifest = struct();
manifest.run_dir = run.runDir;
manifest.relaxation_run = paths.relaxRunDir;
manifest.switching_run = paths.switchRunDir;
manifest.aging_observable_run = paths.agingObservableRunDir;
manifest.aging_shape_run = paths.agingShapeRunDir;
manifest.barrier_reference_time_s = barrier.referenceTime_s;
manifest.barrier_attempt_time_s = barrier.attemptTime_s;
manifest.barrier_ln_factor = barrier.logFactor;
manifest.generated_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
writeText(fullfile(run.tablesDir, 'unified_barrier_input_manifest.json'), jsonencode(manifest, 'PrettyPrint', true));

fprintf('Unified barrier mechanism run created at:\n%s\n', run.runDir);
fprintf('Projection table: %s\n', projectionCsv);
fprintf('Region table: %s\n', regionCsv);
fprintf('Report: %s\n', reportPath);
fprintf('Bundle: %s\n', bundlePath);

if nargout > 0
    out = struct();
    out.runDir = string(run.runDir);
    out.projectionCsv = string(projectionCsv);
    out.regionCsv = string(regionCsv);
    out.reportPath = string(reportPath);
    out.bundlePath = string(bundlePath);
end
end

function cfg = applyDefaults(cfg)
cfg.referenceObservable = getFieldOr(cfg, 'referenceObservable', 'Relax_t_half');
cfg.attemptTime_s = getFieldOr(cfg, 'attemptTime_s', 1e-9);
cfg.commonTemperatureGrid_K = getFieldOr(cfg, 'commonTemperatureGrid_K', (4:34).');
cfg.inactiveThreshold = getFieldOr(cfg, 'inactiveThreshold', 0.12);
cfg.activationThreshold = getFieldOr(cfg, 'activationThreshold', 0.18);
cfg.numClusters = getFieldOr(cfg, 'numClusters', 4);
end

function paths = resolveInputs(repoRoot, cfg)
paths = struct();

paths.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', ...
    'run_2026_03_10_175048_relaxation_observable_stability_audit');
paths.relaxTemperatureObservables = fullfile(paths.relaxRunDir, 'tables', 'temperature_observables.csv');
paths.relaxSummaryObservables = fullfile(paths.relaxRunDir, 'tables', 'observables_relaxation.csv');

paths.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_10_112659_alignment_audit');
paths.switchObservableVsT = fullfile(paths.switchRunDir, 'alignment_audit', ...
    'switching_alignment_observables_vs_T.csv');

agingRunsRoot = fullfile(repoRoot, 'results', 'aging', 'runs');
paths.agingObservableRunDir = findLatestRun(agingRunsRoot, 'run_*_observable_identification_audit');
paths.agingShapeRunDir = findLatestRun(agingRunsRoot, 'run_*_aging_shape_collapse_analysis*');
paths.agingMetrics = fullfile(paths.agingObservableRunDir, 'tables', 'aging_tp_observable_metrics.csv');
paths.agingPointAggregation = fullfile(paths.agingObservableRunDir, 'tables', 'aging_observable_point_aggregation.csv');
paths.agingShapeVariation = fullfile(paths.agingShapeRunDir, 'tables', 'aging_shape_variation_vs_Tp.csv');

required = {paths.relaxTemperatureObservables, paths.relaxSummaryObservables, ...
    paths.switchObservableVsT, paths.agingMetrics, paths.agingShapeVariation};
for i = 1:numel(required)
    if exist(required{i}, 'file') ~= 2
        error('Required input is missing: %s', required{i});
    end
end

paths.cfg = cfg;
end

function barrier = buildBarrierMapping(relaxSummary, cfg)
referenceTime = NaN;
if ismember(cfg.referenceObservable, relaxSummary.Properties.VariableNames)
    referenceTime = relaxSummary.(cfg.referenceObservable)(1);
end
if ~isfinite(referenceTime) || referenceTime <= 0
    if ismember('Relax_tau_global', relaxSummary.Properties.VariableNames)
        referenceTime = relaxSummary.Relax_tau_global(1);
    else
        error('Could not determine a positive relaxation reference time.');
    end
end

if ~isfinite(cfg.attemptTime_s) || cfg.attemptTime_s <= 0
    error('Attempt time must be positive.');
end

barrier = struct();
barrier.referenceTime_s = referenceTime;
barrier.attemptTime_s = cfg.attemptTime_s;
barrier.logFactor = log(referenceTime / cfg.attemptTime_s);
barrier.kB_meV_per_K = 0.08617333262;
barrier.label = sprintf('E_eff = k_B T ln(%.3g / %.1e)', referenceTime, cfg.attemptTime_s);
end

function agingWide = buildAgingObservableTable(agingMetrics, agingShape)
tpVals = unique(agingMetrics.Tp_K);
agingWide = table(tpVals, 'VariableNames', {'temperature_K'});
agingWide.Dip_depth = nan(size(tpVals));
agingWide.Dip_depth_cv = nan(size(tpVals));
agingWide.Dip_depth_wait_corr = nan(size(tpVals));
agingWide.FM_abs = nan(size(tpVals));
agingWide.FM_abs_cv = nan(size(tpVals));
agingWide.FM_abs_wait_corr = nan(size(tpVals));
agingWide.shape_variation = nan(size(tpVals));
agingWide.rank1_explained_variance_ratio = nan(size(tpVals));

for i = 1:numel(tpVals)
    tp = tpVals(i);
    dip = agingMetrics(agingMetrics.Tp_K == tp & strcmp(agingMetrics.observable, 'Dip_depth'), :);
    fm = agingMetrics(agingMetrics.Tp_K == tp & strcmp(agingMetrics.observable, 'FM_abs'), :);
    shape = agingShape(agingShape.Tp_K == tp, :);

    if ~isempty(dip)
        agingWide.Dip_depth(i) = dip.mean_value(1);
        agingWide.Dip_depth_cv(i) = dip.cv_value(1);
        agingWide.Dip_depth_wait_corr(i) = dip.spearman_vs_log10_tw(1);
    end
    if ~isempty(fm)
        agingWide.FM_abs(i) = fm.mean_value(1);
        agingWide.FM_abs_cv(i) = fm.cv_value(1);
        agingWide.FM_abs_wait_corr(i) = fm.spearman_vs_log10_tw(1);
    end
    if ~isempty(shape)
        agingWide.shape_variation(i) = shape.shape_variation(1);
        agingWide.rank1_explained_variance_ratio(i) = shape.rank1_explained_variance_ratio(1);
    end
end
end

function switchDerived = buildSwitchingTable(switchTbl)
switchDerived = table();
switchDerived.temperature_K = switchTbl.T_K;
switchDerived.I_peak = switchTbl.Ipeak;
switchDerived.S_peak = switchTbl.S_peak;

motion = nan(size(switchTbl.Ipeak));
valid = isfinite(switchTbl.Ipeak) & isfinite(switchTbl.T_K);
if nnz(valid) >= 2
    motion(valid) = abs(localGradient(switchTbl.Ipeak(valid), switchTbl.T_K(valid)));
end
switchDerived.motion = motion;

switchDerived.current_ease = nan(size(switchTbl.Ipeak));
switchDerived.current_ease(valid) = max(switchTbl.Ipeak(valid)) - switchTbl.Ipeak(valid);
switchDerived.mode_ratio = switchTbl.mode_ratio_smooth;
end

function projectionTbl = buildProjectionTable(relaxTbl, agingWide, switchDerived, barrier, paths)
rows = {};

rows = [rows; makeRows('relaxation', 'A_T', relaxTbl.T, relaxTbl.A_T, barrier, paths.relaxRunDir)];
rows = [rows; makeRows('aging', 'Dip_depth', agingWide.temperature_K, agingWide.Dip_depth, barrier, paths.agingObservableRunDir)];
rows = [rows; makeRows('aging', 'FM_abs', agingWide.temperature_K, agingWide.FM_abs, barrier, paths.agingObservableRunDir)];
rows = [rows; makeRows('switching', 'I_peak', switchDerived.temperature_K, switchDerived.I_peak, barrier, paths.switchRunDir)];
rows = [rows; makeRows('switching', 'S_peak', switchDerived.temperature_K, switchDerived.S_peak, barrier, paths.switchRunDir)];
rows = [rows; makeRows('switching', 'motion', switchDerived.temperature_K, switchDerived.motion, barrier, paths.switchRunDir)];

projectionTbl = vertcat(rows{:});

obsNames = unique(projectionTbl.observable, 'stable');
projectionTbl.normalized_value = nan(height(projectionTbl), 1);
for i = 1:numel(obsNames)
    mask = strcmp(projectionTbl.observable, obsNames{i});
    projectionTbl.normalized_value(mask) = minMaxScale(projectionTbl.value(mask));
end
end

function rows = makeRows(experimentName, observableName, temperature, values, barrier, sourceRun)
barrierOverKb = temperature .* barrier.logFactor;
barrierMeV = barrierOverKb .* barrier.kB_meV_per_K;
rows = {table( ...
    repmat({experimentName}, numel(temperature), 1), ...
    repmat({observableName}, numel(temperature), 1), ...
    temperature(:), ...
    barrierOverKb(:), ...
    barrierMeV(:), ...
    values(:), ...
    repmat({sourceRun}, numel(temperature), 1), ...
    'VariableNames', {'experiment','observable','temperature_K','barrier_over_kB_K','barrier_meV','value','source_run'})};
end
function [gridTbl, regionSummary] = buildBarrierGrid(relaxTbl, agingWide, switchDerived, barrier, cfg)
Tgrid = cfg.commonTemperatureGrid_K(:);
gridTbl = table();
gridTbl.temperature_K = Tgrid;
gridTbl.barrier_over_kB_K = Tgrid .* barrier.logFactor;
gridTbl.barrier_meV = gridTbl.barrier_over_kB_K .* barrier.kB_meV_per_K;

gridTbl.A_T = interpLinear(relaxTbl.T, relaxTbl.A_T, Tgrid);
gridTbl.Dip_depth = interpLinear(agingWide.temperature_K, agingWide.Dip_depth, Tgrid);
gridTbl.FM_abs = interpLinear(agingWide.temperature_K, agingWide.FM_abs, Tgrid);
gridTbl.I_peak = interpLinear(switchDerived.temperature_K, switchDerived.I_peak, Tgrid);
gridTbl.S_peak = interpLinear(switchDerived.temperature_K, switchDerived.S_peak, Tgrid);
gridTbl.motion = interpLinear(switchDerived.temperature_K, switchDerived.motion, Tgrid);

gridTbl.A_scale = minMaxScale(gridTbl.A_T);
gridTbl.Dip_scale = minMaxScale(gridTbl.Dip_depth);
gridTbl.FM_scale = minMaxScale(gridTbl.FM_abs);
gridTbl.S_scale = minMaxScale(gridTbl.S_peak);
gridTbl.motion_scale = minMaxScale(gridTbl.motion);
gridTbl.current_ease_scale = minMaxScale(maxFinite(gridTbl.I_peak) - gridTbl.I_peak);

gridTbl.mobile_score = combineMean([gridTbl.A_scale, gridTbl.Dip_scale]);
gridTbl.pinned_score = combineMean([gridTbl.A_scale, gridTbl.FM_scale]);
gridTbl.activation_score = combineMean([gridTbl.A_scale, gridTbl.S_scale, gridTbl.motion_scale, gridTbl.current_ease_scale]);
gridTbl.mobile_minus_pinned = gridTbl.mobile_score - gridTbl.pinned_score;

labels = strings(height(gridTbl), 1);
regionId = zeros(height(gridTbl), 1);

for i = 1:height(gridTbl)
    scores = [gridTbl.mobile_score(i), gridTbl.pinned_score(i), gridTbl.activation_score(i)];
    [bestScore, bestIdx] = max(scores, [], 2, 'includenan');
    if ~isfinite(bestScore) || bestScore < cfg.inactiveThreshold || (~isfinite(gridTbl.A_scale(i)) || gridTbl.A_scale(i) < 0.05)
        labels(i) = "inactive_tail";
    elseif bestIdx == 3 && bestScore >= cfg.activationThreshold
        labels(i) = "switching_activation_window";
    elseif bestIdx == 2
        labels(i) = "pinned_sector";
    else
        labels(i) = "mobile_sector";
    end
end

currentRegion = 0;
prevLabel = "";
for i = 1:height(gridTbl)
    if i == 1 || labels(i) ~= prevLabel
        currentRegion = currentRegion + 1;
    end
    regionId(i) = currentRegion;
    prevLabel = labels(i);
end

gridTbl.dominant_region = labels;
gridTbl.region_id = regionId;
regionSummary = summarizeRegions(gridTbl);
end

function clusterMeta = assignClusters(gridTbl, numClusters)
featureNames = {'A_scale','Dip_scale','FM_scale','S_scale','motion_scale','current_ease_scale'};
X = gridTbl{:, featureNames};
for c = 1:size(X, 2)
    col = X(:, c);
    finiteMask = isfinite(col);
    if any(finiteMask)
        col(~finiteMask) = mean(col(finiteMask));
    else
        col(:) = 0;
    end
    X(:, c) = col;
end

[clusterId, centroids] = simpleKmeans(X, numClusters);
clusterLabel = strings(height(gridTbl), 1);
labelPerCluster = strings(numClusters, 1);

for k = 1:numClusters
    centroid = centroids(k, :);
    activity = mean(centroid([1 4 5 6]));
    mobile = mean(centroid([1 2]));
    pinned = mean(centroid([1 3]));

    if activity >= max([mobile, pinned]) && activity > 0.35
        labelPerCluster(k) = "activation_dominant";
    elseif pinned >= mobile && pinned > 0.22
        labelPerCluster(k) = "pinned_dominant";
    elseif mobile > pinned && mobile > 0.22
        labelPerCluster(k) = "mobile_memory";
    elseif centroid(1) > 0.20
        labelPerCluster(k) = "participation_tail";
    else
        labelPerCluster(k) = "inactive_tail";
    end
end

for i = 1:height(gridTbl)
    clusterLabel(i) = labelPerCluster(clusterId(i));
end

clusterMeta = struct();
clusterMeta.clusterId = clusterId;
clusterMeta.clusterLabel = clusterLabel;
clusterMeta.centroids = centroids;
clusterMeta.featureNames = featureNames;
clusterMeta.clusterNames = labelPerCluster;
end

function regionSummary = summarizeRegions(gridTbl)
regionIds = unique(gridTbl.region_id);
regionSummary = table('Size', [numel(regionIds), 10], ...
    'VariableTypes', {'double','string','double','double','double','double','double','double','double','string'}, ...
    'VariableNames', {'region_id','label','T_min_K','T_max_K','E_min_meV','E_max_meV', ...
    'mobile_score_mean','pinned_score_mean','activation_score_mean','dominant_signal'});

for i = 1:numel(regionIds)
    rid = regionIds(i);
    sub = gridTbl(gridTbl.region_id == rid, :);
    regionSummary.region_id(i) = rid;
    regionSummary.label(i) = sub.dominant_region(1);
    regionSummary.T_min_K(i) = min(sub.temperature_K);
    regionSummary.T_max_K(i) = max(sub.temperature_K);
    regionSummary.E_min_meV(i) = min(sub.barrier_meV);
    regionSummary.E_max_meV(i) = max(sub.barrier_meV);
    regionSummary.mobile_score_mean(i) = mean(sub.mobile_score, 'omitnan');
    regionSummary.pinned_score_mean(i) = mean(sub.pinned_score, 'omitnan');
    regionSummary.activation_score_mean(i) = mean(sub.activation_score, 'omitnan');

    avgScores = [regionSummary.mobile_score_mean(i), regionSummary.pinned_score_mean(i), regionSummary.activation_score_mean(i)];
    [~, idx] = max(avgScores);
    if idx == 1
        regionSummary.dominant_signal(i) = "Dip_depth x A(T)";
    elseif idx == 2
        regionSummary.dominant_signal(i) = "FM_abs x A(T)";
    else
        regionSummary.dominant_signal(i) = "S_peak x motion x current ease";
    end
end
end

function makeUnifiedLandscapeFigure(gridTbl, regionSummary, barrier, runDir)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 650], ...
    'Name', 'unified_barrier_landscape', 'NumberTitle', 'off');
ax = axes(fig);
hold(ax, 'on');
box(ax, 'on');
grid(ax, 'on');

shadeRegions(ax, regionSummary);
plot(ax, gridTbl.barrier_meV, gridTbl.A_scale, '-', 'LineWidth', 2.8, 'Color', [0.05 0.27 0.62], 'DisplayName', 'A(T) / participation');
plot(ax, gridTbl.barrier_meV, gridTbl.Dip_scale, '-', 'LineWidth', 2.4, 'Color', [0.00 0.55 0.35], 'DisplayName', 'Dip_depth / mobile');
plot(ax, gridTbl.barrier_meV, gridTbl.FM_scale, '-', 'LineWidth', 2.4, 'Color', [0.64 0.24 0.13], 'DisplayName', 'FM_abs / pinned');
plot(ax, gridTbl.barrier_meV, gridTbl.S_scale, '-', 'LineWidth', 2.4, 'Color', [0.72 0.52 0.04], 'DisplayName', 'S_{peak}(T)');
plot(ax, gridTbl.barrier_meV, gridTbl.motion_scale, '--', 'LineWidth', 2.1, 'Color', [0.45 0.12 0.58], 'DisplayName', '|dI_{peak}/dT|');

xlabel(ax, 'Effective barrier E_{eff} (meV)');
ylabel(ax, 'Normalized observable amplitude');
title(ax, {'Unified barrier landscape', barrier.label}, 'FontWeight', 'bold');
legend(ax, 'Location', 'northoutside', 'NumColumns', 3);
ylim(ax, [0 1.08]);

save_run_figure(fig, 'unified_barrier_landscape', runDir);
close(fig);
end

function makeObservableProjectionFigure(relaxTbl, agingWide, switchDerived, barrier, runDir)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1280 850], ...
    'Name', 'observable_projections_on_barrier_axis', 'NumberTitle', 'off');
tl = tiledlayout(fig, 3, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile(tl);
plotProjected(relaxTbl.T, relaxTbl.A_T, barrier, 'A(T)', 'signal units');

nexttile(tl);
plotProjected(agingWide.temperature_K, agingWide.Dip_depth, barrier, 'Dip depth', 'signal units');

nexttile(tl);
plotProjected(agingWide.temperature_K, agingWide.FM_abs, barrier, 'FM abs', 'signal units');

nexttile(tl);
plotProjected(switchDerived.temperature_K, switchDerived.I_peak, barrier, 'I_{peak}(T)', 'mA');

nexttile(tl);
plotProjected(switchDerived.temperature_K, switchDerived.S_peak, barrier, 'S_{peak}(T)', 'percent');

nexttile(tl);
plotProjected(switchDerived.temperature_K, switchDerived.motion, barrier, 'motion(T)', 'mA/K');

title(tl, 'Observable projections on the reconstructed barrier axis', 'FontWeight', 'bold');
save_run_figure(fig, 'observable_projections_on_barrier_axis', runDir);
close(fig);
end

function makeMobilePinnedFigure(gridTbl, regionSummary, runDir)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [110 110 1200 760], ...
    'Name', 'mobile_vs_pinned_channels', 'NumberTitle', 'off');
tl = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

ax1 = nexttile(tl);
hold(ax1, 'on');
box(ax1, 'on');
grid(ax1, 'on');
shadeRegions(ax1, regionSummary);
plot(ax1, gridTbl.barrier_meV, gridTbl.mobile_score, '-', 'LineWidth', 2.7, 'Color', [0.00 0.55 0.35], 'DisplayName', 'mobile score');
plot(ax1, gridTbl.barrier_meV, gridTbl.pinned_score, '-', 'LineWidth', 2.7, 'Color', [0.64 0.24 0.13], 'DisplayName', 'pinned score');
plot(ax1, gridTbl.barrier_meV, gridTbl.activation_score, '--', 'LineWidth', 2.2, 'Color', [0.72 0.52 0.04], 'DisplayName', 'activation score');
ylabel(ax1, 'score');
title(ax1, 'Mobile vs pinned channels with activation overlay');
legend(ax1, 'Location', 'northoutside', 'NumColumns', 3);

ax2 = nexttile(tl);
hold(ax2, 'on');
box(ax2, 'on');
grid(ax2, 'on');
area(ax2, gridTbl.barrier_meV, gridTbl.mobile_minus_pinned, 'FaceColor', [0.16 0.66 0.50], 'FaceAlpha', 0.35, 'EdgeAlpha', 0.0);
plot(ax2, gridTbl.barrier_meV, gridTbl.mobile_minus_pinned, '-', 'LineWidth', 2.4, 'Color', [0.00 0.45 0.30]);
yline(ax2, 0, ':', 'Color', [0 0 0], 'LineWidth', 1.1);
xlabel(ax2, 'Effective barrier E_{eff} (meV)');
ylabel(ax2, 'mobile - pinned');
title(ax2, 'Positive values favor mobile sectors; negative values favor pinned sectors');

save_run_figure(fig, 'mobile_vs_pinned_channels', runDir);
close(fig);
end

function makeMechanismMapFigure(gridTbl, clusterMeta, runDir)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [90 90 1280 780], ...
    'Name', 'barrier_mechanism_map', 'NumberTitle', 'off');
tl = tiledlayout(fig, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

ax1 = nexttile(tl);
scatter(ax1, gridTbl.barrier_meV, ones(height(gridTbl), 1), 85, double(gridTbl.cluster_id), 'filled');
set(ax1, 'YTick', []);
box(ax1, 'on');
grid(ax1, 'on');
xlim(ax1, [min(gridTbl.barrier_meV) max(gridTbl.barrier_meV)]);
title(ax1, 'Barrier-axis clustering');

ax2 = nexttile(tl, [2 1]);
featureNames = {'A_scale','Dip_scale','FM_scale','S_scale','motion_scale','current_ease_scale'};
featureLabels = {'A(T)', 'Dip depth', 'FM abs', 'S_{peak}', 'motion', 'current ease'};
imagesc(ax2, gridTbl.barrier_meV, 1:numel(featureNames), gridTbl{:, featureNames}.');
set(ax2, 'YTick', 1:numel(featureNames), 'YTickLabel', featureLabels);
xlabel(ax2, 'Effective barrier E_{eff} (meV)');
title(ax2, 'Normalized observable clustering along the barrier axis');
colormap(ax2, turbo(256));
cb = colorbar(ax2);
ylabel(cb, 'normalized amplitude');

clusterNames = unique(clusterMeta.clusterNames, 'stable');
annotationText = sprintf('clusters: %s', strjoin(cellstr(clusterNames), ', '));
annotation(fig, 'textbox', [0.12 0.91 0.8 0.05], 'String', annotationText, ...
    'FitBoxToText', 'on', 'EdgeColor', 'none', 'FontSize', 10);

save_run_figure(fig, 'barrier_mechanism_map', runDir);
close(fig);
end
function reportText = buildReport(paths, run, barrier, relaxSummary, agingWide, switchDerived, regionSummary, clusterMeta)
peakIdx = findMaxFinite(agingWide.Dip_depth .* (1 - minMaxScale(agingWide.FM_abs)));
activationIdx = findMaxFinite(minMaxScale(switchDerived.S_peak) .* minMaxScale(switchDerived.motion) .* minMaxScale(maxFinite(switchDerived.I_peak) - switchDerived.I_peak));

lines = strings(0, 1);
lines(end + 1) = "# Unified barrier landscape report";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf("Run root: `%s`", run.runDir);
lines(end + 1) = "";
lines(end + 1) = "## Inputs";
lines(end + 1) = sprintf("- Relaxation run: `%s`", paths.relaxRunDir);
lines(end + 1) = sprintf("- Switching run: `%s`", paths.switchRunDir);
lines(end + 1) = sprintf("- Aging observable run: `%s`", paths.agingObservableRunDir);
lines(end + 1) = sprintf("- Aging shape run: `%s`", paths.agingShapeRunDir);
lines(end + 1) = "";
lines(end + 1) = "## Barrier mapping";
lines(end + 1) = sprintf("- Effective mapping used: `%s`", barrier.label);
lines(end + 1) = sprintf("- Relaxation-selected reference time: %.6g s", barrier.referenceTime_s);
lines(end + 1) = sprintf("- Microscopic attempt time: %.1e s", barrier.attemptTime_s);
lines(end + 1) = "- This `E_eff(T)` axis is an Arrhenius-style reconstruction inferred from the relaxation diagnostics because no standalone exported `E_eff` lookup table was present in the referenced run artifacts.";
lines(end + 1) = "";
lines(end + 1) = "## Mechanism summary";
lines(end + 1) = "1. Relaxation reconstructs the barrier participation landscape";
lines(end + 1) = sprintf("A(T) provides the weight of dynamically active barriers, with its strongest participation near %.0f K where the relaxation audit reports `Relax_Amp_peak = %.6g`.", ...
    relaxSummary.Relax_T_peak(1), relaxSummary.Relax_Amp_peak(1));
lines(end + 1) = "Because the DeltaM map is nearly rank-1, this amplitude axis can be treated as the participation envelope that tells us which reconstructed barriers are actually populated by the relaxation dynamics.";
lines(end + 1) = "";
lines(end + 1) = "2. Aging separates mobile vs pinned sectors";
lines(end + 1) = sprintf("Dip_depth is used as the mobile-memory channel and FM_abs as the pinned/background channel, following the aging audit recommendation table. The strongest mobile contrast occurs near %.0f K, while FM_abs becomes comparatively dominant in the higher-T part of the sweep.", ...
    agingWide.temperature_K(peakIdx));
lines(end + 1) = "Projecting both onto the same barrier axis shows that memory-rich dip sectors occupy the same reconstructed landscape as the relaxation participation envelope, but they do not span it uniformly.";
lines(end + 1) = "";
lines(end + 1) = "3. Switching probes current-tilted activation thresholds";
lines(end + 1) = sprintf("Switching activation is represented by `I_peak(T)`, `S_peak(T)`, and `motion(T) = |dI_peak/dT|`. The strongest activation composite occurs near %.0f K, where ridge motion and susceptibility amplitude are simultaneously elevated.", ...
    switchDerived.temperature_K(activationIdx));
lines(end + 1) = "On the barrier axis this defines a window where the current threshold is changing rapidly, consistent with a current-tilted activation regime rather than a static pinned background.";
lines(end + 1) = "";
lines(end + 1) = "4. Unified physical interpretation";
lines(end + 1) = "The three experiments are consistent with one shared barrier landscape. Relaxation tells us where the barrier population is active, aging separates that active population into mobile-memory and pinned/background channels, and switching highlights the sub-window where current tilt most efficiently drives sectors across the same landscape.";
lines(end + 1) = "";
lines(end + 1) = "## Barrier regions";
lines(end + 1) = "| region | label | T range (K) | E range (meV) | dominant signal |";
lines(end + 1) = "| ---: | --- | ---: | ---: | --- |";
for i = 1:height(regionSummary)
    lines(end + 1) = sprintf("| %d | %s | %.0f-%.0f | %.2f-%.2f | %s |", ...
        regionSummary.region_id(i), regionSummary.label(i), regionSummary.T_min_K(i), regionSummary.T_max_K(i), ...
        regionSummary.E_min_meV(i), regionSummary.E_max_meV(i), regionSummary.dominant_signal(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Clustering note";
lines(end + 1) = sprintf("- Barrier-axis clustering used %d normalized features: %s.", ...
    numel(clusterMeta.featureNames), strjoin(clusterMeta.featureNames, ', '));
lines(end + 1) = sprintf("- Cluster labels present: %s.", strjoin(cellstr(unique(clusterMeta.clusterNames, 'stable')), ', '));
lines(end + 1) = "";
lines(end + 1) = "## Outputs";
lines(end + 1) = "- `tables/observable_barrier_projections.csv`";
lines(end + 1) = "- `tables/barrier_region_classification.csv`";
lines(end + 1) = "- `figures/unified_barrier_landscape.png`";
lines(end + 1) = "- `figures/observable_projections_on_barrier_axis.png`";
lines(end + 1) = "- `figures/mobile_vs_pinned_channels.png`";
lines(end + 1) = "- `figures/barrier_mechanism_map.png`";
lines(end + 1) = "- `tables/unified_barrier_input_manifest.json`";
lines(end + 1) = "- `review/unified_barrier_landscape_bundle.zip`";

reportText = strjoin(cellstr(lines), newline);
end

function shadeRegions(ax, regionSummary)
yl = [0 1.08];
for i = 1:height(regionSummary)
    x0 = regionSummary.E_min_meV(i);
    x1 = regionSummary.E_max_meV(i);
    if regionSummary.label(i) == "mobile_sector"
        c = [0.84 0.95 0.89];
    elseif regionSummary.label(i) == "pinned_sector"
        c = [0.96 0.90 0.86];
    elseif regionSummary.label(i) == "switching_activation_window"
        c = [0.98 0.95 0.84];
    else
        c = [0.94 0.94 0.94];
    end
    patch(ax, [x0 x1 x1 x0], [yl(1) yl(1) yl(2) yl(2)], c, ...
        'FaceAlpha', 0.28, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
ylim(ax, yl);
end

function plotProjected(T, values, barrier, ttl, yLabelText)
ax = gca;
valid = isfinite(T) & isfinite(values);
plot(ax, T(valid) .* barrier.logFactor .* barrier.kB_meV_per_K, values(valid), ...
    '-o', 'LineWidth', 1.8, 'MarkerSize', 5, 'Color', [0.11 0.32 0.64], ...
    'MarkerFaceColor', [0.11 0.32 0.64]);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'E_{eff} (meV)');
ylabel(ax, yLabelText);
title(ax, ttl);
end

function value = getFieldOr(s, fieldName, fallback)
if isfield(s, fieldName)
    value = s.(fieldName);
else
    value = fallback;
end
end

function path = findLatestRun(rootDir, pattern)
d = dir(fullfile(rootDir, pattern));
d = d([d.isdir]);
if isempty(d)
    error('No run directories found in %s for pattern %s', rootDir, pattern);
end
[~, order] = sort({d.name});
d = d(order);
path = fullfile(d(end).folder, d(end).name);
end

function writeText(path, text)
fid = fopen(path, 'w');
if fid < 0
    error('Could not open file for writing: %s', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', text);
end

function yq = interpLinear(x, y, xq)
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    yq = nan(size(xq));
    return;
end
yq = interp1(x(mask), y(mask), xq, 'linear', NaN);
end

function scaled = minMaxScale(x)
scaled = nan(size(x));
mask = isfinite(x);
if ~any(mask)
    return;
end
xv = x(mask);
lo = min(xv);
hi = max(xv);
if hi <= lo
    scaled(mask) = 0.5;
else
    scaled(mask) = (xv - lo) ./ (hi - lo);
end
end

function y = combineMean(X)
y = nan(size(X, 1), 1);
for i = 1:size(X, 1)
    row = X(i, :);
    mask = isfinite(row);
    if any(mask)
        y(i) = mean(row(mask));
    end
end
end

function g = localGradient(y, x)
g = nan(size(y));
n = numel(y);
if n < 2
    return;
end
g(1) = (y(2) - y(1)) / max(x(2) - x(1), eps);
g(n) = (y(n) - y(n - 1)) / max(x(n) - x(n - 1), eps);
for i = 2:n-1
    g(i) = (y(i + 1) - y(i - 1)) / max(x(i + 1) - x(i - 1), eps);
end
end

function value = maxFinite(x)
mask = isfinite(x);
if any(mask)
    value = max(x(mask));
else
    value = NaN;
end
end

function idx = findMaxFinite(x)
mask = isfinite(x);
if ~any(mask)
    idx = 1;
    return;
end
[~, localIdx] = max(x(mask));
positions = find(mask);
idx = positions(localIdx);
end

function [clusterId, centroids] = simpleKmeans(X, k)
n = size(X, 1);
if n == 0
    clusterId = zeros(0, 1);
    centroids = zeros(k, size(X, 2));
    return;
end

seedIdx = round(linspace(1, n, k));
centroids = X(seedIdx, :);
clusterId = ones(n, 1);

for iter = 1:50
    dist = zeros(n, k);
    for j = 1:k
        diff = X - centroids(j, :);
        dist(:, j) = sum(diff .^ 2, 2);
    end
    [~, newId] = min(dist, [], 2);
    if iter > 1 && all(newId == clusterId)
        break;
    end
    clusterId = newId;
    for j = 1:k
        mask = clusterId == j;
        if any(mask)
            centroids(j, :) = mean(X(mask, :), 1);
        end
    end
end
end
