function s = cleanChannelLabel(s)
    if isempty(s), return; end

    s = string(s);

    % remove all digits
    s = regexprep(s,'\d+','');

    % xx / xy → symbols
    s = regexprep(s,'xx','\\parallel');
    s = regexprep(s,'xy','\\perp');

    % LaTeX safety: no dangling underscore
    s = regexprep(s,'_$','');

    s = char(s);
end
