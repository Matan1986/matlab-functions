function out = relaxation_aging_canonical_comparison(cfg)
% relaxation_aging_canonical_comparison
% Canonical run-scoped Relaxation <-> Aging observable comparison using
% existing saved run artifacts only.

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
runCfg.dataset = sprintf('relax:%s | aging:%s | collapse:%s', ...
    char(source.relaxRunName), char(source.agingObservableRunName), char(source.agingCollapseRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = getRunOutputDir();

fprintf('Relaxation-aging comparison run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Aging observable source run: %s\n', source.agingObservableRunName);
fprintf('Aging audit source run: %s\n', source.agingAuditRunName);
fprintf('Aging collapse source run: %s\n', source.agingCollapseRunName);

appendText(run.log_path, sprintf('[%s] relaxation-aging canonical comparison started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Aging observable source: %s\n', char(source.agingObservableRunName)));
appendText(run.log_path, sprintf('Aging audit source: %s\n', char(source.agingAuditRunName)));
appendText(run.log_path, sprintf('Aging collapse source: %s\n', char(source.agingCollapseRunName)));

relax = loadRelaxationSource(source.relaxRunDir);
aging = loadAgingSources(source);
comparison = buildComparison(source, relax, aging, cfg);

alignmentPath = save_run_table(comparison.alignmentTable, 'relaxation_aging_observable_alignment.csv', runDir);
metricsPath = save_run_table(comparison.metricsTable, 'normalized_overlay_metrics.csv', runDir);
windowPath = save_run_table(comparison.windowTable, 'peak_window_summary.csv', runDir);
manifestPath = save_run_table(comparison.sourceManifestTable, 'source_run_manifest.csv', runDir);

figDip = savePairFigure(relax, comparison.observableMap.Dip_depth, comparison.relaxWindow, comparison.commonTemperatureGrid, runDir, ...
    'A_vs_Dip_depth_overlay', 'Relaxation A(T) vs Aging Dip depth', 'Dip depth (arb.)');
figFM = savePairFigure(relax, comparison.observableMap.FM_abs, comparison.relaxWindow, comparison.commonTemperatureGrid, runDir, ...
    'A_vs_FM_abs_overlay', 'Relaxation A(T) vs Aging FM amplitude', 'FM abs (arb.)');
figCoeff = savePairFigure(relax, comparison.observableMap.coeff_mode1, comparison.relaxWindow, comparison.commonTemperatureGrid, runDir, ...
    'A_vs_coeff_mode1_overlay', 'Relaxation A(T) vs Aging coeff mode 1', 'coeff mode 1 (oriented arb.)');
figMulti = saveNormalizedMultiOverlayFigure(comparison, runDir, 'normalized_multi_overlay');
figPeak = savePeakSummaryFigure(comparison, runDir, 'peak_alignment_summary');
figWindow = saveWindowOverlapFigure(comparison, runDir, 'temperature_window_overlap');

reportText = buildReport(thisFile, source, relax, aging, comparison);
reportPath = save_run_report(reportText, 'relaxation_aging_canonical_comparison.md', runDir);
zipPath = buildReviewZip(runDir, 'relaxation_aging_canonical_comparison_bundle.zip');

appendText(run.log_path, sprintf('[%s] relaxation-aging canonical comparison complete\n', stampNow()));
appendText(run.log_path, sprintf('Alignment table: %s\n', alignmentPath));
appendText(run.log_path, sprintf('Metrics table: %s\n', metricsPath));
appendText(run.log_path, sprintf('Peak/window table: %s\n', windowPath));
appendText(run.log_path, sprintf('Source manifest table: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));
appendText(run.notes_path, sprintf('Shared crossover verdict: %s\n', char(comparison.sharedCrossoverVerdict)));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.relax = relax;
out.aging = aging;
out.comparison = comparison;
out.tables = struct('alignment', string(alignmentPath), 'metrics', string(metricsPath), 'windows', string(windowPath), 'manifest', string(manifestPath));
out.figures = struct('dip', string(figDip.png), 'fm', string(figFM.png), 'coeff', string(figCoeff.png), 'multi', string(figMulti.png), 'peak', string(figPeak.png), 'window', string(figWindow.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Relaxation-aging canonical comparison complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'relaxation_aging_canonical_comparison');
cfg = setDefaultField(cfg, 'relaxLabelHint', 'relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'agingObservableLabelHint', 'observable_mode_correlation');
cfg = setDefaultField(cfg, 'agingAuditLabelHint', 'observable_identification_audit');
cfg = setDefaultField(cfg, 'agingCollapseLabelHint', 'aging_shape_collapse_analysis');
cfg = setDefaultField(cfg, 'stateMapLabelHint', 'existing_results_state_map');
cfg = setDefaultField(cfg, 'unifiedLabelHint', 'unified_barrier_mechanism');
cfg = setDefaultField(cfg, 'interpolationMethod', 'pchip');
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
[source.relaxRunDir, source.relaxRunName] = findLatestRunWithFiles(repoRoot, 'relaxation', ...
    {'tables\observables_relaxation.csv', 'tables\temperature_observables.csv', 'reports\relaxation_observable_stability_report.md'}, cfg.relaxLabelHint);
[source.agingObservableRunDir, source.agingObservableRunName] = findLatestRunWithFiles(repoRoot, 'aging', ...
    {'tables\observable_matrix.csv', 'tables\svd_mode_coefficients.csv', 'reports\observable_mode_correlation_report.md', 'observables.csv'}, cfg.agingObservableLabelHint);
[source.agingAuditRunDir, source.agingAuditRunName] = findLatestRunWithFiles(repoRoot, 'aging', ...
    {'tables\aging_observable_recommendation_table.csv', 'tables\aging_tp_rank_summary.csv', 'reports\aging_observable_identification_audit.md'}, cfg.agingAuditLabelHint);
[source.agingCollapseRunDir, source.agingCollapseRunName] = findLatestRunWithFiles(repoRoot, 'aging', ...
    {'tables\aging_shape_variation_vs_Tp.csv', 'reports\aging_shape_collapse_analysis.md'}, cfg.agingCollapseLabelHint);

source.stateMapRunDir = "";
source.stateMapRunName = "";
try
    [source.stateMapRunDir, source.stateMapRunName] = findLatestRunWithFiles(repoRoot, 'cross_experiment', ...
        {'reports\existing_results_state_map.md'}, cfg.stateMapLabelHint);
catch
end

source.unifiedRunDir = "";
source.unifiedRunName = "";
try
    [source.unifiedRunDir, source.unifiedRunName] = findLatestRunWithFiles(repoRoot, 'cross_experiment', ...
        {'reports\unified_barrier_landscape_report.md'}, cfg.unifiedLabelHint);
catch
end

source.legacyCrossRunDir = fullfile(repoRoot, 'results', 'cross_analysis', 'runs', 'run_legacy_cross_analysis');
if exist(fullfile(source.legacyCrossRunDir, 'run_manifest.json'), 'file') ~= 2
    source.legacyCrossRunDir = "";
end
end

function relax = loadRelaxationSource(runDir)
obsTbl = readtable(fullfile(runDir, 'tables', 'observables_relaxation.csv'), 'VariableNamingRule', 'preserve');
tempTbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'), 'VariableNamingRule', 'preserve');

relax = struct();
relax.runDir = string(runDir);
relax.T = tempTbl.T(:);
relax.A = tempTbl.('A_T')(:);
relax.A_norm = normalizeToPeak(relax.A);
relax.Relax_T_peak = obsTbl.Relax_T_peak(1);
relax.Relax_peak_width = obsTbl.Relax_peak_width(1);
relax.window = computeCurveWindow(relax.T, relax.A, 'A(T)', false);
end

function aging = loadAgingSources(source)
matrixTbl = readtable(fullfile(source.agingObservableRunDir, 'tables', 'observable_matrix.csv'), 'VariableNamingRule', 'preserve');
coeffTbl = readtable(fullfile(source.agingObservableRunDir, 'tables', 'svd_mode_coefficients.csv'), 'VariableNamingRule', 'preserve');
auditTbl = readtable(fullfile(source.agingAuditRunDir, 'tables', 'aging_observable_recommendation_table.csv'), 'VariableNamingRule', 'preserve');
collapsePath = fullfile(source.agingCollapseRunDir, 'tables', 'aging_shape_variation_vs_Tp.csv');
collapseCell = readcell(collapsePath);
collapseHeaders = string(collapseCell(1, :));
collapseData = collapseCell(2:end, :);

tempVarMatrix = firstMatchingName(matrixTbl.Properties.VariableNames, {'temperature', 'Tp', 'Tp_K'});
tempVarCoeff = firstMatchingName(coeffTbl.Properties.VariableNames, {'temperature', 'Tp', 'Tp_K'});

aging = struct();
aging.observableRunDir = string(source.agingObservableRunDir);
aging.auditRunDir = string(source.agingAuditRunDir);
aging.collapseRunDir = string(source.agingCollapseRunDir);
aging.dip = aggregateCurve(matrixTbl.(tempVarMatrix), matrixTbl.Dip_depth, 'Dip_depth');
aging.fm = aggregateCurve(matrixTbl.(tempVarMatrix), matrixTbl.FM_abs, 'FM_abs');
aging.preferredCoeffMatrix = chooseCoeffMatrix(coeffTbl);
coeffMask = strcmp(string(coeffTbl.matrix_name), aging.preferredCoeffMatrix);
aging.coeffRaw = aggregateCurve(coeffTbl.(tempVarCoeff)(coeffMask), coeffTbl.coeff_mode1(coeffMask), 'coeff_mode1');

orientationCorr = corrSafe(aging.coeffRaw.valueMedian, interpAggregatedCurve(aging.dip, aging.coeffRaw.T), 'Pearson');
orientationSign = 1;
if isfinite(orientationCorr) && orientationCorr < 0
    orientationSign = -1;
end
aging.coeff = aging.coeffRaw;
aging.coeff.valueMedian = orientationSign * aging.coeffRaw.valueMedian;
aging.coeff.orientationNote = sprintf('coeff_mode1 sign %s for positive alignment with Dip_depth in %s basis', ...
    ternary(orientationSign < 0, 'flipped', 'kept'), char(aging.preferredCoeffMatrix));

collapseTIdx = findHeaderIndex(collapseHeaders, {'Tp_K', 'Tp', 'temperature'});
collapseRankIdx = findHeaderIndex(collapseHeaders, {'rank1_explained_variance_ratio'});
collapseShapeIdx = findHeaderIndex(collapseHeaders, {'shape_variation'});
collapseNIdx = findHeaderIndex(collapseHeaders, {'n_profiles', 'n_physical_points'});
collapseSourceIdx = findHeaderIndex(collapseHeaders, {'run_id', 'source_run', 'source_run_dir'});
rawCollapseSource = string(collapseData(:, collapseSourceIdx));
if any(contains(rawCollapseSource, filesep))
    collapseSourceName = strings(size(rawCollapseSource));
    for ii = 1:numel(rawCollapseSource)
        [~, collapseSourceName(ii)] = fileparts(rawCollapseSource(ii));
    end
else
    collapseSourceName = rawCollapseSource;
end
aging.collapse = struct();
aging.collapse.T = cell2mat(collapseData(:, collapseTIdx));
aging.collapse.value = cell2mat(collapseData(:, collapseRankIdx));
aging.collapse.shapeVariation = cell2mat(collapseData(:, collapseShapeIdx));
aging.collapse.nPhysicalPoints = cell2mat(collapseData(:, collapseNIdx));
aging.collapse.sourceRun = collapseSourceName(:);

aging.meta = struct();
aging.meta.Dip_depth = getAuditMeta(auditTbl, 'Dip_depth');
aging.meta.FM_abs = getAuditMeta(auditTbl, 'FM_abs');
aging.meta.coeff_mode1 = getAuditMeta(auditTbl, 'coeff_mode1');
aging.meta.rank1_explained_variance_ratio = struct('name', "rank1_explained_variance_ratio", 'category', "Supporting collapse metric", 'justification', "Saved Aging shape-collapse metric from the structured Tp sweep.");
end

function comparison = buildComparison(source, relax, aging, cfg)
allTemps = unique([aging.dip.T(:); aging.fm.T(:); aging.coeff.T(:); aging.collapse.T(:)]);
allTemps = allTemps(isfinite(allTemps));
allTemps = sort(allTemps(:));
allTemps = allTemps(allTemps >= min(relax.T) & allTemps <= max(relax.T));

alignment = table();
alignment.T_K = allTemps;
alignment.A_T = interp1(relax.T, relax.A, allTemps, cfg.interpolationMethod, NaN);
alignment.A_T_norm = normalizeToPeak(alignment.A_T);
alignment.Dip_depth = interpAggregatedCurve(aging.dip, allTemps);
alignment.Dip_depth_norm = normalizeToPeak(alignment.Dip_depth);
alignment.Dip_depth_n = interpAggregatedCounts(aging.dip, allTemps);
alignment.FM_abs = interpAggregatedCurve(aging.fm, allTemps);
alignment.FM_abs_norm = normalizeToPeak(alignment.FM_abs);
alignment.FM_abs_n = interpAggregatedCounts(aging.fm, allTemps);
alignment.coeff_mode1_raw = interpAggregatedCurve(aging.coeffRaw, allTemps);
alignment.coeff_mode1_oriented = interpAggregatedCurve(aging.coeff, allTemps);
alignment.coeff_mode1_norm = normalizeToPeak(alignment.coeff_mode1_oriented);
alignment.coeff_mode1_n = interpAggregatedCounts(aging.coeff, allTemps);
alignment.rank1_explained_variance_ratio = interp1(aging.collapse.T, aging.collapse.value, allTemps, 'linear', NaN);
alignment.rank1_explained_variance_ratio_norm = normalizeToPeak(alignment.rank1_explained_variance_ratio);
alignment.shape_variation = interp1(aging.collapse.T, aging.collapse.shapeVariation, allTemps, 'linear', NaN);

observableMap = struct();
observableMap.Dip_depth = makeObservable('Dip_depth', 'Aging Dip depth', aging.meta.Dip_depth, aging.dip.T, aging.dip.valueMedian, alignment.T_K, alignment.A_T, alignment.A_T_norm, alignment.Dip_depth, alignment.Dip_depth_norm, "");
observableMap.FM_abs = makeObservable('FM_abs', 'Aging FM abs', aging.meta.FM_abs, aging.fm.T, aging.fm.valueMedian, alignment.T_K, alignment.A_T, alignment.A_T_norm, alignment.FM_abs, alignment.FM_abs_norm, "");
observableMap.coeff_mode1 = makeObservable('coeff_mode1', sprintf('Aging coeff mode 1 (%s)', char(aging.preferredCoeffMatrix)), aging.meta.coeff_mode1, aging.coeff.T, aging.coeff.valueMedian, alignment.T_K, alignment.A_T, alignment.A_T_norm, alignment.coeff_mode1_oriented, alignment.coeff_mode1_norm, aging.coeff.orientationNote);
observableMap.rank1_explained_variance_ratio = makeObservable('rank1_explained_variance_ratio', 'Aging rank-1 collapse metric', aging.meta.rank1_explained_variance_ratio, aging.collapse.T, aging.collapse.value, alignment.T_K, alignment.A_T, alignment.A_T_norm, alignment.rank1_explained_variance_ratio, alignment.rank1_explained_variance_ratio_norm, "Higher values mean stronger near-rank-1 collapse.");

windowRows = {
    buildWindowRow('A_T', 'Relaxation A(T)', "Primary relaxation observable", relax.window, numel(relax.T), "");
    buildWindowRow(observableMap.Dip_depth.name, observableMap.Dip_depth.displayName, observableMap.Dip_depth.meta.category, observableMap.Dip_depth.window, observableMap.Dip_depth.nFinite, observableMap.Dip_depth.notes);
    buildWindowRow(observableMap.FM_abs.name, observableMap.FM_abs.displayName, observableMap.FM_abs.meta.category, observableMap.FM_abs.window, observableMap.FM_abs.nFinite, observableMap.FM_abs.notes);
    buildWindowRow(observableMap.coeff_mode1.name, observableMap.coeff_mode1.displayName, observableMap.coeff_mode1.meta.category, observableMap.coeff_mode1.window, observableMap.coeff_mode1.nFinite, observableMap.coeff_mode1.notes);
    buildWindowRow(observableMap.rank1_explained_variance_ratio.name, observableMap.rank1_explained_variance_ratio.displayName, observableMap.rank1_explained_variance_ratio.meta.category, observableMap.rank1_explained_variance_ratio.window, observableMap.rank1_explained_variance_ratio.nFinite, observableMap.rank1_explained_variance_ratio.notes)
    };
windowTable = vertcat(windowRows{:});

metricRows = {
    buildMetricRow(relax.window, observableMap.Dip_depth);
    buildMetricRow(relax.window, observableMap.FM_abs);
    buildMetricRow(relax.window, observableMap.coeff_mode1);
    buildMetricRow(relax.window, observableMap.rank1_explained_variance_ratio)
    };
metricsTable = vertcat(metricRows{:});

comparison = struct();
comparison.alignmentTable = alignment;
comparison.windowTable = windowTable;
comparison.metricsTable = metricsTable;
comparison.sourceManifestTable = buildSourceManifest(source, aging);
comparison.observableMap = observableMap;
comparison.relaxWindow = relax.window;
comparison.commonTemperatureGrid = allTemps;
comparison.sharedCrossoverVerdict = classifySharedCrossover(metricsTable);
comparison.sharedCrossoverSupport = summarizeSharedCrossover(metricsTable);
end
function obs = makeObservable(name, displayName, meta, nativeT, nativeValue, alignedT, alignedA, alignedANorm, alignedValue, alignedNorm, notes)
obs = struct();
obs.name = string(name);
obs.displayName = string(displayName);
obs.meta = meta;
obs.notes = string(notes);
obs.T = nativeT(:);
obs.value = nativeValue(:);
obs.valueNorm = normalizeToPeak(obs.value);
obs.nFinite = sum(isfinite(obs.value));
obs.window = computeCurveWindow(obs.T, obs.value, displayName, contains(lower(name), 'coeff_mode1'));
obs.metrics = computeOverlayMetrics(alignedT, alignedA, alignedANorm, alignedValue, alignedNorm, obs.window);
obs.classification = classifyComparison(meta.category, obs.metrics, obs.nFinite);
end

function metricRow = buildMetricRow(relaxWindow, obs)
metricRow = table( ...
    obs.name, obs.displayName, string(obs.meta.category), obs.classification, ...
    obs.metrics.nOverlap, obs.metrics.rawPearson, obs.metrics.rawSpearman, ...
    obs.metrics.normPearson, obs.metrics.normSpearman, obs.metrics.rmsNormDiff, ...
    obs.metrics.peakDeltaK, obs.metrics.fwhmOverlap, obs.metrics.supportOverlap, ...
    relaxWindow.peakT, obs.window.peakT, ...
    relaxWindow.low50, relaxWindow.high50, obs.window.low50, obs.window.high50, ...
    relaxWindow.low25, relaxWindow.high25, obs.window.low25, obs.window.high25, ...
    string(obs.window.signLabel), string(obs.window.shapeLabel), string(obs.notes), ...
    'VariableNames', {'observable', 'display_name', 'category', 'comparison_strength', ...
    'n_overlap', 'raw_pearson', 'raw_spearman', 'normalized_pearson', 'normalized_spearman', ...
    'normalized_rms_difference', 'peak_delta_K', 'fwhm_overlap_fraction', 'support25_overlap_fraction', ...
    'relax_peak_T_K', 'observable_peak_T_K', 'relax_fwhm_low_K', 'relax_fwhm_high_K', ...
    'observable_fwhm_low_K', 'observable_fwhm_high_K', 'relax_support25_low_K', 'relax_support25_high_K', ...
    'observable_support25_low_K', 'observable_support25_high_K', 'sign_note', 'shape_note', 'notes'});
end

function windowRow = buildWindowRow(name, displayName, category, window, nFinite, notes)
windowRow = table( ...
    string(name), string(displayName), string(category), nFinite, ...
    window.peakT, window.peakValue, window.low50, window.high50, window.width50, ...
    window.low25, window.high25, window.width25, string(window.signLabel), string(window.shapeLabel), string(notes), ...
    'VariableNames', {'observable', 'display_name', 'category', 'n_finite', 'peak_T_K', 'peak_value', ...
    'fwhm_low_K', 'fwhm_high_K', 'fwhm_width_K', 'support25_low_K', 'support25_high_K', ...
    'support25_width_K', 'sign_note', 'shape_note', 'notes'});
end

function manifestTable = buildSourceManifest(source, aging)
rows = {
    loadManifestRow(source.relaxRunDir, 'direct_data', 'Relaxation A(T) source', 'observables_relaxation.csv; temperature_observables.csv');
    loadManifestRow(source.agingObservableRunDir, 'direct_data', 'Aging pooled observables', 'observable_matrix.csv; svd_mode_coefficients.csv; observables.csv');
    loadManifestRow(source.agingAuditRunDir, 'direct_context', 'Aging confidence audit', 'aging_observable_recommendation_table.csv; aging_tp_rank_summary.csv');
    loadManifestRow(source.agingCollapseRunDir, 'direct_data', 'Aging collapse metric source', 'aging_shape_variation_vs_Tp.csv')
    };
if strlength(source.stateMapRunDir) > 0
    rows{end + 1, 1} = loadManifestRow(source.stateMapRunDir, 'context_only', 'Repository state map', 'existing_results_state_map.md');
end
if strlength(source.unifiedRunDir) > 0
    rows{end + 1, 1} = loadManifestRow(source.unifiedRunDir, 'context_only', 'Existing three-way comparison context', 'unified_barrier_landscape_report.md');
end
if strlength(source.legacyCrossRunDir) > 0
    rows{end + 1, 1} = loadManifestRow(source.legacyCrossRunDir, 'legacy_context', 'Legacy cross tree inspected', 'run_manifest.json');
end
collapseRuns = unique(aging.collapse.sourceRun);
for i = 1:numel(collapseRuns)
    runName = collapseRuns(i);
    if strlength(runName) == 0
        continue;
    end
    runDir = fullfile(fileparts(char(aging.collapseRunDir)), char(runName));
    if exist(runDir, 'dir') == 7
        rows{end + 1, 1} = loadManifestRow(runDir, 'indirect_provenance', 'Structured Tp run referenced by collapse sweep', 'observables.csv; DeltaM_map.csv');
    end
end
manifestTable = vertcat(rows{:});
end

function row = loadManifestRow(runDir, usageRole, usageNote, keyFiles)
manifestPath = fullfile(char(runDir), 'run_manifest.json');
if exist(manifestPath, 'file') == 2
    try
        manifest = jsondecode(fileread(manifestPath));
        runId = string(getStructFieldOr(manifest, 'run_id', ""));
        experiment = string(getStructFieldOr(manifest, 'experiment', ""));
        label = string(getStructFieldOr(manifest, 'label', ""));
        timestamp = string(getStructFieldOr(manifest, 'timestamp', ""));
        dataset = string(getStructFieldOr(manifest, 'dataset', usageNote));
        runDirOut = string(getStructFieldOr(manifest, 'run_dir', char(runDir)));
    catch
        [~, name] = fileparts(char(runDir));
        runId = string(name);
        experiment = "";
        label = "";
        timestamp = "";
        dataset = string(usageNote);
        runDirOut = string(runDir);
    end
else
    [~, name] = fileparts(char(runDir));
    runId = string(name);
    experiment = "";
    label = "";
    timestamp = "";
    dataset = string(usageNote);
    runDirOut = string(runDir);
end
row = table(runId, string(usageRole), experiment, label, timestamp, dataset, runDirOut, string(keyFiles), ...
    'VariableNames', {'run_id', 'usage_role', 'experiment', 'label', 'timestamp', 'dataset', 'run_dir', 'key_files'});
end

function figPaths = savePairFigure(relax, obs, relaxWindow, commonT, runDir, figureName, figureTitle, obsLabel)
fig = create_figure('Position', [2 2 17.8 10.0]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, relax.T, relax.A, '-o', 'Color', rgb('#0072B2'), 'MarkerFaceColor', 'w', 'LineWidth', 2.0, 'MarkerSize', 5);
patchWindow(ax1, relaxWindow.low50, relaxWindow.high50, [0.85 0.92 0.98], 0.6);
plot(ax1, relaxWindow.peakT, relaxWindow.peakValue, 'd', 'Color', rgb('#0072B2'), 'MarkerFaceColor', rgb('#0072B2'), 'MarkerSize', 6);
hold(ax1, 'off');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'A(T) (arb.)');
title(ax1, sprintf('%s: relaxation amplitude', figureTitle));
styleLineAxes(ax1, [min(commonT) max(commonT)]);

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, obs.T, obs.value, '-s', 'Color', rgb('#D55E00'), 'MarkerFaceColor', 'w', 'LineWidth', 2.0, 'MarkerSize', 5);
patchWindow(ax2, obs.window.low50, obs.window.high50, [0.99 0.90 0.82], 0.7);
plot(ax2, obs.window.peakT, obs.window.peakValue, 'd', 'Color', rgb('#D55E00'), 'MarkerFaceColor', rgb('#D55E00'), 'MarkerSize', 6);
hold(ax2, 'off');
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, obsLabel);
styleLineAxes(ax2, [min(commonT) max(commonT)]);
text(ax2, 0.01, 0.96, sprintf('comparison: %s | norm corr = %.2f | peak delta = %.1f K | FWHM overlap = %.2f', ...
    obs.classification, obs.metrics.normPearson, obs.metrics.peakDeltaK, obs.metrics.fwhmOverlap), ...
    'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 8, 'BackgroundColor', 'w', 'Margin', 4);
if strlength(obs.notes) > 0
    text(ax2, 0.01, 0.83, char(obs.notes), 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 8, 'BackgroundColor', 'w', 'Margin', 4);
end

figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveNormalizedMultiOverlayFigure(comparison, runDir, figureName)
fig = create_figure('Position', [2 2 17.8 7.6]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, comparison.alignmentTable.T_K, comparison.alignmentTable.A_T_norm, '-o', 'Color', rgb('#000000'), 'MarkerFaceColor', 'w', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'Relaxation A(T)');
plot(ax, comparison.alignmentTable.T_K, comparison.alignmentTable.Dip_depth_norm, '-s', 'Color', rgb('#0072B2'), 'MarkerFaceColor', 'w', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'Dip depth');
plot(ax, comparison.alignmentTable.T_K, comparison.alignmentTable.FM_abs_norm, '-^', 'Color', rgb('#E69F00'), 'MarkerFaceColor', 'w', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'FM abs');
plot(ax, comparison.alignmentTable.T_K, comparison.alignmentTable.coeff_mode1_norm, '-d', 'Color', rgb('#009E73'), 'MarkerFaceColor', 'w', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'coeff mode 1 (oriented)');
plot(ax, comparison.alignmentTable.T_K, comparison.alignmentTable.rank1_explained_variance_ratio_norm, '--', 'Color', rgb('#CC79A7'), 'LineWidth', 1.8, 'DisplayName', 'rank-1 collapse');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized amplitude');
title(ax, 'Normalized Relaxation-Aging overlays on the Aging T_p grid');
styleLineAxes(ax, [min(comparison.commonTemperatureGrid) max(comparison.commonTemperatureGrid)]);
ylim(ax, [-0.15 1.08]);
legend(ax, 'Location', 'eastoutside');
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = savePeakSummaryFigure(comparison, runDir, figureName)
fig = create_figure('Position', [2 2 17.8 7.4]);
ax = axes(fig);
metricTbl = comparison.metricsTable;
displayNames = ["Relaxation A(T)"; metricTbl.display_name];
peakT = [comparison.relaxWindow.peakT; metricTbl.observable_peak_T_K];
yPos = 1:numel(displayNames);
hold(ax, 'on');
xline(ax, comparison.relaxWindow.peakT, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2, 'DisplayName', 'Relaxation peak');
plot(ax, peakT, yPos, 'o', 'Color', rgb('#0072B2'), 'MarkerFaceColor', rgb('#0072B2'), 'MarkerSize', 6, 'LineStyle', 'none', 'DisplayName', 'Observable peak');
for i = 2:numel(displayNames)
    text(ax, peakT(i) + 0.4, yPos(i), sprintf('dT = %.1f K', metricTbl.peak_delta_K(i - 1)), 'FontSize', 8, 'VerticalAlignment', 'middle');
end
hold(ax, 'off');
set(ax, 'YTick', yPos, 'YTickLabel', displayNames, 'YDir', 'reverse');
xlabel(ax, 'Peak temperature (K)');
ylabel(ax, 'Observable');
title(ax, 'Peak-temperature alignment summary');
styleLineAxes(ax, [min(comparison.commonTemperatureGrid) max(comparison.commonTemperatureGrid)]);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveWindowOverlapFigure(comparison, runDir, figureName)
fig = create_figure('Position', [2 2 17.8 8.8]);
ax = axes(fig);
rows = comparison.windowTable;
colors = [rgb('#000000'); rgb('#0072B2'); rgb('#E69F00'); rgb('#009E73'); rgb('#CC79A7')];
yPos = numel(rows.observable):-1:1;
hold(ax, 'on');
for i = 1:height(rows)
    c = colors(min(i, size(colors, 1)), :);
    plotWindowBand(ax, rows.support25_low_K(i), rows.support25_high_K(i), yPos(i), c, 0.18, 0.18);
    plotWindowBand(ax, rows.fwhm_low_K(i), rows.fwhm_high_K(i), yPos(i), c, 0.34, 0.34);
    plot(ax, rows.peak_T_K(i), yPos(i), 'o', 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 6);
end
hold(ax, 'off');
set(ax, 'YTick', yPos, 'YTickLabel', rows.display_name);
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Observable window');
title(ax, 'Temperature-window overlap');
styleLineAxes(ax, [min(comparison.commonTemperatureGrid) max(comparison.commonTemperatureGrid)]);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end
function reportText = buildReport(thisFile, source, relax, aging, comparison)
lines = strings(0, 1);
lines(end + 1) = "# Relaxation-Aging Canonical Comparison";
lines(end + 1) = "";
lines(end + 1) = sprintf('Generated: %s', stampNow());
lines(end + 1) = sprintf('Run root: `%s`', getRunOutputDir());
lines(end + 1) = "";
lines(end + 1) = "## Repository-state summary";
lines(end + 1) = sprintf('- Relevant Relaxation canonical run found: `%s` with `tables/temperature_observables.csv`, `tables/observables_relaxation.csv`, and `reports/relaxation_observable_stability_report.md`.', source.relaxRunName);
lines(end + 1) = sprintf('- Relevant Aging observable run found: `%s` with `tables/observable_matrix.csv`, `tables/svd_mode_coefficients.csv`, `observables.csv`, and `reports/observable_mode_correlation_report.md`.', source.agingObservableRunName);
lines(end + 1) = sprintf('- Relevant Aging confidence audit found: `%s` with `tables/aging_observable_recommendation_table.csv` and `tables/aging_tp_rank_summary.csv`.', source.agingAuditRunName);
lines(end + 1) = sprintf('- Relevant Aging collapse run found: `%s` with `tables/aging_shape_variation_vs_Tp.csv` and `reports/aging_shape_collapse_analysis.md`.', source.agingCollapseRunName);
if strlength(source.stateMapRunName) > 0
    lines(end + 1) = sprintf('- Saved repository state map found: `%s`; it reports that no dedicated saved pairwise Relaxation <-> Aging run existed before this one.', source.stateMapRunName);
end
if strlength(source.unifiedRunName) > 0
    lines(end + 1) = sprintf('- Existing modern cross-experiment context run found: `%s`; it is broader Relaxation <-> Aging <-> Switching context, not a dedicated pairwise Relaxation <-> Aging run.', source.unifiedRunName);
end
if strlength(source.legacyCrossRunDir) > 0
    lines(end + 1) = '- Legacy cross tree found: `results/cross_analysis/runs/run_legacy_cross_analysis/`; it is historical and non-canonical for this task.';
end
lines(end + 1) = '- Saved observables already present before this work: Relaxation `A_T`, `Relax_T_peak`, `Relax_peak_width`; Aging `Dip_depth`, `FM_abs`, `coeff_mode1`, and structured `Tp` rank/collapse summaries.';
lines(end + 1) = sprintf('- New script added for this run: `%s`.', string(thisFile));
lines(end + 1) = '- Existing source pipelines were not modified or rerun.';
lines(end + 1) = "";
lines(end + 1) = "## Source runs used";
lines(end + 1) = sprintf('- Relaxation source run: `%s`', source.relaxRunName);
lines(end + 1) = sprintf('- Aging observable source run: `%s`', source.agingObservableRunName);
lines(end + 1) = sprintf('- Aging audit source run: `%s`', source.agingAuditRunName);
lines(end + 1) = sprintf('- Aging collapse source run: `%s`', source.agingCollapseRunName);
lines(end + 1) = "";
lines(end + 1) = "## Observable selection";
lines(end + 1) = '- `A(T)` was selected because the Relaxation stability audit identifies it as the central, stable, near-rank-1 activity envelope.';
lines(end + 1) = '- `Dip_depth(T)` was selected because the Aging audit calls it the primary Aging observable and the cleanest recurring match to mode 1.';
lines(end + 1) = '- `FM_abs(T)` was kept as a supporting background observable because it is present in saved outputs but explicitly weaker and missing at low `Tp`.';
lines(end + 1) = sprintf('- `coeff_mode1(T)` was included only as a supporting geometry descriptor from the `%s` basis; its sign was oriented for comparison, but the sign is still convention-dependent rather than physical.', aging.preferredCoeffMatrix);
lines(end + 1) = '- The saved Aging collapse metric was taken from `rank1_explained_variance_ratio(T_p)` in the shape-collapse sweep; `shape_variation(T_p)` is retained as auxiliary context in the alignment table.';
lines(end + 1) = "";
lines(end + 1) = "## Alignment method";
lines(end + 1) = '- The comparison uses the Aging `T_p` grid in the overlap interval with Relaxation.';
lines(end + 1) = '- Relaxation `A(T)` was interpolated onto that grid with `pchip` so the Aging points remain the comparison anchor and no new Aging temperatures are invented.';
lines(end + 1) = '- Aging `Dip_depth` and `FM_abs` were aggregated across saved wait-time rows by median at each `T_p`; the per-temperature sample counts remain in the alignment table.';
lines(end + 1) = '- Peak windows use dense linear interpolation only to estimate peak, FWHM, and 25%-support windows from the saved discrete points.';
lines(end + 1) = "";
lines(end + 1) = "## Findings by observable";
for i = 1:height(comparison.metricsTable)
    row = comparison.metricsTable(i, :);
    lines(end + 1) = sprintf('- `%s`: %s. normalized corr = %.3f, peak shift = %.1f K, FWHM overlap = %.3f, support-window overlap = %.3f.', ...
        row.observable, row.comparison_strength, row.normalized_pearson, row.peak_delta_K, row.fwhm_overlap_fraction, row.support25_overlap_fraction);
    lines(end + 1) = sprintf('  category: %s', row.category);
    lines(end + 1) = sprintf('  sign / shape note: %s | %s', row.sign_note, row.shape_note);
    if strlength(row.notes) > 0
        lines(end + 1) = sprintf('  note: %s', row.notes);
    end
end
lines(end + 1) = "";
lines(end + 1) = "## Shared crossover window";
lines(end + 1) = sprintf('- Overall verdict: **%s**.', comparison.sharedCrossoverVerdict);
lines(end + 1) = sprintf('- Summary: %s', comparison.sharedCrossoverSupport);
lines(end + 1) = sprintf('- Relaxation `A(T)` peaks at %.1f K with FWHM [%.1f, %.1f] K.', relax.window.peakT, relax.window.low50, relax.window.high50);
lines(end + 1) = "";
lines(end + 1) = "## Mechanism limits";
lines(end + 1) = '- The Relaxation side supports a strong empirical `A(T)` envelope, but not a unique microscopic Arrhenius-collapse mechanism.';
lines(end + 1) = '- The Aging observable run is a pooled cross-`Tp` and cross-wait-time baseline where the saved `temperature` coordinate is the stopping temperature carried through the join.';
lines(end + 1) = '- `FM_abs` remains partially missing at low `Tp`, so any alignment claim using it should stay supporting rather than primary.';
lines(end + 1) = '- `coeff_mode1` remains geometry-only: its cross-run sign is not physically stable, so it cannot by itself establish a mechanism.';
lines(end + 1) = '- The shape-collapse metric is informative for near-separability, but it is a sweep summary over the saved structured `Tp` runs, with fragile high-`Tp` cases where only three physical profiles exist.';
lines(end + 1) = "";
lines(end + 1) = "## What remains missing for a stronger claim";
lines(end + 1) = '- A dedicated Aging run exporting one trusted `Tp`-resolved physical observable family on the same footing as the Relaxation stability audit.';
lines(end + 1) = '- More complete high-`Tp` structured Aging exports with four physical wait-time points instead of the fragile three-point cases.';
lines(end + 1) = '- A direct mechanistic bridge that is stronger than window/shape alignment, for example a validated shared model rather than a shared temperature band alone.';
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = '- number of curves: pair figures use one Relaxation curve and one Aging curve per panel; the multi-overlay uses 5 curves.';
lines(end + 1) = '- legend vs colormap: explicit legends only because every panel stays at 5 curves or fewer.';
lines(end + 1) = '- colormap used: none for line figures; categorical color-blind-safe palette from the figure style guide.';
lines(end + 1) = '- smoothing applied: none to the source observables; only interpolation for alignment and window estimation was used.';
lines(end + 1) = '- justification: the figure set stays small and directly tied to the requested physical comparison rather than expanding to an all-vs-all matrix.';
reportText = strjoin(lines, newline);
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
zip(zipPath, {'reports', 'tables', 'figures', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function agg = aggregateCurve(T, values, name)
T = double(T(:));
values = double(values(:));
mask = isfinite(T);
T = T(mask);
values = values(mask);
[Tu, ~, groupId] = unique(T);
agg = struct();
agg.name = string(name);
agg.T = Tu(:);
agg.valueMedian = splitapply(@medianNoNan, values, groupId);
agg.count = splitapply(@(x) sum(isfinite(x)), values, groupId);
end

function out = medianNoNan(x)
x = x(isfinite(x));
if isempty(x)
    out = NaN;
else
    out = median(x);
end
end

function window = computeCurveWindow(T, values, label, signAmbiguous)
T = double(T(:));
values = double(values(:));
mask = isfinite(T) & isfinite(values);
T = T(mask);
values = values(mask);
window = struct('label', string(label), 'peakT', NaN, 'peakValue', NaN, 'low50', NaN, 'high50', NaN, 'width50', NaN, 'low25', NaN, 'high25', NaN, 'width25', NaN, 'signLabel', "insufficient", 'shapeLabel', "insufficient");
if numel(T) < 2
    return;
end
[T, order] = sort(T);
values = values(order);
Td = linspace(min(T), max(T), 800).';
method = 'linear';
if numel(unique(T)) >= 4
    method = 'pchip';
end
vd = interp1(T, values, Td, method, 'extrap');
[peakValue, peakIdx] = max(vd);
if ~isfinite(peakValue)
    return;
end
normV = vd ./ peakValue;
[low50, high50] = thresholdWindow(Td, normV, 0.50);
[low25, high25] = thresholdWindow(Td, normV, 0.25);
window.peakT = Td(peakIdx);
window.peakValue = peakValue;
window.low50 = low50;
window.high50 = high50;
window.width50 = high50 - low50;
window.low25 = low25;
window.high25 = high25;
window.width25 = high25 - low25;
window.signLabel = describeSign(values, signAmbiguous);
window.shapeLabel = describeShape(Td, normV, peakIdx);
end

function metrics = computeOverlayMetrics(T, A, A_norm, B, B_norm, obsWindow)
mask = isfinite(T) & isfinite(A) & isfinite(B);
metrics = struct();
metrics.nOverlap = sum(mask);
metrics.rawPearson = corrSafe(A(mask), B(mask), 'Pearson');
metrics.rawSpearman = corrSafe(A(mask), B(mask), 'Spearman');
metrics.normPearson = corrSafe(A_norm(mask), B_norm(mask), 'Pearson');
metrics.normSpearman = corrSafe(A_norm(mask), B_norm(mask), 'Spearman');
metrics.rmsNormDiff = sqrt(mean((A_norm(mask) - B_norm(mask)).^2, 'omitnan'));
refWindow = computeCurveWindow(T, A, 'A_interp', false);
metrics.peakDeltaK = obsWindow.peakT - refWindow.peakT;
metrics.fwhmOverlap = intervalOverlap(refWindow.low50, refWindow.high50, obsWindow.low50, obsWindow.high50);
metrics.supportOverlap = intervalOverlap(refWindow.low25, refWindow.high25, obsWindow.low25, obsWindow.high25);
end

function classLabel = classifyComparison(category, metrics, nFinite)
levels = ["inconclusive", "weak", "suggestive", "strong"];
if nFinite < 4 || metrics.nOverlap < 4
    classLabel = levels(1);
    return;
end
score = 0;
if isfinite(metrics.normPearson)
    if abs(metrics.normPearson) >= 0.80
        score = score + 2;
    elseif abs(metrics.normPearson) >= 0.60
        score = score + 1;
    elseif abs(metrics.normPearson) >= 0.40
        score = score + 0.5;
    end
end
if isfinite(metrics.fwhmOverlap)
    if metrics.fwhmOverlap >= 0.60
        score = score + 2;
    elseif metrics.fwhmOverlap >= 0.35
        score = score + 1;
    elseif metrics.fwhmOverlap >= 0.15
        score = score + 0.5;
    end
end
if isfinite(metrics.peakDeltaK)
    if abs(metrics.peakDeltaK) <= 3
        score = score + 1;
    elseif abs(metrics.peakDeltaK) <= 6
        score = score + 0.5;
    end
end
idx = 1;
if score >= 4.5
    idx = 4;
elseif score >= 3.0
    idx = 3;
elseif score >= 1.5
    idx = 2;
end
maxIdx = 4;
category = lower(string(category));
if contains(category, 'supporting') || contains(category, 'geometric')
    maxIdx = 3;
elseif contains(category, 'tentative')
    maxIdx = 2;
end
classLabel = levels(min(idx, maxIdx));
end

function verdict = classifySharedCrossover(metricTbl)
dipRow = metricTbl(metricTbl.observable == "Dip_depth", :);
if ~isempty(dipRow) && dipRow.comparison_strength == "strong"
    verdict = "suggestive-to-strong shared crossover window";
elseif ~isempty(dipRow) && any(dipRow.comparison_strength == ["suggestive", "strong"])
    verdict = "suggestive shared crossover window";
elseif any(metricTbl.comparison_strength == "suggestive")
    verdict = "partial overlap only";
else
    verdict = "inconclusive shared crossover window";
end
end

function summary = summarizeSharedCrossover(metricTbl)
parts = strings(0, 1);
for i = 1:height(metricTbl)
    parts(end + 1) = sprintf('%s is %s', metricTbl.observable(i), metricTbl.comparison_strength(i));
end
summary = strjoin(parts, '; ');
end

function meta = getAuditMeta(auditTbl, observableName)
row = auditTbl(strcmp(string(auditTbl.name), observableName), :);
if isempty(row)
    meta = struct('name', string(observableName), 'category', "Unclassified", 'justification', "");
else
    meta = struct('name', string(row.name(1)), 'category', string(row.category(1)), 'justification', string(getTableValueOr(row, 'justification', "")));
end
end

function preferred = chooseCoeffMatrix(coeffTbl)
available = unique(string(coeffTbl.matrix_name));
if any(available == "shifted_Tp")
    preferred = "shifted_Tp";
elseif any(available == "raw_T")
    preferred = "raw_T";
else
    preferred = available(1);
end
end

function value = interpAggregatedCurve(agg, Tquery)
value = interp1(agg.T, agg.valueMedian, Tquery, 'linear', NaN);
end

function value = interpAggregatedCounts(agg, Tquery)
value = interp1(agg.T, double(agg.count), Tquery, 'nearest', NaN);
end

function value = normalizeToPeak(values)
values = double(values(:));
peak = max(values, [], 'omitnan');
if ~isfinite(peak) || peak <= 0
    value = NaN(size(values));
else
    value = values ./ peak;
end
end

function [lowT, highT] = thresholdWindow(T, values, threshold)
mask = isfinite(T) & isfinite(values) & values >= threshold;
if ~any(mask)
    lowT = NaN;
    highT = NaN;
else
    idx = find(mask);
    lowT = T(idx(1));
    highT = T(idx(end));
end
end

function overlap = intervalOverlap(a1, a2, b1, b2)
if any(~isfinite([a1 a2 b1 b2]))
    overlap = NaN;
    return;
end
left = max(a1, b1);
right = min(a2, b2);
if right <= left
    overlap = 0;
    return;
end
unionWidth = max(a2, b2) - min(a1, b1);
overlap = (right - left) / unionWidth;
end

function signLabel = describeSign(values, signAmbiguous)
values = values(isfinite(values));
if isempty(values)
    signLabel = "insufficient";
elseif signAmbiguous
    signLabel = "oriented sign; physical sign is convention-dependent";
elseif all(values >= 0)
    signLabel = "positive-valued";
elseif all(values <= 0)
    signLabel = "negative-valued";
else
    signLabel = "sign-changing";
end
end

function shapeLabel = describeShape(Td, normV, peakIdx)
if peakIdx <= 0.15 * numel(Td)
    shapeLabel = "low-temperature edge peak";
elseif peakIdx >= 0.85 * numel(Td)
    shapeLabel = "high-temperature edge peak";
elseif sum(normV >= 0.50) > 0.35 * numel(normV)
    shapeLabel = "broad single peak";
else
    shapeLabel = "single interior peak";
end
end

function styleLineAxes(ax, xLimits)
set(ax, 'FontName', resolvePlotFont(), 'FontSize', 8, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top', 'XMinorTick', 'off', 'YMinorTick', 'off');
xlim(ax, xLimits);
end

function patchWindow(ax, x1, x2, colorValue, alphaValue)
if ~all(isfinite([x1 x2])) || x2 <= x1
    return;
end
yl = ylim(ax);
patch(ax, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], colorValue, 'FaceAlpha', alphaValue, 'EdgeColor', 'none');
uistack(findobj(ax, 'Type', 'line'), 'top');
end

function plotWindowBand(ax, x1, x2, y, colorValue, halfHeight, alphaValue)
if ~all(isfinite([x1 x2])) || x2 <= x1
    return;
end
patch(ax, [x1 x2 x2 x1], [y - halfHeight y - halfHeight y + halfHeight y + halfHeight], colorValue, 'FaceAlpha', alphaValue, 'EdgeColor', 'none');
end

function c = rgb(hex)
hex = char(string(hex));
if startsWith(hex, '#')
    hex = hex(2:end);
end
c = sscanf(hex, '%2x%2x%2x', [1 3]) / 255;
end

function value = corrSafe(x, y, corrType)
if nargin < 3
    corrType = 'Pearson';
end
x = double(x(:));
y = double(y(:));
mask = isfinite(x) & isfinite(y);
if sum(mask) < 3
    value = NaN;
else
    try
        value = corr(x(mask), y(mask), 'Type', corrType, 'Rows', 'complete');
    catch
        value = corr(x(mask), y(mask), 'Rows', 'complete');
    end
end
end

function idx = findHeaderIndex(headers, candidates)
idx = [];
headers = string(headers);
for i = 1:numel(candidates)
    hit = find(strcmp(headers, candidates{i}), 1);
    if ~isempty(hit)
        idx = hit;
        return;
    end
end
error('None of the candidate headers were found.');
end
function name = firstMatchingName(varNames, candidates)
name = "";
for i = 1:numel(candidates)
    idx = find(strcmp(varNames, candidates{i}), 1);
    if ~isempty(idx)
        name = string(varNames{idx});
        return;
    end
end
error('None of the candidate variables were found.');
end

function out = setDefaultField(cfg, fieldName, defaultValue)
out = cfg;
if ~isfield(out, fieldName) || isempty(out.(fieldName))
    out.(fieldName) = defaultValue;
end
end

function [runDir, runName] = findLatestRunWithFiles(repoRoot, experiment, requiredFiles, labelHint)
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);
for i = numel(runDirs):-1:1
    candidateName = string(runDirs(i).name);
    if strlength(labelHint) > 0 && ~contains(candidateName, labelHint)
        continue;
    end
    candidateDir = fullfile(runDirs(i).folder, runDirs(i).name);
    ok = true;
    for k = 1:numel(requiredFiles)
        if exist(fullfile(candidateDir, requiredFiles{k}), 'file') ~= 2
            ok = false;
            break;
        end
    end
    if ok
        runDir = string(candidateDir);
        runName = candidateName;
        return;
    end
end
error('No %s run matched label hint %s with required files.', experiment, labelHint);
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function out = stampNow()
out = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function out = getStructFieldOr(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    out = s.(fieldName);
else
    out = defaultValue;
end
end

function out = getTableValueOr(tbl, fieldName, defaultValue)
if ismember(fieldName, tbl.Properties.VariableNames)
    out = tbl.(fieldName)(1);
else
    out = defaultValue;
end
end

function out = ternary(condition, trueValue, falseValue)
if condition
    out = trueValue;
else
    out = falseValue;
end
end

function fontName = resolvePlotFont()
fontName = 'Helvetica';
try
    fonts = listfonts;
    if ~any(strcmpi(fonts, fontName)) && any(strcmpi(fonts, 'Arial'))
        fontName = 'Arial';
    end
catch
    fontName = 'Arial';
end
end







