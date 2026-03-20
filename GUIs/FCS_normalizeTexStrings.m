function report = FCS_normalizeTexStrings(figHandles, opts)
% FCS_normalizeTexStrings
% Safely normalize LaTeX-like strings for MATLAB 'tex' interpreter.
% Operates in-place and only on objects whose Interpreter == 'tex'.
%
% ===============================
% NORMALIZATION RULES REGISTRY
% ===============================
%
% This function converts LaTeX-like strings into scientific MATLAB TEX-compatible text.
%
% RULES (in execution order):
%
% [R0] Remove numeric $...$ delimiters
%      '$100$' -> '100'
%      '$0$'   -> '0'
%
% [R1] Remove simple $...$ delimiters
%      '$T_N$' -> 'T_N'
%
% [R2] Preserve complex LaTeX segments (e.g. \frac, \sqrt)
%
% [R3] Strip LaTeX wrappers:
%      \mathrm{X} -> X
%      \text{X}   -> X
%      \mathbf{X} -> X
%
% [R4] Remove LaTeX spacing:
%      '\,' -> ' '
%      '\ ' -> ' '
%
% [R5] Replace symbols:
%      '\AA' -> 'Å'
%
% [R6] Convert symbols to ASCII-safe representations
%      '\mu'    -> 'mu'
%      '\Omega' -> 'Ohm'
%      '\Gamma' -> 'Gamma'
%
% [R7] Normalize word subscripts
%      'rho_parallel' -> 'rho_{parallel}'
%
% [R8] Normalize TEX sub/superscript syntax
%      'k_y'  -> 'k_{y}'
%      'K^-1' -> 'K^{-1}'
%
% [R9] Scientific TEX mode enforcement
%      Ensures subscripts/superscripts follow MATLAB TEX syntax.
%
% NOTE:
% This is NOT a full LaTeX parser.
% Only a safe subset is normalized for MATLAB 'tex' interpreter compatibility.

    if nargin < 2 || ~isstruct(opts)
        opts = struct();
    end

    debug = false;
    if isfield(opts, 'debug') && ~isempty(opts.debug)
        debug = logical(opts.debug);
    end
    allowedInterpreters = ["tex"];
    if isfield(opts, 'allowedInterpreters') && ~isempty(opts.allowedInterpreters)
        allowedInterpreters = lower(strtrim(string(opts.allowedInterpreters(:))));
        allowedInterpreters = allowedInterpreters(strlength(allowedInterpreters) > 0);
        if isempty(allowedInterpreters)
            allowedInterpreters = ["tex"];
        end
    end

    figs = i_validateFigureHandles(figHandles);

    report = struct();
    report.figuresProcessed = numel(figs);
    report.examinedCount = 0;
    report.modifiedCount = 0;
    report.skippedComplexCount = 0;
    report.unchangedCount = 0;
    report.errorCount = 0;
    report.modified = strings(0,1);
    report.skippedComplex = strings(0,1);

    if isempty(figs)
        return;
    end

    for kFig = 1:numel(figs)
        fig = figs(kFig);
        if ~isgraphics(fig, 'figure')
            continue;
        end

        excludedTextIds = nan(0,1);

        % Axes labels and title
        axList = findall(fig, 'Type', 'axes');
        for iAx = 1:numel(axList)
            ax = axList(iAx);
            if ~isgraphics(ax, 'axes')
                continue;
            end
            report = i_processTextObject(report, ax.Title, sprintf('Fig %d Axes[%d].Title', kFig, iAx), debug, allowedInterpreters);
            report = i_processTextObject(report, ax.XLabel, sprintf('Fig %d Axes[%d].XLabel', kFig, iAx), debug, allowedInterpreters);
            report = i_processTextObject(report, ax.YLabel, sprintf('Fig %d Axes[%d].YLabel', kFig, iAx), debug, allowedInterpreters);
            report = i_processTextObject(report, ax.ZLabel, sprintf('Fig %d Axes[%d].ZLabel', kFig, iAx), debug, allowedInterpreters);
            excludedTextIds = i_appendHandleId(excludedTextIds, ax.Title);
            excludedTextIds = i_appendHandleId(excludedTextIds, ax.XLabel);
            excludedTextIds = i_appendHandleId(excludedTextIds, ax.YLabel);
            excludedTextIds = i_appendHandleId(excludedTextIds, ax.ZLabel);
        end

        % Legend strings (char/string/cell container preserved)
        lgList = findall(fig, 'Type', 'legend');
        for iLg = 1:numel(lgList)
            report = i_processStringProperty(report, lgList(iLg), 'String', sprintf('Fig %d Legend[%d].String', kFig, iLg), debug, allowedInterpreters);
        end

        % Colorbar labels
        cbList = findall(fig, 'Type', 'colorbar');
        for iCb = 1:numel(cbList)
            cb = cbList(iCb);
            try
                if isprop(cb, 'Label') && isgraphics(cb.Label, 'text')
                    report = i_processTextObject(report, cb.Label, sprintf('Fig %d Colorbar[%d].Label', kFig, iCb), debug, allowedInterpreters);
                    excludedTextIds = i_appendHandleId(excludedTextIds, cb.Label);
                end
            catch
                report.errorCount = report.errorCount + 1;
            end
        end

        % In-axes text and figure text
        txList = findall(fig, 'Type', 'text');
        for iTx = 1:numel(txList)
            txId = i_getHandleId(txList(iTx));
            if ~isnan(txId) && any(excludedTextIds == txId)
                continue;
            end
            report = i_processTextObject(report, txList(iTx), sprintf('Fig %d Text[%d]', kFig, iTx), debug, allowedInterpreters);
        end

        % Annotation textbox + text arrows (existing annotation object classes)
        annTextbox = findall(fig, 'Type', 'textboxshape');
        for iAnn = 1:numel(annTextbox)
            report = i_processStringProperty(report, annTextbox(iAnn), 'String', sprintf('Fig %d AnnotationTextbox[%d].String', kFig, iAnn), debug, allowedInterpreters);
        end
        annTextArrow = findall(fig, 'Type', 'textarrowshape');
        for iAnn = 1:numel(annTextArrow)
            report = i_processStringProperty(report, annTextArrow(iAnn), 'String', sprintf('Fig %d AnnotationTextArrow[%d].String', kFig, iAnn), debug, allowedInterpreters);
        end
    end

    if debug
        fprintf('[FCS Tex Normalize][SUMMARY] objects=%d modified=%d skippedComplex=%d unchanged=%d errors=%d\n', ...
            report.examinedCount, report.modifiedCount, report.skippedComplexCount, report.unchangedCount, report.errorCount);
    end
