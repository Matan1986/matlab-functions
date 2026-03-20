function out = observable_physics_completeness_audit(cfg)
% observable_physics_completeness_audit
% Audit whether the minimal observable basis is physically sufficient using
% existing catalog/reduction outputs only (no new observable computation).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg);
input = resolveInputFiles(repoRoot, cfg);

minimalTbl = readtable(input.minimalSetPath, 'TextType', 'string');
roleTbl = readtable(input.roleClassPath, 'TextType', 'string');
catalogTbl = readtable(input.catalogPath, 'TextType', 'string');
summaryTbl = readtable(input.summaryPath, 'TextType', 'string');

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('reduction_source:%s', input.reductionRunId);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

appendText(run.log_path, sprintf('[%s] observable physics completeness audit started\n', stampNow()));
appendText(run.log_path, sprintf('reduction_run: %s\n', input.reductionRunId));
appendText(run.log_path, sprintf('catalog_source_run: %s\n', input.catalogRunId));

catalogKeys = unique(catalogTbl(:, {'observable_name', 'experiment'}), 'rows', 'stable');
basisNames = unique(string(minimalTbl.observable_name), 'stable');
catalogNames = unique(string(catalogKeys.observable_name), 'stable');

deps = buildDependencyRules();
reconTbl = buildReconstructionMatrix(catalogKeys, basisNames, catalogNames, deps);
supportTbl = buildRequiredSupportTable(reconTbl);
graphTbl = buildDependencyGraphTable(deps);
effectiveTbl = buildEffectiveQuantitiesTable(basisNames, catalogNames);

reconPath = save_run_table(reconTbl, 'observable_reconstruction_matrix.csv', runDir);
supportPath = save_run_table(supportTbl, 'required_support_observables.csv', runDir);
graphPath = save_run_table(graphTbl, 'dependency_graph_edges.csv', runDir);
effectivePath = save_run_table(effectiveTbl, 'effective_physical_quantities_audit.csv', runDir);

reportText = buildReportText(minimalTbl, roleTbl, summaryTbl, reconTbl, supportTbl, graphTbl, effectiveTbl, input, runDir);
reportPath = save_run_report(reportText, 'observable_physics_completeness_report.md', runDir);

zipPath = buildReviewZip(runDir, 'observable_physics_completeness_bundle.zip');

appendText(run.log_path, sprintf('reconstruction_matrix: %s\n', reconPath));
appendText(run.log_path, sprintf('required_support: %s\n', supportPath));
appendText(run.log_path, sprintf('dependency_graph: %s\n', graphPath));
appendText(run.log_path, sprintf('effective_quantities: %s\n', effectivePath));
appendText(run.log_path, sprintf('report: %s\n', reportPath));
appendText(run.log_path, sprintf('bundle: %s\n', zipPath));
appendText(run.log_path, sprintf('[%s] observable physics completeness audit complete\n', stampNow()));

minimalList = unique(string(minimalTbl.observable_name), 'stable');
supportList = unique(string(supportTbl.observable_name), 'stable');

fprintf('RUN_ID=%s\n', run.run_id);
fprintf('Number_of_minimal_observables=%d\n', numel(minimalList));
fprintf('Number_of_support_observables=%d\n', numel(supportList));
fprintf('Minimal_observable_list=%s\n', strjoin(cellstr(minimalList), ', '));
fprintf('Support_observable_list=%s\n', strjoin(cellstr(supportList), ', '));

out = struct();
out.run = run;
out.minimal_observables = minimalList;
out.support_observables = supportList;
out.paths = struct( ...
    'reconstruction_matrix', string(reconPath), ...
    'required_support', string(supportPath), ...
    'dependency_graph', string(graphPath), ...
    'effective_quantities', string(effectivePath), ...
    'report', string(reportPath), ...
    'bundle', string(zipPath));
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'observable_physics_completeness_audit');
cfg = setDefault(cfg, 'inputReductionRunId', 'run_2026_03_16_145120_observable_physics_reduction');
end

function input = resolveInputFiles(repoRoot, cfg)
input = struct();
input.reductionRunId = string(cfg.inputReductionRunId);
input.reductionRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(input.reductionRunId));

if exist(input.reductionRunDir, 'dir') ~= 7
    error('Reduction run not found: %s', input.reductionRunDir);
end

input.minimalSetPath = fullfile(input.reductionRunDir, 'tables', 'minimal_observable_set.csv');
input.roleClassPath = fullfile(input.reductionRunDir, 'tables', 'observable_role_classification.csv');

if exist(input.minimalSetPath, 'file') ~= 2
    error('Missing minimal_observable_set.csv: %s', input.minimalSetPath);
