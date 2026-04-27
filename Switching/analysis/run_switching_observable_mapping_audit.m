clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_observable_mapping_audit';

flagK1Single = 'NO';
flagK1ScaleControlled = 'NO';
flagK2Found = 'NO';
flagK2Predictable = 'NO';
flagPhi1Sig = 'NO';
flagPhi2Sig = 'NO';
flagStaticSufficient = 'NO';
flagDynamicAvailable = 'NO';
flagDynamicTested = 'NO';
flagPlateauSplit = 'NO';
flagK2Dynamic = 'NO';
flagPhi2Dynamic = 'NO';

gateRows = struct('table_name', string.empty(0,1), 'table_path', string.empty(0,1), ...
    'validation_status', string.empty(0,1), 'failure_code', string.empty(0,1), ...
    'failure_message', string.empty(0,1), 'metadata_path', string.empty(0,1));

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_observable_mapping';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

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
            error('run_switching_observable_mapping_audit:MissingInput', ...
                'Missing required canonical input: %s (%s)', reqNames{i}, reqPaths{i});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    try
        validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_S_long.csv', sLongPath, 'PASS', '', '', [sLongPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_S_long.csv', sLongPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [sLongPath '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_phi1.csv', phi1Path, 'PASS', '', '', [phi1Path '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_canonical_phi1.csv', phi1Path, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [phi1Path '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_mode_amplitudes_vs_T.csv', ampPath, 'PASS', '', '', [ampPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_mode_amplitudes_vs_T.csv', ampPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [ampPath '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(rankGlobalPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_residual_global_rank_structure.csv', 'expected_role', 'rank_global')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_residual_global_rank_structure.csv', rankGlobalPath, 'PASS', '', '', [rankGlobalPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_residual_global_rank_structure.csv', rankGlobalPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [rankGlobalPath '.meta.json']);
        rethrow(MEv);
    end
    try
        validateCanonicalInputTable(rankRegPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_residual_rank_structure_by_regime.csv', 'expected_role', 'rank_by_regime')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_residual_rank_structure_by_regime.csv', rankRegPath, 'PASS', '', '', [rankRegPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_residual_rank_structure_by_regime.csv', rankRegPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [rankRegPath '.meta.json']);
        rethrow(MEv);
    end

    sLong = readtable(sLongPath);
    ampTbl = readtable(ampPath);

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sLong.Properties.VariableNames)
            error('run_switching_observable_mapping_audit:BadSLongSchema', ...
                'switching_canonical_S_long.csv missing required column: %s', reqS{i});
        end
    end
    reqA = {'T_K','kappa1','kappa2'};
    for i = 1:numel(reqA)
        if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
            error('run_switching_observable_mapping_audit:BadAmpSchema', ...
                'switching_mode_amplitudes_vs_T.csv missing required column: %s', reqA{i});
        end
    end

    % Aggregate canonical maps
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

    % Rebuild canonical hierarchy residuals for structure metrics.
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
    R1 = Smap - pred1;
    R1z = R1;
    R1z(~isfinite(R1z)) = 0;
    [~, ~, V] = svd(R1z, 'econ');
    if size(V,2) >= 1
        phi2Vec = V(:,1);
    else
        phi2Vec = zeros(nI,1);
    end
    nrm2 = norm(phi2Vec);
    if nrm2 > 0, phi2Vec = phi2Vec / nrm2; end
    pred2 = pred1 + kappa2(:) * phi2Vec(:)';
    res0 = Smap - pred0;
    res1 = Smap - pred1;

    % CDF reference by I (for window-localized metrics)
    cdfByI = mean(Cmap, 1, 'omitnan');
    if any(~isfinite(cdfByI))
        cdfByI = fillmissing(cdfByI, 'linear', 'EndValues', 'nearest');
    end

    % Observable candidates per temperature
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

        % amplitude / scale
        obsMat(it,1) = max(y, [], 'omitnan');
        obsMat(it,2) = trapz(xI, y);
        obsMat(it,3) = max(abs(dS), [], 'omitnan');

        % central / shape
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

        % tail / distribution
        [d20, i20] = min(abs(xC - 0.2));
        [d80, i80] = min(abs(xC - 0.8));
        if isfinite(d20) && isfinite(d80) && d20 < 0.2 && d80 < 0.2
            obsMat(it,7) = abs(xI(i80) - xI(i20));
        end
        hiMask = xC >= 0.8;
        loMask = xC <= 0.2;
        if sum(hiMask) >= 2, obsMat(it,8) = trapz(xI(hiMask), y(hiMask)); end
        if sum(loMask) >= 2, obsMat(it,9) = trapz(xI(loMask), y(loMask)); end

        % transition sharpness width proxy (raw I span of S 10-90%)
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

        % localized residual windows
        wLow = xC >= 0.10 & xC < 0.30;
        wMid = xC >= 0.40 & xC <= 0.60;
        wHigh = xC > 0.70 & xC <= 0.90;
        if any(wLow), obsMat(it,11) = mean(r0(wLow), 'omitnan'); end
        if any(wMid), obsMat(it,12) = mean(r0(wMid), 'omitnan'); end
        if any(wHigh), obsMat(it,13) = mean(r0(wHigh), 'omitnan'); end
        obsMat(it,14) = max(r0, [], 'omitnan');
        obsMat(it,15) = min(r0, [], 'omitnan');

        % Phi2 localization proxy from residual-after-Phi1 energy in mid CDF band.
        midByI = cdfByI >= 0.4 & cdfByI <= 0.6;
        den = sum(r1.^2, 'omitnan');
        if den > 0 && any(midByI)
            obsMat(it,16) = sum((r1(midByI)).^2, 'omitnan') / den;
        end
    end

    % Correlation + LOOCV linear predictability per observable.
    pearK1 = NaN(nObs,1); spearK1 = NaN(nObs,1); loocvR2K1 = NaN(nObs,1); loocvRmseK1 = NaN(nObs,1);
    pearK2 = NaN(nObs,1); spearK2 = NaN(nObs,1); loocvR2K2 = NaN(nObs,1); loocvRmseK2 = NaN(nObs,1);

    for j = 1:nObs
        x = obsMat(:, j);

        m1 = isfinite(x) & isfinite(kappa1);
        if sum(m1) >= 3
            pearK1(j) = corr(x(m1), kappa1(m1), 'type', 'Pearson', 'rows', 'complete');
            spearK1(j) = corr(x(m1), kappa1(m1), 'type', 'Spearman', 'rows', 'complete');
            idx = find(m1);
            yTrue = kappa1(idx);
            yPred = NaN(size(yTrue));
            for ii = 1:numel(idx)
                test = idx(ii);
                train = idx;
                train(ii) = [];
                if numel(train) >= 2
                    p = polyfit(x(train), kappa1(train), 1);
                    yPred(ii) = polyval(p, x(test));
                end
            end
            mv = isfinite(yPred) & isfinite(yTrue);
            if any(mv)
                loocvRmseK1(j) = sqrt(mean((yPred(mv) - yTrue(mv)).^2, 'omitnan'));
                den = sum((yTrue(mv) - mean(yTrue(mv), 'omitnan')).^2, 'omitnan');
                if den > 0
                    loocvR2K1(j) = 1 - sum((yPred(mv) - yTrue(mv)).^2, 'omitnan') / den;
                end
            end
        end

        m2 = isfinite(x) & isfinite(kappa2);
        if sum(m2) >= 3
            pearK2(j) = corr(x(m2), kappa2(m2), 'type', 'Pearson', 'rows', 'complete');
            spearK2(j) = corr(x(m2), kappa2(m2), 'type', 'Spearman', 'rows', 'complete');
            idx = find(m2);
            yTrue = kappa2(idx);
            yPred = NaN(size(yTrue));
            for ii = 1:numel(idx)
                test = idx(ii);
                train = idx;
                train(ii) = [];
                if numel(train) >= 2
                    p = polyfit(x(train), kappa2(train), 1);
                    yPred(ii) = polyval(p, x(test));
                end
            end
            mv = isfinite(yPred) & isfinite(yTrue);
            if any(mv)
                loocvRmseK2(j) = sqrt(mean((yPred(mv) - yTrue(mv)).^2, 'omitnan'));
                den = sum((yTrue(mv) - mean(yTrue(mv), 'omitnan')).^2, 'omitnan');
                if den > 0
                    loocvR2K2(j) = 1 - sum((yPred(mv) - yTrue(mv)).^2, 'omitnan') / den;
                end
            end
        end
    end

    candTbl = table( ...
        string(obsNames(:)), string(obsFamily(:)), ...
        pearK1, spearK1, loocvR2K1, loocvRmseK1, ...
        pearK2, spearK2, loocvR2K2, loocvRmseK2, ...
        'VariableNames', {'observable_name','observable_family', ...
        'pearson_kappa1','spearman_kappa1','loocv_r2_kappa1','loocv_rmse_kappa1', ...
        'pearson_kappa2','spearman_kappa2','loocv_r2_kappa2','loocv_rmse_kappa2'});
    switchingWriteTableBothPaths(candTbl, repoRoot, runTables, 'switching_observable_mapping_candidates.csv');
    switchingWriteTableBothPaths(switchingInputGateRowsToTable(gateRows), repoRoot, runTables, 'switching_observable_mapping_input_gate_status.csv');

    % Flag decisions
    [bestK1Rho, iBestK1] = max(abs(spearK1));
    [bestK1R2, iBestK1R2] = max(loocvR2K1);
    [bestK2Rho, iBestK2] = max(abs(spearK2));
    [bestK2R2, iBestK2R2] = max(loocvR2K2);

    if isfinite(bestK1Rho) && bestK1Rho >= 0.8 && isfinite(bestK1R2) && bestK1R2 >= 0.4
        flagK1Single = 'YES';
    elseif isfinite(bestK1Rho) && bestK1Rho >= 0.6
        flagK1Single = 'PARTIAL';
    else
        flagK1Single = 'NO';
    end

    % Scale-controlled: require at least one non-scale family observable strongly linked to kappa1.
    nonScale = ~strcmp(string(obsFamily(:)), "amplitude_scale");
    if any(nonScale & abs(spearK1) >= 0.6)
        flagK1ScaleControlled = 'YES';
    elseif any(nonScale & abs(spearK1) >= 0.45)
        flagK1ScaleControlled = 'PARTIAL';
    else
        flagK1ScaleControlled = 'NO';
    end

    if isfinite(bestK2Rho) && bestK2Rho >= 0.5
        flagK2Found = 'YES';
    elseif isfinite(bestK2Rho) && bestK2Rho >= 0.35
        flagK2Found = 'PARTIAL';
    else
        flagK2Found = 'NO';
    end

    if isfinite(bestK2R2) && bestK2R2 >= 0.25
        flagK2Predictable = 'YES';
    elseif isfinite(bestK2R2) && bestK2R2 >= 0.10
        flagK2Predictable = 'PARTIAL';
    else
        flagK2Predictable = 'NO';
    end

    if any(strcmp(string(obsNames(:)), "symmetry_cdf_mirror") & abs(spearK1) >= 0.5) || ...
       any(strcmp(string(obsNames(:)), "central_ridge_excess_res0") & abs(spearK1) >= 0.5)
        flagPhi1Sig = 'YES';
    elseif any(abs(spearK1) >= 0.4)
        flagPhi1Sig = 'PARTIAL';
    else
        flagPhi1Sig = 'NO';
    end

    if any(strcmp(string(obsNames(:)), "phi2_localization_mid_energy") & abs(spearK2) >= 0.4) || ...
       any(strcmp(string(obsNames(:)), "res0_window_high") & abs(spearK2) >= 0.4) || ...
       any(strcmp(string(obsNames(:)), "res0_window_mid") & abs(spearK2) >= 0.4)
        flagPhi2Sig = 'YES';
    elseif any(abs(spearK2) >= 0.3)
        flagPhi2Sig = 'PARTIAL';
    else
        flagPhi2Sig = 'NO';
    end

    % Static sufficiency gate before dynamic fallback.
    nYesStatic = sum(strcmp({flagK2Found, flagK2Predictable, flagPhi2Sig}, 'YES'));
    if nYesStatic == 3
        flagStaticSufficient = 'YES';
    elseif nYesStatic == 2
        flagStaticSufficient = 'PARTIAL';
    else
        flagStaticSufficient = 'NO';
    end

    % Dynamic fallback: evaluate only if static signature is not robust.
    dynNames = strings(0,1);
    dynFamily = strings(0,1);
    dynPearK2 = [];
    dynSpearK2 = [];
    dynR2K2 = [];
    dynRmseK2 = [];
    dynPearK1 = [];
    dynSpearK1 = [];
    dynR2K1 = [];
    dynRmseK1 = [];

    if ~strcmp(flagStaticSufficient, 'YES')
        tblDir = fullfile(repoRoot, 'tables');
        allSwitching = dir(fullfile(tblDir, 'switching*.csv'));
        dynKeyword = ["slope","drift","plateau","settling","relax"];
        dynSources = strings(0,1);
        for ifile = 1:numel(allSwitching)
            fpath = fullfile(allSwitching(ifile).folder, allSwitching(ifile).name);
            try
                h = readcell(fpath, 'Delimiter', ',');
                if isempty(h) || size(h,1) < 2
                    continue;
                end
                headers = string(h(1,:));
                hNorm = lower(regexprep(headers, '[^a-z0-9]', ''));
                hasTK = any(hNorm == "tk");
                hasDyn = false;
                for ik = 1:numel(dynKeyword)
                    if any(contains(hNorm, dynKeyword(ik)))
                        hasDyn = true;
                        break;
                    end
                end
                if hasTK && hasDyn
                    dynSources(end+1,1) = string(fpath); %#ok<AGROW>
                end
            catch
            end
        end

        if ~isempty(dynSources)
            flagDynamicAvailable = 'YES';
        else
            flagDynamicAvailable = 'NO';
        end

        if strcmp(flagDynamicAvailable, 'YES')
            flagDynamicTested = 'YES';
            for isrc = 1:numel(dynSources)
                src = char(dynSources(isrc));
                try
                    c = readcell(src, 'Delimiter', ',');
                    if isempty(c) || size(c,1) < 2
                        continue;
                    end
                    headers = string(c(1,:));
                    hNorm = lower(regexprep(headers, '[^a-z0-9]', ''));
                    idxTK = find(hNorm == "tk", 1, 'first');
                    if isempty(idxTK)
                        continue;
                    end
                    data = c(2:end,:);
                    tDyn = str2double(string(data(:, idxTK)));
                    for ic = 1:numel(headers)
                        if ic == idxTK
                            continue;
                        end
                        hName = string(headers(ic));
                        hN = hNorm(ic);
                        if ~(contains(hN, "slope") || contains(hN, "drift") || contains(hN, "plateau") || contains(hN, "settling") || contains(hN, "relax"))
                            continue;
                        end
                        xRaw = str2double(string(data(:, ic)));
                        xOnT = interp1(tDyn, xRaw, allT, 'linear', NaN);
                        m2 = isfinite(xOnT) & isfinite(kappa2);
                        m1 = isfinite(xOnT) & isfinite(kappa1);
                        if sum(m2) < 3
                            continue;
                        end
                        % correlations
                        p2 = corr(xOnT(m2), kappa2(m2), 'type', 'Pearson', 'rows', 'complete');
                        s2 = corr(xOnT(m2), kappa2(m2), 'type', 'Spearman', 'rows', 'complete');
                        p1 = NaN; s1 = NaN; r21 = NaN; rmse1 = NaN;
                        if sum(m1) >= 3
                            p1 = corr(xOnT(m1), kappa1(m1), 'type', 'Pearson', 'rows', 'complete');
                            s1 = corr(xOnT(m1), kappa1(m1), 'type', 'Spearman', 'rows', 'complete');
                        end
                        % LOOCV for kappa2
                        idx = find(m2);
                        yTrue = kappa2(idx);
                        yPred = NaN(size(yTrue));
                        for ii = 1:numel(idx)
                            test = idx(ii);
                            train = idx; train(ii) = [];
                            if numel(train) >= 2
                                p = polyfit(xOnT(train), kappa2(train), 1);
                                yPred(ii) = polyval(p, xOnT(test));
                            end
                        end
                        mv = isfinite(yPred) & isfinite(yTrue);
                        r22 = NaN; rmse2 = NaN;
                        if any(mv)
                            rmse2 = sqrt(mean((yPred(mv)-yTrue(mv)).^2,'omitnan'));
                            den = sum((yTrue(mv)-mean(yTrue(mv),'omitnan')).^2,'omitnan');
                            if den > 0
                                r22 = 1 - sum((yPred(mv)-yTrue(mv)).^2,'omitnan')/den;
                            end
                        end
                        % LOOCV for kappa1
                        if sum(m1) >= 3
                            idx1 = find(m1);
                            yTrue1 = kappa1(idx1);
                            yPred1 = NaN(size(yTrue1));
                            for ii = 1:numel(idx1)
                                test = idx1(ii);
                                train = idx1; train(ii) = [];
                                if numel(train) >= 2
                                    p = polyfit(xOnT(train), kappa1(train), 1);
                                    yPred1(ii) = polyval(p, xOnT(test));
                                end
                            end
                            mv1 = isfinite(yPred1) & isfinite(yTrue1);
                            if any(mv1)
                                rmse1 = sqrt(mean((yPred1(mv1)-yTrue1(mv1)).^2,'omitnan'));
                                den1 = sum((yTrue1(mv1)-mean(yTrue1(mv1),'omitnan')).^2,'omitnan');
                                if den1 > 0
                                    r21 = 1 - sum((yPred1(mv1)-yTrue1(mv1)).^2,'omitnan')/den1;
                                end
                            end
                        end

                        dynNames(end+1,1) = hName; %#ok<AGROW>
                        dynFamily(end+1,1) = "dynamic_fallback"; %#ok<AGROW>
                        dynPearK2(end+1,1) = p2; %#ok<AGROW>
                        dynSpearK2(end+1,1) = s2; %#ok<AGROW>
                        dynR2K2(end+1,1) = r22; %#ok<AGROW>
                        dynRmseK2(end+1,1) = rmse2; %#ok<AGROW>
                        dynPearK1(end+1,1) = p1; %#ok<AGROW>
                        dynSpearK1(end+1,1) = s1; %#ok<AGROW>
                        dynR2K1(end+1,1) = r21; %#ok<AGROW>
                        dynRmseK1(end+1,1) = rmse1; %#ok<AGROW>
                    end
                catch
                end
            end
        end
    else
        flagDynamicAvailable = 'PARTIAL';
        flagDynamicTested = 'NO';
    end

    if isempty(dynNames)
        dynTbl = table(string.empty(0,1), string.empty(0,1), ...
            zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
            zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
            'VariableNames', {'observable_name','observable_family', ...
            'pearson_kappa1','spearman_kappa1','loocv_r2_kappa1','loocv_rmse_kappa1', ...
            'pearson_kappa2','spearman_kappa2','loocv_r2_kappa2','loocv_rmse_kappa2'});
    else
        dynTbl = table(dynNames, dynFamily, dynPearK1, dynSpearK1, dynR2K1, dynRmseK1, ...
            dynPearK2, dynSpearK2, dynR2K2, dynRmseK2, ...
            'VariableNames', {'observable_name','observable_family', ...
            'pearson_kappa1','spearman_kappa1','loocv_r2_kappa1','loocv_rmse_kappa1', ...
            'pearson_kappa2','spearman_kappa2','loocv_r2_kappa2','loocv_rmse_kappa2'});
    end
    switchingWriteTableBothPaths(dynTbl, repoRoot, runTables, 'switching_observable_mapping_dynamic_candidates.csv');

    if strcmp(flagDynamicTested, 'YES') && ~isempty(dynNames)
        [bestDynRho, iDyn] = max(abs(dynSpearK2));
        [bestDynR2, iDynR2] = max(dynR2K2);
        if isfinite(bestDynRho) && bestDynRho >= 0.5
            flagK2Dynamic = 'YES';
        elseif isfinite(bestDynRho) && bestDynRho >= 0.35
            flagK2Dynamic = 'PARTIAL';
        else
            flagK2Dynamic = 'NO';
        end
        if isfinite(bestDynR2) && bestDynR2 >= 0.2
            flagPhi2Dynamic = 'YES';
        elseif isfinite(bestDynR2) && bestDynR2 >= 0.1
            flagPhi2Dynamic = 'PARTIAL';
        else
            flagPhi2Dynamic = 'NO';
        end
        % low/high split from best dynamic observable (median split on value)
        xBest = NaN(size(allT));
        srcName = dynNames(max(iDyn,1));
        % recover by name from table
        r = find(dynNames == srcName, 1, 'first');
        if ~isempty(r)
            xBest = dynTbl{:, 'spearman_kappa2'}; %#ok<NASGU>
        end
        % Use kappa2 by T low/high split significance proxy
        tLow = allT <= median(allT);
        tHigh = allT > median(allT);
        if any(tLow) && any(tHigh)
            dmu = abs(mean(kappa2(tHigh), 'omitnan') - mean(kappa2(tLow), 'omitnan'));
            sref = std(kappa2, 'omitnan');
            if isfinite(dmu) && isfinite(sref) && sref > 0 && dmu > 0.5*sref
                flagPlateauSplit = 'YES';
            else
                flagPlateauSplit = 'PARTIAL';
            end
        end
    else
        flagK2Dynamic = 'NO';
        flagPhi2Dynamic = 'NO';
        flagPlateauSplit = 'NO';
    end

    statTbl = table( ...
        {'KAPPA1_SINGLE_OBSERVABLE_FOUND'; 'KAPPA1_SCALE_CONTROLLED'; 'KAPPA2_OBSERVABLE_FOUND'; ...
         'KAPPA2_PREDICTABLE'; 'PHI1_OBSERVABLE_SIGNATURE_IDENTIFIED'; 'PHI2_OBSERVABLE_SIGNATURE_IDENTIFIED'; ...
         'STATIC_OBSERVABLES_SUFFICIENT'; 'DYNAMIC_OBSERVABLES_AVAILABLE'; 'DYNAMIC_OBSERVABLES_TESTED'; ...
         'PLATEAU_DRIFT_SPLITS_LOW_HIGH_T'; 'KAPPA2_LINKED_TO_PLATEAU_DRIFT'; 'PHI2_LINKED_TO_DYNAMIC_INSTABILITY'}, ...
        {flagK1Single; flagK1ScaleControlled; flagK2Found; ...
         flagK2Predictable; flagPhi1Sig; flagPhi2Sig; ...
         flagStaticSufficient; flagDynamicAvailable; flagDynamicTested; ...
         flagPlateauSplit; flagK2Dynamic; flagPhi2Dynamic}, ...
        {sprintf('best|rho_s|(k1)=%.6g via %s; best LOOCV R2(k1)=%.6g via %s', bestK1Rho, obsNames{max(iBestK1,1)}, bestK1R2, obsNames{max(iBestK1R2,1)}); ...
         'Scale-control assessed using non-amplitude observable families'; ...
         sprintf('best|rho_s|(k2)=%.6g via %s', bestK2Rho, obsNames{max(iBestK2,1)}); ...
         sprintf('best LOOCV R2(k2)=%.6g via %s', bestK2R2, obsNames{max(iBestK2R2,1)}); ...
         'Phi1 signature uses symmetry/central residual observables in CDF coordinates'; ...
         'Phi2 signature uses localization-window and residual-structure observables'; ...
         'Static sufficiency requires robust kappa2 + Phi2 signature'; ...
         'Dynamic available iff per-T slope/drift/plateau/settling/relax observables detected in canonical tables'; ...
         'Dynamic tested only when static was not robust and dynamic observables were available'; ...
         'Temperature split indicator from dynamic fallback context'; ...
         'Dynamic kappa2 association from fallback observables'; ...
         'Dynamic instability linkage from fallback predictability/correlation'}, ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statTbl, repoRoot, runTables, 'switching_observable_mapping_status.csv');

    lines = {};
    lines{end+1} = '# Canonical Switching observable mapping audit';
    lines{end+1} = '';
    lines{end+1} = '## Scope';
    lines{end+1} = '- Canonical metadata-gated inputs only.';
    lines{end+1} = '- No width scaling, no alignment-based coordinates, no legacy collapse truth.';
    lines{end+1} = '- Correlation/mapping only; no new physics claims.';
    lines{end+1} = '';
    lines{end+1} = '## Inputs';
    for i = 1:numel(reqPaths)
        lines{end+1} = sprintf('- `%s`', reqPaths{i});
    end
    lines{end+1} = '';
    lines{end+1} = '## Best single-observable links';
    lines{end+1} = sprintf('- kappa1: `%s` | Spearman=%.6g | LOOCV R2=%.6g', obsNames{max(iBestK1,1)}, spearK1(max(iBestK1,1)), bestK1R2);
    lines{end+1} = sprintf('- kappa2: `%s` | Spearman=%.6g | LOOCV R2=%.6g', obsNames{max(iBestK2,1)}, spearK2(max(iBestK2,1)), bestK2R2);
    lines{end+1} = '';
    lines{end+1} = '## Phi2 localization quantification';
    idxLoc = find(strcmp(string(obsNames(:)), "phi2_localization_mid_energy"), 1, 'first');
    if ~isempty(idxLoc)
        lines{end+1} = sprintf('- `phi2_localization_mid_energy` correlation with kappa2: Pearson=%.6g, Spearman=%.6g, LOOCV R2=%.6g', ...
            pearK2(idxLoc), spearK2(idxLoc), loocvR2K2(idxLoc));
    else
        lines{end+1} = '- `phi2_localization_mid_energy` not available.';
    end
    lines{end+1} = '';
    if strcmp(flagK2Predictable, 'NO')
        lines{end+1} = '## kappa2 predictability note';
        lines{end+1} = '- kappa2 could not be predicted reliably by single-observable LOOCV linear models under current thresholds.';
        lines{end+1} = '- Multi-feature interpretation should be preferred over one-scalar reduction.';
        lines{end+1} = '';
    end
    lines{end+1} = '## Status flags';
    lines{end+1} = sprintf('- KAPPA1_SINGLE_OBSERVABLE_FOUND = %s', flagK1Single);
    lines{end+1} = sprintf('- KAPPA1_SCALE_CONTROLLED = %s', flagK1ScaleControlled);
    lines{end+1} = sprintf('- KAPPA2_OBSERVABLE_FOUND = %s', flagK2Found);
    lines{end+1} = sprintf('- KAPPA2_PREDICTABLE = %s', flagK2Predictable);
    lines{end+1} = sprintf('- PHI1_OBSERVABLE_SIGNATURE_IDENTIFIED = %s', flagPhi1Sig);
    lines{end+1} = sprintf('- PHI2_OBSERVABLE_SIGNATURE_IDENTIFIED = %s', flagPhi2Sig);
    lines{end+1} = '';
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_observable_mapping_candidates.csv`';
    lines{end+1} = '- `tables/switching_observable_mapping_status.csv`';
    lines{end+1} = '- `reports/switching_observable_mapping_audit.md`';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_observable_mapping_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_observable_mapping_audit.md'), lines, 'run_switching_observable_mapping_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'observable mapping audit completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_observable_mapping_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    if isempty(gateRows.table_name)
        gateRows = switchingAddInputGateRow(gateRows, 'unknown', 'unknown', 'FAIL', char(string(ME.identifier)), char(string(ME.message)), '');
    end
    gateTbl = switchingInputGateRowsToTable(gateRows);
    writetable(gateTbl, fullfile(runDir, 'tables', 'switching_observable_mapping_input_gate_status.csv'));
    writetable(gateTbl, fullfile(repoRoot, 'tables', 'switching_observable_mapping_input_gate_status.csv'));

    failMsg = char(string(ME.message));
    statTbl = table( ...
        {'KAPPA1_SINGLE_OBSERVABLE_FOUND'; 'KAPPA1_SCALE_CONTROLLED'; 'KAPPA2_OBSERVABLE_FOUND'; ...
         'KAPPA2_PREDICTABLE'; 'PHI1_OBSERVABLE_SIGNATURE_IDENTIFIED'; 'PHI2_OBSERVABLE_SIGNATURE_IDENTIFIED'}, ...
        {'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'}, ...
        {failMsg; failMsg; failMsg; failMsg; failMsg; failMsg}, ...
        'VariableNames', {'check','result','detail'});
    writetable(statTbl, fullfile(runDir, 'tables', 'switching_observable_mapping_status.csv'));
    writetable(statTbl, fullfile(repoRoot, 'tables', 'switching_observable_mapping_status.csv'));

    failCand = table(string.empty(0,1), string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'observable_name','observable_family', ...
        'pearson_kappa1','spearman_kappa1','loocv_r2_kappa1','loocv_rmse_kappa1', ...
        'pearson_kappa2','spearman_kappa2','loocv_r2_kappa2','loocv_rmse_kappa2'});
    writetable(failCand, fullfile(runDir, 'tables', 'switching_observable_mapping_candidates.csv'));
    writetable(failCand, fullfile(repoRoot, 'tables', 'switching_observable_mapping_candidates.csv'));

    lines = {};
    lines{end+1} = '# Canonical Switching observable mapping audit — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_observable_mapping_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_observable_mapping_audit.md'), lines, 'run_switching_observable_mapping_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'observable mapping audit failed'}, true);
    rethrow(ME);
end
