function addTemperatureArrowPRL(ax, Tmin, Tmax)

if nargin < 1 || isempty(ax)
    ax = gca;
end
if nargin < 3
    error('Specify Tmin and Tmax');
end

fig = ancestor(ax,'figure');

% --- main axis position ---
pos = ax.Position;

% ===== PRL tuning =====
arrowHeight = 0.025;   % thinner strip
gap         = 0.02;    % tight spacing

% --- create gradient axis ---
axArrow = axes('Position', ...
    [pos(1), pos(2)-gap-arrowHeight, pos(3), arrowHeight]);

% --- copy colormap from main axis ---
cmap = colormap(ax);

n = size(cmap,1);
grad = linspace(1,n,1000);

imagesc(axArrow, grad);
colormap(axArrow, cmap);

set(axArrow,'YTick',[],'XTick',[]);
box(axArrow,'off');
xlim(axArrow,[1 1000]);
ylim(axArrow,[0.5 1.5]);

% --- arrow overlay ---
xStart = pos(1);
xEnd   = pos(1) + pos(3);
yArrow = pos(2) - gap - arrowHeight/2;

annotation(fig,'arrow', ...
    [xStart xEnd], ...
    [yArrow yArrow], ...
    'LineWidth',1);

% --- labels ---
fs = ax.FontSize;

text(axArrow,0,-0.9,sprintf('$%g\\,\\mathrm{K}$',Tmin), ...
    'Units','normalized', ...
    'HorizontalAlignment','left', ...
    'Interpreter','latex', ...
    'FontSize',fs);

text(axArrow,1,-0.9,sprintf('$%g\\,\\mathrm{K}$',Tmax), ...
    'Units','normalized', ...
    'HorizontalAlignment','right', ...
    'Interpreter','latex', ...
    'FontSize',fs);

text(axArrow,0.5,-1.8,'$\mathrm{Temperature\ (K)}$', ...
    'Units','normalized', ...
    'HorizontalAlignment','center', ...
    'Interpreter','latex', ...
    'FontSize',fs);

end
