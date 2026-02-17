function h = applyYLabel(varargin)
[ax, textValue, presetName] = resolveAxesTextPresetArgs(varargin{:});
style = getPlotStylePreset(presetName);

h = ylabel(ax, textValue, ...
    'Interpreter', style.interpreter, ...
    'FontSize', style.fontSize, ...
    'FontWeight', style.fontWeight);
set(ax, 'TickLabelInterpreter', style.tickLabelInterpreter);
end
