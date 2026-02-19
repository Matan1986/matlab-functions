function report = FCS_applyTypography(figHandles, profileName, opts)
% FCS_applyTypography Apply FontName-only typography profile to explicit figures.
% This function never resolves targets implicitly and never uses gcf.

    if nargin < 2 || isempty(profileName)
        profileName = "Default";
    end
    if nargin < 3 || ~isstruct(opts)
        opts = struct();
    end

    includeUI = false;
    if isfield(opts, 'includeUI') && ~isempty(opts.includeUI)
        includeUI = logical(opts.includeUI);
    end

    figs = i_validateExplicitFigureHandles(figHandles);
    profile = FCS_getTypographyProfile(profileName);

    [resolvedFontName, fallbackUsed, fallbackSource] = i_resolveAvailableFont(profile);

    report = struct();
    report.profileName = char(profile.Name);
    report.requestedFontName = char(profile.FontName);
    report.resolvedFontName = char(resolvedFontName);
    report.fallbackUsed = logical(fallbackUsed);
    report.fallbackSource = char(fallbackSource);
    report.figuresProcessed = numel(figs);
    report.objectsExamined = 0;
    report.objectsChanged = 0;
    report.objectsSkipped = 0;
    report.objectsErrored = 0;

    if isempty(figs)
        return;
    end

    for kFig = 1:numel(figs)
        fig = figs(kFig);
        if ~isgraphics(fig, 'figure')
            continue;
        end

        objs = i_collectTypographyTargets(fig);
        report.objectsExamined = report.objectsExamined + numel(objs);

        for kObj = 1:numel(objs)
            obj = objs(kObj);
            if isempty(obj) || ~isgraphics(obj)
                report.objectsSkipped = report.objectsSkipped + 1;
                continue;
            end

            if ~isprop(obj, 'FontName')
                report.objectsSkipped = report.objectsSkipped + 1;
                continue;
            end

            if ~includeUI && i_isUIObject(obj)
                report.objectsSkipped = report.objectsSkipped + 1;
                continue;
            end

            try
                currentFont = string(obj.FontName);
            catch
                report.objectsErrored = report.objectsErrored + 1;
                continue;
            end

            if strlength(resolvedFontName) == 0
                report.objectsSkipped = report.objectsSkipped + 1;
                continue;
            end

            if strcmpi(currentFont, resolvedFontName)
                report.objectsSkipped = report.objectsSkipped + 1;
                continue;
            end

            try
                obj.FontName = char(resolvedFontName);
                report.objectsChanged = report.objectsChanged + 1;
            catch
                report.objectsErrored = report.objectsErrored + 1;
            end
        end
    end
end

function [resolvedFontName, fallbackUsed, fallbackSource] = i_resolveAvailableFont(profile)
    resolvedFontName = "";
    fallbackUsed = false;
    fallbackSource = "none";

    availableFonts = strings(0,1);
    listfontsAvailable = true;
    try
        lf = listfonts;
        if iscell(lf)
            availableFonts = string(lf(:));
        elseif isstring(lf)
            availableFonts = lf(:);
        end
    catch
        availableFonts = strings(0,1);
        listfontsAvailable = false;
    end

    requested = string(profile.FontName);
    candidates = string.empty(0,1);
    if strlength(strtrim(requested)) > 0
        candidates(end+1,1) = requested;
    end

    if isfield(profile, 'Fallbacks') && ~isempty(profile.Fallbacks)
        fb = string(profile.Fallbacks(:));
        candidates = [candidates; fb]; %#ok<AGROW>
    end

    if isempty(candidates)
        fallbackSource = "no-requested-font";
        return;
    end

    if ~listfontsAvailable || isempty(availableFonts)
        fallbackUsed = true;
        fallbackSource = "font-list-unavailable-noop";
        return;
    end

    for i = 1:numel(candidates)
        c = strtrim(candidates(i));
        if strlength(c) == 0
            continue;
        end

        tf = any(strcmpi(availableFonts, c));

        if tf
            resolvedFontName = c;
            if i > 1
                fallbackUsed = true;
                fallbackSource = "profile-fallback";
            else
                fallbackSource = "requested";
            end
            return;
        end
    end

    fallbackUsed = true;
    fallbackSource = "current-font-noop";
end

function objs = i_collectTypographyTargets(fig)
    objs = gobjects(0,1);

    try
        allObjs = findall(fig, '-property', 'FontName');
        if ~isempty(allObjs)
            objs = [objs; allObjs(:)]; %#ok<AGROW>
        end
    catch
    end

    try
        axList = findall(fig, 'Type', 'axes');
        for i = 1:numel(axList)
            ax = axList(i);
            if ~isgraphics(ax, 'axes')
                continue;
            end
            try, objs(end+1,1) = ax.Title; catch, end %#ok<AGROW>
            try, objs(end+1,1) = ax.XLabel; catch, end %#ok<AGROW>
            try, objs(end+1,1) = ax.YLabel; catch, end %#ok<AGROW>
            try, objs(end+1,1) = ax.ZLabel; catch, end %#ok<AGROW>
            try
                if isprop(ax, 'XAxis') && ~isempty(ax.XAxis) && isprop(ax.XAxis, 'FontName')
                    objs(end+1,1) = ax.XAxis; %#ok<AGROW>
                end
            catch
            end
            try
                if isprop(ax, 'YAxis') && ~isempty(ax.YAxis) && isprop(ax.YAxis, 'FontName')
                    objs(end+1,1) = ax.YAxis; %#ok<AGROW>
                end
            catch
            end
            try
                if isprop(ax, 'ZAxis') && ~isempty(ax.ZAxis) && isprop(ax.ZAxis, 'FontName')
                    objs(end+1,1) = ax.ZAxis; %#ok<AGROW>
                end
            catch
            end
        end
    catch
    end

    if isempty(objs)
        return;
    end

    keep = false(size(objs));
    ids = nan(size(objs));
    for i = 1:numel(objs)
        try
            keep(i) = isgraphics(objs(i)) && isvalid(objs(i));
            if keep(i)
                ids(i) = double(objs(i));
            end
        catch
            keep(i) = false;
        end
    end
    objs = objs(keep);
    if isempty(objs)
        return;
    end

    [~, ia] = unique(ids(keep), 'stable');
    objs = objs(ia);
end

function tf = i_isUIObject(obj)
    tf = false;
    if isempty(obj) || ~isgraphics(obj)
        return;
    end

    cls = "";
    try
        cls = string(class(obj));
    catch
    end

    if startsWith(lower(cls), "matlab.ui.")
        tf = true;
        return;
    end

    typ = "";
    try
        if isprop(obj, 'Type')
            typ = string(obj.Type);
        end
    catch
    end

    if startsWith(lower(typ), "ui")
        tf = true;
    end
end

function figs = i_validateExplicitFigureHandles(figHandles)
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
        error('FCS_applyTypography:InvalidFigureHandles', 'figHandles must contain only valid figure handles.');
    end

    [~, ia] = unique(ids, 'stable');
    figs = raw(ia);
end
