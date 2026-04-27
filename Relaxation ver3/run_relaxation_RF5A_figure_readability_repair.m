%% RUN_RELAXATION_RF5A_FIGURE_READABILITY_REPAIR
% RF5A figure readability repair only.
% Scope guards:
% - Do not modify RF3/RF4B/RF5A data products.
% - Do not change RF5A amplitude calculations, metrics, or verdict logic.
% - Rebuild only the required RF5A figures with repaired readability.
% - Do not run RF5B, collapse, time-mode, or cross-module analysis.

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
origFigDir = fullfile(repoRoot, 'figures', 'relaxation', 'RF5A_amplitude_factorization', run_id);
repairedFigDir = fullfile(repoRoot, 'figures', 'relaxation', 'RF5A_amplitude_factorization_repaired', run_id);
outTablesDir = fullfile(repoRoot, 'tables');
outReportsDir = fullfile(repoRoot, 'reports');
if ~isfolder(repairedFigDir), mkdir(repairedFigDir); end
if ~isfolder(outTablesDir), mkdir(outTablesDir); end
if ~isfolder(outReportsDir), mkdir(outReportsDir); end

%% Required inputs
required = {
    fullfile(outTablesDir, 'relaxation_RF3_gate_audit_status.csv')
    fullfile(outTablesDir, 'relaxation_RF4B_visualization_status.csv')
    fullfile(outTablesDir, 'relaxation_RF5A_amplitude_choice_comparison.csv')
    fullfile(outTablesDir, 'relaxation_RF5A_negative_control_results.csv')
    fullfile(outTablesDir, 'relaxation_RF5A_temperature_residuals.csv')
    fullfile(outTablesDir, 'relaxation_RF5A_verdict_status.csv')
    fullfile(rf3TablesDir, 'relaxation_event_origin_manifest.csv')
    fullfile(rf3TablesDir, 'relaxation_post_field_off_creation_status.csv')
    fullfile(rf3TablesDir, 'relaxation_post_field_off_curve_samples.csv')
    };
for i = 1:numel(required)
    if exist(required{i}, 'file') ~= 2
        error('Missing required input: %s', required{i});
    end
end

requiredOrigFigures = {
    'rf5a_corrected_post_field_off_curves.png'
    'rf5a_amplitude_normalized_overlays_by_choice.png'
    'rf5a_best_amplitude_master_curve_overlay.png'
    'rf5a_residual_heatmap_best_amplitude.png'
    'rf5a_negative_control_comparison_summary.png'
    };
for i = 1:numel(requiredOrigFigures)
    f = fullfile(origFigDir, requiredOrigFigures{i});
    if exist(f, 'file') ~= 2
        error('Missing original RF5A figure required for repair context: %s', f);
    end
end

%% Load RF5A and RF3 context
rf3Gate = readtable(fullfile(outTablesDir, 'relaxation_RF3_gate_audit_status.csv'), ...
    "TextType", "string", "Delimiter", ",");
rf4bGate = readtable(fullfile(outTablesDir, 'relaxation_RF4B_visualization_status.csv'), ...
    "TextType", "string", "Delimiter", ",");
rf5aVerdict = readtable(fullfile(outTablesDir, 'relaxation_RF5A_verdict_status.csv'), ...
    "TextType", "string", "Delimiter", ",");
choiceCmp = readtable(fullfile(outTablesDir, 'relaxation_RF5A_amplitude_choice_comparison.csv'), ...
    "TextType", "string", "Delimiter", ",");
ctrlTbl = readtable(fullfile(outTablesDir, 'relaxation_RF5A_negative_control_results.csv'), ...
    "TextType", "string", "Delimiter", ",");
tempResTbl = readtable(fullfile(outTablesDir, 'relaxation_RF5A_temperature_residuals.csv'), ...
    "TextType", "string", "Delimiter", ",");
manifest = readtable(fullfile(rf3TablesDir, 'relaxation_event_origin_manifest.csv'), ...
    "TextType", "string", "Delimiter", ",");
creation = readtable(fullfile(rf3TablesDir, 'relaxation_post_field_off_creation_status.csv'), ...
    "TextType", "string", "Delimiter", ",");
curveSamples = readtable(fullfile(rf3TablesDir, 'relaxation_post_field_off_curve_samples.csv'), ...
    "TextType", "string", "Delimiter", ",");

