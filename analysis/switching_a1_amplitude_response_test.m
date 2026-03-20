function out = switching_a1_amplitude_response_test(cfg)
% switching_a1_amplitude_response_test
%
% Test whether the dynamic mode a1(T) represents temperature susceptibility
% of the switching amplitude S_peak(T).
%
% Tests:
%   a1(T) vs dS_peak/dT         -- first derivative (amplitude susceptibility)
%   a1(T) vs d2S_peak/dT2       -- second derivative (curvature in temperature space)
%
% For each pairing:
%   - Pearson and Spearman correlations
%   - Peak alignment: T at max |a1| vs T at max |derivative|
%   - Through-origin and ordinary linear fits
%
% Run label: switching_a1_amplitude_response_test

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

cfg    = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg          = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset  = sprintf('a1:%s | switching:%s', ...
    char(source.a1RunName), char(source.switchRunName));
run    = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching a1 amplitude-response test run directory:\n%s\n', runDir);
fprintf('a1 source run:       %s\n', char(source.a1RunName));
fprintf('Switching source run: %s\n', char(source.switchRunName));
appendText(run.log_path, sprintf('[%s] switching a1 amplitude-response test started\n', stampNow()));
appendText(run.log_path, sprintf('a1 source run: %s\n',       char(source.a1RunName)));
appendText(run.log_path, sprintf('switching source run: %s\n', char(source.switchRunName)));

% -----------------------------------------------------------------------
% Load and align data
% -----------------------------------------------------------------------
a1Data  = loadA1Data(source.a1Path, cfg.a1ColumnName);
obsData = loadSwitchingObservables(source.switchPath);

[T, iA1, iObs] = intersect(a1Data.T_K, obsData.T_K, 'stable');
if isempty(T)
    error('No common temperatures between a1 source and switching observables source.');
end

a1    = double(a1Data.a1(iA1));
Speak = double(obsData.S_peak(iObs));

% Temperature range filter
maskRange = T >= cfg.temperatureMinK & T <= cfg.temperatureMaxK;
T     = double(T(maskRange));
a1    = a1(maskRange);
Speak = Speak(maskRange);

if numel(T) < 5
    error('Need at least 5 temperature points after alignment/range filtering.');
end

% Fill isolated NaN by interpolation
a1    = fillByInterp(T, a1);
Speak = fillByInterp(T, Speak);

% -----------------------------------------------------------------------
% Compute first and second derivatives of S_peak(T)
% -----------------------------------------------------------------------
[dS_raw, dS, S_smooth, derivMethod1] = firstDerivProfiles(T, Speak, cfg);
[d2S_raw, d2S,         derivMethod2] = secondDerivProfiles(T, Speak, cfg);

% -----------------------------------------------------------------------
% Valid mask (require all quantities finite)
% -----------------------------------------------------------------------
valid = isfinite(T) & isfinite(a1) & isfinite(dS) & isfinite(d2S);
if nnz(valid) < 3
    error('Insufficient finite points for correlation after preprocessing.');
end

Tv        = T(valid);
a1v       = a1(valid);
Speakv    = Speak(valid);
S_smoothv = S_smooth(valid);
dS_rawv   = dS_raw(valid);
dSv       = dS(valid);
d2S_rawv  = d2S_raw(valid);
d2Sv      = d2S(valid);

% -----------------------------------------------------------------------
% Correlations
% -----------------------------------------------------------------------
pearson_dS   = safeCorr(a1v, dSv,  'Pearson');
spearman_dS  = safeCorr(a1v, dSv,  'Spearman');
pearson_d2S  = safeCorr(a1v, d2Sv, 'Pearson');
spearman_d2S = safeCorr(a1v, d2Sv, 'Spearman');

% -----------------------------------------------------------------------
% Peak alignment
% -----------------------------------------------------------------------
[a1PeakT,  ~] = peakOf(Tv, a1v,  true);
[dSPeakT,  ~] = peakOf(Tv, dSv,  true);
[d2SPeakT, ~] = peakOf(Tv, d2Sv, true);

deltaPeak_dS  = dSPeakT  - a1PeakT;
deltaPeak_d2S = d2SPeakT - a1PeakT;

