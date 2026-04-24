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

    fileInventory = table('Size', [0 12], ...
        'VariableTypes', {'double','string','string','double','double','string','string','string','double','double','double','logical'}, ...
        'VariableNames', {'file_id','file_name','file_path','field_from_name_oe','mass_mg','system_detected','parser_selected','import_status','n_rows','time_min_s','time_max_s','time_regular_warning'});

    rawSummary = table('Size', [0 9], ...
        'VariableTypes', {'double','double','double','double','double','double','double','double','logical'}, ...
        'VariableNames', {'file_id','n_rows','T_min_K','T_max_K','H_min_Oe','H_max_Oe','M_min_emu','M_max_emu','time_regular_warning'});

    cleaningAudit = table('Size', [0 9], ...
        'VariableTypes', {'double','string','double','double','logical','double','double','double','double'}, ...
        'VariableNames', {'file_id','cleaning_policy_branch','field_oe','field_threshold_oe','unfiltered_mode','n_raw','n_clean_non_nan','n_smooth_non_nan','n_masked_or_nan_after_clean'});

    segmentsTbl = table('Size', [0 9], ...
        'VariableTypes', {'double','string','double','double','double','double','double','double','double'}, ...
        'VariableNames', {'file_id','segment_type','segment_id','start_idx','end_idx','time_start_s','time_end_s','T_start_K','T_end_K'});

    mtInputFound = "NO";
    mtImportStrictnessOk = "NO";
    mtCleaningAuditWritten = "NO";
    mtSegmentTableWritten = "NO";
    mtTimeAxisWarningsPresent = "NO";
    mtReadyForProductionRelease = "NO";

    importedOk = 0;
    importedFail = 0;
    timeWarningCount = 0;

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
            timeRegularWarning = false;

            try
                if strcmp(parserSelected, "importOneFile_MT_MPMS")
                    [TimeSec, TemperatureK, MomentEmu, MagneticFieldOe] = importOneFile_MT_MPMS(char(thisPath), cfg.DC);
                else
                    [TimeSec, TemperatureK, MomentEmu, MagneticFieldOe] = importOneFile_MT(char(thisPath));
                end

                importStatus = "IMPORTED";
                importedOk = importedOk + 1;
                nRows = numel(TimeSec);

                if nRows > 0
                    timeMin = min(TimeSec);
                    timeMax = max(TimeSec);
                end

                if nRows >= 3
                    dt = diff(TimeSec);
                    dt = dt(isfinite(dt));
                    if ~isempty(dt)
                        dtMean = mean(abs(dt));
                        if dtMean > 0
                            dtCv = std(dt) / dtMean;
                            if dtCv > 0.05
                                timeRegularWarning = true;
                                timeWarningCount = timeWarningCount + 1;
                            end
                        end
                    end
                else
                    timeRegularWarning = true;
                    timeWarningCount = timeWarningCount + 1;
                end

                rawSummary = [rawSummary; table(double(iFile), double(nRows), min(TemperatureK), max(TemperatureK), min(MagneticFieldOe), max(MagneticFieldOe), min(MomentEmu), max(MomentEmu), timeRegularWarning, ...
                    'VariableNames', {'file_id','n_rows','T_min_K','T_max_K','H_min_Oe','H_max_Oe','M_min_emu','M_max_emu','time_regular_warning'})];

                [~, ~, ~, M_clean, T_smooth, M_smooth] = clean_MT_data(TemperatureK, MomentEmu, thisField, cfg.cleaning, cfg.Unfiltered);

                branchLabel = "cleaned";
                if cfg.Unfiltered
                    branchLabel = "unfiltered";
                elseif thisField < cfg.cleaning.field_threshold
                    branchLabel = "low_field_bypass";
                end

                nRaw = numel(MomentEmu);
                nClean = sum(isfinite(M_clean));
                nSmooth = sum(isfinite(M_smooth));
                nMasked = nRaw - nClean;

                cleaningAudit = [cleaningAudit; table(double(iFile), branchLabel, double(thisField), double(cfg.cleaning.field_threshold), logical(cfg.Unfiltered), double(nRaw), double(nClean), double(nSmooth), double(nMasked), ...
                    'VariableNames', {'file_id','cleaning_policy_branch','field_oe','field_threshold_oe','unfiltered_mode','n_raw','n_clean_non_nan','n_smooth_non_nan','n_masked_or_nan_after_clean'})];

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
                'VariableNames', {'file_id','file_name','file_path','field_from_name_oe','mass_mg','system_detected','parser_selected','import_status','n_rows','time_min_s','time_max_s','time_regular_warning'})];
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

    inventoryPath = fullfile(tablesDir, 'mt_file_inventory.csv');
    rawSummaryPath = fullfile(tablesDir, 'mt_raw_summary.csv');
    cleaningAuditPath = fullfile(tablesDir, 'mt_cleaning_audit.csv');
    segmentsPath = fullfile(tablesDir, 'mt_segments.csv');

    writetable(fileInventory, inventoryPath);
    writetable(rawSummary, rawSummaryPath);
    writetable(cleaningAudit, cleaningAuditPath);
    writetable(segmentsTbl, segmentsPath);

    mtCleaningAuditWritten = "YES";
    mtSegmentTableWritten = "YES";

    if timeWarningCount > 0
        mtTimeAxisWarningsPresent = "YES";
    else
        mtTimeAxisWarningsPresent = "NO";
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
        "POINT_TABLES_WRITTEN"; ...
        "RAW_CLEAN_DERIVED_SEPARATION"; ...
        "FULL_CANONICAL_DATA_PRODUCT"; ...
        "MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE"; ...
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
        "NO"; ...
        "SUMMARY_LEVEL_ONLY"; ...
        "NO"; ...
        mtReadyForProductionRelease; ...
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
    fprintf(fidReport, '- POINT_TABLES_WRITTEN=NO\n');
    fprintf(fidReport, '- RAW_CLEAN_DERIVED_SEPARATION=SUMMARY_LEVEL_ONLY\n');
    fprintf(fidReport, '- FULL_CANONICAL_DATA_PRODUCT=NO\n');
    fprintf(fidReport, '- MT_READY_FOR_PRODUCTION_CANONICAL_RELEASE=%s\n\n', mtReadyForProductionRelease);

    fprintf(fidReport, '## Output artifacts\n\n');
    fprintf(fidReport, '- tables/mt_file_inventory.csv\n');
    fprintf(fidReport, '- tables/mt_raw_summary.csv\n');
    fprintf(fidReport, '- tables/mt_cleaning_audit.csv\n');
    fprintf(fidReport, '- tables/mt_segments.csv\n');
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
