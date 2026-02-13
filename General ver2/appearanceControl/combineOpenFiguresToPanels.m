function outFig = combineOpenFiguresToPanels(nx, ny, journalMode, outPdfPath)
% Combines open MATLAB figures into ARTICLE-style multi-panel figure.
% Robust: does NOT copy axes directly (avoids TightInset/Position bugs).

if nargin < 1 || isempty(nx), nx = 2; end
if nargin < 2 || isempty(ny), ny = 1; end
if nargin < 3 || isempty(journalMode), journalMode = "PRL-double"; end
if nargin < 4, outPdfPath = ""; end

%% ================= JOURNAL PRESETS =================
switch string(journalMode)
    case "PRL-single"
        figW = 3.375; baseH = 4.5;
    case "PRL-double"
        figW = 7.0;   baseH = 3.8;
    case "Nature-single"
        figW = 3.5;   baseH = 5.0;
    case "Nature-double"
        figW = 7.2;   baseH = 4.8;
    otherwise
        error('Unknown journalMode');
end
figH = baseH * ny;

%% ================= COLLECT REAL FIGURES =================
skipNames = ["CtrlGUI","Final Figure Formatter","FigureTools","refLineGUI", ...
             "Appearance / Colormap Control","CombinedPanels","ArticleFigure"];

allF = findall(0,'Type','figure');
figs = [];

for f = allF'
    nm = string(get(f,'Name'));
    if any(nm == skipNames), continue; end
    figs(end+1) = f; %#ok<AGROW>
end

if isempty(figs)
    error('No non-GUI figures found.');
end

Nwant = nx * ny;
figs  = figs(1:min(numel(figs),Nwant));

%% ================= CREATE OUTPUT FIGURE =================
outFig = figure( ...
    'Name','ArticleFigure', ...
    'Color','w', ...
    'Units','inches', ...
    'Position',[1 1 figW figH]);

%% ================= PANEL GEOMETRY =================
gapX = 0.05;
gapY = 0.08;

panelW = (1 - (nx+1)*gapX) / nx;
panelH = (1 - (ny+1)*gapY) / ny;

letters = 'abcdefghijklmnopqrstuvwxyz';

%% ================= MAIN LOOP =================
for k = 1:(nx*ny)

    if k > numel(figs)
        break;
    end

    row = ceil(k / nx);
    col = mod(k-1, nx) + 1;

    left   = gapX + (col-1)*(panelW + gapX);
    bottom = 1 - row*(panelH + gapY);

    panelPos = [left bottom panelW panelH];
    srcFig   = figs(k);

    % ---- detect real axes (exclude legends & colorbars)
    srcAx = findall(srcFig,'Type','axes');
    srcAx = srcAx(~strcmp(get(srcAx,'Tag'),'legend'));
    srcAx = srcAx(~arrayfun(@isColorbarAxes, srcAx));

    if isempty(srcAx)
        continue;
    end

    %% ===== MULTI-AXIS FIGURE =====
    if numel(srcAx) > 1

        pos = vertcat(srcAx.Position);
        left0   = min(pos(:,1));
        bottom0 = min(pos(:,2));
        right0  = max(pos(:,1)+pos(:,3));
        top0    = max(pos(:,2)+pos(:,4));

        w0 = right0 - left0;
        h0 = top0   - bottom0;

        for a = srcAx'

            newAx = axes(outFig);
            newAx.Units = 'normalized';

            % ---- scale position
            p = a.Position;
            p(1) = panelPos(1) + panelPos(3)*(p(1)-left0)/w0;
            p(2) = panelPos(2) + panelPos(4)*(p(2)-bottom0)/h0;
            p(3) = panelPos(3)*p(3)/w0;
            p(4) = panelPos(4)*p(4)/h0;
            newAx.Position = p;

            % ---- copy graphics only
            copyobj(allchild(a), newAx);

            % ---- copy axis limits & scales
            newAx.XLim = a.XLim;
            newAx.YLim = a.YLim;
            newAx.ZLim = a.ZLim;
            newAx.XScale = a.XScale;
            newAx.YScale = a.YScale;

            % ---- copy visual state
            newAx.Box      = a.Box;
            newAx.LineWidth = a.LineWidth;
            newAx.TickDir  = a.TickDir;
            newAx.Layer    = a.Layer;

            newAx.XDir = a.XDir;
            newAx.YDir = a.YDir;

            newAx.DataAspectRatio = a.DataAspectRatio;
            newAx.PlotBoxAspectRatio = a.PlotBoxAspectRatio;

            newAx.CLim = a.CLim;

            grid(newAx, a.XGrid);
            newAx.YGrid = a.YGrid;
            newAx.ZGrid = a.ZGrid;

            newAx.FontSize = a.FontSize;
            newAx.FontName = a.FontName;
            newAx.TickLabelInterpreter = a.TickLabelInterpreter;

        end

    %% ===== SINGLE AXIS FIGURE =====
    else

        a = srcAx(1);

        newAx = axes(outFig);
        newAx.Units = 'normalized';
        newAx.Position = panelPos;

        copyobj(allchild(a), newAx);

        newAx.XLim = a.XLim;
        newAx.YLim = a.YLim;
        newAx.ZLim = a.ZLim;
        newAx.XScale = a.XScale;
        newAx.YScale = a.YScale;

        newAx.Box      = a.Box;
        newAx.LineWidth = a.LineWidth;
        newAx.TickDir  = a.TickDir;
        newAx.Layer    = a.Layer;

        newAx.XDir = a.XDir;
        newAx.YDir = a.YDir;

        newAx.DataAspectRatio = a.DataAspectRatio;
        newAx.PlotBoxAspectRatio = a.PlotBoxAspectRatio;

        newAx.CLim = a.CLim;

        grid(newAx, a.XGrid);
        newAx.YGrid = a.YGrid;
        newAx.ZGrid = a.ZGrid;

        newAx.FontSize = a.FontSize;
        newAx.FontName = a.FontName;
        newAx.TickLabelInterpreter = a.TickLabelInterpreter;

    end

    % ---- copy colormap from source
    colormap(outFig, colormap(srcFig));

    % ---- panel letter
    annotation(outFig,'textbox', ...
        [panelPos(1)+0.01 panelPos(2)+panelPos(4)-0.04 0.03 0.03], ...
        'String',sprintf('(%c)',letters(k)), ...
        'LineStyle','none', ...
        'FontWeight','bold', ...
        'FontSize',14);

end

%% ================= PAPER SETTINGS =================
outFig.PaperUnits        = 'inches';
outFig.PaperSize         = [figW figH];
outFig.PaperPosition     = [0 0 figW figH];
outFig.PaperPositionMode = 'manual';

%% ================= SAVE =================
if strlength(string(outPdfPath)) > 0
    print(outFig, outPdfPath, '-dpdf', '-painters');
    fprintf('✔ Saved combined PDF: %s\n', outPdfPath);
end

end

%% ================= LOCAL HELPER =================
function tf = isColorbarAxes(a)
tf = false;
try
    if isprop(a,'Tag') && contains(string(a.Tag),'Colorbar','IgnoreCase',true)
        tf = true; return;
    end
    p = a.Position;
    if p(3) < 0.07 || p(4) < 0.07
        tf = true;
    end
catch
end
end