end

function report = i_processTextObject(report, txtObj, contextLabel, debug, allowedInterpreters)
    if isempty(txtObj) || ~isgraphics(txtObj, 'text')
        report.unchangedCount = report.unchangedCount + 1;
        return;
    end
    report = i_processStringProperty(report, txtObj, 'String', contextLabel, debug, allowedInterpreters);
end

function report = i_processStringProperty(report, obj, propName, contextLabel, debug, allowedInterpreters)
    if isempty(obj) || ~isgraphics(obj)
        report.unchangedCount = report.unchangedCount + 1;
        return;
    end

    try
        if ~isprop(obj, 'Interpreter')
            report.unchangedCount = report.unchangedCount + 1;
            return;
        end
        interpValue = lower(strtrim(string(obj.Interpreter)));
        if ~any(interpValue == allowedInterpreters)
            report.unchangedCount = report.unchangedCount + 1;
            return;
        end
    catch
        report.errorCount = report.errorCount + 1;
        return;
    end

    try
        if ~isprop(obj, propName)
            report.unchangedCount = report.unchangedCount + 1;
            return;
        end
        rawValue = obj.(propName);
    catch
        report.errorCount = report.errorCount + 1;
        return;
    end

    report.examinedCount = report.examinedCount + 1;

    [newValue, wasChanged, complexSkipCount] = i_normalizeStringValue(rawValue);
    if complexSkipCount > 0
        report.skippedComplexCount = report.skippedComplexCount + complexSkipCount;
        if debug
            entry = contextLabel + " :: " + i_valuePreview(rawValue);
            report.skippedComplex(end+1,1) = entry; %#ok<AGROW>
            fprintf('[FCS Tex Normalize][SKIP COMPLEX] %s\n', char(entry));
        end
    end

    if ~wasChanged
        if complexSkipCount == 0
            report.unchangedCount = report.unchangedCount + 1;
        end
        return;
    end

    try
        obj.(propName) = newValue;
        report.modifiedCount = report.modifiedCount + 1;
        entry = contextLabel + " :: " + i_valuePreview(rawValue) + " -> " + i_valuePreview(newValue);
        report.modified(end+1,1) = entry; %#ok<AGROW>
        if debug
            fprintf('[FCS Tex Normalize][MODIFIED] %s\n', char(entry));
        end
    catch
        report.errorCount = report.errorCount + 1;
    end
