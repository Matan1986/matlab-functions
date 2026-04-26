clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_mode_relationship_d4_adaptive_rank_audit';

% Required flags defaults
fD4Completed = 'NO';
fSupportCollapse = 'YES';
fWindowsCompatible = 'NO';
fPhaseResolved = 'NO';
fPhi1Class = 'unresolved';
fPhi2Class = 'unresolved_partial';
fKappa2Class = 'unresolved_partial';
fReadyStageE = 'NO';
fClaimsAllowed = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_mode_relationship_d4_adaptive_rank';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Phase D4 adaptive-rank diagnostic initialized'}, false);

    s1Path = fullfile(repoRoot, 'tables', 'switching_backbone_selection_run_status.csv');
    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    reqPre = {s1Path, idPath, ampPath};
    for i = 1:numel(reqPre)
        if exist(reqPre{i}, 'file') ~= 2
            error('run_switching_mode_relationship_d4_rank:MissingInput', 'Missing required input: %s', reqPre{i});
        end
    end

    s1 = readtable(s1Path, 'TextType', 'string');
    iCurr = find(strcmpi(strtrim(s1.check), 'CURRENT_PTCDF_BACKBONE_SELECTED'), 1);
    iAllow = find(strcmpi(strtrim(s1.check), 'PHASE_D_ALLOWED_AFTER_SELECTION'), 1);
    if isempty(iCurr) || isempty(iAllow)
        error('run_switching_mode_relationship_d4_rank:S1Schema', 'S1 status table missing required checks.');
    end
    if upper(strtrim(s1.result(iCurr))) ~= "YES" || upper(strtrim(s1.result(iAllow))) ~= "YES"
        error('run_switching_mode_relationship_d4_rank:S1Gate', 'Phase D4 blocked by S1 selection gate.');
    end

    idRaw = readcell(idPath, 'Delimiter', ',');
    canonicalRunId = "";
    for r = 2:size(idRaw,1)
        k = strtrim(string(idRaw{r,1}));
        k = regexprep(k, "^\xFEFF", "");
        if strcmpi(k, "CANONICAL_RUN_ID")
            canonicalRunId = strtrim(string(idRaw{r,2}));
            break;
        end
    end
    if strlength(canonicalRunId) == 0
        error('run_switching_mode_relationship_d4_rank:Identity', 'CANONICAL_RUN_ID missing in switching_canonical_identity.csv.');
    end

    sLongPath = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables', 'switching_canonical_S_long.csv');
    phi1Path = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables', 'switching_canonical_phi1.csv');
    req = {sLongPath, phi1Path};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_mode_relationship_d4_rank:IdentityAnchorMissing', ...
                'Identity-anchored canonical artifact missing: %s', req{i});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);

    T = double(sLong.T_K); I = double(sLong.current_mA);
    S = double(sLong.S_percent); B = double(sLong.S_model_pt_percent);
    v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B);
    T = T(v); I = I(v); S = S(v); B = B(v);
    G = groupsummary(table(T,I,S,B), {'T','I'}, 'mean', {'S','B'});
    allT = unique(double(G.T), 'sorted');
    allI = unique(double(G.I), 'sorted');
    nT = numel(allT); nI = numel(allI);

    Smap = NaN(nT,nI); Bmap = NaN(nT,nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(G.T)-allT(it)) < 1e-9 & abs(double(G.I)-allI(ii)) < 1e-9;
            if any(m)
                j = find(m,1);
                Smap(it,ii) = double(G.mean_S(j));
                Bmap(it,ii) = double(G.mean_B(j));
            end
        end
    end
    validMap = isfinite(Smap) & isfinite(Bmap);

    % Rank coordinate: per-temperature index order, normalized to [0,1]
    xRankMap = NaN(nT,nI);
    for it = 1:nT
        idx = find(validMap(it,:));
        n = numel(idx);
        if n <= 1, continue; end
        xRankMap(it, idx) = (0:(n-1)) / (n-1);
    end

    % Discrete windows for 7-point rank grid
    rankIdx = (1:nI);
    lowI = ismember(rankIdx, [1 2 3]);
    midI = ismember(rankIdx, [3 4 5]);
    highI = ismember(rankIdx, [5 6 7]);
    fullI = true(1,nI);
    w13 = ismember(rankIdx, [1 2 3]);
    w24 = ismember(rankIdx, [2 3 4]);
    w35 = ismember(rankIdx, [3 4 5]);
    w46 = ismember(rankIdx, [4 5 6]);
    w57 = ismember(rankIdx, [5 6 7]);

    winNames = ["full";"low_1_3";"mid_3_5";"high_5_7";"win_1_3";"win_2_4";"win_3_5";"win_4_6";"win_5_7"];
    winMasks = {fullI, lowI, midI, highI, w13, w24, w35, w46, w57};
    minSupportNLocal = 3;

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

    % Support table with explicit valid-point counts
    supportRows = table();
    perTRows = table();
    for iw = 1:numel(winNames)
        mW = winMasks{iw}(:)';
        nGlobal = sum(mW & isfinite(phi1(:)') & isfinite(phi2(:)'));
        supportRows = [supportRows; table("all_T", winNames(iw), nGlobal, nGlobal/max(nI,1), minSupportNLocal, string(yesNo(nGlobal >= minSupportNLocal)), ...
            'VariableNames', {'T_scope','window_name','support_n','support_fraction','min_support_n','support_ok'})]; %#ok<AGROW>
        for it = 1:nT
            rowValid = validMap(it,:);
            nTI = sum(mW & rowValid);
            perTRows = [perTRows; table(string(allT(it)), sum(rowValid), nTI, ...
                'VariableNames', {'T_scope','valid_points_in_T','window_points_in_T'})]; %#ok<AGROW>
            supportRows = [supportRows; table(string(allT(it)), winNames(iw), nTI, nTI/max(sum(rowValid),1), minSupportNLocal, string(yesNo(nTI >= minSupportNLocal)), ...
                'VariableNames', {'T_scope','window_name','support_n','support_fraction','min_support_n','support_ok'})]; %#ok<AGROW>
        end
    end
    supportRows = outerjoin(supportRows, unique(perTRows,'rows'), 'Keys', 'T_scope', 'MergeKeys', true);
    switchingWriteTableBothPaths(supportRows, repoRoot, runTables, 'switching_mode_relationship_d4_adaptive_rank_window_support.csv');

    metricsRows = table();
    baseMetrics = {
        "phi1_phi2_cosine", "full", fullI(:), 1;
        "phi1_phi2_correlation", "full", fullI(:), 1;
        "phi1_phi2_cosine", "low_1_3", lowI(:), minSupportNLocal;
        "phi1_phi2_correlation", "low_1_3", lowI(:), minSupportNLocal;
        "phi1_phi2_cosine", "mid_3_5", midI(:), minSupportNLocal;
        "phi1_phi2_correlation", "mid_3_5", midI(:), minSupportNLocal;
        "phi1_phi2_cosine", "high_5_7", highI(:), minSupportNLocal;
        "phi1_phi2_correlation", "high_5_7", highI(:), minSupportNLocal;
        };
    for i = 1:size(baseMetrics,1)
        [mv,vf,ic,np] = evalMetric(string(baseMetrics{i,1}), phi1, phi2, logical(baseMetrics{i,3}), baseMetrics{i,4});
        metricsRows = [metricsRows; table(string(baseMetrics{i,1}), string(baseMetrics{i,2}), mv, vf, ic, np, ...
            'VariableNames', {'metric_name','window_name','metric_value','validity_flag','invalid_class','n_points'})]; %#ok<AGROW>
    end

    % Optional sliding windows
    slideNames = ["win_1_3";"win_2_4";"win_3_5";"win_4_6";"win_5_7"];
    slideMasks = {w13(:),w24(:),w35(:),w46(:),w57(:)};
    for i = 1:numel(slideNames)
        [mv,vf,ic,np] = evalMetric("phi1_phi2_cosine", phi1, phi2, logical(slideMasks{i}), minSupportNLocal);
        metricsRows = [metricsRows; table("phi1_phi2_cosine", slideNames(i), mv, vf, ic, np, ...
            'VariableNames', {'metric_name','window_name','metric_value','validity_flag','invalid_class','n_points'})]; %#ok<AGROW>
    end

    tailBurdenStrict = mean(R0(:,highI).^2, 2, 'omitnan') ./ max(mean(R0(:,midI).^2, 2, 'omitnan'), eps);
    tailBurdenSlide = mean(R0(:,w57).^2, 2, 'omitnan') ./ max(mean(R0(:,w35).^2, 2, 'omitnan'), eps);
    globalBurden = mean(R0.^2, 2, 'omitnan');
    [cK2Tail, v1, i1, n1] = evalCorr(kappa2(:), tailBurdenStrict(:), minSupportNLocal);
    [cK2TailSlide, v2, i2, n2] = evalCorr(kappa2(:), tailBurdenSlide(:), minSupportNLocal);
    [cK2Global, v3, i3, n3] = evalCorr(kappa2(:), globalBurden(:), minSupportNLocal);
    [cK1Tail, v4, i4, n4] = evalCorr(kappa1(:), tailBurdenStrict(:), minSupportNLocal);
    metricsRows = [metricsRows; table( ...
        ["kappa2_vs_tail_burden_corr";"kappa2_vs_tail_burden_corr_sliding";"kappa2_vs_global_burden_corr";"kappa1_vs_tail_burden_corr"], ...
        ["high_5_7_over_mid_3_5";"win_5_7_over_win_3_5";"full";"high_5_7_over_mid_3_5"], ...
        [cK2Tail;cK2TailSlide;cK2Global;cK1Tail], [v1;v2;v3;v4], [i1;i2;i3;i4], [n1;n2;n3;n4], ...
        'VariableNames', {'metric_name','window_name','metric_value','validity_flag','invalid_class','n_points'})];
    switchingWriteTableBothPaths(metricsRows, repoRoot, runTables, 'switching_mode_relationship_d4_adaptive_rank_metrics.csv');

    % D2/D3-style classification structure
    cAll = pickMetric(metricsRows, "phi1_phi2_cosine", "full");
    cLow = pickMetric(metricsRows, "phi1_phi2_cosine", "low_1_3");
    cMid = pickMetric(metricsRows, "phi1_phi2_cosine", "mid_3_5");
    cHigh = pickMetric(metricsRows, "phi1_phi2_cosine", "high_5_7");
    cK2TailUse = pickMetric(metricsRows, "kappa2_vs_tail_burden_corr", "high_5_7_over_mid_3_5");
    if ~isfinite(cK2TailUse)
        cK2TailUse = pickMetric(metricsRows, "kappa2_vs_tail_burden_corr_sliding", "win_5_7_over_win_3_5");
    end
    cK2GlobalUse = pickMetric(metricsRows, "kappa2_vs_global_burden_corr", "full");
    cK1TailUse = pickMetric(metricsRows, "kappa1_vs_tail_burden_corr", "high_5_7_over_mid_3_5");

    phi2TailFrac = sum(phi2(highI(:)).^2) / max(sum(phi2.^2), eps);
    phi2OutsideTailFrac = 1 - phi2TailFrac;

    if isfinite(cAll) && isfinite(cLow) && isfinite(cMid) && abs(cAll) < 0.35 && abs(cLow) < 0.45 && abs(cMid) < 0.45 && abs(cK1TailUse) < 0.50
        fPhi1Class = 'robust_residual_redistribution';
    elseif isfinite(cK1TailUse) && abs(cK1TailUse) >= 0.65
        fPhi1Class = 'backbone_error';
    else
        fPhi1Class = 'unresolved';
    end

    if isfinite(cK2TailUse) && isfinite(cK2GlobalUse) && phi2OutsideTailFrac >= 0.45 && abs(cK2GlobalUse) >= 0.45 && abs(cHigh) < 0.60
        fPhi2Class = 'independent_global_mode';
        fKappa2Class = 'independent_coordinate';
    elseif isfinite(cK2TailUse) && phi2TailFrac >= 0.65 && abs(cK2TailUse) >= 0.70
        fPhi2Class = 'high_cdf_tail_correction';
        fKappa2Class = 'tail_burden_tracker';
    elseif isfinite(cK2TailUse) && phi2TailFrac >= 0.50 && abs(cK2TailUse) >= 0.50
        fPhi2Class = 'backbone_tail_residual';
        fKappa2Class = 'tail_burden_tracker';
    else
        fPhi2Class = 'unresolved_partial';
        fKappa2Class = 'unresolved_partial';
    end

    strictCore = supportRows.T_scope=="all_T" & ismember(supportRows.window_name, ["low_1_3","mid_3_5","high_5_7"]);
    nCorePass = sum(supportRows.support_ok(strictCore) == "YES");
    if nCorePass == 3
        fSupportCollapse = 'NO';
        fWindowsCompatible = 'YES';
    elseif nCorePass >= 1
        fSupportCollapse = 'PARTIAL';
        fWindowsCompatible = 'YES';
    else
        fSupportCollapse = 'YES';
        fWindowsCompatible = 'NO';
    end

    if strcmp(fPhi1Class,'unresolved') || strcmp(fPhi2Class,'unresolved_partial') || strcmp(fKappa2Class,'unresolved_partial')
        fPhaseResolved = 'PARTIAL';
    else
        fPhaseResolved = 'YES';
    end
    if strcmp(fPhaseResolved,'YES')
        fReadyStageE = 'YES';
    else
        fReadyStageE = 'NO';
    end

    classTbl = table( ...
        ["D4_COMPLETED";"SUPPORT_COLLAPSE_IN_D4";"WINDOWS_COMPATIBLE_WITH_GRID";"PHASE_D_RESOLVED_IN_D4"; ...
         "PHI1_CLASSIFICATION_D4";"PHI2_CLASSIFICATION_D4";"KAPPA2_CLASSIFICATION_D4"; ...
         "READY_FOR_STAGE_E_FROM_D4";"CLAIMS_UPDATE_ALLOWED"], ...
        [string('YES');string(fSupportCollapse);string(fWindowsCompatible);string(fPhaseResolved); ...
         string(fPhi1Class);string(fPhi2Class);string(fKappa2Class);string(fReadyStageE);string(fClaimsAllowed)], ...
        'VariableNames', {'classification_item','value'});
    switchingWriteTableBothPaths(classTbl, repoRoot, runTables, 'switching_mode_relationship_d4_adaptive_rank_classification.csv');

    statusTbl = table( ...
        ["D4_COMPLETED";"SUPPORT_COLLAPSE_IN_D4";"WINDOWS_COMPATIBLE_WITH_GRID";"PHASE_D_RESOLVED_IN_D4"; ...
         "PHI1_CLASSIFICATION_D4";"PHI2_CLASSIFICATION_D4";"KAPPA2_CLASSIFICATION_D4"; ...
         "READY_FOR_STAGE_E_FROM_D4";"CLAIMS_UPDATE_ALLOWED";"CANONICAL_RUN_ID"], ...
        [string('YES');string(fSupportCollapse);string(fWindowsCompatible);string(fPhaseResolved); ...
         string(fPhi1Class);string(fPhi2Class);string(fKappa2Class); ...
         string(fReadyStageE);string(fClaimsAllowed);string(canonicalRunId)], ...
        ["D4 adaptive-rank diagnostic completed."; ...
         "Geometry/support result under min_support_n=3 local-window policy."; ...
         "Discrete rank windows (1-3,3-5,5-7) evaluated for compatibility with 7-point grid."; ...
         "Mode-relationship result under D2/D3-style classification structure."; ...
         sprintf("Phi1 class from adaptive-rank metrics (full/low/mid/high cos=%.4f/%.4f/%.4f/%.4f).", cAll, cLow, cMid, cHigh); ...
         sprintf("Phi2 class from adaptive-rank coupling evidence (k2 tail=%.4f, k2 global=%.4f).", cK2TailUse, cK2GlobalUse); ...
         sprintf("kappa2 class from adaptive-rank tail/global coupling (tail=%.4f).", cK2TailUse); ...
         "Stage-E readiness from D4 diagnostic only."; ...
         "Claims/context/snapshot/query updates remain forbidden."; ...
         "Identity-locked canonical run used."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_mode_relationship_d4_adaptive_rank_status.csv');

    lines = {};
    lines{end+1} = '# Phase D4 adaptive-rank diagnostic audit';
    lines{end+1} = '';
    lines{end+1} = sprintf('- CANONICAL_RUN_ID: `%s`', canonicalRunId);
    lines{end+1} = '- Coordinate: x_rank on canonical 7-point current grid.';
    lines{end+1} = '- Local window support policy: min_support_n=3.';
    lines{end+1} = '';
    lines{end+1} = '## 1) Geometry/support result';
    lines{end+1} = sprintf('- SUPPORT_COLLAPSE_IN_D4 = %s', fSupportCollapse);
    lines{end+1} = sprintf('- WINDOWS_COMPATIBLE_WITH_GRID = %s', fWindowsCompatible);
    lines{end+1} = '';
    lines{end+1} = '## 2) Mode-relationship result';
    lines{end+1} = sprintf('- PHASE_D_RESOLVED_IN_D4 = %s', fPhaseResolved);
    lines{end+1} = sprintf('- PHI1_CLASSIFICATION_D4 = %s', fPhi1Class);
    lines{end+1} = sprintf('- PHI2_CLASSIFICATION_D4 = %s', fPhi2Class);
    lines{end+1} = sprintf('- KAPPA2_CLASSIFICATION_D4 = %s', fKappa2Class);
    lines{end+1} = sprintf('- READY_FOR_STAGE_E_FROM_D4 = %s', fReadyStageE);
    lines{end+1} = '';
    lines{end+1} = '## 3) Diagnostic artifact check vs D3';
    lines{end+1} = '- D4 explicitly uses support-compatible discrete rank windows; compare SUPPORT_COLLAPSE_IN_D4 to prior D3 support collapse result.';
    lines{end+1} = '- CLAIMS_UPDATE_ALLOWED = NO';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_mode_relationship_d4_rank:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_mode_relationship_d4_adaptive_rank_audit.md'), lines, 'run_switching_mode_relationship_d4_rank:WriteFail');

    fD4Completed = 'YES'; %#ok<NASGU>
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'Phase D4 adaptive-rank diagnostic completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_mode_relationship_d4_adaptive_rank_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    statusTbl = table( ...
        ["D4_COMPLETED";"SUPPORT_COLLAPSE_IN_D4";"WINDOWS_COMPATIBLE_WITH_GRID";"PHASE_D_RESOLVED_IN_D4"; ...
         "PHI1_CLASSIFICATION_D4";"PHI2_CLASSIFICATION_D4";"KAPPA2_CLASSIFICATION_D4";"READY_FOR_STAGE_E_FROM_D4";"CLAIMS_UPDATE_ALLOWED"], ...
        ["NO";"YES";"NO";"NO";"unresolved";"unresolved_partial";"unresolved_partial";"NO";"NO"], ...
        repmat(string(ME.message), 9, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_mode_relationship_d4_adaptive_rank_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_mode_relationship_d4_adaptive_rank_status.csv'));

    lines = {};
    lines{end+1} = '# Phase D4 adaptive-rank diagnostic — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_mode_relationship_d4_rank:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_mode_relationship_d4_adaptive_rank_audit.md'), lines, 'run_switching_mode_relationship_d4_rank:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Phase D4 adaptive-rank diagnostic failed'}, true);
    rethrow(ME);
