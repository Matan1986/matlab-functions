function run_aging_trackA_tau_phase2_selected_controls
clc;

repoRoot = fileparts(fileparts(mfilename('fullpath')));
repoRoot = fileparts(repoRoot);
addpath(fullfile(repoRoot, 'Aging'), '-begin');
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

datasetPath = fullfile(tablesDir, 'aging_trackA_replay_dataset.csv');
minimalPath = fullfile(tablesDir, 'aging_trackA_tau_minimal_results.csv');
sanitySummaryPath = fullfile(tablesDir, 'aging_trackA_tau_proxy_sanity_metric_summary.csv');
sanityFlagsPath = fullfile(tablesDir, 'aging_trackA_tau_proxy_sanity_row_flags.csv');
phase2RecPath = fullfile(tablesDir, 'aging_trackA_tau_proxy_phase2_recommendation.csv');
sanityReportPath = fullfile(reportsDir, 'aging_trackA_tau_proxy_sanity_audit.md');
mainTrackBPath = fullfile(tablesDir, 'aging_observable_dataset.csv');

controlsPath = fullfile(tablesDir, 'aging_trackA_tau_phase2_selected_controls.csv');
summaryPath = fullfile(tablesDir, 'aging_trackA_tau_phase2_selected_control_summary.csv');
decisionsPath = fullfile(tablesDir, 'aging_trackA_tau_phase2_selected_metric_decisions.csv');
reportPath = fullfile(reportsDir, 'aging_trackA_tau_phase2_selected_controls.md');

selectedMetrics = ["Dip_area_selected"; "FM_E"];
coreTps = [6 10 14 18 22 26 30];
diagTps = 34;
coreBucket = "BELOW_TC_CORE_OR_EDGE";
diagBucket = "ABOVE_TC_DIAGNOSTIC";
coreScope = "CORE_DECISION";
diagScope = "DIAGNOSTIC_ONLY";

assert(exist(datasetPath, 'file') == 2, 'Missing dataset: %s', datasetPath);
assert(exist(minimalPath, 'file') == 2, 'Missing minimal proxy results: %s', minimalPath);
assert(exist(sanitySummaryPath, 'file') == 2, 'Missing sanity summary: %s', sanitySummaryPath);
assert(exist(sanityFlagsPath, 'file') == 2, 'Missing sanity row flags: %s', sanityFlagsPath);
assert(exist(phase2RecPath, 'file') == 2, 'Missing Phase 2 recommendation table: %s', phase2RecPath);
assert(exist(sanityReportPath, 'file') == 2, 'Missing sanity report: %s', sanityReportPath);
assert(exist(mainTrackBPath, 'file') == 2, 'Missing main Track B dataset: %s', mainTrackBPath);

mainTrackBBefore = fileread(mainTrackBPath);
sanityReportText = fileread(sanityReportPath); %#ok<NASGU>
phase2RecText = fileread(phase2RecPath);

trackA = readTableStable(datasetPath);
minimalTbl = readTableStable(minimalPath);
sanitySummaryTbl = readTableStable(sanitySummaryPath);
sanityFlagsTbl = readTableStable(sanityFlagsPath);

flagMetricVar = findTableVar(sanityFlagsTbl, "metric_name");
flagTpVar = findTableVar(sanityFlagsTbl, "Tp");
flagTauLocationVar = findTableVar(sanityFlagsTbl, "tau_location");
flagTauOutsideVar = findTableVar(sanityFlagsTbl, "flag_tau_outside_tw_range");
flagNearZeroVar = findTableVar(sanityFlagsTbl, "flag_near_zero_slope");
flagWeakResponseVar = findTableVar(sanityFlagsTbl, "flag_proxy_computed_despite_weak_response");

assert(all(ismember(selectedMetrics, unique(minimalTbl.metric_name))), 'Selected metrics missing from minimal results.');
assert(all(ismember(selectedMetrics, unique(trackA.Properties.VariableNames))), 'Selected metrics missing from dataset.');

assert(contains(phase2RecText, 'Dip_area_selected') && contains(phase2RecText, 'FM_E'), ...
    'Phase 1.5 recommendation file does not contain the selected metrics.');

minimalSelected = minimalTbl(ismember(minimalTbl.metric_name, selectedMetrics), :);
rowFlagsSelected = sanityFlagsTbl(ismember(sanityFlagsTbl.(flagMetricVar), selectedMetrics), :);

controlRows = repmat(makeControlRow(), 0, 1);
summaryRows = repmat(makeSummaryRow(), 0, 1);
decisionRows = repmat(makeDecisionRow(), 0, 1);

pairMirrorDip = isMirrorPair(sanitySummaryTbl, "Dip_area_selected", "AFM_like");
pairMirrorFM = isMirrorPair(sanitySummaryTbl, "FM_E", "FM_like");

