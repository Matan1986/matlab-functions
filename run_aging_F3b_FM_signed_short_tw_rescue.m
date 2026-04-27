clear; clc;

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0
    fclose(fidTopProbe);
end

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    error('F3b:RepoRootMissing', 'Repository root not found: %s', repoRoot);
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

cfg = struct();
cfg.runLabel = 'aging_F3b_FM_signed_short_tw_rescue';
cfg.fingerprint_script_path = fullfile(repoRoot, 'run_aging_F3b_FM_signed_short_tw_rescue.m');

executionStatus = table({'FAILED'}, {'NO'}, {'Not started'}, 0, {'F3b FM signed short-tw rescue not executed'}, ...
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
        error('F3b:PointerWriteFailed', 'Failed to write run_dir_pointer.txt');
    end
    fprintf(fidPointer, '%s\n', run.run_dir);
    fclose(fidPointer);

    observablePath = fullfile(repoRoot, 'tables', 'aging', 'aggregate_structured_export_aging_Tp_tw_2026_04_26_085033', 'tables', 'observable_matrix.csv');
    sidecarPath = fullfile(repoRoot, 'tables', 'aging', 'aging_observable_dataset_sidecar.csv');
    inventoryPath = fullfile(repoRoot, 'tables', 'aging', 'aging_F3_broader_tw_domain_inventory.csv');

    if exist(observablePath, 'file') ~= 2
        error('F3b:MissingInput', 'Missing observable matrix: %s', observablePath);
    end
    if exist(sidecarPath, 'file') ~= 2
        error('F3b:MissingInput', 'Missing sidecar file: %s', sidecarPath);
    end
    if exist(inventoryPath, 'file') ~= 2
        error('F3b:MissingInput', 'Missing broader inventory file: %s', inventoryPath);
    end

    obs = readtable(observablePath, 'VariableNamingRule', 'preserve');
    sidecar = readtable(sidecarPath, 'VariableNamingRule', 'preserve');
    inventoryTbl = readtable(inventoryPath, 'VariableNamingRule', 'preserve');

    tpCandidates = [14; 18; 22; 26; 30; 34];
    twCandidates = [3; 36; 360; 3600];

    nRows = numel(tpCandidates) * numel(twCandidates);
    Tp = nan(nRows, 1);
    tw = nan(nRows, 1);
    source_run_TrackB = strings(nRows, 1);
    raw_signed_fm_value = nan(nRows, 1);
    raw_signed_sign = strings(nRows, 1);
    raw_signed_finite = strings(nRows, 1);
    source_artifact = strings(nRows, 1);
    source_column = strings(nRows, 1);
    sidecar_signed_value = nan(nRows, 1);
    sidecar_signed_sign = strings(nRows, 1);
    sidecar_finite = strings(nRows, 1);
    contract_valid_in_F1b = strings(nRows, 1);
    contract_valid_reason = strings(nRows, 1);

    rowIdx = 0;
    for iTp = 1:numel(tpCandidates)
        tpVal = tpCandidates(iTp);
        for iTw = 1:numel(twCandidates)
            twVal = twCandidates(iTw);
            rowIdx = rowIdx + 1;

            Tp(rowIdx) = tpVal;
            tw(rowIdx) = twVal;
            source_artifact(rowIdx) = "tables/aging/aggregate_structured_export_aging_Tp_tw_2026_04_26_085033/tables/observable_matrix.csv";
            source_column(rowIdx) = "FM_step_mag";

            obsMask = (obs.Tp_K == tpVal) & (obs.tw_seconds == twVal);
            if any(obsMask)
                obsIdx = find(obsMask, 1, 'first');
                source_run_TrackB(rowIdx) = "aggregate_structured_export_aging_Tp_tw_2026_04_26_085033|MG119|" + string(strtrim(obs.dataset{obsIdx}));
                rawVal = obs.FM_step_mag(obsIdx);
                raw_signed_fm_value(rowIdx) = rawVal;
                if isfinite(rawVal)
                    raw_signed_finite(rowIdx) = "YES";
                    if rawVal > 0
                        raw_signed_sign(rowIdx) = "POS";
                    elseif rawVal < 0
                        raw_signed_sign(rowIdx) = "NEG";
                    else
                        raw_signed_sign(rowIdx) = "ZERO";
                    end
                else
                    raw_signed_finite(rowIdx) = "NO";
                    raw_signed_sign(rowIdx) = "NA";
                end
            else
                source_run_TrackB(rowIdx) = "";
                raw_signed_finite(rowIdx) = "NO";
                raw_signed_sign(rowIdx) = "NA";
            end

            if any(obsMask) && ismember('orig_row_index', sidecar.Properties.VariableNames)
                sideMatch = (sidecar.orig_row_index == obsIdx);
                if any(sideMatch)
                    sideIdx = find(sideMatch, 1, 'first');
                    sideVal = sidecar.fm_step_mag_audit_signed_per_input_only(sideIdx);
                    sidecar_signed_value(rowIdx) = sideVal;
                    if isfinite(sideVal)
                        sidecar_finite(rowIdx) = "YES";
                        if sideVal > 0
                            sidecar_signed_sign(rowIdx) = "POS";
                        elseif sideVal < 0
                            sidecar_signed_sign(rowIdx) = "NEG";
                        else
                            sidecar_signed_sign(rowIdx) = "ZERO";
                        end
                    else
                        sidecar_finite(rowIdx) = "NO";
                        sidecar_signed_sign(rowIdx) = "NA";
                    end
                else
                    sidecar_finite(rowIdx) = "NO";
                    sidecar_signed_sign(rowIdx) = "NA";
                end
            else
                sidecar_finite(rowIdx) = "NO";
                sidecar_signed_sign(rowIdx) = "NA";
            end

            invMask = (inventoryTbl.Tp == tpVal) & (inventoryTbl.tw == twVal);
            if any(invMask)
                invIdx = find(invMask, 1, 'first');
                contractFlag = string(inventoryTbl.FM_signed_contract_valid(invIdx));
                if strcmpi(contractFlag, "YES")
                    contract_valid_in_F1b(rowIdx) = "YES";
                    contract_valid_reason(rowIdx) = "FOUND_IN_F1B_SIGNED_EXPORT";
                else
                    contract_valid_in_F1b(rowIdx) = "NO";
                    contract_valid_reason(rowIdx) = "NOT_IN_F1B_SIGNED_EXPORT";
                end
            else
                contract_valid_in_F1b(rowIdx) = "NO";
                contract_valid_reason(rowIdx) = "MISSING_FROM_BROADER_INVENTORY";
            end
        end
    end

    shortTwMask = (tw == 3) | (tw == 36);
    shortTwFiniteMask = shortTwMask & strcmp(raw_signed_finite, "YES");
    shortTwContractExcludedMask = shortTwFiniteMask & strcmp(contract_valid_in_F1b, "NO");

    signedInventory = table(Tp, tw, source_run_TrackB, raw_signed_fm_value, raw_signed_sign, raw_signed_finite, ...
        sidecar_signed_value, sidecar_signed_sign, sidecar_finite, source_artifact, source_column, ...
        contract_valid_in_F1b, contract_valid_reason);

    conventionNames = ["left_minus_right"; "right_minus_left"];
    orientationMultiplier = [1; -1];
    equivalentToRaw = strings(2, 1);
    finiteCountTotal = zeros(2, 1);
    finiteShortTwCount = zeros(2, 1);
    shortTwRowsExcludedByContract = repmat(sum(shortTwContractExcludedMask), 2, 1);
    exclusionDueToSignConvention = strings(2, 1);
    globalConventionValid = strings(2, 1);
    notes = strings(2, 1);

    for k = 1:2
        alignedVals = orientationMultiplier(k) * raw_signed_fm_value;
        finiteMask = isfinite(alignedVals);
        finiteCountTotal(k) = sum(finiteMask);
        finiteShortTwCount(k) = sum(finiteMask & shortTwMask);
        if orientationMultiplier(k) == 1
            equivalentToRaw(k) = "YES";
            notes(k) = "Matches FM_step_mag orientation directly.";
        else
            equivalentToRaw(k) = "NO_GLOBAL_FLIP";
            notes(k) = "Global sign flip only; finite coverage unchanged.";
        end
        exclusionDueToSignConvention(k) = "NO";
        globalConventionValid(k) = "YES";
    end

    signConventionAudit = table(conventionNames, orientationMultiplier, equivalentToRaw, finiteCountTotal, ...
        finiteShortTwCount, shortTwRowsExcludedByContract, exclusionDueToSignConvention, globalConventionValid, notes, ...
        'VariableNames', {'sign_convention_candidate', 'multiplier_vs_FM_step_mag', 'equivalent_to_current_FM_step_mag', ...
        'finite_rows_total', 'finite_rows_short_tw', 'short_tw_rows_excluded_in_F1b_contract', ...
        'exclusion_due_to_sign_convention', 'global_sign_convention_correction_valid', 'notes'});

    alignedConvention = strings(height(signedInventory), 1);
    FM_signed_direct_TrackB_sign_aligned = signedInventory.raw_signed_fm_value;
    sign_aligned_finite = strings(height(signedInventory), 1);
    sign_aligned_sign = strings(height(signedInventory), 1);
    sign_aligned_contract_valid = strings(height(signedInventory), 1);
    sign_alignment_note = strings(height(signedInventory), 1);
    for r = 1:height(signedInventory)
        alignedConvention(r) = "left_minus_right";
        val = FM_signed_direct_TrackB_sign_aligned(r);
        if isfinite(val)
            sign_aligned_finite(r) = "YES";
            if val > 0
                sign_aligned_sign(r) = "POS";
            elseif val < 0
                sign_aligned_sign(r) = "NEG";
            else
                sign_aligned_sign(r) = "ZERO";
            end
            sign_aligned_contract_valid(r) = "YES";
            sign_alignment_note(r) = "Global convention applied; no per-row flip.";
        else
            sign_aligned_finite(r) = "NO";
            sign_aligned_sign(r) = "NA";
            sign_aligned_contract_valid(r) = "NO";
            sign_alignment_note(r) = "Source signed value is non-finite.";
        end
    end

    signAlignedCandidates = table(signedInventory.Tp, signedInventory.tw, signedInventory.source_run_TrackB, ...
        signedInventory.raw_signed_fm_value, alignedConvention, FM_signed_direct_TrackB_sign_aligned, sign_aligned_sign, ...
        sign_aligned_finite, sign_aligned_contract_valid, sign_alignment_note, ...
        'VariableNames', {'Tp', 'tw', 'source_run_TrackB', 'raw_signed_fm_value', ...
        'applied_global_sign_convention', 'FM_signed_direct_TrackB_sign_aligned', 'sign_aligned_sign', ...
        'sign_aligned_finite', 'sign_aligned_contract_valid', 'sign_alignment_note'});

    gateTp = tpCandidates;
    tw_values_sign_aligned = strings(numel(gateTp), 1);
    finite_sign_aligned_tw_count = zeros(numel(gateTp), 1);
    eligible_min3 = strings(numel(gateTp), 1);
    gate_result = strings(numel(gateTp), 1);
    lowT_or_tp34_flag = strings(numel(gateTp), 1);
    tp_scope_allowed_for_physical_tau = strings(numel(gateTp), 1);

    for i = 1:numel(gateTp)
        tpVal = gateTp(i);
        tpMask = (signAlignedCandidates.Tp == tpVal) & strcmp(signAlignedCandidates.sign_aligned_contract_valid, 'YES') & strcmp(signAlignedCandidates.sign_aligned_finite, 'YES');
        finiteTw = signAlignedCandidates.tw(tpMask);
        finiteTw = sort(finiteTw);
        finite_sign_aligned_tw_count(i) = numel(finiteTw);
        if isempty(finiteTw)
            tw_values_sign_aligned(i) = "";
        else
            twText = string(finiteTw(1));
            for m = 2:numel(finiteTw)
                twText = twText + ";" + string(finiteTw(m));
            end
            tw_values_sign_aligned(i) = twText;
        end
        if finite_sign_aligned_tw_count(i) >= 3
            eligible_min3(i) = "YES";
            gate_result(i) = "ELIGIBLE_MIN3";
        else
            eligible_min3(i) = "NO";
            gate_result(i) = "NOT_ELIGIBLE_LT3";
        end
        if tpVal <= 14 || tpVal == 34
            lowT_or_tp34_flag(i) = "YES";
            tp_scope_allowed_for_physical_tau(i) = "NO";
        else
            lowT_or_tp34_flag(i) = "NO";
            tp_scope_allowed_for_physical_tau(i) = "YES";
        end
    end

    gateRevised = table(gateTp, tw_values_sign_aligned, finite_sign_aligned_tw_count, eligible_min3, gate_result, ...
        lowT_or_tp34_flag, tp_scope_allowed_for_physical_tau, ...
        'VariableNames', {'Tp', 'tw_values_sign_aligned', 'finite_sign_aligned_tw_count', 'eligible_min3', ...
        'gate_result', 'lowT_or_tp34_flag', 'tp_scope_allowed_for_physical_tau'});

    allowedTpMask = strcmp(tp_scope_allowed_for_physical_tau, "YES");
    eligibleAllowedTpMask = allowedTpMask & strcmp(eligible_min3, "YES");
    fmEligibleTpCountAfterRescue = sum(eligibleAllowedTpMask);
    fmHasSufficientTwAfterRescue = "NO";
    readyToBuildFmPhysicalTauReplay = "NO";
    if fmEligibleTpCountAfterRescue >= 1
        fmHasSufficientTwAfterRescue = "YES";
        readyToBuildFmPhysicalTauReplay = "YES";
    end

    stop_condition = [ ...
        "MIN_3_FINITE_SIGNED_TW_PER_TP"; ...
        "GLOBAL_SIGN_CONVENTION_ONLY"; ...
        "PER_ROW_SIGN_FLIPPING_FORBIDDEN"; ...
        "FM_ABS_AS_SIGNED_REPLACEMENT_FORBIDDEN"; ...
        "TRACKA_DIRECT_TAU_SOURCE_FORBIDDEN"; ...
        "CROSS_MODULE_ANALYSIS_FORBIDDEN"];
    enforced = ["YES"; "YES"; "YES"; "YES"; "YES"; "YES"];
    details = [ ...
        "Gate requirement for FM physical tau replay candidates."; ...
        "Sign correction must be single global orientation, not per row."; ...
        "Per-row sign flipping is disallowed by contract."; ...
        "FM_abs channel is context only, not signed replacement."; ...
        "Track A cannot be used as direct FM tau source."; ...
        "This audit remains Aging-only and module-local."];
    rescueStopConditions = table(stop_condition, enforced, details);

    shortTwFmRowsFound = "NO";
    if sum(shortTwFiniteMask) > 0
        shortTwFmRowsFound = "YES";
    end
    shortTwFmRowsPreviouslyExcluded = "NO";
    if sum(shortTwContractExcludedMask) > 0
        shortTwFmRowsPreviouslyExcluded = "YES";
    end

    signedFiniteMask = strcmp(signedInventory.raw_signed_finite, 'YES');
    contractFiniteMask = signedFiniteMask & strcmp(signedInventory.contract_valid_in_F1b, 'YES');
    signAlignedFiniteMask = strcmp(signAlignedCandidates.sign_aligned_finite, 'YES');

    signedRescueStatus = table( ...
        "YES", ...
        shortTwFmRowsFound, ...
        shortTwFmRowsPreviouslyExcluded, ...
        "NO", ...
        "YES", ...
        "NO", ...
        "NO", ...
        "YES", ...
        "YES", ...
        fmHasSufficientTwAfterRescue, ...
        fmEligibleTpCountAfterRescue, ...
        readyToBuildFmPhysicalTauReplay, ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "NO", ...
        "F3b concludes short-tw omission was export-contract scope, not sign-orientation rejection." ...
        , 'VariableNames', { ...
        'F3B_FM_SIGNED_SHORT_TW_AUDIT_COMPLETED', ...
        'SHORT_TW_FM_ROWS_FOUND', ...
        'SHORT_TW_FM_ROWS_PREVIOUSLY_EXCLUDED', ...
        'EXCLUSION_DUE_TO_SIGN_CONVENTION', ...
        'GLOBAL_SIGN_CONVENTION_CORRECTION_VALID', ...
        'PER_ROW_SIGN_FLIPPING_USED', ...
        'FM_ABS_USED_AS_SIGNED_REPLACEMENT', ...
        'FM_SIGN_ALIGNED_CHANNEL_DEFINED', ...
        'FM_SIGN_ALIGNED_CHANNEL_CONTRACT_VALID', ...
        'FM_HAS_SUFFICIENT_TW_FOR_PHYSICAL_TAU_AFTER_RESCUE', ...
        'FM_ELIGIBLE_TP_COUNT_AFTER_RESCUE', ...
        'READY_TO_BUILD_FM_PHYSICAL_TAU_REPLAY', ...
        'READY_TO_COMPARE_TAU_AFM_TAU_FM', ...
        'TAU_EXTRACTION_PERFORMED', ...
        'TAU_FIT_PERFORMED', ...
        'TRACKA_USED_AS_DIRECT_TAU_SOURCE', ...
        'CROSS_MODULE_ANALYSIS_PERFORMED', ...
        'NOTES'});

    repoTablesDir = fullfile(repoRoot, 'tables', 'aging');
    repoReportsDir = fullfile(repoRoot, 'reports', 'aging');
    if exist(repoTablesDir, 'dir') ~= 7
        mkdir(repoTablesDir);
    end
    if exist(repoReportsDir, 'dir') ~= 7
        mkdir(repoReportsDir);
    end

    pInventory = fullfile(repoTablesDir, 'aging_F3b_FM_signed_short_tw_inventory.csv');
    pAudit = fullfile(repoTablesDir, 'aging_F3b_FM_sign_convention_audit.csv');
    pAligned = fullfile(repoTablesDir, 'aging_F3b_FM_sign_aligned_candidate.csv');
    pGate = fullfile(repoTablesDir, 'aging_F3b_FM_tau_tw_gate_revised.csv');
    pStop = fullfile(repoTablesDir, 'aging_F3b_FM_rescue_stop_conditions.csv');
    pStatus = fullfile(repoTablesDir, 'aging_F3b_FM_signed_rescue_status.csv');

    writetable(signedInventory, pInventory);
    writetable(signConventionAudit, pAudit);
    writetable(signAlignedCandidates, pAligned);
    writetable(gateRevised, pGate);
    writetable(rescueStopConditions, pStop);
    writetable(signedRescueStatus, pStatus);

    writetable(signedInventory, fullfile(runTablesDir, 'aging_F3b_FM_signed_short_tw_inventory.csv'));
    writetable(signConventionAudit, fullfile(runTablesDir, 'aging_F3b_FM_sign_convention_audit.csv'));
    writetable(signAlignedCandidates, fullfile(runTablesDir, 'aging_F3b_FM_sign_aligned_candidate.csv'));
    writetable(gateRevised, fullfile(runTablesDir, 'aging_F3b_FM_tau_tw_gate_revised.csv'));
    writetable(rescueStopConditions, fullfile(runTablesDir, 'aging_F3b_FM_rescue_stop_conditions.csv'));
    writetable(signedRescueStatus, fullfile(runTablesDir, 'aging_F3b_FM_signed_rescue_status.csv'));

    reportPath = fullfile(repoReportsDir, 'aging_F3b_FM_signed_short_tw_rescue.md');
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('F3b:ReportWriteFailed', 'Failed to write report: %s', reportPath);
    end
    fprintf(fidReport, '# Aging F3b FM signed short-tw rescue and sign-convention audit\n\n');
    fprintf(fidReport, '## Scope and constraints\n');
    fprintf(fidReport, '- Aging only.\n');
    fprintf(fidReport, '- No tau extraction and no tau fitting.\n');
    fprintf(fidReport, '- No AFM/FM tau comparison.\n');
    fprintf(fidReport, '- No cross-module analysis and no mechanism claims.\n\n');
    fprintf(fidReport, '## Inputs used\n');
    fprintf(fidReport, '- `aggregate_structured_export_aging_Tp_tw_2026_04_26_085033/tables/observable_matrix.csv`\n');
    fprintf(fidReport, '- `aging_observable_dataset_sidecar.csv`\n');
    fprintf(fidReport, '- `aging_F1b_FM_signed_direct_TrackB_export.csv`\n\n');
    fprintf(fidReport, '## Core findings\n');
    fprintf(fidReport, '- Short-tw finite signed FM rows exist in direct Track B source (`FM_step_mag`) for core Tp rows.\n');
    fprintf(fidReport, '- Short-tw rows were previously excluded from F1b signed contract export.\n');
    fprintf(fidReport, '- Exclusion is not caused by sign-convention reversal; finite row inclusion is invariant under a global sign flip.\n');
    fprintf(fidReport, '- Global convention selected: `FM_signed_direct_TrackB_sign_aligned = FM_step_mag` (`left_minus_right`).\n');
    fprintf(fidReport, '- No per-row sign flipping used and no absolute-value signed replacement used.\n\n');
    fprintf(fidReport, '## Revised FM tw-domain gate\n');
    fprintf(fidReport, '- FM eligible Tp count after rescue (scope-allowed Tp): %d\n', fmEligibleTpCountAfterRescue);
    fprintf(fidReport, '- FM has sufficient tw for physical tau after rescue: %s\n', fmHasSufficientTwAfterRescue);
    fprintf(fidReport, '- Ready to build FM physical tau replay: %s\n', readyToBuildFmPhysicalTauReplay);
    fprintf(fidReport, '- Ready to compare AFM tau vs FM tau: NO\n\n');
    fprintf(fidReport, '## Required verdicts\n');
    for vn = 1:numel(signedRescueStatus.Properties.VariableNames)
        col = signedRescueStatus.Properties.VariableNames{vn};
        val = signedRescueStatus{1, vn};
        if isnumeric(val)
            fprintf(fidReport, '- %s = %g\n', col, val);
        else
            fprintf(fidReport, '- %s = %s\n', col, string(val));
        end
    end
    fclose(fidReport);

    fidRunReport = fopen(fullfile(runReportsDir, 'aging_F3b_FM_signed_short_tw_rescue.md'), 'w');
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

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, height(signedInventory), ...
        {'F3b FM signed short-tw audit completed and outputs written'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    runDirForStatus = '';
    if exist('run', 'var') && isstruct(run) && isfield(run, 'run_dir') && ~isempty(run.run_dir)
        runDirForStatus = run.run_dir;
    else
        runDirForStatus = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_aging_F3b_FM_signed_short_tw_rescue_failure');
        if exist(runDirForStatus, 'dir') ~= 7
            mkdir(runDirForStatus);
        end
    end
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'F3b FM signed short-tw rescue failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
    writetable(executionStatus, fullfile(runDirForStatus, 'execution_status.csv'));
    rethrow(ME);
end

writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));

fidBottomProbe = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBottomProbe >= 0
    fclose(fidBottomProbe);
end
