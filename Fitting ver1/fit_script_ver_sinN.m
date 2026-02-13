% fit_script_ver_sinN_with_FourierDecomp_pretty.m
% - Degrees-only model (sind/cosd)
% - Optional fixed phases via fix_phases_vec (deg). NaN => free phase
% - Positive amplitudes for FREE phases (phase += 180° if a<0)
% - Phases wrapped to [0°, 360°)
% - Pretty figures, 45° ticks, compact stats box
% - Modern results table
% - Saves figures to b=... subfolder (no more empty folder)
% - Saves results table (XLSX only, rounded to 3 decimals)
% - Saves PNGs to ...\PNGs\ (Fourier + table snapshot) when saveas_png=true
% - Closes lingering uifigure/uitable windows at start

safeCloseTables();    % closes lingering uifigure/uitable windows
close all force; clc;

%% === USER PARAMETERS ===
fixedB = 1;
folds  = [2 4 6 8];
fix_phases_vec = [NaN NaN NaN NaN] ;   % degrees; NaN = free, numeric = fixed
doFFT  = true;

savefigures = true;   % save .fig
saveas_png  = true;   % also .png

baseDir = ...
  'C:\Users\matan\My Drive (matanst@post.bgu.ac.il)\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 131\MG131 FIB10 In Plan Rotator zfAMR\zfAMR 4 high res\Fitting\xx2';

% --- OPTIONAL: if you want to force a specific source fig (leave '' to auto-detect)
sourceFigPathOverride = '';  % e.g. full path to "something.fig"

%% === STYLE ===
fsTitle = 24;
fsAxis  = 20;
fsText  = 18;

%% === PREP ===
numTerms = numel(folds);
assert(numTerms>=1,'folds must have at least one term.');
assert(numel(fix_phases_vec)==numTerms, 'fix_phases_vec must match length(folds).');

foldsStr = strjoin(string(folds), ', ');
foldsTag = sprintf('folds = [%s]', foldsStr);

folds_sub = sprintf('b=%s', strjoin(arrayfun(@num2str, folds, 'uni', false), '_'));

% --- Folders (make outDir always; pngDir only if PNGs requested) ---
outDir = fullfile(baseDir, folds_sub);
if ~exist(outDir,'dir'), mkdir(outDir); end
pngDir = fullfile(outDir, 'PNGs');
if saveas_png && ~exist(pngDir,'dir'), mkdir(pngDir); end