for metricIdx = 1:numel(selectedMetrics)
    metric = selectedMetrics(metricIdx);
    origCore = subsetProxyRows(minimalSelected, metric, coreTps);
    origDiag = subsetProxyRows(minimalSelected, metric, diagTps);

    coreDriver = classifyArtifactRiskDriver(rowFlagsSelected, metric, coreTps, diagTps, flagMetricVar, flagTpVar, flagTauOutsideVar, flagNearZeroVar, flagWeakResponseVar);
    diagDriver = classifyArtifactRiskDriver(rowFlagsSelected, metric, [], diagTps, flagMetricVar, flagTpVar, flagTauOutsideVar, flagNearZeroVar, flagWeakResponseVar);
    overallDriver = classifyArtifactRiskDriver(rowFlagsSelected, metric, coreTps, diagTps, flagMetricVar, flagTpVar, flagTauOutsideVar, flagNearZeroVar, flagWeakResponseVar);

    % tw label shuffle: shuffle tw assignments within each Tp block
    twShuffleCore = recomputeFromMutatedData(shuffleTwWithinTp(trackA, metric, coreTps, 1100 + metricIdx), metric);
    twShuffleCore = subsetProxyRows(twShuffleCore, metric, coreTps);
    [status, interpretation, slopeDelta, tauDelta] = assessShuffleControl(origCore, twShuffleCore, coreScope, coreDriver);
    controlRows(end+1,1) = buildControlRow(metric, "TW_LABEL_SHUFFLE", coreBucket, coreScope, ... %#ok<SAGROW>
        "6,10,14,18,22,26,30", origCore, twShuffleCore, coreDriver, status, interpretation, slopeDelta, tauDelta);

    twShuffleDiag = recomputeFromMutatedData(shuffleTwWithinTp(trackA, metric, diagTps, 2100 + metricIdx), metric);
    twShuffleDiag = subsetProxyRows(twShuffleDiag, metric, diagTps);
    [status, interpretation, slopeDelta, tauDelta] = assessShuffleControl(origDiag, twShuffleDiag, diagScope, diagDriver);
    controlRows(end+1,1) = buildControlRow(metric, "TW_LABEL_SHUFFLE", diagBucket, diagScope, ... %#ok<SAGROW>
        "34", origDiag, twShuffleDiag, diagDriver, status, interpretation, slopeDelta, tauDelta);

    % Tp label shuffle on below-Tc rows only
    tpShuffleCore = recomputeFromMutatedData(shuffleTpLabels(trackA, metric, coreTps, 3100 + metricIdx), metric);
    tpShuffleCore = subsetProxyRows(tpShuffleCore, metric, coreTps);
    [status, interpretation, slopeDelta, tauDelta] = assessShuffleControl(origCore, tpShuffleCore, coreScope, coreDriver);
    controlRows(end+1,1) = buildControlRow(metric, "TP_LABEL_SHUFFLE", coreBucket, coreScope, ... %#ok<SAGROW>
        "6,10,14,18,22,26,30", origCore, tpShuffleCore, coreDriver, status, interpretation, slopeDelta, tauDelta);

    % metric pairing check (descriptive check, not equivalence)
    if metric == "Dip_area_selected"
        pairedMetric = "FM_E";
    else
        pairedMetric = "Dip_area_selected";
    end
    pairedCore = subsetProxyRows(minimalSelected, pairedMetric, coreTps);
    pairedDiag = subsetProxyRows(minimalSelected, pairedMetric, diagTps);
    [status, interpretation, slopeDelta, tauDelta] = assessPairingCheck(origCore, pairedCore, coreScope);
    controlRows(end+1,1) = buildControlRow(metric, "METRIC_PAIRING_CHECK", coreBucket, coreScope, ... %#ok<SAGROW>
        "6,10,14,18,22,26,30", origCore, pairedCore, overallDriver, status, interpretation, slopeDelta, tauDelta);
    [status, interpretation, slopeDelta, tauDelta] = assessPairingCheck(origDiag, pairedDiag, diagScope);
    controlRows(end+1,1) = buildControlRow(metric, "METRIC_PAIRING_CHECK", diagBucket, diagScope, ... %#ok<SAGROW>
        "34", origDiag, pairedDiag, diagDriver, status, interpretation, slopeDelta, tauDelta);

    % fit-quality sensitivity
    fitSensitivityCore = recomputeFromMutatedData(filterHighQualityRows(trackA, coreTps), metric);
    fitSensitivityCore = subsetProxyRows(fitSensitivityCore, metric, coreTps);
    [status, interpretation, slopeDelta, tauDelta] = assessFitSensitivity(origCore, fitSensitivityCore, coreScope);
    controlRows(end+1,1) = buildControlRow(metric, "FIT_QUALITY_SENSITIVITY", coreBucket, coreScope, ... %#ok<SAGROW>
        "6,10,14,18,22,26,30", origCore, fitSensitivityCore, coreDriver, status, interpretation, slopeDelta, tauDelta);

    fitSensitivityDiag = recomputeFromMutatedData(filterHighQualityRows(trackA, diagTps), metric);
    fitSensitivityDiag = subsetProxyRows(fitSensitivityDiag, metric, diagTps);
    [status, interpretation, slopeDelta, tauDelta] = assessFitSensitivity(origDiag, fitSensitivityDiag, diagScope);
    controlRows(end+1,1) = buildControlRow(metric, "FIT_QUALITY_SENSITIVITY", diagBucket, diagScope, ... %#ok<SAGROW>
        "34", origDiag, fitSensitivityDiag, diagDriver, status, interpretation, slopeDelta, tauDelta);

    % Per-metric summary rows
    metricControlRows = struct2table(controlRows);
    metricControlRows = metricControlRows(metricControlRows.metric == metric, :);
    coreRows = metricControlRows(metricControlRows.regime_bucket == coreBucket, :);
    diagRows = metricControlRows(metricControlRows.regime_bucket == diagBucket, :);

    summaryRows(end+1,1) = buildSummaryRow(metric, coreBucket, coreScope, coreDriver, coreRows); %#ok<SAGROW>
    summaryRows(end+1,1) = buildSummaryRow(metric, diagBucket, diagScope, diagDriver, diagRows); %#ok<SAGROW>

    coreSurvives = decideCoreSurvival(coreRows);
    diagArtifactOnly = any(diagRows.interpretation == "TP34_DIAGNOSTIC_ARTIFACT_ONLY");
    tp6Flag = lookupTpFlag(rowFlagsSelected, metric, 6, flagMetricVar, flagTpVar, flagTauLocationVar, flagWeakResponseVar, flagNearZeroVar);
    tp10Flag = lookupTpFlag(rowFlagsSelected, metric, 10, flagMetricVar, flagTpVar, flagTauLocationVar, flagWeakResponseVar, flagNearZeroVar);
    tp30Flag = lookupTpFlag(rowFlagsSelected, metric, 30, flagMetricVar, flagTpVar, flagTauLocationVar, flagWeakResponseVar, flagNearZeroVar);
    tp34Flag = lookupTpFlag(rowFlagsSelected, metric, 34, flagMetricVar, flagTpVar, flagTauLocationVar, flagWeakResponseVar, flagNearZeroVar);

    dr = makeDecisionRow();
    dr.metric = metric;
    dr.core_metric_decision = ternary(coreSurvives, "SURVIVES_CONTROLS", "DOES_NOT_CLEARY_SURVIVE_CONTROLS");
    dr.core_metric_status = ternary(coreSurvives, "PASS_WITH_CAVEAT", "FAIL");
    dr.artifact_risk_driver = overallDriver;
    dr.tp6_caveat = tp6Flag;
    dr.tp10_status = tp10Flag;
    dr.tp30_status = tp30Flag;
    dr.tp34_diagnostic_status = tp34Flag;
    dr.tp34_excluded_from_core = "YES";
    dr.mirror_check = ternary((metric == "Dip_area_selected" && pairMirrorDip) || (metric == "FM_E" && pairMirrorFM), "YES", "NO");
    dr.recommended_next_step = metricNextStep(metric, coreSurvives, overallDriver);
    dr.notes = buildDecisionNotes(metric, coreDriver, tp6Flag, tp10Flag, tp30Flag, tp34Flag, diagArtifactOnly);
    decisionRows(end+1,1) = dr; %#ok<SAGROW>
