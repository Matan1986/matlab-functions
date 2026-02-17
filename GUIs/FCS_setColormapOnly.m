function report = FCS_setColormapOnly(figHandles, opts)
% FCS_setColormapOnly Apply colormap/color styling on explicit target figures only.
% Explicit-target enforcement: operates only on validated figHandles input.
% Assumptions: callers provide figure handles from their own scope resolver.
%
% Signature:
%   report = FCS_setColormapOnly(figHandles, opts)
%
% Required opts:
%   mapName (string) OR mapRGB (Nx3 double)
%
% Optional opts (defaults):
%   reverseOrder        false
%   applyToAxes         true
%   applyToColorbar     true
%   applyToLines        true
%   applyToScatter      true
%   lineWidth           []
%   markerSize          []
%   includeHiddenHandles false

    if nargin < 2
        opts = struct();
    end

    figs = validateFigHandles(figHandles);
    opts = i_parseOpts(opts);
    cmap = i_buildColormap(opts);
    if opts.reverseOrder
        cmap = flipud(cmap);
    end

    report = struct( ...
        'figure', num2cell(figs), ...
        'axesCount', num2cell(zeros(numel(figs),1)), ...
        'colorbarCount', num2cell(zeros(numel(figs),1)), ...
        'linesUpdated', num2cell(zeros(numel(figs),1)), ...
        'scatterUpdated', num2cell(zeros(numel(figs),1)), ...
        'warnings', repmat({{}}, numel(figs), 1));

    for iFig = 1:numel(figs)
        fig = figs(iFig);
        warningsLocal = {};

        axList = getDataAxes(fig, opts.includeHiddenHandles);
        report(iFig).axesCount = numel(axList);

        if opts.applyToAxes
            for ax = axList(:)'
                try
                    colormap(ax, cmap);
                catch ME
                    warningsLocal{end+1} = sprintf('Axes colormap failed (%s).', ME.message); %#ok<AGROW>
                end
            end
        end

        cbList = i_getColorbars(fig, opts.includeHiddenHandles);
        report(iFig).colorbarCount = numel(cbList);
        if opts.applyToColorbar
            for cb = cbList(:)'
                try
                    colormap(cb, cmap);
                catch ME
                    warningsLocal{end+1} = sprintf('Colorbar colormap failed (%s).', ME.message); %#ok<AGROW>
                end
            end
        end

        for ax = axList(:)'
            objs = getPlottableObjects(ax, opts.includeHiddenHandles);

            if opts.applyToLines && ~isempty(objs.lines)
                idx = i_spacedIndices(size(cmap,1), numel(objs.lines));
                for k = 1:numel(objs.lines)
                    L = objs.lines(k);
                    changed = false;

                    try
                        if isprop(L, 'Color')
                            L.Color = cmap(idx(k), :);
                            changed = true;
                        end
                        if ~isempty(opts.lineWidth) && isprop(L, 'LineWidth')
                            L.LineWidth = opts.lineWidth;
                        end
                        if ~isempty(opts.markerSize) && isprop(L, 'MarkerSize')
                            L.MarkerSize = opts.markerSize;
                        end
                    catch ME
                        warningsLocal{end+1} = sprintf('Line update failed (%s).', ME.message); %#ok<AGROW>
                    end

                    if changed
                        report(iFig).linesUpdated = report(iFig).linesUpdated + 1;
                    end
                end
            end

            if opts.applyToScatter && ~isempty(objs.scatter)
                idx = i_spacedIndices(size(cmap,1), numel(objs.scatter));
                for k = 1:numel(objs.scatter)
                    S = objs.scatter(k);
                    thisColor = cmap(idx(k), :);
                    didColor = false;

                    try
                        [didColor, warnMsg] = i_applyScatterColorConservative(S, thisColor);
                        if ~isempty(warnMsg)
                            warningsLocal{end+1} = warnMsg; %#ok<AGROW>
                        end

                        if ~isempty(opts.lineWidth) && isprop(S, 'LineWidth')
                            S.LineWidth = opts.lineWidth;
                        end
                        if ~isempty(opts.markerSize)
                            if isprop(S, 'SizeData')
                                S.SizeData = opts.markerSize.^2;
                            elseif isprop(S, 'MarkerSize')
                                S.MarkerSize = opts.markerSize;
                            end
                        end
                    catch ME
                        warningsLocal{end+1} = sprintf('Scatter update failed (%s).', ME.message); %#ok<AGROW>
                    end

                    if didColor
                        report(iFig).scatterUpdated = report(iFig).scatterUpdated + 1;
                    end
                end
            end
        end

        report(iFig).warnings = warningsLocal;
    end
end

