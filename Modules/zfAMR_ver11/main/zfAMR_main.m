%% Intro
clc; close_all_except_ui_figures;

baseFolder = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions'; % Work PC
addpath(genpath(baseFolder));

%% ===========================
%  USER PARAMETERS (EDITABLE)
%  ===========================
import = true;                                                %% [EDITABLE]
dir = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 131\Diff devices In plane";  %% [EDITABLE]
filename_ending = "FIB12_Vxy1_Vxx2_Vxy3_Vxx4_Ixx_0p1mAmp_f_277p77Hz_Field_11T_5deg_4K_zfAMR";                                                       %% [EDITABLE]

%% Channels configuration
% force=true → manual; false → try filename, else manual %
force_manual_preset = false;            %% [EDITABLE]
manual_preset_name = '1xy_2xx';        % Preset: '2xx' | '1xy_2xx_3xy_4xx' | '1xy_2xx' | '1xx_2xx' | '2xx_3xy' %% [EDITABLE]
channel_sign_vec = [1, 1, 1, 1];   % example: flip LI2 only
preset_name = resolve_preset(filename_ending, force_manual_preset, manual_preset_name);

%% What to plot
plot_specific_temp_at_diff_fields_for_zfAMR_or_fcAMR = "comp";      % "zfAMR","fcAMR","both","comp","non"   %% [EDITABLE]
plot_specific_field_at_diff_temp_for_zfAMR_or_fcAMR  = "non";     % "zfAMR","fcAMR","both","comp","non"   %% [EDITABLE]
resistivity_vs_temp = false;                                       %% [EDITABLE]
showAngleUI_resistivity = false;
polar_plots = false;                                               %% [EDITABLE]
Plot_deltaR_for_specific_angle_at_diff_field_at_diff_temp = false; %% [EDITABLE]
zfc_fwAMR = false;                                                 %% [EDITABLE]
%% ===========================
%  SYMMETRY / FOURIER – USER OPTIONS
% ===========================
doSymmetryAnalysis = false;     % master switch
symMode            = 'zf';     % 'zf' | 'fc' | 'both'
symChannels        = {'2xx'};  % channels to analyze
selectedFields_T   = []; % [1 3 5 7 9 11 13]; % [] = all fields

% --- Symmetry Fourier options ---
symOpts = struct();
symOpts.maxHarm        = 12;
symOpts.specWeightMin = 30;   % minimal AMR strength: below this → no phase at this T
symOpts.phaseRelFrac  = 0.12;  % harmonic must be ≥% of dominant harmonic at this T
symOpts.harmRelFrac   = 0.12;  % harmonic must be ≥% of its own max over all T
symOpts.removeMean     = true;
symOpts.doDetrend      = false;
symOpts.verbose        = true;
symOpts.plotSpectra    = false;
symOpts.plotMaps       = true;
symOpts.pickTempIdx    = [];     % [] = all temperatures

% --- Physical Fourier analysis ---

fourierPhys = struct();
fourierPhys.do            = true;
fourierPhys.mode          = symMode;     % 'zf' | 'fc' | 'both'
fourierPhys.harmonics = [1 2 4 6 8];
fourierPhys.lockingFields_T = selectedFields_T;   % [] = all fields

fourierPhys.pickFieldIdx = [];
fourierPhys.Tref          = 'firstValid';

% visualization
fourierPhys.show.vector        = false;  % complex plane
fourierPhys.show.axisRotation  = false;   % Δθ0(T)
fourierPhys.show.phaseRel      = true;

% validity thresholds (linked to symOpts)
fourierPhys.valid.minSpecWeight = symOpts.specWeightMin;

fourierPhys.valid.relFrac       = symOpts.phaseRelFrac;
% ---- NEW: locking visualization ----
fourierPhys.show.locking = true;
fourierPhys.show.lockingOneFigPerField = true;

%% Field and Angle selections
plot_specific_field_vector=NaN;       % NaN || [11] ;             %% [EDITABLE]
plot_specific_angles_for_deltaR_phaseMap = NaN; % 0:15:360;       %% [EDITABLE]
forced_max_angle=NaN;                                             %% [EDITABLE]
delta_Angle = resolve_delta_angle_from_names(dir, filename_ending);

%% Temperatures selections
[growth_num, ~] = extract_growth_FIB(dir,filename_ending);
temp_values = "TNs" ; %  "TNs" | "FullRange";
if strcmp(temp_values,"TNs")
    switch growth_num
        case 119
            temp_values = [4,33];

        case 131
            temp_values = [4,27];
    end
