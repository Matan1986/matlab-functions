function [cleanedTempTable, cleanedHCTable] = cleanDataForCoolingOrHeating(Temp_table, HC_table, sortedFields, temp_jump_threshold, measure_while_cooling)
    % Function to clean the data by trimming points where temperature trend changes.
    % For cooling, it trims after the temperature increases.
    % For heating, it trims after the temperature decreases.

    cleanedTempTable = Temp_table;
    cleanedHCTable = HC_table;

    for i = 1:length(Temp_table)
        temp_data = Temp_table{i};
        hc_data = HC_table{i};

        % Filter out NaN values from temperature and heat capacity data
        valid_idx = ~isnan(temp_data) & ~isnan(hc_data);
        temp_data = temp_data(valid_idx);
        hc_data = hc_data(valid_idx);
        
        if measure_while_cooling
            % For cooling, find where temperature starts increasing
            temp_diff = diff(temp_data);
            idx_jump = find(temp_diff > temp_jump_threshold, 1);  % Find the first point where temperature increases
        else
            % For heating, find where temperature starts decreasing
            temp_diff = diff(temp_data);
            idx_jump = find(temp_diff < -temp_jump_threshold, 1);  % Find the first point where temperature decreases
        end

        if ~isempty(idx_jump)
            % Trim the data after the jump
            cleanedTempTable{i} = temp_data(1:idx_jump);
            cleanedHCTable{i} = hc_data(1:idx_jump);
        else
            % No jump detected, keep the data as is
            cleanedTempTable{i} = temp_data;
            cleanedHCTable{i} = hc_data;
        end
    end
end
