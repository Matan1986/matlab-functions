function out = switching_a1_vs_dX_test(cfg)
% switching_a1_vs_dX_test
% Test whether dynamic shape-mode amplitude a1(T) tracks dX/dT where
% X(T) = I_peak(T) / (width(T) * S_peak(T)).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('a1:%s | switching:%s', ...
    char(source.a1RunName), char(source.switchRunName));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching a1-vs-dX test run directory:\n%s\n', runDir);
fprintf('a1 source run: %s\n', source.a1RunName);
fprintf('Switching source run: %s\n', source.switchRunName);
appendText(run.log_path, sprintf('[%s] switching a1-vs-dX test started\n', stampNow()));
appendText(run.log_path, sprintf('a1 source run: %s\n', char(source.a1RunName)));
appendText(run.log_path, sprintf('switching source run: %s\n', char(source.switchRunName)));

a1Data = loadA1Data(source.a1Path, cfg.a1ColumnName);
obsData = loadSwitchingObservables(source.switchPath);

[T, iA1, iObs] = intersect(a1Data.T_K, obsData.T_K, 'stable');
if isempty(T)
    error('No common temperatures between a1 source and switching observables source.');
end

a1 = double(a1Data.a1(iA1));
Ipeak = double(obsData.I_peak_mA(iObs));
width = double(obsData.width_mA(iObs));
Speak = double(obsData.S_peak(iObs));

maskRange = T >= cfg.temperatureMinK & T <= cfg.temperatureMaxK;
T = double(T(maskRange));
a1 = a1(maskRange);
Ipeak = Ipeak(maskRange);
width = width(maskRange);
Speak = Speak(maskRange);

if numel(T) < 5
    error('Need at least 5 temperature points after alignment/range filtering.');
end

a1 = fillByInterp(T, a1);
Ipeak = fillByInterp(T, Ipeak);
width = fillByInterp(T, width);
Speak = fillByInterp(T, Speak);

denom = width .* Speak;
denomSafe = max(denom, eps);
X = Ipeak ./ denomSafe;
X = fillByInterp(T, X);

[dX_raw, dX, X_smooth, derivativeMethod] = derivativeProfiles(T, X, cfg);

valid = isfinite(T) & isfinite(a1) & isfinite(dX);
if nnz(valid) < 3
    error('Insufficient finite points for correlation after preprocessing.');
end

pearsonSigned = safeCorr(a1(valid), dX(valid), 'Pearson');
spearmanSigned = safeCorr(a1(valid), dX(valid), 'Spearman');

[a1PeakTAbs, ~] = peakOf(T(valid), a1(valid), true);
[dXPeakTAbs, ~] = peakOf(T(valid), dX(valid), true);
deltaPeakAbsK = dXPeakTAbs - a1PeakTAbs;

a1To10K = abs(a1PeakTAbs - cfg.targetSectorK);
dXTo10K = abs(dXPeakTAbs - cfg.targetSectorK);

corrTbl = table( ...
    nnz(valid), ...
    pearsonSigned, ...
    spearmanSigned, ...
    a1PeakTAbs, ...
    dXPeakTAbs, ...
    deltaPeakAbsK, ...
    a1To10K, ...
    dXTo10K, ...
    cfg.sgolayPolynomialOrder, ...
    cfg.sgolayFrameLength, ...
    string(derivativeMethod), ...
    source.a1RunName, ...
    source.switchRunName, ...
    string(source.a1Path), ...
    string(source.switchPath), ...
    'VariableNames', { ...
    'n_points', ...
    'pearson_a1_vs_dX_dT', ...
    'spearman_a1_vs_dX_dT', ...
    'a1_peak_T_abs_K', ...
    'dX_dT_peak_T_abs_K', ...
    'delta_peak_T_abs_K', ...
    'a1_peak_to_10K_abs_K', ...
    'dX_dT_peak_to_10K_abs_K', ...
    'sgolay_polynomial_order', ...
    'sgolay_frame_length', ...
    'derivative_method', ...
    'a1_source_run', ...
    'switching_source_run', ...
    'a1_source_file', ...
    'switching_source_file'});

