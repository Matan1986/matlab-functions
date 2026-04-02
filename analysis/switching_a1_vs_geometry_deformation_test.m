function out = switching_a1_vs_geometry_deformation_test(cfg)
% switching_a1_vs_geometry_deformation_test
% Test whether a1(T) corresponds to a geometric deformation of the switching
% ridge — i.e. whether it tracks dwidth/dT or dI_peak/dT rather than
% curvature or log-intensity dynamics.
%
% Loads:  a1(T), width(T), I_peak(T)
% Computes: dwidth/dT, dI_peak/dT
% Checks:   Pearson/Spearman correlations and peak alignment of each with a1(T).
% Output:   run_<timestamp>_switching_a1_geometry_deformation_test

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile    = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot    = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

cfg    = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg         = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset  = sprintf('a1:%s | switching:%s', ...
    char(source.a1RunName), char(source.switchRunName));
run    = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching a1-vs-geometry-deformation test run directory:\n%s\n', runDir);
fprintf('a1 source run: %s\n', source.a1RunName);
fprintf('Switching source run: %s\n', source.switchRunName);
appendText(run.log_path, sprintf('[%s] switching a1-vs-geometry-deformation test started\n', stampNow()));
appendText(run.log_path, sprintf('a1 source run: %s\n', char(source.a1RunName)));
appendText(run.log_path, sprintf('switching source run: %s\n', char(source.switchRunName)));

% ── Load and align ─────────────────────────────────────────────────────────
a1Data  = loadA1Data(source.a1Path, cfg.a1ColumnName);
obsData = loadSwitchingObservables(source.switchPath);

[T, iA1, iObs] = intersect(a1Data.T_K, obsData.T_K, 'stable');
if isempty(T)
    error('No common temperatures between a1 source and switching observables source.');
end

a1    = double(a1Data.a1(iA1));
Ipeak = double(obsData.I_peak_mA(iObs));
width = double(obsData.width_mA(iObs));

maskRange = T >= cfg.temperatureMinK & T <= cfg.temperatureMaxK;
T     = double(T(maskRange));
a1    = a1(maskRange);
Ipeak = Ipeak(maskRange);
width = width(maskRange);

if numel(T) < 5
    error('Need at least 5 temperature points after alignment/range filtering.');
end

a1    = fillByInterp(T, a1);
Ipeak = fillByInterp(T, Ipeak);
width = fillByInterp(T, width);

% ── Derivatives ────────────────────────────────────────────────────────────
[dIpeak_raw, dIpeak, Ipeak_smooth, methodIpeak] = derivativeProfiles(T, Ipeak, cfg);
[dwidth_raw,  dwidth,  width_smooth,  methodWidth]  = derivativeProfiles(T, width,  cfg);

valid = isfinite(T) & isfinite(a1) & isfinite(dIpeak) & isfinite(dwidth);
if nnz(valid) < 3
    error('Insufficient finite points for correlation after preprocessing.');
end

Tv      = T(valid);
a1v     = a1(valid);
dIpeakv = dIpeak(valid);
dwidthv = dwidth(valid);

% ── Correlations ───────────────────────────────────────────────────────────
pearsonIpeak  = safeCorr(a1v, dIpeakv, 'Pearson');
spearmanIpeak = safeCorr(a1v, dIpeakv, 'Spearman');
pearsonWidth  = safeCorr(a1v, dwidthv, 'Pearson');
spearmanWidth = safeCorr(a1v, dwidthv, 'Spearman');

% ── Peak alignment ─────────────────────────────────────────────────────────
[a1PeakTAbs,     ~] = peakOf(Tv, a1v,     true);
[dIpeakPeakTAbs, ~] = peakOf(Tv, dIpeakv, true);
[dwidthPeakTAbs, ~] = peakOf(Tv, dwidthv, true);
deltaPeakIpeak_K = dIpeakPeakTAbs - a1PeakTAbs;
deltaPeakWidth_K = dwidthPeakTAbs - a1PeakTAbs;

