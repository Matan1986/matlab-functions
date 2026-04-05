function p = run_artifact_path(repoRoot, runId, relPathUnderRun)
%RUN_ARTIFACT_PATH Full path under results/switching/runs/<runId>/ (no I/O).

if nargin < 3
    error('run_artifact_path:Usage', 'run_artifact_path(repoRoot, runId, relPathUnderRun)');
end

repoRoot = char(string(repoRoot));
runId = char(string(runId));
rel = char(string(relPathUnderRun));
rel = strtrim(rel);
rel = strrep(rel, '/', filesep);
p = fullfile(repoRoot, 'results', 'switching', 'runs', runId, rel);
end
