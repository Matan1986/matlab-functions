% Resistivity_main.m
% Transport (ρ/R) vs Temperature using TEX interpreter

close_all_except_ui_figures; clc; clear;

%% ===========================
%  PATHS
% ===========================
baseFolder = 'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Matlab functions';
addpath(genpath(baseFolder));

%% ===========================
%  USER PARAMETERS
% ===========================
import_data   = true;
dir       = "L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG119 FIB2 transport and out of plane rotator\First cooling 1";
filename_ending = "MG_119_Outof_plan_rotator_CoxTaS2_Vxy1_Vxx2_Ixx_0p1mAmp_f_277p77Hz_Cooling_0T";

force_manual_preset = false;
manual_preset_name  = '1xy_2xx_3xx';
channel_sign_vec    = [1 1 1 1];

quantity_type       = 'resistivity';
run_analysis        = true;
analysis_channel_id = 'ch2';

lineWidth = 2;
fontSize  = 20;

TH               = 50;
TL               = 4;
delta_T          = 0.1;
smoothing_window = 30;
edge_ignore_range= 2000;
sgolay_order     = 7;
sgolay_frame_len = 401;
forced_log_fit   = false;
twoTCs           = false;

force_plane_str = "";

force_TC_by_growth = true;

compute_derivatives = true;
plot_derivatives = struct( ...
    'raw', false, ...
    'first', true, ...
    'second', true ...
);

derivative_plot_mode = 'separate';
% options:
% 'separate' -> new figures
% 'overlay'  -> same axes

%% ===========================
%  FILTER CONTROL
% ===========================
Unfiltered      = true;
ShowFilterDebug = false;

%% ===========================
%  METADATA
% ===========================
preset_name = resolve_preset(filename_ending, force_manual_preset, manual_preset_name);

[plan_measured, plan_measured_strings] = extract_plane_mode(dir, filename_ending, NaN);
plan_measured_str = choose_plane(plan_measured_strings, plan_measured);
if strlength(force_plane_str) > 0
    plan_measured_str = string(force_plane_str);
end

I = extract_current_I(dir, filename_ending, NaN);
[growth_num, FIB_num] = extract_growth_FIB(dir, filename_ending);
Scaling_factor = getScalingFactor(growth_num, FIB_num);

%% ===========================
%  FORCE TC BY GROWTH
% ===========================
TC_used = NaN;
if force_TC_by_growth
    TC_map = containers.Map({'119','131'}, [33.5, 27]);
    if ~isnan(growth_num)
        key = string(growth_num);
        if TC_map.isKey(key)
            TC_used = TC_map(key);
            fprintf('Forced TC = %.2f K based on growth MG %s\n', TC_used, key);
        end
    end
end

%% ===========================
%  IMPORT RAW
% ===========================
files = builtin('dir', fullfile(char(dir), char(filename_ending + ".*")));

if isempty(files)
    error("File not found: %s (no matching extension)", filename_ending);
end

% If multiple matches exist, take the first one
filename = fullfile(char(dir), files(1).name);

[~, ~, TemperatureK, ~, ...
    LI1_XV, ~, LI2_XV, ~, LI3_XV, ~, LI4_XV, ~] = read_data(filename);

%% ===========================
%  PRESET → BUILD → FILTER
% ===========================
LI_XV = {LI1_XV, LI2_XV, LI3_XV, LI4_XV};
LI_XV = apply_channel_signs_by_preset(preset_name, channel_sign_vec, LI_XV);

[chMap, plotChannels, labels, ~] = select_preset(preset_name);
chans_all = build_channels(chMap, LI_XV, I, Scaling_factor);
chans_all = filter_channels(chans_all, [], [], TemperatureK);
filtered_temp = chans_all.filtered_temp;

%% ===========================
% ENABLED CHANNELS
% ===========================
enabledKeys = {};
fns = fieldnames(plotChannels);

for k = 1:numel(fns)
    val = plotChannels.(fns{k});

    isEnabled = false;

    if islogical(val)
        isEnabled = val;
    elseif isnumeric(val)
        isEnabled = any(val ~= 0);
    elseif isstruct(val)
        subVals = struct2cell(val);
        isEnabled = any(cellfun(@(x) ...
            (islogical(x) && x) || (isnumeric(x) && any(x~=0)), subVals));
    end

    if isEnabled
        enabledKeys{end+1} = fns{k}; %#ok<SAGROW>
    end
end

%% ===========================
%  LABEL BASICS
% ===========================
unit_text      = '(\mu\Omega\cdot cm)';
default_lab    = 'ρ';
quantity_label = 'Resistivity';

