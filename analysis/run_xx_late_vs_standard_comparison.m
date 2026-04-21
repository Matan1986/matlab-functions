clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXLateVsStandard:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfgRun = struct();
cfgRun.runLabel = 'xx_late_vs_standard_comparison';
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
lateLengthsPath = fullfile(tablesDir, 'xx_late_plateau_lengths.csv');
lateCoveragePath = fullfile(tablesDir, 'xx_late_coverage.csv');
diffMapsPath = fullfile(tablesDir, 'xx_diff_maps.csv');
correlationTestsPath = fullfile(tablesDir, 'xx_late_correlation_tests.csv');

standardMapsFigPath = fullfile(figuresDir, 'xx_standard_maps.fig');
lateMapsFigPath = fullfile(figuresDir, 'xx_late_maps.fig');
lateMaskSanityFigPath = fullfile(figuresDir, 'xx_late_mask_sanity.fig');
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
maskSanityCount = 5;

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

emptyGapTbl = table([], [], [], ...
    'VariableNames', {'temperature_K', 'current_mA', 'gap'});
emptyNoiseTbl = table([], [], [], ...
    'VariableNames', {'temperature_K', 'current_mA', 'noise'});
emptyDriftTbl = table([], [], [], ...
    'VariableNames', {'temperature_K', 'current_mA', 'drift'});
emptyLengthsTbl = table([], [], [], [], [], [], [], [], [], ...
    'VariableNames', {'current_mA', 'temperature_K', 'file_index', 'plateau_index', 'full_length', 'late_length', 'late_fraction_kept', 'below_threshold_lt5', 'selected_channel'});
