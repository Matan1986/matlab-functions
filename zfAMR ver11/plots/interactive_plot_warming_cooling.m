function interactive_plot_warming_cooling(resistivity_warming_tables, resistivity_cooling_tables, unique_angles, rounded_field_values)
    % Select angles
    selected_angles = select_angles(unique_angles);

    if isempty(selected_angles)
        return;
    end

    % Determine color map
    colors_warming = [1 0 0]; % Red for warming
    colors_cooling = [0 0 1]; % Blue for cooling

    % Plot warming and cooling for each selected angle
    for f = 1:length(resistivity_warming_tables)
        % Extract the current field table for warming and cooling
        field_table_warming = resistivity_warming_tables{f};
        field_table_cooling = resistivity_cooling_tables{f};

        for a = 1:length(selected_angles)
            angle = selected_angles(a);

            % Find the index for the selected angle
            angle_index_warming = find(field_table_warming.Angle == angle, 1);
            angle_index_cooling = find(field_table_cooling.Angle == angle, 1);

            if isempty(angle_index_warming) || isempty(angle_index_cooling)
                continue; % Skip if there is no data for this angle
            end

            % Extract the indices for the current angle from warming and cooling tables
            warming_temperature = field_table_warming.Temperature{angle_index_warming};
            warming_rxy1 = field_table_warming.Rxy1{angle_index_warming};
            warming_rxx2 = field_table_warming.Rxx2{angle_index_warming};

            cooling_temperature = field_table_cooling.Temperature{angle_index_cooling};
            cooling_rxy1 = field_table_cooling.Rxy1{angle_index_cooling};
            cooling_rxx2 = field_table_cooling.Rxx2{angle_index_cooling};

            % Plot Rxy1 warming and cooling for the selected angle
            figure('Name', ['Rxy1 Warming and Cooling at B = ', num2str(rounded_field_values(f)), ' [T], Angle = ', num2str(angle), '^{0}']);
            hold on;
            grid on;

            % Plot warming segments
            plot(warming_temperature, warming_rxy1, 'Color', colors_warming, 'LineWidth', 1, 'DisplayName', [num2str(angle) '^{0} Warming']);

            % Plot cooling segments
            plot(cooling_temperature, cooling_rxy1, 'Color', colors_cooling, 'LineWidth', 1, 'DisplayName', [num2str(angle) '^{0} Cooling']);

            title(['R_{xy1} Warming and Cooling at B = ', num2str(rounded_field_values(f)), ' [T], Angle = ', num2str(angle), '^{0}'], 'FontSize', 14);
            xlabel('Temperature [K]', 'FontSize', 12);
            ylabel('R_{xy1} [10^{-6} \Omega \cdot cm]', 'FontSize', 12);
            legend('show');
            hold off;

            % Plot Rxx2 warming and cooling for the selected angle
            figure('Name', ['Rxx2 Warming and Cooling at B = ', num2str(rounded_field_values(f)), ' [T], Angle = ', num2str(angle), '^{0}']);
            hold on;
            grid on;

            % Plot warming segments
            plot(warming_temperature, warming_rxx2, 'Color', colors_warming, 'LineWidth', 1, 'DisplayName', [num2str(angle) '^{0} Warming']);

            % Plot cooling segments
            plot(cooling_temperature, cooling_rxx2, 'Color', colors_cooling, 'LineWidth', 1, 'DisplayName', [num2str(angle) '^{0} Cooling']);

            title(['R_{xx2} Warming and Cooling at B = ', num2str(rounded_field_values(f)), ' [T], Angle = ', num2str(angle), '^{0}'], 'FontSize', 14);
            xlabel('Temperature [K]', 'FontSize', 12);
            ylabel('R_{xx2} [10^{-6} \Omega \cdot cm]', 'FontSize', 12);
            legend('show');
            hold off;
        end
    end
end

function selected_angles = select_angles(unique_angles)
    % Display a dialog box for selecting angles
    [selection, ok] = listdlg('ListString', string(unique_angles) + "^{0}", ...
                              'SelectionMode', 'multiple', ...
                              'ListSize', [300, 300], ...
                              'PromptString', 'Select angles:', ...
                              'Name', 'Select Angles', ...
                              'OKString', 'Plot', ...
                              'CancelString', 'Cancel');
    if ok
        selected_angles = unique_angles(selection);
    else
        selected_angles = [];
        disp('No angles selected.');
    end
end
