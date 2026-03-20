function out = observable_catalog_completion(cfg)
% observable_catalog_completion
% Aggregate canonical physical observables from existing immutable run
% outputs across Aging, Relaxation, Switching, and cross-experiment areas.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Observable catalog completion run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] observable catalog completion started\n', stampNow()));

specs = canonicalSpecs();
[catalogRows, sourceRegistry, missing] = collectCanonicalObservables(repoRoot, specs);

catalogTbl = rowsToCatalogTable(catalogRows);
summaryTbl = buildSummaryTable(catalogTbl);

catalogPath = save_run_table(catalogTbl, 'observable_catalog.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'observable_summary.csv', runDir);

reportText = buildReportText(run, catalogTbl, summaryTbl, sourceRegistry, missing);
reportPath = save_run_report(reportText, 'observable_catalog_report.md', runDir);

zipPath = buildReviewZip(runDir, 'observable_catalog_bundle.zip');

appendText(run.log_path, sprintf('catalog_path: %s\n', catalogPath));
appendText(run.log_path, sprintf('summary_path: %s\n', summaryPath));
appendText(run.log_path, sprintf('report_path: %s\n', reportPath));
appendText(run.log_path, sprintf('review_zip: %s\n', zipPath));
appendText(run.log_path, sprintf('missing_observable_count: %d\n', numel(missing)));
appendText(run.log_path, sprintf('[%s] observable catalog completion complete\n', stampNow()));

out = struct();
out.run = run;
out.catalog = catalogTbl;
out.summary = summaryTbl;
out.missing_observables = string(missing(:));
out.paths = struct( ...
    'catalog', string(catalogPath), ...
    'summary', string(summaryPath), ...
    'report', string(reportPath), ...
    'bundle', string(zipPath));

observableList = unique(string(catalogTbl.observable_name), 'stable');

fprintf('RUN_ID=%s\n', run.run_id);
fprintf('Number_of_observables=%d\n', numel(observableList));
fprintf('Total_data_points=%d\n', height(catalogTbl));
fprintf('List_of_observables_in_catalog=%s\n', strjoin(cellstr(observableList), ', '));
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'observable_catalog_completion');
end

function specs = canonicalSpecs()
specs = { ...
    makeSpec( ...
    'I_peak', 'switching', {'switching_effective_observables_table.csv'}, ...
    {'I_peak_mA', 'Ipeak_mA'}, {'T_K', 'Temp_K', 'temperature_K'}, 'mA'), ...
    makeSpec( ...
    'width', 'switching', {'switching_effective_observables_table.csv'}, ...
    {'width_mA', 'width_chosen_mA'}, {'T_K', 'Temp_K', 'temperature_K'}, 'mA'), ...
    makeSpec( ...
    'S_peak', 'switching', {'switching_effective_observables_table.csv'}, ...
    {'S_peak'}, {'T_K', 'Temp_K', 'temperature_K'}, 'arb.'), ...
    makeSpec( ...
    'X', 'switching', {'switching_effective_observables_table.csv', 'ridge_susceptibility_vs_temperature.csv'}, ...
    {'X', 'X_T', 'x_value'}, {'T_K', 'Temp_K', 'temperature_K'}, 'arb.'), ...
    makeSpec( ...
    'kappa', 'switching', {'ridge_curvature_vs_T.csv', 'ridge_curvature_diagnostics.csv'}, ...
    {'kappa', 'kappa_signed_norm', 'kappa_norm'}, {'T_K', 'Temp_K', 'temperature_K'}, '1/mA^2'), ...
    makeSpec( ...
    'chi_ridge', 'switching', {'ridge_susceptibility_vs_temperature.csv', 'susceptibility_observables.csv'}, ...
    {'chi_ridge_max', 'chi_ridge_mean', 'chi_dyn_ridge'}, {'T_K', 'Temp_K', 'temperature_K'}, '1/K'), ...
    makeSpec( ...
    'a1', 'switching', {'ridge_susceptibility_vs_temperature.csv', 'a1_vs_mobility_series.csv', 'switching_dynamic_shape_mode_amplitudes.csv'}, ...
    {'a1', 'a_1', 'mode1_amplitude'}, {'T_K', 'Temp_K', 'temperature_K'}, 'arb.'), ...
    makeSpec( ...
    'A', 'relaxation', {'temperature_observables.csv', 'new_relaxation_observables_vs_T.csv'}, ...
    {'A_T', 'A'}, {'T_K', 'T', 'Temp_K', 'temperature_K'}, 'arb.'), ...
    makeSpec( ...
    'tau_dip', 'aging', {'clock_ratio_data.csv', 'table_clock_ratio.csv', 'tau_vs_Tp.csv'}, ...
    {'tau_dip_seconds', 'tau_dip'}, {'T_K', 'Tp', 'Tp_K', 'temperature_K'}, 's'), ...
    makeSpec( ...
    'tau_FM', 'aging', {'clock_ratio_data.csv', 'table_clock_ratio.csv', 'tau_FM_vs_Tp.csv'}, ...
    {'tau_FM_seconds', 'tau_FM'}, {'T_K', 'Tp', 'Tp_K', 'temperature_K'}, 's'), ...
    makeSpec( ...
    'R', 'aging', {'clock_ratio_data.csv', 'table_clock_ratio.csv'}, ...
    {'R', 'R_tau_FM_over_tau_dip'}, {'T_K', 'Tp', 'Tp_K', 'temperature_K'}, 'dimensionless') ...
    };
