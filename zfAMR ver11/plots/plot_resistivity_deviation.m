function plot_zfAMR(resistivity_deviation_percent_tables, angles, fields,temp_index, temp_label,temp_val,Normalize_to,Rxx3_all_zeros)
% Determine color map
num_fields = length(resistivity_deviation_percent_tables);
colors = parula(max(num_fields, 64)); % Use full colormap even for fewer graphs
color_indices = round(linspace(1, size(colors, 1), num_fields)); % Distribute colors more evenly
% Plot deviation percentages for each resistivity component
if(~Rxx3_all_zeros)
    resistivity_components = {'Rxy1', 'Rxx2', 'Rxx3'};
    resistivity_components_str = {'R_{xy1}', 'R_{xx2}', 'R_{xx3}'};
elseif(Rxx3_all_zeros)
    resistivity_components = {'Rxy1', 'Rxx2'};
    resistivity_components_str = {'R_{xy1}', 'R_{xx2}'};
end
devide_resistivity_component_str=resistivity_components_str{Normalize_to};
for i = 1:length(resistivity_components)
    resistivity_component = resistivity_components{i};
    resistivity_component_str=resistivity_components_str{i};
    figure('Name', [resistivity_component ' zfAMR at ' num2str(temp_val) 'K'], 'Position', [100, 100, 1000, 600]);
    hold on;
    for f = 1:length(resistivity_deviation_percent_tables)
        field_table = resistivity_deviation_percent_tables{f};
        angles_field = field_table.Angle;
        deviation_values = field_table.(resistivity_component);
        plot(angles_field, deviation_values(:, temp_index),'-o', 'DisplayName', [num2str(fields(f)) ' T'],'Color', colors(color_indices(f), :));
    end
    hold off;
    title(['zfAMR \Delta' resistivity_component_str '/<' devide_resistivity_component_str '> [%] at '  num2str(temp_val) 'K'],'FontSize', 14 );
    xlabel('Angle ^0', 'FontSize', 12);
    ylabel(['\Delta' resistivity_component_str '/<' devide_resistivity_component_str '> [%]'], 'FontSize', 12);
    legend('show');
    grid on;
end
end