function out = ridge_relaxation_comparison(cfg)
% ridge_relaxation_comparison
% Thin cross-experiment diagnostic comparing switching ridge observables to relaxation participation.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

cfg = applyDefaults(cfg, repoRoot);
runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | switch:%s', cfg.relaxRunName, cfg.switchRunName);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Ridge-relaxation comparison run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', cfg.relaxRunName);
fprintf('Switching source run: %s\n', cfg.switchRunName);
appendText(run.log_path, sprintf('[%s] ridge-relaxation comparison started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', cfg.relaxRunName));
appendText(run.log_path, sprintf('Switching source: %s\n', cfg.switchRunName));

relax = loadRelaxationData(cfg.relaxRunDir);
switching = loadSwitchingData(cfg.switchRunDir);
aligned = alignTemperatureAxes(relax, switching, cfg);
metrics = computeComparisonMetrics(relax, switching, aligned);

comparisonTbl = table(aligned.T, aligned.A, aligned.S_peak, aligned.I_peak, aligned.width_I, ...
    'VariableNames', {'T','A(T)','S_peak(T)','I_peak(T)','width_I(T)'});
summaryTbl = table(metrics.corr_A_Speak, relax.Relax_T_peak, metrics.Switch_T_peak, relax.Relax_peak_width, metrics.Switch_peak_width, ...
    'VariableNames', {'corr_A_Speak','Relax_T_peak','Switch_T_peak','Relax_peak_width','Switch_peak_width'});

