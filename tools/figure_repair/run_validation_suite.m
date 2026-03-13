function results = run_validation_suite(output_json_path)
% run_validation_suite Run runtime, safety, and workflow validation for figure repair.

if nargin < 1
    output_json_path = '';
end

ensure_paths();
results = struct();
results.validation_date = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
results.matlab_version = version;
results.matlab_release = version('-release');
results.runtime_tests = run_runtime_tests();
results.real_cases = run_real_case_suite();
results.guardrail_tests = run_guardrail_tests();
results.failure_modes = run_failure_mode_tests();
results.directory_test = run_directory_test();
results.performance = run_performance_test();

if ~isempty(output_json_path)
    write_text_file(output_json_path, jsonencode(results));
end
end

function ensure_paths()
addpath('tools/figure_repair');
addpath('tools/figures');
end

function root = validation_tmp_root()
root = fullfile('results', 'tests', 'figure_repair_validation_tmp');
if exist(root, 'dir') ~= 7
    mkdir(root);
end
end

function runtime_tests = run_runtime_tests()
runtime_tests = repmat(empty_runtime_test(), 0, 1);
source_fig = 'results/aging/runs/run_2026_03_10_112842_geometry_visualization/figures/aging_map_heatmap.fig';
tmp_root = fullfile(validation_tmp_root(), 'runtime');
if exist(tmp_root, 'dir') == 7
    rmdir(tmp_root, 's');
end
mkdir(tmp_root);

runtime_tests(end + 1) = run_named_test('inspect_fig_contents', @() runtime_inspect(source_fig)); %#ok<AGROW>
runtime_tests(end + 1) = run_named_test('apply_fig_style_repair', @() runtime_apply_style(source_fig)); %#ok<AGROW>
runtime_tests(end + 1) = run_named_test('export_repaired_figure', @() runtime_export(source_fig, tmp_root)); %#ok<AGROW>
runtime_tests(end + 1) = run_named_test('write_repair_metadata', @() runtime_metadata(tmp_root)); %#ok<AGROW>
runtime_tests(end + 1) = run_named_test('repair_fig_file', @() runtime_repair_file(source_fig)); %#ok<AGROW>
runtime_tests(end + 1) = run_named_test('repair_fig_directory', @() runtime_repair_directory()); %#ok<AGROW>
end

function out = runtime_inspect(source_fig)
info = inspect_fig_contents(source_fig);
out = struct('axes_count', info.axes_count, 'annotation_count', info.annotation_count, 'tiled_layout_count', info.tiled_layout_count);
end

function out = runtime_apply_style(source_fig)
fig = openfig(source_fig, 'invisible');
cleanup_obj = onCleanup(@() close_figure_safely(fig)); %#ok<NASGU>
repair_info = apply_fig_style_repair(fig);
out = struct('action_count', numel(repair_info.actions), 'layout_changed', repair_info.layout_changed, 'style_changed', repair_info.style_changed);
end

function out = runtime_export(source_fig, tmp_root)
fig = openfig(source_fig, 'invisible');
cleanup_obj = onCleanup(@() close_figure_safely(fig)); %#ok<NASGU>
out_dir = fullfile(tmp_root, 'direct_export_outputs');
if exist(out_dir, 'dir') == 7
    rmdir(out_dir, 's');
end
mkdir(out_dir);
paths = export_repaired_figure(fig, out_dir, 'direct_runtime_export');
out = struct('pdf_exists', file_exists(paths.pdf), 'png_exists', file_exists(paths.png), 'fig_exists', file_exists(paths.fig));
end

function out = runtime_metadata(tmp_root)
out_dir = fullfile(tmp_root, 'metadata_outputs');
if exist(out_dir, 'dir') == 7
    rmdir(out_dir, 's');
