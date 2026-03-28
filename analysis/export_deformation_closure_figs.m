function export_deformation_closure_figs()
% Reads tables/deformation_closure_metrics.csv and exports repo-root figures.
repoRoot = fileparts(fileparts(mfilename('fullpath')));
tbl = readtable(fullfile(repoRoot, 'tables', 'deformation_closure_metrics.csv'));
figDir = fullfile(repoRoot, 'figures');
if exist(figDir, 'dir') ~= 7
    mkdir(figDir);
end
fontName = 'Arial';

fn = fullfile(figDir, 'deformation_vs_rank2_comparison');
fig = figure('Name', 'deformation_vs_rank2_comparison', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [100 100 900 520], 'Visible', 'off');
hold on;
plot(tbl.T_K, tbl.rmse_A_rank1, 'LineWidth', 2.2, 'DisplayName', 'A: rank-1');
plot(tbl.T_K, tbl.rmse_B_rank2_phi2, 'LineWidth', 2.2, 'DisplayName', 'B: rank-2');
plot(tbl.T_K, tbl.rmse_C_deform3, 'LineWidth', 2.2, 'DisplayName', 'C: deform-3');
plot(tbl.T_K, tbl.rmse_D_constrained, 'LineWidth', 2.2, 'DisplayName', 'D: constrained');
plot(tbl.T_K, tbl.rmse_SVD_rank2_row, '--', 'LineWidth', 2, 'DisplayName', 'SVD rank-2');
grid on;
xlabel('T (K)', 'FontSize', 14, 'FontName', fontName);
ylabel('Per-row RMSE (residual grid)', 'FontSize', 14, 'FontName', fontName);
title('Deformation vs rank-2 residual reconstruction', 'FontSize', 15, 'FontName', fontName);
legend('Location', 'best', 'FontSize', 11);
set(gca, 'FontSize', 13, 'LineWidth', 1.2);
exportgraphics(fig, [fn '.png'], 'Resolution', 300);
close(fig);

fn2 = fullfile(figDir, 'beta_vs_Ipeak');
fig2 = figure('Name', 'beta_vs_Ipeak', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [100 100 700 520], 'Visible', 'off');
tiledlayout(fig2, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(tbl.I_peak_mA, tbl.beta1_fixedKappa, 'o-', 'LineWidth', 2.2, 'MarkerSize', 7);
grid on;
ylabel('\beta_1 (d\Phi_1/dx)', 'FontSize', 14, 'FontName', fontName);
xlabel('I_{peak} (mA)', 'FontSize', 14, 'FontName', fontName);
set(gca, 'FontSize', 13, 'LineWidth', 1.2);
nexttile;
plot(tbl.I_peak_mA, tbl.beta2_fixedKappa, 's-', 'LineWidth', 2.2, 'MarkerSize', 7);
grid on;
ylabel('\beta_2 (x \Phi_1)', 'FontSize', 14, 'FontName', fontName);
xlabel('I_{peak} (mA)', 'FontSize', 14, 'FontName', fontName);
set(gca, 'FontSize', 13, 'LineWidth', 1.2);
sgtitle(fig2, 'Deformation coefficients vs I_{peak}', 'FontSize', 15, 'FontName', fontName);
exportgraphics(fig2, [fn2 '.png'], 'Resolution', 300);
close(fig2);
fprintf('Wrote PNGs to %s\n', figDir);
end
