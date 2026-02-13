% --- 1. Get handles to your open figure, its axes, lines, and legend ---
fig = gcf;                              % current figure
ax  = findobj(fig, 'Type', 'axes');     % might be an array if subplots
ax  = ax(1);                            % pick the first axes (adjust if needed)
lines = findobj(ax, 'Type', 'line');    % all curves

% Try to get the figure's Name; if empty, use its number
origFigName = fig.Name;
if isempty(origFigName)
    origFigName = ['Figure ' num2str(fig.Number)];
end

% Try to get the axes title; if empty, use the figure name
origAxesTitle = ax.Title.String;
if isempty(origAxesTitle)
    origAxesTitle = origFigName;
end

% Get the legend strings (in plot order)
lg = legend(ax);
if ~isempty(lg) && iscell(lg.String)
    legendTexts = lg.String;
else
    legendTexts = arrayfun(@(k) ['Curve ' num2str(k)], 1:length(lines), 'UniformOutput', false);
end

% --- 2. Loop through each line, open a new figure, name & title it ---
for k = 1:length(lines)
    % Build the combined title/name
    thisLegend = legendTexts{min(k, numel(legendTexts))};
    fullName   = [origFigName  ' – '  thisLegend];
    
    % Create new figure and set its window name
    hNew = figure;
    set(hNew, 'Name', fullName, 'NumberTitle', 'off');
    
    % Plot the k-th curve
    xData = get(lines(k), 'XData');
    yData = get(lines(k), 'YData');
    plot(xData, yData, 'LineWidth', 1.5);
    grid on
    
    % Set the axes title
    title([origAxesTitle ' – ' thisLegend], 'Interpreter', 'none');
    xlabel(ax.XLabel.String);
    ylabel(ax.YLabel.String);
end

% 1. Grab your open figure & axes
fig   = gcf;
ax    = findobj(fig, 'Type', 'axes');    % find all axes
ax    = ax(1);                           % pick the first (adjust if you have subplots)

% 2. Find the lines & legend strings
lines       = findobj(ax, 'Type', 'line');
lg          = legend(ax);
legendTexts = lg.String;                 % cell array of your legend entries

% 3. Ask the user to choose one entry
[idx, ok] = listdlg(...
    'PromptString', 'Select a curve to fit:', ...
    'ListString'  , legendTexts, ...
    'SelectionMode','single' ...
);

if ~ok
    disp('No curve selected.');
    return;
end

% 4. Extract that line’s data
selLine = lines(idx);
xData   = get(selLine, 'XData')';
yData   = get(selLine, 'YData')';

% 5A. (Option) Send directly into the Curve Fitter GUI:
assignin('base','xForFit', xData);
assignin('base','yForFit', yData);
cftool xForFit yForFit

% 5B. (Or) Do a programmatic fit, e.g. a two-sine built-in model:
% ft = fit(xData, yData, 'sin2');
% plot(ft, xData, yData);

%{
% Select the specific curve
xData = get(lines(3), 'XData');
yData = get(lines(3), 'YData');


ft = fit(xData(:), yData(:), 'a*exp(b*x)+c', 'StartPoint', [1, -1, 0]);
plot(ft, xData, yData);
%}
