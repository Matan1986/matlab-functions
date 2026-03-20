function out = switching_ridge_temperature_susceptibility_test(cfg)
% switching_ridge_temperature_susceptibility_test
%
% Test whether the dynamic mode a1(T) corresponds to the temperature
% derivative of the switching signal evaluated at the ridge.
%
% Steps:
%   1. Load switching map S(I,T) and ridge I_peak(T) from the geometry-
%      diagnostics run.
%   2. Evaluate the switching amplitude at the ridge:
%         S_ridge(T) = S(I_peak(T), T)
%   3. Compute the ridge temperature susceptibility:
%         rts(T) = d/dT [ S_ridge(T) ]
%      using Savitzky-Golay smoothing + gradient (same approach as prior
%      derivative analyses in this repository; movmean fallback if needed).
%   4. Load a1(T) from the dynamic shape-mode run.
%   5. Align temperatures by intersection.
%   6. Compute Pearson and Spearman correlations.
%   7. Determine peak alignment: T_peak(|a1|) and T_peak(|rts|); report ΔT.
%   8. Produce figures, tables, report, and review ZIP.
%
% Run label: switching_ridge_temperature_susceptibility_test

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
source = resolveSourcePaths(repoRoot, cfg);

runCfg          = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset  = sprintf('a1:%s | geom:%s | map:%s', ...
    char(source.a1RunId), char(source.geomRunId), char(source.mapRunId));
run    = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Ridge temperature susceptibility test run directory:\n%s\n', runDir);
fprintf('a1 source run:      %s\n', char(source.a1RunId));
fprintf('Geometry run:       %s\n', char(source.geomRunId));
fprintf('Switching map run:  %s\n', char(source.mapRunId));
appendText(run.log_path, sprintf('[%s] ridge temperature susceptibility test started\n', stampNow()));
appendText(run.log_path, sprintf('a1 run:   %s\n', char(source.a1RunId)));
appendText(run.log_path, sprintf('geom run: %s\n', char(source.geomRunId)));
appendText(run.log_path, sprintf('map run:  %s\n', char(source.mapRunId)));
appendText(run.log_path, sprintf('a1 file:  %s\n', source.a1Path));
appendText(run.log_path, sprintf('geom file: %s\n', source.geomPath));
appendText(run.log_path, sprintf('map file:  %s\n', source.mapPath));

% -----------------------------------------------------------------------
% Step 1: Load data
% -----------------------------------------------------------------------
a1Data   = loadA1Data(source.a1Path, cfg.a1ColumnName);
geomData = loadGeometryData(source.geomPath);
mapData  = loadSwitchingMap(source.mapPath);

% -----------------------------------------------------------------------
% Step 2: Evaluate S_ridge(T) = S(I_peak(T), T) from map
%         Also record S_peak from geometry table (should match; verify).
% -----------------------------------------------------------------------
[sridgeData, consistencyTbl] = buildRidgeSeries(geomData, mapData, cfg);

% -----------------------------------------------------------------------
% Step 3: Compute d/dT[S_ridge(T)]
% -----------------------------------------------------------------------
[rts_raw, rts, sridge_smooth, smoothMethod] = derivativeProfile( ...
    sridgeData.T_K, sridgeData.S_ridge, cfg);

% -----------------------------------------------------------------------
% Step 4+5: Align a1(T) with rts series
% -----------------------------------------------------------------------
[T, iA1, iRts] = intersect(a1Data.T_K, sridgeData.T_K, 'stable');
if isempty(T)
    error('No overlapping temperature points between a1 and ridge series.');
end

a1  = double(a1Data.a1(iA1));
rts_aligned = rts(iRts);
rts_raw_aligned = rts_raw(iRts);
sridgeAligned = sridgeData.S_ridge(iRts);
sridgeSmoothAligned = sridge_smooth(iRts);

% Temperature range filter
mask = T >= cfg.temperatureMinK & T <= cfg.temperatureMaxK;
T   = double(T(mask));
a1  = a1(mask);
rts_aligned       = rts_aligned(mask);
rts_raw_aligned   = rts_raw_aligned(mask);
sridgeAligned     = sridgeAligned(mask);
sridgeSmoothAligned = sridgeSmoothAligned(mask);

if numel(T) < 3
    error('Need at least 3 temperature points after alignment/range filtering.');
end

% Fill isolated NaN by interpolation
a1  = fillByInterp(T, a1);
rts_aligned = fillByInterp(T, rts_aligned);

% Valid mask
valid = isfinite(T) & isfinite(a1) & isfinite(rts_aligned);
if nnz(valid) < 3
    error('Insufficient finite points for correlation.');
end

