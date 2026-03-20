function out = switching_activation_signature_test(cfg)
% switching_activation_signature_test
% Test whether the switching amplitude a1(T) follows an activation-like
% temperature dependence through the normalized derivative Y(T) = dS_peak/dT / S_peak.
%
% If S_peak ~ exp(-E_a / kT), then Y(T) = d/dT ln(S_peak) ~ E_a / (kT^2),
% i.e. Y should scale as 1/T^2.  This test checks:
%   (a) correlation between Y(T) and a1(T)
%   (b) peak alignment between |Y(T)| and |a1(T)|
%   (c) correlation between Y(T) and 1/T^2  (activation-like scaling check)

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
runCfg.dataset = sprintf('a1:%s | geom:%s', ...
    char(source.a1RunName), char(source.geomRunName));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching activation signature test run directory:\n%s\n', runDir);
fprintf('a1 source run: %s\n', source.a1RunName);
fprintf('Geometry source run: %s\n', source.geomRunName);
appendText(run.log_path, sprintf('[%s] switching activation signature test started\n', stampNow()));
appendText(run.log_path, sprintf('a1 source run: %s\n', char(source.a1RunName)));
appendText(run.log_path, sprintf('geometry source run: %s\n', char(source.geomRunName)));

% -------------------------------------------------------------------------
% Load data
% -------------------------------------------------------------------------
a1Data   = loadA1Data(source.a1Path, cfg.a1ColumnName);
geomData = loadGeomData(source.geomPath);

% Align temperatures
[T, iA1, iGeom] = intersect(a1Data.T_K, geomData.T_K, 'stable');
if isempty(T)
    error('switching_activation_signature_test:noOverlap', ...
        'No common temperatures between a1 source and geometry source.');
end

a1    = double(a1Data.a1(iA1));
Speak = double(geomData.S_peak(iGeom));

% Temperature range filter
maskRange = T >= cfg.temperatureMinK & T <= cfg.temperatureMaxK;
T     = double(T(maskRange));
a1    = a1(maskRange);
Speak = Speak(maskRange);

if numel(T) < 5
    error('switching_activation_signature_test:tooFewPoints', ...
        'Need at least 5 temperature points after alignment/range filtering.');
end

% Fill isolated NaN gaps by interpolation
a1    = fillByInterp(T, a1);
Speak = fillByInterp(T, Speak);
SpeakSafe = max(Speak, eps);

% -------------------------------------------------------------------------
% Compute derivatives
% -------------------------------------------------------------------------
% dS_peak/dT  (with smoothing)
[dS_raw, dS, S_smooth, derivMethodS] = derivativeProfiles(T, SpeakSafe, cfg);

% Y(T) = (1/S_peak) * dS_peak/dT = d/dT ln(S_peak)
logS = log(SpeakSafe);
[dlogS_raw, dlogS, logS_smooth, derivMethodLog] = derivativeProfiles(T, logS, cfg);
% Y and dlogS are identical in derivation; keep two names for clarity
Yv_all = dlogS;

% 1/T^2 reference curve
invT2_all = 1 ./ max(T .^ 2, eps);

% -------------------------------------------------------------------------
% Mask to finite points only
% -------------------------------------------------------------------------
valid = isfinite(T) & isfinite(a1) & isfinite(dS) & isfinite(Yv_all);
if nnz(valid) < 3
    error('switching_activation_signature_test:insufficientPoints', ...
        'Insufficient finite points for analysis after preprocessing.');
end

Tv       = T(valid);
a1v      = a1(valid);
dSv      = dS(valid);
Yv       = Yv_all(valid);
invT2v   = invT2_all(valid);
Speakv   = SpeakSafe(valid);
logSv    = logS(valid);

% -------------------------------------------------------------------------
% Correlations
% -------------------------------------------------------------------------
pearsonY    = safeCorr(a1v, Yv,    'Pearson');
spearmanY   = safeCorr(a1v, Yv,    'Spearman');
pearsonDS   = safeCorr(a1v, dSv,   'Pearson');
spearmanDS  = safeCorr(a1v, dSv,   'Spearman');
pearsonInvT2  = safeCorr(Yv, invT2v, 'Pearson');
spearmanInvT2 = safeCorr(Yv, invT2v, 'Spearman');

% -------------------------------------------------------------------------
% Peak alignment
% -------------------------------------------------------------------------
[a1PeakT,  ~] = peakOf(Tv, a1v, true);
[YPeakT,   ~] = peakOf(Tv, Yv,  true);
[dSPeakT,  ~] = peakOf(Tv, dSv, true);
deltaPeakY_K  = YPeakT  - a1PeakT;
deltaPeakDS_K = dSPeakT - a1PeakT;

