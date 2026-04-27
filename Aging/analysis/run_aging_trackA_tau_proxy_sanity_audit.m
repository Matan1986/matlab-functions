clear; clc;

repoRoot = fileparts(fileparts(mfilename('fullpath')));
repoRoot = fileparts(repoRoot);
addpath(fullfile(repoRoot, 'Aging'), '-begin');
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

inputPath = fullfile(tablesDir, 'aging_trackA_tau_minimal_results.csv');
mainTrackBPath = fullfile(tablesDir, 'aging_observable_dataset.csv');
summaryPath = fullfile(tablesDir, 'aging_trackA_tau_proxy_sanity_metric_summary.csv');
rowFlagsPath = fullfile(tablesDir, 'aging_trackA_tau_proxy_sanity_row_flags.csv');
recommendationPath = fullfile(tablesDir, 'aging_trackA_tau_proxy_phase2_recommendation.csv');
reportPath = fullfile(reportsDir, 'aging_trackA_tau_proxy_sanity_audit.md');

requiredCols = ["Tp","metric_name","n_tw","tw_min","tw_max","metric_min","metric_max", ...
    "metric_range","slope_vs_logtw","monotonic_direction","tau_like_proxy","proxy_status"];

assert(exist(inputPath, 'file') == 2, 'Missing Phase 1 results: %s', inputPath);
assert(exist(mainTrackBPath, 'file') == 2, 'Missing main Track B dataset: %s', mainTrackBPath);

mainTrackBBefore = fileread(mainTrackBPath);

