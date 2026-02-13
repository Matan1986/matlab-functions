function applyToSingleFigure(fig, cmapFull, spreadMode, ...
    fitColor, dataWidth, dataStyle, fitWidth, fitStyle, ...
    reverseOrder, reverseLegend, markerSize)

if nargin < 4
    fitColor = 'black';      % תמיכה בקריאות ישנות
end
% אם fitColor='' → לא לשנות
if nargin < 5, dataWidth = []; end
if nargin < 6, dataStyle = '';  end
if nargin < 7, fitWidth  = []; end
if nargin < 8, fitStyle  = ''; end
if nargin < 9, reverseOrder = 0; end
if nargin < 10, reverseLegend = 0; end
if nargin < 11, markerSize = []; end

axList = findall(fig,'Type','axes');
fitRGB = name2rgb(fitColor);

%% =========================
% 1) COLORING + COLORMAP
% =========================
if ~isempty(cmapFull)
    M = size(cmapFull,1);
end

for ax = axList'

    % ----- colormap -----
    if ~isempty(cmapFull)
        idx = getSliceIndices(M, spreadMode);
        cmapSlice = cmapFull(idx,:);
        colormap(ax, cmapSlice);
    end

    % ----- lines -----
    allLines = findall(ax,'Type','line');
    if isempty(allLines), continue; end

    names = get(allLines,'DisplayName');
    if ischar(names), names = {names}; end

    isData   = ~cellfun(@isempty,names);
    dataLines = allLines(isData);
    fitLines  = allLines(~isData);

    % DATA
    if ~isempty(cmapFull) && ~isempty(dataLines)
        nC = size(cmapSlice,1);
        idx = round(linspace(1,nC,numel(dataLines)));
        for k = 1:numel(dataLines)
            if ~isempty(markerSize), dataLines(k).MarkerSize = markerSize; end
            dataLines(k).Color = cmapSlice(idx(k),:);
            if ~isempty(dataWidth), dataLines(k).LineWidth = dataWidth; end
            if ~isempty(dataStyle), dataLines(k).LineStyle = dataStyle; end
        end
    else
        % change width/style only
        for k = 1:numel(dataLines)
            if ~isempty(dataWidth), dataLines(k).LineWidth = dataWidth; end
            if ~isempty(dataStyle), dataLines(k).LineStyle = dataStyle; end
        end
    end

    % FIT
    for k = 1:numel(fitLines)
        % צבע פיט — רק אם המשתמש ביקש לשנות
        if ~isempty(markerSize), fitLines(k).MarkerSize = markerSize; end
        if ~isempty(fitColor)
            fitLines(k).Color = fitRGB;
        end

        if ~isempty(fitWidth), fitLines(k).LineWidth = fitWidth; end
        if ~isempty(fitStyle), fitLines(k).LineStyle = fitStyle; end
    end

    % COLORBARS
    cbList = findall(fig,'Type','colorbar','Axes',ax);
    for cb = cbList'
        if ~isempty(cmapFull)
            colormap(cb, flipud(cmapSlice));
        end
        set(cb,'Direction','normal');
    end
end

%% =========================
% 2) Reverse PLOT order (lines only)
% =========================
if reverseOrder
    for ax = axList'
        ch = ax.Children;
        isLine = strcmp(get(ch,'Type'),'line');

        lineChildren  = ch(isLine);
        otherChildren = ch(~isLine);

        if numel(lineChildren)>1
            lineChildren = flipud(lineChildren);
        end

        ax.Children = [lineChildren; otherChildren];
    end
end

%% =========================
% 3) Reverse LEGEND order  — ONLY on DATA LINES
% =========================
if reverseLegend

    for ax = axList'

        % get existing legend (if none → skip)
        hLeg = findobj(ax.Parent,'Type','legend','-and','Parent',ax.Parent);
        if isempty(hLeg), continue; end
        oldPos = hLeg.Position;

        % all line handles
        allLines = findall(ax,'Type','line');
        if isempty(allLines), continue; end

        % extract DisplayNames
        names = get(allLines,'DisplayName');
        if ischar(names), names = {names}; end

        % identify REAL data lines (= have DisplayName)
        isData = ~cellfun(@isempty,names);
        dataLines = allLines(isData);
        dataNames = names(isData);

        % reverse ONLY the data lines in legend
        dataLines = flipud(dataLines);
        dataNames = flipud(dataNames);

        % rebuild legend using ONLY data lines
        delete(hLeg);
        newLeg = legend(ax, dataLines, dataNames);
        newLeg.AutoUpdate = 'off';
        newLeg.Position   = oldPos;

    end
end


end