seriesTbl = table(T, a1, Ipeak, width, Speak, X, X_smooth, dX_raw, dX, ...
    normalizeSigned(a1), normalizeSigned(dX), normalize01(abs(a1)), normalize01(abs(dX)), ...
    'VariableNames', {'T_K', 'a1', 'I_peak_mA', 'width_mA', 'S_peak', 'X', ...
    'X_smoothed', 'dX_dT_raw', 'dX_dT_smoothed', ...
    'a1_norm_signed', 'dX_dT_norm_signed', 'a1_abs_norm', 'dX_dT_abs_norm'});

corrPath = save_run_table(corrTbl, 'a1_vs_dX_correlation.csv', runDir);
seriesPath = save_run_table(seriesTbl, 'a1_vs_dX_series.csv', runDir);
figPath = saveOverlayFigure(T, a1, dX, corrTbl, runDir, 'a1_vs_dX_dT');

reportText = buildReportText(source, cfg, corrTbl, figPath, corrPath, seriesPath);
reportPath = save_run_report(reportText, 'a1_vs_dX_report.md', runDir);

zipPath = buildReviewZip(runDir, 'switching_a1_vs_dX_test_bundle.zip');

appendText(run.notes_path, sprintf('a1 source run = %s\n', char(source.a1RunName)));
appendText(run.notes_path, sprintf('switching source run = %s\n', char(source.switchRunName)));
appendText(run.notes_path, sprintf('pearson(a1,dX/dT) = %.6f\n', pearsonSigned));
appendText(run.notes_path, sprintf('spearman(a1,dX/dT) = %.6f\n', spearmanSigned));
appendText(run.notes_path, sprintf('|peak_T(a1)| = %.2f K\n', a1PeakTAbs));
appendText(run.notes_path, sprintf('|peak_T(dX/dT)| = %.2f K\n', dXPeakTAbs));
appendText(run.notes_path, sprintf('delta_peak_T_abs = %.2f K\n', deltaPeakAbsK));
appendText(run.notes_path, sprintf('correlation table = %s\n', corrPath));
appendText(run.notes_path, sprintf('series table = %s\n', seriesPath));
appendText(run.notes_path, sprintf('overlay figure = %s\n', figPath.png));
appendText(run.notes_path, sprintf('report = %s\n', reportPath));
appendText(run.notes_path, sprintf('zip = %s\n', zipPath));

appendText(run.log_path, sprintf('[%s] switching a1-vs-dX test complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlation table: %s\n', corrPath));
appendText(run.log_path, sprintf('Series table: %s\n', seriesPath));
appendText(run.log_path, sprintf('Overlay figure: %s\n', figPath.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.metrics = struct( ...
    'pearson', pearsonSigned, ...
    'spearman', spearmanSigned, ...
    'a1_peak_T_abs_K', a1PeakTAbs, ...
    'dX_peak_T_abs_K', dXPeakTAbs, ...
    'delta_peak_T_abs_K', deltaPeakAbsK);
out.paths = struct( ...
    'correlation', string(corrPath), ...
    'series', string(seriesPath), ...
    'figure', string(figPath.png), ...
    'report', string(reportPath), ...
    'zip', string(zipPath));

fprintf('\n=== Switching a1-vs-dX test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson(a1,dX/dT): %.6f\n', pearsonSigned);
fprintf('Spearman(a1,dX/dT): %.6f\n', spearmanSigned);
fprintf('|peak_T(a1)|: %.2f K\n', a1PeakTAbs);
fprintf('|peak_T(dX/dT)|: %.2f K\n', dXPeakTAbs);
fprintf('Correlation table: %s\n', corrPath);
fprintf('Overlay figure: %s\n', figPath.png);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_a1_vs_dX_test');
cfg = setDefaultField(cfg, 'a1RunName', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefaultField(cfg, 'a1ColumnName', 'a_1');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'targetSectorK', 10);
cfg = setDefaultField(cfg, 'sgolayPolynomialOrder', 2);
cfg = setDefaultField(cfg, 'sgolayFrameLength', 5);
cfg = setDefaultField(cfg, 'movmeanWindow', 3);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.a1RunName = string(cfg.a1RunName);
source.switchRunName = string(cfg.switchRunName);

source.a1RunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.a1RunName));
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));

