function cfg = agingConfig()
% =========================================================
% agingConfig
%
% PURPOSE:
%   Centralized configuration for aging-memory analysis pipeline.
%
% INPUTS:
%   none
%
% OUTPUTS:
%   cfg - struct of all user parameters and paths
%
% Physics meaning:
%   AFM = dip-related memory metric
%   FM  = background/step-related metric
%
% =========================================================
% ============================================================
% agingConfig — Configuration for Aging + Switching Analysis
%
% This pipeline contains TWO independent analysis choices:
%
% ============================================================
% (1) Aging metric extraction from ΔM(T)
%
% Controls how AFM and FM metrics are extracted from magnetization aging data.
%
% Option A — Direct / physics-first (no fitting):
%
%   cfg.agingMetricMode = 'direct';
%
%   AFM_metric:
%       Computed directly from ΔM(T) dip
%       (height or area, controlled by cfg.AFM_metric_main)
%
%   FM_metric:
%       Computed from plateau difference of smoothed ΔM(T)
%
%   Characteristics:
%       • Model-independent
%       • Robust
%       • Minimal assumptions
%       • Recommended as primary analysis
%
%
% Option B — Model-based:
%
%   cfg.agingMetricMode = 'model';
%
%   ΔM(T) is fitted to:
%       tanh step + Gaussian dip
%
%   AFM_metric:
%       Gaussian dip area
%
%   FM_metric:
%       Plateau step (still extracted from raw ΔM, not from fit)
%
%   Characteristics:
%       • Provides dip width (σ)
%       • Smoother metrics
%       • Model-dependent
%       • Intended mainly for cross-checking
%
%
% ============================================================
% (2) Switching reconstruction on Rsw(T)
%
% Switching reconstruction NEVER operates on ΔM(T).
%
% Instead:
%       AFM_metric(Tp), FM_metric(Tp)
%           ↓ interpolate to Tsw
%       A(T), B(T)
%           ↓ coexistence functional
%       C(T) = 1 - |A(T)-B(T)|
%           ↓ fit
%       Rsw(T) ≈ a*C(T) + b
%
% The switching reconstruction can use metrics obtained from:
%
%   • Direct aging extraction
%   • Model-based aging extraction
%
% controlled by:
%
%   cfg.switchingMetricMode = 'direct' | 'model';
%
%
% ============================================================
% Summary:
%
% Aging domain:
%       ΔM(T) → AFM/FM metrics   (direct OR model)
%
% Transport domain:
%       Rsw(T) reconstructed using those metrics
%
% IMPORTANT:
%       Switching is fitted ONLY to Rsw(T),
%       never to magnetization curves.
%
% ============================================================
%
% Recommended default:
%
%   cfg.agingMetricMode     = 'direct';
%   cfg.switchingMetricMode = 'direct';
%
% Model-based options should be used mainly for consistency checks.
%
% ============================================================
% ---------------- User settings ----------------
cfg.normalizeByMass = true;
cfg.color_scheme = 'thermal';
cfg.fontsize = 24;
cfg.linewidth = 2.2;
cfg.debugMode = false;
cfg.Bohar_units = true;
cfg.useAutoYScale = true;
cfg.RobustnessCheck = false;
cfg.doPlotting = true;   % default

% --- Metric mode selection (explicit) ---
cfg.agingMetricMode = 'direct';      % 'direct' -> AFM/FM from DeltaM(T); 'model' -> AFM from Dip_area, FM from plateau
cfg.switchingMetricMode = 'direct';  % selects metrics used to reconstruct Rsw(T)

% --- MAIN FIGURE summary mode (FIT-based only) ---
cfg.AFM_metric_main = 'area';   % 'height' | 'area'

cfg.doFit_MF_Gaussian = true;

% --- AFM / FM normalization control ---
cfg.normalizeAFM_FM = true;

% --- AFM/FM analysis parameters ---
cfg.dip_window_K = 5;
cfg.smoothWindow_K = 4 * cfg.dip_window_K;

% --- AFM / FM analysis display control ---
cfg.showAFM_FM_example = false;
cfg.showAllPauses_AFmFM = true;
cfg.examplePause_K = [];

% --- FM background reliability control ---
cfg.excludeLowT_FM = true;
cfg.excludeLowT_K = 6;

% --- FM / AFM plateau geometry ---
cfg.FM_plateau_K = 6;
cfg.FM_buffer_K = 6;
cfg.excludeLowT_mode = 'pre';

% --- AFM / FM error bar display control ---
cfg.showAFM_errors = false;

% --- Color control for pause markers (xlines) ---
cfg.colorRange = [0 1];

% --- DeltaM subtraction convention ---
cfg.subtractOrder = 'pauseMinusNo';

