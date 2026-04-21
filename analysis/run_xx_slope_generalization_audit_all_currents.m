fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXSlopeGeneralization:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'scripts'));

cfgRun = struct();
cfgRun.runLabel = 'xx_slope_generalization_audit_all_currents';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
inputPath = fullfile(repoRoot, 'tables', 'xx_relaxation_morphology_event_level_config2.csv');
eventOutPath = fullfile(repoRoot, 'tables', 'xx_slope_event_level_all_currents_aligned.csv');
tempOutPath = fullfile(repoRoot, 'tables', 'xx_slope_vs_temperature_all_currents_aligned.csv');
summaryOutPath = fullfile(repoRoot, 'tables', 'xx_slope_generalization_summary.csv');
reportPath = fullfile(repoRoot, 'reports', 'xx_slope_generalization_final.md');

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('analysis', cfgRun);

    if exist(fileparts(eventOutPath), 'dir') ~= 7
        mkdir(fileparts(eventOutPath));
    end
    if exist(fullfile(repoRoot, 'figures'), 'dir') ~= 7
        mkdir(fullfile(repoRoot, 'figures'));
    end
    if exist(fileparts(reportPath), 'dir') ~= 7
        mkdir(fileparts(reportPath));
    end

    if exist(inputPath, 'file') ~= 2
        error('XXSlopeGeneralization:MissingInput', 'Missing canonical input table: %s', inputPath);
    end

    channelTblPath = fullfile(repoRoot, 'tables', 'xx_channel_validation.csv');
    if exist(channelTblPath, 'file') ~= 2
        error('XXSlopeGeneralization:MissingChannelTable', 'Missing channel validation table: %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames) || isempty(channelTbl.pipeline_choice)
        error('XXSlopeGeneralization:MissingPipelineChoice', 'Cannot resolve selected channel in %s', channelTblPath);
    end
    selectedChannel = double(channelTbl.pipeline_choice(1));
    if selectedChannel == 2
        channelName = 'LI2_X (V)';
    elseif selectedChannel == 3
        channelName = 'LI3_X (V)';
    else
        error('XXSlopeGeneralization:UnexpectedChannel', 'Expected pipeline channel 2/3, got %g', selectedChannel);
    end

    events = readtable(inputPath, 'TextType', 'string');
    requiredCols = {'file_id','temperature','pulse_index','target_state','relax_start_idx','switch_idx','window_end_idx','current_mA'};
    for rc = 1:numel(requiredCols)
        if ~ismember(requiredCols{rc}, events.Properties.VariableNames)
            error('XXSlopeGeneralization:MissingColumn', 'Input table missing required column: %s', requiredCols{rc});
        end
    end

    srcCfg = xx_relaxation_config2_sources();
    currents = [25; 30; 35];

    current_mA_event = zeros(0, 1);
    file_id_event = strings(0, 1);
    temperature_event = zeros(0, 1);
    event_id_event = strings(0, 1);
    slope_cm_event = NaN(0, 1);
    slope_sw_event = NaN(0, 1);
    alignment_anchor_event = strings(0, 1);
    alignment_ok_event = false(0, 1);

    current_mA_temp = zeros(0, 1);
    temperature_temp = zeros(0, 1);
    mean_slope_cm_temp = NaN(0, 1);
    std_slope_cm_temp = NaN(0, 1);
    frac_positive_cm_temp = NaN(0, 1);
    frac_negative_cm_temp = NaN(0, 1);
    mean_slope_sw_temp = NaN(0, 1);
    std_slope_sw_temp = NaN(0, 1);
    frac_positive_sw_temp = NaN(0, 1);
    frac_negative_sw_temp = NaN(0, 1);
    n_events_temp = zeros(0, 1);

    n_files_summary = zeros(numel(currents), 1);
    n_event_pairs_summary = zeros(numel(currents), 1);
    n_valid_slopes_summary = zeros(numel(currents), 1);
    n_alignment_failures_summary = zeros(numel(currents), 1);
    current_alignment_ok_summary = strings(numel(currents), 1);
    current_consistency_defined_summary = strings(numel(currents), 1);
    dominant_sign_cm_summary = strings(numel(currents), 1);

    for ci = 1:numel(currents)
        thisCurrent = currents(ci);
        thisConfig = "config2_" + string(thisCurrent) + "mA";
        cfgRows = srcCfg(contains(string({srcCfg.config_id}), thisConfig));
        if isempty(cfgRows)
            error('XXSlopeGeneralization:MissingSourceConfig', 'Missing source configuration for %s', thisConfig);
        end
        sourceDir = fullfile(char(cfgRows(1).baseDir), char(cfgRows(1).tempDepFolder));
        if exist(sourceDir, 'dir') ~= 7
            error('XXSlopeGeneralization:MissingSourceDir', 'Source directory missing: %s', sourceDir);
        end

        rowsCurrent = events(events.current_mA == thisCurrent, :);
        if isempty(rowsCurrent)
            error('XXSlopeGeneralization:NoEventsForCurrent', 'No canonical events found for current %dmA', thisCurrent);
        end
        rowsCurrent = sortrows(rowsCurrent, {'temperature','file_id','pulse_index','target_state'});
        uFiles = unique(rowsCurrent.file_id);
        n_files_summary(ci) = numel(uFiles);

        pairCounterCurrent = 0;
        validSlopeCounterCurrent = 0;
        alignFailCounterCurrent = 0;

        for fi = 1:numel(uFiles)
            thisFile = uFiles(fi);
            rowsFile = rowsCurrent(rowsCurrent.file_id == thisFile, :);

            rawPath = fullfile(sourceDir, char(thisFile));
            if exist(rawPath, 'file') ~= 2
                error('XXSlopeGeneralization:MissingRawFile', 'Raw source file missing: %s', rawPath);
            end

            rawTbl = readtable(rawPath, 'Delimiter', '\t', 'VariableNamingRule', 'preserve');
            if ~ismember('Time (ms)', rawTbl.Properties.VariableNames) || ~ismember(channelName, rawTbl.Properties.VariableNames)
                error('XXSlopeGeneralization:MissingRawColumns', 'Raw file %s is missing Time/channel columns', rawPath);
            end

            tSecGlobal = rawTbl{:, 'Time (ms)'} ./ 1000;
            vRaw = rawTbl{:, channelName};
            if numel(tSecGlobal) ~= numel(vRaw) || numel(tSecGlobal) < 5
                error('XXSlopeGeneralization:InvalidRawTrace', 'Raw file %s has invalid time/trace length', rawPath);
            end

            rowsA = sortrows(rowsFile(rowsFile.target_state == "A", :), {'pulse_index'});
            rowsB = sortrows(rowsFile(rowsFile.target_state == "B", :), {'pulse_index'});
            nPairs = min(height(rowsA), height(rowsB));
            for p = 1:nPairs
                pairCounterCurrent = pairCounterCurrent + 1;

                aStart = rowsA.relax_start_idx(p);
                bStart = rowsB.relax_start_idx(p);
                aEnd = rowsA.window_end_idx(p);
                bEnd = rowsB.window_end_idx(p);
                aAnchor = rowsA.switch_idx(p);
                bAnchor = rowsB.switch_idx(p);

                tempThis = rowsA.temperature(p);
                if ~isfinite(tempThis) && isfinite(rowsB.temperature(p))
                    tempThis = rowsB.temperature(p);
                end

                slopeCmVal = NaN;
                slopeSwVal = NaN;
                anchorTxt = "switch_idx";
                alignOk = false;

                validBounds = isfinite(aStart) && isfinite(aEnd) && isfinite(bStart) && isfinite(bEnd);
                validAnchor = isfinite(aAnchor) && isfinite(bAnchor);
                if validBounds && validAnchor
                    aStart = max(1, round(aStart));
                    bStart = max(1, round(bStart));
                    aEnd = min(numel(vRaw), round(aEnd));
                    bEnd = min(numel(vRaw), round(bEnd));
                    aAnchor = max(1, min(numel(vRaw), round(aAnchor)));
                    bAnchor = max(1, min(numel(vRaw), round(bAnchor)));

                    if aEnd > aStart && bEnd > bStart
                        idxA = aStart:aEnd;
                        idxB = bStart:bEnd;
                        rA = vRaw(idxA);
                        rB = vRaw(idxB);
                        nMin = min(numel(rA), numel(rB));
                        if nMin >= 5
                            rA = rA(1:nMin);
                            rB = rB(1:nMin);
                            if all(isfinite(rA)) && all(isfinite(rB))
                                rCm = 0.5 * (rA + rB);
                                rSw = 0.5 * (rA - rB);

                                tA = tSecGlobal(idxA) - tSecGlobal(aAnchor);
                                tB = tSecGlobal(idxB) - tSecGlobal(bAnchor);
                                tA = tA(1:nMin);
                                tB = tB(1:nMin);

                                if all(isfinite(tA)) && all(isfinite(tB))
                                    tRel = 0.5 * (tA + tB);
                                    if numel(unique(tRel)) >= 2
                                        pCm = polyfit(tRel, rCm, 1);
                                        pSw = polyfit(tRel, rSw, 1);
                                        slopeCmVal = pCm(1);
                                        slopeSwVal = pSw(1);
                                        alignOk = true;
                                        validSlopeCounterCurrent = validSlopeCounterCurrent + 1;
                                    else
                                        anchorTxt = "switch_idx_degenerate";
                                        alignFailCounterCurrent = alignFailCounterCurrent + 1;
                                    end
                                else
                                    anchorTxt = "switch_idx_nonfinite_trel";
                                    alignFailCounterCurrent = alignFailCounterCurrent + 1;
                                end
                            else
                                anchorTxt = "switch_idx_nonfinite_signal";
                                alignFailCounterCurrent = alignFailCounterCurrent + 1;
                            end
                        else
                            anchorTxt = "switch_idx_short_window";
                            alignFailCounterCurrent = alignFailCounterCurrent + 1;
                        end
                    else
                        anchorTxt = "switch_idx_invalid_window";
                        alignFailCounterCurrent = alignFailCounterCurrent + 1;
                    end
                else
                    anchorTxt = "switch_idx_missing";
                    alignFailCounterCurrent = alignFailCounterCurrent + 1;
                end

                current_mA_event(end + 1, 1) = thisCurrent; %#ok<AGROW>
                file_id_event(end + 1, 1) = thisFile; %#ok<AGROW>
                temperature_event(end + 1, 1) = tempThis; %#ok<AGROW>
                event_id_event(end + 1, 1) = "pair_" + string(p); %#ok<AGROW>
                slope_cm_event(end + 1, 1) = slopeCmVal; %#ok<AGROW>
                slope_sw_event(end + 1, 1) = slopeSwVal; %#ok<AGROW>
                alignment_anchor_event(end + 1, 1) = anchorTxt; %#ok<AGROW>
                alignment_ok_event(end + 1, 1) = alignOk; %#ok<AGROW>
            end
        end

        n_event_pairs_summary(ci) = pairCounterCurrent;
        n_valid_slopes_summary(ci) = validSlopeCounterCurrent;
        n_alignment_failures_summary(ci) = alignFailCounterCurrent;
        if alignFailCounterCurrent == 0 && validSlopeCounterCurrent > 0
            current_alignment_ok_summary(ci) = "YES";
        else
            current_alignment_ok_summary(ci) = "NO";
        end

        idxCurrentValid = (current_mA_event == thisCurrent) & isfinite(slope_cm_event) & isfinite(slope_sw_event);
        uTemp = unique(temperature_event(idxCurrentValid));
        for ti = 1:numel(uTemp)
            idxT = idxCurrentValid & (abs(temperature_event - uTemp(ti)) < 1e-9);
            sCm = slope_cm_event(idxT);
            sSw = slope_sw_event(idxT);

            current_mA_temp(end + 1, 1) = thisCurrent; %#ok<AGROW>
            temperature_temp(end + 1, 1) = uTemp(ti); %#ok<AGROW>
            mean_slope_cm_temp(end + 1, 1) = mean(sCm, 'omitnan'); %#ok<AGROW>
            std_slope_cm_temp(end + 1, 1) = std(sCm, 'omitnan'); %#ok<AGROW>
            frac_positive_cm_temp(end + 1, 1) = mean(sCm > 0, 'omitnan'); %#ok<AGROW>
            frac_negative_cm_temp(end + 1, 1) = mean(sCm < 0, 'omitnan'); %#ok<AGROW>
            mean_slope_sw_temp(end + 1, 1) = mean(sSw, 'omitnan'); %#ok<AGROW>
            std_slope_sw_temp(end + 1, 1) = std(sSw, 'omitnan'); %#ok<AGROW>
            frac_positive_sw_temp(end + 1, 1) = mean(sSw > 0, 'omitnan'); %#ok<AGROW>
            frac_negative_sw_temp(end + 1, 1) = mean(sSw < 0, 'omitnan'); %#ok<AGROW>
            n_events_temp(end + 1, 1) = sum(idxT); %#ok<AGROW>
        end

        idxCurrentTempRows = (current_mA_temp == thisCurrent);
        if any(idxCurrentTempRows)
            current_consistency_defined_summary(ci) = "YES";
            meanSlopeCurrent = mean(mean_slope_cm_temp(idxCurrentTempRows), 'omitnan');
            if meanSlopeCurrent > 0
                dominant_sign_cm_summary(ci) = "POSITIVE";
            elseif meanSlopeCurrent < 0
                dominant_sign_cm_summary(ci) = "NEGATIVE";
            else
                dominant_sign_cm_summary(ci) = "ZERO";
            end
        else
            current_consistency_defined_summary(ci) = "NO";
            dominant_sign_cm_summary(ci) = "UNDEFINED";
        end
    end

    eventTbl = table(current_mA_event, file_id_event, temperature_event, event_id_event, ...
        slope_cm_event, slope_sw_event, alignment_anchor_event, alignment_ok_event, ...
        'VariableNames', {'current_mA','file_id','temperature','event_id','slope_cm','slope_sw','alignment_anchor','alignment_ok'});
    if ~isempty(eventTbl)
        eventTbl = sortrows(eventTbl, {'current_mA','temperature','file_id','event_id'});
    end
    writetable(eventTbl, eventOutPath);

    tempTbl = table(current_mA_temp, temperature_temp, mean_slope_cm_temp, std_slope_cm_temp, ...
        frac_positive_cm_temp, frac_negative_cm_temp, ...
        mean_slope_sw_temp, std_slope_sw_temp, frac_positive_sw_temp, frac_negative_sw_temp, n_events_temp, ...
        'VariableNames', {'current_mA','temperature','mean_slope_cm','std_slope_cm', ...
        'frac_positive_cm','frac_negative_cm','mean_slope_sw','std_slope_sw','frac_positive_sw','frac_negative_sw','n_events'});
    if ~isempty(tempTbl)
        tempTbl = sortrows(tempTbl, {'current_mA','temperature'});
    end
    writetable(tempTbl, tempOutPath);

    allCurrentsAligned = all(current_alignment_ok_summary == "YES");
    slopeComputed = all(n_valid_slopes_summary > 0);
    noAlignmentFailure = all(n_alignment_failures_summary == 0);
    consistencyDefined = all(current_consistency_defined_summary == "YES");

    if allCurrentsAligned
        allCurrentsAlignedTxt = "YES";
    else
        allCurrentsAlignedTxt = "NO";
    end
    if slopeComputed
        slopeComputedTxt = "YES";
    else
        slopeComputedTxt = "NO";
    end
    if noAlignmentFailure
        noAlignmentFailureTxt = "YES";
    else
        noAlignmentFailureTxt = "NO";
    end
    if consistencyDefined
        consistencyDefinedTxt = "YES";
    else
        consistencyDefinedTxt = "NO";
    end

    methodGeneralizes = allCurrentsAligned && slopeComputed && noAlignmentFailure && consistencyDefined;
    if methodGeneralizes
        methodGeneralizesTxt = "YES";
    else
        methodGeneralizesTxt = "NO";
    end

    dominantSigns = dominant_sign_cm_summary;
    dominantSigns = dominantSigns(dominantSigns == "POSITIVE" | dominantSigns == "NEGATIVE");
    driftPhysicsConsistent = (numel(dominantSigns) == numel(currents)) && (numel(unique(dominantSigns)) == 1);
    if driftPhysicsConsistent
        driftPhysicsConsistentTxt = "YES";
    else
        driftPhysicsConsistentTxt = "NO";
    end

    figureWriteOk = true;
    for ci = 1:numel(currents)
        thisCurrent = currents(ci);
        figPath = fullfile(repoRoot, 'figures', sprintf('xx_slope_generalization_%dmA.png', thisCurrent));
        idxT = tempTbl.current_mA == thisCurrent;

        fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 700]);
        tl = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

        ax1 = nexttile(tl, 1);
        if any(idxT)
            tt = tempTbl.temperature(idxT);
            errorbar(ax1, tt, tempTbl.mean_slope_cm(idxT), tempTbl.std_slope_cm(idxT), '-o', ...
                'LineWidth', 1.4, 'MarkerSize', 5, 'Color', [0.85 0.20 0.20], 'DisplayName', 'R_{cm}');
            hold(ax1, 'on');
            errorbar(ax1, tt, tempTbl.mean_slope_sw(idxT), tempTbl.std_slope_sw(idxT), '-s', ...
                'LineWidth', 1.2, 'MarkerSize', 5, 'Color', [0.10 0.35 0.85], 'DisplayName', 'R_{sw}');
            yline(ax1, 0, ':k', 'LineWidth', 1.0);
            hold(ax1, 'off');
            legend(ax1, 'Location', 'best');
        else
            text(ax1, 0.5, 0.5, sprintf('%dmA: no valid slope rows', thisCurrent), ...
                'HorizontalAlignment', 'center', 'Interpreter', 'none');
            axis(ax1, 'off');
        end
        xlabel(ax1, 'Temperature (K)');
        ylabel(ax1, 'Slope');
        title(ax1, sprintf('XX slope vs temperature (%dmA)', thisCurrent), 'Interpreter', 'none');
        grid(ax1, 'on');

        ax2 = nexttile(tl, 2);
        if any(idxT)
            tt = tempTbl.temperature(idxT);
            plot(ax2, tt, tempTbl.frac_positive_cm(idxT), '-o', 'LineWidth', 1.3, ...
                'MarkerSize', 5, 'Color', [0.85 0.20 0.20], 'DisplayName', 'R_{cm} positive');
            hold(ax2, 'on');
            plot(ax2, tt, tempTbl.frac_negative_cm(idxT), '--o', 'LineWidth', 1.1, ...
                'MarkerSize', 5, 'Color', [0.85 0.20 0.20], 'DisplayName', 'R_{cm} negative');
            plot(ax2, tt, tempTbl.frac_positive_sw(idxT), '-s', 'LineWidth', 1.3, ...
                'MarkerSize', 5, 'Color', [0.10 0.35 0.85], 'DisplayName', 'R_{sw} positive');
            plot(ax2, tt, tempTbl.frac_negative_sw(idxT), '--s', 'LineWidth', 1.1, ...
                'MarkerSize', 5, 'Color', [0.10 0.35 0.85], 'DisplayName', 'R_{sw} negative');
            yline(ax2, 0.5, ':k', 'LineWidth', 1.0);
            ylim(ax2, [0 1]);
            hold(ax2, 'off');
            legend(ax2, 'Location', 'best');
        else
            text(ax2, 0.5, 0.5, sprintf('%dmA: no consistency rows', thisCurrent), ...
                'HorizontalAlignment', 'center', 'Interpreter', 'none');
            axis(ax2, 'off');
        end
        xlabel(ax2, 'Temperature (K)');
        ylabel(ax2, 'Fraction');
        title(ax2, sprintf('Sign consistency vs temperature (%dmA)', thisCurrent), 'Interpreter', 'none');
        grid(ax2, 'on');

        exportgraphics(fig, figPath, 'Resolution', 220);
        close(fig);
        if exist(figPath, 'file') ~= 2
            figureWriteOk = false;
        end
    end

    fullVisualizationReady = methodGeneralizes && figureWriteOk;
    if fullVisualizationReady
        fullVisualizationReadyTxt = "YES";
    else
        fullVisualizationReadyTxt = "NO";
    end

    summaryTbl = table(currents, n_files_summary, n_event_pairs_summary, n_valid_slopes_summary, ...
        n_alignment_failures_summary, current_alignment_ok_summary, current_consistency_defined_summary, dominant_sign_cm_summary, ...
        repmat(allCurrentsAlignedTxt, numel(currents), 1), repmat(slopeComputedTxt, numel(currents), 1), ...
        repmat(noAlignmentFailureTxt, numel(currents), 1), repmat(consistencyDefinedTxt, numel(currents), 1), ...
        repmat(methodGeneralizesTxt, numel(currents), 1), repmat(fullVisualizationReadyTxt, numel(currents), 1), ...
        repmat(driftPhysicsConsistentTxt, numel(currents), 1), ...
        'VariableNames', {'current_mA','n_files','n_event_pairs','n_valid_slopes','n_alignment_failures', ...
        'current_alignment_ok','current_consistency_defined','dominant_sign_cm', ...
        'ALL_CURRENTS_ALIGNED','SLOPE_COMPUTED','NO_ALIGNMENT_FAILURE','CONSISTENCY_DEFINED', ...
        'METHOD_GENERALIZES_TO_ALL_CURRENTS','FULL_XX_VISUALIZATION_READY','DRIFT_PHYSICS_CONSISTENT'});
    writetable(summaryTbl, summaryOutPath);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('XXSlopeGeneralization:ReportOpenFailed', 'Unable to open report for writing: %s', reportPath);
    end
    fprintf(fid, '# XX Multi-Current Generalization (Aligned, Config2 Only)\n\n');
    fprintf(fid, '## Method lock\n\n');
    fprintf(fid, '- XX = config2 ONLY\n');
    fprintf(fid, '- Decomposition: R_cm = (R_A + R_B)/2, R_sw = (R_A - R_B)/2\n');
    fprintf(fid, '- Alignment anchor: switch_idx\n');
    fprintf(fid, '- Observable: slope (linear trend vs aligned time)\n');
    fprintf(fid, '- Input table: tables/xx_relaxation_morphology_event_level_config2.csv\n\n');

    fprintf(fid, '## Coverage summary\n\n');
    for ci = 1:numel(currents)
        fprintf(fid, '- %dmA: n_files=%d, n_event_pairs=%d, n_valid_slopes=%d, n_alignment_failures=%d\n', ...
            currents(ci), n_files_summary(ci), n_event_pairs_summary(ci), n_valid_slopes_summary(ci), n_alignment_failures_summary(ci));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Required checks\n\n');
    fprintf(fid, 'ALL_CURRENTS_ALIGNED = %s\n', allCurrentsAlignedTxt);
    fprintf(fid, 'SLOPE_COMPUTED = %s\n', slopeComputedTxt);
    fprintf(fid, 'NO_ALIGNMENT_FAILURE = %s\n', noAlignmentFailureTxt);
    fprintf(fid, 'CONSISTENCY_DEFINED = %s\n\n', consistencyDefinedTxt);

    fprintf(fid, '## Final verdicts\n\n');
    fprintf(fid, 'METHOD_GENERALIZES_TO_ALL_CURRENTS = %s\n', methodGeneralizesTxt);
    fprintf(fid, 'FULL_XX_VISUALIZATION_READY = %s\n', fullVisualizationReadyTxt);
    fprintf(fid, 'DRIFT_PHYSICS_CONSISTENT = %s\n\n', driftPhysicsConsistentTxt);

    fprintf(fid, '## Artifacts\n\n');
    fprintf(fid, '- tables/xx_slope_event_level_all_currents_aligned.csv\n');
    fprintf(fid, '- tables/xx_slope_vs_temperature_all_currents_aligned.csv\n');
    fprintf(fid, '- tables/xx_slope_generalization_summary.csv\n');
    fprintf(fid, '- figures/xx_slope_generalization_25mA.png\n');
    fprintf(fid, '- figures/xx_slope_generalization_30mA.png\n');
    fprintf(fid, '- figures/xx_slope_generalization_35mA.png\n');
    fprintf(fid, '- reports/xx_slope_generalization_final.md\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(summaryTbl), {'XX slope multi-current generalization completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_slope_generalization_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XX slope multi-current generalization failed'}, ...
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