comparisonPath = save_run_table(comparisonTbl, 'ridge_relaxation_comparison.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'ridge_relaxation_summary.csv', runDir);

fig1 = saveRawComparisonFigure(relax, switching, aligned, metrics, runDir, 'A_vs_S_peak');
fig2 = saveNormalizedComparisonFigure(aligned, metrics, runDir, 'normalized_ridge_relaxation_comparison');
fig3 = saveIpeakFigure(switching, runDir, 'switching_ridge_current');
fig4 = saveWidthFigure(switching, metrics, runDir, 'switching_ridge_width');
fig5 = saveSummaryFigure(relax, switching, aligned, metrics, runDir, 'ridge_relaxation_summary');

reportText = buildReport(cfg, relax, switching, aligned, metrics);
reportPath = save_run_report(reportText, 'ridge_relaxation_comparison_report.md', runDir);
zipPath = buildReviewZip(runDir);

appendText(run.log_path, sprintf('[%s] ridge-relaxation comparison complete\n', stampNow()));
appendText(run.log_path, sprintf('Comparison table: %s\n', comparisonPath));
appendText(run.log_path, sprintf('Summary table: %s\n', summaryPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));
appendText(run.notes_path, sprintf('corr_A_Speak = %.6g\n', metrics.corr_A_Speak));
appendText(run.notes_path, sprintf('corr_A_Speak_norm = %.6g\n', metrics.corr_A_Speak_norm));
appendText(run.notes_path, sprintf('rms_A_Speak_norm = %.6g\n', metrics.rms_A_Speak_norm));
appendText(run.notes_path, sprintf('Relax_T_peak = %.6g K\n', relax.Relax_T_peak));
appendText(run.notes_path, sprintf('Switch_T_peak = %.6g K\n', metrics.Switch_T_peak));
appendText(run.notes_path, sprintf('Relax_peak_width = %.6g K\n', relax.Relax_peak_width));
appendText(run.notes_path, sprintf('Switch_peak_width = %.6g K\n', metrics.Switch_peak_width));
appendText(run.notes_path, sprintf('corr_widthI_A = %.6g\n', metrics.corr_widthI_A));
appendText(run.notes_path, sprintf('verdict = %s\n', metrics.windowVerdict));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.relax = relax;
out.switching = switching;
out.aligned = aligned;
out.metrics = metrics;
out.tables = struct('comparison', string(comparisonPath), 'summary', string(summaryPath));
out.figures = struct('raw', string(fig1.png), 'normalized', string(fig2.png), 'ipeak', string(fig3.png), 'width', string(fig4.png), 'summary', string(fig5.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Ridge-relaxation comparison complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('corr(A,S_peak) = %.6f\n', metrics.corr_A_Speak);
fprintf('corr(A_norm,S_peak_norm) = %.6f\n', metrics.corr_A_Speak_norm);
fprintf('RMS(A_norm-S_peak_norm) = %.6f\n', metrics.rms_A_Speak_norm);
fprintf('Relax_T_peak vs Switch_T_peak: %.3f K vs %.3f K\n', relax.Relax_T_peak, metrics.Switch_T_peak);
fprintf('Relax_peak_width vs Switch_peak_width: %.3f K vs %.3f K\n', relax.Relax_peak_width, metrics.Switch_peak_width);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefaultField(cfg, 'runLabel', 'ridge_relaxation_comparison');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefaultField(cfg, 'alignmentMode', 'switching_grid');
cfg.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', cfg.relaxRunName);
cfg.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', cfg.switchRunName);
end

function relax = loadRelaxationData(relaxRunDir)
obsTbl = readtable(fullfile(relaxRunDir, 'tables', 'observables_relaxation.csv'));
tempTbl = readtable(fullfile(relaxRunDir, 'tables', 'temperature_observables.csv'));

relax = struct();
relax.T = tempTbl.T(:);
relax.A = tempTbl.('A_T')(:);
if ismember('R_T', tempTbl.Properties.VariableNames)
    relax.R = tempTbl.('R_T')(:);
else
    relax.R = NaN(size(relax.T));
end
relax.Relax_T_peak = obsTbl.Relax_T_peak(1);
relax.Relax_peak_width = obsTbl.Relax_peak_width(1);
[relax.windowLow, relax.windowHigh, relax.windowWidth, relax.peakFromCurve] = computeHalfMaxWindow(relax.T, relax.A);
if ~isfinite(relax.windowWidth)
    relax.windowWidth = relax.Relax_peak_width;
    relax.windowLow = relax.Relax_T_peak - 0.5 * relax.Relax_peak_width;
    relax.windowHigh = relax.Relax_T_peak + 0.5 * relax.Relax_peak_width;
end
relax.A_norm = normalizeToMax(relax.A);
relax.R_norm = normalizeToMax(relax.R);
end

function switching = loadSwitchingData(switchRunDir)
obsTbl = readtable(fullfile(switchRunDir, 'observable_matrix.csv'));
obsLong = readtable(fullfile(switchRunDir, 'observables.csv'));

switching = struct();
switching.T = obsTbl.T(:);
switching.S_peak = obsTbl.('S_peak')(:);
switching.I_peak = obsTbl.('I_peak')(:);
switching.width_I = obsTbl.('width_I')(:);
switching.halfwidth_diff_norm = obsTbl.('halfwidth_diff_norm')(:);
switching.asym = obsTbl.('asym')(:);
switching.observablesLong = obsLong;
[switching.windowLow, switching.windowHigh, switching.windowWidth, switching.Switch_T_peak] = computeHalfMaxWindow(switching.T, switching.S_peak);
switching.S_peak_norm = normalizeToMax(switching.S_peak);
end

function aligned = alignTemperatureAxes(relax, switching, cfg)
lo = max(min(relax.T), min(switching.T));
hi = min(max(relax.T), max(switching.T));
if ~(isfinite(lo) && isfinite(hi) && hi > lo)
    error('No overlapping temperature interval exists between relaxation and switching runs.');
end

switchMask = switching.T >= lo & switching.T <= hi;
Tgrid = switching.T(switchMask);
if isempty(Tgrid)
    error('No switching temperatures remain inside the overlap window.');
end

aligned = struct();
aligned.mode = string(cfg.alignmentMode);
aligned.T = Tgrid(:);
aligned.A = interp1(relax.T, relax.A, aligned.T, 'pchip', NaN);
aligned.R = interp1(relax.T, relax.R, aligned.T, 'pchip', NaN);
aligned.S_peak = switching.S_peak(switchMask);
aligned.I_peak = switching.I_peak(switchMask);
aligned.width_I = switching.width_I(switchMask);
aligned.halfwidth_diff_norm = switching.halfwidth_diff_norm(switchMask);
aligned.asym = switching.asym(switchMask);
aligned.A_norm = normalizeToMax(aligned.A);
aligned.S_peak_norm = normalizeToMax(aligned.S_peak);
end

function metrics = computeComparisonMetrics(relax, switching, aligned)
metrics = struct();
metrics.corr_A_Speak = corrSafe(aligned.A, aligned.S_peak);
metrics.Switch_T_peak = switching.Switch_T_peak;
metrics.Switch_peak_width = switching.windowWidth;
metrics.corr_A_Speak_norm = corrSafe(aligned.A_norm, aligned.S_peak_norm);
delta = aligned.A_norm - aligned.S_peak_norm;
metrics.rms_A_Speak_norm = sqrt(mean(delta(isfinite(delta)).^2));
metrics.corr_widthI_A = corrSafe(aligned.width_I, aligned.A);
metrics.corr_widthI_A_norm = corrSafe(normalizeToMax(aligned.width_I), aligned.A_norm);
metrics.peak_difference_K = metrics.Switch_T_peak - relax.Relax_T_peak;
metrics.width_difference_K = metrics.Switch_peak_width - relax.Relax_peak_width;
metrics.windowOverlap = intervalOverlap(relax.windowLow, relax.windowHigh, switching.windowLow, switching.windowHigh);
metrics.windowVerdict = classifyWindowMatch(metrics.corr_A_Speak_norm, metrics.peak_difference_K, metrics.width_difference_K, metrics.windowOverlap);
end

function figPaths = saveRawComparisonFigure(relax, switching, aligned, metrics, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 620]);
ax = axes(fh);
yyaxis(ax, 'left');
plot(ax, relax.T, relax.A, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'A(T)');
ylabel(ax, 'Relaxation amplitude A(T)', 'FontSize', 14);

yyaxis(ax, 'right');
plot(ax, switching.T, switching.S_peak, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'S_{peak}(T)');
ylabel(ax, 'Switching ridge amplitude S_{peak}(T)', 'FontSize', 14);

hold(ax, 'on');
xline(ax, relax.Relax_T_peak, '--', 'LineWidth', 1.8, 'Color', [0.2 0.2 0.2], 'DisplayName', 'Relax T_{peak}');
xline(ax, metrics.Switch_T_peak, ':', 'LineWidth', 1.8, 'Color', [0.85 0.33 0.10], 'DisplayName', 'Switch T_{peak}');
hold(ax, 'off');

grid(ax, 'on');
xlabel(ax, 'Temperature T (K)', 'FontSize', 14);
title(ax, 'Relaxation amplitude and switching ridge amplitude', 'FontSize', 16);
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
legend(ax, 'Location', 'best');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveNormalizedComparisonFigure(aligned, metrics, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 620]);
ax = axes(fh); hold(ax, 'on');
plot(ax, aligned.T, aligned.A_norm, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'A_{norm}(T)');
plot(ax, aligned.T, aligned.S_peak_norm, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'S_{peak,norm}(T)');
text(ax, aligned.T(2), 0.12, sprintf('corr = %.3f\nRMS = %.3f', metrics.corr_A_Speak_norm, metrics.rms_A_Speak_norm), 'FontSize', 12, 'BackgroundColor', 'w', 'Margin', 6);
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature T (K)', 'FontSize', 14);
ylabel(ax, 'Normalized amplitude', 'FontSize', 14);
title(ax, 'Normalized relaxation vs switching ridge amplitude', 'FontSize', 16);
legend(ax, 'Location', 'best');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveIpeakFigure(switching, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 620]);
ax = axes(fh);
plot(ax, switching.T, switching.I_peak, '-o', 'LineWidth', 2.2, 'MarkerSize', 5);
grid(ax, 'on');
xlabel(ax, 'Temperature T (K)', 'FontSize', 14);
ylabel(ax, 'Ridge current I_{peak}(T) (mA)', 'FontSize', 14);
title(ax, 'Switching ridge current trajectory', 'FontSize', 16);
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveWidthFigure(switching, metrics, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 620]);
ax = axes(fh); hold(ax, 'on');
plot(ax, switching.T, switching.width_I, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'width_I(T)');
plot(ax, switching.T, normalizeToMax(switching.width_I), '--', 'LineWidth', 1.8, 'DisplayName', 'width_I(T) / max');
text(ax, switching.T(2), max(switching.width_I) * 0.88, sprintf('corr(width_I, A) = %.3f', metrics.corr_widthI_A), 'FontSize', 12, 'BackgroundColor', 'w', 'Margin', 6);
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature T (K)', 'FontSize', 14);
ylabel(ax, 'Switching ridge width (mA)', 'FontSize', 14);
title(ax, 'Switching ridge current width vs temperature', 'FontSize', 16);
legend(ax, 'Location', 'best');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveSummaryFigure(relax, switching, aligned, metrics, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 700]);
ax = axes(fh); hold(ax, 'on');
patch(ax, [relax.windowLow relax.windowHigh relax.windowHigh relax.windowLow], [0 0 1.05 1.05], [0.75 0.85 1.00], ...
    'FaceAlpha', 0.30, 'EdgeColor', 'none', 'DisplayName', 'Relaxation FWHM');
