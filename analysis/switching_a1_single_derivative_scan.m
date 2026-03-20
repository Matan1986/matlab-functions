function out = switching_a1_single_derivative_scan(cfg)
% switching_a1_single_derivative_scan
% Compare a1(T) against single geometric derivatives from canonical
% switching observables:
% dI_peak/dT, dwidth/dT, dS_peak/dT, dX/dT.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('a1:%s | switching:%s', ...
    char(source.a1RunName), char(source.switchRunName));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching a1 single-derivative scan run directory:\n%s\n', runDir);
fprintf('a1 source run: %s\n', source.a1RunName);
fprintf('Switching source run: %s\n', source.switchRunName);
appendText(run.log_path, sprintf('[%s] switching a1 single-derivative scan started\n', stampNow()));
appendText(run.log_path, sprintf('a1 source run: %s\n', char(source.a1RunName)));
appendText(run.log_path, sprintf('Switching source run: %s\n', char(source.switchRunName)));

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
X = double(obsData.X(iObs));

maskRange = T >= cfg.temperatureMinK & T <= cfg.temperatureMaxK;
T = double(T(maskRange));
a1 = a1(maskRange);
Ipeak = Ipeak(maskRange);
width = width(maskRange);
Speak = Speak(maskRange);
X = X(maskRange);

if numel(T) < 5
    error('Need at least 5 temperature points after alignment/range filtering.');
end

a1 = fillByInterp(T, a1);
Ipeak = fillByInterp(T, Ipeak);
width = fillByInterp(T, width);
Speak = fillByInterp(T, Speak);
X = fillByInterp(T, X);

[dI_raw, dI, I_smooth, methodI] = derivativeProfiles(T, Ipeak, cfg);
[dw_raw, dw, w_smooth, methodW] = derivativeProfiles(T, width, cfg);
[dS_raw, dS, S_smooth, methodS] = derivativeProfiles(T, Speak, cfg);
[dX_raw, dX, X_smooth, methodX] = derivativeProfiles(T, X, cfg);

derivativeNames = {'dI_peak_dT', 'dwidth_dT', 'dS_peak_dT', 'dX_dT'};
axisNames = {'ridge_motion', 'width_reshaping', 'amplitude_change', 'dynamical_coordinate_derivative'};
derivativeValues = {dI, dw, dS, dX};
methods = {methodI, methodW, methodS, methodX};

nDeriv = numel(derivativeNames);
rows = cell(nDeriv, 18);
for k = 1:nDeriv
    d = derivativeValues{k}(:);
    valid = isfinite(T) & isfinite(a1) & isfinite(d);
    n = nnz(valid);

    pearsonSigned = safeCorr(a1(valid), d(valid), 'Pearson');
    spearmanSigned = safeCorr(a1(valid), d(valid), 'Spearman');
    pearsonAbs = safeCorr(abs(a1(valid)), abs(d(valid)), 'Pearson');
    spearmanAbs = safeCorr(abs(a1(valid)), abs(d(valid)), 'Spearman');

    [a1PeakTSigned, ~] = peakOf(T(valid), a1(valid), false);
    [dPeakTSigned, ~] = peakOf(T(valid), d(valid), false);
    [a1PeakTAbs, ~] = peakOf(T(valid), a1(valid), true);
    [dPeakTAbs, ~] = peakOf(T(valid), d(valid), true);

    scoreSigned = mean(abs([pearsonSigned, spearmanSigned]), 'omitnan');
    scoreAbs = mean(abs([pearsonAbs, spearmanAbs]), 'omitnan');
    scoreOverall = max(scoreSigned, scoreAbs);

    rows(k, :) = { ...
        derivativeNames{k}, axisNames{k}, n, ...
        pearsonSigned, spearmanSigned, pearsonAbs, spearmanAbs, ...
        scoreSigned, scoreAbs, scoreOverall, ...
        a1PeakTSigned, dPeakTSigned, dPeakTSigned - a1PeakTSigned, ...
        a1PeakTAbs, dPeakTAbs, dPeakTAbs - a1PeakTAbs, ...
        methods{k}, source.switchRunName};
end