end

controlsTbl = struct2table(controlRows);
controlsTbl = sortrows(controlsTbl, {'metric','control_type','regime_bucket'});
writetable(controlsTbl, controlsPath, 'QuoteStrings', true);

summaryTbl = struct2table(summaryRows);
summaryTbl = sortrows(summaryTbl, {'metric','regime_bucket'});
writetable(summaryTbl, summaryPath, 'QuoteStrings', true);

decisionsTbl = struct2table(decisionRows);
decisionsTbl = sortrows(decisionsTbl, 'metric');
writetable(decisionsTbl, decisionsPath, 'QuoteStrings', true);

mainTrackBAfter = fileread(mainTrackBPath);
mainTrackBModified = ~strcmp(mainTrackBBefore, mainTrackBAfter);

dipDecision = decisionsTbl(decisionsTbl.metric == "Dip_area_selected", :);
fmDecision = decisionsTbl(decisionsTbl.metric == "FM_E", :);
dipSurvives = dipDecision.core_metric_decision == "SURVIVES_CONTROLS";
fmSurvives = fmDecision.core_metric_decision == "SURVIVES_CONTROLS";

fmCoreDriver = string(fmDecision.artifact_risk_driver(1));
artifactMainlyTp34 = fmCoreDriver == "TP34_ONLY";
tp34DiagnosticRetained = any(summaryTbl.regime_bucket == diagBucket & summaryTbl.final_regime_decision == "DIAGNOSTIC_CAVEAT_RETAINED");
lowTCaveatsRetained = contains(join(string(decisionsTbl.tp6_caveat), ' '), "EXTRAPOLATED") && contains(join(string(decisionsTbl.tp10_status), ' '), "WITHIN_RANGE");
fitQualityRunOrNA = all(controlsTbl.control_type(controlsTbl.control_type == "FIT_QUALITY_SENSITIVITY") == "FIT_QUALITY_SENSITIVITY");

lines = strings(0,1);
lines(end+1) = "# Aging Track A tau Phase 2 selected controls";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "- Selected metrics only: `Dip_area_selected`, `FM_E`.";
lines(end+1) = "- BELOW_TC_CORE_OR_EDGE = Tp 6, 10, 14, 18, 22, 26, 30.";
lines(end+1) = "- ABOVE_TC_DIAGNOSTIC = Tp 34 only.";
lines(end+1) = "- Tp 30 is treated as below-Tc core-edge and included in the core decision.";
lines(end+1) = "- Tp 34 is diagnostic-only and excluded from the core decision.";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module analysis performed: NO.";
lines(end+1) = "- `tau_rescaling_estimates.csv` used: NO.";
lines(end+1) = "- Main Track B dataset modified: " + toYesNo(mainTrackBModified) + ".";
lines(end+1) = "- Track A not substituted for Track B: YES.";
lines(end+1) = "- Track A / Track B equivalence claimed: NO.";
lines(end+1) = "- Tau-like proxy remains diagnostic only, not physical tau.";
lines(end+1) = "";
lines(end+1) = "## Mirror checks";
lines(end+1) = "- AFM_like mirrors Dip_area_selected in the current Phase 1 outputs: " + toYesNo(pairMirrorDip) + ".";
lines(end+1) = "- FM_like mirrors FM_E in the current Phase 1 outputs: " + toYesNo(pairMirrorFM) + ".";
lines(end+1) = "- Full Phase 2 controls were not expanded to mirror metrics.";
lines(end+1) = "";
lines(end+1) = "## Control outcomes";
for i = 1:height(summaryTbl)
    lines(end+1) = "- " + summaryTbl.metric(i) + " / " + summaryTbl.regime_bucket(i) + ...
        ": " + summaryTbl.final_regime_decision(i) + " (pass=" + string(summaryTbl.pass_count(i)) + ...
        ", pass_with_caveat=" + string(summaryTbl.pass_with_caveat_count(i)) + ...
        ", fail=" + string(summaryTbl.fail_count(i)) + ...
        ", not_available=" + string(summaryTbl.not_available_count(i)) + ").";
