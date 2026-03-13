function repair_info = apply_fig_style_repair(fig)
% apply_fig_style_repair Apply safe publication-style repairs to a figure.

if nargin < 1 || isempty(fig) || ~ishandle(fig)
    error('apply_fig_style_repair:InvalidHandle', 'A valid figure handle is required.');
end

fig = resolve_figure_handle(fig);
ensure_visualization_helpers_on_path();
font_name = resolve_publication_font();
protected_state = capture_protected_state(fig);

repair_info = struct();
repair_info.actions = {};
repair_info.style_changed = false;
repair_info.layout_changed = false;

if exist('apply_publication_style', 'file') == 2
    apply_publication_style(fig);
    repair_info = record_action(repair_info, 'publication_style_overlay', 'style');
end

[fig, size_changed] = normalize_figure_size(fig);
if size_changed
    repair_info = record_action(repair_info, 'figure_size_normalized', 'layout');
end

set(fig, 'Color', 'w', 'InvertHardcopy', 'off');

axes_handles = findall(fig, 'Type', 'axes');
for k = 1:numel(axes_handles)
    ax = axes_handles(k);
    tag = safe_char(get_property(ax, 'Tag'));
    if strcmpi(tag, 'legend') || strcmpi(tag, 'colorbar')
        continue;
    end

    if maybe_set(ax, 'FontName', font_name)
        repair_info = record_action(repair_info, 'axes_font_normalized', 'style');
    end
    if maybe_set_floor(ax, 'FontSize', 8)
        repair_info = record_action(repair_info, 'axes_font_size_enforced', 'style');
    end
    if maybe_set_floor(ax, 'LineWidth', 1)
        repair_info = record_action(repair_info, 'axes_line_width_enforced', 'style');
    end
    if maybe_set(ax, 'TickDir', 'out')
        repair_info = record_action(repair_info, 'axes_tick_direction_enforced', 'style');
    end
    if maybe_set(ax, 'Layer', 'top')
        repair_info = record_action(repair_info, 'axes_layer_normalized', 'style');
    end

    if style_text_handle(get_property(ax, 'XLabel'), font_name, 9)
        repair_info = record_action(repair_info, 'label_interpreter_normalized', 'style');
    end
    if style_text_handle(get_property(ax, 'YLabel'), font_name, 9)
        repair_info = record_action(repair_info, 'label_interpreter_normalized', 'style');
    end
    if style_text_handle(get_property(ax, 'ZLabel'), font_name, 9)
        repair_info = record_action(repair_info, 'label_interpreter_normalized', 'style');
    end
    if style_text_handle(get_property(ax, 'Title'), font_name, 9)
        repair_info = record_action(repair_info, 'title_typography_normalized', 'style');
    end

    line_handles = findall(ax, 'Type', 'line');
    for j = 1:numel(line_handles)
        if maybe_set_floor(line_handles(j), 'LineWidth', 2)
            repair_info = record_action(repair_info, 'data_line_width_enforced', 'style');
        end
        if maybe_set_floor(line_handles(j), 'MarkerSize', 5)
            repair_info = record_action(repair_info, 'marker_size_enforced', 'style');
        end
    end

    scatter_handles = findall(ax);
    for j = 1:numel(scatter_handles)
        obj = scatter_handles(j);
        if is_scatter_object(obj) && maybe_set_floor(obj, 'LineWidth', 1)
            repair_info = record_action(repair_info, 'scatter_line_width_enforced', 'style');
        end
    end
end

legend_handles = findall(fig, 'Type', 'Legend');
for k = 1:numel(legend_handles)
    lgd = legend_handles(k);
    if maybe_set(lgd, 'FontName', font_name)
        repair_info = record_action(repair_info, 'legend_font_normalized', 'style');
    end
    if maybe_set_floor(lgd, 'FontSize', 8)
        repair_info = record_action(repair_info, 'legend_font_size_enforced', 'style');
    end
    if maybe_set(lgd, 'Interpreter', 'tex')
        repair_info = record_action(repair_info, 'legend_interpreter_normalized', 'style');
    end
    if maybe_set(lgd, 'Box', 'off')
        repair_info = record_action(repair_info, 'legend_box_removed', 'style');
    end
