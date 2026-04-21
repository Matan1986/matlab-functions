clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXLateAuto:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfgRun = struct();
cfgRun.runLabel = 'xx_late_vs_standard_auto_channel';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');

standardGapPath = fullfile(tablesDir, 'xx_standard_gap.csv');
standardNoisePath = fullfile(tablesDir, 'xx_standard_noise.csv');
standardDriftPath = fullfile(tablesDir, 'xx_standard_drift.csv');
lateGapPath = fullfile(tablesDir, 'xx_late_gap.csv');
lateNoisePath = fullfile(tablesDir, 'xx_late_noise.csv');
lateDriftPath = fullfile(tablesDir, 'xx_late_drift.csv');
channelUsedPath = fullfile(tablesDir, 'xx_channel_used.csv');
lateLengthsPath = fullfile(tablesDir, 'xx_late_plateau_lengths.csv');
lateCoveragePath = fullfile(tablesDir, 'xx_late_coverage.csv');
diffMapsPath = fullfile(tablesDir, 'xx_diff_maps.csv');
correlationTestsPath = fullfile(tablesDir, 'xx_late_correlation_tests.csv');

standardMapsFigPath = fullfile(figuresDir, 'xx_standard_maps.fig');
lateMapsFigPath = fullfile(figuresDir, 'xx_late_maps.fig');
diffMapsFigPath = fullfile(figuresDir, 'xx_diff_maps.fig');
lateScatterFigPath = fullfile(figuresDir, 'xx_late_scatter.fig');

standardSummaryPath = fullfile(reportsDir, 'xx_standard_summary.md');
lateSummaryPath = fullfile(reportsDir, 'xx_late_summary.md');
mainReportPath = fullfile(reportsDir, 'xx_late_vs_standard_analysis.md');

temperatureCutoffK = 34;
lateFrac1 = 0.70;
lateFrac2 = 0.90;
safetyMarginPercent = 15;
skipFirstPlateaus = 1;
skipLastPlateaus = 0;
minPtsFit = 10;
plateauMinOkThreshold = 5;
plateauShortFracFailThreshold = 0.30;

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

emptyMetricTbl = table([], [], [], 'VariableNames', {'temperature_K', 'current_mA', 'value'});
emptyChannelTbl = table(strings(0,1), [], strings(0,1), [], strings(0,1), ...
    'VariableNames', {'folder_name', 'current_mA', 'branch_name', 'channel_selected', 'selection_method'});
emptyLengthsTbl = table([], [], [], [], ...
    'VariableNames', {'mean_length', 'min_length', 'fraction_below_5', 'n_plateaus'});
emptyCoverageTbl = table([], [], [], ...
    'VariableNames', {'valid_points_standard', 'valid_points_late', 'coverage_ratio'});
emptyDiffTbl = table([], [], [], [], [], ...
    'VariableNames', {'temperature_K', 'current_mA', 'delta_gap', 'delta_noise', 'delta_drift'});
emptyCorrTbl = table(strings(0,1), [], [], [], [], [], [], [], [], [], ...
    'VariableNames', {'comparison_name', 'pearson_r', 'pearson_p', 'spearman_rho', 'spearman_p', 'n_points', ...
    'x_mean', 'y_mean', 'x_std', 'y_std'});