source.a1Path = fullfile(source.a1RunDir, 'tables', 'switching_dynamic_shape_mode_amplitudes.csv');
source.switchPath = fullfile(source.switchRunDir, 'tables', 'switching_effective_observables_table.csv');
if exist(source.switchPath, 'file') ~= 2
    source.switchPath = fullfile(source.switchRunDir, 'observables.csv');
end

if exist(source.a1RunDir, 'dir') ~= 7
    error('Required a1 source run directory not found: %s', source.a1RunDir);
end
if exist(source.switchRunDir, 'dir') ~= 7
    error('Required switching source run directory not found: %s', source.switchRunDir);
end
if exist(source.a1Path, 'file') ~= 2
    error('Required a1 source file not found: %s', source.a1Path);
end
if exist(source.switchPath, 'file') ~= 2
    error('No supported switching observables file found in: %s', source.switchRunDir);
end
end

function data = loadA1Data(pathValue, a1ColumnName)
tbl = readtable(pathValue);
if ~ismember('T_K', tbl.Properties.VariableNames)
    error('a1 table missing T_K column: %s', pathValue);
end
if ~ismember(a1ColumnName, tbl.Properties.VariableNames)
    error('a1 table missing requested column %s: %s', a1ColumnName, pathValue);
end
tbl = sortrows(tbl, 'T_K');

data = struct();
data.T_K = double(tbl.T_K(:));
data.a1 = double(tbl.(a1ColumnName)(:));
end

function data = loadSwitchingObservables(pathValue)
tbl = readtable(pathValue);
tbl = normalizeSwitchingTable(tbl);

required = {'T_K', 'I_peak_mA', 'width_mA', 'S_peak'};
for i = 1:numel(required)
    if ~ismember(required{i}, tbl.Properties.VariableNames)
        error('Switching table missing required column "%s": %s', required{i}, pathValue);
    end
end

tbl = sortrows(tbl, 'T_K');
data = struct();
data.T_K = double(tbl.T_K(:));
data.I_peak_mA = double(tbl.I_peak_mA(:));
data.width_mA = double(tbl.width_mA(:));
data.S_peak = double(tbl.S_peak(:));
end

function tblOut = normalizeSwitchingTable(tblIn)
tbl = tblIn;
vars = tbl.Properties.VariableNames;

if ismember('temperature', vars) && ismember('observable', vars) && ismember('value', vars)
    tblOut = longToWideSwitching(tbl);
    return;
end

if ismember('T', vars) && ~ismember('T_K', vars)
    tbl.T_K = tbl.T;
end
if ismember('I_peak', vars) && ~ismember('I_peak_mA', vars)
    tbl.I_peak_mA = tbl.I_peak;
end
if ismember('Ipeak_mA', vars) && ~ismember('I_peak_mA', vars)
    tbl.I_peak_mA = tbl.Ipeak_mA;
end
if ismember('width_I', vars) && ~ismember('width_mA', vars)
    tbl.width_mA = tbl.width_I;
end
if ismember('width_chosen_mA', vars) && ~ismember('width_mA', vars)
    tbl.width_mA = tbl.width_chosen_mA;
end

tblOut = tbl;
end

function tbl = longToWideSwitching(tblLong)
T = unique(double(tblLong.temperature(:)));
T = T(isfinite(T));
T = sort(T);
n = numel(T);

