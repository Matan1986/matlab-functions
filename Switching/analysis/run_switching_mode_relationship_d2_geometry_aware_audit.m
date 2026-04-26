clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_mode_relationship_d2_geometry_aware_audit';

% Required flags defaults
fD2Completed = 'NO';
fUnresolvedDueGeometry = 'NO';
fSupportAwareValid = 'NO';
fPhi1ClassD2 = 'unresolved';
fPhi2ClassD2 = 'unresolved_partial';
fKappa2ClassD2 = 'unresolved_partial';
fReadyStaticMap = 'NO';
fClaimsAllowed = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_mode_relationship_d2_geometry_aware';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Phase D2 geometry-aware audit initialized'}, false);

    s1Path = fullfile(repoRoot, 'tables', 'switching_backbone_selection_run_status.csv');
    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    reqPre = {s1Path, idPath, ampPath};
    for i = 1:numel(reqPre)
        if exist(reqPre{i}, 'file') ~= 2
            error('run_switching_mode_relationship_d2:MissingInput', 'Missing required input: %s', reqPre{i});
        end
    end

    % Enforce S1 gate and frozen backbone policy.
    s1 = readtable(s1Path, 'TextType', 'string');
    iCurr = find(strcmpi(strtrim(s1.check), 'CURRENT_PTCDF_BACKBONE_SELECTED'), 1);
    iAllow = find(strcmpi(strtrim(s1.check), 'PHASE_D_ALLOWED_AFTER_SELECTION'), 1);
    if isempty(iCurr) || isempty(iAllow)
        error('run_switching_mode_relationship_d2:S1Schema', 'S1 status table missing required checks.');
    end
    if upper(strtrim(s1.result(iCurr))) ~= "YES" || upper(strtrim(s1.result(iAllow))) ~= "YES"
        error('run_switching_mode_relationship_d2:S1Gate', 'Phase D2 blocked by S1 selection gate.');
    end

    % Canonical identity lock read (strict for D2: no mtime fallback).
    idRaw = readcell(idPath, 'Delimiter', ',');
    canonicalRunId = "";
    for r = 2:size(idRaw,1)
        f = normalizeIdentityField(string(idRaw{r,1}));
        if strcmpi(f, "CANONICAL_RUN_ID")
            canonicalRunId = strtrim(string(idRaw{r,2}));
            break;
        end
    end
    if strlength(canonicalRunId) == 0
        error('run_switching_mode_relationship_d2:Identity', 'CANONICAL_RUN_ID missing in switching_canonical_identity.csv.');
    end
    sLongPath = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables', 'switching_canonical_S_long.csv');
    phi1Path = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables', 'switching_canonical_phi1.csv');
    req = {sLongPath, phi1Path};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_mode_relationship_d2:IdentityAnchorMissing', ...
                'Identity-anchored canonical artifact missing (no fallback allowed): %s', req{i});
        end
    end

    % Input table contract validation.
    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);
    if ~all(ismember({'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'}, sLong.Properties.VariableNames))
        error('run_switching_mode_relationship_d2:Schema', 'sLong table missing required columns.');
    end
    if ~all(ismember({'T_K','kappa1','kappa2'}, ampTbl.Properties.VariableNames))
        error('run_switching_mode_relationship_d2:Schema', 'amplitude table missing kappa1/kappa2.');
    end

    T = double(sLong.T_K); I = double(sLong.current_mA);
    S = double(sLong.S_percent); B = double(sLong.S_model_pt_percent); C = double(sLong.CDF_pt);
    v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
    T = T(v); I = I(v); S = S(v); B = B(v); C = C(v);
    G = groupsummary(table(T,I,S,B,C), {'T','I'}, 'mean', {'S','B','C'});
    allT = unique(double(G.T), 'sorted');
    allI = unique(double(G.I), 'sorted');
    nT = numel(allT); nI = numel(allI);

    Smap = NaN(nT,nI); Bmap = NaN(nT,nI); Cmap = NaN(nT,nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(G.T)-allT(it)) < 1e-9 & abs(double(G.I)-allI(ii)) < 1e-9;
            if any(m)
                j = find(m,1);
                Smap(it,ii) = double(G.mean_S(j));
                Bmap(it,ii) = double(G.mean_B(j));
                Cmap(it,ii) = double(G.mean_C(j));
            end
        end
    end

    validMap = isfinite(Smap) & isfinite(Bmap) & isfinite(Cmap);
    cdfAxis = mean(Cmap, 1, 'omitnan');

    % Predeclared strict and expanded windows (not tuned post hoc).
    strictLow = cdfAxis >= 0.00 & cdfAxis < 0.20;
    strictMid = cdfAxis > 0.40 & cdfAxis < 0.60;
    strictHigh = cdfAxis >= 0.80 & cdfAxis <= 1.00;
    strictTail = cdfAxis >= 0.80;
    expandedLow = cdfAxis >= 0.00 & cdfAxis < 0.30;
    expandedMid = cdfAxis >= 0.35 & cdfAxis <= 0.65;
    expandedHigh = cdfAxis >= 0.70 & cdfAxis <= 1.00;
    expandedTail = cdfAxis >= 0.70;

    phiVars = string(phi1Tbl.Properties.VariableNames);
    iPhi = find(strcmpi(phiVars, "phi1"), 1);
    phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:,iPhi}), allI, 'linear', 'extrap');
    phi1 = phi1(:); phi1(~isfinite(phi1)) = 0;
    if norm(phi1) > 0, phi1 = phi1 / norm(phi1); end

    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

    R0 = Smap - Bmap;
    pred1 = Bmap - kappa1(:) * phi1(:)';
    R1 = Smap - pred1;
    R1z = R1; R1z(~isfinite(R1z)) = 0;
    [~,~,V1] = svd(R1z, 'econ');
    if size(V1,2) >= 1, phi2 = V1(:,1); else, phi2 = zeros(nI,1); end
    if norm(phi2) > 0, phi2 = phi2 / norm(phi2); end
    pred2 = pred1 + kappa2(:) * phi2(:)';
    R2 = Smap - pred2;
    R0(~validMap) = NaN; R1(~validMap) = NaN; R2(~validMap) = NaN;

    minSupportN = 5; % predeclared support threshold for valid windowed metrics

    % Window support table.
    winNames = ["strict_low";"strict_mid";"strict_high";"strict_tail";"expanded_low";"expanded_mid";"expanded_high";"expanded_tail"];
    winMasks = {strictLow, strictMid, strictHigh, strictTail, expandedLow, expandedMid, expandedHigh, expandedTail};
    supportRows = table();
    for iw = 1:numel(winNames)
        mW = winMasks{iw}(:)';
        nCurr = sum(mW & isfinite(phi1(:)') & isfinite(phi2(:)'));
        fracCurr = nCurr / max(nI, 1);
        suppCurr = string(ternary(nCurr >= minSupportN, 'YES', 'NO'));
        supportRows = [supportRows; table("all_T", winNames(iw), nCurr, fracCurr, minSupportN, suppCurr, ...
            'VariableNames', {'T_scope','window_name','support_n','support_fraction','min_support_n','support_ok'})]; %#ok<AGROW>
        for it = 1:nT
            rowValid = validMap(it,:);
            nTI = sum(mW & rowValid);
            suppTI = string(ternary(nTI >= minSupportN, 'YES', 'NO'));
            supportRows = [supportRows; table(string(allT(it)), winNames(iw), nTI, nTI/max(sum(rowValid),1), minSupportN, suppTI, ...
                'VariableNames', {'T_scope','window_name','support_n','support_fraction','min_support_n','support_ok'})]; %#ok<AGROW>
        end
    end
    switchingWriteTableBothPaths(supportRows, repoRoot, runTables, 'switching_mode_relationship_d2_window_support.csv');

    % Metric validity audit + support-aware metric computation.
    allMetricRows = table();
    metricsRows = table();

    metricSpecs = {
        "phi1_phi2_cosine", "full_domain", true(size(phi1));
        "phi1_phi2_correlation", "full_domain", true(size(phi1));
        "phi1_phi2_cosine", "strict_low", strictLow(:);
        "phi1_phi2_correlation", "strict_low", strictLow(:);
        "phi1_phi2_cosine", "strict_mid", strictMid(:);
        "phi1_phi2_correlation", "strict_mid", strictMid(:);
        "phi1_phi2_cosine", "strict_high", strictHigh(:);
        "phi1_phi2_correlation", "strict_high", strictHigh(:);
        "phi1_phi2_cosine", "strict_tail", strictTail(:);
        "phi1_phi2_correlation", "strict_tail", strictTail(:);
        "phi1_phi2_cosine", "expanded_low", expandedLow(:);
        "phi1_phi2_correlation", "expanded_low", expandedLow(:);
        "phi1_phi2_cosine", "expanded_mid", expandedMid(:);
        "phi1_phi2_correlation", "expanded_mid", expandedMid(:);
        "phi1_phi2_cosine", "expanded_high", expandedHigh(:);
        "phi1_phi2_correlation", "expanded_high", expandedHigh(:);
        "phi1_phi2_cosine", "expanded_tail", expandedTail(:);
        "phi1_phi2_correlation", "expanded_tail", expandedTail(:)
        };

    for i = 1:size(metricSpecs,1)
        metricName = string(metricSpecs{i,1});
        domainName = string(metricSpecs{i,2});
        mask = logical(metricSpecs{i,3});
        isStrict = startsWith(domainName, "strict_");

        [metricVal, validFlag, invalidClass, invalidCause, nPoints] = evalMetric(metricName, phi1, phi2, mask, minSupportN);
        compD = string(ternary(startsWith(domainName, "strict_") || domainName=="full_domain", 'YES', 'NO'));
        allMetricRows = [allMetricRows; table(metricName, domainName, nPoints, string(validFlag), invalidClass, invalidCause, metricVal, ...
            'VariableNames', {'metric_name','window_name','n_points','validity_flag','invalid_class','invalid_cause','metric_value'})]; %#ok<AGROW>
        metricsRows = [metricsRows; table(metricName, domainName, metricVal, string(validFlag), invalidClass, nPoints, compD, ...
            'VariableNames', {'metric_name','window_name','metric_value','validity_flag','invalid_class','n_points','comparable_to_phase_d'})]; %#ok<AGROW>

        if isStrict && validFlag == "NO"
            expDomain = replace(domainName, "strict_", "expanded_");
            expMask = logical(winMasks{find(winNames == expDomain,1)});
            [metricVal2, validFlag2, invalidClass2, invalidCause2, nPoints2] = evalMetric(metricName, phi1, phi2, expMask(:), minSupportN);
            allMetricRows = [allMetricRows; table(metricName, expDomain + "_fallback_for_" + domainName, nPoints2, string(validFlag2), invalidClass2, invalidCause2, metricVal2, ...
                'VariableNames', {'metric_name','window_name','n_points','validity_flag','invalid_class','invalid_cause','metric_value'})]; %#ok<AGROW>
            metricsRows = [metricsRows; table(metricName, expDomain + "_fallback_for_" + domainName, metricVal2, string(validFlag2), invalidClass2, nPoints2, "NO", ...
                'VariableNames', {'metric_name','window_name','metric_value','validity_flag','invalid_class','n_points','comparable_to_phase_d'})]; %#ok<AGROW>
        end
    end

    % Kappa/tail coupling metrics with validity diagnosis.
    strictMidMask = strictMid(:)';
    strictTailMask = strictTail(:)';
    expandedMidMask = expandedMid(:)';
    expandedTailMask = expandedTail(:)';
    tailBurdenStrict = mean(R0(:,strictTailMask).^2, 2, 'omitnan') ./ max(mean(R0(:,strictMidMask).^2, 2, 'omitnan'), eps);
    tailBurdenExpanded = mean(R0(:,expandedTailMask).^2, 2, 'omitnan') ./ max(mean(R0(:,expandedMidMask).^2, 2, 'omitnan'), eps);
    globalBurden = mean(R0.^2, 2, 'omitnan');

    [cK2TailStrict, vK2TailStrict, clsK2TailStrict, causeK2TailStrict, nK2TailStrict] = evalCorrMetric(kappa2(:), tailBurdenStrict(:), minSupportN);
    [cK2TailExpanded, vK2TailExpanded, clsK2TailExpanded, causeK2TailExpanded, nK2TailExpanded] = evalCorrMetric(kappa2(:), tailBurdenExpanded(:), minSupportN);
    [cK2Global, vK2Global, clsK2Global, causeK2Global, nK2Global] = evalCorrMetric(kappa2(:), globalBurden(:), minSupportN);
    [cK1TailStrict, vK1TailStrict, clsK1TailStrict, causeK1TailStrict, nK1TailStrict] = evalCorrMetric(kappa1(:), tailBurdenStrict(:), minSupportN);

    extraValidity = table( ...
        ["kappa2_vs_tail_burden_corr";"kappa2_vs_tail_burden_corr";"kappa2_vs_global_burden_corr";"kappa1_vs_tail_burden_corr"], ...
        ["strict_tail_over_mid";"expanded_tail_over_mid";"full_domain";"strict_tail_over_mid"], ...
        [nK2TailStrict;nK2TailExpanded;nK2Global;nK1TailStrict], ...
        string([vK2TailStrict;vK2TailExpanded;vK2Global;vK1TailStrict]), ...
        [clsK2TailStrict;clsK2TailExpanded;clsK2Global;clsK1TailStrict], ...
        [causeK2TailStrict;causeK2TailExpanded;causeK2Global;causeK1TailStrict], ...
        [cK2TailStrict;cK2TailExpanded;cK2Global;cK1TailStrict], ...
        'VariableNames', {'metric_name','window_name','n_points','validity_flag','invalid_class','invalid_cause','metric_value'});
    allMetricRows = [allMetricRows; extraValidity];

    extraMetrics = table( ...
        ["kappa2_vs_tail_burden_corr";"kappa2_vs_tail_burden_corr";"kappa2_vs_global_burden_corr";"kappa1_vs_tail_burden_corr"], ...
        ["strict_tail_over_mid";"expanded_tail_over_mid";"full_domain";"strict_tail_over_mid"], ...
        [cK2TailStrict;cK2TailExpanded;cK2Global;cK1TailStrict], ...
        string([vK2TailStrict;vK2TailExpanded;vK2Global;vK1TailStrict]), ...
        [clsK2TailStrict;clsK2TailExpanded;clsK2Global;clsK1TailStrict], ...
        [nK2TailStrict;nK2TailExpanded;nK2Global;nK1TailStrict], ...
        ["YES";"NO";"YES";"YES"], ...
        'VariableNames', {'metric_name','window_name','metric_value','validity_flag','invalid_class','n_points','comparable_to_phase_d'});
    metricsRows = [metricsRows; extraMetrics];

    switchingWriteTableBothPaths(allMetricRows, repoRoot, runTables, 'switching_mode_relationship_d2_metric_validity.csv');
    switchingWriteTableBothPaths(metricsRows, repoRoot, runTables, 'switching_mode_relationship_d2_metrics.csv');

    % Support-aware class decisions: invalid strict metrics are not counted as negative evidence.
    cAll = pickMetric(metricsRows, "phi1_phi2_cosine", "full_domain");
    cLow = pickBestStrictOrFallback(metricsRows, "phi1_phi2_cosine", "strict_low");
    cMid = pickBestStrictOrFallback(metricsRows, "phi1_phi2_cosine", "strict_mid");
    cTail = pickBestStrictOrFallback(metricsRows, "phi1_phi2_cosine", "strict_tail");

    phi2TailFrac = sum(phi2(strictTailMask).^2) / max(sum(phi2.^2), eps);
    phi2OutsideTailFrac = 1 - phi2TailFrac;
    cK2TailUse = pickBestStrictOrExpandedCorr(metricsRows, "kappa2_vs_tail_burden_corr");
    cK2GlobalUse = pickMetric(metricsRows, "kappa2_vs_global_burden_corr", "full_domain");
    cK1TailUse = pickBestStrictOrExpandedCorr(metricsRows, "kappa1_vs_tail_burden_corr");

    strictInvalidN = sum(allMetricRows.validity_flag=="NO" & startsWith(allMetricRows.window_name, "strict_"));
    strictTotalN = sum(startsWith(allMetricRows.window_name, "strict_"));
    if strictInvalidN == 0
        fUnresolvedDueGeometry = 'NO';
    elseif strictInvalidN < strictTotalN
        fUnresolvedDueGeometry = 'PARTIAL';
    else
        fUnresolvedDueGeometry = 'YES';
    end

    validCore = isfinite(cAll) && isfinite(cLow) && isfinite(cMid) && isfinite(cTail) && isfinite(cK2GlobalUse);
    if validCore
        fSupportAwareValid = 'YES';
    elseif isfinite(cAll)
        fSupportAwareValid = 'PARTIAL';
    else
        fSupportAwareValid = 'NO';
    end

    if isfinite(cAll) && isfinite(cLow) && isfinite(cMid) && abs(cAll) < 0.35 && abs(cLow) < 0.45 && abs(cMid) < 0.45 && abs(cK1TailUse) < 0.50
        fPhi1ClassD2 = 'robust_residual_redistribution';
    elseif isfinite(cK1TailUse) && abs(cK1TailUse) >= 0.65
        fPhi1ClassD2 = 'backbone_error';
    else
        fPhi1ClassD2 = 'unresolved';
    end

    if isfinite(cK2TailUse) && isfinite(cK2GlobalUse) && phi2OutsideTailFrac >= 0.45 && abs(cK2GlobalUse) >= 0.45 && abs(cTail) < 0.60
        fPhi2ClassD2 = 'independent_global_mode';
        fKappa2ClassD2 = 'independent_coordinate';
    elseif isfinite(cK2TailUse) && phi2TailFrac >= 0.65 && abs(cK2TailUse) >= 0.70
        fPhi2ClassD2 = 'high_cdf_tail_correction';
        fKappa2ClassD2 = 'tail_burden_tracker';
    elseif isfinite(cK2TailUse) && phi2TailFrac >= 0.50 && abs(cK2TailUse) >= 0.50
        fPhi2ClassD2 = 'backbone_tail_residual';
        fKappa2ClassD2 = 'tail_burden_tracker';
    else
        fPhi2ClassD2 = 'unresolved_partial';
        fKappa2ClassD2 = 'unresolved_partial';
    end

    if strcmp(fPhi1ClassD2,'robust_residual_redistribution') && strcmp(fPhi2ClassD2,'independent_global_mode') && strcmp(fSupportAwareValid,'YES')
        fReadyStaticMap = 'PARTIAL';
    else
        fReadyStaticMap = 'NO';
    end

    classTbl = table( ...
        ["PHI1_CLASSIFICATION_D2";"PHI2_CLASSIFICATION_D2";"KAPPA2_CLASSIFICATION_D2"; ...
         "PHASE_D_UNRESOLVED_DUE_TO_GEOMETRY";"SUPPORT_AWARE_REEVALUATION_VALID"; ...
         "READY_FOR_OFFICIAL_STATIC_OBSERVABLE_MAPPING"], ...
        [string(fPhi1ClassD2);string(fPhi2ClassD2);string(fKappa2ClassD2); ...
         string(fUnresolvedDueGeometry);string(fSupportAwareValid);string(fReadyStaticMap)], ...
        'VariableNames', {'classification_item','value'});
    switchingWriteTableBothPaths(classTbl, repoRoot, runTables, 'switching_mode_relationship_d2_classification.csv');

    statusTbl = table( ...
        ["PHASE_D2_COMPLETED";"PHASE_D_UNRESOLVED_DUE_TO_GEOMETRY";"SUPPORT_AWARE_REEVALUATION_VALID"; ...
         "PHI1_CLASSIFICATION_D2";"PHI2_CLASSIFICATION_D2";"KAPPA2_CLASSIFICATION_D2"; ...
         "READY_FOR_OFFICIAL_STATIC_OBSERVABLE_MAPPING";"CLAIMS_UPDATE_ALLOWED";"CANONICAL_RUN_ID";"BACKBONE_SELECTION_REOPENED"], ...
        [string('YES');string(fUnresolvedDueGeometry);string(fSupportAwareValid); ...
         string(fPhi1ClassD2);string(fPhi2ClassD2);string(fKappa2ClassD2); ...
         string(fReadyStaticMap);string(fClaimsAllowed);string(canonicalRunId);string('NO')], ...
        ["Phase D2 completed under adjudicated current PT/CDF backbone."; ...
         sprintf("Strict-window invalid metrics: %d/%d", strictInvalidN, strictTotalN); ...
         "Support-aware reevaluation uses predeclared minimum support and expanded fallback windows."; ...
         sprintf("Phi1 class from valid-support metrics only (cos full/low/mid/tail = %.4f / %.4f / %.4f / %.4f).", cAll, cLow, cMid, cTail); ...
         sprintf("Phi2 class from support-aware global/tail evidence (corr k2-tail=%.4f, k2-global=%.4f).", cK2TailUse, cK2GlobalUse); ...
         sprintf("kappa2 class based on valid tail burden coupling test (strict=%.4f, expanded=%.4f).", cK2TailStrict, cK2TailExpanded); ...
         "Conservative: no promotion when unresolved/partial remains."; ...
         "Claims/context/snapshot/query updates remain forbidden."; ...
         "Locked canonical identity resolver used."; ...
         "Backbone selection not reopened."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_mode_relationship_d2_status.csv');

    lines = {};
    lines{end+1} = '# Phase D2: Geometry-aware mode relationship audit repair';
    lines{end+1} = '';
    lines{end+1} = '## Scope guards';
    lines{end+1} = sprintf('- Canonical lock via identity resolver: `CANONICAL_RUN_ID=%s`', canonicalRunId);
    lines{end+1} = '- Backbone selection reopened: NO (adjudicated current PT/CDF only).';
    lines{end+1} = '- Producer edits: none.';
    lines{end+1} = '- Canonical identity changes: none.';
    lines{end+1} = '- Claims/context/snapshot/query updates: forbidden.';
    lines{end+1} = '';
    lines{end+1} = '## D2 validity and support findings';
    lines{end+1} = sprintf('- Strict-window invalid metrics: %d / %d', strictInvalidN, strictTotalN);
    lines{end+1} = sprintf('- PHASE_D_UNRESOLVED_DUE_TO_GEOMETRY = %s', fUnresolvedDueGeometry);
    lines{end+1} = sprintf('- SUPPORT_AWARE_REEVALUATION_VALID = %s (min_support_n=%d)', fSupportAwareValid, minSupportN);
    lines{end+1} = '- Invalid metrics are excluded from negative evidence; expanded windows are predeclared fallback only.';
    lines{end+1} = '';
    lines{end+1} = '## Core support-aware metrics';
    lines{end+1} = sprintf('- phi1/phi2 cosine (full/low/mid/tail): %.4f / %.4f / %.4f / %.4f', cAll, cLow, cMid, cTail);
    lines{end+1} = sprintf('- corr(kappa2, tail burden): strict=%.4f, expanded=%.4f, used=%.4f', cK2TailStrict, cK2TailExpanded, cK2TailUse);
    lines{end+1} = sprintf('- corr(kappa2, global burden): %.4f', cK2GlobalUse);
    lines{end+1} = '';
    lines{end+1} = '## D2 classifications';
    lines{end+1} = sprintf('- PHI1_CLASSIFICATION_D2 = %s', fPhi1ClassD2);
    lines{end+1} = sprintf('- PHI2_CLASSIFICATION_D2 = %s', fPhi2ClassD2);
    lines{end+1} = sprintf('- KAPPA2_CLASSIFICATION_D2 = %s', fKappa2ClassD2);
    lines{end+1} = sprintf('- READY_FOR_OFFICIAL_STATIC_OBSERVABLE_MAPPING = %s', fReadyStaticMap);
    lines{end+1} = '- CLAIMS_UPDATE_ALLOWED = NO';
    runReportPath = fullfile(runReports, [baseName '.md']);
    repoReportPath = fullfile(repoRoot, 'reports', 'switching_mode_relationship_d2_geometry_aware_audit.md');
    switchingWriteTextLinesFile(runReportPath, lines, 'run_switching_mode_relationship_d2:WriteFail');
    switchingWriteTextLinesFile(repoReportPath, lines, 'run_switching_mode_relationship_d2:WriteFail');
    % Contract guard: repo-root report must always exist, including partial/unresolved outcomes.
    if exist(repoReportPath, 'file') ~= 2
        fid = fopen(repoReportPath, 'w');
        if fid < 0
            error('run_switching_mode_relationship_d2:RepoReportMissing', ...
                'Cannot create required repo report: %s', repoReportPath);
        end
        for il = 1:numel(lines)
            fprintf(fid, '%s\n', lines{il});
        end
        fclose(fid);
        if exist(repoReportPath, 'file') ~= 2
            error('run_switching_mode_relationship_d2:RepoReportMissing', ...
                'Required repo report was not created: %s', repoReportPath);
        end
    end

    fD2Completed = 'YES'; %#ok<NASGU>
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'Phase D2 geometry-aware audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_mode_relationship_d2_geometry_aware_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    statusTbl = table( ...
        ["PHASE_D2_COMPLETED";"PHASE_D_UNRESOLVED_DUE_TO_GEOMETRY";"SUPPORT_AWARE_REEVALUATION_VALID"; ...
         "PHI1_CLASSIFICATION_D2";"PHI2_CLASSIFICATION_D2";"KAPPA2_CLASSIFICATION_D2"; ...
         "READY_FOR_OFFICIAL_STATIC_OBSERVABLE_MAPPING";"CLAIMS_UPDATE_ALLOWED"], ...
        ["NO";"PARTIAL";"NO";"unresolved";"unresolved_partial";"unresolved_partial";"NO";"NO"], ...
        repmat(string(ME.message), 8, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_mode_relationship_d2_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_mode_relationship_d2_status.csv'));

    lines = {};
    lines{end+1} = '# Phase D2 geometry-aware audit — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_mode_relationship_d2:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_mode_relationship_d2_geometry_aware_audit.md'), lines, 'run_switching_mode_relationship_d2:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Phase D2 geometry-aware audit failed'}, true);
    rethrow(ME);
