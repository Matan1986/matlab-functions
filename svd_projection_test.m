function out = svd_projection_test(cfg)
% svd_projection_test
% Test whether X(T) can be explained as a projection of dominant
% low-dimensional structure in aligned switching observables.
%
% Uses only existing aligned cross-experiment tables.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
repoRoot = fileparts(thisFile);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg);
sourcePath = resolveAlignedSourcePath(repoRoot, cfg);
data = loadAlignedData(sourcePath);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = char(string(sourcePath));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('SVD projection test run directory:\n%s\n', runDir);
fprintf('Aligned source dataset:\n%s\n', sourcePath);

appendText(run.log_path, sprintf('[%s] svd_projection_test started\n', stampNow()));
appendText(run.log_path, sprintf('Aligned source: %s\n', sourcePath));
appendText(run.log_path, sprintf('No raw observables recomputed. Using aligned dataset only.\n'));

[svdData, modesTbl, loadingsTbl, componentTbl] = computeModes(data);

[rowAX, fitAX] = evaluateLinearComparison('A_vs_X', data.T, data.A, data.X, 'A', 'X');
[rowAM1, fitAM1] = evaluateLinearComparison('A_vs_Mode1', data.T, data.A, svdData.mode1, 'A', 'Mode1');
[rowXM1, ~] = evaluateLinearComparison('X_vs_Mode1', data.T, data.X, svdData.mode1, 'X', 'Mode1');
[rowX12, ~] = evaluateTwoModeModel('X_vs_Mode1_Mode2', data.T, data.X, svdData.mode1, svdData.mode2, 'X', 'Mode1+Mode2');

comparisonTbl = struct2table([rowAX; rowAM1; rowXM1; rowX12]);

modesPath = save_run_table(modesTbl, 'svd_modes.csv', runDir);
comparisonPath = save_run_table(comparisonTbl, 'comparison_metrics.csv', runDir);
loadingsPath = save_run_table(loadingsTbl, 'svd_loadings.csv', runDir);
componentPath = save_run_table(componentTbl, 'svd_component_summary.csv', runDir);

figAX = saveScatterFigure(runDir, 'A_vs_X', data.X, data.A, ...
    'X (dimensionless)', 'A (arb. units)', ...
    'A(T) vs X(T)', rowAX);
figAM1 = saveScatterFigure(runDir, 'A_vs_Mode1', svdData.mode1, data.A, ...
    'Mode1 score (a.u.)', 'A (arb. units)', ...
    'A(T) vs Mode1(T)', rowAM1);
figXM1 = saveScatterFigure(runDir, 'X_vs_Mode1', svdData.mode1, data.X, ...
    'Mode1 score (a.u.)', 'X (dimensionless)', ...
    'X(T) vs Mode1(T)', rowXM1);
figResidual = saveResidualFigure(runDir, 'residual_comparison', data.T, fitAX.residual, fitAM1.residual, rowAX, rowAM1);

[answers, classification] = answerCriticalQuestions(rowAX, rowAM1, rowXM1, rowX12);
reportText = buildReport(sourcePath, data, svdData, rowAX, rowAM1, rowXM1, rowX12, answers, classification);
reportPath = save_run_report(reportText, 'svd_projection_test_report.md', runDir);

zipPath = buildReviewZip(runDir, 'svd_projection_test_bundle.zip');

appendText(run.notes_path, sprintf('Source aligned dataset: %s\n', sourcePath));
appendText(run.notes_path, sprintf('Mode1 variance explained: %.4f\n', svdData.varianceExplained(1)));
appendText(run.notes_path, sprintf('Mode2 variance explained: %.4f\n', svdData.varianceExplained(2)));
appendText(run.notes_path, sprintf('Critical Q1: %s\n', answers.q1_short));
appendText(run.notes_path, sprintf('Critical Q2: %s\n', answers.q2_short));
appendText(run.notes_path, sprintf('Critical Q3: %s\n', answers.q3_short));
appendText(run.notes_path, sprintf('Critical Q4: %s\n', answers.q4_short));
appendText(run.notes_path, sprintf('Final classification: %s\n', classification));