%% Scope guards
assert(strcmpi(strtrim(rf3Gate.RF3_RUN_VALID_FOR_RF4(1)), "YES"), 'RF3 gate not passed.');
assert(strcmpi(strtrim(rf4bGate.RF4B_VISUALIZATION_REPAIR_COMPLETE(1)), "YES"), 'RF4B repair not complete.');
assert(strcmpi(strtrim(rf4bGate.READY_FOR_RF5_MINIMAL_REPLAY(1)), "YES"), 'RF4B does not allow RF5.');
assert(strcmpi(strtrim(rf5aVerdict.RF5A_AMPLITUDE_FACTORIZATION_COMPLETE(1)), "YES"), 'RF5A factorization not complete.');
assert(strcmpi(strtrim(rf5aVerdict.CORRECTED_POST_FIELD_OFF_RUN_USED(1)), "YES"), 'Corrected RF3 run was not used in RF5A.');
assert(strcmpi(strtrim(rf5aVerdict.QUARANTINED_FULL_TRACE_OUTPUTS_USED(1)), "NO"), 'Quarantined outputs used in RF5A.');
assert(strcmpi(strtrim(creation.READY_FOR_COLLAPSE_REPLAY(1)), "NO"), 'Collapse replay must remain NO.');
assert(strcmpi(strtrim(creation.READY_FOR_CROSS_MODULE_ANALYSIS(1)), "NO"), 'Cross-module analysis must remain NO.');

%% Style provenance
style_source = strjoin([
    "docs/visualization_rules.md"
    "docs/figure_style_guide.md"
    "docs/figure_export_infrastructure.md"
    "tools/figures/create_figure.m"
    "tools/figures/apply_publication_style.m"
    "tools/save_run_figure.m"
    ], "; ");
style_conventions = strjoin([
    "plain-word labels with Interpreter none"
    "Temperature (K) colorbars with explicit temperature ticks"
    "monotonic parula temperature encoding"
    "horizontal negative-control labeling"
    "full-scale plus robust-scale companion views"
    "outlier retained and explicitly labeled"
    "strict base-name figure naming"
    "PNG and FIG exports for every repaired figure"
    ], "; ");

%% Rebuild the same RF5A plotting state from corrected RF3 inputs
validMask = strcmpi(strtrim(manifest.trace_valid_for_relaxation), "YES");
validManifest = manifest(validMask, :);
temps = local_toDouble(validManifest.temperature);
[temps, ord] = sort(temps, 'ascend');
validManifest = validManifest(ord, :);
traceIds = string(validManifest.trace_id);
nTrace = numel(traceIds);

curveSamples.time_s = local_toDouble(curveSamples.time_since_field_off);
curveSamples.delta_m_num = local_toDouble(curveSamples.delta_m);

tMinEach = nan(nTrace,1);
tMaxEach = nan(nTrace,1);
for i = 1:nTrace
    s = curveSamples(strcmp(curveSamples.trace_id, traceIds(i)), :);
    t = s.time_s;
    t = t(isfinite(t) & t > 0);
    tMinEach(i) = min(t);
    tMaxEach(i) = max(t);
end
tMinCommon = max(tMinEach);
tMaxCommon = min(tMaxEach);
if ~isfinite(tMinCommon) || ~isfinite(tMaxCommon) || tMinCommon <= 0 || tMaxCommon <= tMinCommon
    error('Invalid common time interval for RF5A figure repair.');
end

nGrid = 320;
tGridLinear = linspace(tMinCommon, tMaxCommon, nGrid);
Xlin = nan(nTrace, nGrid);
for i = 1:nTrace
    s = curveSamples(strcmp(curveSamples.trace_id, traceIds(i)), :);
    t = s.time_s;
    x = s.delta_m_num;
    m = isfinite(t) & isfinite(x) & t > 0;
    [tUniq, ia] = unique(t(m), 'stable');
    xUniq = x(m);
    xUniq = xUniq(ia);
    Xlin(i,:) = interp1(tUniq, xUniq, tGridLinear, 'linear', 'extrap');
end

choiceList = ["peak_to_peak","l2_norm","mad_scale","abs_endpoint_diff","projection_onto_corrected_mean_curve"];
nChoice = numel(choiceList);
resChoice = struct([]);
for c = 1:nChoice
    method = choiceList(c);
    A = local_compute_amplitude(Xlin, method);
    A(abs(A) < 1e-15) = 1e-15;
    Xn = Xlin ./ A;
    F = mean(Xn, 1, 'omitnan');
    Xhat = A * F;
    R = Xlin - Xhat;
    resChoice(c).method = method;
    resChoice(c).A = A;
    resChoice(c).Xn = Xn;
    resChoice(c).F = F;
    resChoice(c).Xhat = Xhat;
    resChoice(c).R = R;
end

bestMethod = string(choiceCmp.best_method(1));
bestIdx = find(choiceList == bestMethod, 1);
if isempty(bestIdx)
    error('Best method from RF5A outputs not found in repair replay.');
end
best = resChoice(bestIdx);

% Guard against a plotting/data mismatch.
A_rf5a = local_toDouble(tempResTbl.amplitude_best_method);
temp_rf5a = local_toDouble(tempResTbl.temperature);
[temp_rf5a, tempOrd] = sort(temp_rf5a, 'ascend');
A_rf5a = A_rf5a(tempOrd);
if numel(A_rf5a) ~= numel(best.A) || max(abs(temp_rf5a(:) - temps(:))) > 1e-9
    error('RF5A repair detected a temperature ordering mismatch.');
end
ampMismatch = max(abs(A_rf5a(:) - best.A(:)));
ampTol = 1e-9 * max(1, max(abs(A_rf5a)));
if ampMismatch > ampTol
    error('RF5A repair detected a best-amplitude mismatch (max diff %.3e).', ampMismatch);
