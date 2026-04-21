fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('XXNormAudit:RepoMissing', 'Repository root not found: %s', repoRoot);
end

addpath(genpath(repoRoot));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfgRun = struct();
cfgRun.runLabel = 'xx_switching_normalization_audit';
run = struct();

statusPath = fullfile(repoRoot, 'execution_status.csv');
tablesDir = fullfile(repoRoot, 'tables');
figuresDir = fullfile(repoRoot, 'figures');
reportsDir = fullfile(repoRoot, 'reports');

tblMetricDefPath = fullfile(tablesDir, 'xx_switching_normalization_metric_definition.csv');
tblVariantsPath = fullfile(tablesDir, 'xx_switching_metric_variants_comparison.csv');
tblPlateauPath = fullfile(tablesDir, 'xx_switching_plateau_internal_segments.csv');
tblEdgePath = fullfile(tablesDir, 'xx_switching_window_edge_audit.csv');
tblVerdictsPath = fullfile(tablesDir, 'xx_switching_normalization_verdicts.csv');
tblStatusPath = fullfile(tablesDir, 'xx_switching_normalization_status.csv');

figPercentPath = fullfile(figuresDir, 'xx_switching_percent_standard_vs_late.fig');
figPercentPngPath = fullfile(figuresDir, 'xx_switching_percent_standard_vs_late.png');
figRawPath = fullfile(figuresDir, 'xx_switching_raw_standard_vs_late.fig');
figRawPngPath = fullfile(figuresDir, 'xx_switching_raw_standard_vs_late.png');
figScatterPath = fullfile(figuresDir, 'xx_switching_variant_scatter.fig');
figScatterPngPath = fullfile(figuresDir, 'xx_switching_variant_scatter.png');
figPlateauPath = fullfile(figuresDir, 'xx_switching_plateau_segments.fig');
figPlateauPngPath = fullfile(figuresDir, 'xx_switching_plateau_segments.png');

reportPath = fullfile(reportsDir, 'xx_switching_normalization_audit.md');

temperatureCutoffK = 34;
lateFrac1 = 0.70;
lateFrac2 = 0.90;
safetyMarginPercent = 15;
plateauMinN = 5;
repTraceCount = 6;

executionStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, 0, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

emptyMetricDef = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'component_name', 'symbol', 'definition', 'depends_on', 'changes_in_late_window', 'notes'});
emptyVariants = table([], [], [], [], [], [], [], [], [], [], [], [], [], ...
    'VariableNames', {'current_mA', 'temperature_K', ...
    'P2P_percent_standard', 'P2P_percent_late_70_90', ...
    'P2P_raw_signed_standard', 'P2P_raw_signed_late_70_90', ...
    'P2P_raw_abs_standard', 'P2P_raw_abs_late_70_90', ...
    'denominator_standard', 'denominator_late_70_90', 'denominator_frozen_control', ...
    'P2P_percent_late_frozen_denom', 'N_files_contributed'});
emptyPlateau = table([], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], ...
    'VariableNames', {'current_mA', 'temperature_K', 'file_index', 'plateau_index', 'channel_physical', ...
    'n_plateau_samples', 'early_mean_10_30', 'mid_mean_40_60', 'late_mean_70_90', ...
    'within_plateau_std', 'within_plateau_slope', 'delta_early_to_late', 'delta_mid_to_late', ...
    'distance_to_right_edge_samples_70_90', 'distance_to_right_edge_fraction_70_90', 'tail_variance_ratio_80_100_vs_40_60'});
emptyEdge = table([], [], [], [], [], [], [], [], [], [], [], [], ...
    'VariableNames', {'current_mA', 'temperature_K', 'file_index', 'plateau_index', ...
    'window_mean_50_70', 'window_mean_60_80', 'window_mean_70_90', ...
    'window_std_50_70', 'window_std_60_80', 'window_std_70_90', ...
    'edge_shift_70_90_minus_60_80', 'edge_shift_70_90_minus_50_70'});
