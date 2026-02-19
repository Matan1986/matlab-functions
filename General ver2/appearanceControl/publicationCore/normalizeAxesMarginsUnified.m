function report = normalizeAxesMarginsUnified(figHandles, options)
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
    if ~isfield(options, 'debugGeometry') || isempty(options.debugGeometry)
        options.debugGeometry = false;
    end

    skipUIAxes = logical(options.SkipUIAxes);
    verbose = logical(options.Verbose);
    debugGeometry = logical(options.debugGeometry);

    report = struct();
    report.enabled = debugGeometry;
    report.figures = struct('figureHandle', {}, 'figureNumber', {}, 'figureName', {}, 'figureSizePx', {}, 'axes', {});

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

    if debugGeometry
        drawnow;
        report = i_collectDebugGeometryReport(contexts, report);
        i_printDebugGeometryReport(report);
    end

    if verbose
        fprintf('Unified normalization for %d figures (%d axes).\n', totalFiguresNormalized, totalAxesNormalized);
    end
end

function report = i_collectDebugGeometryReport(contexts, report)
    figRows = repmat(struct('figureHandle', gobjects(0,1), 'figureNumber', NaN, 'figureName', "", 'figureSizePx', [NaN NaN], 'axes', struct('axisHandle', gobjects(0,1), 'axisId', NaN, 'positionNorm', [NaN NaN NaN NaN], 'positionPx', [NaN NaN NaN NaN], 'tightInsetNorm', [NaN NaN NaN NaN], 'tightInsetPx', [NaN NaN NaN NaN], 'looseInsetNorm', [NaN NaN NaN NaN], 'looseInsetPx', [NaN NaN NaN NaN], 'xLabelPositionPx', [NaN NaN NaN], 'xLabelExtentPx', [NaN NaN NaN NaN], 'requiredBottomPxFromExtent', NaN, 'xLabelBottomFigPx', NaN, 'overflowPx', NaN)), 0, 1);

    for iFig = 1:numel(contexts)
        c = contexts(iFig);
        fig = c.fig;
        if isempty(fig) || ~isgraphics(fig, 'figure')
            continue;
        end

        figSizePx = i_getFigureSizePx(fig);
        figW = figSizePx(1);
        figH = figSizePx(2);

        axRows = repmat(struct('axisHandle', gobjects(0,1), 'axisId', NaN, 'positionNorm', [NaN NaN NaN NaN], 'positionPx', [NaN NaN NaN NaN], 'tightInsetNorm', [NaN NaN NaN NaN], 'tightInsetPx', [NaN NaN NaN NaN], 'looseInsetNorm', [NaN NaN NaN NaN], 'looseInsetPx', [NaN NaN NaN NaN], 'xLabelPositionPx', [NaN NaN NaN], 'xLabelExtentPx', [NaN NaN NaN NaN], 'requiredBottomPxFromExtent', NaN, 'xLabelBottomFigPx', NaN, 'overflowPx', NaN), 0, 1);

        for iAx = 1:numel(c.axes)
            ax = c.axes(iAx);
            if isempty(ax) || ~isgraphics(ax, 'axes')
                continue;
            end

            posNorm = [NaN NaN NaN NaN];
            tightNorm = [NaN NaN NaN NaN];
            looseNorm = [NaN NaN NaN NaN];
            posPx = [NaN NaN NaN NaN];
            tightPx = [NaN NaN NaN NaN];
            loosePx = [NaN NaN NaN NaN];
            xLabelPosPx = [NaN NaN NaN];
            xLabelExtentPx = [NaN NaN NaN NaN];
            requiredBottomPx = NaN;
            xLabelBottomFigPx = NaN;
            overflowPx = NaN;

            try
                oldAxUnits = ax.Units;
            catch
                oldAxUnits = 'normalized';
            end

            try
                ax.Units = 'normalized';
                posNorm = double(ax.Position);
                tightNorm = double(ax.TightInset);
                if isprop(ax, 'LooseInset')
                    looseNorm = double(ax.LooseInset);
                end
            catch
            end

            try
                ax.Units = oldAxUnits;
            catch
            end

            if numel(posNorm) >= 4 && isfinite(figW) && isfinite(figH) && figW > 0 && figH > 0
                posPx = [posNorm(1) * figW, posNorm(2) * figH, posNorm(3) * figW, posNorm(4) * figH];
            end
            if numel(tightNorm) >= 4 && isfinite(figW) && isfinite(figH) && figW > 0 && figH > 0
                tightPx = [tightNorm(1) * figW, tightNorm(2) * figH, tightNorm(3) * figW, tightNorm(4) * figH];
            end
            if numel(looseNorm) >= 4 && isfinite(figW) && isfinite(figH) && figW > 0 && figH > 0
                loosePx = [looseNorm(1) * figW, looseNorm(2) * figH, looseNorm(3) * figW, looseNorm(4) * figH];
            end

            try
                xl = ax.XLabel;
            catch
                xl = [];
            end

            if ~isempty(xl) && isgraphics(xl)
                xlUnitsOld = "";
                hasUnits = false;
                try
                    if isprop(xl, 'Units')
                        xlUnitsOld = string(xl.Units);
                        hasUnits = true;
                    end
                catch
                end

                try
                    if hasUnits
                        xl.Units = 'pixels';
                    end
                    if isprop(xl, 'Position')
                        xLabelPosPx = double(xl.Position);
                    end
                    if isprop(xl, 'Extent')
                        xLabelExtentPx = double(xl.Extent);
                    end
                catch
                end

                try
                    if hasUnits && strlength(xlUnitsOld) > 0
                        xl.Units = char(xlUnitsOld);
                    end
                catch
                end
            end

            if numel(xLabelExtentPx) >= 2 && isfinite(xLabelExtentPx(2))
                requiredBottomPx = max(0, -xLabelExtentPx(2));
            end

            if numel(posPx) >= 2 && numel(xLabelExtentPx) >= 2 && isfinite(posPx(2)) && isfinite(xLabelExtentPx(2))
                xLabelBottomFigPx = posPx(2) + xLabelExtentPx(2);
                overflowPx = max(0, -xLabelBottomFigPx);
            end

            axRow = struct();
            axRow.axisHandle = ax;
            axRow.axisId = i_handleId(ax);
            axRow.positionNorm = i_vec4(posNorm);
            axRow.positionPx = i_vec4(posPx);
            axRow.tightInsetNorm = i_vec4(tightNorm);
            axRow.tightInsetPx = i_vec4(tightPx);
            axRow.looseInsetNorm = i_vec4(looseNorm);
            axRow.looseInsetPx = i_vec4(loosePx);
            axRow.xLabelPositionPx = i_vec3(xLabelPosPx);
            axRow.xLabelExtentPx = i_vec4(xLabelExtentPx);
            axRow.requiredBottomPxFromExtent = requiredBottomPx;
            axRow.xLabelBottomFigPx = xLabelBottomFigPx;
            axRow.overflowPx = overflowPx;

            axRows(end+1,1) = axRow; %#ok<AGROW>
        end

        figRow = struct();
        figRow.figureHandle = fig;
        figRow.figureNumber = i_figureNumber(fig);
        figRow.figureName = i_figureName(fig);
        figRow.figureSizePx = figSizePx;
        figRow.axes = axRows;

        figRows(end+1,1) = figRow; %#ok<AGROW>
    end

    report.figures = figRows;
