function fig = applySmartLayout_v2(nx, ny, journal, columnMode)
% SMART LAYOUT v2 — ARTICLE ORCHESTRATOR
% nx, ny      : number of MATLAB FIGURES to combine across/down
% journal     : "PRL" | "Nature"
% columnMode  : "single" | "double"

%% -------- journal presets (LAW = WIDTH) --------
switch string(journal)
    case "PRL"
        singleColWidth  = 3.375;
        doubleColWidth  = 7.0;
        singleColHeight = 5.0;
        doubleColHeight = 6.0;
    case "Nature"
        singleColWidth  = 3.5;
        doubleColWidth  = 7.2;
        singleColHeight = 5.5;
        doubleColHeight = 7.5;
    otherwise
        error('Unknown journal');
end

if columnMode == "double"
    figW = doubleColWidth;
    figH = doubleColHeight;
else
    figW = singleColWidth;
    figH = singleColHeight;
end

%% -------- collect real figures --------
skipNames = ["CtrlGUI","Final Figure Formatter","FigureTools","refLineGUI", ...
             "Appearance / Colormap Control"];
allF = findall(0,'Type','figure');
figs = [];
for i = 1:numel(allF)
    nm = string(get(allF(i),'Name'));
    if any(nm == skipNames), continue; end
    figs(end+1) = allF(i); %#ok<AGROW>
end

if isempty(figs)
    error('SMART Layout: no data figures open.');
end

%% -------- COMBINE if needed --------
if numel(figs) > 1
    fig = combineOpenFiguresToPanels_v2(nx, ny, figW, figH);
else
    fig = figs(1);
end

%% -------- LOCK PAPER GEOMETRY (ONCE) --------
fig.PaperUnits        = 'inches';
fig.PaperSize         = [figW figH];
fig.PaperPosition     = [0 0 figW figH];
fig.PaperPositionMode = 'manual';

%% -------- FONT SCALING BY REAL PANEL WIDTH --------
panelW = figW / nx;

if panelW < 2.2
    fs = 12;
elseif panelW < 2.8
    fs = 14;
elseif panelW < 3.5
    fs = 16;
else
    fs = 18;
end

applyFontSizeByRole_v2(fig, fs);

drawnow;

fprintf('✔ SMART v2: %dx%d panels, %.2f×%.2f in, panelW=%.2f → fs=%d\n', ...
        nx, ny, figW, figH, panelW, fs);
end