end

realImprovement = local_toDouble(choiceCmp.spread_reduction(choiceCmp.amplitude_method == bestMethod));
if isempty(realImprovement)
    error('Could not load real improvement for best method.');
end
realImprovement = realImprovement(1);

Rbest = best.R;
bestTempResid = sqrt(mean(Rbest.^2, 2, 'omitnan'));

curveAmplitude = max(abs(Xlin), [], 2, 'omitnan');
[~, outlierIdx] = max(curveAmplitude);
outlierTemp = temps(outlierIdx);
outlierTrace = traceIds(outlierIdx);
nonOutlierMask = true(nTrace,1);
nonOutlierMask(outlierIdx) = false;
if sum(nonOutlierMask) < 3
    nonOutlierMask(:) = true;
end

[traceColors, temperatureMap] = local_temperature_colors(temps);
tempTicks = local_temperature_ticks(temps, outlierTemp);

%% Figure inventory accumulator
inv = table('Size', [0 12], ...
    'VariableTypes', repmat("string", 1, 12), ...
    'VariableNames', {'figure_id','title','png_path','fig_path','source_data', ...
    'canonical_or_diagnostic','uses_robust_scaling','outlier_handling', ...
    'repo_visualization_rules_checked','style_source','style_conventions_applied','notes'});

%% Figure 1: corrected post-field-off curves repaired
base_name = 'rf5a_corrected_post_field_off_curves_repaired';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 9.8]);
t = tiledlayout(1,2,'Padding','compact','TileSpacing','compact'); %#ok<NASGU>

ax1 = nexttile;
hold(ax1, 'on');
for i = 1:nTrace
    lw = 2.0;
    if i == outlierIdx
        lw = 3.0;
    end
    semilogx(ax1, tGridLinear, Xlin(i,:), '-', 'LineWidth', lw, 'Color', traceColors(i,:));
end
local_style_curve_axes(ax1);
xlabel(ax1, 'Time since field-off (s)', 'Interpreter', 'none');
ylabel(ax1, 'Delta M (emu)', 'Interpreter', 'none');
title(ax1, 'Corrected curves (full scale)', 'Interpreter', 'none');
local_add_temperature_colorbar(ax1, tempTicks, temperatureMap);
local_add_outlier_annotation(ax1, sprintf('13 K outlier retained (%s)', outlierTrace));

ax2 = nexttile;
hold(ax2, 'on');
for i = 1:nTrace
    lw = 2.0;
    if i == outlierIdx
        lw = 3.0;
    end
    semilogx(ax2, tGridLinear, Xlin(i,:), '-', 'LineWidth', lw, 'Color', traceColors(i,:));
end
curveRobustLim = local_robust_limits(Xlin(nonOutlierMask,:), 0.02, 0.98);
ylim(ax2, curveRobustLim);
local_style_curve_axes(ax2);
xlabel(ax2, 'Time since field-off (s)', 'Interpreter', 'none');
ylabel(ax2, 'Delta M (emu)', 'Interpreter', 'none');
title(ax2, 'Corrected curves (robust scale)', 'Interpreter', 'none');
text(ax2, 0.02, 0.93, 'Line colors still encode global temperature.', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8, ...
    'BackgroundColor', 'w', 'Margin', 1);

[png_p, fig_p] = local_save_pair(fig, base_name, repairedFigDir);
inv = local_add_inventory(inv, base_name, 'RF5A corrected curves repaired', png_p, fig_p, ...
    'RF3 curve_samples + existing RF5A outputs', 'CANONICAL_DIAGNOSTIC', 'YES', ...
    sprintf('Outlier %.3f K retained in full-scale and robust-scale views', outlierTemp), ...
    style_source, style_conventions, 'Temperature colorbar uses explicit K ticks; no underscores remain in labels.');
close(fig);

%% Figure 2: amplitude-normalized overlays by choice repaired
base_name = 'rf5a_amplitude_normalized_overlays_by_choice_repaired';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 13.6]);
tiledlayout(3,2,'Padding','compact','TileSpacing','compact');

for c = 1:nChoice
    ax = nexttile;
    hold(ax, 'on');
    Xn = resChoice(c).Xn;
    for i = 1:nTrace
        lw = 1.8;
        if i == outlierIdx
            lw = 2.6;
        end
        semilogx(ax, tGridLinear, Xn(i,:), '-', 'LineWidth', lw, 'Color', traceColors(i,:));
    end
    local_style_curve_axes(ax);
    xlabel(ax, 'Time since field-off (s)', 'Interpreter', 'none');
    ylabel(ax, 'Delta M / A(T)', 'Interpreter', 'none');
    displayName = local_choice_display_name(choiceList(c));
    if local_choice_needs_robust_scale(choiceList(c))
        ylim(ax, local_robust_limits(Xn(nonOutlierMask,:), 0.02, 0.98));
        title(ax, sprintf('%s (robust scale)', displayName), 'Interpreter', 'none');
        text(ax, 0.02, 0.93, '13 K trace retained; clipping improves readability.', ...
            'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8, ...
            'BackgroundColor', 'w', 'Margin', 1);
    else
        title(ax, displayName, 'Interpreter', 'none');
    end
    if c == 2
        local_add_temperature_colorbar(ax, tempTicks, temperatureMap);
    end
