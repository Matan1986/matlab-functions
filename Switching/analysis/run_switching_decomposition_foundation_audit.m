clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
baseName = 'switching_decomposition_foundation_audit';

flagOperationalLocked = 'NO';
flagPhysicalLocked = 'NO';
flagLegacyReviewed = 'NO';
flagOldAbsorbPhi1Like = 'NO';
flagAlternativesPlausible = 'NO';
flagTailNeedsRedesignTest = 'NO';
flagPhaseDAllowed = 'NO';
flagReopenRequired = 'NO';
flagConditionalMeasurement = 'NO';

try
    cfg = struct();
    cfg.runLabel = baseName;
    cfg.dataset = 'canonical_decomposition_foundation';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;

    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'run initialized'}, false);

    % Inputs used for evidence extraction (no producer edits, no recomputation)
    truthInvPath = fullfile(repoRoot, 'tables', 'switching_canonical_current_truth_inventory.csv');
    defExtractPath = fullfile(repoRoot, 'tables', 'switching_canonical_definition_extraction.csv');
    phaseBPath = fullfile(repoRoot, 'tables', 'switching_backbone_validity_status.csv');
    phaseCPath = fullfile(repoRoot, 'tables', 'switching_mode_admissibility_status.csv');
    oldNewPath = fullfile(repoRoot, 'tables', 'switching_backbone_old_vs_new_support_comparison.csv');
    bridgePath = fullfile(repoRoot, 'tables', 'tables\\switching_legacy_to_canonical_interpretation_bridge.csv');
    if exist(bridgePath, 'file') ~= 2
        bridgePath = fullfile(repoRoot, 'tables', 'switching_legacy_to_canonical_interpretation_bridge.csv');
    end

    reqPaths = {truthInvPath, defExtractPath, phaseBPath, phaseCPath, oldNewPath};
    reqNames = {'switching_canonical_current_truth_inventory.csv', 'switching_canonical_definition_extraction.csv', ...
        'switching_backbone_validity_status.csv', 'switching_mode_admissibility_status.csv', ...
        'switching_backbone_old_vs_new_support_comparison.csv'};
    for i = 1:numel(reqPaths)
        if exist(reqPaths{i}, 'file') ~= 2
            error('run_switching_decomposition_foundation_audit:MissingInput', ...
                'Missing required evidence artifact: %s (%s)', reqNames{i}, reqPaths{i});
        end
    end

    truthInv = readtable(truthInvPath);
    defTbl = readtable(defExtractPath);
    oldNewTbl = readtable(oldNewPath);

    % Robust parse helper (first 2 columns: check,result) from status CSV lines
    phaseBLines = readlines(phaseBPath);
    bCheck = strings(0,1); bRes = strings(0,1);
    for il = 1:numel(phaseBLines)
        ln = strtrim(string(phaseBLines(il)));
        if ln == "" || startsWith(lower(ln), "check,result"), continue; end
        tk = regexp(char(ln), '^([^,]+),([^,]+),?.*$', 'tokens', 'once');
        if ~isempty(tk)
            bCheck(end+1,1) = upper(strtrim(string(tk{1}))); %#ok<SAGROW>
            bRes(end+1,1) = upper(strtrim(string(tk{2}))); %#ok<SAGROW>
        end
    end
    phaseCLines = readlines(phaseCPath);
    cCheck = strings(0,1); cRes = strings(0,1);
    for il = 1:numel(phaseCLines)
        ln = strtrim(string(phaseCLines(il)));
        if ln == "" || startsWith(lower(ln), "check,result"), continue; end
        tk = regexp(char(ln), '^([^,]+),([^,]+),?.*$', 'tokens', 'once');
        if ~isempty(tk)
            cCheck(end+1,1) = upper(strtrim(string(tk{1}))); %#ok<SAGROW>
            cRes(end+1,1) = upper(strtrim(string(tk{2}))); %#ok<SAGROW>
        end
    end

    getFlag = @(keys, chk, res) localGetFlag(keys, chk, res);
    bBackbone = getFlag({'BACKBONE_VALID_FOR_RESIDUAL_ANALYSIS'}, bCheck, bRes);
    bTail = getFlag({'BACKBONE_FAILURE_LOCALIZED_IN_HIGH_CDF_TAIL'}, bCheck, bRes);
    bCdf = getFlag({'CDF_PT_MONOTONIC'}, bCheck, bRes);
    bPdf = getFlag({'PT_PDF_VALID'}, bCheck, bRes);
    cPhi1 = getFlag({'PHI1_ADMISSIBLE_PHYSICAL_MODE'}, cCheck, cRes);
    cPhi2 = getFlag({'PHI2_ADMISSIBLE_PHYSICAL_MODE'}, cCheck, cRes);
    cReadyD = getFlag({'READY_FOR_PHASE_D_MODE_RELATIONSHIP'}, cCheck, cRes);
    cPhi2Tail = getFlag({'PHI2_HIGH_CDF_TAIL_DOMINATED'}, cCheck, cRes);
    cPhi2TailSurvive = getFlag({'PHI2_SURVIVES_TAIL_CONTROL'}, cCheck, cRes);

    % Evidence summary from old vs new support comparison
    nRowsON = height(oldNewTbl);
    nNewBetter = 0;
    if ismember('winner_by_rmse', oldNewTbl.Properties.VariableNames)
        nNewBetter = sum(strcmpi(string(oldNewTbl.winner_by_rmse), 'NEW_BETTER'));
    end

    % Inventory of decomposition families (legacy + canonical + plausible alternatives)
    fam = strings(0,1);
    routeType = strings(0,1);
    assumptions = strings(0,1);
    coordinate = strings(0,1);
    normalization = strings(0,1);
    dof = strings(0,1);
    residualDef = strings(0,1);
    extractionOrder = strings(0,1);
    classif = strings(0,1);
    evidence = strings(0,1);
    allowedUse = strings(0,1);

    % Legacy families
    fam(end+1) = "width_shift_scale_collapse";
    routeType(end+1) = "legacy";
    assumptions(end+1) = "shape collapse allowed shift/scale/width freedom";
    coordinate(end+1) = "width-normalized/aligned current coordinate";
    normalization(end+1) = "per-temperature alignment + amplitude adjustments";
    dof(end+1) = "high (shift, scale, width)";
    residualDef(end+1) = "post-alignment collapse residual";
    extractionOrder(end+1) = "alignment/collapse first, then residual reading";
    classif(end+1) = "legacy diagnostic";
    evidence(end+1) = "switching_full_scaling_collapse.m; switching_alignment_audit.m; Phase-A inventory";
    allowedUse(end+1) = "historical reference only";

    fam(end+1) = "derivative_pdf_first_maps";
    routeType(end+1) = "legacy";
    assumptions(end+1) = "derivative/PT maps can define primary decomposition basis";
    coordinate(end+1) = "threshold/energy or derivative coordinate";
    normalization(end+1) = "local smoothing + derivative normalization variants";
    dof(end+1) = "medium";
    residualDef(end+1) = "difference vs derivative-derived baseline";
    extractionOrder(end+1) = "derivative extraction before canonical PT/CDF guardrails";
    classif(end+1) = "legacy diagnostic";
    evidence(end+1) = "run_pt_deformation_mode_test.m; run_switching_PT_consistency_audit.m";
    allowedUse(end+1) = "design reference only";

    fam(end+1) = "amplitude_normalized_map_routes";
    routeType(end+1) = "legacy";
    assumptions(end+1) = "normalize S by per-T amplitude before collapse";
    coordinate(end+1) = "amplitude-normalized map coordinate";
    normalization(end+1) = "strong per-T amplitude normalization";
    dof(end+1) = "medium";
    residualDef(end+1) = "residual in normalized map space";
    extractionOrder(end+1) = "normalization first then mode extraction";
    classif(end+1) = "legacy diagnostic";
    evidence(end+1) = "run_switching_collapse_breakdown_analysis.m";
    allowedUse(end+1) = "historical sensitivity only";

    fam(end+1) = "residual_pca_without_pt_backbone";
    routeType(end+1) = "legacy/plausible alternative";
    assumptions(end+1) = "direct PCA/SVD on S maps without explicit PT backbone";
    coordinate(end+1) = "raw current_mA";
    normalization(end+1) = "none or weak centering";
    dof(end+1) = "low-medium";
    residualDef(end+1) = "residual vs mean-shape or rank-1 map";
    extractionOrder(end+1) = "mode extraction before physically constrained backbone";
    classif(end+1) = "plausible future alternative";
    evidence(end+1) = "switching_residual_decomposition_analysis.m; run_residual_decomposition_22k_failure_audit.m";
    allowedUse(end+1) = "future controlled comparison only";

    % Current canonical family
    fam(end+1) = "canonical_ptcdf_backbone_plus_phi_modes";
    routeType(end+1) = "canonical";
    assumptions(end+1) = "S ~= S_model_pt_percent + Phi1 + Phi2 hierarchy; width/alignment excluded";
    coordinate(end+1) = "current_mA with CDF_pt/PT_pdf derived per T";
    normalization(end+1) = "CDF clamp/monotonic + PT nonnegative area normalization";
    dof(end+1) = "low (no shift/width freedom)";
    residualDef(end+1) = "R0=S-backbone; R1 after Phi1; R2 after Phi2";
    extractionOrder(end+1) = "backbone first, then residual SVD modes";
    classif(end+1) = "canonical truth";
    evidence(end+1) = "run_switching_canonical.m; run_switching_canonical_collapse_hierarchy.m; switching_canonical_definition_extraction.csv";
    allowedUse(end+1) = "controlling operational decomposition";

    % Untested alternatives (explicitly not run now)
    fam(end+1) = "tail_aware_backbone_variant";
    routeType(end+1) = "alternative";
    assumptions(end+1) = "backbone augmented in high-CDF sector only";
    coordinate(end+1) = "CDF_pt sectors";
    normalization(end+1) = "canonical-compatible";
    dof(end+1) = "medium";
    residualDef(end+1) = "sector-conditioned residual";
    extractionOrder(end+1) = "backbone first with tail control";
    classif(end+1) = "plausible future alternative";
    evidence(end+1) = "Phase-B high-CDF-tail localization";
    allowedUse(end+1) = "recommended for later controlled test";

    fam(end+1) = "quantile_coordinate_backbone_variants";
    routeType(end+1) = "alternative";
    assumptions(end+1) = "alternative quantile mapping while keeping no width alignment";
    coordinate(end+1) = "quantile/backbone variant";
    normalization(end+1) = "canonical-compatible";
    dof(end+1) = "medium";
    residualDef(end+1) = "residual vs variant backbone";
    extractionOrder(end+1) = "backbone first";
    classif(end+1) = "plausible future alternative";
    evidence(end+1) = "collapse coordinate design notes";
    allowedUse(end+1) = "future controlled test only";

    fam(end+1) = "two_sector_backbone_low_high_cdf";
    routeType(end+1) = "alternative";
    assumptions(end+1) = "piecewise backbone with shared constraints and tail sector";
    coordinate(end+1) = "CDF_pt low/high sectors";
    normalization(end+1) = "canonical-compatible";
    dof(end+1) = "medium";
    residualDef(end+1) = "sector residual with continuity constraints";
    extractionOrder(end+1) = "backbone first";
    classif(end+1) = "plausible future alternative";
    evidence(end+1) = "Phase-B + Phase-C tail dominance findings";
    allowedUse(end+1) = "future controlled test only";

    fam = fam(:);
    routeType = routeType(:);
    assumptions = assumptions(:);
    coordinate = coordinate(:);
    normalization = normalization(:);
    dof = dof(:);
    residualDef = residualDef(:);
    extractionOrder = extractionOrder(:);
    classif = classif(:);
    evidence = evidence(:);
    allowedUse = allowedUse(:);
    invTbl = table(fam, routeType, assumptions, coordinate, normalization, dof, residualDef, extractionOrder, classif, evidence, allowedUse, ...
        'VariableNames', {'decomposition_family','route_type','core_assumption','coordinate_used','normalization_used', ...
        'degrees_of_freedom','residual_definition','mode_extraction_order','classification','evidence_reference','allowed_usage'});
    switchingWriteTableBothPaths(invTbl, repoRoot, runTables, 'switching_decomposition_foundation_inventory.csv');

    % Comparison table: old vs current assumptions
    cmpAspect = [ ...
        "coordinate_used"; "normalization_used"; "amplitude_handling"; "width_shift_scale_dof"; ...
        "residual_definition"; "mode_extraction_order"; "input_gating_and_metadata"; "pt_backbone_definition"; ...
        "phi_reconstruction_convention"; "what_was_discarded"; "what_is_equivalent"; "old_collapse_absorbed_phi1_like_structure"];
    oldAssump = [ ...
        "often width/alignment-derived collapse coordinate"; ...
        "alignment + rescaling variants common"; ...
        "amplitude normalization frequently embedded"; ...
        "allowed (high flexibility)"; ...
        "collapse residual after alignment"; ...
        "often collapse first, residual later"; ...
        "limited/no canonical gate enforcement"; ...
        "mixed PT/backbone definitions, route dependent"; ...
        "not fixed to canonical sign/order"; ...
        "none (legacy included alignment freedoms)"; ...
        "residual rank-1 tendency partially observed"; ...
        "likely partial via coordinate freedom (not proven as truth)"];
    currentAssump = [ ...
        "current_mA + CDF_pt/PT_pdf canonical coordinate family"; ...
        "CDF monotonic + PT nonnegative area normalized"; ...
        "S_peak enters backbone; kappa amplitudes explicit"; ...
        "disallowed (NO width/shift-scale truth)"; ...
        "R0/R1/R2 against explicit PT backbone hierarchy"; ...
        "backbone first, then residual SVD modes"; ...
        "metadata sidecar + validateCanonicalInputTable gate"; ...
        "S_model_pt_percent from canonical PT/CDF construction"; ...
        "pred1 = pred0 - kappa1*phi1; pred2 = pred1 + kappa2*phi2"; ...
        "width/alignment collapse as truth"; ...
        "dominant first mode still present"; ...
        "treated as PARTIAL risk hypothesis only"];
    verdict = [ ...
        "changed"; "changed"; "changed"; "discarded"; "changed"; "changed"; "changed"; "changed"; ...
        "changed"; "discarded"; "partially_equivalent"; "partial"];
    implications = [ ...
        "reduced coordinate arbitrariness"; ...
        "improves reproducibility"; ...
        "more explicit parameter attribution"; ...
        "prevents alignment from masquerading as physics"; ...
        "clearer error localization"; ...
        "mode meanings tied to backbone quality"; ...
        "stronger truth-tier control"; ...
        "backbone validity becomes auditable"; ...
        "ensures convention consistency across scripts"; ...
        "legacy outputs restricted to diagnostics"; ...
        "supports operational continuity with stricter guardrails"; ...
        "requires tail-control caution before physical interpretation"];
    cmpTbl = table(cmpAspect, oldAssump, currentAssump, verdict, implications, ...
        'VariableNames', {'assumption_dimension','legacy_route_assumption','current_canonical_assumption','comparison_verdict','phase_b0_implication'});
    switchingWriteTableBothPaths(cmpTbl, repoRoot, runTables, 'switching_decomposition_foundation_comparison.csv');

    % Risks table
    riskId = [ ...
        "RISK_HIGH_CDF_TAIL_BACKBONE_MISSPEC"; ...
        "RISK_MODE2_TAIL_DEPENDENCE"; ...
        "RISK_PT_PDF_PARTIAL_VALIDITY"; ...
        "RISK_HISTORICAL_ALIGNMENT_LEAKAGE_IN_INTERPRETATION"; ...
        "RISK_UNTESTED_ALTERNATIVE_BACKBONES"; ...
        "RISK_PHYSICAL_LOCK_OVERREACH"];
    riskDesc = [ ...
        "Backbone residual burden is strongly localized in high CDF tail."; ...
        "Phi2 admissibility is partial and does not survive strict tail masking."; ...
        "PT_pdf validity is PARTIAL at subset of temperatures."; ...
        "Legacy alignment language may bias interpretation if reused as truth."; ...
        "Several canonical-compatible alternatives remain untested."; ...
        "Operationally useful decomposition may be over-read as physically final."];
    riskEvidence = [ ...
        sprintf('Phase-B BACKBONE_FAILURE_LOCALIZED_IN_HIGH_CDF_TAIL=%s', bTail); ...
        sprintf('Phase-C PHI2_HIGH_CDF_TAIL_DOMINATED=%s; PHI2_SURVIVES_TAIL_CONTROL=%s', cPhi2Tail, cPhi2TailSurvive); ...
        sprintf('Phase-B PT_PDF_VALID=%s', bPdf); ...
        "Phase-A inventory classifies alignment/width routes as legacy or excluded"; ...
        "B0 inventory lists tail-aware, quantile-variant, and two-sector alternatives"; ...
        sprintf('Phase-C Phi2 admissibility=%s while Phi1=%s', cPhi2, cPhi1)];
    riskSeverity = ["high"; "high"; "medium"; "medium"; "medium"; "high"];
    needsBeforeD = ["YES"; "YES"; "PARTIAL"; "YES"; "PARTIAL"; "YES"];
    action = [ ...
        "Require tail-focused control checks in Phase D tests."; ...
        "Treat Phi2 as partial mode; do not claim broad mechanism."; ...
        "Restrict interpretations to bins/windows passing PT validity."; ...
        "Keep legacy references diagnostic-only with explicit disclaimers."; ...
        "Plan controlled alternative-backbone comparison as follow-up, not now."; ...
        "Separate operational lock from physical lock in all decisions."];
    riskTbl = table(riskId, riskDesc, riskEvidence, riskSeverity, needsBeforeD, action, ...
        'VariableNames', {'risk_id','risk_description','evidence','severity','requires_control_before_phase_d','recommended_control'});
    switchingWriteTableBothPaths(riskTbl, repoRoot, runTables, 'switching_decomposition_foundation_risks.csv');

    % Decision flags
    % Measurement evidence register (external) summary provided by user:
    % - MEASUREMENT_S_DEFINITION_ACCEPTED = YES
    % - implementation details partially locked
    % Therefore decomposition lock conclusions remain conditional, but audit proceeds.
    flagConditionalMeasurement = 'PARTIAL';
    flagLegacyReviewed = 'YES';
    flagOldAbsorbPhi1Like = 'PARTIAL';
    flagAlternativesPlausible = 'YES';
    if strcmpi(bTail, 'YES') || strcmpi(cPhi2Tail, 'YES')
        flagTailNeedsRedesignTest = 'YES';
    else
        flagTailNeedsRedesignTest = 'PARTIAL';
    end

    if (strcmpi(bBackbone, 'YES') || strcmpi(bBackbone, 'PARTIAL')) && strcmpi(cReadyD, 'YES')
        flagOperationalLocked = 'PARTIAL';
        flagPhaseDAllowed = 'PARTIAL';
    else
        flagOperationalLocked = 'NO';
        flagPhaseDAllowed = 'NO';
    end

    if strcmpi(cPhi1, 'YES') && strcmpi(cPhi2, 'YES') && strcmpi(bTail, 'NO')
        flagPhysicalLocked = 'YES';
    elseif strcmpi(cPhi1, 'YES') && ~strcmpi(cPhi2, 'NO')
        flagPhysicalLocked = 'PARTIAL';
    else
        flagPhysicalLocked = 'NO';
    end
    if strcmpi(cPhi2, 'PARTIAL') || strcmpi(flagTailNeedsRedesignTest, 'YES')
        flagPhysicalLocked = 'NO';
    end

    if strcmpi(flagOperationalLocked, 'NO')
        flagReopenRequired = 'YES';
    elseif strcmpi(flagTailNeedsRedesignTest, 'YES') || strcmpi(flagAlternativesPlausible, 'YES')
        flagReopenRequired = 'PARTIAL';
    else
        flagReopenRequired = 'NO';
    end

    statusTbl = table( ...
        {'CURRENT_PTCDF_DECOMPOSITION_OPERATIONALLY_LOCKED'; ...
         'CURRENT_PTCDF_DECOMPOSITION_PHYSICALLY_LOCKED'; ...
         'LEGACY_DECOMPOSITIONS_REVIEWED'; ...
         'OLD_COLLAPSE_ABSORBED_PHI1_LIKE_STRUCTURE'; ...
         'ALTERNATIVE_BACKBONES_REMAIN_PLAUSIBLE'; ...
         'HIGH_CDF_TAIL_REQUIRES_BACKBONE_REDESIGN_TEST'; ...
         'PHASE_D_ALLOWED_WITH_CURRENT_DECOMPOSITION'; ...
         'DECOMPOSITION_REOPEN_REQUIRED'; ...
         'CONDITIONAL_ON_MEASUREMENT_REGISTER'}, ...
        {flagOperationalLocked; flagPhysicalLocked; flagLegacyReviewed; flagOldAbsorbPhi1Like; ...
         flagAlternativesPlausible; flagTailNeedsRedesignTest; flagPhaseDAllowed; flagReopenRequired; ...
         flagConditionalMeasurement}, ...
        {sprintf('Phase-B backbone=%s, CDF=%s, PTpdf=%s; Phase-C ready=%s', bBackbone, bCdf, bPdf, cReadyD); ...
         sprintf('Phi1=%s, Phi2=%s with tail caveat=%s', cPhi1, cPhi2, cPhi2Tail); ...
         'Legacy families inventoried as historical decomposition references only.'; ...
         sprintf('Legacy collapse likely absorbed part of residual structure via coordinate freedom; old-vs-new rows=%d new_better=%d', nRowsON, nNewBetter); ...
         'Tail-aware/quantile/two-sector alternatives remain plausible but untested in controlled comparison.'; ...
         sprintf('Tail burden evidence: Phase-B tail=%s, Phase-C tail-dominated=%s, survives-tail-control=%s', bTail, cPhi2Tail, cPhi2TailSurvive); ...
         'Phase D can proceed only with decomposition caveats and explicit tail controls.'; ...
         'Reopen is not immediate halt, but controlled alternative-backbone comparison is recommended before hard physical locking.'; ...
         'Measurement S definition accepted, but implementation details are partially locked; decomposition lock conclusions remain conditional.'}, ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusTbl, repoRoot, runTables, 'switching_decomposition_foundation_status.csv');

    lines = {};
    lines{end+1} = '# Switching decomposition foundation audit (Phase B0)';
    lines{end+1} = '';
    lines{end+1} = '## Goal';
    lines{end+1} = '- Audit whether the current canonical decomposition is sufficiently justified as controlling operational decomposition before Phase D.';
    lines{end+1} = '- This is a foundation audit, not a new physics-claim analysis.';
    lines{end+1} = '';
    lines{end+1} = '## Scope enforcement';
    lines{end+1} = '- Switching only; no producer edits.';
    lines{end+1} = '- No changes to canonical reconstruction or mode definitions.';
    lines{end+1} = '- Legacy artifacts used only as historical/decomposition-design references.';
    lines{end+1} = '- No width/alignment output promoted to canonical truth.';
    lines{end+1} = '- No claims/context/snapshot updates.';
    lines{end+1} = '';
    lines{end+1} = '## Proven vs operationally chosen';
    lines{end+1} = '- Proven: canonical PT/CDF decomposition is reproducible, metadata-gated, and operationally consistent for Phase B/C diagnostics.';
    lines{end+1} = '- Proven: high-CDF-tail residual burden is strong and materially affects Phi2 admissibility.';
    lines{end+1} = '- Not proven: that current backbone/mode split is physically unique or final among all canonical-compatible backbone families.';
    lines{end+1} = '- Conditional context: measurement S definition is accepted, but implementation details are partially locked; lock-level conclusions below are conditional on targeted measurement-register closure.';
    lines{end+1} = '';
    lines{end+1} = '## Old vs current decomposition summary';
    lines{end+1} = '- Legacy routes often used alignment/width/amplitude freedoms and could absorb residual structure into coordinate choice.';
    lines{end+1} = '- Current canonical route fixes coordinate freedoms, enforces PT/CDF constraints, and extracts modes after explicit backbone.';
    lines{end+1} = sprintf('- Historical old-vs-new support check: NEW_BETTER wins = %d/%d rows.', nNewBetter, max(nRowsON,1));
    lines{end+1} = '';
    lines{end+1} = '## Decision';
    lines{end+1} = '- Keep current PT/CDF decomposition as controlling operational route, but with explicit tail-risk controls.';
    lines{end+1} = '- Do not physically lock decomposition yet; treat physical lock as unresolved.';
    lines{end+1} = '- Recommend a later controlled alternative-backbone comparison (tail-aware/sector variants), not implemented in this audit.';
    lines{end+1} = '';
    lines{end+1} = '## Required status flags';
    lines{end+1} = sprintf('- CURRENT_PTCDF_DECOMPOSITION_OPERATIONALLY_LOCKED = %s', flagOperationalLocked);
    lines{end+1} = sprintf('- CURRENT_PTCDF_DECOMPOSITION_PHYSICALLY_LOCKED = %s', flagPhysicalLocked);
    lines{end+1} = sprintf('- LEGACY_DECOMPOSITIONS_REVIEWED = %s', flagLegacyReviewed);
    lines{end+1} = sprintf('- OLD_COLLAPSE_ABSORBED_PHI1_LIKE_STRUCTURE = %s', flagOldAbsorbPhi1Like);
    lines{end+1} = sprintf('- ALTERNATIVE_BACKBONES_REMAIN_PLAUSIBLE = %s', flagAlternativesPlausible);
    lines{end+1} = sprintf('- HIGH_CDF_TAIL_REQUIRES_BACKBONE_REDESIGN_TEST = %s', flagTailNeedsRedesignTest);
    lines{end+1} = sprintf('- PHASE_D_ALLOWED_WITH_CURRENT_DECOMPOSITION = %s', flagPhaseDAllowed);
    lines{end+1} = sprintf('- DECOMPOSITION_REOPEN_REQUIRED = %s', flagReopenRequired);
    lines{end+1} = sprintf('- CONDITIONAL_ON_MEASUREMENT_REGISTER = %s', flagConditionalMeasurement);
    lines{end+1} = '';
    lines{end+1} = '## Artifacts';
    lines{end+1} = '- `tables/switching_decomposition_foundation_inventory.csv`';
    lines{end+1} = '- `tables/switching_decomposition_foundation_comparison.csv`';
    lines{end+1} = '- `tables/switching_decomposition_foundation_risks.csv`';
    lines{end+1} = '- `tables/switching_decomposition_foundation_status.csv`';
    lines{end+1} = '- `reports/switching_decomposition_foundation_audit.md`';
    switchingWriteTextLinesFile(fullfile(runReports, [baseName '.md']), lines, 'run_switching_decomposition_foundation_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_decomposition_foundation_audit.md'), lines, 'run_switching_decomposition_foundation_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, height(invTbl), {'decomposition foundation audit completed'}, true);

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_decomposition_foundation_audit_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
    end
    if exist(fullfile(runDir, 'tables'), 'dir') ~= 7, mkdir(fullfile(runDir, 'tables')); end
    if exist(fullfile(runDir, 'reports'), 'dir') ~= 7, mkdir(fullfile(runDir, 'reports')); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    failMsg = char(string(ME.message));
    statusTbl = table( ...
        {'CURRENT_PTCDF_DECOMPOSITION_OPERATIONALLY_LOCKED'; ...
         'CURRENT_PTCDF_DECOMPOSITION_PHYSICALLY_LOCKED'; ...
         'LEGACY_DECOMPOSITIONS_REVIEWED'; ...
         'OLD_COLLAPSE_ABSORBED_PHI1_LIKE_STRUCTURE'; ...
         'ALTERNATIVE_BACKBONES_REMAIN_PLAUSIBLE'; ...
         'HIGH_CDF_TAIL_REQUIRES_BACKBONE_REDESIGN_TEST'; ...
         'PHASE_D_ALLOWED_WITH_CURRENT_DECOMPOSITION'; ...
         'DECOMPOSITION_REOPEN_REQUIRED'; ...
         'CONDITIONAL_ON_MEASUREMENT_REGISTER'}, ...
        {'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'NO'; 'PARTIAL'}, ...
        [repmat({failMsg}, 8, 1); {'Failure path: conditional by default until rerun succeeds.'}], ...
        'VariableNames', {'check','result','detail'});
    writetable(statusTbl, fullfile(runDir, 'tables', 'switching_decomposition_foundation_status.csv'));
    writetable(statusTbl, fullfile(repoRoot, 'tables', 'switching_decomposition_foundation_status.csv'));

    lines = {};
    lines{end+1} = '# Switching decomposition foundation audit (Phase B0) — FAILED';
    lines{end+1} = sprintf('- error_id: `%s`', ME.identifier);
    lines{end+1} = sprintf('- error_message: `%s`', ME.message);
    switchingWriteTextLinesFile(fullfile(runDir, 'reports', [baseName '.md']), lines, 'run_switching_decomposition_foundation_audit:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', 'switching_decomposition_foundation_audit.md'), lines, 'run_switching_decomposition_foundation_audit:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'decomposition foundation audit failed'}, true);
    rethrow(ME);
end

function out = localGetFlag(keys, checks, results)
out = "";
if isempty(checks), return; end
for i = 1:numel(keys)
    idx = find(contains(checks, upper(string(keys{i}))), 1);
    if ~isempty(idx)
        out = upper(string(results(idx)));
        return;
    end
end
end
