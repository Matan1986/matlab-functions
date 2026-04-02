function out = switching_a1_vs_curvature_test(cfg)
% switching_a1_vs_curvature_test
% Focused test: a1(T) vs local ridge curvature near I_peak.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);
source = resolveSourcePaths(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('a1:%s | curvature:%s', char(source.a1RunId), char(source.curvatureRunId));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching a1-vs-curvature run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] switching a1-vs-curvature test started\n', stampNow()));
appendText(run.log_path, sprintf('a1 source run: %s\n', char(source.a1RunId)));
appendText(run.log_path, sprintf('a1 source file: %s\n', source.a1Path));
appendText(run.log_path, sprintf('curvature source run: %s\n', char(source.curvatureRunId)));
appendText(run.log_path, sprintf('curvature source file: %s\n', source.curvaturePath));

a1Tbl = sortrows(readtable(source.a1Path), 'T_K');
curvTbl = sortrows(readtable(source.curvaturePath), 'T_K');

assert(ismember('a_1', a1Tbl.Properties.VariableNames), 'a1 table missing a_1 column.');
assert(ismember('T_K', a1Tbl.Properties.VariableNames), 'a1 table missing T_K column.');
assert(ismember('T_K', curvTbl.Properties.VariableNames), 'curvature table missing T_K column.');
assert(ismember('curvature_near_peak', curvTbl.Properties.VariableNames), ...
    'curvature table missing curvature_near_peak column.');

[temps, ia, ic] = intersect(double(a1Tbl.T_K(:)), double(curvTbl.T_K(:)), 'stable');
assert(~isempty(temps), 'No overlapping temperatures between a1(T) and curvature(T).');

a1 = double(a1Tbl.a_1(ia));
curvature = double(curvTbl.curvature_near_peak(ic));
sharpness = -curvature;

valid = isfinite(temps) & isfinite(a1) & isfinite(curvature);
temps = temps(valid);
a1 = a1(valid);
curvature = curvature(valid);
sharpness = sharpness(valid);

assert(numel(temps) >= 3, 'Need at least 3 matched finite points for correlation analysis.');

[pearsonR, nPoints] = safeCorr(a1, curvature, 'Pearson');
[spearmanRho, ~] = safeCorr(a1, curvature, 'Spearman');

[a1PeakTAbs, ~] = peakOf(temps, a1, true);
[curvPeakTAbs, ~] = peakOf(temps, curvature, true);
deltaPeakAbsK = curvPeakTAbs - a1PeakTAbs;

corrTbl = table( ...
    nPoints, pearsonR, spearmanRho, ...
    string(source.a1RunId), string(source.curvatureRunId), ...
    string(source.a1Path), string(source.curvaturePath), ...
    'VariableNames', {'n_points', 'pearson_r', 'spearman_rho', ...
    'a1_source_run', 'curvature_source_run', 'a1_source_file', 'curvature_source_file'});
corrPath = save_run_table(corrTbl, 'a1_vs_curvature_correlations.csv', runDir);

peakTbl = table( ...
    a1PeakTAbs, curvPeakTAbs, deltaPeakAbsK, ...
    'VariableNames', {'a1_peak_abs_T_K', 'curvature_peak_abs_T_K', 'delta_peak_T_K'});
peakPath = save_run_table(peakTbl, 'a1_vs_curvature_peak_alignment.csv', runDir);

figRaw = plotRawOverlay(temps, a1, curvature, runDir);
figNorm = plotNormalizedOverlay(temps, a1, curvature, runDir);
figScatter = plotScatter(temps, a1, curvature, pearsonR, spearmanRho, runDir);

reportText = buildReportText(source, nPoints, pearsonR, spearmanRho, ...
    a1PeakTAbs, curvPeakTAbs, deltaPeakAbsK, corrPath, peakPath, figRaw, figNorm, figScatter);
reportPath = save_run_report(reportText, 'switching_a1_vs_curvature_test.md', runDir);

zipPath = buildReviewZip(runDir, 'switching_a1_vs_curvature_test_bundle.zip');

