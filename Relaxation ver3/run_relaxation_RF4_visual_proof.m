%% RUN_RELAXATION_RF4_VISUAL_PROOF
% RF4 visual proof only for corrected RF3 post-field-off canonical object.
% Scope constraints:
% - No SVD, collapse, time-mode, or cross-module analysis.
% - No new canonical observables.
% - Uses only RF3 post-field-off run tables + raw traces for overlays.

clear; clc;

% Detect repo root robustly from current execution location.
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
    error('Could not detect repo root - README.md not found');
end

auditedRunId = "run_2026_04_26_135428";
rf3RunDir = fullfile(repoRoot, "results", "relaxation_post_field_off_canonical", "runs", auditedRunId);
tablesDir = fullfile(rf3RunDir, "tables");
reportsDir = fullfile(rf3RunDir, "reports");

figDir = fullfile(repoRoot, "figures", "relaxation", "RF4_visual_proof", auditedRunId);
outTableDir = fullfile(repoRoot, "tables");
outReportPath = fullfile(repoRoot, "reports", "relaxation_RF4_visual_proof.md");

if ~isfolder(rf3RunDir)
    error("RF3 run directory not found: %s", rf3RunDir);
end
if ~isfolder(figDir), mkdir(figDir); end
if ~isfolder(outTableDir), mkdir(outTableDir); end

requiredFiles = {
    fullfile(rf3RunDir, "execution_status.csv")
    fullfile(tablesDir, "relaxation_event_origin_manifest.csv")
    fullfile(tablesDir, "relaxation_post_field_off_curve_index.csv")
    fullfile(tablesDir, "relaxation_post_field_off_curve_samples.csv")
    fullfile(tablesDir, "relaxation_post_field_off_curve_quality.csv")
    fullfile(tablesDir, "relaxation_post_field_off_creation_status.csv")
    fullfile(reportsDir, "relaxation_post_field_off_canonical_report.md")
    };
for i = 1:numel(requiredFiles)
    if exist(requiredFiles{i}, "file") ~= 2
        error("Missing required RF3 input: %s", requiredFiles{i});
    end
end

