function debugPlotPulseDrift_TimeAxis( ...
    stored_data, sortedValues, ...
    delay_between_pulses_ms, pulsesPerBlock, ...
    ch_phys, dep_type, labels)

% DEBUG – Pulse-resolved drift (time axis)
% ---------------------------------------
% Debug visualization of pulse-by-pulse drift.
%
% - Each PHYSICAL CHANNEL gets its OWN FIGURE
% - A blocks = blue, B blocks = red
% - ch_phys = []  -> all channels
% - ch_phys = N   -> single channel
% - Figure NAME clearly marks this as DEBUG
% ---------------------------------------

nFiles = numel(sortedValues);

% --- color gradients ---
blueMap = [ ...
    linspace(0.2,0.1,nFiles)', ...
    linspace(0.4,0.3,nFiles)', ...
    linspace(1.0,0.6,nFiles)' ];

redMap  = [ ...
    linspace(1.0,0.6,nFiles)', ...
    linspace(0.3,0.1,nFiles)', ...
    linspace(0.3,0.1,nFiles)' ];

% --- determine channels ---
physIdxAll = stored_data{1,7};
if isempty(ch_phys)
    channelsToUse = physIdxAll;
else
    channelsToUse = ch_phys;
end

% ============================================================
for ch = channelsToUse

    lbl = physChannelLabel(ch, labels);

    figName = sprintf( ...
        'DEBUG – Pulse-resolved drift | %s | %s dep', ...
        lbl, dep_type);

    figure('Name',figName,'NumberTitle','off');
    hold on; box on;

    t0 = 0;   % cumulative time offset [ms]

    for i = 1:nFiles

        if size(stored_data,2) < 7 || isempty(stored_data{i,6}) || isempty(stored_data{i,7})
            continue;
        end

        physIdx = stored_data{i,7};
        k = find(physIdx == ch, 1);
        if isempty(k)
            continue;
        end

        Rpulse = stored_data{i,6}(:,k);
        Np     = numel(Rpulse);

        % --- time axis ---
        t = t0 + (0:Np-1)' * delay_between_pulses_ms;

        % --- block structure ---
        blockIdx = floor((0:Np-1)' / pulsesPerBlock);
        isA = mod(blockIdx,2)==0;
        isB = ~isA;

        RA = Rpulse;  RA(~isA) = NaN;
        RB = Rpulse;  RB(~isB) = NaN;

        plot(t, RA, '-', 'Color', blueMap(i,:), 'LineWidth', 1.5);
        plot(t, RA, '.', 'Color', blueMap(i,:), 'MarkerSize', 9);

        plot(t, RB, '-', 'Color', redMap(i,:),  'LineWidth', 1.5);
        plot(t, RB, '.', 'Color', redMap(i,:),  'MarkerSize', 9);

        t0 = t(end) + delay_between_pulses_ms;
    end

    xlabel('Time (ms)');
    ylabel(physLabel('symbol','R','delta',true));
    grid on;

    hA = plot(NaN,NaN,'.-','Color',blueMap(1,:), ...
        'LineWidth',1.5,'MarkerSize',9);
    hB = plot(NaN,NaN,'.-','Color',redMap(1,:), ...
        'LineWidth',1.5,'MarkerSize',9);
    legend([hA hB], {'A blocks','B blocks'}, 'Location','best');

end
end

% ------------------------------------------------------------
function lbl = physChannelLabel(ch_phys, labels)
    field = sprintf('ch%d', ch_phys);
    if isfield(labels, field) && ~isempty(labels.(field))
        lbl = labels.(field);
    else
        lbl = sprintf('ch%d', ch_phys);
    end
end