% -------------------------------------------------------------------------
% Fits: Y vs a1, Y vs 1/T^2
% -------------------------------------------------------------------------
[c0_Ya1, yHat0_Ya1, res0_Ya1, r20_Ya1, rmse0_Ya1]           = fitThroughOrigin(Yv, a1v);
[m1_Ya1, b1_Ya1, yHat1_Ya1, res1_Ya1, r21_Ya1, rmse1_Ya1]   = fitOrdinaryLinear(Yv, a1v);
[c0_YinvT2, ~, ~, r20_YinvT2, rmse0_YinvT2]                 = fitThroughOrigin(invT2v, Yv);

% -------------------------------------------------------------------------
% Verdict: is activation-like scaling supported?
% -------------------------------------------------------------------------
scoreY     = mean(abs([pearsonY,     spearmanY]),     'omitnan');
scoreInvT2 = mean(abs([pearsonInvT2, spearmanInvT2]), 'omitnan');
isActivationSupported = isfinite(pearsonInvT2) && isfinite(spearmanInvT2) && ...
    abs(pearsonInvT2) >= cfg.activationCorrThreshold && ...
    abs(spearmanInvT2) >= cfg.activationCorrThreshold;
isA1YStrong = isfinite(pearsonY) && isfinite(spearmanY) && ...
    abs(pearsonY) >= cfg.strongCorrThreshold && ...
    abs(spearmanY) >= cfg.strongCorrThreshold;

% -------------------------------------------------------------------------
% Build correlation table
% -------------------------------------------------------------------------
corrTbl = table( ...
    nnz(valid), ...
    pearsonY, ...
    spearmanY, ...
    pearsonDS, ...
    spearmanDS, ...
    pearsonInvT2, ...
    spearmanInvT2, ...
    scoreY, ...
    scoreInvT2, ...
    double(isA1YStrong), ...
    double(isActivationSupported), ...
    a1PeakT, ...
    YPeakT, ...
    dSPeakT, ...
    deltaPeakY_K, ...
    deltaPeakDS_K, ...
    c0_Ya1, ...
    r20_Ya1, ...
    rmse0_Ya1, ...
    m1_Ya1, ...
    b1_Ya1, ...
    r21_Ya1, ...
    rmse1_Ya1, ...
    c0_YinvT2, ...
    r20_YinvT2, ...
    rmse0_YinvT2, ...
    cfg.sgolayPolynomialOrder, ...
    cfg.sgolayFrameLength, ...
    string(derivMethodS), ...
    string(derivMethodLog), ...
    source.a1RunName, ...
    source.geomRunName, ...
    string(source.a1Path), ...
    string(source.geomPath), ...
    'VariableNames', { ...
    'n_points', ...
    'pearson_a1_vs_Y', ...
    'spearman_a1_vs_Y', ...
    'pearson_a1_vs_dS_dT', ...
    'spearman_a1_vs_dS_dT', ...
    'pearson_Y_vs_invT2', ...
    'spearman_Y_vs_invT2', ...
    'score_Y_vs_a1', ...
    'score_Y_vs_invT2', ...
    'is_a1_Y_strong_correlation', ...
    'is_activation_scaling_supported', ...
    'a1_peak_T_abs_K', ...
    'Y_peak_T_abs_K', ...
    'dS_dT_peak_T_abs_K', ...
    'delta_peak_Y_minus_a1_K', ...
    'delta_peak_dS_minus_a1_K', ...
    'fit_Y_to_a1_origin_c', ...
    'fit_Y_to_a1_origin_r2', ...
    'fit_Y_to_a1_origin_rmse', ...
    'fit_Y_to_a1_slope', ...
    'fit_Y_to_a1_intercept', ...
    'fit_Y_to_a1_r2', ...
    'fit_Y_to_a1_rmse', ...
    'fit_Y_vs_invT2_origin_c', ...
    'fit_Y_vs_invT2_origin_r2', ...
    'fit_Y_vs_invT2_origin_rmse', ...
    'sgolay_polynomial_order', ...
    'sgolay_frame_length', ...
    'derivative_method_S', ...
    'derivative_method_logS', ...
    'a1_source_run', ...
    'geom_source_run', ...
    'a1_source_file', ...
    'geom_source_file'});

% -------------------------------------------------------------------------
% Build series table
% -------------------------------------------------------------------------
seriesTbl = table( ...
    Tv, a1v, Speakv, logSv, ...
    S_smooth(valid), logS_smooth(valid), ...
    dS_raw(valid), dSv, ...
    dlogS_raw(valid), Yv, ...
    invT2v, ...
    yHat0_Ya1, res0_Ya1, yHat1_Ya1, res1_Ya1, ...
    normalizeSigned(a1v), normalizeSigned(Yv), normalizeSigned(dSv), ...
    normalize01(abs(a1v)), normalize01(abs(Yv)), normalize01(invT2v), ...
    'VariableNames', { ...
    'T_K', 'a1', 'S_peak', 'logS', ...
    'S_peak_smoothed', 'logS_smoothed', ...
    'dS_peak_dT_raw', 'dS_peak_dT_smoothed', ...
    'Y_raw', 'Y_smoothed', ...
    'inv_T2', ...
    'a1_fit_origin_from_Y', 'fit_origin_residual', ...
    'a1_fit_linear_from_Y', 'fit_linear_residual', ...
    'a1_norm_signed', 'Y_norm_signed', 'dS_dT_norm_signed', ...
    'a1_abs_norm', 'Y_abs_norm', 'inv_T2_norm'});