elseif strcmp(temp_values,"FullRange")
    temp_values = 4:2:50;                    % [EDITABLE]       4:1:50 | | [4,27,50] | 4:1:40  | [4,33,50]
end
num_of_temp_values  = numel(temp_values);

%% Formating
formatFigures = true;                                         %% [EDITABLE]
fontsize = 18; linewidth = 3;                                 %% [EDITABLE]
legendThreshold =5 ;                                          %% [EDITABLE]

%% Debug flags
plot_the_founded_angle_segments = false;                      %% [EDITABLE]
plot_the_founded_field_segments = false;                      %% [EDITABLE]
plot_the_founded_temp_segments  = false;                      %% [EDITABLE]
plot_the_extracted_segments     = false;                      %% [EDITABLE]
plot_the_extracted_segments_with_points = false;              %% [EDITABLE]

%% Exclusions
excluded_fields = NaN; % NaN = none                           %% [EDITABLE]
angles_to_exclude_within_specific_field = [ struct('field', 11, 'angles', 190), ...
    struct('field', NaN, 'angles', NaN) ];                    %% [EDITABLE]

%% Segment detection and filtering
% Segment thresholds — Angle
angle_threshold = 0.5;                                         %% [EDITABLE]  15deg  0.5
min_segment_length_angle = 8;                                  %% [EDITABLE]  15deg  8
% Segment thresholds — Temperature
delta_T = 0.2;                                                 %% [EDITABLE]
min_temp_change = 0.01;                                        %% [EDITABLE]
min_temp_time_window_change = 20;                              %% [EDITABLE]
temp_rate = 3;                                                 %% [EDITABLE]
temp_stabilization_window = 50;                                %% [EDITABLE]
min_segment_length_temp = 1000;                                %% [EDITABLE]
% Segment thresholds — Field
min_field_threshold = 0.001;                                   %% [EDITABLE]
min_diff_field_threshold = 0.001;                              %% [EDITABLE]
min_segment_length_field = 10000;                              %% [EDITABLE]
field_stabilization_window = 1000;                             %% [EDITABLE]

%% Plot strings / mode
[plan_measured, plan_measured_strings, matched] = ...
    extract_plane_mode(dir, filename_ending, NaN); % Expected for your path: plan_measured = 1, plan_measured_str = "In plane"
%%  Geometry & scaling
I = extract_current_I(dir, filename_ending, NaN);
[growth_num, FIB_num] = extract_growth_FIB(dir,filename_ending);
Scaling_factor = getScalingFactor(growth_num, FIB_num);

%% ===========================
%  DATA IMPORT
%  ===========================
if import
    % Keep only user-editable constants; clear everything else
    clearvars -except ...
        import dir filename_ending ...                         % paths/import
        field_vector...
        angles...
        delta_Angle...
        channel_sign_vec...
        plot_specific_angles_for_deltaR_phaseMap...
        legendThreshold...
        forced_max_angle...
        plot_specific_field_vector...
        plan_measured_strings plan_measured ...                    % plane choice
        formatFigures fontsize linewidth LegendVar ...             % figure opts
        plot_the_founded_angle_segments plot_the_founded_field_segments ...
        plot_the_founded_temp_segments plot_the_extracted_segments ...
        plot_the_extracted_segments_with_points ...                % debug flags
        excluded_fields angles_to_exclude_within_specific_field ...% exclusions
        plot_specific_temp_at_diff_fields_for_zfAMR_or_fcAMR ...
        plot_specific_field_at_diff_temp_for_zfAMR_or_fcAMR ...
        resistivity_vs_temp polar_plots ...
        Plot_deltaR_for_specific_angle_at_diff_field_at_diff_temp ...
        zfc_fwAMR ...                                              % plot toggles
        plot_specific_field_vector plot_specific_angles ...                          % axes
        temp_values num_of_temp_values ...      % temperatures
        I d l w A convenient_units Scaling_factor ...               % geometry
        preset_name ...                                            % preset
        angle_threshold min_segment_length_angle ...               % angle seg
        delta_T min_temp_change min_temp_time_window_change ...
        temp_rate temp_stabilization_window min_segment_length_temp ... % temp seg
        min_field_threshold min_diff_field_threshold ...
        min_segment_length_field field_stabilization_window ...    % field seg
        baseFolder...
        doSymmetryAnalysis...
        symOpts...
        symMode...
        symChannels...
        selectedFields_T...
        harmonics...
        do_fourierPhys...
        fourierPhys...
        plotHarmonicLocking...
        lockingHarmonics ...
        lockingFields_T  ...
        showAngleUI_resistivity...

    filename = dir + "\" + filename_ending;
    [Timems, FieldT, TemperatureK, Angledeg, ...
        LI1_XV, LI1_theta, LI2_XV, LI2_theta, LI3_XV, LI3_theta, LI4_XV, LI4_theta] = read_data(filename);
