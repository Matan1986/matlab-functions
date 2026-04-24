function state = stage5_fitFMGaussian(state, cfg)
% ============================================================
% AGING MODULE - CLARITY HEADER
%
% ROLE:
% Stage5 fit layer that transfers tanh+Gaussian fit outputs into pauseRuns.
%
% DECOMPOSITION TYPE:
% FIT
%
% STAGE:
% stage5
%
% DOES:
% - call fitFMstep_plus_GaussianDip on pauseRuns_raw
% - persist fit parameters and fit-derived FM/AFM metrics
% - select Dip_area_selected source for downstream summary usage
%
% DOES NOT:
% - compute stage4 direct smooth/residual decomposition
% - draw final stage6 summary figure
%
% AFFECTS SUMMARY OBSERVABLES:
% YES
%
% NOTES:
% This file is part of a multi-decomposition system.
% It does not define the canonical observable by itself unless stated.
% ============================================================
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

% [FIT_DECOMPOSITION]
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
% Dip_area_selected is the explicit alias for the value stage6 uses in the
% summary observables. Dip_area is retained for backward compatibility.
% NOTE: Dip_area is an overloaded legacy field. Use Dip_area_selected and
% Dip_area_selected_source for explicit provenance.
if isfield(cfg, 'dipAreaSource') && ~isempty(cfg.dipAreaSource)
    dipAreaSource = lower(string(cfg.dipAreaSource));
else
    dipAreaSource = "legacy_fit";
end

for i = 1:numel(state.pauseRuns)
    % [FIT_DECOMPOSITION]
    state.pauseRuns(i).Dip_area_fit = ...
        state.pauseRuns(i).Dip_A * sqrt(2*pi) * state.pauseRuns(i).Dip_sigma;

    if ~isfield(state.pauseRuns(i), 'Dip_area_direct') || isempty(state.pauseRuns(i).Dip_area_direct)
        state.pauseRuns(i).Dip_area_direct = NaN;
    end

    switch dipAreaSource
        case "direct"
            selectedDipArea = state.pauseRuns(i).Dip_area_direct;
            selectedDipAreaSource = 'Dip_area_direct';
        case "mode"
            if isfield(cfg, 'switchingMetricMode') && strcmpi(cfg.switchingMetricMode, 'direct')
                selectedDipArea = state.pauseRuns(i).Dip_area_direct;
                selectedDipAreaSource = 'Dip_area_direct';
            else
                selectedDipArea = state.pauseRuns(i).Dip_area_fit;
                selectedDipAreaSource = 'Dip_area_fit';
            end
        otherwise
            selectedDipArea = state.pauseRuns(i).Dip_area_fit;
            selectedDipAreaSource = 'Dip_area_fit';
    end

    if ~isfinite(selectedDipArea)
        selectedDipArea = state.pauseRuns(i).Dip_area_fit;
        selectedDipAreaSource = 'Dip_area_fit';
    end

    state.pauseRuns(i).Dip_area_selected = selectedDipArea;
    state.pauseRuns(i).Dip_area_selected_source = selectedDipAreaSource;
    state.pauseRuns(i).Dip_area = selectedDipArea;
end

state.pauseRuns_fit = pauseRuns_fit;

end

