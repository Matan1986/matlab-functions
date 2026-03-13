function out = barrier_observable_test(cfg)
% barrier_observable_test
% Reuse saved switching and relaxation outputs to test whether
% B(T) = I_peak(T) / width(T) behaves like a barrier-like control scale
% for relaxation activity A(T).

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
runCfg.dataset = sprintf('switch:%s | relax:%s', ...
    char(source.switchRunName), char(source.relaxRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Barrier observable test run directory:\n%s\n', runDir);
fprintf('Switching source run: %s\n', source.switchRunName);
fprintf('Relaxation source run: %s\n', source.relaxRunName);

appendText(run.log_path, sprintf('[%s] barrier observable test started\n', stampNow()));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));

switching = loadSwitchingData(source.switchRunDir);
relax = loadRelaxationData(source.relaxRunDir);
aligned = buildAlignedData(switching, relax, cfg);
correlationTbl = buildCorrelationTable(aligned);
looTbl = buildLeaveOneOutTable(aligned);
curveTbl = buildCurveTable(aligned);
manifestTbl = buildManifestTable(source);

curvePath = save_run_table(curveTbl, 'barrier_observable_curves.csv', runDir);
correlationPath = save_run_table(correlationTbl, 'barrier_observable_correlation_summary.csv', runDir);
looPath = save_run_table(looTbl, 'barrier_observable_leave_one_out.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

figBarrier = saveBarrierVsTFigure(aligned, runDir, 'barrier_vs_temperature');
figOverlay = saveNormalizedOverlayFigure(aligned, runDir, 'normalized_A_and_B_overlay');
figScatter = saveActivityScatterFigure(aligned, correlationTbl, runDir, 'activity_vs_barrier_scatter');
figLogScatter = saveLogActivityScatterFigure(aligned, correlationTbl, runDir, 'log_activity_vs_barrier');

reportText = buildReportText(source, aligned, correlationTbl, looTbl, cfg);
reportPath = save_run_report(reportText, 'barrier_observable_analysis.md', runDir);
zipPath = buildReviewZip(runDir, 'barrier_observable_test_bundle.zip');

mainRow = correlationTbl(correlationTbl.comparison == "A_vs_B", :);
logRow = correlationTbl(correlationTbl.comparison == "lnA_vs_B", :);
appendText(run.notes_path, sprintf('Definition: B(T) = I_peak(T) / width(T)\n'));
appendText(run.notes_path, sprintf('Switching source = %s\n', char(source.switchRunName)));
appendText(run.notes_path, sprintf('Relaxation source = %s\n', char(source.relaxRunName)));
appendText(run.notes_path, sprintf('Pearson(A,B) = %.6g\n', mainRow.pearson_r(1)));
appendText(run.notes_path, sprintf('Spearman(A,B) = %.6g\n', mainRow.spearman_r(1)));
appendText(run.notes_path, sprintf('Pearson(lnA,B) = %.6g\n', logRow.pearson_r(1)));
appendText(run.notes_path, sprintf('Spearman(lnA,B) = %.6g\n', logRow.spearman_r(1)));

appendText(run.log_path, sprintf('[%s] barrier observable test complete\n', stampNow()));
appendText(run.log_path, sprintf('Curve table: %s\n', curvePath));
appendText(run.log_path, sprintf('Correlation table: %s\n', correlationPath));
appendText(run.log_path, sprintf('Leave-one-out table: %s\n', looPath));
appendText(run.log_path, sprintf('Manifest table: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.aligned = aligned;
out.tables = struct( ...
    'curves', string(curvePath), ...
    'correlation', string(correlationPath), ...
    'leave_one_out', string(looPath), ...
    'manifest', string(manifestPath));
out.figures = struct( ...
    'barrier_vs_T', string(figBarrier.png), ...
    'overlay', string(figOverlay.png), ...
    'activity_scatter', string(figScatter.png), ...
    'log_activity_scatter', string(figLogScatter.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Barrier observable test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson(A,B): %.4f\n', mainRow.pearson_r(1));
fprintf('Spearman(A,B): %.4f\n', mainRow.spearman_r(1));
fprintf('Pearson(lnA,B): %.4f\n', logRow.pearson_r(1));
fprintf('Spearman(lnA,B): %.4f\n', logRow.spearman_r(1));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'barrier_observable_test');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));

requiredPaths = {
    source.switchRunDir, fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv');
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv')
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

function switching = loadSwitchingData(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'switching_full_scaling_parameters.csv'));
tbl = sortrows(tbl, 'T_K');

mask = isfinite(tbl.T_K) & isfinite(tbl.Ipeak_mA) & isfinite(tbl.width_chosen_mA) & tbl.width_chosen_mA > 0;
if ~any(mask)
    error('No valid switching rows were found for I_peak(T) and width(T).');
end

tbl = tbl(mask, :);

switching = struct();
switching.T = tbl.T_K(:);
switching.I_peak = tbl.Ipeak_mA(:);
switching.width = tbl.width_chosen_mA(:);
switching.width_method = string(tbl.width_method(:));
switching.S_peak = tbl.S_peak(:);
switching.n_valid_points = tbl.n_valid_points(:);
end

function relax = loadRelaxationData(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
tbl = sortrows(tbl, 'T');

mask = isfinite(tbl.T) & isfinite(tbl.A_T) & tbl.A_T > 0;
if ~any(mask)
    error('No valid relaxation rows were found for A(T).');
end

tbl = tbl(mask, :);

relax = struct();
relax.T = tbl.T(:);
relax.A = tbl.A_T(:);
end

function aligned = buildAlignedData(switching, relax, cfg)
overlapMask = switching.T >= min(relax.T) & switching.T <= max(relax.T);
if ~any(overlapMask)
    error('No overlapping temperature range exists between the switching and relaxation runs.');
end

T = switching.T(overlapMask);
I_peak = switching.I_peak(overlapMask);
width = switching.width(overlapMask);
B = I_peak ./ width;
A_interp = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
lnA_interp = NaN(size(A_interp));
positiveMask = isfinite(A_interp) & A_interp > 0;
lnA_interp(positiveMask) = log(A_interp(positiveMask));

validMask = isfinite(T) & isfinite(I_peak) & isfinite(width) & width > 0 & isfinite(B) & isfinite(A_interp) & A_interp > 0;
if nnz(validMask) < 4
    error('Too few overlapping valid temperatures remain after alignment.');
end

aligned = struct();
aligned.T_K = T(:);
aligned.I_peak_mA = I_peak(:);
aligned.width_mA = width(:);
aligned.B = B(:);
aligned.A_interp = A_interp(:);
aligned.lnA_interp = lnA_interp(:);
aligned.validMask = validMask(:);
aligned.interp_method = string(cfg.interpMethod);
aligned.usedInterpolation = ~isequal(relax.T(:), T(:));
aligned.width_method = switching.width_method(overlapMask);
aligned.S_peak = switching.S_peak(overlapMask);
aligned.n_valid_points = switching.n_valid_points(overlapMask);
aligned.A_norm = normalizePositive(aligned.A_interp, aligned.validMask);
aligned.B_norm = normalizePositive(aligned.B, aligned.validMask);
end

function correlationTbl = buildCorrelationTable(aligned)
defs = {
    'A_vs_B', aligned.B, aligned.A_interp;
    'lnA_vs_B', aligned.B, aligned.lnA_interp
    };

correlationTbl = table( ...
    strings(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    strings(size(defs, 1), 1), ...
    'VariableNames', {'comparison','n_points','pearson_r','spearman_r','linear_slope', ...
    'linear_intercept','linear_r2','residual_rms','interpretation'});

for i = 1:size(defs, 1)
    x = defs{i, 2};
    y = defs{i, 3};
    mask = aligned.validMask & isfinite(x(:)) & isfinite(y(:));

    [slope, intercept, r2, rmsResidual] = linearFitStats(x(mask), y(mask));
    correlationTbl.comparison(i) = string(defs{i, 1});
    correlationTbl.n_points(i) = nnz(mask);
    correlationTbl.pearson_r(i) = corrSafe(x(mask), y(mask));
    correlationTbl.spearman_r(i) = spearmanSafe(x(mask), y(mask));
    correlationTbl.linear_slope(i) = slope;
    correlationTbl.linear_intercept(i) = intercept;
    correlationTbl.linear_r2(i) = r2;
    correlationTbl.residual_rms(i) = rmsResidual;
    correlationTbl.interpretation(i) = describeComparison(correlationTbl.pearson_r(i), correlationTbl.spearman_r(i), slope, string(defs{i, 1}));
end
end

function looTbl = buildLeaveOneOutTable(aligned)
n = numel(aligned.T_K);
looTbl = table( ...
    aligned.T_K(:), ...
    NaN(n, 1), NaN(n, 1), NaN(n, 1), NaN(n, 1), NaN(n, 1), NaN(n, 1), ...
    false(n, 1), false(n, 1), false(n, 1), false(n, 1), ...
    'VariableNames', {'omitted_temperature_K','pearson_A_B','spearman_A_B', ...
    'pearson_lnA_B','spearman_lnA_B','linear_slope_lnA_B','linear_r2_lnA_B', ...
    'pearson_A_sign_flip','spearman_A_sign_flip','pearson_lnA_sign_flip','spearman_lnA_sign_flip'});

fullPearsonA = corrSafe(aligned.B(aligned.validMask), aligned.A_interp(aligned.validMask));
fullSpearmanA = spearmanSafe(aligned.B(aligned.validMask), aligned.A_interp(aligned.validMask));
fullPearsonLn = corrSafe(aligned.B(aligned.validMask), aligned.lnA_interp(aligned.validMask));
fullSpearmanLn = spearmanSafe(aligned.B(aligned.validMask), aligned.lnA_interp(aligned.validMask));

for i = 1:n
    mask = aligned.validMask;
    mask(i) = false;

    looTbl.pearson_A_B(i) = corrSafe(aligned.B(mask), aligned.A_interp(mask));
    looTbl.spearman_A_B(i) = spearmanSafe(aligned.B(mask), aligned.A_interp(mask));
    looTbl.pearson_lnA_B(i) = corrSafe(aligned.B(mask), aligned.lnA_interp(mask));
    looTbl.spearman_lnA_B(i) = spearmanSafe(aligned.B(mask), aligned.lnA_interp(mask));

    [slopeLn, ~, r2Ln, ~] = linearFitStats(aligned.B(mask), aligned.lnA_interp(mask));
    looTbl.linear_slope_lnA_B(i) = slopeLn;
    looTbl.linear_r2_lnA_B(i) = r2Ln;

    looTbl.pearson_A_sign_flip(i) = signChanged(fullPearsonA, looTbl.pearson_A_B(i));
    looTbl.spearman_A_sign_flip(i) = signChanged(fullSpearmanA, looTbl.spearman_A_B(i));
    looTbl.pearson_lnA_sign_flip(i) = signChanged(fullPearsonLn, looTbl.pearson_lnA_B(i));
    looTbl.spearman_lnA_sign_flip(i) = signChanged(fullSpearmanLn, looTbl.spearman_lnA_B(i));
end
end

function curveTbl = buildCurveTable(aligned)
curveTbl = table( ...
    aligned.T_K(:), ...
    aligned.I_peak_mA(:), ...
    aligned.width_mA(:), ...
    aligned.B(:), ...
    aligned.A_interp(:), ...
    aligned.lnA_interp(:), ...
    aligned.B_norm(:), ...
    aligned.A_norm(:), ...
    aligned.validMask(:), ...
    aligned.S_peak(:), ...
    aligned.n_valid_points(:), ...
    aligned.width_method(:), ...
    repmat(aligned.interp_method, numel(aligned.T_K), 1), ...
    'VariableNames', {'T_K','I_peak_mA','width_mA','B_T','A_interp','lnA_interp', ...
    'B_norm','A_norm','valid_mask','S_peak','switching_n_valid_points', ...
    'width_method','interp_method'});
end

function manifestTbl = buildManifestTable(source)
experiment = string({'switching'; 'relaxation'});
sourceRun = [source.switchRunName; source.relaxRunName];
sourceFile = string({ ...
    fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv')});
role = string({'I_peak(T) and width(T) source'; 'A(T) source'});
manifestTbl = table(experiment, sourceRun, sourceFile, role, ...
    'VariableNames', {'experiment','source_run','source_file','role'});
end

function figPaths = saveBarrierVsTFigure(aligned, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 16.0, 9.5);
ax = axes(fh);
plot(ax, aligned.T_K, aligned.B, '-o', ...
    'Color', [0.06 0.28 0.54], 'LineWidth', 2.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.06 0.28 0.54]);
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'B(T) = I_{peak}(T) / width(T)');
title(ax, 'Barrier-like observable B(T) from switching full-scaling outputs');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveNormalizedOverlayFigure(aligned, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 16.5, 9.5);
ax = axes(fh);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.A_norm, '-o', ...
    'Color', [0.77 0.18 0.10], 'LineWidth', 2.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.77 0.18 0.10], 'DisplayName', 'A(T) / max');
plot(ax, aligned.T_K, aligned.B_norm, '-s', ...
    'Color', [0.08 0.24 0.50], 'LineWidth', 2.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.08 0.24 0.50], 'DisplayName', 'B(T) / max');
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude');
title(ax, 'Normalized relaxation activity and B(T) on the common temperature grid');
legend(ax, 'Location', 'best');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
ylim(ax, [0 1.08]);
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveActivityScatterFigure(aligned, correlationTbl, runDir, figureName)
row = correlationTbl(correlationTbl.comparison == "A_vs_B", :);
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 13.5, 10.5);
ax = axes(fh);
hold(ax, 'on');
scatter(ax, aligned.B(aligned.validMask), aligned.A_interp(aligned.validMask), 95, aligned.T_K(aligned.validMask), ...
    'filled', 'MarkerEdgeColor', [0.20 0.20 0.20], 'LineWidth', 0.7);
