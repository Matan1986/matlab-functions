function state = stage5_fitFMGaussian(state, cfg)
% =========================================================
% stage5_fitFMGaussian
%
% PURPOSE:
%   Fit FM step + Gaussian dip model and store fit metrics.
%
% INPUTS:
%   state - struct with pauseRuns and pauseRuns_raw
%   cfg   - configuration struct
%
% OUTPUTS:
%   state - updated pauseRuns with fit results
%
% Physics meaning:
%   AFM = Gaussian dip parameters
%   FM  = step-like background parameters
%
% =========================================================

% --- Step 4c: MF(FM) + Gaussian(dip) fitting ---
% Provides Dip_area for cfg.agingMetricMode = 'model'.
fitOpts = struct();
fitOpts.windowFactor = 4;
fitOpts.minWindow_K  = 25;
fitOpts.debugPlots   = false; %%%%%%%%%%%%%%%%%%%% Debub plots

pauseRuns_fit = fitFMstep_plus_GaussianDip( ...
    state.pauseRuns_raw, cfg.dip_window_K, fitOpts);

for i = 1:numel(state.pauseRuns)
    state.pauseRuns(i).FM_step_A     = pauseRuns_fit(i).FM_step_A;
    state.pauseRuns(i).Dip_A         = pauseRuns_fit(i).Dip_A;
    state.pauseRuns(i).Dip_sigma    = pauseRuns_fit(i).Dip_sigma;
    state.pauseRuns(i).Dip_T0       = pauseRuns_fit(i).Dip_T0;
    state.pauseRuns(i).fit_R2        = pauseRuns_fit(i).fit_R2;
    state.pauseRuns(i).fit_RMSE      = pauseRuns_fit(i).fit_RMSE;
    state.pauseRuns(i).fit_NRMSE     = pauseRuns_fit(i).fit_NRMSE;
    state.pauseRuns(i).fit_chi2_red  = pauseRuns_fit(i).fit_chi2_red;
    state.pauseRuns(i).fit_curve     = pauseRuns_fit(i).fit_curve;
    state.pauseRuns(i).FM_E = pauseRuns_fit(i).FM_E;
    state.pauseRuns(i).FM_area_abs = pauseRuns_fit(i).FM_area_abs;
end

% --- derived memory strength (integrated dip weight) ---
for i = 1:numel(state.pauseRuns)
    state.pauseRuns(i).Dip_area = ...
        state.pauseRuns(i).Dip_A * sqrt(2*pi) * state.pauseRuns(i).Dip_sigma;
end

state.pauseRuns_fit = pauseRuns_fit;

end
