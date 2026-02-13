function meta = parse_MH_metadata(directory, filename)

    full = lower(fullfile(directory, filename));

    %% Growth MG ###
    mg = regexp(full, 'mg[_\- ]?(\d+)', 'tokens', 'once');
    if ~isempty(mg)
        meta.growth = sprintf('MG %s', mg{1});
    else
        meta.growth = 'MG ???';
    end

    %% Orientation
    if contains(full,'oop') || contains(full,'out') || contains(full,'outof')
        meta.orientation = "Out-of-plane";
    elseif contains(full,'in') && contains(full,'plan')
        meta.orientation = "In-plane";
    else
        meta.orientation = "Orientation Unknown";
    end

    %% Measurement type
    meta.measureType = "M(H)";

    %% Build title and figName (same text)
    base = sprintf('%s, %s, %s', meta.measureType, meta.growth, meta.orientation);

    %% Remove illegal filename characters ONLY (Windows rules)
    % Characters not allowed:  \ / : * ? " < > |
    base = strrep(base, '\',' ');
    base = strrep(base, '/',' ');
    base = strrep(base, ':',' ');
    base = strrep(base, '*',' ');
    base = strrep(base, '?',' ');
    base = strrep(base, '"',' ');
    base = strrep(base, '<',' ');
    base = strrep(base, '>',' ');
    base = strrep(base, '|',' ');

    % Collapse double spaces
    base = regexprep(base, '\s+', ' ');

    % Trim edges
    base = strtrim(base);

    meta.figName = base;
    meta.title   = base;
end
