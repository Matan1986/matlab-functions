<<<<<<< HEAD
<<<<<<<< HEAD:Relaxation ver3/main_relaxation.m
%% MAIN_RELAXATION — TRM/IRM Relaxation Analysis
clc; clear; close all;

=======
%% MAIN_RELAXATION — TRM/IRM Relaxation Analysis
clc; clear; close all;

%% ===============================
%% PLOT MODE CONFIGURATION
%% ===============================
plots = struct();
plots.core = true;
plots.diagnostics = false;
plots.debug = false;

>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
%% ============================================================
%               GLOBAL FITTING CONTROL
% ============================================================
fitParams = struct();
fitParams.betaBoost      = false;
fitParams.tauBoost       = false;
fitParams.timeWeight     = true;
fitParams.lowT_only      = false;
fitParams.lowT_threshold = 15;
<<<<<<< HEAD
fitParams.debugFit       = false;
=======
fitParams.debugFit       = plots.debug;
fitParams.timeWeightFactor = 0.725;    % strength of weighting (you can tune this)
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d

%% ============================================================
%               USER SETTINGS
% ============================================================
Bohar_units       = true;
showFits          = true;
<<<<<<< HEAD
debugMode         = true;
=======
debugMode         = plots.debug;
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
formatFigures     = true;
color_scheme      = 'parula';
normalizeByMass   = true;
fontsize          = 18;
<<<<<<< HEAD
linewidth         = 2.2;
compareMode       = false;
=======
compareMode       = false;
compareModeLocked = false;    % set true to force manual compareMode choice
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
alignByDrop       = true;
Hthresh_align     = 0.5;
trimToFitWindow   = true;
fitWindow_extraEnd_percent = 0.00;   % cut the tail
fitWindow_extraStart_percent = 0.00; % cut the initial start
<<<<<<< HEAD
fitParams.timeWeightFactor = 0.725;    % strength of weighting (you can tune this)
=======
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
absThreshold = 3e-5;
slopeThreshold = 1e-8;

exportFitTableToExcel      = false;
showInFitTableFigure       = true;
<<<<<<< HEAD
showRelaxationParamPlots   = true;
=======
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
minR2_for_paramPlots       = 0.97;

%% Display offset (visual only)
offsetDisplayMode  = true;     % if true → curves are vertically offset
<<<<<<< HEAD
offsetValue         = 5E-5;       % vertical separation between curves
=======
offsetValue        = 5E-5;     % vertical separation between curves
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d

%% ============================================================
%        DATA DIRECTORY (SET YOUR PATH)
% ============================================================
dir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";

%% ============================================================
<<<<<<< HEAD
%        DETECT TYPE FROM FOLDER NAME
% ============================================================
[~, folderName] = fileparts(dir);
folderLower = lower(folderName);

containsTRM_folder = contains(folderLower,"trm");
containsIRM_folder = contains(folderLower,"irm");

%% ============================================================
%        ADD PATHS
% ============================================================
baseFolder = 'C:\Dev\matlab-functions';
addpath(genpath(baseFolder));

%% ============================================================
%        GET FILE LIST
% ============================================================
[fileList, temps, fields, types, colors, mass] = ...
    getFileList_relaxation(dir, color_scheme);

%% Auto-detect TRM vs IRM compare mode
if containsTRM_folder && containsIRM_folder
    compareMode = true;
    fprintf("\n=== Auto-detected TRM vs IRM comparison ===\n");
end

%% ============================================================
%        IMPORT DATA
% ============================================================
=======
%        ADD PATHS
% ============================================================
baseFolder = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions';
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

>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
[Time_table, Temp_table, Field_table, Moment_table, massHeader] = ...
    importFiles_relaxation(dir, fileList, normalizeByMass, debugMode);

if ~isnan(massHeader)
<<<<<<< HEAD
    mass = massHeader;
=======
    mass = massHeader; %#ok<NASGU>
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
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
<<<<<<< HEAD
[growth_num, FIB_num] = extract_growth_FIB(dir, []);
sample_name = sprintf('MG %d', growth_num);

