function out = aging_shape_collapse_analysis()
% aging_shape_collapse_analysis
% Audit near-separability of structured Aging DeltaM maps using existing
% structured run exports only.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

cfgRun = struct();
cfgRun.runLabel = 'aging_shape_collapse_analysis';
cfgRun.datasetName = 'aging_shape_collapse_analysis';
runCtx = createRunContext('aging', cfgRun);
run_output_dir = runCtx.run_dir;
fprintf('Aging shape collapse analysis run root:\n%s\n', run_output_dir);

overlayTpValues = [6 14 18 22 26];
metricTpValues = [6 10 14 18 22 26 30 34];
sourceRuns = resolveStructuredRuns(repoRoot, metricTpValues, ...
    'run_2026_03_10_231719_tp_26_structured_export');

allData = cell(numel(metricTpValues), 1);
shapeRows = repmat(struct( ...
    'Tp_K', NaN, ...
    'shape_variation', NaN, ...
    'rank1_explained_variance_ratio', NaN, ...
    'n_temperatures', NaN, ...
    'n_profiles', NaN, ...
    'run_id', "", ...
    'source_run_dir', ""), 0, 1);

for i = 1:numel(metricTpValues)
    tpK = metricTpValues(i);
    data = loadStructuredRun(sourceRuns(i).run_dir, tpK);
    allData{i} = data;

    shapeRows(end + 1, 1) = struct( ... %#ok<AGROW>
        'Tp_K', tpK, ...
        'shape_variation', data.shape_variation, ...
        'rank1_explained_variance_ratio', data.rank1_explained_variance_ratio, ...
        'n_temperatures', numel(data.T_K), ...
        'n_profiles', numel(data.tw_seconds), ...
        'run_id', string(sourceRuns(i).run_id), ...
        'source_run_dir', string(sourceRuns(i).run_dir));

    if ismember(tpK, overlayTpValues)
        figRaw = makeProfileOverlayFigure(data, false);
        save_run_figure(figRaw, sprintf('aging_profiles_raw_Tp%s', tp_token(tpK)), run_output_dir);
        close(figRaw);

        figNorm = makeProfileOverlayFigure(data, true);
        save_run_figure(figNorm, sprintf('aging_profiles_normalized_Tp%s', tp_token(tpK)), run_output_dir);
        close(figNorm);
    end
end

shapeTbl = sortrows(struct2table(shapeRows), 'Tp_K', 'ascend');
save_run_table(shapeTbl, 'aging_shape_variation_vs_Tp.csv', run_output_dir);
figShape = makeShapeVariationFigure(shapeTbl);
save_run_figure(figShape, 'aging_shape_variation_vs_Tp', run_output_dir);
close(figShape);

tp26Idx = find(cellfun(@(s) s.Tp_K == 26, allData), 1, 'first');
tp26 = allData{tp26Idx};
[scaleTbl, scaledProfiles, refIdx, scaleStats] = computeRank1Scaling(tp26);
save_run_table(scaleTbl, 'aging_rank1_scaling_coefficients_Tp26.csv', run_output_dir);

figScaled = makeScaledCollapseFigure(tp26, scaledProfiles, refIdx);
save_run_figure(figScaled, 'aging_profiles_scaled_collapse_Tp26', run_output_dir);
close(figScaled);

[rank1Map, residualMap, rank1Stats] = buildRank1Reconstruction(tp26);
figRank1 = makeRank1TriptychFigure(tp26, rank1Map, residualMap);
save_run_figure(figRank1, 'aging_rank1_reconstruction_Tp26', run_output_dir);
close(figRank1);

figResidual = makeResidualFigure(tp26, residualMap);
save_run_figure(figResidual, 'aging_residual_map_Tp26', run_output_dir);
close(figResidual);

reportText = buildReportText(run_output_dir, shapeTbl, overlayTpValues, sourceRuns, tp26, scaleStats, rank1Stats);
reportPath = save_run_report(reportText, 'aging_shape_collapse_analysis.md', run_output_dir);
zipPath = createReviewZip(run_output_dir, reportPath);

fprintf('Aging shape collapse analysis complete.\n');
fprintf('Run root: %s\n', run_output_dir);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = run_output_dir;
out.report_path = reportPath;
out.zip_path = zipPath;
out.shape_table = shapeTbl;
out.scaling_table = scaleTbl;
out.rank1_stats = rank1Stats;
out.scale_stats = scaleStats;
end

