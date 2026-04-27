clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_mode_relationship_audit';

% Required flags defaults
fAuditDone = 'NO';
fBackboneUsed = 'ADJUDICATED_CURRENT_PTCDF';
fPhi1Class = 'unresolved';
fPhi2Class = 'unresolved_partial';
fKappa2Class = 'unresolved_partial';
fPhi1Independent = 'PARTIAL';
fPhi2GlobalIndependent = 'PARTIAL';
fPhi2TailLocalized = 'PARTIAL';
fKappa2TracksTail = 'PARTIAL';
fReadyStaticMap = 'NO';
fClaimsAllowed = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_mode_relationship_audit';
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

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Phase D relationship audit initialized'}, false);

    s1Path = fullfile(repoRoot, 'tables', 'switching_backbone_selection_run_status.csv');
    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    phi1Path = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_phi1.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    req = {s1Path, idPath, sLongPath, phi1Path, ampPath};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_mode_relationship_audit:MissingInput', 'Missing required input: %s', req{i});
        end
    end

    % Enforce S1 decision gate
    s1 = readtable(s1Path, 'TextType', 'string');
    idxCurr = find(strcmpi(strtrim(s1.check), 'CURRENT_PTCDF_BACKBONE_SELECTED'), 1);
    idxAllow = find(strcmpi(strtrim(s1.check), 'PHASE_D_ALLOWED_AFTER_SELECTION'), 1);
    if isempty(idxCurr) || isempty(idxAllow)
        error('run_switching_mode_relationship_audit:S1Schema', 'S1 status table missing required checks.');
    end
    if upper(strtrim(s1.result(idxCurr))) ~= "YES" || upper(strtrim(s1.result(idxAllow))) ~= "YES"
        error('run_switching_mode_relationship_audit:S1Gate', 'Phase D blocked by S1 selection gate.');
    end

    % Canonical identity lock read
    idRaw = readcell(idPath, 'Delimiter', ',');
    canonicalRunId = "";
    for r = 2:size(idRaw,1)
        if strcmpi(strtrim(string(idRaw{r,1})), "CANONICAL_RUN_ID")
            canonicalRunId = string(idRaw{r,2});
            break;
        end
    end
    if strlength(strtrim(canonicalRunId)) == 0
        error('run_switching_mode_relationship_audit:Identity', 'CANONICAL_RUN_ID missing in switching_canonical_identity.csv.');
    end

    % Canonical input validation
    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'canonical_phi1')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);
    if ~all(ismember({'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'}, sLong.Properties.VariableNames))
        error('run_switching_mode_relationship_audit:Schema', 'sLong table missing required columns.');
    end
    if ~all(ismember({'T_K','kappa1','kappa2'}, ampTbl.Properties.VariableNames))
        error('run_switching_mode_relationship_audit:Schema', 'amplitude table missing kappa1/kappa2.');
    end

    % Build canonical maps
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
    valid = isfinite(Smap) & isfinite(Bmap) & isfinite(Cmap);
    cdfAxis = mean(Cmap, 1, 'omitnan');
    lowI = cdfAxis >= 0.00 & cdfAxis < 0.20;
    midI = cdfAxis > 0.40 & cdfAxis < 0.60;
    highI = cdfAxis >= 0.80 & cdfAxis <= 1.00;
    tailI = cdfAxis >= 0.80;

    phiVars = string(phi1Tbl.Properties.VariableNames);
    iPhi = find(strcmpi(phiVars, "phi1"), 1);
    phi1 = interp1(double(phi1Tbl.current_mA), double(phi1Tbl{:,iPhi}), allI, 'linear', 'extrap');
    phi1 = phi1(:); phi1(~isfinite(phi1)) = 0;
    if norm(phi1) > 0, phi1 = phi1 / norm(phi1); end

    kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
    kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
    kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');

    % Canonical hierarchical residuals and phi2
    R0 = Smap - Bmap;
    pred1 = Bmap - kappa1(:) * phi1(:)';
    R1 = Smap - pred1;
    R1z = R1; R1z(~isfinite(R1z)) = 0;
    [~,~,V1] = svd(R1z, 'econ');
    if size(V1,2) >= 1
        phi2 = V1(:,1);
    else
        phi2 = zeros(nI,1);
    end
    if norm(phi2) > 0, phi2 = phi2 / norm(phi2); end
    pred2 = pred1 + kappa2(:) * phi2(:)';
    R2 = Smap - pred2;
    R0(~valid) = NaN; R1(~valid) = NaN; R2(~valid) = NaN;

    % Relationship metrics (domain + CDF windows)
    x = cdfAxis(:);
    mAll = isfinite(phi1) & isfinite(phi2);
    mLow = mAll & lowI(:);
    mMid = mAll & midI(:);
    mHigh = mAll & highI(:);
    mTail = mAll & tailI(:);
    cAll = localCos(phi1(mAll), phi2(mAll));
    cLow = localCos(phi1(mLow), phi2(mLow));
    cMid = localCos(phi1(mMid), phi2(mMid));
    cHigh = localCos(phi1(mHigh), phi2(mHigh));
    cTail = localCos(phi1(mTail), phi2(mTail));
    rAll = localCorr(phi1(mAll), phi2(mAll));
    rLow = localCorr(phi1(mLow), phi2(mLow));
    rMid = localCorr(phi1(mMid), phi2(mMid));
    rHigh = localCorr(phi1(mHigh), phi2(mHigh));
    rTail = localCorr(phi1(mTail), phi2(mTail));
    relMetrics = table( ...
        ["full_domain";"low_cdf";"mid_cdf";"high_cdf";"tail_only"], ...
        [cAll;cLow;cMid;cHigh;cTail], [rAll;rLow;rMid;rHigh;rTail], ...
        'VariableNames', {'domain','phi1_phi2_cosine','phi1_phi2_correlation'});
    switchingWriteTableBothPaths(relMetrics, repoRoot, runTables, 'switching_mode_relationship_metrics.csv');

    % Deformation basis tests for Phi2 ~ basis(Phi1)
    x0 = x - 0.5;
    d1 = gradient(phi1, max(median(diff(x),'omitnan'), eps));
    d2 = gradient(d1, max(median(diff(x),'omitnan'), eps));
    Bdef = [phi1, d1, d2, x0.*phi1, x0.*d1];
    fitAll = localFit(phi2, Bdef, true(size(phi2)));
    fitTail = localFit(phi2, Bdef, tailI(:));
    defNames = ["phi1";"dphi1_dx";"d2phi1_dx2";"u_phi1";"u_dphi1_dx"];
    defTbl = table( ...
        repmat(["full_domain";"tail_domain"], numel(defNames), 1), ...
        [repmat(defNames,1,1); repmat(defNames,1,1)], ...
        [fitAll.beta(:); fitTail.beta(:)], ...
        'VariableNames', {'fit_domain','basis_term','coefficient'});
    fitSummary = table( ...
        ["full_domain";"tail_domain"], ...
        [fitAll.r2; fitTail.r2], [fitAll.rmse; fitTail.rmse], ...
        'VariableNames', {'fit_domain','r2','rmse'});
    defOut = [defTbl; table(["full_domain";"tail_domain"], ["__fit_r2__";"__fit_r2__"], [fitAll.r2; fitTail.r2], 'VariableNames', {'fit_domain','basis_term','coefficient'}); ...
              table(["full_domain";"tail_domain"], ["__fit_rmse__";"__fit_rmse__"], [fitAll.rmse; fitTail.rmse], 'VariableNames', {'fit_domain','basis_term','coefficient'})];
    switchingWriteTableBothPaths(defOut, repoRoot, runTables, 'switching_mode_relationship_deformation_fit.csv');

    % Backbone coupling + tail burden tracking
    tailBurden = mean(R0(:,tailI).^2, 2, 'omitnan') ./ max(mean(R0(:,midI).^2, 2, 'omitnan'), eps);
    highBurden = mean(R0(:,highI).^2, 2, 'omitnan');
    globalBurden = mean(R0.^2, 2, 'omitnan');
    ptSpread = std(Bmap, 0, 2, 'omitnan');
    ptMean = mean(Bmap, 2, 'omitnan');
    cK1Tail = localCorr(kappa1(:), tailBurden(:));
    cK2Tail = localCorr(kappa2(:), tailBurden(:));
    cK1High = localCorr(kappa1(:), highBurden(:));
    cK2High = localCorr(kappa2(:), highBurden(:));
    cK1Global = localCorr(kappa1(:), globalBurden(:));
    cK2Global = localCorr(kappa2(:), globalBurden(:));
    cK2PtSpread = localCorr(kappa2(:), ptSpread(:));
    cK2PtMean = localCorr(kappa2(:), ptMean(:));
    couplingTbl = table( ...
        ["kappa1_vs_tail_burden";"kappa2_vs_tail_burden";"kappa1_vs_high_burden";"kappa2_vs_high_burden"; ...
         "kappa1_vs_global_burden";"kappa2_vs_global_burden";"kappa2_vs_backbone_spread";"kappa2_vs_backbone_mean"], ...
        [cK1Tail;cK2Tail;cK1High;cK2High;cK1Global;cK2Global;cK2PtSpread;cK2PtMean], ...
        'VariableNames', {'relationship','pearson_correlation'});
    switchingWriteTableBothPaths(couplingTbl, repoRoot, runTables, 'switching_mode_relationship_backbone_coupling.csv');

    tailTbl = table( ...
        allT(:), kappa1(:), kappa2(:), tailBurden(:), highBurden(:), globalBurden(:), ...
        mean(abs(R1(:,tailI)),2,'omitnan'), mean(abs(R2(:,tailI)),2,'omitnan'), ...
        'VariableNames', {'T_K','kappa1','kappa2','tail_burden_ratio','high_tail_energy','global_residual_energy','tail_abs_R1','tail_abs_R2'});
    switchingWriteTableBothPaths(tailTbl, repoRoot, runTables, 'switching_mode_relationship_tail_burden.csv');

    % Phi2 locality/globality and hierarchy indicators
    phi2TailFrac = sum(phi2(tailI(:)).^2) / max(sum(phi2.^2), eps);
    phi2MidFrac = sum(phi2(midI(:)).^2) / max(sum(phi2.^2), eps);
    phi2LowFrac = sum(phi2(lowI(:)).^2) / max(sum(phi2.^2), eps);
    phi2OutsideTailFrac = 1 - phi2TailFrac;
    cK1K2 = localCorr(kappa1(:), kappa2(:));
    g2Global = mean((mean(R1.^2,2,'omitnan') - mean(R2.^2,2,'omitnan')) ./ max(mean(R1.^2,2,'omitnan'), eps), 'omitnan');
    g2Tail = mean((mean(R1(:,tailI).^2,2,'omitnan') - mean(R2(:,tailI).^2,2,'omitnan')) ./ max(mean(R1(:,tailI).^2,2,'omitnan'), eps), 'omitnan');

    % Classification logic (explicit robust vs partial)
    if abs(cAll) < 0.35 && abs(cLow) < 0.45 && abs(cMid) < 0.45
        fPhi1Independent = 'YES';
    elseif abs(cAll) < 0.55
        fPhi1Independent = 'PARTIAL';
    else
        fPhi1Independent = 'NO';
    end

    if phi2TailFrac >= 0.65 && abs(cK2Tail) >= 0.70
        fPhi2TailLocalized = 'YES';
    elseif phi2TailFrac >= 0.50 && abs(cK2Tail) >= 0.50
        fPhi2TailLocalized = 'PARTIAL';
    else
        fPhi2TailLocalized = 'NO';
    end

    if phi2OutsideTailFrac >= 0.45 && abs(cK2Global) >= 0.45 && abs(cTail) < 0.60
        fPhi2GlobalIndependent = 'YES';
    elseif phi2OutsideTailFrac >= 0.30
        fPhi2GlobalIndependent = 'PARTIAL';
    else
        fPhi2GlobalIndependent = 'NO';
    end

    if abs(cK2Tail) >= 0.70 && abs(cK2Tail) > abs(cK2Global) + 0.15
        fKappa2TracksTail = 'YES';
    elseif abs(cK2Tail) >= 0.50
        fKappa2TracksTail = 'PARTIAL';
    else
        fKappa2TracksTail = 'NO';
    end

    if strcmp(fPhi1Independent,'YES') && abs(cK1Tail) < 0.50
        fPhi1Class = 'robust_residual_redistribution';
    elseif abs(cK1Tail) >= 0.65
        fPhi1Class = 'backbone_error';
    else
        fPhi1Class = 'unresolved';
    end

    if strcmp(fPhi2TailLocalized,'YES') && strcmp(fKappa2TracksTail,'YES')
        if fitTail.r2 >= 0.75
            fPhi2Class = 'phi1_deformation';
            fKappa2Class = 'deformation_amplitude';
        else
            fPhi2Class = 'high_cdf_tail_correction';
            fKappa2Class = 'tail_burden_tracker';
        end
    elseif strcmp(fPhi2GlobalIndependent,'YES') && fitAll.r2 < 0.50
        fPhi2Class = 'independent_global_mode';
        fKappa2Class = 'independent_coordinate';
    elseif strcmp(fPhi2TailLocalized,'PARTIAL')
        fPhi2Class = 'backbone_tail_residual';
        fKappa2Class = 'tail_burden_tracker';
    else
        fPhi2Class = 'unresolved_partial';
        fKappa2Class = 'unresolved_partial';
    end

    % conservative readiness: keep provisional mapping blocked if Phi2 partial
    if strcmp(fPhi1Class,'robust_residual_redistribution') && strcmp(fPhi2Class,'independent_global_mode')
        fReadyStaticMap = 'PARTIAL';
    else
        fReadyStaticMap = 'NO';
    end

    classTbl = table( ...
        ["Phi1_relationship_class";"Phi2_relationship_class";"kappa2_class"; ...
         "phi1_backbone_independent";"phi2_global_independent";"phi2_tail_localized"; ...
         "kappa2_tracks_tail_burden";"mode_hierarchy_note"], ...
        [string(fPhi1Class);string(fPhi2Class);string(fKappa2Class); ...
         string(fPhi1Independent);string(fPhi2GlobalIndependent);string(fPhi2TailLocalized); ...
         string(fKappa2TracksTail); ...
         "Phi1 robust; Phi2 treated as partial/tail-sensitive unless strong global evidence."], ...
        'VariableNames', {'classification_item','value'});
    switchingWriteTableBothPaths(classTbl, repoRoot, runTables, 'switching_mode_relationship_classification.csv');

    statusTbl = table( ...
        ["MODE_RELATIONSHIP_AUDIT_COMPLETED";"BACKBONE_USED";"PHI1_CLASSIFICATION";"PHI2_CLASSIFICATION"; ...
         "KAPPA2_CLASSIFICATION";"PHI1_BACKBONE_INDEPENDENT";"PHI2_GLOBAL_INDEPENDENT";"PHI2_TAIL_LOCALIZED"; ...
         "KAPPA2_TRACKS_TAIL_BURDEN";"READY_FOR_OFFICIAL_STATIC_OBSERVABLE_MAPPING";"CLAIMS_UPDATE_ALLOWED"], ...
        [string('YES');string(fBackboneUsed);string(fPhi1Class);string(fPhi2Class); ...
         string(fKappa2Class);string(fPhi1Independent);string(fPhi2GlobalIndependent);string(fPhi2TailLocalized); ...
         string(fKappa2TracksTail);string(fReadyStaticMap);string(fClaimsAllowed)], ...
        ["Phase D relationship audit completed under adjudicated current PT/CDF."; ...
         sprintf("CANONICAL_RUN_ID=%s", canonicalRunId); ...
         sprintf("Phi1 class based on independence and coupling: cos_all=%.4f, corr(k1,tail)=%.4f", cAll, cK1Tail); ...
         sprintf("Phi2 class from tail localization/global tests + deformation fit (R2 tail=%.4f, full=%.4f)", fitTail.r2, fitAll.r2); ...
         sprintf("kappa2 class from tail/global burden coupling (tail=%.4f, global=%.4f)", cK2Tail, cK2Global); ...
         sprintf("Phi1 backbone independence from full/low/mid cosines: %.4f/%.4f/%.4f", cAll, cLow, cMid); ...
         sprintf("Phi2 global independence from outside-tail frac=%.4f and coupling tests", phi2OutsideTailFrac); ...
         sprintf("Phi2 tail localization from tail energy frac=%.4f", phi2TailFrac); ...
         sprintf("kappa2-tail tracking correlation=%.4f", cK2Tail); ...
         "Blocked unless Phi2 matures beyond partial/tail-sensitive behavior."; ...
         "Claims/context/snapshot/query updates remain forbidden."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_mode_relationship_status.csv');

    % Recommended figures
    fig = figure('Visible','off','Color','w','Position',[70 70 1600 900]);
    tl = tiledlayout(2,2,'Parent',fig,'TileSpacing','compact','Padding','compact');
    nexttile(tl);
    plot(x, phi1, '-', 'LineWidth', 1.5); hold on; plot(x, phi2, '-', 'LineWidth', 1.5); hold off;
    title('Phi1 / Phi2 in CDF_{pt} space'); xlabel('CDF_{pt}'); ylabel('mode amplitude'); legend({'Phi1','Phi2'},'Location','best'); grid on;
    nexttile(tl);
    bar(categorical(["full","tail"]), [fitAll.r2, fitTail.r2]); title('Deformation fit quality'); ylabel('R^2'); grid on;
    nexttile(tl);
    scatter(tailBurden, kappa2, 45, allT, 'filled'); colorbar; title('kappa2 vs tail burden'); xlabel('tail burden ratio'); ylabel('kappa2'); grid on;
    nexttile(tl);
    bar(categorical(["low","mid","high-tail"]), [phi2LowFrac, phi2MidFrac, phi2TailFrac]); title('Phi2 CDF-window energy'); ylabel('energy fraction'); grid on;
    sgtitle(tl, 'Phase D mode relationship diagnostics (NON_CANONICAL_DIAGNOSTIC)', 'Interpreter', 'none');
    savefig(fig, fullfile(runFigures, [baseName '.fig']));
    exportgraphics(fig, fullfile(runFigures, [baseName '.png']), 'Resolution', 300);
    close(fig);

    lines = {};
    lines{end+1} = '# Phase D: Switching mode relationship audit under adjudicated PT/CDF backbone';
    lines{end+1} = '';
    lines{end+1} = '## Scope guards';
    lines{end+1} = sprintf('- Canonical lock: `CANONICAL_RUN_ID=%s`', canonicalRunId);
    lines{end+1} = '- Backbone used: adjudicated current PT/CDF only.';
    lines{end+1} = '- No producer edits, no identity changes, no backbone replacement.';
    lines{end+1} = '- No claims/context/snapshot/query updates.';
    lines{end+1} = '';
    lines{end+1} = '## Core relationship findings';
    lines{end+1} = sprintf('- Phi1-Phi2 cosine (full/low/mid/high/tail): %.4f / %.4f / %.4f / %.4f / %.4f', cAll, cLow, cMid, cHigh, cTail);
    lines{end+1} = sprintf('- Deformation fit R2 (full vs tail): %.4f vs %.4f', fitAll.r2, fitTail.r2);
    lines{end+1} = sprintf('- Corr(kappa2, tail burden)=%.4f; Corr(kappa2, global burden)=%.4f', cK2Tail, cK2Global);
    lines{end+1} = sprintf('- Phi2 tail fraction=%.4f, outside-tail fraction=%.4f', phi2TailFrac, phi2OutsideTailFrac);
    lines{end+1} = '';
    lines{end+1} = '## Final classification';
    lines{end+1} = sprintf('- PHI1_CLASSIFICATION = %s', fPhi1Class);
    lines{end+1} = sprintf('- PHI2_CLASSIFICATION = %s', fPhi2Class);
    lines{end+1} = sprintf('- KAPPA2_CLASSIFICATION = %s', fKappa2Class);
    lines{end+1} = '';
    lines{end+1} = '## Required flags';
    lines{end+1} = '- MODE_RELATIONSHIP_AUDIT_COMPLETED = YES';
    lines{end+1} = sprintf('- BACKBONE_USED = %s', fBackboneUsed);
    lines{end+1} = sprintf('- PHI1_CLASSIFICATION = %s', fPhi1Class);
    lines{end+1} = sprintf('- PHI2_CLASSIFICATION = %s', fPhi2Class);
    lines{end+1} = sprintf('- KAPPA2_CLASSIFICATION = %s', fKappa2Class);
    lines{end+1} = sprintf('- PHI1_BACKBONE_INDEPENDENT = %s', fPhi1Independent);
    lines{end+1} = sprintf('- PHI2_GLOBAL_INDEPENDENT = %s', fPhi2GlobalIndependent);
    lines{end+1} = sprintf('- PHI2_TAIL_LOCALIZED = %s', fPhi2TailLocalized);
    lines{end+1} = sprintf('- KAPPA2_TRACKS_TAIL_BURDEN = %s', fKappa2TracksTail);
    lines{end+1} = sprintf('- READY_FOR_OFFICIAL_STATIC_OBSERVABLE_MAPPING = %s', fReadyStaticMap);
    lines{end+1} = '- CLAIMS_UPDATE_ALLOWED = NO';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_mode_relationship_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_mode_relationship_audit.md'), lines, 'run_switching_mode_relationship_audit:WriteFail');

    fAuditDone = 'YES'; %#ok<NASGU>
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'Phase D relationship audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_mode_relationship_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    statusTbl = table( ...
        ["MODE_RELATIONSHIP_AUDIT_COMPLETED";"BACKBONE_USED";"PHI1_CLASSIFICATION";"PHI2_CLASSIFICATION"; ...
         "KAPPA2_CLASSIFICATION";"PHI1_BACKBONE_INDEPENDENT";"PHI2_GLOBAL_INDEPENDENT";"PHI2_TAIL_LOCALIZED"; ...
         "KAPPA2_TRACKS_TAIL_BURDEN";"READY_FOR_OFFICIAL_STATIC_OBSERVABLE_MAPPING";"CLAIMS_UPDATE_ALLOWED"], ...
        ["NO";"ADJUDICATED_CURRENT_PTCDF";"unresolved";"unresolved_partial";"unresolved_partial"; ...
         "PARTIAL";"PARTIAL";"PARTIAL";"PARTIAL";"NO";"NO"], ...
        repmat(string(ME.message), 11, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_mode_relationship_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_mode_relationship_status.csv'));

    lines = {};
    lines{end+1} = '# Phase D mode relationship audit — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_mode_relationship_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_mode_relationship_audit.md'), lines, 'run_switching_mode_relationship_audit:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Phase D relationship audit failed'}, true);
    rethrow(ME);
