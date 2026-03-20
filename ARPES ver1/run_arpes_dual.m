%% run_arpes_dual.m
clc; close all;

%% ===== FILES =====
fname_FS  = "L:\My Drive\Quantum materials lab\ARPES\Co0.33TaS2_KbMbKb_cut\graph_FS_MGM.json";
fname_CUT = "L:\My Drive\Quantum materials lab\ARPES\Co0.33TaS2_KbMbKb_cut\graph_KbMbKb_second_derivative.json";

%% ===== USER CONTROLS =====
useROI = true;
Emin_user = -0.12;
Emax_user =  0.04;
showDeltaHistogram = true;

%% ===== EXPORT =====
exportSVG = false;
exportPDF = true;
outDir = "L:\My Drive\Quantum materials lab\Switching paper\Graphs for papers\Graphs for paper\Fig1\Fig1 ver19";

%% ===== FIG SIZE (cm) =====
axWidth_cm  = 12;
axHeight_cm = 12;
cbWidth_cm  = 0.6;
gap_cm      = 0.3;
margin_cm   = 2;
baseFont = 14;

figW = axWidth_cm + cbWidth_cm + gap_cm + 2*margin_cm;
figH = axHeight_cm + 2*margin_cm;

%% ===== LOAD FS =====
[Kx, Ky, Z_FS, bz_xs, bz_ys, bz_xs_0, bz_ys_0] = load_arpes_json(fname_FS);

% Delta map from raw FS data (no pre-normalization)
% --- FS preprocessing ---
Z_raw = Z_FS;

% Light denoising
Z0 = imgaussfilt(Z_raw, 0.8);

% Broad background (must be from raw)
Z_bg = imgaussfilt(Z_raw, 30);

% Stabilize denominator to avoid blow-ups
bg_floor = prctile(abs(Z_bg(:)), 0.6);
denom = max(abs(Z_bg), bg_floor);

% Normalized delta
Z_delta = (Z0 - Z_bg) ./ denom;

% Remove global offset (centering distribution)
Z_delta = Z_delta - median(Z_delta(:));

% Mild display smoothing
Z_plot = imgaussfilt(Z_delta, 0.8);

supportMask = Z_bg > prctile(Z_bg(:), 85);
valid = supportMask & ~isnan(Z_plot);
vals = Z_plot(valid);

clim_low  = prctile(vals, 1);
clim_high = prctile(vals, 99);

% ===== fallback נכון =====
if ~(isfinite(clim_low) && isfinite(clim_high) && clim_low < clim_high)
    clim_low  = min(vals);
    clim_high = max(vals);

    if ~(isfinite(clim_low) && isfinite(clim_high) && clim_low < clim_high)
        clim_low  = -1;
        clim_high = 1;
    end
end

clim_vals = [clim_low clim_high];

if showDeltaHistogram
    figure('Color','w','Name','fs_delta_histogram');
    histogram(Z_plot(:), 100);
    xline(0, '--k', 'LineWidth', 1.2);
    xlabel('Normalized \Delta I');
    ylabel('Counts');
    set(gca, 'FontSize', baseFont, 'LineWidth', 0.5, 'TickDir', 'in', 'Box', 'on');
end

%% ===== LOAD CUT =====
[Energy, Ky_cut, Z_CUT] = load_arpes_json(fname_CUT);

if useROI
    maskE = (Energy >= Emin_user) & (Energy <= Emax_user);
    Energy = Energy(maskE);
    Z_CUT = Z_CUT(:,maskE);
end

% Percentile normalization for paper-style intensity rendering
p_low = prctile(Z_CUT(:), 1);
p_high = prctile(Z_CUT(:), 99);
if p_high > p_low
    Z_CUT = (Z_CUT - p_low) / (p_high - p_low);
else
    Z_CUT = zeros(size(Z_CUT));
end
Z_CUT = max(0, min(1, Z_CUT));

%% ===== COLORMAP =====
cmap_cut = interp1([0 0.25 0.5 0.75 1], ...
    [0.1 0.1 0.6;    %
     0 0.6 0.3;      %
     1 1 0.6; ...
     0.6 0.4 0.3; ...
    0.95 0.95 0.95], ...
    linspace(0,1,256));
cmap_fs = cmap_cut;

