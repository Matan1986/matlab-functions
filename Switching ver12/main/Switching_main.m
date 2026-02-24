clc;
clear;
close_all_except_ui_figures;
format shortEng;
%% dir & file list
baseFolder = 'C:\Dev\matlab-functions';
addpath(genpath(baseFolder));
dir = "L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\FIB5_Switching_old_PPMS\Config3 23\Amp Temp Dep all fix\Temp Dep 25mA 10ms 0T 15sec 10pulses 16";
dir = "L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\FIB5_Switching_old_PPMS\Config3 23\Amp Temp Dep all fix\Temp Dep 35mA 10ms 0T 15sec 10pulses 29";
% -------------------------------------------------
% Amp–Temp Switching Map
% plotAmpTempSwitchingMap_switchCh(parentDir, metricType, channelMode)
% parentDir must contain subfolders named "Temp Dep ... mA ..."
if detectAmpTempSwitchingMap(dir)
    plotAmpTempMode = "map+fc";       % "map" | "map+fc"
    ampTempMetric = "P2P_percent";   %  "P2P_percent" | "medianAbs" | "meanP2P"
    ChannesToPlotAmpTemp = "switchCh";      % "switchCh"  |  "all"
    FC_amp_subset = [15 25 35];   % mA
    plotAmpTempSwitchingMap_switchCh( ...
        dir, ampTempMetric, ChannesToPlotAmpTemp, plotAmpTempMode,FC_amp_subset);
    return;
end
%% -------------------------------------------------
dep_type = extract_dep_type_from_folder(dir);
[fileList, sortedValues, colors, meta] = ...
    getFileListSwitching(dir, dep_type);
pulseScheme = extractPulseSchemeFromFolder(dir);
force_manual_preset = true;
manual_preset_name  = '1xy_3xx';
% Preset (for labeling / channel mapping)
preset_name = resolve_preset(fileList(1).name, force_manual_preset, manual_preset_name);
% Channel mapping / normalization
[chMap, plotChannels, labels, Normalize_to] = select_preset(preset_name);
fn = fieldnames(labels);
for k = 1:numel(fn)
    if ~isempty(labels.(fn{k}))
        labels.(fn{k}) = strrep(labels.(fn{k}), 'ρ', 'R');
    end
end
%% Some swaping
swap_Rxy_direction = false;
swap_conf_3_4 = false;
swap_conf_1_2 = false;
%% Switching stability analysis options
% Configuration for analyzeSwitchingStability:
% controls state definition, conditioning exclusion,
% and stability metrics evaluation.
stbOpts = struct();
% --- Debug control ---
stbOpts.debugMode   = false;   % Enable diagnostic figures
stbOpts.debugEveryN = 1;       % Debug every N-th file
% --- Signal selection ---
stbOpts.useFiltered = true;    % Use filtered traces
stbOpts.useCentered = false;   % Use centered traces (relative baseline)
% --- State definition ---
stbOpts.stateMethod = pulseScheme.mode;
% --- Plateau analysis ---
stbOpts.minPtsFit   = 10;      % Min points for slope fit inside plateau
stbOpts.settleFrac  = 0.9;     % Fraction of step used for settling time
% --- Conditioning control ---
stbOpts.skipFirstPlateaus = 1;  % Number of initial plateaus to exclude
stbOpts.skipLastPlateaus  = 0;        % Number of final plateaus to exclude
% --- Debug visualization ---
stbOpts.debugPanels = ["trace","plateau","states","drift", ...
    "slope","within","settle","compareSkips"];
stbOpts.debugFiles    = [];    % Restrict debug to selected files
stbOpts.debugChannels = [];    % Restrict debug to selected channels
stbOpts.pulseScheme = pulseScheme;
plotStabilityAllChannels = true;
%% Visualization
plot_std      = false;
plot_std_as_errors_on_p2p = false;
NegP2P_mode = "auto";
NegP2P = resolveNegP2P(dir, NegP2P_mode);
lineWidth     = 1;
fontsize      = 18;
Format=     true;
debugMode = false;
showLegend = SwitchingShowLegendFun(dep_type);
% FormatArgs = {position, fontSize, legendFontSize, lineWidth, clearTitles, showLegend, showGrid}
% FormatArgs = {[0.1,0.1,0.7,0.6], 20, 20, 1.5, false, showLegend, true};
Resistivity = false;
plotSwitchingTraces = true;
%% Pulses Geometry
[pulses_length_in_sec] =extract_pulse_length_from_name(dir);
pulses_length_in_msec=pulses_length_in_sec*1e3;
delay_between_pulses_in_sec = extract_delay_between_pulses_from_name(dir);
delay_between_pulses_in_msec=delay_between_pulses_in_sec*1e3;
num_of_pulses_with_same_dep_each = pulseScheme.pulsesPerBlock;
num_of_pulses_with_same_dep      = pulseScheme.totalPulses;
safety_margin_for_average_between_pulses_in_percent = 15; %  33
%% For some bad measurments
num_of_pulses_with_same_dep_changes = false;
if num_of_pulses_with_same_dep_changes
    pulses_with_other_num_of_pulses_with_same_dep = 4;
    num_of_pulses_with_same_dep2 = 20;
else
    pulses_with_other_num_of_pulses_with_same_dep = NaN;
    num_of_pulses_with_same_dep2 = NaN;
end
%%
[growth_num, FIB_num] = extract_growth_FIB(dir, fileList(1).name);
I = extract_current_I(dir, fileList(1).name, NaN);
if Resistivity
    [Scaling_factor, A] = getScalingFactor(growth_num, FIB_num); % Ohm-cm
