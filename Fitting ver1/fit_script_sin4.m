% fit_script_sin4_folding_with_FFT.m
% Fits each curve with 4 sine terms (user-defined foldings),
% plots FFT harmonics, saves figures and table.
close all;

%% 0) Set up parameters
fixedB      = 1;    % Always 1
folds       = [2,4,6,8];  % four folding terms
foldTag     = sprintf('b=%d,%d,%d,%d', folds);
savefigures = false;
saveas_png  = false;

%% 1) Define directory
baseDir =  ...
    'L:\My Drive\Quantum materials lab\Matlab functions\Some figs' ...
    ;

if savefigures
    figuresDir = fullfile(baseDir, foldTag);
    if ~exist(figuresDir, 'dir'), mkdir(figuresDir); end
    if saveas_png
        pngDir = fullfile(figuresDir, 'PNGs');
        if ~exist(pngDir, 'dir'), mkdir(pngDir); end
    end
end

%% 2) Open .fig
figFiles = dir(fullfile(baseDir, '*.fig'));
if isempty(figFiles), error('No .fig file in directory'); end
open(fullfile(baseDir, figFiles(1).name));
gcf_fig = gcf;

%% 3) Extract lines
axAll = findobj(gcf_fig, 'Type','axes'); ax = axAll(1);
lines = flip(findobj(ax,'Type','line'));

%% 4) Labels & names
xlab = ax.XLabel.String; ylab = ax.YLabel.String;
lg   = legend(ax);
useNames = ~isempty(lg) && ~isempty(lg.String);
if useNames, names = lg.String(:); names = names(1:numel(lines)); end

%% 5) Prepare storage
n      = numel(lines);
coeffs = zeros(n,8);   % a1..a4, c1..c4
gofs   = zeros(n,4);   % SSE, R2, AdjR2, RMSE

%% 6) Build fittype string
foldList = sprintf('%d*b*pi/180*x + c%d) + %d*sin(%d*b*pi/180*x + c%d', ...
    [folds(1),1,folds(2),folds(2),2,folds(3),3,folds(4),4]);
ftExp = ['a1*sin(' foldList ''];
for i=2:4
    % already built above
end
% Instead build directly:
ft = fittype(...
    sprintf(['a1*sin(%d*b*pi/180*x + c1) + ' ...
            'a2*sin(%d*b*pi/180*x + c2) + ' ...
            'a3*sin(%d*b*pi/180*x + c3) + ' ...
            'a4*sin(%d*b*pi/180*x + c4)'], folds), ...
    'independent','x','coefficients',{'a1','c1','a2','c2','a3','c3','a4','c4'}, 'problem','b');

%% 7) Loop
for k=1:n
    x = double(lines(k).XData(:)); y = double(lines(k).YData(:));
    if useNames, figName = names{k}; else figName = sprintf('Curve_%d',k); end
    safeFig = makeSafeFilename(figName);
    % Handle NaN & extend
    if any(isnan(y))
        v = ~isnan(y); x0=x(v); y0=y(v); per=max(x0)-min(x0);
        x=[x0; x0+per]; y=[y0; y0];
    end
    if max(x)<=180
        per=max(x)-min(x);
        x=[x; x(2:end)+per]; y=[y; y(2:end)];
    end
    % FFT harmonics
    xr = x*pi/180; N=length(xr);
    [xu,iu]=unique(xr); yu=y(iu);
    xu_u=linspace(min(xu),max(xu),N);
    y_u=interp1(xu,yu,xu_u,'pchip');
    Y=fft(y_u)/N; m=0:floor(N/2)-1;
    amp=2*abs(Y(1:floor(N/2)));
    figure('Name',[figName ' FFT'],'NumberTitle','off');
    stem(m,amp,'Marker','none'); grid on;
    xlabel('Harmonic m'); ylabel('Amp'); title([figName ' harmonics']);
    
    % Fit
    amp_g=(max(y)-min(y))/2;
    [fres,g]=fit(x,y,ft,'StartPoint',[amp_g,0,amp_g,0,amp_g,0,amp_g,0],'problem',fixedB);
    coeffs(k,:)=[fres.a1,fres.c1,fres.a2,fres.c2,fres.a3,fres.c3,fres.a4,fres.c4];
    gofs(k,:)=[g.sse,g.rsquare,g.adjrsquare,g.rmse];
    % Plot & annotate
    xFit=linspace(min(x),max(x),300)'; yFit=feval(fres,xFit);
    h=figure('Name',figName,'NumberTitle','off'); hold on;
    plot(x,y,'o'); plot(xFit,yFit,'-','LineWidth',1.5); grid on;
    title(sprintf('%s (%s)',figName,foldTag)); xlabel(xlab); ylabel(ylab);
    ann=sprintf('b=[%s]\nSSE=%.3f R^2=%.3f RMSE=%.3f', ...
        num2str(folds),g.sse,g.rsquare,g.rmse);
    text(max(x)*0.9,min(y)*1.05,ann,'Background','white');
    
    % component plots
    yC1=fres.a1*sin(folds(1)*fixedB*pi/180*xFit+fres.c1);
    yC2=fres.a2*sin(folds(2)*fixedB*pi/180*xFit+fres.c2);
    yC3=fres.a3*sin(folds(3)*fixedB*pi/180*xFit+fres.c3);
    yC4=fres.a4*sin(folds(4)*fixedB*pi/180*xFit+fres.c4);
    h2=figure('Name',[figName ' comps'],'NumberTitle','off'); hold on;
    plot(xFit,yC1,'-'); plot(xFit,yC2,'-'); plot(xFit,yC3,'-'); plot(xFit,yC4,'-');
    grid on; title([figName ' components']); xlabel(xlab); ylabel(ylab);
    legend(sprintf('m=%d',folds));
end

%% 8) Summary table
T = array2table([coeffs, gofs], ...
    'VariableNames', {'a1','c1','a2','c2','a3','c3','a4','c4','SSE','R2','AdjR2','RMSE'});
if useNames
    T.Properties.RowNames = names;
end

% Create a full-figure table
figT = figure('Name', 'Fit Results', ...
              'NumberTitle', 'off', ...
              'Units', 'normalized', ...
              'Position', [0.1 0.1 0.8 0.8]);

% Properly specify parent, units, and position
uitable('Parent',      figT, ...
        'Data',        T{:,:}, ...
        'RowName',     T.Properties.RowNames, ...
        'ColumnName',  T.Properties.VariableNames, ...
        'Units',       'normalized', ...
        'Position',    [0 0 1 1], ...
        'ColumnWidth', 'auto'); 

function sn=makeSafeFilename(n)
    sn=regexprep(n,'[<>:"/\\|?*]','_');
end