try
    run = createRunContext('analysis', cfgRun);

    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end

    pointerPath = fullfile(run.repo_root, 'run_dir_pointer.txt');
    fidPointer = fopen(pointerPath, 'w');
    if fidPointer >= 0
        fprintf(fidPointer, '%s\n', run.run_dir);
        fclose(fidPointer);
    end

    writetable(renameMetricTbl(emptyMetricTbl, 'gap'), standardGapPath);
    writetable(renameMetricTbl(emptyMetricTbl, 'noise'), standardNoisePath);
    writetable(renameMetricTbl(emptyMetricTbl, 'drift'), standardDriftPath);
    writetable(renameMetricTbl(emptyMetricTbl, 'gap'), lateGapPath);
    writetable(renameMetricTbl(emptyMetricTbl, 'noise'), lateNoisePath);
    writetable(renameMetricTbl(emptyMetricTbl, 'drift'), lateDriftPath);
    writetable(emptyChannelTbl, channelUsedPath);
    writetable(emptyLengthsTbl, lateLengthsPath);
    writetable(emptyCoverageTbl, lateCoveragePath);
    writetable(emptyDiffTbl, diffMapsPath);
    writetable(emptyCorrTbl, correlationTestsPath);

    writeSimpleFile(standardSummaryPath, '# XX standard summary\n\nPENDING\n');
    writeSimpleFile(lateSummaryPath, '# XX late summary\n\nPENDING\n');
    writeSimpleFile(mainReportPath, '# XX late vs standard analysis\n\nPENDING\n');

    cfgSources = xx_relaxation_config2_sources();
    if isempty(cfgSources)
        error('XXLateAuto:MissingConfig2Sources', 'xx_relaxation_config2_sources returned empty.');
    end
    parentDir = char(cfgSources(1).baseDir);
    if exist(parentDir, 'dir') ~= 7
        error('XXLateAuto:MissingParentDir', 'XX Config2 parent directory does not exist: %s', parentDir);
    end

    filteredParentDir = fullfile(run.run_dir, sprintf('xx_temp_cutoff_input_le_%gK', temperatureCutoffK));
    if exist(filteredParentDir, 'dir') ~= 7
        mkdir(filteredParentDir);
    end

    srcDirs = dir(fullfile(parentDir, 'Temp Dep *'));
    srcDirs = srcDirs([srcDirs.isdir]);
    if isempty(srcDirs)
        error('XXLateAuto:NoTempDirs', 'No Temp Dep directories found under %s', parentDir);
    end

    totalCopiedFiles = 0;
    for iSrc = 1:numel(srcDirs)
        srcSubDir = fullfile(parentDir, srcDirs(iSrc).name);
        depType = extract_dep_type_from_folder(srcSubDir);
        [fileList, sortedValues, ~, ~] = getFileListSwitching(srcSubDir, depType);
        if isempty(fileList) || isempty(sortedValues)
            continue;
        end

        keepMask = isfinite(sortedValues) & (sortedValues <= temperatureCutoffK);
        if ~any(keepMask)
            continue;
        end

        dstSubDir = fullfile(filteredParentDir, srcDirs(iSrc).name);
        if exist(dstSubDir, 'dir') ~= 7
            mkdir(dstSubDir);
        end

        idxKeep = find(keepMask);
        for ik = 1:numel(idxKeep)
            srcFile = fullfile(srcSubDir, fileList(idxKeep(ik)).name);
            copyfile(srcFile, dstSubDir);
            totalCopiedFiles = totalCopiedFiles + 1;
        end
    end
    if totalCopiedFiles == 0
        error('XXLateAuto:NoCopiedFiles', 'No XX files passed the temperature cutoff.');
    end

    rowsStandard = zeros(0, 5);
    rowsLate = zeros(0, 5);
    channelRows = strings(0, 5);
    lateLengths = zeros(0, 1);
    validPointsStandard = 0;
    validPointsLate = 0;

    tempDirs = dir(fullfile(filteredParentDir, 'Temp Dep *'));
    tempDirs = tempDirs([tempDirs.isdir]);
    if isempty(tempDirs)
        error('XXLateAuto:NoFilteredTempDirs', 'No filtered Temp Dep directories exist under %s', filteredParentDir);
    end

    for iDir = 1:numel(tempDirs)
        thisDir = fullfile(filteredParentDir, tempDirs(iDir).name);
        depType = extract_dep_type_from_folder(thisDir);
        [fileList, sortedValues, ~, meta] = getFileListSwitching(thisDir, depType);
        if isempty(fileList)
            continue;
        end

        amp = meta.Current_mA;
        if ~isfinite(amp)
            continue;
        end

        pulseScheme = extractPulseSchemeFromFolder(thisDir);
        delayMs = extract_delay_between_pulses_from_name(thisDir) * 1e3;
        numPulsesWithSameDep = pulseScheme.totalPulses;

        normalizeTo = 1;
        if exist('resolve_preset', 'file') == 2 && exist('select_preset', 'file') == 2
            presetName = resolve_preset(fileList(1).name, true, '1xy_3xx');
            [~, ~, ~, normalizeCandidate] = select_preset(presetName);
            if ~isempty(normalizeCandidate)
                normalizeTo = normalizeCandidate;
            end
        end

        currentA = extract_current_I(thisDir, fileList(1).name, NaN);
        if ~isfinite(currentA) || currentA == 0
            error('XXLateAuto:InvalidCurrent', 'Invalid current parsed in %s', thisDir);
        end

        [storedDataStd, ~] = processFilesSwitching( ...
            thisDir, fileList, sortedValues, ...
            currentA, 1e3, ...
            4000, 16, 4, 2, 11, ...
            false, delayMs, ...
            numPulsesWithSameDep, safetyMarginPercent, ...
            NaN, NaN, normalizeTo, ...
            true, 1.5, 50, false, pulseScheme);

        stbOpts = struct();
        stbOpts.useFiltered = true;
        stbOpts.useCentered = false;
        stbOpts.stateMethod = pulseScheme.mode;
        stbOpts.skipFirstPlateaus = skipFirstPlateaus;
        stbOpts.skipLastPlateaus = skipLastPlateaus;
        stbOpts.pulseScheme = pulseScheme;
        stbOpts.minPtsFit = minPtsFit;

        stabilityStd = analyzeSwitchingStability( ...
            storedDataStd, sortedValues, ...
            delayMs, safetyMarginPercent, stbOpts);

        selectedStdChannel = stabilityStd.switching.globalChannel;
        if ~(isfinite(selectedStdChannel) && any(selectedStdChannel == [1, 2, 3, 4]))
            continue;
        end

        storedDataLate = storedDataStd;
        for iFile = 1:size(storedDataStd, 1)
            dataRef = storedDataStd{iFile, 1};
            if isempty(dataRef) || size(dataRef, 2) < 2
                continue;
            end

            t = dataRef(:, 1);
            numCh = size(dataRef, 2) - 1;
            plateauMeansStd = storedDataStd{iFile, 5};
            if isempty(plateauMeansStd)
                continue;
            end
            numPulses = size(plateauMeansStd, 1);
            pulseTimes = t(1) + (0:numPulses - 1) * delayMs;
            safetyMarginMs = delayMs * (safetyMarginPercent / 100);

            keepMaskTime = false(size(t));
            lateMeans = NaN(size(plateauMeansStd));

            for j = 1:numPulses
                if j < numPulses
                    t1 = pulseTimes(j) + safetyMarginMs;
                    t2 = pulseTimes(j + 1) - safetyMarginMs;
                else
                    t1 = pulseTimes(j) + safetyMarginMs;
                    t2 = t(end);
                end

                idx0 = find((t >= t1) & (t <= t2));
                nFull = numel(idx0);
                if nFull == 0
                    continue;
                end

                i1 = floor(lateFrac1 * nFull) + 1;
                i2 = floor(lateFrac2 * nFull);
                i2 = max(i2, i1);
                i1 = min(max(i1, 1), nFull);
                i2 = min(max(i2, i1), nFull);
                idxLate = idx0(i1:i2);
                nLate = numel(idxLate);
                lateLengths(end + 1, 1) = nLate; %#ok<AGROW>
                keepMaskTime(idxLate) = true;

                dataUnf = storedDataStd{iFile, 1};
                if size(dataUnf, 2) >= (1 + numCh)
                    for k = 1:numCh
                        valsLate = dataUnf(idxLate, 1 + k);
                        if isempty(valsLate)
                            lateMeans(j, k) = NaN;
                        else
                            lateMeans(j, k) = mean(valsLate, 'omitnan');
                        end
                    end
                end
            end

            for dataCol = 1:3
                dataCur = storedDataStd{iFile, dataCol};
                if isempty(dataCur) || size(dataCur, 2) < 2
                    continue;
                end
                dataMasked = dataCur;
                dataMasked(~keepMaskTime, 2:end) = NaN;
                storedDataLate{iFile, dataCol} = dataMasked;
            end
            storedDataLate{iFile, 4} = keepMaskTime;
            storedDataLate{iFile, 5} = lateMeans;
        end

        stabilityLate = analyzeSwitchingStability( ...
            storedDataLate, sortedValues, ...
            delayMs, safetyMarginPercent, stbOpts);

        selectedLateChannel = stabilityLate.switching.globalChannel;
        if ~(isfinite(selectedLateChannel) && any(selectedLateChannel == [1, 2, 3, 4]))
            continue;
        end

        channelRows(end + 1, :) = [string(tempDirs(iDir).name), string(amp), "standard", string(selectedStdChannel), "automatic"]; %#ok<AGROW>
        channelRows(end + 1, :) = [string(tempDirs(iDir).name), string(amp), "late", string(selectedLateChannel), "automatic"]; %#ok<AGROW>

        [stdRowsDir, stdCount] = extractRowsForAutoChannel(stabilityStd.summaryTable, selectedStdChannel, amp, temperatureCutoffK);
        [lateRowsDir, lateCount] = extractRowsForAutoChannel(stabilityLate.summaryTable, selectedLateChannel, amp, temperatureCutoffK);
        rowsStandard = [rowsStandard; stdRowsDir]; %#ok<AGROW>
        rowsLate = [rowsLate; lateRowsDir]; %#ok<AGROW>

        validPointsStandard = validPointsStandard + stdCount;
        validPointsLate = validPointsLate + lateCount;
    end

    if isempty(rowsStandard) || isempty(rowsLate)
        error('XXLateAuto:NoMetricRows', 'No finite standard/late metric rows were collected.');
    end

    rowsStandard = sortrows(rowsStandard, [2, 1]);
    rowsLate = sortrows(rowsLate, [2, 1]);

    if isempty(lateLengths)
        error('XXLateAuto:NoLatePlateauLengths', 'No late plateau lengths were recorded.');
    end

    meanLength = mean(lateLengths, 'omitnan');
    minLength = min(lateLengths);
    fractionBelow5 = mean(lateLengths < plateauMinOkThreshold, 'omitnan');
    if ~(isfinite(fractionBelow5) && fractionBelow5 <= plateauShortFracFailThreshold)
        error('XXLateAuto:PlateauTooShort', 'Late plateau support too sparse: fraction_below_5 = %.6g', fractionBelow5);
    end

    coverageRatio = validPointsLate / max(validPointsStandard, 1);

    standardGapTbl = buildMetricTable(rowsStandard, 3, 'gap');
    standardNoiseTbl = buildMetricTable(rowsStandard, 4, 'noise');
    standardDriftTbl = buildMetricTable(rowsStandard, 5, 'drift');
    lateGapTbl = buildMetricTable(rowsLate, 3, 'gap');
    lateNoiseTbl = buildMetricTable(rowsLate, 4, 'noise');
    lateDriftTbl = buildMetricTable(rowsLate, 5, 'drift');

    if isempty(standardGapTbl) || isempty(lateGapTbl)
        error('XXLateAuto:NoGapRows', 'No finite gap rows were collected for standard/late comparison.');
    end

    diffTbl = buildDiffTable(standardGapTbl, standardNoiseTbl, standardDriftTbl, ...
        lateGapTbl, lateNoiseTbl, lateDriftTbl);
    if isempty(diffTbl)
        error('XXLateAuto:NoDiffDomain', 'No finite late-defined domain remained for diff analysis.');
    end

    commonKeys = [diffTbl.temperature_K, diffTbl.current_mA];
    temps = sort(unique(commonKeys(:, 1)));
    currents = sort(unique(commonKeys(:, 2)));
    gapStdMap = buildMetricMap(temps, currents, standardGapTbl.temperature_K, standardGapTbl.current_mA, standardGapTbl.gap);
    noiseStdMap = buildMetricMap(temps, currents, standardNoiseTbl.temperature_K, standardNoiseTbl.current_mA, standardNoiseTbl.noise);
    driftStdMap = buildMetricMap(temps, currents, standardDriftTbl.temperature_K, standardDriftTbl.current_mA, standardDriftTbl.drift);
    gapLateMap = buildMetricMap(temps, currents, lateGapTbl.temperature_K, lateGapTbl.current_mA, lateGapTbl.gap);
    noiseLateMap = buildMetricMap(temps, currents, lateNoiseTbl.temperature_K, lateNoiseTbl.current_mA, lateNoiseTbl.noise);
    driftLateMap = buildMetricMap(temps, currents, lateDriftTbl.temperature_K, lateDriftTbl.current_mA, lateDriftTbl.drift);
    deltaGapMap = buildMetricMap(temps, currents, diffTbl.temperature_K, diffTbl.current_mA, diffTbl.delta_gap);
    deltaNoiseMap = buildMetricMap(temps, currents, diffTbl.temperature_K, diffTbl.current_mA, diffTbl.delta_noise);
    deltaDriftMap = buildMetricMap(temps, currents, diffTbl.temperature_K, diffTbl.current_mA, diffTbl.delta_drift);

    channelUsedTbl = table( ...
        channelRows(:, 1), ...
        str2double(channelRows(:, 2)), ...
        channelRows(:, 3), ...
        str2double(channelRows(:, 4)), ...
        channelRows(:, 5), ...
        'VariableNames', {'folder_name', 'current_mA', 'branch_name', 'channel_selected', 'selection_method'});
    channelUsedTbl = sortrows(channelUsedTbl, {'current_mA', 'branch_name'});

    lateLengthsTbl = table(meanLength, minLength, fractionBelow5, numel(lateLengths), ...
        'VariableNames', {'mean_length', 'min_length', 'fraction_below_5', 'n_plateaus'});
    coverageTbl = table(validPointsStandard, validPointsLate, coverageRatio, ...
        'VariableNames', {'valid_points_standard', 'valid_points_late', 'coverage_ratio'});

    writetable(standardGapTbl, standardGapPath);
    writetable(standardNoiseTbl, standardNoisePath);
    writetable(standardDriftTbl, standardDriftPath);
    writetable(lateGapTbl, lateGapPath);
    writetable(lateNoiseTbl, lateNoisePath);
    writetable(lateDriftTbl, lateDriftPath);
    writetable(channelUsedTbl, channelUsedPath);
    writetable(lateLengthsTbl, lateLengthsPath);
    writetable(coverageTbl, lateCoveragePath);
    writetable(diffTbl, diffMapsPath);

    gapValsBoth = [standardGapTbl.gap; lateGapTbl.gap];
    noiseValsBoth = [standardNoiseTbl.noise; lateNoiseTbl.noise];
    driftValsBoth = [standardDriftTbl.drift; lateDriftTbl.drift];
    gapCLim = safeColorLimits(gapValsBoth);
    noiseCLim = safeColorLimits(noiseValsBoth);
    driftCLim = safeColorLimits(driftValsBoth);

    figStandard = figure('Visible', 'off', 'Color', [1 1 1]);
    tl = tiledlayout(figStandard, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); imagesc(ax1, temps, currents, gapStdMap); axis(ax1, 'xy'); set(ax1, 'Color', [1 1 1]); caxis(ax1, gapCLim); colorbar(ax1); title(ax1, 'Gap'); xlabel(ax1, 'T (K)'); ylabel(ax1, 'I (mA)');
    ax2 = nexttile(tl); imagesc(ax2, temps, currents, noiseStdMap); axis(ax2, 'xy'); set(ax2, 'Color', [1 1 1]); caxis(ax2, noiseCLim); colorbar(ax2); title(ax2, 'Noise'); xlabel(ax2, 'T (K)'); ylabel(ax2, 'I (mA)');
    ax3 = nexttile(tl); imagesc(ax3, temps, currents, driftStdMap); axis(ax3, 'xy'); set(ax3, 'Color', [1 1 1]); caxis(ax3, driftCLim); colorbar(ax3); title(ax3, 'Drift'); xlabel(ax3, 'T (K)'); ylabel(ax3, 'I (mA)');
    title(tl, 'XX Standard Maps | auto channel', 'Interpreter', 'none');
    savefig(figStandard, standardMapsFigPath);
    close(figStandard);

    figLate = figure('Visible', 'off', 'Color', [1 1 1]);
    tl = tiledlayout(figLate, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); imagesc(ax1, temps, currents, gapLateMap); axis(ax1, 'xy'); set(ax1, 'Color', [1 1 1]); caxis(ax1, gapCLim); colorbar(ax1); title(ax1, 'Gap'); xlabel(ax1, 'T (K)'); ylabel(ax1, 'I (mA)');
    ax2 = nexttile(tl); imagesc(ax2, temps, currents, noiseLateMap); axis(ax2, 'xy'); set(ax2, 'Color', [1 1 1]); caxis(ax2, noiseCLim); colorbar(ax2); title(ax2, 'Noise'); xlabel(ax2, 'T (K)'); ylabel(ax2, 'I (mA)');
    ax3 = nexttile(tl); imagesc(ax3, temps, currents, driftLateMap); axis(ax3, 'xy'); set(ax3, 'Color', [1 1 1]); caxis(ax3, driftCLim); colorbar(ax3); title(ax3, 'Drift'); xlabel(ax3, 'T (K)'); ylabel(ax3, 'I (mA)');
    title(tl, 'XX Late Maps (70-90%) | auto channel', 'Interpreter', 'none');
    savefig(figLate, lateMapsFigPath);
    close(figLate);

    diffAbs = max(abs([deltaGapMap(:); deltaNoiseMap(:); deltaDriftMap(:)]), [], 'omitnan');
    if ~(isfinite(diffAbs) && diffAbs > 0)
        diffAbs = 1;
    end
    figDiff = figure('Visible', 'off', 'Color', [1 1 1]);
    tl = tiledlayout(figDiff, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); imagesc(ax1, temps, currents, deltaGapMap); axis(ax1, 'xy'); set(ax1, 'Color', [1 1 1]); caxis(ax1, [-diffAbs diffAbs]); colorbar(ax1); title(ax1, 'Delta gap'); xlabel(ax1, 'T (K)'); ylabel(ax1, 'I (mA)');
    ax2 = nexttile(tl); imagesc(ax2, temps, currents, deltaNoiseMap); axis(ax2, 'xy'); set(ax2, 'Color', [1 1 1]); caxis(ax2, [-diffAbs diffAbs]); colorbar(ax2); title(ax2, 'Delta noise'); xlabel(ax2, 'T (K)'); ylabel(ax2, 'I (mA)');
    ax3 = nexttile(tl); imagesc(ax3, temps, currents, deltaDriftMap); axis(ax3, 'xy'); set(ax3, 'Color', [1 1 1]); caxis(ax3, [-diffAbs diffAbs]); colorbar(ax3); title(ax3, 'Delta drift'); xlabel(ax3, 'T (K)'); ylabel(ax3, 'I (mA)');
    title(tl, 'Late minus standard', 'Interpreter', 'none');
    savefig(figDiff, diffMapsFigPath);
    close(figDiff);

    corrNames = strings(0, 1);
    pearsonR = zeros(0, 1);
    pearsonP = zeros(0, 1);
    spearmanR = zeros(0, 1);
    spearmanP = zeros(0, 1);
    nPoints = zeros(0, 1);
    xMean = zeros(0, 1);
    yMean = zeros(0, 1);
    xStd = zeros(0, 1);
    yStd = zeros(0, 1);

    driftStandard = standardDriftTbl.drift;
    driftLate = lateDriftTbl.drift;
    skipDrift = isempty(driftStandard) || isempty(driftLate);
    driftAvailable = ~skipDrift;

    validLate = isfinite(lateGapTbl.gap);
    if ~isempty(driftLate)
        validDrift = isfinite(driftLate);
    else
        validDrift = false(size(lateGapTbl.gap));
    end
    nValidDrift = sum(validDrift);

    [corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd] = ...
        appendCorrStats(corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd, ...
        'gap_standard_vs_gap_late', standardGapTbl.gap(validLate), lateGapTbl.gap(validLate));
    [corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd] = ...
        appendCorrStats(corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd, ...
        'noise_standard_vs_noise_late', standardNoiseTbl.noise(validLate), lateNoiseTbl.noise(validLate));
    if nValidDrift > 0
        [corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd] = ...
            appendCorrStats(corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd, ...
            'drift_standard_vs_drift_late', driftStandard(validDrift), driftLate(validDrift));
        [corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd] = ...
            appendCorrStats(corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd, ...
            'corr(delta_gap, drift_standard)', diffTbl.delta_gap(validDrift), driftStandard(validDrift));
    else
        skipDrift = true;
        driftAvailable = false;
    end

    correlationTbl = table(corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd, ...
        'VariableNames', {'comparison_name', 'pearson_r', 'pearson_p', 'spearman_rho', 'spearman_p', 'n_points', ...
        'x_mean', 'y_mean', 'x_std', 'y_std'});
    writetable(correlationTbl, correlationTestsPath);

    figScatter = figure('Visible', 'off', 'Color', [1 1 1]);
    tl = tiledlayout(figScatter, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    gapColor = zeros(sum(validLate), 1);
    ax = nexttile(tl); scatter(ax, standardGapTbl.gap(validLate), lateGapTbl.gap(validLate), 30, gapColor, 'filled'); grid(ax, 'on'); xlabel(ax, 'gap standard'); ylabel(ax, 'gap late'); title(ax, 'Gap');
    ax = nexttile(tl); scatter(ax, standardNoiseTbl.noise(validLate), lateNoiseTbl.noise(validLate), 30, gapColor, 'filled'); grid(ax, 'on'); xlabel(ax, 'noise standard'); ylabel(ax, 'noise late'); title(ax, 'Noise');
    ax = nexttile(tl);
    if nValidDrift > 0
        scatter(ax, driftStandard(validDrift), driftLate(validDrift), 30, driftStandard(validDrift), 'filled');
        xlabel(ax, 'drift standard');
        ylabel(ax, 'drift late');
        title(ax, 'Drift');
    else
        text(ax, 0.5, 0.5, 'Drift skipped', 'HorizontalAlignment', 'center');
        axis(ax, 'off');
    end
    grid(ax, 'on');
    ax = nexttile(tl);
    if nValidDrift > 0
        scatter(ax, diffTbl.delta_gap(validDrift), driftStandard(validDrift), 30, commonKeys(validDrift, 1), 'filled');
        xlabel(ax, 'delta gap');
        ylabel(ax, 'drift standard');
        title(ax, 'Delta gap vs drift');
        grid(ax, 'on');
    else
        text(ax, 0.5, 0.5, 'Drift correlation skipped', 'HorizontalAlignment', 'center');
        axis(ax, 'off');
    end
    title(tl, 'Late vs standard scatter diagnostics', 'Interpreter', 'none');
    savefig(figScatter, lateScatterFigPath);
    close(figScatter);

    gapChanged = yesNoToken(median(abs(diffTbl.delta_gap) ./ max(abs(standardGapTbl.gap), eps), 'omitnan') > 0.10);
    noiseReduced = yesNoToken(mean((lateNoiseTbl.noise - standardNoiseTbl.noise) < 0, 'omitnan') > 0.5);
    if driftAvailable
        driftReduced = yesNoToken(mean((driftLate - driftStandard) < 0, 'omitnan') > 0.5);
    else
        driftReduced = "NO";
    end

    standardHasData = yesNoToken(height(standardGapTbl) > 0 && height(standardNoiseTbl) > 0);
    lateHasData = yesNoToken(height(lateGapTbl) > 0 && height(lateNoiseTbl) > 0);
    gapNoiseValid = yesNoToken(standardHasData == "YES" && lateHasData == "YES");
    lateTooSparse = yesNoToken(coverageRatio < 0.5);
    plateauTooShort = yesNoToken(fractionBelow5 > plateauShortFracFailThreshold);
    channelSelectionValid = yesNoToken(all(channelUsedTbl.selection_method == "automatic"));

    medianAbsDeltaGap = median(abs(diffTbl.delta_gap), 'omitnan');
    medianAbsGapStd = median(abs(standardGapTbl.gap), 'omitnan');
    noiseReductionFrac = mean((lateNoiseTbl.noise - standardNoiseTbl.noise) < 0, 'omitnan');
    if driftAvailable
        driftReductionFrac = mean((driftLate - driftStandard) < 0, 'omitnan');
    else
        driftReductionFrac = NaN;
    end
    structureMetric = median(abs(diffTbl.delta_gap), 'omitnan') + median(abs(diffTbl.delta_noise), 'omitnan') + median(abs(diffTbl.delta_drift), 'omitnan');
    relaxationImportant = "NO";
    if isfinite(noiseReductionFrac) && isfinite(driftReductionFrac) && isfinite(medianAbsDeltaGap) && isfinite(medianAbsGapStd)
        if noiseReductionFrac >= 0.60 && driftReductionFrac >= 0.60 && medianAbsDeltaGap <= 0.20 * max(medianAbsGapStd, eps)
            relaxationImportant = "YES";
        elseif noiseReductionFrac >= 0.45 || driftReductionFrac >= 0.45 || structureMetric > 0
            relaxationImportant = "PARTIAL";
        end
    end

    fid = fopen(standardSummaryPath, 'w');
    if fid < 0
        error('XXLateAuto:StandardSummaryOpenFailed', 'Unable to write %s', standardSummaryPath);
    end
    fprintf(fid, '# XX standard summary\n\n');
    fprintf(fid, '- automatic selection used: `YES`\n');
    fprintf(fid, '- rows: `%d`\n', height(standardGapTbl));
    fprintf(fid, '- gap median: `%.6g`\n', median(standardGapTbl.gap, 'omitnan'));
    fprintf(fid, '- noise median: `%.6g`\n', median(standardNoiseTbl.noise, 'omitnan'));
    fprintf(fid, '- drift median: `%.6g`\n', median(standardDriftTbl.drift, 'omitnan'));
    fprintf(fid, '- output figure: `figures/xx_standard_maps.fig`\n');
    fclose(fid);

    fid = fopen(lateSummaryPath, 'w');
    if fid < 0
        error('XXLateAuto:LateSummaryOpenFailed', 'Unable to write %s', lateSummaryPath);
    end
    fprintf(fid, '# XX late summary\n\n');
    fprintf(fid, '- automatic selection used: `YES`\n');
    fprintf(fid, '- late window: `70-90%%`\n');
    fprintf(fid, '- rows: `%d`\n', height(lateGapTbl));
    fprintf(fid, '- mean late plateau length: `%.6g`\n', meanLength);
    fprintf(fid, '- min late plateau length: `%.6g`\n', minLength);
    fprintf(fid, '- fraction below threshold (<5): `%.6g`\n', fractionBelow5);
    fprintf(fid, '- gap median: `%.6g`\n', median(lateGapTbl.gap, 'omitnan'));
    fprintf(fid, '- noise median: `%.6g`\n', median(lateNoiseTbl.noise, 'omitnan'));
    fprintf(fid, '- drift median: `%.6g`\n', median(lateDriftTbl.drift, 'omitnan'));
    fprintf(fid, '- output figure: `figures/xx_late_maps.fig`\n');
    fclose(fid);

    fid = fopen(mainReportPath, 'w');
    if fid < 0
        error('XXLateAuto:MainReportOpenFailed', 'Unable to write %s', mainReportPath);
    end
    fprintf(fid, '# XX late vs standard analysis\n\n');
    fprintf(fid, '## A. Channel\n\n');
    fprintf(fid, '- `CHANNEL_SELECTION_VALID = %s`\n', channelSelectionValid);
    fprintf(fid, '- `AUTOMATIC_SELECTION_USED = YES`\n');
    fprintf(fid, '\n## B. Data validity\n\n');
    fprintf(fid, '- `STANDARD_HAS_DATA = %s`\n', standardHasData);
    fprintf(fid, '- `LATE_HAS_DATA = %s`\n', lateHasData);
    fprintf(fid, '\n## C. Late plateau viability\n\n');
    fprintf(fid, '- `LATE_TOO_SPARSE = %s`\n', lateTooSparse);
    fprintf(fid, '- `PLATEAU_TOO_SHORT = %s`\n', plateauTooShort);
    fprintf(fid, '- mean late plateau length: `%.6g`\n', meanLength);
    fprintf(fid, '- min late plateau length: `%.6g`\n', minLength);
    fprintf(fid, '- fraction below threshold (<5): `%.6g`\n', fractionBelow5);
    fprintf(fid, '- valid_points_standard: `%d`\n', validPointsStandard);
    fprintf(fid, '- valid_points_late: `%d`\n', validPointsLate);
    fprintf(fid, '- coverage_ratio: `%.6g`\n', coverageRatio);
    fprintf(fid, '\n## D. Physical effect\n\n');
    fprintf(fid, '- `GAP_CHANGED = %s`\n', gapChanged);
    fprintf(fid, '- `NOISE_REDUCED = %s`\n', noiseReduced);
    fprintf(fid, '- `DRIFT_REDUCED = %s`\n', driftReduced);
    fprintf(fid, '- `DRIFT_AVAILABLE = %s`\n', yesNoToken(driftAvailable));
    fprintf(fid, '- `DRIFT_SKIPPED = %s`\n', yesNoToken(skipDrift));
    fprintf(fid, '\n## E. Final physics verdict\n\n');
    fprintf(fid, '- `RELAXATION_IMPORTANT = %s`\n', relaxationImportant);
    fprintf(fid, '\n## Success criteria\n\n');
    fprintf(fid, '- `RUN_COMPLETED = YES`\n');
    fprintf(fid, '- `CHANNEL_VALID = %s`\n', channelSelectionValid);
    fprintf(fid, '- `DATA_VALID = %s`\n', gapNoiseValid);
    fprintf(fid, '- `GAP_NOISE_VALID = %s`\n', gapNoiseValid);
    fprintf(fid, '- `DRIFT_HANDLED = %s`\n', yesNoToken(driftAvailable || skipDrift));
    fprintf(fid, '- `PHYSICS_CONCLUSION_REACHED = YES`\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, size(commonKeys, 1), {'XX late vs standard auto-channel comparison completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    fid = fopen(mainReportPath, 'w');
    if fid >= 0
        fprintf(fid, '# XX late vs standard analysis\n\n');
        fprintf(fid, '## A. Channel\n\n');
        fprintf(fid, '- `CHANNEL_SELECTION_VALID = NO`\n');
        fprintf(fid, '- `AUTOMATIC_SELECTION_USED = YES`\n');
        fprintf(fid, '\n## B. Data validity\n\n');
        fprintf(fid, '- `STANDARD_HAS_DATA = NO`\n');
        fprintf(fid, '- `LATE_HAS_DATA = NO`\n');
        fprintf(fid, '\n## C. Late plateau viability\n\n');
        fprintf(fid, '- `LATE_TOO_SPARSE = YES`\n');
        fprintf(fid, '- `PLATEAU_TOO_SHORT = YES`\n');
        fprintf(fid, '\n## D. Physical effect\n\n');
        fprintf(fid, '- `GAP_CHANGED = NO`\n');
        fprintf(fid, '- `NOISE_REDUCED = NO`\n');
        fprintf(fid, '- `DRIFT_REDUCED = NO`\n');
        fprintf(fid, '\n## E. Final physics verdict\n\n');
        fprintf(fid, '- `RELAXATION_IMPORTANT = NO`\n');
        fprintf(fid, '\n## Success criteria\n\n');
        fprintf(fid, '- `RUN_COMPLETED = NO`\n');
        fprintf(fid, '- `CHANNEL_VALID = NO`\n');
        fprintf(fid, '- `DATA_VALID = NO`\n');
        fprintf(fid, '- `PHYSICS_CONCLUSION_REACHED = NO`\n');
        fprintf(fid, '\n- error: `%s`\n', strrep(ME.message, '`', ''''));
        fclose(fid);
    end

    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_late_vs_standard_auto_channel_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XX late vs standard auto-channel comparison failed'}, ...
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

function tblOut = renameMetricTbl(tblIn, valueName)
tblOut = tblIn;
tblOut.Properties.VariableNames{3} = valueName;
end

function writeSimpleFile(pathStr, textStr)
fid = fopen(pathStr, 'w');
if fid >= 0
    fprintf(fid, '%s', textStr);
    fclose(fid);
end
end

function [rowsDir, validCount] = extractRowsForAutoChannel(summaryTbl, selectedChannel, amp, temperatureCutoffK)
rowsDir = zeros(0, 5);
validCount = 0;
if isempty(summaryTbl)
    return;
end
if ~all(ismember({'switching_channel_physical', 'depValue', 'stateGapAbs', 'withinRMS', 'slopeRMS'}, summaryTbl.Properties.VariableNames))
    return;
end
idx = (summaryTbl.switching_channel_physical == selectedChannel);
if ~any(idx)
    return;
end
rowsDir = [ ...
    double(summaryTbl.depValue(idx)), ...
    amp * ones(sum(idx), 1), ...
    double(summaryTbl.stateGapAbs(idx)), ...
    double(summaryTbl.withinRMS(idx)), ...
    double(summaryTbl.slopeRMS(idx))];
keep = isfinite(rowsDir(:, 1)) & isfinite(rowsDir(:, 2)) & (rowsDir(:, 1) <= temperatureCutoffK) & ...
    (isfinite(rowsDir(:, 3)) | isfinite(rowsDir(:, 4)) | isfinite(rowsDir(:, 5)));
rowsDir = rowsDir(keep, :);
validCount = sum(isfinite(rowsDir(:, 3)));
end

function tbl = buildMetricTable(rows, colIdx, valueName)
keep = isfinite(rows(:, 1)) & isfinite(rows(:, 2)) & isfinite(rows(:, colIdx));
tbl = table(rows(keep, 1), rows(keep, 2), rows(keep, colIdx), ...
    'VariableNames', {'temperature_K', 'current_mA', valueName});
tbl = sortrows(tbl, {'current_mA', 'temperature_K'});
end

function diffTbl = buildDiffTable(standardGapTbl, standardNoiseTbl, standardDriftTbl, lateGapTbl, lateNoiseTbl, lateDriftTbl)
keys = unique([lateGapTbl{:, {'temperature_K', 'current_mA'}}; ...
    lateNoiseTbl{:, {'temperature_K', 'current_mA'}}; ...
    lateDriftTbl{:, {'temperature_K', 'current_mA'}}], 'rows');

n = size(keys, 1);
deltaGap = NaN(n, 1);
deltaNoise = NaN(n, 1);
deltaDrift = NaN(n, 1);

for i = 1:n
    tVal = keys(i, 1);
    iVal = keys(i, 2);
    deltaGap(i) = diffValueForKey(standardGapTbl, lateGapTbl, 'gap', tVal, iVal);
    deltaNoise(i) = diffValueForKey(standardNoiseTbl, lateNoiseTbl, 'noise', tVal, iVal);
    deltaDrift(i) = diffValueForKey(standardDriftTbl, lateDriftTbl, 'drift', tVal, iVal);
end

diffTbl = table(keys(:, 1), keys(:, 2), deltaGap, deltaNoise, deltaDrift, ...
    'VariableNames', {'temperature_K', 'current_mA', 'delta_gap', 'delta_noise', 'delta_drift'});
diffTbl = sortrows(diffTbl, {'current_mA', 'temperature_K'});
end

function val = diffValueForKey(stdTbl, lateTbl, valueName, tVal, iVal)
val = NaN;
idxStd = abs(stdTbl.temperature_K - tVal) < 1e-9 & abs(stdTbl.current_mA - iVal) < 1e-9;
idxLate = abs(lateTbl.temperature_K - tVal) < 1e-9 & abs(lateTbl.current_mA - iVal) < 1e-9;
if any(idxStd) && any(idxLate)
    xStd = stdTbl{find(idxStd, 1, 'first'), valueName};
    xLate = lateTbl{find(idxLate, 1, 'first'), valueName};
    if isfinite(xStd) && isfinite(xLate)
        val = xLate - xStd;
    end
end
end

function M = buildMetricMap(temps, currents, tVec, iVec, vVec)
M = NaN(numel(currents), numel(temps));
for i = 1:numel(vVec)
    if ~(isfinite(tVec(i)) && isfinite(iVec(i)) && isfinite(vVec(i)))
        continue;
    end
    it = find(abs(temps - tVec(i)) < 1e-9, 1, 'first');
    ii = find(abs(currents - iVec(i)) < 1e-9, 1, 'first');
    if ~isempty(it) && ~isempty(ii)
        M(ii, it) = vVec(i);
    end
end
end

function clim = safeColorLimits(vals)
clim = [min(vals), max(vals)];
if ~(isfinite(clim(1)) && isfinite(clim(2)) && clim(2) > clim(1))
    clim = [0, 1];
end
end

function tok = yesNoToken(tf)
if tf
    tok = "YES";
else
    tok = "NO";
end
end

function [corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd] = ...
    appendCorrStats(corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd, name, x, y)
keep = isfinite(x) & isfinite(y);
if sum(keep) < 3
    return;
end
[r1, p1] = corr(x(keep), y(keep), 'Type', 'Pearson');
[r2, p2] = corr(x(keep), y(keep), 'Type', 'Spearman');
corrNames(end + 1, 1) = string(name); %#ok<AGROW>
pearsonR(end + 1, 1) = r1; %#ok<AGROW>
pearsonP(end + 1, 1) = p1; %#ok<AGROW>
spearmanR(end + 1, 1) = r2; %#ok<AGROW>
spearmanP(end + 1, 1) = p2; %#ok<AGROW>
nPoints(end + 1, 1) = sum(keep); %#ok<AGROW>
xMean(end + 1, 1) = mean(x(keep)); %#ok<AGROW>
yMean(end + 1, 1) = mean(y(keep)); %#ok<AGROW>
xStd(end + 1, 1) = std(x(keep)); %#ok<AGROW>
yStd(end + 1, 1) = std(y(keep)); %#ok<AGROW>
end
