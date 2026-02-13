function keys = tags_to_channel_keys(tags)
% Convert preset-style tags like '2xx','4xx' to channel keys 'ch2','ch4'
% Only the leading number is used.

if isempty(tags)
    keys = {};
    return
end

if isstring(tags)
    tags = cellstr(tags);
end

keys = cell(1, numel(tags));
for i = 1:numel(tags)
    tok = regexp(tags{i}, '^(\d+)', 'tokens', 'once');
    if isempty(tok)
        error('Invalid tag "%s". Expected something like "2xx".', tags{i});
    end
    keys{i} = ['ch' tok{1}];
end
end