appendText(run.notes_path, sprintf('n points = %d\n', nPoints));
appendText(run.notes_path, sprintf('Pearson(a1, curvature) = %.6g\n', pearsonR));
appendText(run.notes_path, sprintf('Spearman(a1, curvature) = %.6g\n', spearmanRho));
appendText(run.notes_path, sprintf('T_peak(|a1|) = %.2f K\n', a1PeakTAbs));
appendText(run.notes_path, sprintf('T_peak(|curvature|) = %.2f K\n', curvPeakTAbs));
appendText(run.notes_path, sprintf('Delta peak T = %.2f K\n', deltaPeakAbsK));
appendText(run.notes_path, sprintf('correlations table = %s\n', corrPath));
appendText(run.notes_path, sprintf('peak-alignment table = %s\n', peakPath));
appendText(run.notes_path, sprintf('raw overlay figure = %s\n', figRaw.png));
appendText(run.notes_path, sprintf('normalized overlay figure = %s\n', figNorm.png));
appendText(run.notes_path, sprintf('scatter figure = %s\n', figScatter.png));
appendText(run.notes_path, sprintf('report = %s\n', reportPath));
appendText(run.notes_path, sprintf('zip = %s\n', zipPath));

appendText(run.log_path, sprintf('[%s] switching a1-vs-curvature test complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlations table: %s\n', corrPath));
appendText(run.log_path, sprintf('Peak-alignment table: %s\n', peakPath));
appendText(run.log_path, sprintf('Raw overlay figure: %s\n', figRaw.png));
appendText(run.log_path, sprintf('Normalized overlay figure: %s\n', figNorm.png));
appendText(run.log_path, sprintf('Scatter figure: %s\n', figScatter.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.pearson = pearsonR;
out.spearman = spearmanRho;
out.deltaPeakT = deltaPeakAbsK;
out.paths = struct( ...
    'correlations', string(corrPath), ...
    'peakAlignment', string(peakPath), ...
    'overlayRaw', string(figRaw.png), ...
    'overlayNormalized', string(figNorm.png), ...
    'scatter', string(figScatter.png), ...
    'report', string(reportPath), ...
    'zip', string(zipPath));
out.series = struct('T_K', temps, 'a1', a1, 'curvature', curvature, 'sharpness', sharpness);

fprintf('\n=== Switching a1-vs-curvature test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson(a1, curvature): %.4f\n', pearsonR);
fprintf('Spearman(a1, curvature): %.4f\n', spearmanRho);
fprintf('T_peak(|a1|): %.2f K\n', a1PeakTAbs);
fprintf('T_peak(|curvature|): %.2f K\n', curvPeakTAbs);
fprintf('Delta peak T: %.2f K\n', deltaPeakAbsK);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_a1_vs_curvature_test');
cfg = setDefault(cfg, 'a1RunId', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefault(cfg, 'curvaturePreferredRunId', 'run_2026_03_09_224017_mechanism_followup');
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.a1RunId = string(cfg.a1RunId);
source.curvaturePreferredRunId = string(cfg.curvaturePreferredRunId);

source.phi1Guard = enforce_canonical_phi1_source({source.a1RunId}, 'switching_a1_vs_curvature_test');

source.a1RunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.a1RunId));
source.a1Path = fullfile(source.a1RunDir, 'tables', 'switching_dynamic_shape_mode_amplitudes.csv');
assert(exist(source.a1Path, 'file') == 2, 'Required a1 source file missing: %s', source.a1Path);

runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');
assert(exist(runsRoot, 'dir') == 7, 'Switching runs directory missing: %s', runsRoot);

preferredRunDir = fullfile(runsRoot, char(source.curvaturePreferredRunId));
[curvPathPreferred, hasPreferred] = findCurvatureFileInRun(preferredRunDir);

runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
runNames = string({runDirs.name});
runNames = sort(runNames, 'descend');

curvPath = "";
curvRunId = "";

if hasPreferred
    curvPath = string(curvPathPreferred);
    curvRunId = source.curvaturePreferredRunId;
end

for i = 1:numel(runNames)
    runName = runNames(i);
    if contains(runName, "legacy")
        continue;
    end
    runDir = fullfile(runsRoot, char(runName));
    try
        [candidatePath, ok] = findCurvatureFileInRun(runDir);
        if ~ok
            continue;
        end
        t = readtable(candidatePath);
        if ~all(ismember({'T_K', 'curvature_near_peak'}, t.Properties.VariableNames))
            continue;
        end
        vv = isfinite(double(t.T_K)) & isfinite(double(t.curvature_near_peak));
        if nnz(vv) < 3
            continue;
        end
        if strlength(curvRunId) == 0 || runName > curvRunId
            curvPath = string(candidatePath);
            curvRunId = runName;
        end
    catch
        % Skip malformed or incompatible candidate files.
    end
end

assert(strlength(curvPath) > 0, 'No valid curvature_near_peak source file found in switching runs.');
source.curvatureRunId = curvRunId;
source.curvaturePath = char(curvPath);
end

function [pathOut, ok] = findCurvatureFileInRun(runDir)
ok = false;
pathOut = '';
if exist(runDir, 'dir') ~= 7
    return;
end

candidates = { ...
    fullfile(runDir, 'tables', 'mechanism_ridge_shape_metrics.csv'), ...
    fullfile(runDir, 'mechanism_followup', 'mechanism_ridge_shape_metrics.csv')};

for i = 1:numel(candidates)
    if exist(candidates{i}, 'file') == 2
        pathOut = candidates{i};
        ok = true;
        return;
    end
end
end

function figPaths = plotRawOverlay(T, a1, curvature, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 14 10.5]);
ax = axes(fig);
hold(ax, 'on');
yyaxis(ax, 'left');
plot(ax, T, a1, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', 'a_1(T)');
ylabel(ax, 'a_1(T) (a.u.)');

yyaxis(ax, 'right');
plot(ax, T, curvature, '-s', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, 'DisplayName', 'curvature_{near peak}(T)');
ylabel(ax, 'curvature_{near peak} (a.u.)');

xlabel(ax, 'Temperature (K)');
title(ax, 'Raw overlay: a_1(T) vs local ridge curvature near I_{peak}');
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best');
hold(ax, 'off');

figPaths = save_run_figure(fig, 'a1_vs_curvature_overlay', runDir);
close(fig);
end

function figPaths = plotNormalizedOverlay(T, a1, curvature, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 14 10.5]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, T, normalizeSigned(a1), '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', 'a_1(T) signed-norm');
plot(ax, T, normalizeSigned(curvature), '-s', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, 'DisplayName', 'curvature(T) signed-norm');
plot(ax, T, normalize01(abs(a1)), '--', 'LineWidth', 2.0, ...
    'Color', [0.20 0.20 0.20], 'DisplayName', '|a_1(T)| norm');
