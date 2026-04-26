clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_tail_backbone_pilot_readiness';

fContractDefined = 'YES';
fPilotReady = 'PARTIAL';
fPilotCanonical = 'NON_CANONICAL_DIAGNOSTIC';
fReplacementNow = 'NO';
fAlgDefined = 'YES';
fIOContract = 'YES';
fNumericDefined = 'YES';
fPhi1Test = 'YES';
fPhi2Test = 'YES';
fContamChecks = 'YES';
fReadyNoncanonical = 'PARTIAL';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'tail_aware_pilot_implementation_readiness';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'implementation-readiness initialized'}, false);

    pDesign = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_design_status.csv');
    pPilot = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_pilot_spec.csv');
    pCrit = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_replacement_criteria.csv');
    pIdentity = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    for p = {pDesign,pPilot,pCrit,pIdentity}
        if exist(p{1}, 'file') ~= 2
            error('run_switching_tail_backbone_pilot_readiness:MissingInput', 'Missing required input: %s', p{1});
        end
    end

    dMap = localReadStatusMap(pDesign);
    recCandidate = localGetMap(dMap, 'RECOMMENDED_BACKBONE_CANDIDATE');
    replaceNow = localGetMap(dMap, 'CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW');
    rPhi1 = localGetMap(dMap, 'RISK_OF_ABSORBING_PHI1');
    rPhi2 = localGetMap(dMap, 'RISK_OF_ABSORBING_PHI2');

    [pilotHdr, pilotRows] = localReadCsvRows(pPilot);
    iF = localIndex(pilotHdr, 'spec_field');
    iV = localIndex(pilotHdr, 'spec_value');
    sf = lower(string(pilotRows(:, iF)));
    sv = string(pilotRows(:, iV));
    pilotName = localLookup(sf, sv, 'pilot_name');
    pilotFamily = localLookup(sf, sv, 'candidate_family');
    pilotInputs = localLookup(sf, sv, 'inputs');
    pilotOutputs = localLookup(sf, sv, 'output_tables');
    pilotClass = localLookup(sf, sv, 'pilot_classification');
    pilotForbidden = localLookup(sf, sv, 'forbidden_operations');
    pilotReplace = localLookup(sf, sv, 'canonical_replacement_action');
    pilotNcRule = localLookup(sf, sv, 'noncanonical_evidence_rule');

    contractKey = [ ...
        "proposed_script_path"; "script_execution_mode"; "script_structure_requirement"; ...
        "producer_edit_policy"; "canonical_overwrite_policy"; "candidate_name"; "candidate_family"; ...
        "tail_sector_start_cdf"; "tail_sector_definition_type"; "tail_sector_tuning_policy"; ...
        "per_temperature_fit_policy"; "shift_scale_freedom_policy"; "phi2_backbone_policy"; ...
        "phi1_absorption_guard_method"; "phi2_absorption_guard_method"; ...
        "stress_output_usage_policy"; "replacement_policy"];
    contractVal = [ ...
        "Switching/analysis/run_switching_tail_aware_backbone_pilot_noncanonical.m (future, not implemented now)"; ...
        "pure runnable script"; ...
        "no local functions in pilot script"; ...
        "forbidden (no producer edits)"; ...
        "forbidden (no canonical truth table overwrite)"; ...
        string(recCandidate); ...
        string(pilotFamily); ...
        "0.80"; ...
        "predeclared fixed threshold in CDF_pt"; ...
        "forbidden to tune threshold per T or for best RMSE"; ...
        "forbidden: no per-T arbitrary shift/scale/tail fit"; ...
        "forbidden"; ...
        "forbidden: Phi2 cannot be fitted as backbone component"; ...
        "compute Phi1 cosine vs canonical >= threshold + amplitude retention gate"; ...
        "verify Phi2 remains residual diagnostic, not absorbed into backbone correction"; ...
        "comparison-only; never training truth"; ...
        "CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW must remain NO"];
    contractTbl = table(contractKey, contractVal, 'VariableNames', {'contract_key','contract_value'});
    switchingWriteTableBothPaths(contractTbl, repoRoot, runTables, 'switching_tail_aware_backbone_pilot_implementation_contract.csv');

    ioItem = [ ...
        "allowed_input_canonical_identity"; "allowed_input_canonical_truth_tables"; "allowed_input_canonical_diagnostic_tables"; ...
        "allowed_input_noncanonical_diagnostic_tables"; "forbidden_inputs_legacy_alignment_width"; ...
        "forbidden_inputs_noncanonical_as_truth"; "output_tables_diagnostic_only"; "output_report_diagnostic_only"; ...
        "output_figures_scope"; "forbidden_output_writes"; "identity_table_policy"];
    ioSpec = [ ...
        "tables/switching_canonical_identity.csv (read-only)"; ...
        "switching_canonical_S_long.csv, switching_canonical_phi1.csv, switching_mode_amplitudes_vs_T.csv"; ...
        "Phase B/C/B0 status tables for gating only"; ...
        "stress-test tables allowed only as baseline comparison metadata, never training truth"; ...
        "forbidden"; ...
        "forbidden"; ...
        "pilot_backbone_metrics.csv; pilot_backbone_tail_window.csv; pilot_mode_stability.csv (diagnostic namespace)"; ...
        "pilot_noncanonical_report.md only"; ...
        "run-scoped figures only"; ...
        "no writing root canonical truth replacements, no canonical identity edits"; ...
        "no modifications to switching_canonical_identity.csv"];
    ioClass = [ ...
        "CANONICAL_TRUTH"; "CANONICAL_TRUTH"; "CANONICAL_DIAGNOSTIC"; ...
        "NONCANONICAL_DIAGNOSTIC_COMPARISON_ONLY"; "FORBIDDEN"; "FORBIDDEN"; ...
        "NON_CANONICAL_DIAGNOSTIC_OUTPUT"; "NON_CANONICAL_DIAGNOSTIC_OUTPUT"; "NON_CANONICAL_DIAGNOSTIC_OUTPUT"; ...
        "FORBIDDEN"; "FORBIDDEN"];
    ioTbl = table(ioItem, ioSpec, ioClass, 'VariableNames', {'io_contract_item','specification','classification'});
    switchingWriteTableBothPaths(ioTbl, repoRoot, runTables, 'switching_tail_aware_backbone_pilot_input_output_contract.csv');

    critName = [ ...
        "tail_burden_reduction"; "backbone_rmse_improvement"; "phi1_cosine_preservation"; ...
        "phi1_amplitude_preservation"; "residual_spectrum_stability"; "phi2_tail_sensitivity_clarification"; ...
        "phi1_absorption_failure"; "rmse_only_improvement_failure"; "metadata_reproducibility"; "diagnostic_labeling_required"];
    critThreshold = [ ...
        ">=25% reduction in high/mid CDF residual-energy ratio vs current PT/CDF"; ...
        ">=10% reduction in backbone-only RMSE vs current PT/CDF"; ...
        "minimum |cos(Phi1_pilot, Phi1_canonical)| >= 0.90 across required subsets"; ...
        "kappa1 proxy retention within +/-15% median shift relative to canonical baseline"; ...
        "mode1 energy fraction change <= 0.10 abs; mode-order inversion forbidden"; ...
        "Phi2 tail-dominance metric must reduce or be explicitly localized with no backbone embedding"; ...
        "FAIL if Phi1 cosine <0.85 in any required subset or if coordinate DOF increase detected"; ...
        "FAIL if RMSE improves but tail burden does not improve and/or Phi1 stability worsens"; ...
        "all outputs replayable, metadata-gated, and run-context complete"; ...
        "all outputs must include NON_CANONICAL_DIAGNOSTIC tag/status"];
    critDecision = [ ...
        "PASS_REQUIRED"; "PASS_REQUIRED"; "PASS_REQUIRED"; "PASS_REQUIRED"; "PASS_REQUIRED"; ...
        "PASS_REQUIRED"; "IMMEDIATE_FAIL"; "IMMEDIATE_FAIL"; "PASS_REQUIRED"; "PASS_REQUIRED"];
    pfTbl = table(critName, critThreshold, critDecision, 'VariableNames', {'criterion','threshold','decision_mode'});
    switchingWriteTableBothPaths(pfTbl, repoRoot, runTables, 'switching_tail_aware_backbone_pilot_pass_fail_criteria.csv');

    remainingBlockers = "Measurement-layer implementation details remain PARTIAL; Phi2 absorption risk remains HIGH and requires strict runtime guard compliance.";
    if strcmpi(replaceNow, 'NO') && strcmpi(pilotClass, 'NON_CANONICAL_DIAGNOSTIC') ...
            && contains(lower(pilotForbidden), 'phi2') && contains(lower(pilotForbidden), 'shift/scale') ...
            && contains(lower(pilotNcRule), 'not copy stress artifacts as truth')
        fPilotReady = 'PARTIAL';
        fReadyNoncanonical = 'PARTIAL';
    else
        fPilotReady = 'NO';
        fReadyNoncanonical = 'NO';
    end

    statusTbl = table( ...
        ["PILOT_IMPLEMENTATION_CONTRACT_DEFINED"; "PILOT_READY_FOR_IMPLEMENTATION"; "PILOT_CANONICAL_STATUS"; ...
         "CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW"; "ALGORITHM_CONTRACT_DEFINED"; "INPUT_OUTPUT_CONTRACT_DEFINED"; ...
         "NUMERICAL_PASS_FAIL_DEFINED"; "PHI1_ABSORPTION_TEST_DEFINED"; "PHI2_ABSORPTION_TEST_DEFINED"; ...
         "CONTAMINATION_CHECKS_DEFINED"; "READY_FOR_NONCANONICAL_PILOT_IMPLEMENTATION"], ...
        [string(fContractDefined); string(fPilotReady); string(fPilotCanonical); string(fReplacementNow); ...
         string(fAlgDefined); string(fIOContract); string(fNumericDefined); string(fPhi1Test); ...
         string(fPhi2Test); string(fContamChecks); string(fReadyNoncanonical)], ...
        ["Implementation contract table created with fixed tail-sector and script scope."; ...
         "Readiness remains PARTIAL until listed blockers are cleared."; ...
         "Pilot remains diagnostic only."; ...
         "Replacement remains blocked."; ...
         "Algorithm contract includes fixed CDF tail start, no per-T fit freedom, no Phi2 in backbone."; ...
         "Allowed/forbidden I/O and classification contract explicitly defined."; ...
         "Concrete numerical thresholds defined for pass/fail and immediate fail conditions."; ...
         "Phi1 absorption test is concrete (cosine + amplitude retention + subset gates)."; ...
         "Phi2 absorption test is concrete (residual-only role + tail-sensitivity criterion)."; ...
         "Post-pilot contamination checks are explicitly defined."; ...
         remainingBlockers], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_tail_aware_backbone_pilot_readiness_status.csv');

    lines = {};
    lines{end+1} = '# Tail-aware backbone pilot implementation-readiness tightening';
    lines{end+1} = '';
    lines{end+1} = '## Decision';
    lines{end+1} = '- Implementation contract is explicit and concrete.';
    lines{end+1} = '- Pilot remains NON_CANONICAL_DIAGNOSTIC and replacement remains blocked.';
    lines{end+1} = '- Readiness remains PARTIAL because strict blockers remain (measurement partial lock + high Phi2 absorption risk).';
    lines{end+1} = '';
    lines{end+1} = '## Required flags';
    lines{end+1} = sprintf('- PILOT_IMPLEMENTATION_CONTRACT_DEFINED = %s', fContractDefined);
    lines{end+1} = sprintf('- PILOT_READY_FOR_IMPLEMENTATION = %s', fPilotReady);
    lines{end+1} = sprintf('- PILOT_CANONICAL_STATUS = %s', fPilotCanonical);
    lines{end+1} = sprintf('- CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW = %s', fReplacementNow);
    lines{end+1} = sprintf('- ALGORITHM_CONTRACT_DEFINED = %s', fAlgDefined);
    lines{end+1} = sprintf('- INPUT_OUTPUT_CONTRACT_DEFINED = %s', fIOContract);
    lines{end+1} = sprintf('- NUMERICAL_PASS_FAIL_DEFINED = %s', fNumericDefined);
    lines{end+1} = sprintf('- PHI1_ABSORPTION_TEST_DEFINED = %s', fPhi1Test);
    lines{end+1} = sprintf('- PHI2_ABSORPTION_TEST_DEFINED = %s', fPhi2Test);
    lines{end+1} = sprintf('- CONTAMINATION_CHECKS_DEFINED = %s', fContamChecks);
    lines{end+1} = sprintf('- READY_FOR_NONCANONICAL_PILOT_IMPLEMENTATION = %s', fReadyNoncanonical);
    lines{end+1} = '';
    lines{end+1} = '## Remaining blockers';
    lines{end+1} = sprintf('- %s', remainingBlockers);
    lines{end+1} = '';
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_tail_aware_backbone_pilot_implementation_contract.csv`';
    lines{end+1} = '- `tables/switching_tail_aware_backbone_pilot_pass_fail_criteria.csv`';
    lines{end+1} = '- `tables/switching_tail_aware_backbone_pilot_input_output_contract.csv`';
    lines{end+1} = '- `tables/switching_tail_aware_backbone_pilot_readiness_status.csv`';
    lines{end+1} = '- `reports/switching_tail_aware_backbone_pilot_implementation_readiness.md`';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_tail_backbone_pilot_readiness:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_tail_aware_backbone_pilot_implementation_readiness.md'), lines, 'run_switching_tail_backbone_pilot_readiness:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(contractTbl), {'pilot readiness tightening completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_tail_backbone_pilot_readiness_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    failMsg = char(string(ME.message));
    statusTbl = table( ...
        ["PILOT_IMPLEMENTATION_CONTRACT_DEFINED"; "PILOT_READY_FOR_IMPLEMENTATION"; "PILOT_CANONICAL_STATUS"; ...
         "CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW"; "ALGORITHM_CONTRACT_DEFINED"; "INPUT_OUTPUT_CONTRACT_DEFINED"; ...
         "NUMERICAL_PASS_FAIL_DEFINED"; "PHI1_ABSORPTION_TEST_DEFINED"; "PHI2_ABSORPTION_TEST_DEFINED"; ...
         "CONTAMINATION_CHECKS_DEFINED"; "READY_FOR_NONCANONICAL_PILOT_IMPLEMENTATION"], ...
        ["NO"; "NO"; "NON_CANONICAL_DIAGNOSTIC"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"; "NO"], ...
        repmat(string(failMsg), 11, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_tail_aware_backbone_pilot_readiness_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_pilot_readiness_status.csv'));
    lines = {};
    lines{end+1} = '# Tail-aware backbone pilot implementation readiness — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_tail_backbone_pilot_readiness:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_tail_aware_backbone_pilot_implementation_readiness.md'), lines, 'run_switching_tail_backbone_pilot_readiness:WriteFail');
    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'pilot readiness tightening failed'}, true);
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

function out = localLookup(keysLower, vals, key)
i = find(keysLower == lower(string(key)), 1);
if isempty(i), out = ""; else, out = string(vals(i)); end
end

function out = localGetMap(m, key)
out = "";
if isKey(m, upper(string(key))), out = m(upper(string(key))); end
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

function m = localReadStatusMap(pathCsv)
m = containers.Map('KeyType', 'char', 'ValueType', 'char');
lines = readlines(pathCsv);
for i = 1:numel(lines)
    ln = strtrim(string(lines(i)));
    if ln == "" || startsWith(lower(ln), "check,result"), continue; end
    tok = regexp(char(ln), '^([^,]+),([^,]+),?.*$', 'tokens', 'once');
    if isempty(tok), continue; end
    m(char(upper(strtrim(string(tok{1})))) ) = char(upper(strtrim(string(tok{2}))));
end
end
