function [coeffsTable, fits, gofNums, hFig] = fitSineAllCurvesFromOpenFigure(figHandle)
% Fit TWO-term sine WITH offset to all lines in an open figure

if nargin < 1 || isempty(figHandle)
    figHandle = gcf;
end
if ~ishandle(figHandle) || ~strcmp(get(figHandle,'Type'),'figure')
    error('Input must be a valid figure handle.');
end

axAll = findobj(figHandle,'Type','axes');
if isempty(axAll)
    error('No axes found in the figure.');
end

% pick first axes with line objects
ax = [];
for kk = 1:numel(axAll)
    L = findobj(axAll(kk),'Type','line');
    if ~isempty(L)
        ax = axAll(kk);
        break;
    end
end
if isempty(ax)
    error('No line plots found in the figure.');
end

% legend order
lg = legend(ax);
if ~isempty(lg) && ~isempty(lg.String)
    namesAll      = string(lg.String(:));
    legendObjsRev = lg.PlotChildren(:);
    legendObjs    = flip(legendObjsRev);
    isLine        = arrayfun(@(h) strcmpi(get(h,'Type'),'line'), legendObjs);
    lines = findobj(ax,'Type','line');
    lines = flipud(lines);
    names = flip(namesAll(isLine));
    names = names(1:min(numel(names), numel(lines)));
else
    lines = flip(findobj(ax,'Type','line'));
    names = arrayfun(@(k) sprintf("Curve %d",k), 1:numel(lines), 'UniformOutput', false).';
end

n = numel(lines);
if n == 0, error('No lines found.'); end

xlab = ax.XLabel.String;
ylab = ax.YLabel.String;

% Fit model
ft = fittype('a1*sin(b1*x + c1) + a2*sin(2*b1*x + c2) + d1', ...
    'independent','x', ...
    'coefficients',{'a1','b1','c1','a2','c2','d1'});

fits  = cell(n,1);
SSE   = nan(n,1); R2 = nan(n,1); AdjR2 = nan(n,1); RMSE = nan(n,1);
a1 = nan(n,1); b1 = nan(n,1); c1 = nan(n,1);
a2 = nan(n,1); c2 = nan(n,1); d1 = nan(n,1);

xDataAll = cell(n,1); 
yDataAll = cell(n,1);
yFitAll  = cell(n,1); 
y2bAll   = cell(n,1);

cmap = parula(n);

for k = 1:n
    x = get(lines(k),'XData');
    y = get(lines(k),'YData');
    valid = isfinite(x) & isfinite(y);
    x = x(valid); y = y(valid);
    x = x(:); y = y(:);

    if numel(x) < 4, continue; end

    % initial guess (FFT)
    A  = 0.5*(max(y)-min(y));
    D  = mean(y);
    xr = max(x)-min(x);
    if xr <= 0, xr = 1; end
    Yfft = abs(fft(y-D));
    [~,idxMax] = max(Yfft(2:floor(end/2)));
    freqGuess  = (idxMax-1)/xr;
    b0 = 2*pi*freqGuess;
    if ~isfinite(b0) || b0 == 0
        b0 = 2*pi/xr;
    end
    c0 = 0;

    sp = [A, b0, c0, A/3, c0, D];

    try
        [f,g] = fit(x,y,ft,'StartPoint',sp);
    catch
        [f,g] = fit(x,y,ft);
    end

    fits{k} = f;
    a1(k)   = f.a1; 
    b1(k)   = f.b1; 
    c1(k)   = f.c1;
    a2(k)   = f.a2; 
    c2(k)   = f.c2; 
    d1(k)   = f.d1;
    SSE(k)  = g.sse; 
    R2(k)   = g.rsquare;
    if isfield(g,'adjrsquare'), AdjR2(k) = g.adjrsquare; end
    if isfield(g,'rmse'),       RMSE(k)  = g.rmse;       end

    yfit = feval(f,x);
    y2b  = f.a2 * sin(2*f.b1*x + f.c2);

    xDataAll{k} = x;
    yDataAll{k} = y;
    yFitAll{k}  = yfit;
    y2bAll{k}   = y2b;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   NEW FIGURE *BEFORE* FORMAT — residuals (original - first harmonic)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hFig2 = figure('Name','Residual: data minus first harmonic','NumberTitle','off');
axR   = axes(hFig2);
hold(axR,'on'); grid(axR,'on'); box(axR,'on');

cmapR = cmap;

for k = 1:n
    f = fits{k};
    x = xDataAll{k};

    y1h  = f.a1*sin(f.b1*x + f.c1) + f.d1;
    yRes = yDataAll{k} - y1h;

    plot(axR,x,yRes,'-','Color',cmapR(k,:), ...
        'LineWidth',1.2,'DisplayName',char(names(k)));
end