end

colorbars = findall(fig, 'Type', 'ColorBar');
for k = 1:numel(colorbars)
    cb = colorbars(k);
    if maybe_set(cb, 'FontName', font_name)
        repair_info = record_action(repair_info, 'colorbar_font_normalized', 'style');
    end
    if maybe_set_floor(cb, 'FontSize', 8)
        repair_info = record_action(repair_info, 'colorbar_font_size_enforced', 'style');
    end
    if maybe_set(cb, 'TickLabelInterpreter', 'tex')
        repair_info = record_action(repair_info, 'colorbar_interpreter_normalized', 'style');
    end
    label_handle = get_property(cb, 'Label');
    if style_text_handle(label_handle, font_name, 9)
        repair_info = record_action(repair_info, 'colorbar_label_normalized', 'style');
    end
end

restore_protected_state(protected_state);
repair_info.actions = unique(repair_info.actions, 'stable');
end

function fig = resolve_figure_handle(handle_in)
if strcmpi(get(handle_in, 'Type'), 'figure')
    fig = handle_in;
    return;
end
fig = ancestor(handle_in, 'figure');
if isempty(fig) || ~ishandle(fig)
    error('apply_fig_style_repair:InvalidHandle', 'A valid figure handle is required.');
end
end

function ensure_visualization_helpers_on_path()
this_file = mfilename('fullpath');
repair_dir = fileparts(this_file);
tools_dir = fileparts(repair_dir);
figures_dir = fullfile(tools_dir, 'figures');
if exist(figures_dir, 'dir') == 7 && isempty(strfind(path, figures_dir))
    addpath(figures_dir);
end
end

function state = capture_protected_state(fig)
state = repmat(struct('handle', [], 'xlim', [], 'ylim', [], 'zlim', [], 'clim', [], 'xscale', '', 'yscale', '', 'zscale', '', 'xdir', '', 'ydir', ''), 0, 1);
axes_handles = findall(fig, 'Type', 'axes');
for k = 1:numel(axes_handles)
    ax = axes_handles(k);
    tag = safe_char(get_property(ax, 'Tag'));
    if strcmpi(tag, 'legend') || strcmpi(tag, 'colorbar')
        continue;
    end
    item = struct();
    item.handle = ax;
    item.xlim = safe_numeric(get_property(ax, 'XLim'));
    item.ylim = safe_numeric(get_property(ax, 'YLim'));
    item.zlim = safe_numeric(get_property(ax, 'ZLim'));
    item.clim = safe_numeric(get_property(ax, 'CLim'));
    item.xscale = safe_char(get_property(ax, 'XScale'));
    item.yscale = safe_char(get_property(ax, 'YScale'));
    item.zscale = safe_char(get_property(ax, 'ZScale'));
    item.xdir = safe_char(get_property(ax, 'XDir'));
    item.ydir = safe_char(get_property(ax, 'YDir'));
    state(end + 1, 1) = item; %#ok<AGROW>
end
end

function restore_protected_state(state)
for k = 1:numel(state)
    ax = state(k).handle;
    if isempty(ax) || ~ishandle(ax)
        continue;
    end
    try, set(ax, 'XScale', state(k).xscale); catch, end
    try, set(ax, 'YScale', state(k).yscale); catch, end
    try, set(ax, 'ZScale', state(k).zscale); catch, end
    try, set(ax, 'XDir', state(k).xdir); catch, end
    try, set(ax, 'YDir', state(k).ydir); catch, end
    try, set(ax, 'XLim', state(k).xlim); catch, end
    try, set(ax, 'YLim', state(k).ylim); catch, end
    try, set(ax, 'ZLim', state(k).zlim); catch, end
    try, set(ax, 'CLim', state(k).clim); catch, end
