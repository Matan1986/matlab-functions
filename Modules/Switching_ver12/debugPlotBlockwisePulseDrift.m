function debugPlotBlockwisePulseDrift(stored_data, ch_phys, pulsesPerBlock)

figure; hold on;

colA = [0 0.45 0.74];    % blue
colB = [0.85 0.33 0.1]; % orange

xOffset = 0;
gap     = pulsesPerBlock * 0.6;  % visual gap between blocks

for i = 1:size(stored_data,1)

    if size(stored_data,2) < 7 || isempty(stored_data{i,7})
        continue;
    end

    physIdx = stored_data{i,7};
    k_local = find(physIdx == ch_phys, 1);
    if isempty(k_local)
        continue;
    end

    Rpulse = stored_data{i,6}(:,k_local);
    Np     = numel(Rpulse);

    pulseIdx = 0:(Np-1);
    blockIdx = floor(pulseIdx / pulsesPerBlock);

    numBlocks = max(blockIdx) + 1;

    for b = 0:(numBlocks-1)

        idx = blockIdx == b;
        y   = Rpulse(idx);
        x   = xOffset + (1:numel(y));

        if mod(b,2) == 0
            plot(x, y, '.-', 'Color', colA, ...
                'LineWidth', 1.2, 'MarkerSize', 8);
        else
            plot(x, y, '.-', 'Color', colB, ...
                'LineWidth', 1.2, 'MarkerSize', 8);
        end

        xOffset = x(end) + gap;
    end
end

xlabel('Pulse index (blockwise, chronological)');
ylabel('Plateau mean R (between pulses)');
title(sprintf('Blockwise pulse drift | ch%d | AAAAA → BBBBB → ...', ch_phys));

legend({'A blocks','B blocks'}, 'Location','best');
grid on; box on;

end