end

function [newValue, changed, skippedComplexCount] = i_normalizeStringValue(rawValue)
    newValue = rawValue;
    changed = false;
    skippedComplexCount = 0;

    if isstring(rawValue)
        out = rawValue;
        for i = 1:numel(rawValue)
            [out(i), changedOne, complexOne] = i_normalizeScalarString(rawValue(i));
            changed = changed || changedOne;
            if complexOne > 0
                skippedComplexCount = skippedComplexCount + complexOne;
            end
        end
        if changed
            newValue = out;
        end
        return;
    end

    if ischar(rawValue)
        % Preserve char container shape (row or char matrix).
        if size(rawValue, 1) <= 1
            [outOne, changedOne, complexOne] = i_normalizeScalarString(string(rawValue));
            changed = changedOne;
            skippedComplexCount = complexOne;
            if changed
                newValue = char(outOne);
            end
        else
            originalCols = size(rawValue, 2);
            rows = cellstr(rawValue);
            outRows = rows;
            for i = 1:numel(rows)
                [rowOut, changedOne, complexOne] = i_normalizeScalarString(string(rows{i}));
                if changedOne
                    outRows{i} = char(rowOut);
                    changed = true;
                end
                if complexOne > 0
                    skippedComplexCount = skippedComplexCount + complexOne;
                end
            end
            if changed
                newValue = i_rebuildCharMatrixFixedWidth(outRows, originalCols);
            end
        end
        return;
    end

    if iscell(rawValue)
        outCell = rawValue;
        for i = 1:numel(rawValue)
            entry = rawValue{i};
            if ischar(entry) || (isstring(entry) && isscalar(entry))
                [entryOut, changedOne, complexOne] = i_normalizeScalarString(string(entry));
                if changedOne
                    if isstring(entry)
                        outCell{i} = entryOut;
                    else
                        outCell{i} = char(entryOut);
                    end
                    changed = true;
                end
                if complexOne > 0
                    skippedComplexCount = skippedComplexCount + complexOne;
                end
            end
        end
        if changed
            newValue = outCell;
        end
        return;
    end
end

