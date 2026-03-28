function out = run_perturbative_closure_test()
%RUN_PERTURBATIVE_CLOSURE_TEST
% AGENT 18A: perturbative closure test on switching residual structure.
%
% Models:
%   M1: PT backbone only (no residual mode term)
%   M2: PT + kappa1(T)*Phi1
%   M3: PT + kappa1(T)*Phi1 + kappa2(T)*Phi2
%
% Holdout protocol:
%   For each temperature row, fit coefficients on odd x-grid indices and
%   evaluate on even x-grid indices.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'analysis'));

set(0, 'DefaultFigureVisible', 'off');

% Rebuild decomposition in read-only spirit from existing source runs.
cfg = struct();
cfg.runLabel = 'agent18a_closure_support';
cfg.alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
cfg.fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
cfg.ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';
cfg.canonicalMaxTemperatureK = 30;
cfg.nXGrid = 220;
cfg.maxModes = 2;
dec = switching_residual_decomposition_analysis(cfg);

temps = dec.temperaturesK(:);
lowMask = logical(dec.lowTemperatureMask(:));
T_eval = temps(lowMask);
Rall = dec.Rall(lowMask, :);  % residual in x-grid representation
phi1 = dec.phi(:);
phi2 = dec.phi2(:);

if isempty(phi2) || all(~isfinite(phi2))
    error('Mode-2 phi was not available from decomposition output.');
end