xlabel(axR, xlab, 'Interpreter','none');
ylabel(axR, ylab, 'Interpreter','none');
title(axR,'Residuals: data - first harmonic');
set(axR,'XLim',[0 360],'XTick',0:45:360);
legend(axR,'Location','bestoutside');
set(axR,'FontSize',16);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   MAIN MULTI-PANEL FIGURE (goes AFTER the residual figure)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hFig = figure('Name','Two-sine fits and 2b components','NumberTitle','off');
set(hFig,'DefaultTextInterpreter','latex', ...
         'DefaultAxesTickLabelInterpreter','latex', ...
         'DefaultLegendInterpreter','latex');

tlo = tiledlayout(3,1,'TileSpacing','loose','Padding','compact');

% 1) raw data  (*** קווים בלבד ***)
ax1 = nexttile(tlo); 
hold(ax1,'on'); grid(ax1,'on');
for k = 1:n
    plot(ax1,xDataAll{k},yDataAll{k},'-', ...   % <--- פה שינינו מ '.' ל '-'
         'Color',cmap(k,:), ...
         'LineWidth',1.2, ...
         'DisplayName',char(names(k)));
end
title(ax1,'Original Data');
xlabel(ax1,xlab); 
ylabel(ax1,ylab);

legendHandles = gobjects(n,1);
for k = 1:n
    legendHandles(k) = plot(ax1,NaN,NaN,'-', ...
        'Color',cmap(k,:), ...
        'LineWidth',1.5, ...
        'DisplayName',char(names(k)));
end
legend(ax1,legendHandles,'Location','bestoutside');

% 2) fits
ax2 = nexttile(tlo); 
hold(ax2,'on'); grid(ax2,'on');
for k = 1:n
    plot(ax2,xDataAll{k},yFitAll{k},'-','LineWidth',1.5, ...
        'Color',cmap(k,:), ...
        'DisplayName',char(names(k)));
end
title(ax2,'Two-term Sine Fits: $a_1\sin(b_1x+c_1)+a_2\sin(2b_1x+c_2)+d_1$');
xlabel(ax2,xlab); 
ylabel(ax2,ylab);

% 3) second harmonic
ax3 = nexttile(tlo); 
hold(ax3,'on'); grid(ax3,'on');
for k = 1:n
    plot(ax3,xDataAll{k},y2bAll{k},'-','LineWidth',1.2, ...
        'Color',cmap(k,:), ...
        'DisplayName',char(names(k)));
end
title(ax3,'Second harmonic components ($2b_1$)');
xlabel(ax3,xlab); 
ylabel(ax3,ylab);

set([ax1 ax2 ax3],'TickLabelInterpreter','none');
xlabel(ax1,xlab,'Interpreter','none');
xlabel(ax2,xlab,'Interpreter','none');
xlabel(ax3,xlab,'Interpreter','none');
ylabel(ax1,ylab,'Interpreter','none');
ylabel(ax2,ylab,'Interpreter','none');
ylabel(ax3,ylab,'Interpreter','none');

set([ax1 ax2 ax3],'XLim',[0 360],'XTick',0:45:360);
linkaxes([ax1 ax2 ax3],'x');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

varNames = {'a1','b1','c1','a2','c2','d1','SSE','R2','AdjR2','RMSE'};
coeffsTable = table(a1,b1,c1,a2,c2,d1,SSE,R2,AdjR2,RMSE, ...
    'VariableNames',varNames);
coeffsTable.Properties.RowNames = cellstr(names);
gofNums = struct('SSE',SSE,'R2',R2,'AdjR2',AdjR2,'RMSE',RMSE);

%% ============================
%  UI TABLE – במקום Command Window
%% ============================

hTableFig = figure('Name','Fit Coefficients Table', ...
                   'NumberTitle','off', ...
                   'Color','w', ...
                   'Units','normalized', ...
                   'Position',[0.25 0.25 0.45 0.55]);

fmt = @(x) arrayfun(@(v) sprintf('%.4f', v), x, 'UniformOutput', false);
dataFormatted = fmt(coeffsTable{:,:});
rowNames = coeffsTable.Properties.RowNames;

uit = uitable(hTableFig, ...
    'Data', dataFormatted, ...
    'ColumnName', coeffsTable.Properties.VariableNames, ...
    'RowName', rowNames, ...
    'FontSize', 12, ...
    'BackgroundColor', [1 1 1], ...
    'Units','normalized', ...
    'Position',[0.02 0.02 0.96 0.96]);

% הרחבת עמודות
numCols = width(coeffsTable);
uit.ColumnWidth = repmat({90}, 1, numCols);   % ← רוחב גדול!


formatAllFigures( ...
    'pos',[0.1 0.1 0.7 0.6], ...
    'fontSize',12, ...
    'legendFS',12, ...
    'lineW',1.5, ...
    'clearTitles',false, ...
    'showLegend',true, ...
    'showGrid',true, ...
     'showLegend',false, ...  
    'fig', hFig, ...
    'callerName',"fitSine_subplots" );
formatAllFigures( ...
    'pos',[0.1 0.1 0.7 0.6], ...
    'fontSize',20, ...
    'legendFS',20, ...
    'lineW',2, ...
    'clearTitles',false, ...
    'showLegend',true, ...
    'showGrid',true, ...
    'fig', hFig2, ...
    'callerName',"fitSine_residual" );


end