end

% Append handling
appended_files = extract_appended_flag("", filename_ending);
% Append handling
Timems = append_file_fun(appended_files, Timems, Angledeg);

% Plot strings
plan_measured_str = choose_plane(plan_measured_strings, plan_measured);

%% ===========================
%  PRESET SELECTION
%  ===========================
[chMap, plotChannels, labels, Normalize_to] = select_preset(preset_name);
enabled_all = {'ch1','ch2','ch3','ch4'};
enabled_all = enabled_all([plotChannels.ch1, plotChannels.ch2, plotChannels.ch3, plotChannels.ch4]);
assert(numel(Normalize_to)==numel(enabled_all), ...
    'Normalize_to length (%d) must match number of enabled channels (%d).', ...
    numel(Normalize_to), numel(enabled_all));

%% ===========================
%  BUILD CHANNELS (ρ) + FILTERS
%  ===========================
% ---- After reading data and before build_channels ----
LI_XV = {LI1_XV, LI2_XV, LI3_XV, LI4_XV};
% Apply signs based on the vector
LI_XV = apply_channel_signs_by_preset(preset_name, channel_sign_vec, LI_XV);
% Unpack back if needed
[LI1_XV, LI2_XV, LI3_XV, LI4_XV] = LI_XV{:};
chans_all = build_channels(chMap, LI_XV, I, Scaling_factor);
chans_all = filter_channels(chans_all, Angledeg, FieldT, TemperatureK);

% pull filtered vectors back out
filtered_angle = chans_all.filtered_angle;
filtered_field = chans_all.filtered_field;
filtered_temp  = chans_all.filtered_temp;

% keep only enabled channels
enabledKeys = get_enabled_keys(plotChannels);                  % e.g., {'ch2','ch3'}
chans = keep_enabled(chans_all, enabledKeys);

% ---- CRUCIAL: map physical Normalize_to -> local indices for enabled keys ----
Normalize_to_local = resolve_norm_indices(Normalize_to, enabledKeys);
%% ===========================
%  ADVANCED FILTERING (NEW)
%  ===========================
ViewRAW = true;      % RAW MODE switch

% ---- Pre-outlier removal ----
RemoveOutliers      = true;
OutlierPercent      = 150;   % % מהממוצע

% ---- Median filter ----
DoMedianFilter      = true;
MedianWindow        = 5;

% ---- Smoothing ----
DoSmoothing         = true;
SmoothMethod        = 'movmean';  % 'movmean' | 'sgolay'
SmoothWindow        = 7;
sgolay_order_new    = 3;

% ---- Post-outlier removal ----
ApplyPostOutlierFilter  = true;
PostOutlierJumpPercent  = 300;   % % מהאמפליטודה
PostOutlierMedianFactor = 3;     % בכפולות של median deviation

% RAW override
if ViewRAW
    RemoveOutliers         = false;
    DoMedianFilter         = false;
    DoSmoothing            = false;
    ApplyPostOutlierFilter = false;
end

%% ===========================
%  APPLY FULL FILTER PIPELINE TO ALL ENABLED CHANNELS
%  ===========================
for iKey = 1:numel(enabledKeys)
    key = enabledKeys{iKey};
    y_raw = chans.(key);
    y_f = y_raw;

    % A) Pre-outlier removal
    if RemoveOutliers
        muY = nanmean(y_f);
        thr = abs(muY) * (OutlierPercent/100);
        y_f = remove_outliers_simple(y_f, thr);
    end

    % B) Median filtering
    if DoMedianFilter
        y_f = medfilt1(y_f, MedianWindow, 'omitnan', 'truncate');
    end

    % C) Smoothing
    if DoSmoothing
        switch lower(SmoothMethod)
            case 'movmean'
                y_f = movmean(y_f, SmoothWindow, 'omitnan');
            case 'sgolay'
                y_f = sgolayfilt(y_f, sgolay_order_new, SmoothWindow);
        end
    end

    % D) Post-outlier removal
    if ApplyPostOutlierFilter
        y_f = clean_after_normalization(y_f, ...
            PostOutlierJumpPercent, PostOutlierMedianFactor);
    end

    % Replace filtered channel
    chans.(key) = y_f;
