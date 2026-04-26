clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_tail_aware_backbone_pilot_design_review';

fCompleted = 'YES';
fPilotReady = 'PARTIAL';
fPilotCanonicalStatus = 'NON_CANONICAL_DIAGNOSTIC';
fReplacementNow = 'NO';
fPhi1Prevent = 'YES';
fPhi2Prevent = 'YES';
fCriteriaDefined = 'YES';
fContamChecksDefined = 'YES';
fReadyNoncanonicalPilot = 'PARTIAL';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'tail_aware_pilot_design_review';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'pilot design review initialized'}, false);

    pDesign = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_design_status.csv');
    pPilot = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_pilot_spec.csv');
    pCrit = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_replacement_criteria.csv');
    pEvidence = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_evidence_classification.csv');
    pIdentity = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    req = {pDesign, pPilot, pCrit, pEvidence, pIdentity};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_tail_aware_backbone_pilot_design_review:MissingInput', ...
                'Missing required input: %s', req{i});
        end
    end

    dMap = localReadStatusMap(pDesign);
    recCandidate = localGetMap(dMap, 'RECOMMENDED_BACKBONE_CANDIDATE');
    replaceNow = localGetMap(dMap, 'CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW');
    absorbPhi1 = localGetMap(dMap, 'RISK_OF_ABSORBING_PHI1');
    absorbPhi2 = localGetMap(dMap, 'RISK_OF_ABSORBING_PHI2');

    [pilotHdr, pilotRows] = localReadCsvRows(pPilot);
    iField = localIndex(pilotHdr, 'spec_field');
    iVal = localIndex(pilotHdr, 'spec_value');
    sf = lower(string(pilotRows(:, iField)));
    sv = string(pilotRows(:, iVal));
    pilotName = localLookup(sf, sv, 'pilot_name');
    pilotFamily = localLookup(sf, sv, 'candidate_family');
    pilotInputs = localLookup(sf, sv, 'inputs');
    pilotOutputs = localLookup(sf, sv, 'output_tables');
    pilotOpsForbidden = localLookup(sf, sv, 'forbidden_operations');
    pilotClass = localLookup(sf, sv, 'pilot_classification');
    pilotNcRule = localLookup(sf, sv, 'noncanonical_evidence_rule');
    pilotReplaceAction = localLookup(sf, sv, 'canonical_replacement_action');
    pilotPassCriteria = localLookup(sf, sv, 'pass_criteria');
    pilotFailCriteria = localLookup(sf, sv, 'fail_criteria');

    [critHdr, critRows] = localReadCsvRows(pCrit);
    iCrit = localIndex(critHdr, 'replacement_criterion');
    iLevel = localIndex(critHdr, 'required_level');
    critNames = lower(string(critRows(:, iCrit)));
    critLevels = lower(string(critRows(:, iLevel)));
    allStrict = all(critLevels == "strict_pass_required");
    hasPhi1Gate = any(contains(critNames, 'preserves_phi1')) && any(contains(critNames, 'does_not_absorb_phi1'));
    hasPhi2Gate = any(contains(critNames, 'phi2_interpretation'));
    hasRmseGuard = any(contains(critNames, 'not_rmse_only'));
    hasSpectrum = any(contains(critNames, 'residual_spectrum'));

    [evHdr, evRows] = localReadCsvRows(pEvidence);
    iPath = localIndex(evHdr, 'artifact_path_or_key');
    iCls = localIndex(evHdr, 'classification');
    evPaths = lower(string(evRows(:, iPath)));
    evCls = upper(string(evRows(:, iCls)));
    stressMask = contains(evPaths, 'stress');
    stressNoncanonical = all(evCls(stressMask) == "NONCANONICAL_DIAGNOSTIC");
    anyNoncanonicalInfluence = any(stressMask);

    % Allowed + forbidden operations + pass/fail + post-pilot contamination checks
    checkName = [ ...
        "confirm_candidate_name"; ...
        "confirm_candidate_family"; ...
        "confirm_inputs_declared"; ...
        "confirm_outputs_declared"; ...
        "confirm_inputs_classification"; ...
        "confirm_noncanonical_influence_declared"; ...
        "allowed_no_width_scaling"; ...
        "allowed_no_legacy_alignment"; ...
        "allowed_no_arbitrary_perT_shift_scale"; ...
        "allowed_no_phi2_fitted_component"; ...
        "allowed_no_canonical_replacement"; ...
        "allowed_no_claims_updates"; ...
        "forbidden_no_stress_as_truth_training"; ...
        "forbidden_no_rmse_only_optimization"; ...
        "forbidden_no_phi1_absorption"; ...
        "forbidden_no_phi2_absorption"; ...
        "forbidden_no_new_canonical_tables"; ...
        "forbidden_no_identity_changes"; ...
        "passfail_tail_burden_reduction"; ...
        "passfail_phi1_stability_preservation"; ...
        "passfail_no_phi1_coordinate_erasure"; ...
        "passfail_phi2_sensitivity_clarified"; ...
        "passfail_rmse_plus_non_rmse_guard"; ...
        "passfail_residual_spectrum_interpretable"; ...
        "passfail_metadata_audit_compatible"; ...
        "passfail_outputs_noncanonical_label"; ...
        "post_no_canonical_outputs_overwritten"; ...
        "post_no_identity_table_changes"; ...
        "post_no_root_summary_promotion"; ...
        "post_no_claim_context_snapshot_updates"; ...
        "post_all_pilot_artifacts_diagnostic"];
    checkStatus = repmat("DEFINED", numel(checkName), 1);
    checkDetail = [ ...
        sprintf("recommended=%s", recCandidate); ...
        sprintf("pilot_family=%s", pilotFamily); ...
        pilotInputs; ...
        pilotOutputs; ...
        "Inputs are canonical truth/diagnostic; stress influence is noncanonical diagnostic only."; ...
        sprintf("stress_noncanonical_only=%s; rule=%s", string(stressNoncanonical), pilotNcRule); ...
        "Explicitly required by B1 constraints and pilot forbidden_operations."; ...
        "Explicitly required by B1 constraints and pilot forbidden_operations."; ...
        "Explicitly required by B1 constraints and pilot forbidden_operations."; ...
        "Explicitly required by B1 constraints and pilot forbidden_operations."; ...
        sprintf("CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW=%s; %s", replaceNow, pilotReplaceAction); ...
        "No claims/context/snapshot/query updates allowed in this review."; ...
        "Stress outputs cannot be used as training truth; they are leads only."; ...
        "not_rmse_only_optimization criterion required strict pass."; ...
        sprintf("RISK_OF_ABSORBING_PHI1=%s and dedicated criteria present.", absorbPhi1); ...
        sprintf("RISK_OF_ABSORBING_PHI2=%s and dedicated criteria present.", absorbPhi2); ...
        "No writing new canonical S_long/phi/mode-amplitudes allowed."; ...
        "No changes to switching_canonical_identity.csv or CANONICAL_RUN_ID."; ...
        "Tail burden must decrease against reference."; ...
        "Phi1 shape/stability must be preserved under subset checks."; ...
        "Coordinate freedom must not erase Phi1."; ...
        "Phi2 tail sensitivity must improve or be clarified."; ...
        "RMSE may improve but cannot be sole win condition."; ...
        "Residual spectrum stability/interpretable structure required."; ...
        "Metadata-gated, replayable, auditable outputs required."; ...
        "Pilot artifacts must be marked NON_CANONICAL_DIAGNOSTIC."; ...
        "Post-run contamination check required."; ...
        "Post-run contamination check required."; ...
        "No promotion of pilot outputs into root canonical mirrors."; ...
        "No claims/context/snapshot/query updates."; ...
        "Pilot outputs must remain in diagnostic namespace with labels."];
    checksTbl = table(checkName, checkStatus, checkDetail, ...
        'VariableNames', {'review_check','status','review_detail'});
    switchingWriteTableBothPaths(checksTbl, repoRoot, runTables, 'switching_tail_aware_backbone_pilot_design_review_checks.csv');

    % Final flags
    fReplacementNow = 'NO';
    fPilotCanonicalStatus = 'NON_CANONICAL_DIAGNOSTIC';
    fPhi1Prevent = tern(hasPhi1Gate, 'YES', 'PARTIAL');
    fPhi2Prevent = tern(hasPhi2Gate, 'YES', 'PARTIAL');
    fCriteriaDefined = tern(allStrict && hasRmseGuard && hasSpectrum, 'YES', 'NO');
    fContamChecksDefined = tern(stressNoncanonical && anyNoncanonicalInfluence, 'YES', 'PARTIAL');
    if strcmp(fCriteriaDefined, 'YES') && strcmp(fContamChecksDefined, 'YES') && replaceNow == "NO" ...
            && contains(upper(recCandidate), 'TWO_SECTOR') && contains(upper(localGetDetailForCheck(pDesign,'RECOMMENDED_BACKBONE_CANDIDATE')), 'PILOT_ONLY')
        fPilotReady = 'PARTIAL';  % remains partial because B1 itself is accepted as PARTIAL design-spec
        fReadyNoncanonicalPilot = 'PARTIAL';
    else
        fPilotReady = 'NO';
        fReadyNoncanonicalPilot = 'NO';
    end

    statusTbl = table( ...
        ["PILOT_DESIGN_REVIEW_COMPLETED"; ...
         "PILOT_READY_FOR_IMPLEMENTATION"; ...
         "PILOT_CANONICAL_STATUS"; ...
         "CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW"; ...
         "PHI1_ABSORPTION_PREVENTION_DEFINED"; ...
         "PHI2_ABSORPTION_PREVENTION_DEFINED"; ...
         "PASS_FAIL_CRITERIA_DEFINED"; ...
         "CONTAMINATION_CHECKS_DEFINED"; ...
         "READY_FOR_NONCANONICAL_PILOT_IMPLEMENTATION"], ...
        [string(fCompleted); string(fPilotReady); string(fPilotCanonicalStatus); string(fReplacementNow); ...
         string(fPhi1Prevent); string(fPhi2Prevent); string(fCriteriaDefined); string(fContamChecksDefined); ...
         string(fReadyNoncanonicalPilot)], ...
        ["Review completed as design-only pass."; ...
         "Implementation readiness for noncanonical pilot only (not canonical replacement)."; ...
         "Pilot outputs must be diagnostic-only."; ...
         "Current PT/CDF remains active operational reference."; ...
         sprintf("Phi1 absorption prevention gates present=%s.", string(hasPhi1Gate)); ...
         sprintf("Phi2 absorption prevention gates present=%s.", string(hasPhi2Gate)); ...
         sprintf("Strict criteria all-set=%s; RMSE guard=%s.", string(allStrict), string(hasRmseGuard)); ...
         sprintf("Noncanonical influence declared and isolated=%s.", string(stressNoncanonical)); ...
         "Ready for implementation as noncanonical pilot with contamination checks pre-defined."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_tail_aware_backbone_pilot_design_review_status.csv');

    lines = {};
    lines{end+1} = '# Tail-aware backbone pilot design review';
    lines{end+1} = '';
    lines{end+1} = '## Scope';
    lines{end+1} = '- Design review only. No pilot implementation, no scientific analysis, no producer changes.';
    lines{end+1} = '- Current PT/CDF remains active operational reference; replacement remains blocked.';
    lines{end+1} = '';
    lines{end+1} = '## Pilot confirmation';
    lines{end+1} = sprintf('- Candidate name: `%s`', recCandidate);
    lines{end+1} = sprintf('- Pilot name: `%s`', pilotName);
    lines{end+1} = sprintf('- Candidate family: `%s`', pilotFamily);
    lines{end+1} = sprintf('- Pilot classification: `%s`', pilotClass);
    lines{end+1} = sprintf('- Inputs: `%s`', pilotInputs);
    lines{end+1} = sprintf('- Outputs: `%s`', pilotOutputs);
    lines{end+1} = '';
    lines{end+1} = '## Noncanonical influence';
    lines{end+1} = sprintf('- Stress evidence influences pilot ranking: `%s`', string(anyNoncanonicalInfluence));
    lines{end+1} = sprintf('- Stress evidence class isolated as NONCANONICAL_DIAGNOSTIC: `%s`', string(stressNoncanonical));
    lines{end+1} = '- Influence is design guidance only; no stress outputs may be used as training truth.';
    lines{end+1} = '';
    lines{end+1} = '## Required flags';
    lines{end+1} = sprintf('- PILOT_DESIGN_REVIEW_COMPLETED = %s', fCompleted);
    lines{end+1} = sprintf('- PILOT_READY_FOR_IMPLEMENTATION = %s', fPilotReady);
    lines{end+1} = sprintf('- PILOT_CANONICAL_STATUS = %s', fPilotCanonicalStatus);
    lines{end+1} = sprintf('- CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW = %s', fReplacementNow);
    lines{end+1} = sprintf('- PHI1_ABSORPTION_PREVENTION_DEFINED = %s', fPhi1Prevent);
    lines{end+1} = sprintf('- PHI2_ABSORPTION_PREVENTION_DEFINED = %s', fPhi2Prevent);
    lines{end+1} = sprintf('- PASS_FAIL_CRITERIA_DEFINED = %s', fCriteriaDefined);
    lines{end+1} = sprintf('- CONTAMINATION_CHECKS_DEFINED = %s', fContamChecksDefined);
    lines{end+1} = sprintf('- READY_FOR_NONCANONICAL_PILOT_IMPLEMENTATION = %s', fReadyNoncanonicalPilot);
    lines{end+1} = '';
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_tail_aware_backbone_pilot_design_review_checks.csv`';
    lines{end+1} = '- `tables/switching_tail_aware_backbone_pilot_design_review_status.csv`';
    lines{end+1} = '- `reports/switching_tail_aware_backbone_pilot_design_review.md`';

    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_tail_aware_backbone_pilot_design_review:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_tail_aware_backbone_pilot_design_review.md'), lines, 'run_switching_tail_aware_backbone_pilot_design_review:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(checksTbl), {'pilot design review completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_tail_aware_backbone_pilot_design_review_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        ["PILOT_DESIGN_REVIEW_COMPLETED"; "PILOT_READY_FOR_IMPLEMENTATION"; "PILOT_CANONICAL_STATUS"; ...
         "CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW"; "PHI1_ABSORPTION_PREVENTION_DEFINED"; ...
         "PHI2_ABSORPTION_PREVENTION_DEFINED"; "PASS_FAIL_CRITERIA_DEFINED"; ...
         "CONTAMINATION_CHECKS_DEFINED"; "READY_FOR_NONCANONICAL_PILOT_IMPLEMENTATION"], ...
        ["NO"; "NO"; "NON_CANONICAL_DIAGNOSTIC"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"], ...
        repmat(string(failMsg), 9, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_tail_aware_backbone_pilot_design_review_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_pilot_design_review_status.csv'));

    lines = {};
    lines{end+1} = '# Tail-aware backbone pilot design review — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_tail_aware_backbone_pilot_design_review:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_tail_aware_backbone_pilot_design_review.md'), lines, 'run_switching_tail_aware_backbone_pilot_design_review:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'pilot design review failed'}, true);
    rethrow(ME);
end

function [hdr, rows] = localReadCsvRows(pathCsv)
raw = readcell(pathCsv);
hdr = lower(strtrim(string(raw(1,:))));
rows = raw(2:end, :);
end

function idx = localIndex(hdr, key)
idx = find(hdr == lower(string(key)), 1);
if isempty(idx), idx = 0; end
end

function val = localLookup(keysLower, vals, key)
i = find(keysLower == lower(string(key)), 1);
if isempty(i)
    val = "";
else
    val = string(vals(i));
end
end

function out = localGetDetailForCheck(pathCsv, key)
out = "";
lines = readlines(pathCsv);
target = upper(string(key));
for i = 1:numel(lines)
    ln = strtrim(string(lines(i)));
    if ln == "" || startsWith(lower(ln), "check,result"), continue; end
    tok = regexp(char(ln), '^([^,]+),([^,]+),(.*)$', 'tokens', 'once');
    if isempty(tok), continue; end
    if upper(strtrim(string(tok{1}))) == target
        out = string(strtrim(tok{3}));
        return;
    end
end
end

function out = localGetMap(m, key)
out = "";
if isKey(m, upper(string(key)))
    out = m(upper(string(key)));
end
end

function m = localReadStatusMap(pathCsv)
m = containers.Map('KeyType', 'char', 'ValueType', 'char');
lines = readlines(pathCsv);
for i = 1:numel(lines)
    ln = strtrim(string(lines(i)));
    if ln == "" || startsWith(lower(ln), "check,result"), continue; end
    tok = regexp(char(ln), '^([^,]+),([^,]+),?.*$', 'tokens', 'once');
    if isempty(tok), continue; end
    k = upper(strtrim(string(tok{1})));
    v = upper(strtrim(string(tok{2})));
    m(char(k)) = char(v);
end
end

function out = tern(cond, yesVal, noVal)
if cond
    out = yesVal;
else
    out = noVal;
end
end