% -------------------------------------------------------------------------
% Peak table
% -------------------------------------------------------------------------
peakTbl = table( ...
    a1PeakT, YPeakT, dSPeakT, deltaPeakY_K, deltaPeakDS_K, ...
    'VariableNames', { ...
    'a1_peak_T_abs_K', 'Y_peak_T_abs_K', 'dS_dT_peak_T_abs_K', ...
    'delta_Y_minus_a1_K', 'delta_dS_minus_a1_K'});

% -------------------------------------------------------------------------
% Save tables
% -------------------------------------------------------------------------
corrPath   = save_run_table(corrTbl,   'activation_signature_correlations.csv', runDir);
seriesPath = save_run_table(seriesTbl, 'activation_signature_series.csv',       runDir);
peakPath   = save_run_table(peakTbl,   'activation_signature_peaks.csv',         runDir);

% -------------------------------------------------------------------------
% Figures
% -------------------------------------------------------------------------
figOverlay  = saveOverlayFigure(Tv, a1v, Yv, dSv,       corrTbl, runDir);
figScatterY = saveScatterFigure(Yv,     a1v, 'Y(T)', 'a1(T)', ...
    yHat0_Ya1, yHat1_Ya1, r20_Ya1, r21_Ya1, ...
    'activation_scatter_a1_vs_Y', runDir);
figScatterInvT2 = saveScatterFigure_invT2(invT2v, Yv, pearsonInvT2, spearmanInvT2, ...
    c0_YinvT2, r20_YinvT2, 'activation_scatter_Y_vs_invT2', runDir);

% -------------------------------------------------------------------------
% Report
% -------------------------------------------------------------------------
reportText = buildReport(source, cfg, corrTbl, ...
    figOverlay, figScatterY, figScatterInvT2, ...
    corrPath, seriesPath, peakPath, ...
    isActivationSupported, isA1YStrong);
reportPath = save_run_report(reportText, 'activation_signature_report.md', runDir);

% -------------------------------------------------------------------------
% Review ZIP
% -------------------------------------------------------------------------
zipPath = buildReviewZip(runDir, 'switching_activation_signature_bundle.zip');

% -------------------------------------------------------------------------
% Notes and log
% -------------------------------------------------------------------------
appendText(run.notes_path, sprintf('a1 source run = %s\n',          char(source.a1RunName)));
appendText(run.notes_path, sprintf('geometry source run = %s\n',    char(source.geomRunName)));
appendText(run.notes_path, sprintf('pearson(a1,Y) = %.6f\n',        pearsonY));
appendText(run.notes_path, sprintf('spearman(a1,Y) = %.6f\n',       spearmanY));
appendText(run.notes_path, sprintf('pearson(Y,1/T^2) = %.6f\n',     pearsonInvT2));
appendText(run.notes_path, sprintf('spearman(Y,1/T^2) = %.6f\n',    spearmanInvT2));
appendText(run.notes_path, sprintf('a1_peak_T_abs = %.2f K\n',      a1PeakT));
appendText(run.notes_path, sprintf('Y_peak_T_abs = %.2f K\n',       YPeakT));
appendText(run.notes_path, sprintf('delta_peak_Y_a1 = %.2f K\n',    deltaPeakY_K));
appendText(run.notes_path, sprintf('activation_scaling_supported = %d\n', double(isActivationSupported)));
appendText(run.notes_path, sprintf('correlation table = %s\n',      corrPath));
appendText(run.notes_path, sprintf('series table = %s\n',           seriesPath));
appendText(run.notes_path, sprintf('overlay figure = %s\n',         figOverlay.png));
appendText(run.notes_path, sprintf('report = %s\n',                 reportPath));
appendText(run.notes_path, sprintf('zip = %s\n',                    zipPath));

