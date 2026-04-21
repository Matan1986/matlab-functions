function T = load_observables(resultsRoot)
% load_observables Load and aggregate observables.csv files across runs.
%
% Usage:
%   T = load_observables();
%   T = load_observables(fullfile(repoRoot, 'results'));
%
% Output schema:
%   experiment, sample, temperature, observable, value, units, role, source_run

if nargin < 1 || isempty(resultsRoot)
    repoRoot = resolveRepoRoot();
    resultsRoot = fullfile(repoRoot, 'results');
end
resultsRoot = char(string(resultsRoot));

T = emptyObservablesTable();

if exist(resultsRoot, 'dir') ~= 7
    warning('load_observables:MissingResultsRoot', 'Results root not found: %s', resultsRoot);
    return;
end

csvFiles = dir(fullfile(resultsRoot, '*', 'runs', '*', 'observables.csv'));
if isempty(csvFiles)
    fprintf('No observables.csv files found under: %s\n', resultsRoot);
    return;
end

chunks = cell(numel(csvFiles), 1);
keep = false(numel(csvFiles), 1);

for i = 1:numel(csvFiles)
    csvPath = fullfile(csvFiles(i).folder, csvFiles(i).name);
    try
        runDir = fileparts(csvPath);
        [runStatus, ~] = get_run_status_value(runDir);
        if runStatus == "PARTIAL"
            error('PARTIAL_RUN_NOT_ALLOWED');
        end
        if runStatus ~= "CANONICAL"
            continue;
        end
        explicitValidateObservablesCsv(csvPath);
        tbl = readtable(csvPath, 'TextType', 'string');
        tbl = normalizeObservableTable(tbl, csvPath);
        chunks{i} = tbl;
        keep(i) = true;
    catch ME
        warning('load_observables:ReadFailed', ...
            'Skipping file %s (%s)', csvPath, ME.message);
    end
end

if any(keep)
    T = vertcat(chunks{keep});
    T = sortrows(T, {'experiment','source_run','sample','temperature','observable'});
end
end

function tbl = normalizeObservableTable(tbl, csvPath)
requiredOrder = ["experiment","sample","temperature","observable","value","units","role","source_run"];
vars = string(tbl.Properties.VariableNames);

[expFromPath, runFromPath] = inferPathFields(csvPath);
n = height(tbl);

if ~ismember("experiment", vars)
    tbl.experiment = repmat(expFromPath, n, 1);
end
if ~ismember("sample", vars)
    tbl.sample = repmat("", n, 1);
end
if ~ismember("temperature", vars)
    tbl.temperature = NaN(n, 1);
end
if ~ismember("observable", vars)
    tbl.observable = repmat("", n, 1);
end
if ~ismember("value", vars)
    tbl.value = NaN(n, 1);
end
if ~ismember("units", vars)
    tbl.units = repmat("", n, 1);
end
if ~ismember("role", vars)
    tbl.role = repmat("observable", n, 1);
end
if ~ismember("source_run", vars)
    tbl.source_run = repmat(runFromPath, n, 1);
end

tbl.experiment = string(tbl.experiment);
tbl.sample = string(tbl.sample);
tbl.observable = string(tbl.observable);
tbl.units = string(tbl.units);
tbl.role = lower(strtrim(string(tbl.role)));
tbl.source_run = string(tbl.source_run);

tbl.temperature = toDoubleColumn(tbl.temperature, n);
tbl.value = toDoubleColumn(tbl.value, n);

emptyExp = strlength(strtrim(tbl.experiment)) == 0;
tbl.experiment(emptyExp) = expFromPath;
emptyRole = strlength(tbl.role) == 0;
tbl.role(emptyRole) = "observable";
emptyRun = strlength(strtrim(tbl.source_run)) == 0;
tbl.source_run(emptyRun) = runFromPath;

allowedRoles = ["coordinate","observable","metadata"];
invalidRole = ~ismember(tbl.role, allowedRoles);
if any(invalidRole)
    tbl.role(invalidRole) = "observable";
end

tbl = tbl(:, cellstr(requiredOrder));
end

function v = toDoubleColumn(x, n)
if isnumeric(x)
    v = double(x);
elseif isstring(x)
    v = str2double(x);
elseif iscell(x)
    try
        v = str2double(string(x));
    catch
        v = NaN(n,1);
    end
else
    try
        v = double(x);
    catch
        v = NaN(n,1);
    end
end
v = reshape(v, [], 1);
if numel(v) ~= n
    v = NaN(n,1);
end
end

function [experiment, runId] = inferPathFields(csvPath)
runDir = fileparts(csvPath);
[~, runId] = fileparts(runDir);

runsDir = fileparts(runDir);
expDir = fileparts(runsDir);
[~, experiment] = fileparts(expDir);

experiment = string(experiment);
runId = string(runId);
end

function T = emptyObservablesTable()
T = table( ...
    strings(0,1), strings(0,1), NaN(0,1), strings(0,1), NaN(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'experiment','sample','temperature','observable','value','units','role','source_run'});
end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);
repoRoot = fileparts(toolsDir);
end

function explicitValidateObservablesCsv(csvPath)
if exist(csvPath, 'file') ~= 2
    error('load_observables:MissingObservablesCsv', ...
        'Observables csv not found: %s', csvPath);
end
end