end
%% ===========================
%  SEGMENTS
%  ===========================

base_max_angle = extract_base_max_angle(filename, forced_max_angle);
[segments_angle, rounded_smoothed_angle_deg, unique_rounded_smoothed_angle_deg] =...
    find_angle_segments(delta_Angle, angle_threshold, filtered_angle, min_segment_length_angle);

[rounded_smoothed_angle_deg, unique_rounded_smoothed_angle_deg] = ...
    fix_angle_wrap_after_segments( ...
    filtered_angle, ...
    rounded_smoothed_angle_deg, ...
    unique_rounded_smoothed_angle_deg, ...
    base_max_angle);

segments_increasing_temp = find_increasing_temperature_segments( ...
    Timems, filtered_temp, min_segment_length_temp, ...
    temp_values(end), min_temp_change, min_temp_time_window_change, ...
    temp_rate, temp_stabilization_window, delta_T);

segments_decreasing_temp = find_decreasing_temperature_segments( ...
    Timems, filtered_temp, min_segment_length_temp, ...
    temp_values(1), min_temp_change, min_temp_time_window_change, ...
    temp_rate, temp_stabilization_window, delta_T);

[segments_field_max, rounded_unique_field_max_values, rounded_field_max_values_vec] = ...
    find_field_segments(filtered_field, min_field_threshold, min_diff_field_threshold, ...
    min_segment_length_field, field_stabilization_window);

if(isnan(plot_specific_field_vector))
    plot_specific_field_vector=rounded_unique_field_max_values;
end

%% Optional debug plots
if plot_the_founded_angle_segments
    plot_founded_angle_segments(Timems, TemperatureK, FieldT, ...
        segments_angle, rounded_smoothed_angle_deg, unique_rounded_smoothed_angle_deg, ...
        base_max_angle);
end
if plot_the_founded_field_segments
    plot_founded_field_segments(Timems, TemperatureK, FieldT, ...
        filtered_field, segments_field_max, rounded_field_max_values_vec, ...
        rounded_unique_field_max_values);
end
if plot_the_founded_temp_segments
    plot_founded_increasing_temperature_segments(Timems, TemperatureK, FieldT, ...
        segments_increasing_temp, filtered_temp);
    plot_founded_decreasing_temperature_segments(Timems, TemperatureK, FieldT, ...
        segments_decreasing_temp, filtered_temp);
end

%% ===========================
%  INTERSECTIONS + POINTS
%  ===========================
warming_tables = extract_warming_segments( ...
    segments_angle, rounded_smoothed_angle_deg, unique_rounded_smoothed_angle_deg, ...
    segments_increasing_temp, segments_decreasing_temp, ...
    segments_field_max, rounded_unique_field_max_values, filtered_field);

cooling_tables = extract_cooling_segments( ...
    segments_angle, rounded_smoothed_angle_deg, unique_rounded_smoothed_angle_deg, ...
    segments_decreasing_temp, segments_field_max, ...
    rounded_unique_field_max_values, filtered_field);

if plot_the_extracted_segments
    plot_extracted_warming_segments(Timems, TemperatureK, FieldT, warming_tables, filtered_temp, ...
        'Warn', false, 'Debug', false, 'DebugTag', 'WARM');

    plot_extracted_cooling_segments( ...
        Timems, TemperatureK, FieldT, cooling_tables, filtered_temp);
end

warming_points_table = extract_warming_segments_with_points( ...
    Timems, warming_tables, TemperatureK, ...
    unique_rounded_smoothed_angle_deg, temp_values, delta_T);

cooling_points_table = extract_cooling_segments_with_points( ...
    Timems, cooling_tables, TemperatureK, ...
    unique_rounded_smoothed_angle_deg, temp_values, delta_T);

%% ===========================
%  RESISTIVITY TABLES & AVERAGES
%  ===========================
[resistivity_warming_tables, resistivity_cooling_tables] = ...
    build_resistivity_tables(warming_tables, cooling_tables, TemperatureK, chans);

if resistivity_vs_temp
    plot_resistivity_warming_segments(resistivity_warming_tables, ...
        rounded_unique_field_max_values, merge_labels(plotChannels, labels), plan_measured_str,showAngleUI_resistivity);
    plot_resistivity_cooling_segments(resistivity_cooling_tables, ...
        rounded_unique_field_max_values, merge_labels(plotChannels, labels), plan_measured_str,showAngleUI_resistivity);
