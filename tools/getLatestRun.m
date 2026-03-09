function run_id = getLatestRun(experiment)
% getLatestRun Return the newest run_id for an experiment from runs/.
%
% Usage:
%   run_id = getLatestRun('aging');
%   run_id = getLatestRun();   % defaults to 'aging'

if nargin < 1 || isempty(experiment)
    experiment = 'aging';
end
experiment = char(string(experiment));

repoRoot = resolveRepoRoot();
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');

if exist(runsRoot, 'dir') ~= 7
    error('Runs directory not found for experiment "%s": %s', experiment, runsRoot);
end

runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('No run directories found for experiment "%s": %s', experiment, runsRoot);
end

names = string({runDirs.name});
timestamps = NaT(size(names));

for i = 1:numel(names)
    token = regexp(names(i), '^run_(\d{4})_(\d{2})_(\d{2})_(\d{6})(?:_|$)', 'tokens', 'once');
    if isempty(token)
        continue;
    end

    tsText = sprintf('%s-%s-%s %s:%s:%s', ...
        token{1}, token{2}, token{3}, token{4}(1:2), token{4}(3:4), token{4}(5:6));
    timestamps(i) = datetime(tsText, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
end

valid = ~isnat(timestamps);
if any(valid)
    validNames = names(valid);
    validTimestamps = timestamps(valid);
    [~, idx] = max(validTimestamps);
    run_id = char(validNames(idx));
else
    names = sort(names, 'descend');
    run_id = char(names(1));
end
end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);
repoRoot = fileparts(toolsDir);
end