appendText(run.log_path, sprintf('[%s] switching activation signature test complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlation table: %s\n', corrPath));
appendText(run.log_path, sprintf('Series table: %s\n',      seriesPath));
appendText(run.log_path, sprintf('Overlay figure: %s\n',    figOverlay.png));
appendText(run.log_path, sprintf('Scatter Y: %s\n',         figScatterY.png));
appendText(run.log_path, sprintf('Scatter invT2: %s\n',     figScatterInvT2.png));
appendText(run.log_path, sprintf('Report: %s\n',            reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n',               zipPath));

% -------------------------------------------------------------------------
% Output struct
% -------------------------------------------------------------------------
out = struct();
out.run    = run;
out.runDir = string(runDir);
out.source = source;
out.metrics = struct( ...
    'pearson_a1_vs_Y',          pearsonY, ...
    'spearman_a1_vs_Y',         spearmanY, ...
    'pearson_a1_vs_dS',         pearsonDS, ...
    'spearman_a1_vs_dS',        spearmanDS, ...
    'pearson_Y_vs_invT2',       pearsonInvT2, ...
    'spearman_Y_vs_invT2',      spearmanInvT2, ...
    'a1_peak_T_abs_K',          a1PeakT, ...
    'Y_peak_T_abs_K',           YPeakT, ...
    'delta_peak_Y_K',           deltaPeakY_K, ...
    'is_activation_supported',  isActivationSupported, ...
    'is_a1_Y_strong',           isA1YStrong, ...
    'fit_origin_c',             c0_Ya1, ...
    'fit_origin_r2',            r20_Ya1, ...
    'fit_linear_slope',         m1_Ya1, ...
    'fit_linear_intercept',     b1_Ya1, ...
    'fit_linear_r2',            r21_Ya1);
out.paths = struct( ...
    'correlations', string(corrPath), ...
    'series',       string(seriesPath), ...
    'peaks',        string(peakPath), ...
    'figOverlay',   string(figOverlay.png), ...
    'figScatterY',  string(figScatterY.png), ...
    'figScatterInvT2', string(figScatterInvT2.png), ...
    'report',       string(reportPath), ...
    'zip',          string(zipPath));

fprintf('\n=== Switching activation signature test complete ===\n');
fprintf('Run dir: %s\n',                runDir);
fprintf('Pearson(a1,Y): %.6f\n',        pearsonY);
fprintf('Spearman(a1,Y): %.6f\n',       spearmanY);
fprintf('Pearson(Y,1/T^2): %.6f\n',     pearsonInvT2);
fprintf('Spearman(Y,1/T^2): %.6f\n',    spearmanInvT2);
fprintf('Activation scaling supported: %d\n', double(isActivationSupported));
fprintf('Correlation table: %s\n',      corrPath);
fprintf('Overlay figure: %s\n',         figOverlay.png);
fprintf('Report: %s\n\n',              reportPath);
end

% =========================================================================
%  LOCAL FUNCTIONS
% =========================================================================

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel',               'switching_activation_signature_test');
cfg = setDefaultField(cfg, 'a1RunName',              'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'geomRunName',            'run_2026_03_13_112155_switching_geometry_diagnostics');
cfg = setDefaultField(cfg, 'a1ColumnName',           'a_1');
cfg = setDefaultField(cfg, 'temperatureMinK',        4);
cfg = setDefaultField(cfg, 'temperatureMaxK',        30);
cfg = setDefaultField(cfg, 'sgolayPolynomialOrder',  2);
cfg = setDefaultField(cfg, 'sgolayFrameLength',      5);
cfg = setDefaultField(cfg, 'movmeanWindow',          3);
cfg = setDefaultField(cfg, 'strongCorrThreshold',    0.70);
cfg = setDefaultField(cfg, 'activationCorrThreshold', 0.70);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.a1RunName   = string(cfg.a1RunName);
source.geomRunName = string(cfg.geomRunName);

source.a1RunDir   = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.a1RunName));
source.geomRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.geomRunName));

source.a1Path   = fullfile(source.a1RunDir,   'tables', 'switching_dynamic_shape_mode_amplitudes.csv');
source.geomPath = fullfile(source.geomRunDir, 'tables', 'switching_geometry_observables.csv');

if exist(source.a1RunDir, 'dir') ~= 7
    error('switching_activation_signature_test:missingDir', ...
        'Required a1 source run directory not found: %s', source.a1RunDir);
end
if exist(source.geomRunDir, 'dir') ~= 7
    error('switching_activation_signature_test:missingDir', ...
        'Required geometry source run directory not found: %s', source.geomRunDir);
end
if exist(source.a1Path, 'file') ~= 2
    error('switching_activation_signature_test:missingFile', ...
        'Required a1 source file not found: %s', source.a1Path);
end
if exist(source.geomPath, 'file') ~= 2
    error('switching_activation_signature_test:missingFile', ...
        'Required geometry observables file not found: %s', source.geomPath);
end
end

function data = loadA1Data(pathValue, a1ColumnName)
tbl = readtable(pathValue);
if ~ismember('T_K', tbl.Properties.VariableNames)
    error('switching_activation_signature_test:missingColumn', ...
        'a1 table missing T_K column: %s', pathValue);
