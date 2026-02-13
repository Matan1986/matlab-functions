%% ===========================
%  HC_main  –  Full Version
%  Compatible with auto mass detection in getFileListHC
% ===========================

clc;
clear;
close_all_except_ui_figures;

%% USER PARAMETERS
analysis_and_fitt       = false;
measure_while_cooling   = true;
temp_jump_threshold     = 3;      % for cleaning (if used)
Fontsize                = 20;
LineWidth               = 2;
figureMode = 'paper';   % 'normal' | 'paper'

%% PATHS
baseFolder = 'C:\Users\User\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions';
addpath(genpath(baseFolder));

%% DATA dir
dir = 'C:\Users\User\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 Heat Capacity out of plane\Field Scan 0T 8T';
% dir = 'I:\My Drive\...\Field scans data';
% dir = 'I:\My Drive\...\Field Scan 0T 8T';

%% ============================================================
%  IMPORT FILE LIST (AUTO-DETECT MASS + FIELD + MGxxx)
% ============================================================

enter_sample_details = true;   % initial, but will be overridden
[fileList, sortedFields, colors, mass, enter_sample_details] = ...
    getFileListHC(dir, enter_sample_details);


%% ============================================================
%  SET PHYSICAL CONSTANTS BASED ON MASS DETECTION
% ============================================================

if ~enter_sample_details
    % Co1/3TaS2 molar mass
    molar_mass = (1/3)*58.9332 + 1*180.948 + 2*32.066;

    % convert mass (mg) to mols
    n_mols = (mass * 1e-3) / molar_mass;

    overall_unit_mols = 1/3 + 1 + 2;
    HC_units = 1e-6;   % µJ → J
else
    % no mass → normalized units
    n_mols = 1;
    mass = 1;
    HC_units = 1;
    overall_unit_mols = 1;
end

unitsRatio = HC_units / n_mols;


%% ============================================================
%  IMPORT DATA
% ============================================================

[Temp_table, HC_table] = importFilesHC(dir, fileList, sortedFields, unitsRatio);


%% ============================================================
%  CLEAN (OPTIONAL)
% ============================================================

% [Temp_table, HC_table] = cleanDataForCoolingOrHeating(Temp_table, HC_table, sortedFields, temp_jump_threshold, measure_while_cooling);


%% ============================================================
%  PLOT
% ============================================================

PlotsHC(Temp_table, HC_table, sortedFields, colors, ...
        temp_jump_threshold, Fontsize, LineWidth);


%% ============================================================
%  ANALYSIS + FIT (OPTIONAL)
% ============================================================

if analysis_and_fitt
    peak_width        = 21;
    poly_order        = 3;
    moving_avg_window = 3;

    smoothed_data = analysisAndFittHC( Temp_table, HC_table, sortedFields, colors, ...
                                       peak_width, poly_order, temp_jump_threshold, moving_avg_window, Fontsize );
end


%% ============================================================
%  FIGURE FORMATTING  (normal | paper)
% ============================================================
%{
switch lower(figureMode)

    case 'normal'
        formatAllFigures( ...
            'pos',[0.10 0.10 0.70 0.60], ...
            'fontSize',18, ...
            'legendFS',16, ...
            'lineW',1.8, ...
            'showLegend',true, ...
            'showGrid',true, ...
            'clearTitles',true, ...
            'callerName','HC_main');

    case 'paper'
        % ==== SPECIAL JOURNAL STYLE ====
        formatAllFigures( ...
            'pos',[0.12 0.12 0.80 0.70], ...   % מעט גדול ורחב יותר
            'fontSize',30, ...                 % פונט גדול יותר
            'legendFS',22, ...                 % מקרא גדול
            'lineW',2.5, ...                   % קווים עבים
            'showLegend',true, ...
            'showGrid',true, ...
            'clearTitles',true, ...            % מנקה כותרות
            'callerName','HC_main');

    otherwise
        warning('Unknown figureMode. Use ''normal'' or ''paper''.');

end
%}

