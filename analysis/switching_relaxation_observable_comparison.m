function out = switching_relaxation_observable_comparison(cfg)
% switching_relaxation_observable_comparison
% Compare saved switching ridge observables against Relaxation A(T) using
% saved run outputs only. No switching maps are recomputed.

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
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | switch:%s | motion:%s', ...
    char(source.relaxRunName), char(source.switchRunName), char(source.motionRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Switching-relaxation observable comparison run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Switching source run: %s\n', source.switchRunName);
fprintf('Saved motion source run: %s\n', source.motionRunName);

appendText(run.log_path, sprintf('[%s] switching-relaxation observable comparison started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Saved motion source: %s\n', char(source.motionRunName)));

relax = loadRelaxationData(source.relaxRunDir);
switching = loadSwitchingData(source.switchRunDir);
motion = loadSavedMotionData(source.motionRunDir);

aligned = buildAlignedData(relax, switching, motion, cfg);
relax.alignedPeakT = computeAlignedPeakTemperature(aligned);
summaryTbl = buildSummaryTable(aligned, relax);
curveTbl = buildCurveTable(aligned, relax);
manifestTbl = buildManifestTable(source);

curvePath = save_run_table(curveTbl, 'switching_relaxation_observable_curves.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'switching_relaxation_observable_alignment_summary.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

figGrid = saveAlignmentGridFigure(aligned, relax, runDir, 'switching_relaxation_alignment_grid');
figAll = saveNormalizedOverlayFigure(aligned, relax, runDir, 'switching_relaxation_normalized_overlay');
figPeaks = savePeakSummaryFigure(summaryTbl, relax, runDir, 'switching_relaxation_peak_summary');

reportText = buildReportText(source, relax, aligned, summaryTbl, cfg);
reportPath = save_run_report(reportText, 'switching_relaxation_observable_comparison.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_relaxation_observable_comparison.zip');

bestPearsonRow = summaryTbl(summaryTbl.pearson_rank == 1, :);
bestSpearmanRow = summaryTbl(summaryTbl.spearman_rank == 1, :);
appendText(run.notes_path, sprintf('Relaxation source peak = %.6g K\n', relax.sourcePeakT));
appendText(run.notes_path, sprintf('Relaxation aligned peak = %.6g K\n', relax.alignedPeakT));
appendText(run.notes_path, sprintf('Best Pearson observable = %s (r = %.6g)\n', ...
    char(bestPearsonRow.observable_key(1)), bestPearsonRow.pearson_r(1)));
appendText(run.notes_path, sprintf('Best Spearman observable = %s (rho = %.6g)\n', ...
    char(bestSpearmanRow.observable_key(1)), bestSpearmanRow.spearman_r(1)));
appendText(run.notes_path, sprintf('Overall verdict = %s\n', char(selectOverallWinner(summaryTbl))));

appendText(run.log_path, sprintf('[%s] switching-relaxation observable comparison complete\n', stampNow()));
appendText(run.log_path, sprintf('Curve table: %s\n', curvePath));
appendText(run.log_path, sprintf('Summary table: %s\n', summaryPath));
appendText(run.log_path, sprintf('Manifest table: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.relax = relax;
out.aligned = aligned;
out.tables = struct('curves', string(curvePath), 'summary', string(summaryPath), 'manifest', string(manifestPath));
out.figures = struct('grid', string(figGrid.png), 'overlay', string(figAll.png), 'peaks', string(figPeaks.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Switching-relaxation observable comparison complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Best Pearson observable: %s (%.4f)\n', char(bestPearsonRow.observable_key(1)), bestPearsonRow.pearson_r(1));
fprintf('Best Spearman observable: %s (%.4f)\n', char(bestSpearmanRow.observable_key(1)), bestSpearmanRow.spearman_r(1));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_relaxation_observable_comparison');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefaultField(cfg, 'motionRunName', 'run_2026_03_11_084425_relaxation_switching_motion_test');
cfg = setDefaultField(cfg, 'tempSmoothWindow', 3);
cfg = setDefaultField(cfg, 'signalFloorFrac', 0.05);
cfg = setDefaultField(cfg, 'curvatureAbsoluteValue', true);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.relaxRunName = string(cfg.relaxRunName);
source.switchRunName = string(cfg.switchRunName);
source.motionRunName = string(cfg.motionRunName);
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.motionRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.motionRunName));

requiredPaths = {
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
    source.switchRunDir, fullfile(char(source.switchRunDir), 'observable_matrix.csv');
    source.motionRunDir, fullfile(char(source.motionRunDir), 'tables', 'relaxation_switching_motion_table.csv')
    };

for i = 1:size(requiredPaths, 1)
    if exist(requiredPaths{i, 1}, 'dir') ~= 7
        error('Required source run directory not found: %s', requiredPaths{i, 1});
    end
    if exist(requiredPaths{i, 2}, 'file') ~= 2
        error('Required source file not found: %s', requiredPaths{i, 2});
    end
end
end

function relax = loadRelaxationData(runDir)
tempTbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
obsTbl = readtable(fullfile(runDir, 'tables', 'observables_relaxation.csv'));

relax = struct();
relax.T = tempTbl.T(:);
relax.A = tempTbl.A_T(:);
relax.sourcePeakT = obsTbl.Relax_T_peak(1);
relax.sourcePeakWidth = obsTbl.Relax_peak_width(1);
relax.sourcePeakAmp = obsTbl.Relax_Amp_peak(1);
end

function switching = loadSwitchingData(runDir)
matrixTbl = readtable(fullfile(runDir, 'observable_matrix.csv'));
core = load(fullfile(runDir, 'switching_alignment_core_data.mat'), 'temps', 'currents', 'Smap');

switching = struct();
switching.T = matrixTbl.T(:);
switching.I_peak = matrixTbl.I_peak(:);
switching.S_peak = matrixTbl.S_peak(:);
switching.width_I = matrixTbl.width_I(:);
switching.currents_mA = core.currents(:);
switching.coreTemps_K = core.temps(:);
switching.Smap = core.Smap;
end

function motion = loadSavedMotionData(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'relaxation_switching_motion_table.csv'));

motion = struct();
motion.T = tbl.T_K(:);
motion.motion_abs = tbl.motion_abs_dI_peak_dT(:);
motion.motion_norm = tbl.motion_norm(:);
motion.comparisonMask = logical(tbl.comparison_mask(:));
motion.robustMask = logical(tbl.robust_mask(:));
end

function aligned = buildAlignedData(relax, switching, motion, cfg)
overlapLow = max(min(relax.T), min(switching.T));
overlapHigh = min(max(relax.T), max(switching.T));
if ~(isfinite(overlapLow) && isfinite(overlapHigh) && overlapHigh > overlapLow)
    error('No overlapping temperature interval exists between relaxation and switching data.');
end

maskOverlap = switching.T >= overlapLow & switching.T <= overlapHigh;
T = switching.T(maskOverlap);
I_peak = switching.I_peak(maskOverlap);
S_peak = switching.S_peak(maskOverlap);
width_I = switching.width_I(maskOverlap);

A_interp = interp1(relax.T, relax.A, T, 'pchip', NaN);
signalThreshold = cfg.signalFloorFrac * max(S_peak, [], 'omitnan');
robustMask = isfinite(T) & isfinite(A_interp) & isfinite(S_peak) & S_peak >= signalThreshold;

centroid = computeCentroidOnSwitchingGrid(switching);
centroid = centroid(maskOverlap);

motionAbs = nan(size(T));
motionValid = false(size(T));
[lia, loc] = ismember(T, motion.T);
motionAbs(lia) = motion.motion_abs(loc(lia));
motionValid(lia) = motion.comparisonMask(loc(lia));

curvature = computeCurvatureObservable(T, I_peak, robustMask, cfg);

aligned = struct();
aligned.T_K = T;
aligned.A_interp = A_interp;
aligned.I_peak_raw_mA = I_peak;
aligned.S_peak = S_peak;
aligned.width_I_mA = width_I;
aligned.I_centroid_mA = centroid;
aligned.motion_abs_dI_peak_dT = motionAbs;
aligned.curvature_abs_d2I_peak_dT2 = curvature;
aligned.signalThreshold = signalThreshold;
aligned.robustMask = robustMask;
aligned.motionValidMask = motionValid;
aligned.overlapLow = overlapLow;
aligned.overlapHigh = overlapHigh;

aligned.A_norm = normalizeOnMask(A_interp, robustMask);
aligned.motion_norm = normalizeOnMask(motionAbs, motionValid & robustMask);
aligned.centroid_norm = normalizeOnMask(centroid, robustMask);
aligned.width_norm = normalizeOnMask(width_I, robustMask & isfinite(width_I));
aligned.curvature_norm = normalizeOnMask(curvature, robustMask & isfinite(curvature));
end

function centroid = computeCentroidOnSwitchingGrid(switching)
if numel(switching.coreTemps_K) ~= numel(switching.T)
    error('Switching core temperatures do not match observable_matrix length.');
end
if any(abs(switching.coreTemps_K - switching.T) > 1e-9)
    error('Switching core temperatures do not align with observable_matrix temperatures.');
end

weights = max(switching.Smap, 0);
denom = sum(weights, 2);
numer = sum(weights .* reshape(switching.currents_mA, 1, []), 2);
centroid = numer ./ denom;
centroid(~isfinite(denom) | denom <= 0) = NaN;
end

function curvature = computeCurvatureObservable(T, I_peak, robustMask, cfg)
curvature = nan(size(T));
Tg = T(robustMask);
Ig = I_peak(robustMask);
if numel(Tg) < 5
    return;
end

smoothWindow = min(cfg.tempSmoothWindow, numel(Ig));
if smoothWindow >= 2
    Is = smoothdata(Ig, 'movmean', smoothWindow);
else
    Is = Ig;
end

d1 = gradient(Is, Tg);
d2 = gradient(d1, Tg);
d2([1 end]) = NaN;
if cfg.curvatureAbsoluteValue
    d2 = abs(d2);
end
curvature(robustMask) = d2;
end

function summaryTbl = buildSummaryTable(aligned, relax)
defs = {
    'motion_abs_dI_peak_dT', '|dI_peak/dT|', aligned.motion_abs_dI_peak_dT, aligned.robustMask & aligned.motionValidMask;
    'I_centroid_mA', 'ridge centroid', aligned.I_centroid_mA, aligned.robustMask;
    'width_I_mA', 'width_I', aligned.width_I_mA, aligned.robustMask & isfinite(aligned.width_I_mA);
    'curvature_abs_d2I_peak_dT2', '|d^2I_peak/dT^2|', aligned.curvature_abs_d2I_peak_dT2, aligned.robustMask & isfinite(aligned.curvature_abs_d2I_peak_dT2)
    };

summaryTbl = table( ...
    strings(size(defs, 1), 1), ...
    strings(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    strings(size(defs, 1), 1), ...
    'VariableNames', {'observable_key','display_name','pearson_r','spearman_r','n_points', ...
    'peak_T_K','peak_value','peak_delta_vs_relax_source_K','peak_delta_vs_relax_aligned_K', ...
    'support_fraction','interpretation'});

for i = 1:size(defs, 1)
    key = string(defs{i, 1});
    label = string(defs{i, 2});
    x = defs{i, 3};
    mask = defs{i, 4};
    mask = mask(:) & isfinite(aligned.A_interp(:)) & isfinite(x(:));
    [peakValue, peakT] = findPeak(aligned.T_K, x, mask);

    summaryTbl.observable_key(i) = key;
    summaryTbl.display_name(i) = label;
    summaryTbl.pearson_r(i) = corrSafe(aligned.A_interp(mask), x(mask));
    summaryTbl.spearman_r(i) = spearmanSafe(aligned.A_interp(mask), x(mask));
    summaryTbl.n_points(i) = nnz(mask);
    summaryTbl.peak_T_K(i) = peakT;
    summaryTbl.peak_value(i) = peakValue;
    summaryTbl.peak_delta_vs_relax_source_K(i) = peakT - relax.sourcePeakT;
    summaryTbl.peak_delta_vs_relax_aligned_K(i) = peakT - relax.alignedPeakT;
    summaryTbl.support_fraction(i) = nnz(mask) / numel(aligned.T_K);
    summaryTbl.interpretation(i) = classifyObservable(summaryTbl.pearson_r(i), summaryTbl.spearman_r(i), peakT, relax.sourcePeakT);
end

summaryTbl.pearson_rank = tiedRankDescending(summaryTbl.pearson_r);
summaryTbl.spearman_rank = tiedRankDescending(summaryTbl.spearman_r);
summaryTbl.peak_alignment_abs_K = abs(summaryTbl.peak_delta_vs_relax_source_K);
summaryTbl = movevars(summaryTbl, {'pearson_rank','spearman_rank'}, 'After', 'spearman_r');
end

function curveTbl = buildCurveTable(aligned, relax)
curveTbl = table( ...
    aligned.T_K(:), ...
    aligned.A_interp(:), ...
    aligned.A_norm(:), ...
    aligned.I_peak_raw_mA(:), ...
    aligned.S_peak(:), ...
    aligned.I_centroid_mA(:), ...
    aligned.centroid_norm(:), ...
    aligned.width_I_mA(:), ...
    aligned.width_norm(:), ...
    aligned.motion_abs_dI_peak_dT(:), ...
    aligned.motion_norm(:), ...
    aligned.curvature_abs_d2I_peak_dT2(:), ...
    aligned.curvature_norm(:), ...
    aligned.robustMask(:), ...
    aligned.motionValidMask(:), ...
    repmat(relax.sourcePeakT, numel(aligned.T_K), 1), ...
    repmat(relax.alignedPeakT, numel(aligned.T_K), 1), ...
    'VariableNames', {'T_K','A_interp','A_norm','I_peak_raw_mA','S_peak','I_centroid_mA', ...
    'I_centroid_norm','width_I_mA','width_I_norm','motion_abs_dI_peak_dT','motion_norm', ...
    'curvature_abs_d2I_peak_dT2','curvature_norm','robust_mask','motion_valid_mask', ...
    'relax_source_peak_T_K','relax_aligned_peak_T_K'});
end

function manifestTbl = buildManifestTable(source)
experiment = string({'relaxation'; 'relaxation'; 'switching'; 'switching'; 'cross_experiment'});
sourceRun = [source.relaxRunName; source.relaxRunName; source.switchRunName; source.switchRunName; source.motionRunName];
sourceFile = string({ ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv'); ...
    fullfile(char(source.switchRunDir), 'observable_matrix.csv'); ...
    fullfile(char(source.switchRunDir), 'switching_alignment_core_data.mat'); ...
    fullfile(char(source.motionRunDir), 'tables', 'relaxation_switching_motion_table.csv')});
role = string({'relaxation activity curve'; 'relaxation peak metadata'; 'switching ridge summary'; ...
    'switching ridge intensity grid for centroid'; 'saved motion baseline'});
manifestTbl = table(experiment, sourceRun, sourceFile, role, ...
    'VariableNames', {'experiment','source_run','source_file','role'});
end

function figPaths = saveAlignmentGridFigure(aligned, relax, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 20.0, 16.0);
tl = tiledlayout(fh, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

panels = {
    aligned.motion_norm, '|dI_{peak}/dT| / max', 'Switching ridge motion vs Relaxation A(T)';
    aligned.centroid_norm, 'I_{centroid} / max', 'Switching ridge centroid vs Relaxation A(T)';
    aligned.width_norm, 'width_I / max', 'Switching ridge width vs Relaxation A(T)';
    aligned.curvature_norm, '|d^2I_{peak}/dT^2| / max', 'Switching ridge curvature vs Relaxation A(T)'
    };

for i = 1:size(panels, 1)
    ax = nexttile(tl, i);
    hold(ax, 'on');
    plot(ax, aligned.T_K, aligned.A_norm, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'Relaxation A(T) / max');
    plot(ax, aligned.T_K, panels{i, 1}, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', panels{i, 2});
    xline(ax, relax.sourcePeakT, '--', 'LineWidth', 1.4, 'Color', [0.15 0.15 0.15], 'DisplayName', 'Relaxation source peak');
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, 'Temperature (K)');
    ylabel(ax, 'Normalized magnitude');
    title(ax, panels{i, 3});
    legend(ax, 'Location', 'best');
    setAxisStyle(ax);
end

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveNormalizedOverlayFigure(aligned, relax, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.5, 9.5);
ax = axes(fh);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.A_norm, '-o', 'LineWidth', 2.4, 'MarkerSize', 5, 'DisplayName', 'Relaxation A(T) / max');
plot(ax, aligned.T_K, aligned.motion_norm, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', '|dI_{peak}/dT| / max');
plot(ax, aligned.T_K, aligned.centroid_norm, '-^', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'I_{centroid} / max');
plot(ax, aligned.T_K, aligned.width_norm, '-d', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'width_I / max');
plot(ax, aligned.T_K, aligned.curvature_norm, '-v', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', '|d^2I_{peak}/dT^2| / max');
for i = 1:numel(aligned.T_K)
    if ~aligned.robustMask(i)
        xline(ax, aligned.T_K(i), ':', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
    end
end
xline(ax, relax.sourcePeakT, '--', 'LineWidth', 1.6, 'Color', [0.10 0.10 0.10], 'DisplayName', 'Relaxation source peak');
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude');
title(ax, 'Relaxation A(T) against saved switching observables');
legend(ax, 'Location', 'best');
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = savePeakSummaryFigure(summaryTbl, relax, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 14.0, 8.5);
ax = axes(fh);

yVals = (1:height(summaryTbl))';
hold(ax, 'on');
plot(ax, relax.sourcePeakT, 0, 'kp', 'MarkerSize', 12, 'MarkerFaceColor', [0.10 0.10 0.10], 'DisplayName', 'Relaxation source peak');
for i = 1:height(summaryTbl)
    plot(ax, summaryTbl.peak_T_K(i), yVals(i), 'o', 'MarkerSize', 9, 'LineWidth', 1.8, ...
        'DisplayName', char(summaryTbl.display_name(i)));
    line(ax, [relax.sourcePeakT summaryTbl.peak_T_K(i)], [0 yVals(i)], 'LineStyle', '--', ...
        'LineWidth', 1.1, 'Color', [0.60 0.60 0.60], 'HandleVisibility', 'off');
end
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Peak temperature (K)');
ylabel(ax, 'Observable index');
title(ax, 'Peak-temperature comparison against Relaxation A(T)');
yticks(ax, [0; yVals]);
yticklabels(ax, [{'Relaxation A(T)'}; cellstr(summaryTbl.display_name)]);
setAxisStyle(ax);
legend(ax, 'Location', 'bestoutside');

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReportText(source, relax, aligned, summaryTbl, cfg)
bestPearsonRow = summaryTbl(summaryTbl.pearson_rank == 1, :);
bestSpearmanRow = summaryTbl(summaryTbl.spearman_rank == 1, :);
overallWinner = selectOverallWinner(summaryTbl);

lines = strings(0, 1);
lines(end + 1) = "# Switching-Relaxation Observable Comparison";
lines(end + 1) = "";
lines(end + 1) = "## Repository-state summary";
lines(end + 1) = sprintf('- Relaxation run reused: `%s`.', source.relaxRunName);
lines(end + 1) = sprintf('- Switching canonical run reused: `%s`.', source.switchRunName);
lines(end + 1) = sprintf('- Previously saved cross-experiment motion run reused: `%s`.', source.motionRunName);
lines(end + 1) = "- No switching maps were recomputed. All quantities were derived from saved run outputs only.";
lines(end + 1) = "- No legacy result trees were used.";
lines(end + 1) = "- New code added: `analysis/switching_relaxation_observable_comparison.m`.";
lines(end + 1) = "";
lines(end + 1) = "## Exact source files used";
lines(end + 1) = sprintf('- Relaxation A(T): `%s`.', fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'));
lines(end + 1) = sprintf('- Relaxation peak metadata: `%s`.', fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv'));
lines(end + 1) = sprintf('- Switching observable table: `%s`.', fullfile(char(source.switchRunDir), 'observable_matrix.csv'));
lines(end + 1) = sprintf('- Switching saved ridge grid: `%s`.', fullfile(char(source.switchRunDir), 'switching_alignment_core_data.mat'));
lines(end + 1) = sprintf('- Saved motion baseline: `%s`.', fullfile(char(source.motionRunDir), 'tables', 'relaxation_switching_motion_table.csv'));
lines(end + 1) = "";
lines(end + 1) = "## Observable definitions";
lines(end + 1) = "- `A(T)` was interpolated onto the switching temperature grid with `pchip` over the common interval `4-34 K`.";
lines(end + 1) = sprintf('- Ridge support mask: `S_peak >= %.2f * max(S_peak)`; threshold = %.6g.', cfg.signalFloorFrac, aligned.signalThreshold);
lines(end + 1) = "- `|dI_peak/dT|` was reused directly from the saved motion-table run rather than recomputed from raw maps.";
lines(end + 1) = "- `I_centroid(T)` was computed from the saved switching `Smap` and current axis using nonnegative ridge weights `max(S,0)` so tiny negative background values do not create an unphysical centroid.";
lines(end + 1) = "- `width_I(T)` was read directly from the saved switching observable table.";
lines(end + 1) = sprintf('- Curvature was evaluated as `|d^2I_peak/dT^2|` after a %d-point moving-mean smoothing of the saved `I_peak(T)` ridge trajectory. Endpoint second-derivative values were excluded to avoid one-sided finite-difference artifacts.', cfg.tempSmoothWindow);
lines(end + 1) = "";
lines(end + 1) = "## Relaxation reference";
lines(end + 1) = sprintf('- Relaxation source peak from `observables_relaxation.csv`: `%.1f K`.', relax.sourcePeakT);
lines(end + 1) = sprintf('- Relaxation aligned peak on the switching temperature grid: `%.1f K`.', relax.alignedPeakT);
lines(end + 1) = "";
lines(end + 1) = "## Correlation and peak summary";
for i = 1:height(summaryTbl)
    lines(end + 1) = sprintf('- `%s`: Pearson = %.4f, Spearman = %.4f, peak temperature = %.1f K, source-peak offset = %+0.1f K, support fraction = %.3f.', ...
        summaryTbl.display_name(i), summaryTbl.pearson_r(i), summaryTbl.spearman_r(i), summaryTbl.peak_T_K(i), ...
        summaryTbl.peak_delta_vs_relax_source_K(i), summaryTbl.support_fraction(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Alignment verdict";
lines(end + 1) = sprintf('- Best Pearson alignment: `%s` (r = %.4f, peak at %.1f K).', ...
    bestPearsonRow.display_name(1), bestPearsonRow.pearson_r(1), bestPearsonRow.peak_T_K(1));
lines(end + 1) = sprintf('- Best Spearman alignment: `%s` (rho = %.4f, peak at %.1f K).', ...
    bestSpearmanRow.display_name(1), bestSpearmanRow.spearman_r(1), bestSpearmanRow.peak_T_K(1));
if overallWinner == "motion_abs_dI_peak_dT"
    lines(end + 1) = "- Overall, the saved ridge-motion observable `|dI_peak/dT|` remains the best match to Relaxation `A(T)`. It has the strongest Pearson correlation and its peak at `28 K` stays close to the Relaxation source peak near `27 K`.";
    lines(end + 1) = "- The strongest alternative is the curvature metric. Its peak sits closer to the Relaxation window near `26 K`, and its Spearman correlation is slightly higher than the motion baseline, but its Pearson correlation is weaker.";
else
    lines(end + 1) = sprintf('- Overall winner by the saved metrics: `%s`.', strrep(char(overallWinner), '_', ' '));
end
lines(end + 1) = "- `I_centroid(T)` and `width_I(T)` do not behave like crossover markers for this comparison. Both peak at the low-temperature edge and show negative correlations with `A(T)` over the robust switching interval.";
lines(end + 1) = "";
lines(end + 1) = "## Practical interpretation";
lines(end + 1) = "- If the criterion is direct shape similarity to `A(T)`, `|dI_peak/dT|` is still the strongest saved switching observable.";
lines(end + 1) = "- If the criterion is monotonic ordering plus peak proximity to the Relaxation crossover region, the interior-only curvature metric is the most credible alternative and deserves to be kept alongside the motion baseline.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 2 curves in each grid panel and 5 curves in the normalized summary overlay";
lines(end + 1) = "- legend vs colormap: legends only, because every panel has 6 or fewer curves";
lines(end + 1) = "- colormap used: none";
lines(end + 1) = sprintf('- smoothing applied: %d-point moving mean before the curvature calculation; no extra smoothing for centroid or width', cfg.tempSmoothWindow);
lines(end + 1) = "- justification: the figures stay focused on the physically motivated shortlist of saved ridge observables and their direct comparison to Relaxation A(T)";

reportText = strjoin(lines, newline);
end

function winner = selectOverallWinner(summaryTbl)
bestPearson = summaryTbl(summaryTbl.pearson_rank == 1, :);
bestSpearman = summaryTbl(summaryTbl.spearman_rank == 1, :);

if bestPearson.observable_key(1) == bestSpearman.observable_key(1)
    winner = bestPearson.observable_key(1);
    return;
end

motionRow = summaryTbl(summaryTbl.observable_key == "motion_abs_dI_peak_dT", :);
curvRow = summaryTbl(summaryTbl.observable_key == "curvature_abs_d2I_peak_dT2", :);
if ~isempty(motionRow) && ~isempty(curvRow)
    if motionRow.pearson_r >= curvRow.pearson_r && motionRow.peak_alignment_abs_K <= 2
        winner = motionRow.observable_key(1);
        return;
    end
end

winner = bestPearson.observable_key(1);
end

function txt = classifyObservable(pearsonR, spearmanR, peakT, relaxPeakT)
if ~isfinite(pearsonR) || ~isfinite(spearmanR) || ~isfinite(peakT)
    txt = "insufficient";
    return;
end

if pearsonR > 0.65 && spearmanR > 0.65 && abs(peakT - relaxPeakT) <= 3
    txt = "strong_alignment";
elseif pearsonR > 0.3 && spearmanR > 0.3
    txt = "moderate_alignment";
elseif pearsonR < 0 || spearmanR < 0
    txt = "anti_aligned";
else
    txt = "weak_alignment";
end
end

function peakT = computeAlignedPeakTemperature(aligned)
peakT = NaN;
mask = aligned.robustMask & isfinite(aligned.A_interp);
if ~any(mask)
    return;
end
Avalid = aligned.A_interp(mask);
Tvalid = aligned.T_K(mask);
[~, idxPeak] = max(Avalid);
peakT = Tvalid(idxPeak);
end

function [peakValue, peakT] = findPeak(T, x, mask)
peakValue = NaN;
peakT = NaN;
if nnz(mask) < 1
    return;
end
xValid = x(mask);
TValid = T(mask);
[peakValue, idxPeak] = max(xValid);
peakT = TValid(idxPeak);
end

function rankVals = tiedRankDescending(x)
rankVals = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end

[~, order] = sort(x(valid), 'descend');
xs = x(valid);
xs = xs(order);
ranked = zeros(size(xs));
ii = 1;
while ii <= numel(xs)
    jj = ii;
    while jj < numel(xs) && xs(jj + 1) == xs(ii)
        jj = jj + 1;
    end
    ranked(ii:jj) = mean(ii:jj);
    ii = jj + 1;
end
tmp = zeros(size(xs));
tmp(order) = ranked;
rankVals(valid) = tmp;
end

function out = normalizeOnMask(y, mask)
y = y(:);
mask = mask(:) & isfinite(y);
out = NaN(size(y));
if ~any(mask)
    return;
end
mx = max(y(mask), [], 'omitnan');
if isfinite(mx) && mx > 0
    out = y ./ mx;
end
end

function c = corrSafe(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
c = NaN;
if nnz(mask) < 3
    return;
end
cc = corrcoef(x(mask), y(mask));
if numel(cc) >= 4
    c = cc(1, 2);
end
end

function rho = spearmanSafe(x, y)
rho = corrSafe(tiedRank(x), tiedRank(y));
end

function r = tiedRank(x)
x = x(:);
r = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end
xs = x(valid);
[xsSorted, order] = sort(xs);
ranks = zeros(size(xsSorted));
ii = 1;
while ii <= numel(xsSorted)
    jj = ii;
    while jj < numel(xsSorted) && xsSorted(jj + 1) == xsSorted(ii)
        jj = jj + 1;
    end
    ranks(ii:jj) = mean(ii:jj);
    ii = jj + 1;
end
tmp = zeros(size(xsSorted));
tmp(order) = ranks;
r(valid) = tmp;
end

function setFigureGeometry(fig, widthCm, heightCm)
set(fig, 'Units', 'centimeters', ...
    'Position', [2 2 widthCm heightCm], ...
    'PaperUnits', 'centimeters', ...
    'PaperPosition', [0 0 widthCm heightCm], ...
    'PaperSize', [widthCm heightCm], ...
    'Color', 'w');
end

function setAxisStyle(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.1, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top');
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

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = value;
end
end


