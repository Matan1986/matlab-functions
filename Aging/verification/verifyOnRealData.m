function verifyOnRealData
% VERIFYONREALDATA - Real-data verification (Aging dip analysis only, Stage1-4)
%
% Runs only:
%   Stage1 load
%   Stage2 preprocess
%   Stage3 DeltaM
%   Stage4 AFM/FM decomposition
%
% Does NOT run switching reconstruction stages.

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════════╗\n');
    fprintf('║  REAL MG 119 VERIFICATION (AGING STAGE1-4 ONLY)              ║\n');
    fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

    baseFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath(baseFolder));

    paths = localPaths();
    mg119Root = fullfile(paths.dataRoot, 'MG 119');

    if ~exist(mg119Root, 'dir')
        fprintf('✗ MG 119 directory not found:\n  %s\n', mg119Root);
        return;
    end

    fprintf('MG 119 root: %s\n\n', mg119Root);

    allItems = dir(mg119Root);
    subfolders = allItems([allItems.isdir] & ~ismember({allItems.name}, {'.', '..'}));

    waitTimeFolders = {};
    waitTimeSeconds = [];
    datFileCounts = [];

    fprintf('Folder detection:\n');
    for i = 1:numel(subfolders)
        folderName = subfolders(i).name;
        folderPath = fullfile(mg119Root, folderName);

        [ok, wtSec] = parseWaitTimeFromFolder(folderName);
        if ~ok
            continue;
        end

        datFiles = dir(fullfile(folderPath, '*.dat'));
        nDat = numel(datFiles);

        waitTimeFolders{end+1} = folderPath;
        waitTimeSeconds(end+1) = wtSec;
        datFileCounts(end+1) = nDat;

        fprintf('%s\n', folderName);
        fprintf('folder path: %s\n', folderPath);
        fprintf('.dat files found: %d\n\n', nDat);

        if nDat == 0
            fprintf('⚠ zero .dat files found; searched folder: %s\n\n', folderPath);
        end
    end

    if isempty(waitTimeFolders)
        fprintf('✗ No wait-time folders found.\n');
        return;
    end

    allPauseRuns = [];
    allWaitSec = [];

    cfgTemplate = agingConfig();
    cfgTemplate.useRobustBaseline = true;
    cfgTemplate.dip_margin_K = 2;
    cfgTemplate.plateau_nPoints = 6;
    cfgTemplate.dropLowestN = 1;
    cfgTemplate.debug.verbose = true;
    cfgTemplate.debug.enable = false;
    cfgTemplate.doPlotting = false;
    cfgTemplate.showAFM_FM_example = false;
    cfgTemplate.RobustnessCheck = false;
    if ~isfield(cfgTemplate, 'diagnosticsVerbose')
        cfgTemplate.diagnosticsVerbose = false;
    end
    cfgTemplate.debug.verbose = cfgTemplate.diagnosticsVerbose;

    diagnosticsVerbose = isfield(cfgTemplate, 'diagnosticsVerbose') && cfgTemplate.diagnosticsVerbose;
    if ~isfield(cfgTemplate, 'recomputePlateauGeometryInVerify')
        cfgTemplate.recomputePlateauGeometryInVerify = false;
    end

    fprintf('Running Stage1-4 only per folder:\n\n');

    for i = 1:numel(waitTimeFolders)
        fprintf('[Folder %d/%d]\n', i, numel(waitTimeFolders));
        fprintf('folder path: %s\n', waitTimeFolders{i});
        fprintf('.dat files found: %d\n', datFileCounts(i));

        if datFileCounts(i) == 0
            fprintf('Skipping (no .dat files).\n\n');
            continue;
        end

        cfg = cfgTemplate;
        cfg.dataDir = waitTimeFolders{i};
        cfg.outputFolder = fullfile(cfg.dataDir, 'Results');

        try
            cfg = stage0_setupPaths(cfg);
            state = stage1_loadData(cfg);
            state = stage2_preprocess(state, cfg);
            state = stage3_computeDeltaM(state, cfg);
            state = stage4_analyzeAFM_FM(state, cfg);

            N = numel(state.pauseRuns);
            fprintf('pauseRuns detected: %d\n', N);

            if N > 0
                tpList = [state.pauseRuns.waitK];
                tpList = unique(tpList(isfinite(tpList)), 'stable');
                fprintf('Tp = [');
                fprintf('%g ', tpList);
                fprintf(']\n');
            else
                fprintf('Tp = []\n');
            end

            for k = 1:N
                state.pauseRuns(k).wait_time_seconds = waitTimeSeconds(i);
                state.pauseRuns(k).source_folder = waitTimeFolders{i};
            end

            if isempty(allPauseRuns)
                allPauseRuns = state.pauseRuns(:);
            else
                allPauseRuns = [allPauseRuns; state.pauseRuns(:)];
            end
            waitBlock = repmat(waitTimeSeconds(i), N, 1);
            allWaitSec = [allWaitSec; waitBlock(:)];

        catch ME
            fprintf('✗ Stage1-4 failed for folder: %s\n', waitTimeFolders{i});
            fprintf('  Error: %s\n', ME.message);
            disp(ME.getReport());
        end

        fprintf('\n');
    end

    if isempty(allPauseRuns)
        fprintf('✗ No pauseRuns collected from Stage1-4.\n');
        return;
    end

    diagTable = buildUnifiedTable(allPauseRuns, allWaitSec, cfgTemplate);

    fprintf('Unified diagnostics table:\n');
    tblOut = diagTable(:, {'Tp','wait_time_seconds','Tmin','Dip_area','Dip_depth','FM_step_mag','baseline_slope','baseline_status'});
    disp(tblOut);

    fprintf('Physics checks per Tp:\n');
    uniqueTp = unique(diagTable.Tp);
    uniqueTp = uniqueTp(isfinite(uniqueTp));

    for tp = uniqueTp'
        mask = diagTable.Tp == tp;
        wt = diagTable.wait_time_seconds(mask);
        dip_area = diagTable.Dip_area(mask);
        dip_depth = diagTable.Dip_depth(mask);
        bsl_stat = diagTable.baseline_status(mask);
        tmin = diagTable.Tmin(mask);
        dip_lo = diagTable.dip_lo(mask);
        dip_hi = diagTable.dip_hi(mask);
        n_plateau_L = diagTable.n_plateau_L(mask);
        n_plateau_R = diagTable.n_plateau_R(mask);

        % Apply full validity mask (quality gates)
        valid = buildQualityMask(wt, dip_area, dip_depth, bsl_stat, tmin, dip_lo, dip_hi, n_plateau_L, n_plateau_R);

        % Debug: print Tp=10 points before Spearman
        if diagnosticsVerbose && abs(tp - 10) < 0.1 && nnz(valid) > 0
            fprintf('  [DEBUG Tp=%.1f] Valid points after masking (n=%d):\n', tp, nnz(valid));
            valid_idx = find(valid);
            for idbg = 1:numel(valid_idx)
                idx = valid_idx(idbg);
                fprintf('    Point %d: wait_time_seconds=%g s, Dip_area=%g, Dip_depth=%g\n', ...
                    idbg, wt(idx), dip_area(idx), dip_depth(idx));
            end
        end

        % Spearman correlation for Dip_area
        if nnz(valid) >= 3
            [wt_s, ord] = sort(wt(valid));
            dip_area_s = dip_area(valid);
            dip_area_s = dip_area_s(ord);
            [rho, p] = corr(wt_s, dip_area_s, 'type', 'Spearman');
            fprintf('Tp=%.1f K: Spearman(wait_time_seconds, Dip_area)=%.4f (p=%.4g, n=%d)\n', tp, rho, p, nnz(valid));
        else
            fprintf('Tp=%.1f K: Spearman(wait_time_seconds, Dip_area)=insufficient points (n=%d)\n', tp, nnz(valid));
        end

        % Spearman correlation for Dip_depth
        if nnz(valid) >= 3
            [wt_s, ord] = sort(wt(valid));
            dip_depth_s = dip_depth(valid);
            dip_depth_s = dip_depth_s(ord);
            [rho, p] = corr(wt_s, dip_depth_s, 'type', 'Spearman');
            fprintf('Tp=%.1f K: Spearman(wait_time_seconds, Dip_depth)=%.4f (p=%.4g, n=%d)\n', tp, rho, p, nnz(valid));
        else
            fprintf('Tp=%.1f K: Spearman(wait_time_seconds, Dip_depth)=insufficient points (n=%d)\n', tp, nnz(valid));
        end
    end
    fprintf('\n');

    fprintf('FM stability per Tp:\n');
    for tp = uniqueTp'
        mask = diagTable.Tp == tp;
        fm = diagTable.FM_step_mag(mask);
        bsl_stat = diagTable.baseline_status(mask);
        wt = diagTable.wait_time_seconds(mask);
        dip_area = diagTable.Dip_area(mask);
        dip_depth = diagTable.Dip_depth(mask);
        tmin = diagTable.Tmin(mask);
        dip_lo = diagTable.dip_lo(mask);
        dip_hi = diagTable.dip_hi(mask);
        n_plateau_L = diagTable.n_plateau_L(mask);
        n_plateau_R = diagTable.n_plateau_R(mask);

        % Apply same validity mask + FM finite
        valid = buildQualityMask(wt, dip_area, dip_depth, bsl_stat, tmin, dip_lo, dip_hi, n_plateau_L, n_plateau_R) & isfinite(fm);
        fm_valid = fm(valid);

        if numel(fm_valid) >= 1
            fprintf('Tp=%.1f K: mean(FM_step_mag)=%.6g, std(FM_step_mag)=%.6g\n', tp, mean(fm_valid), std(fm_valid));
        else
            fprintf('Tp=%.1f K: mean/std(FM_step_mag)=NaN (no valid points)\n', tp);
        end
    end
    fprintf('\n');

    fprintf('FM aging checks per Tp:\n');
    for tp = uniqueTp'
        mask = diagTable.Tp == tp;
        wt = diagTable.wait_time_seconds(mask);
        fm = diagTable.FM_step_mag(mask);
        dip_area = diagTable.Dip_area(mask);
        dip_depth = diagTable.Dip_depth(mask);
        bsl_stat = diagTable.baseline_status(mask);
        tmin = diagTable.Tmin(mask);
        dip_lo = diagTable.dip_lo(mask);
        dip_hi = diagTable.dip_hi(mask);
        n_plateau_L = diagTable.n_plateau_L(mask);
        n_plateau_R = diagTable.n_plateau_R(mask);

        valid_fm = buildQualityMask(wt, dip_area, dip_depth, bsl_stat, tmin, dip_lo, dip_hi, n_plateau_L, n_plateau_R) & isfinite(fm);

        if nnz(valid_fm) >= 3
            [wt_s, ord] = sort(wt(valid_fm));
            fm_s = fm(valid_fm);
            fm_s = fm_s(ord);
            [rho, p] = corr(wt_s, fm_s, 'type', 'Spearman');
            fprintf('Tp=%.1f K: Spearman(wait_time_seconds, FM_step_mag)=%.4f (p=%.4g, n=%d)\n', tp, rho, p, nnz(valid_fm));
        else
            fprintf('Tp=%.1f K: Spearman(wait_time_seconds, FM_step_mag)=insufficient points (n=%d)\n', tp, nnz(valid_fm));
        end

        if nnz(valid_fm) >= 3
            [rho, p] = corr(fm(valid_fm), dip_area(valid_fm), 'type', 'Spearman');
            fprintf('Tp=%.1f K: corr(FM_step_mag, Dip_area)=%.4f (p=%.4g, n=%d)\n', tp, rho, p, nnz(valid_fm));
        else
            fprintf('Tp=%.1f K: corr(FM_step_mag, Dip_area)=insufficient points (n=%d)\n', tp, nnz(valid_fm));
        end

        if nnz(valid_fm) >= 3
            [rho, p] = corr(fm(valid_fm), dip_depth(valid_fm), 'type', 'Spearman');
            fprintf('Tp=%.1f K: corr(FM_step_mag, Dip_depth)=%.4f (p=%.4g, n=%d)\n', tp, rho, p, nnz(valid_fm));
        else
            fprintf('Tp=%.1f K: corr(FM_step_mag, Dip_depth)=insufficient points (n=%d)\n', tp, nnz(valid_fm));
        end
    end
    fprintf('\n');

    if diagnosticsVerbose
        fprintf('High-T debug after masking (Tp=30,34):\n');
        for tpDbg = [30 34]
            mask = abs(diagTable.Tp - tpDbg) < 0.1;
            if ~any(mask)
                continue;
            end

            wt = diagTable.wait_time_seconds(mask);
            fm = diagTable.FM_step_mag(mask);
            dip_area = diagTable.Dip_area(mask);
            dip_depth = diagTable.Dip_depth(mask);
            tmin = diagTable.Tmin(mask);
            bsl = diagTable.baseline_slope(mask);
            bsl_stat = diagTable.baseline_status(mask);
            dip_lo = diagTable.dip_lo(mask);
            dip_hi = diagTable.dip_hi(mask);
            n_plateau_L = diagTable.n_plateau_L(mask);
            n_plateau_R = diagTable.n_plateau_R(mask);

            valid_ht = buildQualityMask(wt, dip_area, dip_depth, bsl_stat, tmin, dip_lo, dip_hi, n_plateau_L, n_plateau_R) & isfinite(fm);
            if ~any(valid_ht)
                fprintf('Tp=%.0f K: no valid points after masking\n', tpDbg);
                continue;
            end

            dbgTbl = table(wt(valid_ht), fm(valid_ht), dip_area(valid_ht), dip_depth(valid_ht), tmin(valid_ht), bsl(valid_ht), ...
                'VariableNames', {'wait_time_seconds','FM_step_mag','Dip_area','Dip_depth','Tmin','baseline_slope'});
            fprintf('Tp=%.0f K valid rows:\n', tpDbg);
            disp(dbgTbl);
        end
        fprintf('\n');
    end

    fprintf('Dip position stability per Tp:\n');
    for tp = uniqueTp'
        mask = diagTable.Tp == tp;
        tmin = diagTable.Tmin(mask);
        bsl_stat = diagTable.baseline_status(mask);
        wt = diagTable.wait_time_seconds(mask);
        dip_area = diagTable.Dip_area(mask);
        dip_depth = diagTable.Dip_depth(mask);
        dip_lo = diagTable.dip_lo(mask);
        dip_hi = diagTable.dip_hi(mask);
        n_plateau_L = diagTable.n_plateau_L(mask);
        n_plateau_R = diagTable.n_plateau_R(mask);

        % Apply same validity mask
        valid = buildQualityMask(wt, dip_area, dip_depth, bsl_stat, tmin, dip_lo, dip_hi, n_plateau_L, n_plateau_R);
        tmin_valid = tmin(valid);
        tmin_valid = tmin_valid(isfinite(tmin_valid));

        if numel(tmin_valid) >= 2
            fprintf('Tp=%.1f K: std(Tmin)=%.6g K\n', tp, std(tmin_valid));
        else
            fprintf('Tp=%.1f K: std(Tmin)=NaN (insufficient points)\n', tp);
        end
    end
    fprintf('\n');

    fprintf('Baseline drift check per Tp:\n');
    for tp = uniqueTp'
        mask = diagTable.Tp == tp;
        wt = diagTable.wait_time_seconds(mask);
        bsl = diagTable.baseline_slope(mask);
        bsl_stat = diagTable.baseline_status(mask);
        dip_area = diagTable.Dip_area(mask);
        dip_depth = diagTable.Dip_depth(mask);
        tmin = diagTable.Tmin(mask);
        dip_lo = diagTable.dip_lo(mask);
        dip_hi = diagTable.dip_hi(mask);
        n_plateau_L = diagTable.n_plateau_L(mask);
        n_plateau_R = diagTable.n_plateau_R(mask);

        % Apply same validity mask
        valid = buildQualityMask(wt, dip_area, dip_depth, bsl_stat, tmin, dip_lo, dip_hi, n_plateau_L, n_plateau_R) & isfinite(bsl);

        if nnz(valid) >= 3
            [wt_s, ord] = sort(wt(valid));
            bsl_s = bsl(valid);
            bsl_s = bsl_s(ord);
            [rho, p] = corr(wt_s, bsl_s, 'type', 'Spearman');
            fprintf('Tp=%.1f K: corr(wait_time_seconds, baseline_slope)=%.4f (p=%.4g, n=%d)\n', tp, rho, p, nnz(valid));
        else
            fprintf('Tp=%.1f K: corr(wait_time_seconds, baseline_slope)=insufficient points (n=%d)\n', tp, nnz(valid));
        end
    end
    fprintf('\n');

    fprintf('Plateau diagnostics per run (Stage4 geometry):\n');
    fprintf('  Windows correspond to FM plateau geometry used by Stage4 extraction.\n');
    fprintf('  Robust-baseline recomputation is only used when Stage4 geometry is missing or forced by config.\n');
    for i = 1:height(diagTable)
        fprintf('Run %d | Tp=%.3g K | wait=%g s | plateau_L=[%.4g, %.4g] K (n=%g) | plateau_R=[%.4g, %.4g] K (n=%g) | source=%s\n', ...
            diagTable.RunID(i), diagTable.Tp(i), diagTable.wait_time_seconds(i), ...
            diagTable.plateau_L_min(i), diagTable.plateau_L_max(i), diagTable.n_plateau_L(i), ...
            diagTable.plateau_R_min(i), diagTable.plateau_R_max(i), diagTable.n_plateau_R(i), char(diagTable.plateau_geometry_source(i)));
    end
    fprintf('\n');
