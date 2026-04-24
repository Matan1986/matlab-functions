function state = stage6_extractMetrics(state, cfg)
% ============================================================
% AGING MODULE - CLARITY HEADER
%
% ROLE:
% Stage6 summary extraction and plotting of AFM_like/FM_like observables.
%
% DECOMPOSITION TYPE:
% FIT / EXTREMA
%
% STAGE:
% stage6
%
% DOES:
% - select summary observables per pause run
% - persist state.summary.AFM_like and state.summary.FM_like
% - persist explicit summary source labels
%
% DOES NOT:
% - perform stage4 direct smooth/residual decomposition
% - perform stage5 fitting
%
% AFFECTS SUMMARY OBSERVABLES:
% YES
%
% NOTES:
% This file is part of a multi-decomposition system.
% It does not define the canonical observable by itself unless stated.
% ============================================================
% =========================================================
% stage6_extractMetrics
%
% OBSERVABLE CONTRACT (CURRENT DEFAULT):
%
% AFM_like:
%   - defined as Dip_area_selected
%   - currently sourced from Dip_area_fit (Gaussian fit)
%
% FM_like:
%   - defined as FM_E
%   - derived from tanh step fit
%
% IMPORTANT:
%   - These are fit-derived observables.
%   - They are NOT the same as:
%       dip_signed (stage4)
%       FM_signed  (stage4)
%
% PURPOSE:
%   Extract AFM/FM metrics, print diagnostics, and plot summary figures.
%
% This function produces AFM-like and FM-like observables:
%   - one scalar value per pause temperature
%   - used for physical interpretation and summary plots
%
% This is:
%   - the correct 'basic decomposition' figure
%
% This is NOT:
%   - a continuous decomposition of a single run
%
% INPUTS:
%   state - struct with pauseRuns
%   cfg   - configuration struct
%
% OUTPUTS:
%   state - updated data struct with explicit summary observables
%
% Physics meaning:
%   AFM = dip height/area metrics
%   FM  = step/background metrics
%
% =========================================================

agingMode = lower(string(cfg.agingMetricMode));
Tp = [state.pauseRuns.waitK];

if agingMode ~= "extrema_smoothed"
    % [FIT_DECOMPOSITION]
    if isfield(state.pauseRuns, 'Dip_area_selected')
        DipAreaSelected = [state.pauseRuns.Dip_area_selected];
    else
        DipAreaSelected = [state.pauseRuns.Dip_area];
    end

    DipA     = [state.pauseRuns.Dip_A];
    DipSigma = [state.pauseRuns.Dip_sigma];
    FMstepA  = [state.pauseRuns.FM_step_A];

    fprintf('\n=== Dip sigma statistics ===\n');
    fprintf('min sigma = %.2f K\n', min(DipSigma));
    fprintf('max sigma = %.2f K\n', max(DipSigma));
    fprintf('mean sigma = %.2f K\n', mean(DipSigma));
    fprintf('std/mean = %.2f\n', std(DipSigma)/mean(DipSigma));
    % --- extra diagnostics: does sigma add independent info? ---
    R_As = corr(DipA(:), DipSigma(:), 'rows','complete');
    fprintf('corr(Dip_A, Dip_sigma) = %.2f\n', R_As);

    % --- build per-component "strength" metrics (not ratios) ---
    Dip_area_fit_diag = DipA .* sqrt(2*pi) .* DipSigma;   % integrated Gaussian weight

    % normalize for comparison across metrics (z-score)
    Z = @(x) (x - mean(x,'omitnan')) ./ (std(x,'omitnan') + eps);

    Z_FM      = Z(FMstepA);
    Z_DipA    = Z(DipA);
    Z_DipArea = Z(Dip_area_fit_diag);

    % --- quick table (all pauses) ---
    diagTbl = table(Tp(:), FMstepA(:), DipA(:), DipSigma(:), Dip_area_fit_diag(:), ...
        Z_FM(:), Z_DipA(:), Z_DipArea(:), ...
        'VariableNames', {'Tp_K','FM_step_A','Dip_A','Dip_sigma_K','Dip_area','Z_FM','Z_DipA','Z_DipArea'});

    disp(diagTbl);

    % --- show only 5 representative pauses (spread across Tp) ---
    n = numel(Tp);
    idx5 = unique(round(linspace(1,n, min(5,n))));
    disp(diagTbl(idx5,:));

    % --- simple diagnostic plot: which metric separates pauses better? ---
    makeDiagnostics = true;
    if isfield(cfg, 'disableStage6Diagnostics') && logical(cfg.disableStage6Diagnostics)
        makeDiagnostics = false;
    end
    if makeDiagnostics
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
    end

    % --- auto scaling (based on what is actually plotted) ---
    FMvec = [state.pauseRuns.FM_E];   % row vector
    switch cfg.AFM_metric_main
        case 'height'
            AFMvec = [state.pauseRuns.Dip_A];      % row vector
            unitStr = '\\mu_B / Co';

        case 'area'
            AFMvec = DipAreaSelected;              % row vector
            unitStr = '\\mu_B·K / Co';

        otherwise
            error('Unknown AFM_metric_main: %s', cfg.AFM_metric_main);
    end
