function run_agent24h_figures()
%RUN_AGENT24H_FIGURES — PNGs for experimental observable replacement survey (Agent 24H).
% Writes: figures/latent_vs_observable_proxy_comparison.png,
%         figures/phi1_phi2_in_experimental_language.png,
%         figures/observable_replacement_summary.png
%         tables/agent24h_correlations.csv

repoRoot = fileparts(fileparts(mfilename('fullpath')));
cd(repoRoot);
figDir = fullfile(repoRoot, 'figures');
tblDir = fullfile(repoRoot, 'tables');
if exist(figDir, 'dir') ~= 7, mkdir(figDir); end
if exist(tblDir, 'dir') ~= 7, mkdir(tblDir); end

%% Correlations (alpha_structure: measured-map scalars)
a = readtable(fullfile(tblDir, 'alpha_structure.csv'));
k1 = a.kappa1(:);
k2 = a.kappa2(:);
al = a.alpha(:);
Wmeas = a.q90_minus_q50(:);
Sp = a.S_peak(:);
Ip = a.I_peak_mA(:);
asymM = a.asymmetry_q_spread(:);

rows = {
    'kappa1' 'q90_minus_q50_measured' corr_pearson(k1, Wmeas) corr_spearman(k1, Wmeas) sum(isfinite(k1)&isfinite(Wmeas))
    'kappa1' 'S_peak' corr_pearson(k1, Sp) corr_spearman(k1, Sp) sum(isfinite(k1)&isfinite(Sp))
    'kappa1' 'I_peak_mA' corr_pearson(k1, Ip) corr_spearman(k1, Ip) sum(isfinite(k1)&isfinite(Ip))
    'kappa2' 'I_peak_mA' corr_pearson(k2, Ip) corr_spearman(k2, Ip) sum(isfinite(k2)&isfinite(Ip))
    'alpha' 'asymmetry_q_spread_measured' corr_pearson(al, asymM) corr_spearman(al, asymM) sum(isfinite(al)&isfinite(asymM))
    'alpha' 'q90_minus_q50_measured' corr_pearson(al, Wmeas) corr_spearman(al, Wmeas) sum(isfinite(al)&isfinite(Wmeas))
    };

cTbl = cell2table(rows, 'VariableNames', {'latent', 'observable', 'pearson', 'spearman', 'n'});

%% PT tail table overlap (subset)
p = readtable(fullfile(tblDir, 'kappa1_from_PT.csv'));
Wpt = p.tail_width_q90_q50(:);
k1p = p.kappa1(:);
Spp = p.S_peak(:);
mask = isfinite(k1p) & isfinite(Wpt) & isfinite(Spp);
cTbl2 = table( ...
    {'kappa1'; 'kappa1'}, ...
    {'tail_width_q90_q50_PT'; 'S_peak_PT_row'}, ...
    [corr_pearson(k1p(mask), Wpt(mask)); corr_pearson(k1p(mask), Spp(mask))], ...
    [corr_spearman(k1p(mask), Wpt(mask)); corr_spearman(k1p(mask), Spp(mask))], ...
    [sum(mask); sum(mask)], ...
    'VariableNames', {'latent', 'observable', 'pearson', 'spearman', 'n'});
writetable([cTbl; cTbl2], fullfile(tblDir, 'agent24h_correlations.csv'));

%% Figure 1 — latent vs observable proxies
f1 = figure('Visible', 'off', 'Position', [100 100 900 700], 'Color', 'w');
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile; scatter(Wmeas, k1, 36, a.T_K(:), 'filled'); colorbar; xlabel('q_{90}-q_{50} on map (mA)'); ylabel('\kappa_1'); title(sprintf('\\kappa_1 vs measured spread (\\rho=%.2f)', corr_pearson(k1, Wmeas))); grid on;
nexttile; scatter(Sp, k1, 36, a.T_K(:), 'filled'); colorbar; xlabel('S_{peak}'); ylabel('\kappa_1'); title(sprintf('\\kappa_1 vs S_{peak} (\\rho=%.2f)', corr_pearson(k1, Sp))); grid on;
nexttile; scatter(Ip, k2, 36, a.T_K(:), 'filled'); colorbar; xlabel('I_{peak} (mA)'); ylabel('\kappa_2'); title(sprintf('\\kappa_2 vs I_{peak} (\\rho=%.2f)', corr_pearson(k2, Ip))); grid on;
nexttile; scatter(asymM, al, 36, a.T_K(:), 'filled'); colorbar; xlabel('Asymmetry (measured spread)'); ylabel('\alpha'); title(sprintf('\\alpha vs asymmetry (\\rho=%.2f)', corr_pearson(al, asymM))); grid on;
sgtitle('Latent decomposition scalars vs direct map / ridge observables', 'FontWeight', 'bold');
exportgraphics(f1, fullfile(figDir, 'latent_vs_observable_proxy_comparison.png'), 'Resolution', 150);
close(f1);