%% === LOAD SOURCE FIG (ROBUST) ===
% Goal: locate a .fig reliably even if baseDir contains only fitting outputs.
% Search order:
%   1) override path (if provided)
%   2) baseDir/*.fig
%   3) baseDir/**/.fig (recursive)
%   4) parentDir/*.fig
% Pick the newest .fig by datenum.

if ~isempty(sourceFigPathOverride)
    assert(exist(sourceFigPathOverride,'file')==2, ...
        'sourceFigPathOverride does not exist: %s', sourceFigPathOverride);
    srcFigPath = sourceFigPathOverride;
else
    figFiles = dir(fullfile(baseDir,'*.fig'));

    if isempty(figFiles)
        figFiles = dir(fullfile(baseDir,'**','*.fig')); % recursive search
    end

    if isempty(figFiles)
        parentDir = fileparts(baseDir);
        figFiles  = dir(fullfile(parentDir,'*.fig'));
    end

    if isempty(figFiles)
        error(['No .fig file found. Searched:\n' ...
               '  1) %s\\*.fig\n  2) %s\\**\\*.fig\n  3) %s\\*.fig (parent)\n' ...
               'Fix: put the source .fig in baseDir, or set sourceFigPathOverride.'], ...
               baseDir, baseDir, fileparts(baseDir));
    end

    [~, idxNewest] = max([figFiles.datenum]);
    srcFigPath = fullfile(figFiles(idxNewest).folder, figFiles(idxNewest).name);
end

% open invisibly to avoid UI clutter; then grab axes/lines
fSrc = openfig(srcFigPath, 'invisible');
set(fSrc, 'Visible','on');  % set to 'off' if you prefer headless
drawnow;

% Pick an axes that is not a legend/colorbar etc.
axs = findobj(fSrc, 'Type','axes');
if isempty(axs), error('No axes found in source .fig: %s', srcFigPath); end

% Heuristic: choose axes with the most line objects
bestAx = axs(1);
bestN  = -inf;
for ia = 1:numel(axs)
    nLines = numel(findobj(axs(ia), 'Type','line'));
    if nLines > bestN
        bestN = nLines;
        bestAx = axs(ia);
    end
end
ax = bestAx;

lines = flip(findobj(ax,'Type','line'));
if isempty(lines), error('No line plots found in source .fig.'); end

xlab = ax.XLabel.String;  ylab = ax.YLabel.String;
xInt = ax.XLabel.Interpreter;  yInt = ax.YLabel.Interpreter;

lg = legend(ax);
if ~isempty(lg) && ~isempty(lg.String)
    if isstring(lg.String) || iscellstr(lg.String)
        names = cellstr(lg.String(:));
    else
        names = arrayfun(@(i)sprintf('Curve_%d',i),1:numel(lines),'UniformOutput',false);
    end
else
    names = arrayfun(@(i)sprintf('Curve_%d',i),1:numel(lines),'UniformOutput',false);
end
if numel(names) ~= numel(lines)
    names = arrayfun(@(i)sprintf('Curve_%d',i),1:numel(lines),'UniformOutput',false);
end

%% === MODEL ===
ft = build_sinN_fittype_deg(numTerms, folds, fix_phases_vec);

%% === STORAGE ===
nCurves = numel(lines);
coeffs  = nan(nCurves, 2*numTerms);
gofs    = nan(nCurves, 4);

%% === MAIN LOOP ===
for k = 1:nCurves
    x = double(lines(k).XData(:));
    y = double(lines(k).YData(:));
    if isempty(x) || numel(x)<2 || all(isnan(y)), continue; end

    figName = names{k};
    safeFig = regexprep(figName,'[<>:"/\\|?*]','_');

    valid = ~isnan(x) & ~isnan(y);
    x = x(valid); y = y(valid);
    per = max(x)-min(x);
    if any(diff(x) < 0),       x=[x; x+per]; y=[y; y];       end
    if (max(x)-min(x)) <= 180, x=[x; x(2:end)+per]; y=[y; y(2:end)]; end

    xmin = min(x); xmax = max(x);

    % ===== Fourier-like decomposition (unnormalized; degrees) =====
    if doFFT
        span_deg  = xmax - xmin;
        L         = 512;
        x_uniform = linspace(xmin, xmax, L);
        y_uniform = interp1(x, y, x_uniform, 'pchip');

        maxHarm = 20;
        scale   = 360/span_deg;
        An = zeros(maxHarm,1);  Bn = zeros(maxHarm,1);
        for n = 1:maxHarm
            An(n) = trapz(x_uniform, y_uniform .* cosd(n*scale*x_uniform));
            Bn(n) = trapz(x_uniform, y_uniform .* sind(n*scale*x_uniform));
        end
        Amp = sqrt(An.^2 + Bn.^2);

        fFFT = figure('Name',[figName ' - Fourier'], ...
                      'NumberTitle','off','Units','normalized','Position',[0.06 0.08 0.78 0.80]);
        stem(1:maxHarm, Amp, 'filled','LineWidth',1.5); grid on;
        set(gca,'FontSize',fsAxis,'TickDir','out');
        xlabel('Harmonic number n (cycles per full span)','FontSize',fsAxis);
        ylabel('Amplitude (unnormalized)','FontSize',fsAxis);
        title(sprintf('%s - Fourier decomposition (span = %.0f°)', figName, span_deg), ...
              'Interpreter','none','FontSize',fsTitle,'FontWeight','bold');
        xlim([0 maxHarm+1]);

        if savefigures
            savefig(fFFT, fullfile(outDir, sprintf('%s_Fourier.fig', safeFig)));
        end
        if saveas_png
            exportgraphics(fFFT, fullfile(pngDir, sprintf('%s_Fourier.png', safeFig)), 'Resolution', 300);
        end
    end

    % ===== Fit =====
    amp_guess = (max(y)-min(y))/2;
    sp = [];
    for t = 1:numTerms
        sp(end+1) = amp_guess*(0.6)^(t-1);
        if isnan(fix_phases_vec(t))
            sp(end+1) = 0;
        end
    end
    [fres, g] = fit(x, y, ft, 'StartPoint', sp, 'problem', fixedB);

    % --- extract adjusted parameters WITHOUT mutating 'fres' ---
    a_adj = zeros(1, numTerms);
    c_adj = zeros(1, numTerms);
    for t = 1:numTerms
        a = fres.(sprintf('a%d',t));
        if isnan(fix_phases_vec(t))
            c = fres.(sprintf('c%d',t));
            if a < 0
                a = -a;
                c = c + 180;
            end
        else
            c = fix_phases_vec(t);
        end
        a_adj(t) = a;
        c_adj(t) = c;
    end
    c_adj = mod(c_adj, 360);

    coeffs_row = reshape([a_adj; c_adj], 1, []);
    coeffs(k,:) = coeffs_row;
    gofs(k,:)   = [g.sse, g.rsquare, g.adjrsquare, g.rmse];

    % ===== Plot: Fit (use adjusted params) =====
    xFit = linspace(xmin, xmax, 400).';
    yFit = zeros(size(xFit));
    for t = 1:numTerms
        yFit = yFit + a_adj(t) * sind(folds(t)*fixedB*xFit + c_adj(t));
    end

    fFit = figure('Name',[figName ' - Fit'], ...
                  'NumberTitle','off','Units','normalized','Position',[0.08 0.08 0.78 0.80]);
    plot(x, y, 'o', 'MarkerFaceColor','auto', 'DisplayName', figName); hold on;
    plot(xFit, yFit, '-', 'LineWidth', 1.9, 'DisplayName', sprintf('fit: %s', foldsTag));
    grid on; set(gca,'FontSize',fsAxis,'TickDir','out');
    xlabel(xlab,'Interpreter',xInt,'FontSize',fsAxis);
    ylabel(ylab,'Interpreter',yInt,'FontSize',fsAxis);
    title(sprintf('%s - Fit (folds = [%s])', figName, foldsStr), ...
          'Interpreter','none','FontSize',fsTitle,'FontWeight','bold');
    legend('Location','northeast','FontSize',fsText);

    xmaxRound = ceil(xmax/45)*45;
    xlim([0 xmax]);
    xticks(0:45:xmaxRound);

    xL = xlim; yL = ylim;
    xPos = xL(1) + 0.005*(xL(2)-xL(1));
    yPos = yL(2) - 0.005*(yL(2)-yL(1));
    text(xPos, yPos, sprintf('R^2 = %.3f\nRMSE = %.3f', g.rsquare, g.rmse), ...
        'EdgeColor','black','BackgroundColor','white', ...
        'FontSize',fsText,'HorizontalAlignment','left','VerticalAlignment','top');

    if savefigures
        savefig(fFit, fullfile(outDir, sprintf('%s_Fit.fig', safeFig)));
    end
    if saveas_png
        exportgraphics(fFit, fullfile(pngDir, sprintf('%s_Fit.png', safeFig)), 'Resolution', 300);
    end

    % ===== Plot: Components (use adjusted params) =====
    fComp = figure('Name',[figName ' - Components'], ...
                   'NumberTitle','off','Units','normalized','Position',[0.10 0.10 0.78 0.80]);
    hold on; grid on; set(gca,'FontSize',fsAxis,'TickDir','out');
    xFit = linspace(xmin, xmax, 400).';
    for t = 1:numTerms
        yt = a_adj(t) * sind(folds(t)*fixedB*xFit + c_adj(t));
        plot(xFit, yt, '-', 'LineWidth', 1.7, ...
             'DisplayName', sprintf('fold %d', folds(t)));
    end
    xlabel(xlab,'Interpreter',xInt,'FontSize',fsAxis);
    ylabel(ylab,'Interpreter',yInt,'FontSize',fsAxis);
    title(sprintf('%s - Components (folds = [%s])', figName, foldsStr), ...
          'Interpreter','none','FontSize',fsTitle,'FontWeight','bold');
    legend('Location','northeast','FontSize',fsText);
    xlim([0 xmax]);
    xticks(0:45:xmaxRound);

    if savefigures
        savefig(fComp, fullfile(outDir, sprintf('%s_Components.fig', safeFig)));
    end
    if saveas_png
        exportgraphics(fComp, fullfile(pngDir, sprintf('%s_Components.png', safeFig)), 'Resolution', 300);
    end
end

%% === RESULTS TABLE (modern UI) ===
ac_names = strings(1,2*numTerms);
for t=1:numTerms, ac_names(2*t-1)="a"+t; ac_names(2*t)="c"+t; end
varNames = [cellstr(ac_names), {'SSE','R2','AdjR2','RMSE'}];
T = array2table([coeffs,gofs], 'VariableNames', varNames, 'RowNames', names);

fmt = @(v) compose('%.4g', v);
nRows = height(T); nCols = width(T);
C = cell(nRows, nCols+1);
C(:,1) = T.Properties.RowNames;
for j = 1:nCols
    if isnumeric(T{:,j}), C(:,j+1) = fmt(T{:,j});
    else,                C(:,j+1) = string(T{:,j});
    end
end
colNames = [{'Curve'}, T.Properties.VariableNames];

colPixels = 120; pad = 80;
figW = max(700, min(1800, pad + colPixels*(nCols+1)));
figH = 420;
uf = uifigure('Name', sprintf('Fit Results (%s)', strjoin(string(folds),'_')), ...
              'Position', [100 100 figW figH]);
uit = uitable(uf, 'Data', C, 'ColumnName', colNames, ...
    'RowName', [], 'FontName', 'Segoe UI', 'FontSize', 16, ...
    'Units', 'normalized', 'Position', [0 0 1 1]);
try, uit.ColumnWidth = 'auto'; end
try, uit.ColumnSortable = true; end
try, uit.ColumnRearrangeable = 'on'; end
try, uit.RowStriping = 'on'; end

tb = uitoolbar(uf);
uipushtool(tb, 'Tooltip','Copy table (tab-separated)', ...
    'ClickedCallback', @(~,~)clipboard('copy', strjoin( ...
        [strjoin(string(colNames), sprintf('\t'))
         arrayfun(@(r) strjoin(string(C(r,:)), sprintf('\t')), (1:nRows).', 'uni', false)], sprintf('\n'))));

%% === SAVE RESULTS TABLE UI (FIG + optional PNG) ===
fieldTag = sprintf('%.2f[T]', fixedB);
safeField = regexprep(fieldTag, '[<>:"/\\|?*]', '_');

savefig(uf, fullfile(outDir, sprintf('%s_FitResults_Table.fig', safeField)));

if saveas_png
    if ~exist(pngDir,'dir'), mkdir(pngDir); end
    saveUITablePNG(uf, uit, fullfile(pngDir, sprintf('%s_FitResults_Table.png', safeField)));
end

%% === Helper (DEGREES model) ===
function ft = build_sinN_fittype_deg(N, folds, fix_phases_vec)
    if nargin < 3, fix_phases_vec = nan(1,N); end
    terms  = strings(1,N);
    coeffs = strings(1, 2*N);
    for i = 1:N
        if isnan(fix_phases_vec(i))
            terms(i) = sprintf('a%d*sind(%d*b*x + c%d)', i, folds(i), i);
            coeffs(2*i-1) = "a"+i;
            coeffs(2*i)   = "c"+i;
        else
            val = fix_phases_vec(i);
            terms(i) = sprintf('a%d*sind(%d*b*x + (%.8f))', i, folds(i), val);
            coeffs(2*i-1) = "a"+i;
            coeffs(2*i)   = "";
        end
    end
    coeffs = coeffs(coeffs~="");
    ft = fittype(strjoin(terms,' + '), ...
        'independent','x', ...
        'coefficients',cellstr(coeffs), ...
        'problem','b');
end

function safeCloseTables()
%SAFECLOSETABLES  Close any open uifigure/uitable windows from prior runs.
    figs = allchild(groot);
    for k = 1:numel(figs)
        f = figs(k);
        if ~ishandle(f), continue; end
        try
            isUIFigure = isprop(f,'Scrollable');
            hasUITable = ~isempty(findall(f, 'Type','uitable')) || ...
                         ~isempty(findall(f, '-class','matlab.ui.control.Table'));
            if isUIFigure || hasUITable
                delete(f);
            end
        catch
        end
    end
end

function saveUITablePNG(uf, uit, outPath)
%SAVEUITABLEPNG  Save a uifigure/uitable to PNG robustly.
    ok = false;

    try
        if exist('exportapp','file') == 2
            exportapp(uf, outPath);
            ok = true;
            return
        end
    catch
    end

    if ~ok
        try
            exportgraphics(uf, outPath, 'Resolution', 300);
            ok = true;
            return
        catch
        end
    end

    try
        pos = getpixelposition(uf);
        ftmp = figure('Visible','off', 'Position', [100 100 pos(3) pos(4)]);
        uit2 = uitable('Parent', ftmp, ...
            'Data', uit.Data, ...
            'ColumnName', uit.ColumnName, ...
            'RowName', [], ...
            'Units','normalized','Position',[0 0 1 1], ...
            'FontName', uit.FontName, 'FontSize', uit.FontSize);

        try, uit2.ColumnWidth = 'auto'; end
        try, uit2.ColumnSortable = true; end
        try, uit2.ColumnRearrangeable = 'on'; end
        try, uit2.RowStriping = 'on'; end

        drawnow;
        fr = getframe(ftmp);
        imwrite(fr.cdata, outPath);
        close(ftmp);
        ok = true;
    catch ME
        warning('Failed to save uitable PNG: %s', ME.message);
    end

    if ~ok
        error('Could not save table PNG to %s', outPath);
    end
end
