function out = switching_a1_vs_logdS_test(cfg)
% switching_a1_vs_logdS_test
% Test whether dynamic shape-mode amplitude a1(T) tracks d/dT ln(S_peak(T)).

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

fprintf('Switching a1-vs-logdS test run directory:\n%s\n', runDir);
fprintf('a1 source run: %s\n', source.a1RunName);
fprintf('Switching source run: %s\n', source.switchRunName);
appendText(run.log_path, sprintf('[%s] switching a1-vs-logdS test started\n', stampNow()));
appendText(run.log_path, sprintf('a1 source run: %s\n', char(source.a1RunName)));
appendText(run.log_path, sprintf('switching source run: %s\n', char(source.switchRunName)));

a1Data = loadA1Data(source.a1Path, cfg.a1ColumnName);
obsData = loadSwitchingObservables(source.switchPath);

[T, iA1, iObs] = intersect(a1Data.T_K, obsData.T_K, 'stable');
if isempty(T)
    error('No common temperatures between a1 source and switching observables source.');
end

a1 = double(a1Data.a1(iA1));
Speak = double(obsData.S_peak(iObs));

maskRange = T >= cfg.temperatureMinK & T <= cfg.temperatureMaxK;
T = double(T(maskRange));
a1 = a1(maskRange);
Speak = Speak(maskRange);

if numel(T) < 5
    error('Need at least 5 temperature points after alignment/range filtering.');
end

a1 = fillByInterp(T, a1);
Speak = fillByInterp(T, Speak);
SpeakSafe = max(Speak, eps);

logS = log(SpeakSafe);
[dlogS_raw, dlogS, logS_smooth, derivativeMethod] = derivativeProfiles(T, logS, cfg);
[dS_raw, dS, S_smooth, derivativeMethodS] = derivativeProfiles(T, SpeakSafe, cfg);

valid = isfinite(T) & isfinite(a1) & isfinite(dlogS) & isfinite(dS) & isfinite(logS);
if nnz(valid) < 3
    error('Insufficient finite points for correlation after preprocessing.');
end

Tv = T(valid);
a1v = a1(valid);
dlogSv = dlogS(valid);
dSv = dS(valid);
logSv = logS(valid);
Speakv = SpeakSafe(valid);

pearsonLog = safeCorr(a1v, dlogSv, 'Pearson');
spearmanLog = safeCorr(a1v, dlogSv, 'Spearman');
pearsonDS = safeCorr(a1v, dSv, 'Pearson');
spearmanDS = safeCorr(a1v, dSv, 'Spearman');

[a1PeakTAbs, ~] = peakOf(Tv, a1v, true);
[dlogSPeakTAbs, ~] = peakOf(Tv, dlogSv, true);
deltaPeakAbsK = dlogSPeakTAbs - a1PeakTAbs;

[scaleC0, yHat0, residuals0, r20, rmse0] = fitThroughOrigin(dlogSv, a1v);
[scaleC1, intercept1, yHat1, residuals1, r21, rmse1] = fitOrdinaryLinear(dlogSv, a1v);

scoreLog = mean(abs([pearsonLog, spearmanLog]), 'omitnan');
scoreDS = mean(abs([pearsonDS, spearmanDS]), 'omitnan');
if scoreLog >= scoreDS
    betterBy = "d/dT ln(S_peak)";
else
    betterBy = "dS_peak/dT";
end

isReasonablyStrong = isfinite(pearsonLog) && isfinite(spearmanLog) && ...
    abs(pearsonLog) >= cfg.strongCorrThreshold && abs(spearmanLog) >= cfg.strongCorrThreshold;

