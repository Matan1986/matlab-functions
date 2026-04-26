clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

runDir = '';
baseName = 'switching_stage_e5_mode_order_sufficiency';

% Required flags defaults
fStageE5Completed = 'NO';
fRank2Sufficient = 'PARTIAL';
fRank3Significant = 'PARTIAL';
fRank3Stable = 'PARTIAL';
fRank3ObservableLinked = 'PARTIAL';
fHigherOrderBlocksClaims = 'PARTIAL';
fReadyClaimReview = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'switching_stage_e5_mode_order_sufficiency';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'Stage E.5 canonical mode-order sufficiency audit initialized'}, false);

    d4Path = fullfile(repoRoot, 'tables', 'switching_mode_relationship_d4_adaptive_rank_status.csv');
    ePath = fullfile(repoRoot, 'tables', 'switching_stage_e_observable_mapping_status.csv');
    idPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
    ampPath = fullfile(repoRoot, 'tables', 'switching_mode_amplitudes_vs_T.csv');
    obsRootPath = fullfile(repoRoot, 'results', 'switching');
    req = {d4Path, ePath, idPath, ampPath, obsRootPath};
    for i = 1:numel(req)
        if exist(req{i}, 'file') ~= 2 && exist(req{i}, 'dir') ~= 7
            error('run_switching_stage_e5_mode_order_sufficiency:MissingInput', 'Missing required input: %s', req{i});
        end
    end

    d4 = readStatusCsv(d4Path);
    e = readStatusCsv(ePath);
    if getStatusCheck(d4, "D4_COMPLETED") ~= "YES" || getStatusCheck(d4, "READY_FOR_STAGE_E_FROM_D4") ~= "YES"
        error('run_switching_stage_e5_mode_order_sufficiency:D4Gate', 'Stage E.5 blocked: D4 completion/readiness flags not satisfied.');
    end
    if getStatusCheck(e, "STAGE_E_COMPLETED") ~= "YES"
        error('run_switching_stage_e5_mode_order_sufficiency:EGate', 'Stage E.5 blocked: Stage E is not complete.');
    end
    if getStatusCheck(d4, "CLAIMS_UPDATE_ALLOWED") ~= "NO" || getStatusCheck(e, "READY_FOR_CLAIMS_UPDATE") ~= "NO"
        error('run_switching_stage_e5_mode_order_sufficiency:ClaimsEmbargo', 'Claims embargo violated: expected claims update flags to remain NO.');
    end

    canonicalRunId = readCanonicalRunId(idPath);
    canonicalRunIdD4 = getStatusCheck(d4, "CANONICAL_RUN_ID");
    canonicalRunIdE = getStatusCheck(e, "CANONICAL_RUN_ID");
    if strlength(canonicalRunId) == 0 || canonicalRunId ~= canonicalRunIdD4 || canonicalRunId ~= canonicalRunIdE
        error('run_switching_stage_e5_mode_order_sufficiency:IdentityMismatch', ...
            'Canonical run mismatch across identity/D4/Stage E tables: identity=%s, D4=%s, E=%s', canonicalRunId, canonicalRunIdD4, canonicalRunIdE);
    end

    canonTables = fullfile(repoRoot, 'results', 'switching', 'runs', char(canonicalRunId), 'tables');
    sLongPath = fullfile(canonTables, 'switching_canonical_S_long.csv');
    phi1Path = fullfile(canonTables, 'switching_canonical_phi1.csv');
    obsPath = fullfile(canonTables, 'switching_canonical_observables.csv');
    reqCanon = {sLongPath, phi1Path, obsPath, ampPath};
    for i = 1:numel(reqCanon)
        if exist(reqCanon{i}, 'file') ~= 2
            error('run_switching_stage_e5_mode_order_sufficiency:CanonicalMissing', ...
                'Identity-locked canonical artifact missing: %s', reqCanon{i});
        end
    end

    ctxBase = struct('repo_root', repoRoot, 'required_context', 'canonical_collapse');
    validateCanonicalInputTable(sLongPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_S_long.csv', 'expected_role', 'canonical_raw_long')));
    validateCanonicalInputTable(phi1Path, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_canonical_phi1.csv', 'expected_role', 'phi1_shape')));
    validateCanonicalInputTable(ampPath, switchingMergeStructCtx(ctxBase, struct('table_name', 'switching_mode_amplitudes_vs_T.csv', 'expected_role', 'mode_amplitudes')));
    % This identity-locked run predates metadata sidecars for the observables table.
    % Stage E already consumed the same artifact by path+schema without sidecar validation.

    sLong = readtable(sLongPath);
    phi1Tbl = readtable(phi1Path);
    ampTbl = readtable(ampPath);
    obsTbl = readtable(obsPath);

    data = buildCanonicalMaps(sLong, phi1Tbl, ampTbl);
    hierarchy = buildHierarchy(data);

    nPerm = 500;
    rng(0, 'twister');
    nullR0 = permutationNullSummary(hierarchy.R0z, nPerm);
    nullR1 = permutationNullSummary(hierarchy.R1z, nPerm);
    nullR2 = permutationNullSummary(hierarchy.R2z, nPerm);

    spectrumTbl = buildSpectrumTable(nullR0, nullR1, nullR2, hierarchy);
    switchingWriteTableBothPaths(spectrumTbl, repoRoot, runTables, 'switching_stage_e5_mode_order_spectrum.csv');

    reconDomains = buildReconstructionDomains(data);
    reconTbl = buildReconstructionHierarchyTable(data, hierarchy, reconDomains);
    switchingWriteTableBothPaths(reconTbl, repoRoot, runTables, 'switching_stage_e5_reconstruction_hierarchy.csv');

    observableTbl = buildObservableJoin(obsTbl, hierarchy, data);
    residualTbl = buildResidualStructureTable(data, hierarchy, observableTbl, nullR2, reconTbl, reconDomains);
    switchingWriteTableBothPaths(residualTbl, repoRoot, runTables, 'switching_stage_e5_residual_structure.csv');

    stabilityTbl = buildModeStabilityTable(data, hierarchy);
    switchingWriteTableBothPaths(stabilityTbl, repoRoot, runTables, 'switching_stage_e5_mode_stability.csv');

    rank3GainFull = pickReconMetric(reconTbl, "full", "backbone_phi1_phi2_phi3_diag", "incremental_rmse_gain_vs_prev_fraction");
    rank3GainHigh = pickReconMetric(reconTbl, "high_5_7", "backbone_phi1_phi2_phi3_diag", "incremental_rmse_gain_vs_prev_fraction");
    rank3SigmaP = pickResidualMetric(residualTbl, "rank3_significance", "sigma1_after_phi2", "p_value");
    rank3GainP = pickResidualMetric(residualTbl, "rank3_significance", "rmse_gain_fraction_after_phi2_full", "p_value");
    rank3EnergyFrac = pickResidualMetric(residualTbl, "rank3_significance", "energy_fraction_after_phi2_mode1", "observed_value");
    rank3TailEnergy = pickResidualMetric(residualTbl, "rank3_localization", "phi3_energy_fraction", "observed_value", "high_5_7");
    rank3TailP = pickResidualMetric(residualTbl, "rank3_localization", "phi3_energy_fraction", "p_value", "high_5_7");
    rank3SmoothP = pickResidualMetric(residualTbl, "rank3_structure", "phi3_total_variation", "p_value");

    phi3LotoMedian = pickStabilityAggregate(stabilityTbl, "phi3_diag", "leave_one_temperature_out", "abs_cosine_to_full_mode", "median");
    phi3LotoMin = pickStabilityAggregate(stabilityTbl, "phi3_diag", "leave_one_temperature_out", "abs_cosine_to_full_mode", "min");
    phi3SubsetMin = pickStabilityAggregate(stabilityTbl, "phi3_diag", "subset_exclusion", "abs_cosine_to_full_mode", "min");
    phi3AmpMedian = pickStabilityAggregate(stabilityTbl, "phi3_diag", "leave_one_temperature_out", "aligned_amplitude_corr", "median");

    obsMaskOnly = residualTbl.analysis_group == "rank3_observable_linkage" & ...
        ~ismember(residualTbl.metric_name, ["kappa2","kappa3_producer"]);
    bestObsRho = max(abs(residualTbl.observed_value(obsMaskOnly)), [], 'omitnan');
    bestObsP = min(residualTbl.p_value(obsMaskOnly), [], 'omitnan');
    controlKappa3Rho = pickResidualMetric(residualTbl, "rank3_observable_linkage", "kappa3_producer", "observed_value");
    controlKappa3P = pickResidualMetric(residualTbl, "rank3_observable_linkage", "kappa3_producer", "p_value");

    isRank3SignificantYes = isfinite(rank3SigmaP) && isfinite(rank3GainP) && rank3SigmaP <= 0.05 && rank3GainP <= 0.05 && ...
        isfinite(rank3GainFull) && rank3GainFull >= 0.10 && isfinite(rank3EnergyFrac) && rank3EnergyFrac >= 0.10;
    isRank3SignificantPartial = ...
        ((isfinite(rank3SigmaP) && rank3SigmaP <= 0.10 && isfinite(rank3EnergyFrac) && rank3EnergyFrac >= 0.10) || ...
         (isfinite(rank3GainP) && rank3GainP <= 0.05 && ((isfinite(rank3GainFull) && rank3GainFull >= 0.10) || (isfinite(rank3GainHigh) && rank3GainHigh >= 0.10))));

    if isRank3SignificantYes
        fRank3Significant = 'YES';
    elseif isRank3SignificantPartial
        fRank3Significant = 'PARTIAL';
    else
        fRank3Significant = 'NO';
    end

    isRank3StableYes = isfinite(phi3LotoMedian) && phi3LotoMedian >= 0.75 && isfinite(phi3LotoMin) && phi3LotoMin >= 0.45 && ...
        isfinite(phi3SubsetMin) && phi3SubsetMin >= 0.45 && isfinite(phi3AmpMedian) && phi3AmpMedian >= 0.50;
    isRank3StablePartial = isfinite(phi3LotoMedian) && phi3LotoMedian >= 0.55 && isfinite(phi3SubsetMin) && phi3SubsetMin >= 0.25;
    if isRank3StableYes
        fRank3Stable = 'YES';
    elseif isRank3StablePartial
        fRank3Stable = 'PARTIAL';
    else
        fRank3Stable = 'NO';
    end

    isObsLinkedYes = isfinite(bestObsRho) && isfinite(bestObsP) && bestObsRho >= 0.60 && bestObsP <= 0.05;
    isObsLinkedPartial = isfinite(bestObsRho) && isfinite(bestObsP) && bestObsRho >= 0.40 && bestObsP <= 0.10;
    if isObsLinkedYes
        fRank3ObservableLinked = 'YES';
    elseif isObsLinkedPartial
        fRank3ObservableLinked = 'PARTIAL';
    else
        fRank3ObservableLinked = 'NO';
    end

    structuredYes = isfinite(rank3TailEnergy) && isfinite(rank3TailP) && rank3TailEnergy >= 0.50 && rank3TailP <= 0.05 && ...
        isfinite(rank3SmoothP) && rank3SmoothP <= 0.10;
    structuredPartial = isfinite(rank3TailEnergy) && rank3TailEnergy >= 0.35 && (rank3TailP <= 0.10 || rank3SmoothP <= 0.20);

    if fRank3Significant == "YES" && fRank3Stable == "YES" && (fRank3ObservableLinked == "YES" || structuredYes)
        fHigherOrderBlocksClaims = 'YES';
        fRank2Sufficient = 'NO';
    elseif fRank3Significant == "PARTIAL" || fRank3Stable == "PARTIAL" || structuredPartial || fRank3ObservableLinked == "PARTIAL"
        fHigherOrderBlocksClaims = 'PARTIAL';
        fRank2Sufficient = 'PARTIAL';
    else
        fHigherOrderBlocksClaims = 'NO';
        fRank2Sufficient = 'YES';
    end

    if fRank2Sufficient == "YES" && fHigherOrderBlocksClaims == "NO"
        fReadyClaimReview = 'YES';
    else
        fReadyClaimReview = 'NO';
    end

    statusTbl = table( ...
        ["STAGE_E5_COMPLETED";"RANK2_RECONSTRUCTION_SUFFICIENT";"RANK3_SIGNIFICANT";"RANK3_STABLE"; ...
         "RANK3_OBSERVABLE_LINKED";"HIGHER_ORDER_MODES_BLOCK_CLAIMS";"READY_FOR_CLAIM_READINESS_REVIEW"; ...
         "CANONICAL_RUN_ID";"PHI1_CLASSIFICATION_D4";"PHI2_CLASSIFICATION_D4";"KAPPA2_CLASSIFICATION_D4"], ...
        [string('YES');string(fRank2Sufficient);string(fRank3Significant);string(fRank3Stable); ...
         string(fRank3ObservableLinked);string(fHigherOrderBlocksClaims);string(fReadyClaimReview); ...
         string(canonicalRunId);getStatusCheck(d4, "PHI1_CLASSIFICATION_D4");getStatusCheck(d4, "PHI2_CLASSIFICATION_D4"); ...
         getStatusCheck(d4, "KAPPA2_CLASSIFICATION_D4")], ...
        [ ...
         "Stage E.5 canonical mode-order sufficiency audit completed."; ...
         sprintf("Full-domain rank3 diagnostic gain=%.4f, high-rank gain=%.4f.", rank3GainFull, rank3GainHigh); ...
         sprintf("Rank3 significance from after-phi2 residual: sigma p=%.4f, gain p=%.4f, energy fraction=%.4f.", rank3SigmaP, rank3GainP, rank3EnergyFrac); ...
         sprintf("Phi3 diagnostic stability: LOTO median |cos|=%.4f, LOTO min=%.4f, subset min=%.4f, amplitude median corr=%.4f.", phi3LotoMedian, phi3LotoMin, phi3SubsetMin, phi3AmpMedian); ...
         sprintf("Best canonical observable linkage for diagnostic rank3 amplitude: |rho|=%.4f, shuffled-T p=%.4f; producer-control kappa3 rho=%.4f (p=%.4f).", bestObsRho, bestObsP, controlKappa3Rho, controlKappa3P); ...
         sprintf("Tail localization fraction=%.4f (p=%.4f), total-variation p=%.4f.", rank3TailEnergy, rank3TailP, rank3SmoothP); ...
         "Claim-readiness review allowed only if higher-order modes do not block interpretation."; ...
         "Identity-locked canonical run used throughout Stage E.5."; ...
         "Imported from D4 status for context only."; ...
         "Imported from D4 status for context only."; ...
         "Imported from D4 status for context only."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_stage_e5_status.csv');

    reportLines = {};
    reportLines{end+1} = '# Stage E.5 canonical mode-order sufficiency audit';
    reportLines{end+1} = '';
    reportLines{end+1} = sprintf('- Canonical lock: `CANONICAL_RUN_ID=%s`', canonicalRunId);
    reportLines{end+1} = '- Scope: canonical Switching data only; backbone unchanged; producer outputs treated as fixed.';
    reportLines{end+1} = '- Hierarchy audited: backbone, backbone + Phi1, backbone + Phi1 + Phi2, and diagnostic Phi3 from the existing level-2 residual.';
    reportLines{end+1} = '';
    reportLines{end+1} = '## Reconstruction hierarchy';
    reportLines{end+1} = sprintf('- Full-domain incremental RMSE gain: Phi1 = %.4f, Phi2 = %.4f, Phi3 diagnostic = %.4f.', ...
        pickReconMetric(reconTbl, "full", "backbone_phi1", "incremental_rmse_gain_vs_prev"), ...
        pickReconMetric(reconTbl, "full", "backbone_phi1_phi2", "incremental_rmse_gain_vs_prev"), ...
        pickReconMetric(reconTbl, "full", "backbone_phi1_phi2_phi3_diag", "incremental_rmse_gain_vs_prev"));
    reportLines{end+1} = sprintf('- Fractional gain over previous level (full domain): Phi1 = %.4f, Phi2 = %.4f, Phi3 diagnostic = %.4f.', ...
        pickReconMetric(reconTbl, "full", "backbone_phi1", "incremental_rmse_gain_vs_prev_fraction"), ...
        pickReconMetric(reconTbl, "full", "backbone_phi1_phi2", "incremental_rmse_gain_vs_prev_fraction"), ...
        rank3GainFull);
    reportLines{end+1} = sprintf('- High-rank window (`5:7`) Phi3 diagnostic fractional gain = %.4f.', rank3GainHigh);
    reportLines{end+1} = '';
    reportLines{end+1} = '## Rank-3 diagnostic tests';
    reportLines{end+1} = sprintf('- RANK3_SIGNIFICANT = %s (sigma p=%.4f, gain p=%.4f, after-phi2 mode-1 energy fraction=%.4f).', ...
        fRank3Significant, rank3SigmaP, rank3GainP, rank3EnergyFrac);
    reportLines{end+1} = sprintf('- RANK3_STABLE = %s (LOTO median |cos|=%.4f, subset min=%.4f, amplitude median corr=%.4f).', ...
        fRank3Stable, phi3LotoMedian, phi3SubsetMin, phi3AmpMedian);
    reportLines{end+1} = sprintf('- RANK3_OBSERVABLE_LINKED = %s (best canonical-observable |rho|=%.4f, shuffled-T p=%.4f; producer-control kappa3 rho=%.4f, p=%.4f).', ...
        fRank3ObservableLinked, bestObsRho, bestObsP, controlKappa3Rho, controlKappa3P);
    reportLines{end+1} = sprintf('- Strong kappa3-diagnostic vs producer-kappa3 agreement is treated as an internal consistency control, not as an observable linkage claim.');
    reportLines{end+1} = sprintf('- Tail/high-rank localization: energy fraction=%.4f with p=%.4f; total-variation p=%.4f.', ...
        rank3TailEnergy, rank3TailP, rank3SmoothP);
    reportLines{end+1} = '';
    reportLines{end+1} = '## Decision';
    reportLines{end+1} = sprintf('- RANK2_RECONSTRUCTION_SUFFICIENT = %s', fRank2Sufficient);
    reportLines{end+1} = sprintf('- HIGHER_ORDER_MODES_BLOCK_CLAIMS = %s', fHigherOrderBlocksClaims);
    reportLines{end+1} = sprintf('- READY_FOR_CLAIM_READINESS_REVIEW = %s', fReadyClaimReview);
    reportLines{end+1} = '';
    reportLines{end+1} = '## Notes';
    reportLines{end+1} = '- Phi1 uses the documented sign convention from the canonical collapse hierarchy audit: `pred1 = backbone - kappa1 * phi1Vec''`.';
    reportLines{end+1} = '- Phi2 is re-derived from the level-1 residual and paired with the existing `kappa2(T)` amplitude, matching the current canonical hierarchy script.';
    reportLines{end+1} = '- Phi3 is diagnostic only and is not promoted into the model by this audit.';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), reportLines, 'run_switching_stage_e5_mode_order_sufficiency:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', [baseName '.md']), reportLines, 'run_switching_stage_e5_mode_order_sufficiency:WriteFail');

    fStageE5Completed = 'YES';
    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(reconTbl), {'Stage E.5 canonical mode-order sufficiency audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_stage_e5_mode_order_sufficiency_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    statusTbl = table( ...
        ["STAGE_E5_COMPLETED";"RANK2_RECONSTRUCTION_SUFFICIENT";"RANK3_SIGNIFICANT";"RANK3_STABLE"; ...
         "RANK3_OBSERVABLE_LINKED";"HIGHER_ORDER_MODES_BLOCK_CLAIMS";"READY_FOR_CLAIM_READINESS_REVIEW"], ...
        [string('NO');string(fRank2Sufficient);string(fRank3Significant);string(fRank3Stable); ...
         string(fRank3ObservableLinked);string(fHigherOrderBlocksClaims);string(fReadyClaimReview)], ...
        [string(ME.message);strings(6,1)], ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_stage_e5_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_stage_e5_status.csv'));

    emptySpectrum = table(string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), strings(0,1), ...
        'VariableNames', {'residual_stage','mode_rank','singular_value','energy_fraction','cumulative_energy_fraction','null_mean','null_std','null_p95','p_value','detail'});
    emptyRecon = table(string.empty(0,1), string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'domain_name','model_label','n_points','rmse_global','mean_row_rmse','residual_energy','residual_energy_fraction_vs_backbone','incremental_rmse_gain_vs_prev','incremental_rmse_gain_vs_prev_fraction','variance_explained_vs_backbone'});
    emptyResidual = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', {'analysis_group','metric_name','domain_name','observed_value','null_mean','null_p95','p_value','verdict','detail'});
    emptyStability = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), strings(0,1), ...
        'VariableNames', {'mode_id','holdout_type','holdout_label','metric_name','observed_value','aggregate_median','aggregate_min','aggregate_max','detail'});

    writetable(emptySpectrum, fullfile(runDir, 'tables', 'switching_stage_e5_mode_order_spectrum.csv'));
    writetable(emptySpectrum, fullfile(repoRoot, 'tables', 'switching_stage_e5_mode_order_spectrum.csv'));
    writetable(emptyRecon, fullfile(runDir, 'tables', 'switching_stage_e5_reconstruction_hierarchy.csv'));
    writetable(emptyRecon, fullfile(repoRoot, 'tables', 'switching_stage_e5_reconstruction_hierarchy.csv'));
    writetable(emptyResidual, fullfile(runDir, 'tables', 'switching_stage_e5_residual_structure.csv'));
    writetable(emptyResidual, fullfile(repoRoot, 'tables', 'switching_stage_e5_residual_structure.csv'));
    writetable(emptyStability, fullfile(runDir, 'tables', 'switching_stage_e5_mode_stability.csv'));
    writetable(emptyStability, fullfile(repoRoot, 'tables', 'switching_stage_e5_mode_stability.csv'));

    lines = {};
    lines{end+1} = '# Stage E.5 canonical mode-order sufficiency audit FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_stage_e5_mode_order_sufficiency:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', [baseName '.md']), lines, 'run_switching_stage_e5_mode_order_sufficiency:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'Stage E.5 canonical mode-order sufficiency audit failed'}, true);
    rethrow(ME);
