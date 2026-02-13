function [segments_angle, rounded_smoothed_angle_deg, unique_rounded_smoothed_angle_deg] = find_angle_segments(delta_Angle, angle_threshold, filtered_angle, min_segment_length_angle)
    %% Divide by angle


    % Round the filtered angles to the nearest delta_Angle
    rounded_smoothed_angle_deg = round(filtered_angle / delta_Angle) * delta_Angle;

    % Find unique rounded angles
    unique_rounded_smoothed_angle_deg = unique(rounded_smoothed_angle_deg);

    % Initialize segments
    segments_angle = [];
    in_segment_angle = false;
    segment_start_angle = 0;

    % Identify segments where angle is roughly constant
    for i = 1:length(rounded_smoothed_angle_deg) - 1
        if abs(rounded_smoothed_angle_deg(i+1) - rounded_smoothed_angle_deg(i)) <= angle_threshold
            if ~in_segment_angle
                in_segment_angle = true;
                segment_start_angle = i;
            end
        else
            if in_segment_angle
                in_segment_angle = false;
                if (i - segment_start_angle) >= min_segment_length_angle
                    segments_angle = [segments_angle; segment_start_angle, i];
                end
            end
        end
    end

    % Handle the case where the last segment goes till the end
    if in_segment_angle && (length(rounded_smoothed_angle_deg) - segment_start_angle) >= min_segment_length_angle
        segments_angle = [segments_angle; segment_start_angle, length(rounded_smoothed_angle_deg)];
    end
end
