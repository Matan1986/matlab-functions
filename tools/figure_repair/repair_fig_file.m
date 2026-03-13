function result = repair_fig_file(source_fig_path, output_directory)
% repair_fig_file Repair a FIG into publication outputs without overwriting the source.

if nargin < 2
    error('repair_fig_file:InvalidInput', ...
        'repair_fig_file requires source_fig_path and output_directory.');
end

source_fig_path = char(string(source_fig_path));
output_directory = char(string(output_directory));
if exist(source_fig_path, 'file') ~= 2
    error('repair_fig_file:SourceMissing', 'Source FIG file not found: %s', source_fig_path);
end
if isempty(strtrim(output_directory))
    error('repair_fig_file:InvalidOutputDir', 'A non-empty output_directory is required.');
end

assert_safe_output_directory(source_fig_path, output_directory);
ensure_dependencies_on_path();
if exist(output_directory, 'dir') ~= 7
    mkdir(output_directory);
end

try
    fig = openfig(source_fig_path, 'invisible');
catch ME
    error('repair_fig_file:OpenFailed', 'Failed to open FIG file %s: %s', source_fig_path, ME.message);
end
cleanup_obj = onCleanup(@() close_figure_safely(fig)); %#ok<NASGU>
set(fig, 'Visible', 'off');

source_figure_name = get_source_figure_name(source_fig_path);
inspection_before = inspect_fig_contents(fig);
repair_info = apply_fig_style_repair(fig);
inspection_after = inspect_fig_contents(fig);
validation = validate_repair_integrity(inspection_before, inspection_after);
if ~validation.is_valid
    error('repair_fig_file:ForbiddenStructuralChange', '%s', strjoin(validation.issues, ' | '));
end

quality_issues = run_quality_check(fig);
[classification, classification_reasons, repair_warnings] = classify_repair(repair_info, inspection_after, quality_issues);
paths = export_repaired_figure(fig, output_directory, 'repaired');

metadata = struct();
metadata.source_figure = source_figure_name;
metadata.source_path = source_fig_path;
metadata.source_run = resolve_source_run(source_fig_path);
metadata.repair_date = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
metadata.style_guide_version = '';
metadata.repair_actions = repair_info.actions;
metadata.repair_classification = classification;
metadata.repair_requested_by = resolve_requested_by();
metadata.output_files = paths;
metadata.validation = validation;
metadata.inspection_summary = struct('before', inspection_before.summary, 'after', inspection_after.summary);
metadata.quality_check_result = struct('issue_count', numel(quality_issues), 'issues', {issue_cell_array(quality_issues)});
metadata.repair_warnings = repair_warnings;
metadata.classification_reasons = classification_reasons;
metadata_path = write_repair_metadata(output_directory, metadata);

result = struct();
result.source_fig_path = source_fig_path;
result.output_directory = output_directory;
result.paths = paths;
result.metadata_path = metadata_path;
result.repair_classification = classification;
result.repair_actions = repair_info.actions;
result.quality_issues = quality_issues;
result.repair_warnings = repair_warnings;
result.validation = validation;
result.inspection_summary = metadata.inspection_summary;
end

function ensure_dependencies_on_path()
this_file = mfilename('fullpath');
repair_dir = fileparts(this_file);
tools_dir = fileparts(repair_dir);
figures_dir = fullfile(tools_dir, 'figures');
paths_to_add = {repair_dir, figures_dir};
for k = 1:numel(paths_to_add)
    path_to_add = paths_to_add{k};
    if exist(path_to_add, 'dir') == 7 && isempty(strfind(path, path_to_add))
        addpath(path_to_add);
    end
end
end

function assert_safe_output_directory(source_fig_path, output_directory)
source_dir = normalize_path(fileparts(source_fig_path));
output_dir = normalize_path(output_directory);
if strcmpi(source_dir, output_dir)
    error('repair_fig_file:UnsafeOutputDir', ...
        'output_directory must not be the original figures directory.');
end
if startsWith(output_dir, [source_dir filesep], 'IgnoreCase', true)
    error('repair_fig_file:UnsafeOutputDir', ...
        'output_directory must be outside the original figures directory.');
