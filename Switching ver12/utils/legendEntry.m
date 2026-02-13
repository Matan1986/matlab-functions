function lbl = legendEntry(sortedValues, dep_type, i)

switch dep_type
    case 'Field cool'
        lbl = sortedValues{i};
    case 'Configuration'
        angle_deg = sortedValues(i) * 45;
        lbl = "α=" + angle_deg + "°";

    case 'Cooling rate'
        lbl = sprintf('%g[K/min]', sortedValues(i));

    case 'Pulse direction and order'
        lbl = sortedValues{i};

    otherwise
        lbl = sprintf('%.0f', sortedValues(i));
end

end