plot(ax, T, normalize01(abs(curvature)), ':', 'LineWidth', 2.2, ...
    'Color', [0.47 0.67 0.19], 'DisplayName', '|curvature(T)| norm');
yline(ax, 0, '-', 'LineWidth', 1.0, 'Color', [0.70 0.70 0.70]);

xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized amplitude');
title(ax, 'Normalized overlay: a_1(T) vs local ridge curvature');
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best');
hold(ax, 'off');

figPaths = save_run_figure(fig, 'a1_vs_curvature_overlay_normalized', runDir);
close(fig);
end

function figPaths = plotScatter(~, a1, curvature, pearsonR, spearmanRho, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 12 10]);
ax = axes(fig);
hold(ax, 'on');
scatter(ax, curvature, a1, 64, 'filled', ...
    'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerEdgeColor', [0.00 0.45 0.74], ...
    'DisplayName', 'Data points');

m = isfinite(curvature) & isfinite(a1);
if nnz(m) >= 2
    p = polyfit(curvature(m), a1(m), 1);
    xg = linspace(min(curvature(m)), max(curvature(m)), 200);
    yg = polyval(p, xg);
    plot(ax, xg, yg, '-', 'LineWidth', 2.2, 'Color', [0.85 0.33 0.10], ...
        'DisplayName', sprintf('Linear fit: a_1 = %.3g*curv + %.3g', p(1), p(2)));
