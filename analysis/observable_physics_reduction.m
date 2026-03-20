function out = observable_physics_reduction(cfg)
% observable_physics_reduction
% Analyze existing observable catalog tables and derive a minimal physical
% observable basis without recomputing any observables.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg);
[catalogPath, summaryPath, sourceRunId] = resolveCatalogInputs(repoRoot, cfg);

catalogTbl = readtable(catalogPath, 'TextType', 'string');
summaryTbl = table();
if exist(summaryPath, 'file') == 2
    summaryTbl = readtable(summaryPath, 'TextType', 'string');
end

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('catalog_source:%s', sourceRunId);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

appendText(run.log_path, sprintf('[%s] observable physics reduction started\n', stampNow()));
appendText(run.log_path, sprintf('catalog_source_run: %s\n', sourceRunId));
appendText(run.log_path, sprintf('catalog_path: %s\n', catalogPath));
appendText(run.log_path, sprintf('summary_path: %s\n', summaryPath));

catalogKeys = unique(catalogTbl(:, {'observable_name', 'experiment'}), 'rows', 'stable');
classificationTbl = classifyObservables(catalogKeys);

minimalNames = string(cfg.minimalBasisCandidates(:));
presentMask = ismember(lower(strtrim(minimalNames)), lower(strtrim(string(classificationTbl.observable_name))));
minimalNames = minimalNames(presentMask);

minimalTbl = buildMinimalSetTable(classificationTbl, minimalNames);
classificationPath = save_run_table(classificationTbl, 'observable_role_classification.csv', runDir);
minimalPath = save_run_table(minimalTbl, 'minimal_observable_set.csv', runDir);

reportText = buildReportText(catalogTbl, summaryTbl, classificationTbl, minimalTbl, sourceRunId, catalogPath, summaryPath, runDir);
reportPath = save_run_report(reportText, 'observable_physics_reduction_report.md', runDir);

zipPath = buildReviewZip(runDir, 'observable_physics_reduction_bundle.zip');

appendText(run.log_path, sprintf('classification_path: %s\n', classificationPath));
appendText(run.log_path, sprintf('minimal_set_path: %s\n', minimalPath));
appendText(run.log_path, sprintf('report_path: %s\n', reportPath));
appendText(run.log_path, sprintf('bundle_path: %s\n', zipPath));
appendText(run.log_path, sprintf('[%s] observable physics reduction complete\n', stampNow()));

catalogObservableCount = height(unique(catalogTbl(:, {'observable_name'}), 'rows', 'stable'));
minimalObservableCount = height(minimalTbl);
minimalList = string(minimalTbl.observable_name(:));

fprintf('RUN_ID=%s\n', run.run_id);
fprintf('Number_of_catalog_observables=%d\n', catalogObservableCount);
fprintf('Number_of_minimal_observables=%d\n', minimalObservableCount);
fprintf('List_of_minimal_observables=%s\n', strjoin(cellstr(minimalList), ', '));

out = struct();
out.run = run;
out.source_run = string(sourceRunId);
out.catalog_observable_count = catalogObservableCount;
out.minimal_observable_count = minimalObservableCount;
out.minimal_observables = minimalList;
out.paths = struct( ...
    'classification', string(classificationPath), ...
    'minimal_set', string(minimalPath), ...
    'report', string(reportPath), ...
    'bundle', string(zipPath));
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'observable_physics_reduction');
cfg = setDefault(cfg, 'catalogPath', '');
cfg = setDefault(cfg, 'summaryPath', '');
cfg = setDefault(cfg, 'minimalBasisCandidates', {'X', 'A', 'kappa', 'chi_ridge', 'R'});
end

function [catalogPath, summaryPath, sourceRunId] = resolveCatalogInputs(repoRoot, cfg)
catalogPath = char(string(cfg.catalogPath));
summaryPath = char(string(cfg.summaryPath));
sourceRunId = '';

if ~isempty(strtrim(catalogPath))
    if exist(catalogPath, 'file') ~= 2
        error('Configured catalogPath not found: %s', catalogPath);
    end
    [sourceRunId, inferredSummary] = inferRunAndSummaryFromCatalog(catalogPath);
    if isempty(strtrim(summaryPath))
        summaryPath = inferredSummary;
    end