else
    [Scaling_factor, A] = getScalingFactor(growth_num, FIB_num);
    Scaling_factor= 1e3;       % m·Ohm;
end
%% ==== FILTERING & OUTLIER CONTROL PARAMETERS ====
RemovePulseOutliers = true;     % Clean local outliers around each pulse (recommended ON)
PulseOutlierPercent = 1.5;      % Local cleaning strength: threshold = PulseOutlierPercent * sigma
% 1 = very aggressive, 2–3 = recommended, >5 = weak
safety_margin_for_outlier_clean_in_percent = 50;    % Cleaning window size around each pulse (as % of pulse delay)
% 5% = narrow, 8–10% = recommended, >15% = wide (thermal effects)
%% ==== GLOBAL FILTERING PARAMETERS ====
hample_filter_window_size = 4000;
% Hampel window size (larger = smoother, less sensitive to spikes)
HampelGlobalPercent = 4;  % Global outlier threshold: thr = HampelGlobalPercent * MAD 1.7
% 3 = standard, >5 = weaker filtering
med_filter_window_size = 16; % Median filter window (removes point spikes, preserves edges) 6
SG_filter_poly_order = 2; % Savitzky–Golay polynomial order (higher = sharper features) 8
SG_filter_frame_size = 11; % Savitzky–Golay window size (odd number, controls smoothing) 11
if strcmp(dep_type,'Configuration')
    pulse_current_str = meta.Current_mA + "mA";
end
%% Process files
[stored_data, tableData] = processFilesSwitching( ...
    dir, fileList, sortedValues, I, Scaling_factor, ...
    hample_filter_window_size, med_filter_window_size, HampelGlobalPercent, ...
    SG_filter_poly_order, SG_filter_frame_size, ...
    swap_Rxy_direction, delay_between_pulses_in_msec, ...
    num_of_pulses_with_same_dep, safety_margin_for_average_between_pulses_in_percent, ...
    pulses_with_other_num_of_pulses_with_same_dep, num_of_pulses_with_same_dep2, ...
    Normalize_to, ...
    RemovePulseOutliers, PulseOutlierPercent,safety_margin_for_outlier_clean_in_percent,debugMode,pulseScheme);


%%% FIX: keep an "analysis channels" vector if you want, BUT derive plot channels from preset
nCols = size(stored_data{1,3}, 2) - 1;    % ignore TIME column
active_channels = 1:nCols;                % (leave for generic uses if needed)

% Plot channels must follow preset (manual/auto), not raw column count:
presetPlotMask = [plotChannels.ch1, plotChannels.ch2, plotChannels.ch3, plotChannels.ch4];
active_channels_plot = find(presetPlotMask);
active_channels_plot = active_channels_plot(active_channels_plot <= nCols);

stability = analyzeSwitchingStability( ...
    stored_data, sortedValues, ...
    delay_between_pulses_in_msec, safety_margin_for_average_between_pulses_in_percent, ...
    stbOpts);
switchCh = stability.switching.globalChannel;
% ---------------------------------------
% Choose which physical channels to plot
% ---------------------------------------
if plotStabilityAllChannels
    ch_phys_to_plot = find([ ...
        plotChannels.ch1, ...
        plotChannels.ch2, ...
        plotChannels.ch3, ...
        plotChannels.ch4 ]);
else
    ch_phys_to_plot = switchCh;
end

stability.meta=meta;
createSwitchingStabilityFigure(stability, dep_type, labels,A);

if pulseScheme.mode == "repeated"

    debugPlotGlobalPulseDrift_TimeAxis( ...
        stored_data, sortedValues, ...
        delay_between_pulses_in_msec, ...
        pulseScheme.pulsesPerBlock, ...
        ch_phys_to_plot, dep_type, labels);

    plotTotalBlockDriftVsDep_PulseResolved( ...
        stored_data, sortedValues, ...
        pulseScheme.pulsesPerBlock, ...
        ch_phys_to_plot, dep_type, labels);
end


%% Optional configuration swaps
if strcmp(dep_type,'Configuration')
    if swap_conf_3_4
        % swap rows 3 & 4 in all relevant arrays/tables
        stored_data([3 4],:)      = stored_data([4 3],:);
        tableData_Rxy1([3 4],2:5)  = tableData_Rxy1([4 3],2:5);
        tableData_Rxx2([3 4],2:5)  = tableData_Rxx2([4 3],2:5);
    end
    if swap_conf_1_2
        stored_data([1 2],:)      = stored_data([2 1],:);
        tableData_Rxy1([1 2],2:5)  = tableData_Rxy1([2 1],2:5);
        tableData_Rxx2([1 2],2:5)  = tableData_Rxx2([2 1],2:5);
    end
end

%% Create plots & tables using your channel labels
labels_struct = labels;          % from select_preset
plot_struct   = plotChannels;    % from select_preset


if plotSwitchingTraces
    createPlotsSwitching( ...
        stored_data, sortedValues, colors, A, dep_type, ...
        lineWidth, fontsize, labels, plotChannels, Resistivity,meta);
end

if ~strcmp(dep_type,'Configuration')
    createP2PSwitching(tableData, sortedValues, A, dep_type, ...
        plot_std, labels, plotChannels, Normalize_to, NegP2P, ...
        plot_std_as_errors_on_p2p, pulseScheme, meta);
else
    fig = plotFilteredCenteredSubplotsDiffConfig( ...
        stored_data, meta, dep_type,labels, Normalize_to, active_channels_plot, fontsize);

    %   createP2PSwitchingConfig(tableData, sortedValues, A, pulse_current_str, ...
    %                       plot_std, labels, plotChannels);

end
%%


