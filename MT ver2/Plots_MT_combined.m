function legendData = Plots_MT_combined( ...
    Temp_table, VSM_table, sortedFields, colors, unitsRatio, ...
    increasing_temp_cell_array, decreasing_temp_cell_array, ...
    growth_num, fontsize, figureMode, plotQuantity, unitsMode, ...
    useAutoYScale, legendMode)

if nargin < 14 || isempty(legendMode)
    legendMode = 'internal';
end
% ==============================================================
% Plots_MT_combined  — SAFE, PHYSICALLY CONSISTENT VERSION
%
% • Scales DATA (not ticks) when using 10^n presentation
% • NEVER touches YTick / YTickLabel
% • Locks only XLim / YLim
% • Compatible with old MATLAB + NumericRuler (MPMS)
% ==============================================================

if nargin < 13 || isempty(useAutoYScale)
    useAutoYScale = false;
end

%% ==============================================================
%% FIGURE MODE
%% ==============================================================

switch lower(figureMode)
    case 'small'
        lw = 2;
        fs = fontsize;
    otherwise   % 'paper'
        lw = 2.5;
        fs = fontsize;
end

yMarginFrac = 0.10;
xMarginFrac = 0.02;
xGlobalMin  = 0;
xGlobalMax  = 300;

%% ==============================================================
%% SAFE DATA SCALING (PHYSICAL)
scaleFactor = 1;
scalePower  = 0;

if useAutoYScale
    yProbe = [];

    for i = 1:numel(sortedFields)
        M = VSM_table{i};
        if isempty(M), continue; end

        switch plotQuantity
            case 'M'
                ytmp = M * unitsRatio;
            case 'M_over_H'
                if sortedFields(i) == 0, continue; end
                ytmp = M * unitsRatio / sortedFields(i);
        end

        yProbe = [yProbe; ytmp(:)]; %#ok<AGROW>
    end

    scalePower  = chooseAutoScalePower(yProbe);
    scaleFactor = 10^scalePower;
end


%% ==============================================================
%% PASS 1 — determine global Y limits (ON SCALED DATA)
%% ==============================================================

globalY = [];

for i = 1:numel(sortedFields)

    M    = VSM_table{i};
    Temp = Temp_table{i};
    if isempty(M) || isempty(Temp)
        continue;
    end

    incRaw = increasing_temp_cell_array{i};
    if isempty(incRaw)
        continue;
    end

    if iscell(incRaw)
        segRanges = incRaw;
    elseif isnumeric(incRaw) && size(incRaw,2) == 2
        segRanges = mat2cell(incRaw, ones(size(incRaw,1),1), 2);
    else
        error('Unsupported incRanges format at index %d', i);
    end

    for j = 1:numel(segRanges)
        r = segRanges{j};
        segM = M(r(1):r(2));

        switch plotQuantity
            case 'M'
                ydata = segM * unitsRatio * scaleFactor;
            case 'M_over_H'
                if sortedFields(i) == 0, continue; end
                ydata = segM * unitsRatio / sortedFields(i) * scaleFactor;
        end

        globalY = [globalY; ydata(:)]; %#ok<AGROW>
    end
end

globalY = globalY(isfinite(globalY));
if isempty(globalY)
    globalYLim = [0 1];
else
    yMin   = min(globalY);
    yMax   = max(globalY);
    yRange = yMax - yMin;
    if yRange == 0
        yRange = max(abs(yMin),1);
    end
    globalYLim = [ ...
        yMin - yRange*yMarginFrac, ...
        yMax + yRange*yMarginFrac ];
end

%% ==============================================================
%% FIELD ORDER & COLOR MAPS
%% ==============================================================

fields_T = sortedFields(:).' / 1e4;   % Tesla
nF = numel(fields_T);

[~, order] = sort(fields_T);
fieldRank = zeros(size(order));
fieldRank(order) = 1:nF;

baseZ = [
    0.05 0.25 0.55
    0.07 0.32 0.65
    0.10 0.40 0.75
    0.12 0.48 0.85
    0.15 0.55 0.95
    0.18 0.62 1.00
    0.22 0.70 1.00 ];

