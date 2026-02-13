function [T, coeffs, gofs] = fitSin2Folding(baseDir, fold1, fold2, norm_chan, saveFigures, saveAsPng)
% fitSin2Folding Fits each curve in a .fig file with two sine terms, shows individual
% subplots plus a combined normalized-residuals plot using a single reference channel.
%   [T, coeffs, gofs] = fitSin2Folding(baseDir, fold1, fold2, norm_chan, saveFigures, saveAsPng)
%
%   Inputs:
%     baseDir      - Directory containing the .fig files to process (string)
%     fold1,fold2  - First and second folding values (numeric)
%     norm_chan    - Index of the channel (curve) to use for normalization
%     saveFigures  - Boolean flag to save .fig outputs (default: false)
%     saveAsPng    - Boolean flag to save .png outputs (default: false)
%
%   Outputs:
%     coeffs - n-by-4 array of fitting coefficients [a1, c1, a2, c2]
%     gofs   - n-by-4 array of goodness-of-fit [SSE, R2, AdjR2, RMSE]
%     T      - Table combining coeffs and gofs with optional row names

    % Default flags
    if nargin < 6, saveAsPng = false; end
    if nargin < 5, saveFigures = false; end
    if nargin < 4
        error('Usage: fitSin2Folding(baseDir, fold1, fold2, norm_chan, saveFigures, saveAsPng)');
    end

    fixedB = 1;
    foldsTag = sprintf('b=%d_%d', fold1, fold2);

    % Create save dirs if needed
    if saveFigures
        figuresDir = fullfile(baseDir, foldsTag);
        if ~exist(figuresDir, 'dir'), mkdir(figuresDir); end
        if saveAsPng
            pngDir = fullfile(figuresDir, 'PNGs');
            if ~exist(pngDir, 'dir'), mkdir(pngDir); end
        end
    end

    % Open first .fig
    figs = dir(fullfile(baseDir, '*.fig'));
    if isempty(figs), error('No .fig in %s', baseDir); end
    open(fullfile(baseDir, figs(1).name));
    hFig = gcf;

    % Extract lines
    axAll = findobj(hFig,'Type','axes');
    if isempty(axAll), error('No axes found'); end
    ax = axAll(1);
    linesObj = flip(findobj(ax,'Type','line'));
    n = numel(linesObj);

    % Labels and legend names
    xlab = ax.XLabel.String; ylab = ax.YLabel.String;
    lg = legend(ax); useNames = ~isempty(lg) && ~isempty(lg.String);
    if useNames, names = lg.String(:); end

    % Preallocate results and residuals
    coeffs = zeros(n,4); gofs = zeros(n,4);
    x_common = double(linesObj(1).XData(:));
    Npts = numel(x_common);
    resid_mat   = zeros(n, Npts);
    comp2_mat   = zeros(n, Npts);

    % Define fit model
    modelStr = sprintf('a1*sin(%d*b*pi/180*x + c1) + a2*sin(%d*b*pi/180*x + c2)', fold1, fold2);
    ft = fittype(modelStr,'independent','x','coefficients',{'a1','c1','a2','c2'},'problem','b');

    % Loop curves: fit, plot, store residuals and comp2
    for k=1:n
        % Extract and clean data
        xk = double(linesObj(k).XData(:));
        yk = double(linesObj(k).YData(:));
        if any(isnan(yk))
            valid = ~isnan(yk);
            x0 = xk(valid); y0 = yk(valid);
            per = max(x0)-min(x0);
            xk = [x0; x0+per]; yk = [y0; y0];
        end
        if max(xk)<=180
            per = max(xk)-min(xk);
            xk = [xk; xk(2:end)+per]; yk = [yk; yk(2:end)];
        end
        % Initial guess
        amp = (max(yk)-min(yk))/2;
        sp = [amp,0,amp,0];
        % Fit
        [fobj,gobj] = fit(xk,yk,ft,'StartPoint',sp,'problem',fixedB);
        coeffs(k,:) = [fobj.a1,fobj.c1,fobj.a2,fobj.c2];
        gofs(k,:)   = [gobj.sse,gobj.rsquare,gobj.adjrsquare,gobj.rmse];

        % Compute on common grid
        yFit      = feval(fobj,     x_common);
        c1_common = fobj.a1*sin(fold1*pi/180*fixedB*x_common + fobj.c1);
        c2_common = fobj.a2*sin(fold2*pi/180*fixedB*x_common + fobj.c2);
        y_common  = interp1(xk, yk, x_common);
        % Store residual and comp2
        resid_mat(k,:) = y_common - c1_common;
        comp2_mat(k,:) = c2_common;

        % Individual figure with 3 subplots
        h = figure('Name',sprintf('Curve_%d',k),'NumberTitle','off');
        % 1) Raw + Fit
        subplot(3,1,1);
            plot(xk,yk,'o','MarkerFaceColor','auto'); hold on;
            plot(x_common,yFit,'-','LineWidth',1.5); grid on;
            if useNames, tname = names{k}; else tname = sprintf('Curve_%d',k); end
            title(sprintf('%s (%s)',tname,foldsTag));
            xlabel(xlab); ylabel(ylab);
        % 2) Both components
        subplot(3,1,2);
            % Plot both components as solid lines
            plot(x_common,c1_common,'-','LineWidth',1.5); hold on;
            plot(x_common,c2_common,'-','LineWidth',1.5); grid on;
            legend(sprintf('fold %d',fold1),sprintf('fold %d',fold2),'Location','northeast');
            title('Components'); xlabel(xlab); ylabel(ylab);
        % 3) Residual and comp2
        subplot(3,1,3);
            % Plot residual and fold2 component both as solid lines
            plot(x_common,resid_mat(k,:),'-','LineWidth',1); hold on;
            plot(x_common,comp2_mat(k,:),'-','LineWidth',1.5); grid on;
            legend('data - fold1',sprintf('fold %d',fold2),'Location','northeast');
            title('Residual vs Fold2 Component'); xlabel(xlab); ylabel('Value');

        % Save if requested
        if saveFigures
            savefig(h, fullfile(figuresDir,sprintf('curve_%d_%s.fig',k,foldsTag)));
            if saveAsPng, saveas(h,fullfile(pngDir,sprintf('curve_%d_%s.png',k,foldsTag))); end
        end
    end    % Combined normalized-residuals plot using reference channel
    if norm_chan>=1 && norm_chan<=n
        % Normalize by the peak amplitude of the reference channel's residual
        h2 = figure('Name','Normalized Residuals','NumberTitle','off'); hold on;
        cmap   = parula(n);
        for kk=1:n
            color = cmap(kk, :);
            plot(x_common, resid_mat(kk,:),'-','LineWidth',1.2,'Color',color);
        end
        xticks(0:45:360);
        xlabel(xlab);
        ylabel("\DeltaR_{xy}/R_{xx} %");
        if useNames, legend(names,'Location','northeast'); end
        grid on; hold off;
        if saveFigures
            savefig(h2, fullfile(figuresDir,['normRes_ch' num2str(norm_chan) '_' foldsTag '.fig']));
            if saveAsPng, saveas(h2, fullfile(pngDir,['normRes_ch' num2str(norm_chan) '_' foldsTag '.png'])); end
        end
    end

    % Summary table
    varNames = {'a1','c1','a2','c2','SSE','R2','AdjR2','RMSE'};
    T = array2table([coeffs,gofs],'VariableNames',varNames);
    if useNames, T.Properties.RowNames = names; end
    if saveFigures
        writetable(T,fullfile(figuresDir,sprintf('fit_results_%s.csv',foldsTag)),'WriteRowNames',true);
    end
    % Display results
    fT = figure('Name','Fit Results','NumberTitle','off','Units','normalized','Position',[0.2 0.2 0.6 0.6]);
    uitable('Parent',fT,'Data',T{:,:},'ColumnName',T.Properties.VariableNames,'RowName',T.Properties.RowNames,'Units','normalized','Position',[0 0 1 1],'ColumnWidth','auto');
end

function s = makeSafeFilename(name)
    s = regexprep(name,'[<>:"\\/\|?*]','_');
end
