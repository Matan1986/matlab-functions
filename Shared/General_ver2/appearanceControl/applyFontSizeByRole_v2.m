function applyFontSizeByRole_v2(fig, fs)

ax = findall(fig,'Type','axes');
for a = ax'
    a.FontSize = fs;
    if ~isempty(a.XLabel.String), a.XLabel.FontSize = fs+4; end
    if ~isempty(a.YLabel.String), a.YLabel.FontSize = fs+4; end
    if ~isempty(a.Title.String),  a.Title.FontSize  = fs+4; end
end

lg = findall(fig,'Type','legend');
for L = lg'
    L.FontSize = fs;
    L.Box = 'off';
end
end
