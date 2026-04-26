clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_limited_claim_readiness';

fCompleted = 'NO';
fLimitedClaimsAllowed = 'NO';
fFullClosureClaimsBlocked = 'YES';
fRank3OpenResidual = 'NO';
fReadyLimitedContext = 'NO';
fReadySnapshot = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_limited_claim_readiness';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Limited claim-readiness review initialized'}, false);

    e5bPath = fullfile(repoRoot, 'tables', 'switching_stage_e5b_claim_boundary_review.csv');
    e5Path = fullfile(repoRoot, 'tables', 'switching_stage_e5_status.csv');
    d4Path = fullfile(repoRoot, 'tables', 'switching_mode_relationship_d4_adaptive_rank_status.csv');
    ePath = fullfile(repoRoot, 'tables', 'switching_stage_e_observable_mapping_status.csv');
    reconPath = fullfile(repoRoot, 'tables', 'switching_stage_e5_reconstruction_hierarchy.csv');
    residualPath = fullfile(repoRoot, 'tables', 'switching_stage_e5_residual_structure.csv');
    reportE5BPath = fullfile(repoRoot, 'reports', 'switching_stage_e5b_claim_boundary_review.md');
    req = {e5bPath, e5Path, d4Path, ePath, reconPath, residualPath, reportE5BPath};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_limited_claim_readiness:MissingInput', 'Missing required input: %s', req{i});
        end
    end

    e5bTbl = readtable(e5bPath, 'TextType', 'string');
    e5Status = readStatusCsv(e5Path);
    d4Status = readStatusCsv(d4Path);
    eStatus = readStatusCsv(ePath);
    reconTbl = readtable(reconPath, 'TextType', 'string');
    residualTbl = readtable(residualPath, 'TextType', 'string');

    if getE5BValue(e5bTbl, "STAGE_E5B_COMPLETED") ~= "YES"
        error('run_switching_limited_claim_readiness:E5BBlocked', 'Limited claim-readiness blocked because Stage E5B is not complete.');
    end
    if getE5BValue(e5bTbl, "READY_FOR_LIMITED_CLAIM_READINESS") ~= "YES"
        error('run_switching_limited_claim_readiness:E5BNotReady', 'Stage E5B does not permit limited claim-readiness.');
    end

    canonicalRunId = getStatusCheck(e5Status, "CANONICAL_RUN_ID");
    phi1Class = getStatusCheck(d4Status, "PHI1_CLASSIFICATION_D4");
    phi2Class = getStatusCheck(d4Status, "PHI2_CLASSIFICATION_D4");
    kappa2Class = getStatusCheck(d4Status, "KAPPA2_CLASSIFICATION_D4");
    rank3Class = getE5BValue(e5bTbl, "RANK3_CLASSIFICATION");

    fLimitedClaimsAllowed = getE5BValue(e5bTbl, "CLAIMS_ALLOWED_LIMITED");
    fFullClosureClaimsBlocked = getE5BValue(e5bTbl, "CLAIMS_BLOCKED_FULL_CLOSURE");
    if rank3Class == "weak_structured_residual" || rank3Class == "numerical_residual" || rank3Class == "unresolved_physical_signal"
        fRank3OpenResidual = 'YES';
    else
        fRank3OpenResidual = 'NO';
    end

    if fLimitedClaimsAllowed == "YES"
        fReadyLimitedContext = 'PARTIAL';
        fReadySnapshot = 'PARTIAL';
    end

    rmseBackbone = pickRecon(reconTbl, "full", "backbone", "rmse_global");
    rmsePhi1 = pickRecon(reconTbl, "full", "backbone_phi1", "rmse_global");
    rmsePhi2 = pickRecon(reconTbl, "full", "backbone_phi1_phi2", "rmse_global");
    fullExplained = pickRecon(reconTbl, "full", "backbone_phi1_phi2", "variance_explained_vs_backbone");
    tailExplained = pickRecon(reconTbl, "high_5_7", "backbone_phi1_phi2", "variance_explained_vs_backbone");
    phi3Gain = pickRecon(reconTbl, "full", "backbone_phi1_phi2_phi3_diag", "incremental_rmse_gain_vs_prev_fraction");
    phi3GainP = pickResidual(residualTbl, "rank3_significance", "rmse_gain_fraction_after_phi2_full", "full", "p_value");
    obsMask = residualTbl.analysis_group == "rank3_observable_linkage" & ...
        ismember(residualTbl.metric_name, ["S_peak","I_peak"]);
    phi3ObsRho = max(abs(residualTbl.observed_value(obsMask)), [], 'omitnan');
    phi3ObsP = min(residualTbl.p_value(obsMask), [], 'omitnan');

    safeLeadSentence = sprintf('Within the canonical Switching analysis, the backbone + Phi1 + Phi2 hierarchy is currently the leading-order interpretable model, reducing full-domain RMSE from %.4f to %.4f to %.4f and explaining %.2f%% of the backbone residual variance.', ...
        rmseBackbone, rmsePhi1, rmsePhi2, 100 * fullExplained);
    safePhi1Sentence = sprintf('Phi1 is interpreted as a stable first residual correction consistent with the D4 `%s` classification and the Stage E canonical observable mapping for kappa1.', phi1Class);
    safePhi2Sentence = sprintf('Phi2 is interpreted as a stable second residual correction consistent with the D4 `%s` / `%s` classification and is especially important in the high-rank tail region, where the rank-2 model explains %.2f%% of backbone residual variance.', ...
        phi2Class, kappa2Class, 100 * tailExplained);
    safeBoundarySentence = sprintf('This rank-2 interpretation should be stated as leading-order only, not as full closure, because a diagnostic rank-3 residual still yields %.4f fractional fit gain after Phi2 (p=%.4f).', ...
        phi3Gain, phi3GainP);
    safeRank3Sentence = sprintf('Rank-3 should be documented only as an open residual branch classified as `%s`: it is not promoted into the canonical model and does not yet show convincing canonical observable linkage (best |rho|=%.4f, p=%.4f).', ...
        rank3Class, phi3ObsRho, phi3ObsP);
    blockedSentence1 = 'Blocked: any statement that the canonical model is fully closed at rank-2 or that higher-order residual structure is negligible.';
    blockedSentence2 = 'Blocked: any statement that rank-3 is a resolved physical mode, an established observable-linked signal, or part of the promoted model.';
    contextSentence = 'Context updates may be partially opened only if they preserve the leading-order / not-full-closure boundary and explicitly document rank-3 as an open residual branch.';
    snapshotSentence = 'Snapshot updates may be partially opened only in a caveated form that includes the same closure disclaimer; uncaveated compressed summaries remain blocked.';

    reviewRows = table();
    reviewRows = [reviewRows; makeRow("status_flag", "LIMITED_CLAIM_READINESS_COMPLETED", "YES", ...
        "Read-only limited claim-readiness review completed using E5B claim boundary plus Stage E5 evidence.", ...
        "Establishes safe wording and update-readiness without changing claims/context/snapshot files.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "LIMITED_CLAIMS_ALLOWED", fLimitedClaimsAllowed, ...
        "E5B allowed limited claims and limited claim-readiness.", ...
        "Leading-order interpretive claims are allowed now, but only with explicit boundary language.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "FULL_CLOSURE_CLAIMS_BLOCKED", fFullClosureClaimsBlocked, ...
        sprintf("E5B blocked full closure; diagnostic rank-3 gain remains %.4f with p=%.4f.", phi3Gain, phi3GainP), ...
        "No full-closure claims are currently safe.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "RANK3_DOCUMENTED_AS_OPEN_RESIDUAL", fRank3OpenResidual, ...
        sprintf("E5B classified rank-3 as `%s` and forbade promotion.", rank3Class), ...
        "Rank-3 may be mentioned only as an open residual branch / weak structured residual.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "READY_FOR_LIMITED_CONTEXT_UPDATE", fReadyLimitedContext, ...
        contextSentence, ...
        "Only partial context opening is safe because caveats must travel with the update.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "READY_FOR_SNAPSHOT_UPDATE", fReadySnapshot, ...
        snapshotSentence, ...
        "Only partial snapshot opening is safe because concise summaries can easily overstate closure.")]; %#ok<AGROW>

    reviewRows = [reviewRows; makeRow("allowed_claim", "leading_order_model_statement", "YES", ...
        safeLeadSentence, ...
        "Safe wording for the core model statement.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("allowed_claim", "phi1_statement", "YES", ...
        safePhi1Sentence, ...
        "Safe wording for Phi1 interpretation.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("allowed_claim", "phi2_statement", "YES", ...
        safePhi2Sentence, ...
        "Safe wording for Phi2 interpretation.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("allowed_claim", "boundary_statement", "YES", ...
        safeBoundarySentence, ...
        "Mandatory boundary sentence accompanying limited claims.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("allowed_claim", "rank3_open_branch_statement", "YES", ...
        safeRank3Sentence, ...
        "Safe wording for documenting the rank-3 branch without promoting it.")]; %#ok<AGROW>

    reviewRows = [reviewRows; makeRow("blocked_claim", "full_closure_statement", "YES", ...
        blockedSentence1, ...
        "Must remain excluded from claims/context/snapshot updates.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("blocked_claim", "rank3_promotion_statement", "YES", ...
        blockedSentence2, ...
        "Must remain excluded from claims/context/snapshot updates.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("update_scope", "context_update_scope", fReadyLimitedContext, ...
        "Allowed only for bounded canonical-model wording plus explicit non-closure caveat and open-rank3 note.", ...
        "Context updates are partially open, not broadly open.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("update_scope", "snapshot_update_scope", fReadySnapshot, ...
        "Allowed only if the snapshot format can preserve both the non-closure caveat and the open-rank3 note.", ...
        "Snapshot updates are more compression-sensitive and remain only partially open.")]; %#ok<AGROW>

    switchingWriteTableBothPaths(reviewRows, repoRoot, runTables, 'switching_limited_claim_readiness.csv');

    lines = {};
    lines{end+1} = '# Limited claim-readiness review';
    lines{end+1} = '';
    lines{end+1} = sprintf('- Canonical lock: `CANONICAL_RUN_ID=%s`', canonicalRunId);
    lines{end+1} = '- Scope: read-only review after E5B; no modeling, reruns, or claim/context/snapshot updates performed.';
    lines{end+1} = '';
    lines{end+1} = '## Flags';
    lines{end+1} = sprintf('- LIMITED_CLAIM_READINESS_COMPLETED = YES');
    lines{end+1} = sprintf('- LIMITED_CLAIMS_ALLOWED = %s', fLimitedClaimsAllowed);
    lines{end+1} = sprintf('- FULL_CLOSURE_CLAIMS_BLOCKED = %s', fFullClosureClaimsBlocked);
    lines{end+1} = sprintf('- RANK3_DOCUMENTED_AS_OPEN_RESIDUAL = %s', fRank3OpenResidual);
    lines{end+1} = sprintf('- READY_FOR_LIMITED_CONTEXT_UPDATE = %s', fReadyLimitedContext);
    lines{end+1} = sprintf('- READY_FOR_SNAPSHOT_UPDATE = %s', fReadySnapshot);
    lines{end+1} = '';
    lines{end+1} = '## Allowed now';
    lines{end+1} = ['- ' safeLeadSentence];
    lines{end+1} = ['- ' safePhi1Sentence];
    lines{end+1} = ['- ' safePhi2Sentence];
    lines{end+1} = ['- ' safeBoundarySentence];
    lines{end+1} = ['- ' safeRank3Sentence];
    lines{end+1} = '';
    lines{end+1} = '## Blocked now';
    lines{end+1} = ['- ' blockedSentence1];
    lines{end+1} = ['- ' blockedSentence2];
    lines{end+1} = '';
    lines{end+1} = '## Update readiness';
    lines{end+1} = ['- ' contextSentence];
    lines{end+1} = ['- ' snapshotSentence];
    lines{end+1} = '- Claims/context/snapshot/query files themselves remain untouched in this stage.';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_limited_claim_readiness:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', [baseName '.md']), lines, 'run_switching_limited_claim_readiness:WriteFail');

    fCompleted = 'YES';
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(reviewRows), {'Limited claim-readiness review completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_limited_claim_readiness_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    failTbl = table( ...
        ["LIMITED_CLAIM_READINESS_COMPLETED";"LIMITED_CLAIMS_ALLOWED";"FULL_CLOSURE_CLAIMS_BLOCKED"; ...
         "RANK3_DOCUMENTED_AS_OPEN_RESIDUAL";"READY_FOR_LIMITED_CONTEXT_UPDATE";"READY_FOR_SNAPSHOT_UPDATE"], ...
        [string('NO');string(fLimitedClaimsAllowed);string(fFullClosureClaimsBlocked);string(fRank3OpenResidual); ...
         string(fReadyLimitedContext);string(fReadySnapshot)], ...
        [string(ME.message);strings(5,1)], ...
        'VariableNames', {'item','result','evidence'});
    writetable(failTbl, fullfile(runDir, 'tables', 'switching_limited_claim_readiness.csv'));
    writetable(failTbl, fullfile(repoRoot, 'tables', 'switching_limited_claim_readiness.csv'));

    lines = {};
    lines{end+1} = '# Limited claim-readiness review FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_limited_claim_readiness:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', [baseName '.md']), lines, 'run_switching_limited_claim_readiness:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Limited claim-readiness review failed'}, true);
    rethrow(ME);
