function fit_script_sin1(folder, figName)
% fit_script_sin1(folder, figName)
% Fits all curves inside a FIG file using:
%   y = A*cos(f*x) + B*sin(f*x) + d
% Extracts true phase phi = atan2(B, A)
% Works directly from the FIG file, NOT from an open figure.

if nargin < 2
    error('Usage: fit_script_sin1(folder, figName)');
end

figPath = fullfile(folder, figName);

if ~isfile(figPath)
    error('FIG file not found: %s', figPath);
end

fprintf('Opening FIG: %s\n', figPath);
open(figPath);
gcf_fig = gcf;

%% --- Extract axes with line objects
axAll = findall(gcf_fig, 'Type', 'axes');
validAxes = axAll(arrayfun(@(a) ~isempty(findobj(a,'Type','line')), axAll));

if isempty(validAxes)
    error('No axes with line plots found inside the FIG!');
end

ax = validAxes(1);
lines = flip(findobj(ax, 'Type', 'line'));   % preserve legend order

fprintf('Found %d curves\n', numel(lines));

%% --- Labels
xlab = ax.XLabel.String;
ylab = ax.YLabel.String;

%% --- Legend names
lg = legend(ax);
if ~isempty(lg) && ~isempty(lg.String)
    names = lg.String(:);
else
    names = arrayfun(@(k) sprintf('Curve_%d',k), 1:numel(lines), 'UniformOutput', false);
end

%% --- Fit settings
fold1  = 6;
fixedB = 1;

ft = fittype( ...
    sprintf('A*cos(%d*b*pi/180*x) + B*sin(%d*b*pi/180*x) + d', fold1, fold1), ...
    'independent','x', ...
    'coefficients',{'A','B','d'}, ...
    'problem','b' ...
);

n = numel(lines);
coeffs = zeros(n,3);   % A, B, d
phase  = zeros(n,1);   % phi
gofs   = zeros(n,4);   % SSE, R2, AdjR2, RMSE

%% --- Loop over curves
for k = 1:n
    fprintf("Processing: %s\n", names{k});

    x = double(lines(k).XData(:));
    y = double(lines(k).YData(:));

    valid = ~isnan(y);
    x = x(valid);
    y = y(valid);

    % Init guess
    A0 = (max(y)-min(y))/2;
    B0 = 0;
    d0 = mean(y);

    sp = [A0, B0, d0];

    % Fit
    [fres, g] = fit(x, y, ft, 'StartPoint', sp, 'problem', fixedB);

    A = fres.A;
    B = fres.B;
    d = fres.d;

    coeffs(k,:) = [A, B, d];
    phase(k)    = atan2(B, A);   % TRUE PHASE
    gofs(k,:)   = [g.sse, g.rsquare, g.adjrsquare, g.rmse];

    % Plot fit extended to 360
    x360 = linspace(0,360,600)';
    y360 = feval(fres, x360);

    figure('Name',names{k},'NumberTitle','off');
    plot(x, y, 'o', 'MarkerFaceColor','auto'); hold on;
    plot(x360, y360, 'r-', 'LineWidth', 2);

    xlabel(xlab);
    ylabel(ylab);
    grid on;
    title(sprintf('%s — cos+sin fit (phi=%.2f°)', names{k}, rad2deg(phase(k))), ...
        'Interpreter','none');

    legend(names{k}, sprintf('fit fold=%d', fold1), 'Location','best');
end

%% --- Create summary table
phi_deg = rad2deg(phase);

varNames = {'A','B','d','phi_deg','SSE','R2','AdjR2','RMSE'};
T = table(coeffs(:,1), coeffs(:,2), coeffs(:,3), phi_deg, ...
          gofs(:,1), gofs(:,2), gofs(:,3), gofs(:,4), ...
          'RowNames', names, ...
          'VariableNames', varNames);

%% --- Print to command window
disp('===== Fit Results Table =====');
disp(T);

%% --- uitable window
figure('Name','Fit Results Summary','NumberTitle','off','Units','normalized',...
        'Position',[0.2 0.2 0.6 0.6]);

uitable('Data',T{:,:}, 'ColumnName',T.Properties.VariableNames, ...
        'RowName',T.Properties.RowNames, ...
        'Units','normalized','Position',[0 0 1 1], 'ColumnWidth','auto');
