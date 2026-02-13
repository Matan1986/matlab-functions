function [fileList, sortedValues, colors, meta] = getFileListSwitching(directory, dep_type)

fileList = dir(fullfile(directory, '*.dat'));

%% -------------------------------------------------
% Parse physical parameters from *folder name only*
% (OPTIONAL: if not found -> NaN)
%% -------------------------------------------------
[~, folderName] = fileparts(directory);

meta = struct( ...
    'Temperature_K', NaN, ...
    'Field_T',       NaN, ...
    'PulseWidth_ms', NaN, ...
    'Current_mA',    NaN );

tok = regexp(folderName, '(?<![\d\.])(\d+\.?\d*)K(?![a-zA-Z])', 'tokens', 'once');
if ~isempty(tok), meta.Temperature_K = str2double(tok{1}); end

tok = regexp(folderName, '(?<![\d\.])(-?\d+\.?\d*)T(?![a-zA-Z])', 'tokens', 'once');
if ~isempty(tok), meta.Field_T = str2double(tok{1}); end

tok = regexp(folderName, '(?<![\d\.])(\d+\.?\d*)ms(?![a-zA-Z])', 'tokens', 'once');
if ~isempty(tok), meta.PulseWidth_ms = str2double(tok{1}); end

tok = regexp(folderName, '(?<![\d\.])(\d+\.?\d*)mA(?![a-zA-Z])', 'tokens', 'once');
if ~isempty(tok), meta.Current_mA = str2double(tok{1}); end

%% -------------------------------------------------
% Existing logic (kept compatible)
%% -------------------------------------------------
numColors = numel(fileList);

switch dep_type
    case 'Amplitude'
        findStr = '_(\d+\.\d+)mA_';
        colors = [linspace(0.4,0.9,numColors)', ...
                  linspace(0.4,0.9,numColors)', ...
                  linspace(0.1,0.2,numColors)'];

    case 'Width'
        findStr = '_([\d\.E\-]+)sec\.dat';
        colors = [linspace(0.1,0.4,numColors)', ...
                  linspace(0.3,0.7,numColors)', ...
                  linspace(0.1,0.3,numColors)'];

    case 'Temperature'
        findStr = '_T(\d+\.\d+)_H';
        colors = [linspace(0.4,0.9,numColors)', ...
                  linspace(0.1,0.3,numColors)', ...
                  linspace(0.1,0.3,numColors)'];

    case 'Field'
        findStr = '_H([-\d\.]+)\.dat';
        colors = [linspace(0.1,0.3,numColors)', ...
                  linspace(0.1,0.3,numColors)', ...
                  linspace(0.4,0.9,numColors)'];

    case 'Configuration'
        findStr = 'Configuration';
        colors  = parula(numColors);

    otherwise
        findStr = '';
        colors  = parula(numColors);
end

%% -------------------------------------------------
% Sorting
%% -------------------------------------------------
if strcmp(dep_type,'Configuration')
    % --- EXACTLY like before: configuration dependence ---
    Values = zeros(numel(fileList),1);

    for i = 1:numel(fileList)
        filename = fileList(i).name;
        tok = regexp(filename, '(?i)conf(?:ig)?(\d+)(?:_|\.|$)', ...
                     'tokens', 'once');
        Values(i) = str2double(tok{1});
    end

    [sortedValues, order] = sort(Values);
    fileList = fileList(order);

elseif ~isempty(findStr)
    Values = zeros(numel(fileList),1);

    for i = 1:numel(fileList)
        tok = regexp(fileList(i).name, findStr, 'tokens', 'once');
        Values(i) = str2double(tok{1});
    end

    if strcmp(dep_type,'Field')
        [~, order] = sort(abs(Values),'ascend');
    else
        [~, order] = sort(Values,'ascend');
    end

    sortedValues = Values(order);
    fileList     = fileList(order);

else
    sortedValues = [];
end

end
