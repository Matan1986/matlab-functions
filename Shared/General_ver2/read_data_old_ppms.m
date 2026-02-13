% Function to read data from a text or .dat file and extract columns into variables
function [Timems, FieldT, TemperatureK, Angledeg, LI5_XV, LI5_theta, LI6_XV, LI6_theta] = read_data_old_ppms(filename)
    data = readtable(filename, 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
    Timems = data{:, 'Time (ms)'};
    FieldT = data{:, 'Field (T)'};
    TemperatureK = data{:, 'Temperature (K)'};
    Angledeg = data{:, 'Angle (deg)'};
    LI5_XV = data{:, 'LI5_X (V)'};
    LI5_theta = data{:, 'LI5_theta (deg)'};
    LI6_XV = data{:, 'LI6_X (V)'};
    LI6_theta = data{:, 'LI6_theta (deg)'};
end