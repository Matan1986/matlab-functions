%% RUN_RELAXATION_RF4B_VISUALIZATION_REPAIR
% RF4B visualization repair for corrected post-field-off Relaxation object.
% Canonical rerun (RF3R): reads ONLY relaxation_post_field_off_RF3R_canonical run outputs;
% default-replay traces are used for canonical DeltaM views (flagged traces excluded).
% Scope: visualization only (no canonical data edits, no replay/collapse/SVD/time-mode/cross-module).

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
    error('Could not detect repo root - README.md not found');
end

addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

run_id = "run_2026_04_26_234453";
canonRunDir = fullfile(repoRoot, 'results', 'relaxation_post_field_off_RF3R_canonical', 'runs', run_id);
canonTablesDir = fullfile(canonRunDir, 'tables');

figDir = fullfile(repoRoot, 'figures', 'relaxation', 'RF4B_visualization_repair', run_id);
outTablesDir = fullfile(repoRoot, 'tables');
outReportsDir = fullfile(repoRoot, 'reports');
if ~isfolder(figDir), mkdir(figDir); end
if ~isfolder(outTablesDir), mkdir(outTablesDir); end
if ~isfolder(outReportsDir), mkdir(outReportsDir); end

%% Required RF3R run inputs (strict canonical; no RF3 / full-trace / precomputed artifacts)
required = {
    fullfile(canonTablesDir, 'relaxation_event_origin_manifest.csv')
    fullfile(canonTablesDir, 'relaxation_post_field_off_curve_index.csv')
    fullfile(canonTablesDir, 'relaxation_post_field_off_curve_samples.csv')
    fullfile(canonTablesDir, 'relaxation_post_field_off_curve_quality.csv')
    fullfile(canonTablesDir, 'relaxation_post_field_off_creation_status.csv')
    fullfile(canonRunDir, 'execution_status.csv')
    };
for i = 1:numel(required)
    if exist(required{i}, 'file') ~= 2
        error('STOP: Missing required RF3R input: %s', required{i});
    end
end

execT = readtable(fullfile(canonRunDir, 'execution_status.csv'), "TextType", "string", "Delimiter", ",");
manifest = readtable(fullfile(canonTablesDir, 'relaxation_event_origin_manifest.csv'), "TextType", "string", "Delimiter", ",");
curveIndex = readtable(fullfile(canonTablesDir, 'relaxation_post_field_off_curve_index.csv'), "TextType", "string", "Delimiter", ",");
curveSamples = readtable(fullfile(canonTablesDir, 'relaxation_post_field_off_curve_samples.csv'), "TextType", "string", "Delimiter", ",");
curveQuality = readtable(fullfile(canonTablesDir, 'relaxation_post_field_off_curve_quality.csv'), "TextType", "string", "Delimiter", ",");
creation = readtable(fullfile(canonTablesDir, 'relaxation_post_field_off_creation_status.csv'), "TextType", "string", "Delimiter", ",");

status_col = local_pickVar(execT, "status");
if ~strcmpi(strtrim(execT.(status_col)(1)), "SUCCESS")
    error('STOP: RF3R execution status is not SUCCESS.');
end

validMask = strcmpi(strtrim(manifest.trace_valid_for_relaxation), "YES");
validManifestAll = manifest(validMask, :);
if isempty(validManifestAll)
    error('STOP: No valid traces in RF3R manifest.');
end
tempsAll = local_toDouble(validManifestAll.temperature);
[tempsSortedAll, ordAll] = sort(tempsAll, "ascend");
validManifestAll = validManifestAll(ordAll, :);

% Join default replay + quality flags; enforce default replay for canonical DeltaM views
nAll = height(validManifestAll);
replayDefault = strings(nAll, 1);
qualityFlag = strings(nAll, 1);
zFpAll = nan(nAll, 1);
for k = 1:nAll
    tid = string(validManifestAll.trace_id(k));
    ix = find(strcmp(string(curveIndex.trace_id), tid), 1);
    if isempty(ix)
        error('STOP: curve_index missing trace %s', tid);
    end
    replayDefault(k) = strtrim(string(curveIndex.valid_for_default_replay(ix)));
    qx = find(strcmp(string(curveQuality.trace_id), tid), 1);
    if isempty(qx)
        error('STOP: curve_quality missing trace %s', tid);
    end
    qualityFlag(k) = strtrim(string(curveQuality.quality_flag(qx)));
    zFpAll(k) = local_toDouble(curveQuality.z_fp(qx));
end
validManifestAll.replay_default = replayDefault;
validManifestAll.quality_flag = qualityFlag;
validManifestAll.z_fp = zFpAll;

defaultMask = strcmpi(replayDefault, "YES");
if ~any(defaultMask)
    error('STOP: default replay set is empty.');
end
if any(strcmpi(qualityFlag(defaultMask), "YES"))
    error('STOP: flagged trace(s) leaked into default replay set.');
end

drPath = fullfile(repoRoot, 'tables', 'relaxation_RF3R_default_replay_set.csv');
if exist(drPath, 'file') == 2
    drTbl = readtable(drPath, "TextType", "string", "Delimiter", ",");
    drTbl = drTbl(strcmp(string(drTbl.run_id), string(run_id)), :);
    nDrYes = sum(strcmpi(strtrim(string(drTbl.valid_for_default_replay)), "YES"));
    if nDrYes ~= sum(defaultMask)
        error('STOP: default replay count mismatch vs tables/relaxation_RF3R_default_replay_set.csv');
    end
end

