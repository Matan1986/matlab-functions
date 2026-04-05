function T = load_run(repoRoot, runId, relPathUnderRun)
%LOAD_RUN Read a CSV artifact from results/switching/runs/<runId>/...
%
% Usage:
%   T = load_run(repoRoot, 'run_2026_04_03_000147_switching_canonical', 'tables/foo.csv');
%
% relPathUnderRun may use '/' or '\' ; must be relative to the run root.

if nargin < 3
    error('load_run:Usage', 'load_run(repoRoot, runId, relPathUnderRun)');
end

repoRoot = char(string(repoRoot));
runId = char(string(runId));
rel = char(string(relPathUnderRun));
rel = strtrim(rel);
rel = strrep(rel, '/', filesep);

fullPath = fullfile(repoRoot, 'results', 'switching', 'runs', runId, rel);

if exist(fullPath, 'file') ~= 2
    error('load_run:MissingFile', 'Artifact not found: %s', fullPath);
end

[~, ~, ext] = fileparts(fullPath);
if strcmpi(ext, '.csv')
    T = readtable(fullPath, 'VariableNamingRule', 'preserve');
else
    error('load_run:UnsupportedType', 'Only .csv is supported: %s', fullPath);
end
end
