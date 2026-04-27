%% RUN_RELAXATION_POST_FIELD_OFF_CANONICAL (RF3)
% Event-origin-correct canonical curve creation for Relaxation:
%   DeltaM(t - t_field_off; T), post-field-off only.

clear; clc;

cfg = struct();
scriptName = 'run_relaxation_post_field_off_canonical.m';
creationContract = 'DELTA_M_POST_FIELD_OFF';
maxPointsPerTrace = 500;
minPostFieldPoints = 3;

% Frozen-for-RF3 detection/sign conventions (explicitly recorded in outputs)
lowFieldThresholdOe = 1.0;
highFieldQuantile = 0.90;
highFieldMinOe = 20.0;
minLowFractionAfter = 0.90;
fieldBeforeAfterWindow = 10;
signRule = "RF3_SIGN_DIAGNOSTIC:DeltaM=M_post-M_field_off";
baselineRule = "BASELINE_AT_FIRST_POST_FIELD_OFF_POINT";
samplePolicyLabel = "UNIFORM_INDEX_MAX500_POST_FIELD_OFF";

experiment_name = 'relaxation_post_field_off_canonical';
run = createRunContext(experiment_name, struct());
if ~isfield(run, 'dir') || isempty(run.dir)
    run.dir = run.run_dir;
end

execution_status = "FAILED";
failure_summary = "";
num_input_files = 0;
num_loaded_traces = 0;
num_invalid_for_relaxation = 0;
num_valid_creation_curves = 0;