end

axInfo = nexttile;
axis(axInfo, 'off');
text(axInfo, 0.04, 0.90, 'Shared temperature encoding', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontWeight', 'bold', 'FontSize', 9);
text(axInfo, 0.04, 0.79, 'All panels use the Temperature (K) colorbar shown next to L2 norm.', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8);
text(axInfo, 0.04, 0.67, sprintf('Best RF5A choice: %s', local_choice_display_name(bestMethod)), ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8);
text(axInfo, 0.04, 0.55, 'Methods marked "robust scale" still include the 13 K trace.', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8);
text(axInfo, 0.04, 0.43, 'Clipping is used only to keep the non-outlier structure readable.', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8);
text(axInfo, 0.04, 0.27, 'No RF5A metrics or verdict logic were changed in this repair.', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8);

[png_p, fig_p] = local_save_pair(fig, base_name, repairedFigDir);
inv = local_add_inventory(inv, base_name, 'RF5A amplitude-normalized overlays by choice repaired', png_p, fig_p, ...
    'RF3 curve_samples + existing RF5A choice table', 'DIAGNOSTIC_ONLY', 'YES', ...
    sprintf('13 K outlier retained across all amplitude choices; robust scaling used where needed'), ...
    style_source, style_conventions, 'Amplitude-choice display names are human-readable and plain-text.');
close(fig);

%% Figure 3: best amplitude master-curve overlay repaired
base_name = 'rf5a_best_amplitude_master_curve_overlay_repaired';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 12.4]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

ax1 = nexttile;
hold(ax1, 'on');
for i = 1:nTrace
    lw = 1.8;
    if i == outlierIdx
        lw = 2.6;
    end
    semilogx(ax1, tGridLinear, best.Xn(i,:), '-', 'LineWidth', lw, 'Color', traceColors(i,:));
end
semilogx(ax1, tGridLinear, best.F, 'k-', 'LineWidth', 3.0);
local_style_curve_axes(ax1);
xlabel(ax1, 'Time since field-off (s)', 'Interpreter', 'none');
ylabel(ax1, 'Delta M / A(T)', 'Interpreter', 'none');
title(ax1, 'Best-choice normalized overlays', 'Interpreter', 'none');
local_add_temperature_colorbar(ax1, tempTicks, temperatureMap);

ax2 = nexttile;
hold(ax2, 'on');
for i = 1:nTrace
    lw = 1.8;
    if i == outlierIdx
        lw = 2.6;
    end
    semilogx(ax2, tGridLinear, best.Xn(i,:), '-', 'LineWidth', lw, 'Color', traceColors(i,:));
end
semilogx(ax2, tGridLinear, best.F, 'k-', 'LineWidth', 3.0);
ylim(ax2, local_robust_limits(best.Xn(nonOutlierMask,:), 0.02, 0.98));
local_style_curve_axes(ax2);
xlabel(ax2, 'Time since field-off (s)', 'Interpreter', 'none');
ylabel(ax2, 'Delta M / A(T)', 'Interpreter', 'none');
title(ax2, 'Best-choice normalized overlays (robust)', 'Interpreter', 'none');

ax3 = nexttile;
hold(ax3, 'on');
dummyData = plot(ax3, nan, nan, '-', 'Color', [0.72 0.72 0.72], 'LineWidth', 1.6, 'DisplayName', 'Data');
dummyFit = plot(ax3, nan, nan, '--', 'Color', [0.15 0.15 0.15], 'LineWidth', 2.2, 'DisplayName', 'A(T)F(t) reconstruction');
for i = 1:nTrace
    lwData = 1.2;
    lwFit = 1.8;
    if i == outlierIdx
        lwData = 1.8;
        lwFit = 2.6;
    end
    semilogx(ax3, tGridLinear, Xlin(i,:), '-', 'LineWidth', lwData, 'Color', [0.72 0.72 0.72], 'HandleVisibility', 'off');
    semilogx(ax3, tGridLinear, best.Xhat(i,:), '--', 'LineWidth', lwFit, 'Color', traceColors(i,:), 'HandleVisibility', 'off');
end
local_style_curve_axes(ax3);
xlabel(ax3, 'Time since field-off (s)', 'Interpreter', 'none');
ylabel(ax3, 'Delta M (emu)', 'Interpreter', 'none');
title(ax3, 'Reconstruction versus data (full scale)', 'Interpreter', 'none');
legend(ax3, [dummyData, dummyFit], 'Location', 'southoutside', 'Box', 'off');
local_add_outlier_annotation(ax3, sprintf('13 K trace retained: %.3f K', outlierTemp));

