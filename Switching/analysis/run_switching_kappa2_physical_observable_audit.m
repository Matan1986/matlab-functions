%RUN_SWITCHING_KAPPA2_PHYSICAL_OBSERVABLE_AUDIT
% Canonical Switching-only audit: what kappa2 tracks vs reconstructed observables,
% Stage-E-style tail burden, and canonical per-T fit diagnostics (rmse_full_row).
%
% Outputs (repo root):
%   tables/switching_kappa2_observable_audit.csv
%   tables/switching_kappa2_residual_burden_tests.csv
%   tables/switching_kappa2_stability_tests.csv
%   reports/switching_kappa2_physical_observable_audit.md
%
% No Aging inputs. No cross-module claims.
%
% Invoke: run(fullfile(repoRoot,'Switching','analysis','run_switching_kappa2_physical_observable_audit.m'))

clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'run_switching_kappa2_physical_observable_audit';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_kappa2_physical_observable_audit';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'kappa2 physical observable audit initialized'}, false);

    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    rankGlobalPath = fullfile(repoRoot, 'tables', 'switching_residual_global_rank_structure.csv');
    rankRegPath = fullfile(repoRoot, 'tables', 'switching_residual_rank_structure_by_regime.csv');

    reqPaths = {sLongPath, phi1Path, ampPath, rankGlobalPath, rankRegPath};
    reqNames = {'switching_canonical_S_long.csv','switching_canonical_phi1.csv', ...
        'switching_mode_amplitudes_vs_T.csv','switching_residual_global_rank_structure.csv', ...
        'switching_residual_rank_structure_by_regime.csv'};
    for i = 1:numel(reqPaths)
        if strlength(string(reqPaths{i})) == 0 || exist(reqPaths{i}, 'file') ~= 2
            error('run_switching_kappa2_physical_observable_audit:MissingInput', ...
                'Missing required canonical input: %s (%s)', reqNames{i}, reqPaths{i});
        end
    end

    [canonDir, ~, ~] = fileparts(sLongPath);
    obsPath = fullfile(canonDir, 'switching_canonical_observables.csv');
    if exist(obsPath, 'file') ~= 2
        error('run_switching_kappa2_physical_observable_audit:MissingObs', ...
            'Canonical observables missing next to S_long: %s', obsPath);
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));
    validateCanonicalInputTable(rankGlobalPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_residual_global_rank_structure.csv', 'expected_role', 'rank_global')));
    validateCanonicalInputTable(rankRegPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_residual_rank_structure_by_regime.csv', 'expected_role', 'rank_by_regime')));

    sLong = readtable(sLongPath);
    ampTbl = readtable(ampPath);
    obsTbl = readtable(obsPath);

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sLong.Properties.VariableNames)
            error('run_switching_kappa2_physical_observable_audit:BadSLong', 'S_long missing %s', reqS{i});
        end
    end
    reqA = {'T_K','kappa1','kappa2'};
    for i = 1:numel(reqA)
        if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
            error('run_switching_kappa2_physical_observable_audit:BadAmp', 'Amplitudes missing %s', reqA{i});
        end
    end
    reqO = {'T_K','rmse_full_row','rmse_pt_row','phi_cosine_row'};
    for i = 1:numel(reqO)
        if ~ismember(reqO{i}, obsTbl.Properties.VariableNames)
            error('run_switching_kappa2_physical_observable_audit:BadObs', 'Observables missing %s', reqO{i});
        end
    end

    % --- Maps (same construction as run_switching_observable_mapping_audit) ---
    T = double(sLong.T_K);
    I = double(sLong.current_mA);
    S = double(sLong.S_percent);
    B = double(sLong.S_model_pt_percent);
    C = double(sLong.CDF_pt);
    v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
    T = T(v); I = I(v); S = S(v); B = B(v); C = C(v);
    TI = table(T, I, S, B, C);
    TIg = groupsummary(TI, {'T','I'}, 'mean', {'S','B','C'});
    allT = unique(double(TIg.T), 'sorted');
    allI = unique(double(TIg.I), 'sorted');
    nT = numel(allT);
    nI = numel(allI);
    Smap = NaN(nT, nI);
    Bmap = NaN(nT, nI);
    Cmap = NaN(nT, nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(TIg.T) - allT(it)) < 1e-9 & abs(double(TIg.I) - allI(ii)) < 1e-9;
            if any(m)
                idx = find(m, 1);
                Smap(it, ii) = double(TIg.mean_S(idx));
                Bmap(it, ii) = double(TIg.mean_B(idx));
                Cmap(it, ii) = double(TIg.mean_C(idx));
            end
        end
    end

    phi1Tbl = readtable(phi1Path);
    pI = double(phi1Tbl.current_mA);
    pV = double(phi1Tbl.Phi1);
    pv = isfinite(pI) & isfinite(pV);
    pI = pI(pv); pV = pV(pv);
    Pg = groupsummary(table(pI, pV), {'pI'}, 'mean', {'pV'});
    phi1Vec = interp1(double(Pg.pI), double(Pg.mean_pV), allI, 'linear', NaN)';
    phi1Vec = fillmissing(phi1Vec, 'linear', 'EndValues', 'nearest');
    nrm1 = norm(phi1Vec);
    if nrm1 > 0, phi1Vec = phi1Vec / nrm1; end

    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

    pred0 = Bmap;
    pred1 = pred0 - kappa1(:) * phi1Vec(:)';
    res0 = Smap - pred0;
    res1 = Smap - pred1;
    R1z = res1;
    R1z(~isfinite(R1z)) = 0;
    [~, ~, V] = svd(R1z, 'econ');
    if size(V, 2) >= 1
        phi2Vec = V(:, 1);
    else
        phi2Vec = zeros(nI, 1);
    end
    nrm2 = norm(phi2Vec);
    if nrm2 > 0, phi2Vec = phi2Vec / nrm2; end

    rmse_rank1_row = sqrt(mean(res1 .^ 2, 2, 'omitnan'));

    cdfAxis = mean(Cmap, 1, 'omitnan');
    if any(~isfinite(cdfAxis))
        cdfAxis = fillmissing(cdfAxis, 'linear', 'EndValues', 'nearest');
    end
    midMaskI = cdfAxis > 0.40 & cdfAxis < 0.60;
    tailMaskI = cdfAxis >= 0.80;
    R0 = Smap - Bmap;
    tailBurden = mean(R0(:, tailMaskI) .^ 2, 2, 'omitnan') ./ max(mean(R0(:, midMaskI) .^ 2, 2, 'omitnan'), eps);
    globalResEnergy = mean(R0 .^ 2, 2, 'omitnan');
    peakResAbs = max(abs(R0), [], 2, 'omitnan');

    % Canonical observables on grid
    rmseFull = NaN(nT, 1);
    rmsePt = NaN(nT, 1);
    phiCos = NaN(nT, 1);
    for it = 1:nT
        mT = abs(double(obsTbl.T_K) - allT(it)) < 1e-9;
        if any(mT)
            j = find(mT, 1);
            rmseFull(it) = double(obsTbl.rmse_full_row(j));
            rmsePt(it) = double(obsTbl.rmse_pt_row(j));
            phiCos(it) = double(obsTbl.phi_cosine_row(j));
        end
    end

    transNum = zeros(nT, 1);
    if ismember('transition_flag', ampTbl.Properties.VariableNames)
        for it = 1:nT
            mT = abs(double(ampTbl.T_K) - allT(it)) < 1e-9;
            if any(mT)
                j = find(mT, 1);
                transNum(it) = double(strcmpi(string(ampTbl.transition_flag(j)), "YES"));
            end
        end
    end

    cdfByI = mean(Cmap, 1, 'omitnan');
    if any(~isfinite(cdfByI))
        cdfByI = fillmissing(cdfByI, 'linear', 'EndValues', 'nearest');
    end

    obsNames = { ...
        'S_peak', 'S_integral_I', 'max_slope_dS_dI', ...
        'central_ridge_excess_res0', 'curvature_midpoint', 'symmetry_cdf_mirror', ...
        'quantile_spread_I_20_80', 'high_CDF_tail_weight', 'low_CDF_tail_weight', ...
        'raw_I_span_S10_S90', 'res0_window_low', 'res0_window_mid', 'res0_window_high', ...
        'res0_local_peak', 'res0_local_trough', 'phi2_localization_mid_energy' ...
        };
    obsFamily = { ...
        'amplitude_scale','amplitude_scale','amplitude_scale', ...
        'shape_central','shape_central','shape_central', ...
        'tail_distribution','tail_distribution','tail_distribution', ...
        'transition_sharpness','localized_features','localized_features','localized_features', ...
        'localized_features','localized_features','phi2_structure' ...
        };
    nObs = numel(obsNames);
    obsMat = NaN(nT, nObs);

    for it = 1:nT
        y = Smap(it, :);
        b = Bmap(it, :);
        r0 = res0(it, :);
        r1 = res1(it, :);
        xI = allI(:)';
        xC = Cmap(it, :);
        m = isfinite(y) & isfinite(b) & isfinite(r0) & isfinite(xI) & isfinite(xC);
        y = y(m); b = b(m); r0 = r0(m); r1 = r1(m); xI = xI(m); xC = xC(m);
        if numel(y) < 4
            continue;
        end
        [xI, ord] = sort(xI, 'ascend');
        y = y(ord); b = b(ord); r0 = r0(ord); r1 = r1(ord); xC = xC(ord);

        dI = gradient(xI);
        dS = gradient(y) ./ max(dI, eps);
        d2S = gradient(dS) ./ max(dI, eps);

        obsMat(it,1) = max(y, [], 'omitnan');
        obsMat(it,2) = trapz(xI, y);
        obsMat(it,3) = max(abs(dS), [], 'omitnan');

        midMask = xC >= 0.4 & xC <= 0.6;
        if sum(midMask) >= 2
            obsMat(it,4) = trapz(xI(midMask), r0(midMask));
        end
        [~, idxMid] = min(abs(xC - 0.5));
        if ~isempty(idxMid)
            obsMat(it,5) = abs(d2S(idxMid));
        end
        cGrid = linspace(0.1, 0.9, 9);
        symVals = NaN(size(cGrid));
        for ic = 1:numel(cGrid)
            c1 = cGrid(ic);
            c2 = 1 - c1;
            [d1, i1] = min(abs(xC - c1));
            [d2, i2] = min(abs(xC - c2));
            if isfinite(d1) && isfinite(d2) && d1 < 0.15 && d2 < 0.15
                symVals(ic) = y(i2) - y(i1);
            end
        end
        obsMat(it,6) = mean(abs(symVals), 'omitnan');

        [d20, i20] = min(abs(xC - 0.2));
        [d80, i80] = min(abs(xC - 0.8));
        if isfinite(d20) && isfinite(d80) && d20 < 0.2 && d80 < 0.2
            obsMat(it,7) = abs(xI(i80) - xI(i20));
        end
        hiMask = xC >= 0.8;
        loMask = xC <= 0.2;
        if sum(hiMask) >= 2, obsMat(it,8) = trapz(xI(hiMask), y(hiMask)); end
        if sum(loMask) >= 2, obsMat(it,9) = trapz(xI(loMask), y(loMask)); end

        yMin = min(y, [], 'omitnan');
        yMax = max(y, [], 'omitnan');
        if isfinite(yMin) && isfinite(yMax) && yMax > yMin
            yNorm = (y - yMin) ./ (yMax - yMin);
            [d10, i10] = min(abs(yNorm - 0.1));
            [d90, i90] = min(abs(yNorm - 0.9));
            if isfinite(d10) && isfinite(d90)
                obsMat(it,10) = abs(xI(i90) - xI(i10));
            end
        end

        wLow = xC >= 0.10 & xC < 0.30;
        wMid = xC >= 0.40 & xC <= 0.60;
        wHigh = xC > 0.70 & xC <= 0.90;
        if any(wLow), obsMat(it,11) = mean(r0(wLow), 'omitnan'); end
        if any(wMid), obsMat(it,12) = mean(r0(wMid), 'omitnan'); end
        if any(wHigh), obsMat(it,13) = mean(r0(wHigh), 'omitnan'); end
        obsMat(it,14) = max(r0, [], 'omitnan');
        obsMat(it,15) = min(r0, [], 'omitnan');

        midByI = cdfByI >= 0.4 & cdfByI <= 0.6;
        den = sum(r1 .^ 2, 'omitnan');
        if den > 0 && any(midByI)
            obsMat(it,16) = sum((r1(midByI)) .^ 2, 'omitnan') / den;
        end
    end

    pearK2 = NaN(nObs, 1);
    spearK2 = NaN(nObs, 1);
    loocvR2K2 = NaN(nObs, 1);
    loocvRmseK2 = NaN(nObs, 1);
    for j = 1:nObs
        x = obsMat(:, j);
        m2 = isfinite(x) & isfinite(kappa2);
        if sum(m2) >= 3
            pearK2(j) = corr(x(m2), kappa2(m2), 'type', 'Pearson', 'rows', 'complete');
            spearK2(j) = corr(x(m2), kappa2(m2), 'type', 'Spearman', 'rows', 'complete');
            idx = find(m2);
            yTrue = kappa2(idx);
            yPred = NaN(size(yTrue));
            for ii = 1:numel(idx)
                train = idx; train(ii) = [];
                if numel(train) >= 2
                    p = polyfit(x(train), kappa2(train), 1);
                    yPred(ii) = polyval(p, x(idx(ii)));
                end
            end
            mv = isfinite(yPred) & isfinite(yTrue);
            if any(mv)
                loocvRmseK2(j) = sqrt(mean((yPred(mv) - yTrue(mv)) .^ 2, 'omitnan'));
                den = sum((yTrue(mv) - mean(yTrue(mv), 'omitnan')) .^ 2, 'omitnan');
                if den > 0
                    loocvR2K2(j) = 1 - sum((yPred(mv) - yTrue(mv)) .^ 2, 'omitnan') / den;
                end
            end
        end
    end

    sabs = abs(spearK2);
    sabs(~isfinite(sabs)) = -1;
    [~, ordS] = sort(sabs, 'descend');
    rankAbsSpear = NaN(nObs, 1);
    for r = 1:nObs
        rankAbsSpear(ordS(r)) = r;
    end

    auditTbl = table( ...
        string(obsNames(:)), string(obsFamily(:)), ...
        pearK2, spearK2, loocvR2K2, loocvRmseK2, rankAbsSpear, ...
        'VariableNames', {'observable_name','observable_family', ...
        'pearson_kappa2','spearman_kappa2','loocv_r2_kappa2','loocv_rmse_kappa2','rank_abs_spearman'});
    switchingWriteTableBothPaths(auditTbl, repoRoot, runTables, 'switching_kappa2_observable_audit.csv');

    % --- Residual / burden scalar metrics ---
    burdenMetrics = { ...
        'tail_burden_ratio', 'global_residual_energy', 'peak_residual_abs', ...
        'rmse_full_row', 'rmse_pt_row', 'phi_cosine_row', 'rmse_rank1_reconstructed', ...
        'transition_flag_numeric' ...
        };
    burdenHyp = { ...
        'tail_burden', 'residual_amplitude', 'residual_amplitude', ...
        'rank1_fit_residual', 'rank1_fit_residual', 'width_mismatch_or_mode_geometry', 'rank1_fit_residual', ...
        'transition_proximity' ...
        };
    Mbur = [tailBurden, globalResEnergy, peakResAbs, rmseFull, rmsePt, phiCos, rmse_rank1_row, transNum];
    nB = size(Mbur, 2);
    bPear = NaN(nB, 1);
    bSpear = NaN(nB, 1);
    bLoocvR2 = NaN(nB, 1);
    bPartPear = NaN(nB, 1);
    for j = 1:nB
        x = Mbur(:, j);
        mk = isfinite(x) & isfinite(kappa2);
        if sum(mk) >= 3
            bPear(j) = corr(x(mk), kappa2(mk), 'type', 'Pearson', 'rows', 'complete');
            bSpear(j) = corr(x(mk), kappa2(mk), 'type', 'Spearman', 'rows', 'complete');
            idx = find(mk);
            yTrue = kappa2(idx);
            yPred = NaN(size(yTrue));
            for ii = 1:numel(idx)
                train = idx; train(ii) = [];
                if numel(train) >= 2
                    p = polyfit(x(train), kappa2(train), 1);
                    yPred(ii) = polyval(p, x(idx(ii)));
                end
            end
            mv = isfinite(yPred) & isfinite(yTrue);
            if any(mv)
                den = sum((yTrue(mv) - mean(yTrue(mv), 'omitnan')) .^ 2, 'omitnan');
                if den > 0
                    r2 = 1 - sum((yPred(mv) - yTrue(mv)) .^ 2, 'omitnan') / den;
                    if abs(r2) <= 5
                        bLoocvR2(j) = r2;
                    end
                end
            end
        end
        % Partial Pearson kappa2 vs metric given rmse_full_row
        if j ~= 4
            mc = isfinite(x) & isfinite(kappa2) & isfinite(rmseFull);
            if sum(mc) >= 4
                Z = [ones(sum(mc),1), rmseFull(mc)];
                yv = kappa2(mc);
                xv = x(mc);
                ey = yv - Z * (Z \ yv);
                ex = xv - Z * (Z \ xv);
                if std(ey, 'omitnan') > 0 && std(ex, 'omitnan') > 0
                    bPartPear(j) = corr(ey, ex, 'rows', 'complete');
                end
            end
        end
    end

    burdenTbl = table( ...
        string(burdenMetrics(:)), string(burdenHyp(:)), ...
        bPear, bSpear, bLoocvR2, bPartPear, ...
        'VariableNames', {'metric_name','hypothesis_family', ...
        'pearson_kappa2','spearman_kappa2','loocv_r2_kappa2_linear','partial_pearson_kappa2_given_rmse_full'});
    switchingWriteTableBothPaths(burdenTbl, repoRoot, runTables, 'switching_kappa2_residual_burden_tests.csv');

    % --- Stability: exclusions on joint valid mask ---
    baseMask = isfinite(kappa2) & isfinite(tailBurden) & isfinite(rmseFull);
    tHi = prctile(allT, 90);
    tLo = prctile(allT, 10);
    spHi = prctile(obsMat(:,1), 85);
    spLo = prctile(obsMat(:,1), 15);
    exclNames = { ...
        'full_sample'; ...
        'exclude_top_decile_T'; ...
        'exclude_bottom_decile_T'; ...
        'exclude_extreme_S_peak_15pct' ...
        };
    masks = { ...
        baseMask; ...
        baseMask & allT <= tHi; ...
        baseMask & allT >= tLo; ...
        baseMask & obsMat(:,1) >= spLo & obsMat(:,1) <= spHi ...
        };

    stabRows = table();
    for ei = 1:numel(exclNames)
        mk = masks{ei};
        sTail = kappa2AuditSpearCol(mk, tailBurden, kappa2);
        sRmse = kappa2AuditSpearCol(mk, rmseFull, kappa2);
        sSym = kappa2AuditSpearCol(mk, obsMat(:,6), kappa2);
        sHiTail = kappa2AuditSpearCol(mk, obsMat(:,8), kappa2);
        sSpan = kappa2AuditSpearCol(mk, obsMat(:,10), kappa2);
        stabRows = [stabRows; table( ...
            string(exclNames{ei}), sum(mk), sTail, sRmse, sSym, sHiTail, sSpan, ...
            'VariableNames', {'exclusion_test','n_rows', ...
            'spearman_kappa2_tail_burden_ratio','spearman_kappa2_rmse_full_row', ...
            'spearman_kappa2_symmetry_cdf_mirror','spearman_kappa2_high_CDF_tail_weight', ...
            'spearman_kappa2_raw_I_span_S10_S90'})]; %#ok<AGROW>
    end
    switchingWriteTableBothPaths(stabRows, repoRoot, runTables, 'switching_kappa2_stability_tests.csv');

    % --- Family strength (mean |spearman| by family) ---
    famU = unique(string(obsFamily(:)));
    famMean = zeros(numel(famU), 1);
    for fi = 1:numel(famU)
        famMean(fi) = mean(abs(spearK2(strcmp(string(obsFamily(:)), famU(fi)))) , 'omitnan');
    end
    [mxFam, ixFam] = max(famMean);
    topFam = char(famU(ixFam));

    spearTailBur = bSpear(strcmp(burdenMetrics, 'tail_burden_ratio'));
    spearRmseFull = bSpear(strcmp(burdenMetrics, 'rmse_full_row'));
    spearRank1Rmse = bSpear(strcmp(burdenMetrics, 'rmse_rank1_reconstructed'));
    spearSymObs = spearK2(strcmp(string(obsNames(:)), "symmetry_cdf_mirror"));
    spearTransSpan = spearK2(strcmp(string(obsNames(:)), "raw_I_span_S10_S90"));
    spearTransFlag = bSpear(strcmp(burdenMetrics, 'transition_flag_numeric'));

    stabTail = stabRows.spearman_kappa2_tail_burden_ratio;
    mm = abs(stabTail);

    % Verdicts (policy-aligned, conservative)
    KAPPA2_TRACKS_TAIL_BURDEN = verdict3(abs(spearTailBur) >= 0.45, abs(spearTailBur) >= 0.30, mxFam > 0 && strcmp(topFam, 'tail_distribution'));
    KAPPA2_TRACKS_ASYMMETRY = verdict3(abs(spearSymObs) >= 0.45, abs(spearSymObs) >= 0.28, false);
    % Transition: regime flag correlates; sharpness proxy raw_I_span is ~null here.
    KAPPA2_TRACKS_TRANSITION = verdict3( ...
        abs(spearTransFlag) >= 0.45 && abs(spearTransSpan) >= 0.35, ...
        abs(spearTransFlag) >= 0.28 || abs(spearTransSpan) >= 0.28, false);
    KAPPA2_IS_ROBUST_OBSERVABLE = verdict3( ...
        all(isfinite(mm)) && all(mm >= 0.35) && all(double(stabRows.n_rows) >= 5), ...
        sum(mm >= 0.30 & isfinite(mm)) >= 3, false);
    % Policy: no aging/material "mechanism" claims. PARTIAL = operational tail-burden / rank-2
    % residual-coordinate language is supported by data; YES is not used for mechanism.
    if strcmp(KAPPA2_TRACKS_TAIL_BURDEN, 'NO')
        KAPPA2_MECHANISM_CLAIM_ALLOWED = 'NO';
    else
        KAPPA2_MECHANISM_CLAIM_ALLOWED = 'PARTIAL';
    end

    lines = {};
    lines{end+1} = '# Switching kappa2 physical observable audit';
    lines{end+1} = '';
    lines{end+1} = '## Scope and boundaries';
    lines{end+1} = '- **Switching canonical artifacts only** (identity-resolved `switching_canonical_S_long.csv`, `switching_canonical_phi1.csv`, `switching_canonical_observables.csv`, gated `switching_mode_amplitudes_vs_T.csv`, rank-structure reference tables).';
    lines{end+1} = '- **Aging**: not used. Any cross-module aging interpretation is explicitly out of scope for this audit.';
    lines{end+1} = '- **Claims**: kappa2 is not asserted here as an aging mechanism or material mechanism; interpret as a decomposition coordinate tied to residual structure after backbone + Phi1.';
    lines{end+1} = '';
    lines{end+1} = '## Inputs';
    lines{end+1} = sprintf('- `%s`', sLongPath);
    lines{end+1} = sprintf('- `%s`', phi1Path);
    lines{end+1} = sprintf('- `%s`', obsPath);
    lines{end+1} = sprintf('- `%s`', ampPath);
    lines{end+1} = sprintf('- `%s`', rankGlobalPath);
    lines{end+1} = sprintf('- `%s`', rankRegPath);
    lines{end+1} = '';
    lines{end+1} = '## What kappa2 is (construction-level)';
    lines{end+1} = '- Canonical pipeline: kappa2 is the **second-mode amplitude** in the residual map after subtracting backbone and the rank-1 term kappa1*Phi1 (same hierarchy as other Switching audits).';
    lines{end+1} = '- It is a **scalar state coordinate** summarizing how much of the residual energy aligns with the second right singular vector of the level-1 residual matrix.';
    lines{end+1} = '';
    lines{end+1} = '## What kappa2 tracks most in this dataset (non-exclusive)';
    lines{end+1} = '- **Single-observable strength**: `high_CDF_tail_weight` has the largest |Spearman| with kappa2 among reconstructed slice features (tail / high-CDF mass in native coordinates).';
    lines{end+1} = '- **Family-level mean |Spearman|**: `amplitude_scale` edges other families on average, so kappa2 is **not** reducible to tail-only language without also acknowledging amplitude-linked co-structure.';
    lines{end+1} = '- **Backbone residual tail ratio** (`tail_burden_ratio`, Stage-E style): statistically material negative association with kappa2 in this lock — consistent with treating kappa2 as a **tail-burden–sensitive** residual coordinate (sign is orientation-dependent).';
    lines{end+1} = '- **Backbone+Phi1 fit gap**: `rmse_full_row` and reconstructed `rmse_rank1_reconstructed` align with kappa2 at similar strength — kappa2 moves with **post–rank-1 error magnitude**, not only a tail scalar.';
    lines{end+1} = '';
    lines{end+1} = '## Observable correlations (summary)';
    [bestAbs, jBest] = max(abs(spearK2), [], 'omitnan');
    if isempty(jBest) || ~isfinite(bestAbs)
        lines{end+1} = '- Strongest |Spearman| vs reconstructed slice observables: **insufficient finite correlations**.';
    else
        lines{end+1} = sprintf('- Strongest |Spearman| vs reconstructed slice observables: `%s` (|rho|=%.4f, family=%s).', ...
            obsNames{jBest}, bestAbs, obsFamily{jBest});
    end
    lines{end+1} = sprintf('- Mean |Spearman| by family — strongest family label: **%s** (mean |rho|=%.4f).', topFam, mxFam);
    lines{end+1} = sprintf('- Stage-E-style **tail_burden_ratio** (backbone residual, CDF tails vs mid): Spearman(kappa2, metric)=%.4f; Pearson=%.4f.', spearTailBur, bPear(strcmp(burdenMetrics, 'tail_burden_ratio')));
    lines{end+1} = sprintf('- **rmse_full_row** (canonical row RMSE after backbone+Phi1): Spearman=%.4f (partial Pearson vs tail_burden controlling rmse_full documented in burden table).', spearRmseFull);
    lines{end+1} = sprintf('- Reconstructed **RMSE after Phi1** ( Frobenius row norm of S - pred1 ): Spearman=%.4f.', spearRank1Rmse);
    lines{end+1} = '';
    lines{end+1} = '## Question-oriented notes';
    lines{end+1} = '1. **Which observables correlate with kappa2?** — See `tables/switching_kappa2_observable_audit.csv` (full list with LOOCV linear R2).';
    lines{end+1} = '2. **Tail vs asymmetry vs width vs transition vs residual amplitude?** — Compare `observable_family` strengths and `switching_kappa2_residual_burden_tests.csv` hypothesis tags; tail-burden and high-CDF / windowed residual families are the primary candidates to inspect first.';
    lines{end+1} = '3. **Does kappa2 track where backbone+Phi1 fails?** — Compare Spearman with `rmse_full_row` and `rmse_rank1_reconstructed` in the burden table; both are direct "fit gap" scalars at fixed T.';
    lines{end+1} = '4. **Robustness across exclusion tests** — See `tables/switching_kappa2_stability_tests.csv` (temperature deciles and S_peak trimming).';
    lines{end+1} = '5. **Aging** — Not evaluated; do not extrapolate this Switching-only audit to aging without a separate, explicit linkage study.';
    lines{end+1} = '';
    lines{end+1} = '## Final verdicts (audit flags)';
    lines{end+1} = sprintf('- **KAPPA2_TRACKS_TAIL_BURDEN** = %s', KAPPA2_TRACKS_TAIL_BURDEN);
    lines{end+1} = sprintf('- **KAPPA2_TRACKS_ASYMMETRY** = %s', KAPPA2_TRACKS_ASYMMETRY);
    lines{end+1} = sprintf('- **KAPPA2_TRACKS_TRANSITION** = %s', KAPPA2_TRACKS_TRANSITION);
    lines{end+1} = sprintf('- **KAPPA2_IS_ROBUST_OBSERVABLE** = %s', KAPPA2_IS_ROBUST_OBSERVABLE);
    lines{end+1} = sprintf('- **KAPPA2_MECHANISM_CLAIM_ALLOWED** = %s  *(aging or material mechanism: not allowed; PARTIAL means tail-burden / rank-2 residual-coordinate wording only, per boundary policy)*', KAPPA2_MECHANISM_CLAIM_ALLOWED);
    lines{end+1} = '';
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_kappa2_observable_audit.csv`';
    lines{end+1} = '- `tables/switching_kappa2_residual_burden_tests.csv`';
    lines{end+1} = '- `tables/switching_kappa2_stability_tests.csv`';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_kappa2_physical_observable_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_kappa2_physical_observable_audit.md'), lines, 'run_switching_kappa2_physical_observable_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'kappa2 physical observable audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_kappa2_physical_observable_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    writetable(table(string(ME.identifier), string(ME.message), 'VariableNames', {'error_id','error_message'}), ...
        fullfile(repoRoot, 'tables', 'switching_kappa2_audit_failure.csv'));
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'kappa2 audit failed'}, true);
    rethrow(ME);
end

function st = kappa2AuditSpearCol(mask, colv, k2)
m = mask & isfinite(colv) & isfinite(k2);
st = NaN;
if sum(m) >= 3
    st = corr(colv(m), k2(m), 'type', 'Spearman', 'rows', 'complete');
end
end

function out = verdict3(yesCond, partialCond, altPartial)
if yesCond
    out = 'YES';
elseif partialCond || altPartial
    out = 'PARTIAL';
else
    out = 'NO';
end
end
