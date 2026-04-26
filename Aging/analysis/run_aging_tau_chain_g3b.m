clear; clc;

repoRoot = fileparts(fileparts(mfilename('fullpath')));
repoRoot = fileparts(repoRoot);
addpath(fullfile(repoRoot, 'Aging'), '-begin');
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

datasetPath = fullfile(tablesDir, 'aging_observable_dataset.csv');
assert(exist(datasetPath, 'file') == 2, 'Missing dataset: %s', datasetPath);

runStatusCsv = fullfile(tablesDir, 'aging_tau_chain_run_status.csv');
artifactInvCsv = fullfile(tablesDir, 'aging_tau_chain_artifact_inventory.csv');
readerSmokeCsv = fullfile(tablesDir, 'aging_tau_chain_reader_smoke_results.csv');
reportPath = fullfile(reportsDir, 'aging_tau_chain_run_report.md');

step_id = strings(0,1);
producer_or_reader = strings(0,1);
path_col = strings(0,1);
input_dataset = strings(0,1);
expected_output = strings(0,1);
ran = strings(0,1);
exit_status = strings(0,1);
output_found = strings(0,1);
output_row_count = nan(0,1);
required_columns_present = strings(0,1);
failure_class = strings(0,1);
failure_message = strings(0,1);
notes = strings(0,1);

artifact_name = strings(0,1);
artifact_path = strings(0,1);
artifact_producer = strings(0,1);
artifact_row_count = nan(0,1);
artifact_columns = strings(0,1);
artifact_dataset_source = strings(0,1);
artifact_multibacked = strings(0,1);
artifact_required_by = strings(0,1);
artifact_valid_smoke = strings(0,1);
artifact_risk = strings(0,1);
artifact_notes = strings(0,1);

reader_id = strings(0,1);
reader_path = strings(0,1);
required_artifacts = strings(0,1);
artifacts_available = strings(0,1);
reader_ran = strings(0,1);
reader_exit_status = strings(0,1);
reached_checkpoint = strings(0,1);
reader_failure_class = strings(0,1);
reader_failure_message = strings(0,1);
reader_status = strings(0,1);
reader_notes = strings(0,1);

cmds = strings(0,1);

dipTauPath = "";
rescalePath = "";
fmUsingDipPath = "";
fmTauPath = "";
rdr002RunDir = "";
rdr007RunDir = "";

ds = readtable(datasetPath, 'TextType', 'string', 'VariableNamingRule', 'preserve', ...
    'Delimiter', ',', 'ReadVariableNames', true);
dsCols = string(ds.Properties.VariableNames);
if ~any(dsCols == "Tp") && width(ds) >= 1
    ds.Properties.VariableNames{1} = 'Tp';
    dsCols = string(ds.Properties.VariableNames);
end
if ~any(dsCols == "tw") && width(ds) >= 2
    ds.Properties.VariableNames{2} = 'tw';
    dsCols = string(ds.Properties.VariableNames);
end
if any(dsCols == "Tp"), tpVals = unique(double(ds.Tp(isfinite(double(ds.Tp))))); else, tpVals = []; end
if any(dsCols == "tw"), twVals = unique(double(ds.tw(isfinite(double(ds.tw))))); else, twVals = []; end
hasHighTp = any(abs(tpVals - 30) < 1e-9) || any(abs(tpVals - 34) < 1e-9);