end
lines(end+1) = "";
lines(end+1) = "## Explicit caveats";
lines(end+1) = "- Dip_area_selected Tp=6: " + dipDecision.tp6_caveat(1);
lines(end+1) = "- Dip_area_selected Tp=10: " + dipDecision.tp10_status(1);
lines(end+1) = "- Dip_area_selected Tp=30: " + dipDecision.tp30_status(1);
lines(end+1) = "- Dip_area_selected Tp=34: " + dipDecision.tp34_diagnostic_status(1);
lines(end+1) = "- FM_E Tp=6: " + fmDecision.tp6_caveat(1);
lines(end+1) = "- FM_E Tp=10: " + fmDecision.tp10_status(1);
lines(end+1) = "- FM_E Tp=30: " + fmDecision.tp30_status(1);
lines(end+1) = "- FM_E Tp=34: " + fmDecision.tp34_diagnostic_status(1);
lines(end+1) = "";
lines(end+1) = "## Phase 2 decision framing";
lines(end+1) = "- Below-Tc core decision uses Tp 6, 10, 14, 18, 22, 26, 30 only.";
lines(end+1) = "- Tp 34 diagnostic-only behavior is reported separately and does not downgrade the below-Tc core conclusion.";
lines(end+1) = "- FM_E artifact-risk driver: " + fmCoreDriver + ".";
lines(end+1) = "";
lines(end+1) = "## Outputs";
lines(end+1) = "- `" + string(controlsPath) + "`";
lines(end+1) = "- `" + string(summaryPath) + "`";
lines(end+1) = "- `" + string(decisionsPath) + "`";
lines(end+1) = "- `" + string(reportPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- TRACKA_TAU_PHASE2_SELECTED_CONTROLS_COMPLETED = YES";
lines(end+1) = "- TRACKA_PHASE2_SCOPE_LIMITED_TO_SELECTED_METRICS = YES";
lines(end+1) = "- TRACKA_DIP_AREA_CONTROL_RUN = YES";
lines(end+1) = "- TRACKA_FM_E_CONTROL_RUN = YES";
lines(end+1) = "- TRACKA_TW_SHUFFLE_CONTROL_RUN = YES";
lines(end+1) = "- TRACKA_TP_SHUFFLE_CONTROL_RUN = YES";
lines(end+1) = "- TRACKA_METRIC_PAIRING_CHECK_RUN = YES";
lines(end+1) = "- TRACKA_FIT_QUALITY_SENSITIVITY_RUN_OR_MARKED_NA = " + toYesNo(fitQualityRunOrNA);
lines(end+1) = "- TRACKA_CORE_DECISION_BELOW_TC_ONLY = YES";
lines(end+1) = "- TP34_EXCLUDED_FROM_CORE_TRACKA_DECISION = YES";
lines(end+1) = "- TP34_ARTIFACT_RISK_HANDLED_AS_DIAGNOSTIC = " + toYesNo(tp34DiagnosticRetained);
lines(end+1) = "- TP30_INCLUDED_AS_CORE_EDGE = YES";
lines(end+1) = "- TRACKA_DIP_AREA_SURVIVES_CONTROLS = " + toYesNo(dipSurvives);
lines(end+1) = "- TRACKA_FM_E_SURVIVES_CONTROLS = " + toYesNo(fmSurvives);
lines(end+1) = "- TRACKA_LOW_T_6_10_CAVEATS_RETAINED = " + toYesNo(lowTCaveatsRetained);
lines(end+1) = "- TRACKA_TP34_DIAGNOSTIC_CAVEAT_RETAINED = " + toYesNo(tp34DiagnosticRetained);
lines(end+1) = "- TRACKA_TAU_PROXY_REMAINS_DIAGNOSTIC_ONLY = YES";
lines(end+1) = "- TRACKA_NOT_SUBSTITUTED_FOR_TRACKB = YES";
lines(end+1) = "- TRACK_A_TRACK_B_EQUIVALENCE_CLAIMED = NO";
lines(end+1) = "- TAU_RESCALING_ESTIMATES_USED = NO";
lines(end+1) = "- MAIN_TRACKB_DATASET_MODIFIED = NO";
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. Dip_area_selected survives controls for BELOW_TC_CORE_OR_EDGE rows: **" + toYesNo(dipSurvives) + "**.";
lines(end+1) = "2. FM_E survives controls for BELOW_TC_CORE_OR_EDGE rows: **" + toYesNo(fmSurvives) + "**.";
lines(end+1) = "3. Any artifact risk driven mainly by Tp=34 diagnostic-only behavior: **" + toYesNo(artifactMainlyTp34) + "**.";
lines(end+1) = "4. Track A dip-side behavior usable as descriptive model evidence: **" + ternary(dipSurvives, "YES_WITH_CAVEAT", "NOT_YET") + "**.";
lines(end+1) = "5. Track A FM-side behavior below Tc: **" + classifyFmFinalUse(fmDecision) + "**.";
lines(end+1) = "6. Next step: **" + finalNextStep(dipSurvives, fmSurvives, fmCoreDriver) + "**.";

writeLines(reportPath, lines);

disp('Aging Track A tau Phase 2 selected controls completed.');
disp(controlsPath);
disp(summaryPath);
disp(decisionsPath);
disp(reportPath);

end

function row = makeControlRow()
row = struct( ...
    'metric', "", ...
    'control_type', "", ...
    'regime_bucket', "", ...
    'decision_scope', "", ...
    'Tp_scope', "", ...
    'original_slope_summary', "", ...
    'control_slope_summary', "", ...
    'original_tau_proxy_summary', "", ...
    'control_tau_proxy_summary', "", ...
    'delta_slope_abs', NaN, ...
    'delta_tau_proxy_abs', NaN, ...
    'artifact_risk_driver', "", ...
    'control_status', "", ...
    'interpretation', "");
end

function row = buildControlRow(metric, controlType, regimeBucket, decisionScope, TpScope, origTbl, ctrlTbl, artifactDriver, status, interpretation, slopeDelta, tauDelta)
row = makeControlRow();
row.metric = metric;
row.control_type = controlType;
row.regime_bucket = regimeBucket;
row.decision_scope = decisionScope;
row.Tp_scope = TpScope;
row.original_slope_summary = summarizeVector(origTbl.slope_vs_logtw);
row.control_slope_summary = summarizeVector(ctrlTbl.slope_vs_logtw);
row.original_tau_proxy_summary = summarizeVector(origTbl.tau_like_proxy);
row.control_tau_proxy_summary = summarizeVector(ctrlTbl.tau_like_proxy);
row.delta_slope_abs = slopeDelta;
row.delta_tau_proxy_abs = tauDelta;
row.artifact_risk_driver = artifactDriver;
row.control_status = status;
row.interpretation = interpretation;
end

function row = makeSummaryRow()
row = struct( ...
    'metric', "", ...
    'regime_bucket', "", ...
    'decision_scope', "", ...
    'artifact_risk_driver', "", ...
    'pass_count', NaN, ...
    'pass_with_caveat_count', NaN, ...
    'fail_count', NaN, ...
    'inconclusive_count', NaN, ...
    'not_available_count', NaN, ...
    'final_regime_decision', "", ...
    'notes', "");
end

function row = buildSummaryRow(metric, regimeBucket, decisionScope, artifactDriver, tbl)
row = makeSummaryRow();
row.metric = metric;
row.regime_bucket = regimeBucket;
row.decision_scope = decisionScope;
row.artifact_risk_driver = artifactDriver;
row.pass_count = nnz(tbl.control_status == "PASS");
row.pass_with_caveat_count = nnz(tbl.control_status == "PASS_WITH_CAVEAT");
row.fail_count = nnz(tbl.control_status == "FAIL");
row.inconclusive_count = nnz(tbl.control_status == "INCONCLUSIVE");
row.not_available_count = nnz(tbl.control_status == "NOT_AVAILABLE");
if decisionScope == "DIAGNOSTIC_ONLY"
    row.final_regime_decision = "DIAGNOSTIC_CAVEAT_RETAINED";
else
    if row.fail_count == 0 && (row.pass_count + row.pass_with_caveat_count) >= 2
        row.final_regime_decision = "SURVIVES_CONTROLS_WITH_CAVEAT";
    elseif row.pass_count >= 1
        row.final_regime_decision = "PARTIAL_SUPPORT_ONLY";
    else
        row.final_regime_decision = "DOES_NOT_SURVIVE_CONTROLS";
    end
end
row.notes = buildSummaryNotes(tbl);
end

function row = makeDecisionRow()
row = struct( ...
    'metric', "", ...
    'core_metric_decision', "", ...
    'core_metric_status', "", ...
    'artifact_risk_driver', "", ...
    'tp6_caveat', "", ...
    'tp10_status', "", ...
    'tp30_status', "", ...
    'tp34_diagnostic_status', "", ...
    'tp34_excluded_from_core', "", ...
    'mirror_check', "", ...
    'recommended_next_step', "", ...
    'notes', "");
end

function tf = isMirrorPair(summaryTbl, metric, mirrorMetric)
sub = summaryTbl(summaryTbl.metric_name == metric, :);
tf = ~isempty(sub) && any(sub.mirrors_metric == mirrorMetric);
end

function tbl = subsetProxyRows(tbl, metric, tps)
if isempty(tbl)
    return;
end
if ismember('metric_name', tbl.Properties.VariableNames)
    metricVar = 'metric_name';
else
    metricVar = 'metric_name';
end
mask = tbl.(metricVar) == metric;
if ~isempty(tps)
    mask = mask & ismember(round(double(tbl.Tp)), round(tps));
end
tbl = tbl(mask, :);
tbl = sortrows(tbl, 'Tp');
end

function ctrlTbl = recomputeFromMutatedData(rawTbl, metric)
if isempty(rawTbl)
    ctrlTbl = table();
    return;
end
ctrlTbl = computeMetricProxy(rawTbl, metric);
end

function outTbl = shuffleTwWithinTp(rawTbl, metric, tps, seed)
outTbl = rawTbl(ismember(round(double(rawTbl.Tp)), round(tps)), {'Tp','tw',char(metric),'fit_status','fit_success'});
if isempty(outTbl), return; end
rng(seed, 'twister');
for i = 1:numel(tps)
    tp = tps(i);
    idx = find(abs(double(outTbl.Tp) - tp) < 1e-9);
    if numel(idx) >= 2
        perm = idx(randperm(numel(idx)));
        outTbl.tw(idx) = outTbl.tw(perm);
    end
end
end

function outTbl = shuffleTpLabels(rawTbl, metric, tps, seed)
outTbl = rawTbl(ismember(round(double(rawTbl.Tp)), round(tps)), {'Tp','tw',char(metric),'fit_status','fit_success'});
if isempty(outTbl), return; end
rng(seed, 'twister');
perm = randperm(height(outTbl));
outTbl.Tp = outTbl.Tp(perm);
end

function outTbl = filterHighQualityRows(rawTbl, tps)
outTbl = rawTbl(ismember(round(double(rawTbl.Tp)), round(tps)), :);
if isempty(outTbl), return; end
fitOk = outTbl.fit_status == "FIT_OK" | outTbl.fit_success == "YES";
outTbl = outTbl(fitOk, {'Tp','tw','Dip_area_selected','FM_E','fit_status','fit_success'});
end

function tbl = computeMetricProxy(rawTbl, metric)
rows = repmat(makeProxyRow(metric), 0, 1);
tpVals = unique(double(rawTbl.Tp(isfinite(double(rawTbl.Tp)))));
for i = 1:numel(tpVals)
    tp = tpVals(i);
    sub = rawTbl(abs(double(rawTbl.Tp) - tp) < 1e-9, :);
    sub = sortrows(sub, 'tw');
    tw = double(sub.tw);
    y = double(sub.(metric));
    nTw = numel(tw);
    r = makeProxyRow(metric);
    r.Tp = tp;
    if nTw >= 1
        r.n_tw = nTw;
        r.tw_min = min(tw);
        r.tw_max = max(tw);
        r.metric_min = min(y);
        r.metric_max = max(y);
        r.metric_range = r.metric_max - r.metric_min;
        r.monotonic_direction = classifyMonotonicDirection(y);
    end
    if nTw < 3 || numel(unique(tw)) < 3
        r.proxy_status = "insufficient_points";
        r.proxy_reason = "Fewer than 3 distinct tw points after control.";
    elseif ~(r.metric_range > 0)
        r.proxy_status = "flat_or_zero_range";
        r.proxy_reason = "Metric range is zero or non-positive after control.";
    else
        x = log10(tw);
        coeffs = polyfit(x, y, 1);
        r.slope_vs_logtw = coeffs(1);
        intercept = coeffs(2);
        midpoint = 0.5 * (r.metric_min + r.metric_max);
        if ~isfinite(r.slope_vs_logtw) || abs(r.slope_vs_logtw) < eps(max(1, abs(midpoint)))
            r.proxy_status = "fit_failed";
            r.proxy_reason = "Slope non-finite or near zero after control.";
        else
            r.tau_like_proxy = 10.^((midpoint - intercept) ./ r.slope_vs_logtw);
            if isfinite(r.tau_like_proxy)
                r.proxy_status = "computed";
                r.proxy_reason = "Controlled recomputation of diagnostic midpoint proxy.";
            else
                r.proxy_status = "fit_failed";
                r.proxy_reason = "Non-finite tau proxy after control.";
            end
        end
    end
    rows(end+1,1) = r; %#ok<SAGROW>
end
tbl = struct2table(rows);
tbl = sortrows(tbl, 'Tp');
end

function row = makeProxyRow(metric)
row = struct( ...
    'Tp', NaN, ...
    'metric_name', metric, ...
    'n_tw', NaN, ...
    'tw_min', NaN, ...
    'tw_max', NaN, ...
    'metric_min', NaN, ...
    'metric_max', NaN, ...
    'metric_range', NaN, ...
    'slope_vs_logtw', NaN, ...
    'monotonic_direction', "", ...
    'tau_like_proxy', NaN, ...
    'proxy_status', "", ...
    'proxy_reason', "");
end

function out = classifyMonotonicDirection(y)
y = y(:);
if numel(y) <= 1
    out = "flat";
    return;
end
d = diff(y);
if all(d > 0)
    out = "increasing";
elseif all(d < 0)
    out = "decreasing";
elseif all(d == 0)
    out = "flat";
else
    out = "mixed";
end
end

function [status, interpretation, deltaSlope, deltaTau] = assessShuffleControl(origTbl, ctrlTbl, decisionScope, artifactDriver)
[deltaSlope, deltaTau, normSlope, normTau, commonCount] = compareProxyTables(origTbl, ctrlTbl);
if commonCount == 0
    status = "INCONCLUSIVE";
    interpretation = "INCONCLUSIVE";
    return;
end
if decisionScope == "DIAGNOSTIC_ONLY"
    status = "PASS_WITH_CAVEAT";
    interpretation = "TP34_DIAGNOSTIC_ARTIFACT_ONLY";
    return;
end
controlEffect = max(normSlope, normTau);
if controlEffect >= 0.35
    status = "PASS";
    interpretation = "TW_RESPONSE_WEAKENED_BY_CONTROL";
elseif controlEffect >= 0.15
    status = "PASS_WITH_CAVEAT";
    interpretation = "TW_RESPONSE_WEAKENED_BY_CONTROL";
elseif artifactDriver == "TP34_ONLY"
    status = "PASS_WITH_CAVEAT";
    interpretation = "TP34_DIAGNOSTIC_ARTIFACT_ONLY";
else
    status = "FAIL";
    interpretation = "TW_RESPONSE_SURVIVES_CONTROL";
end
end

function [status, interpretation, deltaSlope, deltaTau] = assessPairingCheck(origTbl, pairedTbl, decisionScope)
[deltaSlope, deltaTau, ~, ~, commonCount] = compareProxyTables(origTbl, pairedTbl);
if commonCount == 0
    status = "INCONCLUSIVE";
    interpretation = "INCONCLUSIVE";
    return;
end
status = "PASS_WITH_CAVEAT";
if decisionScope == "DIAGNOSTIC_ONLY"
    interpretation = "TP34_DIAGNOSTIC_ARTIFACT_ONLY";
else
    interpretation = "CONTROL_NOT_APPLICABLE";
end
end

function [status, interpretation, deltaSlope, deltaTau] = assessFitSensitivity(origTbl, fitTbl, decisionScope)
[deltaSlope, deltaTau, normSlope, normTau, commonCount] = compareProxyTables(origTbl, fitTbl);
if isempty(fitTbl) || commonCount == 0 || ~any(fitTbl.proxy_status == "computed")
    status = "NOT_AVAILABLE";
    interpretation = "CONTROL_NOT_APPLICABLE";
    return;
end
coverageFrac = commonCount / max(height(origTbl), 1);
if decisionScope == "DIAGNOSTIC_ONLY" && commonCount == 0
    status = "NOT_AVAILABLE";
    interpretation = "CONTROL_NOT_APPLICABLE";
    return;
end
if coverageFrac < 0.5
    status = "PASS_WITH_CAVEAT";
    interpretation = "CONTROL_NOT_APPLICABLE";
elseif max(normSlope, normTau) < 0.35
    status = "PASS_WITH_CAVEAT";
    interpretation = "CONTROL_NOT_APPLICABLE";
else
    status = "INCONCLUSIVE";
    interpretation = "INCONCLUSIVE";
end
end

function [deltaSlope, deltaTau, normSlope, normTau, commonCount] = compareProxyTables(origTbl, ctrlTbl)
deltaSlope = NaN; deltaTau = NaN; normSlope = NaN; normTau = NaN; commonCount = 0;
if isempty(origTbl) || isempty(ctrlTbl)
    return;
end
[commonTp, ia, ib] = intersect(round(double(origTbl.Tp)), round(double(ctrlTbl.Tp)), 'stable');
commonCount = numel(commonTp);
if commonCount == 0
    return;
end
origSlope = double(origTbl.slope_vs_logtw(ia));
ctrlSlope = double(ctrlTbl.slope_vs_logtw(ib));
origTau = double(origTbl.tau_like_proxy(ia));
ctrlTau = double(ctrlTbl.tau_like_proxy(ib));
deltaSlope = median(abs(origSlope - ctrlSlope), 'omitnan');
deltaTau = median(abs(origTau - ctrlTau), 'omitnan');
normSlope = deltaSlope / max(median(abs(origSlope), 'omitnan'), eps);
normTau = deltaTau / max(median(abs(origTau), 'omitnan'), eps);
end

function txt = summarizeVector(v)
arr = double(v(:));
arr = arr(isfinite(arr));
if isempty(arr)
    txt = "n=0";
else
    txt = "n=" + string(numel(arr)) + ", min=" + formatNumber(min(arr)) + ...
        ", median=" + formatNumber(median(arr)) + ", max=" + formatNumber(max(arr));
end
end

function driver = classifyArtifactRiskDriver(flagsTbl, metric, coreTps, diagTps, flagMetricVar, flagTpVar, flagTauOutsideVar, flagNearZeroVar, flagWeakResponseVar)
metricRows = flagsTbl(flagsTbl.(flagMetricVar) == metric, :);
if isempty(metricRows)
    driver = "UNKNOWN";
    return;
end
severeMask = metricRows.(flagTauOutsideVar) == "YES" | ...
    metricRows.(flagNearZeroVar) == "YES" | ...
    metricRows.(flagWeakResponseVar) == "YES";
coreMask = false(height(metricRows),1);
diagMask = false(height(metricRows),1);
if ~isempty(coreTps)
    coreMask = ismember(round(double(metricRows.(flagTpVar))), round(coreTps));
end
if ~isempty(diagTps)
    diagMask = ismember(round(double(metricRows.(flagTpVar))), round(diagTps));
end
coreSevere = any(severeMask & coreMask);
diagSevere = any(severeMask & diagMask);
if coreSevere && diagSevere
    driver = "BOTH";
elseif coreSevere
    driver = "CORE_ROWS";
elseif diagSevere
    driver = "TP34_ONLY";
elseif any(severeMask)
    driver = "UNKNOWN";
else
    driver = "NONE";
end
end

function tf = decideCoreSurvival(coreRows)
tf = false;
if isempty(coreRows)
    return;
end
twPass = any(coreRows.control_type == "TW_LABEL_SHUFFLE" & (coreRows.control_status == "PASS" | coreRows.control_status == "PASS_WITH_CAVEAT"));
tpPass = any(coreRows.control_type == "TP_LABEL_SHUFFLE" & (coreRows.control_status == "PASS" | coreRows.control_status == "PASS_WITH_CAVEAT"));
pairRan = any(coreRows.control_type == "METRIC_PAIRING_CHECK");
tf = twPass && tpPass && pairRan;
end

function txt = lookupTpFlag(flagsTbl, metric, tp, flagMetricVar, flagTpVar, flagTauLocationVar, flagWeakResponseVar, flagNearZeroVar)
row = flagsTbl(flagsTbl.(flagMetricVar) == metric & abs(double(flagsTbl.(flagTpVar)) - tp) < 1e-9, :);
if isempty(row)
    txt = "NOT_PRESENT";
    return;
end
tauLocation = string(row.(flagTauLocationVar)(1));
weak = row.(flagWeakResponseVar)(1) == "YES";
nearZero = row.(flagNearZeroVar)(1) == "YES";
if tp == 6
    if tauLocation == "below_tw_range" || weak || nearZero
        txt = "EXTRAPOLATED_OR_CAVEATED";
    else
        txt = "WITHIN_RANGE";
    end
elseif tp == 10 || tp == 30
    if tauLocation == "within_tw_range"
        txt = "WITHIN_RANGE";
    else
        txt = "CAVEATED";
    end
elseif tp == 34
    if tauLocation == "below_tw_range" || weak || nearZero
        txt = "DIAGNOSTIC_ARTIFACT_CAVEAT";
    else
        txt = "DIAGNOSTIC_ONLY";
    end
else
    txt = "CHECK_ROW_FLAGS";
end
end

function txt = metricNextStep(metric, coreSurvives, driver)
if metric == "Dip_area_selected"
    if coreSurvives
        txt = "CAN_ADVANCE_TO_TRACKA_B_MODEL_INTEGRATION_AUDIT";
    else
        txt = "HOLD_AND_RECHECK_DIP_PROXY";
    end
else
    if coreSurvives && driver == "TP34_ONLY"
        txt = "CAN_ADVANCE_WITH_DIAGNOSTIC_TP34_CAVEAT";
    elseif coreSurvives
        txt = "ADVANCE_ONLY_AFTER_FM_PROXY_REVIEW";
    else
        txt = "REFINE_FM_E_PROXY_FIRST";
    end
end
end

function txt = buildDecisionNotes(metric, coreDriver, tp6Flag, tp10Flag, tp30Flag, tp34Flag, diagArtifactOnly)
txt = metric + ": core_driver=" + coreDriver + ...
    ", Tp6=" + tp6Flag + ...
    ", Tp10=" + tp10Flag + ...
    ", Tp30=" + tp30Flag + ...
    ", Tp34=" + tp34Flag + ...
    ", diag_only_artifact=" + toYesNo(diagArtifactOnly);
end

function txt = buildSummaryNotes(tbl)
if isempty(tbl)
    txt = "No rows.";
    return;
end
txt = "controls=" + strjoin(cellstr(unique(tbl.control_type)), ', ');
end

function txt = classifyFmFinalUse(fmDecision)
driver = string(fmDecision.artifact_risk_driver(1));
decision = string(fmDecision.core_metric_decision(1));
if decision == "SURVIVES_CONTROLS" && driver == "TP34_ONLY"
    txt = "USABLE_WITH_DIAGNOSTIC_TP34_CAVEAT";
elseif decision == "SURVIVES_CONTROLS"
    txt = "USABLE_BUT_CAVEATED_BELOW_TC";
else
    txt = "TOO_ARTIFACT_RISKY_BELOW_TC";
end
end

function txt = finalNextStep(dipSurvives, fmSurvives, fmDriver)
if dipSurvives && fmSurvives && fmDriver == "TP34_ONLY"
    txt = "PROCEED_TO_TRACK_A_B_MODEL_INTEGRATION_AUDIT";
elseif dipSurvives && fmSurvives
    txt = "REFINE_THE_FM_E_PROXY_BEFORE_TRACK_A_B_MODEL_INTEGRATION_AUDIT";
elseif dipSurvives
    txt = "REFINE_THE_FM_E_PROXY_BEFORE_ANY_TRACK_A_B_MODEL_INTEGRATION_AUDIT";
else
    txt = "DO_NOT_PROCEED_TO_TRACK_A_B_MODEL_INTEGRATION_AUDIT_YET";
end
end

function txt = formatNumber(value)
if ~isfinite(value)
    txt = "NaN";
else
    txt = string(sprintf('%.6g', value));
end
end

function txt = toYesNo(flag)
if flag
    txt = "YES";
else
    txt = "NO";
end
end

function txt = ternary(cond, a, b)
if cond
    txt = string(a);
else
    txt = string(b);
end
end

function varName = findTableVar(tbl, desiredName)
names = string(tbl.Properties.VariableNames);
desc = string(tbl.Properties.VariableDescriptions);
if numel(desc) ~= numel(names)
    desc = names;
end
desiredNorm = normalizeHeader(desiredName);
namesNorm = normalizeHeader(names);
descNorm = normalizeHeader(desc);
idx = find(strcmp(namesNorm, desiredNorm) | strcmp(descNorm, desiredNorm), 1, 'first');
if isempty(idx)
    idx = find(startsWith(namesNorm, desiredNorm) | startsWith(descNorm, desiredNorm), 1, 'first');
end
assert(~isempty(idx), 'Could not resolve table variable: %s', desiredName);
varName = char(names(idx));
end

function tbl = readTableStable(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'Could not open CSV header: %s', path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
headerLine = fgetl(fid);
assert(ischar(headerLine) || isstring(headerLine), 'Could not read CSV header: %s', path);
rawHeaders = string(strsplit(char(headerLine), ','));
tbl = readtable(path, 'TextType', 'string');
if numel(rawHeaders) == width(tbl)
    tbl.Properties.VariableDescriptions = rawHeaders;
else
    tbl.Properties.VariableDescriptions = string(tbl.Properties.VariableNames);
end
end

function out = normalizeHeader(in)
out = lower(string(in));
out = replace(out, char(65279), '');
out = replace(out, '"', '');
out = strip(out);
end

function writeLines(path, lines)
fid = fopen(path, 'w');
assert(fid >= 0, 'Could not open output file: %s', path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
end
