function out = aging_switching_clock_bridge(cfg)
% aging_switching_clock_bridge
% Bridge the aging clock ratio R(T)=tau_FM/tau_dip to switching geometry X(T).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg, repoRoot);
source = resolveSources(cfg);

runCfg = struct();
runCfg.runLabel = char(string(cfg.runLabel));
runCfg.dataset = sprintf('aging_ratio:%s | switching_x:%s', ...
    char(source.agingRunName), char(source.switchingRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
ensureStandardSubdirs(runDir);

appendText(run.log_path, sprintf('[%s] aging_switching_clock_bridge started\n', stampNow()));
appendText(run.log_path, sprintf('Aging source: %s\n', source.agingClockPath));
appendText(run.log_path, sprintf('Switching source: %s\n', source.switchingXPath));

agingTbl = loadAgingClockTable(source.agingClockPath);
switchingTbl = loadSwitchingXTable(source.switchingXPath);
commonTbl = buildCommonTable(agingTbl, switchingTbl);

corrStats = computeCorrelation(commonTbl.R_tau_FM_over_tau_dip, commonTbl.X);
fitStats = fitLogLogRvsX(commonTbl);
crossover = computeCrossover(commonTbl, switchingTbl, cfg);
summaryTbl = buildCorrelationSummary(corrStats, fitStats, crossover);

tablePath = save_run_table(commonTbl, 'table_clock_switching_bridge.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'correlation_summary.csv', runDir);

figRvsT = makeRvsTFigure(commonTbl, crossover, cfg);
figRvsTPaths = save_run_figure(figRvsT, 'ratio_R_vs_T', runDir);
close(figRvsT);

figXvsT = makeXvsTFigure(commonTbl, switchingTbl, crossover, cfg);
figXvsTPaths = save_run_figure(figXvsT, 'X_vs_T', runDir);
close(figXvsT);

figRvsX = makeRvsXFigure(commonTbl, corrStats, cfg);
figRvsXPaths = save_run_figure(figRvsX, 'ratio_R_vs_X', runDir);
close(figRvsX);

figLogLog = makeLogLogFitFigure(commonTbl, fitStats, cfg);
figLogLogPaths = save_run_figure(figLogLog, 'loglog_R_vs_X_fit', runDir);
close(figLogLog);

reportText = buildReportText(runDir, source, commonTbl, corrStats, fitStats, crossover);
reportPath = save_run_report(reportText, 'aging_switching_clock_bridge_report.md', runDir);

zipPath = buildReviewZip(runDir, 'aging_switching_clock_bridge_bundle.zip');

appendText(run.notes_path, sprintf('Common temperatures (K): %s\n', char(join(compose('%.0f', commonTbl.T.'), ', '))));
appendText(run.notes_path, sprintf('Pearson(R,X)=%.6g, Spearman(R,X)=%.6g, n=%d\n', ...
    corrStats.pearson_r, corrStats.spearman_r, corrStats.n_pairs));
appendText(run.notes_path, sprintf('log(R) vs log(X): beta=%.6g, R^2=%.6g\n', fitStats.beta, fitStats.r_squared));
appendText(run.notes_path, sprintf('X peak temperature (all switching T): %.0f K\n', crossover.x_peak_T_all));
appendText(run.notes_path, sprintf('Steepest R(T) segment end: %.0f K\n', crossover.steepest_segment_end_T));
appendText(run.notes_path, sprintf('Delta T (steepest end - X peak): %.0f K\n', crossover.deltaT_steepest_end_minus_X_peak));

appendText(run.log_path, sprintf('[%s] common table: %s\n', stampNow(), tablePath));
appendText(run.log_path, sprintf('[%s] correlation summary: %s\n', stampNow(), summaryPath));
appendText(run.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(run.log_path, sprintf('[%s] zip: %s\n', stampNow(), zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.commonTable = commonTbl;
out.correlation = corrStats;
out.fit = fitStats;
out.crossover = crossover;
out.tablePath = string(tablePath);
out.summaryPath = string(summaryPath);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.figures = struct( ...
    'R_vs_T', string(figRvsTPaths.png), ...
    'X_vs_T', string(figXvsTPaths.png), ...
    'R_vs_X', string(figRvsXPaths.png), ...
    'loglog_R_vs_X', string(figLogLogPaths.png));
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefaultField(cfg, 'runLabel', 'aging_switching_clock_bridge');
cfg = setDefaultField(cfg, 'crossoverTemperatureK', 26);
cfg = setDefaultField(cfg, 'crossoverToleranceK', 2);
cfg = setDefaultField(cfg, 'agingRunName', 'run_2026_03_14_074613_aging_clock_ratio_analysis');
cfg = setDefaultField(cfg, 'switchingRunName', 'run_2026_03_13_071713_switching_composite_observable_scan');
cfg = setDefaultField(cfg, 'agingClockPath', fullfile(repoRoot, 'results', 'aging', 'runs', ...
    char(string(cfg.agingRunName)), 'tables', 'table_clock_ratio.csv'));
cfg = setDefaultField(cfg, 'switchingXPath', fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    char(string(cfg.switchingRunName)), 'tables', 'composite_observables_table.csv'));

colors = struct();
colors.ratio = [0.13 0.36 0.74];
colors.x = [0.84 0.31 0.13];
colors.fit = [0.22 0.22 0.22];
colors.reference = [0.45 0.45 0.45];
cfg = setDefaultField(cfg, 'colors', colors);
end

function source = resolveSources(cfg)
source = struct();
source.agingRunName = string(cfg.agingRunName);
source.switchingRunName = string(cfg.switchingRunName);
source.agingClockPath = char(string(cfg.agingClockPath));
source.switchingXPath = char(string(cfg.switchingXPath));

assert(exist(source.agingClockPath, 'file') == 2, ...
    'Aging clock table not found: %s', source.agingClockPath);
assert(exist(source.switchingXPath, 'file') == 2, ...
    'Switching X table not found: %s', source.switchingXPath);
end

function ensureStandardSubdirs(runDir)
for folderName = ["figures", "tables", "reports", "review"]
    folderPath = fullfile(runDir, char(folderName));
    if exist(folderPath, 'dir') ~= 7
        mkdir(folderPath);
    end
end
end

function tbl = loadAgingClockTable(pathStr)
tbl = readtable(pathStr, 'TextType', 'string', 'VariableNamingRule', 'preserve');
tbl = normalizeNumericColumns(tbl);
required = {'Tp', 'tau_dip_seconds', 'tau_FM_seconds', 'R_tau_FM_over_tau_dip'};
assert(all(ismember(required, tbl.Properties.VariableNames)), ...
    'Aging clock table is missing required columns.');
tbl = tbl(:, required);
tbl = sortrows(tbl, 'Tp');
end

function tbl = loadSwitchingXTable(pathStr)
tbl = readtable(pathStr, 'TextType', 'string', 'VariableNamingRule', 'preserve');
tbl = normalizeNumericColumns(tbl);
required = {'T_K', 'I_over_wS'};
assert(all(ismember(required, tbl.Properties.VariableNames)), ...
    'Switching table is missing required columns.');
tbl = tbl(:, required);
tbl = sortrows(tbl, 'T_K');
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

function commonTbl = buildCommonTable(agingTbl, switchingTbl)
T = agingTbl.Tp(:);
xAtTp = mapByT(T, switchingTbl.T_K, switchingTbl.I_over_wS);

commonTbl = table( ...
    T, ...
    agingTbl.tau_dip_seconds(:), ...
    agingTbl.tau_FM_seconds(:), ...
    agingTbl.R_tau_FM_over_tau_dip(:), ...
    xAtTp(:), ...
    'VariableNames', {'T', 'tau_dip_seconds', 'tau_FM_seconds', 'R_tau_FM_over_tau_dip', 'X'});

mask = isfinite(commonTbl.tau_dip_seconds) & commonTbl.tau_dip_seconds > 0 & ...
    isfinite(commonTbl.tau_FM_seconds) & commonTbl.tau_FM_seconds > 0 & ...
    isfinite(commonTbl.R_tau_FM_over_tau_dip) & commonTbl.R_tau_FM_over_tau_dip > 0 & ...
    isfinite(commonTbl.X) & commonTbl.X > 0;

commonTbl = commonTbl(mask, :);
commonTbl = sortrows(commonTbl, 'T');
end

function mapped = mapByT(targetT, sourceT, sourceValues)
mapped = nan(size(targetT));
[tf, loc] = ismember(targetT, sourceT);
mapped(tf) = sourceValues(loc(tf));
end

function stats = computeCorrelation(x, y)
mask = isfinite(x) & isfinite(y);
stats = struct();
stats.n_pairs = nnz(mask);
stats.pearson_r = NaN;
stats.spearman_r = NaN;
if stats.n_pairs < 2
    return;
end
x = x(mask);
y = y(mask);
stats.pearson_r = pearsonCorrelation(x, y);
stats.spearman_r = spearmanCorrelation(x, y);
end

function fitStats = fitLogLogRvsX(commonTbl)
mask = isfinite(commonTbl.R_tau_FM_over_tau_dip) & commonTbl.R_tau_FM_over_tau_dip > 0 & ...
    isfinite(commonTbl.X) & commonTbl.X > 0;
x = commonTbl.X(mask);
r = commonTbl.R_tau_FM_over_tau_dip(mask);
lx = log10(x);
lr = log10(r);
t = commonTbl.T(mask);

fitStats = struct();
fitStats.n_pairs = numel(lx);
fitStats.T = t;
fitStats.X = x;
fitStats.R = r;
fitStats.log10_X = lx;
fitStats.log10_R = lr;
fitStats.beta = NaN;
fitStats.intercept = NaN;
fitStats.r_squared = NaN;
fitStats.status = "insufficient_pairs";

if numel(lx) < 2
    return;
end

coeffs = polyfit(lx, lr, 1);
lrHat = polyval(coeffs, lx);
ssRes = sum((lr - lrHat).^2);
ssTot = sum((lr - mean(lr)).^2);

fitStats.beta = coeffs(1);
fitStats.intercept = coeffs(2);
if ssTot > 0
    fitStats.r_squared = 1 - ssRes/ssTot;
end
fitStats.status = "ok";
end

function crossover = computeCrossover(commonTbl, switchingTbl, cfg)
crossover = struct();
crossover.x_peak_T_all = NaN;
crossover.x_peak_value_all = NaN;
crossover.x_peak_T_common = NaN;
crossover.x_peak_value_common = NaN;
crossover.steepest_segment_start_T = NaN;
crossover.steepest_segment_end_T = NaN;
crossover.steepest_segment_mid_T = NaN;
crossover.steepest_slope_log10R_per_K = NaN;
crossover.deltaT_steepest_end_minus_X_peak = NaN;
crossover.is_near_peak = false;
crossover.segment_table = table([], [], [], [], ...
    'VariableNames', {'T_start', 'T_end', 'delta_log10_R', 'slope_log10R_per_K'});

maskXAll = isfinite(switchingTbl.T_K) & isfinite(switchingTbl.I_over_wS);
if any(maskXAll)
    [crossover.x_peak_value_all, idx] = max(switchingTbl.I_over_wS(maskXAll));
    tAll = switchingTbl.T_K(maskXAll);
    crossover.x_peak_T_all = tAll(idx);
end

maskXCommon = isfinite(commonTbl.T) & isfinite(commonTbl.X);
if any(maskXCommon)
    [crossover.x_peak_value_common, idx] = max(commonTbl.X(maskXCommon));
    tCommon = commonTbl.T(maskXCommon);
    crossover.x_peak_T_common = tCommon(idx);
end

maskR = isfinite(commonTbl.T) & isfinite(commonTbl.R_tau_FM_over_tau_dip) & commonTbl.R_tau_FM_over_tau_dip > 0;
T = commonTbl.T(maskR);
R = commonTbl.R_tau_FM_over_tau_dip(maskR);
if numel(T) < 2
    return;
end

deltaLogR = diff(log10(R));
deltaT = diff(T);
slope = deltaLogR ./ deltaT;
segTbl = table(T(1:end-1), T(2:end), deltaLogR, slope, ...
    'VariableNames', {'T_start', 'T_end', 'delta_log10_R', 'slope_log10R_per_K'});
cross_over_idx = find(abs(segTbl.slope_log10R_per_K) == max(abs(segTbl.slope_log10R_per_K)), 1, 'first');

crossover.segment_table = segTbl;
crossover.steepest_segment_start_T = segTbl.T_start(cross_over_idx);
crossover.steepest_segment_end_T = segTbl.T_end(cross_over_idx);
crossover.steepest_segment_mid_T = mean([segTbl.T_start(cross_over_idx), segTbl.T_end(cross_over_idx)]);
crossover.steepest_slope_log10R_per_K = segTbl.slope_log10R_per_K(cross_over_idx);

if isfinite(crossover.x_peak_T_all)
    crossover.deltaT_steepest_end_minus_X_peak = crossover.steepest_segment_end_T - crossover.x_peak_T_all;
    crossover.is_near_peak = abs(crossover.deltaT_steepest_end_minus_X_peak) <= cfg.crossoverToleranceK;
end
end

function summaryTbl = buildCorrelationSummary(corrStats, fitStats, crossover)
summaryTbl = table( ...
    corrStats.n_pairs, ...
    corrStats.pearson_r, ...
    corrStats.spearman_r, ...
    fitStats.beta, ...
    fitStats.r_squared, ...
    fitStats.intercept, ...
    crossover.x_peak_T_all, ...
    crossover.steepest_segment_start_T, ...
    crossover.steepest_segment_end_T, ...
    crossover.steepest_slope_log10R_per_K, ...
    crossover.deltaT_steepest_end_minus_X_peak, ...
    crossover.is_near_peak, ...
    'VariableNames', { ...
    'n_pairs_R_X', ...
    'pearson_R_X', ...
    'spearman_R_X', ...
    'beta_loglog_R_vs_X', ...
    'R2_loglog_R_vs_X', ...
    'intercept_log10R_vs_log10X', ...
    'X_peak_temperature_K', ...
    'steepest_R_segment_start_K', ...
    'steepest_R_segment_end_K', ...
    'steepest_R_segment_slope_log10R_per_K', ...
    'deltaT_steepest_end_minus_X_peak_K', ...
    'crossover_match_within_tolerance'});
end

function fig = makeRvsTFigure(commonTbl, crossover, cfg)
fig = create_figure('Position', [2 2 12.8 9.0], 'Visible', 'off');
ax = axes('Parent', fig);
hold(ax, 'on');

plot(ax, commonTbl.T, commonTbl.R_tau_FM_over_tau_dip, 'o-', ...
    'Color', cfg.colors.ratio, ...
    'MarkerFaceColor', cfg.colors.ratio, ...
    'MarkerSize', 7, ...
    'LineWidth', 2.2);
yline(ax, 1, '--', 'R = 1', 'Color', cfg.colors.reference, 'LineWidth', 1.5);
if isfinite(crossover.x_peak_T_all)
    xline(ax, crossover.x_peak_T_all, '--', sprintf('X peak: %.0f K', crossover.x_peak_T_all), ...
        'Color', [0.35 0.35 0.35], 'LineWidth', 1.5, ...
        'LabelVerticalAlignment', 'bottom', 'LabelOrientation', 'horizontal');
end

set(ax, 'YScale', 'log', 'FontSize', 14, 'LineWidth', 1.2);
grid(ax, 'on');
box(ax, 'off');
xlabel(ax, 'T (K)', 'FontSize', 14);
ylabel(ax, 'R(T)=\tau_{FM}/\tau_{dip} (a.u.)', 'FontSize', 14);
title(ax, 'Clock ratio R(T) vs temperature', 'FontSize', 14, 'FontWeight', 'normal');
ax.XLim = [min(commonTbl.T) - 1, max(commonTbl.T) + 1];
end

function fig = makeXvsTFigure(commonTbl, switchingTbl, crossover, cfg)
fig = create_figure('Position', [2 2 12.8 9.0], 'Visible', 'off');
ax = axes('Parent', fig);
hold(ax, 'on');

maskAll = isfinite(switchingTbl.T_K) & isfinite(switchingTbl.I_over_wS) & switchingTbl.I_over_wS > 0;
plot(ax, switchingTbl.T_K(maskAll), switchingTbl.I_over_wS(maskAll), 'o-', ...
    'Color', cfg.colors.x, ...
    'MarkerFaceColor', cfg.colors.x, ...
    'MarkerSize', 5.5, ...
    'LineWidth', 2.0, ...
    'DisplayName', 'Switching X(T) source');

plot(ax, commonTbl.T, commonTbl.X, 'ks', ...
    'MarkerFaceColor', 'w', ...
    'MarkerSize', 7, ...
    'LineWidth', 1.4, ...
    'DisplayName', 'Common T subset');

if isfinite(crossover.x_peak_T_all) && isfinite(crossover.x_peak_value_all)
    plot(ax, crossover.x_peak_T_all, crossover.x_peak_value_all, 'kp', ...
        'MarkerFaceColor', [0.95 0.95 0.95], 'MarkerSize', 10, 'LineWidth', 1.4, ...
        'DisplayName', 'X peak');
end

set(ax, 'FontSize', 14, 'LineWidth', 1.2);
grid(ax, 'on');
box(ax, 'off');
xlabel(ax, 'T (K)', 'FontSize', 14);
ylabel(ax, 'X(T)=I_{peak}/(width\cdot S_{peak}) (a.u.)', 'FontSize', 14);
title(ax, 'Switching geometry X(T) vs temperature', 'FontSize', 14, 'FontWeight', 'normal');
legend(ax, 'Location', 'northwest', 'FontSize', 12);
ax.XLim = [min(switchingTbl.T_K(maskAll)) - 1, max(switchingTbl.T_K(maskAll)) + 1];
end

function fig = makeRvsXFigure(commonTbl, corrStats, cfg)
fig = create_figure('Position', [2 2 12.8 9.0], 'Visible', 'off');
ax = axes('Parent', fig);
hold(ax, 'on');

plot(ax, commonTbl.X, commonTbl.R_tau_FM_over_tau_dip, 'o-', ...
    'Color', cfg.colors.ratio, ...
    'MarkerFaceColor', cfg.colors.ratio, ...
    'MarkerSize', 7, ...
    'LineWidth', 2.2);

for i = 1:height(commonTbl)
    text(ax, commonTbl.X(i) * 1.005, commonTbl.R_tau_FM_over_tau_dip(i) * 1.02, sprintf('%.0f K', commonTbl.T(i)), ...
        'FontSize', 11, 'Color', [0.2 0.2 0.2]);
end

set(ax, 'YScale', 'log', 'FontSize', 14, 'LineWidth', 1.2);
grid(ax, 'on');
box(ax, 'off');
xlabel(ax, 'X(T)=I_{peak}/(width\cdot S_{peak}) (a.u.)', 'FontSize', 14);
ylabel(ax, 'R(T)=\tau_{FM}/\tau_{dip} (a.u.)', 'FontSize', 14);
title(ax, 'Clock ratio R(T) vs switching geometry X(T)', 'FontSize', 14, 'FontWeight', 'normal');

annotationText = sprintf('n=%d\nPearson=%.3f\nSpearman=%.3f', ...
    corrStats.n_pairs, corrStats.pearson_r, corrStats.spearman_r);
text(ax, 0.04, 0.94, annotationText, 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'FontSize', 12, 'BackgroundColor', 'w', 'Margin', 6);
end

function fig = makeLogLogFitFigure(commonTbl, fitStats, cfg)
fig = create_figure('Position', [2 2 12.8 9.0], 'Visible', 'off');
ax = axes('Parent', fig);
hold(ax, 'on');

loglog(ax, fitStats.X, fitStats.R, 'o', ...
    'Color', cfg.colors.ratio, ...
    'MarkerFaceColor', cfg.colors.ratio, ...
    'MarkerSize', 7, ...
    'LineWidth', 2.0);

if fitStats.n_pairs >= 2 && isfinite(fitStats.beta) && isfinite(fitStats.intercept)
    xFit = logspace(log10(min(fitStats.X)) - 0.03, log10(max(fitStats.X)) + 0.03, 200);
    rFit = 10 .^ (fitStats.intercept + fitStats.beta .* log10(xFit));
    loglog(ax, xFit, rFit, '-', 'Color', cfg.colors.fit, 'LineWidth', 2.0);
    legend(ax, {'data', 'fit: R \propto X^\beta'}, 'Location', 'northwest', 'FontSize', 12);
end

for i = 1:numel(fitStats.T)
    text(ax, fitStats.X(i) * 1.005, fitStats.R(i) * 1.02, sprintf('%.0f K', fitStats.T(i)), ...
        'FontSize', 11, 'Color', [0.2 0.2 0.2]);
end

set(ax, 'FontSize', 14, 'LineWidth', 1.2);
grid(ax, 'on');
box(ax, 'off');
xlabel(ax, 'X(T) (a.u.)', 'FontSize', 14);
ylabel(ax, 'R(T) (a.u.)', 'FontSize', 14);
title(ax, 'log-log fit: R(T) vs X(T)', 'FontSize', 14, 'FontWeight', 'normal');

annotationText = sprintf('\\beta = %.3f\nR^2 = %.3f\nn = %d', ...
    fitStats.beta, fitStats.r_squared, fitStats.n_pairs);
text(ax, 0.04, 0.94, annotationText, 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'FontSize', 12, 'BackgroundColor', 'w', 'Margin', 6);
end

function reportText = buildReportText(runDir, source, commonTbl, corrStats, fitStats, crossover)
lines = strings(0, 1);
lines(end + 1) = "# Aging-switching clock bridge";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", stampNow());
lines(end + 1) = sprintf("Run root: `%s`", runDir);
lines(end + 1) = "";
lines(end + 1) = "## Existing-analysis check";
lines(end + 1) = "- A prior Aging run already computed `R_vs_X` scalar correlations (`run_2026_03_14_074613_aging_clock_ratio_analysis`).";
lines(end + 1) = "- This run adds the explicit bridge artifacts requested here: common table with `T,tau_dip,tau_FM,R,X`, `R(T)` vs `X(T)` plot, and log-log `R \\propto X^\\beta` fit.";
lines(end + 1) = "";
lines(end + 1) = "## Sources";
lines(end + 1) = sprintf("- Aging clock ratio table: `%s`", source.agingClockPath);
lines(end + 1) = sprintf("- Switching composite geometry table: `%s`", source.switchingXPath);
lines(end + 1) = "";
lines(end + 1) = "## Common-temperature bridge table";
lines(end + 1) = sprintf("- Temperatures with both aging clocks and switching `X(T)`: `%s K`.", char(join(compose('%.0f', commonTbl.T.'), ', ')));
lines(end + 1) = sprintf("- Number of paired points: `%d`.", height(commonTbl));
lines(end + 1) = "";
lines(end + 1) = "## Correlation and functional relation";
lines(end + 1) = sprintf("- Pearson(`R`,`X`) = `%.6g`.", corrStats.pearson_r);
lines(end + 1) = sprintf("- Spearman(`R`,`X`) = `%.6g`.", corrStats.spearman_r);
lines(end + 1) = sprintf("- Fit `log(R) = beta * log(X) + c`: `beta = %.6g`, `R^2 = %.6g`.", fitStats.beta, fitStats.r_squared);
lines(end + 1) = "";
lines(end + 1) = "## Crossover test near 26 K";
lines(end + 1) = sprintf("- Peak of switching `X(T)` on its source grid occurs at `%.0f K`.", crossover.x_peak_T_all);
lines(end + 1) = sprintf("- Steepest `R(T)` segment is `%.0f-%.0f K` with slope `%.6g` in `log10(R)/K`.", ...
    crossover.steepest_segment_start_T, crossover.steepest_segment_end_T, crossover.steepest_slope_log10R_per_K);
lines(end + 1) = sprintf("- Offset between steepest-segment end and `X` peak: `%.0f K`.", crossover.deltaT_steepest_end_minus_X_peak);
if crossover.is_near_peak
    lines(end + 1) = "- Crossover verdict: yes, the sharp `R(T)` growth lands near the `X(T)` peak region around `26 K`.";
else
    lines(end + 1) = "- Crossover verdict: no clear temperature coincidence within the selected tolerance.";
end
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
if isfinite(corrStats.pearson_r) && abs(corrStats.pearson_r) >= 0.8
    lines(end + 1) = "- `R(T)` correlates strongly with switching geometry `X(T)` on the available overlap temperatures.";
elseif isfinite(corrStats.pearson_r) && abs(corrStats.pearson_r) >= 0.5
    lines(end + 1) = "- `R(T)` shows a moderate correlation with switching geometry `X(T)` on the available overlap temperatures.";
else
    lines(end + 1) = "- `R(T)` shows only weak linear correlation with switching geometry `X(T)` on the available overlap temperatures.";
end
if isfinite(fitStats.r_squared) && fitStats.r_squared >= 0.8
    lines(end + 1) = "- The ratio can be approximated by a simple power-law in `X` on this sampled range.";
else
    lines(end + 1) = "- A simple power-law `R \\propto X^\\beta` is only weakly supported on this sparse dataset.";
end
lines(end + 1) = "- Because only four paired temperatures are available, all conclusions here remain descriptive rather than final.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- Number of curves: `R(T)` vs `T` (1), `X(T)` vs `T` (1 source curve + overlap markers), `R` vs `X` (1), log-log fit (1 data series + 1 fit line).";
lines(end + 1) = "- Legend vs colormap: explicit legends where multiple series appear; no colormap used.";
lines(end + 1) = "- Colormap used: none.";
lines(end + 1) = "- Smoothing applied: none.";
lines(end + 1) = "- Justification: with very small paired sample size, direct point-marked plots and labeled temperatures best preserve interpretability.";

reportText = strjoin(lines, newline);
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