end

function [metricVal, validFlag, invalidClass, nPoints] = evalMetric(metricName, a, b, mask, minSupportN)
a = a(:); b = b(:); mask = mask(:);
m = mask & isfinite(a) & isfinite(b);
nPoints = sum(m);
if nPoints < minSupportN
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_GEOMETRY"; return;
end
aa = a(m); bb = b(m);
if metricName == "phi1_phi2_cosine"
    denom = norm(aa) * norm(bb);
    if denom <= eps, metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; return; end
    metricVal = dot(aa, bb) / denom;
else
    rr = corrcoef(aa, bb);
    if numel(rr) < 4 || ~isfinite(rr(1,2))
        metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; return;
    end
    metricVal = rr(1,2);
end
validFlag = "YES"; invalidClass = "VALID";
end

function [metricVal, validFlag, invalidClass, nPoints] = evalCorr(x, y, minSupportN)
x = x(:); y = y(:);
m = isfinite(x) & isfinite(y);
nPoints = sum(m);
if nPoints < minSupportN
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_GEOMETRY"; return;
end
xx = x(m); yy = y(m);
if std(xx) <= eps || std(yy) <= eps
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; return;
end
rr = corrcoef(xx, yy);
if numel(rr) < 4 || ~isfinite(rr(1,2))
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; return;
end
metricVal = rr(1,2); validFlag = "YES"; invalidClass = "VALID";
end

function out = pickMetric(tbl, metricName, windowName)
m = tbl.metric_name==metricName & tbl.window_name==windowName & tbl.validity_flag=="YES";
if any(m), out = tbl.metric_value(find(m,1,'first')); else, out = NaN; end
end

function y = yesNo(tf)
if tf, y = "YES"; else, y = "NO"; end
end
