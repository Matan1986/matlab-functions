function info = inspect_fig_contents(fig_source)
% inspect_fig_contents Inspect a FIG file or figure handle without changing data.

[fig, source_path, cleanup_obj] = load_figure_source(fig_source);
if ~isempty(cleanup_obj)
    cleanup_guard = cleanup_obj; %#ok<NASGU>
end

set(fig, 'Visible', 'off');

axes_info = collect_axes(fig);
legend_info = collect_legends(fig);
colorbar_info = collect_colorbars(fig);
annotation_info = collect_annotations(fig);
tiled_layout_info = collect_tiled_layouts(fig);
unsupported_info = collect_unsupported_objects(fig);

summary = struct();
summary.figure_size = get_position_in_units(fig, 'centimeters');
summary.axes_count = numel(axes_info);
summary.line_count = sum(arrayfun(@(x) numel(x.lines), axes_info));
summary.scatter_count = sum(arrayfun(@(x) numel(x.scatters), axes_info));
summary.image_count = sum(arrayfun(@(x) numel(x.images), axes_info));
summary.colorbar_count = numel(colorbar_info);
summary.legend_count = numel(legend_info);
summary.annotation_count = numel(annotation_info);
summary.tiled_layout_count = numel(tiled_layout_info);
summary.unsupported_object_count = numel(unsupported_info);
summary.has_3d_axes = any(arrayfun(@(x) x.has_3d_view, axes_info));
summary.has_multiple_yaxes = any(arrayfun(@(x) x.has_multiple_yaxes, axes_info));
summary.missing_xlabel = any(arrayfun(@(x) isempty(strtrim(x.xlabel.string)), axes_info));
summary.missing_ylabel = any(arrayfun(@(x) isempty(strtrim(x.ylabel.string)), axes_info));
summary.colorbar_labels_missing = any(arrayfun(@(x) isempty(strtrim(x.label.string)), colorbar_info));
summary.hidden_handle_count = count_hidden_handles(fig);

info = struct();
info.source_figure = get_figure_name(source_path, fig);
info.source_path = source_path;
info.figure_units = 'centimeters';
info.figure_size = summary.figure_size;
info.figure_size_cm = summary.figure_size;
info.paper_size_cm = safe_numeric(get_property(fig, 'PaperSize'));
info.paper_position_cm = safe_numeric(get_property(fig, 'PaperPosition'));
info.figure_color = safe_numeric(get_property(fig, 'Color'));
info.figure_colormap = safe_numeric(safe_colormap(fig));
info.axes = axes_info;
info.legends = legend_info;
info.colorbars = colorbar_info;
info.annotations = annotation_info;
info.tiled_layouts = tiled_layout_info;
info.unsupported_objects = unsupported_info;
info.axes_count = summary.axes_count;
info.line_count = summary.line_count;
info.scatter_count = summary.scatter_count;
info.image_count = summary.image_count;
info.colorbar_count = summary.colorbar_count;
info.legend_count = summary.legend_count;
info.annotation_count = summary.annotation_count;
info.tiled_layout_count = summary.tiled_layout_count;
info.summary = summary;
end

function [fig, source_path, cleanup_obj] = load_figure_source(fig_source)
cleanup_obj = [];
source_path = '';
if ischar(fig_source) || (isstring(fig_source) && isscalar(fig_source))
    source_path = char(string(fig_source));
    if exist(source_path, 'file') ~= 2
        error('inspect_fig_contents:SourceMissing', 'FIG file not found: %s', source_path);
    end
    try
        fig = openfig(source_path, 'invisible');
    catch ME
        error('inspect_fig_contents:OpenFailed', 'Failed to open FIG file %s: %s', source_path, ME.message);
    end
    cleanup_obj = onCleanup(@() close_figure_safely(fig));
    return;
end

fig = resolve_figure_handle(fig_source);
end