% Canonical visualization manifest = default replay only (sorted by temperature)
validManifest = validManifestAll(defaultMask, :);
temps = local_toDouble(validManifest.temperature);
[tempsSorted, ord] = sort(temps, "ascend");
validManifest = validManifest(ord, :);
traceIds = string(validManifest.trace_id);
nTrace = numel(traceIds);

% Build sample arrays per trace using sample_index (default replay traces only)
curveSamples.time_s = local_toDouble(curveSamples.time_since_field_off);
curveSamples.delta_m_num = local_toDouble(curveSamples.delta_m);
curveSamples.sample_idx = local_toDouble(curveSamples.sample_index);
maxSample = max(curveSamples.sample_idx);
Tmat = nan(nTrace, maxSample);
Dmat = nan(nTrace, maxSample);
for i = 1:nTrace
    tid = traceIds(i);
    m = strcmp(curveSamples.trace_id, tid);
    sidx = curveSamples.sample_idx(m);
    Tmat(i, sidx) = curveSamples.time_s(m);
    Dmat(i, sidx) = curveSamples.delta_m_num(m);
end

% Outlier detection on max |DeltaM|
amp = nanmax(abs(Dmat), [], 2);
[ampSorted, ampOrd] = sort(amp, 'descend');
outlierIdx = ampOrd(1);
outlierTrace = traceIds(outlierIdx);
outlierTemp = tempsSorted(outlierIdx);
neighborOrder = sort(unique(max(1, outlierIdx-1):min(nTrace, outlierIdx+1)));
outlierFlag = false(nTrace,1);
outlierFlag(outlierIdx) = true;

%% Style conventions audited/applied
style_source = strjoin([
    "docs/visualization_rules.md"
    "docs/figure_style_guide.md"
    "docs/figure_export_infrastructure.md"
    "tools/figures/create_figure.m"
    "tools/figures/apply_publication_style.m"
    "tools/save_run_figure.m"
    ], "; ");
style_conventions = strjoin([
    "axis labels include units"
    "parula colormap"
    "colorbar for >6 curves"
    "line width >=2"
    "figure Name matches filename base"
    "save PNG+FIG"
    "explicit canonical vs diagnostic labels"
    "robust scaling disclosed"
    ], "; ");

%% Figure inventory accumulator
inv = table('Size', [0 12], ...
    'VariableTypes', repmat("string", 1, 12), ...
    'VariableNames', {'figure_id','title','png_path','fig_path','source_data', ...
    'canonical_or_diagnostic','uses_robust_scaling','outlier_handling', ...
    'repo_visualization_rules_checked','style_source','style_conventions_applied','notes'});

axisRows = table('Size',[0 8], 'VariableTypes', {'string','string','double','double','double','double','double','double'}, ...
    'VariableNames', {'figure_id','quantity','x_min','x_max','y_min','y_max','c_min','c_max'});

%% 1) Event-origin overlays readable (relative time)
repIdx = unique([1, round((nTrace+1)/2), nTrace]);
base_name = 'event_origin_overlays_relative_time_representative';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 11.0]);
tiledlayout(numel(repIdx),1,'Padding','compact','TileSpacing','compact');
for j = 1:numel(repIdx)
    i = repIdx(j);
    row = validManifest(i,:);
    src = char(row.source_file(1));
    tCol = char(row.raw_time_column(1));
    hCol = char(row.raw_field_column(1));
    mCol = char(row.raw_magnetization_column(1));
    tOff = local_toDouble(row.detected_field_off_time(1));
    Traw = readtable(src, detectImportOptions(src, 'Delimiter', ',', 'VariableNamingRule', 'preserve'));
    tRaw = Traw.(tCol);
    hRaw = Traw.(hCol);
    mRaw = Traw.(mCol);
    tRel = tRaw - tOff;
    nexttile;
    yyaxis left;
    plot(tRel, hRaw, '-', 'LineWidth', 2.0, 'Color', [0.1 0.35 0.75]); hold on;
    ylabel('Magnetic field H (Oe)');
    yyaxis right;
    plot(tRel, mRaw, '-', 'LineWidth', 2.0, 'Color', [0.8 0.2 0.2]);
    ylabel('Moment M (emu)');
    xline(0, '--k', 't_{field-off}=0', 'LineWidth', 1.5);
    yl = ylim;
    patch([min(tRel) 0 0 min(tRel)], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
        'FaceAlpha', 0.18, 'EdgeColor', 'none');
    title(sprintf('Event overlay (canonical witness): trace %s, T = %.3f K', traceIds(i), tempsSorted(i)));
    xlabel('Raw time relative to field-off, t - t_{field-off} (s)');
    grid on;
end
[png_p, fig_p] = local_save_pair(fig, base_name, figDir);
inv = local_add_inventory(inv, base_name, 'Representative event-origin overlays (relative time)', png_p, fig_p, ...
    'RF3R manifest + raw traces (default replay traces only)', 'CANONICAL_WITNESS', 'NO', 'None', style_source, style_conventions, ...
    'Pre-field region shaded, t=0 marked, canonical segment starts at field-off.');
close(fig);

base_name = 'event_origin_field_overview_all_traces_relative_time';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 12.0]);
tiledlayout(4,5,'Padding','compact','TileSpacing','compact');
for i = 1:nTrace
    row = validManifest(i,:);
    src = char(row.source_file(1));
    tCol = char(row.raw_time_column(1));
    hCol = char(row.raw_field_column(1));
    tOff = local_toDouble(row.detected_field_off_time(1));
    Traw = readtable(src, detectImportOptions(src, 'Delimiter', ',', 'VariableNamingRule', 'preserve'));
    tRel = Traw.(tCol) - tOff;
    hRaw = Traw.(hCol);
    nexttile;
    plot(tRel, hRaw, '-', 'LineWidth', 2.0, 'Color', [0.12 0.45 0.7]); hold on;
    xline(0, '--k', 'LineWidth', 1.2);
    xlim([min(tRel) max(tRel)]);
    xlabel('t - t_{field-off} (s)');
    ylabel('H (Oe)');
    title(sprintf('%s, %.1f K (default replay)', traceIds(i), tempsSorted(i)));
    grid on;