function [out, changed, complexCount] = i_normalizeScalarString(in)
    s = string(in);
    if strlength(s) == 0
        out = s;
        changed = false;
        complexCount = 0;
        return;
    end

    txt = char(s);
    if ~i_mightNeedNormalization(txt)
        out = s;
        changed = false;
        complexCount = 0;
        return;
    end

    original = txt;
    complexCount = 0;
    simpleDollarChanged = false;

    % [R0] Remove numeric $...$ segments before general dollar processing.
    if contains(txt, '$')
        txtNum = regexprep(txt, '\$([0-9]+)\$', '$1');
        if ~strcmp(txtNum, txt)
            simpleDollarChanged = true;
            txt = txtNum;
        end
    end

    % [R1] HANDLE SIMPLE $...$ SEGMENTS
    if contains(txt, '$')
        matches = regexp(txt, '\$(.*?)\$', 'match');
        txtOut = txt;
        for iTok = 1:numel(matches)
            fullMatch = matches{iTok};
            seg = regexp(fullMatch, '^\$(.*?)\$$', 'tokens', 'once');
            seg = seg{1};
            % If no LaTeX command -> simple case -> remove $
            if ~contains(seg, '\')
                txtOutNew = strrep(txtOut, fullMatch, seg);
                if ~strcmp(txtOutNew, txtOut)
                    simpleDollarChanged = true;
                    txtOut = txtOutNew;
                end
            end
        end
        txt = txtOut;
    end

    [txtSeg, segChanged, segComplexCount, hasDollarSegments] = i_processDollarSegments(txt);
    txt = txtSeg;
    complexCount = complexCount + segComplexCount;
    [txt, coreChanged] = i_normalizeNonComplexChunk(txt, true, true);
    changed = simpleDollarChanged || segChanged || coreChanged || ~strcmp(original, txt);
    out = string(txt);
end

function [txtOut, changed, complexCount, hasSegments] = i_processDollarSegments(txtIn)
    txtOut = txtIn;
    changed = false;
    complexCount = 0;
    hasSegments = false;

    if ~contains(txtIn, '$')
        return;
    end
    if count(txtIn, '$') < 2
        return;
    end

    starts = regexp(txtIn, '(?<!\\)\$[^\$\r\n]*(?<!\\)\$', 'start');
    ends = regexp(txtIn, '(?<!\\)\$[^\$\r\n]*(?<!\\)\$', 'end');
    if isempty(starts)
        return;
    end

    hasSegments = true;
    parts = cell(0,1);
    cursor = 1;
    for i = 1:numel(starts)
        s = starts(i);
        e = ends(i);
        if s > cursor
            outerChunk = txtIn(cursor:s-1);
            parts{end+1,1} = outerChunk; %#ok<AGROW>
        end

        inner = txtIn(s+1:e-1);
        [innerCandidate, didUnwrapWrapper] = i_tryUnwrapSimpleWrapper(inner);
        if didUnwrapWrapper
            innerClassify = innerCandidate;
        else
            innerClassify = inner;
        end
        if strlength(strtrim(string(inner))) == 0
            % Degenerate/empty math segment: keep unchanged for safety.
            parts{end+1,1} = txtIn(s:e); %#ok<AGROW>
        elseif ~i_isSimpleMathSegment(innerClassify)
            % [R2] Preserve complex LaTeX segment as-is.
            parts{end+1,1} = txtIn(s:e); %#ok<AGROW>
            complexCount = complexCount + 1;
        else
            [innerNorm, innerChanged] = i_normalizeNonComplexChunk(innerClassify, true, true);
            parts{end+1,1} = innerNorm; %#ok<AGROW>
            changed = changed || didUnwrapWrapper || innerChanged || ~strcmp(innerClassify, innerNorm) || ~strcmp(inner, innerNorm);
        end
        cursor = e + 1;
    end
    if cursor <= numel(txtIn)
        outerChunk = txtIn(cursor:end);
        parts{end+1,1} = outerChunk; %#ok<AGROW>
    end

    txtOut = [parts{:}];
end

function tf = i_isSimpleMathSegment(txt)
    tf = false;
    if isempty(txt)
        return;
    end
    if i_containsComplexLatex(txt)
        return;
    end

    % Conservative boundary: slash and linebreak-like patterns are risky.
    if contains(txt, '/') || contains(txt, '\\') || contains(txt, '&')
        return;
    end

    if ~isempty(regexp(txt, '\{[^{}]*,[^{}]*\}', 'once'))
        return;
    end

    % Non-math/currency-like guard: no letters, no command marker, no sub/sup.
    if isempty(regexp(txt, '[A-Za-z]', 'once')) && ~contains(txt, '\') && ~contains(txt, '_') && ~contains(txt, '^')
        return;
    end

    % Spacing-command-only segments are kept complex for safety.
    if ~isempty(regexp(txt, '^\\[,!:;]$', 'once')) || strcmp(txt, '\quad') || strcmp(txt, '\qquad')
        return;
    end

    % Allow only a restricted character set for simplification.
    if isempty(regexp(txt, '^[A-Za-z0-9_\^\{\}\\\.\,\:\;\!\+\-\=\(\)\s]*$', 'once'))
        return;
    end

    % If spaces exist, require at least one clear math/context marker.
    if any(isspace(txt))
        if ~(contains(txt, '=') || contains(txt, '\') || contains(txt, '_') || contains(txt, '^') || ...
             contains(txt, '+') || contains(txt, '-') || contains(txt, '(') || contains(txt, ')'))
            return;
        end
    end

    tf = true;
end

function [txt, changed] = i_normalizeNonComplexChunk(txtIn, allowOuterBraceStrip, doTrim)
    if nargin < 3
        doTrim = true;
    end
    txt = txtIn;
    changed = false;
    if isempty(txt)
        return;
    end

    before = txt;

    % [R1] Remove remaining '$' in non-segment content
    if contains(txt, '$')
        txt = strrep(txt, '$', '');
    end

    % [R3] Strip LaTeX wrappers (\mathrm, \text, \mathbf, \mathit)
    if contains(txt, '\')
        while true
            txtNew = regexprep(txt, '\\(?:mathrm|text|mathbf|mathit)\{((?:[^{}]|\{[^{}]*\})*)\}', '$1');
            if strcmp(txtNew, txt)
                break;
            end
            txt = txtNew;
        end
    end

    % [R4] Remove LaTeX spacing escapes + punctuation normalization
    if contains(txt, '\')
        txt = regexprep(txt, '\\\s+', ' ');
        txt = regexprep(txt, '\\[,!:;]', ' ');
    end
    if contains(txt, ',') || contains(txt, '!') || contains(txt, ':') || contains(txt, ';')
        txt = regexprep(txt, '[,!:;]+', ' ');
    end

    % [R5] Symbol replacements for readable plain text
    if contains(txt, '\AA')
        txt = strrep(txt, '\AA', char(197));
    end

    % Step E: visual-only commands
    if contains(txt, '\left')
        txt = regexprep(txt, '\\left\s*', '');
    end
    if contains(txt, '\right')
        txt = regexprep(txt, '\\right\s*', '');
    end

    % Step F: targeted fixes (no deep brace parsing)
    if contains(txt, '^{}') || contains(txt, '^{')
        txt = regexprep(txt, '\^\{\s*\}', '');
    end
    if contains(txt, '_{}') || contains(txt, '_{')
        txt = regexprep(txt, '_\{\s*\}', '');
    end
    if allowOuterBraceStrip && startsWith(txt, '{') && endsWith(txt, '}')
        txt = i_stripWholeOuterBraces(txt);
    end

    % Rule A: collapse clearly safe simple subscript braces (letter_{token}).
    if allowOuterBraceStrip
        txt = regexprep(txt, '(^|[^A-Za-z\\])([A-Za-z])_\{([A-Za-z0-9]+)\}', '$1$2_$3');
        txt = regexprep(txt, '_\{([A-Za-z0-9]+)\}', '_$1');
    end

    % [R6] Convert symbols to ASCII-safe forms (MATLAB TEX compatible).
    txt = strrep(txt, '\mu', 'mu');
    txt = strrep(txt, '\Omega', 'Ohm');
    txt = strrep(txt, '\Gamma', 'Gamma');

    % [R7] Normalize word subscripts.
    txt = regexprep(txt, '([A-Za-z])_([A-Za-z]+)', '$1_{$2}');
    txt = strrep(txt, '_{parallel}', '_{\parallel}');

    % [R8]/[R9] Final Scientific TEX mode enforcement for sub/superscripts.
    txt = regexprep(txt, '([A-Za-z])_([A-Za-z0-9])', '$1_{$2}');
    txt = regexprep(txt, '\^(-?\d+)', '^{$1}');
    txt = regexprep(txt, '\s*\^\s*\{', '^{');

    % Step G: whitespace
    if contains(txt, '  ') || contains(txt, sprintf('\t')) || contains(txt, sprintf('\n')) || contains(txt, sprintf('\r'))
        txt = regexprep(txt, '[ \t\r\n]+', ' ');
    end
    if doTrim
        txt = regexprep(txt, '^[ \t\r\n]+', '');
        txt = regexprep(txt, '[ \t\r\n]+$', '');
    end

    changed = ~strcmp(before, txt);
end

function tf = i_mightNeedNormalization(txt)
    tf = false;
    if isempty(txt)
        return;
    end
    tf = contains(txt, '$') || contains(txt, '\') || contains(txt, '{') || contains(txt, '}') || ...
         contains(txt, '_') || contains(txt, '^');
end

function out = i_stripWholeOuterBraces(txt)
    out = txt;
    if numel(out) < 2 || out(1) ~= '{' || out(end) ~= '}'
        return;
    end
    inner = out(2:end-1);
    if contains(inner, '{') || contains(inner, '}')
        return;
    end
    out = inner;
end

function tf = i_containsComplexLatex(txt)
    tf = false;
    if isempty(txt)
        return;
    end
    complexTokens = {'\frac', '\sqrt', '\sum', '\int', '\begin', '\end', ...
                     '\prod', '\lim', '\oint', '\binom', '\stackrel', '\overset', '\underset', ...
                     '\middle', ...
                     '\left', '\right', '\overline', '\underline', ...
                     '\mathbf', '\mathit', '\mathcal', '\mathbb', ...
                     '\hat', '\tilde', '\bar', '\vec', '\dot', '\ddot', ...
                     '\langle', '\rangle', '\big', '\Big', '\bigg', '\Bigg', ...
                     '\matrix', '\pmatrix', '\bmatrix', '\Bmatrix', '\vmatrix', '\Vmatrix', '\cases'};
    for i = 1:numel(complexTokens)
        if contains(txt, complexTokens{i})
            tf = true;
            return;
        end
    end

    % Conservative heuristic: nested/structured brace usage is treated as complex.
    if count(txt, '{') ~= count(txt, '}')
        tf = true;
        return;
    end
    if count(txt, '{') > 1 || count(txt, '}') > 1
        tf = true;
        return;
    end
    if ~isempty(regexp(txt, '\{[^{}]*\{[^{}]*\}', 'once'))
        tf = true;
        return;
    end
end

function [inner, didUnwrap] = i_tryUnwrapSimpleWrapper(txt)
    inner = txt;
    didUnwrap = false;
    if isempty(txt)
        return;
    end
    startTok = regexp(txt, '^\\(?:mathrm|text|mathbf|mathit)\{', 'once');
    if isempty(startTok) || txt(end) ~= '}'
        return;
    end
    openPos = regexp(txt, '\{', 'once');
    if isempty(openPos) || openPos >= numel(txt)
        return;
    end
    depth = 0;
    closePos = -1;
    for i = openPos:numel(txt)
        ch = txt(i);
        if ch == '{'
            depth = depth + 1;
        elseif ch == '}'
            depth = depth - 1;
            if depth == 0
                closePos = i;
                break;
            elseif depth < 0
                return;
            end
        end
    end
    if closePos ~= numel(txt) || depth ~= 0
        return;
    end
    inner = txt(openPos+1:closePos-1);
    didUnwrap = true;
end

function txt = i_valuePreview(v)
    try
        if isstring(v)
            txt = strjoin(v(:)', " | ");
        elseif ischar(v)
            txt = string(v);
        elseif iscell(v)
            parts = strings(0,1);
            for i = 1:numel(v)
                if ischar(v{i}) || (isstring(v{i}) && isscalar(v{i}))
                    parts(end+1,1) = string(v{i}); %#ok<AGROW>
                else
                    parts(end+1,1) = "<non-text>"; %#ok<AGROW>
                end
            end
            txt = strjoin(parts, " | ");
        else
            txt = "<unsupported>";
        end
        if strlength(txt) > 220
            txt = extractBefore(txt, 220) + "...";
        end
    catch
        txt = "<preview-error>";
    end
end

function figs = i_validateFigureHandles(figHandles)
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
        error('FCS_normalizeTexStrings:InvalidFigureHandles', 'figHandles must contain only valid figure handles.');
    end

    [~, ia] = unique(ids, 'stable');
    figs = raw(ia);
end

function ids = i_appendHandleId(ids, h)
    id = i_getHandleId(h);
    if ~isnan(id)
        ids(end+1,1) = id; %#ok<AGROW>
    end
end

function id = i_getHandleId(h)
    id = NaN;
    try
        if ~isempty(h) && isgraphics(h)
            id = double(h);
        end
    catch
        id = NaN;
    end
end

function out = i_rebuildCharMatrixFixedWidth(rows, widthTarget)
    if nargin < 2 || isempty(widthTarget) || ~isfinite(widthTarget) || widthTarget < 0
        widthTarget = 0;
    end
    widthTarget = max(0, floor(double(widthTarget)));
    n = numel(rows);
    outRows = cell(n,1);
    for i = 1:n
        s = char(string(rows{i}));
        if numel(s) >= widthTarget
            outRows{i} = s(1:widthTarget);
        else
            outRows{i} = [s repmat(' ', 1, widthTarget - numel(s))];
        end
    end
    if isempty(outRows)
        out = repmat(' ', 0, widthTarget);
    else
        out = char(outRows);
    end
end
