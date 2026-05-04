clear; clc;

% AGENT24H_RENDER_FIGURES_MATLAB_REPLACEMENT (INFRA-04 replacement candidate)
% Replicates visual intent of tools/agent24h_render_figures.ps1 using MATLAB only.
% Writes .fig and .png under figures/infra_04_agent24h_replacement/ (non-destructive).
% Writes tables/infra_04_agent24h_replacement_correlations.csv (does not overwrite tables/agent24h_correlations.csv).
% INFRA-04B: Prerequisite tables (alpha_structure, phi2_structure_metrics, kappa1_from_PT) were absent at audit; materialize via documented upstream writers before execution.


thisFile = mfilename('fullpath');
if isempty(thisFile)
    error('agent24h_render_figures_matlab_replacement:RunAsFile', 'Run this file from disk; mfilename is empty when evaluated.');
end
thisDir = fileparts(thisFile);
repoRoot = fileparts(thisDir);

tblDir = fullfile(repoRoot, 'tables');
outFigDir = fullfile(repoRoot, 'figures', 'infra_04_agent24h_replacement');
alphaCsv = fullfile(tblDir, 'alpha_structure.csv');
phi2Csv = fullfile(tblDir, 'phi2_structure_metrics.csv');
kptCsv = fullfile(tblDir, 'kappa1_from_PT.csv');

if exist(alphaCsv, 'file') ~= 2
    error('agent24h_render_figures_matlab_replacement:MissingInput', 'Missing %s', alphaCsv);
end
if exist(phi2Csv, 'file') ~= 2
    error('agent24h_render_figures_matlab_replacement:MissingInput', 'Missing %s', phi2Csv);
end
if exist(kptCsv, 'file') ~= 2
    error('agent24h_render_figures_matlab_replacement:MissingInput', 'Missing %s', kptCsv);
end

if exist(outFigDir, 'dir') ~= 7
    mkdir(outFigDir);
end

alphaTbl = readtable(alphaCsv, 'VariableNamingRule', 'preserve');
phi2Tbl = readtable(phi2Csv, 'VariableNamingRule', 'preserve');
kptTbl = readtable(kptCsv, 'VariableNamingRule', 'preserve');

T_K = alphaTbl.T_K;
k1 = alphaTbl.kappa1;
k2 = alphaTbl.kappa2;
al = alphaTbl.alpha;
W = alphaTbl.q90_minus_q50;
Sp = alphaTbl.S_peak;
Ip = alphaTbl.I_peak_mA;
asym = alphaTbl.asymmetry_q_spread;

row1 = phi2Tbl(1, :);
even = row1.phi2_even_energy_fraction(1);
tight = row1.phi2_center_energy_frac_abs_x_le_tight(1);
sh = row1.phi2_shoulder_tail_ratio_R_over_L(1);
kc = row1.phi2_best_kernel_abs_corr(1);
kname = char(row1.phi2_best_kernel_name(1));

f1 = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 700]);
tiledlayout(f1, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
sgtitle(f1, 'Latent decomposition scalars vs direct map / ridge observables', 'FontWeight', 'bold');

nexttile;
drawScatterPanel(gca, W, k1, T_K, 'q90-q50 map (mA)', 'kappa1', sprintf('k1 vs spread rho=%.2f', localPearson(W, k1)));

nexttile;
drawScatterPanel(gca, Sp, k1, T_K, 'S_peak', 'kappa1', sprintf('k1 vs S_peak rho=%.2f', localPearson(Sp, k1)));

nexttile;
drawScatterPanel(gca, Ip, k2, T_K, 'I_peak (mA)', 'kappa2', sprintf('k2 vs I_peak rho=%.2f', localPearson(Ip, k2)));

nexttile;
drawScatterPanel(gca, asym, al, T_K, 'asymmetry (map)', 'alpha', sprintf('alpha vs asym rho=%.2f', localPearson(asym, al)));

savefig(f1, fullfile(outFigDir, 'latent_vs_observable_proxy_comparison.fig'));
exportgraphics(f1, fullfile(outFigDir, 'latent_vs_observable_proxy_comparison.png'));
close(f1);

vals = [even, tight, sh, kc];
names = {'Even frac', 'Tight center', 'Shoulder R/L', 'Kernel |r|'};
mx = 1.15;

f2 = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 820 520]);
bar(1:4, vals, 'FaceColor', [50 110 160] / 255);
ylim([0 mx]);
set(gca, 'XTickLabel', names, 'FontSize', 8);
ylabel('');
title('Mode-2 shape: experimental descriptors', 'FontWeight', 'bold', 'FontSize', 10);
annotationText = sprintf(['Phi1 (rank-1 correction)\n', ...
    'Broad symmetric adjustment of the switching curve\n', ...
    'away from the threshold-PDF backbone in normalized x.\n\n', ...
    'Phi2 (rank-2 correction)\n', ...
    'Mixed width/slope-like pattern on the ridge;\n', ...
    '~%d%% even / ~%d%% odd;\n', ...
    'localized near ridge center; best simple-template match |r| ~ %.2f (%s).'], ...
    round(100 * even), round(100 * (1 - even)), kc, kname);
annotation(f2, 'textbox', [0.48 0.15 0.5 0.7], 'String', annotationText, ...
    'EdgeColor', 'none', 'FontSize', 10, 'Interpreter', 'none', 'VerticalAlignment', 'top');
sgtitle(f2, 'Interpreting spatial modes without linear-algebra jargon', 'FontWeight', 'bold');

savefig(f2, fullfile(outFigDir, 'phi1_phi2_in_experimental_language.fig'));
exportgraphics(f2, fullfile(outFigDir, 'phi1_phi2_in_experimental_language.png'));
close(f2);