try
    %% Repo root
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

    %% Data source (real Relaxation raw dataset)
    dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM';
    if isempty(dataDir) || exist(dataDir, 'dir') ~= 7
        error('RF3 dataDir must exist: %s', dataDir);
    end
    config = relaxation_config_helper(cfg);

    %% Run dirs
    runDir = run.dir;
    if ~isfolder(runDir), mkdir(runDir); end
    tablesDir = fullfile(runDir, 'tables');
    if ~isfolder(tablesDir), mkdir(tablesDir); end
    reportsDir = fullfile(runDir, 'reports');
    if ~isfolder(reportsDir), mkdir(reportsDir); end

    %% Load deterministic file list and raw traces
    [fileList, ~, ~, ~, ~, ~, traceListing] = getFileList_relaxation(dataDir, config.color_scheme);
    num_input_files = numel(fileList);
    if num_input_files == 0
        error('No input files discovered by getFileList_relaxation.');
    end

    loadOpts = struct('run_id', run.run_id, 'n_min_points', 3, 'traceListing', traceListing);
    [Time_table, Temp_table, Field_table, Moment_table, ~, loaderAudit] = ...
        importFiles_relaxation(dataDir, fileList, config.normalize_by_mass, false, loadOpts);

    manifestT = loaderAudit.manifest;
    metricsT = loaderAudit.metrics;
    loaderStatus = string(manifestT.loader_status);
    num_loaded_traces = sum(loaderStatus == "LOADED");
    if num_loaded_traces == 0
        error('No LOADED traces available for RF3 canonical creation.');
    end

    %% Build RF3 outputs
    eventRows = table();
    indexRows = table();
    sampleRows = table();
    qualityRows = table();

    for i = 1:height(manifestT)
        trace_id = string(manifestT.trace_id{i});
        source_file = string(manifestT.file_path{i});
        file_name = string(manifestT.file_name{i});
        temperature = NaN;
        if ismember('table_median_T_K', metricsT.Properties.VariableNames)
            temperature = metricsT.table_median_T_K(i);
        end
        if ~isfinite(temperature)
            temperature = manifestT.parsed_temperature_K(i);
        end

        defaultInvalid = "";
        raw_time_column = "UNKNOWN";
        raw_field_column = "UNKNOWN";
        raw_magnetization_column = "UNKNOWN";
        detected_field_off_index = NaN;
        detected_field_off_time = NaN;
        field_before = NaN;
        field_after = NaN;
        field_delta = NaN;
        field_off_detection_method = "UNSET";
        field_off_detection_confidence = "UNKNOWN";
        canonical_start_time = NaN;
        canonical_start_minus_field_off = NaN;
        pre_field_off_points_excluded = NaN;
        post_field_off_points_retained = 0;
        contains_pre_field_off_points = "UNKNOWN";
        M_at_field_off_or_baseline = NaN;
        trace_valid_for_relaxation = "NO";
        invalid_reason = "";

        if loaderStatus(i) ~= "LOADED"
            invalid_reason = string(manifestT.failure_reason{i});
            if strlength(strtrim(invalid_reason)) == 0
                invalid_reason = "FAIL_LOADER_STATUS_NOT_LOADED";
            end
        else
            t = Time_table{i};
            h = Field_table{i};
            m = Moment_table{i};
            tc = Temp_table{i}; %#ok<NASGU>
            if isempty(t) || isempty(h) || isempty(m)
                invalid_reason = "FAIL_EMPTY_TRACE_PAYLOAD";
            else
                [raw_time_column, raw_field_column, raw_magnetization_column, colErr] = ...
                    local_resolveRawColumnNames(char(source_file));
                if strlength(colErr) > 0
                    invalid_reason = "FAIL_RF3_COLUMN_RESOLUTION_" + colErr;
                else
                    [det, detErr] = local_detectFieldOff(t, h, lowFieldThresholdOe, ...
                        highFieldQuantile, highFieldMinOe, minLowFractionAfter, fieldBeforeAfterWindow);
                    if strlength(detErr) > 0
                        invalid_reason = "FAIL_FIELD_OFF_DETECTION_" + detErr;
                    else
                        detected_field_off_index = det.idx;
                        detected_field_off_time = det.t_field_off;
                        field_before = det.field_before;
                        field_after = det.field_after;
                        field_delta = det.field_delta;
                        field_off_detection_method = det.method;
                        field_off_detection_confidence = det.confidence;

                        idx0 = det.idx;
                        t_post = t(idx0:end);
                        m_post = m(idx0:end);
                        t_rel = t_post - t(idx0);
                        preCount = idx0 - 1;
                        postCount = numel(t_rel);

                        if any(t_rel < -1e-12)
                            invalid_reason = "FAIL_NEGATIVE_TIME_AFTER_FIELD_OFF_RESET";
                        elseif postCount < minPostFieldPoints
                            invalid_reason = "FAIL_INSUFFICIENT_POST_FIELD_OFF_POINTS";
                        else
                            baseline = m_post(1);
                            dM = m_post - baseline;

                            trace_valid_for_relaxation = "YES";
                            invalid_reason = "";
                            canonical_start_time = t_post(1);
                            canonical_start_minus_field_off = canonical_start_time - detected_field_off_time;
                            pre_field_off_points_excluded = preCount;
                            post_field_off_points_retained = postCount;
                            contains_pre_field_off_points = "NO";
                            M_at_field_off_or_baseline = baseline;

                            % Curve samples
                            k = min(maxPointsPerTrace, postCount);
                            if k == postCount
                                sIdx = (1:postCount)';
                            else
                                sIdx = unique(round(linspace(1, postCount, k)))';
                                if sIdx(end) ~= postCount
                                    sIdx(end) = postCount;
                                end
                            end
                            tmpSamples = table( ...
                                repmat(string(run.run_id), numel(sIdx), 1), ...
                                repmat(trace_id, numel(sIdx), 1), ...
                                repmat(source_file, numel(sIdx), 1), ...
                                (1:numel(sIdx))', ...
                                (idx0 - 1) + sIdx, ...
                                t_rel(sIdx), ...
                                dM(sIdx), ...
                                m_post(sIdx), ...
                                repmat(baseline, numel(sIdx), 1), ...
                                repmat(baselineRule, numel(sIdx), 1), ...
                                repmat(signRule, numel(sIdx), 1), ...
                                repmat(samplePolicyLabel, numel(sIdx), 1), ...
                                'VariableNames', {'run_id', 'trace_id', 'source_file', 'sample_index', ...
                                'original_index', 'time_since_field_off', 'delta_m', 'moment_post_field_off', ...
                                'baseline_value', 'baseline_rule', 'sign_rule', 'sample_policy'});
                            sampleRows = [sampleRows; tmpSamples]; %#ok<AGROW>
                        end
                    end
                end
            end
        end

        if trace_valid_for_relaxation == "NO"
            contains_pre_field_off_points = "UNKNOWN";
            if strlength(strtrim(invalid_reason)) == 0
                invalid_reason = "FAIL_UNSPECIFIED_RF3";
            end
        end

        eventRow = table( ...
            string(run.run_id), trace_id, source_file, temperature, ...
            raw_time_column, raw_field_column, raw_magnetization_column, ...
            detected_field_off_index, detected_field_off_time, ...
            field_before, field_after, field_delta, ...
            field_off_detection_method, field_off_detection_confidence, ...
            canonical_start_time, canonical_start_minus_field_off, ...
            pre_field_off_points_excluded, post_field_off_points_retained, ...
            contains_pre_field_off_points, M_at_field_off_or_baseline, ...
            baselineRule, signRule, trace_valid_for_relaxation, invalid_reason, ...
            'VariableNames', {'run_id', 'trace_id', 'source_file', 'temperature', ...
            'raw_time_column', 'raw_field_column', 'raw_magnetization_column', ...
            'detected_field_off_index', 'detected_field_off_time', ...
            'field_before', 'field_after', 'field_delta', ...
            'field_off_detection_method', 'field_off_detection_confidence', ...
            'canonical_start_time', 'canonical_start_minus_field_off', ...
            'pre_field_off_points_excluded', 'post_field_off_points_retained', ...
            'contains_pre_field_off_points', 'M_at_field_off_or_baseline', ...
            'baseline_rule', 'sign_rule', 'trace_valid_for_relaxation', 'invalid_reason'});
        eventRows = [eventRows; eventRow]; %#ok<AGROW>

        idxRow = table( ...
            string(run.run_id), trace_id, file_name, source_file, temperature, ...
            trace_valid_for_relaxation, invalid_reason, ...
            detected_field_off_time, post_field_off_points_retained, ...
            "tables/relaxation_post_field_off_curve_samples.csv", ...
            'VariableNames', {'run_id', 'trace_id', 'file_name', 'source_file', 'temperature', ...
            'trace_valid_for_relaxation', 'invalid_reason', 'detected_field_off_time', ...
            'post_field_off_points_retained', 'curve_sample_file_or_table'});
        indexRows = [indexRows; idxRow]; %#ok<AGROW>

        hasNeg = false;
        if trace_valid_for_relaxation == "YES"
            hasNeg = canonical_start_minus_field_off < -1e-12;
        end
        qRow = table( ...
            string(run.run_id), trace_id, logical(trace_valid_for_relaxation == "YES"), ...
            logical(~hasNeg), post_field_off_points_retained, ...
            string(field_off_detection_confidence), string(invalid_reason), ...
            'VariableNames', {'run_id', 'trace_id', 'trace_valid_for_relaxation', ...
            'canonical_start_nonnegative_check', 'post_field_off_points_retained', ...
            'field_off_detection_confidence', 'invalid_reason'});
        qualityRows = [qualityRows; qRow]; %#ok<AGROW>
    end

    % Write RF3 tables
    writetable(eventRows, fullfile(tablesDir, 'relaxation_event_origin_manifest.csv'));
    writetable(indexRows, fullfile(tablesDir, 'relaxation_post_field_off_curve_index.csv'));
    writetable(sampleRows, fullfile(tablesDir, 'relaxation_post_field_off_curve_samples.csv'));
    writetable(qualityRows, fullfile(tablesDir, 'relaxation_post_field_off_curve_quality.csv'));

    % RF3 status derivation
    validMask = string(eventRows.trace_valid_for_relaxation) == "YES";
    num_valid_creation_curves = sum(validMask);
    num_invalid_for_relaxation = sum(~validMask);
    loadedMask = loaderStatus == "LOADED";
    loadedN = sum(loadedMask);
    detectedN = sum(isfinite(eventRows.detected_field_off_index) & loadedMask);
    canonicalEqN = sum(abs(eventRows.canonical_start_minus_field_off(validMask)) <= 1e-9);
    baseAppliedN = sum(isfinite(eventRows.M_at_field_off_or_baseline(validMask)));
    signRecorded = all(strlength(strtrim(string(eventRows.sign_rule(validMask)))) > 0);
    preIncluded = any(string(eventRows.contains_pre_field_off_points(validMask)) == "YES");

    fieldUsedStatus = local_ratioToTri(detectedN, loadedN);
    detectedAllStatus = local_ratioToTri(detectedN, loadedN);
    canonEqStatus = local_ratioToTri(canonicalEqN, max(num_valid_creation_curves, 1));
    postOnlyStatus = "YES";
    timeResetStatus = canonEqStatus;
    baselineStatus = local_ratioToTri(baseAppliedN, max(num_valid_creation_curves, 1));
    signStatus = local_boolToYN(signRecorded);
    % At this point execution_status.csv is not written yet, so evaluate
    % run-scoped outputs without that file and finalize after status write.
    runScopedStatus = local_boolToYN(local_outputsExist(runDir, false));
    rf3Complete = local_boolToYN(num_valid_creation_curves > 0 && ~preIncluded);
    readyRF4 = local_boolToYN(num_valid_creation_curves > 0 && ~preIncluded);

    creationStatus = table( ...
        rf3Complete, "DELTA_M_POST_FIELD_OFF", fieldUsedStatus, detectedAllStatus, ...
        canonEqStatus, postOnlyStatus, timeResetStatus, "NO", baselineStatus, ...
        signStatus, "NO", "NO", runScopedStatus, readyRF4, "NO", "NO", ...
        'VariableNames', {'RF3_EVENT_ORIGIN_CORRECT_CREATION_COMPLETE', 'PHYSICAL_OBJECT', ...
        'FIELD_COLUMN_USED', 'FIELD_OFF_DETECTED_ALL_TRACES', ...
        'CANONICAL_START_EQUALS_FIELD_OFF', 'CANONICAL_CURVES_ARE_POST_FIELD_OFF', ...
        'CANONICAL_TIME_RESET_AT_FIELD_OFF', 'PRE_FIELD_POINTS_INCLUDED', ...
        'BASELINE_RULE_APPLIED', 'SIGN_RULE_RECORDED', 'OLD_FULL_TRACE_RUN_REUSED', ...
        'OLD_PRECOMPUTED_ARTIFACTS_USED', 'OUTPUTS_RUN_SCOPED', ...
        'READY_FOR_RF4_VISUAL_PROOF', 'READY_FOR_COLLAPSE_REPLAY', ...
        'READY_FOR_CROSS_MODULE_ANALYSIS'});
    writetable(creationStatus, fullfile(tablesDir, 'relaxation_post_field_off_creation_status.csv'));

    %% Report
    reportPath = fullfile(reportsDir, 'relaxation_post_field_off_canonical_report.md');
    invalidRows = eventRows(~validMask, :);
    nAmbiguous = sum(contains(string(invalidRows.invalid_reason), "AMBIGUOUS", 'IgnoreCase', true));
    lines = {
        '# Relaxation RF3 Event-Origin-Correct Canonical Curve Run'
        ''
        sprintf('- Run ID: `%s`', run.run_id)
        sprintf('- Run directory: `%s`', runDir)
        sprintf('- Data source: `%s`', dataDir)
        ''
        '## Quarantine and scope statement'
        '- Old full-trace canonical run remains quarantined and unchanged.'
        '- Physical object implemented here: `DeltaM(t - t_field_off; T)` using post-field-off points only.'
        '- No SVD/collapse/time-mode/cross-module conclusions are produced in RF3.'
        ''
        '## Field-off detection rule'
        sprintf('- Primary rule: identify first index where `|H| <= %.3f Oe` and a sustained low-field tail is present after a prior high-field regime.', lowFieldThresholdOe)
        sprintf('- High-field regime is defined from trace scale (`q%.2f(|H|)`) with minimum %.1f Oe.', highFieldQuantile, highFieldMinOe)
        sprintf('- Sustained low-field requirement after candidate event: >= %.2f fraction of points below threshold.', minLowFractionAfter)
        '- Detection metadata recorded per trace: field_before, field_after, field_delta, method, confidence.'
        ''
        '## Trace summary'
        sprintf('- Input files discovered: %d', num_input_files)
        sprintf('- Loader LOADED traces: %d', num_loaded_traces)
        sprintf('- Valid post-field-off canonical traces: %d', num_valid_creation_curves)
        sprintf('- Invalid traces for canonical relaxation: %d', num_invalid_for_relaxation)
        sprintf('- Ambiguous traces (column or field-off ambiguity): %d', nAmbiguous)
        ''
        '## RF3 outputs'
        '- `execution_status.csv`'
        '- `tables/relaxation_event_origin_manifest.csv`'
        '- `tables/relaxation_post_field_off_curve_index.csv`'
        '- `tables/relaxation_post_field_off_curve_samples.csv`'
        '- `tables/relaxation_post_field_off_curve_quality.csv`'
        '- `tables/relaxation_post_field_off_creation_status.csv`'
        '- `reports/relaxation_post_field_off_canonical_report.md`'
        ''
        '## Gate status'
        '- READY_FOR_RF4_VISUAL_PROOF: as recorded in `relaxation_post_field_off_creation_status.csv`.'
        '- READY_FOR_COLLAPSE_REPLAY: NO.'
        '- READY_FOR_CROSS_MODULE_ANALYSIS: NO.'
        };
    fid = fopen(reportPath, 'w');
    if fid < 0
        error('Could not write report: %s', reportPath);
    end
    for k = 1:numel(lines)
        fprintf(fid, '%s\n', lines{k});
    end
    fclose(fid);

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
    num_input_files, num_loaded_traces, num_invalid_for_relaxation, num_valid_creation_curves, ...
    string(failure_summary), ...
    'VariableNames', {'status', 'run_id', 'script', 'creation_contract', ...
    'num_input_files', 'num_loaded_traces', 'num_invalid_for_relaxation', ...
    'num_valid_creation_curves', 'failure_summary'});