end
if ~ismember(a1ColumnName, tbl.Properties.VariableNames)
    error('switching_activation_signature_test:missingColumn', ...
        'a1 table missing requested column %s: %s', a1ColumnName, pathValue);
end
tbl = sortrows(tbl, 'T_K');
data = struct();
data.T_K = double(tbl.T_K(:));
data.a1  = double(tbl.(a1ColumnName)(:));
end

function data = loadGeomData(pathValue)
tbl = readtable(pathValue);
required = {'T_K', 'S_peak'};
for i = 1:numel(required)
    if ~ismember(required{i}, tbl.Properties.VariableNames)
        error('switching_activation_signature_test:missingColumn', ...
            'Geometry table missing required column "%s": %s', required{i}, pathValue);
    end
end
tbl = sortrows(tbl, 'T_K');
data = struct();
data.T_K   = double(tbl.T_K(:));
data.S_peak = double(tbl.S_peak(:));
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
dRaw      = gradient(y, x);
ySmooth   = y;
methodText = "none";

n     = numel(y);
frame = min(max(3, round(cfg.sgolayFrameLength)), n);
if mod(frame, 2) == 0
    frame = frame - 1;
end
poly = min(max(1, round(cfg.sgolayPolynomialOrder)), frame - 1);

if exist('sgolayfilt', 'file') == 2 && frame >= 3 && frame > poly
    try
        ySmooth    = sgolayfilt(y, poly, frame);
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
        ySmooth    = smoothdata(y, 'movmean', w, 'omitnan');
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
peakT   = NaN;
peakVal = NaN;
if isempty(T) || isempty(y)
    return;
end
if useAbs
    [~, idx] = max(abs(y));
    peakVal  = y(idx);
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
    c         = NaN;
    yHat      = NaN(size(y));
    residuals = NaN(size(y));
    r2        = NaN;
    rmse      = NaN;
    return;
end
c         = (x' * y) / max(x' * x, eps);
yHat      = c .* x;
residuals = y - yHat;
sse = sum(residuals .^ 2);
sst = sum((y - mean(y, 'omitnan')) .^ 2);
r2  = ternaryVal(sst > eps, 1 - sse / sst, NaN);
rmse = sqrt(mean(residuals .^ 2, 'omitnan'));
end

function [slope, intercept, yHat, residuals, r2, rmse] = fitOrdinaryLinear(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
x = x(mask);
y = y(mask);
if numel(x) < 3
    slope     = NaN;
    intercept = NaN;
    yHat      = NaN(size(y));
    residuals = NaN(size(y));
    r2        = NaN;
    rmse      = NaN;
    return;
end
p         = polyfit(x, y, 1);
slope     = p(1);
intercept = p(2);
yHat      = polyval(p, x);
residuals = y - yHat;
sse = sum(residuals .^ 2);
sst = sum((y - mean(y, 'omitnan')) .^ 2);
r2  = ternaryVal(sst > eps, 1 - sse / sst, NaN);
rmse = sqrt(mean(residuals .^ 2, 'omitnan'));
end

function v = ternaryVal(cond, a, b)
if cond
    v = a;
else
    v = b;
end
end

function y = normalizeSigned(x)
x     = x(:);
scale = max(abs(x), [], 'omitnan');
if ~isfinite(scale) || scale <= 0
    y = zeros(size(x));
else
    y = x ./ scale;
end
end

function y = normalize01(x)
x  = x(:);
mn = min(x, [], 'omitnan');
mx = max(x, [], 'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn
    y = zeros(size(x));
else
    y = (x - mn) ./ (mx - mn);
end
end

% -------------------------------------------------------------------------
%  Figure: 3-curve normalized overlay (a1, dS/dT, Y)
% -------------------------------------------------------------------------
function figOut = saveOverlayFigure(T, a1, Y, dS, corrTbl, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 14 10]);
ax  = axes(fig);
hold(ax, 'on');

plot(ax, T, normalizeSigned(a1), '-o', ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'DisplayName', 'a_1(T) signed-norm');
plot(ax, T, normalizeSigned(dS), '-s', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'DisplayName', 'dS_{peak}/dT signed-norm');
plot(ax, T, normalizeSigned(Y), '-^', ...
    'Color', [0.47 0.67 0.19], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.47 0.67 0.19], ...
    'DisplayName', 'Y(T) = (1/S)dS/dT signed-norm');

yline(ax, 0, '-', 'LineWidth', 1.0, 'Color', [0.70 0.70 0.70]);
hold(ax, 'off');

xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalized amplitude', 'FontSize', 14);
title(ax, sprintf('a_1 vs dS/dT vs Y  |  Pearson(a_1,Y)=%.4f  Spearman=%.4f  ΔT_{peak}=%.1f K', ...
    corrTbl.pearson_a1_vs_Y(1), corrTbl.spearman_a1_vs_Y(1), ...
    corrTbl.delta_peak_Y_minus_a1_K(1)), 'FontSize', 11);