scanTbl = cell2table(rows, 'VariableNames', { ...
    'derivative', 'interpretation_axis', 'n_points', ...
    'pearson_signed', 'spearman_signed', 'pearson_abs', 'spearman_abs', ...
    'score_signed', 'score_abs', 'score_overall', ...
    'a1_peak_T_signed_K', 'derivative_peak_T_signed_K', 'delta_peak_T_signed_K', ...
    'a1_peak_T_abs_K', 'derivative_peak_T_abs_K', 'delta_peak_T_abs_K', ...
    'smoothing_method', 'switching_source_run'});

scanTbl = sortrows(scanTbl, {'score_overall', 'score_abs', 'score_signed'}, ...
    {'descend', 'descend', 'descend'});

seriesTbl = table(T, a1, normalizeSigned(a1), abs(a1), normalize01(abs(a1)), ...
    Ipeak, I_smooth, dI_raw, dI, width, w_smooth, dw_raw, dw, ...
    Speak, S_smooth, dS_raw, dS, X, X_smooth, dX_raw, dX, ...
    'VariableNames', {'T_K', 'a1', 'a1_norm_signed', 'a1_abs', 'a1_abs_norm', ...
    'I_peak_mA', 'I_peak_smoothed_mA', 'dI_peak_dT_raw', 'dI_peak_dT_smoothed', ...
    'width_mA', 'width_smoothed_mA', 'dwidth_dT_raw', 'dwidth_dT_smoothed', ...
    'S_peak', 'S_peak_smoothed', 'dS_peak_dT_raw', 'dS_peak_dT_smoothed', ...
    'X', 'X_smoothed', 'dX_dT_raw', 'dX_dT_smoothed'});

sourceManifestTbl = table( ...
    string({'a1_dynamic_shape_mode'; 'switching_effective_observables'}), ...
    [source.a1RunName; source.switchRunName], ...
    string({source.a1Path; source.switchPath}), ...
    string({'a1(T) from dynamic shape mode'; 'I_peak,width,S_peak,X from canonical switching run'}), ...
    'VariableNames', {'source_role', 'source_run', 'source_file', 'role_note'});

scanPath = save_run_table(scanTbl, 'a1_single_derivative_scan.csv', runDir);
seriesPath = save_run_table(seriesTbl, 'a1_geometric_derivatives_vs_T.csv', runDir);
sourcePath = save_run_table(sourceManifestTbl, 'a1_single_derivative_sources.csv', runDir);

figPath = saveOverlayFigure(T, a1, derivativeNames, derivativeValues, scanTbl, runDir, ...
    'a1_vs_geometric_derivatives');

rankingsText = buildRankingReport(source, cfg, scanTbl, scanPath, seriesPath, sourcePath, figPath);
rankingsPath = save_run_report(rankingsText, 'a1_derivative_rankings.md', runDir);

zipPath = buildReviewZip(runDir, 'switching_a1_single_derivative_scan_bundle.zip');

topDeriv = string(scanTbl.derivative(1));
topAxis = string(scanTbl.interpretation_axis(1));
topScore = scanTbl.score_overall(1);

appendText(run.notes_path, sprintf('a1 source run = %s\n', char(source.a1RunName)));
appendText(run.notes_path, sprintf('switching source run = %s\n', char(source.switchRunName)));
appendText(run.notes_path, sprintf('top derivative = %s (%s)\n', topDeriv, topAxis));
appendText(run.notes_path, sprintf('top score_overall = %.4f\n', topScore));
appendText(run.notes_path, sprintf('scan table = %s\n', scanPath));
appendText(run.notes_path, sprintf('overlay figure = %s\n', figPath.png));
appendText(run.notes_path, sprintf('rankings report = %s\n', rankingsPath));

