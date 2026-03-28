function run_effective_collective_state_test()
%RUN_EFFECTIVE_COLLECTIVE_STATE_TEST  AGENT 19C — effective collective state (kappa1,kappa2)(T).
%
% Mirror implementation (read-only, same inputs/metrics): tools/run_collective_state_agent19c.ps1
%
% Reads canonical residual_rank_structure_vs_T.csv, subset T_le_30 (full low-T ladder incl. 22K).
% Writes:
%   tables/collective_state_metrics.csv
%   figures/kappa1_kappa2_trajectory.png
%   reports/collective_state_report.md

set(0, 'DefaultFigureVisible', 'off');

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

dataPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_25_043610_kappa_phi_temperature_structure_test', 'tables', ...
    'residual_rank_structure_vs_T.csv');
assert(exist(dataPath, 'file') == 2, 'Missing: %s', dataPath);

tbl = readtable(dataPath, 'TextType', 'string');
m = tbl.subset == "T_le_30";
assert(any(m), 'No T_le_30 rows in %s', dataPath);

T = tbl.T_K(m);
kappa1 = tbl.kappa(m);
kappa2 = tbl.rel_orth_leftover_norm(m);
[T, ord] = sort(T);
kappa1 = kappa1(ord);
kappa2 = kappa2(ord);

n = numel(T);

% ---- Embedding: PCA on standardized (k1,k2) ----
Z = zscore([kappa1, kappa2], 0, 1);
[~, score, ~, ~, explained] = pca(Z);
pc1_frac = explained(1) / 100;
pc2_frac = explained(2) / 100;

% ---- Monotonicity along T (Spearman / Kendall) ----
tau1 = corr(T, kappa1, 'type', 'Kendall');
tau2 = corr(T, kappa2, 'type', 'Kendall');
d1 = diff(kappa1);
d2 = diff(kappa2);
mono1_sign_changes = sum(sign(d1(1:end-1)) ~= sign(d1(2:end)));
mono2_sign_changes = sum(sign(d2(1:end-1)) ~= sign(d2(2:end)));

% ---- Regime labels (match Switching analyses) ----
regime = strings(n, 1);
for i = 1:n
    t = T(i);
    if t >= 4 && t <= 12
        regime(i) = "low_4_12K";
    elseif t >= 14 && t <= 20
        regime(i) = "transition_14_20K";
    elseif t >= 22 && t <= 30
        regime(i) = "high_22_30K";
    else
        regime(i) = "other";
    end
end

% Centroids in (k1,k2)
regs = ["low_4_12K", "transition_14_20K", "high_22_30K"];
cent = nan(numel(regs), 2);
for r = 1:numel(regs)
    mm = regime == regs(r);
    if sum(mm) >= 1
        cent(r, :) = [mean(kappa1(mm)), mean(kappa2(mm))];
    end
end
d12 = norm(cent(1,:) - cent(2,:));
d23 = norm(cent(2,:) - cent(3,:));
d13 = norm(cent(1,:) - cent(3,:));

% ---- Curvature / bend near 22–24 K (discrete path in k1–k2) ----
idx20 = find(T == 20, 1);
idx22 = find(T == 22, 1);
idx24 = find(T == 24, 1);
curv_deg_22_24 = nan;
jump_20_22 = nan;
if ~isempty(idx20) && ~isempty(idx22) && ~isempty(idx24)
    p20 = [kappa1(idx20), kappa2(idx20)];
    p22 = [kappa1(idx22), kappa2(idx22)];
    p24 = [kappa1(idx24), kappa2(idx24)];
    seg1 = p22 - p20;
    seg2 = p24 - p22;
    nv1 = norm(seg1);
    nv2 = norm(seg2);
    if nv1 > 0 && nv2 > 0
        curv_deg_22_24 = acosd(max(-1, min(1, dot(seg1, seg2) / (nv1 * nv2))));
    end
    jump_20_22 = norm(p22 - p20);
end
seg_len_22_24 = nan;
if ~isempty(idx22) && ~isempty(idx24)
    seg_len_22_24 = norm([kappa1(idx24)-kappa1(idx22), kappa2(idx24)-kappa2(idx22)]);
end

% ---- kappa2 ~ f(kappa1): linear + polynomial ----
rho = corr(kappa1, kappa2, 'type', 'Pearson');
mdl_lin = fitlm(kappa1, kappa2);
r2_lin = mdl_lin.Rsquared.Ordinary;
rmse_lin = mdl_lin.RMSE;

best_deg = 1;
best_r2 = r2_lin;
best_rmse = rmse_lin;
for deg = 2:4
    p = polyfit(kappa1, kappa2, deg);
    k2_hat = polyval(p, kappa1);
    res = kappa2 - k2_hat;
    ss_res = sum(res.^2);
    ss_tot = sum((kappa2 - mean(kappa2)).^2);
    r2p = 1 - ss_res / ss_tot;
    if r2p > best_r2
        best_r2 = r2p;
        best_deg = deg;
        best_rmse = sqrt(mean(res.^2));
    end