% -----------------------------------------------------------------------
% Linear fits: a1 ~ f(dS/dT) and a1 ~ f(d2S/dT2)
% -----------------------------------------------------------------------
[c0_dS,   yHat0_dS,   res0_dS,   r2_c0_dS,   rmse_c0_dS  ] = fitThroughOrigin(dSv,  a1v);
[m1_dS,   b1_dS,      yHat1_dS,  res1_dS,    r2_l1_dS,  rmse_l1_dS ] = fitOrdinaryLinear(dSv,  a1v);
[c0_d2S,  yHat0_d2S,  res0_d2S,  r2_c0_d2S,  rmse_c0_d2S ] = fitThroughOrigin(d2Sv, a1v);
[m1_d2S,  b1_d2S,     yHat1_d2S, res1_d2S,   r2_l1_d2S, rmse_l1_d2S] = fitOrdinaryLinear(d2Sv, a1v);

% -----------------------------------------------------------------------
% Scoring: which derivative better tracks a1?
% -----------------------------------------------------------------------
score_dS  = mean(abs([pearson_dS,  spearman_dS ]), 'omitnan');
score_d2S = mean(abs([pearson_d2S, spearman_d2S]), 'omitnan');

if score_dS >= score_d2S
    betterBy = "dS_peak/dT";
else
    betterBy = "d2S_peak/dT2";
end

isStrong_dS  = isfinite(pearson_dS)  && isfinite(spearman_dS)  && ...
               abs(pearson_dS)  >= cfg.strongCorrThreshold && ...
               abs(spearman_dS) >= cfg.strongCorrThreshold;
isStrong_d2S = isfinite(pearson_d2S) && isfinite(spearman_d2S) && ...
               abs(pearson_d2S) >= cfg.strongCorrThreshold && ...
               abs(spearman_d2S) >= cfg.strongCorrThreshold;

% -----------------------------------------------------------------------
% Correlation table
% -----------------------------------------------------------------------
corrTbl = table( ...
    nnz(valid), ...
    pearson_dS,  spearman_dS,  score_dS, ...
    dSPeakT,  deltaPeak_dS, ...
    c0_dS,  r2_c0_dS,  rmse_c0_dS, ...
    m1_dS,  b1_dS,     r2_l1_dS,  rmse_l1_dS, ...
    pearson_d2S, spearman_d2S, score_d2S, ...
    d2SPeakT, deltaPeak_d2S, ...
    c0_d2S, r2_c0_d2S, rmse_c0_d2S, ...
    m1_d2S, b1_d2S,    r2_l1_d2S, rmse_l1_d2S, ...
    a1PeakT, betterBy, ...
    string(cfg.a1ColumnName), ...
    string(derivMethod1), string(derivMethod2), ...
    cfg.sgolayPolynomialOrder, cfg.sgolayFrameLength, ...
    source.a1RunName, source.switchRunName, ...
    string(source.a1Path), string(source.switchPath), ...
    'VariableNames', { ...
    'n_points', ...
    'pearson_a1_vs_dS_dT',   'spearman_a1_vs_dS_dT',   'score_first_derivative', ...
    'dS_dT_peak_T_K',        'delta_peak_T_dS_K', ...
    'fit_origin_c_dS',       'fit_origin_r2_dS',  'fit_origin_rmse_dS', ...
    'fit_slope_dS',          'fit_intercept_dS',   'fit_r2_dS',  'fit_rmse_dS', ...
    'pearson_a1_vs_d2S_dT2', 'spearman_a1_vs_d2S_dT2', 'score_second_derivative', ...
    'd2S_dT2_peak_T_K',      'delta_peak_T_d2S_K', ...
    'fit_origin_c_d2S',      'fit_origin_r2_d2S', 'fit_origin_rmse_d2S', ...
    'fit_slope_d2S',         'fit_intercept_d2S',  'fit_r2_d2S', 'fit_rmse_d2S', ...
    'a1_peak_T_K',           'better_described_by', ...
    'a1_column', ...
    'first_deriv_smooth_method', 'second_deriv_smooth_method', ...
    'sgolay_polynomial_order', 'sgolay_frame_length', ...
    'a1_source_run', 'switching_source_run', ...
    'a1_source_file', 'switching_source_file'});

corrPath = save_run_table(corrTbl, 'a1_amplitude_response_correlations.csv', runDir);

