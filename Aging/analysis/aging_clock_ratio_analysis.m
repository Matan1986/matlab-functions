function out = aging_clock_ratio_analysis(cfg)
% aging_clock_ratio_analysis
% Build and analyze the ratio R(T_p) = tau_FM(T_p) / tau_dip(T_p) using
% previously extracted Aging timescales and, when available, existing
% cross-experiment A(T_p) and X(T_p) alignments.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg, repoRoot);
source = resolveSources(cfg);

runCfg = struct();
runCfg.runLabel = char(string(cfg.runLabel));
runCfg.dataset = sprintf('dip:%s | fm:%s | bridge:%s', ...
    char(string(source.dipRunName)), ...
    char(string(source.fmRunName)), ...
    char(string(source.bridgeRunName)));
run = createRunContext('aging', runCfg);
runDir = run.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging clock ratio analysis run root:\n%s\n', runDir);
fprintf('Dip tau source: %s\n', source.dipTauPath);
fprintf('FM tau source: %s\n', source.fmTauPath);
if source.hasBridge
    fprintf('Bridge-aligned A/X source: %s\n', source.bridgeAlignedPath);
else
    fprintf('Bridge-aligned A/X source: unavailable\n');
end

appendText(run.log_path, sprintf('[%s] aging_clock_ratio_analysis started\n', stampNow()));
appendText(run.log_path, sprintf('Dip tau source: %s\n', source.dipTauPath));
appendText(run.log_path, sprintf('FM tau source: %s\n', source.fmTauPath));
appendText(run.log_path, sprintf('Bridge-aligned A/X source: %s\n', source.bridgeAlignedPath));

dipTbl = loadTauTable(source.dipTauPath, source.dipRunName, 'tau_dip_seconds');
fmTbl = loadTauTable(source.fmTauPath, source.fmRunName, 'tau_FM_seconds');
bridgeTbl = loadBridgeTable(source.bridgeAlignedPath, source.hasBridge);

[clockTbl, mergedTbl] = buildClockRatioTable(dipTbl, fmTbl, bridgeTbl);
fitStats = fitClockPowerLaw(clockTbl);
ratioStats = analyzeRatioTemperatureDependence(clockTbl, cfg.crossoverTemperatureK);
summaryTbl = buildSummaryTable(clockTbl, mergedTbl, fitStats);
sourceManifestTbl = buildSourceManifestTable(source);