end
if exist(input.roleClassPath, 'file') ~= 2
    error('Missing observable_role_classification.csv: %s', input.roleClassPath);
end

% The requested catalog files may not be inside the reduction run.
% First try reduction run tables; if missing, resolve from the source catalog run.
input.catalogPath = fullfile(input.reductionRunDir, 'tables', 'observable_catalog.csv');
input.summaryPath = fullfile(input.reductionRunDir, 'tables', 'observable_summary.csv');

if exist(input.catalogPath, 'file') ~= 2 || exist(input.summaryPath, 'file') ~= 2
    [catPath, sumPath, runId] = resolveCatalogFromReductionReport(input.reductionRunDir, repoRoot);
    input.catalogPath = catPath;
    input.summaryPath = sumPath;
    input.catalogRunId = runId;
else
    input.catalogRunId = extractRunIdFromPath(fileparts(input.catalogPath));
end

if exist(input.catalogPath, 'file') ~= 2
    error('Missing observable_catalog.csv: %s', input.catalogPath);
end
if exist(input.summaryPath, 'file') ~= 2
    error('Missing observable_summary.csv: %s', input.summaryPath);
end
end

function [catalogPath, summaryPath, runId] = resolveCatalogFromReductionReport(reductionRunDir, repoRoot)
reportPath = fullfile(reductionRunDir, 'reports', 'observable_physics_reduction_report.md');
catalogPath = '';
summaryPath = '';
runId = "";

if exist(reportPath, 'file') == 2
    txt = fileread(reportPath);
    catTok = regexp(txt, 'Catalog file:\s*`([^`]+)`', 'tokens', 'once');
    sumTok = regexp(txt, 'Summary file:\s*`([^`]+)`', 'tokens', 'once');
    if ~isempty(catTok)
        catalogPath = catTok{1};
        runId = extractRunIdFromPath(fileparts(catalogPath));
    end
    if ~isempty(sumTok)
        summaryPath = sumTok{1};
    end
end

if isempty(catalogPath) || exist(catalogPath, 'file') ~= 2
    files = dir(fullfile(repoRoot, 'results', 'cross_experiment', 'runs', 'run_*', 'tables', 'observable_catalog.csv'));
    if isempty(files)
        error('No observable_catalog.csv found under cross_experiment runs.');
    end
    runIds = strings(numel(files),1);
    for i = 1:numel(files)
        runIds(i) = extractRunIdFromPath(files(i).folder);
    end
    [~, ord] = sort(runIds, 'descend');
    pick = files(ord(1));
    catalogPath = fullfile(pick.folder, pick.name);
    runId = runIds(ord(1));
end

if isempty(summaryPath) || exist(summaryPath, 'file') ~= 2
    summaryPath = fullfile(fileparts(catalogPath), 'observable_summary.csv');
end
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

function deps = buildDependencyRules()
deps = { ...
    makeDepRule('X', {'I_peak','width','S_peak'}, 'exact', 'X = I_peak/(width*S_peak)'), ...
    makeDepRule('a1', {'S_peak'}, 'approx_derivative', 'a1 approx -dS_peak/dT'), ...
    makeDepRule('R', {'tau_FM','tau_dip'}, 'exact', 'R = tau_FM/tau_dip') ...
    };
end

function d = makeDepRule(target, deps, ruleType, relation)
d = struct();
d.target = string(target);
d.dependencies = string(deps(:));
d.rule_type = string(ruleType);
d.relation = string(relation);
end

function tbl = buildReconstructionMatrix(catalogKeys, basisNames, catalogNames, deps)
n = height(catalogKeys);
recon = strings(n,1);
requiresSupport = false(n,1);
infoLost = strings(n,1);

for i = 1:n
    obs = string(catalogKeys.observable_name(i));
    [recon(i), requiresSupport(i), infoLost(i)] = classifyReconstruction(obs, basisNames, catalogNames, deps);
end

tbl = table( ...
    string(catalogKeys.observable_name), ...
    string(catalogKeys.experiment), ...
    recon, ...
    requiresSupport, ...
    infoLost, ...
    'VariableNames', {'observable_name','experiment','reconstructable_from_basis','requires_support_observable','physical_information_lost_if_removed'});

tbl = sortrows(tbl, {'experiment','observable_name'});
end

function [status, supportFlag, infoLost] = classifyReconstruction(obs, basisNames, catalogNames, deps)
obsNorm = lower(strtrim(obs));
basisNorm = lower(strtrim(basisNames));
catalogNorm = lower(strtrim(catalogNames));

supportFlag = false;

if any(obsNorm == basisNorm)
    status = "RECONSTRUCTABLE_FROM_BASIS";
