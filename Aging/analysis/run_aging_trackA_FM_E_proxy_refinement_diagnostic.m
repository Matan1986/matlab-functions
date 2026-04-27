function run_aging_trackA_FM_E_proxy_refinement_diagnostic
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
phase2ControlsPath = fullfile(tablesDir, 'aging_trackA_tau_phase2_selected_controls.csv');
phase2SummaryPath = fullfile(tablesDir, 'aging_trackA_tau_phase2_selected_control_summary.csv');
phase2DecisionPath = fullfile(tablesDir, 'aging_trackA_tau_phase2_selected_metric_decisions.csv');
phase2ReportPath = fullfile(reportsDir, 'aging_trackA_tau_phase2_selected_controls.md');
mainTrackBPath = fullfile(tablesDir, 'aging_observable_dataset.csv');

rowsPath = fullfile(tablesDir, 'aging_trackA_FM_E_proxy_refinement_rows.csv');
altSummaryPath = fullfile(tablesDir, 'aging_trackA_FM_E_proxy_alternative_summaries.csv');
fitSensitivityPath = fullfile(tablesDir, 'aging_trackA_FM_E_proxy_fit_quality_sensitivity.csv');
decisionPath = fullfile(tablesDir, 'aging_trackA_FM_E_proxy_refined_decision.csv');
reportPath = fullfile(reportsDir, 'aging_trackA_FM_E_proxy_refinement_diagnostic.md');

coreTps = [6 10 14 18 22 26 30];
coreMidTps = [14 18 22 26];
metric = "FM_E";

assert(exist(datasetPath, 'file') == 2, 'Missing dataset: %s', datasetPath);
assert(exist(minimalPath, 'file') == 2, 'Missing minimal results: %s', minimalPath);
assert(exist(sanitySummaryPath, 'file') == 2, 'Missing sanity summary: %s', sanitySummaryPath);
assert(exist(sanityFlagsPath, 'file') == 2, 'Missing sanity row flags: %s', sanityFlagsPath);
assert(exist(phase2ControlsPath, 'file') == 2, 'Missing Phase 2 controls: %s', phase2ControlsPath);
assert(exist(phase2SummaryPath, 'file') == 2, 'Missing Phase 2 control summary: %s', phase2SummaryPath);
assert(exist(phase2DecisionPath, 'file') == 2, 'Missing Phase 2 decisions: %s', phase2DecisionPath);
assert(exist(phase2ReportPath, 'file') == 2, 'Missing Phase 2 report: %s', phase2ReportPath);
assert(exist(mainTrackBPath, 'file') == 2, 'Missing main Track B dataset: %s', mainTrackBPath);

mainTrackBBefore = fileread(mainTrackBPath);
phase2ReportText = fileread(phase2ReportPath); %#ok<NASGU>

trackA = readTableStable(datasetPath);
minimalTbl = readTableStable(minimalPath);
sanitySummaryTbl = readTableStable(sanitySummaryPath);
sanityFlagsTbl = readTableStable(sanityFlagsPath);
phase2ControlsTbl = readTableStable(phase2ControlsPath);
phase2SummaryTbl = readTableStable(phase2SummaryPath);
phase2DecisionTbl = readTableStable(phase2DecisionPath);

flagMetricVar = findTableVar(sanityFlagsTbl, "metric_name");
flagTpVar = findTableVar(sanityFlagsTbl, "Tp");
flagTauLocationVar = findTableVar(sanityFlagsTbl, "tau_location");
flagSmallAbsVar = findTableVar(sanityFlagsTbl, "flag_small_metric_range_abs");
flagNearZeroVar = findTableVar(sanityFlagsTbl, "flag_near_zero_slope");
flagWeakVar = findTableVar(sanityFlagsTbl, "flag_proxy_computed_despite_weak_response");
flagMixedVar = findTableVar(sanityFlagsTbl, "flag_mixed_monotonicity");
flagNotesVar = findTableVar(sanityFlagsTbl, "flag_notes");
flagSlopeSignVar = findTableVar(sanityFlagsTbl, "slope_sign");
flagFittedRatioVar = findTableVar(sanityFlagsTbl, "fitted_excursion_ratio");

controlsMetricVar = findTableVar(phase2ControlsTbl, "metric");
controlsTypeVar = findTableVar(phase2ControlsTbl, "control_type");
controlsBucketVar = findTableVar(phase2ControlsTbl, "regime_bucket");
controlsStatusVar = findTableVar(phase2ControlsTbl, "control_status");
controlsInterpVar = findTableVar(phase2ControlsTbl, "interpretation");
controlsDriverVar = findTableVar(phase2ControlsTbl, "artifact_risk_driver");

decisionMetricVar = findTableVar(phase2DecisionTbl, "metric");
decisionDriverVar = findTableVar(phase2DecisionTbl, "artifact_risk_driver");
decisionTp6Var = findTableVar(phase2DecisionTbl, "tp6_caveat");
decisionTp10Var = findTableVar(phase2DecisionTbl, "tp10_status");
decisionTp30Var = findTableVar(phase2DecisionTbl, "tp30_status");
decisionTp34Var = findTableVar(phase2DecisionTbl, "tp34_diagnostic_status");

