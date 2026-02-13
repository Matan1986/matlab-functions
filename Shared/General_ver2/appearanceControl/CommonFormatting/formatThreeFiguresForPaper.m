function formatThreeFiguresForPaper(outputNames)
% formatThreeFiguresForPaper
%
% Automatically formats the *three currently open figures* for PRL/PRB
% quality export. Enlarged fonts, thicker lines, clean legends, and
% high-resolution PNG export.
%
% Usage:
%   formatThreeFiguresForPaper({'figA.png','figB.png','figC.png'})
%
% If outputNames is not given: auto-names them fig1.png, fig2.png, fig3.png.

    if nargin < 1
        outputNames = {'fig1.png','fig2.png','fig3.png'};
    end

    figs = findall(groot, 'Type', 'figure');

    if numel(figs) < 3
        error('You must have at least 3 open figures.');
    end

    % Take newest 3 figures by creation order
    figs = flipud(figs);     % reverse to get last opened first
    figs = figs(1:3);

    % Formatting parameters
    tickFont   = 16;
    labelFont  = 20;
    legendFont = 18;
    lineWidth  = 2.5;

    for k = 1:3
        f = figs(k);
        figure(f);  % activate

        ax = findall(f, 'Type', 'axes');

        for a = 1:numel(ax)
            set(ax(a), 'FontSize', tickFont, ...
                       'LineWidth', 1.8, ...
                       'Box', 'on');

            % Axis labels
            if ~isempty(ax(a).XLabel.String)
                ax(a).XLabel.FontSize = labelFont;
            end
            if ~isempty(ax(a).YLabel.String)
                ax(a).YLabel.FontSize = labelFont;
            end

            % Legends
            lg = findall(ax(a), 'Type', 'Legend');
            for L = 1:numel(lg)
                set(lg(L), 'FontSize', legendFont, 'Box', 'off');
            end

            % Line widths
            lines = findall(ax(a), 'Type', 'Line');
            set(lines, 'LineWidth', lineWidth);

        end

        % Export high-quality PNG
        exportgraphics(f, outputNames{k}, ...
            'Resolution', 300, ...
            'BackgroundColor', 'white');

        fprintf("Saved figure %d as %s\n", k, outputNames{k});
    end

end
