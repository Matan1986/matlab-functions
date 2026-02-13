function dep_type = extract_dep_type_from_folder(directory)
% EXTRACT_DEP_TYPE_FROM_FOLDER  Robust detection of dependence type from folder name.
%
% Usage:
%   dep_type = extract_dep_type_from_folder(directory)
%
% Detects dependence type strings like:
%   "Amp Dep", "Width Dep", "Temp Dep", "Field Dep", "FC Dep",
%   "Config Dep", "Cooling Rate Dep", "Pulse direction and order Dep"
%
% Robust to case (upper/lower) and separators (-, _, ., multiple spaces).
%
% If no match found → defaults to 'Temperature'.

    if nargin < 1 || isempty(directory)
        error('extract_dep_type_from_folder:MissingInput', ...
            'You must provide a valid directory path.');
    end

    % Get the folder name only
    [~, folderName] = fileparts(directory);

    % Normalize to lowercase and unify separators
    folderNameLower = lower(folderName);
    folderNameClean = regexprep(folderNameLower, '[-_.]+', ' ');  % replace -,_,. with space
    folderNameClean = regexprep(folderNameClean, '\s+', ' ');     % collapse multiple spaces
    folderNameClean = strtrim(folderNameClean);                   % trim ends

    % --- Pattern matching ---
    if contains(folderNameClean, 'amp dep')
        dep_type = 'Amplitude';
    elseif contains(folderNameClean, 'width dep')
        dep_type = 'Width';
    elseif contains(folderNameClean, 'temp dep')
        dep_type = 'Temperature';
    elseif contains(folderNameClean, 'field dep')
        dep_type = 'Field';
    elseif contains(folderNameClean, 'fc dep')
        dep_type = 'Field cool';
    elseif contains(folderNameClean, 'config dep')
        dep_type = 'Configuration';
    elseif contains(folderNameClean, 'cooling rate dep')
        dep_type = 'Cooling rate';
    elseif contains(folderNameClean, 'pulse direction and order dep')
        dep_type = 'Pulse direction and order';
    else
        warning('⚠️ Could not detect dependence type from folder "%s". Defaulting to "Temperature".', folderName);
        dep_type = 'Temperature';
    end

    % fprintf('[extract_dep_type_from_folder] Detected: %s\n', dep_type);
end
