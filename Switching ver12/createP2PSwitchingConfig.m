function createP2PSwitchingConfig(tableData, sortedValues, A, pulse_current_str, ...
                                  plot_std, labels, plotChannels)
% createP2PSwitchingConfig
% P2P summary for Configuration mode.
% One figure per channel.
%
% tableData.chX = [N × 5], only active channels

    % determine active channels
    allNames = {'ch1','ch2','ch3','ch4'};
    active = {};
    for k=1:4
        if plotChannels.(allNames{k})
            active{end+1} = allNames{k};
        end
    end
    numCh = numel(active);

    if numCh == 0
        warning('No active channels in createP2PSwitchingConfig.');
        return;
    end

    % x-axis labels are simply Conf numbers
    xVals = sortedValues;

    for c = 1:numCh
        ch = active{c};
        tbl = tableData.(ch); % Nx5

        avgP2P  = tbl(:,1);
        avgBase = tbl(:,3);
        pct     = tbl(:,4);
        stdPct  = tbl(:,5);

        fig = figure('Name', sprintf('P2P Config – %s', labels.(ch)), ...
                     'NumberTitle','off');
        hold on;
        grid on; box on;

        plot(xVals, pct, 'o-', 'LineWidth',2, 'MarkerSize',8, 'Color','k');

        % std bars
        if plot_std
            y_low  = pct - stdPct;
            y_high = pct + stdPct;
            for i = 1:numel(xVals)
                plot([xVals(i) xVals(i)], [y_low(i) y_high(i)], ...
                     'Color',[0.4 0.4 0.4], 'LineWidth',1.5);
            end
        end

        xlabel('Configuration', 'FontSize',16);
        ylabel(physLabel('symbol','R','delta',true,'ratioTo','R','units','\%'), 'FontSize',16);
        title(sprintf('%s   (%s)', labels.(ch), pulse_current_str), 'FontSize',18);
    end
end