% ── Fits ───────────────────────────────────────────────────────────────────
[cI0, yHatI0, residI0, r2I0, rmseI0]          = fitThroughOrigin(dIpeakv, a1v);
[mI1, bI1, yHatI1, residI1, r2I1, rmseI1]     = fitOrdinaryLinear(dIpeakv, a1v);
[cW0, yHatW0, residW0, r2W0, rmseW0]          = fitThroughOrigin(dwidthv, a1v);
[mW1, bW1, yHatW1, residW1, r2W1, rmseW1]     = fitOrdinaryLinear(dwidthv, a1v);

% ── Which geometric observable better tracks a1? ───────────────────────────
scoreIpeak = mean(abs([pearsonIpeak, spearmanIpeak]), 'omitnan');
scoreWidth = mean(abs([pearsonWidth, spearmanWidth]), 'omitnan');
if scoreIpeak >= scoreWidth
    betterBy = "dI_peak/dT";
else
    betterBy = "dwidth/dT";
end

% ── Tables ─────────────────────────────────────────────────────────────────
corrTbl = table( ...
    nnz(valid), ...
    pearsonIpeak, spearmanIpeak, scoreIpeak, ...
    pearsonWidth,  spearmanWidth,  scoreWidth, ...
    betterBy, ...
    a1PeakTAbs, dIpeakPeakTAbs, dwidthPeakTAbs, ...
    deltaPeakIpeak_K, deltaPeakWidth_K, ...
    cI0, r2I0, rmseI0, mI1, bI1, r2I1, rmseI1, ...
    cW0, r2W0, rmseW0, mW1, bW1, r2W1, rmseW1, ...
    cfg.sgolayPolynomialOrder, cfg.sgolayFrameLength, ...
    string(methodIpeak), string(methodWidth), ...
    source.a1RunName, source.switchRunName, ...
    string(source.a1Path), string(source.switchPath), ...
    'VariableNames', { ...
    'n_points', ...
    'pearson_a1_vs_dIpeak_dT', 'spearman_a1_vs_dIpeak_dT', 'score_dIpeak', ...
    'pearson_a1_vs_dwidth_dT', 'spearman_a1_vs_dwidth_dT', 'score_dwidth', ...
    'better_described_by', ...
    'a1_peak_T_abs_K', 'dIpeak_dT_peak_T_abs_K', 'dwidth_dT_peak_T_abs_K', ...
    'delta_peak_T_Ipeak_K', 'delta_peak_T_width_K', ...
    'fit_origin_Ipeak_c',  'fit_origin_Ipeak_r2',  'fit_origin_Ipeak_rmse', ...
    'fit_linear_Ipeak_slope', 'fit_linear_Ipeak_intercept', 'fit_linear_Ipeak_r2', 'fit_linear_Ipeak_rmse', ...
    'fit_origin_width_c',  'fit_origin_width_r2',  'fit_origin_width_rmse', ...
    'fit_linear_width_slope', 'fit_linear_width_intercept', 'fit_linear_width_r2', 'fit_linear_width_rmse', ...
    'sgolay_polynomial_order', 'sgolay_frame_length', ...
    'derivative_method_Ipeak', 'derivative_method_width', ...
    'a1_source_run', 'switching_source_run', 'a1_source_file', 'switching_source_file'});

seriesTbl = table( ...
    Tv, a1v, ...
    Ipeak(valid), Ipeak_smooth(valid), dIpeak_raw(valid), dIpeakv, ...
    width(valid),  width_smooth(valid),  dwidth_raw(valid),  dwidthv, ...
    yHatI0, residI0, yHatI1, residI1, ...
    yHatW0, residW0, yHatW1, residW1, ...
    normalizeSigned(a1v), normalizeSigned(dIpeakv), normalizeSigned(dwidthv), ...
    normalize01(abs(a1v)), normalize01(abs(dIpeakv)), normalize01(abs(dwidthv)), ...
    'VariableNames', { ...
    'T_K', 'a1', ...
    'I_peak_mA', 'I_peak_smoothed', 'dIpeak_dT_raw', 'dIpeak_dT_smoothed', ...
    'width_mA',  'width_smoothed',  'dwidth_dT_raw',  'dwidth_dT_smoothed', ...
    'a1_fit_origin_from_dIpeak', 'fit_origin_Ipeak_residual', ...
    'a1_fit_linear_from_dIpeak', 'fit_linear_Ipeak_residual', ...
    'a1_fit_origin_from_dwidth', 'fit_origin_width_residual', ...
    'a1_fit_linear_from_dwidth', 'fit_linear_width_residual', ...
    'a1_norm_signed', 'dIpeak_dT_norm_signed', 'dwidth_dT_norm_signed', ...
    'a1_abs_norm', 'dIpeak_dT_abs_norm', 'dwidth_dT_abs_norm'});

