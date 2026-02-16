function FCS_applyColormap(figHandles, cmapOpts)
% FCS_applyColormap Apply colormap/line styling to explicitly provided figures.
% Enforces explicit targeting by calling SmartFigureEngine.applyColormapToFigures
% with useFolder=false and targetFigs=figHandles.
% Assumes SmartFigureEngine is available on path.

    if nargin < 2
        cmapOpts = struct();
    end
    opts = i_parseCmapOpts(cmapOpts);

    figs = FCS_resolveTargets(struct('mode', 'explicitList', 'explicitList', figHandles, 'excludeKnownGUIs', false));
    if isempty(figs)
        return;
    end

    SmartFigureEngine.applyColormapToFigures( ...
        opts.mapName, ...
        [], ...
        opts.spreadMode, ...
        '', ...                % fitColor
        opts.lineWidth, ...    % dataWidth
        '', ...                % dataStyle
        opts.lineWidth, ...    % fitWidth
        '', ...                % fitStyle
        opts.reverseOrder, ...
        opts.reverseLegendOrder, ...
        opts.noMapChange, ...
        opts.markerSize, ...
        figs, ...
        {}, ...                % scm8Maps
        false);                % useFolder
end

function opts = i_parseCmapOpts(cmapOpts)
    if ~isstruct(cmapOpts)
        error('FCS_applyColormap:InvalidOpts', 'cmapOpts must be a struct.');
    end

    opts = struct();
    opts.mapName = i_getStringField(cmapOpts, 'mapName', "parula");
    opts.spreadMode = i_getStringField(cmapOpts, 'spreadMode', "medium");
    opts.lineWidth = i_getPositiveNumericOrEmpty(cmapOpts, 'lineWidth', []);
    opts.markerSize = i_getPositiveNumericOrEmpty(cmapOpts, 'markerSize', []);
    opts.reverseOrder = i_getLogicalField(cmapOpts, 'reverseOrder', false);
    opts.reverseLegendOrder = i_getLogicalField(cmapOpts, 'reverseLegendOrder', false);
    opts.noMapChange = i_getLogicalField(cmapOpts, 'noMapChange', false);

    opts.mapName = char(opts.mapName);
    opts.spreadMode = char(opts.spreadMode);
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

function value = i_getPositiveNumericOrEmpty(s, name, defaultValue)
    value = defaultValue;
    if ~isfield(s, name) || isempty(s.(name))
        return;
    end

    raw = s.(name);
    if ~isnumeric(raw) || ~isscalar(raw) || ~isfinite(raw) || raw <= 0
        error('FCS_applyColormap:InvalidNumericField', '%s must be a positive numeric scalar when provided.', name);
    end
    value = double(raw);
end
