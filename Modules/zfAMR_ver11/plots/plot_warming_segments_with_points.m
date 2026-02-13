function plot_warming_segments_with_points(Timems, FieldT, warming_points_table, TemperatureK, unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values)
    % Plot warming segments for each field and angle with points TL, TC1, TC2, TH
    figure('Name', 'Extracted Warming Segments with Points', 'Position', [100, 100, 1000, 600]);

    % Helper for index validation (works for vectors or Nx2 start/end arrays)
    is_valid_idx = @(v) ~isempty(v) && all(isfinite(v(:)) & v(:) == floor(v(:)) & v(:) >= 1 & v(:) <= numel(Timems));

    %--------------------
    % Top: Temperature
    %--------------------
    subplot(2, 1, 1);
    hold on;
    plot(Timems, TemperatureK, 'r', 'DisplayName', 'Temperature');
    ylabel('Temperature [K]');
    title('Extracted Warming Segments with Points');

    % Colors by angle bin
    colormap_warming = parula(length(unique_rounded_smoothed_angle_deg));
    nColors = size(colormap_warming, 1);

    is_first_segment = true;
    for f = 1:length(warming_points_table)
        field_table = warming_points_table{f};
        for j = 1:height(field_table)
            indices = field_table.Indices{j};
            if is_valid_idx(indices)
                angle = field_table.Angle(j);
                bin = floor(angle/15) + 1;          % your original binning
                bin = max(1, min(nColors, bin));    % clamp to valid color row
                color = colormap_warming(bin, :);

                idx = indices(:);
                segment_start = Timems(idx(1));
                segment_end   = Timems(idx(end));

                xline(segment_start, '--', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off');
                xline(segment_end,   '--', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off');
                plot(Timems(idx(1):idx(end)), TemperatureK(idx(1):idx(end)), 'Color', color, 'LineWidth', 2, 'HandleVisibility', 'off');

                % Plot TL/TC1/TC2/TH once with legend labels, then hide in legend
                if is_first_segment
                    if is_valid_idx(field_table.TL(j)),  plot(Timems(field_table.TL(j)),  TemperatureK(field_table.TL(j)),  'bo', 'DisplayName', 'TL');  end
                    if is_valid_idx(field_table.TC1(j)), plot(Timems(field_table.TC1(j)), TemperatureK(field_table.TC1(j)), 'go', 'DisplayName', 'TC1'); end
                    if is_valid_idx(field_table.TC2(j)), plot(Timems(field_table.TC2(j)), TemperatureK(field_table.TC2(j)), 'mo', 'DisplayName', 'TC2'); end % 'mo' per your code
                    if is_valid_idx(field_table.TH(j)),  plot(Timems(field_table.TH(j)),  TemperatureK(field_table.TH(j)),  'ro', 'DisplayName', 'TH');  end
                    is_first_segment = false;
                else
                    if is_valid_idx(field_table.TL(j)),  plot(Timems(field_table.TL(j)),  TemperatureK(field_table.TL(j)),  'bo', 'HandleVisibility', 'off'); end
                    if is_valid_idx(field_table.TC1(j)), plot(Timems(field_table.TC1(j)), TemperatureK(field_table.TC1(j)), 'go', 'HandleVisibility', 'off'); end
                    if is_valid_idx(field_table.TC2(j)), plot(Timems(field_table.TC2(j)), TemperatureK(field_table.TC2(j)), 'mo', 'HandleVisibility', 'off'); end
                    if is_valid_idx(field_table.TH(j)),  plot(Timems(field_table.TH(j)),  TemperatureK(field_table.TH(j)),  'ro', 'HandleVisibility', 'off'); end
                end
            end
        end
    end
    hold off;
    legend('show');

    %--------------------
    % Bottom: Field
    %--------------------
    subplot(2, 1, 2);
    hold on;
    plot(Timems, FieldT, 'r', 'DisplayName', 'Field [T]');
    ylabel('Field [T]');
    xlabel('Time [ms]');
    legend('show');

    for f = 1:length(warming_points_table)
        field_table = warming_points_table{f};
        for j = 1:height(field_table)
            indices = field_table.Indices{j};
            if is_valid_idx(indices)
                angle = field_table.Angle(j);
                bin = floor(angle/15) + 1;
                bin = max(1, min(nColors, bin));
                color = colormap_warming(bin, :);

                idx = indices(:);
                segment_start = Timems(idx(1));
                segment_end   = Timems(idx(end));
                xline(segment_start, '--', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off');
                xline(segment_end,   '--', 'Color', color, 'LineWidth', 1, 'HandleVisibility', 'off');
            end
        end
    end
    hold off;
end