corrPath   = save_run_table(corrTbl,   'a1_vs_geometry_deformation_correlation.csv', runDir);
seriesPath = save_run_table(seriesTbl, 'a1_vs_geometry_deformation_series.csv',      runDir);

% ── Figures ────────────────────────────────────────────────────────────────
figOverlay  = saveOverlayFigure(Tv, a1v, dIpeakv, dwidthv, corrTbl, runDir);
figScatterI = saveScatterFigure(dIpeakv, a1v, pearsonIpeak, spearmanIpeak, runDir, ...
    'a1_vs_dIpeak_scatter', 'dI_{peak}/dT  (mA K^{-1})', 'a_1(T)');
figScatterW = saveScatterFigure(dwidthv, a1v, pearsonWidth, spearmanWidth, runDir, ...
    'a1_vs_dwidth_scatter', 'dwidth/dT  (mA K^{-1})', 'a_1(T)');

% ── Report & zip ───────────────────────────────────────────────────────────
reportText = buildReportText(source, cfg, corrTbl, ...
    figOverlay, figScatterI, figScatterW, corrPath, seriesPath);
reportPath = save_run_report(reportText, 'a1_vs_geometry_deformation_report.md', runDir);

zipPath = buildReviewZip(runDir, 'switching_a1_geometry_deformation_test_bundle.zip');

% ── Notes & log ────────────────────────────────────────────────────────────
appendText(run.notes_path, sprintf('a1 source run = %s\n', char(source.a1RunName)));
appendText(run.notes_path, sprintf('switching source run = %s\n', char(source.switchRunName)));
appendText(run.notes_path, sprintf('pearson(a1,dIpeak/dT) = %.6f\n', pearsonIpeak));
appendText(run.notes_path, sprintf('spearman(a1,dIpeak/dT) = %.6f\n', spearmanIpeak));
appendText(run.notes_path, sprintf('pearson(a1,dwidth/dT) = %.6f\n', pearsonWidth));
appendText(run.notes_path, sprintf('spearman(a1,dwidth/dT) = %.6f\n', spearmanWidth));
appendText(run.notes_path, sprintf('|peak_T(a1)| = %.2f K\n', a1PeakTAbs));
appendText(run.notes_path, sprintf('|peak_T(dIpeak/dT)| = %.2f K  delta = %.2f K\n', dIpeakPeakTAbs, deltaPeakIpeak_K));
appendText(run.notes_path, sprintf('|peak_T(dwidth/dT)| = %.2f K  delta = %.2f K\n', dwidthPeakTAbs,  deltaPeakWidth_K));
appendText(run.notes_path, sprintf('better described by = %s\n', char(betterBy)));
appendText(run.notes_path, sprintf('correlation table = %s\n', corrPath));
appendText(run.notes_path, sprintf('series table = %s\n', seriesPath));
appendText(run.notes_path, sprintf('overlay figure = %s\n', figOverlay.png));
appendText(run.notes_path, sprintf('report = %s\n', reportPath));
appendText(run.notes_path, sprintf('zip = %s\n', zipPath));

