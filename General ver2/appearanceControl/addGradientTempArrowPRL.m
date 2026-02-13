function addGradientTempArrowPRL(ax, Tmin, Tmax)

if nargin < 1 || isempty(ax) || ~isvalid(ax)
    ax = gca;
end

fig = ancestor(ax,'figure');

% ===== Delete existing colorbars =====
delete(findall(fig,'Type','ColorBar'));

% ===== Delete previous arrow axis =====
delete(findall(fig,'Type','axes','Tag','TempGradientArrow'));

% ===== Find TOPMOST regular axis =====
allAxes = findall(fig,'Type','axes');

% remove arrow axes if somehow present
allAxes(strcmp(get(allAxes,'Tag'),'TempGradientArrow')) = [];

% keep only visible data axes
allAxes = allAxes(arrayfun(@(a) isempty(get(a,'Tag')), allAxes));

topY = -inf;
topAx = ax;

for k = 1:length(allAxes)
    p = allAxes(k).Position;
    currentTop = p(2) + p(4);
    if currentTop > topY
        topY = currentTop;
        topAx = allAxes(k);
    end
end

pos = topAx.Position;

% ===== Geometry =====
arrowHeight = 0.04;
gap         = 0.01;
bodyEnd     = 0.84;
headOver    = 0.55;
headTip     = 1.02;

% ===== Create arrow ABOVE top subplot =====
axArrow = axes('Parent',fig,...
    'Position',[pos(1), pos(2)+pos(4)+gap, pos(3), arrowHeight], ...
    'Tag','TempGradientArrow');

axArrow.FontSize = topAx.FontSize * 0.95;
axArrow.FontName = topAx.FontName;

axis(axArrow,[0 1.05 -headOver 1+headOver]);
axis(axArrow,'off');
hold(axArrow,'on');

% ===== Gradient body =====
n = 800;
x = linspace(0,bodyEnd,n);
[X,Y] = meshgrid(x,[0 1]);
C = repmat(linspace(0,1,n),2,1);

surf(axArrow,X,Y,zeros(size(X)),C,'EdgeColor','none');
view(axArrow,2);
colormap(axArrow,colormap(topAx));

% stroke body
patch(axArrow,...
    [0 bodyEnd bodyEnd 0],...
    [0 0 1 1],...
    'k',...
    'FaceColor','none',...
    'LineWidth',0.35);

% arrow head
cmap = colormap(topAx);
colorHead = cmap(end,:);

patch(axArrow,...
    [bodyEnd headTip bodyEnd], ...
    [-headOver 0.5 1+headOver], ...
    colorHead,...
    'EdgeColor','k',...
    'LineWidth',0.35);

% ===== Labels =====
fs = axArrow.FontSize;

text(axArrow,0,-0.35,...
    sprintf('$%g\\,\\mathrm{K}$',Tmin),...
    'Units','normalized',...
    'Interpreter','latex',...
    'HorizontalAlignment','left',...
    'FontSize',fs);

text(axArrow,bodyEnd,-0.35,...
    sprintf('$%g\\,\\mathrm{K}$',Tmax),...
    'Units','normalized',...
    'Interpreter','latex',...
    'HorizontalAlignment','right',...
    'FontSize',fs);

text(axArrow,0.5,-0.9,...
    '$\mathrm{Temperature\ (K)}$',...
    'Units','normalized',...
    'Interpreter','latex',...
    'HorizontalAlignment','center',...
    'FontSize',fs);

end