writetable(statusT, fullfile(run.run_dir, 'execution_status.csv'));

% Finalize OUTPUTS_RUN_SCOPED after execution_status.csv is present.
if execution_status == "SUCCESS"
    creationStatusPath = fullfile(run.run_dir, 'tables', 'relaxation_post_field_off_creation_status.csv');
    if exist('creationStatus', 'var') == 1
        creationStatus.OUTPUTS_RUN_SCOPED(:) = local_boolToYN(local_outputsExist(run.run_dir, true));
        writetable(creationStatus, creationStatusPath);
    end
end

%% ========================== Local helpers ================================
function tri = local_ratioToTri(nGood, nTot)
if nTot <= 0
    tri = "NO";
elseif nGood == nTot
    tri = "YES";
elseif nGood <= 0
    tri = "NO";
else
    tri = "PARTIAL";
end
end

function yn = local_boolToYN(tf)
if tf
    yn = "YES";
else
    yn = "NO";
end
end

function ok = local_outputsExist(runDir, includeExecutionStatus)
if nargin < 2
    includeExecutionStatus = true;
end

coreOk = ...
    exist(fullfile(runDir, 'tables', 'relaxation_event_origin_manifest.csv'), 'file') == 2 && ...
    exist(fullfile(runDir, 'tables', 'relaxation_post_field_off_curve_index.csv'), 'file') == 2 && ...
    exist(fullfile(runDir, 'tables', 'relaxation_post_field_off_curve_samples.csv'), 'file') == 2 && ...
    exist(fullfile(runDir, 'tables', 'relaxation_post_field_off_curve_quality.csv'), 'file') == 2 && ...
    exist(fullfile(runDir, 'tables', 'relaxation_post_field_off_creation_status.csv'), 'file') == 2 && ...
    exist(fullfile(runDir, 'reports', 'relaxation_post_field_off_canonical_report.md'), 'file') == 2;

