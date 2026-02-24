function state = stage6_extractMetrics(state, cfg)
% =========================================================
% stage6_extractMetrics
%
% PURPOSE:
%   Extract AFM/FM metrics, print diagnostics, and plot summary figures.
%
% INPUTS:
%   state - struct with pauseRuns
%   cfg   - configuration struct
%
% OUTPUTS:
%   state - unchanged data struct (diagnostic plots/prints only)
%
% Physics meaning:
%   AFM = dip height/area metrics
%   FM  = step/background metrics
%
% =========================================================

DipA     = [state.pauseRuns.Dip_A];
DipSigma = [state.pauseRuns.Dip_sigma];
FMstepA  = [state.pauseRuns.FM_step_A];
Tp       = [state.pauseRuns.waitK];

fprintf('\n=== Dip sigma statistics ===\n');
fprintf('min sigma = %.2f K\n', min(DipSigma));
fprintf('max sigma = %.2f K\n', max(DipSigma));
fprintf('mean sigma = %.2f K\n', mean(DipSigma));
fprintf('std/mean = %.2f\n', std(DipSigma)/mean(DipSigma));
% --- extra diagnostics: does sigma add independent info? ---
R_As = corr(DipA(:), DipSigma(:), 'rows','complete');
fprintf('corr(Dip_A, Dip_sigma) = %.2f\n', R_As);

% --- build per-component "strength" metrics (not ratios) ---
Dip_area = DipA .* sqrt(2*pi) .* DipSigma;   % integrated Gaussian weight

% normalize for comparison across metrics (z-score)
Z = @(x) (x - mean(x,'omitnan')) ./ (std(x,'omitnan') + eps);

Z_FM      = Z(FMstepA);
Z_DipA    = Z(DipA);
Z_DipArea = Z(Dip_area);

% --- quick table (all pauses) ---
diagTbl = table(Tp(:), FMstepA(:), DipA(:), DipSigma(:), Dip_area(:), ...
    Z_FM(:), Z_DipA(:), Z_DipArea(:), ...
    'VariableNames', {'Tp_K','FM_step_A','Dip_A','Dip_sigma_K','Dip_area','Z_FM','Z_DipA','Z_DipArea'});

disp(diagTbl);

% --- show only 5 representative pauses (spread across Tp) ---
n = numel(Tp);
idx5 = unique(round(linspace(1,n, min(5,n))));
disp(diagTbl(idx5,:));

% --- simple diagnostic plot: which metric separates pauses better? ---
figure('Color','w', ...
       'Name','Diagnostic: AFM vs FM metric variability', ...
       'NumberTitle','off');

ax = axes; 
hold(ax,'on');

plot(Tp, Z_FM, '-o',['LineWi' ...
    'dth'],1.5);
plot(Tp, Z_DipA, '-o','LineWidth',1.5);
plot(Tp, Z_DipArea, '-o','LineWidth',1.5);
xlabel('T_p (K)');
ylabel('Z-score (relative variation)');
legend('FM\_step\_A','Dip\_A','Dip\_area','Location','best');
title('Diagnostic: which component metric varies most across pauses?');

Tp        = [state.pauseRuns.waitK];
Dip_area = [state.pauseRuns.Dip_area];
FM_step  = [state.pauseRuns.FM_step_A];

% --- auto scaling (based on what is actually plotted) ---
FMvec = [state.pauseRuns.FM_E];   % row vector

switch cfg.AFM_metric_main
    case 'height'
        AFMvec = [state.pauseRuns.Dip_A];      % row vector
        unitStr = '\\mu_B / Co';

    case 'area'
        AFMvec = [state.pauseRuns.Dip_area];   % row vector
        unitStr = '\\mu_B·K / Co';

    otherwise
        error('Unknown AFM_metric_main: %s', cfg.AFM_metric_main);
end

% build probe vector (column), remove NaNs/Infs
yProbe = [AFMvec(:); FMvec(:)];
yProbe = yProbe(isfinite(yProbe));

if isempty(yProbe)
    warning('Auto-scale probe is empty. Falling back to scalePower=0.');
    scalePower  = 0;
    scaleFactor = 1;
else
    scalePower  = chooseAutoScalePower(yProbe);
    scaleFactor = 10^(scalePower);
end

% ===============================
% Build AFM / FM vectors for MAIN FIGURE
% ===============================