function figs = validateFigHandles(figHandles)
% validateFigHandles Validate/normalize explicit figure handles only.
% Enforces explicit targeting by rejecting invalid/non-figure handles.

    if nargin < 1 || isempty(figHandles)
        figs = gobjects(0,1);
        return;
    end

    raw = figHandles;
    if iscell(raw)
        raw = [raw{:}];
    end
    raw = raw(:);

    keep = false(size(raw));
    ids = nan(size(raw));
    for k = 1:numel(raw)
        try
            keep(k) = isgraphics(raw(k), 'figure') && isvalid(raw(k));
            if keep(k)
                ids(k) = double(raw(k));
            end
        catch
            keep(k) = false;
        end
    end

    if ~all(keep)
        error('FCS_setColormapOnly:InvalidFigureHandles', 'figHandles must contain only valid figure handles.');
    end

    [~, ia] = unique(ids, 'stable');
    figs = raw(ia);
end

function axList = getDataAxes(fig, includeHiddenHandles)
% getDataAxes Return data axes under fig, excluding colorbars/legends.
% Works for subplot and tiledlayout axes because both are regular axes.

    if includeHiddenHandles
        axList = findall(fig, 'Type', 'axes');
    else
        axList = findobj(fig, 'Type', 'axes');
    end

    uiAxesList = gobjects(0,1);
    try
        if includeHiddenHandles
            uiAxesList = findall(fig, '-isa', 'matlab.ui.control.UIAxes');
        else
            uiAxesList = findobj(fig, '-isa', 'matlab.ui.control.UIAxes');
        end
    catch
        uiAxesList = gobjects(0,1);
    end

    if ~isempty(uiAxesList)
        axList = [axList(:); uiAxesList(:)];
    else
        axList = axList(:);
    end

    if isempty(axList)
        return;
    end

    ids = nan(size(axList));
    for k = 1:numel(axList)
        try
            ids(k) = double(axList(k));
        catch
            ids(k) = nan;
        end
    end
    validId = ~isnan(ids);
    axList = axList(validId);
    ids = ids(validId);
    [~, ia] = unique(ids, 'stable');
    axList = axList(ia);

    keep = true(size(axList));
    for k = 1:numel(axList)
        a = axList(k);
        try
            tag = lower(string(a.Tag));
        catch
            tag = "";
        end
        if contains(tag, "legend") || contains(tag, "colorbar")
            keep(k) = false;
            continue;
        end
        try
            if isa(a, 'matlab.graphics.illustration.Legend')
                keep(k) = false;
            end
        catch
        end
        try
            if isa(a, 'matlab.graphics.illustration.ColorBar')
                keep(k) = false;
            end
        catch
        end
    end
    axList = axList(keep);
end

function objs = getPlottableObjects(ax, includeHiddenHandles)
% getPlottableObjects Return plottable line/scatter objects under one axes.

    if includeHiddenHandles
        lineObjs = findall(ax, 'Type', 'line');
        scatterObjs = findall(ax, 'Type', 'scatter');
    else
        lineObjs = findobj(ax, 'Type', 'line');
        scatterObjs = findobj(ax, 'Type', 'scatter');
    end

    objs = struct('lines', lineObjs(:), 'scatter', scatterObjs(:));
end

function opts = i_parseOpts(opts)
    if ~isstruct(opts)
        error('FCS_setColormapOnly:InvalidOpts', 'opts must be a struct.');
    end

    defaults = struct();
    defaults.mapName = "";
    defaults.mapRGB = [];
    defaults.reverseOrder = false;
    defaults.applyToAxes = true;
    defaults.applyToColorbar = true;
    defaults.applyToLines = true;
    defaults.applyToScatter = true;
    defaults.lineWidth = [];
    defaults.markerSize = [];
    defaults.includeHiddenHandles = false;

    opts = i_applyDefaults(opts, defaults);

    hasMapName = isfield(opts, 'mapName') && strlength(string(opts.mapName)) > 0;
    hasMapRGB = isfield(opts, 'mapRGB') && ~isempty(opts.mapRGB);
    if ~(hasMapName || hasMapRGB)
        error('FCS_setColormapOnly:MissingColormap', 'Provide opts.mapName or opts.mapRGB.');
    end

    opts.reverseOrder = logical(opts.reverseOrder);
    opts.applyToAxes = logical(opts.applyToAxes);
    opts.applyToColorbar = logical(opts.applyToColorbar);
    opts.applyToLines = logical(opts.applyToLines);
    opts.applyToScatter = logical(opts.applyToScatter);
    opts.includeHiddenHandles = logical(opts.includeHiddenHandles);

    opts.mapName = string(opts.mapName);

    if ~isempty(opts.lineWidth)
        if ~isnumeric(opts.lineWidth) || ~isscalar(opts.lineWidth) || ~isfinite(opts.lineWidth) || opts.lineWidth <= 0
            error('FCS_setColormapOnly:InvalidLineWidth', 'lineWidth must be a positive numeric scalar when provided.');
        end
        opts.lineWidth = double(opts.lineWidth);
    end

    if ~isempty(opts.markerSize)
        if ~isnumeric(opts.markerSize) || ~isscalar(opts.markerSize) || ~isfinite(opts.markerSize) || opts.markerSize <= 0
            error('FCS_setColormapOnly:InvalidMarkerSize', 'markerSize must be a positive numeric scalar when provided.');
        end
        opts.markerSize = double(opts.markerSize);
    end

    if ~isempty(opts.mapRGB)
        if ~isnumeric(opts.mapRGB) || ndims(opts.mapRGB) ~= 2 || size(opts.mapRGB,2) ~= 3
            error('FCS_setColormapOnly:InvalidMapRGB', 'mapRGB must be an Nx3 numeric matrix.');
        end
        if any(~isfinite(opts.mapRGB(:))) || any(opts.mapRGB(:) < 0) || any(opts.mapRGB(:) > 1)
            error('FCS_setColormapOnly:InvalidMapRGB', 'mapRGB values must be finite and within [0,1].');
        end
        if size(opts.mapRGB,1) < 2
            error('FCS_setColormapOnly:InvalidMapRGB', 'mapRGB must have at least 2 rows.');
        end
    end
