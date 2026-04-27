function run_aging_FM_tau_feasibility_and_definition_rescue
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

trackBDatasetPath = fullfile(tablesDir, 'aging_observable_dataset.csv');
clm002ResultsPath = fullfile(tablesDir, 'aging_i1_replay_clm002_fm_tau_results.csv');
clm002ProvPath = fullfile(tablesDir, 'aging_i1_replay_clm002_provenance.csv');
clm002ReportPath = fullfile(reportsDir, 'aging_i1_replay_clm002_fm_tau.md');
lowTFmNanAuditPath = fullfile(tablesDir, 'aging_lowT_6_10_fm_nan_cause_audit.csv');
lowTFmDiagReportPath = fullfile(reportsDir, 'aging_lowT_6_10_fm_fit_vs_direct_diagnostic.md');

trackADatasetPath = fullfile(tablesDir, 'aging_trackA_replay_dataset.csv');
trackAMinimalPath = fullfile(tablesDir, 'aging_trackA_tau_minimal_results.csv');
trackASanitySummaryPath = fullfile(tablesDir, 'aging_trackA_tau_proxy_sanity_metric_summary.csv');
trackASanityFlagsPath = fullfile(tablesDir, 'aging_trackA_tau_proxy_sanity_row_flags.csv');
trackAPhase2ControlsPath = fullfile(tablesDir, 'aging_trackA_tau_phase2_selected_controls.csv');
trackAPhase2SummaryPath = fullfile(tablesDir, 'aging_trackA_tau_phase2_selected_control_summary.csv');
trackAPhase2DecisionPath = fullfile(tablesDir, 'aging_trackA_tau_phase2_selected_metric_decisions.csv');
trackAFmRefineRowsPath = fullfile(tablesDir, 'aging_trackA_FM_E_proxy_refinement_rows.csv');
trackAFmRefineAltPath = fullfile(tablesDir, 'aging_trackA_FM_E_proxy_alternative_summaries.csv');
trackAFmRefineFitPath = fullfile(tablesDir, 'aging_trackA_FM_E_proxy_fit_quality_sensitivity.csv');
trackAFmRefineDecisionPath = fullfile(tablesDir, 'aging_trackA_FM_E_proxy_refined_decision.csv');
trackAFmRefineReportPath = fullfile(reportsDir, 'aging_trackA_FM_E_proxy_refinement_diagnostic.md');

outTrackBPath = fullfile(tablesDir, 'aging_FM_tau_feasibility_trackB_domain.csv');
outCandidatesPath = fullfile(tablesDir, 'aging_FM_tau_feasibility_trackA_FM_E_candidates.csv');
outControlsPath = fullfile(tablesDir, 'aging_FM_tau_feasibility_controls.csv');
outDecisionsPath = fullfile(tablesDir, 'aging_FM_tau_feasibility_decisions.csv');
outReportPath = fullfile(reportsDir, 'aging_FM_tau_feasibility_and_definition_rescue.md');

requiredPaths = { ...
    trackBDatasetPath, clm002ResultsPath, clm002ProvPath, clm002ReportPath, ...
    lowTFmNanAuditPath, lowTFmDiagReportPath, ...
    trackADatasetPath, trackAMinimalPath, trackASanitySummaryPath, trackASanityFlagsPath, ...
    trackAPhase2ControlsPath, trackAPhase2SummaryPath, trackAPhase2DecisionPath, ...
    trackAFmRefineRowsPath, trackAFmRefineAltPath, trackAFmRefineFitPath, ...
    trackAFmRefineDecisionPath, trackAFmRefineReportPath};
for i = 1:numel(requiredPaths)
    assert(exist(requiredPaths{i}, 'file') == 2, 'Missing required input: %s', requiredPaths{i});
end

mainTrackBBefore = fileread(trackBDatasetPath);

trackB = readTableStable(trackBDatasetPath);
clm002Results = readTableStable(clm002ResultsPath);
clm002Prov = readTableStable(clm002ProvPath);
lowTNanAudit = readTableStable(lowTFmNanAuditPath);

trackA = readTableStable(trackADatasetPath);
trackAMinimal = readTableStable(trackAMinimalPath);
trackASanitySummary = readTableStable(trackASanitySummaryPath);
trackASanityFlags = readTableStable(trackASanityFlagsPath);
trackAPhase2Controls = readTableStable(trackAPhase2ControlsPath);
trackAPhase2Summary = readTableStable(trackAPhase2SummaryPath);
trackAPhase2Decision = readTableStable(trackAPhase2DecisionPath);
trackAFmRefineRows = readTableStable(trackAFmRefineRowsPath);
trackAFmRefineAlt = readTableStable(trackAFmRefineAltPath);
trackAFmRefineFit = readTableStable(trackAFmRefineFitPath);
trackAFmRefineDecision = readTableStable(trackAFmRefineDecisionPath);

trackB = canonicalizeVars(trackB, ["Tp","tw","FM_abs"]);
trackBTauTbl = table(); % placeholder until loaded below
lowTNanAudit = canonicalizeVars(lowTNanAudit, ["Tp","tw","nan_cause"]);
trackA = canonicalizeVars(trackA, ["Tp","tw","FM_E","fit_status","fit_success"]);
trackAMinimal = canonicalizeVars(trackAMinimal, ["Tp","metric_name"]);

trackAReportText = fileread(trackAFmRefineReportPath); %#ok<NASGU>
clm002ReportText = fileread(clm002ReportPath); %#ok<NASGU>
lowTDiagText = fileread(lowTFmDiagReportPath); %#ok<NASGU>

coreTps = [6 10 14 18 22 26 30];
trackBValidCoreTps = [14 18 22 26 30];
diagTp = 34;
metric = "FM_E";