else
    files = dir(fullfile(repoRoot, 'results', 'cross_experiment', 'runs', 'run_*', 'tables', 'observable_catalog.csv'));
    if isempty(files)
        error('No observable_catalog.csv found under results/cross_experiment/runs/run_*/tables.');
    end

    runIds = strings(numel(files), 1);
    for i = 1:numel(files)
        runIds(i) = extractRunIdFromPath(files(i).folder);
    end
    [~, order] = sort(runIds, 'descend');
    files = files(order);

    chosen = fullfile(files(1).folder, files(1).name);
    catalogPath = chosen;
    sourceRunId = char(runIds(order(1)));

    inferredSummary = fullfile(files(1).folder, 'observable_summary.csv');
    if isempty(strtrim(summaryPath))
        summaryPath = inferredSummary;
    end
end

if isempty(strtrim(summaryPath))
    summaryPath = '';
end
end

function [runId, summaryPath] = inferRunAndSummaryFromCatalog(catalogPath)
folderPath = fileparts(catalogPath);
runId = char(extractRunIdFromPath(folderPath));
summaryPath = fullfile(folderPath, 'observable_summary.csv');
end

function runId = extractRunIdFromPath(pathValue)
parts = split(string(strrep(pathValue, '/', filesep)), filesep);
idx = find(startsWith(parts, "run_"), 1, 'last');
if isempty(idx)
    runId = "unknown_run";
else
    runId = parts(idx);
end
end

function classTbl = classifyObservables(catalogKeys)
n = height(catalogKeys);
role = strings(n, 1);
physicalMeaning = strings(n, 1);
derivedFrom = strings(n, 1);

for i = 1:n
    obs = string(catalogKeys.observable_name(i));
    [role(i), physicalMeaning(i), derivedFrom(i)] = classifyOne(obs);
end

classTbl = table( ...
    string(catalogKeys.observable_name), ...
    role, ...
    string(catalogKeys.experiment), ...
    physicalMeaning, ...
    derivedFrom, ...
    'VariableNames', {'observable_name', 'role', 'experiment', 'physical_meaning', 'derived_from'});

classTbl = sortrows(classTbl, {'experiment', 'observable_name'});
end

function [role, meaning, relation] = classifyOne(obsName)
obs = lower(strtrim(obsName));
role = "SECONDARY";
meaning = "Auxiliary response or geometric observable.";
relation = "";

switch obs
    case "i_peak"
        role = "PRIMARY";
        meaning = "Ridge center current coordinate.";
    case "width"
        role = "PRIMARY";
        meaning = "Ridge thermal/current width scale.";
    case "s_peak"
        role = "PRIMARY";
        meaning = "Peak switching amplitude scale.";
    case "a"
        role = "PRIMARY";
        meaning = "Relaxation activity amplitude.";
    case "tau_dip"
        role = "PRIMARY";
        meaning = "Aging dip-sector clock timescale.";
    case "tau_fm"
        role = "PRIMARY";
        meaning = "Aging FM-sector clock timescale.";
    case "x"
        role = "DERIVED";
        meaning = "Composite switching coordinate combining center, width, and amplitude.";
        relation = "X = I_peak / (width * S_peak)";
    case "a1"
        role = "DERIVED";
        meaning = "Dynamic shape-mode amplitude from temperature-response structure.";
        relation = "a1 approx -dS_peak/dT";
    case "r"
        role = "DERIVED";
        meaning = "Aging two-clock ratio quantifying sector decoupling.";
        relation = "R = tau_FM / tau_dip";
    case "kappa"
        role = "SECONDARY";
        meaning = "Ridge curvature (shape stiffness) response observable.";
    case "chi_ridge"
        role = "SECONDARY";
        meaning = "Ridge-local susceptibility to thermal change.";
end
end

function minimalTbl = buildMinimalSetTable(classTbl, minimalNames)
if isempty(minimalNames)
    minimalTbl = classTbl([],:);
    return;
end

lookup = lower(strtrim(string(classTbl.observable_name)));
rows = false(height(classTbl), 1);
for i = 1:numel(minimalNames)
    rows = rows | (lookup == lower(strtrim(minimalNames(i))));