baseF = [
    0.50 0.10 0.10
    0.60 0.15 0.15
    0.70 0.20 0.20
    0.78 0.28 0.28
    0.85 0.36 0.36
    0.90 0.45 0.45
    0.95 0.55 0.55 ];

idxBase = round(linspace(size(baseZ,1),1,nF));
idxBase = max(1,min(idxBase,size(baseZ,1)));

colorsZFC = zeros(nF,3);
colorsFCW = zeros(nF,3);

for k = 1:nF
    r = fieldRank(k);
    colorsZFC(r,:) = baseZ(idxBase(r),:);
    colorsFCW(r,:) = baseF(idxBase(r),:);
end

greyColor = 0.4*[1 1 1];

%% ==============================================================
%% FIGURE
%% ==============================================================

switch plotQuantity
    case 'M'
        figName = sprintf('MG%d — Combined M(T)', growth_num);
    case 'M_over_H'
        figName = sprintf('MG%d — Combined M/H(T)', growth_num);
end

fig = figure('Name',figName,'NumberTitle','off','Color','w');
ax  = axes('Parent',fig);
hold(ax,'on');
grid(ax,'on'); box(ax,'on');

allT = [];
zfcHandles = gobjects(nF,1);
fcwHandles = gobjects(nF,1);
zfcLabels = strings(nF,1);
fcwLabels = strings(nF,1);

%% ==============================================================
%% PASS 2 — plotting (ON SCALED DATA)
%% ==============================================================

for i = numel(sortedFields):-1:1

    Temp = Temp_table{i};
    M    = VSM_table{i};
    if isempty(Temp) || isempty(M)
        continue;
    end

    incRaw = increasing_temp_cell_array{i};
    if isempty(incRaw)
        continue;
    end

    if iscell(incRaw)
        segRanges = incRaw;
    elseif isnumeric(incRaw) && size(incRaw,2) == 2
        segRanges = mat2cell(incRaw, ones(size(incRaw,1),1), 2);
    else
        error('Unsupported incRanges format at index %d', i);
    end

    thisRank = fieldRank(i);

    for j = 1:numel(segRanges)
        r = segRanges{j};

        segT = Temp(r(1):r(2));
        segM = M(r(1):r(2));

        switch plotQuantity
            case 'M'
                ydata = segM * unitsRatio * scaleFactor;
            case 'M_over_H'
                if sortedFields(i) == 0, continue; end
                ydata = segM * unitsRatio / sortedFields(i) * scaleFactor;
        end

        if j == 1
            c = colorsZFC(thisRank,:);
        elseif j == 2
            c = colorsFCW(thisRank,:);
        else
            c = greyColor;
        end

        h = plot(ax, segT, ydata, ...
            'LineWidth', lw, ...
            'Color', c, ...
            'HandleVisibility','off');

        if j == 1
            h.DisplayName = sprintf('%.1f T', sortedFields(i)/1e4);
            h.HandleVisibility = 'on';
            zfcHandles(i) = h;
            zfcLabels(i) = string(h.DisplayName);
        elseif j == 2
            h.DisplayName = sprintf('%.1f T', sortedFields(i)/1e4);
            h.HandleVisibility = 'on';
            fcwHandles(i) = h;
            fcwLabels(i) = string(h.DisplayName);
        end

        allT = [allT; segT(:)]; %#ok<AGROW>
    end
end

%% ==============================================================
%% AXES (SAFE)
%% ==============================================================

set(ax,'FontSize',fs);
xlabel(ax,'Temperature (K)','Interpreter','latex');

switch plotQuantity
    case 'M'
        baseLabel = 'M';
    case 'M_over_H'
        baseLabel = 'M/H';
end

switch unitsMode
    case 'raw'
        unitStrDisp = 'emu';
    case 'per_mass'
        unitStrDisp = 'emu\,g^{-1}\,Oe^{-1}';
    case 'per_Co'
        unitStrDisp = '\mu_B\,Co^{-1}\,Oe^{-1}';
end

if useAutoYScale && scalePower ~= 0
    ylab = sprintf('$%s\\ (10^{-%d}\\,\\mathrm{%s})$', ...
        baseLabel, scalePower, unitStrDisp);
