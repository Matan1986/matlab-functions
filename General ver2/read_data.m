% Function to read data from a text or .dat file and extract columns into variables
function [Timems, FieldT, TemperatureK, Angledeg, LI1_XV, LI1_theta, LI2_XV, LI2_theta, LI3_XV, LI3_theta, LI4_XV, LI4_theta] = read_data(filename)
    explicitValidateGeneralDataFile(filename);
    data = readtable(filename, 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
    Timems = data{:, 'Time (ms)'};
    FieldT = data{:, 'Field (T)'};
    TemperatureK = data{:, 'Temperature (K)'};
    Angledeg = data{:, 'Angle (deg)'};
    LI1_XV = data{:, 'LI1_X (V)'};
    LI1_theta = data{:, 'LI1_theta (deg)'};
    LI2_XV = data{:, 'LI2_X (V)'};
    LI2_theta = data{:, 'LI2_theta (deg)'};
    LI3_XV = data{:, 'LI3_X (V)'};
    LI3_theta = data{:, 'LI3_theta (deg)'};
    LI4_XV = data{:, 'LI4_X (V)'};
    LI4_theta = data{:, 'LI4_theta (deg)'};
end

function explicitValidateGeneralDataFile(filename)
if exist(filename, 'file') ~= 2
    error('read_data:MissingFile', 'Data file not found: %s', filename);
end

txt = fileread(filename);
lines = regexp(txt, '\r\n|\n|\r', 'split');
if isempty(lines) || strlength(strtrim(string(lines{1}))) == 0
    error('read_data:InvalidHeader', 'Data file must include a tab-delimited header row.');
end

headerCols = strtrim(split(string(lines{1}), sprintf('\t')));
required = ["Time (ms)","Field (T)","Temperature (K)","Angle (deg)", ...
    "LI1_X (V)","LI1_theta (deg)","LI2_X (V)","LI2_theta (deg)", ...
    "LI3_X (V)","LI3_theta (deg)","LI4_X (V)","LI4_theta (deg)"];
if ~all(ismember(required, headerCols))
    error('read_data:MissingColumns', 'Data file is missing one or more required columns.');
end
end