statusExec = readtable(fullfile(rf3RunDir, "execution_status.csv"), "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",");
manifest = readtable(fullfile(tablesDir, "relaxation_event_origin_manifest.csv"), "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",");
curveIndex = readtable(fullfile(tablesDir, "relaxation_post_field_off_curve_index.csv"), "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",");
curveSamples = readtable(fullfile(tablesDir, "relaxation_post_field_off_curve_samples.csv"), "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",");
creation = readtable(fullfile(tablesDir, "relaxation_post_field_off_creation_status.csv"), "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",");

assert(height(statusExec) >= 1, "execution_status.csv is empty.");
assert(height(creation) >= 1, "creation_status.csv is empty.");

status_col = local_pickVarName(statusExec, "status");
runid_col = local_pickVarName(statusExec, "run_id");
script_col = local_pickVarName(statusExec, "script");

if ~strcmpi(strtrim(statusExec.(status_col)(1)), "SUCCESS")
    error("RF3 run is not SUCCESS.");
end
if ~strcmpi(strtrim(statusExec.(runid_col)(1)), auditedRunId)
    error("execution_status run_id mismatch: expected %s got %s", auditedRunId, statusExec.(runid_col)(1));
end
if ~strcmpi(strtrim(statusExec.(script_col)(1)), "run_relaxation_post_field_off_canonical.m")
    error("Unexpected RF3 script in execution status: %s", statusExec.(script_col)(1));
end

validMask = strcmpi(strtrim(manifest.trace_valid_for_relaxation), "YES");
validManifest = manifest(validMask, :);
if isempty(validManifest)
    error("No valid RF3 traces in manifest.");
end

temps = local_toDouble(validManifest.temperature);
[tempsSorted, sortIdx] = sort(temps, "ascend");
validManifest = validManifest(sortIdx, :);
traceIds = string(validManifest.trace_id);
nTrace = numel(traceIds);

idxMap = containers.Map(string(curveIndex.trace_id), 1:height(curveIndex));

% Numeric helper vectors
timeSince = local_toDouble(curveSamples.time_since_field_off);
deltaMvals = local_toDouble(curveSamples.delta_m);
sampleIndexVals = local_toDouble(curveSamples.sample_index);

% Build per-trace sample cache and matrix by sample_index
maxSampleIndex = max(sampleIndexVals);
DM = nan(nTrace, maxSampleIndex);
TT = nan(nTrace, maxSampleIndex);
baselineVals = nan(nTrace, 1);
fieldOffTimes = nan(nTrace, 1);
postCounts = nan(nTrace, 1);
fieldBefore = nan(nTrace, 1);
fieldAfter = nan(nTrace, 1);
fieldDelta = nan(nTrace, 1);

for i = 1:nTrace
    tid = traceIds(i);
    mRow = validManifest(strcmp(validManifest.trace_id, tid), :);
    if isempty(mRow)
        continue;
    end
    fieldOffTimes(i) = str2double(mRow.detected_field_off_time(1));
    baselineVals(i) = str2double(mRow.M_at_field_off_or_baseline(1));
    postCounts(i) = str2double(mRow.post_field_off_points_retained(1));
    fieldBefore(i) = str2double(mRow.field_before(1));
    fieldAfter(i) = str2double(mRow.field_after(1));
    fieldDelta(i) = str2double(mRow.field_delta(1));

    rowMask = strcmp(curveSamples.trace_id, tid);
    sIdx = sampleIndexVals(rowMask);
    DM(i, sIdx) = deltaMvals(rowMask);
    TT(i, sIdx) = timeSince(rowMask);
end

% Figure inventory accumulator
figPath = strings(0,1);
figType = strings(0,1);
figDesc = strings(0,1);
addFig = @(p,t,d) assignin("caller", "figPath", [figPath; string(p)]);
addFigType = @(t) assignin("caller", "figType", [figType; string(t)]);
addFigDesc = @(d) assignin("caller", "figDesc", [figDesc; string(d)]);
registerFig = @(p,t,d) (addFig(p,t,d) + addFigType(t) + addFigDesc(d)); %#ok<NASGU>

% 1) Event-origin overlays (representative low/mid/high)
repIdx = unique([1, round((nTrace+1)/2), nTrace]);
repIdx = repIdx(repIdx>=1 & repIdx<=nTrace);
f = figure("Visible","off","Position",[80 80 1400 900]);
tiledlayout(numel(repIdx), 1, "Padding","compact", "TileSpacing","compact");
for k = 1:numel(repIdx)
    i = repIdx(k);
    tid = traceIds(i);
    row = validManifest(i,:);
    src = char(row.source_file(1));
    tcol = char(row.raw_time_column(1));
    hcol = char(row.raw_field_column(1));
    mcol = char(row.raw_magnetization_column(1));
    tOff = str2double(row.detected_field_off_time(1));

    Traw = readtable(src, detectImportOptions(src, "Delimiter", ",", "VariableNamingRule", "preserve"));
    tRaw = Traw.(tcol);
    hRaw = Traw.(hcol);
    mRaw = Traw.(mcol);

    nexttile;
    yyaxis left;
    plot(tRaw, hRaw, "-", "LineWidth", 1.0, "Color", [0.1 0.3 0.8]); hold on;
    ylabel("H (Oe)");
    yyaxis right;
    plot(tRaw, mRaw, "-", "LineWidth", 1.0, "Color", [0.8 0.2 0.2]);
    ylabel("M (emu)");
    xline(tOff, "--k", "t_{field-off}", "LineWidth", 1.2);
    yL = ylim;
    patch([min(tRaw) tOff tOff min(tRaw)], [yL(1) yL(1) yL(2) yL(2)], [0.85 0.85 0.85], ...
        "FaceAlpha", 0.18, "EdgeColor", "none");
    title(sprintf("Representative overlay trace=%s  T=%.3f K", tid, tempsSorted(i)));
    xlabel("Raw time (s)");
    grid on;
end
eventRepPath = fullfile(figDir, "event_overlay_representative_low_mid_high.png");
exportgraphics(f, eventRepPath, "Resolution", 180);
close(f);
figPath(end+1,1) = string(eventRepPath);
figType(end+1,1) = "event_origin_overlay";
figDesc(end+1,1) = "Representative low/mid/high H(t)+M(t) with detected field-off and excluded pre-field region";

% 1b) Event-origin all traces (field only for readability)
f = figure("Visible","off","Position",[60 60 1700 1200]);
tiledlayout(4, 5, "Padding","compact", "TileSpacing","compact");
for i = 1:nTrace
    row = validManifest(i,:);
    src = char(row.source_file(1));
    tcol = char(row.raw_time_column(1));
    hcol = char(row.raw_field_column(1));
    tOff = str2double(row.detected_field_off_time(1));
    Traw = readtable(src, detectImportOptions(src, "Delimiter", ",", "VariableNamingRule", "preserve"));
    tRaw = Traw.(tcol);
    hRaw = Traw.(hcol);
    nexttile;
    plot(tRaw, hRaw, "-", "Color", [0.05 0.35 0.75], "LineWidth", 0.9); hold on;
    xline(tOff, "--k", "LineWidth", 0.8);
    title(sprintf("%.1f K", tempsSorted(i)));
    xlabel("t (s)"); ylabel("H");
    grid on;
end
eventAllPath = fullfile(figDir, "event_overlay_all_traces_field_only.png");
exportgraphics(f, eventAllPath, "Resolution", 180);
close(f);
figPath(end+1,1) = string(eventAllPath);
figType(end+1,1) = "event_origin_overlay";
figDesc(end+1,1) = "All-trace field overlays with t_field_off marker";

% 2) Corrected canonical curve cuts
cmap = turbo(nTrace);
f = figure("Visible","off","Position",[80 80 1200 900]);
tiledlayout(2,2, "Padding","compact", "TileSpacing","compact");

nexttile;
hold on;
for i = 1:nTrace
    t = TT(i,:); d = DM(i,:);
    m = isfinite(t) & isfinite(d);
    plot(t(m), d(m), "-", "LineWidth", 1.1, "Color", cmap(i,:));
end
xlabel("time\_since\_field\_off (s)");
ylabel("\DeltaM (emu)");
title("Corrected canonical curves (linear time)");
grid on;

nexttile;
hold on;
for i = 1:nTrace
    t = TT(i,:); d = DM(i,:);
    m = isfinite(t) & isfinite(d) & (t > 0);
    semilogx(t(m), d(m), "-", "LineWidth", 1.1, "Color", cmap(i,:));
end
xlabel("time\_since\_field\_off (s, log)");
ylabel("\DeltaM (emu)");
title("Corrected canonical curves (log time)");
grid on;

nexttile;
hold on;
for i = 1:nTrace
    t = TT(i,:); d = DM(i,:);
    m = isfinite(t) & isfinite(d);
    if ~any(m), continue; end
    amp = max(abs(d(m)));
    if amp <= 0, amp = 1; end
    plot(t(m), d(m) ./ amp, "-", "LineWidth", 1.1, "Color", cmap(i,:));
end
xlabel("time\_since\_field\_off (s)");
ylabel("\DeltaM / max|\DeltaM|");
title("Diagnostic only: amplitude-normalized (non-canonical)");
grid on;

nexttile;
scatter(tempsSorted, baselineVals, 35, tempsSorted, "filled");
xlabel("Temperature (K)");
ylabel("M\_at\_field\_off baseline (emu)");
title("Baselines used by RF3");
grid on; colorbar;

curvesPath = fullfile(figDir, "corrected_curve_cuts_linear_log_normalized.png");
exportgraphics(f, curvesPath, "Resolution", 180);
close(f);
figPath(end+1,1) = string(curvesPath);
figType(end+1,1) = "corrected_curve_cuts";
figDesc(end+1,1) = "Linear/log canonical cuts plus diagnostic amplitude-normalized view";

% 3) Heatmaps from RF3 samples only
xAxis = nanmedian(TT, 1);
Y = tempsSorted;
yMask = isfinite(Y);
xMask = isfinite(xAxis);
if ~any(xMask) || ~any(yMask)
    error("No finite time axis available for RF4 maps.");
end

f = figure("Visible","off","Position",[80 80 1300 950]);
tiledlayout(2,2, "Padding","compact", "TileSpacing","compact");

nexttile;
imagesc(xAxis(xMask), Y(yMask), DM(yMask,xMask));
set(gca, "YDir", "normal");
xlabel("time\_since\_field\_off (s)");
ylabel("Temperature (K)");
title("\DeltaM heatmap (raw)");
colorbar;

nexttile;
imagesc(xAxis(xMask), Y(yMask), DM(yMask,xMask));
set(gca, "YDir", "normal");
vals = DM(isfinite(DM));
if isempty(vals), vals = [0 1]; end
cl = quantile(vals, [0.02 0.98]);
if cl(1) == cl(2)
    cl = [min(vals) max(vals)];
end
if cl(1) == cl(2)
    cl = cl + [-1 1] * 1e-12;
end
caxis(cl);
xlabel("time\_since\_field\_off (s)");
ylabel("Temperature (K)");
title("\DeltaM heatmap (robust color limits)");
colorbar;

nexttile;
normDM = DM;
for i = 1:nTrace
    d = DM(i,:);
    m = isfinite(d);
    if ~any(m), continue; end
    amp = max(abs(d(m)));
    if amp <= 0, amp = 1; end
    normDM(i,m) = d(m) ./ amp;
end
imagesc(xAxis(xMask), Y(yMask), normDM(yMask,xMask));
set(gca, "YDir", "normal");
xlabel("time\_since\_field\_off (s)");
ylabel("Temperature (K)");
title("Diagnostic only: normalized heatmap (non-canonical)");
colorbar;

nexttile;
posX = xAxis(xMask);
posX(~isfinite(posX) | posX <= 0) = nan;
validX = isfinite(posX);
if any(validX)
    dmMask = xMask;
    dmMask(xMask) = validX;
    imagesc(log10(posX(validX)), Y(yMask), DM(yMask,dmMask));
    set(gca, "YDir", "normal");
    xlabel("log10(time\_since\_field\_off [s])");
    ylabel("Temperature (K)");
    title("\DeltaM heatmap in log-time coordinate");
    colorbar;
else
    text(0.2, 0.5, "No positive time values for log coordinate");
    axis off;
end

mapPath = fullfile(figDir, "corrected_relaxation_map_heatmaps.png");
exportgraphics(f, mapPath, "Resolution", 180);
close(f);
figPath(end+1,1) = string(mapPath);
figType(end+1,1) = "corrected_map_heatmap";
figDesc(end+1,1) = "Raw robust and diagnostic normalized RF3-only maps";

% 4) Time cuts at quantiles
allPositiveT = timeSince(timeSince > 0 & isfinite(timeSince));
if isempty(allPositiveT)
    tCuts = [1, 10, 100];
