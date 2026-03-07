function runPath = openLatestRun(experiment)
% openLatestRun Open latest run folder for an experiment.
%
% Usage:
%   openLatestRun('aging');
%   p = openLatestRun('aging');

if nargin < 1 || isempty(experiment)
    experiment = 'aging';
end
experiment = char(string(experiment));

run_id = getLatestRun(experiment);
repoRoot = resolveRepoRoot();
runPath = fullfile(repoRoot, 'results', experiment, 'runs', run_id);

if exist(runPath, 'dir') ~= 7
    error('Latest run folder does not exist: %s', runPath);
end

if ispc
    winopen(runPath);
else
    fprintf('Latest run path: %s\n', runPath);
end
end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);
repoRoot = fileparts(toolsDir);
end