end

function out = readStatusCsv(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
if size(raw,1) < 2 || size(raw,2) < 2
    error('run_switching_stage_e5_mode_order_sufficiency:BadStatusSchema', 'Status table is empty or malformed: %s', pathIn);
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
    error('run_switching_stage_e5_mode_order_sufficiency:BadStatusSchema', 'Status table missing check/result columns: %s', pathIn);
end
n = size(raw,1) - 1;
detail = strings(n,1);
if ~isempty(iDetail)
    detail = string(raw(2:end, iDetail));
end
out = table( ...
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

function runId = readCanonicalRunId(pathIn)
raw = readcell(pathIn, 'Delimiter', ',');
runId = "";
for r = 2:size(raw,1)
    key = strip(string(raw{r,1}));
    key = regexprep(key, "^\xFEFF", "");
    if strcmpi(key, "CANONICAL_RUN_ID")
        runId = strip(string(raw{r,2}));
        return;
    end
end
end

function data = buildCanonicalMaps(sLong, phi1Tbl, ampTbl)
reqS = {'T_K','current_mA','S_percent','S_model_pt_percent','CDF_pt'};
for i = 1:numel(reqS)
    if ~ismember(reqS{i}, sLong.Properties.VariableNames)
        error('run_switching_stage_e5_mode_order_sufficiency:BadSLongSchema', 'switching_canonical_S_long.csv missing %s', reqS{i});
    end
end
reqP = {'current_mA','Phi1'};
for i = 1:numel(reqP)
    if ~ismember(reqP{i}, phi1Tbl.Properties.VariableNames)
        error('run_switching_stage_e5_mode_order_sufficiency:BadPhi1Schema', 'switching_canonical_phi1.csv missing %s', reqP{i});
    end
end
reqA = {'T_K','kappa1','kappa2'};
for i = 1:numel(reqA)
    if ~ismember(reqA{i}, ampTbl.Properties.VariableNames)
        error('run_switching_stage_e5_mode_order_sufficiency:BadAmpSchema', 'switching_mode_amplitudes_vs_T.csv missing %s', reqA{i});
    end
end

T = double(sLong.T_K);
I = double(sLong.current_mA);
S = double(sLong.S_percent);
B = double(sLong.S_model_pt_percent);
C = double(sLong.CDF_pt);
v = isfinite(T) & isfinite(I) & isfinite(S) & isfinite(B) & isfinite(C);
G = groupsummary(table(T(v), I(v), S(v), B(v), C(v)), {'Var1','Var2'}, 'mean', {'Var3','Var4','Var5'});

allT = unique(double(G.Var1), 'sorted');
allI = unique(double(G.Var2), 'sorted');
nT = numel(allT);
nI = numel(allI);
Smap = NaN(nT, nI);
Bmap = NaN(nT, nI);
Cmap = NaN(nT, nI);
for it = 1:nT
    for ii = 1:nI
        m = abs(double(G.Var1) - allT(it)) < 1e-9 & abs(double(G.Var2) - allI(ii)) < 1e-9;
        if any(m)
            j = find(m, 1);
            Smap(it, ii) = double(G.mean_Var3(j));
            Bmap(it, ii) = double(G.mean_Var4(j));
            Cmap(it, ii) = double(G.mean_Var5(j));
        end
    end
end

phiI = double(phi1Tbl.current_mA);
phiV = double(phi1Tbl.Phi1);
pv = isfinite(phiI) & isfinite(phiV);
Pg = groupsummary(table(phiI(pv), phiV(pv)), {'Var1'}, 'mean', {'Var2'});
phi1Vec = interp1(double(Pg.Var1), double(Pg.mean_Var2), allI, 'linear', NaN)';
phi1Vec = fillmissing(phi1Vec, 'linear', 'EndValues', 'nearest');
if norm(phi1Vec) > 0
    phi1Vec = phi1Vec / norm(phi1Vec);
end

kappa1 = interp1(double(ampTbl.T_K), double(ampTbl.kappa1), allT, 'linear', NaN);
kappa2 = interp1(double(ampTbl.T_K), double(ampTbl.kappa2), allT, 'linear', NaN);
kappa1 = fillmissing(kappa1, 'linear', 'EndValues', 'nearest');
kappa2 = fillmissing(kappa2, 'linear', 'EndValues', 'nearest');
if ismember('kappa3', ampTbl.Properties.VariableNames)
    kappa3Producer = interp1(double(ampTbl.T_K), double(ampTbl.kappa3), allT, 'linear', NaN);
    kappa3Producer = fillmissing(kappa3Producer, 'linear', 'EndValues', 'nearest');
else
    kappa3Producer = NaN(size(allT));
end
if ismember('regime_label', ampTbl.Properties.VariableNames)
    regimeTbl = ampTbl(:, {'T_K','regime_label'});
    regimeTbl = sortrows(regimeTbl, 'T_K');
    regimeLabel = strings(nT, 1);
    for it = 1:nT
        idx = find(abs(double(regimeTbl.T_K) - allT(it)) < 1e-9, 1);
        if isempty(idx)
            regimeLabel(it) = "unlabeled";
        else
            regimeLabel(it) = string(regimeTbl.regime_label(idx));
        end
    end
else
    regimeLabel = repmat("unlabeled", nT, 1);
end
if ismember('transition_flag', ampTbl.Properties.VariableNames)
    transitionTbl = ampTbl(:, {'T_K','transition_flag'});
    transitionTbl = sortrows(transitionTbl, 'T_K');
    transitionFlag = strings(nT, 1);
    for it = 1:nT
        idx = find(abs(double(transitionTbl.T_K) - allT(it)) < 1e-9, 1);
        if isempty(idx)
            transitionFlag(it) = "NO";
        else
            transitionFlag(it) = string(transitionTbl.transition_flag(idx));
        end
    end
else
    transitionFlag = repmat("NO", nT, 1);
end

validMap = isfinite(Smap) & isfinite(Bmap);
cdfAxis = mean(Cmap, 1, 'omitnan');
tailMask = cdfAxis >= 0.80;
if ~any(tailMask)
    tailMask = false(1, nI);
    tailMask(max(nI-1,1):nI) = true;
end

data = struct();
data.allT = allT(:);
data.allI = allI(:);
data.Smap = Smap;
data.Bmap = Bmap;
data.Cmap = Cmap;
data.validMap = validMap;
data.cdfAxis = cdfAxis(:)';
data.tailMask = logical(tailMask(:)');
data.phi1Vec = phi1Vec(:);
data.kappa1 = kappa1(:);
data.kappa2 = kappa2(:);
data.kappa3Producer = kappa3Producer(:);
data.regimeLabel = regimeLabel(:);
data.transitionFlag = transitionFlag(:);
end

function hierarchy = buildHierarchy(data)
pred0 = data.Bmap;
pred1 = pred0 - data.kappa1(:) * data.phi1Vec(:)';
R0 = data.Smap - pred0;
R1 = data.Smap - pred1;
R1z = R1;
R1z(~isfinite(R1z)) = 0;
[~, ~, V1] = svd(R1z, 'econ');
if isempty(V1)
    phi2 = zeros(numel(data.allI), 1);
else
    phi2 = V1(:, 1);
end
if norm(phi2) > 0
    phi2 = phi2 / norm(phi2);
end
pred2 = pred1 + data.kappa2(:) * phi2(:)';
R2 = data.Smap - pred2;
R2z = R2;
R2z(~isfinite(R2z)) = 0;
[~, S2, V2] = svd(R2z, 'econ');
if isempty(V2)
    phi3 = zeros(numel(data.allI), 1);
else
    phi3 = V2(:, 1);
end
if norm(phi3) > 0
    phi3 = phi3 / norm(phi3);
end
kappa3Diag = R2z * phi3;
pred3 = pred2 + kappa3Diag(:) * phi3(:)';
R3 = data.Smap - pred3;

R0z = R0;
R0z(~isfinite(R0z)) = 0;
[~, S0, V0] = svd(R0z, 'econ');
[~, S1, ~] = svd(R1z, 'econ');
[~, S3, ~] = svd(fillResidual(R3), 'econ');

hierarchy = struct();
hierarchy.pred0 = pred0;
hierarchy.pred1 = pred1;
hierarchy.pred2 = pred2;
hierarchy.pred3 = pred3;
hierarchy.R0 = R0;
hierarchy.R1 = R1;
hierarchy.R2 = R2;
hierarchy.R3 = R3;
hierarchy.R0z = R0z;
hierarchy.R1z = R1z;
hierarchy.R2z = R2z;
hierarchy.R3z = fillResidual(R3);
hierarchy.mode1Ref = firstModeFromV(V0, numel(data.allI));
hierarchy.phi2Vec = phi2(:);
hierarchy.phi3Vec = phi3(:);
hierarchy.kappa3Diag = kappa3Diag(:);
hierarchy.svd0 = diag(S0);
hierarchy.svd1 = diag(S1);
hierarchy.svd2 = diag(S2);
hierarchy.svd3 = diag(S3);
end

function out = fillResidual(R)
out = R;
out(~isfinite(out)) = 0;
end

function mode = firstModeFromV(V, nI)
if isempty(V)
    mode = zeros(nI, 1);
else
    mode = V(:, 1);
end
if norm(mode) > 0
    mode = mode / norm(mode);
end
end

function out = permutationNullSummary(R, nPerm)
obs = svd(R, 'econ');
nMode = size(R, 2);
nullSigma = NaN(nPerm, nMode);
for ip = 1:nPerm
    Rp = zeros(size(R));
    for it = 1:size(R,1)
        Rp(it, :) = R(it, randperm(size(R,2)));
    end
    nullSigma(ip, :) = svd(Rp, 'econ')';
end
obs = padVector(obs(:), nMode);
nullMean = mean(nullSigma, 1, 'omitnan')';
nullStd = std(nullSigma, 0, 1, 'omitnan')';
nullP95 = prctile(nullSigma, 95, 1)';
pValue = NaN(nMode, 1);
for i = 1:nMode
    pValue(i) = (1 + sum(nullSigma(:, i) >= obs(i))) / (size(nullSigma, 1) + 1);
end
energy = obs.^2;
energyTotal = sum(energy);
if energyTotal <= 0
    energyTotal = eps;
end
energyFrac = energy / energyTotal;
cumFrac = cumsum(energyFrac);

out = struct();
out.obsSigma = obs(:);
out.energyFrac = energyFrac(:);
out.cumFrac = cumFrac(:);
out.nullMean = nullMean(:);
out.nullStd = nullStd(:);
out.nullP95 = nullP95(:);
out.pValue = pValue(:);
end

function tbl = buildSpectrumTable(nullR0, nullR1, nullR2, hierarchy)
stages = { ...
    "after_backbone", nullR0; ...
    "after_phi1", nullR1; ...
    "after_phi2", nullR2};
rows = table();
for is = 1:size(stages,1)
    stageName = stages{is,1};
    info = stages{is,2};
    nMode = numel(info.obsSigma);
    detail = repmat("", nMode, 1);
    if stageName == "after_phi2" && nMode >= 1
        detail(1) = "Diagnostic Phi3 candidate corresponds to mode_rank=1 of the after_phi2 residual.";
    end
    rows = [rows; table( ...
        repmat(stageName, nMode, 1), ...
        (1:nMode)', ...
        info.obsSigma(:), ...
        info.energyFrac(:), ...
        info.cumFrac(:), ...
        info.nullMean(:), ...
        info.nullStd(:), ...
        info.nullP95(:), ...
        info.pValue(:), ...
        detail, ...
        'VariableNames', {'residual_stage','mode_rank','singular_value','energy_fraction','cumulative_energy_fraction','null_mean','null_std','null_p95','p_value','detail'})]; %#ok<AGROW>
end

rows = [rows; table( ...
    "after_phi3_diag", 0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    string(sprintf('Residual RMS after diagnostic Phi3 = %.6g', sqrt(mean(hierarchy.R3z(:).^2, 'omitnan')))), ...
    'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
tbl = rows;
end

function domains = buildReconstructionDomains(data)
nI = numel(data.allI);
rankIdx = 1:nI;
domains = struct('name', {}, 'mask', {}, 'detail', {});
domains(end+1) = makeDomain("full", true(1, nI), "Full canonical current domain.");
domains(end+1) = makeDomain("low_1_3", ismember(rankIdx, [1 2 3]), "D4 low-rank window.");
domains(end+1) = makeDomain("mid_3_5", ismember(rankIdx, [3 4 5]), "D4 mid-rank window.");
domains(end+1) = makeDomain("high_5_7", ismember(rankIdx, [5 6 7]), "D4 high-rank window.");
domains(end+1) = makeDomain("win_1_3", ismember(rankIdx, [1 2 3]), "D4 sliding window 1:3.");
domains(end+1) = makeDomain("win_2_4", ismember(rankIdx, [2 3 4]), "D4 sliding window 2:4.");
domains(end+1) = makeDomain("win_3_5", ismember(rankIdx, [3 4 5]), "D4 sliding window 3:5.");
domains(end+1) = makeDomain("win_4_6", ismember(rankIdx, [4 5 6]), "D4 sliding window 4:6.");
domains(end+1) = makeDomain("win_5_7", ismember(rankIdx, [5 6 7]), "D4 sliding window 5:7.");
domains(end+1) = makeDomain("tail_cdf_ge_0p80", data.tailMask, "Canonical tail region from mean CDF_pt >= 0.80.");
end

function domain = makeDomain(name, mask, detail)
domain = struct('name', string(name), 'mask', logical(mask(:)'), 'detail', string(detail));
end

function tbl = buildReconstructionHierarchyTable(data, hierarchy, domains)
models = { ...
    "backbone", hierarchy.pred0; ...
    "backbone_phi1", hierarchy.pred1; ...
    "backbone_phi1_phi2", hierarchy.pred2; ...
    "backbone_phi1_phi2_phi3_diag", hierarchy.pred3};
prevPred = [];
rows = table();
for im = 1:size(models,1)
    modelName = models{im,1};
    pred = models{im,2};
    for id = 1:numel(domains)
        mask = domains(id).mask;
        metric = computeDomainMetric(data.Smap, hierarchy.pred0, pred, prevPred, mask, data.validMap);
        rows = [rows; table( ...
            domains(id).name, modelName, metric.nPoints, metric.rmseGlobal, metric.meanRowRmse, metric.residualEnergy, ...
            metric.residualEnergyFractionVsBackbone, metric.incrementalGain, metric.incrementalGainFraction, ...
            metric.varianceExplainedVsBackbone, domains(id).detail, ...
            'VariableNames', {'domain_name','model_label','n_points','rmse_global','mean_row_rmse','residual_energy','residual_energy_fraction_vs_backbone','incremental_rmse_gain_vs_prev','incremental_rmse_gain_vs_prev_fraction','variance_explained_vs_backbone','detail'})]; %#ok<AGROW>
    end
    prevPred = pred;
end
tbl = rows;
end

function metric = computeDomainMetric(Smap, backbonePred, pred, prevPred, colMask, validMap)
mask = validMap & repmat(logical(colMask(:))', size(Smap,1), 1);
residual = Smap - pred;
residual0 = Smap - backbonePred;
nPoints = sum(mask(:));
if nPoints == 0
    metric = struct('nPoints', 0, 'rmseGlobal', NaN, 'meanRowRmse', NaN, 'residualEnergy', NaN, ...
        'residualEnergyFractionVsBackbone', NaN, 'incrementalGain', NaN, 'incrementalGainFraction', NaN, ...
        'varianceExplainedVsBackbone', NaN);
    return;
end
err = residual(mask);
err0 = residual0(mask);
rmseGlobal = sqrt(mean(err.^2, 'omitnan'));
residualEnergy = sum(err.^2, 'omitnan');
backboneEnergy = sum(err0.^2, 'omitnan');
if backboneEnergy <= 0
    backboneEnergy = eps;
end
rowRmse = rowRmseOnMask(residual, mask);
meanRowRmse = mean(rowRmse, 'omitnan');
if isempty(prevPred)
    incrementalGain = NaN;
    incrementalGainFraction = NaN;
else
    prevErr = Smap - prevPred;
    prevRmse = sqrt(mean(prevErr(mask).^2, 'omitnan'));
    incrementalGain = prevRmse - rmseGlobal;
    if prevRmse > 0
        incrementalGainFraction = incrementalGain / prevRmse;
    else
        incrementalGainFraction = NaN;
    end
end
metric = struct();
metric.nPoints = nPoints;
metric.rmseGlobal = rmseGlobal;
metric.meanRowRmse = meanRowRmse;
metric.residualEnergy = residualEnergy;
metric.residualEnergyFractionVsBackbone = residualEnergy / backboneEnergy;
metric.incrementalGain = incrementalGain;
metric.incrementalGainFraction = incrementalGainFraction;
metric.varianceExplainedVsBackbone = 1 - residualEnergy / backboneEnergy;
end

function rowRmse = rowRmseOnMask(residual, mask)
rowRmse = NaN(size(residual, 1), 1);
for it = 1:size(residual, 1)
    m = mask(it, :);
    if any(m)
        vals = residual(it, m);
        rowRmse(it) = sqrt(mean(vals.^2, 'omitnan'));
    end
end
end

function tbl = buildObservableJoin(obsTbl, hierarchy, data)
reqObs = {'T_K','S_peak','I_peak'};
for i = 1:numel(reqObs)
    if ~ismember(reqObs{i}, obsTbl.Properties.VariableNames)
        error('run_switching_stage_e5_mode_order_sufficiency:BadObservableSchema', 'switching_canonical_observables.csv missing %s', reqObs{i});
    end
end

midMask = data.cdfAxis > 0.40 & data.cdfAxis < 0.60;
if ~any(midMask)
    midMask = ismember(1:numel(data.allI), [3 4 5]);
end
tailBurden0 = mean(hierarchy.R0(:, data.tailMask).^2, 2, 'omitnan') ./ max(mean(hierarchy.R0(:, midMask).^2, 2, 'omitnan'), eps);
tailBurden2 = mean(hierarchy.R2(:, data.tailMask).^2, 2, 'omitnan') ./ max(mean(hierarchy.R2(:, midMask).^2, 2, 'omitnan'), eps);
globalResidual2 = mean(hierarchy.R2.^2, 2, 'omitnan');
peakResidual2 = max(abs(hierarchy.R2), [], 2, 'omitnan');
globalResidual3 = mean(hierarchy.R3.^2, 2, 'omitnan');

J = table(data.allT(:), tailBurden0(:), tailBurden2(:), globalResidual2(:), peakResidual2(:), globalResidual3(:), ...
    hierarchy.kappa3Diag(:), data.kappa3Producer(:), data.kappa1(:), data.kappa2(:), data.regimeLabel(:), data.transitionFlag(:), ...
    'VariableNames', {'T_K','tail_burden_backbone','tail_burden_after_phi2','global_residual_after_phi2','peak_residual_after_phi2','global_residual_after_phi3','kappa3_diag','kappa3_producer','kappa1','kappa2','regime_label','transition_flag'});
O = groupsummary(obsTbl, 'T_K', 'mean', setdiff(obsTbl.Properties.VariableNames, {'T_K'}));
O.Properties.VariableNames = strrep(O.Properties.VariableNames, 'mean_', '');
tbl = outerjoin(J, O, 'Keys', 'T_K', 'MergeKeys', true);
tbl = sortrows(tbl, 'T_K');
end

function tbl = buildResidualStructureTable(data, hierarchy, observableTbl, nullR2, reconTbl, domains)
rows = table();

rank3Sigma = nullR2.obsSigma(1);
rank3Energy = nullR2.energyFrac(1);
rank3SigmaP = nullR2.pValue(1);
rank3Sigma95 = nullR2.nullP95(1);
rank3GainFull = pickReconMetric(reconTbl, "full", "backbone_phi1_phi2_phi3_diag", "incremental_rmse_gain_vs_prev_fraction");
rank3GainHigh = pickReconMetric(reconTbl, "high_5_7", "backbone_phi1_phi2_phi3_diag", "incremental_rmse_gain_vs_prev_fraction");

gainNull = rank3GainNullDistribution(data, hierarchy, domains, 500);
gainNullP = (1 + sum(gainNull >= rank3GainFull)) / (numel(gainNull) + 1);
gainNullMean = mean(gainNull, 'omitnan');
gainNull95 = prctile(gainNull, 95);

rows = [rows; makeResidualRow("rank3_significance", "sigma1_after_phi2", "full", rank3Sigma, nullR2.nullMean(1), rank3Sigma95, rank3SigmaP, classifyP(rank3SigmaP), ...
    "Top singular value of the level-2 residual.")]; %#ok<AGROW>
rows = [rows; makeResidualRow("rank3_significance", "energy_fraction_after_phi2_mode1", "full", rank3Energy, NaN, NaN, NaN, classifyEffect(rank3Energy, [0.05 0.10]), ...
    "Energy fraction carried by the diagnostic Phi3 candidate within the after-phi2 residual.")]; %#ok<AGROW>
rows = [rows; makeResidualRow("rank3_significance", "rmse_gain_fraction_after_phi2_full", "full", rank3GainFull, gainNullMean, gainNull95, gainNullP, classifyP(gainNullP), ...
    "Full-domain incremental RMSE gain from adding the diagnostic Phi3 layer.")]; %#ok<AGROW>
rows = [rows; makeResidualRow("rank3_significance", "rmse_gain_fraction_after_phi2_high_5_7", "high_5_7", rank3GainHigh, NaN, NaN, NaN, classifyEffect(rank3GainHigh, [0.10 0.20]), ...
    "High-rank D4 window incremental RMSE gain from the diagnostic Phi3 layer.")]; %#ok<AGROW>

phi3Energy = hierarchy.phi3Vec(:).^2;
windowNull = localizationNullDistribution(hierarchy.R2z, size(hierarchy.R2z,2), 500);
for id = 1:numel(domains)
    mask = domains(id).mask;
    eFrac = sum(phi3Energy(mask)) / max(sum(phi3Energy), eps);
    if isfield(windowNull, char(domains(id).name))
        nullVals = windowNull.(char(domains(id).name));
        pVal = (1 + sum(nullVals >= eFrac)) / (numel(nullVals) + 1);
        nullMean = mean(nullVals, 'omitnan');
        null95 = prctile(nullVals, 95);
    else
        pVal = NaN; nullMean = NaN; null95 = NaN;
    end
    rows = [rows; makeResidualRow("rank3_localization", "phi3_energy_fraction", domains(id).name, eFrac, nullMean, null95, pVal, classifyLocalization(eFrac, pVal), domains(id).detail)]; %#ok<AGROW>
end

tvObserved = sum(abs(diff(hierarchy.phi3Vec(:))));
tvNull = phiVectorNullTotalVariation(hierarchy.R2z, 500);
tvP = (1 + sum(tvNull <= tvObserved)) / (numel(tvNull) + 1);
rows = [rows; makeResidualRow("rank3_structure", "phi3_total_variation", "full", tvObserved, mean(tvNull, 'omitnan'), prctile(tvNull, 5), tvP, classifyP(tvP), ...
    "Lower total variation than null indicates smoother structure than randomized residual residue.")]; %#ok<AGROW>

adjCorr = lagOneCorr(hierarchy.kappa3Diag(:));
adjNull = shuffledLagCorr(abs(hierarchy.kappa3Diag(:)), 500);
adjP = (1 + sum(adjNull >= abs(adjCorr))) / (numel(adjNull) + 1);
rows = [rows; makeResidualRow("rank3_structure", "abs_kappa3_lag1_corr", "temperature", abs(adjCorr), mean(adjNull, 'omitnan'), prctile(adjNull, 95), adjP, classifyP(adjP), ...
    "Temperature coherence of diagnostic Phi3 amplitude.")]; %#ok<AGROW>

obsDefs = { ...
    "tail_burden_after_phi2", observableTbl.tail_burden_after_phi2; ...
    "global_residual_after_phi2", observableTbl.global_residual_after_phi2; ...
    "peak_residual_after_phi2", observableTbl.peak_residual_after_phi2; ...
    "S_peak", pickColumn(observableTbl, "S_peak"); ...
    "I_peak", pickColumn(observableTbl, "I_peak"); ...
    "kappa2", observableTbl.kappa2; ...
    "kappa3_producer", observableTbl.kappa3_producer};
for i = 1:size(obsDefs,1)
    targetName = obsDefs{i,1};
    y = obsDefs{i,2};
    [rho, nullAbs, pVal] = shuffledObservableLink(observableTbl.kappa3_diag, y, 500);
    rows = [rows; makeResidualRow("rank3_observable_linkage", targetName, "temperature", rho, mean(nullAbs, 'omitnan'), prctile(nullAbs, 95), pVal, classifyObservable(rho, pVal), ...
        "Spearman linkage between diagnostic Phi3 amplitude and canonical observable/control.")]; %#ok<AGROW>
end

tbl = rows;
end

function values = rank3GainNullDistribution(data, hierarchy, domains, nPerm)
targetMask = [];
for i = 1:numel(domains)
    if domains(i).name == "full"
        targetMask = domains(i).mask;
        break;
    end
end
if isempty(targetMask)
    targetMask = true(1, numel(data.allI));
end
values = NaN(nPerm, 1);
for ip = 1:nPerm
    Rp = zeros(size(hierarchy.R2z));
    for it = 1:size(hierarchy.R2z,1)
        Rp(it, :) = hierarchy.R2z(it, randperm(size(hierarchy.R2z,2)));
    end
    [~, ~, Vp] = svd(Rp, 'econ');
    if isempty(Vp)
        phi = zeros(size(Rp,2),1);
    else
        phi = Vp(:,1);
    end
    if norm(phi) > 0, phi = phi / norm(phi); end
    kp = Rp * phi;
    pred = hierarchy.pred2 + kp(:) * phi(:)';
    metricPrev = computeDomainMetric(data.Smap, hierarchy.pred0, hierarchy.pred2, hierarchy.pred1, targetMask, data.validMap);
    metricNew = computeDomainMetric(data.Smap, hierarchy.pred0, pred, hierarchy.pred2, targetMask, data.validMap);
    values(ip) = metricNew.incrementalGainFraction;
end
end

function out = localizationNullDistribution(R2z, nI, nPerm)
windows = struct();
idx = 1:nI;
windows.full = true(1, nI);
windows.low_1_3 = ismember(idx, [1 2 3]);
windows.mid_3_5 = ismember(idx, [3 4 5]);
windows.high_5_7 = ismember(idx, [5 6 7]);
windows.win_1_3 = ismember(idx, [1 2 3]);
windows.win_2_4 = ismember(idx, [2 3 4]);
windows.win_3_5 = ismember(idx, [3 4 5]);
windows.win_4_6 = ismember(idx, [4 5 6]);
windows.win_5_7 = ismember(idx, [5 6 7]);
if nI >= 2
    windows.tail_cdf_ge_0p80 = false(1, nI);
    windows.tail_cdf_ge_0p80(max(nI-1,1):nI) = true;
else
    windows.tail_cdf_ge_0p80 = true(1, nI);
end

fields = fieldnames(windows);
for i = 1:numel(fields)
    out.(fields{i}) = NaN(nPerm, 1);
end
for ip = 1:nPerm
    Rp = zeros(size(R2z));
    for it = 1:size(R2z,1)
        Rp(it, :) = R2z(it, randperm(size(R2z,2)));
    end
    [~, ~, Vp] = svd(Rp, 'econ');
    if isempty(Vp)
        phi = zeros(nI,1);
    else
        phi = Vp(:,1);
    end
    if norm(phi) > 0, phi = phi / norm(phi); end
    e = phi(:).^2;
    for i = 1:numel(fields)
        m = windows.(fields{i});
        out.(fields{i})(ip) = sum(e(m)) / max(sum(e), eps);
    end
end
end

function tv = phiVectorNullTotalVariation(R2z, nPerm)
tv = NaN(nPerm, 1);
for ip = 1:nPerm
    Rp = zeros(size(R2z));
    for it = 1:size(R2z,1)
        Rp(it, :) = R2z(it, randperm(size(R2z,2)));
    end
    [~, ~, Vp] = svd(Rp, 'econ');
    if isempty(Vp)
        phi = zeros(size(R2z,2),1);
    else
        phi = Vp(:,1);
    end
    if norm(phi) > 0, phi = phi / norm(phi); end
    tv(ip) = sum(abs(diff(phi(:))));
end
end

function tbl = makeResidualRow(group, metric, domain, observed, nullMean, nullP95, pValue, verdict, detail)
tbl = table(string(group), string(metric), string(domain), observed, nullMean, nullP95, pValue, string(verdict), string(detail), ...
    'VariableNames', {'analysis_group','metric_name','domain_name','observed_value','null_mean','null_p95','p_value','verdict','detail'});
end

function verdict = classifyP(pValue)
if ~isfinite(pValue)
    verdict = "UNSCORED";
elseif pValue <= 0.05
    verdict = "YES";
elseif pValue <= 0.10
    verdict = "PARTIAL";
else
    verdict = "NO";
end
end

function verdict = classifyEffect(value, thresholds)
if ~isfinite(value)
    verdict = "UNSCORED";
elseif value >= thresholds(2)
    verdict = "YES";
elseif value >= thresholds(1)
    verdict = "PARTIAL";
else
    verdict = "NO";
end
end

function verdict = classifyLocalization(value, pValue)
if ~isfinite(value)
    verdict = "UNSCORED";
elseif value >= 0.50 && isfinite(pValue) && pValue <= 0.05
    verdict = "YES";
elseif value >= 0.35 && (~isfinite(pValue) || pValue <= 0.10)
    verdict = "PARTIAL";
else
    verdict = "NO";
end
end

function verdict = classifyObservable(rho, pValue)
if ~isfinite(rho)
    verdict = "UNSCORED";
elseif abs(rho) >= 0.60 && isfinite(pValue) && pValue <= 0.05
    verdict = "YES";
elseif abs(rho) >= 0.40 && (~isfinite(pValue) || pValue <= 0.10)
    verdict = "PARTIAL";
else
    verdict = "NO";
end
end

function [rho, nullAbs, pValue] = shuffledObservableLink(x, y, nPerm)
x = double(x(:));
y = double(y(:));
rho = safeSpearman(x, y);
nullAbs = NaN(nPerm, 1);
for ip = 1:nPerm
    idx = randperm(numel(y));
    nullAbs(ip) = abs(safeSpearman(x, y(idx)));
end
if isfinite(rho)
    pValue = (1 + sum(nullAbs >= abs(rho))) / (numel(nullAbs) + 1);
else
    pValue = NaN;
end
end

function c = safeSpearman(x, y)
mask = isfinite(x) & isfinite(y);
if sum(mask) < 4
    c = NaN;
    return;
end
c = corr(x(mask), y(mask), 'Type', 'Spearman', 'Rows', 'complete');
end

function value = lagOneCorr(x)
x = double(x(:));
mask = isfinite(x);
x = x(mask);
if numel(x) < 4
    value = NaN;
    return;
end
value = corr(x(1:end-1), x(2:end), 'Rows', 'complete');
end

function nullVals = shuffledLagCorr(x, nPerm)
x = double(x(:));
x = x(isfinite(x));
nullVals = NaN(nPerm, 1);
if numel(x) < 4
    return;
end
for ip = 1:nPerm
    xp = x(randperm(numel(x)));
    nullVals(ip) = abs(corr(xp(1:end-1), xp(2:end), 'Rows', 'complete'));
end
end

function value = pickColumn(tbl, name)
if ismember(name, tbl.Properties.VariableNames)
    value = tbl.(name);
else
    value = NaN(height(tbl), 1);
end
end

function tbl = buildModeStabilityTable(data, hierarchy)
rows = table();

tasks = { ...
    "phi1", -data.phi1Vec(:), hierarchy.R0, hierarchy.pred0, hierarchy.pred0, data.kappa1(:); ...
    "phi2", hierarchy.phi2Vec(:), hierarchy.R1, hierarchy.pred1, hierarchy.pred1, data.kappa2(:); ...
    "phi3_diag", hierarchy.phi3Vec(:), hierarchy.R2, hierarchy.pred2, hierarchy.pred2, hierarchy.kappa3Diag(:)};

holdouts = buildHoldouts(data);
for itask = 1:size(tasks,1)
    modeId = tasks{itask,1};
    refMode = tasks{itask,2};
    baseResidual = tasks{itask,3};
    predBase = tasks{itask,4};
    comparePred = tasks{itask,5};
    fullAmp = tasks{itask,6};
    absCos = NaN(numel(holdouts), 1);
    signedCos = NaN(numel(holdouts), 1);
    ampCorr = NaN(numel(holdouts), 1);
    for ih = 1:numel(holdouts)
        keepMask = holdouts(ih).keepMask;
        Rsub = baseResidual(keepMask, :);
        Rsubz = fillResidual(Rsub);
        [~, ~, Vsub] = svd(Rsubz, 'econ');
        if isempty(Vsub)
            modeSub = zeros(size(refMode));
        else
            modeSub = Vsub(:, 1);
        end
        if norm(modeSub) > 0, modeSub = modeSub / norm(modeSub); end
        c = dot(refMode, modeSub) / max(norm(refMode) * norm(modeSub), eps);
        if ~isfinite(c), c = NaN; end
        signedCos(ih) = c;
        absCos(ih) = abs(c);
        if isfinite(c) && c < 0
            modeSub = -modeSub;
        end
        ampSub = Rsubz * modeSub;
        fullAmpSub = fullAmp(keepMask);
        ampCorr(ih) = corrWithMin(fullAmpSub, ampSub, 4);
    end
    medCos = median(absCos, 'omitnan');
    minCos = min(absCos, [], 'omitnan');
    maxCos = max(absCos, [], 'omitnan');
    medAmp = median(ampCorr, 'omitnan');
    for ih = 1:numel(holdouts)
        rows = [rows; table( ...
            repmat(string(modeId), 2, 1), ...
            repmat(holdouts(ih).type, 2, 1), ...
            repmat(holdouts(ih).label, 2, 1), ...
            ["abs_cosine_to_full_mode";"aligned_amplitude_corr"], ...
            [absCos(ih); ampCorr(ih)], ...
            [medCos; medAmp], ...
            [minCos; min(ampCorr, [], 'omitnan')], ...
            [maxCos; max(ampCorr, [], 'omitnan')], ...
            repmat(holdouts(ih).detail, 2, 1), ...
            'VariableNames', {'mode_id','holdout_type','holdout_label','metric_name','observed_value','aggregate_median','aggregate_min','aggregate_max','detail'})]; %#ok<AGROW>
    end
end

tbl = rows;
end

function holdouts = buildHoldouts(data)
nT = numel(data.allT);
holdouts = struct('type', {}, 'label', {}, 'keepMask', {}, 'detail', {});
for i = 1:nT
    keep = true(nT, 1);
    keep(i) = false;
    holdouts(end+1) = struct( ... %#ok<AGROW>
        'type', "leave_one_temperature_out", ...
        'label', string(sprintf('omit_%gK', data.allT(i))), ...
        'keepMask', keep, ...
        'detail', string(sprintf('Leave-one-temperature-out excluding T=%.6g K.', data.allT(i))));
    end

    preMask = data.transitionFlag ~= "YES";
    if sum(preMask) >= 4
        holdouts(end+1) = struct( ... %#ok<AGROW>
            'type', "subset_exclusion", ...
            'label', "exclude_transition", ...
            'keepMask', preMask, ...
            'detail', "Subset fit excluding transition-flagged temperatures.");
    end
    transMask = data.transitionFlag == "YES";
    if sum(transMask) >= 4
        holdouts(end+1) = struct( ... %#ok<AGROW>
            'type', "subset_exclusion", ...
            'label', "exclude_pretransition", ...
            'keepMask', transMask, ...
            'detail', "Subset fit using transition-flagged temperatures only.");
    end
end

function c = corrWithMin(x, y, minN)
mask = isfinite(x) & isfinite(y);
if sum(mask) < minN
    c = NaN;
else
    c = corr(x(mask), y(mask), 'Rows', 'complete');
end
end

function value = pickReconMetric(tbl, domainName, modelLabel, varName)
m = tbl.domain_name == string(domainName) & tbl.model_label == string(modelLabel);
if ~any(m)
    value = NaN;
else
    vals = tbl.(varName);
    value = vals(find(m, 1));
end
end

function value = pickResidualMetric(tbl, groupName, metricName, varName, domainName)
m = tbl.analysis_group == string(groupName) & tbl.metric_name == string(metricName);
if nargin >= 5
    m = m & tbl.domain_name == string(domainName);
end
if ~any(m)
    value = NaN;
else
    vals = tbl.(varName);
    value = vals(find(m, 1));
end
end

function value = pickStabilityAggregate(tbl, modeId, holdoutType, metricName, aggField)
m = tbl.mode_id == string(modeId) & tbl.holdout_type == string(holdoutType) & tbl.metric_name == string(metricName);
if ~any(m)
    value = NaN;
else
    vals = tbl.(sprintf('aggregate_%s', aggField));
    value = vals(find(m, 1));
end
end

function out = padVector(x, n)
out = zeros(n, 1);
if isempty(x)
    return;
end
m = min(numel(x), n);
out(1:m) = x(1:m);
end
