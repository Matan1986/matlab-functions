%% RUN_RELAXATION_POST_FIELD_OFF_RF3R_CANONICAL
% RF3R robust-baseline repair canonical curve creation for Relaxation:
%   DeltaM_RF3R(t - t_field_off; T) = M_post(t) - b_robust
% where b_robust uses ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT.

clear; clc;

cfg = struct();
scriptName = 'run_relaxation_post_field_off_RF3R_canonical.m';
creationContract = 'DELTA_M_POST_FIELD_OFF_ROBUST_BASELINE';
maxPointsPerTrace = 500;
minPostFieldPoints = 3;

% Keep RF3 event detection conventions.
lowFieldThresholdOe = 1.0;
highFieldQuantile = 0.90;
highFieldMinOe = 20.0;
minLowFractionAfter = 0.90;
fieldBeforeAfterWindow = 10;

% RF3R selected rule (overridden by spec_status if present).
selectedBaselineRule = "ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT";
baselineWindowPrimaryS = 30.0;
baselineWindowFallbackS = 60.0;
baselineMinPoints = 7;
baselineFallbackMinPoints = 5; % median first-5 excluding first point
signRule = "RF3R_SIGN_DIAGNOSTIC:DeltaM_RF3R=M_post-M_robust_baseline";
samplePolicyLabel = "UNIFORM_INDEX_MAX500_POST_FIELD_OFF";

% Quality flag defaults (overridden by quality spec table if present).
sigmaFloor = 1e-9;
bFloor = 1e-9;
zThresholdPrimary = 6.0;
zThresholdSignAssist = 4.0;
rShiftThreshold = 2.0;

trace13k = "r2c_2d905a61c8bc6c27";
trace13kFileName = "MG_119_14p31mg_relaxation_13K_afterFC1T.dat";

experiment_name = 'relaxation_post_field_off_RF3R_canonical';
run = createRunContext(experiment_name, struct());
if ~isfield(run, 'dir') || isempty(run.dir)
    run.dir = run.run_dir;
end

