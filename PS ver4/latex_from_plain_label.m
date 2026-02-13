function s = latex_from_plain_label(s)
% LATEX_FROM_PLAIN_LABEL  Map plain tokens to LaTeX-safe label strings.
% Examples:
%   'rho_xx2'          -> '\rho_{xx2}'
%   'parallel'         -> '\parallel'
%   'perp'             -> '\perp'
%   'Delta rho_xx2'    -> '\Delta \rho_{xx2}'
%   (Already LaTeX) '\rho_{xx2}' -> '\rho_{xx2}'

    if isstring(s), s = char(s); end
    if ~ischar(s),  s = char(string(s)); end
    t = strtrim(s);

    % If it already contains common LaTeX tokens, leave it as-is
    if startsWith(t, '$') || contains(t, '\rho') || contains(t, '\Delta') ...
            || contains(t, '\parallel') || contains(t, '\perp')
        s = t;
        return
    end

    % Replace plain keywords with LaTeX
    % Handle 'rho_<subscript>'
    m = regexp(t, '\brho_([A-Za-z0-9]+)\b', 'tokens', 'once');
    if ~isempty(m)
        t = regexprep(t, '\brho_([A-Za-z0-9]+)\b', '\\rho_{$1}');
    else
        % Standalone 'rho' → '\rho'
        t = regexprep(t, '\brho\b', '\\rho');
    end

    % Leading 'Delta ' → '\Delta '
    t = regexprep(t, '(^|\s)Delta(\s+)', '$1\\Delta$2');

    % 'parallel' / 'perp'
    t = regexprep(t, '\bparallel\b', '\\parallel');
    t = regexprep(t, '\bperp\b',     '\\perp');

    s = t;
end