end

function out = i_applyDefaults(in, defaults)
    out = defaults;
    fn = fieldnames(defaults);
    for k = 1:numel(fn)
        key = fn{k};
        if isfield(in, key) && ~isempty(in.(key))
            out.(key) = in.(key);
        end
    end
end

function cmap = i_buildColormap(opts)
    if ~isempty(opts.mapRGB)
        cmap = double(opts.mapRGB);
        return;
    end

    mapName = lower(strtrim(char(opts.mapName)));
    n = 256;

    builtinNames = { ...
        'parula','turbo','hsv','hot','cool','spring','summer','autumn', ...
        'winter','gray','bone','copper','pink','lines','colorcube', ...
        'prism','flag','white','jet'};

    if any(strcmp(mapName, builtinNames))
        cmap = feval(mapName, n);
        return;
    end

    switch mapName
        case 'viridis'
            anchors = [
                0.2670 0.0049 0.3294
                0.2832 0.1410 0.4580
                0.2540 0.2650 0.5300
                0.2070 0.3720 0.5530
                0.1640 0.4710 0.5580
                0.1280 0.5670 0.5510
                0.1350 0.6590 0.5180
                0.2670 0.7490 0.4410
                0.4780 0.8210 0.3180
                0.7410 0.8730 0.1500
            ];
        case 'plasma'
            anchors = [
                0.0500 0.0300 0.5280
                0.2530 0.0140 0.6150
                0.4170 0.0010 0.6580
                0.5730 0.0450 0.6320
                0.7060 0.1430 0.5410
                0.8130 0.2700 0.4300
                0.8940 0.4160 0.3230
                0.9510 0.5720 0.2500
                0.9810 0.7420 0.2390
                0.9400 0.9750 0.1310
            ];
        case 'magma'
            anchors = [
                0.0010 0.0005 0.0140
                0.0910 0.0280 0.2080
                0.2290 0.0590 0.3900
                0.3720 0.0910 0.4990
                0.5220 0.1210 0.5050
                0.6650 0.1730 0.4660
                0.7920 0.2590 0.4060
                0.9020 0.3850 0.3260
                0.9720 0.5540 0.2570
                0.9870 0.9910 0.7490
            ];
        otherwise
            error('FCS_setColormapOnly:UnknownMapName', ...
                'Unknown mapName "%s". Use built-in map name or provide opts.mapRGB.', mapName);
    end

    x = linspace(0, 1, size(anchors,1));
    xi = linspace(0, 1, n);
    cmap = interp1(x, anchors, xi, 'linear');
    cmap = max(0, min(1, cmap));
end

function idx = i_spacedIndices(nRows, nObjects)
    if nObjects <= 0
        idx = zeros(0,1);
        return;
    end
    idx = round(linspace(1, max(1, nRows), nObjects));
    idx = max(1, min(nRows, idx));
end

function cbList = i_getColorbars(fig, includeHiddenHandles)
    if includeHiddenHandles
        cbList = findall(fig, 'Type', 'colorbar');
    else
        cbList = findobj(fig, 'Type', 'colorbar');
    end
    cbList = cbList(:);
end

function [didColor, warnMsg] = i_applyScatterColorConservative(S, rgb)
    didColor = false;
    warnMsg = '';

    cdata = [];
    hasCData = false;
    try
        if isprop(S, 'CData')
            cdata = S.CData;
            hasCData = true;
        end
    catch
        hasCData = false;
    end

    if hasCData && ~isempty(cdata)
        isSingleRGB = isnumeric(cdata) && ismatrix(cdata) && size(cdata,1) == 1 && size(cdata,2) == 3;
        if ~isSingleRGB
            warnMsg = 'Scatter skipped: per-point CData detected (preserving existing color mapping).';
            return;
        end
    end

    if hasCData
        try
            S.CData = rgb;
            didColor = true;
        catch
        end
    end

    if ~didColor && hasCData && ~isempty(cdata)
        warnMsg = 'Scatter skipped: per-point CData detected (preserving existing color mapping).';
        return;
    end

    if ~didColor
        try
            if isprop(S, 'MarkerFaceColor')
                S.MarkerFaceColor = rgb;
                didColor = true;
            end
            if isprop(S, 'MarkerEdgeColor')
                S.MarkerEdgeColor = rgb;
                didColor = true;
            end
        catch
        end
    end

    if ~didColor
        warnMsg = 'Scatter skipped: object properties not compatible with single-color assignment.';
    end
end
