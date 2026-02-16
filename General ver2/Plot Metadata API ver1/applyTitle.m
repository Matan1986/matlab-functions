function h = applyTitle(varargin)
[ax, textValue, presetName] = resolveAxesTextPresetArgs(varargin{:});
style = getPlotStylePreset(presetName);

titleFontSize = style.fontSize * style.titleFontSizeMultiplier;
h = title(ax, textValue, ...
    'Interpreter', style.interpreter, ...
    'FontSize', titleFontSize, ...
    'FontWeight', style.fontWeight);
set(ax, 'TickLabelInterpreter', style.tickLabelInterpreter);
end