plotFitLine(ax, aligned.B(aligned.validMask), aligned.A_interp(aligned.validMask), [0.15 0.15 0.15]);
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'B(T) = I_{peak}(T) / width(T)');
ylabel(ax, 'A(T)');
title(ax, 'Relaxation activity A(T) versus barrier observable B(T)');
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
cb.LineWidth = 1.0;
cb.FontName = 'Helvetica';
cb.FontSize = 12;
colormap(ax, parula(256));
txt = sprintf('Pearson = %.3f\\newlineSpearman = %.3f', row.pearson_r(1), row.spearman_r(1));
text(ax, 0.05, 0.95, txt, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontName', 'Helvetica', 'FontSize', 12, 'BackgroundColor', [1 1 1], 'Margin', 6);
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveLogActivityScatterFigure(aligned, correlationTbl, runDir, figureName)
row = correlationTbl(correlationTbl.comparison == "lnA_vs_B", :);
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 13.5, 10.5);
ax = axes(fh);
hold(ax, 'on');
scatter(ax, aligned.B(aligned.validMask), aligned.lnA_interp(aligned.validMask), 95, aligned.T_K(aligned.validMask), ...
    'filled', 'MarkerEdgeColor', [0.20 0.20 0.20], 'LineWidth', 0.7);