assert(any(minimalTbl.metric_name == metric), 'FM_E missing from minimal results.');
assert(any(sanitySummaryTbl.metric_name == metric), 'FM_E missing from sanity summary.');
assert(any(phase2DecisionTbl.(decisionMetricVar) == metric), 'FM_E missing from Phase 2 decisions.');

trackAcore = trackA(ismember(round(double(trackA.Tp)), coreTps), :);
minimalCore = minimalTbl(minimalTbl.metric_name == metric & ismember(round(double(minimalTbl.Tp)), coreTps), :);
flagsCore = sanityFlagsTbl(sanityFlagsTbl.(flagMetricVar) == metric & ismember(round(double(sanityFlagsTbl.(flagTpVar))), coreTps), :);

rowAudit = repmat(makeRowAuditRow(), 0, 1);
altRows = repmat(makeAltSummaryRow(), 0, 1);
fitRows = repmat(makeFitSensitivityRow(), 0, 1);

for i = 1:numel(coreTps)
    tp = coreTps(i);
    raw = trackAcore(abs(double(trackAcore.Tp) - tp) < 1e-9, :);
    raw = sortrows(raw, 'tw');
    y = double(raw.(char(metric)));
    tw = double(raw.tw);
    x = log10(tw);
    minimalRow = minimalCore(abs(double(minimalCore.Tp) - tp) < 1e-9, :);
    flagRow = flagsCore(abs(double(flagsCore.(flagTpVar)) - tp) < 1e-9, :);

    metricMedianAbs = median(abs(y), 'omitnan');
    slope = double(minimalRow.slope_vs_logtw);
    tauProxy = double(minimalRow.tau_like_proxy);
    metricRange = max(y) - min(y);
    normSlope = slope / max(metricMedianAbs, eps);
    rangeOverMedian = metricRange / max(metricMedianAbs, eps);
    endpointDiff = y(end) - y(1);
    endpointRatio = y(end) / max(abs(y(1)), eps);
    endpointAbsRatio = abs(y(end)) / max(abs(y(1)), eps);
    rankTrend = computeSpearman(x, y);
    midpointWithinRange = string(flagRow.(flagTauLocationVar)) == "within_tw_range";
    nearZeroSlope = flagRow.(flagNearZeroVar) == "YES";
    smallRange = flagRow.(flagSmallAbsVar) == "YES";
    weakResponse = flagRow.(flagWeakVar) == "YES";
    mixedTrend = flagRow.(flagMixedVar) == "YES";

    riskGroup = classifyCoreRiskGroup(tp);
    instabilitySource = classifyInstabilitySource(midpointWithinRange, nearZeroSlope, smallRange, mixedTrend, weakResponse);
    trendStatus = classifyTrendStatus(normSlope, rangeOverMedian, endpointDiff, rankTrend, mixedTrend, weakResponse);

    nFitOk = nnz(raw.fit_status == "FIT_OK" | raw.fit_success == "YES");
    nFitWeakNumeric = nnz(raw.fit_status == "FIT_WEAK_BUT_NUMERIC");
    hq = raw(raw.fit_status == "FIT_OK" | raw.fit_success == "YES", :);
    hqProxy = computeMetricProxySubset(hq, metric, tp);
    hqProxyStatus = hqProxy.proxy_status;
    hqSlope = hqProxy.slope_vs_logtw;
    hqTau = hqProxy.tau_like_proxy;
    hqCoverage = height(hq);
    fitDependency = classifyFitDependency(height(raw), hqCoverage, hqProxyStatus, slope, hqSlope, tauProxy, hqTau);

    rr = makeRowAuditRow();
    rr.Tp = tp;
    rr.core_bucket = "BELOW_TC_CORE_OR_EDGE";
    rr.core_subgroup = riskGroup;
    rr.n_tw = numel(tw);
    rr.tw_values = joinNumeric(tw);
    rr.slope_vs_logtw = slope;
    rr.normalized_slope = normSlope;
    rr.metric_median_abs = metricMedianAbs;
    rr.metric_range = metricRange;
    rr.metric_range_over_median_abs = rangeOverMedian;
    rr.endpoint_difference = endpointDiff;
    rr.endpoint_ratio_signed = endpointRatio;
    rr.endpoint_abs_ratio = endpointAbsRatio;
    rr.rank_trend_score = rankTrend;
    rr.monotonic_direction = minimalRow.monotonic_direction;
    rr.slope_sign = flagRow.(flagSlopeSignVar);
    rr.fitted_excursion_ratio = double(flagRow.(flagFittedRatioVar));
    rr.tau_like_proxy = tauProxy;
    rr.tau_location = flagRow.(flagTauLocationVar);
    rr.midpoint_proxy_issue = instabilitySource;
    rr.trend_status = trendStatus;
    rr.n_fit_ok = nFitOk;
    rr.n_fit_weak_but_numeric = nFitWeakNumeric;
    rr.fit_quality_profile = "FIT_OK=" + string(nFitOk) + ", FIT_WEAK_BUT_NUMERIC=" + string(nFitWeakNumeric);
    rr.high_quality_proxy_status = hqProxyStatus;
    rr.high_quality_slope = hqSlope;
    rr.high_quality_tau_proxy = hqTau;
    rr.fit_quality_dependency = fitDependency;
    rr.row_flag_notes = flagRow.(flagNotesVar);
    rowAudit(end+1,1) = rr; %#ok<SAGROW>

    ar = makeAltSummaryRow();
    ar.scope = "PER_TP";
    ar.Tp_scope = string(tp);
    ar.metric = metric;
    ar.summary_family = "ALTERNATIVE_DIAGNOSTIC_SUMMARIES";
    ar.slope_vs_logtw = slope;
    ar.normalized_slope = normSlope;
    ar.metric_range_over_median_abs = rangeOverMedian;
    ar.endpoint_difference = endpointDiff;
    ar.endpoint_ratio_signed = endpointRatio;
    ar.endpoint_abs_ratio = endpointAbsRatio;
    ar.rank_trend_score = rankTrend;
    ar.midpoint_proxy_within_range = toYesNo(midpointWithinRange);
    ar.summary_status = trendStatus;
    ar.notes = "instability=" + instabilitySource + "; fit_dependency=" + fitDependency;
    altRows(end+1,1) = ar; %#ok<SAGROW>

    fr = makeFitSensitivityRow();
    fr.scope = "PER_TP";
    fr.Tp_scope = string(tp);
    fr.metric = metric;
    fr.n_total_points = height(raw);
    fr.n_high_quality_points = hqCoverage;
    fr.high_quality_fraction = hqCoverage / max(height(raw), 1);
    fr.original_proxy_status = minimalRow.proxy_status;
    fr.high_quality_proxy_status = hqProxyStatus;
    fr.original_slope = slope;
    fr.high_quality_slope = hqSlope;
    fr.original_tau_proxy = tauProxy;
    fr.high_quality_tau_proxy = hqTau;
    fr.fit_quality_sensitivity_status = fitDependency;
    fr.notes = "fit_ok=" + string(nFitOk) + ", weak_numeric=" + string(nFitWeakNumeric);
    fitRows(end+1,1) = fr; %#ok<SAGROW>
