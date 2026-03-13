function paths = export_repaired_figure(fig, output_directory, figure_name)
% export_repaired_figure Export a repaired figure without touching the source FIG.

if nargin < 3
    error('export_repaired_figure:InvalidInput', ...
        'export_repaired_figure requires fig, output_directory, and figure_name.');
end
if isempty(fig) || ~ishandle(fig)
    error('export_repaired_figure:InvalidHandle', 'A valid figure handle is required.');
end

fig = resolve_figure_handle(fig);
output_directory = char(string(output_directory));
figure_name = strip_extension(char(string(figure_name)));
if isempty(strtrim(output_directory))
    error('export_repaired_figure:InvalidOutputDir', 'A non-empty output_directory is required.');
end
if isempty(strtrim(figure_name))
    error('export_repaired_figure:InvalidFigureName', 'A non-empty figure_name is required.');
end
if exist(output_directory, 'dir') ~= 7
    mkdir(output_directory);
end

paths = struct();
paths.pdf = fullfile(output_directory, [figure_name '.pdf']);
paths.png = fullfile(output_directory, [figure_name '.png']);
paths.fig = fullfile(output_directory, [figure_name '.fig']);

set(fig, 'Color', 'w', 'InvertHardcopy', 'off');
exportgraphics(fig, paths.pdf, 'ContentType', 'vector');
exportgraphics(fig, paths.png, 'Resolution', 600);
savefig(fig, paths.fig);
end

function fig = resolve_figure_handle(handle_in)
if strcmpi(get(handle_in, 'Type'), 'figure')
    fig = handle_in;
    return;
end
fig = ancestor(handle_in, 'figure');
if isempty(fig) || ~ishandle(fig)
    error('export_repaired_figure:InvalidHandle', 'A valid figure handle is required.');
end
end

function figure_name = strip_extension(figure_name)
[~, base_name] = fileparts(figure_name);
if isempty(base_name)
    return;
end
figure_name = base_name;
end
