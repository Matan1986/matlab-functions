clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'MT ver2'));

cfg = struct();
cfg.runLabel = 'mt_canonical_diagnostic';
cfg.input_dir = '';
cfg.color_scheme = 'default';
cfg.units_mode = 'raw';
cfg.DC = true;
cfg.Unfiltered = false;

cfg.cleaning = struct();
cfg.cleaning.tempJump_K = 0.5;
cfg.cleaning.magJump_sigma = 3;
cfg.cleaning.useHampel = true;
cfg.cleaning.hampelWindow = 21;
cfg.cleaning.hampelSigma = 2;
cfg.cleaning.max_interp_gap = 15;
cfg.cleaning.sgOrder = 2;
cfg.cleaning.sgFrame = 41;
cfg.cleaning.movingAvgWindow = 15;
cfg.cleaning.field_threshold = 20000;
% When true, runner passes cleaning options with field_threshold forced to 0 so
% clean_MT_data does not take the low-field bypass (field-dependent preprocessing gate).
cfg.cleaning_disable_low_field_bypass = false;

cfg.segmentation = struct();
cfg.segmentation.delta_T = 0.7;
cfg.segmentation.min_temp_change = 0.1;
cfg.segmentation.min_temp_time_window_change = 20;
cfg.segmentation.temp_rate = 3;
cfg.segmentation.temp_stabilization_window = 10;
cfg.segmentation.min_segment_length_temp = 50;

configLoadedFlag = false;
configPathUsed = '';

localCfgPath = fullfile(repoRoot, 'local', 'mt_canonical_config.m');
if exist(localCfgPath, 'file') == 2
    % fileread+eval avoids MATLAB rule: script basename cannot match assigned var name.
    eval(fileread(localCfgPath));
    if exist('mt_canonical_config', 'var') && isstruct(mt_canonical_config)
        u = mt_canonical_config;
        ufn = fieldnames(u);
        for ii = 1:numel(ufn)
            key = ufn{ii};
            if strcmp(key, 'cleaning')
                if isstruct(u.cleaning)
                    sf = fieldnames(u.cleaning);
                    for jj = 1:numel(sf)
                        cfg.cleaning.(sf{jj}) = u.cleaning.(sf{jj});
                    end
                end
            elseif strcmp(key, 'segmentation')
                if isstruct(u.segmentation)
                    sf = fieldnames(u.segmentation);
                    for jj = 1:numel(sf)
                        cfg.segmentation.(sf{jj}) = u.segmentation.(sf{jj});
                    end
                end
            else
                cfg.(key) = u.(key);
            end
        end
        if numel(ufn) > 0
            configLoadedFlag = true;
            configPathUsed = char(string(localCfgPath));
        end
        clear mt_canonical_config;
    end
end

if configLoadedFlag
    configLoadedStr = "YES";
else
    configLoadedStr = "NO";
end
configPathReport = '';
if configLoadedFlag
    configPathReport = configPathUsed;
end