end
mkdir(out_dir);
metadata = struct('source_figure', 'runtime_test', 'source_path', 'synthetic', 'repair_actions', {{'test_action'}}, 'repair_classification', 'style_only');
metadata_path = write_repair_metadata(out_dir, metadata);
out = struct('metadata_exists', file_exists(metadata_path), 'metadata_size', file_size(metadata_path));
end

function out = runtime_repair_file(source_fig)
out_dir = fullfile('results', 'aging', 'runs', 'run_2026_03_10_112842_geometry_visualization', 'repaired_figures', '__validation_runtime_single');
if exist(out_dir, 'dir') == 7
    rmdir(out_dir, 's');
end
result = repair_fig_file(source_fig, out_dir);
out = struct('classification', result.repair_classification, 'metadata_exists', file_exists(result.metadata_path));
end

function out = runtime_repair_directory()
run_dir = 'results/aging/runs/run_2026_03_10_112842_geometry_visualization';
results_dir = repair_fig_directory(run_dir);
out = struct('result_count', numel(results_dir), 'all_metadata_present', all(arrayfun(@(x) file_exists(x.metadata_path), results_dir)));
end

function cases = run_real_case_suite()
cases = repmat(empty_real_case(), 0, 1);
case_defs = get_real_case_definitions();
for k = 1:numel(case_defs)
    cases(end + 1) = execute_real_case(case_defs(k)); %#ok<AGROW>
end
end

function case_defs = get_real_case_definitions()
case_defs = struct([]);
case_defs(1).name = 'aging_heatmap';
case_defs(1).source = 'results/aging/runs/run_2026_03_10_112842_geometry_visualization/figures/aging_map_heatmap.fig';
case_defs(2).name = 'aging_line_stack';
case_defs(2).source = 'results/aging/runs/run_2026_03_10_112842_geometry_visualization/figures/aging_temperature_slices.fig';
case_defs(3).name = 'cross_experiment_tiled_layout';
case_defs(3).source = 'results/cross_experiment/runs/run_2026_03_10_233449_simple_switching_vs_relaxation_search/figures/candidate_overview_normalized.fig';
case_defs(4).name = 'switching_scatter_geometry';
case_defs(4).source = 'results/switching/runs/run_2026_03_09_230048_XI_Xshape_analysis/XI_Xshape_analysis/figures/mode_space_geometry.fig';
case_defs(5).name = 'relaxation_spectrum';
case_defs(5).source = 'results/relaxation/runs/run_2026_03_10_143118_geometry_observables/figures/singular_value_spectrum.fig';
end

function item = execute_real_case(case_def)
item = empty_real_case();
item.name = case_def.name;
item.source_figure_path = case_def.source;
item.source_hash_before = file_md5(case_def.source);
info = inspect_fig_contents(case_def.source);
item.detected_structure = info.summary;
output_dir = get_validation_output_dir(case_def.source, case_def.name);
if exist(output_dir, 'dir') == 7
    rmdir(output_dir, 's');
end
result = repair_fig_file(case_def.source, output_dir);
item.output_directory = output_dir;
item.repair_classification = result.repair_classification;
item.repair_actions = result.repair_actions;
item.source_hash_after = file_md5(case_def.source);
item.original_unchanged = strcmp(item.source_hash_before, item.source_hash_after);
item.output_files = result.paths;
item.outputs_exist = all(structfun(@file_exists, result.paths));
item.output_sizes = structfun(@file_size, result.paths, 'UniformOutput', false);
metadata = jsondecode(fileread(result.metadata_path));
item.metadata_written = file_exists(result.metadata_path);
item.metadata_has_required_fields = all(isfield(metadata, {'source_figure','source_run','repair_date','repair_classification','repair_actions','repair_requested_by','style_guide_version'}));
item.pass = item.original_unchanged && item.outputs_exist && item.metadata_written && item.metadata_has_required_fields && result.validation.is_valid;
item.notes = strjoin(result.repair_warnings, ' | ');
end

