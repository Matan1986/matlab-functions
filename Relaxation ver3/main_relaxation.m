%% MAIN_RELAXATION — TRM/IRM Relaxation Analysis
clc; clear; close all;

%% ===============================
%% PLOT MODE CONFIGURATION
%% ===============================
plots = struct();
plots.core = true;
plots.diagnostics = false;
plots.debug = false;
%% ============================================================
%               GLOBAL FITTING CONTROL
% ============================================================
fitParams = struct();
fitParams.betaBoost      = false;
fitParams.tauBoost       = false;
fitParams.timeWeight     = true;
fitParams.lowT_only      = false;
fitParams.lowT_threshold = 15;
fitParams.debugFit       = plots.debug;
fitParams.timeWeightFactor = 0.725;    % strength of weighting (you can tune this)

%% ============================================================
%               USER SETTINGS
% ============================================================
Bohar_units       = true;
showFits          = true;
debugMode         = plots.debug;
formatFigures     = true;
color_scheme      = 'parula';
normalizeByMass   = true;
fontsize          = 18;
linewidth         = 2.2;
compareMode       = false;
compareModeLocked = false;    % set true to force manual compareMode choice
alignByDrop       = true;
Hthresh_align     = 0.5;
trimToFitWindow   = true;
fitWindow_extraEnd_percent = 0.00;   % cut the tail
fitWindow_extraStart_percent = 0.00; % cut the initial start
absThreshold = 3e-5;
slopeThreshold = 1e-8;

% Relaxation model selection:
%   'log'     - logarithmic relaxation (default)
%   'kww'     - stretched exponential
%   'compare' - fit both and pick lower AIC
cfg = struct();
cfg.relaxationModel = 'log';  % options: 'log' | 'kww' | 'compare'

% Plotting control:
%   'none'    - no plots
%   'summary' - core plots only (overlay, params, collapse)
%   'full'    - all diagnostics + core plots
cfg.plotLevel = 'summary';  % options: 'none' | 'summary' | 'full'

exportFitTableToExcel      = false;
showInFitTableFigure       = true;
showRelaxationParamPlots   = true;
minR2_for_paramPlots       = 0.97;

%% Display offset (visual only)
offsetDisplayMode  = true;     % if true → curves are vertically offset
offsetValue        = 5E-5;     % vertical separation between curves

%% ============================================================
%        DATA DIRECTORY (SET YOUR PATH)
% ============================================================
dir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";

%% ============================================================
%        ADD PATHS
% ============================================================
baseFolder = 'C:\Dev\matlab-functions';
addpath(genpath(baseFolder));

%% ===============================
%% LOAD DATA
%% ===============================
[fileList, temps, fields, types, colors, mass] = ... %#ok<ASGLU>
    getFileList_relaxation(dir, color_scheme);

% Detect TRM/IRM content from actual files (not folder name)
fileListLower = lower(string(fileList));
containsTRM_data = any(contains(fileListLower, "trm"));
containsIRM_data = any(contains(fileListLower, "irm"));

% Backward-compatibility API note:
% These legacy *_folder flags are now populated from fileList-based detection
% (not from folder-name heuristics), and are kept to avoid signature changes.
containsTRM_folder = containsTRM_data;
containsIRM_folder = containsIRM_data;

% Auto-detect TRM vs IRM compare mode unless explicitly locked by user
if ~compareModeLocked
    compareModeAuto = containsTRM_data && containsIRM_data;
    autoEnabledCompare = ~compareMode && compareModeAuto;
    compareMode = compareModeAuto;
else
    autoEnabledCompare = false;
end

if autoEnabledCompare
    fprintf("\n=== Auto-detected TRM vs IRM comparison ===\n");
end
[Time_table, Temp_table, Field_table, Moment_table, massHeader] = ...
    importFiles_relaxation(dir, fileList, normalizeByMass, debugMode);

if ~isnan(massHeader)
    mass = massHeader; %#ok<NASGU>
end

%% ============================================================
%       BOHR MAGNETON CONVERSION
% ============================================================
if Bohar_units
    x_Co = 1/3;
    m_mol = 58.9332/3 + 180.948 + 2*32.066;
    muB = 9.274e-21;
    NA  = 6.022e23;
    convFactor = m_mol / (NA * muB * x_Co);

    for i = 1:numel(Moment_table)
        Moment_table{i} = Moment_table{i} * convFactor;
    end
end

%% ============================================================
%         SAMPLE NAME
% ============================================================
[growth_num, FIB_num] = extract_growth_FIB(dir, []); %#ok<ASGLU>
sample_name = sprintf('MG %d', growth_num);

