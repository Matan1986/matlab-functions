function FCS_export(figHandles, exportOpts)
% FCS_export Export only explicitly provided figures.
% Enforces explicit targeting by iterating only figHandles (no all-open scans).
% Assumes print/exportgraphics/savefig availability; optionally reuses sanitizeFilename.

    if nargin < 2
        exportOpts = struct();
    end
    opts = i_parseExportOpts(exportOpts);

    figs = FCS_resolveTargets(struct('mode', 'explicitList', 'explicitList', figHandles, 'excludeKnownGUIs', false));
    if isempty(figs)
        return;
    end

    if ~exist(opts.outDir, 'dir')
        mkdir(opts.outDir);
    end

    for idx = 1:numel(figs)
        fig = figs(idx);
        baseName = i_buildBaseName(fig, idx, opts);
        if opts.sanitize
            baseName = i_sanitizeName(baseName);
        end
        if strlength(baseName) == 0
            baseName = "Figure_" + string(idx);
        end

        for f = opts.formats
            fmt = lower(string(f));
            outFile = fullfile(opts.outDir, char(baseName + "." + fmt));
            if ~opts.overwrite
                outFile = i_uniqueFilename(outFile);
            end

            switch fmt
                case "pdf"
                    % === PDF EXPORT DIAGNOSTICS AND FONT ENFORCEMENT ===
                    i_logExportDiagnostics(fig, fmt, opts.debugExport);
                    
                    if opts.normalizeFontsOnExport
                        [exportFontName, exportFontSize] = i_getExportFontSettings(fig);
                        
                        % Normalize fonts on axes
                        axAll = findall(fig, 'Type', 'axes');
                        for iAx = 1:numel(axAll)
                            if isprop(axAll(iAx), 'FontName')
                                axAll(iAx).FontName = exportFontName;
                            end
                            if isprop(axAll(iAx), 'FontSize')
                                axAll(iAx).FontSize = exportFontSize;
                            end
                        end
                        
                        % Normalize fonts on colorbars
                        cbAll = findall(fig, 'Type', 'colorbar');
                        for iCb = 1:numel(cbAll)
                            if isprop(cbAll(iCb), 'FontName')
                                cbAll(iCb).FontName = exportFontName;
                            end
                            if isprop(cbAll(iCb), 'FontSize')
                                cbAll(iCb).FontSize = exportFontSize;
                            end
                        end
                        
                        % Normalize fonts on text objects
                        txAll = findall(fig, 'Type', 'text');
                        for iTx = 1:numel(txAll)
                            if isprop(txAll(iTx), 'FontName')
                                txAll(iTx).FontName = exportFontName;
                            end
                            if isprop(txAll(iTx), 'FontSize')
                                txAll(iTx).FontSize = exportFontSize;
                            end
                        end
                    end
                    
                    % Synchronize PaperSize with figure dimensions
                    i_syncPaperSize(fig);
                    
                    if opts.vectorMode
                        try
                            print(fig, outFile, '-dpdf', '-painters');
                        catch
                            exportgraphics(fig, outFile, 'ContentType', 'vector');
                        end
                    else
                        exportgraphics(fig, outFile, 'ContentType', 'image', 'Resolution', 300);
                    end

                case "png"
                    % === PNG EXPORT ===
                    i_logExportDiagnostics(fig, fmt, opts.debugExport);
                    % Synchronize PaperSize with figure dimensions
                    i_syncPaperSize(fig);
                    exportgraphics(fig, outFile, 'Resolution', 300);

                case "fig"
                    % === FIG EXPORT DIAGNOSTICS AND FONT ENFORCEMENT ===
                    if iscell(fig)
                        error('FCS_export:InvalidFigureHandleType', 'savefig input fig must not be a cell array.');
                    end
                    if isstruct(fig)
                        error('FCS_export:InvalidFigureHandleType', 'savefig input fig must not be a struct.');
                    end

                    figList = fig;
                    for kFig = 1:numel(figList)
                        figOne = figList(kFig);
                        if ~isgraphics(figOne, 'figure')
                            error('FCS_export:InvalidFigureHandle', 'savefig input must be a valid figure handle.');
                        end

                        outFileK = outFile;
                        if numel(figList) > 1
                            [pK, nK, eK] = fileparts(outFile);
                            outFileK = fullfile(pK, sprintf('%s_%d%s', nK, kFig, eK));
                        end

                        % Log diagnostics for this figure
                        i_logExportDiagnostics(figOne, fmt, opts.debugExport);
                        
                        % Synchronize PaperSize with figure dimensions
                        i_syncPaperSize(figOne);
                        
                        % Font normalization for FIG export
                        if opts.normalizeFontsOnExport
                            [exportFontName, exportFontSize] = i_getExportFontSettings(figOne);
                            
                            % Normalize fonts on axes
                            axAll = findall(figOne, 'Type', 'axes');
                            for iAx = 1:numel(axAll)
                                if isprop(axAll(iAx), 'FontName')
                                    axAll(iAx).FontName = exportFontName;
                                end
                                if isprop(axAll(iAx), 'FontSize')
                                    axAll(iAx).FontSize = exportFontSize;
                                end
                            end
                            
                            % Normalize fonts on colorbars
                            cbAll = findall(figOne, 'Type', 'colorbar');
                            for iCb = 1:numel(cbAll)
                                if isprop(cbAll(iCb), 'FontName')
                                    cbAll(iCb).FontName = exportFontName;
                                end
                                if isprop(cbAll(iCb), 'FontSize')
                                    cbAll(iCb).FontSize = exportFontSize;
                                end
                            end
                            
                            % Normalize fonts on text objects
                            txAll = findall(figOne, 'Type', 'text');
                            for iTx = 1:numel(txAll)
                                if isprop(txAll(iTx), 'FontName')
                                    txAll(iTx).FontName = exportFontName;
                                end
                                if isprop(txAll(iTx), 'FontSize')
                                    txAll(iTx).FontSize = exportFontSize;
                                end
                            end
                        end

                        savefig(figOne, outFileK);
                    end

                otherwise
                    error('FCS_export:UnsupportedFormat', 'Unsupported format: %s', fmt);
            end
        end
    end
