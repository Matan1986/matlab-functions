clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';

anchorRunId = 'run_2026_04_03_000147_switching_canonical';
anchorRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', anchorRunId);
anchorTablesDir = fullfile(anchorRunDir, 'tables');

fileSLong = fullfile(anchorTablesDir, 'switching_canonical_S_long.csv');
filePhi1 = fullfile(anchorTablesDir, 'switching_canonical_phi1.csv');
fileObs = fullfile(anchorTablesDir, 'switching_canonical_observables.csv');
fileVal = fullfile(anchorTablesDir, 'switching_canonical_validation.csv');

outErrorName = 'switching_reconstruction_error_vs_T_window18_30.csv';
outFailureName = 'switching_reconstruction_failure_mode_vs_T_window18_30.csv';
outReportName = 'switching_reconstruction_window18_30_diagnostic.md';
outFigureBase = 'switching_reconstruction_window18_30_diagnostic';

try
    cfg = struct();
    cfg.runLabel = 'switching_recon_window18_30_diagnostic';
    cfg.dataset = anchorRunId;
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTablesDir = fullfile(runDir, 'tables');
    runReportsDir = fullfile(runDir, 'reports');
    runFiguresDir = fullfile(runDir, 'figures');
    if exist(runTablesDir, 'dir') ~= 7
        mkdir(runTablesDir);
    end
    if exist(runReportsDir, 'dir') ~= 7
        mkdir(runReportsDir);
    end
    if exist(runFiguresDir, 'dir') ~= 7
        mkdir(runFiguresDir);
    end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0
        fprintf(fidTop, 'SCRIPT_ENTERED\n');
        fclose(fidTop);
    end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    requiredInputs = {fileSLong, filePhi1, fileObs, fileVal};
    for iReq = 1:numel(requiredInputs)
        if exist(requiredInputs{iReq}, 'file') ~= 2
            error('run_switching_reconstruction_window18_30_diagnostic:MissingInput', ...
                'Missing required anchor input: %s', requiredInputs{iReq});
        end
    end

    tblS = readtable(fileSLong);
    tblPhi = readtable(filePhi1);
    tblObs = readtable(fileObs);
    tblVal = readtable(fileVal);

    mustS = {'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent'};
    mustPhi = {'current_mA', 'Phi1'};
    mustObs = {'T_K', 'kappa1'};
    for i = 1:numel(mustS)
        if ~ismember(mustS{i}, tblS.Properties.VariableNames)
            error('run_switching_reconstruction_window18_30_diagnostic:MissingColumn', ...
                'switching_canonical_S_long.csv missing %s', mustS{i});
        end
    end
    for i = 1:numel(mustPhi)
        if ~ismember(mustPhi{i}, tblPhi.Properties.VariableNames)
            error('run_switching_reconstruction_window18_30_diagnostic:MissingColumn', ...
                'switching_canonical_phi1.csv missing %s', mustPhi{i});
        end
    end
    for i = 1:numel(mustObs)
        if ~ismember(mustObs{i}, tblObs.Properties.VariableNames)
            error('run_switching_reconstruction_window18_30_diagnostic:MissingColumn', ...
                'switching_canonical_observables.csv missing %s', mustObs{i});
        end
    end

    allTemps = unique(double(tblS.T_K(:)));
    allTemps = allTemps(isfinite(allTemps));
    targetTemps = [18; 20; 22; 24; 26; 28; 30];
    nTarget = numel(targetTemps);

    usedTemps = nan(nTarget, 1);
    usedNearest = strings(nTarget, 1);
    nearestDelta = nan(nTarget, 1);
    missingReason = strings(nTarget, 1);
    nCurrPoints = nan(nTarget, 1);

    rmseFull = nan(nTarget, 1);
    rmseScdf = nan(nTarget, 1);
    maxAbsErr = nan(nTarget, 1);
    residualL2 = nan(nTarget, 1);
    residualMean = nan(nTarget, 1);
    residualIntegral = nan(nTarget, 1);
    corrObsFull = nan(nTarget, 1);
    corrObsScdf = nan(nTarget, 1);
    corrObsFullMeaningful = strings(nTarget, 1);
    corrObsScdfMeaningful = strings(nTarget, 1);
    currentMaxAbsResidual = nan(nTarget, 1);
    band3545FractionAbs = nan(nTarget, 1);
    band3545MeanAbs = nan(nTarget, 1);
    outside3545MeanAbs = nan(nTarget, 1);
    band3545Ratio = nan(nTarget, 1);
    residualConcentratedNear3545 = strings(nTarget, 1);

    deltaRmse = nan(nTarget, 1);
    fractionalImprovement = nan(nTarget, 1);
    failureMode = strings(nTarget, 1);
    shapeCorrTo18K = nan(nTarget, 1);

    residualVecByTarget = cell(nTarget, 1);
    currentVecByTarget = cell(nTarget, 1);

    for iT = 1:nTarget
        tReq = targetTemps(iT);
        exactIdx = find(abs(allTemps - tReq) < 1e-9, 1);
        if ~isempty(exactIdx)
            usedTemps(iT) = tReq;
            usedNearest(iT) = "NO";
            nearestDelta(iT) = 0;
        else
            if isempty(allTemps)
                usedTemps(iT) = NaN;
                usedNearest(iT) = "NO";
                nearestDelta(iT) = NaN;
                missingReason(iT) = "No temperatures in canonical table";
            else
                [dMin, idxMin] = min(abs(allTemps - tReq));
                if dMin <= 2.1
                    usedTemps(iT) = allTemps(idxMin);
                    usedNearest(iT) = "YES";
                    nearestDelta(iT) = dMin;
                    missingReason(iT) = sprintf('Requested temperature missing; used nearest canonical T=%g K.', allTemps(idxMin));
                else
                    usedTemps(iT) = NaN;
                    usedNearest(iT) = "NO";
                    nearestDelta(iT) = dMin;
                    missingReason(iT) = sprintf('Requested temperature missing and nearest canonical T is too far (delta=%g K).', dMin);
                end
            end
        end

        if ~isfinite(usedTemps(iT))
            corrObsFullMeaningful(iT) = "NO";
            corrObsScdfMeaningful(iT) = "NO";
            failureMode(iT) = "UNCLEAR";
            residualConcentratedNear3545(iT) = "NO";
            continue;
        end

        rowsT = abs(double(tblS.T_K) - usedTemps(iT)) < 1e-9;
        sub = tblS(rowsT, :);
        if isempty(sub)
            missingReason(iT) = "No S_long rows at selected temperature.";
            corrObsFullMeaningful(iT) = "NO";
            corrObsScdfMeaningful(iT) = "NO";
            failureMode(iT) = "UNCLEAR";
            residualConcentratedNear3545(iT) = "NO";
            continue;
        end

        [currSort, idxSort] = sort(double(sub.current_mA));
        obs = double(sub.S_percent(idxSort));
        scdf = double(sub.S_model_pt_percent(idxSort));
        nCurrPoints(iT) = numel(currSort);

        rowObs = find(abs(double(tblObs.T_K) - usedTemps(iT)) < 1e-9, 1);
        if isempty(rowObs)
            missingReason(iT) = "kappa1 missing at selected temperature.";
            corrObsFullMeaningful(iT) = "NO";
            corrObsScdfMeaningful(iT) = "NO";
            failureMode(iT) = "UNCLEAR";
            residualConcentratedNear3545(iT) = "NO";
            continue;
        end
        kappa1 = double(tblObs.kappa1(rowObs));

        phiVec = nan(numel(currSort), 1);
        for iI = 1:numel(currSort)
            rowPhi = find(abs(double(tblPhi.current_mA) - currSort(iI)) < 1e-9, 1);
            if ~isempty(rowPhi)
                phiVec(iI) = double(tblPhi.Phi1(rowPhi));
            end
        end
        if any(~isfinite(phiVec))
            missingReason(iT) = "phi1 missing for one or more currents.";
        end

        fullRecon = scdf + kappa1 .* phiVec;
        residual = obs - fullRecon;

        validFull = isfinite(obs) & isfinite(fullRecon);
        validScdf = isfinite(obs) & isfinite(scdf);
        validResidual = isfinite(residual);

        if any(validFull)
            rmseFull(iT) = sqrt(mean((obs(validFull) - fullRecon(validFull)).^2));
            maxAbsErr(iT) = max(abs(obs(validFull) - fullRecon(validFull)));
        end
        if any(validScdf)
            rmseScdf(iT) = sqrt(mean((obs(validScdf) - scdf(validScdf)).^2));
        end
        if any(validResidual)
            residualL2(iT) = norm(residual(validResidual), 2);
            residualMean(iT) = mean(residual(validResidual));
            if sum(validResidual) >= 2
                residualIntegral(iT) = trapz(currSort(validResidual), residual(validResidual));
            end
            [~, idxMax] = max(abs(residual(validResidual)));
            idxValid = find(validResidual);
            idxMaxGlobal = idxValid(idxMax);
            currentMaxAbsResidual(iT) = currSort(idxMaxGlobal);

            absRes = abs(residual);
            totalAbs = sum(absRes(validResidual));
            bandMask = (currSort >= 35) & (currSort <= 45) & validResidual;
            outMask = (~((currSort >= 35) & (currSort <= 45))) & validResidual;
            if totalAbs > 0
                band3545FractionAbs(iT) = sum(absRes(bandMask)) / totalAbs;
            end
            if any(bandMask)
                band3545MeanAbs(iT) = mean(absRes(bandMask));
            end
            if any(outMask)
                outside3545MeanAbs(iT) = mean(absRes(outMask));
            end
            if isfinite(band3545MeanAbs(iT)) && isfinite(outside3545MeanAbs(iT)) && outside3545MeanAbs(iT) > 0
                band3545Ratio(iT) = band3545MeanAbs(iT) / outside3545MeanAbs(iT);
            end
            if isfinite(band3545FractionAbs(iT)) && band3545FractionAbs(iT) >= 0.5
                residualConcentratedNear3545(iT) = "YES";
            else
                residualConcentratedNear3545(iT) = "NO";
            end
        end

        if sum(validFull) >= 2
            stdObs = std(obs(validFull));
            stdFull = std(fullRecon(validFull));
            if stdObs > 0 && stdFull > 0
                cMat = corrcoef(obs(validFull), fullRecon(validFull));
                corrObsFull(iT) = cMat(1, 2);
                corrObsFullMeaningful(iT) = "YES";
            else
                corrObsFullMeaningful(iT) = "NO";
            end
        else
            corrObsFullMeaningful(iT) = "NO";
        end

        if sum(validScdf) >= 2
            stdObs2 = std(obs(validScdf));
            stdScdf = std(scdf(validScdf));
            if stdObs2 > 0 && stdScdf > 0
                cMat2 = corrcoef(obs(validScdf), scdf(validScdf));
                corrObsScdf(iT) = cMat2(1, 2);
                corrObsScdfMeaningful(iT) = "YES";
            else
                corrObsScdfMeaningful(iT) = "NO";
            end
        else
            corrObsScdfMeaningful(iT) = "NO";
        end

        if isfinite(rmseScdf(iT)) && rmseScdf(iT) > 0 && isfinite(rmseFull(iT))
            deltaRmse(iT) = rmseScdf(iT) - rmseFull(iT);
            fractionalImprovement(iT) = deltaRmse(iT) / rmseScdf(iT);
        end

        if isfinite(deltaRmse(iT)) && isfinite(fractionalImprovement(iT))
            if fractionalImprovement(iT) >= 0.2 && rmseFull(iT) <= 0.8 * rmseScdf(iT)
                failureMode(iT) = "BACKBONE_LIMITED";
            elseif fractionalImprovement(iT) < 0.1 && rmseFull(iT) >= 0.8 * rmseScdf(iT)
                if isfinite(rmseScdf(iT)) && rmseScdf(iT) > 0.03
                    failureMode(iT) = "BOTH";
                else
                    failureMode(iT) = "RANK1_INSUFFICIENT";
                end
            elseif fractionalImprovement(iT) < 0
                failureMode(iT) = "RANK1_INSUFFICIENT";
            else
                failureMode(iT) = "UNCLEAR";
            end
        else
            failureMode(iT) = "UNCLEAR";
        end

        residualVecByTarget{iT} = residual(:);
        currentVecByTarget{iT} = currSort(:);
    end

    idx18 = find(targetTemps == 18, 1);
    if isempty(idx18) || ~isfinite(usedTemps(idx18)) || isempty(residualVecByTarget{idx18})
        idxBase = find(~cellfun(@isempty, residualVecByTarget), 1);
    else
        idxBase = idx18;
    end

    if ~isempty(idxBase)
        baseResidual = residualVecByTarget{idxBase};
        baseCurrent = currentVecByTarget{idxBase};
        for iT = 1:nTarget
            if isempty(residualVecByTarget{iT})
                continue;
            end
            curResidual = residualVecByTarget{iT};
            curCurrent = currentVecByTarget{iT};
            if numel(curResidual) == numel(baseResidual) && all(abs(curCurrent - baseCurrent) < 1e-9)
                validShape = isfinite(baseResidual) & isfinite(curResidual);
                if sum(validShape) >= 2 && std(baseResidual(validShape)) > 0 && std(curResidual(validShape)) > 0
                    cShape = corrcoef(baseResidual(validShape), curResidual(validShape));
                    shapeCorrTo18K(iT) = cShape(1, 2);
                end
            end
        end
    end

    validRmse = isfinite(rmseFull) & isfinite(usedTemps);
    tValid = usedTemps(validRmse);
    eValid = rmseFull(validRmse);
    [tSort, idxSort] = sort(tValid);
    eSort = eValid(idxSort);

    highTPattern = "INCONCLUSIVE";
    if numel(eSort) >= 3
        earlyMask = tSort <= 22;
        riseMask = tSort >= 24;
        if sum(earlyMask) >= 3 && sum(riseMask) >= 2
            eEarly = eSort(earlyMask);
            eRise = eSort(riseMask);
            stableEarly = (mean(eEarly) > 0) && (std(eEarly) / mean(eEarly) <= 0.2);
            risesAfter = median(eRise) >= 2.0 * median(eEarly);
            if stableEarly && risesAfter
                highTPattern = "STABLE_THEN_RISES";
            end
        end
        if highTPattern == "INCONCLUSIVE" && numel(eSort) >= 4
            dE = diff(eSort);
            posFrac = sum(dE > 0) / numel(dE);
            if eSort(end) >= 1.8 * eSort(1) && posFrac >= 0.8
                highTPattern = "GRADUAL_FROM_LOW_T";
            end
        end
        if highTPattern == "INCONCLUSIVE"
            idx30 = find(abs(tSort - 30) < 1e-9, 1);
            if ~isempty(idx30) && idx30 > 1
                e30 = eSort(idx30);
                ePre = eSort(1:idx30-1);
                if numel(ePre) >= 2
                    if e30 >= 1.8 * median(ePre) && (max(ePre) - min(ePre)) <= 0.5 * e30
                        highTPattern = "LOCAL_30K";
                    end
                end
            end
        end
    end

    residualShapeEvolution = "INCONCLUSIVE";
    validShapeCorr = isfinite(shapeCorrTo18K) & isfinite(usedTemps);
    if sum(validShapeCorr) >= 3
        tShape = usedTemps(validShapeCorr);
        cShape = shapeCorrTo18K(validShapeCorr);
        highShape = cShape(tShape >= 26);
        lowShape = cShape(tShape <= 24);
        ampLow = residualL2(usedTemps <= 24 & isfinite(residualL2));
        ampHigh = residualL2(usedTemps >= 26 & isfinite(residualL2));
        ampRise = false;
        if ~isempty(ampLow) && ~isempty(ampHigh) && median(ampLow) > 0
            ampRise = median(ampHigh) >= 1.5 * median(ampLow);
        end
        if ~isempty(highShape) && all(highShape >= 0.85) && ampRise
            residualShapeEvolution = "SAME_PATTERN_STRENGTHENS";
        elseif ~isempty(highShape) && any(highShape <= 0.6)
            residualShapeEvolution = "NEW_PATTERN_EMERGES";
        elseif ~isempty(highShape) && ~isempty(lowShape) && (median(highShape) < median(lowShape) - 0.15)
            residualShapeEvolution = "MIXED";
        else
            residualShapeEvolution = "INCONCLUSIVE";
        end
    end

    mismatchGrows3545 = "INCONCLUSIVE";
    highBand = band3545MeanAbs(usedTemps >= 26 & isfinite(usedTemps) & isfinite(band3545MeanAbs));
    lowBand = band3545MeanAbs(usedTemps <= 24 & isfinite(usedTemps) & isfinite(band3545MeanAbs));
    highOut = outside3545MeanAbs(usedTemps >= 26 & isfinite(usedTemps) & isfinite(outside3545MeanAbs));
    lowOut = outside3545MeanAbs(usedTemps <= 24 & isfinite(usedTemps) & isfinite(outside3545MeanAbs));
    if ~isempty(highBand) && ~isempty(lowBand) && ~isempty(highOut) && ~isempty(lowOut)
        if median(highBand) > median(lowBand) && median(highBand ./ max(highOut, eps)) > median(lowBand ./ max(lowOut, eps))
            mismatchGrows3545 = "YES";
        else
            mismatchGrows3545 = "NO";
        end
    end

    transitionProximity = "NO";
    highTMaskMode = usedTemps >= 26 & strlength(failureMode) > 0;
    nHighMode = sum(highTMaskMode);
    highModeIssueCount = 0;
    if nHighMode > 0
        fmHigh = failureMode(highTMaskMode);
        highModeIssueCount = sum(fmHigh == "RANK1_INSUFFICIENT" | fmHigh == "BOTH");
    end
    highModeIssueFrac = 0;
    if nHighMode > 0
        highModeIssueFrac = highModeIssueCount / nHighMode;
    end
    if highTPattern == "LOCAL_30K" && highModeIssueFrac >= 0.67 && residualShapeEvolution == "NEW_PATTERN_EMERGES"
        transitionProximity = "YES";
    elseif highTPattern ~= "INCONCLUSIVE"
        if highModeIssueFrac >= 0.5 || residualShapeEvolution ~= "INCONCLUSIVE" || mismatchGrows3545 == "YES"
            transitionProximity = "PARTIAL";
        else
            transitionProximity = "NO";
        end
    else
        if residualShapeEvolution == "NEW_PATTERN_EMERGES" && mismatchGrows3545 == "YES"
            transitionProximity = "PARTIAL";
        else
            transitionProximity = "NO";
        end
    end

    errorTbl = table( ...
        targetTemps, usedTemps, usedNearest, nearestDelta, missingReason, nCurrPoints, ...
        rmseFull, rmseScdf, maxAbsErr, residualL2, residualMean, residualIntegral, ...
        corrObsFull, corrObsFullMeaningful, corrObsScdf, corrObsScdfMeaningful, ...
        currentMaxAbsResidual, band3545FractionAbs, band3545MeanAbs, outside3545MeanAbs, band3545Ratio, ...
        residualConcentratedNear3545, ...
        'VariableNames', { ...
        'requested_temp_K', 'used_temp_K', 'used_nearest', 'nearest_delta_K', 'missing_or_substitution_note', 'n_current_points', ...
        'rmse_obs_vs_full', 'rmse_obs_vs_scdf', 'max_abs_error_obs_vs_full', 'residual_l2_norm', 'residual_signed_mean', 'residual_signed_integral_over_current', ...
        'corr_obs_full', 'corr_obs_full_meaningful', 'corr_obs_scdf', 'corr_obs_scdf_meaningful', ...
        'current_of_max_abs_residual_mA', 'abs_residual_fraction_35_45mA', 'mean_abs_residual_35_45mA', 'mean_abs_residual_outside_35_45mA', 'abs_residual_ratio_35_45_to_outside', ...
        'residual_concentrated_near_35_45mA'});

    failureTbl = table( ...
        targetTemps, usedTemps, rmseScdf, rmseFull, deltaRmse, fractionalImprovement, ...
        failureMode, shapeCorrTo18K, ...
        'VariableNames', { ...
        'requested_temp_K', 'used_temp_K', 'rmse_obs_vs_scdf', 'rmse_obs_vs_full', 'delta_rmse_scdf_minus_full', 'fractional_improvement', ...
        'failure_mode', 'residual_shape_corr_to_18K'});

    runErrorPath = fullfile(runTablesDir, outErrorName);
    runFailurePath = fullfile(runTablesDir, outFailureName);
    writetable(errorTbl, runErrorPath);
    writetable(failureTbl, runFailurePath);

    repoErrorPath = fullfile(repoRoot, 'tables', outErrorName);
    repoFailurePath = fullfile(repoRoot, 'tables', outFailureName);
    writetable(errorTbl, repoErrorPath);
    writetable(failureTbl, repoFailurePath);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1450, 600]);
    tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot(usedTemps, rmseScdf, '-o', 'LineWidth', 1.5, 'DisplayName', 'RMSE Obs vs Scdf');
    hold on;
    plot(usedTemps, rmseFull, '-s', 'LineWidth', 1.5, 'DisplayName', 'RMSE Obs vs Full');
    xlabel('Temperature (K)');
    ylabel('RMSE');
    title('Reconstruction Error vs Temperature');
    legend('Location', 'northwest');
    grid on;

    nexttile;
    hold on;
    drawTemps = [18; 24; 26; 30];
    for iD = 1:numel(drawTemps)
        idxD = find(targetTemps == drawTemps(iD), 1);
        if isempty(idxD) || ~isfinite(usedTemps(idxD)) || isempty(residualVecByTarget{idxD})
            continue;
        end
        plot(currentVecByTarget{idxD}, residualVecByTarget{idxD}, '-o', 'LineWidth', 1.2, ...
            'DisplayName', sprintf('T=%g K', usedTemps(idxD)));
    end
    xlabel('Current (mA)');
    ylabel('Residual (Observed - Full)');
    title('Residual vs Current (Selected Temperatures)');
    legend('Location', 'best');
    grid on;

    sgtitle(sprintf('Canonical Anchor Diagnostic (%s)', anchorRunId), 'Interpreter', 'none');

    figPathFig = fullfile(runFiguresDir, [outFigureBase '.fig']);
    figPathPng = fullfile(runFiguresDir, [outFigureBase '.png']);
    savefig(fig, figPathFig);
    exportgraphics(fig, figPathPng, 'Resolution', 300);
    close(fig);

    reportLines = {};
    reportLines{end+1} = '# Switching Reconstruction Window 18-30 K Diagnostic';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Scope';
    reportLines{end+1} = '';
    reportLines{end+1} = ['- Anchor run only: `', anchorRunId, '`'];
    reportLines{end+1} = '- Inputs are canonical anchor tables only.';
    reportLines{end+1} = '- No non-canonical source, no non-anchor run, no width/ridge-width logic.';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Canonical Inputs';
    reportLines{end+1} = '';
    reportLines{end+1} = ['1. `', fileSLong, '`'];
    reportLines{end+1} = ['2. `', filePhi1, '`'];
    reportLines{end+1} = ['3. `', fileObs, '`'];
    reportLines{end+1} = ['4. `', fileVal, '`'];
    reportLines{end+1} = '';
    reportLines{end+1} = '## Requested Temperature Set';
    reportLines{end+1} = '';
    reportLines{end+1} = '- Requested: 18, 20, 22, 24, 26, 28, 30 K';
    reportLines{end+1} = ['- Available canonical temperatures in S_long: ', strjoin(cellstr(string(allTemps')), ', '), ' K'];
    reportLines{end+1} = '';
    reportLines{end+1} = '## High-T Degradation Pattern';
    reportLines{end+1} = '';
    reportLines{end+1} = ['- HIGH_T_DEGRADATION_PATTERN = ', char(highTPattern)];
    reportLines{end+1} = '';
    reportLines{end+1} = '## Backbone vs Rank-1';
    reportLines{end+1} = '';
    reportLines{end+1} = '- Failure mode table written to switching_reconstruction_failure_mode_vs_T_window18_30.csv';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Current-Localized Mismatch';
    reportLines{end+1} = '';
    reportLines{end+1} = ['- Mismatch growth around 35-45 mA: ', char(mismatchGrows3545)];
    reportLines{end+1} = '';
    reportLines{end+1} = '## Residual Shape Evolution';
    reportLines{end+1} = '';
    reportLines{end+1} = ['- RESIDUAL_SHAPE_EVOLUTION = ', char(residualShapeEvolution)];
    reportLines{end+1} = '';
    reportLines{end+1} = '## Transition Boundary Interpretation';
    reportLines{end+1} = '';
    reportLines{end+1} = ['- TRANSITION_PROXIMITY_EXPLAINS_DEGRADATION = ', char(transitionProximity)];
    reportLines{end+1} = '';
    reportLines{end+1} = '## Output Artifacts';
    reportLines{end+1} = '';
    reportLines{end+1} = ['- `', runErrorPath, '`'];
    reportLines{end+1} = ['- `', runFailurePath, '`'];
    reportLines{end+1} = ['- `', fullfile(runReportsDir, outReportName), '`'];
    reportLines{end+1} = ['- `', figPathPng, '`'];
    reportLines{end+1} = '';
    reportLines{end+1} = '## Compliance';
    reportLines{end+1} = '';
    reportLines{end+1} = '- ANCHOR_ONLY = YES';
    reportLines{end+1} = '- TABLES_ONLY = YES';
    reportLines{end+1} = '- NON_CANONICAL_SOURCE_USED = NO';
    reportLines{end+1} = ['- validation_rows_loaded = ', num2str(height(tblVal))];

    runReportPath = fullfile(runReportsDir, outReportName);
    fidReport = fopen(runReportPath, 'w');
    if fidReport < 0
        error('run_switching_reconstruction_window18_30_diagnostic:ReportWriteFailed', ...
            'Cannot write report: %s', runReportPath);
    end
    for iLine = 1:numel(reportLines)
        fprintf(fidReport, '%s\n', reportLines{iLine});
    end
    fclose(fidReport);

    repoReportPath = fullfile(repoRoot, 'reports', outReportName);
    fidReport2 = fopen(repoReportPath, 'w');
    if fidReport2 < 0
        error('run_switching_reconstruction_window18_30_diagnostic:ReportWriteFailed', ...
            'Cannot write report: %s', repoReportPath);
    end
    for iLine = 1:numel(reportLines)
        fprintf(fidReport2, '%s\n', reportLines{iLine});
    end
    fclose(fidReport2);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, sum(isfinite(usedTemps)), ...
        {'window18_30 diagnostic completed from anchor canonical tables only'}, true);

    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_reconstruction_window18_30_diagnostic_failure');
        if exist(runDir, 'dir') ~= 7
            mkdir(runDir);
        end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7
        mkdir(fullfile(runDir, 'tables'));
    end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7
        mkdir(fullfile(runDir, 'reports'));
    end
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, ...
        {'window18_30 diagnostic failed'}, true);
    failReport = fullfile(runDir, 'reports', outReportName);
    fidFail = fopen(failReport, 'w');
    if fidFail >= 0
        fprintf(fidFail, '# Switching Reconstruction Window 18-30 K Diagnostic FAILED\n\n');
        fprintf(fidFail, '- error_id: `%s`\n', ME.identifier);
        fprintf(fidFail, '- error_message: `%s`\n', ME.message);
        fclose(fidFail);
    end
    rethrow(ME);
end