end

function spec = makeSpec(name, expName, tableCandidates, valueCandidates, tempCandidates, units)
spec = struct();
spec.observable_name = string(name);
spec.experiment = string(expName);
spec.table_candidates = string(tableCandidates(:));
spec.value_candidates = string(valueCandidates(:));
spec.temp_candidates = string(tempCandidates(:));
spec.units = string(units);
end

function [rows, sourceRegistry, missing] = collectCanonicalObservables(repoRoot, specs)
rows = repmat(struct( ...
    'observable_name', "", ...
    'experiment', "", ...
    'temperature_K', NaN, ...
    'value', NaN, ...
    'units', "", ...
    'source_run', ""), 0, 1);

sourceRegistry = repmat(struct( ...
    'observable_name', "", ...
    'experiment', "", ...
    'source_run', "", ...
    'source_file', "", ...
    'value_column', "", ...
    'temperature_column', ""), 0, 1);

missing = strings(0, 1);

for i = 1:numel(specs)
    spec = specs{i};
    [tbl, sourceFile, sourceRun, valueCol, tempCol] = findObservableTable(repoRoot, spec);
    if isempty(tbl)
        missing(end + 1, 1) = spec.observable_name; %#ok<AGROW>
        continue;
    end

    tVals = toDoubleColumn(tbl.(tempCol));
    yVals = toDoubleColumn(tbl.(valueCol));
    mask = isfinite(tVals) & isfinite(yVals);
    tVals = tVals(mask);
    yVals = yVals(mask);

    if isempty(tVals)
        missing(end + 1, 1) = spec.observable_name; %#ok<AGROW>
        continue;
    end

    [tVals, ord] = sort(tVals);
    yVals = yVals(ord);

    for r = 1:numel(tVals)
        rows(end + 1, 1).observable_name = spec.observable_name; %#ok<AGROW>
        rows(end, 1).experiment = spec.experiment;
        rows(end, 1).temperature_K = tVals(r);
        rows(end, 1).value = yVals(r);
        rows(end, 1).units = spec.units;
        rows(end, 1).source_run = sourceRun;
    end

    sourceRegistry(end + 1, 1).observable_name = spec.observable_name; %#ok<AGROW>
    sourceRegistry(end, 1).experiment = spec.experiment;
    sourceRegistry(end, 1).source_run = sourceRun;
    sourceRegistry(end, 1).source_file = string(sourceFile);
    sourceRegistry(end, 1).value_column = string(valueCol);
    sourceRegistry(end, 1).temperature_column = string(tempCol);
end

if ~isempty(rows)
    tbl = rowsToCatalogTable(rows);
    tbl = sortrows(tbl, {'experiment', 'observable_name', 'temperature_K', 'source_run'});
    rows = tableToRows(tbl);
end

if ~isempty(sourceRegistry)
    srcTbl = struct2table(sourceRegistry);
    srcTbl = unique(srcTbl, 'rows', 'stable');
    sourceRegistry = table2struct(srcTbl);
end

missing = unique(missing, 'stable');
end

