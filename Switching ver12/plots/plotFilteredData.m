function plotFilteredData(figs, stored_data, sortedValues, colors, A, dep_type, ...
    lineWidth, fontsize, activeChannels, tOffset)
% plotFilteredData  (supports 1–4 channels)

N = size(stored_data,1);
numCh = numel(activeChannels);

% ---- conversion factor and xlabel text ----
[convUnits, xlabelStr] = convertDepUnits(dep_type, A);

% ---- legend entries ----
legEntries = cell(N, numCh);

% ---- indices inside filtered data ----
chIndex = struct('ch1',2,'ch2',3,'ch3',4,'ch4',5);

%% =================================================
% 1) Plot filtered traces
% =================================================
for i = 1:N
    filt = stored_data{i,2};      % [t, ch1, ch2, ch3, ch4]
    t = filt(:,1) + tOffset(i);

    for c = 1:numCh
        fig = figs{c};
        figure(fig); hold on;

        y = filt(:, chIndex.(activeChannels{c}));
        plot(t, y, 'Color', colors(i,:), 'LineWidth', lineWidth);

        xticks([]);
        legEntries{i,c} = legendEntry(sortedValues, dep_type, i);
    end
end

%% =================================================
% Set x-limits and grid
% =================================================
tmin = 0;
tmax = tOffset(end) + stored_data{end,2}(end,1);

for c = 1:numCh
    figure(figs{c});
    xlim([tmin tmax]);
    set(gca,'YGrid','on','XGrid','off','GridAlpha',0.15);
end

%% =================================================
% 2) Colorbar — SAME LOGIC AS plotUnfilteredData
% =================================================
special = {'Field cool','Configuration','Cooling rate','Pulse direction and order'};

if ~ismember(dep_type, special)

    for c = 1:numCh
        figure(figs{c});
        colormap(colors);

        if isnumeric(sortedValues)

            physVals = abs(sortedValues(:)) * convUnits;

            switch lower(dep_type)

                % ===== WIDTH : index-based =====
                case {'width'}

                    Nvals = numel(sortedValues);

                    clim([0 Nvals]);
                    cb = colorbar('southoutside');

                    cb.Ticks = (1:Nvals) - 0.5;
                    cb.TickLabels = arrayfun(@(x) ...
                        cleanZero(sprintf('%.2g', x)), ...
                        physVals, 'UniformOutput', false);

                % ===== CONTINUOUS CASES =====
                otherwise

                    ticks  = unique(physVals,'stable');
                    nTicks = numel(ticks);

                    if nTicks > 1
                        edges = zeros(nTicks+1,1);
                        edges(2:end-1) = (ticks(1:end-1)+ticks(2:end))/2;
                        edges(1)       = ticks(1) - (edges(2)-ticks(1));
                        edges(end)     = ticks(end) + (ticks(end)-edges(end-1));
                    else
                        edges = [ticks(1)-1, ticks(1)+1];
                    end

                    tickCenters = (edges(1:end-1)+edges(2:end))/2;

                    clim([edges(1) edges(end)]);
                    cb = colorbar('southoutside');
                    cb.Ticks = tickCenters;

                    % label format
                    switch lower(dep_type)
                        case {'temperature','temp','t'}
                            fmt = '%.0f';
                        case {'field'}
                            fmt = '%.1f';
                        case {'amplitude','amp'}
                            fmt = '%.0f';
                        otherwise
                            fmt = '%.2f';
                    end

                    cb.TickLabels = arrayfun(@(x) ...
                        cleanZero(sprintf(fmt,x)), ...
                        ticks, 'UniformOutput', false);
            end

        else
            cb = colorbar('southoutside');
            cb.Ticks = 1:numel(sortedValues);
            cb.TickLabels = sortedValues;
        end

        xlabel(cb, xlabelStr, 'Interpreter','latex','FontSize',fontsize);
        cb.TickLabelInterpreter = 'latex';
        cb.TickLength = 0;
    end
end

%% =================================================
% 3) Legends
% =================================================
for c = 1:numCh
    figure(figs{c});
    legend(legEntries(:,c),'Location','best','Interpreter','tex');
    legend off;
end

end

% =================================================
% Helper: clean minus-zero
% =================================================
function s = cleanZero(str)
val = str2double(str);
if abs(val) < 1e-12
    s = regexprep(str,'^-0(\.0+)?$','0');
else
    s = str;
end
end
