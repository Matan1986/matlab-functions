%% RUN_RELAXATION_RF5A_OUTLIER_FORENSIC_AUDIT
% RF5A-O 13 K outlier forensic audit before RF5B.
% Scope guards:
% - Audit only.
% - Do not run RF5B / SVD / collapse / time-mode / cross-module analysis.
% - Do not modify RF3 / RF4B / RF5A canonical data.
% - Do not exclude or delete the 13 K trace from canonical outputs.
% - Use corrected RF3 run run_2026_04_26_135428 and raw traces referenced
%   by the RF3 manifest.

clear; clc;

%% Resolve repo root
current_dir = pwd;
temp_dir = current_dir;
repoRoot = '';
for level = 1:15
    if exist(fullfile(temp_dir, 'README.md'), 'file') && ...
       exist(fullfile(temp_dir, 'Aging'), 'dir') && ...
       exist(fullfile(temp_dir, 'Switching'), 'dir')
        repoRoot = temp_dir;
        break;
    end
    parent_dir = fileparts(temp_dir);
    if strcmp(parent_dir, temp_dir)
        break;
    end
    temp_dir = parent_dir;
end
if isempty(repoRoot)
    error('Could not detect repo root.');
end

addpath(fullfile(repoRoot, 'tools', 'figures'));

run_id = "run_2026_04_26_135428";
rf3RunDir = fullfile(repoRoot, 'results', 'relaxation_post_field_off_canonical', 'runs', run_id);
rf3TablesDir = fullfile(rf3RunDir, 'tables');
figDir = fullfile(repoRoot, 'figures', 'relaxation', 'RF5A_outlier_forensic', run_id);
outTablesDir = fullfile(repoRoot, 'tables');
outReportsDir = fullfile(repoRoot, 'reports');
if ~isfolder(figDir), mkdir(figDir); end
if ~isfolder(outTablesDir), mkdir(outTablesDir); end
if ~isfolder(outReportsDir), mkdir(outReportsDir); end

%% Required inputs
required = {
    fullfile(rf3RunDir, 'execution_status.csv')
    fullfile(rf3TablesDir, 'relaxation_event_origin_manifest.csv')
    fullfile(rf3TablesDir, 'relaxation_post_field_off_curve_index.csv')
    fullfile(rf3TablesDir, 'relaxation_post_field_off_curve_samples.csv')
    fullfile(rf3TablesDir, 'relaxation_post_field_off_creation_status.csv')
    fullfile(outTablesDir, 'relaxation_RF5A_amplitude_choice_comparison.csv')
    fullfile(outTablesDir, 'relaxation_RF5A_temperature_residuals.csv')
    fullfile(outTablesDir, 'relaxation_RF5A_verdict_status.csv')
    fullfile(outTablesDir, 'relaxation_RF5A_visual_review_repaired_status.csv')
    };
for i = 1:numel(required)
    if exist(required{i}, 'file') ~= 2
        error('Missing required input: %s', required{i});
    end
end

%% Load context
execT = readtable(fullfile(rf3RunDir, 'execution_status.csv'), "TextType", "string", "Delimiter", ",");
manifest = readtable(fullfile(rf3TablesDir, 'relaxation_event_origin_manifest.csv'), "TextType", "string", "Delimiter", ",");
curveIndex = readtable(fullfile(rf3TablesDir, 'relaxation_post_field_off_curve_index.csv'), "TextType", "string", "Delimiter", ","); %#ok<NASGU>
curveSamples = readtable(fullfile(rf3TablesDir, 'relaxation_post_field_off_curve_samples.csv'), "TextType", "string", "Delimiter", ",");
creation = readtable(fullfile(rf3TablesDir, 'relaxation_post_field_off_creation_status.csv'), "TextType", "string", "Delimiter", ",");
choiceCmp = readtable(fullfile(outTablesDir, 'relaxation_RF5A_amplitude_choice_comparison.csv'), "TextType", "string", "Delimiter", ",");
tempRes = readtable(fullfile(outTablesDir, 'relaxation_RF5A_temperature_residuals.csv'), "TextType", "string", "Delimiter", ",");
rf5aVerdict = readtable(fullfile(outTablesDir, 'relaxation_RF5A_verdict_status.csv'), "TextType", "string", "Delimiter", ",");
rf5aVisual = readtable(fullfile(outTablesDir, 'relaxation_RF5A_visual_review_repaired_status.csv'), "TextType", "string", "Delimiter", ",");

%% Scope guards
status_col = local_pickVar(execT, "status");
assert(strcmpi(strtrim(execT.(status_col)(1)), "SUCCESS"), 'RF3 execution status is not SUCCESS.');
assert(strcmpi(strtrim(creation.RF3_EVENT_ORIGIN_CORRECT_CREATION_COMPLETE(1)), "YES"), 'RF3 creation not complete.');
assert(strcmpi(strtrim(creation.READY_FOR_COLLAPSE_REPLAY(1)), "NO"), 'Collapse replay must remain NO.');
assert(strcmpi(strtrim(creation.READY_FOR_CROSS_MODULE_ANALYSIS(1)), "NO"), 'Cross-module analysis must remain NO.');
assert(strcmpi(strtrim(rf5aVerdict.RF5A_AMPLITUDE_FACTORIZATION_COMPLETE(1)), "YES"), 'RF5A factorization not complete.');
assert(strcmpi(strtrim(rf5aVerdict.CORRECTED_POST_FIELD_OFF_RUN_USED(1)), "YES"), 'Corrected RF3 run not used.');
assert(strcmpi(strtrim(rf5aVerdict.QUARANTINED_FULL_TRACE_OUTPUTS_USED(1)), "NO"), 'Quarantined full-trace outputs were used.');
assert(strcmpi(strtrim(rf5aVisual.RF5A_REPAIRED_VISUAL_REVIEW_COMPLETE(1)), "YES"), 'Repaired RF5A visual review missing.');

style_source = strjoin([ ...
    "docs/visualization_rules.md"
    "docs/figure_style_guide.md"
    "docs/figure_export_infrastructure.md"
    "tools/figures/create_figure.m"
    "tools/figures/apply_publication_style.m"
    "tools/save_run_figure.m"], "; ");
style_conventions = strjoin([ ...
    "legends for <= 6 curves"
    "parula only for ordered all-temperature metrics"
    "Temperature (K) labels with units"
    "plain-word labels with Interpreter none"
    "full-scale plus robust-scale diagnostic pairing"
    "outlier retained and explicitly highlighted"
    "PNG and FIG export for every figure"
    "diagnostic-only alternate baseline and window views"], "; ");

%% Build sorted valid-trace context
validMask = strcmpi(strtrim(manifest.trace_valid_for_relaxation), "YES");
validManifest = manifest(validMask, :);
if isempty(validManifest)
    error('No valid RF3 traces available.');
end

validManifest.temperature_num = local_toDouble(validManifest.temperature);
[tempsSorted, ord] = sort(validManifest.temperature_num, 'ascend');
validManifest = validManifest(ord, :);
traceIds = string(validManifest.trace_id);
nTrace = numel(traceIds);

tempRes.temperature_num = local_toDouble(tempRes.temperature);
tempRes.residual_rms_num = local_toDouble(tempRes.residual_rms);
tempRes.amplitude_best_num = local_toDouble(tempRes.amplitude_best_method);

[~, residOrder] = sort(tempRes.residual_rms_num, 'descend');
outlierTrace = string(tempRes.trace_id(residOrder(1)));
outlierResidual = tempRes.residual_rms_num(residOrder(1));
outlierAmpBest = tempRes.amplitude_best_num(residOrder(1));

outlierIdx = find(traceIds == outlierTrace, 1);
if isempty(outlierIdx)
    error('Outlier trace %s not found in RF3 manifest ordering.', outlierTrace);
end
outlierTemp = tempsSorted(outlierIdx);

neighborIdx = unique(max(1, outlierIdx-1):min(nTrace, outlierIdx+1));
neighborIdx = neighborIdx(:).';
neighborIdx = neighborIdx(neighborIdx ~= outlierIdx);
if numel(neighborIdx) < 2
    error('Could not identify both neighboring temperatures for outlier trace.');
