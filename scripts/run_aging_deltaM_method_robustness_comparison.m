clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';

runCfg = struct();
runCfg.runLabel = 'aging_deltaM_method_robustness_comparison';

try
    run = createRunContext('aging', runCfg);

    cfg = struct();
    cfg.dataDir = dataDir;
    cfg.normalizeByMass = true;
    cfg.debugMode = false;
    cfg.Bohar_units = true;
    cfg.dip_window_K = 5;
    cfg.subtractOrder = 'noMinusPause';
    cfg.alignDeltaM = false;
    cfg.alignRef = 'lowT';
    cfg.alignWindow_K = 2;
    cfg.doFilterDeltaM = true;
    cfg.filterMethod = 'sgolay';
    cfg.sgolayOrder = 2;
    cfg.sgolayFrame = 15;

    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);

    Tp = [state.pauseRuns.waitK]';
    nRuns = numel(Tp);
    nNoise = 50;
    rng(1);

    % High-T noise sigma per run from DeltaM.
    sigmaHT = nan(nRuns, 1);
    for i = 1:nRuns
        dM = state.pauseRuns(i).DeltaM(:);
        T = state.pauseRuns(i).T_common(:);
        valid = isfinite(dM) & isfinite(T);
        dM = dM(valid);
        T = T(valid);
        if isempty(dM)
            sigmaHT(i) = 0;
            continue;
        end
        tCut = prctile(T, 80);
        idxHT = T >= tCut;
        if nnz(idxHT) < 5
            idxHT = true(size(T));
        end
        dMht = dM(idxHT);
        dMhtSm = movmean(dMht, 11);
        s = std(dMht - dMhtSm, 'omitnan');
        if ~isfinite(s)
            s = 0;
        end
        sigmaHT(i) = s;
    end

    methodNames = [ ...
        "extrema_smoothed_baseline"; ...
        "percentile_5_95"; ...
        "percentile_10_90"; ...
        "topk_mean_k3"; ...
        "topk_mean_k5"; ...
        "topk_mean_k7"; ...
        "extrema_stronger_smoothing"; ...
        "existing_components_height" ...
    ];
    nMethods = numel(methodNames);

    AFM_max_var = nan(nMethods,1);
    FM_max_var = nan(nMethods,1);
    AFM_noise_pct = nan(nMethods,1);
    FM_noise_pct = nan(nMethods,1);
    ordering_stable = false(nMethods,1);
    peak_stable = false(nMethods,1);
    robust = false(nMethods,1);
    notes = strings(nMethods,1);

    for m = 1:nMethods
        methodName = methodNames(m);

        if methodName == "extrema_stronger_smoothing"
            winList = [11 15 19 23 27 31];
            baseWin = 21;
        else
            winList = [5 9 13 17 21 31];
            baseWin = 13;
        end
        nW = numel(winList);

        AFM_w = nan(nRuns, nW);
        FM_w = nan(nRuns, nW);

        % Window sweep
        for i = 1:nRuns
            dM = state.pauseRuns(i).DeltaM(:);
            T = state.pauseRuns(i).T_common(:);
            valid = isfinite(dM) & isfinite(T);
            dM = dM(valid);
            T = T(valid);
            if isempty(dM)
                continue;
            end

            for w = 1:nW
                win = winList(w);
                ds = movmean(dM, win);

                if methodName == "extrema_smoothed_baseline" || methodName == "extrema_stronger_smoothing"
                    AFM_w(i, w) = abs(min(ds));
                    FM_w(i, w) = abs(max(ds));
                elseif methodName == "percentile_5_95"
                    AFM_w(i, w) = abs(prctile(ds, 5));
                    FM_w(i, w) = abs(prctile(ds, 95));
                elseif methodName == "percentile_10_90"
                    AFM_w(i, w) = abs(prctile(ds, 10));
                    FM_w(i, w) = abs(prctile(ds, 90));
                elseif methodName == "topk_mean_k3" || methodName == "topk_mean_k5" || methodName == "topk_mean_k7"
                    if methodName == "topk_mean_k3"
                        k = 3;
                    elseif methodName == "topk_mean_k5"
                        k = 5;
                    else
                        k = 7;
                    end
                    dsSort = sort(ds, 'ascend');
                    kEff = min(k, numel(dsSort));
                    lowVals = dsSort(1:kEff);
                    highVals = dsSort(end-kEff+1:end);
                    AFM_w(i, w) = abs(mean(lowVals, 'omitnan'));
                    FM_w(i, w) = abs(mean(highVals, 'omitnan'));
                elseif methodName == "existing_components_height"
                    tmpRun = struct('T_common', T, 'DeltaM', dM, 'waitK', Tp(i));
                    smoothWindow_K = win;
                    out = analyzeAFM_FM_components(tmpRun, 5, smoothWindow_K, false, -inf, 6, 'pre', 6, 'height', struct());
                    AFM_w(i, w) = abs(out(1).AFM_amp);
                    FM_w(i, w) = abs(out(1).FM_step_mag);
                end
            end
        end

        AFM_var_pct_perT = 100 * (max(AFM_w, [], 2) - min(AFM_w, [], 2)) ./ max(mean(AFM_w, 2, 'omitnan'), eps);
        FM_var_pct_perT = 100 * (max(FM_w, [], 2) - min(FM_w, [], 2)) ./ max(mean(FM_w, 2, 'omitnan'), eps);
        AFM_max_var(m) = max(AFM_var_pct_perT, [], 'omitnan');
        FM_max_var(m) = max(FM_var_pct_perT, [], 'omitnan');

        % Baseline values at base window.
        AFM_base = nan(nRuns,1);
        FM_base = nan(nRuns,1);
        for i = 1:nRuns
            dM = state.pauseRuns(i).DeltaM(:);
            T = state.pauseRuns(i).T_common(:);
            valid = isfinite(dM) & isfinite(T);
            dM = dM(valid);
            T = T(valid);
            if isempty(dM)
                continue;
            end

            ds = movmean(dM, baseWin);
            if methodName == "extrema_smoothed_baseline" || methodName == "extrema_stronger_smoothing"
                AFM_base(i) = abs(min(ds));
                FM_base(i) = abs(max(ds));
            elseif methodName == "percentile_5_95"
                AFM_base(i) = abs(prctile(ds, 5));
                FM_base(i) = abs(prctile(ds, 95));
            elseif methodName == "percentile_10_90"
                AFM_base(i) = abs(prctile(ds, 10));
                FM_base(i) = abs(prctile(ds, 90));
            elseif methodName == "topk_mean_k3" || methodName == "topk_mean_k5" || methodName == "topk_mean_k7"
                if methodName == "topk_mean_k3"
                    k = 3;
                elseif methodName == "topk_mean_k5"
                    k = 5;
                else
                    k = 7;
                end
                dsSort = sort(ds, 'ascend');
                kEff = min(k, numel(dsSort));
                lowVals = dsSort(1:kEff);
                highVals = dsSort(end-kEff+1:end);
                AFM_base(i) = abs(mean(lowVals, 'omitnan'));
                FM_base(i) = abs(mean(highVals, 'omitnan'));
            elseif methodName == "existing_components_height"
                tmpRun = struct('T_common', T, 'DeltaM', dM, 'waitK', Tp(i));
                out = analyzeAFM_FM_components(tmpRun, 5, baseWin, false, -inf, 6, 'pre', 6, 'height', struct());
                AFM_base(i) = abs(out(1).AFM_amp);
                FM_base(i) = abs(out(1).FM_step_mag);
            end
        end

        % Bootstrap noise
        AFM_boot = nan(nRuns, nNoise);
        FM_boot = nan(nRuns, nNoise);
        for i = 1:nRuns
            dM = state.pauseRuns(i).DeltaM(:);
            T = state.pauseRuns(i).T_common(:);
            valid = isfinite(dM) & isfinite(T);
            dM = dM(valid);
            T = T(valid);
            if isempty(dM)
                continue;
            end
            sig = sigmaHT(i);
            for n = 1:nNoise
                dMp = dM + sig * randn(size(dM));
                ds = movmean(dMp, baseWin);
                if methodName == "extrema_smoothed_baseline" || methodName == "extrema_stronger_smoothing"
                    AFM_boot(i, n) = abs(min(ds));
                    FM_boot(i, n) = abs(max(ds));
                elseif methodName == "percentile_5_95"
                    AFM_boot(i, n) = abs(prctile(ds, 5));
                    FM_boot(i, n) = abs(prctile(ds, 95));
                elseif methodName == "percentile_10_90"
                    AFM_boot(i, n) = abs(prctile(ds, 10));
                    FM_boot(i, n) = abs(prctile(ds, 90));
                elseif methodName == "topk_mean_k3" || methodName == "topk_mean_k5" || methodName == "topk_mean_k7"
                    if methodName == "topk_mean_k3"
                        k = 3;
                    elseif methodName == "topk_mean_k5"
                        k = 5;
                    else
                        k = 7;
                    end
                    dsSort = sort(ds, 'ascend');
                    kEff = min(k, numel(dsSort));
                    lowVals = dsSort(1:kEff);
                    highVals = dsSort(end-kEff+1:end);
                    AFM_boot(i, n) = abs(mean(lowVals, 'omitnan'));
                    FM_boot(i, n) = abs(mean(highVals, 'omitnan'));
                elseif methodName == "existing_components_height"
                    tmpRun = struct('T_common', T, 'DeltaM', dMp, 'waitK', Tp(i));
                    out = analyzeAFM_FM_components(tmpRun, 5, baseWin, false, -inf, 6, 'pre', 6, 'height', struct());
                    AFM_boot(i, n) = abs(out(1).AFM_amp);
                    FM_boot(i, n) = abs(out(1).FM_step_mag);
                end
            end
        end

        AFM_std = std(AFM_boot, 0, 2, 'omitnan');
        FM_std = std(FM_boot, 0, 2, 'omitnan');
        AFM_noise_pct(m) = max(100 * AFM_std ./ max(AFM_base, eps), [], 'omitnan');
        FM_noise_pct(m) = max(100 * FM_std ./ max(FM_base, eps), [], 'omitnan');

        % Ordering + peak stability
        [~, rankAFM_ref] = sort(AFM_base, 'descend');
        [~, rankFM_ref] = sort(FM_base, 'descend');
        ordStable = true;
        pkStable = true;
        [~, pRef] = max(AFM_base);

        for w = 1:nW
            [~, rankAFM_w] = sort(AFM_w(:, w), 'descend');
            [~, rankFM_w] = sort(FM_w(:, w), 'descend');
            if any(rankAFM_w ~= rankAFM_ref) || any(rankFM_w ~= rankFM_ref)
                ordStable = false;
            end
            [~, pW] = max(AFM_w(:, w));
            if pW ~= pRef
                pkStable = false;
            end
        end

        for n = 1:nNoise
            [~, rankAFM_n] = sort(AFM_boot(:, n), 'descend');
            [~, rankFM_n] = sort(FM_boot(:, n), 'descend');
            if any(rankAFM_n ~= rankAFM_ref) || any(rankFM_n ~= rankFM_ref)
                ordStable = false;
            end
            [~, pN] = max(AFM_boot(:, n));
            if pN ~= pRef
                pkStable = false;
            end
        end

        ordering_stable(m) = ordStable;
        peak_stable(m) = pkStable;
        robust(m) = (AFM_max_var(m) < 15) && (FM_max_var(m) < 15) && ordStable && pkStable;

        if robust(m)
            notes(m) = "passes decision rule";
        else
            notes(m) = "fails decision rule";
        end
    end

    outTbl = table(methodNames, AFM_max_var, FM_max_var, AFM_noise_pct, FM_noise_pct, ordering_stable, peak_stable, robust, notes, ...
        'VariableNames', {'method_name','AFM_max_variation_percent','FM_max_variation_percent','AFM_noise_std_percent','FM_noise_std_percent','ordering_stable','peak_position_stable','robust','notes'});

    outCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_deltaM_method_robustness_comparison.csv');
    writetable(outTbl, outCsv);

    % Pick minimal recommended replacement among passing methods.
    preferredOrder = [ ...
        "percentile_10_90"; ...
        "percentile_5_95"; ...
        "topk_mean_k3"; ...
        "topk_mean_k5"; ...
        "topk_mean_k7"; ...
        "extrema_stronger_smoothing"; ...
        "existing_components_height" ...
    ];
    recommended = "none";
    for p = 1:numel(preferredOrder)
        idx = find(outTbl.method_name == preferredOrder(p), 1);
        if ~isempty(idx) && outTbl.robust(idx)
            recommended = preferredOrder(p);
            break;
        end
    end

    rep = fullfile(repoRoot, 'reports', 'aging', 'aging_deltaM_method_replacement.md');
    fid = fopen(rep, 'w');
    fprintf(fid, '# DeltaM Method Replacement Audit\n\n');
    fprintf(fid, '## 1. Why extrema\\_smoothed failed on DeltaM\n\n');
    idxBase = find(outTbl.method_name == "extrema_smoothed_baseline", 1);
    fprintf(fid, '- extrema\\_smoothed\\_baseline: AFM variation = %.6g%%, FM variation = %.6g%%, ordering stable = %d, robust = %d.\n\n', ...
        outTbl.AFM_max_variation_percent(idxBase), outTbl.FM_max_variation_percent(idxBase), outTbl.ordering_stable(idxBase), outTbl.robust(idxBase));

    fprintf(fid, '## 2. Candidate comparison\n\n');
    for i = 1:height(outTbl)
        fprintf(fid, '- %s: AFM_var=%.6g%%, FM_var=%.6g%%, AFM_noise=%.6g%%, FM_noise=%.6g%%, order=%d, peak=%d, robust=%d.\n', ...
            outTbl.method_name(i), ...
            outTbl.AFM_max_variation_percent(i), outTbl.FM_max_variation_percent(i), ...
            outTbl.AFM_noise_std_percent(i), outTbl.FM_noise_std_percent(i), ...
            outTbl.ordering_stable(i), outTbl.peak_position_stable(i), outTbl.robust(i));
    end

    fprintf(fid, '\n## 3. Minimal recommended replacement\n\n');
    if recommended == "none"
        fprintf(fid, '- No simple candidate passed the decision rule.\n');
    else
        fprintf(fid, '- Recommended method: %s\n', recommended);
        fprintf(fid, '- Selection rule: simplest candidate in the preferred order that satisfies AFM<15%%, FM<15%%, ordering stable, peak stable.\n');
    end

    fprintf(fid, '\n## 4. Physical interpretation\n\n');
    if recommended == "none"
        fprintf(fid, '- No robust simple extrema-like replacement identified; interpretation remains unstable under required stress tests.\n');
    elseif contains(char(recommended), 'percentile') || contains(char(recommended), 'topk')
        fprintf(fid, '- Recommended method preserves amplitude-like interpretation on DeltaM while reducing single-point sensitivity.\n');
    elseif recommended == "existing_components_height"
        fprintf(fid, '- Recommended method uses existing DeltaM decomposition with AFM dip height and FM step amplitude from the current repository implementation.\n');
    else
        fprintf(fid, '- Recommended method preserves DeltaM extrema-amplitude interpretation with modified smoothing policy.\n');
    end
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nRuns, {'DeltaM method robustness comparison completed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_deltaM_method_robustness_comparison_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'DeltaM method robustness comparison failed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
