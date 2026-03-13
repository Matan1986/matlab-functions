function refresh_tau_figure_only()
repoRoot = 'C:\Dev\matlab-functions';
runDir = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_2026_03_12_223709_aging_timescale_extraction');
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
T = readtable(fullfile(runDir, 'tables', 'tau_vs_Tp.csv'), 'TextType', 'string');
fig = create_figure('Visible', 'off', 'Position', [2 2 12.0 8.0]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, T.Tp, T.tau_logistic_half_seconds, '-o', 'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerSize', 5.5, 'LineWidth', 2.0, 'DisplayName', 'Logistic fit in log(t_w)');
plot(ax, T.Tp, T.tau_stretched_half_seconds, '-s', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerSize', 5.5, 'LineWidth', 2.0, 'DisplayName', 'Stretched-exp half time');
plot(ax, T.Tp, T.tau_half_range_seconds, '-^', 'Color', [0.00 0.62 0.45], 'MarkerFaceColor', [0.00 0.62 0.45], 'MarkerSize', 5.5, 'LineWidth', 2.0, 'DisplayName', 'Direct half-range');
plot(ax, T.Tp, T.tau_effective_seconds, '-d', 'Color', [0.00 0.00 0.00], 'MarkerFaceColor', [0.00 0.00 0.00], 'MarkerSize', 5.5, 'LineWidth', 2.4, 'DisplayName', 'Consensus');
fragileMask = T.fragile_low_point_count & isfinite(T.tau_logistic_half_seconds);
if any(fragileMask)
    plot(ax, T.Tp(fragileMask), T.tau_logistic_half_seconds(fragileMask), 'ko', 'MarkerSize', 8, 'LineWidth', 1.2, 'MarkerFaceColor', 'w', 'DisplayName', 'Fragile T_p (3 points)');
end
set(ax, 'YScale', 'log');
xlabel(ax, 'Stopping temperature T_p (K)');
ylabel(ax, 'Effective aging timescale \tau (s)');
title(ax, 'Aging timescale estimates vs stopping temperature');
set(ax, 'FontSize', 9, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
legend(ax, 'Location', 'eastoutside');
save_run_figure(fig, 'tau_vs_Tp', runDir);
close(fig);
end
