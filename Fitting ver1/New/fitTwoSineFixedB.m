function [coeffsTable, fits, gofNums, hFig] = fitTwoSineFixedB(figHandle)
% Fit TWO-term sine WITH offset to all lines in an open figure,
% with b1 and 2*b1 fixed to correspond to 360° periodicity.
%
% Model:
%   y(x) = a1*sin((2*pi/360)*x + c1) + a2*sin((4*pi/360)*x + c2) + d1
%
% Creates:
%   (1) Multi-panel debug figure (raw, fits, 2b)
%   (2) Residual figure after removing 1st harmonic

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

% ---- Pick first axes with line objects ----
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

% ---- Legend / lines ----
lg = legend(ax);
if ~isempty(lg) && ~isempty(lg.String)
    namesAll      = string(lg.String(:));
    legendObjsRev = lg.PlotChildren(:);
    legendObjs    = legendObjsRev;
    isLine        = arrayfun(@(h) strcmpi(get(h,'Type'),'line'), legendObjs);
    lines         = legendObjs(isLine);
    names         = namesAll(isLine);
    names         = names(1:min(numel(names), numel(lines)));
else
    lines = findobj(ax,'Type','line','-depth',1);
    names = arrayfun(@(k) sprintf("Curve %d",k), 1:numel(lines), 'UniformOutput', false).';
end

n = numel(lines);
if n == 0
    error('No line plots found.');
end

xlab = ax.XLabel.String;
ylab = ax.YLabel.String;

% ======== fixed frequencies ========
b1_fixed = 2*pi/360;
b2_fixed = 2*b1_fixed;

ft = fittype('a1*sin(b1*x + c1) + a2*sin(b2*x + c2) + d1', ...
    'independent','x', ...
    'coefficients',{'a1','c1','a2','c2','d1'}, ...
    'problem',{'b1','b2'});

fits = cell(n,1);
SSE=nan(n,1); R2=nan(n,1); AdjR2=nan(n,1); RMSE=nan(n,1);
a1=nan(n,1); c1=nan(n,1); a2=nan(n,1); c2=nan(n,1); d1=nan(n,1);

xDataAll=cell(n,1); yDataAll=cell(n,1); yFitAll=cell(n,1); y2bAll=cell(n,1);
cmap = parula(n);

for k=1:n
    x = get(lines(k),'XData');
    y = get(lines(k),'YData');
    valid = isfinite(x) & isfinite(y);
    x = x(valid); y = y(valid);
    x = x(:); y = y(:);
    if numel(x) < 4, continue; end

    A = 0.5*(max(y)-min(y));
    D = mean(y);
    sp = [A, 0, A/3, 0, D]; % [a1,c1,a2,c2,d1]

    [f,g] = fit(x,y,ft,'StartPoint',sp,'problem',{b1_fixed,b2_fixed});

    fits{k}=f;
    a1(k)=f.a1; c1(k)=f.c1;
    a2(k)=f.a2; c2(k)=f.c2; d1(k)=f.d1;
    SSE(k)=g.sse; R2(k)=g.rsquare;
    if isfield(g,'adjrsquare'), AdjR2(k)=g.adjrsquare; end
    if isfield(g,'rmse'), RMSE(k)=g.rmse; end

    yfit = f.a1*sin(b1_fixed*x + f.c1) + f.a2*sin(b2_fixed*x + f.c2) + f.d1;
    y2b  = f.a2*sin(b2_fixed*x + f.c2);

    xDataAll{k}=x; yDataAll{k}=y; yFitAll{k}=yfit; y2bAll{k}=y2b;
end

% ======== reorder ascending by field value ========
fieldNums = nan(n,1);
for k = 1:n
    s = char(names(k));
    m = regexp(s,'([-+]?\d*\.?\d+)\[T\]','tokens','once');
    if ~isempty(m)
        fieldNums(k) = str2double(m{1});
    end
end
[~, orderAsc] = sort(fieldNums,'ascend','MissingPlacement','last');
names = names(orderAsc);
fits = fits(orderAsc);
a1=a1(orderAsc); c1=c1(orderAsc); a2=a2(orderAsc); c2=c2(orderAsc); d1=d1(orderAsc);
SSE=SSE(orderAsc); R2=R2(orderAsc); AdjR2=AdjR2(orderAsc); RMSE=RMSE(orderAsc);
xDataAll=xDataAll(orderAsc); yDataAll=yDataAll(orderAsc);
yFitAll=yFitAll(orderAsc); y2bAll=y2bAll(orderAsc);
cmap = parula(n); % keep consistent mapping




% ======== main debug figure ========
hFig = figure('Name','Folding 360°: Two-sine fits','NumberTitle','off', ...
              'Position',[100,100,1100,850]);  % ← בלי Color, רקע ברירת מחדל
set(hFig,'DefaultTextInterpreter','latex','DefaultLegendInterpreter','latex');

tlo = tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

% --- תווית ציר Y ב-LaTeX ---
yLabelLatex = '$\Delta\rho_{\perp}/\rho_{\parallel}\,[\%]$';

% --- עיצוב כללי ---
commonFontSize = 14;
lw = 2.5;
grayGrid = [0.7 0.7 0.7];
xTickVals = 0:45:360;   % טיקים כל 45°
xLimVals  = [0, 360];   % גבול מ-0 עד 360