legend(ax, 'Location', 'best', 'FontSize', 10);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');

figOut = robustSaveFigure(fig, 'activation_overlay', runDir);
close(fig);
end

% -------------------------------------------------------------------------
%  Figure: scatter a1 vs Y with both fits
% -------------------------------------------------------------------------
function figOut = saveScatterFigure(xv, yv, xLabel, yLabel, yHat0, yHat1, r20, r21, baseName, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 11 9]);
ax  = axes(fig);
hold(ax, 'on');

scatter(ax, xv, yv, 40, [0.00 0.45 0.74], 'filled', 'DisplayName', 'Data');

% Sort for line plots
[xs, si] = sort(xv);
plot(ax, xs, yHat0(si), '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.0, ...
    'DisplayName', sprintf('Through-origin fit (R^2=%.3f)', r20));
plot(ax, xs, yHat1(si), '--', 'Color', [0.49 0.18 0.56], 'LineWidth', 2.0, ...
    'DisplayName', sprintf('Linear fit (R^2=%.3f)', r21));

hold(ax, 'off');
xlabel(ax, xLabel, 'FontSize', 14);
ylabel(ax, yLabel, 'FontSize', 14);
title(ax, sprintf('%s vs %s', yLabel, xLabel), 'FontSize', 12);
legend(ax, 'Location', 'best', 'FontSize', 10);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');

figOut = robustSaveFigure(fig, baseName, runDir);
close(fig);
end

% -------------------------------------------------------------------------
%  Figure: scatter Y vs 1/T^2 (activation scaling check)
% -------------------------------------------------------------------------
function figOut = saveScatterFigure_invT2(invT2v, Yv, pearsonInvT2, spearmanInvT2, c0, r20, baseName, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 11 9]);
ax  = axes(fig);
hold(ax, 'on');

scatter(ax, invT2v, Yv, 40, [0.47 0.67 0.19], 'filled', 'DisplayName', 'Data');

[xs, si] = sort(invT2v);
yFit     = c0 .* xs;
plot(ax, xs, yFit, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.0, ...
    'DisplayName', sprintf('Through-origin fit (R^2=%.3f)', r20));

hold(ax, 'off');
xlabel(ax, '1/T^2  (K^{-2})', 'FontSize', 14);
ylabel(ax, 'Y(T) = (1/S) dS/dT  (K^{-1})', 'FontSize', 14);
title(ax, sprintf('Activation scaling check  |  Pearson=%.4f  Spearman=%.4f', ...
    pearsonInvT2, spearmanInvT2), 'FontSize', 12);
legend(ax, 'Location', 'best', 'FontSize', 10);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');

figOut = robustSaveFigure(fig, baseName, runDir);
close(fig);
end

% -------------------------------------------------------------------------
%  Robust figure saver
% -------------------------------------------------------------------------
function figOut = robustSaveFigure(fig, baseName, runDir)
try
    figOut = save_run_figure(fig, baseName, runDir);
catch ME
    warning('switching_activation_signature_test:saveFigureFallback', ...
        'save_run_figure failed (%s); using fallback export.', ME.message);
    figuresDir = fullfile(runDir, 'figures');
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    figOut      = struct();
    figOut.png  = fullfile(figuresDir, [baseName '.png']);
    figOut.fig  = fullfile(figuresDir, [baseName '.fig']);
    figOut.pdf  = fullfile(figuresDir, [baseName '.pdf']);
    exportgraphics(fig, figOut.png, 'Resolution', 300);
    savefig(fig, figOut.fig);
    try
        exportgraphics(fig, figOut.pdf, 'ContentType', 'vector');
    catch
        % PDF export is optional in fallback mode.
    end
end
end

% -------------------------------------------------------------------------
%  Report builder
% -------------------------------------------------------------------------
function txt = buildReport(source, cfg, corrTbl, figOverlay, figScatterY, figScatterInvT2, ...
    corrPath, seriesPath, peakPath, isActivationSupported, isA1YStrong)

pY  = corrTbl.pearson_a1_vs_Y(1);
sY  = corrTbl.spearman_a1_vs_Y(1);
pDS = corrTbl.pearson_a1_vs_dS_dT(1);
sDS = corrTbl.spearman_a1_vs_dS_dT(1);
pI  = corrTbl.pearson_Y_vs_invT2(1);
sI  = corrTbl.spearman_Y_vs_invT2(1);

