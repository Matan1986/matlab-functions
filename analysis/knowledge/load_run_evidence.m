function evidence = load_run_evidence(run_id)
% load_run_evidence
%   Loads existing run evidence file paths (tables + reports) from
%   analysis/knowledge/run_registry.csv.
%
% Returns a struct with:
%   evidence.run_id
%   evidence.path              (absolute run folder; empty if unresolved)
%   evidence.tables           (cellstr of absolute csv paths)
%   evidence.report           (cellstr of absolute md paths)
%   evidence.snapshot         (struct with snapshot linkage metadata)
%   evidence.resolution_method

if nargin < 1 || isempty(run_id)
    error('load_run_evidence requires a non-empty run_id.');
end

run_id = string(run_id);

persistent repoRoot registryPath regTable
if isempty(repoRoot)
    repoRoot = resolveRepoRoot();
    registryPath = fullfile(repoRoot, 'analysis', 'knowledge', 'run_registry.csv');
    if exist(registryPath, 'file') ~= 2
        error('run_registry.csv not found: %s', registryPath);
    end
    regTable = readtable(registryPath, 'Delimiter', ',', 'TextType', 'string');
end

if ~ismember('run_id', regTable.Properties.VariableNames)
    error('run_registry.csv missing expected column: run_id');
end

idx = find(regTable.run_id == run_id, 1, 'first');
if isempty(idx)
    error('Unknown run_id (not in registry): %s', run_id);
end

run_rel_path = string(regTable.run_rel_path(idx));
tables_csv = string(regTable.tables_csv(idx));
reports_md = string(regTable.reports_md(idx));

runAbsPath = "";
if strlength(run_rel_path) > 0
    run_rel_path = strrep(run_rel_path, '/', '\');
    runAbsPath = fullfile(repoRoot, char(run_rel_path));
end

tables = cell(0, 1);
if strlength(tables_csv) > 0
    parts = split(tables_csv, ';');
    parts = parts(parts ~= "");
    tables = cell(numel(parts), 1);
    for i = 1:numel(parts)
        relp = strrep(char(parts(i)), '/', '\');
        if strlength(runAbsPath) > 0
            tables{i} = fullfile(runAbsPath, relp);
        else
            tables{i} = "";
        end
    end
end

report = cell(0, 1);
if strlength(reports_md) > 0
    parts = split(reports_md, ';');
    parts = parts(parts ~= "");
    report = cell(numel(parts), 1);
    for i = 1:numel(parts)
        relp = strrep(char(parts(i)), '/', '\');
        if strlength(runAbsPath) > 0
            report{i} = fullfile(runAbsPath, relp);
        else
            report{i} = "";
        end
    end
end

snapshot = struct();
snapshot.source_run_path = safeGet(regTable, idx, 'snapshot_source_run_path');
snapshot.runpack_path = safeGet(regTable, idx, 'snapshot_runpack_path');
snapshot.analysis_ids = splitSemicolon(safeGet(regTable, idx, 'snapshot_analysis_ids'));
snapshot.report_ids = splitSemicolon(safeGet(regTable, idx, 'snapshot_report_ids'));
snapshot.has_entry = string(safeGet(regTable, idx, 'snapshot_has_entry'));

evidence = struct();
evidence.run_id = run_id;
evidence.path = runAbsPath;
evidence.tables = tables;
evidence.report = report;
evidence.snapshot = snapshot;
evidence.resolution_method = safeGet(regTable, idx, 'resolution_method');

end

function s = safeGet(T, idx, colName)
if ~ismember(colName, T.Properties.VariableNames)
    s = "";
    return;
end
v = T.(colName)(idx);
s = string(v);
end

function parts = splitSemicolon(s)
s = string(s);
if strlength(s) == 0
    parts = strings(0, 1);
    return;
end
parts = split(s, ';');
parts = parts(parts ~= "");
end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);       % analysis/knowledge
repoRoot = fileparts(toolsDir);       % analysis
repoRoot = fileparts(repoRoot);      % repo root
end

