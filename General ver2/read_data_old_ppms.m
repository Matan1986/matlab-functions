% Function to read data from a text or .dat file and extract columns into variables
function [Timems, FieldT, TemperatureK, Angledeg, LI5_XV, LI5_theta, LI6_XV, LI6_theta] = read_data_old_ppms(filename)
    explicitValidateGeneralOldPpmsDataFile(filename);
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

function explicitValidateGeneralOldPpmsDataFile(filename)
if exist(filename, 'file') ~= 2
    error('read_data_old_ppms:MissingFile', 'Data file not found: %s', filename);
end

txt = fileread(filename);
lines = regexp(txt, '\r\n|\n|\r', 'split');
if isempty(lines) || strlength(strtrim(string(lines{1}))) == 0
    error('read_data_old_ppms:InvalidHeader', 'Data file must include a tab-delimited header row.');
end

headerCols = strtrim(split(string(lines{1}), sprintf('\t')));
required = ["Time (ms)","Field (T)","Temperature (K)","Angle (deg)", ...
    "LI5_X (V)","LI5_theta (deg)","LI6_X (V)","LI6_theta (deg)"];
if ~all(ismember(required, headerCols))
    error('read_data_old_ppms:MissingColumns', 'Data file is missing one or more required columns.');
end
end