ax4 = nexttile;
hold(ax4, 'on');
for i = 1:nTrace
    lwData = 1.2;
    lwFit = 1.8;
    if i == outlierIdx
        lwData = 1.8;
        lwFit = 2.6;
    end
    semilogx(ax4, tGridLinear, Xlin(i,:), '-', 'LineWidth', lwData, 'Color', [0.72 0.72 0.72]);
    semilogx(ax4, tGridLinear, best.Xhat(i,:), '--', 'LineWidth', lwFit, 'Color', traceColors(i,:));
end
ylim(ax4, curveRobustLim);
local_style_curve_axes(ax4);
xlabel(ax4, 'Time since field-off (s)', 'Interpreter', 'none');
ylabel(ax4, 'Delta M (emu)', 'Interpreter', 'none');
title(ax4, 'Reconstruction versus data (robust scale)', 'Interpreter', 'none');

[png_p, fig_p] = local_save_pair(fig, base_name, repairedFigDir);
inv = local_add_inventory(inv, base_name, 'RF5A best amplitude master-curve overlay repaired', png_p, fig_p, ...
    'RF3 curve_samples + existing RF5A best-method table', 'DIAGNOSTIC_ONLY', 'YES', ...
    sprintf('13 K outlier retained in normalized and reconstruction views at %.3f K', outlierTemp), ...
    style_source, style_conventions, 'Best-choice title and labels use plain readable names without subscript corruption.');
close(fig);

%% Figure 4: residual heatmap repaired
base_name = 'rf5a_residual_heatmap_best_amplitude_repaired';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 12.0]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

xLog = log10(tGridLinear);
fullResidualClim = max(abs(Rbest(:)));
robResidualClim = quantile(abs(Rbest(:)), 0.98);
if ~isfinite(robResidualClim) || robResidualClim <= 0
    robResidualClim = fullResidualClim;
end

ax1 = nexttile;
imagesc(ax1, xLog, temps, Rbest);
set(ax1, 'YDir', 'normal');
colormap(ax1, local_blue_white_red(256));
caxis(ax1, [-fullResidualClim, fullResidualClim]);
local_style_heatmap_axes(ax1);
xlabel(ax1, 'log10(Time since field-off / s)', 'Interpreter', 'none');
ylabel(ax1, 'Temperature (K)', 'Interpreter', 'none');
title(ax1, 'Residual heatmap (full signed scale)', 'Interpreter', 'none');
cb1 = colorbar(ax1);
cb1.Label.String = 'Residual Delta M (emu)';
cb1.Label.Interpreter = 'none';
cb1.TickLabelInterpreter = 'none';

ax2 = nexttile;
imagesc(ax2, xLog, temps, Rbest);
set(ax2, 'YDir', 'normal');
colormap(ax2, local_blue_white_red(256));
caxis(ax2, [-robResidualClim, robResidualClim]);
local_style_heatmap_axes(ax2);
xlabel(ax2, 'log10(Time since field-off / s)', 'Interpreter', 'none');
ylabel(ax2, 'Temperature (K)', 'Interpreter', 'none');
title(ax2, 'Residual heatmap (robust scale)', 'Interpreter', 'none');
cb2 = colorbar(ax2);
cb2.Label.String = 'Residual Delta M (emu)';
cb2.Label.Interpreter = 'none';
cb2.TickLabelInterpreter = 'none';
text(ax2, 0.02, 0.93, 'Outlier row retained; colors clipped.', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8, ...
    'BackgroundColor', 'w', 'Margin', 1);

ax3 = nexttile;
plot(ax3, temps, bestTempResid, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.0 0.45 0.74]);
hold(ax3, 'on');
plot(ax3, temps(outlierIdx), bestTempResid(outlierIdx), 'ro', 'MarkerSize', 9, 'LineWidth', 2.0);
local_style_curve_axes(ax3);
xlabel(ax3, 'Temperature (K)', 'Interpreter', 'none');
ylabel(ax3, 'Residual RMS (emu)', 'Interpreter', 'none');
title(ax3, 'Residual RMS by temperature (full scale)', 'Interpreter', 'none');
text(ax3, temps(outlierIdx), bestTempResid(outlierIdx), '  13 K', 'Interpreter', 'none', 'FontSize', 8, 'VerticalAlignment', 'bottom');

ax4 = nexttile;
plot(ax4, temps, bestTempResid, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.0 0.45 0.74]);
hold(ax4, 'on');
plot(ax4, temps(outlierIdx), bestTempResid(outlierIdx), 'ro', 'MarkerSize', 9, 'LineWidth', 2.0);
ylim(ax4, local_robust_limits(bestTempResid(nonOutlierMask), 0.02, 0.98));
local_style_curve_axes(ax4);
xlabel(ax4, 'Temperature (K)', 'Interpreter', 'none');
ylabel(ax4, 'Residual RMS (emu)', 'Interpreter', 'none');
title(ax4, 'Residual RMS by temperature (robust scale)', 'Interpreter', 'none');
text(ax4, 0.02, 0.93, '13 K retained; smaller non-outlier structure is visible here.', ...
    'Units', 'normalized', 'Interpreter', 'none', 'FontSize', 8, ...
    'BackgroundColor', 'w', 'Margin', 1);

