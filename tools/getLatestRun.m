function run_id = getLatestRun(experiment)
% getLatestRun Return latest run_id for an experiment from latest_run.txt.
%
% Usage:
%   run_id = getLatestRun('aging');
%   run_id = getLatestRun();   % defaults to 'aging'

if nargin < 1 || isempty(experiment)
    experiment = 'aging';
end
experiment = char(string(experiment));

repoRoot = resolveRepoRoot();
pointerPath = fullfile(repoRoot, 'results', experiment, 'latest_run.txt');

if exist(pointerPath, 'file') ~= 2
    error('Latest run pointer not found for experiment "%s": %s', experiment, pointerPath);
end

run_id = strtrim(fileread(pointerPath));
if isempty(run_id)
    error('Latest run pointer file is empty: %s', pointerPath);
end
end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);
repoRoot = fileparts(toolsDir);
end