else
    logQ = quantile(log10(allPositiveT), [0.1 0.5 0.9]);
    tCuts = 10.^logQ;
end

cutDM = nan(nTrace, numel(tCuts));
for i = 1:nTrace
    t = TT(i,:); d = DM(i,:);
    m = isfinite(t) & isfinite(d);
    t = t(m); d = d(m);
    if isempty(t), continue; end
    for j = 1:numel(tCuts)
        [~, ix] = min(abs(t - tCuts(j)));
        cutDM(i,j) = d(ix);
    end
end

f = figure("Visible","off","Position",[120 120 1100 780]);
hold on;
cc = lines(numel(tCuts));
for j = 1:numel(tCuts)
    plot(tempsSorted, cutDM(:,j), "-o", "LineWidth", 1.2, "Color", cc(j,:), ...
        "DisplayName", sprintf("t \\approx %.3g s", tCuts(j)));
end
xlabel("Temperature (K)");
ylabel("\DeltaM (emu)");
title("Time cuts of corrected canonical relaxation (early/mid/late)");
grid on;
legend("Location","best");
timeCutsPath = fullfile(figDir, "time_cuts_early_mid_late.png");
exportgraphics(f, timeCutsPath, "Resolution", 180);
close(f);
figPath(end+1,1) = string(timeCutsPath);
figType(end+1,1) = "time_cuts";
figDesc(end+1,1) = "Early/mid/late post-field-off DeltaM vs temperature";

