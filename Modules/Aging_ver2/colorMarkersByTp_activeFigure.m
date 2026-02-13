function colorMarkersByTp_activeFigure(Tp, cmapName)
% ------------------------------------------------------------
% Rebuilds ALL data lines in active figure:
% • replaces original lines
% • redraws grey guide lines
% • redraws colored markers by Tp (cmocean)
% • works with multiple subplots safely
% ------------------------------------------------------------

if nargin < 2 || isempty(cmapName)
    cmapName = 'thermal';
end

Tp = Tp(:)';
Tp_unique = unique(Tp,'stable');

% ---- colormap ----
cmap = cmocean(cmapName,256);
Tp_norm = (Tp_unique - min(Tp_unique)) ./ ...
          (max(Tp_unique) - min(Tp_unique) + eps);
idx = round(1 + Tp_norm*(size(cmap,1)-1));
Tp_colors = cmap(idx,:);

fig = gcf;
axList = findall(fig,'Type','axes');

for a = 1:numel(axList)

    ax = axList(a);
    hold(ax,'on');

    % --- find candidate data lines ---
    hLines = findall(ax,'Type','line');

    for h = 1:numel(hLines)

        X = hLines(h).XData;
        Y = hLines(h).YData;

        % skip junk / single-point / non-data
        if numel(X) < 2 || numel(X) ~= numel(Y)
            continue;
        end

        % remove original line
        delete(hLines(h));

        % redraw grey guide line
        plot(ax, X, Y, '-', ...
            'Color',[0.45 0.45 0.45], ...
            'LineWidth',2.0);

        % redraw colored markers
        for i = 1:numel(X)
            [tf, loc] = ismember(X(i), Tp_unique);
            if ~tf, continue; end

            plot(ax, X(i), Y(i), 'o', ...
                'MarkerSize',7, ...
                'MarkerFaceColor',Tp_colors(loc,:), ...
                'MarkerEdgeColor','k', ...
                'LineWidth',0.8, ...
                'LineStyle','none');
        end
    end

    % --- enforce X axis ---
    ax.XLim  = [min(Tp_unique)-1, max(Tp_unique)+1];
    ax.XTick = Tp_unique;
    ax.TickLabelInterpreter = 'tex';
end

end