%% ================= CUT =================
figCUT = figure('Color','w','Units','centimeters','Position',[5 5 figW figH]);
set(figCUT, 'Name', 'ARPES Cut (Second Derivative)', 'NumberTitle', 'off')
ax2 = axes('Parent', figCUT, 'Units', 'centimeters');
ax2.Position = [margin_cm, margin_cm, axWidth_cm, axHeight_cm];

imagesc(ax2,Ky_cut,Energy,Z_CUT.');
axis(ax2,'xy')
axis(ax2,'tight')

K_pos = 0.7300596424962338 / 2;
xline(ax2, -K_pos, '--', 'Color', [0 0 0]*0.7, 'LineWidth', 1.0)
xline(ax2,  K_pos, '--', 'Color', [0 0 0]*0.7, 'LineWidth', 1.0)
xticks(ax2, [-K_pos 0 K_pos])
xticklabels(ax2, {'$K$','$M$','$K$'})
set(ax2, 'TickLabelInterpreter', 'latex')

xlabel(ax2,'$k_y\ (\mathrm{\AA^{-1}})$','Interpreter','latex','FontSize',baseFont);
ylabel(ax2,'$\mathrm{Binding\ Energy}\ \mathrm{(eV)}$','Interpreter','latex','FontSize',baseFont);
set(ax2,'FontSize',baseFont)

yl = ylim(ax2);
yt = linspace(yl(1), yl(2), 5);
yticks(ax2, yt);
ax2.YTickLabel = compose('%.2f', yt);


colormap(ax2,cmap_cut)
caxis(ax2,[0 1])

set(ax2,'FontSize',baseFont,'LineWidth',0.5,'TickDir','in','Box','on')
set(ax2, 'ActivePositionProperty', 'position');
set(ax2, 'PositionConstraint', 'innerposition');
set(ax2, 'LooseInset', [0 0 0 0]);

cb2 = colorbar(ax2);
cb2.Location = 'eastoutside';
cb2.Units = 'centimeters';
drawnow;
ax2.Position = [margin_cm, margin_cm, axWidth_cm, axHeight_cm];
cb2.Position = [ ...
    margin_cm + axWidth_cm + gap_cm, ...
    margin_cm, ...
    cbWidth_cm, ...
    axHeight_cm];
cb2.FontSize = ax2.FontSize;
cb2.FontName = ax2.FontName;
cb2.LineWidth = ax2.LineWidth;
cb2.Label.String = 'Second derivative (a.u.)';
cb2.Label.FontSize = ax2.FontSize;
cb2.Label.FontName = ax2.FontName;
cb2.Label.FontWeight = 'normal';
cb2.Label.Interpreter = 'latex';
cb2.TickLength = 0;
ticks = linspace(0, 1, 5);
cb2.Ticks = ticks;
cb2.TickLabels = compose('%.2f', ticks);
ax2.XAxis.Exponent = 0;
ax2.YAxis.Exponent = 0;

%% ================= FS FIGURE (INDEPENDENT) =================
figFS = figure('Color','w','Units','centimeters','Position',[5 5 figW figH]);
set(figFS, 'Name', 'Fermi Surface (Delta Map)', 'NumberTitle', 'off')
axFS = axes('Parent', figFS, 'Units', 'centimeters');
axFS.Position = [margin_cm, margin_cm, axWidth_cm, axHeight_cm];
setappdata(axFS, 'bz_xs', bz_xs);
setappdata(axFS, 'bz_ys', bz_ys);
setappdata(axFS, 'bz_xs_0', bz_xs_0);
setappdata(axFS, 'bz_ys_0', bz_ys_0);

set(axFS, ...
    'FontSize', baseFont, ...
    'LineWidth', 0.5, ...
    'TickDir', 'in', ...
    'Box', 'on');

plot_fs(axFS, Ky, Kx, Z_plot, cmap_fs, clim_vals,baseFont);

xlabel(axFS,'$k_y\ (\mathrm{\AA^{-1}})$','Interpreter','latex','FontSize',baseFont);
ylabel(axFS,'$k_x\ (\mathrm{\AA^{-1}})$','Interpreter','latex','FontSize',baseFont);
xl = xlim(axFS);
yl = ylim(axFS);
xt = round(linspace(xl(1), xl(2), 5) * 2) / 2;
yt = round(linspace(yl(1), yl(2), 5) * 2) / 2;
xticks(axFS, xt);
yticks(axFS, yt);
axFS.XTickLabel = compose('%.1f', xt);
axFS.YTickLabel = compose('%.1f', yt);
grid(axFS,'off');
set(axFS, 'ActivePositionProperty', 'position');
set(axFS, 'PositionConstraint', 'innerposition');
set(axFS, 'LooseInset', [0 0 0 0]);
cbFS = colorbar(axFS);
cbFS.Location = 'eastoutside';
cbFS.Units = 'centimeters';
drawnow;
axFS.Position = [margin_cm, margin_cm, axWidth_cm, axHeight_cm];
cbFS.Position = [ ...
    margin_cm + axWidth_cm + gap_cm, ...
    margin_cm, ...
    cbWidth_cm, ...
    axHeight_cm];
cbFS.FontSize = axFS.FontSize;
cbFS.FontName = axFS.FontName;
cbFS.LineWidth = axFS.LineWidth;
cbFS.Label.String = 'Normalized intensity contrast (a.u.)';
cbFS.Label.FontSize = axFS.FontSize;
cbFS.Label.FontName = axFS.FontName;
cbFS.Label.FontWeight = 'normal';
cbFS.Label.Interpreter = 'latex';
caxis(axFS, [-1 1]);
ticks = -1:0.5:1;
cbFS.Ticks = ticks;
cbFS.TickLabels = compose('%.1f', ticks);
cbFS.TickLength = 0;
axFS.XAxis.Exponent = 0;
axFS.YAxis.Exponent = 0;

% Temporary debug check: CUT and FS axes positions should match
ax2.Units = 'centimeters';
axFS.Units = 'centimeters';
disp(ax2.Position)
disp(axFS.Position)

%% ===== EXPORT =====
if exportSVG
    export_fig(figCUT, fullfile(outDir,'arpes_cut.svg'));
    if ~isempty(figFS)
        export_fig(figFS, fullfile(outDir,'arpes_FS.svg'));
    end
end

if exportPDF
    exportgraphics(figCUT, fullfile(outDir,'arpes_cut.pdf'), 'ContentType','vector')
    if ~isempty(figFS)
        exportgraphics(figFS, fullfile(outDir,'arpes_FS.pdf'), 'ContentType','vector')
    end
end

%% ===== FUNCTIONS =====
function [Axis1,Axis2,Z,bz_xs,bz_ys,bz_xs_0,bz_ys_0] = load_arpes_json(fname)
S = jsondecode(fileread(fname));
Z = double(S.mes_data).';
scales = S.mes_scales;
Axis1 = double(scales{1});
Axis2 = double(scales{2});

bz_xs   = getMetaField(S, 'bz_xs');
bz_ys   = getMetaField(S, 'bz_ys');
bz_xs_0 = getMetaField(S, 'bz_xs_0');
bz_ys_0 = getMetaField(S, 'bz_ys_0');
end

function v = getMetaField(S, name)
v = [];
if isfield(S, name)
    v = double(S.(name));
elseif isfield(S, 'metadata') && isstruct(S.metadata) && isfield(S.metadata, name)
    v = double(S.metadata.(name));
elseif isfield(S, 'params') && isstruct(S.params) && isfield(S.params, name)
    v = double(S.params.(name));
end
end

function plot_fs(ax, Ky, Kx, Z_data, cmap, clim_vals,baseFont)

imagesc(ax, Ky, Kx, Z_data.');
set(ax,'YDir','normal')

% ===== FORCE SQUARE K-SPACE LIMITS =====
kx_min = min(Kx);
kx_max = max(Kx);
ky_min = min(Ky);
ky_max = max(Ky);

cx = (kx_min + kx_max)/2;
cy = (ky_min + ky_max)/2;

halfRange = max([kx_max - kx_min, ky_max - ky_min]) / 2;

xlim(ax, [cx - halfRange, cx + halfRange]);
ylim(ax, [cy - halfRange, cy + halfRange]);

axis(ax,'image')

ax.PlotBoxAspectRatio = [1 1 1];

% ===== VISUAL SETTINGS =====
caxis(ax, clim_vals);
colormap(ax, cmap)

set(ax,'PositionConstraint','innerposition')
set(ax,'LooseInset',[0 0 0 0])

% ===== OVERLAY =====
bz_xs = getappdata(ax, 'bz_xs');
bz_ys = getappdata(ax, 'bz_ys');
bz_xs_0 = getappdata(ax, 'bz_xs_0');
bz_ys_0 = getappdata(ax, 'bz_ys_0');
plot_fs_bz_overlay(ax, bz_xs, bz_ys, bz_xs_0, bz_ys_0,baseFont)

end

function plot_fs_bz_overlay(axFS, bz_xs, bz_ys, bz_xs_0, bz_ys_0,baseFont)
% Use Brillouin-zone polygons directly from FS JSON metadata
x_hex_inner = bz_xs(:).';
y_hex_inner = bz_ys(:).';
x_hex_outer = bz_xs_0(:).';
y_hex_outer = bz_ys_0(:).';

% Close loops for plotting
x_hex_inner_plot = [x_hex_inner x_hex_inner(1)];
y_hex_inner_plot = [y_hex_inner y_hex_inner(1)];
x_hex_outer_plot = [x_hex_outer x_hex_outer(1)];
y_hex_outer_plot = [y_hex_outer y_hex_outer(1)];

hold(axFS,'on')
bzColor = [0 0 0];

% Plot hexagons
plot(axFS, x_hex_inner_plot, y_hex_inner_plot, '--', ...
    'Color', bzColor, 'LineWidth', 1.0)

plot(axFS, x_hex_outer_plot, y_hex_outer_plot, '--', ...
    'Color', bzColor, 'LineWidth', 1.2)

% Identify lower inner-BZ edge and define K-M-K cut points
[~, idxSortY] = sort(y_hex_inner, 'ascend');
idxLower = idxSortY(1:2);
xLower = x_hex_inner(idxLower);
yLower = y_hex_inner(idxLower);
[xK, order] = sort(xLower, 'ascend');
yK = yLower(order);
xM = mean(xK);
yM = mean(yK);

% Gamma point
plot(axFS, 0, 0, 'o', 'Color', bzColor, 'MarkerFaceColor', bzColor, 'MarkerEdgeColor', bzColor, 'LineWidth', 1, 'MarkerSize', 4)
text(axFS, 0, 0.05, '$\Gamma$', 'Interpreter', 'latex', ...
    'Color', bzColor, 'FontWeight', 'normal', 'FontSize', baseFont, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

% Plot only lower-edge K-M-K cut markers and labels
plot(axFS, xK(1), yK(1), 'o', 'Color', bzColor, 'MarkerFaceColor', bzColor, 'MarkerEdgeColor', bzColor, 'LineWidth', 1, 'MarkerSize', 4)
plot(axFS, xM,   yM,   'o', 'Color', bzColor, 'MarkerFaceColor', bzColor, 'MarkerEdgeColor', bzColor, 'LineWidth', 1, 'MarkerSize', 4)
plot(axFS, xK(2), yK(2), 'o', 'Color', bzColor, 'MarkerFaceColor', bzColor, 'MarkerEdgeColor', bzColor, 'LineWidth', 1, 'MarkerSize', 4)

labelOffsetY = 0.06;
text(axFS, xK(1), yK(1) - labelOffsetY, '$K$', 'Interpreter', 'latex', ...
    'Color', bzColor, 'FontWeight', 'normal', 'FontSize', baseFont-1, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
text(axFS, xM, yM - labelOffsetY, '$M$', 'Interpreter', 'latex', ...
    'Color', bzColor, 'FontWeight', 'normal', 'FontSize', baseFont-1, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
text(axFS, xK(2), yK(2) - labelOffsetY, '$K$', 'Interpreter', 'latex', ...
    'Color', bzColor, 'FontWeight', 'normal', 'FontSize', baseFont-1, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');

% K0 point from outer-BZ vertices
[~, K0_idx] = max(x_hex_outer + y_hex_outer);
K0_x = x_hex_outer(K0_idx);
K0_y = y_hex_outer(K0_idx);

plot(axFS, K0_x, K0_y, 'o', 'Color', bzColor, 'MarkerFaceColor', bzColor, 'MarkerEdgeColor', bzColor, 'LineWidth', 1, 'MarkerSize', 4)
text(axFS, K0_x - 0.10, K0_y - 0.10, '$K_{0}$', 'Interpreter', 'latex', ...
    'Color', bzColor, 'FontWeight', 'normal', 'FontSize', baseFont, 'HorizontalAlignment', 'center');

hold(axFS, 'off')
end

function labels = format_ticks(ticks)
if max(abs(ticks - round(ticks))) < 1e-6
    labels = compose('%d', round(ticks));
else
    labels = compose('%.1f', ticks);
end
end
