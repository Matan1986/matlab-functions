function applyAxisPolicy(varargin)
if nargin < 0 || nargin > 2
    error('applyAxisPolicy:InvalidArgCount', 'Expected 0 to 2 inputs.');
end

presetName = 'paper';

switch nargin
    case 0
        ax = resolveCurrentAxesNoCreateForAxisPolicy();
    case 1
        if isAxesHandleForAxisPolicy(varargin{1})
            ax = varargin{1};
        else
            ax = resolveCurrentAxesNoCreateForAxisPolicy();
            presetName = varargin{1};
        end
    case 2
        ax = varargin{1};
        presetName = varargin{2};
end

validateAxesForAxisPolicy(ax);
validatePresetNameForAxisPolicy(presetName);
style = getPlotStylePreset(presetName);

if isfield(style, 'axisBox')
    box(ax, style.axisBox);
end

if isfield(style, 'tickLabelInterpreter')
    ax.TickLabelInterpreter = style.tickLabelInterpreter;
end

if isfield(style, 'gridPolicy')
    gridMode = lower(style.gridPolicy);
    switch gridMode
        case 'on'
            grid(ax, 'on');
        case 'off'
            grid(ax, 'off');
            if isprop(ax, 'XMinorGrid')
                ax.XMinorGrid = 'off';
            end
            if isprop(ax, 'YMinorGrid')
                ax.YMinorGrid = 'off';
            end
            if isprop(ax, 'ZMinorGrid')
                ax.ZMinorGrid = 'off';
            end
        case 'minor'
            grid(ax, 'on');
            grid(ax, 'minor');
        case {'none', ''}
        otherwise
            error('applyAxisPolicy:InvalidGridPolicy', 'Unsupported gridPolicy value: %s', style.gridPolicy);
    end
end
end

function ax = resolveCurrentAxesNoCreateForAxisPolicy()
fig = get(groot, 'CurrentFigure');
if isempty(fig) || ~isgraphics(fig, 'figure')
    error('applyAxisPolicy:NoCurrentAxes', 'No current axes found and no axes handle was provided.');
end

ax = get(fig, 'CurrentAxes');
if isempty(ax) || ~isgraphics(ax, 'axes')
    error('applyAxisPolicy:NoCurrentAxes', 'No current axes found and no axes handle was provided.');
end
end

function tf = isAxesHandleForAxisPolicy(value)
tf = isscalar(value) && isgraphics(value, 'axes');
end

function validateAxesForAxisPolicy(ax)
if ~(isscalar(ax) && isgraphics(ax, 'axes'))
    error('applyAxisPolicy:InvalidAxes', 'First input must be a valid axes handle.');
end
end

function validatePresetNameForAxisPolicy(presetName)
if isstring(presetName)
    if ~isscalar(presetName)
        error('applyAxisPolicy:InvalidPresetName', 'Preset name must be a scalar string or char.');
    end
    return;
end

if ~ischar(presetName)
    error('applyAxisPolicy:InvalidPresetName', 'Preset name must be a scalar string or char.');
end
end
