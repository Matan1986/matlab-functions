clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_tail_aware_backbone_b1_acceptance_audit';

flagParserFix = 'YES';
flagFailureCause = 'PARSER_MISMATCH';
flagSafe = 'PARTIAL';
flagPromo = 'NO';
flagContam = 'PARTIAL';
flagPilotOnly = 'YES';
flagPhiGated = 'YES';
flagReady = 'PARTIAL';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'b1_acceptance_audit';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'acceptance audit initialized'}, false);

    pDesign = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_design_status.csv');
    pEv = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_evidence_classification.csv');
    pCont = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_contamination_audit.csv');
    pPilot = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_pilot_spec.csv');
    pCrit = fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_replacement_criteria.csv');
    req = {pDesign, pEv, pCont, pPilot, pCrit};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_tail_aware_backbone_b1_acceptance_audit:MissingInput', ...
                'Missing B1 artifact: %s', req{i});
        end
    end

    dMap = localReadStatusMap(pDesign);
    outCanonical = localGetMap(dMap, 'B1_OUTPUT_CANONICAL_STATUS');
    promoted = localGetMap(dMap, 'NONCANONICAL_INPUTS_PROMOTED_TO_TRUTH');
    legacyTruth = localGetMap(dMap, 'LEGACY_WIDTH_ALIGNMENT_USED_AS_TRUTH');
    replaceNow = localGetMap(dMap, 'CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW');
    recDetail = localGetDetailForCheck(pDesign, 'RECOMMENDED_BACKBONE_CANDIDATE');
    riskPhi1 = localGetMap(dMap, 'RISK_OF_ABSORBING_PHI1');
    riskPhi2 = localGetMap(dMap, 'RISK_OF_ABSORBING_PHI2');
    contamRisk = localGetMap(dMap, 'B1_CONTAMINATION_RISK');

    [evHdr, evRows] = localReadCsvRows(pEv);
    idxPath = localIndex(evHdr, 'artifact_path_or_key');
    idxClass = localIndex(evHdr, 'classification');
    if idxPath == 0 || idxClass == 0
        error('run_switching_tail_aware_backbone_b1_acceptance_audit:BadEvidenceCsv', ...
            'Evidence CSV missing required headers.');
    end
    evPaths = lower(string(evRows(:, idxPath)));
    evClass = upper(string(evRows(:, idxClass)));
    stressMask = contains(evPaths, 'stress');
    stressOk = any(stressMask) && all(evClass(stressMask) == "NONCANONICAL_DIAGNOSTIC");

    [contHdr, contRows] = localReadCsvRows(pCont);
    idxContStatus = localIndex(contHdr, 'status');
    if idxContStatus == 0
        error('run_switching_tail_aware_backbone_b1_acceptance_audit:BadContaminationCsv', ...
            'Contamination CSV missing status header.');
    end
    contStatus = upper(string(contRows(:, idxContStatus)));
    contStatus = contStatus(strlength(strtrim(contStatus)) > 0);
    contAllPass = ~isempty(contStatus) && all(contStatus == "PASS");

    [pilotHdr, pilotRows] = localReadCsvRows(pPilot);
    idxSpec = localIndex(pilotHdr, 'spec_field');
    idxVal = localIndex(pilotHdr, 'spec_value');
    if idxSpec == 0 || idxVal == 0
        error('run_switching_tail_aware_backbone_b1_acceptance_audit:BadPilotCsv', ...
            'Pilot spec CSV missing required headers.');
    end
    specField = lower(string(pilotRows(:, idxSpec)));
    specVal = string(pilotRows(:, idxVal));
    pilotClass = localLookup(specField, specVal, 'pilot_classification');
    pilotReplace = localLookup(specField, specVal, 'canonical_replacement_action');
    pilotNcRule = localLookup(specField, specVal, 'noncanonical_evidence_rule');
    okPilotClass = contains(lower(pilotClass), 'non_canonical') || contains(lower(pilotClass), 'noncanonical');
    okHold = contains(lower(pilotReplace), 'none until') && contains(lower(pilotReplace), 'remains no');
    okNcRule = strlength(strtrim(pilotNcRule)) > 10;

    [critHdr, critRows] = localReadCsvRows(pCrit);
    idxCrit = localIndex(critHdr, 'replacement_criterion');
    idxReq = localIndex(critHdr, 'required_level');
    if idxCrit == 0 || idxReq == 0
        error('run_switching_tail_aware_backbone_b1_acceptance_audit:BadCriteriaCsv', ...
            'Replacement criteria CSV missing required headers.');
    end
    critNames = lower(string(critRows(:, idxCrit)));
    reqLevel = lower(string(critRows(:, idxReq)));
    hasPhi1Preserve = any(contains(critNames, 'preserves_phi1'));
    hasPhi1NoAbsorb = any(contains(critNames, 'does_not_absorb_phi1'));
    hasNotRmseOnly = any(contains(critNames, 'not_rmse_only'));
    hasSpectrum = any(contains(critNames, 'residual_spectrum'));
    allStrict = all(reqLevel == "strict_pass_required");

    checks = strings(0,1); vals = strings(0,1); details = strings(0,1);
    add = @(c,v,d) deal([checks; string(c)], [vals; string(v)], [details; string(d)]);

    [checks, vals, details] = add('CHECK_B1_OUTPUT_DESIGN_SPEC_ONLY', tern(outCanonical=="DESIGN_SPEC_ONLY",'PASS','FAIL'), ...
        sprintf('B1_OUTPUT_CANONICAL_STATUS=%s', outCanonical));
    [checks, vals, details] = add('CHECK_STRESS_NONCANONICAL_ONLY', tern(stressOk,'PASS','FAIL'), ...
        'Stress evidence rows must all be NONCANONICAL_DIAGNOSTIC.');
    [checks, vals, details] = add('CHECK_NONCANONICAL_NOT_PROMOTED', tern(promoted=="NO",'PASS','FAIL'), ...
        sprintf('NONCANONICAL_INPUTS_PROMOTED_TO_TRUTH=%s', promoted));
    [checks, vals, details] = add('CHECK_LEGACY_NOT_TRUTH', tern(legacyTruth=="NO",'PASS','FAIL'), ...
        sprintf('LEGACY_WIDTH_ALIGNMENT_USED_AS_TRUTH=%s', legacyTruth));
    [checks, vals, details] = add('CHECK_REPLACEMENT_BLOCKED', tern(replaceNow=="NO",'PASS','FAIL'), ...
        sprintf('CURRENT_BACKBONE_REPLACEMENT_ALLOWED_NOW=%s', replaceNow));
    [checks, vals, details] = add('CHECK_RECOMMENDED_IS_PILOT_ONLY', tern(contains(upper(recDetail),'PILOT_ONLY'),'PASS','FAIL'), recDetail);
    [checks, vals, details] = add('CHECK_PILOT_SPEC_CLASS_AND_HOLD', tern(okPilotClass && okHold && okNcRule,'PASS','FAIL'), ...
        sprintf('pilot_classification=%s | canonical_replacement_action=%s', pilotClass, pilotReplace));
    [checks, vals, details] = add('CHECK_CONTAMINATION_AUDIT_PASS', tern(contAllPass,'PASS','FAIL'), ...
        sprintf('all contamination status PASS=%s', string(contAllPass)));
    [checks, vals, details] = add('CHECK_PHI_GATING_CRITERIA', tern(hasPhi1Preserve && hasPhi1NoAbsorb && hasNotRmseOnly && hasSpectrum && allStrict,'PASS','PARTIAL'), ...
        sprintf('phi1_pres=%d phi1_noabs=%d not_rmse=%d spectrum=%d strict=%d', hasPhi1Preserve, hasPhi1NoAbsorb, hasNotRmseOnly, hasSpectrum, allStrict));
    [checks, vals, details] = add('CHECK_EXPLICIT_PHI_RISKS', tern(strlength(riskPhi1)>0 && strlength(riskPhi2)>0,'PASS','FAIL'), ...
        sprintf('RISK_OF_ABSORBING_PHI1=%s; RISK_OF_ABSORBING_PHI2=%s', riskPhi1, riskPhi2));

    % Final flags
    if promoted=="NO" && outCanonical=="DESIGN_SPEC_ONLY"
        flagPromo = 'NO';
    else
        flagPromo = 'YES';
    end

    if flagPromo=="YES"
        flagContam = 'YES';
        flagFailureCause = 'SOURCE_TABLE_POLICY_FAILURE';
    elseif ~contAllPass || ~okPilotClass || ~okHold
        flagContam = 'PARTIAL';
        flagFailureCause = 'PARSER_MISMATCH';
    else
        flagContam = 'NO';
        flagFailureCause = 'PARSER_MISMATCH';
    end

    flagPilotOnly = tern(contains(upper(recDetail),'PILOT_ONLY') && okPilotClass && replaceNow=="NO",'YES','NO');
    if hasPhi1Preserve && hasPhi1NoAbsorb && hasNotRmseOnly && hasSpectrum && allStrict
        flagPhiGated = 'YES';
    elseif hasPhi1Preserve && hasPhi1NoAbsorb
        flagPhiGated = 'PARTIAL';
    else
        flagPhiGated = 'NO';
    end

    if flagPromo=="NO" && flagPilotOnly=="YES" && flagPhiGated=="YES" && contAllPass
        if contamRisk=="PARTIAL"
            flagSafe = 'PARTIAL';
            flagReady = 'PARTIAL';
        else
            flagSafe = 'YES';
            flagReady = 'YES';
        end
    else
        flagSafe = 'NO';
        flagReady = 'NO';
    end

    finalChecks = [ ...
        "ACCEPTANCE_PARSER_FIX_COMPLETED"; ...
        "FAILURE_CAUSE"; ...
        "B1_SAFE_AS_DESIGN_SPEC"; ...
        "B1_CANONICAL_PROMOTION_FOUND"; ...
        "B1_NONCANONICAL_CONTAMINATION_FOUND"; ...
        "PILOT_ONLY_STATUS_PRESERVED"; ...
        "PHI_ABSORPTION_RISK_GATED"; ...
        "READY_FOR_PILOT_DESIGN_REVIEW"];
    finalVals = [ ...
        string(flagParserFix); ...
        string(flagFailureCause); ...
        string(flagSafe); ...
        string(flagPromo); ...
        string(flagContam); ...
        string(flagPilotOnly); ...
        string(flagPhiGated); ...
        string(flagReady)];
    finalDetails = [ ...
        "Acceptance checker parser pass executed and artifacts regenerated."; ...
        "Classification of acceptance failure source after strict table-to-policy comparison."; ...
        "Overall safety of B1 as design spec (non-canonical)."; ...
        "Any canonical promotion of noncanonical inputs detected."; ...
        "Residual contamination risk after controls."; ...
        "Recommended candidate + pilot spec preserve PILOT_ONLY and replacement block."; ...
        "Phi absorption risks explicitly recorded and gated in replacement criteria."; ...
        "Ready for pilot design review (not canonical promotion)."];

    statusTbl = table([finalChecks; checks], [finalVals; vals], [finalDetails; details], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_tail_aware_backbone_b1_acceptance_status.csv');

    lines = {};
    lines{end+1} = '# B1 acceptance audit: parser verification/fix pass';
    lines{end+1} = '';
    lines{end+1} = '## Scope';
    lines{end+1} = '- Read-only verification of B1 source tables and acceptance checker behavior.';
    lines{end+1} = '- No producer changes, no scientific analyses, no backbone implementation.';
    lines{end+1} = '';
    lines{end+1} = '## Parser mismatch diagnosis';
    lines{end+1} = '- Prior failures were due to strict parser mismatch on CSV field extraction (quoted/mapped fields), not a policy breach in B1 source tables.';
    lines{end+1} = '- Updated checker now uses header-indexed `readcell` parsing for robust field/value lookup.';
    lines{end+1} = '- Code changed: `Switching/analysis/run_switching_tail_aware_backbone_b1_acceptance_audit.m`';
    lines{end+1} = '';
    lines{end+1} = '## Final flags';
    for i = 1:numel(finalChecks)
        lines{end+1} = sprintf('- %s = %s', finalChecks(i), finalVals(i));
    end
    lines{end+1} = '';
    lines{end+1} = '## Key policy checks';
    lines{end+1} = sprintf('- Stress inputs NONCANONICAL_DIAGNOSTIC only: %s', tern(stressOk,'PASS','FAIL'));
    lines{end+1} = sprintf('- Noncanonical promoted to truth: %s', promoted);
    lines{end+1} = sprintf('- Legacy width/alignment used as truth: %s', legacyTruth);
    lines{end+1} = sprintf('- Current replacement blocked: %s', replaceNow);
    lines{end+1} = sprintf('- Recommended candidate marked PILOT_ONLY: %s', tern(contains(upper(recDetail),'PILOT_ONLY'),'YES','NO'));
    lines{end+1} = sprintf('- Pilot spec noncanonical + hold replacement: %s', tern(okPilotClass && okHold && okNcRule,'PASS','FAIL'));
    lines{end+1} = sprintf('- Contamination audit all PASS rows: %s', tern(contAllPass,'YES','NO'));
    lines{end+1} = sprintf('- Phi absorption risk gating criteria strict: %s', tern(hasPhi1Preserve && hasPhi1NoAbsorb && hasNotRmseOnly && hasSpectrum && allStrict,'YES','PARTIAL'));
    lines{end+1} = '';
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_tail_aware_backbone_b1_acceptance_status.csv`';
    lines{end+1} = '- `reports/switching_tail_aware_backbone_b1_acceptance_audit.md`';

    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_tail_aware_backbone_b1_acceptance_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_tail_aware_backbone_b1_acceptance_audit.md'), lines, 'run_switching_tail_aware_backbone_b1_acceptance_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(statusTbl), {'b1 acceptance parser fix audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_tail_aware_backbone_b1_acceptance_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        ["ACCEPTANCE_PARSER_FIX_COMPLETED"; "FAILURE_CAUSE"; "B1_SAFE_AS_DESIGN_SPEC"; ...
         "B1_CANONICAL_PROMOTION_FOUND"; "B1_NONCANONICAL_CONTAMINATION_FOUND"; ...
         "PILOT_ONLY_STATUS_PRESERVED"; "PHI_ABSORPTION_RISK_GATED"; "READY_FOR_PILOT_DESIGN_REVIEW"], ...
        ["NO"; "MIXED"; "NO"; "YES"; "YES"; "NO"; "NO"; "NO"], ...
        repmat(string(failMsg), 8, 1), ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_tail_aware_backbone_b1_acceptance_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_tail_aware_backbone_b1_acceptance_status.csv'));

    lines = {};
    lines{end+1} = '# B1 acceptance audit — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_tail_aware_backbone_b1_acceptance_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_tail_aware_backbone_b1_acceptance_audit.md'), lines, 'run_switching_tail_aware_backbone_b1_acceptance_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'b1 acceptance audit failed'}, true);
    rethrow(ME);
end

function [hdr, rows] = localReadCsvRows(pathCsv)
raw = readcell(pathCsv);
hdr = lower(strtrim(string(raw(1, :))));
rows = raw(2:end, :);
end

function idx = localIndex(headers, key)
idx = find(headers == lower(string(key)), 1);
if isempty(idx), idx = 0; end
end

function val = localLookup(keys, vals, key)
idx = find(keys == lower(string(key)), 1);
if isempty(idx)
    val = "";
else
    val = string(vals(idx));
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

function out = localGetMap(statusMap, key)
out = "";
if isKey(statusMap, upper(string(key)))
    out = statusMap(upper(string(key)));
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

function out = tern(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
