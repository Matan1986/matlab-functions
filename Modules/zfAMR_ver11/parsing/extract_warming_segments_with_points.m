function warming_points_table = extract_warming_segments_with_points( ...
    Timems, warming_tables, TemperatureK, unique_rounded_smoothed_angle_deg, temp_values, delta_T)
% extract_warming_segments_with_points  
%   Builds tables of time‐indices at each requested temperature for each angle.
%   temp_values may be any length; columns T1, T2, …, TN will be created.

    warming_points_table = cell(size(warming_tables));
    numTemps   = numel(temp_values);
    % Generate column names T1, T2, …, TN
    tempLabels = arrayfun(@(k) sprintf('T%d',k), 1:numTemps, 'UniformOutput', false);

    for i = 1:numel(warming_tables)
        table      = warming_tables{i};
        angles     = table.Angle;
        new_table  = table;
        % Initialize one column per requested temperature
        for t = 1:numTemps
            new_table.(tempLabels{t}) = nan(size(table,1),1);
        end

        for j = 1:numel(angles)
            angle = angles(j);
            row   = table(table.Angle == angle, :);
            indices = row.Indices{1};

            if ~isempty(indices)
                idxVec = indices(1) : indices(end);
                % For each temperature, find the closest timestamp index
                for t = 1:numTemps
                    [~, idxClosest] = min(abs(TemperatureK(idxVec) - temp_values(t)));
                    new_table.(tempLabels{t})(j) = idxVec(idxClosest);
                end
            else
                % no data for this angle → leave NaNs
                for t = 1:numTemps
                    new_table.(tempLabels{t})(j) = NaN;
                end
            end
        end

        warming_points_table{i} = new_table;
    end
end