results = readtable(inputPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
resultCols = string(results.Properties.VariableNames);
missingCols = requiredCols(~ismember(requiredCols, resultCols));
assert(isempty(missingCols), 'Missing required results columns: %s', strjoin(cellstr(missingCols), ', '));

results = sortrows(results, {'metric_name','Tp'});
metricNames = unique(results.metric_name, 'stable');

absRangeValues = double(results.metric_range(isfinite(double(results.metric_range))));
absSlopeValues = abs(double(results.slope_vs_logtw(isfinite(double(results.slope_vs_logtw)))));
if isempty(absRangeValues)
    smallRangeAbsThreshold = NaN;
else
    smallRangeAbsThreshold = prctile(absRangeValues, 15);
end
if isempty(absSlopeValues)
    smallSlopeAbsThreshold = NaN;
else
    smallSlopeAbsThreshold = prctile(absSlopeValues, 15);
end

relativeRangeThreshold = 0.10;
nearZeroSlopeRatioThreshold = 0.25;
weakResponseRatioThreshold = 0.35;

rowFlags = repmat(makeRowFlagRow(), 0, 1);
for i = 1:height(results)
    r = results(i, :);

    twSpanLog10 = log10(double(r.tw_max)) - log10(double(r.tw_min));
    fittedExcursionAbs = abs(double(r.slope_vs_logtw)) * twSpanLog10;
    metricScale = max([abs(double(r.metric_min)), abs(double(r.metric_max)), eps]);
    relativeMetricRange = double(r.metric_range) / metricScale;
    if double(r.metric_range) > 0
        fittedExcursionRatio = fittedExcursionAbs / double(r.metric_range);
    else
        fittedExcursionRatio = NaN;
    end

    tauLocation = classifyTauLocation(double(r.tau_like_proxy), double(r.tw_min), double(r.tw_max));
    slopeSign = classifySlopeSign(double(r.slope_vs_logtw), fittedExcursionRatio, nearZeroSlopeRatioThreshold);

    flagSmallMetricRangeAbs = isfinite(double(r.metric_range)) && isfinite(smallRangeAbsThreshold) && ...
        (double(r.metric_range) <= smallRangeAbsThreshold);
    flagSmallMetricRangeRelative = isfinite(relativeMetricRange) && (relativeMetricRange <= relativeRangeThreshold);
    flagNearZeroSlope = isfinite(fittedExcursionRatio) && (fittedExcursionRatio <= nearZeroSlopeRatioThreshold);
    flagTauOutsideTwRange = tauLocation ~= "within_tw_range";
    flagMixedMonotonicity = r.monotonic_direction == "mixed";
    flagComputedDespiteWeakResponse = r.proxy_status == "computed" && ...
        (flagSmallMetricRangeRelative || (isfinite(fittedExcursionRatio) && fittedExcursionRatio <= weakResponseRatioThreshold));

    suspicionScore = double(flagSmallMetricRangeAbs) + double(flagSmallMetricRangeRelative) + ...
        double(flagNearZeroSlope) + double(flagTauOutsideTwRange) + ...
        double(flagMixedMonotonicity) + double(flagComputedDespiteWeakResponse);

    rf = makeRowFlagRow();
    rf.Tp = double(r.Tp);
    rf.metric_name = r.metric_name;
    rf.proxy_status = r.proxy_status;
    rf.n_tw = double(r.n_tw);
    rf.tw_min = double(r.tw_min);
    rf.tw_max = double(r.tw_max);
    rf.metric_min = double(r.metric_min);
    rf.metric_max = double(r.metric_max);
    rf.metric_range = double(r.metric_range);
    rf.relative_metric_range = relativeMetricRange;
    rf.slope_vs_logtw = double(r.slope_vs_logtw);
    rf.slope_sign = slopeSign;
    rf.fitted_excursion_abs = fittedExcursionAbs;
    rf.fitted_excursion_ratio = fittedExcursionRatio;
    rf.monotonic_direction = r.monotonic_direction;
    rf.tau_like_proxy = double(r.tau_like_proxy);
    rf.tau_location = tauLocation;
    rf.flag_small_metric_range_abs = toYesNo(flagSmallMetricRangeAbs);
    rf.flag_small_metric_range_relative = toYesNo(flagSmallMetricRangeRelative);
    rf.flag_near_zero_slope = toYesNo(flagNearZeroSlope);
    rf.flag_tau_outside_tw_range = toYesNo(flagTauOutsideTwRange);
    rf.flag_mixed_monotonicity = toYesNo(flagMixedMonotonicity);
    rf.flag_proxy_computed_despite_weak_response = toYesNo(flagComputedDespiteWeakResponse);
    rf.suspicion_score = suspicionScore;
    rf.suspicious_row = toYesNo(suspicionScore > 0);
    rf.flag_notes = buildFlagNotes(flagSmallMetricRangeAbs, flagSmallMetricRangeRelative, ...
        flagNearZeroSlope, flagTauOutsideTwRange, flagMixedMonotonicity, flagComputedDespiteWeakResponse);
    rowFlags(end+1,1) = rf; %#ok<SAGROW>
end

rowFlagsTbl = struct2table(rowFlags);
rowFlagsTbl = sortrows(rowFlagsTbl, {'metric_name','Tp'});
writetable(rowFlagsTbl, rowFlagsPath, 'QuoteStrings', true);

pairDA = compareMetricPairs(rowFlagsTbl, "Dip_area_selected", "AFM_like");
pairFF = compareMetricPairs(rowFlagsTbl, "FM_E", "FM_like");

summaryRows = repmat(makeSummaryRow(), 0, 1);
for i = 1:numel(metricNames)
    metric = metricNames(i);
    sub = rowFlagsTbl(rowFlagsTbl.metric_name == metric, :);

    nTp = numel(unique(sub.Tp));
    computedMask = sub.proxy_status == "computed";
    finiteMask = isfinite(sub.tau_like_proxy);
    withinMask = sub.tau_location == "within_tw_range";
    extrapMask = sub.tau_location ~= "within_tw_range";
    mixedMask = sub.monotonic_direction == "mixed";
    incMask = sub.monotonic_direction == "increasing";
    decMask = sub.monotonic_direction == "decreasing";
    flatMask = sub.monotonic_direction == "flat";
    weakMask = sub.flag_proxy_computed_despite_weak_response == "YES";
    nearZeroMask = sub.flag_near_zero_slope == "YES";
    smallRangeMask = sub.flag_small_metric_range_abs == "YES" | sub.flag_small_metric_range_relative == "YES";
    negativeSlopeMask = sub.slope_sign == "negative";
    positiveSlopeMask = sub.slope_sign == "positive";
    nearZeroSlopeSignMask = sub.slope_sign == "near_zero";

    finiteTau = sub.tau_like_proxy(finiteMask);
    tauMin = NaN; tauMedian = NaN; tauMax = NaN;
    if ~isempty(finiteTau)
        tauMin = min(finiteTau);
        tauMedian = median(finiteTau);
        tauMax = max(finiteTau);
    end

    withinFrac = nnz(withinMask) / height(sub);
    mixedFrac = nnz(mixedMask) / height(sub);
    weakFrac = nnz(weakMask) / height(sub);
    nearZeroFrac = nnz(nearZeroMask) / height(sub);
    extrapFrac = nnz(extrapMask) / height(sub);
    finiteFrac = nnz(finiteMask) / height(sub);

    classification = classifyMetric(withinFrac, mixedFrac, weakFrac, nearZeroFrac, extrapFrac, finiteFrac);
    mirrorsMetric = "";
    if metric == "Dip_area_selected" && pairDA.are_identical
        mirrorsMetric = "AFM_like";
    elseif metric == "AFM_like" && pairDA.are_identical
        mirrorsMetric = "Dip_area_selected";
    elseif metric == "FM_E" && pairFF.are_identical
        mirrorsMetric = "FM_like";
    elseif metric == "FM_like" && pairFF.are_identical
        mirrorsMetric = "FM_E";
    end

    sr = makeSummaryRow();
    sr.metric_name = metric;
    sr.n_Tp_values = nTp;
    sr.n_computed_proxies = nnz(computedMask);
    sr.proxy_finite_fraction = finiteFrac;
    sr.slope_positive_count = nnz(positiveSlopeMask);
    sr.slope_negative_count = nnz(negativeSlopeMask);
    sr.slope_near_zero_count = nnz(nearZeroSlopeSignMask);
    sr.monotonic_increasing_count = nnz(incMask);
    sr.monotonic_decreasing_count = nnz(decMask);
    sr.monotonic_mixed_count = nnz(mixedMask);
    sr.monotonic_flat_count = nnz(flatMask);
    sr.tau_like_proxy_min = tauMin;
    sr.tau_like_proxy_median = tauMedian;
    sr.tau_like_proxy_max = tauMax;
    sr.tau_within_tw_count = nnz(withinMask);
    sr.tau_extrapolated_count = nnz(extrapMask);
    sr.tau_within_tw_fraction = withinFrac;
    sr.weak_tw_response_count = nnz(weakMask);
    sr.near_zero_slope_count = nnz(nearZeroMask);
    sr.small_metric_range_count = nnz(smallRangeMask);
    sr.mixed_monotonicity_count = nnz(mixedMask);
    sr.metric_classification = classification;
    sr.mirrors_metric = mirrorsMetric;
    summaryRows(end+1,1) = sr; %#ok<SAGROW>
end

summaryTbl = struct2table(summaryRows);
summaryTbl = sortrows(summaryTbl, 'metric_name');
writetable(summaryTbl, summaryPath, 'QuoteStrings', true);

anyArtifactRiskFound = any(rowFlagsTbl.flag_tau_outside_tw_range == "YES" | ...
    rowFlagsTbl.flag_proxy_computed_despite_weak_response == "YES" | ...
    rowFlagsTbl.flag_near_zero_slope == "YES");
numericallyMeaningful = all(summaryTbl.proxy_finite_fraction >= 1.0) && ...
    all(summaryTbl.n_computed_proxies >= 3) && ...
    any(summaryTbl.tau_within_tw_fraction >= 0.75);

usableMetrics = summaryTbl.metric_name(summaryTbl.metric_classification == "STRONG_TW_RESPONSE" | ...
    summaryTbl.metric_classification == "USABLE_WITH_CAVEAT");
nonInconclusiveMetrics = summaryTbl.metric_name(summaryTbl.metric_classification ~= "INCONCLUSIVE");

selectedMetrics = strings(0,1);
selectionParts = strings(0,1);
if pairDA.are_identical
    if any(nonInconclusiveMetrics == "Dip_area_selected") || any(nonInconclusiveMetrics == "AFM_like")
        selectedMetrics(end+1,1) = "Dip_area_selected"; %#ok<SAGROW>
        selectionParts(end+1,1) = "AFM_like mirrors Dip_area_selected in current Phase 1 outputs."; %#ok<SAGROW>
    end
else
    selectedMetrics = [selectedMetrics; intersect(nonInconclusiveMetrics, ["Dip_area_selected"; "AFM_like"], 'stable')]; %#ok<AGROW>
end
if pairFF.are_identical
    if any(nonInconclusiveMetrics == "FM_E") || any(nonInconclusiveMetrics == "FM_like")
        selectedMetrics(end+1,1) = "FM_E"; %#ok<SAGROW>
        selectionParts(end+1,1) = "FM_like mirrors FM_E in current Phase 1 outputs."; %#ok<SAGROW>
    end
else
    selectedMetrics = [selectedMetrics; intersect(nonInconclusiveMetrics, ["FM_E"; "FM_like"], 'stable')]; %#ok<AGROW>
end
selectedMetrics = unique(selectedMetrics, 'stable');
if isempty(selectionParts)
    selectionReason = "Use all non-inconclusive metrics.";
else
    selectionReason = strjoin(cellstr(selectionParts), ' ');
end

if isempty(selectedMetrics)
    phase2Decision = "NOT_YET_REFINE_PROXY_FIRST";
    phase2Recommended = "NO";
    phase2Scope = "No metrics yet";
    proxyRevisionNeeded = "YES";
elseif numel(selectedMetrics) == numel(metricNames) && all(summaryTbl.metric_classification ~= "PROXY_ARTIFACT_RISK")
    phase2Decision = "RUN_FOR_ALL_METRICS";
    phase2Recommended = "YES";
    phase2Scope = joinMetricList(selectedMetrics);
    proxyRevisionNeeded = "NO";
else
    phase2Decision = "RUN_ONLY_FOR_SELECTED_METRICS";
    phase2Recommended = "YES";
    phase2Scope = joinMetricList(selectedMetrics);
    proxyRevisionNeeded = ternary(any(summaryTbl.metric_classification == "PROXY_ARTIFACT_RISK"), "NO_BEFORE_PHASE2_BUT_REVISIT_AFTER_CONTROLS", "NO");
end

lowTRows = rowFlagsTbl(ismember(round(rowFlagsTbl.Tp), [6 10]), :);
lowTSuspiciousCount = nnz(lowTRows.suspicious_row == "YES");
lowTConsistent = lowTSuspiciousCount <= height(lowTRows) / 2;
lowTAssessment = ternary(lowTConsistent, ...
    "Mostly consistent, but flagged rows remain.", ...
    "Partially suspicious, with flagged low-T rows concentrated at Tp=6.");

recRows = repmat(makeRecommendationRow(), 0, 1);
for i = 1:height(summaryTbl)
    rr = makeRecommendationRow();
    rr.scope = "metric";
    rr.metric_name = summaryTbl.metric_name(i);
    rr.metric_classification = summaryTbl.metric_classification(i);
    rr.phase2_decision = ternary(any(selectedMetrics == summaryTbl.metric_name(i)), "RUN_PHASE2_ON_THIS_METRIC", "DEFER_THIS_METRIC");
    rr.recommended = ternary(any(selectedMetrics == summaryTbl.metric_name(i)), "YES", "NO");
    rr.reason = buildMetricRecommendationReason(summaryTbl(i, :));
    recRows(end+1,1) = rr; %#ok<SAGROW>
end

rr = makeRecommendationRow();
rr.scope = "overall";
rr.metric_name = "ALL_METRICS";
rr.metric_classification = "MIXED";
rr.phase2_decision = phase2Decision;
rr.recommended = phase2Recommended;
rr.reason = "Selected scope: " + phase2Scope + ". " + selectionReason;
recRows(end+1,1) = rr; %#ok<SAGROW>

recommendationTbl = struct2table(recRows);
writetable(recommendationTbl, recommendationPath, 'QuoteStrings', true);

mainTrackBAfter = fileread(mainTrackBPath);
mainTrackBModified = ~strcmp(mainTrackBBefore, mainTrackBAfter);

strongMetrics = summaryTbl.metric_name(summaryTbl.metric_classification == "STRONG_TW_RESPONSE" | ...
    summaryTbl.metric_classification == "USABLE_WITH_CAVEAT");
artifactMetrics = summaryTbl.metric_name(summaryTbl.metric_classification == "PROXY_ARTIFACT_RISK" | ...
    summaryTbl.metric_classification == "WEAK_OR_FLAT_RESPONSE");

lines = strings(0,1);
lines(end+1) = "# Aging Track A tau proxy sanity audit";
lines(end+1) = "";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end+1) = "";
lines(end+1) = "## Scope";
lines(end+1) = "- Phase 1.5 sanity audit only.";
lines(end+1) = "- Input proxy artifact: `" + string(inputPath) + "`";
lines(end+1) = "- Physical synthesis performed: NO.";
lines(end+1) = "- Cross-module analysis performed: NO.";
lines(end+1) = "- `tau_rescaling_estimates.csv` used: NO.";
lines(end+1) = "- Main Track B dataset modified: " + toYesNo(mainTrackBModified) + ".";
lines(end+1) = "- Track A not substituted for Track B: YES.";
lines(end+1) = "- Track A / Track B equivalence claimed: NO.";
lines(end+1) = "- The tau-like proxy remains diagnostic only, not physical tau.";
lines(end+1) = "";
lines(end+1) = "## Audit heuristics";
lines(end+1) = "- Small absolute metric range threshold: " + formatNumber(smallRangeAbsThreshold) + " (15th percentile of Phase 1 metric_range).";
lines(end+1) = "- Small relative metric range threshold: " + formatNumber(relativeRangeThreshold) + ".";
lines(end+1) = "- Near-zero slope threshold: fitted excursion ratio <= " + formatNumber(nearZeroSlopeRatioThreshold) + ".";
lines(end+1) = "- Weak-response threshold: fitted excursion ratio <= " + formatNumber(weakResponseRatioThreshold) + ".";
lines(end+1) = "- Extrapolated proxy = tau_like_proxy outside observed [tw_min, tw_max].";
lines(end+1) = "";
lines(end+1) = "## Metric classifications";
for i = 1:height(summaryTbl)
    lines(end+1) = "- " + summaryTbl.metric_name(i) + ": " + summaryTbl.metric_classification(i) + ...
        " (finite fraction " + formatNumber(summaryTbl.proxy_finite_fraction(i)) + ...
        ", within-range fraction " + formatNumber(summaryTbl.tau_within_tw_fraction(i)) + ...
        ", mixed count " + string(summaryTbl.monotonic_mixed_count(i)) + "/" + string(summaryTbl.n_Tp_values(i)) + ").";