% Step 1: Dip tau artifact
step_id(end+1,1) = "S1_DIP_TAU";
producer_or_reader(end+1,1) = "aging_timescale_extraction";
path_col(end+1,1) = fullfile(repoRoot, 'Aging', 'analysis', 'aging_timescale_extraction.m');
input_dataset(end+1,1) = datasetPath;
expected_output(end+1,1) = "tau_vs_Tp.csv";
ran(end+1,1) = "YES";
cmds(end+1,1) = "aging_timescale_extraction() with AGING_OBSERVABLE_DATASET_PATH override";
try
    setenv('AGING_OBSERVABLE_DATASET_PATH', datasetPath);
    out1 = aging_timescale_extraction();
    if isfield(out1, 'table_path')
        dipTauPath = string(out1.table_path);
    end
    t1 = readtable(char(dipTauPath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    c1 = string(t1.Properties.VariableNames);
    okCols = any(c1 == "Tp") && any(c1 == "tau_effective_seconds");
    exit_status(end+1,1) = "SUCCESS";
    output_found(end+1,1) = string(exist(char(dipTauPath), 'file') == 2);
    output_row_count(end+1,1) = height(t1);
    if okCols
        required_columns_present(end+1,1) = "YES";
    else
        required_columns_present(end+1,1) = "NO";
    end
    failure_class(end+1,1) = "";
    failure_message(end+1,1) = "";
    notes(end+1,1) = "dip_tau_generated";
catch ME
    exit_status(end+1,1) = "FAILED";
    output_found(end+1,1) = "NO";
    output_row_count(end+1,1) = NaN;
    required_columns_present(end+1,1) = "NO";
    failure_class(end+1,1) = "PRODUCER_EXCEPTION";
    failure_message(end+1,1) = string(ME.message);
    notes(end+1,1) = "dip_tau_failed";
end

% Step 2: tau rescaling estimates
step_id(end+1,1) = "S2_TAU_RESCALING";
producer_or_reader(end+1,1) = "aging_time_rescaling_collapse";
path_col(end+1,1) = fullfile(repoRoot, 'Aging', 'analysis', 'aging_time_rescaling_collapse.m');
input_dataset(end+1,1) = datasetPath;
expected_output(end+1,1) = "tau_rescaling_estimates.csv";
ran(end+1,1) = "YES";
cmds(end+1,1) = "aging_time_rescaling_collapse(cfg.datasetPath override)";
try
    cfg2 = struct();
    cfg2.datasetPath = datasetPath;
    out2 = aging_time_rescaling_collapse(cfg2);
    rescalePath = string(out2.table_path);
    t2 = readtable(char(rescalePath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    c2 = string(t2.Properties.VariableNames);
    okCols = any(c2 == "Tp") && any(c2 == "tau_estimate_seconds");
    exit_status(end+1,1) = "SUCCESS";
    output_found(end+1,1) = string(exist(char(rescalePath), 'file') == 2);
    output_row_count(end+1,1) = height(t2);
    if okCols
        required_columns_present(end+1,1) = "YES";
    else
        required_columns_present(end+1,1) = "NO";
    end
    failure_class(end+1,1) = "";
    failure_message(end+1,1) = "";
    notes(end+1,1) = "rescaling_tau_generated";
catch ME
    exit_status(end+1,1) = "FAILED";
    output_found(end+1,1) = "NO";
    output_row_count(end+1,1) = NaN;
    required_columns_present(end+1,1) = "NO";
    failure_class(end+1,1) = "PRODUCER_EXCEPTION";
    failure_message(end+1,1) = string(ME.message);
    notes(end+1,1) = "rescaling_tau_failed";
end

% Step 3: FM using Dip metrics
step_id(end+1,1) = "S3_FM_USING_DIP";
producer_or_reader(end+1,1) = "aging_fm_using_dip_clock";
path_col(end+1,1) = fullfile(repoRoot, 'Aging', 'analysis', 'aging_fm_using_dip_clock.m');
input_dataset(end+1,1) = datasetPath;
expected_output(end+1,1) = "fm_collapse_using_dip_tau_metrics.csv";
ran(end+1,1) = "YES";
cmds(end+1,1) = "aging_fm_using_dip_clock(cfg.datasetPath/cfg.tauPath override)";
try
    cfg3 = struct();
    cfg3.datasetPath = datasetPath;
    if strlength(rescalePath) > 0 && exist(char(rescalePath), 'file') == 2
        cfg3.tauPath = char(rescalePath);
    else
        cfg3.tauPath = char(dipTauPath);
    end
    out3 = aging_fm_using_dip_clock(cfg3);
    fmUsingDipPath = string(out3.metrics_path);
    t3 = readtable(char(fmUsingDipPath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    c3 = string(t3.Properties.VariableNames);
    okCols = any(c3 == "scenario") && any(c3 == "rmse_log_after");
    hasBaseline = false;
    if any(c3 == "scenario")
        hasBaseline = any(string(t3.scenario) == "baseline_all_fm");
    end
    exit_status(end+1,1) = "SUCCESS";
    output_found(end+1,1) = string(exist(char(fmUsingDipPath), 'file') == 2);
    output_row_count(end+1,1) = height(t3);
    if okCols && hasBaseline
        required_columns_present(end+1,1) = "YES";
    else
        required_columns_present(end+1,1) = "NO";
    end
    failure_class(end+1,1) = "";
    failure_message(end+1,1) = "";
    if hasBaseline
        notes(end+1,1) = "baseline_all_fm_present";
    else
        notes(end+1,1) = "baseline_all_fm_missing";
    end
catch ME
    exit_status(end+1,1) = "FAILED";
    output_found(end+1,1) = "NO";
    output_row_count(end+1,1) = NaN;
    required_columns_present(end+1,1) = "NO";
    failure_class(end+1,1) = "PRODUCER_EXCEPTION";
    failure_message(end+1,1) = string(ME.message);
    notes(end+1,1) = "fm_using_dip_failed";
end

% Step 4 + RDR002 smoke: FM tau artifact
step_id(end+1,1) = "S4_FM_TAU_RDR002";
producer_or_reader(end+1,1) = "aging_fm_timescale_analysis";
path_col(end+1,1) = fullfile(repoRoot, 'Aging', 'analysis', 'aging_fm_timescale_analysis.m');
input_dataset(end+1,1) = datasetPath;
expected_output(end+1,1) = "tau_FM_vs_Tp.csv";
ran(end+1,1) = "YES";
cmds(end+1,1) = "aging_fm_timescale_analysis(cfg overrides)";
try
    cfg4 = struct();
    cfg4.datasetPath = datasetPath;
    cfg4.dipTauPath = char(dipTauPath);
    cfg4.failedDipClockMetricsPath = char(fmUsingDipPath);
    out4 = aging_fm_timescale_analysis(cfg4);
    fmTauPath = string(out4.tau_table_path);
    rdr002RunDir = string(out4.run_dir);
    t4 = readtable(char(fmTauPath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
    c4 = string(t4.Properties.VariableNames);
    okCols = any(c4 == "Tp") && any(c4 == "tau_effective_seconds");
    exit_status(end+1,1) = "SUCCESS";
    output_found(end+1,1) = string(exist(char(fmTauPath), 'file') == 2);
    output_row_count(end+1,1) = height(t4);
    if okCols
        required_columns_present(end+1,1) = "YES";
    else
        required_columns_present(end+1,1) = "NO";
    end
    failure_class(end+1,1) = "";
    failure_message(end+1,1) = "";
    notes(end+1,1) = "rdr002_smoke_invoked";
catch ME
    exit_status(end+1,1) = "FAILED";
    output_found(end+1,1) = "NO";
    output_row_count(end+1,1) = NaN;
    required_columns_present(end+1,1) = "NO";
    failure_class(end+1,1) = "READER_EXCEPTION";
    failure_message(end+1,1) = string(ME.message);
    notes(end+1,1) = "rdr002_failed";
end

% Step 5 + RDR007 smoke
step_id(end+1,1) = "S5_RDR007_TRI_CLOCK";
producer_or_reader(end+1,1) = "aging_tri_clock_consistency_test";
path_col(end+1,1) = fullfile(repoRoot, 'Aging', 'analysis', 'aging_tri_clock_consistency_test.m');
input_dataset(end+1,1) = datasetPath;
expected_output(end+1,1) = "clock_collapse_metrics.csv";
ran(end+1,1) = "YES";
cmds(end+1,1) = "aging_tri_clock_consistency_test(cfg overrides)";
try
    cfg5 = struct();
    cfg5.observableDatasetPath = datasetPath;
    cfg5.dipTauPath = char(dipTauPath);
    cfg5.fmTauPath = char(fmTauPath);
    out5 = aging_tri_clock_consistency_test(cfg5);
    rdr007RunDir = string(out5.run_dir);
    expected5 = fullfile(char(rdr007RunDir), 'tables', 'clock_collapse_metrics.csv');
    t5 = readtable(expected5, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    c5 = string(t5.Properties.VariableNames);
    okCols = any(c5 == "scenario_name") && any(c5 == "mean_pairwise_rmse");
    exit_status(end+1,1) = "SUCCESS";
    output_found(end+1,1) = string(exist(expected5, 'file') == 2);
    output_row_count(end+1,1) = height(t5);
    if okCols
        required_columns_present(end+1,1) = "YES";
    else
        required_columns_present(end+1,1) = "NO";
    end
    failure_class(end+1,1) = "";
    failure_message(end+1,1) = "";
    notes(end+1,1) = "rdr007_smoke_invoked";
catch ME
    exit_status(end+1,1) = "FAILED";
    output_found(end+1,1) = "NO";
    output_row_count(end+1,1) = NaN;
    required_columns_present(end+1,1) = "NO";
    failure_class(end+1,1) = "READER_EXCEPTION";
    failure_message(end+1,1) = string(ME.message);
    notes(end+1,1) = "rdr007_failed";
end

statusTbl = table(step_id, producer_or_reader, path_col, input_dataset, expected_output, ...
    ran, exit_status, output_found, output_row_count, required_columns_present, ...
    failure_class, failure_message, notes, ...
    'VariableNames', {'step_id','producer_or_reader','path','input_dataset','expected_output', ...
    'ran','exit_status','output_found','output_row_count','required_columns_present', ...
    'failure_class','failure_message','notes'});
writetable(statusTbl, runStatusCsv);

% Artifact inventory entries
artifacts = {
    "tau_vs_Tp.csv", dipTauPath, "aging_timescale_extraction", "RDR002;RDR007";
    "tau_rescaling_estimates.csv", rescalePath, "aging_time_rescaling_collapse", "aging_fm_using_dip_clock";
    "fm_collapse_using_dip_tau_metrics.csv", fmUsingDipPath, "aging_fm_using_dip_clock", "RDR002";
    "tau_FM_vs_Tp.csv", fmTauPath, "aging_fm_timescale_analysis", "RDR007";
    };
for i = 1:size(artifacts, 1)
    p = string(artifacts{i,2});
    rc = NaN;
    cols = "";
    validSmoke = "NO";
    risk = "HIGH";
    nte = "artifact_missing";
    if strlength(p) > 0 && exist(char(p), 'file') == 2
        tt = readtable(char(p), 'TextType', 'string', 'VariableNamingRule', 'preserve');
        rc = height(tt);
        cols = strjoin(string(tt.Properties.VariableNames), ';');
        validSmoke = "YES";
        risk = "LOW";
        nte = "artifact_present";
    end
    artifact_name(end+1,1) = string(artifacts{i,1});
    artifact_path(end+1,1) = p;
    artifact_producer(end+1,1) = string(artifacts{i,3});
    artifact_row_count(end+1,1) = rc;
    artifact_columns(end+1,1) = cols;
    artifact_dataset_source(end+1,1) = datasetPath;
    artifact_multibacked(end+1,1) = "YES";
    artifact_required_by(end+1,1) = string(artifacts{i,4});
    artifact_valid_smoke(end+1,1) = validSmoke;
    artifact_risk(end+1,1) = risk;
    artifact_notes(end+1,1) = nte;
end

invTbl = table(artifact_name, artifact_path, artifact_producer, artifact_row_count, artifact_columns, ...
    artifact_dataset_source, artifact_multibacked, artifact_required_by, artifact_valid_smoke, artifact_risk, artifact_notes, ...
    'VariableNames', {'artifact','path','producer','row_count','columns','dataset_source','multiTp_multiTw_backed', ...
    'required_by','valid_for_smoke','risk_level','notes'});
writetable(invTbl, artifactInvCsv);

% Reader smoke summary
rdr002Ok = strlength(rdr002RunDir) > 0 && exist(char(fullfile(char(rdr002RunDir), 'tables', 'tau_FM_vs_Tp.csv')), 'file') == 2;
rdr007Ok = strlength(rdr007RunDir) > 0 && exist(char(fullfile(char(rdr007RunDir), 'tables', 'clock_collapse_metrics.csv')), 'file') == 2;

reader_id = ["RDR002"; "RDR007"];
reader_path = [
    string(fullfile(repoRoot, 'Aging', 'analysis', 'aging_fm_timescale_analysis.m'));
    string(fullfile(repoRoot, 'Aging', 'analysis', 'aging_tri_clock_consistency_test.m'))
    ];
required_artifacts = ["tau_vs_Tp.csv;fm_collapse_using_dip_tau_metrics.csv"; "tau_vs_Tp.csv;tau_FM_vs_Tp.csv"];
if (exist(char(dipTauPath),'file')==2) && (exist(char(fmUsingDipPath),'file')==2)
    a1 = "YES";
else
    a1 = "NO";
end
if (exist(char(dipTauPath),'file')==2) && (exist(char(fmTauPath),'file')==2)
    a2 = "YES";
else
    a2 = "NO";
end
artifacts_available = [a1; a2];
reader_ran = ["YES"; "YES"];
if rdr002Ok, ex1 = "SUCCESS"; cp1 = "tau_FM_vs_Tp_written"; fc1 = ""; else, ex1 = "FAILED"; cp1 = "not_reached"; fc1 = "SMOKE_FAILED"; end
if rdr007Ok, ex2 = "SUCCESS"; cp2 = "clock_collapse_metrics_written"; fc2 = ""; else, ex2 = "FAILED"; cp2 = "not_reached"; fc2 = "SMOKE_FAILED"; end
reader_exit_status = [ex1; ex2];
reached_checkpoint = [cp1; cp2];
reader_failure_class = [fc1; fc2];
reader_failure_message = [""; ""];
if rdr002Ok, rs1 = "PASS"; else, rs1 = "FAIL"; end
if rdr007Ok, rs2 = "PASS"; else, rs2 = "FAIL"; end
reader_status = [rs1; rs2];
reader_notes = ["Focused retry on multi-Tp dataset"; "Focused retry on multi-Tp dataset"];

smokeTbl = table(reader_id, reader_path, required_artifacts, artifacts_available, reader_ran, ...
    reader_exit_status, reached_checkpoint, reader_failure_class, reader_failure_message, reader_status, reader_notes, ...
    'VariableNames', {'reader_id','reader_path','required_artifacts','artifacts_available','ran', ...
    'exit_status','reached_checkpoint','failure_class','failure_message','status','notes'});
writetable(smokeTbl, readerSmokeCsv);

% Verdicts
dipTauWritten = exist(char(dipTauPath), 'file') == 2;
rescaleWritten = exist(char(rescalePath), 'file') == 2;
fmUsingDipWritten = exist(char(fmUsingDipPath), 'file') == 2;
fmTauWritten = exist(char(fmTauPath), 'file') == 2;
rdr002Pass = rdr002Ok;
rdr007Pass = rdr007Ok;
readyRobust = rdr002Pass && rdr007Pass && dipTauWritten && fmTauWritten;
readyDeep = readyRobust;

lines = strings(0,1);
lines(end+1,1) = "# Aging tau chain run report (G3b)";
lines(end+1,1) = "";
lines(end+1,1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1,1) = "";
lines(end+1,1) = "## Dataset used";
lines(end+1,1) = "- `"+string(datasetPath)+"`";
lines(end+1,1) = sprintf("- Distinct Tp count: %d", numel(tpVals));
lines(end+1,1) = sprintf("- Distinct tw count: %d", numel(twVals));
if hasHighTp
    lines(end+1,1) = "- High Tp 30/34 present: YES";
else
    lines(end+1,1) = "- High Tp 30/34 present: NO";
end
lines(end+1,1) = "";
lines(end+1,1) = "## Artifact chain attempted";
lines(end+1,1) = "- Dip tau extraction";
lines(end+1,1) = "- Tau rescaling estimates";
lines(end+1,1) = "- FM using Dip metrics";
lines(end+1,1) = "- FM tau extraction";
lines(end+1,1) = "- RDR002/RDR007 focused smoke";
lines(end+1,1) = "";
lines(end+1,1) = "## Commands run";
for i = 1:numel(cmds)
    lines(end+1,1) = "- " + cmds(i);
end
lines(end+1,1) = "";
lines(end+1,1) = "## Artifact validation";
lines(end+1,1) = "- Run status CSV: `"+string(runStatusCsv)+"`";
lines(end+1,1) = "- Inventory CSV: `"+string(artifactInvCsv)+"`";
lines(end+1,1) = "";
lines(end+1,1) = "## Reader results";
if rdr002Pass
    lines(end+1,1) = "- RDR002 (`aging_fm_timescale_analysis.m`): PASS";
else
    lines(end+1,1) = "- RDR002 (`aging_fm_timescale_analysis.m`): FAIL";
end
if rdr007Pass
    lines(end+1,1) = "- RDR007 (`aging_tri_clock_consistency_test.m`): PASS";
else
    lines(end+1,1) = "- RDR007 (`aging_tri_clock_consistency_test.m`): FAIL";
end
lines(end+1,1) = "";
lines(end+1,1) = "## Remaining blockers";
if rdr002Pass && rdr007Pass
    lines(end+1,1) = "- No immediate artifact-chain blocker for smoke readiness.";
else
    lines(end+1,1) = "- One or more readers did not reach artifact checkpoints; inspect `aging_tau_chain_reader_smoke_results.csv`.";
end
lines(end+1,1) = "";
lines(end+1,1) = "## Policy statements";
lines(end+1,1) = "- No physical synthesis was performed.";
lines(end+1,1) = "- No cross-module analysis was performed.";
lines(end+1,1) = "";
lines(end+1,1) = "## Final verdicts";
if (numel(tpVals) > 1) && (numel(twVals) > 1), lines(end+1,1) = "- TAU_CHAIN_DATASET_MULTITP_MULTITW = YES"; else, lines(end+1,1) = "- TAU_CHAIN_DATASET_MULTITP_MULTITW = NO"; end
if dipTauWritten, lines(end+1,1) = "- DIP_TAU_ARTIFACT_WRITTEN = YES"; else, lines(end+1,1) = "- DIP_TAU_ARTIFACT_WRITTEN = NO"; end
if rescaleWritten, lines(end+1,1) = "- TAU_RESCALING_ARTIFACT_WRITTEN = YES"; else, lines(end+1,1) = "- TAU_RESCALING_ARTIFACT_WRITTEN = NO"; end
if fmUsingDipWritten, lines(end+1,1) = "- FM_USING_DIP_METRICS_WRITTEN = YES"; else, lines(end+1,1) = "- FM_USING_DIP_METRICS_WRITTEN = NO"; end
if fmTauWritten, lines(end+1,1) = "- FM_TAU_ARTIFACT_WRITTEN = YES"; else, lines(end+1,1) = "- FM_TAU_ARTIFACT_WRITTEN = NO"; end
if rdr002Pass, lines(end+1,1) = "- RDR002_SMOKE_PASS = YES"; else, lines(end+1,1) = "- RDR002_SMOKE_PASS = NO"; end
if rdr007Pass, lines(end+1,1) = "- RDR007_SMOKE_PASS = YES"; else, lines(end+1,1) = "- RDR007_SMOKE_PASS = NO"; end
lines(end+1,1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1,1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
if readyRobust, lines(end+1,1) = "- READY_FOR_ROBUSTNESS_AUDIT = YES"; else, lines(end+1,1) = "- READY_FOR_ROBUSTNESS_AUDIT = PARTIAL"; end
if readyDeep, lines(end+1,1) = "- READY_FOR_DEEP_CANONICAL_REVIEW = YES"; else, lines(end+1,1) = "- READY_FOR_DEEP_CANONICAL_REVIEW = PARTIAL"; end

fid = fopen(reportPath, 'w');
assert(fid >= 0, 'Could not open report path: %s', reportPath);
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
fclose(fid);

disp('Stage G3b tau-chain run completed.');
disp(runStatusCsv);
disp(artifactInvCsv);
disp(readerSmokeCsv);
disp(reportPath);

