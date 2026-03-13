function out = ax_scaling_temperature_robustness(cfg)
% ax_scaling_temperature_robustness
% Test whether the saved AX scaling relation holds uniformly across the
% temperature range using only saved aligned observables from the AX run.

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
source = resolveSourceRun(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('source:%s', char(source.sourceRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('AX scaling temperature robustness run directory:\n%s\n', runDir);
fprintf('Source AX run: %s\n', source.sourceRunName);

appendText(run.log_path, sprintf('[%s] AX scaling temperature robustness started\n', stampNow()));
appendText(run.log_path, sprintf('Source AX run: %s\n', char(source.sourceRunName)));

aligned = loadAlignedData(source.alignedPath);
savedParams = loadSavedParameters(source.parameterPath, source.modelPath);
globalFit = fitLogLog(aligned.lnX, aligned.lnA);
residualStatsTbl = buildResidualStatistics(aligned, globalFit, savedParams, cfg);
exclusionTbl = buildExclusionTable(aligned, cfg);
looTbl = buildLeaveOneOutTable(aligned);
manifestTbl = buildSourceManifestTable(source);

residualStatsPath = save_run_table(residualStatsTbl, 'residual_statistics.csv', runDir);
exclusionPath = save_run_table(exclusionTbl, 'beta_exclusion_tests.csv', runDir);
looPath = save_run_table(looTbl, 'beta_leave_one_temperature_out.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

fig1 = saveResidualTemperatureFigure(aligned, globalFit, cfg, runDir, 'residual_vs_temperature');
fig2 = saveTemperatureColoredLogLogFigure(aligned, globalFit, runDir, 'lnA_vs_lnX_temperature_colored');
fig3 = saveLeaveOneOutBetaFigure(looTbl, globalFit, cfg, runDir, 'beta_leave_one_temperature_out');

reportText = buildReportText(source, aligned, savedParams, globalFit, residualStatsTbl, exclusionTbl, looTbl, cfg);
reportPath = save_run_report(reportText, 'AX_scaling_temperature_robustness.md', runDir);
zipPath = buildReviewZip(runDir, 'AX_scaling_temperature_robustness_bundle.zip');

appendText(run.notes_path, sprintf('Source AX run: %s\n', char(source.sourceRunName)));
appendText(run.notes_path, sprintf('Saved beta = %.15g\n', savedParams.savedBeta));
appendText(run.notes_path, sprintf('Recovered beta = %.15g\n', globalFit.beta));
appendText(run.notes_path, sprintf('Peak-excluded beta = %.15g\n', exclusionTbl.beta(exclusionTbl.test == "excluding_peak_region")));
appendText(run.notes_path, sprintf('Leave-one-out beta mean/std = %.15g / %.15g\n', mean(looTbl.beta), std(looTbl.beta)));

appendText(run.log_path, sprintf('[%s] AX scaling temperature robustness complete\n', stampNow()));
appendText(run.log_path, sprintf('Residual statistics: %s\n', residualStatsPath));
appendText(run.log_path, sprintf('Exclusion table: %s\n', exclusionPath));
appendText(run.log_path, sprintf('Leave-one-out table: %s\n', looPath));
appendText(run.log_path, sprintf('Manifest: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.globalFit = globalFit;
out.exclusionTable = exclusionTbl;
out.leaveOneOutTable = looTbl;
out.residualStatistics = residualStatsTbl;
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.figures = struct('residuals', string(fig1.png), 'loglog', string(fig2.png), 'loo_beta', string(fig3.png));

fprintf('\n=== AX scaling temperature robustness complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Recovered beta: %.6f\n', globalFit.beta);
fprintf('Saved beta: %.6f\n', savedParams.savedBeta);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'AX_scaling_temperature_robustness');
cfg = setDefaultField(cfg, 'sourceRunName', 'run_2026_03_13_115401_AX_functional_relation_analysis');
cfg = setDefaultField(cfg, 'peakTempK', 26);
cfg = setDefaultField(cfg, 'peakHalfWidthK', 2);
cfg = setDefaultField(cfg, 'betaStabilityThreshold', 0.05);
end

function source = resolveSourceRun(repoRoot, cfg)
source = struct();
source.sourceRunName = string(cfg.sourceRunName);
source.sourceRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.sourceRunName));
source.alignedPath = fullfile(char(source.sourceRunDir), 'tables', 'AX_aligned_data.csv');
source.parameterPath = fullfile(char(source.sourceRunDir), 'tables', 'AX_parameter_estimates.csv');
source.modelPath = fullfile(char(source.sourceRunDir), 'tables', 'AX_model_comparison.csv');
source.reportPath = fullfile(char(source.sourceRunDir), 'reports', 'AX_functional_relation_analysis.md');

required = {source.sourceRunDir, source.alignedPath; source.sourceRunDir, source.parameterPath; source.sourceRunDir, source.modelPath};
for i = 1:size(required, 1)
    if exist(required{i, 1}, 'dir') ~= 7
        error('Required source run directory not found: %s', required{i, 1});
    end
    if exist(required{i, 2}, 'file') ~= 2
        error('Required source file not found: %s', required{i, 2});
    end
end
end

function aligned = loadAlignedData(csvPath)
tbl = readtable(csvPath);
tbl = sortrows(tbl, 'T_K');
aligned = struct();
aligned.table = tbl;
aligned.T_K = tbl.T_K(:);
aligned.A = tbl.A_interp(:);
aligned.X = tbl.X(:);
aligned.lnA = tbl.ln_A(:);
aligned.lnX = tbl.ln_X(:);
end

function saved = loadSavedParameters(parameterPath, modelPath)
paramTbl = readtable(parameterPath, 'TextType', 'string');
modelTbl = readtable(modelPath, 'TextType', 'string');
saved = struct();
saved.paramTbl = paramTbl;
saved.modelTbl = modelTbl;
saved.savedSlope = paramTbl.parameter_value(paramTbl.model_number == 3 & paramTbl.parameter_name == "a");
saved.savedIntercept = paramTbl.parameter_value(paramTbl.model_number == 3 & paramTbl.parameter_name == "b");
saved.savedPrefactor = paramTbl.parameter_value(paramTbl.model_number == 4 & paramTbl.parameter_name == "a");
saved.savedBeta = paramTbl.parameter_value(paramTbl.model_number == 4 & paramTbl.parameter_name == "b");
end

function fit = fitLogLog(lnX, lnA)
p = polyfit(lnX, lnA, 1);
yhat = polyval(p, lnX);
fit = struct();
fit.beta = p(1);
fit.intercept = p(2);
fit.prefactor = exp(p(2));
fit.yhat = yhat(:);
fit.residual = lnA(:) - fit.yhat;
fit.r_squared = computeR2(lnA, fit.yhat);
fit.rmse = sqrt(mean(fit.residual .^ 2));
fit.n = numel(lnA);
end

function residualStatsTbl = buildResidualStatistics(aligned, globalFit, savedParams, cfg)
peakMask = abs(aligned.T_K - cfg.peakTempK) < cfg.peakHalfWidthK;
nonPeakMask = ~peakMask;
trend = polyfit(aligned.T_K, globalFit.residual, 1);
residualStatsTbl = table( ...
    savedParams.savedBeta, globalFit.beta, abs(globalFit.beta - savedParams.savedBeta), ...
    globalFit.intercept, globalFit.prefactor, globalFit.r_squared, globalFit.rmse, ...
    mean(globalFit.residual), std(globalFit.residual), mean(abs(globalFit.residual)), max(abs(globalFit.residual)), ...
    trend(1), corrPearson(aligned.T_K, globalFit.residual), corrSpearman(aligned.T_K, globalFit.residual), ...
    nnz(peakMask), mean(abs(globalFit.residual(peakMask))), mean(abs(globalFit.residual(nonPeakMask))), ...
    'VariableNames', {'saved_beta','recovered_beta','abs_beta_difference','intercept','prefactor_C','r_squared_loglog','rmse_loglog', ...
    'residual_mean','residual_std','mean_abs_residual','max_abs_residual','residual_vs_temperature_slope','residual_temperature_pearson','residual_temperature_spearman', ...
    'peak_region_count','peak_region_mean_abs_residual','non_peak_mean_abs_residual'});
end

function exclusionTbl = buildExclusionTable(aligned, cfg)
T = aligned.T_K(:);
maskList = {
    true(size(T)), 'full_dataset', 'All saved aligned temperatures';
    abs(T - cfg.peakTempK) >= cfg.peakHalfWidthK, 'excluding_peak_region', '|T - 26 K| >= 2 K';
    T <= cfg.peakTempK, 'excluding_high_temperatures', 'Exclude T > 26 K';
    T >= cfg.peakTempK, 'excluding_low_temperatures', 'Exclude T < 26 K'
    };

rows = repmat(struct('test', "", 'n_points', NaN, 'temperature_min_K', NaN, 'temperature_max_K', NaN, 'beta', NaN, 'intercept', NaN, 'prefactor_C', NaN, 'r_squared_loglog', NaN, 'rmse_loglog', NaN, 'subset_note', ""), size(maskList, 1), 1);
for i = 1:size(maskList, 1)
    mask = maskList{i, 1};
    fit = fitLogLog(aligned.lnX(mask), aligned.lnA(mask));
    rows(i).test = string(maskList{i, 2});
    rows(i).n_points = nnz(mask);
    rows(i).temperature_min_K = min(aligned.T_K(mask));
    rows(i).temperature_max_K = max(aligned.T_K(mask));
    rows(i).beta = fit.beta;
    rows(i).intercept = fit.intercept;
    rows(i).prefactor_C = fit.prefactor;
    rows(i).r_squared_loglog = fit.r_squared;
    rows(i).rmse_loglog = fit.rmse;
    rows(i).subset_note = string(maskList{i, 3});
end
exclusionTbl = struct2table(rows);
end
function looTbl = buildLeaveOneOutTable(aligned)
n = numel(aligned.T_K);
rows = repmat(struct('removed_T_K', NaN, 'beta', NaN, 'intercept', NaN, 'prefactor_C', NaN, 'r_squared_loglog', NaN, 'rmse_loglog', NaN), n, 1);
for i = 1:n
    mask = true(n, 1);
    mask(i) = false;
    fit = fitLogLog(aligned.lnX(mask), aligned.lnA(mask));
    rows(i).removed_T_K = aligned.T_K(i);
    rows(i).beta = fit.beta;
    rows(i).intercept = fit.intercept;
    rows(i).prefactor_C = fit.prefactor;
    rows(i).r_squared_loglog = fit.r_squared;
    rows(i).rmse_loglog = fit.rmse;
end
looTbl = struct2table(rows);
looTbl = sortrows(looTbl, 'removed_T_K');
end

function manifestTbl = buildSourceManifestTable(source)
manifestTbl = table( ...
    repmat("cross_experiment", 4, 1), ...
    repmat(source.sourceRunName, 4, 1), ...
    [string(source.alignedPath); string(source.parameterPath); string(source.modelPath); string(source.reportPath)], ...
    ["saved aligned AX data"; "saved AX parameter table"; "saved AX model ranking table"; "saved AX report"], ...
    'VariableNames', {'experiment','source_run','source_file','role'});
end

function figPaths = saveResidualTemperatureFigure(aligned, globalFit, cfg, runDir, figureName)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, aligned.T_K, globalFit.residual, '-o', 'Color', [0.80 0.24 0.17], 'MarkerFaceColor', [0.80 0.24 0.17], 'LineWidth', 1.8, 'MarkerSize', 5);
yline(ax, 0, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.1);
xline(ax, cfg.peakTempK, ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.1);
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Residual in ln(A)');
title(ax, 'Residual vs temperature for ln(A) = beta ln(X) + b');
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveTemperatureColoredLogLogFigure(aligned, globalFit, runDir, figureName)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
scatter(ax, aligned.lnX, aligned.lnA, 58, aligned.T_K, 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.6);
hold(ax, 'on');
xFit = linspace(min(aligned.lnX), max(aligned.lnX), 250);
plot(ax, xFit, globalFit.beta .* xFit + globalFit.intercept, '-', 'Color', [0 0 0], 'LineWidth', 1.8);
hold(ax, 'off');
xlabel(ax, 'ln(X(T))');
ylabel(ax, 'ln(A(T))');
title(ax, 'ln(A) vs ln(X), colored by temperature');
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
colormap(ax, parula(256));
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveLeaveOneOutBetaFigure(looTbl, globalFit, cfg, runDir, figureName)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, looTbl.removed_T_K, looTbl.beta, '-o', 'Color', [0.02 0.37 0.67], 'MarkerFaceColor', [0.02 0.37 0.67], 'LineWidth', 1.8, 'MarkerSize', 5);
yline(ax, globalFit.beta, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.1);
xline(ax, cfg.peakTempK, ':', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.1);
hold(ax, 'off');
xlabel(ax, 'Removed temperature (K)');
ylabel(ax, 'Refit exponent beta');
title(ax, 'Leave-one-temperature-out stability of beta');
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function reportText = buildReportText(source, aligned, savedParams, globalFit, residualStatsTbl, exclusionTbl, looTbl, cfg)
peakRow = exclusionTbl(exclusionTbl.test == "excluding_peak_region", :);
highRow = exclusionTbl(exclusionTbl.test == "excluding_high_temperatures", :);
lowRow = exclusionTbl(exclusionTbl.test == "excluding_low_temperatures", :);
looMean = mean(looTbl.beta);
looStd = std(looTbl.beta);
looMin = min(looTbl.beta);
looMax = max(looTbl.beta);
peakDelta = peakRow.beta(1) - globalFit.beta;
highDelta = highRow.beta(1) - globalFit.beta;
lowDelta = lowRow.beta(1) - globalFit.beta;

if abs(peakDelta) <= cfg.betaStabilityThreshold
    peakAnswer = sprintf('Yes. Excluding the peak region changes beta by only %.4f (from %.4f to %.4f).', peakDelta, globalFit.beta, peakRow.beta(1));
else
    peakAnswer = sprintf('No. Excluding the peak region changes beta by %.4f (from %.4f to %.4f).', peakDelta, globalFit.beta, peakRow.beta(1));
end

if abs(residualStatsTbl.residual_temperature_pearson(1)) < 0.3 && abs(residualStatsTbl.residual_temperature_spearman(1)) < 0.3
    residualAnswer = 'Residuals do not show a strong monotonic temperature trend; the full-range scaling is not obviously driven by a systematic residual drift with temperature.';
else
    residualAnswer = 'Residuals show a noticeable temperature trend, so the scaling is not perfectly uniform across temperature.';
end

if max(abs([peakDelta, highDelta, lowDelta])) <= 0.08 && (looMax - looMin) <= 0.12
    dominanceAnswer = 'No single temperature subset appears to dominate the fit. The exponent stays in a relatively narrow band under the exclusion and leave-one-out tests.';
else
    dominanceAnswer = 'At least one temperature subset shifts beta appreciably, so the fitted scaling should be interpreted with some subset sensitivity in mind.';
end

lines = strings(0, 1);
lines(end + 1) = '# AX scaling temperature robustness';
lines(end + 1) = '';
lines(end + 1) = '## Inputs';
lines(end + 1) = sprintf('- Source AX run: `%s`.', char(source.sourceRunName));
lines(end + 1) = '- Loaded only saved aligned data from `tables/AX_aligned_data.csv`; no switching observables were recomputed.';
lines(end + 1) = sprintf('- Saved source beta from the earlier run: `%.15g`.', savedParams.savedBeta);
lines(end + 1) = '';
lines(end + 1) = '## Global fit reproduction';
lines(end + 1) = sprintf('- Recovered fit to the saved aligned data: `ln(A) = beta ln(X) + b` with `beta = %.15g`, `b = %.15g`, `R^2 = %.6f`, and `RMSE = %.6g` on the log-log variables.', ...
    globalFit.beta, globalFit.intercept, globalFit.r_squared, globalFit.rmse);
lines(end + 1) = sprintf('- Consistency with the saved run: `|beta_recovered - beta_saved| = %.3g`.', abs(globalFit.beta - savedParams.savedBeta));
lines(end + 1) = '';
lines(end + 1) = '## Residual analysis';
lines(end + 1) = sprintf('- Residual mean = `%.3g`, residual std = `%.3g`, max |residual| = `%.3g`.', residualStatsTbl.residual_mean(1), residualStatsTbl.residual_std(1), residualStatsTbl.max_abs_residual(1));
lines(end + 1) = sprintf('- Residual vs temperature Pearson = `%.3f`, Spearman = `%.3f`, linear-trend slope = `%.3g` per K.', ...
    residualStatsTbl.residual_temperature_pearson(1), residualStatsTbl.residual_temperature_spearman(1), residualStatsTbl.residual_vs_temperature_slope(1));
lines(end + 1) = sprintf('- Mean |residual| inside the peak region = `%.3g`; outside the peak region = `%.3g`.', ...
    residualStatsTbl.peak_region_mean_abs_residual(1), residualStatsTbl.non_peak_mean_abs_residual(1));
lines(end + 1) = sprintf('- Interpretation: %s', residualAnswer);
lines(end + 1) = '';
lines(end + 1) = '## Exclusion tests';
lines(end + 1) = '| test | n | beta | delta beta vs full | R^2 | note |';
lines(end + 1) = '| --- | ---: | ---: | ---: | ---: | --- |';
for i = 1:height(exclusionTbl)
    lines(end + 1) = sprintf('| %s | %d | %.6f | %.6f | %.6f | %s |', exclusionTbl.test(i), exclusionTbl.n_points(i), exclusionTbl.beta(i), exclusionTbl.beta(i) - globalFit.beta, exclusionTbl.r_squared_loglog(i), exclusionTbl.subset_note(i));
end
lines(end + 1) = sprintf('- Peak exclusion stability: %s', peakAnswer);
lines(end + 1) = sprintf('- High-temperature exclusion shifts beta by `%.4f`; low-temperature exclusion shifts beta by `%.4f`.', highDelta, lowDelta);
lines(end + 1) = '';
lines(end + 1) = '## Leave-one-temperature-out test';
lines(end + 1) = sprintf('- Leave-one-out beta mean = `%.6f`, std = `%.6f`, min = `%.6f`, max = `%.6f`.', looMean, looStd, looMin, looMax);
lines(end + 1) = sprintf('- Maximum single-temperature shift relative to the full fit = `%.6f`.', max(abs(looTbl.beta - globalFit.beta)));
lines(end + 1) = '';
lines(end + 1) = '## Answers';
lines(end + 1) = sprintf('1. Does the scaling hold across the entire temperature range? %s', residualAnswer);
lines(end + 1) = sprintf('2. Is the exponent beta stable when excluding the peak region? %s', peakAnswer);
lines(end + 1) = sprintf('3. Is the fit dominated by any specific temperature subset? %s', dominanceAnswer);
lines(end + 1) = '';
lines(end + 1) = '## Assumption used for one-sided exclusion tests';
lines(end + 1) = '- `excluding_high_temperatures` means removing all points with `T > 26 K`.';
lines(end + 1) = '- `excluding_low_temperatures` means removing all points with `T < 26 K`.';
lines(end + 1) = '- The second case leaves only the high-temperature side and the peak point, so it is intentionally a harsher and less well-constrained stress test.';
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- number of curves: one residual trace, one temperature-colored scatter cloud with one fit line, and one leave-one-out beta trace.';
lines(end + 1) = '- legend vs colormap: the log-log scatter uses a labeled temperature colorbar because 14 temperatures are shown; the one-dimensional diagnostics use direct labels and guide lines instead of legends.';
lines(end + 1) = '- colormap used: `parula`.';
lines(end + 1) = '- smoothing applied: none; the analysis uses saved aligned observables from the previous AX run.';
lines(end + 1) = '- justification: the figure set isolates residual structure, leverage of individual temperatures, and the full temperature-colored collapse in the same saved coordinate system.';
lines(end + 1) = '';
lines(end + 1) = '## Output files';
lines(end + 1) = '- `tables/beta_exclusion_tests.csv`';
lines(end + 1) = '- `tables/residual_statistics.csv`';
lines(end + 1) = '- `tables/beta_leave_one_temperature_out.csv`';
lines(end + 1) = '- `figures/residual_vs_temperature.png`';
lines(end + 1) = '- `figures/lnA_vs_lnX_temperature_colored.png`';
lines(end + 1) = '- `figures/beta_leave_one_temperature_out.png`';
lines(end + 1) = '- `reports/AX_scaling_temperature_robustness.md`';

reportText = strjoin(lines, newline);
end
function value = corrPearson(x, y)
mask = isfinite(x) & isfinite(y);
value = NaN;
if nnz(mask) < 2
    return;
end
cc = corrcoef(x(mask), y(mask));
if numel(cc) >= 4
    value = cc(1, 2);
end
end

function value = corrSpearman(x, y)
value = corrPearson(tiedRank(x), tiedRank(y));
end

function ranks = tiedRank(x)
x = x(:);
ranks = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end
[xs, order] = sort(x(valid));
rankVals = zeros(size(xs));
i = 1;
while i <= numel(xs)
    j = i;
    while j < numel(xs) && xs(j + 1) == xs(i)
        j = j + 1;
    end
    rankVals(i:j) = mean(i:j);
    i = j + 1;
end
tmp = zeros(size(xs));
tmp(order) = rankVals;
ranks(valid) = tmp;
end

function r2 = computeR2(y, yhat)
ssRes = sum((y(:) - yhat(:)) .^ 2);
ssTot = sum((y(:) - mean(y(:))) .^ 2);
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
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
zip(zipPath, {'tables', 'figures', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function styleAxes(ax)
set(ax, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top', 'XMinorTick', 'off', 'YMinorTick', 'off');
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

function cfg = setDefaultField(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
