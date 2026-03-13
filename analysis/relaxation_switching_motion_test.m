function out = relaxation_switching_motion_test(cfg)
% relaxation_switching_motion_test
% Cross-experiment analysis testing whether the Relaxation A(T) peak aligns
% with maximal switching ridge motion |dI_peak/dT|.

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
source = resolveSourceRuns(repoRoot);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | switch:%s', char(source.relaxRunName), char(source.switchRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Relaxation-switching motion test run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Switching source run: %s\n', source.switchRunName);

appendText(run.log_path, sprintf('[%s] relaxation-switching motion test started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));

relax = loadRelaxationData(source.relaxRunDir);
switching = loadSwitchingData(source.switchRunDir, cfg);
aligned = alignAndComputeMotion(relax, switching, cfg);
features = extractFeatureSet(relax, aligned, cfg);
pairTbl = buildPairwiseTable(aligned, features);
curveTbl = buildCurveTable(aligned);
featureTbl = buildFeatureTable(features);

curvePath = save_run_table(curveTbl, 'relaxation_switching_motion_table.csv', runDir);
featurePath = save_run_table(featureTbl, 'relaxation_switching_feature_summary.csv', runDir);
pairPath = save_run_table(pairTbl, 'relaxation_switching_correlations.csv', runDir);

figMotion = saveRelaxationVsMotionFigure(aligned, features, runDir, 'relaxation_vs_motion_overlay');
figSpeak = saveRelaxationVsSwitchingAmplitudeFigure(aligned, features, runDir, 'relaxation_vs_switching_amplitude_overlay');
figRidge = saveRidgeMotionFigure(aligned, cfg, runDir, 'ridge_motion_vs_temperature');

reportText = buildReport(source, relax, switching, aligned, features, pairTbl, cfg);
reportPath = save_run_report(reportText, 'relaxation_switching_motion_analysis.md', runDir);
zipPath = buildReviewZip(runDir, 'relaxation_switching_motion_analysis.zip');

appendText(run.log_path, sprintf('[%s] relaxation-switching motion test complete\n', stampNow()));
appendText(run.log_path, sprintf('Curve table: %s\n', curvePath));
appendText(run.log_path, sprintf('Feature table: %s\n', featurePath));
appendText(run.log_path, sprintf('Correlation table: %s\n', pairPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

motionPair = pairTbl(pairTbl.pair_name == "A_vs_motion", :);
ampPair = pairTbl(pairTbl.pair_name == "A_vs_S_peak", :);
appendText(run.notes_path, sprintf('Relaxation source peak from run = %.6g K\n', relax.sourcePeakT));
appendText(run.notes_path, sprintf('Aligned A(T) peak = %.6g K\n', features.A.peak_T_K));
appendText(run.notes_path, sprintf('Motion peak = %.6g K\n', features.motion.peak_T_K));
appendText(run.notes_path, sprintf('S_peak peak = %.6g K\n', features.S_peak.peak_T_K));
appendText(run.notes_path, sprintf('corr(A,motion) Pearson/Spearman = %.6g / %.6g\n', motionPair.pearson_r, motionPair.spearman_r));
appendText(run.notes_path, sprintf('corr(A,S_peak) Pearson/Spearman = %.6g / %.6g\n', ampPair.pearson_r, ampPair.spearman_r));
appendText(run.notes_path, sprintf('hypothesis_verdict = %s\n', char(features.hypothesisVerdict)));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.relax = relax;
out.switching = switching;
out.aligned = aligned;
out.features = features;
out.tables = struct('curve', string(curvePath), 'feature', string(featurePath), 'pairwise', string(pairPath));
out.figures = struct('motion_overlay', string(figMotion.png), 'amplitude_overlay', string(figSpeak.png), 'ridge_motion', string(figRidge.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Relaxation-switching motion test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('corr(A,motion) = %.6f | corr(A,S_peak) = %.6f\n', motionPair.pearson_r, ampPair.pearson_r);
fprintf('Motion peak T = %.3f K | Relaxation peak T (aligned) = %.3f K\n', features.motion.peak_T_K, features.A.peak_T_K);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'relaxation_switching_motion_test');
cfg = setDefaultField(cfg, 'tempSmoothWindow', 3);
cfg = setDefaultField(cfg, 'signalFloorFrac', 0.05);
cfg = setDefaultField(cfg, 'significantRiseFraction', 0.10);
cfg = setDefaultField(cfg, 'peakAlignmentToleranceK', 3);
cfg = setDefaultField(cfg, 'windowOverlapSupport', 0.35);
cfg = setDefaultField(cfg, 'broadWindowFraction', 0.60);
end

function source = resolveSourceRuns(repoRoot)
source = struct();
source.relaxRunDir = findLatestRelaxationRun(repoRoot);
source.relaxRunName = string(filepartsToName(source.relaxRunDir));
source.switchRunDir = findLatestSwitchingRun(repoRoot);
source.switchRunName = string(filepartsToName(source.switchRunDir));
end

function runDir = findLatestRelaxationRun(repoRoot)
runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
runDir = findLatestMatchingRun(runsRoot, @relaxationRunMatches);
if strlength(runDir) == 0
    error('No relaxation run containing A(T) could be found under %s', runsRoot);
end
end

function runDir = findLatestSwitchingRun(repoRoot)
runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');
runDir = findLatestMatchingRun(runsRoot, @switchingRunMatches);
if strlength(runDir) == 0
    error('No switching run containing I_peak(T) and S_peak(T) could be found under %s', runsRoot);
end
end

function runDir = findLatestMatchingRun(runsRoot, predicate)
runDir = "";
entries = dir(fullfile(runsRoot, 'run_*'));
entries = entries([entries.isdir]);
if isempty(entries)
    return;
end

names = string({entries.name});
keep = ~startsWith(names, "run_legacy", 'IgnoreCase', true);
entries = entries(keep);
if isempty(entries)
    return;
end

[~, order] = sort({entries.name});
entries = entries(order);

for i = numel(entries):-1:1
    candidate = fullfile(entries(i).folder, entries(i).name);
    if predicate(candidate)
        runDir = string(candidate);
        return;
    end
end
end

function tf = relaxationRunMatches(runDir)
tempPath = fullfile(runDir, 'tables', 'temperature_observables.csv');
obsPath = fullfile(runDir, 'tables', 'observables_relaxation.csv');
if exist(tempPath, 'file') ~= 2 || exist(obsPath, 'file') ~= 2
    tf = false;
    return;
end
try
    tempTbl = readtable(tempPath);
    obsTbl = readtable(obsPath);
catch
    tf = false;
    return;
end
varsTemp = string(tempTbl.Properties.VariableNames);
varsObs = string(obsTbl.Properties.VariableNames);
tf = ismember("T", varsTemp) && ismember("A_T", varsTemp) && ismember("Relax_T_peak", varsObs);
end

function tf = switchingRunMatches(runDir)
matrixPath = fullfile(runDir, 'observable_matrix.csv');
obsPath = fullfile(runDir, 'observables.csv');
if exist(matrixPath, 'file') ~= 2 || exist(obsPath, 'file') ~= 2
    tf = false;
    return;
end
try
    matrixTbl = readtable(matrixPath);
catch
    tf = false;
    return;
end
vars = string(matrixTbl.Properties.VariableNames);
tf = all(ismember(["T","I_peak","S_peak"], vars));
end

function name = filepartsToName(pathStr)
[~, name] = fileparts(char(pathStr));
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

function switching = loadSwitchingData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'observable_matrix.csv'));

switching = struct();
switching.T = tbl.T(:);
switching.I_peak = tbl.I_peak(:);
switching.S_peak = tbl.S_peak(:);
switching.signalThreshold = cfg.signalFloorFrac * max(switching.S_peak, [], 'omitnan');
switching.robustMask = isfinite(switching.T) & isfinite(switching.I_peak) & isfinite(switching.S_peak) & switching.S_peak >= switching.signalThreshold;
end

function aligned = alignAndComputeMotion(relax, switching, cfg)
overlapLow = max(min(relax.T), min(switching.T));
overlapHigh = min(max(relax.T), max(switching.T));
if ~(isfinite(overlapLow) && isfinite(overlapHigh) && overlapHigh > overlapLow)
    error('No overlapping temperature interval exists between relaxation and switching data.');
end

overlapMask = switching.T >= overlapLow & switching.T <= overlapHigh;
if ~any(overlapMask)
    error('No switching points remain in the overlapping temperature interval.');
end

aligned = struct();
aligned.T_K = switching.T(overlapMask);
aligned.I_peak_raw_mA = switching.I_peak(overlapMask);
aligned.S_peak = switching.S_peak(overlapMask);
aligned.A_interp = interp1(relax.T, relax.A, aligned.T_K, 'pchip', NaN);
aligned.robustMask = switching.robustMask(overlapMask) & isfinite(aligned.A_interp);
aligned.signalThreshold = switching.signalThreshold;
aligned.overlapLow = overlapLow;
aligned.overlapHigh = overlapHigh;

aligned.I_peak_smooth_mA = NaN(size(aligned.T_K));
aligned.dI_peak_dT_raw = NaN(size(aligned.T_K));
aligned.dI_peak_dT = NaN(size(aligned.T_K));
aligned.motion = NaN(size(aligned.T_K));

Tg = aligned.T_K(aligned.robustMask);
Ig = aligned.I_peak_raw_mA(aligned.robustMask);
if numel(Tg) >= 2
    if cfg.tempSmoothWindow >= 2
        Is = smoothdata(Ig, 'movmean', min(cfg.tempSmoothWindow, numel(Ig)));
    else
        Is = Ig;
    end
    aligned.I_peak_smooth_mA(aligned.robustMask) = Is;
    aligned.dI_peak_dT_raw(aligned.robustMask) = gradient(Ig, Tg);
    aligned.dI_peak_dT(aligned.robustMask) = gradient(Is, Tg);
    aligned.motion(aligned.robustMask) = abs(aligned.dI_peak_dT(aligned.robustMask));
else
    aligned.I_peak_smooth_mA(aligned.robustMask) = Ig;
end

aligned.comparisonMask = aligned.robustMask & isfinite(aligned.motion) & isfinite(aligned.S_peak) & isfinite(aligned.A_interp);
aligned.A_norm = normalizeOnMask(aligned.A_interp, aligned.comparisonMask);
aligned.S_peak_norm = normalizeOnMask(aligned.S_peak, aligned.comparisonMask);
aligned.motion_norm = normalizeOnMask(aligned.motion, aligned.comparisonMask);
end

function features = extractFeatureSet(relax, aligned, cfg)
features = struct();
features.A = computeCurveFeatures("A", aligned.T_K, applyMask(aligned.A_interp, aligned.comparisonMask), cfg);
features.motion = computeCurveFeatures("motion", aligned.T_K, applyMask(aligned.motion, aligned.comparisonMask), cfg);
features.S_peak = computeCurveFeatures("S_peak", aligned.T_K, applyMask(aligned.S_peak, aligned.comparisonMask), cfg);

features.A.source_peak_T_K = relax.sourcePeakT;
features.A.source_peak_width_K = relax.sourcePeakWidth;
features.A.source_peak_amp = relax.sourcePeakAmp;

motionCorr = corrSafe(aligned.A_interp(aligned.comparisonMask), aligned.motion(aligned.comparisonMask));
ampCorr = corrSafe(aligned.A_interp(aligned.comparisonMask), aligned.S_peak(aligned.comparisonMask));
motionPair = comparePair("A_vs_motion", features.A, features.motion, aligned.T_K, aligned.A_interp, aligned.motion, aligned.comparisonMask);
ampPair = comparePair("A_vs_S_peak", features.A, features.S_peak, aligned.T_K, aligned.A_interp, aligned.S_peak, aligned.comparisonMask);

features.pairs = [motionPair; ampPair];
features.motionStronger = isfinite(motionCorr) && isfinite(ampCorr) && motionCorr > ampCorr;
features.windowStyle = classifyWindowStyle(features.A, features.motion, motionPair, cfg);
features.hypothesisVerdict = classifyHypothesis(motionPair, ampPair, features, cfg);
end

function yMasked = applyMask(y, mask)
yMasked = y(:);
yMasked(~mask(:)) = NaN;
end

function feat = computeCurveFeatures(name, T, y, cfg)
T = T(:);
y = y(:);
mask = isfinite(T) & isfinite(y);
T = T(mask);
y = y(mask);

feat = struct();
feat.observable = string(name);
feat.n_points = numel(T);
feat.peak_T_K = NaN;
feat.peak_value = NaN;
feat.FWHM_low_K = NaN;
feat.FWHM_high_K = NaN;
feat.FWHM_width_K = NaN;
feat.onset_T_K = NaN;
feat.decay_T_K = NaN;
feat.centroid_T_K = NaN;
feat.area = NaN;

if isempty(T)
    return;
end

[feat.peak_value, idxPeak] = max(y);
if isfinite(feat.peak_value)
    feat.peak_T_K = T(idxPeak);
end

[feat.FWHM_low_K, feat.FWHM_high_K, feat.FWHM_width_K, peakHalf] = computeHalfMaxWindow(T, y);
if isfinite(peakHalf)
    feat.peak_T_K = peakHalf;
end

yNorm = normalizePositive(y);
if any(isfinite(yNorm))
    leftIdx = find(yNorm(1:idxPeak) >= cfg.significantRiseFraction, 1, 'first');
    if ~isempty(leftIdx)
        feat.onset_T_K = T(leftIdx);
    end
    rightRel = find(yNorm(idxPeak:end) >= cfg.significantRiseFraction, 1, 'last');
    if ~isempty(rightRel)
        feat.decay_T_K = T(idxPeak + rightRel - 1);
    end
end

feat.centroid_T_K = weightedCentroid(T, y);
feat.area = positiveArea(T, y);
end

function pair = comparePair(name, featX, featY, T, x, y, mask)
mask = mask(:) & isfinite(T(:)) & isfinite(x(:)) & isfinite(y(:));
pair = struct();
pair.pair_name = string(name);
pair.pearson_r = corrSafe(x(mask), y(mask));
pair.spearman_r = spearmanSafe(x(mask), y(mask));
pair.n_points = nnz(mask);
pair.peak_T_x_K = featX.peak_T_K;
pair.peak_T_y_K = featY.peak_T_K;
pair.peak_alignment_signed_K = featY.peak_T_K - featX.peak_T_K;
pair.peak_alignment_abs_K = abs(pair.peak_alignment_signed_K);
pair.centroid_x_K = featX.centroid_T_K;
pair.centroid_y_K = featY.centroid_T_K;
pair.centroid_diff_signed_K = featY.centroid_T_K - featX.centroid_T_K;
pair.centroid_diff_abs_K = abs(pair.centroid_diff_signed_K);
pair.halfmax_overlap_fraction = intervalOverlap(featX.FWHM_low_K, featX.FWHM_high_K, featY.FWHM_low_K, featY.FWHM_high_K);
pair.window_low_x_K = featX.FWHM_low_K;
pair.window_high_x_K = featX.FWHM_high_K;
pair.window_low_y_K = featY.FWHM_low_K;
pair.window_high_y_K = featY.FWHM_high_K;
end

function tbl = buildCurveTable(aligned)
tbl = table(aligned.T_K(:), aligned.A_interp(:), aligned.A_norm(:), aligned.S_peak(:), aligned.S_peak_norm(:), ...
    aligned.I_peak_raw_mA(:), aligned.I_peak_smooth_mA(:), aligned.dI_peak_dT_raw(:), aligned.dI_peak_dT(:), ...
    aligned.motion(:), aligned.motion_norm(:), aligned.robustMask(:), aligned.comparisonMask(:), ...
    'VariableNames', {'T_K','A_interp','A_norm','S_peak','S_peak_norm','I_peak_raw_mA','I_peak_smooth_mA', ...
    'dI_peak_dT_raw_mA_per_K','dI_peak_dT_smooth_mA_per_K','motion_abs_dI_peak_dT','motion_norm','robust_mask','comparison_mask'});
end

function tbl = buildFeatureTable(features)
curves = {features.A, features.motion, features.S_peak};
tbl = table(strings(numel(curves),1), NaN(numel(curves),1), NaN(numel(curves),1), NaN(numel(curves),1), NaN(numel(curves),1), ...
    NaN(numel(curves),1), NaN(numel(curves),1), NaN(numel(curves),1), NaN(numel(curves),1), NaN(numel(curves),1), ...
    'VariableNames', {'observable','n_points','peak_T_K','peak_value','FWHM_low_K','FWHM_high_K','FWHM_width_K','onset_T_K','decay_T_K','centroid_T_K'});
for i = 1:numel(curves)
    c = curves{i};
    tbl.observable(i) = c.observable;
    tbl.n_points(i) = c.n_points;
    tbl.peak_T_K(i) = c.peak_T_K;
    tbl.peak_value(i) = c.peak_value;
    tbl.FWHM_low_K(i) = c.FWHM_low_K;
    tbl.FWHM_high_K(i) = c.FWHM_high_K;
    tbl.FWHM_width_K(i) = c.FWHM_width_K;
    tbl.onset_T_K(i) = c.onset_T_K;
    tbl.decay_T_K(i) = c.decay_T_K;
    tbl.centroid_T_K(i) = c.centroid_T_K;
end
end

function tbl = buildPairwiseTable(aligned, features)
pairStruct = features.pairs;
tbl = struct2table(pairStruct);
tbl.comparison_T_min_K = repmat(min(aligned.T_K(aligned.comparisonMask)), height(tbl), 1);
tbl.comparison_T_max_K = repmat(max(aligned.T_K(aligned.comparisonMask)), height(tbl), 1);
end

function figPaths = saveRelaxationVsMotionFigure(aligned, features, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 8.6, 6.5);
ax = axes(fh);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.A_norm, '-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'A(T) / max');
plot(ax, aligned.T_K, aligned.motion_norm, '-s', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', '|dI_{peak}/dT| / max');
xline(ax, features.A.peak_T_K, '--', 'LineWidth', 1.4, 'Color', [0.15 0.15 0.15], 'DisplayName', 'A peak');
xline(ax, features.motion.peak_T_K, ':', 'LineWidth', 1.4, 'Color', [0.85 0.33 0.10], 'DisplayName', 'motion peak');
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude');
title(ax, 'Relaxation participation vs switching ridge motion');
legend(ax, 'Location', 'best');
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveRelaxationVsSwitchingAmplitudeFigure(aligned, features, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 8.6, 6.5);
ax = axes(fh);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.A_norm, '-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'A(T) / max');
plot(ax, aligned.T_K, aligned.S_peak_norm, '-s', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'S_{peak}(T) / max');
xline(ax, features.A.peak_T_K, '--', 'LineWidth', 1.4, 'Color', [0.15 0.15 0.15], 'DisplayName', 'A peak');
xline(ax, features.S_peak.peak_T_K, ':', 'LineWidth', 1.4, 'Color', [0.85 0.33 0.10], 'DisplayName', 'S_{peak} peak');
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude');
title(ax, 'Relaxation participation vs switching ridge amplitude');
legend(ax, 'Location', 'best');
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveRidgeMotionFigure(aligned, cfg, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.8, 10.0);
tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, aligned.T_K, aligned.I_peak_raw_mA, '-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'I_{peak}(T)');
plot(ax1, aligned.T_K, aligned.I_peak_smooth_mA, '-s', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', sprintf('smoothed I_{peak} (movmean %d)', cfg.tempSmoothWindow));
hold(ax1, 'off');
grid(ax1, 'on');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'Current (mA)');
title(ax1, 'Switching ridge position vs temperature');
legend(ax1, 'Location', 'best');
setAxisStyle(ax1);

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, aligned.T_K, aligned.dI_peak_dT, '-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', 'dI_{peak}/dT');
plot(ax2, aligned.T_K, aligned.motion, '-s', 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', '|dI_{peak}/dT|');
hold(ax2, 'off');
grid(ax2, 'on');
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, 'Slope (mA/K)');
title(ax2, 'Switching ridge motion observable');
legend(ax2, 'Location', 'best');
setAxisStyle(ax2);

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
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
    'FontSize', 9, ...
    'LineWidth', 1.0, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top');
end

function reportText = buildReport(source, relax, switching, aligned, features, pairTbl, cfg)
motionPair = pairTbl(pairTbl.pair_name == "A_vs_motion", :);
ampPair = pairTbl(pairTbl.pair_name == "A_vs_S_peak", :);

lines = strings(0,1);
lines(end+1) = "# Relaxation-Switching Motion Analysis";
lines(end+1) = "";
lines(end+1) = "## Data sources used";
lines(end+1) = sprintf("- Relaxation run: `%s`", source.relaxRunName);
lines(end+1) = sprintf("- Switching run: `%s`", source.switchRunName);
lines(end+1) = "- Relaxation inputs: `tables/temperature_observables.csv`, `tables/observables_relaxation.csv`.";
lines(end+1) = "- Switching inputs: `observable_matrix.csv`, `observables.csv`.";
lines(end+1) = "";
lines(end+1) = "## Preprocessing";
lines(end+1) = sprintf("- Common temperature axis: switching grid over the overlap interval [%.1f, %.1f] K.", aligned.overlapLow, aligned.overlapHigh);
lines(end+1) = "- Relaxation `A(T)` was interpolated onto the switching temperature grid with `pchip` because the runs use offset temperature samples.";
lines(end+1) = sprintf("- Ridge-motion support mask: `S_peak >= %.2f * max(S_peak)`; threshold = %.6g.", cfg.signalFloorFrac, switching.signalThreshold);
lines(end+1) = sprintf("- Smoothing before differentiation: %d-point moving mean applied to `I_peak(T)` on the robust switching points only.", cfg.tempSmoothWindow);
lines(end+1) = "- Motion observable definition: `motion(T) = |dI_peak/dT|`.";
lines(end+1) = "- Raw slope `dI_peak/dT` was retained alongside the smoothed derivative for reference.";
lines(end+1) = "";
lines(end+1) = "## Extracted feature temperatures";
lines(end+1) = sprintf("- Relaxation source-run peak from `observables_relaxation.csv`: %.3f K with reported width %.3f K.", relax.sourcePeakT, relax.sourcePeakWidth);
lines(end+1) = sprintf("- Aligned `A(T)` peak / onset / decay: %.3f / %.3f / %.3f K.", features.A.peak_T_K, features.A.onset_T_K, features.A.decay_T_K);
lines(end+1) = sprintf("- `motion(T)` peak / onset / decay: %.3f / %.3f / %.3f K.", features.motion.peak_T_K, features.motion.onset_T_K, features.motion.decay_T_K);
lines(end+1) = sprintf("- `S_peak(T)` peak / onset / decay: %.3f / %.3f / %.3f K.", features.S_peak.peak_T_K, features.S_peak.onset_T_K, features.S_peak.decay_T_K);
lines(end+1) = sprintf("- FWHM widths: A(T) = %.3f K, motion(T) = %.3f K, S_peak(T) = %.3f K.", features.A.FWHM_width_K, features.motion.FWHM_width_K, features.S_peak.FWHM_width_K);
lines(end+1) = "";
lines(end+1) = "## Correlation results";
lines(end+1) = sprintf("- `A(T) <-> motion(T)`: Pearson = %.4f, Spearman = %.4f.", motionPair.pearson_r, motionPair.spearman_r);
lines(end+1) = sprintf("- `A(T) <-> S_peak(T)`: Pearson = %.4f, Spearman = %.4f.", ampPair.pearson_r, ampPair.spearman_r);
lines(end+1) = "";
lines(end+1) = "## Window-overlap analysis";
lines(end+1) = sprintf("- Peak alignment A vs motion: signed difference = %.3f K, absolute difference = %.3f K.", motionPair.peak_alignment_signed_K, motionPair.peak_alignment_abs_K);
lines(end+1) = sprintf("- Half-maximum-window overlap A vs motion: %.4f.", motionPair.halfmax_overlap_fraction);
lines(end+1) = sprintf("- Centroid difference A vs motion: signed difference = %.3f K, absolute difference = %.3f K.", motionPair.centroid_diff_signed_K, motionPair.centroid_diff_abs_K);
lines(end+1) = "";
lines(end+1) = "## Summary interpretation";
lines(end+1) = sprintf("1. Ridge motion peak near relaxation peak: **%s**.", yesNoLine(motionPair.peak_alignment_abs_K <= cfg.peakAlignmentToleranceK));
lines(end+1) = sprintf("2. Correlation stronger for `A(T) <-> motion(T)` than for `A(T) <-> S_peak(T)`: **%s**.", yesNoLine(features.motionStronger));
lines(end+1) = sprintf("3. High-motion window overlaps the relaxation window: **%s** (overlap = %.4f).", yesNoLine(motionPair.halfmax_overlap_fraction >= cfg.windowOverlapSupport), motionPair.halfmax_overlap_fraction);
lines(end+1) = sprintf("4. Relationship type: **%s**.", strrep(features.windowStyle, "_", " "));
lines(end+1) = sprintf("- Overall hypothesis verdict: **%s**.", strrep(features.hypothesisVerdict, "_", " "));
if features.hypothesisVerdict == "supported"
    lines(end+1) = "- The stored runs support the hypothesis that the relaxation-participation peak is more closely tied to ridge motion than to switching amplitude.";
elseif features.hypothesisVerdict == "partially_supported"
    lines(end+1) = "- The data show meaningful alignment between relaxation participation and ridge motion, but the agreement is broad rather than a clean one-to-one temperature lock.";
else
    lines(end+1) = "- The ridge motion does not align with the relaxation peak strongly enough to support the hypothesis for these stored runs.";
end
lines(end+1) = "";
lines(end+1) = "## Visualization choices";
lines(end+1) = "- number of curves: 2 curves in each overlay figure and 2 curves per panel in the ridge-motion figure";
lines(end+1) = "- legend vs colormap: legends only, because each panel has 6 or fewer curves";
lines(end+1) = "- colormap used: none";
lines(end+1) = sprintf("- smoothing applied: %d-point moving mean on `I_peak(T)` before computing `dI_peak/dT`", cfg.tempSmoothWindow);
lines(end+1) = "- justification: the figures focus directly on whether the relaxation window aligns with ridge motion rather than with switching amplitude";

reportText = strjoin(lines, newline);
end

function verdict = classifyHypothesis(motionPair, ampPair, features, cfg)
peakAligned = isfinite(motionPair.peak_alignment_abs_K) && motionPair.peak_alignment_abs_K <= cfg.peakAlignmentToleranceK;
overlapStrong = isfinite(motionPair.halfmax_overlap_fraction) && motionPair.halfmax_overlap_fraction >= cfg.windowOverlapSupport;
corrStronger = features.motionStronger;
pearsonPositive = isfinite(motionPair.pearson_r) && motionPair.pearson_r > 0;

if peakAligned && overlapStrong && corrStronger && pearsonPositive
    verdict = "supported";
elseif (peakAligned || overlapStrong || corrStronger) && pearsonPositive
    verdict = "partially_supported";
else
    verdict = "not_supported";
end

if isfinite(ampPair.pearson_r) && isfinite(motionPair.pearson_r) && motionPair.pearson_r <= ampPair.pearson_r
    if verdict == "supported"
        verdict = "partially_supported";
    end
end
end

function style = classifyWindowStyle(featA, featMotion, motionPair, cfg)
style = "mixed";
if isfinite(featA.FWHM_width_K) && isfinite(featMotion.FWHM_width_K) && isfinite(motionPair.halfmax_overlap_fraction)
    if featMotion.FWHM_width_K >= cfg.broadWindowFraction * featA.FWHM_width_K && motionPair.halfmax_overlap_fraction >= cfg.windowOverlapSupport
        style = "broad_window";
    elseif motionPair.peak_alignment_abs_K <= cfg.peakAlignmentToleranceK
        style = "sharp_peak";
    end
end
end

function txt = yesNoLine(tf)
if tf
    txt = "yes";
else
    txt = "no";
end
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
zip(zipPath, {'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);
end

function [windowLow, windowHigh, width, peakT] = computeHalfMaxWindow(T, y)
T = T(:);
y = y(:);
windowLow = NaN;
windowHigh = NaN;
width = NaN;
peakT = NaN;
ok = isfinite(T) & isfinite(y);
T = T(ok);
y = y(ok);
if numel(T) < 3
    return;
end

[peakVal, idxPeak] = max(y);
if ~(isfinite(peakVal) && peakVal > 0)
    return;
end
peakT = T(idxPeak);
halfVal = 0.5 * peakVal;

leftIdx = find(y(1:idxPeak) <= halfVal, 1, 'last');
if isempty(leftIdx)
    windowLow = T(1);
elseif leftIdx == idxPeak
    windowLow = T(idxPeak);
else
    windowLow = crossInterp(T(leftIdx), T(leftIdx + 1), y(leftIdx) - halfVal, y(leftIdx + 1) - halfVal);
end

rightRel = find(y(idxPeak:end) <= halfVal, 1, 'first');
if isempty(rightRel)
    windowHigh = T(end);
else
    rightIdx = idxPeak + rightRel - 1;
    if rightIdx == idxPeak
        windowHigh = T(idxPeak);
    else
        windowHigh = crossInterp(T(rightIdx - 1), T(rightIdx), y(rightIdx - 1) - halfVal, y(rightIdx) - halfVal);
    end
end

width = windowHigh - windowLow;
if ~(isfinite(width) && width >= 0)
    width = NaN;
end
end

function x0 = crossInterp(x1, x2, y1, y2)
if ~all(isfinite([x1 x2 y1 y2]))
    x0 = NaN;
    return;
end
if abs(y2 - y1) < eps
    x0 = mean([x1 x2]);
else
    x0 = x1 - y1 * (x2 - x1) / (y2 - y1);
end
end

function out = normalizePositive(y)
y = y(:);
out = NaN(size(y));
mx = max(y, [], 'omitnan');
if isfinite(mx) && mx > 0
    out = y ./ mx;
end
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
    c = cc(1,2);
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
[xs, order] = sort(x(valid));
ranks = zeros(size(xs));
i = 1;
while i <= numel(xs)
    j = i;
    while j < numel(xs) && xs(j + 1) == xs(i)
        j = j + 1;
    end
    ranks(i:j) = mean(i:j);
    i = j + 1;
end
rValid = zeros(size(xs));
rValid(order) = ranks;
r(valid) = rValid;
end

function overlap = intervalOverlap(aLow, aHigh, bLow, bHigh)
overlap = NaN;
if ~all(isfinite([aLow aHigh bLow bHigh]))
    return;
end
intersectionWidth = max(0, min(aHigh, bHigh) - max(aLow, bLow));
unionWidth = max(aHigh, bHigh) - min(aLow, bLow);
if unionWidth > 0
    overlap = intersectionWidth / unionWidth;
end
end

function cT = weightedCentroid(T, y)
T = T(:);
y = y(:);
mask = isfinite(T) & isfinite(y);
cT = NaN;
if nnz(mask) < 2
    return;
end
T = T(mask);
y = max(y(mask), 0);
area = trapz(T, y);
if ~(isfinite(area) && area > 0)
    return;
end
cT = trapz(T, T .* y) / area;
end

function areaVal = positiveArea(T, y)
T = T(:);
y = y(:);
mask = isfinite(T) & isfinite(y);
areaVal = NaN;
if nnz(mask) < 2
    return;
end
areaVal = trapz(T(mask), max(y(mask), 0));
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
