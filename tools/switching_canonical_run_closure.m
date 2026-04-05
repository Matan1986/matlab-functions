function switching_canonical_run_closure()
% switching_canonical_run_closure Compare existing Switching *_switching_canonical runs (no science changes).
%
% Writes:
%   tables/switching_canonical_run_closure.csv
%   tables/switching_canonical_run_closure_status.csv
%   reports/switching_canonical_run_closure.md

repoRoot = fileparts(fileparts(mfilename('fullpath')));
runsRoot = fullfile(repoRoot, 'results', 'Switching', 'runs');

d = dir(fullfile(runsRoot, '*_switching_canonical'));
runDirs = {};
for i = 1:numel(d)
    if d(i).isdir
        runDirs{end+1, 1} = fullfile(runsRoot, d(i).name); %#ok<AGROW>
    end
end
runDirs = sort(runDirs(:));

n = numel(runDirs);
infos = repmat(struct('run_id', '', 'path', '', 'exec_success', false, 'exec_legacy_ok', false, ...
    'artifact_ok', false, 'core_tables_ok', false, 'markers_ok', false, 'candidate', false), n, 1);

for i = 1:n
    rd = runDirs{i};
    [~, runId, ~] = fileparts(rd);
    infos(i).run_id = runId;
    infos(i).path = rd;
    [ss, leg] = local_parse_execution_status(rd);
    infos(i).exec_success = ss;
    infos(i).exec_legacy_ok = leg;
    infos(i).artifact_ok = local_artifact_ok(rd);
    infos(i).core_tables_ok = local_core_tables_ok(rd);
    infos(i).markers_ok = local_markers_ok(rd);
    infos(i).candidate = ss && infos(i).artifact_ok && infos(i).markers_ok && infos(i).core_tables_ok;
end

candIdx = find([infos.candidate]);
if isempty(candIdx)
    candIdx = find([infos.exec_success] & [infos.artifact_ok] & [infos.core_tables_ok]);
end
if isempty(candIdx)
    candIdx = find([infos.exec_success] & [infos.artifact_ok]);
end
if isempty(candIdx)
    candIdx = find(([infos.exec_success] | [infos.exec_legacy_ok]) & [infos.artifact_ok] & [infos.core_tables_ok]);
end
if isempty(candIdx)
    candIdx = find(([infos.exec_success] | [infos.exec_legacy_ok]) & [infos.artifact_ok]);
end

sourceIdx = [];
if ~isempty(candIdx)
    runIds = {infos(candIdx).run_id};
    [~, ord] = sort(runIds);
    sourceIdx = candIdx(ord(end));
end

pairRows = local_pairwise_vs_source(repoRoot, infos, sourceIdx);

closureRows = local_build_closure_rows(infos, sourceIdx);

[dupCount, driftCount, systemLocked] = local_counts(closureRows);

local_write_closure_csv(repoRoot, closureRows);
local_write_status_csv(repoRoot, ~isempty(sourceIdx), dupCount, driftCount, systemLocked);
local_write_report_md(repoRoot, infos, sourceIdx, pairRows, dupCount, driftCount, systemLocked);

if ~isempty(sourceIdx)
    fprintf('CANONICAL_RUN_ID=%s\n', infos(sourceIdx).run_id);
else
    fprintf('CANONICAL_RUN_ID=\n');
end
fprintf('DUPLICATE_COUNT=%d\n', dupCount);
fprintf('DRIFT_COUNT=%d\n', driftCount);
fprintf('SYSTEM_FULLY_LOCKED=%s\n', systemLocked);
end

function [strictSuccess, legacyOk] = local_parse_execution_status(runDir)
strictSuccess = false;
legacyOk = false;
p = fullfile(runDir, 'execution_status.csv');
if exist(p, 'file') ~= 2
    return;
end
txt = local_normalize_eol(fileread(p));
lines = splitlines(strtrim(txt));
if numel(lines) < 2
    return;