end

function diagTable = buildUnifiedTable(pauseRuns, waitSecVec, cfg)
    N = numel(pauseRuns);

    runId = (1:N)';
    tp = NaN(N,1);
    wt = waitSecVec(:);
    tmin = NaN(N,1);
    dipArea = NaN(N,1);
    dipDepth = NaN(N,1);
    fm = NaN(N,1);
    bsl = NaN(N,1);
    stat = strings(N,1);
    dipLo = NaN(N,1);
    dipHi = NaN(N,1);

    plMin = NaN(N,1);
    plMax = NaN(N,1);
    prMin = NaN(N,1);
    prMax = NaN(N,1);
    nL = NaN(N,1);
    nR = NaN(N,1);
    plateauSource = strings(N,1);
    forceRobustGeom = isfield(cfg, 'recomputePlateauGeometryInVerify') && logical(cfg.recomputePlateauGeometryInVerify);

    for i = 1:N
        r = pauseRuns(i);

        tp(i) = getval(r, 'waitK');
        tmin(i) = getval(r, 'Tmin_K');
        v = getval(r, 'Dip_area');
        if isempty(v)
            v = NaN;
        end
        dipArea(i) = v;

        v = getval(r, 'Dip_depth');
        if isempty(v)
            v = getval(r, 'AFM_amp');
        end
        if isempty(v)
            v = NaN;
        end
        dipDepth(i) = v;

        v = getval(r, 'FM_step_mag');
        if isempty(v)
            v = NaN;
        end
        fm(i) = v;

        v = getval(r, 'baseline_slope');
        if isempty(v)
            v = NaN;
        end
        bsl(i) = v;

        s = getval_str(r, 'baseline_status', 'unknown');
        if isempty(s)
            s = 'unknown';
        end
        stat(i) = string(s);

        w = getval(r, 'dip_window');
        if isnumeric(w) && numel(w) >= 2 && isfinite(w(1)) && isfinite(w(2))
            dipLo(i) = w(1);
            dipHi(i) = w(2);
        elseif isfinite(tp(i))
            dipLo(i) = tp(i) - cfg.dip_window_K;
            dipHi(i) = tp(i) + cfg.dip_window_K;
        end

        [T, dM] = getCurve(r);
        hasStage4Geom = false;

        if ~forceRobustGeom
            wL = getval(r, 'FM_plateau_left_window');
            wR = getval(r, 'FM_plateau_right_window');
            nL_run = getval(r, 'FM_plateau_n_left');
            nR_run = getval(r, 'FM_plateau_n_right');

            hasWinL = isnumeric(wL) && numel(wL) >= 2 && all(isfinite(wL(1:2)));
            hasWinR = isnumeric(wR) && numel(wR) >= 2 && all(isfinite(wR(1:2)));
            hasNL = isnumeric(nL_run) && isfinite(nL_run);
            hasNR = isnumeric(nR_run) && isfinite(nR_run);

            if hasWinL && hasWinR && hasNL && hasNR
                plMin(i) = wL(1);
                plMax(i) = wL(2);
                prMin(i) = wR(1);
                prMax(i) = wR(2);
                nL(i) = nL_run;
                nR(i) = nR_run;
                hasStage4Geom = true;
                plateauSource(i) = "stage4";
            end
        end

        if ~hasStage4Geom && ~isempty(T) && ~isempty(dM) && isfinite(tp(i))
            cfgB = struct('dip_halfwidth_K', cfg.dip_window_K, ...
                          'dip_margin_K', cfg.dip_margin_K, ...
                          'plateau_nPoints', cfg.plateau_nPoints, ...
                          'dropLowestN', cfg.dropLowestN, ...
                          'dropHighestN', 0);
            bout = estimateRobustBaseline(T, dM, tp(i), cfgB);
            if isfield(bout, 'idxL') && ~isempty(bout.idxL)
                plMin(i) = min(T(bout.idxL));
                plMax(i) = max(T(bout.idxL));
                nL(i) = numel(bout.idxL);
            end
            if isfield(bout, 'idxR') && ~isempty(bout.idxR)
                prMin(i) = min(T(bout.idxR));
                prMax(i) = max(T(bout.idxR));
                nR(i) = numel(bout.idxR);
            end

            if isfinite(plMin(i)) && isfinite(plMax(i)) && isfinite(prMin(i)) && isfinite(prMax(i))
                if forceRobustGeom
                    plateauSource(i) = "robust_recompute_forced";
                else
                    plateauSource(i) = "robust_recompute_fallback";
                end
            else
                plateauSource(i) = "missing";
            end
        elseif ~hasStage4Geom
            plateauSource(i) = "missing";
        end

        if ~isfinite(tmin(i)) && ~isempty(T) && ~isempty(dM)
            [~, j] = min(dM);
            if ~isempty(j) && isfinite(j)
                tmin(i) = T(j);
            end
        end
    end

    diagTable = table(runId, tp, wt, tmin, dipArea, dipDepth, fm, bsl, stat, dipLo, dipHi, ...
                      plMin, plMax, prMin, prMax, nL, nR, plateauSource, ...
                      'VariableNames', {'RunID','Tp','wait_time_seconds','Tmin','Dip_area','Dip_depth', ...
                                        'FM_step_mag','baseline_slope','baseline_status','dip_lo','dip_hi', ...
                                        'plateau_L_min','plateau_L_max','plateau_R_min','plateau_R_max', ...
                                        'n_plateau_L','n_plateau_R','plateau_geometry_source'});
