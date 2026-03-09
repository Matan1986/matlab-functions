function [outDir, run] = init_run_output_dir(repoRoot, experiment, analysisName, dataset)
% init_run_output_dir Create a run context and return a run-scoped output dir.

if nargin < 3
    error('init_run_output_dir requires repoRoot, experiment, and analysisName.');
end
if nargin < 4
    dataset = '';
end

if exist('createRunContext', 'file') ~= 2 || exist('getResultsDir', 'file') ~= 2
    error('Run helpers are not on the MATLAB path.');
end

cfgRun = struct();
cfgRun.runLabel = char(string(analysisName));
if ~isempty(dataset)
    cfgRun.dataset = char(string(dataset));
end

run = createRunContext(char(string(experiment)), cfgRun);
outDir = getResultsDir(char(string(experiment)), char(string(analysisName)));

fprintf('%s output directory:\n%s\n', char(string(experiment)), outDir);
if isfield(run, 'run_dir') && ~isempty(run.run_dir)
    fprintf('%s run directory:\n%s\n', char(string(experiment)), run.run_dir);
end
end