end
minimalTbl = classTbl(rows, :);

% Preserve candidate order when possible.
ord = zeros(height(minimalTbl), 1);
for i = 1:height(minimalTbl)
    hit = find(lower(strtrim(minimalNames)) == lower(strtrim(string(minimalTbl.observable_name(i)))), 1, 'first');
    if isempty(hit)
        ord(i) = numel(minimalNames) + i;
    else
        ord(i) = hit;
    end
end
minimalTbl.order_key = ord;
minimalTbl = sortrows(minimalTbl, 'order_key');
minimalTbl.order_key = [];
end

function textOut = buildReportText(catalogTbl, summaryTbl, classTbl, minimalTbl, sourceRunId, catalogPath, summaryPath, runDir)
line = strings(0,1);
line(end + 1) = '# Observable Physics Reduction';
line(end + 1) = '';
line(end + 1) = 'Generated: ' + string(stampNow());
line(end + 1) = 'Run id: `' + string(sourceRunId) + '` (catalog source)';
line(end + 1) = 'Catalog file: `' + string(catalogPath) + '`';
line(end + 1) = 'Summary file: `' + string(summaryPath) + '`';
line(end + 1) = 'Reduction run dir: `' + string(runDir) + '`';
line(end + 1) = '';

line(end + 1) = '## Full observable list';
for i = 1:height(classTbl)
    line(end + 1) = '- `' + classTbl.observable_name(i) + '` (' + classTbl.experiment(i) + '): role=' + classTbl.role(i);
end
line(end + 1) = '';

line(end + 1) = '## Derived-variable relations';
line(end + 1) = '- `X = I_peak/(width*S_peak)`';
line(end + 1) = '- `a1 approx -dS_peak/dT`';
line(end + 1) = '- `R = tau_FM/tau_dip`';
line(end + 1) = '';

line(end + 1) = '## Minimal physical observable set';
for i = 1:height(minimalTbl)
    relation = string(minimalTbl.derived_from(i));
    if strlength(strtrim(relation)) == 0
        relation = 'independent or response-level';
    end
    line(end + 1) = '- `' + minimalTbl.observable_name(i) + '` (' + minimalTbl.experiment(i) + ', role=' + minimalTbl.role(i) + '): ' + ...
        minimalTbl.physical_meaning(i) + ' | derived_from: ' + relation;
end
line(end + 1) = '';

line(end + 1) = '## Why this captures system physics';
line(end + 1) = '- `X(T)` captures composite switching geometry and effective control-coordinate evolution.';
line(end + 1) = '- `A(T)` captures relaxation activity amplitude and thermal response strength.';
line(end + 1) = '- `kappa(T)` captures ridge-shape stiffness/curvature evolution.';
line(end + 1) = '- `chi_ridge(T)` captures local susceptibility of switching ridge to temperature.';
line(end + 1) = '- `R(T)` captures aging-sector clock decoupling between FM and dip channels.';
line(end + 1) = '- Together these span control-coordinate, relaxation activity, shape, susceptibility, and aging-clock hierarchy with minimal redundancy for paper-level reporting.';

if ~isempty(summaryTbl)
    line(end + 1) = '';
    line(end + 1) = '## Catalog coverage snapshot';
    if all(ismember({'observable_name','experiment','N_points','temperature_range','source_runs'}, summaryTbl.Properties.VariableNames))
        for i = 1:height(summaryTbl)
            line(end + 1) = '- `' + string(summaryTbl.observable_name(i)) + '` (' + string(summaryTbl.experiment(i)) + ...
                '): N=' + string(summaryTbl.N_points(i)) + ', T=' + string(summaryTbl.temperature_range(i));
        end
    end
end

textOut = strjoin(line, newline);
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end

zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end

zip(zipPath, { ...
    fullfile('tables', 'minimal_observable_set.csv'), ...
    fullfile('tables', 'observable_role_classification.csv'), ...
    fullfile('reports', 'observable_physics_reduction_report.md'), ...
    'run_manifest.json', ...
    'config_snapshot.m', ...
    'log.txt', ...
    'run_notes.txt' ...
    }, runDir);
end

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', char(string(textValue)));
end

function out = stampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, name, value)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = value;
end
end