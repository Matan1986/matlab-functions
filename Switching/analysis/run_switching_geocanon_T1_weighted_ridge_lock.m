clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
runTables = '';
runReports = '';

outValues = 'switching_geocanon_T1_weighted_ridge_values.csv';
outStability = 'switching_geocanon_T1_weighted_ridge_stability.csv';
outStatus = 'switching_geocanon_T1_weighted_ridge_status.csv';
outReport = 'switching_geocanon_T1_weighted_ridge_lock.md';

try
    cfg = struct();
    cfg.runLabel = 'switching_geocanon_T1_weighted_ridge_lock';
    cfg.dataset = 'switching_geocanon_T1_weighted_ridge_lock';
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
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'geocanon T1 weighted ridge lock initialized'}, false);

    % Inputs required by this step.
    priorValuesPath = fullfile(repoRoot, 'tables', 'switching_geocanon_descriptor_values.csv');
    priorRobustPath = fullfile(repoRoot, 'tables', 'switching_geocanon_descriptor_robustness.csv');
    priorStatusPath = fullfile(repoRoot, 'tables', 'switching_geocanon_descriptor_status.csv');
    diagnosisPath = fullfile(repoRoot, 'tables', 'switching_geocanon_partial_status_diagnosis.csv');
    variantPath = fullfile(repoRoot, 'tables', 'switching_geocanon_variant_disagreement_summary.csv');
    fixPlanPath = fullfile(repoRoot, 'tables', 'switching_geocanon_descriptor_fix_plan.csv');
    diagnosisReportPath = fullfile(repoRoot, 'reports', 'switching_geocanon_partial_status_diagnosis.md');
    required = {priorValuesPath, priorRobustPath, priorStatusPath, diagnosisPath, variantPath, fixPlanPath, diagnosisReportPath};
    for i = 1:numel(required)
        if exist(required{i}, 'file') ~= 2
            error('run_switching_geocanon_T1_weighted_ridge_lock:MissingInput', ...
                'Required T1 input missing: %s', required{i});
        end
    end
    priorValuesTbl = readtable(priorValuesPath, 'VariableNamingRule', 'preserve');
    priorRobustTbl = readtable(priorRobustPath, 'VariableNamingRule', 'preserve');
    priorStatusTbl = readtable(priorStatusPath, 'VariableNamingRule', 'preserve'); %#ok<NASGU>
    diagnosisTbl = readtable(diagnosisPath, 'VariableNamingRule', 'preserve');
    variantTbl = readtable(variantPath, 'VariableNamingRule', 'preserve');
    fixPlanTbl = readtable(fixPlanPath, 'VariableNamingRule', 'preserve');

    if height(priorValuesTbl) < 3
        error('run_switching_geocanon_T1_weighted_ridge_lock:InsufficientPriorRows', ...
            'Prior geocanon descriptor values are insufficient for T1 lock.');
    end

    % Canonical Switching source-of-truth map.
    sLongPath = switchingResolveLatestCanonicalTable(repoRoot, 'switching_canonical_S_long.csv');
    if strlength(string(sLongPath)) == 0 || exist(sLongPath, 'file') ~= 2
        error('run_switching_geocanon_T1_weighted_ridge_lock:MissingCanonicalSLong', ...
            'Missing canonical source-of-truth switching_canonical_S_long.csv');
    end
    sLong = readtable(sLongPath, 'VariableNamingRule', 'preserve');
    neededCols = {'T_K', 'current_mA', 'S_percent'};
    for i = 1:numel(neededCols)
        if ~ismember(neededCols{i}, sLong.Properties.VariableNames)
            error('run_switching_geocanon_T1_weighted_ridge_lock:Schema', ...
                'Missing required canonical column: %s', neededCols{i});
        end
    end

    T = double(sLong.T_K);
    I = double(sLong.current_mA);
    S = double(sLong.S_percent);
    keep = isfinite(T) & isfinite(I) & isfinite(S);
    T = T(keep);
    I = I(keep);
    S = S(keep);
    if isempty(T)
        error('run_switching_geocanon_T1_weighted_ridge_lock:NoFiniteData', ...
            'Canonical S grid has no finite rows.');
    end

    G = groupsummary(table(T, I, S), {'T', 'I'}, 'mean', {'S'});
    allT = unique(double(G.T), 'sorted');
    allI = unique(double(G.I), 'sorted');
    nT = numel(allT);
    nI = numel(allI);
    if nT < 3 || nI < 3
        error('run_switching_geocanon_T1_weighted_ridge_lock:GridTooSmall', ...
            'Canonical S grid cannot support deterministic weighted ridge extraction.');
    end

    Smap = NaN(nT, nI);
    for it = 1:nT
        for ii = 1:nI
            m = abs(double(G.T)-allT(it)) < 1e-9 & abs(double(G.I)-allI(ii)) < 1e-9;
            if any(m)
                j = find(m, 1, 'first');
                Smap(it, ii) = double(G.mean_S(j));
            end
        end
    end

    ridge_center_geocanon_primary = NaN(nT, 1);
    ridge_center_weighted_geocanon = NaN(nT, 1);
    ridge_center_max_response_geocanon = NaN(nT, 1);
    ridge_center_gradient_response_geocanon = NaN(nT, 1);
    tie_rule_code = strings(nT, 1);
    tie_rule_note = strings(nT, 1);
    valid_T_row = false(nT, 1);

    for it = 1:nT
        row = Smap(it, :);
        finiteMask = isfinite(row);
        if ~any(finiteMask)
            error('run_switching_geocanon_T1_weighted_ridge_lock:RowNoFinite', ...
                'T row %.6g has no finite S values.', allT(it));
        end
        iVals = allI(finiteMask);
        sVals = row(finiteMask);
        iVals = iVals(:);
        sVals = sVals(:);
        valid_T_row(it) = true;

        % Diagnostic max-response ridge center.
        [maxVal, idxMax] = max(sVals);
        idxMaxSet = find(abs(sVals - maxVal) <= 1e-12);
        if numel(idxMaxSet) == 1
            ridge_center_max_response_geocanon(it) = iVals(idxMax);
        else
            ridge_center_max_response_geocanon(it) = mean(iVals(idxMaxSet));
        end

        % Diagnostic gradient-response ridge center.
        if numel(iVals) >= 3
            gradVals = gradient(sVals, iVals);
            absGrad = abs(gradVals);
            gmax = max(absGrad);
            idxGradSet = find(abs(absGrad - gmax) <= 1e-12);
            if isempty(idxGradSet)
                ridge_center_gradient_response_geocanon(it) = NaN;
            else
                ridge_center_gradient_response_geocanon(it) = mean(iVals(idxGradSet));
            end
        else
            ridge_center_gradient_response_geocanon(it) = NaN;
        end

        % Weighted primary ridge center with deterministic tie-break policy:
        % 1) base weights = sVals - min(sVals), clipped to >=0.
        % 2) if all base weights ~0, fallback weights = abs(sVals).
        % 3) if fallback also all ~0 -> fail loudly (unsupported row).
        % 4) if weighted center lands outside [min(iVals), max(iVals)] -> fail loudly.
        % 5) if multiple equal max weights exist, deterministic weighted mean still applies.
        w0 = sVals - min(sVals);
        w0(w0 < 0) = 0;
        sumW0 = sum(w0);
        if isfinite(sumW0) && sumW0 > eps
            wUse = w0;
            tie_rule_code(it) = "BASE_SHIFT_WEIGHTS";
            tie_rule_note(it) = "weights=s-min(s); weighted mean primary";
        else
            w1 = abs(sVals);
            sumW1 = sum(w1);
            if isfinite(sumW1) && sumW1 > eps
                wUse = w1;
                tie_rule_code(it) = "ABS_FALLBACK_WEIGHTS";
                tie_rule_note(it) = "base weights degenerate; fallback to abs(s)";
            else
                error('run_switching_geocanon_T1_weighted_ridge_lock:ZeroWeightRow', ...
                    'T row %.6g has zero base and fallback weights.', allT(it));
            end
        end

        wc = sum(iVals .* wUse) / sum(wUse);
        if ~isfinite(wc) || wc < (min(iVals)-1e-9) || wc > (max(iVals)+1e-9)
            error('run_switching_geocanon_T1_weighted_ridge_lock:WeightedCenterOutOfBounds', ...
                'Weighted center invalid at T=%.6g', allT(it));
        end
        ridge_center_weighted_geocanon(it) = wc;
        ridge_center_geocanon_primary(it) = wc;
    end

    delta_max_weighted = abs(ridge_center_max_response_geocanon - ridge_center_geocanon_primary);
    delta_grad_weighted = abs(ridge_center_gradient_response_geocanon - ridge_center_geocanon_primary);
    finitePrimaryFrac = mean(isfinite(ridge_center_geocanon_primary) & valid_T_row);
    finiteMaxFrac = mean(isfinite(ridge_center_max_response_geocanon) & valid_T_row);
    finiteGradFrac = mean(isfinite(ridge_center_gradient_response_geocanon) | ~valid_T_row);

    meanMaxWeighted = mean(delta_max_weighted, 'omitnan');
    medianMaxWeighted = median(delta_max_weighted, 'omitnan');
    maxMaxWeighted = max(delta_max_weighted, [], 'omitnan');
    fracMaxWeightedWithin2 = mean(delta_max_weighted <= 2, 'omitnan');
    fracMaxWeightedWithin3 = mean(delta_max_weighted <= 3, 'omitnan');

    meanGradWeighted = mean(delta_grad_weighted, 'omitnan');
    medianGradWeighted = median(delta_grad_weighted, 'omitnan');
    maxGradWeighted = max(delta_grad_weighted, [], 'omitnan');
    fracGradWeightedWithin2 = mean(delta_grad_weighted <= 2, 'omitnan');

    % Diagnosis support: treat gradient as diagnostic-only if prior diagnosis says so.
    q2 = "";
    q7 = "";
    diagnosisQuestions = string(diagnosisTbl{:, 1});
    diagnosisAnswers = string(diagnosisTbl{:, 2});
    idxQ2 = find(strcmp(diagnosisQuestions, 'Q2_variant_relation'), 1, 'first');
    if ~isempty(idxQ2), q2 = diagnosisAnswers(idxQ2); end
    idxQ7 = find(strcmp(diagnosisQuestions, 'Q7_primary_vs_multi_variant_next'), 1, 'first');
    if ~isempty(idxQ7), q7 = diagnosisAnswers(idxQ7); end
    q2n = lower(strtrim(char(q2)));
    q7n = lower(strtrim(char(q7)));
    supportFromDiagnosisTable = ...
        strcmp(q2n, 'weighted_max_close_gradient_different') || ...
        contains(q7n, 'gradient_as_diagnostic_only') || ...
        contains(q7n, 'diagnostic');

    diagnosisReportText = lower(fileread(diagnosisReportPath));
    supportFromDiagnosisReport = ...
        contains(diagnosisReportText, 'keep max/gradient variants as diagnostics only') || ...
        contains(diagnosisReportText, 'single_primary_weighted_center_keep_gradient_as_diagnostic_only');

    fixText = lower(strjoin(string(fixPlanTbl{:, :}), ' '));
    supportFromFixPlan = contains(fixText, 'set gradient/max as diagnostics only');

    diagnosisSupportsGradientDiagnostic = supportFromDiagnosisTable || supportFromDiagnosisReport || supportFromFixPlan;

    % Additional cross-check from variant summary input.
    variantPair = string(variantTbl{:, 1});
    variantMean = double(variantTbl{:, 2});
    gradPairIdx = find(strcmp(variantPair, 'gradient_vs_weighted'), 1, 'first');
    maxPairIdx = find(strcmp(variantPair, 'max_vs_weighted'), 1, 'first');
    priorGradMean = NaN;
    priorMaxMean = NaN;
    if ~isempty(gradPairIdx), priorGradMean = variantMean(gradPairIdx); end
    if ~isempty(maxPairIdx), priorMaxMean = variantMean(maxPairIdx); end
    if ~isfinite(priorGradMean), priorGradMean = meanGradWeighted; end
    if ~isfinite(priorMaxMean), priorMaxMean = meanMaxWeighted; end
    gradientClearlyDifferent = isfinite(priorGradMean) && isfinite(priorMaxMean) && (priorGradMean > 2.0 * priorMaxMean);

    weightedLockFiniteGate = finitePrimaryFrac >= 0.99;
    weightedLockAgreementGate = fracMaxWeightedWithin2 >= 0.70 && meanMaxWeighted <= 2.0;
    weightedLockStrongGate = fracMaxWeightedWithin3 >= 0.85 && maxMaxWeighted <= 5.0;
    weightedPrimaryLocked = weightedLockFiniteGate && weightedLockAgreementGate && weightedLockStrongGate;

    maxDiagnosticOnly = true;
    gradientDiagnosticOnly = diagnosisSupportsGradientDiagnostic && gradientClearlyDifferent;

    ridgeCenterCompleted = "NO";
    if weightedPrimaryLocked && maxDiagnosticOnly && gradientDiagnosticOnly
        ridgeCenterCompleted = "YES";
    elseif weightedPrimaryLocked
        ridgeCenterCompleted = "PARTIAL";
    end

    safeToProceedT2 = "NO";
    if strcmp(ridgeCenterCompleted, "YES")
        safeToProceedT2 = "YES";
    end

    valuesTbl = table(allT, ...
        ridge_center_geocanon_primary, ...
        ridge_center_weighted_geocanon, ...
        ridge_center_max_response_geocanon, ...
        ridge_center_gradient_response_geocanon, ...
        tie_rule_code, tie_rule_note, valid_T_row, ...
        'VariableNames', {'T_K', ...
        'ridge_center_geocanon_primary', ...
        'ridge_center_weighted_geocanon', ...
        'ridge_center_max_response_geocanon', ...
        'ridge_center_gradient_response_geocanon', ...
        'weighted_tie_rule_code', 'weighted_tie_rule_note', 'valid_T_row'});
    switchingWriteTableBothPaths(valuesTbl, repoRoot, runTables, outValues);

    stabilityTbl = table( ...
        ["finite_primary_fraction"; ...
         "finite_max_diagnostic_fraction"; ...
         "finite_gradient_diagnostic_fraction"; ...
         "mean_abs_diff_max_vs_weighted_primary"; ...
         "median_abs_diff_max_vs_weighted_primary"; ...
         "max_abs_diff_max_vs_weighted_primary"; ...
         "frac_max_vs_weighted_within_2mA"; ...
         "frac_max_vs_weighted_within_3mA"; ...
         "mean_abs_diff_gradient_vs_weighted_primary"; ...
         "median_abs_diff_gradient_vs_weighted_primary"; ...
         "max_abs_diff_gradient_vs_weighted_primary"; ...
         "frac_gradient_vs_weighted_within_2mA"; ...
         "diagnosis_supports_gradient_diagnostic_only"; ...
         "gradient_clearly_different_from_weighted"; ...
         "weighted_lock_finite_gate"; ...
         "weighted_lock_agreement_gate"; ...
         "weighted_lock_strong_gate"], ...
        [finitePrimaryFrac; finiteMaxFrac; finiteGradFrac; meanMaxWeighted; medianMaxWeighted; maxMaxWeighted; ...
         fracMaxWeightedWithin2; fracMaxWeightedWithin3; ...
         meanGradWeighted; medianGradWeighted; maxGradWeighted; fracGradWeightedWithin2; ...
         double(diagnosisSupportsGradientDiagnostic); double(gradientClearlyDifferent); ...
         double(weightedLockFiniteGate); double(weightedLockAgreementGate); double(weightedLockStrongGate)], ...
        'VariableNames', {'metric','value'});
    switchingWriteTableBothPaths(stabilityTbl, repoRoot, runTables, outStability);

    if weightedPrimaryLocked, weightedPrimaryLockedTxt = "YES"; else, weightedPrimaryLockedTxt = "NO"; end
    if maxDiagnosticOnly, maxDiagnosticOnlyTxt = "YES"; else, maxDiagnosticOnlyTxt = "NO"; end
    if gradientDiagnosticOnly, gradientDiagnosticOnlyTxt = "YES"; else, gradientDiagnosticOnlyTxt = "NO"; end
    if diagnosisSupportsGradientDiagnostic, diagnosisSupportsGradTxt = "YES"; else, diagnosisSupportsGradTxt = "NO"; end

    statusTbl = table( ...
        ["GEOCANON_T1_WEIGHTED_RIDGE_LOCK_COMPLETE"; ...
         "SWITCHING_ONLY"; ...
         "CANONICAL_GEOMETRIC_DECOMPOSITION_ONLY"; ...
         "LEGACY_EVIDENCE_USED"; ...
         "CANONICAL_REPLAY_PERFORMED"; ...
         "AGING_EVIDENCE_USED"; ...
         "RELAXATION_EVIDENCE_USED"; ...
         "WEIGHTED_RIDGE_PRIMARY_LOCKED"; ...
         "MAX_RIDGE_DIAGNOSTIC_ONLY"; ...
         "GRADIENT_RIDGE_DIAGNOSTIC_ONLY"; ...
         "RIDGE_CENTER_GEOCANON_COMPLETED"; ...
         "SAFE_TO_PROCEED_TO_T2_WIDTH_FRAME"; ...
         "SAFE_TO_WRITE_GEOCANON_INTERPRETATION"; ...
         "SAFE_TO_COMPARE_TO_RELAXATION"], ...
        [ ...
         "YES"; "YES"; "YES"; "NO"; "NO"; "NO"; "NO"; ...
         string(weightedPrimaryLockedTxt); ...
         string(maxDiagnosticOnlyTxt); ...
         string(gradientDiagnosticOnlyTxt); ...
         string(ridgeCenterCompleted); ...
         string(safeToProceedT2); ...
         "NO"; ...
         "NO"], ...
        [ ...
         "T1 weighted primary lock run completed."; ...
         "Switching-only scope maintained."; ...
         "Geocanon-only scope maintained."; ...
         "No legacy evidence used."; ...
         "No canonical replay performed."; ...
         "No Aging evidence used."; ...
         "No Relaxation evidence used."; ...
         "Weighted center lock uses deterministic tie-break policy and gates."; ...
         "Max-response retained only as diagnostic comparator."; ...
         "Gradient-response retained as diagnostic-only due to physical-difference diagnosis."; ...
         "Completion determined by weighted-primary lock and diagnostic policy."; ...
         "Proceed to T2 only when ridge center is completed."; ...
         "Interpretation remains blocked in this T1 step."; ...
         "Relaxation comparison remains forbidden."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, outStatus);

    lines = {};
    lines{end+1} = '# Switching geocanon T1 weighted ridge lock';
    lines{end+1} = '';
    lines{end+1} = '## Scope';
    lines{end+1} = '- Switching only.';
    lines{end+1} = '- canonical_geometric_decomposition only.';
    lines{end+1} = '- No replay/legacy/Aging/Relaxation evidence.';
    lines{end+1} = '';
    lines{end+1} = '## Definition lock';
    lines{end+1} = '- ridge_center_geocanon_primary = weighted-center ridge (promoted).';
    lines{end+1} = '- ridge_center_max_response_geocanon = diagnostic only.';
    lines{end+1} = '- ridge_center_gradient_response_geocanon = diagnostic only.';
    lines{end+1} = '';
    lines{end+1} = '## Deterministic weighted tie-break policy';
    lines{end+1} = '- Base weights: s-min(s), clipped >=0.';
    lines{end+1} = '- If base weights degenerate: fallback to abs(s).';
    lines{end+1} = '- If fallback also degenerate: fail loudly.';
    lines{end+1} = '- If weighted center is out of row bounds: fail loudly.';
    lines{end+1} = '- Multi-peak/equal-max rows are handled by deterministic weighted mean.';
    lines{end+1} = '';
    lines{end+1} = '## T1 stability summary';
    lines{end+1} = ['- finite_primary_fraction=' num2str(finitePrimaryFrac, '%.4f')];
    lines{end+1} = ['- mean_abs_diff_max_vs_weighted_primary=' num2str(meanMaxWeighted, '%.4f')];
    lines{end+1} = ['- frac_max_vs_weighted_within_2mA=' num2str(fracMaxWeightedWithin2, '%.4f')];
    lines{end+1} = ['- mean_abs_diff_gradient_vs_weighted_primary=' num2str(meanGradWeighted, '%.4f')];
    lines{end+1} = ['- diagnosis_supports_gradient_diagnostic_only=' char(diagnosisSupportsGradTxt)];
    lines{end+1} = '';
    lines{end+1} = '## Required verdicts';
    for i = 1:height(statusTbl)
        lines{end+1} = ['- ' char(statusTbl.check(i)) '=' char(statusTbl.result(i))];
    end
    switchingWriteTextLinesFile(fullfile(runReports, outReport), lines, 'run_switching_geocanon_T1_weighted_ridge_lock:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', outReport), lines, 'run_switching_geocanon_T1_weighted_ridge_lock:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nT, {'geocanon T1 weighted ridge lock completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_geocanon_T1_weighted_ridge_lock_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
        runTables = fullfile(runDir, 'tables');
        runReports = fullfile(runDir, 'reports');
        if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
        if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
        if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
        if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    end

    emptyTbl = table();
    switchingWriteTableBothPaths(emptyTbl, repoRoot, runTables, outValues);
    switchingWriteTableBothPaths(emptyTbl, repoRoot, runTables, outStability);

    failStatus = table( ...
        ["GEOCANON_T1_WEIGHTED_RIDGE_LOCK_COMPLETE"; ...
         "SWITCHING_ONLY"; ...
         "CANONICAL_GEOMETRIC_DECOMPOSITION_ONLY"; ...
         "LEGACY_EVIDENCE_USED"; ...
         "CANONICAL_REPLAY_PERFORMED"; ...
         "AGING_EVIDENCE_USED"; ...
         "RELAXATION_EVIDENCE_USED"; ...
         "WEIGHTED_RIDGE_PRIMARY_LOCKED"; ...
         "MAX_RIDGE_DIAGNOSTIC_ONLY"; ...
         "GRADIENT_RIDGE_DIAGNOSTIC_ONLY"; ...
         "RIDGE_CENTER_GEOCANON_COMPLETED"; ...
         "SAFE_TO_PROCEED_TO_T2_WIDTH_FRAME"; ...
         "SAFE_TO_WRITE_GEOCANON_INTERPRETATION"; ...
         "SAFE_TO_COMPARE_TO_RELAXATION"], ...
        ["NO"; "YES"; "YES"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"], ...
        'VariableNames', {'check','result'});
    switchingWriteTableBothPaths(failStatus, repoRoot, runTables, outStatus);

    failLines = {};
    failLines{end+1} = '# Switching geocanon T1 weighted ridge lock FAILED';
    failLines{end+1} = '';
    failLines{end+1} = ['- Identifier: `' char(string(ME.identifier)) '`'];
    failLines{end+1} = ['- Message: ' char(string(ME.message))];
    switchingWriteTextLinesFile(fullfile(runReports, outReport), failLines, 'run_switching_geocanon_T1_weighted_ridge_lock:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', outReport), failLines, 'run_switching_geocanon_T1_weighted_ridge_lock:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'geocanon T1 weighted ridge lock failed'}, true);
    rethrow(ME);
end