end
end

function normalized = normalize_path(path_value)
path_value = char(string(path_value));
try
    normalized = char(java.io.File(path_value).getCanonicalPath());
catch
    normalized = strrep(path_value, '/', filesep);
end
end

function close_figure_safely(fig)
if ~isempty(fig) && ishandle(fig)
    close(fig);
end
end

function issues = run_quality_check(fig)
issues = struct('id', {}, 'message', {});
if exist('figure_quality_check', 'file') ~= 2
    return;
end
try
    issues = figure_quality_check(fig);
catch ME
    issues(1).id = 'quality_check_failed';
    issues(1).message = ME.message;
end
end

function [classification, reasons, warnings_out] = classify_repair(repair_info, inspection_after, quality_issues)
reasons = {};
warnings_out = {};
if ~isempty(quality_issues)
    quality_ids = strcat('quality_issue:', {quality_issues.id}.');
    reasons = [reasons; quality_ids]; %#ok<AGROW>
    warnings_out = [warnings_out; {quality_issues.message}.']; %#ok<AGROW>
end
if inspection_after.summary.has_3d_axes
    reasons{end + 1, 1} = '3d_axes_present'; %#ok<AGROW>
    warnings_out{end + 1, 1} = 'The repaired figure contains 3D axes and requires manual publication review.'; %#ok<AGROW>
end
if inspection_after.summary.has_multiple_yaxes
    reasons{end + 1, 1} = 'multiple_yaxes_present'; %#ok<AGROW>
    warnings_out{end + 1, 1} = 'The repaired figure contains multiple y-axes and requires manual publication review.'; %#ok<AGROW>
end
if inspection_after.summary.colorbar_labels_missing
    reasons{end + 1, 1} = 'missing_colorbar_label'; %#ok<AGROW>
    warnings_out{end + 1, 1} = 'At least one colorbar is missing a label.'; %#ok<AGROW>
end
if inspection_after.summary.image_count > 0 && inspection_after.summary.colorbar_count == 0
    reasons{end + 1, 1} = 'heatmap_without_colorbar'; %#ok<AGROW>
    warnings_out{end + 1, 1} = 'Image-based content was detected without a colorbar.'; %#ok<AGROW>
end
if inspection_after.summary.missing_xlabel || inspection_after.summary.missing_ylabel
    reasons{end + 1, 1} = 'missing_axis_label'; %#ok<AGROW>
    warnings_out{end + 1, 1} = 'At least one axis is missing an x- or y-label.'; %#ok<AGROW>
end
if inspection_after.summary.unsupported_object_count > 0
    reasons{end + 1, 1} = 'unsupported_object_types_present'; %#ok<AGROW>
    warnings_out{end + 1, 1} = 'Unsupported object types were detected and should be reviewed manually.'; %#ok<AGROW>
end

if ~isempty(reasons)
    classification = 'manual_review_required';
elseif repair_info.layout_changed && ~repair_info.style_changed
    classification = 'layout_only';
else
    classification = 'style_only';
end
reasons = unique(reasons, 'stable');
warnings_out = unique(warnings_out, 'stable');
end

function cells = issue_cell_array(issues)
if isempty(issues)
    cells = {};
    return;
end
cells = arrayfun(@(x) struct('id', x.id, 'message', x.message), issues, 'UniformOutput', false);
end

function source_run = resolve_source_run(source_fig_path)
source_run = '';
parts = regexp(strrep(source_fig_path, '\', '/'), '/', 'split');
run_index = find(startsWith(parts, 'run_', 'IgnoreCase', true), 1, 'last');
if isempty(run_index)
    return;
end
source_run = strjoin(parts(1:run_index), '/');
end

function name = get_source_figure_name(source_fig_path)
[~, name] = fileparts(source_fig_path);
end

function requested_by = resolve_requested_by()
requested_by = getenv('USERNAME');
if isempty(requested_by)
    requested_by = getenv('USER');
end
if isempty(requested_by)
    requested_by = 'unknown';
end
end