% -----------------------------------------------------------------------
% Series table
% -----------------------------------------------------------------------
seriesTbl = table( ...
    Tv, a1v, Speakv, S_smoothv, ...
    dS_rawv, dSv, d2S_rawv, d2Sv, ...
    normalizeSigned(a1v), normalizeSigned(dSv), normalizeSigned(d2Sv), ...
    normalize01(abs(a1v)), normalize01(abs(dSv)), normalize01(abs(d2Sv)), ...
    yHat0_dS,  res0_dS,  yHat1_dS,  res1_dS, ...
    yHat0_d2S, res0_d2S, yHat1_d2S, res1_d2S, ...
    'VariableNames', { ...
    'T_K', 'a1', 'S_peak', 'S_peak_smoothed', ...
    'dS_peak_dT_raw',   'dS_peak_dT', ...
    'd2S_peak_dT2_raw', 'd2S_peak_dT2', ...
    'a1_norm_signed',   'dS_dT_norm_signed', 'd2S_dT2_norm_signed', ...
    'a1_abs_norm',      'dS_dT_abs_norm',    'd2S_dT2_abs_norm', ...
    'a1_fit_origin_from_dS',  'fit_origin_resid_dS', ...
    'a1_fit_linear_from_dS',  'fit_linear_resid_dS', ...
    'a1_fit_origin_from_d2S', 'fit_origin_resid_d2S', ...
    'a1_fit_linear_from_d2S', 'fit_linear_resid_d2S'});

seriesPath = save_run_table(seriesTbl, 'a1_amplitude_response_series.csv', runDir);

% -----------------------------------------------------------------------
% Figures
% -----------------------------------------------------------------------
figOverlay   = saveOverlayFigure(Tv, a1v, dSv, d2Sv, corrTbl, runDir);
figScatter1  = saveScatterFigure(Tv, a1v, dSv,  pearson_dS,  spearman_dS,  ...
    'dS_{peak}/dT',    'a1_vs_dS_dT_scatter',    runDir);
figScatter2  = saveScatterFigure(Tv, a1v, d2Sv, pearson_d2S, spearman_d2S, ...
    'd^2S_{peak}/dT^2', 'a1_vs_d2S_dT2_scatter', runDir);

% -----------------------------------------------------------------------
% Report
% -----------------------------------------------------------------------
reportText = buildReportText(source, cfg, corrTbl, ...
    figOverlay, figScatter1, figScatter2, corrPath, seriesPath, ...
    isStrong_dS, isStrong_d2S);
reportPath = save_run_report(reportText, 'a1_amplitude_response_report.md', runDir);

% -----------------------------------------------------------------------
% Review ZIP
% -----------------------------------------------------------------------
zipPath = buildReviewZip(runDir, 'switching_a1_amplitude_response_bundle.zip');

% -----------------------------------------------------------------------
% Notes + log
% -----------------------------------------------------------------------
appendText(run.notes_path, sprintf('a1 source run = %s\n',         char(source.a1RunName)));
appendText(run.notes_path, sprintf('switching source run = %s\n',  char(source.switchRunName)));
appendText(run.notes_path, sprintf('n_points = %d\n',              nnz(valid)));
appendText(run.notes_path, sprintf('pearson(a1, dS/dT)    = %.6f\n', pearson_dS));
appendText(run.notes_path, sprintf('spearman(a1, dS/dT)   = %.6f\n', spearman_dS));
appendText(run.notes_path, sprintf('pearson(a1, d2S/dT2)  = %.6f\n', pearson_d2S));
appendText(run.notes_path, sprintf('spearman(a1, d2S/dT2) = %.6f\n', spearman_d2S));
appendText(run.notes_path, sprintf('a1 peak T        = %.2f K\n',   a1PeakT));
appendText(run.notes_path, sprintf('dS/dT peak T     = %.2f K\n',   dSPeakT));
appendText(run.notes_path, sprintf('d2S/dT2 peak T   = %.2f K\n',   d2SPeakT));
appendText(run.notes_path, sprintf('delta_peak (dS)  = %.2f K\n',   deltaPeak_dS));
appendText(run.notes_path, sprintf('delta_peak (d2S) = %.2f K\n',   deltaPeak_d2S));
appendText(run.notes_path, sprintf('better described by = %s\n',    char(betterBy)));
appendText(run.notes_path, sprintf('correlations table = %s\n',     corrPath));
appendText(run.notes_path, sprintf('series table = %s\n',           seriesPath));
appendText(run.notes_path, sprintf('overlay figure = %s\n',         figOverlay.png));
appendText(run.notes_path, sprintf('scatter dS/dT figure = %s\n',   figScatter1.png));
appendText(run.notes_path, sprintf('scatter d2S/dT2 figure = %s\n', figScatter2.png));
appendText(run.notes_path, sprintf('report = %s\n',                 reportPath));
appendText(run.notes_path, sprintf('zip = %s\n',                    zipPath));

