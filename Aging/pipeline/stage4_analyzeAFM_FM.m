function state = stage4_analyzeAFM_FM(state, cfg)
% =========================================================
% stage4_analyzeAFM_FM
%
% PURPOSE:
%   Orchestrate AFM/FM decomposition from DeltaM.
%   Delegates computation to specialized analysis functions.
%
% INPUTS:
%   state - struct with pauseRuns
%   cfg   - configuration struct
%
% OUTPUTS:
%   state - updated with AFM/FM metrics
%
% Physics meaning:
%   AFM = dip metric (height/area)
%   FM  = background step metric
%
% =========================================================

% ====================== Core Analysis ======================
% Compute AFM/FM decomposition (models/analyzeAFM_FM_components.m)
state.pauseRuns = analyzeAFM_FM_components( ...
    state.pauseRuns, cfg.dip_window_K, cfg.smoothWindow_K, ...
    cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
    cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
    cfg.AFM_metric_main, cfg);

% ====================== Debug Diagnostics (Optional) ======================
if isfield(cfg, 'debug') && isfield(cfg.debug, 'enable') && cfg.debug.enable
    state = debugAgingStage4(state, cfg);
end

% ====================== Debug Geometry Plots (Optional) ======================
if isfield(cfg, 'doPlotting') && cfg.doPlotting && ...
        isfield(cfg, 'debug') && isfield(cfg.debug, 'plotGeometry') && cfg.debug.plotGeometry && ...
        usejava('desktop')
    debugPlotGeometry(state, cfg);
end

% ====================== Robustness Check (Optional) ======================
if isfield(cfg, 'RobustnessCheck') && cfg.RobustnessCheck
    runRobustnessCheck(state, cfg);
end

% ====================== Example Decomposition Plots (Optional) ======================
if isfield(cfg, 'showAFM_FM_example') && cfg.showAFM_FM_example
    plotDecompositionExamples(state, cfg);
end

end