corrTbl = table( ...
    nnz(valid), ...
    pearsonLog, ...
    spearmanLog, ...
    pearsonDS, ...
    spearmanDS, ...
    scoreLog, ...
    scoreDS, ...
    betterBy, ...
    a1PeakTAbs, ...
    dlogSPeakTAbs, ...
    deltaPeakAbsK, ...
    scaleC0, ...
    r20, ...
    rmse0, ...
    scaleC1, ...
    intercept1, ...
    r21, ...
    rmse1, ...
    cfg.sgolayPolynomialOrder, ...
    cfg.sgolayFrameLength, ...
    string(derivativeMethod), ...
    source.a1RunName, ...
    source.switchRunName, ...
    string(source.a1Path), ...
    string(source.switchPath), ...
    'VariableNames', { ...
    'n_points', ...
    'pearson_a1_vs_dlogS_dT', ...
    'spearman_a1_vs_dlogS_dT', ...
    'pearson_a1_vs_dS_dT', ...
    'spearman_a1_vs_dS_dT', ...
    'score_logderivative', ...
    'score_direct_derivative', ...
    'better_described_by', ...
    'a1_peak_T_abs_K', ...
    'dlogS_dT_peak_T_abs_K', ...
    'delta_peak_T_abs_K', ...
    'fit_through_origin_c', ...
    'fit_through_origin_r2', ...
    'fit_through_origin_rmse', ...
    'fit_ordinary_slope', ...
    'fit_ordinary_intercept', ...
    'fit_ordinary_r2', ...
    'fit_ordinary_rmse', ...
    'sgolay_polynomial_order', ...
    'sgolay_frame_length', ...
    'derivative_method', ...
    'a1_source_run', ...
    'switching_source_run', ...
    'a1_source_file', ...
    'switching_source_file'});

seriesTbl = table(Tv, a1v, Speakv, logSv, S_smooth(valid), logS_smooth(valid), dS_raw(valid), dSv, dlogS_raw(valid), dlogSv, ...
    yHat0, residuals0, yHat1, residuals1, ...
    normalizeSigned(a1v), normalizeSigned(dlogSv), normalize01(abs(a1v)), normalize01(abs(dlogSv)), ...
    'VariableNames', {'T_K', 'a1', 'S_peak', 'logS', 'S_peak_smoothed', 'logS_smoothed', ...
    'dS_peak_dT_raw', 'dS_peak_dT_smoothed', 'dlogS_dT_raw', 'dlogS_dT_smoothed', ...
    'a1_fit_origin_from_dlogS', 'fit_origin_residual', 'a1_fit_linear_from_dlogS', 'fit_linear_residual', ...
    'a1_norm_signed', 'dlogS_dT_norm_signed', 'a1_abs_norm', 'dlogS_dT_abs_norm'});

corrPath = save_run_table(corrTbl, 'a1_vs_dlogS_correlation.csv', runDir);
seriesPath = save_run_table(seriesTbl, 'a1_vs_dlogS_series.csv', runDir);
figPath = saveOverlayFigure(Tv, a1v, dlogSv, corrTbl, runDir, 'a1_vs_dlogS_dT');

if isReasonablyStrong
    Eproxy = (Tv .^ 2) .* a1v;
    eProxyFigPath = saveEProxyFigure(Tv, Eproxy, runDir, 'E_proxy_vs_T');
    eProxyPathText = string(eProxyFigPath.png);
else
    Eproxy = NaN(size(Tv));
    eProxyFigPath = struct('png', "", 'fig', "");
    eProxyPathText = "";
end

reportText = buildReportText(source, cfg, corrTbl, figPath, corrPath, seriesPath, eProxyPathText, isReasonablyStrong);
reportPath = save_run_report(reportText, 'a1_vs_dlogS_report.md', runDir);

zipPath = buildReviewZip(runDir, 'switching_a1_vs_logdS_test_bundle.zip', isReasonablyStrong);