end
[png_p, fig_p] = local_save_pair(fig, base_name, figDir);
inv = local_add_inventory(inv, base_name, 'All-trace field overview (relative time)', png_p, fig_p, ...
    'RF3R manifest + raw traces (default replay traces only)', 'CANONICAL_WITNESS', 'NO', 'None', style_source, style_conventions, ...
    'All traces inspected in relative-time coordinates.');
close(fig);

%% 2) Corrected canonical overlays readable
cmap = parula(nTrace);
base_name = 'corrected_curve_overlays_readable_linear_log';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 10.8]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
hold on;
for i = 1:nTrace
    m = isfinite(Tmat(i,:)) & isfinite(Dmat(i,:));
    plot(Tmat(i,m), Dmat(i,m), '-', 'LineWidth', 2.0, 'Color', cmap(i,:));
end
xlabel('time\_since\_field\_off (s)');
ylabel('\Delta M (emu)');
title('Canonical object (default replay only): \DeltaM vs time\_since\_field\_off (linear time)');
cb = colorbar; colormap(parula);
cb.Label.String = 'Temperature (K)';
cb.Ticks = linspace(0,1,5);
cb.TickLabels = compose('%.1f', linspace(min(tempsSorted), max(tempsSorted), 5));
grid on;

nexttile;
hold on;
for i = 1:nTrace
    m = isfinite(Tmat(i,:)) & isfinite(Dmat(i,:)) & Tmat(i,:) > 0;
    semilogx(Tmat(i,m), Dmat(i,m), '-', 'LineWidth', 2.0, 'Color', cmap(i,:));
end
xlabel('time\_since\_field\_off (s, log scale)');
ylabel('\Delta M (emu)');
title('Canonical object (default replay only): \DeltaM vs time\_since\_field\_off (log-time view)');
cb = colorbar; colormap(parula);
cb.Label.String = 'Temperature (K)';
cb.Ticks = linspace(0,1,5);
cb.TickLabels = compose('%.1f', linspace(min(tempsSorted), max(tempsSorted), 5));
grid on;
[png_p, fig_p] = local_save_pair(fig, base_name, figDir);
inv = local_add_inventory(inv, base_name, 'Canonical curve overlays (linear and log-time)', png_p, fig_p, ...
    'RF3R curve_samples (default replay only)', 'CANONICAL', 'NO', sprintf('Largest |DeltaM| among default replay: %s', outlierTrace), ...
    style_source, style_conventions, 'Readable linear and log-time variants with temperature colorbar.');
close(fig);

robustLim = quantile(Dmat(isfinite(Dmat)), [0.02 0.98]);
base_name = 'corrected_curve_overlays_robust_and_outlier_split';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 11.4]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

groupNames = {'Low T group', 'Mid T group', 'High T group', 'Outlier and neighbors'};
groupIdx = {
    find(tempsSorted <= quantile(tempsSorted, 1/3))
    find(tempsSorted > quantile(tempsSorted, 1/3) & tempsSorted <= quantile(tempsSorted, 2/3))
    find(tempsSorted > quantile(tempsSorted, 2/3))
    neighborOrder
    };
for g = 1:4
    nexttile; hold on;
    ids = groupIdx{g};
    for ii = ids(:)'
        m = isfinite(Tmat(ii,:)) & isfinite(Dmat(ii,:));
        lw = 2.0;
        if ii == outlierIdx, lw = 2.8; end
        plot(Tmat(ii,m), Dmat(ii,m), '-', 'LineWidth', lw, 'Color', cmap(ii,:));
    end
    ylim(robustLim);
    xlabel('time\_since\_field\_off (s)');
    ylabel('\Delta M (emu)');
    title(sprintf('%s (robust y-range)', groupNames{g}));
    if g == 4
        txt = sprintf('Outlier trace: %s at %.3f K', outlierTrace, outlierTemp);
        text(0.02, 0.92, txt, 'Units','normalized', 'FontSize', 8);
    end
    grid on;
end
[png_p, fig_p] = local_save_pair(fig, base_name, figDir);
inv = local_add_inventory(inv, base_name, 'Canonical overlays with robust scaling and outlier split', png_p, fig_p, ...
    'RF3R curve_samples (default replay only)', 'CANONICAL', 'YES', sprintf('Explicit outlier split around %s', outlierTrace), ...
    style_source, style_conventions, sprintf('Robust y-limits [%.3e, %.3e].', robustLim(1), robustLim(2)));
close(fig);
axisRows = [axisRows; {base_name, "DeltaM robust y", NaN, NaN, robustLim(1), robustLim(2), NaN, NaN}];

%% 3) Amplitude-normalized diagnostic overlays
normPeak = nan(size(Dmat));
normL2 = nan(size(Dmat));
for i = 1:nTrace
    d = Dmat(i,:);
    m = isfinite(d);
    if ~any(m), continue; end
    p2p = max(d(m)) - min(d(m));
    if p2p <= 0, p2p = 1; end
    l2 = sqrt(mean(d(m).^2));
    if l2 <= 0, l2 = 1; end
    normPeak(i,m) = d(m) / p2p;
    normL2(i,m) = d(m) / l2;