end

resistivity_warming_points_tables = build_resistivity_warming_points_tables( ... % chack this
    warming_points_table, chans, num_of_temp_values);
resistivity_cooling_points_tables = build_resistivity_cooling_points_tables( ...
    cooling_points_table, chans, num_of_temp_values);

resistivity_warming_points_averages = calculate_resistivity_points_averages( ...
    resistivity_warming_points_tables, angles_to_exclude_within_specific_field, ...
    rounded_unique_field_max_values, enabledKeys);
resistivity_cooling_points_averages = calculate_resistivity_points_averages( ...
    resistivity_cooling_points_tables, angles_to_exclude_within_specific_field, ...
    rounded_unique_field_max_values, enabledKeys);

resistivity_warming_deviation_percent_tables = calculate_resistivity_deviation_percent( ...
    resistivity_warming_points_tables, resistivity_warming_points_averages, ...
    Normalize_to, angles_to_exclude_within_specific_field, ...
    rounded_unique_field_max_values, enabledKeys);
resistivity_cooling_deviation_percent_tables = calculate_resistivity_deviation_percent( ...
    resistivity_cooling_points_tables, resistivity_cooling_points_averages, ...
    Normalize_to, angles_to_exclude_within_specific_field, ...
    rounded_unique_field_max_values, enabledKeys);

%% ===========================
%  PLOTS (ANGLE SCANS / MAPS)
%  ===========================
if ~strcmp(plot_specific_temp_at_diff_fields_for_zfAMR_or_fcAMR,"non")
    if plot_specific_temp_at_diff_fields_for_zfAMR_or_fcAMR == "comp"
        for ti = 1:numel(temp_values)
            plot_compAMR( ...
                resistivity_warming_deviation_percent_tables, ...
                resistivity_cooling_deviation_percent_tables, ...
                rounded_unique_field_max_values, ...
                ti, temp_values(ti), Normalize_to_local, excluded_fields, ...
                plan_measured_str, fontsize, linewidth, ...
                merge_labels(plotChannels, labels), zfc_fwAMR);
        end
    end
    if any(plot_specific_temp_at_diff_fields_for_zfAMR_or_fcAMR == ["zfAMR","both"])
        for ti = 1:numel(temp_values)
            plot_zfAMR(resistivity_warming_deviation_percent_tables, ...
                unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, ...
                ti, temp_values(ti), Normalize_to_local, excluded_fields, ...
                plan_measured_str, fontsize, linewidth, merge_labels(plotChannels, labels), zfc_fwAMR);
        end
        if polar_plots
            for ti = 1:numel(temp_values)
                plot_zfAMR_polar(resistivity_warming_deviation_percent_tables, ...
                    unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, ...
                    ti, temp_values(ti), Normalize_to_local, excluded_fields, ...
                    plan_measured_str, fontsize, linewidth, merge_labels(plotChannels, labels), zfc_fwAMR);
            end
        end
    end
    if any(plot_specific_temp_at_diff_fields_for_zfAMR_or_fcAMR == ["fcAMR","both"]) && ~zfc_fwAMR
        for ti = 1:numel(temp_values)
            plot_fcAMR(resistivity_cooling_deviation_percent_tables, ...
                unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, ...
                ti, temp_values(ti), Normalize_to_local, excluded_fields, ...
                plan_measured_str, fontsize, linewidth, merge_labels(plotChannels, labels), zfc_fwAMR);
        end
        if polar_plots
            for ti = 1:numel(temp_values)
                plot_fcAMR_polar(resistivity_cooling_deviation_percent_tables, ...
                    unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, ...
                    ti, temp_values(ti), Normalize_to_local, excluded_fields, ...
                    plan_measured_str, fontsize, linewidth, merge_labels(plotChannels, labels), zfc_fwAMR);
            end
        end
    end
end

zfAMR_string = 'zfAMR'; fcAMR_string = 'fcAMR';
if zfc_fwAMR, zfAMR_string = 'fwAMR'; fcAMR_string = 'zfcAMR'; end