%% Figure 2 — Phi1 / Phi2 in experimental language (metrics bar + text)
phi2m = readtable(fullfile(tblDir, 'phi2_structure_metrics.csv'));
f2 = figure('Visible', 'off', 'Position', [100 100 820 520], 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact');
nexttile;
bnames = {'Even frac', 'Tight center frac', 'Shoulder L/R', '|kernel| max'};
bvals = [phi2m.phi2_even_energy_fraction, phi2m.phi2_center_energy_frac_abs_x_le_tight, ...
    phi2m.phi2_shoulder_tail_ratio_R_over_L, phi2m.phi2_best_kernel_abs_corr];
bar(bvals);
set(gca, 'XTickLabel', bnames, 'XTickLabelRotation', 25);
ylabel('Metric value'); title('Mode-2 shape: experimental descriptors'); ylim([0 1.15]); grid on;
nexttile; axis off;
text(0.02, 0.95, sprintf(['\\bf\\Phi_1 (rank-1 correction)\\rm\nBroad symmetric adjustment of the\nswitching curve away from the\nthreshold PDF backbone in x.\n\n' ...
    '\\bf\\Phi_2 (rank-2 correction)\\rm\nMixed width/slope-like pattern;\n~%.0f%% even / ~%.0f%% odd;\nlocalized near ridge center;\nkernel match |r| \\approx %.2f (%s).'], ...
    100*phi2m.phi2_even_energy_fraction, 100*phi2m.phi2_odd_energy_fraction, ...
    phi2m.phi2_best_kernel_abs_corr, char(phi2m.phi2_best_kernel_name)), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 11);
sgtitle('Interpreting spatial modes without linear-algebra jargon', 'FontWeight', 'bold');
exportgraphics(f2, fullfile(figDir, 'phi1_phi2_in_experimental_language.png'), 'Resolution', 150);
close(f2);

%% Figure 3 — replacement summary (two panels, consistent units per panel)
f3 = figure('Visible', 'off', 'Position', [100 100 780 420], 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
y1 = [13.78698119261; 11.9148173531162];
b1 = bar(y1);
b1.FaceColor = [0.25 0.5 0.75];
set(gca, 'XTickLabel', {'R ~ spread_{90-50}', 'R ~ spread + \kappa_1'}, 'XTickLabelRotation', 20);
ylabel('LOOCV RMSE on R(T)');
title('Aging: PT spread vs adding \kappa_1 (24B, n=10)');
grid on;
nexttile;
y2 = [0.0184738729675384; 0.113456194057352];
b2 = bar(y2);
b2.FaceColor = [0.55 0.35 0.25];
set(gca, 'XTickLabel', {'\kappa_1 ~ W_{PT}+S', '\kappa_2 ~ I_{peak}'}, 'XTickLabelRotation', 15);
ylabel('LOOCV RMSE');
title('Switching latents predicted from observables (20A / 19A)');
grid on;
sgtitle('When observables replace or surround latent scalars', 'FontWeight', 'bold');
exportgraphics(f3, fullfile(figDir, 'observable_replacement_summary.png'), 'Resolution', 150);
close(f3);

fprintf('Agent24H figures written to %s\n', figDir);
end

function r = corr_pearson(a, b)
m = isfinite(a) & isfinite(b);
if sum(m) < 3, r = NaN; return; end
r = corr(a(m), b(m), 'type', 'Pearson');
end

function r = corr_spearman(a, b)
m = isfinite(a) & isfinite(b);
if sum(m) < 3, r = NaN; return; end
r = corr(a(m), b(m), 'type', 'Spearman');
end
