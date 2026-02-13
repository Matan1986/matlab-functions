function cooling_tables = extract_cooling_segments( ...
    segments_angle, rounded_smoothed_angle_deg, unique_rounded_smoothed_angle_deg, ...
    segments_decreasing_temp, segments_field_max, rounded_unique_field_max_values, smoothed_field) %#ok<INUSD>

    % ---- linear rounding only (no modulo/wrap) ----
    ROUND_DISPLAY_DIGITS = 1;
    keyround = @(x) round(x, ROUND_DISPLAY_DIGITS);

    % ----- Label each angle segment by its dominant rounded angle (linear) -----
    N      = numel(rounded_smoothed_angle_deg);
    nSegA  = size(segments_angle,1);
    seg_angle_value = nan(nSegA,1);

    for r = 1:nSegA
        s = max(1, min(N, segments_angle(r,1)));
        e = max(1, min(N, segments_angle(r,2)));
        if s <= e
            seg_vals = rounded_smoothed_angle_deg(s:e);
            if ~isempty(seg_vals)
                v = mode(seg_vals);
                if ~isnan(v)
                    seg_angle_value(r) = keyround(v);  % linear, no wrap
                end
            end
        end
    end

    % Use linear, scan-derived keys
    uniq_angles = unique(keyround(unique_rounded_smoothed_angle_deg(:)));

    % Prepare output cell (one table per field)
    nFields = numel(rounded_unique_field_max_values);
    cooling_tables = cell(nFields, 1);

    % Defensive: if no field segments, still return empty tables with angle keys
    if isempty(segments_field_max)
        for f = 1:nFields
            cooling_tables{f} = table(uniq_angles, repmat({zeros(0,2)}, numel(uniq_angles),1), ...
                                      'VariableNames', {'Angle','Indices'});
        end
        return;
    end

    % Defensive for cooling segments
    if isempty(segments_decreasing_temp)
        segments_decreasing_temp = zeros(0,2);
    end

    for f = 1:nFields
        % Clamp field index (if values > rows)
        ff = min(max(1,f), size(segments_field_max,1));
        field_seg = segments_field_max(ff,:);

        % Cooling segments overlapping this field segment
        coolF = segments_decreasing_temp( ...
            segments_decreasing_temp(:,2) >= field_seg(1) & ...
            segments_decreasing_temp(:,1) <= field_seg(2), :);

        Indices = cell(numel(uniq_angles), 1);

        for a = 1:numel(uniq_angles)
            A = uniq_angles(a);

            % angle-segment rows whose dominant angle equals A
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

                % intersect with each cooling segment that overlaps [s1 e1]
                if ~isempty(coolF)
                    cand = coolF(coolF(:,2) >= s1 & coolF(:,1) <= e1, :);
                    for k = 1:size(cand,1)
                        s = max(cand(k,1), s1);
                        e = min(cand(k,2), e1);
                        if s <= e
                            blocks = [blocks; s e]; %#ok<AGROW>
                        end
                    end
                end
            end

            % Merge touching/overlapping blocks (don’t bridge real gaps)
            Indices{a} = merge_adjacent_blocks(blocks);
        end

        cooling_tables{f} = table(uniq_angles, Indices, ...
                                  'VariableNames', {'Angle','Indices'});
    end
end

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
        if cur(1) <= prev(2) + 1   % touch or overlap
            out(end,2) = max(prev(2), cur(2));
        else
            out = [out; cur]; %#ok<AGROW>
        end
    end
end
