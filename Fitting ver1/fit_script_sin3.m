% fit_script_ver_sin3_folding_manual_save_with_FFT.m
% Fits each curve with 3 sine terms (user-defined foldings),
% plots FFT spectrum, saves figures and table.
close all;

%% 0) Set up parameters
fixedB      = 1;    % Always 1
fold1       = 2;    % first folding (e.g. 2θ)
fold2       = 4;    % second folding (e.g. 4θ)
fold3       = 8;    % third  folding (e.g. 6θ)

% Create folds tag for folder and filenames
foldsTag    = sprintf('b=%d_%d_%d', fold1, fold2, fold3);
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
% a1, c1, a2, c2, a3, c3
coeffs = zeros(n,6);
% SSE, R2, AdjR2, RMSE
gofs   = zeros(n,4);

%% 7) Define the fittype (3 sines)
ft = fittype( ...
    sprintf('a1*sin(%d*b*pi/180*x + c1) + a2*sin(%d*b*pi/180*x + c2) + a3*sin(%d*b*pi/180*x + c3)', ...
    fold1, fold2, fold3), ...
    'independent', 'x', ...
    'coefficients', {'a1','c1','a2','c2','a3','c3'}, ...
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
    else
        x0 = x; y0 = y;
    end

    % Basic period inference (assumes angular sweep)
    per = max(x0) - min(x0);
    if per == 0
        error('Degenerate x-range for %s.', figName);
    end

    % If there were NaNs: tile once to keep continuity
    if any(isnan(y))
        x  = [x0; x0 + per];
        y  = [y0; y0];
    else
        x = x0; y = y0;
    end

    % --- Extend if needed (only ≤ 180°) ---
    if max(x) - min(x) <= 180
        x_ext = x(2:end) + per;
        y_ext = y(2:end);
        x     = [x; x_ext];
        y     = [y; y_ext];
    end

    %% --- Compute and plot Fourier spectrum ---
    % 1) Resample onto uniform grid in radians over the covered domain
    x_rad     = x * pi/180;
    [xu, idx] = unique(x_rad);
    yu        = y(idx);
    N         = numel(xu);
    x_uniform = linspace(min(xu), max(xu), N);
    y_uniform = interp1(xu, yu, x_uniform, 'pchip');

    % 2) FFT (single-sided amplitudes vs harmonic number m)
    Y   = fft(y_uniform) / N;                  % normalize
    Nh  = floor(N/2);
    amp = 2*abs(Y(1:Nh));                      % single-sided amplitudes
    m   = 0:Nh-1;                              % harmonic index (cycles per 2π over the sampled span)

    % Plot harmonics (index)
    figure('Name',[figName ' – FFT Harmonics'],'NumberTitle','off');
    stem(m, amp, 'Marker','none'); grid on;
    xlabel('Harmonic number m');
    ylabel('Amplitude');
    title([figName ' Fourier Harmonics']);

    % Plot spectrum vs “frequency” scale (cycles per 2π)
    span = max(x_uniform) - min(x_uniform);    % in radians
    if span == 0, span = 1; end
    Fs   = N / span;                            % samples per rad
    f_axis = (0:Nh-1)*(Fs/N)*2*pi;              % cycles per 2π (so integer m map cleanly)
    figure('Name', [figName ' – FFT Spectrum'], 'NumberTitle','off');
    stem(f_axis, amp, 'Marker','none'); grid on;
    xlabel('Harmonic number (cycles per 2\pi)');
    ylabel('Amplitude');
    title([figName ' Fourier Spectrum']);

    % --- Smart initial guess ---
    amp_guess = (max(y)-min(y))/3;
    sp        = [amp_guess, 0, amp_guess, 0, amp_guess, 0];

    % --- Fit ---
    [fres, g] = fit(x, y, ft, 'StartPoint', sp, 'problem', fixedB);

    % --- Store results ---
    coeffs(k,:) = [fres.a1, fres.c1, fres.a2, fres.c2, fres.a3, fres.c3];
    gofs(k,:)   = [g.sse, g.rsquare, g.adjrsquare, g.rmse];

    % --- Generate fit curve ---
    xFit = linspace(min(x), max(x), 300)'; %#ok<*NASGU>
    yFit = feval(fres, xFit);

    % --- Plot fit overlay ---
    hNew = figure('Name', figName, 'NumberTitle','off');
    plot(x,   y,    'o','MarkerFaceColor','auto'); hold on;
    plot(xFit,yFit,'-','LineWidth',1.5);
    grid on;
    title(sprintf('%s (%s)', figName, foldsTag), 'Interpreter','none');
    xlabel(xlab); ylabel(ylab);
    legend(figName, sprintf('folds=[%d,%d,%d]', fold1,fold2,fold3), 'Location','northeast');

    % --- Annotation ---
    annStr = sprintf( ...
        'folds=[%d,%d,%d]\nSSE=%.3f\nR^2=%.3f\nRMSE=%.3f', ...
        fold1, fold2, fold3, g.sse, g.rsquare, g.rmse );
    axNew = gca;
    xL = axNew.XLim; yL = axNew.YLim;
    xPos = xL(2) - 0.02*(xL(2)-xL(1));
    yPos = yL(1) + 0.05*(yL(2)-yL(1));
    text(xPos, yPos, annStr, ...
        'BackgroundColor','white','EdgeColor','black', ...
        'FontSize',8,'HorizontalAlignment','right', ...
        'VerticalAlignment','bottom','Interpreter','none');

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
    y3 = fres.a3 * sin(fold3*fixedB*pi/180*xFit + fres.c3);

    hComp = figure('Name',[figName ' - Components'], 'NumberTitle','off');
    plot(xFit, y1, '-', 'LineWidth',1.5); hold on;
    plot(xFit, y2, '-', 'LineWidth',1.5);
    plot(xFit, y3, '-', 'LineWidth',1.5);
    grid on;
    title(sprintf('%s Components (%s)', figName, foldsTag), 'Interpreter','none');
    xlabel(xlab); ylabel(ylab);
    legend({sprintf('fold %d',fold1), sprintf('fold %d',fold2), sprintf('fold %d',fold3)}, ...
           'Location','northeast');

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
varNames = {'a1','c1','a2','c2','a3','c3','SSE','R2','AdjR2','RMSE'};
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
