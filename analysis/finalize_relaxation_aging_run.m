function finalize_relaxation_aging_run(runDir)
if nargin < 1 || strlength(string(runDir)) == 0
    runDir = "C:\Dev\matlab-functions\results\cross_experiment\runs\run_2026_03_11_223145_relaxation_aging_canonical_comparison";
end
runDir = char(string(runDir));
repoRoot = fileparts(fileparts(runDir));
repoRoot = fileparts(fileparts(repoRoot));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

metrics = readtable(fullfile(runDir, 'tables', 'normalized_overlay_metrics.csv'), 'VariableNamingRule', 'preserve');
windows = readtable(fullfile(runDir, 'tables', 'peak_window_summary.csv'), 'VariableNamingRule', 'preserve');
manifest = readtable(fullfile(runDir, 'tables', 'source_run_manifest.csv'), 'VariableNamingRule', 'preserve');
alignment = readtable(fullfile(runDir, 'tables', 'relaxation_aging_observable_alignment.csv'), 'VariableNamingRule', 'preserve');

savePeakFigure(metrics, runDir);
saveWindowFigure(windows, alignment, runDir);
reportText = buildReport(runDir, metrics, windows, manifest);
writeText(fullfile(runDir, 'reports', 'relaxation_aging_canonical_comparison.md'), reportText);
buildZip(runDir);
end

function savePeakFigure(metrics, runDir)
fig = create_figure('Position', [2 2 17.8 7.4]);
ax = axes(fig);
displayNames = ["Relaxation A(T)"; string(metrics.('display_name'))];
peakT = [metrics.relax_peak_T_K(1); metrics.observable_peak_T_K];
yPos = 1:numel(displayNames);
hold(ax, 'on');
xline(ax, metrics.relax_peak_T_K(1), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2);
plot(ax, peakT, yPos, 'o', 'Color', hex2rgb('#0072B2'), 'MarkerFaceColor', hex2rgb('#0072B2'), 'MarkerSize', 6, 'LineStyle', 'none');
for i = 2:numel(displayNames)
    text(ax, peakT(i) + 0.3, yPos(i), sprintf('dT = %.1f K', metrics.peak_delta_K(i - 1)), 'FontSize', 8, 'VerticalAlignment', 'middle');
end
hold(ax, 'off');
set(ax, 'YTick', yPos, 'YTickLabel', displayNames, 'YDir', 'reverse');
xlabel(ax, 'Peak temperature (K)');
ylabel(ax, 'Observable');
title(ax, 'Peak-temperature alignment summary');
styleAxes(ax, [min(metrics.relax_support25_low_K) - 1, max(metrics.observable_support25_high_K) + 1]);
save_run_figure(fig, 'peak_alignment_summary', runDir);
close(fig);
end

function saveWindowFigure(windows, alignment, runDir)
fig = create_figure('Position', [2 2 17.8 8.8]);
ax = axes(fig);
colors = [hex2rgb('#000000'); hex2rgb('#0072B2'); hex2rgb('#E69F00'); hex2rgb('#009E73'); hex2rgb('#CC79A7')];
yPos = 1:height(windows);
hold(ax, 'on');
for i = 1:height(windows)
    c = colors(min(i, size(colors, 1)), :);
    patchBand(ax, windows.support25_low_K(i), windows.support25_high_K(i), yPos(i), c, 0.18, 0.18);
    patchBand(ax, windows.fwhm_low_K(i), windows.fwhm_high_K(i), yPos(i), c, 0.34, 0.34);
    plot(ax, windows.peak_T_K(i), yPos(i), 'o', 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 6);
end
hold(ax, 'off');
set(ax, 'YTick', yPos, 'YTickLabel', windows.display_name, 'YDir', 'reverse');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Observable window');
title(ax, 'Temperature-window overlap');
styleAxes(ax, [min(alignment.T_K) - 1, max(alignment.T_K) + 4]);
save_run_figure(fig, 'temperature_window_overlap', runDir);
close(fig);
end

