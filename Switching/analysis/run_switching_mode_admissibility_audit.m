clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_mode_admissibility_audit';

% Required status flags
fPhi1Admissible = 'NO';
fPhi2Admissible = 'NO';
fMode1Dominant = 'NO';
fMode2Significant = 'NO';
fMode1Stable = 'NO';
fMode2Stable = 'NO';
fMode2AboveNull = 'NO';
fPhi2EdgeDominated = 'NO';
fPhi2TailDominated = 'NO';
fPhi2SurvivesTail = 'NO';
fPhi2SurvivesHighTExcl = 'NO';
fPhi2SurvivesTransExcl = 'NO';
fPhi1InterpCDF = 'NO';
fPhi2InterpCDF = 'NO';
fReadyPhaseD = 'NO';

gateRows = struct('table_name', string.empty(0,1), 'table_path', string.empty(0,1), ...
    'validation_status', string.empty(0,1), 'failure_code', string.empty(0,1), ...
    'failure_message', string.empty(0,1), 'metadata_path', string.empty(0,1));

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_mode_admissibility';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    runFigures = fullfile(runDir, 'figures');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(runFigures, 'dir') ~= 7, mkdir(runFigures); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    % Phase-A and Phase-B allowed inputs
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    phaseBPath = fullfile(repoRoot, 'tables', 'switching_backbone_validity_status.csv');

    reqPaths = {sLongPath, phi1Path, ampPath, phaseBPath};
    reqNames = {'switching_canonical_S_long.csv', 'switching_canonical_phi1.csv', ...
        'switching_mode_amplitudes_vs_T.csv', 'switching_backbone_validity_status.csv'};
    for i = 1:numel(reqPaths)
        if strlength(string(reqPaths{i})) == 0 || exist(reqPaths{i}, 'file') ~= 2
            error('run_switching_mode_admissibility_audit:MissingInput', ...
                'Missing required input: %s (%s)', reqNames{i}, reqPaths{i});
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
        validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
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

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);
    phaseBLines = readlines(phaseBPath);

    if ~all(ismember({'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt','PT_pdf'}, sLong.Properties.VariableNames))
        error('run_switching_mode_admissibility_audit:BadSchema', 'sLong schema missing required columns.');
    end
    phiVars = string(phi1Tbl.Properties.VariableNames);
    hasPhi1 = any(strcmpi(phiVars, "phi1"));
    if ~ismember('current_mA', phi1Tbl.Properties.VariableNames) || ~hasPhi1
        error('run_switching_mode_admissibility_audit:BadSchema', 'phi1 schema missing current_mA/Phi1.');
    end
    if ~all(ismember({'T_K','kappa1','kappa2'}, ampTbl.Properties.VariableNames))
        error('run_switching_mode_admissibility_audit:BadSchema', 'mode amplitude schema missing T_K/kappa1/kappa2.');
    end

    % Enforce Phase-B restrictions (robust CSV parse from first 2 columns)
    bCheck = strings(0,1);
    bRes = strings(0,1);
    for il = 1:numel(phaseBLines)
        ln = strtrim(string(phaseBLines(il)));
        if ln == "" || startsWith(lower(ln), "check,result")
            continue;
        end
        tok = regexp(char(ln), '^([^,]+),([^,]+),?.*$', 'tokens', 'once');
        if ~isempty(tok)
            bCheck(end+1,1) = string(tok{1}); %#ok<SAGROW>
            bRes(end+1,1) = string(tok{2}); %#ok<SAGROW>
        end
    end
    bCheckNorm = upper(strtrim(bCheck));
    bResNorm = upper(strtrim(bRes));
    bBackbone = "";
    bTail = "";
    bHighT = "";
    bTrans = "";
    iBack = find(contains(bCheckNorm, "BACKBONE_VALID_FOR_RESIDUAL_ANALYSIS"), 1);
    iTail = find(contains(bCheckNorm, "BACKBONE_FAILURE_LOCALIZED_IN_HIGH_CDF_TAIL"), 1);
    iHigh = find(contains(bCheckNorm, "HIGH_T_BACKBONE_FAILURE"), 1);
    iTran = find(contains(bCheckNorm, "TRANSITION_22_24_BACKBONE_KINK"), 1);
    if ~isempty(iBack), bBackbone = bResNorm(iBack); end
    if ~isempty(iTail), bTail = bResNorm(iTail); end
    if ~isempty(iHigh), bHighT = bResNorm(iHigh); end
    if ~isempty(iTran), bTrans = bResNorm(iTran); end
    if ~(bBackbone == "PARTIAL" || bBackbone == "YES")
        error('run_switching_mode_admissibility_audit:PhaseBGate', ...
            'Phase C blocked: Phase B does not allow progression (BACKBONE_VALID_FOR_RESIDUAL_ANALYSIS=%s).', bBackbone);
    end

    % Build canonical maps on (T, I)
    T = double(sLong.T_K);
    I = double(sLong.current_mA);
    S = double(sLong.S_percent);
    B = double(sLong.S_model_pt_percent);
    C = double(sLong.CDF_pt);
    P = double(sLong.PT_pdf);
    v = isfinite(T) & isfinite(I);
    T = T(v); I = I(v); S = S(v); B = B(v); C = C(v); P = P(v);

    TI = table(T, I, S, B, C, P);
    TIg = groupsummary(TI, {'T','I'}, 'mean', {'S','B','C','P'});
    allT = unique(double(TIg.T), 'sorted');
    allI = unique(double(TIg.I), 'sorted');
    nT = numel(allT);
    nI = numel(allI);
    Smap = NaN(nT, nI);
    Bmap = NaN(nT, nI);
    Cmap = NaN(nT, nI);
    Pmap = NaN(nT, nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(TIg.T) - allT(it)) < 1e-9 & abs(double(TIg.I) - allI(ii)) < 1e-9;
            if any(m)
                idx = find(m, 1);
                Smap(it, ii) = double(TIg.mean_S(idx));
                Bmap(it, ii) = double(TIg.mean_B(idx));
                Cmap(it, ii) = double(TIg.mean_C(idx));
                Pmap(it, ii) = double(TIg.mean_P(idx));
            end
        end
    end

    % Canonical phi1 interpolation on current axis
    phi1Col = find(strcmpi(phiVars, "phi1"), 1);
    phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:, phi1Col}), allI, 'linear', 'extrap');
    phi1 = phi1(:);
    if any(~isfinite(phi1))
        phi1(~isfinite(phi1)) = 0;
    end
    n1 = norm(phi1);
    if n1 > 0, phi1 = phi1 / n1; end

    % Canonical amplitudes aligned to allT
    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

    % Residual decomposition (canonical hierarchy convention)
    R0 = Smap - Bmap;
    pred1 = Bmap - kappa1(:) * phi1(:)';
    R1 = Smap - pred1;
    R1z = R1; R1z(~isfinite(R1z)) = 0;
    [~, S1, V1] = svd(R1z, 'econ');
    if size(V1,2) >= 1
        phi2 = V1(:,1);
    else
        phi2 = zeros(nI,1);
    end
    n2 = norm(phi2);
    if n2 > 0, phi2 = phi2 / n2; end
    pred2 = pred1 + kappa2(:) * phi2(:)';
    R2 = Smap - pred2;

    R0z = R0; R0z(~isfinite(R0z)) = 0;
    [~, S0svd, V0] = svd(R0z, 'econ');
    sv0 = diag(S0svd);
    ev0 = sv0.^2;
    frac0 = ev0 / max(sum(ev0), eps);
    modeIdx = (1:numel(sv0))';
    spectrumTbl = table(modeIdx, sv0, ev0, frac0, ...
        'VariableNames', {'mode_index','singular_value','energy','energy_fraction'});
    switchingWriteTableBothPaths(spectrumTbl, repoRoot, runTables, 'switching_mode_admissibility_spectrum.csv');

    % Per-temperature decomposition energies and gains
    e0 = mean(R0.^2, 2, 'omitnan');
    e1 = mean(R1.^2, 2, 'omitnan');
    e2 = mean(R2.^2, 2, 'omitnan');
    g1 = (e0 - e1) ./ max(e0, eps);
    g2 = (e1 - e2) ./ max(e1, eps);

    % CDF coordinate for shape diagnostics
    cdfAxis = mean(Cmap, 1, 'omitnan');
    [cdfSort, ord] = sort(cdfAxis(:), 'ascend');
    cdfSort(~isfinite(cdfSort)) = 0;
    phi1cdf = phi1(ord);
    phi2cdf = phi2(ord);
    ptx = cdfSort(:);
    ptx = max(min(ptx, 1), 0);

    % even/odd decomposition around 0.5 on a regular grid
    xg = linspace(0,1,401)';
    p1g = interp1(ptx, phi1cdf, xg, 'linear', 'extrap');
    p2g = interp1(ptx, phi2cdf, xg, 'linear', 'extrap');
    p1m = interp1(xg, p1g, 1-xg, 'linear', 'extrap');
    p2m = interp1(xg, p2g, 1-xg, 'linear', 'extrap');
    p1even = 0.5 * (p1g + p1m); p1odd = 0.5 * (p1g - p1m);
    p2even = 0.5 * (p2g + p2m); p2odd = 0.5 * (p2g - p2m);

    p1eEven = mean(p1even.^2); p1eOdd = mean(p1odd.^2);
    p2eEven = mean(p2even.^2); p2eOdd = mean(p2odd.^2);

    lowMask = ptx <= 0.2;
    midMask = ptx > 0.4 & ptx < 0.6;
    highMask = ptx >= 0.8;
    edgeMask = ptx <= 0.05 | ptx >= 0.95;

    p1tot = sum(phi1cdf.^2); p2tot = sum(phi2cdf.^2);
    p1Low = sum(phi1cdf(lowMask).^2) / max(p1tot, eps);
    p1Mid = sum(phi1cdf(midMask).^2) / max(p1tot, eps);
    p1High = sum(phi1cdf(highMask).^2) / max(p1tot, eps);
    p1Edge = sum(phi1cdf(edgeMask).^2) / max(p1tot, eps);
    p2Low = sum(phi2cdf(lowMask).^2) / max(p2tot, eps);
    p2Mid = sum(phi2cdf(midMask).^2) / max(p2tot, eps);
    p2High = sum(phi2cdf(highMask).^2) / max(p2tot, eps);
    p2Edge = sum(phi2cdf(edgeMask).^2) / max(p2tot, eps);

    [~, i1pk] = max(phi1cdf); [~, i1tr] = min(phi1cdf);
    [~, i2pk] = max(phi2cdf); [~, i2tr] = min(phi2cdf);
    p1rough = mean(diff(phi1cdf).^2) / max(mean(phi1cdf.^2), eps);
    p2rough = mean(diff(phi2cdf).^2) / max(mean(phi2cdf.^2), eps);
    p1zc = sum(phi1cdf(1:end-1).*phi1cdf(2:end) < 0);
    p2zc = sum(phi2cdf(1:end-1).*phi2cdf(2:end) < 0);

    shapeTbl = table( ...
        string({'phi1';'phi2'}), ...
        [p1eEven/(p1eEven+p1eOdd+eps); p2eEven/(p2eEven+p2eOdd+eps)], ...
        [p1eOdd/(p1eEven+p1eOdd+eps); p2eOdd/(p2eEven+p2eOdd+eps)], ...
        [p1Low; p2Low], [p1Mid; p2Mid], [p1High; p2High], [p1Edge; p2Edge], ...
        [ptx(i1pk); ptx(i2pk)], [ptx(i1tr); ptx(i2tr)], ...
        [p1rough; p2rough], [p1zc; p2zc], ...
        'VariableNames', {'mode','even_energy_fraction','odd_energy_fraction','low_cdf_energy_fraction', ...
        'mid_cdf_energy_fraction','high_cdf_energy_fraction','edge_energy_fraction', ...
        'peak_cdf_location','trough_cdf_location','roughness','sign_changes'});
    switchingWriteTableBothPaths(shapeTbl, repoRoot, runTables, 'switching_mode_admissibility_shape.csv');

    % Stability tests
    stName = strings(0,1);
    stType = strings(0,1);
    stN = zeros(0,1);
    stCos1 = zeros(0,1);
    stCos2 = zeros(0,1);
    stSign1 = zeros(0,1);
    stSign2 = zeros(0,1);

    phi1Ref = phi1(:);
    phi2Ref = phi2(:);

    % LOOT
    lootCos1 = NaN(nT,1);
    lootCos2 = NaN(nT,1);
    for it = 1:nT
        keep = true(nT,1); keep(it) = false;
        Rk = R0z(keep,:);
        [~,~,Vk] = svd(Rk, 'econ');
        if size(Vk,2) < 2, continue; end
        v1 = Vk(:,1); v2 = Vk(:,2);
        c1 = dot(v1, phi1Ref)/(max(norm(v1),eps)*max(norm(phi1Ref),eps));
        c2 = dot(v2, phi2Ref)/(max(norm(v2),eps)*max(norm(phi2Ref),eps));
        lootCos1(it) = abs(c1);
        lootCos2(it) = abs(c2);
    end
    stName(end+1) = "leave_one_temperature_out";
    stType(end+1) = "LOOT";
    stN(end+1) = sum(isfinite(lootCos1));
    stCos1(end+1) = median(lootCos1, 'omitnan');
    stCos2(end+1) = median(lootCos2, 'omitnan');
    stSign1(end+1) = mean(lootCos1 >= 0.8, 'omitnan');
    stSign2(end+1) = mean(lootCos2 >= 0.8, 'omitnan');

    % Subset recomputation helper logic inlined
    tLow = allT <= prctile(allT, 33);
    tMid = allT > prctile(allT, 33) & allT < prctile(allT, 67);
    tHigh = allT >= prctile(allT, 67);
    tNoTrans = ~(allT >= 22 & allT <= 24);
    tNoHigh = allT < 28;
    tNoEdge = true(size(allT));
    if numel(allT) >= 4
        tNoEdge(1) = false; tNoEdge(end) = false;
    end

    subMasks = {tLow, tMid, tHigh, tNoTrans, tNoHigh, tNoEdge};
    subNames = {'subset_lowT','subset_midT','subset_highT','subset_exclude_22_24','subset_exclude_highT','subset_exclude_boundaryT'};
    for i = 1:numel(subMasks)
        mk = subMasks{i};
        Rk = R0z(mk,:);
        if size(Rk,1) < 3
            c1a = NaN; c2a = NaN; s1a = NaN; s2a = NaN;
        else
            [~,~,Vk] = svd(Rk, 'econ');
            if size(Vk,2) < 2
                c1a = NaN; c2a = NaN; s1a = NaN; s2a = NaN;
            else
                v1 = Vk(:,1); v2 = Vk(:,2);
                cc1 = dot(v1, phi1Ref)/(max(norm(v1),eps)*max(norm(phi1Ref),eps));
                cc2 = dot(v2, phi2Ref)/(max(norm(v2),eps)*max(norm(phi2Ref),eps));
                c1a = abs(cc1); c2a = abs(cc2);
                s1a = sign(cc1); s2a = sign(cc2);
            end
        end
        stName(end+1) = string(subNames{i});
        stType(end+1) = "subset";
        stN(end+1) = sum(mk);
        stCos1(end+1) = c1a;
        stCos2(end+1) = c2a;
        stSign1(end+1) = s1a;
        stSign2(end+1) = s2a;
    end

    stName = stName(:);
    stType = stType(:);
    stN = stN(:);
    stCos1 = stCos1(:);
    stCos2 = stCos2(:);
    stSign1 = stSign1(:);
    stSign2 = stSign2(:);
    stabilityTbl = table(stName, stType, stN, stCos1, stCos2, stSign1, stSign2, ...
        'VariableNames', {'test_name','test_type','n_temperatures','phi1_cosine_abs','phi2_cosine_abs','phi1_sign_consistency','phi2_sign_consistency'});
    switchingWriteTableBothPaths(stabilityTbl, repoRoot, runTables, 'switching_mode_admissibility_stability.csv');

    % High-CDF tail controls
    tailKeep = ptx < 0.8;
    w = ones(nI,1);
    w(ptx >= 0.8) = 0.25;
    Wsqrt = sqrt(w(:)');

    RtMask = R0z(:, tailKeep);
    [~,~,Vtm] = svd(RtMask, 'econ');
    if size(Vtm,2) >= 2
        v2m = zeros(nI,1);
        v2m(tailKeep) = Vtm(:,2);
        c2mask = abs(dot(v2m, phi2Ref)/(max(norm(v2m),eps)*max(norm(phi2Ref),eps)));
    else
        c2mask = NaN;
    end
    Rw = R0z .* (ones(nT,1)*Wsqrt);
    [~,~,Vtw] = svd(Rw, 'econ');
    if size(Vtw,2) >= 2
        v2w = Vtw(:,2);
        c2w = abs(dot(v2w, phi2Ref)/(max(norm(v2w),eps)*max(norm(phi2Ref),eps)));
    else
        c2w = NaN;
    end

    phi2NonTailEnergy = sum(phi2Ref(~highMask).^2) / max(sum(phi2Ref.^2), eps);
    phi2TailEnergy = sum(phi2Ref(highMask).^2) / max(sum(phi2Ref.^2), eps);
    phi2TailDominanceRatio = phi2TailEnergy / max(phi2NonTailEnergy, eps);
    tailTbl = table( ...
        string({'mask_high_cdf_tail';'downweight_high_cdf_tail'}), ...
        [c2mask; c2w], ...
        [phi2TailEnergy; phi2TailEnergy], ...
        [phi2NonTailEnergy; phi2NonTailEnergy], ...
        [phi2TailDominanceRatio; phi2TailDominanceRatio], ...
        'VariableNames', {'tail_control_test','phi2_cosine_abs_vs_canonical','phi2_tail_energy_fraction','phi2_non_tail_energy_fraction','phi2_tail_to_non_tail_energy_ratio'});
    switchingWriteTableBothPaths(tailTbl, repoRoot, runTables, 'switching_mode_admissibility_tail_controls.csv');

    % Null/noise-floor tests
    obsSv2 = NaN;
    if numel(sv0) >= 2, obsSv2 = sv0(2); end
    obsE2 = NaN;
    if numel(frac0) >= 2, obsE2 = frac0(2); end

    nNull = 100;
    nullSv2Shuffle = NaN(nNull,1);
    nullSv2Sign = NaN(nNull,1);
    nullSv2Noise = NaN(nNull,1);
    colStd = std(R0z, 0, 1, 'omitnan');
    for k = 1:nNull
        Rsh = R0z;
        for j = 1:nI
            ordk = randperm(nT);
            Rsh(:,j) = Rsh(ordk,j);
        end
        [~,Ssh,~] = svd(Rsh, 'econ');
        svk = diag(Ssh);
        if numel(svk) >= 2, nullSv2Shuffle(k) = svk(2); end

        sgn = sign(randn(nT,1));
        sgn(sgn==0) = 1;
        Rsgn = R0z .* (sgn * ones(1,nI));
        [~,Ssgn,~] = svd(Rsgn, 'econ');
        svs = diag(Ssgn);
        if numel(svs) >= 2, nullSv2Sign(k) = svs(2); end

        Rnz = randn(nT,nI) .* (ones(nT,1) * colStd);
        Rnz = conv2(Rnz, [0.25 0.5 0.25], 'same');
        [~,Snz,~] = svd(Rnz, 'econ');
        svn = diag(Snz);
        if numel(svn) >= 2, nullSv2Noise(k) = svn(2); end
    end

    nullNames = string({'temperature_shuffled';'random_sign_rows';'smoothed_matched_variance_noise'});
    nullMedian = [median(nullSv2Shuffle,'omitnan'); median(nullSv2Sign,'omitnan'); median(nullSv2Noise,'omitnan')];
    nullP95 = [prctile(nullSv2Shuffle,95); prctile(nullSv2Sign,95); prctile(nullSv2Noise,95)];
    nullRatio = obsSv2 ./ max(nullP95, eps);
    nullPass = strings(3,1);
    for i = 1:3
        if isfinite(nullRatio(i)) && nullRatio(i) >= 1.25
            nullPass(i) = "YES";
        elseif isfinite(nullRatio(i)) && nullRatio(i) >= 1.05
            nullPass(i) = "PARTIAL";
        else
            nullPass(i) = "NO";
        end
    end
    nullTbl = table(nullNames, repmat(obsSv2,3,1), repmat(obsE2,3,1), nullMedian, nullP95, nullRatio, nullPass, ...
        'VariableNames', {'null_test','observed_sv2','observed_mode2_energy_fraction','null_sv2_median','null_sv2_p95','observed_over_p95_ratio','mode2_above_null_flag'});
    switchingWriteTableBothPaths(nullTbl, repoRoot, runTables, 'switching_mode_admissibility_null_tests.csv');

    % Temperature structure table
    isHighT = allT >= 28;
    isTrans = allT >= 22 & allT <= 24;
    isNeighbor = allT >= 20 & allT <= 26 & ~isTrans;
    tempTbl = table(allT(:), kappa1(:), kappa2(:), e0(:), e1(:), e2(:), g1(:), g2(:), isHighT(:), isTrans(:), isNeighbor(:), ...
        'VariableNames', {'T_K','kappa1','kappa2','residual_energy_R0','residual_energy_R1','residual_energy_R2','phi1_gain_fraction','phi2_gain_fraction','is_highT','is_transition_22_24','is_neighbor_transition'});
    switchingWriteTableBothPaths(tempTbl, repoRoot, runTables, 'switching_mode_admissibility_temperature_structure.csv');

    % Status decision logic
    mode1Frac = frac0(1);
    mode2Frac = NaN;
    if numel(frac0) >= 2, mode2Frac = frac0(2); end
    if mode1Frac >= 0.50
        fMode1Dominant = 'YES';
    elseif mode1Frac >= 0.35
        fMode1Dominant = 'PARTIAL';
    else
        fMode1Dominant = 'NO';
    end
    if isfinite(mode2Frac) && mode2Frac >= 0.12
        fMode2Significant = 'YES';
    elseif isfinite(mode2Frac) && mode2Frac >= 0.06
        fMode2Significant = 'PARTIAL';
    else
        fMode2Significant = 'NO';
    end

    medCos1 = median(stabilityTbl.phi1_cosine_abs, 'omitnan');
    medCos2 = median(stabilityTbl.phi2_cosine_abs, 'omitnan');
    if medCos1 >= 0.9
        fMode1Stable = 'YES';
    elseif medCos1 >= 0.75
        fMode1Stable = 'PARTIAL';
    else
        fMode1Stable = 'NO';
    end
    if medCos2 >= 0.9
        fMode2Stable = 'YES';
    elseif medCos2 >= 0.7
        fMode2Stable = 'PARTIAL';
    else
        fMode2Stable = 'NO';
    end

    if all(nullTbl.mode2_above_null_flag == "YES")
        fMode2AboveNull = 'YES';
    elseif any(nullTbl.mode2_above_null_flag ~= "NO")
        fMode2AboveNull = 'PARTIAL';
    else
        fMode2AboveNull = 'NO';
    end

    if p2Edge >= 0.60
        fPhi2EdgeDominated = 'YES';
    elseif p2Edge >= 0.40
        fPhi2EdgeDominated = 'PARTIAL';
    else
        fPhi2EdgeDominated = 'NO';
    end
    if p2High >= 0.55
        fPhi2TailDominated = 'YES';
    elseif p2High >= 0.35
        fPhi2TailDominated = 'PARTIAL';
    else
        fPhi2TailDominated = 'NO';
    end

    % survival tests
    cNoHigh = stabilityTbl.phi2_cosine_abs(stabilityTbl.test_name == "subset_exclude_highT");
    cNoTrans = stabilityTbl.phi2_cosine_abs(stabilityTbl.test_name == "subset_exclude_22_24");
    if ~isempty(cNoHigh) && isfinite(cNoHigh(1)) && cNoHigh(1) >= 0.75
        fPhi2SurvivesHighTExcl = 'YES';
    elseif ~isempty(cNoHigh) && isfinite(cNoHigh(1)) && cNoHigh(1) >= 0.55
        fPhi2SurvivesHighTExcl = 'PARTIAL';
    else
        fPhi2SurvivesHighTExcl = 'NO';
    end
    if ~isempty(cNoTrans) && isfinite(cNoTrans(1)) && cNoTrans(1) >= 0.75
        fPhi2SurvivesTransExcl = 'YES';
    elseif ~isempty(cNoTrans) && isfinite(cNoTrans(1)) && cNoTrans(1) >= 0.55
        fPhi2SurvivesTransExcl = 'PARTIAL';
    else
        fPhi2SurvivesTransExcl = 'NO';
    end

    medTailCos = median(tailTbl.phi2_cosine_abs_vs_canonical, 'omitnan');
    if medTailCos >= 0.75
        fPhi2SurvivesTail = 'YES';
    elseif medTailCos >= 0.55
        fPhi2SurvivesTail = 'PARTIAL';
    else
        fPhi2SurvivesTail = 'NO';
    end

    if p1rough <= 1.2 && p1zc <= 3
        fPhi1InterpCDF = 'YES';
    elseif p1rough <= 2.0 && p1zc <= 5
        fPhi1InterpCDF = 'PARTIAL';
    else
        fPhi1InterpCDF = 'NO';
    end
    if p2rough <= 1.8 && p2zc <= 5
        fPhi2InterpCDF = 'YES';
    elseif p2rough <= 3.0 && p2zc <= 7
        fPhi2InterpCDF = 'PARTIAL';
    else
        fPhi2InterpCDF = 'NO';
    end

    % Admissibility (do not claim mechanism)
    if strcmp(fMode1Dominant,'YES') && strcmp(fMode1Stable,'YES') && strcmp(fPhi1InterpCDF,'YES')
        fPhi1Admissible = 'YES';
    elseif ~strcmp(fMode1Dominant,'NO') && ~strcmp(fMode1Stable,'NO')
        fPhi1Admissible = 'PARTIAL';
    else
        fPhi1Admissible = 'NO';
    end

    if strcmp(fMode2Significant,'YES') && ~strcmp(fMode2Stable,'NO') && ~strcmp(fMode2AboveNull,'NO')
        if strcmp(fPhi2TailDominated,'YES') || strcmp(fPhi2SurvivesTail,'NO')
            fPhi2Admissible = 'PARTIAL';
        else
            fPhi2Admissible = 'YES';
        end
    elseif strcmp(fMode2Significant,'NO') || strcmp(fMode2AboveNull,'NO')
        fPhi2Admissible = 'NO';
    else
        fPhi2Admissible = 'PARTIAL';
    end

    if ~strcmp(fPhi1Admissible,'NO')
        fReadyPhaseD = 'YES';
    else
        fReadyPhaseD = 'NO';
    end

    statusTbl = table( ...
        {'PHI1_ADMISSIBLE_PHYSICAL_MODE'; 'PHI2_ADMISSIBLE_PHYSICAL_MODE'; 'MODE1_DOMINANT'; ...
         'MODE2_SIGNIFICANT'; 'MODE1_STABLE'; 'MODE2_STABLE'; 'MODE2_ABOVE_NULL_FLOOR'; ...
         'PHI2_EDGE_DOMINATED'; 'PHI2_HIGH_CDF_TAIL_DOMINATED'; 'PHI2_SURVIVES_TAIL_CONTROL'; ...
         'PHI2_SURVIVES_HIGH_T_EXCLUSION'; 'PHI2_SURVIVES_22_24_EXCLUSION'; ...
         'PHI1_INTERPRETABLE_IN_CDF_SPACE'; 'PHI2_INTERPRETABLE_IN_CDF_SPACE'; ...
         'READY_FOR_PHASE_D_MODE_RELATIONSHIP'}, ...
        {fPhi1Admissible; fPhi2Admissible; fMode1Dominant; fMode2Significant; fMode1Stable; fMode2Stable; ...
         fMode2AboveNull; fPhi2EdgeDominated; fPhi2TailDominated; fPhi2SurvivesTail; ...
         fPhi2SurvivesHighTExcl; fPhi2SurvivesTransExcl; fPhi1InterpCDF; fPhi2InterpCDF; fReadyPhaseD}, ...
        {sprintf('mode1_frac=%.6g, med_cos=%.6g, cdf_interp=%s', mode1Frac, medCos1, fPhi1InterpCDF); ...
         sprintf('mode2_frac=%.6g, med_cos=%.6g, null=%s, tail_dom=%s', mode2Frac, medCos2, fMode2AboveNull, fPhi2TailDominated); ...
         sprintf('mode1 energy fraction=%.6g', mode1Frac); ...
         sprintf('mode2 energy fraction=%.6g', mode2Frac); ...
         sprintf('median phi1 cosine abs across stability tests=%.6g', medCos1); ...
         sprintf('median phi2 cosine abs across stability tests=%.6g', medCos2); ...
         sprintf('null floor flags: %s/%s/%s', nullTbl.mode2_above_null_flag(1), nullTbl.mode2_above_null_flag(2), nullTbl.mode2_above_null_flag(3)); ...
         sprintf('phi2 edge energy fraction=%.6g', p2Edge); ...
         sprintf('phi2 high-CDF energy fraction=%.6g', p2High); ...
         sprintf('median tail-control cosine abs=%.6g', medTailCos); ...
         sprintf('exclude high-T cosine abs=%.6g', cNoHigh(1)); ...
         sprintf('exclude 22-24 cosine abs=%.6g', cNoTrans(1)); ...
         sprintf('phi1 roughness=%.6g sign_changes=%d', p1rough, p1zc); ...
         sprintf('phi2 roughness=%.6g sign_changes=%d', p2rough, p2zc); ...
         sprintf('Phase D readiness based on admissibility flags: Phi1=%s Phi2=%s', fPhi1Admissible, fPhi2Admissible)}, ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_mode_admissibility_status.csv');
    switchingWriteTableBothPaths(switchingInputGateRowsToTable(gateRows), repoRoot, runTables, 'switching_mode_admissibility_input_gate_status.csv');

    % Run-scoped figures
    fig = figure('Visible','off','Color','w','Position',[80 80 1600 900]);
    tl = tiledlayout(2,3,'Parent',fig,'TileSpacing','compact','Padding','compact');

    nexttile(tl);
    plot(modeIdx, frac0, '-o', 'LineWidth', 1.5);
    title('SVD spectrum (R0)'); xlabel('Mode'); ylabel('Energy fraction'); grid on;

    nexttile(tl);
    plot(ptx, phi1cdf, '-','LineWidth',1.6); hold on;
    plot(ptx, phi2cdf, '-','LineWidth',1.6); hold off;
    title('Phi1/Phi2 in CDF_{pt}'); xlabel('CDF_{pt}'); ylabel('Mode amplitude');
    legend({'Phi1','Phi2'},'Location','best'); grid on;

    nexttile(tl);
    plot(allT, g1, '-o', 'LineWidth', 1.4); hold on;
    plot(allT, g2, '-s', 'LineWidth', 1.4); hold off;
    xline(22,'--'); xline(24,'--'); xline(28,'--');
    title('Residual reduction by T'); xlabel('T_K'); ylabel('Gain fraction');
    legend({'Phi1 gain','Phi2 gain'},'Location','best'); grid on;

    nexttile(tl);
    ystab = [stabilityTbl.phi1_cosine_abs, stabilityTbl.phi2_cosine_abs];
    bar(ystab);
    ax4 = gca;
    ax4.XTick = 1:height(stabilityTbl);
    ax4.XTickLabel = cellstr(stabilityTbl.test_name);
    title('Mode stability cosine summary'); ylabel('|cosine|'); xtickangle(30); grid on;

    nexttile(tl);
    bar(categorical(tailTbl.tail_control_test), tailTbl.phi2_cosine_abs_vs_canonical);
    title('Tail-control Phi2 similarity'); ylabel('|cosine to canonical Phi2|'); grid on;

    nexttile(tl);
    plot(allT, kappa2, '-o', 'LineWidth', 1.4); hold on;
    plot(allT, g2, '-s', 'LineWidth', 1.4); hold off;
    xline(22,'--'); xline(24,'--'); xline(28,'--');
    title('Phi2 gain vs T'); xlabel('T_K'); ylabel('kappa2 / gain');
    legend({'kappa2','Phi2 gain'}, 'Location', 'best'); grid on;

    sgtitle(tl, 'Canonical Switching Mode Admissibility (Phase C)', 'Interpreter', 'none');
    figPath = fullfile(runFigures, [baseName '.fig']);
    pngPath = fullfile(runFigures, [baseName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    % Report
    lines = {};
    lines{end+1} = '# Canonical Switching mode admissibility audit (Phase C)';
    lines{end+1} = '';
    lines{end+1} = '## Scope and restrictions';
    lines{end+1} = '- Switching only; no producer edits; no changes to canonical reconstruction or mode definitions.';
    lines{end+1} = '- Phase-B restrictions enforced: CDF-validity stratification, explicit high-CDF-tail controls, high-T and 22-24K subset checks.';
    lines{end+1} = '- Provisional observable/dynamic outputs used only as leads, not accepted conclusions.';
    lines{end+1} = '';
    lines{end+1} = '## Inputs';
    for i = 1:numel(reqPaths)
        lines{end+1} = sprintf('- `%s`', reqPaths{i});
    end
    lines{end+1} = sprintf('- Phase B gate flags: BACKBONE=%s, TAIL_LOCALIZATION=%s, HIGH_T=%s, TRANSITION=%s', bBackbone, bTail, bHighT, bTrans);
    lines{end+1} = '';
    lines{end+1} = '## Core diagnostics';
    lines{end+1} = sprintf('- mode1 energy fraction = %.6g', mode1Frac);
    lines{end+1} = sprintf('- mode2 energy fraction = %.6g', mode2Frac);
    lines{end+1} = sprintf('- median stability |cos|: Phi1=%.6g, Phi2=%.6g', medCos1, medCos2);
    lines{end+1} = sprintf('- Phi2 tail energy fraction = %.6g, non-tail = %.6g', phi2TailEnergy, phi2NonTailEnergy);
    lines{end+1} = sprintf('- Phi2 tail-control median |cos| = %.6g', medTailCos);
    lines{end+1} = sprintf('- Phi2 exclusion checks: noHighT=%s, no22_24=%s', fPhi2SurvivesHighTExcl, fPhi2SurvivesTransExcl);
    lines{end+1} = sprintf('- Mode2 vs null floor ratios (obs/p95): shuffle=%.6g sign=%.6g noise=%.6g', nullRatio(1), nullRatio(2), nullRatio(3));
    lines{end+1} = '';
    lines{end+1} = '## Required status flags';
    lines{end+1} = sprintf('- PHI1_ADMISSIBLE_PHYSICAL_MODE = %s', fPhi1Admissible);
    lines{end+1} = sprintf('- PHI2_ADMISSIBLE_PHYSICAL_MODE = %s', fPhi2Admissible);
    lines{end+1} = sprintf('- MODE1_DOMINANT = %s', fMode1Dominant);
    lines{end+1} = sprintf('- MODE2_SIGNIFICANT = %s', fMode2Significant);
    lines{end+1} = sprintf('- MODE1_STABLE = %s', fMode1Stable);
    lines{end+1} = sprintf('- MODE2_STABLE = %s', fMode2Stable);
    lines{end+1} = sprintf('- MODE2_ABOVE_NULL_FLOOR = %s', fMode2AboveNull);
    lines{end+1} = sprintf('- PHI2_EDGE_DOMINATED = %s', fPhi2EdgeDominated);
    lines{end+1} = sprintf('- PHI2_HIGH_CDF_TAIL_DOMINATED = %s', fPhi2TailDominated);
    lines{end+1} = sprintf('- PHI2_SURVIVES_TAIL_CONTROL = %s', fPhi2SurvivesTail);
    lines{end+1} = sprintf('- PHI2_SURVIVES_HIGH_T_EXCLUSION = %s', fPhi2SurvivesHighTExcl);
    lines{end+1} = sprintf('- PHI2_SURVIVES_22_24_EXCLUSION = %s', fPhi2SurvivesTransExcl);
    lines{end+1} = sprintf('- PHI1_INTERPRETABLE_IN_CDF_SPACE = %s', fPhi1InterpCDF);
    lines{end+1} = sprintf('- PHI2_INTERPRETABLE_IN_CDF_SPACE = %s', fPhi2InterpCDF);
    lines{end+1} = sprintf('- READY_FOR_PHASE_D_MODE_RELATIONSHIP = %s', fReadyPhaseD);
    lines{end+1} = '';
    if strcmp(fPhi2TailDominated, 'YES') || strcmp(fPhi2SurvivesTail, 'NO')
        lines{end+1} = '## Required caveat';
        lines{end+1} = '- Phi2 appears significant but is strongly linked to high-CDF-tail residual burden; treat as partial admissibility, not a robust broad residual mode.';
        lines{end+1} = '';
    end
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_mode_admissibility_spectrum.csv`';
    lines{end+1} = '- `tables/switching_mode_admissibility_shape.csv`';
    lines{end+1} = '- `tables/switching_mode_admissibility_stability.csv`';
    lines{end+1} = '- `tables/switching_mode_admissibility_tail_controls.csv`';
    lines{end+1} = '- `tables/switching_mode_admissibility_null_tests.csv`';
    lines{end+1} = '- `tables/switching_mode_admissibility_temperature_structure.csv`';
    lines{end+1} = '- `tables/switching_mode_admissibility_status.csv`';
    lines{end+1} = '- `reports/switching_mode_admissibility_audit.md`';
    lines{end+1} = sprintf('- run figure `.fig`: `%s`', figPath);
    lines{end+1} = sprintf('- run figure `.png`: `%s`', pngPath);
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_mode_admissibility_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_mode_admissibility_audit.md'), lines, 'run_switching_mode_admissibility_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'mode admissibility audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_mode_admissibility_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    if isempty(gateRows.table_name)
        gateRows = switchingAddInputGateRow(gateRows, 'unknown', 'unknown', 'FAIL', char(string(ME.identifier)), char(string(ME.message)), '');
    end
    writetable(switchingInputGateRowsToTable(gateRows), fullfile(runDir, 'tables', 'switching_mode_admissibility_input_gate_status.csv'));
    writetable(switchingInputGateRowsToTable(gateRows), fullfile(repoRoot, 'tables', 'switching_mode_admissibility_input_gate_status.csv'));

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        {'PHI1_ADMISSIBLE_PHYSICAL_MODE'; 'PHI2_ADMISSIBLE_PHYSICAL_MODE'; 'MODE1_DOMINANT'; ...
         'MODE2_SIGNIFICANT'; 'MODE1_STABLE'; 'MODE2_STABLE'; 'MODE2_ABOVE_NULL_FLOOR'; ...
         'PHI2_EDGE_DOMINATED'; 'PHI2_HIGH_CDF_TAIL_DOMINATED'; 'PHI2_SURVIVES_TAIL_CONTROL'; ...
         'PHI2_SURVIVES_HIGH_T_EXCLUSION'; 'PHI2_SURVIVES_22_24_EXCLUSION'; ...
         'PHI1_INTERPRETABLE_IN_CDF_SPACE'; 'PHI2_INTERPRETABLE_IN_CDF_SPACE'; ...
         'READY_FOR_PHASE_D_MODE_RELATIONSHIP'}, ...
        {'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'}, ...
        repmat({failMsg}, 15, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_mode_admissibility_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_mode_admissibility_status.csv'));

    lines = {};
    lines{end+1} = '# Canonical Switching mode admissibility audit — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_mode_admissibility_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_mode_admissibility_audit.md'), lines, 'run_switching_mode_admissibility_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'mode admissibility audit failed'}, true);
    rethrow(ME);
end