appendText(run.notes_path, sprintf('a1 source run = %s\n', char(source.a1RunName)));
appendText(run.notes_path, sprintf('switching source run = %s\n', char(source.switchRunName)));
appendText(run.notes_path, sprintf('pearson(a1,dlogS/dT) = %.6f\n', pearsonLog));
appendText(run.notes_path, sprintf('spearman(a1,dlogS/dT) = %.6f\n', spearmanLog));
appendText(run.notes_path, sprintf('pearson(a1,dS/dT) = %.6f\n', pearsonDS));
appendText(run.notes_path, sprintf('spearman(a1,dS/dT) = %.6f\n', spearmanDS));
appendText(run.notes_path, sprintf('|peak_T(a1)| = %.2f K\n', a1PeakTAbs));
appendText(run.notes_path, sprintf('|peak_T(dlogS/dT)| = %.2f K\n', dlogSPeakTAbs));
appendText(run.notes_path, sprintf('delta_peak_T_abs = %.2f K\n', deltaPeakAbsK));
appendText(run.notes_path, sprintf('better described by = %s\n', char(betterBy)));
appendText(run.notes_path, sprintf('correlation table = %s\n', corrPath));
appendText(run.notes_path, sprintf('series table = %s\n', seriesPath));
appendText(run.notes_path, sprintf('overlay figure = %s\n', figPath.png));
if isReasonablyStrong
    appendText(run.notes_path, sprintf('E_proxy figure = %s\n', eProxyFigPath.png));
end
appendText(run.notes_path, sprintf('report = %s\n', reportPath));
appendText(run.notes_path, sprintf('zip = %s\n', zipPath));

appendText(run.log_path, sprintf('[%s] switching a1-vs-logdS test complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlation table: %s\n', corrPath));
appendText(run.log_path, sprintf('Series table: %s\n', seriesPath));
appendText(run.log_path, sprintf('Overlay figure: %s\n', figPath.png));
if isReasonablyStrong
    appendText(run.log_path, sprintf('E_proxy figure: %s\n', eProxyFigPath.png));
end
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.metrics = struct( ...
    'pearson_dlogS', pearsonLog, ...
    'spearman_dlogS', spearmanLog, ...
    'pearson_dS', pearsonDS, ...
    'spearman_dS', spearmanDS, ...
    'betterBy', betterBy, ...
    'a1_peak_T_abs_K', a1PeakTAbs, ...
    'dlogS_peak_T_abs_K', dlogSPeakTAbs, ...
    'delta_peak_T_abs_K', deltaPeakAbsK, ...
    'fit_origin_c', scaleC0, ...
    'fit_origin_r2', r20, ...
    'fit_linear_slope', scaleC1, ...
    'fit_linear_intercept', intercept1, ...
    'fit_linear_r2', r21);
out.paths = struct( ...
    'correlation', string(corrPath), ...
    'series', string(seriesPath), ...
    'figure', string(figPath.png), ...
    'report', string(reportPath), ...
    'zip', string(zipPath));
if isReasonablyStrong
    out.paths.eProxyFigure = string(eProxyFigPath.png);
end

fprintf('\n=== Switching a1-vs-logdS test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson(a1,dlogS/dT): %.6f\n', pearsonLog);
fprintf('Spearman(a1,dlogS/dT): %.6f\n', spearmanLog);
fprintf('Pearson(a1,dS/dT): %.6f\n', pearsonDS);
fprintf('Spearman(a1,dS/dT): %.6f\n', spearmanDS);
fprintf('Better described by: %s\n', betterBy);
fprintf('Correlation table: %s\n', corrPath);
fprintf('Overlay figure: %s\n', figPath.png);
if isReasonablyStrong
    fprintf('E_proxy figure: %s\n', eProxyFigPath.png);
end
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_a1_vs_logdS_test');
cfg = setDefaultField(cfg, 'a1RunName', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefaultField(cfg, 'a1ColumnName', 'a_1');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'targetSectorK', 10);
cfg = setDefaultField(cfg, 'sgolayPolynomialOrder', 2);
cfg = setDefaultField(cfg, 'sgolayFrameLength', 5);
cfg = setDefaultField(cfg, 'movmeanWindow', 3);
cfg = setDefaultField(cfg, 'strongCorrThreshold', 0.7);
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

required = {'T_K', 'S_peak'};
for i = 1:numel(required)
    if ~ismember(required{i}, tbl.Properties.VariableNames)
        error('Switching table missing required column "%s": %s', required{i}, pathValue);
    end
