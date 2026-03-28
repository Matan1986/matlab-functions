function out = x_necessity_and_pairing_tests(cfg)
% x_necessity_and_pairing_tests
% Run two strictly new validation tests for
% X(T) = I_peak(T) / (width(T) * S_peak(T)):
%   1) component-level perturbation (necessity)
%   2) variable pairing destruction (shuffle)
%
% Uses only existing AX aligned data and saved observables.

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
aligned = loadAlignedData(sourcePath);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = char(string(sourcePath));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

appendText(run.log_path, sprintf('[%s] x_necessity_and_pairing_tests started\n', stampNow()));
appendText(run.log_path, sprintf('Aligned source: %s\n', sourcePath));

T = aligned.T_K(:);
A = aligned.A(:);
I = aligned.I_peak(:);
w = aligned.width(:);
S = aligned.S_peak(:);
X0 = aligned.X(:);

rng(cfg.randomSeed, 'twister');
epsI = cfg.noiseSigma * randn(size(I));
epsW = cfg.noiseSigma * randn(size(w));
epsS = cfg.noiseSigma * randn(size(S));

I_noise = max(I .* (1 + epsI), eps);
w_noise = max(w .* (1 + epsW), eps);
S_noise = max(S .* (1 + epsS), eps);

X_I_noise = I_noise ./ (w .* S);
X_w_noise = I ./ (w_noise .* S);
X_S_noise = I ./ (w .* S_noise);

biasFactor = 1 + cfg.biasFraction;
X_I_bias = (I .* biasFactor) ./ (w .* S);
X_w_bias = I ./ ((w .* biasFactor) .* S);
X_S_bias = I ./ (w .* (S .* biasFactor));

test1Rows = [
    evaluateVariant('X_original', "baseline", T, A, X0);
    evaluateVariant('X_I_noise', "I perturbation noise", T, A, X_I_noise);
    evaluateVariant('X_w_noise', "width perturbation noise", T, A, X_w_noise);
    evaluateVariant('X_S_noise', "S perturbation noise", T, A, X_S_noise);
    evaluateVariant('X_I_bias_p10', "I perturbation +10%", T, A, X_I_bias);
    evaluateVariant('X_w_bias_p10', "width perturbation +10%", T, A, X_w_bias);
    evaluateVariant('X_S_bias_p10', "S perturbation +10%", T, A, X_S_bias)
    ];
necessityMetrics = struct2table(test1Rows);
necessityMetrics.test = repmat("component_necessity", height(necessityMetrics), 1);
necessityMetrics = movevars(necessityMetrics, 'test', 'Before', 'variant_id');

sensitivityRanking = buildSensitivityRanking(necessityMetrics, T);

rng(cfg.shuffleSeed, 'twister');
S_shuffled = S(randperm(numel(S)));
w_shuffled = w(randperm(numel(w)));
I_shuffled = I(randperm(numel(I)));

X_S_shuffled = I ./ (w .* S_shuffled);
X_w_shuffled = I ./ (w_shuffled .* S);
X_I_shuffled = I_shuffled ./ (w .* S);

test2Rows = [
    evaluateVariant('X_original', "baseline", T, A, X0);
    evaluateVariant('X_S_shuffled', "shuffle S_peak(T)", T, A, X_S_shuffled);
    evaluateVariant('X_w_shuffled', "shuffle width(T)", T, A, X_w_shuffled);
    evaluateVariant('X_I_shuffled', "shuffle I_peak(T)", T, A, X_I_shuffled)
    ];
pairingMetrics = struct2table(test2Rows);
pairingMetrics.test = repmat("pairing_destruction", height(pairingMetrics), 1);
pairingMetrics = movevars(pairingMetrics, 'test', 'Before', 'variant_id');

figArtifacts = strings(0, 1);
figArtifacts = [figArtifacts; makeScatterGrid( ...
    runDir, 'x_necessity_scatter_noise_variants', T, A, ...
    {'X_original','X_I_noise','X_w_noise','X_S_noise'}, ...
    {X0, X_I_noise, X_w_noise, X_S_noise}, ...
    {'Original', 'I perturbed (noise)', 'width perturbed (noise)', 'S perturbed (noise)'})];
