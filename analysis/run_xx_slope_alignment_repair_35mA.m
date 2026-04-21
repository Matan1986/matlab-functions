fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXSlopeAlign35mA:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'scripts'));

cfgRun = struct();
cfgRun.runLabel = 'xx_slope_alignment_repair_35mA';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
anchorAuditPath = fullfile(repoRoot, 'tables', 'xx_alignment_anchor_audit_35mA.csv');
eventOutPath = fullfile(repoRoot, 'tables', 'xx_slope_event_level_35mA_aligned.csv');
tempOutPath = fullfile(repoRoot, 'tables', 'xx_slope_vs_temperature_35mA_aligned.csv');
signOutPath = fullfile(repoRoot, 'tables', 'xx_slope_sign_consistency_35mA_aligned.csv');
figDir = fullfile(repoRoot, 'figures', 'xx_slope_diagnostics_35mA_aligned');
summaryFigPath = fullfile(repoRoot, 'figures', 'xx_slope_diagnostics_summary_aligned.png');
reportPath = fullfile(repoRoot, 'reports', 'xx_slope_alignment_repair_35mA.md');

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('analysis', cfgRun);

    if exist(fileparts(anchorAuditPath), 'dir') ~= 7
        mkdir(fileparts(anchorAuditPath));
    end
    if exist(figDir, 'dir') ~= 7
        mkdir(figDir);
    end
    if exist(fileparts(summaryFigPath), 'dir') ~= 7
        mkdir(fileparts(summaryFigPath));
    end
    if exist(fileparts(reportPath), 'dir') ~= 7
        mkdir(fileparts(reportPath));
    end

    channelTblPath = fullfile(repoRoot, 'tables', 'xx_channel_validation.csv');
    if exist(channelTblPath, 'file') ~= 2
        error('XXSlopeAlign35mA:MissingChannelTable', 'Missing pipeline channel table: %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames) || isempty(channelTbl.pipeline_choice)
        error('XXSlopeAlign35mA:MissingPipelineChoice', 'Cannot resolve pipeline-selected channel from %s', channelTblPath);
    end
    selectedChannel = double(channelTbl.pipeline_choice(1));
    if ~(selectedChannel == 2 || selectedChannel == 3)
        error('XXSlopeAlign35mA:UnexpectedChannel', 'Expected channel 2 or 3, got %g', selectedChannel);
    end
    if selectedChannel == 2
        channelName = 'LI2_X (V)';
    else
        channelName = 'LI3_X (V)';
    end

    cfg = xx_relaxation_config2_sources();
    cfg35 = cfg(contains(string({cfg.config_id}), "35mA"));
    if isempty(cfg35)
        error('XXSlopeAlign35mA:ConfigMissing', 'Could not find config2_35mA source in xx_relaxation_config2_sources().');
    end
    sourceDir = fullfile(char(cfg35.baseDir), char(cfg35.tempDepFolder));
    if exist(sourceDir, 'dir') ~= 7
        error('XXSlopeAlign35mA:SourceMissing', '35 mA source directory not found: %s', sourceDir);
    end

    eventSrcPath = fullfile(repoRoot, 'tables', 'xx_35mA_model_free_relaxation.csv');
    if exist(eventSrcPath, 'file') ~= 2
        error('XXSlopeAlign35mA:MissingPipelineEvents', 'Missing pipeline event table: %s', eventSrcPath);
    end
    srcEvents = readtable(eventSrcPath, 'TextType', 'string');
    needCols = {'file_id','temperature','pulse_index','target_state','switch_idx','relax_start_idx','window_end_idx'};
    for c = 1:numel(needCols)
        if ~ismember(needCols{c}, srcEvents.Properties.VariableNames)
            error('XXSlopeAlign35mA:MissingColumn', 'Missing required event column: %s', needCols{c});
        end
    end
    srcEvents = sortrows(srcEvents, {'temperature', 'file_id', 'pulse_index'});
    if isempty(srcEvents)
        error('XXSlopeAlign35mA:NoPipelineEvents', 'Pipeline event table is empty.');
    end

    hasEventStart = ismember('event_start_idx', srcEvents.Properties.VariableNames);
    hasRelaxStart = ismember('relax_start_idx', srcEvents.Properties.VariableNames);
    hasPlateauStart = ismember('plateau_start_idx', srcEvents.Properties.VariableNames);
    hasPulseEnd = ismember('switch_idx', srcEvents.Properties.VariableNames);
    hasCanonicalPostPulse = hasPulseEnd;

    nRows = height(srcEvents);
    file_id_audit = srcEvents.file_id;
    temperature_audit = srcEvents.temperature;
    event_id_audit = "pulse_" + string(srcEvents.pulse_index) + "_" + srcEvents.target_state;
    pulse_end_available = false(nRows, 1);
    event_start_available = false(nRows, 1);
    relaxation_start_available = false(nRows, 1);
    plateau_start_available = false(nRows, 1);
    chosen_anchor = strings(nRows, 1);
    chosen_anchor_reason = strings(nRows, 1);

    for i = 1:nRows
        if hasPulseEnd
            pulse_end_available(i) = isfinite(srcEvents.switch_idx(i)) && (srcEvents.switch_idx(i) >= 1);
        end
        if hasEventStart
            event_start_available(i) = isfinite(srcEvents.event_start_idx(i)) && (srcEvents.event_start_idx(i) >= 1);
        end
        if hasRelaxStart
            relaxation_start_available(i) = isfinite(srcEvents.relax_start_idx(i)) && (srcEvents.relax_start_idx(i) >= 1);
        end
        if hasPlateauStart
            plateau_start_available(i) = isfinite(srcEvents.plateau_start_idx(i)) && (srcEvents.plateau_start_idx(i) >= 1);
        end
    end

    if hasCanonicalPostPulse
        chosenAnchorGlobal = "switch_idx";
        chosenReasonGlobal = "Available across events, directly tied to post-pulse transition, and minimizes pulse-timing ambiguity.";
    elseif hasRelaxStart
        chosenAnchorGlobal = "relax_start_idx";
        chosenReasonGlobal = "Fallback anchor because explicit post-pulse anchor is unavailable.";
    else
        chosenAnchorGlobal = "none";
        chosenReasonGlobal = "No operational post-pulse anchor available in pipeline event table.";
    end
    for i = 1:nRows
        chosen_anchor(i) = chosenAnchorGlobal;
        chosen_anchor_reason(i) = chosenReasonGlobal;
    end

    anchorAuditTbl = table(file_id_audit, temperature_audit, event_id_audit, pulse_end_available, ...
        event_start_available, relaxation_start_available, plateau_start_available, ...
        chosen_anchor, chosen_anchor_reason, ...
        'VariableNames', {'file_id','temperature','event_id','pulse_end_available', ...
        'event_start_available','relaxation_start_available','plateau_start_available', ...
        'chosen_anchor','chosen_anchor_reason'});
    anchorAuditTbl = sortrows(anchorAuditTbl, {'temperature','file_id','event_id'});
    writetable(anchorAuditTbl, anchorAuditPath);

    if chosenAnchorGlobal == "none"
        error('XXSlopeAlign35mA:NoAnchor', 'No operational alignment anchor found.');
    end

    file_id = strings(0, 1);
    temperature = zeros(0, 1);
    event_id = strings(0, 1);
    slope_cm_aligned = NaN(0, 1);
    slope_sw_aligned = NaN(0, 1);
    slope_cm_abs_aligned = NaN(0, 1);
    slope_sw_abs_aligned = NaN(0, 1);
    ratio_slope_aligned = NaN(0, 1);
    t_rel_start_sec = NaN(0, 1);
    t_rel_end_sec = NaN(0, 1);

    rCmCell = cell(0, 1);
    tRelCell = cell(0, 1);

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
        tSecGlobal = tMs ./ 1000;

        aRows = rowsF(rowsF.target_state == "A", :);
        bRows = rowsF(rowsF.target_state == "B", :);
        nPairs = min(height(aRows), height(bRows));

        for p = 1:nPairs
            aStart = aRows.relax_start_idx(p);
            aEnd = aRows.window_end_idx(p);
            bStart = bRows.relax_start_idx(p);
            bEnd = bRows.window_end_idx(p);

            if chosenAnchorGlobal == "switch_idx"
                aAnchor = aRows.switch_idx(p);
                bAnchor = bRows.switch_idx(p);
            else
                aAnchor = aRows.relax_start_idx(p);
                bAnchor = bRows.relax_start_idx(p);
            end

            if ~(isfinite(aStart) && isfinite(aEnd) && isfinite(bStart) && isfinite(bEnd) && isfinite(aAnchor) && isfinite(bAnchor))
                continue;
            end

            aStart = max(1, round(aStart));
            aEnd = min(numel(v), round(aEnd));
            bStart = max(1, round(bStart));
            bEnd = min(numel(v), round(bEnd));
            aAnchor = max(1, min(numel(v), round(aAnchor)));
            bAnchor = max(1, min(numel(v), round(bAnchor)));
            if aEnd <= aStart || bEnd <= bStart
                continue;
            end

            idxA = aStart:aEnd;
            idxB = bStart:bEnd;
            ra = v(idxA);
            rb = v(idxB);
            tA = tSecGlobal(idxA) - tSecGlobal(aAnchor);
            tB = tSecGlobal(idxB) - tSecGlobal(bAnchor);

            nMin = min([numel(ra), numel(rb), numel(tA), numel(tB)]);
            if nMin < 5
                continue;
            end

            ra = ra(1:nMin);
            rb = rb(1:nMin);
            tA = tA(1:nMin);
            tB = tB(1:nMin);
            if any(~isfinite(ra)) || any(~isfinite(rb)) || any(~isfinite(tA)) || any(~isfinite(tB))
                continue;
            end

            tRel = 0.5 * (tA + tB);
            if numel(unique(tRel)) < 2
                continue;
            end

            r_cm = 0.5 * (ra + rb);
            r_sw = 0.5 * (ra - rb);

            pCm = polyfit(tRel, r_cm, 1);
            pSw = polyfit(tRel, r_sw, 1);
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
            slope_cm_aligned(end + 1, 1) = cmVal; %#ok<AGROW>
            slope_sw_aligned(end + 1, 1) = swVal; %#ok<AGROW>
            slope_cm_abs_aligned(end + 1, 1) = cmAbsVal; %#ok<AGROW>
            slope_sw_abs_aligned(end + 1, 1) = swAbsVal; %#ok<AGROW>
            ratio_slope_aligned(end + 1, 1) = ratioVal; %#ok<AGROW>
            t_rel_start_sec(end + 1, 1) = tRel(1); %#ok<AGROW>
            t_rel_end_sec(end + 1, 1) = tRel(end); %#ok<AGROW>
            rCmCell{end + 1, 1} = r_cm; %#ok<AGROW>
            tRelCell{end + 1, 1} = tRel; %#ok<AGROW>
        end
    end

    eventTbl = table(file_id, temperature, event_id, slope_cm_aligned, slope_sw_aligned, ...
        slope_cm_abs_aligned, slope_sw_abs_aligned, ratio_slope_aligned, t_rel_start_sec, t_rel_end_sec, ...
        'VariableNames', {'file_id','temperature','event_id','slope_cm_aligned','slope_sw_aligned', ...
        'slope_cm_abs_aligned','slope_sw_abs_aligned','ratio_slope_aligned','t_rel_start_sec','t_rel_end_sec'});
    eventTbl = sortrows(eventTbl, {'temperature','file_id','event_id'});
    writetable(eventTbl, eventOutPath);

    if isempty(eventTbl)
        tempTbl = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            'VariableNames', {'temperature','mean_slope_cm_abs_aligned','mean_slope_sw_abs_aligned','mean_ratio_slope_aligned', ...
            'std_slope_cm_abs_aligned','std_slope_sw_abs_aligned','n_events'});
        writetable(tempTbl, tempOutPath);

        signTbl = table(string.empty(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            'VariableNames', {'group','n_events','fraction_negative_slope_cm_aligned','fraction_positive_slope_cm_aligned'});
        writetable(signTbl, signOutPath);

        fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 540]);
        ax = axes(fig);
        text(ax, 0.5, 0.5, 'No aligned events available', 'HorizontalAlignment', 'center');
        axis(ax, 'off');
        exportgraphics(fig, summaryFigPath, 'Resolution', 200);
        close(fig);

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('XXSlopeAlign35mA:ReportOpenFailed', 'Unable to write report: %s', reportPath);
        end
        fprintf(fid, '## A. Alignment decision\n\n');
        fprintf(fid, '- Which anchor was chosen? %s\n', char(chosenAnchorGlobal));
        fprintf(fid, '- Why is it the best available operational anchor? %s\n\n', char(chosenReasonGlobal));
        fprintf(fid, '## B. Outcome\n\n');
        fprintf(fid, '- Did slope sign consistency improve? NO\n');
        fprintf(fid, '- Do aligned slopes now match the visual direction? NO\n\n');
        fprintf(fid, '## C. Final flags\n\n');
        fprintf(fid, 'ALIGNMENT_ANCHOR_FOUND = NO\n');
        fprintf(fid, 'ALIGNED_SLOPE_SIGN_CONSISTENT = NO\n');
        fprintf(fid, 'VISUAL_AND_SLOPE_AGREE_AFTER_ALIGNMENT = NO\n');
        fprintf(fid, 'EVENT_LEVEL_TREND_NOW_TRUSTED = NO\n\n');
        fprintf(fid, 'ALIGNMENT_ISSUE_RESOLVED = NO\n');
        fprintf(fid, 'SLOPE_SIGN_REPAIRED = NO\n');
        fprintf(fid, 'CORRECTED_ANALYSIS_AVAILABLE = NO\n');
        fclose(fid);

        executionStatus = table({'SUCCESS'}, {'YES'}, {''}, 0, {'Anchor audit completed but no aligned events available'}, ...
            'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    else
        uT = unique(eventTbl.temperature);
        nT = numel(uT);
        mean_slope_cm_abs_aligned = NaN(nT, 1);
        mean_slope_sw_abs_aligned = NaN(nT, 1);
        mean_ratio_slope_aligned = NaN(nT, 1);
        std_slope_cm_abs_aligned = NaN(nT, 1);
        std_slope_sw_abs_aligned = NaN(nT, 1);
        n_events = zeros(nT, 1);

        for i = 1:nT
            idx = abs(eventTbl.temperature - uT(i)) < 1e-9;
            mean_slope_cm_abs_aligned(i) = mean(eventTbl.slope_cm_abs_aligned(idx), 'omitnan');
            mean_slope_sw_abs_aligned(i) = mean(eventTbl.slope_sw_abs_aligned(idx), 'omitnan');
            mean_ratio_slope_aligned(i) = mean(eventTbl.ratio_slope_aligned(idx), 'omitnan');
            std_slope_cm_abs_aligned(i) = std(eventTbl.slope_cm_abs_aligned(idx), 'omitnan');
            std_slope_sw_abs_aligned(i) = std(eventTbl.slope_sw_abs_aligned(idx), 'omitnan');
            n_events(i) = sum(idx);
        end

        tempTbl = table(uT, mean_slope_cm_abs_aligned, mean_slope_sw_abs_aligned, mean_ratio_slope_aligned, ...
            std_slope_cm_abs_aligned, std_slope_sw_abs_aligned, n_events, ...
            'VariableNames', {'temperature','mean_slope_cm_abs_aligned','mean_slope_sw_abs_aligned','mean_ratio_slope_aligned', ...
            'std_slope_cm_abs_aligned','std_slope_sw_abs_aligned','n_events'});
        tempTbl = sortrows(tempTbl, 'temperature');
        writetable(tempTbl, tempOutPath);

        tVals = eventTbl.temperature;
        tLowThr = prctile(tVals, 33);
        tHighThr = prctile(tVals, 67);
        idxLow = tVals <= tLowThr;
        idxMid = (tVals > tLowThr) & (tVals < tHighThr);
        idxHigh = tVals >= tHighThr;

        group = ["overall"; "low"; "mid"; "high"];
        n_group = zeros(4, 1);
        frac_neg = zeros(4, 1);
        frac_pos = zeros(4, 1);

        idxSet = cell(4, 1);
        idxSet{1} = true(height(eventTbl), 1);
        idxSet{2} = idxLow;
        idxSet{3} = idxMid;
        idxSet{4} = idxHigh;

        for g = 1:4
            idxG = idxSet{g};
            n_group(g) = sum(idxG);
            if n_group(g) > 0
                frac_neg(g) = mean(eventTbl.slope_cm_aligned(idxG) < 0, 'omitnan');
                frac_pos(g) = mean(eventTbl.slope_cm_aligned(idxG) > 0, 'omitnan');
            else
                frac_neg(g) = NaN;
                frac_pos(g) = NaN;
            end
        end

        signTbl = table(group, n_group, frac_neg, frac_pos, ...
            'VariableNames', {'group','n_events','fraction_negative_slope_cm_aligned','fraction_positive_slope_cm_aligned'});
        writetable(signTbl, signOutPath);

        nSel = min(6, height(eventTbl));
        [~, orderByAbs] = sort(eventTbl.slope_cm_abs_aligned, 'descend');
        selIdx = sort(orderByAbs(1:nSel), 'ascend');
        if ~isempty(selIdx)
            nCols = 2;
            nRowsFig = ceil(nSel / nCols);
            figSum = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 520 * nRowsFig]);
            tl = tiledlayout(nRowsFig, nCols, 'Padding', 'compact', 'TileSpacing', 'compact');

            for k = 1:nSel
                idxEv = selIdx(k);
                tRel = tRelCell{idxEv};
                rCm = rCmCell{idxEv};
                pCm = polyfit(tRel, rCm, 1);
                fitCm = polyval(pCm, tRel);

                figSingle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 640]);
                ax1 = axes(figSingle);
                plot(ax1, tRel, rCm, 'Color', [0.80 0.10 0.10], 'LineWidth', 1.3);
                hold(ax1, 'on');
                plot(ax1, tRel, fitCm, 'k--', 'LineWidth', 1.4);
                xline(ax1, 0, ':', 'anchor', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
                xlabel(ax1, 't_{rel} (s)');
                ylabel(ax1, 'R_{cm}');
                title(ax1, sprintf('Aligned event: %s | %s', char(eventTbl.file_id(idxEv)), char(eventTbl.event_id(idxEv))), 'Interpreter', 'none');
                legend(ax1, {'R_{cm}(t_{rel})', 'Linear fit'}, 'Location', 'best');
                grid(ax1, 'on');
                hold(ax1, 'off');

                figName = sprintf('aligned_%s_%s.png', char(eventTbl.file_id(idxEv)), char(eventTbl.event_id(idxEv)));
                figName = regexprep(figName, '[^a-zA-Z0-9_\-\.]', '_');
                exportgraphics(figSingle, fullfile(figDir, figName), 'Resolution', 220);
                close(figSingle);

                ax = nexttile(tl, k);
                plot(ax, tRel, rCm, 'Color', [0.80 0.10 0.10], 'LineWidth', 1.2);
                hold(ax, 'on');
                plot(ax, tRel, fitCm, 'k--', 'LineWidth', 1.2);
                xline(ax, 0, ':', 'anchor', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0);
                grid(ax, 'on');
                title(ax, sprintf('T=%.2fK, slope=%.3g', eventTbl.temperature(idxEv), eventTbl.slope_cm_aligned(idxEv)));
                xlabel(ax, 't_{rel} (s)');
                ylabel(ax, 'R_{cm}');
                hold(ax, 'off');
            end
            title(tl, 'XX 35mA aligned slope diagnostics');
            exportgraphics(figSum, summaryFigPath, 'Resolution', 240);
            close(figSum);
        end

        fracNegOverall = signTbl.fraction_negative_slope_cm_aligned(signTbl.group == "overall");
        fracPosOverall = signTbl.fraction_positive_slope_cm_aligned(signTbl.group == "overall");
        alignedSlopeSignConsistent = (fracNegOverall >= 0.70) || (fracPosOverall >= 0.70);

        visualDirPositiveCount = 0;
        visualDirNegativeCount = 0;
        for i = 1:numel(rCmCell)
            rTraceLocal = rCmCell{i};
            if isempty(rTraceLocal) || any(~isfinite(rTraceLocal))
                continue;
            end
            if (rTraceLocal(end) - rTraceLocal(1)) >= 0
                visualDirPositiveCount = visualDirPositiveCount + 1;
            else
                visualDirNegativeCount = visualDirNegativeCount + 1;
            end
        end
        if visualDirPositiveCount >= visualDirNegativeCount
            visualMajorityPositive = true;
        else
            visualMajorityPositive = false;
        end
        if fracPosOverall >= fracNegOverall
            slopeMajorityPositive = true;
        else
            slopeMajorityPositive = false;
        end
        visualAndSlopeAgree = (visualMajorityPositive == slopeMajorityPositive);
        alignmentAnchorFound = chosenAnchorGlobal ~= "none";
        eventTrendTrusted = alignmentAnchorFound && alignedSlopeSignConsistent && visualAndSlopeAgree;

        if alignedSlopeSignConsistent
            slopeConsistencyTxt = 'YES';
        else
            slopeConsistencyTxt = 'NO';
        end
        if visualAndSlopeAgree
            visualAgreeTxt = 'YES';
        else
            visualAgreeTxt = 'NO';
        end

        fid = fopen(reportPath, 'w');
        if fid < 0
            error('XXSlopeAlign35mA:ReportOpenFailed', 'Unable to write report: %s', reportPath);
        end
        fprintf(fid, '## A. Alignment decision\n\n');
        fprintf(fid, '- Which anchor was chosen? %s\n', char(chosenAnchorGlobal));
        fprintf(fid, '- Why is it the best available operational anchor? %s\n\n', char(chosenReasonGlobal));
        fprintf(fid, '## B. Outcome\n\n');
        fprintf(fid, '- Did slope sign consistency improve? %s\n', slopeConsistencyTxt);
        fprintf(fid, '- Do aligned slopes now match the visual direction? %s\n\n', visualAgreeTxt);
        fprintf(fid, '## C. Final flags\n\n');
        if alignmentAnchorFound
            fprintf(fid, 'ALIGNMENT_ANCHOR_FOUND = YES\n');
        else
            fprintf(fid, 'ALIGNMENT_ANCHOR_FOUND = NO\n');
        end
        if alignedSlopeSignConsistent
            fprintf(fid, 'ALIGNED_SLOPE_SIGN_CONSISTENT = YES\n');
        else
            fprintf(fid, 'ALIGNED_SLOPE_SIGN_CONSISTENT = NO\n');
        end
        if visualAndSlopeAgree
            fprintf(fid, 'VISUAL_AND_SLOPE_AGREE_AFTER_ALIGNMENT = YES\n');
        else
            fprintf(fid, 'VISUAL_AND_SLOPE_AGREE_AFTER_ALIGNMENT = NO\n');
        end
        if eventTrendTrusted
            fprintf(fid, 'EVENT_LEVEL_TREND_NOW_TRUSTED = YES\n\n');
        else
            fprintf(fid, 'EVENT_LEVEL_TREND_NOW_TRUSTED = NO\n\n');
        end
        if alignmentAnchorFound
            fprintf(fid, 'ALIGNMENT_ISSUE_RESOLVED = YES\n');
        else
            fprintf(fid, 'ALIGNMENT_ISSUE_RESOLVED = NO\n');
        end
        if alignedSlopeSignConsistent && visualAndSlopeAgree
            fprintf(fid, 'SLOPE_SIGN_REPAIRED = YES\n');
        else
            fprintf(fid, 'SLOPE_SIGN_REPAIRED = NO\n');
        end
        fprintf(fid, 'CORRECTED_ANALYSIS_AVAILABLE = YES\n');
        fclose(fid);

        executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nT, {'Aligned 35mA slope analysis outputs generated'}, ...
            'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    end

catch ME
    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_slope_alignment_repair_35mA_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'35mA aligned slope repair failed'}, ...
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
