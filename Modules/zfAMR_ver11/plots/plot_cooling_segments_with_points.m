function plot_cooling_segments_with_points(Timems, FieldT, cooling_points_table, TemperatureK, unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values)
    % Plot cooling segments for each field and angle with points TL, TC1, TC2, TH
    figure('Name', 'Extracted Cooling Segments with Points', 'Position', [100, 100, 1000, 600]);

    % Plot the temperature
    subplot(2, 1, 1);
    hold on;
    plot(Timems, TemperatureK, 'r', 'DisplayName', 'Temperature');
    ylabel('Temperature [K]');
    title('Extracted Cooling Segments with Points');

    % Add vertical lines for segments and overlay temperature segments with parula colors
    colormap_cooling = parula(length(unique_rounded_smoothed_angle_deg));
    is_first_segment = true;
    for f = 1:length(cooling_points_table)
        field_table = cooling_points_table{f};
        for j = 1:height(field_table)
            indices = field_table.Indices{j};
            if ~isempty(indices) && all(indices > 0 & indices <= length(Timems)) % Ensure indices are valid
                angle = field_table.Angle(j);
                segment_start = Timems(indices(1));
                segment_end = Timems(indices(end));
                color = colormap_cooling(floor(angle/15) + 1, :);
                xline(segment_start, '--', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off');
                xline(segment_end, '--', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off');
                plot(Timems(indices(1):indices(end)), TemperatureK(indices(1):indices(end)), 'Color', color, 'LineWidth', 2, 'HandleVisibility', 'off');
                
                % Plot points TL, TC1, TC2, TH only for the first segment
                if is_first_segment
                    plot(Timems(field_table.TL(j)), TemperatureK(field_table.TL(j)), 'bo', 'DisplayName', 'TL');
                    plot(Timems(field_table.TC1(j)), TemperatureK(field_table.TC1(j)), 'go', 'DisplayName', 'TC1');
                    plot(Timems(field_table.TC2(j)), TemperatureK(field_table.TC2(j)), 'mo', 'DisplayName', 'TC2'); % Change to orange
                    plot(Timems(field_table.TH(j)), TemperatureK(field_table.TH(j)), 'ro', 'DisplayName', 'TH');
                    is_first_segment = false;
                else
                    plot(Timems(field_table.TL(j)), TemperatureK(field_table.TL(j)), 'bo', 'HandleVisibility', 'off');
                    plot(Timems(field_table.TC1(j)), TemperatureK(field_table.TC1(j)), 'go', 'HandleVisibility', 'off');
                    plot(Timems(field_table.TC2(j)), TemperatureK(field_table.TC2(j)), 'mo', 'HandleVisibility', 'off'); % Change to orange
                    plot(Timems(field_table.TH(j)), TemperatureK(field_table.TH(j)), 'ro', 'HandleVisibility', 'off');
                end
            end
        end
    end
    hold off;
    legend('show');

    % Plot the field
    subplot(2, 1, 2);
    hold on;
    plot(Timems, FieldT, 'r', 'DisplayName', 'Field [T]');
    ylabel('Field [T]');
    xlabel('Time [ms]');
    legend('show');

    % Add vertical lines for segments
    for f = 1:length(cooling_points_table)
        field_table = cooling_points_table{f};
        for j = 1:height(field_table)
            indices = field_table.Indices{j};
            if ~isempty(indices) && all(indices > 0 & indices <= length(Timems)) % Ensure indices are valid
                angle = field_table.Angle(j);
                segment_start = Timems(indices(1));
                segment_end = Timems(indices(end));
                color = colormap_cooling(floor(angle/15) + 1, :);
                xline(segment_start, '--', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off');
                xline(segment_end, '--', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off');
            end
        end
    end
    hold off;
end
