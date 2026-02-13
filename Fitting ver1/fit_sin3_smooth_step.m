% fit_sin3_one_sided_step.m
% Fit each curve to a 3-fold sine multiplied by a smooth one-sided logistic step.

close all;

%% 0) Parameters
fixedB      = 1;       % b factor for degree-to-radian conversion
duplicateHalfCycle = true;  % if data spans <=180°, duplicate to cover full 360°
savefigs    = false;  % save figures to disk
savePNGs    = false;  % also save PNGs

%% 1) Directory setup
baseDir = ['L:\My Drive\Quantum materials lab\Analysis Lab measurments\' ...
    'Magnetic Intercalated TMD\Co1_3TaS2\MG 131\MG131 FIB3 ' ...
    'In Plane Rotator full vs partially in series zfAMR and high res 5 deg\\' ...
    'zfAMR at 11T high res 5deg inc 4K 3\\fitting'];

figFiles = dir(fullfile(baseDir,'*.fig'));
if isempty(figFiles)
    error('No .fig file found in the specified directory.');
end
open(fullfile(baseDir,figFiles(1).name));
fig = gcf;

%% 2) Extract data
axAll = findobj(fig,'Type','axes');
ax    = axAll(1);
lines = flip(findobj(ax,'Type','line'));
xlab  = ax.XLabel.String;
ylab  = ax.YLabel.String;
lg    = legend(ax);
useNames = ~isempty(lg) && ~isempty(lg.String);
if useNames
    names = lg.String(:);
    names = names(1:numel(lines));
end

%% 3) Define one-sided logistic step model
% y(x) = A*sin(3*b*pi/180*x + phi) ./ (1 + exp(-k*(x - x0))) + C
ft = fittype('A*sin(3*b*pi/180*x + phi) ./ (1 + exp(-k*(x - x0))) + C', ...
    'independent','x', ...
    'coefficients',{'A','phi','k','x0','C'}, ...
    'problem','b');

%% 4) Prepare storage
n    = numel(lines);
pars = zeros(n,5);  % [A,phi,k,x0,C]
gofs = zeros(n,4);  % [SSE,R2,AdjR2,RMSE]

%% 5) Loop over curves
for k = 1:n
    x = double(lines(k).XData(:));
    y = double(lines(k).YData(:));
    % extend half-cycle if needed
    if duplicateHalfCycle
        span = max(x)-min(x);
        if span <= 180 && span > 0
            x = [x; x+span];
            y = [y; y];
        end
    end
    % initial guesses
    A0   = 0.5*(max(y)-min(y));
    phi0 = 0;
    k0   = 0.1;
    x00  = 0.5*(min(x)+max(x));
    C0   = mean(y);
    opts = fitoptions('Method','NonlinearLeastSquares', ...
        'StartPoint',[A0,phi0,k0,x00,C0], ...
        'Lower',[0,-Inf,-0.5,min(x)-45,-Inf], ...
        'Upper',[Inf,Inf,0.5,max(x)+45,Inf], ...
        'Robust','LAR');
    ft2 = setoptions(ft,opts);
    [f,g] = fit(x,y,ft2,'problem',fixedB);
    pars(k,:) = [f.A,f.phi,f.k,f.x0,f.C];
    gofs(k,:) = [g.sse,g.rsquare,g.adjrsquare,g.rmse];

    % name
    if useNames, figName = names{k}; else figName = sprintf('Curve_%d',k); end
    % dense grid
    xFit = linspace(min(x),max(x),500)';
    yFit = feval(f,xFit);
    % plot data vs fit
    hf = figure('Name',figName,'NumberTitle','off');
    plot(x,y,'o','MarkerFaceColor','auto'); hold on;
    plot(xFit,yFit,'-','LineWidth',1.5);
    grid on; xlabel(xlab); ylabel(ylab);
    title([figName ' - Fit (sin3 x step)']);
    legend('Data','Fit','Location','best');
    % plot components
    sineComp = f.A*sin(3*fixedB*pi/180*xFit + f.phi);
    stepComp = 1./(1+exp(-f.k*(xFit - f.x0)));
    hc = figure('Name',[figName ' - Components'],'NumberTitle','off');
    subplot(3,1,1); plot(xFit,sineComp,'-','LineWidth',1.4); grid on; title('3-fold sine');
    subplot(3,1,2); plot(xFit,stepComp,'-','LineWidth',1.4); grid on; title('Logistic step');
    subplot(3,1,3); plot(xFit,sineComp.*stepComp+f.C,'-','LineWidth',1.4); hold on; plot(x,y,'o','MarkerFaceColor','auto'); grid on;
    title('Product + offset vs data'); xlabel(xlab); ylabel(ylab);
    % optional saving
    if savefigs
        outDir = fullfile(baseDir,'sin3_step_results'); if ~exist(outDir,'dir'), mkdir(outDir); end
        savefig(hf, fullfile(outDir,[figName '_fit.fig']));
        savefig(hc, fullfile(outDir,[figName '_comps.fig']));
        if savePNGs, saveas(hf,fullfile(outDir,[figName '_fit.png'])); saveas(hc,fullfile(outDir,[figName '_comps.png'])); end
    end
end

%% 6) Summary table
T = array2table([pars,gofs],'VariableNames',{'A','phi','k','x0','C','SSE','R2','AdjR2','RMSE'});
ftab = figure('Name','Fit Results','NumberTitle','off','Units','normalized','Position',[0.2 0.2 0.6 0.6]);
uitable('Parent',ftab,'Data',T{:,:},'ColumnName',T.Properties.VariableNames,'RowName',T.Properties.RowNames,'Units','normalized','Position',[0 0 1 1],'ColumnWidth','auto');