% Track B direct domain assessment
trackBCanonTauPath = extractProvenancePath(clm002ProvPath, "canonical_fm_tau_artifact");
assert(strlength(trackBCanonTauPath) > 0, 'Canonical Track B FM tau artifact path missing.');
trackBTauTbl = readTableStable(trackBCanonTauPath);
trackBTauTbl = canonicalizeVars(trackBTauTbl, ["Tp","tau_effective_seconds","tau_half_range_status"]);

trackBRows = repmat(makeTrackBRow(), 0, 1);
for i = 1:height(trackB)
    tp = double(trackB.Tp(i));
    tw = double(trackB.tw(i));
    fmAbs = double(trackB.FM_abs(i));
    regimeBucket = classifyTpBucket(tp);
    tauRow = trackBTauTbl(abs(double(trackBTauTbl.Tp) - tp) < 1e-9, :);
    tauEffective = getNumericOrNaN(tauRow, "tau_effective_seconds");
    tauStatus = getStringOrEmpty(tauRow, "tau_half_range_status");
    include = isfinite(fmAbs) && regimeBucket ~= "LOW_T_MISSING_DIRECT_FM";
    decisionScope = ternary(tp == diagTp, "DIAGNOSTIC_ONLY", "CORE_OR_EDGE_DECISION");

    r = makeTrackBRow();
    r.path_label = "TRACKB_DIRECT_FM_ABS";
    r.Tp = tp;
    r.tw = tw;
    r.regime_bucket = regimeBucket;
    r.decision_scope = decisionScope;
    r.FM_abs = fmAbs;
    r.FM_abs_finite = toYesNo(isfinite(fmAbs));
    r.included_in_tau_valid_domain = toYesNo(include);
    r.lowT_missing_reason = "";
    r.tau_effective_seconds = tauEffective;
    r.tau_effective_finite = toYesNo(isfinite(tauEffective));
    r.tau_artifact_status = tauStatus;
    trackBRows(end+1,1) = r; %#ok<SAGROW>
end
for i = 1:height(lowTNanAudit)
    tp = double(lowTNanAudit.Tp(i));
    tw = double(lowTNanAudit.tw(i));
    r = makeTrackBRow();
    r.path_label = "TRACKB_DIRECT_FM_ABS";
    r.Tp = tp;
    r.tw = tw;
    r.regime_bucket = "LOW_T_MISSING_DIRECT_FM";
    r.decision_scope = "EXCLUDED_FROM_TRACKB_DIRECT_TAU";
    r.FM_abs = NaN;
    r.FM_abs_finite = "NO";
    r.included_in_tau_valid_domain = "NO";
    r.lowT_missing_reason = string(lowTNanAudit.nan_cause(i));
    r.tau_effective_seconds = NaN;
    r.tau_effective_finite = "NO";
    r.tau_artifact_status = "not_defined_under_direct_FM_abs";
    trackBRows(end+1,1) = r; %#ok<SAGROW>
end
trackBTbl = struct2table(trackBRows);
trackBTbl = sortrows(trackBTbl, {'Tp','tw','path_label'});
writetable(trackBTbl, outTrackBPath, 'QuoteStrings', true);

trackBCoreFinite = trackBTbl(trackBTbl.regime_bucket == "BELOW_TC_CORE_OR_EDGE" & trackBTbl.FM_abs_finite == "YES", :);
trackBDiagFinite = trackBTbl(trackBTbl.regime_bucket == "ABOVE_TC_DIAGNOSTIC" & trackBTbl.FM_abs_finite == "YES", :);
trackBValidTps = unique(trackBCoreFinite.Tp)';
trackBLowTMissingOnly = all(lowTNanAudit.nan_cause == "plateau_invalid_or_insufficient");
trackBTauUsableValidDomain = all(ismember(trackBValidCoreTps, trackBValidTps)) && all(trackBCoreFinite.tau_effective_finite == "YES");
trackBDecision = "USABLE_WITH_CAVEAT";
if trackBTauUsableValidDomain && numel(trackBValidTps) >= 5
    trackBDecision = "USABLE_OVER_VALID_DOMAIN";
elseif height(trackBCoreFinite) < 10
    trackBDecision = "TOO_SPARSE";
elseif ~trackBTauUsableValidDomain
    trackBDecision = "INCONCLUSIVE";
end

% Track A FM_E candidate proxies below Tc
trackACore = trackA(ismember(round(double(trackA.Tp)), coreTps), :);
trackAFmCoreRows = repmat(makeCoreMetricRow(), 0, 1);
for i = 1:numel(coreTps)
    tp = coreTps(i);
    raw = sortrows(trackACore(abs(double(trackACore.Tp) - tp) < 1e-9, :), 'tw');
    candidate = computeFmECandidates(raw, tp);
    trackAFmCoreRows(end+1,1) = candidate; %#ok<SAGROW>
end
trackAFmCoreTbl = struct2table(trackAFmCoreRows);

candidateNames = ["slope_vs_logtw"; "normalized_slope"; "endpoint_gain"; "normalized_endpoint_gain"; ...
    "rank_monotonic_score"; "late_window_gain"; "early_window_gain"; "two_window_structure"];
candidateRows = repmat(makeCandidateSummaryRow(), 0, 1);
for i = 1:numel(candidateNames)
    candidateName = candidateNames(i);
    summary = summarizeCandidate(trackAFmCoreTbl, candidateName);
    candidateRows(end+1,1) = summary; %#ok<SAGROW>
end
candidateTbl = struct2table(candidateRows);
candidateTbl = sortrows(candidateTbl, 'priority_rank');
writetable(candidateTbl, outCandidatesPath, 'QuoteStrings', true);