execution_status = "FAILED";
failure_summary = "";
run_start_time = datetime('now');
run_end_time = NaT;

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

    %% Pull selected rule from RF3R spec if available
    specStatusPath = fullfile(repoRoot, 'tables', 'relaxation_RF3R_spec_status.csv');
    if exist(specStatusPath, 'file') == 2
        specT = readtable(specStatusPath, "TextType", "string", "Delimiter", ",");
        if ismember('SELECTED_BASELINE_RULE', specT.Properties.VariableNames)
            candidate = strtrim(string(specT.SELECTED_BASELINE_RULE(1)));
            if strlength(candidate) > 0
                selectedBaselineRule = candidate;
            end
        end
    end

    qSpecPath = fullfile(repoRoot, 'tables', 'relaxation_RF3R_quality_flag_rule_spec.csv');
    if exist(qSpecPath, 'file') == 2
        qSpec = readtable(qSpecPath, "TextType", "string", "Delimiter", ",");
        [zThresholdPrimary, sigmaFloor] = local_parseZRule(qSpec, zThresholdPrimary, sigmaFloor);
        [rShiftThreshold, bFloor] = local_parseRShiftRule(qSpec, rShiftThreshold, bFloor);
        zThresholdSignAssist = local_parseSignAssistRule(qSpec, zThresholdSignAssist);
    end

    %% Data source (real Relaxation raw dataset)
    dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM';
    if isempty(dataDir) || exist(dataDir, 'dir') ~= 7
        error('RF3R dataDir must exist: %s', dataDir);
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
        error('No LOADED traces available for RF3R canonical creation.');
    end

    %% Build RF3R outputs
    eventRows = table();
    indexRows = table();
    sampleRows = table();
    qualityRows = table();
    baselineMetaRows = table();
    qualityFlagRows = table();

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
        baselineRuleUsed = selectedBaselineRule;
        baselineWindowUsedS = NaN;
        baselinePointsInWindow = 0;
        baselinePointsUsed = 0;
        baselineValue = NaN;
        baselineFallbackUsed = "NO";
        baselineFallbackReason = "";
        baselineConfidence = "LOW";

        z_fp = NaN;
        r_shift = NaN;
        sign_mismatch = "NO";
        firstPointArtifactFlag = "NO";
        baselineShiftFlag = "NO";
        signMismatchFlag = "NO";
        quality_flag = "NO";
        quality_flag_reason = "";
        valid_for_default_replay = "NO";

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
                    invalid_reason = "FAIL_RF3R_COLUMN_RESOLUTION_" + colErr;
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
                            [bObj, bErr] = local_estimateRobustBaseline( ...
                                t_rel, m_post, baselineWindowPrimaryS, baselineWindowFallbackS, ...
                                baselineMinPoints, baselineFallbackMinPoints, selectedBaselineRule);
                            if strlength(bErr) > 0
                                invalid_reason = "FAIL_BASELINE_" + bErr;
                            else
                                baselineWindowUsedS = bObj.window_s;
                                baselinePointsInWindow = bObj.n_window;
                                baselinePointsUsed = bObj.n_used;
                                baselineValue = bObj.value;
                                baselineFallbackUsed = bObj.fallback_used;
                                baselineFallbackReason = bObj.fallback_reason;
                                baselineConfidence = bObj.confidence;

                                dM = m_post - baselineValue;
                                M_at_field_off_or_baseline = baselineValue;

                                firstPointDev = m_post(1) - baselineValue;
                                earlyMask = (t_rel > 0) & (t_rel <= baselineWindowPrimaryS);
                                earlyResiduals = m_post(earlyMask) - baselineValue;
                                sigma_robust = 1.4826 * local_mad(earlyResiduals);
                                sigma_used = max(sigma_robust, sigmaFloor);
                                z_fp = abs(firstPointDev) / sigma_used;
                                r_shift = abs(m_post(1) - baselineValue) / max(abs(baselineValue), bFloor);

                                s_fp = sign(firstPointDev);
                                s_robust = sign(median(earlyResiduals, 'omitnan'));
                                sign_mismatch = local_boolToYN(s_fp ~= s_robust);

                                firstPointArtifactFlag = local_boolToYN( ...
                                    (z_fp > zThresholdPrimary) || ((s_fp ~= s_robust) && (z_fp > zThresholdSignAssist)));
                                baselineShiftFlag = local_boolToYN(r_shift > rShiftThreshold);
                                signMismatchFlag = local_boolToYN((s_fp ~= s_robust) && (z_fp > zThresholdSignAssist));

                                quality_flag = firstPointArtifactFlag;
                                if quality_flag == "YES"
                                    quality_flag_reason = "FIRST_POST_POINT_ARTIFACT";
                                else
                                    quality_flag_reason = "NONE";
                                end

                                trace_valid_for_relaxation = "YES";
                                valid_for_default_replay = local_boolToYN(quality_flag ~= "YES");
                                invalid_reason = "";
                                canonical_start_time = t_post(1);
                                canonical_start_minus_field_off = canonical_start_time - detected_field_off_time;
                                pre_field_off_points_excluded = preCount;
                                post_field_off_points_retained = postCount;
                                contains_pre_field_off_points = "NO";

                                % Curve samples (preserve all traces, including quality-flagged)
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
                                    repmat(baselineValue, numel(sIdx), 1), ...
                                    repmat(string(selectedBaselineRule), numel(sIdx), 1), ...
                                    repmat(signRule, numel(sIdx), 1), ...
                                    repmat(samplePolicyLabel, numel(sIdx), 1), ...
                                    repmat(quality_flag, numel(sIdx), 1), ...
                                    repmat(valid_for_default_replay, numel(sIdx), 1), ...
                                    'VariableNames', {'run_id', 'trace_id', 'source_file', 'sample_index', ...
                                    'original_index', 'time_since_field_off', 'delta_m', 'moment_post_field_off', ...
                                    'baseline_value', 'baseline_rule', 'sign_rule', 'sample_policy', ...
                                    'quality_flag', 'valid_for_default_replay'});
                                sampleRows = [sampleRows; tmpSamples]; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end

        if trace_valid_for_relaxation == "NO"
            contains_pre_field_off_points = "UNKNOWN";
            valid_for_default_replay = "NO";
            quality_flag = "YES";
            if strlength(strtrim(quality_flag_reason)) == 0
                quality_flag_reason = "INVALID_TRACE_FOR_CANONICAL_RELAXATION";
            end
            if strlength(strtrim(invalid_reason)) == 0
                invalid_reason = "FAIL_UNSPECIFIED_RF3R";
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
            string(selectedBaselineRule), signRule, trace_valid_for_relaxation, invalid_reason, ...
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
            canonical_start_minus_field_off, ...
            quality_flag, valid_for_default_replay, ...
            "tables/relaxation_post_field_off_curve_samples.csv", ...
            'VariableNames', {'run_id', 'trace_id', 'file_name', 'source_file', 'temperature', ...
            'trace_valid_for_relaxation', 'invalid_reason', 'detected_field_off_time', ...
            'post_field_off_points_retained', 'canonical_start_minus_field_off', ...
            'is_quality_flagged', 'valid_for_default_replay', ...
            'curve_sample_file_or_table'});
        indexRows = [indexRows; idxRow]; %#ok<AGROW>

        qRow = table( ...
            string(run.run_id), trace_id, trace_valid_for_relaxation, ...
            quality_flag, quality_flag_reason, z_fp, r_shift, sign_mismatch, ...
            valid_for_default_replay, string(field_off_detection_confidence), string(invalid_reason), ...
            'VariableNames', {'run_id', 'trace_id', 'trace_valid_for_relaxation', ...
            'quality_flag', 'quality_flag_reason', 'z_fp', 'r_shift', 'sign_mismatch', ...
            'valid_for_default_replay', 'field_off_detection_confidence', 'invalid_reason'});
        qualityRows = [qualityRows; qRow]; %#ok<AGROW>

        bRow = table( ...
            string(run.run_id), trace_id, string(selectedBaselineRule), ...
            baselineWindowPrimaryS, baselineWindowUsedS, baselinePointsInWindow, baselinePointsUsed, ...
            baselineValue, baselineFallbackUsed, baselineFallbackReason, baselineConfidence, ...
            'VariableNames', {'run_id', 'trace_id', 'baseline_rule_selected', ...
            't_window_primary_s', 't_window_used_s', 'n_points_window', 'n_points_used', ...
            'baseline_value', 'baseline_fallback_used', 'fallback_reason', 'baseline_confidence_status'});
        baselineMetaRows = [baselineMetaRows; bRow]; %#ok<AGROW>

        qualityFlagRows = [qualityFlagRows; local_flagRow(run.run_id, trace_id, ...
            "FIRST_POST_POINT_ARTIFACT", firstPointArtifactFlag, "FIRST_POINT_ROBUST_Z", z_fp, ...
            sprintf('z_fp > %.6g OR sign_mismatch with z_fp > %.6g', zThresholdPrimary, zThresholdSignAssist), ...
            local_defaultActionFromFlag(firstPointArtifactFlag))]; %#ok<AGROW>
        qualityFlagRows = [qualityFlagRows; local_flagRow(run.run_id, trace_id, ...
            "FIRST_POST_POINT_BASELINE_SHIFT", baselineShiftFlag, "FIRST_POINT_BASELINE_SHIFT_RATIO", r_shift, ...
            sprintf('r_shift > %.6g', rShiftThreshold), "DIAGNOSTIC_ONLY")]; %#ok<AGROW>
        qualityFlagRows = [qualityFlagRows; local_flagRow(run.run_id, trace_id, ...
            "FIRST_POST_POINT_SIGN_MISMATCH", signMismatchFlag, "FIRST_POINT_SIGN_CONSISTENCY", ...
            local_boolToDouble(signMismatchFlag == "YES"), ...
            sprintf('sign_mismatch AND z_fp > %.6g', zThresholdSignAssist), "DIAGNOSTIC_ONLY")]; %#ok<AGROW>
    end

    % Write RF3R tables
    writetable(eventRows, fullfile(tablesDir, 'relaxation_event_origin_manifest.csv'));
    writetable(indexRows, fullfile(tablesDir, 'relaxation_post_field_off_curve_index.csv'));
    writetable(sampleRows, fullfile(tablesDir, 'relaxation_post_field_off_curve_samples.csv'));
    writetable(qualityRows, fullfile(tablesDir, 'relaxation_post_field_off_curve_quality.csv'));
    writetable(baselineMetaRows, fullfile(tablesDir, 'relaxation_RF3R_baseline_metadata.csv'));
    writetable(qualityFlagRows, fullfile(tablesDir, 'relaxation_RF3R_quality_flags.csv'));

    % RF3R status derivation
    validMask = string(eventRows.trace_valid_for_relaxation) == "YES";
    num_valid_creation_curves = sum(validMask);
    num_invalid_for_relaxation = sum(~validMask);
    loadedMask = loaderStatus == "LOADED";
    loadedN = sum(loadedMask);
    detectedN = sum(isfinite(eventRows.detected_field_off_index) & loadedMask);
    canonEqN = sum(abs(eventRows.canonical_start_minus_field_off(validMask)) <= 1e-9);
    baselineAppliedN = sum(isfinite(baselineMetaRows.baseline_value(validMask)));
    preIncluded = any(string(eventRows.contains_pre_field_off_points(validMask)) == "YES");

    fieldDetectedStatus = local_ratioToTri(detectedN, loadedN);
    postOnlyStatus = "YES";
    timeResetStatus = local_ratioToTri(canonEqN, max(num_valid_creation_curves, 1));
    robustBaselineStatus = local_ratioToTri(baselineAppliedN, max(num_valid_creation_curves, 1));
    firstPointRuleStatus = local_boolToYN(height(qualityRows) == height(eventRows));
    flaggedMask = string(qualityRows.quality_flag) == "YES";
    flaggedExcludedStatus = local_boolToYN(all(string(qualityRows.valid_for_default_replay(flaggedMask)) == "NO"));
    if ~any(flaggedMask)
        flaggedExcludedStatus = "PARTIAL";
    end

    sourceNames = strings(height(eventRows), 1);
    for j = 1:height(eventRows)
        [~, nm, ext] = fileparts(char(eventRows.source_file(j)));
        sourceNames(j) = string(nm) + string(ext);
    end
    idx13 = find(string(eventRows.trace_id) == trace13k, 1);
    if isempty(idx13)
        idx13 = find(sourceNames == trace13kFileName, 1);
    end
    if isempty(idx13)
        idx13 = find(abs(eventRows.temperature - 13.0000102519989) < 0.2, 1);
    end
    trace13kFlagged = "PARTIAL";
    trace13kValidDefault = "PARTIAL";
    if ~isempty(idx13)
        q13 = qualityRows(idx13, :);
        if string(q13.quality_flag) == "YES"
            trace13kFlagged = "YES";
        else
            trace13kFlagged = "NO";
        end
        trace13kValidDefault = string(q13.valid_for_default_replay);
    end

    runScopedStatus = local_boolToYN(local_outputsExist(runDir, false));
    rf3rComplete = local_boolToYN(num_valid_creation_curves > 0 && ~preIncluded && robustBaselineStatus ~= "NO");
    readyAudit = local_boolToYN(rf3rComplete == "YES");

    creationStatus = table( ...
        rf3rComplete, "DELTA_M_POST_FIELD_OFF_ROBUST_BASELINE", fieldDetectedStatus, ...
        postOnlyStatus, timeResetStatus, "NO", robustBaselineStatus, firstPointRuleStatus, ...
        trace13kFlagged, "YES", trace13kValidDefault, flaggedExcludedStatus, ...
        "NO", "NO", runScopedStatus, readyAudit, "NO", "NO", "NO", ...
        'VariableNames', {'RF3R_ROBUST_BASELINE_REPAIR_COMPLETE', 'PHYSICAL_OBJECT', ...
        'FIELD_OFF_DETECTED_ALL_TRACES', 'CANONICAL_CURVES_ARE_POST_FIELD_OFF', ...
        'CANONICAL_TIME_RESET_AT_FIELD_OFF', 'PRE_FIELD_POINTS_INCLUDED', ...
        'ROBUST_BASELINE_RULE_APPLIED', 'FIRST_POINT_ARTIFACT_RULE_APPLIED', ...
        'TRACE_13K_FLAGGED_FIRST_POINT_ARTIFACT', 'TRACE_13K_INCLUDED_IN_CANONICAL_RECORDS', ...
        'TRACE_13K_VALID_FOR_DEFAULT_REPLAY', ...
        'QUALITY_FLAGGED_TRACES_EXCLUDED_FROM_DEFAULT_REPLAY', ...
        'OLD_FULL_TRACE_RUN_REUSED', 'OLD_PRECOMPUTED_ARTIFACTS_USED', ...
        'OUTPUTS_RUN_SCOPED', 'READY_FOR_RF3R_AUDIT', ...
        'READY_FOR_RF5_REPLAY_RERUN', 'READY_FOR_COLLAPSE_REPLAY', ...
        'READY_FOR_CROSS_MODULE_ANALYSIS'});
    writetable(creationStatus, fullfile(tablesDir, 'relaxation_post_field_off_creation_status.csv'));

    %% Report
    reportPath = fullfile(reportsDir, 'relaxation_post_field_off_RF3R_canonical_report.md');
    lines = {
        '# Relaxation RF3R Robust-Baseline Post-Field-Off Canonical Run'
        ''
        sprintf('- Run ID: `%s`', run.run_id)
        sprintf('- Run directory: `%s`', runDir)
        sprintf('- Data source: `%s`', dataDir)
        sprintf('- Baseline rule: `%s`', selectedBaselineRule)
        sprintf('- Quality primary metric: `z_fp` with threshold %.3f (sigma_floor %.3e emu)', zThresholdPrimary, sigmaFloor)
        ''
        '## Scope statement'
        '- RF3R runner only: event-origin-preserving post-field-off canonical creation with robust baseline repair.'
        '- No RF4B/RF5A rerun performed here.'
        '- No RF5B/effective-rank, SVD, collapse, time-mode, or cross-module analysis performed.'
        '- No silent trace exclusion: quality-flagged traces (including 13K when flagged) remain in canonical records.'
        ''
        '## Trace summary'
        sprintf('- Input files discovered: %d', num_input_files)
        sprintf('- Loader LOADED traces: %d', num_loaded_traces)
        sprintf('- Valid canonical traces created: %d', num_valid_creation_curves)
        sprintf('- Invalid traces: %d', num_invalid_for_relaxation)
        sprintf('- Quality-flagged traces: %d', sum(string(qualityRows.quality_flag) == "YES"))
        sprintf('- Default-replay valid traces: %d', sum(string(qualityRows.valid_for_default_replay) == "YES"))
        ''
        '## Required outputs written'
        '- `execution_status.csv`'
        '- `tables/relaxation_event_origin_manifest.csv`'
        '- `tables/relaxation_post_field_off_curve_index.csv`'
        '- `tables/relaxation_post_field_off_curve_samples.csv`'
        '- `tables/relaxation_post_field_off_curve_quality.csv`'
        '- `tables/relaxation_post_field_off_creation_status.csv`'
        '- `tables/relaxation_RF3R_baseline_metadata.csv`'
        '- `tables/relaxation_RF3R_quality_flags.csv`'
        '- `reports/relaxation_post_field_off_RF3R_canonical_report.md`'
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
    run_end_time = datetime('now');

catch ME
    execution_status = "FAILED";
    failure_summary = string(ME.message);
    run_end_time = datetime('now');
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
    string(run_start_time), string(run_end_time), string(failure_summary), ...
    num_input_files, num_loaded_traces, num_invalid_for_relaxation, num_valid_creation_curves, ...
    'VariableNames', {'status', 'run_id', 'script', 'creation_contract', ...
    'start_time', 'end_time', 'error_message', 'num_input_files', 'num_loaded_traces', ...
    'num_invalid_for_relaxation', 'num_valid_creation_curves'});
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

