function warming_tables = extract_warming_segments( ...
    segments_angle, rounded_smoothed_angle_deg, unique_rounded_smoothed_angle_deg, ...
    segments_increasing_temp, segments_decreasing_temp, ...
    segments_field_max, rounded_unique_field_max_values, smoothed_field) %#ok<INUSD>

    % ---- linear rounding only (no modulo) ----
    ROUND_DISPLAY_DIGITS = 1;
    keyround = @(x) round(x, ROUND_DISPLAY_DIGITS);

    % ----- Label each angle segment by its dominant rounded angle -----
    N      = numel(rounded_smoothed_angle_deg);
    nSegA  = size(segments_angle,1);
    seg_angle_value = nan(nSegA,1);

    for r = 1:nSegA
        s = max(1, min(N, segments_angle(r,1)));
        e = max(1, min(N, segments_angle(r,2)));
        if s <= e
            v = mode(rounded_smoothed_angle_deg(s:e));
            if ~isnan(v)
                seg_angle_value(r) = keyround(v);
            end
        end
    end

    % Use linear, scan-derived keys
    uniq_angles = unique(keyround(unique_rounded_smoothed_angle_deg(:)));

    % Prepare output cell (one table per field)
    nFields = numel(rounded_unique_field_max_values);
    warming_tables = cell(nFields, 1);

    % ---- find first cooling start (FC reference) ----
    if isempty(segments_decreasing_temp)
        firstCoolStart = NaN;
    else
        firstCoolStart = min(segments_decreasing_temp(:,1));
    end

    % ---- no field segmentation case: treat as single field ----
    if isempty(segments_field_max)
        segments_field_max = [1 N];
    end

    % ---- build warming tables ----
    for f = 1:nFields
        ff = min(f, size(segments_field_max,1));
        field_seg = segments_field_max(ff,:);

        % Warming segments overlapping this field segment
        if isempty(segments_increasing_temp)
            warmF = zeros(0,2);
        else
            warmF = segments_increasing_temp( ...
                segments_increasing_temp(:,2) >= field_seg(1) & ...
                segments_increasing_temp(:,1) <= field_seg(2), :);
        end

        Indices = cell(numel(uniq_angles), 1);

        for a = 1:numel(uniq_angles)
            A = uniq_angles(a);
            rowsA = find(seg_angle_value == A);

            if isempty(rowsA)
                Indices{a} = zeros(0,2);
                continue;
            end

            blocks = zeros(0,2);

            for rr = rowsA(:).'
                ang_seg = segments_angle(rr,:);

                % intersect (angle ∩ field)
                s1 = max(ang_seg(1), field_seg(1));
                e1 = min(ang_seg(2), field_seg(2));
                if s1 > e1, continue; end

                % intersect with warming
                cand = warmF(warmF(:,2) >= s1 & warmF(:,1) <= e1, :);
                for k = 1:size(cand,1)
                    s = max(cand(k,1), s1);
                    e = min(cand(k,2), e1);
                    if s <= e
                        blocks = [blocks; s e]; %#ok<AGROW>
                    end
                end
            end

            % merge adjacent warming blocks
            idx = merge_adjacent_blocks(blocks);

            % ---- DROP initial warm-up (before first FC) ----
            if ~isnan(firstCoolStart) && ~isempty(idx)
                idx = idx(idx(:,2) >= firstCoolStart, :);
            end

            Indices{a} = idx;
        end

        warming_tables{f} = table( ...
            uniq_angles, Indices, ...
            'VariableNames', {'Angle','Indices'} );
    end
end

% =========================================================
% Helper: merge adjacent [start end] blocks
% =========================================================
function out = merge_adjacent_blocks(blocks)
    if isempty(blocks)
        out = zeros(0,2);
        return;
    end
    blocks = sortrows(blocks,1);
    out = blocks(1,:);
    for i = 2:size(blocks,1)
        prev = out(end,:);
        cur  = blocks(i,:);
        if cur(1) <= prev(2) + 1
            out(end,2) = max(prev(2), cur(2));
        else
            out = [out; cur]; %#ok<AGROW>
        end
    end
end