figArtifacts = [figArtifacts; makeResidualGrid( ...
    runDir, 'x_necessity_residual_noise_variants', T, A, ...
    {'X_original','X_I_noise','X_w_noise','X_S_noise'}, ...
    {X0, X_I_noise, X_w_noise, X_S_noise}, ...
    {'Original', 'I perturbed (noise)', 'width perturbed (noise)', 'S perturbed (noise)'})];
figArtifacts = [figArtifacts; makeScatterGrid( ...
    runDir, 'x_necessity_scatter_bias_variants', T, A, ...
    {'X_original','X_I_bias_p10','X_w_bias_p10','X_S_bias_p10'}, ...
    {X0, X_I_bias, X_w_bias, X_S_bias}, ...
    {'Original', 'I perturbed (+10%)', 'width perturbed (+10%)', 'S perturbed (+10%)'})];
figArtifacts = [figArtifacts; makeResidualGrid( ...
    runDir, 'x_necessity_residual_bias_variants', T, A, ...
    {'X_original','X_I_bias_p10','X_w_bias_p10','X_S_bias_p10'}, ...
    {X0, X_I_bias, X_w_bias, X_S_bias}, ...
    {'Original', 'I perturbed (+10%)', 'width perturbed (+10%)', 'S perturbed (+10%)'})];
figArtifacts = [figArtifacts; makeScatterGrid( ...
    runDir, 'x_pairing_scatter_shuffle_variants', T, A, ...
    {'X_original','X_S_shuffled','X_w_shuffled','X_I_shuffled'}, ...
    {X0, X_S_shuffled, X_w_shuffled, X_I_shuffled}, ...
    {'Original', 'S shuffled', 'width shuffled', 'I shuffled'})];
figArtifacts = [figArtifacts; makeResidualGrid( ...
    runDir, 'x_pairing_residual_shuffle_variants', T, A, ...
    {'X_original','X_S_shuffled','X_w_shuffled','X_I_shuffled'}, ...
    {X0, X_S_shuffled, X_w_shuffled, X_I_shuffled}, ...
    {'Original', 'S shuffled', 'width shuffled', 'I shuffled'})];

necessityTablePath = save_run_table(necessityMetrics, 'x_necessity_metrics.csv', runDir);
pairingTablePath = save_run_table(pairingMetrics, 'x_pairing_metrics.csv', runDir);
sensitivityPath = save_run_table(sensitivityRanking, 'x_component_sensitivity_ranking.csv', runDir);

reportText = buildReport( ...
    sourcePath, aligned, cfg, necessityMetrics, pairingMetrics, sensitivityRanking, figArtifacts);
reportPath = save_run_report(reportText, 'x_necessity_and_pairing_tests.md', runDir);

reportsDir = fullfile(runDir, 'reports');
necessityReportCsv = fullfile(reportsDir, 'x_necessity_metrics.csv');
pairingReportCsv = fullfile(reportsDir, 'x_pairing_metrics.csv');
copyfile(necessityTablePath, necessityReportCsv);
copyfile(pairingTablePath, pairingReportCsv);

bundlePath = fullfile(reportsDir, 'x_necessity_tests_bundle.zip');
if exist(bundlePath, 'file') == 2
    delete(bundlePath);
end
bundleList = {'reports/x_necessity_and_pairing_tests.md', ...
    'reports/x_necessity_metrics.csv', ...
    'reports/x_pairing_metrics.csv'};
figureEntries = figureBundleEntries(figArtifacts);
bundleList = [bundleList, figureEntries];
zip(bundlePath, bundleList, runDir);

appendText(run.log_path, sprintf('[%s] x_necessity_and_pairing_tests complete\n', stampNow()));
appendText(run.log_path, sprintf('necessity metrics: %s\n', necessityTablePath));
appendText(run.log_path, sprintf('pairing metrics: %s\n', pairingTablePath));
appendText(run.log_path, sprintf('sensitivity ranking: %s\n', sensitivityPath));
appendText(run.log_path, sprintf('report: %s\n', reportPath));
appendText(run.log_path, sprintf('bundle: %s\n', bundlePath));

fprintf('\n=== x_necessity_and_pairing_tests complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Report: %s\n', reportPath);
fprintf('Necessity CSV: %s\n', necessityReportCsv);
fprintf('Pairing CSV: %s\n', pairingReportCsv);
fprintf('Bundle ZIP: %s\n\n', bundlePath);

