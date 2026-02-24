%% run_arpes_dual.m
% FS = true 1:1
% CUT uses same PlotBoxAspectRatio as FS

clc; close all;

%% ===== FILES =====
fname_FS  = "L:\My Drive\Quantum materials lab\ARPES\Co0.33TaS2_KbMbKb_cut\graph_FS_MGM.json";
fname_CUT = "L:\My Drive\Quantum materials lab\ARPES\Co0.33TaS2_KbMbKb_cut\graph_KbMbKb_second_derivative.json";

%% ===== USER CONTROLS =====
useROI = true;
Emin_user = -0.12;
Emax_user =  0.04;

%% ===== FIGURE SIZE (cm) =====
figW = 12;
figH = 12;

%% ===== LOAD FS =====
[Kx, Ky, Z_FS] = load_arpes_json(fname_FS);

Z_FS = Z_FS - prctile(Z_FS(:),1);
Z_FS = Z_FS / prctile(Z_FS(:),99);
Z_FS = max(min(Z_FS,1),0);

%% ===== LOAD CUT =====
[Energy, Ky_cut, Z_CUT] = load_arpes_json(fname_CUT);

if useROI
    maskE = (Energy >= Emin_user) & (Energy <= Emax_user);
    Energy = Energy(maskE);
    Z_CUT = Z_CUT(:,maskE);
end

Z_CUT = Z_CUT - prctile(Z_CUT(:),1);
Z_CUT = Z_CUT / prctile(Z_CUT(:),99);
Z_CUT = max(min(Z_CUT,1),0);

%% ===== COLORMAP =====
cmap = cmocean('curl',256);

%% ================= FS =================
figure('Color','w','Units','centimeters','Position',[5 5 figW figH],'Name','arpes_fermi_surface');

ax1 = axes;

imagesc(ax1,Kx,Ky,Z_FS.');
set(ax1,'YDir','normal')
axis(ax1,'equal')
axis(ax1,'tight')


dx = range(Kx);
dy = range(Ky);
half = min(dx,dy)/2;
xlim(ax1,[-half half])
ylim(ax1,[-half half])

xlabel(ax1,'$k_y\ (\mathrm{\AA^{-1}})$','Interpreter','latex');
ylabel(ax1,'$k_y\ (\mathrm{\AA^{-1}})$','Interpreter','latex');
set(ax1,'FontSize',14)

colormap(ax1,cmap)
cb1 = colorbar(ax1,'northoutside');
ylabel(cb1,'Intensity (arb. units)','Interpreter','latex');

% ---- capture FS physical plot box ----
pb = ax1.PlotBoxAspectRatio;
posFS = ax1.Position;
%% ================= CUT =================
figure('Color','w','Units','centimeters','Position',[20 5 figW figH],'Name','arpes_energy_momentum_cut');

ax2 = axes;

imagesc(ax2,Ky_cut,Energy,Z_CUT.');
set(ax2,'YDir','normal')
axis(ax2,'tight')

% ---- enforce same physical height as FS ----
ax2.PlotBoxAspectRatio = pb;

xlabel(ax2,'$k_y\ (\mathrm{\AA^{-1}})$','Interpreter','latex');
ylabel(ax2,'$\mathrm{Binding\ Energy}\ \mathrm{(eV)}$','Interpreter','latex');
set(ax2,'FontSize',14)

colormap(ax2,cmap)
cb2 = colorbar(ax2,'northoutside');
ylabel(cb2,'Intensity (arb. units)','Interpreter','latex');
ax2.Position = posFS;
%% ===== FUNCTIONS =====

function [Axis1,Axis2,Z] = load_arpes_json(fname)

S = jsondecode(fileread(fname));
Z = double(S.mes_data).';
scales = S.mes_scales;

Axis1 = double(scales{1});
Axis2 = double(scales{2});

end
function apply_colorbar(Z, useScaling, scale)

v = Z(:);

if min(v)<0
    caxis([-1 1])
else
    caxis([0 1])
end

cb = colorbar('northoutside');   % <<< למעלה
cb.TickLabelInterpreter = 'latex';
cb.FontSize = 14;

ax = gca;
ax.TickLabelInterpreter = 'latex';

cb.Label.String = '\mathrm{Intensity\ (arb.\ units)}';
cb.Label.Interpreter = 'latex';
cb.Label.FontSize = 14;

% קצת ריווח מהאיור (אופציונלי)
cb.Position(2) = cb.Position(2) + 0.02;

end