function d = local_boolToDouble(tf)
if tf
    d = 1.0;
else
    d = 0.0;
end
end

function row = local_flagRow(run_id, trace_id, flag_name, flag_value, metric_name, metric_value, threshold_txt, action_txt)
row = table( ...
    string(run_id), string(trace_id), string(flag_name), string(flag_value), ...
    string(metric_name), metric_value, string(threshold_txt), string(action_txt), ...
    'VariableNames', {'run_id', 'trace_id', 'flag_name', 'flag_value', ...
    'flag_metric_name', 'flag_metric_value', 'threshold', 'action_default_replay'});
end

function action = local_defaultActionFromFlag(flagValue)
if string(flagValue) == "YES"
    action = "EXCLUDE_FROM_DEFAULT_REPLAY";
else
    action = "INCLUDE_IN_DEFAULT_REPLAY";
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
    exist(fullfile(runDir, 'tables', 'relaxation_RF3R_baseline_metadata.csv'), 'file') == 2 && ...
    exist(fullfile(runDir, 'tables', 'relaxation_RF3R_quality_flags.csv'), 'file') == 2 && ...
    exist(fullfile(runDir, 'reports', 'relaxation_post_field_off_RF3R_canonical_report.md'), 'file') == 2;

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

function [bObj, errTag] = local_estimateRobustBaseline(t_rel, m_post, tWinPrimary, tWinFallback, minPts, fallbackPts, ruleName)
bObj = struct();
bObj.rule = string(ruleName);
bObj.window_s = NaN;
bObj.n_window = 0;
bObj.n_used = 0;
bObj.value = NaN;
bObj.fallback_used = "NO";
bObj.fallback_reason = "";
bObj.confidence = "LOW";
errTag = "";