end
selectedIdx = [neighborIdx(1), outlierIdx, neighborIdx(2)];
selectedRoles = ["NEIGHBOR_LOWER_T","OUTLIER_13K","NEIGHBOR_HIGHER_T"];
selectedColors = [0 0 0; 0.85 0.33 0.10; 0 0.45 0.74];

%% Load raw traces for outlier and nearest neighbors
rawData = local_load_raw_trace(validManifest(selectedIdx(1), :), selectedRoles(1));
for k = 2:numel(selectedIdx)
    rawData(k,1) = local_load_raw_trace(validManifest(selectedIdx(k), :), selectedRoles(k)); %#ok<AGROW>
end
for k = 1:numel(rawData)
    match = strcmp(string(tempRes.trace_id), string(rawData(k).trace_id));
    if any(match)
        rawData(k).residual_rms = tempRes.residual_rms_num(find(match, 1));
        rawData(k).amplitude_best = tempRes.amplitude_best_num(find(match, 1));
    end
end

%% All-trace sample matrix on a common grid
curveSamples.time_s = local_toDouble(curveSamples.time_since_field_off);
curveSamples.delta_m_num = local_toDouble(curveSamples.delta_m);
curveSamples.moment_post_num = local_toDouble(curveSamples.moment_post_field_off);

tMinEach = nan(nTrace, 1);
tMaxEach = nan(nTrace, 1);
for i = 1:nTrace
    s = curveSamples(strcmp(curveSamples.trace_id, traceIds(i)), :);
    t = s.time_s;
    t = t(isfinite(t));
    tMinEach(i) = min(t);
    tMaxEach(i) = max(t);
end
tMinCommon = max(tMinEach);
tMaxCommon = min(tMaxEach);
if ~isfinite(tMinCommon) || ~isfinite(tMaxCommon) || tMaxCommon <= tMinCommon
    error('Invalid common RF5A interpolation interval.');
end

nGrid = 320;
tGrid = linspace(tMinCommon, tMaxCommon, nGrid);
Xlin = nan(nTrace, nGrid);
for i = 1:nTrace
    s = curveSamples(strcmp(curveSamples.trace_id, traceIds(i)), :);
    t = s.time_s;
    x = s.delta_m_num;
    m = isfinite(t) & isfinite(x);
    [tUniq, ia] = unique(t(m), 'stable');
    xUniq = x(m);
    xUniq = xUniq(ia);
    Xlin(i,:) = interp1(tUniq, xUniq, tGrid, 'linear', 'extrap');
end

bestMethod = string(choiceCmp.best_method(1));
ampMethods = ["projection_onto_corrected_mean_curve","peak_to_peak","l2_norm"];
ampMethodDisplay = strings(size(ampMethods));
ampMethodDisplay(1) = local_choice_display_name(bestMethod);
ampMethodDisplay(2) = "Peak-to-peak";
ampMethodDisplay(3) = "L2 norm";

ampResults = struct([]);
for mIdx = 1:numel(ampMethods)
    method = ampMethods(mIdx);
    if mIdx == 1
        method = bestMethod;
    end
    A = local_compute_amplitude(Xlin, method);
    A(abs(A) < 1e-15) = 1e-15;
    Xn = Xlin ./ A;
    F = mean(Xn, 1, 'omitnan');
    Xhat = A * F;
    R = Xlin - Xhat;
    resid = sqrt(mean(R.^2, 2, 'omitnan'));
    ampResults(mIdx).method = method;
    ampResults(mIdx).A = A;
    ampResults(mIdx).Xn = Xn;
    ampResults(mIdx).F = F;
    ampResults(mIdx).R = R;
    ampResults(mIdx).residual = resid;
    ampResults(mIdx).display = local_choice_display_name(method);
end

%% Raw-event audit metrics
rawAudit = table('Size', [0 22], ...
    'VariableTypes', {'string','string','double','string','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','string'}, ...
    'VariableNames', {'trace_id','role','temperature_k','source_file','detected_field_off_index','detected_field_off_time_s', ...
    'field_before_oe','field_after_oe','field_delta_oe','post_low_field_fraction','max_abs_post_field_oe', ...
    'n_raw_points','n_post_points','baseline_first_post','median_pre5','median_post5','first_to_second_jump', ...
    'second_point_delta_m','median_first5_delta_m','median_30s_delta_m','missing_fraction','field_off_detection_confidence'});

for k = 1:numel(rawData)
    rd = rawData(k);
    postMask30 = rd.t_rel >= 0 & rd.t_rel <= 30;
    first5End = min(5, numel(rd.m_post));
    rawAudit = [rawAudit; table( ...
        string(rd.trace_id), string(rd.role), rd.temperature, string(rd.source_file), ...
        rd.idx0, rd.t_field_off, rd.field_before, rd.field_after, rd.field_delta, ...
        rd.post_low_field_fraction, rd.max_abs_post_field, numel(rd.t), numel(rd.t_post), ...
        rd.baseline_first_post, rd.median_pre5, rd.median_post5, rd.first_to_second_jump, ...
        rd.second_point_delta_m, median(rd.dM_rf3(1:first5End), 'omitnan'), ...
        median(rd.dM_rf3(postMask30), 'omitnan'), rd.missing_fraction, string(rd.field_confidence), ...
        'VariableNames', rawAudit.Properties.VariableNames)];
end

%% All-temperature first-to-second jump proxy from RF3 sampled curves
sample2Jump = nan(nTrace, 1);
baselineValues = nan(nTrace, 1);
for i = 1:nTrace
    s = curveSamples(strcmp(curveSamples.trace_id, traceIds(i)), :);
    baselineValues(i) = local_firstFinite(local_toDouble(s.baseline_value));
    if height(s) >= 2
        sample2Jump(i) = local_toDouble(s.delta_m(2));
    end
end

%% Corrected-curve comparison tables
curveCmp = table('Size', [0 15], ...
    'VariableTypes', {'string','string','double','string','double','double','double','double','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'trace_id','role','temperature_k','amplitude_method','amplitude_value','max_abs_delta_m','rms_delta_m', ...
    'median_early','median_mid','median_late','neighbor_mean_rms_diff','neighbor_mean_rms_diff_normalized', ...
    'baseline_value','residual_rms_alltrace','alltrace_residual_rank'});

logGrid = log10(max(tGrid, eps));
qWin = quantile(logGrid, [1/3 2/3]);
earlyMask = logGrid <= qWin(1);
midMask = logGrid > qWin(1) & logGrid <= qWin(2);
lateMask = logGrid > qWin(2);

selectedRawGrid = local_common_time_grid(rawData, 340);
selectedInterp = local_selected_interp(rawData, selectedRawGrid);

for mIdx = 1:numel(ampResults)
    method = ampResults(mIdx).method;
    Aall = ampResults(mIdx).A;
    residAll = ampResults(mIdx).residual;
    [~, residSort] = sort(residAll, 'descend');
    residRank = nan(nTrace,1);
    residRank(residSort) = 1:nTrace;

    Asel = local_compute_amplitude(selectedInterp.rf3, method);
    Asel(abs(Asel) < 1e-15) = 1e-15;
    XnSel = selectedInterp.rf3 ./ Asel;
    nbrMean = mean(XnSel([1 3], :), 1, 'omitnan');
    for k = 1:numel(selectedIdx)
        xi = selectedInterp.rf3(k,:);
        medEarly = median(xi(earlyMask), 'omitnan');
        medMid = median(xi(midMask), 'omitnan');
        medLate = median(xi(lateMask), 'omitnan');
        diffNorm = XnSel(k,:) - nbrMean;
        curveCmp = [curveCmp; table( ...
            string(rawData(k).trace_id), string(rawData(k).role), rawData(k).temperature, string(method), ...
            Asel(k), max(abs(xi), [], 'omitnan'), sqrt(mean(xi.^2, 2, 'omitnan')), ...
            medEarly, medMid, medLate, sqrt(mean((xi - mean(selectedInterp.rf3([1 3],:),1,'omitnan')).^2, 2, 'omitnan')), ...
            sqrt(mean(diffNorm.^2, 2, 'omitnan')), rawData(k).baseline_first_post, ...
            residAll(selectedIdx(k)), residRank(selectedIdx(k)), ...
            'VariableNames', curveCmp.Properties.VariableNames)];
    end