end

function valid = buildQualityMask(wt, dip_area, dip_depth, baseline_status, tmin, dip_lo, dip_hi, n_plateau_L, n_plateau_R)
    valid = strcmp(baseline_status, "ok") & ...
            isfinite(wt) & wt > 0 & ...
            isfinite(dip_area) & ...
            isfinite(dip_depth) & ...
            isfinite(tmin) & ...
            isfinite(dip_lo) & isfinite(dip_hi) & ...
            (tmin >= dip_lo) & (tmin <= dip_hi) & ...
            isfinite(n_plateau_L) & isfinite(n_plateau_R) & ...
            (n_plateau_L >= 3) & (n_plateau_R >= 3);
end

function [isValid, waitSec] = parseWaitTimeFromFolder(folderName)
    isValid = false;
    waitSec = NaN;

    tok = regexp(folderName, '(\d+)sec\s+wait', 'tokens', 'ignorecase');
    if ~isempty(tok)
        waitSec = str2double(tok{1}{1});
        isValid = true;
        return;
    end

    tok = regexp(folderName, '(\d+)min\s+wait', 'tokens', 'ignorecase');
    if ~isempty(tok)
        waitSec = 60 * str2double(tok{1}{1});
        isValid = true;
    end
end

function [T, dM] = getCurve(run)
    T = [];
    dM = [];

    if isfield(run, 'T_common')
        T = run.T_common(:);
    end

    if isfield(run, 'DeltaM') && ~isempty(run.DeltaM)
        dM = run.DeltaM(:);
    elseif isfield(run, 'DeltaM_sharp') && ~isempty(run.DeltaM_sharp)
        dM = run.DeltaM_sharp(:);
    end

    if isempty(T) || isempty(dM)
        T = [];
        dM = [];
        return;
    end

    n = min(numel(T), numel(dM));
    T = T(1:n);
    dM = dM(1:n);

    valid = isfinite(T) & isfinite(dM);
    T = T(valid);
    dM = dM(valid);
end

function val = getval(s, fieldName)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = NaN;
    end
end

function val = getval_str(s, fieldName, dflt)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = dflt;
    end
end