end

function [metricVal, validFlag, invalidClass, invalidCause, nPoints] = evalMetric(metricName, a, b, mask, minSupportN)
a = a(:); b = b(:); mask = mask(:);
m = mask & isfinite(a) & isfinite(b);
nPoints = sum(m);
if nPoints == 0
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_GEOMETRY"; invalidCause = "empty_window"; return;
end
if nPoints < minSupportN
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_GEOMETRY"; invalidCause = "insufficient_points"; return;
end
aa = a(m); bb = b(m);
if std(aa) <= eps || std(bb) <= eps
    if metricName == "phi1_phi2_correlation"
        metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; invalidCause = "zero_variance"; return;
    end
end
if metricName == "phi1_phi2_cosine"
    denom = norm(aa) * norm(bb);
    if denom <= eps
        metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; invalidCause = "near_zero_norm"; return;
    end
    metricVal = dot(aa, bb) / denom;
else
    rr = corrcoef(aa, bb);
    if numel(rr) < 4 || ~isfinite(rr(1,2))
        metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; invalidCause = "missing_alignment"; return;
    end
    metricVal = rr(1,2);
end
if ~isfinite(metricVal)
    validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; invalidCause = "numerical_issue";
else
    validFlag = "YES"; invalidClass = "VALID"; invalidCause = "";
