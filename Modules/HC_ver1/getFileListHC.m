function [fileList, sortedFields, colors, mass, enter_sample_details] = getFileListHC(directory, enter_sample_details)
% getFileListHC (Flex full version with auto override enter_sample_details)
% ------------------------------------------------------------------------
% Detects:
%   • sample mass (folder + file names)
%   • growth MGxxx
%   • field XXT
% And decides:
%   • enter_sample_details = false if mass FOUND
%   • enter_sample_details = true  if mass NOT found
% ------------------------------------------------------------------------

%% Collect files
files = dir(fullfile(directory, '*.Dat'));
fileList = {files.name};

if isempty(fileList)
    error('No .Dat files found in directory: %s', directory);
end

%% Regex
exprMass   = '(\d+)p(\d+)mg';
exprGrowth = 'MG\s*\d+';

%% ============================================================
%  1) TRY TO FIND MASS IN FOLDER NAME
% ============================================================
folderName = string(directory);
mass = NaN;

tokensMass = regexp(folderName, exprMass, 'tokens');

if ~isempty(tokensMass)
    major = str2double(tokensMass{1}{1});
    minor = str2double(tokensMass{1}{2});
    mass = major + minor/100;
    fprintf('✓ Detected mass in folder: %.2f mg\n', mass);
end

%% ============================================================
%  2) IF NOT FOUND → SEARCH IN FILE NAMES
% ============================================================
if isnan(mass)
    for i = 1:length(fileList)
        tokensMass = regexp(fileList{i}, exprMass, 'tokens');
        if ~isempty(tokensMass)
            major = str2double(tokensMass{1}{1});
            minor = str2double(tokensMass{1}{2});
            mass = major + minor/100;
            fprintf('✓ Detected mass in file: %.2f mg (from %s)\n', mass, fileList{i});
            break;
        end
    end
end

%% ============================================================
%  3) DECIDE enter_sample_details
% ============================================================
if isnan(mass)
    fprintf('⚠ No mass detected → enter_sample_details = true\n');
    enter_sample_details = true;     % FORCE TRUE
    mass = 1;                        % normalized mass
else
    fprintf('✓ Mass detected → enter_sample_details = false\n');
    enter_sample_details = false;    % FORCE FALSE
end

%% ============================================================
%  Detect growth ID
% ============================================================
tokensGrowth = regexp(folderName, exprGrowth, 'match');
if ~isempty(tokensGrowth)
    fprintf('✓ Detected growth ID: %s\n', tokensGrowth{1});
else
    fprintf('⚠ No growth ID found (MGxxx)\n');
end

%% ============================================================
%  Extract magnetic fields
% ============================================================
sortedFields = zeros(length(fileList),1);

for i = 1:length(fileList)
    [~, filename, ~] = fileparts(fileList{i});
    fieldToken = regexp(filename, '\d+T', 'match');

    if ~isempty(fieldToken)
        sortedFields(i) = str2double(regexprep(fieldToken{1}, 'T', ''));
    else
        sortedFields(i) = 0;
        fprintf('⚠ No field found in "%s" → assuming 0T\n', fileList{i});
    end
end

[sortedFields, idx] = sort(sortedFields);
fileList = fileList(idx);

%% Colors
colors = cool(length(fileList));

fprintf('✓ Loaded %d files\n', length(fileList));

end