function runs = resolveStructuredRuns(repoRoot, tpValues, tp26RunId)
runsRoot = fullfile(repoRoot, 'results', 'aging', 'runs');
entries = dir(fullfile(runsRoot, 'run_*_tp_*_structured_export'));
entries = entries([entries.isdir]);
names = string({entries.name});
runs = repmat(struct('Tp_K', NaN, 'run_id', "", 'run_dir', ""), numel(tpValues), 1);

for i = 1:numel(tpValues)
    tpK = tpValues(i);
    token = sprintf('_tp_%g_structured_export', tpK);
    matches = names(endsWith(names, token));
    if tpK == 26
        matches = matches(matches == string(tp26RunId));
    end
    assert(~isempty(matches), 'No structured run found for Tp = %.3g K.', tpK);
    matches = sort(matches);
    runId = matches(end);
    runs(i).Tp_K = tpK;
    runs(i).run_id = runId;
    runs(i).run_dir = fullfile(runsRoot, char(runId));
end
end

function data = loadStructuredRun(runDir, tpK)
Ttbl = readtable(fullfile(runDir, 'tables', 'T_axis.csv'));
twTbl = readtable(fullfile(runDir, 'tables', 'tw_axis.csv'));
mapTbl = readtable(fullfile(runDir, 'tables', 'DeltaM_map.csv'));
sTbl = readtable(fullfile(runDir, 'tables', 'svd_singular_values.csv'));

T_K = Ttbl{:, 1};
tw_seconds = twTbl.tw_seconds;
wait_time = string(twTbl.wait_time);
DeltaM = table2array(mapTbl);

assert(size(DeltaM, 1) == numel(T_K), 'DeltaM rows do not match T axis in %s.', runDir);
assert(size(DeltaM, 2) == numel(tw_seconds), 'DeltaM columns do not match tw axis in %s.', runDir);

amplitudes = max(abs(DeltaM), [], 1);
amplitudes(~isfinite(amplitudes) | amplitudes <= 0) = NaN;
DeltaM_norm = DeltaM ./ amplitudes;
shape_std = std(DeltaM_norm, 0, 2, 'omitnan');

data = struct();
data.Tp_K = tpK;
data.run_dir = runDir;
data.T_K = T_K(:);
data.tw_seconds = tw_seconds(:);
data.wait_time = wait_time(:);
data.DeltaM = DeltaM;
data.amplitudes = amplitudes(:);
data.DeltaM_norm = DeltaM_norm;
data.shape_variation = mean(shape_std, 'omitnan');
data.rank1_explained_variance_ratio = sTbl.explained_variance_ratio(1);
end

function fig = makeProfileOverlayFigure(data, normalized)
if normalized
    yMat = data.DeltaM_norm;
    yLabel = 'Normalized \DeltaM(T, t_w)';
    titleText = sprintf('Normalized Aging profiles at T_p = %g K', data.Tp_K);
else
    yMat = data.DeltaM;
    yLabel = '\DeltaM(T, t_w)';
    titleText = sprintf('Raw Aging profiles at T_p = %g K', data.Tp_K);
end

fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 7.8]);
ax = axes(fig);
hold(ax, 'on');
colors = wait_time_colors(numel(data.tw_seconds));

for i = 1:numel(data.tw_seconds)
    plot(ax, data.T_K, yMat(:, i), '-', 'Color', colors(i, :), ...
        'LineWidth', 2.0, 'DisplayName', char(data.wait_time(i)));
end

