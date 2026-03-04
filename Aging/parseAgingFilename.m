function meta = parseAgingFilename(fname)
% parseAgingFilename — Extract metadata (pause T, wait hours, FC field, meas field)
L = lower(fname);

meta.isNoPause = contains(L, 'afterzfc');
meta.measOe    = extractNumeric(L, 'measure[_-]?(\d+(\.\d+)?)\s*oe');
meta.fcT       = extractNumeric(L, 'after[_-]?(\d+(\.\d+)?)\s*t[_-]');
meta.waitHours = extractNumeric(L, '_(\d+(\.\d+)?)\s*hour[_-]');
meta.waitK     = extractNumeric(L, 'at[_-](\d+(\.\d+)?)\s*k');
end

function val = extractNumeric(str, pattern)
tok = regexp(str, pattern, 'tokens', 'once');
if isempty(tok)
    val = NaN;
else
    val = str2double(tok{1});
end
end
