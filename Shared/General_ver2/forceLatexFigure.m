function forceLatexFigure(fig)
% forceLatexFigure
% Applies LaTeX ONLY where physics lives:
%   - YLabel
%   - Legend
%   - Text objects
% NEVER touches:
%   - XLabel
%   - TickLabelInterpreter

if nargin < 1 || isempty(fig) || ~ishandle(fig)
    return;
end

% -------- axes handling --------
axesList = findall(fig,'Type','axes');
for ax = axesList.'

    % Y label = physics → LaTeX allowed
    if isprop(ax,'YLabel') && isprop(ax.YLabel,'Interpreter')
        ax.YLabel.Interpreter = 'latex';
    end

    % X label = scale → FORCE TEX
    if isprop(ax,'XLabel') && isprop(ax.XLabel,'Interpreter')
        ax.XLabel.Interpreter = 'tex';
    end

    % Ticks are OFF-LIMITS
    ax.TickLabelInterpreter = 'tex';
end

% -------- legends --------
set(findall(fig,'Type','legend'), 'Interpreter','latex');

% -------- text objects (EXCEPT colorbar labels) --------
txt = findall(fig,'Type','text');
for t = txt.'
    % skip colorbar labels
    if isa(t.Parent,'matlab.graphics.illustration.ColorBar')
        continue;
    end
    t.Interpreter = 'latex';
end

end