end

function c = localCorr(a,b)
a = a(:); b = b(:);
m = isfinite(a) & isfinite(b);
if sum(m) < 3
    c = NaN; return;
end
r = corrcoef(a(m), b(m));
if numel(r) < 4, c = NaN; else, c = r(1,2); end
end

function c = localCos(a,b)
a = a(:); b = b(:);
m = isfinite(a) & isfinite(b);
if sum(m) < 2
    c = NaN; return;
end
aa = a(m); bb = b(m);
c = dot(aa,bb) / max(norm(aa)*norm(bb), eps);
end

function out = localFit(y, X, mask)
y = y(:);
if nargin < 3, mask = true(size(y)); end
mask = mask(:) & isfinite(y);
XX = X(mask,:); yy = y(mask);
mm = all(isfinite(XX),2) & isfinite(yy);
XX = XX(mm,:); yy = yy(mm);
if size(XX,1) < size(XX,2)
    out.beta = zeros(size(X,2),1); out.r2 = NaN; out.rmse = NaN; return;
end
beta = XX \ yy;
yhat = XX * beta;
sse = sum((yy - yhat).^2);
sst = sum((yy - mean(yy)).^2);
out.beta = beta;
out.r2 = 1 - sse / max(sst, eps);
out.rmse = sqrt(mean((yy-yhat).^2));
end
