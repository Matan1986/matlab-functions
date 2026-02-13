%% PS_dynamic_channels_dynamic_auto.m — Median + smoothing + outlier removal + post-normalization filtering + RAW MODE
close all; clearvars; clc;

baseFolder = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions';
addpath(genpath(baseFolder));

%% ====================== 1) GLOBAL MODE SWITCHES ======================
Unfiltered = false;     % <---- RAW MODE BUTTON

%% ====================== 2) User Parameters ======================
dir      = "C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 131\MG131 FIB10 In Plan Rotator zfAMR\PS diff temp 3";
filename_dat = "MG_131_CoxTaS2_Vxy1_Vxx2_Vxy3_Vxx4_Ixx_0p1mAmp_f_277p77Hz_PS_diff_temps_4_12_20_28_36K_diff_fields_3_7_11_14T";

force_manual_preset = false;
manual_preset_name  = '2xx_3xy_4xx';

normalizeData = true;
subtractMean  = true;

forced_max_angle = NaN;
TEMP_TOL  = 0.08;
FIELD_TOL = 0.05;

%% ----- Pre-normalization median & smoothing -----
DoMedianFilter    = true;
MedianWindow      = 3;
DoSmoothing       = true;
SmoothMethod      = 'movmean';
SmoothWindow      = 3;

%% ----- Remove spikes BEFORE filtering -----
RemoveOutliers   = false;     
OutlierPercent   = 700;      

%% ----- Remove spikes AFTER normalization (NEW) -----
ApplyPostOutlierFilter   = true;  
PostOutlierJumpPercent   = 700;   
PostOutlierMedianFactor  = 12;     

%% ----- Plot formatting -----
MakePolarPlots = false;
DoFormat  = true;
FormatArgs = {[0.1,0.1,0.7,0.6], 20, 20, 2.5, false, true, true};

%% ====================== RAW MODE OVERRIDE ======================
if Unfiltered
    fprintf('*** RAW MODE ENABLED — all filtering OFF ***\n');
    RemoveOutliers         = false;
    DoMedianFilter         = false;
    DoSmoothing            = false;
    ApplyPostOutlierFilter = false;
    
    % אם רוצים RAW מוחלט בלי נרמול:
    % normalizeData = false;
    % subtractMean  = false;
end

%% ====================== 3) Metadata ======================
[plan_measured, plan_measured_strings] = extract_plane_mode(dir, filename_dat, NaN);
base_max_angle = extract_base_max_angle(filename_dat, forced_max_angle);
[growth_num, FIB_num] = extract_growth_FIB(dir, filename_dat);
I = extract_current_I(dir, filename_dat, NaN);
Scaling_factor = getScalingFactor(growth_num, FIB_num);

[preset_name] = resolve_preset(filename_dat, force_manual_preset, manual_preset_name);
[chMap, plotChannels, labels, Normalize_to] = select_preset(preset_name);

[temp_values, field_values] = parse_TB_from_filename(filename_dat);

%% ====================== 4) Load data ======================
fullpath = fullfile(dir, filename_dat + ".dat");
[Timems, FieldT, TempK, AngleDeg, ...
 LI1_XV, ~, LI2_XV, ~, LI3_XV, ~, LI4_XV, ~] = read_data(fullpath);
LI_XV = {LI1_XV, LI2_XV, LI3_XV, LI4_XV};

%% ====================== 5) Build channels ======================
chans_raw = build_channels(chMap, LI_XV, I, Scaling_factor);

%% ====================== 6) Pre-normalization filtering ======================
chans_smooth = struct();
angle = AngleDeg(:);

for k = 1:4
    key = sprintf('ch%d', k);
    if ~isfield(chans_raw, key)
        continue;
    end

    Y = chans_raw.(key)(:);

    % ---- pre-outlier removal ----
    if RemoveOutliers
        muY = nanmean(Y);
        thr = abs(muY) * (OutlierPercent / 100);
        Y = remove_outliers(Y, thr);
    end

    % ---- median filter ----
    if DoMedianFilter
        Y = medfilt1(Y, MedianWindow, 'omitnan', 'truncate');
    end

    % ---- smoothing ----
    if DoSmoothing
        switch lower(SmoothMethod)
            case 'movmean'
                Y = movmean(Y, SmoothWindow, 'omitnan');
            case 'sgolay'
                Y = sgolayfilt(Y, 3, SmoothWindow);
        end
    end

    chans_smooth.(key) = Y;
end

%% ====================== 7) Plotting ======================
figs = plot_T_by_B( ...
    temp_values, field_values, ...
    FieldT, TempK, AngleDeg, ...
    chans_raw, chans_smooth, ...
    labels, plotChannels, Normalize_to, ...
    plan_measured_strings, ...   % <--- העבר כארגומנט רגיל, לא כ-Name/Value
    'NormalizeData',      normalizeData, ...
    'SubtractMean',       subtractMean, ...
    'TempTol',            TEMP_TOL, ...
    'FieldTol',           FIELD_TOL, ...
    'MakePolar',          MakePolarPlots, ...
    'ApplyPostOutlierFilter',   ApplyPostOutlierFilter, ...
    'PostOutlierJumpPercent',   PostOutlierJumpPercent, ...
    'PostOutlierMedianFactor',  PostOutlierMedianFactor, ...
    'FinalSmoothWindow',  11 ...    % <--- מחליף את wFinal
);


%% ====================== 8) Format ======================
if DoFormat
   formatAllFigures(FormatArgs{:});
end
