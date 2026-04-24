fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    scriptDir = fileparts(mfilename('fullpath'));
    repoRoot = scriptDir;
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Aging'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_extrema_localmean_validation';

resultsOutPath = fullfile(repoRoot, 'tables', 'aging', 'aging_extrema_localmean_results.csv');
stabilityOutPath = fullfile(repoRoot, 'tables', 'aging', 'aging_extrema_localmean_stability.csv');
reportOutPath = fullfile(repoRoot, 'reports', 'aging', 'aging_extrema_localmean_validation.md');

resultsTbl = table();
stabilityTbl = table();

try
    run = createRunContext('aging', cfg);

    if exist(fileparts(resultsOutPath), 'dir') ~= 7
        mkdir(fileparts(resultsOutPath));
    end
    if exist(fileparts(reportOutPath), 'dir') ~= 7
        mkdir(fileparts(reportOutPath));
    end

    dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';
    if exist(dataDir, 'dir') ~= 7
        error('AgingLocalMean:MissingDataDir', 'Dataset folder not found: %s', dataDir);
    end

    [~, pauseRuns] = getFileList_aging(dataDir);
    nTrace = numel(pauseRuns);
    if nTrace == 0
        error('AgingLocalMean:NoPauseRuns', 'No pause traces found in dataset.');
    end

    smoothWindows = [5 7 9 11];
    kList = [1 2 3 4];
    percentileHi = 98;
    percentileLo = 2;
    nPerturb = 20;
    rng(119);

    rowRes = 0;
    res_trace_name = strings(0,1);
    res_trace_file = strings(0,1);
    res_waitK = zeros(0,1);
    res_method = strings(0,1);
    res_smooth_window = zeros(0,1);
    res_k = zeros(0,1);
    res_variant = strings(0,1);
    res_perturb_id = zeros(0,1);
    res_FM = zeros(0,1);
    res_AFM = zeros(0,1);
    res_FM_rel_vs_B9 = zeros(0,1);
    res_AFM_rel_vs_B9 = zeros(0,1);

    for i = 1:nTrace
        pr = pauseRuns(i);
        [T, M] = importFiles_aging(pr.file, true, false); %#ok<NASGU>
        if isempty(M)
            continue;
        end

        [~, baseName, ext] = fileparts(pr.file);
        traceLabel = string(strcat(baseName, ext));
        nPts = numel(M);

        Msm9 = movmean(M, 9);
        FM_B9 = max(Msm9);
        AFM_B9 = min(Msm9);
        if abs(FM_B9) < eps
            FM_B9 = sign(FM_B9) * eps + (FM_B9 == 0) * eps;
        end
        if abs(AFM_B9) < eps
            AFM_B9 = sign(AFM_B9) * eps + (AFM_B9 == 0) * eps;
        end

        for w = smoothWindows
            Msm = movmean(M, w);
            [~, idxMax] = max(Msm);
            [~, idxMin] = min(Msm);

            fmA = max(M);
            afmA = min(M);

            fmB = max(Msm);
            afmB = min(Msm);

            fmD = prctile(M, percentileHi);
            afmD = prctile(M, percentileLo);

            rowRes = rowRes + 1;
            res_trace_name(rowRes,1) = traceLabel;
            res_trace_file(rowRes,1) = string(pr.file);
            res_waitK(rowRes,1) = pr.waitK;
            res_method(rowRes,1) = "A_raw_extrema";
            res_smooth_window(rowRes,1) = w;
            res_k(rowRes,1) = 0;
            res_variant(rowRes,1) = "base";
            res_perturb_id(rowRes,1) = 0;
            res_FM(rowRes,1) = fmA;
            res_AFM(rowRes,1) = afmA;
            res_FM_rel_vs_B9(rowRes,1) = (fmA - FM_B9) / abs(FM_B9);
            res_AFM_rel_vs_B9(rowRes,1) = (afmA - AFM_B9) / abs(AFM_B9);

            rowRes = rowRes + 1;
            res_trace_name(rowRes,1) = traceLabel;
            res_trace_file(rowRes,1) = string(pr.file);
            res_waitK(rowRes,1) = pr.waitK;
            res_method(rowRes,1) = "B_smoothed_extrema";
            res_smooth_window(rowRes,1) = w;
            res_k(rowRes,1) = 0;
            res_variant(rowRes,1) = "base";
            res_perturb_id(rowRes,1) = 0;
            res_FM(rowRes,1) = fmB;
            res_AFM(rowRes,1) = afmB;
            res_FM_rel_vs_B9(rowRes,1) = (fmB - FM_B9) / abs(FM_B9);
            res_AFM_rel_vs_B9(rowRes,1) = (afmB - AFM_B9) / abs(AFM_B9);

            rowRes = rowRes + 1;
            res_trace_name(rowRes,1) = traceLabel;
            res_trace_file(rowRes,1) = string(pr.file);
            res_waitK(rowRes,1) = pr.waitK;
            res_method(rowRes,1) = "D_percentile_reference";
            res_smooth_window(rowRes,1) = w;
            res_k(rowRes,1) = 0;
            res_variant(rowRes,1) = "base";
            res_perturb_id(rowRes,1) = 0;
            res_FM(rowRes,1) = fmD;
            res_AFM(rowRes,1) = afmD;
            res_FM_rel_vs_B9(rowRes,1) = (fmD - FM_B9) / abs(FM_B9);
            res_AFM_rel_vs_B9(rowRes,1) = (afmD - AFM_B9) / abs(AFM_B9);

            for k = kList
                iLmax = max(1, idxMax - k);
                iRmax = min(nPts, idxMax + k);
                iLmin = max(1, idxMin - k);
                iRmin = min(nPts, idxMin + k);

                fmC = mean(M(iLmax:iRmax));
                afmC = mean(M(iLmin:iRmin));

                rowRes = rowRes + 1;
                res_trace_name(rowRes,1) = traceLabel;
                res_trace_file(rowRes,1) = string(pr.file);
                res_waitK(rowRes,1) = pr.waitK;
                res_method(rowRes,1) = "C_localmean_extrema";
                res_smooth_window(rowRes,1) = w;
                res_k(rowRes,1) = k;
                res_variant(rowRes,1) = "base";
                res_perturb_id(rowRes,1) = 0;
                res_FM(rowRes,1) = fmC;
                res_AFM(rowRes,1) = afmC;
                res_FM_rel_vs_B9(rowRes,1) = (fmC - FM_B9) / abs(FM_B9);
                res_AFM_rel_vs_B9(rowRes,1) = (afmC - AFM_B9) / abs(AFM_B9);
            end
        end

        noiseSigma = std(M - movmean(M, 9), 0);
        if ~isfinite(noiseSigma) || noiseSigma <= 0
            noiseSigma = 0.01 * std(M, 0);
        end
        perturbSigma = 0.20 * noiseSigma;

        for p = 1:nPerturb
            Mp = M + perturbSigma * randn(size(M));

            for w = smoothWindows
                MsmP = movmean(Mp, w);
                [~, idxMaxP] = max(MsmP);
                [~, idxMinP] = min(MsmP);

                fmAP = max(Mp);
                afmAP = min(Mp);
                fmBP = max(MsmP);
                afmBP = min(MsmP);
                fmDP = prctile(Mp, percentileHi);
                afmDP = prctile(Mp, percentileLo);

                rowRes = rowRes + 1;
                res_trace_name(rowRes,1) = traceLabel;
                res_trace_file(rowRes,1) = string(pr.file);
                res_waitK(rowRes,1) = pr.waitK;
                res_method(rowRes,1) = "A_raw_extrema";
                res_smooth_window(rowRes,1) = w;
                res_k(rowRes,1) = 0;
                res_variant(rowRes,1) = "perturbed_noise";
                res_perturb_id(rowRes,1) = p;
                res_FM(rowRes,1) = fmAP;
                res_AFM(rowRes,1) = afmAP;
                res_FM_rel_vs_B9(rowRes,1) = NaN;
                res_AFM_rel_vs_B9(rowRes,1) = NaN;

                rowRes = rowRes + 1;
                res_trace_name(rowRes,1) = traceLabel;
                res_trace_file(rowRes,1) = string(pr.file);
                res_waitK(rowRes,1) = pr.waitK;
                res_method(rowRes,1) = "B_smoothed_extrema";
                res_smooth_window(rowRes,1) = w;
                res_k(rowRes,1) = 0;
                res_variant(rowRes,1) = "perturbed_noise";
                res_perturb_id(rowRes,1) = p;
                res_FM(rowRes,1) = fmBP;
                res_AFM(rowRes,1) = afmBP;
                res_FM_rel_vs_B9(rowRes,1) = NaN;
                res_AFM_rel_vs_B9(rowRes,1) = NaN;

                rowRes = rowRes + 1;
                res_trace_name(rowRes,1) = traceLabel;
                res_trace_file(rowRes,1) = string(pr.file);
                res_waitK(rowRes,1) = pr.waitK;
                res_method(rowRes,1) = "D_percentile_reference";
                res_smooth_window(rowRes,1) = w;
                res_k(rowRes,1) = 0;
                res_variant(rowRes,1) = "perturbed_noise";
                res_perturb_id(rowRes,1) = p;
                res_FM(rowRes,1) = fmDP;
                res_AFM(rowRes,1) = afmDP;
                res_FM_rel_vs_B9(rowRes,1) = NaN;
                res_AFM_rel_vs_B9(rowRes,1) = NaN;

                for k = kList
                    iLmaxP = max(1, idxMaxP - k);
                    iRmaxP = min(nPts, idxMaxP + k);
                    iLminP = max(1, idxMinP - k);
                    iRminP = min(nPts, idxMinP + k);

                    fmCP = mean(Mp(iLmaxP:iRmaxP));
                    afmCP = mean(Mp(iLminP:iRminP));

                    rowRes = rowRes + 1;
                    res_trace_name(rowRes,1) = traceLabel;
                    res_trace_file(rowRes,1) = string(pr.file);
                    res_waitK(rowRes,1) = pr.waitK;
                    res_method(rowRes,1) = "C_localmean_extrema";
                    res_smooth_window(rowRes,1) = w;
                    res_k(rowRes,1) = k;
                    res_variant(rowRes,1) = "perturbed_noise";
                    res_perturb_id(rowRes,1) = p;
                    res_FM(rowRes,1) = fmCP;
                    res_AFM(rowRes,1) = afmCP;
                    res_FM_rel_vs_B9(rowRes,1) = NaN;
                    res_AFM_rel_vs_B9(rowRes,1) = NaN;
                end
            end
        end
    end

    resultsTbl = table(res_trace_name, res_trace_file, res_waitK, res_method, res_smooth_window, ...
        res_k, res_variant, res_perturb_id, res_FM, res_AFM, res_FM_rel_vs_B9, res_AFM_rel_vs_B9, ...
        'VariableNames', {'trace_name','trace_file','waitK','method','smooth_window','k','variant','perturb_id','FM','AFM','FM_rel_vs_B9','AFM_rel_vs_B9'});

    baseMask = resultsTbl.variant == "base" & resultsTbl.perturb_id == 0;
    pertMask = resultsTbl.variant == "perturbed_noise" & resultsTbl.perturb_id > 0;
    baseTbl = resultsTbl(baseMask, :);
    pertTbl = resultsTbl(pertMask, :);

    keyMethod = strings(0,1);
    keyWindow = zeros(0,1);
    keyK = zeros(0,1);
    nTemps = zeros(0,1);
    FM_var_acrossT = zeros(0,1);
    AFM_var_acrossT = zeros(0,1);
    smooth_sensitivity_FM = zeros(0,1);
    smooth_sensitivity_AFM = zeros(0,1);
    k_sensitivity_FM = zeros(0,1);
    k_sensitivity_AFM = zeros(0,1);
    perturb_sensitivity_FM = zeros(0,1);
    perturb_sensitivity_AFM = zeros(0,1);
    mean_abs_rel_change_vs_B9_FM = zeros(0,1);
    mean_abs_rel_change_vs_B9_AFM = zeros(0,1);
    stability_score = zeros(0,1);
    rowStab = 0;

    methods = unique(baseTbl.method, 'stable');
    for mi = 1:numel(methods)
        mName = methods(mi);
        if mName == "C_localmean_extrema"
            winList = smoothWindows;
            kvals = kList;
        else
            winList = smoothWindows;
            kvals = 0;
        end

        for w = winList
            for k = kvals
                sel = baseTbl.method == mName & baseTbl.smooth_window == w & baseTbl.k == k;
                if ~any(sel)
                    continue;
                end

                fmVals = baseTbl.FM(sel);
                afmVals = baseTbl.AFM(sel);

                rowStab = rowStab + 1;
                keyMethod(rowStab,1) = mName;
                keyWindow(rowStab,1) = w;
                keyK(rowStab,1) = k;
                nTemps(rowStab,1) = numel(fmVals);
                FM_var_acrossT(rowStab,1) = var(fmVals, 0);
                AFM_var_acrossT(rowStab,1) = var(afmVals, 0);

                traceIDs = unique(baseTbl.trace_name(baseTbl.method == mName & baseTbl.k == k), 'stable');
                perTraceFMstd = zeros(numel(traceIDs),1);
                perTraceAFMstd = zeros(numel(traceIDs),1);
                for ti = 1:numel(traceIDs)
                    tSel = baseTbl.trace_name == traceIDs(ti) & baseTbl.method == mName & baseTbl.k == k;
                    perTraceFMstd(ti) = std(baseTbl.FM(tSel), 0);
                    perTraceAFMstd(ti) = std(baseTbl.AFM(tSel), 0);
                end
                smooth_sensitivity_FM(rowStab,1) = mean(perTraceFMstd);
                smooth_sensitivity_AFM(rowStab,1) = mean(perTraceAFMstd);

                if mName == "C_localmean_extrema"
                    perTraceFMk = zeros(numel(traceIDs),1);
                    perTraceAFMk = zeros(numel(traceIDs),1);
                    for ti = 1:numel(traceIDs)
                        tkSel = baseTbl.trace_name == traceIDs(ti) & baseTbl.method == mName & baseTbl.smooth_window == w;
                        perTraceFMk(ti) = std(baseTbl.FM(tkSel), 0);
                        perTraceAFMk(ti) = std(baseTbl.AFM(tkSel), 0);
                    end
                    k_sensitivity_FM(rowStab,1) = mean(perTraceFMk);
                    k_sensitivity_AFM(rowStab,1) = mean(perTraceAFMk);
                else
                    k_sensitivity_FM(rowStab,1) = 0;
                    k_sensitivity_AFM(rowStab,1) = 0;
                end

                pSel = pertTbl.method == mName & pertTbl.smooth_window == w & pertTbl.k == k;
                if any(pSel)
                    bJoinSel = baseTbl.method == mName & baseTbl.smooth_window == w & baseTbl.k == k;
                    bRows = baseTbl(bJoinSel, {'trace_name','FM','AFM'});
                    pRows = pertTbl(pSel, {'trace_name','FM','AFM'});
                    fmDelta = zeros(height(pRows),1);
                    afmDelta = zeros(height(pRows),1);
                    for pj = 1:height(pRows)
                        bIdx = find(bRows.trace_name == pRows.trace_name(pj), 1, 'first');
                        if isempty(bIdx)
                            fmDelta(pj) = NaN;
                            afmDelta(pj) = NaN;
                        else
                            fmDelta(pj) = pRows.FM(pj) - bRows.FM(bIdx);
                            afmDelta(pj) = pRows.AFM(pj) - bRows.AFM(bIdx);
                        end
                    end
                    perturb_sensitivity_FM(rowStab,1) = std(fmDelta, 0, 'omitnan');
                    perturb_sensitivity_AFM(rowStab,1) = std(afmDelta, 0, 'omitnan');
                else
                    perturb_sensitivity_FM(rowStab,1) = NaN;
                    perturb_sensitivity_AFM(rowStab,1) = NaN;
                end

                mean_abs_rel_change_vs_B9_FM(rowStab,1) = mean(abs(baseTbl.FM_rel_vs_B9(sel)), 'omitnan');
                mean_abs_rel_change_vs_B9_AFM(rowStab,1) = mean(abs(baseTbl.AFM_rel_vs_B9(sel)), 'omitnan');

                stability_score(rowStab,1) = ...
                    FM_var_acrossT(rowStab,1) + AFM_var_acrossT(rowStab,1) + ...
                    smooth_sensitivity_FM(rowStab,1) + smooth_sensitivity_AFM(rowStab,1) + ...
                    k_sensitivity_FM(rowStab,1) + k_sensitivity_AFM(rowStab,1) + ...
                    perturb_sensitivity_FM(rowStab,1) + perturb_sensitivity_AFM(rowStab,1);
            end
        end
    end

    stabilityTbl = table(keyMethod, keyWindow, keyK, nTemps, FM_var_acrossT, AFM_var_acrossT, ...
        smooth_sensitivity_FM, smooth_sensitivity_AFM, k_sensitivity_FM, k_sensitivity_AFM, ...
        perturb_sensitivity_FM, perturb_sensitivity_AFM, mean_abs_rel_change_vs_B9_FM, ...
        mean_abs_rel_change_vs_B9_AFM, stability_score, ...
        'VariableNames', {'method','smooth_window','k','n_temps','FM_var_acrossT','AFM_var_acrossT', ...
        'smooth_sensitivity_FM','smooth_sensitivity_AFM','k_sensitivity_FM','k_sensitivity_AFM', ...
        'perturb_sensitivity_FM','perturb_sensitivity_AFM','mean_abs_rel_change_vs_B9_FM', ...
        'mean_abs_rel_change_vs_B9_AFM','stability_score'});

    cRows = stabilityTbl(stabilityTbl.method == "C_localmean_extrema", :);
    [~, cBestIdx] = min(cRows.stability_score);
    cBest = cRows(cBestIdx, :);

    bRows = stabilityTbl(stabilityTbl.method == "B_smoothed_extrema", :);
    [~, bBestIdx] = min(bRows.stability_score);
    bBest = bRows(bBestIdx, :);

    localMeanBetter = cBest.stability_score < bBest.stability_score;

    writetable(resultsTbl, resultsOutPath);
    writetable(stabilityTbl, stabilityOutPath);

    fidReport = fopen(reportOutPath, 'w');
    if fidReport < 0
        error('AgingLocalMean:ReportWriteFail', 'Failed to write report: %s', reportOutPath);
    end
    fprintf(fidReport, '# Aging extrema local-mean validation\n\n');
    fprintf(fidReport, '## 1. Method behavior\n\n');
    fprintf(fidReport, '- Implemented method C: smooth for extrema localization then local raw averaging.\n');
    fprintf(fidReport, '- Definition: M_s = movmean(M, w), idx_max/min from M_s, FM/AFM from mean(raw around idx, radius k).\n');
    fprintf(fidReport, '- Tested all traces in dataset with w in [5,7,9,11] and k in [1,2,3,4].\n');
    fprintf(fidReport, '- Local averaging reduces point-level fluctuation by construction; stability quantified in output tables.\n\n');

    fprintf(fidReport, '## 2. Comparison to other methods\n\n');
    fprintf(fidReport, '- Method A: raw extrema (reference, most spike-sensitive).\n');
    fprintf(fidReport, '- Method B: smoothed extrema only.\n');
    fprintf(fidReport, '- Method C: local-mean extrema (candidate).\n');
    fprintf(fidReport, '- Method D: percentile reference (not extrema-like primary).\n\n');

    fprintf(fidReport, '## 3. Parameter robustness\n\n');
    fprintf(fidReport, '- Best Method C by stability score: w=%d, k=%d, score=%.6g\n', cBest.smooth_window, cBest.k, cBest.stability_score);
    fprintf(fidReport, '- Best Method B by stability score: w=%d, score=%.6g\n', bBest.smooth_window, bBest.stability_score);
    fprintf(fidReport, '- k sensitivity is explicitly reported via k_sensitivity_FM/AFM metrics.\n');
    fprintf(fidReport, '- Window sensitivity is explicitly reported via smooth_sensitivity_FM/AFM metrics.\n\n');

    fprintf(fidReport, '## 4. FINAL VERDICT (CLEAR)\n\n');
    if localMeanBetter
        fprintf(fidReport, '- Yes: local-mean extrema is more stable than smoothed-extrema-only under this validation set.\n');
    else
        fprintf(fidReport, '- No significant gain over smoothed-extrema-only under this validation set.\n');
    end
    fprintf(fidReport, '- Recommended parameters: smoothing window w=%d, local averaging k=%d.\n', cBest.smooth_window, cBest.k);
    fprintf(fidReport, '- Final algorithm:\n');
    fprintf(fidReport, '  1) Load raw trace M(T)\n');
    fprintf(fidReport, '  2) M_s = movmean(M, w)\n');
    fprintf(fidReport, '  3) idx_max = argmax(M_s), idx_min = argmin(M_s)\n');
    fprintf(fidReport, '  4) FM = mean(M(idx_max-k:idx_max+k)), AFM = mean(M(idx_min-k:idx_min+k))\n');
    fclose(fidReport);

    summaryText = sprintf('best_C_w%d_k%d_vs_B_w%d_localMeanBetter_%d', cBest.smooth_window, cBest.k, bBest.smooth_window, localMeanBetter);
    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nTrace, {summaryText}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    if exist(fileparts(resultsOutPath), 'dir') ~= 7
        mkdir(fileparts(resultsOutPath));
    end
    if exist(fileparts(reportOutPath), 'dir') ~= 7
        mkdir(fileparts(reportOutPath));
    end

    if isempty(resultsTbl)
        resultsTbl = table('Size', [0 12], ...
            'VariableTypes', {'string','string','double','string','double','double','string','double','double','double','double','double'}, ...
            'VariableNames', {'trace_name','trace_file','waitK','method','smooth_window','k','variant','perturb_id','FM','AFM','FM_rel_vs_B9','AFM_rel_vs_B9'});
    end
    if isempty(stabilityTbl)
        stabilityTbl = table('Size', [0 15], ...
            'VariableTypes', {'string','double','double','double','double','double','double','double','double','double','double','double','double','double','double'}, ...
            'VariableNames', {'method','smooth_window','k','n_temps','FM_var_acrossT','AFM_var_acrossT', ...
            'smooth_sensitivity_FM','smooth_sensitivity_AFM','k_sensitivity_FM','k_sensitivity_AFM', ...
            'perturb_sensitivity_FM','perturb_sensitivity_AFM','mean_abs_rel_change_vs_B9_FM', ...
            'mean_abs_rel_change_vs_B9_AFM','stability_score'});
    end

    writetable(resultsTbl, resultsOutPath);
    writetable(stabilityTbl, stabilityOutPath);

    fidReport = fopen(reportOutPath, 'w');
    if fidReport >= 0
        fprintf(fidReport, '# Aging extrema local-mean validation\n\n');
        fprintf(fidReport, 'Execution failed.\n\n');
        fprintf(fidReport, '- Error: %s\n', ME.message);
        fclose(fidReport);
    end

    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_extrema_localmean_validation_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end

    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'aging extrema localmean validation failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