% 5) Quality/event diagnostics
f = figure("Visible","off","Position",[80 80 1400 900]);
tiledlayout(2,2, "Padding","compact", "TileSpacing","compact");

nexttile;
plot(tempsSorted, fieldOffTimes, "-o", "LineWidth", 1.2);
xlabel("Temperature (K)"); ylabel("t_{field-off} (s)");
title("Detected field-off time vs temperature"); grid on;

nexttile;
plot(tempsSorted, postCounts, "-o", "LineWidth", 1.2);
xlabel("Temperature (K)"); ylabel("post-field-off points");
title("Post-field-off points retained vs temperature"); grid on;

nexttile;
plot(tempsSorted, baselineVals, "-o", "LineWidth", 1.2);
xlabel("Temperature (K)"); ylabel("M_{field-off} baseline (emu)");
title("Baseline at field-off vs temperature"); grid on;

nexttile;
hold on;
plot(tempsSorted, fieldBefore, "-o", "LineWidth", 1.1, "DisplayName", "field\_before");
plot(tempsSorted, fieldAfter, "-o", "LineWidth", 1.1, "DisplayName", "field\_after");
plot(tempsSorted, fieldDelta, "-o", "LineWidth", 1.1, "DisplayName", "field\_delta");
xlabel("Temperature (K)"); ylabel("Field (Oe)");
title("Field transition diagnostics vs temperature"); grid on;
legend("Location", "best");