else
        depTargets = strings(numel(deps), 1);
        for di = 1:numel(deps)
            depTargets(di) = lower(strtrim(deps{di}.target));
        end
        depIdx = find(depTargets == obsNorm, 1, 'first');
    if isempty(depIdx)
        status = "NOT_RECONSTRUCTABLE";
    else
            depList = lower(strtrim(deps{depIdx}.dependencies));
        inBasis = all(ismember(depList, basisNorm));
        inCatalog = all(ismember(depList, catalogNorm));
        if inBasis
            status = "RECONSTRUCTABLE_FROM_BASIS";
        elseif inCatalog
            status = "PARTIALLY_RECONSTRUCTABLE";
        else
            status = "NOT_RECONSTRUCTABLE";
        end
    end
end

switch obsNorm
    case {'tau_dip','tau_fm'}
        infoLost = "clock information";
        supportFlag = true;
    case {'i_peak','width','s_peak'}
        infoLost = "geometry information; activation information; susceptibility structure";
        supportFlag = true;
    case {'a1'}
        infoLost = "susceptibility structure";
    case {'kappa'}
        infoLost = "geometry information";
    case {'chi_ridge'}
        infoLost = "susceptibility structure";
    case {'a'}
        infoLost = "activation information";
    case {'x'}
        infoLost = "activation information; geometry information";
    case {'r'}
        infoLost = "clock information";
    otherwise
        infoLost = "unspecified";
end

if status == "NOT_RECONSTRUCTABLE" && ~any(obsNorm == basisNorm)
    supportFlag = true;
end
end

function tbl = buildRequiredSupportTable(reconTbl)
mask = reconTbl.requires_support_observable & ~(lower(string(reconTbl.observable_name)) == "x") ...
    & ~(lower(string(reconTbl.observable_name)) == "a") ...
    & ~(lower(string(reconTbl.observable_name)) == "kappa") ...
    & ~(lower(string(reconTbl.observable_name)) == "chi_ridge") ...
    & ~(lower(string(reconTbl.observable_name)) == "r");

