function plotUnfilteredData(figs, stored_data, sortedValues, colors, A, dep_type, ...
    lineWidth, fontsize, activeChannels, tOffset)
% plotUnfilteredData  (supports 1–4 channels)

N     = size(stored_data,1);
numCh = numel(activeChannels);

% ---- conversion factor and xlabel text ----
[convUnits, xlabelStr] = convertDepUnits(dep_type, A);

% ---- legend container ----
legEntries = cell(N, numCh);

% ---- channel indices ----
chIndex = struct('ch1',2,'ch2',3,'ch3',4,'ch4',5);

%% =================================================
% 1) Plot raw traces
% =================================================
for i = 1:N
    raw = stored_data{i,1};
    t   = raw(:,1) + tOffset(i);

    for c = 1:numCh
        fig = figs{c};
        figure(fig); hold on;

        y = raw(:, chIndex.(activeChannels{c}));
        plot(t, y, 'Color', colors(i,:), 'LineWidth', lineWidth);

        xticks([]);
        legEntries{i,c} = legendEntry(sortedValues, dep_type, i);
    end
end

%% =================================================
% Set x-limits
% =================================================
tmin = 0;
tmax = tOffset(end) + stored_data{end,1}(end,1);

for c = 1:numCh
    figure(figs{c});
    xlim([tmin tmax]);
end

%% =================================================
% 2) Pulse averages
% =================================================
physIndex = stored_data{1,7};

for i = 1:N
    raw = stored_data{i,1};
    t   = raw(:,1) + tOffset(i);

    pulses   = stored_data{i,4};
    avg_vals = stored_data{i,5};

    pulse_start = find(diff([0; pulses(:); 0]) == 1);
    pulse_end   = find(diff([0; pulses(:); 0]) == -1);

    for c = 1:numCh
        fig = figs{c};
        figure(fig); hold on;

        physCh = sscanf(activeChannels{c}, 'ch%d');
        col    = find(physIndex == physCh, 1);
        if isempty(col), continue; end

        avgC = avg_vals(:, col);

        for j = 1:numel(pulse_start)
            st = t(pulse_start(j));
            en = t(min(pulse_end(j), numel(t)));
            plot([st en], [avgC(j) avgC(j)], ...
                'm', 'LineWidth', 3, 'HandleVisibility','off');
        end
    end
end

%% =================================================
% Grid (Y only)
% =================================================
for c = 1:numCh
    figure(figs{c});
    ax = gca;
    set(ax,'YGrid','on','XGrid','off','GridAlpha',0.15);
end

%% =================================================
% 3) Colorbar — CORRECT centered ticks
% =================================================
special = {'Field cool','Configuration','Cooling rate','Pulse direction and order'};

if ~ismember(dep_type, special)

    for c = 1:numCh
        figure(figs{c});
        colormap(colors);

        if isnumeric(sortedValues)

            % ---- physical values ----
            physVals = abs(sortedValues(:)) * convUnits;
            ticks    = unique(physVals,'stable');
            nTicks   = numel(ticks);

            % ---- compute bin edges ----
            if nTicks > 1
                edges = zeros(nTicks+1,1);
                edges(2:end-1) = (ticks(1:end-1) + ticks(2:end)) / 2;
                edges(1)       = ticks(1) - (edges(2) - ticks(1));
                edges(end)     = ticks(end) + (ticks(end) - edges(end-1));
            else
                edges = [ticks(1)-1, ticks(1)+1];
            end

            % ---- centers ----
            tickCenters = (edges(1:end-1) + edges(2:end)) / 2;

            % ---- colorbar ----
            clim([edges(1) edges(end)]);
            cb = colorbar('southoutside');
            cb.Ticks = tickCenters;

            % ---- label format ----
            switch lower(dep_type)
                case {'temperature','temp','t'}
                    fmt = '%.0f';
                case {'field'}
                    fmt = '%.1f';
                case {'width'}

                    % --- index-based colorbar ---
                    Nvals = numel(sortedValues);

                    clim([0 Nvals]);
                    cb = colorbar('southoutside');

                    % --- ticks at center of each color ---
                    cb.Ticks = (1:Nvals) - 0.5;

                    % --- physical values as labels (log-spaced but discrete) ---
                    physVals = abs(sortedValues(:)) * convUnits;

                    cb.TickLabels = arrayfun(@(x) ...
                        cleanZero(sprintf('%.2g', x)), ...
                        physVals, 'UniformOutput', false);

                case {'amplitude','amp'}
                    fmt = '%.0f';
                otherwise
                    fmt = '%.2f';
            end

            if ~strcmpi(dep_type,'width')
                cb.TickLabels = arrayfun(@(x) cleanZero(sprintf(fmt,x)), ...
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
% 4) Legends
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
