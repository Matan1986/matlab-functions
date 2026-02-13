% fit_script_ver_sin2_folding_manual_save_with_FFT.m
% Fits each curve with 2 sine terms (user-defined foldings),
% plots FFT spectrum, saves figures and table.
close all;

%% 0) Set up parameters
fixedB      = 1;    % Always 1
fold1       = 2;    % first folding (e.g. 2θ)
fold2       = 8;    % second folding (e.g. 4θ)

% Create folds tag for folder and filenames
foldsTag    = sprintf('b=%d_%d', fold1, fold2);
savefigures = false;
saveas_png  = false;

%% 1) Define directory
baseDir =  ...
    'L:\My Drive\Quantum materials lab\Matlab functions\Some figs' ...
    ;

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
figPath = fullfile(baseDir, figFiles(1).name);
open(figPath);
gcf_fig = gcf;  % handle to the opened figure

%% 3) Find axes and lines
axAll = findobj(gcf_fig, 'Type', 'axes');
if isempty(axAll), error('No axes found.'); end
ax    = axAll(1);
lines = findobj(ax, 'Type', 'line');
if isempty(lines), error('No line plots found.'); end
lines = flip(lines);  % match legend order

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
n      = numel(lines);
coeffs = zeros(n,4);   % a1, c1, a2, c2
gofs   = zeros(n,4);   % SSE, R2, AdjR2, RMSE

%% 7) Define the fittype
ft = fittype( ...
    sprintf('a1*sin(%d*b*pi/180*x + c1) + a2*sin(%d*b*pi/180*x + c2)', ...
    fold1, fold2), ...
    'independent', 'x', ...
    'coefficients', {'a1','c1','a2','c2'}, ...
    'problem',      'b' ...
    );

