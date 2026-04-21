function atomic_writetable(T, finalPath)
% atomic_writetable Write table to a temp file then rename to finalPath.

if nargin < 2 || isempty(strtrim(char(string(finalPath))))
    error('atomic_writetable requires table_data and finalPath.');
end
if ~istable(T)
    error('atomic_writetable requires a table.');
end
thisDir = fileparts(mfilename('fullpath'));
if exist(fullfile(thisDir, 'atomic_commit_file.m'), 'file') == 2
    addpath(thisDir);
end
finalPath = char(string(finalPath));
tmpPath = [finalPath '.tmp'];
writetable(T, tmpPath, 'FileType', 'text');
atomic_commit_file(tmpPath, finalPath);
end