end

function exportModel = discoverScene(figOne, exportOpts)
    exportModel = struct();
    exportModel.figure = struct();
    exportModel.layout = discoverTiledLayout(figOne);
    exportModel.axes = struct('key', {}, 'srcHandle', {}, 'tag', {}, 'className', {}, 'isPrimary', {}, ...
        'isManualLegend', {}, 'isAuxiliary', {}, 'classificationReason', {}, 'positionNorm', {}, 'tileIndex', {}, ...
        'tileSpan', {}, 'axisProps', {}, 'children', {}, 'sortHandleId', {});
    exportModel.colorbars = struct('srcId', {}, 'hostAxesKey', {}, 'props', {});
    exportModel.legends = struct('srcId', {}, 'hostAxesKey', {}, 'entrySrcIds', {}, 'labels', {}, 'props', {});
    exportModel.annotations = struct('className', {}, 'props', {});
    exportModel.manualLegend = struct('axesKey', {}, 'positionNorm', {});
    exportModel.warnings = strings(0,1);

    exportModel.figure.sourceClass = string(class(figOne));
    exportModel.figure.name = i_figureNameSafe(figOne);
    exportModel.figure.color = i_getPropSafe(figOne, 'Color', [1 1 1]);
    exportModel.figure.renderer = i_getPropSafe(figOne, 'Renderer', 'painters');
    exportModel.figure.positionPixels = i_getFigurePositionPixels(figOne);
    exportModel.figure.colormap = i_getColormapSafe(figOne, []);

    axList = findall(figOne, 'Type', 'axes');
    for iAx = 1:numel(axList)
        ax = axList(iAx);
        if ~isgraphics(ax)
            continue;
        end

        [category, reason] = classifyAxes(ax, exportModel.layout);

        axModel = struct();
        axModel.key = i_handleKey(ax);
        axModel.srcHandle = ax;
        axModel.tag = string(i_getPropSafe(ax, 'Tag', ''));
        axModel.className = string(class(ax));
        axModel.isPrimary = strcmp(category, 'primary');
        axModel.isManualLegend = strcmp(category, 'manualLegend');
        axModel.isAuxiliary = strcmp(category, 'auxiliary');
        axModel.classificationReason = string(reason);
        axModel.positionNorm = i_getAxesPositionNorm(ax);
        [axModel.tileIndex, axModel.tileSpan] = i_getAxesTileInfo(ax);
        axModel.axisProps = i_captureAxesProps(ax);
        axModel.children = i_discoverAxesChildren(ax);
        axModel.sortHandleId = i_handleIdNumeric(ax);

        exportModel.axes(end+1,1) = axModel; %#ok<AGROW>

        if axModel.isManualLegend
            exportModel.manualLegend(end+1,1) = struct('axesKey', axModel.key, 'positionNorm', axModel.positionNorm); %#ok<AGROW>
        end
    end

    exportModel.axes = i_sortAxesModelsDeterministic(exportModel.axes, exportModel.layout);

    cbList = findall(figOne, 'Type', 'ColorBar');
    if isempty(cbList)
        cbList = findall(figOne, 'Type', 'colorbar');
    end
    for iCb = 1:numel(cbList)
        cb = cbList(iCb);
        hostAx = i_getPropSafe(cb, 'Axes', []);
        if isempty(hostAx) || ~isgraphics(hostAx, 'axes')
            continue;
        end
        hostKey = i_handleKey(hostAx);
        if ~i_axesKeyIsPrimary(exportModel.axes, hostKey)
            continue;
        end

        cbModel = struct();
        cbModel.srcId = i_handleKey(cb);
        cbModel.hostAxesKey = hostKey;
        cbModel.props = i_captureColorbarProps(cb);
        exportModel.colorbars(end+1,1) = cbModel; %#ok<AGROW>
    end

    lgList = findall(figOne, 'Type', 'Legend');
    if isempty(lgList)
        lgList = findall(figOne, 'Type', 'legend');
    end
    for iLg = 1:numel(lgList)
        lg = lgList(iLg);
        hostAx = i_getPropSafe(lg, 'Axes', []);
        if isempty(hostAx) || ~isgraphics(hostAx, 'axes')
            continue;
        end
        hostKey = i_handleKey(hostAx);
        if ~i_axesKeyIsPrimary(exportModel.axes, hostKey)
            continue;
        end

        entrySrcIds = strings(0,1);
        pc = i_getPropSafe(lg, 'PlotChildren', gobjects(0,1));
        for p = 1:numel(pc)
            if isgraphics(pc(p))
                entrySrcIds(end+1,1) = string(i_handleKey(pc(p))); %#ok<AGROW>
            end
        end

        labels = i_getLegendLabelsSafe(lg);
        lgModel = struct();
        lgModel.srcId = i_handleKey(lg);
        lgModel.hostAxesKey = hostKey;
        lgModel.entrySrcIds = entrySrcIds;
        lgModel.labels = labels;
        lgModel.props = i_captureLegendProps(lg);
        exportModel.legends(end+1,1) = lgModel; %#ok<AGROW>
    end

    shapeObjs = findall(figOne, '-regexp', 'Type', 'textboxshape|line|arrow|doubleendarrow|textarrow');
    if ~isempty(shapeObjs)
        exportModel.warnings(end+1,1) = "Figure annotations found; Stage-1 exporter currently skips annotation reconstruction.";
    end

    if nargin >= 2 && isstruct(exportOpts) && isfield(exportOpts, 'exportVerbose') && ~logical(exportOpts.exportVerbose)
        % Warnings are still recorded; emission is controlled elsewhere.
    end