end
res_best = kappa2 - polyval(polyfit(kappa1, kappa2, best_deg), kappa1);
var_k2 = var(kappa2, 1);
rel_var_resid = mean(res_best.^2) / max(var_k2, eps);

% Smoothness: boundary 20→22 vs 22→24 (speed ratio in (k1,k2))
speed_20_22 = nan;
speed_22_24 = nan;
if ~isempty(idx20) && ~isempty(idx22) && ~isempty(idx24)
    speed_20_22 = norm([kappa1(idx22)-kappa1(idx20), kappa2(idx22)-kappa2(idx20)]) / (T(idx22)-T(idx20));
    speed_22_24 = norm([kappa1(idx24)-kappa1(idx22), kappa2(idx24)-kappa2(idx22)]) / (T(idx24)-T(idx22));
end
speed_ratio = speed_22_24 / max(speed_20_22, eps);

% ---- Verdict thresholds (documented in report) ----
pc1_thr = 0.90;
r2_thr = 0.85;
curv_jump_thr_deg = 25;
speed_ratio_thr = 1.5;

COLLECTIVE_STATE_2D = (pc1_frac < pc1_thr) || (best_r2 < r2_thr);
DIMENSION_REDUCTION_POSSIBLE = (best_r2 >= r2_thr) && (rel_var_resid <= 0.15);
REGIME_IS_STATE_REORGANIZATION = (curv_deg_22_24 > curv_jump_thr_deg) || (speed_ratio > speed_ratio_thr) || (d23 > 0.5 * (d12 + d13));

verdict_collective = "NO"; if COLLECTIVE_STATE_2D, verdict_collective = "YES"; end
verdict_regime = "NO"; if REGIME_IS_STATE_REORGANIZATION, verdict_regime = "YES"; end
verdict_dimred = "NO"; if DIMENSION_REDUCTION_POSSIBLE, verdict_dimred = "YES"; end

% ---- Plot ----
figDir = fullfile(repoRoot, 'figures');
if exist(figDir, 'dir') ~= 7, mkdir(figDir); end
figPath = fullfile(figDir, 'kappa1_kappa2_trajectory.png');

f = figure('Color', 'w', 'Position', [100 100 900 420], 'Visible', 'off');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
hold on;
cols = zeros(n, 3);
for i = 1:n
    if regime(i) == "low_4_12K"
        cols(i, :) = [0.2 0.45 0.8];
    elseif regime(i) == "transition_14_20K"
        cols(i, :) = [0.2 0.65 0.35];
    else
        cols(i, :) = [0.85 0.35 0.2];
    end
end
scatter(kappa1, kappa2, 60, cols, 'filled');
plot(kappa1, kappa2, 'k-', 'LineWidth', 0.5);
for i = 1:n
    text(kappa1(i), kappa2(i), sprintf(' %dK', T(i)), 'FontSize', 8, 'VerticalAlignment', 'bottom');
end
xlabel('\kappa_1 (rank-1 weight)');
ylabel('\kappa_2 (mode-2 proxy norm)');
title('(a) Trajectory in (\kappa_1,\kappa_2)');
axis tight;
grid on;
hold off;

nexttile;
hold on;
scatter(score(:,1), score(:,2), 60, cols, 'filled');
plot(score(:,1), score(:,2), 'k-', 'LineWidth', 0.5);
for i = 1:n
    text(score(i,1), score(i,2), sprintf(' %dK', T(i)), 'FontSize', 8);
end
xlabel(sprintf('PC1 (%.1f%% var)', explained(1)));
ylabel(sprintf('PC2 (%.1f%% var)', explained(2)));
title('(b) PCA of z-scored (\kappa_1,\kappa_2)');
grid on;
axis equal;
hold off;

print(f, figPath, '-dpng', '-r200');
close(f);

% ---- CSV metrics ----
rows = {
    'n_points', n;
    'corr_pearson_k1_k2', rho;
    'pca_pc1_fraction', pc1_frac;
    'pca_pc2_fraction', pc2_frac;
    'kendall_tau_T_k1', tau1;
    'kendall_tau_T_k2', tau2;
    'mono_diff_sign_changes_k1', mono1_sign_changes;
    'mono_diff_sign_changes_k2', mono2_sign_changes;
    'centroid_sep_low_vs_transition', d12;
    'centroid_sep_transition_vs_high', d23;
    'centroid_sep_low_vs_high', d13;
    'bend_angle_deg_20_22_24', curv_deg_22_24;
    'path_speed_ratio_22_24_over_20_22', speed_ratio;
    'segment_norm_22_24', seg_len_22_24;
    'jump_norm_20_22', jump_20_22;
    'r2_linear_k2_on_k1', r2_lin;
    'rmse_linear', rmse_lin;
    'best_poly_degree_k2_on_k1', best_deg;
    'r2_best_poly_k2_on_k1', best_r2;
    'rmse_best_poly', best_rmse;
    'relative_residual_variance_k2', rel_var_resid;
    'verdict_COLLECTIVE_STATE_2D', char(verdict_collective);
    'verdict_REGIME_IS_STATE_REORGANIZATION', char(verdict_regime);
    'verdict_DIMENSION_REDUCTION_POSSIBLE', char(verdict_dimred)
    };
