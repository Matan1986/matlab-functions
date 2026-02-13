function [xlabelStr, convUnits] = resolve_x_label_and_units(dep_type, A)
% helper for x-label and unit conversion

    convUnits = 1;
    switch dep_type
        case 'Amplitude'
            xlabelStr = 'Current [10^{4} A cm^{-2}]';
            convUnits = 1/A * 10^-4 * 10^-3 * 10^-4;
        case 'Width'
            xlabelStr = 'Pulse time [ms]';
            convUnits = 1e3;
        case 'Temperature'
            xlabelStr = 'Temperature [K]';
        case 'Field'
            xlabelStr = 'Field [T]';
        case 'Field cool'
            xlabelStr = 'FC conditions';
        case 'Configuration'
            xlabelStr = 'Configuration';
        case 'Cooling rate'
            xlabelStr = 'Cooling rate [K/min]';
        case 'Pulse direction and order'
            xlabelStr = 'Bars and pulse direction';
        otherwise
            xlabelStr = dep_type;
    end
end