function [tbl, sourceFile, sourceRun, valueCol, tempCol] = findObservableTable(repoRoot, spec)
tbl = table();
sourceFile = '';
sourceRun = '';
valueCol = '';
tempCol = '';

expRoot = fullfile(repoRoot, 'results', char(spec.experiment), 'runs');
if exist(expRoot, 'dir') ~= 7
    return;
end

for c = 1:numel(spec.table_candidates)
    pat = char(spec.table_candidates(c));
    files = dir(fullfile(expRoot, 'run_*', 'tables', pat));
    if isempty(files)
        continue;
    end

    runs = strings(numel(files), 1);
    for k = 1:numel(files)
        parts = splitPath(files(k).folder);
        runIdx = find(startsWith(parts, "run_"), 1, 'last');
        if isempty(runIdx)
            runs(k) = "";
        else
            runs(k) = parts(runIdx);
        end
    end
    [~, order] = sort(runs, 'descend');
    files = files(order);
    runs = runs(order);

    for k = 1:numel(files)
        candidateFile = fullfile(files(k).folder, files(k).name);
        candidateRun = runs(k);
        try
            tCandidate = readtable(candidateFile, 'TextType', 'string');
        catch
            continue;
        end

        vCol = pickFirstExistingColumn(tCandidate, spec.value_candidates);
        tCol = pickFirstExistingColumn(tCandidate, spec.temp_candidates);
        if strlength(vCol) == 0 || strlength(tCol) == 0
            continue;
        end

        vVals = toDoubleColumn(tCandidate.(char(vCol)));
        tVals = toDoubleColumn(tCandidate.(char(tCol)));
        finiteCount = nnz(isfinite(vVals) & isfinite(tVals));
        if finiteCount < 1
            continue;
        end

        tbl = tCandidate;
        sourceFile = candidateFile;
        sourceRun = char(candidateRun);
        valueCol = char(vCol);
        tempCol = char(tCol);
        return;
    end
end
end

function col = pickFirstExistingColumn(tbl, candidateNames)
col = "";
varNames = string(tbl.Properties.VariableNames);
for i = 1:numel(candidateNames)
    hit = candidateNames(i);
    if any(strcmp(varNames, hit))
        col = hit;
        return;
    end
end
end

function v = toDoubleColumn(x)
if isnumeric(x)
    v = double(x);
elseif isstring(x)
    v = str2double(x);
elseif iscell(x)
    v = str2double(string(x));
else
    try
        v = double(x);
    catch
        v = NaN(size(x));
    end
end
v = v(:);
end

