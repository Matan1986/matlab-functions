function state = Main_Aging(cfg)
%% MAIN_AGING_MEMORY — Spin-glass aging memory analysis (modular pipeline)
% Reads aging-memory .dat files, identifies pause/no-pause runs,
% computes DeltaM(T), and generates analysis + summary plots.
% ============================================================
% MAIN_AGING — Aging + Switching dual-mode analysis pipeline
%
% This pipeline contains TWO independent choices:
%
%   cfg.agingMetricMode     = 'direct' | 'model' | 'fit' | 'derivative' | 'extrema_smoothed'
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

clc; close_all_except_ui_figures;

% =========================================================
% Stage 0: Config + paths
% =========================================================
if ~exist('cfg','var') || ~isstruct(cfg)
    cfg = agingConfig();
end

cfg = applyAgingMode(cfg);

% ========== DEBUG INFRASTRUCTURE INIT ==========
dbgInitDiagnostics(cfg);

dbg(cfg, "summary", "AGING metric mode: %s", cfg.agingMetricMode);
dbg(cfg, "summary", "SWITCHING metric mode: %s", cfg.switchingMetricMode);
dbg(cfg, "summary", "AFM metric type: %s", cfg.AFM_metric_main);
dbg(cfg, "summary", "FM metric: plateau step magnitude from ΔM(T)");
dbg(cfg, "summary", "Switch fit window: %.2f–%.2f K", cfg.switchParams.fitTmin, cfg.switchParams.fitTmax);
dbg(cfg, "full", "Debug level: %s | Plots: %s | Max figures: %d", ...
    cfg.debug.level, cfg.debug.plots, cfg.debug.maxFigures);

cfg = stage0_setupPaths(cfg);
% =========================================================
% Stage 1: Load files
% =========================================================
if ~isfield(cfg,'dataDir') || isempty(cfg.dataDir)
    error('cfg.dataDir must be provided externally.');
end

if ~isfield(cfg,'outputFolder') || isempty(cfg.outputFolder)
    if isfield(cfg,'run') && isstruct(cfg.run) && isfield(cfg.run,'run_dir') && ~isempty(cfg.run.run_dir)
        cfg.outputFolder = cfg.run.run_dir;
    else
        cfg.outputFolder = fullfile(cfg.dataDir, 'Results');
    end
end

dbg(cfg, "summary", "Loading data from: %s", cfg.dataDir);
state = stage1_loadData(cfg);
dbg(cfg, "summary", "Loaded %d pause runs + 1 no-pause reference", numel(state.pauseRuns));

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

dbg(cfg, "full", "switchExcludeTp config: %s", mat2str(cfg.switchParams.switchExcludeTp));

% =========================================================
% Stage 7: Switching reconstruction
% =========================================================
result = struct();
if isfield(cfg, 'enableStage7') && cfg.enableStage7
    [result, state] = stage7_reconstructSwitching(state, cfg);
end

% ========== EXTRACT PHYSICS CONTEXT ==========
% Build comprehensive metadata for physicists
physicsContext = dbgExtractPhysicsContext(cfg, result, state);

% =========================================================
% Stage 8: Plotting
% =========================================================
if isfield(cfg,'doPlotting') && cfg.doPlotting
    stage8_plotting(state, cfg, result);
end
% =========================================================
% Stage 9: Export
% =========================================================
stage9_export(state, cfg);

% ========== DIAGNOSTIC SUMMARY ==========
dbg(cfg, "summary", "Pipeline completed successfully");

% Save detailed physics context
dbgSummaryPhysics(cfg, physicsContext, result, state);

% Compile metrics summary
nPause = numel(state.pauseRuns);
nFigs = length(findobj('Type', 'figure'));
corr_R_A = NaN;
corr_R_B = NaN;
corr_R_dAdT = NaN;
corr_R_dBdT = NaN;
partialcorr_R_A_given_T = NaN;
partialcorr_R_B_given_T = NaN;
if isfield(result, 'corr_R_A')
    corr_R_A = result.corr_R_A;
