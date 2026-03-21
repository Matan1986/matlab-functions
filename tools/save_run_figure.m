function paths = save_run_figure(figure_handle, figure_name, run_output_dir)
% save_run_figure Save a run figure in canonical PDF, PNG, and FIG formats.
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
%   paths           - struct with fields pdf, png, and fig

if nargin < 3
    error('save_run_figure requires figure_handle, figure_name, and run_output_dir.');
end
if isempty(figure_handle) || ~ishandle(figure_handle)
    error('save_run_figure requires a valid figure handle.');
end

figure_handle = resolve_figure_handle(figure_handle);
if ~(ischar(figure_name) || (isstring(figure_name) && isscalar(figure_name)))
    error('Figure Name must exactly match base_name and must be non-empty');
end
figure_name = char(figure_name);
run_output_dir = char(string(run_output_dir));
base_name = strtrim(figure_name);
if isempty(base_name)
    error('Figure Name must exactly match base_name and must be non-empty');
end
if isempty(strtrim(run_output_dir))
    error('save_run_figure requires a non-empty run_output_dir.');
end

if ~isprop(figure_handle, 'Name')
    error('Figure Name must exactly match base_name and must be non-empty');
end
figName = get(figure_handle, 'Name');
if ~(ischar(figName) || (isstring(figName) && isscalar(figName)))
    error('Figure Name must exactly match base_name and must be non-empty');
end
figName = strtrim(char(string(figName)));
if isempty(figName) || ~strcmp(figName, base_name)
    error('Figure Name must exactly match base_name and must be non-empty');
end

run_output_dir = resolve_run_root(run_output_dir);
figures_dir = fullfile(run_output_dir, 'figures');
if exist(figures_dir, 'dir') ~= 7
    mkdir(figures_dir);
end

ensure_figure_helpers_on_path();
try_apply_publication_style(figure_handle);
try_run_figure_quality_check(figure_handle);

paths = struct();
paths.pdf = fullfile(figures_dir, [base_name '.pdf']);
paths.png = fullfile(figures_dir, [base_name '.png']);
paths.fig = fullfile(figures_dir, [base_name '.fig']);

set(figure_handle, 'Color', 'w');
exportgraphics(figure_handle, paths.pdf, 'ContentType', 'vector');
exportgraphics(figure_handle, paths.png, 'Resolution', 600);
savefig(figure_handle, paths.fig);

fprintf('Saved figure PDF: %s\n', paths.pdf);
fprintf('Saved figure PNG: %s\n', paths.png);
fprintf('Saved figure FIG: %s\n', paths.fig);
end

function figure_handle = resolve_figure_handle(handle_in)
if strcmp(get(handle_in, 'Type'), 'figure')
    figure_handle = handle_in;
    return;
end

figure_handle = ancestor(handle_in, 'figure');
if isempty(figure_handle) || ~ishandle(figure_handle)
    error('save_run_figure requires a valid figure handle.');
end
end

function ensure_figure_helpers_on_path()
this_file = mfilename('fullpath');
tools_dir = fileparts(this_file);
helpers_dir = fullfile(tools_dir, 'figures');
if exist(helpers_dir, 'dir') ~= 7
    return;
end
if isempty(strfind(path, helpers_dir))
    addpath(helpers_dir);
end
end

function try_apply_publication_style(figure_handle)
if exist('apply_publication_style', 'file') ~= 2
    return;
end
try
    apply_publication_style(figure_handle);
catch ME
    warning('save_run_figure:publicationStyleFailed', ...
        'apply_publication_style failed for this export: %s', ME.message);
end
end

function try_run_figure_quality_check(figure_handle)
if exist('figure_quality_check', 'file') ~= 2
    return;
end
try
    figure_quality_check(figure_handle);
catch ME
    warning('save_run_figure:qualityCheckFailed', ...
        'figure_quality_check failed for this export: %s', ME.message);
end
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