function tests = run_guardrail_tests()
tests = repmat(empty_guardrail_test(), 0, 1);
line_fig = 'results/aging/runs/run_2026_03_10_112842_geometry_visualization/figures/aging_temperature_slices.fig';
image_fig = 'results/aging/runs/run_2026_03_10_112842_geometry_visualization/figures/aging_map_heatmap.fig';

tests(end + 1) = run_guardrail_case('axis_limits', line_fig, @mutate_axis_limits, 'x_limits_changed'); %#ok<AGROW>
tests(end + 1) = run_guardrail_case('line_data', line_fig, @mutate_line_data, 'data_changed'); %#ok<AGROW>
tests(end + 1) = run_guardrail_case('line_visibility', line_fig, @mutate_visibility, 'visibility_changed'); %#ok<AGROW>
tests(end + 1) = run_guardrail_case('object_count', line_fig, @mutate_object_count, 'count_changed'); %#ok<AGROW>
tests(end + 1) = run_guardrail_case('axis_scale', line_fig, @mutate_axis_scale, 'xscale_changed'); %#ok<AGROW>
tests(end + 1) = run_guardrail_case('image_data', image_fig, @mutate_image_data, 'data_changed'); %#ok<AGROW>
tests(end + 1) = run_guardrail_case('color_limits', image_fig, @mutate_color_limits, 'color_limits_changed'); %#ok<AGROW>
end

function item = run_guardrail_case(name, source_fig, mutator, expected_fragment)
fig = openfig(source_fig, 'invisible');
cleanup_obj = onCleanup(@() close_figure_safely(fig)); %#ok<NASGU>
before = inspect_fig_contents(fig);
mutator(fig);
after = inspect_fig_contents(fig);
validation = validate_repair_integrity(before, after);
item = empty_guardrail_test();
item.name = name;
item.expected_issue_fragment = expected_fragment;
item.detected = ~validation.is_valid;
item.issues = validation.issues;
item.pass = item.detected && any(contains(string(validation.issues), expected_fragment));
end

function modes = run_failure_mode_tests()
modes = repmat(empty_failure_mode(), 0, 1);
tmp_root = fullfile(validation_tmp_root(), 'failure_modes');
if exist(tmp_root, 'dir') == 7
    rmdir(tmp_root, 's');
end
mkdir(tmp_root);
source_root = fullfile(tmp_root, 'sources');
output_root = fullfile(tmp_root, 'outputs');
mkdir(source_root);
mkdir(output_root);

modes(end + 1) = test_corrupted_fig(source_root, output_root); %#ok<AGROW>
modes(end + 1) = test_unsupported_object_fig(source_root, output_root); %#ok<AGROW>
modes(end + 1) = test_missing_colorbar_fig(source_root, output_root); %#ok<AGROW>
modes(end + 1) = test_hidden_handle_fig(source_root, output_root); %#ok<AGROW>
end

function item = test_corrupted_fig(source_root, output_root)
item = empty_failure_mode();
item.name = 'corrupted_fig';
source_fig = fullfile(source_root, 'corrupted.fig');
write_text_file(source_fig, 'not a valid fig');
output_dir = fullfile(output_root, 'corrupted_output');
try
    repair_fig_file(source_fig, output_dir);
    item.pass = false;
    item.result = 'unexpected_success';
catch ME
    item.pass = contains(ME.identifier, 'OpenFailed');
    item.result = ME.identifier;
    item.message = ME.message;
end
end

function item = test_unsupported_object_fig(source_root, output_root)
item = empty_failure_mode();
item.name = 'unsupported_patch_object';
source_fig = fullfile(source_root, 'unsupported_patch.fig');
output_dir = fullfile(output_root, 'unsupported_patch_output');
fig = figure('Visible', 'off');
patch([0 1 0.5], [0 0 1], [0.2 0.7 0.4]);
xlabel('x'); ylabel('y');
savefig(fig, source_fig);
close(fig);
info = inspect_fig_contents(source_fig);
result = repair_fig_file(source_fig, output_dir);
item.pass = info.summary.unsupported_object_count > 0 && strcmp(result.repair_classification, 'manual_review_required');
item.result = result.repair_classification;
item.message = sprintf('unsupported_count=%d', info.summary.unsupported_object_count);
end

