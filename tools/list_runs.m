function T = list_runs(experiment)
% list_runs List run folders and key manifest metadata for an experiment.
%
% Usage:
%   list_runs;           % defaults to 'aging'
%   list_runs('aging');
%   T = list_runs('cross_analysis');

if nargin < 1 || isempty(experiment)
    experiment = 'aging';
end
experiment = char(string(experiment));

repoRoot = resolveRepoRoot();
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');

if exist(runsRoot, 'dir') ~= 7
    fprintf('No runs directory found: %s\n', runsRoot);
    T = table();
    return;
end

d = dir(runsRoot);
d = d([d.isdir]);
d = d(~ismember({d.name}, {'.','..'}));

if isempty(d)
    fprintf('No run folders found in: %s\n', runsRoot);
    T = table();
    return;
end

names = string({d.name});
[~, order] = sort(names, 'descend');
d = d(order);

n = numel(d);
run_id = strings(n,1);
timestamp = strings(n,1);
label = strings(n,1);
dataset = strings(n,1);
git_commit = strings(n,1);

for i = 1:n
    runDir = fullfile(runsRoot, d(i).name);
    run_id(i) = string(d(i).name);

    manifestPath = fullfile(runDir, 'run_manifest.json');
    if exist(manifestPath, 'file') == 2
        try
            m = load_run_manifest(runDir);
            timestamp(i) = getStringField(m, 'timestamp', "");
            label(i) = getStringField(m, 'label', "");
            dataset(i) = getStringField(m, 'dataset', "");
            commitFull = getStringField(m, 'git_commit', "");
            if strlength(commitFull) > 8
                git_commit(i) = extractBefore(commitFull, 9);
            else
                git_commit(i) = commitFull;
            end
            if isfield(m, 'run_id') && ~isempty(m.run_id)
                run_id(i) = string(m.run_id);
            end
        catch
            timestamp(i) = "";
            label(i) = "";
            dataset(i) = "";
            git_commit(i) = "";
        end
    else
        timestamp(i) = "";
        label(i) = "";
        dataset(i) = "";
        git_commit(i) = "";
    end
end

T = table(run_id, timestamp, label, dataset, git_commit);

fprintf('\nRuns for experiment: %s\n', experiment);
disp(T);
end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);
repoRoot = fileparts(toolsDir);
end

function s = getStringField(st, fieldName, defaultValue)
if nargin < 3
    defaultValue = "";
end
s = string(defaultValue);
if isstruct(st) && isfield(st, fieldName)
    v = st.(fieldName);
    if ~isempty(v)
        s = string(v);
    end
end
end