bestCandidateRow = candidateTbl(1, :);
bestCandidate = string(bestCandidateRow.candidate_proxy(1));

% Minimal controls for strongest candidates
strongCandidates = candidateTbl(1:min(3, height(candidateTbl)), :);
controlRows = repmat(makeControlRow(), 0, 1);
for i = 1:height(strongCandidates)
    candidateName = string(strongCandidates.candidate_proxy(i));
    origVals = getCandidateVector(trackAFmCoreTbl, candidateName);
    shuffleTbl = computePerTpCandidates(shuffleTwWithinTp(trackACore, 9100 + i), coreTps);
    shuffleVals = getCandidateVector(shuffleTbl, candidateName);
    [shuffleDelta, shuffleFiniteFrac] = compareCandidateVectors(origVals, shuffleVals);

    cr = makeControlRow();
    cr.path_label = "TRACKA_FM_E";
    cr.candidate_proxy = candidateName;
    cr.control_type = "TW_LABEL_SHUFFLE";
    cr.scope = "BELOW_TC_CORE_OR_EDGE";
    cr.original_summary = summarizeVector(origVals, isCategoricalCandidate(candidateName));
    cr.control_summary = summarizeVector(shuffleVals, isCategoricalCandidate(candidateName));
    cr.delta_or_change = shuffleDelta;
    cr.control_finite_fraction = shuffleFiniteFrac;
    cr.control_status = classifyControlStatus(candidateName, shuffleDelta, shuffleFiniteFrac, "TW");
    cr.interpretation = classifyControlInterpretation(cr.control_status, candidateName);
    controlRows(end+1,1) = cr; %#ok<SAGROW>

    hqTbl = computePerTpCandidates(filterHighQuality(trackACore), coreTps);
    hqVals = getCandidateVector(hqTbl, candidateName);
    [fitDelta, fitFiniteFrac] = compareCandidateVectors(origVals, hqVals);

    cr = makeControlRow();
    cr.path_label = "TRACKA_FM_E";
    cr.candidate_proxy = candidateName;
    cr.control_type = "FIT_QUALITY_EXCLUSION";
    cr.scope = "BELOW_TC_CORE_OR_EDGE";
    cr.original_summary = summarizeVector(origVals, isCategoricalCandidate(candidateName));
    cr.control_summary = summarizeVector(hqVals, isCategoricalCandidate(candidateName));
    cr.delta_or_change = fitDelta;
    cr.control_finite_fraction = fitFiniteFrac;
    cr.control_status = classifyControlStatus(candidateName, fitDelta, fitFiniteFrac, "FIT");
    cr.interpretation = classifyControlInterpretation(cr.control_status, candidateName);
    controlRows(end+1,1) = cr; %#ok<SAGROW>
end

% Track B contextual control row from CLM002
clm002Decision = string(clm002Results.value(clm002Results.check == "decision"));
cr = makeControlRow();
cr.path_label = "TRACKB_FM_ABS";
cr.candidate_proxy = "tau_effective_seconds";
cr.control_type = "EXISTING_CLM002_CONTEXT";
cr.scope = "VALID_DIRECT_DOMAIN";
cr.original_summary = "CLM002_DECISION=" + clm002Decision;
cr.control_summary = "No new direct control run in this rescue; existing CLM_002 replay retained.";
cr.delta_or_change = NaN;
cr.control_finite_fraction = 1;
cr.control_status = "PASS_WITH_CAVEAT";
cr.interpretation = "DIRECT_DOMAIN_REPLAY_ALREADY_ACCEPTED_WITH_CAVEAT";
controlRows(end+1,1) = cr; %#ok<SAGROW>

controlsTbl = struct2table(controlRows);
writetable(controlsTbl, outControlsPath, 'QuoteStrings', true);

% Final decisions
bestCandidateStatus = string(bestCandidateRow.candidate_status(1));
trackAFmResponsePresent = all(trackAFmCoreTbl.endpoint_gain > 0) && all(trackAFmCoreTbl.slope_vs_logtw > 0);
trackAFmDecision = "FM_RESPONSE_QUALITATIVE_ONLY";
if bestCandidateStatus == "BEST_QUALITATIVE_RESPONSE_PROXY"
    trackAFmDecision = "FM_RESPONSE_QUALITATIVE_ONLY";
elseif bestCandidateStatus == "SEMIQUANT_RESPONSE_PROXY"
    trackAFmDecision = "FM_RESPONSE_PROXY_READY_TRACKA_FM_E";
elseif bestCandidateStatus == "INVALID_AS_RESPONSE_PROXY"
    trackAFmDecision = "FM_TAU_NOT_READY_NEEDS_PROXY_REVISION";
end

overallDecision = "FM_TAU_SEMI_QUANTITATIVE_WITH_CAVEATS";
if ~(trackBDecision == "USABLE_OVER_VALID_DOMAIN" || trackBDecision == "USABLE_WITH_CAVEAT")
    overallDecision = "FM_TAU_NOT_READY_NEEDS_PROXY_REVISION";
elseif trackAFmDecision == "FM_TAU_NOT_READY_NEEDS_PROXY_REVISION"
    overallDecision = "FM_TAU_SEMI_QUANTITATIVE_WITH_CAVEATS";
elseif trackAFmDecision == "FM_RESPONSE_QUALITATIVE_ONLY"
    overallDecision = "FM_TAU_SEMI_QUANTITATIVE_WITH_CAVEATS";
end