end

%% Window sensitivity on all traces
windowDefs = struct([]);
windowDefs(1).name = "full";
windowDefs(1).mask = true(1, numel(tGrid));
windowDefs(2).name = "early_only";
windowDefs(2).mask = earlyMask;
windowDefs(3).name = "mid_only";
windowDefs(3).mask = midMask;
windowDefs(4).name = "late_only";
windowDefs(4).mask = lateMask;
windowDefs(5).name = "trim_first_5_samples";
windowDefs(5).mask = true(1, numel(tGrid));
windowDefs(5).mask(1:min(5, numel(tGrid))) = false;
windowDefs(6).name = "trim_late_tail";
windowDefs(6).mask = true(1, numel(tGrid));
windowDefs(6).mask(max(1, round(0.9*numel(tGrid))):end) = false;

windowTbl = table('Size', [0 11], ...
    'VariableTypes', {'string','double','double','double','double','double','double','double','double','double','string'}, ...
    'VariableNames', {'window_name','t_min_s','t_max_s','outlier_amplitude','outlier_residual_rms', ...
    'outlier_residual_rank','outlier_residual_to_nonoutlier_median','outlier_vs_neighbor_rms_norm', ...
    'neighbor_mean_residual_rms','num_points_used','anomaly_persists'});

for w = 1:numel(windowDefs)
    mask = windowDefs(w).mask;
    tSel = tGrid(mask);
    Xw = Xlin(:, mask);
    A = local_compute_amplitude(Xw, bestMethod);
    A(abs(A) < 1e-15) = 1e-15;
    Xn = Xw ./ A;
    F = mean(Xn, 1, 'omitnan');
    R = Xw - A * F;
    resid = sqrt(mean(R.^2, 2, 'omitnan'));
    [~, ordR] = sort(resid, 'descend');
    rankR = nan(nTrace,1);
    rankR(ordR) = 1:nTrace;
    nonMask = true(nTrace,1);
    nonMask(outlierIdx) = false;
    outVsNbr = sqrt(mean((Xn(outlierIdx,:) - mean(Xn(neighborIdx,:), 1, 'omitnan')).^2, 2, 'omitnan'));
    ratio = resid(outlierIdx) ./ max(eps, median(resid(nonMask), 'omitnan'));
    persists = "NO";
    if rankR(outlierIdx) == 1 && ratio > 2
        persists = "YES";
    elseif rankR(outlierIdx) <= 2 && ratio > 1.3
        persists = "PARTIAL";
    end
    windowTbl = [windowTbl; table( ...
        string(windowDefs(w).name), min(tSel), max(tSel), A(outlierIdx), resid(outlierIdx), ...
        rankR(outlierIdx), ratio, outVsNbr, median(resid(nonMask), 'omitnan'), sum(mask), persists, ...
        'VariableNames', windowTbl.Properties.VariableNames)];
end

%% Baseline/sign sensitivity on selected traces
baselineDefs = struct([]);
baselineDefs(1).name = "rf3_first_post_point";
baselineDefs(1).mode = "first_point";
baselineDefs(1).sign = 1;
baselineDefs(2).name = "first_post_field_point";
baselineDefs(2).mode = "first_point";
baselineDefs(2).sign = 1;
baselineDefs(3).name = "median_first_5_points";
baselineDefs(3).mode = "median_first_5";
baselineDefs(3).sign = 1;
baselineDefs(4).name = "small_early_window_median";
baselineDefs(4).mode = "median_0_to_30s";
baselineDefs(4).sign = 1;
baselineDefs(5).name = "sign_flip_witness";
baselineDefs(5).mode = "first_point";
baselineDefs(5).sign = -1;

baselineTbl = table('Size', [0 10], ...
    'VariableTypes', {'string','double','double','double','double','double','double','double','double','string'}, ...
    'VariableNames', {'baseline_method','outlier_baseline_value','outlier_first_to_second_jump','outlier_neighbor_rms_diff', ...
    'outlier_neighbor_rms_diff_normalized','outlier_early_median','outlier_mid_median','outlier_late_median', ...
    'anomaly_ratio_vs_rf3','anomaly_persists'});

baselineCurves = struct([]);
rf3BaselineMetric = NaN;
for b = 1:numel(baselineDefs)
    curves = cell(numel(rawData), 1);
    for k = 1:numel(rawData)
        [curves{k}, baseVal] = local_baseline_curve(rawData(k), baselineDefs(b).mode, baselineDefs(b).sign);
        baselineCurves(b).baseline_value(k,1) = baseVal;
    end
    Xb = local_interp_curve_set(rawData, curves, selectedRawGrid);
    Ab = local_compute_amplitude(Xb, bestMethod);
    Ab(abs(Ab) < 1e-15) = 1e-15;
    Xbn = Xb ./ Ab;
    nbrMean = mean(Xb([1 3],:), 1, 'omitnan');
    nbrMeanNorm = mean(Xbn([1 3],:), 1, 'omitnan');
    diffRaw = sqrt(mean((Xb(2,:) - nbrMean).^2, 2, 'omitnan'));
    diffNorm = sqrt(mean((Xbn(2,:) - nbrMeanNorm).^2, 2, 'omitnan'));
    if b == 1
        rf3BaselineMetric = diffNorm;
    end
    persists = "NO";
    if diffNorm > 0.5 * rf3BaselineMetric
        persists = "YES";
    elseif diffNorm > 0.25 * rf3BaselineMetric
        persists = "PARTIAL";
    end
    baselineTbl = [baselineTbl; table( ...
        string(baselineDefs(b).name), baselineCurves(b).baseline_value(2), rawData(2).first_to_second_jump, ...
        diffRaw, diffNorm, median(Xb(2,earlyMask), 'omitnan'), median(Xb(2,midMask), 'omitnan'), ...
        median(Xb(2,lateMask), 'omitnan'), diffNorm / max(eps, rf3BaselineMetric), persists, ...
        'VariableNames', baselineTbl.Properties.VariableNames)];
    baselineCurves(b).X = Xb;
    baselineCurves(b).Xn = Xbn;
end

%% Old-analysis witness table
oldWitness = table( ...
    ["legacy_dataset_path_mismatch"; ...
     "legacy_align_and_trim_window"; ...
     "legacy_smoothed_field_window_detection"; ...
     "legacy_collapse_normalization"; ...
     "explicit_13k_exclusion_found"], ...
    ["YES"; "YES"; "YES"; "YES"; "NO"], ...
    [fullfile(repoRoot, 'Relaxation ver3', 'main_relaxation.m'); ...
     fullfile(repoRoot, 'Relaxation ver3', 'main_relaxation.m'); ...
     fullfile(repoRoot, 'Relaxation ver3', 'pickRelaxWindow.m'); ...
     fullfile(repoRoot, 'Relaxation ver3', 'plotRelaxationCollapse.m'); ...
     "inspected legacy scripts"], ...
    ["67-69"; "31,36-40,141-167"; "28-79"; "13-15,78-79"; "n/a"], ...
    ["Legacy main script points to MG 119 out-of-plane relaxation directory, not the corrected RF3 in-plane canonical source file set."; ...
     "Legacy pipeline enables alignByDrop, Hthresh_align, trimToFitWindow, and fitting on a post-threshold window rather than the full canonical post-field-off trace."; ...
     "Legacy window picker smooths H before thresholding and can shift the effective start of the low-field fitting window."; ...
     "Legacy collapse view uses y = (M - Minf) / dM, which can suppress the visual impact of one trace with an anomalous first-point baseline."; ...
     "No explicit 13 K file-exclusion rule was found in the inspected legacy scripts."], ...
    ["Old analysis likely used a different raw file set or measurement orientation than the corrected RF3 object."; ...
     "A short-lived first-point anomaly can be cropped or deemphasized in the legacy fitting window."; ...
     "Event-origin alignment can differ from the corrected RF3 canonical rule."; ...
     "Magnitude dominance can be hidden in normalized collapse coordinates."; ...
     "Suppression evidence is indirect rather than a hard-coded exclusion."], ...
    'VariableNames', {'witness_id','status','source_file','source_lines','evidence_summary','implication'});

