clear; clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

datasetPath = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset.csv');
statusCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_reader_smoke_test_results.csv');
compatCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_reader_contract_compatibility.csv');
reportMd = fullfile(repoRoot, 'reports', 'aging', 'aging_reader_smoke_test.md');
realStatusCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset_real_consolidation_status.csv');

if exist(fullfile(repoRoot, 'reports', 'aging'), 'dir') ~= 7
    mkdir(fullfile(repoRoot, 'reports', 'aging'));
end

datasetExists = exist(datasetPath, 'file') == 2;
datasetColumns = strings(0, 1);
rowCount = 0;
columnsPresent = "NO";
datasetIsReal = "NO";
datasetRealEvidence = "missing_dataset";
requiredCols = ["Tp","tw","Dip_depth","FM_abs","source_run"];

if datasetExists
    ds = readtable(datasetPath, 'TextType', 'string', 'VariableNamingRule', 'preserve', 'Delimiter', ',');
    datasetColumns = string(ds.Properties.VariableNames(:));
    rowCount = height(ds);
    if numel(datasetColumns) == 5 && all(datasetColumns == requiredCols')
        columnsPresent = "YES";
    end
    if exist(realStatusCsv, 'file') == 2
        rs = readtable(realStatusCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
        needChecks = ["OUTPUT_IS_FIXTURE","FIVE_COLUMN_ORDER_VALID","SOURCE_RUN_POPULATED"];
        vals = strings(size(needChecks));
        for i = 1:numel(needChecks)
            idx = find(rs.check == needChecks(i), 1, 'first');
            if ~isempty(idx)
                vals(i) = upper(strtrim(string(rs.value(idx))));
            else
                vals(i) = "";
            end
        end
        if vals(1) == "NO" && vals(2) == "YES" && vals(3) == "YES"
            datasetIsReal = "YES";
            datasetRealEvidence = "aging_observable_dataset_real_consolidation_status.csv";
        else
            datasetIsReal = "NO";
            datasetRealEvidence = "real_consolidation_status_not_confirmed";
        end
    end
end

reader_id = strings(0,1);
reader_path = strings(0,1);
reader_category = strings(0,1);
dataset_path_col = strings(0,1);
required_columns_col = strings(0,1);
columns_present_col = strings(0,1);
row_count_col = zeros(0,1);
ran_via_wrapper_col = strings(0,1);
exit_status_col = strings(0,1);
reached_checkpoint_col = strings(0,1);
outputs_written_col = strings(0,1);
failure_class_col = strings(0,1);
failure_message_col = strings(0,1);
unblocked_status_col = strings(0,1);
notes_col = strings(0,1);

function_call_ok = false; %#ok<NASGU>

candidateRunDirs = strings(0,1);
runsRoot = fullfile(repoRoot, 'results', 'aging', 'runs');
if exist(runsRoot, 'dir') == 7
    runEntries = dir(fullfile(runsRoot, 'run_*'));
    for i = 1:numel(runEntries)
        if runEntries(i).isdir
            candidateRunDirs(end+1,1) = string(fullfile(runEntries(i).folder, runEntries(i).name)); %#ok<AGROW>
        end
    end
end

dipTauCandidates = strings(0,1);
dipTauCandidates(end+1,1) = string(fullfile(repoRoot, 'results', 'aging', 'runs', 'run_2026_03_12_223709_aging_timescale_extraction', 'tables', 'tau_vs_Tp.csv'));
dipTauCandidates(end+1,1) = string(fullfile(repoRoot, 'results', 'aging', 'runs', 'run_2026_04_25_214500_stagef_smoke_timescale', 'tables', 'tau_vs_Tp.csv'));

fmTauCandidates = strings(0,1);
fmTauCandidates(end+1,1) = string(fullfile(repoRoot, 'results', 'aging', 'runs', 'run_2026_03_13_013634_aging_fm_timescale_analysis', 'tables', 'tau_FM_vs_Tp.csv'));

dipClockMetricsCandidates = strings(0,1);
dipClockMetricsCandidates(end+1,1) = string(fullfile(repoRoot, 'results', 'aging', 'runs', 'run_2026_03_13_005134_aging_fm_using_dip_clock', 'tables', 'fm_collapse_using_dip_tau_metrics.csv'));

dipTauPath = "";
for i = 1:numel(dipTauCandidates)
    if exist(dipTauCandidates(i), 'file') == 2
        dipTauPath = string(dipTauCandidates(i));
        break;
    end
end

fmTauPath = "";
for i = 1:numel(fmTauCandidates)
    if exist(fmTauCandidates(i), 'file') == 2
        fmTauPath = string(fmTauCandidates(i));
        break;
    end
end

dipClockMetricsPath = "";
for i = 1:numel(dipClockMetricsCandidates)
    if exist(dipClockMetricsCandidates(i), 'file') == 2
        dipClockMetricsPath = string(dipClockMetricsCandidates(i));
        break;
    end
end

readerDefs = struct( ...
    'id', { ...
        "RDR001", ...
        "RDR002", ...
        "RDR003", ...
        "RDR004", ...
        "RDR007" ...
    }, ...
    'path', { ...
        "Aging/analysis/aging_timescale_extraction.m", ...
        "Aging/analysis/aging_fm_timescale_analysis.m", ...
        "Aging/analysis/aging_time_rescaling_collapse.m", ...
        "Aging/analysis/aging_component_clock_test.m", ...
        "Aging/analysis/aging_tri_clock_consistency_test.m" ...
    }, ...
    'category', { ...
        "tau_timescale", ...
        "tau_timescale_fm", ...
        "clock_collapse", ...
        "clock_component_direct", ...
        "mixed_mode_clock" ...
    }, ...
    'required_columns', { ...
        "Tp tw Dip_depth FM_abs source_run", ...
        "Tp tw Dip_depth FM_abs source_run", ...
        "Tp tw Dip_depth (FM_abs optional)", ...
        "Tp tw Dip_depth FM_abs source_run", ...
        "Tp tw Dip_depth FM_abs source_run + tau inputs + structured runs" ...
    } ...
    );

for i = 1:numel(readerDefs)
    rid = readerDefs(i).id;
    rpath = readerDefs(i).path;
    rcat = readerDefs(i).category;
    req = readerDefs(i).required_columns;

    exitStatus = "FAIL";
    reached = "NO";
    outputsWritten = "NO";
    failClass = "";
    failMsg = "";
    unblocked = "NO";
    note = "";

    try
        if rid == "RDR001"
            out = aging_timescale_extraction(); %#ok<NASGU>
            reached = "YES";
            exitStatus = "PASS";
            outputsWritten = "YES";
            unblocked = "YES";
        elseif rid == "RDR002"
            cfg = struct();
            cfg.runLabel = 'stagef_smoke_fm_timescale';
            cfg.datasetPath = datasetPath;
            if strlength(dipTauPath) > 0
                cfg.dipTauPath = char(dipTauPath);
            end
            if strlength(dipClockMetricsPath) > 0
                cfg.failedDipClockMetricsPath = char(dipClockMetricsPath);
            end
            out = aging_fm_timescale_analysis(cfg); %#ok<NASGU>
            reached = "YES";
            exitStatus = "PASS";
            outputsWritten = "YES";
            unblocked = "YES";
            if rowCount < 6
                note = "PASS with limited smoke checkpoint; real robustness needs more rows.";
            end
        elseif rid == "RDR003"
            cfg = struct();
            cfg.runLabel = 'stagef_smoke_time_rescaling';
            cfg.datasetPath = datasetPath;
            out = aging_time_rescaling_collapse(cfg); %#ok<NASGU>
            reached = "YES";
            exitStatus = "PASS";
            outputsWritten = "YES";
            unblocked = "YES";
            if rowCount < 6
                note = "PASSed load and run entrypoint; small row count may limit collapse quality checks.";
            end
        elseif rid == "RDR004"
            out = aging_component_clock_test(); %#ok<NASGU>
            reached = "YES";
            exitStatus = "PASS";
            outputsWritten = "YES";
            unblocked = "YES";
        elseif rid == "RDR007"
            cfg = struct();
            cfg.runLabel = 'stagef_smoke_tri_clock';
            cfg.observableDatasetPath = datasetPath;
            if strlength(dipTauPath) > 0
                cfg.dipTauPath = char(dipTauPath);
            end
            if strlength(fmTauPath) > 0
                cfg.fmTauPath = char(fmTauPath);
            end
            cfg.structuredRunsRoot = runsRoot;
            out = aging_tri_clock_consistency_test(cfg); %#ok<NASGU>
            reached = "YES";
            exitStatus = "PASS";
            outputsWritten = "YES";
            unblocked = "YES";
        end
    catch ME
        exitStatus = "FAIL";
        reached = "NO";
        outputsWritten = "NO";
        failMsg = string(ME.message);
        msgLower = lower(char(failMsg));
        if contains(msgLower, 'dataset not found') || contains(msgLower, 'missing consolidated aging observable dataset') || contains(msgLower, 'missing dataset:')
            failClass = "MISSING_DATASET_PATH_OR_HARDCODED_LEGACY_PATH";
            unblocked = "PARTIAL";
        elseif contains(msgLower, 'missing columns') || contains(msgLower, 'unexpected dataset header') || contains(msgLower, 'missing required columns') || contains(msgLower, 'header')
            failClass = "CONTRACT_MISMATCH";
            unblocked = "NO";
        elseif contains(msgLower, 'tau table not found') || contains(msgLower, 'dip tau table not found') || contains(msgLower, 'failed dip-clock metrics not found') || contains(msgLower, 'structured export run found') || contains(msgLower, 'structured-runs root not found')
            failClass = "MISSING_OPTIONAL_OR_UPSTREAM_INPUTS";
            unblocked = "PARTIAL";
        elseif contains(msgLower, 'need at least')
            failClass = "TOO_FEW_ROWS_FOR_DOWNSTREAM_STEP";
            unblocked = "PARTIAL";
        elseif contains(msgLower, 'exportgraphics') || contains(msgLower, 'save_run_figure') || contains(msgLower, 'figure')
            failClass = "PLOTTING_OR_FIGURE_IO";
            unblocked = "PARTIAL";
        else
            failClass = "READER_RUNTIME_ERROR";
            unblocked = "PARTIAL";
        end
    end

    reader_id(end+1,1) = rid; %#ok<AGROW>
    reader_path(end+1,1) = rpath; %#ok<AGROW>
    reader_category(end+1,1) = rcat; %#ok<AGROW>
    dataset_path_col(end+1,1) = string(datasetPath); %#ok<AGROW>
    required_columns_col(end+1,1) = req; %#ok<AGROW>
    columns_present_col(end+1,1) = columnsPresent; %#ok<AGROW>
    row_count_col(end+1,1) = rowCount; %#ok<AGROW>
    ran_via_wrapper_col(end+1,1) = "YES"; %#ok<AGROW>
    exit_status_col(end+1,1) = exitStatus; %#ok<AGROW>
    reached_checkpoint_col(end+1,1) = reached; %#ok<AGROW>
    outputs_written_col(end+1,1) = outputsWritten; %#ok<AGROW>
    failure_class_col(end+1,1) = failClass; %#ok<AGROW>
    failure_message_col(end+1,1) = failMsg; %#ok<AGROW>
    unblocked_status_col(end+1,1) = unblocked; %#ok<AGROW>
    notes_col(end+1,1) = note; %#ok<AGROW>
end

resultsTbl = table(reader_id, reader_path, reader_category, dataset_path_col, required_columns_col, ...
    columns_present_col, row_count_col, ran_via_wrapper_col, exit_status_col, reached_checkpoint_col, ...
    outputs_written_col, failure_class_col, failure_message_col, unblocked_status_col, notes_col, ...
    'VariableNames', {'reader_id','reader_path','reader_category','dataset_path','required_columns', ...
    'columns_present','row_count','ran_via_wrapper','exit_status','reached_checkpoint', ...
    'outputs_written','failure_class','failure_message','unblocked_status','notes'});
writetable(resultsTbl, statusCsv);

compat_reader_id = resultsTbl.reader_id;
compat_reader_path = resultsTbl.reader_path;
uses_five = repmat("YES", height(resultsTbl), 1);
requires_extra = repmat("NO", height(resultsTbl), 1);
extra_cols = repmat("", height(resultsTbl), 1);
compatible = repmat("YES", height(resultsTbl), 1);
requires_sidecar = repmat("NO", height(resultsTbl), 1);
requires_switch = repmat("NO", height(resultsTbl), 1);
requires_more_rows = repmat("NO", height(resultsTbl), 1);
requires_replay = repmat("NO", height(resultsTbl), 1);
risk_level = repmat("MED", height(resultsTbl), 1);
compat_notes = repmat("", height(resultsTbl), 1);

for i = 1:height(resultsTbl)
    rid = resultsTbl.reader_id(i);
    if rid == "RDR002"
        requires_extra(i) = "YES";
        extra_cols(i) = "dipTauPath + failedDipClockMetricsPath inputs";
        requires_more_rows(i) = "YES";
    elseif rid == "RDR007"
        requires_extra(i) = "YES";
        extra_cols(i) = "dipTauPath + fmTauPath + structured export runs";
        requires_more_rows(i) = "YES";
        requires_replay(i) = "YES";
        risk_level(i) = "HIGH";
    elseif rid == "RDR004"
        compatible(i) = "PARTIAL";
        compat_notes(i) = "Reader hardcodes legacy dataset run path; loader matches five-column contract.";
        risk_level(i) = "HIGH";
    elseif rid == "RDR001"
        compatible(i) = "PARTIAL";
        compat_notes(i) = "Reader hardcodes legacy dataset run path; loadObservableDataset expects exact five-column header.";
        risk_level(i) = "HIGH";
    elseif rid == "RDR003"
        compatible(i) = "YES";
        risk_level(i) = "MED";
    end

    if resultsTbl.failure_class(i) == "MISSING_OPTIONAL_OR_UPSTREAM_INPUTS"
        compatible(i) = "PARTIAL";
        requires_extra(i) = "YES";
        requires_replay(i) = "YES";
    elseif resultsTbl.failure_class(i) == "TOO_FEW_ROWS_FOR_DOWNSTREAM_STEP"
        compatible(i) = "PARTIAL";
        requires_more_rows(i) = "YES";
    elseif resultsTbl.failure_class(i) == "CONTRACT_MISMATCH"
        compatible(i) = "NO";
        risk_level(i) = "HIGH";
    elseif resultsTbl.failure_class(i) == "MISSING_DATASET_PATH_OR_HARDCODED_LEGACY_PATH"
        compatible(i) = "PARTIAL";
        requires_replay(i) = "NO";
    end
end

compatTbl = table(compat_reader_id, compat_reader_path, uses_five, requires_extra, extra_cols, ...
    compatible, requires_sidecar, requires_switch, requires_more_rows, requires_replay, risk_level, compat_notes, ...
    'VariableNames', {'reader_id','reader_path','uses_five_column_contract','requires_extra_columns', ...
    'extra_columns_required','compatible_with_minimal_contract','requires_sidecar','requires_switching_inputs', ...
    'requires_more_rows','requires_replay','risk_level','notes'});
writetable(compatTbl, compatCsv);

nReaders = height(resultsTbl);
nPass = nnz(resultsTbl.exit_status == "PASS");
nFail = nReaders - nPass;
nUnblocked = nnz(resultsTbl.unblocked_status == "YES");
nPartial = nnz(resultsTbl.unblocked_status == "PARTIAL");

tauRows = resultsTbl(ismember(resultsTbl.reader_id, ["RDR001","RDR002"]), :);
clockRows = resultsTbl(ismember(resultsTbl.reader_id, ["RDR003","RDR004"]), :);
mixedRows = resultsTbl(ismember(resultsTbl.reader_id, ["RDR007"]), :);

tauVerdict = "NO";
if any(tauRows.exit_status == "PASS")
    tauVerdict = "PARTIAL";
end
if all(tauRows.exit_status == "PASS")
    tauVerdict = "YES";
end

clockVerdict = "NO";
if any(clockRows.exit_status == "PASS")
    clockVerdict = "PARTIAL";
end
if all(clockRows.exit_status == "PASS")
    clockVerdict = "YES";
end

mixedVerdict = "NO";
if any(mixedRows.exit_status == "PASS")
    mixedVerdict = "YES";
elseif any(mixedRows.unblocked_status == "PARTIAL")
    mixedVerdict = "PARTIAL";
end

coreSufficient = "NO";
if columnsPresent == "YES" && (tauVerdict == "PARTIAL" || tauVerdict == "YES") && (clockVerdict == "PARTIAL" || clockVerdict == "YES")
    coreSufficient = "PARTIAL";
end
if columnsPresent == "YES" && tauVerdict == "YES" && clockVerdict == "YES"
    coreSufficient = "YES";
end

oldUnblocked = "NO";
if nUnblocked > 0 && nPartial > 0
    oldUnblocked = "PARTIAL";
elseif nUnblocked == nReaders
    oldUnblocked = "YES";
elseif nUnblocked > 0
    oldUnblocked = "PARTIAL";
end

wideNeeded = "NO";
if any(compatTbl.requires_extra_columns == "YES")
    wideNeeded = "PARTIAL";
end

readyRobust = "NO";
if columnsPresent == "YES" && nPass >= 2
    readyRobust = "PARTIAL";
end
if nPass == nReaders
    readyRobust = "YES";
end

readySwitching = "PENDING";
if any(compatTbl.requires_switching_inputs == "YES")
    readySwitching = "PENDING";
end

mappedVerdict = "NO";
if nReaders >= 4
    mappedVerdict = "YES";
elseif nReaders >= 1
    mappedVerdict = "PARTIAL";
end

lines = strings(0,1);
lines(end+1) = "# Aging reader smoke test (Stage F)";
lines(end+1) = "";
lines(end+1) = "## Dataset used";
lines(end+1) = sprintf("- Dataset path: `%s`", strrep(char(datasetPath), '\', '/'));
lines(end+1) = sprintf("- Exists: %s", string(datasetExists));
lines(end+1) = sprintf("- Columns present (five-column order): %s", columnsPresent);
lines(end+1) = sprintf("- Row count: %d", rowCount);
lines(end+1) = sprintf("- Real-run-backed confirmation: %s (%s)", datasetIsReal, datasetRealEvidence);
lines(end+1) = "";
lines(end+1) = "## Readers tested";
for i = 1:height(resultsTbl)
    lines(end+1) = sprintf("- %s | `%s` | category=%s | exit=%s | checkpoint=%s | failure_class=%s", ...
        resultsTbl.reader_id(i), resultsTbl.reader_path(i), resultsTbl.reader_category(i), ...
        resultsTbl.exit_status(i), resultsTbl.reached_checkpoint(i), ...
        string(resultsTbl.failure_class(i)));
end
lines(end+1) = "";
lines(end+1) = "## Commands run";
lines(end+1) = sprintf("- `tools/run_matlab_safe.bat %s`", strrep(thisFile, '\', '/'));
lines(end+1) = "";
lines(end+1) = "## Pass/fail summary";
lines(end+1) = sprintf("- Readers total: %d", nReaders);
lines(end+1) = sprintf("- PASS: %d", nPass);
lines(end+1) = sprintf("- FAIL: %d", nFail);
lines(end+1) = sprintf("- Unblocked: %d", nUnblocked);
lines(end+1) = sprintf("- Partial unblock: %d", nPartial);
lines(end+1) = "";
lines(end+1) = "## Failure classification";
classes = unique(resultsTbl.failure_class(strlength(resultsTbl.failure_class) > 0));
if isempty(classes)
    lines(end+1) = "- none";
else
    for i = 1:numel(classes)
        c = classes(i);
        lines(end+1) = sprintf("- %s: %d", c, nnz(resultsTbl.failure_class == c));
    end
end
lines(end+1) = "";
lines(end+1) = "## Unblocked vs blocked";
lines(end+1) = "- Unblocked readers are those that loaded the five-column dataset and reached first checkpoint.";
lines(end+1) = "- Blocked readers require either legacy hardcoded paths, upstream tau/correlation inputs, or broader replay artifacts.";
lines(end+1) = "";
lines(end+1) = "## Verdicts";
lines(end+1) = sprintf("- SMOKE_TEST_DATASET_REAL = %s", datasetIsReal);
lines(end+1) = sprintf("- SMOKE_TEST_READERS_MAPPED = %s", mappedVerdict);
lines(end+1) = sprintf("- TAU_READER_LOADS_DATASET = %s", tauVerdict);
lines(end+1) = sprintf("- CLOCK_COLLAPSE_READER_LOADS_DATASET = %s", clockVerdict);
lines(end+1) = sprintf("- MIXED_MODE_READER_LOADS_DATASET = %s", mixedVerdict);
lines(end+1) = sprintf("- FIVE_COLUMN_CONTRACT_SUFFICIENT_FOR_CORE_READERS = %s", coreSufficient);
lines(end+1) = sprintf("- OLD_ANALYSIS_READERS_UNBLOCKED = %s", oldUnblocked);
lines(end+1) = sprintf("- WIDE_COMPANION_TABLE_NEEDED = %s", wideNeeded);
lines(end+1) = sprintf("- READY_FOR_ROBUSTNESS_AUDIT = %s", readyRobust);
lines(end+1) = sprintf("- READY_FOR_SWITCHING_CROSS_ANALYSIS = %s", readySwitching);
lines(end+1) = "";
lines(end+1) = "## Next recommended stage";
lines(end+1) = "- Stage G: targeted replay/minimal upstream regeneration for readers that require tau tables and structured-run bundles, then rerun smoke matrix.";

fid = fopen(reportMd, 'w');
if fid >= 0
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', char(lines(i)));
    end
    fclose(fid);
end

disp('Stage F smoke harness complete.');
