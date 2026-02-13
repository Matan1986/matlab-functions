function plot_founded_decreasing_temperature_segments(Timems, TemperatureK, FieldT, segments_decreasing_temp, filtered_temp)
%% Plot Decreasing Temperature Segments (robust to small length mismatches)

    % ---- 0) Align lengths to a common n ----
    Timems        = Timems(:);
    TemperatureK  = TemperatureK(:);
    FieldT        = FieldT(:);
    filtered_temp = filtered_temp(:);

    nCommon = min([numel(Timems), numel(TemperatureK), numel(FieldT), numel(filtered_temp)]);
    if any([numel(Timems), numel(TemperatureK), numel(FieldT), numel(filtered_temp)] ~= nCommon)
        Timems        = Timems(1:nCommon);
        TemperatureK  = TemperatureK(1:nCommon);
        FieldT        = FieldT(1:nCommon);
        filtered_temp = filtered_temp(1:nCommon);
        segments_decreasing_temp = clean_and_clip_segments(segments_decreasing_temp, nCommon);
    end

    % Early-out if nothing to plot
    if isempty(Timems) || isempty(TemperatureK) || isempty(FieldT)
        warning('Nothing to plot: one or more inputs are empty after alignment.');
        return;
    end

    % ---- 1) Base figure: raw signals ----
    figure('Name', 'Decreasing Temperature Segments', 'Position', [100, 100, 1000, 600]);

    % Top: Temperature vs time
    subplot(2,1,1); hold on;
    plot(Timems, TemperatureK, 'r', 'DisplayName', 'Temperature [K]');
    ylabel('Temperature [K]');
    title('Decreasing Temperature Segments');
    legend('show');
    hold off;

    % Bottom: Field vs time
    subplot(2,1,2); hold on;
    plot(Timems, FieldT, 'r', 'DisplayName', 'Field [T]');
    ylabel('Field [T]');
    xlabel('Time [ms]');
    legend('show');
    hold off;

    % ---- 2) Colored segments ----
    if isempty(segments_decreasing_temp)
        return; % no segments to overlay
    end

    segments_decreasing_temp = round(segments_decreasing_temp);

    % drop invalid / inverted / out-of-range
    valid = isfinite(segments_decreasing_temp(:,1)) & isfinite(segments_decreasing_temp(:,2)) & ...
            segments_decreasing_temp(:,1) >= 1 & segments_decreasing_temp(:,2) >= 1 & ...
            segments_decreasing_temp(:,1) <= nCommon & segments_decreasing_temp(:,2) <= nCommon & ...
            segments_decreasing_temp(:,2) >= segments_decreasing_temp(:,1);
    segments_decreasing_temp = segments_decreasing_temp(valid, :);

    if isempty(segments_decreasing_temp)
        return;
    end

    colors = parula(size(segments_decreasing_temp, 1));

    % Overlay on temperature (filtered curve + boundaries)
    subplot(2,1,1); hold on;
    for i = 1:size(segments_decreasing_temp, 1)
        s = segments_decreasing_temp(i, 1);
        e = segments_decreasing_temp(i, 2);
        if s < 1 || e > nCommon || s > e, continue; end

        col = colors(i, :);
        plot(Timems(s:e), filtered_temp(s:e), 'Color', col, 'LineWidth', 2, 'HandleVisibility', 'off');
        xline(Timems(s), '--', 'Color', col, 'HandleVisibility', 'off');
        xline(Timems(e), '--', 'Color', col, 'HandleVisibility', 'off');
    end
    hold off;

    % Overlay on field (boundaries only)
    subplot(2,1,2); hold on;
    for i = 1:size(segments_decreasing_temp, 1)
        s = segments_decreasing_temp(i, 1);
        e = segments_decreasing_temp(i, 2);
        if s < 1 || e > nCommon || s > e, continue; end
        col = colors(i, :);
        xline(Timems(s), '--', 'Color', col, 'HandleVisibility', 'off');
        xline(Timems(e), '--', 'Color', col, 'HandleVisibility', 'off');
    end
    hold off;
end

% ===== helper =====
function segs = clean_and_clip_segments(segs, nMax)
    if isempty(segs), return; end
    segs = round(segs);
    good = all(isfinite(segs),2);
    segs = segs(good,:);
    segs(:,1) = max(1, min(nMax, segs(:,1)));
    segs(:,2) = max(1, min(nMax, segs(:,2)));
    flipMask = segs(:,1) > segs(:,2);
    if any(flipMask), segs(flipMask,:) = fliplr(segs(flipMask,:)); end
    segs = segs(segs(:,2) >= segs(:,1), :);
end
