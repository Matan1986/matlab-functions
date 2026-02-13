function s = pretty_label(k)
% Make a readable/TeX-safe label from a channel key.
    k = char(k);
    k = strrep(k, '_', '\_');
    tokens = regexp(k, '^([A-Za-z\\]+)(\d+)$', 'tokens', 'once');
    if ~isempty(tokens)
        s = sprintf('%s_{%s}', tokens{1}, tokens{2});
    else
        s = k;
    end
end
