function plot_founded_angle_segments(Timems, TemperatureK, FieldT, ...
    segments_angle, rounded_smoothed_angle_deg, unique_rounded_smoothed_angle_deg, ...
    max_angle)

    % ==== 0) Robust alignment (trim to common length) ====
    Timems   = Timems(:);
    TemperatureK = TemperatureK(:);
    FieldT   = FieldT(:);
    rounded_smoothed_angle_deg = rounded_smoothed_angle_deg(:);

    nCommon = min([numel(Timems), numel(TemperatureK), numel(FieldT), numel(rounded_smoothed_angle_deg)]);
    if any([numel(Timems), numel(TemperatureK), numel(FieldT), numel(rounded_smoothed_angle_deg)] ~= nCommon)
        Timems   = Timems(1:nCommon);
        TemperatureK = TemperatureK(1:nCommon);
        FieldT   = FieldT(1:nCommon);
        rounded_smoothed_angle_deg = rounded_smoothed_angle_deg(1:nCommon);
        segments_angle = clean_and_clip_segments(segments_angle, nCommon);
    end

    % ==== 1) Angle keys and color mapping (LITERAL, not modulo) ====
    ROUND_DISPLAY_DIGITS = 1;
    keyround = @(x) round(x, ROUND_DISPLAY_DIGITS);

    if ~isempty(unique_rounded_smoothed_angle_deg)
        angle_keys_lit = unique(keyround(unique_rounded_smoothed_angle_deg(:)));
    else
        angle_keys_lit = unique(keyround(rounded_smoothed_angle_deg(:)));
    end
    angle_keys_lit = sort(angle_keys_lit(:).');
    cmap_angle = parula(max(1, numel(angle_keys_lit)));

    function c = color_for_angle_literal(a_lit)
        if isempty(angle_keys_lit), c = [0 0 0]; return; end
        a_lit = keyround(a_lit);
        [tf, idx] = ismember(a_lit, angle_keys_lit);
        if ~tf, [~, idx] = min(abs(angle_keys_lit - a_lit)); end
        c = cmap_angle(idx, :);
    end

    % Segment mode (literal; may be exactly max_angle)
    function ang = seg_mode(s,e)
        if ~(isfinite(s) && isfinite(e) && s<=e && s>=1 && e<=nCommon), ang = NaN; return; end
        seg_vals = rounded_smoothed_angle_deg(s:e);
        if isempty(seg_vals), ang = NaN; return; end
        ang = keyround(mode(seg_vals));
    end

    % ==== 2) Detect sweep starts from the raw angle series ====
    % sweep start when previous sample is max_angle and current is 0
    sweep_start_idx = find( ...
        rounded_smoothed_angle_deg(2:end) == 0 & ...
        rounded_smoothed_angle_deg(1:end-1) == keyround(max_angle) ) + 1;

    % For quick membership checks:
    is_sweep_start_sample = false(size(rounded_smoothed_angle_deg));
    is_sweep_start_sample(sweep_start_idx) = true;

    % Label thinning (keep 1 to show every change)
    label_every = 1;

    figure('Name', 'Angle Segments', 'Position', [100, 100, 1000, 600]);

    % -------- Temperature subplot --------
    subplot(2,1,1); hold on;
    plot(Timems, TemperatureK, 'r', 'DisplayName', 'Temperature [K]');
    ylabel('Temperature [K]'); title('Angle Segments'); legend('show');

    yl = ylim;
    text_y = yl(2) - 0.02*(yl(2)-yl(1));
    nSeg = size(segments_angle, 1);

    last_ang_lit = NaN;  label_counter = 0;

    for i = 1:nSeg
        s = segments_angle(i, 1); e = segments_angle(i, 2);
        ang_mode_lit = seg_mode(s,e); if isnan(ang_mode_lit), continue; end
        col = color_for_angle_literal(ang_mode_lit);

        % Only the START line → less clutter
        xline(Timems(s), '--', 'Color', col, 'LineWidth', 1.2, 'HandleVisibility', 'off');

        % Decide if we must label this segment:
        % (a) angle changed, OR
        % (b) this segment *contains* a sweep start at its first sample and the mode is 0
        is_change = isnan(last_ang_lit) || abs(ang_mode_lit - last_ang_lit) >= 1e-9;
        is_segment_sweep_start = (ang_mode_lit == 0) && is_sweep_start_sample(s);

        if is_change || is_segment_sweep_start
            label_counter = label_counter + 1;

            % Place the label:
            if is_segment_sweep_start
                % Force the label exactly at the sweep start time (right edge of previous sweep)
                tx = Timems(s) + 0.001*(Timems(end)-Timems(1)); % tiny shift to avoid overlap
            else
                % Normal case: center of the segment
                tx = Timems(floor((s+e)/2));
            end

            if mod(label_counter, label_every) == 0
                text(tx, text_y, num2str(ang_mode_lit), ...
                    'HorizontalAlignment','center','VerticalAlignment','bottom', ...
                    'Color', col, 'FontSize', 8, 'Clipping', 'on');
            end
            last_ang_lit = ang_mode_lit;
        end
    end
    hold off;

    % -------- Field subplot --------
    subplot(2,1,2); hold on;
    plot(Timems, FieldT, 'r', 'DisplayName', 'Field [T]');
    ylabel('Field [T]'); xlabel('Time [ms]'); legend('show');

    last_ang_lit = NaN;
    for i = 1:nSeg
        s = segments_angle(i, 1); e = segments_angle(i, 2);
        ang_mode_lit = seg_mode(s,e); if isnan(ang_mode_lit), continue; end
        col = color_for_angle_literal(ang_mode_lit);

        % Only START lines; mark on change OR on sweep start
        is_change = isnan(last_ang_lit) || abs(ang_mode_lit - last_ang_lit) >= 1e-9;
        is_segment_sweep_start = (ang_mode_lit == 0) && is_sweep_start_sample(s);

        if is_change || is_segment_sweep_start
            xline(Timems(s), '--', 'Color', col, 'LineWidth', 1.2, 'HandleVisibility', 'off');
            last_ang_lit = ang_mode_lit;
        end
    end
    hold off;
end

% ===== helper =====
function segs = clean_and_clip_segments(segs, nMax)
    if isempty(segs), return; end
    segs = segs(isfinite(segs(:,1)) & isfinite(segs(:,2)), :);
    segs(:,1) = max(1, min(nMax, segs(:,1)));
    segs(:,2) = max(1, min(nMax, segs(:,2)));
    swapMask = segs(:,1) > segs(:,2);
    if any(swapMask), segs(swapMask,:) = fliplr(segs(swapMask,:)); end
    keep = segs(:,2) >= segs(:,1);
    segs = segs(keep,:);
end
