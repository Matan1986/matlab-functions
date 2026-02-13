function Plots_MT(Temp_table, VSM_table, sortedFields, colors, unitsRatio, ...
    increasing_temp_cell_array, decreasing_temp_cell_array, ...
    growth_num, fontsize, plotQuantity, unitsMode)
% Plots_MT
%   Plot M(T) or M/H(T) per field in separate figures
%   • Unified Y scale across all figures
%   • Smart X limits clipped to [0,300] K
%   • Units handled ONLY via buildMagneticYLabel (TeX-safe)

ZFC_FCW = {"ZFC"; "FCW"};

yMarginFrac = 0.05;
xMarginFrac = 0.02;
xGlobalMin  = 0;
xGlobalMax  = 300;

%% ============================================================
%% PASS 1 — determine global Y limits
%% ============================================================

globalY = [];

for i = 1:numel(sortedFields)

    Temp = Temp_table{i};
    M    = VSM_table{i};
    if isempty(Temp) || isempty(M)
        continue;
    end

    incRaw = increasing_temp_cell_array{i};
    if isempty(incRaw)
        continue;
    end

    % --- normalize segment format ---
    if iscell(incRaw)
        segRanges = incRaw;
    elseif isnumeric(incRaw) && size(incRaw,2) == 2
        segRanges = mat2cell(incRaw, ones(size(incRaw,1),1), 2);
    else
        error('Unsupported incRanges format at index %d', i);
    end

    for j = 1:numel(segRanges)
        r = segRanges{j};
        segM = M(r(1):r(2));

        switch plotQuantity
            case 'M'
                ydata = segM * unitsRatio;
            case 'M_over_H'
                if sortedFields(i) == 0, continue; end
                ydata = segM * unitsRatio / sortedFields(i);
            otherwise
                error('Unknown plotQuantity: %s', plotQuantity);
        end

        globalY = [globalY; ydata(:)];
    end
end

globalY = globalY(isfinite(globalY));
if isempty(globalY)
    globalYLim = [0 1];
else
    yMin   = min(globalY);
    yMax   = max(globalY);
    yRange = yMax - yMin;
    globalYLim = [ ...
        yMin - yRange*yMarginFrac, ...
        yMax + yRange*yMarginFrac ];
end

%% ============================================================
%% PASS 2 — plotting per field
%% ============================================================

for i = 1:numel(sortedFields)

    Temp = Temp_table{i};
    M    = VSM_table{i};
    if isempty(Temp) || isempty(M)
        continue;
    end

    incRaw = increasing_temp_cell_array{i};
    if isempty(incRaw)
        continue;
    end

    if iscell(incRaw)
        segRanges = incRaw;
    elseif isnumeric(incRaw) && size(incRaw,2) == 2
        segRanges = mat2cell(incRaw, ones(size(incRaw,1),1), 2);
    else
        error('Unsupported incRanges format at index %d', i);
    end

    % ---- figure title ----
    switch plotQuantity
        case 'M'
            figTitle = sprintf('MG%d — M(T), %.3f T', ...
                growth_num, sortedFields(i)/1e4);
        case 'M_over_H'
            figTitle = sprintf('MG%d — M/H(T), %.3f T', ...
                growth_num, sortedFields(i)/1e4);
    end

    figure('Name',figTitle,'NumberTitle','off');
    hold on; grid off;

    allT = [];

    for j = 1:numel(segRanges)
        r = segRanges{j};
        segT = Temp(r(1):r(2));
        segM = M(r(1):r(2));

        switch plotQuantity
            case 'M'
                ydata = segM * unitsRatio;
            case 'M_over_H'
                if sortedFields(i) == 0, continue; end
                ydata = segM * unitsRatio / sortedFields(i);
        end

        thisColor = colors(mod(j-1,size(colors,1))+1,:);

        if j <= numel(ZFC_FCW)
            segName = ZFC_FCW{j};
        else
            segName = sprintf('Seg %d', j);
        end

        plot(segT, ydata, ...
            'LineWidth',2, ...
            'Color',thisColor, ...
            'DisplayName',sprintf('%.2f T, %s', ...
            sortedFields(i)/1e4, segName));

        allT = [allT; segT(:)];
    end

    %% ---- axes ----
    xlabel('Temperature (K)','Interpreter','latex');

    yLabelFinal = buildMagneticYLabel(unitsMode, plotQuantity);
    ylabel(yLabelFinal,'Interpreter','latex');

    ax = gca;
    ax.FontSize = fontsize;
    ax.TickLabelInterpreter = 'tex';
    ax.TickDir = 'out';
    ax.Layer   = 'top';

    legend('show','Location','northeast');


    % ---- X limits ----
    if ~isempty(allT)
        xMin = min(allT);
        xMax = max(allT);
        xRange = max(xMax-xMin,1);
        set(gca,'XLim',[ ...
            max(xMin-xRange*xMarginFrac,xGlobalMin), ...
            min(xMax+xRange*xMarginFrac,xGlobalMax)]);
    else
        set(gca,'XLim',[xGlobalMin xGlobalMax]);
    end

    % ---- unified Y limits ----
    set(gca,'YLim',globalYLim);

    hold off;
end

end
