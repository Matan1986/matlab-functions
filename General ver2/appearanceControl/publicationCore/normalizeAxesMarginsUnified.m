function normalizeAxesMarginsUnified(figHandles, options)
% NORMALIZEAXESMARGINSUNIFIED  Unified publication margin normalization.
%
% Normalizes a list of figures together so all figures receive the same
% drawable axes box while preserving subplot-grid relative geometry.
%
% Policies:
% - Explicit figure handles only (no gcf)
% - Fail-fast on tiledlayout
% - UIAxes skip policy (error when SkipUIAxes=false)
% - Skip known manual legend axes (tag/appdata)
% - Stateless, deterministic, no listeners/callbacks
% - Does not modify limits, legends, or export settings
%
% Usage:
%   normalizeAxesMarginsUnified(figHandles)
%   normalizeAxesMarginsUnified(figHandles, struct('SkipUIAxes', true, 'Verbose', false))

    if nargin < 1 || isempty(figHandles)
        error('normalizeAxesMarginsUnified:MissingInput', 'figHandles is required and cannot be empty.');
    end
    if nargin < 2 || isempty(options)
        options = struct();
    end
    if ~isstruct(options)
        error('normalizeAxesMarginsUnified:InvalidOptions', 'options must be a struct.');
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
    if isempty(figList)
        error('normalizeAxesMarginsUnified:EmptyInput', 'No valid figure handles provided.');
    end

    i_preflightFigures(figList, skipUIAxes);

    ctxTemplate = struct( ...
        'fig', gobjects(0,1), ...
        'axes', gobjects(0,1), ...
        'positions', zeros(0,4), ...
        'isGroupMode', false, ...
        'leftOld', 0, ...
        'bottomOld', 0, ...
        'bboxOldWidth', 1, ...
        'bboxOldHeight', 1);

    contexts = repmat(ctxTemplate, 0, 1);
    allTightInsetsGlobal = zeros(0,4);

    for k = 1:numel(figList)
        fig = figList(k);

        if ~isgraphics(fig)
            continue;
        end
        if ~isgraphics(fig, 'figure')
            error('normalizeAxesMarginsUnified:InvalidHandle', 'figHandles must contain graphics figure handles.');
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
            error('normalizeAxesMarginsUnified:NoPrimaryAxes', 'No primary axes found.');
        end

        drawnow;

        validAxes = gobjects(0,1);
        validPositions = zeros(0,4);
        figTightInsets = zeros(0,4);

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
            figTightInsets(end+1,:) = ti(1:4); %#ok<AGROW>
        end

        if isempty(validAxes)
            error('normalizeAxesMarginsUnified:NoPrimaryAxes', 'No primary axes found.');
        end

        allTightInsetsGlobal = [allTightInsetsGlobal; figTightInsets]; %#ok<AGROW>

        c = ctxTemplate;
        c.fig = fig;
        c.axes = validAxes;
        c.positions = validPositions;
        c.isGroupMode = numel(validAxes) > 1;

        if c.isGroupMode
            leftOld = min(validPositions(:,1));
            bottomOld = min(validPositions(:,2));
            rightOld = max(validPositions(:,1) + validPositions(:,3));
            topOld = max(validPositions(:,2) + validPositions(:,4));

            bboxOldWidth = rightOld - leftOld;
            bboxOldHeight = topOld - bottomOld;
            if ~isfinite(bboxOldWidth) || ~isfinite(bboxOldHeight) || bboxOldWidth <= 0 || bboxOldHeight <= 0
                error('normalizeAxesMarginsUnified:InvalidAxesGroupBounds', 'Primary axes group bounds are non-positive.');
            end

            c.leftOld = leftOld;
            c.bottomOld = bottomOld;
            c.bboxOldWidth = bboxOldWidth;
            c.bboxOldHeight = bboxOldHeight;
        end

        contexts(end+1,1) = c; %#ok<AGROW>
    end

    if isempty(allTightInsetsGlobal)
        error('normalizeAxesMarginsUnified:NoPrimaryAxes', 'No primary axes found.');
    end

    leftMargin = max(allTightInsetsGlobal(:,1));
    bottomMargin = max(allTightInsetsGlobal(:,2));
    rightMargin = max(allTightInsetsGlobal(:,3));
    topMargin = max(allTightInsetsGlobal(:,4));

    % Compensates for TightInset underestimation in multiline rotated labels.
    publicationSafety = 0.003;  % ~0.3% normalized units
    leftMargin = leftMargin + publicationSafety;
    bottomMargin = bottomMargin + publicationSafety;
    rightMargin = rightMargin + publicationSafety;
    topMargin = topMargin + publicationSafety;

    bboxNew = [ ...
        leftMargin, ...
        bottomMargin, ...
        1 - leftMargin - rightMargin, ...
        1 - bottomMargin - topMargin];

    if any(~isfinite(bboxNew)) || bboxNew(3) <= 0 || bboxNew(4) <= 0
        error('normalizeAxesMarginsUnified:InvalidDrawableArea', 'Computed drawable area is non-positive.');
    end

    totalFiguresNormalized = 0;
    totalAxesNormalized = 0;

    for iFig = 1:numel(contexts)
        c = contexts(iFig);
        if isempty(c.axes)
            continue;
        end

        totalFiguresNormalized = totalFiguresNormalized + 1;
        totalAxesNormalized = totalAxesNormalized + numel(c.axes);
    end

    i_applyUnifiedBBox(contexts, bboxNew);
    drawnow;

    allTightInsetsGlobal2 = zeros(0,4);
    for iFig = 1:numel(contexts)
        c = contexts(iFig);
        if isempty(c.axes)
            continue;
        end

        for iAx = 1:numel(c.axes)
            ax = c.axes(iAx);
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

            allTightInsetsGlobal2(end+1,:) = ti2(1:4); %#ok<AGROW>
        end
    end

    if isempty(allTightInsetsGlobal2)
        error('normalizeAxesMarginsUnified:NoPrimaryAxes', 'No primary axes found.');
    end

    leftMargin2 = max(allTightInsetsGlobal2(:,1));
    bottomMargin2 = max(allTightInsetsGlobal2(:,2));
    rightMargin2 = max(allTightInsetsGlobal2(:,3));
    topMargin2 = max(allTightInsetsGlobal2(:,4));

    leftMargin2 = leftMargin2 + publicationSafety;
    bottomMargin2 = bottomMargin2 + publicationSafety;
    rightMargin2 = rightMargin2 + publicationSafety;
    topMargin2 = topMargin2 + publicationSafety;

    bboxNew2 = [ ...
        leftMargin2, ...
        bottomMargin2, ...
        1 - leftMargin2 - rightMargin2, ...
        1 - bottomMargin2 - topMargin2];

    if any(~isfinite(bboxNew2)) || bboxNew2(3) <= 0 || bboxNew2(4) <= 0
        error('normalizeAxesMarginsUnified:InvalidDrawableArea', 'Computed drawable area is non-positive.');
    end

    if any(abs(bboxNew2 - bboxNew) > 1e-6)
        i_applyUnifiedBBox(contexts, bboxNew2);
    end

    if verbose
        fprintf('Unified normalization for %d figures (%d axes).\n', totalFiguresNormalized, totalAxesNormalized);
    end