else
    AFMvec = nan(1, numel(state.pauseRuns));
    FMvec = nan(1, numel(state.pauseRuns));
    for i = 1:numel(state.pauseRuns)
        if isfield(state.pauseRuns(i), 'AFM_extrema_smoothed') && isfinite(state.pauseRuns(i).AFM_extrema_smoothed)
            AFMvec(i) = abs(state.pauseRuns(i).AFM_extrema_smoothed);
        end
        if isfield(state.pauseRuns(i), 'FM_extrema_smoothed') && isfinite(state.pauseRuns(i).FM_extrema_smoothed)
            FMvec(i) = state.pauseRuns(i).FM_extrema_smoothed;
        end
    end
    unitStr = '\\mu_{\\mathrm{B}} / \\mathrm{Co}';
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
% This section defines observable-level quantities.
%
% AFM-like(T_pause):
%   - definition:
%       cfg.AFM_metric_main = 'height' -> Dip_A
%       cfg.AFM_metric_main = 'area'   -> Dip_area_selected
%   - default path in this project:
%       Dip_area_selected = Dip_area_fit
%       Dip_area_fit = Dip_A * sqrt(2*pi) * Dip_sigma
%       because cfg.dipAreaSource = 'legacy_fit' selects the fit-derived
%       Gaussian area from stage5_fitFMGaussian.
%   - interpretation:
%       scalar measure of dip strength per pause temperature.
%
% FM-like(T_pause):
%   - definition:
%       FM_E
%   - exact fit-based metric:
%       FM_E = sqrt(mean((stepWin - mean(stepWin)).^2))
%       where stepWin = Astep * tanh((T - Tp)/w) on the fit window.
%   - interpretation:
%       scalar measure of fitted FM background strength per pause
%       temperature.
%
% IMPORTANT:
%   - These are summary observables: one value per pause run.
%   - They are NOT the same as the continuous decomposition
%       DeltaM(T) = DeltaM_smooth(T) + DeltaM_sharp(T).
%   - If cfg.agingMetricMode = 'extrema_smoothed', this figure switches to
%       AFM_extrema_smoothed and FM_extrema_smoothed instead of fit-based
%       Dip_A / Dip_area / FM_E.
% ===============================
if agingMode == "extrema_smoothed"
    % [EXTREMA_BASED]
    Y_AFM = nan(1, numel(state.pauseRuns));
    Y_FM = nan(1, numel(state.pauseRuns));
    for i = 1:numel(state.pauseRuns)
        if isfield(state.pauseRuns(i), 'AFM_extrema_smoothed') && isfinite(state.pauseRuns(i).AFM_extrema_smoothed)
            Y_AFM(i) = abs(state.pauseRuns(i).AFM_extrema_smoothed);
        end
        if isfield(state.pauseRuns(i), 'FM_extrema_smoothed') && isfinite(state.pauseRuns(i).FM_extrema_smoothed)
            Y_FM(i) = state.pauseRuns(i).FM_extrema_smoothed;
        end
    end
    AFM_source = 'AFM_extrema_smoothed_abs';
    FM_source = 'FM_extrema_smoothed';
    unitStr = '\\mu_{\\mathrm{B}} / \\mathrm{Co}';
