cb = findall(gcf,'Type','colorbar');
if isempty(cb); return; end

% נועל טיקים
cb.TicksMode = 'manual';
cb.Ticks = 4:4:34;

% LaTeX tick labels (אמיתי)
cb.TickLabels = arrayfun(@(x) sprintf('$%d$',x), cb.Ticks, ...
                          'UniformOutput', false);

% LaTeX renderer
cb.TickLabelInterpreter = 'latex';

% גודל פונט
cb.FontSize = 24;

% קריטי ל-horizontal colorbar
cb.AxisLocation  = 'out';
cb.TickDirection = 'out';