patch(ax, [switching.windowLow switching.windowHigh switching.windowHigh switching.windowLow], [0 0 1.05 1.05], [1.00 0.85 0.75], ...
    'FaceAlpha', 0.30, 'EdgeColor', 'none', 'DisplayName', 'Switching FWHM');
plot(ax, aligned.T, aligned.A_norm, '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'A_{norm}(T)');
plot(ax, aligned.T, aligned.S_peak_norm, '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'S_{peak,norm}(T)');
plot(ax, relax.Relax_T_peak, 1.0, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8, 'DisplayName', 'Relax T_{peak}');
plot(ax, metrics.Switch_T_peak, 0.96, 'kd', 'MarkerFaceColor', 'w', 'MarkerSize', 8, 'DisplayName', 'Switch T_{peak}');
text(ax, min(aligned.T)+0.6, 0.14, sprintf('Peak: %.1f K vs %.1f K\nWidth: %.2f K vs %.2f K\nOverlap: %.3f\nVerdict: %s', ...
    relax.Relax_T_peak, metrics.Switch_T_peak, relax.Relax_peak_width, metrics.Switch_peak_width, metrics.windowOverlap, strrep(metrics.windowVerdict, '_', ' ')), ...
    'FontSize', 12, 'BackgroundColor', 'w', 'Margin', 6);
hold(ax, 'off');
grid(ax, 'on');
ylim(ax, [0 1.05]);
xlabel(ax, 'Temperature T (K)', 'FontSize', 14);
ylabel(ax, 'Normalized window coordinate', 'FontSize', 14);
title(ax, 'Ridge-relaxation window summary', 'FontSize', 16);
legend(ax, 'Location', 'eastoutside');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReport(cfg, relax, switching, aligned, metrics)
lines = {};
lines{end+1,1} = '# Ridge-Relaxation Comparison Report';
lines{end+1,1} = '';
lines{end+1,1} = '## Data sources used';
lines{end+1,1} = sprintf('- Relaxation run: `%s`', cfg.relaxRunName);
lines{end+1,1} = sprintf('- Switching run: `%s`', cfg.switchRunName);
lines{end+1,1} = '- Relaxation inputs: `tables/temperature_observables.csv`, `tables/observables_relaxation.csv`';
lines{end+1,1} = '- Switching inputs: `observable_matrix.csv`, `observables.csv`';
lines{end+1,1} = sprintf('- Temperature alignment used the switching grid over the overlap interval [%.1f, %.1f] K with pchip interpolation of relaxation observables because the two runs have no common sampled temperatures.', min(aligned.T), max(aligned.T));
lines{end+1,1} = '';
lines{end+1,1} = '## Correlation results';
lines{end+1,1} = sprintf('- corr(A(T), S_peak(T)) = %.6f', metrics.corr_A_Speak);
lines{end+1,1} = sprintf('- corr(A_norm(T), S_peak_norm(T)) = %.6f', metrics.corr_A_Speak_norm);
lines{end+1,1} = sprintf('- RMS difference of normalized curves = %.6f', metrics.rms_A_Speak_norm);
lines{end+1,1} = sprintf('- corr(width_I(T), A(T)) = %.6f', metrics.corr_widthI_A);
lines{end+1,1} = '';
lines{end+1,1} = '## Peak position comparison';
lines{end+1,1} = sprintf('- Relax_T_peak = %.6g K', relax.Relax_T_peak);
lines{end+1,1} = sprintf('- Switch_T_peak = %.6g K', metrics.Switch_T_peak);
lines{end+1,1} = sprintf('- Peak-position difference = %.6g K', metrics.peak_difference_K);
lines{end+1,1} = '';
lines{end+1,1} = '## Width comparison';
lines{end+1,1} = sprintf('- Relax_peak_width = %.6g K', relax.Relax_peak_width);
lines{end+1,1} = sprintf('- Switch_peak_width = %.6g K', metrics.Switch_peak_width);
lines{end+1,1} = sprintf('- Width difference = %.6g K', metrics.width_difference_K);
lines{end+1,1} = sprintf('- Temperature-window overlap fraction = %.6f', metrics.windowOverlap);
lines{end+1,1} = '';
lines{end+1,1} = '## Interpretation';
lines{end+1,1} = sprintf('- Ridge-window verdict: **%s**', strrep(metrics.windowVerdict, '_', ' '));
if metrics.windowVerdict == "matched"
    lines{end+1,1} = '- The switching ridge amplitude defines a temperature window that is consistent with the relaxation participation window in both peak location and width.';
elseif metrics.windowVerdict == "partially_matched"
    lines{end+1,1} = '- The switching ridge shows partial agreement with the relaxation window, but either the peak location, width, or overall curve shape remains noticeably offset.';
else
    lines{end+1,1} = '- The switching ridge amplitude does not define a temperature window that cleanly matches the relaxation participation window for this pair of stored runs.';
end
lines{end+1,1} = '';
lines{end+1,1} = '## Visualization choices';
lines{end+1,1} = '- number of curves: 2 curves in the raw comparison, 2 curves in the normalized comparison, 1 curve each for ridge current and ridge width, and 2 normalized curves plus 2 window bands in the summary';
lines{end+1,1} = '- legend vs colormap: legends only, because every figure has 6 or fewer curves';
lines{end+1,1} = '- colormap used: none for line plots; pastel patches only for the summary window bands';
lines{end+1,1} = '- smoothing applied: none in this diagnostic because it reuses exported observables rather than differentiating the map';
lines{end+1,1} = '- justification: the figure set focuses directly on the ridge-amplitude window and its peak/width comparison to relaxation without introducing new map-level processing';
reportText = strjoin(lines, newline);
end

function zipPath = buildReviewZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'ridge_relaxation_comparison.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zipInputs = {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};
zip(zipPath, zipInputs, runDir);
end

function [windowLow, windowHigh, width, peakT] = computeHalfMaxWindow(T, y)
T = T(:);
y = y(:);
windowLow = NaN;
windowHigh = NaN;
width = NaN;
peakT = NaN;
ok = isfinite(T) & isfinite(y);
T = T(ok);
y = y(ok);
if numel(T) < 3
    return;
end
[peakVal, idxPeak] = max(y);
if ~(isfinite(peakVal) && peakVal > 0)
    return;
end
peakT = T(idxPeak);
halfVal = 0.5 * peakVal;
leftIdx = find(y(1:idxPeak) <= halfVal, 1, 'last');
if isempty(leftIdx)
    windowLow = T(1);
elseif leftIdx == idxPeak
    windowLow = T(idxPeak);
else
    windowLow = interpCross(T(leftIdx), T(leftIdx + 1), y(leftIdx) - halfVal, y(leftIdx + 1) - halfVal);
end
rightRel = find(y(idxPeak:end) <= halfVal, 1, 'first');
if isempty(rightRel)
    windowHigh = T(end);
else
    rightIdx = idxPeak + rightRel - 1;
    if rightIdx == idxPeak
        windowHigh = T(idxPeak);
    else
        windowHigh = interpCross(T(rightIdx - 1), T(rightIdx), y(rightIdx - 1) - halfVal, y(rightIdx) - halfVal);
    end
end
width = windowHigh - windowLow;
if ~(isfinite(width) && width >= 0)
    width = NaN;
end
end

function yNorm = normalizeToMax(y)
y = y(:);
yNorm = NaN(size(y));
mx = max(y, [], 'omitnan');
if isfinite(mx) && mx > 0
    yNorm = y ./ mx;
end
end

function r = corrSafe(x, y)
x = x(:);
y = y(:);
ok = isfinite(x) & isfinite(y);
r = NaN;
if nnz(ok) < 3
    return;
end
cc = corrcoef(x(ok), y(ok));
if numel(cc) >= 4
    r = cc(1,2);
end
end

function overlap = intervalOverlap(aLow, aHigh, bLow, bHigh)
overlap = NaN;
if ~all(isfinite([aLow aHigh bLow bHigh]))
    return;
end
intersectionWidth = max(0, min(aHigh, bHigh) - max(aLow, bLow));
unionWidth = max(aHigh, bHigh) - min(aLow, bLow);
if unionWidth <= 0
    return;
end
overlap = intersectionWidth / unionWidth;
end

function verdict = classifyWindowMatch(corrNorm, peakDiff, widthDiff, overlap)
if isfinite(corrNorm) && isfinite(overlap) && corrNorm >= 0.80 && abs(peakDiff) <= 3 && abs(widthDiff) <= 4 && overlap >= 0.50
    verdict = "matched";
elseif isfinite(corrNorm) && isfinite(overlap) && corrNorm >= 0.50 && abs(peakDiff) <= 8 && abs(widthDiff) <= 10 && overlap >= 0.25
    verdict = "partially_matched";
else
    verdict = "not_matched";
end
end

function x0 = interpCross(x1, x2, y1, y2)
if ~all(isfinite([x1 x2 y1 y2]))
    x0 = NaN;
    return;
end
if abs(y2 - y1) < eps
    x0 = mean([x1 x2]);
    return;
end
x0 = x1 - y1 * (x2 - x1) / (y2 - y1);
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = value;
end
end

