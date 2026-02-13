function [segments_field_max, rounded_unique_field_max_values, rounded_field_max_values_vec] = find_field_segments( ...
    filtered_field, min_field_threshold, min_diff_field_threshold, min_segment_length_field, stabilization_window)

% Ensure the input is a column vector
if isrow(filtered_field)
    filtered_field = filtered_field';
end

% Calculate the first derivative of the field
field_derivative = diff(filtered_field);

% Identify local minima and maxima based on the derivative
min_locs = [];
max_locs = [];

% Find local minima where the field value is close to zero
for i = 2:length(field_derivative)-1
    if (filtered_field(i) <= filtered_field(i-1) && filtered_field(i+1) >= filtered_field(i) ...
            && abs(filtered_field(i)) <= min_field_threshold)
        min_locs = [min_locs; i];
    end
end

% Find local maxima where the field value is greater than min_diff_field_threshold
for i = 2:length(field_derivative)-1
    if field_derivative(i-1) > 0 && field_derivative(i+1) < 0 && abs(filtered_field(i)) > min_diff_field_threshold
        max_locs = [max_locs; i];
    end
end

%{
% Debug plot
% figure; plot(filtered_field,'b-'); hold on;
% plot(min_locs, filtered_field(min_locs), 'go');
% plot(max_locs, filtered_field(max_locs), 'ro');
% title('Filtered Field with Local Minima and Maxima'); grid on;
%}

% Merge maxima that are too close in amplitude (difference < threshold)
merged_max_locs   = [];
merged_max_values = [];
for i = length(max_locs):-1:1
    if isempty(merged_max_values) || abs(filtered_field(max_locs(i)) - merged_max_values(end)) >= min_diff_field_threshold
        merged_max_locs   = [merged_max_locs;   max_locs(i)];
        merged_max_values = [merged_max_values; filtered_field(max_locs(i))];
    else
        % Merge into the previous maximum
        merged_max_locs(end)   = max_locs(i);
        merged_max_values(end) = filtered_field(max_locs(i));
    end
end
merged_max_locs   = flipud(merged_max_locs);
merged_max_values = flipud(merged_max_values);

% Round the maxima values for the output (3 decimals)
rounded_unique_field_max_values = unique(round(merged_max_values, 3));

% ---------- SPECIAL CASE MERGE ----------
% If there is exactly one non-zero rounded unique field value,
% merge all segments and set everything to that value.
tol = 1e-9; % numeric tolerance for "zero"
nonzero_vals = rounded_unique_field_max_values(abs(rounded_unique_field_max_values) > tol);
if numel(nonzero_vals) == 1
    single_val = nonzero_vals(1);
    segments_field_max = [1, length(filtered_field)];
    rounded_unique_field_max_values = single_val;              % single non-zero value
    rounded_field_max_values_vec    = repmat(single_val, length(filtered_field), 1);
    return;
end
% ----------------------------------------

% Initialize segments
segments_field_max = [];

% Create segments starting from the nearest local minimum before each merged maximum
for i = 1:length(merged_max_locs)
    if i == 1
        segment_start = 1; % first segment starts at 1
    else
        % nearest local minimum BEFORE the previous maximum
        prev_min_idx = find(min_locs < merged_max_locs(i-1), 1, 'last');
        if isempty(prev_min_idx)
            segment_start = 1;
        else
            segment_start = min_locs(prev_min_idx);
        end
    end

    % Define the segment end at the local minimum BEFORE the current maximum
    next_max_loc = merged_max_locs(i);
    next_min_idx = find(min_locs < next_max_loc, 1, 'last');
    if isempty(next_min_idx)
        segment_end = length(filtered_field); % if no min before, go to end
    else
        segment_end = min_locs(next_min_idx) - 1; % end just before that minimum
        if segment_end < segment_start
            segment_end = segment_start; % guard
        end
    end

    % Ensure the segment length meets the minimum requirement
    if segment_end - segment_start + 1 >= min_segment_length_field
        segments_field_max = [segments_field_max; segment_start, segment_end];
    end
end

% Add a trailing segment to the end (as in your original code)
if ~isempty(segments_field_max)
    segment_start = segments_field_max(end,2) + 1;
else
    segment_start = 1;
end
segment_end = length(filtered_field);
if segment_start <= segment_end
    segments_field_max = [segments_field_max; segment_start, segment_end];
end

% Adjust the final segment end if it exceeds the length of the filtered_field
if ~isempty(segments_field_max) && segments_field_max(end, 2) > length(filtered_field)
    segments_field_max(end, 2) = length(filtered_field);
end

% Create the field_max_values_vec (your original mapping logic)
field_max_values_vec = zeros(length(filtered_field), 1);
for k = 1:size(segments_field_max, 1)
    ind     = segments_field_max(k, :);
    ind_vec = ind(1):ind(end);

    % Guard if there are more segments than unique values:
    ku = min(k, numel(rounded_unique_field_max_values));
    if ku == 0
        val_k = 0;
    else
        val_k = rounded_unique_field_max_values(ku);
    end

    field_max_values_vec(ind_vec) = val_k;

    % Your original early-exit:
    if size(segments_field_max,1) == 2 && length(rounded_unique_field_max_values) == 1 && k == 1
        break;
    end
end

rounded_field_max_values_vec = field_max_values_vec;


end