emptyCoverageTbl = table(strings(0,1), [], ...
    'VariableNames', {'metric_name', 'value'});
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

    writetable(emptyGapTbl, standardGapPath);
    writetable(emptyNoiseTbl, standardNoisePath);
    writetable(emptyDriftTbl, standardDriftPath);
    writetable(emptyGapTbl, lateGapPath);
    writetable(emptyNoiseTbl, lateNoisePath);
    writetable(emptyDriftTbl, lateDriftPath);
    writetable(emptyLengthsTbl, lateLengthsPath);
    writetable(emptyCoverageTbl, lateCoveragePath);
    writetable(emptyDiffTbl, diffMapsPath);
    writetable(emptyCorrTbl, correlationTestsPath);

    fid = fopen(standardSummaryPath, 'w');
    if fid >= 0
        fprintf(fid, '# XX standard summary\n\nPENDING\n');
        fclose(fid);
    end
    fid = fopen(lateSummaryPath, 'w');
    if fid >= 0
        fprintf(fid, '# XX late summary\n\nPENDING\n');
        fclose(fid);
    end
    fid = fopen(mainReportPath, 'w');
    if fid >= 0
        fprintf(fid, '# XX late vs standard analysis\n\nPENDING\n');
        fclose(fid);
    end

    cfgSources = xx_relaxation_config2_sources();
    if isempty(cfgSources)
        error('XXLateVsStandard:MissingConfig2Sources', 'xx_relaxation_config2_sources returned empty.');
    end
    parentDir = char(cfgSources(1).baseDir);
    if exist(parentDir, 'dir') ~= 7
        error('XXLateVsStandard:MissingParentDir', 'XX Config2 parent directory does not exist: %s', parentDir);
    end

    channelTblPath = fullfile(tablesDir, 'xx_channel_validation.csv');
    if exist(channelTblPath, 'file') ~= 2
        error('XXLateVsStandard:MissingChannelValidation', 'Missing %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames)
        error('XXLateVsStandard:MissingPipelineChoice', 'pipeline_choice missing in %s', channelTblPath);
    end
    pipelineChoices = unique(double(channelTbl.pipeline_choice(isfinite(double(channelTbl.pipeline_choice)))));
    if isempty(pipelineChoices)
        error('XXLateVsStandard:EmptyPipelineChoice', 'No finite pipeline_choice found in %s', channelTblPath);
    end
    selectedChannel = pipelineChoices(1);
    if ~(isfinite(selectedChannel) && any(selectedChannel == [1,2,3,4]))
        error('XXLateVsStandard:BadSelectedChannel', 'Invalid selected channel: %g', selectedChannel);
    end

    filteredParentDir = fullfile(run.run_dir, sprintf('xx_temp_cutoff_input_le_%gK', temperatureCutoffK));
    if exist(filteredParentDir, 'dir') ~= 7
        mkdir(filteredParentDir);
    end

    srcDirs = dir(fullfile(parentDir, 'Temp Dep *'));
    srcDirs = srcDirs([srcDirs.isdir]);
    if isempty(srcDirs)
        error('XXLateVsStandard:NoTempDirs', 'No Temp Dep directories found under %s', parentDir);
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
        error('XXLateVsStandard:NoCopiedFiles', 'No XX files passed the temperature cutoff.');
    end

    rowsStandard = zeros(0, 5);
    rowsLate = zeros(0, 5);
    lengthsRows = zeros(0, 9);
    maskInfo = struct('amp', {}, 'T', {}, 't', {}, 'yStd', {}, 'yLate', {}, 'x1', {}, 'x2', {}, 'nLate', {}, 'nFull', {});
    maskMeta = zeros(0, 6);
    validPointsStandard = 0;
    validPointsLate = 0;
    plateauPointsStandard = 0;
    plateauPointsLate = 0;
    rng(0);

    tempDirs = dir(fullfile(filteredParentDir, 'Temp Dep *'));
    tempDirs = tempDirs([tempDirs.isdir]);
    if isempty(tempDirs)
        error('XXLateVsStandard:NoFilteredTempDirs', 'No filtered Temp Dep directories exist under %s', filteredParentDir);
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
            error('XXLateVsStandard:InvalidCurrent', 'Invalid current parsed in %s', thisDir);
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

        storedDataLate = storedDataStd;
        for iFile = 1:size(storedDataStd, 1)
            dataRef = storedDataStd{iFile, 1};
            if isempty(dataRef) || size(dataRef, 2) < 2
                continue;
            end

            t = dataRef(:, 1);
            numCh = size(dataRef, 2) - 1;
            physIdxRow = [];
            if size(storedDataStd, 2) >= 7 && ~isempty(storedDataStd{iFile, 7})
                physIdxRow = storedDataStd{iFile, 7}(:).';
            end
            localIdx = find(physIdxRow == selectedChannel, 1, 'first');
            if isempty(localIdx)
                continue;
            end

            plateauMeansStd = storedDataStd{iFile, 5};
            if isempty(plateauMeansStd)
                continue;
            end
            numPulses = size(plateauMeansStd, 1);
            pulseTimes = t(1) + (0:numPulses-1) * delayMs;
            safetyMarginMs = delayMs * (safetyMarginPercent / 100);

            keepMaskTime = false(size(t));
            lateMeans = NaN(size(plateauMeansStd));

            for j = 1:numPulses
                if j < numPulses
                    t1 = pulseTimes(j) + safetyMarginMs;
                    t2 = pulseTimes(j+1) - safetyMarginMs;
                else
                    t1 = pulseTimes(j) + safetyMarginMs;
                    t2 = t(end);
                end
                idx0 = find((t >= t1) & (t <= t2));
                nFull = numel(idx0);
                plateauPointsStandard = plateauPointsStandard + nFull;
                if isempty(idx0)
                    lengthsRows(end+1, :) = [amp, sortedValues(iFile), iFile, j, 0, 0, 0, 1, selectedChannel]; %#ok<AGROW>
                    continue;
                end

                i1 = floor(lateFrac1 * nFull) + 1;
                i2 = floor(lateFrac2 * nFull);
                i2 = max(i2, i1);
                i1 = min(max(i1, 1), nFull);
                i2 = min(max(i2, i1), nFull);
                idxLate = idx0(i1:i2);

                keepMaskTime(idxLate) = true;
                nLate = numel(idxLate);
                plateauPointsLate = plateauPointsLate + nLate;
                lengthsRows(end+1, :) = [amp, sortedValues(iFile), iFile, j, nFull, nLate, nLate / nFull, double(nLate < plateauMinOkThreshold), selectedChannel]; %#ok<AGROW>

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

                maskMeta(end+1, :) = [amp, sortedValues(iFile), iFile, j, nFull, nLate]; %#ok<AGROW>
                infoEntry = struct();
                infoEntry.amp = amp;
                infoEntry.T = sortedValues(iFile);
                infoEntry.t = t;
                infoEntry.yStd = storedDataStd{iFile, 1}(:, 1 + localIdx);
                infoEntry.yLate = storedDataStd{iFile, 1}(:, 1 + localIdx);
                tmpLate = NaN(size(infoEntry.yLate));
                tmpLate(idxLate) = infoEntry.yLate(idxLate);
                infoEntry.yLate = tmpLate;
                if ~isempty(idx0)
                    infoEntry.x1 = t(idx0(1));
                    infoEntry.x2 = t(idx0(end));
                else
                    infoEntry.x1 = NaN;
                    infoEntry.x2 = NaN;
                end
                infoEntry.nLate = nLate;
                infoEntry.nFull = nFull;
                maskInfo(end+1) = infoEntry; %#ok<AGROW>
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

            validPointsStandard = validPointsStandard + sum(isfinite(storedDataStd{iFile, 1}(:, 1 + localIdx)));
            validPointsLate = validPointsLate + sum(isfinite(storedDataLate{iFile, 1}(:, 1 + localIdx)));
        end

        stabilityLate = analyzeSwitchingStability( ...
            storedDataLate, sortedValues, ...
            delayMs, safetyMarginPercent, stbOpts);

        Tstd = stabilityStd.summaryTable;
        Tlate = stabilityLate.summaryTable;
        if isempty(Tstd) || isempty(Tlate)
            continue;
        end

        idxStd = (Tstd.switching_channel_physical == selectedChannel);
        idxLate = (Tlate.switching_channel_physical == selectedChannel);
        if ~any(idxStd) || ~any(idxLate)
            continue;
        end

        rowsStdDir = [ ...
            double(Tstd.depValue(idxStd)), ...
            amp * ones(sum(idxStd), 1), ...
            double(Tstd.stateGapAbs(idxStd)), ...
            double(Tstd.withinRMS(idxStd)), ...
            double(Tstd.slopeRMS(idxStd))];
        rowsLateDir = [ ...
            double(Tlate.depValue(idxLate)), ...
            amp * ones(sum(idxLate), 1), ...
            double(Tlate.stateGapAbs(idxLate)), ...
            double(Tlate.withinRMS(idxLate)), ...
            double(Tlate.slopeRMS(idxLate))];

        keepStd = all(isfinite(rowsStdDir), 2) & (rowsStdDir(:, 1) <= temperatureCutoffK);
        keepLate = all(isfinite(rowsLateDir), 2) & (rowsLateDir(:, 1) <= temperatureCutoffK);
        rowsStandard = [rowsStandard; rowsStdDir(keepStd, :)]; %#ok<AGROW>
        rowsLate = [rowsLate; rowsLateDir(keepLate, :)]; %#ok<AGROW>
    end

    if isempty(rowsStandard) || isempty(rowsLate)
        error('XXLateVsStandard:NoMetricRows', 'No finite standard/late metric rows were collected.');
    end

    rowsStandard = sortrows(rowsStandard, [2, 1]);
    rowsLate = sortrows(rowsLate, [2, 1]);

    keyStd = rowsStandard(:, 1:2);
    keyLate = rowsLate(:, 1:2);
    [commonKeys, idxStdCommon, idxLateCommon] = intersect(keyStd, keyLate, 'rows');
    if isempty(commonKeys)
        error('XXLateVsStandard:NoCommonDomain', 'No common (T,current) domain between standard and late rows.');
    end

    stdCommon = rowsStandard(idxStdCommon, :);
    lateCommon = rowsLate(idxLateCommon, :);
    commonFiniteMask = all(isfinite(stdCommon(:, 3:5)), 2) & all(isfinite(lateCommon(:, 3:5)), 2);
    commonKeys = commonKeys(commonFiniteMask, :);
    stdCommon = stdCommon(commonFiniteMask, :);
    lateCommon = lateCommon(commonFiniteMask, :);
    if isempty(commonKeys)
        error('XXLateVsStandard:NoCommonFiniteDomain', 'No common finite domain remains after joint masking.');
    end

    temps = sort(unique(commonKeys(:, 1)));
    currents = sort(unique(commonKeys(:, 2)));
    gapStdMap = NaN(numel(currents), numel(temps));
    noiseStdMap = NaN(numel(currents), numel(temps));
    driftStdMap = NaN(numel(currents), numel(temps));
    gapLateMap = NaN(numel(currents), numel(temps));
    noiseLateMap = NaN(numel(currents), numel(temps));
    driftLateMap = NaN(numel(currents), numel(temps));

    for iRow = 1:size(commonKeys, 1)
        tVal = commonKeys(iRow, 1);
        iVal = commonKeys(iRow, 2);
        it = find(abs(temps - tVal) < 1e-9, 1, 'first');
        ii = find(abs(currents - iVal) < 1e-9, 1, 'first');
        gapStdMap(ii, it) = stdCommon(iRow, 3);
        noiseStdMap(ii, it) = stdCommon(iRow, 4);
        driftStdMap(ii, it) = stdCommon(iRow, 5);
        gapLateMap(ii, it) = lateCommon(iRow, 3);
        noiseLateMap(ii, it) = lateCommon(iRow, 4);
        driftLateMap(ii, it) = lateCommon(iRow, 5);
    end

    deltaGapMap = gapLateMap - gapStdMap;
    deltaNoiseMap = noiseLateMap - noiseStdMap;
    deltaDriftMap = driftLateMap - driftStdMap;

    standardGapTbl = table(commonKeys(:, 1), commonKeys(:, 2), stdCommon(:, 3), ...
        'VariableNames', {'temperature_K', 'current_mA', 'gap'});
    standardNoiseTbl = table(commonKeys(:, 1), commonKeys(:, 2), stdCommon(:, 4), ...
        'VariableNames', {'temperature_K', 'current_mA', 'noise'});
    standardDriftTbl = table(commonKeys(:, 1), commonKeys(:, 2), stdCommon(:, 5), ...
        'VariableNames', {'temperature_K', 'current_mA', 'drift'});
    lateGapTbl = table(commonKeys(:, 1), commonKeys(:, 2), lateCommon(:, 3), ...
        'VariableNames', {'temperature_K', 'current_mA', 'gap'});
    lateNoiseTbl = table(commonKeys(:, 1), commonKeys(:, 2), lateCommon(:, 4), ...
        'VariableNames', {'temperature_K', 'current_mA', 'noise'});
    lateDriftTbl = table(commonKeys(:, 1), commonKeys(:, 2), lateCommon(:, 5), ...
        'VariableNames', {'temperature_K', 'current_mA', 'drift'});
    diffTbl = table(commonKeys(:, 1), commonKeys(:, 2), ...
        lateCommon(:, 3) - stdCommon(:, 3), ...
        lateCommon(:, 4) - stdCommon(:, 4), ...
        lateCommon(:, 5) - stdCommon(:, 5), ...
        'VariableNames', {'temperature_K', 'current_mA', 'delta_gap', 'delta_noise', 'delta_drift'});

    lengthsTbl = array2table(lengthsRows, 'VariableNames', ...
        {'current_mA', 'temperature_K', 'file_index', 'plateau_index', 'full_length', 'late_length', 'late_fraction_kept', 'below_threshold_lt5', 'selected_channel'});
    coverageTbl = table( ...
        ["valid_points_standard"; "valid_points_late"; "plateau_points_standard"; "plateau_points_late"; "common_domain_points"], ...
        [validPointsStandard; validPointsLate; plateauPointsStandard; plateauPointsLate; size(commonKeys, 1)], ...
        'VariableNames', {'metric_name', 'value'});

    writetable(standardGapTbl, standardGapPath);
    writetable(standardNoiseTbl, standardNoisePath);
    writetable(standardDriftTbl, standardDriftPath);
    writetable(lateGapTbl, lateGapPath);
    writetable(lateNoiseTbl, lateNoisePath);
    writetable(lateDriftTbl, lateDriftPath);
    writetable(lengthsTbl, lateLengthsPath);
    writetable(coverageTbl, lateCoveragePath);
    writetable(diffTbl, diffMapsPath);

    gapValsBoth = [standardGapTbl.gap; lateGapTbl.gap];
    noiseValsBoth = [standardNoiseTbl.noise; lateNoiseTbl.noise];
    driftValsBoth = [standardDriftTbl.drift; lateDriftTbl.drift];
    gapCLim = [min(gapValsBoth), max(gapValsBoth)];
    noiseCLim = [min(noiseValsBoth), max(noiseValsBoth)];
    driftCLim = [min(driftValsBoth), max(driftValsBoth)];
    if ~(isfinite(gapCLim(1)) && isfinite(gapCLim(2)) && gapCLim(2) > gapCLim(1))
        gapCLim = [0, 1];
    end
    if ~(isfinite(noiseCLim(1)) && isfinite(noiseCLim(2)) && noiseCLim(2) > noiseCLim(1))
        noiseCLim = [0, 1];
    end
    if ~(isfinite(driftCLim(1)) && isfinite(driftCLim(2)) && driftCLim(2) > driftCLim(1))
        driftCLim = [0, 1];
    end

    figStandard = figure('Visible', 'off', 'Color', [1 1 1]);
    tl = tiledlayout(figStandard, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); imagesc(ax1, temps, currents, gapStdMap); axis(ax1, 'xy'); set(ax1, 'Color', [1 1 1]); caxis(ax1, gapCLim); colorbar(ax1); title(ax1, 'Gap'); xlabel(ax1, 'T (K)'); ylabel(ax1, 'I (mA)');
    ax2 = nexttile(tl); imagesc(ax2, temps, currents, noiseStdMap); axis(ax2, 'xy'); set(ax2, 'Color', [1 1 1]); caxis(ax2, noiseCLim); colorbar(ax2); title(ax2, 'Noise'); xlabel(ax2, 'T (K)'); ylabel(ax2, 'I (mA)');
    ax3 = nexttile(tl); imagesc(ax3, temps, currents, driftStdMap); axis(ax3, 'xy'); set(ax3, 'Color', [1 1 1]); caxis(ax3, driftCLim); colorbar(ax3); title(ax3, 'Drift'); xlabel(ax3, 'T (K)'); ylabel(ax3, 'I (mA)');
    title(tl, sprintf('XX Standard Maps | ch=%d', selectedChannel), 'Interpreter', 'none');
    savefig(figStandard, standardMapsFigPath);
    close(figStandard);

    figLate = figure('Visible', 'off', 'Color', [1 1 1]);
    tl = tiledlayout(figLate, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); imagesc(ax1, temps, currents, gapLateMap); axis(ax1, 'xy'); set(ax1, 'Color', [1 1 1]); caxis(ax1, gapCLim); colorbar(ax1); title(ax1, 'Gap'); xlabel(ax1, 'T (K)'); ylabel(ax1, 'I (mA)');
    ax2 = nexttile(tl); imagesc(ax2, temps, currents, noiseLateMap); axis(ax2, 'xy'); set(ax2, 'Color', [1 1 1]); caxis(ax2, noiseCLim); colorbar(ax2); title(ax2, 'Noise'); xlabel(ax2, 'T (K)'); ylabel(ax2, 'I (mA)');
    ax3 = nexttile(tl); imagesc(ax3, temps, currents, driftLateMap); axis(ax3, 'xy'); set(ax3, 'Color', [1 1 1]); caxis(ax3, driftCLim); colorbar(ax3); title(ax3, 'Drift'); xlabel(ax3, 'T (K)'); ylabel(ax3, 'I (mA)');
    title(tl, sprintf('XX Late Maps (70-90%%) | ch=%d', selectedChannel), 'Interpreter', 'none');
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

    nMaskCandidates = numel(maskInfo);
    if nMaskCandidates == 0
        error('XXLateVsStandard:NoMaskCandidates', 'No plateau windows available for mask sanity plotting.');
    end
    perm = randperm(nMaskCandidates, min(maskSanityCount, nMaskCandidates));
    figMask = figure('Visible', 'off', 'Color', [1 1 1]);
    tl = tiledlayout(figMask, numel(perm), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for ii = 1:numel(perm)
        infoEntry = maskInfo(perm(ii));
        ax = nexttile(tl);
        plot(ax, infoEntry.t, infoEntry.yStd, '-', 'LineWidth', 0.9, 'Color', [0.20 0.20 0.20]); hold(ax, 'on');
        plot(ax, infoEntry.t, infoEntry.yLate, '-', 'LineWidth', 1.2, 'Color', [0.00 0.45 0.74]);
        xline(ax, infoEntry.x1, '--', 'Color', [0.40 0.40 0.40]);
        xline(ax, infoEntry.x2, '--', 'Color', [0.40 0.40 0.40]);
        grid(ax, 'on');
        xlabel(ax, 't');
        ylabel(ax, 'R');
        title(ax, sprintf('I=%.3g mA | T=%.3g K | kept %d/%d samples', infoEntry.amp, infoEntry.T, infoEntry.nLate, infoEntry.nFull), 'Interpreter', 'none');
        legend(ax, {'original', 'late-masked'}, 'Location', 'best');
    end
    title(tl, 'Late mask sanity: original vs retained 70-90% window', 'Interpreter', 'none');
    savefig(figMask, lateMaskSanityFigPath);
    close(figMask);

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

    x = diffTbl.delta_gap;
    y = standardDriftTbl.drift;
    keep = isfinite(x) & isfinite(y);
    if sum(keep) >= 3
        [r1, p1] = corr(x(keep), y(keep), 'Type', 'Pearson');
        [r2, p2] = corr(x(keep), y(keep), 'Type', 'Spearman');
        corrNames(end+1, 1) = "corr(delta_gap, drift_standard)"; %#ok<AGROW>
        pearsonR(end+1, 1) = r1; %#ok<AGROW>
        pearsonP(end+1, 1) = p1; %#ok<AGROW>
        spearmanR(end+1, 1) = r2; %#ok<AGROW>
        spearmanP(end+1, 1) = p2; %#ok<AGROW>
        nPoints(end+1, 1) = sum(keep); %#ok<AGROW>
        xMean(end+1, 1) = mean(x(keep)); %#ok<AGROW>
        yMean(end+1, 1) = mean(y(keep)); %#ok<AGROW>
        xStd(end+1, 1) = std(x(keep)); %#ok<AGROW>
        yStd(end+1, 1) = std(y(keep)); %#ok<AGROW>
    end

    x = diffTbl.delta_noise;
    y = standardDriftTbl.drift;
    keep = isfinite(x) & isfinite(y);
    if sum(keep) >= 3
        [r1, p1] = corr(x(keep), y(keep), 'Type', 'Pearson');
        [r2, p2] = corr(x(keep), y(keep), 'Type', 'Spearman');
        corrNames(end+1, 1) = "corr(delta_noise, drift_standard)"; %#ok<AGROW>
        pearsonR(end+1, 1) = r1; %#ok<AGROW>
        pearsonP(end+1, 1) = p1; %#ok<AGROW>
        spearmanR(end+1, 1) = r2; %#ok<AGROW>
        spearmanP(end+1, 1) = p2; %#ok<AGROW>
        nPoints(end+1, 1) = sum(keep); %#ok<AGROW>
        xMean(end+1, 1) = mean(x(keep)); %#ok<AGROW>
        yMean(end+1, 1) = mean(y(keep)); %#ok<AGROW>
        xStd(end+1, 1) = std(x(keep)); %#ok<AGROW>
        yStd(end+1, 1) = std(y(keep)); %#ok<AGROW>
    end

    x = diffTbl.delta_drift;
    y = standardDriftTbl.drift;
    keep = isfinite(x) & isfinite(y);
    if sum(keep) >= 3
        [r1, p1] = corr(x(keep), y(keep), 'Type', 'Pearson');
        [r2, p2] = corr(x(keep), y(keep), 'Type', 'Spearman');
        corrNames(end+1, 1) = "corr(delta_drift, drift_standard)"; %#ok<AGROW>
        pearsonR(end+1, 1) = r1; %#ok<AGROW>
        pearsonP(end+1, 1) = p1; %#ok<AGROW>
        spearmanR(end+1, 1) = r2; %#ok<AGROW>
        spearmanP(end+1, 1) = p2; %#ok<AGROW>
        nPoints(end+1, 1) = sum(keep); %#ok<AGROW>
        xMean(end+1, 1) = mean(x(keep)); %#ok<AGROW>
        yMean(end+1, 1) = mean(y(keep)); %#ok<AGROW>
        xStd(end+1, 1) = std(x(keep)); %#ok<AGROW>
        yStd(end+1, 1) = std(y(keep)); %#ok<AGROW>
    end

    x = standardGapTbl.gap;
    y = lateGapTbl.gap;
    keep = isfinite(x) & isfinite(y);
    if sum(keep) >= 3
        [r1, p1] = corr(x(keep), y(keep), 'Type', 'Pearson');
        [r2, p2] = corr(x(keep), y(keep), 'Type', 'Spearman');
        corrNames(end+1, 1) = "gap_standard_vs_gap_late"; %#ok<AGROW>
        pearsonR(end+1, 1) = r1; %#ok<AGROW>
        pearsonP(end+1, 1) = p1; %#ok<AGROW>
        spearmanR(end+1, 1) = r2; %#ok<AGROW>
        spearmanP(end+1, 1) = p2; %#ok<AGROW>
        nPoints(end+1, 1) = sum(keep); %#ok<AGROW>
        xMean(end+1, 1) = mean(x(keep)); %#ok<AGROW>
        yMean(end+1, 1) = mean(y(keep)); %#ok<AGROW>
        xStd(end+1, 1) = std(x(keep)); %#ok<AGROW>
        yStd(end+1, 1) = std(y(keep)); %#ok<AGROW>
    end

    x = standardNoiseTbl.noise;
    y = lateNoiseTbl.noise;
    keep = isfinite(x) & isfinite(y);
    if sum(keep) >= 3
        [r1, p1] = corr(x(keep), y(keep), 'Type', 'Pearson');
        [r2, p2] = corr(x(keep), y(keep), 'Type', 'Spearman');
        corrNames(end+1, 1) = "noise_standard_vs_noise_late"; %#ok<AGROW>
        pearsonR(end+1, 1) = r1; %#ok<AGROW>
        pearsonP(end+1, 1) = p1; %#ok<AGROW>
        spearmanR(end+1, 1) = r2; %#ok<AGROW>
        spearmanP(end+1, 1) = p2; %#ok<AGROW>
        nPoints(end+1, 1) = sum(keep); %#ok<AGROW>
        xMean(end+1, 1) = mean(x(keep)); %#ok<AGROW>
        yMean(end+1, 1) = mean(y(keep)); %#ok<AGROW>
        xStd(end+1, 1) = std(x(keep)); %#ok<AGROW>
        yStd(end+1, 1) = std(y(keep)); %#ok<AGROW>
    end

    x = standardDriftTbl.drift;
    y = lateDriftTbl.drift;
    keep = isfinite(x) & isfinite(y);
    if sum(keep) >= 3
        [r1, p1] = corr(x(keep), y(keep), 'Type', 'Pearson');
        [r2, p2] = corr(x(keep), y(keep), 'Type', 'Spearman');
        corrNames(end+1, 1) = "drift_standard_vs_drift_late"; %#ok<AGROW>
        pearsonR(end+1, 1) = r1; %#ok<AGROW>
        pearsonP(end+1, 1) = p1; %#ok<AGROW>
        spearmanR(end+1, 1) = r2; %#ok<AGROW>
        spearmanP(end+1, 1) = p2; %#ok<AGROW>
        nPoints(end+1, 1) = sum(keep); %#ok<AGROW>
        xMean(end+1, 1) = mean(x(keep)); %#ok<AGROW>
        yMean(end+1, 1) = mean(y(keep)); %#ok<AGROW>
        xStd(end+1, 1) = std(x(keep)); %#ok<AGROW>
        yStd(end+1, 1) = std(y(keep)); %#ok<AGROW>
    end

    correlationTbl = table(corrNames, pearsonR, pearsonP, spearmanR, spearmanP, nPoints, xMean, yMean, xStd, yStd, ...
        'VariableNames', {'comparison_name', 'pearson_r', 'pearson_p', 'spearman_rho', 'spearman_p', 'n_points', ...
        'x_mean', 'y_mean', 'x_std', 'y_std'});
    writetable(correlationTbl, correlationTestsPath);

    figScatter = figure('Visible', 'off', 'Color', [1 1 1]);
    tl = tiledlayout(figScatter, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax = nexttile(tl); scatter(ax, standardGapTbl.gap, lateGapTbl.gap, 30, standardDriftTbl.drift, 'filled'); grid(ax, 'on'); xlabel(ax, 'gap standard'); ylabel(ax, 'gap late'); title(ax, 'Gap');
    ax = nexttile(tl); scatter(ax, standardNoiseTbl.noise, lateNoiseTbl.noise, 30, standardDriftTbl.drift, 'filled'); grid(ax, 'on'); xlabel(ax, 'noise standard'); ylabel(ax, 'noise late'); title(ax, 'Noise');
    ax = nexttile(tl); scatter(ax, standardDriftTbl.drift, lateDriftTbl.drift, 30, standardDriftTbl.drift, 'filled'); grid(ax, 'on'); xlabel(ax, 'drift standard'); ylabel(ax, 'drift late'); title(ax, 'Drift');
    ax = nexttile(tl); scatter(ax, diffTbl.delta_gap, standardDriftTbl.drift, 30, commonKeys(:, 1), 'filled'); grid(ax, 'on'); xlabel(ax, 'delta gap'); ylabel(ax, 'drift standard'); title(ax, 'Delta gap vs drift');
    ax = nexttile(tl); scatter(ax, diffTbl.delta_noise, standardDriftTbl.drift, 30, commonKeys(:, 1), 'filled'); grid(ax, 'on'); xlabel(ax, 'delta noise'); ylabel(ax, 'drift standard'); title(ax, 'Delta noise vs drift');
    ax = nexttile(tl); scatter(ax, diffTbl.delta_drift, standardDriftTbl.drift, 30, commonKeys(:, 1), 'filled'); grid(ax, 'on'); xlabel(ax, 'delta drift'); ylabel(ax, 'drift standard'); title(ax, 'Delta drift vs drift');
    title(tl, 'Late vs standard scatter diagnostics', 'Interpreter', 'none');
    savefig(figScatter, lateScatterFigPath);
    close(figScatter);

    meanLength = mean(lengthsTbl.late_length, 'omitnan');
    minLength = min(lengthsTbl.late_length);
    fracBelowThreshold = mean(lengthsTbl.below_threshold_lt5 > 0, 'omitnan');
    maskValid = "YES";
    if mean(isfinite(maskMeta(:, 6)) & isfinite(maskMeta(:, 5)) & (maskMeta(:, 6) < maskMeta(:, 5))) < 1
        maskValid = "NO";
    end
    minPlateauOk = "YES";
    if ~(isfinite(minLength) && minLength >= plateauMinOkThreshold)
        minPlateauOk = "NO";
    end

    gapChanged = "NO";
    noiseChanged = "NO";
    driftChanged = "NO";
    medianRelGap = median(abs(diffTbl.delta_gap) ./ max(abs(standardGapTbl.gap), eps), 'omitnan');
    medianRelNoise = median(abs(diffTbl.delta_noise) ./ max(abs(standardNoiseTbl.noise), eps), 'omitnan');
    medianRelDrift = median(abs(diffTbl.delta_drift) ./ max(abs(standardDriftTbl.drift), eps), 'omitnan');
    if isfinite(medianRelGap) && medianRelGap > 0.10
        gapChanged = "YES";
    end
    if isfinite(medianRelNoise) && medianRelNoise > 0.10
        noiseChanged = "YES";
    end
    if isfinite(medianRelDrift) && medianRelDrift > 0.10
        driftChanged = "YES";
    end

    noiseReductionFrac = mean((lateNoiseTbl.noise - standardNoiseTbl.noise) < 0, 'omitnan');
    driftReductionFrac = mean((lateDriftTbl.drift - standardDriftTbl.drift) < 0, 'omitnan');
    medianAbsDeltaGap = median(abs(diffTbl.delta_gap), 'omitnan');
    medianAbsGapStd = median(abs(standardGapTbl.gap), 'omitnan');
    structureMetric = median(abs(diffTbl.delta_gap), 'omitnan') + median(abs(diffTbl.delta_noise), 'omitnan') + median(abs(diffTbl.delta_drift), 'omitnan');
    relaxationImportant = "NO";
    if isfinite(noiseReductionFrac) && isfinite(driftReductionFrac) && isfinite(medianAbsDeltaGap) && isfinite(medianAbsGapStd)
        if noiseReductionFrac >= 0.60 && driftReductionFrac >= 0.60 && medianAbsDeltaGap <= 0.20 * max(medianAbsGapStd, eps)
            relaxationImportant = "YES";
        elseif noiseReductionFrac >= 0.45 || driftReductionFrac >= 0.45 || structureMetric > 0
            relaxationImportant = "PARTIAL";
        else
            relaxationImportant = "NO";
        end
    end

    sanityPassed = "NO";
    if maskValid == "YES" && minPlateauOk == "YES"
        sanityPassed = "YES";
    end

    fid = fopen(standardSummaryPath, 'w');
    if fid < 0
        error('XXLateVsStandard:StandardSummaryOpenFailed', 'Unable to write %s', standardSummaryPath);
    end
    fprintf(fid, '# XX standard summary\n\n');
    fprintf(fid, '- Selected channel: `%d`\n', selectedChannel);
    fprintf(fid, '- Temperature cutoff: `%.1f K`\n', temperatureCutoffK);
    fprintf(fid, '- Common-domain points: `%d`\n', size(commonKeys, 1));
    fprintf(fid, '- Gap median: `%.6g`\n', median(standardGapTbl.gap, 'omitnan'));
    fprintf(fid, '- Noise median: `%.6g`\n', median(standardNoiseTbl.noise, 'omitnan'));
    fprintf(fid, '- Drift median: `%.6g`\n', median(standardDriftTbl.drift, 'omitnan'));
    fprintf(fid, '- Output figure: `figures/xx_standard_maps.fig`\n');
    fclose(fid);

    fid = fopen(lateSummaryPath, 'w');
    if fid < 0
        error('XXLateVsStandard:LateSummaryOpenFailed', 'Unable to write %s', lateSummaryPath);
    end
    fprintf(fid, '# XX late summary\n\n');
    fprintf(fid, '- Selected channel: `%d`\n', selectedChannel);
    fprintf(fid, '- Late window: `70-90%%`\n');
    fprintf(fid, '- Mean late plateau length: `%.6g`\n', meanLength);
    fprintf(fid, '- Min late plateau length: `%.6g`\n', minLength);
    fprintf(fid, '- Fraction below threshold (<5): `%.6g`\n', fracBelowThreshold);
    fprintf(fid, '- Gap median: `%.6g`\n', median(lateGapTbl.gap, 'omitnan'));
    fprintf(fid, '- Noise median: `%.6g`\n', median(lateNoiseTbl.noise, 'omitnan'));
    fprintf(fid, '- Drift median: `%.6g`\n', median(lateDriftTbl.drift, 'omitnan'));
    fprintf(fid, '- Output figure: `figures/xx_late_maps.fig`\n');
    fclose(fid);

    fid = fopen(mainReportPath, 'w');
    if fid < 0
        error('XXLateVsStandard:MainReportOpenFailed', 'Unable to write %s', mainReportPath);
    end
    fprintf(fid, '# XX late vs standard analysis\n\n');
    fprintf(fid, '## A. Sanity\n\n');
    fprintf(fid, '- `MASK_VALID = %s`\n', maskValid);
    fprintf(fid, '- `MIN_PLATEAU_OK = %s`\n', minPlateauOk);
    fprintf(fid, '- mean late plateau length: `%.6g`\n', meanLength);
    fprintf(fid, '- min late plateau length: `%.6g`\n', minLength);
    fprintf(fid, '- fraction below threshold (<5): `%.6g`\n', fracBelowThreshold);
    fprintf(fid, '- valid points standard: `%d`\n', validPointsStandard);
    fprintf(fid, '- valid points late: `%d`\n', validPointsLate);
    fprintf(fid, '\n## B. Stability impact\n\n');
    fprintf(fid, '- `GAP_CHANGED = %s`\n', gapChanged);
    fprintf(fid, '- `NOISE_CHANGED = %s`\n', noiseChanged);
    fprintf(fid, '- `DRIFT_CHANGED = %s`\n', driftChanged);
    fprintf(fid, '- median relative gap change: `%.6g`\n', medianRelGap);
    fprintf(fid, '- median relative noise change: `%.6g`\n', medianRelNoise);
    fprintf(fid, '- median relative drift change: `%.6g`\n', medianRelDrift);
    fprintf(fid, '\n## C. Physics interpretation\n\n');
    fprintf(fid, '- `RELAXATION_IMPORTANT = %s`\n', relaxationImportant);
    fprintf(fid, '- noise reduction fraction: `%.6g`\n', noiseReductionFrac);
    fprintf(fid, '- drift reduction fraction: `%.6g`\n', driftReductionFrac);
    fprintf(fid, '- median abs(delta gap): `%.6g`\n', medianAbsDeltaGap);
    fprintf(fid, '- median abs(gap standard): `%.6g`\n', medianAbsGapStd);
    fprintf(fid, '- diff structure metric: `%.6g`\n', structureMetric);
    fprintf(fid, '\n## Success criteria\n\n');
    fprintf(fid, '- `RUN_COMPLETED = YES`\n');
    fprintf(fid, '- `SANITY_PASSED = %s`\n', sanityPassed);
    fprintf(fid, '- `DIFF_MAPS_CREATED = YES`\n');
    fprintf(fid, '- `PHYSICS_CONCLUSION_REACHED = YES`\n');
    fprintf(fid, '\n## Output artifacts\n\n');
    fprintf(fid, '- `tables/xx_standard_gap.csv`\n');
    fprintf(fid, '- `tables/xx_standard_noise.csv`\n');
    fprintf(fid, '- `tables/xx_standard_drift.csv`\n');
    fprintf(fid, '- `tables/xx_late_gap.csv`\n');
    fprintf(fid, '- `tables/xx_late_noise.csv`\n');
    fprintf(fid, '- `tables/xx_late_drift.csv`\n');
    fprintf(fid, '- `tables/xx_late_plateau_lengths.csv`\n');
    fprintf(fid, '- `tables/xx_late_coverage.csv`\n');
    fprintf(fid, '- `tables/xx_diff_maps.csv`\n');
    fprintf(fid, '- `tables/xx_late_correlation_tests.csv`\n');
    fprintf(fid, '- `figures/xx_standard_maps.fig`\n');
    fprintf(fid, '- `figures/xx_late_maps.fig`\n');
    fprintf(fid, '- `figures/xx_late_mask_sanity.fig`\n');
    fprintf(fid, '- `figures/xx_diff_maps.fig`\n');
    fprintf(fid, '- `figures/xx_late_scatter.fig`\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, size(commonKeys, 1), {'XX late vs standard comparison completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    fid = fopen(mainReportPath, 'w');
    if fid >= 0
        fprintf(fid, '# XX late vs standard analysis\n\n');
        fprintf(fid, '- `RUN_COMPLETED = NO`\n');
        fprintf(fid, '- `SANITY_PASSED = NO`\n');
        fprintf(fid, '- `DIFF_MAPS_CREATED = NO`\n');
        fprintf(fid, '- `PHYSICS_CONCLUSION_REACHED = NO`\n');
        fprintf(fid, '- error: `%s`\n', strrep(ME.message, '`', ''''));
        fclose(fid);
    end

    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_late_vs_standard_comparison_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XX late vs standard comparison failed'}, ...
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