[png_p, fig_p] = local_save_pair(fig, base_name, repairedFigDir);
inv = local_add_inventory(inv, base_name, 'RF5A residual heatmap repaired', png_p, fig_p, ...
    'RF3 curve_samples + existing RF5A best-method table', 'DIAGNOSTIC_ONLY', 'YES', ...
    sprintf('13 K residual row retained in full-scale and robust-scale residual views'), ...
    style_source, style_conventions, 'Signed residual heatmap uses a zero-centered diverging colormap for readability.');
close(fig);

%% Figure 5: negative-control summary repaired
base_name = 'rf5a_negative_control_comparison_summary_repaired';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Position', [2 2 17.8 12.4]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

ctrlTbl.control_label = strings(height(ctrlTbl), 1);
ctrlLevels = [
    "temperature_label_shuffle"
    "trace_order_permutation"
    "random_amplitude_surrogate"
    "smooth_amplitude_surrogate"
    "mean_curve_plus_amplitude_synthetic"
    ];
for i = 1:numel(ctrlLevels)
    mask = ctrlTbl.control_type == ctrlLevels(i);
    ctrlTbl.control_label(mask) = local_control_display_name(ctrlLevels(i));
end
ctrlLabels = cellstr(local_control_display_name(ctrlLevels));
ctrlMeans = nan(numel(ctrlLevels), 1);
for i = 1:numel(ctrlLevels)
    ctrlMeans(i) = mean(local_toDouble(ctrlTbl.spread_reduction(ctrlTbl.control_type == ctrlLevels(i))), 'omitnan');
end
barLabels = ["Real improvement"; string(ctrlLabels(:))];
barValues = [realImprovement; ctrlMeans];
barColors = repmat([0.2 0.45 0.78], numel(barValues), 1);
barColors(1,:) = [0.85 0.33 0.10];
yPos = 1:numel(barValues);

ax1 = nexttile;
b1 = barh(ax1, yPos, barValues, 'FaceColor', 'flat');
b1.CData = barColors;
set(ax1, 'YTick', yPos, 'YTickLabel', cellstr(barLabels), 'YDir', 'reverse', 'TickLabelInterpreter', 'none');
local_style_curve_axes(ax1);
xlabel(ax1, 'Spread reduction', 'Interpreter', 'none');
ylabel(ax1, 'Summary statistic', 'Interpreter', 'none');
title(ax1, 'Means (full scale)', 'Interpreter', 'none');
xline(ax1, 0, '-', 'LineWidth', 1.0, 'Color', [0.25 0.25 0.25]);

ax2 = nexttile;
b2 = barh(ax2, yPos, barValues, 'FaceColor', 'flat');
b2.CData = barColors;
robCtrlX = local_robust_limits([realImprovement; ctrlMeans(1:4)], 0.00, 1.00);
xlim(ax2, [min(robCtrlX(1), 1.2*min([realImprovement; ctrlMeans(1:4)])), ...
    max(robCtrlX(2), 1.2*max([realImprovement; ctrlMeans(1:4)]))]);
set(ax2, 'YTick', yPos, 'YTickLabel', cellstr(barLabels), 'YDir', 'reverse', 'TickLabelInterpreter', 'none');
local_style_curve_axes(ax2);
xlabel(ax2, 'Spread reduction', 'Interpreter', 'none');
ylabel(ax2, 'Summary statistic', 'Interpreter', 'none');
title(ax2, 'Means (near-zero zoom)', 'Interpreter', 'none');
xline(ax2, 0, '-', 'LineWidth', 1.0, 'Color', [0.25 0.25 0.25]);

ax3 = nexttile;
local_plot_control_distributions(ax3, ctrlTbl, ctrlLevels, realImprovement, false);
title(ax3, 'Control distributions (full scale)', 'Interpreter', 'none');

ax4 = nexttile;
local_plot_control_distributions(ax4, ctrlTbl, ctrlLevels, realImprovement, true);
title(ax4, 'Control distributions (zoom)', 'Interpreter', 'none');

[png_p, fig_p] = local_save_pair(fig, base_name, repairedFigDir);
inv = local_add_inventory(inv, base_name, 'RF5A negative-control summary repaired', png_p, fig_p, ...
    'Existing RF5A negative-control table + choice comparison', 'DIAGNOSTIC_ONLY', 'YES', ...
    'Real improvement and control distributions separated with horizontal readable labels', ...
    style_source, style_conventions, 'Full-scale and near-zero zoom panels preserve the extreme synthetic control without crowding labels.');
close(fig);

%% Save inventory
writetable(inv, fullfile(outTablesDir, 'relaxation_RF5A_repaired_figure_inventory.csv'));

%% Repair status
expectedBaseNames = [
    "rf5a_corrected_post_field_off_curves_repaired"
    "rf5a_amplitude_normalized_overlays_by_choice_repaired"
    "rf5a_best_amplitude_master_curve_overlay_repaired"
    "rf5a_residual_heatmap_best_amplitude_repaired"
    "rf5a_negative_control_comparison_summary_repaired"
    ];