Tv           = T(valid);
a1v          = a1(valid);
rtsv         = rts_aligned(valid);
rts_rawv     = rts_raw_aligned(valid);
sridgev      = sridgeAligned(valid);
sridgeSmv    = sridgeSmoothAligned(valid);

% -----------------------------------------------------------------------
% Step 6: Correlations
% -----------------------------------------------------------------------
pearsonR  = safeCorr(a1v, rtsv, 'Pearson');
spearmanR = safeCorr(a1v, rtsv, 'Spearman');

% -----------------------------------------------------------------------
% Step 7: Peak alignment
% -----------------------------------------------------------------------
[a1PeakT,   ~] = peakOf(Tv, a1v,  true);
[rtsPeakT,  ~] = peakOf(Tv, rtsv, true);
deltaPeakK     = rtsPeakT - a1PeakT;

% Linear fits
[c0, yHat0, res0, r2_c0, rmse_c0] = fitThroughOrigin(rtsv, a1v);
[m1, b1,    yHat1, res1, r2_l1, rmse_l1] = fitOrdinaryLinear(rtsv, a1v);

isStrong = isfinite(pearsonR) && isfinite(spearmanR) && ...
           abs(pearsonR)  >= cfg.strongCorrThreshold && ...
           abs(spearmanR) >= cfg.strongCorrThreshold;

% -----------------------------------------------------------------------
% Step 9a: Series table
% -----------------------------------------------------------------------
seriesTbl = table( ...
    Tv, a1v, sridgev, sridgeSmv, rts_rawv, rtsv, ...
    normalizeSigned(a1v), normalizeSigned(rtsv), ...
    normalize01(abs(a1v)), normalize01(abs(rtsv)), ...
    yHat0, res0, yHat1, res1, ...
    'VariableNames', { ...
    'T_K', 'a1', 'S_ridge', 'S_ridge_smoothed', ...
    'ridge_temp_susceptibility_raw', 'ridge_temp_susceptibility', ...
    'a1_norm_signed', 'rts_norm_signed', ...
    'a1_abs_norm', 'rts_abs_norm', ...
    'a1_fit_origin_from_rts', 'fit_origin_residual', ...
    'a1_fit_linear_from_rts', 'fit_linear_residual'});

seriesPath = save_run_table(seriesTbl, ...
    'ridge_temperature_susceptibility_series.csv', runDir);

% -----------------------------------------------------------------------
% Step 9b: Correlations table
% -----------------------------------------------------------------------
corrTbl = table( ...
    nnz(valid), pearsonR, spearmanR, ...
    a1PeakT, rtsPeakT, deltaPeakK, ...
    c0, r2_c0, rmse_c0, ...
    m1, b1, r2_l1, rmse_l1, ...
    string(smoothMethod), ...
    cfg.sgolayPolynomialOrder, cfg.sgolayFrameLength, ...
    source.a1RunId, source.geomRunId, source.mapRunId, ...
    string(source.a1Path), string(source.geomPath), string(source.mapPath), ...
    'VariableNames', { ...
    'n_points', 'pearson_a1_vs_rts', 'spearman_a1_vs_rts', ...
    'a1_peak_T_K', 'rts_peak_T_K', 'delta_peak_T_K', ...
    'fit_origin_c', 'fit_origin_r2', 'fit_origin_rmse', ...
    'fit_slope', 'fit_intercept', 'fit_r2', 'fit_rmse', ...
    'smooth_method', 'sgolay_poly_order', 'sgolay_frame', ...
    'a1_source_run', 'geom_source_run', 'map_source_run', ...
    'a1_source_file', 'geom_source_file', 'map_source_file'});

corrPath = save_run_table(corrTbl, ...
    'ridge_temperature_susceptibility_correlations.csv', runDir);

% Consistency check table
consistencyPath = save_run_table(consistencyTbl, ...
    'ridge_sridge_consistency_check.csv', runDir);

% -----------------------------------------------------------------------
% Step 8: Figures
% -----------------------------------------------------------------------
% Figure 1: normalized overlay
fig1 = buildOverlayFigure(Tv, a1v, rtsv, corrTbl);
figOverlay = save_run_figure(fig1, 'ridge_temp_susceptibility_overlay', runDir);
close(fig1);

% Figure 2: scatter
fig2 = buildScatterFigure(Tv, a1v, rtsv, pearsonR, spearmanR);
figScatter = save_run_figure(fig2, 'ridge_temp_susceptibility_scatter', runDir);
close(fig2);

% -----------------------------------------------------------------------
% Step 10: Report
% -----------------------------------------------------------------------
reportText = buildReport(source, cfg, corrTbl, consistencyTbl, ...
    seriesPath, corrPath, figOverlay, figScatter, isStrong);
reportPath = save_run_report(reportText, ...
    'ridge_temperature_susceptibility_report.md', runDir);