function fig = resolve_figure_handle(handle_in)
if isempty(handle_in) || ~ishandle(handle_in)
    error('inspect_fig_contents:InvalidHandle', 'A valid figure handle or FIG path is required.');
end
if strcmpi(get(handle_in, 'Type'), 'figure')
    fig = handle_in;
    return;
end
fig = ancestor(handle_in, 'figure');
if isempty(fig) || ~ishandle(fig)
    error('inspect_fig_contents:InvalidHandle', 'A valid figure handle or FIG path is required.');
end
end

function close_figure_safely(fig)
if ~isempty(fig) && ishandle(fig)
    close(fig);
end
end

function axes_info = collect_axes(fig)
axes_info = repmat(empty_axes_info(), 0, 1);
all_axes = findall(fig, 'Type', 'axes');
for k = 1:numel(all_axes)
    ax = all_axes(k);
    tag = safe_char(get_property(ax, 'Tag'));
    if strcmpi(tag, 'legend') || strcmpi(tag, 'colorbar')
        continue;
    end

    item = empty_axes_info();
    item.index = numel(axes_info) + 1;
    item.tag = tag;
    item.class = class(ax);
    item.position = safe_numeric(get_property(ax, 'Position'));
    item.font_name = safe_char(get_property(ax, 'FontName'));
    item.font_size = safe_scalar(get_property(ax, 'FontSize'));
    item.line_width = safe_scalar(get_property(ax, 'LineWidth'));
    item.tick_dir = safe_char(get_property(ax, 'TickDir'));
    item.box = safe_char(get_property(ax, 'Box'));
    item.layer = safe_char(get_property(ax, 'Layer'));
    item.visible = safe_char(get_property(ax, 'Visible'));
    item.xscale = safe_char(get_property(ax, 'XScale'));
    item.yscale = safe_char(get_property(ax, 'YScale'));
    item.zscale = safe_char(get_property(ax, 'ZScale'));
    item.xdir = safe_char(get_property(ax, 'XDir'));
    item.ydir = safe_char(get_property(ax, 'YDir'));
    item.xlim = safe_numeric(get_property(ax, 'XLim'));
    item.ylim = safe_numeric(get_property(ax, 'YLim'));
    item.zlim = safe_numeric(get_property(ax, 'ZLim'));
    item.clim = safe_numeric(get_property(ax, 'CLim'));
    item.title = inspect_text_object(get_property(ax, 'Title'));
    item.xlabel = inspect_text_object(get_property(ax, 'XLabel'));
    item.ylabel = inspect_text_object(get_property(ax, 'YLabel'));
    item.zlabel = inspect_text_object(get_property(ax, 'ZLabel'));
    item.has_multiple_yaxes = detect_multiple_yaxes(ax);
    item.has_3d_view = detect_3d_view(ax);
    item.lines = collect_line_objects(ax);
    item.scatters = collect_scatter_objects(ax);
    item.images = collect_image_objects(ax);
    item.other_primitives = collect_other_primitive_objects(ax);
    item.axis_colormap = safe_numeric(safe_colormap(ax));
    axes_info(end + 1, 1) = item; %#ok<AGROW>
end
end

function item = empty_axes_info()
item = struct( ...
    'index', [], ...
    'tag', '', ...
    'class', '', ...
    'position', [], ...
    'font_name', '', ...
    'font_size', [], ...
    'line_width', [], ...
    'tick_dir', '', ...
    'box', '', ...
    'layer', '', ...
    'visible', '', ...
    'xscale', '', ...
    'yscale', '', ...
    'zscale', '', ...
    'xdir', '', ...
    'ydir', '', ...
    'xlim', [], ...
    'ylim', [], ...
    'zlim', [], ...
    'clim', [], ...
    'title', empty_text_info(), ...
    'xlabel', empty_text_info(), ...
    'ylabel', empty_text_info(), ...
    'zlabel', empty_text_info(), ...
    'has_multiple_yaxes', false, ...
    'has_3d_view', false, ...
    'lines', repmat(empty_line_info(), 0, 1), ...
    'scatters', repmat(empty_scatter_info(), 0, 1), ...
    'images', repmat(empty_image_info(), 0, 1), ...
    'other_primitives', repmat(empty_other_primitive_info(), 0, 1), ...
    'axis_colormap', []);