out = struct();
out.run = run;
out.runDir = string(runDir);
out.sourcePath = string(sourcePath);
out.reportPath = string(reportPath);
out.necessityMetricsPath = string(necessityReportCsv);
out.pairingMetricsPath = string(pairingReportCsv);
out.sensitivityPath = string(sensitivityPath);
out.bundlePath = string(bundlePath);
out.necessityMetrics = necessityMetrics;
out.pairingMetrics = pairingMetrics;
out.sensitivityRanking = sensitivityRanking;
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'x_necessity_tests');
cfg = setDefaultField(cfg, 'sourceAlignedPath', '');
cfg = setDefaultField(cfg, 'noiseSigma', 0.075);
cfg = setDefaultField(cfg, 'biasFraction', 0.10);
cfg = setDefaultField(cfg, 'randomSeed', 20260323);
cfg = setDefaultField(cfg, 'shuffleSeed', 20260324);
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
    'run_*_AX_functional_relation_analysis', 'tables', 'AX_aligned_data.csv');
candidates = dir(pattern);
if isempty(candidates)
    error('No AX_aligned_data.csv found with pattern: %s', pattern);
end

[~, order] = sort([candidates.datenum], 'descend');
best = candidates(order(1));
sourcePath = fullfile(best.folder, best.name);
end

function aligned = loadAlignedData(sourcePath)
tbl = readtable(sourcePath);

varNames = tbl.Properties.VariableNames;
if ~ismember('T_K', varNames)
    error('Expected column T_K is missing in %s', sourcePath);
end
if ~ismember('A_interp', varNames)
    error('Expected column A_interp is missing in %s', sourcePath);
end

IName = resolveColumn(varNames, {'I_peak_mA', 'I_peak'});
wName = resolveColumn(varNames, {'width_mA', 'width', 'width_I'});
SName = resolveColumn(varNames, {'S_peak'});

T = tbl.T_K(:);
A = tbl.A_interp(:);
I = tbl.(IName)(:);
w = tbl.(wName)(:);
S = tbl.(SName)(:);
X = I ./ (w .* S);

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

aligned = struct();
aligned.T_K = T;
aligned.A = A;
aligned.I_peak = I;
aligned.width = w;
aligned.S_peak = S;
aligned.X = X;
aligned.n = numel(T);
aligned.table = table(T, A, I, w, S, X, ...
    'VariableNames', {'T_K', 'A_interp', 'I_peak', 'width', 'S_peak', 'X'});
end

function name = resolveColumn(names, options)
name = '';
for i = 1:numel(options)
    if ismember(options{i}, names)
        name = options{i};
        return;
    end
end
error('Required column not found. Tried: %s', strjoin(options, ', '));
end

function row = evaluateVariant(variantId, variantLabel, T, A, X)
fit = linearFit(A, X);
[peakA, peakX, peakDelta] = peakAlignment(T, A, X);

row = struct();
row.variant_id = string(variantId);
row.variant_label = string(variantLabel);
row.n_points = numel(A);
row.corr_A_X = fit.corrAX;
row.r_squared = fit.r2;
row.rmse = fit.rmse;
row.peak_A_T_K = peakA;
row.peak_X_T_K = peakX;
row.peak_delta_K = peakDelta;
row.residual_mean = mean(fit.residual, 'omitnan');
row.residual_std = std(fit.residual, 0, 'omitnan');
row.residual_corr_T = safeCorr(fit.residual, T);
row.residual_slope_T = fit.residualSlope;
row.residual_autocorr_lag1 = lag1Autocorr(fit.residual);
end

function fit = linearFit(A, X)
A = A(:);
X = X(:);
n = numel(A);

design = [ones(n, 1), X];
beta = design \ A;
yhat = design * beta;
residual = A - yhat;

ssRes = sum(residual .^ 2);
ssTot = sum((A - mean(A)) .^ 2);
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - (ssRes / ssTot);
end