L = strings(0, 1);
L(end+1) = "# Switching Activation Signature Test Report";
L(end+1) = "";
L(end+1) = "## Sources";
L(end+1) = sprintf("- a1 source run: `%s`", source.a1RunName);
L(end+1) = sprintf("- Geometry source run: `%s`", source.geomRunName);
L(end+1) = sprintf("- a1 source file: `%s`", string(source.a1Path));
L(end+1) = sprintf("- Geometry source file: `%s`", string(source.geomPath));
L(end+1) = "";
L(end+1) = "## Method";
L(end+1) = sprintf("- Temperature range: `%.1f – %.1f K`.", cfg.temperatureMinK, cfg.temperatureMaxK);
L(end+1) = "- Loaded `S_peak(T)` from geometry diagnostics run.";
L(end+1) = "- Computed `dS_peak/dT` and `Y(T) = (1/S_peak) × dS_peak/dT = d/dT ln(S_peak)`.";
L(end+1) = sprintf("- Derivative smoothing: Savitzky-Golay (`p=%d`, `frame=%d`) or movmean fallback; derivative via `gradient`.", ...
    cfg.sgolayPolynomialOrder, cfg.sgolayFrameLength);
L(end+1) = sprintf("- Method used (S): `%s`", corrTbl.derivative_method_S(1));
L(end+1) = "- Activation baseline: `1/T^2` (expected if S_peak ~ exp(-E_a/kT)).";
L(end+1) = sprintf("- n_points = %d", corrTbl.n_points(1));
L(end+1) = "";
L(end+1) = "## Correlation Table";
L(end+1) = "";
L(end+1) = "| Observable Pair | Pearson | Spearman | Score |";
L(end+1) = "|---|---|---|---|";
L(end+1) = sprintf("| a1 vs Y(T) | %.4f | %.4f | %.4f |", pY, sY, corrTbl.score_Y_vs_a1(1));
L(end+1) = sprintf("| a1 vs dS/dT | %.4f | %.4f | %.4f |", pDS, sDS, ...
    mean(abs([pDS, sDS]), 'omitnan'));
L(end+1) = sprintf("| Y(T) vs 1/T^2 | %.4f | %.4f | %.4f |", pI, sI, corrTbl.score_Y_vs_invT2(1));
L(end+1) = "";
L(end+1) = "## Peak Alignment";
L(end+1) = "";
L(end+1) = sprintf("| Observable | T_peak (abs) |");
L(end+1) = "|---|---|";
L(end+1) = sprintf("| a1(T) | %.2f K |", corrTbl.a1_peak_T_abs_K(1));
L(end+1) = sprintf("| Y(T) | %.2f K |", corrTbl.Y_peak_T_abs_K(1));
L(end+1) = sprintf("| dS_peak/dT | %.2f K |", corrTbl.dS_dT_peak_T_abs_K(1));
L(end+1) = sprintf("| Δ(Y − a1) | %.2f K |", corrTbl.delta_peak_Y_minus_a1_K(1));
L(end+1) = sprintf("| Δ(dS/dT − a1) | %.2f K |", corrTbl.delta_peak_dS_minus_a1_K(1));
L(end+1) = "";
L(end+1) = "## Fits";
L(end+1) = sprintf("- Through-origin `a1 = c × Y`: c = %.6g, R² = %.4f, RMSE = %.4g.", ...
    corrTbl.fit_Y_to_a1_origin_c(1), corrTbl.fit_Y_to_a1_origin_r2(1), corrTbl.fit_Y_to_a1_origin_rmse(1));
L(end+1) = sprintf("- Linear `a1 = m × Y + b`: m = %.6g, b = %.6g, R² = %.4f, RMSE = %.4g.", ...
    corrTbl.fit_Y_to_a1_slope(1), corrTbl.fit_Y_to_a1_intercept(1), corrTbl.fit_Y_to_a1_r2(1), corrTbl.fit_Y_to_a1_rmse(1));
L(end+1) = sprintf("- Through-origin `Y = c × (1/T²)`: c = %.6g, R² = %.4f, RMSE = %.4g.", ...
    corrTbl.fit_Y_vs_invT2_origin_c(1), corrTbl.fit_Y_vs_invT2_origin_r2(1), corrTbl.fit_Y_vs_invT2_origin_rmse(1));
L(end+1) = "";
L(end+1) = "## Interpretation";
L(end+1) = "";

% a1 vs Y interpretation
if isA1YStrong
    L(end+1) = sprintf("- **a1 vs Y(T)**: Strong correlation (Pearson=%.4f, Spearman=%.4f). a1(T) tracks the normalized rate of change of S_peak.", pY, sY);
else
    L(end+1) = sprintf("- **a1 vs Y(T)**: Weak or moderate correlation (Pearson=%.4f, Spearman=%.4f). a1(T) does not clearly track the normalized S_peak derivative.", pY, sY);
end