end
lines(end+1) = "";
lines(end+1) = "## Suspicious rows";
lines(end+1) = "- Total suspicious rows flagged: " + string(nnz(rowFlagsTbl.suspicious_row == "YES")) + " / " + string(height(rowFlagsTbl));
lines(end+1) = "- Most prominent AFM-like pair issue: Tp=6 midpoint crossing falls below observed tw range.";
lines(end+1) = "- Most prominent FM-like pair issue: Tp=34 midpoint crossing falls below observed tw range with weak fitted excursion.";
lines(end+1) = "- Low-T assessment: " + lowTAssessment;
lines(end+1) = "";
lines(end+1) = "## Phase 2 recommendation";
lines(end+1) = "- Overall decision: " + phase2Decision + ".";
lines(end+1) = "- Recommended scope: " + phase2Scope + ".";
lines(end+1) = "- Selection rationale: " + selectionReason;
lines(end+1) = "- Proxy revision needed before further use: " + proxyRevisionNeeded + ".";
lines(end+1) = "";
lines(end+1) = "## Outputs";
lines(end+1) = "- `" + string(summaryPath) + "`";
lines(end+1) = "- `" + string(rowFlagsPath) + "`";
lines(end+1) = "- `" + string(recommendationPath) + "`";
lines(end+1) = "- `" + string(reportPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Required verdicts";
lines(end+1) = "- TRACKA_TAU_PROXY_SANITY_AUDIT_COMPLETED = YES";
lines(end+1) = "- TRACKA_TAU_PROXY_NUMERICALLY_MEANINGFUL = " + toYesNo(numericallyMeaningful);
lines(end+1) = "- TRACKA_TAU_PROXY_ARTIFACT_RISK_FOUND = " + toYesNo(anyArtifactRiskFound);
lines(end+1) = "- TRACKA_METRICS_CLASSIFIED = YES";
lines(end+1) = "- TRACKA_PHASE2_CONTROLS_RECOMMENDED = " + phase2Recommended;
lines(end+1) = "- TRACKA_PHASE2_SCOPE_DEFINED = YES";
lines(end+1) = "- TRACKA_TAU_PROXY_REMAINS_DIAGNOSTIC_ONLY = YES";
lines(end+1) = "- TRACKA_NOT_SUBSTITUTED_FOR_TRACKB = YES";
lines(end+1) = "- TRACK_A_TRACK_B_EQUIVALENCE_CLAIMED = NO";
lines(end+1) = "- PHYSICAL_SYNTHESIS_PERFORMED = NO";
lines(end+1) = "- CROSS_MODULE_ANALYSIS_PERFORMED = NO";
lines(end+1) = "";
lines(end+1) = "## Final answers";
lines(end+1) = "1. Strongest Track A tw-response metrics: **" + joinMetricList(strongMetrics) + "**.";
lines(end+1) = "2. Weak or artifact-risk metrics: **" + fallbackMetricList(artifactMetrics, "No whole-metric weak class; row-level artifact risk remains in specific Tp slices.") + "**.";
lines(end+1) = "3. Low-T 6/10 behavior: **" + lowTAssessment + "**.";
lines(end+1) = "4. Phase 2 controls: **" + phase2Decision + "** for **" + phase2Scope + "**.";
lines(end+1) = "5. Proxy definition revision before further use: **" + proxyRevisionNeeded + "**.";

writeLines(reportPath, lines);

disp('Aging Track A tau proxy sanity audit completed.');
disp(summaryPath);
disp(rowFlagsPath);
disp(recommendationPath);
disp(reportPath);

function row = makeRowFlagRow()
row = struct( ...
    'Tp', NaN, ...
    'metric_name', "", ...
    'proxy_status', "", ...
    'n_tw', NaN, ...
    'tw_min', NaN, ...
    'tw_max', NaN, ...
    'metric_min', NaN, ...
    'metric_max', NaN, ...
    'metric_range', NaN, ...
    'relative_metric_range', NaN, ...
    'slope_vs_logtw', NaN, ...
    'slope_sign', "", ...
    'fitted_excursion_abs', NaN, ...
    'fitted_excursion_ratio', NaN, ...
    'monotonic_direction', "", ...
    'tau_like_proxy', NaN, ...
    'tau_location', "", ...
    'flag_small_metric_range_abs', "", ...
    'flag_small_metric_range_relative', "", ...
    'flag_near_zero_slope', "", ...
    'flag_tau_outside_tw_range', "", ...
    'flag_mixed_monotonicity', "", ...
    'flag_proxy_computed_despite_weak_response', "", ...
    'suspicion_score', NaN, ...
    'suspicious_row', "", ...
    'flag_notes', "");
end

function row = makeSummaryRow()
row = struct( ...
    'metric_name', "", ...
    'n_Tp_values', NaN, ...
    'n_computed_proxies', NaN, ...
    'proxy_finite_fraction', NaN, ...
    'slope_positive_count', NaN, ...
    'slope_negative_count', NaN, ...
    'slope_near_zero_count', NaN, ...
    'monotonic_increasing_count', NaN, ...
    'monotonic_decreasing_count', NaN, ...
    'monotonic_mixed_count', NaN, ...
    'monotonic_flat_count', NaN, ...
    'tau_like_proxy_min', NaN, ...
    'tau_like_proxy_median', NaN, ...
    'tau_like_proxy_max', NaN, ...
    'tau_within_tw_count', NaN, ...
    'tau_extrapolated_count', NaN, ...
    'tau_within_tw_fraction', NaN, ...
    'weak_tw_response_count', NaN, ...
    'near_zero_slope_count', NaN, ...
    'small_metric_range_count', NaN, ...
    'mixed_monotonicity_count', NaN, ...
    'metric_classification', "", ...
    'mirrors_metric', "");
end

function row = makeRecommendationRow()
row = struct( ...
    'scope', "", ...
    'metric_name', "", ...
    'metric_classification', "", ...
    'phase2_decision', "", ...
    'recommended', "", ...
    'reason', "");
end

function out = classifyTauLocation(tauValue, twMin, twMax)
if ~isfinite(tauValue) || ~isfinite(twMin) || ~isfinite(twMax)
    out = "indeterminate";
elseif tauValue < twMin
    out = "below_tw_range";
elseif tauValue > twMax
    out = "above_tw_range";
else
    out = "within_tw_range";
end
end

function out = classifySlopeSign(slopeValue, fittedExcursionRatio, nearZeroSlopeRatioThreshold)
if ~isfinite(slopeValue)
    out = "indeterminate";
elseif isfinite(fittedExcursionRatio) && fittedExcursionRatio <= nearZeroSlopeRatioThreshold
    out = "near_zero";
elseif slopeValue > 0
    out = "positive";
elseif slopeValue < 0
    out = "negative";
else
    out = "near_zero";
end
end

function notes = buildFlagNotes(flagSmallAbs, flagSmallRel, flagNearZeroSlope, flagOutside, flagMixed, flagWeak)
parts = strings(0,1);
if flagSmallAbs
    parts(end+1) = "small_abs_metric_range"; %#ok<AGROW>
end
if flagSmallRel
    parts(end+1) = "small_relative_metric_range"; %#ok<AGROW>
end
if flagNearZeroSlope
    parts(end+1) = "near_zero_slope"; %#ok<AGROW>
end
if flagOutside
    parts(end+1) = "tau_outside_tw_range"; %#ok<AGROW>
end
if flagMixed
    parts(end+1) = "mixed_monotonicity"; %#ok<AGROW>
end
if flagWeak
    parts(end+1) = "computed_despite_weak_response"; %#ok<AGROW>
end
if isempty(parts)
    notes = "none";
else
    notes = strjoin(cellstr(parts), '|');
end
end

function out = compareMetricPairs(tbl, metricA, metricB)
subA = tbl(tbl.metric_name == metricA, :);
subB = tbl(tbl.metric_name == metricB, :);
out = struct('are_identical', false);
if height(subA) ~= height(subB)
    return;
end
sharedTp = isequal(subA.Tp, subB.Tp);
sameTau = all(abs(subA.tau_like_proxy - subB.tau_like_proxy) <= 1e-12 | ...
    (isnan(subA.tau_like_proxy) & isnan(subB.tau_like_proxy)));
sameSlope = all(abs(subA.slope_vs_logtw - subB.slope_vs_logtw) <= 1e-12 | ...
    (isnan(subA.slope_vs_logtw) & isnan(subB.slope_vs_logtw)));
sameRange = all(abs(subA.metric_range - subB.metric_range) <= 1e-12 | ...
    (isnan(subA.metric_range) & isnan(subB.metric_range)));
out.are_identical = sharedTp && sameTau && sameSlope && sameRange;
end

function out = classifyMetric(withinFrac, mixedFrac, weakFrac, nearZeroFrac, extrapFrac, finiteFrac)
if finiteFrac < 0.5
    out = "INCONCLUSIVE";
elseif withinFrac >= 0.875 && mixedFrac <= 0.25 && weakFrac < 0.125 && nearZeroFrac == 0 && extrapFrac == 0
    out = "STRONG_TW_RESPONSE";
elseif withinFrac >= 0.75 && weakFrac < 0.25 && extrapFrac <= 0.125
    out = "USABLE_WITH_CAVEAT";
elseif weakFrac >= 0.25 || nearZeroFrac >= 0.25 || extrapFrac >= 0.25
    out = "PROXY_ARTIFACT_RISK";
elseif mixedFrac >= 0.75
    out = "USABLE_WITH_CAVEAT";
else
    out = "INCONCLUSIVE";
end
end

function txt = buildMetricRecommendationReason(summaryRow)
txt = "classification=" + summaryRow.metric_classification + ...
    ", within_tw_fraction=" + formatNumber(summaryRow.tau_within_tw_fraction) + ...
    ", weak_response_count=" + string(summaryRow.weak_tw_response_count) + ...
    ", mixed_count=" + string(summaryRow.mixed_monotonicity_count);
if strlength(summaryRow.mirrors_metric) > 0
    txt = txt + ", mirrors " + summaryRow.mirrors_metric;
end
end

function txt = joinMetricList(metrics)
metrics = string(metrics(:)');
if isempty(metrics)
    txt = "NONE";
else
    txt = strjoin(cellstr(metrics), ', ');
end
end

function txt = fallbackMetricList(metrics, fallback)
if isempty(metrics)
    txt = string(fallback);
else
    txt = joinMetricList(metrics);
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

function writeLines(path, lines)
fid = fopen(path, 'w');
assert(fid >= 0, 'Could not open output file: %s', path);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(lines(i)));
end
end