appendText(run.log_path, sprintf('[%s] switching a1-vs-geometry-deformation test complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlation table: %s\n', corrPath));
appendText(run.log_path, sprintf('Series table: %s\n', seriesPath));
appendText(run.log_path, sprintf('Overlay figure: %s\n', figOverlay.png));
appendText(run.log_path, sprintf('Scatter I_peak: %s\n', figScatterI.png));
appendText(run.log_path, sprintf('Scatter width: %s\n', figScatterW.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

% ── Output struct ──────────────────────────────────────────────────────────
out = struct();
out.run    = run;
out.runDir = string(runDir);
out.source = source;
out.metrics = struct( ...
    'pearson_dIpeak',      pearsonIpeak, ...
    'spearman_dIpeak',     spearmanIpeak, ...
    'pearson_dwidth',      pearsonWidth, ...
    'spearman_dwidth',     spearmanWidth, ...
    'betterBy',            betterBy, ...
    'a1_peak_T_abs_K',     a1PeakTAbs, ...
    'dIpeak_peak_T_abs_K', dIpeakPeakTAbs, ...
    'dwidth_peak_T_abs_K', dwidthPeakTAbs, ...
    'delta_peak_Ipeak_K',  deltaPeakIpeak_K, ...
    'delta_peak_width_K',  deltaPeakWidth_K);
out.paths = struct( ...
    'correlation', string(corrPath), ...
    'series',      string(seriesPath), ...
    'overlay',     string(figOverlay.png), ...
    'scatterIpeak',string(figScatterI.png), ...
    'scatterWidth',string(figScatterW.png), ...
    'report',      string(reportPath), ...
    'zip',         string(zipPath));

fprintf('\n=== Switching a1-vs-geometry-deformation test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson(a1,dIpeak/dT):  %.6f\n', pearsonIpeak);
fprintf('Spearman(a1,dIpeak/dT): %.6f\n', spearmanIpeak);
fprintf('Pearson(a1,dwidth/dT):  %.6f\n', pearsonWidth);
fprintf('Spearman(a1,dwidth/dT): %.6f\n', spearmanWidth);
fprintf('Better described by: %s\n', betterBy);
fprintf('Correlation table: %s\n', corrPath);
fprintf('Overlay figure: %s\n', figOverlay.png);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

% ═══════════════════════════════════════════════════════════════════════════
% Configuration helpers
% ═══════════════════════════════════════════════════════════════════════════

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel',               'switching_a1_geometry_deformation_test');
cfg = setDefaultField(cfg, 'a1RunName',              'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'switchRunName',          'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefaultField(cfg, 'a1ColumnName',           'a_1');
cfg = setDefaultField(cfg, 'temperatureMinK',        4);
cfg = setDefaultField(cfg, 'temperatureMaxK',        30);
cfg = setDefaultField(cfg, 'sgolayPolynomialOrder',  2);
cfg = setDefaultField(cfg, 'sgolayFrameLength',      5);
cfg = setDefaultField(cfg, 'movmeanWindow',          3);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.a1RunName     = string(cfg.a1RunName);
source.switchRunName = string(cfg.switchRunName);

source.phi1Guard = enforce_canonical_phi1_source({source.a1RunName}, 'switching_a1_vs_geometry_deformation_test');

source.a1RunDir     = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.a1RunName));
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

% ═══════════════════════════════════════════════════════════════════════════
% Data loading helpers
% ═══════════════════════════════════════════════════════════════════════════

function data = loadA1Data(pathValue, a1ColumnName)
tbl = readtable(pathValue);
if ~ismember('T_K', tbl.Properties.VariableNames)
    error('a1 table missing T_K column: %s', pathValue);
end
if ~ismember(a1ColumnName, tbl.Properties.VariableNames)
    error('a1 table missing requested column %s: %s', a1ColumnName, pathValue);
end
tbl = sortrows(tbl, 'T_K');
data     = struct();
data.T_K = double(tbl.T_K(:));
data.a1  = double(tbl.(a1ColumnName)(:));
end

function data = loadSwitchingObservables(pathValue)
tbl = readtable(pathValue);
tbl = normalizeSwitchingTable(tbl);

required = {'T_K', 'I_peak_mA', 'width_mA'};
for i = 1:numel(required)
    if ~ismember(required{i}, tbl.Properties.VariableNames)
        error('Switching table missing required column "%s": %s', required{i}, pathValue);
    end
end

tbl = sortrows(tbl, 'T_K');
data            = struct();
data.T_K        = double(tbl.T_K(:));
data.I_peak_mA  = double(tbl.I_peak_mA(:));
data.width_mA   = double(tbl.width_mA(:));
end

function tblOut = normalizeSwitchingTable(tblIn)
tbl  = tblIn;
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
width  = NaN(n, 1);
for i = 1:n
    t    = T(i);
    rows = tblLong(double(tblLong.temperature) == t, :);
    obs  = lower(string(rows.observable));
    vals = double(rows.value);
    I_peak(i) = firstValue(obs, vals, ["i_peak"]);
    width(i)  = firstValue(obs, vals, ["width_i", "width"]);
end

tbl = table(T, I_peak, width, ...
    'VariableNames', {'T_K', 'I_peak_mA', 'width_mA'});
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

% ═══════════════════════════════════════════════════════════════════════════
% Signal processing helpers
% ═══════════════════════════════════════════════════════════════════════════

function y = fillByInterp(x, yIn)
y    = yIn(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    return;
end
if any(~mask)
    y(~mask) = interp1(x(mask), y(mask), x(~mask), 'linear', 'extrap');
end
end

function [dRaw, dSmooth, ySmooth, methodText] = derivativeProfiles(x, y, cfg)
x    = x(:);
y    = y(:);
dRaw = gradient(y, x);
ySmooth    = y;
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

% ═══════════════════════════════════════════════════════════════════════════
% Statistics helpers
% ═══════════════════════════════════════════════════════════════════════════

function c = safeCorr(x, y, corrType)
x    = x(:);
y    = y(:);
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
x    = x(:);
y    = y(:);
mask = isfinite(x) & isfinite(y);
x    = x(mask);
y    = y(mask);

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
sse       = sum(residuals .^ 2);
sst       = sum((y - mean(y, 'omitnan')) .^ 2);
r2        = 1 - (sse / max(sst, eps));
rmse      = sqrt(mean(residuals .^ 2, 'omitnan'));
end

function [slope, intercept, yHat, residuals, r2, rmse] = fitOrdinaryLinear(x, y)
x    = x(:);
y    = y(:);
mask = isfinite(x) & isfinite(y);
x    = x(mask);
y    = y(mask);

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
sse       = sum(residuals .^ 2);
sst       = sum((y - mean(y, 'omitnan')) .^ 2);
r2        = 1 - (sse / max(sst, eps));
rmse      = sqrt(mean(residuals .^ 2, 'omitnan'));
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

% ═══════════════════════════════════════════════════════════════════════════
% Figure helpers
% ═══════════════════════════════════════════════════════════════════════════

function figOut = saveOverlayFigure(T, a1, dIpeak, dwidth, corrTbl, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 14 10.5]);
ax  = axes(fig);
hold(ax, 'on');
plot(ax, T, normalizeSigned(a1), '-o', ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'DisplayName', 'a_1(T) signed-norm');
plot(ax, T, normalizeSigned(dIpeak), '-s', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'DisplayName', 'dI_{peak}/dT signed-norm');
plot(ax, T, normalizeSigned(dwidth), '-^', ...
    'Color', [0.47 0.67 0.19], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.47 0.67 0.19], ...
    'DisplayName', 'dwidth/dT signed-norm');