end

function i_printDebugGeometryReport(report)
    if ~isstruct(report) || ~isfield(report, 'figures') || isempty(report.figures)
        fprintf('[normalizeAxesMarginsUnified][debugGeometry] No eligible axes report rows.\n');
        return;
    end

    for i = 1:numel(report.figures)
        figRow = report.figures(i);
        sz = i_vec2(figRow.figureSizePx);
        fprintf('[normalizeAxesMarginsUnified][debugGeometry] figure=%s sizePx=[%.1f %.1f] axes=%d\n', ...
            char(i_figureLabel(figRow.figureNumber, figRow.figureName)), sz(1), sz(2), numel(figRow.axes));
        fprintf('  %-18s %-16s %-16s %-24s %-12s\n', 'AxisId', 'TightInsetPxB', 'LooseInsetPxB', 'requiredBottomPxFromExtent', 'overflowPx');
        for j = 1:numel(figRow.axes)
            r = figRow.axes(j);
            ti = i_vec4(r.tightInsetPx);
            li = i_vec4(r.looseInsetPx);
            fprintf('  %-18.17g %-16.3f %-16.3f %-24.3f %-12.3f\n', ...
                r.axisId, ti(2), li(2), r.requiredBottomPxFromExtent, r.overflowPx);
        end
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
                    % Clamp normalized bbox to [0,1] frame before write.
                    bboxClamped = i_clampNormalizedRect(bbox);
                    ax.Units = 'normalized';
                    ax.Position = bboxClamped;
                    i_correctBottomOuterOverflow(ax);
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
                    % Clamp normalized bbox to [0,1] frame before write.
                    pNewClamped = i_clampNormalizedRect(pNew);
                    ax.Units = 'normalized';
                    ax.Position = pNewClamped;
                    i_correctBottomOuterOverflow(ax);
                catch
                end
            end
        end
    end
