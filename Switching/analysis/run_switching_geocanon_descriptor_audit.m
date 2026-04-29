% SWITCHING NAMESPACE / EVIDENCE WARNING
% NAMESPACE_ID: DIAGNOSTIC_FORENSIC / geocanon descriptor branch — NOT backbone physics equivalence
% EVIDENCE_STATUS: DESCRIPTOR_AUDIT — manuscript interpretation blocked unless promoted by charter (see governance map)
% SAFE_USE: atlas / descriptor inventories with DIAGNOSTIC labels
% UNSAFE_USE: importing geocanon descriptors into CORRECTED_CANONICAL_OLD_ANALYSIS claims without bridge
% CURRENT_STATE_ENTRYPOINT: reports/switching_corrected_canonical_current_state.md
clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
runTables = '';
runReports = '';

outValuesName = 'switching_geocanon_descriptor_values.csv';
outRobustName = 'switching_geocanon_descriptor_robustness.csv';
outStatusName = 'switching_geocanon_descriptor_status.csv';
outRisksName = 'switching_geocanon_descriptor_risks.csv';
outReportName = 'switching_geocanon_descriptor_audit.md';

try
    cfg = struct();
    cfg.runLabel = 'switching_geocanon_descriptor_audit';
    cfg.dataset = 'switching_geocanon_descriptor_audit';
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
    if fidTop >= 0
        fprintf(fidTop, 'SCRIPT_ENTERED\n');
        fclose(fidTop);
    end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'geocanon descriptor audit initialized'}, false);

    % Canonical input lock.
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    if strlength(string(sLongPath)) == 0 || exist(sLongPath, 'file') ~= 2
        error('run_switching_geocanon_descriptor_audit:MissingSLong', ...
            'Missing canonical input switching_canonical_S_long.csv');
    end
    obsPath = strrep(sLongPath, 'switching_canonical_S_long.csv', 'switching_canonical_observables.csv');
    hasObs = exist(obsPath, 'file') == 2;
    if hasObs
        obsTbl = readtable(obsPath, 'VariableNamingRule', 'preserve');
    else
        obsTbl = table();
    end

    sLong = readtable(sLongPath, 'VariableNamingRule', 'preserve');
    req = {'T_K', 'current_mA', 'S_percent'};
    for i = 1:numel(req)
        if ~ismember(req{i}, sLong.Properties.VariableNames)
            error('run_switching_geocanon_descriptor_audit:Schema', ...
                'switching_canonical_S_long.csv missing required column %s', req{i});
        end
    end

    T = double(sLong.T_K);
    I = double(sLong.current_mA);
    S = double(sLong.S_percent);
    if ismember('CDF_pt', sLong.Properties.VariableNames)
        C = double(sLong.CDF_pt);
    else
        C = NaN(size(S));
    end
    v = isfinite(T) & isfinite(I) & isfinite(S);
    T = T(v);
    I = I(v);
    S = S(v);
    C = C(v);
    G = groupsummary(table(T, I, S, C), {'T','I'}, 'mean', {'S','C'});
    allT = unique(double(G.T), 'sorted');
    allI = unique(double(G.I), 'sorted');
    nT = numel(allT);
    nI = numel(allI);
    Smap = NaN(nT, nI);
    Cmap = NaN(nT, nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(G.T)-allT(it)) < 1e-9 & abs(double(G.I)-allI(ii)) < 1e-9;
            if any(m)
                j = find(m, 1, 'first');
                Smap(it, ii) = double(G.mean_S(j));
                if ismember('mean_C', G.Properties.VariableNames)
                    Cmap(it, ii) = double(G.mean_C(j));
                end
            end
        end
    end

    validRows = any(isfinite(Smap), 2);
    activeDomainRows = allT(validRows);

    ridge_center_max = NaN(nT, 1);
    ridge_center_grad = NaN(nT, 1);
    ridge_center_weighted = NaN(nT, 1);
    ridge_center = NaN(nT, 1);
    ridge_amp = NaN(nT, 1);
    ridge_area = NaN(nT, 1);
    w_perp = NaN(nT, 1);
    skew_perp = NaN(nT, 1);
    tail_weight_perp = NaN(nT, 1);
    ridge_tangent_I = NaN(nT, 1);
    ridge_tangent_T = NaN(nT, 1);
    ridge_normal_I = NaN(nT, 1);
    ridge_normal_T = NaN(nT, 1);

    for it = 1:nT
        row = Smap(it, :);
        finiteMask = isfinite(row);
        if ~any(finiteMask)
            continue;
        end
        iVals = allI(finiteMask);
        sVals = row(finiteMask);
        iVals = iVals(:);
        sVals = sVals(:);

        [~, idxMax] = max(sVals);
        ridge_center_max(it) = iVals(idxMax);

        if numel(iVals) >= 3
            gradVals = gradient(sVals, iVals);
            [~, idxGrad] = max(abs(gradVals));
            ridge_center_grad(it) = iVals(idxGrad);
        end

        minS = min(sVals);
        weights = sVals - minS;
        weights(weights < 0) = 0;
        if sum(weights) <= eps
            weights = abs(sVals);
        end
        if sum(weights) > eps
            ridge_center_weighted(it) = sum(iVals .* weights) / sum(weights);
            center = ridge_center_weighted(it);
        else
            center = ridge_center_max(it);
        end
        ridge_center(it) = center;

        if numel(iVals) >= 2
            ridge_amp(it) = interp1(iVals, sVals, center, 'linear', 'extrap');
            sPos = sVals;
            sPos(sPos < 0) = 0;
            if sum(sPos) > eps
                ridge_area(it) = trapz(iVals, sPos);
                d = iVals - center;
                varW = sum(sPos .* (d.^2)) / sum(sPos);
                if isfinite(varW) && varW >= 0
                    w_perp(it) = sqrt(varW);
                end
                m3 = sum(sPos .* (d.^3)) / sum(sPos);
                if isfinite(varW) && varW > eps
                    skew_perp(it) = m3 / (varW^(3/2));
                end
                if isfinite(w_perp(it)) && w_perp(it) > 0
                    farMask = abs(d) > w_perp(it);
                    tail_weight_perp(it) = sum(sPos(farMask)) / sum(sPos);
                end
            else
                ridge_area(it) = trapz(iVals, sVals);
            end
        else
            ridge_amp(it) = sVals(1);
            ridge_area(it) = sVals(1);
        end
    end

    finiteCenter = isfinite(ridge_center) & isfinite(allT);
    if nnz(finiteCenter) >= 3
        tGood = allT(finiteCenter);
        cGood = ridge_center(finiteCenter);
        dcdt = gradient(cGood, tGood);
        d2cdt2 = gradient(dcdt, tGood);
        ridge_curvature = NaN(nT, 1);
        ridge_curvature(finiteCenter) = d2cdt2;
        for k = 1:numel(tGood)
            idx = find(abs(allT - tGood(k)) < 1e-9, 1, 'first');
            vI = dcdt(k);
            vT = 1;
            nrm = sqrt(vI.^2 + vT.^2);
            if nrm > 0
                ridge_tangent_I(idx) = vI / nrm;
                ridge_tangent_T(idx) = vT / nrm;
                ridge_normal_I(idx) = -vT / nrm;
                ridge_normal_T(idx) = vI / nrm;
            end
        end
    else
        ridge_curvature = NaN(nT, 1);
    end

    % Reactivity candidate: normalized blend of center motion, width, curvature, skew.
    reactivity_geocanon_candidate = NaN(nT, 1);
    dcenter = NaN(nT, 1);
    if nnz(finiteCenter) >= 3
        tGood = allT(finiteCenter);
        cGood = ridge_center(finiteCenter);
        dc = gradient(cGood, tGood);
        dcenter(finiteCenter) = abs(dc);
    end
    z1 = NaN(nT, 1); z2 = NaN(nT, 1); z3 = NaN(nT, 1); z4 = NaN(nT, 1);
    m = isfinite(dcenter); if nnz(m) >= 2, z1(m) = (dcenter(m)-mean(dcenter(m),'omitnan'))/max(std(dcenter(m),0,'omitnan'),eps); end
    m = isfinite(w_perp); if nnz(m) >= 2, z2(m) = (w_perp(m)-mean(w_perp(m),'omitnan'))/max(std(w_perp(m),0,'omitnan'),eps); end
    m = isfinite(ridge_curvature); if nnz(m) >= 2, z3(m) = (abs(ridge_curvature(m))-mean(abs(ridge_curvature(m)),'omitnan'))/max(std(abs(ridge_curvature(m)),0,'omitnan'),eps); end
    m = isfinite(skew_perp); if nnz(m) >= 2, z4(m) = (abs(skew_perp(m))-mean(abs(skew_perp(m)),'omitnan'))/max(std(abs(skew_perp(m)),0,'omitnan'),eps); end
    for it = 1:nT
        comp = [z1(it), z2(it), z3(it), z4(it)];
        comp = comp(isfinite(comp));
        if ~isempty(comp)
            reactivity_geocanon_candidate(it) = mean(comp);
        end
    end

    valuesTbl = table(allT, ridge_center_max, ridge_center_grad, ridge_center_weighted, ridge_center, ...
        ridge_tangent_I, ridge_tangent_T, ridge_normal_I, ridge_normal_T, ...
        w_perp, ridge_amp, ridge_area, ridge_curvature, skew_perp, tail_weight_perp, ...
        reactivity_geocanon_candidate, ...
        'VariableNames', { ...
        'T_K', 'ridge_center_max_response_geocanon', 'ridge_center_gradient_response_geocanon', ...
        'ridge_center_weighted_geocanon', 'ridge_center_geocanon', ...
        'ridge_tangent_I_geocanon', 'ridge_tangent_T_geocanon', ...
        'ridge_normal_I_geocanon', 'ridge_normal_T_geocanon', ...
        'w_perp_geocanon', 'S_ridge_amp_geocanon', 'S_ridge_area_geocanon', ...
        'ridge_curvature_geocanon', 'skew_perp_geocanon', 'tail_weight_perp_geocanon', ...
        'reactivity_geocanon_candidate'});
    switchingWriteTableBothPaths(valuesTbl, repoRoot, runTables, outValuesName);

    % Robustness summaries.
    delta_max_weighted = abs(ridge_center_max - ridge_center_weighted);
    delta_grad_weighted = abs(ridge_center_grad - ridge_center_weighted);
    delta_max_grad = abs(ridge_center_max - ridge_center_grad);
    nCenter = sum(isfinite(ridge_center));
    robustRows = table();
    robustRows = [robustRows; table(string('active_ridge_center_variant_overlap'), nCenter, ...
        mean(delta_max_weighted, 'omitnan'), median(delta_max_weighted, 'omitnan'), ...
        max(delta_max_weighted, [], 'omitnan'), ...
        string('max_response vs weighted_center'), ...
        'VariableNames', {'metric','n_valid','mean_abs_diff','median_abs_diff','max_abs_diff','notes'})]; %#ok<AGROW>
    robustRows = [robustRows; table(string('active_ridge_center_variant_overlap_grad'), nCenter, ...
        mean(delta_grad_weighted, 'omitnan'), median(delta_grad_weighted, 'omitnan'), ...
        max(delta_grad_weighted, [], 'omitnan'), ...
        string('gradient_response vs weighted_center'), ...
        'VariableNames', {'metric','n_valid','mean_abs_diff','median_abs_diff','max_abs_diff','notes'})]; %#ok<AGROW>
    robustRows = [robustRows; table(string('active_ridge_center_variant_overlap_max_vs_grad'), nCenter, ...
        mean(delta_max_grad, 'omitnan'), median(delta_max_grad, 'omitnan'), ...
        max(delta_max_grad, [], 'omitnan'), ...
        string('max_response vs gradient_response'), ...
        'VariableNames', {'metric','n_valid','mean_abs_diff','median_abs_diff','max_abs_diff','notes'})]; %#ok<AGROW>
    robustRows = [robustRows; table(string('w_perp_geocanon_finite_fraction'), nT, ...
        mean(isfinite(w_perp)), NaN, NaN, ...
        string('fraction of T rows with finite w_perp_geocanon'), ...
        'VariableNames', {'metric','n_valid','mean_abs_diff','median_abs_diff','max_abs_diff','notes'})]; %#ok<AGROW>
    robustRows = [robustRows; table(string('ridge_curvature_geocanon_finite_fraction'), nT, ...
        mean(isfinite(ridge_curvature)), NaN, NaN, ...
        string('fraction of T rows with finite ridge_curvature_geocanon'), ...
        'VariableNames', {'metric','n_valid','mean_abs_diff','median_abs_diff','max_abs_diff','notes'})]; %#ok<AGROW>
    robustRows = [robustRows; table(string('reactivity_geocanon_candidate_finite_fraction'), nT, ...
        mean(isfinite(reactivity_geocanon_candidate)), NaN, NaN, ...
        string('fraction of T rows with finite reactivity_geocanon_candidate'), ...
        'VariableNames', {'metric','n_valid','mean_abs_diff','median_abs_diff','max_abs_diff','notes'})]; %#ok<AGROW>
    switchingWriteTableBothPaths(robustRows, repoRoot, runTables, outRobustName);

    % Descriptor status.
    hasActiveRidge = nCenter >= max(3, ceil(0.6*nT));
    hasCenter = nCenter >= max(3, ceil(0.7*nT));
    hasPerp = mean(isfinite(w_perp)) >= 0.6;
    hasAmp = mean(isfinite(ridge_amp)) >= 0.8;
    hasReactivity = mean(isfinite(reactivity_geocanon_candidate)) >= 0.6;
    if hasActiveRidge, statusActive = 'PARTIAL'; else, statusActive = 'UNRESOLVED'; end
    if hasCenter, statusCenter = 'PARTIAL'; else, statusCenter = 'UNRESOLVED'; end
    if hasPerp, statusPerp = 'PARTIAL'; else, statusPerp = 'UNRESOLVED'; end
    if hasAmp, statusAmp = 'COMPLETE'; else, statusAmp = 'PARTIAL'; end
    if hasAmp, statusArea = 'PARTIAL'; else, statusArea = 'UNRESOLVED'; end
    if mean(isfinite(ridge_curvature)) >= 0.5, statusCurv = 'PARTIAL'; else, statusCurv = 'UNRESOLVED'; end
    if mean(isfinite(skew_perp)) >= 0.5, statusSkew = 'PARTIAL'; else, statusSkew = 'UNRESOLVED'; end
    if mean(isfinite(tail_weight_perp)) >= 0.5, statusTail = 'PARTIAL'; else, statusTail = 'UNRESOLVED'; end
    if hasReactivity, statusReact = 'PARTIAL'; else, statusReact = 'UNRESOLVED'; end

    statusRows = table();
    statusRows = [statusRows; table(string('active_ridge_geocanon'), string(statusActive), ...
        string('Extracted using multiple ridge-center variants; contract still variant-sensitive.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    statusRows = [statusRows; table(string('ridge_center_geocanon'), string(statusCenter), ...
        string('Weighted-center candidate exists over most T rows; tie-break rules still needed.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    statusRows = [statusRows; table(string('ridge_tangent_geocanon/ridge_normal_geocanon'), string(statusCenter), ...
        string('Computed where ridge_center_geocanon is finite and smooth enough.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    statusRows = [statusRows; table(string('w_perp_geocanon'), string(statusPerp), ...
        string('Perpendicular-width proxy computable on majority rows; strict frame contract pending.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    statusRows = [statusRows; table(string('S_ridge_amp_geocanon'), string(statusAmp), ...
        string('Directly extracted from canonical map at ridge_center_geocanon.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    statusRows = [statusRows; table(string('S_ridge_area_geocanon'), string(statusArea), ...
        string('Area candidate computed from nonnegative ridge-neighborhood response.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    statusRows = [statusRows; table(string('ridge_curvature_geocanon'), string(statusCurv), ...
        string('Second-derivative estimate available but sensitive to sparse-grid smoothing.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    statusRows = [statusRows; table(string('skew_perp_geocanon'), string(statusSkew), ...
        string('Cross-ridge skew candidate extracted where positive support exists.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    statusRows = [statusRows; table(string('tail_weight_perp_geocanon'), string(statusTail), ...
        string('Cross-ridge tail weight candidate extracted with width-based tail mask.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    statusRows = [statusRows; table(string('reactivity_geocanon_candidate'), string(statusReact), ...
        string('Composite candidate computed; utility gate not yet passed.'), ...
        'VariableNames', {'descriptor_name','status','detail'})]; %#ok<AGROW>
    % Combined descriptor + verdict status table is written after required verdicts are assembled.

    risksTbl = table( ...
        ["X_renaming_conflation";"perpendicular_frame_instability";"sparse_grid_curvature_instability";"cross_family_value_transfer"], ...
        ["HIGH";"MEDIUM";"HIGH";"MEDIUM"], ...
        ["Do not rename reactivity_geocanon_candidate to any X_canon-like label."; ...
         "ridge_normal_geocanon contract must be fixed before strict interpretation."; ...
         "ridge_curvature_geocanon highly sensitive to sparse current grid and smoothing choices."; ...
         "Compare to canonical_residual_decomposition by mapping categories only, not by value transfer."], ...
        'VariableNames', {'risk_id','risk_level','mitigation'});
    switchingWriteTableBothPaths(risksTbl, repoRoot, runTables, outRisksName);

    if hasActiveRidge, activeExtracted = 'PARTIAL'; else, activeExtracted = 'NO'; end
    if hasCenter, centerExtracted = 'PARTIAL'; else, centerExtracted = 'NO'; end
    if hasPerp, wPerpExtracted = 'PARTIAL'; else, wPerpExtracted = 'NO'; end
    if hasAmp, ampExtracted = 'YES'; else, ampExtracted = 'PARTIAL'; end
    if hasReactivity, reactExtracted = 'PARTIAL'; else, reactExtracted = 'NO'; end
    readyInterp = 'PARTIAL';
    if hasCenter, safeCompareResidual = 'YES'; else, safeCompareResidual = 'NO'; end

    verdictTbl = table( ...
        ["GEOCANON_DESCRIPTOR_AUDIT_COMPLETE";"SWITCHING_ONLY";"CANONICAL_SWITCHING_ARTIFACTS_ONLY"; ...
         "LEGACY_EVIDENCE_EXCLUDED";"CANONICAL_REPLAY_PERFORMED";"AGING_EVIDENCE_USED";"RELAXATION_EVIDENCE_USED"; ...
         "EXISTING_FILES_MOVED_OR_RENAMED";"ACTIVE_RIDGE_GEOCANON_EXTRACTED";"RIDGE_CENTER_GEOCANON_EXTRACTED"; ...
         "W_PERP_GEOCANON_EXTRACTED";"S_RIDGE_AMP_GEOCANON_EXTRACTED";"REACTIVITY_GEOCANON_CANDIDATE_COMPUTED"; ...
         "RISK_OF_RENAMING_X_OLD";"GEOCANON_DESCRIPTORS_READY_FOR_INTERPRETATION"; ...
         "SAFE_TO_COMPARE_GEOCANON_TO_RESIDUAL_CANON";"SAFE_TO_COMPARE_TO_RELAXATION"], ...
        ["YES";"YES";"YES";"YES";"NO";"NO";"NO";"NO"; ...
         string(activeExtracted); string(centerExtracted); string(wPerpExtracted); ...
         string(ampExtracted); string(reactExtracted); ...
         "HIGH"; string(readyInterp); string(safeCompareResidual); "NO"], ...
        'VariableNames', {'check','result'});

    lines = {};
    lines{end+1} = '# Switching canonical_geometric_decomposition descriptor audit';
    lines{end+1} = '';
    lines{end+1} = '## Scope';
    lines{end+1} = '- Switching-only, canonical artifact-only descriptor audit.';
    lines{end+1} = '- No canonical replay, no legacy evidence, no Aging/Relaxation evidence.';
    lines{end+1} = '- Geocanon descriptors are extracted directly from canonical S(I,T) map aggregates.';
    lines{end+1} = '';
    lines{end+1} = '## Canonical source lock';
    lines{end+1} = ['- `switching_canonical_S_long.csv`: `' sLongPath '`'];
    if hasObs
        lines{end+1} = ['- `switching_canonical_observables.csv`: `' obsPath '`'];
    else
        lines{end+1} = '- `switching_canonical_observables.csv`: not found; audit proceeds with S-map-only path.';
    end
    lines{end+1} = ['- Active T rows: ' num2str(nT) '; current-grid points: ' num2str(nI)];
    lines{end+1} = '';
    lines{end+1} = '## Extraction variants';
    lines{end+1} = '- ridge_center_max_response_geocanon: argmax S per T row.';
    lines{end+1} = '- ridge_center_gradient_response_geocanon: argmax |dS/dI| per T row (where supported).';
    lines{end+1} = '- ridge_center_weighted_geocanon: weighted centroid by shifted nonnegative S.';
    lines{end+1} = '- ridge_center_geocanon: weighted-center preferred; max-response fallback.';
    lines{end+1} = '';
    lines{end+1} = '## Descriptor summary';
    lines{end+1} = ['- ACTIVE_RIDGE_GEOCANON_EXTRACTED = ' char(string(activeExtracted))];
    lines{end+1} = ['- RIDGE_CENTER_GEOCANON_EXTRACTED = ' char(string(centerExtracted))];
    lines{end+1} = ['- W_PERP_GEOCANON_EXTRACTED = ' char(string(wPerpExtracted))];
    lines{end+1} = ['- S_RIDGE_AMP_GEOCANON_EXTRACTED = ' char(string(ampExtracted))];
    lines{end+1} = ['- REACTIVITY_GEOCANON_CANDIDATE_COMPUTED = ' char(string(reactExtracted))];
    lines{end+1} = '';
    lines{end+1} = '## Bounded context';
    lines{end+1} = '- canonical_residual_decomposition is not used to define descriptors; only safe comparison readiness is assessed.';
    lines{end+1} = '- No comparison to Relaxation is allowed in this audit.';
    lines{end+1} = '';
    lines{end+1} = '## Outputs';
    lines{end+1} = ['- `tables/' outValuesName '`'];
    lines{end+1} = ['- `tables/' outRobustName '`'];
    lines{end+1} = ['- `tables/' outStatusName '`'];
    lines{end+1} = ['- `tables/' outRisksName '`'];
    lines{end+1} = '';
    lines{end+1} = '## Required verdicts';
    for i = 1:height(verdictTbl)
        lines{end+1} = ['- ' char(verdictTbl.check(i)) '=' char(verdictTbl.result(i))];
    end

    switchingWriteTextLinesFile(fullfile(runReports, outReportName), lines, 'run_switching_geocanon_descriptor_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', outReportName), lines, 'run_switching_geocanon_descriptor_audit:WriteFail');
    verdictDetails = repmat("required_verdict", height(verdictTbl), 1);
    verdictStatusRows = table(string(verdictTbl.check), string(verdictTbl.result), verdictDetails, ...
        'VariableNames', {'descriptor_name','status','detail'});
    statusOut = [statusRows; verdictStatusRows];
    switchingWriteTableBothPaths(statusOut, repoRoot, runTables, outStatusName);

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'geocanon descriptor audit completed'}, true);

    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_geocanon_descriptor_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
        runTables = fullfile(runDir, 'tables');
        runReports = fullfile(runDir, 'reports');
        if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
        if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
        if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
        if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    end

    emptyValues = table();
    emptyRobust = table();
    emptyDescStatus = table();
    emptyRisks = table();
    switchingWriteTableBothPaths(emptyValues, repoRoot, runTables, outValuesName);
    switchingWriteTableBothPaths(emptyRobust, repoRoot, runTables, outRobustName);
    switchingWriteTableBothPaths(emptyDescStatus, repoRoot, runTables, outStatusName);
    switchingWriteTableBothPaths(emptyRisks, repoRoot, runTables, outRisksName);

    failVerdict = table( ...
        ["GEOCANON_DESCRIPTOR_AUDIT_COMPLETE";"SWITCHING_ONLY";"CANONICAL_SWITCHING_ARTIFACTS_ONLY"; ...
         "LEGACY_EVIDENCE_EXCLUDED";"CANONICAL_REPLAY_PERFORMED";"AGING_EVIDENCE_USED";"RELAXATION_EVIDENCE_USED"; ...
         "EXISTING_FILES_MOVED_OR_RENAMED";"ACTIVE_RIDGE_GEOCANON_EXTRACTED";"RIDGE_CENTER_GEOCANON_EXTRACTED"; ...
         "W_PERP_GEOCANON_EXTRACTED";"S_RIDGE_AMP_GEOCANON_EXTRACTED";"REACTIVITY_GEOCANON_CANDIDATE_COMPUTED"; ...
         "RISK_OF_RENAMING_X_OLD";"GEOCANON_DESCRIPTORS_READY_FOR_INTERPRETATION"; ...
         "SAFE_TO_COMPARE_GEOCANON_TO_RESIDUAL_CANON";"SAFE_TO_COMPARE_TO_RELAXATION"], ...
        ["NO";"YES";"NO";"YES";"NO";"NO";"NO";"NO"; ...
         "NO";"NO";"NO";"NO";"NO";"HIGH";"NO";"NO";"NO"], ...
        'VariableNames', {'check','result'});
    switchingWriteTableBothPaths(failVerdict, repoRoot, runTables, outStatusName);

    failLines = {};
    failLines{end+1} = '# Switching canonical_geometric_decomposition descriptor audit FAILED';
    failLines{end+1} = '';
    failLines{end+1} = ['- Identifier: `' char(string(ME.identifier)) '`'];
    failLines{end+1} = ['- Message: ' char(string(ME.message))];
    failLines{end+1} = '';
    failLines{end+1} = '## Required verdicts';
    for i = 1:height(failVerdict)
        failLines{end+1} = ['- ' char(failVerdict.check(i)) '=' char(failVerdict.result(i))];
    end
    switchingWriteTextLinesFile(fullfile(runReports, outReportName), failLines, 'run_switching_geocanon_descriptor_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', outReportName), failLines, 'run_switching_geocanon_descriptor_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'geocanon descriptor audit failed'}, true);
    rethrow(ME);
end
