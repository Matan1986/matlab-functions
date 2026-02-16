function [ax, textValue, presetName] = resolveAxesTextPresetArgs(varargin)
if nargin < 1 || nargin > 3
    error('resolveAxesTextPresetArgs:InvalidArgCount', 'Expected 1 to 3 inputs.');
end

presetName = 'paper';

switch nargin
    case 1
        ax = resolveCurrentAxesNoCreate();
        textValue = varargin{1};
    case 2
        if isAxesHandle(varargin{1})
            ax = varargin{1};
            textValue = varargin{2};
        else
            ax = resolveCurrentAxesNoCreate();
            textValue = varargin{1};
            presetName = varargin{2};
        end
    case 3
        ax = varargin{1};
        textValue = varargin{2};
        presetName = varargin{3};
end

validateAxesHandle(ax);
validateLabelText(textValue);
validatePresetName(presetName);
end

function ax = resolveCurrentAxesNoCreate()
fig = get(groot, 'CurrentFigure');
if isempty(fig) || ~isgraphics(fig, 'figure')
    error('resolveAxesTextPresetArgs:NoCurrentAxes', 'No current axes found and no axes handle was provided.');
end

ax = get(fig, 'CurrentAxes');
if isempty(ax) || ~isgraphics(ax, 'axes')
    error('resolveAxesTextPresetArgs:NoCurrentAxes', 'No current axes found and no axes handle was provided.');
end
end

function tf = isAxesHandle(value)
tf = isscalar(value) && isgraphics(value, 'axes');
end

function validateAxesHandle(ax)
if ~(isscalar(ax) && isgraphics(ax, 'axes'))
    error('resolveAxesTextPresetArgs:InvalidAxes', 'First input must be a valid axes handle.');
end
end

function validateLabelText(textValue)
if isstring(textValue)
    if ~isscalar(textValue)
        error('resolveAxesTextPresetArgs:InvalidText', 'Text input must be char, string scalar, or cellstr.');
    end
    return;
end

if ischar(textValue)
    return;
end

if iscellstr(textValue)
    return;
end

error('resolveAxesTextPresetArgs:InvalidText', 'Text input must be char, string scalar, or cellstr.');
end

function validatePresetName(presetName)
if isstring(presetName)
    if ~isscalar(presetName)
        error('resolveAxesTextPresetArgs:InvalidPresetName', 'Preset name must be a scalar string or char.');
    end
    return;
end

if ~ischar(presetName)
    error('resolveAxesTextPresetArgs:InvalidPresetName', 'Preset name must be a scalar string or char.');
end
end