function tbl = rowsToCatalogTable(rows)
if isempty(rows)
    tbl = table( ...
        strings(0,1), strings(0,1), NaN(0,1), NaN(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', {'observable_name','experiment','temperature_K','value','units','source_run'});
    return;
end

tbl = struct2table(rows);
tbl.observable_name = string(tbl.observable_name);
tbl.experiment = string(tbl.experiment);
tbl.units = string(tbl.units);
tbl.source_run = string(tbl.source_run);
tbl.temperature_K = double(tbl.temperature_K);
tbl.value = double(tbl.value);

tbl = tbl(:, {'observable_name','experiment','temperature_K','value','units','source_run'});
end

function rows = tableToRows(tbl)
rows = repmat(struct( ...
    'observable_name', "", ...
    'experiment', "", ...
    'temperature_K', NaN, ...
    'value', NaN, ...
    'units', "", ...
    'source_run', ""), height(tbl), 1);

for i = 1:height(tbl)
    rows(i).observable_name = string(tbl.observable_name(i));
    rows(i).experiment = string(tbl.experiment(i));
    rows(i).temperature_K = double(tbl.temperature_K(i));
    rows(i).value = double(tbl.value(i));
    rows(i).units = string(tbl.units(i));
    rows(i).source_run = string(tbl.source_run(i));
end
end

function summaryTbl = buildSummaryTable(catalogTbl)
if isempty(catalogTbl)
    summaryTbl = table( ...
        strings(0,1), strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', {'observable_name','experiment','N_points','temperature_range','source_runs'});
    return;
end

groups = unique(catalogTbl(:, {'observable_name', 'experiment'}), 'rows', 'stable');
n = height(groups);

N_points = zeros(n, 1);
temperature_range = strings(n, 1);
source_runs = strings(n, 1);

for i = 1:n
    m = catalogTbl.observable_name == groups.observable_name(i) & ...
        catalogTbl.experiment == groups.experiment(i);
    sub = catalogTbl(m, :);

    N_points(i) = height(sub);
    temperature_range(i) = fmtRange(sub.temperature_K);
    source_runs(i) = strjoin(unique(string(sub.source_run), 'stable'), '; ');
end

summaryTbl = table( ...
    string(groups.observable_name), ...
    string(groups.experiment), ...
    N_points, ...
    temperature_range, ...
    source_runs, ...
    'VariableNames', {'observable_name','experiment','N_points','temperature_range','source_runs'});

summaryTbl = sortrows(summaryTbl, {'experiment', 'observable_name'});
end

function txt = buildReportText(run, catalogTbl, summaryTbl, sourceRegistry, missing)
lines = strings(0, 1);
lines(end + 1) = '# Observable Catalog Completion';
lines(end + 1) = '';
lines(end + 1) = 'Generated: ' + string(stampNow());
lines(end + 1) = 'Run id: `' + string(run.run_id) + '`';
lines(end + 1) = 'Run dir: `' + string(run.run_dir) + '`';
lines(end + 1) = '';
lines(end + 1) = '## Included observables';
if isempty(catalogTbl)
    lines(end + 1) = '- None';
else
    obsNames = unique(string(catalogTbl.observable_name), 'stable');
    for i = 1:numel(obsNames)
        lines(end + 1) = '- `' + obsNames(i) + '`';
    end
end

lines(end + 1) = '';
lines(end + 1) = '## Source runs and temperature coverage';
if isempty(summaryTbl)
    lines(end + 1) = '- No summary rows generated.';
else
    for i = 1:height(summaryTbl)
        lines(end + 1) = '- `' + summaryTbl.observable_name(i) + '` (' + ...
            summaryTbl.experiment(i) + '): N=' + string(summaryTbl.N_points(i)) + ...
            ', T=' + summaryTbl.temperature_range(i) + ...
            ', runs=' + summaryTbl.source_runs(i);
    end
end

lines(end + 1) = '';
lines(end + 1) = '## Source file registry';
if isempty(sourceRegistry)
    lines(end + 1) = '- No source files resolved.';
else
    srcTbl = struct2table(sourceRegistry);
    for i = 1:height(srcTbl)
        lines(end + 1) = '- `' + srcTbl.observable_name(i) + '` from `' + ...
            srcTbl.source_run(i) + '` table `' + string(srcTbl.source_file(i)) + ...
            '` columns (`' + srcTbl.temperature_column(i) + '`, `' + srcTbl.value_column(i) + '`)';
    end
end

lines(end + 1) = '';
lines(end + 1) = '## Missing data';
if isempty(missing)
    lines(end + 1) = '- None';
else
    for i = 1:numel(missing)
        lines(end + 1) = '- `' + missing(i) + '` (no usable table/columns with finite temperature and value)';
    end
end

lines(end + 1) = '';
lines(end + 1) = '## Notes on derived quantities';
lines(end + 1) = '- `X` is treated as the precomputed switching composite observable (`I_peak/(width*S_peak)`) and is read directly from run tables.';
lines(end + 1) = '- `R` is treated as the precomputed aging clock ratio (`tau_FM/tau_dip`) and is read directly from run tables.';
lines(end + 1) = '- No observables are recomputed in this script; all values are loaded from existing immutable run outputs.';

txt = strjoin(lines, newline);
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
    fullfile('tables', 'observable_catalog.csv'), ...
    fullfile('tables', 'observable_summary.csv'), ...
    fullfile('reports', 'observable_catalog_report.md'), ...
    'run_manifest.json', ...
    'config_snapshot.m', ...
    'log.txt', ...
    'run_notes.txt'}, runDir);
end

function p = splitPath(pathValue)
normPath = strrep(char(pathValue), '/', filesep);
parts = regexp(normPath, '[\\/]+', 'split');
parts = string(parts(~cellfun(@isempty, cellstr(parts))));
p = parts(:);
end

function txt = fmtRange(x)
x = x(isfinite(x));
if isempty(x)
    txt = 'NaN';
    return;
end
txt = sprintf('%.3g-%.3g', min(x), max(x));
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