%% 8) Loop over each curve
for k = 1:n
    % --- Extract data ---
    x = double(lines(k).XData(:));
    y = double(lines(k).YData(:));

    % --- Decide on this curve’s name ---
    if useNames
        figName = names{k};
    else
        figName = sprintf('Curve_%d', k);
    end
    safeFigName = makeSafeFilename(figName);

    % --- Handle NaNs with periodic extension ---
    if any(isnan(y))
        valid = ~isnan(y);
        x0 = x(valid); y0 = y(valid);
        per = max(x0)-min(x0);
        x  = [x0; x0+per];
        y  = [y0; y0];
    end

    % --- Extend if needed (only ≤ 180°) ---
    if max(x) <= 180
        per   = max(x) - min(x);
        x_ext = x(2:end) + per;
        y_ext = y(2:end);
        x     = [x; x_ext];
        y     = [y; y_ext];
    end

    %% --- Compute and plot Fourier spectrum ---
    % convert x (degrees) to radians and resample onto uniform grid
    x_rad       = x * pi/180;
    N           = numel(x_rad);
    [xu, idx]   = unique(x_rad);
    yu          = y(idx);
    x_uniform   = linspace(min(xu), max(xu), N);
    y_uniform   = interp1(xu, yu, x_uniform, 'pchip');
    Fs          = N/(max(xu)-min(xu));        % sampling freq (cycles per rad)
    Y           = fft(y_uniform);
    f_axis      = (0:N-1)*(Fs/N);             % harmonic index
    amp         = abs(Y)/N*2;                 % single-sided amplitude

    % after y_uniform is defined and FFT computed:
    Y   = fft(y_uniform)/N;           % normalize
    amp = 2*abs(Y(1:floor(N/2)));     % single-sided amplitudes
    m   = (0:floor(N/2)-1);           % harmonic index

    figure('Name',[figName ' – FFT Harmonics'],'NumberTitle','off');
    stem(m, amp, 'Marker','none');
    xlabel('Harmonic number m');
    ylabel('Amplitude');
    title([figName ' Fourier Harmonics']);
    grid on;



    figure('Name', [figName ' – FFT Spectrum'], 'NumberTitle','off');
    stem(f_axis(1:floor(N/2)), amp(1:floor(N/2)), 'Marker','none');
    xlabel('Harmonic number (cycles per 2\pi)');
    ylabel('Amplitude');
    title([figName ' Fourier Spectrum']);
    grid on;

    % --- Smart initial guess ---
    amp_guess = (max(y)-min(y))/2;
    sp        = [amp_guess, 0, amp_guess, 0];

    % --- Fit ---
    [fres, g] = fit(x, y, ft, 'StartPoint', sp, 'problem', fixedB);

    % --- Store results ---
    coeffs(k,:) = [fres.a1, fres.c1, fres.a2, fres.c2];
    gofs(k,:)   = [g.sse, g.rsquare, g.adjrsquare, g.rmse];

    % --- Generate fit curve ---
    xFit = linspace(min(x), max(x), 300)';
    yFit = feval(fres, xFit);

    % --- Plot fit overlay ---
    hNew = figure('Name', figName, 'NumberTitle','off');
    plot(x,   y,    'o','MarkerFaceColor','auto'); hold on;
    plot(xFit,yFit,'-','LineWidth',1.5);
    grid on;
    title(sprintf('%s (%s)', figName, foldsTag), 'Interpreter','none');
    xlabel(xlab); ylabel(ylab);
    legend(figName, sprintf('folds=[%d,%d]', fold1,fold2), 'Location','northeast');

    % --- Annotation ---
    annStr = sprintf(...
        'folds=[%d,%d]\nSSE=%.3f\nR^2=%.3f\nRMSE=%.3f', ...
        fold1, fold2, g.sse, g.rsquare, g.rmse ...
        );
    axNew = gca;
    xL    = axNew.XLim; yL = axNew.YLim;
    xPos  = xL(2) - 0.02*(xL(2)-xL(1));
    yPos  = yL(1) + 0.05*(yL(2)-yL(1));
    text(xPos, yPos, annStr, ...
        'BackgroundColor','white','EdgeColor','black', ...
        'FontSize',8, 'HorizontalAlignment','right', ...
        'VerticalAlignment','bottom', 'Interpreter','none');

    if savefigures
        savefig(hNew, fullfile(figuresDir, ...
            sprintf('%s_%s.fig', safeFigName, foldsTag)));
        if saveas_png
            saveas(hNew, fullfile(pngDir, ...
                sprintf('%s_%s.png', safeFigName, foldsTag)));
        end
    end

    % --- Plot individual sine components ---
    y1 = fres.a1 * sin(fold1*fixedB*pi/180*xFit + fres.c1);
    y2 = fres.a2 * sin(fold2*fixedB*pi/180*xFit + fres.c2);

    hComp = figure('Name',[figName ' - Components'], 'NumberTitle','off');
    plot(xFit, y1, '-', 'LineWidth',1.5); hold on;
    plot(xFit, y2, '-', 'LineWidth',1.5);
    grid on;
    title(sprintf('%s Components (%s)', figName, foldsTag), 'Interpreter','none');
    xlabel(xlab); ylabel(ylab);
    legend({sprintf('fold %d',fold1), sprintf('fold %d',fold2)}, 'Location','northeast');

    if savefigures
        savefig(hComp, fullfile(figuresDir, ...
            sprintf('%s_Components_%s.fig', safeFigName, foldsTag)));
        if saveas_png
            saveas(hComp, fullfile(pngDir, ...
                sprintf('%s_Components_%s.png', safeFigName, foldsTag)));
        end
    end

end  % for k

%% 9) Build and save summary table
varNames = {'a1','c1','a2','c2','SSE','R2','AdjR2','RMSE'};
T        = array2table([coeffs, gofs], 'VariableNames', varNames);
if useNames
    T.Properties.RowNames = names;
end

tableFilename = sprintf('fit_results_%s.csv', foldsTag);
if savefigures
    writetable(T, fullfile(figuresDir, tableFilename), 'WriteRowNames', true);
    fprintf('Summary table saved to: %s\n', ...
        fullfile(figuresDir, tableFilename));
end

% Display table
figTable = figure('Name',sprintf('Fit Results (%s)', foldsTag), ...
    'NumberTitle','off','Units','normalized', ...
    'Position',[0.2 0.2 0.6 0.6]);
uitable('Data',T{:,:}, 'ColumnName',T.Properties.VariableNames, ...
    'RowName',T.Properties.RowNames, 'Units','normalized', ...
    'Position',[0 0 1 1], 'ColumnWidth','auto', 'Parent',figTable);

%% Helper: safe filename
function safeName = makeSafeFilename(name)
safeName = regexprep(name, '[<>:"/\\|?*]', '_');
end