% -----------------------------------------------------------------------
% Step 11: Review ZIP
% -----------------------------------------------------------------------
zipPath = buildReviewZip(runDir, 'ridge_temperature_susceptibility_bundle.zip');

% -----------------------------------------------------------------------
% Notes + log
% -----------------------------------------------------------------------
appendText(run.notes_path, sprintf('a1 source run = %s\n',  char(source.a1RunId)));
appendText(run.notes_path, sprintf('geom source run = %s\n', char(source.geomRunId)));
appendText(run.notes_path, sprintf('map source run = %s\n',  char(source.mapRunId)));
appendText(run.notes_path, sprintf('n_points = %d\n',         nnz(valid)));
appendText(run.notes_path, sprintf('smooth_method = %s\n',    smoothMethod));
appendText(run.notes_path, sprintf('pearson(a1, rts)  = %.6f\n', pearsonR));
appendText(run.notes_path, sprintf('spearman(a1, rts) = %.6f\n', spearmanR));
appendText(run.notes_path, sprintf('T_peak(|a1|)  = %.2f K\n', a1PeakT));
appendText(run.notes_path, sprintf('T_peak(|rts|) = %.2f K\n', rtsPeakT));
appendText(run.notes_path, sprintf('delta_peak_T  = %.2f K\n', deltaPeakK));
appendText(run.notes_path, sprintf('series table  = %s\n',    seriesPath));
appendText(run.notes_path, sprintf('corr table    = %s\n',    corrPath));
appendText(run.notes_path, sprintf('overlay fig   = %s\n',    figOverlay.png));
appendText(run.notes_path, sprintf('scatter fig   = %s\n',    figScatter.png));
appendText(run.notes_path, sprintf('report        = %s\n',    reportPath));
appendText(run.notes_path, sprintf('zip           = %s\n',    zipPath));

appendText(run.log_path, sprintf('[%s] ridge temperature susceptibility test complete\n', stampNow()));
appendText(run.log_path, sprintf('Series table:    %s\n', seriesPath));
appendText(run.log_path, sprintf('Corr table:      %s\n', corrPath));
appendText(run.log_path, sprintf('Overlay figure:  %s\n', figOverlay.png));
appendText(run.log_path, sprintf('Scatter figure:  %s\n', figScatter.png));
appendText(run.log_path, sprintf('Report:          %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP:             %s\n', zipPath));

% -----------------------------------------------------------------------
% Output
% -----------------------------------------------------------------------
out         = struct();
out.run     = run;
out.runDir  = string(runDir);
out.source  = source;
out.metrics = struct( ...
    'pearsonR',      pearsonR, ...
    'spearmanR',     spearmanR, ...
    'a1PeakT_K',     a1PeakT, ...
    'rtsPeakT_K',    rtsPeakT, ...
    'deltaPeakT_K',  deltaPeakK, ...
    'fit_origin_c',  c0,   'fit_origin_r2', r2_c0, ...
    'fit_slope',     m1,   'fit_intercept', b1,  'fit_r2', r2_l1);
out.paths = struct( ...
    'series',      string(seriesPath), ...
    'correlations', string(corrPath), ...
    'overlay',     string(figOverlay.png), ...
    'scatter',     string(figScatter.png), ...
    'report',      string(reportPath), ...
    'zip',         string(zipPath));

fprintf('\n=== Ridge temperature susceptibility test complete ===\n');
fprintf('Run dir:          %s\n',   runDir);
fprintf('n points:         %d\n',   nnz(valid));
fprintf('Smooth method:    %s\n',   smoothMethod);
fprintf('Pearson(a1,rts):  %.6f\n', pearsonR);
fprintf('Spearman(a1,rts): %.6f\n', spearmanR);
fprintf('T_peak(|a1|):     %.2f K\n', a1PeakT);
fprintf('T_peak(|rts|):    %.2f K | ΔT = %.2f K\n', rtsPeakT, deltaPeakK);
fprintf('Report:           %s\n',   reportPath);
fprintf('ZIP:              %s\n\n', zipPath);
end

% =======================================================================
% Configuration
% =======================================================================

