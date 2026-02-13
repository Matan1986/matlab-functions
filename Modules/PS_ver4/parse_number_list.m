function vals = parse_number_list(token_str)
% PARSE_NUMBER_LIST  Convert a token string like "4_12_20_28_36" or "3p5_7_11_14"
% into a numeric vector [4 12 20 28 36] or [3.5 7 11 14].
% Replaces 'p' with '.' to support filenames like "3p5" → 3.5.

    if isstring(token_str), token_str = char(token_str); end
    pieces = strsplit(token_str, '_');              % split at underscores
    vals = str2double(strrep(pieces, 'p', '.'));   % replace 'p' with '.'
    vals = unique(vals(~isnan(vals)));             % drop NaNs, sort unique
end