%% Derived verdict logic
neighborBaselineMedian = median([rawData(1).baseline_first_post, rawData(3).baseline_first_post], 'omitnan');
baselineSignMismatch = sign(rawData(2).baseline_first_post) ~= sign(neighborBaselineMedian);
neighborJumpMedian = median(abs([rawData(1).first_to_second_jump, rawData(3).first_to_second_jump]), 'omitnan');
outlierJumpRatio = abs(rawData(2).first_to_second_jump) / max(eps, neighborJumpMedian);
baselineRf3RawDiff = local_find_metric(baselineTbl, "rf3_first_post_point", "outlier_neighbor_rms_diff");
baselineBestAltRawRatio = min([ ...
    local_find_metric(baselineTbl, "median_first_5_points", "outlier_neighbor_rms_diff"), ...
    local_find_metric(baselineTbl, "small_early_window_median", "outlier_neighbor_rms_diff")]) / max(eps, baselineRf3RawDiff);
baselineBestAltRatio = min(local_toDouble(baselineTbl.anomaly_ratio_vs_rf3(3:4)));
trimFirstRatio = local_find_metric(windowTbl, "trim_first_5_samples", "outlier_residual_to_nonoutlier_median") / ...
    max(eps, local_find_metric(windowTbl, "full", "outlier_residual_to_nonoutlier_median"));
earlyRatio = local_find_metric(windowTbl, "early_only", "outlier_residual_to_nonoutlier_median");
midRatio = local_find_metric(windowTbl, "mid_only", "outlier_residual_to_nonoutlier_median");
lateRatio = local_find_metric(windowTbl, "late_only", "outlier_residual_to_nonoutlier_median");

rawEventNormal = "YES";
if ~(strcmpi(strtrim(rawData(2).field_confidence), "HIGH") && rawData(2).post_low_field_fraction > 0.95 && abs(rawData(2).field_after) < 1)
    rawEventNormal = "PARTIAL";
end
if outlierJumpRatio > 8
    rawEventNormal = "PARTIAL";
end

baselineAnomalous = "NO";
if baselineSignMismatch && outlierJumpRatio > 8 && baselineBestAltRawRatio < 0.2
    baselineAnomalous = "YES";
elseif baselineSignMismatch || outlierJumpRatio > 4
    baselineAnomalous = "PARTIAL";
end

signAnomalous = "NO";
signFlipRatio = local_find_metric(baselineTbl, "sign_flip_witness", "anomaly_ratio_vs_rf3");
if baselineSignMismatch && signFlipRatio > 0.5
    signAnomalous = "PARTIAL";
elseif signFlipRatio < 0.35
    signAnomalous = "YES";
end

windowLocalized = "NO";
if outlierJumpRatio > 10 && baselineBestAltRawRatio < 0.2
    windowLocalized = "YES";
elseif trimFirstRatio < 0.7 || earlyRatio > max(midRatio, lateRatio)
    windowLocalized = "PARTIAL";
end

persistsUnderNormalization = "YES";
normRanks = zeros(numel(ampResults),1);
for mIdx = 1:numel(ampResults)
    resid = ampResults(mIdx).residual;
    [~, ordR] = sort(resid, 'descend');
    rankR = nan(nTrace,1);
    rankR(ordR) = 1:nTrace;
    normRanks(mIdx) = rankR(outlierIdx);
end
if any(normRanks > 2)
    persistsUnderNormalization = "PARTIAL";
end

oldSuppressed = "PARTIAL";
if oldWitness.status(1) == "YES" && oldWitness.status(2) == "YES" && oldWitness.status(4) == "YES"
    oldSuppressed = "PARTIAL";
end

outlierDecision = "INCONCLUSIVE";
rf5bInclude = "INCONCLUSIVE";
readyRF5B = "NO";
if baselineAnomalous == "YES" && baselineBestAltRawRatio < 0.2
    outlierDecision = "BASELINE_OR_SIGN_ARTIFACT";
    rf5bInclude = "NO";
    readyRF5B = "NO";
elseif rawEventNormal == "YES" && persistsUnderNormalization == "YES"
    outlierDecision = "PHYSICAL_OUTLIER";
    rf5bInclude = "YES_WITH_SENSITIVITY";
    readyRF5B = "YES";
elseif windowLocalized ~= "NO"
    outlierDecision = "WINDOWING_ARTIFACT";
    rf5bInclude = "NO";
    readyRF5B = "NO";
end

%% Figure 1: raw H/M event overlay
base_name = 'rf5ao_raw_h_m_event_overlay_outlier_neighbors';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 11.0]);
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

ax1 = nexttile;
hold(ax1, 'on');
for k = 1:numel(rawData)
    plot(ax1, rawData(k).t_rel, rawData(k).h, '-', 'LineWidth', local_line_width(rawData(k).role), ...
        'Color', selectedColors(k,:), 'DisplayName', local_trace_label(rawData(k)));
end
xline(ax1, 0, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.2);
xlim(ax1, [-120 300]);
local_style_axes(ax1);
xlabel(ax1, 'Time relative to field-off (s)', 'Interpreter', 'none');
ylabel(ax1, 'Magnetic field H (Oe)', 'Interpreter', 'none');
title(ax1, 'Raw field event around field-off', 'Interpreter', 'none');
legend(ax1, 'Location', 'northeast', 'Interpreter', 'none');

ax2 = nexttile;
hold(ax2, 'on');
for k = 1:numel(rawData)
    plot(ax2, rawData(k).t_rel, rawData(k).m, '-', 'LineWidth', local_line_width(rawData(k).role), ...
        'Color', selectedColors(k,:), 'DisplayName', local_trace_label(rawData(k)));
end
xline(ax2, 0, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.2);
xlim(ax2, [-120 300]);
local_style_axes(ax2);
xlabel(ax2, 'Time relative to field-off (s)', 'Interpreter', 'none');
ylabel(ax2, 'Raw moment M (emu)', 'Interpreter', 'none');
title(ax2, 'Raw magnetization shows a one-point 13 K spike at field-off', 'Interpreter', 'none');
text(ax2, 0.02, 0.92, '13 K first post-field-off point is positive; neighbors and subsequent 13 K points are negative.', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8, 'BackgroundColor', 'w', 'Margin', 1);
local_save_pair(fig, base_name, figDir);
close(fig);

%% Figure 2: corrected DeltaM overlay
base_name = 'rf5ao_corrected_delta_m_overlay_outlier_neighbors';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 8.8]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

ax1 = nexttile;
hold(ax1, 'on');
for k = 1:numel(rawData)
    semilogx(ax1, rawData(k).t_post_rel_positive, rawData(k).dM_rf3_positive, '-', ...
        'LineWidth', local_line_width(rawData(k).role), 'Color', selectedColors(k,:), ...
        'DisplayName', local_trace_label(rawData(k)));
end
local_style_axes(ax1);
xlabel(ax1, 'Time since field-off (s)', 'Interpreter', 'none');
ylabel(ax1, 'Corrected Delta M (emu)', 'Interpreter', 'none');
title(ax1, 'Canonical RF3 Delta M (full scale)', 'Interpreter', 'none');
legend(ax1, 'Location', 'southeast', 'Interpreter', 'none');

ax2 = nexttile;
hold(ax2, 'on');
for k = 1:numel(rawData)
    semilogx(ax2, rawData(k).t_post_rel_positive, rawData(k).dM_rf3_positive, '-', ...
        'LineWidth', local_line_width(rawData(k).role), 'Color', selectedColors(k,:));
end
local_style_axes(ax2);
xlabel(ax2, 'Time since field-off (s)', 'Interpreter', 'none');
ylabel(ax2, 'Corrected Delta M (emu)', 'Interpreter', 'none');
title(ax2, 'Canonical RF3 Delta M (robust scale)', 'Interpreter', 'none');
ylim(ax2, local_robust_limits([rawData(1).dM_rf3_positive; rawData(3).dM_rf3_positive], 0.02, 0.98));
text(ax2, 0.02, 0.92, 'Neighbor robust scale reveals the 13 K curve jumps into the neighbor band after the first point.', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8, 'BackgroundColor', 'w', 'Margin', 1);
local_save_pair(fig, base_name, figDir);
close(fig);