end

function legends = collect_legends(fig)
legends = repmat(empty_legend_info(), 0, 1);
handles = findall(fig, 'Type', 'Legend');
for k = 1:numel(handles)
    lgd = handles(k);
    item = empty_legend_info();
    item.index = k;
    item.location = safe_char(get_property(lgd, 'Location'));
    item.font_name = safe_char(get_property(lgd, 'FontName'));
    item.font_size = safe_scalar(get_property(lgd, 'FontSize'));
    item.interpreter = safe_char(get_property(lgd, 'Interpreter'));
    item.box = safe_char(get_property(lgd, 'Box'));
    item.visible = safe_char(get_property(lgd, 'Visible'));
    item.position = safe_numeric(get_property(lgd, 'Position'));
    item.entries = safe_string_list(get_property(lgd, 'String'));
    legends(end + 1, 1) = item; %#ok<AGROW>
end
end

function item = empty_legend_info()
item = struct( ...
    'index', [], ...
    'location', '', ...
    'font_name', '', ...
    'font_size', [], ...
    'interpreter', '', ...
    'box', '', ...
    'visible', '', ...
    'position', [], ...
    'entries', {{}});
end

function colorbars = collect_colorbars(fig)
colorbars = repmat(empty_colorbar_info(), 0, 1);
handles = findall(fig, 'Type', 'ColorBar');
for k = 1:numel(handles)
    cb = handles(k);
    item = empty_colorbar_info();
    item.index = k;
    item.location = safe_char(get_property(cb, 'Location'));
    item.font_name = safe_char(get_property(cb, 'FontName'));
    item.font_size = safe_scalar(get_property(cb, 'FontSize'));
    item.tick_label_interpreter = safe_char(get_property(cb, 'TickLabelInterpreter'));
    item.visible = safe_char(get_property(cb, 'Visible'));
    item.position = safe_numeric(get_property(cb, 'Position'));
    item.limits = safe_numeric(get_property(cb, 'Limits'));
    item.ticks = safe_numeric(get_property(cb, 'Ticks'));
    item.label = inspect_text_object(get_property(cb, 'Label'));
    colorbars(end + 1, 1) = item; %#ok<AGROW>
end
end

function item = empty_colorbar_info()
item = struct( ...
    'index', [], ...
    'location', '', ...
    'font_name', '', ...
    'font_size', [], ...
    'tick_label_interpreter', '', ...
    'visible', '', ...
    'position', [], ...
    'limits', [], ...
    'ticks', [], ...
    'label', empty_text_info());
end

function annotations = collect_annotations(fig)
annotations = repmat(empty_annotation_info(), 0, 1);
all_objects = findall(fig);
for k = 1:numel(all_objects)
    obj = all_objects(k);
    if ~is_annotation_object(obj)
        continue;
    end
    item = empty_annotation_info();
    item.index = numel(annotations) + 1;
    item.class = class(obj);
    item.type = safe_char(get_property(obj, 'Type'));
    item.visible = safe_char(get_property(obj, 'Visible'));
    item.string = safe_char(get_property(obj, 'String'));
    item.position = safe_numeric(get_property(obj, 'Position'));
    annotations(end + 1, 1) = item; %#ok<AGROW>
end
end

function tf = is_annotation_object(obj)
obj_class = lower(class(obj));
obj_type = lower(safe_char(get_property(obj, 'Type')));
if contains(obj_class, 'annotationpane')
    tf = false;
    return;
end
annotation_types = {'textboxshape','arrowshape','doubleendarrow','textarrowshape','rectangle','ellipse'};
tf = contains(obj_class, 'matlab.graphics.shape') || any(strcmp(obj_type, annotation_types));
end