end

function layoutModel = discoverTiledLayout(figOne)
    layoutModel = struct('mode', 'free', 'gridSize', [1 1], 'tileSpacing', 'none', 'padding', 'none');

    axList = findall(figOne, 'Type', 'axes');
    tileHit = false;
    for iAx = 1:numel(axList)
        ax = axList(iAx);
        [tileIdx, ~] = i_getAxesTileInfo(ax);
        if isfinite(tileIdx)
            tileHit = true;
            lay = i_findTiledLayoutParent(ax);
            if ~isempty(lay)
                gs = i_getPropSafe(lay, 'GridSize', [1 1]);
                ts = i_getPropSafe(lay, 'TileSpacing', 'none');
                pd = i_getPropSafe(lay, 'Padding', 'none');
                layoutModel.gridSize = double(gs);
                layoutModel.tileSpacing = ts;
                layoutModel.padding = pd;
            end
            break;
        end
    end

    if tileHit
        layoutModel.mode = 'tiled';
    end
end

function [category, reason] = classifyAxes(ax, layoutModel)
    tagVal = lower(strtrim(string(i_getPropSafe(ax, 'Tag', ''))));
    if tagVal == "mt_legend_axes"
        category = 'manualLegend';
        reason = 'tag:MT_Legend_Axes';
        return;
    end

    visible = strcmpi(char(string(i_getPropSafe(ax, 'Visible', 'on'))), 'on');
    hasPlottable = i_hasMeaningfulPlottableChildren(ax);
    [tileIdx, ~] = i_getAxesTileInfo(ax);
    isTiled = strcmp(layoutModel.mode, 'tiled') && isfinite(tileIdx);

    if (~visible) && (~hasPlottable)
        category = 'auxiliary';
        reason = 'invisible-and-empty';
        return;
    end

    if isTiled || hasPlottable
        category = 'primary';
        if isTiled
            reason = 'tiled-member';
        else
            reason = 'has-plottable-children';
        end
        return;
    end

    category = 'auxiliary';
    reason = 'non-primary-fallback';
end

function [cleanFig, handleMaps] = rebuildFigure(exportModel, exportOpts)
    cleanFig = figure;
    drawnow;
    cleanFig.Visible = 'off';
    if isfield(exportModel.figure, 'color') && isnumeric(exportModel.figure.color) && numel(exportModel.figure.color) >= 3
        cleanFig.Color = exportModel.figure.color;
    end
    if isfield(exportModel.figure, 'renderer') && ~isempty(exportModel.figure.renderer)
        try, cleanFig.Renderer = exportModel.figure.renderer; catch, end
    end
    if isfield(exportModel.figure, 'positionPixels') && isnumeric(exportModel.figure.positionPixels) && numel(exportModel.figure.positionPixels) >= 4
        try
            oldUnits = cleanFig.Units;
            cleanFig.Units = 'pixels';
            cleanFig.Position = exportModel.figure.positionPixels;
            cleanFig.Units = oldUnits;
        catch
        end
    end
    if isfield(exportModel.figure, 'colormap') && ~isempty(exportModel.figure.colormap)
        try, colormap(cleanFig, exportModel.figure.colormap); catch, end
    end

    handleMaps = struct();
    handleMaps.axesByKey = containers.Map('KeyType', 'char', 'ValueType', 'any');
    handleMaps.plotBySrcId = containers.Map('KeyType', 'char', 'ValueType', 'any');
    handleMaps.warnings = strings(0,1);
    handleMaps.layoutHandle = [];

    if strcmp(exportModel.layout.mode, 'tiled')
        try
            gs = exportModel.layout.gridSize;
            handleMaps.layoutHandle = tiledlayout(cleanFig, gs(1), gs(2));
            try, handleMaps.layoutHandle.TileSpacing = exportModel.layout.tileSpacing; catch, end
            try, handleMaps.layoutHandle.Padding = exportModel.layout.padding; catch, end
        catch
            handleMaps.layoutHandle = [];
        end
    end

    if nargin >= 2 && isstruct(exportOpts)
        % reserved for future options; no callbacks/appdata are set here intentionally.
    end
end