% Peak alignment interpretation
deltaPeakY = corrTbl.delta_peak_Y_minus_a1_K(1);
if abs(deltaPeakY) <= 2
    L(end+1) = sprintf("- **Peak alignment**: T_peak(|Y|) and T_peak(|a1|) are within %.2f K — consistent with a common susceptibility response.", abs(deltaPeakY));
elseif abs(deltaPeakY) <= 5
    L(end+1) = sprintf("- **Peak alignment**: T_peak(|Y|) − T_peak(|a1|) = %.2f K — modest offset; peaks are shifted but partially overlapping.", deltaPeakY);
else
    L(end+1) = sprintf("- **Peak alignment**: T_peak(|Y|) − T_peak(|a1|) = %.2f K — substantial offset, suggesting different underlying processes.", deltaPeakY);
end

% Activation scaling interpretation
if isActivationSupported
    L(end+1) = sprintf("- **Activation-like scaling**: Supported. Y(T) correlates significantly with 1/T² (Pearson=%.4f, Spearman=%.4f). This is consistent with S_peak(T) following Arrhenius-type growth.", pI, sI);
    L(end+1) = "  The proportionality constant c in `Y ≈ c/T²` gives a phenomenological scale E_a/k ≈ c.";
    L(end+1) = sprintf("  Estimated E_a/k ≈ %.4g K  (descriptive only; not a validated microscopic barrier).", corrTbl.fit_Y_vs_invT2_origin_c(1));
else
    L(end+1) = sprintf("- **Activation-like scaling**: Not supported. Y(T) does not correlate strongly with 1/T² (Pearson=%.4f, Spearman=%.4f). A simple Arrhenius model is inconsistent with S_peak(T) in this range.", pI, sI);
end

L(end+1) = "- Limitations: derivative estimates are sensitive to smoothing; grid is finite; correlation alone does not establish mechanism.";
L(end+1) = "";
L(end+1) = "## Artifacts";
L(end+1) = sprintf("- Correlation table: `%s`", string(corrPath));
L(end+1) = sprintf("- Series table: `%s`", string(seriesPath));
L(end+1) = sprintf("- Peaks table: `%s`", string(peakPath));
L(end+1) = sprintf("- Overlay figure: `%s`", string(figOverlay.png));
L(end+1) = sprintf("- Scatter a1 vs Y figure: `%s`", string(figScatterY.png));
L(end+1) = sprintf("- Scatter Y vs 1/T² figure: `%s`", string(figScatterInvT2.png));
L(end+1) = "";
L(end+1) = "![activation_overlay](../figures/activation_overlay.png)";
L(end+1) = "";
L(end+1) = "![activation_scatter_a1_vs_Y](../figures/activation_scatter_a1_vs_Y.png)";
L(end+1) = "";
L(end+1) = "![activation_scatter_Y_vs_invT2](../figures/activation_scatter_Y_vs_invT2.png)";
L(end+1) = "";
L(end+1) = "## Visualization choices";
L(end+1) = "- Figure 1: 3-curve signed-normalized overlay (a1, dS/dT, Y)";
L(end+1) = "- Figure 2: scatter a1 vs Y with through-origin and linear fits";
L(end+1) = "- Figure 3: scatter Y vs 1/T² with through-origin fit (activation check)";
L(end+1) = "- Smoothing: Savitzky-Golay before differentiation (same settings as switching_a1_vs_logdS_test)";
L(end+1) = "";
L(end+1) = "---";
L(end+1) = sprintf("Generated on: %s", char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

txt = strjoin(L, newline);
end

% -------------------------------------------------------------------------
%  Review ZIP
% -------------------------------------------------------------------------
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
    fullfile(runDir, 'figures',  'activation_overlay.png'), ...
    fullfile(runDir, 'figures',  'activation_scatter_a1_vs_Y.png'), ...
    fullfile(runDir, 'figures',  'activation_scatter_Y_vs_invT2.png'), ...
    fullfile(runDir, 'tables',   'activation_signature_correlations.csv'), ...
    fullfile(runDir, 'tables',   'activation_signature_series.csv'), ...
    fullfile(runDir, 'tables',   'activation_signature_peaks.csv'), ...
    fullfile(runDir, 'reports',  'activation_signature_report.md'), ...
    fullfile(runDir, 'run_manifest.json'), ...
    fullfile(runDir, 'config_snapshot.m'), ...
    fullfile(runDir, 'log.txt'), ...
    fullfile(runDir, 'run_notes.txt')};

existing = {};
for i = 1:numel(files)
    if exist(files{i}, 'file') == 2
        existing{end+1} = files{i}; %#ok<AGROW>
    end
end

if ~isempty(existing)
    zip(zipPath, existing, runDir);
end
end

% -------------------------------------------------------------------------
%  Utility helpers  (local to this file)
% -------------------------------------------------------------------------
function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('switching_activation_signature_test:appendFailed', ...
        'Unable to append to %s.', filePath);
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