end

xlabel(ax, 'curvature_{near peak}(T)');
ylabel(ax, 'a_1(T)');
title(ax, 'Scatter: a_1(T) vs curvature_{near peak}(T)');
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best');

xL = xlim(ax);
yL = ylim(ax);
textX = xL(1) + 0.03 * (xL(2) - xL(1));
textY = yL(2) - 0.06 * (yL(2) - yL(1));
text(ax, textX, textY, sprintf('Pearson r = %.4f\nSpearman rho = %.4f', pearsonR, spearmanRho), ...
    'VerticalAlignment', 'top', 'FontSize', 11, ...
    'BackgroundColor', [1 1 1], 'EdgeColor', [0.8 0.8 0.8], 'Margin', 6);

hold(ax, 'off');
figPaths = save_run_figure(fig, 'a1_vs_curvature_scatter', runDir);
close(fig);
end

function reportText = buildReportText(source, nPoints, pearsonR, spearmanRho, ...
    a1PeakTAbs, curvPeakTAbs, deltaPeakAbsK, corrPath, peakPath, figRaw, figNorm, figScatter)

strength = "weak-to-moderate";
if isfinite(pearsonR) && isfinite(spearmanRho) && abs(pearsonR) >= 0.7 && abs(spearmanRho) >= 0.7
    strength = "strong";
elseif isfinite(pearsonR) && isfinite(spearmanRho) && abs(pearsonR) >= 0.5 && abs(spearmanRho) >= 0.5
    strength = "moderate";
end

if strcmp(strength, "strong") && abs(deltaPeakAbsK) <= 4
    conclusion = "Yes, χ_amp(T) (legacy: a1) is consistent with a local ridge stiffness/curvature mode in this focused test.";
elseif strcmp(strength, "strong") || strcmp(strength, "moderate")
    conclusion = "Partially: there is nontrivial coupling, but peak timing mismatch limits a strict local-curvature-mode interpretation.";
else
    conclusion = "No clear support: χ_amp(T) (legacy: a1) is not well captured by local ridge curvature alone in this focused test.";
end

lines = strings(0, 1);
lines(end + 1) = "# Switching χ_amp(T) (legacy: a1) vs local ridge curvature test";
lines(end + 1) = "";
lines(end + 1) = "## Sources";
lines(end + 1) = "- a1 source run: `" + source.a1RunId + "`.";
lines(end + 1) = "- curvature source run: `" + source.curvatureRunId + "`.";
lines(end + 1) = "- a1 source file: `" + string(source.a1Path) + "`.";
lines(end + 1) = "- curvature source file: `" + string(source.curvaturePath) + "`.";
lines(end + 1) = "- Temperatures aligned by intersection only.";
lines(end + 1) = "";
lines(end + 1) = "## Results";
lines(end + 1) = sprintf('- Matched points: `%d`.', nPoints);
lines(end + 1) = sprintf('- Pearson corr(`χ_amp`, `curvature_near_peak`) = `%.6f`.', pearsonR);
lines(end + 1) = sprintf('- Spearman corr(`χ_amp`, `curvature_near_peak`) = `%.6f`.', spearmanRho);
lines(end + 1) = sprintf('- `T_peak(|χ_amp|) = %.2f K`.', a1PeakTAbs);
lines(end + 1) = sprintf('- `T_peak(|curvature_near_peak|) = %.2f K`.', curvPeakTAbs);
lines(end + 1) = sprintf('- `Delta T_peak = %.2f K`.', deltaPeakAbsK);
lines(end + 1) = "- Correlation strength class: **" + strength + "**.";
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
lines(end + 1) = "- " + conclusion;
lines(end + 1) = "- Note: `curvature_near_peak` sign convention reflects the stored quadratic coefficient convention; ridge sharpness proxy is `-curvature_near_peak`.";
lines(end + 1) = "";
lines(end + 1) = "## Artifacts";
lines(end + 1) = "- Correlations table: `" + string(corrPath) + "`.";
lines(end + 1) = "- Peak-alignment table: `" + string(peakPath) + "`.";
lines(end + 1) = "- Raw overlay figure: `" + string(figRaw.png) + "`.";
lines(end + 1) = "- Normalized overlay figure: `" + string(figNorm.png) + "`.";
lines(end + 1) = "- Scatter figure: `" + string(figScatter.png) + "`.";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_curvature_overlay](../figures/a1_vs_curvature_overlay.png)";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_curvature_overlay_normalized](../figures/a1_vs_curvature_overlay_normalized.png)";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_curvature_scatter](../figures/a1_vs_curvature_scatter.png)";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 2 (raw overlay), 4 (normalized overlay), 1 scatter series + fit line";
lines(end + 1) = "- legend vs colormap: legend used (`<= 6` curves)";
lines(end + 1) = "- colormap used: none";
lines(end + 1) = "- smoothing applied: none (stored observables only, no re-derived map processing)";
lines(end + 1) = "- justification: direct focused test of the local ridge-curvature hypothesis using stored artifacts only.";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end

