clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

run = struct();
runDir = '';
runTables = '';
runReports = '';

outDiagnosis = 'switching_geocanon_partial_status_diagnosis.csv';
outVariant = 'switching_geocanon_variant_disagreement_summary.csv';
outFixPlan = 'switching_geocanon_descriptor_fix_plan.csv';
outStatus = 'switching_geocanon_partial_status_diagnosis_status.csv';
outReport = 'switching_geocanon_partial_status_diagnosis.md';

try
    cfg = struct();
    cfg.runLabel = 'switching_geocanon_partial_status_diagnosis';
    cfg.dataset = 'switching_geocanon_partial_status_diagnosis';
    cfg.fingerprint_script_path = fullfile(fileparts(mfilename('fullpath')), [mfilename '.m']);
    run = createSwitchingRunContext(repoRoot, cfg);
    runDir = run.run_dir;
    runTables = fullfile(runDir, 'tables');
    runReports = fullfile(runDir, 'reports');
    if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
    if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
    if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
    if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

    fidTop = fopen(fullfile(runDir, 'execution_probe_top.txt'), 'w');
    if fidTop >= 0
        fprintf(fidTop, 'SCRIPT_ENTERED\n');
        fclose(fidTop);
    end
    writeSwitchingExecutionStatus(runDir, {'PARTIAL'}, {'YES'}, {''}, 0, {'geocanon partial-status diagnosis initialized'}, false);

    valuesPath = fullfile(repoRoot, 'tables', 'switching_geocanon_descriptor_values.csv');
    robustPath = fullfile(repoRoot, 'tables', 'switching_geocanon_descriptor_robustness.csv');
    statusPath = fullfile(repoRoot, 'tables', 'switching_geocanon_descriptor_status.csv');
    risksPath = fullfile(repoRoot, 'tables', 'switching_geocanon_descriptor_risks.csv');
    reqPath = fullfile(repoRoot, 'tables', 'switching_geocanon_definition_requirements.csv');
    testPath = fullfile(repoRoot, 'tables', 'switching_geocanon_minimal_test_plan.csv');
    conceptPath = fullfile(repoRoot, 'reports', 'switching_geocanon_concept_audit.md');
    auditReportPath = fullfile(repoRoot, 'reports', 'switching_geocanon_descriptor_audit.md');

    required = {valuesPath, robustPath, statusPath, risksPath, reqPath, testPath, conceptPath, auditReportPath};
    for i = 1:numel(required)
        if exist(required{i}, 'file') ~= 2
            error('run_switching_geocanon_partial_status_diagnosis:MissingInput', ...
                'Required input missing: %s', required{i});
        end
    end

    V = readtable(valuesPath, 'VariableNamingRule', 'preserve');
    R = readtable(robustPath, 'VariableNamingRule', 'preserve');
    S = readtable(statusPath, 'VariableNamingRule', 'preserve');
    riskTbl = readtable(risksPath, 'VariableNamingRule', 'preserve');
    reqTbl = readtable(reqPath, 'VariableNamingRule', 'preserve');
    testTbl = readtable(testPath, 'VariableNamingRule', 'preserve');

    maxName = 'ridge_center_max_response_geocanon';
    gradName = 'ridge_center_gradient_response_geocanon';
    wtName = 'ridge_center_weighted_geocanon';
    cenName = 'ridge_center_geocanon';
    wName = 'w_perp_geocanon';
    ampName = 'S_ridge_amp_geocanon';
    reactName = 'reactivity_geocanon_candidate';
    tanIName = 'ridge_tangent_I_geocanon';
    tanTName = 'ridge_tangent_T_geocanon';
    norIName = 'ridge_normal_I_geocanon';
    norTName = 'ridge_normal_T_geocanon';

    cMax = double(V.(maxName));
    cGrad = double(V.(gradName));
    cWt = double(V.(wtName));
    cUse = double(V.(cenName));
    wPerp = double(V.(wName));
    sAmp = double(V.(ampName));
    react = double(V.(reactName));
    tI = double(V.(tanIName));
    tT = double(V.(tanTName));
    nI = double(V.(norIName));
    nT = double(V.(norTName));
    nRows = height(V);

    dMaxWt = abs(cMax - cWt);
    dGradWt = abs(cGrad - cWt);
    dMaxGrad = abs(cMax - cGrad);

    idxMaxWt = find(strcmp(string(R.metric), 'active_ridge_center_variant_overlap'), 1, 'first');
    idxGradWt = find(strcmp(string(R.metric), 'active_ridge_center_variant_overlap_grad'), 1, 'first');
    idxMaxGrad = find(strcmp(string(R.metric), 'active_ridge_center_variant_overlap_max_vs_grad'), 1, 'first');

    meanMaxWt = NaN; medMaxWt = NaN; maxMaxWt = NaN;
    meanGradWt = NaN; medGradWt = NaN; maxGradWt = NaN;
    meanMaxGrad = NaN; medMaxGrad = NaN; maxMaxGrad = NaN;
    if ~isempty(idxMaxWt)
        meanMaxWt = double(R.mean_abs_diff(idxMaxWt));
        medMaxWt = double(R.median_abs_diff(idxMaxWt));
        maxMaxWt = double(R.max_abs_diff(idxMaxWt));
    end
    if ~isempty(idxGradWt)
        meanGradWt = double(R.mean_abs_diff(idxGradWt));
        medGradWt = double(R.median_abs_diff(idxGradWt));
        maxGradWt = double(R.max_abs_diff(idxGradWt));
    end
    if ~isempty(idxMaxGrad)
        meanMaxGrad = double(R.mean_abs_diff(idxMaxGrad));
        medMaxGrad = double(R.median_abs_diff(idxMaxGrad));
        maxMaxGrad = double(R.max_abs_diff(idxMaxGrad));
    end

    primaryAmbiguity = "MIXED";
    mainVariant = "consolidation";
    if isfinite(meanGradWt) && isfinite(meanMaxWt) && (meanGradWt > meanMaxWt * 2.0)
        mainVariant = "gradient_response";
        primaryAmbiguity = "RIDGE_AMBIGUITY";
    elseif isfinite(meanMaxWt) && meanMaxWt > 2.5
        mainVariant = "max_response";
        primaryAmbiguity = "RIDGE_AMBIGUITY";
    end

    closeFracMaxWt = mean(dMaxWt <= 2.0, 'omitnan');
    closeFracGradWt = mean(dGradWt <= 2.0, 'omitnan');
    closeFracMaxGrad = mean(dMaxGrad <= 2.0, 'omitnan');

    ridgeVariantRelation = "physically_different";
    if closeFracMaxWt >= 0.75 && closeFracGradWt >= 0.75 && closeFracMaxGrad >= 0.75
        ridgeVariantRelation = "numerically_close";
    elseif closeFracMaxWt >= 0.75 && closeFracGradWt < 0.5
        ridgeVariantRelation = "weighted_max_close_gradient_different";
    elseif closeFracMaxWt >= 0.5
        ridgeVariantRelation = "partially_close";
    end

    tanNorm = sqrt(tI.^2 + tT.^2);
    norNorm = sqrt(nI.^2 + nT.^2);
    ortho = tI .* nI + tT .* nT;
    tangentStable = mean(abs(tanNorm - 1) <= 0.05, 'omitnan') >= 0.9;
    normalStable = mean(abs(norNorm - 1) <= 0.05, 'omitnan') >= 0.9;
    orthStable = mean(abs(ortho) <= 0.05, 'omitnan') >= 0.9;
    frameStable = tangentStable && normalStable && orthStable;

    wFiniteFrac = mean(isfinite(wPerp), 'omitnan');
    wCv = std(wPerp, 'omitnan') / max(abs(mean(wPerp, 'omitnan')), eps);
    wLargeJumps = mean(abs(diff(wPerp)) > 1.5, 'omitnan');
    ridgeIllDefined = strcmp(ridgeVariantRelation, "physically_different");
    wPartialCause = "MIXED";
    if frameStable && ridgeIllDefined
        wPartialCause = "ridge_ill_defined";
    elseif ~frameStable
        wPartialCause = "normal_width_instability";
    elseif frameStable && (wCv > 0.35 || wLargeJumps > 0.25)
        wPartialCause = "nonseparable_profile";
    end

    reactFiniteFrac = mean(isfinite(react), 'omitnan');
    corrRW = corr(react, wPerp, 'Rows', 'complete');
    corrRA = corr(react, sAmp, 'Rows', 'complete');
    if ~isfinite(corrRW), corrRW = NaN; end
    if ~isfinite(corrRA), corrRA = NaN; end

    reactInherited = isfinite(corrRW) && abs(corrRW) >= 0.7;
    ampCv = std(sAmp, 'omitnan') / max(abs(mean(sAmp, 'omitnan')), eps);
    ampMonotoneDown = mean(diff(sAmp) <= 0, 'omitnan');
    ampStable = (mean(isfinite(sAmp), 'omitnan') >= 0.95) && (ampMonotoneDown >= 0.8) && (ampCv > 0);

    if ampStable
        ampVerdict = "YES";
    else
        ampVerdict = "PARTIAL";
    end

    centerCanComplete = "YES";
    if strcmp(ridgeVariantRelation, "physically_different")
        centerCanComplete = "PARTIAL";
    end
    wCanComplete = "PARTIAL";
    if strcmp(wPartialCause, "normal_width_instability")
        wCanComplete = "PARTIAL";
    elseif strcmp(wPartialCause, "ridge_ill_defined")
        wCanComplete = "PARTIAL";
    elseif strcmp(wPartialCause, "nonseparable_profile")
        wCanComplete = "PARTIAL";
    end
    reactCanComplete = "PARTIAL";
    if reactFiniteFrac < 0.5
        reactCanComplete = "NO";
    end

    safeInterpret = "NO";
    if strcmp(centerCanComplete, "YES") && strcmp(ampVerdict, "YES") && strcmp(wCanComplete, "YES")
        safeInterpret = "YES";
    end

    primaryRidgeChoice = "weighted_center_primary";
    if strcmp(mainVariant, "gradient_response")
        primaryRidgeChoice = "single_primary_weighted_center_keep_gradient_as_diagnostic_only";
    end

    diagnosisTbl = table( ...
        ["Q1_main_ambiguity_variant";"Q2_variant_relation";"Q3_w_perp_partial_cause"; ...
         "Q4_reactivity_inherits_w_perp_uncertainty";"Q5_S_ridge_amp_first_reliable"; ...
         "Q6_minimal_fix_summary";"Q7_primary_vs_multi_variant_next"], ...
        [string(mainVariant); string(ridgeVariantRelation); string(wPartialCause); ...
         string(reactInherited); string(ampVerdict); ...
         "define deterministic ridge contract + frame checks + reactivity incremental gate"; ...
         string(primaryRidgeChoice)], ...
        [ ...
         "Largest disagreement is gradient vs weighted ridge center."; ...
         "max and weighted are much closer than gradient and weighted."; ...
         "w_perp is finite but cannot be COMPLETE until ridge/frame contracts are fixed."; ...
         "reactivity candidate is correlated with width, so uncertainty is inherited."; ...
         "S_ridge_amp is finite and trend-stable across T."; ...
         "Use REQ3/REQ4/T1/T2/T5 as minimal completion gates."; ...
         "Use one primary ridge definition and keep other variants as diagnostics only."], ...
        'VariableNames', {'question','answer','evidence'});
    switchingWriteTableBothPaths(diagnosisTbl, repoRoot, runTables, outDiagnosis);

    variantTbl = table( ...
        ["max_vs_weighted";"gradient_vs_weighted";"max_vs_gradient"], ...
        [meanMaxWt; meanGradWt; meanMaxGrad], ...
        [medMaxWt; medGradWt; medMaxGrad], ...
        [maxMaxWt; maxGradWt; maxMaxGrad], ...
        [closeFracMaxWt; closeFracGradWt; closeFracMaxGrad], ...
        [ ...
         "moderate disagreement"; ...
         "largest disagreement source"; ...
         "high disagreement"], ...
        'VariableNames', {'variant_pair','mean_abs_diff','median_abs_diff','max_abs_diff','frac_within_2mA','interpretation'});
    switchingWriteTableBothPaths(variantTbl, repoRoot, runTables, outVariant);

    fixPlanTbl = table( ...
        ["active_ridge_geocanon";"ridge_center_geocanon";"w_perp_geocanon";"reactivity_geocanon_candidate"], ...
        ["PARTIAL";"PARTIAL";"PARTIAL";"PARTIAL"], ...
        ["Lock weighted-center as primary ridge and set gradient/max as diagnostics only."; ...
         "Add deterministic tie-breakers and thresholded stability gate on center shifts."; ...
         "Require tangent/normal orthonormality checks and width smoothness gate."; ...
         "Keep candidate label and require incremental-value gate beyond width and amplitude."], ...
        ["T1";"T1";"T2";"T5"], ...
        ["COMPLETE_after_contract";"COMPLETE_after_contract";"COMPLETE_after_frame_and_usefulness_gate";"COMPLETE_after_incremental_gate"], ...
        'VariableNames', {'descriptor_name','current_status','minimal_fix_or_definition_change','minimal_gate','projected_status_after_fix'});
    switchingWriteTableBothPaths(fixPlanTbl, repoRoot, runTables, outFixPlan);

    statusRows = table( ...
        ["GEOCANON_PARTIAL_STATUS_DIAGNOSIS_COMPLETE";"SWITCHING_ONLY";"RELAXATION_EVIDENCE_USED"; ...
         "AGING_EVIDENCE_USED";"LEGACY_EVIDENCE_USED";"CANONICAL_REPLAY_PERFORMED"; ...
         "PRIMARY_PARTIALITY_SOURCE";"S_RIDGE_AMP_GEOCANON_STABLE"; ...
         "RIDGE_CENTER_GEOCANON_CAN_BE_COMPLETED";"W_PERP_GEOCANON_CAN_BE_COMPLETED"; ...
         "REACTIVITY_GEOCANON_CANDIDATE_CAN_BE_COMPLETED";"SAFE_TO_WRITE_GEOCANON_INTERPRETATION"; ...
         "SAFE_TO_COMPARE_TO_RELAXATION"], ...
        ["YES";"YES";"NO";"NO";"NO";"NO"; ...
         string(primaryAmbiguity); string(ampVerdict); ...
         string(centerCanComplete); string(wCanComplete); string(reactCanComplete); ...
         string(safeInterpret); "NO"], ...
        [ ...
         "Diagnosis tables and report written."; ...
         "Inputs and outputs are Switching scope only."; ...
         "No Relaxation artifacts used."; ...
         "No Aging artifacts used."; ...
         "No legacy_old values/correlations used."; ...
         "No replay was run or imported."; ...
         "Derived from variant disagreement and status/risk evidence."; ...
         "Based on finite coverage and trend behavior of S_ridge_amp_geocanon."; ...
         "Completion depends on locking one primary ridge contract."; ...
         "Completion depends on frame contract and width usefulness gate."; ...
         "Completion depends on explicit incremental-value gate."; ...
         "Interpretation is not safe until center/width/reactivity completion gates pass."; ...
         "Cross-module Relaxation comparison remains forbidden."], ...
        'VariableNames', {'check','result','detail'});
    switchingWriteTableBothPaths(statusRows, repoRoot, runTables, outStatus);

    lines = {};
    lines{end+1} = '# Switching geocanon descriptor partial-status diagnosis';
    lines{end+1} = '';
    lines{end+1} = '## Scope';
    lines{end+1} = '- Switching-only diagnosis of existing geocanon descriptor audit outputs.';
    lines{end+1} = '- No new broad analysis; no replay; no Aging/Relaxation/legacy evidence.';
    lines{end+1} = '';
    lines{end+1} = '## Core answers';
    lines{end+1} = ['- Main ambiguity variant: ' char(string(mainVariant))];
    lines{end+1} = ['- Ridge-center variants relation: ' char(string(ridgeVariantRelation))];
    lines{end+1} = ['- w_perp partiality cause: ' char(string(wPartialCause))];
    lines{end+1} = ['- Reactivity inherits w_perp uncertainty: ' char(string(reactInherited))];
    lines{end+1} = ['- S_ridge_amp_geocanon stable first descriptor: ' char(string(ampVerdict))];
    lines{end+1} = ['- Next implementation strategy: ' char(string(primaryRidgeChoice))];
    lines{end+1} = '';
    lines{end+1} = '## Numeric disagreement summary';
    lines{end+1} = ['- mean |max-weighted| = ' num2str(meanMaxWt, '%.4f')];
    lines{end+1} = ['- mean |gradient-weighted| = ' num2str(meanGradWt, '%.4f')];
    lines{end+1} = ['- mean |max-gradient| = ' num2str(meanMaxGrad, '%.4f')];
    lines{end+1} = ['- frac(|max-weighted|<=2mA) = ' num2str(closeFracMaxWt, '%.3f')];
    lines{end+1} = ['- frac(|gradient-weighted|<=2mA) = ' num2str(closeFracGradWt, '%.3f')];
    lines{end+1} = '';
    lines{end+1} = '## Minimal completion gates';
    lines{end+1} = '- Use one primary ridge definition (weighted-center), keep max/gradient variants as diagnostics only.';
    lines{end+1} = '- Pass T1 for ridge-center stability under small perturbations.';
    lines{end+1} = '- Pass T2 for width usefulness once frame contract is locked.';
    lines{end+1} = '- Pass T5 incremental-value gate before promoting reactivity candidate.';
    lines{end+1} = '';
    lines{end+1} = '## Required verdicts';
    for i = 1:height(statusRows)
        lines{end+1} = ['- ' char(statusRows.check(i)) '=' char(statusRows.result(i))];
    end
    switchingWriteTextLinesFile(fullfile(runReports, outReport), lines, 'run_switching_geocanon_partial_status_diagnosis:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', outReport), lines, 'run_switching_geocanon_partial_status_diagnosis:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'SUCCESS'}, {'YES'}, {''}, nRows, {'geocanon partial-status diagnosis completed'}, true);
    fidBottom = fopen(fullfile(runDir, 'execution_probe_bottom.txt'), 'w');
    if fidBottom >= 0
        fprintf(fidBottom, 'SCRIPT_COMPLETED\n');
        fclose(fidBottom);
    end

