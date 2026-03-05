function cfg = agingConfig(datasetName)
% =========================================================
% agingConfig — Centralized configuration for aging-memory analysis pipeline
% =========================================================

if nargin < 1
    datasetName = 'MG119_60min';   % default
end

cfg.current_mA = 25;   % Allowed values: 15 20 25 30 35 45
cfg.datasetName = datasetName;   % 'MG119_60min' | 'MG119_6min' | 'MG119_36sec' | 'MG119_3sec'


cfg.normalizeByMass = true;
cfg.color_scheme = 'thermal';
cfg.fontsize = 24;
cfg.linewidth = 2.2;
cfg.debugMode = true;
cfg.Bohar_units = true;
cfg.useAutoYScale = true;
cfg.RobustnessCheck = false;
cfg.doPlotting = true;

% --- Metric mode selection ---
cfg.agingMetricMode = 'direct';
cfg.switchingMetricMode = 'direct';

cfg.AFM_metric_main = 'area';
cfg.doFit_MF_Gaussian = true;
cfg.normalizeAFM_FM = true;
cfg.allowSignedFM = true;   % default: legacy magnitude-only

% --- FM metric notes ---
% FM metrics (FM_step_mag, FM_step_A, FM_E) can be positive or negative.
% Negative FM indicates inverted ferromagnetism (opposite magnetization step).
% No filtering is applied based on FM sign; all pauses are retained.

cfg.dip_window_K = 5;
cfg.smoothWindow_K = 4 * cfg.dip_window_K;

cfg.showAFM_FM_example = false;
cfg.showAllPauses_AFmFM = true;
cfg.examplePause_K = [];

cfg.excludeLowT_FM = true;
cfg.excludeLowT_K = 6;

cfg.FM_plateau_K = 6;
cfg.FM_buffer_K = 6;
cfg.excludeLowT_mode = 'pre';

% --- FM right plateau window mode ---
cfg.FM_rightPlateauMode = 'fixed';  % 'relative' (Tp-dependent) or 'fixed' (absolute temperature)
cfg.FM_rightPlateauFixedWindow_K = [35 45];  % Used when mode='fixed'

cfg.showAFM_errors = false;
cfg.colorRange = [0 1];

cfg.subtractOrder = 'pauseMinusNo';

cfg.doFilterDeltaM = true;
cfg.filterMethod = 'sgolay';
cfg.sgolayOrder = 2;
cfg.sgolayFrame = 15;

cfg.alignDeltaM = false;
cfg.alignRef = 'lowT';
cfg.alignWindow_K = 2;

cfg.offsetMode = 'none';
cfg.offsetValue = 120;

cfg.saveTableMode = 'none';
cfg.outputFolder = '';

% --- Debug ---
cfg.debug = struct();
cfg.debug.enable = true;
cfg.debug.saveOutputs = true;
cfg.debug.outputRoot = fullfile(cfg.outputFolder,'Debug');
cfg.debug.runTag = '';
cfg.debug.makeWindowOverlayPlots = true;
cfg.debug.makeRawVsFilteredPlots = true;
cfg.debug.makeSummaryPlots = true;
cfg.debug.plotGeometry = false;
cfg.debug.plotSwitching = false;
cfg.debug.dumpTables = true;
cfg.debug.maxOverlayPauses = Inf;
cfg.debug.selectedTp = [];
cfg.debug.noiseWindowMode = 'highT';
cfg.debug.noiseWindowHighT = [35 45];
cfg.debug.noiseWindowTailK = 10;
cfg.debug.filterImpactWarnPct = 25;
cfg.debug.overlapWarn = true;
cfg.debug.boundsWarn = true;
cfg.debug.assertNoTpMixing = true;
cfg.debug.logToFile = true;
cfg.debug.overlayShowTc = true;
cfg.debug.Tc = 32.5;
cfg.debug.dipMinMarginFraction = 0.10;
cfg.debug.plateauMaxSlope = 0.01;
cfg.debug.interpOvershootPct = 2.0;

% ========== STRUCTURED DEBUG INFRASTRUCTURE ==========
% Logging levels: "quiet" < "summary" < "full"
% Controls console output verbosity across all pipeline stages
cfg.debug.level = "summary";           % Default: key milestones only

% Figure management
% cfg.debug.plots: "none" | "key" | "all"
%   "none"  - No figures created
%   "key"   - Only create figures with tags in keyPlotTags
%   "all"   - Create all figures (legacy behavior)
cfg.debug.plots = "key";               % Default: key plots only

% List of approved plot tags when plots="key"
cfg.debug.keyPlotTags = [
    "DeltaM_overview"
    "AFM_FM_channels"
    "Rsw_vs_T"
    "global_J_fit"
    "reconstruction_fit"
    "aging_memory_summary"
];

% Figure visibility
% "on"  - Visible (normal)
% "off" - Hidden (saves memory, faster renders)
cfg.debug.plotVisible = "off";         % Default: hidden

% Maximum number of figures allowed open simultaneously
cfg.debug.maxFigures = 8;              % Default: 8 figures max

% Log file configuration
cfg.debug.logFile = '';                % Full path to log file (empty = no logging)
if ~isempty(cfg.outputFolder) && ~strcmp(cfg.outputFolder, '')
    cfg.debug.logFile = fullfile(cfg.outputFolder, 'diagnostic_log.txt');
end