else
    % [FIT_DECOMPOSITION]
    switch cfg.AFM_metric_main
        case 'height'
            Y_AFM = [state.pauseRuns.Dip_A];
            AFM_source = 'Dip_A';
            unitStr = '\\mu_B / Co';

        case 'area'
            % "selected" means the summary-stage AFM observable used here.
            Y_AFM = DipAreaSelected;
            if isfield(state.pauseRuns, 'Dip_area_selected_source')
                selectedSources = unique(string({state.pauseRuns.Dip_area_selected_source}));
                selectedSources = selectedSources(selectedSources ~= "");
                if numel(selectedSources) == 1
                    AFM_source = char(selectedSources);
                else
                    AFM_source = 'Dip_area_selected';
                end
            else
                AFM_source = 'Dip_area';
            end
            unitStr = '\\mu_B\\cdot K / Co';

        otherwise
            error('Unknown AFM_metric_main: %s', cfg.AFM_metric_main);
    end

    Y_FM = [state.pauseRuns.FM_E];   % local FM strength (RMS from fit)
    FM_source = 'FM_E';
end

if ~isfield(state, 'summary') || ~isstruct(state.summary)
    state.summary = struct();
end
% SOURCE OF TRUTH:
% In the default path, AFM_like is defined from Tanh step + Gaussian dip
% fit outputs (via Dip_area_selected/Dip_area_fit).
% In the default path, FM_like is defined from the same stage5 fit-based
% decomposition path (via FM_E).
% AFM_like in the default path is NOT derived from the direct
% smooth/residual decomposition.
state.summary.AFM_like = Y_AFM;
state.summary.FM_like  = Y_FM;
state.summary.sources  = struct( ...
    'AFM_source', AFM_source, ...
    'FM_source',  FM_source);

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

if agingMode == "extrema_smoothed"
    ylab_AFM = sprintf([ ...
        '$\\mathrm{AFM-like\\ |\\Delta M|\\ memory\\ signal}$\n' ...
        '$\\mathrm{(10^{-%d}\\ \\mu_{\\mathrm{B}} / \\mathrm{Co})}$' ], ...
        scalePower);
else
    ylab_AFM = sprintf([ ...
        '$\\mathrm{AFM-like}$\n' ...
        '$\\mathrm{(10^{-%d}\\ %s)}$' ], ...
        scalePower, unitStr);
end

hY1 = ylabel(ylab_AFM,'Interpreter','latex');
set(hY1,'FontSize',cfg.fontsize-2);

set(ax1,'FontSize',cfg.fontsize-2)
set(ax1,'XTick',Tp)
tpMin = min(Tp);
tpMax = max(Tp);
tpSpan = max(tpMax - tpMin, eps);
xPad = max(0.5, 0.05 * tpSpan);
xlim(ax1,[tpMin - xPad, tpMax + xPad])

yAll = [Y_AFM(:); Y_FM(:)] * scaleFactor;
yAll = yAll(isfinite(yAll));
if isempty(yAll)
    ylim(ax1, [0 1])
else
    yMin = min(yAll);
    yMax = max(yAll);
    ySpan = max(yMax - yMin, eps);
    yPad = max(0.05 * ySpan, eps);
    ylim(ax1, [yMin - yPad, yMax + yPad])
end


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

if agingMode == "extrema_smoothed"
    ylab_FM = sprintf([ ...
        '$\\mathrm{FM-like\\ \\Delta M\\ memory\\ signal}$\n' ...
        '$\\mathrm{(10^{-%d}\\ \\mu_{\\mathrm{B}} / \\mathrm{Co})}$' ], ...
        scalePower);
else
    ylab_FM = sprintf([ ...
        '$\\mathrm{FM-like}$\n' ...
        '$\\mathrm{(10^{-%d}\\ \\mu_{\\mathrm{B}} / \\mathrm{Co})}$' ], ...
        scalePower);
end

hY2 = ylabel(ylab_FM,'Interpreter','latex');
set(hY2,'FontSize',cfg.fontsize-2);

set(ax2,'FontSize',cfg.fontsize-2)
set(ax2,'XTick',Tp)
xlim(ax2,[tpMin - xPad, tpMax + xPad])
if isempty(yAll)
    ylim(ax2, [0 1])
else
    ylim(ax2, [yMin - yPad, yMax + yPad])
end


set(ax1,'XTickLabel',[])

pos1 = ax1.Position;
pos2 = ax2.Position;

newHeight = 0.38;

ax1.Position = [pos1(1), 0.58, pos1(3), newHeight];
ax2.Position = [pos2(1), 0.08, pos2(3), newHeight];


linkaxes(findall(gcf,'Type','axes'),'x');

end