switch cfg.AFM_metric_main
    case 'height'
        Y_AFM = [state.pauseRuns.Dip_A];
        unitStr = '\\mu_B / Co';

    case 'area'
        Y_AFM = [state.pauseRuns.Dip_area];
        unitStr = '\\mu_B\\cdot K / Co';

    otherwise
        error('Unknown AFM_metric_main: %s', cfg.AFM_metric_main);
end

Y_FM = [state.pauseRuns.FM_E];   % local FM strength (RMS from fit)

% ===============================
% Colormap for pause temperatures (Tp)
% ===============================
Tp = [state.pauseRuns.waitK];
Tp = Tp(:)';

cmap = cmocean('thermal',256);

Tp_norm = (Tp - min(Tp)) ./ ...
          (max(Tp) - min(Tp) + eps);

idx = round(1 + Tp_norm*(size(cmap,1)-1));
Tp_colors = cmap(idx,:);



% --- marker style (locked for both panels) ---
markerEdgeColor = 'k';
markerEdgeWidth = 0.6;

figure('Color','w', ...
       'Name','Aging memory summary', ...
       'NumberTitle','off');


% ---------- (a) AFM memory (FIT-based) ----------
ax1 = subplot(2,1,1); hold(ax1,'on');

ax1.TickDir = 'in';
ax1.Box = 'on';
ax1.Layer = 'top';
ax1.FontName = 'Times New Roman';
ax1.TickLabelInterpreter = 'latex';
ax1.XMinorTick = 'off';
ax1.YMinorTick = 'off';
grid(ax1,'off');

% guide line
plot(Tp, Y_AFM * scaleFactor, '-', ...
    'Color',[0.6 0.6 0.6], 'LineWidth',1.2);

% markers
for i = 1:numel(Tp)
    plot(Tp(i), Y_AFM(i)*scaleFactor, 'o', ...
    'MarkerSize',9, ...
        'MarkerFaceColor',Tp_colors(i,:), ...
        'MarkerEdgeColor',markerEdgeColor, ...
        'LineWidth',markerEdgeWidth);
end

ylab_AFM = sprintf([ ...
    '$\\mathrm{AFM-like}$\n' ...
    '$\\mathrm{(10^{-%d}\\ %s)}$' ], ...
    scalePower, unitStr);

hY1 = ylabel(ylab_AFM,'Interpreter','latex');
set(hY1,'FontSize',cfg.fontsize-2);

set(ax1,'FontSize',cfg.fontsize-2)
set(ax1,'XTick',Tp)
xlim(ax1,[min(Tp)-1 max(Tp)+1])
ylim(ax1,[0 max(max(Y_AFM*scaleFactor),max(Y_FM * scaleFactor))])


% ---------- (b) FM background (FIT-based) ----------
ax2 = subplot(2,1,2); hold(ax2,'on');

ax2.TickDir = 'in';
ax2.Box = 'on';
ax2.Layer = 'top';
ax2.FontName = 'Times New Roman';
ax2.TickLabelInterpreter = 'latex';
ax2.XMinorTick = 'off';
ax2.YMinorTick = 'off';
grid(ax2,'off');

% guide line
plot(Tp, Y_FM * scaleFactor, '-', ...
    'Color',[0.6 0.6 0.6], 'LineWidth',1.2);

% markers
for i = 1:numel(Tp)
    plot(Tp(i), Y_FM(i)*scaleFactor, 'o', ...
    'MarkerSize',9, ...
        'MarkerFaceColor',Tp_colors(i,:), ...
        'MarkerEdgeColor',markerEdgeColor, ...
        'LineWidth',markerEdgeWidth);
end

xlabel('Pause temperature (K)','Interpreter','latex');

ylab_FM = sprintf([ ...
    '$\\mathrm{FM-like}$\n' ...
    '$\\mathrm{(10^{-%d}\\ \\mu_{\\mathrm{B}}/\\mathrm{Co})}$' ], ...
    scalePower);

hY2 = ylabel(ylab_FM,'Interpreter','latex');
set(hY2,'FontSize',cfg.fontsize-2);

set(ax2,'FontSize',cfg.fontsize-2)
set(ax2,'XTick',Tp)
xlim(ax2,[min(Tp)-1 max(Tp)+1])
ylim(ax2,[0 max(max(Y_AFM*scaleFactor),max(Y_FM * scaleFactor))])


set(ax1,'XTickLabel',[])

pos1 = ax1.Position;
pos2 = ax2.Position;

newHeight = 0.38;

ax1.Position = [pos1(1), 0.58, pos1(3), newHeight];
ax2.Position = [pos2(1), 0.08, pos2(3), newHeight];


linkaxes(findall(gcf,'Type','axes'),'x');

end