y1a = 13.78698119261;
y1b = 11.9148173531162;
y2a = 0.0184738729675384;
y2b = 0.113456194057352;

f3 = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 780 420]);
tiledlayout(f3, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
mx1 = max([y1a y1b]) * 1.15;
bar([1 2], [y1a y1b], 'FaceColor', [60 120 190] / 255);
ylim([0 mx1]);
set(gca, 'XTick', [1 2], 'XTickLabel', {'spread only', '+ kappa1'}, 'FontSize', 8);
title('Aging R(T): LOOCV RMSE', 'FontWeight', 'bold', 'FontSize', 10);

nexttile;
mx2 = max([y2a y2b]) * 1.15;
bar([1 2], [y2a y2b], 'FaceColor', [140 90 60] / 255);
ylim([0 mx2]);
set(gca, 'XTick', [1 2], 'XTickLabel', {'k1~W+S', 'k2~Ipeak'}, 'FontSize', 8);
title('Latent ~ observable (LOOCV RMSE)', 'FontWeight', 'bold', 'FontSize', 10);

sgtitle(f3, 'When observables replace or surround latent scalars (canonical agent tables)', 'FontWeight', 'bold');

savefig(f3, fullfile(outFigDir, 'observable_replacement_summary.fig'));
exportgraphics(f3, fullfile(outFigDir, 'observable_replacement_summary.png'));
close(f3);

k1p = kptTbl.kappa1;
Wpt = kptTbl.tail_width_q90_q50;
Spp = kptTbl.S_peak;
mask = ~isnan(k1p) & ~isnan(Wpt) & ~isnan(Spp);
k1ok = k1p(mask);
Wok = Wpt(mask);
Sok = Spp(mask);

p_w_k1 = localPearson(W, k1);
p_sp_k1 = localPearson(Sp, k1);
p_ip_k1 = localPearson(Ip, k1);
p_ip_k2 = localPearson(Ip, k2);
p_asym_al = localPearson(asym, al);
p_w_al = localPearson(W, al);
p_wpt_k1 = localPearson(Wok, k1ok);
p_spt_k1 = localPearson(Sok, k1ok);

latentCol = {'kappa1'; 'kappa1'; 'kappa1'; 'kappa2'; 'alpha'; 'alpha'; 'kappa1'; 'kappa1'};
obsCol = {'q90_minus_q50_measured'; 'S_peak'; 'I_peak_mA'; 'I_peak_mA'; ...
    'asymmetry_q_spread_measured'; 'q90_minus_q50_measured'; 'tail_width_q90_q50_PT'; 'S_peak_PT_row'};
pearCol = [p_w_k1; p_sp_k1; p_ip_k1; p_ip_k2; p_asym_al; p_w_al; p_wpt_k1; p_spt_k1];
spearCol = NaN(8, 1);
nCol = [numel(W); numel(Sp); numel(Ip); numel(Ip); numel(asym); numel(W); numel(k1ok); numel(k1ok)];

corrRows = table(latentCol, obsCol, pearCol, spearCol, nCol, ...
    'VariableNames', {'latent', 'observable', 'pearson', 'spearman', 'n'});

corrPath = fullfile(tblDir, 'infra_04_agent24h_replacement_correlations.csv');
writetable(corrRows, corrPath);

disp(['Wrote ', fullfile(outFigDir, 'latent_vs_observable_proxy_comparison.png')]);
disp(['Wrote ', fullfile(outFigDir, 'phi1_phi2_in_experimental_language.png')]);
disp(['Wrote ', fullfile(outFigDir, 'observable_replacement_summary.png')]);
disp(['Wrote ', corrPath]);

function drawScatterPanel(ax, xs, ys, cvals, xt, yt, ttl)
axes(ax);
cla(ax);
hold(ax, 'on');
minx = min(xs, [], 'omitnan');
maxx = max(xs, [], 'omitnan');
miny = min(ys, [], 'omitnan');
maxy = max(ys, [], 'omitnan');
rx = max(maxx - minx, 1e-9);
ry = max(maxy - miny, 1e-9);
minc = min(cvals, [], 'omitnan');
maxc = max(cvals, [], 'omitnan');
rc = max(maxc - minc, 1e-9);
nc = numel(xs);
rgb = zeros(nc, 3);
for i = 1:nc
    if isnan(xs(i))
        continue;
    end
    t = 255 * (cvals(i) - minc) / rc;
    t = max(0, min(255, t));
    rgb(i, :) = [30 / 255, 80 / 255, (120 + t / 2) / 255];
end
scatter(ax, xs, ys, 36, rgb, 'filled');
ax.Color = [250 250 250] / 255;
box(ax, 'on');
title(ax, ttl, 'FontWeight', 'bold', 'FontSize', 9);
xlabel(ax, xt, 'FontSize', 8);
ylabel(ax, yt, 'FontSize', 8);
hold(ax, 'off');
end

function r = localPearson(a, b)
a = a(:);
b = b(:);
n = min(numel(a), numel(b));
aa = [];
bb = [];
for i = 1:n
    if a(i) == a(i) && b(i) == b(i)
        aa(end + 1, 1) = a(i); %#ok<AGROW>
        bb(end + 1, 1) = b(i); %#ok<AGROW>
    end
end
if numel(aa) < 3
    r = NaN;
    return;
end
ma = mean(aa);
mb = mean(bb);
num = 0;
da = 0;
db = 0;
for i = 1:numel(aa)
    va = aa(i) - ma;
    vb = bb(i) - mb;
    num = num + va * vb;
    da = da + va * va;
    db = db + vb * vb;
end
if da <= 0 || db <= 0
    r = NaN;
    return;
end
r = num / sqrt(da * db);
end
