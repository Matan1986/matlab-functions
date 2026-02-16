function h = applyXLabel(varargin)
[ax, textValue, presetName] = resolveAxesTextPresetArgs(varargin{:});
style = getPlotStylePreset(presetName);

h = xlabel(ax, textValue, ...
    'Interpreter', style.interpreter, ...
    'FontSize', style.fontSize, ...
    'FontWeight', style.fontWeight);
set(ax, 'TickLabelInterpreter', style.tickLabelInterpreter);
end
