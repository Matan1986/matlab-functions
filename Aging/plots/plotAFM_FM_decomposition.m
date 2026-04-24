function plotAFM_FM_decomposition(pauseRun, fontsize)
% ============================================================
% AGING MODULE - CLARITY HEADER
%
% ROLE:
% Diagnostic visualization for direct smooth/residual decomposition.
%
% DECOMPOSITION TYPE:
% DIRECT
%
% STAGE:
% other
%
% DOES:
% - plot DeltaM with DeltaM_smooth and DeltaM_sharp for a single run
% - visualize direct decomposition representation
%
% DOES NOT:
% - define stage6 summary observables
% - represent the default AFM_like / FM_like summary source
%
% AFFECTS SUMMARY OBSERVABLES:
% NO
%
% NOTES:
% This file is part of a multi-decomposition system.
% It does not define the canonical observable by itself unless stated.
% ============================================================
% =========================================================
% plotAFM_FM_decomposition
%
% PURPOSE:
%   Plot DeltaM decomposition into FM-like smooth background and AFM-like dip.
%
% This function plots a single-run decomposition:
%
%   DeltaM(T) = DeltaM_smooth(T) + DeltaM_sharp(T)
%
% This is:
%   - a function-level decomposition
%   - used for analysis/debugging
%
% This is NOT:
%   - the AFM/FM summary vs pause temperature
%   - NOT a basic plotting target
%
% INPUTS:
%   pauseRun  - struct with fields T_common, DeltaM, DeltaM_smooth, DeltaM_sharp
%   fontsize  - base font size
%
% OUTPUTS:
%   none (creates figure)
%
% Physics meaning:
%   AFM = sharp dip in DeltaM (memory component)
%   FM  = smooth background (step-like)
%
% =========================================================

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

% [DIRECT_DECOMPOSITION]
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