end

function i_applyUnifiedBBox(contexts, bbox)
    for iFig = 1:numel(contexts)
        c = contexts(iFig);
        if isempty(c.axes)
            continue;
        end

        if ~c.isGroupMode
            ax = c.axes(1);
            if isgraphics(ax, 'axes')
                try
                    ax.Units = 'normalized';
                    ax.Position = bbox;
                catch
                end
            end
        else
            for iAx = 1:numel(c.axes)
                ax = c.axes(iAx);
                if ~isgraphics(ax, 'axes')
                    continue;
                end

                p = c.positions(iAx,:);
                rx = (p(1) - c.leftOld) / c.bboxOldWidth;
                ry = (p(2) - c.bottomOld) / c.bboxOldHeight;
                rw = p(3) / c.bboxOldWidth;
                rh = p(4) / c.bboxOldHeight;

                pNew = [ ...
                    bbox(1) + rx * bbox(3), ...
                    bbox(2) + ry * bbox(4), ...
                    rw * bbox(3), ...
                    rh * bbox(4)];

                try
                    ax.Units = 'normalized';
                    ax.Position = pNew;
                catch
                end
            end
        end
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
            continue;
        end
        if ~isgraphics(h, 'figure')
            error('normalizeAxesMarginsUnified:InvalidHandle', 'figHandles must contain graphics figure handles.');
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
            error('normalizeAxesMarginsUnified:InvalidHandle', 'figHandles must contain graphics figure handles.');
        end

        if i_hasTiledLayout(fig)
            error('normalizeAxesMarginsUnified:TiledLayoutUnsupported', 'Tiled layout detected — not supported.');
        end

        uiAxesList = i_findUIAxes(fig);
        if ~isempty(uiAxesList) && ~skipUIAxes
            error('normalizeAxesMarginsUnified:UIAxesUnsupported', 'UIAxes detected — unsupported in current policy.');
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