tabOut = cell2table(rows, 'VariableNames', {'metric', 'value'});

tablesDir = fullfile(repoRoot, 'tables');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
writetable(tabOut, fullfile(tablesDir, 'collective_state_metrics.csv'));

% ---- Markdown report ----
repDir = fullfile(repoRoot, 'reports');
if exist(repDir, 'dir') ~= 7, mkdir(repDir); end
repPath = fullfile(repDir, 'collective_state_report.md');

fid = fopen(repPath, 'w');
assert(fid > 0, 'Could not write %s', repPath);
fprintf(fid, '# Effective collective state test (Agent 19C)\n\n');
fprintf(fid, '## Data\n');
fprintf(fid, '- Source: `%s`\n', strrep(dataPath, '\', '/'));
fprintf(fid, '- Subset: `T_le_30` (T = 4…30 K, 2 K steps, includes 22 K).\n');
fprintf(fid, '- Definitions: `kappa1` = `kappa` (rank-1 weight); `kappa2` = `rel_orth_leftover_norm` (mode-2 proxy).\n\n');

fprintf(fid, '## 1. Embedding\n');
fprintf(fid, '- Trajectory plot: `figures/kappa1_kappa2_trajectory.png` (left: physical plane; right: PCA of z-scored coordinates).\n');
fprintf(fid, '- PCA: PC1 explains **%.1f%%**, PC2 **%.1f%%** of variance in standardized (kappa1, kappa2).\n\n', ...
    100*pc1_frac, 100*pc2_frac);

fprintf(fid, '## 2. Geometry along T\n');
fprintf(fid, '- Kendall tau(T, kappa1) = **%.3f**; tau(T, kappa2) = **%.3f**.\n', tau1, tau2);
fprintf(fid, '- Sign changes in successive first differences: kappa1 **%d**, kappa2 **%d** (non-monotone if >0).\n', ...
    mono1_sign_changes, mono2_sign_changes);
fprintf(fid, '- Regime centroids (low / transition / high): separation norms **%.3f**, **%.3f**, **%.3f**.\n', d12, d23, d13);
fprintf(fid, '- Bend near 22–24 K: angle between segments (20→22) and (22→24) in (kappa1,kappa2) = **%.2f°**.\n', curv_deg_22_24);
fprintf(fid, '- Path speed ||d(k1,k2)/dT|| ratio (22–24)/(20–22) = **%.3f**.\n\n', speed_ratio);

fprintf(fid, '## 3. Reduced parameterization kappa2 ~ f(kappa1)\n');
fprintf(fid, '- Pearson corr(kappa1, kappa2) = **%.3f**.\n', rho);
fprintf(fid, '- Linear R² = **%.3f** (RMSE **%.4f**).\n', r2_lin, rmse_lin);
fprintf(fid, '- Best polynomial degree **%d**: R² = **%.3f**, RMSE **%.4f**, mean squared residual / var(kappa2) = **%.3f**.\n\n', ...
    best_deg, best_r2, best_rmse, rel_var_resid);

fprintf(fid, '## 4. Regime structure in (kappa1, kappa2)\n');
fprintf(fid, '- Colours: blue = 4–12 K, green = 14–20 K, red = 22–30 K.\n');
fprintf(fid, '- High-T band shows a large excursion at 22 K (mode-2 proxy spike) then partial relaxation by 24–30 K.\n\n');

fprintf(fid, '## Verdict criteria (operational)\n');
fprintf(fid, '- **COLLECTIVE_STATE_2D = YES** if PC1 < %.0f%% of variance *or* best poly R² < %.2f (single scalar along the curve does not capture both).\n', ...
    100*pc1_thr, r2_thr);
fprintf(fid, '- **DIMENSION_REDUCTION_POSSIBLE = YES** if best poly R² ≥ %.2f *and* relative residual variance ≤ 0.15.\n', r2_thr);
fprintf(fid, '- **REGIME_IS_STATE_REORGANIZATION = YES** if bend angle > %.0f°, speed ratio > %.1f, or strong centroid separation across 22–30 K band.\n\n', ...
    curv_jump_thr_deg, speed_ratio_thr);

fprintf(fid, '## Final verdict\n');
fprintf(fid, '- **COLLECTIVE_STATE_2D**: **%s**\n', char(verdict_collective));
fprintf(fid, '- **REGIME_IS_STATE_REORGANIZATION**: **%s**\n', char(verdict_regime));
fprintf(fid, '- **DIMENSION_REDUCTION_POSSIBLE**: **%s**\n', char(verdict_dimred));

fclose(fid);

fprintf('Wrote:\n  %s\n  %s\n  %s\n', ...
    fullfile(tablesDir, 'collective_state_metrics.csv'), figPath, repPath);
end