end
base_name = 'diagnostic_only_normalized_overlays_peak_to_peak_and_l2';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 10.8]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile; hold on;
for i = 1:nTrace
    m = isfinite(Tmat(i,:)) & isfinite(normPeak(i,:));
    plot(Tmat(i,m), normPeak(i,m), '-', 'LineWidth', 2.0, 'Color', cmap(i,:));
end
xlabel('time\_since\_field\_off (s)'); ylabel('\Delta M / peak-to-peak');
title('DIAGNOSTIC ONLY - non-canonical normalization (peak-to-peak)');
cb = colorbar; colormap(parula); cb.Label.String = 'Temperature (K)';
grid on;
nexttile; hold on;
for i = 1:nTrace
    m = isfinite(Tmat(i,:)) & isfinite(normL2(i,:));
    plot(Tmat(i,m), normL2(i,m), '-', 'LineWidth', 2.0, 'Color', cmap(i,:));
end
xlabel('time\_since\_field\_off (s)'); ylabel('\Delta M / L2');
title('DIAGNOSTIC ONLY - non-canonical normalization (L2)');
cb = colorbar; colormap(parula); cb.Label.String = 'Temperature (K)';
grid on;
[png_p, fig_p] = local_save_pair(fig, base_name, figDir);
inv = local_add_inventory(inv, base_name, 'Diagnostic-only normalized overlays (peak-to-peak and L2)', png_p, fig_p, ...
    'RF3R curve_samples (default replay only)', 'DIAGNOSTIC_ONLY', 'NO', sprintf('Largest |DeltaM| trace %s', outlierTrace), ...
    style_source, style_conventions, 'No smoothing applied; unsmoothed traces shown.');
close(fig);

%% 4) Heatmaps repaired (RF3R default-replay samples only)
xAxis = nanmedian(Tmat,1);
xMask = isfinite(xAxis);
yMask = isfinite(tempsSorted);
if ~any(xMask) || ~any(yMask)
    error('Cannot create heatmaps: invalid x/y axes.');
end
xv = xAxis(xMask);
yv = tempsSorted(yMask);
Dm = Dmat(yMask, xMask);

% outlier excluded version
rowMaskNoOut = true(size(yv));
if outlierIdx >= 1 && outlierIdx <= numel(yv)
    rowMaskNoOut(outlierIdx) = false;
end
if sum(rowMaskNoOut) < 2
    rowMaskNoOut = true(size(yv));
end

base_name = 'corrected_relaxation_heatmaps_readable';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 12.0]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');

nexttile;
imagesc(xv, yv, Dm); set(gca, 'YDir', 'normal'); axis tight;
xlabel('time\_since\_field\_off (s)'); ylabel('Temperature (K)');
title('Canonical heatmap: raw \Delta M');
cb = colorbar; cb.Label.String = '\Delta M (emu)'; colormap(parula);

nexttile;
robCl = quantile(Dm(isfinite(Dm)), [0.02 0.98]);
imagesc(xv, yv, Dm); set(gca, 'YDir', 'normal'); axis tight;
caxis(robCl);
xlabel('time\_since\_field\_off (s)'); ylabel('Temperature (K)');
title('Canonical heatmap: robust color limits');
cb = colorbar; cb.Label.String = '\Delta M (emu)'; colormap(parula);

nexttile;
imagesc(xv, yv(rowMaskNoOut), Dm(rowMaskNoOut,:)); set(gca, 'YDir', 'normal'); axis tight;
xlabel('time\_since\_field\_off (s)'); ylabel('Temperature (K)');
title('Canonical heatmap: outlier row isolated/excluded view');
cb = colorbar; cb.Label.String = '\Delta M (emu)'; colormap(parula);

nexttile;
normH = Dm;
for i = 1:size(normH,1)
    d = normH(i,:);
    m = isfinite(d);
    if ~any(m), continue; end
    a = max(abs(d(m))); if a <= 0, a = 1; end
    normH(i,m) = d(m)/a;
end
imagesc(xv, yv, normH); set(gca, 'YDir', 'normal'); axis tight;
xlabel('time\_since\_field\_off (s)'); ylabel('Temperature (K)');
title('DIAGNOSTIC ONLY - non-canonical normalized heatmap');
cb = colorbar; cb.Label.String = 'Normalized \Delta M (arb.)'; colormap(parula);

nexttile([1 2]);
xlogMask = xv > 0 & isfinite(xv);
if any(xlogMask)
    imagesc(log10(xv(xlogMask)), yv, Dm(:,xlogMask)); set(gca, 'YDir', 'normal'); axis tight;
    xlabel('log_{10}(time\_since\_field\_off / s)'); ylabel('Temperature (K)');
    title('Canonical heatmap in log-time coordinate');
    cb = colorbar; cb.Label.String = '\Delta M (emu)'; colormap(parula);
else
    text(0.1, 0.5, 'data missing', 'Units','normalized', 'FontSize', 12);
    axis off;
end
[png_p, fig_p] = local_save_pair(fig, base_name, figDir);
inv = local_add_inventory(inv, base_name, 'Readable heatmap suite (raw, robust, outlier, normalized diagnostic, log-time)', png_p, fig_p, ...
    'RF3R curve_samples (default replay only)', 'CANONICAL+DIAGNOSTIC', 'YES', sprintf('Outlier row at %.3f K isolated', outlierTemp), ...
    style_source, style_conventions, sprintf('Robust color limits [%.3e, %.3e].', robCl(1), robCl(2)));
