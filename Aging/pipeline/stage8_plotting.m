function stage8_plotting(state, cfg, result)
% =========================================================
% stage8_plotting
%
% PURPOSE:
%   Generate switching reconstruction plots and aging memory figures.
%   Uses controlled debug figure system for memory efficiency.
%
% INPUTS:
%   state  - struct with analysis data
%   cfg    - configuration struct
%   result - reconstruction output struct
%
% OUTPUTS:
%   none (creates figures via dbgFigure)
%
% Physics meaning:
%   AFM = low-manifold basis in switching model
%   FM  = high-manifold basis in switching model
%
% DEBUG INFRASTRUCTURE:
%   - Uses dbgFigure() for controlled figure creation
%   - Uses dbg() for logging key results
%   - Uses dbgSaveFig() for automatic diagnostic saves
%
% =========================================================

Tsw = cfg.Tsw;
Rsw = cfg.Rsw;
params = cfg.switchParams;

% Log key fit results
dbg(cfg, "summary", "Reconstruction fit results:");
dbg(cfg, "summary", "  λ = %.3f", result.lambda);
dbg(cfg, "summary", "  a = %.3f", result.a);
dbg(cfg, "summary", "  b = %.3f", result.b);
dbg(cfg, "summary", "  R² = %.3f", result.R2);

maskPlot = (Tsw >= params.fitTmin) & (Tsw <= params.fitTmax);

%% --- Figure 1: Switching amplitude reconstruction ---
h1 = dbgFigure(cfg, "Rsw_vs_T");
if ~isempty(h1)
    figure(h1); clf;
    plot(Tsw(maskPlot), Rsw(maskPlot), 'ko','LineWidth',2); hold on;
    plot(Tsw(maskPlot), result.Rhat(maskPlot), 'r-','LineWidth',2);
    legend('Measured','Reconstructed');
    xlabel('T (K)');
    ylabel('\DeltaR');
    title('Switching Amplitude Reconstruction');
    grid on;
    dbgSaveFig(cfg, h1, 'Rsw_vs_T.png');
end

A = result.A_basis(:);
B = result.B_basis(:);

mask = (Tsw >= params.fitTmin) & (Tsw <= params.fitTmax);

%% --- Figure 2: Basis function decomposition ---
h2 = dbgFigure(cfg, "AFM_FM_channels");
if ~isempty(h2)
    figure(h2); clf; hold on;

    % plot mask (visual only)
    maskPlot = (Tsw >= params.fitTmin) & (Tsw <= params.fitTmax);

    % normalized switching
    Rsw_norm = Rsw(maskPlot) / max(Rsw(maskPlot));

    plot(Tsw(maskPlot), Rsw_norm, 'k','LineWidth',3);
    plot(Tsw(maskPlot), A(maskPlot), 'b','LineWidth',2);
    plot(Tsw(maskPlot), B(maskPlot), 'g','LineWidth',2);
    plot(Tsw(maskPlot), A(maskPlot).*(1-A(maskPlot)), 'm','LineWidth',2);

    imb = abs(A - B);
    imb_norm = imb / max(imb(maskPlot));

    plot(Tsw(maskPlot), 1 - imb_norm(maskPlot), 'c','LineWidth',2);

    legend('Rsw (normalized)','AFM (A)','FM (B)','Overlap A(1-A)','Coexistence 1-|A-B|');
    grid on;
    xlabel('T (K)');
    ylabel('Amplitude (normalized)');
    title('Basis Function Decomposition');
    dbgSaveFig(cfg, h2, 'AFM_FM_channels.png');
end

%% --- Figure 3: Aging memory summary ---
h3 = dbgFigure(cfg, "DeltaM_overview");
if ~isempty(h3)
    figure(h3); clf;
    plotAgingMemory(state.noPause_T, state.noPause_M, state.pauseRuns, cfg.color_scheme, ...
        cfg.fontsize, cfg.linewidth, cfg.sample_name, cfg.Bohar_units, ...
        cfg.offsetMode, cfg.offsetValue, cfg.dip_window_K, cfg.colorRange, cfg.useAutoYScale);
    dbgSaveFig(cfg, h3, 'DeltaM_overview.png');
end

dbg(cfg, "summary", "Plotting complete (figures created: %d)", length(findobj('Type', 'figure')));

end
