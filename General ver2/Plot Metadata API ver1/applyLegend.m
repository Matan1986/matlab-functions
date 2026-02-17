function h = applyLegend(varargin)
if nargin < 1
    error('applyLegend:InvalidArgCount', 'Expected at least 1 input.');
end

presetName = 'paper';
legendArgs = varargin;

if numel(legendArgs) >= 2 && isTextScalarForLegend(legendArgs{end-1})
    key = lower(strtrim(char(string(legendArgs{end-1}))));
    if strcmp(key, 'preset') || strcmp(key, 'presetname')
        presetName = legendArgs{end};
        legendArgs = legendArgs(1:end-2);
    end
elseif numel(legendArgs) == 2 && ~isAxesHandleForLegend(legendArgs{1}) && isKnownPresetForLegend(legendArgs{2})
    presetName = legendArgs{2};
    legendArgs = legendArgs(1);
elseif numel(legendArgs) == 3 && isAxesHandleForLegend(legendArgs{1}) && isKnownPresetForLegend(legendArgs{3})
    presetName = legendArgs{3};
    legendArgs = legendArgs(1:2);
end

validatePresetNameForLegend(presetName);
style = getPlotStylePreset(presetName);

h = legend(legendArgs{:});
if ~isempty(h) && isgraphics(h, 'legend')
    set(h, 'Interpreter', 'latex');
    set(h, 'FontSize', style.fontSize);
end
end

function tf = isAxesHandleForLegend(value)
tf = isscalar(value) && isgraphics(value, 'axes');
end

function tf = isTextScalarForLegend(value)
tf = false;
if ischar(value)
    tf = true;
    return;
end
if isstring(value) && isscalar(value)
    tf = true;
end
end

function tf = isKnownPresetForLegend(candidate)
tf = false;
if ~(ischar(candidate) || (isstring(candidate) && isscalar(candidate)))
    return;
end

try
    getPlotStylePreset(candidate);
    tf = true;
catch
    tf = false;
end
end

function validatePresetNameForLegend(presetName)
if isstring(presetName)
    if ~isscalar(presetName)
        error('applyLegend:InvalidPresetName', 'Preset name must be a scalar string or char.');
    end
    return;
end

if ~ischar(presetName)
    error('applyLegend:InvalidPresetName', 'Preset name must be a scalar string or char.');
end
end