end

tbl = sortrows(tbl, 'T_K');
data = struct();
data.T_K = double(tbl.T_K(:));
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

tblOut = tbl;
end

function tbl = longToWideSwitching(tblLong)
T = unique(double(tblLong.temperature(:)));
T = T(isfinite(T));
T = sort(T);
n = numel(T);

S_peak = NaN(n, 1);
for i = 1:n
    t = T(i);
    rows = tblLong(double(tblLong.temperature) == t, :);
    obs = lower(string(rows.observable));
    vals = double(rows.value);
    S_peak(i) = firstValue(obs, vals, ["s_peak"]);
end

tbl = table(T, S_peak, ...
    'VariableNames', {'T_K', 'S_peak'});
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

function [c, yHat, residuals, r2, rmse] = fitThroughOrigin(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
x = x(mask);
y = y(mask);

if isempty(x) || sum(x .^ 2) <= eps
    c = NaN;
    yHat = NaN(size(y));
    residuals = NaN(size(y));
    r2 = NaN;
    rmse = NaN;
    return;
end

c = (x' * y) / max(x' * x, eps);
yHat = c .* x;
residuals = y - yHat;

sse = sum(residuals .^ 2);
sst = sum((y - mean(y, 'omitnan')) .^ 2);
if sst <= eps
    r2 = NaN;
else
    r2 = 1 - (sse / sst);
end
rmse = sqrt(mean(residuals .^ 2, 'omitnan'));
end

function [slope, intercept, yHat, residuals, r2, rmse] = fitOrdinaryLinear(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
x = x(mask);
y = y(mask);

if numel(x) < 3
    slope = NaN;
    intercept = NaN;
    yHat = NaN(size(y));
    residuals = NaN(size(y));
    r2 = NaN;
    rmse = NaN;
    return;
end

p = polyfit(x, y, 1);
slope = p(1);
intercept = p(2);
yHat = polyval(p, x);
residuals = y - yHat;

sse = sum(residuals .^ 2);
sst = sum((y - mean(y, 'omitnan')) .^ 2);
if sst <= eps
    r2 = NaN;
else
    r2 = 1 - (sse / sst);
end
rmse = sqrt(mean(residuals .^ 2, 'omitnan'));
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

function figOut = saveOverlayFigure(T, a1, dlogS, corrTbl, runDir, baseName)
fig = create_figure('Visible', 'off', 'Position', [2 2 13.5 9.6]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, T, normalizeSigned(a1), '-o', ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'DisplayName', 'a1(T) signed-norm');
plot(ax, T, normalizeSigned(dlogS), '-s', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'DisplayName', 'dlogS/dT signed-norm');
plot(ax, T, normalize01(abs(a1)), '--', ...
    'Color', [0.20 0.20 0.20], 'LineWidth', 2.0, ...
    'DisplayName', '|a1(T)| norm');
plot(ax, T, normalize01(abs(dlogS)), ':', ...
    'Color', [0.47 0.67 0.19], 'LineWidth', 2.2, ...
    'DisplayName', '|dlogS/dT| norm');
yline(ax, 0, '-', 'LineWidth', 1.0, 'Color', [0.70 0.70 0.70]);
hold(ax, 'off');

xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalized amplitude', 'FontSize', 14);
title(ax, sprintf('a1(T) vs dlogS/dT | Pearson=%.4f, Spearman=%.4f, DeltaT_{peak}=%.1f K', ...
    corrTbl.pearson_a1_vs_dlogS_dT(1), corrTbl.spearman_a1_vs_dlogS_dT(1), corrTbl.delta_peak_T_abs_K(1)), ...
    'FontSize', 12);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 10);

figOut = robustSaveFigure(fig, baseName, runDir);
close(fig);
end

function figOut = saveEProxyFigure(T, Eproxy, runDir, baseName)
fig = create_figure('Visible', 'off', 'Position', [2 2 13.0 7.8]);
ax = axes(fig);
plot(ax, T, Eproxy, '-o', ...
    'Color', [0.49 0.18 0.56], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.49 0.18 0.56]);

xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'E_proxy(T) = T^2 * a1(T) (a.u.)', 'FontSize', 14);
title(ax, 'Phenomenological proxy scale (descriptive only)', 'FontSize', 12);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');

figOut = robustSaveFigure(fig, baseName, runDir);
close(fig);
end

function figOut = robustSaveFigure(fig, baseName, runDir)
try
    figOut = save_run_figure(fig, baseName, runDir);
catch ME
    warning('switching_a1_vs_logdS_test:saveFigureFallback', ...
        'save_run_figure failed (%s); using fallback export.', ME.message);
    figuresDir = fullfile(runDir, 'figures');
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    figOut = struct();
    figOut.png = fullfile(figuresDir, [baseName '.png']);
    figOut.fig = fullfile(figuresDir, [baseName '.fig']);
    figOut.pdf = fullfile(figuresDir, [baseName '.pdf']);
    exportgraphics(fig, figOut.png, 'Resolution', 300);
    savefig(fig, figOut.fig);
    try
        exportgraphics(fig, figOut.pdf, 'ContentType', 'vector');
    catch
        % PDF export is optional in fallback mode.
    end
end
end

function reportText = buildReportText(source, cfg, corrTbl, figPath, corrPath, seriesPath, eProxyPathText, hasEProxy)
lines = strings(0, 1);
lines(end + 1) = "# a1(T) vs d/dT ln(S_peak(T)) test report";
lines(end + 1) = "";
lines(end + 1) = "## Sources";
lines(end + 1) = "- a1 source run: `" + source.a1RunName + "`";
lines(end + 1) = "- switching observables source run: `" + source.switchRunName + "`";
lines(end + 1) = "- a1 source file: `" + string(source.a1Path) + "`";
lines(end + 1) = "- switching source file: `" + string(source.switchPath) + "`";
lines(end + 1) = "";
lines(end + 1) = "## Method";
lines(end + 1) = "- Temperature range: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`.";
lines(end + 1) = "- Computed `logS(T) = ln(S_peak(T))` and `dlogS_dT = d/dT ln(S_peak(T))`.";
lines(end + 1) = "- Derivative smoothing: Savitzky-Golay with polynomial order `" + string(cfg.sgolayPolynomialOrder) + "` and frame `" + string(cfg.sgolayFrameLength) + "`; derivative via `gradient`.";
lines(end + 1) = "- Comparison baseline: `dS_peak/dT` with identical smoothing settings.";
lines(end + 1) = "";
lines(end + 1) = "## Results";
lines(end + 1) = "- Pearson correlation (`a1` vs `dlogS/dT`): `" + sprintf('%.6f', corrTbl.pearson_a1_vs_dlogS_dT(1)) + "`.";
lines(end + 1) = "- Spearman correlation (`a1` vs `dlogS/dT`): `" + sprintf('%.6f', corrTbl.spearman_a1_vs_dlogS_dT(1)) + "`.";
lines(end + 1) = "- Pearson correlation (`a1` vs `dS_peak/dT`): `" + sprintf('%.6f', corrTbl.pearson_a1_vs_dS_dT(1)) + "`.";
lines(end + 1) = "- Spearman correlation (`a1` vs `dS_peak/dT`): `" + sprintf('%.6f', corrTbl.spearman_a1_vs_dS_dT(1)) + "`.";
lines(end + 1) = "- Better descriptor between derivatives: `" + string(corrTbl.better_described_by(1)) + "` (by mean absolute correlation score).";
lines(end + 1) = "- Peak-temperature alignment (absolute peaks): `T_peak(|a1|) = " + sprintf('%.2f K', corrTbl.a1_peak_T_abs_K(1)) + ...
    "`, `T_peak(|dlogS/dT|) = " + sprintf('%.2f K', corrTbl.dlogS_dT_peak_T_abs_K(1)) + ...
    "`, `delta = " + sprintf('%.2f K', corrTbl.delta_peak_T_abs_K(1)) + "`.";
