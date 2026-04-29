% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: CORRECTED_CANONICAL_OLD_ANALYSIS (reads authoritative builder tables + clean source view)
% EVIDENCE_STATUS: TASK_002A_visual_QA_refinement — DIAGNOSTIC_QA_FIGURES only; NOT publication-authorized
% BACKBONE_FORMULA: N/A (visualization of precomputed authoritative maps)
% SVD_INPUT: N/A
% COORDINATE_GRID: source_view + map tables finite-window semantics per script
% SAFE_USE: refined PNGs for QA; reads switching_canonical_source_view.csv + switching_corrected_old_authoritative_*.csv only
% UNSAFE_USE: publication figures without publication gate; mixing in S_model_pt_percent diagnostic pathway
% NOT_MAIN_MANUSCRIPT_EVIDENCE_IF_APPLICABLE: QA diagnostics until TASK_009/TASK_012 gates — see reports/switching_reconstruction_task_id_alignment.md (TASK_002A vs TASK_002B)
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
% run_switching_corrected_old_task002_visual_QA_refinement — TASK_002A visual QA refinement only (no reconstruction changes).

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    repoRoot = pwd;
end

tablesDir = fullfile(repoRoot, 'tables');
figDir = fullfile(repoRoot, 'figures', 'switching', 'diagnostics', 'corrected_old_task002_quality_QA_refined');
if exist(figDir, 'dir') ~= 7
    mkdir(figDir);
end

sourcePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_04_24_233348_switching_canonical', 'tables', 'switching_canonical_source_view.csv');
bbPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_backbone_map.csv');
resPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_residual_map.csv');
m1Path = fullfile(tablesDir, 'switching_corrected_old_authoritative_mode1_reconstruction_map.csv');
raPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_residual_after_mode1_map.csv');
phiPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_phi1.csv');
kapPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_kappa1.csv');
byTPath = fullfile(tablesDir, 'switching_corrected_old_quality_metrics_by_T.csv');

src = readtable(sourcePath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
bb = readtable(bbPath, 'VariableNamingRule', 'preserve');
res = readtable(resPath, 'VariableNamingRule', 'preserve');
m1 = readtable(m1Path, 'VariableNamingRule', 'preserve');
ra = readtable(raPath, 'VariableNamingRule', 'preserve');
phiT = readtable(phiPath, 'VariableNamingRule', 'preserve');
kap = readtable(kapPath, 'VariableNamingRule', 'preserve');
qByT = readtable(byTPath, 'VariableNamingRule', 'preserve');

% Builder window and current filtering: T=4:2:30 and fully finite source currents.
expectedT = (4:2:30)';
srcT = str2double(string(src.T_K));
srcI = str2double(string(src.current_mA));
srcS = str2double(string(src.S_percent));
keep = isfinite(srcT) & isfinite(srcI) & isfinite(srcS) & ismember(srcT, expectedT);
srcT = srcT(keep);
srcI = srcI(keep);
srcS = srcS(keep);
allI = unique(srcI, 'sorted');
nT = numel(expectedT);
nIall = numel(allI);
SmapAll = nan(nT, nIall);
for it = 1:nT
    for ii = 1:nIall
        idx = find(srcT == expectedT(it) & srcI == allI(ii), 1, 'first');
        if ~isempty(idx)
            SmapAll(it, ii) = srcS(idx);
        end
    end
end
finiteCurr = all(isfinite(SmapAll), 1);
uI = allI(finiteCurr);
SmapSource = SmapAll(:, finiteCurr);
uT = expectedT;

Mbb = pivotField(bb, uT, uI, 'S_backbone_old_recipe');
Mr = pivotField(res, uT, uI, 'DeltaS');
Mm1 = pivotField(m1, uT, uI, 'S_mode1_reconstruction');
Mra = pivotField(ra, uT, uI, 'DeltaS_after_mode1');

nanMaskMode = ~isfinite(Mm1);
nanMaskAfter = ~isfinite(Mra);
maskColor = [0.92, 0.92, 0.92];

set(groot, ...
    'defaultTextFontName', 'Helvetica', ...
    'defaultAxesFontName', 'Helvetica', ...
    'defaultAxesFontSize', 12, ...
    'defaultLineLineWidth', 2);

%% Figure 1: source -> backbone -> mode1 -> residual after
base_name = 'switching_corrected_old_QA_refined_source_backbone_mode1_residual';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [80 80 1300 900], 'Color', 'w');
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
maskedHeatmap(uI, uT, SmapSource, false(size(SmapSource)), maskColor, 'S_{percent} source map');
xlabel('Current (mA)'); ylabel('Temperature (K)');

