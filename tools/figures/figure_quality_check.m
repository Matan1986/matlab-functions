function issues = figure_quality_check(fig)
% figure_quality_check Warn about common publication-style violations.

if nargin < 1 || isempty(fig) || ~ishandle(fig)
    error('figure_quality_check requires a valid figure handle.');
end

fig = resolve_figure_handle(fig);
issues = struct('id', {}, 'message', {});
axis_index = 0;
axes_handles = findall(fig, 'Type', 'axes');
for i = 1:numel(axes_handles)
    ax = axes_handles(i);
    if ~isgraphics(ax)
        continue;
    end
    axis_index = axis_index + 1;

    if get(ax, 'FontSize') < 8
        issues = add_issue(issues, 'font_size', sprintf('Axis %d has FontSize < 8 pt.', axis_index));
    end

    line_handles = findall(ax, 'Type', 'line');
    small_lines = 0;
    for j = 1:numel(line_handles)
        if isgraphics(line_handles(j)) && get(line_handles(j), 'LineWidth') < 2
            small_lines = small_lines + 1;
        end
    end
    if small_lines > 0
        issues = add_issue(issues, 'line_width', sprintf('Axis %d has %d line object(s) with LineWidth < 2.', axis_index, small_lines));
    end

    x_label = get_label_text(get(ax, 'XLabel'));
    y_label = get_label_text(get(ax, 'YLabel'));
    if isempty(strtrim(x_label))
        issues = add_issue(issues, 'missing_xlabel', sprintf('Axis %d is missing an x-axis label.', axis_index));
    end
    if isempty(strtrim(y_label))
        issues = add_issue(issues, 'missing_ylabel', sprintf('Axis %d is missing a y-axis label.', axis_index));
    end

    if has_forbidden_colormap(ax)
        issues = add_issue(issues, 'forbidden_colormap', sprintf('Axis %d uses a forbidden colormap (jet, turbo, or hsv).', axis_index));
    end
end

for i = 1:numel(issues)
    warning(['figure_quality_check:' issues(i).id], '%s', issues(i).message);
end
end

function fig = resolve_figure_handle(handle_in)
if strcmp(get(handle_in, 'Type'), 'figure')
    fig = handle_in;
    return;
end

fig = ancestor(handle_in, 'figure');
if isempty(fig) || ~ishandle(fig)
    error('figure_quality_check requires a valid figure handle.');
end
end

function issues = add_issue(issues, id, message)
issues(end + 1).id = id; %#ok<AGROW>
issues(end).message = message;
end

function text_value = get_label_text(label_handle)
text_value = '';
if ~isgraphics(label_handle)
    return;
end
try
    text_value = char(string(get(label_handle, 'String')));
catch
    text_value = '';
end
end

function tf = has_forbidden_colormap(ax)
tf = false;
if isempty(findall(ax, 'Type', 'image')) && isempty(findall(ax, 'Type', 'surface'))
    return;
end

try
    cmap = colormap(ax);
catch
    return;
end

if isempty(cmap) || size(cmap, 2) ~= 3
    return;
end

n = size(cmap, 1);
tf = matches_colormap(cmap, jet(n)) || matches_colormap(cmap, hsv(n));
if ~tf && exist('turbo', 'file') == 2
    tf = matches_colormap(cmap, turbo(n));
end
end

function tf = matches_colormap(cmap_a, cmap_b)
tf = isequal(size(cmap_a), size(cmap_b)) && max(abs(cmap_a(:) - cmap_b(:))) < 1e-10;
end

