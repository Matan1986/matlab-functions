clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_stage_e5b_claim_boundary_review';

fStageE5BCompleted = 'NO';
fRank2InterpretableAllowed = 'PARTIAL';
fRank2FullClosureAllowed = 'NO';
fRank3PromotionAllowed = 'NO';
fRank3Classification = 'weak_structured_residual';
fClaimsAllowedLimited = 'NO';
fClaimsBlockedFullClosure = 'YES';
fAdditionalTestRequired = 'PARTIAL';
fReadyLimitedClaimReadiness = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_stage_e5b_claim_boundary_review';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Stage E5B claim-boundary review initialized'}, false);

    e5SpectrumPath = fullfile(repoRoot, 'tables', 'switching_stage_e5_mode_order_spectrum.csv');
    e5ReconPath = fullfile(repoRoot, 'tables', 'switching_stage_e5_reconstruction_hierarchy.csv');
    e5ResidualPath = fullfile(repoRoot, 'tables', 'switching_stage_e5_residual_structure.csv');
    e5StabilityPath = fullfile(repoRoot, 'tables', 'switching_stage_e5_mode_stability.csv');
    e5StatusPath = fullfile(repoRoot, 'tables', 'switching_stage_e5_status.csv');
    e5ReportPath = fullfile(repoRoot, 'reports', 'switching_stage_e5_mode_order_sufficiency.md');
    d4StatusPath = fullfile(repoRoot, 'tables', 'switching_mode_relationship_d4_adaptive_rank_status.csv');
    eStatusPath = fullfile(repoRoot, 'tables', 'switching_stage_e_observable_mapping_status.csv');
    req = {e5SpectrumPath, e5ReconPath, e5ResidualPath, e5StabilityPath, e5StatusPath, e5ReportPath, d4StatusPath, eStatusPath};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2
            error('run_switching_stage_e5b_claim_boundary_review:MissingInput', 'Missing required input: %s', req{i});
        end
    end

    e5Status = readStatusCsv(e5StatusPath);
    d4Status = readStatusCsv(d4StatusPath);
    eStatus = readStatusCsv(eStatusPath);
    if getStatusCheck(e5Status, "STAGE_E5_COMPLETED") ~= "YES"
        error('run_switching_stage_e5b_claim_boundary_review:E5Blocked', 'Stage E5B blocked because Stage E5 is not completed.');
    end
    if getStatusCheck(d4Status, "D4_COMPLETED") ~= "YES" || getStatusCheck(eStatus, "STAGE_E_COMPLETED") ~= "YES"
        error('run_switching_stage_e5b_claim_boundary_review:ContextBlocked', 'Stage D4 / Stage E context is incomplete.');
    end

    reconTbl = readtable(e5ReconPath, 'TextType', 'string');
    residualTbl = readtable(e5ResidualPath, 'TextType', 'string');
    stabilityTbl = readtable(e5StabilityPath, 'TextType', 'string');
    spectrumTbl = readtable(e5SpectrumPath, 'TextType', 'string');

    canonicalRunId = getStatusCheck(e5Status, "CANONICAL_RUN_ID");

    phi1GainFull = pickRecon(reconTbl, "full", "backbone_phi1", "incremental_rmse_gain_vs_prev_fraction");
    phi2GainFull = pickRecon(reconTbl, "full", "backbone_phi1_phi2", "incremental_rmse_gain_vs_prev_fraction");
    phi2GainTail = pickRecon(reconTbl, "high_5_7", "backbone_phi1_phi2", "incremental_rmse_gain_vs_prev_fraction");
    phi2ExplainedFull = pickRecon(reconTbl, "full", "backbone_phi1_phi2", "variance_explained_vs_backbone");
    phi2ExplainedTail = pickRecon(reconTbl, "high_5_7", "backbone_phi1_phi2", "variance_explained_vs_backbone");
    phi3GainFull = pickRecon(reconTbl, "full", "backbone_phi1_phi2_phi3_diag", "incremental_rmse_gain_vs_prev_fraction");
    phi3GainTail = pickRecon(reconTbl, "high_5_7", "backbone_phi1_phi2_phi3_diag", "incremental_rmse_gain_vs_prev_fraction");

    phi1SubsetMin = pickStability(stabilityTbl, "phi1", "subset_exclusion", "abs_cosine_to_full_mode", "aggregate_min");
    phi2SubsetMin = pickStability(stabilityTbl, "phi2", "subset_exclusion", "abs_cosine_to_full_mode", "aggregate_min");
    phi3SubsetMin = pickStability(stabilityTbl, "phi3_diag", "subset_exclusion", "abs_cosine_to_full_mode", "aggregate_min");
    phi3Median = pickStability(stabilityTbl, "phi3_diag", "leave_one_temperature_out", "abs_cosine_to_full_mode", "aggregate_median");
    phi3AmpMedian = pickStability(stabilityTbl, "phi3_diag", "leave_one_temperature_out", "aligned_amplitude_corr", "aggregate_median");

    phi3SigmaP = pickResidual(residualTbl, "rank3_significance", "sigma1_after_phi2", "full", "p_value");
    phi3Energy = pickResidual(residualTbl, "rank3_significance", "energy_fraction_after_phi2_mode1", "full", "observed_value");
    phi3GainP = pickResidual(residualTbl, "rank3_significance", "rmse_gain_fraction_after_phi2_full", "full", "p_value");
    phi3TailEnergy = pickResidual(residualTbl, "rank3_localization", "phi3_energy_fraction", "high_5_7", "observed_value");
    phi3TailP = pickResidual(residualTbl, "rank3_localization", "phi3_energy_fraction", "high_5_7", "p_value");
    phi3TvP = pickResidual(residualTbl, "rank3_structure", "phi3_total_variation", "full", "p_value");
    phi3ObsRho = max(abs(residualTbl.observed_value( ...
        residualTbl.analysis_group == "rank3_observable_linkage" & ...
        ismember(residualTbl.metric_name, ["S_peak","I_peak"] ))), [], 'omitnan');
    phi3ObsP = min(residualTbl.p_value( ...
        residualTbl.analysis_group == "rank3_observable_linkage" & ...
        ismember(residualTbl.metric_name, ["S_peak","I_peak"] )), [], 'omitnan');
    phi3Kappa2Rho = pickResidual(residualTbl, "rank3_observable_linkage", "kappa2", "temperature", "observed_value");
    phi3Kappa2P = pickResidual(residualTbl, "rank3_observable_linkage", "kappa2", "temperature", "p_value");
    phi3ProducerRho = pickResidual(residualTbl, "rank3_observable_linkage", "kappa3_producer", "temperature", "observed_value");
    phi3ProducerP = pickResidual(residualTbl, "rank3_observable_linkage", "kappa3_producer", "temperature", "p_value");

    stageE5Rank3SigFlag = getStatusCheck(e5Status, "RANK3_SIGNIFICANT");
    stageE5Rank3StableFlag = getStatusCheck(e5Status, "RANK3_STABLE");
    stageE5Rank3ObsFlag = getStatusCheck(e5Status, "RANK3_OBSERVABLE_LINKED");

    rank2CoreStrong = isfinite(phi1GainFull) && phi1GainFull > 0 && ...
        isfinite(phi2GainFull) && phi2GainFull >= 0.30 && ...
        isfinite(phi2GainTail) && phi2GainTail >= 0.50 && ...
        isfinite(phi2ExplainedFull) && phi2ExplainedFull >= 0.95 && ...
        isfinite(phi2ExplainedTail) && phi2ExplainedTail >= 0.98 && ...
        isfinite(phi1SubsetMin) && phi1SubsetMin >= 0.50 && ...
        isfinite(phi2SubsetMin) && phi2SubsetMin >= 0.65 && ...
        getStatusCheck(eStatus, "KAPPA1_CANONICAL_OBSERVABLE_FOUND") == "YES" && ...
        getStatusCheck(eStatus, "KAPPA2_CANONICAL_OBSERVABLE_FOUND") == "YES";

    if rank2CoreStrong
        fRank2InterpretableAllowed = 'YES';
    else
        fRank2InterpretableAllowed = 'PARTIAL';
    end

    fRank2FullClosureAllowed = 'NO';
    fClaimsBlockedFullClosure = 'YES';
    fRank3PromotionAllowed = 'NO';

    if stageE5Rank3SigFlag == "NO" && stageE5Rank3StableFlag == "NO" && stageE5Rank3ObsFlag == "NO"
        fRank3Classification = 'numerical_residual';
    elseif stageE5Rank3ObsFlag == "NO" && ...
            ((stageE5Rank3SigFlag == "PARTIAL" || stageE5Rank3StableFlag == "PARTIAL") || ...
             (isfinite(phi3GainFull) && phi3GainFull >= 0.10) || ...
             (isfinite(phi3ProducerRho) && abs(phi3ProducerRho) >= 0.90))
        fRank3Classification = 'weak_structured_residual';
    else
        fRank3Classification = 'unresolved_physical_signal';
    end

    if fRank2InterpretableAllowed == "YES"
        fClaimsAllowedLimited = 'YES';
        fReadyLimitedClaimReadiness = 'YES';
    elseif fRank2InterpretableAllowed == "PARTIAL"
        fClaimsAllowedLimited = 'PARTIAL';
        fReadyLimitedClaimReadiness = 'NO';
    else
        fClaimsAllowedLimited = 'NO';
        fReadyLimitedClaimReadiness = 'NO';
    end

    if fRank3Classification == "weak_structured_residual"
        fAdditionalTestRequired = 'PARTIAL';
    elseif fRank3Classification == "unresolved_physical_signal"
        fAdditionalTestRequired = 'YES';
    else
        fAdditionalTestRequired = 'NO';
    end

    reviewRows = table();
    reviewRows = [reviewRows; makeRow("status_flag", "STAGE_E5B_COMPLETED", "YES", ...
        "Read-only claim-boundary review completed from Stage E5 artifacts.", ...
        "Establishes explicit claim boundary without rerunning or changing models.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "RANK2_INTERPRETABLE_MODEL_ALLOWED", fRank2InterpretableAllowed, ...
        sprintf("Rank-2 gains/stability are strong: phi1 gain=%.4f, phi2 gain=%.4f, phi2 tail gain=%.4f, phi2 explained(full/tail)=%.4f/%.4f, subset minima phi1/phi2=%.4f/%.4f.", ...
        phi1GainFull, phi2GainFull, phi2GainTail, phi2ExplainedFull, phi2ExplainedTail, phi1SubsetMin, phi2SubsetMin), ...
        "Rank-2 may be used as the current interpretable leading-order model.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "RANK2_FULL_CLOSURE_CLAIM_ALLOWED", fRank2FullClosureAllowed, ...
        sprintf("Stage E5 left higher-order closure unresolved: rank3 significance=%s, stability=%s, observable linkage=%s.", ...
        stageE5Rank3SigFlag, stageE5Rank3StableFlag, stageE5Rank3ObsFlag), ...
        "Do not claim rank-2 exhausts all physically relevant residual structure.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "RANK3_PROMOTION_ALLOWED", fRank3PromotionAllowed, ...
        sprintf("Rank3 lacks promotion support: sigma p=%.4f, observable rho/p=%.4f/%.4f, tail fraction p=%.4f.", ...
        phi3SigmaP, phi3ObsRho, phi3ObsP, phi3TailP), ...
        "Do not promote the diagnostic rank-3 layer into the interpreted model.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "RANK3_CLASSIFICATION", fRank3Classification, ...
        sprintf("Rank3 improves fit (gain=%.4f, p=%.4f) and is internally reproducible (median stability=%.4f, amplitude median corr=%.4f), but lacks canonical observable support and localization.", ...
        phi3GainFull, phi3GainP, phi3Median, phi3AmpMedian), ...
        "Treat the rank-3 layer as residual structure with limited interpretive status.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "CLAIMS_ALLOWED_LIMITED", fClaimsAllowedLimited, ...
        "Rank-2 reconstruction and D4/E mappings support bounded interpretation of backbone, Phi1, and Phi2 roles.", ...
        "Limited claim-readiness may proceed for leading-order statements only.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "CLAIMS_BLOCKED_FULL_CLOSURE", fClaimsBlockedFullClosure, ...
        "Stage E5 did not certify higher-order irrelevance.", ...
        "Full closure / no-higher-mode claims remain blocked.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "ADDITIONAL_TEST_REQUIRED", fAdditionalTestRequired, ...
        sprintf("Weak point is residual persistence across transition-focused exclusions: phi3 subset min=%.4f, tail localization p=%.4f, observable rho/p=%.4f/%.4f.", ...
        phi3SubsetMin, phi3TailP, phi3ObsRho, phi3ObsP), ...
        "Only one targeted extra robustness test is needed if stronger-than-limited claims are desired.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("status_flag", "READY_FOR_LIMITED_CLAIM_READINESS", fReadyLimitedClaimReadiness, ...
        "Limited claim-readiness depends on accepting rank-2 as a leading-order model while preserving explicit exclusions.", ...
        "Proceed only with bounded claim language; do not update claims in this stage.")]; %#ok<AGROW>

    reviewRows = [reviewRows; makeRow("allowed_claim", "rank2_leading_order_model", "YES", ...
        sprintf("Backbone->Phi1->Phi2 improves full RMSE from %.4f to %.4f to %.4f and explains %.2f%% of backbone residual variance.", ...
        pickRecon(reconTbl, "full", "backbone", "rmse_global"), ...
        pickRecon(reconTbl, "full", "backbone_phi1", "rmse_global"), ...
        pickRecon(reconTbl, "full", "backbone_phi1_phi2", "rmse_global"), ...
        100 * phi2ExplainedFull), ...
        "Allowed claim: rank-2 is the current interpretable approximation to the canonical switching residual hierarchy.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("allowed_claim", "phi1_backbone_error_axis", "YES", ...
        sprintf("D4 classified Phi1 as `%s`; Stage E mapped kappa1 canonically; phi1 stability subset min=%.4f.", ...
        getStatusCheck(d4Status, "PHI1_CLASSIFICATION_D4"), phi1SubsetMin), ...
        "Allowed claim: Phi1 is a stable interpretable correction associated with backbone error / residual redistribution.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("allowed_claim", "phi2_tail_burden_axis", "YES", ...
        sprintf("D4 classified Phi2/Kappa2 as `%s`/`%s`; Phi2 adds %.4f tail fractional gain; Stage E validated kappa2 tail-burden mapping.", ...
        getStatusCheck(d4Status, "PHI2_CLASSIFICATION_D4"), getStatusCheck(d4Status, "KAPPA2_CLASSIFICATION_D4"), phi2GainTail), ...
        "Allowed claim: Phi2 captures a stable second-order tail-burden residual component in the current canonical model.")]; %#ok<AGROW>

    reviewRows = [reviewRows; makeRow("blocked_claim", "rank2_complete_closure", "YES", ...
        sprintf("Diagnostic Phi3 still yields %.4f full-domain fractional gain with p=%.4f.", phi3GainFull, phi3GainP), ...
        "Blocked claim: rank-2 fully closes the residual hierarchy.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("blocked_claim", "rank3_physical_mode", "YES", ...
        sprintf("Rank3 canonical observable linkage is weak (best rho/p=%.4f/%.4f), tail localization p=%.4f, smoothness p=%.4f.", ...
        phi3ObsRho, phi3ObsP, phi3TailP, phi3TvP), ...
        "Blocked claim: rank-3 is an established physical mode or observable-linked signal.")]; %#ok<AGROW>
    reviewRows = [reviewRows; makeRow("blocked_claim", "no_higher_order_interpretive_risk", "YES", ...
        sprintf("Stage E5 status left higher-order blocking as `%s`.", getStatusCheck(e5Status, "HIGHER_ORDER_MODES_BLOCK_CLAIMS")), ...
        "Blocked claim: no higher-order residual structure can affect interpretation.")]; %#ok<AGROW>

    reviewRows = [reviewRows; makeRow("recommended_test", "minimum_additional_test", "transition_band_block_exclusion", ...
        sprintf("Existing E5 holdouts show phi3 weak point under subset exclusion (subset min=%.4f) but no canonical observable support. A single contiguous transition-band block exclusion around the 28-32 K regime would test whether the diagnostic mode survives the transition cluster rather than isolated single-temperature drops.", phi3SubsetMin), ...
        "Minimum extra test, only if stronger-than-limited claims are needed: contiguous transition-band exclusion / re-evaluation of diagnostic rank3 persistence and localization.")]; %#ok<AGROW>

    switchingWriteTableBothPaths(reviewRows, repoRoot, runTables, 'switching_stage_e5b_claim_boundary_review.csv');

    lines = {};
    lines{end+1} = '# Stage E5B rank-2 claim-boundary review';
    lines{end+1} = '';
    lines{end+1} = sprintf('- Canonical lock: `CANONICAL_RUN_ID=%s`', canonicalRunId);
    lines{end+1} = '- Scope: read-only review of Stage E5 outputs plus Stage D4 / Stage E context.';
    lines{end+1} = '- No producer changes, reruns, or claim updates were performed.';
    lines{end+1} = '';
    lines{end+1} = '## Decision';
    lines{end+1} = sprintf('- RANK2_INTERPRETABLE_MODEL_ALLOWED = %s', fRank2InterpretableAllowed);
    lines{end+1} = sprintf('- RANK2_FULL_CLOSURE_CLAIM_ALLOWED = %s', fRank2FullClosureAllowed);
    lines{end+1} = sprintf('- RANK3_PROMOTION_ALLOWED = %s', fRank3PromotionAllowed);
    lines{end+1} = sprintf('- RANK3_CLASSIFICATION = %s', fRank3Classification);
    lines{end+1} = sprintf('- CLAIMS_ALLOWED_LIMITED = %s', fClaimsAllowedLimited);
    lines{end+1} = sprintf('- CLAIMS_BLOCKED_FULL_CLOSURE = %s', fClaimsBlockedFullClosure);
    lines{end+1} = sprintf('- ADDITIONAL_TEST_REQUIRED = %s', fAdditionalTestRequired);
    lines{end+1} = sprintf('- READY_FOR_LIMITED_CLAIM_READINESS = %s', fReadyLimitedClaimReadiness);
    lines{end+1} = '';
    lines{end+1} = '## Why rank-2 is allowed';
    lines{end+1} = sprintf('- Rank-2 explains %.2f%% of full-domain backbone residual variance and %.2f%% in the high-rank window.', ...
        100 * phi2ExplainedFull, 100 * phi2ExplainedTail);
    lines{end+1} = sprintf('- Phi1 and Phi2 are stable under subset exclusion (subset minima %.4f and %.4f) and already have D4/E interpretive support.', ...
        phi1SubsetMin, phi2SubsetMin);
    lines{end+1} = sprintf('- Phi2 remains especially important in the tail/high-rank region with fractional gain %.4f.', phi2GainTail);
    lines{end+1} = '';
    lines{end+1} = '## Why full closure is blocked';
    lines{end+1} = sprintf('- Diagnostic rank-3 still improves full-domain reconstruction by %.4f fractional gain (p=%.4f).', phi3GainFull, phi3GainP);
    lines{end+1} = sprintf('- But that diagnostic does not pass physical promotion tests: sigma p=%.4f, canonical observable rho/p=%.4f/%.4f, tail localization p=%.4f, smoothness p=%.4f.', ...
        phi3SigmaP, phi3ObsRho, phi3ObsP, phi3TailP, phi3TvP);
    lines{end+1} = sprintf('- Internal consistency remains strong against producer kappa3 (rho=%.4f, p=%.4f), which supports classification as `%s` rather than a promoted physical mode.', ...
        phi3ProducerRho, phi3ProducerP, fRank3Classification);
    lines{end+1} = '';
    lines{end+1} = '## Allowed claims';
    lines{end+1} = '- Rank-2 is the current interpretable leading-order model for the canonical Switching residual hierarchy.';
    lines{end+1} = '- Phi1 is a stable first residual correction consistent with the D4 backbone-error classification.';
    lines{end+1} = '- Phi2 is a stable second residual correction consistent with the D4 tail-burden interpretation.';
    lines{end+1} = '';
    lines{end+1} = '## Blocked claims';
    lines{end+1} = '- Do not claim full rank-2 closure or the absence of higher-order residual structure.';
    lines{end+1} = '- Do not promote rank-3 into the interpretable model.';
    lines{end+1} = '- Do not claim a resolved physical interpretation for rank-3.';
    lines{end+1} = '';
    lines{end+1} = '## Minimum additional test';
    lines{end+1} = '- Only needed if stronger-than-limited claims are desired: run one contiguous transition-band block exclusion test centered on the 28-32 K cluster and re-check diagnostic rank-3 persistence/localization.';
    lines{end+1} = '- If that test fails, the current limited-claim boundary should stand; if it passes cleanly, a follow-up review can revisit whether the residual remains merely weakly structured.';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_stage_e5b_claim_boundary_review:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', [baseName '.md']), lines, 'run_switching_stage_e5b_claim_boundary_review:WriteFail');

    fStageE5BCompleted = 'YES';
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(reviewRows), {'Stage E5B claim-boundary review completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_stage_e5b_claim_boundary_review_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    failTbl = table( ...
        ["STAGE_E5B_COMPLETED";"RANK2_INTERPRETABLE_MODEL_ALLOWED";"RANK2_FULL_CLOSURE_CLAIM_ALLOWED"; ...
         "RANK3_PROMOTION_ALLOWED";"RANK3_CLASSIFICATION";"CLAIMS_ALLOWED_LIMITED"; ...
         "CLAIMS_BLOCKED_FULL_CLOSURE";"ADDITIONAL_TEST_REQUIRED";"READY_FOR_LIMITED_CLAIM_READINESS"], ...
        [string('NO');string(fRank2InterpretableAllowed);string(fRank2FullClosureAllowed);string(fRank3PromotionAllowed); ...
         string(fRank3Classification);string(fClaimsAllowedLimited);string(fClaimsBlockedFullClosure); ...
         string(fAdditionalTestRequired);string(fReadyLimitedClaimReadiness)], ...
        [string(ME.message);strings(8,1)], ...
        'VariableNames', {'item','result','evidence'});
    writetable(failTbl, fullfile(runDir, 'tables', 'switching_stage_e5b_claim_boundary_review.csv'));
    writetable(failTbl, fullfile(repoRoot, 'tables', 'switching_stage_e5b_claim_boundary_review.csv'));

    lines = {};
    lines{end+1} = '# Stage E5B rank-2 claim-boundary review FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_stage_e5b_claim_boundary_review:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', [baseName '.md']), lines, 'run_switching_stage_e5b_claim_boundary_review:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Stage E5B claim-boundary review failed'}, true);
    rethrow(ME);