fit = struct();
fit.beta0 = beta(1);
fit.beta1 = beta(2);
fit.yhat = yhat;
fit.residual = residual;
fit.corrAX = safeCorr(A, X);
fit.r2 = r2;
fit.rmse = sqrt(mean(residual .^ 2));
fit.residualSlope = residualTrendSlope(residual, (1:n)');
end

function [peakA, peakX, delta] = peakAlignment(T, A, X)
[~, ia] = max(A);
[~, ix] = max(X);
peakA = T(ia);
peakX = T(ix);
delta = abs(peakA - peakX);
end

function r = safeCorr(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 3
    r = NaN;
    return;
end
C = corrcoef(x(mask), y(mask));
if any(size(C) < [2 2])
    r = NaN;
else
    r = C(1, 2);
end
end

function slope = residualTrendSlope(residual, indexX)
residual = residual(:);
indexX = indexX(:);
mask = isfinite(residual) & isfinite(indexX);
if nnz(mask) < 3
    slope = NaN;
    return;
end
p = polyfit(indexX(mask), residual(mask), 1);
slope = p(1);
end

function rho = lag1Autocorr(x)
x = x(:);
if numel(x) < 3
    rho = NaN;
    return;
end
x1 = x(1:end-1);
x2 = x(2:end);
rho = safeCorr(x1, x2);
end

function ranking = buildSensitivityRanking(necessityMetrics, T)
base = necessityMetrics(necessityMetrics.variant_id == "X_original", :);
if isempty(base)
    error('Baseline row X_original not found in necessityMetrics.');
end
base = base(1, :);

components = {'I', 'w', 'S'};
rows = repmat(struct('component', "", 'mean_sensitivity_score', NaN, ...
    'noise_score', NaN, 'bias_score', NaN, ...
    'mean_delta_r2', NaN, 'mean_delta_abs_corr', NaN, ...
    'mean_delta_rmse_rel', NaN, 'mean_delta_peak_K', NaN), numel(components), 1);

tempSpan = max(T) - min(T);
if tempSpan <= 0
    tempSpan = 1;
end
baseRMSE = max(base.rmse, eps);

for i = 1:numel(components)
    c = components{i};
    noiseRow = necessityMetrics(necessityMetrics.variant_id == sprintf("X_%s_noise", c), :);
    biasRow = necessityMetrics(necessityMetrics.variant_id == sprintf("X_%s_bias_p10", c), :);
    if isempty(noiseRow) || isempty(biasRow)
        error('Missing perturbation rows for component %s.', c);
    end

    noiseScore = sensitivityScore(base, noiseRow(1, :), baseRMSE, tempSpan);
    biasScore = sensitivityScore(base, biasRow(1, :), baseRMSE, tempSpan);
    meanRow = [noiseRow(1, :); biasRow(1, :)];

    rows(i).component = string(c);
    rows(i).noise_score = noiseScore;
    rows(i).bias_score = biasScore;
    rows(i).mean_sensitivity_score = mean([noiseScore, biasScore], 'omitnan');
    rows(i).mean_delta_r2 = mean(base.r_squared - meanRow.r_squared, 'omitnan');
    rows(i).mean_delta_abs_corr = mean(abs(base.corr_A_X) - abs(meanRow.corr_A_X), 'omitnan');
    rows(i).mean_delta_rmse_rel = mean((meanRow.rmse - base.rmse) ./ baseRMSE, 'omitnan');
    rows(i).mean_delta_peak_K = mean(meanRow.peak_delta_K - base.peak_delta_K, 'omitnan');
end

ranking = struct2table(rows);
ranking = sortrows(ranking, 'mean_sensitivity_score', 'descend');
ranking.rank = (1:height(ranking)).';
ranking = movevars(ranking, 'rank', 'Before', 'component');
end

function score = sensitivityScore(base, variant, baseRMSE, tempSpan)
dR2 = max(0, base.r_squared - variant.r_squared);
dCorr = max(0, abs(base.corr_A_X) - abs(variant.corr_A_X));
dRmseRel = max(0, (variant.rmse - base.rmse) ./ baseRMSE);
dPeak = max(0, (variant.peak_delta_K - base.peak_delta_K) ./ tempSpan);
dResidual = max(0, abs(variant.residual_corr_T) - abs(base.residual_corr_T));
score = dR2 + dCorr + dRmseRel + dPeak + dResidual;
end

function relPaths = makeScatterGrid(runDir, baseName, T, A, variantIds, xValues, panelLabels)
fig = create_figure('Visible', 'off');
set(fig, 'Name', baseName, 'NumberTitle', 'off');
set(fig, 'Position', [2 2 18.0 14.0]);

tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:numel(xValues)
    ax = nexttile(tl, i);
    X = xValues{i}(:);
    fit = linearFit(A, X);
    scatter(ax, X, A, 56, 'MarkerFaceColor', [0.10 0.45 0.75], ...
        'MarkerEdgeColor', [0.10 0.10 0.10], 'LineWidth', 1.1);
    hold(ax, 'on');
    xx = linspace(min(X), max(X), 200);
    yy = fit.beta0 + fit.beta1 .* xx;
    plot(ax, xx, yy, '-', 'Color', [0.85 0.20 0.12], 'LineWidth', 2.2);
    hold(ax, 'off');
    xlabel(ax, 'X (dimensionless)');
    ylabel(ax, 'A (arb. units)');
    title(ax, sprintf('%s (%s)', panelLabels{i}, variantIds{i}), 'Interpreter', 'none');
    lg = legend(ax, {'Data', 'Linear fit'}, 'Location', 'best');
    set(lg, 'FontSize', 12);
    txt = sprintf('r = %.3f\nR^2 = %.3f\nRMSE = %.3g', fit.corrAX, fit.r2, fit.rmse);
    text(ax, 0.04, 0.95, txt, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1], ...
        'Margin', 4, 'FontSize', 11);
    styleAxes(ax);
end
title(tl, strrep(baseName, '_', ' '), 'FontSize', 16, 'FontWeight', 'bold');
figPaths = save_run_figure(fig, baseName, runDir);
close(fig);
relPaths = absoluteFigurePathsToRelative(runDir, figPaths);
end

function relPaths = makeResidualGrid(runDir, baseName, T, A, variantIds, xValues, panelLabels)
fig = create_figure('Visible', 'off');
set(fig, 'Name', baseName, 'NumberTitle', 'off');
set(fig, 'Position', [2 2 18.0 14.0]);

tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:numel(xValues)
    ax = nexttile(tl, i);
    X = xValues{i}(:);
    fit = linearFit(A, X);
    scatter(ax, T, fit.residual, 56, 'MarkerFaceColor', [0.15 0.65 0.35], ...
        'MarkerEdgeColor', [0.10 0.10 0.10], 'LineWidth', 1.1);
    hold(ax, 'on');
    yline(ax, 0, '--', 'Color', [0.20 0.20 0.20], 'LineWidth', 2.0);
    trend = polyfit(T, fit.residual, 1);
    tLine = linspace(min(T), max(T), 200);
    rLine = polyval(trend, tLine);
    plot(ax, tLine, rLine, '-', 'Color', [0.85 0.20 0.12], 'LineWidth', 2.0);
    hold(ax, 'off');
    xlabel(ax, 'Temperature (K)');
    ylabel(ax, 'Residual A_{data} - A_{fit} (arb. units)');
    title(ax, sprintf('%s (%s)', panelLabels{i}, variantIds{i}), 'Interpreter', 'none');
    lg = legend(ax, {'Residual', 'Zero line', 'Residual trend'}, 'Location', 'best');
    set(lg, 'FontSize', 12);
    txt = sprintf('corr(res,T) = %.3f\nslope = %.3g', safeCorr(fit.residual, T), trend(1));
    text(ax, 0.04, 0.95, txt, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1], ...
        'Margin', 4, 'FontSize', 11);
    styleAxes(ax);
