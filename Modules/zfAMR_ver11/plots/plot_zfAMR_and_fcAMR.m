function plot_zfAMR_and_fcAMR(temp_values_to_plot_zfAMR, resistivity_warming_deviation_percent_tables, unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, temp_labels, temp_values, Normalize_to, Rxx3_all_zeros, excluded_fields, plan_measured_str, polar_plots, temp_values_to_plot_fcAMR, resistivity_cooling_deviation_percent_tables)
% Plot zfAMR for warming points tables
for temp_index = 1:length(temp_values_to_plot_zfAMR)
    plot_zfAMR(resistivity_warming_deviation_percent_tables, unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, temp_index, temp_labels{temp_index}, temp_values(temp_index), Normalize_to, Rxx3_all_zeros, excluded_fields, plan_measured_str);
end
if polar_plots
    for temp_index = 1:length(temp_values_to_plot_zfAMR)
        plot_zfAMR_polar(resistivity_warming_deviation_percent_tables, unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, temp_index, temp_labels{temp_index}, temp_values(temp_index), Normalize_to, Rxx3_all_zeros, excluded_fields, plan_measured_str);
    end
end

% Plot fcAMR for cooling points tables
for temp_index = 1:length(temp_values_to_plot_fcAMR)
    plot_fcAMR(resistivity_cooling_deviation_percent_tables, unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, temp_index, temp_labels{temp_index}, temp_values(temp_index), Normalize_to, Rxx3_all_zeros, excluded_fields, plan_measured_str);
end
if polar_plots
    for temp_index = 1:length(temp_values_to_plot_fcAMR)
        plot_fcAMR_polar(resistivity_cooling_deviation_percent_tables, unique_rounded_smoothed_angle_deg, rounded_unique_field_max_values, temp_index, temp_labels{temp_index}, temp_values(temp_index), Normalize_to, Rxx3_all_zeros, excluded_fields, plan_measured_str);
    end
end
end