% ---------- (1) Raw data ----------
ax1 = nexttile(tlo);
hold(ax1,'on');
for k=1:n
    hRaw(k) = plot(ax1, xDataAll{k}, yDataAll{k}, '-', ...
        'LineWidth', lw, 'Color', cmap(k,:), 'DisplayName', char(names(k)));
end
grid(ax1,'on');
ax1.GridColor = grayGrid; ax1.GridAlpha = 0.4;
ax1.FontSize = commonFontSize; ax1.LineWidth = 1; ax1.Box = 'on';
ax1.XTick = xTickVals; xlim(ax1,xLimVals);           % ✅ טיקים וגבול
xlabel(ax1, 'Angle °', 'FontSize', commonFontSize, 'Interpreter', 'none');
ylabel(ax1,yLabelLatex,'FontSize',commonFontSize,'Interpreter','latex');  % ✅ שם ציר Y
title(ax1,'Original Data','FontSize',commonFontSize+2,'FontWeight','bold');
legend(ax1, flip(hRaw), 'Location','bestoutside','FontSize',commonFontSize-2,'Box','off');

% ---------- (2) Total fits ----------
ax2 = nexttile(tlo);
hold(ax2,'on');
for k=1:n
    hFit(k) = plot(ax2, xDataAll{k}, yFitAll{k}, '-', ...
        'LineWidth', lw, 'Color', cmap(k,:), 'DisplayName', char(names(k)));
end
grid(ax2,'on');
ax2.GridColor = grayGrid; ax2.GridAlpha = 0.4;
ax2.FontSize = commonFontSize; ax2.LineWidth = 1; ax2.Box = 'on';
ax2.XTick = xTickVals; xlim(ax2,xLimVals);           % ✅ טיקים וגבול
xlabel(ax2, 'Angle °', 'FontSize', commonFontSize, 'Interpreter', 'none');
ylabel(ax2,yLabelLatex,'FontSize',commonFontSize,'Interpreter','latex');  % ✅ שם ציר Y
title(ax2,'$a_1\sin(b_1x+c_1)+a_2\sin(2b_1x+c_2)+d_1$', ...
      'FontSize',commonFontSize+2,'Interpreter','latex','FontWeight','bold');
legend(ax2, flip(hFit), 'Location','bestoutside','FontSize',commonFontSize-2,'Box','off');

% ---------- (3) Second harmonic ----------
ax3 = nexttile(tlo);
hold(ax3,'on');
for k=1:n
    h2b(k) = plot(ax3, xDataAll{k}, y2bAll{k}, '-', ...
        'LineWidth', lw, 'Color', cmap(k,:), 'DisplayName', char(names(k)));
end
grid(ax3,'on');
ax3.GridColor = grayGrid; ax3.GridAlpha = 0.4;
ax3.FontSize = commonFontSize; ax3.LineWidth = 1; ax3.Box = 'on';
ax3.XTick = xTickVals; xlim(ax3,xLimVals);           % ✅ טיקים וגבול
xlabel(ax3, 'Angle °', 'FontSize', commonFontSize, 'Interpreter', 'none');
ylabel(ax3,yLabelLatex,'FontSize',commonFontSize,'Interpreter','latex');  % ✅ שם ציר Y
title(ax3,'Second harmonic ($2b_1=4\pi/360$)', ...
      'Interpreter','latex','FontSize',commonFontSize+2,'FontWeight','bold');
legend(ax3, flip(h2b), 'Location','bestoutside','FontSize',commonFontSize-2,'Box','off');

linkaxes([ax1,ax2,ax3],'x');





% ======== output table ========
varNames = {'a1','c1','a2','c2','d1','SSE','R2','AdjR2','RMSE'};
coeffsTable = table(a1,c1,a2,c2,d1,SSE,R2,AdjR2,RMSE,'VariableNames',varNames);
coeffsTable.Properties.RowNames = cellstr(names);
gofNums = struct('SSE',SSE,'R2',R2,'AdjR2',AdjR2,'RMSE',RMSE);

% ======== extra figure: residual after removing 1st harmonic ========
hFigRes = figure('Name','Residual after removing 1st harmonic','NumberTitle','off', ...
    'Position',[100,100,1000,600]);
axRes = axes('Parent',hFigRes); hold(axRes,'on'); grid(axRes,'on');
axRes.FontSize = 18; axRes.XTick = 0:45:360;
xlabel(axRes, 'Angle °', 'FontSize', commonFontSize, 'Interpreter', 'none');
ylabel(axRes,[ylab ' residual'],'FontSize',18);
xlim(axRes,[0,360]);
title(axRes, sprintf('Residual after removing 1st harmonic  %s  at 4.00[K]', ylab), ...
    'FontSize',18,'Interpreter','tex');

for k=1:n
    y_res = yDataAll{k} - a1(k)*sin(b1_fixed*xDataAll{k} + c1(k)); % remove 1θ
    hRes(k) = plot(axRes, xDataAll{k}, y_res, '-', 'LineWidth', 3, ...
                   'Color', cmap(k,:), 'DisplayName', char(names(k)));
end
legend(axRes, flip(hRes), 'Location','bestoutside');  % גבוה למעלה
box(axRes, 'on');

axesList = [ax1, ax2, ax3];
for ax = axesList
    hx = xlabel(ax, 'Angle °', 'FontSize', commonFontSize);
    hx.HorizontalAlignment = 'right';
    hx.Position(1) = hx.Position(1) + 175;
end

end