appendText(run.log_path, sprintf('[%s] switching a1 single-derivative scan complete\n', stampNow()));
appendText(run.log_path, sprintf('Scan table: %s\n', scanPath));
appendText(run.log_path, sprintf('Series table: %s\n', seriesPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', sourcePath));
appendText(run.log_path, sprintf('Overlay figure: %s\n', figPath.png));
appendText(run.log_path, sprintf('Rankings report: %s\n', rankingsPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.top = struct('derivative', topDeriv, 'axis', topAxis, 'score_overall', topScore);
out.paths = struct( ...
    'scan', string(scanPath), ...
    'series', string(seriesPath), ...
    'sourceManifest', string(sourcePath), ...
    'figure', string(figPath.png), ...
    'rankings', string(rankingsPath), ...
    'zip', string(zipPath));

fprintf('\n=== Switching a1 single-derivative scan complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Top derivative: %s (%s)\n', topDeriv, topAxis);
fprintf('Top score_overall: %.4f\n', topScore);
fprintf('Scan table: %s\n', scanPath);
fprintf('Overlay figure: %s\n', figPath.png);
fprintf('Rankings report: %s\n', rankingsPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_a1_single_derivative_scan');
cfg = setDefaultField(cfg, 'a1RunName', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefaultField(cfg, 'a1ColumnName', 'a_1');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
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
    fallbackPath = fullfile(source.switchRunDir, 'observables.csv');
    if exist(fallbackPath, 'file') == 2
        source.switchPath = fallbackPath;
    else
        error('Required switching observables file not found: %s', source.switchPath);
    end
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
if ~ismember('T_K', tbl.Properties.VariableNames)
    error('Switching table missing T_K column: %s', pathValue);
end
tbl = sortrows(tbl, 'T_K');

iPeakCol = firstPresent(tbl, {'I_peak_mA', 'Ipeak_mA'});
widthCol = firstPresent(tbl, {'width_mA', 'width_chosen_mA'});
sPeakCol = firstPresent(tbl, {'S_peak'});

if isempty(iPeakCol) || isempty(widthCol) || isempty(sPeakCol)
    error('Switching table missing one of I_peak, width, S_peak columns: %s', pathValue);
end

if ismember('X', tbl.Properties.VariableNames)
    X = double(tbl.X(:));
else
    X = double(tbl.(iPeakCol)(:)) ./ ...
        max(double(tbl.(widthCol)(:)) .* double(tbl.(sPeakCol)(:)), eps);
end

data = struct();
data.T_K = double(tbl.T_K(:));
data.I_peak_mA = double(tbl.(iPeakCol)(:));
data.width_mA = double(tbl.(widthCol)(:));
data.S_peak = double(tbl.(sPeakCol)(:));
data.X = X;
end

function name = firstPresent(tbl, candidates)
name = '';
for i = 1:numel(candidates)
    if ismember(candidates{i}, tbl.Properties.VariableNames)
        name = candidates{i};
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

function figOut = saveOverlayFigure(T, a1, derivativeNames, derivativeValues, scanTbl, runDir, baseName)
fig = figure('Color', 'w', 'Visible', 'off');
set(fig, 'Units', 'centimeters', 'Position', [2 2 16.0 11.8], ...
    'PaperUnits', 'centimeters', 'PaperPosition', [0 0 16.0 11.8], ...
    'PaperSize', [16.0 11.8]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

a1SignedNorm = normalizeSigned(a1);
a1AbsNorm = normalize01(abs(a1));

for i = 1:numel(derivativeNames)
    ax = nexttile(tl, i);
    hold(ax, 'on');

    row = scanTbl(strcmp(scanTbl.derivative, derivativeNames{i}), :);
    d = derivativeValues{i}(:);
    dSignedNorm = normalizeSigned(d);
    dAbsNorm = normalize01(abs(d));

    p1 = plot(ax, T, a1SignedNorm, '-o', 'LineWidth', 2.1, 'MarkerSize', 5, ...
        'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
        'DisplayName', 'a1(T) signed-norm');
    p2 = plot(ax, T, dSignedNorm, '-s', 'LineWidth', 2.1, 'MarkerSize', 5, ...
        'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
        'DisplayName', sprintf('%s signed-norm', derivativeNames{i}));
    p3 = plot(ax, T, a1AbsNorm, '--', 'LineWidth', 1.8, ...
        'Color', [0.20 0.20 0.20], 'DisplayName', '|a1(T)| norm');
    p4 = plot(ax, T, dAbsNorm, ':', 'LineWidth', 2.0, ...
        'Color', [0.47 0.67 0.19], 'DisplayName', sprintf('|%s| norm', derivativeNames{i}));

    yline(ax, 0, '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 0.8);
    hold(ax, 'off');

    xlabel(ax, 'Temperature (K)');
    ylabel(ax, 'Normalized amplitude');
    title(ax, sprintf('%s | r=%.3f, \\rho=%.3f', derivativeNames{i}, ...
        row.pearson_signed(1), row.spearman_signed(1)));
    set(ax, 'FontName', 'Helvetica', 'FontSize', 10, 'LineWidth', 1.0, ...
        'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
    grid(ax, 'on');

    if i == 1
        legend(ax, [p1 p2 p3 p4], 'Location', 'best', 'FontSize', 8);
    end
end

title(tl, 'a1(T) versus single geometric derivatives (signed + absolute overlays)');
figOut = save_run_figure(fig, baseName, runDir);
close(fig);
end

function reportText = buildRankingReport(source, cfg, scanTbl, scanPath, seriesPath, sourcePath, figPath)
top = scanTbl(1, :);
[~, iSigned] = max(scanTbl.score_signed);
[~, iAbs] = max(scanTbl.score_abs);
topSigned = scanTbl(iSigned, :);
topAbs = scanTbl(iAbs, :);

lines = strings(0, 1);
lines(end + 1) = "# a1 vs geometric derivatives ranking";
lines(end + 1) = "";
lines(end + 1) = "## Sources";
lines(end + 1) = "- a1 source run: `" + source.a1RunName + "`";
lines(end + 1) = "- switching source run: `" + source.switchRunName + "`";
lines(end + 1) = "- temperature range analyzed: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`";
lines(end + 1) = "- source manifest: `" + string(sourcePath) + "`";
lines(end + 1) = "";
lines(end + 1) = "## Scan outputs";
lines(end + 1) = "- ranking table: `" + string(scanPath) + "`";
lines(end + 1) = "- aligned series and derivatives: `" + string(seriesPath) + "`";
lines(end + 1) = "- normalized overlay figure: `" + string(figPath.png) + "`";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_derivatives](../figures/a1_vs_geometric_derivatives.png)";
lines(end + 1) = "";
lines(end + 1) = "## Best matches";
lines(end + 1) = "- overall best (max of signed/abs scores): `" + string(top.derivative) + "` (" + string(top.interpretation_axis) + ...
    "), score = `" + sprintf('%.4f', top.score_overall) + "`.";
lines(end + 1) = "- signed best: `" + string(topSigned.derivative) + "`, score_signed = `" + ...
    sprintf('%.4f', topSigned.score_signed) + "`, Pearson = `" + sprintf('%.4f', topSigned.pearson_signed) + ...
    "`, Spearman = `" + sprintf('%.4f', topSigned.spearman_signed) + "`.";
lines(end + 1) = "- absolute best: `" + string(topAbs.derivative) + "`, score_abs = `" + ...
    sprintf('%.4f', topAbs.score_abs) + "`, Pearson_abs = `" + sprintf('%.4f', topAbs.pearson_abs) + ...
    "`, Spearman_abs = `" + sprintf('%.4f', topAbs.spearman_abs) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Ranking details";
for i = 1:height(scanTbl)
    r = scanTbl(i, :);
    lines(end + 1) = sprintf('%d. `%s` (%s): overall=%.4f, signed=[r=%.4f, rho=%.4f], abs=[r=%.4f, rho=%.4f], peak-delta-signed=%.2f K, peak-delta-abs=%.2f K.', ...
        i, string(r.derivative), string(r.interpretation_axis), ...
        r.score_overall, r.pearson_signed, r.spearman_signed, ...
        r.pearson_abs, r.spearman_abs, ...
        r.delta_peak_T_signed_K, r.delta_peak_T_abs_K);
end
lines(end + 1) = "";
lines(end + 1) = "## Interpretation mapping";
lines(end + 1) = "- `dI_peak/dT`: ridge motion";
lines(end + 1) = "- `dwidth/dT`: width reshaping";
lines(end + 1) = "- `dS_peak/dT`: amplitude change";
lines(end + 1) = "- `dX/dT`: dynamical-coordinate derivative";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
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

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
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