%% ===========================
%  PLOT EACH CHANNEL
% ===========================
for ii = 1:numel(enabledKeys)

    key = enabledKeys{ii};
    y_raw = chans_all.(key);

    if ~Unfiltered
        y_raw = clean_resistivity_curve_auto(filtered_temp, y_raw, ShowFilterDebug);
    end

    % ---- META RAW ----
    ylab_raw = default_lab;
    if isfield(labels, key)
        ylab_raw = labels.(key);
    end

    if isnan(FIB_num)
        figNameStr = sprintf('%s, MG %d, %s, %s', ...
            quantity_label, growth_num, plan_measured_str, ylab_raw);
    else
        figNameStr = sprintf('%s, MG %d, FIB %d, %s, %s', ...
            quantity_label, growth_num, FIB_num, plan_measured_str, ylab_raw);
    end

    % -------- DISPLAY (cleaned) --------
    ylab_disp = cleanChannelLabel(ylab_raw);
    ylab_disp = regexprep(string(ylab_disp), '_$', '');
    ylab_disp = char(ylab_disp);

    % force proper LaTeX rho (only if rho symbol exists)
    ylab_disp = strrep(ylab_disp, 'ρ', '\rho');
    ylab_full = ['$\mathrm{' ylab_disp '\ (\mu\Omega\cdot cm)}$'];

    % ---- FIGURE ----
    fig = figure('Name', figNameStr, 'Color','w');
    ax  = axes(fig); hold(ax,'on');

    plot(ax, filtered_temp, y_raw, '.-', 'LineWidth', lineWidth);

    % labels in LaTeX
    xlabel(ax,'Temperature (K)','Interpreter','latex','FontSize',fontSize);
    ylabel(ax,ylab_full,'Interpreter','latex','FontSize',fontSize);

    % IMPORTANT: let MATLAB manage tick locations & text
    ax.TickLabelInterpreter = 'tex';
    ax.FontSize = fontSize - 2;
    ax.TickDir = 'out';
    ax.Layer   = 'top';

    grid(ax,'on');

    % Enforce LaTeX everywhere (like switching)
    if exist('forceLatexFigure','file') == 2
        forceLatexFigure(fig);
    end
end

%% ===========================
%  ANALYSIS FIGURE (FIG 4)
% ===========================
if run_analysis && ismember(analysis_channel_id, enabledKeys)

    key = analysis_channel_id;
    y_raw = chans_all.(key);

    if ~Unfiltered
        y_raw = clean_resistivity_curve_auto(filtered_temp, y_raw, false);
    end

    [sm, fit_y, TC_idx, ~, rhoTH, maxidx, fit_T, p, RRR, drop, dropN, modelStr, dR_dT, d2R_dT2] = ...
        Resistivity_analysis(filtered_temp, y_raw, TH, TL, delta_T, ...
        smoothing_window, edge_ignore_range, sgolay_order, sgolay_frame_len, ...
        forced_log_fit, twoTCs);

    if ~isnan(TC_used)
        [~, TC_idx] = min(abs(filtered_temp - TC_used));
    end

    ylab_raw = default_lab;
    if isfield(labels, key)
        ylab_raw = labels.(key);
    end

    if isnan(FIB_num)
        figNameStr = sprintf('%s, MG %d, %s, %s', ...
            quantity_label, growth_num, plan_measured_str, ylab_raw);
    else
        figNameStr = sprintf('%s, MG %d, FIB %d, %s, %s', ...
            quantity_label, growth_num, FIB_num, plan_measured_str, ylab_raw);
    end

    % force proper LaTeX rho (only if rho symbol exists)
    ylab_disp = strrep(ylab_disp, 'ρ', '\rho');

    % UPRIGHT journal-style Y label
    ylab_full = ['$\mathrm{' ylab_disp '\ (\mu\Omega\cdot cm)}$'];

    ylabel(ax, ylab_full, 'Interpreter','latex','FontSize',fontSize);

    Resistivity_plot_results( ...
        filtered_temp, y_raw, sm, fit_y, ...
        TC_idx, NaN, maxidx, TH, TL, delta_T, rhoTH, ...
        fit_T, p, RRR, drop, dropN, ylab_full, figNameStr, ...
        false, filename, modelStr);

    build_resistivity_analysis_table( ...
        figNameStr, filtered_temp(TC_idx), RRR, drop, dropN);

    if compute_derivatives
        plot_cfg = plot_derivatives;
        plot_cfg.mode = derivative_plot_mode;
        plot_cfg.TC_index = TC_idx;
        plot_resistivity_derivatives(filtered_temp, sm, dR_dT, d2R_dT2, ...
            plot_cfg, figNameStr, fontSize);
    end