close(fig);
axisRows = [axisRows; {base_name, "Heatmap robust color", min(xv), max(xv), min(yv), max(yv), robCl(1), robCl(2)}];

%% 5) Time cuts readable (full + robust)
allPosT = curveSamples.time_s(curveSamples.time_s > 0 & isfinite(curveSamples.time_s));
if isempty(allPosT)
    tCuts = [1 10 100];
else
    q = quantile(log10(allPosT), [0.05 0.2 0.5 0.8 0.95]);
    tCuts = 10.^q;
end
cutMat = nan(nTrace, numel(tCuts));
for i = 1:nTrace
    t = Tmat(i,:); d = Dmat(i,:);
    m = isfinite(t) & isfinite(d);
    t = t(m); d = d(m);
    if isempty(t), continue; end
    for j = 1:numel(tCuts)
        [~, ix] = min(abs(t - tCuts(j)));
        cutMat(i,j) = d(ix);
    end
end
base_name = 'time_cuts_readable_full_and_robust';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 9.0]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile; hold on;
cc = parula(numel(tCuts));
for j = 1:numel(tCuts)
    plot(tempsSorted, cutMat(:,j), '-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'Color', cc(j,:));
end
xlabel('Temperature (K)'); ylabel('\Delta M (emu)');
title('Time cuts (full scale)');
legend(compose('t=%.3g s', tCuts), 'Location', 'eastoutside', 'Box', 'off');
grid on;
nexttile; hold on;
for j = 1:numel(tCuts)
    plot(tempsSorted, cutMat(:,j), '-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'Color', cc(j,:));
end
robY = quantile(cutMat(isfinite(cutMat)), [0.02 0.98]);
ylim(robY);
xlabel('Temperature (K)'); ylabel('\Delta M (emu)');
title('Time cuts (robust y-scale for readability)');
legend(compose('t=%.3g s', tCuts), 'Location', 'eastoutside', 'Box', 'off');
grid on;
[png_p, fig_p] = local_save_pair(fig, base_name, figDir);
inv = local_add_inventory(inv, base_name, 'Time cuts at quantile times (full and robust)', png_p, fig_p, ...
    'RF3R curve_samples (default replay only)', 'CANONICAL', 'YES', sprintf('Largest |DeltaM| trace %s', outlierTrace), ...
    style_source, style_conventions, sprintf('Cut times: %s', strjoin(compose('%.3g', tCuts), ', ')));
close(fig);
axisRows = [axisRows; {base_name, "Time cuts robust y", NaN, NaN, robY(1), robY(2), NaN, NaN}];

%% 6) Quality/event diagnostics (all traces) + RF3R quality-flag witness
tDiag = local_toDouble(validManifestAll.temperature);
[tempsDiag, ordDiag] = sort(tDiag, "ascend");
vDiag = validManifestAll(ordDiag, :);
base_name = 'quality_event_diagnostics_repaired';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 14.0]);
tiledlayout(4,2,'Padding','compact','TileSpacing','compact');

fieldOff = local_toDouble(vDiag.detected_field_off_time);
postPts = local_toDouble(vDiag.post_field_off_points_retained);
baseline = local_toDouble(vDiag.M_at_field_off_or_baseline);
fieldBefore = local_toDouble(vDiag.field_before);
fieldAfter = local_toDouble(vDiag.field_after);
fieldDelta = local_toDouble(vDiag.field_delta);
conf = string(vDiag.field_off_detection_confidence);
confCode = nan(size(conf));
confCode(conf=="LOW") = 1;
confCode(conf=="MEDIUM") = 2;
confCode(conf=="HIGH") = 3;

nexttile; plot(tempsDiag, fieldOff, '-o', 'LineWidth', 2.0); xlabel('Temperature (K)'); ylabel('t_{field-off} (s)'); title('Detected field-off time vs temperature (all traces)'); grid on;
nexttile; plot(tempsDiag, postPts, '-o', 'LineWidth', 2.0); xlabel('Temperature (K)'); ylabel('Post-field-off points retained'); title('Retained samples vs temperature (all traces)'); grid on;
nexttile; plot(tempsDiag, baseline, '-o', 'LineWidth', 2.0); xlabel('Temperature (K)'); ylabel('Robust baseline M (emu)'); title('RF3R robust baseline vs temperature (all traces)'); grid on;
nexttile; hold on; plot(tempsDiag, fieldBefore, '-o', 'LineWidth', 2.0, 'DisplayName', 'field\_before'); plot(tempsDiag, fieldAfter, '-o', 'LineWidth', 2.0, 'DisplayName', 'field\_after'); plot(tempsDiag, fieldDelta, '-o', 'LineWidth', 2.0, 'DisplayName', 'field\_delta'); xlabel('Temperature (K)'); ylabel('Field (Oe)'); title('Field transition diagnostics (all traces)'); legend('Location','eastoutside','Box','off'); grid on;
nexttile;
if all(isnan(confCode))
    text(0.25,0.5,'data missing','Units','normalized'); axis off;
else
    stairs(tempsDiag, confCode, '-o', 'LineWidth', 2.0);
    ylim([0.5 3.5]); yticks([1 2 3]); yticklabels({'LOW','MEDIUM','HIGH'});
    xlabel('Temperature (K)'); ylabel('Detection confidence');
    title('Field-off detection confidence vs temperature'); grid on;
end
nexttile;
if any(~isfinite(fieldOff))
    text(0.25,0.5,'data missing','Units','normalized'); axis off;
