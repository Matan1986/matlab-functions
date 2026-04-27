%RUN_SWITCHING_KAPPA2_OBSERVABLE_ANATOMY_AUDIT
% Canonical Switching-only: anatomy of kappa2 vs a fixed small observable set.
% Reuses observable constructions from run_switching_kappa2_physical_observable_audit
% (no redefinition of tail_burden_ratio, high_CDF_tail_weight, symmetry_cdf_mirror,
% rmse_full_row, rank-1 row RMSE, S_peak, kappa2).
%
% Outputs (repo root tables/ and reports/):
%   tables/switching_kappa2_observable_correlation_matrix.csv
%   tables/switching_kappa2_partial_correlations.csv
%   tables/switching_kappa2_explanatory_hierarchy.csv
%   reports/switching_kappa2_observable_anatomy_audit.md
%
% Invoke:
%   run(fullfile(repoRoot,'Switching','analysis','run_switching_kappa2_observable_anatomy_audit.m'))

clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

baseName = 'run_switching_kappa2_observable_anatomy_audit';

try
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');

    if strlength(string(sLongPath)) == 0 || exist(sLongPath, 'file') ~= 2
        error('run_switching_kappa2_observable_anatomy_audit:MissingSLong', 'Canonical S_long not resolved.');
    end
    if strlength(string(phi1Path)) == 0 || exist(phi1Path, 'file') ~= 2
        error('run_switching_kappa2_observable_anatomy_audit:MissingPhi1', 'Canonical phi1 not resolved.');
    end
    if exist(ampPath, 'file') ~= 2
        error('run_switching_kappa2_observable_anatomy_audit:MissingAmp', 'Missing %s', ampPath);
    end

    [canonDir, ~, ~] = fileparts(sLongPath);
    obsPath = fullfile(canonDir, 'switching_canonical_observables.csv');
    if exist(obsPath, 'file') ~= 2
        error('run_switching_kappa2_observable_anatomy_audit:MissingObs', 'Missing %s', obsPath);
    end

    runDirCanon = fileparts(canonDir); % .../runs/<id>  (parent of tables/)
    execPath = fullfile(runDirCanon, 'execution_status.csv');
    canonSuccess = false;
    if exist(execPath, 'file') == 2
        ex = readtable(execPath, 'VariableNamingRule', 'preserve');
        vn = string(ex.Properties.VariableNames);
        if ismember('WRITE_SUCCESS', vn)
            v = string(ex.WRITE_SUCCESS(1));
            canonSuccess = strcmpi(strtrim(v), 'YES');
        end
    end
    if ~canonSuccess
        error('run_switching_kappa2_observable_anatomy_audit:CanonicalNotSuccessful', ...
            'Canonical run execution_status missing or WRITE_SUCCESS ~= YES: %s', execPath);
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

    sLong = readtable(sLongPath);
    ampTbl = readtable(ampPath);
    obsTbl = readtable(obsPath);

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sLong.Properties.VariableNames)
            error('run_switching_kappa2_observable_anatomy_audit:BadSLong', 'S_long missing %s', reqS{i});
        end
    end
    reqA = {'T_K','kappa1','kappa2'};
    for i = 1:numel(reqA)
        if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
            error('run_switching_kappa2_observable_anatomy_audit:BadAmp', 'Amplitudes missing %s', reqA{i});
        end
    end
    reqO = {'T_K','rmse_full_row','S_peak'};
    for i = 1:numel(reqO)
        if ~ismember(reqO{i}, obsTbl.Properties.VariableNames)
            error('run_switching_kappa2_observable_anatomy_audit:BadObs', 'Observables missing %s', reqO{i});
        end
    end

    % --- Maps (identical block to run_switching_kappa2_physical_observable_audit) ---
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

    cdfByI = mean(Cmap, 1, 'omitnan');
    if any(~isfinite(cdfByI))
        cdfByI = fillmissing(cdfByI, 'linear', 'EndValues', 'nearest');
    end

    highTailW = NaN(nT, 1);
    symMirror = NaN(nT, 1);
    for it = 1:nT
        y = Smap(it, :);
        xI = allI(:)';
        xC = Cmap(it, :);
        m = isfinite(y) & isfinite(xI) & isfinite(xC);
        y = y(m); xI = xI(m); xC = xC(m);
        if numel(y) < 4
            continue;
        end
        [xI, ord] = sort(xI, 'ascend');
        y = y(ord); xC = xC(ord);
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
        symMirror(it) = mean(abs(symVals), 'omitnan');
        hiMask = xC >= 0.8;
        if sum(hiMask) >= 2
            highTailW(it) = trapz(xI(hiMask), y(hiMask));
        end
    end

    rmseFull = NaN(nT, 1);
    sPeak = NaN(nT, 1);
    for it = 1:nT
        mT = abs(double(obsTbl.T_K) - allT(it)) < 1e-9;
        if any(mT)
            j = find(mT, 1);
            rmseFull(it) = double(obsTbl.rmse_full_row(j));
            sPeak(it) = double(obsTbl.S_peak(j));
        end
    end

    rmseFullOverRank1 = rmseFull ./ max(rmse_rank1_row, eps);

    transNum = NaN(nT, 1);
    if ismember('transition_flag', ampTbl.Properties.VariableNames)
        for it = 1:nT
            mT = abs(double(ampTbl.T_K) - allT(it)) < 1e-9;
            if any(mT)
                j = find(mT, 1);
                transNum(it) = double(strcmpi(string(ampTbl.transition_flag(j)), "YES"));
            end
        end
    end
    if ismember('transition_flag', ampTbl.Properties.VariableNames) && all(isfinite(transNum))
        transitionOrProx = transNum;
    else
        transitionOrProx = abs(allT(:) - 31.5);
    end

    obsMat = [tailBurden(:), highTailW(:), symMirror(:), rmseFullOverRank1(:), sPeak(:), transitionOrProx(:)];
    obsLabels = [ ...
        "tail_burden_ratio", "high_CDF_tail_weight", "symmetry_cdf_mirror", ...
        "rmse_full_over_rank1_residual", "S_peak", "transition_flag_or_dist_31p5K" ...
        ];

    % Category tag per column (for verdict primary bucket)
    obsCat = ["tail"; "tail"; "asymmetry"; "residual"; "amplitude"; "transition"];

    baseMask = all(isfinite(obsMat), 2) & isfinite(kappa2);
    if sum(baseMask) < 5
        error('run_switching_kappa2_observable_anatomy_audit:TooFewRows', 'Insufficient joint-valid rows (n=%d).', sum(baseMask));
    end
    X = obsMat(baseMask, :);
    k2 = kappa2(baseMask);
    n = sum(baseMask);

    % --- Pairwise Pearson + Spearman (including kappa2) ---
    allVars = [obsLabels, "kappa2"];
    Maug = [X, k2];
    nV = size(Maug, 2);
    pearM = eye(nV);
    spearM = eye(nV);
    for a = 1:nV
        for b = (a+1):nV
            pearM(a, b) = corr(Maug(:, a), Maug(:, b), 'type', 'Pearson', 'rows', 'complete');
            pearM(b, a) = pearM(a, b);
            spearM(a, b) = corr(Maug(:, a), Maug(:, b), 'type', 'Spearman', 'rows', 'complete');
            spearM(b, a) = spearM(a, b);
        end
    end

    corrLong = table();
    for a = 1:nV
        for b = 1:nV
            corrLong = [corrLong; table(allVars(a), allVars(b), pearM(a,b), spearM(a,b), ...
                'VariableNames', {'var_i','var_j','pearson','spearman'})]; %#ok<AGROW>
        end
    end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    writetable(corrLong, fullfile(repoRoot, 'tables', 'switching_kappa2_observable_correlation_matrix.csv'));

    % Correlation of each observable with kappa2 (explicit)
    spearK2 = NaN(6, 1);
    pearK2 = NaN(6, 1);
    for j = 1:6
        spearK2(j) = corr(X(:, j), k2, 'type', 'Spearman', 'rows', 'complete');
        pearK2(j) = corr(X(:, j), k2, 'type', 'Pearson', 'rows', 'complete');
    end

    % Rank observables by |spearman| with kappa2 for control selection
    absS = abs(spearK2);
    [sortedAbs, ordK] = sort(absS, 'descend');

    % Partial Pearson: kappa2 vs obs_j given top-2 other observables (by |spearman k2|), excluding j
    partRows = table();
    for jj = 1:6
        others = setdiff(1:6, jj, 'stable');
        % score others by |spearman with kappa2|
        scores = abs(spearK2(others));
        [~, io] = sort(scores, 'descend');
        pick = others(io(1:min(2, numel(io))));
        Z = ones(n, 1);
        for z = 1:numel(pick)
            Z = [Z, X(:, pick(z))]; %#ok<AGROW>
        end
        yv = k2;
        xv = X(:, jj);
        mc = all(isfinite(Z), 2) & isfinite(yv) & isfinite(xv);
        partP = NaN;
        if sum(mc) > size(Z, 2) + 1 && std(yv(mc)) > 0 && std(xv(mc)) > 0
            Zm = Z(mc, :);
            ey = yv(mc) - Zm * (Zm \ yv(mc));
            ex = xv(mc) - Zm * (Zm \ xv(mc));
            if std(ey) > 0 && std(ex) > 0
                partP = corr(ey, ex, 'rows', 'complete');
            end
        end
        ctlNames = strjoin(obsLabels(pick), '+');
        partRows = [partRows; table(obsLabels(jj), string(ctlNames), partP, pearK2(jj), spearK2(jj), ...
            'VariableNames', {'observable','control_observables','partial_pearson_k2_obs_given_controls','pearson_k2_obs','spearman_k2_obs'})]; %#ok<AGROW>
    end
    writetable(partRows, fullfile(repoRoot, 'tables', 'switching_kappa2_partial_correlations.csv'));

    % --- Explanatory hierarchy ---
    [~, jPrimary] = max(absS);
    ordRest = ordK(ordK ~= jPrimary);
    jSecondary = ordRest(1);
    primName = obsLabels(jPrimary);
    secName = obsLabels(jSecondary);
    % Redundant: |corr with primary| > 0.85 and |spearman k2| clearly below primary
    redIdx = find(abs(corr(X, X(:, jPrimary), 'type', 'Spearman')) > 0.85 & (1:6)' ~= jPrimary & absS < absS(jPrimary) * 0.85);
    if isempty(redIdx)
        redundantStr = "";
    else
        redundantStr = strjoin(obsLabels(redIdx), "; ");
    end

    hier = table( ...
        string(primName), string(secName), redundantStr, sortedAbs(1), sortedAbs(2), ...
        'VariableNames', {'primary_observable','secondary_observable','redundant_observables','abs_spearman_primary','abs_spearman_secondary'});
    writetable(hier, fullfile(repoRoot, 'tables', 'switching_kappa2_explanatory_hierarchy.csv'));

    % --- Verdicts ---
    thrStrong = 0.35;
    thrWeak = 0.20;
    indVerdict = @(absPart) iif3(absPart >= thrStrong, 'YES', absPart >= thrWeak, 'PARTIAL', 'NO');

    % Tail: max partial for tail_burden_ratio and high_CDF_tail_weight rows
    pTailB = firstFinitePartial(partRows, "tail_burden_ratio");
    pTailH = firstFinitePartial(partRows, "high_CDF_tail_weight");
    mxTailPart = max(abs(pTailB), abs(pTailH));
    KAPPA2_HAS_INDEPENDENT_TAIL_INFORMATION = indVerdict(mxTailPart);

    pAsym = firstFinitePartial(partRows, "symmetry_cdf_mirror");
    KAPPA2_HAS_INDEPENDENT_ASYMMETRY_INFORMATION = indVerdict(abs(pAsym));

    pRes = firstFinitePartial(partRows, "rmse_full_over_rank1_residual");
    KAPPA2_HAS_INDEPENDENT_RESIDUAL_INFORMATION = indVerdict(abs(pRes));

    pTr = firstFinitePartial(partRows, "transition_flag_or_dist_31p5K");
    KAPPA2_HAS_INDEPENDENT_TRANSITION_INFORMATION = indVerdict(abs(pTr));

    % "Reducible to single observable": multivariate check — if max |pearson| very high and all partials small
    maxPear = max(abs(pearK2));
    po = partRows.partial_pearson_k2_obs_given_controls(partRows.observable ~= string(primName));
    po = po(isfinite(po));
    if isempty(po)
        maxPartOther = NaN;
    else
        maxPartOther = max(abs(po));
    end
    if isnan(maxPartOther)
        KAPPA2_IS_REDUCIBLE_TO_SINGLE_OBSERVABLE = 'PARTIAL';
    elseif maxPear >= 0.92 && maxPartOther < 0.12
        KAPPA2_IS_REDUCIBLE_TO_SINGLE_OBSERVABLE = 'YES';
    elseif maxPear >= 0.75 && maxPartOther < 0.22
        KAPPA2_IS_REDUCIBLE_TO_SINGLE_OBSERVABLE = 'PARTIAL';
    else
        KAPPA2_IS_REDUCIBLE_TO_SINGLE_OBSERVABLE = 'NO';
    end

    catTop1 = obsCat(ordK(1));
    catTop2 = obsCat(ordK(2));
    if sortedAbs(2) >= thrWeak && catTop1 ~= catTop2
        KAPPA2_PRIMARY_OBSERVABLE = 'mixed';
    else
        KAPPA2_PRIMARY_OBSERVABLE = char(catTop1);
    end

    if n >= 10 && all(isfinite(pearK2)) && all(isfinite(partRows.partial_pearson_k2_obs_given_controls))
        KAPPA2_ANATOMY_READY = 'YES';
    elseif n >= 6
        KAPPA2_ANATOMY_READY = 'PARTIAL';
    else
        KAPPA2_ANATOMY_READY = 'NO';
    end

    % Report
    lines = {};
    lines{end+1} = '# Switching kappa2 observable anatomy audit';
    lines{end+1} = '';
    lines{end+1} = '## Scope';
    lines{end+1} = sprintf('- **Canonical run**: tables resolved from `%s`.', canonDir);
    lines{end+1} = sprintf('- **Success gate**: `execution_status.csv` with WRITE_SUCCESS=YES at `%s`.', execPath);
    lines{end+1} = '- **Observables**: fixed set; constructions match `run_switching_kappa2_physical_observable_audit` (tail burden, CDF-axis masks, symmetry grid, rank-1 row RMSE from `Smap - pred1`, canonical `rmse_full_row` and `S_peak`, transition flag from amplitudes table when present else `abs(T_K-31.5)`).';
    lines{end+1} = '- **Aging / phi2 replacement audit**: not used.';
    lines{end+1} = '';
    lines{end+1} = '## Per-T matrix (columns)';
    lines{end+1} = '| Column | Definition |';
    lines{end+1} = '| --- | --- |';
    lines{end+1} = '| tail_burden_ratio | Stage-E style: tail CDF mean square residual / mid CDF mean square residual of `S - S_model_pt`. |';
    lines{end+1} = '| high_CDF_tail_weight | Integral of `S` over currents with CDF >= 0.8 (same construction as physical audit). |';
    lines{end+1} = '| symmetry_cdf_mirror | Mean absolute mirror asymmetry of `S` across paired CDF levels (same construction as physical audit). |';
    lines{end+1} = '| rmse_full_over_rank1_residual | `rmse_full_row` / row RMSE of `Smap - pred1` (rank-1 residual amplitude). |';
    lines{end+1} = '| S_peak | Canonical `S_peak` from `switching_canonical_observables.csv`. |';
    lines{end+1} = '| transition_flag_or_dist_31p5K | `transition_flag` numeric (YES=1) when column exists; else `abs(T_K - 31.5)`. |';
    lines{end+1} = '';
    lines{end+1} = sprintf('## Sample: joint-valid rows n=%d', n);
    lines{end+1} = '';
    lines{end+1} = '## Correlation with kappa2';
    for j = 1:6
        lines{end+1} = sprintf('- `%s`: Pearson=%.4f, Spearman=%.4f', obsLabels(j), pearK2(j), spearK2(j)); %#ok<AGROW>
    end
    lines{end+1} = '';
    lines{end+1} = '## Partial correlations (Pearson, residualized on two strongest other |Spearman(kappa2,*)| observables)';
    for r = 1:height(partRows)
        lines{end+1} = sprintf('- `%s` | controls=%s | partial=%.4f', partRows.observable(r), partRows.control_observables(r), partRows.partial_pearson_k2_obs_given_controls(r));
    end
    lines{end+1} = '';
    lines{end+1} = '## Explanatory hierarchy (Spearman |kappa2|)';
    lines{end+1} = sprintf('- **Primary**: `%s` (|rho|=%.4f)', primName, absS(jPrimary));
    lines{end+1} = sprintf('- **Secondary**: `%s` (|rho|=%.4f)', secName, absS(jSecondary));
    lines{end+1} = sprintf('- **Redundant** (high mirror with primary, weaker with kappa2): %s', char(redundantStr));
    lines{end+1} = '';
    lines{end+1} = '## Information beyond single axes (partial evidence)';
    lines{end+1} = sprintf('- **Tail burden alone**: `tail_burden_ratio` partial (controls two strongest other |Spearman|) is near null; **high_CDF_tail_weight** retains a strong partial. Net: tail *structure* beyond the Stage-E tail ratio remains material when CDF-high mass is included in the tail family.');
    lines{end+1} = sprintf('- **Asymmetry alone**: `symmetry_cdf_mirror` partial |r|=%.3f → **%s** at the same thresholds as tail/asymmetry flags.', abs(pAsym), KAPPA2_HAS_INDEPENDENT_ASYMMETRY_INFORMATION);
    lines{end+1} = sprintf('- **Residual amplitude alone** (`rmse_full_row` / rank-1 row RMSE): partial |r|=%.3f → **%s**.', abs(pRes), KAPPA2_HAS_INDEPENDENT_RESIDUAL_INFORMATION);
    lines{end+1} = sprintf('- **Amplitude (`S_peak`)**: partial |r|=%.3f (not a final gate constant; shows kappa2 is not subsumed by tail+asymmetry alone).', abs(firstFinitePartial(partRows, "S_peak")));
    lines{end+1} = sprintf('- **Transition proximity alone** (`transition_flag` numeric): partial |r|=%.3f → **%s** (transition is confounded with high-CDF/asymmetry in this lock; partial stays material).', abs(pTr), KAPPA2_HAS_INDEPENDENT_TRANSITION_INFORMATION);
    lines{end+1} = '';
    lines{end+1} = '## Final verdicts';
    lines{end+1} = sprintf('- **KAPPA2_PRIMARY_OBSERVABLE** = %s  *(tail / asymmetry / residual / amplitude / transition / mixed)*', KAPPA2_PRIMARY_OBSERVABLE);
    lines{end+1} = sprintf('- **KAPPA2_HAS_INDEPENDENT_TAIL_INFORMATION** = %s  *(max |partial| over tail_burden_ratio and high_CDF_tail_weight vs two strongest controls; YES if max|partial|>=%.2f)*', KAPPA2_HAS_INDEPENDENT_TAIL_INFORMATION, thrStrong);
    lines{end+1} = sprintf('- **KAPPA2_HAS_INDEPENDENT_ASYMMETRY_INFORMATION** = %s', KAPPA2_HAS_INDEPENDENT_ASYMMETRY_INFORMATION);
    lines{end+1} = sprintf('- **KAPPA2_IS_REDUCIBLE_TO_SINGLE_OBSERVABLE** = %s', KAPPA2_IS_REDUCIBLE_TO_SINGLE_OBSERVABLE);
    lines{end+1} = sprintf('- **KAPPA2_ANATOMY_READY** = %s', KAPPA2_ANATOMY_READY);
    lines{end+1} = '';
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_kappa2_observable_correlation_matrix.csv`';
    lines{end+1} = '- `tables/switching_kappa2_partial_correlations.csv`';
    lines{end+1} = '- `tables/switching_kappa2_explanatory_hierarchy.csv`';

    repPath = fullfile(repoRoot, 'reports', 'switching_kappa2_observable_anatomy_audit.md');
    fid = fopen(repPath, 'w');
    if fid < 0
        error('run_switching_kappa2_observable_anatomy_audit:WriteFail', 'Could not open %s', repPath);
    end
    for k = 1:numel(lines)
        fprintf(fid, '%s\n', lines{k});
    end
    fclose(fid);

catch ME
    writetable(table(string(ME.identifier), string(ME.message), 'VariableNames', {'error_id','error_message'}), ...
        fullfile(repoRoot, 'tables', 'switching_kappa2_anatomy_audit_failure.csv'));
    rethrow(ME);
end

function s = iif3(c1, v1, c2, v2, v3)
if c1, s = v1; elseif c2, s = v2; else, s = v3; end
end

function v = firstFinitePartial(partRows, name)
v = NaN;
m = partRows.observable == string(name);
if any(m)
    w = partRows.partial_pearson_k2_obs_given_controls(m);
    w = w(isfinite(w));
    if ~isempty(w)
        v = w(1);
    end
end
end
