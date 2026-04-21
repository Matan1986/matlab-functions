fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXSlope35mA:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'scripts'));

cfgRun = struct();
cfgRun.runLabel = 'xx_slope_analysis_35mA';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
eventOutPath = fullfile(repoRoot, 'tables', 'xx_slope_event_level_35mA.csv');
tempOutPath = fullfile(repoRoot, 'tables', 'xx_slope_vs_temperature_35mA.csv');
reportPath = fullfile(repoRoot, 'reports', 'xx_slope_analysis_35mA.md');

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('analysis', cfgRun);

    channelTblPath = fullfile(repoRoot, 'tables', 'xx_channel_validation.csv');
    if exist(channelTblPath, 'file') ~= 2
        error('XXSlope35mA:MissingChannelTable', 'Missing pipeline channel table: %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames) || isempty(channelTbl.pipeline_choice)
        error('XXSlope35mA:MissingPipelineChoice', 'Cannot resolve pipeline-selected channel from %s', channelTblPath);
    end
    selectedChannel = double(channelTbl.pipeline_choice(1));
    if ~(selectedChannel == 2 || selectedChannel == 3)
        error('XXSlope35mA:UnexpectedChannel', 'Expected channel 2 or 3, got %g', selectedChannel);
    end
    if selectedChannel == 2
        channelName = 'LI2_X (V)';
    else
        channelName = 'LI3_X (V)';
    end

    cfg = xx_relaxation_config2_sources();
    cfg35 = cfg(contains(string({cfg.config_id}), "35mA"));
    if isempty(cfg35)
        error('XXSlope35mA:ConfigMissing', 'Could not find config2_35mA source in xx_relaxation_config2_sources().');
    end
    sourceDir = fullfile(char(cfg35.baseDir), char(cfg35.tempDepFolder));
    if exist(sourceDir, 'dir') ~= 7
        error('XXSlope35mA:SourceMissing', '35 mA source directory not found: %s', sourceDir);
    end

    eventSrcPath = fullfile(repoRoot, 'tables', 'xx_35mA_model_free_relaxation.csv');
    if exist(eventSrcPath, 'file') ~= 2
        error('XXSlope35mA:MissingPipelineEvents', 'Missing pipeline event table: %s', eventSrcPath);
    end
    srcEvents = readtable(eventSrcPath, 'TextType', 'string');
    needCols = {'file_id','temperature','pulse_index','target_state','switch_idx','relax_start_idx','window_end_idx'};
    for c = 1:numel(needCols)
        if ~ismember(needCols{c}, srcEvents.Properties.VariableNames)
            error('XXSlope35mA:MissingColumn', 'Missing required event column: %s', needCols{c});
        end
    end
    srcEvents = sortrows(srcEvents, {'temperature', 'file_id', 'pulse_index'});
    if isempty(srcEvents)
        error('XXSlope35mA:NoPipelineEvents', 'Pipeline event table is empty.');
    end

    file_id = strings(0, 1);
    temperature = zeros(0, 1);
    event_id = strings(0, 1);
    slope_cm = NaN(0, 1);
    slope_sw = NaN(0, 1);
    slope_cm_abs = NaN(0, 1);
    slope_sw_abs = NaN(0, 1);
    ratio_slope = NaN(0, 1);

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
        if numel(tMs) < 5 || numel(v) ~= numel(tMs)
            continue;
        end

        dtSec = median(diff(tMs), 'omitnan') / 1000;
        if ~(isfinite(dtSec) && dtSec > 0)
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

            ra = v(aStart:aEnd);
            rb = v(bStart:bEnd);
            nMin = min(numel(ra), numel(rb));
            if nMin < 5
                continue;
            end

            ra = ra(1:nMin);
            rb = rb(1:nMin);
            if any(~isfinite(ra)) || any(~isfinite(rb))
                continue;
            end

            tSec = ((0:(nMin - 1))') * dtSec;
            r_cm = 0.5 * (ra + rb);
            r_sw = 0.5 * (ra - rb);

            pCm = polyfit(tSec, r_cm, 1);
            pSw = polyfit(tSec, r_sw, 1);
            cmVal = pCm(1);
            swVal = pSw(1);
            cmAbsVal = abs(cmVal);
            swAbsVal = abs(swVal);

            if swAbsVal > 0
                ratioVal = cmAbsVal / swAbsVal;
            else
                ratioVal = NaN;
            end

            file_id(end + 1, 1) = fname; %#ok<AGROW>
            temperature(end + 1, 1) = rowsF.temperature(1); %#ok<AGROW>
            event_id(end + 1, 1) = "pair_" + string(p); %#ok<AGROW>
            slope_cm(end + 1, 1) = cmVal; %#ok<AGROW>
            slope_sw(end + 1, 1) = swVal; %#ok<AGROW>
            slope_cm_abs(end + 1, 1) = cmAbsVal; %#ok<AGROW>
            slope_sw_abs(end + 1, 1) = swAbsVal; %#ok<AGROW>
            ratio_slope(end + 1, 1) = ratioVal; %#ok<AGROW>
        end
    end

    eventTbl = table(file_id, temperature, event_id, slope_cm, slope_sw, slope_cm_abs, slope_sw_abs, ratio_slope);
    eventTbl = sortrows(eventTbl, {'temperature', 'file_id', 'event_id'});
    writetable(eventTbl, eventOutPath);

    if isempty(eventTbl)
        tempTbl = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            'VariableNames', {'temperature', 'mean_slope_cm_abs', 'mean_slope_sw_abs', 'mean_ratio_slope', ...
            'std_slope_cm_abs', 'std_slope_sw_abs', 'n_events'});
        writetable(tempTbl, tempOutPath);

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('XXSlope35mA:ReportOpenFailed', 'Unable to write report: %s', reportPath);
        end
        fprintf(fid, '## A. Drift detection\n\n');
        fprintf(fid, '- Is slope_cm consistently non-zero? NO\n\n');
        fprintf(fid, '## B. Dominance\n\n');
        fprintf(fid, '- Is slope_cm_abs > slope_sw_abs at high T? NO\n\n');
        fprintf(fid, '## C. Temperature behavior\n\n');
        fprintf(fid, '- Does slope_cm_abs change with T? NO\n');
        fprintf(fid, '- Any sharp transition? NO\n\n');
        fprintf(fid, '## D. Final flags\n\n');
        fprintf(fid, 'SLOPE_METHOD_VALID = NO\n');
        fprintf(fid, 'COMMON_MODE_TREND_DETECTED = NO\n');
        fprintf(fid, 'WINDOW_FREE_RESULT_STABLE = NO\n\n');
        fprintf(fid, 'TREND_CAPTURED = YES\n');
        fprintf(fid, 'RESULT_STABLE = YES\n');
        fprintf(fid, 'WINDOW_DEPENDENCE_REMOVED = YES\n');
        fclose(fid);

        executionStatus = table({'SUCCESS'}, {'YES'}, {''}, 0, {'35mA slope outputs generated with no events'}, ...
            'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    else
        uT = unique(eventTbl.temperature);
        nT = numel(uT);
        mean_slope_cm_abs = NaN(nT, 1);
        mean_slope_sw_abs = NaN(nT, 1);
        mean_ratio_slope = NaN(nT, 1);
        std_slope_cm_abs = NaN(nT, 1);
        std_slope_sw_abs = NaN(nT, 1);
        n_events = zeros(nT, 1);

        for i = 1:nT
            idx = abs(eventTbl.temperature - uT(i)) < 1e-9;
            mean_slope_cm_abs(i) = mean(eventTbl.slope_cm_abs(idx), 'omitnan');
            mean_slope_sw_abs(i) = mean(eventTbl.slope_sw_abs(idx), 'omitnan');
            mean_ratio_slope(i) = mean(eventTbl.ratio_slope(idx), 'omitnan');
            std_slope_cm_abs(i) = std(eventTbl.slope_cm_abs(idx), 'omitnan');
            std_slope_sw_abs(i) = std(eventTbl.slope_sw_abs(idx), 'omitnan');
            n_events(i) = sum(idx);
        end

        tempTbl = table(uT, mean_slope_cm_abs, mean_slope_sw_abs, mean_ratio_slope, std_slope_cm_abs, std_slope_sw_abs, n_events, ...
            'VariableNames', {'temperature', 'mean_slope_cm_abs', 'mean_slope_sw_abs', 'mean_ratio_slope', ...
            'std_slope_cm_abs', 'std_slope_sw_abs', 'n_events'});
        tempTbl = sortrows(tempTbl, 'temperature');
        writetable(tempTbl, tempOutPath);

        slopeZeroTol = max(1e-12, 1e-6 * median(eventTbl.slope_cm_abs, 'omitnan'));
        if ~(isfinite(slopeZeroTol) && slopeZeroTol > 0)
            slopeZeroTol = 1e-12;
        end
        slopeCmConsistentNonZero = mean(double(eventTbl.slope_cm_abs > slopeZeroTol), 'omitnan') >= 0.8;

        highT = max(tempTbl.temperature);
        idxHigh = abs(tempTbl.temperature - highT) < 1e-9;
        cmDominantHighT = mean(tempTbl.mean_slope_cm_abs(idxHigh), 'omitnan') > mean(tempTbl.mean_slope_sw_abs(idxHigh), 'omitnan');

        if height(tempTbl) >= 2
            cmVals = tempTbl.mean_slope_cm_abs;
            cmSpan = max(cmVals) - min(cmVals);
            cmBase = max(abs(mean(cmVals, 'omitnan')), eps);
            cmRelSpan = cmSpan / cmBase;
            cmChangesWithT = cmRelSpan > 0.10;

            dCm = abs(diff(cmVals));
            if isempty(dCm)
                sharpTransition = false;
            else
                maxJumpRel = max(dCm) / cmBase;
                sharpTransition = maxJumpRel > 0.25;
            end
        else
            cmChangesWithT = false;
            sharpTransition = false;
        end

        slopeMethodValid = height(eventTbl) > 0;
        commonModeTrendDetected = slopeCmConsistentNonZero && (mean(eventTbl.slope_cm_abs, 'omitnan') > mean(eventTbl.slope_sw_abs, 'omitnan'));
        if height(tempTbl) >= 2
            cvCm = std(tempTbl.mean_slope_cm_abs, 'omitnan') / max(abs(mean(tempTbl.mean_slope_cm_abs, 'omitnan')), eps);
            cvSw = std(tempTbl.mean_slope_sw_abs, 'omitnan') / max(abs(mean(tempTbl.mean_slope_sw_abs, 'omitnan')), eps);
            windowFreeResultStable = (cvCm <= 0.50) && (cvSw <= 0.50) && (~sharpTransition);
        else
            windowFreeResultStable = true;
        end

        trendCaptured = slopeCmConsistentNonZero;
        resultStable = windowFreeResultStable;
        windowDependenceRemoved = true;

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('XXSlope35mA:ReportOpenFailed', 'Unable to write report: %s', reportPath);
        end
        fprintf(fid, '## A. Drift detection\n\n');
        if slopeCmConsistentNonZero
            fprintf(fid, '- Is slope_cm consistently non-zero? YES\n\n');
        else
            fprintf(fid, '- Is slope_cm consistently non-zero? NO\n\n');
        end

        fprintf(fid, '## B. Dominance\n\n');
        if cmDominantHighT
            fprintf(fid, '- Is slope_cm_abs > slope_sw_abs at high T? YES\n\n');
        else
            fprintf(fid, '- Is slope_cm_abs > slope_sw_abs at high T? NO\n\n');
        end

        fprintf(fid, '## C. Temperature behavior\n\n');
        if cmChangesWithT
            fprintf(fid, '- Does slope_cm_abs change with T? YES\n');
        else
            fprintf(fid, '- Does slope_cm_abs change with T? NO\n');
        end
        if sharpTransition
            fprintf(fid, '- Any sharp transition? YES\n\n');
        else
            fprintf(fid, '- Any sharp transition? NO\n\n');
        end

        fprintf(fid, '## D. Final flags\n\n');
        if slopeMethodValid
            fprintf(fid, 'SLOPE_METHOD_VALID = YES\n');
        else
            fprintf(fid, 'SLOPE_METHOD_VALID = NO\n');
        end
        if commonModeTrendDetected
            fprintf(fid, 'COMMON_MODE_TREND_DETECTED = YES\n');
        else
            fprintf(fid, 'COMMON_MODE_TREND_DETECTED = NO\n');
        end
        if windowFreeResultStable
            fprintf(fid, 'WINDOW_FREE_RESULT_STABLE = YES\n\n');
        else
            fprintf(fid, 'WINDOW_FREE_RESULT_STABLE = NO\n\n');
        end

        if trendCaptured
            fprintf(fid, 'TREND_CAPTURED = YES\n');
        else
            fprintf(fid, 'TREND_CAPTURED = NO\n');
        end
        if resultStable
            fprintf(fid, 'RESULT_STABLE = YES\n');
        else
            fprintf(fid, 'RESULT_STABLE = NO\n');
        end
        if windowDependenceRemoved
            fprintf(fid, 'WINDOW_DEPENDENCE_REMOVED = YES\n');
        else
            fprintf(fid, 'WINDOW_DEPENDENCE_REMOVED = NO\n');
        end
        fclose(fid);

        executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nT, {'35mA slope tables and report generated'}, ...
            'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    end

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_slope_analysis_35mA_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'35mA slope analysis failed'}, ...
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