files = { ...
    fullfile(runDir, 'tables', 'a1_vs_curvature_correlations.csv'), ...
    fullfile(runDir, 'tables', 'a1_vs_curvature_peak_alignment.csv'), ...
    fullfile(runDir, 'figures', 'a1_vs_curvature_overlay.png'), ...
    fullfile(runDir, 'figures', 'a1_vs_curvature_overlay_normalized.png'), ...
    fullfile(runDir, 'figures', 'a1_vs_curvature_scatter.png'), ...
    fullfile(runDir, 'reports', 'switching_a1_vs_curvature_test.md'), ...
    fullfile(runDir, 'run_manifest.json'), ...
    fullfile(runDir, 'config_snapshot.m'), ...
    fullfile(runDir, 'log.txt'), ...
    fullfile(runDir, 'run_notes.txt')};

existing = {};
for i = 1:numel(files)
    if exist(files{i}, 'file') == 2
        existing{end + 1} = files{i}; %#ok<AGROW>
    end
end

if ~isempty(existing)
    zip(zipPath, existing, runDir);
end
end

function [r, n] = safeCorr(x, y, corrType)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
n = nnz(mask);
if n < 3
    r = NaN;
    return;
end
try
    r = corr(x(mask), y(mask), 'Type', corrType, 'Rows', 'complete');
catch
    if strcmpi(corrType, 'Pearson')
        r = corr(x(mask), y(mask));
    else
        rx = simpleRank(x(mask));
        ry = simpleRank(y(mask));
        r = corr(rx, ry);
    end
end
end

function r = simpleRank(v)
v = v(:);
n = numel(v);
[sv, idx] = sort(v, 'ascend');
r = zeros(n, 1);
i = 1;
while i <= n
    j = i;
    while j < n && sv(j + 1) == sv(i)
        j = j + 1;
    end
    rankValue = (i + j) / 2;
    r(idx(i:j)) = rankValue;
    i = j + 1;
end
end

function [peakT, peakVal] = peakOf(T, y, useAbs)
peakT = NaN;
peakVal = NaN;
if isempty(T) || isempty(y)
    return;
end
if useAbs
    [~, idx] = max(abs(y));
    peakVal = y(idx);
else
    [peakVal, idx] = max(y);
end
if ~isempty(idx)
    peakT = T(idx);
end
end

function y = normalizeSigned(x)
x = x(:);
scale = max(abs(x), [], 'omitnan');
if ~isfinite(scale) || scale <= 0
    y = zeros(size(x));
else
    y = x ./ scale;
end
end

function y = normalize01(x)
x = x(:);
mn = min(x, [], 'omitnan');
mx = max(x, [], 'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn
    y = zeros(size(x));
else
    y = (x - mn) ./ (mx - mn);
end
end

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', char(string(textValue)));
end

function out = stampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
