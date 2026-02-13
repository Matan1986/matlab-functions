function [segments_decreasing_temp_cell] = find_decreasing_temperature_segments_MT(Timems, filtered_temp, min_segment_length_decreasing_temp, TL, min_temp_change, min_temp_time_window_change, temp_rate, stabilization_window, delta_T)
    % Initialize a cell array for segments
    segments_decreasing_temp_cell = {};
    in_segment_temp = false;
    segment_start_temp = 0;

    % Identify segments where temperature is decreasing and ends at TL
    for i = 1:length(filtered_temp) - min_temp_time_window_change
        temp_change = filtered_temp(i) - filtered_temp(i + min_temp_time_window_change);
        expected_change = temp_rate * min_temp_time_window_change * (Timems(2) - Timems(1)) * 10^-3 * (1/60); % converting milliseconds to minutes
        if temp_change >= expected_change - min_temp_change
            if ~in_segment_temp
                in_segment_temp = true;
                segment_start_temp = i;
            end
        else
            if in_segment_temp && filtered_temp(i) <= TL + delta_T
                stable = true;
                for j = i + 1:i + stabilization_window
                    if abs(filtered_temp(j) - filtered_temp(i)) > min_temp_change
                        stable = false;
                        break;
                    end
                end
                if stable
                    in_segment_temp = false;
                    if (i - segment_start_temp) >= min_segment_length_decreasing_temp
                        % Append the segment as a row to the cell array
                        segments_decreasing_temp_cell{end + 1, 1} = [segment_start_temp, i]; % Add vertically
                    end
                end
            end
        end
    end

    % Handle the case where the last segment goes till the end
    if in_segment_temp && (length(filtered_temp) - segment_start_temp) >= min_segment_length_decreasing_temp
        segments_decreasing_temp_cell{end + 1, 1} = [segment_start_temp, length(filtered_temp)]; % Add vertically
    end
end
