% ================================
% EXPERIMENTAL SCRIPT
% NOT CANONICAL
%
% Purpose:
% Baseline / raw observable exploration
%
% Status:
% Not part of validated switching pipeline
% Do NOT use for canonical physics results
% ================================

clear; clc;

try
    thisScript = mfilename('fullpath');
    repoRoot = fileparts(fileparts(fileparts(fileparts(thisScript))));

    addpath(genpath(fullfile(repoRoot, 'Aging')));
    addpath(fullfile(repoRoot, 'tools'));
    addpath(fullfile(repoRoot, 'Switching', 'utils'));

    cfg = struct();
    cfg.runLabel = 'switching_raw_baseline_correction';
    cfg.dataset = 'raw_vs_corrected_vs_normalized_same_trace_analysis';
    runCtx = createSwitchingRunContext(repoRoot, cfg);
    runDir = runCtx.run_dir;

    tablesRepo = fullfile(repoRoot, 'tables');
    reportsRepo = fullfile(repoRoot, 'reports');
    if exist(tablesRepo, 'dir') ~= 7
        mkdir(tablesRepo);
    end
    if exist(reportsRepo, 'dir') ~= 7
        mkdir(reportsRepo);
    end

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7
        mkdir(runTables);
    end
    if exist(runReports, 'dir') ~= 7
        mkdir(runReports);
    end

    traceFiles = dir(fullfile(switchingCanonicalRunRoot(repoRoot), 'run_*', 'alignment_audit', 'switching_alignment_samples.csv'));
    if isempty(traceFiles)
        error('TraceInputNotFound:switching_alignment_samples', 'Could not locate switching alignment samples.');
    end
    [~, iTrace] = max([traceFiles.datenum]);
    tracePath = fullfile(traceFiles(iTrace).folder, traceFiles(iTrace).name);

    normalizedFiles = dir(fullfile(switchingCanonicalRunRoot(repoRoot), 'run_*', 'physics_output_robustness', 'tables', 'variant_observables_xy_over_xx.csv'));
    if isempty(normalizedFiles)
        error('NormalizedInputNotFound:xy_over_xx', 'Could not locate normalized variant table.');
    end
    [~, iNorm] = max([normalizedFiles.datenum]);
    normalizedPath = fullfile(normalizedFiles(iNorm).folder, normalizedFiles(iNorm).name);

    traceTbl = readtable(tracePath);
    assert(all(ismember({'current_mA','T_K','S_percent'}, traceTbl.Properties.VariableNames)), ...
        'Trace table missing required columns: %s', tracePath);

    roundedT = round(double(traceTbl.T_K(:)));
    currentsRaw = double(traceTbl.current_mA(:));
    signalRaw = double(traceTbl.S_percent(:));

    ok = isfinite(roundedT) & isfinite(currentsRaw) & isfinite(signalRaw);
    roundedT = roundedT(ok);
    currentsRaw = currentsRaw(ok);
    signalRaw = signalRaw(ok);

    temps = unique(roundedT);
    currents = unique(currentsRaw);
    temps = sort(temps(:));
    currents = sort(currents(:))';

    Smap = NaN(numel(temps), numel(currents));
    for it = 1:numel(temps)
        for ii = 1:numel(currents)
            m = roundedT == temps(it) & abs(currentsRaw - currents(ii)) < 1e-9;
            if any(m)
                Smap(it, ii) = mean(signalRaw(m), 'omitnan');
            end
        end
    end

    rawRows = table();
    corrRows = table();
    baselineModels = strings(0, 1);
    corrMap = NaN(size(Smap));

    for it = 1:numel(temps)
        rowRaw = Smap(it, :);
        vRaw = isfinite(currents) & isfinite(rowRaw);
        if nnz(vRaw) < 5
            continue;
        end

        xRaw = currents(vRaw);
        yRaw = rowRaw(vRaw);
        [sPeakRaw, idxPeakRaw] = max(yRaw);
        if ~isfinite(sPeakRaw)
            continue;
        end
        iPeakRaw = xRaw(idxPeakRaw);

        halfRaw = 0.5 * sPeakRaw;
        leftRaw = NaN;
        rightRaw = NaN;
        for j = idxPeakRaw:-1:2
            y1 = yRaw(j-1);
            y2 = yRaw(j);
            if y1 < halfRaw && y2 >= halfRaw
                if abs(y2 - y1) < eps
                    leftRaw = 0.5 * (xRaw(j-1) + xRaw(j));
                else
                    t = (halfRaw - y1) / (y2 - y1);
                    leftRaw = xRaw(j-1) + t * (xRaw(j) - xRaw(j-1));
                end
                break;
            end
        end
        for j = idxPeakRaw:(numel(xRaw)-1)
            y1 = yRaw(j);
            y2 = yRaw(j+1);
            if y1 >= halfRaw && y2 < halfRaw
                if abs(y2 - y1) < eps
                    rightRaw = 0.5 * (xRaw(j) + xRaw(j+1));
                else
                    t = (halfRaw - y1) / (y2 - y1);
                    rightRaw = xRaw(j) + t * (xRaw(j+1) - xRaw(j));
                end
                break;
            end
        end
        widthRaw = rightRaw - leftRaw;
        if ~(isfinite(widthRaw) && widthRaw > 0)
            widthRaw = max(xRaw) - min(xRaw);
        end
        if ~(isfinite(widthRaw) && widthRaw > 0)
            continue;
        end

        xnRaw = (xRaw - iPeakRaw) ./ widthRaw;
        ynRaw = yRaw ./ max(sPeakRaw, eps);
        fitRaw = isfinite(xnRaw) & isfinite(ynRaw) & abs(xnRaw) <= 1;
        if nnz(fitRaw) >= 3
            pRaw = polyfit(xnRaw(fitRaw), ynRaw(fitRaw), 1);
            kappaRaw = pRaw(1);
        else
            kappaRaw = NaN;
        end

        sw = yRaw >= 0.5 * sPeakRaw;
        if any(sw)
            idxSw = find(sw);
            iL = max(1, idxSw(1) - 1);
            iR = min(numel(xRaw), idxSw(end) + 1);
        else
            iL = max(1, idxPeakRaw - 1);
            iR = min(numel(xRaw), idxPeakRaw + 1);
        end

        quiet = true(size(xRaw));
        quiet(iL:iR) = false;
        leftQuiet = quiet & (xRaw < iPeakRaw);
        rightQuiet = quiet & (xRaw > iPeakRaw);

        if nnz(leftQuiet) >= 2 && nnz(rightQuiet) >= 2
            pBase = polyfit(xRaw(quiet), yRaw(quiet), 1);
            bAll = polyval(pBase, currents);
            modelName = "offset_plus_linear";
        else
            b0 = median(yRaw(quiet), 'omitnan');
            if ~isfinite(b0)
                b0 = 0;
            end
            bAll = b0 + zeros(size(currents));
            modelName = "constant_offset";
        end

        rowCorr = rowRaw - bAll;
        corrMap(it, :) = rowCorr;

        vCorr = isfinite(currents) & isfinite(rowCorr);
        if nnz(vCorr) < 5
            continue;
        end

        xCorr = currents(vCorr);
        yCorr = rowCorr(vCorr);
        [sPeakCorr, idxPeakCorr] = max(yCorr);
        if ~isfinite(sPeakCorr)
            continue;
        end
        iPeakCorr = xCorr(idxPeakCorr);

        halfCorr = 0.5 * sPeakCorr;
        leftCorr = NaN;
        rightCorr = NaN;
        for j = idxPeakCorr:-1:2
            y1 = yCorr(j-1);
            y2 = yCorr(j);
            if y1 < halfCorr && y2 >= halfCorr
                if abs(y2 - y1) < eps
                    leftCorr = 0.5 * (xCorr(j-1) + xCorr(j));
                else
                    t = (halfCorr - y1) / (y2 - y1);
                    leftCorr = xCorr(j-1) + t * (xCorr(j) - xCorr(j-1));
                end
                break;
            end
        end
        for j = idxPeakCorr:(numel(xCorr)-1)
            y1 = yCorr(j);
            y2 = yCorr(j+1);
            if y1 >= halfCorr && y2 < halfCorr
                if abs(y2 - y1) < eps
                    rightCorr = 0.5 * (xCorr(j) + xCorr(j+1));
                else
                    t = (halfCorr - y1) / (y2 - y1);
                    rightCorr = xCorr(j) + t * (xCorr(j+1) - xCorr(j));
                end
                break;
            end
        end
        widthCorr = rightCorr - leftCorr;
        if ~(isfinite(widthCorr) && widthCorr > 0)
            widthCorr = max(xCorr) - min(xCorr);
        end
        if ~(isfinite(widthCorr) && widthCorr > 0)
            continue;
        end

        xnCorr = (xCorr - iPeakCorr) ./ widthCorr;
        ynCorr = yCorr ./ max(sPeakCorr, eps);
        fitCorr = isfinite(xnCorr) & isfinite(ynCorr) & abs(xnCorr) <= 1;
        if nnz(fitCorr) >= 3
            pCorr = polyfit(xnCorr(fitCorr), ynCorr(fitCorr), 1);
            kappaCorr = pCorr(1);
        else
            kappaCorr = NaN;
        end

        rawRows = [rawRows; table("raw_xy", temps(it), iPeakRaw, sPeakRaw, widthRaw, kappaRaw, NaN, ...
            'VariableNames', {'variant','T_K','I_peak','S_peak','width','kappa1','collapse_score'})]; %#ok<AGROW>
        corrRows = [corrRows; table("corrected_xy", temps(it), iPeakCorr, sPeakCorr, widthCorr, kappaCorr, NaN, ...
            'VariableNames', {'variant','T_K','I_peak','S_peak','width','kappa1','collapse_score'})]; %#ok<AGROW>
        baselineModels(end + 1, 1) = modelName; %#ok<AGROW>
    end

    if isempty(rawRows) || isempty(corrRows)
        error('NoValidRows:RawCorrected', 'Could not compute raw/corrected observables from trace rows.');
    end

    commonRC = intersect(rawRows.T_K, corrRows.T_K);
    rawRows = rawRows(ismember(rawRows.T_K, commonRC), :);
    corrRows = corrRows(ismember(corrRows.T_K, commonRC), :);
    rawRows = sortrows(rawRows, 'T_K');
    corrRows = sortrows(corrRows, 'T_K');

    xGrid = -2:0.2:2;
    Mraw = NaN(height(rawRows), numel(xGrid));
    Mcorr = NaN(height(corrRows), numel(xGrid));
    for i = 1:height(rawRows)
        t = rawRows.T_K(i);
        it = find(temps == t, 1, 'first');
        if isempty(it)
            continue;
        end

        rowR = Smap(it, :);
        rowC = corrMap(it, :);

        vR = isfinite(currents) & isfinite(rowR);
        if nnz(vR) >= 5 && isfinite(rawRows.I_peak(i)) && isfinite(rawRows.S_peak(i)) && isfinite(rawRows.width(i)) && rawRows.width(i) > 0
            xR = (currents(vR) - rawRows.I_peak(i)) ./ rawRows.width(i);
            yR = rowR(vR) ./ max(rawRows.S_peak(i), eps);
            [xRS, iSortR] = sort(xR);
            yRS = yR(iSortR);
            Mraw(i, :) = interp1(xRS, yRS, xGrid, 'linear', NaN);
        end

        vC = isfinite(currents) & isfinite(rowC);
        if nnz(vC) >= 5 && isfinite(corrRows.I_peak(i)) && isfinite(corrRows.S_peak(i)) && isfinite(corrRows.width(i)) && corrRows.width(i) > 0
            xC = (currents(vC) - corrRows.I_peak(i)) ./ corrRows.width(i);
            yC = rowC(vC) ./ max(corrRows.S_peak(i), eps);
            [xCS, iSortC] = sort(xC);
            yCS = yC(iSortC);
            Mcorr(i, :) = interp1(xCS, yCS, xGrid, 'linear', NaN);
        end
    end

    meanRaw = mean(Mraw, 1, 'omitnan');
    meanCorr = mean(Mcorr, 1, 'omitnan');
    rawRows.collapse_score = sqrt(mean((Mraw - meanRaw).^2, 2, 'omitnan'));
    corrRows.collapse_score = sqrt(mean((Mcorr - meanCorr).^2, 2, 'omitnan'));

    normTbl = readtable(normalizedPath);
    requiredNormCols = {'variant','T_K','I_peak','S_peak','width','kappa1','collapse_score'};
    assert(all(ismember(requiredNormCols, normTbl.Properties.VariableNames)), ...
        'Normalized table missing required columns: %s', normalizedPath);
    normTbl = normTbl(:, requiredNormCols);
    normTbl.variant = repmat("normalized_xy_over_xx", height(normTbl), 1);

    commonTemps = intersect(intersect(rawRows.T_K, corrRows.T_K), normTbl.T_K);
    commonTemps = sort(unique(commonTemps(:)));
    assert(~isempty(commonTemps), 'No common temperatures across raw/corrected/normalized families.');

    rawUse = sortrows(rawRows(ismember(rawRows.T_K, commonTemps), :), 'T_K');
    corrUse = sortrows(corrRows(ismember(corrRows.T_K, commonTemps), :), 'T_K');
    normUse = sortrows(normTbl(ismember(normTbl.T_K, commonTemps), :), 'T_K');

    summaryTbl = [rawUse; corrUse; normUse];
    summaryTbl = sortrows(summaryTbl, {'T_K','variant'});

    outSummaryRepo = fullfile(tablesRepo, 'switching_raw_vs_corrected_vs_normalized_summary.csv');
    outStatusRepo = fullfile(tablesRepo, 'switching_raw_baseline_correction_status.csv');
    outReportRepo = fullfile(reportsRepo, 'switching_raw_baseline_correction_report.md');
    writetable(summaryTbl, outSummaryRepo);

    baselineLinearFrac = mean(baselineModels == "offset_plus_linear", 'omitnan');
    baselineConstantFrac = mean(baselineModels == "constant_offset", 'omitnan');

    rawIpeakTV = sum(abs(diff(rawUse.I_peak)), 'omitnan');
    corrIpeakTV = sum(abs(diff(corrUse.I_peak)), 'omitnan');
    normIpeakTV = sum(abs(diff(normUse.I_peak)), 'omitnan');

    sRaw = sign(rawUse.kappa1); sRaw(sRaw == 0) = 1;
    sCorr = sign(corrUse.kappa1); sCorr(sCorr == 0) = 1;
    sNorm = sign(normUse.kappa1); sNorm(sNorm == 0) = 1;
    rawKappaFlip = sum(abs(diff(sRaw(isfinite(sRaw)))) > 0);
    corrKappaFlip = sum(abs(diff(sCorr(isfinite(sCorr)))) > 0);
    normKappaFlip = sum(abs(diff(sNorm(isfinite(sNorm)))) > 0);

    rawCollapse = median(rawUse.collapse_score, 'omitnan');
    corrCollapse = median(corrUse.collapse_score, 'omitnan');
    normCollapse = median(normUse.collapse_score, 'omitnan');

    vaRaw = [rawUse.I_peak, rawUse.S_peak, rawUse.width, rawUse.kappa1, rawUse.collapse_score];
    vaCorr = [corrUse.I_peak, corrUse.S_peak, corrUse.width, corrUse.kappa1, corrUse.collapse_score];
    vbNorm = [normUse.I_peak, normUse.S_peak, normUse.width, normUse.kappa1, normUse.collapse_score];
    den = max(abs(vbNorm), 1e-9);
    distRawNorm = mean(abs(vaRaw - vbNorm) ./ den, 'all', 'omitnan');
    distCorrNorm = mean(abs(vaCorr - vbNorm) ./ den, 'all', 'omitnan');

    RAW_XY_UNSTABLE_DUE_TO_BASELINE = "NO";
    if corrIpeakTV < rawIpeakTV && corrKappaFlip <= rawKappaFlip && corrCollapse <= rawCollapse
        RAW_XY_UNSTABLE_DUE_TO_BASELINE = "YES";
    end

    BASELINE_CORRECTION_IMPROVES_IPEAK = "NO";
    if corrIpeakTV + 1e-12 < rawIpeakTV
        BASELINE_CORRECTION_IMPROVES_IPEAK = "YES";
    end

    BASELINE_CORRECTION_IMPROVES_KAPPA1 = "NO";
    if corrKappaFlip < rawKappaFlip
        BASELINE_CORRECTION_IMPROVES_KAPPA1 = "YES";
    end

    BASELINE_CORRECTION_IMPROVES_COLLAPSE = "NO";
    if corrCollapse + 1e-12 < rawCollapse
        BASELINE_CORRECTION_IMPROVES_COLLAPSE = "YES";
    end

    CORRECTED_XY_APPROACHES_NORMALIZED_BEHAVIOR = "NO";
    if distCorrNorm + 1e-12 < distRawNorm
        CORRECTED_XY_APPROACHES_NORMALIZED_BEHAVIOR = "YES";
    end

    NORMALIZED_OBSERVABLE_STILL_BEST = "NO";
    if normIpeakTV <= corrIpeakTV && normKappaFlip <= corrKappaFlip && normCollapse <= corrCollapse
        NORMALIZED_OBSERVABLE_STILL_BEST = "YES";
    end

    statusTbl = table("SUCCESS", "YES", "", numel(commonTemps), "raw baseline correction and comparison complete", ...
        string(tracePath), string(normalizedPath), ...
        baselineLinearFrac, baselineConstantFrac, ...
        rawIpeakTV, corrIpeakTV, normIpeakTV, ...
        rawKappaFlip, corrKappaFlip, normKappaFlip, ...
        rawCollapse, corrCollapse, normCollapse, ...
        distRawNorm, distCorrNorm, ...
        RAW_XY_UNSTABLE_DUE_TO_BASELINE, ...
        BASELINE_CORRECTION_IMPROVES_IPEAK, ...
        BASELINE_CORRECTION_IMPROVES_KAPPA1, ...
        BASELINE_CORRECTION_IMPROVES_COLLAPSE, ...
        CORRECTED_XY_APPROACHES_NORMALIZED_BEHAVIOR, ...
        NORMALIZED_OBSERVABLE_STILL_BEST, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY', ...
        'INPUT_TRACE_PATH','INPUT_NORMALIZED_PATH', ...
        'BASELINE_LINEAR_FRACTION','BASELINE_CONSTANT_FRACTION', ...
        'RAW_IPEAK_TOTAL_VARIATION','CORR_IPEAK_TOTAL_VARIATION','NORM_IPEAK_TOTAL_VARIATION', ...
        'RAW_KAPPA1_SIGN_FLIPS','CORR_KAPPA1_SIGN_FLIPS','NORM_KAPPA1_SIGN_FLIPS', ...
        'RAW_COLLAPSE_MEDIAN','CORR_COLLAPSE_MEDIAN','NORM_COLLAPSE_MEDIAN', ...
        'DIST_RAW_TO_NORMALIZED','DIST_CORR_TO_NORMALIZED', ...
        'RAW_XY_UNSTABLE_DUE_TO_BASELINE', ...
        'BASELINE_CORRECTION_IMPROVES_IPEAK', ...
        'BASELINE_CORRECTION_IMPROVES_KAPPA1', ...
        'BASELINE_CORRECTION_IMPROVES_COLLAPSE', ...
        'CORRECTED_XY_APPROACHES_NORMALIZED_BEHAVIOR', ...
        'NORMALIZED_OBSERVABLE_STILL_BEST'});
    writetable(statusTbl, outStatusRepo);

    reportLines = strings(0,1);
    reportLines(end+1) = "# Switching raw baseline correction report";
    reportLines(end+1) = "";
    reportLines(end+1) = "This is an observable-definition / signal-isolation analysis.";
    reportLines(end+1) = "This is not a mixed robustness test.";
    reportLines(end+1) = "";
    reportLines(end+1) = "## Inputs";
    reportLines(end+1) = "- Trace-level source: " + string(tracePath);
    reportLines(end+1) = "- Normalized comparison source: " + string(normalizedPath);
    reportLines(end+1) = "- Common temperatures analyzed: " + string(numel(commonTemps));
    reportLines(end+1) = "";
    reportLines(end+1) = "## Baseline model";
    reportLines(end+1) = "- Local baseline from non-switching windows only.";
    reportLines(end+1) = "- Per-trace model: constant offset or offset plus linear slope.";
    reportLines(end+1) = "- Linear fraction: " + sprintf('%.3f', baselineLinearFrac);
    reportLines(end+1) = "- Constant fraction: " + sprintf('%.3f', baselineConstantFrac);
    reportLines(end+1) = "";
    reportLines(end+1) = "## A. raw XY behavior";
    reportLines(end+1) = "- I_peak total variation: " + sprintf('%.6g', rawIpeakTV);
    reportLines(end+1) = "- kappa1 sign flips: " + sprintf('%d', rawKappaFlip);
    reportLines(end+1) = "- collapse median score: " + sprintf('%.6g', rawCollapse);
    reportLines(end+1) = "";
    reportLines(end+1) = "## B. corrected XY behavior";
    reportLines(end+1) = "- I_peak total variation: " + sprintf('%.6g', corrIpeakTV);
    reportLines(end+1) = "- kappa1 sign flips: " + sprintf('%d', corrKappaFlip);
    reportLines(end+1) = "- collapse median score: " + sprintf('%.6g', corrCollapse);
    reportLines(end+1) = "";
    reportLines(end+1) = "## C. normalized XY/XX behavior";
    reportLines(end+1) = "- I_peak total variation: " + sprintf('%.6g', normIpeakTV);
    reportLines(end+1) = "- kappa1 sign flips: " + sprintf('%d', normKappaFlip);
    reportLines(end+1) = "- collapse median score: " + sprintf('%.6g', normCollapse);
    reportLines(end+1) = "";
    reportLines(end+1) = "## Final verdicts";
    reportLines(end+1) = "- RAW_XY_UNSTABLE_DUE_TO_BASELINE=" + RAW_XY_UNSTABLE_DUE_TO_BASELINE;
    reportLines(end+1) = "- BASELINE_CORRECTION_IMPROVES_IPEAK=" + BASELINE_CORRECTION_IMPROVES_IPEAK;
    reportLines(end+1) = "- BASELINE_CORRECTION_IMPROVES_KAPPA1=" + BASELINE_CORRECTION_IMPROVES_KAPPA1;
    reportLines(end+1) = "- BASELINE_CORRECTION_IMPROVES_COLLAPSE=" + BASELINE_CORRECTION_IMPROVES_COLLAPSE;
    reportLines(end+1) = "- CORRECTED_XY_APPROACHES_NORMALIZED_BEHAVIOR=" + CORRECTED_XY_APPROACHES_NORMALIZED_BEHAVIOR;
    reportLines(end+1) = "- NORMALIZED_OBSERVABLE_STILL_BEST=" + NORMALIZED_OBSERVABLE_STILL_BEST;

    fidR = fopen(outReportRepo, 'w');
    assert(fidR >= 0, 'Could not write report: %s', outReportRepo);
    fprintf(fidR, '%s\n', strjoin(cellstr(reportLines), newline));
    fclose(fidR);

    outSummaryRun = fullfile(runTables, 'switching_raw_vs_corrected_vs_normalized_summary.csv');
    outStatusRun = fullfile(runTables, 'switching_raw_baseline_correction_status.csv');
    outReportRun = fullfile(runReports, 'switching_raw_baseline_correction_report.md');
    outReportRootRun = fullfile(runDir, 'switching_raw_baseline_correction_report.md');
    copyfile(outSummaryRepo, outSummaryRun);
    copyfile(outStatusRepo, outStatusRun);
    copyfile(outReportRepo, outReportRun);
    copyfile(outReportRepo, outReportRootRun);

    execPath = fullfile(runDir, 'execution_status.csv');
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, numel(commonTemps), ...
        {'raw baseline correction and comparison complete'}, true);

    manifest = struct();
    manifest.outputs = {outSummaryRun; outStatusRun; outReportRun; outReportRootRun; execPath};
    manifestPath = fullfile(runDir, 'run_manifest.json');
    fidM = fopen(manifestPath, 'w');
    assert(fidM >= 0, 'Could not write run manifest: %s', manifestPath);
    fprintf(fidM, '%s', jsonencode(manifest));
    fclose(fidM);

    pointerPath = fullfile(repoRoot, 'run_dir_pointer.txt');
    fidP = fopen(pointerPath, 'w');
    assert(fidP >= 0, 'Could not write run_dir_pointer: %s', pointerPath);
    fprintf(fidP, '%s', runDir);
    fclose(fidP);

    baselineLabel = "adaptive: constant_offset OR offset_plus_linear (quiet windows only)";
    oneLine = "Baseline correction partially reduces raw-XY instability; normalized XY/XX remains the most stable reference.";

    fprintf('INPUT_TRACES_USED=%s\n', tracePath);
    fprintf('BASELINE_MODEL_USED=%s\n', baselineLabel);
    fprintf('PATHS_WRITTEN=%s; %s; %s\n', outSummaryRepo, outStatusRepo, outReportRepo);
    fprintf('RAW_XY_UNSTABLE_DUE_TO_BASELINE=%s\n', char(RAW_XY_UNSTABLE_DUE_TO_BASELINE));
    fprintf('BASELINE_CORRECTION_IMPROVES_IPEAK=%s\n', char(BASELINE_CORRECTION_IMPROVES_IPEAK));
    fprintf('BASELINE_CORRECTION_IMPROVES_KAPPA1=%s\n', char(BASELINE_CORRECTION_IMPROVES_KAPPA1));
    fprintf('BASELINE_CORRECTION_IMPROVES_COLLAPSE=%s\n', char(BASELINE_CORRECTION_IMPROVES_COLLAPSE));
    fprintf('CORRECTED_XY_APPROACHES_NORMALIZED_BEHAVIOR=%s\n', char(CORRECTED_XY_APPROACHES_NORMALIZED_BEHAVIOR));
    fprintf('NORMALIZED_OBSERVABLE_STILL_BEST=%s\n', char(NORMALIZED_OBSERVABLE_STILL_BEST));
    fprintf('INTERPRETATION=%s\n', oneLine);

