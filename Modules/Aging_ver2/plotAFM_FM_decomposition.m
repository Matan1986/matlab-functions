function plotAFM_FM_decomposition(pauseRun, fontsize)
% plotAFM_FM_decomposition
% ------------------------------------------------------------
% Panel-style plot:
%   (a) ΔM(T)
%   (b) smooth (FM) + sharp (AFM)
%   (c) sharp only (memory dip)
%
% Domain shown = domain actually used in AFM/FM analysis
% Consistent with excludeLowT_* stored inside pauseRun.
% ------------------------------------------------------------

if nargin < 2 || isempty(fontsize)
    fontsize = 16;
end

T  = pauseRun.T_common(:);
dM = pauseRun.DeltaM(:);

dM_smooth = pauseRun.DeltaM_smooth(:);
dM_sharp  = pauseRun.DeltaM_sharp(:);

Tp = pauseRun.waitK;

% ------------------------------------------------------------
% Define PHYSICAL valid domain
% ------------------------------------------------------------
valid = isfinite(T) & isfinite(dM) & isfinite(dM_smooth);

if isfield(pauseRun,'excludeLowT_FM') && pauseRun.excludeLowT_FM
    if isfield(pauseRun,'excludeLowT_K') && ~isempty(pauseRun.excludeLowT_K)
        valid = valid & (T >= pauseRun.excludeLowT_K);
    end
end

% Mask everything consistently
Tplot  = T;        Tplot(~valid)  = NaN;
dMplot = dM;       dMplot(~valid) = NaN;

dM_smooth(~valid) = NaN;
dM_sharp(~valid)  = NaN;

if any(valid)
    Tmin = min(T(valid));
    Tmax = max(T(valid));
else
    Tmin = min(T);
    Tmax = max(T);
end

% ------------------------------------------------------------
% Figure
% ------------------------------------------------------------
figure('Color','w', ...
    'Name',sprintf('AFM–FM Decomposition, %.0f K', Tp));

tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

% ------------------------------------------------------------
% (a) Raw ΔM
% ------------------------------------------------------------
nexttile;
plot(Tplot, dMplot, 'k', 'LineWidth',1.6); hold on;
xline(Tp,'--r','LineWidth',1.2);
xlim([Tmin Tmax]);
ylabel('\Delta M');
title(sprintf('Pause at %.0f K', Tp),'FontWeight','bold');

% ------------------------------------------------------------
% (b) Smooth + sharp
% ------------------------------------------------------------
nexttile;
plot(Tplot, dM_smooth, 'b', 'LineWidth',1.6); hold on;
plot(Tplot, dM_sharp,  'r', 'LineWidth',1.2);
xline(Tp,'--k','LineWidth',1.0);
xlim([Tmin Tmax]);
ylabel('\Delta M');
legend('Smooth (FM)','Sharp (AFM)','Location','best');

% ------------------------------------------------------------
% (c) Sharp only
% ------------------------------------------------------------
nexttile;
plot(Tplot, dM_sharp, 'r', 'LineWidth',1.6); hold on;
xline(Tp,'--k','LineWidth',1.0);
xlim([Tmin Tmax]);
xlabel('Temperature (K)');
ylabel('\Delta M_{AFM}');


set(findall(gcf,'-property','FontSize'),'FontSize',fontsize);
end