end

function i_correctBottomOuterOverflow(ax)
    if isempty(ax) || ~isgraphics(ax, 'axes')
        return;
    end

    try
        outerPos = double(ax.OuterPosition);
    catch
        return;
    end

    if numel(outerPos) < 2 || ~isfinite(outerPos(2)) || outerPos(2) >= 0
        return;
    end

    delta = -outerPos(2);

    try
        posNow = double(ax.Position);
        if numel(posNow) < 4 || any(~isfinite(posNow(1:4)))
            return;
        end
        posAdjusted = posNow;
        posAdjusted(2) = posAdjusted(2) + delta;
        posAdjusted = i_clampNormalizedRect(posAdjusted);
        ax.Position = posAdjusted;
    catch
    end
end

function out = i_clampNormalizedRect(inRect)
    out = [0 0 0 0];
    if ~isnumeric(inRect) || numel(inRect) < 4
        return;
    end

    left = double(inRect(1));
    bottom = double(inRect(2));
    width = double(inRect(3));
    height = double(inRect(4));

    left = max(0, left);
    bottom = max(0, bottom);

    width = max(0, width);
    height = max(0, height);

    width = min(width, 1 - left);
    height = min(height, 1 - bottom);

    out = [left, bottom, width, height];
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

function id = i_handleId(h)
    id = NaN;
    try
        id = double(h);
    catch
    end
end

function out = i_figureNumber(fig)
    out = NaN;
    try
        out = double(fig.Number);
    catch
    end
end

function out = i_figureName(fig)
    out = "";
    try
        out = string(fig.Name);
    catch
    end
end

function out = i_figureLabel(figNumber, figName)
    out = "#?";
    if isfinite(figNumber)
        out = "#" + string(figNumber);
    end
    if strlength(strtrim(figName)) > 0
        out = out + " " + figName;
    end
end

function sz = i_getFigureSizePx(fig)
    sz = [NaN NaN];
    if isempty(fig) || ~isgraphics(fig, 'figure')
        return;
    end
    oldUnits = "";
    try
        oldUnits = string(fig.Units);
    catch
    end
    try
        fig.Units = 'pixels';
        pos = double(fig.Position);
        if isnumeric(pos) && numel(pos) >= 4 && isfinite(pos(3)) && isfinite(pos(4))
            sz = [pos(3) pos(4)];
        end
    catch
    end
    try
        if strlength(oldUnits) > 0
            fig.Units = char(oldUnits);
        end
    catch
    end
end

function v = i_vec2(x)
    v = [NaN NaN];
    if isnumeric(x) && numel(x) >= 2
        v = double(x(1:2));
    end
end

function v = i_vec3(x)
    v = [NaN NaN NaN];
    if isnumeric(x) && numel(x) >= 3
        v = double(x(1:3));
    end
end

function v = i_vec4(x)
    v = [NaN NaN NaN NaN];
    if isnumeric(x) && numel(x) >= 4
        v = double(x(1:4));
    end
end