% Use timestamped subdirectories for diagnostics
cfg.debug.useTimestamp = false;        % Default: false

% --- Paths ---
cfg.baseFolder = 'C:\Dev\matlab-functions';
paths = localPaths();

switch cfg.datasetName

    case 'MG119_60min'
        dataSubDir = join([
            "MG 119 M2 out of plane Aging no field"
            "high res 60min wait"
        ], " ");

    case 'MG119_6min'
        dataSubDir = join([
            "MG 119 M2 out of plane Aging no field"
            "high res 6min wait"
        ], " ");

    case 'MG119_36sec'
        dataSubDir = join([
            "MG 119 M2 out of plane Aging no field"
            "high res 36sec wait"
        ], " ");
    case 'MG119_3sec'
        dataSubDir = join([
            "MG 119 M2 out of plane Aging no field"
            "high res 3sec wait"
        ], " ");

    otherwise
        error('Unknown datasetName: %s', cfg.datasetName);
end

cfg.dataDir = fullfile(paths.dataRoot, "MG 119", dataSubDir);

assert(isfolder(cfg.dataDir), 'Dataset folder not found:\n%s', cfg.dataDir);

% --- Switching reconstruction ---

cfg.Tsw = [4 6 8 10 12.01 14 16 18 20 22 24 26 28 30 32 34];

cfg.Rsw_15mA = abs([ ...
-0.00102482798526087
 0.00109505184024555
-0.000886438334058970
-0.00104591276544765
 0.00136401709134106
 0.00197270507808167
-0.000870269837691975
 0.000797918298212283
-0.00113635765387369
 0.00103022396948144
 0.00116144364495105
-0.00445611187349242
-0.0149324104653412
-0.0380258836809851
-0.0695147785421419
 0.000824341354299825]);

cfg.Rsw_20mA = abs([ ...
-0.00582259023505392
-0.00785063819744449
-0.00543285750734171
-0.00645648701111463
-0.00486960928498080
-0.00507517839334559
-0.00677175776209974
-0.00776684687723585
-0.0101746080318297
-0.0131743942271184
-0.0171713301503286
-0.0247766959738057
-0.0428984469542497
-0.0879097809338481
-0.0207730272894197
 0.000736227972478355]);

cfg.Rsw_25mA = abs([ ...
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

cfg.Rsw_30mA = abs([ ...
-0.249053456384229
-0.250488593439895
-0.234449499272200
-0.200197314257807
-0.159277162134620
-0.124701192359837
-0.0993986539539130
-0.0864861551912553
-0.0814300845096031
-0.0848252860423066
-0.0930645821294685
-0.0732255508855988
-0.0391669784936588
-0.0176356531647830
-0.00139694898968291
-0.00111194952316543]);

cfg.Rsw_35mA = abs([ ...
-0.349600045040287
-0.341950817738385
-0.311011499245369
-0.265625424732821
-0.232986037937288
-0.192544819951381
-0.162443432649134
-0.142095227831458
-0.118297407736058
-0.0832202553642621
-0.0545631856614726
-0.0318709361078693
-0.0178054852417963
-0.00549571126459982
 0.00186991866339437
 0.00101911609498144]);

cfg.Rsw_45mA = abs([ ...
-0.268847171789871
-0.245378963400438
-0.186793639532574
-0.139139102538978
-0.114718911205828
-0.0895613962903788
-0.0671479744387739
-0.0504803947542886
-0.0370235881771524
-0.0257405408686804
-0.0136447566131659
-0.00705464583447693
-0.00233366033585276
-0.00216294491394753
-0.00268570513399984
 0.00166926065760789]);

switch cfg.current_mA
    case 15
        cfg.Rsw = cfg.Rsw_15mA;

    case 20
        cfg.Rsw = cfg.Rsw_20mA;

    case 25
        cfg.Rsw = cfg.Rsw_25mA;

    case 30
        cfg.Rsw = cfg.Rsw_30mA;

    case 35
        cfg.Rsw = cfg.Rsw_35mA;

    case 45
        cfg.Rsw = cfg.Rsw_45mA;

    otherwise
        error('Unsupported current value.');
end

cfg.switchParams = struct();
cfg.switchParams.available_currents_mA = [15 20 25 30 35 45];
cfg.switchParams.reference_current_mA = cfg.current_mA;
cfg.switchParams.dipWindowK = cfg.dip_window_K;
cfg.switchParams.wideWindowK = 18;
cfg.switchParams.lambdaMin = 0.03;
cfg.switchParams.lambdaMax = 1.2;
cfg.switchParams.nLambda = 100;
cfg.switchParams.fitTmin = 10;
cfg.switchParams.fitTmax = 32;
cfg.switchParams.FM_plateau_K = cfg.FM_plateau_K;
cfg.switchParams.FM_buffer_K = cfg.FM_buffer_K;
cfg.switchParams.allowSignedFM = isfield(cfg, 'allowSignedFM') && cfg.allowSignedFM;

cfg.dipSigmaLowerBound = 0.4;
cfg.dipAreaLowPercentile = 5;

cfg.switchExcludeTp = [34];
cfg.switchExcludeTpAbove = [];

cfg.autoExcludeDegenerateDip = true;

cfg.switchParams.debugSwitching = false;

cfg.switchParams.dipSigmaLowerBound = cfg.dipSigmaLowerBound;
cfg.switchParams.dipAreaLowPercentile = cfg.dipAreaLowPercentile;

end