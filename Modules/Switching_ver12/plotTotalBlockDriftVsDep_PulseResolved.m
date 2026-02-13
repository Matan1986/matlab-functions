function plotTotalBlockDriftVsDep_PulseResolved( ...
    stored_data, sortedValues, ...
    pulsesPerBlock, ch_phys, dep_type, labels)

% FINAL – Total drift vs dep
% --------------------------
% Result figure: scalar drift metric vs dep.
%
% - Each PHYSICAL CHANNEL gets its OWN FIGURE
% - State A (blue) / State B (red)
% - ch_phys = []  -> all channels
% - ch_phys = N   -> single channel
% - Suitable for comparison / paper figures
% --------------------------

nDep = numel(sortedValues);

% --- color gradients ---
blueMap = [ ...
    linspace(0.2,0.1,nDep)', ...
    linspace(0.4,0.3,nDep)', ...
    linspace(1.0,0.6,nDep)' ];

redMap  = [ ...
    linspace(1.0,0.6,nDep)', ...
    linspace(0.3,0.1,nDep)', ...
    linspace(0.3,0.1,nDep)' ];

% --- determine channels ---
physIdxAll = stored_data{1,7};
if isempty(ch_phys)
    channelsToUse = physIdxAll;
else
    channelsToUse = ch_phys;
end

% ============================================================
for ch = channelsToUse

    meanDriftA = nan(nDep,1);
    meanDriftB = nan(nDep,1);

    for i = 1:nDep

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

        if Np < 2*pulsesPerBlock
            continue
        end

        blockIdx = floor((0:Np-1)' / pulsesPerBlock);
        nBlocks  = max(blockIdx) + 1;

        driftA = [];
        driftB = [];

        for b0 = 0:(nBlocks-1)

            idx = (blockIdx == b0);
            yBlock = Rpulse(idx);

            if numel(yBlock) < 2
                continue
            end

            n  = numel(yBlock);
            n0 = max(1, round(0.2*n));
            n1 = max(1, round(0.8*n));

            yStart = mean(yBlock(1:n0), 'omitnan');
            yEnd   = mean(yBlock(n1:end), 'omitnan');

            if isnan(yStart) || abs(yStart) < eps
                continue
            end

            driftPct = 100 * (yEnd - yStart) / abs(yStart);

            if mod(b0,2)==0
                driftA(end+1) = driftPct; %#ok<AGROW>
            else
                driftB(end+1) = driftPct; %#ok<AGROW>
            end
        end

        meanDriftA(i) = mean(driftA,'omitnan');
        meanDriftB(i) = mean(driftB,'omitnan');
    end

    lbl = physChannelLabel(ch, labels);

    figName = sprintf( ...
        'Total drift vs %s | %s', ...
        dep_type, lbl);

    figure('Name',figName,'NumberTitle','off');
    box on;

    subplot(2,1,1); hold on;
    plot(sortedValues, meanDriftA, 'o-', ...
        'Color', mean(blueMap,1), ...
        'MarkerFaceColor', mean(blueMap,1), ...
        'LineWidth', 1.5);
    ylabel('\langle total drift \rangle [%]');
    title(sprintf('State A | %s', lbl));
    grid on;

    subplot(2,1,2); hold on;
    plot(sortedValues, meanDriftB, 'o-', ...
        'Color', mean(redMap,1), ...
        'MarkerFaceColor', mean(redMap,1), ...
        'LineWidth', 1.5);
    ylabel('\langle total drift \rangle [%]');
    xlabel(dep_type);
    title(sprintf('State B | %s', lbl));
    grid on;

    if strcmpi(dep_type,'Width')
        subplot(2,1,1); set(gca,'XScale','log');
        subplot(2,1,2); set(gca,'XScale','log');
    end

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
