function [file_noPause, pauseRuns] = getFileList_aging(directory)
% getFileList_aging — Find aging .dat files and identify pause/no-pause runs

files = dir(fullfile(directory, '*aging_*.dat'));
if isempty(files)
    error('No aging files found in %s', directory);
end

file_noPause = '';
pauseRuns = [];

for i = 1:numel(files)
    meta = parseAgingFilename(files(i).name);
    if meta.isNoPause
        file_noPause = fullfile(directory, files(i).name);
    else
        s = struct( ...
            'file', fullfile(directory, files(i).name), ...
            'waitK', meta.waitK, ...
            'waitHours', meta.waitHours, ...
            'fcT', meta.fcT, ...
            'measOe', meta.measOe, ...
            'meta', meta);
        pauseRuns = [pauseRuns; s]; %#ok<AGROW>
    end
end

if isempty(file_noPause)
    error('No "no-pause" (afterZFC) file found.');
end
if isempty(pauseRuns)
    error('No "pause" files found.');
end

% sort by waiting temperature
[~, idx] = sort([pauseRuns.waitK]);
pauseRuns = pauseRuns(idx);

fprintf('Found %d pause runs and 1 no-pause run.\n', numel(pauseRuns));
end