pngSaved = "YES";
figSaved = "YES";
for i = 1:numel(expectedBaseNames)
    if exist(fullfile(repairedFigDir, expectedBaseNames(i) + ".png"), 'file') ~= 2
        pngSaved = "PARTIAL";
    end
    if exist(fullfile(repairedFigDir, expectedBaseNames(i) + ".fig"), 'file') ~= 2
        figSaved = "PARTIAL";
    end
end
if pngSaved == "PARTIAL" && figSaved == "PARTIAL"
    repairComplete = "NO";
elseif pngSaved == "YES" && figSaved == "YES"
    repairComplete = "YES";
else
    repairComplete = "PARTIAL";
end

repairStatus = table( ...
    repairComplete, "NO", "YES", "YES", "YES", "YES", "YES", pngSaved, figSaved, "YES", "NO", "NO", "NO", ...
    'VariableNames', {'RF5A_FIGURE_READABILITY_REPAIR_COMPLETE','RF5A_COMPUTATIONS_CHANGED', ...
    'REPO_VISUALIZATION_RULES_APPLIED','TEXT_RENDERING_FIXED','TEMPERATURE_COLORBAR_FIXED', ...
    'NEGATIVE_CONTROL_SUMMARY_FIXED','OUTLIER_HANDLING_PRESERVED','PNG_FILES_SAVED','FIG_FILES_SAVED', ...
    'READY_FOR_RF5A_VISUAL_REVIEW_RERUN','READY_FOR_RF5B_EFFECTIVE_RANK','READY_FOR_COLLAPSE_REPLAY', ...
    'READY_FOR_CROSS_MODULE_ANALYSIS'});
writetable(repairStatus, fullfile(outTablesDir, 'relaxation_RF5A_figure_readability_repair_status.csv'));

%% Repair report
reportPath = fullfile(outReportsDir, 'relaxation_RF5A_figure_readability_repair.md');
lines = {
    '# Relaxation RF5A Figure Readability Repair'
    ''
    'This step repairs RF5A figure readability only. RF5A computations, metrics, and verdict logic were not changed.'
    ''
    sprintf('- Corrected RF3 run used: `%s`', rf3RunDir)
    sprintf('- Original RF5A figure directory: `%s`', origFigDir)
    sprintf('- Repaired RF5A figure directory: `%s`', repairedFigDir)
    sprintf('- Best RF5A amplitude choice retained: `%s`', local_choice_display_name(bestMethod))
    sprintf('- Explicit outlier retained across repaired figures: %.3f K (`%s`)', outlierTemp, outlierTrace)
    ''
    '## What was repaired'
    '- All required titles, axis labels, annotations, and figure notes now use plain readable text so underscores are not interpreted as subscripts.'
    '- Temperature-encoded multi-curve panels now use explicit `Temperature (K)` colorbars with actual temperature ticks instead of normalized 0..1 semantics.'
    '- Negative-control summary panels now use horizontal readable labels plus full-scale and near-zero zoom views to separate the real result from the control families.'
    '- Full-scale and robust-scale companion panels were added where needed so the 13 K outlier remains visible without flattening the rest of the structure.'
    ''
    '## Repository visualization conventions applied'
    sprintf('- Inspected: `%s`', strjoin(strsplit(style_source, '; '), '`, `'))
    sprintf('- Applied conventions: %s', style_conventions)
    ''
    '## Visualization choices'
    sprintf('- Number of curves in temperature-encoded overlays: %d', nTrace)
    '- Legend vs colormap: colorbar used for ordered temperature stacks; short legends used only for data-versus-reconstruction semantics.'
    '- Colormap used for temperature stacks: `parula` with monotonic temperature mapping.'
    '- Residual heatmap colormap: zero-centered diverging map because signed residual zero is physically meaningful.'
    '- Smoothing applied: none.'
    '- Justification: readability repair required explicit temperature semantics, readable labels, and robust-scale companion views while preserving the visible 13 K outlier and the original RF5A conclusions.'
    ''
    '## Repaired figure paths (PNG + FIG)'
    };
for i = 1:height(inv)
    lines{end+1,1} = sprintf('- `%s`', inv.png_path(i)); %#ok<AGROW>
    lines{end+1,1} = sprintf('- `%s`', inv.fig_path(i)); %#ok<AGROW>
end
lines = [lines; {
    ''
    '## Scope guardrails'
    '- No RF3 data were modified.'
    '- No RF4B outputs were modified.'
    '- No RF5A metrics or verdict logic were changed.'
    '- No RF5B effective-rank analysis was run.'
    '- No collapse replay was run.'
    '- No time-mode analysis was run.'
    '- No cross-module analysis was run.'
    }]; %#ok<AGROW>

fid = fopen(reportPath, 'w');
if fid < 0
    error('Could not write report: %s', reportPath);
end
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i});
end
fclose(fid);

