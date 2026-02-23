%% run_arpes_json.m
% ARPES JSON loader (Igor export)
% Fix Igor->MATLAB orientation by single transpose

clc; clear;

fname = "L:\My Drive\Quantum materials lab\ARPES\Co0.33TaS2_KbMbKb_cut\graph_KbMbKb_second_derivative.json";

%% ===== LOAD =====
S = jsondecode(fileread(fname));

Z = double(S.mes_data);

% ---- CRITICAL FIX: Igor orientation ----
Z = Z.';   % Energy now along columns, Ky along rows

scales = S.mes_scales;

% Igor order: {Energy , Ky}
Energy = double(scales{1});
Ky     = double(scales{2});

fprintf('Z = %d x %d\n',size(Z,1),size(Z,2));
fprintf('Energy: %.4f → %.4f\n',min(Energy),max(Energy));
fprintf('Ky:     %.4f → %.4f\n',min(Ky),max(Ky));

%% ===== Energy ROI =====
Emin = -0.12;
Emax =  0.04;

maskE = (Energy >= Emin) & (Energy <= Emax);
Energy_zoom = Energy(maskE);
Z_zoom = Z(:,maskE);

%% ===== PLOT =====
figure('Color','w');

% --- ROTATE: X=Ky, Y=Energy ---
imagesc(Ky, Energy_zoom, Z_zoom.');   % <-- 90° rotation
set(gca,'YDir','normal');

% --- FLIP X axis (whole figure + ticks) ---
set(gca,'XDir','reverse');

xlabel('Ky','Interpreter','none');
ylabel('Binding Energy (E - E_f)','Interpreter','none');

% contrast only from ROI
v = Z_zoom(:);
caxis(prctile(v,[2 98]));

colormap(arpesTerrain(256));
colorbar;

xlim([min(Ky) max(Ky)]);
ylim([Emin Emax]);

title('ARPES second derivative (EF zoom)');
set(gca,'FontSize',14);
box on;

%% ===== COLORMAP =====
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