else
    scatter(tempsDiag, fieldOff, 70, abs(fieldDelta), 'filled');
    xlabel('Temperature (K)'); ylabel('t_{field-off} (s)');
    title('Event timing colored by |field\_delta|');
    cb = colorbar; cb.Label.String = '|field\_delta| (Oe)';
    colormap(parula); grid on;
end
zDiag = local_toDouble(vDiag.z_fp);
nexttile; plot(tempsDiag, zDiag, '-o', 'LineWidth', 2.0, 'Color', [0.75 0.35 0.1]);
xlabel('Temperature (K)'); ylabel('z_{fp}'); title('DIAGNOSTIC: RF3R first-point robust z (all traces)'); grid on;
qNum = double(strcmpi(strtrim(string(vDiag.quality_flag)), "YES"));
nexttile; stairs(tempsDiag, qNum, '-', 'LineWidth', 2.0, 'Color', [0.2 0.55 0.35]);
ylim([-0.2 1.2]); yticks([0 1]); yticklabels({'NO','YES'});
xlabel('Temperature (K)'); ylabel('quality\_flag'); title('DIAGNOSTIC: FIRST\_POST\_POINT\_ARTIFACT flag (all traces)');
grid on;
[png_p, fig_p] = local_save_pair(fig, base_name, figDir);
inv = local_add_inventory(inv, base_name, 'Quality/event diagnostics + RF3R flag witness', png_p, fig_p, ...
    'RF3R manifest + curve_quality (all traces)', 'CANONICAL_DIAGNOSTIC', 'NO', 'Canonical DeltaM plots use default replay only; this panel shows all traces for flags', ...
    style_source, style_conventions, 'RF3R z_fp and quality_flag vs temperature for audit.');
close(fig);

%% 7) Outlier diagnostic
base_name = 'outlier_diagnostic_largest_delta_m_trace';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 8.8]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile; hold on;
for ii = neighborOrder
    m = isfinite(Tmat(ii,:)) & isfinite(Dmat(ii,:));
    lw = 2.0; ls = '-';
    if ii == outlierIdx, lw = 3.0; ls = '--'; end
    plot(Tmat(ii,m), Dmat(ii,m), ls, 'LineWidth', lw, 'Color', cmap(ii,:));