function item = empty_annotation_info()
item = struct( ...
    'index', [], ...
    'class', '', ...
    'type', '', ...
    'visible', '', ...
    'string', '', ...
    'position', []);
end

function tiled_layouts = collect_tiled_layouts(fig)
tiled_layouts = repmat(empty_tiled_layout_info(), 0, 1);
handles = findall(fig, 'Type', 'tiledlayout');
for k = 1:numel(handles)
    tl = handles(k);
    item = empty_tiled_layout_info();
    item.index = k;
    item.tile_spacing = safe_char(get_property(tl, 'TileSpacing'));
    item.padding = safe_char(get_property(tl, 'Padding'));
    item.grid_size = safe_numeric(get_property(tl, 'GridSize'));
    item.visible = safe_char(get_property(tl, 'Visible'));
    tiled_layouts(end + 1, 1) = item; %#ok<AGROW>
end
end

function item = empty_tiled_layout_info()
item = struct( ...
    'index', [], ...
    'tile_spacing', '', ...
    'padding', '', ...
    'grid_size', [], ...
    'visible', '');
end

function unsupported = collect_unsupported_objects(fig)
unsupported = repmat(empty_unsupported_info(), 0, 1);
all_objects = findall(fig);
for k = 1:numel(all_objects)
    obj = all_objects(k);
    if ~is_unsupported_object(obj)
        continue;
    end
    item = empty_unsupported_info();
    item.index = numel(unsupported) + 1;
    item.class = class(obj);
    item.type = safe_char(get_property(obj, 'Type'));
    unsupported(end + 1, 1) = item; %#ok<AGROW>
end
end

function tf = is_unsupported_object(obj)
obj_class = lower(class(obj));
obj_type = lower(safe_char(get_property(obj, 'Type')));
supported_types = {'figure','axes','legend','colorbar','line','scatter','image','surface','contour','text','constantline','quiver','tiledlayout', ...
    'uimenu','uitoolbar','uipushtool','uitoggletool','uicontextmenu','annotationpane'};
supported_class_fragments = {'matlab.graphics.axis.axes','matlab.graphics.illustration.legend','matlab.graphics.illustration.colorbar', ...
    'matlab.graphics.chart.primitive.line','matlab.graphics.chart.primitive.scatter','matlab.graphics.primitive.image', ...
    'matlab.graphics.chart.primitive.surface','matlab.graphics.chart.decoration.constantline','matlab.graphics.chart.primitive.quiver', ...
    'matlab.graphics.primitive.text','matlab.graphics.layout.tiledchartlayout','matlab.graphics.shape.internal.annotationpane', ...
    'matlab.ui.figure','matlab.ui.container.menu','matlab.ui.container.toolbar','matlab.ui.container.contextmenu'};
tf = ~any(strcmp(obj_type, supported_types)) && ~any(cellfun(@(s) contains(obj_class, s), supported_class_fragments));
end

function item = empty_unsupported_info()
item = struct('index', [], 'class', '', 'type', '');
end

function lines = collect_line_objects(ax)
lines = repmat(empty_line_info(), 0, 1);
handles = findall(ax, 'Type', 'line');
for k = 1:numel(handles)
    obj = handles(k);
    item = empty_line_info();
    item.index = k;
    item.class = class(obj);
    item.visible = safe_char(get_property(obj, 'Visible'));
    item.display_name = safe_char(get_property(obj, 'DisplayName'));
    item.line_style = safe_char(get_property(obj, 'LineStyle'));
    item.marker = safe_char(get_property(obj, 'Marker'));
    item.line_width = safe_scalar(get_property(obj, 'LineWidth'));
    item.marker_size = safe_scalar(get_property(obj, 'MarkerSize'));
    item.point_count = max(numel(safe_numeric(get_property(obj, 'XData'))), numel(safe_numeric(get_property(obj, 'YData'))));
    item.data_signature = object_data_signature(obj, {'XData','YData','ZData'});
    lines(end + 1, 1) = item; %#ok<AGROW>