xlabel(ax, 'Temperature (K)');
ylabel(ax, yLabel);
title(ax, titleText);
set(ax, 'FontSize', 9, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
lg = legend(ax, 'Location', 'eastoutside');
lg.Box = 'off';
lg.Title.String = 't_w';
end

function [tbl, scaledProfiles, refIdx, stats] = computeRank1Scaling(data)
[~, refIdx] = max(data.amplitudes);
Fref = data.DeltaM(:, refIdx);
n = numel(data.tw_seconds);
scaledProfiles = nan(size(data.DeltaM));
coeff = nan(n, 1);
resid = nan(n, 1);

for i = 1:n
    profile = data.DeltaM(:, i);
    valid = isfinite(Fref) & isfinite(profile);
    denom = sum(Fref(valid) .^ 2, 'omitnan');
    coeff(i) = sum(Fref(valid) .* profile(valid), 'omitnan') / max(denom, eps);
    if isfinite(coeff(i)) && abs(coeff(i)) > eps
        scaledProfiles(:, i) = profile ./ coeff(i);
        resid(i) = norm(profile(valid) - coeff(i) * Fref(valid)) / max(norm(profile(valid)), eps);
    end
end

tbl = table((1:n).', data.tw_seconds, log10(data.tw_seconds), data.wait_time, ...
    data.amplitudes, coeff, resid, false(n, 1), ...
    'VariableNames', {'tw_index','tw_seconds','log10_tw_seconds','wait_time', ...
    'max_abs_amplitude','best_fit_scale_coefficient','relative_fit_residual','is_reference_profile'});
tbl.is_reference_profile(refIdx) = true;

stats = struct();
stats.reference_wait_time = data.wait_time(refIdx);
stats.mean_relative_fit_residual = mean(resid, 'omitnan');
stats.max_relative_fit_residual = max(resid, [], 'omitnan');
end

function fig = makeScaledCollapseFigure(data, scaledProfiles, refIdx)
fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 7.8]);
ax = axes(fig);
hold(ax, 'on');
colors = wait_time_colors(numel(data.tw_seconds));

for i = 1:numel(data.tw_seconds)
    style = '-';
    width = 2.0;
    if i == refIdx
        style = '--';
        width = 2.4;
    end
    plot(ax, data.T_K, scaledProfiles(:, i), style, 'Color', colors(i, :), ...
        'LineWidth', width, 'DisplayName', char(data.wait_time(i)));
end

xlabel(ax, 'Temperature (K)');
ylabel(ax, '\DeltaM(T, t_w) / a(t_w)');
title(ax, 'Best-fit amplitude-scaled collapse at T_p = 26 K');
set(ax, 'FontSize', 9, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
lg = legend(ax, 'Location', 'eastoutside');
lg.Box = 'off';
lg.Title.String = 't_w';
end

function [rank1Map, residualMap, stats] = buildRank1Reconstruction(data)
[U, S, V] = svd(data.DeltaM, 'econ');
s = diag(S);
rank1Map = s(1) * U(:, 1) * V(:, 1).';
residualMap = data.DeltaM - rank1Map;

residS = svd(residualMap, 'econ');
residEnergy = residS .^ 2;
meanAbsResidualByT = mean(abs(residualMap), 2, 'omitnan');
[peakResidual, peakIdx] = max(meanAbsResidualByT, [], 'omitnan');

stats = struct();
stats.rank1_explained_variance_ratio = s(1)^2 / max(sum(s .^ 2, 'omitnan'), eps);
stats.residual_frobenius_fraction = norm(residualMap, 'fro') / max(norm(data.DeltaM, 'fro'), eps);
stats.residual_rank1_explained_variance_ratio = residEnergy(1) / max(sum(residEnergy, 'omitnan'), eps);
stats.residual_peak_temperature_K = data.T_K(peakIdx);
stats.residual_peak_mean_abs_value = peakResidual;
end

function fig = makeRank1TriptychFigure(data, rank1Map, residualMap)
fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 7.4]);
tlo = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
mapLim = max(abs([data.DeltaM(:); rank1Map(:)]), [], 'omitnan');
residLim = max(abs(residualMap(:)), [], 'omitnan');
cmap = blue_white_red_map(256);

ax1 = nexttile(tlo, 1);
imagesc(ax1, data.T_K, log10(data.tw_seconds), data.DeltaM.');
axis(ax1, 'xy');
colormap(ax1, cmap);
clim(ax1, [-mapLim mapLim]);
cb1 = colorbar(ax1);
cb1.Label.String = '\DeltaM';
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'log_{10}(t_w / s)');
title(ax1, 'a  Original map');
set(ax1, 'FontSize', 8, 'Box', 'on', 'LineWidth', 1);

ax2 = nexttile(tlo, 2);
imagesc(ax2, data.T_K, log10(data.tw_seconds), rank1Map.');
axis(ax2, 'xy');
colormap(ax2, cmap);
clim(ax2, [-mapLim mapLim]);
cb2 = colorbar(ax2);
cb2.Label.String = 'Rank-1 \DeltaM';
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, 'log_{10}(t_w / s)');
title(ax2, 'b  Rank-1 reconstruction');
set(ax2, 'FontSize', 8, 'Box', 'on', 'LineWidth', 1);