appendText(run.log_path, sprintf('[%s] svd_projection_test complete\n', stampNow()));
appendText(run.log_path, sprintf('svd_modes.csv: %s\n', modesPath));
appendText(run.log_path, sprintf('comparison_metrics.csv: %s\n', comparisonPath));
appendText(run.log_path, sprintf('svd_loadings.csv: %s\n', loadingsPath));
appendText(run.log_path, sprintf('svd_component_summary.csv: %s\n', componentPath));
appendText(run.log_path, sprintf('report: %s\n', reportPath));
appendText(run.log_path, sprintf('zip: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.sourcePath = string(sourcePath);
out.tables = struct( ...
    'modes', string(modesPath), ...
    'comparison', string(comparisonPath), ...
    'loadings', string(loadingsPath), ...
    'components', string(componentPath));
out.figures = struct( ...
    'A_vs_X', string(figAX.png), ...
    'A_vs_Mode1', string(figAM1.png), ...
    'X_vs_Mode1', string(figXM1.png), ...
    'residual_comparison', string(figResidual.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.answers = answers;
out.classification = string(classification);
out.metrics = comparisonTbl;

fprintf('\n=== svd_projection_test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Mode1 variance explained: %.2f%%\n', 100 * svdData.varianceExplained(1));
fprintf('corr(X, Mode1): %.4f\n', rowXM1.pearson_r);
fprintf('R^2 A~X: %.4f | R^2 A~Mode1: %.4f\n', rowAX.r_squared, rowAM1.r_squared);
fprintf('Classification: %s\n', classification);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'svd_projection_test');
cfg = setDefaultField(cfg, 'sourceAlignedPath', '');
end

function sourcePath = resolveAlignedSourcePath(repoRoot, cfg)
if isfield(cfg, 'sourceAlignedPath') && ~isempty(cfg.sourceAlignedPath)
    sourcePath = char(string(cfg.sourceAlignedPath));
    if exist(sourcePath, 'file') ~= 2
        error('Configured sourceAlignedPath does not exist: %s', sourcePath);
    end
    return;
end

pattern = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_*_x_single_observable_residual_test*', 'tables', 'x_independence_aligned_data.csv');
candidates = dir(pattern);
if isempty(candidates)
    error('No aligned x_independence_aligned_data.csv found under cross_experiment runs.');
end

[~, order] = sort([candidates.datenum], 'descend');
best = candidates(order(1));
sourcePath = fullfile(best.folder, best.name);
end

function data = loadAlignedData(sourcePath)
tbl = readtable(sourcePath, 'VariableNamingRule', 'preserve');
names = tbl.Properties.VariableNames;

tName = resolveColumn(names, {'T', 'T_K', 'Temperature_K'});
aName = resolveColumn(names, {'A', 'A_interp', 'A_T'});
iName = resolveColumn(names, {'I_peak', 'I_peak_mA'});
wName = resolveColumn(names, {'width_I', 'width_mA', 'width'});
sName = resolveColumn(names, {'S_peak'});
xName = resolveColumnOptional(names, {'X', 'X_T'});

T = tbl.(tName)(:);
A = tbl.(aName)(:);
I = tbl.(iName)(:);
w = tbl.(wName)(:);
S = tbl.(sName)(:);
if ~isempty(xName)
    X = tbl.(xName)(:);
else
    X = I ./ (w .* S);
end

mask = isfinite(T) & isfinite(A) & isfinite(I) & isfinite(w) & isfinite(S) & isfinite(X);
mask = mask & A > 0 & I > 0 & w > 0 & S > 0 & X > 0;
if nnz(mask) < 6
    error('Too few valid aligned points remain after filtering.');
end

T = T(mask);
A = A(mask);
I = I(mask);
w = w(mask);
S = S(mask);
X = X(mask);

[T, order] = sort(T, 'ascend');
A = A(order);
I = I(order);
w = w(order);
S = S(order);
X = X(order);

data = struct();
data.T = T;
data.A = A;
data.I_peak = I;
data.width = w;
data.S_peak = S;
data.X = X;
end

function [svdData, modesTbl, loadingsTbl, componentTbl] = computeModes(data)
featureNames = {'I_peak', 'width', 'S_peak'};
M = [data.I_peak, data.width, data.S_peak];
mu = mean(M, 1, 'omitnan');
sigma = std(M, 0, 1, 'omitnan');
sigma(~isfinite(sigma) | sigma < eps) = 1;
Mz = (M - mu) ./ sigma;

[U, S, V] = svd(Mz, 'econ');
scores = U * S;
mode1 = scores(:, 1);
mode2 = scores(:, 2);

if safeCorr(mode1, data.A) < 0
    mode1 = -mode1;
    V(:, 1) = -V(:, 1);
end
if safeCorr(mode2, data.X) < 0
    mode2 = -mode2;
    V(:, 2) = -V(:, 2);
end

singVals = diag(S);
varExpl = (singVals .^ 2) ./ sum(singVals .^ 2);
cumVarExpl = cumsum(varExpl);

svdData = struct();
svdData.featureNames = featureNames;
svdData.mu = mu;
svdData.sigma = sigma;
svdData.V = V;
svdData.mode1 = mode1;
svdData.mode2 = mode2;
svdData.varianceExplained = varExpl(:);
svdData.cumulativeVariance = cumVarExpl(:);

modesTbl = table(data.T, data.A, data.X, data.I_peak, data.width, data.S_peak, ...
    Mz(:, 1), Mz(:, 2), Mz(:, 3), mode1, mode2, ...
    'VariableNames', {'T_K', 'A', 'X', 'I_peak', 'width', 'S_peak', ...
    'I_peak_z', 'width_z', 'S_peak_z', 'Mode1', 'Mode2'});

loadingsTbl = table(string(featureNames(:)), V(:, 1), V(:, 2), ...
    'VariableNames', {'feature', 'pc1_loading', 'pc2_loading'});

components = (1:numel(varExpl)).';
componentTbl = table(components, varExpl(:), cumVarExpl(:), singVals(:), ...
    'VariableNames', {'component', 'variance_explained', 'cumulative_variance', 'singular_value'});
end

function [row, fit] = evaluateLinearComparison(comparisonId, T, y, x, responseName, predictorName)
y = y(:);
x = x(:);
T = T(:);
mask = isfinite(T) & isfinite(y) & isfinite(x);
T = T(mask);
y = y(mask);
x = x(mask);

n = numel(y);
design = [ones(n, 1), x];
beta = design \ y;
yhat = design * beta;
residual = y - yhat;

fit = struct();
fit.y = y;
fit.x = x;
fit.T = T;
fit.yhat = yhat;
fit.residual = residual;
fit.slope = beta(2);
fit.intercept = beta(1);

row = initComparisonRow();
row.comparison_id = string(comparisonId);
row.response = string(responseName);
row.predictor = string(predictorName);
row.model_type = "linear_1d";
row.n_points = n;
row.pearson_r = safeCorr(y, x);
row.r_squared = computeR2(y, yhat);
row.rmse = sqrt(mean(residual .^ 2, 'omitnan'));
row.slope = beta(2);
row.intercept = beta(1);
row.beta_mode1 = NaN;
row.beta_mode2 = NaN;

[peakY, peakX, delta] = peakAlignment(T, y, x);
row.peak_response_T_K = peakY;
row.peak_predictor_T_K = peakX;
row.delta_T_peak_K = delta;
row.residual_mean = mean(residual, 'omitnan');
row.residual_std = std(residual, 0, 'omitnan');
row.residual_corr_T = safeCorr(residual, T);
end

function [row, fit] = evaluateTwoModeModel(comparisonId, T, y, mode1, mode2, responseName, predictorName)
y = y(:);
mode1 = mode1(:);
mode2 = mode2(:);
T = T(:);
mask = isfinite(T) & isfinite(y) & isfinite(mode1) & isfinite(mode2);
T = T(mask);
y = y(mask);
mode1 = mode1(mask);
mode2 = mode2(mask);

n = numel(y);
design = [ones(n, 1), mode1, mode2];
beta = design \ y;
yhat = design * beta;
residual = y - yhat;

fit = struct();
fit.y = y;
fit.T = T;
fit.yhat = yhat;
fit.residual = residual;
fit.intercept = beta(1);
fit.beta_mode1 = beta(2);
fit.beta_mode2 = beta(3);

row = initComparisonRow();
row.comparison_id = string(comparisonId);
row.response = string(responseName);
row.predictor = string(predictorName);
row.model_type = "linear_2d";
row.n_points = n;
row.pearson_r = safeCorr(y, yhat);
row.r_squared = computeR2(y, yhat);
row.rmse = sqrt(mean(residual .^ 2, 'omitnan'));
row.slope = NaN;
row.intercept = beta(1);
row.beta_mode1 = beta(2);
row.beta_mode2 = beta(3);

[peakY, peakYhat, delta] = peakAlignment(T, y, yhat);
row.peak_response_T_K = peakY;
row.peak_predictor_T_K = peakYhat;
row.delta_T_peak_K = delta;
row.residual_mean = mean(residual, 'omitnan');
row.residual_std = std(residual, 0, 'omitnan');
row.residual_corr_T = safeCorr(residual, T);
end

function row = initComparisonRow()
row = struct( ...
    'comparison_id', "", ...
    'response', "", ...
    'predictor', "", ...
    'model_type', "", ...
    'n_points', NaN, ...
    'pearson_r', NaN, ...
    'r_squared', NaN, ...
    'rmse', NaN, ...
    'slope', NaN, ...
    'intercept', NaN, ...
    'beta_mode1', NaN, ...
    'beta_mode2', NaN, ...
    'peak_response_T_K', NaN, ...
    'peak_predictor_T_K', NaN, ...
    'delta_T_peak_K', NaN, ...
    'residual_mean', NaN, ...
    'residual_std', NaN, ...
    'residual_corr_T', NaN);
end

function [peakY, peakX, delta] = peakAlignment(T, y, x)
[~, iy] = max(y);
[~, ix] = max(x);
peakY = T(iy);
peakX = T(ix);
delta = abs(peakY - peakX);
end

function figPaths = saveScatterFigure(runDir, baseName, x, y, xLabel, yLabel, titleText, row)
fig = create_figure('Visible', 'off', 'Name', baseName, 'NumberTitle', 'off');
set(fig, 'Position', [2 2 14 10]);
ax = axes(fig);

scatter(ax, x, y, 78, 'MarkerFaceColor', [0.10 0.45 0.75], ...
    'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 1.0);
hold(ax, 'on');
xLine = linspace(min(x), max(x), 200);
yLine = row.intercept + row.slope .* xLine;
plot(ax, xLine, yLine, '-', 'Color', [0.85 0.20 0.12], 'LineWidth', 2.4);
hold(ax, 'off');

xlabel(ax, xLabel);
ylabel(ax, yLabel);
title(ax, titleText);
legend(ax, {'Data', 'Linear fit'}, 'Location', 'best');

txt = sprintf('r = %.3f\\newlineR^2 = %.3f\\newlineRMSE = %.3g\\newline\\DeltaT_{peak} = %.1f K', ...
    row.pearson_r, row.r_squared, row.rmse, row.delta_T_peak_K);
text(ax, 0.03, 0.97, txt, 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1], ...
    'Margin', 4, 'FontSize', 12);

styleAxes(ax);
figPaths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPaths = saveResidualFigure(runDir, baseName, T, residualAX, residualAM1, rowAX, rowAM1)
fig = create_figure('Visible', 'off', 'Name', baseName, 'NumberTitle', 'off');
set(fig, 'Position', [2 2 14 10]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, T, residualAX, '-o', 'Color', [0.12 0.44 0.70], ...
    'MarkerFaceColor', [0.12 0.44 0.70], 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', sprintf('A~X residual (RMSE=%.3g)', rowAX.rmse));
plot(ax, T, residualAM1, '-s', 'Color', [0.86 0.24 0.12], ...
    'MarkerFaceColor', [0.86 0.24 0.12], 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', sprintf('A~Mode1 residual (RMSE=%.3g)', rowAM1.rmse));
yline(ax, 0, '--', 'Color', [0.15 0.15 0.15], 'LineWidth', 2.0, 'DisplayName', 'zero');
hold(ax, 'off');

xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Residual A_{data} - A_{fit} (arb. units)');
title(ax, 'Residual comparison: A vs X and A vs Mode1');
legend(ax, 'Location', 'best');
styleAxes(ax);

figPaths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function styleAxes(ax)
set(ax, 'FontSize', 14, 'LineWidth', 1.4, ...
    'TickDir', 'out', 'Box', 'off', 'Layer', 'top', ...
    'XMinorTick', 'off', 'YMinorTick', 'off');
end

function [answers, classification] = answerCriticalQuestions(rowAX, rowAM1, rowXM1, rowX12)
absCorrXM1 = abs(rowXM1.pearson_r);
deltaR2 = rowAM1.r_squared - rowAX.r_squared;
relRmseChange = (rowAM1.rmse - rowAX.rmse) / max(rowAX.rmse, eps);

peakGapDelta = rowAM1.delta_T_peak_K - rowAX.delta_T_peak_K;
r2Comparable = rowAM1.r_squared >= (rowAX.r_squared - 0.03);
rmseComparable = rowAM1.rmse <= (1.10 * rowAX.rmse);
peakComparable = rowAM1.delta_T_peak_K <= (rowAX.delta_T_peak_K + 1.0);

q1_yes = r2Comparable && rmseComparable && peakComparable;
q2_yes = absCorrXM1 >= 0.85;
q3_yes = (rowAM1.r_squared > rowAX.r_squared + 0.01) || ...
    (rowAM1.rmse < 0.95 * rowAX.rmse) || ...
    (rowAM1.delta_T_peak_K + 0.5 < rowAX.delta_T_peak_K);
q4_yes = (absCorrXM1 >= 0.90) || (rowX12.r_squared >= 0.95);

answers = struct();
if q1_yes
    answers.q1 = sprintf('Mode1 reproduces A approximately as well as X across the required metrics (delta R^2 = %.3f, delta RMSE = %.1f%%, delta peak shift = %.1f K).', ...
        deltaR2, 100 * relRmseChange, peakGapDelta);
else
    answers.q1 = sprintf('Mode1 improves regression fit (delta R^2 = %.3f, delta RMSE = %.1f%%) but is worse on peak alignment (delta peak shift = %.1f K), so it is not uniformly as good as X across all required metrics.', ...
        deltaR2, 100 * relRmseChange, peakGapDelta);
end
answers.q2 = ternaryText(q2_yes, ...
    sprintf('X is strongly aligned with Mode1 (|corr| = %.3f).', absCorrXM1), ...
    sprintf('X is not strongly aligned with Mode1 (|corr| = %.3f).', absCorrXM1));
answers.q3 = ternaryText(q3_yes, ...
    'Mode1 outperforms X in at least one required metric.', ...
    'Mode1 does not outperform X in the required metrics.');
answers.q4 = ternaryText(q4_yes, ...
    sprintf('X is largely reducible to low-dimensional projection (R^2[X~Mode1+Mode2] = %.3f).', rowX12.r_squared), ...
    sprintf('X is not well reducible to low-dimensional projection (R^2[X~Mode1+Mode2] = %.3f).', rowX12.r_squared));
answers.q1_short = ternaryShort(q1_yes);
answers.q2_short = ternaryShort(q2_yes);
answers.q3_short = ternaryShort(q3_yes);
answers.q4_short = ternaryShort(q4_yes);

if absCorrXM1 >= 0.95 && abs(deltaR2) <= 0.02 && abs(relRmseChange) <= 0.05
    classification = 'X is equivalent to Mode1 (projection)';
elseif absCorrXM1 >= 0.80 || rowX12.r_squared >= 0.90
    classification = 'X is partially aligned but richer';
else
    classification = 'X captures structure beyond Mode1';
end
end

function reportText = buildReport(sourcePath, data, svdData, rowAX, rowAM1, rowXM1, rowX12, answers, classification)
lines = strings(0, 1);
lines(end + 1) = '# SVD projection test';
lines(end + 1) = '';
lines(end + 1) = '## Scope';
lines(end + 1) = '- Goal: test whether success of X can be explained as projection onto dominant low-dimensional structure.';
lines(end + 1) = '- Inputs fixed to aligned observables only: `I_peak(T)`, `width(T)`, `S_peak(T)`, `A(T)`, `X(T)`.';
lines(end + 1) = '- No raw observable recomputation and no nonlinear models.';
lines(end + 1) = sprintf('- Source aligned table: `%s`.', strrep(sourcePath, '\\', '/'));
lines(end + 1) = sprintf('- Number of aligned temperature points: `%d`.', numel(data.T));
lines(end + 1) = '';
lines(end + 1) = '## Method';
lines(end + 1) = '- Feature matrix: `M(T,features) = [I_peak, width, S_peak]`.';
lines(end + 1) = '- Standardization: z-score each feature across temperature.';
lines(end + 1) = '- PCA/SVD: `M_z = U S V^T`; mode scores are `U*S`.';
lines(end + 1) = sprintf('- Mode1 explained variance: `%.2f%%`.', 100 * svdData.varianceExplained(1));
lines(end + 1) = sprintf('- Mode2 explained variance: `%.2f%%`.', 100 * svdData.varianceExplained(2));
lines(end + 1) = sprintf('- Cumulative variance (Mode1+Mode2): `%.2f%%`.', 100 * svdData.cumulativeVariance(2));
lines(end + 1) = '';
lines(end + 1) = '## Metrics summary';
lines(end + 1) = '| Comparison | Pearson r | R^2 | RMSE | Delta T_peak (K) |';
lines(end + 1) = '| --- | ---: | ---: | ---: | ---: |';
lines(end + 1) = sprintf('| A vs X | %.4f | %.4f | %.4g | %.2f |', rowAX.pearson_r, rowAX.r_squared, rowAX.rmse, rowAX.delta_T_peak_K);
lines(end + 1) = sprintf('| A vs Mode1 | %.4f | %.4f | %.4g | %.2f |', rowAM1.pearson_r, rowAM1.r_squared, rowAM1.rmse, rowAM1.delta_T_peak_K);
lines(end + 1) = sprintf('| X vs Mode1 | %.4f | %.4f | %.4g | %.2f |', rowXM1.pearson_r, rowXM1.r_squared, rowXM1.rmse, rowXM1.delta_T_peak_K);
lines(end + 1) = sprintf('| X vs (Mode1+Mode2) | %.4f | %.4f | %.4g | %.2f |', rowX12.pearson_r, rowX12.r_squared, rowX12.rmse, rowX12.delta_T_peak_K);
lines(end + 1) = '';
lines(end + 1) = '## Critical questions (mandatory)';
lines(end + 1) = sprintf('1. Does Mode1 reproduce A(T) as well as X? %s', answers.q1);
lines(end + 1) = sprintf('2. Is X strongly aligned with Mode1? %s', answers.q2);
lines(end + 1) = sprintf('3. Does Mode1 outperform X in any metric? %s', answers.q3);
lines(end + 1) = sprintf('4. Is X reducible to a low-dimensional projection? %s', answers.q4);
lines(end + 1) = '';
lines(end + 1) = '## Final conclusion';
lines(end + 1) = sprintf('- Classification: **%s**.', classification);
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- number of curves: each scatter panel uses one data cloud and one fit line; residual panel uses two residual curves plus zero reference.';
lines(end + 1) = '- legend vs colormap: legends used (<= 6 curves in every panel); no colormap used.';
lines(end + 1) = '- colormap used: none.';
lines(end + 1) = '- smoothing applied: none.';
lines(end + 1) = '- justification: direct pairwise comparisons isolate whether Mode1 captures the same structure as X, and residual overlay contrasts unexplained temperature structure.';
lines(end + 1) = '';
lines(end + 1) = '## Artifacts';
lines(end + 1) = '- `tables/svd_modes.csv`';
lines(end + 1) = '- `tables/comparison_metrics.csv`';
lines(end + 1) = '- `figures/A_vs_X.png`';
lines(end + 1) = '- `figures/A_vs_Mode1.png`';
lines(end + 1) = '- `figures/X_vs_Mode1.png`';
lines(end + 1) = '- `figures/residual_comparison.png`';
lines(end + 1) = '- `review/svd_projection_test_bundle.zip`';

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

zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function name = resolveColumn(names, options)
name = resolveColumnOptional(names, options);
if isempty(name)
    error('Missing required column. Tried: %s', strjoin(options, ', '));
end
end

function name = resolveColumnOptional(names, options)
name = '';
for i = 1:numel(options)
    if ismember(options{i}, names)
        name = options{i};
        return;
    end
end
end

function r = safeCorr(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 3
    r = NaN;
    return;
end
cc = corrcoef(x(mask), y(mask));
if numel(cc) < 4
    r = NaN;
else
    r = cc(1, 2);
end
end

function r2 = computeR2(y, yhat)
mask = isfinite(y) & isfinite(yhat);
if nnz(mask) < 3
    r2 = NaN;
    return;
end
y = y(mask);
yhat = yhat(mask);
ssRes = sum((y - yhat) .^ 2);
ssTot = sum((y - mean(y)) .^ 2);
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
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

function txt = ternaryText(condition, trueText, falseText)
if condition
    txt = trueText;
else
    txt = falseText;
end
end

function txt = ternaryShort(condition)
if condition
    txt = 'Yes';
else
    txt = 'No';
end
end

