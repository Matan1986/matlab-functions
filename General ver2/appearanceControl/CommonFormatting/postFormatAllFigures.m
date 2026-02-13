function postFormatAllFigures(newSize, fontName, fontSize, skipName, bgMode, clearTitles)
% POSTFORMATALLFIGURES
% Resize all figures, optionally set fonts/background, and optionally clear titles.
% postFormatAllFigures([1000 600], [], 12, 'CtrlGUI', 'white', true)
% Now includes FULL FONT CONTROL:
%   ✔ axes (cartesian + polar)
%   ✔ XLabel, YLabel, Title
%   ✔ legends
%   ✔ text objects
%   ✔ colorbars
%   ✔ polar axes tick labels

if nargin < 6, clearTitles = false; end
if nargin < 5, bgMode = ''; end
if nargin < 4 || isempty(skipName), skipName = 'CtrlGUI'; end
if nargin < 3, fontSize = []; end
if nargin < 2, fontName = []; end

figs = findall(groot, 'Type', 'figure');

for i = 1:numel(figs)

    fig = figs(i);
    % === Skip ALL GUI windows ===
    skipList = ["CtrlGUI","Final Figure Formatter","FigureTools","refLineGUI"];

    figName = string(get(fig,'Name'));

    if any(figName == skipList)
        fprintf("Skipping GUI figure: %s\n", figName);
        continue;
    end

    % Skip specific figure by name
    figName = get(fig, 'Name');
    if ischar(figName) && strcmp(figName, skipName)
        fprintf("Skipping figure: %s\n", figName);
        continue;
    end

    %% === RESIZE ===
    oldUnits = fig.Units;
    fig.Units = 'pixels';
    pos = fig.Position;
    fig.Position = [pos(1) pos(2) newSize(1) newSize(2)];
    fig.Units = oldUnits;

    %% === BACKGROUND ===
    switch lower(bgMode)
        case 'white'
            fig.Color = 'w';
        case 'transparent'
            fig.Color = 'none';
    end

    %% ======================================
    %        APPLY TO ALL AXES TYPES
    %% ======================================
    axList = findall(fig, 'Type', 'axes');
    paxList = findall(fig, 'Type', 'polaraxes');
    cbList = findall(fig, 'Type', 'colorbar');

    %% === REGULAR AXES ===
    for ax = axList'
        if clearTitles
            title(ax, '');
        end

        if ~isempty(fontSize)
            if ~isempty(fontName), ax.FontName = fontName; end
            ax.FontSize = fontSize;

            % X/Y labels
            if ~isempty(fontName), ax.XLabel.FontName = fontName; end
            ax.XLabel.FontSize = fontSize;

            if ~isempty(fontName), ax.YLabel.FontName = fontName; end
            ax.YLabel.FontSize = fontSize;

            % Title
            if ~isempty(fontName), ax.Title.FontName = fontName; end
            ax.Title.FontSize = fontSize;
        end
    end

    %% === POLAR AXES (טיפול מיוחד!) ===
    for pax = paxList'
        if clearTitles
            pax.Title.String = '';
        end

        if ~isempty(fontSize)
            if ~isempty(fontName), pax.FontName = fontName; end
            pax.FontSize = fontSize;

            % Tick labels
            pax.ThetaAxis.Label.FontSize = fontSize;
            pax.RAxis.Label.FontSize     = fontSize;

            if ~isempty(fontName)
                pax.ThetaAxis.Label.FontName = fontName;
                pax.RAxis.Label.FontName     = fontName;
            end

            pax.ThetaAxis.TickLabelInterpreter = 'none';
            pax.RAxis.TickLabelInterpreter     = 'none';
        end
    end

    %% === COLORBARS ===
    for cb = cbList'
        if ~isempty(fontSize)
            cb.FontSize = fontSize;
            if ~isempty(fontName), cb.FontName = fontName; end
        end
    end

    %% === LEGENDS ===
    lgList = findall(fig, 'Type', 'legend');
    for L = lgList'
        if ~isempty(fontSize), L.FontSize = fontSize; end
        if ~isempty(fontName), L.FontName = fontName; end
    end
    %% === LEGEND BACKGROUND: DEFAULT TRANSPARENT ===
    for L = lgList'
        L.Color = 'none';   % רקע שקוף
        L.Box   = 'off';    % בלי מסגרת
    end

    %% === TEXT OBJECTS ===
    txtList = findall(fig, 'Type', 'text');
    for t = txtList'
        if ~isempty(fontSize), t.FontSize = fontSize; end
        if ~isempty(fontName), t.FontName = fontName; end
    end

end

fprintf("Finished formatting all figures.\n");

end
