function out = switching_width_relaxation_correlation(cfg)
% switching_width_relaxation_correlation
% Correlate the saved switching full-scaling width(T) against saved
% relaxation observables using existing run outputs only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('switch:%s | relax:%s', ...
    char(source.switchRunName), char(source.relaxRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Switching-width vs relaxation correlation run directory:\n%s\n', runDir);
fprintf('Switching source run: %s\n', source.switchRunName);
fprintf('Relaxation source run: %s\n', source.relaxRunName);

appendText(run.log_path, sprintf('[%s] switching-width vs relaxation correlation started\n', stampNow()));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));

switching = loadSwitchingWidthData(source.switchRunDir, cfg);
relax = loadRelaxationData(source.relaxRunDir);
aligned = buildAlignedData(switching, relax, cfg);
correlationTbl = buildCorrelationTable(aligned, cfg);
manifestTbl = buildManifestTable(source);

correlationPath = save_run_table(correlationTbl, 'correlation_results.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

figWidth = saveWidthVsTFigure(aligned, runDir, 'width_vs_T');
figA = saveRelaxationAVsTFigure(aligned, runDir, 'relaxation_A_vs_T');
figScatter = saveWidthVsAScatterFigure(aligned, correlationTbl, runDir, 'width_vs_A_scatter');
figOverlay = saveNormalizedOverlayFigure(aligned, runDir, 'normalized_shape_overlay');

reportText = buildReportText(source, aligned, correlationTbl, cfg);
reportPath = save_run_report(reportText, 'switching_width_relaxation_correlation.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_width_relaxation_correlation_bundle.zip');

bestPearson = correlationTbl(correlationTbl.abs_pearson_rank == min(correlationTbl.abs_pearson_rank, [], 'omitnan'), :);
bestSpearman = correlationTbl(correlationTbl.abs_spearman_rank == min(correlationTbl.abs_spearman_rank, [], 'omitnan'), :);
appendText(run.notes_path, sprintf('Switching width source = %s\n', char(source.switchRunName)));
appendText(run.notes_path, sprintf('Relaxation source = %s\n', char(source.relaxRunName)));
appendText(run.notes_path, sprintf('Temperature window = %.1f-%.1f K\n', min(aligned.T_K), max(aligned.T_K)));
appendText(run.notes_path, sprintf('Best |Pearson| match = %s (r = %.6g)\n', ...
    char(bestPearson.relaxation_key(1)), bestPearson.pearson_r(1)));
appendText(run.notes_path, sprintf('Best |Spearman| match = %s (rho = %.6g)\n', ...
    char(bestSpearman.relaxation_key(1)), bestSpearman.spearman_r(1)));

appendText(run.log_path, sprintf('[%s] switching-width vs relaxation correlation complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlation table: %s\n', correlationPath));
appendText(run.log_path, sprintf('Manifest table: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.aligned = aligned;
out.tables = struct('correlation', string(correlationPath), 'manifest', string(manifestPath));
out.figures = struct('width_vs_T', string(figWidth.png), 'A_vs_T', string(figA.png), ...
    'width_vs_A', string(figScatter.png), 'overlay', string(figOverlay.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Switching-width vs relaxation correlation complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Best |Pearson| match: %s (%.4f)\n', char(bestPearson.display_name(1)), bestPearson.pearson_r(1));
fprintf('Best |Spearman| match: %s (%.4f)\n', char(bestSpearman.display_name(1)), bestSpearman.spearman_r(1));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_width_relaxation_correlation');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));

requiredPaths = {
    source.switchRunDir, fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv');
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv')
    };

for i = 1:size(requiredPaths, 1)
    if exist(requiredPaths{i, 1}, 'dir') ~= 7
        error('Required source run directory not found: %s', requiredPaths{i, 1});
    end
    if exist(requiredPaths{i, 2}, 'file') ~= 2
        error('Required source file not found: %s', requiredPaths{i, 2});
    end
end
end

function switching = loadSwitchingWidthData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'switching_full_scaling_parameters.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
mask = mask & isfinite(tbl.width_chosen_mA);
if ~any(mask)
    error('No switching width data survived the requested temperature filter.');
end

tbl = sortrows(tbl(mask, :), 'T_K');

switching = struct();
switching.T = tbl.T_K(:);
switching.width = tbl.width_chosen_mA(:);
switching.widthFwhm = tbl.width_fwhm_mA(:);
switching.widthSigma = tbl.width_sigma_mA(:);
switching.widthMethod = string(tbl.width_method(:));
switching.Ipeak = tbl.Ipeak_mA(:);
switching.Speak = tbl.S_peak(:);
switching.leftHalf = tbl.left_half_current_mA(:);
switching.rightHalf = tbl.right_half_current_mA(:);
switching.nValidPoints = tbl.n_valid_points(:);
end

function relax = loadRelaxationData(runDir)
tempTbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
obsTbl = readtable(fullfile(runDir, 'tables', 'observables_relaxation.csv'));
tempTbl = sortrows(tempTbl, 'T');

relax = struct();
relax.T = tempTbl.T(:);
relax.A = tempTbl.A_T(:);
relax.R = tempTbl.R_T(:);
relax.beta = tempTbl.Relax_beta_T(:);
relax.tau = tempTbl.Relax_tau_T(:);
relax.sourcePeakT = obsTbl.Relax_T_peak(1);
relax.sourcePeakA = obsTbl.Relax_Amp_peak(1);
relax.globalBeta = obsTbl.Relax_beta_global(1);
relax.globalTau = obsTbl.Relax_tau_global(1);
end

function aligned = buildAlignedData(switching, relax, cfg)
T = switching.T(:);
aligned = struct();
aligned.T_K = T;
aligned.width_mA = switching.width(:);
aligned.width_fwhm_mA = switching.widthFwhm(:);
aligned.width_sigma_mA = switching.widthSigma(:);
aligned.width_method = switching.widthMethod(:);
aligned.I_peak_mA = switching.Ipeak(:);
aligned.S_peak = switching.Speak(:);
aligned.n_valid_points = switching.nValidPoints(:);
aligned.relax_source_peak_T_K = repmat(relax.sourcePeakT, numel(T), 1);

aligned.A_interp = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
aligned.R_interp = interp1(relax.T, relax.R, T, cfg.interpMethod, NaN);
aligned.Relax_beta_interp = interp1(relax.T, relax.beta, T, cfg.interpMethod, NaN);
aligned.Relax_tau_interp = interp1(relax.T, relax.tau, T, cfg.interpMethod, NaN);

aligned.width_norm = normalizeVector(aligned.width_mA);
aligned.A_norm = normalizeVector(aligned.A_interp);
aligned.R_norm = normalizeVector(aligned.R_interp);
aligned.Relax_beta_norm = normalizeVector(aligned.Relax_beta_interp);
aligned.Relax_tau_norm = normalizeVector(aligned.Relax_tau_interp);

aligned.A_peak_T_K = findPeakT(T, aligned.A_interp);
aligned.R_peak_T_K = findPeakT(T, aligned.R_interp);
aligned.Relax_beta_peak_T_K = findPeakT(T, aligned.Relax_beta_interp);
aligned.Relax_tau_peak_T_K = findPeakT(T, aligned.Relax_tau_interp);
aligned.width_peak_T_K = findPeakT(T, aligned.width_mA);
end

function correlationTbl = buildCorrelationTable(aligned, cfg)
defs = {
    'A_T', 'Relaxation A(T)', aligned.A_interp;
    'R_T', 'Relaxation R(T)', aligned.R_interp;
    'Relax_beta_T', 'Relaxation beta(T)', aligned.Relax_beta_interp;
    'Relax_tau_T', 'Relaxation tau(T)', aligned.Relax_tau_interp
    };

correlationTbl = table( ...
    strings(size(defs, 1), 1), ...
    strings(size(defs, 1), 1), ...
    repmat(string(cfg.interpMethod), size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    NaN(size(defs, 1), 1), ...
    'VariableNames', {'relaxation_key','display_name','interp_method','n_points', ...
    'pearson_r','spearman_r','width_peak_T_K','relax_peak_T_K','peak_delta_K', ...
    'width_at_relax_peak_mA','relax_value_at_width_peak'});

for i = 1:size(defs, 1)
    y = defs{i, 3};
    mask = isfinite(aligned.width_mA) & isfinite(y(:));
    correlationTbl.relaxation_key(i) = string(defs{i, 1});
    correlationTbl.display_name(i) = string(defs{i, 2});
    correlationTbl.n_points(i) = nnz(mask);
    correlationTbl.pearson_r(i) = corrSafe(aligned.width_mA(mask), y(mask));
    correlationTbl.spearman_r(i) = spearmanSafe(aligned.width_mA(mask), y(mask));
    correlationTbl.width_peak_T_K(i) = aligned.width_peak_T_K;
    correlationTbl.relax_peak_T_K(i) = findPeakT(aligned.T_K, y);
    correlationTbl.peak_delta_K(i) = correlationTbl.width_peak_T_K(i) - correlationTbl.relax_peak_T_K(i);
    correlationTbl.width_at_relax_peak_mA(i) = interp1(aligned.T_K, aligned.width_mA, correlationTbl.relax_peak_T_K(i), 'linear', NaN);
    correlationTbl.relax_value_at_width_peak(i) = interp1(aligned.T_K, y, correlationTbl.width_peak_T_K(i), 'linear', NaN);
end

correlationTbl.abs_pearson_r = abs(correlationTbl.pearson_r);
correlationTbl.abs_spearman_r = abs(correlationTbl.spearman_r);
correlationTbl.abs_pearson_rank = tiedRankDescending(correlationTbl.abs_pearson_r);
correlationTbl.abs_spearman_rank = tiedRankDescending(correlationTbl.abs_spearman_r);
correlationTbl = movevars(correlationTbl, {'abs_pearson_rank','abs_spearman_rank'}, 'After', 'spearman_r');
end

function manifestTbl = buildManifestTable(source)
experiment = string({'switching'; 'relaxation'; 'relaxation'});
sourceRun = [source.switchRunName; source.relaxRunName; source.relaxRunName];
sourceFile = string({ ...
    fullfile(char(source.switchRunDir), 'tables', 'switching_full_scaling_parameters.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'observables_relaxation.csv')});
role = string({'full-scaling switching width table'; 'relaxation temperature observables'; 'relaxation peak metadata'});
manifestTbl = table(experiment, sourceRun, sourceFile, role, ...
    'VariableNames', {'experiment','source_run','source_file','role'});
end

function figPaths = saveWidthVsTFigure(aligned, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 16.5, 9.5);
ax = axes(fh);
plot(ax, aligned.T_K, aligned.width_mA, '-o', ...
    'Color', [0.07 0.24 0.52], 'LineWidth', 2.4, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.07 0.24 0.52]);
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'width(T) (mA)');
title(ax, 'Switching width from full-scaling collapse');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveRelaxationAVsTFigure(aligned, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 16.5, 9.5);
ax = axes(fh);
plot(ax, aligned.T_K, aligned.A_interp, '-s', ...
    'Color', [0.75 0.18 0.12], 'LineWidth', 2.4, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.75 0.18 0.12]);
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'A(T)');
title(ax, 'Relaxation A(T) interpolated onto switching temperatures');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveWidthVsAScatterFigure(aligned, correlationTbl, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 13.5, 10.5);
ax = axes(fh);
hold(ax, 'on');
mask = isfinite(aligned.A_interp) & isfinite(aligned.width_mA) & isfinite(aligned.T_K);
scatter(ax, aligned.A_interp(mask), aligned.width_mA(mask), 80, aligned.T_K(mask), 'filled', ...
    'MarkerEdgeColor', [0.20 0.20 0.20], 'LineWidth', 0.6);
if nnz(mask) >= 2
    coeffs = polyfit(aligned.A_interp(mask), aligned.width_mA(mask), 1);
    xfit = linspace(min(aligned.A_interp(mask)), max(aligned.A_interp(mask)), 200);
    yfit = polyval(coeffs, xfit);
    plot(ax, xfit, yfit, '--', 'Color', [0.10 0.10 0.10], 'LineWidth', 2.0, 'DisplayName', 'Linear fit');
end
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Relaxation A(T)');
ylabel(ax, 'Switching width(T) (mA)');
title(ax, 'Switching width(T) vs Relaxation A(T)');
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
cb.LineWidth = 1.0;
cb.FontName = 'Helvetica';
cb.FontSize = 12;
colormap(ax, parula(256));
setAxisStyle(ax);
row = correlationTbl(correlationTbl.relaxation_key == "A_T", :);
if ~isempty(row)
    txt = sprintf('Pearson = %.3f\\newlineSpearman = %.3f', row.pearson_r(1), row.spearman_r(1));
    text(ax, 0.05, 0.95, txt, 'Units', 'normalized', ...
        'FontName', 'Helvetica', 'FontSize', 12, 'BackgroundColor', [1 1 1], ...
        'Margin', 6, 'VerticalAlignment', 'top');
end
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveNormalizedOverlayFigure(aligned, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.5, 10.0);
ax = axes(fh);
colors = lines(4);
hold(ax, 'on');
plot(ax, aligned.T_K, aligned.width_norm, '-o', 'Color', [0.05 0.05 0.05], 'LineWidth', 2.8, ...
    'MarkerSize', 5, 'MarkerFaceColor', [0.05 0.05 0.05], 'DisplayName', 'width(T) / max');
plot(ax, aligned.T_K, aligned.A_norm, '-s', 'Color', colors(1, :), 'LineWidth', 2.2, ...
    'MarkerSize', 5, 'MarkerFaceColor', colors(1, :), 'DisplayName', 'A(T) / max');
plot(ax, aligned.T_K, aligned.R_norm, '-^', 'Color', colors(2, :), 'LineWidth', 2.2, ...
    'MarkerSize', 5, 'MarkerFaceColor', colors(2, :), 'DisplayName', 'R(T) / max');
plot(ax, aligned.T_K, aligned.Relax_beta_norm, '-d', 'Color', colors(3, :), 'LineWidth', 2.2, ...
    'MarkerSize', 5, 'MarkerFaceColor', colors(3, :), 'DisplayName', 'beta(T) / max');
plot(ax, aligned.T_K, aligned.Relax_tau_norm, '-v', 'Color', colors(4, :), 'LineWidth', 2.2, ...
    'MarkerSize', 5, 'MarkerFaceColor', colors(4, :), 'DisplayName', 'tau(T) / max');
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized magnitude');
title(ax, 'Shape comparison on the switching temperature grid');
legend(ax, 'Location', 'bestoutside');
xlim(ax, [min(aligned.T_K) max(aligned.T_K)]);
ylim(ax, [0 1.08]);
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReportText(source, aligned, correlationTbl, cfg)
rowA = correlationTbl(correlationTbl.relaxation_key == "A_T", :);
if isempty(rowA)
    error('A(T) correlation row missing from correlation table.');
end

lines = strings(0, 1);
lines(end + 1) = "# Switching Width vs Relaxation Correlation";
lines(end + 1) = "";
lines(end + 1) = "## Repository-state summary";
lines(end + 1) = "- Existing related run `run_2026_03_12_004907_switching_relaxation_observable_comparis` already compared the older canonical switching `width_I(T)` from the alignment audit against relaxation `A(T)` and reported Pearson `-0.5255` and Spearman `-0.6296`.";
lines(end + 1) = "- Existing related run `run_2026_03_12_081243_relaxation_switching_observable_scan` repeated that older `width_I(T)` comparison in a consolidated scan and reported Pearson(full) `-0.525` and Spearman(full) `-0.630`.";
lines(end + 1) = sprintf('- No existing cross-experiment run was found that reused `%s` as an input source, so the exact full-scaling width(T) analysis did not already exist.', source.switchRunName);
lines(end + 1) = "- This run therefore evaluates the newer full-scaling width(T) against saved relaxation observables without recomputing either experiment.";
lines(end + 1) = "";
lines(end + 1) = "## Input runs";
lines(end + 1) = sprintf('- Switching width source: `%s`.', source.switchRunName);
lines(end + 1) = sprintf('- Relaxation observable source: `%s`.', source.relaxRunName);
lines(end + 1) = "";
lines(end + 1) = "## Observables compared";
lines(end + 1) = "- Switching: `width(T) = width_chosen_mA` from `switching_full_scaling_parameters.csv`.";
lines(end + 1) = sprintf('- Temperature filter inherited from the switching full-scaling run: `%.0f-%.0f K`.', min(aligned.T_K), max(aligned.T_K));
lines(end + 1) = sprintf('- Width method stored in the source table: `%s` for all kept temperatures.', char(join(unique(aligned.width_method), ', ')));
lines(end + 1) = sprintf('- Relaxation observables interpolated onto the switching temperature grid using `%s`: `A(T)`, `R(T)`, `beta(T)`, `tau(T)`.', cfg.interpMethod);
lines(end + 1) = "";
lines(end + 1) = "## Correlation results";
for i = 1:height(correlationTbl)
    lines(end + 1) = sprintf('- `%s`: Pearson = %.4f, Spearman = %.4f, width peak = %.1f K, relaxation peak = %.1f K, peak offset = %+0.1f K.', ...
        correlationTbl.display_name(i), correlationTbl.pearson_r(i), correlationTbl.spearman_r(i), ...
        correlationTbl.width_peak_T_K(i), correlationTbl.relax_peak_T_K(i), correlationTbl.peak_delta_K(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Interpretation notes";
if rowA.pearson_r(1) < 0 && rowA.spearman_r(1) < 0
    lines(end + 1) = sprintf('- `width(T)` and relaxation `A(T)` are anti-correlated on the common `%.0f-%.0f K` grid, so the newer full-scaling width does not behave like a positive tracker of the relaxation activity envelope.', min(aligned.T_K), max(aligned.T_K));
else
    lines(end + 1) = sprintf('- `width(T)` and relaxation `A(T)` are not anti-correlated in both metrics on the common `%.0f-%.0f K` grid.', min(aligned.T_K), max(aligned.T_K));
end
lines(end + 1) = sprintf('- The width curve peaks at `%.1f K`, while the interpolated `A(T)` curve peaks at `%.1f K` on the switching grid.', aligned.width_peak_T_K, aligned.A_peak_T_K);
lines(end + 1) = "- The normalized overlay should be read as a shape comparison only; each curve is max-normalized independently for visual comparison.";
lines(end + 1) = "- No switching maps, relaxation maps, or collapse fits were recomputed. This run only reused saved tables from immutable source runs.";

reportText = strjoin(lines, newline);
end

function tPeak = findPeakT(T, y)
tPeak = NaN;
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    return;
end
[~, idx] = max(y(mask));
Tvalid = T(mask);
tPeak = Tvalid(idx);
end

function yNorm = normalizeVector(y)
y = y(:);
yNorm = NaN(size(y));
mask = isfinite(y);
if ~any(mask)
    return;
end
maxVal = max(y(mask), [], 'omitnan');
if isfinite(maxVal) && maxVal ~= 0
    yNorm(mask) = y(mask) ./ maxVal;
end
end

function c = corrSafe(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
c = NaN;
if nnz(mask) < 3
    return;
end
cc = corrcoef(x(mask), y(mask));
if numel(cc) >= 4
    c = cc(1, 2);
end
end

function rho = spearmanSafe(x, y)
rho = corrSafe(tiedRank(x), tiedRank(y));
end

function r = tiedRank(x)
x = x(:);
r = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end
xs = x(valid);
[xsSorted, order] = sort(xs);
ranks = zeros(size(xsSorted));
ii = 1;
while ii <= numel(xsSorted)
    jj = ii;
    while jj < numel(xsSorted) && xsSorted(jj + 1) == xsSorted(ii)
        jj = jj + 1;
    end
    ranks(ii:jj) = mean(ii:jj);
    ii = jj + 1;
end
tmp = zeros(size(xsSorted));
tmp(order) = ranks;
r(valid) = tmp;
end

function rankVals = tiedRankDescending(x)
rankVals = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end
[~, order] = sort(x(valid), 'descend');
xs = x(valid);
xs = xs(order);
ranked = zeros(size(xs));
ii = 1;
while ii <= numel(xs)
    jj = ii;
    while jj < numel(xs) && xs(jj + 1) == xs(ii)
        jj = jj + 1;
    end
    ranked(ii:jj) = mean(ii:jj);
    ii = jj + 1;
end
tmp = zeros(size(xs));
tmp(order) = ranked;
rankVals(valid) = tmp;
end

function setFigureGeometry(fig, widthCm, heightCm)
set(fig, 'Units', 'centimeters', ...
    'Position', [2 2 widthCm heightCm], ...
    'PaperUnits', 'centimeters', ...
    'PaperPosition', [0 0 widthCm heightCm], ...
    'PaperSize', [widthCm heightCm], ...
    'Color', 'w');
end

function setAxisStyle(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.1, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top');
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
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
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