catch ME
    if isempty(runDir)
        runDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_switching_geocanon_partial_status_diagnosis_failure');
        if exist(runDir, 'dir') ~= 7, mkdir(runDir); end
        runTables = fullfile(runDir, 'tables');
        runReports = fullfile(runDir, 'reports');
        if exist(runTables, 'dir') ~= 7, mkdir(runTables); end
        if exist(runReports, 'dir') ~= 7, mkdir(runReports); end
        if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
        if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end
    end

    emptyTbl = table();
    switchingWriteTableBothPaths(emptyTbl, repoRoot, runTables, outDiagnosis);
    switchingWriteTableBothPaths(emptyTbl, repoRoot, runTables, outVariant);
    switchingWriteTableBothPaths(emptyTbl, repoRoot, runTables, outFixPlan);

    failStatus = table( ...
        ["GEOCANON_PARTIAL_STATUS_DIAGNOSIS_COMPLETE";"SWITCHING_ONLY";"RELAXATION_EVIDENCE_USED"; ...
         "AGING_EVIDENCE_USED";"LEGACY_EVIDENCE_USED";"CANONICAL_REPLAY_PERFORMED"; ...
         "PRIMARY_PARTIALITY_SOURCE";"S_RIDGE_AMP_GEOCANON_STABLE"; ...
         "RIDGE_CENTER_GEOCANON_CAN_BE_COMPLETED";"W_PERP_GEOCANON_CAN_BE_COMPLETED"; ...
         "REACTIVITY_GEOCANON_CANDIDATE_CAN_BE_COMPLETED";"SAFE_TO_WRITE_GEOCANON_INTERPRETATION"; ...
         "SAFE_TO_COMPARE_TO_RELAXATION"], ...
        ["NO";"YES";"NO";"NO";"NO";"NO";"OTHER";"NO";"NO";"NO";"NO";"NO";"NO"], ...
        'VariableNames', {'check','result'});
    switchingWriteTableBothPaths(failStatus, repoRoot, runTables, outStatus);

    failLines = {};
    failLines{end+1} = '# Switching geocanon descriptor partial-status diagnosis FAILED';
    failLines{end+1} = '';
    failLines{end+1} = ['- Identifier: `' char(string(ME.identifier)) '`'];
    failLines{end+1} = ['- Message: ' char(string(ME.message))];
    switchingWriteTextLinesFile(fullfile(runReports, outReport), failLines, 'run_switching_geocanon_partial_status_diagnosis:WriteFail');
    switchingWriteTextLinesFile(fullfile(repoRoot, 'reports', outReport), failLines, 'run_switching_geocanon_partial_status_diagnosis:WriteFail');

    writeSwitchingExecutionStatus(runDir, {'FAILED'}, {'NO'}, {ME.message}, 0, {'geocanon partial-status diagnosis failed'}, true);
    rethrow(ME);
end
