%% intro
clc;
clear;
close_all_except_ui_figures;

fontsize = 24;
DC       = true;
color_scheme = 'default';
formatFigures = true;
plotAllCurvesOnOneFigure = true;
plot2DMaps = true; 
plotTemperatureCuts = true;   % true / false
T_targets = [5 7.5 10 12.5 15 17.5 20 22.5 25 27.5 30 32.5];   % טמפ' לחיתוכים
useAutoYScale = true;   % true / false
legendMode = 'external';   % 'internal' | 'external' | 'none'

%% ==========================
% Units mode
% ==========================
% Options:
%   'raw'       – raw MPMS moment units (emu)
%   'per_mass'  – normalized by sample mass (emu / g)
%   'per_Co'    – converted to μB per Co atom
unitsMode = 'per_mass';   % <-- choose: 'raw' | 'per_mass' | 'per_Co'
plotQuantity = 'M_over_H';   % 'M' | 'M_over_H'

%% Choose figure mode
figureMode = 'paper';   % 'regular' or 'paper'

% RAW MODE (לראות את הקבצים כמו שהם)
Unfiltered = false;

% Add paths
baseFolder = 'L:\My Drive\Quantum materials lab\Quantum materials lab\Matlab functions';
addpath(genpath(baseFolder));

%% dir
dir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M1 Out of plane MPMS\MT DC ZFC FCC FCW';

%% Import files (AUTO detect mode)
[fileList,sortedFields,colors,mass] = getFileList_MT(dir, color_scheme);

%% Compute units ratio AFTER mass is known
[unitsRatio, yLabelStr] = compute_unitsRatio_MT(unitsMode, mass);
fprintf("Units mode: %s   |  unitsRatio = %.3e\n", unitsMode, unitsRatio);

%% ============================================
% AUTO-DETECT MPMS (same mechanism as MH_main)
%% ============================================
systemType = detect_MT_file_type(dir, fileList{1});
MPMS = strcmpi(systemType, 'MPMS');
fprintf("Detected measurement system: %s\n", systemType);

%% ============================
% PARAMETERS for CLEANING
%% ============================
params.tempJump_K      = 0.5;
params.magJump_sigma   = 3;
params.useHampel       = true;
params.hampelWindow    = 21;
params.hampelSigma     = 2;
params.max_interp_gap  = 15;
params.sgOrder         = 2;
params.sgFrame         = 41;
params.movingAvgWindow = 15;
params.field_threshold = 20000;   % [Oe]

%% =====================================================
%  IMPORT DATA
%% =====================================================
[Time_table,Temp_table,VSM_table,MagneticFieldOe_table] = ...
    importFiles_MT(dir, fileList, sortedFields, MPMS, DC);

[growth_num, FIB_num] = extract_growth_FIB(dir, []);

%% =====================================================
%  CLEANING + SMOOTHING PER FILE
%% =====================================================
for iF = 1:numel(sortedFields)

    T_in = Temp_table{iF};
    M_in = VSM_table{iF};

    [T_raw, M_raw, T_clean, M_clean, T_smooth, M_smooth] = ...
        clean_MT_data(T_in, M_in, sortedFields(iF), params, Unfiltered);

    if Unfiltered
        Temp_table{iF} = T_raw;
        VSM_table{iF}  = M_raw;
    else
        Temp_table{iF} = T_smooth;
        VSM_table{iF}  = M_smooth;
    end
end

%% =====================================================
% FIND TEMPERATURE SEGMENTS
%% =====================================================
temp_values_vec = {};
increasing_temp_cell_array = {};
decreasing_temp_cell_array = {};

delta_T = 0.7;
min_temp_change = 0.1;
min_temp_time_window_change = 20;
temp_rate = 3;
temp_stabilization_window = 10;
min_segment_length_temp = 50;

for i = 1:length(sortedFields)
    TimeSec = Time_table{i};
    TemperatureK = Temp_table{i};

    temp_values_vec{i} = [min(TemperatureK), max(TemperatureK)];

    filtered_temp = medfilt1(TemperatureK, 20);
    % Safety: if temperature vector is empty or too short
    if numel(filtered_temp) < 2
        warning("Temperature vector too short in file index %d — skipping.", i);
        increasing_temp_cell_array{i,1} = [];
        decreasing_temp_cell_array{i,1} = [];
        continue;   % jump to next file
    end

    filtered_temp(1) = filtered_temp(2);   % safe now

    filtered_temp(1) = filtered_temp(2);

    [inc_seg] = find_increasing_temperature_segments_MT( ...
        TimeSec, filtered_temp, min_segment_length_temp, ...
        temp_values_vec{i}(2), min_temp_change, ...
        min_temp_time_window_change, temp_rate, ...
        temp_stabilization_window, delta_T);

    [dec_seg] = find_decreasing_temperature_segments_MT( ...
        TimeSec, filtered_temp, min_segment_length_temp, ...
        temp_values_vec{i}(1), min_temp_change, ...
        min_temp_time_window_change, temp_rate, ...
        temp_stabilization_window, delta_T);

    increasing_temp_cell_array{i,1} = inc_seg;
    decreasing_temp_cell_array{i,1} = dec_seg;
end

%% =====================================================
% PLOTS
%% =====================================================
if ~plotAllCurvesOnOneFigure
Plots_MT(Temp_table, VSM_table, sortedFields, colors, ...
         unitsRatio, yLabelStr, ...
         increasing_temp_cell_array, decreasing_temp_cell_array, ...
         growth_num, fontsize,plotQuantity);

if plot2DMaps
    plot_MT_2D_maps(Temp_table, VSM_table, MagneticFieldOe_table, ...
        sortedFields, unitsRatio, plotQuantity, unitsMode, fontsize);
    if plotTemperatureCuts
    Plots_MT_Tcuts( ...
        Temp_table, ...
        VSM_table, ...
        MagneticFieldOe_table, ...
        increasing_temp_cell_array, ...
        sortedFields, ...
        unitsRatio, ...
        plotQuantity, ...
        fontsize, ...
        T_targets);
end
end

else
legendData = Plots_MT_combined( ...
    Temp_table, VSM_table, sortedFields, colors, unitsRatio, ...
    increasing_temp_cell_array, decreasing_temp_cell_array, ...
    growth_num, fontsize, ...
    figureMode, plotQuantity, unitsMode, ...
    useAutoYScale, legendMode);

if plot2DMaps
plot_MT_2D_maps_segments( ...
    Temp_table, VSM_table, MagneticFieldOe_table, ...
    increasing_temp_cell_array, decreasing_temp_cell_array, ...
    sortedFields, unitsRatio, plotQuantity, fontsize);
    if plotTemperatureCuts
        Plots_MT_Tcuts( ...
            Temp_table, ...
            VSM_table, ...
            MagneticFieldOe_table, ...
            increasing_temp_cell_array, ...
            sortedFields, ...
            unitsRatio, ...
            plotQuantity, ...
            fontsize, ...
            T_targets);
    end
end
end
%{
if formatFigures
    switch figureMode
        case 'paper'
            formatAllFigures('pos',[0.1,0.1,0.8,0.75], ...
                'fontSize',36, ...
                'legendFS',36, ...
                'lineW',2.5, ...
                'showLegend',false, ...
                'showGrid',true);

        case 'small'
            formatAllFigures('pos',[0.15,0.15,0.40,0.50], ...
                'fontSize',12, ...
                'legendFS',11, ...
                'lineW',1.2, ...
                'showLegend',false, ...    % חשוב!
                'showGrid',true);

    end
end
%}

