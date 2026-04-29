% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: DIAGNOSTIC_FORENSIC — backbone confidence gates on declared inputs (not CORRECTED authoritative backbone substitution)
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
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

outErrorName = 'switching_backbone_error_vs_T.csv';
outShapeName = 'switching_backbone_shape_stability.csv';
outReportName = 'switching_backbone_confidence_audit.md';
outFigureBase = 'switching_backbone_confidence_audit';

try
    cfg = struct();
    cfg.runLabel = 'switching_backbone_confidence_audit';
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
            error('run_switching_backbone_confidence_audit:MissingInput', ...
                'Missing required anchor input: %s', requiredInputs{iReq});
        end
    end

    tblS = readtable(fileSLong);
    tblPhi = readtable(filePhi1);
    tblObs = readtable(fileObs);
    tblVal = readtable(fileVal);

    reqCols = {'T_K', 'current_mA', 'S_percent', 'S_model_pt_percent'};
    for iC = 1:numel(reqCols)
        if ~ismember(reqCols{iC}, tblS.Properties.VariableNames)
            error('run_switching_backbone_confidence_audit:MissingColumn', ...
                'switching_canonical_S_long.csv missing %s', reqCols{iC});
        end
    end

    allTemps = unique(double(tblS.T_K(:)));
    allTemps = allTemps(isfinite(allTemps));
    allTemps = sort(allTemps);
    nT = numel(allTemps);

    rmseObsScdf = nan(nT, 1);
    maxAbsErr = nan(nT, 1);
    residualSignedMean = nan(nT, 1);
    residualSignedIntegral = nan(nT, 1);
    residualL2 = nan(nT, 1);
    corrObsScdf = nan(nT, 1);
    corrObsScdfMeaningful = strings(nT, 1);
    nCurrentPoints = nan(nT, 1);
    currentMaxAbsResidual = nan(nT, 1);
    absResidualFraction3545 = nan(nT, 1);
    meanAbsResidual3545 = nan(nT, 1);
    meanAbsResidualOutside3545 = nan(nT, 1);
    absResidualRatio3545ToOutside = nan(nT, 1);
    currentObsPeak = nan(nT, 1);
    currentScdfPeak = nan(nT, 1);
    peakLocationShift = nan(nT, 1);
    failureCharacterByT = strings(nT, 1);

    currentGridCell = cell(nT, 1);
    residualCell = cell(nT, 1);
    residualNormCell = cell(nT, 1);

    for iT = 1:nT
        tVal = allTemps(iT);
        rowsT = abs(double(tblS.T_K) - tVal) < 1e-9;
        sub = tblS(rowsT, :);
        if isempty(sub)
            corrObsScdfMeaningful(iT) = "NO";
            failureCharacterByT(iT) = "UNCLEAR";
            continue;
        end

        [currSort, idxSort] = sort(double(sub.current_mA));
        obs = double(sub.S_percent(idxSort));
        scdf = double(sub.S_model_pt_percent(idxSort));
        residual = obs - scdf;

        nCurrentPoints(iT) = numel(currSort);
        currentGridCell{iT} = currSort(:);
        residualCell{iT} = residual(:);

        valid = isfinite(obs) & isfinite(scdf);
        validRes = isfinite(residual);
        if any(valid)
            d = obs(valid) - scdf(valid);
            rmseObsScdf(iT) = sqrt(mean(d.^2));
            maxAbsErr(iT) = max(abs(d));
        end
        if any(validRes)
            residualSignedMean(iT) = mean(residual(validRes));
            residualL2(iT) = norm(residual(validRes), 2);
            if sum(validRes) >= 2
                residualSignedIntegral(iT) = trapz(currSort(validRes), residual(validRes));
            end

            [~, idxMax] = max(abs(residual(validRes)));
            idxValid = find(validRes);
            idxGlobal = idxValid(idxMax);
            currentMaxAbsResidual(iT) = currSort(idxGlobal);

            absRes = abs(residual);
            totalAbs = sum(absRes(validRes));
            bandMask = (currSort >= 35) & (currSort <= 45) & validRes;
            outMask = (~((currSort >= 35) & (currSort <= 45))) & validRes;
            if totalAbs > 0
                absResidualFraction3545(iT) = sum(absRes(bandMask)) / totalAbs;
            end
            if any(bandMask)
                meanAbsResidual3545(iT) = mean(absRes(bandMask));
            end
            if any(outMask)
                meanAbsResidualOutside3545(iT) = mean(absRes(outMask));
            end
            if isfinite(meanAbsResidual3545(iT)) && isfinite(meanAbsResidualOutside3545(iT)) && meanAbsResidualOutside3545(iT) > 0
                absResidualRatio3545ToOutside(iT) = meanAbsResidual3545(iT) / meanAbsResidualOutside3545(iT);
            end

            normRes = norm(residual(validRes), 2);
            if normRes > 0
                tmp = nan(size(residual));
                tmp(validRes) = residual(validRes) ./ normRes;
                residualNormCell{iT} = tmp(:);
            else
                residualNormCell{iT} = nan(size(residual(:)));
            end
        end

        if any(valid)
            [~, iObsPk] = max(obs(valid));
            validIdx = find(valid);
            idxObsPk = validIdx(iObsPk);
            currentObsPeak(iT) = currSort(idxObsPk);

            [~, iScdfPk] = max(scdf(valid));
            idxScdfPk = validIdx(iScdfPk);
            currentScdfPeak(iT) = currSort(idxScdfPk);
            peakLocationShift(iT) = currentObsPeak(iT) - currentScdfPeak(iT);
        end

        if sum(valid) >= 2 && std(obs(valid)) > 0 && std(scdf(valid)) > 0
            c = corrcoef(obs(valid), scdf(valid));
            corrObsScdf(iT) = c(1, 2);
            corrObsScdfMeaningful(iT) = "YES";
        else
            corrObsScdfMeaningful(iT) = "NO";
        end

        if isfinite(peakLocationShift(iT)) && abs(peakLocationShift(iT)) >= 10 && isfinite(corrObsScdf(iT)) && corrObsScdf(iT) >= 0.6
            failureCharacterByT(iT) = "LOCATION_DOMINATED";
        elseif isfinite(absResidualFraction3545(iT)) && absResidualFraction3545(iT) >= 0.55 && isfinite(peakLocationShift(iT)) && abs(peakLocationShift(iT)) <= 5
            failureCharacterByT(iT) = "SHAPE_DOMINATED";
        elseif isfinite(absResidualFraction3545(iT)) && absResidualFraction3545(iT) < 0.4
            failureCharacterByT(iT) = "BROAD_MISMATCH";
        else
            failureCharacterByT(iT) = "MIXED";
        end
    end

    refTemp = 18;
    idxRef = find(abs(allTemps - refTemp) < 1e-9, 1);
    if isempty(idxRef)
        idxRef = 1;
    end

    corrResidualToRef = nan(nT, 1);
    corrResidualToPrev = nan(nT, 1);
    normalizedL2ToRef = nan(nT, 1);
    for iT = 1:nT
        currA = currentGridCell{iT};
        resN = residualNormCell{iT};
        if isempty(currA) || isempty(resN)
            continue;
        end

        currRef = currentGridCell{idxRef};
        resRef = residualNormCell{idxRef};
        if numel(currA) == numel(currRef) && all(abs(currA - currRef) < 1e-9)
            v = isfinite(resN) & isfinite(resRef);
            if sum(v) >= 2 && std(resN(v)) > 0 && std(resRef(v)) > 0
                c = corrcoef(resN(v), resRef(v));
                corrResidualToRef(iT) = c(1, 2);
            end
            if any(v)
                normalizedL2ToRef(iT) = norm(resN(v) - resRef(v), 2);
            end
        end

        if iT > 1
            currP = currentGridCell{iT-1};
            resP = residualNormCell{iT-1};
            if numel(currA) == numel(currP) && all(abs(currA - currP) < 1e-9)
                v2 = isfinite(resN) & isfinite(resP);
                if sum(v2) >= 2 && std(resN(v2)) > 0 && std(resP(v2)) > 0
                    c2 = corrcoef(resN(v2), resP(v2));
                    corrResidualToPrev(iT) = c2(1, 2);
                end
            end
        end
    end

    backboneTrend = "INCONCLUSIVE";
    if nT >= 5
        lowMask = allTemps <= 22;
        midMask = (allTemps > 22) & (allTemps <= 26);
        highMask = allTemps >= 28;
        lowErr = rmseObsScdf(lowMask & isfinite(rmseObsScdf));
        midErr = rmseObsScdf(midMask & isfinite(rmseObsScdf));
        highErr = rmseObsScdf(highMask & isfinite(rmseObsScdf));
        if ~isempty(lowErr) && ~isempty(highErr)
            if (std(rmseObsScdf(isfinite(rmseObsScdf))) / mean(rmseObsScdf(isfinite(rmseObsScdf)))) <= 0.2
                backboneTrend = "STABLE_ACROSS_T";
            elseif median(highErr) >= 1.8 * median(lowErr)
                if ~isempty(midErr) && median(midErr) >= 1.3 * median(lowErr)
                    backboneTrend = "GRADUAL_DEGRADATION";
                else
                    backboneTrend = "SHARP_HIGH_T_BREAKDOWN";
                end
            elseif median(highErr) >= 1.3 * median(lowErr)
                backboneTrend = "GRADUAL_DEGRADATION";
            else
                backboneTrend = "INCONCLUSIVE";
            end
        end
    end

    backboneResidualShape = "INCONCLUSIVE";
    shapeTemps = [18; 22; 24; 26; 28; 30];
    idxShape = [];
    for iS = 1:numel(shapeTemps)
        idxFound = find(abs(allTemps - shapeTemps(iS)) < 1e-9, 1);
        if ~isempty(idxFound)
            idxShape(end+1) = idxFound; %#ok<AGROW>
        end
    end
    if numel(idxShape) >= 4
        cShape = corrResidualToRef(idxShape);
        tShape = allTemps(idxShape);
        validShape = isfinite(cShape);
        if sum(validShape) >= 4
            if all(cShape(validShape) >= 0.85)
                backboneResidualShape = "STABLE_SHAPE";
            else
                highCorr = cShape(tShape >= 28 & isfinite(cShape));
                lowCorr = cShape(tShape <= 22 & isfinite(cShape));
                if ~isempty(highCorr) && ~isempty(lowCorr)
                    if median(highCorr) <= 0.4 && median(lowCorr) >= 0.7
                        backboneResidualShape = "NEW_HIGH_T_PATTERN";
                    elseif median(highCorr) < median(lowCorr) - 0.2
                        backboneResidualShape = "GRADUALLY_DEFORMING";
                    else
                        backboneResidualShape = "INCONCLUSIVE";
                    end
                end
            end
        end
    end

    highMask = allTemps >= 26 & allTemps <= 30;
    highTemps = allTemps(highMask);
    highCurrMax = currentMaxAbsResidual(highMask);
    highFrac3545 = absResidualFraction3545(highMask);
    highRatios = absResidualRatio3545ToOutside(highMask);
    ridgeCount = sum((highCurrMax >= 35 & highCurrMax <= 45) | (highFrac3545 >= 0.5));
    broadCount = sum(highFrac3545 < 0.4);
    edgeCount = sum(highCurrMax <= 20 | highCurrMax >= 50);

    highTLocalization = "MIXED";
    if ~isempty(highTemps)
        if ridgeCount >= ceil(0.67 * numel(highTemps))
            highTLocalization = "RIDGE_LOCALIZED";
        elseif broadCount >= ceil(0.67 * numel(highTemps))
            highTLocalization = "BROAD";
        elseif edgeCount >= ceil(0.67 * numel(highTemps))
            highTLocalization = "EDGE_RANGE";
        else
            highTLocalization = "MIXED";
        end
    end

    lowErr = rmseObsScdf(allTemps <= 22 & isfinite(rmseObsScdf));
    highErr = rmseObsScdf(allTemps >= 28 & isfinite(rmseObsScdf));
    growthRatio = NaN;
    if ~isempty(lowErr) && ~isempty(highErr) && median(lowErr) > 0
        growthRatio = median(highErr) / median(lowErr);
    end

    backboneConfidence = "LOW";
    backboneTrust = "NO";
    if (backboneTrend == "STABLE_ACROSS_T" || backboneTrend == "GRADUAL_DEGRADATION") && ...
            (backboneResidualShape == "STABLE_SHAPE" || backboneResidualShape == "GRADUALLY_DEFORMING") && ...
            (highTLocalization == "RIDGE_LOCALIZED" || highTLocalization == "MIXED") && ...
            (isnan(growthRatio) || growthRatio <= 1.7)
        backboneConfidence = "HIGH";
        backboneTrust = "YES";
    elseif (backboneTrend == "GRADUAL_DEGRADATION" || backboneTrend == "INCONCLUSIVE") && ...
            (backboneResidualShape ~= "STABLE_SHAPE") && ...
            (isnan(growthRatio) || growthRatio <= 2.5)
        backboneConfidence = "MODERATE";
        backboneTrust = "PARTIAL";
    else
        backboneConfidence = "LOW";
        backboneTrust = "NO";
    end

    highFailureSet = failureCharacterByT(allTemps >= 24 & allTemps <= 30);
    if isempty(highFailureSet)
        backboneFailureCharacter = "INCONCLUSIVE";
    else
        nLoc = sum(highFailureSet == "LOCATION_DOMINATED");
        nShape = sum(highFailureSet == "SHAPE_DOMINATED");
        nBroad = sum(highFailureSet == "BROAD_MISMATCH");
        nMix = sum(highFailureSet == "MIXED");
        counts = [nLoc, nShape, nBroad, nMix];
        [~, idxMaxCount] = max(counts);
        labels = ["LOCATION_DOMINATED", "SHAPE_DOMINATED", "BROAD_MISMATCH", "MIXED"];
        backboneFailureCharacter = labels(idxMaxCount);
    end

    errorTbl = table( ...
        allTemps, nCurrentPoints, rmseObsScdf, maxAbsErr, residualSignedMean, residualSignedIntegral, residualL2, ...
        corrObsScdf, corrObsScdfMeaningful, currentObsPeak, currentScdfPeak, peakLocationShift, ...
        currentMaxAbsResidual, absResidualFraction3545, meanAbsResidual3545, meanAbsResidualOutside3545, ...
        absResidualRatio3545ToOutside, failureCharacterByT, ...
        'VariableNames', { ...
        'T_K', 'n_current_points', 'rmse_obs_vs_scdf', 'max_abs_error_obs_vs_scdf', ...
        'residual_signed_mean', 'residual_signed_integral_over_current', 'residual_l2_norm', ...
        'corr_obs_scdf', 'corr_obs_scdf_meaningful', 'current_obs_peak_mA', 'current_scdf_peak_mA', 'peak_location_shift_mA', ...
        'current_max_abs_residual_mA', 'abs_residual_fraction_35_45mA', 'mean_abs_residual_35_45mA', ...
        'mean_abs_residual_outside_35_45mA', 'abs_residual_ratio_35_45_to_outside', 'backbone_failure_character_by_T'});

    shapeTbl = table( ...
        allTemps, corrResidualToRef, corrResidualToPrev, normalizedL2ToRef, residualL2, ...
        currentMaxAbsResidual, absResidualFraction3545, absResidualRatio3545ToOutside, ...
        'VariableNames', { ...
        'T_K', 'corr_normalized_backbone_residual_to_ref18K', 'corr_normalized_backbone_residual_to_prevT', ...
        'normalized_residual_l2_distance_to_ref18K', 'residual_l2_norm', ...
        'current_max_abs_backbone_residual_mA', 'abs_residual_fraction_35_45mA', 'abs_residual_ratio_35_45_to_outside'});

    runErrorPath = fullfile(runTablesDir, outErrorName);
    runShapePath = fullfile(runTablesDir, outShapeName);
    writetable(errorTbl, runErrorPath);
    writetable(shapeTbl, runShapePath);

    repoErrorPath = fullfile(repoRoot, 'tables', outErrorName);
    repoShapePath = fullfile(repoRoot, 'tables', outShapeName);
    writetable(errorTbl, repoErrorPath);
    writetable(shapeTbl, repoShapePath);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1450, 600]);
    tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot(allTemps, rmseObsScdf, '-o', 'LineWidth', 1.5);
    hold on;
    plot(allTemps, maxAbsErr, '-s', 'LineWidth', 1.5);
    xlabel('Temperature (K)');
    ylabel('Error');
    title('Backbone-only Error vs Temperature');
    legend({'RMSE Obs vs Scdf', 'Max |Obs-Scdf|'}, 'Location', 'northwest');
    grid on;

    nexttile;
    hold on;
    drawTemps = [18; 22; 24; 26; 28; 30];
    for iD = 1:numel(drawTemps)
        idxD = find(abs(allTemps - drawTemps(iD)) < 1e-9, 1);
        if isempty(idxD) || isempty(currentGridCell{idxD}) || isempty(residualCell{idxD})
            continue;
        end
        plot(currentGridCell{idxD}, residualCell{idxD}, '-o', 'LineWidth', 1.2, ...
            'DisplayName', sprintf('T=%g K', drawTemps(iD)));
    end
    xlabel('Current (mA)');
    ylabel('Backbone residual (Observed - Scdf)');
    title('Backbone Residual Rows');
    legend('Location', 'best');
    grid on;

    sgtitle(sprintf('Backbone Confidence Audit (%s)', anchorRunId), 'Interpreter', 'none');
    figPathFig = fullfile(runFiguresDir, [outFigureBase '.fig']);
    figPathPng = fullfile(runFiguresDir, [outFigureBase '.png']);
    savefig(fig, figPathFig);
    exportgraphics(fig, figPathPng, 'Resolution', 300);
    close(fig);

    reportLines = {};
    reportLines{end+1} = '# Canonical Backbone Confidence Audit';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Scope and Constraints';
    reportLines{end+1} = '';
    reportLines{end+1} = ['- Anchor run only: `', anchorRunId, '`'];
    reportLines{end+1} = '- Canonical tables only.';
    reportLines{end+1} = '- No higher-order extension, no mode-2, no width-based parametrization.';
    reportLines{end+1} = '- Diagnosis only.';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Canonical Inputs';
    reportLines{end+1} = '';
    reportLines{end+1} = ['1. `', fileSLong, '`'];
    reportLines{end+1} = ['2. `', filePhi1, '` (loaded for provenance consistency only; not used in metrics)'];
    reportLines{end+1} = ['3. `', fileObs, '` (loaded for provenance consistency only; not used in backbone-only metrics)'];
    reportLines{end+1} = ['4. `', fileVal, '`'];
    reportLines{end+1} = '';
    reportLines{end+1} = '## Backbone Trend and Shape Verdicts';
    reportLines{end+1} = '';
    reportLines{end+1} = ['- BACKBONE_TREND = ', char(backboneTrend)];
    reportLines{end+1} = ['- BACKBONE_RESIDUAL_SHAPE = ', char(backboneResidualShape)];
    reportLines{end+1} = ['- BACKBONE_FAILURE_CHARACTER = ', char(backboneFailureCharacter)];
    reportLines{end+1} = ['- HIGH_T_BACKBONE_ERROR_LOCALIZATION = ', char(highTLocalization)];
    reportLines{end+1} = ['- CANONICAL_BACKBONE_CONFIDENCE = ', char(backboneConfidence)];
    reportLines{end+1} = ['- BACKBONE_IS_SUFFICIENTLY_TRUSTWORTHY_TO_SUPPORT_HIGHER_ORDER_EXTENSION = ', char(backboneTrust)];
    reportLines{end+1} = '';
    reportLines{end+1} = '## High-T Localization Notes (26-30 K)';
    reportLines{end+1} = '';
    if ~isempty(highTemps)
        for iH = 1:numel(highTemps)
            idxH = find(abs(allTemps - highTemps(iH)) < 1e-9, 1);
            reportLines{end+1} = sprintf('- T=%g K: current_max_abs_residual=%g mA, frac_35_45=%0.6g, ratio_35_45_to_outside=%0.6g', ...
                highTemps(iH), currentMaxAbsResidual(idxH), absResidualFraction3545(idxH), highRatios(iH));
        end
    else
        reportLines{end+1} = '- No temperatures in 26-30 K window found.';
    end
    reportLines{end+1} = '';
    reportLines{end+1} = '## Output Artifacts';
    reportLines{end+1} = '';
    reportLines{end+1} = ['- `', runErrorPath, '`'];
    reportLines{end+1} = ['- `', runShapePath, '`'];
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
    fidR = fopen(runReportPath, 'w');
    if fidR < 0
        error('run_switching_backbone_confidence_audit:ReportWriteFailed', ...
            'Cannot write run report: %s', runReportPath);
    end
    for iL = 1:numel(reportLines)
        fprintf(fidR, '%s\n', reportLines{iL});
    end
    fclose(fidR);

    repoReportPath = fullfile(repoRoot, 'reports', outReportName);
    fidR2 = fopen(repoReportPath, 'w');
    if fidR2 < 0
        error('run_switching_backbone_confidence_audit:ReportWriteFailed', ...
            'Cannot write repo report: %s', repoReportPath);
    end
    for iL = 1:numel(reportLines)
        fprintf(fidR2, '%s\n', reportLines{iL});
    end
    fclose(fidR2);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, ...
        {'backbone confidence audit completed from anchor canonical tables only'}, true);

    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_backbone_confidence_audit_failure');
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
        {'backbone confidence audit failed'}, true);
    failReport = fullfile(runDir, 'reports', outReportName);
    fidFail = fopen(failReport, 'w');
    if fidFail >= 0
        fprintf(fidFail, '# Canonical Backbone Confidence Audit FAILED\n\n');
        fprintf(fidFail, '- error_id: `%s`\n', ME.identifier);
        fprintf(fidFail, '- error_message: `%s`\n', ME.message);
        fclose(fidFail);
    end
    rethrow(ME);
end