I_peak = NaN(n, 1);
width = NaN(n, 1);
S_peak = NaN(n, 1);
for i = 1:n
    t = T(i);
    rows = tblLong(double(tblLong.temperature) == t, :);
    obs = lower(string(rows.observable));
    vals = double(rows.value);
    I_peak(i) = firstValue(obs, vals, ["i_peak"]);
    width(i) = firstValue(obs, vals, ["width_i", "width"]);
    S_peak(i) = firstValue(obs, vals, ["s_peak"]);
end

tbl = table(T, I_peak, width, S_peak, ...
    'VariableNames', {'T_K', 'I_peak_mA', 'width_mA', 'S_peak'});
end

function v = firstValue(obsNames, values, candidates)
v = NaN;
for i = 1:numel(candidates)
    idx = find(obsNames == lower(string(candidates(i))), 1, 'first');
    if ~isempty(idx)
        v = values(idx);
        return;
    end
end
end

function y = fillByInterp(x, yIn)
y = yIn(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    return;
end
if any(~mask)
    y(~mask) = interp1(x(mask), y(mask), x(~mask), 'linear', 'extrap');
end
end

function [dRaw, dSmooth, ySmooth, methodText] = derivativeProfiles(x, y, cfg)
x = x(:);
y = y(:);
dRaw = gradient(y, x);
ySmooth = y;
methodText = "none";

n = numel(y);
frame = min(max(3, round(cfg.sgolayFrameLength)), n);
if mod(frame, 2) == 0
    frame = frame - 1;
end
poly = min(max(1, round(cfg.sgolayPolynomialOrder)), frame - 1);

if exist('sgolayfilt', 'file') == 2 && frame >= 3 && frame > poly
    try
        ySmooth = sgolayfilt(y, poly, frame);
        methodText = sprintf('sgolayfilt(p=%d,frame=%d)', poly, frame);
    catch
        ySmooth = y;
    end
end

if strcmp(methodText, "none")
    w = min(max(1, round(cfg.movmeanWindow)), n);
    if mod(w, 2) == 0 && w > 1
        w = w - 1;
    end
    if w > 1
        ySmooth = smoothdata(y, 'movmean', w, 'omitnan');
        methodText = sprintf('movmean(window=%d)', w);
    end
end

dSmooth = gradient(ySmooth, x);
end

function c = safeCorr(x, y, corrType)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 3
    c = NaN;
    return;
end
try
    c = corr(x(mask), y(mask), 'Type', corrType, 'Rows', 'complete');
catch
    c = corr(x(mask), y(mask));
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

function figOut = saveOverlayFigure(T, a1, dX, corrTbl, runDir, baseName)
fig = create_figure('Visible', 'off', 'Position', [2 2 13.5 9.6]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, T, normalizeSigned(a1), '-o', ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'DisplayName', 'a1(T) signed-norm');
plot(ax, T, normalizeSigned(dX), '-s', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'DisplayName', 'dX/dT signed-norm');
plot(ax, T, normalize01(abs(a1)), '--', ...
    'Color', [0.20 0.20 0.20], 'LineWidth', 2.0, ...
    'DisplayName', '|a1(T)| norm');
plot(ax, T, normalize01(abs(dX)), ':', ...
    'Color', [0.47 0.67 0.19], 'LineWidth', 2.2, ...
    'DisplayName', '|dX/dT| norm');
yline(ax, 0, '-', 'LineWidth', 1.0, 'Color', [0.70 0.70 0.70]);
hold(ax, 'off');

xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalized amplitude', 'FontSize', 14);
title(ax, sprintf('a1(T) vs dX/dT | Pearson=%.4f, Spearman=%.4f, \\DeltaT_{peak}=%.1f K', ...
    corrTbl.pearson_a1_vs_dX_dT(1), corrTbl.spearman_a1_vs_dX_dT(1), corrTbl.delta_peak_T_abs_K(1)), ...
    'FontSize', 12);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 10);

