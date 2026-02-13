function PlotsRHC(Temp_S, RHs, RHr, RHdiff, RHs_norm, RHr_norm, RHd_norm, ...
    Angle, Field, slowValsR, fastValsR, colors, temp_jump_thresh, ...
    Fontsize, legendStrings, RHr_RHs_plotMode, RHorRHT_plotType, ...
    RHrRHor_layout, includeDiff, xVar, lineWidth, ...
    applyShift, shiftValue, addSuffix, Order_down_up, SortMode)
% PlotsRHC: Plot raw/normalized RHs and RHr in overlay or separate layout

n = numel(legendStrings);
if ischar(legendStrings), legendStrings = cellstr(legendStrings); end

% Select x data
switch xVar
    case 'Temp',  xData = Temp_S; xlbl = 'T (K)';
    case 'Angle', xData = Angle;  xlbl = 'φ (°)';
    case 'Field', xData = Field;  xlbl = 'B (T)';
    otherwise,    error('Unknown xVar "%s".', xVar);
end

% Compute vertical offsets
offsets = zeros(n,1);
if applyShift
    for ii = 2:n
        switch SortMode
            case 'fast',  ch = fastValsR(ii) ~= fastValsR(ii-1);
            case 'slow',  ch = slowValsR(ii) ~= slowValsR(ii-1);
            case 'both',  ch = (fastValsR(ii)~=fastValsR(ii-1)) || (slowValsR(ii)~=slowValsR(ii-1));
            otherwise,    error('Unknown SortMode "%s".', SortMode);
        end
        if ch, offsets(ii) = offsets(ii-1) + shiftValue; end
    end
end

% Helper to plot a series
    function plotSeries(dataCell, nameStr, style)
        figure('Name',[nameStr ' vs ' xlbl],'NumberTitle','off'); hold on;
        for jj = 1:n
            dat = dataCell{jj};
            base = applyShift * offsets(jj);
            if applyShift
                y = dat - mean(dat) + base;
            else
                y = dat;
            end
            plot(xData{jj}, y, style, 'LineWidth', lineWidth, 'Color', colors(jj,:));
        end
        xlabel(xlbl); ylabel([nameStr ' (Ω)']); grid on;
        title([nameStr ' vs ' xlbl]);
        legend(legendStrings,'Location','best'); set(gca,'FontSize',Fontsize);
        hold off;
    end

% Plot raw data
if any(strcmp(RHorRHT_plotType, {'raw','both'}))
    switch RHrRHor_layout
        case 'overlay'
            figure('Name',['Raw RH vs ' xlbl],'NumberTitle','off'); hold on;
            for ii = 1:n
                datS = RHs{ii}; datR = RHr{ii}; base = applyShift * offsets(ii);
                if strcmp(RHr_RHs_plotMode,'S') || strcmp(RHr_RHs_plotMode,'B')
                    if applyShift, yS = datS - mean(datS) + base; else yS = datS; end
                    plot(xData{ii}, yS, '-', 'LineWidth', lineWidth, 'Color', colors(ii,:));
                end
                if strcmp(RHr_RHs_plotMode,'R') || strcmp(RHr_RHs_plotMode,'B')
                    if applyShift, yR = datR - mean(datR) + base; else yR = datR; end
                    plot(xData{ii}, yR, '-', 'LineWidth', lineWidth, 'Color', colors(ii,:));
                end
            end
            xlabel(xlbl); ylabel('RH (Ω)'); grid on; legend(legendStrings,'Location','best'); hold off;
        case 'separate'
            if strcmp(RHr_RHs_plotMode,'S') || strcmp(RHr_RHs_plotMode,'B'), plotSeries(RHs, 'RHs', '-'); end
            if strcmp(RHr_RHs_plotMode,'R') || strcmp(RHr_RHs_plotMode,'B'), plotSeries(RHr,'RHr','-'); end
        otherwise, error('Unknown layout "%s".', RHrRHor_layout);
    end
end

% Plot normalized data
if any(strcmp(RHorRHT_plotType, {'norm','both'}))
    switch RHrRHor_layout
        case 'overlay'
            figure('Name',['Norm RH vs ' xlbl],'NumberTitle','off'); hold on;
            for ii = 1:n
                datSN = RHs_norm{ii}; datRN = RHr_norm{ii}; base = applyShift * offsets(ii);
                if strcmp(RHr_RHs_plotMode,'S') || strcmp(RHr_RHs_plotMode,'B')
                    if applyShift, ySN = datSN - mean(datSN) + base; else ySN = datSN; end
                    plot(xData{ii}, ySN, '-', 'LineWidth', lineWidth, 'Color', colors(ii,:));
                end
                if strcmp(RHr_RHs_plotMode,'R') || strcmp(RHr_RHs_plotMode,'B')
                    if applyShift, yRN = datRN - mean(datRN) + base; else yRN = datRN; end
                    plot(xData{ii}, yRN, '-', 'LineWidth', lineWidth, 'Color', colors(ii,:));
                end
            end
            xlabel(xlbl); ylabel('RH/T (Ω/K)'); grid on; legend(legendStrings,'Location','best'); hold off;
        case 'separate'
            if strcmp(RHr_RHs_plotMode,'S') || strcmp(RHr_RHs_plotMode,'B'), plotSeries(RHs_norm,'RHs/T','-'); end
            if strcmp(RHr_RHs_plotMode,'R') || strcmp(RHr_RHs_plotMode,'B'), plotSeries(RHr_norm,'RHr/T','-'); end
        otherwise, error('Unknown layout "%s".', RHrRHor_layout);
    end
end
end