function item = test_missing_colorbar_fig(source_root, output_root)
item = empty_failure_mode();
item.name = 'heatmap_without_colorbar';
source_fig = fullfile(source_root, 'heatmap_without_colorbar.fig');
output_dir = fullfile(output_root, 'heatmap_without_colorbar_output');
fig = figure('Visible', 'off');
imagesc(rand(10));
xlabel('x'); ylabel('y');
savefig(fig, source_fig);
close(fig);
result = repair_fig_file(source_fig, output_dir);
item.pass = strcmp(result.repair_classification, 'manual_review_required') && any(contains(string(result.repair_warnings), 'colorbar'));
item.result = result.repair_classification;
item.message = strjoin(result.repair_warnings, ' | ');
end

function item = test_hidden_handle_fig(source_root, output_root)
item = empty_failure_mode();
item.name = 'hidden_handles';
source_fig = fullfile(source_root, 'hidden_handles.fig');
output_dir = fullfile(output_root, 'hidden_handles_output');
fig = figure('Visible', 'off');
plot(1:5, (1:5).^2);
xlabel('x'); ylabel('y');
line_obj = findall(gca, 'Type', 'line');
set(line_obj, 'HandleVisibility', 'off');
savefig(fig, source_fig);
close(fig);
info = inspect_fig_contents(source_fig);
result = repair_fig_file(source_fig, output_dir);
item.pass = info.summary.hidden_handle_count > 0 && result.validation.is_valid;
item.result = result.repair_classification;
item.message = sprintf('hidden_handle_count=%d', info.summary.hidden_handle_count);
end

function item = run_directory_test()
item = struct();
source_dir = 'results/aging/runs/run_2026_03_10_112842_geometry_visualization';
results_dir = repair_fig_directory(source_dir);
item.source_directory = source_dir;
item.figure_count = numel(results_dir);
item.output_directories = {results_dir.output_directory};
item.unique_output_directories = numel(unique(item.output_directories));
item.metadata_files = {results_dir.metadata_path};
item.unique_metadata_files = numel(unique(item.metadata_files));
item.pass = item.figure_count == 6 && item.unique_output_directories == item.figure_count && item.unique_metadata_files == item.figure_count;
end

function item = run_performance_test()
item = struct();
source_dirs = { ...
    'results/relaxation/runs/run_2026_03_10_143118_geometry_observables', ...
    'results/relaxation/runs/run_2026_03_10_150549_geometry_observables'};
mem_before = safe_memory();
tic;
count = 0;
for k = 1:numel(source_dirs)
    results_dir = repair_fig_directory(source_dirs{k});
    count = count + numel(results_dir);
end
elapsed_seconds = toc;
mem_after = safe_memory();
item.source_directories = source_dirs;
item.figure_count = count;
item.elapsed_seconds = elapsed_seconds;
item.seconds_per_figure = elapsed_seconds / max(count, 1);
item.memory_before_mb = mem_before;
item.memory_after_mb = mem_after;
item.pass = count >= 32;
end

function item = run_named_test(name, fn)
item = empty_runtime_test();
item.name = name;
try
    output = fn();
    item.pass = true;
    item.output = output;
catch ME
    item.pass = false;
    item.error_identifier = ME.identifier;
    item.error_message = ME.message;
end
end

function mutate_axis_limits(fig)
ax = findall(fig, 'Type', 'axes');
ax = first_plot_axis(ax);
set(ax, 'XLim', get(ax, 'XLim') + [1 1]);
end

function mutate_line_data(fig)
ax = findall(fig, 'Type', 'axes');
ax = first_plot_axis(ax);
ln = findall(ax, 'Type', 'line', '-depth', 1);
ln = ln(1);
set(ln, 'YData', get(ln, 'YData') + 1);
end

