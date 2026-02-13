function [segments_increasing_temp] = find_increasing_temperature_segments(Timems, filtered_temp, min_segment_length_increasing_temp, TH, min_temp_change, min_temp_time_window_change, temp_rate, stabilization_window, delta_T)
    % Initialize segments
    segments_increasing_temp = [];
    in_segment_temp = false;
    segment_start_temp = 0;

    % Identify segments where temperature is increasing and ends at TH
    for i = 1:length(filtered_temp) - min_temp_time_window_change
        temp_change = filtered_temp(i + min_temp_time_window_change) - filtered_temp(i);
        expected_change = temp_rate * min_temp_time_window_change * (Timems(2) - Timems(1)) * 10^-3 * (1/60); % converting the millisec to minutes
        if temp_change >= expected_change - min_temp_change
            if ~in_segment_temp
                in_segment_temp = true;
                segment_start_temp = i;
            end
        else
            if in_segment_temp && filtered_temp(i) >= TH - delta_T
                stable = true;
                for j = i + 1:i + stabilization_window
                    if abs(filtered_temp(j) - filtered_temp(i)) > min_temp_change
                        stable = false;
                        break;
                    end
                end
                if stable
                    in_segment_temp = false;
                    if (i - segment_start_temp) >= min_segment_length_increasing_temp
                        segments_increasing_temp = [segments_increasing_temp; segment_start_temp, i];
                    end
                end
            end
        end
    end

    % Handle the case where the last segment goes till the end
    if in_segment_temp && (length(filtered_temp) - segment_start_temp) >= min_segment_length_increasing_temp
        segments_increasing_temp = [segments_increasing_temp; segment_start_temp, length(filtered_temp)];
    end
end