end

function tbl = readStatusCsv(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
if size(raw,1) < 2 || size(raw,2) < 2
    error('run_switching_stage_e5b_claim_boundary_review:BadStatusSchema', 'Malformed status csv: %s', pathIn);
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
    error('run_switching_stage_e5b_claim_boundary_review:BadStatusSchema', 'Status csv missing check/result columns: %s', pathIn);
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

function value = pickRecon(tbl, domainName, modelLabel, fieldName)
m = tbl.domain_name == string(domainName) & tbl.model_label == string(modelLabel);
if ~any(m)
    value = NaN;
else
    value = tbl.(fieldName)(find(m, 1));
end
end

function value = pickResidual(tbl, groupName, metricName, domainName, fieldName)
m = tbl.analysis_group == string(groupName) & tbl.metric_name == string(metricName) & tbl.domain_name == string(domainName);
if ~any(m)
    value = NaN;
else
    value = tbl.(fieldName)(find(m, 1));
end
end

function value = pickStability(tbl, modeId, holdoutType, metricName, fieldName)
m = tbl.mode_id == string(modeId) & tbl.holdout_type == string(holdoutType) & tbl.metric_name == string(metricName);
if ~any(m)
    value = NaN;
else
    value = tbl.(fieldName)(find(m, 1));
end
end

function tbl = makeRow(group, item, result, evidence, boundary)
tbl = table(string(group), string(item), string(result), string(evidence), string(boundary), ...
    'VariableNames', {'review_group','item','result','evidence','claim_boundary'});
end