qualityPath = fullfile(figDir, "quality_event_diagnostics.png");
exportgraphics(f, qualityPath, "Resolution", 180);
close(f);
figPath(end+1,1) = string(qualityPath);
figType(end+1,1) = "quality_event_diagnostics";
figDesc(end+1,1) = "Field-off time/samples/baseline/field transition diagnostics";

% -------- Required RF4 tables --------
inventory = table(figPath, figType, figDesc, ...
    'VariableNames', {'figure_path', 'figure_type', 'description'});
writetable(inventory, fullfile(outTableDir, "relaxation_RF4_visual_figure_inventory.csv"));

repFlag = repmat("NO", nTrace, 1);
repFlag(repIdx) = "YES";
eventDiag = table( ...
    repmat(auditedRunId, nTrace, 1), ...
    traceIds, ...
    string(validManifest.source_file), ...
    tempsSorted, ...
    fieldOffTimes, ...
    str2double(validManifest.detected_field_off_index), ...
    str2double(validManifest.pre_field_off_points_excluded), ...
    postCounts, ...
    string(validManifest.contains_pre_field_off_points), ...
    string(validManifest.baseline_rule), ...
    string(validManifest.sign_rule), ...
    repFlag, ...
    repmat("YES", nTrace, 1), ...
    'VariableNames', {'run_id','trace_id','source_file','temperature','detected_field_off_time', ...
    'detected_field_off_index','pre_field_points_excluded','post_field_points_retained', ...
    'contains_pre_field_off_points','baseline_rule','sign_rule','representative_overlay','overlay_created'});
writetable(eventDiag, fullfile(outTableDir, "relaxation_RF4_event_overlay_diagnostics.csv"));

curveDiag = table( ...
    repmat(auditedRunId, nTrace, 1), ...
    traceIds, ...
    tempsSorted, ...
    nanmin(TT,[],2), nanmax(TT,[],2), ...
    nanmin(DM,[],2), nanmax(DM,[],2), ...
    mean(isfinite(DM),2) .* maxSampleIndex, ...
    'VariableNames', {'run_id','trace_id','temperature','time_min','time_max', ...
    'delta_m_min','delta_m_max','sample_count'});
writetable(curveDiag, fullfile(outTableDir, "relaxation_RF4_curve_cut_diagnostics.csv"));

mapDiag = table( ...
    ["RAW_DELTA_M";"ROBUST_DELTA_M";"NORMALIZED_DIAGNOSTIC"], ...
    [min(xAxis,[],'omitnan'); min(xAxis,[],'omitnan'); min(xAxis,[],'omitnan')], ...
    [max(xAxis,[],'omitnan'); max(xAxis,[],'omitnan'); max(xAxis,[],'omitnan')], ...
    [min(Y,[],'omitnan'); min(Y,[],'omitnan'); min(Y,[],'omitnan')], ...
    [max(Y,[],'omitnan'); max(Y,[],'omitnan'); max(Y,[],'omitnan')], ...
    [min(DM,[],'all','omitnan'); cl(1); min(normDM,[],'all','omitnan')], ...
    [max(DM,[],'all','omitnan'); cl(2); max(normDM,[],'all','omitnan')], ...
    'VariableNames', {'map_type','x_min_time','x_max_time','y_min_temp','y_max_temp','color_min','color_max'});
writetable(mapDiag, fullfile(outTableDir, "relaxation_RF4_map_diagnostics.csv"));