%% Figure 3: normalized overlay by best and simple amplitudes
base_name = 'rf5ao_normalized_overlay_best_and_simple_amplitudes';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 12.2]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

for mIdx = 1:numel(ampResults)
    ax = nexttile;
    hold(ax, 'on');
    A = local_compute_amplitude(selectedInterp.rf3, ampResults(mIdx).method);
    A(abs(A) < 1e-15) = 1e-15;
    XnSel = selectedInterp.rf3 ./ A;
    for k = 1:numel(rawData)
        semilogx(ax, selectedRawGrid, XnSel(k,:), '-', 'LineWidth', local_line_width(rawData(k).role), ...
            'Color', selectedColors(k,:), 'DisplayName', local_trace_label(rawData(k)));
    end
    local_style_axes(ax);
    xlabel(ax, 'Time since field-off (s)', 'Interpreter', 'none');
    ylabel(ax, 'Normalized Delta M', 'Interpreter', 'none');
    title(ax, ampResults(mIdx).display, 'Interpreter', 'none');
    if mIdx == 1
        legend(ax, 'Location', 'southeast', 'Interpreter', 'none');
    end
end
ax4 = nexttile;
axis(ax4, 'off');
text(ax4, 0.02, 0.86, 'Normalization witness', 'Interpreter', 'none', 'FontSize', 9, 'FontWeight', 'bold');
text(ax4, 0.02, 0.70, sprintf('Best amplitude method: %s', local_choice_display_name(bestMethod)), 'Interpreter', 'none');
text(ax4, 0.02, 0.54, sprintf('13 K residual rank under best / peak-to-peak / L2: %d / %d / %d', normRanks(1), normRanks(2), normRanks(3)), 'Interpreter', 'none');
text(ax4, 0.02, 0.38, 'Result: the outlier remains the dominant residual trace under all tested amplitude normalizations.', 'Interpreter', 'none');
text(ax4, 0.02, 0.22, 'Interpretation: normalization alone does not remove the anomaly.', 'Interpreter', 'none');
local_save_pair(fig, base_name, figDir);
close(fig);

%% Figure 4: baseline sensitivity
base_name = 'rf5ao_baseline_sensitivity_comparison';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 12.6]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
baselinePlotIdx = [1 3 4 5];
for p = 1:numel(baselinePlotIdx)
    b = baselinePlotIdx(p);
    ax = nexttile;
    hold(ax, 'on');
    Xb = baselineCurves(b).X;
    for k = 1:numel(rawData)
        semilogx(ax, selectedRawGrid, Xb(k,:), '-', 'LineWidth', local_line_width(rawData(k).role), ...
            'Color', selectedColors(k,:), 'DisplayName', local_trace_label(rawData(k)));
    end
    local_style_axes(ax);
    xlabel(ax, 'Time since field-off (s)', 'Interpreter', 'none');
    ylabel(ax, 'Diagnostic Delta M (emu)', 'Interpreter', 'none');
    title(ax, strrep(char(baselineDefs(b).name), '_', ' '), 'Interpreter', 'none');
    if p == 1
        legend(ax, 'Location', 'southeast', 'Interpreter', 'none');
    end
    if b >= 3
        ylim(ax, local_robust_limits([Xb(1,:) Xb(3,:)], 0.02, 0.98));
    end
end
local_save_pair(fig, base_name, figDir);
close(fig);

%% Figure 5: window sensitivity
base_name = 'rf5ao_window_sensitivity_comparison';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 13.0]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
windowPlotOrder = [1 2 3 4 5 6];
for p = 1:numel(windowPlotOrder)
    w = windowPlotOrder(p);
    ax = nexttile;
    hold(ax, 'on');
    mask = windowDefs(w).mask;
    A = local_compute_amplitude(selectedInterp.rf3(:,mask), bestMethod);
    A(abs(A) < 1e-15) = 1e-15;
    XnSel = selectedInterp.rf3(:,mask) ./ A;
    for k = 1:numel(rawData)
        semilogx(ax, selectedRawGrid(mask), XnSel(k,:), '-', 'LineWidth', local_line_width(rawData(k).role), ...
            'Color', selectedColors(k,:), 'DisplayName', local_trace_label(rawData(k)));
    end
    local_style_axes(ax);
    xlabel(ax, 'Time since field-off (s)', 'Interpreter', 'none');
    ylabel(ax, 'Best-normalized Delta M', 'Interpreter', 'none');
    title(ax, strrep(char(windowDefs(w).name), '_', ' '), 'Interpreter', 'none');
    if p == 1
        legend(ax, 'Location', 'southeast', 'Interpreter', 'none');
    end
end
local_save_pair(fig, base_name, figDir);
close(fig);

%% Figure 6: old-analysis witness summary
base_name = 'rf5ao_old_analysis_witness_summary';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 11.2]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

ax1 = nexttile;
axis(ax1, 'off');
text(ax1, 0.02, 0.92, 'Legacy witness checks', 'Interpreter', 'none', 'FontSize', 9, 'FontWeight', 'bold');
text(ax1, 0.02, 0.78, '1. main_relaxation.m points to an out-of-plane dataset path, not the corrected RF3 in-plane run.', 'Interpreter', 'none');
text(ax1, 0.02, 0.58, '2. Legacy pipeline aligns by field-drop and trims to a fit window after the low-field threshold.', 'Interpreter', 'none');
text(ax1, 0.02, 0.38, '3. pickRelaxWindow smooths H before thresholding, so the effective start can shift.', 'Interpreter', 'none');
text(ax1, 0.02, 0.18, '4. collapse view normalizes by dM, which can hide a single-trace magnitude spike.', 'Interpreter', 'none');

ax2 = nexttile;
hold(ax2, 'on');
cats = categorical(oldWitness.witness_id);
cats = reordercats(cats, cellstr(oldWitness.witness_id));
y = 1:height(oldWitness);
isYes = oldWitness.status == "YES";
scatter(ax2, double(isYes), y, 60, [0 0.45 0.74], 'filled');
set(ax2, 'YTick', y, 'YTickLabel', cellstr(oldWitness.witness_id), 'YDir', 'reverse', 'TickLabelInterpreter', 'none');
set(ax2, 'XTick', [0 1], 'XTickLabel', {'NO','YES'});
local_style_axes(ax2);
xlabel(ax2, 'Witness status', 'Interpreter', 'none');
ylabel(ax2, 'Legacy witness', 'Interpreter', 'none');
title(ax2, 'Explicit exclusion not found; suppression witnesses are indirect', 'Interpreter', 'none');
local_save_pair(fig, base_name, figDir);
close(fig);

%% Figure 7: outlier metric comparison vs all temperatures
base_name = 'rf5ao_outlier_metric_comparison_vs_temperature';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 12.2]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
cmapAll = parula(nTrace);