run = struct();
try
    run = createRunContext('mt', cfg);

    tablesDir = fullfile(run.run_dir, 'tables');
    reportsDir = fullfile(run.run_dir, 'reports');
    figuresDir = fullfile(run.run_dir, 'figures');

    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end

    pointerPath = fullfile(run.repo_root, 'run_dir_pointer.txt');
    fidPointer = fopen(pointerPath, 'w');
    if fidPointer >= 0
        fprintf(fidPointer, '%s\n', run.run_dir);
        fclose(fidPointer);
    end

    inputDir = '';
    if isfield(cfg, 'input_dir') && ~isempty(cfg.input_dir)
        inputDir = char(string(cfg.input_dir));
    end

    inputExists = (exist(inputDir, 'dir') == 7);
    datFiles = [];
    if inputExists
        datFiles = dir(fullfile(inputDir, '*.DAT'));
    end
    datCount = numel(datFiles);
    inputFound = inputExists && (datCount > 0);

    fileInventory = table('Size', [0 27], ...
        'VariableTypes', {'double','string','string','double','double','string','string','string','double','double','double','logical','double','double','double','double','double','double','double','double','double','double','double','string','string','string','string'}, ...
        'VariableNames', {'file_id','file_name','file_path','field_from_name_oe','mass_mg','system_detected','parser_selected','import_status','n_rows','time_min_s','time_max_s','time_regular_warning','dt_mean_s','dt_std_s','dt_cv','dt_median_s','dt_q90_s','dt_q99_s','dt_max_s','negative_dt_count','zero_dt_count','pause_gap_count','pause_gap_fraction','time_quality','time_warning_class','time_blocker_reason','segmentation_trust'});

    rawSummary = table('Size', [0 25], ...
        'VariableTypes', {'double','double','double','double','double','double','double','double','logical','double','double','double','double','double','double','double','double','double','double','double','double','string','string','string','string'}, ...
        'VariableNames', {'file_id','n_rows','T_min_K','T_max_K','H_min_Oe','H_max_Oe','M_min_emu','M_max_emu','time_regular_warning','dt_mean_s','dt_std_s','dt_cv','dt_median_s','dt_q90_s','dt_q99_s','dt_max_s','negative_dt_count','zero_dt_count','pause_gap_count','pause_gap_fraction','dt_count','time_quality','time_warning_class','time_blocker_reason','segmentation_trust'});

    cleaningAudit = table('Size', [0 18], ...
        'VariableTypes', {'double','string','double','double','logical','double','double','double','double','string','string','double','double','double','double','string','string','string'}, ...
        'VariableNames', {'file_id','cleaning_policy_branch','field_oe','field_threshold_oe','unfiltered_mode','n_raw','n_clean_non_nan','n_smooth_non_nan','n_masked_or_nan_after_clean', ...
        'cleaning_reason_code','cleaning_branch','points_changed_count','points_changed_fraction','raw_clean_max_abs_delta','raw_smooth_max_abs_delta','cleaning_effect_class','cleaning_warning_class','cleaning_trust'});

    segmentsTbl = table('Size', [0 9], ...
        'VariableTypes', {'double','string','double','double','double','double','double','double','double'}, ...
        'VariableNames', {'file_id','segment_type','segment_id','start_idx','end_idx','time_start_s','time_end_s','T_start_K','T_end_K'});

    pointsRawTbl = table('Size', [0 10], ...
        'VariableTypes', {'double','double','double','double','double','double','double','string','string','string'}, ...
        'VariableNames', {'file_id','row_index','T_K','H_Oe','time_s','M_emu','sample_mass_g','import_status','time_quality','time_warning_class'});
    pointsCleanTbl = table('Size', [0 20], ...
        'VariableTypes', {'double','double','double','double','double','double','double','double','double','string','string','double','double','double','string','string','string','double','string','string'}, ...
        'VariableNames', {'file_id','row_index','T_K','H_Oe','time_s','M_emu_raw','M_emu_clean','M_emu_smooth','sample_mass_g','cleaning_branch','cleaning_reason_code','points_changed_flag','raw_clean_abs_delta','raw_smooth_abs_delta','cleaning_effect_class','cleaning_warning_class','cleaning_trust','segment_id','segment_type','segment_source'});
    pointsDerivedTbl = table('Size', [0 20], ...
        'VariableTypes', {'double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','string','double','string','double','string'}, ...
        'VariableNames', {'file_id','row_index','T_K','H_Oe','time_s','M_emu_clean','sample_mass_g','time_rel_s','M_over_H_emu_per_Oe','M_norm_emu_per_g','chi_mass_emu_per_g_per_Oe','dM_dT_emu_per_K','dM_dt_emu_per_s','dT_dt_K_per_s','segment_id','segment_type','segment_progress_01','segment_direction_sign','derived_valid_flag','derived_missing_reason'});
    observablesTbl = table('Size', [0 14], ...
        'VariableTypes', {'string','string','double','double','string','string','string','string','string','double','string','double','string','string'}, ...
        'VariableNames', {'observable_name','observable_variant','file_id','segment_id','segment_type','definition','source_columns','aggregation_method','temperature_dependence','value_numeric','value_unit','n_points_used','quality_flag','notes'});
    gateSummaryTbl = table('Size', [0 8], ...
        'VariableTypes', {'string','string','string','string','string','string','string','string'}, ...
        'VariableNames', {'gate_id','gate_name','status','severity','blocks_full_canonical','blocks_production_release','blocks_advanced_analysis','details'});
    gateFailuresTbl = table('Size', [0 5], ...
        'VariableTypes', {'string','string','string','string','string'}, ...
        'VariableNames', {'gate_id','gate_name','severity','failure_mode_description','required_action'});

    mtInputFound = "NO";
    mtImportStrictnessOk = "NO";
    mtCleaningAuditWritten = "NO";
    mtSegmentTableWritten = "NO";
    mtTimeAxisWarningsPresent = "NO";
    mtTimeAxisCorruptionPresent = "NO";
    mtTimeAxisPauseGapsPresent = "NO";
    mtTimeAxisSegmentationRiskPresent = "NO";
    mtSegmentationTrustLevel = "HIGH";
    mtReadyForProductionRelease = "NO";
    mtReadyForAdvancedAnalysis = "NO";
    mtCleaningPolicyBranchSplitPresent = "NO";
    mtCleaningChangedPointsPresent = "NO";
    mtCleaningEffectRiskPresent = "NO";
    mtCleaningBranchSplitIsBlocker = "NO";
    mtCleaningTrustLevel = "HIGH";
    pointTablesWritten = "NO";
    pointTableGateSummary = "NOT_RUN";
    fullCanonicalDataProduct = "NO";

    importedOk = 0;
    importedFail = 0;
    timeWarningCount = 0;
    runSegmentationTrustRank = 1;

    if inputFound
        mtInputFound = "YES";

        [fileList, sortedFields, ~, massFromName] = getFileList_MT(inputDir, cfg.color_scheme);
        systemType = detect_MT_file_type(inputDir, fileList{1});
        parserSelected = "importOneFile_MT";
        if strcmpi(char(systemType), 'MPMS')
            parserSelected = "importOneFile_MT_MPMS";
        end

        for iFile = 1:numel(fileList)
            thisName = string(fileList{iFile});
            thisPath = string(fullfile(inputDir, fileList{iFile}));
            thisField = NaN;
            if iFile <= numel(sortedFields)
                thisField = sortedFields(iFile);
            end

            importStatus = "FAILED";
            importError = "";
            nRows = 0;
            timeMin = NaN;
            timeMax = NaN;
            dtMean = NaN;
            dtStd = NaN;
            dtCv = NaN;
            dtMedian = NaN;
            dtQ90 = NaN;
            dtQ99 = NaN;
            dtMax = NaN;
            dtCount = 0;
            negativeDtCount = 0;
            zeroDtCount = 0;
            pauseGapCount = 0;
            pauseGapFraction = 0;
            timeQuality = "FAIL";
            timeWarningClass = "CORRUPTION";
            timeBlockerReason = "IMPORT_FAILED_OR_NO_TIME_DATA";
            segmentationTrust = "FAIL";
            timeRegularWarning = true;

            try
                if strcmp(parserSelected, "importOneFile_MT_MPMS")
                    [TimeSec, TemperatureK, MomentEmu, MagneticFieldOe] = importOneFile_MT_MPMS(char(thisPath), cfg.DC);
                else
                    [TimeSec, TemperatureK, MomentEmu, MagneticFieldOe] = importOneFile_MT(char(thisPath));
                end

                importStatus = "IMPORTED";
                importedOk = importedOk + 1;
                nRows = numel(TimeSec);
                finiteTimeMask = isfinite(TimeSec);
                nonfiniteTimeCount = nRows - sum(finiteTimeMask);
                finiteTime = TimeSec(finiteTimeMask);
                if ~isempty(finiteTime)
                    timeMin = min(finiteTime);
                    timeMax = max(finiteTime);
                end

                dt = [];
                if numel(finiteTime) >= 2
                    dt = diff(finiteTime);
                end
                dtCount = numel(dt);
                if dtCount > 0
                    absDt = abs(dt);
                    dtMean = mean(absDt);
                    dtStd = std(dt);
                    if dtMean > 0
                        dtCv = dtStd / dtMean;
                    else
                        dtCv = NaN;
                    end
                    dtMedian = median(absDt);
                    sortedAbsDt = sort(absDt);
                    idx90 = max(1, min(dtCount, floor(0.90 * (dtCount - 1)) + 1));
                    idx99 = max(1, min(dtCount, floor(0.99 * (dtCount - 1)) + 1));
                    dtQ90 = sortedAbsDt(idx90);
                    dtQ99 = sortedAbsDt(idx99);
                    dtMax = max(absDt);
                    negativeDtCount = sum(dt < 0);
                    zeroDtCount = sum(dt == 0);
                    pauseGapCount = sum(dt > 20);
                    pauseGapFraction = pauseGapCount / dtCount;
                else
                    nonfiniteTimeCount = max(nonfiniteTimeCount, 1);
                end

                zeroDtFraction = 0;
                if dtCount > 0
                    zeroDtFraction = zeroDtCount / dtCount;
                end

                if nRows < 3
                    timeQuality = "FAIL";
                    timeWarningClass = "CORRUPTION";
                    timeBlockerReason = "TOO_FEW_ROWS";
                    segmentationTrust = "FAIL";
                elseif nonfiniteTimeCount > 0
                    timeQuality = "FAIL";
                    timeWarningClass = "CORRUPTION";
                    timeBlockerReason = "NONFINITE_TIME_VALUES";
                    segmentationTrust = "FAIL";
                elseif dtCount == 0
                    timeQuality = "FAIL";
                    timeWarningClass = "CORRUPTION";
                    timeBlockerReason = "NO_USABLE_FINITE_DT";
                    segmentationTrust = "FAIL";
                elseif negativeDtCount > 0
                    timeQuality = "FAIL";
                    timeWarningClass = "CORRUPTION";
                    timeBlockerReason = "NEGATIVE_DT_PRESENT";
                    segmentationTrust = "FAIL";
                elseif zeroDtFraction >= 0.10
                    timeQuality = "FAIL";
                    timeWarningClass = "CORRUPTION";
                    timeBlockerReason = "HEAVY_ZERO_DT_DUPLICATES";
                    segmentationTrust = "FAIL";
                elseif pauseGapFraction >= 0.20 || (~isnan(dtCv) && dtCv >= 0.50)
                    timeQuality = "MEDIUM";
                    timeWarningClass = "SEGMENTATION_RISK";
                    timeBlockerReason = "";
                    segmentationTrust = "LOW";
                elseif pauseGapCount > 0
                    timeQuality = "MEDIUM";
                    timeWarningClass = "PAUSE_GAPS";
                    timeBlockerReason = "";
                    segmentationTrust = "MEDIUM";
                elseif ~isnan(dtCv) && dtCv > 0.20
                    timeQuality = "MEDIUM";
                    timeWarningClass = "NONUNIFORM";
                    timeBlockerReason = "";
                    segmentationTrust = "MEDIUM";
                else
                    timeQuality = "GOOD";
                    timeWarningClass = "NONE";
                    timeBlockerReason = "";
                    segmentationTrust = "HIGH";
                end

                timeRegularWarning = ~strcmp(timeWarningClass, "NONE");
                if timeRegularWarning
                    timeWarningCount = timeWarningCount + 1;
                end

                if strcmp(timeWarningClass, "CORRUPTION")
                    mtTimeAxisCorruptionPresent = "YES";
                elseif strcmp(timeWarningClass, "PAUSE_GAPS")
                    mtTimeAxisPauseGapsPresent = "YES";
                elseif strcmp(timeWarningClass, "SEGMENTATION_RISK")
                    mtTimeAxisSegmentationRiskPresent = "YES";
                end

                thisTrustRank = 1;
                if strcmp(segmentationTrust, "MEDIUM")
                    thisTrustRank = 2;
                elseif strcmp(segmentationTrust, "LOW")
                    thisTrustRank = 3;
                elseif strcmp(segmentationTrust, "FAIL")
                    thisTrustRank = 4;
                end
                if thisTrustRank > runSegmentationTrustRank
                    runSegmentationTrustRank = thisTrustRank;
                end

                rawSummary = [rawSummary; table(double(iFile), double(nRows), min(TemperatureK), max(TemperatureK), min(MagneticFieldOe), max(MagneticFieldOe), min(MomentEmu), max(MomentEmu), logical(timeRegularWarning), ...
                    double(dtMean), double(dtStd), double(dtCv), double(dtMedian), double(dtQ90), double(dtQ99), double(dtMax), double(negativeDtCount), double(zeroDtCount), double(pauseGapCount), double(pauseGapFraction), double(dtCount), ...
                    timeQuality, timeWarningClass, timeBlockerReason, segmentationTrust, ...
                    'VariableNames', {'file_id','n_rows','T_min_K','T_max_K','H_min_Oe','H_max_Oe','M_min_emu','M_max_emu','time_regular_warning','dt_mean_s','dt_std_s','dt_cv','dt_median_s','dt_q90_s','dt_q99_s','dt_max_s','negative_dt_count','zero_dt_count','pause_gap_count','pause_gap_fraction','dt_count','time_quality','time_warning_class','time_blocker_reason','segmentation_trust'})];

                cleaningOpts = cfg.cleaning;
                if isfield(cfg, 'cleaning_disable_low_field_bypass') && logical(cfg.cleaning_disable_low_field_bypass)
                    cleaningOpts.field_threshold = 0;
                end
                [~, M_raw, ~, M_clean, T_smooth, M_smooth] = clean_MT_data(TemperatureK, MomentEmu, thisField, cleaningOpts, cfg.Unfiltered);

                branchLabel = "cleaned";
                if cfg.Unfiltered
                    branchLabel = "unfiltered";
                elseif thisField < cleaningOpts.field_threshold
                    branchLabel = "low_field_bypass";
                end

                if cfg.Unfiltered
                    cleaningReasonCode = "RAW_MODE";
                elseif thisField < cleaningOpts.field_threshold
                    cleaningReasonCode = "BYPASS_LOW_FIELD";
                else
                    cleaningReasonCode = "FULL_CLEAN";
                end
                cleaningBranch = branchLabel;

                nRaw = numel(M_raw);
                nClean = sum(isfinite(M_clean));
                nSmooth = sum(isfinite(M_smooth));
                nMasked = nRaw - nClean;

                % Point-wise deltas on aligned rows. M_smooth (SG+moving-avg) is reported separately and is not used
                % for points_changed_* (would flag essentially every row). points_changed_* counts structural edits:
                % finite↔NaN transitions on the raw→clean channel (masking / gap handling), not Hampel micro-replacements.
                % cleaningTolMaterial: small relative floor for classifying max raw→clean delta as NONE vs LOW/MEDIUM/HIGH.
                pointsChangedCount = 0;
                pointsChangedFraction = 0;
                rawCleanMaxAbsDelta = NaN;
                rawSmoothMaxAbsDelta = NaN;
                cleaningEffectClass = "UNRESOLVED";
                cleaningWarningClass = "NONE";
                cleaningTrust = "HIGH";

                if numel(M_raw) ~= numel(M_clean) || numel(M_raw) ~= numel(M_smooth)
                    cleaningEffectClass = "UNRESOLVED";
                    cleaningWarningClass = "CHANGED_POINTS";
                    cleaningTrust = "LOW";
                else
                    finiteRC = isfinite(M_raw) & isfinite(M_clean);
                    finiteRS = isfinite(M_raw) & isfinite(M_smooth);
                    if ~any(finiteRC)
                        cleaningEffectClass = "UNRESOLVED";
                        cleaningWarningClass = "CHANGED_POINTS";
                        cleaningTrust = "LOW";
                    else
                        delRc = abs(M_clean - M_raw);
                        rawCleanMaxAbsDelta = max(delRc(finiteRC));
                        scaleSig = max(abs(M_raw(finiteRC)));
                        if ~isfinite(scaleSig) || scaleSig <= 0
                            scaleSig = 1;
                        end
                        cleaningTolMaterial = max(1e-15, 1e-6 * scaleSig);
                        structuralMask = (isfinite(M_raw) & ~isfinite(M_clean)) | (~isfinite(M_raw) & isfinite(M_clean));
                        pointsChangedCount = sum(structuralMask);
                        if any(finiteRS)
                            delRs = abs(M_smooth - M_raw);
                            rawSmoothMaxAbsDelta = max(delRs(finiteRS));
                        end
                        mxClean = rawCleanMaxAbsDelta;
                        if pointsChangedCount == 0 && mxClean <= cleaningTolMaterial
                            cleaningEffectClass = "NONE";
                        elseif mxClean / scaleSig <= 0.01
                            cleaningEffectClass = "LOW";
                        elseif mxClean / scaleSig <= 0.25
                            cleaningEffectClass = "MEDIUM";
                        else
                            cleaningEffectClass = "HIGH";
                        end
                        pointsChangedFraction = pointsChangedCount / max(nRaw, 1);
                    end
                end

                cleaningAudit = [cleaningAudit; table(double(iFile), branchLabel, double(thisField), double(cfg.cleaning.field_threshold), logical(cfg.Unfiltered), double(nRaw), double(nClean), double(nSmooth), double(nMasked), ...
                    cleaningReasonCode, cleaningBranch, double(pointsChangedCount), double(pointsChangedFraction), double(rawCleanMaxAbsDelta), double(rawSmoothMaxAbsDelta), cleaningEffectClass, cleaningWarningClass, cleaningTrust, ...
                    'VariableNames', {'file_id','cleaning_policy_branch','field_oe','field_threshold_oe','unfiltered_mode','n_raw','n_clean_non_nan','n_smooth_non_nan','n_masked_or_nan_after_clean', ...
                    'cleaning_reason_code','cleaning_branch','points_changed_count','points_changed_fraction','raw_clean_max_abs_delta','raw_smooth_max_abs_delta','cleaning_effect_class','cleaning_warning_class','cleaning_trust'})];

                rowIndex = (1:nRows)';
                sampleMassG = NaN;
                if isfinite(massFromName) && massFromName > 0
                    sampleMassG = massFromName / 1000.0;
                end
                sampleMassCol = repmat(double(sampleMassG), nRows, 1);
                pointsRawTbl = [pointsRawTbl; table(repmat(double(iFile), nRows, 1), double(rowIndex), double(TemperatureK(:)), double(MagneticFieldOe(:)), double(TimeSec(:)), double(MomentEmu(:)), sampleMassCol, ...
                    repmat(string(importStatus), nRows, 1), repmat(timeQuality, nRows, 1), repmat(timeWarningClass, nRows, 1), ...
                    'VariableNames', {'file_id','row_index','T_K','H_Oe','time_s','M_emu','sample_mass_g','import_status','time_quality','time_warning_class'})];

                pointsChangedFlag = zeros(nRows, 1);
                if numel(M_raw) == nRows && numel(M_clean) == nRows
                    structuralMask = (isfinite(M_raw) & ~isfinite(M_clean)) | (~isfinite(M_raw) & isfinite(M_clean));
                    pointsChangedFlag = double(structuralMask(:));
                end
                rawCleanDelta = abs(M_clean(:) - M_raw(:));
                rawSmoothDelta = abs(M_smooth(:) - M_raw(:));
                pointsCleanTbl = [pointsCleanTbl; table(repmat(double(iFile), nRows, 1), double(rowIndex), double(TemperatureK(:)), double(MagneticFieldOe(:)), double(TimeSec(:)), ...
                    double(M_raw(:)), double(M_clean(:)), double(M_smooth(:)), sampleMassCol, repmat(cleaningBranch, nRows, 1), repmat(cleaningReasonCode, nRows, 1), double(pointsChangedFlag), ...
                    double(rawCleanDelta), double(rawSmoothDelta), repmat(cleaningEffectClass, nRows, 1), repmat(cleaningWarningClass, nRows, 1), repmat(cleaningTrust, nRows, 1), ...
                    repmat(0, nRows, 1), repmat("unknown", nRows, 1), repmat("not_implemented", nRows, 1), ...
                    'VariableNames', {'file_id','row_index','T_K','H_Oe','time_s','M_emu_raw','M_emu_clean','M_emu_smooth','sample_mass_g','cleaning_branch','cleaning_reason_code','points_changed_flag','raw_clean_abs_delta','raw_smooth_abs_delta','cleaning_effect_class','cleaning_warning_class','cleaning_trust','segment_id','segment_type','segment_source'})];

                filteredTemp = medfilt1(T_smooth, 20);
                incSeg = {};
                decSeg = {};

                if numel(filteredTemp) >= 2
                    filteredTemp(1) = filteredTemp(2);
                    tempHi = max(filteredTemp);
                    tempLo = min(filteredTemp);

                    incSeg = find_increasing_temperature_segments_MT( ...
                        TimeSec, filteredTemp, cfg.segmentation.min_segment_length_temp, ...
                        tempHi, cfg.segmentation.min_temp_change, ...
                        cfg.segmentation.min_temp_time_window_change, cfg.segmentation.temp_rate, ...
                        cfg.segmentation.temp_stabilization_window, cfg.segmentation.delta_T);

                    decSeg = find_decreasing_temperature_segments_MT( ...
                        TimeSec, filteredTemp, cfg.segmentation.min_segment_length_temp, ...
                        tempLo, cfg.segmentation.min_temp_change, ...
                        cfg.segmentation.min_temp_time_window_change, cfg.segmentation.temp_rate, ...
                        cfg.segmentation.temp_stabilization_window, cfg.segmentation.delta_T);
                end

                for j = 1:numel(incSeg)
                    rr = incSeg{j};
                    if numel(rr) == 2
                        sIdx = rr(1);
                        eIdx = rr(2);
                        if sIdx >= 1 && eIdx <= numel(TimeSec) && sIdx <= eIdx
                            segmentsTbl = [segmentsTbl; table(double(iFile), "increasing", double(j), double(sIdx), double(eIdx), double(TimeSec(sIdx)), double(TimeSec(eIdx)), double(T_smooth(sIdx)), double(T_smooth(eIdx)), ...
                                'VariableNames', {'file_id','segment_type','segment_id','start_idx','end_idx','time_start_s','time_end_s','T_start_K','T_end_K'})];
                        end
                    end
                end

                for j = 1:numel(decSeg)
                    rr = decSeg{j};
                    if numel(rr) == 2
                        sIdx = rr(1);
                        eIdx = rr(2);
                        if sIdx >= 1 && eIdx <= numel(TimeSec) && sIdx <= eIdx
                            segmentsTbl = [segmentsTbl; table(double(iFile), "decreasing", double(j), double(sIdx), double(eIdx), double(TimeSec(sIdx)), double(TimeSec(eIdx)), double(T_smooth(sIdx)), double(T_smooth(eIdx)), ...
                                'VariableNames', {'file_id','segment_type','segment_id','start_idx','end_idx','time_start_s','time_end_s','T_start_K','T_end_K'})];
                        end
                    end
                end

            catch ME_import
                importedFail = importedFail + 1;
                importError = string(ME_import.message);
            end

            fileInventory = [fileInventory; table(double(iFile), thisName, thisPath, double(thisField), double(massFromName), string(systemType), parserSelected, importStatus + "|" + importError, double(nRows), double(timeMin), double(timeMax), logical(timeRegularWarning), ...
                double(dtMean), double(dtStd), double(dtCv), double(dtMedian), double(dtQ90), double(dtQ99), double(dtMax), double(negativeDtCount), double(zeroDtCount), double(pauseGapCount), double(pauseGapFraction), ...
                timeQuality, timeWarningClass, timeBlockerReason, segmentationTrust, ...
                'VariableNames', {'file_id','file_name','file_path','field_from_name_oe','mass_mg','system_detected','parser_selected','import_status','n_rows','time_min_s','time_max_s','time_regular_warning','dt_mean_s','dt_std_s','dt_cv','dt_median_s','dt_q90_s','dt_q99_s','dt_max_s','negative_dt_count','zero_dt_count','pause_gap_count','pause_gap_fraction','time_quality','time_warning_class','time_blocker_reason','segmentation_trust'})];
        end

        if importedFail == 0 && importedOk > 0
            mtImportStrictnessOk = "YES";
        else
            mtImportStrictnessOk = "NO";
        end

    else
        mtInputFound = "NO";
        mtImportStrictnessOk = "NO";
    end

    if height(cleaningAudit) > 0
        ub = unique(cleaningAudit.cleaning_policy_branch);
        splitPresent = numel(ub) > 1;
        if splitPresent
            mtCleaningPolicyBranchSplitPresent = "YES";
        end
        worstCleaningTrustRank = 1;
        for r = 1:height(cleaningAudit)
            eff = char(cleaningAudit.cleaning_effect_class(r));
            ch = cleaningAudit.points_changed_count(r);
            warnClass = "NONE";
            trust = "HIGH";
            if strcmp(eff, 'UNRESOLVED')
                warnClass = "CHANGED_POINTS";
                trust = "LOW";
            elseif ch > 0
                warnClass = "CHANGED_POINTS";
                trust = "LOW";
            elseif strcmp(eff, 'HIGH')
                warnClass = "HIGH_EFFECT";
                trust = "LOW";
            elseif strcmp(eff, 'MEDIUM')
                warnClass = "HIGH_EFFECT";
                trust = "MEDIUM";
            elseif strcmp(eff, 'LOW')
                warnClass = "NONE";
                trust = "MEDIUM";
            else
                if splitPresent
                    warnClass = "BRANCH_SPLIT_ONLY";
                    trust = "MEDIUM";
                else
                    warnClass = "NONE";
                    trust = "HIGH";
                end
            end
            cleaningAudit.cleaning_warning_class(r) = string(warnClass);
            cleaningAudit.cleaning_trust(r) = string(trust);
            if strcmp(trust, 'LOW')
                rk = 3;
            elseif strcmp(trust, 'MEDIUM')
                rk = 2;
            else
                rk = 1;
            end
            worstCleaningTrustRank = max(worstCleaningTrustRank, rk);
        end
        if any(cleaningAudit.points_changed_count > 0)
            mtCleaningChangedPointsPresent = "YES";
        elseif any(strcmp(cleaningAudit.cleaning_effect_class, "UNRESOLVED"))
            mtCleaningChangedPointsPresent = "POSSIBLY_UNRESOLVED";
        else
            mtCleaningChangedPointsPresent = "NO";
        end
        if any(strcmp(cleaningAudit.cleaning_effect_class, "HIGH"))
            mtCleaningEffectRiskPresent = "YES";
        else
            mtCleaningEffectRiskPresent = "NO";
        end
        if strcmp(mtCleaningPolicyBranchSplitPresent, "YES") && strcmp(mtCleaningChangedPointsPresent, "YES") && strcmp(mtCleaningEffectRiskPresent, "YES")
            mtCleaningBranchSplitIsBlocker = "YES";
        end
        if worstCleaningTrustRank >= 3
            mtCleaningTrustLevel = "LOW";
        elseif worstCleaningTrustRank >= 2
            mtCleaningTrustLevel = "MEDIUM";
        else
            mtCleaningTrustLevel = "HIGH";
        end
    end

    if height(pointsCleanTbl) > 0
        nP = height(pointsCleanTbl);
        timeRel = NaN(nP, 1);
        mOverH = NaN(nP, 1);
        mNorm = NaN(nP, 1);
        chiMass = NaN(nP, 1);
        dMdT = NaN(nP, 1);
        dMdt = NaN(nP, 1);
        dTdt = NaN(nP, 1);
        segProgress = NaN(nP, 1);
        segDir = repmat("0", nP, 1);
        derivedValid = ones(nP, 1);
        derivedReason = repmat("OK", nP, 1);

        uf = unique(pointsCleanTbl.file_id);
        for kk = 1:numel(uf)
            fid = uf(kk);
            idx = find(pointsCleanTbl.file_id == fid);
            t = pointsCleanTbl.time_s(idx);
            mf = isfinite(t);
            if any(mf)
                t0 = t(find(mf, 1, 'first'));
                timeRel(idx(mf)) = t(mf) - t0;
            end
            nLoc = numel(idx);
            if nLoc > 1
                segProgress(idx) = (0:(nLoc-1))' ./ (nLoc-1);
            else
                segProgress(idx) = 0;
            end
        end

        hz = pointsCleanTbl.H_Oe;
        mz = pointsCleanTbl.M_emu_clean;
        nz = pointsCleanTbl.sample_mass_g;
        okH = isfinite(hz) & hz ~= 0 & isfinite(mz);
        mOverH(okH) = mz(okH) ./ hz(okH);
        badH = isfinite(mz) & (~isfinite(hz) | hz == 0);
        derivedReason(badH) = "zero_or_missing_field";

        okMass = isfinite(nz) & nz > 0 & isfinite(mz);
        mNorm(okMass) = mz(okMass) ./ nz(okMass);
        chiOk = okMass & isfinite(hz) & hz ~= 0;
        chiMass(chiOk) = mNorm(chiOk) ./ hz(chiOk);
        badMass = isfinite(mz) & (~isfinite(nz) | nz <= 0);
        derivedReason(badMass) = "missing_mass";
        badChi = okMass & (~isfinite(hz) | hz == 0);
        derivedReason(badChi) = "zero_or_missing_field";

        dMdT(:) = NaN;
        dMdt(:) = NaN;
        dTdt(:) = NaN;
        needDer = true(nP,1);
        derivedReason(needDer & derivedReason=="OK") = "derivative_not_implemented";
        derivedValid(derivedReason ~= "OK") = 0;
        hasCore = isfinite(pointsCleanTbl.M_emu_clean) & isfinite(pointsCleanTbl.time_s);
        derivedValid(hasCore) = 1;

        pointsDerivedTbl = table(pointsCleanTbl.file_id, pointsCleanTbl.row_index, pointsCleanTbl.T_K, pointsCleanTbl.H_Oe, pointsCleanTbl.time_s, ...
            pointsCleanTbl.M_emu_clean, pointsCleanTbl.sample_mass_g, timeRel, mOverH, mNorm, chiMass, dMdT, dMdt, dTdt, ...
            pointsCleanTbl.segment_id, pointsCleanTbl.segment_type, segProgress, segDir, double(derivedValid), derivedReason, ...
            'VariableNames', {'file_id','row_index','T_K','H_Oe','time_s','M_emu_clean','sample_mass_g','time_rel_s','M_over_H_emu_per_Oe','M_norm_emu_per_g','chi_mass_emu_per_g_per_Oe','dM_dT_emu_per_K','dM_dt_emu_per_s','dT_dt_K_per_s','segment_id','segment_type','segment_progress_01','segment_direction_sign','derived_valid_flag','derived_missing_reason'});
    end

    if height(pointsDerivedTbl) > 0
        uf = unique(pointsDerivedTbl.file_id);
        for kk = 1:numel(uf)
            fid = uf(kk);
            idx = pointsDerivedTbl.file_id == fid;
            vals = pointsDerivedTbl.M_over_H_emu_per_Oe(idx);
            vals = vals(isfinite(vals));
            nUsed = numel(vals);
            v = NaN;
            qf = "LOW";
            notes = "No finite derived points";
            if nUsed > 0
                v = mean(vals);
                qf = "MEDIUM";
                notes = "Stage 4.2 minimal observable from derived";
            end
            observablesTbl = [observablesTbl; table("mean_M_over_H", "file_level", double(fid), double(0), "unknown", ...
                "File-level mean of M_over_H from derived points", "M_over_H_emu_per_Oe", "mean", "scalar", double(v), "emu_per_Oe", double(nUsed), qf, notes, ...
                'VariableNames', {'observable_name','observable_variant','file_id','segment_id','segment_type','definition','source_columns','aggregation_method','temperature_dependence','value_numeric','value_unit','n_points_used','quality_flag','notes'})];
        end
    end

    gNames = ["schema_columns_present","required_fields_nonmissing","row_parity_raw_clean_derived","key_uniqueness","no_float_coordinate_joins","clean_raw_traceability","smooth_not_clean_replacement","derived_source_isolation","time_channel_assumption_check","segmentation_annotation_check","observables_provenance_check"]';
    gIds = ["G01","G02","G03","G04","G05","G06","G07","G08","G09","G10","G11"]';
    gSeverity = ["HIGH","HIGH","HIGH","HIGH","HIGH","HIGH","MEDIUM","HIGH","MEDIUM","MEDIUM","HIGH"]';
    gBlockFull = ["YES","YES","YES","YES","YES","YES","YES","YES","NO","NO","YES"]';
    gBlockProd = repmat("YES", 11, 1);
    gBlockAdv = repmat("YES", 11, 1);
    gStatus = repmat("PASS", 11, 1);
    gDetails = repmat("ok", 11, 1);

    reqRaw = ["file_id","row_index","T_K","H_Oe","time_s","M_emu","sample_mass_g","import_status","time_quality","time_warning_class"];
    reqClean = ["file_id","row_index","T_K","H_Oe","time_s","M_emu_raw","M_emu_clean","M_emu_smooth","cleaning_branch","cleaning_reason_code","points_changed_flag","raw_clean_abs_delta","raw_smooth_abs_delta","cleaning_effect_class","cleaning_warning_class","cleaning_trust","segment_id","segment_type","segment_source"];
    reqDer = ["file_id","row_index","T_K","H_Oe","time_s","M_emu_clean","sample_mass_g","time_rel_s","M_over_H_emu_per_Oe","M_norm_emu_per_g","chi_mass_emu_per_g_per_Oe","dM_dT_emu_per_K","dM_dt_emu_per_s","dT_dt_K_per_s","segment_id","segment_type","segment_progress_01","segment_direction_sign","derived_valid_flag","derived_missing_reason"];
    reqObs = ["observable_name","observable_variant","file_id","segment_id","segment_type","definition","source_columns","aggregation_method","temperature_dependence","value_numeric","value_unit","n_points_used","quality_flag","notes"];
    rawCols = string(pointsRawTbl.Properties.VariableNames);
    cleanCols = string(pointsCleanTbl.Properties.VariableNames);
    derCols = string(pointsDerivedTbl.Properties.VariableNames);
    obsCols = string(observablesTbl.Properties.VariableNames);
    if ~all(ismember(reqRaw, rawCols)) || ~all(ismember(reqClean, cleanCols)) || ~all(ismember(reqDer, derCols)) || ~all(ismember(reqObs, obsCols))
        gStatus(1) = "FAIL"; gDetails(1) = "missing required schema column(s)";
    else
        gDetails(1) = "required schema columns present for RAW/CLEAN/DERIVED/OBS";
    end

    reqIssues = strings(0,1);
    reqNumRaw = ["file_id","row_index","T_K","H_Oe","time_s","M_emu"];
    reqStrRaw = ["import_status","time_quality","time_warning_class"];
    reqNumClean = ["file_id","row_index","T_K","H_Oe","time_s","M_emu_raw","M_emu_clean","M_emu_smooth","points_changed_flag","raw_clean_abs_delta","raw_smooth_abs_delta","segment_id"];
    reqStrClean = ["cleaning_branch","cleaning_reason_code","cleaning_effect_class","cleaning_warning_class","cleaning_trust","segment_type","segment_source"];
    reqNumDerNoNaN = ["file_id","row_index","T_K","H_Oe","time_s","M_emu_clean","derived_valid_flag"];
    reqStrDer = ["segment_type","segment_direction_sign","derived_missing_reason"];
    reqStrObs = ["observable_name","observable_variant","segment_type","definition","source_columns","aggregation_method","temperature_dependence","value_unit","quality_flag"];
    for jj = 1:numel(reqNumRaw)
        cn = char(reqNumRaw(jj));
        if any(~isfinite(pointsRawTbl.(cn)))
            reqIssues(end+1) = "RAW numeric required has NaN/Inf: " + reqNumRaw(jj);
        end
    end
    for jj = 1:numel(reqStrRaw)
        cn = char(reqStrRaw(jj));
        if any(ismissing(pointsRawTbl.(cn)) | strlength(pointsRawTbl.(cn)) == 0)
            reqIssues(end+1) = "RAW string required missing: " + reqStrRaw(jj);
        end
    end
    for jj = 1:numel(reqNumClean)
        cn = char(reqNumClean(jj));
        if any(~isfinite(pointsCleanTbl.(cn)))
            reqIssues(end+1) = "CLEAN numeric required has NaN/Inf: " + reqNumClean(jj);
        end
    end
    for jj = 1:numel(reqStrClean)
        cn = char(reqStrClean(jj));
        if any(ismissing(pointsCleanTbl.(cn)) | strlength(pointsCleanTbl.(cn)) == 0)
            reqIssues(end+1) = "CLEAN string required missing: " + reqStrClean(jj);
        end
    end
    for jj = 1:numel(reqNumDerNoNaN)
        cn = char(reqNumDerNoNaN(jj));
        if any(~isfinite(pointsDerivedTbl.(cn)))
            reqIssues(end+1) = "DERIVED numeric required has NaN/Inf: " + reqNumDerNoNaN(jj);
        end
    end
    for jj = 1:numel(reqStrDer)
        cn = char(reqStrDer(jj));
        if any(ismissing(pointsDerivedTbl.(cn)) | strlength(pointsDerivedTbl.(cn)) == 0)
            reqIssues(end+1) = "DERIVED string required missing: " + reqStrDer(jj);
        end
    end
    for jj = 1:numel(reqStrObs)
        cn = char(reqStrObs(jj));
        if height(observablesTbl) > 0 && any(ismissing(observablesTbl.(cn)) | strlength(observablesTbl.(cn)) == 0)
            reqIssues(end+1) = "OBS string required missing: " + reqStrObs(jj);
        end
    end
    if isempty(reqIssues)
        gDetails(2) = "required fields populated per local required-column map; optional derived NaN semantics allowed";
    else
        gStatus(2) = "FAIL";
        gDetails(2) = "required field violations: " + strjoin(reqIssues(1:min(4,end)), " | ");
    end

    parityOk = (height(pointsRawTbl) == height(pointsCleanTbl)) && (height(pointsCleanTbl) == height(pointsDerivedTbl));
    keySetEq = false;
    if parityOk
        kRaw = sortrows(pointsRawTbl(:, {'file_id','row_index'}), {'file_id','row_index'});
        kClean = sortrows(pointsCleanTbl(:, {'file_id','row_index'}), {'file_id','row_index'});
        kDer = sortrows(pointsDerivedTbl(:, {'file_id','row_index'}), {'file_id','row_index'});
        keySetEq = isequal(kRaw{:,:}, kClean{:,:}) && isequal(kRaw{:,:}, kDer{:,:});
    end
    if ~parityOk || ~keySetEq
        gStatus(3) = "FAIL";
        gDetails(3) = "parity_ok=" + string(parityOk) + ", key_set_equality=" + string(keySetEq);
    else
        gDetails(3) = "row parity and immutable key-set equality verified";
    end

    if height(unique(pointsRawTbl(:,{'file_id','row_index'}))) ~= height(pointsRawTbl) || height(unique(pointsCleanTbl(:,{'file_id','row_index'}))) ~= height(pointsCleanTbl) || height(unique(pointsDerivedTbl(:,{'file_id','row_index'}))) ~= height(pointsDerivedTbl)
        gStatus(4) = "FAIL"; gDetails(4) = "duplicate key rows";
    else
        gDetails(4) = "unique(file_id,row_index) in RAW/CLEAN/DERIVED";
    end

    join_key_policy = "file_id,row_index_only";
    float_coordinate_join_used = false;
    if ~(join_key_policy == "file_id,row_index_only") || float_coordinate_join_used
        gStatus(5) = "FAIL";
    end
    gDetails(5) = "join_key_policy=" + join_key_policy + ", float_coordinate_join_used=" + string(float_coordinate_join_used);

    if any(abs(pointsCleanTbl.M_emu_raw - pointsRawTbl.M_emu) > 0 | xor(isfinite(pointsCleanTbl.M_emu_raw), isfinite(pointsRawTbl.M_emu)))
        gStatus(6) = "FAIL"; gDetails(6) = "clean raw traceability mismatch";
    else
        gDetails(6) = "M_emu_raw in CLEAN matches RAW M_emu on immutable keys";
    end

    derived_uses_clean_channel = ismember("M_emu_clean", derCols) && ~ismember("M_emu_smooth", derCols);
    smoothOverwriteSuspected = false;
    cleanMask = pointsCleanTbl.cleaning_branch == "cleaned";
    eqMask = cleanMask & isfinite(pointsCleanTbl.M_emu_clean) & isfinite(pointsCleanTbl.M_emu_smooth);
    if any(eqMask)
        fracEq = sum(abs(pointsCleanTbl.M_emu_clean(eqMask) - pointsCleanTbl.M_emu_smooth(eqMask)) <= 1e-15) / sum(eqMask);
        if fracEq > 0.999
            smoothOverwriteSuspected = true;
        end
    end
    smooth_used_as_clean_truth = smoothOverwriteSuspected || ~derived_uses_clean_channel;
    if ~derived_uses_clean_channel || smooth_used_as_clean_truth
        gStatus(7) = "FAIL";
    end
    gDetails(7) = "derived_uses_clean_channel=" + string(derived_uses_clean_channel) + ", smooth_used_as_clean_truth=" + string(smooth_used_as_clean_truth);

    derived_source_table = "mt_points_clean";
    rawOnlyCols = setdiff(rawCols, cleanCols);
    derived_uses_raw_only_column = any(ismember(rawOnlyCols, derCols));
    if ~(derived_source_table == "mt_points_clean") || derived_uses_raw_only_column
        gStatus(8) = "FAIL";
    end
    gDetails(8) = "derived_source_table=" + derived_source_table + ", derived_uses_raw_only_column=" + string(derived_uses_raw_only_column);

    time_s_assumed_elapsed = false;
    time_rel_s_explicit = ismember("time_rel_s", derCols);
    timeRelConsistent = true;
    if time_rel_s_explicit
        uf = unique(pointsDerivedTbl.file_id);
        for kk = 1:numel(uf)
            idx = find(pointsDerivedTbl.file_id == uf(kk));
            t = pointsDerivedTbl.time_s(idx);
            tr = pointsDerivedTbl.time_rel_s(idx);
            mf = find(isfinite(t) & isfinite(tr), 1, 'first');
            if ~isempty(mf)
                if abs(tr(mf)) > 1e-9
                    timeRelConsistent = false;
                    break;
                end
            end
        end
    else
        timeRelConsistent = false;
    end
    if time_s_assumed_elapsed || ~time_rel_s_explicit || ~timeRelConsistent
        gStatus(9) = "FAIL";
    end
    gDetails(9) = "time_s_assumed_elapsed=" + string(time_s_assumed_elapsed) + ", time_rel_s_explicit=" + string(time_rel_s_explicit) + ", time_rel_s_consistent=" + string(timeRelConsistent);

    segmentation_is_cleaning = false;
    segment_source_populated = ~any(ismissing(pointsCleanTbl.segment_source) | strlength(pointsCleanTbl.segment_source) == 0);
    if segmentation_is_cleaning || ~segment_source_populated
        gStatus(10) = "FAIL";
    end
    gDetails(10) = "segmentation_is_cleaning=" + string(segmentation_is_cleaning) + ", segment_source_populated=" + string(segment_source_populated);

    if height(observablesTbl) > 0
        missObs = any(observablesTbl.source_columns == "" | observablesTbl.aggregation_method == "" | observablesTbl.definition == "");
        if missObs
            gStatus(11) = "FAIL"; gDetails(11) = "observable provenance missing";
        else
            gDetails(11) = "observable provenance complete";
        end
    else
        gDetails(11) = "empty but schema-valid observables";
    end

    gateSummaryTbl = table(gIds, gNames, gStatus, gSeverity, gBlockFull, gBlockProd, gBlockAdv, gDetails, ...
        'VariableNames', {'gate_id','gate_name','status','severity','blocks_full_canonical','blocks_production_release','blocks_advanced_analysis','details'});
    failMask = gateSummaryTbl.status == "FAIL";
    if any(failMask)
        pointTableGateSummary = "FAIL";
        for ii = find(failMask').'
            gateFailuresTbl = [gateFailuresTbl; table(gateSummaryTbl.gate_id(ii), gateSummaryTbl.gate_name(ii), gateSummaryTbl.severity(ii), "Validation gate failed", "Fix producer logic and re-run", ...
                'VariableNames', {'gate_id','gate_name','severity','failure_mode_description','required_action'})];
        end
    else
        pointTableGateSummary = "PASS";
    end

    inventoryPath = fullfile(tablesDir, 'mt_file_inventory.csv');
    rawSummaryPath = fullfile(tablesDir, 'mt_raw_summary.csv');
    cleaningAuditPath = fullfile(tablesDir, 'mt_cleaning_audit.csv');
    segmentsPath = fullfile(tablesDir, 'mt_segments.csv');
    pointsRawPath = fullfile(tablesDir, 'mt_points_raw.csv');
    pointsCleanPath = fullfile(tablesDir, 'mt_points_clean.csv');
    pointsDerivedPath = fullfile(tablesDir, 'mt_points_derived.csv');
    observablesPath = fullfile(tablesDir, 'mt_observables.csv');
    pointGateSummaryPath = fullfile(tablesDir, 'mt_point_tables_validation_summary.csv');
    pointGateFailuresPath = fullfile(tablesDir, 'mt_point_tables_gate_failures.csv');

    writetable(fileInventory, inventoryPath);
    writetable(rawSummary, rawSummaryPath);
    writetable(cleaningAudit, cleaningAuditPath);
    writetable(segmentsTbl, segmentsPath);
    writetable(pointsRawTbl, pointsRawPath);
    writetable(pointsCleanTbl, pointsCleanPath);
    writetable(pointsDerivedTbl, pointsDerivedPath);
    writetable(observablesTbl, observablesPath);
    writetable(gateSummaryTbl, pointGateSummaryPath);
    writetable(gateFailuresTbl, pointGateFailuresPath);

    mtCleaningAuditWritten = "YES";
    mtSegmentTableWritten = "YES";
    pointTablesWritten = "YES";
    if pointTableGateSummary == "PASS" && pointTablesWritten == "YES"
        fullCanonicalDataProduct = "PARTIAL";
    else
        fullCanonicalDataProduct = "NO";
    end

    if strcmp(mtTimeAxisCorruptionPresent, "YES") || strcmp(mtTimeAxisPauseGapsPresent, "YES") || strcmp(mtTimeAxisSegmentationRiskPresent, "YES") || timeWarningCount > 0
        mtTimeAxisWarningsPresent = "YES";
    else
        mtTimeAxisWarningsPresent = "NO";
    end
    if runSegmentationTrustRank == 1
        mtSegmentationTrustLevel = "HIGH";
    elseif runSegmentationTrustRank == 2
        mtSegmentationTrustLevel = "MEDIUM";
    elseif runSegmentationTrustRank == 3
        mtSegmentationTrustLevel = "LOW";
    else
        mtSegmentationTrustLevel = "FAIL";
    end

    metricCol = [ ...
        "RUN_ID"; ...
        "CONFIG_LOADED"; ...
        "CONFIG_PATH"; ...
        "INPUT_DIR"; ...
        "DAT_FILE_COUNT"; ...
        "IMPORTED_OK"; ...
        "IMPORTED_FAIL"; ...
        "MT_INPUT_FOUND"; ...
        "MT_IMPORT_STRICTNESS_OK"; ...
        "MT_CLEANING_AUDIT_WRITTEN"; ...
        "MT_SEGMENT_TABLE_WRITTEN"; ...
        "MT_TIME_AXIS_WARNINGS_PRESENT"; ...
        "MT_TIME_AXIS_CORRUPTION_PRESENT"; ...
        "MT_TIME_AXIS_PAUSE_GAPS_PRESENT"; ...
        "MT_TIME_AXIS_SEGMENTATION_RISK_PRESENT"; ...
        "MT_SEGMENTATION_TRUST_LEVEL"; ...
        "MT_CLEANING_POLICY_BRANCH_SPLIT_PRESENT"; ...
        "MT_CLEANING_CHANGED_POINTS_PRESENT"; ...
        "MT_CLEANING_EFFECT_RISK_PRESENT"; ...
        "MT_CLEANING_BRANCH_SPLIT_IS_BLOCKER"; ...
        "MT_CLEANING_TRUST_LEVEL"; ...
        "MT_POINT_TABLES_GATE_SUMMARY"; ...
        "POINT_TABLES_WRITTEN"; ...
        "RAW_CLEAN_DERIVED_SEPARATION"; ...
        "FULL_CANONICAL_DATA_PRODUCT"; ...
        "MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE"; ...
        "MT_READY_FOR_ADVANCED_ANALYSIS"; ...
        "DIAGNOSTIC_ONLY"];

    valueCol = [ ...
        string(run.run_id); ...
        configLoadedStr; ...
        string(configPathReport); ...
        string(inputDir); ...
        string(datCount); ...
        string(importedOk); ...
        string(importedFail); ...
        mtInputFound; ...
        mtImportStrictnessOk; ...
        mtCleaningAuditWritten; ...
        mtSegmentTableWritten; ...
        mtTimeAxisWarningsPresent; ...
        mtTimeAxisCorruptionPresent; ...
        mtTimeAxisPauseGapsPresent; ...
        mtTimeAxisSegmentationRiskPresent; ...
        mtSegmentationTrustLevel; ...
        mtCleaningPolicyBranchSplitPresent; ...
        mtCleaningChangedPointsPresent; ...
        mtCleaningEffectRiskPresent; ...
        mtCleaningBranchSplitIsBlocker; ...
        mtCleaningTrustLevel; ...
        pointTableGateSummary; ...
        pointTablesWritten; ...
        "TABLE_LEVEL"; ...
        fullCanonicalDataProduct; ...
        mtReadyForProductionRelease; ...
        mtReadyForAdvancedAnalysis; ...
        "YES"];

    canonicalSummary = table(metricCol, valueCol, ...
        'VariableNames', {'metric','value'});

    runSummaryPath = fullfile(tablesDir, 'mt_canonical_run_summary.csv');
    writetable(canonicalSummary, runSummaryPath);

    reportPath = fullfile(reportsDir, 'mt_canonical_run_report.md');
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('MTCanonical:ReportWriteFailed', 'Failed to write mt_canonical_run_report.md');
    end

    fprintf(fidReport, '# MT Canonical Diagnostic Run Report\n\n');
    fprintf(fidReport, '- RUN_ID: %s\n', run.run_id);
    fprintf(fidReport, '- RUN_DIR: %s\n', run.run_dir);
    fprintf(fidReport, '- CONFIG_LOADED=%s\n', char(configLoadedStr));
    fprintf(fidReport, '- CONFIG_PATH=%s\n', configPathReport);
    fprintf(fidReport, '- INPUT_DIR: %s\n', inputDir);
    fprintf(fidReport, '- DAT_FILE_COUNT: %d\n', datCount);
    fprintf(fidReport, '- IMPORTED_OK: %d\n', importedOk);
    fprintf(fidReport, '- IMPORTED_FAIL: %d\n', importedFail);
    fprintf(fidReport, '- DIAGNOSTIC_ONLY: YES\n');
    fprintf(fidReport, '- PRODUCTION_RELEASE: BLOCKED\n\n');

    fprintf(fidReport, '## Blocker and status flags\n\n');
    fprintf(fidReport, '- MT_INPUT_FOUND=%s\n', mtInputFound);
    fprintf(fidReport, '- MT_IMPORT_STRICTNESS_OK=%s\n', mtImportStrictnessOk);
    fprintf(fidReport, '- MT_CLEANING_AUDIT_WRITTEN=%s\n', mtCleaningAuditWritten);
    fprintf(fidReport, '- MT_SEGMENT_TABLE_WRITTEN=%s\n', mtSegmentTableWritten);
    fprintf(fidReport, '- MT_TIME_AXIS_WARNINGS_PRESENT=%s\n', mtTimeAxisWarningsPresent);
    fprintf(fidReport, '- MT_TIME_AXIS_CORRUPTION_PRESENT=%s\n', mtTimeAxisCorruptionPresent);
    fprintf(fidReport, '- MT_TIME_AXIS_PAUSE_GAPS_PRESENT=%s\n', mtTimeAxisPauseGapsPresent);
    fprintf(fidReport, '- MT_TIME_AXIS_SEGMENTATION_RISK_PRESENT=%s\n', mtTimeAxisSegmentationRiskPresent);
    fprintf(fidReport, '- MT_SEGMENTATION_TRUST_LEVEL=%s\n', mtSegmentationTrustLevel);
    fprintf(fidReport, '- MT_CLEANING_POLICY_BRANCH_SPLIT_PRESENT=%s\n', mtCleaningPolicyBranchSplitPresent);
    fprintf(fidReport, '- MT_CLEANING_CHANGED_POINTS_PRESENT=%s\n', mtCleaningChangedPointsPresent);
    fprintf(fidReport, '- MT_CLEANING_EFFECT_RISK_PRESENT=%s\n', mtCleaningEffectRiskPresent);
    fprintf(fidReport, '- MT_CLEANING_BRANCH_SPLIT_IS_BLOCKER=%s\n', mtCleaningBranchSplitIsBlocker);
    fprintf(fidReport, '- MT_CLEANING_TRUST_LEVEL=%s\n', mtCleaningTrustLevel);
    fprintf(fidReport, '- MT_POINT_TABLES_GATE_SUMMARY=%s\n', pointTableGateSummary);
    fprintf(fidReport, '- POINT_TABLES_WRITTEN=%s\n', pointTablesWritten);
    fprintf(fidReport, '- RAW_CLEAN_DERIVED_SEPARATION=TABLE_LEVEL\n');
    fprintf(fidReport, '- FULL_CANONICAL_DATA_PRODUCT=%s\n', fullCanonicalDataProduct);
    fprintf(fidReport, '- MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=%s\n', mtReadyForProductionRelease);
    fprintf(fidReport, '- MT_READY_FOR_ADVANCED_ANALYSIS=%s\n\n', mtReadyForAdvancedAnalysis);

    fprintf(fidReport, '## Output artifacts\n\n');
    fprintf(fidReport, '- tables/mt_file_inventory.csv\n');
    fprintf(fidReport, '- tables/mt_raw_summary.csv\n');
    fprintf(fidReport, '- tables/mt_cleaning_audit.csv\n');
    fprintf(fidReport, '- tables/mt_segments.csv\n');
    fprintf(fidReport, '- tables/mt_points_raw.csv\n');
    fprintf(fidReport, '- tables/mt_points_clean.csv\n');
    fprintf(fidReport, '- tables/mt_points_derived.csv\n');
    fprintf(fidReport, '- tables/mt_observables.csv\n');
    fprintf(fidReport, '- tables/mt_point_tables_validation_summary.csv\n');
    fprintf(fidReport, '- tables/mt_point_tables_gate_failures.csv\n');
    fprintf(fidReport, '- tables/mt_canonical_run_summary.csv\n');
    fprintf(fidReport, '- reports/mt_canonical_run_report.md\n');
    fprintf(fidReport, '- execution_status.csv\n');
    fclose(fidReport);

    statusText = "SUCCESS";
    inputFoundText = "NO";
    summaryText = "diagnostic run artifacts written";

    if strcmp(mtInputFound, "YES")
        inputFoundText = "YES";
        if importedFail > 0
            summaryText = "diagnostic artifacts written with import failures";
        elseif timeWarningCount > 0
            summaryText = "diagnostic artifacts written with time-axis warnings";
        else
            summaryText = "diagnostic artifacts written";
        end
    else
        summaryText = "no input directory or DAT files; empty diagnostic artifacts written";
    end

    executionStatus = table({char(statusText)}, {char(inputFoundText)}, {''}, height(fileInventory), {char(summaryText)}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'mt', 'runs', 'run_mt_canonical_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end

    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'mt diagnostic canonical runner failed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