end

function plot_resistivity_derivatives(T, R, dR_dT, d2R_dT2, plot_config, figNameStr, fontSize)
% Plot resistivity and selected derivatives in separate or overlay mode.

if ~isfield(plot_config, 'raw'), plot_config.raw = false; end
if ~isfield(plot_config, 'first'), plot_config.first = false; end
if ~isfield(plot_config, 'second'), plot_config.second = false; end
if ~isfield(plot_config, 'mode'), plot_config.mode = 'separate'; end

show_raw = plot_config.raw;
show_first = plot_config.first;
show_second = plot_config.second;
mode_str = lower(string(plot_config.mode));

TC_index = NaN;
if isfield(plot_config, 'TC_index')
    TC_index = plot_config.TC_index;
end

if ~(show_raw || show_first || show_second)
    return;
end

lw = 1.8;

if mode_str == "overlay"
    fig = figure('Name', [figNameStr ' - Derivatives'], 'Color', 'w');
    ax = axes(fig); hold(ax, 'on');

    if show_raw
        plot(ax, T, R, '-', 'LineWidth', lw, 'DisplayName', '$\rho(T)$');
    end
    if show_first
        plot(ax, T, dR_dT, '-', 'LineWidth', lw, 'DisplayName', '$\frac{d\rho}{dT}$');
    end
    if show_second
        plot(ax, T, d2R_dT2, '-', 'LineWidth', lw, 'DisplayName', '$\frac{d^2\rho}{dT^2}$');
    end

    if ~isnan(TC_index) && TC_index >= 1 && TC_index <= numel(T)
        xline(ax, T(TC_index), '--');
    end

    xlabel(ax, 'Temperature (K)', 'Interpreter', 'latex', 'FontSize', fontSize);
    ylabel(ax, '$\rho,\ \frac{d\rho}{dT},\ \frac{d^2\rho}{dT^2}$', ...
        'Interpreter', 'latex', 'FontSize', fontSize);
    ax.TickLabelInterpreter = 'latex';
    ax.FontSize = fontSize - 2;
    grid(ax, 'on');
    legend(ax, 'Interpreter', 'latex', 'Location', 'best');
    return;
end

if show_raw
    fig = figure('Name', [figNameStr ' - Raw'], 'Color', 'w');
    ax = axes(fig); hold(ax, 'on');
    plot(ax, T, R, '-', 'LineWidth', lw);
    if ~isnan(TC_index) && TC_index >= 1 && TC_index <= numel(T)
        xline(ax, T(TC_index), '--');
    end
    xlabel(ax, 'Temperature (K)', 'Interpreter', 'latex', 'FontSize', fontSize);
    ylabel(ax, '$\rho\ (\mu\Omega\cdot cm)$', 'Interpreter', 'latex', 'FontSize', fontSize);
    ax.TickLabelInterpreter = 'latex';
    ax.FontSize = fontSize - 2;
    grid(ax, 'on');
end

if show_first
    fig = figure('Name', [figNameStr ' - First Derivative'], 'Color', 'w');
    ax = axes(fig); hold(ax, 'on');
    plot(ax, T, dR_dT, '-', 'LineWidth', lw);
    if ~isnan(TC_index) && TC_index >= 1 && TC_index <= numel(T)
        xline(ax, T(TC_index), '--');
    end
    xlabel(ax, 'Temperature (K)', 'Interpreter', 'latex', 'FontSize', fontSize);
    ylabel(ax, '$\frac{d\rho}{dT}$', 'Interpreter', 'latex', 'FontSize', fontSize);
    ax.TickLabelInterpreter = 'latex';
    ax.FontSize = fontSize - 2;
    grid(ax, 'on');
end

if show_second
    fig = figure('Name', [figNameStr ' - Second Derivative'], 'Color', 'w');
    ax = axes(fig); hold(ax, 'on');
    plot(ax, T, d2R_dT2, '-', 'LineWidth', lw);
    if ~isnan(TC_index) && TC_index >= 1 && TC_index <= numel(T)
        xline(ax, T(TC_index), '--');
    end
    xlabel(ax, 'Temperature (K)', 'Interpreter', 'latex', 'FontSize', fontSize);
    ylabel(ax, '$\frac{d^2\rho}{dT^2}$', 'Interpreter', 'latex', 'FontSize', fontSize);
    ax.TickLabelInterpreter = 'latex';
    ax.FontSize = fontSize - 2;
    grid(ax, 'on');
end
end