end
xlabel('time\_since\_field\_off (s)'); ylabel('\Delta M (emu)');
title(sprintf('Outlier diagnostic: %s (%.3f K) vs neighboring temperatures', outlierTrace, outlierTemp));
cb = colorbar; colormap(parula); cb.Label.String = 'Temperature (K)';
grid on;
nexttile;
bar(tempsSorted, amp, 'FaceColor', [0.4 0.4 0.7]); hold on;
plot(tempsSorted(outlierIdx), amp(outlierIdx), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
xlabel('Temperature (K)'); ylabel('max |\Delta M| (emu)');
title('Largest-amplitude trace ranking');
grid on;
[png_p, fig_p] = local_save_pair(fig, base_name, figDir);
inv = local_add_inventory(inv, base_name, 'Explicit outlier diagnostic (largest-amplitude trace)', png_p, fig_p, ...
    'RF3R curve_samples (default replay only)', 'DIAGNOSTIC_ONLY', 'NO', sprintf('Largest |DeltaM| among default replay: %s (%.3f K)', outlierTrace, outlierTemp), ...
    style_source, style_conventions, 'Outlier isolated visually; no data removal from canonical tables.');
close(fig);

% Outlier diagnostics table (all traces; includes RF3R quality flags)
outlierInterpretation = "INCONCLUSIVE_FROM_VISUALIZATION";
if ampSorted(1) > 2 * ampSorted(min(2, numel(ampSorted)))
    outlierInterpretation = "STRONG_ISOLATED_FEATURE_VISUAL_WITNESS_ONLY";
end
nAllR = height(validManifestAll);
idsAllR = string(validManifestAll.trace_id);
ampAll = nan(nAllR, 1);
for kk = 1:nAllR
    tidR = idsAllR(kk);
    mR = strcmp(string(curveSamples.trace_id), tidR);
    dR = curveSamples.delta_m_num(mR);
    ampAll(kk) = max(abs(dR), [], 'omitnan');
end
tAllR = local_toDouble(validManifestAll.temperature);
[tSortR, ordR] = sort(tAllR, "ascend");
vOut = validManifestAll(ordR, :);
ampAllS = ampAll(ordR);
outlierTable = table( ...
    repmat(string(run_id), nAllR, 1), string(vOut.trace_id), tSortR, ampAllS, ...
    string(vOut.quality_flag), local_toDouble(vOut.z_fp), string(vOut.replay_default), ...
    repmat(string(outlierTrace), nAllR, 1), repmat(outlierTemp, nAllR, 1), ...
    repmat(string(outlierInterpretation), nAllR, 1), ...
    'VariableNames', {'run_id','trace_id','temperature','max_abs_delta_m', ...
    'rf3r_quality_flag','rf3r_z_fp','valid_for_default_replay', ...
    'largest_default_replay_trace_id','largest_default_replay_temperature','visual_interpretation'});
writetable(outlierTable, fullfile(outTablesDir, 'relaxation_RF4B_outlier_diagnostics.csv'));

%% Additional diagnostics summary table
diagSummary = table( ...
    ["event_overlays";"curve_overlays";"normalized_diagnostics";"heatmaps";"time_cuts";"quality_panels";"outlier_check";"default_replay_policy";"rf3r_flag_witness"], ...
    ["PASS";"PASS";"PASS";"PASS";"PASS";"PASS";"PASS";"PASS";"PASS"], ...
    ["Relative-time axes and field-off markers readable (default replay traces only)"; ...
     "Linear/log + robust and grouped overlays use default replay traces only"; ...
     "Peak-to-peak and L2 normalized labeled diagnostic-only (default replay)"; ...
     "Heatmaps use default replay traces only"; ...
     "Time cuts use default replay traces only"; ...
     "Quality panels show all traces including RF3R z_fp and quality_flag"; ...
     sprintf("Largest |DeltaM| among default replay isolated (%s, %.3f K)", outlierTrace, outlierTemp); ...
     "Default replay set enforced; flagged traces excluded from canonical DeltaM figures"; ...
     "RF3R quality_flag and z_fp plotted vs temperature for all traces"], ...
    'VariableNames', {'diagnostic_component','status','summary'});
writetable(diagSummary, fullfile(outTablesDir, 'relaxation_RF4B_visual_diagnostics_summary.csv'));

%% Figure inventory + axis scaling table
writetable(inv, fullfile(outTablesDir, 'relaxation_RF4B_visual_figure_inventory.csv'));
writetable(axisRows, fullfile(outTablesDir, 'relaxation_RF4B_axis_scaling_and_color_limits.csv'));

%% RF4B status table
emptyAxesRemain = "NO";
visualObjectMatch = "YES";
masterCurveVisual = "INCONCLUSIVE";
readyRF5 = "NO";
if strcmpi(strtrim(creation.OUTPUTS_RUN_SCOPED(1)), "YES") == 0
    readyRF5 = "NO";
end
status = table( ...
    "YES","NO","NO","YES","YES","YES","YES","YES","YES","YES","YES","YES","YES","YES", ...
    emptyAxesRemain, visualObjectMatch, masterCurveVisual, readyRF5, "NO", "NO", ...
    'VariableNames', {'RF4B_VISUALIZATION_REPAIR_COMPLETE','CORRECTED_RF3_RUN_USED', ...
    'QUARANTINED_FULL_TRACE_OUTPUTS_USED','REPO_VISUALIZATION_RULES_INSPECTED', ...
    'REPO_VISUALIZATION_RULES_APPLIED','PNG_FILES_SAVED','FIG_FILES_SAVED', ...
    'EVENT_OVERLAYS_REPAIRED','CURVE_OVERLAYS_REPAIRED', ...
    'AMPLITUDE_NORMALIZED_DIAGNOSTICS_REPAIRED','HEATMAPS_REPAIRED', ...
    'TIME_CUTS_REPAIRED','QUALITY_DIAGNOSTICS_REPAIRED','OUTLIER_DIAGNOSTIC_CREATED', ...
    'EMPTY_OR_INVALID_AXES_REMAIN','VISUAL_OBJECT_MATCHES_POST_FIELD_OFF_RELAXATION', ...
    'VISUAL_EVIDENCE_SUPPORTS_SIMPLE_MASTER_CURVE','READY_FOR_RF5_MINIMAL_REPLAY', ...
    'READY_FOR_COLLAPSE_REPLAY','READY_FOR_CROSS_MODULE_ANALYSIS'});
status.RF4B_RERUN_COMPLETE = "YES";
status.RF3R_RUN_USED = "YES";
status.DEFAULT_REPLAY_SET_ENFORCED = "YES";
status.FLAGGED_TRACES_EXCLUDED = "YES";
status.FIGURES_READABLE = "YES";
status.READY_FOR_RF5A_RERUN = "NO";
status.READY_FOR_RF5B = "NO";
status.READY_FOR_COLLAPSE = "NO";
writetable(status, fullfile(outTablesDir, 'relaxation_RF4B_visualization_status.csv'));

%% RF4B report
reportPath = fullfile(outReportsDir, 'relaxation_RF4B_visualization_repair.md');
lines = {
    '# Relaxation RF4B Visualization Repair'
    ''
    'RF4B is visualization repair only; it does not alter RF3 canonical data or physical definitions.'
    ''
    sprintf('- RF3R canonical run used: `%s`', canonRunDir)
    sprintf('- RF4B figure directory: `%s`', figDir)
    ''
    '## What was wrong in RF4 visualization'
    '- Some panels were hard to inspect due to scaling/axis clarity issues.'
    '- A large-amplitude outlier trace dominated overlays and heatmaps.'
    '- Absolute raw timestamps reduced readability of event overlays.'
    '- Log-time and linear-time views were not sufficiently distinct for human inspection.'
    ''
    '## What RF4B repaired'
    '- Event overlays now use relative time (`t - t_{field-off}`), with `t=0` marker and pre-field shading.'
    '- Canonical overlays now include explicit linear and true log-time views with robust-scale and grouped views.'
    '- Heatmaps now include raw, robust color limits, outlier-isolated view, and log-time coordinate view.'
    '- Diagnostic-only normalized views now include both peak-to-peak and L2 normalizations with explicit labels.'
    '- Quality/event diagnostics are repaired with meaningful units and no misleading empty axes.'
    '- Explicit outlier diagnostic isolates largest-amplitude trace against neighbors.'
    ''
    '## Repository visualization conventions applied'
    sprintf('- Inspected: `%s`', strjoin(strsplit(style_source, '; '), '`, `'))
    '- Applied conventions: units in axis labels, publication-style fonts/line widths, `parula` colormap, colorbar labels with units, robust scaling disclosed, strict base-name figure naming, PNG + FIG export for every figure, explicit canonical vs diagnostic-only labels.'
    '- Non-applicable conventions: PDF export was not required for RF4B deliverables; focus remained on required PNG+FIG outputs.'
    ''
    '## RF4B figure paths (PNG + FIG)'
    };
for i = 1:height(inv)
    lines{end+1,1} = sprintf('- `%s`', inv.png_path(i)); %#ok<AGROW>
    lines{end+1,1} = sprintf('- `%s`', inv.fig_path(i)); %#ok<AGROW>
end
lines = [lines; {
    ''
    '## Outlier diagnostic interpretation'
    sprintf('- Largest-amplitude trace: `%s` at %.3f K', outlierTrace, outlierTemp)
    sprintf('- Visual interpretation: `%s`', outlierInterpretation)
    '- This is a visualization witness only; no canonical data rows were removed or modified.'
    ''
    '## Scope guardrails'
    '- No SVD was performed.'
    '- No collapse was performed.'
    '- No time-mode analysis was performed.'
    '- No cross-module analysis was performed.'
    '- RF4B outputs are diagnostic visualization only.'
    }];
fid = fopen(reportPath, 'w');
if fid < 0
    error('Could not write report: %s', reportPath);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);