plotFitLine(ax, aligned.B(aligned.validMask), aligned.lnA_interp(aligned.validMask), [0.15 0.15 0.15]);
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'B(T) = I_{peak}(T) / width(T)');
ylabel(ax, 'ln(A(T))');
title(ax, 'Log-relaxation activity versus barrier observable B(T)');
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
cb.LineWidth = 1.0;
cb.FontName = 'Helvetica';
cb.FontSize = 12;
colormap(ax, parula(256));
txt = sprintf('Pearson = %.3f\\newlineSpearman = %.3f\\newlineSlope = %.3f\\newlineR^2 = %.3f', ...
    row.pearson_r(1), row.spearman_r(1), row.linear_slope(1), row.linear_r2(1));
text(ax, 0.05, 0.95, txt, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontName', 'Helvetica', 'FontSize', 12, 'BackgroundColor', [1 1 1], 'Margin', 6);
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReportText(source, aligned, correlationTbl, looTbl, cfg)
rowA = correlationTbl(correlationTbl.comparison == "A_vs_B", :);
rowLn = correlationTbl(correlationTbl.comparison == "lnA_vs_B", :);
robust = buildRobustnessSummary(looTbl);
interpretation = interpretBarrierLikeHypothesis(rowA, rowLn, robust);

widthMethods = unique(aligned.width_method);
widthMethods = widthMethods(strlength(widthMethods) > 0);

lines = strings(0, 1);
lines(end + 1) = "# Barrier Observable Analysis";
lines(end + 1) = "";
lines(end + 1) = "## Input runs";
lines(end + 1) = sprintf('- Switching observables reused from `%s`.', source.switchRunName);
lines(end + 1) = sprintf('- Relaxation activity reused from `%s`.', source.relaxRunName);
lines(end + 1) = "- No source runs were modified; all outputs in this run were generated from saved tables only.";
lines(end + 1) = "";
lines(end + 1) = "## Definition of B(T)";
lines(end + 1) = "- `B(T) = I_peak(T) / width(T)`.";
lines(end + 1) = "- `I_peak(T)` and `width(T)` were loaded from `switching_full_scaling_parameters.csv` using the saved `width_chosen_mA` column.";
lines(end + 1) = sprintf('- Width method recorded in the source table: `%s`.', char(join(widthMethods, ', ')));
lines(end + 1) = "- `A(T)` was loaded from `temperature_observables.csv`.";
if aligned.usedInterpolation
    lines(end + 1) = sprintf('- Because the relaxation and switching temperatures differ, `A(T)` was interpolated onto the switching temperature grid with `%s`.', cfg.interpMethod);
else
    lines(end + 1) = "- No interpolation was needed because both runs already shared the same temperature grid.";
end
lines(end + 1) = sprintf('- Common temperature grid used for the comparison: `%s`.', joinNumbers(aligned.T_K.'));
lines(end + 1) = "";
lines(end + 1) = "## Correlation values";
lines(end + 1) = sprintf('- `A(T)` vs `B(T)`: Pearson = %.4f, Spearman = %.4f, linear slope = %.4g, linear R^2 = %.4f, n = %d.', ...
    rowA.pearson_r(1), rowA.spearman_r(1), rowA.linear_slope(1), rowA.linear_r2(1), rowA.n_points(1));
lines(end + 1) = sprintf('- `ln(A(T))` vs `B(T)`: Pearson = %.4f, Spearman = %.4f, linear slope = %.4g, linear R^2 = %.4f, n = %d.', ...
    rowLn.pearson_r(1), rowLn.spearman_r(1), rowLn.linear_slope(1), rowLn.linear_r2(1), rowLn.n_points(1));
lines(end + 1) = "";
lines(end + 1) = "## Robustness results";
lines(end + 1) = sprintf('- Leave-one-out Pearson(A,B) range: %.4f to %.4f. Sign flips: %d.', ...
    robust.pearsonA_min, robust.pearsonA_max, robust.pearsonA_sign_flips);
lines(end + 1) = sprintf('- Leave-one-out Spearman(A,B) range: %.4f to %.4f. Sign flips: %d.', ...
    robust.spearmanA_min, robust.spearmanA_max, robust.spearmanA_sign_flips);
lines(end + 1) = sprintf('- Leave-one-out Pearson(lnA,B) range: %.4f to %.4f. Sign flips: %d.', ...
    robust.pearsonLn_min, robust.pearsonLn_max, robust.pearsonLn_sign_flips);
lines(end + 1) = sprintf('- Leave-one-out Spearman(lnA,B) range: %.4f to %.4f. Sign flips: %d.', ...
    robust.spearmanLn_min, robust.spearmanLn_max, robust.spearmanLn_sign_flips);
lines(end + 1) = sprintf('- Leave-one-out linear-fit quality for `ln(A)` vs `B`: slope range %.4g to %.4g and R^2 range %.4f to %.4f.', ...
    robust.slopeLn_min, robust.slopeLn_max, robust.r2Ln_min, robust.r2Ln_max);
if isfinite(robust.mostInfluentialTemperature)
    lines(end + 1) = sprintf('- The largest single-point shift in `Pearson(lnA,B)` occurs when omitting `%.1f K`.', robust.mostInfluentialTemperature);
end
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
lines(end + 1) = sprintf('- %s', interpretation.summary);
lines(end + 1) = sprintf('- %s', interpretation.logRelation);
lines(end + 1) = sprintf('- %s', interpretation.robustness);
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: one curve in `B(T)` vs temperature, two curves in the normalized overlay, and one scatter cloud per correlation figure";
lines(end + 1) = "- legend vs colormap: legend for the 2-curve overlay; parula plus colorbar in the scatter plots to encode temperature";
lines(end + 1) = "- colormap used: parula";
lines(end + 1) = sprintf('- smoothing applied: none beyond `%s` interpolation of `A(T)` onto the switching temperatures', cfg.interpMethod);
lines(end + 1) = "- justification: the figure set stays minimal and directly tied to the barrier-like hypothesis rather than introducing extra derived observables";

reportText = strjoin(lines, newline);
end

function robust = buildRobustnessSummary(looTbl)
robust = struct();
robust.pearsonA_min = min(looTbl.pearson_A_B, [], 'omitnan');
robust.pearsonA_max = max(looTbl.pearson_A_B, [], 'omitnan');
robust.spearmanA_min = min(looTbl.spearman_A_B, [], 'omitnan');
robust.spearmanA_max = max(looTbl.spearman_A_B, [], 'omitnan');
robust.pearsonLn_min = min(looTbl.pearson_lnA_B, [], 'omitnan');
robust.pearsonLn_max = max(looTbl.pearson_lnA_B, [], 'omitnan');
robust.spearmanLn_min = min(looTbl.spearman_lnA_B, [], 'omitnan');
robust.spearmanLn_max = max(looTbl.spearman_lnA_B, [], 'omitnan');
robust.slopeLn_min = min(looTbl.linear_slope_lnA_B, [], 'omitnan');
robust.slopeLn_max = max(looTbl.linear_slope_lnA_B, [], 'omitnan');
robust.r2Ln_min = min(looTbl.linear_r2_lnA_B, [], 'omitnan');
robust.r2Ln_max = max(looTbl.linear_r2_lnA_B, [], 'omitnan');
robust.pearsonA_sign_flips = nnz(looTbl.pearson_A_sign_flip);
robust.spearmanA_sign_flips = nnz(looTbl.spearman_A_sign_flip);
robust.pearsonLn_sign_flips = nnz(looTbl.pearson_lnA_sign_flip);
robust.spearmanLn_sign_flips = nnz(looTbl.spearman_lnA_sign_flip);

fullAbs = abs(looTbl.pearson_lnA_B - median(looTbl.pearson_lnA_B, 'omitnan'));
[~, idx] = max(fullAbs);
if isempty(idx) || ~isfinite(fullAbs(idx))
    robust.mostInfluentialTemperature = NaN;
else
    robust.mostInfluentialTemperature = looTbl.omitted_temperature_K(idx);
end
end

function interpretation = interpretBarrierLikeHypothesis(rowA, rowLn, robust)
interpretation = struct();

strengthLn = min(abs([rowLn.pearson_r(1), rowLn.spearman_r(1)]));
strengthA = min(abs([rowA.pearson_r(1), rowA.spearman_r(1)]));
signWord = slopeSignWord(rowLn.linear_slope(1));

if strengthLn >= 0.75 && robust.pearsonLn_sign_flips == 0 && robust.spearmanLn_sign_flips == 0
    interpretation.summary = sprintf('`B(T)` shows a strong monotonic association with both `A(T)` and `ln(A(T))`, so it is a credible low-dimensional control coordinate over the shared temperature window. The `ln(A)` relation is %s in slope.', signWord);
elseif strengthLn >= 0.5 && robust.pearsonLn_sign_flips == 0 && robust.spearmanLn_sign_flips == 0
    interpretation.summary = sprintf('`B(T)` shows a moderate and sign-stable association with `ln(A(T))`, so it is plausible as a coarse control scale, but not a uniquely compelling barrier variable. The `ln(A)` relation is %s in slope.', signWord);
else
    interpretation.summary = sprintf('The correlation between `B(T)` and `ln(A(T))` is too weak or too fragile to support `B(T)` as a convincing barrier-like scale. The fitted `ln(A)` slope is %s.', signWord);
end

if rowLn.linear_slope(1) < 0
    interpretation.logRelation = sprintf('Because `ln(A)` decreases as `B` increases, the sign is at least compatible with a conventional activated-barrier picture in which larger barrier scale suppresses activity. The fitted `ln(A)` relation is tighter than the raw `A(T)` relation by %s.', compareTightness(rowA, rowLn));
elseif rowLn.linear_slope(1) > 0
    interpretation.logRelation = sprintf('Because `ln(A)` increases as `B` increases, `B(T)` does not behave like a conventional suppressing barrier height; at best it acts as a crossover/control scale whose increase accompanies stronger relaxation activity. The fitted `ln(A)` relation is tighter than the raw `A(T)` relation by %s.', compareTightness(rowA, rowLn));
else
    interpretation.logRelation = 'The fitted `ln(A)` slope is nearly zero, so the exponential-control interpretation is not supported.';
end

if robust.pearsonLn_sign_flips == 0 && robust.spearmanLn_sign_flips == 0
    interpretation.robustness = 'The leave-one-out test preserves the sign of both `Pearson(lnA,B)` and `Spearman(lnA,B)` at every omitted temperature, so the qualitative conclusion is not driven by a single temperature point.';
else
    interpretation.robustness = 'The leave-one-out test changes the sign of at least one `ln(A)` correlation metric, so the barrier-like interpretation is sensitive to specific temperatures.';
end

if strengthA > strengthLn
    interpretation.logRelation = interpretation.logRelation + " In this run, the raw `A(T)` relation is actually stronger than the log-transformed one, which weakens the case for an exponential barrier picture.";
end
end

function txt = compareTightness(rowA, rowLn)
deltaR2 = rowLn.linear_r2(1) - rowA.linear_r2(1);
if deltaR2 > 0.10
    txt = sprintf('a noticeably higher linear R^2 (`+%.3f`)', deltaR2);
elseif deltaR2 > 0.02
    txt = sprintf('a slightly higher linear R^2 (`+%.3f`)', deltaR2);
elseif deltaR2 < -0.10
    txt = sprintf('a noticeably lower linear R^2 (`%.3f`)', deltaR2);
elseif deltaR2 < -0.02
    txt = sprintf('a slightly lower linear R^2 (`%.3f`)', deltaR2);
else
    txt = sprintf('a comparable linear R^2 (`%.3f` difference)', deltaR2);
end
end

function word = slopeSignWord(val)
if ~isfinite(val)
    word = 'undefined';
elseif val > 0
    word = 'positive';
elseif val < 0
    word = 'negative';
else
    word = 'zero';
end
end

function txt = describeComparison(pearsonR, spearmanR, slope, comparisonName)
metric = min(abs([pearsonR, spearmanR]));
if metric >= 0.75
    strength = "strong";
elseif metric >= 0.5
    strength = "moderate";
elseif metric >= 0.3
    strength = "weak-to-moderate";
else
    strength = "weak";
end

if slope > 0
    signText = "positive";
elseif slope < 0
    signText = "negative";
else
    signText = "flat";
end

if comparisonName == "lnA_vs_B"
    txt = sprintf('%s monotonic relation with %s linear slope in log-space', strength, signText);
else
    txt = sprintf('%s monotonic relation with %s linear slope', strength, signText);
end
end

function [slope, intercept, r2, rmsResidual] = linearFitStats(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
slope = NaN;
intercept = NaN;
r2 = NaN;
rmsResidual = NaN;
if nnz(mask) < 3
    return;
end

p = polyfit(x(mask), y(mask), 1);
yfit = polyval(p, x(mask));
resid = y(mask) - yfit;
ssRes = sum(resid .^ 2);
ssTot = sum((y(mask) - mean(y(mask))).^ 2);

slope = p(1);
intercept = p(2);
rmsResidual = sqrt(mean(resid .^ 2));
if ssTot > 0
    r2 = 1 - ssRes / ssTot;
end
end

function plotFitLine(ax, x, y, colorVal)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    return;
end
p = polyfit(x(mask), y(mask), 1);
xfit = linspace(min(x(mask)), max(x(mask)), 200);
yfit = polyval(p, xfit);
plot(ax, xfit, yfit, '--', 'Color', colorVal, 'LineWidth', 2.0, 'HandleVisibility', 'off');
end

function yNorm = normalizePositive(y, mask)
y = y(:);
mask = mask(:) & isfinite(y);
yNorm = NaN(size(y));
if ~any(mask)
    return;
end
maxVal = max(y(mask), [], 'omitnan');
if isfinite(maxVal) && maxVal > 0
    yNorm(mask) = y(mask) ./ maxVal;
end
end

function tf = signChanged(a, b)
if ~isfinite(a) || ~isfinite(b) || a == 0 || b == 0
    tf = false;
    return;
end
tf = sign(a) ~= sign(b);
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

function str = joinNumbers(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
    str = "";
    return;
end
parts = strings(numel(x), 1);
for i = 1:numel(x)
    if abs(x(i) - round(x(i))) < 1e-9
        parts(i) = sprintf('%.0f K', x(i));
    else
        parts(i) = sprintf('%.3g K', x(i));
    end
end
str = strjoin(parts.', ', ');
end
