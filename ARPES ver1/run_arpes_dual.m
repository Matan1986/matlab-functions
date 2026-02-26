%% run_arpes_dual.m
clc; close all;

%% ===== FILES =====
fname_FS  = "L:\My Drive\Quantum materials lab\ARPES\Co0.33TaS2_KbMbKb_cut\graph_FS_MGM.json";
fname_CUT = "L:\My Drive\Quantum materials lab\ARPES\Co0.33TaS2_KbMbKb_cut\graph_KbMbKb_second_derivative.json";

%% ===== USER CONTROLS =====
useROI = true;
Emin_user = -0.12;
Emax_user =  0.04;

useInsetFS = true;
insetSize = 0.45;

%% ===== EXPORT =====
exportSVG = false;
exportPDF = true;
outDir = "L:\My Drive\Quantum materials lab\Switching paper\Graphs for papers\Graphs for paper ver3\Fig1\Res HC (all out of plane) FIB2 and ARPES\Final ver15";

%% ===== FIG SIZE (cm) =====
figW = 18;
figH = 18;

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
color = [1 0 0];
%% ================= CUT =================
figCUT = figure('Color','w','Units','centimeters','Position',[5 5 figW figH]);
ax2 = axes(figCUT);

imagesc(ax2,Ky_cut,Energy,Z_CUT.');
set(ax2,'YDir','normal')
axis(ax2,'tight')
pbaspect(ax2,[1 1 1])

xlabel(ax2,'$k_y\ (\mathrm{\AA^{-1}})$','Interpreter','latex');
ylabel(ax2,'$\mathrm{Binding\ Energy}\ \mathrm{(eV)}$','Interpreter','latex');
set(ax2,'FontSize',14)

colormap(ax2,cmap)
caxis(ax2,[0 1])

cb2 = colorbar(ax2,'eastoutside');
ylabel(cb2,'$\mathrm{Intensity\ (arb.\ units)}$','Interpreter','latex');

posMain = ax2.Position;

%% ================= FS INSET =================
if useInsetFS

insetW = posMain(3)*insetSize;
insetH = posMain(4)*insetSize;

insetLeft   = posMain(1)+posMain(3)-insetW-0.02;
insetBottom = posMain(2)+0.08;

axInset = axes('Parent',figCUT,'Position',[insetLeft insetBottom insetW insetH]);

imagesc(axInset,Kx,Ky,Z_FS.');
set(axInset,'YDir','normal')
axis(axInset,'equal')
axis(axInset,'tight')
stretchX = 0.725* axInset.Position(4) / axInset.Position(3);
stretchY = 0.88* axInset.Position(4) / axInset.Position(3);

colormap(axInset,cmap)
caxis(axInset,[0 1])

dx = range(Kx); dy = range(Ky);
half = min(dx,dy)/2;
xlim(axInset,[-half half])
ylim(axInset,[-half half])

axInset.XTick=[]; axInset.YTick=[];
axInset.Color='none';

box(axInset,'on')
axInset.LineWidth=1.8;
axInset.XColor='w';
axInset.YColor='w';

%% ===== Γ =====
GammaYOffset = 0.05*half;   % מרווח קטן למעלה

text(axInset,0,GammaYOffset,'$\Gamma$',...
    'Interpreter','latex',...
    'Color',color,...
    'FontSize',14,...
    'HorizontalAlignment','center',...
    'VerticalAlignment','bottom');

%% ===== HEXAGONS (inner rotated, outer slightly enlarged) =====

theta_inner = (0:6)*pi/3 + pi/6 + pi/2;   % inner rotated 90 deg
theta_outer = (0:6)*pi/3 + pi/6;          % outer original

R1 = 0.65*half;      % inner (keep – looks good)
R2 = 1.05*half;      % outer (just slightly outside frame)

dx_hex = -0.05;
dy_hex = 0;

x1 = stretchX * R1*cos(theta_inner) + dx_hex;
y1 = stretchY * (R1*sin(theta_inner)) + dy_hex;

x2 = stretchX * R2*cos(theta_outer) + dx_hex;
y2 = stretchY * (R2*sin(theta_outer)) + dy_hex;

hold(axInset,'on')
plot(axInset,x1,y1,'Color',color,'LineWidth',1.4,'LineStyle','--')
plot(axInset,x2,y2,'Color',color,'LineWidth',1.4,'LineStyle','--')

%% ===== Γ , K , K0 from actual hexagon vertices =====

% ---- Gamma point ----
plot(axInset,dx_hex,0,...
     'o',...
    'MarkerFaceColor',color,...
    'MarkerEdgeColor',color,...
    'MarkerSize',4)

% ---- K from INNER hexagon (choose NE corner) ----
[~,idxK] = max(x1 + y1);   % same as before: NE vertex
K_inner = [x1(idxK), y1(idxK)];

% ---- K0 = NEXT vertex clockwise on OUTER hexagon ----
% (clockwise = index - 1)
idxK0 = idxK - 6;
if idxK0 < 1
    idxK0 = length(x2)-1;   % wrap around (ignore duplicated last point)
end

K_outer = [x2(idxK0), y2(idxK0)];

% ---- plot points ----
plot(axInset,K_inner(1),K_inner(2),...
    'o',...
    'MarkerFaceColor',color,...
    'MarkerEdgeColor',color,...
    'MarkerSize',4)

plot(axInset,K_outer(1),-K_outer(2),...
    'o',...
    'MarkerFaceColor',color,...
    'MarkerEdgeColor',color,...
    'MarkerSize',4)

% ---- labels ----
text(axInset,K_inner(1)*0.85,K_inner(2)*1.15,'$K$',...
    'Interpreter','latex','Color',color,'FontSize',14);

text(axInset,K_outer(1)*0.9,-K_outer(2)*1.2,'$K_0$',...
    'Interpreter','latex','Color',color,'FontSize',14);



%% FS label
text(axInset,0.04,0.96,'FS','Units','normalized','Color','w',...
    'FontSize',14,'FontWeight','bold','VerticalAlignment','top');

end

%% ===== EXPORT =====
if exportSVG
    export_fig(figCUT, fullfile(outDir,'arpes_cut_with_FS_inset.svg'));
end

if exportPDF
    exportgraphics(figCUT, fullfile(outDir,'arpes_cut_with_FS_inset.pdf'), 'ContentType','vector')
end

%% ===== FUNCTIONS =====
function [Axis1,Axis2,Z] = load_arpes_json(fname)
S = jsondecode(fileread(fname));
Z = double(S.mes_data).';
scales = S.mes_scales;
Axis1 = double(scales{1});
Axis2 = double(scales{2});
end