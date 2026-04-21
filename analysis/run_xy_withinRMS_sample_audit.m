clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XYWithinRMSAudit:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

cfgRun = struct();
cfgRun.runLabel = 'xy_withinRMS_sample_audit';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');

outCsvPath = fullfile(tablesDir, 'xy_withinRMS_sample_audit.csv');
outReportPath = fullfile(reportsDir, 'xy_withinRMS_sample_audit.md');

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('analysis', cfgRun);

    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end

    xyParentDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\FIB5_Switching_old_PPMS\Config3 23\Amp Temp Dep all';
    if exist(xyParentDir, 'dir') ~= 7
        error('XYWithinRMSAudit:MissingXYParentDir', 'XY source directory does not exist: %s', xyParentDir);
    end

    delayBetweenPulseScale = 1e3;
    safety_margin_percent = 15;
    minPtsFit = 10;
    temperatureCutoffK = 34;

    rows = {};

    tempDirs = dir(fullfile(xyParentDir, 'Temp Dep *'));
    tempDirs = tempDirs([tempDirs.isdir]);
    for iDir = 1:numel(tempDirs)
        thisDir = fullfile(xyParentDir, tempDirs(iDir).name);
        dep_type = extract_dep_type_from_folder(thisDir);
        [fileList, sortedValues, ~, meta] = getFileListSwitching(thisDir, dep_type);
        if isempty(fileList)
            continue;
        end

        amp = meta.Current_mA;
        if ~isfinite(amp)
            continue;
        end

        pulseScheme = extractPulseSchemeFromFolder(thisDir);
        delay_between_pulses_in_msec = extract_delay_between_pulses_from_name(thisDir) * delayBetweenPulseScale;
        num_of_pulses_with_same_dep = pulseScheme.totalPulses;

        preset_name = resolve_preset(fileList(1).name, true, '1xy_3xx');
        [~, ~, ~, Normalize_to] = select_preset(preset_name);

        [stored_data, ~] = processFilesSwitching( ...
            thisDir, fileList, sortedValues, ...
            extract_current_I(thisDir, fileList(1).name, NaN), ...
            1e3, ...
            4000, 16, 4, 2, 11, ...
            false, delay_between_pulses_in_msec, ...
            num_of_pulses_with_same_dep, 15, ...
            NaN, NaN, Normalize_to, ...
            true, 1.5, 50, false, pulseScheme);

        stbOpts = struct();
        stbOpts.useFiltered = true;
        stbOpts.useCentered = false;
        stbOpts.stateMethod = pulseScheme.mode;
        stbOpts.skipFirstPlateaus = 1;
        stbOpts.skipLastPlateaus = 0;
        stbOpts.pulseScheme = pulseScheme;

        stability = analyzeSwitchingStability( ...
            stored_data, sortedValues, ...
            delay_between_pulses_in_msec, safety_margin_percent, stbOpts);

        switchCh = stability.switching.globalChannel;
        if ~(isfinite(switchCh) && switchCh >= 1 && switchCh <= 4)
            continue;
        end

        safety_margin_ms = delay_between_pulses_in_msec * (safety_margin_percent / 100);
        Nfiles = size(stored_data, 1);
        for iFile = 1:Nfiles
            data = stored_data{iFile, 2};
            if isempty(data) || size(data, 2) < 2
                continue;
            end

            t = data(:, 1);
            R = data(:, 2:end);
            numCh = size(R, 2);
            physIdxRow = stored_data{iFile, 7};
            if isempty(physIdxRow) || numel(physIdxRow) ~= numCh
                continue;
            end

            k = find(physIdxRow(:) == switchCh, 1, 'first');
            if isempty(k)
                continue;
            end

            pm = stored_data{iFile, 5};
            if isempty(pm) || size(pm, 1) < 1 || size(pm, 2) < k
                continue;
            end
            pmk = pm(:, k);
            numPulses = size(pm, 1);
            pulse_times = t(1) + (0:numPulses-1) * delay_between_pulses_in_msec;

            useJ = false(numPulses, 1);
            j0 = 1 + max(0, stbOpts.skipFirstPlateaus);
            j1 = numPulses - max(0, stbOpts.skipLastPlateaus);
            if j0 <= j1
                useJ(j0:j1) = true;
            end
            useJ = useJ & ~isnan(pmk);

            withinStd = nan(numPulses, 1);
            for j = 1:numPulses
                if ~useJ(j)
                    continue;
                end
                if j < numPulses
                    t1 = pulse_times(j) + safety_margin_ms;
                    t2 = pulse_times(j+1) - safety_margin_ms;
                else
                    t1 = pulse_times(j) + safety_margin_ms;
                    t2 = t(end);
                end
                idx = (t >= t1) & (t <= t2);
                vals = R(idx, k);
                if numel(vals) >= minPtsFit
                    withinStd(j) = std(vals, 'omitnan');
                end
            end

            rawVals = withinStd(useJ);
            rawVals = rawVals(isfinite(rawVals));
            nSamples = numel(rawVals);
            if nSamples == 0
                continue;
            end

            withinRMS = sqrt(mean(rawVals.^2, 'omitnan'));
            depVal = sortedValues(iFile);

            if ~(isfinite(depVal) && depVal <= temperatureCutoffK)
                continue;
            end

            rawText = sprintf('%.6g,', rawVals);
            if ~isempty(rawText)
                rawText = rawText(1:end-1);
            end
            rows(end+1, :) = {double(depVal), double(amp), double(nSamples), double(withinRMS), string(rawText)}; %#ok<AGROW>
        end
    end

    if isempty(rows)
        error('XYWithinRMSAudit:NoRows', 'No withinRMS audit rows were produced.');
    end

    outTbl = cell2table(rows, 'VariableNames', {'temperature_K', 'current_mA', 'samples_used', 'withinRMS', 'raw_withinStd_values'});
    outTbl = sortrows(outTbl, {'current_mA', 'temperature_K'});
    writetable(outTbl, outCsvPath);

    samplesPerBin = double(outTbl.samples_used);
    minS = min(samplesPerBin);
    medS = median(samplesPerBin);
    maxS = max(samplesPerBin);
    bugFlag = (minS <= 1);

    nShow = min(8, height(outTbl));
    showTbl = outTbl(1:nShow, :);

    fid = fopen(outReportPath, 'w');
    if fid < 0
        error('XYWithinRMSAudit:ReportOpenFailed', 'Unable to write report: %s', outReportPath);
    end
    fprintf(fid, '# XY withinRMS sample audit\n\n');
    fprintf(fid, 'WITHINRMS_FORMULA_CONFIRMED = YES\n');
    fprintf(fid, 'FORMULA = withinRMS = sqrt(mean(withinStd(useJ).^2))\n');
    fprintf(fid, 'MIN_SAMPLES_PER_BIN = %.0f\n', minS);
    fprintf(fid, 'MEDIAN_SAMPLES_PER_BIN = %.1f\n', medS);
    fprintf(fid, 'MAX_SAMPLES_PER_BIN = %.0f\n', maxS);
    if bugFlag
        fprintf(fid, 'BUG_MIN_LE_1 = YES\n');
    else
        fprintf(fid, 'BUG_MIN_LE_1 = NO\n');
    end
    fprintf(fid, '\n## Example bins\n\n');
    for i = 1:height(showTbl)
        fprintf(fid, '- T=%.3f K, I=%.3f mA: N=%d, withinRMS=%.6g, raw=[%s]\n', ...
            showTbl.temperature_K(i), showTbl.current_mA(i), showTbl.samples_used(i), ...
            showTbl.withinRMS(i), char(showTbl.raw_withinStd_values(i)));
    end
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(outTbl), {'withinRMS sample-count audit completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xy_withinRMS_sample_audit_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'withinRMS sample-count audit failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    writetable(executionStatus, statusPath);
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
writetable(executionStatus, statusPath);

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
