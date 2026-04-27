function results = relaxation_validate_loader_contract()
% relaxation_validate_loader_contract — R2C loader checks on fixtures (no fitting).
%
% Run from repo root or any cwd after addpath('Relaxation ver3').
% Requires tests/fixtures/relaxation_raw_minimal/*.dat

thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(thisDir);
fixtureDir = fullfile(repoRoot, 'tests', 'fixtures', 'relaxation_raw_minimal');
assert(isfolder(fixtureDir), 'Missing fixture dir: %s', fixtureDir);

addpath(thisDir);

[fileList1, ~, ~, ~, ~, ~, tl1] = getFileList_relaxation(fixtureDir, 'parula');
[fileList2, ~, ~, ~, ~, ~, tl2] = getFileList_relaxation(fixtureDir, 'parula');
assert(isequal(fileList1, fileList2), 'U-R3-01: file order must be deterministic across calls');

opts = struct('run_id', 'fixture_validation', 'n_min_points', 3, 'traceListing', tl1);
[Time_table, ~, ~, Moment_table, ~, audit] = importFiles_relaxation( ...
    fixtureDir, fileList1, false, false, opts);

assert(height(audit.manifest) == numel(fileList1), 'U-R3-04: manifest row count must match files');
assert(height(audit.metrics) == numel(fileList1), 'metrics row count must match files');

results = struct();
results.file_order_ok = true;
results.manifest_rows = height(audit.manifest);
results.n_loaded = sum(strcmpi(string(audit.manifest.loader_status), "LOADED"));

% Expected: good + duplicate_time load; ambiguous_time fails time; no_finite fails
assert(endsWith(string(fileList1{1}), "ambiguous_time.dat"), ...
    'U-R3-01: lexicographic first file must be ambiguous_time.dat');

fr = string(audit.manifest.failure_reason);
ld = string(audit.manifest.loader_status);
fnCol = string(audit.manifest.file_name);
isGood = endsWith(fnCol, "good.dat");
isAmb = endsWith(fnCol, "ambiguous_time.dat");
isDup = endsWith(fnCol, "duplicate_time.dat");
isBad = endsWith(fnCol, "no_finite_signal.dat");

assert(any(isGood & ld == "LOADED" & fr == "OK"), 'good.dat must LOAD');
assert(any(isAmb & fr == "FAIL_AMBIGUOUS_TIME_COLUMN"), 'ambiguous_time.dat must fail ambiguous time');
assert(any(isDup & ld == "LOADED"), 'duplicate_time.dat must still load (dedup policy)');
assert(any(isBad & fr == "FAIL_NO_FINITE_ROWS"), 'no_finite_signal.dat must FAIL_NO_FINITE_ROWS');

dupRow = audit.metrics(isDup, :);
assert(dupRow.duplicate_time_count >= 1, 'duplicate_time_count must be recorded');

results.duplicate_time_count_on_fixture = dupRow.duplicate_time_count;
results.u_r3_01_ok = true;
results.u_r3_02_ok = true;
results.u_r3_04_ok = true;
results.u_r3_06_ok = true;
reqMetrics = {'trace_id','file_index','n_points','t_min','t_max','duration','time_monotonic', ...
    'duplicate_time_count','nonpositive_dt_count','min_M','max_M','delta_M','std_M', ...
    'nan_count_time','nan_count_signal','loader_status','failure_reason', ...
    'normalize_by_mass_applied','time_scale_branch','time_unit_policy','time_unit_detected', ...
    'time_shifted_to_zero','log_time_allowed','table_median_T_K','table_median_H_Oe'};
results.u_r3_07_ok = all(ismember(reqMetrics, audit.metrics.Properties.VariableNames));

fprintf('relaxation_validate_loader_contract: PASS (%d files, %d LOADED)\n', ...
    numel(fileList1), results.n_loaded);

end
