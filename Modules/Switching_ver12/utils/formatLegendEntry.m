function entry = formatLegendEntry(value)
    % Split the value string using underscores
    parts = strsplit(value, '_');

    % Ensure there are at least 3 parts (avoid indexing errors)
    if numel(parts) < 3
        if numel(parts) == 2
            entry = sprintf('FC %s', parts{2}); % Handle cases like "0T"
        else
            entry = value; % Fallback for single-element values
        end
    else
        entry = sprintf('FC %s at %s', parts{2}, parts{3});
    end
end
