function [fileList, sortedFields, colors, mass] = getFileList_MT(directory, color_scheme)
% Function to process data files in a directory
% Extracts file names, fields, colormap, and mass.
% Inputs:
%   directory    - Directory containing the .DAT files
%   color_scheme - 'default' | 'parula' | 'jet'
% Outputs:
%   fileList     - Sorted list of file names
%   sortedFields - Array of extracted field values
%   colors       - Colormap (depends on color_scheme)
%   mass         - Mass extracted from the first file

% Get list of .DAT files in the directory
files = dir(fullfile(directory, '*.DAT'));
fileList = {files.name};

% Initialize arrays for fields
sortedFields = nan(length(fileList), 1);

% Extract fields and sort file names
for i = 1:length(fileList)
    % Extract field (e.g., "1000OE") from the filename
    fieldMatch = regexp(fileList{i}, '(\d+(\.\d+)?[kK]?)(?i)OE', 'match');
    if ~isempty(fieldMatch)
        fieldStr = regexprep(fieldMatch{1}, '(?i)OE', ''); % remove "OE"
        if contains(fieldStr, 'k', 'IgnoreCase', true)
            fieldStr = regexprep(fieldStr, '(?i)K', ''); % remove "k"
            sortedFields(i) = str2double(fieldStr) * 1000; % convert to Oe
        else
            sortedFields(i) = str2double(fieldStr);
        end
    else
        error(['Field value not found in file name: ', fileList{i}]);
    end
end

% Sort files based on field values
[sortedFields, sortIdx] = sort(sortedFields);
fileList = fileList(sortIdx);

% --- choose colors according to scheme ---
switch lower(color_scheme)
    case 'parula'
        colors = parula(2);    % 2 צבעים ל־ZFC/FCW
    case 'jet'
        colors = jet(2);
    otherwise % 'default'
        colors = lines(2);     % ברירת מחדל: כמו plot רגיל (כחול/אדום פחות בוהקים)
end

% Extract mass from the first file
firstFilename = fileList{1};
massMatch = regexp(firstFilename, '\d+[pP]\d+(?i)MG', 'match');
if ~isempty(massMatch)
    % Clean the mass string (e.g., "20P54MG" or "20p54MG")
    massStr = regexprep(massMatch{1}, '(?i)MG', ''); % remove "MG"
    massStr = regexprep(massStr, '[pP]', '.');       % replace "P/p" with "."
    mass = str2double(massStr); % numeric
else
    error('Mass could not be extracted from the first filename.');
end

end