disp('RF5A figure readability repair complete.');
disp(repairedFigDir);

%% ---------------- Local functions ----------------
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

function [traceColors, temperatureMap] = local_temperature_colors(temps)
nMap = 256;
temperatureMap = parula(nMap);
tMin = min(temps);
tMax = max(temps);
if tMax <= tMin
    idx = repmat(round(nMap/2), numel(temps), 1);
else
    idx = round(1 + (nMap - 1) * (temps - tMin) / (tMax - tMin));
end
idx = max(1, min(nMap, idx));
traceColors = temperatureMap(idx, :);
end

function ticks = local_temperature_ticks(temps, outlierTemp)
temps = sort(unique(temps(:)));
if numel(temps) <= 8
    ticks = temps.';
else
    idx = unique(round(linspace(1, numel(temps), 6)));
    ticks = temps(idx).';
end
if all(abs(ticks - outlierTemp) > 1e-6)
    ticks = sort(unique([ticks, outlierTemp]));
end
end

function local_add_temperature_colorbar(ax, tempTicks, temperatureMap)
cb = colorbar(ax);
colormap(ax, temperatureMap);
caxis(ax, [tempTicks(1), tempTicks(end)]);
cb.Label.String = 'Temperature (K)';
cb.Label.Interpreter = 'none';
cb.TickLabelInterpreter = 'none';
cb.Ticks = tempTicks;
cb.Limits = [tempTicks(1), tempTicks(end)];
cb.TickLabels = compose('%.3g', tempTicks);
end

function local_style_curve_axes(ax)
set(ax, 'Box', 'off', 'TickDir', 'out', 'Layer', 'top', ...
    'XMinorTick', 'off', 'YMinorTick', 'off', 'LineWidth', 1.0);
grid(ax, 'off');
end

function local_style_heatmap_axes(ax)
set(ax, 'Box', 'on', 'TickDir', 'out', 'Layer', 'top', ...
    'XMinorTick', 'off', 'YMinorTick', 'off', 'LineWidth', 1.0);
grid(ax, 'off');
end

function local_add_outlier_annotation(ax, textStr)
text(ax, 0.02, 0.93, textStr, 'Units', 'normalized', ...
    'Interpreter', 'none', 'FontSize', 8, 'BackgroundColor', 'w', 'Margin', 1);
end

function tf = local_choice_needs_robust_scale(method)
tf = any(method == ["peak_to_peak","mad_scale","abs_endpoint_diff"]);
end

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

function name = local_control_display_name(controlType)
controlType = string(controlType);
name = strings(size(controlType));
for i = 1:numel(controlType)
    switch controlType(i)
        case "temperature_label_shuffle"
            name(i) = "Temperature-label shuffle";
        case "trace_order_permutation"
            name(i) = "Trace-order permutation";
        case "random_amplitude_surrogate"
            name(i) = "Random amplitude surrogate";
        case "smooth_amplitude_surrogate"
            name(i) = "Smooth amplitude surrogate";
        case "mean_curve_plus_amplitude_synthetic"
            name(i) = "Mean-curve plus amplitude synthetic";
        otherwise
            name(i) = replace(controlType(i), "_", " ");
    end
end
end

function local_plot_control_distributions(ax, ctrlTbl, ctrlLevels, realImprovement, useZoom)
hold(ax, 'on');
ctrlColors = lines(numel(ctrlLevels));
for i = 1:numel(ctrlLevels)
    vals = local_toDouble(ctrlTbl.spread_reduction(ctrlTbl.control_type == ctrlLevels(i)));
    y = i + 0.16 * linspace(-1, 1, numel(vals)).';
    scatter(ax, vals, y, 14, 'MarkerFaceColor', ctrlColors(i,:), ...
        'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.30);
    plot(ax, median(vals, 'omitnan'), i, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 6, 'LineWidth', 1.2);
end
set(ax, 'YTick', 1:numel(ctrlLevels), 'YTickLabel', cellstr(local_control_display_name(ctrlLevels)), ...
    'YDir', 'reverse', 'TickLabelInterpreter', 'none');
local_style_curve_axes(ax);
xlabel(ax, 'Spread reduction', 'Interpreter', 'none');
ylabel(ax, 'Control family', 'Interpreter', 'none');
xline(ax, realImprovement, 'r-', 'LineWidth', 2.0);
if useZoom
    controlVals = local_toDouble(ctrlTbl.spread_reduction);
    zoomVals = [realImprovement; controlVals(controlVals > quantile(controlVals, 0.01))];
    xlim(ax, local_robust_limits(zoomVals, 0.02, 0.98));
end
end

function cmap = local_blue_white_red(n)
if nargin < 1
    n = 256;
end
half1 = floor(n/2);
half2 = n - half1;
blue = [linspace(0.10, 1.00, half1)', linspace(0.25, 1.00, half1)', ones(half1,1)];
red = [ones(half2,1), linspace(1.00, 0.10, half2)', linspace(1.00, 0.10, half2)'];
cmap = [blue; red];
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
