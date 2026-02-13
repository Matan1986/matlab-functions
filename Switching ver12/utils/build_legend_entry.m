function entry = build_legend_entry(dep_type, sortedValues, i)
% BUILD_LEGEND_ENTRY create legend string per trace/file

    val = sortedValues(i);

    switch dep_type
        case 'Field cool'
            entry = char(val);   % string like "ZFC_3T_2KtoMin"
        case 'Configuration'
            entry = num2str(val);
        case 'Cooling rate'
            entry = sprintf('%g K/min', val);
        case 'Pulse direction and order'
            if isstring(val) || ischar(val)
                entry = char(val);
            else
                entry = sprintf('%g', val);
            end
        otherwise
            if isnumeric(val)
                entry = sprintf('%.0f', val);
            else
                entry = char(val);
            end
    end
end