end
end

function [fig, changed] = normalize_figure_size(fig)
changed = false;
set(fig, 'Units', 'centimeters');
pos = safe_numeric(get_property(fig, 'Position'));
if numel(pos) ~= 4 || any(~isfinite(pos)) || any(pos(3:4) <= 0)
    target = [2 2 8.6 6.2];
else
    current_width = pos(3);
    current_height = pos(4);
    if current_width >= 12
        target_width = 17.8;
        min_height = 6.5;
        max_height = 11.5;
        min_ratio = 1.20;
        max_ratio = 1.60;
    else
        target_width = 8.6;
        min_height = 5.5;
        max_height = 7.0;
        min_ratio = 1.25;
        max_ratio = 1.55;
    end
    if current_height <= 0
        ratio = 1.4;
    else
        ratio = current_width / current_height;
    end
    ratio = min(max(ratio, min_ratio), max_ratio);
    target_height = target_width / ratio;
    target_height = min(max(target_height, min_height), max_height);
    target = [pos(1) pos(2) target_width target_height];
end

if ~isequal(round(pos, 6), round(target, 6))
    set(fig, 'Position', target);
    changed = true;
end
set(fig, 'PaperUnits', 'centimeters', ...
    'PaperPosition', [0 0 target(3) target(4)], ...
    'PaperSize', [target(3) target(4)]);
end

function changed = style_text_handle(text_handle, font_name, min_size)
changed = false;
if isempty(text_handle) || ~ishandle(text_handle)
    return;
end
if maybe_set(text_handle, 'FontName', font_name)
    changed = true;
end
if maybe_set_floor(text_handle, 'FontSize', min_size)
    changed = true;
end
if maybe_set(text_handle, 'Interpreter', 'tex')
    changed = true;
end
end

function repair_info = record_action(repair_info, action_name, action_kind)
repair_info.actions{end + 1} = action_name;
switch action_kind
    case 'style'
        repair_info.style_changed = true;
    case 'layout'
        repair_info.layout_changed = true;
end
end

function changed = maybe_set(obj, property_name, target_value)
changed = false;
current_value = get_property(obj, property_name);
if isempty(current_value)
    return;
end
if isequaln(current_value, target_value)
    return;
end
try
    set(obj, property_name, target_value);
    changed = true;
catch
    changed = false;
end
end

function changed = maybe_set_floor(obj, property_name, floor_value)
changed = false;
current_value = safe_numeric(get_property(obj, property_name));
if isempty(current_value)
    return;
end
if current_value >= floor_value
    return;
end
try
    set(obj, property_name, floor_value);
    changed = true;
catch
    changed = false;
end
end

function value = get_property(obj, property_name)
try
    value = get(obj, property_name);
catch
    value = [];
end
end

function value = safe_numeric(value)
if isempty(value)
    return;
end
if islogical(value)
    value = double(value);
    return;
end
if isnumeric(value)
    return;
end
try
    value = double(value);
catch
    value = [];
end
end

function text_value = safe_char(value)
text_value = '';
if isempty(value)
    return;
end
if ischar(value)
    text_value = value;
    return;
end
if isstring(value)
    text_value = char(strjoin(value(:), ' | '));
    return;
end
try
    text_value = char(string(value));
catch
    text_value = '';
end
end

function tf = is_scatter_object(obj)
tf = false;
if ~ishandle(obj)
    return;
end
obj_type = safe_char(get_property(obj, 'Type'));
obj_class = class(obj);
tf = strcmpi(obj_type, 'scatter') || contains(lower(obj_class), 'scatter');
end

function font_name = resolve_publication_font()
font_name = 'Helvetica';
try
    fonts = listfonts;
    if ~any(strcmpi(fonts, font_name)) && any(strcmpi(fonts, 'Arial'))
        font_name = 'Arial';
    end
catch
    font_name = 'Arial';
end
end