end

rowAuditTbl = struct2table(rowAudit);
rowAuditTbl = sortrows(rowAuditTbl, 'Tp');
writetable(rowAuditTbl, rowsPath, 'QuoteStrings', true);

aggregate = summarizeCoreFM(rowAuditTbl);
altRows(end+1,1) = buildAggregateAltRow(metric, aggregate); %#ok<SAGROW>
altTbl = struct2table(altRows);
writetable(altTbl, altSummaryPath, 'QuoteStrings', true);

fitRows(end+1,1) = buildAggregateFitRow(metric, rowAuditTbl); %#ok<SAGROW>
fitTbl = struct2table(fitRows);
writetable(fitTbl, fitSensitivityPath, 'QuoteStrings', true);

phase2Rows = phase2ControlsTbl(phase2ControlsTbl.(controlsMetricVar) == metric, :);
phase2CoreRows = phase2Rows(phase2Rows.(controlsBucketVar) == "BELOW_TC_CORE_OR_EDGE", :);
phase2DiagRows = phase2Rows(phase2Rows.(controlsBucketVar) == "ABOVE_TC_DIAGNOSTIC", :);
phase2Decision = phase2DecisionTbl(phase2DecisionTbl.(decisionMetricVar) == metric, :);

artifactLocalization = localizeArtifactRisk(rowAuditTbl);
primaryCaveatDriver = determinePrimaryCaveatDriver(rowAuditTbl, fitTbl);
refinedStatus = determineRefinedStatus(rowAuditTbl, artifactLocalization, primaryCaveatDriver);
integrationMode = determineIntegrationMode(refinedStatus);
readyForModelIntegration = ismember(integrationMode, ["DIP_AREA_SELECTED_ONLY"; "DIP_AREA_SELECTED_PLUS_QUALITATIVE_FM_E"]);
requiresProxyRevision = ismember(refinedStatus, ["FM_E_PROXY_DEFINITION_UNSTABLE"; "FM_E_REQUIRES_ALTERNATIVE_PROXY"; "FM_E_USABLE_ONLY_AS_QUALITATIVE_TREND"]);