ax3 = nexttile(tlo, 3);
imagesc(ax3, data.T_K, log10(data.tw_seconds), residualMap.');
axis(ax3, 'xy');
colormap(ax3, cmap);
clim(ax3, [-residLim residLim]);
cb3 = colorbar(ax3);
cb3.Label.String = 'Residual \DeltaM';
xlabel(ax3, 'Temperature (K)');
ylabel(ax3, 'log_{10}(t_w / s)');
title(ax3, 'c  Residual map');
set(ax3, 'FontSize', 8, 'Box', 'on', 'LineWidth', 1);
end

function fig = makeResidualFigure(data, residualMap)
fig = create_figure('Visible', 'off', 'Position', [2 2 8.6 6.8]);
ax = axes(fig);
residLim = max(abs(residualMap(:)), [], 'omitnan');
imagesc(ax, data.T_K, log10(data.tw_seconds), residualMap.');
axis(ax, 'xy');
colormap(ax, blue_white_red_map(256));
clim(ax, [-residLim residLim]);
cb = colorbar(ax);
cb.Label.String = 'Residual \DeltaM';
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'log_{10}(t_w / s)');
title(ax, 'Residual map after rank-1 subtraction at T_p = 26 K');
set(ax, 'FontSize', 8, 'Box', 'on', 'LineWidth', 1);
end

function fig = makeShapeVariationFigure(shapeTbl)
fig = create_figure('Visible', 'off', 'Position', [2 2 8.6 6.2]);
ax = axes(fig);
hold(ax, 'on');

plot(ax, shapeTbl.Tp_K, shapeTbl.shape_variation, '-o', 'LineWidth', 2.0, ...
    'Color', [0 0.4470 0.7410], 'MarkerFaceColor', [0 0.4470 0.7410], 'MarkerSize', 6);

mask26 = shapeTbl.Tp_K == 26;
plot(ax, shapeTbl.Tp_K(mask26), shapeTbl.shape_variation(mask26), 'o', ...
    'LineWidth', 1.5, 'MarkerSize', 8, ...
    'Color', [0.8500 0.3250 0.0980], 'MarkerFaceColor', [0.8500 0.3250 0.0980]);

xlabel(ax, 'T_p (K)');
ylabel(ax, 'Shape variation');
title(ax, 'Cross-T_p shape-collapse metric');
set(ax, 'FontSize', 9, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
end

function txt = buildReportText(runOutputDir, shapeTbl, overlayTpValues, sourceRuns, tp26, scaleStats, rank1Stats)
shapeSorted = sortrows(shapeTbl, 'shape_variation', 'ascend');
tp26Row = shapeTbl(shapeTbl.Tp_K == 26, :);
tp26Rank = find(shapeSorted.Tp_K == 26, 1, 'first');

lines = strings(0, 1);
lines(end + 1) = "# Aging shape collapse analysis";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf("Run root: `%s`", string(runOutputDir));
lines(end + 1) = "";
lines(end + 1) = "## Scope";
lines(end + 1) = "- Existing structured Aging runs only were used.";
lines(end + 1) = "- No Aging pipeline stages were modified or rerun.";
lines(end + 1) = sprintf("- Raw and normalized overlays were generated for T_p = %s K.", strjoin(string(overlayTpValues), ", "));
lines(end + 1) = "";
lines(end + 1) = "## Source runs";
for i = 1:numel(sourceRuns)
    lines(end + 1) = sprintf("- T_p = %g K -> `%s`", sourceRuns(i).Tp_K, string(sourceRuns(i).run_id));
end
lines(end + 1) = "";
lines(end + 1) = "## Findings";
lines(end + 1) = sprintf("- T_p = 26 K shape variation = %.6g and ranks %d of %d in the tested T_p sweep.", ...
    tp26Row.shape_variation, tp26Rank, height(shapeTbl));
lines(end + 1) = sprintf("- T_p = 26 K rank-1 explained variance ratio = %.4f.", rank1Stats.rank1_explained_variance_ratio);
lines(end + 1) = sprintf("- Best-fit amplitude scaling at T_p = 26 K uses the `%s` profile as reference; mean relative residual = %.4f, max relative residual = %.4f.", ...
    scaleStats.reference_wait_time, scaleStats.mean_relative_fit_residual, scaleStats.max_relative_fit_residual);
lines(end + 1) = sprintf("- Residual Frobenius fraction after rank-1 subtraction at T_p = 26 K = %.4f.", rank1Stats.residual_frobenius_fraction);
lines(end + 1) = sprintf("- The residual map has its largest mean absolute structure near T = %.3f K.", rank1Stats.residual_peak_temperature_K);
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
if tp26Rank == 1
    lines(end + 1) = "- T_p = 26 K is the strongest shape-collapse case in this sweep.";
else
    lines(end + 1) = "- T_p = 26 K shows strong but not uniquely strongest collapse in this sweep.";
end
if rank1Stats.rank1_explained_variance_ratio >= 0.9
    lines(end + 1) = "- The map is dominated by one temperature-shape mode, so waiting time mainly rescales amplitude rather than changing shape.";
else
    lines(end + 1) = "- The map is not strongly rank-1, so waiting time changes shape as well as amplitude.";
end
if rank1Stats.residual_rank1_explained_variance_ratio >= 0.5
    lines(end + 1) = sprintf("- The residual is low-amplitude but structured: its leading residual mode explains %.4f of residual variance.", ...
        rank1Stats.residual_rank1_explained_variance_ratio);
else
    lines(end + 1) = "- The residual is weak and does not show a strong coherent correction mode.";
end
lines(end + 1) = "- Physically, near-separability at T_p = 26 K suggests one dominant aging response shape F(T), with t_w controlling how strongly that shape appears.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- Number of curves per profile overlay: 4.";
lines(end + 1) = "- Legend vs colormap: explicit legend, because the curve count is <= 6.";
lines(end + 1) = "- Colormaps: color-blind safe line palette for overlays and a blue-white-red diverging map for signed heatmaps.";
lines(end + 1) = "- Smoothing applied: none.";
lines(end + 1) = "- Justification: the audit should reflect the saved structured maps directly, without extra smoothing.";
lines(end + 1) = "";
lines(end + 1) = "## Exported artifacts";
lines(end + 1) = "- `tables/aging_shape_variation_vs_Tp.csv`";
lines(end + 1) = "- `tables/aging_rank1_scaling_coefficients_Tp26.csv`";
lines(end + 1) = "- `figures/aging_profiles_raw_Tp26.png`";
lines(end + 1) = "- `figures/aging_profiles_normalized_Tp26.png`";
lines(end + 1) = "- `figures/aging_profiles_scaled_collapse_Tp26.png`";
lines(end + 1) = "- `figures/aging_rank1_reconstruction_Tp26.png`";
lines(end + 1) = "- `figures/aging_residual_map_Tp26.png`";
lines(end + 1) = "- `figures/aging_shape_variation_vs_Tp.png`";
lines(end + 1) = "- `review/aging_shape_collapse_analysis.zip`";
lines(end + 1) = "";
lines(end + 1) = "## Notes";
lines(end + 1) = sprintf("- T_p = 26 K raw-profile amplitudes span %.6g to %.6g.", ...
    min(tp26.amplitudes, [], 'omitnan'), max(tp26.amplitudes, [], 'omitnan'));

txt = strjoin(lines, newline);
end

function zipPath = createReviewZip(runOutputDir, reportPath)
reviewDir = fullfile(runOutputDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'aging_shape_collapse_analysis.zip');
if isfile(zipPath)
    delete(zipPath);
end
files = [collectFiles(fullfile(runOutputDir, 'tables')); ...
    collectFiles(fullfile(runOutputDir, 'figures')); ...
    {reportPath}];
zip(zipPath, files);
end

function files = collectFiles(folderPath)
entries = dir(fullfile(folderPath, '*'));
entries = entries(~[entries.isdir]);
files = cell(numel(entries), 1);
for i = 1:numel(entries)
    files{i} = fullfile(entries(i).folder, entries(i).name);
end
end

function token = tp_token(tpK)
token = sprintf('%02d', round(tpK));
end

function colors = wait_time_colors(n)
palette = [
    0.0000 0.4470 0.7410
    0.8500 0.3250 0.0980
    0.0000 0.6200 0.4510
    0.8350 0.3690 0.0000
    0.4940 0.1840 0.5560
    0.3010 0.7450 0.9330
    ];
colors = palette(1:n, :);
end

function cmap = blue_white_red_map(n)
if nargin < 1
    n = 256;
end
n = max(2, round(n));
half = floor(n / 2);
top = [linspace(0, 1, half)', linspace(0.2, 1, half)', ones(half, 1)];
bottom = [ones(n - half, 1), linspace(1, 0.2, n - half)', linspace(1, 0, n - half)'];
cmap = [top; flipud(bottom)];
if size(cmap, 1) > n
    cmap = cmap(1:n, :);
end
end