%% ===============================
%% PHYSICS PLOTS (RAW CURVES)
%% ===============================
if plots.core
    [Time_table, Moment_table, T_all, F_all] = Plots_relaxation( ... %#ok<NASGU>
        Time_table, Moment_table, temps, fields, Field_table, ...
        color_scheme, normalizeByMass, sample_name, fontsize, Bohar_units, ...
        fileList, alignByDrop, Hthresh_align, debugMode, trimToFitWindow, ...
        compareMode, containsTRM_folder, containsIRM_folder, ...
        offsetDisplayMode, offsetValue);
end

%% ===============================
%% RELAXATION FITTING
%% ===============================
allFits = table();
if showFits
    fprintf("\n--- Performing automatic relaxation fits ---\n");

    allFits = fitAllRelaxations(Time_table, Moment_table, ...
        Temp_table, Field_table, debugMode, Hthresh_align, fitParams, ...
        fitWindow_extraStart_percent, fitWindow_extraEnd_percent, absThreshold, slopeThreshold, fileList, cfg.relaxationModel);

    showRelaxationFitTable(allFits, exportFitTableToExcel, ...
        showInFitTableFigure, dir);
end

%% ===============================
%% PHYSICS PLOTS
%% ===============================
if plots.core && showFits && ~isempty(allFits)
    % Final fit overlay (single canonical implementation)
    overlayRelaxationFits(allFits, Time_table, Moment_table, ...
        color_scheme, fileList, debugMode, trimToFitWindow, ...
        compareMode, sample_name, fields, ...
        containsTRM_folder, containsIRM_folder, ...
        offsetDisplayMode, offsetValue, cfg.plotLevel);

    % Physical parameters
    plotRelaxationParamsVsTemp(allFits, sample_name, minR2_for_paramPlots, cfg.plotLevel);

    % Collapse plot (stretched-exponential scaling)
    plotRelaxationCollapse(allFits, Time_table, Moment_table, sample_name, fileList, cfg.plotLevel);
end

%% ===============================
%% DIAGNOSTICS
%% ===============================
if (plots.diagnostics || plots.debug) && showFits && ~isempty(allFits)
    advCfg = struct();
    advCfg.useMultiStart         = plots.diagnostics;
    advCfg.enableLogModel        = plots.diagnostics;
    advCfg.modelCriterion        = 'AIC';
    advCfg.makePerCurvePlots     = plots.debug;
    advCfg.debugResidualPlot     = plots.debug;
    advCfg.makeSummaryPlot       = plots.diagnostics;
    advCfg.makeCollapsePlot      = false;   % core collapse handled above
    advCfg.makePhysicsPlots      = false;   % core parameter plots handled above
    advCfg.makeResidualDiagnostics = plots.diagnostics;
    advCfg.makeTauDistribution   = false;
    advCfg.advanced              = plots.diagnostics;
    advCfg.debug                 = plots.debug;

    adv = analyzeRelaxationAdvanced(allFits, Time_table, Moment_table, Temp_table, advCfg); %#ok<NASGU>

    if plots.diagnostics && isfield(adv,'results') && ~isempty(adv.results)
        Tdiag = adv.results;
        modelNames = categories(categorical(string(Tdiag.model_choice)));
        modelCounts = zeros(size(modelNames));
        for ii = 1:numel(modelNames)
            modelCounts(ii) = sum(string(Tdiag.model_choice) == string(modelNames(ii)));
        end
        [~,iBest] = min(Tdiag.AIC, [], 'omitnan');
        bestModel = "n/a";
        if ~isempty(iBest) && isfinite(iBest)
            bestModel = string(Tdiag.model_choice(iBest));
        end
        nOk = sum(Tdiag.fit_ok);
        nTauUnresolved = sum(Tdiag.tau_unresolved);

        fprintf('\n=== Diagnostics summary ===\n');
        fprintf('Fits OK: %d/%d\n', nOk, height(Tdiag));
        fprintf('Tau unresolved: %d\n', nTauUnresolved);
        fprintf('Best (global min AIC) model: %s\n', bestModel);
        fprintf('Model choices: ');
        for ii = 1:numel(modelNames)
            fprintf('%s=%d', modelNames{ii}, modelCounts(ii));
            if ii < numel(modelNames), fprintf(', '); end
        end
        fprintf('\n\n');
    end

    if plots.diagnostics && exist('plotArrhenius','file')
        plotArrhenius(allFits, sample_name);
    end
end

%% ===============================
%% FINAL FORMATTING
%% ===============================
%{
if formatFigures && exist('formatAllFigures','file')
    formatAllFigures('pos',[0.1,0.1,0.75,0.7], ...
        'clearTitles',false,'showLegend',true,'showGrid',true);
end
%}