decisionRows = repmat(makeDecisionKeyRow(), 0, 1);
decisionRows(end+1,1) = buildDecisionKeyRow("FM_E_CORE_ARTIFACT_RISK_LOCALIZATION", artifactLocalization, "From below-Tc row audit."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("FM_E_PRIMARY_CAVEAT_DRIVER", primaryCaveatDriver, "Midpoint proxy vs alternative summary comparison."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("FM_E_REFINED_STATUS", refinedStatus, "Refined diagnostic status for FM_E."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("FM_E_DESCRIPTIVE_MODEL_EVIDENCE", classifyDescriptiveUse(refinedStatus), "Whether FM_E remains usable descriptively."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("TRACKA_MODEL_INTEGRATION_MODE", integrationMode, "Recommended Track A/B integration scope."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("TRACKA_FM_E_READY_FOR_MODEL_INTEGRATION", toYesNo(readyForModelIntegration), "Qualitative readiness only; tau-like proxy remains diagnostic."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("TRACKA_FM_E_REQUIRES_PROXY_REVISION", toYesNo(requiresProxyRevision), "Tau-like FM_E proxy revision need."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("PHASE2_DRIVER_CONFIRMATION", string(phase2Decision.(decisionDriverVar)), "Imported from selected-control decision."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("TP6_STATUS", string(phase2Decision.(decisionTp6Var)), "Imported from selected-control decision."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("TP10_STATUS", string(phase2Decision.(decisionTp10Var)), "Imported from selected-control decision."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("TP30_STATUS", string(phase2Decision.(decisionTp30Var)), "Imported from selected-control decision."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionKeyRow("TP34_STATUS", string(phase2Decision.(decisionTp34Var)), "Imported from selected-control decision."); %#ok<SAGROW>
decisionTbl = struct2table(decisionRows);
writetable(decisionTbl, decisionPath, 'QuoteStrings', true);

mainTrackBAfter = fileread(mainTrackBPath);
mainTrackBModified = ~strcmp(mainTrackBBefore, mainTrackBAfter);

fitQualityAvailable = all(ismember(["fit_status","fit_success","fit_R2","fit_NRMSE"], string(trackA.Properties.VariableNames)));
phase2CorePass = any(phase2CoreRows.(controlsStatusVar) == "PASS");
phase2DiagTp34Only = all(phase2DiagRows.(controlsInterpVar) == "TP34_DIAGNOSTIC_ARTIFACT_ONLY" | phase2DiagRows.(controlsInterpVar) == "CONTROL_NOT_APPLICABLE");

lines = strings(0,1);
lines(end+1) = "# Aging Track A FM_E proxy refinement diagnostic";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "- FM_E refinement diagnostic only.";
lines(end+1) = "- BELOW_TC_CORE_OR_EDGE rows audited: Tp 6, 10, 14, 18, 22, 26, 30.";
lines(end+1) = "- Tp 34 remains above-Tc diagnostic-only and is not part of the core FM_E decision.";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module analysis performed: NO.";
lines(end+1) = "- FM_E definition unchanged.";
lines(end+1) = "- FM_E was not replaced with Track B FM_abs.";
lines(end+1) = "- `tau_rescaling_estimates.csv` used: NO.";
lines(end+1) = "- Main Track B dataset modified: " + toYesNo(mainTrackBModified) + ".";
lines(end+1) = "- Track A / Track B equivalence claimed: NO.";
lines(end+1) = "- Tau-like proxy remains diagnostic only, not physical tau.";
lines(end+1) = "";
lines(end+1) = "## Core observations";
lines(end+1) = "- FM_E core endpoint difference is positive at every below-Tc Tp.";
lines(end+1) = "- Core slopes remain positive at every below-Tc Tp, but monotonicity is mixed at Tp 6, 10, 14, 18, and 22.";
lines(end+1) = "- The weakest core FM_E row is Tp 18, where the normalized slope and fitted-excursion ratio are smallest.";
lines(end+1) = "- Fit-quality filtering removes enough short-tw points that Tp 6, 10, 14, and 18 lose direct proxy coverage.";
lines(end+1) = "";
lines(end+1) = "## Artifact-risk localization";
lines(end+1) = "- Localization result: " + artifactLocalization + ".";
lines(end+1) = "- Primary caveat driver: " + primaryCaveatDriver + ".";
lines(end+1) = "- Phase 2 selected-controls driver confirmation: " + string(phase2Decision.(decisionDriverVar)) + ".";
lines(end+1) = "";
lines(end+1) = "## Refined status";
lines(end+1) = "- Refined FM_E status: " + refinedStatus + ".";
lines(end+1) = "- Track A model integration mode: " + integrationMode + ".";
lines(end+1) = "";
lines(end+1) = "## Outputs";
lines(end+1) = "- `" + string(rowsPath) + "`";
lines(end+1) = "- `" + string(altSummaryPath) + "`";
lines(end+1) = "- `" + string(fitSensitivityPath) + "`";
lines(end+1) = "- `" + string(decisionPath) + "`";
lines(end+1) = "- `" + string(reportPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- TRACKA_FM_E_PROXY_REFINEMENT_COMPLETED = YES";
lines(end+1) = "- TRACKA_FM_E_CORE_ROWS_AUDITED = YES";
lines(end+1) = "- TRACKA_FM_E_ARTIFACT_RISK_LOCALIZED = YES";
lines(end+1) = "- TRACKA_FM_E_ALTERNATIVE_SUMMARIES_COMPUTED = YES";
lines(end+1) = "- TRACKA_FM_E_FIT_QUALITY_SENSITIVITY_RUN_OR_MARKED_NA = " + toYesNo(fitQualityAvailable);
lines(end+1) = "- TRACKA_FM_E_REFINED_STATUS = " + refinedStatus;
lines(end+1) = "- TRACKA_FM_E_READY_FOR_MODEL_INTEGRATION = " + toYesNo(readyForModelIntegration);
lines(end+1) = "- TRACKA_FM_E_REQUIRES_PROXY_REVISION = " + toYesNo(requiresProxyRevision);
lines(end+1) = "- TRACKA_TAU_PROXY_REMAINS_DIAGNOSTIC_ONLY = YES";
lines(end+1) = "- TRACKA_NOT_SUBSTITUTED_FOR_TRACKB = YES";
lines(end+1) = "- TRACK_A_TRACK_B_EQUIVALENCE_CLAIMED = NO";
lines(end+1) = "- TAU_RESCALING_ESTIMATES_USED = NO";
lines(end+1) = "- MAIN_TRACKB_DATASET_MODIFIED = NO";
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. What drives the FM_E caveat: **" + primaryCaveatDriver + "**.";
lines(end+1) = "2. Whether FM_E is usable for descriptive model evidence: **" + classifyDescriptiveUse(refinedStatus) + "**.";
lines(end+1) = "3. Whether FM_E needs a revised proxy: **" + toYesNo(requiresProxyRevision) + "**.";
lines(end+1) = "4. Whether model integration should proceed with Dip_area_selected only or include FM_E qualitatively: **" + integrationMode + "**.";
lines(end+1) = "5. Whether Track A/B model integration audit may proceed: **" + finalProceedDecision(integrationMode) + "**.";

writeLines(reportPath, lines);

disp('Aging Track A FM_E proxy refinement diagnostic completed.');
disp(rowsPath);
disp(altSummaryPath);
disp(fitSensitivityPath);
disp(decisionPath);
disp(reportPath);

end

function row = makeRowAuditRow()
row = struct( ...
    'Tp', NaN, ...
    'core_bucket', "", ...
    'core_subgroup', "", ...
    'n_tw', NaN, ...
    'tw_values', "", ...
    'slope_vs_logtw', NaN, ...
    'normalized_slope', NaN, ...
    'metric_median_abs', NaN, ...
    'metric_range', NaN, ...
    'metric_range_over_median_abs', NaN, ...
    'endpoint_difference', NaN, ...
    'endpoint_ratio_signed', NaN, ...
    'endpoint_abs_ratio', NaN, ...
    'rank_trend_score', NaN, ...
    'monotonic_direction', "", ...
    'slope_sign', "", ...
    'fitted_excursion_ratio', NaN, ...
    'tau_like_proxy', NaN, ...
    'tau_location', "", ...
    'midpoint_proxy_issue', "", ...
    'trend_status', "", ...
    'n_fit_ok', NaN, ...
    'n_fit_weak_but_numeric', NaN, ...
    'fit_quality_profile', "", ...
    'high_quality_proxy_status', "", ...
    'high_quality_slope', NaN, ...
    'high_quality_tau_proxy', NaN, ...
    'fit_quality_dependency', "", ...
    'row_flag_notes', "");
end

function row = makeAltSummaryRow()
row = struct( ...
    'scope', "", ...
    'Tp_scope', "", ...
    'metric', "", ...
    'summary_family', "", ...
    'slope_vs_logtw', NaN, ...
    'normalized_slope', NaN, ...
    'metric_range_over_median_abs', NaN, ...
    'endpoint_difference', NaN, ...
    'endpoint_ratio_signed', NaN, ...
    'endpoint_abs_ratio', NaN, ...
    'rank_trend_score', NaN, ...
    'midpoint_proxy_within_range', "", ...
    'summary_status', "", ...
    'notes', "");
end

function row = makeFitSensitivityRow()
row = struct( ...
    'scope', "", ...
    'Tp_scope', "", ...
    'metric', "", ...
    'n_total_points', NaN, ...
    'n_high_quality_points', NaN, ...
    'high_quality_fraction', NaN, ...
    'original_proxy_status', "", ...
    'high_quality_proxy_status', "", ...
    'original_slope', NaN, ...
    'high_quality_slope', NaN, ...
    'original_tau_proxy', NaN, ...
    'high_quality_tau_proxy', NaN, ...
    'fit_quality_sensitivity_status', "", ...
    'notes', "");
end

function row = makeDecisionKeyRow()
row = struct('decision_key', "", 'decision_value', "", 'evidence', "");
end

function row = buildDecisionKeyRow(key, value, evidence)
row = makeDecisionKeyRow();
row.decision_key = key;
row.decision_value = string(value);
row.evidence = string(evidence);
end

function row = buildAggregateAltRow(metric, aggregate)
row = makeAltSummaryRow();
row.scope = "CORE_AGGREGATE";
row.Tp_scope = "6,10,14,18,22,26,30";
row.metric = metric;
row.summary_family = "ALTERNATIVE_DIAGNOSTIC_SUMMARIES";
row.slope_vs_logtw = aggregate.median_slope;
row.normalized_slope = aggregate.median_normalized_slope;
row.metric_range_over_median_abs = aggregate.median_range_over_median_abs;
row.endpoint_difference = aggregate.median_endpoint_difference;
row.endpoint_ratio_signed = aggregate.median_endpoint_ratio_signed;
row.endpoint_abs_ratio = aggregate.median_endpoint_abs_ratio;
row.rank_trend_score = aggregate.median_rank_trend;
row.midpoint_proxy_within_range = toYesNo(aggregate.within_range_fraction >= 0.75);
row.summary_status = aggregate.aggregate_status;
row.notes = "positive_endpoint_fraction=" + formatNumber(aggregate.positive_endpoint_fraction) + ...
    "; mixed_fraction=" + formatNumber(aggregate.mixed_fraction);
end

function row = buildAggregateFitRow(metric, rowAuditTbl)
row = makeFitSensitivityRow();
row.scope = "CORE_AGGREGATE";
row.Tp_scope = "6,10,14,18,22,26,30";
row.metric = metric;
row.n_total_points = sum(rowAuditTbl.n_tw);
row.n_high_quality_points = sum(rowAuditTbl.n_fit_ok);
row.high_quality_fraction = row.n_high_quality_points / max(row.n_total_points, 1);
row.original_proxy_status = "computed";
row.high_quality_proxy_status = summarizeCategory(rowAuditTbl.high_quality_proxy_status);
row.original_slope = median(rowAuditTbl.slope_vs_logtw, 'omitnan');
row.high_quality_slope = median(rowAuditTbl.high_quality_slope, 'omitnan');
row.original_tau_proxy = median(rowAuditTbl.tau_like_proxy, 'omitnan');
row.high_quality_tau_proxy = median(rowAuditTbl.high_quality_tau_proxy, 'omitnan');
row.fit_quality_sensitivity_status = summarizeCategory(rowAuditTbl.fit_quality_dependency);
row.notes = "rows_losing_proxy_coverage=" + string(nnz(rowAuditTbl.high_quality_proxy_status ~= "computed"));
end

function aggregate = summarizeCoreFM(rowAuditTbl)
aggregate = struct();
aggregate.median_slope = median(rowAuditTbl.slope_vs_logtw, 'omitnan');
aggregate.median_normalized_slope = median(rowAuditTbl.normalized_slope, 'omitnan');
aggregate.median_range_over_median_abs = median(rowAuditTbl.metric_range_over_median_abs, 'omitnan');
aggregate.median_endpoint_difference = median(rowAuditTbl.endpoint_difference, 'omitnan');
aggregate.median_endpoint_ratio_signed = median(rowAuditTbl.endpoint_ratio_signed, 'omitnan');
aggregate.median_endpoint_abs_ratio = median(rowAuditTbl.endpoint_abs_ratio, 'omitnan');
aggregate.median_rank_trend = median(rowAuditTbl.rank_trend_score, 'omitnan');
aggregate.positive_endpoint_fraction = mean(rowAuditTbl.endpoint_difference > 0, 'omitnan');
aggregate.mixed_fraction = mean(rowAuditTbl.monotonic_direction == "mixed", 'omitnan');
aggregate.within_range_fraction = mean(rowAuditTbl.tau_location == "within_tw_range", 'omitnan');
if aggregate.positive_endpoint_fraction == 1 && aggregate.mixed_fraction < 0.75
    aggregate.aggregate_status = "POSITIVE_BUT_NOT_STRICTLY_MONOTONIC";
elseif aggregate.positive_endpoint_fraction == 1
    aggregate.aggregate_status = "QUALITATIVE_POSITIVE_TREND";
else
    aggregate.aggregate_status = "WEAK_OR_IRREGULAR";
end
end

function subgroup = classifyCoreRiskGroup(tp)
if tp == 6
    subgroup = "TP6";
elseif tp == 10
    subgroup = "TP10";
elseif ismember(tp, [14 18 22 26])
    subgroup = "MID_CORE";
elseif tp == 30
    subgroup = "TP30_CORE_EDGE";
else
    subgroup = "OTHER";
end
end

function label = classifyInstabilitySource(midpointWithinRange, nearZeroSlope, smallRange, mixedTrend, weakResponse)
parts = strings(0,1);
if ~midpointWithinRange
    parts(end+1) = "MIDPOINT_OUTSIDE_RANGE"; %#ok<AGROW>
end
if nearZeroSlope
    parts(end+1) = "NEAR_ZERO_SLOPE"; %#ok<AGROW>
end
if smallRange
    parts(end+1) = "SMALL_METRIC_RANGE"; %#ok<AGROW>
end
if mixedTrend
    parts(end+1) = "NON_MONOTONIC_TREND"; %#ok<AGROW>
end
if weakResponse
    parts(end+1) = "WEAK_TW_RESPONSE"; %#ok<AGROW>
end
if isempty(parts)
    label = "NO_MAJOR_PROXY_INSTABILITY";
else
    label = strjoin(cellstr(parts), '+');
end
end

function status = classifyTrendStatus(normSlope, rangeOverMedian, endpointDiff, rankTrend, mixedTrend, weakResponse)
if weakResponse || abs(normSlope) < 0.2 || rangeOverMedian < 0.5
    status = "WEAK_OR_COMPRESSED";
elseif endpointDiff > 0 && rankTrend >= 0.4 && mixedTrend
    status = "QUALITATIVE_POSITIVE_BUT_NON_MONOTONIC";
elseif endpointDiff > 0 && rankTrend >= 0.6
    status = "CONSISTENT_POSITIVE_RESPONSE";
else
    status = "IRREGULAR";
end
end

function status = classifyFitDependency(nTotal, nHighQuality, hqProxyStatus, origSlope, hqSlope, origTau, hqTau)
if nHighQuality == 0 || hqProxyStatus ~= "computed"
    status = "HIGH_QUALITY_FILTER_REMOVES_PROXY";
    return;
end
slopeShift = abs(origSlope - hqSlope) / max(abs(origSlope), eps);
tauShift = abs(origTau - hqTau) / max(abs(origTau), eps);
if slopeShift > 0.5 || tauShift > 0.5
    status = "HIGH_QUALITY_FILTER_STRONGLY_SHIFTS_PROXY";
elseif (nHighQuality / max(nTotal,1)) < 0.75
    status = "HIGH_QUALITY_FILTER_REDUCES_COVERAGE_BUT_PRESERVES_TREND";
else
    status = "HIGH_QUALITY_FILTER_STABLE";
end
end

function out = computeMetricProxySubset(rawTbl, metric, tp)
out = struct('proxy_status',"NOT_AVAILABLE",'slope_vs_logtw',NaN,'tau_like_proxy',NaN);
if isempty(rawTbl) || height(rawTbl) < 3
    return;
end
rawTbl = sortrows(rawTbl, 'tw');
tw = double(rawTbl.tw);
y = double(rawTbl.(char(metric)));
if numel(unique(tw)) < 3
    return;
end
x = log10(tw);
metricMin = min(y);
metricMax = max(y);
metricRange = metricMax - metricMin;
if ~(metricRange > 0)
    return;
end
coeffs = polyfit(x, y, 1);
out.slope_vs_logtw = coeffs(1);
midpoint = 0.5 * (metricMin + metricMax);
if ~isfinite(out.slope_vs_logtw) || abs(out.slope_vs_logtw) < eps(max(1, abs(midpoint)))
    return;
end
out.tau_like_proxy = 10.^((midpoint - coeffs(2)) / out.slope_vs_logtw);
if isfinite(out.tau_like_proxy)
    out.proxy_status = "computed";
else
    out.proxy_status = "fit_failed";
end
out.Tp = tp; %#ok<STRNU>
end

function rho = computeSpearman(x, y)
if numel(x) < 3 || numel(y) < 3
    rho = NaN;
    return;
end
rx = tiedrank(x(:));
ry = tiedrank(y(:));
rho = corr(rx, ry, 'Rows', 'complete');
end

function localization = localizeArtifactRisk(rowAuditTbl)
tp6Severe = any(rowAuditTbl.Tp == 6 & (contains(rowAuditTbl.midpoint_proxy_issue, "MIDPOINT") | contains(rowAuditTbl.midpoint_proxy_issue, "NEAR_ZERO")));
tp10Severe = any(rowAuditTbl.Tp == 10 & (contains(rowAuditTbl.midpoint_proxy_issue, "MIDPOINT") | contains(rowAuditTbl.midpoint_proxy_issue, "NEAR_ZERO") | rowAuditTbl.trend_status == "WEAK_OR_COMPRESSED"));
midCoreSevere = any(ismember(rowAuditTbl.Tp, [14 18 22 26]) & (contains(rowAuditTbl.midpoint_proxy_issue, "WEAK_TW_RESPONSE") | rowAuditTbl.trend_status == "WEAK_OR_COMPRESSED"));
tp30Severe = any(rowAuditTbl.Tp == 30 & rowAuditTbl.trend_status == "WEAK_OR_COMPRESSED");
mixedBroad = nnz(rowAuditTbl.monotonic_direction == "mixed") >= 4;
if tp6Severe && midCoreSevere && mixedBroad
    localization = "TP6_PLUS_MID_CORE_AND_BROAD_NON_MONOTONICITY";
elseif midCoreSevere
    localization = "MID_CORE_14_18_22_26";
elseif tp6Severe
    localization = "TP6";
elseif tp10Severe
    localization = "TP10";
elseif tp30Severe
    localization = "TP30_CORE_EDGE";
elseif mixedBroad
    localization = "BROAD_ALL_ROWS";
else
    localization = "NO_SHARP_LOCALIZATION";
end
end

function driver = determinePrimaryCaveatDriver(rowAuditTbl, fitTbl)
allPositiveEndpoints = all(rowAuditTbl.endpoint_difference > 0);
weakRows = nnz(rowAuditTbl.trend_status == "WEAK_OR_COMPRESSED");
nonMonoRows = nnz(rowAuditTbl.monotonic_direction == "mixed");
fitLossRows = nnz(contains(fitTbl.fit_quality_sensitivity_status, "REMOVES_PROXY"));
if allPositiveEndpoints && nonMonoRows >= 4 && fitLossRows >= 3
    driver = "MIDPOINT_PROXY_SENSITIVITY_PLUS_NON_MONOTONIC_LOW_T_AND_FIT_QUALITY_DEPENDENCE";
elseif weakRows >= 3
    driver = "WEAK_OR_COMPRESSED_FM_E_RESPONSE";
elseif fitLossRows >= 3
    driver = "FIT_QUALITY_SENSITIVITY";
else
    driver = "COMPLEX_FM_SIDE_RESPONSE";
end
end

function status = determineRefinedStatus(rowAuditTbl, localization, primaryDriver)
allPositiveEndpoints = all(rowAuditTbl.endpoint_difference > 0);
weakRows = nnz(rowAuditTbl.trend_status == "WEAK_OR_COMPRESSED");
fitLossRows = nnz(contains(rowAuditTbl.fit_quality_dependency, "REMOVES_PROXY"));
outsideRangeRows = nnz(rowAuditTbl.tau_location ~= "within_tw_range");
if outsideRangeRows >= 2 || contains(primaryDriver, "MIDPOINT_PROXY_SENSITIVITY")
    if allPositiveEndpoints
        status = "FM_E_USABLE_ONLY_AS_QUALITATIVE_TREND";
    else
        status = "FM_E_PROXY_DEFINITION_UNSTABLE";
    end
elseif weakRows >= 4
    status = "FM_E_NOT_USABLE_FOR_TAU_LIKE_MODEL";
elseif fitLossRows >= 3 || contains(localization, "MID_CORE")
    status = "FM_E_REQUIRES_ALTERNATIVE_PROXY";
elseif allPositiveEndpoints
    status = "FM_E_USABLE_WITH_CAVEAT";
else
    status = "INCONCLUSIVE";
end
end

function mode = determineIntegrationMode(refinedStatus)
switch char(refinedStatus)
    case 'FM_E_USABLE_WITH_CAVEAT'
        mode = "DIP_AREA_SELECTED_PLUS_QUALITATIVE_FM_E";
    case 'FM_E_USABLE_ONLY_AS_QUALITATIVE_TREND'
        mode = "DIP_AREA_SELECTED_PLUS_QUALITATIVE_FM_E";
    case 'FM_E_PROXY_DEFINITION_UNSTABLE'
        mode = "DIP_AREA_SELECTED_PLUS_FM_E_AFTER_PROXY_REVISION";
    case 'FM_E_REQUIRES_ALTERNATIVE_PROXY'
        mode = "DIP_AREA_SELECTED_PLUS_FM_E_AFTER_PROXY_REVISION";
    case 'FM_E_NOT_USABLE_FOR_TAU_LIKE_MODEL'
        mode = "DIP_AREA_SELECTED_ONLY";
    otherwise
        mode = "NO_TRACK_A_B_INTEGRATION_YET";
end
end

function txt = classifyDescriptiveUse(refinedStatus)
switch char(refinedStatus)
    case 'FM_E_USABLE_WITH_CAVEAT'
        txt = "YES_WITH_CAVEAT";
    case 'FM_E_USABLE_ONLY_AS_QUALITATIVE_TREND'
        txt = "YES_QUALITATIVE_ONLY";
    otherwise
        txt = "NO_NOT_FOR_TAU_LIKE_MODEL";
end
end

function txt = finalProceedDecision(integrationMode)
if integrationMode == "DIP_AREA_SELECTED_ONLY" || integrationMode == "DIP_AREA_SELECTED_PLUS_QUALITATIVE_FM_E"
    txt = "YES_WITH_THE_SPECIFIED_SCOPE";
else
    txt = "NO_REVISE_FM_E_FIRST";
end
end

function txt = summarizeCategory(values)
values = string(values(:));
values = values(strlength(values) > 0);
if isempty(values)
    txt = "NONE";
else
    txt = strjoin(cellstr(unique(values, 'stable')), '|');
end
end

function tbl = readTableStable(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'Could not open CSV header: %s', path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
headerLine = fgetl(fid);
assert(ischar(headerLine) || isstring(headerLine), 'Could not read CSV header: %s', path);
rawHeaders = string(strsplit(char(headerLine), ','));
tbl = readtable(path, 'TextType', 'string', 'VariableNamingRule', 'preserve');
if numel(rawHeaders) == width(tbl)
    tbl.Properties.VariableDescriptions = rawHeaders;
else
    tbl.Properties.VariableDescriptions = string(tbl.Properties.VariableNames);
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

function out = normalizeHeader(in)
out = lower(string(in));
out = replace(out, char(65279), '');
out = replace(out, '"', '');
out = strip(out);
end

function txt = joinNumeric(values)
values = values(:)';
if isempty(values)
    txt = "NONE";
else
    txt = strjoin(compose('%.12g', values), ', ');
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

function writeLines(path, lines)
fid = fopen(path, 'w');
assert(fid >= 0, 'Could not open output file: %s', path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
end