plot(ax, T, normalize01(abs(a1)), '--', ...
    'Color', [0.20 0.20 0.20], 'LineWidth', 1.8, ...
    'DisplayName', '|a_1(T)| norm');
yline(ax, 0, '-', 'LineWidth', 1.0, 'Color', [0.70 0.70 0.70]);
hold(ax, 'off');

xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalized amplitude',  'FontSize', 14);
title(ax, sprintf('a_1(T) vs geometric deformation derivatives  |  r(I)=%.3f  r(w)=%.3f  \x0394T_{pk}(I)=%.1f K  \x0394T_{pk}(w)=%.1f K', ...
    corrTbl.pearson_a1_vs_dIpeak_dT(1), corrTbl.pearson_a1_vs_dwidth_dT(1), ...
    corrTbl.delta_peak_T_Ipeak_K(1),    corrTbl.delta_peak_T_width_K(1)), ...
    'FontSize', 11);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 10);

figOut = robustSaveFigure(fig, 'a1_vs_geometry_deformation_overlay', runDir);
close(fig);
end

function figOut = saveScatterFigure(xData, yData, pearsonR, spearmanRho, runDir, baseName, xLabel, yLabel)
fig = create_figure('Visible', 'off', 'Position', [2 2 12 10]);
ax  = axes(fig);
hold(ax, 'on');
scatter(ax, xData, yData, 64, 'filled', ...
    'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerEdgeColor', [0.00 0.45 0.74], ...
    'DisplayName', 'Data points');

