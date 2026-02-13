%% Convert entire figure to PRB-style (fixed legend version)

fig = gcf;

% -- Use LaTeX everywhere --
set(findall(fig,'-property','Interpreter'), 'Interpreter', 'latex');
set(findall(fig,'-property','TickLabelInterpreter'), 'TickLabelInterpreter', 'latex');

% -- Use Times font for APS style --
set(findall(fig,'-property','FontName'), 'FontName', 'Times');

% -- Set consistent font size --
set(findall(fig,'-property','FontSize'), 'FontSize', 16);

% -- Thinner axes lines --
set(findall(fig,'type','axes'), 'LineWidth', 1);

% ------------------------
%  FIX LEGEND COMPLETELY
% ------------------------
lg = findall(fig,'type','legend');

if ~isempty(lg)
    % Fix the legend strings to proper LaTeX
    correctStrings = { ...
        '$\Delta\rho_{\perp}/\rho_{\parallel}\ (\%)$', ...
        '$\Delta\rho_{\parallel}/\rho_{\parallel}\ (\%)$' ...
    };

    lg.String = correctStrings;
    lg.Interpreter = 'latex';
    lg.FontSize = 16;
    lg.Box = 'off';
    lg.Location = 'best';
end

% ------------------------
%  Fix axis labels
% ------------------------
xlabel('$\mathrm{Angle\ (^\circ)}$','FontSize',18,'Interpreter','latex');
ylabel('$\Delta\rho_{\parallel,\perp}/\rho_{\parallel}\ (\%)$','FontSize',18,'Interpreter','latex');
