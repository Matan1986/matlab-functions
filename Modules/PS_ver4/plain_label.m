function s = plain_label(s)
% PLAIN_LABEL  Convert LaTeX/Unicode label variants into plain ASCII.
% Examples:
%   '\rho_{xx2}'       -> 'rho_xx2'
%   'ρxx2'             -> 'rho xx2'
%   '$\Delta \rho_{\perp}/\rho_{\parallel}$' -> 'Delta rho_perp/rho_parallel'

    if isstring(s), s = char(s); end
    if ~ischar(s),  s = char(string(s)); end

    % strip surrounding math mode $...$
    s = regexprep(s, '^\$(.*)\$$', '$1');

    % greek/unicode replacements
    s = strrep(s, 'ρ', 'rho');
    s = strrep(s, 'Δ', 'Delta');

    % LaTeX greek replacements
    s = strrep(s, '\rho', 'rho');
    s = strrep(s, '\Delta', 'Delta');

    % subscript {xx2} → _xx2
    s = regexprep(s, '\\?rho\s*_\{([^}]+)\}', 'rho_$1');

    % parallel/perp
    s = strrep(s, '\parallel', 'parallel');
    s = strrep(s, '\perp', 'perp');

    % remove stray backslashes
    s = strrep(s, '\', '');

    % clean multiple spaces
    s = regexprep(s, '\s{2,}', ' ');
end