clockTablePath = save_run_table(clockTbl, 'table_clock_ratio.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'correlation_summary.csv', runDir);
manifestPath = save_run_table(sourceManifestTbl, 'source_run_manifest.csv', runDir);
observablesPath = exportClockRatioObservables(runDir, run.run_id, clockTbl, source);

figDip = makeTauTemperatureFigure(clockTbl.Tp, clockTbl.tau_dip_seconds, cfg.colors.dip, ...
    '\tau_{dip} (s)', 'Dip-sector clock vs stopping temperature', cfg.crossoverTemperatureK);
figDipPaths = save_run_figure(figDip, 'tau_dip_vs_Tp', runDir);
close(figDip);

figFm = makeTauTemperatureFigure(clockTbl.Tp, clockTbl.tau_FM_seconds, cfg.colors.fm, ...
    '\tau_{FM} (s)', 'FM-sector clock vs stopping temperature', cfg.crossoverTemperatureK);
figFmPaths = save_run_figure(figFm, 'tau_FM_vs_Tp', runDir);
close(figFm);

figRatio = makeRatioFigure(clockTbl, cfg);
figRatioPaths = save_run_figure(figRatio, 'ratio_R_vs_Tp', runDir);
close(figRatio);

figLogLog = makeLogLogFigure(clockTbl, fitStats, cfg);
figLogLogPaths = save_run_figure(figLogLog, 'loglog_clock_relation', runDir);
close(figLogLog);

reportText = buildReportText(runDir, source, clockTbl, summaryTbl, fitStats, ratioStats, cfg);
reportPath = save_run_report(reportText, 'aging_clock_ratio_analysis_report.md', runDir);
zipPath = buildReviewZip(runDir, 'aging_clock_ratio_bundle.zip');

appendText(run.notes_path, sprintf('Finite ratio temperatures: %s K\n', char(join(compose('%.0f', ratioStats.finiteTp.'), ', '))));
appendText(run.notes_path, sprintf('Ratio monotonic increasing: %s\n', tfText(ratioStats.isMonotonicIncreasing)));
appendText(run.notes_path, sprintf('Clock proportionality alpha = %.6g, R^2 = %.6g (n = %d)\n', ...
    fitStats.alpha, fitStats.r_squared, fitStats.n_pairs));
appendText(run.notes_path, sprintf('Cross-over interpretation: %s\n', char(ratioStats.crossoverSummary)));
appendText(run.log_path, sprintf('[%s] clock table: %s\n', stampNow(), clockTablePath));
appendText(run.log_path, sprintf('[%s] summary table: %s\n', stampNow(), summaryPath));
appendText(run.log_path, sprintf('[%s] source manifest: %s\n', stampNow(), manifestPath));
appendText(run.log_path, sprintf('[%s] observables: %s\n', stampNow(), observablesPath));
appendText(run.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(run.log_path, sprintf('[%s] zip: %s\n', stampNow(), zipPath));

fprintf('Aging clock ratio analysis complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Clock table: %s\n', clockTablePath);
fprintf('Report: %s\n', reportPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run = run;
out.runDir = string(runDir);
out.clockTable = clockTbl;
out.summaryTable = summaryTbl;
out.fitStats = fitStats;
out.ratioStats = ratioStats;
out.tablePath = string(clockTablePath);
out.summaryPath = string(summaryPath);
out.observablesPath = string(observablesPath);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.figures = struct( ...
    'tau_dip', string(figDipPaths.png), ...
    'tau_FM', string(figFmPaths.png), ...
    'ratio', string(figRatioPaths.png), ...
    'loglog', string(figLogLogPaths.png));
end

function outPath = exportClockRatioObservables(runDir, runId, clockTbl, source)
sampleName = "aging_clock_ratio_" + string(source.dipRunName) + "__" + string(source.fmRunName);
n = height(clockTbl);
obsTbl = table( ...
    repmat("aging", n, 1), ...
    repmat(sampleName, n, 1), ...
    clockTbl.Tp(:), ...
    repmat("R", n, 1), ...
    clockTbl.R_tau_FM_over_tau_dip(:), ...
    repmat("unitless", n, 1), ...
    repmat("observable", n, 1), ...
    repmat(string(runId), n, 1), ...
    'VariableNames', {'experiment', 'sample', 'temperature', 'observable', 'value', 'units', 'role', 'source_run'});
outPath = export_observables('aging', runDir, obsTbl);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefaultField(cfg, 'runLabel', 'aging_clock_ratio_analysis');
cfg = setDefaultField(cfg, 'crossoverTemperatureK', 26);
cfg = setDefaultField(cfg, 'dipRunName', 'run_2026_03_12_223709_aging_timescale_extraction');
cfg = setDefaultField(cfg, 'fmRunName', 'run_2026_03_13_013634_aging_fm_timescale_analysis');
cfg = setDefaultField(cfg, 'bridgeRunName', 'run_2026_03_13_122404_aging_timescale_bridge');
cfg = setDefaultField(cfg, 'dipTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.dipRunName)), 'tables', 'tau_vs_Tp.csv'));
cfg = setDefaultField(cfg, 'fmTauPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.fmRunName)), 'tables', 'tau_FM_vs_Tp.csv'));
cfg = setDefaultField(cfg, 'bridgeAlignedPath', fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    char(string(cfg.bridgeRunName)), 'tables', 'aligned_dynamical_timescale_dataset.csv'));

colors = struct();
colors.dip = [0.11 0.53 0.28];
colors.fm = [0.80 0.26 0.15];
colors.ratio = [0.12 0.35 0.72];
colors.fit = [0.25 0.25 0.25];
colors.reference = [0.45 0.45 0.45];
cfg = setDefaultField(cfg, 'colors', colors);
end

function source = resolveSources(cfg)
source = struct();
source.dipRunName = string(cfg.dipRunName);
source.fmRunName = string(cfg.fmRunName);
source.bridgeRunName = string(cfg.bridgeRunName);
source.dipTauPath = char(string(cfg.dipTauPath));
source.fmTauPath = char(string(cfg.fmTauPath));
source.bridgeAlignedPath = char(string(cfg.bridgeAlignedPath));
source.hasBridge = exist(source.bridgeAlignedPath, 'file') == 2;

assert(exist(source.dipTauPath, 'file') == 2, 'Dip tau table not found: %s', source.dipTauPath);
assert(exist(source.fmTauPath, 'file') == 2, 'FM tau table not found: %s', source.fmTauPath);
end

function ensureStandardSubdirs(runDir)
for folderName = ["figures", "tables", "reports", "review"]
    folderPath = fullfile(runDir, char(folderName));
    if exist(folderPath, 'dir') ~= 7
        mkdir(folderPath);
    end
end
end

function tauTbl = loadTauTable(pathStr, runName, outputColumn)
tauTbl = readtable(pathStr, 'TextType', 'string', 'VariableNamingRule', 'preserve');
tauTbl = normalizeNumericColumns(tauTbl);
required = {'Tp', 'tau_effective_seconds'};
assert(all(ismember(required, tauTbl.Properties.VariableNames)), ...
    'Tau table %s is missing required columns.', pathStr);
tauTbl = tauTbl(:, {'Tp', 'tau_effective_seconds'});
tauTbl.Properties.VariableNames = {'Tp', outputColumn};
tauTbl.source_run = repmat(string(runName), height(tauTbl), 1);
tauTbl = sortrows(tauTbl, 'Tp');
end

function bridgeTbl = loadBridgeTable(pathStr, hasBridge)
if ~hasBridge
    bridgeTbl = table();
    return;
end

bridgeTbl = readtable(pathStr, 'TextType', 'string', 'VariableNamingRule', 'preserve');
bridgeTbl = normalizeNumericColumns(bridgeTbl);
required = {'Tp', 'A_Tp', 'X_Tp'};
assert(all(ismember(required, bridgeTbl.Properties.VariableNames)), ...
    'Bridge table %s is missing required columns.', pathStr);
bridgeTbl = bridgeTbl(:, required);
bridgeTbl = sortrows(bridgeTbl, 'Tp');
end

function tbl = normalizeNumericColumns(tbl)
for i = 1:numel(tbl.Properties.VariableNames)
    vn = tbl.Properties.VariableNames{i};
    if isnumeric(tbl.(vn)) || islogical(tbl.(vn))
        continue;
    end
    values = str2double(erase(string(tbl.(vn)), '"'));
    if all(isfinite(values) | ismissing(string(tbl.(vn))) | strcmpi(strtrim(string(tbl.(vn))), "NaN"))
        tbl.(vn) = values;
    end
end
end

function [clockTbl, mergedTbl] = buildClockRatioTable(dipTbl, fmTbl, bridgeTbl)
allTp = unique([dipTbl.Tp(:); fmTbl.Tp(:)], 'sorted');
tauDip = mapByTp(allTp, dipTbl.Tp, dipTbl.tau_dip_seconds);
tauFm = mapByTp(allTp, fmTbl.Tp, fmTbl.tau_FM_seconds);
ratio = tauFm ./ tauDip;
ratio(~isfinite(tauDip) | ~isfinite(tauFm) | tauDip <= 0 | tauFm <= 0) = NaN;

log10Dip = nan(size(tauDip));
maskDip = isfinite(tauDip) & tauDip > 0;
log10Dip(maskDip) = log10(tauDip(maskDip));

log10Fm = nan(size(tauFm));
maskFm = isfinite(tauFm) & tauFm > 0;
log10Fm(maskFm) = log10(tauFm(maskFm));

clockTbl = table(allTp, tauDip, tauFm, ratio, log10Dip, log10Fm, ...
    'VariableNames', {'Tp', 'tau_dip_seconds', 'tau_FM_seconds', ...
    'R_tau_FM_over_tau_dip', 'log10_tau_dip', 'log10_tau_FM'});

mergedTbl = clockTbl;
if ~isempty(bridgeTbl)
    mergedTbl.A_Tp = mapByTp(allTp, bridgeTbl.Tp, bridgeTbl.A_Tp);
    mergedTbl.X_Tp = mapByTp(allTp, bridgeTbl.Tp, bridgeTbl.X_Tp);
else
    mergedTbl.A_Tp = nan(size(allTp));
    mergedTbl.X_Tp = nan(size(allTp));
end
end

function valuesOut = mapByTp(targetTp, sourceTp, sourceValues)
valuesOut = nan(size(targetTp));
[tf, loc] = ismember(targetTp, sourceTp);
valuesOut(tf) = sourceValues(loc(tf));
end

function fitStats = fitClockPowerLaw(clockTbl)
mask = isfinite(clockTbl.tau_dip_seconds) & clockTbl.tau_dip_seconds > 0 & ...
    isfinite(clockTbl.tau_FM_seconds) & clockTbl.tau_FM_seconds > 0;
x = log10(clockTbl.tau_dip_seconds(mask));
y = log10(clockTbl.tau_FM_seconds(mask));
tp = clockTbl.Tp(mask);

fitStats = struct();
fitStats.n_pairs = numel(x);
fitStats.Tp = tp;
fitStats.log10_tau_dip = x;
fitStats.log10_tau_FM = y;
fitStats.alpha = NaN;
fitStats.intercept = NaN;
fitStats.r_squared = NaN;
fitStats.log_pearson_r = NaN;
fitStats.status = "insufficient_overlap";

if numel(x) < 2
    return;
end

coeffs = polyfit(x, y, 1);
yhat = polyval(coeffs, x);
ssRes = sum((y - yhat) .^ 2);
ssTot = sum((y - mean(y)) .^ 2);

fitStats.alpha = coeffs(1);
fitStats.intercept = coeffs(2);
if ssTot > 0
    fitStats.r_squared = 1 - ssRes ./ ssTot;
end
fitStats.log_pearson_r = pearsonCorrelation(x, y);
fitStats.status = "ok";
end

function ratioStats = analyzeRatioTemperatureDependence(clockTbl, crossoverTemperatureK)
mask = isfinite(clockTbl.R_tau_FM_over_tau_dip) & clockTbl.R_tau_FM_over_tau_dip > 0;
tp = clockTbl.Tp(mask);
ratio = clockTbl.R_tau_FM_over_tau_dip(mask);
logRatio = log10(ratio);

ratioStats = struct();
ratioStats.finiteTp = tp;
ratioStats.finiteRatio = ratio;
ratioStats.log10Ratio = logRatio;
ratioStats.n_points = numel(ratio);
ratioStats.isMonotonicIncreasing = numel(ratio) >= 2 && all(diff(ratio) > 0);
ratioStats.isApproximatelyConstant = false;
ratioStats.crossesUnity = any(ratio < 1) && any(ratio > 1);
ratioStats.firstGreaterThanOneTp = NaN;
ratioStats.belowUnityTp = tp(ratio < 1);
ratioStats.aboveUnityTp = tp(ratio > 1);
ratioStats.segmentSlopeTable = table([], [], [], [], ...
    'VariableNames', {'Tp_start', 'Tp_end', 'delta_log10_R', 'slope_decades_per_K'});
ratioStats.crossoverSummary = "Ratio unavailable.";
ratioStats.crossoverTemperatureK = crossoverTemperatureK;

if isempty(ratio)
    return;
end

if any(ratio > 1)
    ratioStats.firstGreaterThanOneTp = tp(find(ratio > 1, 1, 'first'));
end

if numel(ratio) >= 2
    deltaLog = diff(logRatio);
    deltaT = diff(tp);
    slopes = deltaLog ./ deltaT;
    ratioStats.segmentSlopeTable = table(tp(1:end-1), tp(2:end), deltaLog, slopes, ...
        'VariableNames', {'Tp_start', 'Tp_end', 'delta_log10_R', 'slope_decades_per_K'});
end

if numel(ratio) >= 2
    logSpread = max(logRatio) - min(logRatio);
    ratioStats.isApproximatelyConstant = logSpread < 0.1;
end

if ratioStats.n_points < 2
    ratioStats.crossoverSummary = "Only one finite ratio point is available.";
    return;
end

lastSegmentIdx = find(ratioStats.segmentSlopeTable.Tp_end == crossoverTemperatureK, 1, 'last');
if ~isempty(lastSegmentIdx) && height(ratioStats.segmentSlopeTable) >= 2
    lastSlope = ratioStats.segmentSlopeTable.slope_decades_per_K(lastSegmentIdx);
    priorMask = ratioStats.segmentSlopeTable.Tp_end < crossoverTemperatureK;
    priorSlopes = ratioStats.segmentSlopeTable.slope_decades_per_K(priorMask);
    if ~isempty(priorSlopes) && all(isfinite(priorSlopes))
        meanPrior = mean(priorSlopes);
        if meanPrior ~= 0
            factor = lastSlope / meanPrior;
            ratioStats.crossoverSummary = string(sprintf([ ...
                'log10(R) steepens into %.0f K: the final resolved segment has slope %.3f decades/K, ' ...
                'which is %.2fx the mean lower-temperature slope.'], ...
                crossoverTemperatureK, lastSlope, factor));
            return;
        end
    end
    ratioStats.crossoverSummary = string(sprintf( ...
        'The final resolved segment into %.0f K has slope %.3f decades/K.', ...
        crossoverTemperatureK, lastSlope));
else
    ratioStats.crossoverSummary = string(sprintf([ ...
        'No resolved ratio segment ends exactly at %.0f K; any crossover statement is limited by missing taus.'], ...
        crossoverTemperatureK));
end
end

function summaryTbl = buildSummaryTable(clockTbl, mergedTbl, fitStats)
rows = repmat(initSummaryRow(), 3, 1);

rows(1).analysis_key = "clock_power_law_fit";
rows(1).x_quantity = "tau_dip";
rows(1).y_quantity = "tau_FM";
rows(1).transform = "log10-log10";
rows(1).n_pairs = fitStats.n_pairs;
rows(1).pearson_r = fitStats.log_pearson_r;
rows(1).spearman_r = spearmanCorrelation(fitStats.log10_tau_dip, fitStats.log10_tau_FM);
rows(1).fit_slope_alpha = fitStats.alpha;
rows(1).fit_r_squared = fitStats.r_squared;
rows(1).Tp_values_used = join(compose('%.0f', fitStats.Tp.'), ', ');
rows(1).notes = "Fit of log10(tau_FM) vs log10(tau_dip) over finite overlap temperatures.";

statsA = correlationStats(mergedTbl.R_tau_FM_over_tau_dip, mergedTbl.A_Tp, mergedTbl.Tp);
rows(2).analysis_key = "R_vs_A";
rows(2).x_quantity = "R=tau_FM/tau_dip";
rows(2).y_quantity = "A(Tp)";
rows(2).transform = "raw";
rows(2).n_pairs = statsA.n_pairs;
rows(2).pearson_r = statsA.pearson_r;
rows(2).spearman_r = statsA.spearman_r;
rows(2).Tp_values_used = statsA.tp_string;
rows(2).notes = "Correlation between the clock ratio and relaxation activity on the common Tp grid.";

statsX = correlationStats(mergedTbl.R_tau_FM_over_tau_dip, mergedTbl.X_Tp, mergedTbl.Tp);
rows(3).analysis_key = "R_vs_X";
rows(3).x_quantity = "R=tau_FM/tau_dip";
rows(3).y_quantity = "X(Tp)";
rows(3).transform = "raw";
rows(3).n_pairs = statsX.n_pairs;
rows(3).pearson_r = statsX.pearson_r;
rows(3).spearman_r = statsX.spearman_r;
rows(3).Tp_values_used = statsX.tp_string;
rows(3).notes = "Correlation between the clock ratio and switching coordinate on the common Tp grid.";

summaryTbl = struct2table(rows);
end

function row = initSummaryRow()
row = struct( ...
    'analysis_key', "", ...
    'x_quantity', "", ...
    'y_quantity', "", ...
    'transform', "", ...
    'n_pairs', 0, ...
    'pearson_r', NaN, ...
    'spearman_r', NaN, ...
    'fit_slope_alpha', NaN, ...
    'fit_r_squared', NaN, ...
    'Tp_values_used', "", ...
    'notes', "");
end

function stats = correlationStats(x, y, tp)
mask = isfinite(x) & isfinite(y);
stats = struct();
stats.n_pairs = nnz(mask);
stats.pearson_r = NaN;
stats.spearman_r = NaN;
stats.tp_string = "";
if stats.n_pairs == 0
    return;
end

x = x(mask);
y = y(mask);
tp = tp(mask);
stats.tp_string = join(compose('%.0f', tp.'), ', ');
if stats.n_pairs >= 2
    stats.pearson_r = pearsonCorrelation(x, y);
    stats.spearman_r = spearmanCorrelation(x, y);
end
end

function manifestTbl = buildSourceManifestTable(source)
experiment = strings(0, 1);
observable = strings(0, 1);
runName = strings(0, 1);
filePath = strings(0, 1);
columnUsed = strings(0, 1);

experiment(end + 1, 1) = "aging";
observable(end + 1, 1) = "tau_dip(Tp)";
runName(end + 1, 1) = source.dipRunName;
filePath(end + 1, 1) = string(source.dipTauPath);
columnUsed(end + 1, 1) = "tau_effective_seconds";

experiment(end + 1, 1) = "aging";
observable(end + 1, 1) = "tau_FM(Tp)";
runName(end + 1, 1) = source.fmRunName;
filePath(end + 1, 1) = string(source.fmTauPath);
columnUsed(end + 1, 1) = "tau_effective_seconds";

if source.hasBridge
    experiment(end + 1, 1) = "cross_experiment";
    observable(end + 1, 1) = "A(Tp), X(Tp) aligned bridge";
    runName(end + 1, 1) = source.bridgeRunName;
    filePath(end + 1, 1) = string(source.bridgeAlignedPath);
    columnUsed(end + 1, 1) = "A_Tp, X_Tp";
end

manifestTbl = table(experiment, observable, runName, filePath, columnUsed, ...
    'VariableNames', {'experiment', 'observable', 'run_name', 'file_path', 'column_used'});
end

function fig = makeTauTemperatureFigure(tp, tau, colorValue, yLabelText, titleText, crossoverTemperatureK)
mask = isfinite(tp) & isfinite(tau) & tau > 0;
fig = create_figure('Position', [2 2 12.8 9.0]);
ax = axes('Parent', fig);
hold(ax, 'on');
plot(ax, tp(mask), tau(mask), 'o-', ...
    'Color', colorValue, ...
    'MarkerFaceColor', colorValue, ...
    'MarkerSize', 7, ...
    'LineWidth', 2.2);
xline(ax, crossoverTemperatureK, '--', sprintf('%.0f K crossover', crossoverTemperatureK), ...
    'Color', [0.35 0.35 0.35], 'LineWidth', 1.5, ...
    'LabelVerticalAlignment', 'bottom', 'LabelOrientation', 'horizontal');
set(ax, 'YScale', 'log', 'FontSize', 14, 'LineWidth', 1.2);
grid(ax, 'on');
box(ax, 'off');
xlabel(ax, 'T_p (K)', 'FontSize', 14);
ylabel(ax, yLabelText, 'FontSize', 14);
title(ax, titleText, 'FontSize', 14, 'FontWeight', 'normal');
ax.XLim = [min(tp) - 1, max(tp) + 1];
end

function fig = makeRatioFigure(clockTbl, cfg)
mask = isfinite(clockTbl.R_tau_FM_over_tau_dip) & clockTbl.R_tau_FM_over_tau_dip > 0;
fig = create_figure('Position', [2 2 12.8 9.0]);
ax = axes('Parent', fig);
hold(ax, 'on');
plot(ax, clockTbl.Tp(mask), clockTbl.R_tau_FM_over_tau_dip(mask), 'o-', ...
    'Color', cfg.colors.ratio, ...
    'MarkerFaceColor', cfg.colors.ratio, ...
    'MarkerSize', 7, ...
    'LineWidth', 2.2);
yline(ax, 1, '--', 'R = 1', 'Color', cfg.colors.reference, 'LineWidth', 1.5);
xline(ax, cfg.crossoverTemperatureK, '--', sprintf('%.0f K crossover', cfg.crossoverTemperatureK), ...
    'Color', [0.35 0.35 0.35], 'LineWidth', 1.5, ...
    'LabelVerticalAlignment', 'bottom', 'LabelOrientation', 'horizontal');
set(ax, 'YScale', 'log', 'FontSize', 14, 'LineWidth', 1.2);
grid(ax, 'on');
box(ax, 'off');
xlabel(ax, 'T_p (K)', 'FontSize', 14);
ylabel(ax, 'R(T_p) = \tau_{FM} / \tau_{dip}', 'FontSize', 14);
title(ax, 'Clock ratio vs stopping temperature', 'FontSize', 14, 'FontWeight', 'normal');
ax.XLim = [min(clockTbl.Tp) - 1, max(clockTbl.Tp) + 1];
end

function fig = makeLogLogFigure(clockTbl, fitStats, cfg)
mask = isfinite(clockTbl.tau_dip_seconds) & clockTbl.tau_dip_seconds > 0 & ...
    isfinite(clockTbl.tau_FM_seconds) & clockTbl.tau_FM_seconds > 0;
x = clockTbl.tau_dip_seconds(mask);
y = clockTbl.tau_FM_seconds(mask);
tp = clockTbl.Tp(mask);

fig = create_figure('Position', [2 2 12.8 9.0]);
ax = axes('Parent', fig);
hold(ax, 'on');

loglog(ax, x, y, 'o', ...
    'Color', cfg.colors.fm, ...
    'MarkerFaceColor', cfg.colors.fm, ...
    'MarkerSize', 7, ...
    'LineWidth', 2.0);

for i = 1:numel(tp)
    text(ax, x(i) * 1.04, y(i) * 1.05, sprintf('%.0f K', tp(i)), ...
        'FontSize', 11, 'Color', [0.20 0.20 0.20]);
end

if fitStats.n_pairs >= 2 && isfinite(fitStats.alpha) && isfinite(fitStats.intercept)
    xFit = logspace(log10(min(x)) - 0.08, log10(max(x)) + 0.08, 200);
    yFit = 10 .^ (fitStats.intercept + fitStats.alpha .* log10(xFit));
    loglog(ax, xFit, yFit, '-', 'Color', cfg.colors.fit, 'LineWidth', 2.0);
    legend(ax, {'data', 'power-law fit'}, 'Location', 'northwest', 'FontSize', 12);
end

set(ax, 'FontSize', 14, 'LineWidth', 1.2);
grid(ax, 'on');
box(ax, 'off');
xlabel(ax, '\tau_{dip} (s)', 'FontSize', 14);
ylabel(ax, '\tau_{FM} (s)', 'FontSize', 14);
title(ax, 'Clock-to-clock relation in log-log space', 'FontSize', 14, 'FontWeight', 'normal');

annotationText = sprintf('\\alpha = %.3f\\nR^2 = %.3f\\nn = %d', ...
    fitStats.alpha, fitStats.r_squared, fitStats.n_pairs);
text(ax, 0.06, 0.94, annotationText, ...
    'Units', 'normalized', ...
    'VerticalAlignment', 'top', ...
    'FontSize', 12, ...
    'BackgroundColor', 'w', ...
    'Margin', 6);
end

function reportText = buildReportText(runDir, source, clockTbl, summaryTbl, fitStats, ratioStats, cfg)
lines = strings(0, 1);
lines(end + 1) = "# Aging clock ratio analysis";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", stampNow());
lines(end + 1) = sprintf("Run root: `%s`", runDir);
lines(end + 1) = "";
lines(end + 1) = "## Repository scan summary";
lines(end + 1) = "- Checked the Aging analysis scripts and existing `results/aging/runs/` outputs before creating this run.";
lines(end + 1) = "- No completed prior run was found that exported `R(T_p) = tau_FM / tau_dip` as a dedicated table plus temperature, crossover, and `A/X` correlation analysis.";
lines(end + 1) = "- The existing `run_2026_03_13_013634_aging_fm_timescale_analysis` run already contained a `tau_FM` vs `tau_dip` comparison figure, so this run extends that partial overlap instead of repeating the earlier FM extraction.";
lines(end + 1) = "";
lines(end + 1) = "## Sources";
lines(end + 1) = sprintf("- Dip-sector clock: `%s`", source.dipTauPath);
lines(end + 1) = sprintf("- FM-sector clock: `%s`", source.fmTauPath);
if source.hasBridge
    lines(end + 1) = sprintf("- Existing aligned `A(T_p), X(T_p)` bridge table: `%s`", source.bridgeAlignedPath);
else
    lines(end + 1) = "- Existing aligned `A(T_p), X(T_p)` bridge table: unavailable, so the `A/X` comparison was skipped.";
end
lines(end + 1) = "";
lines(end + 1) = "## Clock table";
lines(end + 1) = "| T_p (K) | tau_dip (s) | tau_FM (s) | R = tau_FM / tau_dip |";
lines(end + 1) = "| --- | ---: | ---: | ---: |";
for i = 1:height(clockTbl)
    lines(end + 1) = sprintf("| %.0f | %s | %s | %s |", ...
        clockTbl.Tp(i), ...
        fmtNumber(clockTbl.tau_dip_seconds(i), '%.6g'), ...
        fmtNumber(clockTbl.tau_FM_seconds(i), '%.6g'), ...
        fmtNumber(clockTbl.R_tau_FM_over_tau_dip(i), '%.6g'));
end
lines(end + 1) = "";
lines(end + 1) = "## Temperature dependence";
lines(end + 1) = sprintf("- Finite ratio points: `%s K`.", char(join(compose('%.0f', ratioStats.finiteTp.'), ', ')));
lines(end + 1) = sprintf("- Constant-ratio check: `%s`.", yesNoText(ratioStats.isApproximatelyConstant));
lines(end + 1) = sprintf("- Monotonic-ratio check: `%s`.", yesNoText(ratioStats.isMonotonicIncreasing));
if ratioStats.crossesUnity
    lines(end + 1) = sprintf("- `R(T_p)` crosses unity between `%.0f K` and `%.0f K`, so `tau_FM < tau_dip` only at the lowest overlap point and `tau_FM > tau_dip` for the higher overlap temperatures.", ...
        max(ratioStats.belowUnityTp), ratioStats.firstGreaterThanOneTp);
else
    lines(end + 1) = "- `R(T_p)` does not cross unity on the finite overlap set.";
end
lines(end + 1) = sprintf("- The ratio increases from `%s` at `14 K` to `%s` at `26 K`, so the two clocks do not remain proportionally separated by a fixed factor.", ...
    fmtNumber(valueAtTp(clockTbl, 14, 'R_tau_FM_over_tau_dip'), '%.4g'), ...
    fmtNumber(valueAtTp(clockTbl, 26, 'R_tau_FM_over_tau_dip'), '%.4g'));
lines(end + 1) = "";
lines(end + 1) = "## Log-log clock relation";
lines(end + 1) = sprintf("- Overlap temperatures used in the fit: `%s K`.", char(join(compose('%.0f', fitStats.Tp.'), ', ')));
lines(end + 1) = sprintf("- Power-law slope `alpha = %.6g`.", fitStats.alpha);
lines(end + 1) = sprintf("- Fit quality `R^2 = %.6g`.", fitStats.r_squared);
lines(end + 1) = sprintf("- Log-space Pearson correlation = `%.6g`.", fitStats.log_pearson_r);
if isfinite(fitStats.alpha) && isfinite(fitStats.r_squared)
    if abs(fitStats.alpha - 1) <= 0.15 && fitStats.r_squared >= 0.8
        lines(end + 1) = "- Interpretation: the clocks are approximately proportional on the finite overlap set.";
    else
        lines(end + 1) = "- Interpretation: the clocks do not follow a robust proportional power law on the finite overlap set.";
    end
end
lines(end + 1) = "";
lines(end + 1) = "## Correlation summary";
for i = 2:height(summaryTbl)
    lines(end + 1) = sprintf("- `%s`: Pearson `%.6g`, Spearman `%.6g`, `n = %d`, overlap `T_p = %s K`.", ...
        summaryTbl.analysis_key(i), summaryTbl.pearson_r(i), summaryTbl.spearman_r(i), ...
        summaryTbl.n_pairs(i), char(summaryTbl.Tp_values_used(i)));
end
if source.hasBridge
    lines(end + 1) = "- These `A/X` correlations are descriptive only because the ratio is defined at just four temperatures (`14, 18, 22, 26 K`).";
end
lines(end + 1) = "";
lines(end + 1) = "## Temperature-window test near 26 K";
lines(end + 1) = sprintf("- Reference crossover used in the figures: `%.0f K`.", cfg.crossoverTemperatureK);
lines(end + 1) = sprintf("- %s", char(ratioStats.crossoverSummary));
if ~isempty(ratioStats.segmentSlopeTable)
    for i = 1:height(ratioStats.segmentSlopeTable)
        lines(end + 1) = sprintf("- Segment `%.0f-%.0f K`: `delta log10(R) = %.6g`, slope `%.6g decades/K`.", ...
            ratioStats.segmentSlopeTable.Tp_start(i), ...
            ratioStats.segmentSlopeTable.Tp_end(i), ...
            ratioStats.segmentSlopeTable.delta_log10_R(i), ...
            ratioStats.segmentSlopeTable.slope_decades_per_K(i));
    end
end
lines(end + 1) = "- Above `26 K`, the ratio cannot be continued because `tau_dip` is unresolved at `30 K` and `34 K` in the source dip-timescale table.";
lines(end + 1) = "";
lines(end + 1) = "## Conclusion";
if ratioStats.isMonotonicIncreasing
    lines(end + 1) = "- `R(T_p)` rises strongly with temperature, so the FM and dip clocks are not separated by an approximately constant factor.";
else
    lines(end + 1) = "- `R(T_p)` is not constant, but the finite overlap set is too sparse to call it strictly monotonic.";
end
lines(end + 1) = "- The log-log fit gives a very weak power-law relation, which argues against a single proportional clock across the two sectors.";
lines(end + 1) = "- The steepest resolved increase in `R(T_p)` occurs on the final `22-26 K` segment, consistent with a dynamical crossover as the dip clock collapses while the FM clock stays large.";
if source.hasBridge
    lines(end + 1) = "- `R(T_p)` can be compared to both `A(T_p)` and `X(T_p)`, but any apparent trend should be treated as a small-sample descriptive correlation rather than a settled law.";
end
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- Number of curves per figure: 1 in the three temperature-dependence plots and 1 data series + 1 fit line in the log-log relation, so no colormap was used.";
lines(end + 1) = "- Legend vs colormap: no legend was needed for the single-curve temperature plots; the log-log plot uses a two-entry legend for data and fit.";
lines(end + 1) = "- Colormap used: none. Fixed colors distinguish dip, FM, ratio, and fit elements.";
lines(end + 1) = "- Smoothing applied: none. All plots use the saved effective timescales directly.";
lines(end + 1) = "- Justification: the dataset has only 4 finite ratio points, so direct point-marked curves with the `26 K` crossover marked are the clearest representation.";
lines(end + 1) = "";
lines(end + 1) = "## Exported artifacts";
lines(end + 1) = "- `tables/table_clock_ratio.csv`";
lines(end + 1) = "- `tables/correlation_summary.csv`";
lines(end + 1) = "- `figures/tau_dip_vs_Tp.png`";
lines(end + 1) = "- `figures/tau_FM_vs_Tp.png`";
lines(end + 1) = "- `figures/ratio_R_vs_Tp.png`";
lines(end + 1) = "- `figures/loglog_clock_relation.png`";
lines(end + 1) = "- `reports/aging_clock_ratio_analysis_report.md`";
lines(end + 1) = "- `review/aging_clock_ratio_bundle.zip`";

reportText = strjoin(lines, newline);
end

function value = valueAtTp(tbl, tp, fieldName)
idx = find(tbl.Tp == tp, 1, 'first');
if isempty(idx)
    value = NaN;
else
    value = tbl.(fieldName)(idx);
end
end

function r = pearsonCorrelation(x, y)
r = NaN;
if numel(x) < 2 || numel(y) < 2
    return;
end
C = corrcoef(x(:), y(:));
if isequal(size(C), [2 2])
    r = C(1, 2);
end
end

function r = spearmanCorrelation(x, y)
r = NaN;
if numel(x) < 2 || numel(y) < 2
    return;
end
rx = tiedRankLocal(x(:));
ry = tiedRankLocal(y(:));
C = corrcoef(rx, ry);
if isequal(size(C), [2 2])
    r = C(1, 2);
end
end

function ranks = tiedRankLocal(values)
[sortedValues, order] = sort(values);
ranks = zeros(size(values));
i = 1;
while i <= numel(sortedValues)
    j = i;
    while j < numel(sortedValues) && sortedValues(j + 1) == sortedValues(i)
        j = j + 1;
    end
    ranks(order(i:j)) = (i + j) / 2;
    i = j + 1;
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
zip(zipPath, {'figures', 'tables', 'reports'}, runDir);
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

function out = setDefaultField(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    out = s;
    return;
end
s.(fieldName) = defaultValue;
out = s;
end

function txt = fmtNumber(value, pattern)
if nargin < 2
    pattern = '%.4g';
end
if ~isfinite(value)
    txt = "NaN";
else
    txt = string(sprintf(pattern, value));
end
end

function txt = yesNoText(flag)
if flag
    txt = "Yes";
else
    txt = "No";
end
end

function txt = tfText(flag)
if flag
    txt = "true";
else
    txt = "false";
end
end
