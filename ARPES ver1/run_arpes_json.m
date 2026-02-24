%% run_arpes_dual.m
% Load and display FS and CUT together with consistent aspect ratio

clc;

%% ===== FILES =====
fname_FS  = "L:\My Drive\Quantum materials lab\ARPES\Co0.33TaS2_KbMbKb_cut\graph_FS_MGM.json";
fname_CUT = "L:\My Drive\Quantum materials lab\ARPES\Co0.33TaS2_KbMbKb_cut\graph_KbMbKb_second_derivative.json";

%% ===== USER CONTROLS =====
useROI = true;
Emin_user = -0.12;
Emax_user =  0.04;

useIntensityScaling = false;
intensityScale = 1e5;

%% ===== LOAD FS =====
[Kx, Ky, Z_FS] = load_arpes_json(fname_FS);

Z_FS = Z_FS - prctile(Z_FS(:),1);
Z_FS = Z_FS / prctile(Z_FS(:),99);
Z_FS = max(min(Z_FS,1),0);

fs_ratio = range(Ky) / range(Kx);

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

fprintf('FS: min=%g max=%g\n', min(Z_FS(:)), max(Z_FS(:)))
fprintf('CUT: min=%g max=%g\n', min(Z_CUT(:)), max(Z_CUT(:)))
%% ===== COLORMAP =====
cmap = cmocean('curl',256);
% Alternative custom colormap:
% cmap = arpesTerrain(256);

%% ===== PLOT FS =====
figure('Color','w','Name','ARPES_FS','NumberTitle','off');

imagesc(Kx, Ky, Z_FS.');
axis tight

dx = range(Kx);
dy = range(Ky);
half = min(dx,dy)/2;
xlim([-half half])
ylim([-half half])

set(gca,'YDir','normal');
xlabel('$k_x\ (\mathrm{\AA^{-1}})$','Interpreter','latex');
ylabel('$k_y\ (\mathrm{\AA^{-1}})$','Interpreter','latex');
set(gca,'FontSize',14);

apply_colorbar(Z_FS, useIntensityScaling, intensityScale);

colormap(cmap);

%% ===== PLOT CUT =====
figure('Color','w','Name','ARPES_CUT','NumberTitle','off');

imagesc(Ky_cut, Energy, Z_CUT.');
ylim([min(Energy) max(Energy)]);

axis tight

set(gca,'YDir','normal');
xlabel('$k_y\ (\mathrm{\AA^{-1}})$','Interpreter','latex');
ylabel('$\mathrm{Binding\ Energy}\ \mathrm{(eV)}$','Interpreter','latex');
set(gca,'FontSize',14);

apply_colorbar(Z_CUT, useIntensityScaling, intensityScale);

colormap(cmap);
box on;

%% ===== FUNCTIONS =====

function [Axis1, Axis2, Z] = load_arpes_json(fname)

S = jsondecode(fileread(fname));
Z = double(S.mes_data).';
scales = S.mes_scales;

Axis1 = double(scales{1});
Axis2 = double(scales{2});

end


function apply_colorbar(Z, useScaling, scale)

v = Z(:);
if min(v) < 0
    caxis([-1 1]);
else
    caxis([0 1]);
end

cb = colorbar;
cb.TickLabelInterpreter = 'latex';
cb.FontSize = 14;

ax = gca;
ax.TickLabelInterpreter = 'latex';

cb.Label.String = 'Intensity (arb. units)';
cb.Label.Interpreter = 'latex';
cb.Label.FontSize = 14;

end


function cmap = arpesTerrain(n)
if nargin<1, n=256; end

anchors = [
    0.00 0.15 0.50
    0.00 0.55 0.80
    0.10 0.75 0.45
    0.80 0.85 0.35
    0.65 0.45 0.25
    0.50 0.32 0.25
    0.98 0.98 0.98
];

x  = linspace(0,1,size(anchors,1));
xi = linspace(0,1,n);

cmap = interp1(x,anchors,xi,'pchip');
end