if includeExecutionStatus
    ok = coreOk && (exist(fullfile(runDir, 'execution_status.csv'), 'file') == 2);
else
    ok = coreOk;
end
end

function [timeCol, fieldCol, momentCol, errTag] = local_resolveRawColumnNames(filePath)
timeCol = "UNKNOWN";
fieldCol = "UNKNOWN";
momentCol = "UNKNOWN";
errTag = "";

try
    optsRead = detectImportOptions(filePath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    names = string(optsRead.VariableNames);
catch
    errTag = "READTABLE_FAILED";
    return;
end

normNames = local_normNames(names);
[iTime, eTime] = local_pickColumn(normNames, 'time');
[iField, eField] = local_pickColumn(normNames, 'field');
[iMoment, eMoment] = local_pickColumn(normNames, 'moment');

if ~isempty(eTime)
    errTag = eTime;
    return;
end
if ~isempty(eField)
    errTag = eField;
    return;
end
if ~isempty(eMoment)
    errTag = eMoment;
    return;
end
if isempty(iTime) || isempty(iField) || isempty(iMoment)
    errTag = "MISSING_REQUIRED_COLUMNS";
    return;
end

timeCol = names(iTime);
fieldCol = names(iField);
momentCol = names(iMoment);
end

function [det, errTag] = local_detectFieldOff(t, h, lowTh, highQ, highMin, minLowFrac, nWin)
det = struct('idx', NaN, 't_field_off', NaN, 'field_before', NaN, ...
    'field_after', NaN, 'field_delta', NaN, ...
    'method', "FIELD_THRESHOLD_WITH_SUSTAINED_LOW_TAIL", 'confidence', "LOW");
errTag = "";

t = t(:);
h = h(:);
if numel(t) ~= numel(h) || numel(t) < 5
    errTag = "INSUFFICIENT_OR_MISMATCHED_LENGTH";
    return;
end
if any(~isfinite(t)) || any(~isfinite(h))
    errTag = "NONFINITE_TIME_OR_FIELD";
    return;
end

absH = abs(h);
highRef = quantile(absH, highQ);
highTh = max(highMin, 0.35 * highRef);
if ~isfinite(highTh) || highTh <= lowTh
    errTag = "INVALID_HIGH_FIELD_THRESHOLD";
    return;
end

below = absH <= lowTh;
above = absH >= highTh;
if ~any(above)
    errTag = "NO_HIGH_FIELD_REGION";
    return;
end
if ~any(below)
    errTag = "NO_LOW_FIELD_REGION";
    return;
end

idx = NaN;
for k = 2:numel(t)
    if ~below(k)
        continue;
    end
    hadHighBefore = any(above(1:k-1));
    if ~hadHighBefore
        continue;
    end
    tail = below(k:end);
    lowFrac = mean(double(tail));
    if lowFrac >= minLowFrac
        idx = k;
        break;
    end
end

if ~isfinite(idx)
    errTag = "NO_SUSTAINED_LOW_FIELD_AFTER_HIGH_FIELD";
    return;
end

i0 = max(1, idx - nWin);
i1 = min(numel(h), idx + nWin);
beforeVals = h(i0:max(i0, idx-1));
afterVals = h(idx:i1);
if isempty(beforeVals), beforeVals = h(max(1, idx-1)); end
if isempty(afterVals), afterVals = h(idx); end

det.idx = idx;
det.t_field_off = t(idx);
det.field_before = median(beforeVals, 'omitnan');
det.field_after = median(afterVals, 'omitnan');
det.field_delta = det.field_after - det.field_before;

dropMag = abs(det.field_before) - abs(det.field_after);
if dropMag >= 0.7 * highTh
    det.confidence = "HIGH";
elseif dropMag >= 0.3 * highTh
    det.confidence = "MEDIUM";
else
    det.confidence = "LOW";
end
end

function normNames = local_normNames(names)
normNames = strings(numel(names), 1);
for i = 1:numel(names)
    s = lower(strtrim(string(names(i))));
    s = regexprep(s, '\s+', ' ');
    normNames(i) = s;
end
end

function [idx, errTag] = local_pickColumn(normNames, role)
idx = [];
errTag = '';
switch lower(role)
    case 'time'
        allow = ["time stamp (sec)", "time stamp", "timestamp", "sample timestamp", ...
            "elapsed time (s)", "elapsed time"];
        idxHits = find(ismember(normNames, allow));
        if numel(idxHits) > 1
            errTag = 'AMBIGUOUS_TIME_COLUMN';
            return
        elseif numel(idxHits) == 1
            idx = idxHits;
            return
        end
        mask = startsWith(normNames, "time", 'IgnoreCase', true) & ...
            contains(normNames, "stamp", 'IgnoreCase', true);
        idxHits = find(mask);
        if numel(idxHits) > 1
            errTag = 'AMBIGUOUS_TIME_COLUMN';
        elseif numel(idxHits) == 1
            idx = idxHits;
        else
            errTag = 'MISSING_TIME_COLUMN';
        end
    case 'field'
        allow = ["magnetic field (oe)", "magnetic field", "magneticfield_oe"];
        idxHits = find(ismember(normNames, allow));
        if numel(idxHits) > 1
            errTag = 'AMBIGUOUS_FIELD_COLUMN';
        elseif numel(idxHits) == 1
            idx = idxHits;
        else
            mask = contains(normNames, "magnetic", 'IgnoreCase', true) & ...
                (contains(normNames, "oe", 'IgnoreCase', true) | contains(normNames, "field", 'IgnoreCase', true));
            idxHits = find(mask);
            if numel(idxHits) > 1
                errTag = 'AMBIGUOUS_FIELD_COLUMN';
            elseif numel(idxHits) == 1
                idx = idxHits;
            else
                errTag = 'MISSING_FIELD_COLUMN';
            end
        end
    case 'moment'
        allow = ["moment (emu)", "moment_emu", "moment(emu)", "moment ( emu )"];
        idxHits = find(ismember(normNames, allow));
        if numel(idxHits) > 1
            errTag = 'AMBIGUOUS_MOMENT_COLUMN';
        elseif numel(idxHits) == 1
            idx = idxHits;
        else
            mask = startsWith(normNames, "moment", 'IgnoreCase', true) & ...
                contains(normNames, "emu", 'IgnoreCase', true);
            idxHits = find(mask);
            if numel(idxHits) > 1
                errTag = 'AMBIGUOUS_MOMENT_COLUMN';
            elseif numel(idxHits) == 1
                idx = idxHits;
            else
                errTag = 'MISSING_MOMENT_COLUMN';
            end
        end
end
end
