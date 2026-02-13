% fit_sin4_pure_sin.m
% Fit each curve to a sum of 4 sines plus constant offset, with optional tie of first two amplitudes.

close all;

%% 0) Parameters
fixedB             = 1;       % degree-to-radian factor
forceEqualAmp12    = true;    % true to tie A1 == A2 (2θ & 4θ)
duplicateHalfCycle = true;    % replicate 0–180° data to full 360°
savefigs           = false;   % save .figs if true
savePNGs           = false;   % also save .pngs if true

%% 1) Directory setup
baseDir = [ ...
    'L:\My Drive\Quantum materials lab\Analysis Lab measurments\' ...
    'Magnetic Intercalated TMD\Co1_3TaS2\MG 131\MG131 FIB3 ' ...
    'In Plane Rotator full vs partially in series zfAMR and high res 5 deg\' ...
    'zfAMR at 11T high res 5deg inc 4K 3\fitting' ...
];
figFiles = dir(fullfile(baseDir,'*.fig'));
if isempty(figFiles), error('No .fig files found'); end
open(fullfile(baseDir,figFiles(1).name));
fig = gcf;

%% 2) Extract data
axAll = findobj(fig,'Type','axes');
ax    = axAll(1);
lines  = flip(findobj(ax,'Type','line'));
xlab   = ax.XLabel.String;
ylab   = ax.YLabel.String;
lg     = legend(ax);
useNames = ~isempty(lg) && ~isempty(lg.String);
if useNames, names = lg.String(:); names = names(1:numel(lines)); end

%% 3) Build sine-sum model expression
folds = [4,8,6,2];
if forceEqualAmp12
    % A1 shared between 2θ and 4θ terms
    expr = sprintf([ ...
        'A1*sin(%d*b*pi/180*x+phi1) + ' ...
        'A1*sin(%d*b*pi/180*x+phi2) + ' ...
        'A3*sin(%d*b*pi/180*x+phi3) + ' ...
        'A4*sin(%d*b*pi/180*x+phi4) '], folds);
   coeffsList = {'A1','phi1','phi2','A3','phi3','A4','phi4'};
else
    expr = sprintf([ ...
        'A1*sin(%d*b*pi/180*x+phi1) + ' ...
        'A2*sin(%d*b*pi/180*x+phi2) + ' ...
        'A3*sin(%d*b*pi/180*x+phi3) + ' ...
        'A4*sin(%d*b*pi/180*x+phi4) + C'], folds);
    coeffsList = {'A1','phi1','A2','phi2','A3','phi3','A4','phi4','C'};
end
ft = fittype(expr, 'independent','x', 'coefficients',coeffsList, 'problem','b');

%% 4) Prepare storage
n    = numel(lines);
pars = zeros(n,numel(coeffsList));
gofs = zeros(n,4);

%% 5) Loop & fit
for k = 1:n
    x = double(lines(k).XData(:));
    y = double(lines(k).YData(:));
    % duplicate half-cycle if needed
    if duplicateHalfCycle
        span = max(x)-min(x);
        if span<=180 && span>0
            x = [x; x+span]; y = [y; y];
        end
    end
    % initial guesses
yRange = max(y)-min(y);
    startPt = [];
    % A1, phi1
    startPt(end+1:end+2) = [0.5*yRange, 0];
    % A2, phi2 or placeholder
    if forceEqualAmp12
        startPt(end+1) = 0;            % phi2 placeholder
    else
        startPt(end+1:end+2) = [0.5*yRange, 0];
    end
    % A3, phi3
    startPt(end+1:end+2) = [0.5*yRange, 0];
    % A4, phi4
    startPt(end+1:end+2) = [0.5*yRange, 0];
    % C offset
    if any(strcmp(coeffsList,'C'))
        startPt(end+1) = mean(y);
    end
    opts = fitoptions('Method','NonlinearLeastSquares', ...
                      'StartPoint', startPt, 'Robust', 'LAR');
    ft2 = setoptions(ft,opts);
    [fCur, g] = fit(x, y, ft2, 'problem', fixedB);
    pars(k,:) = coeffvalues(fCur);
    gofs(k,:) = [g.sse, g.rsquare, g.adjrsquare, g.rmse];

    % determine figure name
    if useNames
        figName = names{k};
    else
        figName = sprintf('Curve_%d', k);
    end

    % Plot data vs fit
    xFit = linspace(min(x), max(x), 300)';
    yFit = fCur(xFit);
    hf = figure('Name', figName, 'NumberTitle','off');
    plot(x, y, 'o', 'MarkerFaceColor','auto'); hold on;
    plot(xFit, yFit, '-', 'LineWidth',1.5);
    grid on; xlabel(xlab); ylabel(ylab);
    title(sprintf('%s - Fit (4 sin)', figName), 'Interpreter','none');
    legend('Data','Fit','Location','best');

    % Plot individual sine components
    y1 = fCur.A1 * sin(folds(1)*fixedB*pi/180*xFit + fCur.phi1);
    if forceEqualAmp12, A2_val = fCur.A1; else A2_val = fCur.A2; end
    y2 = A2_val * sin(folds(2)*fixedB*pi/180*xFit + fCur.phi2);
    y3 = fCur.A3 * sin(folds(3)*fixedB*pi/180*xFit + fCur.phi3);
    y4 = fCur.A4 * sin(folds(4)*fixedB*pi/180*xFit + fCur.phi4);
    hc = figure('Name', [figName ' - Components'], 'NumberTitle','off'); hold on;
    plot(xFit, y1, '-', 'LineWidth',1.5);
    plot(xFit, y2, '-', 'LineWidth',1.5);
    plot(xFit, y3, '-', 'LineWidth',1.5);
    plot(xFit, y4, '-', 'LineWidth',1.5);
    grid on; xlabel(xlab); ylabel(ylab);
    title(sprintf('%s Components (4 sin)', figName), 'Interpreter','none');
    legend(sprintf('fold %d',folds(1)), sprintf('fold %d',folds(2)), ...
           sprintf('fold %d',folds(3)), sprintf('fold %d',folds(4)), 'Location','best');
end

%% 6) Summary results
tbl = array2table([pars,gofs],'VariableNames',[coeffsList,{'SSE','R2','AdjR2','RMSE'}]);
fH = figure('Name','4-sin Fit Results','NumberTitle','off','Units','normalized','Position',[0.1 0.1 0.8 0.8]);
uitable('Parent',fH,'Data',tbl{:,:},'ColumnName',tbl.Properties.VariableNames,'RowName',tbl.Properties.RowNames,'Units','normalized','Position',[0 0 1 1],'ColumnWidth','auto');

