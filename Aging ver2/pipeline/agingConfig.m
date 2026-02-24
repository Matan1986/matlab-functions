function cfg = agingConfig(datasetName)
% =========================================================
% agingConfig — Centralized configuration for aging-memory analysis pipeline
% =========================================================

if nargin < 1
    datasetName = 'MG119_60min';   % default
end

cfg.current_mA = 35;   % Allowed values: 15 or 35
cfg.datasetName = datasetName;   % 'MG119_60min' | 'MG119_6min' | 'MG119_36sec'

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
cfg.agingMetricMode = 'model';
cfg.switchingMetricMode = 'direct';

cfg.AFM_metric_main = 'area';
cfg.doFit_MF_Gaussian = true;
cfg.normalizeAFM_FM = true;

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
cfg.debug.plotGeometry = true;
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

% --- Paths ---
cfg.baseFolder = 'C:\Dev\matlab-functions';
paths = localPaths();

switch cfg.datasetName

    case 'MG119_60min'
        dataSubDir = join([
            "MG 119 M2 out of plane Aging no field"
            "high res 60min waiting time"
        ], " ");

    case 'MG119_6min'
        dataSubDir = join([
            "MG 119 M2 out of plane Aging no field"
            "high res 6min waiting time"
        ], " ");

    case 'MG119_36sec'
        dataSubDir = join([
            "MG 119 M2 out of plane Aging no field"
            "high res 36sec waiting time"
        ], " ");

    otherwise
        error('Unknown datasetName: %s', cfg.datasetName);
end

cfg.dataDir = fullfile(paths.dataRoot, "MG 119", dataSubDir);

assert(isfolder(cfg.dataDir), 'Dataset folder not found:\n%s', cfg.dataDir);

% --- Switching reconstruction ---

cfg.Tsw = [4 6 8 10 12.01 14 16 18 20 22 24 26 28 30 32 34];

cfg.Rsw_15mA = abs([ ...
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

switch cfg.current_mA
    case 15
        cfg.Rsw = cfg.Rsw_15mA;
    case 35
        cfg.Rsw = cfg.Rsw_35mA;
    otherwise
        error('Unsupported current value.');
end

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

cfg.dipSigmaLowerBound = 0.4;
cfg.dipAreaLowPercentile = 5;

cfg.switchExcludeTp = [34];
cfg.switchExcludeTpAbove = [];

cfg.autoExcludeDegenerateDip = true;

cfg.switchParams.debugSwitching = false;

cfg.switchParams.dipSigmaLowerBound = cfg.dipSigmaLowerBound;
cfg.switchParams.dipAreaLowPercentile = cfg.dipAreaLowPercentile;

end