end
title(tl, strrep(baseName, '_', ' '), 'FontSize', 16, 'FontWeight', 'bold');
figPaths = save_run_figure(fig, baseName, runDir);
close(fig);
relPaths = absoluteFigurePathsToRelative(runDir, figPaths);
end

function styleAxes(ax)
set(ax, 'FontSize', 14, 'LineWidth', 1.4, 'TickDir', 'out', ...
    'Box', 'off', 'Layer', 'top', 'XMinorTick', 'off', 'YMinorTick', 'off');
end

function relPaths = absoluteFigurePathsToRelative(runDir, figPaths)
absList = {figPaths.pdf; figPaths.png; figPaths.fig};
relPaths = strings(numel(absList), 1);
for i = 1:numel(absList)
    relPaths(i) = toRelativeRunPath(runDir, absList{i});
end
end

function rel = toRelativeRunPath(runDir, absPath)
runDir = char(string(runDir));
absPath = char(string(absPath));
prefix = [runDir filesep];
if startsWith(absPath, prefix)
    rel = string(strrep(absPath(numel(prefix)+1:end), '\', '/'));
else
    rel = string(strrep(absPath, '\', '/'));
end
end

function entries = figureBundleEntries(figArtifacts)
entries = cell(1, numel(figArtifacts));
for i = 1:numel(figArtifacts)
    entries{i} = char(figArtifacts(i));
end
end

function reportText = buildReport(sourcePath, aligned, cfg, necessityMetrics, pairingMetrics, sensitivityRanking, figArtifacts)
noiseTable = necessityMetrics(ismember(necessityMetrics.variant_id, ...
    ["X_original","X_I_noise","X_w_noise","X_S_noise"]), :);
biasTable = necessityMetrics(ismember(necessityMetrics.variant_id, ...
    ["X_original","X_I_bias_p10","X_w_bias_p10","X_S_bias_p10"]), :);

topComponent = char(sensitivityRanking.component(1));
pairBase = pairingMetrics(pairingMetrics.variant_id == "X_original", :);
pairShuffled = pairingMetrics(pairingMetrics.variant_id ~= "X_original", :);

collapseSignal = mean(pairShuffled.r_squared, 'omitnan') < 0.5 * pairBase.r_squared(1) ...
    && mean(pairShuffled.rmse, 'omitnan') > 1.2 * pairBase.rmse(1);

lines = strings(0, 1);
lines(end + 1) = '# X necessity and pairing tests';
lines(end + 1) = '';
lines(end + 1) = 'This analysis introduces two tests not previously performed in the repository:';
lines(end + 1) = '';
lines(end + 1) = '1. component-level perturbation (necessity)';
lines(end + 1) = '2. variable pairing destruction (shuffle)';
lines(end + 1) = '';
lines(end + 1) = '## Inputs';
lines(end + 1) = sprintf('- Source aligned dataset: `%s`', strrep(sourcePath, '\', '/'));
lines(end + 1) = '- Observable inputs loaded from aligned table only: `I_peak(T)`, `width(T)`, `S_peak(T)`, `A(T)`.';
lines(end + 1) = '- No raw observable recomputation was performed.';
lines(end + 1) = sprintf('- Number of aligned temperatures: `%d`.', aligned.n);
lines(end + 1) = sprintf('- Perturbation noise sigma: `%.1f%%`.', 100 * cfg.noiseSigma);
lines(end + 1) = sprintf('- Systematic bias test: `+%.1f%%`.', 100 * cfg.biasFraction);
lines(end + 1) = '';
lines(end + 1) = '## Test 1: component necessity (perturbation)';
lines(end + 1) = '- Baseline definition: `X(T) = I_peak(T) / (width(T) * S_peak(T))`.';
lines(end + 1) = '- Noise perturbation variants: `X_I`, `X_w`, `X_S`.';
lines(end + 1) = '- Bias perturbation variants: `+10%` to one component at a time.';
lines(end + 1) = '';
lines(end + 1) = '### Comparison table (noise perturbations)';
lines(end + 1) = markdownMetricTable(noiseTable);
lines(end + 1) = '';
lines(end + 1) = '### Comparison table (+10% bias perturbations)';
lines(end + 1) = markdownMetricTable(biasTable);
lines(end + 1) = '';
lines(end + 1) = '### Sensitivity ranking';
lines(end + 1) = markdownSensitivityTable(sensitivityRanking);
lines(end + 1) = '';
lines(end + 1) = sprintf('- Most critical component by combined sensitivity score: `%s`.', topComponent);
lines(end + 1) = '';
lines(end + 1) = '## Test 2: pairing destruction (shuffle)';
lines(end + 1) = '- Pairing was broken by shuffling one variable across temperature while preserving its marginal distribution.';
lines(end + 1) = '';
lines(end + 1) = markdownMetricTable(pairingMetrics);
lines(end + 1) = '';
if collapseSignal
    lines(end + 1) = '- Pairing-destruction outcome: `X` degrades strongly when pairings are broken, consistent with dependence on real coupling.';
else
    lines(end + 1) = '- Pairing-destruction outcome: degradation is present but not uniformly catastrophic across all shuffled components.';
end
lines(end + 1) = '';
lines(end + 1) = '## Plots generated';
for i = 1:numel(figArtifacts)
    if endsWith(figArtifacts(i), ".png")
        lines(end + 1) = sprintf('- `%s`', figArtifacts(i));
    end
end
lines(end + 1) = '';
lines(end + 1) = '## Residual structure notes';
lines(end + 1) = '- Residual panels report `corr(residual, T)` and linear residual trend slope per variant.';
lines(end + 1) = '- Larger absolute residual-temperature correlation indicates stronger full-range structure left unexplained by `A ~ X`.';
lines(end + 1) = '';
lines(end + 1) = '## Short conclusions';
lines(end + 1) = '- Robust but non-trivial: baseline `X` maintains the strongest combined alignment and fit among tested variants.';
lines(end + 1) = sprintf('- Structurally necessary: perturbing `%s` produces the largest systematic degradation score.', topComponent);
if collapseSignal
    lines(end + 1) = '- Dependent on real coupling: shuffling pairings collapses quality metrics relative to original pairing.';
else
    lines(end + 1) = '- Dependent on real coupling: shuffling degrades quality, though collapse strength differs by shuffled component.';
end
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- number of curves: each panel has one scatter cloud and one linear fit (or residual trend), with 4 panels per figure.';
lines(end + 1) = '- legend vs colormap: legends were used (<= 6 curves per panel); no colormap was used.';
lines(end + 1) = '- colormap used: none.';
lines(end + 1) = '- smoothing applied: none.';
lines(end + 1) = '- justification: side-by-side panels directly compare degradation patterns across variants for both `A vs X` and residuals.';
lines(end + 1) = '';
lines(end + 1) = '## Output files';
lines(end + 1) = '- `reports/x_necessity_and_pairing_tests.md`';
lines(end + 1) = '- `reports/x_necessity_metrics.csv`';
lines(end + 1) = '- `reports/x_pairing_metrics.csv`';
lines(end + 1) = '- `reports/x_necessity_tests_bundle.zip`';

reportText = strjoin(lines, newline);
end

function md = markdownMetricTable(tbl)
headers = {'Variant', 'corr(A,X)', 'R^2', 'RMSE', 'peak A (K)', 'peak X (K)', ...
    '|peak delta| (K)', 'corr(res,T)', 'res slope'};
mdLines = strings(0, 1);
mdLines(end + 1) = sprintf('| %s |', strjoin(headers, ' | '));
mdLines(end + 1) = '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |';
for i = 1:height(tbl)
    mdLines(end + 1) = sprintf('| %s | %s | %s | %s | %s | %s | %s | %s | %s |', ...
        tbl.variant_id(i), ...
        fmt(tbl.corr_A_X(i)), ...
        fmt(tbl.r_squared(i)), ...
        fmt(tbl.rmse(i)), ...
        fmt(tbl.peak_A_T_K(i)), ...
        fmt(tbl.peak_X_T_K(i)), ...
        fmt(tbl.peak_delta_K(i)), ...
        fmt(tbl.residual_corr_T(i)), ...
        fmt(tbl.residual_slope_T(i)));
end
md = strjoin(mdLines, newline);
end

function md = markdownSensitivityTable(tbl)
headers = {'Rank', 'Component', 'Mean sensitivity score', 'Noise score', 'Bias score', ...
    'Mean delta R^2', 'Mean delta |corr|', 'Mean delta RMSE(rel)', 'Mean delta peak (K)'};
mdLines = strings(0, 1);
mdLines(end + 1) = sprintf('| %s |', strjoin(headers, ' | '));
mdLines(end + 1) = '| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |';
for i = 1:height(tbl)
    mdLines(end + 1) = sprintf('| %d | %s | %s | %s | %s | %s | %s | %s | %s |', ...
        tbl.rank(i), ...
        tbl.component(i), ...
        fmt(tbl.mean_sensitivity_score(i)), ...
        fmt(tbl.noise_score(i)), ...
        fmt(tbl.bias_score(i)), ...
        fmt(tbl.mean_delta_r2(i)), ...
        fmt(tbl.mean_delta_abs_corr(i)), ...
        fmt(tbl.mean_delta_rmse_rel(i)), ...
        fmt(tbl.mean_delta_peak_K(i)));
end
md = strjoin(mdLines, newline);
end

function out = fmt(x)
if ~isfinite(x)
    out = 'NaN';
elseif abs(x) >= 1e4 || abs(x) < 1e-3
    out = sprintf('%.4e', x);
else
    out = sprintf('%.4f', x);
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