end
header = local_split_csv_header(lines{1});
row2 = lines{2};
if any(strcmp(header, 'EXECUTION_STATUS'))
    parts = strsplit(row2, ',');
    if ~isempty(parts)
        v = upper(strtrim(parts{1}));
        strictSuccess = strcmp(v, 'SUCCESS');
    end
    return;
end
if any(strcmp(header, 'EXECUTION_STARTED')) && any(strcmp(header, 'WRITE_SUCCESS'))
    parts = strsplit(row2, ',');
    if numel(parts) < 2
        return;
    end
    es = strcmp(upper(strtrim(parts{1})), 'YES');
    ws = strcmp(upper(strtrim(parts{2})), 'YES');
    err = '';
    if numel(parts) >= 3
        err = strtrim(parts{3});
    end
    legacyOk = es && ws && isempty(err);
end
end

function s = local_normalize_eol(txt)
s = strrep(strrep(txt, sprintf('\r\n'), sprintf('\n')), sprintf('\r'), sprintf('\n'));
end

function cols = local_split_csv_header(line)
cols = strtrim(strsplit(line, ','));
end

function ok = local_artifact_ok(runDir)
ok = false;
if exist(fullfile(runDir, 'execution_status.csv'), 'file') ~= 2
    return;
end
td = fullfile(runDir, 'tables');
rd = fullfile(runDir, 'reports');
if exist(td, 'dir') ~= 7 || exist(rd, 'dir') ~= 7
    return;
end
if isempty(dir(fullfile(td, '*.csv')))
    return;
end
if isempty(dir(fullfile(rd, '*.md')))
    return;
end
ok = true;
end

function ok = local_core_tables_ok(runDir)
ok = false;
files = {'switching_canonical_phi1.csv', 'switching_canonical_observables.csv', 'switching_canonical_validation.csv'};
for i = 1:numel(files)
    if exist(fullfile(runDir, 'tables', files{i}), 'file') ~= 2
        return;
    end
end
ok = true;
end

function ok = local_markers_ok(runDir)
ok = false;
p = fullfile(runDir, 'runtime_execution_markers.txt');
if exist(p, 'file') ~= 2
    return;
end
txt = fileread(p);
lines = splitlines(txt);
marks = strings(0, 1);
for i = 1:numel(lines)
    ln = strtrim(lines(i));
    if strlength(ln) == 0
        continue;
    end
    parts = split(ln);
    if ~isempty(parts)
        marks(end+1, 1) = parts(end); %#ok<AGROW>
    end
end
ok = any(marks == "ENTRY") && any(marks == "COMPLETED");
end

function pairRows = local_pairwise_vs_source(repoRoot, infos, sourceIdx)
pairRows = {};
if isempty(sourceIdx)
    return;
end
base = infos(sourceIdx).path;
files = {'switching_canonical_phi1.csv', 'switching_canonical_observables.csv', 'switching_canonical_validation.csv'};
for i = 1:numel(infos)
    if i == sourceIdx
        continue;
    end
    other = infos(i).path;
    row = struct('run_b', infos(i).run_id, 'phi1_rmse', 'NA', 'obs_rmse', 'NA', 'val_rmse', 'NA', ...
        'max_rmse', 'NA', 'exact_all', 'NO', 'note', '');
    miss = false;
    for f = 1:numel(files)
        if exist(fullfile(other, 'tables', files{f}), 'file') ~= 2
            miss = true;
        end
    end
    if miss
        row.note = 'missing_tables';
        pairRows{end+1, 1} = row; %#ok<AGROW>
        continue;
    end
    try
        [pRmse, pEx] = local_cmp_phi1(fullfile(base, 'tables', files{1}), fullfile(other, 'tables', files{1}));
        [oRmse, oEx] = local_cmp_obs(fullfile(base, 'tables', files{2}), fullfile(other, 'tables', files{2}));
        [vRmse, vEx] = local_cmp_val(fullfile(base, 'tables', files{3}), fullfile(other, 'tables', files{3}));
        mx = max([pRmse, oRmse, vRmse], [], 'omitnan');
        ex = pEx && oEx && vEx;
        row.phi1_rmse = sprintf('%.16g', pRmse);
        row.obs_rmse = sprintf('%.16g', oRmse);
        row.val_rmse = sprintf('%.16g', vRmse);
        row.max_rmse = sprintf('%.16g', mx);
        row.exact_all = ternary(ex, 'YES', 'NO');
    catch ME
        row.note = char(ME.message);
    end
    pairRows{end+1, 1} = row; %#ok<AGROW>