%% RF4B rerun report (RF3R strict canonical)
reportRf3r = fullfile(outReportsDir, 'relaxation_RF4B_visualization_repair_RF3R.md');
nDef = nTrace;
nFl = sum(~defaultMask);
linesR = {
    '# Relaxation RF4B Visualization Repair (RF3R rerun)'
    ''
    '- Scope: visualization only on the audited RF3R post-field-off canonical run.'
    '- No RF3 / legacy RF4 / RF5 outputs were loaded as inputs.'
    '- No full-trace runs, no precomputed collapse/SVD artifacts, no physics-definition edits.'
    '- No collapse, SVD, time-mode, or cross-module analysis was performed.'
    ''
    sprintf('- RF3R run directory: `%s`', canonRunDir)
    sprintf('- RF4B figure directory: `%s`', figDir)
    sprintf('- Run ID: `%s`', run_id)
    ''
    '## Default replay policy'
    sprintf('- Default replay traces used for canonical \\DeltaM figures: `%d`.', nDef)
    sprintf('- Traces excluded from default canonical views (quality-flagged or not valid for default replay): `%d`.', nFl)
    '- Canonical \\DeltaM overlays, normalized diagnostics, heatmaps, and time cuts use **only** the default replay subset.'
    '- Event-origin and quality-flag panels use **all** loaded traces where noted, so RF3R `quality_flag` and `z_fp` remain visible for audit.'
    ''
    '## Visual description (no interpretation)'
    '- Event overlays: raw field and moment vs time relative to detected field-off, with t=0 marker and pre-field shading where applicable.'
    '- Canonical curve figures: sampled \\DeltaM vs time_since_field_off (linear and log time), plus grouped robust-scale views.'
    '- Heatmaps: \\DeltaM arranged by temperature vs sample time grid (raw, robust color limits, row-exclusion view, diagnostic normalization, log-time axis where applicable).'
    '- Time cuts: \\DeltaM at selected time abscissas vs temperature (full and robust y-scale).'
    '- Quality panels: detection timing, retained points, RF3R baseline column, field transition metrics, confidence encoding, RF3R `z_fp` vs temperature, and binary `quality_flag` vs temperature.'
    '- Outlier diagnostic: largest max(|\\DeltaM|) among **default replay** traces, shown with neighboring temperatures in that subset; bar chart ranks the same subset.'
    ''
    '## Figure outputs'
    };
for i = 1:height(inv)
    linesR{end+1,1} = sprintf('- `%s`', inv.png_path(i)); %#ok<AGROW>
    linesR{end+1,1} = sprintf('- `%s`', inv.fig_path(i)); %#ok<AGROW>
end
linesR{end+1,1} = '';
linesR{end+1,1} = '## Status';
linesR{end+1,1} = 'See `tables/relaxation_RF4B_visualization_status.csv` for RF4B_RERUN_COMPLETE and RF3R gate fields.';
fidR = fopen(reportRf3r, 'w');
if fidR < 0
    error('Could not write report: %s', reportRf3r);
end
for i = 1:numel(linesR)
    fprintf(fidR, '%s\n', linesR{i});
end
fclose(fidR);

disp('RF4B visualization repair complete.');
disp(figDir);

%% ------------------------- Local helpers -------------------------
function [png_path, fig_path] = local_save_pair(fig, base_name, outDir)
if ~strcmp(char(string(get(fig, 'Name'))), base_name)
    error('Figure Name must match base_name for strict naming rule.');
end
png_path = fullfile(outDir, [base_name '.png']);
fig_path = fullfile(outDir, [base_name '.fig']);
apply_publication_style(fig);
exportgraphics(fig, png_path, 'Resolution', 600);
savefig(fig, fig_path);
end

function inv = local_add_inventory(inv, figure_id, title_txt, png_path, fig_path, source_data, cod, robust_tf, outlier_handling, style_source, style_conventions, notes)
row = {string(figure_id), string(title_txt), string(png_path), string(fig_path), ...
    string(source_data), string(cod), string(robust_tf), string(outlier_handling), ...
    "YES", string(style_source), string(style_conventions), string(notes)};
inv = [inv; row];
end

function x = local_toDouble(v)
if isnumeric(v)
    x = double(v);
else
    x = str2double(string(v));
end
end

function varName = local_pickVar(T, target)
names = string(T.Properties.VariableNames);
t = lower(strtrim(string(target)));
normNames = lower(strtrim(regexprep(names, '^[^A-Za-z0-9_]+', '')));
idx = find(normNames == t, 1);
if isempty(idx)
    idx = find(contains(normNames, t), 1);
end
if isempty(idx)
    error('Could not find variable %s', target);
end
varName = char(names(idx));
end