appendText(run.log_path, sprintf('[%s] switching a1 amplitude-response test complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlations table: %s\n', corrPath));
appendText(run.log_path, sprintf('Series table:       %s\n', seriesPath));
appendText(run.log_path, sprintf('Overlay figure:     %s\n', figOverlay.png));
appendText(run.log_path, sprintf('Scatter dS figure:  %s\n', figScatter1.png));
appendText(run.log_path, sprintf('Scatter d2S figure: %s\n', figScatter2.png));
appendText(run.log_path, sprintf('Report:             %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP:                %s\n', zipPath));

% -----------------------------------------------------------------------
% Output struct
% -----------------------------------------------------------------------
out         = struct();
out.run     = run;
out.runDir  = string(runDir);
out.source  = source;
out.metrics = struct( ...
    'pearson_dS',     pearson_dS,    'spearman_dS',   spearman_dS, ...
    'pearson_d2S',    pearson_d2S,   'spearman_d2S',  spearman_d2S, ...
    'score_dS',       score_dS,      'score_d2S',     score_d2S, ...
    'betterBy',       betterBy, ...
    'a1_peak_T_K',    a1PeakT, ...
    'dS_peak_T_K',    dSPeakT, ...
    'd2S_peak_T_K',   d2SPeakT, ...
    'delta_peak_dS',  deltaPeak_dS, ...
    'delta_peak_d2S', deltaPeak_d2S);
out.paths = struct( ...
    'correlations', string(corrPath), ...
    'series',       string(seriesPath), ...
    'overlay',      string(figOverlay.png), ...
    'scatter_dS',   string(figScatter1.png), ...
    'scatter_d2S',  string(figScatter2.png), ...
    'report',       string(reportPath), ...
    'zip',          string(zipPath));

fprintf('\n=== Switching a1 amplitude-response test complete ===\n');
fprintf('Run dir: %s\n',              runDir);
fprintf('n points: %d\n',             nnz(valid));
fprintf('Pearson(a1,  dS/dT):   %.6f\n', pearson_dS);
fprintf('Spearman(a1, dS/dT):   %.6f\n', spearman_dS);
fprintf('Pearson(a1,  d2S/dT2): %.6f\n', pearson_d2S);
fprintf('Spearman(a1, d2S/dT2): %.6f\n', spearman_d2S);
fprintf('a1 peak T   = %.2f K | dS peak T   = %.2f K (delta = %.2f K)\n', ...
    a1PeakT, dSPeakT, deltaPeak_dS);
fprintf('a1 peak T   = %.2f K | d2S peak T  = %.2f K (delta = %.2f K)\n', ...
    a1PeakT, d2SPeakT, deltaPeak_d2S);
fprintf('Better described by: %s\n', char(betterBy));
fprintf('Report: %s\n',              reportPath);
fprintf('ZIP:    %s\n\n',            zipPath);
end

% =======================================================================
% Configuration
% =======================================================================

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel',              'switching_a1_amplitude_response_test');
cfg = setDefaultField(cfg, 'a1RunName',             'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'switchRunName',         'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefaultField(cfg, 'a1ColumnName',          'a_1');
cfg = setDefaultField(cfg, 'temperatureMinK',       4);
cfg = setDefaultField(cfg, 'temperatureMaxK',       30);
cfg = setDefaultField(cfg, 'sgolayPolynomialOrder', 2);
cfg = setDefaultField(cfg, 'sgolayFrameLength',     5);
cfg = setDefaultField(cfg, 'movmeanWindow',         3);
cfg = setDefaultField(cfg, 'strongCorrThreshold',   0.7);
end

function source = resolveSourceRuns(repoRoot, cfg)
source             = struct();
source.a1RunName   = string(cfg.a1RunName);
source.switchRunName = string(cfg.switchRunName);

source.a1RunDir    = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.a1RunName));
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));

source.a1Path      = fullfile(source.a1RunDir, 'tables', 'switching_dynamic_shape_mode_amplitudes.csv');
source.switchPath  = fullfile(source.switchRunDir, 'tables', 'switching_effective_observables_table.csv');
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

