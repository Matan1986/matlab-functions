clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F6:RepoRootMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F6_AFM_FM_tau_comparison';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F6_AFM_FM_tau_comparison.m');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, 0, {'F6 AFM/FM tau comparison not executed'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('aging', cfg);

    runTablesDir = fullfile(run.run_dir, 'tables');
    runReportsDir = fullfile(run.run_dir, 'reports');
    if exist(runTablesDir, 'dir') ~= 7
        mkdir(runTablesDir);
    end
    if exist(runReportsDir, 'dir') ~= 7
        mkdir(runReportsDir);
    end

    pointerPath = fullfile(run.repo_root, 'run_dir_pointer.txt');
    fidPointer = fopen(pointerPath, 'w');
    if fidPointer < 0
        error('F6:PointerWriteFailed', 'Failed to write run_dir_pointer.txt');
    end
    fprintf(fidPointer, '%s\n', run.run_dir);
    fclose(fidPointer);

    pShared = fullfile(repoRoot, 'tables', 'aging', 'aging_F5_AFM_FM_tau_shared_domain.csv');
    pClaim = fullfile(repoRoot, 'tables', 'aging', 'aging_F5_AFM_FM_tau_claim_boundary.csv');
    pF5Stat = fullfile(repoRoot, 'tables', 'aging', 'aging_F5_AFM_FM_tau_readiness_status.csv');
    pAfmSel = fullfile(repoRoot, 'tables', 'aging', 'aging_F4A_AFM_tau_selected_values.csv');
    pFmSel = fullfile(repoRoot, 'tables', 'aging', 'aging_F4B_FM_tau_selected_values.csv');
    pAfmQ = fullfile(repoRoot, 'tables', 'aging', 'aging_F4A_AFM_tau_fit_quality.csv');
    pFmQ = fullfile(repoRoot, 'tables', 'aging', 'aging_F4B_FM_tau_fit_quality.csv');

    req = {pShared, pClaim, pF5Stat, pAfmSel, pFmSel, pAfmQ, pFmQ};
    for ir = 1:numel(req)
        if exist(req{ir}, 'file') ~= 2
            error('F6:MissingInput', 'Missing required input: %s', req{ir});
        end
    end

    sharedTbl = readtable(pShared, 'VariableNamingRule', 'preserve');
    claimTbl = readtable(pClaim, 'VariableNamingRule', 'preserve');
    f5stat = readtable(pF5Stat, 'VariableNamingRule', 'preserve');
    claimOk = false;
    if height(claimTbl) >= 1 && ismember('claim_level', claimTbl.Properties.VariableNames)
        for ic = 1:height(claimTbl)
            if strcmpi(strtrim(string(claimTbl.claim_level(ic))), 'LEVEL_2')
                claimOk = true;
                break;
            end
        end
    end
    if ~claimOk
        error('F6:ClaimBoundary', 'F5 claim boundary table must define LEVEL_2.');
    end
    afmSel = readtable(pAfmSel, 'VariableNamingRule', 'preserve');
    fmSel = readtable(pFmSel, 'VariableNamingRule', 'preserve');
    afmQ = readtable(pAfmQ, 'VariableNamingRule', 'preserve');
    fmQ = readtable(pFmQ, 'VariableNamingRule', 'preserve');

    if height(f5stat) < 1
        error('F6:F5StatusEmpty', 'F5 readiness status table is empty.');
    end
    cmpAllowed = upper(strtrim(string(f5stat.AFM_FM_TAU_COMPARISON_ALLOWED(1))));
    readyNext = upper(strtrim(string(f5stat.READY_FOR_NEXT_COMPARISON_STEP(1))));
    maxAllowed = upper(strtrim(string(f5stat.MAX_ALLOWED_CLAIM_LEVEL(1))));
    if ~strcmp(cmpAllowed, 'PARTIAL')
        error('F6:F5Gate', 'F5 AFM_FM_TAU_COMPARISON_ALLOWED must be PARTIAL for this step.');
    end
    if ~strcmp(readyNext, 'YES')
        error('F6:F5Gate', 'F5 READY_FOR_NEXT_COMPARISON_STEP must be YES.');
    end
    if ~contains(maxAllowed, 'LEVEL_2')
        error('F6:F5Gate', 'F5 MAX_ALLOWED_CLAIM_LEVEL must allow LEVEL_2.');
    end

    allowedTp = [22; 26; 30];
    nRows = height(sharedTbl);
    if nRows < 1
        error('F6:SharedEmpty', 'F5 shared domain table has no rows.');
    end

    tol = 1e-6 * max(1, max(sharedTbl.tau_AFM_physical_canon_replay));

    TpCol = zeros(nRows, 1);
    tauAfmCol = zeros(nRows, 1);
    tauFmCol = zeros(nRows, 1);
    ratioCol = zeros(nRows, 1);
    logRatioCol = zeros(nRows, 1);
    deltaCol = zeros(nRows, 1);
    afmR2Col = zeros(nRows, 1);
    fmR2Col = zeros(nRows, 1);
    afmQpassCol = strings(nRows, 1);
    fmQpassCol = strings(nRows, 1);
    afmNptCol = zeros(nRows, 1);
    fmNptCol = zeros(nRows, 1);
    afmSupCol = strings(nRows, 1);
    fmSupCol = strings(nRows, 1);
    verifiedCol = strings(nRows, 1);
    perTpInterp = strings(nRows, 1);

    for r = 1:nRows
        tp = sharedTbl.Tp(r);
        if ~any(allowedTp == tp)
            error('F6:TpOutOfDomain', 'Shared domain contains Tp not in F6 allow-list: %g', tp);
        end

        tauA = sharedTbl.tau_AFM_physical_canon_replay(r);
        tauF = sharedTbl.tau_FM_physical_canon_replay(r);
        if tauA <= 0 || tauF <= 0
            error('F6:NonPositiveTau', 'Non-positive tau at Tp %g.', tp);
        end

        ra = afmSel(afmSel.Tp == tp, :);
        rf = fmSel(fmSel.Tp == tp, :);
        if height(ra) ~= 1 || height(rf) ~= 1
            error('F6:JoinFail', 'Missing F4A/F4B selected row for Tp %g.', tp);
        end
        if abs(ra.tau_AFM_physical_canon_replay(1) - tauA) > tol * max(1, abs(tauA))
            error('F6:MismatchAFM', 'AFM tau mismatch vs F4A at Tp %g.', tp);
        end
        if abs(rf.tau_FM_physical_canon_replay(1) - tauF) > tol * max(1, abs(tauF))
            error('F6:MismatchFM', 'FM tau mismatch vs F4B at Tp %g.', tp);
        end

        qa = afmQ(afmQ.Tp == tp, :);
        qf = fmQ(fmQ.Tp == tp, :);
        if height(qa) ~= 1 || height(qf) ~= 1
            error('F6:QualityJoin', 'Missing fit-quality row for Tp %g.', tp);
        end

        rr = tauF / tauA;
        TpCol(r) = tp;
        tauAfmCol(r) = tauA;
        tauFmCol(r) = tauF;
        ratioCol(r) = rr;
        logRatioCol(r) = log10(rr);
        deltaCol(r) = tauF - tauA;
        afmR2Col(r) = sharedTbl.AFM_r2_primary(r);
        fmR2Col(r) = sharedTbl.FM_r2_primary(r);
        afmQpassCol(r) = string(qa.quality_pass(1));
        fmQpassCol(r) = string(qf.quality_pass(1));
        afmNptCol(r) = qa.n_points(1);
        fmNptCol(r) = qf.n_points(1);
        afmSupCol(r) = string(qa.support_class(1));
        fmSupCol(r) = string(qf.support_class(1));
        verifiedCol(r) = "YES";

        if rr < 0.25 || rr > 4
            perTpInterp(r) = "DESCRIPTIVE_SEPARATION";
        elseif rr >= 0.5 && rr <= 2
            perTpInterp(r) = "APPROXIMATE_SIMILARITY_SCALE";
        else
            perTpInterp(r) = "MODERATE_MISMATCH";
        end
    end

    meanLog = mean(logRatioCol);
    stdLog = std(logRatioCol);
    minRatio = min(ratioCol);
    maxRatio = max(ratioCol);
    medRatio = median(ratioCol);

    ratioSpanDecades = log10(maxRatio / minRatio);
    overallQual = "INCONCLUSIVE_BEHAVIOR";
    if ratioSpanDecades > 2
        overallQual = "INCONCLUSIVE_BEHAVIOR";
    elseif max(abs(logRatioCol)) < 0.3
        overallQual = "APPROXIMATE_SIMILARITY";
    else
        overallQual = "DESCRIPTIVE_SEPARATION_OR_MIXED";
    end

    comparisonVals = table(TpCol, tauAfmCol, tauFmCol, ratioCol, logRatioCol, deltaCol, ...
        afmR2Col, fmR2Col, afmQpassCol, fmQpassCol, afmNptCol, fmNptCol, afmSupCol, fmSupCol, verifiedCol, perTpInterp, ...
        'VariableNames', {'Tp', 'tau_AFM_physical_canon_replay', 'tau_FM_physical_canon_replay', ...
        'tau_FM_over_tau_AFM', 'log10_tau_FM_over_tau_AFM', 'tau_FM_minus_tau_AFM', ...
        'AFM_r2_primary', 'FM_r2_primary', 'AFM_quality_pass', 'FM_quality_pass', ...
        'AFM_n_points', 'FM_n_points', 'AFM_support_class', 'FM_support_class', ...
        'values_verified_vs_F4A_F4B', 'per_Tp_descriptive_pattern'});

    ratioSummary = table(nRows, meanLog, stdLog, minRatio, maxRatio, medRatio, ratioSpanDecades, overallQual, ...
        'VariableNames', {'n_shared_tp', 'mean_log10_ratio', 'std_log10_ratio', ...
        'min_tau_FM_over_tau_AFM', 'max_tau_FM_over_tau_AFM', 'median_tau_FM_over_tau_AFM', ...
        'ratio_span_decades', 'overall_descriptive_pattern'});

    rid = [ ...
        "F5_PARTIAL_ONLY"; ...
        "SHARED_TP_ONLY"; ...
        "NO_TP_14_18_34"; ...
        "NO_EXTRAPOLATION"; ...
        "NO_MECHANISM"; ...
        "NO_CROSS_MODULE"; ...
        "LEVEL_2_CAP"];
    rtx = [ ...
        "Comparison authorized only as PARTIAL per F5; not full-stack alignment."; ...
        "Quantities computed only for F5 shared selected Tp rows."; ...
        "Tp 14, 18, and 34 excluded from this comparison by contract."; ...
        "No extrapolation beyond Tp = 22, 26, 30."; ...
        "Not interpreted as mechanism validation."; ...
        "No Switching, Relaxation, or MT comparison."; ...
        "Maximum claim level for this step: LEVEL_2 within-Aging descriptive/quantitative only."];
    domainRestrictions = table(rid, rtx, 'VariableNames', {'restriction_id', 'restriction_text'});

    interpBoundary = table( ...
        "LEVEL_2", ...
        "Within-Aging descriptive ratios and deltas on shared Tp only; not mechanism.", ...
        "NO", ...
        "NO", ...
        overallQual ...
        , 'VariableNames', { ...
        'MAX_CLAIM_LEVEL_USED', ...
        'LEVEL_2_statement', ...
        'mechanism_validation_claim', ...
        'cross_module_relevance_claim', ...
        'overall_descriptive_assessment'});

    f6Status = table( ...
        "YES", ...
        "YES", ...
        nRows, ...
        "YES", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "LEVEL_2", ...
        "YES" ...
        , 'VariableNames', { ...
        'F6_AFM_FM_TAU_COMPARISON_COMPLETED', ...
        'F5_SHARED_DOMAIN_USED', ...
        'SHARED_SELECTED_TP_COUNT_USED', ...
        'ONLY_SHARED_TP_USED', ...
        'TP14_USED_IN_COMPARISON', ...
        'TP18_USED_IN_COMPARISON', ...
        'TP34_USED_IN_COMPARISON', ...
        'TAU_PROXY_AS_PHYSICAL_TAU_USED', ...
        'TRACKA_USED_AS_DIRECT_TAU_SOURCE', ...
        'CROSS_MODULE_ANALYSIS_PERFORMED', ...
        'MECHANISM_VALIDATION_PERFORMED', ...
        'GLOBAL_AGING_MECHANISM_CLAIMED', ...
        'MAX_CLAIM_LEVEL_USED', ...
        'READY_FOR_NEXT_LEVEL2_SUMMARY'});

    repoTablesDir = fullfile(repoRoot, 'tables', 'aging');
    repoReportsDir = fullfile(repoRoot, 'reports', 'aging');
    if exist(repoTablesDir, 'dir') ~= 7
        mkdir(repoTablesDir);
    end
    if exist(repoReportsDir, 'dir') ~= 7
        mkdir(repoReportsDir);
    end

    pVals = fullfile(repoTablesDir, 'aging_F6_AFM_FM_tau_comparison_values.csv');
    pSum = fullfile(repoTablesDir, 'aging_F6_AFM_FM_tau_ratio_summary.csv');
    pDom = fullfile(repoTablesDir, 'aging_F6_AFM_FM_tau_domain_restrictions.csv');
    pInterp = fullfile(repoTablesDir, 'aging_F6_AFM_FM_tau_interpretation_boundary.csv');
    pStat = fullfile(repoTablesDir, 'aging_F6_AFM_FM_tau_status.csv');

    writetable(comparisonVals, pVals);
    writetable(ratioSummary, pSum);
    writetable(domainRestrictions, pDom);
    writetable(interpBoundary, pInterp);
    writetable(f6Status, pStat);

    writetable(comparisonVals, fullfile(runTablesDir, 'aging_F6_AFM_FM_tau_comparison_values.csv'));
    writetable(ratioSummary, fullfile(runTablesDir, 'aging_F6_AFM_FM_tau_ratio_summary.csv'));
    writetable(domainRestrictions, fullfile(runTablesDir, 'aging_F6_AFM_FM_tau_domain_restrictions.csv'));
    writetable(interpBoundary, fullfile(runTablesDir, 'aging_F6_AFM_FM_tau_interpretation_boundary.csv'));
    writetable(f6Status, fullfile(runTablesDir, 'aging_F6_AFM_FM_tau_status.csv'));

    reportPath = fullfile(repoReportsDir, 'aging_F6_AFM_FM_tau_comparison.md');
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('F6:ReportWriteFailed', 'Failed to write report: %s', reportPath);
    end
    fprintf(fidReport, '# Aging F6 AFM/FM physical tau comparison (within-Aging, shared domain)\n\n');
    fprintf(fidReport, '## Scope and claim level\n');
    fprintf(fidReport, '- LEVEL_2 only: descriptive/quantitative within-Aging statements on shared Tp.\n');
    fprintf(fidReport, '- Domain: Tp = 22, 26, 30 per F5 shared selected domain.\n');
    fprintf(fidReport, '- No mechanism validation and no cross-module claims.\n\n');
    fprintf(fidReport, '## Inputs and gates\n');
    fprintf(fidReport, '- F5 AFM_FM_TAU_COMPARISON_ALLOWED = PARTIAL (verified).\n');
    fprintf(fidReport, '- Physical tau values cross-checked vs F4A/F4B selected tables.\n\n');
    fprintf(fidReport, '## Quantities\n');
    fprintf(fidReport, '- tau_FM_over_tau_AFM, log10 ratio, difference, and fit-quality context per Tp.\n\n');
    fprintf(fidReport, '## Summary pattern\n');
    fprintf(fidReport, '- Overall descriptive pattern: %s\n', overallQual);
    fprintf(fidReport, '- Ratio span (decades): %g\n\n', ratioSpanDecades);
    fprintf(fidReport, '## Required verdicts\n');
    for vn = 1:numel(f6Status.Properties.VariableNames)
        col = f6Status.Properties.VariableNames{vn};
        val = f6Status{1, vn};
        if isnumeric(val)
            fprintf(fidReport, '- %s = %g\n', col, val);
        else
            fprintf(fidReport, '- %s = %s\n', col, string(val));
        end
    end
    fclose(fidReport);

    fidRunReport = fopen(fullfile(runReportsDir, 'aging_F6_AFM_FM_tau_comparison.md'), 'w');
    if fidRunReport >= 0
        fidSrc = fopen(reportPath, 'r');
        if fidSrc >= 0
            while ~feof(fidSrc)
                lineText = fgetl(fidSrc);
                if ischar(lineText)
                    fprintf(fidRunReport, '%s\n', lineText);
                end
            end
            fclose(fidSrc);
        end
        fclose(fidRunReport);
    end

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nRows, ...
        {'F6 AFM/FM tau comparison completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_F6_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'F6 comparison failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
