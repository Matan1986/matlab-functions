function debugPlotGlobalPulseDrift_blocks(stored_data, ch_phys, pulsesPerBlock)
% Global pulse-resolved drift
% Chronological order: AAAAA BBBBB AAAAA BBBBB ...

figure; hold on;

% --- nice, fixed colors ---
colA = [0 0.45 0.74];    % blue
colB = [0.85 0.33 0.1]; % orange

pulseCounter = 0;

for i = 1:size(stored_data,1)

    if size(stored_data,2) < 7 || isempty(stored_data{i,7})
        continue;
    end

    physIdx = stored_data{i,7};
    k_local = find(physIdx == ch_phys, 1);
    if isempty(k_local)
        continue;
    end

    Rpulse = stored_data{i,6}(:, k_local);
    Np     = numel(Rpulse);

    pulseIdx  = 0:(Np-1);
    blockIdx  = floor(pulseIdx / pulsesPerBlock);

    isA = mod(blockIdx,2) == 0;
    isB = ~isA;

    x = pulseCounter + (1:Np);

    plot(x(isA), Rpulse(isA), '.-', ...
        'Color', colA, 'LineWidth', 1.2, 'MarkerSize', 7);

    plot(x(isB), Rpulse(isB), '.-', ...
        'Color', colB, 'LineWidth', 1.2, 'MarkerSize', 7);

    % ---- mark file boundary ----
    if i > 1
        xline(pulseCounter + 0.5, ':', ...
            'Color', [0.6 0.6 0.6], 'LineWidth', 0.75);
    end

    pulseCounter = pulseCounter + Np;
end

xlabel('Global pulse index (chronological)');
ylabel('Plateau mean R (between pulses)');
title(sprintf('Global pulse-resolved drift | ch%d | AAAAA vs BBBBB', ch_phys));

legend({'A pulses','B pulses'}, 'Location','best');
grid on; box on;

end