if string(ruleName) ~= "ROBUST_EARLY_WINDOW_MEDIAN_EXCLUDING_FIRST_POINT"
    errTag = "UNSUPPORTED_BASELINE_RULE";
    return;
end

if numel(m_post) < 2
    errTag = "INSUFFICIENT_POINTS_EXCLUDING_FIRST";
    return;
end

maskPrimary = (t_rel > 0) & (t_rel <= tWinPrimary);
valsPrimary = m_post(maskPrimary);
valsPrimary = valsPrimary(isfinite(valsPrimary));
bObj.n_window = numel(valsPrimary);

if numel(valsPrimary) >= minPts
    bObj.window_s = tWinPrimary;
    bObj.n_used = numel(valsPrimary);
    bObj.value = median(valsPrimary, 'omitnan');
    bObj.confidence = "HIGH";
    return;
end

maskFallbackWin = (t_rel > 0) & (t_rel <= tWinFallback);
valsFallbackWin = m_post(maskFallbackWin);
valsFallbackWin = valsFallbackWin(isfinite(valsFallbackWin));
if numel(valsFallbackWin) >= minPts
    bObj.window_s = tWinFallback;
    bObj.n_window = numel(valsFallbackWin);
    bObj.n_used = numel(valsFallbackWin);
    bObj.value = median(valsFallbackWin, 'omitnan');
    bObj.fallback_used = "YES";
    bObj.fallback_reason = "EXPAND_TO_60S_WINDOW";
    bObj.confidence = "MEDIUM";
    return;
