clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(genpath(fullfile(repoRoot, 'Aging')));

dataDir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 out of plane Aging no field high res 60min wait';

cfgRun = struct();
cfgRun.runLabel = 'extrema_smoothed_strict_stability_audit';

try
    run = createRunContext('aging', cfgRun);

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

    windows = [5 9 13 17 21 31];
    nW = numel(windows);
    nNoise = 50;
    rng(1);

    Tp = [state.pauseRuns.waitK]';
    nRuns = numel(Tp);

    AFM_w = nan(nRuns, nW);
    FM_w = nan(nRuns, nW);
    sigmaHT = nan(nRuns, 1);

    for i = 1:nRuns
        dM = state.pauseRuns(i).DeltaM(:);
        T = state.pauseRuns(i).T_common(:);
        valid = isfinite(dM) & isfinite(T);
        dM = dM(valid);
        T = T(valid);
        if isempty(dM)
            continue;
        end

        % High-T noise estimate from top 20%% of T range.
        tCut = prctile(T, 80);
        idxHT = T >= tCut;
        if nnz(idxHT) < 5
            idxHT = true(size(T));
        end
        dMht = dM(idxHT);
        dMhtSm = movmean(dMht, 11);
        sigmaHT(i) = std(dMht - dMhtSm, 'omitnan');
        if ~isfinite(sigmaHT(i))
            sigmaHT(i) = 0;
        end

        for w = 1:nW
            ds = movmean(dM, windows(w));
            FM_w(i, w) = max(ds);
            AFM_w(i, w) = min(ds);
        end
    end

    % Percent variation across aggressive window sweep.
    AFM_mag = abs(AFM_w);
    FM_mag = abs(FM_w);
    AFM_var_pct_perT = 100 * (max(AFM_mag, [], 2) - min(AFM_mag, [], 2)) ./ max(mean(AFM_mag, 2, 'omitnan'), eps);
    FM_var_pct_perT = 100 * (max(FM_mag, [], 2) - min(FM_mag, [], 2)) ./ max(mean(FM_mag, 2, 'omitnan'), eps);
    AFM_MAX_VARIATION_PERCENT = max(AFM_var_pct_perT, [], 'omitnan');
    FM_MAX_VARIATION_PERCENT = max(FM_var_pct_perT, [], 'omitnan');

    % Bootstrap noise test at default window=11.
    AFM_boot = nan(nRuns, nNoise);
    FM_boot = nan(nRuns, nNoise);
    for i = 1:nRuns
        dM = state.pauseRuns(i).DeltaM(:);
        valid = isfinite(dM);
        dM = dM(valid);
        if isempty(dM)
            continue;
        end
        sig = sigmaHT(i);
        for n = 1:nNoise
            dMp = dM + sig * randn(size(dM));
            ds = movmean(dMp, 11);
            FM_boot(i, n) = max(ds);
            AFM_boot(i, n) = min(ds);
        end
    end

    AFM_base = abs(AFM_w(:, windows == 9 | windows == 13)); %#ok<NASGU>
    FM_base = abs(FM_w(:, windows == 9 | windows == 13)); %#ok<NASGU>
    % Use explicit baseline window=11 computed directly.
    AFM_base11 = nan(nRuns, 1);
    FM_base11 = nan(nRuns, 1);
    localDipJumpPct = nan(nRuns, 1);
    for i = 1:nRuns
        dM = state.pauseRuns(i).DeltaM(:);
        valid = isfinite(dM);
        dM = dM(valid);
        if isempty(dM)
            continue;
        end
        ds11 = movmean(dM, 11);
        FM_base11(i) = max(ds11);
        AFM_base11(i) = min(ds11);

        % Local dip sensitivity: shifted minima around central minimum.
        [~, idxMin] = min(ds11);
        shifts = -3:3;
        vals = nan(size(shifts));
        for s = 1:numel(shifts)
            idx = idxMin + shifts(s);
            idx = max(1, min(numel(ds11), idx));
            vals(s) = ds11(idx);
        end
        centerVal = ds11(idxMin);
        localDipJumpPct(i) = 100 * max(abs(vals - centerVal)) / max(abs(centerVal), eps);
    end

    AFM_noise_std = std(AFM_boot, 0, 2, 'omitnan');
    FM_noise_std = std(FM_boot, 0, 2, 'omitnan');
    AFM_NOISE_STD_PERCENT = max(100 * AFM_noise_std ./ max(abs(AFM_base11), eps), [], 'omitnan');
    FM_NOISE_STD_PERCENT = max(100 * FM_noise_std ./ max(abs(FM_base11), eps), [], 'omitnan');

    % Rank/order stability (AFM by |AFM|, FM by FM amplitude).
    [~, rankAFM_ref] = sort(abs(AFM_base11), 'descend');
    [~, rankFM_ref] = sort(FM_base11, 'descend');
    ORDERING_STABLE = true;
    PEAK_POSITION_STABLE = true;

    for w = 1:nW
        [~, rankAFM_w] = sort(abs(AFM_w(:, w)), 'descend');
        [~, rankFM_w] = sort(FM_w(:, w), 'descend');
        if any(rankAFM_w ~= rankAFM_ref) || any(rankFM_w ~= rankFM_ref)
            ORDERING_STABLE = false;
        end
        [~, pAFM_ref] = max(abs(AFM_base11));
        [~, pAFM_w] = max(abs(AFM_w(:, w)));
        if pAFM_w ~= pAFM_ref
            PEAK_POSITION_STABLE = false;
        end
    end

    for n = 1:nNoise
        [~, rankAFM_n] = sort(abs(AFM_boot(:, n)), 'descend');
        [~, rankFM_n] = sort(FM_boot(:, n), 'descend');
        if any(rankAFM_n ~= rankAFM_ref) || any(rankFM_n ~= rankFM_ref)
            ORDERING_STABLE = false;
        end
        [~, pAFM_ref] = max(abs(AFM_base11));
        [~, pAFM_n] = max(abs(AFM_boot(:, n)));
        if pAFM_n ~= pAFM_ref
            PEAK_POSITION_STABLE = false;
        end
    end

    % Strict robustness criteria.
    robustByVar = (AFM_MAX_VARIATION_PERCENT < 5) && (FM_MAX_VARIATION_PERCENT < 5);
    robustByNoise = (AFM_NOISE_STD_PERCENT < 5) && (FM_NOISE_STD_PERCENT < 5);
    robustByOrder = ORDERING_STABLE && PEAK_POSITION_STABLE;
    robustByLocal = max(localDipJumpPct, [], 'omitnan') < 15;
    ROBUST = robustByVar && robustByNoise && robustByOrder && robustByLocal;

    outTbl = table( ...
        AFM_MAX_VARIATION_PERCENT, FM_MAX_VARIATION_PERCENT, ...
        AFM_NOISE_STD_PERCENT, FM_NOISE_STD_PERCENT, ...
        ORDERING_STABLE, PEAK_POSITION_STABLE, ...
        max(localDipJumpPct, [], 'omitnan'), ROBUST, ...
        'VariableNames', {'AFM_MAX_VARIATION_PERCENT','FM_MAX_VARIATION_PERCENT','AFM_NOISE_STD_PERCENT','FM_NOISE_STD_PERCENT','ORDERING_STABLE','PEAK_POSITION_STABLE','AFM_LOCAL_DIP_MAX_JUMP_PERCENT','ROBUST'});
    outCsv = fullfile(repoRoot, 'tables', 'aging', 'aging_extrema_smoothed_strict_stability_audit.csv');
    writetable(outTbl, outCsv);

    repPath = fullfile(repoRoot, 'reports', 'aging', 'aging_extrema_smoothed_strict_stability_audit.md');
    fid = fopen(repPath, 'w');
    fprintf(fid, '# extrema\\_smoothed Strict Stability Audit (DeltaM Only)\n\n');
    fprintf(fid, '- AFM_MAX_VARIATION_PERCENT = %.6g\n', AFM_MAX_VARIATION_PERCENT);
    fprintf(fid, '- FM_MAX_VARIATION_PERCENT = %.6g\n', FM_MAX_VARIATION_PERCENT);
    fprintf(fid, '- AFM_NOISE_STD_PERCENT = %.6g\n', AFM_NOISE_STD_PERCENT);
    fprintf(fid, '- FM_NOISE_STD_PERCENT = %.6g\n', FM_NOISE_STD_PERCENT);
    fprintf(fid, '- ORDERING_STABLE = %s\n', string(ORDERING_STABLE));
    fprintf(fid, '- PEAK_POSITION_STABLE = %s\n', string(PEAK_POSITION_STABLE));
    fprintf(fid, '- AFM_LOCAL_DIP_MAX_JUMP_PERCENT = %.6g\n', max(localDipJumpPct, [], 'omitnan'));
    fprintf(fid, '- ROBUST = %s\n', string(ROBUST));
    fclose(fid);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nRuns, {'strict stability audit completed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_extrema_smoothed_strict_stability_audit_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'strict stability audit failed'}, ...
        'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
