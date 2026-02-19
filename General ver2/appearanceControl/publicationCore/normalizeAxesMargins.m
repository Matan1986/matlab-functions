function normalizeAxesMargins(figHandles, options)
% NORMALIZEAXESMARGINS  Stateless publication margin normalization primitive.
%
% This is the new publication baseline primitive.
% It replaces legacy geometry engines for new layout normalization work.
% It is safe for single-axes and subplot-based figures only.
% It is intentionally not tiledlayout-aware.
%
% Usage:
%   normalizeAxesMargins(figHandles)
%   normalizeAxesMargins(figHandles, struct('SkipUIAxes', true, 'Verbose', false))
%
% Inputs:
%   figHandles : Explicit array/cell array of figure handles.
%   options    : Optional struct with fields:
%                .SkipUIAxes (default = true)
%                .Verbose    (default = false)
%
% Policies enforced:
% - No gcf usage.
% - No limits, legends, or export settings are modified.
% - Tiled layout figures are rejected.
% - UIAxes are skipped or rejected based on policy.

    if nargin < 1
        error('normalizeAxesMargins:MissingInput', 'figHandles is required.');
    end
    if nargin < 2 || isempty(options)
        options = struct();
    end
    if ~isstruct(options)
        error('normalizeAxesMargins:InvalidOptions', 'options must be a struct.');
    end

    if ~isfield(options, 'SkipUIAxes') || isempty(options.SkipUIAxes)
        options.SkipUIAxes = true;
    end
    if ~isfield(options, 'Verbose') || isempty(options.Verbose)
        options.Verbose = false;
    end

    skipUIAxes = logical(options.SkipUIAxes);
    verbose = logical(options.Verbose);

    figList = i_normalizeFigureInput(figHandles);

    % Validate-first preflight: reject unsupported figure policies before
    % any geometry writes occur.
    i_preflightFigures(figList, skipUIAxes);

    totalFiguresNormalized = 0;
    totalAxesNormalized = 0;

    for k = 1:numel(figList)
        fig = figList(k);

        if ~isgraphics(fig)
            continue;
        end
        if ~isgraphics(fig, 'figure')
            error('normalizeAxesMargins:InvalidHandle', 'figHandles must contain graphics figure handles.');
        end

        if i_hasTiledLayout(fig)
            error('normalizeAxesMargins:TiledLayoutUnsupported', 'Tiled layout detected — not supported.');
        end

        uiAxesList = i_findUIAxes(fig);
        if ~isempty(uiAxesList)
            if skipUIAxes
                % Allowed by policy: skip UIAxes and continue with classic axes only.
            else
                error('normalizeAxesMargins:UIAxesUnsupported', 'UIAxes detected — unsupported in current policy.');
            end
        end

        classicAxes = findall(fig, 'Type', 'axes');
        primaryAxes = gobjects(0,1);
        for iAx = 1:numel(classicAxes)
            ax = classicAxes(iAx);
            if ~isgraphics(ax, 'axes')
                continue;
            end
            if i_isPrimaryPlotAxes(ax, fig)
                primaryAxes(end+1,1) = ax; %#ok<AGROW>
            end
        end

        if isempty(primaryAxes)
            error('normalizeAxesMargins:NoPrimaryAxes', 'No primary axes found.');
        end

        drawnow;

        allTightInsets = zeros(0,4);
        validAxes = gobjects(0,1);
        validPositions = zeros(0,4);

        for iAx = 1:numel(primaryAxes)
            ax = primaryAxes(iAx);
            if ~isgraphics(ax, 'axes')
                continue;
            end

            try
                ax.Units = 'normalized';
                pos = double(ax.Position);
                drawnow;
                ti = double(ax.TightInset);
            catch
                continue;
            end

            if numel(pos) < 4 || any(~isfinite(pos(1:4)))
                continue;
            end

            if numel(ti) < 4 || any(~isfinite(ti(1:4)))
                continue;
            end

            validAxes(end+1,1) = ax; %#ok<AGROW>
            validPositions(end+1,:) = pos(1:4); %#ok<AGROW>
            allTightInsets(end+1,:) = ti(1:4); %#ok<AGROW>
        end

        if isempty(validAxes)
            error('normalizeAxesMargins:NoPrimaryAxes', 'No primary axes found.');
        end

        leftMargin = max(allTightInsets(:,1));
        bottomMargin = max(allTightInsets(:,2));
        rightMargin = max(allTightInsets(:,3));
        topMargin = max(allTightInsets(:,4));

        bboxNew = [ ...
            leftMargin, ...
            bottomMargin, ...
            1 - leftMargin - rightMargin, ...
            1 - bottomMargin - topMargin];

        if any(~isfinite(bboxNew)) || bboxNew(3) <= 0 || bboxNew(4) <= 0
            error('normalizeAxesMargins:InvalidDrawableArea', 'Computed drawable area is non-positive.');
        end

        isGroupMode = numel(validAxes) > 1;
        if isGroupMode
            leftOld = min(validPositions(:,1));
            bottomOld = min(validPositions(:,2));
            rightOld = max(validPositions(:,1) + validPositions(:,3));
            topOld = max(validPositions(:,2) + validPositions(:,4));

            bboxOldWidth = rightOld - leftOld;
            bboxOldHeight = topOld - bottomOld;
            if ~isfinite(bboxOldWidth) || ~isfinite(bboxOldHeight) || bboxOldWidth <= 0 || bboxOldHeight <= 0
                error('normalizeAxesMargins:InvalidAxesGroupBounds', 'Primary axes group bounds are non-positive.');
            end
        end

        % -------- First pass apply --------
        if ~isGroupMode
            ax = validAxes(1);
            if isgraphics(ax, 'axes')
                try
                    ax.Units = 'normalized';
                    ax.Position = bboxNew;
                catch
                end
            end
        else
            for iAx = 1:numel(validAxes)
                ax = validAxes(iAx);
                if ~isgraphics(ax, 'axes')
                    continue;
                end

                p = validPositions(iAx,:);
                rx = (p(1) - leftOld) / bboxOldWidth;
                ry = (p(2) - bottomOld) / bboxOldHeight;
                rw = p(3) / bboxOldWidth;
                rh = p(4) / bboxOldHeight;

                pNew = [ ...
                    bboxNew(1) + rx * bboxNew(3), ...
                    bboxNew(2) + ry * bboxNew(4), ...
                    rw * bboxNew(3), ...
                    rh * bboxNew(4)];

                try
                    ax.Units = 'normalized';
                    ax.Position = pNew;
                catch
                end
            end
        end

        drawnow;

        % -------- Second pass measure --------
        allTightInsets2 = zeros(0,4);
        for iAx = 1:numel(validAxes)
            ax = validAxes(iAx);
            if ~isgraphics(ax, 'axes')
                continue;
            end

            try
                ax.Units = 'normalized';
                ti2 = double(ax.TightInset);
            catch
                continue;
            end

            if numel(ti2) < 4 || any(~isfinite(ti2(1:4)))
                continue;
            end

            allTightInsets2(end+1,:) = ti2(1:4); %#ok<AGROW>
        end

        if isempty(allTightInsets2)
            error('normalizeAxesMargins:NoPrimaryAxes', 'No primary axes found.');
        end

        leftMargin2 = max(allTightInsets2(:,1));
        bottomMargin2 = max(allTightInsets2(:,2));
        rightMargin2 = max(allTightInsets2(:,3));
        topMargin2 = max(allTightInsets2(:,4));

        bboxNew2 = [ ...
            leftMargin2, ...
            bottomMargin2, ...
            1 - leftMargin2 - rightMargin2, ...
            1 - bottomMargin2 - topMargin2];

        if any(~isfinite(bboxNew2)) || bboxNew2(3) <= 0 || bboxNew2(4) <= 0
            error('normalizeAxesMargins:InvalidDrawableArea', 'Computed drawable area is non-positive.');
        end

        % -------- Optional second apply (deterministic, max two passes) --------
        if any(abs(bboxNew2 - bboxNew) > 1e-6)
            if ~isGroupMode
                ax = validAxes(1);
                if isgraphics(ax, 'axes')
                    try
                        ax.Units = 'normalized';
                        ax.Position = bboxNew2;
                    catch
                    end
                end
            else
                for iAx = 1:numel(validAxes)
                    ax = validAxes(iAx);
                    if ~isgraphics(ax, 'axes')
                        continue;
                    end

                    p = validPositions(iAx,:);
                    rx = (p(1) - leftOld) / bboxOldWidth;
                    ry = (p(2) - bottomOld) / bboxOldHeight;
                    rw = p(3) / bboxOldWidth;
                    rh = p(4) / bboxOldHeight;

                    pNew2 = [ ...
                        bboxNew2(1) + rx * bboxNew2(3), ...
                        bboxNew2(2) + ry * bboxNew2(4), ...
                        rw * bboxNew2(3), ...
                        rh * bboxNew2(4)];

                    try
                        ax.Units = 'normalized';
                        ax.Position = pNew2;
                    catch
                    end
                end
            end
        end

        totalFiguresNormalized = totalFiguresNormalized + 1;
        totalAxesNormalized = totalAxesNormalized + numel(validAxes);
    end

    if verbose
        fprintf('Normalized margins for %d figures (%d axes).\n', totalFiguresNormalized, totalAxesNormalized);
    end
