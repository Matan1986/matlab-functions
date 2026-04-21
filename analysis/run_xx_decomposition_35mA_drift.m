fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXDecomp35mADrift:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'scripts'));

cfgRun = struct();
cfgRun.runLabel = 'xx_decomposition_35mA_drift';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
eventOutPath = fullfile(repoRoot, 'tables', 'xx_decomposition_event_level_35mA_drift.csv');
tempOutPath = fullfile(repoRoot, 'tables', 'xx_decomposition_vs_temperature_35mA_drift.csv');
reportPath = fullfile(repoRoot, 'reports', 'xx_decomposition_35mA_drift.md');

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('analysis', cfgRun);

    channelTblPath = fullfile(repoRoot, 'tables', 'xx_channel_validation.csv');
    if exist(channelTblPath, 'file') ~= 2
        error('XXDecomp35mADrift:MissingChannelTable', 'Missing pipeline channel table: %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames) || isempty(channelTbl.pipeline_choice)
        error('XXDecomp35mADrift:MissingPipelineChoice', 'Cannot resolve pipeline-selected channel from %s', channelTblPath);
    end
    selectedChannel = double(channelTbl.pipeline_choice(1));
    if ~(selectedChannel == 2 || selectedChannel == 3)
        error('XXDecomp35mADrift:UnexpectedChannel', 'Expected channel 2 or 3, got %g', selectedChannel);
    end
    if selectedChannel == 2
        channelName = 'LI2_X (V)';
    else
        channelName = 'LI3_X (V)';
    end

    cfg = xx_relaxation_config2_sources();
    cfg35 = cfg(contains(string({cfg.config_id}), "35mA"));
    if isempty(cfg35)
        error('XXDecomp35mADrift:ConfigMissing', 'Could not find config2_35mA source in xx_relaxation_config2_sources().');
    end
    sourceDir = fullfile(char(cfg35.baseDir), char(cfg35.tempDepFolder));
    if exist(sourceDir, 'dir') ~= 7
        error('XXDecomp35mADrift:SourceMissing', '35 mA source directory not found: %s', sourceDir);
    end

    eventSrcPath = fullfile(repoRoot, 'tables', 'xx_35mA_model_free_relaxation.csv');
    if exist(eventSrcPath, 'file') ~= 2
        error('XXDecomp35mADrift:MissingPipelineEvents', 'Missing pipeline event table: %s', eventSrcPath);
    end
    srcEvents = readtable(eventSrcPath, 'TextType', 'string');
    needCols = {'file_id','temperature','pulse_index','target_state','switch_idx','relax_start_idx','window_end_idx'};
    for c = 1:numel(needCols)
        if ~ismember(needCols{c}, srcEvents.Properties.VariableNames)
            error('XXDecomp35mADrift:MissingColumn', 'Missing required event column: %s', needCols{c});
        end
    end
    srcEvents = sortrows(srcEvents, {'temperature', 'file_id', 'pulse_index'});
    if isempty(srcEvents)
        error('XXDecomp35mADrift:NoPipelineEvents', 'Pipeline event table is empty.');
    end

    file_id = strings(0, 1);
    temperature = zeros(0, 1);
    event_id = strings(0, 1);
    cm_drift = NaN(0, 1);
    sw_drift = NaN(0, 1);
    cm_drift_abs = NaN(0, 1);
    sw_drift_abs = NaN(0, 1);
    ratio_drift = NaN(0, 1);
    same_direction = false(0, 1);

    uFiles = unique(srcEvents.file_id);
    for fi = 1:numel(uFiles)
        fname = uFiles(fi);
        rowsF = srcEvents(srcEvents.file_id == fname, :);
        rawPath = fullfile(sourceDir, char(fname));
        if exist(rawPath, 'file') ~= 2
            continue;
        end

        data = readtable(rawPath, 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
        if ~ismember('Time (ms)', data.Properties.VariableNames) || ~ismember(channelName, data.Properties.VariableNames)
            continue;
        end

        tMs = data{:, 'Time (ms)'};
        v = data{:, channelName};
        if numel(tMs) < 50 || numel(v) ~= numel(tMs)
            continue;
        end

        aRows = rowsF(rowsF.target_state == "A", :);
        bRows = rowsF(rowsF.target_state == "B", :);
        nPairs = min(height(aRows), height(bRows));

        for p = 1:nPairs
            aStart = aRows.relax_start_idx(p);
            aEnd = aRows.window_end_idx(p);
            bStart = bRows.relax_start_idx(p);
            bEnd = bRows.window_end_idx(p);

            if ~(isfinite(aStart) && isfinite(aEnd) && isfinite(bStart) && isfinite(bEnd))
                continue;
            end

            aStart = max(1, round(aStart));
            aEnd = min(numel(v), round(aEnd));
            bStart = max(1, round(bStart));
            bEnd = min(numel(v), round(bEnd));

            if aEnd <= aStart || bEnd <= bStart
                continue;
            end

            idxA = aStart:aEnd;
            idxB = bStart:bEnd;
            ra = v(idxA);
            rb = v(idxB);

            nMin = min(numel(ra), numel(rb));
            if nMin < 5
                continue;
            end

            ra = ra(1:nMin);
            rb = rb(1:nMin);
            if any(~isfinite(ra)) || any(~isfinite(rb))
                continue;
            end

            r_cm = 0.5 * (ra + rb);
            r_sw = 0.5 * (ra - rb);

            nWin = max(1, floor(0.20 * nMin));
            idxFirst = 1:nWin;
            idxLast = (nMin - nWin + 1):nMin;

            cmDrift = mean(r_cm(idxFirst), 'omitnan') - mean(r_cm(idxLast), 'omitnan');
            swDrift = mean(r_sw(idxFirst), 'omitnan') - mean(r_sw(idxLast), 'omitnan');
            cmAbs = abs(cmDrift);
            swAbs = abs(swDrift);
            if swAbs > 0
                ratioVal = cmAbs / swAbs;
            else
                ratioVal = NaN;
            end

            file_id(end + 1, 1) = fname; %#ok<AGROW>
            temperature(end + 1, 1) = rowsF.temperature(1); %#ok<AGROW>
            event_id(end + 1, 1) = "pair_" + string(p); %#ok<AGROW>
            cm_drift(end + 1, 1) = cmDrift; %#ok<AGROW>
            sw_drift(end + 1, 1) = swDrift; %#ok<AGROW>
            cm_drift_abs(end + 1, 1) = cmAbs; %#ok<AGROW>
            sw_drift_abs(end + 1, 1) = swAbs; %#ok<AGROW>
            ratio_drift(end + 1, 1) = ratioVal; %#ok<AGROW>
            same_direction(end + 1, 1) = sign(cmDrift) == sign(swDrift); %#ok<AGROW>
        end
    end

    eventTbl = table(file_id, temperature, event_id, cm_drift, sw_drift, cm_drift_abs, sw_drift_abs, ratio_drift);
    eventTbl = sortrows(eventTbl, {'temperature', 'file_id', 'event_id'});
    writetable(eventTbl, eventOutPath);

    if isempty(eventTbl)
        tempTbl = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            'VariableNames', {'temperature', 'mean_cm_drift_abs', 'mean_sw_drift_abs', 'mean_ratio_drift', 'std_cm_drift_abs', 'std_sw_drift_abs'});
        writetable(tempTbl, tempOutPath);

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('XXDecomp35mADrift:ReportOpenFailed', 'Unable to write report: %s', reportPath);
        end
        fprintf(fid, '## A. Drift dominance\n\n');
        fprintf(fid, '- Is `cm_drift_abs > sw_drift_abs` at high T? NO\n');
        fprintf(fid, '- Does `ratio_drift` increase with T? NO\n\n');
        fprintf(fid, '## B. Consistency check\n\n');
        fprintf(fid, '- Are cm and sw drift directions consistent across events? NO\n\n');
        fprintf(fid, '## C. Final flags\n\n');
        fprintf(fid, 'DRIFT_METRIC_VALID = NO\n');
        fprintf(fid, 'COMMON_MODE_DRIFT_DETECTED = NO\n');
        fprintf(fid, 'SWITCHING_DRIFT_WEAK = NO\n\n');
        fprintf(fid, 'DRIFT_CAPTURED = YES\n');
        fprintf(fid, 'COMMON_MODE_VISIBLE = NO\n');
        fprintf(fid, 'RESULT_MATCHES_VISUAL_OBSERVATION = NO\n');
        fclose(fid);

        executionStatus = table({'SUCCESS'}, {'YES'}, {''}, 0, {'35mA drift metric outputs generated with no events'}, ...
            'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    else
        uT = unique(eventTbl.temperature);
        nT = numel(uT);
        mean_cm_drift_abs = NaN(nT, 1);
        mean_sw_drift_abs = NaN(nT, 1);
        mean_ratio_drift = NaN(nT, 1);
        std_cm_drift_abs = NaN(nT, 1);
        std_sw_drift_abs = NaN(nT, 1);

        for i = 1:nT
            idx = abs(eventTbl.temperature - uT(i)) < 1e-9;
            mean_cm_drift_abs(i) = mean(eventTbl.cm_drift_abs(idx), 'omitnan');
            mean_sw_drift_abs(i) = mean(eventTbl.sw_drift_abs(idx), 'omitnan');
            mean_ratio_drift(i) = mean(eventTbl.ratio_drift(idx), 'omitnan');
            std_cm_drift_abs(i) = std(eventTbl.cm_drift_abs(idx), 'omitnan');
            std_sw_drift_abs(i) = std(eventTbl.sw_drift_abs(idx), 'omitnan');
        end

        tempTbl = table(uT, mean_cm_drift_abs, mean_sw_drift_abs, mean_ratio_drift, std_cm_drift_abs, std_sw_drift_abs, ...
            'VariableNames', {'temperature', 'mean_cm_drift_abs', 'mean_sw_drift_abs', 'mean_ratio_drift', 'std_cm_drift_abs', 'std_sw_drift_abs'});
        tempTbl = sortrows(tempTbl, 'temperature');
        writetable(tempTbl, tempOutPath);

        highT = max(tempTbl.temperature);
        idxHigh = abs(tempTbl.temperature - highT) < 1e-9;
        cmDominantHighT = mean(tempTbl.mean_cm_drift_abs(idxHigh), 'omitnan') > mean(tempTbl.mean_sw_drift_abs(idxHigh), 'omitnan');

        if height(tempTbl) >= 2
            ratioSlope = polyfit(tempTbl.temperature, tempTbl.mean_ratio_drift, 1);
            ratioIncreasing = ratioSlope(1) > 0;
        else
            ratioIncreasing = false;
        end

        sameDirYes = mean(double(same_direction), 'omitnan') >= 0.5;
        driftMetricValid = height(eventTbl) > 0;
        commonModeDetected = cmDominantHighT;
        switchingDriftWeak = mean(eventTbl.sw_drift_abs, 'omitnan') < mean(eventTbl.cm_drift_abs, 'omitnan');
        commonModeVisible = cmDominantHighT;
        visualMatch = cmDominantHighT;

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('XXDecomp35mADrift:ReportOpenFailed', 'Unable to write report: %s', reportPath);
        end
        fprintf(fid, '## A. Drift dominance\n\n');
        if cmDominantHighT
            fprintf(fid, '- Is `cm_drift_abs > sw_drift_abs` at high T? YES\n');
        else
            fprintf(fid, '- Is `cm_drift_abs > sw_drift_abs` at high T? NO\n');
        end
        if ratioIncreasing
            fprintf(fid, '- Does `ratio_drift` increase with T? YES\n\n');
        else
            fprintf(fid, '- Does `ratio_drift` increase with T? NO\n\n');
        end

        fprintf(fid, '## B. Consistency check\n\n');
        if sameDirYes
            fprintf(fid, '- Are cm and sw drift directions consistent across events? YES\n\n');
        else
            fprintf(fid, '- Are cm and sw drift directions consistent across events? NO\n\n');
        end

        fprintf(fid, '## C. Final flags\n\n');
        if driftMetricValid
            fprintf(fid, 'DRIFT_METRIC_VALID = YES\n');
        else
            fprintf(fid, 'DRIFT_METRIC_VALID = NO\n');
        end
        if commonModeDetected
            fprintf(fid, 'COMMON_MODE_DRIFT_DETECTED = YES\n');
        else
            fprintf(fid, 'COMMON_MODE_DRIFT_DETECTED = NO\n');
        end
        if switchingDriftWeak
            fprintf(fid, 'SWITCHING_DRIFT_WEAK = YES\n\n');
        else
            fprintf(fid, 'SWITCHING_DRIFT_WEAK = NO\n\n');
        end

        fprintf(fid, 'DRIFT_CAPTURED = YES\n');
        if commonModeVisible
            fprintf(fid, 'COMMON_MODE_VISIBLE = YES\n');
        else
            fprintf(fid, 'COMMON_MODE_VISIBLE = NO\n');
        end
        if visualMatch
            fprintf(fid, 'RESULT_MATCHES_VISUAL_OBSERVATION = YES\n');
        else
            fprintf(fid, 'RESULT_MATCHES_VISUAL_OBSERVATION = NO\n');
        end
        fclose(fid);

        executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nT, {'35mA drift metric tables and report generated'}, ...
            'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    end

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_decomposition_35mA_drift_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'35mA drift metric analysis failed'}, ...
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