function [cleanFig, handleMaps] = rebuildAxes(cleanFig, exportModel, handleMaps)
    primary = exportModel.axes(arrayfun(@(a) a.isPrimary, exportModel.axes));
    for iAx = 1:numel(primary)
        axModel = primary(iAx);
        dstAx = [];
        if strcmp(exportModel.layout.mode, 'tiled') && ~isempty(handleMaps.layoutHandle) && isfinite(axModel.tileIndex)
            try
                dstAx = nexttile(handleMaps.layoutHandle, axModel.tileIndex);
                if isnumeric(axModel.tileSpan) && numel(axModel.tileSpan) == 2
                    try, dstAx.Layout.TileSpan = axModel.tileSpan; catch, end
                end
            catch
                dstAx = [];
            end
        end

        if isempty(dstAx) || ~isgraphics(dstAx, 'axes')
            dstAx = axes('Parent', cleanFig, 'Units', 'normalized', 'Position', axModel.positionNorm);
        end

        i_applyAxesProps(dstAx, axModel.axisProps);
        handleMaps.axesByKey(char(axModel.key)) = dstAx;
        handleMaps = copyAxesChildren(axModel.srcHandle, dstAx, axModel.children, handleMaps, exportModel);

        if isfield(axModel.axisProps, 'Colormap') && ~isempty(axModel.axisProps.Colormap)
            try, colormap(dstAx, axModel.axisProps.Colormap); catch, end
        end
    end
end

function handleMaps = copyAxesChildren(srcAx, dstAx, childModels, handleMaps, exportModel)
    if isempty(srcAx) || ~isgraphics(srcAx, 'axes') || isempty(dstAx) || ~isgraphics(dstAx, 'axes')
        return;
    end

    if nargin >= 5 && isstruct(exportModel)
        % no-op; reserved for future context-sensitive copy behavior.
    end

    for iChild = 1:numel(childModels)
        cm = childModels(iChild);
        if ~cm.copyEligible || isempty(cm.srcHandle) || ~isgraphics(cm.srcHandle)
            continue;
        end
        try
            newObj = copyobj(cm.srcHandle, dstAx);
            if ~isempty(newObj)
                handleMaps.plotBySrcId(char(cm.srcId)) = newObj(1);
            end
        catch ME
            handleMaps.warnings(end+1,1) = "Child copy skipped (" + string(cm.className) + "): " + string(ME.message);
        end
    end
end

function [cleanFig, handleMaps] = rebuildColorbars(cleanFig, exportModel, handleMaps)
    for iCb = 1:numel(exportModel.colorbars)
        cbModel = exportModel.colorbars(iCb);
        k = char(cbModel.hostAxesKey);
        if ~isKey(handleMaps.axesByKey, k)
            handleMaps.warnings(end+1,1) = "Colorbar skipped: missing mapped host axes.";
            continue;
        end
        dstAx = handleMaps.axesByKey(k);
        try
            cb = colorbar(dstAx);
            i_applyColorbarProps(cb, cbModel.props);
        catch ME
            handleMaps.warnings(end+1,1) = "Colorbar rebuild failed: " + string(ME.message);
        end
    end

    if nargin >= 1
        % keeps signature explicit and stable
    end
end

function [cleanFig, handleMaps] = rebuildLegends(cleanFig, exportModel, handleMaps)
    for iLg = 1:numel(exportModel.legends)
        lgModel = exportModel.legends(iLg);
        hostKey = char(lgModel.hostAxesKey);
        if ~isKey(handleMaps.axesByKey, hostKey)
            handleMaps.warnings(end+1,1) = "Legend skipped: missing mapped host axes.";
            continue;
        end

        mappedHandles = gobjects(0,1);
        mappedLabels = strings(0,1);
        for j = 1:numel(lgModel.entrySrcIds)
            srcId = char(lgModel.entrySrcIds(j));
            if isKey(handleMaps.plotBySrcId, srcId)
                mappedHandles(end+1,1) = handleMaps.plotBySrcId(srcId); %#ok<AGROW>
                if j <= numel(lgModel.labels)
                    mappedLabels(end+1,1) = lgModel.labels(j); %#ok<AGROW>
                else
                    mappedLabels(end+1,1) = ""; %#ok<AGROW>
                end
            end
        end

        if isempty(mappedHandles)
            handleMaps.warnings(end+1,1) = "Legend skipped: no mapped plot handles.";
            continue;
        end

        dstAx = handleMaps.axesByKey(hostKey);
        try
            lg = legend(dstAx, mappedHandles, cellstr(mappedLabels));
            try, lg.AutoUpdate = 'off'; catch, end
            i_applyLegendProps(lg, lgModel.props);
        catch ME
            handleMaps.warnings(end+1,1) = "Legend rebuild failed: " + string(ME.message);
        end
    end

    if nargin >= 1
        % keeps signature explicit and stable
    end
end

function cleanFig = rebuildAnnotations(cleanFig, exportModel, handleMaps)
    if ~isempty(exportModel.annotations)
        handleMaps.warnings(end+1,1) = "Annotation reconstruction partially supported; unsupported annotations were skipped.";
    end
end

function finalizeAndSave(cleanFig, outFile, exportOpts)
    savefig(cleanFig, outFile);
    if ~isempty(cleanFig) && isgraphics(cleanFig, 'figure')
        close(cleanFig);
    end

    if nargin >= 3 && isstruct(exportOpts)
        % reserved for future save-time options
    end
end