end
end

function [rmse, exact] = local_cmp_phi1(p1, p2)
t1 = local_normalize_eol(fileread(p1));
t2 = local_normalize_eol(fileread(p2));
if strcmp(t1, t2)
    rmse = 0;
    exact = true;
    return;
end
[Acur, Aphi] = local_parse_phi1(p1);
[Bcur, Bphi] = local_parse_phi1(p2);
if isempty(Acur) || isempty(Bcur) || numel(Acur) ~= numel(Bcur)
    rmse = NaN;
    exact = false;
    return;
end
[Acur, ordA] = sort(Acur);
Aphi = Aphi(ordA);
[Bcur, ordB] = sort(Bcur);
Bphi = Bphi(ordB);
if ~isequal(Acur, Bcur)
    rmse = NaN;
    exact = false;
    return;
end
v = abs(Aphi - Bphi);
rmse = sqrt(mean(v .^ 2, 'omitnan'));
exact = all(v < 1e-12 | (isnan(Aphi) & isnan(Bphi)));
end

function [c, phi] = local_parse_phi1(p)
txt = local_normalize_eol(fileread(p));
lines = splitlines(strtrim(txt));
if numel(lines) < 2
    c = [];
    phi = [];
    return;
end
n = numel(lines) - 1;
c = zeros(n, 1);
phi = zeros(n, 1);
for i = 2:numel(lines)
    parts = strsplit(lines{i}, ',');
    if numel(parts) < 2
        c = [];
        phi = [];
        return;
    end
    c(i - 1) = str2double(parts{1});
    phi(i - 1) = str2double(parts{2});
end
end

function [rmse, exact] = local_cmp_obs(p1, p2)
t1 = local_normalize_eol(fileread(p1));
t2 = local_normalize_eol(fileread(p2));
if strcmp(t1, t2)
    rmse = 0;
    exact = true;
    return;
end
A = local_parse_obs_mat(p1);
B = local_parse_obs_mat(p2);
if isempty(A) || isempty(B)
    rmse = NaN;
    exact = false;
    return;
end
A = sortrows(A, 1);
B = sortrows(B, 1);
if ~isequal(size(A), size(B))
    rmse = NaN;
    exact = false;
    return;
end
if ~all(A(:, 1) == B(:, 1))
    rmse = NaN;
    exact = false;
    return;
end
d = A(:, 2:end) - B(:, 2:end);
rmse = sqrt(mean(d .^ 2, 'all', 'omitnan'));
exact = all(abs(d) < 1e-12 | (isnan(A(:, 2:end)) & isnan(B(:, 2:end))), 'all');
end

function M = local_parse_obs_mat(p)
txt = local_normalize_eol(fileread(p));
lines = splitlines(strtrim(txt));
if numel(lines) < 2
    M = [];
    return;
end
parts0 = strsplit(lines{1}, ',');
nc = numel(parts0);
n = numel(lines) - 1;
M = zeros(n, nc);
for i = 2:numel(lines)
    parts = strsplit(lines{i}, ',');
    if numel(parts) < nc
        M = [];
        return;
    end
    for j = 1:nc
        M(i - 1, j) = str2double(parts{j});
    end
end
end

function [rmse, exact] = local_cmp_val(p1, p2)
t1 = local_normalize_eol(fileread(p1));
t2 = local_normalize_eol(fileread(p2));
if strcmp(t1, t2)
    rmse = 0;
    exact = true;
    return;
end
rmse = NaN;
exact = false;
end