end

function figList = i_normalizeFigureInput(figHandles)
    if iscell(figHandles)
        figHandles = [figHandles{:}];
    end

    figHandles = figHandles(:);
    if isempty(figHandles)
        figList = gobjects(0,1);
        return;
    end

    figList = gobjects(0,1);
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    for k = 1:numel(figHandles)
        h = figHandles(k);

        if ~isgraphics(h)
            % Gracefully skip deleted/invalid handles.
            continue;
        end

        if ~isgraphics(h, 'figure')
            error('normalizeAxesMargins:InvalidHandle', 'figHandles must contain graphics figure handles.');
        end

        key = i_handleKey(h);
        if ~isKey(seen, key)
            seen(key) = true;
            figList(end+1,1) = h; %#ok<AGROW>
        end
    end
end

function i_preflightFigures(figList, skipUIAxes)
    for k = 1:numel(figList)
        fig = figList(k);

        if ~isgraphics(fig)
            continue;
        end
        if ~isgraphics(fig, 'figure')
            error('normalizeAxesMargins:InvalidHandle', 'figHandles must contain graphics figure handles.');
        end

        if i_hasTiledLayout(fig)
            error('normalizeAxesMargins:TiledLayoutUnsupported', 'Tiled layout detected — not supported.');
        end

        uiAxesList = i_findUIAxes(fig);
        if ~isempty(uiAxesList) && ~skipUIAxes
            error('normalizeAxesMargins:UIAxesUnsupported', 'UIAxes detected — unsupported in current policy.');
        end
    end