m = isfinite(xData) & isfinite(yData);
if nnz(m) >= 2
    p  = polyfit(xData(m), yData(m), 1);
    xg = linspace(min(xData(m)), max(xData(m)), 200);
    yg = polyval(p, xg);
    plot(ax, xg, yg, '-', 'LineWidth', 2.2, 'Color', [0.85 0.33 0.10], ...
        'DisplayName', sprintf('Linear fit: slope=%.3g', p(1)));
end

xlabel(ax, xLabel, 'FontSize', 14);
ylabel(ax, yLabel, 'FontSize', 14);
title(ax, sprintf('%s vs %s', strtrim(yLabel), strtrim(xLabel)), 'FontSize', 13);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 10);

xL    = xlim(ax);
yL    = ylim(ax);
textX = xL(1) + 0.03 * (xL(2) - xL(1));
textY = yL(2) - 0.06 * (yL(2) - yL(1));
text(ax, textX, textY, ...
    sprintf('Pearson r = %.4f\nSpearman \x03C1 = %.4f', pearsonR, spearmanRho), ...
    'VerticalAlignment', 'top', 'FontSize', 11, ...
    'BackgroundColor', [1 1 1], 'EdgeColor', [0.8 0.8 0.8], 'Margin', 6);

hold(ax, 'off');
figOut = robustSaveFigure(fig, baseName, runDir);
close(fig);
end

function figOut = robustSaveFigure(fig, baseName, runDir)
try
    figOut = save_run_figure(fig, baseName, runDir);
catch ME
    warning('switching_a1_vs_geometry_deformation_test:saveFigureFallback', ...
        'save_run_figure failed (%s); using fallback export.', ME.message);
    figuresDir = fullfile(runDir, 'figures');
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    figOut     = struct();
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

% ═══════════════════════════════════════════════════════════════════════════
% Report helper
% ═══════════════════════════════════════════════════════════════════════════

function reportText = buildReportText(source, cfg, corrTbl, figOverlay, figScatterI, figScatterW, corrPath, seriesPath)
pI = corrTbl.pearson_a1_vs_dIpeak_dT(1);
sI = corrTbl.spearman_a1_vs_dIpeak_dT(1);
pW = corrTbl.pearson_a1_vs_dwidth_dT(1);
sW = corrTbl.spearman_a1_vs_dwidth_dT(1);

scoreI = corrTbl.score_dIpeak(1);
scoreW = corrTbl.score_dwidth(1);

betterBy = string(corrTbl.better_described_by(1));

% Strength classification
function s = classify(p, sp)
    if isfinite(p) && isfinite(sp) && abs(p) >= 0.7 && abs(sp) >= 0.7
        s = "strong";
    elseif isfinite(p) && isfinite(sp) && abs(p) >= 0.5 && abs(sp) >= 0.5
        s = "moderate";
    else
        s = "weak";
    end
end

strengthI = classify(pI, sI);
strengthW = classify(pW, sW);

if strengthI == "strong" && abs(corrTbl.delta_peak_T_Ipeak_K(1)) <= 4
    conclusionI = "a1(T) is consistent with a ridge positional deformation in I_peak direction.";