function cfg = applyDefaults(cfg)
cfg = setdf(cfg, 'runLabel',              'switching_ridge_temperature_susceptibility_test');
cfg = setdf(cfg, 'a1RunId',               'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setdf(cfg, 'geomRunId',             'run_2026_03_13_112155_switching_geometry_diagnostics');
cfg = setdf(cfg, 'mapRunId',              'run_2026_03_13_152008_switching_effective_observables');
cfg = setdf(cfg, 'a1ColumnName',          'a_1');
cfg = setdf(cfg, 'temperatureMinK',       4);
cfg = setdf(cfg, 'temperatureMaxK',       30);
cfg = setdf(cfg, 'sgolayPolynomialOrder', 2);
cfg = setdf(cfg, 'sgolayFrameLength',     5);
cfg = setdf(cfg, 'movmeanWindow',         3);
cfg = setdf(cfg, 'strongCorrThreshold',   0.7);
cfg = setdf(cfg, 'sridgeConsistencyTol',  0.01);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();

source.a1RunId   = string(cfg.a1RunId);
source.geomRunId = string(cfg.geomRunId);
source.mapRunId  = string(cfg.mapRunId);

runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');

source.a1RunDir   = fullfile(runsRoot, char(source.a1RunId));
source.geomRunDir = fullfile(runsRoot, char(source.geomRunId));
source.mapRunDir  = fullfile(runsRoot, char(source.mapRunId));

source.a1Path   = fullfile(source.a1RunDir,   'tables', 'switching_dynamic_shape_mode_amplitudes.csv');
source.geomPath = fullfile(source.geomRunDir, 'tables', 'switching_geometry_observables.csv');
source.mapPath  = fullfile(source.mapRunDir,  'tables', 'switching_effective_switching_map.csv');

assertDir(source.a1RunDir,   'a1 run directory');
assertDir(source.geomRunDir, 'geometry run directory');
assertDir(source.mapRunDir,  'switching map run directory');
assertFile(source.a1Path,   'a1 amplitudes CSV');
assertFile(source.geomPath, 'geometry observables CSV');
assertFile(source.mapPath,  'switching map CSV');
end

% =======================================================================
% Data loading
% =======================================================================

function data = loadA1Data(filePath, colName)
tbl = readtable(filePath);
assertCol(tbl, 'T_K',   filePath);
assertCol(tbl, colName, filePath);
tbl  = sortrows(tbl, 'T_K');
data = struct('T_K', double(tbl.T_K(:)), 'a1', double(tbl.(colName)(:)));
end

function data = loadGeometryData(filePath)
tbl = readtable(filePath);
assertCol(tbl, 'T_K',       filePath);
assertCol(tbl, 'I_peak_mA', filePath);
assertCol(tbl, 'S_peak',    filePath);
tbl  = sortrows(tbl, 'T_K');
data = struct( ...
    'T_K',      double(tbl.T_K(:)), ...
    'I_peak_mA', double(tbl.I_peak_mA(:)), ...
    'S_peak',   double(tbl.S_peak(:)));
end

function data = loadSwitchingMap(filePath)
% Load long-format switching map: T_K, current_mA, S_percent.
tbl = readtable(filePath);
assertCol(tbl, 'T_K',        filePath);
assertCol(tbl, 'current_mA', filePath);
assertCol(tbl, 'S_percent',  filePath);
data = struct( ...
    'T_K',       double(tbl.T_K(:)), ...
    'current_mA', double(tbl.current_mA(:)), ...
    'S_percent', double(tbl.S_percent(:)));
end

% =======================================================================
% Ridge evaluation
% =======================================================================

function [sridgeData, consistencyTbl] = buildRidgeSeries(geomData, mapData, cfg)
% For each temperature in geomData, look up S from the switching map at
% I = I_peak(T). Interpolate in I if I_peak is between discrete grid
% values. Cross-check with S_peak from the geometry table.

Tgeom  = geomData.T_K;
Ipeak  = geomData.I_peak_mA;
Speak  = geomData.S_peak;       % from geometry table (reference)

nT = numel(Tgeom);
S_from_map  = NaN(nT, 1);
interp_flag = false(nT, 1);

for ti = 1:nT
    t   = Tgeom(ti);
    ip  = Ipeak(ti);

    % Find rows in map at this temperature
    rows = mapData.T_K == t;
    if ~any(rows)
        continue;
    end
    I_grid = mapData.current_mA(rows);
    S_grid = mapData.S_percent(rows);

    % Sort by current
    [I_grid, sIdx] = sort(I_grid);
    S_grid = S_grid(sIdx);

    m = isfinite(I_grid) & isfinite(S_grid);
    if nnz(m) < 2
        continue;
    end

    if any(abs(I_grid(m) - ip) < eps)
        % Exact grid match
        idx = find(abs(I_grid - ip) < eps, 1);
        S_from_map(ti)  = S_grid(idx);
        interp_flag(ti) = false;
    else
        % Interpolate
        try
            S_from_map(ti)  = interp1(I_grid(m), S_grid(m), ip, 'linear', 'extrap');
            interp_flag(ti) = true;
        catch
            S_from_map(ti) = NaN;
        end
    end
end

% Consistency check: |S_map - S_geom| / max(|S_geom|)
maxSpeakRef = max(abs(Speak), [], 'omitnan');
if maxSpeakRef <= eps; maxSpeakRef = 1; end
rel_diff = (S_from_map - Speak) ./ maxSpeakRef;

% Choose S_ridge: prefer map lookup (explicit derivation); fall back to
% geometry S_peak when map lookup gives NaN.
S_ridge = S_from_map;
fallback_flag = ~isfinite(S_ridge);
S_ridge(fallback_flag) = Speak(fallback_flag);

% Report consistency
consistencyTbl = table( ...
    Tgeom, Ipeak, Speak, S_from_map, S_ridge, ...
    interp_flag, fallback_flag, rel_diff, ...
    'VariableNames', { ...
    'T_K', 'I_peak_mA', 'S_peak_geom', 'S_from_map', 'S_ridge_used', ...
    'was_interpolated', 'used_geom_fallback', 'rel_diff_vs_geom'});

% Log any inconsistencies above threshold
badMask = isfinite(rel_diff) & abs(rel_diff) > cfg.sridgeConsistencyTol;
for bi = find(badMask)'
    fprintf('[WARNING] S_ridge inconsistency at T=%.1f K: map=%.6f, geom=%.6f, rel_diff=%.4f\n', ...
        Tgeom(bi), S_from_map(bi), Speak(bi), rel_diff(bi));
end

sridgeData = struct('T_K', Tgeom, 'S_ridge', S_ridge, 'I_peak_mA', Ipeak);
end

% =======================================================================
% Derivative
% =======================================================================

function [dRaw, dSmooth, ySmooth, methodText] = derivativeProfile(x, y, cfg)
x = x(:);
y = y(:);

dRaw = gradient(y, x);

n     = numel(y);
frame = min(max(3, round(cfg.sgolayFrameLength)), n);
if mod(frame, 2) == 0; frame = frame - 1; end
poly  = min(max(1, round(cfg.sgolayPolynomialOrder)), frame - 1);

ySmooth    = y;
methodText = 'none';

if exist('sgolayfilt', 'file') == 2 && frame >= 3 && frame > poly
    try
        ySmooth    = sgolayfilt(y, poly, frame);
        methodText = sprintf('sgolayfilt(p=%d,frame=%d)', poly, frame);
    catch
        ySmooth = y;
    end
end

if strcmp(methodText, 'none')
    w = min(max(1, round(cfg.movmeanWindow)), n);
    if mod(w, 2) == 0 && w > 1; w = w - 1; end
    if w > 1
        ySmooth    = smoothdata(y, 'movmean', w, 'omitnan');
        methodText = sprintf('movmean(window=%d)', w);
    end
end

dSmooth = gradient(ySmooth, x);
end

% =======================================================================
% Statistics
% =======================================================================

function c = safeCorr(x, y, corrType)
x    = x(:); y = y(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 3; c = NaN; return; end
try
    c = corr(x(mask), y(mask), 'Type', corrType, 'Rows', 'complete');
catch
    c = corr(x(mask), y(mask));
end
end

function [peakT, peakVal] = peakOf(T, y, useAbs)
peakT   = NaN;
peakVal = NaN;
if isempty(T) || isempty(y); return; end
if useAbs
    [~, idx] = max(abs(y));
    peakVal  = y(idx);
else
    [peakVal, idx] = max(y);
end
if ~isempty(idx); peakT = T(idx); end
end

function [c, yHat, residuals, r2, rmse] = fitThroughOrigin(x, y)
x    = x(:); y = y(:);
mask = isfinite(x) & isfinite(y);
x    = x(mask); y = y(mask);
if isempty(x) || sum(x.^2) <= eps
    c = NaN; yHat = NaN(size(y)); residuals = NaN(size(y)); r2 = NaN; rmse = NaN; return;
end
c         = (x' * y) / max(x' * x, eps);
yHat      = c .* x;
residuals = y - yHat;
sse       = sum(residuals.^2);
sst       = sum((y - mean(y, 'omitnan')).^2);
r2        = 1 - sse / max(sst, eps);
rmse      = sqrt(mean(residuals.^2, 'omitnan'));
end

function [slope, intercept, yHat, residuals, r2, rmse] = fitOrdinaryLinear(x, y)
x    = x(:); y = y(:);
mask = isfinite(x) & isfinite(y);
x    = x(mask); y = y(mask);
if numel(x) < 3
    slope = NaN; intercept = NaN; yHat = NaN(size(y)); residuals = NaN(size(y)); r2 = NaN; rmse = NaN; return;
end
p         = polyfit(x, y, 1);
slope     = p(1); intercept = p(2);
yHat      = polyval(p, x);
residuals = y - yHat;
sse       = sum(residuals.^2);
sst       = sum((y - mean(y, 'omitnan')).^2);
r2        = 1 - sse / max(sst, eps);
rmse      = sqrt(mean(residuals.^2, 'omitnan'));
end

% =======================================================================
% Normalization
% =======================================================================

function y = normalizeSigned(x)
x = x(:);
s = max(abs(x), [], 'omitnan');
if ~isfinite(s) || s <= 0; y = zeros(size(x)); else; y = x ./ s; end
end

function y = normalize01(x)
x = x(:);
mn = min(x, [], 'omitnan'); mx = max(x, [], 'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn; y = zeros(size(x)); else; y = (x-mn)./(mx-mn); end
end

function y = fillByInterp(x, yIn)
y    = yIn(:);
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2; return; end
if any(~mask)
    y(~mask) = interp1(x(mask), y(mask), x(~mask), 'linear', 'extrap');
end
end

% =======================================================================
% Figures
% =======================================================================

function fig = buildOverlayFigure(T, a1, rts, corrTbl)
% Normalized overlay: a1(T) and ridge temperature susceptibility.
% 2 primary curves → use legend (≤6 curves rule).
fig = create_figure('Visible', 'off', 'Position', [2 2 14 10]);
ax  = axes(fig);
hold(ax, 'on');

plot(ax, T, normalizeSigned(a1),  '-o', ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'DisplayName', 'a_1(T) signed-norm');
plot(ax, T, normalizeSigned(rts), '-s', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, ...
    'MarkerSize', 5.5, 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'DisplayName', 'd/dT[S_{ridge}(T)] signed-norm');
plot(ax, T, normalize01(abs(a1)),  '--', ...
    'Color', [0.20 0.20 0.20], 'LineWidth', 1.8, ...
    'DisplayName', '|a_1(T)| norm');
plot(ax, T, normalize01(abs(rts)), ':', ...
    'Color', [0.47 0.67 0.19], 'LineWidth', 2.0, ...
    'DisplayName', '|d/dT[S_{ridge}]| norm');
yline(ax, 0, '-', 'LineWidth', 1.0, 'Color', [0.70 0.70 0.70]);
hold(ax, 'off');

xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalized amplitude (a.u.)', 'FontSize', 14);
title(ax, ...
    ['a_1(T) vs d/dT[S_{ridge}(T)] | Pearson = ' ...
     sprintf('%.4f', corrTbl.pearson_a1_vs_rts(1)) ...
     ', Spearman = ' sprintf('%.4f', corrTbl.spearman_a1_vs_rts(1)) ...
     ', \DeltaT_{peak} = ' sprintf('%.1f', corrTbl.delta_peak_T_K(1)) ' K'], ...
    'FontSize', 11);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 10);
end

function fig = buildScatterFigure(T, a1, rts, pearsonR, spearmanR)
% Scatter plot: a1 vs ridge temperature susceptibility.
% Points color-coded by temperature using parula colormap.
fig = create_figure('Visible', 'off', 'Position', [2 2 12 10]);
ax  = axes(fig);
hold(ax, 'on');

m = isfinite(rts) & isfinite(a1) & isfinite(T);
if nnz(m) >= 1
    scatter(ax, rts(m), a1(m), 60, T(m), 'filled', 'MarkerEdgeColor', 'none');
    colormap(ax, parula);
    tRange = [min(T(m)), max(T(m))];
    if tRange(1) < tRange(2)
        try; clim(ax, tRange);       % R2022b+
        catch; caxis(ax, tRange); end %#ok<CAXIS>
    end
    cb = colorbar(ax);
    cb.Label.String   = 'Temperature (K)';
    cb.Label.FontSize = 12;
end

% Linear fit
if nnz(m) >= 2
    p  = polyfit(rts(m), a1(m), 1);
    xg = linspace(min(rts(m)), max(rts(m)), 200);
    yg = polyval(p, xg);
    plot(ax, xg, yg, '-', 'LineWidth', 2.2, 'Color', [0.85 0.10 0.10], ...
        'DisplayName', sprintf('linear fit: slope = %.3g', p(1)));
    legend(ax, 'Location', 'best', 'FontSize', 10);
end

xlabel(ax, 'd/dT[S_{ridge}(T)] (a.u.)', 'FontSize', 14);
ylabel(ax, 'a_1(T)', 'FontSize', 14);
title(ax, 'a_1(T) vs ridge temperature susceptibility', 'FontSize', 12);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');

xL    = xlim(ax); yL = ylim(ax);
textX = xL(1) + 0.03*(xL(2)-xL(1));
textY = yL(2) - 0.05*(yL(2)-yL(1));
text(ax, textX, textY, ...
    sprintf('Pearson r = %.4f\nSpearman \\rho = %.4f', pearsonR, spearmanR), ...
    'VerticalAlignment', 'top', 'FontSize', 11, ...
    'BackgroundColor', [1 1 1], 'EdgeColor', [0.8 0.8 0.8], 'Margin', 6);

hold(ax, 'off');
end

% =======================================================================
% Report
% =======================================================================

function reportText = buildReport(source, cfg, corrTbl, consistencyTbl, ...
    seriesPath, corrPath, figOverlay, figScatter, isStrong)

pearsonR  = corrTbl.pearson_a1_vs_rts(1);
spearmanR = corrTbl.spearman_a1_vs_rts(1);
a1PeakT   = corrTbl.a1_peak_T_K(1);
rtsPeakT  = corrTbl.rts_peak_T_K(1);
deltaPeak = corrTbl.delta_peak_T_K(1);

nFallback = nnz(consistencyTbl.used_geom_fallback);
nInterp   = nnz(consistencyTbl.was_interpolated);
maxRelDiff = max(abs(consistencyTbl.rel_diff_vs_geom), [], 'omitnan');

lines = strings(0, 1);
lines(end+1) = "# Ridge temperature susceptibility test report";
lines(end+1) = "";
lines(end+1) = "**Goal**: determine whether a1(T) corresponds to the temperature " + ...
    "derivative of the switching signal evaluated at the ridge, " + ...
    "i.e., the ridge temperature susceptibility `d/dT[S_ridge(T)]`.";
lines(end+1) = "";
lines(end+1) = "## Sources";
lines(end+1) = "- a1 run: `" + source.a1RunId + "`";
lines(end+1) = "- Geometry / ridge run: `" + source.geomRunId + "`";
lines(end+1) = "- Switching map run: `" + source.mapRunId + "`";
lines(end+1) = "- a1 file: `" + string(source.a1Path) + "`";
lines(end+1) = "- Geometry file: `" + string(source.geomPath) + "`";
lines(end+1) = "- Map file: `" + string(source.mapPath) + "`";
lines(end+1) = "";
lines(end+1) = "## Method";
lines(end+1) = "1. Load long-format switching map S(I, T) and geometry observables I_peak(T), S_peak(T).";
lines(end+1) = "2. For each T, evaluate `S_ridge(T) = S(I_peak(T), T)` by direct grid lookup " + ...
    "(with linear interpolation in I if I_peak lies between grid points).";
lines(end+1) = sprintf("   - Points using interpolation: %d.", nInterp);
lines(end+1) = sprintf("   - Points using geom-table fallback (I not in map): %d.", nFallback);
lines(end+1) = sprintf("   - Maximum relative deviation |S_map - S_geom| / max|S_geom|: %.4g.", maxRelDiff);
lines(end+1) = "3. Compute `rts(T) = d/dT[S_ridge(T)]` using Savitzky-Golay smoothing + gradient (`gradient` MATLAB).";
lines(end+1) = "   - Smooth method: `" + string(corrTbl.smooth_method(1)) + "`.";
lines(end+1) = "   - Sgolay polynomial order: `" + string(cfg.sgolayPolynomialOrder) + ...
    "`, frame: `" + string(cfg.sgolayFrameLength) + "`.";
lines(end+1) = "4. Align a1(T) and rts(T) by temperature intersection.";
lines(end+1) = "5. Temperature range: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`.";
lines(end+1) = sprintf("6. n_points after alignment: `%d`.", corrTbl.n_points(1));
lines(end+1) = "";
lines(end+1) = "## Results";
lines(end+1) = sprintf("- **Pearson correlation** (a1 vs rts): `%.6f`.", pearsonR);
lines(end+1) = sprintf("- **Spearman correlation** (a1 vs rts): `%.6f`.", spearmanR);
lines(end+1) = "";
lines(end+1) = "### Peak alignment";
lines(end+1) = sprintf("- T_peak(|a1|):   `%.2f K`.", a1PeakT);
lines(end+1) = sprintf("- T_peak(|rts|):  `%.2f K`.", rtsPeakT);
lines(end+1) = sprintf("- ΔT_peak:        `%.2f K`.", deltaPeak);
lines(end+1) = "";
lines(end+1) = "### Fits (a1 regressed on rts)";
lines(end+1) = sprintf("- Through-origin:  c = `%.6g`,  R² = `%.4f`,  RMSE = `%.4g`.", ...
    corrTbl.fit_origin_c(1), corrTbl.fit_origin_r2(1), corrTbl.fit_origin_rmse(1));
lines(end+1) = sprintf("- Linear fit:  slope = `%.6g`, intercept = `%.6g`,  R² = `%.4f`,  RMSE = `%.4g`.", ...
    corrTbl.fit_slope(1), corrTbl.fit_intercept(1), corrTbl.fit_r2(1), corrTbl.fit_rmse(1));
lines(end+1) = "";
lines(end+1) = "## Interpretation";
if isStrong
    lines(end+1) = "**Strong correlation** (|r| ≥ " + string(0.7) + " for both metrics).";
    lines(end+1) = "";
    lines(end+1) = "a1(T) is strongly consistent with the ridge temperature susceptibility " + ...
        "`d/dT[S_ridge(T)]`. This supports interpreting the dynamic mode a1 as the " + ...
        "rate at which the switching amplitude at the ridge responds to temperature change.";
    if abs(deltaPeak) <= 2
        lines(end+1) = "Peak alignment is within ≤2 K, consistent with co-located temperature response features.";
    else
        lines(end+1) = sprintf("Peak alignment offset of %.1f K may indicate a temperature lag or " + ...
            "slightly different thermal sensitivities between the mode and the ridge amplitude.", deltaPeak);
    end
else
    lines(end+1) = "Correlation is sub-threshold (|r| < " + string(0.7) + " for at least one metric).";
    lines(end+1) = "";
    lines(end+1) = "a1(T) is not strongly explained by the ridge temperature susceptibility alone. " + ...
        "Alternative mode interpretations should be explored.";
end
lines(end+1) = "";
lines(end+1) = "**Caveat**: Correlation evidence alone does not confirm a mechanistic link. " + ...
    "Independent evidence (e.g., functional form matching, amplitude scaling) would strengthen any claim.";
lines(end+1) = "";
lines(end+1) = "## Artifacts";
lines(end+1) = "- Series table: `" + string(seriesPath) + "`";
lines(end+1) = "- Correlations table: `" + string(corrPath) + "`";
lines(end+1) = "- Overlay figure: `" + string(figOverlay.png) + "`";
lines(end+1) = "- Scatter figure: `" + string(figScatter.png) + "`";
lines(end+1) = "";
lines(end+1) = "![ridge_temp_susceptibility_overlay](../figures/ridge_temp_susceptibility_overlay.png)";
lines(end+1) = "";
lines(end+1) = "![ridge_temp_susceptibility_scatter](../figures/ridge_temp_susceptibility_scatter.png)";
lines(end+1) = "";
lines(end+1) = "## Visualization notes";
lines(end+1) = "- Figure 1: 4 curves (signed-norm and abs-norm for each series), ≤6 → explicit legend.";
lines(end+1) = "- Figure 2: scatter color-coded by temperature (parula colormap) with linear fit.";
lines(end+1) = "- Both figures: LineWidth ≥ 2, FontSize ≥ 14.";
lines(end+1) = "";
lines(end+1) = "---";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

% =======================================================================
% ZIP
% =======================================================================

function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7; mkdir(reviewDir); end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2; delete(zipPath); end

candidates = { ...
    fullfile(runDir, 'figures', 'ridge_temp_susceptibility_overlay.png'), ...
    fullfile(runDir, 'figures', 'ridge_temp_susceptibility_scatter.png'), ...
    fullfile(runDir, 'figures', 'ridge_temp_susceptibility_overlay.pdf'), ...
    fullfile(runDir, 'figures', 'ridge_temp_susceptibility_scatter.pdf'), ...
    fullfile(runDir, 'tables',  'ridge_temperature_susceptibility_series.csv'), ...
    fullfile(runDir, 'tables',  'ridge_temperature_susceptibility_correlations.csv'), ...
    fullfile(runDir, 'tables',  'ridge_sridge_consistency_check.csv'), ...
    fullfile(runDir, 'reports', 'ridge_temperature_susceptibility_report.md'), ...
    fullfile(runDir, 'run_manifest.json'), ...
    fullfile(runDir, 'log.txt'), ...
    fullfile(runDir, 'run_notes.txt')};

existing = {};
for i = 1:numel(candidates)
    if exist(candidates{i}, 'file') == 2
        existing{end+1} = candidates{i}; %#ok<AGROW>
    end
end
if ~isempty(existing)
    zip(zipPath, existing, runDir);
end
end

% =======================================================================
% Micro-utilities
% =======================================================================

function cfg = setdf(cfg, name, val)
if ~isfield(cfg, name) || isempty(cfg.(name)); cfg.(name) = val; end
end

function appendText(filePath, txt)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1; warning('Cannot append to %s', filePath); return; end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', char(string(txt)));
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function assertDir(p, label)
if exist(p, 'dir') ~= 7
    error('Required %s not found: %s', label, p);
end
end

function assertFile(p, label)
if exist(p, 'file') ~= 2
    error('Required %s not found: %s', label, p);
end
end

function assertCol(tbl, col, filePath)
if ~ismember(col, tbl.Properties.VariableNames)
    error('Table missing column "%s": %s', col, filePath);
end
end