% --- DeltaM filtering ---
cfg.doFilterDeltaM = true;
cfg.filterMethod = 'sgolay';
cfg.sgolayOrder = 2;
cfg.sgolayFrame = 15;

% --- DeltaM alignment (visual only) ---
cfg.alignDeltaM = false;
cfg.alignRef = 'lowT';
cfg.alignWindow_K = 2;

% --- Offset controls for DeltaM plots ---
cfg.offsetMode = 'none';
cfg.offsetValue = 120;

% --- Save options ---
cfg.saveTableMode = 'none';
cfg.outputFolder = '';

% --- Diagnostics / debug (pipeline-gated) ---
cfg.debug = struct();
cfg.debug.enable = true;                 % master gate
cfg.debug.saveOutputs = true;             % write files when enabled
cfg.debug.outputRoot = fullfile(cfg.outputFolder,'Debug');
cfg.debug.runTag = '';                    % if empty, auto timestamp
cfg.debug.makeWindowOverlayPlots = true;
cfg.debug.makeRawVsFilteredPlots = true;
cfg.debug.makeSummaryPlots = true;
cfg.debug.plotGeometry = false;
cfg.debug.plotSwitching = false;
cfg.debug.dumpTables = true;
cfg.debug.maxOverlayPauses = Inf;
cfg.debug.selectedTp = [];
cfg.debug.noiseWindowMode = 'highT';      % 'highT' or 'tail'
cfg.debug.noiseWindowHighT = [35 45];
cfg.debug.noiseWindowTailK = 10;
cfg.debug.filterImpactWarnPct = 25;
cfg.debug.overlapWarn = true;
cfg.debug.boundsWarn = true;
cfg.debug.assertNoTpMixing = true;
cfg.debug.logToFile = true;
cfg.debug.overlayShowTc = true;
cfg.debug.Tc = 32.5;  % plotting/reference only
cfg.debug.dipMinMarginFraction = 0.10;  % flag if Tmin closer than 10% of window width to boundary
cfg.debug.plateauMaxSlope = 0.01;       % flag if abs(linear fit slope) exceeds this [units/K]
cfg.debug.interpOvershootPct = 2.0;     % flag if interpolated range exceeds original Tp by >2%

% --- MATLAB paths ---
cfg.baseFolder = 'C:\Dev\matlab-functions';

% --- Switching reconstruction ---
% NOTE: Reconstruction is fitted to Rsw(T), not to DeltaM(T).

cfg.Tsw = [4 6 8 10 12.01 14 16 18 20 22 24 26 28 30 32 34];

cfg.Rsw = abs([ ...
-0.118798584194838
-0.122264267325776
-0.118851761632771
-0.101822896954594
-0.0788304623579251
-0.0593463579408640
-0.0498599138258924
-0.0428929207553538
-0.0415806933904911
-0.0430961878264001
-0.0500748615139096
-0.0693882621296171
-0.0809671274875996
-0.0367692256085554
-0.00532765237477462
-0.000552867428264816]);

cfg.switchParams = struct();
cfg.switchParams.dipWindowK = cfg.dip_window_K;
cfg.switchParams.wideWindowK = 18;
cfg.switchParams.lambdaMin = 0.03;
cfg.switchParams.lambdaMax = 1.2;
cfg.switchParams.nLambda = 100;
cfg.switchParams.fitTmin = 10;
cfg.switchParams.fitTmax = 32;

cfg.switchParams.FM_plateau_K = cfg.FM_plateau_K;
cfg.switchParams.FM_buffer_K = cfg.FM_buffer_K;

% --- Dip degeneracy detection constants ---
cfg.dipSigmaLowerBound = 0.4;       % lower bound that creates degenerate sigma
cfg.dipAreaLowPercentile = 5;       % percentile threshold for tiny dip area

% --- Optional pause-temperature exclusion for switching basis ---
% Useful for diagnostic sensitivity analysis.
% Empty defaults mean no exclusion (current numerical behavior preserved).
cfg.switchExcludeTp = [34];         % Vector of Tp values to exclude (e.g., [2, 4, 8])
cfg.switchExcludeTpAbove = [];      % Exclude all Tp > this threshold (e.g., 6 K)

% --- Automatic exclusion of degenerate Gaussian dips (diagnostic) ---
% If true, automatically exclude Tp where Dip fits are degenerate
% (sigma stuck at lower bound, or dip area extremely small)
cfg.autoExcludeDegenerateDip = false;

% --- Switching reconstruction debug gating ---
cfg.switchParams.debugSwitching = false;  % if true, print/plot switching debug info

% --- Map dip constants to switchParams ---
cfg.switchParams.dipSigmaLowerBound = cfg.dipSigmaLowerBound;
cfg.switchParams.dipAreaLowPercentile = cfg.dipAreaLowPercentile;

end
