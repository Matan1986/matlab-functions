clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_backbone_validity_audit';

flagBackboneValid = 'NO';
flagCdfMonotonic = 'NO';
flagPtPdfValid = 'NO';
flagFormulaConsistent = 'NO';
flagTailFailure = 'NO';
flagHighTFailure = 'NO';
flagTransitionKink = 'NO';
flagK2TailRelated = 'PARTIAL';
flagReadyPhaseC = 'NO';

gateRows = struct('table_name', string.empty(0,1), 'table_path', string.empty(0,1), ...
    'validation_status', string.empty(0,1), 'failure_code', string.empty(0,1), ...
    'failure_message', string.empty(0,1), 'metadata_path', string.empty(0,1));

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_backbone_validity';
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

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0, fprintf(fidTop, 'SCRIPT_ENTERED\n'); fclose(fidTop); end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    % Phase-A canonical truth artifacts
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    gatePath = fullfile(repoRoot, 'tables', 'switching_canonical_input_gate_status.csv');
    hierErrPath = fullfile(repoRoot, 'tables', 'switching_canonical_collapse_hierarchy_error_vs_T.csv');
    hierStatusPath = fullfile(repoRoot, 'tables', 'switching_canonical_collapse_hierarchy_status.csv');

    reqPaths = {sLongPath, ampPath, gatePath, hierErrPath, hierStatusPath};
    reqNames = {'switching_canonical_S_long.csv', 'switching_mode_amplitudes_vs_T.csv', ...
        'switching_canonical_input_gate_status.csv', 'switching_canonical_collapse_hierarchy_error_vs_T.csv', ...
        'switching_canonical_collapse_hierarchy_status.csv'};
    for i = 1:numel(reqPaths)
        if strlength(string(reqPaths{i})) == 0 || exist(reqPaths{i}, 'file') ~= 2
            error('run_switching_backbone_validity_audit:MissingInput', ...
                'Missing Phase-A canonical artifact: %s (%s)', reqNames{i}, reqPaths{i});
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
        validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));
        gateRows = switchingAddInputGateRow(gateRows, 'switching_mode_amplitudes_vs_T.csv', ampPath, 'PASS', '', '', [ampPath '.meta.json']);
    catch MEv
        gateRows = switchingAddInputGateRow(gateRows, 'switching_mode_amplitudes_vs_T.csv', ampPath, 'FAIL', char(string(MEv.identifier)), char(string(MEv.message)), [ampPath '.meta.json']);
        rethrow(MEv);
    end

    sLong = readtable(sLongPath);
    ampTbl = readtable(ampPath);
    gateTbl = readtable(gatePath);
    hierErrTbl = readtable(hierErrPath);
    hierStatusTbl = readtable(hierStatusPath);

    reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt','PT_pdf'};
    for i = 1:numel(reqS)
        if ~ismember(reqS{i}, sLong.Properties.VariableNames)
            error('run_switching_backbone_validity_audit:BadSLongSchema', ...
                'switching_canonical_S_long.csv missing required column: %s', reqS{i});
        end
    end
    reqA = {'T_K','kappa2'};
    for i = 1:numel(reqA)
        if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
            error('run_switching_backbone_validity_audit:BadAmpSchema', ...
                'switching_mode_amplitudes_vs_T.csv missing required column: %s', reqA{i});
        end
    end

    % Confirm gate PASS and width-scaling NO in hierarchy
    gatePass = all(strcmpi(string(gateRows.validation_status), 'PASS'));
    hierWidthNo = true;
    if ismember('used_width_scaling', hierStatusTbl.Properties.VariableNames)
        hierWidthNo = all(strcmpi(string(hierStatusTbl.used_width_scaling), 'NO'));
    end

    % Aggregate to canonical (T, I) map
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
                idx = find(m,1);
                Smap(it,ii) = double(TIg.mean_S(idx));
                Bmap(it,ii) = double(TIg.mean_B(idx));
                Cmap(it,ii) = double(TIg.mean_C(idx));
                Pmap(it,ii) = double(TIg.mean_P(idx));
            end
        end
    end

    % 1) CDF monotonic diagnostics by T
    cdfFiniteFrac = NaN(nT,1);
    cdfMin = NaN(nT,1);
    cdfMax = NaN(nT,1);
    cdfMonotonicViolations = NaN(nT,1);
    cdfMonotonicFlag = strings(nT,1);
    for it = 1:nT
        c = Cmap(it,:);
        m = isfinite(c);
        cdfFiniteFrac(it) = mean(m);
        if any(m)
            cs = c(m);
            cdfMin(it) = min(cs);
            cdfMax(it) = max(cs);
            dc = diff(cs);
            cdfMonotonicViolations(it) = sum(dc < -1e-6);
            if cdfMonotonicViolations(it) == 0
                cdfMonotonicFlag(it) = "YES";
            elseif cdfMonotonicViolations(it) <= 1
                cdfMonotonicFlag(it) = "PARTIAL";
            else
                cdfMonotonicFlag(it) = "NO";
            end
        else
            cdfMonotonicViolations(it) = NaN;
            cdfMonotonicFlag(it) = "NO";
        end
    end
    cdfTbl = table(allT(:), cdfFiniteFrac, cdfMin, cdfMax, cdfMonotonicViolations, cdfMonotonicFlag, ...
        'VariableNames', {'T_K','cdf_finite_fraction','cdf_min','cdf_max','cdf_monotonic_violations','cdf_monotonic_flag'});
    switchingWriteTableBothPaths(cdfTbl, repoRoot, runTables, 'switching_backbone_validity_cdf_diagnostics.csv');

    % 2) PT_pdf validity by T
    pFiniteFrac = NaN(nT,1);
    pNegativeFrac = NaN(nT,1);
    pIntegral = NaN(nT,1);
    pTailMassLow = NaN(nT,1);
    pTailMassHigh = NaN(nT,1);
    Irow = allI(:)';
    for it = 1:nT
        p = Pmap(it,:);
        c = Cmap(it,:);
        m = isfinite(p) & isfinite(c) & isfinite(Irow);
        pFiniteFrac(it) = mean(isfinite(p));
        if any(m)
            ps = p(m);
            cs = c(m);
            is = Irow(m);
            pNegativeFrac(it) = mean(ps < -1e-9);
            if numel(ps) >= 2
                pIntegral(it) = trapz(is, ps);
            end
            low = cs <= 0.2;
            high = cs >= 0.8;
            if sum(low) >= 2, pTailMassLow(it) = trapz(is(low), ps(low)); end
            if sum(high) >= 2, pTailMassHigh(it) = trapz(is(high), ps(high)); end
        end
    end
    pTbl = table(allT(:), pFiniteFrac, pNegativeFrac, pIntegral, pTailMassLow, pTailMassHigh, ...
        'VariableNames', {'T_K','ptpdf_finite_fraction','ptpdf_negative_fraction','ptpdf_integral','ptpdf_tail_mass_low','ptpdf_tail_mass_high'});
    switchingWriteTableBothPaths(pTbl, repoRoot, runTables, 'switching_backbone_validity_ptpdf_diagnostics.csv');

    % 3,4,5,6) Backbone consistency + residual localization
    res = Smap - Bmap;
    resEnergyTotal = NaN(nT,1);
    resEnergyLow = NaN(nT,1);
    resEnergyMid = NaN(nT,1);
    resEnergyHigh = NaN(nT,1);
    highTailWeight = NaN(nT,1);
    formulaRmse = NaN(nT,1);
    formulaRelRmse = NaN(nT,1);
    for it = 1:nT
        s = Smap(it,:);
        b = Bmap(it,:);
        c = Cmap(it,:);
        r = res(it,:);
        m = isfinite(s) & isfinite(b) & isfinite(c);
        if ~any(m)
            continue;
        end
        ss = s(m); bb = b(m); cc = c(m); rr = r(m);
        low = cc <= 0.2;
        mid = cc > 0.4 & cc < 0.6;
        high = cc >= 0.8;

        resEnergyTotal(it) = mean(rr.^2, 'omitnan');
        if any(low), resEnergyLow(it) = mean((rr(low)).^2, 'omitnan'); end
        if any(mid), resEnergyMid(it) = mean((rr(mid)).^2, 'omitnan'); end
        if any(high), resEnergyHigh(it) = mean((rr(high)).^2, 'omitnan'); end
        if any(high), highTailWeight(it) = mean(ss(high), 'omitnan'); end

        % Candidate consistency check against S_peak * CDF_pt
        Speak = max(ss, [], 'omitnan');
        bEst = Speak .* cc;
        d = bb - bEst;
        formulaRmse(it) = sqrt(mean(d.^2, 'omitnan'));
        denom = max(abs(bb), [], 'omitnan');
        if isfinite(denom) && denom > 0
            formulaRelRmse(it) = formulaRmse(it) / denom;
        end
    end
    locTbl = table(allT(:), resEnergyTotal, resEnergyLow, resEnergyMid, resEnergyHigh, highTailWeight, formulaRmse, formulaRelRmse, ...
        'VariableNames', {'T_K','residual_energy_total','residual_energy_low_cdf','residual_energy_mid_cdf','residual_energy_high_cdf','high_cdf_tail_weight','backbone_formula_rmse','backbone_formula_rel_rmse'});
    switchingWriteTableBothPaths(locTbl, repoRoot, runTables, 'switching_backbone_validity_residual_localization.csv');

    % 7) Temperature audit (high-T and 22-24 K)
    highMask = allT >= 28;
    transMask = allT >= 22 & allT <= 24;
    neighMask = allT >= 20 & allT <= 26 & ~transMask;
    restMask = ~highMask;

    highVsRestRatio = mean(resEnergyTotal(highMask), 'omitnan') / max(mean(resEnergyTotal(restMask), 'omitnan'), eps);
    transVsNeighRatio = mean(resEnergyTotal(transMask), 'omitnan') / max(mean(resEnergyTotal(neighMask), 'omitnan'), eps);
    highTailVsMid = mean(resEnergyHigh(highMask), 'omitnan') / max(mean(resEnergyMid(highMask), 'omitnan'), eps);

    tempAuditTbl = table( ...
        string({'highT_vs_rest_residual_energy_ratio'; 'transition22_24_vs_neighbors_ratio'; 'highT_highCDF_vs_midCDF_ratio'}), ...
        [highVsRestRatio; transVsNeighRatio; highTailVsMid], ...
        string({strjoin(string(allT(highMask)), ','); strjoin(string(allT(transMask)), ','); strjoin(string(allT(highMask)), ',')}), ...
        'VariableNames', {'metric','value','bins_included'});
    switchingWriteTableBothPaths(tempAuditTbl, repoRoot, runTables, 'switching_backbone_validity_temperature_audit.csv');

    % Lead audit: high_CDF_tail_weight ↔ kappa2 likely backbone or failure artifact?
    k2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
    mLead = isfinite(k2) & isfinite(highTailWeight);
    rhoTailK2 = NaN;
    if sum(mLead) >= 3
        rhoTailK2 = corr(highTailWeight(mLead), k2(mLead), 'type', 'Spearman', 'rows', 'complete');
    end
    mFail = isfinite(k2) & isfinite(resEnergyHigh);
    rhoFailK2 = NaN;
    if sum(mFail) >= 3
        rhoFailK2 = corr(resEnergyHigh(mFail), k2(mFail), 'type', 'Spearman', 'rows', 'complete');
    end

    % Flag decisions
    cdfGoodFrac = mean(cdfMonotonicViolations == 0 & cdfMin >= -0.05 & cdfMax <= 1.05, 'omitnan');
    if cdfGoodFrac >= 0.95
        flagCdfMonotonic = 'YES';
    elseif cdfGoodFrac >= 0.75
        flagCdfMonotonic = 'PARTIAL';
    else
        flagCdfMonotonic = 'NO';
    end

    pFiniteGood = mean(pFiniteFrac >= 0.95, 'omitnan');
    pNegGood = mean(pNegativeFrac <= 0.05, 'omitnan');
    pIntErr = median(abs(pIntegral - 1), 'omitnan');
    if pFiniteGood >= 0.9 && pNegGood >= 0.9 && isfinite(pIntErr) && pIntErr <= 0.25
        flagPtPdfValid = 'YES';
    elseif pFiniteGood >= 0.7 && pNegGood >= 0.7
        flagPtPdfValid = 'PARTIAL';
    else
        flagPtPdfValid = 'NO';
    end

    relErrMed = median(formulaRelRmse, 'omitnan');
    if isfinite(relErrMed) && relErrMed <= 0.10
        flagFormulaConsistent = 'YES';
    elseif isfinite(relErrMed) && relErrMed <= 0.25
        flagFormulaConsistent = 'PARTIAL';
    else
        flagFormulaConsistent = 'NO';
    end

    if isfinite(highTailVsMid) && highTailVsMid > 1.3
        flagTailFailure = 'YES';
    elseif isfinite(highTailVsMid) && highTailVsMid > 1.1
        flagTailFailure = 'PARTIAL';
    else
        flagTailFailure = 'NO';
    end

    if isfinite(highVsRestRatio) && highVsRestRatio > 1.3
        flagHighTFailure = 'YES';
    elseif isfinite(highVsRestRatio) && highVsRestRatio > 1.1
        flagHighTFailure = 'PARTIAL';
    else
        flagHighTFailure = 'NO';
    end

    if isfinite(transVsNeighRatio) && transVsNeighRatio > 1.25
        flagTransitionKink = 'YES';
    elseif isfinite(transVsNeighRatio) && transVsNeighRatio > 1.05
        flagTransitionKink = 'PARTIAL';
    else
        flagTransitionKink = 'NO';
    end

    if isfinite(rhoTailK2) && isfinite(rhoFailK2)
        if abs(rhoTailK2) >= 0.45 && abs(rhoFailK2) < 0.30
            flagK2TailRelated = 'YES';
        elseif abs(rhoFailK2) >= 0.45 && abs(rhoFailK2) >= abs(rhoTailK2)
            flagK2TailRelated = 'NO';
        else
            flagK2TailRelated = 'PARTIAL';
        end
    else
        flagK2TailRelated = 'PARTIAL';
    end

    % Overall backbone validity for downstream residual analysis
    nYesCore = sum(strcmp({flagCdfMonotonic, flagPtPdfValid, flagFormulaConsistent}, 'YES'));
    nNoCore = sum(strcmp({flagCdfMonotonic, flagPtPdfValid, flagFormulaConsistent}, 'NO'));
    if nNoCore >= 2
        flagBackboneValid = 'NO';
    elseif nYesCore == 3 && ~strcmp(flagTailFailure, 'YES')
        flagBackboneValid = 'YES';
    else
        flagBackboneValid = 'PARTIAL';
    end

    if strcmp(flagBackboneValid, 'YES') || strcmp(flagBackboneValid, 'PARTIAL')
        flagReadyPhaseC = 'YES';
    else
        flagReadyPhaseC = 'NO';
    end

    % Recommended run-scoped figures
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1450, 820]);
    tl = tiledlayout(2, 2, 'Parent', fig, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile(tl);
    plot(allT, cdfMonotonicViolations, '-o', 'LineWidth', 1.5); hold on;
    yyaxis right;
    plot(allT, cdfMin, '--', 'LineWidth', 1.2);
    plot(allT, cdfMax, '--', 'LineWidth', 1.2);
    hold off;
    title('CDF_{pt} monotonicity/range by T');
    xlabel('T_K'); ylabel('Violations / Range');
    legend({'violations','cdf min','cdf max'}, 'Location', 'best');
    grid on;

    nexttile(tl);
    plot(allT, pIntegral, '-o', 'LineWidth', 1.5); hold on;
    plot(allT, pNegativeFrac, '-s', 'LineWidth', 1.3);
    plot(allT, pFiniteFrac, '-d', 'LineWidth', 1.3);
    hold off;
    title('PT_{pdf} diagnostics by T');
    xlabel('T_K'); ylabel('Value');
    legend({'integral','negative frac','finite frac'}, 'Location', 'best');
    grid on;

    nexttile(tl);
    plot(allT, resEnergyTotal, '-o', 'LineWidth', 1.6); hold on;
    xline(22,'--'); xline(24,'--'); xline(28,'--');
    hold off;
    title('Residual energy vs T');
    xlabel('T_K'); ylabel('mean((S-S_{pt})^2)');
    grid on;

    nexttile(tl);
    bar(allT, [resEnergyLow, resEnergyMid, resEnergyHigh], 'stacked');
    title('Residual energy by CDF window');
    xlabel('T_K'); ylabel('Window energy');
    legend({'low CDF','mid CDF','high CDF'}, 'Location', 'best');
    grid on;

    sgtitle(tl, 'Canonical backbone validity audit (Phase B)', 'Interpreter', 'none');
    figPath = fullfile(runFigures, [baseName '.fig']);
    pngPath = fullfile(runFigures, [baseName '.png']);
    savefig(fig, figPath);
    exportgraphics(fig, pngPath, 'Resolution', 300);
    close(fig);

    statusTbl = table( ...
        {'BACKBONE_VALID_FOR_RESIDUAL_ANALYSIS'; 'CDF_PT_MONOTONIC'; 'PT_PDF_VALID'; ...
         'BACKBONE_FORMULA_CONSISTENT'; 'BACKBONE_FAILURE_LOCALIZED_IN_HIGH_CDF_TAIL'; ...
         'HIGH_T_BACKBONE_FAILURE'; 'TRANSITION_22_24_BACKBONE_KINK'; ...
         'KAPPA2_HIGH_CDF_TAIL_LEAD_BACKBONE_RELATED'; 'READY_FOR_PHASE_C_MODE_ADMISSIBILITY'}, ...
        {flagBackboneValid; flagCdfMonotonic; flagPtPdfValid; ...
         flagFormulaConsistent; flagTailFailure; flagHighTFailure; ...
         flagTransitionKink; flagK2TailRelated; flagReadyPhaseC}, ...
        {sprintf('Core flags: CDF=%s PTpdf=%s formula=%s', flagCdfMonotonic, flagPtPdfValid, flagFormulaConsistent); ...
         sprintf('cdf_good_fraction=%.6g', cdfGoodFrac); ...
         sprintf('ptpdf finite-good=%.6g neg-good=%.6g median |int-1|=%.6g', pFiniteGood, pNegGood, pIntErr); ...
         sprintf('median relative formula RMSE=%.6g (S_model_pt vs S_peak*CDF_pt proxy)', relErrMed); ...
         sprintf('highCDF/midCDF residual energy ratio=%.6g', highTailVsMid); ...
         sprintf('highT/rest residual energy ratio=%.6g', highVsRestRatio); ...
         sprintf('transition22_24/neighbors residual energy ratio=%.6g', transVsNeighRatio); ...
         sprintf('spearman(kappa2,high_tail_weight)=%.6g; spearman(kappa2,high_tail_residual_energy)=%.6g', rhoTailK2, rhoFailK2); ...
         sprintf('Phase C restrictions required when backbone validity is PARTIAL. Figure: %s', figPath)}, ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_backbone_validity_status.csv');
    switchingWriteTableBothPaths(switchingInputGateRowsToTable(gateRows), repoRoot, runTables, 'switching_backbone_validity_input_gate_status.csv');

    lines = {};
    lines{end+1} = '# Canonical Switching backbone validity audit (Phase B)';
    lines{end+1} = '';
    lines{end+1} = '## Scope';
    lines{end+1} = '- Switching only; no producer edits; no reconstruction/mode-definition changes.';
    lines{end+1} = '- Canonical truth/diagnostic artifacts only (Phase-A allow-list).';
    lines{end+1} = '- No width scaling, no alignment coordinates, no legacy truth promotion.';
    lines{end+1} = '- No claims/context/snapshot updates.';
    lines{end+1} = '';
    lines{end+1} = '## Inputs';
    for i = 1:numel(reqPaths)
        lines{end+1} = sprintf('- `%s`', reqPaths{i});
    end
    lines{end+1} = sprintf('- gate_pass_confirmed = %s', string(gatePass));
    lines{end+1} = sprintf('- hierarchy_used_width_scaling_NO = %s', string(hierWidthNo));
    lines{end+1} = '';
    lines{end+1} = '## Backbone checks (key metrics)';
    lines{end+1} = sprintf('- CDF monotonic good fraction = %.6g', cdfGoodFrac);
    lines{end+1} = sprintf('- PT_pdf finite-good = %.6g, negative-good = %.6g, median |integral-1| = %.6g', pFiniteGood, pNegGood, pIntErr);
    lines{end+1} = sprintf('- Backbone formula proxy median relative RMSE (S_model_pt vs S_peak*CDF_pt) = %.6g', relErrMed);
    lines{end+1} = sprintf('- Residual highCDF/midCDF ratio = %.6g', highTailVsMid);
    lines{end+1} = sprintf('- HighT/rest residual ratio = %.6g', highVsRestRatio);
    lines{end+1} = sprintf('- Transition22_24/neighbors ratio = %.6g', transVsNeighRatio);
    lines{end+1} = sprintf('- Spearman(kappa2, high_CDF_tail_weight) = %.6g', rhoTailK2);
    lines{end+1} = sprintf('- Spearman(kappa2, high_CDF_tail_residual_energy) = %.6g', rhoFailK2);
    lines{end+1} = '';
    lines{end+1} = '## Required status flags';
    lines{end+1} = sprintf('- BACKBONE_VALID_FOR_RESIDUAL_ANALYSIS = %s', flagBackboneValid);
    lines{end+1} = sprintf('- CDF_PT_MONOTONIC = %s', flagCdfMonotonic);
    lines{end+1} = sprintf('- PT_PDF_VALID = %s', flagPtPdfValid);
    lines{end+1} = sprintf('- BACKBONE_FORMULA_CONSISTENT = %s', flagFormulaConsistent);
    lines{end+1} = sprintf('- BACKBONE_FAILURE_LOCALIZED_IN_HIGH_CDF_TAIL = %s', flagTailFailure);
    lines{end+1} = sprintf('- HIGH_T_BACKBONE_FAILURE = %s', flagHighTFailure);
    lines{end+1} = sprintf('- TRANSITION_22_24_BACKBONE_KINK = %s', flagTransitionKink);
    lines{end+1} = sprintf('- KAPPA2_HIGH_CDF_TAIL_LEAD_BACKBONE_RELATED = %s', flagK2TailRelated);
    lines{end+1} = sprintf('- READY_FOR_PHASE_C_MODE_ADMISSIBILITY = %s', flagReadyPhaseC);
    lines{end+1} = '';
    if strcmp(flagBackboneValid, 'PARTIAL')
        lines{end+1} = '## Phase C restrictions (required because backbone validity is PARTIAL)';
        lines{end+1} = '- Restrict Phase C mode-admissibility interpretations to CDF windows where PT_pdf validity and CDF monotonicity pass.';
        lines{end+1} = '- Add tail-focused controls: explicitly condition mode diagnostics on high-CDF residual-energy burden.';
        lines{end+1} = '- Treat 22–24 K and high-T bins as stratified subsets in Phase C significance checks.';
        lines{end+1} = '';
    end
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_backbone_validity_cdf_diagnostics.csv`';
    lines{end+1} = '- `tables/switching_backbone_validity_ptpdf_diagnostics.csv`';
    lines{end+1} = '- `tables/switching_backbone_validity_residual_localization.csv`';
    lines{end+1} = '- `tables/switching_backbone_validity_temperature_audit.csv`';
    lines{end+1} = '- `tables/switching_backbone_validity_status.csv`';
    lines{end+1} = '- `reports/switching_backbone_validity_audit.md`';
    lines{end+1} = sprintf('- run figure `.fig`: `%s`', figPath);
    lines{end+1} = sprintf('- run figure `.png`: `%s`', pngPath);
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_backbone_validity_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_backbone_validity_audit.md'), lines, 'run_switching_backbone_validity_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'backbone validity audit completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0, fprintf(fidBottom, 'SCRIPT_COMPLETED\n'); fclose(fidBottom); end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_backbone_validity_audit_failure');
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
    writetable(gateTbl, fullfile(runDir, 'tables', 'switching_backbone_validity_input_gate_status.csv'));
    writetable(gateTbl, fullfile(repoRoot, 'tables', 'switching_backbone_validity_input_gate_status.csv'));

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        {'BACKBONE_VALID_FOR_RESIDUAL_ANALYSIS'; 'CDF_PT_MONOTONIC'; 'PT_PDF_VALID'; ...
         'BACKBONE_FORMULA_CONSISTENT'; 'BACKBONE_FAILURE_LOCALIZED_IN_HIGH_CDF_TAIL'; ...
         'HIGH_T_BACKBONE_FAILURE'; 'TRANSITION_22_24_BACKBONE_KINK'; ...
         'KAPPA2_HIGH_CDF_TAIL_LEAD_BACKBONE_RELATED'; 'READY_FOR_PHASE_C_MODE_ADMISSIBILITY'}, ...
        {'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'}, ...
        {failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg; failMsg}, ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_backbone_validity_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_backbone_validity_status.csv'));

    cdfFail = table(zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), string.empty(0,1), ...
        'VariableNames', {'T_K','cdf_finite_fraction','cdf_min','cdf_max','cdf_monotonic_violations','cdf_monotonic_flag'});
    pFail = table(zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'T_K','ptpdf_finite_fraction','ptpdf_negative_fraction','ptpdf_integral','ptpdf_tail_mass_low','ptpdf_tail_mass_high'});
    locFail = table(zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'T_K','residual_energy_total','residual_energy_low_cdf','residual_energy_mid_cdf','residual_energy_high_cdf','high_cdf_tail_weight','backbone_formula_rmse','backbone_formula_rel_rmse'});
    tempFail = table(string.empty(0,1), zeros(0,1), string.empty(0,1), ...
        'VariableNames', {'metric','value','bins_included'});
    writetable(cdfFail, fullfile(runDir, 'tables', 'switching_backbone_validity_cdf_diagnostics.csv'));
    writetable(cdfFail, fullfile(repoRoot, 'tables', 'switching_backbone_validity_cdf_diagnostics.csv'));
    writetable(pFail, fullfile(runDir, 'tables', 'switching_backbone_validity_ptpdf_diagnostics.csv'));
    writetable(pFail, fullfile(repoRoot, 'tables', 'switching_backbone_validity_ptpdf_diagnostics.csv'));
    writetable(locFail, fullfile(runDir, 'tables', 'switching_backbone_validity_residual_localization.csv'));
    writetable(locFail, fullfile(repoRoot, 'tables', 'switching_backbone_validity_residual_localization.csv'));
    writetable(tempFail, fullfile(runDir, 'tables', 'switching_backbone_validity_temperature_audit.csv'));
    writetable(tempFail, fullfile(repoRoot, 'tables', 'switching_backbone_validity_temperature_audit.csv'));

    lines = {};
    lines{end+1} = '# Canonical Switching backbone validity audit — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_backbone_validity_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_backbone_validity_audit.md'), lines, 'run_switching_backbone_validity_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'backbone validity audit failed'}, true);
    rethrow(ME);
end
