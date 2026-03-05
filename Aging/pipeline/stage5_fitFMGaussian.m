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

% --- Dip area semantics (single assignment point) ---
% Keep legacy default output: Dip_area follows fit-derived area unless configured otherwise.
if isfield(cfg, 'dipAreaSource') && ~isempty(cfg.dipAreaSource)
    dipAreaSource = lower(string(cfg.dipAreaSource));
else
    dipAreaSource = "legacy_fit";
end

for i = 1:numel(state.pauseRuns)
    state.pauseRuns(i).Dip_area_fit = ...
        state.pauseRuns(i).Dip_A * sqrt(2*pi) * state.pauseRuns(i).Dip_sigma;

    if ~isfield(state.pauseRuns(i), 'Dip_area_direct') || isempty(state.pauseRuns(i).Dip_area_direct)
        state.pauseRuns(i).Dip_area_direct = NaN;
    end

    switch dipAreaSource
        case "direct"
            selectedDipArea = state.pauseRuns(i).Dip_area_direct;
        case "mode"
            if isfield(cfg, 'switchingMetricMode') && strcmpi(cfg.switchingMetricMode, 'direct')
                selectedDipArea = state.pauseRuns(i).Dip_area_direct;
            else
                selectedDipArea = state.pauseRuns(i).Dip_area_fit;
            end
        otherwise
            selectedDipArea = state.pauseRuns(i).Dip_area_fit;
    end

    if ~isfinite(selectedDipArea)
        selectedDipArea = state.pauseRuns(i).Dip_area_fit;
    end

    state.pauseRuns(i).Dip_area = selectedDipArea;
end

state.pauseRuns_fit = pauseRuns_fit;

end

