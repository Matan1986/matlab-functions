function validation = validate_repair_integrity(before_info, after_info)
% validate_repair_integrity Detect forbidden structural or data changes.

validation = struct();
validation.is_valid = true;
validation.issues = {};

validation = compare_scalar_count(validation, before_info.axes_count, after_info.axes_count, 'axes_count_changed');
validation = compare_scalar_count(validation, before_info.legend_count, after_info.legend_count, 'legend_count_changed');
validation = compare_scalar_count(validation, before_info.colorbar_count, after_info.colorbar_count, 'colorbar_count_changed');
validation = compare_scalar_count(validation, before_info.line_count, after_info.line_count, 'line_count_changed');
validation = compare_scalar_count(validation, before_info.scatter_count, after_info.scatter_count, 'scatter_count_changed');
validation = compare_scalar_count(validation, before_info.image_count, after_info.image_count, 'image_count_changed');
validation = compare_scalar_count(validation, before_info.annotation_count, after_info.annotation_count, 'annotation_count_changed');
validation = compare_scalar_count(validation, before_info.tiled_layout_count, after_info.tiled_layout_count, 'tiled_layout_count_changed');

if ~isequal_numeric(before_info.figure_colormap, after_info.figure_colormap)
    validation = add_validation_issue(validation, 'figure_colormap_changed');
end

axis_count = min(numel(before_info.axes), numel(after_info.axes));
for k = 1:axis_count
    before_ax = before_info.axes(k);
    after_ax = after_info.axes(k);

    if ~isequal_numeric(before_ax.xlim, after_ax.xlim)
        validation = add_validation_issue(validation, sprintf('axis_%d_x_limits_changed', k));
    end
    if ~isequal_numeric(before_ax.ylim, after_ax.ylim)
        validation = add_validation_issue(validation, sprintf('axis_%d_y_limits_changed', k));
    end
    if ~isequal_numeric(before_ax.zlim, after_ax.zlim)
        validation = add_validation_issue(validation, sprintf('axis_%d_z_limits_changed', k));
    end
    if ~isequal_numeric(before_ax.clim, after_ax.clim)
        validation = add_validation_issue(validation, sprintf('axis_%d_color_limits_changed', k));
    end
    if ~strcmp(before_ax.xscale, after_ax.xscale)
        validation = add_validation_issue(validation, sprintf('axis_%d_xscale_changed', k));
    end
    if ~strcmp(before_ax.yscale, after_ax.yscale)
        validation = add_validation_issue(validation, sprintf('axis_%d_yscale_changed', k));
    end
    if ~strcmp(before_ax.zscale, after_ax.zscale)
        validation = add_validation_issue(validation, sprintf('axis_%d_zscale_changed', k));
    end
    if ~strcmp(before_ax.xdir, after_ax.xdir)
        validation = add_validation_issue(validation, sprintf('axis_%d_xdir_changed', k));
    end
    if ~strcmp(before_ax.ydir, after_ax.ydir)
        validation = add_validation_issue(validation, sprintf('axis_%d_ydir_changed', k));
    end

    validation = compare_object_lists(validation, before_ax.lines, after_ax.lines, k, 'line');
    validation = compare_object_lists(validation, before_ax.scatters, after_ax.scatters, k, 'scatter');
    validation = compare_object_lists(validation, before_ax.images, after_ax.images, k, 'image');
    validation = compare_object_lists(validation, before_ax.other_primitives, after_ax.other_primitives, k, 'primitive');
end
end

function validation = compare_scalar_count(validation, before_value, after_value, issue_id)
if before_value ~= after_value
    validation = add_validation_issue(validation, issue_id);
end
end

function validation = compare_object_lists(validation, before_items, after_items, axis_index, kind)
if numel(before_items) ~= numel(after_items)
    validation = add_validation_issue(validation, sprintf('axis_%d_%s_count_changed', axis_index, kind));
    return;
end

for k = 1:numel(before_items)
    before_visible = safe_get_field(before_items(k), 'visible');
    after_visible = safe_get_field(after_items(k), 'visible');
    if ~strcmp(before_visible, after_visible)
        validation = add_validation_issue(validation, sprintf('axis_%d_%s_%d_visibility_changed', axis_index, kind, k));
    end

    before_signature = safe_get_field(before_items(k), 'data_signature');
    after_signature = safe_get_field(after_items(k), 'data_signature');
    if ~strcmp(before_signature, after_signature)
        validation = add_validation_issue(validation, sprintf('axis_%d_%s_%d_data_changed', axis_index, kind, k));
    end
end
end

function value = safe_get_field(item, field_name)
if isfield(item, field_name)
    value = item.(field_name);
else
    value = '';
end
end

function tf = isequal_numeric(a, b)
a = safe_numeric(a);
b = safe_numeric(b);
if isempty(a) && isempty(b)
    tf = true;
    return;
end
if ~isequal(size(a), size(b))
    tf = false;
    return;
end
tf = all(abs(a(:) - b(:)) < 1e-10);
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

function validation = add_validation_issue(validation, issue_text)
validation.is_valid = false;
validation.issues{end + 1, 1} = issue_text;
end