emptyVerdicts = table(strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'verdict_key', 'verdict_value', 'evidence'});
emptyStatus = table({'FAILED'}, {'NO'}, {'NotStarted'}, {''}, {'NotStarted'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'RUN_DIR', 'MAIN_RESULT_SUMMARY'});

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

    writetable(emptyMetricDef, tblMetricDefPath);
    writetable(emptyVariants, tblVariantsPath);
    writetable(emptyPlateau, tblPlateauPath);
    writetable(emptyEdge, tblEdgePath);
    writetable(emptyVerdicts, tblVerdictsPath);
    writetable(emptyStatus, tblStatusPath);

    fidInit = fopen(reportPath, 'w');
    if fidInit >= 0
        fprintf(fidInit, '# XX switching normalization audit\n\nPENDING\n');
        fclose(fidInit);
    end

    cfgSources = xx_relaxation_config2_sources();
    if isempty(cfgSources)
        error('XXNormAudit:MissingConfig2Sources', 'xx_relaxation_config2_sources returned empty.');
    end
    parentDir = char(cfgSources(1).baseDir);
    if exist(parentDir, 'dir') ~= 7
        error('XXNormAudit:MissingParentDir', 'XX Config2 parent directory does not exist: %s', parentDir);
    end

    channelTblPath = fullfile(tablesDir, 'xx_channel_validation.csv');
    if exist(channelTblPath, 'file') ~= 2
        error('XXNormAudit:MissingChannelValidation', 'Missing %s', channelTblPath);
    end
    channelTbl = readtable(channelTblPath, 'TextType', 'string');
    if ~ismember('pipeline_choice', channelTbl.Properties.VariableNames)
        error('XXNormAudit:MissingPipelineChoice', 'pipeline_choice missing in %s', channelTblPath);
    end
    pipelineChoices = unique(double(channelTbl.pipeline_choice(isfinite(double(channelTbl.pipeline_choice)))));
    if isempty(pipelineChoices)
        error('XXNormAudit:EmptyPipelineChoice', 'No finite pipeline_choice found in %s', channelTblPath);
    end
    selectedChannel = pipelineChoices(1);
    if ~(isfinite(selectedChannel) && any(selectedChannel == [1, 2, 3, 4]))
        error('XXNormAudit:BadSelectedChannel', 'Invalid selected channel: %g', selectedChannel);
    end

    filteredParentDir = fullfile(run.run_dir, sprintf('xx_temp_cutoff_input_le_%gK', temperatureCutoffK));
    if exist(filteredParentDir, 'dir') ~= 7
        mkdir(filteredParentDir);
    end

    srcDirs = dir(fullfile(parentDir, 'Temp Dep *'));
    srcDirs = srcDirs([srcDirs.isdir]);
    totalCopiedFiles = 0;
    for iSrc = 1:numel(srcDirs)
        srcSubDir = fullfile(parentDir, srcDirs(iSrc).name);
        depType = extract_dep_type_from_folder(srcSubDir);
        [fileList0, sortedValues0, ~, ~] = getFileListSwitching(srcSubDir, depType);
        if isempty(fileList0) || isempty(sortedValues0)
            continue;
        end
        keepMask = isfinite(sortedValues0) & (sortedValues0 <= temperatureCutoffK);
        if ~any(keepMask)
            continue;
        end
        dstSubDir = fullfile(filteredParentDir, srcDirs(iSrc).name);
        if exist(dstSubDir, 'dir') ~= 7
            mkdir(dstSubDir);
        end
        idxKeep = find(keepMask);
        for ik = 1:numel(idxKeep)
            srcFile = fullfile(srcSubDir, fileList0(idxKeep(ik)).name);
            copyfile(srcFile, dstSubDir);
            totalCopiedFiles = totalCopiedFiles + 1;
        end
    end
    if totalCopiedFiles == 0
        error('XXNormAudit:NoCopiedFiles', 'No XX files passed the temperature cutoff.');
    end

    rowsVariants = zeros(0, 13);
    rowsPlateau = zeros(0, 16);
    rowsEdge = zeros(0, 12);
    repTraceStruct = struct('t', {}, 'y', {}, 'i_mA', {}, 'T_K', {}, 'plateau_idx', {}, 't1', {}, 't2', {}, 'e1', {}, 'e2', {}, 'm1', {}, 'm2', {}, 'l1', {}, 'l2', {});
    repTraceCountUsed = 0;

    tempDirs = dir(fullfile(filteredParentDir, 'Temp Dep *'));
    tempDirs = tempDirs([tempDirs.isdir]);
    if isempty(tempDirs)
        error('XXNormAudit:NoFilteredTempDirs', 'No filtered Temp Dep directories in %s', filteredParentDir);
    end

    normalizationPhysicalRefValues = [];
    denominatorLateValues = [];
    denominatorStdValues = [];
    pctStdVals = [];
    pctLateVals = [];
    rawStdVals = [];
    rawLateVals = [];

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
            error('XXNormAudit:InvalidCurrent', 'Invalid current parsed in %s', thisDir);
        end

        [storedDataStd, tableDataStd] = processFilesSwitching( ...
            thisDir, fileList, sortedValues, ...
            currentA, 1e3, ...
            4000, 16, 4, 2, 11, ...
            false, delayMs, ...
            numPulsesWithSameDep, safetyMarginPercent, ...
            NaN, NaN, normalizeTo, ...
            true, 1.5, 50, false, pulseScheme);

        stdMat = [];
        if selectedChannel == 1
            stdMat = tableDataStd.ch1;
        elseif selectedChannel == 2
            stdMat = tableDataStd.ch2;
        elseif selectedChannel == 3
            stdMat = tableDataStd.ch3;
        elseif selectedChannel == 4
            stdMat = tableDataStd.ch4;
        end
        if isempty(stdMat)
            continue;
        end

        for iFile = 1:size(storedDataStd, 1)
            if iFile > size(stdMat, 1)
                continue;
            end
            depK = stdMat(iFile, 1);
            rawSignedStd = stdMat(iFile, 2);
            pctStd = stdMat(iFile, 4);
            denomStd = stdMat(iFile, 7);
            if ~isfinite(depK) || depK > temperatureCutoffK
                continue;
            end

            dataUnf = storedDataStd{iFile, 1};
            plateauMeansStd = storedDataStd{iFile, 5};
            physIdxRow = [];
            if size(storedDataStd, 2) >= 7 && ~isempty(storedDataStd{iFile, 7})
                physIdxRow = storedDataStd{iFile, 7}(:).';
            end
            if isempty(dataUnf) || isempty(plateauMeansStd) || isempty(physIdxRow)
                continue;
            end

            localIdxSel = find(physIdxRow == selectedChannel, 1, 'first');
            if isempty(localIdxSel)
                continue;
            end

            numCh = size(dataUnf, 2) - 1;
            if size(plateauMeansStd, 2) < numCh
                continue;
            end

            t = dataUnf(:, 1);
            numPulses = size(plateauMeansStd, 1);
            pulseTimes = t(1) + (0:numPulses-1) * delayMs;
            safetyMarginMs = delayMs * (safetyMarginPercent / 100);

            lateMeans = NaN(size(plateauMeansStd));
            lateDenomLocal = NaN;
            rawSignedLate = NaN;
            rawAbsStd = NaN;
            rawAbsLate = NaN;
            pctLate = NaN;
            pctLateFrozen = NaN;

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
                if nFull <= 0
                    continue;
                end

                iE1 = floor(0.10 * nFull) + 1;
                iE2 = floor(0.30 * nFull);
                iM1 = floor(0.40 * nFull) + 1;
                iM2 = floor(0.60 * nFull);
                iL1 = floor(0.70 * nFull) + 1;
                iL2 = floor(0.90 * nFull);
                iA1 = floor(0.50 * nFull) + 1;
                iA2 = floor(0.70 * nFull);
                iB1 = floor(0.60 * nFull) + 1;
                iB2 = floor(0.80 * nFull);
                iC1 = floor(0.70 * nFull) + 1;
                iC2 = floor(0.90 * nFull);
                iT1 = floor(0.80 * nFull) + 1;
                iT2 = nFull;
                iMidVar1 = floor(0.40 * nFull) + 1;
                iMidVar2 = floor(0.60 * nFull);

                iE1 = min(max(iE1, 1), nFull); iE2 = min(max(iE2, iE1), nFull);
                iM1 = min(max(iM1, 1), nFull); iM2 = min(max(iM2, iM1), nFull);
                iL1 = min(max(iL1, 1), nFull); iL2 = min(max(iL2, iL1), nFull);
                iA1 = min(max(iA1, 1), nFull); iA2 = min(max(iA2, iA1), nFull);
                iB1 = min(max(iB1, 1), nFull); iB2 = min(max(iB2, iB1), nFull);
                iC1 = min(max(iC1, 1), nFull); iC2 = min(max(iC2, iC1), nFull);
                iT1 = min(max(iT1, 1), nFull); iT2 = min(max(iT2, iT1), nFull);
                iMidVar1 = min(max(iMidVar1, 1), nFull); iMidVar2 = min(max(iMidVar2, iMidVar1), nFull);

                idxLate = idx0(iL1:iL2);
                idxEarly = idx0(iE1:iE2);
                idxMid = idx0(iM1:iM2);
                idx50_70 = idx0(iA1:iA2);
                idx60_80 = idx0(iB1:iB2);
                idx70_90 = idx0(iC1:iC2);
                idxTail = idx0(iT1:iT2);
                idxMidVar = idx0(iMidVar1:iMidVar2);

                ySel = dataUnf(:, 1 + localIdxSel);
                yPlateau = ySel(idx0);
                yEarly = ySel(idxEarly);
                yMid = ySel(idxMid);
                yLate = ySel(idxLate);
                y50_70 = ySel(idx50_70);
                y60_80 = ySel(idx60_80);
                y70_90 = ySel(idx70_90);
                yTail = ySel(idxTail);
                yMidVar = ySel(idxMidVar);

                if isempty(yPlateau)
                    continue;
                end

                xLocal = (1:numel(yPlateau)).';
                slopeVal = NaN;
                if numel(yPlateau) >= 3
                    pFit = polyfit(xLocal, yPlateau(:), 1);
                    slopeVal = pFit(1);
                end
                stdVal = std(yPlateau, 'omitnan');
                earlyMean = mean(yEarly, 'omitnan');
                midMean = mean(yMid, 'omitnan');
                lateMeanSeg = mean(yLate, 'omitnan');
                deltaEL = lateMeanSeg - earlyMean;
                deltaML = lateMeanSeg - midMean;
                distRightSamples = nFull - iL2;
                distRightFrac = distRightSamples / max(nFull, 1);
                varTail = var(yTail, 'omitnan');
                varMid = var(yMidVar, 'omitnan');
                tailVarRatio = NaN;
                if isfinite(varTail) && isfinite(varMid) && varMid > 0
                    tailVarRatio = varTail / varMid;
                end

                rowsPlateau(end+1, :) = [amp, depK, iFile, j, selectedChannel, ...
                    nFull, earlyMean, midMean, lateMeanSeg, stdVal, slopeVal, deltaEL, deltaML, ...
                    distRightSamples, distRightFrac, tailVarRatio]; %#ok<AGROW>

                mean50_70 = mean(y50_70, 'omitnan');
                mean60_80 = mean(y60_80, 'omitnan');
                mean70_90 = mean(y70_90, 'omitnan');
                std50_70 = std(y50_70, 'omitnan');
                std60_80 = std(y60_80, 'omitnan');
                std70_90 = std(y70_90, 'omitnan');
                edgeShift1 = mean70_90 - mean60_80;
                edgeShift2 = mean70_90 - mean50_70;

                rowsEdge(end+1, :) = [amp, depK, iFile, j, ...
                    mean50_70, mean60_80, mean70_90, ...
                    std50_70, std60_80, std70_90, edgeShift1, edgeShift2]; %#ok<AGROW>

                if repTraceCountUsed < repTraceCount
                    repTraceCountUsed = repTraceCountUsed + 1;
                    repTraceStruct(repTraceCountUsed).t = t(idx0);
                    repTraceStruct(repTraceCountUsed).y = yPlateau;
                    repTraceStruct(repTraceCountUsed).i_mA = amp;
                    repTraceStruct(repTraceCountUsed).T_K = depK;
                    repTraceStruct(repTraceCountUsed).plateau_idx = j;
                    repTraceStruct(repTraceCountUsed).t1 = t(idx0(1));
                    repTraceStruct(repTraceCountUsed).t2 = t(idx0(end));
                    repTraceStruct(repTraceCountUsed).e1 = t(idx0(iE1));
                    repTraceStruct(repTraceCountUsed).e2 = t(idx0(iE2));
                    repTraceStruct(repTraceCountUsed).m1 = t(idx0(iM1));
                    repTraceStruct(repTraceCountUsed).m2 = t(idx0(iM2));
                    repTraceStruct(repTraceCountUsed).l1 = t(idx0(iL1));
                    repTraceStruct(repTraceCountUsed).l2 = t(idx0(iL2));
                end

                for k = 1:numCh
                    valsLateK = dataUnf(idxLate, 1 + k);
                    if ~isempty(valsLateK)
                        lateMeans(j, k) = mean(valsLateK, 'omitnan');
                    end
                end
            end

            p2pStdRaw = diff(plateauMeansStd(:, localIdxSel));
            p2pStdAbs = abs(p2pStdRaw);
            if numel(p2pStdAbs) >= 1
                p2pStdAbs(1) = NaN;
            end
            medStd = median(p2pStdAbs, 'omitnan');
            madStd = mad(p2pStdAbs, 1);
            thrStd = 4 * 1.4826 * madStd;
            goodStd = isfinite(p2pStdAbs) & (abs(p2pStdAbs - medStd) <= thrStd);
            p2pStdCleanAbs = p2pStdAbs(goodStd);
            if isempty(p2pStdCleanAbs) || all(isnan(p2pStdCleanAbs))
                rawAbsStd = NaN;
            else
                rawAbsStd = mean(p2pStdCleanAbs, 'omitnan');
            end

            p2pLateRaw = diff(lateMeans(:, localIdxSel));
            p2pLateAbs = abs(p2pLateRaw);
            if numel(p2pLateAbs) >= 1
                p2pLateAbs(1) = NaN;
            end
            medLate = median(p2pLateAbs, 'omitnan');
            madLate = mad(p2pLateAbs, 1);
            thrLate = 4 * 1.4826 * madLate;
            goodLate = isfinite(p2pLateAbs) & (abs(p2pLateAbs - medLate) <= thrLate);
            p2pLateCleanAbs = p2pLateAbs(goodLate);
            if isempty(p2pLateCleanAbs) || all(isnan(p2pLateCleanAbs))
                rawAbsLate = NaN;
            else
                rawAbsLate = mean(p2pLateCleanAbs, 'omitnan');
            end

            sgnLate = 1;
            signPulseIdx = 2;
            if numel(p2pLateRaw) >= signPulseIdx && signPulseIdx >= 1 && ...
                    goodLate(signPulseIdx) && isfinite(p2pLateRaw(signPulseIdx)) && p2pLateRaw(signPulseIdx) ~= 0
                sgnLate = sign(p2pLateRaw(signPulseIdx));
            else
                sTmpLate = mean(p2pLateRaw(goodLate), 'omitnan');
                if isfinite(sTmpLate) && sTmpLate ~= 0
                    sgnLate = sign(sTmpLate);
                end
            end
            if isempty(p2pLateCleanAbs) || all(isnan(p2pLateCleanAbs))
                rawSignedLate = NaN;
            else
                rawSignedLate = sgnLate * mean(p2pLateCleanAbs, 'omitnan');
            end

            normalizeToVec = normalizeTo;
            if isscalar(normalizeToVec) && isnumeric(normalizeToVec)
                normalizeToVec = repmat(normalizeToVec, 1, numCh);
            elseif isnumeric(normalizeToVec)
                nNorm = numel(normalizeToVec);
                if nNorm > numCh
                    normalizeToVec = normalizeToVec(1:numCh);
                elseif nNorm < numCh
                    normalizeToVec = [normalizeToVec(:).' repmat(normalizeToVec(end), 1, numCh - nNorm)];
                end
            else
                normalizeToVec = ones(1, numCh);
            end

            refPhys = normalizeToVec(localIdxSel);
            normalizationPhysicalRefValues(end+1, 1) = refPhys; %#ok<AGROW>
            refLocal = find(physIdxRow == refPhys, 1, 'first');
            if isempty(refLocal)
                lateDenomLocal = NaN;
            else
                lateDenomLocal = mean(lateMeans(:, refLocal), 'omitnan');
            end

            if isfinite(lateDenomLocal) && lateDenomLocal ~= 0
                pctLate = (rawSignedLate / lateDenomLocal) * 100;
            else
                pctLate = NaN;
            end
            if isfinite(denomStd) && denomStd ~= 0
                pctLateFrozen = (rawSignedLate / denomStd) * 100;
            else
                pctLateFrozen = NaN;
            end

            rowsVariants(end+1, :) = [amp, depK, ...
                pctStd, pctLate, ...
                rawSignedStd, rawSignedLate, ...
                rawAbsStd, rawAbsLate, ...
                denomStd, lateDenomLocal, denomStd, pctLateFrozen, 1]; %#ok<AGROW>

            denominatorStdValues(end+1, 1) = denomStd; %#ok<AGROW>
            denominatorLateValues(end+1, 1) = lateDenomLocal; %#ok<AGROW>
            pctStdVals(end+1, 1) = pctStd; %#ok<AGROW>
            pctLateVals(end+1, 1) = pctLate; %#ok<AGROW>
            rawStdVals(end+1, 1) = rawSignedStd; %#ok<AGROW>
            rawLateVals(end+1, 1) = rawSignedLate; %#ok<AGROW>
        end
    end

    if isempty(rowsVariants)
        error('XXNormAudit:NoVariantRows', 'No variant rows were produced from XX data.');
    end

    [gIdx, gI, gT] = findgroups(rowsVariants(:, 1), rowsVariants(:, 2));
    agg = splitapply(@(a,b,c,d,e,f,g,h,i,j,k,m,n)[ ...
        mean(a, 'omitnan'), mean(b, 'omitnan'), mean(c, 'omitnan'), mean(d, 'omitnan'), ...
        mean(e, 'omitnan'), mean(f, 'omitnan'), mean(g, 'omitnan'), mean(h, 'omitnan'), ...
        mean(i, 'omitnan'), mean(j, 'omitnan'), mean(k, 'omitnan'), sum(isfinite(m))], ...
        rowsVariants(:, 3), rowsVariants(:, 4), rowsVariants(:, 5), rowsVariants(:, 6), ...
        rowsVariants(:, 7), rowsVariants(:, 8), rowsVariants(:, 9), rowsVariants(:, 10), ...
        rowsVariants(:, 11), rowsVariants(:, 12), rowsVariants(:, 13), rowsVariants(:, 3), rowsVariants(:, 4), gIdx);

    variantsTbl = table(gI, gT, ...
        agg(:, 1), agg(:, 2), agg(:, 3), agg(:, 4), agg(:, 5), agg(:, 6), ...
        agg(:, 7), agg(:, 8), agg(:, 9), agg(:, 10), agg(:, 12), ...
        'VariableNames', {'current_mA', 'temperature_K', ...
        'P2P_percent_standard', 'P2P_percent_late_70_90', ...
        'P2P_raw_signed_standard', 'P2P_raw_signed_late_70_90', ...
        'P2P_raw_abs_standard', 'P2P_raw_abs_late_70_90', ...
        'denominator_standard', 'denominator_late_70_90', 'denominator_frozen_control', ...
        'P2P_percent_late_frozen_denom', 'N_files_contributed'});
    variantsTbl = sortrows(variantsTbl, {'current_mA', 'temperature_K'});
    writetable(variantsTbl, tblVariantsPath);

    if isempty(rowsPlateau)
        plateauTbl = emptyPlateau;
    else
        plateauTbl = array2table(rowsPlateau, 'VariableNames', emptyPlateau.Properties.VariableNames);
    end
    writetable(plateauTbl, tblPlateauPath);

    if isempty(rowsEdge)
        edgeTbl = emptyEdge;
    else
        edgeTbl = array2table(rowsEdge, 'VariableNames', emptyEdge.Properties.VariableNames);
    end
    writetable(edgeTbl, tblEdgePath);

    metricDefTbl = table( ...
        ["numerator_raw"; "denominator_refBase"; "percent_metric"; "plateau_mean_intervel_avg_res"; "late_window_indexing"; "frozen_denom_control"], ...
        ["avg_p2p"; "refBase"; "change_pct(P2P_percent)"; "intervel_avg_res"; "i1=floor(0.70*n)+1,i2=floor(0.90*n)"; "P2P_percent_late_frozen_denom"], ...
        ["Robust mean of signed |diff(intervel_avg_res)| after skip-first and MAD outlier mask"; ...
         "Mean plateau level of normalization reference channel from intervel_avg_res"; ...
         "100 * avg_p2p / refBase"; ...
         "Per-pulse plateau means computed from R_unf over valid pulse intervals"; ...
         "Late uses subset of each plateau; standard uses full plateau"; ...
         "100 * raw_signed_late / denominator_standard"], ...
        ["intervel_avg_res; skip-first; MAD threshold"; ...
         "Normalize_to (physical channel map), intervel_avg_res"; ...
         "numerator_raw + denominator_refBase"; ...
         "R_unf, pulse timing, safety margin"; ...
         "plateau sample count n"; ...
         "raw late numerator + standard denominator"], ...
        ["NO"; "YES"; "YES"; "YES"; "YES"; "NO"], ...
        ["Numerator estimator itself depends on diff of plateau means."; ...
         "Denominator is data-dependent (state/current/temperature/file) not a global constant."; ...
         "Canonical metric in processFilesSwitching tableData column 4."; ...
         "This is where both standard and late windowing enter."; ...
         "Late window changes numerator source and denominator source unless denominator frozen."; ...
         "Diagnostic control only, canonical metric unchanged."], ...
        'VariableNames', {'component_name', 'symbol', 'definition', 'depends_on', 'changes_in_late_window', 'notes'});
    writetable(metricDefTbl, tblMetricDefPath);

    keys = {'P2P_percent_standard', 'P2P_percent_late_70_90', 'P2P_raw_signed_standard', 'P2P_raw_signed_late_70_90', 'P2P_percent_late_frozen_denom'};
    vals = {variantsTbl.P2P_percent_standard, variantsTbl.P2P_percent_late_70_90, variantsTbl.P2P_raw_signed_standard, variantsTbl.P2P_raw_signed_late_70_90, variantsTbl.P2P_percent_late_frozen_denom};
    compRows = strings(0, 1);
    compPearson = zeros(0, 1);
    compSlope = zeros(0, 1);
    compIntercept = zeros(0, 1);
    compRmse = zeros(0, 1);
    compNrmse = zeros(0, 1);
    compMae = zeros(0, 1);
    compDynRatio = zeros(0, 1);
    compRankRho = zeros(0, 1);

    pairList = {
        'percent_standard_vs_late', 1, 2;
        'raw_standard_vs_late', 3, 4;
        'percent_vs_raw_standard', 1, 3;
        'percent_vs_raw_late', 2, 4;
        'late_percent_vs_late_frozen_denom', 2, 5
        };
    for ip = 1:size(pairList, 1)
        name = string(pairList{ip, 1});
        x = vals{pairList{ip, 2}};
        y = vals{pairList{ip, 3}};
        keep = isfinite(x) & isfinite(y);
        xk = x(keep);
        yk = y(keep);
        if numel(xk) >= 3
            p = polyfit(xk, yk, 1);
            slopeVal = p(1);
            intVal = p(2);
            rVal = corr(xk, yk, 'Type', 'Pearson');
            rmseVal = sqrt(mean((yk - xk).^2, 'omitnan'));
            dyn = max(xk) - min(xk);
            nrmseVal = NaN;
            if isfinite(dyn) && dyn > 0
                nrmseVal = rmseVal / dyn;
            end
            maeVal = mean(abs(yk - xk), 'omitnan');
            rankRho = corr(tiedrank(xk), tiedrank(yk), 'Type', 'Pearson');
            dynY = max(yk) - min(yk);
            dynRatioVal = NaN;
            if isfinite(dyn) && dyn ~= 0 && isfinite(dynY)
                dynRatioVal = dynY / dyn;
            end
        else
            slopeVal = NaN;
            intVal = NaN;
            rVal = NaN;
            rmseVal = NaN;
            nrmseVal = NaN;
            maeVal = NaN;
            rankRho = NaN;
            dynRatioVal = NaN;
        end
        compRows(end+1, 1) = name; %#ok<AGROW>
        compPearson(end+1, 1) = rVal; %#ok<AGROW>
        compSlope(end+1, 1) = slopeVal; %#ok<AGROW>
        compIntercept(end+1, 1) = intVal; %#ok<AGROW>
        compRmse(end+1, 1) = rmseVal; %#ok<AGROW>
        compNrmse(end+1, 1) = nrmseVal; %#ok<AGROW>
        compMae(end+1, 1) = maeVal; %#ok<AGROW>
        compDynRatio(end+1, 1) = dynRatioVal; %#ok<AGROW>
        compRankRho(end+1, 1) = rankRho; %#ok<AGROW>
    end

    temps = sort(unique(variantsTbl.temperature_K));
    currents = sort(unique(variantsTbl.current_mA));
    mapPctStd = NaN(numel(currents), numel(temps));
    mapPctLate = NaN(numel(currents), numel(temps));
    mapRawStd = NaN(numel(currents), numel(temps));
    mapRawLate = NaN(numel(currents), numel(temps));
    for ir = 1:height(variantsTbl)
        tVal = variantsTbl.temperature_K(ir);
        iVal = variantsTbl.current_mA(ir);
        it = find(abs(temps - tVal) < 1e-9, 1, 'first');
        ii = find(abs(currents - iVal) < 1e-9, 1, 'first');
        if isempty(it) || isempty(ii)
            continue;
        end
        mapPctStd(ii, it) = variantsTbl.P2P_percent_standard(ir);
        mapPctLate(ii, it) = variantsTbl.P2P_percent_late_70_90(ir);
        mapRawStd(ii, it) = variantsTbl.P2P_raw_signed_standard(ir);
        mapRawLate(ii, it) = variantsTbl.P2P_raw_signed_late_70_90(ir);
    end

    pctValsAll = [mapPctStd(:); mapPctLate(:)];
    rawValsAll = [mapRawStd(:); mapRawLate(:)];
    pctClim = [min(pctValsAll, [], 'omitnan'), max(pctValsAll, [], 'omitnan')];
    rawClim = [min(rawValsAll, [], 'omitnan'), max(rawValsAll, [], 'omitnan')];
    if ~(isfinite(pctClim(1)) && isfinite(pctClim(2)) && pctClim(2) > pctClim(1))
        pctClim = [0, 1];
    end
    if ~(isfinite(rawClim(1)) && isfinite(rawClim(2)) && rawClim(2) > rawClim(1))
        rawClim = [0, 1];
    end

    figPct = figure('Visible', 'off', 'Color', [1 1 1]);
    tlPct = tiledlayout(figPct, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    axP1 = nexttile(tlPct); imagesc(axP1, temps, currents, mapPctStd); axis(axP1, 'xy'); set(axP1, 'Color', [1 1 1]); caxis(axP1, pctClim); colorbar(axP1); title(axP1, 'P2P percent standard'); xlabel(axP1, 'T (K)'); ylabel(axP1, 'I (mA)');
    axP2 = nexttile(tlPct); imagesc(axP2, temps, currents, mapPctLate); axis(axP2, 'xy'); set(axP2, 'Color', [1 1 1]); caxis(axP2, pctClim); colorbar(axP2); title(axP2, 'P2P percent late 70-90'); xlabel(axP2, 'T (K)'); ylabel(axP2, 'I (mA)');
    title(tlPct, 'XX switching maps: percent normalization', 'Interpreter', 'none');
    savefig(figPct, figPercentPath);
    exportgraphics(figPct, figPercentPngPath, 'Resolution', 260);
    close(figPct);

    figRaw = figure('Visible', 'off', 'Color', [1 1 1]);
    tlRaw = tiledlayout(figRaw, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    axR1 = nexttile(tlRaw); imagesc(axR1, temps, currents, mapRawStd); axis(axR1, 'xy'); set(axR1, 'Color', [1 1 1]); caxis(axR1, rawClim); colorbar(axR1); title(axR1, 'P2P raw signed standard'); xlabel(axR1, 'T (K)'); ylabel(axR1, 'I (mA)');
    axR2 = nexttile(tlRaw); imagesc(axR2, temps, currents, mapRawLate); axis(axR2, 'xy'); set(axR2, 'Color', [1 1 1]); caxis(axR2, rawClim); colorbar(axR2); title(axR2, 'P2P raw signed late 70-90'); xlabel(axR2, 'T (K)'); ylabel(axR2, 'I (mA)');
    title(tlRaw, 'XX switching maps: raw numerator metric', 'Interpreter', 'none');
    savefig(figRaw, figRawPath);
    exportgraphics(figRaw, figRawPngPath, 'Resolution', 260);
    close(figRaw);

    figSc = figure('Visible', 'off', 'Color', [1 1 1]);
    tlSc = tiledlayout(figSc, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    axS1 = nexttile(tlSc);
    scatter(axS1, variantsTbl.P2P_percent_standard, variantsTbl.P2P_percent_late_70_90, 28, variantsTbl.temperature_K, 'filled');
    grid(axS1, 'on'); xlabel(axS1, 'percent standard'); ylabel(axS1, 'percent late'); title(axS1, 'Percent std vs late');
    axS2 = nexttile(tlSc);
    scatter(axS2, variantsTbl.P2P_raw_signed_standard, variantsTbl.P2P_raw_signed_late_70_90, 28, variantsTbl.temperature_K, 'filled');
    grid(axS2, 'on'); xlabel(axS2, 'raw signed standard'); ylabel(axS2, 'raw signed late'); title(axS2, 'Raw std vs late');
    axS3 = nexttile(tlSc);
    scatter(axS3, variantsTbl.P2P_percent_late_70_90, variantsTbl.P2P_percent_late_frozen_denom, 28, variantsTbl.current_mA, 'filled');
    grid(axS3, 'on'); xlabel(axS3, 'late percent (native denom)'); ylabel(axS3, 'late percent (frozen denom)'); title(axS3, 'Denominator control');
    axS4 = nexttile(tlSc);
    scatter(axS4, variantsTbl.denominator_standard, variantsTbl.denominator_late_70_90, 28, variantsTbl.temperature_K, 'filled');
    grid(axS4, 'on'); xlabel(axS4, 'denominator standard'); ylabel(axS4, 'denominator late'); title(axS4, 'Denominator shift');
    title(tlSc, 'Variant scatter comparisons', 'Interpreter', 'none');
    savefig(figSc, figScatterPath);
    exportgraphics(figSc, figScatterPngPath, 'Resolution', 260);
    close(figSc);

    if ~isempty(repTraceStruct)
        figPl = figure('Visible', 'off', 'Color', [1 1 1]);
        tlPl = tiledlayout(figPl, numel(repTraceStruct), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
        for itrc = 1:numel(repTraceStruct)
            tr = repTraceStruct(itrc);
            ax = nexttile(tlPl);
            plot(ax, tr.t, tr.y, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.0); hold(ax, 'on');
            xline(ax, tr.e1, '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.0);
            xline(ax, tr.e2, '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.0);
            xline(ax, tr.m1, '--', 'Color', [0.00 0.45 0.74], 'LineWidth', 1.0);
            xline(ax, tr.m2, '--', 'Color', [0.00 0.45 0.74], 'LineWidth', 1.0);
            xline(ax, tr.l1, '--', 'Color', [0.47 0.67 0.19], 'LineWidth', 1.0);
            xline(ax, tr.l2, '--', 'Color', [0.47 0.67 0.19], 'LineWidth', 1.0);
            grid(ax, 'on');
            xlabel(ax, 't');
            ylabel(ax, 'R');
            title(ax, sprintf('I=%.3g mA | T=%.3g K | plateau=%d', tr.i_mA, tr.T_K, tr.plateau_idx), 'Interpreter', 'none');
        end
        title(tlPl, 'Representative plateau traces with early/mid/late segment boundaries', 'Interpreter', 'none');
        savefig(figPl, figPlateauPath);
        exportgraphics(figPl, figPlateauPngPath, 'Resolution', 260);
        close(figPl);
    end

    normalIsConst = "NO";
    lateOnlyNum = "NO";
    lateChangesDen = "YES";
    metricUnderstood = "YES";
    rawComputed = "YES";
    frozenComputed = "YES";

    keepPct = isfinite(variantsTbl.P2P_percent_standard) & isfinite(variantsTbl.P2P_percent_late_70_90);
    keepRaw = isfinite(variantsTbl.P2P_raw_signed_standard) & isfinite(variantsTbl.P2P_raw_signed_late_70_90);
    pctLateVisible = mean(abs(variantsTbl.P2P_percent_late_70_90 - variantsTbl.P2P_percent_standard), 'omitnan');
    rawLateVisible = mean(abs(variantsTbl.P2P_raw_signed_late_70_90 - variantsTbl.P2P_raw_signed_standard), 'omitnan');
    pctLateNorm = pctLateVisible / max(mean(abs(variantsTbl.P2P_percent_standard), 'omitnan'), eps);
    rawLateNorm = rawLateVisible / max(mean(abs(variantsTbl.P2P_raw_signed_standard), 'omitnan'), eps);

    lateOnlyWithoutNorm = "NO";
    pctCompresses = "NO";
    stdLateNormArtifact = "NO";
    if isfinite(pctLateNorm) && isfinite(rawLateNorm) && rawLateNorm > (pctLateNorm * 1.25)
        pctCompresses = "YES";
        if pctLateNorm < 0.10 && rawLateNorm >= 0.10
            lateOnlyWithoutNorm = "YES";
            stdLateNormArtifact = "YES";
        end
    end

    normAffects = "NO";
    keepDenCmp = isfinite(variantsTbl.P2P_percent_late_70_90) & isfinite(variantsTbl.P2P_percent_late_frozen_denom);
    if any(keepDenCmp)
        denDelta = mean(abs(variantsTbl.P2P_percent_late_70_90(keepDenCmp) - variantsTbl.P2P_percent_late_frozen_denom(keepDenCmp)), 'omitnan');
        lateDeltaPct = mean(abs(variantsTbl.P2P_percent_late_70_90(keepPct) - variantsTbl.P2P_percent_standard(keepPct)), 'omitnan');
        if isfinite(denDelta) && isfinite(lateDeltaPct) && denDelta > 0.25 * max(lateDeltaPct, eps)
            normAffects = "YES";
        end
    end

    plateauEvolutionPresent = "NO";
    plateauEvolutionSmall = "YES";
    lateExpectedChange = "NO";
    if ~isempty(rowsPlateau)
        deltaELabs = abs(rowsPlateau(:, 12));
        switchScale = abs(rowsVariants(:, 5));
        medDeltaEL = median(deltaELabs, 'omitnan');
        medSwitch = median(switchScale, 'omitnan');
        if isfinite(medDeltaEL) && medDeltaEL > 0
            plateauEvolutionPresent = "YES";
        end
        if isfinite(medDeltaEL) && isfinite(medSwitch) && medDeltaEL > 0.25 * max(medSwitch, eps)
            plateauEvolutionSmall = "NO";
            lateExpectedChange = "YES";
        end
    end

    windowTooClose = "NO";
    windowDominates = "NO";
    noiseShortDominates = "NO";
    if ~isempty(rowsEdge)
        medShift7060 = median(abs(rowsEdge(:, 11)), 'omitnan');
        medShift7050 = median(abs(rowsEdge(:, 12)), 'omitnan');
        stdInflation = median(rowsEdge(:, 10) ./ max(rowsEdge(:, 9), eps), 'omitnan');
        if isfinite(medShift7060) && medShift7060 > 0
            if isfinite(medShift7050) && medShift7050 > medShift7060 * 1.1
                windowTooClose = "YES";
            end
        end
        if isfinite(stdInflation) && stdInflation > 1.15
            noiseShortDominates = "YES";
        end
        if windowTooClose == "YES" || noiseShortDominates == "YES"
            windowDominates = "YES";
        end
    end

    finalPhysical = "NO";
    finalNormDriven = "NO";
    finalEstimatorDriven = "NO";
    primaryCause = "UNRESOLVED";
    if plateauEvolutionPresent == "NO" && pctCompresses == "NO" && windowDominates == "NO"
        finalPhysical = "YES";
        primaryCause = "PHYSICS";
    else
        if pctCompresses == "YES" || normAffects == "YES"
            finalNormDriven = "PARTIAL";
        end
        if windowDominates == "YES" || lateExpectedChange == "NO"
            finalEstimatorDriven = "PARTIAL";
        end
        if windowTooClose == "YES"
            primaryCause = "EDGE_CONTAMINATION";
        elseif pctCompresses == "YES" && windowDominates == "YES"
            primaryCause = "MIXED";
        elseif pctCompresses == "YES"
            primaryCause = "NORMALIZATION";
        elseif windowDominates == "YES"
            primaryCause = "ESTIMATOR";
        elseif plateauEvolutionPresent == "YES" && plateauEvolutionSmall == "YES"
            primaryCause = "PHYSICS";
            finalPhysical = "PARTIAL";
        else
            primaryCause = "MIXED";
        end
    end

    verdictKeys = {
        'NORMALIZATION_IS_CONSTANT'
        'LATE_WINDOW_CHANGES_ONLY_NUMERATOR'
        'LATE_WINDOW_CHANGES_DENOMINATOR'
        'METRIC_DEFINITION_FULLY_UNDERSTOOD'
        'RAW_VARIANT_COMPUTED'
        'FROZEN_DENOMINATOR_CONTROL_COMPUTED'
        'NORMALIZATION_AFFECTS_LATE_STANDARD_DIFFERENCE'
        'LATE_EFFECT_VISIBLE_ONLY_WITHOUT_NORMALIZATION'
        'PERCENT_NORMALIZATION_COMPRESSES_DIFFERENCES'
        'STANDARD_LATE_EQUIVALENCE_IS_NORMALIZATION_ARTIFACT'
        'PLATEAU_INTERNAL_EVOLUTION_PRESENT'
        'PLATEAU_INTERNAL_EVOLUTION_SMALL_RELATIVE_TO_SWITCHING'
        'LATE_WINDOW_EXPECTED_TO_CHANGE_MEASUREMENT'
        'WINDOW_70_90_TOO_CLOSE_TO_EDGE'
        'WINDOW_CHOICE_DOMINATES_RESULT'
        'NOISE_IN_SHORT_WINDOW_DOMINATES'
        'LATE_STANDARD_SIMILARITY_IS_PHYSICAL'
        'LATE_STANDARD_SIMILARITY_IS_NORMALIZATION_DRIVEN'
        'LATE_STANDARD_SIMILARITY_IS_ESTIMATOR_DRIVEN'
        'PRIMARY_CAUSE'
        };
    verdictVals = {
        normalIsConst
        lateOnlyNum
        lateChangesDen
        metricUnderstood
        rawComputed
        frozenComputed
        normAffects
        lateOnlyWithoutNorm
        pctCompresses
        stdLateNormArtifact
        plateauEvolutionPresent
        plateauEvolutionSmall
        lateExpectedChange
        windowTooClose
        windowDominates
        noiseShortDominates
        finalPhysical
        finalNormDriven
        finalEstimatorDriven
        primaryCause
        };
    verdictEvidence = {
        'refBase is mean(intervel_avg_res(reference channel)) and varies by file'
        'late changes intervel_avg_res values and therefore both numerator and denominator'
        'late denominator recomputed from lateMeans for the same reference channel'
        'definition traced through processFilesSwitching rowTemplate columns'
        'raw signed and raw abs variants computed from plateau mean differences'
        'late_frozen_denom control computed as raw late divided by standard denominator'
        'compare late native denominator vs late frozen denominator'
        'compare normalized late-vs-standard contrast to raw late-vs-standard contrast'
        'contrast ratio raw-vs-percent normalized late effect'
        'artifact only if late effect appears primarily after removing normalization'
        'median |early-late| across plateaus'
        'compare plateau internal delta to switching amplitude scale'
        'if internal delta non-negligible then late window expected to move metric'
        '70-90 vs 60-80 and 50-70 shift statistics'
        'window shift and variance inflation indicate dominance'
        'std(70-90) relative to std(60-80)'
        'final classification from combined diagnostics'
        'normalization and frozen-denominator control outcome'
        'edge/noise and window sensitivity outcome'
        'highest-support cause class among physics/normalization/estimator/edge'
        };
    verdictTbl = table(string(verdictKeys), string(verdictVals), string(verdictEvidence), ...
        'VariableNames', {'verdict_key', 'verdict_value', 'evidence'});
    writetable(verdictTbl, tblVerdictsPath);

    statusTbl = table({'SUCCESS'}, {'YES'}, {''}, {run.run_dir}, {'XX switching normalization audit completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'RUN_DIR', 'MAIN_RESULT_SUMMARY'});
    writetable(statusTbl, tblStatusPath);

    fid = fopen(reportPath, 'w');
    if fid < 0
        error('XXNormAudit:ReportOpenFailed', 'Unable to write report: %s', reportPath);
    end
    fprintf(fid, '# XX switching normalization / observable integrity audit\n\n');
    fprintf(fid, 'Audit scope: canonical measurement-definition integrity for XX switching, with additive diagnostics only.\n\n');
    fprintf(fid, '## 1. Exact metric definition\n\n');
    fprintf(fid, '- Canonical metric path traced through `processFilesSwitching` and XX map wrappers.\n');
    fprintf(fid, '- Numerator (`avg_p2p`) is robust mean of signed pulse-to-pulse plateau differences from `intervel_avg_res`.\n');
    fprintf(fid, '- Denominator (`refBase`) is mean plateau level of reference channel (from `Normalize_to`) from `intervel_avg_res`.\n');
    fprintf(fid, '- Canonical percent is `P2P_percent = 100 * avg_p2p / refBase`.\n');
    fprintf(fid, '- Late 70-90 changes plateau extraction and therefore affects both numerator and denominator when denominator is recomputed.\n\n');
    fprintf(fid, '### Required verdicts\n\n');
    fprintf(fid, '- `NORMALIZATION_IS_CONSTANT = %s`\n', normalIsConst);
    fprintf(fid, '- `LATE_WINDOW_CHANGES_ONLY_NUMERATOR = %s`\n', lateOnlyNum);
    fprintf(fid, '- `LATE_WINDOW_CHANGES_DENOMINATOR = %s`\n', lateChangesDen);
    fprintf(fid, '- `METRIC_DEFINITION_FULLY_UNDERSTOOD = %s`\n\n', metricUnderstood);

    fprintf(fid, '## 2. Matched map comparisons across metric variants\n\n');
    fprintf(fid, '- Canonical percent standard/late and raw signed/raw abs standard/late were computed for matched `(I,T)` points.\n');
    fprintf(fid, '- Frozen denominator control (`P2P_percent_late_frozen_denom`) was computed.\n\n');
    fprintf(fid, '### Required verdicts\n\n');
    fprintf(fid, '- `RAW_VARIANT_COMPUTED = %s`\n', rawComputed);
    fprintf(fid, '- `FROZEN_DENOMINATOR_CONTROL_COMPUTED = %s`\n', frozenComputed);
    fprintf(fid, '- `NORMALIZATION_AFFECTS_LATE_STANDARD_DIFFERENCE = %s`\n\n', normAffects);

    fprintf(fid, '## 3. Quantitative normalization masking test\n\n');
    for ip = 1:numel(compRows)
        fprintf(fid, '- `%s`: pearson=%.6g, slope=%.6g, intercept=%.6g, RMSE=%.6g, nRMSE=%.6g, MAE=%.6g, rank_rho=%.6g\n', ...
            compRows(ip), compPearson(ip), compSlope(ip), compIntercept(ip), compRmse(ip), compNrmse(ip), compMae(ip), compRankRho(ip));
    end
    fprintf(fid, '\n### Required verdicts\n\n');
    fprintf(fid, '- `LATE_EFFECT_VISIBLE_ONLY_WITHOUT_NORMALIZATION = %s`\n', lateOnlyWithoutNorm);
    fprintf(fid, '- `PERCENT_NORMALIZATION_COMPRESSES_DIFFERENCES = %s`\n', pctCompresses);
    fprintf(fid, '- `STANDARD_LATE_EQUIVALENCE_IS_NORMALIZATION_ARTIFACT = %s`\n\n', stdLateNormArtifact);

    fprintf(fid, '## 4. Plateau internal evolution audit\n\n');
    if ~isempty(rowsPlateau)
        fprintf(fid, '- Median `|delta_early_to_late|` = %.6g\n', median(abs(rowsPlateau(:, 12)), 'omitnan'));
        fprintf(fid, '- Median within-plateau slope = %.6g\n', median(rowsPlateau(:, 11), 'omitnan'));
        fprintf(fid, '- Median tail variance ratio (80-100 vs 40-60) = %.6g\n', median(rowsPlateau(:, 16), 'omitnan'));
    else
        fprintf(fid, '- Plateau-internal table is empty; extraction failed for all files.\n');
    end
    fprintf(fid, '\n### Required verdicts\n\n');
    fprintf(fid, '- `PLATEAU_INTERNAL_EVOLUTION_PRESENT = %s`\n', plateauEvolutionPresent);
    fprintf(fid, '- `PLATEAU_INTERNAL_EVOLUTION_SMALL_RELATIVE_TO_SWITCHING = %s`\n', plateauEvolutionSmall);
    fprintf(fid, '- `LATE_WINDOW_EXPECTED_TO_CHANGE_MEASUREMENT = %s`\n\n', lateExpectedChange);

    fprintf(fid, '## 5. Edge contamination audit\n\n');
    if ~isempty(rowsEdge)
        fprintf(fid, '- Median `|70-90 minus 60-80|` = %.6g\n', median(abs(rowsEdge(:, 11)), 'omitnan'));
        fprintf(fid, '- Median `|70-90 minus 50-70|` = %.6g\n', median(abs(rowsEdge(:, 12)), 'omitnan'));
        fprintf(fid, '- Median `std70_90/std60_80` = %.6g\n', median(rowsEdge(:, 10) ./ max(rowsEdge(:, 9), eps), 'omitnan'));
    else
        fprintf(fid, '- Edge-audit table is empty.\n');
    end
    fprintf(fid, '\n### Required verdicts\n\n');
    fprintf(fid, '- `WINDOW_70_90_TOO_CLOSE_TO_EDGE = %s`\n', windowTooClose);
    fprintf(fid, '- `WINDOW_CHOICE_DOMINATES_RESULT = %s`\n', windowDominates);
    fprintf(fid, '- `NOISE_IN_SHORT_WINDOW_DOMINATES = %s`\n\n', noiseShortDominates);

    fprintf(fid, '## 6. Final diagnosis\n\n');
    fprintf(fid, '- `LATE_STANDARD_SIMILARITY_IS_PHYSICAL = %s`\n', finalPhysical);
    fprintf(fid, '- `LATE_STANDARD_SIMILARITY_IS_NORMALIZATION_DRIVEN = %s`\n', finalNormDriven);
    fprintf(fid, '- `LATE_STANDARD_SIMILARITY_IS_ESTIMATOR_DRIVEN = %s`\n', finalEstimatorDriven);
    fprintf(fid, '- `PRIMARY_CAUSE = %s`\n\n', primaryCause);

    fprintf(fid, '## 7. Recommendation\n\n');
    if primaryCause == "NORMALIZATION"
        fprintf(fid, '- Keep canonical metric unchanged for mainline; keep raw/frozen-denominator diagnostics as audit overlays.\n');
    elseif primaryCause == "ESTIMATOR" || primaryCause == "EDGE_CONTAMINATION"
        fprintf(fid, '- Keep canonical metric unchanged; keep late as diagnostic and proceed to focused edge/segment diagnostic follow-up.\n');
    elseif primaryCause == "PHYSICS"
        fprintf(fid, '- Keep canonical metric unchanged; treat late-vs-standard similarity as likely physical unless contradicted by future raw-trace evidence.\n');
    else
        fprintf(fid, '- Keep canonical metric unchanged; keep late only as diagnostic and run one targeted follow-up audit branch.\n');
    end
    fprintf(fid, '\n## Output artifacts\n\n');
    fprintf(fid, '- `tables/xx_switching_normalization_metric_definition.csv`\n');
    fprintf(fid, '- `tables/xx_switching_metric_variants_comparison.csv`\n');
    fprintf(fid, '- `tables/xx_switching_plateau_internal_segments.csv`\n');
    fprintf(fid, '- `tables/xx_switching_window_edge_audit.csv`\n');
    fprintf(fid, '- `tables/xx_switching_normalization_verdicts.csv`\n');
    fprintf(fid, '- `tables/xx_switching_normalization_status.csv`\n');
    fprintf(fid, '- `figures/xx_switching_percent_standard_vs_late.fig` / `.png`\n');
    fprintf(fid, '- `figures/xx_switching_raw_standard_vs_late.fig` / `.png`\n');
    fprintf(fid, '- `figures/xx_switching_variant_scatter.fig` / `.png`\n');
    fprintf(fid, '- `figures/xx_switching_plateau_segments.fig` / `.png`\n');
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(variantsTbl), {'XX switching normalization audit completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    if exist(tablesDir, 'dir') ~= 7
        mkdir(tablesDir);
    end
    if exist(reportsDir, 'dir') ~= 7
        mkdir(reportsDir);
    end

    fidFail = fopen(reportPath, 'w');
    if fidFail >= 0
        fprintf(fidFail, '# XX switching normalization audit (FAILED)\n\n');
        fprintf(fidFail, '- error: `%s`\n', strrep(ME.message, '`', ''''));
        fclose(fidFail);
    end
    statusTbl = table({'FAILED'}, {'NO'}, {ME.message}, {''}, {'XX switching normalization audit failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'RUN_DIR', 'MAIN_RESULT_SUMMARY'});
    writetable(statusTbl, tblStatusPath);

    runDirForStatus = fullfile(repoRoot, 'results', 'analysis', 'runs', 'run_xx_switching_normalization_audit_failure');
    if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
        statusTbl.RUN_DIR = string(run.run_dir);
        writetable(statusTbl, tblStatusPath);
    end
    if exist(runDirForStatus, 'dir') ~= 7
        mkdir(runDirForStatus);
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'XX switching normalization audit failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    writetable(executionStatus, statusPath);
    fidBottomProbeCatch = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
    if fidBottomProbeCatch >= 0
        fclose(fidBottomProbeCatch);
    end
    rethrow(ME);
end

if isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
    writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
end
writetable(executionStatus, statusPath);

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