end
end

function item = empty_line_info()
item = struct( ...
    'index', [], ...
    'class', '', ...
    'visible', '', ...
    'display_name', '', ...
    'line_style', '', ...
    'marker', '', ...
    'line_width', [], ...
    'marker_size', [], ...
    'point_count', [], ...
    'data_signature', '');
end

function scatters = collect_scatter_objects(ax)
scatters = repmat(empty_scatter_info(), 0, 1);
handles = findall(ax);
for k = 1:numel(handles)
    obj = handles(k);
    if ~is_scatter_object(obj)
        continue;
    end
    item = empty_scatter_info();
    item.index = numel(scatters) + 1;
    item.class = class(obj);
    item.visible = safe_char(get_property(obj, 'Visible'));
    item.display_name = safe_char(get_property(obj, 'DisplayName'));
    item.line_width = safe_scalar(get_property(obj, 'LineWidth'));
    item.size_data = safe_numeric(get_property(obj, 'SizeData'));
    item.point_count = max(numel(safe_numeric(get_property(obj, 'XData'))), numel(safe_numeric(get_property(obj, 'YData'))));
    item.data_signature = object_data_signature(obj, {'XData','YData','ZData','CData','SizeData'});
    scatters(end + 1, 1) = item; %#ok<AGROW>
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

function item = empty_scatter_info()
item = struct( ...
    'index', [], ...
    'class', '', ...
    'visible', '', ...
    'display_name', '', ...
    'line_width', [], ...
    'size_data', [], ...
    'point_count', [], ...
    'data_signature', '');
end

function images = collect_image_objects(ax)
images = repmat(empty_image_info(), 0, 1);
handles = [findall(ax, 'Type', 'image'); findall(ax, 'Type', 'surface')];
for k = 1:numel(handles)
    obj = handles(k);
    item = empty_image_info();
    item.index = k;
    item.class = class(obj);
    item.type = safe_char(get_property(obj, 'Type'));
    item.visible = safe_char(get_property(obj, 'Visible'));
    cdata = get_property(obj, 'CData');
    item.cdata_size = size(cdata);
    item.data_signature = object_data_signature(obj, {'XData','YData','ZData','CData'});
    images(end + 1, 1) = item; %#ok<AGROW>
end
end

function item = empty_image_info()
item = struct( ...
    'index', [], ...
    'class', '', ...
    'type', '', ...
    'visible', '', ...
    'cdata_size', [], ...
    'data_signature', '');
end

function other_objects = collect_other_primitive_objects(ax)
other_objects = repmat(empty_other_primitive_info(), 0, 1);
all_children = findall(ax);
for k = 1:numel(all_children)
    obj = all_children(k);
    obj_type = lower(safe_char(get_property(obj, 'Type')));
    if any(strcmp(obj_type, {'axes','line','scatter','image','surface','text','constantline'}))
        continue;
    end
    obj_class = lower(class(obj));
    if contains(obj_class, 'legend') || contains(obj_class, 'colorbar')
        continue;
    end
    if contains(obj_class, 'quiver')
        item = empty_other_primitive_info();
        item.index = numel(other_objects) + 1;
        item.class = class(obj);
        item.type = safe_char(get_property(obj, 'Type'));
        item.visible = safe_char(get_property(obj, 'Visible'));
        item.data_signature = object_data_signature(obj, {'XData','YData','ZData','UData','VData','WData','CData'});
        other_objects(end + 1, 1) = item; %#ok<AGROW>
    end
end
end

function item = empty_other_primitive_info()
item = struct('index', [], 'class', '', 'type', '', 'visible', '', 'data_signature', '');
end

function text_info = inspect_text_object(text_handle)
text_info = empty_text_info();
if isempty(text_handle) || ~ishandle(text_handle)
    return;
