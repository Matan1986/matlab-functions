function applyColormapToDataLines(fig, cmapName, reverseMap)
% applyColormapToDataLines  Color all DATA lines in an *open* figure using a chosen colormap.
%
% Usage (after the figure is open):
%   applyColormapToDataLines(gcf, "turbo");
%   applyColormapToDataLines(gcf, "parula", true);   % reversed
%
% Notes:
% - Works on an existing/open figure.
% - Colors Line objects that look like plotted data (has X/Y data with >1 point).
% - Also colors markers (MarkerEdgeColor/MarkerFaceColor) if they exist.
%
% Matan-style safe behavior: only touches colors, not axes/labels/ticks.

    if nargin < 1 || isempty(fig), fig = gcf; end
    if nargin < 2 || isempty(cmapName), cmapName = "turbo"; end
    if nargin < 3 || isempty(reverseMap), reverseMap = false; end

    if ~ishandle(fig) || ~strcmp(get(fig,'Type'),'figure')
        error('Input "fig" must be a valid figure handle (e.g., gcf).');
    end

    % Find candidate line objects in the figure
    axList = findall(fig, 'Type', 'axes');

    lines = gobjects(0,1);
    for ax = axList(:).'
        % Only lines that belong to this axes
        L = findall(ax, 'Type', 'line');

        for k = 1:numel(L)
            x = get(L(k),'XData');
            y = get(L(k),'YData');

            % Keep only "data-like" lines (not single-point, not empty)
            if isempty(x) || isempty(y), continue; end
            if numel(x) < 2 || numel(y) < 2, continue; end

            % Skip legend proxy lines if any slipped in
            if isprop(L(k),'Annotation') && isfield(L(k).Annotation,'LegendInformation')
                % keep it anyway; legend uses the real handle, so OK
            end

            lines(end+1,1) = L(k); %#ok<AGROW>
        end
    end

    if isempty(lines)
        warning('No data lines found in the figure.');
        return;
    end

    % Make a stable order (so colors are predictable):
    % sort by axes, then by creation order (approx: reverse of findall)
    lines = flipud(lines); % findall often returns reverse-creation; flip helps

    N = numel(lines);

    % Build colormap
    try
        cmap = feval(char(cmapName), max(N,2));
    catch
        error('Unknown colormap "%s". Try e.g. "parula","turbo","hot","gray","lines","jet".', cmapName);
    end
    if reverseMap
        cmap = flipud(cmap);
    end

    % Assign colors
    for i = 1:N
        c = cmap(i,:);

        set(lines(i), 'Color', c);

        % If the line has markers, color them too (without changing marker type/size)
        mk = get(lines(i), 'Marker');
        if ~strcmp(mk, 'none')
            try, set(lines(i), 'MarkerEdgeColor', c); end %#ok<TRYNC>
            try, set(lines(i), 'MarkerFaceColor', c); end %#ok<TRYNC>
        end
    end

    % Keep the figure's colormap consistent (optional but often nice)
    colormap(fig, cmap);

end