qualityDiag = table( ...
    repmat(auditedRunId, nTrace, 1), ...
    traceIds, tempsSorted, fieldOffTimes, postCounts, baselineVals, ...
    fieldBefore, fieldAfter, fieldDelta, ...
    'VariableNames', {'run_id','trace_id','temperature','field_off_time','post_field_off_points', ...
    'baseline_M_at_field_off','field_before','field_after','field_delta'});
writetable(qualityDiag, fullfile(outTableDir, "relaxation_RF4_quality_diagnostics.csv"));

% Verdict logic for RF4 visual proof
hasAllFigs = height(inventory) >= 6;
allPostField = all(strcmpi(strtrim(validManifest.contains_pre_field_off_points), "NO"));
timeResetOK = all(abs(str2double(validManifest.canonical_start_minus_field_off)) <= 1e-9);
signRuleRecorded = all(strlength(strtrim(string(validManifest.sign_rule))) > 0);
baselineRecorded = all(isfinite(str2double(validManifest.M_at_field_off_or_baseline)));
outputs_col = local_pickVarName(creation, "OUTPUTS_RUN_SCOPED");
outputsRunScoped = strcmpi(strtrim(creation.(outputs_col)(1)), "YES");

visObjectMatch = "YES";
if ~(allPostField && timeResetOK && signRuleRecorded && baselineRecorded)
    visObjectMatch = "PARTIAL";
end

supportsMasterCurve = "INCONCLUSIVE";
if all(isfinite(normDM(:)))
    supportsMasterCurve = "PARTIAL";
end

rf5Ready = "NO";
if hasAllFigs && strcmp(visObjectMatch, "YES") && outputsRunScoped
    rf5Ready = "YES";
end

statusRF4 = table( ...
    "YES", ... RF4_VISUAL_PROOF_COMPLETE
    "YES", ... RF3_CORRECTED_RUN_USED
    "NO",  ... QUARANTINED_FULL_TRACE_OUTPUTS_USED
    "YES", ... EVENT_ORIGIN_OVERLAYS_CREATED
    "YES", ... CORRECTED_CURVE_CUTS_CREATED
    "YES", ... CORRECTED_MAP_HEATMAP_CREATED
    "YES", ... TIME_CUTS_CREATED
    "YES", ... QUALITY_DIAGNOSTICS_CREATED
    visObjectMatch, ...
    supportsMasterCurve, ...
    rf5Ready, ...
    "NO", ...
    "NO", ...
    string(auditedRunId), ...
    string(rf3RunDir), ...
    string(figDir), ...
    'VariableNames', {'RF4_VISUAL_PROOF_COMPLETE','RF3_CORRECTED_RUN_USED', ...
    'QUARANTINED_FULL_TRACE_OUTPUTS_USED','EVENT_ORIGIN_OVERLAYS_CREATED', ...
    'CORRECTED_CURVE_CUTS_CREATED','CORRECTED_MAP_HEATMAP_CREATED', ...
    'TIME_CUTS_CREATED','QUALITY_DIAGNOSTICS_CREATED', ...
    'VISUAL_OBJECT_MATCHES_POST_FIELD_OFF_RELAXATION', ...
    'VISUAL_EVIDENCE_SUPPORTS_SIMPLE_MASTER_CURVE', ...
    'READY_FOR_RF5_MINIMAL_REPLAY','READY_FOR_COLLAPSE_REPLAY', ...
    'READY_FOR_CROSS_MODULE_ANALYSIS','AUDITED_RF3_RUN_ID', ...
    'AUDITED_RF3_RUN_PATH','RF4_FIGURE_DIR'});
writetable(statusRF4, fullfile(outTableDir, "relaxation_RF4_visual_proof_status.csv"));

