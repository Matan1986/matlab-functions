function result = demo_repair_example(source_fig_path)
% demo_repair_example Demonstrate explicit FIG repair on a repository run artifact.

if nargin < 1 || isempty(source_fig_path)
    source_fig_path = find_example_fig();
end

source_fig_path = char(string(source_fig_path));
if exist(source_fig_path, 'file') ~= 2
    error('demo_repair_example:SourceMissing', 'FIG file not found: %s', source_fig_path);
end

source_dir = fileparts(source_fig_path);
output_root = fullfile(fileparts(source_dir), 'repaired_figures');
[~, base_name] = fileparts(source_fig_path);
output_directory = fullfile(output_root, base_name);

fprintf('Repairing FIG: %s\n', source_fig_path);
fprintf('Writing repaired outputs to: %s\n', output_directory);
result = repair_fig_file(source_fig_path, output_directory);
fprintf('Repaired PDF: %s\n', result.paths.pdf);
fprintf('Repaired PNG: %s\n', result.paths.png);
fprintf('Repaired FIG: %s\n', result.paths.fig);
fprintf('Metadata: %s\n', result.metadata_path);
end

function source_fig_path = find_example_fig()
fig_files = dir(fullfile('results', '**', '*.fig'));
if isempty(fig_files)
    error('demo_repair_example:NoExampleFigure', ...
        'No FIG files were found under results/. Provide a source_fig_path explicitly.');
end
source_fig_path = fullfile(fig_files(1).folder, fig_files(1).name);
end