function reportText = buildReport(runDir, metrics, windows, manifest)
lines = strings(0, 1);
lines(end + 1) = "# Relaxation-Aging Canonical Comparison";
lines(end + 1) = "";
lines(end + 1) = sprintf('Generated: %s', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf('Run root: `%s`', runDir);
lines(end + 1) = "";
lines(end + 1) = "## Repository-state summary";
lines(end + 1) = '- Relevant saved runs were inspected from `results/relaxation/runs/`, `results/aging/runs/`, and `results/cross_experiment/runs/`.';
lines(end + 1) = '- Saved observables already present before this run included Relaxation `A_T`, `Relax_T_peak`, `Relax_peak_width`, and Aging `Dip_depth`, `FM_abs`, `coeff_mode1`, plus the saved Aging collapse sweep.';
lines(end + 1) = '- Existing cross-analysis context was present as a broader Relaxation-Aging-Switching run and a legacy `results/cross_analysis` tree, but no saved dedicated modern pairwise Relaxation-Aging run existed.';
lines(end + 1) = '- New scripts added or modified for this task: `analysis/relaxation_aging_canonical_comparison.m`, `analysis/finalize_relaxation_aging_run.m`.';
lines(end + 1) = "";
lines(end + 1) = "## Source runs used";
for i = 1:height(manifest)
    lines(end + 1) = sprintf('- `%s` [%s]: %s', manifest.run_id(i), manifest.usage_role(i), manifest.dataset(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Why these observables were selected";
lines(end + 1) = '- `A(T)` is the canonical Relaxation activity envelope from the stability audit.';
lines(end + 1) = '- `Dip_depth(T)` is the primary Aging observable according to the saved audit.';
lines(end + 1) = '- `FM_abs(T)` is a supporting background observable that is present in saved outputs but weaker.';
lines(end + 1) = '- `coeff_mode1(T)` is included as a supporting geometric descriptor only, with sign treated as convention-dependent.';
lines(end + 1) = '- `rank1_explained_variance_ratio(T_p)` is the saved Aging collapse metric used for the comparison.';
lines(end + 1) = "";
lines(end + 1) = "## Findings";
for i = 1:height(metrics)
    lines(end + 1) = sprintf('- `%s`: %s. normalized corr = %.3f, peak shift = %.1f K, FWHM overlap = %.3f, support-window overlap = %.3f.', ...
        metrics.observable(i), metrics.comparison_strength(i), metrics.normalized_pearson(i), metrics.peak_delta_K(i), metrics.fwhm_overlap_fraction(i), metrics.support25_overlap_fraction(i));
    lines(end + 1) = sprintf('  sign / shape: %s | %s', metrics.sign_note(i), metrics.shape_note(i));
    if strlength(string(metrics.notes(i))) > 0
        lines(end + 1) = sprintf('  note: %s', metrics.notes(i));
    end
end
lines(end + 1) = "";
lines(end + 1) = "## Shared crossover window";
dipRow = metrics(metrics.observable == "Dip_depth", :);
if ~isempty(dipRow) && any(dipRow.comparison_strength == ["suggestive", "strong"])
    lines(end + 1) = '- The current evidence supports a **suggestive** shared crossover window centered in the same broad 22-30 K band, but not a clean one-to-one mechanistic lock.';
else
    lines(end + 1) = '- The current evidence does **not** cleanly establish a shared crossover window beyond partial overlap.';
end
lines(end + 1) = "";
lines(end + 1) = "## What remains missing for a stronger mechanism claim";
lines(end + 1) = '- A direct model-based bridge stronger than broad temperature-window alignment.';
lines(end + 1) = '- More complete structured Aging coverage at the fragile high-T points.';
lines(end + 1) = '- A sign-stable or otherwise more directly physical replacement for `coeff_mode1` across runs.';
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = '- number of curves: pair figures use one Relaxation curve and one Aging curve per panel; summary figures use one point/window per observable.';
lines(end + 1) = '- legend vs colormap: explicit legends only; no panel exceeds 5 compared quantities.';
lines(end + 1) = '- colormap used: none for line figures; categorical color-blind-safe palette only.';
lines(end + 1) = '- smoothing applied: none to source observables; interpolation is only used for alignment and window estimation.';
reportText = strjoin(lines, newline);
end

function buildZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'relaxation_aging_canonical_comparison_bundle.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'reports', 'tables', 'figures', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function writeText(path, txt)
folder = fileparts(path);
if exist(folder, 'dir') ~= 7
    mkdir(folder);
end
fid = fopen(path, 'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function patchBand(ax, x1, x2, y, colorValue, halfHeight, alphaValue)
if ~all(isfinite([x1 x2])) || x2 <= x1
    return;
end
patch(ax, [x1 x2 x2 x1], [y - halfHeight y - halfHeight y + halfHeight y + halfHeight], colorValue, 'FaceAlpha', alphaValue, 'EdgeColor', 'none');
end

function styleAxes(ax, xLimits)
set(ax, 'FontName', resolvePlotFont(), 'FontSize', 8, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top', 'XMinorTick', 'off', 'YMinorTick', 'off');
xlim(ax, xLimits);
end

function c = hex2rgb(hex)
hex = char(string(hex));
if startsWith(hex, '#')
    hex = hex(2:end);
end
c = sscanf(hex, '%2x%2x%2x', [1 3]) / 255;
end

function fontName = resolvePlotFont()
fontName = 'Helvetica';
try
    fonts = listfonts;
    if ~any(strcmpi(fonts, fontName)) && any(strcmpi(fonts, 'Arial'))
        fontName = 'Arial';
    end
catch
    fontName = 'Arial';
end
end
