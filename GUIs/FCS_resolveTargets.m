function figHandles = FCS_resolveTargets(scopeSpec)
% FCS_resolveTargets Resolve figure targets from an explicit scope specification.
% Enforces explicit target resolution. It never mutates UI state.
%
% Supported scopeSpec modes:
%   "current"         - current figure only
%   "allOpen"         - all open figures (explicitly requested)
%   "byTag"           - figures whose Tag matches scopeSpec.tag
%   "byNameContains"  - figures whose Name contains scopeSpec.nameContains
%   "explicitList"    - scopeSpec.explicitList
%
% Optional scopeSpec fields:
%   excludeKnownGUIs   (default false)
%   knownGUINames      (string/cellstr list)
%   knownGUITags       (string/cellstr list)
%   excludeAutoGUI     (default false)

    spec = i_normalizeScopeSpec(scopeSpec);

    switch spec.mode
        case "current"
            h = get(groot, 'CurrentFigure');
            candidates = h;

        case "allOpen"
            candidates = findall(groot, 'Type', 'figure');

        case "byTag"
            tagNeedle = char(spec.tag);
            candidates = findall(groot, 'Type', 'figure', '-and', 'Tag', tagNeedle);

        case "byNameContains"
            candidates = findall(groot, 'Type', 'figure');
            keep = false(size(candidates));
            needle = lower(char(spec.nameContains));
            for k = 1:numel(candidates)
                figName = "";
                try
                    figName = string(candidates(k).Name);
                catch
                end
                keep(k) = contains(lower(figName), needle);
            end
            candidates = candidates(keep);

        case "explicitList"
            candidates = spec.explicitList;

        otherwise
            error('FCS_resolveTargets:UnsupportedMode', 'Unsupported scope mode: %s', spec.mode);
    end

    figHandles = i_normalizeFigureHandles(candidates);

    if spec.excludeKnownGUIs
        keep = true(size(figHandles));
        for k = 1:numel(figHandles)
            keep(k) = ~i_isKnownGUIFigure(figHandles(k), spec.knownGUINames, spec.knownGUITags, spec.excludeAutoGUI);
        end
        figHandles = figHandles(keep);
    end
end

function spec = i_normalizeScopeSpec(scopeSpec)
    if nargin < 1 || isempty(scopeSpec)
        scopeSpec = struct('mode', "current");
    end

    if ischar(scopeSpec) || (isstring(scopeSpec) && isscalar(scopeSpec))
        scopeSpec = struct('mode', string(scopeSpec));
    end

    if ~isstruct(scopeSpec)
        error('FCS_resolveTargets:InvalidScopeSpec', 'scopeSpec must be a struct, char, or scalar string.');
    end

    if ~isfield(scopeSpec, 'mode') || isempty(scopeSpec.mode)
        scopeSpec.mode = "current";
    end

    spec = struct();
    spec.mode = lower(string(scopeSpec.mode));
    spec.excludeKnownGUIs = i_getLogicalField(scopeSpec, 'excludeKnownGUIs', false);
    spec.excludeAutoGUI = i_getLogicalField(scopeSpec, 'excludeAutoGUI', false);
    spec.knownGUINames = i_getStringListField(scopeSpec, 'knownGUINames', [ ...
        "Appearance / Colormap Control", "refLineGUI", "Final Figure Formatter", ...
        "FigureTools", "Figure Control Studio"]);
    spec.knownGUITags = i_getStringListField(scopeSpec, 'knownGUITags', [ ...
        "AppearanceControl", "refLineGUI", "FinalFigureFormatter", "FigureControlStudio"]);

    switch spec.mode
        case "bytag"
            spec.mode = "byTag";
            if ~isfield(scopeSpec, 'tag') || isempty(scopeSpec.tag)
                error('FCS_resolveTargets:MissingTag', 'scopeSpec.tag is required for mode "byTag".');
            end
            spec.tag = string(scopeSpec.tag);

        case "bynamecontains"
            spec.mode = "byNameContains";
            if ~isfield(scopeSpec, 'nameContains') || isempty(scopeSpec.nameContains)
                error('FCS_resolveTargets:MissingNameContains', 'scopeSpec.nameContains is required for mode "byNameContains".');
            end
            spec.nameContains = string(scopeSpec.nameContains);

        case "explicitlist"
            spec.mode = "explicitList";
            if ~isfield(scopeSpec, 'explicitList')
                error('FCS_resolveTargets:MissingExplicitList', 'scopeSpec.explicitList is required for mode "explicitList".');
            end
            spec.explicitList = scopeSpec.explicitList;

        case "current"
            spec.mode = "current";

        case "allopen"
            spec.mode = "allOpen";

        otherwise
            error('FCS_resolveTargets:UnsupportedMode', 'Unsupported scope mode: %s', string(scopeSpec.mode));
    end
end

function tf = i_getLogicalField(s, fieldName, defaultValue)
    tf = defaultValue;
    if isfield(s, fieldName) && ~isempty(s.(fieldName))
        tf = logical(s.(fieldName));
    end
end

function values = i_getStringListField(s, fieldName, defaultValue)
    values = defaultValue;
    if ~isfield(s, fieldName) || isempty(s.(fieldName))
        return;
    end
    raw = s.(fieldName);
    if ischar(raw)
        values = string({raw});
    elseif isstring(raw)
        values = raw(:);
    elseif iscell(raw)
        values = string(raw(:));
    else
        error('FCS_resolveTargets:InvalidStringList', '%s must be char, string array, or cellstr.', fieldName);
    end
end

function figHandles = i_normalizeFigureHandles(raw)
    if isempty(raw)
        figHandles = gobjects(0,1);
        return;
    end

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

    figHandles = raw(keep);
    if isempty(figHandles)
        figHandles = gobjects(0,1);
        return;
    end

    [~, ia] = unique(ids(keep), 'stable');
    figHandles = figHandles(ia);
end

function tf = i_isKnownGUIFigure(fig, knownNames, knownTags, excludeAutoGUI)
    tf = false;

    figName = "";
    figTag = "";
    try, figName = string(fig.Name); catch, end
    try, figTag = string(fig.Tag); catch, end

    if any(strcmpi(figName, knownNames)) || any(strcmpi(figTag, knownTags))
        tf = true;
        return;
    end

    if excludeAutoGUI
        try
            numTitle = fig.NumberTitle;
        catch
            numTitle = '';
        end
        figNum = [];
        try
            figNum = fig.Number;
        catch
        end
        tf = strcmpi(string(numTitle), "off") && isempty(figNum);
    end
end
