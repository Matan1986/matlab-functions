clear; clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

datasetPath = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset.csv');
realStatusPath = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset_real_consolidation_status.csv');
outCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_reader_smoke_retry_g2b.csv');
outMd = fullfile(repoRoot, 'reports', 'aging', 'aging_reader_smoke_retry_g2b.md');

if exist(fullfile(repoRoot, 'reports', 'aging'), 'dir') ~= 7
    mkdir(fullfile(repoRoot, 'reports', 'aging'));
end

requiredCols = ["Tp","tw","Dip_depth","FM_abs","source_run"];
datasetReal = "NO";
rowCount = 0;
colsValid = "NO";

assert(exist(datasetPath, 'file') == 2, 'Missing dataset: %s', datasetPath);
ds = readtable(datasetPath, 'TextType', 'string', 'VariableNamingRule', 'preserve', 'Delimiter', ',');
rowCount = height(ds);
names = string(ds.Properties.VariableNames(:));
if numel(names) == 5 && all(names == requiredCols')
    colsValid = "YES";
end

if exist(realStatusPath, 'file') == 2
    rs = readtable(realStatusPath, 'TextType', 'string', 'VariableNamingRule', 'preserve', 'Delimiter', ',');
    idxFix = find(rs.check == "OUTPUT_IS_FIXTURE", 1, 'first');
    idxOrder = find(rs.check == "FIVE_COLUMN_ORDER_VALID", 1, 'first');
    idxSrc = find(rs.check == "SOURCE_RUN_POPULATED", 1, 'first');
    if ~isempty(idxFix) && ~isempty(idxOrder) && ~isempty(idxSrc)
        isFixture = upper(strtrim(string(rs.value(idxFix))));
        orderOk = upper(strtrim(string(rs.value(idxOrder))));
        srcOk = upper(strtrim(string(rs.value(idxSrc))));
        if isFixture == "NO" && orderOk == "YES" && srcOk == "YES"
            datasetReal = "YES";
        end
    end
end

reader_id = strings(0,1);
reader_path = strings(0,1);
dataset_path_col = strings(0,1);
dataset_real_col = strings(0,1);
row_count_col = zeros(0,1);
columns_valid_col = strings(0,1);
override_used_col = strings(0,1);
reached_checkpoint_col = strings(0,1);
exit_status_col = strings(0,1);
failure_class_col = strings(0,1);
failure_message_col = strings(0,1);
status_col = strings(0,1);
notes_col = strings(0,1);

oldEnv = getenv('AGING_OBSERVABLE_DATASET_PATH');
setenv('AGING_OBSERVABLE_DATASET_PATH', datasetPath);

readers = struct( ...
    'id', {"RDR001","RDR004"}, ...
    'path', {"Aging/analysis/aging_timescale_extraction.m","Aging/analysis/aging_component_clock_test.m"} ...
    );

for i = 1:numel(readers)
    rid = readers(i).id;
    rpath = readers(i).path;
    reached = "NO";
    exitStatus = "FAIL";
    fclass = "";
    fmsg = "";
    state = "FAIL";
    note = "";

    try
        if rid == "RDR001"
            out = aging_timescale_extraction(); %#ok<NASGU>
        else
            out = aging_component_clock_test(); %#ok<NASGU>
        end
        reached = "YES";
        exitStatus = "0";
        state = "PASS";
        note = "Completed smoke checkpoint after plotting/export.";
    catch ME
        reached = "NO";
        exitStatus = "1";
        fmsg = string(ME.message);
        msg = lower(char(fmsg));
        if contains(msg, 'missing consolidated aging observable dataset') || contains(msg, 'missing dataset') || ...
                contains(msg, 'unexpected aging observable dataset header') || contains(msg, 'dataset missing columns')
            fclass = "DATASET_CONTRACT";
        elseif contains(msg, 'clim') || contains(msg, 'save_run_figure') || contains(msg, 'figure name') || ...
                contains(msg, 'exportgraphics') || contains(msg, 'axes')
            fclass = "PLOTTING_IO";
        elseif contains(msg, 'need at least') || contains(msg, 'insufficient') || contains(msg, 'too few')
            fclass = "DATA_COVERAGE";
        elseif contains(msg, 'tau table not found') || contains(msg, 'dip tau table not found') || ...
                contains(msg, 'structured export run found') || contains(msg, 'fm tau table not found')
            fclass = "UPSTREAM_DEPENDENCY";
        else
            fclass = "OTHER";
        end
        state = "FAIL";
    end

    reader_id(end+1,1) = rid; %#ok<AGROW>
    reader_path(end+1,1) = rpath; %#ok<AGROW>
    dataset_path_col(end+1,1) = string(datasetPath); %#ok<AGROW>
    dataset_real_col(end+1,1) = datasetReal; %#ok<AGROW>
    row_count_col(end+1,1) = rowCount; %#ok<AGROW>
    columns_valid_col(end+1,1) = colsValid; %#ok<AGROW>
    override_used_col(end+1,1) = "YES"; %#ok<AGROW>
    reached_checkpoint_col(end+1,1) = reached; %#ok<AGROW>
    exit_status_col(end+1,1) = exitStatus; %#ok<AGROW>
    failure_class_col(end+1,1) = fclass; %#ok<AGROW>
    failure_message_col(end+1,1) = fmsg; %#ok<AGROW>
    status_col(end+1,1) = state; %#ok<AGROW>
    notes_col(end+1,1) = note; %#ok<AGROW>
end

if isempty(oldEnv)
    setenv('AGING_OBSERVABLE_DATASET_PATH', '');
else
    setenv('AGING_OBSERVABLE_DATASET_PATH', oldEnv);
end

tbl = table(reader_id, reader_path, dataset_path_col, dataset_real_col, row_count_col, ...
    columns_valid_col, override_used_col, reached_checkpoint_col, exit_status_col, ...
    failure_class_col, failure_message_col, status_col, notes_col, ...
    'VariableNames', {'reader_id','reader_path','dataset_path','dataset_real','row_count', ...
    'columns_valid','override_used','reached_checkpoint','exit_status','failure_class', ...
    'failure_message','status','notes'});
writetable(tbl, outCsv);

r1 = tbl(tbl.reader_id == "RDR001", :);
r4 = tbl(tbl.reader_id == "RDR004", :);
r1Pass = ~isempty(r1) && all(r1.status == "PASS");
r4Pass = ~isempty(r4) && all(r4.status == "PASS");
contractFailure = any(tbl.failure_class == "DATASET_CONTRACT");
unblocked = "NO";
if r1Pass && r4Pass
    unblocked = "YES";
elseif r1Pass || r4Pass
    unblocked = "PARTIAL";
end

readyG3 = "NO";
if r1Pass && r4Pass
    readyG3 = "YES";
else
    readyG3 = "PARTIAL";
end

readyCommit = "PARTIAL";

lines = strings(0,1);
lines(end+1) = "# Aging reader smoke retry G2b";
lines(end+1) = "";
lines(end+1) = "## Command run";
lines(end+1) = sprintf("- `tools/run_matlab_safe.bat %s`", strrep([thisFile '.m'], '\', '/'));
lines(end+1) = "";
lines(end+1) = "## Dataset used";
lines(end+1) = sprintf("- Path: `%s`", strrep(datasetPath, '\', '/'));
lines(end+1) = sprintf("- dataset_real: %s", datasetReal);
lines(end+1) = sprintf("- row_count: %d", rowCount);
lines(end+1) = sprintf("- columns_valid: %s", colsValid);
lines(end+1) = "";
lines(end+1) = "## Reader results";
for i = 1:height(tbl)
    lines(end+1) = sprintf("- %s `%s`: status=%s, reached_checkpoint=%s, exit_status=%s, failure_class=%s", ...
        tbl.reader_id(i), tbl.reader_path(i), tbl.status(i), tbl.reached_checkpoint(i), ...
        tbl.exit_status(i), string(tbl.failure_class(i)));
end
lines(end+1) = "";
lines(end+1) = "## Unblock state";
lines(end+1) = sprintf("- RDR001 pass: %s", string(r1Pass));
lines(end+1) = sprintf("- RDR004 pass: %s", string(r4Pass));
lines(end+1) = sprintf("- RDR001_RDR004_UNBLOCKED: %s", unblocked);
lines(end+1) = "";
lines(end+1) = "## Remaining Aging reader blockers";
lines(end+1) = "- RDR002 and RDR007 remain dependent on upstream tau/correlation artifacts.";
lines(end+1) = "- RDR003 remains coverage-limited (multi-Tp requirement).";
lines(end+1) = "";
lines(end+1) = "## Verdicts";
lines(end+1) = sprintf("- SMOKE_RETRY_DATASET_REAL = %s", datasetReal);
if r1Pass
    lines(end+1) = "- RDR001_SMOKE_PASS = YES";
else
    lines(end+1) = "- RDR001_SMOKE_PASS = NO";
end
if r4Pass
    lines(end+1) = "- RDR004_SMOKE_PASS = YES";
else
    lines(end+1) = "- RDR004_SMOKE_PASS = NO";
end
lines(end+1) = sprintf("- RDR001_RDR004_UNBLOCKED = %s", unblocked);
if contractFailure
    lines(end+1) = "- CONTRACT_FAILURE_FOUND = YES";
else
    lines(end+1) = "- CONTRACT_FAILURE_FOUND = NO";
end
lines(end+1) = sprintf("- READY_FOR_G3_UPSTREAM_TAU_ARTIFACTS = %s", readyG3);
lines(end+1) = sprintf("- READY_FOR_COMMIT = %s", readyCommit);
lines(end+1) = "";
lines(end+1) = "## Next recommended stage";
lines(end+1) = "- Stage G3: regenerate/refresh upstream tau artifacts and multi-Tp coverage for RDR002/RDR003/RDR007, then rerun broader smoke matrix.";

fid = fopen(outMd, 'w');
if fid >= 0
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', char(lines(i)));
    end
    fclose(fid);
end

disp('Stage G2b focused smoke retry complete.');
