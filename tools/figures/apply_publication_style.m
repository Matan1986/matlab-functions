function fig = apply_publication_style(fig)
% apply_publication_style Apply repository publication styling to a figure.

if nargin < 1 || isempty(fig) || ~ishandle(fig)
    error('apply_publication_style requires a valid figure handle.');
end

fig = resolve_figure_handle(fig);
font_name = resolve_publication_font();
configure_figure(fig);

axes_handles = findall(fig, 'Type', 'axes');
for i = 1:numel(axes_handles)
    ax = axes_handles(i);
    if ~isgraphics(ax)
        continue;
    end
    ax_tag = '';
    try
        ax_tag = get(ax, 'Tag');
    catch
        ax_tag = '';
    end
    if strcmpi(ax_tag, 'legend') || strcmpi(ax_tag, 'Colorbar')
        continue;
    end
    style_axes(ax, font_name);
end

legend_handles = findall(fig, 'Type', 'Legend');
for i = 1:numel(legend_handles)
    style_legend(legend_handles(i), font_name);
end

colorbar_handles = findall(fig, 'Type', 'ColorBar');
for i = 1:numel(colorbar_handles)
    style_colorbar(colorbar_handles(i), font_name);
end
end

function fig = resolve_figure_handle(handle_in)
if strcmp(get(handle_in, 'Type'), 'figure')
    fig = handle_in;
    return;
end

fig = ancestor(handle_in, 'figure');
if isempty(fig) || ~ishandle(fig)
    error('apply_publication_style requires a valid figure handle.');
end
end

function configure_figure(fig)
set(fig, 'Color', 'w', 'InvertHardcopy', 'off');
set(fig, 'Units', 'centimeters');
pos = get(fig, 'Position');
if numel(pos) ~= 4 || any(~isfinite(pos(3:4))) || any(pos(3:4) <= 0)
    pos = [2 2 8.6 6.2];
    set(fig, 'Position', pos);
end
set(fig, 'PaperUnits', 'centimeters', ...
    'PaperPosition', [0 0 pos(3) pos(4)], ...
    'PaperSize', [pos(3) pos(4)]);
end

function style_axes(ax, font_name)
set(ax, ...
    'FontName', font_name, ...
    'FontSize', max(8, get(ax, 'FontSize')), ...
    'LineWidth', max(1, get(ax, 'LineWidth')), ...
    'TickDir', 'out', ...
    'Layer', 'top', ...
    'XMinorTick', 'off', ...
    'YMinorTick', 'off', ...
    'TickLabelInterpreter', 'tex');

if has_image_content(ax)
    set(ax, 'Box', 'on', 'YDir', 'normal');
else
    set(ax, 'Box', 'off');
end

style_label(get(ax, 'XLabel'), font_name, 9);
style_label(get(ax, 'YLabel'), font_name, 9);
if isprop(ax, 'ZLabel')
    style_label(get(ax, 'ZLabel'), font_name, 9);
end
style_label(get(ax, 'Title'), font_name, 9);

line_handles = findall(ax, 'Type', 'line');
for j = 1:numel(line_handles)
    if ~isgraphics(line_handles(j))
        continue;
    end
    set(line_handles(j), 'LineWidth', max(2, get(line_handles(j), 'LineWidth')));
    if isprop(line_handles(j), 'MarkerSize')
        set(line_handles(j), 'MarkerSize', max(5, get(line_handles(j), 'MarkerSize')));
    end
end
end

function tf = has_image_content(ax)
tf = ~isempty(findall(ax, 'Type', 'image')) || ...
    ~isempty(findall(ax, 'Type', 'surface')) || ...
    ~isempty(findall(ax, 'Type', 'contour'));
end

function style_legend(lgd, font_name)
if ~isgraphics(lgd)
    return;
end
set(lgd, ...
    'FontName', font_name, ...
    'FontSize', max(8, get(lgd, 'FontSize')), ...
    'Interpreter', 'tex', ...
    'Box', 'off');
end

function style_colorbar(cb, font_name)
if ~isgraphics(cb)
    return;
end
set(cb, ...
    'FontName', font_name, ...
    'FontSize', max(8, get(cb, 'FontSize')), ...
    'TickLabelInterpreter', 'tex');
if isgraphics(cb.Label)
    style_label(cb.Label, font_name, 9);
end
end

function style_label(label_handle, font_name, font_size)
if ~isgraphics(label_handle)
    return;
end
set(label_handle, ...
    'FontName', font_name, ...
    'FontSize', max(font_size, get(label_handle, 'FontSize')), ...
    'Interpreter', 'tex');
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