function i_legacyTopLevelCopyAndSave(figOne, outFileK, exportOpts)
    cleanFig = [];
    try
        cleanFig = figure('Visible', 'off');
        srcChildren = allchild(figOne);
        for iChild = numel(srcChildren):-1:1
            hChild = srcChildren(iChild);
            if ~isgraphics(hChild)
                continue;
            end
            childClass = lower(string(class(hChild)));
            if contains(childClass, 'menu') || contains(childClass, 'toolbar') || contains(childClass, 'uipanel')
                continue;
            end
            try
                copyobj(hChild, cleanFig);
            catch
            end
        end
        if isprop(figOne, 'Color') && isprop(cleanFig, 'Color')
            cleanFig.Color = figOne.Color;
        end
        finalizeAndSave(cleanFig, outFileK, exportOpts);
    catch ME
        if ~isempty(cleanFig) && isgraphics(cleanFig, 'figure')
            close(cleanFig);
        end
        rethrow(ME);
    end
end

function i_emitExportWarnings(figOne, warningsIn, exportOpts)
    verbose = true;
    if nargin >= 3 && isstruct(exportOpts) && isfield(exportOpts, 'exportVerbose') && ~isempty(exportOpts.exportVerbose)
        verbose = logical(exportOpts.exportVerbose);
    end
    if ~verbose || isempty(warningsIn)
        return;
    end

    allWarnings = unique(warningsIn(:), 'stable');
    if isempty(allWarnings)
        return;
    end

    msg = sprintf('FCS_export warnings for "%s":\n%s', char(i_figureNameSafe(figOne)), char(strjoin(allWarnings, newline)));
    warning('FCS_export:Warnings', '%s', char(msg));
end

function out = i_figureNameSafe(fig)
    out = "(unnamed)";
    try
        nm = string(fig.Name);
        if strlength(strtrim(nm)) > 0
            out = nm;
        end
    catch
    end
end

function tf = i_axesKeyIsPrimary(axModels, key)
    tf = false;
    for i = 1:numel(axModels)
        if strcmp(char(axModels(i).key), char(key)) && axModels(i).isPrimary
            tf = true;
            return;
        end
    end
end

function key = i_handleKey(h)
    key = "";
    try
        key = string(sprintf('%.17g', double(h)));
    catch
    end
end

function idNum = i_handleIdNumeric(h)
    idNum = inf;
    try
        idNum = double(h);
    catch
    end
end

function posPix = i_getFigurePositionPixels(fig)
    posPix = [100 100 640 480];
    if isempty(fig) || ~isgraphics(fig, 'figure')
        return;
    end
    try
        oldUnits = fig.Units;
        fig.Units = 'pixels';
        posPix = fig.Position;
        fig.Units = oldUnits;
    catch
    end
end

