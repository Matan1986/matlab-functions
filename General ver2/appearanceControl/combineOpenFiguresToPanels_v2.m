function outFig = combineOpenFiguresToPanels_v2(nx, ny, figW, figH)
% ========================================================================
% DEPRECATION NOTICE (LEGACY GEOMETRY ENGINE)
% This file is deprecated for new development.
% It remains for backward compatibility only.
% Do not extend or reuse this file for new layout logic.
% New layout logic must use explicit target lists and stateless margin
% normalization.
% ========================================================================
% Combine open MATLAB figures into one ARTICLE figure (no font logic!)

skipNames = ["CtrlGUI","Final Figure Formatter","FigureTools","refLineGUI", ...
             "Appearance / Colormap Control"];
allF = findall(0,'Type','figure');
figs = [];
for i = 1:numel(allF)
    nm = string(get(allF(i),'Name'));
    if any(nm == skipNames), continue; end
    figs(end+1) = allF(i); %#ok<AGROW>
end

Nwant = nx * ny;
figs  = figs(1:min(numel(figs), Nwant));

outFig = figure('Color','w','Name','ArticleFigure',...
    'Units','inches','Position',[1 1 figW figH]);

tl = tiledlayout(outFig, ny, nx, ...
    'TileSpacing','compact', ...
    'Padding','compact');

letters = 'abcdefghijklmnopqrstuvwxyz';

for k = 1:(nx*ny)
    nexttile(tl, k);

    if k > numel(figs)
        axis off; continue;
    end

    srcFig = figs(k);
    axAll  = findall(srcFig,'Type','axes');
    axAll  = axAll(~strcmp(get(axAll,'Tag'),'legend'));

    if isempty(axAll)
        axis off; continue;
    end

    pos = vertcat(axAll.Position);
    [~,idx] = max(pos(:,3).*pos(:,4));
    srcAx = axAll(idx);

    dstAx = gca; cla(dstAx);
    copyobj(allchild(srcAx), dstAx);

    dstAx.XLim   = srcAx.XLim;
    dstAx.YLim   = srcAx.YLim;
    dstAx.XScale = srcAx.XScale;
    dstAx.YScale = srcAx.YScale;

    dstAx.XLabel.String = srcAx.XLabel.String;
    dstAx.YLabel.String = srcAx.YLabel.String;
    dstAx.Title.String  = srcAx.Title.String;

    text(dstAx, 0.02, 0.98, sprintf('(%c)', letters(k)), ...
        'Units','normalized','FontWeight','bold', ...
        'VerticalAlignment','top','HorizontalAlignment','left');
end
end
