function plot_resistivity_diff...
    (resistivity_diff_tables, unique_rounded_smoothed_angle_deg, fields, temp_low, temp_high, resistivity_type, plan_measured_str,meas_type,devide_resistivity_component,Rxx3_all_zeros)

if(~Rxx3_all_zeros)
    resistivity_components = {'Rxy1', 'Rxx2', 'Rxx3'};
    resistivity_components_str = {'R_{xy1}', 'R_{xx2}', 'R_{xx3}'};
elseif(Rxx3_all_zeros)
    resistivity_components = {'Rxy1', 'Rxx2'};
    resistivity_components_str = {'R_{xy1}', 'R_{xx2}'};
end
devide_resistivity_component_str = resistivity_components_str{devide_resistivity_component};

switch(resistivity_type)
    case 'Rxy1'
        resistivity_component_str=resistivity_components_str{1};
    case 'Rxx2'
        resistivity_component_str=resistivity_components_str{2};
    case 'Rxx3'
        resistivity_component_str=resistivity_components_str{3};
end

figure('Name', sprintf('%s %s %s Polar difference', plan_measured_str, resistivity_type, meas_type), 'Position', [100, 100, 1000, 600]);
polarAxes = polaraxes; % Create a dedicated polar axes
hold on;

colors = parula(length(resistivity_diff_tables)); % Use parula colormap for consistency
color_indices = round(linspace(1, size(colors, 1), length(resistivity_diff_tables))); % Distribute colors evenly

for f = 1:length(resistivity_diff_tables)
    field_table = resistivity_diff_tables{f};
    angles = field_table.Angle;
    resistivity_diff = field_table.ResistivityDiff;
    % plot(angles, resistivity_diff, '-o', 'DisplayName', sprintf('%d T', fields(f)), 'Color', colors(color_indices(f), :));
    polarplot(polarAxes, deg2rad(angles), abs(resistivity_diff), '-o', 'DisplayName', [num2str(fields(f)) ' T'], 'Color', colors(color_indices(f), :));
end

hold off;
title(sprintf('%s %s Polar (%s(%dK)-%s(%dK)) /< %s > [%%]', plan_measured_str, meas_type, resistivity_component_str,temp_low, resistivity_component_str,temp_high,devide_resistivity_component_str), 'FontSize', 14);
% xlabel('Angle ^0', 'FontSize', 12);
% ylabel(sprintf('(%s(%dK)-%s(%dK)) /< %s > [%%]', resistivity_component_str,temp_low, resistivity_component_str,temp_high,devide_resistivity_component_str), 'FontSize', 12);
lgd = legend('show');
lgd.Position = [0.775, 0.80, 0.1, 0.1]; % Adjust the values as needed
grid on;
end
