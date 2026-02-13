% fit_script_sin5_folding_with_FFT.m
% Fits each curve with 5 sine terms (user-defined foldings),
% plots FFT harmonics, saves figures and table.
close all;

%% 0) Set up parameters
fixedB      = 1;                % Always 1
folds       = [2,4,6,8,10];      % five folding terms
foldTag     = sprintf('b=%d_%d_%d_%d_%d', folds);
savefigures = false;
saveas_png  = false;

%% 1) Define directory
baseDir = [ ...
    'L:\My Drive\Quantum materials lab\Analysis Lab measurments\' ...
    'Magnetic Intercalated TMD\Co1_3TaS2\MG 131\MG131 FIB3 ' ...
    'In Plane Rotator full vs partially in series zfAMR and high res 5 deg\' ...
    'zfAMR at 11T high res 5deg inc 4K 3\fitting' ...
    ];

if savefigures
    figuresDir = fullfile(baseDir, foldTag);
    if ~exist(figuresDir, 'dir'), mkdir(figuresDir); end
    if saveas_png
        pngDir = fullfile(figuresDir, 'PNGs');
        if ~exist(pngDir, 'dir'), mkdir(pngDir); end
    end
end

%% 2) Open .fig file
figFiles = dir(fullfile(baseDir, '*.fig'));
if isempty(figFiles), error('No .fig file in directory'); end
open(fullfile(baseDir, figFiles(1).name));
gcf_fig = gcf;

%% 3) Extract line objects
axAll = findobj(gcf_fig, 'Type','axes');
ax    = axAll(1);
lines = flip(findobj(ax,'Type','line'));

%% 4) Labels & legend names
xlab = ax.XLabel.String;
ylab = ax.YLabel.String;
lg   = legend(ax);
useNames = ~isempty(lg) && ~isempty(lg.String);
if useNames, names = lg.String(:); names = names(1:numel(lines)); end

%% 5) Storage for results
n      = numel(lines);
coeffs = zeros(n,10);   % a1..a5, c1..c5
gofs   = zeros(n,4);    % SSE, R2, AdjR2, RMSE

%% 6) Build fittype for 5 sines
ft = fittype(...
    sprintf(['a1*sin(%d*b*pi/180*x + c1) + ' ...
            'a2*sin(%d*b*pi/180*x + c2) + ' ...
            'a3*sin(%d*b*pi/180*x + c3) + ' ...
            'a4*sin(%d*b*pi/180*x + c4) + ' ...
            'a5*sin(%d*b*pi/180*x + c5)'], folds), ...
    'independent','x', ...
    'coefficients',{'a1','c1','a2','c2','a3','c3','a4','c4','a5','c5'}, ...
    'problem','b' ...
);

%% 7) Loop over each curve
for k = 1:n
    % Extract data
    x = double(lines(k).XData(:));
    y = double(lines(k).YData(:));
    % Curve name
    if useNames, figName = names{k}; else figName = sprintf('Curve_%d',k); end
    safeFig = makeSafeFilename(figName);
    % Handle NaNs
    if any(isnan(y))
        v = ~isnan(y);
        x0 = x(v); y0 = y(v);
        per = max(x0)-min(x0);
        x = [x0; x0+per];
        y = [y0; y0];
    end
    % Extend domain if ≤180°
    if max(x) <= 180
        per   = max(x)-min(x);
        x_ext = x(2:end)+per;
        y_ext = y(2:end);
        x = [x; x_ext];
        y = [y; y_ext];
    end
    % FFT harmonics
    x_rad     = x*pi/180;
    N         = numel(x_rad);
    [xu,iu]   = unique(x_rad);
    yu        = y(iu);
    xu_u      = linspace(min(xu),max(xu),N);
    y_u       = interp1(xu,yu,xu_u,'pchip');
    Y         = fft(y_u)/N;
    m         = 0:floor(N/2)-1;
    amp       = 2*abs(Y(1:floor(N/2)));
    figure('Name',[figName ' FFT'],'NumberTitle','off');
    stem(m,amp,'Marker','none'); grid on;
    xlabel('Harmonic m'); ylabel('Amplitude'); title([figName ' harmonics']);

    % Fit initial guess
    amp_g = (max(y)-min(y))/2;
    sp    = [amp_g,0,amp_g,0,amp_g,0,amp_g,0,amp_g,0];
    [fres, g] = fit(x,y,ft,'StartPoint',sp,'problem',fixedB);
    coeffs(k,:) = [fres.a1, fres.c1, fres.a2, fres.c2, ...
                   fres.a3, fres.c3, fres.a4, fres.c4, ...
                   fres.a5, fres.c5];
    gofs(k,:)   = [g.sse, g.rsquare, g.adjrsquare, g.rmse];

    % Plot fit overlay
    xFit = linspace(min(x),max(x),300)';
    yFit = feval(fres,xFit);
    h = figure('Name',figName,'NumberTitle','off'); hold on;
    plot(x,y,'o'); plot(xFit,yFit,'-','LineWidth',1.5);
    grid on; title(sprintf('%s (%s)',figName,foldTag));
    xlabel(xlab); ylabel(ylab);
    ann = sprintf('b=[%s]\nSSE=%.3f R^2=%.3f RMSE=%.3f', ...
          num2str(folds),g.sse,g.rsquare,g.rmse);
    text(max(x)*0.9,min(y)*1.05,ann,'Background','white');

    % Plot individual components
    y1 = fres.a1*sin(folds(1)*fixedB*pi/180*xFit + fres.c1);
    y2 = fres.a2*sin(folds(2)*fixedB*pi/180*xFit + fres.c2);
    y3 = fres.a3*sin(folds(3)*fixedB*pi/180*xFit + fres.c3);
    y4 = fres.a4*sin(folds(4)*fixedB*pi/180*xFit + fres.c4);
    y5 = fres.a5*sin(folds(5)*fixedB*pi/180*xFit + fres.c5);
    h2 = figure('Name',[figName ' comps'],'NumberTitle','off'); hold on;
    plot(xFit,y1,'-'); plot(xFit,y2,'-'); plot(xFit,y3,'-');
    plot(xFit,y4,'-'); plot(xFit,y5,'-');
    grid on; title([figName ' components']); xlabel(xlab); ylabel(ylab);
    legend(arrayfun(@(m) sprintf('m=%d',m), folds, 'Uni',0));
end

%% 8) Summary table
varNames = {'a1','c1','a2','c2','a3','c3','a4','c4','a5','c5','SSE','R2','AdjR2','RMSE'};
T = array2table([coeffs, gofs], 'VariableNames', varNames);
if useNames, T.Properties.RowNames = names; end

% Create a standard figure and embed a table
figT = figure('Name','Fit Results','NumberTitle','off', ...
              'Units','normalized','Position',[0.1 0.1 0.8 0.8]);

% Use the figure handle in uitable constructor
t = uitable(figT, ...
    'Data',        T{:,:}, ...
    'RowName',     T.Properties.RowNames, ...
    'ColumnName',  T.Properties.VariableNames, ...
    'Units',       'normalized', ...
    'Position',    [0 0 1 1], ...
    'ColumnWidth', 'auto' ...
);

%% Helper: safe filename
function sn = makeSafeFilename(n)
    sn = regexprep(n,'[<>:"/\\|?*]','_');
end