sub = reconTbl(mask, :);
if isempty(sub)
    tbl = table(strings(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', {'observable_name','experiment','reason'});
    return;
end

reason = strings(height(sub),1);
for i = 1:height(sub)
    reason(i) = "Required support observable: " + sub.physical_information_lost_if_removed(i);
end

tbl = table(string(sub.observable_name), string(sub.experiment), reason, ...
    'VariableNames', {'observable_name','experiment','reason'});
tbl = unique(tbl, 'rows', 'stable');
tbl = sortrows(tbl, {'experiment','observable_name'});
end

function tbl = buildDependencyGraphTable(deps)
target = strings(0,1);
dependency = strings(0,1);
rule_type = strings(0,1);
relation = strings(0,1);

for i = 1:numel(deps)
    d = deps{i};
    for j = 1:numel(d.dependencies)
        target(end+1,1) = d.target; %#ok<AGROW>
        dependency(end+1,1) = d.dependencies(j); %#ok<AGROW>
        rule_type(end+1,1) = d.rule_type; %#ok<AGROW>
        relation(end+1,1) = d.relation; %#ok<AGROW>
    end
end

tbl = table(target, dependency, rule_type, relation);
end

function tbl = buildEffectiveQuantitiesTable(basisNames, catalogNames)
names = [ ...
    "ridge motion"; ...
    "ridge broadening"; ...
    "motion/broadening ratio"; ...
    "activation proxy"; ...
    "temperature derivatives"; ...
    "relaxation activity A(T)"; ...
    "relaxation local activation proxy"; ...
    "aging absolute clocks" ...
    ];

requires = [ ...
    "I_peak"; ...
    "width"; ...
    "I_peak,width"; ...
    "X"; ...
    "I_peak,width,S_peak,A"; ...
    "A"; ...
    "A"; ...
    "tau_dip,tau_FM" ...
    ];

canDerive = false(size(names));
notes = strings(size(names));

basisNorm = lower(strtrim(string(basisNames)));
catalogNorm = lower(strtrim(string(catalogNames)));

for i = 1:numel(names)
    deps = split(string(requires(i)), ',');
    deps = lower(strtrim(deps));
    deps = deps(strlength(deps) > 0);
    inBasis = all(ismember(deps, basisNorm));
    inCatalog = all(ismember(deps, catalogNorm));
    canDerive(i) = inBasis;
    if inBasis
        notes(i) = "Derivable from minimal basis.";
    elseif inCatalog
        notes(i) = "Needs support observables beyond minimal basis.";
    else
        notes(i) = "Not available from current catalog.";
    end
end

tbl = table(names, requires, canDerive, notes, ...
    'VariableNames', {'effective_quantity','required_observables','derivable_from_minimal_basis','note'});
end

function textOut = buildReportText(minimalTbl, roleTbl, summaryTbl, reconTbl, supportTbl, graphTbl, effectiveTbl, input, runDir)
line = strings(0,1);
line(end+1) = '# Observable Physics Completeness Audit';
line(end+1) = '';
line(end+1) = 'Generated: ' + string(stampNow());
line(end+1) = 'Reduction source run: `' + string(input.reductionRunId) + '`';
line(end+1) = 'Catalog source run: `' + string(input.catalogRunId) + '`';
line(end+1) = 'Reduction run dir: `' + string(runDir) + '`';
line(end+1) = '';

line(end+1) = '## Minimal observable basis';
for i = 1:height(minimalTbl)
    line(end+1) = '- `' + string(minimalTbl.observable_name(i)) + '` (' + string(minimalTbl.experiment(i)) + ')';
end
line(end+1) = '';

line(end+1) = '## Dependency graph';
line(end+1) = '- `X <- I_peak, width, S_peak`';
line(end+1) = '- `a1 <- S_peak` (approx derivative relation)';
line(end+1) = '- `R <- tau_FM, tau_dip`';
line(end+1) = '';

line(end+1) = '## Reconstruction analysis';
for i = 1:height(reconTbl)
    line(end+1) = '- `' + string(reconTbl.observable_name(i)) + '` (' + string(reconTbl.experiment(i)) + '): ' + ...
        string(reconTbl.reconstructable_from_basis(i)) + ', support=' + string(reconTbl.requires_support_observable(i));
end
line(end+1) = '';

line(end+1) = '## Effective physical quantities';
for i = 1:height(effectiveTbl)
    line(end+1) = '- `' + string(effectiveTbl.effective_quantity(i)) + '` requires `' + string(effectiveTbl.required_observables(i)) + ...
        '`: derivable_from_basis=' + string(effectiveTbl.derivable_from_minimal_basis(i)) + ' (' + string(effectiveTbl.note(i)) + ')';
end
line(end+1) = '';

line(end+1) = '## Required support observables';
if isempty(supportTbl)
    line(end+1) = '- None';
else
    for i = 1:height(supportTbl)
        line(end+1) = '- `' + string(supportTbl.observable_name(i)) + '` (' + string(supportTbl.experiment(i)) + '): ' + string(supportTbl.reason(i));
    end
end
line(end+1) = '';

line(end+1) = '## Final recommended observable architecture';
line(end+1) = '- Core minimal basis: `X, A, kappa, chi_ridge, R`';
if isempty(supportTbl)
    line(end+1) = '- Required support observables: none';
else
    supportNames = unique(string(supportTbl.observable_name), 'stable');
    line(end+1) = '- Required support observables: `' + strjoin(supportNames, ', ') + '`';
end
line(end+1) = '- Recommendation: keep support observables in catalog for reconstruction, derivative physics, and absolute-clock interpretability, while treating minimal basis as paper-level core descriptors.';

if ~isempty(roleTbl)
    line(end+1) = '';
    line(end+1) = '## Role classification snapshot';
    for i = 1:height(roleTbl)
        line(end+1) = '- `' + string(roleTbl.observable_name(i)) + '` role=' + string(roleTbl.role(i)) + ' (' + string(roleTbl.experiment(i)) + ')';
    end
end

if ~isempty(summaryTbl) && all(ismember({'observable_name','experiment','N_points','temperature_range'}, summaryTbl.Properties.VariableNames))
    line(end+1) = '';
    line(end+1) = '## Catalog summary snapshot';
    for i = 1:height(summaryTbl)
        line(end+1) = '- `' + string(summaryTbl.observable_name(i)) + '` (' + string(summaryTbl.experiment(i)) + '): N=' + ...
            string(summaryTbl.N_points(i)) + ', T=' + string(summaryTbl.temperature_range(i));
    end
end

line(end+1) = '';
line(end+1) = '## Output tables';
line(end+1) = '- `tables/observable_reconstruction_matrix.csv`';
line(end+1) = '- `tables/required_support_observables.csv`';
line(end+1) = '- `tables/dependency_graph_edges.csv`';
line(end+1) = '- `tables/effective_physical_quantities_audit.csv`';

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
    fullfile('tables', 'observable_reconstruction_matrix.csv'), ...
    fullfile('tables', 'required_support_observables.csv'), ...
    fullfile('tables', 'dependency_graph_edges.csv'), ...
    fullfile('tables', 'effective_physical_quantities_audit.csv'), ...
    fullfile('reports', 'observable_physics_completeness_report.md'), ...
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

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end