nX = numel(phi1);
idxTrain = mod((1:nX)', 2) == 1;
idxTest = ~idxTrain;

if nnz(idxTrain) < 5 || nnz(idxTest) < 5
    error('Insufficient train/test split points on x-grid.');
end

nT = numel(T_eval);
rmse_M1 = nan(nT, 1);
rmse_M2 = nan(nT, 1);
rmse_M3 = nan(nT, 1);
corr_M1 = nan(nT, 1);
corr_M2 = nan(nT, 1);
corr_M3 = nan(nT, 1);
kappa1_M2 = nan(nT, 1);
kappa1_M3 = nan(nT, 1);
kappa2_M3 = nan(nT, 1);

for it = 1:nT
    y = Rall(it, :)';
    m = isfinite(y) & isfinite(phi1) & isfinite(phi2);
    tr = m & idxTrain;
    te = m & idxTest;
    if nnz(tr) < 6 || nnz(te) < 6
        continue;
    end

    ytr = y(tr);
    yte = y(te);
    p1tr = phi1(tr);
    p1te = phi1(te);
    p2tr = phi2(tr);
    p2te = phi2(te);

    % M1 residual prediction is zero (PT backbone only).
    yhat1 = zeros(size(yte));
    rmse_M1(it) = sqrt(mean((yte - yhat1).^2, 'omitnan'));
    corr_M1(it) = corrSafe(yte, yhat1);

    % M2: single mode coefficient.
    denom1 = sum(p1tr.^2, 'omitnan');
    if denom1 > eps
        a1 = sum(ytr .* p1tr, 'omitnan') / denom1;
    else
        a1 = NaN;
    end
    yhat2 = a1 * p1te;
    kappa1_M2(it) = a1;
    rmse_M2(it) = sqrt(mean((yte - yhat2).^2, 'omitnan'));
    corr_M2(it) = corrSafe(yte, yhat2);

    % M3: two-mode fit.
    Xtr = [p1tr, p2tr];
    if rank(Xtr) >= 2
        b = Xtr \ ytr;
    else
        b = pinv(Xtr) * ytr;
    end
    yhat3 = [p1te, p2te] * b;
    kappa1_M3(it) = b(1);
    kappa2_M3(it) = b(2);
    rmse_M3(it) = sqrt(mean((yte - yhat3).^2, 'omitnan'));
    corr_M3(it) = corrSafe(yte, yhat3);
end

tblPerT = table(T_eval, rmse_M1, rmse_M2, rmse_M3, corr_M1, corr_M2, corr_M3, ...
    kappa1_M2, kappa1_M3, kappa2_M3, ...
    'VariableNames', {'T_K', 'rmse_M1', 'rmse_M2', 'rmse_M3', ...
    'corr_M1', 'corr_M2', 'corr_M3', 'kappa1_M2', 'kappa1_M3', 'kappa2_M3'});

agg = table( ...
    string({'M1_PT_only'; 'M2_PT_plus_kappaPhi1'; 'M3_PT_plus_kappa1Phi1_plus_kappa2Phi2'}), ...
    [mean(rmse_M1, 'omitnan'); mean(rmse_M2, 'omitnan'); mean(rmse_M3, 'omitnan')], ...
    [median(rmse_M1, 'omitnan'); median(rmse_M2, 'omitnan'); median(rmse_M3, 'omitnan')], ...
    [mean(corr_M1, 'omitnan'); mean(corr_M2, 'omitnan'); mean(corr_M3, 'omitnan')], ...
    [median(corr_M1, 'omitnan'); median(corr_M2, 'omitnan'); median(corr_M3, 'omitnan')], ...
    'VariableNames', {'model', 'rmse_mean', 'rmse_median', 'corr_mean', 'corr_median'});

imp_M2_vs_M1_rmse = relImprove(mean(rmse_M1, 'omitnan'), mean(rmse_M2, 'omitnan'));
imp_M3_vs_M2_rmse = relImprove(mean(rmse_M2, 'omitnan'), mean(rmse_M3, 'omitnan'));
imp_M2_vs_M1_corr = mean(corr_M2, 'omitnan') - mean(corr_M1, 'omitnan');
imp_M3_vs_M2_corr = mean(corr_M3, 'omitnan') - mean(corr_M2, 'omitnan');

cmp = table( ...
    string({'M2_vs_M1'; 'M3_vs_M2'}), ...
    [imp_M2_vs_M1_rmse; imp_M3_vs_M2_rmse], ...
    [imp_M2_vs_M1_corr; imp_M3_vs_M2_corr], ...
    'VariableNames', {'comparison', 'rmse_relative_improvement', 'corr_delta'});

closureMetrics = [agg; ...
    table("M2_vs_M1", imp_M2_vs_M1_rmse, NaN, imp_M2_vs_M1_corr, NaN, ...
    'VariableNames', agg.Properties.VariableNames); ...
    table("M3_vs_M2", imp_M3_vs_M2_rmse, NaN, imp_M3_vs_M2_corr, NaN, ...
    'VariableNames', agg.Properties.VariableNames)];

tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(figuresDir, 'dir') ~= 7, mkdir(figuresDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

csvPath = fullfile(tablesDir, 'closure_metrics.csv');
writetable(closureMetrics, csvPath);
writetable(tblPerT, fullfile(tablesDir, 'closure_metrics_per_temperature.csv'));
writetable(cmp, fullfile(tablesDir, 'closure_improvement.csv'));

fig = figure('Name', 'closure_comparison', 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'centimeters', 'Position', [2 2 15 7]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
bar([mean(rmse_M1, 'omitnan'), mean(rmse_M2, 'omitnan'), mean(rmse_M3, 'omitnan')], ...
    'FaceColor', [0.2 0.45 0.7]);
set(gca, 'XTick', 1:3, 'XTickLabel', {'M1', 'M2', 'M3'});
ylabel('Holdout RMSE(S)');
title('Lower is better');
styleAx(gca);

nexttile;
bar([mean(corr_M1, 'omitnan'), mean(corr_M2, 'omitnan'), mean(corr_M3, 'omitnan')], ...
    'FaceColor', [0.75 0.35 0.2]);
set(gca, 'XTick', 1:3, 'XTickLabel', {'M1', 'M2', 'M3'});
ylabel('Holdout correlation(S)');
title('Higher is better');
styleAx(gca);

pngPath = fullfile(figuresDir, 'closure_comparison.png');
exportgraphics(fig, pngPath, 'Resolution', 200);
close(fig);

rank2Improves = isfinite(imp_M3_vs_M2_rmse) && (imp_M3_vs_M2_rmse > 0.02) && (imp_M3_vs_M2_corr > 0);
closureAchieved = rank2Improves && (mean(corr_M3, 'omitnan') >= 0.90) && (mean(rmse_M3, 'omitnan') <= 0.60 * mean(rmse_M1, 'omitnan'));
residualRequired = isfinite(imp_M2_vs_M1_rmse) && imp_M2_vs_M1_rmse > 0.05;

reportPath = fullfile(reportsDir, 'closure_report.md');
fid = fopen(reportPath, 'w');
fprintf(fid, '# Perturbative Closure Test\n\n');
fprintf(fid, '## Goal\n');
fprintf(fid, 'Test whether adding rank-2 residual mode yields predictive closure beyond rank-1.\n\n');
fprintf(fid, '## Inputs\n');
fprintf(fid, '- PT-based backbone from CDF reconstruction in `switching_residual_decomposition_analysis`.\n');
fprintf(fid, '- `Phi1` and `Phi2` from residual SVD mode extraction.\n');
fprintf(fid, '- Data matrix `S(I,T)` through residual representation on common x-grid.\n');
fprintf(fid, '- Canonical temperature window: T <= %.1f K.\n\n', cfg.canonicalMaxTemperatureK);
fprintf(fid, '## Holdout protocol\n');
fprintf(fid, '- Per temperature: fit coefficients on odd x-grid indices.\n');
fprintf(fid, '- Evaluate RMSE and Pearson correlation on even x-grid indices.\n\n');
fprintf(fid, '## Aggregate metrics\n\n');
fprintf(fid, '%s\n\n', evalc('disp(agg)'));
fprintf(fid, '## Improvement\n\n');
fprintf(fid, '%s\n\n', evalc('disp(cmp)'));
fprintf(fid, '## Final Verdict\n');
fprintf(fid, '- RANK2_IMPROVES_PREDICTION: **%s**\n', yn(rank2Improves));
fprintf(fid, '- CLOSURE_ACHIEVED: **%s**\n', yn(closureAchieved));
fprintf(fid, '- RESIDUAL_STRUCTURE_REQUIRED: **%s**\n', yn(residualRequired));
fprintf(fid, '\n## Artifacts\n');
fprintf(fid, '- `tables/closure_metrics.csv`\n');
fprintf(fid, '- `figures/closure_comparison.png`\n');
fprintf(fid, '- `reports/closure_report.md`\n');
fclose(fid);

out = struct();
out.csvPath = string(csvPath);
out.pngPath = string(pngPath);
out.reportPath = string(reportPath);
out.rank2Improves = rank2Improves;
out.closureAchieved = closureAchieved;
out.residualStructureRequired = residualRequired;
end

function v = relImprove(oldVal, newVal)
if ~(isfinite(oldVal) && isfinite(newVal)) || oldVal <= 0
    v = NaN;
else
    v = (oldVal - newVal) / oldVal;
end
end

function r = corrSafe(a, b)
a = a(:);
b = b(:);
m = isfinite(a) & isfinite(b);
if nnz(m) < 3 || std(a(m), 0) <= eps || std(b(m), 0) <= eps
    r = NaN;
    return;
end
r = corr(a(m), b(m), 'type', 'Pearson');
end

function s = yn(tf)
if tf
    s = 'YES';
else
    s = 'NO';
end
end

function styleAx(ax)
set(ax, 'FontSize', 12, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off');
end
