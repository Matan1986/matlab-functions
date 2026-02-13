function allowLatexTicks(fig)
% Explicit opt-in for LaTeX tick labels

if nargin < 1 || isempty(fig) || ~ishandle(fig)
    return;
end

axesList = findall(fig,'Type','axes');
for ax = axesList.'
    ax.TickLabelInterpreter = 'latex';
end
end
