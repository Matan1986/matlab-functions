%% MAIN_RELAXATION — TRM/IRM Relaxation Analysis
clc; clear; close all;

%% ============================================================
%               GLOBAL FITTING CONTROL
% ============================================================
fitParams = struct();
fitParams.betaBoost      = false;
fitParams.tauBoost       = false;
fitParams.timeWeight     = true;
fitParams.lowT_only      = false;
fitParams.lowT_threshold = 15;
fitParams.debugFit       = false;

%% ============================================================
%               USER SETTINGS
% ============================================================
Bohar_units       = true;
showFits          = true;
debugMode         = false;
formatFigures     = true;
color_scheme      = 'parula';
normalizeByMass   = true;
fontsize          = 18;
linewidth         = 2.2;
compareMode       = false;
alignByDrop       = true;
Hthresh_align     = 0.5;
trimToFitWindow   = true;
fitWindow_extraEnd_percent = 0.00;   % cut the tail
fitWindow_extraStart_percent = 0.00; % cut the initial start
fitParams.timeWeightFactor = 0.725;    % strength of weighting (you can tune this)
absThreshold = 3e-5;
slopeThreshold = 1e-8;

exportFitTableToExcel      = false;
showInFitTableFigure       = true;
showRelaxationParamPlots   = true;
minR2_for_paramPlots       = 0.97;

%% Display offset (visual only)
offsetDisplayMode  = true;     % if true → curves are vertically offset
offsetValue         = 5E-5;       % vertical separation between curves

%% ============================================================
%        DATA DIRECTORY (SET YOUR PATH)
% ============================================================
dir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane susep relax aging\Relaxation TRM";

%% ============================================================
%        DETECT TYPE FROM FOLDER NAME
% ============================================================
[~, folderName] = fileparts(dir);
folderLower = lower(folderName);

containsTRM_folder = contains(folderLower,"trm");
containsIRM_folder = contains(folderLower,"irm");

%% ============================================================
%        ADD PATHS
% ============================================================
baseFolder = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions';
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
[Time_table, Temp_table, Field_table, Moment_table, massHeader] = ...
    importFiles_relaxation(dir, fileList, normalizeByMass, debugMode);

if ~isnan(massHeader)
    mass = massHeader;
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
if showFits
    fprintf("\n--- Performing automatic relaxation fits ---\n");

    allFits = fitAllRelaxations(Time_table, Moment_table, ...
        Temp_table, Field_table, debugMode, Hthresh_align, fitParams, ...
        fitWindow_extraStart_percent, fitWindow_extraEnd_percent,absThreshold,slopeThreshold);


    showRelaxationFitTable(allFits, exportFitTableToExcel, ...
        showInFitTableFigure, dir);
end

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
    overlayRelaxationFits(allFits, Time_table, Moment_table, ...
        color_scheme, fileList, debugMode, trimToFitWindow, ...
        compareMode, sample_name, fields, ...
        containsTRM_folder, containsIRM_folder, ...
        offsetDisplayMode, offsetValue);
end

%% ============================================================
%     FINAL FORMATTING
% ============================================================
if formatFigures && exist('formatAllFigures','file')
    formatAllFigures('pos',[0.1,0.1,0.75,0.7], ...
        'clearTitles',false,'showLegend',true,'showGrid',true);
end