% =======================================================================
% Data loading
% =======================================================================

function data = loadA1Data(pathValue, a1ColumnName)
tbl = readtable(pathValue);
if ~ismember('T_K', tbl.Properties.VariableNames)
    error('a1 table missing T_K column: %s', pathValue);
end
if ~ismember(a1ColumnName, tbl.Properties.VariableNames)
    error('a1 table missing requested column %s: %s', a1ColumnName, pathValue);
end
tbl  = sortrows(tbl, 'T_K');
data = struct();
data.T_K = double(tbl.T_K(:));
data.a1  = double(tbl.(a1ColumnName)(:));
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

tbl  = sortrows(tbl, 'T_K');
data = struct();
data.T_K   = double(tbl.T_K(:));
data.S_peak = double(tbl.S_peak(:));
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

tblOut = tbl;
end

function tbl = longToWideSwitching(tblLong)
T = unique(double(tblLong.temperature(:)));
T = T(isfinite(T));
T = sort(T);
n = numel(T);

S_peak = NaN(n, 1);
for i = 1:n
    t      = T(i);
    rows   = tblLong(double(tblLong.temperature) == t, :);
    obs    = lower(string(rows.observable));
    vals   = double(rows.value);
    S_peak(i) = firstMatchedValue(obs, vals, ["s_peak"]);
end

tbl = table(T, S_peak, 'VariableNames', {'T_K', 'S_peak'});
end

function v = firstMatchedValue(obsNames, values, candidates)
v = NaN;
for i = 1:numel(candidates)
    idx = find(obsNames == lower(string(candidates(i))), 1, 'first');
    if ~isempty(idx)
        v = values(idx);
        return;
    end
end
end

% =======================================================================
% Numerical preprocessing
% =======================================================================

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

function [dRaw, dSmooth, ySmooth, methodText] = firstDerivProfiles(x, y, cfg)
% Smooth y, then compute first derivative via gradient.
x     = x(:);
y     = y(:);
dRaw  = gradient(y, x);

[ySmooth, methodText] = smoothProfile(y, cfg);
dSmooth = gradient(ySmooth, x);
end

function [d2Raw, d2Smooth, methodText] = secondDerivProfiles(x, y, cfg)
% Smooth y, differentiate once to get dY, smooth dY, differentiate again.
x  = x(:);
y  = y(:);

% Raw second derivative
dRaw  = gradient(y, x);
d2Raw = gradient(dRaw, x);

% Smoothed path: smooth S, take dS, smooth dS, take d2S
[ySmooth, methodText] = smoothProfile(y, cfg);
dSmooth  = gradient(ySmooth, x);
[dSmooth2, ~] = smoothProfile(dSmooth, cfg);
d2Smooth = gradient(dSmooth2, x);
end

function [ySmooth, methodText] = smoothProfile(y, cfg)
% Apply Savitzky-Golay smoothing or movmean fallback.
y   = y(:);
n   = numel(y);

frame = min(max(3, round(cfg.sgolayFrameLength)), n);
if mod(frame, 2) == 0
    frame = frame - 1;
end
poly = min(max(1, round(cfg.sgolayPolynomialOrder)), frame - 1);

ySmooth    = y;
methodText = "none";

if exist('sgolayfilt', 'file') == 2 && frame >= 3 && frame > poly
    try
        ySmooth    = sgolayfilt(y, poly, frame);
        methodText = sprintf('sgolayfilt(p=%d,frame=%d)', poly, frame);
        return;
    catch
        ySmooth = y;
    end
end

% Fallback: movmean
w = min(max(1, round(cfg.movmeanWindow)), n);
if mod(w, 2) == 0 && w > 1
    w = w - 1;
end
if w > 1
    ySmooth    = smoothdata(y, 'movmean', w, 'omitnan');
    methodText = sprintf('movmean(window=%d)', w);
end
end

% =======================================================================
% Statistics helpers
% =======================================================================

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

sse = sum(residuals .^ 2);
sst = sum((y - mean(y, 'omitnan')) .^ 2);
r2  = 1 - sse / max(sst, eps);
rmse = sqrt(mean(residuals .^ 2, 'omitnan'));
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

sse  = sum(residuals .^ 2);
sst  = sum((y - mean(y, 'omitnan')) .^ 2);
r2   = 1 - sse / max(sst, eps);
rmse = sqrt(mean(residuals .^ 2, 'omitnan'));
end

