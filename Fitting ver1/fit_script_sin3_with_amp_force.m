% fit_script_sin3.m
% ------------------------------------------------------------------------------
% Fits ΔR% vs. angle data from multiple .fig files to three sine terms (2θ, 4θ, 6θ)
% plus constant offset, then plots individual fits and a summary table.
% ------------------------------------------------------------------------------

close all;
clc;

%% 0) User parameters
fixedB             = 1;        % degree-to-radian factor
folds              = [2, 4, 6];% the harmonics (2θ, 4θ, 6θ)
forceEqualAmp12    = false;    % true to tie A1 == A2 (2θ & 4θ)
saveFigures        = false;    % save .figs if true
savePNGs           = false;    % also save .pngs if true

%% 1) Directory & figure files
% Specify your full Windows path as one continued string with escaped backslashes:
dataDir =  ...
    'L:\My Drive\Quantum materials lab\Matlab functions\Some figs' ...
;
figFiles = dir(fullfile(dataDir, '*.fig'));
if isempty(figFiles)
    error('No .fig files found in %s', dataDir);
end

%% 2) Loop over each .fig file
results = struct('file',{},'gof',{},'coeffs',{});
for k = 1:numel(figFiles)
    % Load figure
    open(fullfile(dataDir, figFiles(k).name));
    fig = gcf;

    %% 3) Extract data
    axList = findobj(fig, 'Type','axes');
    ax = axList(1);
    lineAll = findobj(ax, 'Type','line');
    lineObj = lineAll(1);
    if isempty(lineObj)
        warning('Skipping %s: no line data.', figFiles(k).name);
        close(fig);
        continue;
    end
    xData = lineObj.XData(:);
    yData = lineObj.YData(:);
    valid = ~isnan(xData) & ~isnan(yData);
    xData = xData(valid);
    yData = yData(valid);

    %% 4) Build fit type & options
    Nf = numel(folds);
    if forceEqualAmp12
        expr = sprintf('C + A1*sin(%d*b*x*pi/180+phi1) + A1*sin(%d*b*x*pi/180+phi2) + A3*sin(%d*b*x*pi/180+phi3)', folds);
        coeffNames = {'C','A1','phi1','phi2','A3','phi3'};
    else
        expr = sprintf('C + A1*sin(%d*b*x*pi/180+phi1) + A2*sin(%d*b*x*pi/180+phi2) + A3*sin(%d*b*x*pi/180+phi3)', folds);
        coeffNames = {'C','A1','phi1','A2','phi2','A3','phi3'};
    end
    tf = fittype(expr, 'independent','x','coefficients',coeffNames, 'problem','b');

    % Initial guesses matching coeffNames count
    startPts = zeros(1, numel(coeffNames));
    for i = 1:numel(coeffNames)
        nm = coeffNames{i};
        if strcmp(nm,'C')
            startPts(i) = mean(yData);
        elseif startsWith(nm,'A')
            startPts(i) = (max(yData)-min(yData))/(2*Nf);
        else % phi
            startPts(i) = 0;
        end
    end
    opts = fitoptions('Method','NonlinearLeastSquares', ...
                      'StartPoint', startPts, ...
                      'Lower',[-Inf, repmat(-Inf,1,numel(coeffNames)-1)], ...
                      'Upper',[ Inf, repmat( Inf,1,numel(coeffNames)-1)]);

    %% 5) Perform fit
    [fObj, gof] = fit(xData, yData, tf, opts, 'problem', fixedB);

    %% 6) Generate fit curve & components
    xFit = linspace(min(xData), max(xData), 300).';
    vals = coeffvalues(fObj); C0 = vals(1);
    if forceEqualAmp12
        A = [vals(2), vals(2), vals(5)]; phi = [vals(3), vals(4), vals(6)];
    else
        A = [vals(2), vals(4), vals(6)]; phi = [vals(3), vals(5), vals(7)];
    end
    yFit = C0*ones(size(xFit)); comps = zeros(numel(xFit), Nf);
    for j=1:Nf
        comps(:,j) = A(j).*sin(folds(j)*fixedB*pi/180 .* xFit + phi(j));
        yFit = yFit + comps(:,j);
    end

    %% 7) Plot results
    figure('Name',figFiles(k).name,'Color','w'); hold on; grid on;
    plot(xData, yData, 'ko','MarkerFaceColor','g');
    plot(xFit, yFit, 'b-','LineWidth',1.5);
    cols = feval('lines', Nf);
    for j=1:Nf, plot(xFit, comps(:,j), '--','Color',cols(j,:)); end
    hold off;
    xlabel('Angle (°)'); ylabel('Signal');
    title(['Fit: ', figFiles(k).name]);
    legend(['Data','Fit', arrayfun(@(n)[num2str(folds(n)),'θ'],1:Nf,'Uni',0)], 'Location','Best');

    %% 8) Save if desired
    if saveFigures || savePNGs
        safe = regexprep(figFiles(k).name,'[^\w]','_');
        if saveFigures, saveas(gcf,[safe,'.fig']); end
        if savePNGs,    saveas(gcf,[safe,'.png']); end
    end

    %% 9) Record results and close
    results(k).file   = figFiles(k).name;
    results(k).gof    = gof;
    results(k).coeffs = vals;
    close(fig);
end

%% 10) Summary table
% Convert results struct to cell data for uitable to avoid mixed types issue
vars = {'file','gof','coeffs'};
cellData = cell(numel(results), numel(vars));
for i=1:numel(results)
    cellData{i,1} = results(i).file;
    cellData{i,2} = sprintf('R2=%.3f', results(i).gof.rsquare);
    cellData{i,3} = jsonencode(results(i).coeffs);
end

figure('Name','All Fit Results');
uitable('Data', cellData, 'ColumnName', vars);