function mutate_visibility(fig)
ax = findall(fig, 'Type', 'axes');
ax = first_plot_axis(ax);
ln = findall(ax, 'Type', 'line', '-depth', 1);
ln = ln(1);
set(ln, 'Visible', 'off');
end

function mutate_object_count(fig)
ax = findall(fig, 'Type', 'axes');
ax = first_plot_axis(ax);
line(ax, [0 1], [0 1], 'Color', 'k');
end

function mutate_axis_scale(fig)
ax = findall(fig, 'Type', 'axes');
ax = first_plot_axis(ax);
set(ax, 'XScale', 'log');
end

function mutate_image_data(fig)
img = findall(fig, 'Type', 'image');
if isempty(img)
    img = findall(fig, 'Type', 'surface');
end
img = img(1);
set(img, 'CData', get(img, 'CData') + 1);
end

function mutate_color_limits(fig)
ax = findall(fig, 'Type', 'axes');
ax = first_plot_axis(ax);
set(ax, 'CLim', get(ax, 'CLim') + [0.1 0.1]);
end

function ax = first_plot_axis(ax_list)
ax = ax_list(1);
for k = 1:numel(ax_list)
    tag = '';
    try
        tag = get(ax_list(k), 'Tag');
    catch
    end
    if ~strcmpi(tag, 'legend') && ~strcmpi(tag, 'colorbar')
        ax = ax_list(k);
        return;
    end
end
end

function output_dir = get_validation_output_dir(source_fig, case_name)
figures_dir = fileparts(source_fig);
run_dir = fileparts(figures_dir);
output_dir = fullfile(run_dir, 'repaired_figures', ['__validation_' case_name]);
end

function tf = file_exists(file_path)
tf = exist(file_path, 'file') == 2;
end

function bytes = file_size(file_path)
bytes = 0;
if exist(file_path, 'file') ~= 2
    return;
end
file_info = dir(file_path);
bytes = file_info.bytes;
end

function digest = file_md5(file_path)
bytes = fileread_binary(file_path);
md = java.security.MessageDigest.getInstance('MD5');
md.update(bytes);
hash = typecast(md.digest(), 'uint8');
digest = lower(reshape(dec2hex(hash, 2).', 1, []));
end

function bytes = fileread_binary(file_path)
fid = fopen(file_path, 'r');
if fid == -1
    error('run_validation_suite:FileReadFailed', 'Unable to open file: %s', file_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid, inf, '*uint8');
end

function mb = safe_memory()
mb = NaN;
try
    m = memory;
    mb = m.MemUsedMATLAB / 1024 / 1024;
catch
    mb = NaN;
end
end

function close_figure_safely(fig)
if ~isempty(fig) && ishandle(fig)
    close(fig);
end
end

function write_text_file(file_path, text_value)
fid = fopen(file_path, 'w');
if fid == -1
    error('run_validation_suite:FileWriteFailed', 'Unable to write file: %s', file_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', text_value);
end

function item = empty_runtime_test()
item = struct('name', '', 'pass', false, 'output', struct(), 'error_identifier', '', 'error_message', '');
end

function item = empty_real_case()
item = struct('name', '', 'source_figure_path', '', 'detected_structure', struct(), 'repair_classification', '', 'repair_actions', {{}}, ...
    'output_directory', '', 'source_hash_before', '', 'source_hash_after', '', 'original_unchanged', false, 'output_files', struct(), ...
    'outputs_exist', false, 'output_sizes', struct(), 'metadata_written', false, 'metadata_has_required_fields', false, 'pass', false, 'notes', '');
end

function item = empty_guardrail_test()
item = struct('name', '', 'expected_issue_fragment', '', 'detected', false, 'issues', {{}}, 'pass', false);
end

function item = empty_failure_mode()
item = struct('name', '', 'pass', false, 'result', '', 'message', '');
end
