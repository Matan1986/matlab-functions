%% Transport_FieldSweep_auto.m — Automatic channels (raw or filtered)

clc;
% clear;
close_all_except_ui_figures;

%% 1) Paths
baseFolder = 'C:\Dev\matlab-functions';
addpath(genpath(baseFolder));

%% 2) User Parameters
dir      = "C:\Users\User\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG119_FIB4_Switching\Field Sweep 13";
filename_end = "MG_119_FIB4_CoxTaS2_Vxy1_Vxx2_Vxx3_Ixx_0p1mAmp_f_277p77Hz_FS_9Tto-9T_Different_temp_2K_to_42K_at_4K_steps";
filename     = fullfile(dir, filename_end);

force_manual_preset = false;
manual_preset_name  = '2xx_3xy_4xx';

Resistivity    = true;
center_graphs  = true;
vertical_shift = false;
shift_amount   = 0;
symmetrization = false;

%% *** NEW FLAG ***
Unfiltered = false;       % TRUE = use raw channels, FALSE = filtered channels

%% --- Filtering ---
DoMedianFilter = true;
MedianWindow   = 7;
DoSmoothing    = true;
SmoothMethod   = 'sgolay';
SmoothWindow   = 11;
IgnoreDirection = true;
JumpThreshold   = 0.6;

%% --- Plot styling ---
line_width = 2.5;
font_size  = 20;
show_legend = true;
DoFormatFirst  = true;
FormatArgs = {[0.1,0.1,0.7,0.6], 20, 20, 2.5, false, true, true};

%% ===========================
%  METADATA
%  ===========================
[growth_num, FIB_num] = extract_growth_FIB(dir, filename_end);
I = extract_current_I(dir, filename_end, NaN);
Scaling_factor = getScalingFactor(growth_num, FIB_num);

[preset_name] = resolve_preset(filename_end, force_manual_preset, manual_preset_name);
[chMap, plotChannels, labels, Normalize_to] = select_preset(preset_name);

[plan_measured, plan_strings] = extract_plane_mode(dir, filename_end, NaN);
plan_str = choose_plane(plan_strings, plan_measured);

[temp_values, field_values] = parse_TB_from_FS_filename(filename_end);
Bstart = field_values(1); Bend = field_values(2);

if Resistivity
    yUnit = ' [10^{-6}Ω·cm]';
else
    yUnit = ' [mΩ]';
end

if isnan(FIB_num)
    strtitle = sprintf('MG %d, %s', growth_num, plan_str);
else
    strtitle = sprintf('MG %d FIB%d, %s', growth_num, FIB_num, plan_str);
end

%% ===========================
%  LOAD DATA
%  ===========================
[~,FieldT,TempK,~,LI1_XV,~,LI2_XV,~,LI3_XV,~,LI4_XV,~] = read_data(filename);
LI_XV = {LI1_XV, LI2_XV, LI3_XV, LI4_XV};

%% ===========================
%  BUILD RAW CHANNELS
%  ===========================
chans_raw = build_channels(chMap, LI_XV, I, Scaling_factor);

%% ===========================
%  FILTERED CHANNELS
%  ===========================
chans_smooth = apply_median_and_smooth_per_sweep(chans_raw, FieldT, ...
    'DoMedian', DoMedianFilter, 'MedianWindow', MedianWindow, ...
    'DoSmooth', DoSmoothing, 'SmoothMethod', SmoothMethod, ...
    'SmoothWindow', SmoothWindow, ...
    'IgnoreDirection', IgnoreDirection, ...
    'JumpThreshold', JumpThreshold);

%% ===========================
%  FINAL CHANNEL SELECTION (NEW)
%  ===========================
if Unfiltered
    chans_final = chans_raw;      % RAW DATA
    disp('>>> Using RAW unfiltered data');
else
    chans_final = chans_smooth;   % FILTERED DATA
    disp('>>> Using FILTERED data');
end

%% ===========================
%  TEMPERATURE GROUPS
%  ===========================
Tunique = temp_values;
Ntemps  = numel(Tunique);

if Ntemps < 5
    colors = [];        % MATLAB auto colors
else
    colors = parula(Ntemps);
end

%% ===========================
%  PLOTTING
%  ===========================
set(0,'DefaultAxesFontSize',font_size);
enabledKeys = {};
fns = fieldnames(plotChannels);
for k = 1:numel(fns)
    fk = fns{k};
    if islogical(plotChannels.(fk)) && plotChannels.(fk)
        enabledKeys{end+1} = fk;
    end
end

for iCh = 1:numel(enabledKeys)
    key = enabledKeys{iCh};
    if ~isfield(chans_final,key), continue; end

    label_str = key;
    if isfield(labels, key) && ~isempty(labels.(key))
        label_str = labels.(key);
    end
    label_str = replace(label_str, 'rho_', 'ρ_');

    fig = figure('Name', sprintf('%s, %s', strtitle, label_str));
    ax = axes(fig); hold(ax,'on');

    for j = 1:Ntemps
        idx = abs(TempK - Tunique(j)) < 0.15;
        if ~any(idx), continue; end

        x = FieldT(idx);
        y = chans_final.(key)(idx);

        good = isfinite(x) & isfinite(y);
        x = x(good);
        y = y(good);
        if isempty(x), continue; end

        if center_graphs
            y = y - 0.5*(max(y)+min(y));
        end
        if vertical_shift
            y = y + (j-1)*shift_amount;
        end

        if isempty(colors)
            plot(ax, x, y, 'LineWidth', line_width, ...
                'DisplayName', sprintf('%.0f[K]', Tunique(j)));
        else
            plot(ax, x, y, 'LineWidth', line_width, ...
                'Color', colors(j,:), ...
                'DisplayName', sprintf('%.0f[K]', Tunique(j)));
        end
    end

    xlabel(ax, 'Field [T]');
    ylabel(ax, sprintf('%s%s', label_str, yUnit));
    xlim(ax,[Bstart,Bend]);

    % ===== NEW: nicer X-axis ticks =====
    try
        % אם זה בערך -5 עד 5 נעשה טיקים של 1T
        rangeB = Bend - Bstart;
        if abs(Bstart) == abs(Bend) && mod(Bstart,1)==0 && mod(Bend,1)==0 && rangeB <= 14
            xTicks = Bstart:1:Bend;
        else
            % ברירת מחדל: 9 טיקים ליניאריים
            xTicks = linspace(Bstart,Bend,9);
        end
        set(ax,'XTick',xTicks);
    catch
        % אם משהו נדפק, לא מפילים את הסקריפט
    end
    % ===== END NEW =====

    title(ax, sprintf('%s, %s', strtitle, label_str));
    if show_legend, legend(ax,'show','Location','best'); end
    grid(ax,'on'); box(ax,'on');
end

if DoFormatFirst
    formatAllFigures(FormatArgs{:}, 'callerName','FieldSweep_main');
end
