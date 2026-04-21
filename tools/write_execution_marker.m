function write_execution_marker(markerName, runDirOverride)
% write_execution_marker Append a non-blocking runtime execution marker (observability only).
%
% Requires runDirOverride (run root). Writes atomically via temp file + rename.
% Never throws.

if nargin < 1 || isempty(markerName)
    return;
end

markerName = char(string(markerName));

try
    thisDir = fileparts(mfilename('fullpath'));
    if exist(fullfile(thisDir, 'atomic_commit_file.m'), 'file') == 2
        addpath(thisDir);
    end

    if nargin < 2 || isempty(strtrim(char(string(runDirOverride))))
        return;
    end

    ts = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
    line = sprintf('%s %s\n', ts, markerName);

    runDir = char(string(runDirOverride));

    if ~isempty(runDir) && exist(runDir, 'dir') == 7
        markerPath = fullfile(runDir, 'runtime_execution_markers.txt');
        old = '';
        if isfile(markerPath)
            try
                old = fileread(markerPath);
            catch %#ok<CTCH>
                old = '';
            end
        end
        newContent = [old line];
        tmpPath = [markerPath '.tmp'];
        fid = fopen(tmpPath, 'w');
        if fid >= 0
            fprintf(fid, '%s', newContent);
            fclose(fid);
            atomic_commit_file(tmpPath, markerPath);
        end
        return;
    end
catch %#ok<CTCH>
end
end
