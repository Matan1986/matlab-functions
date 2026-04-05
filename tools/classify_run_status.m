function out = classify_run_status(run_dir)
% classify_run_status Classify canonical run outcome from runtime markers and artifacts.
%
% status in {SUCCESS, PARTIAL, FAIL}
% Also writes/updates repo tables/runtime_classification.csv for this run_id.

if nargin < 1 || isempty(run_dir)
    error('classify_run_status requires run_dir.');
end

run_dir = char(string(run_dir));
run_id = '';

try
    [~, baseName, ~] = fileparts(run_dir);
    if isempty(baseName)
        run_id = char(string(run_dir));
    else
        run_id = char(string(baseName));
    end
catch
    run_id = '';
end

markerPath = fullfile(run_dir, 'runtime_execution_markers.txt');
hasEntry = marker_file_has_marker(markerPath, 'ENTRY');
hasCompleted = marker_file_has_marker(markerPath, 'COMPLETED');
hasFailed = marker_file_has_marker(markerPath, 'FAILED');

execPath = fullfile(run_dir, 'execution_status.csv');
hasExecStatus = exist(execPath, 'file') == 2;

tablesDir = fullfile(run_dir, 'tables');
reportsDir = fullfile(run_dir, 'reports');

hasTableCsv = dir_has_csv(tablesDir);
hasReportMd = dir_has_md(reportsDir);

artifact_ok = hasExecStatus && hasTableCsv && hasReportMd;

if ~hasEntry
    status = 'FAIL';
elseif ~hasCompleted
    status = 'PARTIAL';
elseif hasCompleted && ~artifact_ok
    status = 'PARTIAL';
else
    status = 'SUCCESS';
end

out = struct();
out.run_id = run_id;
out.status = status;
out.entry = hasEntry;
out.completed = hasCompleted;
out.failed = hasFailed;
out.artifact_ok = artifact_ok;

try
    write_repo_runtime_classification_row(out);
catch
end
end

function tf = marker_file_has_marker(markerPath, markerName)
tf = false;
if exist(markerPath, 'file') ~= 2
    return;
end
try
    txt = fileread(markerPath);
    lines = splitlines(txt);
    for i = 1:numel(lines)
        line = strtrim(char(lines(i)));
        if isempty(line)
            continue;
        end
        parts = strsplit(line);
        if numel(parts) < 2
            continue;
        end
        rest = strtrim(parts{end});
        if strcmpi(rest, markerName)
            tf = true;
            return;
        end
    end
catch
end
end

function tf = dir_has_csv(dirPath)
tf = false;
if isempty(dirPath) || exist(dirPath, 'dir') ~= 7
    return;
end
try
    d = dir(fullfile(dirPath, '*.csv'));
    tf = ~isempty(d);
catch
end
end

function tf = dir_has_md(dirPath)
tf = false;
if isempty(dirPath) || exist(dirPath, 'dir') ~= 7
    return;
end
try
    d = dir(fullfile(dirPath, '*.md'));
    tf = ~isempty(d);
catch
end
end

function write_repo_runtime_classification_row(out)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
outPath = fullfile(repoRoot, 'tables', 'runtime_classification.csv');
tablesDir = fullfile(repoRoot, 'tables');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end

row = table( ...
    {char(string(out.run_id))}, ...
    {char(string(out.status))}, ...
    {logical_to_yesno(out.entry)}, ...
    {logical_to_yesno(out.completed)}, ...
    {logical_to_yesno(out.failed)}, ...
    {logical_to_yesno(out.artifact_ok)}, ...
    'VariableNames', {'run_id', 'status', 'entry', 'completed', 'failed', 'artifact_ok'});

if exist(outPath, 'file') ~= 2
    writetable(row, outPath);
    return;
end

try
    old = readtable(outPath);
    if isempty(old) || ~ismember('run_id', old.Properties.VariableNames)
        writetable(row, outPath);
        return;
    end
    rid = string(old.run_id);
    keep = rid ~= string(out.run_id);
    old = old(keep, :);
    newTbl = [old; row]; %#ok<AGROW>
    writetable(newTbl, outPath);
catch
    writetable(row, outPath);
end
end

function s = logical_to_yesno(tf)
if tf
    s = 'YES';
else
    s = 'NO';
end
end
