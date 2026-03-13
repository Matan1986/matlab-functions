function results = repair_fig_directory(source_directory)
% repair_fig_directory Repair every FIG in a figures directory into repaired_figures/.

if nargin < 1
    error('repair_fig_directory:InvalidInput', 'repair_fig_directory requires source_directory.');
end

source_directory = char(string(source_directory));
if exist(source_directory, 'dir') ~= 7
    error('repair_fig_directory:DirectoryMissing', 'Directory not found: %s', source_directory);
end

[source_fig_dir, repaired_root] = resolve_repair_directories(source_directory);
fig_files = dir(fullfile(source_fig_dir, '*.fig'));
if isempty(fig_files)
    warning('repair_fig_directory:NoFiguresFound', 'No FIG files found in %s', source_fig_dir);
    results = repmat(empty_result(), 0, 1);
    return;
end

if exist(repaired_root, 'dir') ~= 7
    mkdir(repaired_root);
end

results = repmat(empty_result(), 0, 1);
for k = 1:numel(fig_files)
    source_fig_path = fullfile(fig_files(k).folder, fig_files(k).name);
    [~, base_name] = fileparts(fig_files(k).name);
    output_directory = resolve_unique_output_directory(repaired_root, base_name);
    result = repair_fig_file(source_fig_path, output_directory);
    results(end + 1, 1) = result; %#ok<AGROW>
end
end

function [source_fig_dir, repaired_root] = resolve_repair_directories(source_directory)
[~, dir_name] = fileparts(source_directory);
if strcmpi(dir_name, 'figures')
    source_fig_dir = source_directory;
    repaired_root = fullfile(fileparts(source_directory), 'repaired_figures');
    return;
end

candidate_figures = fullfile(source_directory, 'figures');
if exist(candidate_figures, 'dir') == 7
    source_fig_dir = candidate_figures;
    repaired_root = fullfile(source_directory, 'repaired_figures');
    return;
end

source_fig_dir = source_directory;
repaired_root = fullfile(fileparts(source_directory), 'repaired_figures');
end

function output_directory = resolve_unique_output_directory(repaired_root, base_name)
output_directory = fullfile(repaired_root, base_name);
if exist(output_directory, 'dir') ~= 7
    return;
end

suffix = 2;
while true
    candidate = fullfile(repaired_root, sprintf('%s__%02d', base_name, suffix));
    if exist(candidate, 'dir') ~= 7
        output_directory = candidate;
        return;
    end
    suffix = suffix + 1;
end
end

function item = empty_result()
item = struct( ...
    'source_fig_path', '', ...
    'output_directory', '', ...
    'paths', struct('pdf', '', 'png', '', 'fig', ''), ...
    'metadata_path', '', ...
    'repair_classification', '', ...
    'repair_actions', {{}}, ...
    'quality_issues', struct('id', {}, 'message', {}), ...
    'repair_warnings', {{}}, ...
    'validation', struct('is_valid', true, 'issues', {{}}), ...
    'inspection_summary', struct());
end