end
text_info.string = safe_char(get_property(text_handle, 'String'));
text_info.interpreter = safe_char(get_property(text_handle, 'Interpreter'));
text_info.font_name = safe_char(get_property(text_handle, 'FontName'));
text_info.font_size = safe_scalar(get_property(text_handle, 'FontSize'));
text_info.visible = safe_char(get_property(text_handle, 'Visible'));
end

function item = empty_text_info()
item = struct( ...
    'string', '', ...
    'interpreter', '', ...
    'font_name', '', ...
    'font_size', [], ...
    'visible', '');
end

function tf = detect_multiple_yaxes(ax)
tf = false;
try
    y_axes = get(ax, 'YAxis');
    tf = numel(y_axes) > 1;
catch
    tf = false;
end
end

function tf = detect_3d_view(ax)
tf = false;
try
    view_value = get(ax, 'View');
    if isnumeric(view_value) && numel(view_value) == 2
        tf = abs(view_value(2) - 90) > 1e-9;
    end
catch
    tf = false;
end
end

function count = count_hidden_handles(fig)
count = 0;
objs = findall(fig);
for k = 1:numel(objs)
    handle_visibility = lower(safe_char(get_property(objs(k), 'HandleVisibility')));
    if ~isempty(handle_visibility) && ~strcmp(handle_visibility, 'on')
        count = count + 1;
    end
end
end

function signature = object_data_signature(obj, property_names)
parts = cell(1, numel(property_names));
for k = 1:numel(property_names)
    property_name = property_names{k};
    value = get_property(obj, property_name);
    parts{k} = [property_name ':' hash_value(value)]; %#ok<AGROW>
end
signature = strjoin(parts, '|');
end

function hash_text = hash_value(value)
if isempty(value)
    hash_text = 'empty';
    return;
end
try
    bytes = getByteStreamFromArray(value);
    md = java.security.MessageDigest.getInstance('MD5');
    md.update(bytes);
    hash = typecast(md.digest(), 'uint8');
    hash_text = lower(reshape(dec2hex(hash, 2).', 1, []));
catch
    try
        value_numeric = double(value(:));
        hash_text = sprintf('fallback_%d_%0.15g_%0.15g', numel(value_numeric), sum(value_numeric), sum(abs(value_numeric)));
    catch
        hash_text = ['fallback_' class(value)];
    end
end
end

function position = get_position_in_units(obj, units_name)
position = [];
if isempty(obj) || ~ishandle(obj)
    return;
end
original_units = safe_char(get_property(obj, 'Units'));
try
    set(obj, 'Units', units_name);
    position = safe_numeric(get_property(obj, 'Position'));
catch
    position = safe_numeric(get_property(obj, 'Position'));
end
if ~isempty(original_units)
    try
        set(obj, 'Units', original_units);
    catch
    end
end
end

function value = get_property(obj, property_name)
try
    value = get(obj, property_name);
catch
    value = [];
end
end

function cmap = safe_colormap(target)
cmap = [];
try
    cmap = colormap(target);
catch
    cmap = [];
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

function value = safe_scalar(value)
value = safe_numeric(value);
if isempty(value)
    return;
end
if numel(value) ~= 1
    value = value(1);
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
if iscell(value)
    parts = cellfun(@safe_char, value, 'UniformOutput', false);
    text_value = char(strjoin(parts, ' | '));
    return;
end
try
    text_value = char(string(value));
catch
    text_value = '';
end
end

function values = safe_string_list(value)
values = {};
if isempty(value)
    return;
end
if ischar(value)
    values = cellstr(value);
    return;
end
if isstring(value)
    values = cellstr(value);
    return;
end
if iscell(value)
    values = cellfun(@safe_char, value, 'UniformOutput', false);
end
end

function name = get_figure_name(source_path, fig)
if ~isempty(source_path)
    [~, name] = fileparts(source_path);
    return;
end
name = safe_char(get_property(fig, 'Name'));
if isempty(name)
    name = 'unsaved_figure';
end
end
