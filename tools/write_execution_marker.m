function write_execution_marker(markerName, runDirOverride)
% write_execution_marker Append a non-blocking runtime execution marker (observability only).
%
% Resolves run_dir from createRunContext appdata when available; optional runDirOverride
% forces the destination directory (e.g. failure path after catch resolves run_dir).
% Otherwise appends to a repo-level fallback marker file under tables/. Never throws.

if nargin < 1 || isempty(markerName)
    return;
end

markerName = char(string(markerName));

try
    ts = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
    line = sprintf('%s %s\n', ts, markerName);

    runDir = '';
    if nargin >= 2 && ~isempty(runDirOverride)
        runDir = char(string(runDirOverride));
    else
        runDir = resolve_run_dir_for_marker();
    end

    if ~isempty(runDir) && exist(runDir, 'dir') == 7
        markerPath = fullfile(runDir, 'runtime_execution_markers.txt');
        fid = fopen(markerPath, 'a');
        if fid >= 0
            fprintf(fid, '%s', line);
            fclose(fid);
        end
        return;
    end

    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    if isempty(repoRoot) || exist(repoRoot, 'dir') ~= 7
        return;
    end

    tablesDir = fullfile(repoRoot, 'tables');
    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end

    fbPath = fullfile(tablesDir, 'runtime_execution_markers_fallback.txt');
    fid = fopen(fbPath, 'a');
    if fid >= 0
        fprintf(fid, '%s', line);
        fclose(fid);
    end
catch
end
end

function runDir = resolve_run_dir_for_marker()
runDir = '';

try
    if isappdata(0, 'MATLAB_FUNCTIONS_ACTIVE_RUN_CONTEXT')
        ctx = getappdata(0, 'MATLAB_FUNCTIONS_ACTIVE_RUN_CONTEXT');
        if isstruct(ctx) && isfield(ctx, 'run_dir') && ~isempty(ctx.run_dir)
            runDir = char(string(ctx.run_dir));
            return;
        end
    end

    if isappdata(0, 'runContext')
        ctx = getappdata(0, 'runContext');
        if isstruct(ctx) && isfield(ctx, 'run_dir') && ~isempty(ctx.run_dir)
            runDir = char(string(ctx.run_dir));
        end
    end
catch
end
end