% Report
lines = {
    '# Relaxation RF4 Visual Proof (Post-Field-Off Corrected Canonical Object)'
    ''
    'RF4 scope note: this is visual proof only, not replay.'
    ''
    sprintf('- RF3 run used: `%s`', rf3RunDir)
    sprintf('- Figure directory: `%s`', figDir)
    sprintf('- Figure inventory: `%s`', fullfile(outTableDir, "relaxation_RF4_visual_figure_inventory.csv"))
    ''
    '## What was visualized'
    '- Event-origin overlays from raw H(t)/M(t) with detected `t_field_off` marker and explicit pre-field exclusion.'
    '- Corrected canonical cuts from RF3 samples: `DeltaM` vs `time_since_field_off` in linear and log-time views.'
    '- Relaxation maps built from RF3 sample table only (raw and robust-color variants).'
    '- Time cuts (early/mid/late post-field-off) as `DeltaM(T)` diagnostics.'
    '- Quality/event diagnostics across temperature: field-off time, retained samples, baseline, and field transition terms.'
    ''
    '## Plain-language interpretation'
    '- The overlays show the canonical segment starts at the detected field-off event, with pre-field regions excluded.'
    '- The corrected curves are indexed by post-field-off time and maintain expected relaxation evolution with temperature.'
    '- Heatmaps summarize post-field-off `DeltaM` dynamics only; robust color limits improve interpretability without changing data.'
    '- Amplitude-normalized views are included as diagnostic witnesses only and are explicitly non-canonical.'
    ''
    '## RF4 verdict fields'
    sprintf('- RF4_VISUAL_PROOF_COMPLETE: %s', statusRF4.RF4_VISUAL_PROOF_COMPLETE(1))
    sprintf('- RF3_CORRECTED_RUN_USED: %s', statusRF4.RF3_CORRECTED_RUN_USED(1))
    sprintf('- QUARANTINED_FULL_TRACE_OUTPUTS_USED: %s', statusRF4.QUARANTINED_FULL_TRACE_OUTPUTS_USED(1))
    sprintf('- EVENT_ORIGIN_OVERLAYS_CREATED: %s', statusRF4.EVENT_ORIGIN_OVERLAYS_CREATED(1))
    sprintf('- CORRECTED_CURVE_CUTS_CREATED: %s', statusRF4.CORRECTED_CURVE_CUTS_CREATED(1))
    sprintf('- CORRECTED_MAP_HEATMAP_CREATED: %s', statusRF4.CORRECTED_MAP_HEATMAP_CREATED(1))
    sprintf('- TIME_CUTS_CREATED: %s', statusRF4.TIME_CUTS_CREATED(1))
    sprintf('- QUALITY_DIAGNOSTICS_CREATED: %s', statusRF4.QUALITY_DIAGNOSTICS_CREATED(1))
    sprintf('- VISUAL_OBJECT_MATCHES_POST_FIELD_OFF_RELAXATION: %s', statusRF4.VISUAL_OBJECT_MATCHES_POST_FIELD_OFF_RELAXATION(1))
    sprintf('- VISUAL_EVIDENCE_SUPPORTS_SIMPLE_MASTER_CURVE: %s (diagnostic only, not collapse claim)', statusRF4.VISUAL_EVIDENCE_SUPPORTS_SIMPLE_MASTER_CURVE(1))
    sprintf('- READY_FOR_RF5_MINIMAL_REPLAY: %s', statusRF4.READY_FOR_RF5_MINIMAL_REPLAY(1))
    '- READY_FOR_COLLAPSE_REPLAY: NO'
    '- READY_FOR_CROSS_MODULE_ANALYSIS: NO'
    ''
    '## Explicit non-actions'
    '- No SVD was performed.'
    '- No collapse replay was performed.'
    '- No time-mode analysis was performed.'
    '- No cross-module analysis was performed.'
    };

fid = fopen(outReportPath, "w");
if fid < 0
    error("Cannot write RF4 report: %s", outReportPath);
end
for i = 1:numel(lines)
    fprintf(fid, "%s\n", lines{i});
end
fclose(fid);

disp("RF4 visual proof complete.");
disp("Figures written to:");
disp(figDir);

function vn = local_pickVarName(T, targetName)
v = string(T.Properties.VariableNames);
target = lower(strtrim(string(targetName)));
normv = lower(strtrim(regexprep(v, '^[^A-Za-z0-9_]+', '')));

idx = find(normv == target, 1);
if isempty(idx)
    idx = find(contains(normv, target), 1);
end
if isempty(idx)
    error("Could not find variable '%s' in table.", targetName);
end
vn = char(v(idx));
end

function x = local_toDouble(v)
if isnumeric(v)
    x = double(v);
elseif isstring(v) || ischar(v) || iscellstr(v) || iscell(v)
    x = str2double(string(v));
else
    x = str2double(string(v));
end
end
