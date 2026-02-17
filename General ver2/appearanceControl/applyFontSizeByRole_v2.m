function applyFontSizeByRole_v2(fig, fs, varargin)

opts = i_parseOptions(varargin{:});

ax = findall(fig,'Type','axes');
for a = ax'
    a.FontSize = fs;
    if ~isempty(a.XLabel.String), a.XLabel.FontSize = fs+4; end
    if ~isempty(a.YLabel.String), a.YLabel.FontSize = fs+4; end
    if ~isempty(a.Title.String),  a.Title.FontSize  = fs+4; end
end

if opts.AffectLegend
    lg = findall(fig,'Type','legend');
    for L = lg'
        L.FontSize = fs;
        L.Box = 'off';
    end
end
end

function opts = i_parseOptions(varargin)
opts = struct('AffectLegend', true);
if isempty(varargin)
    return;
end

if mod(numel(varargin), 2) ~= 0
    error('applyFontSizeByRole_v2:InvalidOptions', 'Options must be provided as name-value pairs.');
end

for k = 1:2:numel(varargin)
    name = string(varargin{k});
    value = varargin{k+1};
    switch lower(name)
        case "affectlegend"
            if ~(islogical(value) && isscalar(value))
                error('applyFontSizeByRole_v2:InvalidAffectLegend', 'AffectLegend must be a logical scalar.');
            end
            opts.AffectLegend = logical(value);
        otherwise
            error('applyFontSizeByRole_v2:UnknownOption', 'Unknown option: %s', char(name));
    end
end
end