if ~strcmp(plot_specific_field_at_diff_temp_for_zfAMR_or_fcAMR,"non")
    if any(plot_specific_field_at_diff_temp_for_zfAMR_or_fcAMR == ["zfAMR","both"])
        plot_field_vs_temp( ...
            resistivity_warming_deviation_percent_tables, ...
            unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, ...
            plot_specific_field_vector, temp_values, Normalize_to_local, excluded_fields, ...
            plan_measured_str, fontsize, linewidth, ...
            merge_labels(plotChannels, labels), zfAMR_string, polar_plots, ...
            [], [], temp_values, legendThreshold);
    end
    if any(plot_specific_field_at_diff_temp_for_zfAMR_or_fcAMR == ["fcAMR","both"]) && ~zfc_fwAMR
        plot_field_vs_temp( ...
            resistivity_cooling_deviation_percent_tables, ...
            unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, ...
            plot_specific_field_vector, temp_values, Normalize_to_local, excluded_fields, ...
            plan_measured_str, fontsize, linewidth, ...
            merge_labels(plotChannels, labels), fcAMR_string, polar_plots, ...
            [], [], temp_values, legendThreshold);
    end
end

if Plot_deltaR_for_specific_angle_at_diff_field_at_diff_temp
    plot_R_vs_temp_field_at_angle( ...
        plot_specific_angles_for_deltaR_phaseMap, resistivity_warming_deviation_percent_tables, ...
        unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, ...
        plot_specific_field_vector, temp_values, Normalize_to_local, plan_measured_str, ...
        fontsize, linewidth, merge_labels(plotChannels, labels), zfAMR_string, 'PlotOnlyXX', true);
    if ~zfc_fwAMR
        plot_R_vs_temp_field_at_angle( ...
            plot_specific_angles_for_deltaR_phaseMap, resistivity_cooling_deviation_percent_tables, ...
            unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, ...
            plot_specific_field_vector, temp_values, Normalize_to_local, plan_measured_str, ...
            fontsize, linewidth, merge_labels(plotChannels, labels), fcAMR_string, 'PlotOnlyXX', true);
    end
end
%% ===========================
%  SYMMETRY / FOURIER ANALYSIS
% ===========================

% ---- Resolve selected field indices (ONCE) ----
if isempty(selectedFields_T)
    pickedFieldIdx = [];
else
    tol = 1e-3;  % Tesla tolerance
    pickedFieldIdx = find( ...
        arrayfun(@(b) any(abs(b - selectedFields_T) < tol), ...
        rounded_unique_field_max_values) );
end

%% --------- Run symmetry Fourier (amplitude + phase) ---------
if doSymmetryAnalysis

    symOpts.pickFieldIdx = pickedFieldIdx;   % propagate selection

    switch symMode
        case 'zf'
            symResults.zf = analyze_AMR_symmetry( ...
                resistivity_warming_deviation_percent_tables, ...
                unique_rounded_smoothed_angle_deg, ...
                rounded_unique_field_max_values, ...
                temp_values, ...
                symChannels, ...
                symOpts, ...
                'zf');

        case 'fc'
            symResults.fc = analyze_AMR_symmetry( ...
                resistivity_cooling_deviation_percent_tables, ...
                unique_rounded_smoothed_angle_deg, ...
                rounded_unique_field_max_values, ...
                temp_values, ...
                symChannels, ...
                symOpts, ...
                'fc');

        case 'both'
            symResults.zf = analyze_AMR_symmetry( ...
                resistivity_warming_deviation_percent_tables, ...
                unique_rounded_smoothed_angle_deg, ...
                rounded_unique_field_max_values, ...
                temp_values, ...
                symChannels, ...
                symOpts, ...
                'zf');

            symResults.fc = analyze_AMR_symmetry( ...
                resistivity_cooling_deviation_percent_tables, ...
                unique_rounded_smoothed_angle_deg, ...
                rounded_unique_field_max_values, ...
                temp_values, ...
                symChannels, ...
                symOpts, ...
                'fc');
    end
end


%% ===========================
%  HARMONIC LOCKING PLOTS
% ===========================
if doSymmetryAnalysis && exist('fourierPhys','var') && ...
        isfield(fourierPhys,'show') && ...
        isfield(fourierPhys.show,'locking') && ...
        fourierPhys.show.locking

    switch symMode
        case 'zf'
            plot_harmonic_locking(symResults.zf, fourierPhys);

        case 'fc'
            plot_harmonic_locking(symResults.fc, fourierPhys);

        case 'both'
            plot_harmonic_locking(symResults.zf, fourierPhys);
            plot_harmonic_locking(symResults.fc, fourierPhys);
    end
end

%% ===========================
%  FINAL FORMATTING
% ===========================
if formatFigures
    formatAllFigures('pos',[0.1,0.1,0.7,0.6], ...
        'clearTitles',false, ...
        'showLegend',false, ...
        'showGrid',true, ...
        'callerName','zfAMR_main');
end