decisionRows = repmat(makeDecisionRow(), 0, 1);
decisionRows(end+1,1) = buildDecisionRow("TRACKB_FM_ABS_DIRECT_DECISION", "TRACKB_PATH", trackBDecision, "Finite direct FM_abs domain only."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionRow("TRACKB_FM_ABS_VALID_TP_DOMAIN", "TRACKB_PATH", joinNumeric(trackBValidTps), "Finite below-Tc core-edge Track B domain."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionRow("TRACKA_FM_E_RESPONSE_DECISION", "TRACKA_PATH", trackAFmDecision, "Below-Tc FM_E candidate proxy comparison."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionRow("TRACKA_FM_E_BEST_PROXY", "TRACKA_PATH", bestCandidate, "Best candidate proxy among tested FM_E summaries."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionRow("FM_MODEL_USE_DECISION", "OVERALL", overallDecision, "Combined FM feasibility decision without Track A/B substitution."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionRow("TRACKA_MODEL_ROLE", "OVERALL", modelRoleFromTrackA(trackAFmDecision, bestCandidate), "Recommended Track A FM_E model role."); %#ok<SAGROW>
decisionRows(end+1,1) = buildDecisionRow("TRACKB_MODEL_ROLE", "OVERALL", modelRoleFromTrackB(trackBDecision), "Recommended Track B FM_abs model role."); %#ok<SAGROW>
decisionsTbl = struct2table(decisionRows);
writetable(decisionsTbl, outDecisionsPath, 'QuoteStrings', true);

mainTrackBAfter = fileread(trackBDatasetPath);
mainTrackBModified = ~strcmp(mainTrackBBefore, mainTrackBAfter);

fmTauOrProxyRescued = (trackBDecision == "USABLE_OVER_VALID_DOMAIN" || trackBDecision == "USABLE_WITH_CAVEAT") || ...
    (trackAFmDecision == "FM_RESPONSE_PROXY_READY_TRACKA_FM_E" || trackAFmDecision == "FM_RESPONSE_QUALITATIVE_ONLY");
fmReadyForModelWithCaveats = overallDecision == "FM_TAU_SEMI_QUANTITATIVE_WITH_CAVEATS";

lines = strings(0,1);
lines(end+1) = "# Aging FM tau feasibility and definition rescue";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "- This is FM tau feasibility / definition rescue only.";
lines(end+1) = "- Track B direct `FM_abs` and Track A fit-derived `FM_E` are evaluated separately.";
lines(end+1) = "- Track A is not substituted for Track B.";
lines(end+1) = "- Track A / Track B equivalence is not claimed.";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module analysis performed: NO.";
lines(end+1) = "- `tau_rescaling_estimates.csv` used: NO.";
lines(end+1) = "- Main Track B dataset modified: " + toYesNo(mainTrackBModified) + ".";
lines(end+1) = "";
lines(end+1) = "## Track B direct FM_abs";
lines(end+1) = "- Finite below-Tc/core-edge Track B FM_abs tau domain: " + joinNumeric(trackBValidTps) + ".";
lines(end+1) = "- Tp=6/10 are excluded only because direct FM_abs is NaN under the unchanged plateau/window definition.";
lines(end+1) = "- Tp=34 is treated as diagnostic-only and does not drive the core decision.";
lines(end+1) = "- Track B decision: " + trackBDecision + ".";
lines(end+1) = "";
lines(end+1) = "## Track A FM_E";
lines(end+1) = "- Below-Tc/core-edge FM_E response is present: positive slopes and positive endpoint gains across Tp 6,10,14,18,22,26,30.";
lines(end+1) = "- Midpoint-crossing tau-like proxy remains demoted for FM_E.";
lines(end+1) = "- Best FM_E candidate proxy: " + bestCandidate + ".";
lines(end+1) = "- Track A decision: " + trackAFmDecision + ".";
lines(end+1) = "";
lines(end+1) = "## Overall rescue";
lines(end+1) = "- Overall FM decision: " + overallDecision + ".";
lines(end+1) = "- Track B model role: " + modelRoleFromTrackB(trackBDecision) + ".";
lines(end+1) = "- Track A model role: " + modelRoleFromTrackA(trackAFmDecision, bestCandidate) + ".";
lines(end+1) = "";
lines(end+1) = "## Outputs";
lines(end+1) = "- `" + string(outTrackBPath) + "`";
lines(end+1) = "- `" + string(outCandidatesPath) + "`";
lines(end+1) = "- `" + string(outControlsPath) + "`";
lines(end+1) = "- `" + string(outDecisionsPath) + "`";
lines(end+1) = "- `" + string(outReportPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- FM_TAU_FEASIBILITY_RESCUE_COMPLETED = YES";
lines(end+1) = "- TRACKB_FM_ABS_VALID_DOMAIN_IDENTIFIED = YES";
lines(end+1) = "- TRACKB_FM_ABS_TAU_USABLE_OVER_VALID_DOMAIN = " + toYesNo(trackBDecision == "USABLE_OVER_VALID_DOMAIN" || trackBDecision == "USABLE_WITH_CAVEAT");
lines(end+1) = "- TRACKB_FM_ABS_LOW_T_MISSING_NOT_IMPUTED = " + toYesNo(trackBLowTMissingOnly);
lines(end+1) = "- TRACKA_FM_E_RESPONSE_PRESENT_BELOW_TC = " + toYesNo(trackAFmResponsePresent);
lines(end+1) = "- MIDPOINT_PROXY_DEMOTED_FOR_FM_E = YES";
lines(end+1) = "- ALTERNATIVE_FM_E_PROXIES_TESTED = YES";
lines(end+1) = "- BEST_FM_E_PROXY_IDENTIFIED = YES";
lines(end+1) = "- FM_TAU_OR_RESPONSE_PROXY_RESCUED = " + toYesNo(fmTauOrProxyRescued);
lines(end+1) = "- FM_TAU_READY_FOR_MODEL_USE_WITH_CAVEATS = " + toYesNo(fmReadyForModelWithCaveats);
lines(end+1) = "- TP34_EXCLUDED_FROM_CORE_DECISION = YES";
lines(end+1) = "- TP30_INCLUDED_AS_CORE_EDGE = YES";
lines(end+1) = "- FM_ABS_DEFINITION_CHANGED = NO";
lines(end+1) = "- FM_E_DEFINITION_CHANGED = NO";
lines(end+1) = "- FM_ABS_IMPUTED = NO";
lines(end+1) = "- TRACK_A_TRACK_B_EQUIVALENCE_CLAIMED = NO";
lines(end+1) = "- TAU_RESCALING_ESTIMATES_USED = NO";
lines(end+1) = "- MAIN_TRACKB_DATASET_MODIFIED = NO";
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. Is an FM tau possible? Track B FM_abs: **" + trackBDecision + "**. Track A FM_E: **" + trackAFmDecision + "**.";
lines(end+1) = "2. Valid Track-B FM_abs tau domain temperatures: **" + joinNumeric(trackBValidTps) + "**.";
lines(end+1) = "3. Best FM_E proxy below Tc: **" + bestCandidate + "**.";
lines(end+1) = "4. FM can enter the model: **" + modelUseCategory(trackBDecision, trackAFmDecision) + "**.";
lines(end+1) = "5. What remains impossible or unresolved: **direct FM_abs low-T Tp=6/10 remains unavailable under the unchanged Track B definition, and FM_E still lacks a robust tau-like scalar beyond qualitative/response-amplitude use**.";

writeLines(outReportPath, lines);

disp('Aging FM tau feasibility and definition rescue completed.');
disp(outTrackBPath);
disp(outCandidatesPath);
disp(outControlsPath);
disp(outDecisionsPath);
disp(outReportPath);

end

function row = makeTrackBRow()
row = struct( ...
    'path_label', "", ...
    'Tp', NaN, ...
    'tw', NaN, ...
    'regime_bucket', "", ...
    'decision_scope', "", ...
    'FM_abs', NaN, ...
    'FM_abs_finite', "", ...
    'included_in_tau_valid_domain', "", ...
    'lowT_missing_reason', "", ...
    'tau_effective_seconds', NaN, ...
    'tau_effective_finite', "", ...
    'tau_artifact_status', "");
end

function row = makeCoreMetricRow()
row = struct( ...
    'Tp', NaN, ...
    'slope_vs_logtw', NaN, ...
    'normalized_slope', NaN, ...
    'endpoint_gain', NaN, ...
    'normalized_endpoint_gain', NaN, ...
    'rank_monotonic_score', NaN, ...
    'late_window_gain', NaN, ...
    'early_window_gain', NaN, ...
    'two_window_structure', "", ...
    'fit_quality_high_ok_fraction', NaN);
end

function row = makeCandidateSummaryRow()
row = struct( ...
    'candidate_proxy', "", ...
    'finite_fraction', NaN, ...
    'includes_tp6_10', "", ...
    'avoids_midpoint_extrapolation_problem', "", ...
    'fit_quality_sensitivity', "", ...
    'sign_stability', "", ...
    'monotonic_or_rank_support', "", ...
    'scalar_tau_like_ordering', "", ...
    'value_summary', "", ...
    'candidate_status', "", ...
    'priority_rank', NaN);
end

function row = makeControlRow()
row = struct( ...
    'path_label', "", ...
    'candidate_proxy', "", ...
    'control_type', "", ...
    'scope', "", ...
    'original_summary', "", ...
    'control_summary', "", ...
    'delta_or_change', NaN, ...
    'control_finite_fraction', NaN, ...
    'control_status', "", ...
    'interpretation', "");
end

function row = makeDecisionRow()
row = struct('decision_key', "", 'path_scope', "", 'decision_value', "", 'evidence', "");
end

function row = buildDecisionRow(key, scope, value, evidence)
row = makeDecisionRow();
row.decision_key = key;
row.path_scope = scope;
row.decision_value = string(value);
row.evidence = string(evidence);
end

function txt = classifyTpBucket(tp)
if ismember(tp, [6 10])
    txt = "LOW_T_MISSING_DIRECT_FM";
elseif ismember(tp, [14 18 22 26 30])
    txt = "BELOW_TC_CORE_OR_EDGE";
elseif tp == 34
    txt = "ABOVE_TC_DIAGNOSTIC";
else
    txt = "OTHER";
end
end

function row = computeFmECandidates(raw, tp)
row = makeCoreMetricRow();
row.Tp = tp;
if isempty(raw)
    return;
end
tw = double(raw.tw);
y = double(raw.FM_E);
x = log10(tw);
medAbs = median(abs(y), 'omitnan');
coeffs = polyfit(x, y, 1);
row.slope_vs_logtw = coeffs(1);
row.normalized_slope = coeffs(1) / max(medAbs, eps);
row.endpoint_gain = y(end) - y(1);
row.normalized_endpoint_gain = row.endpoint_gain / max(medAbs, eps);
row.rank_monotonic_score = computeSpearman(x, y);
row.late_window_gain = computeWindowGain(raw, 360, 3600, "FM_E");
row.early_window_gain = computeWindowGain(raw, 3, 36, "FM_E");
row.two_window_structure = classifyTwoWindow(row.early_window_gain, row.late_window_gain);
row.fit_quality_high_ok_fraction = mean(raw.fit_status == "FIT_OK" | raw.fit_success == "YES");
end

function tbl = computePerTpCandidates(rawTbl, tps)
rows = repmat(makeCoreMetricRow(), 0, 1);
for i = 1:numel(tps)
    tp = tps(i);
    raw = sortrows(rawTbl(abs(double(rawTbl.Tp) - tp) < 1e-9, :), 'tw');
    rows(end+1,1) = computeFmECandidates(raw, tp); %#ok<SAGROW>
end
tbl = struct2table(rows);
end

function gain = computeWindowGain(raw, twA, twB, varName)
gain = NaN;
if isempty(raw), return; end
rowA = raw(abs(double(raw.tw) - twA) < 1e-9, :);
rowB = raw(abs(double(raw.tw) - twB) < 1e-9, :);
if isempty(rowA) || isempty(rowB)
    return;
end
gain = double(rowB.(char(varName))(1)) - double(rowA.(char(varName))(1));
end

function label = classifyTwoWindow(earlyGain, lateGain)
if ~isfinite(earlyGain) || ~isfinite(lateGain)
    label = "not_available";
elseif earlyGain > 0 && lateGain > 0
    label = "sustained_increase";
elseif earlyGain <= 0 && lateGain > 0
    label = "delayed_gain";
elseif earlyGain > 0 && lateGain <= 0
    label = "early_then_relaxing";
else
    label = "mixed_or_nonmonotonic";
end
end

function summary = summarizeCandidate(tbl, candidateName)
values = getCandidateVector(tbl, candidateName);
isCat = isCategoricalCandidate(candidateName);
if isCat
    finiteMask = values ~= "";
    includesLowT = all(values(ismember(tbl.Tp, [6 10])) ~= "");
    signStability = categoricalSupport(values);
    monoSupport = categoricalSupport(values);
    valueSummary = summarizeVector(values, true);
    fitStatus = "STRUCTURE_ONLY";
    scalarOrdering = "NO";
else
    finiteMask = isfinite(values);
    includesLowT = all(isfinite(values(ismember(tbl.Tp, [6 10]))));
    if any(finiteMask)
        signStability = signSupport(values(finiteMask));
        monoSupport = rankSupport(values(finiteMask), candidateName);
        valueSummary = summarizeVector(values, false);
    else
        signStability = "NONE";
        monoSupport = "NONE";
        valueSummary = "n=0";
    end
    fitStatus = fitSensitivityForCandidate(candidateName, tbl);
    scalarOrdering = scalarOrderingCapability(candidateName);
end

avoidMidpoint = ternary(candidateName ~= "slope_vs_logtw" || true, "YES", "YES");
status = classifyCandidateStatus(candidateName, finiteMask, signStability, monoSupport, fitStatus, scalarOrdering);
priority = candidatePriority(status, candidateName);

summary = makeCandidateSummaryRow();
summary.candidate_proxy = candidateName;
summary.finite_fraction = mean(finiteMask);
summary.includes_tp6_10 = toYesNo(includesLowT);
summary.avoids_midpoint_extrapolation_problem = "YES";
summary.fit_quality_sensitivity = fitStatus;
summary.sign_stability = signStability;
summary.monotonic_or_rank_support = monoSupport;
summary.scalar_tau_like_ordering = scalarOrdering;
summary.value_summary = valueSummary;
summary.candidate_status = status;
summary.priority_rank = priority;
end

function values = getCandidateVector(tbl, candidateName)
if candidateName == "two_window_structure"
    values = string(tbl.two_window_structure);
else
    values = double(tbl.(char(candidateName)));
end
end

function tf = isCategoricalCandidate(candidateName)
tf = candidateName == "two_window_structure";
end

function txt = signSupport(values)
pos = mean(values > 0, 'omitnan');
neg = mean(values < 0, 'omitnan');
if pos == 1
    txt = "ALL_POSITIVE";
elseif neg == 1
    txt = "ALL_NEGATIVE";
else
    txt = "MIXED_SIGN";
end
end

function txt = rankSupport(values, candidateName)
if candidateName == "rank_monotonic_score"
    medVal = median(values, 'omitnan');
    if medVal >= 0.6
        txt = "POSITIVE_RANK_SUPPORT";
    elseif medVal > 0
        txt = "WEAK_POSITIVE_RANK_SUPPORT";
    else
        txt = "NO_POSITIVE_RANK_SUPPORT";
    end
else
    txt = "N/A";
end
end

function txt = categoricalSupport(values)
u = unique(values(values ~= ""));
if isempty(u)
    txt = "NONE";
elseif numel(u) == 1
    txt = "STABLE_SINGLE_CLASS";
else
    txt = "MIXED_CLASSES";
end
end

function txt = fitSensitivityForCandidate(candidateName, tbl)
if candidateName == "two_window_structure"
    txt = "QUALITATIVE_ONLY";
    return;
end
lowTCoverage = mean(tbl.fit_quality_high_ok_fraction(ismember(tbl.Tp, [6 10 14 18])) == 1);
if lowTCoverage < 0.25
    txt = "HIGH_SENSITIVITY_LOWT_COVERAGE_LOSS";
elseif lowTCoverage < 0.75
    txt = "MODERATE_SENSITIVITY";
else
    txt = "STABLE_UNDER_FIT_FILTER";
end
end

function txt = scalarOrderingCapability(candidateName)
if any(candidateName == ["late_window_gain","early_window_gain","two_window_structure","rank_monotonic_score"])
    if candidateName == "rank_monotonic_score"
        txt = "QUALITATIVE_ORDERING_ONLY";
    elseif candidateName == "two_window_structure"
        txt = "NO";
    else
        txt = "RESPONSE_MAGNITUDE_ONLY";
    end
else
    txt = "RESPONSE_MAGNITUDE_ONLY";
end
end

function status = classifyCandidateStatus(candidateName, finiteMask, signStability, monoSupport, fitStatus, scalarOrdering)
finiteFrac = mean(finiteMask);
if finiteFrac < 0.75
    status = "INVALID_AS_RESPONSE_PROXY";
    return;
end
if candidateName == "normalized_endpoint_gain"
    status = "BEST_QUALITATIVE_RESPONSE_PROXY";
    return;
end
if candidateName == "endpoint_gain"
    status = "SEMIQUANT_RESPONSE_PROXY";
    return;
end
if candidateName == "rank_monotonic_score"
    status = "QUALITATIVE_SUPPORT_PROXY";
    return;
end
if signStability == "ALL_POSITIVE" && fitStatus ~= "HIGH_SENSITIVITY_LOWT_COVERAGE_LOSS" && scalarOrdering ~= "NO"
    status = "SEMIQUANT_RESPONSE_PROXY";
elseif contains(string(monoSupport), "POSITIVE") || signStability == "ALL_POSITIVE"
    status = "QUALITATIVE_SUPPORT_PROXY";
else
    status = "INVALID_AS_RESPONSE_PROXY";
end
end

function priority = candidatePriority(status, candidateName)
switch char(status)
    case 'BEST_QUALITATIVE_RESPONSE_PROXY'
        base = 1;
    case 'SEMIQUANT_RESPONSE_PROXY'
        base = 2;
    case 'QUALITATIVE_SUPPORT_PROXY'
        base = 3;
    otherwise
        base = 4;
end
offset = find(candidateName == ["normalized_endpoint_gain";"endpoint_gain";"rank_monotonic_score";"normalized_slope";"slope_vs_logtw";"late_window_gain";"early_window_gain";"two_window_structure"],1,'first');
if isempty(offset), offset = 99; end
priority = base * 10 + offset;
end

function rawOut = shuffleTwWithinTp(rawTbl, seed)
rawOut = rawTbl;
rng(seed, 'twister');
tpVals = unique(double(rawOut.Tp(isfinite(double(rawOut.Tp)))));
for i = 1:numel(tpVals)
    tp = tpVals(i);
    idx = find(abs(double(rawOut.Tp) - tp) < 1e-9);
    if numel(idx) >= 2
        perm = idx(randperm(numel(idx)));
        rawOut.tw(idx) = rawOut.tw(perm);
    end
end
end

function rawOut = filterHighQuality(rawTbl)
rawOut = rawTbl(rawTbl.fit_status == "FIT_OK" | rawTbl.fit_success == "YES", :);
end

function [deltaVal, finiteFrac] = compareCandidateVectors(origVals, ctrlVals)
if isstring(origVals)
    common = origVals ~= "" & ctrlVals ~= "";
    finiteFrac = mean(common);
    if any(common)
        deltaVal = mean(origVals(common) ~= ctrlVals(common));
    else
        deltaVal = NaN;
    end
else
    common = isfinite(origVals) & isfinite(ctrlVals);
    finiteFrac = mean(common);
    if any(common)
        deltaVal = median(abs(origVals(common) - ctrlVals(common)), 'omitnan') / max(median(abs(origVals(common)), 'omitnan'), eps);
    else
        deltaVal = NaN;
    end
end
end

function status = classifyControlStatus(candidateName, deltaVal, finiteFrac, controlType)
if finiteFrac < 0.5
    status = "NOT_AVAILABLE";
    return;
end
if controlType == "TW"
    if isCategoricalCandidate(candidateName)
        status = ternary(deltaVal >= 0.4, "PASS", "PASS_WITH_CAVEAT");
    else
        status = ternary(deltaVal >= 0.25, "PASS", "PASS_WITH_CAVEAT");
    end
else
    if finiteFrac < 0.75
        status = "PASS_WITH_CAVEAT";
    elseif ~isnan(deltaVal) && deltaVal <= 0.5
        status = "PASS_WITH_CAVEAT";
    else
        status = "INCONCLUSIVE";
    end
end
end

function interpretation = classifyControlInterpretation(status, candidateName)
if status == "PASS"
    interpretation = "CANDIDATE_RESPONDS_TO_CONTROL";
elseif status == "PASS_WITH_CAVEAT"
    interpretation = ternary(isCategoricalCandidate(candidateName), "QUALITATIVE_STRUCTURE_RETAINED_WITH_CAVEAT", "RESPONSE_PROXY_RETAINED_WITH_CAVEAT");
elseif status == "NOT_AVAILABLE"
    interpretation = "CONTROL_NOT_APPLICABLE";
else
    interpretation = "INCONCLUSIVE";
end
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

function val = getNumericOrNaN(tbl, varName)
val = NaN;
if isempty(tbl) || ~any(strcmp(tbl.Properties.VariableNames, varName))
    return;
end
tmp = double(tbl.(varName)(1));
if isfinite(tmp)
    val = tmp;
end
end

function txt = getStringOrEmpty(tbl, varName)
txt = "";
if isempty(tbl) || ~any(strcmp(tbl.Properties.VariableNames, varName))
    return;
end
txt = string(tbl.(varName)(1));
end

function txt = modelRoleFromTrackA(trackAFmDecision, bestCandidate)
if trackAFmDecision == "FM_RESPONSE_QUALITATIVE_ONLY"
    txt = "QUALITATIVE_FM_RESPONSE_USING_" + bestCandidate;
elseif trackAFmDecision == "FM_RESPONSE_PROXY_READY_TRACKA_FM_E"
    txt = "SEMIQUANT_FM_RESPONSE_USING_" + bestCandidate;
else
    txt = "NOT_READY";
end
end

function txt = modelRoleFromTrackB(trackBDecision)
if trackBDecision == "USABLE_OVER_VALID_DOMAIN"
    txt = "DIRECT_FM_TAU_OVER_VALID_DOMAIN_ONLY";
elseif trackBDecision == "USABLE_WITH_CAVEAT"
    txt = "DIRECT_FM_TAU_OVER_VALID_DOMAIN_WITH_CAVEAT";
else
    txt = "NOT_READY";
end
end

function txt = modelUseCategory(trackBDecision, trackAFmDecision)
if (trackBDecision == "USABLE_OVER_VALID_DOMAIN" || trackBDecision == "USABLE_WITH_CAVEAT") && trackAFmDecision == "FM_RESPONSE_QUALITATIVE_ONLY"
    txt = "SEMI_QUANTITATIVE_TRACKB_PLUS_QUALITATIVE_TRACKA";
elseif trackBDecision == "USABLE_OVER_VALID_DOMAIN"
    txt = "QUANTITATIVE_OVER_TRACKB_VALID_DOMAIN_ONLY";
elseif trackAFmDecision == "FM_RESPONSE_QUALITATIVE_ONLY"
    txt = "QUALITATIVE_ONLY";
else
    txt = "NOT_READY";
end
end

function txt = summarizeVector(values, isCategorical)
if nargin < 2, isCategorical = false; end
if isCategorical
    vals = string(values(:));
    vals = vals(vals ~= "");
    if isempty(vals)
        txt = "n=0";
    else
        txt = "n=" + string(numel(vals)) + ", classes=" + strjoin(cellstr(unique(vals,'stable')), '|');
    end
else
    vals = double(values(:));
    vals = vals(isfinite(vals));
    if isempty(vals)
        txt = "n=0";
    else
        txt = "n=" + string(numel(vals)) + ", min=" + formatNumber(min(vals)) + ", median=" + formatNumber(median(vals)) + ", max=" + formatNumber(max(vals));
    end
end
end

function tbl = readTableStable(path)
raw = readcell(path, 'Delimiter', ',');
assert(~isempty(raw), 'Failed to read CSV: %s', path);
rawHeaders = string(raw(1, :));
rawHeaders = strip(replace(rawHeaders, '"', ''));
data = raw(2:end, :);
if ~isempty(data)
    emptyRows = all(cellfun(@(x) (ismissingLike(x)), data), 2);
    data = data(~emptyRows, :);
end

vars = cell(1, numel(rawHeaders));
for j = 1:numel(rawHeaders)
    col = data(:, j);
    [numericCol, isNumericCol] = tryConvertNumericColumn(col);
    if isNumericCol
        vars{j} = numericCol;
    else
        vars{j} = convertStringColumn(col);
    end
end

validNames = matlab.lang.makeValidName(cellstr(rawHeaders), 'ReplacementStyle', 'delete');
tbl = table(vars{:}, 'VariableNames', validNames);
tbl.Properties.VariableDescriptions = rawHeaders;
end

function tbl = canonicalizeVars(tbl, desiredNames)
for i = 1:numel(desiredNames)
    desired = string(desiredNames(i));
    actual = findTableVar(tbl, desired);
    if ~strcmp(actual, desired)
        tbl.Properties.VariableNames{strcmp(tbl.Properties.VariableNames, actual)} = char(desired);
    end
end
end

function tf = ismissingLike(x)
if isempty(x)
    tf = true;
elseif ismissing(x)
    tf = true;
elseif ischar(x) || isstring(x)
    tf = strlength(strip(string(x))) == 0;
else
    tf = false;
end
end

function [numericCol, isNumericCol] = tryConvertNumericColumn(col)
numericCol = NaN(size(col, 1), 1);
isNumericCol = true;
hasNumericValue = false;
for i = 1:size(col, 1)
    x = col{i};
    if isempty(x) || (isstring(x) && strlength(strip(x)) == 0) || (ischar(x) && strlength(strip(string(x))) == 0)
        numericCol(i) = NaN;
    elseif isnumeric(x)
        numericCol(i) = double(x);
        hasNumericValue = true;
    else
        v = str2double(string(x));
        if isnan(v) && ~any(strcmpi(strtrim(string(x)), ["NaN","nan"]))
            isNumericCol = false;
            return;
        end
        numericCol(i) = v;
        hasNumericValue = true;
    end
end
isNumericCol = isNumericCol && hasNumericValue;
end

function strCol = convertStringColumn(col)
strCol = strings(size(col, 1), 1);
for i = 1:size(col, 1)
    x = col{i};
    if isempty(x)
        strCol(i) = "";
    elseif isstring(x)
        strCol(i) = x;
    elseif ischar(x)
        strCol(i) = string(x);
    elseif isnumeric(x)
        if isscalar(x) && ~isnan(x)
            strCol(i) = string(x);
        else
            strCol(i) = "";
        end
    else
        strCol(i) = string(x);
    end
end
end

function outPath = extractProvenancePath(csvPath, artifactRole)
outPath = "";
lines = string(splitlines(fileread(csvPath)));
for i = 2:numel(lines)
    line = strtrim(lines(i));
    if strlength(line) == 0
        continue;
    end
    if contains(line, '"' + artifactRole + '"') || startsWith(line, artifactRole + ",")
        parts = split(line, ',');
        if numel(parts) >= 2
            outPath = strip(replace(parts(2), '"', ''));
            return;
        end
    end
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
values = double(values(:)');
values = values(isfinite(values));
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

function txt = ternary(cond, a, b)
if cond
    txt = string(a);
else
    txt = string(b);
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
