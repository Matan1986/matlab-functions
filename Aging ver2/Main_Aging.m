%% MAIN_AGING_MEMORY — Spin-glass aging memory analysis (modular pipeline)
% Reads aging-memory .dat files, identifies pause/no-pause runs,
% computes DeltaM(T), and generates analysis + summary plots.
% ============================================================
% MAIN_AGING — Aging + Switching dual-mode analysis pipeline
%
% This pipeline contains TWO independent choices:
%
%   cfg.agingMetricMode     = 'direct' | 'model'
%   cfg.switchingMetricMode = 'direct' | 'model'
%
% ------------------------------------------------------------
% (1) Aging metric extraction from ΔM(T)
%     (controlled by cfg.agingMetricMode)
%
%   'direct' → AFM/FM extracted directly from ΔM(T)
%              (dip height/area and plateau step)
%
%   'model'  → AFM from Gaussian dip fit (Dip_area)
%              FM still from plateau step (raw ΔM)
%
% ------------------------------------------------------------
% (2) Switching reconstruction on Rsw(T)
%     (controlled by cfg.switchingMetricMode)
%
%   'direct' → reconstruct Rsw(T) using direct AFM/FM metrics (from ΔM)
%   'model'  → reconstruct Rsw(T) using fit-derived AFM (Dip_area) + plateau FM
%
% NOTE:
%   Switching reconstruction is fitted ONLY to Rsw(T), never to ΔM(T).
% ============================================================

clc; clear; close_all_except_ui_figures;

% =========================================================
% Stage 0: Config + paths
% =========================================================
cfg = agingConfig();
fprintf('AGING metric mode: %s\n', cfg.agingMetricMode);
fprintf('SWITCHING metric mode: %s\n', cfg.switchingMetricMode);
fprintf('AFM metric type: %s\n', cfg.AFM_metric_main);
fprintf('FM metric: plateau step magnitude from ΔM(T)\n');
fprintf('Switch fit window: %.2f–%.2f K\n', cfg.switchParams.fitTmin, cfg.switchParams.fitTmax);
cfg = stage0_setupPaths(cfg);
% =========================================================
% Stage 1: Load files
% =========================================================
state = stage1_loadData(cfg);

% =========================================================
% Stage 2: Preprocess + unit conversion
% =========================================================
state = stage2_preprocess(state, cfg);

% =========================================================
% Stage 3: DeltaM construction
% =========================================================
state = stage3_computeDeltaM(state, cfg);

% =========================================================
% Stage 4: AFM/FM decomposition
% =========================================================
state = stage4_analyzeAFM_FM(state, cfg);

% =========================================================
% Stage 5: FM + Gaussian fitting
% =========================================================
state = stage5_fitFMGaussian(state, cfg);

% =========================================================
% Stage 6: Metric extraction
% =========================================================
state = stage6_extractMetrics(state, cfg);

% =========================================================
% Inject diagnostic Tp exclusions into switching params
% =========================================================
if isfield(cfg,'switchExcludeTp') && ~isempty(cfg.switchExcludeTp)
    cfg.switchParams.switchExcludeTp = cfg.switchExcludeTp(:);
else
    cfg.switchParams.switchExcludeTp = [];
end

if isfield(cfg,'switchExcludeTpAbove') && ~isempty(cfg.switchExcludeTpAbove)
    cfg.switchParams.switchExcludeTpAbove = cfg.switchExcludeTpAbove;
else
    cfg.switchParams.switchExcludeTpAbove = [];
end

if isfield(cfg,'autoExcludeDegenerateDip')
    cfg.switchParams.autoExcludeDegenerateDip = cfg.autoExcludeDegenerateDip;
else
    cfg.switchParams.autoExcludeDegenerateDip = false;
end

% Map dip degeneracy constants
if isfield(cfg,'dipSigmaLowerBound')
    cfg.switchParams.dipSigmaLowerBound = cfg.dipSigmaLowerBound;
else
    cfg.switchParams.dipSigmaLowerBound = 0.4;
end

if isfield(cfg,'dipAreaLowPercentile')
    cfg.switchParams.dipAreaLowPercentile = cfg.dipAreaLowPercentile;
else
    cfg.switchParams.dipAreaLowPercentile = 5;
end

if isfield(cfg,'switchParams') && isfield(cfg.switchParams, 'debugSwitching')
    % debugSwitching already set in config
else
    cfg.switchParams.debugSwitching = false;
end

disp("=== switchExcludeTp debug (after mapping) ===");
disp(cfg.switchParams.switchExcludeTp);

% =========================================================
% Stage 7: Switching reconstruction
% =========================================================
[result, state] = stage7_reconstructSwitching(state, cfg);

% =========================================================
% Stage 8: Plotting
% =========================================================
stage8_plotting(state, cfg, result);

% =========================================================
% Stage 9: Export
% =========================================================
stage9_export(state, cfg);

% =========================================================
% Workspace compatibility (preserve key variables)
% =========================================================
noPause_T = state.noPause_T;
noPause_M = state.noPause_M;
pauseRuns = state.pauseRuns;
pauseRuns_raw = state.pauseRuns_raw;
pauseRuns_fit = state.pauseRuns_fit;

sample_name = cfg.sample_name;
fontsize = cfg.fontsize;
linewidth = cfg.linewidth;
Bohar_units = cfg.Bohar_units;

% expose config for downstream usage
params = cfg.switchParams;
Tsw = cfg.Tsw;
Rsw = cfg.Rsw;

