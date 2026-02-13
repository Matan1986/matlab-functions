function [fileList, sortedFreqs, colors, mass] = getFileList_Susceptibility(directory, color_scheme)
% getFileList_Susceptibility — Process AC susceptibility data files
% Extracts file names, excitation frequencies, colormap, and sample mass.
%
% Inputs:
%   directory     - Directory containing the .DAT files
%   color_scheme  - 'default' | 'parula' | 'jet'
%
% Outputs:
%   fileList      - Sorted list of file names
%   sortedFreqs   - Array of extracted excitation frequencies (Hz)
%   colors        - Colormap array (depends on color_scheme)
%   mass          - Sample mass (mg) extracted from filename or header
%
% ---------------------------------------------------------------
% Author: Adapted from getFileList_MT for AC susceptibility module
% ---------------------------------------------------------------

% --- Locate .dat files ---
files = dir(fullfile(directory, '*.dat'));
fileList = {files.name};
if isempty(fileList)
    error('No .dat files found in the specified directory.');
end

% --- Extract excitation frequency (e.g. "10Oe_100Hz" or "1to500Hz") ---
sortedFreqs = nan(length(fileList), 1);
for i = 1:length(fileList)
    fMatch = regexp(fileList{i}, '(?<=_)\d+(\.\d+)?([pP]\d+)?(?=Hz)', 'match');
    if ~isempty(fMatch)
        fStr = regexprep(fMatch{1}, '[pP]', '.');
        sortedFreqs(i) = str2double(fStr);
    elseif contains(fileList{i}, 'to', 'IgnoreCase', true)
        sortedFreqs(i) = NaN; % multi-frequency file (1–500Hz)
    else
        sortedFreqs(i) = NaN;
    end
end

% --- Sort files by extracted frequency ---
[sortedFreqs, sortIdx] = sort(sortedFreqs);
fileList = fileList(sortIdx);

% --- Color map ---
switch lower(color_scheme)
    case 'parula'
        colors = parula(max(length(fileList), 3));
    case 'jet'
        colors = jet(max(length(fileList), 3));
    otherwise
        colors = lines(max(length(fileList), 3));
end

% --- Try to extract mass from first filename ---
firstFilename = fileList{1};
massMatch = regexp(firstFilename, '\d+[pP]\d+(?i)MG', 'match');
if ~isempty(massMatch)
    massStr = regexprep(massMatch{1}, '(?i)MG', '');
    massStr = regexprep(massStr, '[pP]', '.');
    mass = str2double(massStr);
else
    warning('Mass not found in filename. Will attempt to read from header.');
    mass = NaN;
end
end