else
    ylab = sprintf('$%s\\ (\\mathrm{%s})$', ...
        baseLabel, unitStrDisp);
end

ylabel(ax, ylab, 'Interpreter','latex');

% ---- limits only (no ticks) ----
if ~isempty(allT)
    xMin = min(allT); xMax = max(allT);
    xRange = max(xMax-xMin,1);
    ax.XLim = [ ...
        max(xMin-xRange*xMarginFrac,xGlobalMin), ...
        min(xMax+xRange*xMarginFrac,xGlobalMax)];
else
    ax.XLim = [xGlobalMin xGlobalMax];
end
ax.XLimMode = 'manual';

ax.YLim = globalYLim;
ax.YLimMode = 'manual';
ax.TickLabelInterpreter = 'tex';
ax.TickDir = 'in';
ax.Box = 'on';
ax.XAxisLocation = 'bottom';
ax.YAxisLocation = 'left';
ax.TickDirMode = 'manual';
ax.TickLength = [0.02 0.02];
ax.Layer   = 'top';

%% ==============================================================
%% CUSTOM LEGEND AXES — ZFC | FCW | FIELD
%% ==============================================================
[fieldsSorted, order] = sort(fields_T,'descend');
nLegend = numel(fieldsSorted);

oldLegendAx = [];
oldLegendAx = findall(fig, 'Type', 'axes', 'Tag', 'PlotsMTCombinedManualLegendAxes');
if ~isempty(oldLegendAx)
    delete(oldLegendAx);
end
if isappdata(fig, 'PlotsMTCombinedLegendAxesHandle')
    rmappdata(fig, 'PlotsMTCombinedLegendAxesHandle');
end

axLeg = axes('Parent',fig, ...
    'Units','normalized', ...
    'Position',[0.60 0.30 0.30 0.55], ...
    'Visible','on', ...
    'HitTest','on', ...
    'PickableParts','all', ...
    'HandleVisibility','on', ...
    'Color','none', ...
    'XColor','none', ...
    'YColor','none', ...
    'XLim',[0 1], ...
    'YLim',[0 nLegend+1], ...
    'YDir','reverse');
axLeg.Tag = 'PlotsMTCombinedManualLegendAxes';
axLeg.UserData = [];

uistack(axLeg,'top');
axLeg.Clipping = 'off';

% ---- headers (only once) ----
text(axLeg,0.15,0.5,'ZFC', ...
    'FontWeight','normal', ...
    'Interpreter','latex', ...
    'FontSize', fs-2, ...
    'HitTest','on', ...
    'PickableParts','all');

text(axLeg,0.45,0.5,'FCW', ...
    'FontWeight','normal', ...
    'Interpreter','latex', ...
    'FontSize', fs-2, ...
    'HitTest','on', ...
    'PickableParts','all');

for k = 1:nLegend
    idx = order(k);
    y = k + 0.5;

    zfcColor = colorsZFC(fieldRank(idx),:);
    fcwColor = colorsFCW(fieldRank(idx),:);

    line(axLeg,[0.05 0.20],[y y], ...
        'Color',zfcColor, ...
        'LineWidth',lw, ...
        'HitTest','on', ...
        'PickableParts','all', ...
        'UserData',[]);

    line(axLeg,[0.30 0.45],[y y], ...
        'Color',fcwColor, ...
        'LineWidth',lw, ...
        'HitTest','on', ...
        'PickableParts','all', ...
        'UserData',[]);

    text(axLeg,0.70,y, sprintf('%.1f T',fieldsSorted(k)), ...
        'HorizontalAlignment','left', ...
        'Interpreter','latex', ...
        'FontSize', fs-4, ...
        'HitTest','on', ...
        'PickableParts','all', ...
        'UserData',[]);
end

%% ==============================================================
%% OUTPUT
%% ==============================================================

legendData.sortedFields = sortedFields;
legendData.fieldRank    = fieldRank;
legendData.colorsZFC    = colorsZFC;
legendData.colorsFCW    = colorsFCW;
legendData.fontsize     = fs;
legendData.lw           = lw;
legendData.dy           = [];

if ~strcmpi(string(legendMode), "none")
    setappdata(fig, 'ComposeLegendData', legendData);
end

end