end

function tf = i_hasTiledLayout(fig)
    tf = false;
    if isempty(fig) || ~isgraphics(fig, 'figure')
        return;
    end

    try
        tl = findall(fig, '-isa', 'matlab.graphics.layout.TiledChartLayout');
        tf = ~isempty(tl);
    catch
        tf = false;
    end
end

function uiAxesList = i_findUIAxes(fig)
    uiAxesList = gobjects(0,1);
    if isempty(fig) || ~isgraphics(fig, 'figure')
        return;
    end

    try
        uiAxesList = findall(fig, '-isa', 'matlab.ui.control.UIAxes');
    catch
        uiAxesList = gobjects(0,1);
    end
end

function tf = i_isPrimaryPlotAxes(ax, fig)
    tf = false;
    if isempty(ax) || ~isgraphics(ax, 'axes')
        return;
    end

    if nargin < 2
        fig = ancestor(ax, 'figure');
    end

    tagVal = "";
    try
        tagVal = lower(strtrim(string(ax.Tag)));
    catch
    end

    if tagVal == "plotsmtcombinedmanuallegendaxes"
        return;
    end

    try
        if ~isempty(fig) && isgraphics(fig, 'figure') && isappdata(fig, 'PlotsMTCombinedLegendAxesHandle')
            legendAx = getappdata(fig, 'PlotsMTCombinedLegendAxesHandle');
            if ~isempty(legendAx) && isgraphics(legendAx, 'axes') && isequal(ax, legendAx)
                return;
            end
        end
    catch
    end

    if contains(tagVal, "legend") || contains(tagVal, "colorbar")
        return;
    end

    if ~i_hasPlottableChildren(ax)
        return;
    end

    tf = true;
end

function tf = i_hasPlottableChildren(ax)
    tf = false;
    if isempty(ax) || ~isgraphics(ax, 'axes')
        return;
    end

    kids = allchild(ax);
    if isempty(kids)
        return;
    end

    plottableTypes = [ ...
        "line", "scatter", "bar", "histogram", "stem", "area", ...
        "patch", "surface", "image", "contour", "functionline", ...
        "errorbar", "quiver", "heatmap", "hggroup"];

    for i = 1:numel(kids)
        h = kids(i);
        if ~isgraphics(h)
            continue;
        end

        hType = "";
        try
            hType = lower(string(get(h, 'Type')));
        catch
        end

        if any(hType == plottableTypes)
            tf = true;
            return;
        end

        % Fallback: charts and graphics groups with children count as data-bearing.
        try
            cls = lower(string(class(h)));
            if contains(cls, "chart") || contains(cls, "primitive")
                tf = true;
                return;
            end
        catch
        end
    end
end

function key = i_handleKey(h)
    key = "";
    try
        key = string(sprintf('%.17g', double(h)));
    catch
        key = "";
    end
    key = char(key);
end
