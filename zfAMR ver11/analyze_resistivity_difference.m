function resistivity_diff_tables = analyze_resistivity_difference(resistivity_deviation_percent_tables, temp_values, temp_low, temp_high, resistivity_type)
    num_fields = length(resistivity_deviation_percent_tables);
    resistivity_diff_tables = cell(num_fields, 1);

    % Find the indices for the chosen temperatures
    temp_low_col = find(temp_values == temp_low);
    temp_high_col = find(temp_values == temp_high);

    if isempty(temp_low_col) || isempty(temp_high_col)
        error('Temperature values not found in the data');
    end

    for f = 1:num_fields
        field_table = resistivity_deviation_percent_tables{f};
        Angles = field_table.Angle;
        Indices = field_table.Indices;

        % Calculate the difference for the chosen resistivity type
        resistivity_diff = field_table.(resistivity_type)(:, temp_low_col)-1.5*field_table.(resistivity_type)(:, temp_high_col);

        % Store the results in a new table
        resistivity_diff_tables{f} = table(Angles, Indices, resistivity_diff, 'VariableNames', {'Angle', 'Indices', 'ResistivityDiff'});
    end
end