end

valsFirst5ExFirst = m_post(2:min(numel(m_post), 6));
valsFirst5ExFirst = valsFirst5ExFirst(isfinite(valsFirst5ExFirst));
if numel(valsFirst5ExFirst) >= fallbackPts
    bObj.window_s = NaN;
    bObj.n_window = numel(valsFirst5ExFirst);
    bObj.n_used = numel(valsFirst5ExFirst);
    bObj.value = median(valsFirst5ExFirst, 'omitnan');
    bObj.fallback_used = "YES";
    bObj.fallback_reason = "MEDIAN_FIRST5_EXCLUDING_FIRST_POINT";
    bObj.confidence = "MEDIUM";
    return;
end

errTag = "INSUFFICIENT_POINTS_FOR_ROBUST_BASELINE";
end

function m = local_mad(x)
x = x(isfinite(x));
if isempty(x)
    m = NaN;
    return;
end
medx = median(x, 'omitnan');
m = median(abs(x - medx), 'omitnan');
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

function [zThresh, sigFloor] = local_parseZRule(qSpec, zDefault, sDefault)
zThresh = zDefault;
sigFloor = sDefault;
if ~all(ismember(["metric_name","robust_threshold"], qSpec.Properties.VariableNames))
    return;
end
mask = string(qSpec.metric_name) == "FIRST_POINT_ROBUST_Z";
if ~any(mask)
    return;