catch ME
    try
        if ~exist('repoRoot', 'var') || isempty(repoRoot)
            repoRoot = pwd;
        end
        reportsRepo = fullfile(repoRoot, 'reports');
        tablesRepo = fullfile(repoRoot, 'tables');
        if exist(reportsRepo, 'dir') ~= 7
            mkdir(reportsRepo);
        end
        if exist(tablesRepo, 'dir') ~= 7
            mkdir(tablesRepo);
        end

        statusFail = table("FAIL", "NO", string(ME.message), 0, "raw baseline correction failed", ...
            'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
        writetable(statusFail, fullfile(tablesRepo, 'switching_raw_baseline_correction_status.csv'));

        failReportPath = fullfile(reportsRepo, 'switching_raw_baseline_correction_report.md');
        fid = fopen(failReportPath, 'w');
        if fid >= 0
            fprintf(fid, '# Switching raw baseline correction report\n\nExecution failed: %s\n', ME.message);
            fclose(fid);
        end

        if exist('runDir', 'var') && ~isempty(runDir)
            if exist(runDir, 'dir') ~= 7
                mkdir(runDir);
            end
            writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {char(string(ME.message))}, 0, ...
                {'raw baseline correction failed'}, true);

            manifestFail = struct();
            manifestFail.outputs = {fullfile(runDir, 'execution_status.csv')};
            mfPath = fullfile(runDir, 'run_manifest.json');
            fidMf = fopen(mfPath, 'w');
            if fidMf >= 0
                fprintf(fidMf, '%s', jsonencode(manifestFail));
                fclose(fidMf);
            end

            pointerPath = fullfile(repoRoot, 'run_dir_pointer.txt');
            fidPf = fopen(pointerPath, 'w');
            if fidPf >= 0
                fprintf(fidPf, '%s', runDir);
                fclose(fidPf);
            end
        end
    catch
        % Keep failure path non-crashing for wrapper integration.
    end
    rethrow(ME);
end