end
if isfield(result, 'corr_R_B')
    corr_R_B = result.corr_R_B;
end
if isfield(result, 'corr_R_dAdT')
    corr_R_dAdT = result.corr_R_dAdT;
end
if isfield(result, 'corr_R_dBdT')
    corr_R_dBdT = result.corr_R_dBdT;
end
if isfield(result, 'partialcorr_R_A_given_T')
    partialcorr_R_A_given_T = result.partialcorr_R_A_given_T;
end
if isfield(result, 'partialcorr_R_B_given_T')
    partialcorr_R_B_given_T = result.partialcorr_R_B_given_T;
end

% Build comprehensive summary with physics context
dbgSummaryTable(cfg, ...
    '=== SAMPLE & DATASET ===', '', ...
    'sample_name', physicsContext.sample_name, ...
    'dataset_name', physicsContext.dataset_name, ...
    '', '', ...
    '=== EXPERIMENTAL SETUP ===', '', ...
    'reference_current_mA', physicsContext.reference_current_mA, ...
    'available_currents_mA', mat2str(physicsContext.available_currents_mA), ...
    'n_pause_runs', physicsContext.n_pause_runs, ...
    '', '', ...
    '=== TEMPERATURE GRID ===', '', ...
    'temperature_min_K', physicsContext.temperature_min_K, ...
    'temperature_max_K', physicsContext.temperature_max_K, ...
    'temperature_range_K', physicsContext.temperature_range_K, ...
    'n_temperature_points', physicsContext.n_temperature_points, ...
    'fit_window_min_K', physicsContext.fit_window_min_K, ...
    'fit_window_max_K', physicsContext.fit_window_max_K, ...
    '', '', ...
    '=== RECONSTRUCTION RESULTS ===', '', ...
    'reconstruction_mode', physicsContext.reconstruction_mode, ...
    'coexistence_parameter_lambda', physicsContext.coexistence_parameter_lambda, ...
    'reconstruction_coeff_a', physicsContext.reconstruction_coeff_a, ...
    'reconstruction_coeff_b', physicsContext.reconstruction_coeff_b, ...
    'fit_quality_R2', physicsContext.fit_quality_R2, ...
    '', '', ...
    '=== CHANNEL CORRELATIONS ===', '', ...
    'corr(R,A)', corr_R_A, ...
    'corr(R,B)', corr_R_B, ...
    'corr(R,|dA/dT|)', corr_R_dAdT, ...
    'corr(R,|dB/dT|)', corr_R_dBdT, ...
    'partialcorr(R,A|T)', partialcorr_R_A_given_T, ...
    'partialcorr(R,B|T)', partialcorr_R_B_given_T, ...
    '', '', ...
    '=== PIPELINE EXECUTION ===', '', ...
    'pause_runs', nPause, ...
    'figures_created', nFigs, ...
    'output_folder', cfg.outputFolder);

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
end

function cfg = applyAgingMode(cfg)
if ~isfield(cfg, 'mode') || isempty(cfg.mode)
    cfg.mode = 'default';
end

mode = lower(string(cfg.mode));

switch mode
    case "basic_plots"
        % Practical plotting preset: keep only observable-level basic Aging
        % figures and suppress diagnostic/decomposition/robustness plots.
        cfg.doPlotting = true;
        cfg.enableStage7 = false;
        cfg.RobustnessCheck = false;

        if ~isfield(cfg, 'debug') || ~isstruct(cfg.debug)
            cfg.debug = struct();
        end
        cfg.debug.enable = false;
        cfg.debug.plotGeometry = false;
        cfg.debug.plots = "key";
        cfg.debug.keyPlotTags = ["DeltaM_overview"];

        % Stage 6 summary figure is the basic AFM-like / FM-like observable.
        cfg.disableStage6Diagnostics = true;

        % Single-run decomposition figures are diagnostic, not basic.
        cfg.showAFM_FM_example = false;

        % Hide the stage-9 table figure in basic plotting mode.
        cfg.showStage9SummaryTable = false;

    otherwise
        % Keep the existing pipeline behavior for all non-basic modes.
end
end