% =======================================================================
% Normalization helpers
% =======================================================================

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
mn = min(x,  [], 'omitnan');
mx = max(x,  [], 'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn
    y = zeros(size(x));
else
    y = (x - mn) ./ (mx - mn);
end
end

% =======================================================================
% Figures
% =======================================================================

function figOut = saveOverlayFigure(T, a1, dS, d2S, corrTbl, runDir)
% Three-curve signed-normalized overlay: a1, dS/dT, d2S/dT2.
fig = create_figure('Visible', 'off', 'Position', [2 2 14 10]);
ax  = axes(fig);
hold(ax, 'on');

plot(ax, T, normalizeSigned(a1),  '-o', ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'DisplayName', 'a_1(T) signed-norm');
plot(ax, T, normalizeSigned(dS),  '-s', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'DisplayName', 'dS_{peak}/dT signed-norm');
plot(ax, T, normalizeSigned(d2S), '-^', ...
    'Color', [0.47 0.67 0.19], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.47 0.67 0.19], ...
    'DisplayName', 'd^2S_{peak}/dT^2 signed-norm');
yline(ax, 0, '-', 'LineWidth', 1.0, 'Color', [0.70 0.70 0.70]);

hold(ax, 'off');
xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalized amplitude', 'FontSize', 14);
title(ax, sprintf( ...
    'a_1(T) vs amplitude-response derivatives | P_{dS}=%.3f P_{d2S}=%.3f', ...
    corrTbl.pearson_a1_vs_dS_dT(1), corrTbl.pearson_a1_vs_d2S_dT2(1)), ...
    'FontSize', 11);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 10);

figOut = robustSaveFigure(fig, 'a1_vs_amplitude_response_overlay', runDir);
close(fig);
end

function figOut = saveScatterFigure(T, a1, xData, pearsonR, spearmanRho, xLabel, baseName, runDir)
% Scatter of a1 vs derivative quantity with linear fit and correlation annotation.
fig = create_figure('Visible', 'off', 'Position', [2 2 12 10]);
ax  = axes(fig);
hold(ax, 'on');

% Single scatter call with temperature as CData
m = isfinite(xData) & isfinite(a1) & isfinite(T);
if nnz(m) >= 1
    scatter(ax, xData(m), a1(m), 60, T(m), 'filled', 'MarkerEdgeColor', 'none');
    colormap(ax, parula);
    tRange = [min(T(m)), max(T(m))];
    if tRange(1) < tRange(2)
        try
            clim(ax, tRange);       % R2022b+
        catch
            caxis(ax, tRange); %#ok<CAXIS>  % pre-R2022b fallback
        end
    end
    cb = colorbar(ax);
    cb.Label.String   = 'Temperature (K)';
    cb.Label.FontSize = 11;
end

% Linear fit line
if nnz(m) >= 2
    p  = polyfit(xData(m), a1(m), 1);
    xg = linspace(min(xData(m)), max(xData(m)), 200);
    yg = polyval(p, xg);
    plot(ax, xg, yg, '-', 'LineWidth', 2.2, 'Color', [0.85 0.10 0.10], ...
        'DisplayName', sprintf('linear fit: slope=%.3g', p(1)));
    legend(ax, 'Location', 'best', 'FontSize', 10);
end

xlabel(ax, xLabel, 'FontSize', 14);
ylabel(ax, 'a_1(T)', 'FontSize', 14);
title(ax, sprintf('a_1(T) vs %s', strrep(xLabel, '_', '\_')), 'FontSize', 12);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');