end

function tbl = readStatusCsv(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
if size(raw,1) < 2 || size(raw,2) < 2
    error('run_switching_limited_claim_readiness:BadStatusSchema', 'Malformed status csv: %s', pathIn);
end
headers = strings(1, size(raw,2));
for i = 1:size(raw,2)
    headers(i) = lower(strip(string(raw{1,i})));
    headers(i) = regexprep(headers(i), "^\xFEFF", "");
end
iCheck = find(headers == "check", 1);
iResult = find(headers == "result", 1);
iDetail = find(headers == "detail", 1);
if isempty(iCheck) || isempty(iResult)
    error('run_switching_limited_claim_readiness:BadStatusSchema', 'Status csv missing check/result columns: %s', pathIn);
end
n = size(raw,1) - 1;
detail = strings(n,1);
if ~isempty(iDetail)
    detail = string(raw(2:end, iDetail));
end
tbl = table( ...
    strip(string(raw(2:end, iCheck))), ...
    strip(string(raw(2:end, iResult))), ...
    detail, ...
    'VariableNames', {'check','result','detail'});
end

function value = getStatusCheck(tbl, key)
idx = find(strcmpi(strip(string(tbl.check)), strip(string(key))), 1);
if isempty(idx)
    value = "";
else
    value = strip(string(tbl.result(idx)));
end
end

function value = getE5BValue(tbl, item)
m = tbl.item == string(item) & tbl.review_group == "status_flag";
if ~any(m)
    value = "";
else
    value = string(tbl.result(find(m,1)));
end
end

function value = pickRecon(tbl, domainName, modelLabel, fieldName)
m = tbl.domain_name == string(domainName) & tbl.model_label == string(modelLabel);
if ~any(m)
    value = NaN;
else
    value = tbl.(fieldName)(find(m,1));
end
end

function value = pickResidual(tbl, groupName, metricName, domainName, fieldName)
m = tbl.analysis_group == string(groupName) & tbl.metric_name == string(metricName) & tbl.domain_name == string(domainName);
if ~any(m)
    value = NaN;
else
    value = tbl.(fieldName)(find(m,1));
end
end

function tbl = makeRow(group, item, result, evidence, boundary)
tbl = table(string(group), string(item), string(result), string(evidence), string(boundary), ...
    'VariableNames', {'review_group','item','result','evidence','claim_boundary'});
end