end
end

function [metricVal, validFlag, invalidClass, invalidCause, nPoints] = evalCorrMetric(x, y, minSupportN)
x = x(:); y = y(:);
m = isfinite(x) & isfinite(y);
nPoints = sum(m);
if nPoints == 0
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_GEOMETRY"; invalidCause = "empty_window"; return;
end
if nPoints < minSupportN
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_GEOMETRY"; invalidCause = "insufficient_points"; return;
end
xx = x(m); yy = y(m);
if std(xx) <= eps || std(yy) <= eps
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; invalidCause = "zero_variance"; return;
end
rr = corrcoef(xx, yy);
if numel(rr) < 4 || ~isfinite(rr(1,2))
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; invalidCause = "missing_alignment"; return;
end
metricVal = rr(1,2);
if ~isfinite(metricVal)
    validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; invalidCause = "numerical_issue";
else
    validFlag = "YES"; invalidClass = "VALID"; invalidCause = "";
end
end

function out = pickMetric(tbl, metricName, windowName)
m = tbl.metric_name==metricName & tbl.window_name==windowName & tbl.validity_flag=="YES";
if any(m)
    out = tbl.metric_value(find(m, 1, 'first'));
else
    out = NaN;
end
end

function out = pickBestStrictOrFallback(tbl, metricName, strictWindowName)
out = pickMetric(tbl, metricName, strictWindowName);
if isfinite(out), return; end
expWindow = replace(strictWindowName, "strict_", "expanded_") + "_fallback_for_" + strictWindowName;
out = pickMetric(tbl, metricName, expWindow);
end

function out = pickBestStrictOrExpandedCorr(tbl, metricName)
out = pickMetric(tbl, metricName, "strict_tail_over_mid");
if isfinite(out), return; end
out = pickMetric(tbl, metricName, "expanded_tail_over_mid");
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end

function out = normalizeIdentityField(v)
out = strtrim(string(v));
out = regexprep(out, "^\xFEFF", "");
end