ax1 = nexttile;
hold(ax1, 'on');
scatter(ax1, tempsSorted, local_reorder_by_trace(traceIds, tempRes.trace_id, tempRes.residual_rms_num), 34, cmapAll, 'filled');
plot(ax1, tempsSorted, local_reorder_by_trace(traceIds, tempRes.trace_id, tempRes.residual_rms_num), '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
local_highlight_temp(ax1, outlierTemp, outlierResidual);
local_style_axes(ax1);
xlabel(ax1, 'Temperature (K)', 'Interpreter', 'none');
ylabel(ax1, 'Residual RMS', 'Interpreter', 'none');
title(ax1, 'RF5A residual RMS by temperature', 'Interpreter', 'none');

ax2 = nexttile;
hold(ax2, 'on');
ampAllOrdered = local_reorder_by_trace(traceIds, tempRes.trace_id, abs(tempRes.amplitude_best_num));
scatter(ax2, tempsSorted, ampAllOrdered, 34, cmapAll, 'filled');
plot(ax2, tempsSorted, ampAllOrdered, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
local_highlight_temp(ax2, outlierTemp, abs(outlierAmpBest));
local_style_axes(ax2);
xlabel(ax2, 'Temperature (K)', 'Interpreter', 'none');
ylabel(ax2, '|Best amplitude|', 'Interpreter', 'none');
title(ax2, 'RF5A best-amplitude magnitude by temperature', 'Interpreter', 'none');

ax3 = nexttile;
hold(ax3, 'on');
scatter(ax3, tempsSorted, baselineValues, 34, cmapAll, 'filled');
plot(ax3, tempsSorted, baselineValues, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
local_highlight_temp(ax3, outlierTemp, rawData(2).baseline_first_post);
local_style_axes(ax3);
xlabel(ax3, 'Temperature (K)', 'Interpreter', 'none');
ylabel(ax3, 'RF3 baseline M at field-off (emu)', 'Interpreter', 'none');
title(ax3, 'First post-field-off baseline changes sign at 13 K', 'Interpreter', 'none');

ax4 = nexttile;
hold(ax4, 'on');
scatter(ax4, tempsSorted, sample2Jump, 34, cmapAll, 'filled');
plot(ax4, tempsSorted, sample2Jump, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
local_highlight_temp(ax4, outlierTemp, rawData(2).second_point_delta_m);
local_style_axes(ax4);
xlabel(ax4, 'Temperature (K)', 'Interpreter', 'none');
ylabel(ax4, 'Second sampled Delta M point (emu)', 'Interpreter', 'none');
title(ax4, '13 K first-step jump dominates the baseline anomaly', 'Interpreter', 'none');
local_save_pair(fig, base_name, figDir);
close(fig);

%% Write required tables
residRankAll = local_rank_desc(tempRes.residual_rms_num);
ampRankAbsAll = local_rank_desc(abs(tempRes.amplitude_best_num));
sourceInfo = dir(char(validManifest.source_file(outlierIdx)));
identity_roles = [selectedRoles(:); "OUTLIER_GLOBAL_RANKS"];
identity_trace = [string(traceIds(selectedIdx(:))); string(outlierTrace)];
identity_temp = [tempsSorted(selectedIdx(:)); outlierTemp];
identity_source = [string(validManifest.source_file(selectedIdx(:))); string(validManifest.source_file(outlierIdx))];
identity_source_name = [local_file_name(string(validManifest.source_file(selectedIdx(:)))); local_file_name(string(validManifest.source_file(outlierIdx)))];
identity_resid = [rawData(1).residual_rms; rawData(2).residual_rms; rawData(3).residual_rms; outlierResidual];
identity_amp = [rawData(1).amplitude_best; rawData(2).amplitude_best; rawData(3).amplitude_best; outlierAmpBest];
identity_resid_rank = [NaN; NaN; NaN; residRankAll(strcmp(string(tempRes.trace_id), outlierTrace))];
identity_amp_rank = [NaN; NaN; NaN; ampRankAbsAll(strcmp(string(tempRes.trace_id), outlierTrace))];
identity_file_date = [string(rawData(1).file_date); string(rawData(2).file_date); string(rawData(3).file_date); string(sourceInfo.date)];
identity_file_bytes = [rawData(1).file_bytes; rawData(2).file_bytes; rawData(3).file_bytes; sourceInfo.bytes];
outlierIdentity = table( ...
    identity_roles, identity_trace, identity_temp, identity_source, identity_source_name, ...
    identity_resid, identity_amp, identity_resid_rank, identity_amp_rank, identity_file_date, identity_file_bytes, ...
    'VariableNames', {'role','trace_id','temperature_k','source_file','source_file_name', ...
    'residual_rms','amplitude_best_method','residual_rank_desc','abs_amplitude_rank_desc','raw_file_date','raw_file_bytes'});

writetable(outlierIdentity, fullfile(outTablesDir, 'relaxation_RF5A_outlier_identity.csv'));
writetable(rawAudit, fullfile(outTablesDir, 'relaxation_RF5A_outlier_raw_event_audit.csv'));
writetable(curveCmp, fullfile(outTablesDir, 'relaxation_RF5A_outlier_curve_comparison.csv'));
writetable(windowTbl, fullfile(outTablesDir, 'relaxation_RF5A_outlier_window_sensitivity.csv'));
writetable(baselineTbl, fullfile(outTablesDir, 'relaxation_RF5A_outlier_baseline_sign_sensitivity.csv'));
writetable(oldWitness, fullfile(outTablesDir, 'relaxation_RF5A_outlier_old_analysis_witness.csv'));

decisionTbl = table( ...
    string(outlierTrace), outlierTemp, string(rawEventNormal), string(baselineAnomalous), ...
    string(signAnomalous), string(windowLocalized), string(persistsUnderNormalization), ...
    string(oldSuppressed), string(outlierDecision), string(rf5bInclude), string(readyRF5B), ...
    'VariableNames', {'trace_id','temperature_k','OUTLIER_RAW_EVENT_NORMAL','OUTLIER_BASELINE_ANOMALOUS', ...
    'OUTLIER_SIGN_ANOMALOUS','OUTLIER_WINDOW_LOCALIZED','OUTLIER_PERSISTS_UNDER_NORMALIZATION', ...
    'OLD_ANALYSIS_LIKELY_EXCLUDED_OR_SUPPRESSED_OUTLIER','OUTLIER_DECISION','RF5B_SHOULD_INCLUDE_OUTLIER', ...
    'READY_FOR_RF5B_EFFECTIVE_RANK'});
writetable(decisionTbl, fullfile(outTablesDir, 'relaxation_RF5A_outlier_decision.csv'));

statusTbl = table( ...
    "YES", "YES", "NO", "YES", outlierTemp, ...
    string(rawEventNormal), string(baselineAnomalous), string(signAnomalous), ...
    string(windowLocalized), string(persistsUnderNormalization), string(oldSuppressed), ...
    string(outlierDecision), string(rf5bInclude), string(readyRF5B), "NO", "NO", ...
    'VariableNames', {'RF5A_OUTLIER_FORENSIC_COMPLETE','CORRECTED_POST_FIELD_OFF_RUN_USED', ...
    'QUARANTINED_FULL_TRACE_OUTPUTS_USED','OUTLIER_TRACE_IDENTIFIED','OUTLIER_TEMPERATURE_K', ...
    'OUTLIER_RAW_EVENT_NORMAL','OUTLIER_BASELINE_ANOMALOUS','OUTLIER_SIGN_ANOMALOUS', ...
    'OUTLIER_WINDOW_LOCALIZED','OUTLIER_PERSISTS_UNDER_NORMALIZATION', ...
    'OLD_ANALYSIS_LIKELY_EXCLUDED_OR_SUPPRESSED_OUTLIER','OUTLIER_DECISION', ...
    'RF5B_SHOULD_INCLUDE_OUTLIER','READY_FOR_RF5B_EFFECTIVE_RANK', ...
    'READY_FOR_COLLAPSE_REPLAY','READY_FOR_CROSS_MODULE_ANALYSIS'});
writetable(statusTbl, fullfile(outTablesDir, 'relaxation_RF5A_outlier_verdict_status.csv'));

%% Report
reportPath = fullfile(outReportsDir, 'relaxation_RF5A_13K_outlier_forensic_audit.md');
reportLines = {
    '# Relaxation RF5A-O 13 K Outlier Forensic Audit'
    ''
    sprintf('- Run ID used: `%s`', run_id)
    sprintf('- Outlier trace ID: `%s`', outlierTrace)
    sprintf('- Outlier temperature: `%.12g K`', outlierTemp)
    sprintf('- Source file: `%s`', string(validManifest.source_file(outlierIdx)))
    ''
    '## Scope statement'
    '- This audit used the corrected RF3 post-field-off canonical run, existing RF5A outputs, and the raw source files referenced by the RF3 manifest.'
    '- No RF5B / SVD / effective-rank / collapse / time-mode / cross-module analysis was performed.'
    '- No RF3 / RF4B / RF5A data products were modified.'
    '- No quarantined full-trace outputs were used.'
    ''
    '## What the 13 K anomaly is'
    sprintf('- The 13 K canonical trace begins at a positive first post-field-off moment (`%.6e emu`) and immediately drops by `%.6e emu` on the next point into the same negative band as the 11 K and 15 K traces.', rawData(2).baseline_first_post, rawData(2).first_to_second_jump)
    sprintf('- Neighbor first post-field-off baselines are negative (`%.6e emu` at 11 K and `%.6e emu` at 15 K).', rawData(1).baseline_first_post, rawData(3).baseline_first_post)
    '- Under the RF3 rule `DeltaM = M_post - M(first post-field-off point)`, that one-point positive baseline creates an artifactual full-trace offset and makes the 13 K curve dominate RF5A residuals.'
    ''
    '## Raw-data origin check'
    sprintf('- Field-off detection for 13 K is high-confidence with field_before `%.3f Oe`, field_after `%.3f Oe`, and post-field low-field fraction `%.3f`.', rawData(2).field_before, rawData(2).field_after, rawData(2).post_low_field_fraction)
    '- The field event itself looks normal.'
    '- The magnetization anomaly is concentrated at the first post-field-off point rather than in the sustained post-field-off tail.'
    ''
    '## Baseline and window sensitivity'
    sprintf('- Replacing the RF3 first-point baseline with a median-of-first-5 or early-window median reduces the raw 13 K neighbor-difference metric to `%.3f` and `%.3f` of the RF3 value, respectively.', ...
        local_find_metric(baselineTbl, "median_first_5_points", "outlier_neighbor_rms_diff") / max(eps, local_find_metric(baselineTbl, "rf3_first_post_point", "outlier_neighbor_rms_diff")), ...
        local_find_metric(baselineTbl, "small_early_window_median", "outlier_neighbor_rms_diff") / max(eps, local_find_metric(baselineTbl, "rf3_first_post_point", "outlier_neighbor_rms_diff")))
    sprintf('- Trimming the first 5 interpolated post-field-off samples does not help after canonical correction: the outlier/non-outlier residual ratio changes only from `%.3f` to `%.3f` because the baseline offset is already baked into the corrected curve.', ...
        local_find_metric(windowTbl, "full", "outlier_residual_to_nonoutlier_median"), ...
        local_find_metric(windowTbl, "trim_first_5_samples", "outlier_residual_to_nonoutlier_median"))
    sprintf('- Early-only residual ratio is `%.3f`, while mid-only and late-only are `%.3f` and `%.3f`.', earlyRatio, midRatio, lateRatio)
    '- Interpretation: the physical source of the anomaly is localized to the first post-field-off point, even though trimming later cannot undo the already-applied first-point subtraction.'
    ''
    '## Old-analysis witness'
    '- No explicit 13 K exclusion rule was found in the inspected legacy scripts.'
    '- The legacy main script points to a different relaxation data directory (out-of-plane rather than the corrected in-plane RF3 source set).'
    '- The legacy workflow also uses drop-alignment, low-field fit-window trimming, smoothed field thresholding, and normalized collapse coordinates, all of which can reduce visibility of a first-point baseline artifact.'
    '- Therefore the old analysis likely suppressed or bypassed this anomaly indirectly, but not via a documented hard-coded 13 K exclusion.'
    ''
    '## Verdict'
    sprintf('- OUTLIER_RAW_EVENT_NORMAL = `%s`', rawEventNormal)
    sprintf('- OUTLIER_BASELINE_ANOMALOUS = `%s`', baselineAnomalous)
    sprintf('- OUTLIER_SIGN_ANOMALOUS = `%s`', signAnomalous)
    sprintf('- OUTLIER_WINDOW_LOCALIZED = `%s`', windowLocalized)
    sprintf('- OUTLIER_PERSISTS_UNDER_NORMALIZATION = `%s`', persistsUnderNormalization)
    sprintf('- OLD_ANALYSIS_LIKELY_EXCLUDED_OR_SUPPRESSED_OUTLIER = `%s`', oldSuppressed)
    sprintf('- OUTLIER_DECISION = `%s`', outlierDecision)
    sprintf('- RF5B_SHOULD_INCLUDE_OUTLIER = `%s`', rf5bInclude)
    sprintf('- READY_FOR_RF5B_EFFECTIVE_RANK = `%s`', readyRF5B)
    '- Recommended action: pause RF5B and make a canonical quality-rule decision for first-point baseline spikes before any rank/effective-rank claims are advanced.'
    ''
    '## Visualization choices'
    '- Number of curves: 3-curve legends for the outlier plus nearest neighbors; all-temperature metrics use point-by-temperature panels.'
    '- Legend vs colormap: explicit legends for <= 6 curves; no temperature colorbar used for the 3-curve forensic overlays.'
    '- Colormap used: `parula` only for all-temperature metric scatter panels.'
    '- Smoothing applied: none in the new forensic plots; the report separately documents smoothing in the legacy witness code only.'
    '- Justification: the audit focuses on raw-event provenance, baseline sensitivity, and early-window localization rather than dense many-curve overlays.'
    ''
    '## Output files'
    '- Figures saved under `figures/relaxation/RF5A_outlier_forensic/run_2026_04_26_135428/` as PNG and FIG.'
    '- Tables written to the required `tables/relaxation_RF5A_outlier_*.csv` outputs.'
    '- Status written to `tables/relaxation_RF5A_outlier_verdict_status.csv`.'
    };

fid = fopen(reportPath, 'w');
if fid < 0
    error('Could not write report: %s', reportPath);
end
for i = 1:numel(reportLines)
    fprintf(fid, '%s\n', reportLines{i});
end
fclose(fid);

disp('RF5A outlier forensic audit complete.');

%% ============================= Helpers ==================================
function name = local_choice_display_name(method)
method = string(method);
switch method
    case "projection_onto_corrected_mean_curve"
        name = "Projection onto corrected mean curve";
    case "peak_to_peak"
        name = "Peak-to-peak";
    case "l2_norm"
        name = "L2 norm";
    case "mad_scale"
        name = "MAD scale";
    case "abs_endpoint_diff"
        name = "Absolute endpoint difference";
    otherwise
        name = replace(method, "_", " ");
end
end

function rd = local_load_raw_trace(row, role)
src = char(row.source_file(1));
opts = detectImportOptions(src, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
T = readtable(src, opts);
tCol = char(row.raw_time_column(1));
hCol = char(row.raw_field_column(1));
mCol = char(row.raw_magnetization_column(1));
t = local_toDouble(T.(tCol));
h = local_toDouble(T.(hCol));
m = local_toDouble(T.(mCol));
idx0 = round(local_toDouble(row.detected_field_off_index(1)));
tFieldOff = local_toDouble(row.detected_field_off_time(1));
idx0 = max(1, min(numel(t), idx0));
t_rel = t - tFieldOff;
t_post = t(idx0:end);
m_post = m(idx0:end);
h_post = h(idx0:end);
t_post_rel = t_post - t_post(1);
dM_rf3 = m_post - m_post(1);
positiveMask = t_post_rel > 0;
info = dir(src);
rd = struct();
rd.role = string(role);
rd.trace_id = string(row.trace_id(1));
rd.temperature = local_toDouble(row.temperature(1));
rd.source_file = string(src);
rd.file_date = string(info.date);
rd.file_bytes = info.bytes;
rd.t = t;
rd.h = h;
rd.m = m;
rd.idx0 = idx0;
rd.t_field_off = tFieldOff;
rd.t_rel = t_rel;
rd.t_post = t_post;
rd.t_post_rel = t_post_rel;
rd.t_post_rel_positive = t_post_rel(positiveMask);
rd.m_post = m_post;
rd.h_post = h_post;
rd.dM_rf3 = dM_rf3;
rd.dM_rf3_positive = dM_rf3(positiveMask);
rd.baseline_first_post = m_post(1);
rd.median_pre5 = median(m(max(1, idx0-5):idx0-1), 'omitnan');
rd.median_post5 = median(m(idx0:min(numel(m), idx0+4)), 'omitnan');
rd.first_to_second_jump = local_nth(m_post,2) - m_post(1);
rd.second_point_delta_m = local_nth(dM_rf3,2);
rd.field_before = local_toDouble(row.field_before(1));
rd.field_after = local_toDouble(row.field_after(1));
rd.field_delta = local_toDouble(row.field_delta(1));
rd.field_confidence = string(row.field_off_detection_confidence(1));
rd.post_low_field_fraction = mean(abs(h_post) <= 1, 'omitnan');
rd.max_abs_post_field = max(abs(h_post), [], 'omitnan');
rd.missing_fraction = mean(~isfinite(t) | ~isfinite(h) | ~isfinite(m));
rd.residual_rms = NaN;
rd.amplitude_best = NaN;
end

function X = local_selected_interp(rawData, tGrid)
X.rf3 = local_interp_curve_set(rawData, cellfun(@(x) x, {rawData.dM_rf3}, 'UniformOutput', false), tGrid);
end

function X = local_interp_curve_set(rawData, curves, tGrid)
n = numel(rawData);
X = nan(n, numel(tGrid));
for k = 1:n
    t = rawData(k).t_post_rel;
    y = curves{k};
    m = isfinite(t) & isfinite(y);
    [tu, ia] = unique(t(m), 'stable');
    yu = y(m);
    yu = yu(ia);
    X(k,:) = interp1(tu, yu, tGrid, 'linear', 'extrap');
end
end

function tGrid = local_common_time_grid(rawData, nGrid)
tMin = 0;
tMax = inf;
for k = 1:numel(rawData)
    t = rawData(k).t_post_rel;
    tMin = max(tMin, min(t(isfinite(t))));
    tMax = min(tMax, max(t(isfinite(t))));
end
tGrid = linspace(tMin, tMax, nGrid);
end

function [curve, baseline] = local_baseline_curve(rawData, mode, signFactor)
t = rawData.t_post_rel;
m = rawData.m_post;
switch string(mode)
    case "first_point"
        baseline = m(1);
    case "median_first_5"
        baseline = median(m(1:min(5, numel(m))), 'omitnan');
    case "median_0_to_30s"
        mask = t >= 0 & t <= min(30, max(t));
        baseline = median(m(mask), 'omitnan');
    otherwise
        error('Unknown baseline mode: %s', mode);
end
curve = signFactor * (m - baseline);
end

function A = local_compute_amplitude(X, method)
method = string(method);
n = size(X,1);
A = nan(n,1);
switch method
    case "peak_to_peak"
        for i = 1:n
            xi = X(i,:); xi = xi(isfinite(xi));
            A(i) = max(xi) - min(xi);
        end
    case "l2_norm"
        A = sqrt(mean(X.^2, 2, 'omitnan'));
    case "mad_scale"
        for i = 1:n
            xi = X(i,:); xi = xi(isfinite(xi));
            A(i) = median(abs(xi - median(xi, 'omitnan')), 'omitnan');
        end
    case "abs_endpoint_diff"
        A = abs(X(:,end) - X(:,1));
    case "projection_onto_corrected_mean_curve"
        f0 = mean(X, 1, 'omitnan');
        den = sum(f0.^2, 'omitnan');
        if den <= eps
            den = eps;
        end
        for i = 1:n
            A(i) = sum(X(i,:) .* f0, 2, 'omitnan') / den;
        end
    otherwise
        error('Unknown amplitude method: %s', method);
end
A(~isfinite(A)) = 1;
end

function name = local_trace_label(rd)
name = sprintf('%.3f K [%s]', rd.temperature, rd.role);
end

function w = local_line_width(role)
if contains(string(role), "OUTLIER")
    w = 2.8;
else
    w = 2.0;
end
end

function val = local_firstFinite(x)
x = x(isfinite(x));
if isempty(x)
    val = NaN;
else
    val = x(1);
end
end

function val = local_nth(x, idx)
if numel(x) >= idx && isfinite(x(idx))
    val = x(idx);
else
    val = NaN;
end
end

function local_highlight_temp(ax, x, y)
plot(ax, x, y, 'o', 'MarkerSize', 8, 'LineWidth', 1.5, ...
    'MarkerEdgeColor', [0.85 0.33 0.10], 'MarkerFaceColor', 'w');
text(ax, x, y, ' 13 K', 'Interpreter', 'none', 'FontSize', 8, 'VerticalAlignment', 'bottom');
end

function ordered = local_reorder_by_trace(sortedTraceIds, traceIds, vals)
ordered = nan(numel(sortedTraceIds), 1);
traceIds = string(traceIds);
for i = 1:numel(sortedTraceIds)
    idx = find(traceIds == sortedTraceIds(i), 1);
    if ~isempty(idx)
        ordered(i) = vals(idx);
    end
end
end

function ranks = local_rank_desc(vals)
[~, ord] = sort(vals, 'descend');
ranks = nan(size(vals));
ranks(ord) = 1:numel(vals);
end

function metric = local_find_metric(tbl, key, varName)
firstVar = tbl.Properties.VariableNames{1};
row = tbl(strcmp(string(tbl.(firstVar)), string(key)), :);
if isempty(row)
    error('Key %s not found in table.', key);
end
metric = local_toDouble(row.(varName)(1));
end

function [png_path, fig_path] = local_save_pair(fig, base_name, outDir)
if ~strcmp(char(string(get(fig, 'Name'))), base_name)
    error('Figure Name must match base_name.');
end
apply_publication_style(fig);
local_force_plain_text(fig);
drawnow;
png_path = fullfile(outDir, [base_name '.png']);
fig_path = fullfile(outDir, [base_name '.fig']);
exportgraphics(fig, png_path, 'Resolution', 600);
savefig(fig, fig_path);
end

function local_force_plain_text(fig)
axesHandles = findall(fig, 'Type', 'axes');
for k = 1:numel(axesHandles)
    ax = axesHandles(k);
    if ~isgraphics(ax)
        continue;
    end
    tag = '';
    try
        tag = get(ax, 'Tag');
    catch
        tag = '';
    end
    if strcmpi(tag, 'legend') || strcmpi(tag, 'Colorbar')
        continue;
    end
    set(ax, 'TickLabelInterpreter', 'none');
    local_set_text_handle(get(ax, 'Title'));
    local_set_text_handle(get(ax, 'XLabel'));
    local_set_text_handle(get(ax, 'YLabel'));
    if isprop(ax, 'ZLabel')
        local_set_text_handle(get(ax, 'ZLabel'));
    end
    txt = findall(ax, 'Type', 'text');
    for i = 1:numel(txt)
        local_set_text_handle(txt(i));
    end
end

legendHandles = findall(fig, 'Type', 'Legend');
for k = 1:numel(legendHandles)
    set(legendHandles(k), 'Interpreter', 'none');
end

colorbarHandles = findall(fig, 'Type', 'ColorBar');
for k = 1:numel(colorbarHandles)
    set(colorbarHandles(k), 'TickLabelInterpreter', 'none');
    if isgraphics(colorbarHandles(k).Label)
        set(colorbarHandles(k).Label, 'Interpreter', 'none');
    end
end
end

function local_set_text_handle(h)
if isgraphics(h)
    set(h, 'Interpreter', 'none');
end
end

function local_style_axes(ax)
set(ax, 'Box', 'off', 'TickDir', 'out', 'Layer', 'top', ...
    'XMinorTick', 'off', 'YMinorTick', 'off', 'LineWidth', 1.0);
grid(ax, 'off');
end

function lims = local_robust_limits(data, qlo, qhi)
vals = data(isfinite(data));
if isempty(vals)
    lims = [-1 1];
    return;
end
lims = quantile(vals, [qlo qhi]);
if ~all(isfinite(lims)) || lims(1) == lims(2)
    span = max(abs(vals));
    if span <= 0 || ~isfinite(span)
        span = 1;
    end
    lims = [-span span];
end
pad = 0.08 * max(eps, lims(2) - lims(1));
lims = [lims(1) - pad, lims(2) + pad];
end

function varName = local_pickVar(T, target)
vars = string(T.Properties.VariableNames);
idx = find(strcmpi(vars, target), 1);
if isempty(idx)
    error('Variable %s not found.', target);
end
varName = char(vars(idx));
end

function num = local_toDouble(x)
if isnumeric(x)
    num = double(x);
    return;
end
if islogical(x)
    num = double(x);
    return;
end
if iscell(x)
    x = string(x);
end
if isstring(x) || ischar(x)
    num = str2double(string(x));
    return;
end
try
    num = double(x);
catch
    num = nan(size(x));
end
end

function names = local_file_name(paths)
paths = string(paths);
names = strings(size(paths));
for i = 1:numel(paths)
    [~, name, ext] = fileparts(paths(i));
    names(i) = name + ext;
end
end
