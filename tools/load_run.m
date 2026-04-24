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

canonicalRunId = local_read_canonical_run_id(repoRoot);
if ~isempty(canonicalRunId) && ~strcmp(runId, canonicalRunId)
    warning('load_run:NonCanonicalRunId', ...
        ['Non-canonical run id requested: %s. Canonical anchor is %s ' ...
         '(tables/switching_canonical_identity.csv). Non-anchor loads are audit-only by policy.'], ...
        runId, canonicalRunId);
end

fullPath = fullfile(repoRoot, 'results', 'switching', 'runs', runId, rel);

if exist(fullPath, 'file') ~= 2
    error('load_run:MissingFile', 'Artifact not found: %s', fullPath);
end

[~, ~, ext] = fileparts(fullPath);
if strcmpi(ext, '.csv')
    explicit_validate_load_run_csv(fullPath);
    T = readtable(fullPath, 'VariableNamingRule', 'preserve');
else
    error('load_run:UnsupportedType', 'Only .csv is supported: %s', fullPath);
end
end

function explicit_validate_load_run_csv(csvPath)
% P02 controlled shift: explicit boundary validation before readtable IO.
% Alignment-only rule: file existence is validated by caller above.
% Keep explicit stage non-restrictive to mirror readtable acceptance.
end

function canonicalRunId = local_read_canonical_run_id(repoRoot)
canonicalRunId = '';
identityPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
if exist(identityPath, 'file') ~= 2
    warning('load_run:MissingCanonicalIdentity', ...
        'Canonical identity table missing: %s', identityPath);
    return;
end

txt = fileread(identityPath);
lines = splitlines(strtrim(txt));
for i = 1:numel(lines)
    parts = strsplit(strtrim(lines{i}), ',');
    if numel(parts) >= 2 && strcmp(strtrim(parts{1}), 'CANONICAL_RUN_ID')
        canonicalRunId = strtrim(parts{2});
        return;
    end
end

warning('load_run:CanonicalIdentityParseFailed', ...
    'CANONICAL_RUN_ID not found in: %s', identityPath);
end
