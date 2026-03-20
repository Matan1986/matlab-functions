function state = FCS_prepareExportFigure(fig, opts)
% FCS_prepareExportFigure Shared export diagnostics + temporary normalization.
% Applies export-time adjustments in-place and returns state for restoration.

    if nargin < 2 || ~isstruct(opts)
        opts = struct();
    end
    cfg = i_parseOpts(opts);

    state = struct();
    state.obj = gobjects(0,1);
    state.prop = strings(0,1);
    state.value = cell(0,1);
    state.paper = struct('applied', false, 'fig', gobjects(0,1), ...
        'PaperUnits', [], 'PaperPosition', [], 'PaperSize', [], ...
        'PaperPositionMode', [], 'InvertHardcopy', []);

    if isempty(fig) || ~isgraphics(fig, 'figure')
        return;
    end

    i_logExportDiagnostics(fig, cfg.outType, cfg.debugExport);

    if cfg.normalizeFontsOnExport
        [exportFontName, exportFontSize] = i_getExportFontSettings(fig);
        if cfg.debugExport
            fprintf('Export font settings: FontName=%s, FontSize=%.1f\n', exportFontName, exportFontSize);
            fprintf('Normalize fonts on export: %d\n', cfg.normalizeFontsOnExport);
        end

        axAll = FCS_getPrimaryAxes(fig, struct('mode', 'all'));
        state = i_applyFontNormalization(state, axAll, exportFontName, exportFontSize);

        cbAll = findall(fig, 'Type', 'colorbar');
        state = i_applyFontNormalization(state, cbAll, exportFontName, exportFontSize);

        txAll = findall(fig, 'Type', 'text');
        state = i_applyFontNormalization(state, txAll, exportFontName, exportFontSize);
    end

    % Guard against export-time clipping of labels/titles by ensuring
    % LooseInset is not tighter than TightInset. Restored after export.
    state = i_applyAxesInsetGuard(state, fig);

    if cfg.syncPaperSize
        state = i_capturePaperState(state, fig);
        i_syncPaperSize(fig);
    end
end

function cfg = i_parseOpts(opts)
    cfg = struct();
    cfg.outType = 'pdf';
    cfg.debugExport = false;
    cfg.normalizeFontsOnExport = false;
    cfg.syncPaperSize = false;

    if isfield(opts, 'outType') && ~isempty(opts.outType)
        cfg.outType = char(string(opts.outType));
    end
    if isfield(opts, 'debugExport') && ~isempty(opts.debugExport)
        cfg.debugExport = logical(opts.debugExport);
    end
    if isfield(opts, 'normalizeFontsOnExport') && ~isempty(opts.normalizeFontsOnExport)
        cfg.normalizeFontsOnExport = logical(opts.normalizeFontsOnExport);
    end
    if isfield(opts, 'syncPaperSize') && ~isempty(opts.syncPaperSize)
        cfg.syncPaperSize = logical(opts.syncPaperSize);
    end
end

function state = i_applyFontNormalization(state, objs, fontName, fontSize)
    if isempty(objs)
        return;
    end
    for i = 1:numel(objs)
        obj = objs(i);
        if ~isgraphics(obj)
            continue;
        end
        if isprop(obj, 'FontName')
            state = i_recordPropState(state, obj, 'FontName');
            try
                obj.FontName = fontName;
            catch
            end
        end
        if isprop(obj, 'FontSize')
            state = i_recordPropState(state, obj, 'FontSize');
            try
                obj.FontSize = fontSize;
            catch
            end
        end
    end
end

function state = i_recordPropState(state, obj, propName)
    if isempty(obj) || ~isgraphics(obj) || ~isprop(obj, propName)
        return;
    end
    try
        val = obj.(propName);
    catch
        return;
    end
    state.obj(end+1,1) = obj; %#ok<AGROW>
    state.prop(end+1,1) = string(propName); %#ok<AGROW>
    state.value{end+1,1} = val; %#ok<AGROW>
end

function state = i_capturePaperState(state, fig)
    state.paper.applied = true;
    state.paper.fig = fig;
    if isprop(fig, 'PaperUnits')
        state.paper.PaperUnits = fig.PaperUnits;
    end
    if isprop(fig, 'PaperPosition')
        state.paper.PaperPosition = fig.PaperPosition;
    end
    if isprop(fig, 'PaperSize')
        state.paper.PaperSize = fig.PaperSize;
    end
    if isprop(fig, 'PaperPositionMode')
        state.paper.PaperPositionMode = fig.PaperPositionMode;
    end
    if isprop(fig, 'InvertHardcopy')
        state.paper.InvertHardcopy = fig.InvertHardcopy;
    end
end

function i_logExportDiagnostics(fig, outType, debugExport)
    if nargin < 3 || ~logical(debugExport)
        return;
    end

    fprintf('\n=== FCS EXPORT DIAGNOSTIC (format=%s) ===\n', outType);

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

    allAxes = FCS_getPrimaryAxes(fig, struct('mode', 'all'));
    fprintf('Axes count: %d\n', numel(allAxes));
    for k = 1:min(numel(allAxes), 5)
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
        try
            if isprop(allAxes(k), 'InnerPosition') && isprop(allAxes(k), 'Units')
                origUnits = allAxes(k).Units;
                allAxes(k).Units = 'centimeters';
                innerPosCm = allAxes(k).InnerPosition;
                allAxes(k).Units = origUnits;
                fprintf('    INNER (cm): [%.4f %.4f %.4f %.4f]\n', innerPosCm);
            end
        catch
        end
    end

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
    fontName = 'Helvetica';
    fontSize = 8;

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

    allAxes = FCS_getPrimaryAxes(fig, struct('mode', 'all'));
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
    if ~isgraphics(fig, 'figure')
        return;
    end

    origUnits = [];
    try
        origUnits = fig.Units;
        fig.Units = 'centimeters';
        figPos = fig.Position;
        fig.PaperUnits = 'centimeters';
        fig.PaperSize = figPos(3:4);
        fig.PaperPosition = [0 0 figPos(3:4)];
        if isprop(fig, 'PaperPositionMode')
            fig.PaperPositionMode = 'auto';
        end
        if isprop(fig, 'InvertHardcopy')
            fig.InvertHardcopy = 'off';
        end
    catch ME
        warning('FCS_prepareExportFigure:PaperSyncFailed', 'Paper synchronization failed: %s', ME.message);
    end
    if ~isempty(origUnits) && isgraphics(fig, 'figure')
        try
            fig.Units = origUnits;
        catch
        end
    end
end

function state = i_applyAxesInsetGuard(state, fig)
    if isempty(fig) || ~isgraphics(fig, 'figure')
        return;
    end
    axAll = FCS_getPrimaryAxes(fig, struct('mode', 'all'));
    if isempty(axAll)
        return;
    end
    for iAx = 1:numel(axAll)
        ax = axAll(iAx);
        if ~isgraphics(ax, 'axes')
            continue;
        end
        if ~isprop(ax, 'LooseInset') || ~isprop(ax, 'TightInset')
            continue;
        end
        try
            tightInset = double(ax.TightInset);
            looseInset = double(ax.LooseInset);
            if numel(tightInset) >= 4 && numel(looseInset) >= 4 && all(isfinite(tightInset(1:4))) && all(isfinite(looseInset(1:4)))
                newLooseInset = max(looseInset(1:4), tightInset(1:4));
                if any(abs(newLooseInset - looseInset(1:4)) > eps)
                    state = i_recordPropState(state, ax, 'LooseInset');
                    ax.LooseInset = newLooseInset;
                end
            end
        catch
        end
    end
end
