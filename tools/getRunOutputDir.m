function run_output_dir = getRunOutputDir()
% getRunOutputDir Return the active run directory from MATLAB root appdata.
%
% Usage:
%   run_output_dir = getRunOutputDir()
%
% The helper reads the active run context from MATLAB root appdata and
% returns the current run root directory, for example:
%   results/<experiment>/runs/run_<timestamp>_<label>/

runCtx = get_active_run_context();
if isempty(runCtx)
    error('Run context not found. Make sure stage0_setupPaths has been executed.');
end

if isfield(runCtx, 'run_dir') && strlength(strtrim(string(runCtx.run_dir))) > 0
    run_output_dir = char(string(runCtx.run_dir));
    return;
end

error('Active run context is missing run_dir. Make sure stage0_setupPaths has been executed.');
end

function runCtx = get_active_run_context()
runCtx = [];
keys = {'runContext', 'MATLAB_FUNCTIONS_ACTIVE_RUN_CONTEXT'};
for i = 1:numel(keys)
    key = keys{i};
    if isappdata(0, key)
        candidate = getappdata(0, key);
        if isstruct(candidate)
            runCtx = candidate;
            return;
        end
    end
end
end
