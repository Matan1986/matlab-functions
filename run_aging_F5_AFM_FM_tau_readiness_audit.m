clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F5:RepoRootMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F5_AFM_FM_tau_readiness';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F5_AFM_FM_tau_readiness_audit.m');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, 0, {'F5 AFM/FM tau readiness audit not executed'}, ...
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
        error('F5:PointerWriteFailed', 'Failed to write run_dir_pointer.txt');
    end
    fprintf(fidPointer, '%s\n', run.run_dir);
    fclose(fidPointer);

    pAfmSel = fullfile(repoRoot, 'tables', 'aging', 'aging_F4A_AFM_tau_selected_values.csv');
    pAfmFail = fullfile(repoRoot, 'tables', 'aging', 'aging_F4A_AFM_tau_failure_reasons.csv');
    pAfmQ = fullfile(repoRoot, 'tables', 'aging', 'aging_F4A_AFM_tau_fit_quality.csv');
    pAfmSt = fullfile(repoRoot, 'tables', 'aging', 'aging_F4A_AFM_tau_status.csv');
    pFmSel = fullfile(repoRoot, 'tables', 'aging', 'aging_F4B_FM_tau_selected_values.csv');
    pFmFail = fullfile(repoRoot, 'tables', 'aging', 'aging_F4B_FM_tau_failure_reasons.csv');
    pFmQ = fullfile(repoRoot, 'tables', 'aging', 'aging_F4B_FM_tau_fit_quality.csv');
    pFmSt = fullfile(repoRoot, 'tables', 'aging', 'aging_F4B_FM_tau_status.csv');

    inputs = {pAfmSel, pAfmFail, pAfmQ, pAfmSt, pFmSel, pFmFail, pFmQ, pFmSt};
    for ii = 1:numel(inputs)
        if exist(inputs{ii}, 'file') ~= 2
            error('F5:MissingInput', 'Missing required input: %s', inputs{ii});
        end
    end

    afmSel = readtable(pAfmSel, 'VariableNamingRule', 'preserve');
    afmFail = readtable(pAfmFail, 'VariableNamingRule', 'preserve');
    afmQ = readtable(pAfmQ, 'VariableNamingRule', 'preserve');
    afmSt = readtable(pAfmSt, 'VariableNamingRule', 'preserve');
    fmSel = readtable(pFmSel, 'VariableNamingRule', 'preserve');
    fmFail = readtable(pFmFail, 'VariableNamingRule', 'preserve');
    fmQ = readtable(pFmQ, 'VariableNamingRule', 'preserve');
    fmSt = readtable(pFmSt, 'VariableNamingRule', 'preserve');

    f4aValid = false;
    if height(afmSt) >= 1
        c1 = string(afmSt.AFM_TAU_PHYSICAL_VALUES_SELECTED(1));
        c2 = string(afmSt.TAU_PROXY_AS_PHYSICAL_TAU_USED(1));
        c3 = string(afmSt.TRACKA_USED_AS_DIRECT_TAU_SOURCE(1));
        c4 = string(afmSt.CROSS_MODULE_ANALYSIS_PERFORMED(1));
        f4aValid = strcmpi(c1, 'YES') && strcmpi(c2, 'NO') && strcmpi(c3, 'NO') && strcmpi(c4, 'NO');
    end

    f4bValid = false;
    if height(fmSt) >= 1
        c1b = string(fmSt.FM_TAU_PHYSICAL_VALUES_SELECTED(1));
        c2b = string(fmSt.TAU_PROXY_AS_PHYSICAL_TAU_USED(1));
        c3b = string(fmSt.TRACKA_USED_AS_DIRECT_TAU_SOURCE(1));
        c4b = string(fmSt.CROSS_MODULE_ANALYSIS_PERFORMED(1));
        f4bValid = strcmpi(c1b, 'YES') && strcmpi(c2b, 'NO') && strcmpi(c3b, 'NO') && strcmpi(c4b, 'NO');
    end

    afmSelTp = unique(afmSel.Tp);
    afmFailTp = unique(afmFail.Tp);
    fmSelTp = unique(fmSel.Tp);
    fmFailTp = unique(fmFail.Tp);

    allTp = unique([afmSelTp; afmFailTp; fmSelTp; fmFailTp]);

    nInv = numel(allTp);
    afm_branch = strings(nInv, 1);
    fm_branch = strings(nInv, 1);
    tau_afm = nan(nInv, 1);
    tau_fm = nan(nInv, 1);
    afm_quality_pass = strings(nInv, 1);
    afm_r2 = nan(nInv, 1);
    fm_quality_pass = strings(nInv, 1);
    fm_r2 = nan(nInv, 1);
    shared_status = strings(nInv, 1);

    for i = 1:nInv
        tp = allTp(i);
        if any(afmSelTp == tp)
            afm_branch(i) = "SELECTED";
            rowS = afmSel(afmSel.Tp == tp, :);
            tau_afm(i) = rowS.tau_AFM_physical_canon_replay(1);
        elseif any(afmFailTp == tp)
            afm_branch(i) = "FAILED";
        else
            afm_branch(i) = "MISSING";
        end

        if any(fmSelTp == tp)
            fm_branch(i) = "SELECTED";
            rowF = fmSel(fmSel.Tp == tp, :);
            tau_fm(i) = rowF.tau_FM_physical_canon_replay(1);
        elseif any(fmFailTp == tp)
            fm_branch(i) = "FAILED";
        else
            fm_branch(i) = "MISSING";
        end

        afm_quality_pass(i) = "NA";
        maskA = afmQ.Tp == tp;
        if any(maskA)
            idxa = find(maskA, 1);
            afm_quality_pass(i) = string(afmQ.quality_pass(idxa));
            afm_r2(i) = afmQ.r2_primary(idxa);
        end

        fm_quality_pass(i) = "NA";
        maskF = fmQ.Tp == tp;
        if any(maskF)
            idxf = find(maskF, 1);
            fm_quality_pass(i) = string(fmQ.quality_pass(idxf));
            fm_r2(i) = fmQ.r2_primary(idxf);
        end

        if afm_branch(i) == "SELECTED" && fm_branch(i) == "SELECTED"
            shared_status(i) = "BOTH_SELECTED";
        elseif afm_branch(i) == "SELECTED" && fm_branch(i) ~= "SELECTED"
            shared_status(i) = "AFM_ONLY_NO_FM_PHYSICAL";
        elseif fm_branch(i) == "SELECTED" && afm_branch(i) ~= "SELECTED"
            shared_status(i) = "FM_ONLY_NO_AFM_PHYSICAL";
        elseif afm_branch(i) == "FAILED" && fm_branch(i) == "FAILED"
            shared_status(i) = "BOTH_FAILED";
        elseif afm_branch(i) == "FAILED"
            shared_status(i) = "AFM_FAILED";
        elseif fm_branch(i) == "FAILED"
            shared_status(i) = "FM_FAILED";
        else
            shared_status(i) = "NOT_COMPARABLE";
        end
    end

    inventory = table(allTp, afm_branch, fm_branch, tau_afm, tau_fm, ...
        afm_quality_pass, afm_r2, fm_quality_pass, fm_r2, shared_status, ...
        'VariableNames', {'Tp', 'AFM_branch', 'FM_branch', 'tau_AFM_physical_canon_replay', ...
        'tau_FM_physical_canon_replay', 'AFM_fit_quality_pass', 'AFM_r2_primary', ...
        'FM_fit_quality_pass', 'FM_r2_primary', 'shared_selected_status'});

    sharedMask = shared_status == "BOTH_SELECTED";
    sharedTp = allTp(sharedMask);
    sharedCount = sum(sharedMask);

    sharedTbl = table();
    if sharedCount > 0
        tauAfmCol = tau_afm(sharedMask);
        tauFmCol = tau_fm(sharedMask);
        afmR2Col = afm_r2(sharedMask);
        fmR2Col = fm_r2(sharedMask);
        sharedTbl = table(sharedTp, tauAfmCol, tauFmCol, afmR2Col, fmR2Col, ...
            repmat("SHARED_PHYSICAL_TAU_DOMAIN", sharedCount, 1), ...
            'VariableNames', {'Tp', 'tau_AFM_physical_canon_replay', 'tau_FM_physical_canon_replay', ...
            'AFM_r2_primary', 'FM_r2_primary', 'comparison_domain_note'});
    end

    emptyShared = table([], [], [], [], [], [], ...
        'VariableNames', {'Tp', 'tau_AFM_physical_canon_replay', 'tau_FM_physical_canon_replay', ...
        'AFM_r2_primary', 'FM_r2_primary', 'comparison_domain_note'});

    tpExc = zeros(nInv, 1);
    reasonExc = strings(nInv, 1);
    detailExc = strings(nInv, 1);
    for ix = 1:nInv
        tpExc(ix) = allTp(ix);
        if shared_status(ix) == "BOTH_SELECTED"
            reasonExc(ix) = "IN_SHARED_DOMAIN";
            detailExc(ix) = "Both AFM and FM physical tau selected; eligible for constrained comparison.";
        elseif shared_status(ix) == "AFM_ONLY_NO_FM_PHYSICAL"
            reasonExc(ix) = "EXCLUDED_FROM_PAIRWISE";
            detailExc(ix) = "AFM physical tau present; FM branch missing or no FM physical tau for this Tp.";
        elseif shared_status(ix) == "FM_ONLY_NO_AFM_PHYSICAL"
            reasonExc(ix) = "EXCLUDED_FROM_PAIRWISE";
            detailExc(ix) = "FM physical tau present; AFM branch missing or no AFM physical tau for this Tp.";
        elseif shared_status(ix) == "BOTH_FAILED"
            reasonExc(ix) = "EXCLUDED_BOTH_FAILED";
            detailExc(ix) = "Neither channel produced physical tau at this Tp per F4A/F4B failure tables.";
        elseif shared_status(ix) == "AFM_FAILED" || shared_status(ix) == "FM_FAILED"
            reasonExc(ix) = "EXCLUDED_ONE_BRANCH_FAILED";
            detailExc(ix) = "One branch failed fit quality; see F4A/F4B failure reasons.";
        else
            reasonExc(ix) = "EXCLUDED_NOT_COMPARABLE";
            detailExc(ix) = "Cannot form AFM/FM pair at this Tp.";
        end
    end
    exclusions = table(tpExc, reasonExc, detailExc, 'VariableNames', {'Tp', 'exclusion_category', 'exclusion_detail'});

    claim_level_col = ["LEVEL_0"; "LEVEL_1"; "LEVEL_2"; "LEVEL_3"; "LEVEL_4"];
    definition_col = [ ...
        "Bookkeeping inventory of which Tp have AFM/FM physical tau."; ...
        "Descriptive side-by-side listing on shared Tp only."; ...
        "Quantitative within-Aging comparison on shared selected Tp only; no mechanism claim."; ...
        "Mechanism-supporting Aging claim not authorized by F5."; ...
        "Cross-module mechanism claim not authorized."];
    claimBoundary = table(claim_level_col, definition_col, ...
        'VariableNames', {'claim_level', 'definition'});

    comparisonAllowed = "PARTIAL";
    if sharedCount == 0
        comparisonAllowed = "NO";
    end

    maxClaim = "LEVEL_2";

    readyNext = "YES";
    if ~f4aValid || ~f4bValid || sharedCount == 0
        readyNext = "NO";
    end

    f4aStr = "NO";
    if f4aValid
        f4aStr = "YES";
    end
    f4bStr = "NO";
    if f4bValid
        f4bStr = "YES";
    end

    readinessStatus = table( ...
        "YES", ...
        f4aStr, ...
        f4bStr, ...
        "YES", ...
        "YES", ...
        sharedCount, ...
        comparisonAllowed, ...
        maxClaim, ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        readyNext ...
        , 'VariableNames', { ...
        'F5_AFM_FM_TAU_READINESS_AUDIT_COMPLETED', ...
        'F4A_STATUS_VALID', ...
        'F4B_STATUS_VALID', ...
        'AFM_PHYSICAL_TAU_AVAILABLE', ...
        'FM_PHYSICAL_TAU_AVAILABLE', ...
        'SHARED_SELECTED_TP_COUNT', ...
        'AFM_FM_TAU_COMPARISON_ALLOWED', ...
        'MAX_ALLOWED_CLAIM_LEVEL', ...
        'TAU_PROXY_AS_PHYSICAL_TAU_USED', ...
        'TRACKA_USED_AS_DIRECT_TAU_SOURCE', ...
        'CROSS_MODULE_ANALYSIS_PERFORMED', ...
        'MECHANISM_VALIDATION_PERFORMED', ...
        'GLOBAL_AGING_MECHANISM_CLAIMED', ...
        'READY_FOR_NEXT_COMPARISON_STEP'});

    repoTablesDir = fullfile(repoRoot, 'tables', 'aging');
    repoReportsDir = fullfile(repoRoot, 'reports', 'aging');
    if exist(repoTablesDir, 'dir') ~= 7
        mkdir(repoTablesDir);
    end
    if exist(repoReportsDir, 'dir') ~= 7
        mkdir(repoReportsDir);
    end

    pInv = fullfile(repoTablesDir, 'aging_F5_AFM_FM_tau_domain_inventory.csv');
    pShared = fullfile(repoTablesDir, 'aging_F5_AFM_FM_tau_shared_domain.csv');
    pExc = fullfile(repoTablesDir, 'aging_F5_AFM_FM_tau_exclusion_reasons.csv');
    pClaim = fullfile(repoTablesDir, 'aging_F5_AFM_FM_tau_claim_boundary.csv');
    pRead = fullfile(repoTablesDir, 'aging_F5_AFM_FM_tau_readiness_status.csv');

    writetable(inventory, pInv);
    if sharedCount > 0
        writetable(sharedTbl, pShared);
    else
        writetable(emptyShared, pShared);
    end
    writetable(exclusions, pExc);
    writetable(claimBoundary, pClaim);
    writetable(readinessStatus, pRead);

    writetable(inventory, fullfile(runTablesDir, 'aging_F5_AFM_FM_tau_domain_inventory.csv'));
    if sharedCount > 0
        writetable(sharedTbl, fullfile(runTablesDir, 'aging_F5_AFM_FM_tau_shared_domain.csv'));
    else
        writetable(emptyShared, fullfile(runTablesDir, 'aging_F5_AFM_FM_tau_shared_domain.csv'));
    end
    writetable(exclusions, fullfile(runTablesDir, 'aging_F5_AFM_FM_tau_exclusion_reasons.csv'));
    writetable(claimBoundary, fullfile(runTablesDir, 'aging_F5_AFM_FM_tau_claim_boundary.csv'));
    writetable(readinessStatus, fullfile(runTablesDir, 'aging_F5_AFM_FM_tau_readiness_status.csv'));

    reportPath = fullfile(repoReportsDir, 'aging_F5_AFM_FM_tau_comparison_readiness.md');
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('F5:ReportWriteFailed', 'Failed to write report: %s', reportPath);
    end
    fprintf(fidReport, '# Aging F5 AFM/FM physical tau comparison readiness audit\n\n');
    fprintf(fidReport, '## Scope\n');
    fprintf(fidReport, '- Readiness and domain audit only.\n');
    fprintf(fidReport, '- No mechanism validation and no global Aging mechanism claims.\n');
    fprintf(fidReport, '- No Switching, Relaxation, or MT comparison.\n\n');
    fprintf(fidReport, '## F4A/F4B status checks\n');
    fprintf(fidReport, '- F4A_STATUS_VALID = %s\n', char(f4aStr));
    fprintf(fidReport, '- F4B_STATUS_VALID = %s\n', char(f4bStr));
    fprintf(fidReport, '- Proxy-as-physical and Track A direct use: asserted NO per F4A/F4B status tables.\n\n');
    fprintf(fidReport, '## Shared comparison domain\n');
    fprintf(fidReport, '- SHARED_SELECTED_TP_COUNT = %d\n', sharedCount);
    fprintf(fidReport, '- Shared Tp values: ');
    if sharedCount > 0
        for k = 1:numel(sharedTp)
            if k > 1
                fprintf(fidReport, ', ');
            end
            fprintf(fidReport, '%g', sharedTp(k));
        end
        fprintf(fidReport, '\n');
    else
        fprintf(fidReport, '(none)\n');
    end
    fprintf(fidReport, '- AFM_FM_TAU_COMPARISON_ALLOWED = %s\n', comparisonAllowed);
    fprintf(fidReport, '- MAX_ALLOWED_CLAIM_LEVEL = %s (within-Aging only on shared Tp; not mechanism)\n\n', maxClaim);
    fprintf(fidReport, '## Required verdicts\n');
    for vn = 1:numel(readinessStatus.Properties.VariableNames)
        col = readinessStatus.Properties.VariableNames{vn};
        val = readinessStatus{1, vn};
        if isnumeric(val)
            fprintf(fidReport, '- %s = %g\n', col, val);
        else
            fprintf(fidReport, '- %s = %s\n', col, string(val));
        end
    end
    fclose(fidReport);

    fidRunReport = fopen(fullfile(runReportsDir, 'aging_F5_AFM_FM_tau_comparison_readiness.md'), 'w');
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

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(inventory), ...
        {'F5 AFM/FM tau readiness audit completed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_F5_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'F5 readiness audit failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