figOut = save_run_figure(fig, baseName, runDir);
close(fig);
end

function reportText = buildReportText(source, cfg, corrTbl, figPath, corrPath, seriesPath)
pearsonSigned = corrTbl.pearson_a1_vs_dX_dT(1);
spearmanSigned = corrTbl.spearman_a1_vs_dX_dT(1);
a1PeakT = corrTbl.a1_peak_T_abs_K(1);
dXPeakT = corrTbl.dX_dT_peak_T_abs_K(1);
deltaPeakK = corrTbl.delta_peak_T_abs_K(1);

lines = strings(0, 1);
lines(end + 1) = "# a1(T) vs dX/dT test report";
lines(end + 1) = "";
lines(end + 1) = "## Sources";
lines(end + 1) = "- a1 source run: `" + source.a1RunName + "`";
lines(end + 1) = "- switching observables source run: `" + source.switchRunName + "`";
lines(end + 1) = "- a1 source file: `" + string(source.a1Path) + "`";
lines(end + 1) = "- switching source file: `" + string(source.switchPath) + "`";
lines(end + 1) = "";
lines(end + 1) = "## Method";
lines(end + 1) = "- Temperature range: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`.";
lines(end + 1) = "- Geometric coordinate: `X(T) = I_peak(T) / (width(T) * S_peak(T))`.";
lines(end + 1) = "- Derivative method: `sgolayfilt` with polynomial order `" + string(cfg.sgolayPolynomialOrder) + "` and frame `" + string(cfg.sgolayFrameLength) + "`; derivative via `gradient`.";
lines(end + 1) = "";
lines(end + 1) = "## Results";
lines(end + 1) = "- Pearson correlation (`a1` vs `dX/dT`): `" + sprintf('%.6f', pearsonSigned) + "`.";
lines(end + 1) = "- Spearman correlation (`a1` vs `dX/dT`): `" + sprintf('%.6f', spearmanSigned) + "`.";
lines(end + 1) = "- Peak-temperature alignment (absolute peaks): `T_peak(|a1|) = " + sprintf('%.2f K', a1PeakT) + ...
    "`, `T_peak(|dX/dT|) = " + sprintf('%.2f K', dXPeakT) + ...
    "`, `delta = " + sprintf('%.2f K', deltaPeakK) + "`.";
lines(end + 1) = "- Distances to 10 K: `|T_peak(|a1|)-10| = " + sprintf('%.2f K', corrTbl.a1_peak_to_10K_abs_K(1)) + ...
    "`, `|T_peak(|dX/dT|)-10| = " + sprintf('%.2f K', corrTbl.dX_dT_peak_to_10K_abs_K(1)) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Artifacts";
lines(end + 1) = "- Correlation table: `" + string(corrPath) + "`";
lines(end + 1) = "- Aligned-series table: `" + string(seriesPath) + "`";
lines(end + 1) = "- Overlay figure: `" + string(figPath.png) + "`";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_dX_dT](../figures/a1_vs_dX_dT.png)";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 4";
lines(end + 1) = "- legend vs colormap: legend used (`<= 6` curves)";
lines(end + 1) = "- colormap used: none (line overlay)";
lines(end + 1) = "- smoothing applied: Savitzky-Golay (`p=2`, `frame=5`) before derivative";
lines(end + 1) = "- justification: signed and absolute normalized overlays expose both directional tracking and sector-localized susceptibility.";
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
    fullfile(runDir, 'figures', 'a1_vs_dX_dT.png'), ...
    fullfile(runDir, 'tables', 'a1_vs_dX_correlation.csv'), ...
    fullfile(runDir, 'reports', 'a1_vs_dX_report.md'), ...
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

function cfg = setDefaultField(cfg, name, value)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = value;
end
end