xL    = xlim(ax);
yL    = ylim(ax);
textX = xL(1) + 0.03 * (xL(2) - xL(1));
textY = yL(2) - 0.05 * (yL(2) - yL(1));
text(ax, textX, textY, ...
    sprintf('Pearson r = %.4f\nSpearman \\rho = %.4f', pearsonR, spearmanRho), ...
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
    warning('switching_a1_amplitude_response_test:saveFigureFallback', ...
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
        % PDF optional in fallback.
    end
end
end

% =======================================================================
% Report
% =======================================================================

function reportText = buildReportText(source, cfg, corrTbl, ...
    figOverlay, figScatter1, figScatter2, corrPath, seriesPath, ...
    isStrongDS, isStrongD2S)

pearsonDS  = corrTbl.pearson_a1_vs_dS_dT(1);
spearmanDS = corrTbl.spearman_a1_vs_dS_dT(1);
pearsonD2S = corrTbl.pearson_a1_vs_d2S_dT2(1);
spearmanD2S= corrTbl.spearman_a1_vs_d2S_dT2(1);

betterBy   = string(corrTbl.better_described_by(1));
a1PeakT    = corrTbl.a1_peak_T_K(1);
dSPeakT    = corrTbl.dS_dT_peak_T_K(1);
d2SPeakT   = corrTbl.d2S_dT2_peak_T_K(1);
deltaDSK   = corrTbl.delta_peak_T_dS_K(1);
deltaD2SK  = corrTbl.delta_peak_T_d2S_K(1);

lines = strings(0, 1);
lines(end + 1) = "# a1(T) vs amplitude-response derivatives test report";
lines(end + 1) = "";
lines(end + 1) = "**Goal**: test whether a1(T) represents temperature susceptibility of " + ...
    "the switching amplitude, i.e. whether it tracks dS_peak/dT or d²S_peak/dT².";
lines(end + 1) = "";
lines(end + 1) = "## Sources";
lines(end + 1) = "- a1 source run: `" + source.a1RunName + "`";
lines(end + 1) = "- switching observables source run: `" + source.switchRunName + "`";
lines(end + 1) = "- a1 source file: `" + string(source.a1Path) + "`";
lines(end + 1) = "- switching source file: `" + string(source.switchPath) + "`";
lines(end + 1) = "";
lines(end + 1) = "## Method";
lines(end + 1) = "- Temperature range: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`.";
lines(end + 1) = "- Quantities computed:";
lines(end + 1) = "  - `dS_peak/dT`: Savitzky-Golay smooth S_peak, then `gradient`.";
lines(end + 1) = "  - `d²S_peak/dT²`: smooth S_peak → derivative → smooth derivative → `gradient` again.";
lines(end + 1) = "- Smoothing: Savitzky-Golay polynomial order `" + ...
    string(cfg.sgolayPolynomialOrder) + "`, frame `" + string(cfg.sgolayFrameLength) + "`.";
lines(end + 1) = "- First-deriv smooth method: `" + string(corrTbl.first_deriv_smooth_method(1)) + "`.";
lines(end + 1) = "- Second-deriv smooth method: `" + string(corrTbl.second_deriv_smooth_method(1)) + "`.";
lines(end + 1) = "- Correlations: Pearson (linear) and Spearman (rank).";
lines(end + 1) = "- Peak alignment: temperature of `max|a1|` vs `max|derivative|`.";
lines(end + 1) = "";
lines(end + 1) = "## Results: a1(T) vs dS_peak/dT";
lines(end + 1) = sprintf('- n_points: `%d`.', corrTbl.n_points(1));
lines(end + 1) = sprintf('- Pearson r = `%.6f`.', pearsonDS);
lines(end + 1) = sprintf('- Spearman ρ = `%.6f`.', spearmanDS);
lines(end + 1) = sprintf('- Score (mean |corr|) = `%.4f`.', corrTbl.score_first_derivative(1));
lines(end + 1) = sprintf('- T_peak(|a1|) = `%.2f K`, T_peak(|dS/dT|) = `%.2f K`, Δ = `%.2f K`.', ...
    a1PeakT, dSPeakT, deltaDSK);
lines(end + 1) = sprintf('- Through-origin fit: c = `%.6g`, R² = `%.4f`, RMSE = `%.4g`.', ...
    corrTbl.fit_origin_c_dS(1), corrTbl.fit_origin_r2_dS(1), corrTbl.fit_origin_rmse_dS(1));
lines(end + 1) = sprintf('- Linear fit: slope = `%.6g`, intercept = `%.6g`, R² = `%.4f`, RMSE = `%.4g`.', ...
    corrTbl.fit_slope_dS(1), corrTbl.fit_intercept_dS(1), corrTbl.fit_r2_dS(1), corrTbl.fit_rmse_dS(1));
if isStrongDS
    lines(end + 1) = "- **Strong correlation**. a1(T) is consistent with a temperature susceptibility of switching amplitude.";
else
    lines(end + 1) = "- Correlation is not strong by the applied threshold.";
end
lines(end + 1) = "";
lines(end + 1) = "## Results: a1(T) vs d²S_peak/dT²";
lines(end + 1) = sprintf('- Pearson r = `%.6f`.', pearsonD2S);
lines(end + 1) = sprintf('- Spearman ρ = `%.6f`.', spearmanD2S);
lines(end + 1) = sprintf('- Score (mean |corr|) = `%.4f`.', corrTbl.score_second_derivative(1));
lines(end + 1) = sprintf('- T_peak(|a1|) = `%.2f K`, T_peak(|d²S/dT²|) = `%.2f K`, Δ = `%.2f K`.', ...
    a1PeakT, d2SPeakT, deltaD2SK);
lines(end + 1) = sprintf('- Through-origin fit: c = `%.6g`, R² = `%.4f`, RMSE = `%.4g`.', ...
    corrTbl.fit_origin_c_d2S(1), corrTbl.fit_origin_r2_d2S(1), corrTbl.fit_origin_rmse_d2S(1));
lines(end + 1) = sprintf('- Linear fit: slope = `%.6g`, intercept = `%.6g`, R² = `%.4f`, RMSE = `%.4g`.', ...
    corrTbl.fit_slope_d2S(1), corrTbl.fit_intercept_d2S(1), corrTbl.fit_r2_d2S(1), corrTbl.fit_rmse_d2S(1));
if isStrongD2S
    lines(end + 1) = "- **Strong correlation**. a1(T) is consistent with the curvature of the switching amplitude in temperature space.";
else
    lines(end + 1) = "- Correlation is not strong by the applied threshold.";
end
lines(end + 1) = "";
lines(end + 1) = "## Comparative summary";
lines(end + 1) = "- Better descriptor (higher mean |corr|): **`" + betterBy + "`**.";
if betterBy == "dS_peak/dT"
    lines(end + 1) = "- Interpretation: a1(T) tracks the *rate of change* of switching amplitude with temperature — " + ...
        "consistent with a susceptibility-mode picture.";
    lines(end + 1) = "- The second derivative provides weaker tracking, suggesting a1 does not primarily " + ...
        "represent amplitude-response curvature.";
else
    lines(end + 1) = "- Interpretation: a1(T) tracks the *curvature* of switching amplitude in temperature space " + ...
        "more than its first derivative.";
    lines(end + 1) = "- This is consistent with a1 marking inflection/crossover structure in S_peak(T) rather than " + ...
        "its slope.";
end
lines(end + 1) = "- Both correlations should be interpreted as empirical associations only; " + ...
    "no mechanistic claim is made without independent evidence.";
lines(end + 1) = "";
lines(end + 1) = "## Artifacts";
lines(end + 1) = "- Correlation table: `" + string(corrPath) + "`";
lines(end + 1) = "- Series table: `" + string(seriesPath) + "`";
lines(end + 1) = "- Overlay figure: `" + string(figOverlay.png) + "`";
lines(end + 1) = "- Scatter (dS/dT): `" + string(figScatter1.png) + "`";
lines(end + 1) = "- Scatter (d²S/dT²): `" + string(figScatter2.png) + "`";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_amplitude_response_overlay](../figures/a1_vs_amplitude_response_overlay.png)";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_dS_dT_scatter](../figures/a1_vs_dS_dT_scatter.png)";
lines(end + 1) = "";
lines(end + 1) = "![a1_vs_d2S_dT2_scatter](../figures/a1_vs_d2S_dT2_scatter.png)";
lines(end + 1) = "";
lines(end + 1) = "## Visualization notes";
lines(end + 1) = "- Overlay: signed-normalized traces of a1, dS/dT, d²S/dT² on shared axis.";
lines(end + 1) = "- Scatter: data points color-coded by temperature (parula colormap), with linear fit line.";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

% =======================================================================
% ZIP
% =======================================================================

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
    fullfile(runDir, 'figures', 'a1_vs_amplitude_response_overlay.png'), ...
    fullfile(runDir, 'figures', 'a1_vs_dS_dT_scatter.png'), ...
    fullfile(runDir, 'figures', 'a1_vs_d2S_dT2_scatter.png'), ...
    fullfile(runDir, 'tables',  'a1_amplitude_response_correlations.csv'), ...
    fullfile(runDir, 'tables',  'a1_amplitude_response_series.csv'), ...
    fullfile(runDir, 'reports', 'a1_amplitude_response_report.md'), ...
    fullfile(runDir, 'run_manifest.json'), ...
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

% =======================================================================
% Small utilities
% =======================================================================

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
