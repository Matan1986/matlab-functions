function paths = save_run_figure(figure_handle, figure_name, run_output_dir)
% save_run_figure Save a run figure in canonical PNG and FIG formats.
%
% Usage:
%   paths = save_run_figure(gcf, 'aging_map_heatmap', run_output_dir)
%
% Inputs:
%   figure_handle   - MATLAB figure handle to save
%   figure_name     - Base filename without extension
%   run_output_dir  - Run root directory, e.g. results/<experiment>/runs/run_...
%
% Output:
%   paths           - struct with fields png and fig

if nargin < 3
    error('save_run_figure requires figure_handle, figure_name, and run_output_dir.');
end
if isempty(figure_handle) || ~ishandle(figure_handle)
    error('save_run_figure requires a valid figure handle.');
end

figure_name = char(string(figure_name));
run_output_dir = char(string(run_output_dir));
if isempty(strtrim(figure_name))
    error('save_run_figure requires a non-empty figure_name.');
end
if isempty(strtrim(run_output_dir))
    error('save_run_figure requires a non-empty run_output_dir.');
end

run_output_dir = resolve_run_root(run_output_dir);
figures_dir = fullfile(run_output_dir, 'figures');
if exist(figures_dir, 'dir') ~= 7
    mkdir(figures_dir);
end

paths = struct();
paths.png = fullfile(figures_dir, [figure_name '.png']);
paths.fig = fullfile(figures_dir, [figure_name '.fig']);

exportgraphics(figure_handle, paths.png, 'Resolution', 300);
savefig(figure_handle, paths.fig);

fprintf('Saved figure PNG: %s\n', paths.png);
fprintf('Saved figure FIG: %s\n', paths.fig);
end

function run_root_dir = resolve_run_root(run_output_dir)
run_output_dir = char(string(run_output_dir));
run_root_dir = run_output_dir;

while true
    [parentDir, dirName, ext] = fileparts(run_root_dir);
    if isempty(dirName) && isempty(ext)
        break;
    end

    fullName = [dirName ext];
    if startsWith(string(fullName), "run_", 'IgnoreCase', true)
        return;
    end

    if strcmp(parentDir, run_root_dir)
        break;
    end

    run_root_dir = parentDir;
end

run_root_dir = run_output_dir;
end