elseif strengthI == "strong" || strengthI == "moderate"
    conclusionI = "Nontrivial coupling to dI_peak/dT but peak timing mismatch limits strict ridge-deformation interpretation.";
else
    conclusionI = "No clear support for dI_peak/dT as driver of a1.";
end

if strengthW == "strong" && abs(corrTbl.delta_peak_T_width_K(1)) <= 4
    conclusionW = "a1(T) is consistent with a width-deformation mode of the switching ridge.";
elseif strengthW == "strong" || strengthW == "moderate"
    conclusionW = "Nontrivial coupling to dwidth/dT but peak timing mismatch limits strict width-deformation interpretation.";
else
    conclusionW = "No clear support for dwidth/dT as driver of a1.";
end

lines = strings(0, 1);
lines(end+1) = "# a1(T) vs geometric deformation of the switching ridge";
lines(end+1) = "";
lines(end+1) = "## Hypothesis";
lines(end+1) = "Test whether a1(T) reflects a ridge shape-deformation observable — specifically";
lines(end+1) = "the temperature derivatives of the ridge position (dI_peak/dT) or ridge width (dwidth/dT) —";
lines(end+1) = "rather than curvature or log-intensity dynamics.";
lines(end+1) = "";
lines(end+1) = "## Sources";
lines(end+1) = "- a1 source run: `" + source.a1RunName + "`";
lines(end+1) = "- switching observables source run: `" + source.switchRunName + "`";
lines(end+1) = "- a1 source file: `" + string(source.a1Path) + "`";
lines(end+1) = "- switching source file: `" + string(source.switchPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Method";
lines(end+1) = "- Temperature range: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`.";
lines(end+1) = "- Computed `dI_peak/dT` and `dwidth/dT` from the smoothed I_peak(T) and width(T) traces.";
lines(end+1) = "- Derivative smoothing: Savitzky-Golay with polynomial order `" + ...
    string(cfg.sgolayPolynomialOrder) + "` and frame `" + string(cfg.sgolayFrameLength) + "`; derivative via `gradient`.";
lines(end+1) = "- Correlations and linear fits computed independently for each derivative.";
lines(end+1) = "";
lines(end+1) = "## Results — dI_peak/dT";
lines(end+1) = sprintf("- Pearson corr(`a1`, `dI_peak/dT`) = `%.6f` (%s).", pI, strengthI);
lines(end+1) = sprintf("- Spearman corr(`a1`, `dI_peak/dT`) = `%.6f`.", sI);
lines(end+1) = sprintf("- Score (mean |r|) = `%.4f`.", scoreI);
lines(end+1) = sprintf("- `T_peak(|a1|) = %.2f K`,  `T_peak(|dI_peak/dT|) = %.2f K`,  `delta = %.2f K`.", ...
    corrTbl.a1_peak_T_abs_K(1), corrTbl.dIpeak_dT_peak_T_abs_K(1), corrTbl.delta_peak_T_Ipeak_K(1));
lines(end+1) = "- Through-origin fit `a1 = c*(dI_peak/dT)`: `c = " + ...
    sprintf('%.6g', corrTbl.fit_origin_Ipeak_c(1)) + "`,  `R^2 = " + ...
    sprintf('%.4f', corrTbl.fit_origin_Ipeak_r2(1)) + "`.";
lines(end+1) = "- Ordinary linear fit: `slope = " + ...
    sprintf('%.6g', corrTbl.fit_linear_Ipeak_slope(1)) + "`,  `R^2 = " + ...
    sprintf('%.4f', corrTbl.fit_linear_Ipeak_r2(1)) + "`.";
lines(end+1) = "- **" + conclusionI + "**";
lines(end+1) = "";
lines(end+1) = "## Results — dwidth/dT";
lines(end+1) = sprintf("- Pearson corr(`a1`, `dwidth/dT`) = `%.6f` (%s).", pW, strengthW);
lines(end+1) = sprintf("- Spearman corr(`a1`, `dwidth/dT`) = `%.6f`.", sW);
lines(end+1) = sprintf("- Score (mean |r|) = `%.4f`.", scoreW);
lines(end+1) = sprintf("- `T_peak(|a1|) = %.2f K`,  `T_peak(|dwidth/dT|) = %.2f K`,  `delta = %.2f K`.", ...
    corrTbl.a1_peak_T_abs_K(1), corrTbl.dwidth_dT_peak_T_abs_K(1), corrTbl.delta_peak_T_width_K(1));
lines(end+1) = "- Through-origin fit `a1 = c*(dwidth/dT)`: `c = " + ...
    sprintf('%.6g', corrTbl.fit_origin_width_c(1)) + "`,  `R^2 = " + ...
    sprintf('%.4f', corrTbl.fit_origin_width_r2(1)) + "`.";
lines(end+1) = "- Ordinary linear fit: `slope = " + ...
    sprintf('%.6g', corrTbl.fit_linear_width_slope(1)) + "`,  `R^2 = " + ...
    sprintf('%.4f', corrTbl.fit_linear_width_r2(1)) + "`.";
lines(end+1) = "- **" + conclusionW + "**";
lines(end+1) = "";
lines(end+1) = "## Summary";
lines(end+1) = "- a1(T) is better described by: **`" + betterBy + "`** (higher mean |r| = `" + ...
    sprintf('%.4f', max(scoreI, scoreW)) + "`).";
lines(end+1) = "- Limitations: correlation-only evidence; derivative sensitivity to smoothing/windowing; finite temperature grid.";
lines(end+1) = "";
lines(end+1) = "## Artifacts";
lines(end+1) = "- Correlation table: `" + string(corrPath) + "`";
lines(end+1) = "- Aligned-series table: `" + string(seriesPath) + "`";
lines(end+1) = "- Overlay figure: `" + string(figOverlay.png) + "`";
lines(end+1) = "- Scatter (I_peak): `" + string(figScatterI.png) + "`";
lines(end+1) = "- Scatter (width): `" + string(figScatterW.png) + "`";
lines(end+1) = "";
lines(end+1) = "![a1_vs_geometry_deformation_overlay](../figures/a1_vs_geometry_deformation_overlay.png)";
lines(end+1) = "";
lines(end+1) = "![a1_vs_dIpeak_scatter](../figures/a1_vs_dIpeak_scatter.png)";
lines(end+1) = "";
lines(end+1) = "![a1_vs_dwidth_scatter](../figures/a1_vs_dwidth_scatter.png)";
lines(end+1) = "";
lines(end+1) = "## Visualization choices";
lines(end+1) = "- Overlay: 4 signed-normalized curves (a1, dI_peak/dT, dwidth/dT, |a1| abs-norm)";
lines(end+1) = "- Scatter panels: one per derivative + OLS line + Pearson/Spearman annotation";
lines(end+1) = "- legend vs colormap: legend used (<= 6 curves)";
lines(end+1) = "- smoothing applied: Savitzky-Golay (`p=2`, `frame=5`) before derivative";
lines(end+1) = "";
lines(end+1) = "---";
lines(end+1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

% ═══════════════════════════════════════════════════════════════════════════
% ZIP helper
% ═══════════════════════════════════════════════════════════════════════════

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
    fullfile(runDir, 'figures', 'a1_vs_geometry_deformation_overlay.png'), ...
    fullfile(runDir, 'figures', 'a1_vs_dIpeak_scatter.png'), ...
    fullfile(runDir, 'figures', 'a1_vs_dwidth_scatter.png'), ...
    fullfile(runDir, 'tables',  'a1_vs_geometry_deformation_correlation.csv'), ...
    fullfile(runDir, 'tables',  'a1_vs_geometry_deformation_series.csv'), ...
    fullfile(runDir, 'reports', 'a1_vs_geometry_deformation_report.md'), ...
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

% ═══════════════════════════════════════════════════════════════════════════
% Shared utilities
% ═══════════════════════════════════════════════════════════════════════════

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