%% ============================================================
%     PLOT RAW RELAXATION (WITH TITLES & LEGENDS)
%     *** UPDATED TO SUPPORT OFFSET + FINAL VALUE CENTERING ***
% ============================================================
[Time_table, Moment_table, T_all, F_all] = Plots_relaxation( ...
    Time_table, Moment_table, temps, fields, Field_table, ...
    color_scheme, normalizeByMass, sample_name, fontsize, Bohar_units, ...
    fileList, alignByDrop, Hthresh_align, debugMode, trimToFitWindow, ...
    compareMode, containsTRM_folder, containsIRM_folder, ...
    offsetDisplayMode, offsetValue);

%% ============================================================
%     FIT RELAXATION CURVES
% ============================================================
=======
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
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
if showFits
    fprintf("\n--- Performing automatic relaxation fits ---\n");

    allFits = fitAllRelaxations(Time_table, Moment_table, ...
        Temp_table, Field_table, debugMode, Hthresh_align, fitParams, ...
<<<<<<< HEAD
        fitWindow_extraStart_percent, fitWindow_extraEnd_percent,absThreshold,slopeThreshold);

=======
        fitWindow_extraStart_percent, fitWindow_extraEnd_percent, absThreshold, slopeThreshold);
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d

    showRelaxationFitTable(allFits, exportFitTableToExcel, ...
        showInFitTableFigure, dir);
end

<<<<<<< HEAD
%% ============================================================
%     PLOT RELAXATION PARAMETERS VS TEMPERATURE
% ============================================================
if showRelaxationParamPlots
    plotRelaxationParamsVsTemp(allFits, sample_name, minR2_for_paramPlots);
end

%% ============================================================
%     OVERLAY FITTED CURVES
%     *** UPDATED TO SUPPORT OFFSET + FINAL VALUE CENTERING ***
% ============================================================
if showFits
=======
%% ===============================
%% PHYSICS PLOTS
%% ===============================
if plots.core && showFits && ~isempty(allFits)
    % Final fit overlay (single canonical implementation)
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
    overlayRelaxationFits(allFits, Time_table, Moment_table, ...
        color_scheme, fileList, debugMode, trimToFitWindow, ...
        compareMode, sample_name, fields, ...
        containsTRM_folder, containsIRM_folder, ...
        offsetDisplayMode, offsetValue);
<<<<<<< HEAD
end



%% ============================================================
%     ADVANCED ANALYSIS (NON-BREAKING, OPTIONAL)
% ============================================================
advancedMode = true;

if advancedMode && showFits
    advCfg = struct();

    advCfg.useMultiStart    = true;
    advCfg.enableLogModel   = true;
    advCfg.modelCriterion   = 'AIC';

    advCfg.makePerCurvePlots = true;
    advCfg.debugResidualPlot = debugMode;

    advCfg.makeSummaryPlot  = true;
    advCfg.makeCollapsePlot = true;

    % -------- NEW DEBUG FLAGS --------
    advCfg.debug     = true;     % prints diagnostics for each fit
    advCfg.advanced  = true;     % enables advanced summary

    advCfg.makePhysicsPlots       = true;   % tau(T) and beta(T)
    advCfg.makeResidualDiagnostics = true;  % residual vs log(t)
    advCfg.makeTauDistribution     = true;  % optional g(tau)

    adv = analyzeRelaxationAdvanced(allFits, Time_table, Moment_table, Temp_table, advCfg); %#ok<NASGU>
end

%% ============================================================
%     FINAL FORMATTING
% ============================================================
%{
=======

    % Physical parameters
    plotRelaxationParamsVsTemp(allFits, sample_name, minR2_for_paramPlots);

    % Collapse plot (stretched-exponential scaling)
    plotRelaxationCollapse(allFits, Time_table, Moment_table, sample_name, fileList);
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

    adv = analyzeRelaxationAdvanced(allFits, Time_table, Moment_table, Temp_table, advCfg);

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
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
if formatFigures && exist('formatAllFigures','file')
    formatAllFigures('pos',[0.1,0.1,0.75,0.7], ...
        'clearTitles',false,'showLegend',true,'showGrid',true);
end
<<<<<<< HEAD
%}
========
%% Compatibility wrapper (legacy filename)
run(fullfile(fileparts(mfilename('fullpath')), 'main_relaxation.m'));
>>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d:Relaxation ver3/main_relexation.m
=======
>>>>>>> 4d7010aa99892fd0adf50a8ee0c9939b97fa306d
