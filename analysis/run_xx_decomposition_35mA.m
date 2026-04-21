fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXDecomp35mA:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'scripts'));

cfgRun = struct();
cfgRun.runLabel = 'xx_decomposition_35mA';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
eventOutPath = fullfile(repoRoot, 'tables', 'xx_decomposition_event_level_35mA.csv');
tempOutPath = fullfile(repoRoot, 'tables', 'xx_decomposition_vs_temperature_35mA.csv');
reportPath = fullfile(repoRoot, 'reports', 'xx_decomposition_35mA.md');

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('analysis', cfgRun);

    channelTblPath = fullfile(repoRoot, 'tables', 'xx_channel_validation.csv');
    if exist(channelTblPath, 'file') ~= 2
        error('XXDecomp35mA:MissingChannelTable', 'Missing pipeline channel table: %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames) || isempty(channelTbl.pipeline_choice)
        error('XXDecomp35mA:MissingPipelineChoice', 'Cannot resolve pipeline-selected channel from %s', channelTblPath);
    end
    selectedChannel = double(channelTbl.pipeline_choice(1));
    if ~(selectedChannel == 2 || selectedChannel == 3)
        error('XXDecomp35mA:UnexpectedChannel', 'Expected channel 2 or 3, got %g', selectedChannel);
    end

    cfg = xx_relaxation_config2_sources();
    cfg35 = cfg(contains(string({cfg.config_id}), "35mA"));
    if isempty(cfg35)
        error('XXDecomp35mA:ConfigMissing', 'Could not find config2_35mA source in xx_relaxation_config2_sources().');
    end

    sourceDir = fullfile(char(cfg35.baseDir), char(cfg35.tempDepFolder));
    if exist(sourceDir, 'dir') ~= 7
        error('XXDecomp35mA:SourceMissing', '35 mA source directory not found: %s', sourceDir);
    end

    files = dir(fullfile(sourceDir, '*.dat'));
    if isempty(files)
        error('XXDecomp35mA:NoFiles', 'No .dat files found under %s', sourceDir);
    end

    file_id = strings(0, 1);
    temperature = zeros(0, 1);
    event_id = strings(0, 1);
    cm_range = NaN(0, 1);
    cm_std = NaN(0, 1);
    sw_range = NaN(0, 1);
    sw_std = NaN(0, 1);
    ratio_cm_to_sw = NaN(0, 1);
    same_direction = false(0, 1);

    knownSpacingSec = 15;
    nFilesUsed = 0;

    for f = 1:numel(files)
        fname = string(files(f).name);
        tokT = regexp(fname, '_T([0-9]+(?:\.[0-9]+)?)_', 'tokens', 'once');
        if isempty(tokT)
            continue;
        end
        tK = str2double(tokT{1});

        rawPath = fullfile(sourceDir, char(fname));
        data = readtable(rawPath, 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
        if ~ismember('Time (ms)', data.Properties.VariableNames)
            continue;
        end
        if selectedChannel == 2
            chanName = 'LI2_X (V)';
        else
            chanName = 'LI3_X (V)';
        end
        if ~ismember(chanName, data.Properties.VariableNames)
            continue;
        end

        tMs = data{:, 'Time (ms)'};
        vRaw = data{:, chanName};
        if numel(tMs) < 50 || numel(vRaw) ~= numel(tMs)
            continue;
        end

        tSec = (tMs - tMs(1)) ./ 1000;
        dt = median(diff(tSec), 'omitnan');
        if ~isfinite(dt) || dt <= 0
            continue;
        end

        filtN = max(5, round(0.05 / dt));
        v = movmean(vRaw, filtN, 'omitnan');
        absDvDt = abs(gradient(v, dt));

        q90 = quantile(absDvDt, 0.90);
        q99 = quantile(absDvDt, 0.99);
        thr = max(q99, q90 + 3 * mad(absDvDt, 1));
        minDist = max(round((0.6 * knownSpacingSec) / dt), 5);
        [~, pulseIdx] = findpeaks(absDvDt, 'MinPeakHeight', thr, 'MinPeakDistance', minDist);
        if numel(pulseIdx) < 4
            thr2 = quantile(absDvDt, 0.995);
            [~, pulseIdx] = findpeaks(absDvDt, 'MinPeakHeight', thr2, 'MinPeakDistance', max(round((0.4 * knownSpacingSec) / dt), 3));
        end
        if isempty(pulseIdx)
            continue;
        end

        meanPeriod = knownSpacingSec;
        if numel(pulseIdx) > 1
            meanPeriod = median(diff(tSec(pulseIdx)), 'omitnan');
        end
        W = max(round(0.12 * meanPeriod / dt), 8);
        stableN = max(round(W / 3), 5);
        slopeFloor = median(absDvDt, 'omitnan') + 1.5 * mad(absDvDt, 1);
        rollStd = movstd(v, W, 0, 'omitnan');
        stdFloor = median(rollStd, 'omitnan') + 2.0 * mad(rollStd, 1);
        if ~isfinite(stdFloor) || stdFloor <= 0
            stdFloor = std(v, 'omitnan') * 0.1;
        end

        pulseRows = struct('target_state', {}, 'switch_idx', {}, 'relax_start_idx', {}, ...
            'window_end_idx', {}, 't_rel', {}, 'r_trace', {});
        for p = 1:numel(pulseIdx)
            thisPeak = pulseIdx(p);
            nextPulse = numel(v);
            if p < numel(pulseIdx)
                nextPulse = pulseIdx(p + 1) - 1;
            end

            pulseEnd = thisPeak;
            while pulseEnd < nextPulse
                if absDvDt(pulseEnd) < 1.2 * slopeFloor
                    break;
                end
                pulseEnd = pulseEnd + 1;
            end
            pulseEnd = min(pulseEnd, nextPulse);

            relaxStart = pulseEnd;
            need = 4;
            while relaxStart + need < nextPulse
                if all(absDvDt(relaxStart:(relaxStart + need - 1)) < 1.1 * slopeFloor)
                    break;
                end
                relaxStart = relaxStart + 1;
            end
            relaxStart = min(relaxStart, nextPulse);

            if relaxStart + W + stableN > nextPulse
                continue;
            end

            stable = false(nextPulse, 1);
            for k = relaxStart:(nextPulse - W + 1)
                seg = v(k:(k + W - 1));
                slopeVal = mean(absDvDt(k:(k + W - 1)), 'omitnan');
                stable(k) = (slopeVal < slopeFloor) && (std(seg, 'omitnan') < stdFloor);
            end

            runLen = 0;
            plateauStart = NaN;
            for k = relaxStart:(nextPulse - W + 1)
                if stable(k)
                    runLen = runLen + 1;
                    if runLen >= stableN
                        plateauStart = k - stableN + 1;
                        break;
                    end
                else
                    runLen = 0;
                end
            end
            if ~isfinite(plateauStart)
                continue;
            end

            if mod(p, 2) == 1
                stateNow = "A";
            else
                stateNow = "B";
            end

            segIdx = relaxStart:nextPulse;
            tRel = tSec(segIdx) - tSec(thisPeak);
            rTrace = v(segIdx);

            pulseRows(end + 1).target_state = stateNow; %#ok<AGROW>
            pulseRows(end).switch_idx = thisPeak;
            pulseRows(end).relax_start_idx = relaxStart;
            pulseRows(end).window_end_idx = nextPulse;
            pulseRows(end).t_rel = tRel;
            pulseRows(end).r_trace = rTrace;
        end

        if isempty(pulseRows)
            continue;
        end
        nFilesUsed = nFilesUsed + 1;

        aIdx = find(strcmp({pulseRows.target_state}, 'A'));
        bIdx = find(strcmp({pulseRows.target_state}, 'B'));
        nPairs = min(numel(aIdx), numel(bIdx));
        for pp = 1:nPairs
            ra = pulseRows(aIdx(pp)).r_trace(:);
            rb = pulseRows(bIdx(pp)).r_trace(:);
            ta = pulseRows(aIdx(pp)).t_rel(:);
            tb = pulseRows(bIdx(pp)).t_rel(:);
            nMin = min([numel(ra), numel(rb), numel(ta), numel(tb)]);
            if nMin < 5
                continue;
            end

            ra = ra(1:nMin);
            rb = rb(1:nMin);
            ta = ta(1:nMin);
            tb = tb(1:nMin);
            if any(~isfinite(ra)) || any(~isfinite(rb)) || any(~isfinite(ta)) || any(~isfinite(tb))
                continue;
            end

            r_cm = 0.5 * (ra + rb);
            r_sw = 0.5 * (ra - rb);

            cmRng = max(r_cm) - min(r_cm);
            swRng = max(r_sw) - min(r_sw);
            if swRng > 0
                ratioVal = cmRng / swRng;
            else
                ratioVal = NaN;
            end

            file_id(end + 1, 1) = fname; %#ok<AGROW>
            temperature(end + 1, 1) = tK; %#ok<AGROW>
            event_id(end + 1, 1) = "pair_" + string(pp); %#ok<AGROW>
            cm_range(end + 1, 1) = cmRng; %#ok<AGROW>
            cm_std(end + 1, 1) = std(r_cm, 'omitnan'); %#ok<AGROW>
            sw_range(end + 1, 1) = swRng; %#ok<AGROW>
            sw_std(end + 1, 1) = std(r_sw, 'omitnan'); %#ok<AGROW>
            ratio_cm_to_sw(end + 1, 1) = ratioVal; %#ok<AGROW>
            same_direction(end + 1, 1) = ((ra(end) - ra(1)) * (rb(end) - rb(1))) > 0; %#ok<AGROW>
        end
    end

    eventTbl = table(file_id, temperature, event_id, cm_range, cm_std, sw_range, sw_std, ratio_cm_to_sw);
    eventTbl = sortrows(eventTbl, {'temperature', 'file_id', 'event_id'});
    writetable(eventTbl, eventOutPath);

    if isempty(eventTbl)
        tempTbl = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            'VariableNames', {'temperature', 'mean_cm_range', 'mean_sw_range', 'mean_ratio', 'std_cm_range', 'std_sw_range', 'n_events'});
        writetable(tempTbl, tempOutPath);

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('XXDecomp35mA:ReportOpenFailed', 'Unable to write report: %s', reportPath);
        end
        fprintf(fid, '# XX Two-State Decomposition (35 mA)\n\n');
        fprintf(fid, '## A. Data coverage\n\n');
        fprintf(fid, '- number of files used: 0\n');
        fprintf(fid, '- number of events: 0\n');
        fprintf(fid, '- temperature range: N/A\n\n');
        fprintf(fid, '## B. Observed trends (descriptive only)\n\n');
        fprintf(fid, '- Does `cm_range` increase with temperature? NO\n');
        fprintf(fid, '- Does `sw_range` decrease or stay constant? NO\n');
        fprintf(fid, '- Does `ratio_cm_to_sw` increase? NO\n\n');
        fprintf(fid, '## C. Signal structure sanity\n\n');
        fprintf(fid, '- Are both R_A and R_B moving in same direction? NO\n');
        fprintf(fid, '- Is R_sw smaller than R_cm at high T? NO\n\n');
        fprintf(fid, '## D. Final flags\n\n');
        fprintf(fid, 'DECOMPOSITION_SUCCESS = NO\n');
        fprintf(fid, 'COMMON_MODE_DOMINANT_AT_HIGH_T = NO\n');
        fprintf(fid, 'SWITCHING_VISIBLE_AT_LOW_T = NO\n\n');
        fprintf(fid, 'EVENTS_EXTRACTED = NO\n');
        fprintf(fid, 'DECOMPOSITION_VALID = NO\n');
        fprintf(fid, 'TEMPERATURE_TRENDS_VISIBLE = NO\n');
        fclose(fid);

        executionStatus = table({'SUCCESS'}, {'YES'}, {''}, 0, {'No events extracted for 35mA decomposition'}, ...
            'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    else
        uT = unique(eventTbl.temperature);
        nT = numel(uT);
        mean_cm_range = NaN(nT, 1);
        mean_sw_range = NaN(nT, 1);
        mean_ratio = NaN(nT, 1);
        std_cm_range = NaN(nT, 1);
        std_sw_range = NaN(nT, 1);
        n_events = zeros(nT, 1);

        for i = 1:nT
            idx = abs(eventTbl.temperature - uT(i)) < 1e-9;
            mean_cm_range(i) = mean(eventTbl.cm_range(idx), 'omitnan');
            mean_sw_range(i) = mean(eventTbl.sw_range(idx), 'omitnan');
            mean_ratio(i) = mean(eventTbl.ratio_cm_to_sw(idx), 'omitnan');
            std_cm_range(i) = std(eventTbl.cm_range(idx), 'omitnan');
            std_sw_range(i) = std(eventTbl.sw_range(idx), 'omitnan');
            n_events(i) = sum(idx);
        end

        tempTbl = table(uT, mean_cm_range, mean_sw_range, mean_ratio, std_cm_range, std_sw_range, n_events, ...
            'VariableNames', {'temperature', 'mean_cm_range', 'mean_sw_range', 'mean_ratio', 'std_cm_range', 'std_sw_range', 'n_events'});
        tempTbl = sortrows(tempTbl, 'temperature');
        writetable(tempTbl, tempOutPath);

        if height(tempTbl) >= 2
            cmSlope = polyfit(tempTbl.temperature, tempTbl.mean_cm_range, 1);
            swSlope = polyfit(tempTbl.temperature, tempTbl.mean_sw_range, 1);
            ratioSlope = polyfit(tempTbl.temperature, tempTbl.mean_ratio, 1);
            cmIncreasing = cmSlope(1) > 0;
            swDecreaseOrConst = swSlope(1) <= 0;
            ratioIncreasing = ratioSlope(1) > 0;
        else
            cmIncreasing = false;
            swDecreaseOrConst = false;
            ratioIncreasing = false;
        end

        sameDirYes = mean(double(same_direction)) >= 0.5;
        highT = max(tempTbl.temperature);
        idxHigh = abs(tempTbl.temperature - highT) < 1e-9;
        swSmallerAtHighT = mean(tempTbl.mean_sw_range(idxHigh), 'omitnan') < mean(tempTbl.mean_cm_range(idxHigh), 'omitnan');

        lowT = min(tempTbl.temperature);
        idxLow = abs(tempTbl.temperature - lowT) < 1e-9;
        switchingVisibleLowT = mean(tempTbl.mean_sw_range(idxLow), 'omitnan') > 0;

        decompositionSuccess = height(eventTbl) > 0;
        commonModeDominantHighT = swSmallerAtHighT;
        temperatureTrendsVisible = cmIncreasing || swDecreaseOrConst || ratioIncreasing;

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('XXDecomp35mA:ReportOpenFailed', 'Unable to write report: %s', reportPath);
        end

        fprintf(fid, '# XX Two-State Decomposition (35 mA)\n\n');
        fprintf(fid, '## A. Data coverage\n\n');
        fprintf(fid, '- number of files used: %d\n', nFilesUsed);
        fprintf(fid, '- number of events: %d\n', height(eventTbl));
        fprintf(fid, '- temperature range: %.2f to %.2f K\n\n', min(eventTbl.temperature), max(eventTbl.temperature));

        fprintf(fid, '## B. Observed trends (descriptive only)\n\n');
        if cmIncreasing
            fprintf(fid, '- Does `cm_range` increase with temperature? YES\n');
        else
            fprintf(fid, '- Does `cm_range` increase with temperature? NO\n');
        end
        if swDecreaseOrConst
            fprintf(fid, '- Does `sw_range` decrease or stay constant? YES\n');
        else
            fprintf(fid, '- Does `sw_range` decrease or stay constant? NO\n');
        end
        if ratioIncreasing
            fprintf(fid, '- Does `ratio_cm_to_sw` increase? YES\n\n');
        else
            fprintf(fid, '- Does `ratio_cm_to_sw` increase? NO\n\n');
        end

        fprintf(fid, '## C. Signal structure sanity\n\n');
        if sameDirYes
            fprintf(fid, '- Are both R_A and R_B moving in same direction? YES\n');
        else
            fprintf(fid, '- Are both R_A and R_B moving in same direction? NO\n');
        end
        if swSmallerAtHighT
            fprintf(fid, '- Is R_sw smaller than R_cm at high T? YES\n\n');
        else
            fprintf(fid, '- Is R_sw smaller than R_cm at high T? NO\n\n');
        end

        fprintf(fid, '## D. Final flags\n\n');
        if decompositionSuccess
            fprintf(fid, 'DECOMPOSITION_SUCCESS = YES\n');
        else
            fprintf(fid, 'DECOMPOSITION_SUCCESS = NO\n');
        end
        if commonModeDominantHighT
            fprintf(fid, 'COMMON_MODE_DOMINANT_AT_HIGH_T = YES\n');
        else
            fprintf(fid, 'COMMON_MODE_DOMINANT_AT_HIGH_T = NO\n');
        end
        if switchingVisibleLowT
            fprintf(fid, 'SWITCHING_VISIBLE_AT_LOW_T = YES\n\n');
        else
            fprintf(fid, 'SWITCHING_VISIBLE_AT_LOW_T = NO\n\n');
        end

        if height(eventTbl) > 0
            fprintf(fid, 'EVENTS_EXTRACTED = YES\n');
        else
            fprintf(fid, 'EVENTS_EXTRACTED = NO\n');
        end
        if decompositionSuccess
            fprintf(fid, 'DECOMPOSITION_VALID = YES\n');
        else
            fprintf(fid, 'DECOMPOSITION_VALID = NO\n');
        end
        if temperatureTrendsVisible
            fprintf(fid, 'TEMPERATURE_TRENDS_VISIBLE = YES\n');
        else
            fprintf(fid, 'TEMPERATURE_TRENDS_VISIBLE = NO\n');
        end
        fclose(fid);

        executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nT, {'35mA decomposition tables and report generated'}, ...
            'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    end

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_decomposition_35mA_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'35mA decomposition failed'}, ...
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