function rows = local_build_closure_rows(infos, sourceIdx)
rows = {};
n = numel(infos);
if isempty(sourceIdx)
    for i = 1:n
        rows{end+1, 1} = struct('run_id', infos(i).run_id, 'status', 'NO_SOURCE', ...
            'matches_source', 'NO', 'classification', 'DRIFTED'); %#ok<AGROW>
    end
    return;
end
for i = 1:n
    if i == sourceIdx
        st = ternary(infos(i).exec_success, 'SUCCESS', ternary(infos(i).exec_legacy_ok, 'LEGACY_OK', 'OTHER'));
        rows{end+1, 1} = struct('run_id', infos(i).run_id, 'status', st, ...
            'matches_source', 'YES', 'classification', 'SOURCE'); %#ok<AGROW>
        continue;
    end
    st = ternary(infos(i).exec_success, 'SUCCESS', ternary(infos(i).exec_legacy_ok, 'LEGACY_OK', 'OTHER'));
    base = infos(sourceIdx).path;
    other = infos(i).path;
    files = {'switching_canonical_phi1.csv', 'switching_canonical_observables.csv', 'switching_canonical_validation.csv'};
    miss = false;
    for f = 1:numel(files)
        if exist(fullfile(other, 'tables', files{f}), 'file') ~= 2
            miss = true;
        end
    end
    if miss
        rows{end+1, 1} = struct('run_id', infos(i).run_id, 'status', st, ...
            'matches_source', 'NO', 'classification', 'DRIFTED'); %#ok<AGROW>
        continue;
    end
    try
        [pRmse, pEx] = local_cmp_phi1(fullfile(base, 'tables', files{1}), fullfile(other, 'tables', files{1}));
        [oRmse, oEx] = local_cmp_obs(fullfile(base, 'tables', files{2}), fullfile(other, 'tables', files{2}));
        [vRmse, vEx] = local_cmp_val(fullfile(base, 'tables', files{3}), fullfile(other, 'tables', files{3}));
        ex = pEx && oEx && vEx;
        mx = max([pRmse, oRmse, vRmse], [], 'omitnan');
        if ex || (isfinite(mx) && mx < 1e-12)
            cls = 'DUPLICATE';
            ms = 'YES';
        else
            cls = 'DRIFTED';
            ms = 'NO';
        end
        rows{end+1, 1} = struct('run_id', infos(i).run_id, 'status', st, ...
            'matches_source', ms, 'classification', cls); %#ok<AGROW>
    catch
        rows{end+1, 1} = struct('run_id', infos(i).run_id, 'status', st, ...
            'matches_source', 'NO', 'classification', 'DRIFTED'); %#ok<AGROW>
    end
end
end

function [dupCount, driftCount, systemLocked] = local_counts(rows)
dupCount = 0;
driftCount = 0;
for i = 1:numel(rows)
    r = rows{i};
    if strcmp(r.classification, 'DUPLICATE')
        dupCount = dupCount + 1;
    elseif strcmp(r.classification, 'DRIFTED')
        driftCount = driftCount + 1;
    end
end
systemLocked = 'NO';
if driftCount == 0 && numel(rows) > 0
    systemLocked = 'YES';
end
end

function local_write_closure_csv(repoRoot, rows)
p = fullfile(repoRoot, 'tables', 'switching_canonical_run_closure.csv');
if ~exist(fileparts(p), 'dir')
    mkdir(fileparts(p));
end
fid = fopen(p, 'w');
if fid < 0
    error('switching_canonical_run_closure:WriteFailed', 'Failed writing %s', p);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, 'run_id,status,matches_source,classification\n');
for i = 1:numel(rows)
    r = rows{i};
    fprintf(fid, '%s,%s,%s,%s\n', r.run_id, r.status, r.matches_source, r.classification);
end
end

function local_write_status_csv(repoRoot, canonicalDefined, dupCount, driftCount, systemLocked)
p = fullfile(repoRoot, 'tables', 'switching_canonical_run_closure_status.csv');
if ~exist(fileparts(p), 'dir')
    mkdir(fileparts(p));
end
fid = fopen(p, 'w');
if fid < 0
    error('switching_canonical_run_closure:WriteFailed', 'Failed writing %s', p);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, 'field,value\n');
