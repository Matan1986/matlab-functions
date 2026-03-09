function outPath = export_observables(experiment, runDir, observablesTbl)
% export_observables Write standardized observables.csv for a run.
%
% Usage:
%   outPath = export_observables('switching', runDir, observablesTbl)
%
% Input table required columns:
%   experiment, sample, temperature, observable, value, units
%
% Output schema:
%   experiment, sample, temperature, observable, value, units, role, source_run

if nargin < 3
    error('export_observables requires (experiment, runDir, observablesTbl).');
end
if ~istable(observablesTbl)
    error('observablesTbl must be a table.');
end

experiment = char(string(experiment));
runDir = char(string(runDir));

runPath = resolveRunPath(experiment, runDir);
if exist(runPath, 'dir') ~= 7
    mkdir(runPath);
end

runId = inferRunId(runPath, runDir);
requiredBase = ["experiment","sample","temperature","observable","value","units"];
finalOrder = [requiredBase, "role", "source_run"];

vars = string(observablesTbl.Properties.VariableNames);

% Backward-compatible fill for missing experiment column.
if ~ismember("experiment", vars)
    observablesTbl.experiment = repmat(string(experiment), height(observablesTbl), 1);
end

vars = string(observablesTbl.Properties.VariableNames);
missingBase = requiredBase(~ismember(requiredBase, vars));
if ~isempty(missingBase)
    error('Missing required observable columns: %s', strjoin(cellstr(missingBase), ', '));
end

% Normalize experiment column and fill empties with the provided experiment.
expCol = string(observablesTbl.experiment);
emptyExp = strlength(strtrim(expCol)) == 0;
expCol(emptyExp) = string(experiment);
observablesTbl.experiment = expCol;

n = height(observablesTbl);

% Optional role column.
if ~ismember("role", vars)
    observablesTbl.role = repmat("observable", n, 1);
else
    roleCol = lower(strtrim(string(observablesTbl.role)));
    emptyRole = strlength(roleCol) == 0;
    roleCol(emptyRole) = "observable";

    allowedRoles = ["coordinate","observable","metadata"];
    invalidRole = ~ismember(roleCol, allowedRoles);
    if any(invalidRole)
        warning('export_observables:InvalidRole', ...
            'Invalid role values found. Replacing with "observable".');
        roleCol(invalidRole) = "observable";
    end
    observablesTbl.role = roleCol;
end

% Optional source_run column.
if ~ismember("source_run", vars)
    observablesTbl.source_run = repmat(string(runId), n, 1);
else
    srcCol = string(observablesTbl.source_run);
    emptySrc = strlength(strtrim(srcCol)) == 0;
    srcCol(emptySrc) = string(runId);
    observablesTbl.source_run = srcCol;
end

observablesTbl = observablesTbl(:, cellstr(finalOrder));
outPath = fullfile(runPath, 'observables.csv');
writetable(observablesTbl, outPath);

fprintf('Observables exported: %s\n', outPath);
end

function runPath = resolveRunPath(experiment, runDir)
if isfolder(runDir)
    runPath = runDir;
    return;
end

repoRoot = resolveRepoRoot();
runPath = fullfile(repoRoot, 'results', experiment, 'runs', runDir);
end

function runId = inferRunId(runPath, runDir)
[~, runId] = fileparts(runPath);
if strlength(string(runId)) == 0
    [~, runId] = fileparts(fileparts(runPath));
end
if strlength(string(runId)) == 0
    runId = char(string(runDir));
end
end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);
repoRoot = fileparts(toolsDir);
end
