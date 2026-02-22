function stage8_plotting(state, cfg, result)
% =========================================================
% stage8_plotting
%
% PURPOSE:
%   Generate switching reconstruction plots and aging memory figures.
%
% INPUTS:
%   state  - struct with analysis data
%   cfg    - configuration struct
%   result - reconstruction output struct
%
% OUTPUTS:
%   none (creates figures)
%
% Physics meaning:
%   AFM = low-manifold basis in switching model
%   FM  = high-manifold basis in switching model
%
% =========================================================

Tsw = cfg.Tsw;
Rsw = cfg.Rsw;
params = cfg.switchParams;

fprintf('\nλ = %.3f\n', result.lambda);
fprintf('a = %.3f\n', result.a);
fprintf('b = %.3f\n', result.b);
fprintf('R² = %.3f\n', result.R2);

maskPlot = (Tsw >= params.fitTmin) & (Tsw <= params.fitTmax);

figure;
plot(Tsw(maskPlot), Rsw(maskPlot), 'ko','LineWidth',2); hold on;
plot(Tsw(maskPlot), result.Rhat(maskPlot), 'r-','LineWidth',2);
legend('Measured','Reconstructed');
xlabel('T (K)');
ylabel('\DeltaR');

A = result.D_basis(:);
B = result.F_basis(:);

mask = (Tsw >= params.fitTmin) & (Tsw <= params.fitTmax);

figure; hold on;

% ---- plot mask (visual only) ----
maskPlot = (Tsw >= params.fitTmin) & (Tsw <= params.fitTmax);

% ---- normalized switching ----
Rsw_norm = Rsw(maskPlot) / max(Rsw(maskPlot));

plot(Tsw(maskPlot), Rsw_norm, 'k','LineWidth',3);

plot(Tsw(maskPlot), A(maskPlot), 'b','LineWidth',2);
plot(Tsw(maskPlot), B(maskPlot), 'g','LineWidth',2);

plot(Tsw(maskPlot), A(maskPlot).*(1-A(maskPlot)), 'm','LineWidth',2);

imb = abs(A - B);
imb_norm = imb / max(imb(maskPlot));

plot(Tsw(maskPlot), 1 - imb_norm(maskPlot), 'c','LineWidth',2);

legend('Rsw','A','B','A(1-A)','Coexistence: 1-|A-B|');
grid on;

% --- Step 5: Plot results (with optional offset) ---
plotAgingMemory(state.noPause_T, state.noPause_M, state.pauseRuns, cfg.color_scheme, ...
    cfg.fontsize, cfg.linewidth, cfg.sample_name, cfg.Bohar_units, ...
    cfg.offsetMode, cfg.offsetValue, cfg.dip_window_K, cfg.colorRange, cfg.useAutoYScale);

end