function [tileIdx, tileSpan] = i_getAxesTileInfo(ax)
    tileIdx = NaN;
    tileSpan = [1 1];
    try
        if isprop(ax, 'Layout')
            lay = ax.Layout;
            if ~isempty(lay)
                try
                    t = lay.Tile;
                    if isnumeric(t) && isfinite(t)
                        tileIdx = double(t);
                    end
                catch
                end
                try
                    ts = lay.TileSpan;
                    if isnumeric(ts) && numel(ts) == 2
                        tileSpan = double(ts(:)');
                    end
                catch
                end
            end
        end
    catch
    end
end

function lay = i_findTiledLayoutParent(ax)
    lay = [];
    p = [];
    try, p = ax.Parent; catch, end
    while ~isempty(p)
        cls = lower(string(class(p)));
        if contains(cls, 'tiledchartlayout')
            lay = p;
            return;
        end
        try
            p = p.Parent;
        catch
            p = [];
        end
    end
end

function axProps = i_captureAxesProps(ax)
    axProps = struct();
    propNames = {'XLim','YLim','ZLim','CLim','ALim','XScale','YScale','ZScale','XDir','YDir','ZDir', ...
        'DataAspectRatio','PlotBoxAspectRatio','View','Box','FontName','FontSize','LineWidth','Color','ColorOrder','Colormap'};
    for i = 1:numel(propNames)
        pn = propNames{i};
        if isprop(ax, pn)
            try, axProps.(pn) = ax.(pn); catch, end
        end
    end
    axProps.Visible = i_getPropSafe(ax, 'Visible', 'on');
end

function i_applyAxesProps(ax, axProps)
    fns = fieldnames(axProps);
    for i = 1:numel(fns)
        fn = fns{i};
        if strcmp(fn, 'Colormap')
            continue;
        end
        if isprop(ax, fn)
            try, ax.(fn) = axProps.(fn); catch, end
        end
    end
end

function childModels = i_discoverAxesChildren(ax)
    childModels = struct('srcHandle', {}, 'srcId', {}, 'className', {}, 'copyEligible', {}, 'sortA', {}, 'sortB', {}, 'sortHandleId', {});
    ch = allchild(ax);
    for i = 1:numel(ch)
        h = ch(i);
        if ~isgraphics(h)
            continue;
        end

        cls = string(class(h));
        childModel = struct();
        childModel.srcHandle = h;
        childModel.srcId = i_handleKey(h);
        childModel.className = cls;
        childModel.copyEligible = i_isChildCopyEligible(h);
        [childModel.sortA, childModel.sortB] = i_childSortScalar(h);
        childModel.sortHandleId = i_handleIdNumeric(h);
        childModels(end+1,1) = childModel; %#ok<AGROW>
    end

    if isempty(childModels)
        return;
    end

    mat = [[childModels.sortA]' [childModels.sortB]' [childModels.sortHandleId]'];
    [~, ord] = sortrows(mat, [1 2 3]);
    childModels = childModels(ord);
end

function tf = i_isChildCopyEligible(h)
    tf = false;
    if isempty(h) || ~isgraphics(h)
        return;
    end
    cls = lower(string(class(h)));
    if contains(cls, 'menu') || contains(cls, 'toolbar') || contains(cls, 'uipanel') || contains(cls, 'uicontainer') || contains(cls, 'appdesigner')
        return;
    end
    tf = true;
end

function tf = i_hasMeaningfulPlottableChildren(ax)
    tf = false;
    ch = allchild(ax);
    for i = 1:numel(ch)
        h = ch(i);
        if ~isgraphics(h)
            continue;
        end
        if i_isMeaningfulPlottableClass(string(class(h)))
            tf = true;
            return;
        end
    end
end

function tf = i_isMeaningfulPlottableClass(className)
    c = lower(string(className));
    keys = ["line","scatter","bar","errorbar","image","surface","patch","text","histogram","stair","area","contour","heatmap"];
    tf = any(contains(c, keys));
end

function [a, b] = i_childSortScalar(h)
    a = 0;
    b = 0;
    try
        if isprop(h, 'XData')
            xd = h.XData;
            if isnumeric(xd) && ~isempty(xd)
                a = double(xd(1));
            end
        end
    catch
    end
    try
        if isprop(h, 'YData')
            yd = h.YData;
            if isnumeric(yd) && ~isempty(yd)
                b = double(yd(1));
            end
        end
    catch
    end
end

function axesOut = i_sortAxesModelsDeterministic(axesIn, layoutModel)
    axesOut = axesIn;
    if isempty(axesOut)
        return;
    end

    isPrimary = arrayfun(@(a) a.isPrimary, axesOut);
    primary = axesOut(isPrimary);
    nonPrimary = axesOut(~isPrimary);

    if isempty(primary)
        axesOut = [nonPrimary(:)];
        return;
    end

    if strcmp(layoutModel.mode, 'tiled')
        tIdx = arrayfun(@(a) i_nanToInf(a.tileIndex), primary);
        ts1 = arrayfun(@(a) i_nanToInf(a.tileSpan(1)), primary);
        ts2 = arrayfun(@(a) i_nanToInf(a.tileSpan(2)), primary);
        hid = arrayfun(@(a) i_nanToInf(a.sortHandleId), primary);
        mat = [tIdx(:) ts1(:) ts2(:) hid(:)];
        [~, ord] = sortrows(mat, [1 2 3 4]);
        primary = primary(ord);
    else
        y = arrayfun(@(a) i_nanToInf(a.positionNorm(2)), primary);
        x = arrayfun(@(a) i_nanToInf(a.positionNorm(1)), primary);
        hid = arrayfun(@(a) i_nanToInf(a.sortHandleId), primary);
        mat = [-y(:) x(:) hid(:)];
        [~, ord] = sortrows(mat, [1 2 3]);
        primary = primary(ord);
    end

    axesOut = [primary(:); nonPrimary(:)];
end

function v = i_nanToInf(v)
    if ~isfinite(v)
        v = inf;
    end
end

function pos = i_getAxesPositionNorm(ax)
    pos = [0.13 0.11 0.775 0.815];
    if isempty(ax) || ~isgraphics(ax)
        return;
    end
    try
        oldUnits = ax.Units;
        ax.Units = 'normalized';
        pos = ax.Position;
        ax.Units = oldUnits;
    catch
    end
end

function cmap = i_getColormapSafe(target, defaultVal)
    cmap = defaultVal;
    try
        cmap = colormap(target);
    catch
    end
end

function val = i_getPropSafe(obj, propName, defaultVal)
    val = defaultVal;
    try
        if isprop(obj, propName)
            val = obj.(propName);
        end
    catch
    end
end

function props = i_captureColorbarProps(cb)
    props = struct();
    propNames = {'Location','Limits','Ticks','TickLabels','Direction','FontName','FontSize','LineWidth','Color','Box'};
    for i = 1:numel(propNames)
        pn = propNames{i};
        if isprop(cb, pn)
            try, props.(pn) = cb.(pn); catch, end
        end
    end
    if isprop(cb, 'Label') && ~isempty(cb.Label)
        props.LabelString = i_getPropSafe(cb.Label, 'String', '');
        props.LabelInterpreter = i_getPropSafe(cb.Label, 'Interpreter', 'tex');
    end
end

function i_applyColorbarProps(cb, props)
    fns = fieldnames(props);
    for i = 1:numel(fns)
        fn = fns{i};
        if strcmp(fn, 'LabelString') || strcmp(fn, 'LabelInterpreter')
            continue;
        end
        if isprop(cb, fn)
            try, cb.(fn) = props.(fn); catch, end
        end
    end
    try
        if isfield(props, 'LabelString')
            cb.Label.String = props.LabelString;
        end
        if isfield(props, 'LabelInterpreter')
            cb.Label.Interpreter = props.LabelInterpreter;
        end
    catch
    end
end

function labels = i_getLegendLabelsSafe(lg)
    labels = strings(0,1);
    raw = i_getPropSafe(lg, 'String', {});
    if ischar(raw)
        labels = string({raw});
    elseif isstring(raw)
        labels = raw(:);
    elseif iscell(raw)
        labels = string(raw(:));
    end
end

function props = i_captureLegendProps(lg)
    props = struct();
    propNames = {'Location','Orientation','Box','NumColumns','FontName','FontSize','Interpreter','TextColor'};
    for i = 1:numel(propNames)
        pn = propNames{i};
        if isprop(lg, pn)
            try, props.(pn) = lg.(pn); catch, end
        end
    end
end

function i_applyLegendProps(lg, props)
    fns = fieldnames(props);
    for i = 1:numel(fns)
        fn = fns{i};
        if isprop(lg, fn)
            try, lg.(fn) = props.(fn); catch, end
        end
    end
end

function opts = i_parseExportOpts(exportOpts)
    if ~isstruct(exportOpts)
        error('FCS_export:InvalidOpts', 'exportOpts must be a struct.');
    end

    opts = struct();
    opts.formats = i_parseFormats(exportOpts);
    opts.outDir = i_getStringField(exportOpts, 'outDir', string(pwd));
    opts.overwrite = i_getLogicalField(exportOpts, 'overwrite', false);
    opts.vectorMode = i_getLogicalField(exportOpts, 'vectorMode', true);
    opts.filenameFrom = lower(i_getStringField(exportOpts, 'filenameFrom', "Name"));
    opts.sanitize = i_getLogicalField(exportOpts, 'sanitize', true);
    opts.customPrefix = i_getStringField(exportOpts, 'customPrefix', "Figure");
    opts.normalizeFontsOnExport = i_getLogicalField(exportOpts, 'normalizeFontsOnExport', false);
    opts.debugExport = i_getLogicalField(exportOpts, 'debugExport', false);

    validNameModes = ["name", "number", "customprefix"];
    if ~any(opts.filenameFrom == validNameModes)
        error('FCS_export:InvalidFilenameFrom', 'filenameFrom must be one of: Name, Number, customPrefix.');
    end

    opts.outDir = char(opts.outDir);
end

function formats = i_parseFormats(exportOpts)
    raw = "pdf";
    if isfield(exportOpts, 'format') && ~isempty(exportOpts.format)
        raw = exportOpts.format;
    end

    if ischar(raw)
        formats = string({raw});
    elseif isstring(raw)
        formats = raw(:);
    elseif iscell(raw)
        formats = string(raw(:));
    else
        error('FCS_export:InvalidFormat', 'format must be char, string, or cellstr.');
    end

    formats = lower(strtrim(formats));
    valid = ["pdf", "png", "fig"];
    if any(~ismember(formats, valid))
        error('FCS_export:InvalidFormat', 'format supports only: pdf, png, fig.');
    end
    formats = unique(formats, 'stable');
end

function value = i_getStringField(s, name, defaultValue)
    value = defaultValue;
    if isfield(s, name) && ~isempty(s.(name))
        value = string(s.(name));
    end
end

function value = i_getLogicalField(s, name, defaultValue)
    value = defaultValue;
    if isfield(s, name) && ~isempty(s.(name))
        value = logical(s.(name));
    end
end

function out = i_buildBaseName(fig, idx, opts)
    switch opts.filenameFrom
        case "name"
            try
                out = string(fig.Name);
            catch
                out = "";
            end
            if strlength(strtrim(out)) == 0
                out = i_defaultFigureName(fig, idx);
            end

        case "number"
            out = i_defaultFigureName(fig, idx);

        case "customprefix"
            out = string(opts.customPrefix) + "_" + string(idx);

        otherwise
            out = i_defaultFigureName(fig, idx);
    end
end

function out = i_defaultFigureName(fig, idx)
    figNum = [];
    try
        figNum = fig.Number;
    catch
    end

    if ~isempty(figNum) && isnumeric(figNum) && isfinite(figNum)
        out = "Figure" + string(figNum);
    else
        out = "Figure_" + string(idx);
    end
end

function out = i_sanitizeName(nameIn)
    out = string(nameIn);
    try
        if exist('sanitizeFilename', 'file') == 2
            out = string(sanitizeFilename(char(out)));
            return;
        end
    catch
    end

    out = regexprep(out, '\\s+', '_');
    out = regexprep(out, '[^a-zA-Z0-9_\.-]', '');
    out = regexprep(out, '_+', '_');
    out = regexprep(out, '^_+|_+$', '');
end

function out = i_uniqueFilename(pathIn)
    out = pathIn;
    [p, n, e] = fileparts(pathIn);
    k = 1;
    while exist(out, 'file')
        out = fullfile(p, sprintf('%s_%d%s', n, k, e));
        k = k + 1;
    end
end
function i_logExportDiagnostics(fig, outType, debugExport)
    % Unified export diagnostics for both PDF and FIG formats
    if nargin < 3 || ~logical(debugExport)
        return;
    end
    
    fprintf('\n=== FCS EXPORT DIAGNOSTIC (format=%s) ===\n', outType);
    
    % Figure diagnostics
    try
        fprintf('fig class: %s\n', class(fig));
        fprintf('fig.Name: %s\n', char(string(fig.Name)));
        fprintf('fig.Position: [%.1f %.1f %.1f %.1f]\n', fig.Position);
        if isprop(fig, 'PaperSize')
            fprintf('fig.PaperSize: [%.2f %.2f]\n', fig.PaperSize);
        end
        if isprop(fig, 'PaperPosition')
            fprintf('fig.PaperPosition: [%.2f %.2f %.2f %.2f]\n', fig.PaperPosition);
        end
        if isprop(fig, 'Renderer')
            fprintf('fig.Renderer: %s\n', fig.Renderer);
        end
    catch ME
        fprintf('Figure diagnostics error: %s\n', ME.message);
    end
    
    % Axes diagnostics
    allAxes = findall(fig, 'Type', 'axes');
    fprintf('Axes count: %d\n', numel(allAxes));
    for k = 1:min(numel(allAxes), 5)  % Limit to first 5 axes
        fprintf('\n  AXIS %d:\n', k);
        if isprop(allAxes(k), 'FontName')
            fprintf('    FontName: %s\n', allAxes(k).FontName);
        end
        if isprop(allAxes(k), 'FontSize')
            fprintf('    FontSize: %.2f\n', allAxes(k).FontSize);
        end
        if isprop(allAxes(k), 'Units')
            fprintf('    Units: %s\n', allAxes(k).Units);
        end
        if isprop(allAxes(k), 'Position')
            fprintf('    Position: [%.4f %.4f %.4f %.4f]\n', allAxes(k).Position);
        end
        
        % Inner position in centimeters (non-destructive measurement)
        try
            if isprop(allAxes(k), 'InnerPosition') && isprop(allAxes(k), 'Units')
                origUnits = allAxes(k).Units;
                allAxes(k).Units = 'centimeters';
                innerPosCm = allAxes(k).InnerPosition;
                allAxes(k).Units = origUnits;  % Restore original units
                fprintf('    INNER (cm): [%.4f %.4f %.4f %.4f]\n', innerPosCm);
            end
        catch
            % Silent fail if InnerPosition measurement not supported
        end
    end
    
    % Colorbar diagnostics
    allColorbars = findall(fig, 'Type', 'colorbar');
    fprintf('\nColorbar count: %d\n', numel(allColorbars));
    for k = 1:min(numel(allColorbars), 3)
        fprintf('  COLORBAR %d:\n', k);
        if isprop(allColorbars(k), 'FontName')
            fprintf('    FontName: %s\n', allColorbars(k).FontName);
        end
        if isprop(allColorbars(k), 'FontSize')
            fprintf('    FontSize: %.2f\n', allColorbars(k).FontSize);
        end
    end
    
    % Text diagnostics
    allText = findall(fig, 'Type', 'text');
    fprintf('\nText object count: %d\n', numel(allText));
    for k = 1:min(numel(allText), 5)
        fprintf('  TEXT %d:\n', k);
        if isprop(allText(k), 'FontName')
            fprintf('    FontName: %s\n', allText(k).FontName);
        end
        if isprop(allText(k), 'FontSize')
            fprintf('    FontSize: %.2f\n', allText(k).FontSize);
        end
    end
    
    fprintf('=== END EXPORT DIAGNOSTIC ===\n\n');
end

function [fontName, fontSize] = i_getExportFontSettings(fig)
    % Intelligent font fallback: figure -> axes -> root -> default
    fontName = 'Helvetica';
    fontSize = 8;
    
    % Try figure
    if isprop(fig, 'DefaultAxesFontName')
        try
            fn = fig.DefaultAxesFontName;
            if ~isempty(fn) && ischar(fn)
                fontName = fn;
                if isprop(fig, 'DefaultAxesFontSize')
                    sz = fig.DefaultAxesFontSize;
                    if isnumeric(sz) && isfinite(sz) && sz > 0
                        fontSize = sz;
                    end
                end
                return;
            end
        catch
        end
    end
    
    % Try first axis
    allAxes = findall(fig, 'Type', 'axes');
    if ~isempty(allAxes)
        ax = allAxes(1);
        try
            if isprop(ax, 'FontName') && ~isempty(ax.FontName)
                fontName = ax.FontName;
            end
            if isprop(ax, 'FontSize') && isnumeric(ax.FontSize) && isfinite(ax.FontSize) && ax.FontSize > 0
                fontSize = ax.FontSize;
            end
            return;
        catch
        end
    end
    
    % Try root defaults
    try
        rootFontName = get(0, 'DefaultAxesFontName');
        if ~isempty(rootFontName) && ischar(rootFontName)
            fontName = rootFontName;
        end
        rootFontSize = get(0, 'DefaultAxesFontSize');
        if isnumeric(rootFontSize) && isfinite(rootFontSize) && rootFontSize > 0
            fontSize = rootFontSize;
        end
    catch
    end
end
function i_syncPaperSize(fig)
    % Synchronize PaperSize with on-screen figure dimensions
    % Ensures exported PDF page size matches the MATLAB figure size
    if ~isgraphics(fig, 'figure')
        return;
    end
    
    try
        % Set figure units to centimeters and read position
        origUnits = fig.Units;
        fig.Units = 'centimeters';
        figPos = fig.Position;
        
        % Set paper properties to match figure size
        fig.PaperUnits = 'centimeters';
        fig.PaperSize = figPos(3:4);        % Width and height from Position
        fig.PaperPosition = [0 0 figPos(3:4)];
        
        % Restore original units
        fig.Units = origUnits;
    catch
        % Silent fail if paper synchronization not supported
    end
end
