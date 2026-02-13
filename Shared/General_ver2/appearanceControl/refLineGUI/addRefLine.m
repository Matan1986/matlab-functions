function hLine = addRefLine(orientation, value, varargin)
% ADDREFLINE  Add a vertical or horizontal dashed reference line to an axes,
% including an optional label with position and offset control.
%
% -------------------------------------------------------------------------
% REQUIRED INPUTS
% -------------------------------------------------------------------------
% orientation  - Direction of the reference line.
%                Valid options:
%                    'x', 'vertical'     → Vertical line at x = value
%                    'y', 'horizontal'   → Horizontal line at y = value
%
% value        - Numeric value where the line will be placed.
%
% -------------------------------------------------------------------------
% OPTIONAL NAME–VALUE PAIRS
% -------------------------------------------------------------------------
% 'Axes'          - Axes handle to draw on.
%                   Default: gca
%
% 'LineStyle'     - Line style.
%                   Default: '--'
%                   Examples: '-', '--', ':', '-.'
%
% 'Color'         - Line color.
%                   Default: [0 0 0] (black)
%
% 'LineWidth'     - Thickness of the reference line.
%                   Default: 1.5
%
% 'Label'         - Text label appearing near the line.
%                   Default: '' (no label)
%
% 'LabelLocation' - Position of the label relative to the line.
%                   Vertical lines:
%                       'top' (default), 'middle', 'bottom'
%                   Horizontal lines:
%                       'right' (default), 'center', 'left'
%
% 'XOffset'       - Horizontal offset (in axis units) for the label.
%                   Default: 0
%
% 'YOffset'       - Vertical offset (in axis units) for the label.
%                   Default: 0
%
% -------------------------------------------------------------------------
% OUTPUT
% -------------------------------------------------------------------------
% hLine - Handle to the generated line (ConstantLine or line object).
%
% -------------------------------------------------------------------------
% EXAMPLES
% -------------------------------------------------------------------------
%  addRefLine('x', 5, 'Label', 'Critical', 'LabelLocation', 'middle');
%
%  addRefLine('y', 1e-3, 'Color', 'r', 'Label', 'Threshold', ...
%             'LabelLocation', 'left', 'YOffset', 0.02);
%
%  ax = subplot(2,1,1);
%  addRefLine('x', 0, 'Axes', ax, 'Color', [0 .6 0], ...
%             'Label', 'B=0', 'XOffset', 0.1);
%
% -------------------------------------------------------------------------

%% --- Parse inputs -------------------------------------------------------
p = inputParser;
validOrient = {'x','y','vertical','horizontal'};
addRequired(p,'orientation',@(s) any(strcmpi(s,validOrient)));
addRequired(p,'value',@isnumeric);

addParameter(p,'Axes', gca);
addParameter(p,'LineStyle','--');
addParameter(p,'Color',[0 0 0]);
addParameter(p,'LineWidth',1.5);
addParameter(p,'Label','');
addParameter(p,'LabelLocation','auto');
addParameter(p,'XOffset',0);
addParameter(p,'YOffset',0);

parse(p,orientation,value,varargin{:});
opt = p.Results;

ax = opt.Axes;
hold(ax,'on');

isVertical = any(strcmpi(opt.orientation,{'x','vertical'}));

%% --- Default label locations --------------------------------------------
if strcmpi(opt.LabelLocation,'auto')
    if isVertical
        opt.LabelLocation = 'top';
    else
        opt.LabelLocation = 'right';
    end
end

%% --- Draw the line (xline/yline if available) ----------------------------
supportsConstantLine = exist('xline','file') == 2;

if supportsConstantLine
    if isVertical
        hLine = xline(ax, opt.value, opt.LineStyle, ...
            'Color', opt.Color, 'LineWidth', opt.LineWidth);
    else
        hLine = yline(ax, opt.value, opt.LineStyle, ...
            'Color', opt.Color, 'LineWidth', opt.LineWidth);
    end
else
    % Fallback for older MATLAB versions
    if isVertical
        yl = ylim(ax);
        hLine = line(ax, [opt.value opt.value], yl, ...
            'LineStyle', opt.LineStyle, ...
            'Color', opt.Color, 'LineWidth', opt.LineWidth);
    else
        xl = xlim(ax);
        hLine = line(ax, xl, [opt.value opt.value], ...
            'LineStyle', opt.LineStyle, ...
            'Color', opt.Color, 'LineWidth', opt.LineWidth);
    end
end

%% --- Add label (with offset) --------------------------------------------
if ~isempty(opt.Label)

    if isVertical
        yl = ylim(ax);
        x = opt.value + opt.XOffset;

        switch lower(opt.LabelLocation)
            case 'top'
                y = yl(2) + opt.YOffset;
                halign = 'left';  valign = 'top';
            case 'middle'
                y = mean(yl) + opt.YOffset;
                halign = 'left';  valign = 'middle';
            case 'bottom'
                y = yl(1) + opt.YOffset;
                halign = 'left';  valign = 'bottom';
        end
    else
        xl = xlim(ax);
        y = opt.value + opt.YOffset;

        switch lower(opt.LabelLocation)
            case 'right'
                x = xl(2) + opt.XOffset;
                halign = 'right'; valign = 'bottom';
            case 'center'
                x = mean(xl) + opt.XOffset;
                halign = 'center'; valign = 'bottom';
            case 'left'
                x = xl(1) + opt.XOffset;
                halign = 'left';  valign = 'bottom';
        end
    end

    text(ax, x, y, opt.Label, ...
        'HorizontalAlignment', halign, ...
        'VerticalAlignment',   valign);
end

end