lines(end + 1) = "- Through-origin fit `a1 = c*(dlogS/dT)`: `c = " + sprintf('%.6g', corrTbl.fit_through_origin_c(1)) + ...
    "`, `R^2 = " + sprintf('%.4f', corrTbl.fit_through_origin_r2(1)) + ...
    "`, `RMSE = " + sprintf('%.4g', corrTbl.fit_through_origin_rmse(1)) + "`.";
lines(end + 1) = "- Ordinary linear fit `a1 = m*(dlogS/dT) + b`: `m = " + sprintf('%.6g', corrTbl.fit_ordinary_slope(1)) + ...
    "`, `b = " + sprintf('%.6g', corrTbl.fit_ordinary_intercept(1)) + ...
    "`, `R^2 = " + sprintf('%.4f', corrTbl.fit_ordinary_r2(1)) + ...
    "`, `RMSE = " + sprintf('%.4g', corrTbl.fit_ordinary_rmse(1)) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
lines(end + 1) = "- Statement requested: a1(T) is better described by `" + string(corrTbl.better_described_by(1)) + "` within this dataset and smoothing choice.";
if string(corrTbl.better_described_by(1)) == "d/dT ln(S_peak)"
    lines(end + 1) = "- This supports interpreting a1 as a relative-amplitude susceptibility at a phenomenological level.";
else
    lines(end + 1) = "- This does not support a stronger relative-amplitude susceptibility interpretation than direct amplitude-derivative tracking.";
end
lines(end + 1) = "- Limitations: finite temperature grid, derivative sensitivity to smoothing/windowing, and correlation-only evidence without mechanistic identification.";

if hasEProxy
    lines(end + 1) = "";
    lines(end + 1) = "## Phenomenological proxy";
    lines(end + 1) = "- Because correlation is reasonably strong, `E_proxy(T) = T^2 * a1(T)` is plotted as a descriptive scale candidate only.";
    lines(end + 1) = "- This is not a validated barrier energy and should not be interpreted as a microscopic activation energy without independent evidence.";
    lines(end + 1) = "- E_proxy figure: `" + eProxyPathText + "`.";
    lines(end + 1) = "";
    lines(end + 1) = "![E_proxy_vs_T](../figures/E_proxy_vs_T.png)";
end

lines(end + 1) = "";
lines(end + 1) = "## Artifacts";
lines(end + 1) = "- Correlation table: `" + string(corrPath) + "`";
lines(end + 1) = "- Aligned-series table: `" + string(seriesPath) + "`";
lines(end + 1) = "- Overlay figure: `" + string(figPath.png) + "`";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_dlogS_dT](../figures/a1_vs_dlogS_dT.png)";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 4";
lines(end + 1) = "- legend vs colormap: legend used (`<= 6` curves)";
lines(end + 1) = "- colormap used: none (line overlay)";
lines(end + 1) = "- smoothing applied: Savitzky-Golay (`p=2`, `frame=5`) before derivative";
lines(end + 1) = "- justification: signed and absolute normalized overlays expose directional tracking and absolute-amplitude alignment.";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

function zipPath = buildReviewZip(runDir, zipName, hasEProxy)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end

files = { ...
    fullfile(runDir, 'figures', 'a1_vs_dlogS_dT.png'), ...
    fullfile(runDir, 'tables', 'a1_vs_dlogS_correlation.csv'), ...
    fullfile(runDir, 'reports', 'a1_vs_dlogS_report.md'), ...
    fullfile(runDir, 'run_manifest.json'), ...
    fullfile(runDir, 'config_snapshot.m'), ...
    fullfile(runDir, 'log.txt'), ...
    fullfile(runDir, 'run_notes.txt')};

if hasEProxy
    files{end + 1} = fullfile(runDir, 'figures', 'E_proxy_vs_T.png'); %#ok<AGROW>
end

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