nexttile;
maskedHeatmap(uI, uT, Mbb, false(size(Mbb)), maskColor, 'Corrected-old backbone map');
xlabel('Current (mA)'); ylabel('Temperature (K)');

nexttile;
maskedHeatmap(uI, uT, Mm1, nanMaskMode, maskColor, 'Mode1 reconstruction map');
xlabel('Current (mA)'); ylabel('Temperature (K)');

nexttile;
maskedHeatmap(uI, uT, Mra, nanMaskAfter, maskColor, 'Residual after mode1');
xlabel('Current (mA)'); ylabel('Temperature (K)');

annotation(fig, 'textbox', [0.18 0.01 0.72 0.05], ...
    'String', 'gray = unsupported / outside finite aligned support (not zero)', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11);

exportgraphics(fig, fullfile(figDir, [base_name '.png']), 'Resolution', 300);
close(fig);

%% Figure 2: residual before/after same scale
base_name = 'switching_corrected_old_QA_refined_residual_before_after_same_scale';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [80 80 1200 470], 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

sameScale = max(abs(Mr), [], 'all', 'omitnan');

nexttile;
maskedHeatmap(uI, uT, Mr, false(size(Mr)), maskColor, 'Residual before mode1 (same scale)');
clim([-sameScale sameScale]);
xlabel('Current (mA)'); ylabel('Temperature (K)');

nexttile;
maskedHeatmap(uI, uT, Mra, nanMaskAfter, maskColor, 'Residual after mode1 (same scale)');
clim([-sameScale sameScale]);
xlabel('Current (mA)'); ylabel('Temperature (K)');

annotation(fig, 'textbox', [0.16 0.01 0.74 0.05], ...
    'String', 'both panels use identical symmetric scale set by max |residual before|; gray = unsupported', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11);

exportgraphics(fig, fullfile(figDir, [base_name '.png']), 'Resolution', 300);
close(fig);

%% Figure 3: residual after zoomed + masked
base_name = 'switching_corrected_old_QA_refined_residual_after_zoomed_masked';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [80 80 640 520], 'Color', 'w');
afterScale = max(abs(Mra), [], 'all', 'omitnan');
maskedHeatmap(uI, uT, Mra, nanMaskAfter, maskColor, 'Residual after mode1 (zoomed scale)');
clim([-afterScale afterScale]);
xlabel('Current (mA)'); ylabel('Temperature (K)');
text(0.02, 0.96, 'gray = unsupported / outside finite aligned support', ...
    'Units', 'normalized', 'FontSize', 10, 'Color', [0.25 0.25 0.25], ...
    'BackgroundColor', [1 1 1], 'Margin', 2);
exportgraphics(fig, fullfile(figDir, [base_name '.png']), 'Resolution', 300);
close(fig);

%% Figure 4: phi1 + kappa1 support annotations
base_name = 'switching_corrected_old_QA_refined_phi1_kappa1_support_annotated';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [80 80 1200 470], 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
x = phiT.x_aligned;
y = phiT.Phi1_corrected_old;
mf = isfinite(y);
plot(x(mf), y(mf), '-', 'Color', [0 0.45 0.74], 'LineWidth', 2); hold on;
plot(x(mf), y(mf), 'o', 'MarkerSize', 4, 'MarkerFaceColor', [0 0.45 0.74], 'MarkerEdgeColor', 'none');
grid on;
xlabel('x aligned ((I - I_{peak}) / W)');
ylabel('\Phi_1 (corrected-old)');
title('\Phi_1 with finite support points');
text(0.02, 0.05, 'line is visual connector; support is sparse', ...
    'Units', 'normalized', 'FontSize', 10, 'Color', [0.3 0.3 0.3]);