end
txt = string(qSpec.robust_threshold(find(mask,1)));
zVal = local_extractNumberAfter(txt, "z_fp >", zDefault);
sVal = local_extractNumberAfter(txt, "sigma_floor=", sDefault);
zThresh = zVal;
sigFloor = sVal;
end

function [rThresh, bFloor] = local_parseRShiftRule(qSpec, rDefault, bDefault)
rThresh = rDefault;
bFloor = bDefault;
if ~all(ismember(["metric_name","robust_threshold"], qSpec.Properties.VariableNames))
    return;
end
mask = string(qSpec.metric_name) == "FIRST_POINT_BASELINE_SHIFT_RATIO";
if ~any(mask)
    return;
end
txt = string(qSpec.robust_threshold(find(mask,1)));
rVal = local_extractNumberAfter(txt, "r_shift >", rDefault);
bVal = local_extractNumberAfter(txt, "b_floor=", bDefault);
rThresh = rVal;
bFloor = bVal;
end

function signAssist = local_parseSignAssistRule(qSpec, defaultVal)
signAssist = defaultVal;
if ~all(ismember(["metric_name","robust_threshold"], qSpec.Properties.VariableNames))
    return;
end
mask = string(qSpec.metric_name) == "FIRST_POINT_SIGN_CONSISTENCY";
if ~any(mask)
    return;
end
txt = string(qSpec.robust_threshold(find(mask,1)));
signAssist = local_extractNumberAfter(txt, "z_fp >", defaultVal);
end

function v = local_extractNumberAfter(txt, token, fallback)
v = fallback;
txt = string(txt);
token = string(token);
idx = strfind(lower(char(txt)), lower(char(token)));
if isempty(idx)
    return;
end
sub = extractAfter(txt, idx(1) + strlength(token) - 1);
num = regexp(char(sub), '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match', 'once');
if isempty(num)
    return;
end
n = str2double(num);
if isfinite(n)
    v = n;
end
end
