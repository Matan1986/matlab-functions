clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_mode_relationship_d3_rank_audit';

% Required flags defaults
fSupportCollapseRank = 'YES';
fPhaseDResolvedRank = 'NO';
fPhi1Class = 'unresolved';
fPhi2Class = 'unresolved_partial';
fKappa2Class = 'unresolved_partial';
fReadyStageE = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_mode_relationship_d3_rank';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Phase D3 rank diagnostic initialized'}, false);

    s1Path = fullfile(repoRoot, 'tables', 'switching_backbone_selection_run_status.csv');
    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    reqPre = {s1Path, idPath, ampPath};
    for i = 1:numel(reqPre)
        if exist(reqPre{i}, 'file') ~= 2
            error('run_switching_mode_relationship_d3_rank:MissingInput', 'Missing required input: %s', reqPre{i});
        end
    end

    s1 = readtable(s1Path, 'TextType', 'string');
    iCurr = find(strcmpi(strtrim(s1.check), 'CURRENT_PTCDF_BACKBONE_SELECTED'), 1);
    iAllow = find(strcmpi(strtrim(s1.check), 'PHASE_D_ALLOWED_AFTER_SELECTION'), 1);
    if isempty(iCurr) || isempty(iAllow)
        error('run_switching_mode_relationship_d3_rank:S1Schema', 'S1 status table missing required checks.');
    end
    if upper(strtrim(s1.result(iCurr))) ~= "YES" || upper(strtrim(s1.result(iAllow))) ~= "YES"
        error('run_switching_mode_relationship_d3_rank:S1Gate', 'Phase D3 blocked by S1 selection gate.');
    end

    idRaw = readcell(idPath, 'Delimiter', ',');
    canonicalRunId = "";
    for r = 2:size(idRaw,1)
        f = strtrim(string(idRaw{r,1}));
        f = regexprep(f, "^\xFEFF", "");
        if strcmpi(f, "CANONICAL_RUN_ID")
            canonicalRunId = strtrim(string(idRaw{r,2}));
            break;
        end
    end
    if strlength(canonicalRunId) == 0
        error('run_switching_mode_relationship_d3_rank:Identity', 'CANONICAL_RUN_ID missing in switching_canonical_identity.csv.');
    end

    sLongPath = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables', 'switching_canonical_S_long.csv');
    phi1Path = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables', 'switching_canonical_phi1.csv');
    req = {sLongPath, phi1Path};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_mode_relationship_d3_rank:IdentityAnchorMissing', ...
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

    % Rank coordinate per temperature row, normalized to [0,1].
    xRankMap = NaN(nT, nI);
    for it = 1:nT
        idx = find(validMap(it,:));
        n = numel(idx);
        if n <= 1, continue; end
        xRankMap(it, idx) = (0:(n-1)) / (n-1);
    end
    xRankAxis = nanmean(xRankMap, 1);

    strictLow = xRankAxis >= 0.00 & xRankAxis < 0.20;
    strictMid = xRankAxis > 0.40 & xRankAxis < 0.60;
    strictHigh = xRankAxis >= 0.80 & xRankAxis <= 1.00;
    strictTail = xRankAxis >= 0.80;
    expandedLow = xRankAxis >= 0.00 & xRankAxis < 0.30;
    expandedMid = xRankAxis >= 0.35 & xRankAxis <= 0.65;
    expandedHigh = xRankAxis >= 0.70 & xRankAxis <= 1.00;
    expandedTail = xRankAxis >= 0.70;

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

    minSupportN = 5;
    winNames = ["strict_low";"strict_mid";"strict_high";"strict_tail";"expanded_low";"expanded_mid";"expanded_high";"expanded_tail"];
    winMasks = {strictLow, strictMid, strictHigh, strictTail, expandedLow, expandedMid, expandedHigh, expandedTail};

    supportRows = table();
    for iw = 1:numel(winNames)
        mW = winMasks{iw}(:)';
        nCurr = sum(mW & isfinite(phi1(:)') & isfinite(phi2(:)'));
        supportRows = [supportRows; table("all_T", winNames(iw), nCurr, nCurr/max(nI,1), minSupportN, string(yesNo(nCurr >= minSupportN)), ...
            'VariableNames', {'T_scope','window_name','support_n','support_fraction','min_support_n','support_ok'})]; %#ok<AGROW>
        for it = 1:nT
            rowValid = validMap(it,:);
            nTI = sum(mW & rowValid);
            supportRows = [supportRows; table(string(allT(it)), winNames(iw), nTI, nTI/max(sum(rowValid),1), minSupportN, string(yesNo(nTI >= minSupportN)), ...
                'VariableNames', {'T_scope','window_name','support_n','support_fraction','min_support_n','support_ok'})]; %#ok<AGROW>
        end
    end
    switchingWriteTableBothPaths(supportRows, repoRoot, runTables, 'switching_mode_relationship_d3_rank_window_support.csv');

    metricsRows = table();
    spec = {
        "phi1_phi2_cosine","full_domain",true(size(phi1));
        "phi1_phi2_correlation","full_domain",true(size(phi1));
        "phi1_phi2_cosine","strict_low",strictLow(:);
        "phi1_phi2_correlation","strict_low",strictLow(:);
        "phi1_phi2_cosine","strict_mid",strictMid(:);
        "phi1_phi2_correlation","strict_mid",strictMid(:);
        "phi1_phi2_cosine","strict_high",strictHigh(:);
        "phi1_phi2_correlation","strict_high",strictHigh(:);
        "phi1_phi2_cosine","strict_tail",strictTail(:);
        "phi1_phi2_correlation","strict_tail",strictTail(:)
        };
    for i = 1:size(spec,1)
        [mv,vf,ic,npt] = evalMetric(string(spec{i,1}), phi1, phi2, logical(spec{i,3}), minSupportN);
        metricsRows = [metricsRows; table(string(spec{i,1}), string(spec{i,2}), mv, vf, ic, npt, ...
            'VariableNames', {'metric_name','window_name','metric_value','validity_flag','invalid_class','n_points'})]; %#ok<AGROW>
    end

    strictMidMask = strictMid(:)'; strictTailMask = strictTail(:)';
    expandedMidMask = expandedMid(:)'; expandedTailMask = expandedTail(:)';
    tailBurdenStrict = mean(R0(:,strictTailMask).^2, 2, 'omitnan') ./ max(mean(R0(:,strictMidMask).^2, 2, 'omitnan'), eps);
    tailBurdenExpanded = mean(R0(:,expandedTailMask).^2, 2, 'omitnan') ./ max(mean(R0(:,expandedMidMask).^2, 2, 'omitnan'), eps);
    globalBurden = mean(R0.^2, 2, 'omitnan');

    [cK2TailStrict, v1, ic1, n1] = evalCorr(kappa2(:), tailBurdenStrict(:), minSupportN);
    [cK2TailExpanded, v2, ic2, n2] = evalCorr(kappa2(:), tailBurdenExpanded(:), minSupportN);
    [cK2Global, v3, ic3, n3] = evalCorr(kappa2(:), globalBurden(:), minSupportN);
    [cK1TailStrict, v4, ic4, n4] = evalCorr(kappa1(:), tailBurdenStrict(:), minSupportN);
    metricsRows = [metricsRows; table( ...
        ["kappa2_vs_tail_burden_corr";"kappa2_vs_tail_burden_corr";"kappa2_vs_global_burden_corr";"kappa1_vs_tail_burden_corr"], ...
        ["strict_tail_over_mid";"expanded_tail_over_mid";"full_domain";"strict_tail_over_mid"], ...
        [cK2TailStrict;cK2TailExpanded;cK2Global;cK1TailStrict], [v1;v2;v3;v4], [ic1;ic2;ic3;ic4], [n1;n2;n3;n4], ...
        'VariableNames', {'metric_name','window_name','metric_value','validity_flag','invalid_class','n_points'})];
    switchingWriteTableBothPaths(metricsRows, repoRoot, runTables, 'switching_mode_relationship_d3_rank_metrics.csv');

    cAll = pickMetric(metricsRows, "phi1_phi2_cosine", "full_domain");
    cLow = pickMetric(metricsRows, "phi1_phi2_cosine", "strict_low");
    cMid = pickMetric(metricsRows, "phi1_phi2_cosine", "strict_mid");
    cTail = pickMetric(metricsRows, "phi1_phi2_cosine", "strict_tail");
    cK2GlobalUse = pickMetric(metricsRows, "kappa2_vs_global_burden_corr", "full_domain");
    cK2TailUse = pickMetric(metricsRows, "kappa2_vs_tail_burden_corr", "strict_tail_over_mid");
    if ~isfinite(cK2TailUse)
        cK2TailUse = pickMetric(metricsRows, "kappa2_vs_tail_burden_corr", "expanded_tail_over_mid");
    end
    cK1TailUse = pickMetric(metricsRows, "kappa1_vs_tail_burden_corr", "strict_tail_over_mid");

    phi2TailFrac = sum(phi2(strictTailMask).^2) / max(sum(phi2.^2), eps);
    phi2OutsideTailFrac = 1 - phi2TailFrac;

    % Same classification logic as D2.
    if isfinite(cAll) && isfinite(cLow) && isfinite(cMid) && abs(cAll) < 0.35 && abs(cLow) < 0.45 && abs(cMid) < 0.45 && abs(cK1TailUse) < 0.50
        fPhi1Class = 'robust_residual_redistribution';
    elseif isfinite(cK1TailUse) && abs(cK1TailUse) >= 0.65
        fPhi1Class = 'backbone_error';
    else
        fPhi1Class = 'unresolved';
    end

    if isfinite(cK2TailUse) && isfinite(cK2GlobalUse) && phi2OutsideTailFrac >= 0.45 && abs(cK2GlobalUse) >= 0.45 && abs(cTail) < 0.60
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

    if strcmp(fPhi1Class,'unresolved') || strcmp(fPhi2Class,'unresolved_partial') || strcmp(fKappa2Class,'unresolved_partial')
        fPhaseDResolvedRank = 'PARTIAL';
    else
        fPhaseDResolvedRank = 'YES';
    end

    if strcmp(fPhaseDResolvedRank,'YES')
        fReadyStageE = 'YES';
    else
        fReadyStageE = 'NO';
    end

    % Collapse flag from strict rank windows.
    strictSupportAll = supportRows.T_scope=="all_T" & startsWith(supportRows.window_name,"strict_");
    if any(supportRows.support_ok(strictSupportAll) == "NO")
        fSupportCollapseRank = 'YES';
    else
        fSupportCollapseRank = 'NO';
    end

    classTbl = table( ...
        ["SUPPORT_COLLAPSE_IN_RANK";"PHASE_D_RESOLVED_IN_RANK";"PHI1_CLASSIFICATION_RANK"; ...
         "PHI2_CLASSIFICATION_RANK";"KAPPA2_CLASSIFICATION_RANK";"READY_FOR_STAGE_E_FROM_RANK"], ...
        [string(fSupportCollapseRank);string(fPhaseDResolvedRank);string(fPhi1Class); ...
         string(fPhi2Class);string(fKappa2Class);string(fReadyStageE)], ...
        'VariableNames', {'classification_item','value'});
    switchingWriteTableBothPaths(classTbl, repoRoot, runTables, 'switching_mode_relationship_d3_rank_classification.csv');

    statusTbl = table( ...
        ["SUPPORT_COLLAPSE_IN_RANK";"PHASE_D_RESOLVED_IN_RANK";"PHI1_CLASSIFICATION_RANK"; ...
         "PHI2_CLASSIFICATION_RANK";"KAPPA2_CLASSIFICATION_RANK";"READY_FOR_STAGE_E_FROM_RANK";"CANONICAL_RUN_ID"], ...
        [string(fSupportCollapseRank);string(fPhaseDResolvedRank);string(fPhi1Class); ...
         string(fPhi2Class);string(fKappa2Class);string(fReadyStageE);string(canonicalRunId)], ...
        ["Support collapse decision from strict rank-window support counts (min_support_n=5)."; ...
         "Resolved status under rank-coordinate diagnostic using D2-equivalent rules."; ...
         sprintf("Phi1 class from rank-windowed/full metrics (cos full/low/mid/tail=%.4f/%.4f/%.4f/%.4f).", cAll, cLow, cMid, cTail); ...
         sprintf("Phi2 class from rank-windowed coupling evidence (k2 tail=%.4f, k2 global=%.4f).", cK2TailUse, cK2GlobalUse); ...
         sprintf("kappa2 class from strict/expanded rank-tail burden coupling (strict=%.4f expanded=%.4f).", cK2TailStrict, cK2TailExpanded); ...
         "Stage-E readiness from rank diagnostic only."; ...
         "Identity-locked canonical run used."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_mode_relationship_d3_rank_status.csv');

    lines = {};
    lines{end+1} = '# Phase D3 rank-coordinate diagnostic audit';
    lines{end+1} = '';
    lines{end+1} = sprintf('- CANONICAL_RUN_ID: `%s`', canonicalRunId);
    lines{end+1} = '- Diagnostic coordinate: `x_rank` (per-temperature current-order rank normalized to [0,1]).';
    lines{end+1} = '- Constraints preserved: no backbone change, no decomposition change, no width scaling.';
    lines{end+1} = '';
    lines{end+1} = '## Required flags';
    lines{end+1} = sprintf('- SUPPORT_COLLAPSE_IN_RANK = %s', fSupportCollapseRank);
    lines{end+1} = sprintf('- PHASE_D_RESOLVED_IN_RANK = %s', fPhaseDResolvedRank);
    lines{end+1} = sprintf('- PHI1_CLASSIFICATION_RANK = %s', fPhi1Class);
    lines{end+1} = sprintf('- PHI2_CLASSIFICATION_RANK = %s', fPhi2Class);
    lines{end+1} = sprintf('- KAPPA2_CLASSIFICATION_RANK = %s', fKappa2Class);
    lines{end+1} = sprintf('- READY_FOR_STAGE_E_FROM_RANK = %s', fReadyStageE);
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_mode_relationship_d3_rank:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_mode_relationship_d3_rank_audit.md'), lines, 'run_switching_mode_relationship_d3_rank:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'Phase D3 rank diagnostic completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_mode_relationship_d3_rank_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    statusTbl = table( ...
        ["SUPPORT_COLLAPSE_IN_RANK";"PHASE_D_RESOLVED_IN_RANK";"PHI1_CLASSIFICATION_RANK"; ...
         "PHI2_CLASSIFICATION_RANK";"KAPPA2_CLASSIFICATION_RANK";"READY_FOR_STAGE_E_FROM_RANK"], ...
        ["YES";"NO";"unresolved";"unresolved_partial";"unresolved_partial";"NO"], ...
        repmat(string(ME.message), 6, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_mode_relationship_d3_rank_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_mode_relationship_d3_rank_status.csv'));

    lines = {};
    lines{end+1} = '# Phase D3 rank diagnostic — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_mode_relationship_d3_rank:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_mode_relationship_d3_rank_audit.md'), lines, 'run_switching_mode_relationship_d3_rank:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Phase D3 rank diagnostic failed'}, true);
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
    denom = norm(aa)*norm(bb);
    if denom <= eps, metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; return; end
    metricVal = dot(aa,bb)/denom;
else
    rr = corrcoef(aa,bb);
    if numel(rr) < 4 || ~isfinite(rr(1,2)), metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; return; end
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
if std(xx)<=eps || std(yy)<=eps
    metricVal = NaN; validFlag = "NO"; invalidClass = "INVALID_NUMERIC"; return;
end
rr = corrcoef(xx,yy);
if numel(rr)<4 || ~isfinite(rr(1,2))
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
