% fit_script_ver_sin2_folding_manual_save_product.m
% Fits each curve with the PRODUCT of 2 sine terms (user-defined foldings), saves figures and table.
close all;

%% 0) Set up parameters
fixedB       = 1;  % Always 1
fold1        = 2;  % first folding
fold2        = 3;  % second folding

% Create folds tag for folder and filenames
foldsTag     = sprintf('b=%d_%d', fold1, fold2);
savefigures  = false;
saveas_png   = false;

%% 1) Define directory
baseDir  = 'I:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 131\MG131 FIB3 In Plane Rotator full vs partially in series zfAMR and high res 5 deg\zfAMR at 11T high res 5deg inc 4K 3\fitting';

if savefigures
    figuresDir = fullfile(baseDir, foldsTag);
    if ~exist(figuresDir, 'dir')
        mkdir(figuresDir);
    end
    if saveas_png
        pngDir = fullfile(figuresDir, 'PNGs');
        if ~exist(pngDir, 'dir')
            mkdir(pngDir);
        end
    end
end

%% 2) Find and open the .fig file
figFiles = dir(fullfile(baseDir, '*.fig'));
if isempty(figFiles)
    error('No .fig file found in the specified directory.');
end
figPath  = fullfile(baseDir, figFiles(1).name);
open(figPath);
gcf_fig  = gcf;  % handle to the opened figure

%% 3) Find axes and lines
axAll = findobj(gcf_fig, 'Type', 'axes');
if isempty(axAll), error('No axes found.'); end
ax       = axAll(1);
lines    = findobj(ax, 'Type', 'line');
if isempty(lines), error('No line plots found.'); end
lines    = flip(lines);  % match legend order

%% 4) Capture axis labels
xlab = ax.XLabel.String;
ylab = ax.YLabel.String;

%% 5) Legend entries (for names)
lg       = legend(ax);
useNames = ~isempty(lg) && ~isempty(lg.String);
if useNames
    names = lg.String(:);
    names = names(1:numel(lines));
end

%% 6) Prepare storage
n        = numel(lines);
coeffs   = zeros(n,3);   % A, c1, c2
gofs     = zeros(n,4);   % SSE, R2, AdjR2, RMSE

%% 7) Define the fittype for PRODUCT of two sines
ft = fittype( ...
    sprintf('A*sin(%d*b*pi/180*x + c1).*sin(%d*b*pi/180*x + c2)', fold1, fold2), ...
    'independent','x', ...
    'coefficients',{'A','c1','c2'}, ...
    'problem','b');

%% 8) Loop over each curve
for k = 1:n
    % --- Extract data ---
    x = double(lines(k).XData(:));
    y = double(lines(k).YData(:));

    % Handle NaNs with periodic extension
    if any(isnan(y))
        valid = ~isnan(y);
        x0    = x(valid);  y0 = y(valid);
        per   = max(x0) - min(x0);
        x     = [x0; x0+per];
        y     = [y0; y0];
    end

    % Extend if needed (only ≤ 180)
    if max(x) <= 180
        per   = max(x) - min(x);
        x_ext = x(2:end) + per;
        y_ext = y(2:end);
        x     = [x; x_ext];
        y     = [y; y_ext];
    end

    % --- Smart initial guess ---
    amp_guess = (max(y) - min(y)) / 2;
    sp        = [amp_guess, 0, 0];

    % --- Fit to the PRODUCT model ---
    [f, g]   = fit(x, y, ft, 'StartPoint', sp, 'problem', fixedB);

    % --- Store results ---
    coeffs(k,:) = [f.A, f.c1, f.c2];
    gofs(k,:)   = [g.sse, g.rsquare, g.adjrsquare, g.rmse];

    % --- Generate fit curve ---
    xFit = linspace(min(x), max(x), 300)';
    yFit = feval(f, xFit);

    % --- Plot and save ---
    if useNames
        figName = names{k};
    else
        figName = sprintf('Curve_%d', k);
    end
    safeFigName = makeSafeFilename(figName);

    hNew = figure('Name', figName, 'NumberTitle', 'off');
    plot(x,    y,    'o', 'MarkerFaceColor','auto'); hold on;
    plot(xFit, yFit, '-', 'LineWidth',1.5);
    grid on;
    title(sprintf('%s (product folds=[%d,%d])', figName, fold1, fold2), 'Interpreter','none');
    xlabel(xlab);  ylabel(ylab);
    legend({'data', sprintf('A·sin(%d·x+ c_1)·sin(%d·x+ c_2)',fold1,fold2)}, 'Location','northeast');

    % --- Overlay annotation ---
    annStr = sprintf('folds=[%d,%d]\nSSE=%.3f\nR^2=%.3f\nRMSE=%.3f', ...
                     fold1, fold2, g.sse, g.rsquare, g.rmse);
    axNew = gca;
    xL    = axNew.XLim;  yL = axNew.YLim;
    xPos  = xL(2) - 0.02*(xL(2)-xL(1));
    yPos  = yL(1) + 0.05*(yL(2)-yL(1));
    text(xPos, yPos, annStr, 'BackgroundColor','white', ...
         'EdgeColor','black','FontSize',8,...
         'HorizontalAlignment','right','VerticalAlignment','bottom',...
         'Interpreter','none');

    if savefigures
        savefig(hNew, fullfile(figuresDir, sprintf('%s_%s.fig', safeFigName, foldsTag)));
        if saveas_png
            saveas(hNew, fullfile(pngDir, sprintf('%s_%s.png', safeFigName, foldsTag)));
        end
    end
end

%% 9) Build and save summary table
varNames      = {'A','c1','c2','SSE','R2','AdjR2','RMSE'};
T             = array2table([coeffs, gofs], 'VariableNames', varNames);

if useNames
    T.Properties.RowNames = names;
end

tableFilename = sprintf('fit_results_%s.csv', foldsTag);
if savefigures
    writetable(T, fullfile(figuresDir, tableFilename), 'WriteRowNames', true);
    fprintf('Summary table saved to: %s\n', fullfile(figuresDir, tableFilename));
end

% Display table in a new window
figTable = figure('Name', sprintf('Fit Results (%s)', foldsTag), ...
                  'NumberTitle','off','Units','normalized', ...
                  'Position',[0.2 0.2 0.6 0.6]);
uitable('Data',        T{:,:}, ...
        'ColumnName',  T.Properties.VariableNames, ...
        'RowName',     T.Properties.RowNames, ...
        'Units',       'normalized', ...
        'Position',    [0 0 1 1], ...
        'ColumnWidth','auto', ...
        'Parent',      figTable);

%% Safe‐filename helper
function safeName = makeSafeFilename(name)
    safeName = regexprep(name, '[<>:"/\\|?*]', '_');
end