nexttile;
plot(kap.T_K, kap.kappa1_corrected_old, 'o-', 'LineWidth', 2, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.85 0.33 0.1]); hold on;
xline(22, '--', '22 K', 'LabelVerticalAlignment', 'middle', 'Color', [0.35 0.35 0.35], 'HandleVisibility', 'off');
xline(24, '--', '24 K', 'LabelVerticalAlignment', 'middle', 'Color', [0.35 0.35 0.35], 'HandleVisibility', 'off');
xline(30, ':', '30 K boundary caution', 'LabelVerticalAlignment', 'bottom', 'Color', [0.55 0 0], 'HandleVisibility', 'off');
grid on;
xlabel('Temperature (K)');
ylabel('\kappa_1 (corrected-old)');
title('\kappa_1 vs T (annotated)');

exportgraphics(fig, fullfile(figDir, [base_name '.png']), 'Resolution', 300);
close(fig);

%% Figure 5: quality by T + improvement factor
base_name = 'switching_corrected_old_QA_refined_quality_by_T_improvement';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [80 80 1200 500], 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

Tq = qByT.T_K;
rb = qByT.rmse_backbone_only;
rafter = qByT.rmse_after_mode1;
improve = rb ./ rafter;

nexttile;
yyaxis left;
plot(Tq, rb, 's-', 'DisplayName', 'RMSE backbone'); hold on;
plot(Tq, rafter, 'o-', 'DisplayName', 'RMSE after mode1');
ylabel('RMSE (S units)');
yyaxis right;
plot(Tq, improve, 'd-', 'Color', [0.2 0.6 0.2], 'DisplayName', 'Improvement factor');
ylabel('RMSE_{backbone} / RMSE_{after}');
xline(30, ':', '30 K caution', 'Color', [0.55 0 0], 'HandleVisibility', 'off');
grid on; xlabel('Temperature (K)');
title('Per-T RMSE and improvement factor');
legend('Location', 'best');

nexttile;
plot(Tq, qByT.mean_abs_DeltaS, 's-', 'DisplayName', 'mean |\DeltaS|'); hold on;
plot(Tq, qByT.mean_abs_DeltaS_after_mode1, 'o-', 'DisplayName', 'mean |\DeltaS_{after}|');
xline(30, ':', '30 K caution', 'Color', [0.55 0 0], 'HandleVisibility', 'off');
grid on;
xlabel('Temperature (K)');
ylabel('Mean absolute residual');
title('Per-T mean absolute residual');
legend('Location', 'best');

exportgraphics(fig, fullfile(figDir, [base_name '.png']), 'Resolution', 300);
close(fig);

fprintf('Refined visual QA complete. Output folder:\n%s\n', figDir);

function M = pivotField(tbl, uT, uI, varName)
M = nan(numel(uT), numel(uI));
Tcol = tbl.T_K;
Icol = tbl.current_mA;
V = tbl.(varName);
for i = 1:numel(uT)
    for j = 1:numel(uI)
        idx = find(Tcol == uT(i) & Icol == uI(j), 1, 'first');
        if ~isempty(idx)
            M(i, j) = V(idx);
        end
    end
end
end

function maskedHeatmap(uI, uT, M, nanMask, maskColor, ttl)
ax = gca;
set(ax, 'Color', maskColor);
h = imagesc(uI, uT, M);
axis xy;
colormap(ax, parula);
colorbar;
if any(nanMask(:))
    alpha = ones(size(M));
    alpha(nanMask) = 0;
    set(h, 'AlphaData', alpha);
end
title(ttl);
end