if canonicalDefined
    fprintf(fid, 'CANONICAL_RUN_DEFINED,YES\n');
else
    fprintf(fid, 'CANONICAL_RUN_DEFINED,NO\n');
end
if dupCount > 0
    fprintf(fid, 'DUPLICATES_IDENTIFIED,YES\n');
else
    fprintf(fid, 'DUPLICATES_IDENTIFIED,NO\n');
end
if driftCount > 0
    fprintf(fid, 'DRIFT_DETECTED,YES\n');
else
    fprintf(fid, 'DRIFT_DETECTED,NO\n');
end
fprintf(fid, 'SYSTEM_FULLY_LOCKED,%s\n', systemLocked);
end

function local_write_report_md(repoRoot, infos, sourceIdx, pairRows, dupCount, driftCount, systemLocked)
p = fullfile(repoRoot, 'reports', 'switching_canonical_run_closure.md');
if ~exist(fileparts(p), 'dir')
    mkdir(fileparts(p));
end
fid = fopen(p, 'w');
if fid < 0
    error('switching_canonical_run_closure:WriteFailed', 'Failed writing %s', p);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, '# Switching canonical run closure\n\n');
if ~isempty(sourceIdx)
    fprintf(fid, '- **SOURCE_OF_TRUTH (CANONICAL_RUN_ID):** `%s`\n', infos(sourceIdx).run_id);
    fprintf(fid, '- **Selection:** Among runs with `EXECUTION_STATUS=SUCCESS` plus full artifacts and ENTRY→COMPLETED markers when present; if none qualify, falls back to SUCCESS+artifacts, then legacy-success+artifacts. Most recent `run_id` wins.\n\n');
else
    fprintf(fid, '- **SOURCE_OF_TRUTH:** none selected (no qualifying run).\n\n');
end
fprintf(fid, '## Candidate filter\n\n');
fprintf(fid, '| run_id | EXECUTION_STATUS SUCCESS | artifact_ok | core triple CSVs | ENTRY+COMPLETED markers | candidate |\n');
fprintf(fid, '| --- | --- | --- | --- | --- | --- |\n');
for i = 1:numel(infos)
    fprintf(fid, '| `%s` | %s | %s | %s | %s | %s |\n', infos(i).run_id, ...
        yn(infos(i).exec_success), yn(infos(i).artifact_ok), yn(infos(i).core_tables_ok), ...
        yn(infos(i).markers_ok), yn(infos(i).candidate));
end
fprintf(fid, '\n## Equivalence vs SOURCE (three CSVs)\n\n');
fprintf(fid, '| run_b | phi1_rmse | observables_rmse | validation_rmse | max_rmse | exact_all |\n');
fprintf(fid, '| --- | --- | --- | --- | --- | --- |\n');
for i = 1:numel(pairRows)
    pr = pairRows{i};
    fprintf(fid, '| `%s` | %s | %s | %s | %s | %s |\n', pr.run_b, pr.phi1_rmse, pr.obs_rmse, pr.val_rmse, pr.max_rmse, pr.exact_all);
    if isfield(pr, 'note') && ~isempty(pr.note)
        fprintf(fid, '\n  - note: %s\n', pr.note);
    end
end
fprintf(fid, '\n## Drift analysis\n\n');
if driftCount > 0
    fprintf(fid, '- **Drift detected:** at least one run differs from SOURCE on the compared tables or is missing required CSVs.\n');
else
    fprintf(fid, '- **No drift:** every non-SOURCE run with complete triples matches SOURCE within tolerance.\n');
end
fprintf(fid, '\n## Counts\n\n');
fprintf(fid, '- **DUPLICATE_COUNT:** %d\n', dupCount);
fprintf(fid, '- **DRIFT_COUNT:** %d\n', driftCount);
fprintf(fid, '- **SYSTEM_FULLY_LOCKED:** %s\n', systemLocked);
end

function s = yn(tf)
if tf
    s = 'YES';
else
    s = 'NO';
end
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
