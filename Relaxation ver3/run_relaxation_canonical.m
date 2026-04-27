%% RUN_RELAXATION_CANONICAL
% Curve-first Relaxation creation-layer entrypoint (R4).
% No scalar canonical observable is produced in this script.

clear; clc;

cfg = struct();
scriptName = 'run_relaxation_canonical.m';
creationContract = 'CURVE_FIRST';
maxPointsPerTrace = 500;

experiment_name = 'relaxation_canonical';
run = createRunContext(experiment_name, struct());
if ~isfield(run, 'dir') || isempty(run.dir)
    run.dir = run.run_dir;
end

execution_status = "FAILED";
failure_summary = "";

num_input_files = 0;
num_loaded_traces = 0;
num_failed_traces = 0;
num_valid_creation_curves = 0;

try
    %% ==================================================================
    %% REPO ROOT + PATH SETUP
    %% ==================================================================
    current_dir = pwd;
    temp_dir = current_dir;
    repoRoot = '';
    for level = 1:15
        if exist(fullfile(temp_dir, 'README.md'), 'file') && ...
           exist(fullfile(temp_dir, 'Aging'), 'dir') && ...
           exist(fullfile(temp_dir, 'Switching'), 'dir')
            repoRoot = temp_dir;
            break;
        end
        parent_dir = fileparts(temp_dir);
        if strcmp(parent_dir, temp_dir)
            break;
        end
        temp_dir = parent_dir;
    end
    if isempty(repoRoot)
        error('Could not detect repo root - README.md not found');
    end

    addpath(fullfile(repoRoot, 'Aging', 'utils'));
    addpath(fullfile(repoRoot, 'Relaxation ver3'));

    %% ==================================================================
    %% USER CONFIG
    %% ==================================================================
    dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM';
    if isempty(dataDir) || exist(dataDir, 'dir') ~= 7
        error('dataDir must exist and be explicitly provided: %s', dataDir);
    end
    config = relaxation_config_helper(cfg);

    %% ==================================================================
    %% RUN DIR
    %% ==================================================================
    runDir = run.dir;
    if ~isfolder(runDir), mkdir(runDir); end
    tablesDir = fullfile(runDir, 'tables');
    if ~isfolder(tablesDir), mkdir(tablesDir); end
    reportsDir = fullfile(runDir, 'reports');
    if ~isfolder(reportsDir), mkdir(reportsDir); end

    %% ==================================================================
    %% LOADER INPUTS (RAW TRACE SOURCE OF TRUTH)
    %% ==================================================================
    [fileList, ~, ~, ~, ~, ~, traceListing] = getFileList_relaxation(dataDir, config.color_scheme);
    num_input_files = numel(fileList);
    if num_input_files == 0
        error('No input files discovered by getFileList_relaxation.');
    end

    loadOpts = struct('run_id', run.run_id, 'n_min_points', 3, 'traceListing', traceListing);
    [Time_table, ~, ~, Moment_table, ~, loaderAudit] = ...
        importFiles_relaxation(dataDir, fileList, config.normalize_by_mass, false, loadOpts);

    manifestT = loaderAudit.manifest;
    metricsT = loaderAudit.metrics;
    writetable(manifestT, fullfile(tablesDir, 'relaxation_raw_trace_manifest.csv'));
    writetable(metricsT, fullfile(tablesDir, 'relaxation_raw_trace_metrics.csv'));

    loaderStatus = string(manifestT.loader_status);
    num_loaded_traces = sum(loaderStatus == "LOADED");
    num_failed_traces = sum(loaderStatus ~= "LOADED");
    if num_loaded_traces == 0
        error('No LOADED traces available for curve-first outputs.');
    end

    %% ==================================================================
    %% CURVE SAMPLES (BOUNDED, DETERMINISTIC)
    %% ==================================================================
    sampleRows = table();
    samplePolicyLabel = "UNIFORM_INDEX_MAX500_NON_AUTHORITATIVE_NORM";
    curveSampleTableName = "relaxation_curve_samples.csv";

    for i = 1:height(manifestT)
        if loaderStatus(i) ~= "LOADED"
            continue;
        end
        if i > numel(Time_table) || i > numel(Moment_table)
            continue;
        end
        t = Time_table{i};
        m = Moment_table{i};
        if isempty(t) || isempty(m)
            continue;
        end
        t = t(:);
        m = m(:);
        n = numel(t);
        if n == 0
            continue;
        end

        k = min(maxPointsPerTrace, n);
        if k == n
            idx = (1:n)';
        else
            idx = unique(round(linspace(1, n, k)))';
            if idx(end) ~= n
                idx(end) = n;
            end
        end

        mNorm = nan(size(idx));
        den = m(1) - m(end);
        if abs(den) > 1e-12
            mNorm = (m(idx) - m(end)) ./ den;
        end

        tmp = table( ...
            repmat(string(manifestT.trace_id{i}), numel(idx), 1), ...
            (1:numel(idx))', ...
            idx, ...
            t(idx), ...
            m(idx), ...
            mNorm, ...
            repmat(samplePolicyLabel, numel(idx), 1), ...
            'VariableNames', {'trace_id', 'sample_index', 'original_index', ...
            'time', 'moment', 'moment_normalized', 'sample_policy'});
        sampleRows = [sampleRows; tmp]; %#ok<AGROW>
    end
    writetable(sampleRows, fullfile(tablesDir, curveSampleTableName));

    %% ==================================================================
    %% CURVE QUALITY
    %% ==================================================================
    signal_valid = isfinite(metricsT.delta_M) & (metricsT.n_points > 0);
    timebase_valid = logical(metricsT.time_monotonic) & (metricsT.nonpositive_dt_count == 0);
    curve_valid = (loaderStatus == "LOADED") & signal_valid & timebase_valid;
    num_valid_creation_curves = sum(curve_valid);

    quality_flags = strings(height(metricsT), 1);
    for i = 1:height(metricsT)
        flags = strings(0, 1);
        if loaderStatus(i) ~= "LOADED"
            flags(end+1) = "LOADER_FAILED"; %#ok<AGROW>
        end
        if ~signal_valid(i)
            flags(end+1) = "SIGNAL_INVALID"; %#ok<AGROW>
        end
        if ~timebase_valid(i)
            flags(end+1) = "TIMEBASE_INVALID"; %#ok<AGROW>
        end
        if metricsT.duplicate_time_count(i) > 0
            flags(end+1) = "HAS_DUPLICATES"; %#ok<AGROW>
        end
        if isempty(flags)
            quality_flags(i) = "OK";
        else
            quality_flags(i) = strjoin(flags, ';');
        end
    end

    qualityT = table( ...
        string(metricsT.trace_id), metricsT.n_points, metricsT.duration, metricsT.delta_M, ...
        metricsT.std_M, logical(metricsT.time_monotonic), metricsT.duplicate_time_count, ...
        metricsT.nonpositive_dt_count, logical(signal_valid), logical(timebase_valid), ...
        logical(curve_valid), quality_flags, ...
        'VariableNames', {'trace_id', 'n_points', 'duration', 'delta_M', 'std_M', ...
        'time_monotonic', 'duplicate_time_count', 'nonpositive_dt_count', ...
        'signal_valid', 'timebase_valid', 'curve_valid', 'quality_flags'});
    writetable(qualityT, fullfile(tablesDir, 'relaxation_curve_quality.csv'));

    %% ==================================================================
    %% CURVE INDEX
    %% ==================================================================
    curve_status = repmat("SKIPPED_FAILED", height(manifestT), 1);
    curve_status(curve_valid) = "CREATED";

    curve_sample_file_or_table = strings(height(manifestT), 1);
    curve_sample_file_or_table(curve_valid) = curveSampleTableName;

    is_creation_curve = curve_valid;

    temperature = nan(height(manifestT), 1);
    if ismember('table_median_T_K', metricsT.Properties.VariableNames)
        temperature = metricsT.table_median_T_K;
    end
    parsed_temperature = manifestT.parsed_temperature_K;

    field_condition = strings(height(manifestT), 1);
    for i = 1:height(manifestT)
        if isfinite(manifestT.parsed_field_Oe(i))
            field_condition(i) = sprintf('FC_%g_Oe', manifestT.parsed_field_Oe(i));
        else
            field_condition(i) = "UNKNOWN_FIELD";
        end
    end

    indexT = table( ...
        string(manifestT.trace_id), manifestT.file_index, string(manifestT.file_name), ...
        temperature, parsed_temperature, field_condition, metricsT.n_points, ...
        string(manifestT.loader_status), string(manifestT.failure_reason), ...
        curve_status, curve_sample_file_or_table, logical(is_creation_curve), ...
        'VariableNames', {'trace_id', 'file_index', 'file_name', 'temperature', ...
        'parsed_temperature', 'field_condition', 'n_points', 'loader_status', ...
        'failure_reason', 'curve_status', 'curve_sample_file_or_table', ...
        'is_creation_curve'});
    writetable(indexT, fullfile(tablesDir, 'relaxation_curve_index.csv'));

    %% ==================================================================
    %% CREATION STATUS + REPORT
    %% ==================================================================
    curve_outputs_written = ...
        exist(fullfile(tablesDir, 'relaxation_raw_trace_manifest.csv'), 'file') == 2 && ...
        exist(fullfile(tablesDir, 'relaxation_raw_trace_metrics.csv'), 'file') == 2 && ...
        exist(fullfile(tablesDir, 'relaxation_curve_index.csv'), 'file') == 2 && ...
        exist(fullfile(tablesDir, 'relaxation_curve_samples.csv'), 'file') == 2 && ...
        exist(fullfile(tablesDir, 'relaxation_curve_quality.csv'), 'file') == 2;

    creationStatus = table( ...
        "CURVE_FIRST", "NO", "NO", "NO", "NO", "YES", "NO", "NO", ...
        string(curve_outputs_written), string(num_valid_creation_curves > 0), ...
        'VariableNames', {'CREATION_CONTRACT', 'SCALAR_CANONICAL_OUTPUT', ...
        'FIT_TAU_BETA_CANONICAL', 'LOG_SLOPE_CANONICAL', 'HALF_TIME_CANONICAL', ...
        'RAW_TRACE_SOURCE', 'PRECOMPUTED_INPUTS_USED', 'ROOT_OUTPUTS_WRITTEN', ...
        'CURVE_OUTPUTS_WRITTEN', 'READY_FOR_R5_REPLAY_DECISION'});
    writetable(creationStatus, fullfile(tablesDir, 'relaxation_creation_status.csv'));

    reportPath = fullfile(reportsDir, 'relaxation_canonical_curve_first_report.md');
    reportLines = {
        '# Relaxation Canonical Curve-First Run'
        ''
        sprintf('- Run ID: `%s`', run.run_id)
        sprintf('- Run directory: `%s`', runDir)
        sprintf('- Data source: `%s`', dataDir)
        sprintf('- Creation contract: `%s`', creationContract)
        ''
        '## Input/Loader Summary'
        sprintf('- Input files discovered: %d', num_input_files)
        sprintf('- Loaded traces: %d', num_loaded_traces)
        sprintf('- Failed traces: %d', num_failed_traces)
        sprintf('- Valid creation curves: %d', num_valid_creation_curves)
        ''
        '## Canonical Policy'
        '- Scalar canonical output: NO'
        '- Fit tau/beta canonical: NO'
        '- Log-slope canonical: NO'
        '- Half-time canonical: NO'
        '- Precomputed inputs used: NO'
        '- Root outputs written: NO'
        ''
        '## Run-Scoped Outputs'
        '- `tables/relaxation_raw_trace_manifest.csv`'
        '- `tables/relaxation_raw_trace_metrics.csv`'
        '- `tables/relaxation_curve_index.csv`'
        '- `tables/relaxation_curve_samples.csv`'
        '- `tables/relaxation_curve_quality.csv`'
        '- `tables/relaxation_creation_status.csv`'
        '- `execution_status.csv`'
        ''
        'Diagnostic fit summaries are intentionally omitted in this curve-first R4 path.'
        };
    fid = fopen(reportPath, 'w');
    if fid < 0
        error('Could not write report: %s', reportPath);
    end
    for i = 1:numel(reportLines)
        fprintf(fid, '%s\n', reportLines{i});
    end
    fclose(fid);

    %% ==================================================================
    %% EXECUTION STATUS
    %% ==================================================================
    execution_status = "SUCCESS";
    failure_summary = "";

catch ME
    execution_status = "FAILED";
    failure_summary = string(ME.message);
    try
        fid = fopen(fullfile(run.run_dir, 'error_report.txt'), 'w');
        if fid >= 0
            fprintf(fid, '%s\n', getReport(ME, 'extended'));
            fclose(fid);
        end
    catch
    end
    disp('=== MATLAB ERROR ===');
    disp(getReport(ME, 'extended'));
end

statusT = table( ...
    string(execution_status), string(run.run_id), string(scriptName), string(creationContract), ...
    num_input_files, num_loaded_traces, num_failed_traces, num_valid_creation_curves, ...
    string(failure_summary), ...
    'VariableNames', {'status', 'run_id', 'script', 'creation_contract', ...
    'num_input_files', 'num_loaded_traces', 'num_failed_traces', ...
    'num_valid_creation_curves', 'failure_summary'});
writetable(statusT, fullfile(run.run_dir, 'execution_status.csv'));
