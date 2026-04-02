function out = switching_a1_vs_mobility_test(cfg)
% switching_a1_vs_mobility_test
% Test whether the dynamic shape-mode amplitude a1(T) corresponds to a
% mobility / depinning response of the switching ridge.
%
% Observables compared against a1(T):
%   1. ridge_mobility_index(T)  = |dI_peak/dT| / width(T)  [1/K]
%   2. dS_peak/dT(T)            geometric amplitude derivative [1/K]
%   3. dI_peak/dT(T)            ridge-center motion rate [mA/K]
%
% Sources:
%   - a1:               switching dynamic shape mode run
%   - ridge_mobility:   effective observables catalog run (new tables)
%   - dS_peak/dT,
%     dI_peak/dT:       switching geometry diagnostics run
%
% Outputs (run directory): correlation summary, aligned series, overlay /
%   normalised overlay / scatter figures, markdown report, ZIP bundle.

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
runCfg.dataset = sprintf('a1:%s | catalog:%s | geom:%s', ...
    char(source.a1RunName), char(source.catalogRunName), char(source.geomRunName));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching a1-vs-mobility test run directory:\n%s\n', runDir);
fprintf('a1 source run:     %s\n', source.a1RunName);
fprintf('catalog run:       %s\n', source.catalogRunName);
fprintf('geometry run:      %s\n', source.geomRunName);
appendText(run.log_path, sprintf('[%s] switching a1-vs-mobility test started\n', stampNow()));
appendText(run.log_path, sprintf('a1 run:      %s\n', char(source.a1RunName)));
appendText(run.log_path, sprintf('catalog run: %s\n', char(source.catalogRunName)));
appendText(run.log_path, sprintf('geom run:    %s\n', char(source.geomRunName)));

% ---- Load data ----------------------------------------------------------
a1Data    = loadA1Table(source.a1Path, cfg.a1ColumnName);
mobData   = loadMobilityTable(source.catalogPath);
geomData  = loadGeomTable(source.geomPath);

% Three-way temperature intersection
T_all = intersect(intersect(a1Data.T_K, mobData.T_K, 'stable'), geomData.T_K, 'stable');
if isempty(T_all)
    error('No common temperatures across a1, mobility, and geometry sources.');
end

[~, iA1]  = ismember(T_all, a1Data.T_K);
[~, iMob] = ismember(T_all, mobData.T_K);
[~, iGeom] = ismember(T_all, geomData.T_K);

a1_raw   = double(a1Data.a1(iA1));
rmi_raw  = double(mobData.ridge_mobility_index(iMob));
dS_raw   = double(geomData.dS_peak_dT(iGeom));
dI_raw   = double(geomData.dI_peak_dT(iGeom));

% Apply temperature range filter
maskRange = T_all >= cfg.temperatureMinK & T_all <= cfg.temperatureMaxK;
T  = double(T_all(maskRange));
a1 = a1_raw(maskRange);
rmi = rmi_raw(maskRange);
dS  = dS_raw(maskRange);
dI  = dI_raw(maskRange);

if numel(T) < 5
    error('Need at least 5 temperature points after range filter (got %d).', numel(T));
end

a1  = fillByInterp(T, a1);
rmi = fillByInterp(T, rmi);
dS  = fillByInterp(T, dS);
dI  = fillByInterp(T, dI);

% ---- Validity mask (require all four finite) ---------------------------
valid = isfinite(T) & isfinite(a1) & isfinite(rmi) & isfinite(dS) & isfinite(dI);
if nnz(valid) < 3
    error('Fewer than 3 finite rows after alignment (n=%d).', nnz(valid));
end

Tv   = T(valid);
a1v  = a1(valid);
rmiv = rmi(valid);
dSv  = dS(valid);
dIv  = dI(valid);

% ---- Correlations -------------------------------------------------------
pR_rmi = safeCorr(a1v, rmiv, 'Pearson');
sR_rmi = safeCorr(a1v, rmiv, 'Spearman');

pR_dS  = safeCorr(a1v, dSv, 'Pearson');
sR_dS  = safeCorr(a1v, dSv, 'Spearman');

pR_dI  = safeCorr(a1v, dIv, 'Pearson');
sR_dI  = safeCorr(a1v, dIv, 'Spearman');

% ---- Peak alignment -----------------------------------------------------
[a1PeakT, ~]  = peakOf(Tv, a1v,  true);
[rmiPeakT, ~] = peakOf(Tv, rmiv, true);
[dSPeakT, ~]  = peakOf(Tv, dSv,  true);
[dIPeakT, ~]  = peakOf(Tv, dIv,  true);

dPeak_rmi = rmiPeakT - a1PeakT;
dPeak_dS  = dSPeakT  - a1PeakT;
dPeak_dI  = dIPeakT  - a1PeakT;

% ---- Best score ---------------------------------------------------------
score_rmi = mean(abs([pR_rmi, sR_rmi]), 'omitnan');
score_dS  = mean(abs([pR_dS,  sR_dS]),  'omitnan');
score_dI  = mean(abs([pR_dI,  sR_dI]),  'omitnan');

scores      = [score_rmi, score_dS, score_dI];
obsNames    = ["ridge_mobility_index", "dS_peak_dT", "dI_peak_dT"];
[~, bestIdx] = max(scores);
bestObs      = obsNames(bestIdx);

isStrongRMI = isfinite(pR_rmi) && isfinite(sR_rmi) && ...
    abs(pR_rmi) >= cfg.strongCorrThreshold && abs(sR_rmi) >= cfg.strongCorrThreshold;
isMobilityDriver = isStrongRMI && (score_rmi >= cfg.minScoreForMobility);

% ---- Fits: a1 vs each observable ----------------------------------------
[c0_rmi, yHat_rmi, ~, r2_rmi, rmse_rmi] = fitThroughOrigin(rmiv, a1v);
[c0_dS,  yHat_dS,  ~, r2_dS,  rmse_dS]  = fitThroughOrigin(dSv,  a1v);
[c0_dI,  yHat_dI,  ~, r2_dI,  rmse_dI]  = fitThroughOrigin(dIv,  a1v);

% ---- Correlation summary table -----------------------------------------
corrTbl = buildCorrelationTable( ...
    nnz(valid), ...
    pR_rmi, sR_rmi, score_rmi, a1PeakT, rmiPeakT, dPeak_rmi, ...
    c0_rmi, r2_rmi, rmse_rmi, ...
    pR_dS,  sR_dS,  score_dS,           dSPeakT,  dPeak_dS, ...
    c0_dS,  r2_dS,  rmse_dS, ...
    pR_dI,  sR_dI,  score_dI,           dIPeakT,  dPeak_dI, ...
    c0_dI,  r2_dI,  rmse_dI, ...
    bestObs, isMobilityDriver, ...
    cfg, source);

% ---- Aligned series table ----------------------------------------------
a1Norm  = normalizeSigned(a1v);
rmiNorm = normalizeSigned(rmiv);
dSNorm  = normalizeSigned(dSv);
dINorm  = normalizeSigned(dIv);
a1Abs   = normalize01(abs(a1v));
rmiAbs  = normalize01(abs(rmiv));
dSAbs   = normalize01(abs(dSv));
dIAbs   = normalize01(abs(dIv));

seriesTbl = table(Tv, a1v, rmiv, dSv, dIv, ...
    a1Norm, rmiNorm, dSNorm, dINorm, ...
    a1Abs,  rmiAbs,  dSAbs,  dIAbs, ...
    yHat_rmi, yHat_dS, yHat_dI, ...
    'VariableNames', { ...
    'T_K', 'a1', 'ridge_mobility_index', 'dS_peak_dT', 'dI_peak_dT', ...
    'a1_norm_signed',  'rmi_norm_signed',  'dS_norm_signed',  'dI_norm_signed', ...
    'a1_abs_norm',     'rmi_abs_norm',     'dS_abs_norm',     'dI_abs_norm', ...
    'a1_fit_from_rmi', 'a1_fit_from_dS',   'a1_fit_from_dI'});

% ---- Peak table ---------------------------------------------------------
peakTbl = table( ...
    string({'a1'; 'ridge_mobility_index'; 'dS_peak_dT'; 'dI_peak_dT'}), ...
    [a1PeakT; rmiPeakT; dSPeakT; dIPeakT], ...
    [NaN; dPeak_rmi; dPeak_dS; dPeak_dI], ...
    'VariableNames', {'observable', 'peak_T_K', 'delta_vs_a1_K'});

% ---- Save tables --------------------------------------------------------
corrPath   = save_run_table(corrTbl,   'a1_vs_mobility_correlations.csv',  runDir);
seriesPath = save_run_table(seriesTbl, 'a1_vs_mobility_series.csv',        runDir);
peakPath   = save_run_table(peakTbl,   'a1_vs_mobility_peaks.csv',         runDir);

% ---- Figures ------------------------------------------------------------
figOverlay    = saveOverlayAllFigure(Tv, a1Norm, rmiNorm, dSNorm, dINorm, ...
                    a1Abs,  rmiAbs,  dSAbs,  dIAbs, corrTbl, runDir, ...
                    'a1_vs_mobility_overlay');

figRMI        = savePairFigure(Tv, a1v, a1Norm, rmiv, rmiNorm, ...
                    'a1', 'ridge\_mobility\_index', ...
                    pR_rmi, sR_rmi, dPeak_rmi, runDir, ...
                    'a1_vs_ridge_mobility_index');

figDS         = savePairFigure(Tv, a1v, a1Norm, dSv, dSNorm, ...
                    'a1', 'dS\_peak/dT', ...
                    pR_dS, sR_dS, dPeak_dS, runDir, ...
                    'a1_vs_dS_peak_dT');

figDI         = savePairFigure(Tv, a1v, a1Norm, dIv, dINorm, ...
                    'a1', 'dI\_peak/dT', ...
                    pR_dI, sR_dI, dPeak_dI, runDir, ...
                    'a1_vs_dI_peak_dT');

figScatterRMI = saveScatterFigure(rmiv, a1v, yHat_rmi, ...
                    'ridge\_mobility\_index', 'a1', ...
                    pR_rmi, sR_rmi, c0_rmi, r2_rmi, runDir, ...
                    'scatter_a1_vs_ridge_mobility');

figScatterDS  = saveScatterFigure(dSv, a1v, yHat_dS, ...
                    'dS\_peak/dT', 'a1', ...
                    pR_dS, sR_dS, c0_dS, r2_dS, runDir, ...
                    'scatter_a1_vs_dS_peak_dT');

figScatterDI  = saveScatterFigure(dIv, a1v, yHat_dI, ...
                    'dI\_peak/dT', 'a1', ...
                    pR_dI, sR_dI, c0_dI, r2_dI, runDir, ...
                    'scatter_a1_vs_dI_peak_dT');

figures = struct( ...
    'overlay',       string(figOverlay.png), ...
    'pair_rmi',      string(figRMI.png), ...
    'pair_dS',       string(figDS.png), ...
    'pair_dI',       string(figDI.png), ...
    'scatter_rmi',   string(figScatterRMI.png), ...
    'scatter_dS',    string(figScatterDS.png), ...
    'scatter_dI',    string(figScatterDI.png));

% ---- Report + ZIP -------------------------------------------------------
reportText = buildReport(source, cfg, corrTbl, peakTbl, figures, ...
    corrPath, seriesPath, peakPath, isMobilityDriver);
reportPath = save_run_report(reportText, 'a1_vs_mobility_report.md', runDir);
zipPath    = buildReviewZip(runDir, 'switching_a1_vs_mobility_bundle.zip');

% ---- Notes / log --------------------------------------------------------
appendText(run.notes_path, sprintf('a1 source run          = %s\n', char(source.a1RunName)));
appendText(run.notes_path, sprintf('catalog run            = %s\n', char(source.catalogRunName)));
appendText(run.notes_path, sprintf('geometry run           = %s\n', char(source.geomRunName)));
appendText(run.notes_path, sprintf('n_points               = %d\n', nnz(valid)));
appendText(run.notes_path, sprintf('T_peak(|a1|)           = %.2f K\n', a1PeakT));
appendText(run.notes_path, sprintf('T_peak(|rmi|)          = %.2f K\n', rmiPeakT));
appendText(run.notes_path, sprintf('T_peak(|dS/dT|)        = %.2f K\n', dSPeakT));
appendText(run.notes_path, sprintf('T_peak(|dI/dT|)        = %.2f K\n', dIPeakT));
appendText(run.notes_path, sprintf('pearson(a1, rmi)       = %.6f\n', pR_rmi));
appendText(run.notes_path, sprintf('spearman(a1, rmi)      = %.6f\n', sR_rmi));
appendText(run.notes_path, sprintf('pearson(a1, dS/dT)     = %.6f\n', pR_dS));
appendText(run.notes_path, sprintf('spearman(a1, dS/dT)    = %.6f\n', sR_dS));
appendText(run.notes_path, sprintf('pearson(a1, dI/dT)     = %.6f\n', pR_dI));
appendText(run.notes_path, sprintf('spearman(a1, dI/dT)    = %.6f\n', sR_dI));
appendText(run.notes_path, sprintf('best observable        = %s\n', char(bestObs)));
appendText(run.notes_path, sprintf('is_mobility_driver     = %d\n', isMobilityDriver));
appendText(run.notes_path, sprintf('correlation table      = %s\n', corrPath));
appendText(run.notes_path, sprintf('series table           = %s\n', seriesPath));
appendText(run.notes_path, sprintf('overlay figure         = %s\n', figOverlay.png));
appendText(run.notes_path, sprintf('report                 = %s\n', reportPath));
appendText(run.notes_path, sprintf('zip                    = %s\n', zipPath));

appendText(run.log_path, sprintf('[%s] switching a1-vs-mobility test complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlation table: %s\n', corrPath));
appendText(run.log_path, sprintf('Report:           %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP:              %s\n', zipPath));

% ---- Output struct ------------------------------------------------------
out = struct();
out.run     = run;
out.runDir  = string(runDir);
out.source  = source;
out.metrics = struct( ...
    'pearson_rmi',       pR_rmi,  'spearman_rmi',     sR_rmi,  ...
    'pearson_dS',        pR_dS,   'spearman_dS',      sR_dS,   ...
    'pearson_dI',        pR_dI,   'spearman_dI',      sR_dI,   ...
    'a1_peak_T_K',       a1PeakT, ...
    'rmi_peak_T_K',      rmiPeakT,'dS_peak_T_K',      dSPeakT, ...
    'dI_peak_T_K',       dIPeakT, ...
    'best_observable',   bestObs,  'is_mobility_driver', isMobilityDriver);
out.paths = struct( ...
    'correlations', string(corrPath),      'series', string(seriesPath), ...
    'peaks',        string(peakPath),      'report', string(reportPath), ...
    'zip',          string(zipPath),       'figures', figures);

fprintf('\n=== Switching a1-vs-mobility test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson(a1, ridge_mobility_index) = %.6f\n', pR_rmi);
fprintf('Spearman(a1, ridge_mobility_index)= %.6f\n', sR_rmi);
fprintf('Pearson(a1, dS_peak/dT)           = %.6f\n', pR_dS);
fprintf('Spearman(a1, dS_peak/dT)          = %.6f\n', sR_dS);
fprintf('Pearson(a1, dI_peak/dT)           = %.6f\n', pR_dI);
fprintf('Spearman(a1, dI_peak/dT)          = %.6f\n', sR_dI);
fprintf('Best observable: %s\n', char(bestObs));
fprintf('a1 is mobility driver: %d\n', isMobilityDriver);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP:    %s\n\n', zipPath);
end

% =========================================================================
%  Configuration
% =========================================================================
function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel',             'switching_a1_vs_mobility_test');
cfg = setDefaultField(cfg, 'a1ColumnName',         'a_1');
cfg = setDefaultField(cfg, 'temperatureMinK',      4);
cfg = setDefaultField(cfg, 'temperatureMaxK',      30);
cfg = setDefaultField(cfg, 'strongCorrThreshold',  0.70);
cfg = setDefaultField(cfg, 'minScoreForMobility',  0.60);
% Source run names (latest runs by default)
cfg = setDefaultField(cfg, 'a1RunName', ...
    'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'catalogRunName', ...
    'run_2026_03_15_210701_effective_observables_catalog');
cfg = setDefaultField(cfg, 'geomRunName', ...
    'run_2026_03_13_112155_switching_geometry_diagnostics');
end

% =========================================================================
%  Source resolution
% =========================================================================
function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.a1RunName      = string(cfg.a1RunName);
source.catalogRunName = string(cfg.catalogRunName);
source.geomRunName    = string(cfg.geomRunName);

source.phi1Guard = enforce_canonical_phi1_source({source.a1RunName}, 'switching_a1_vs_mobility_test');

source.a1RunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.a1RunName));
source.catalogRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    char(source.catalogRunName));
source.geomRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.geomRunName));

source.a1Path      = fullfile(source.a1RunDir,      'tables', ...
    'switching_dynamic_shape_mode_amplitudes.csv');
source.catalogPath = fullfile(source.catalogRunDir, 'tables', ...
    'new_switching_observables_vs_T.csv');
source.geomPath    = fullfile(source.geomRunDir,    'tables', ...
    'switching_geometry_observables.csv');

requiredDirs  = {source.a1RunDir; source.catalogRunDir; source.geomRunDir};
requiredFiles = {source.a1Path;   source.catalogPath;   source.geomPath};
labels        = {'a1 run dir'; 'catalog run dir'; 'geometry run dir'};
fLabels       = {'a1 file';    'catalog file';    'geometry file'};

for i = 1:numel(requiredDirs)
    if exist(requiredDirs{i}, 'dir') ~= 7
        error('switching_a1_vs_mobility_test: Missing source run directory (%s): %s', ...
            labels{i}, requiredDirs{i});
    end
end
for i = 1:numel(requiredFiles)
    if exist(requiredFiles{i}, 'file') ~= 2
        error('switching_a1_vs_mobility_test: Missing source file (%s): %s', ...
            fLabels{i}, requiredFiles{i});
    end
end
end

% =========================================================================
%  Loaders
% =========================================================================
function data = loadA1Table(pathValue, a1ColumnName)
tbl = readtable(pathValue);
if ~ismember('T_K', tbl.Properties.VariableNames)
    error('a1 table missing T_K column: %s', pathValue);
end
if ~ismember(a1ColumnName, tbl.Properties.VariableNames)
    found = strjoin(tbl.Properties.VariableNames, ', ');
    error('a1 table missing column "%s" in %s.\nAvailable: %s', ...
        a1ColumnName, pathValue, found);
end
tbl = sortrows(tbl, 'T_K');
data.T_K = double(tbl.T_K(:));
data.a1  = double(tbl.(a1ColumnName)(:));
end

function data = loadMobilityTable(pathValue)
tbl = readtable(pathValue);
required = {'T_K', 'ridge_mobility_index'};
for i = 1:numel(required)
    if ~ismember(required{i}, tbl.Properties.VariableNames)
        error('Catalog table missing column "%s": %s', required{i}, pathValue);
    end
end
tbl = sortrows(tbl, 'T_K');
data.T_K                = double(tbl.T_K(:));
data.ridge_mobility_index = double(tbl.ridge_mobility_index(:));
end

function data = loadGeomTable(pathValue)
tbl = readtable(pathValue);
required = {'T_K', 'dS_peak_dT_per_K', 'dI_peak_dT_mA_per_K'};
for i = 1:numel(required)
    if ~ismember(required{i}, tbl.Properties.VariableNames)
        error('Geometry table missing column "%s": %s', required{i}, pathValue);
    end
end
tbl = sortrows(tbl, 'T_K');
data.T_K       = double(tbl.T_K(:));
data.dS_peak_dT = double(tbl.dS_peak_dT_per_K(:));
data.dI_peak_dT = double(tbl.dI_peak_dT_mA_per_K(:));
end

% =========================================================================
%  Math helpers
% =========================================================================
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
peakT = NaN; peakVal = NaN;
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
x = x(:); y = y(:);
mask = isfinite(x) & isfinite(y);
x = x(mask); y = y(mask);
if isempty(x) || sum(x .^ 2) <= eps
    c = NaN; yHat = NaN(size(y)); residuals = NaN(size(y)); r2 = NaN; rmse = NaN;
    return;
end
c = (x' * y) / max(x' * x, eps);
yHat = c .* x;
residuals = y - yHat;
sse = sum(residuals .^ 2);
sst = sum((y - mean(y, 'omitnan')) .^ 2);
r2  = ternaryVal(sst > eps, 1 - sse / sst, NaN);
rmse = sqrt(mean(residuals .^ 2, 'omitnan'));
end

function v = ternaryVal(cond, a, b)
if cond; v = a; else; v = b; end
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
mn = min(x, [], 'omitnan'); mx = max(x, [], 'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn
    y = zeros(size(x));
else
    y = (x - mn) ./ (mx - mn);
end
end

function cfg = setDefaultField(cfg, field, val)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = val;
end
end

% =========================================================================
%  Table builder
% =========================================================================
function tbl = buildCorrelationTable( ...
    n, ...
    pR_rmi, sR_rmi, score_rmi, a1PeakT, rmiPeakT, dPeak_rmi, ...
    c0_rmi, r2_rmi, rmse_rmi, ...
    pR_dS,  sR_dS,  score_dS,            dSPeakT,  dPeak_dS, ...
    c0_dS,  r2_dS,  rmse_dS, ...
    pR_dI,  sR_dI,  score_dI,            dIPeakT,  dPeak_dI, ...
    c0_dI,  r2_dI,  rmse_dI, ...
    bestObs, isMobilityDriver, ...
    cfg, source)

tbl = table( ...
    n, ...
    pR_rmi, sR_rmi, score_rmi, ...
    pR_dS,  sR_dS,  score_dS, ...
    pR_dI,  sR_dI,  score_dI, ...
    bestObs, ...
    double(isMobilityDriver), ...
    a1PeakT, rmiPeakT, dSPeakT, dIPeakT, ...
    dPeak_rmi, dPeak_dS, dPeak_dI, ...
    c0_rmi, r2_rmi, rmse_rmi, ...
    c0_dS,  r2_dS,  rmse_dS, ...
    c0_dI,  r2_dI,  rmse_dI, ...
    cfg.temperatureMinK, cfg.temperatureMaxK, ...
    source.a1RunName, source.catalogRunName, source.geomRunName, ...
    string(source.a1Path), string(source.catalogPath), string(source.geomPath), ...
    'VariableNames', { ...
    'n_points', ...
    'pearson_a1_vs_rmi',      'spearman_a1_vs_rmi',     'score_rmi', ...
    'pearson_a1_vs_dS_dT',    'spearman_a1_vs_dS_dT',   'score_dS', ...
    'pearson_a1_vs_dI_dT',    'spearman_a1_vs_dI_dT',   'score_dI', ...
    'best_observable', 'is_mobility_driver', ...
    'a1_peak_T_K', 'rmi_peak_T_K', 'dS_peak_T_K', 'dI_peak_T_K', ...
    'delta_peak_rmi_K', 'delta_peak_dS_K', 'delta_peak_dI_K', ...
    'fit_origin_c_rmi', 'fit_origin_r2_rmi', 'fit_origin_rmse_rmi', ...
    'fit_origin_c_dS',  'fit_origin_r2_dS',  'fit_origin_rmse_dS', ...
    'fit_origin_c_dI',  'fit_origin_r2_dI',  'fit_origin_rmse_dI', ...
    'T_min_K', 'T_max_K', ...
    'a1_source_run', 'catalog_source_run', 'geom_source_run', ...
    'a1_source_file', 'catalog_source_file', 'geom_source_file'});
end

% =========================================================================
%  Figure helpers
% =========================================================================
function figOut = saveOverlayAllFigure(T, a1N, rmiN, dSN, dIN, ...
    a1A, rmiA, dSA, dIA, corrTbl, runDir, baseName)
% Two-panel figure: signed-norm (left) and |.| norm (right).
lw = 2.2; ms = 5.0;
colorA1  = [0.00 0.45 0.74];
colorRMI = [0.85 0.33 0.10];
colorDS  = [0.47 0.67 0.19];
colorDI  = [0.49 0.18 0.56];

fig = create_figure('Visible', 'off', 'Position', [2 2 16 8]);
tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
hold(ax1, 'on');
plot(ax1, T, a1N,  '-o', 'Color', colorA1,  'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorA1,  'DisplayName', 'a_1 signed-norm');
plot(ax1, T, rmiN, '-s', 'Color', colorRMI, 'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorRMI, 'DisplayName', 'ridge\_mobility\_index');
plot(ax1, T, dSN,  '-^', 'Color', colorDS,  'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorDS,  'DisplayName', 'dS\_peak/dT');
plot(ax1, T, dIN,  '-d', 'Color', colorDI,  'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorDI,  'DisplayName', 'dI\_peak/dT');
yline(ax1, 0, '-', 'LineWidth', 1.0, 'Color', [0.7 0.7 0.7]);
hold(ax1, 'off');
xlabel(ax1, 'T (K)', 'FontSize', 13);
ylabel(ax1, 'Signed norm', 'FontSize', 13);
title(ax1, 'Signed normalised overlay', 'FontSize', 12);
styledAx(ax1);
legend(ax1, 'Location', 'best', 'FontSize', 9);

ax2 = nexttile;
hold(ax2, 'on');
plot(ax2, T, a1A,  '-o', 'Color', colorA1,  'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorA1,  'DisplayName', '|a_1| norm');
plot(ax2, T, rmiA, '-s', 'Color', colorRMI, 'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorRMI, 'DisplayName', '|ridge\_mobility|');
plot(ax2, T, dSA,  '-^', 'Color', colorDS,  'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorDS,  'DisplayName', '|dS\_peak/dT|');
plot(ax2, T, dIA,  '-d', 'Color', colorDI,  'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorDI,  'DisplayName', '|dI\_peak/dT|');
hold(ax2, 'off');
xlabel(ax2, 'T (K)', 'FontSize', 13);
ylabel(ax2, '[0,1] norm', 'FontSize', 13);
title(ax2, 'Absolute normalised overlay', 'FontSize', 12);
styledAx(ax2);
legend(ax2, 'Location', 'best', 'FontSize', 9);

sgtitle(fig, sprintf('a_1(T) vs mobility observables | R(rmi)=%.3f/%.3f | R(dS)=%.3f/%.3f | R(dI)=%.3f/%.3f', ...
    corrTbl.pearson_a1_vs_rmi(1),  corrTbl.spearman_a1_vs_rmi(1), ...
    corrTbl.pearson_a1_vs_dS_dT(1), corrTbl.spearman_a1_vs_dS_dT(1), ...
    corrTbl.pearson_a1_vs_dI_dT(1), corrTbl.spearman_a1_vs_dI_dT(1)), ...
    'FontSize', 11);

figOut = robustSaveFigure(fig, baseName, runDir);
close(fig);
end

function figOut = savePairFigure(T, a1, a1N, obs, obsN, ...
    a1Label, obsLabel, pearsonR, spearmanR, dPeak, runDir, baseName)
lw = 2.2; ms = 5.5;
colorA1  = [0.00 0.45 0.74];
colorObs = [0.85 0.33 0.10];

fig = create_figure('Visible', 'off', 'Position', [2 2 13.5 9.6]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, T, a1N, '-o', 'Color', colorA1,  'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorA1,  'DisplayName', [a1Label ' signed-norm']);
plot(ax, T, obsN, '-s', 'Color', colorObs, 'LineWidth', lw, 'MarkerSize', ms, ...
    'MarkerFaceColor', colorObs, 'DisplayName', [obsLabel ' signed-norm']);
plot(ax, T, normalize01(abs(a1)),  '--', 'Color', [0.20 0.20 0.20], 'LineWidth', 2.0, ...
    'DisplayName', ['|' a1Label '| norm']);
plot(ax, T, normalize01(abs(obs)), ':',  'Color', [0.47 0.67 0.19], 'LineWidth', 2.2, ...
    'DisplayName', ['|' obsLabel '| norm']);
yline(ax, 0, '-', 'LineWidth', 1.0, 'Color', [0.70 0.70 0.70]);
hold(ax, 'off');
xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalised amplitude', 'FontSize', 14);
title(ax, sprintf('%s vs %s | Pearson=%.4f, Spearman=%.4f, \\DeltaT_{peak}=%.1f K', ...
    a1Label, obsLabel, pearsonR, spearmanR, dPeak), 'FontSize', 12);
styledAx(ax);
legend(ax, 'Location', 'best', 'FontSize', 10);

figOut = robustSaveFigure(fig, baseName, runDir);
close(fig);
end

function figOut = saveScatterFigure(x, y, yHat, xLabel, yLabel, ...
    pearsonR, spearmanR, c0, r2, runDir, baseName)
colorData = [0.00 0.45 0.74];
colorFit  = [0.85 0.33 0.10];

fig = create_figure('Visible', 'off', 'Position', [2 2 9 9]);
ax = axes(fig);
hold(ax, 'on');
scatter(ax, x, y, 36, colorData, 'filled', 'MarkerFaceAlpha', 0.75, ...
    'DisplayName', 'data');
if ~isempty(x) && ~any(isnan(yHat))
    [xSorted, si] = sort(x);
    plot(ax, xSorted, yHat(si), '-', 'Color', colorFit, 'LineWidth', 2.0, ...
        'DisplayName', sprintf('origin fit  c=%.3g, R^2=%.3f', c0, r2));
end
hold(ax, 'off');
xlabel(ax, xLabel, 'FontSize', 14);
ylabel(ax, yLabel, 'FontSize', 14);
title(ax, sprintf('%s vs %s | P=%.4f, S=%.4f', yLabel, xLabel, pearsonR, spearmanR), ...
    'FontSize', 12);
styledAx(ax);
legend(ax, 'Location', 'best', 'FontSize', 10);
axis(ax, 'equal');

figOut = robustSaveFigure(fig, baseName, runDir);
close(fig);
end

function styledAx(ax)
set(ax, 'FontSize', 13, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
end

function figOut = robustSaveFigure(fig, baseName, runDir)
try
    figOut = save_run_figure(fig, baseName, runDir);
catch ME
    warning('switching_a1_vs_mobility_test:saveFigureFallback', ...
        'save_run_figure failed (%s); using fallback export.', ME.message);
    figuresDir = fullfile(runDir, 'figures');
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    figOut.png = fullfile(figuresDir, [baseName '.png']);
    figOut.fig = fullfile(figuresDir, [baseName '.fig']);
    figOut.pdf = fullfile(figuresDir, [baseName '.pdf']);
    exportgraphics(fig, figOut.png, 'Resolution', 300);
    savefig(fig, figOut.fig);
    try
        exportgraphics(fig, figOut.pdf, 'ContentType', 'vector');
    catch
        % PDF optional.
    end
end
end

% =========================================================================
%  Report
% =========================================================================
function txt = buildReport(source, cfg, corrTbl, peakTbl, figures, ...
    corrPath, seriesPath, peakPath, isMobilityDriver)

L = strings(0, 1);
a = @(s) [L; s];  % append helper

L = a("# a1(T) vs ridge mobility / depinning susceptibility — test report");
L = a("");
L = a("## Hypothesis");
L = a("The dynamic shape-mode amplitude a1(T) is a mobility/depinning susceptibility");
L = a("of the switching ridge, tracking |dI_peak/dT| / width or equivalently dS_peak/dT.");
L = a("");
L = a("## Sources");
L = a("| Role | Run name |");
L = a("|------|----------|");
L = a(sprintf("| a1 | `%s` |", char(source.a1RunName)));
L = a(sprintf("| catalog (ridge_mobility_index) | `%s` |", char(source.catalogRunName)));
L = a(sprintf("| geometry (dS/dT, dI/dT) | `%s` |", char(source.geomRunName)));
L = a("");
L = a(sprintf("Temperature range: **%.1f – %.1f K**  |  n = **%d** points", ...
    cfg.temperatureMinK, cfg.temperatureMaxK, corrTbl.n_points(1)));
L = a("");
L = a("## Correlation results");
L = a("| Observable | Pearson r | Spearman r | Score | |a1| peak (K) | obs peak (K) | ΔT (K) |");
L = a("|-----------|-----------|------------|-------|-------------|-------------|--------|");
L = a(sprintf("| ridge_mobility_index | %.4f | %.4f | %.4f | %.2f | %.2f | %.2f |", ...
    corrTbl.pearson_a1_vs_rmi(1),   corrTbl.spearman_a1_vs_rmi(1),   corrTbl.score_rmi(1), ...
    corrTbl.a1_peak_T_K(1), corrTbl.rmi_peak_T_K(1), corrTbl.delta_peak_rmi_K(1)));
L = a(sprintf("| dS_peak/dT | %.4f | %.4f | %.4f | %.2f | %.2f | %.2f |", ...
    corrTbl.pearson_a1_vs_dS_dT(1), corrTbl.spearman_a1_vs_dS_dT(1), corrTbl.score_dS(1), ...
    corrTbl.a1_peak_T_K(1), corrTbl.dS_peak_T_K(1), corrTbl.delta_peak_dS_K(1)));
L = a(sprintf("| dI_peak/dT | %.4f | %.4f | %.4f | %.2f | %.2f | %.2f |", ...
    corrTbl.pearson_a1_vs_dI_dT(1), corrTbl.spearman_a1_vs_dI_dT(1), corrTbl.score_dI(1), ...
    corrTbl.a1_peak_T_K(1), corrTbl.dI_peak_T_K(1), corrTbl.delta_peak_dI_K(1)));
L = a("");
L = a(sprintf("**Best observable by mean |Pearson|+|Spearman|/2:** `%s`", ...
    char(corrTbl.best_observable(1))));
L = a(sprintf("**Mobility driver verdict:** `%s`", ...
    ternaryStr(isMobilityDriver, 'YES — a1 behaves like a ridge mobility/depinning susceptibility', ...
    'NO  — correlation too weak')));
L = a("");
L = a("## Fit quality (through-origin: a1 = c * observable)");
L = a("| Observable | c | R² | RMSE |");
L = a("|-----------|---|-----|------|");
L = a(sprintf("| ridge_mobility_index | %.4g | %.4f | %.4g |", ...
    corrTbl.fit_origin_c_rmi(1), corrTbl.fit_origin_r2_rmi(1), corrTbl.fit_origin_rmse_rmi(1)));
L = a(sprintf("| dS_peak/dT | %.4g | %.4f | %.4g |", ...
    corrTbl.fit_origin_c_dS(1),  corrTbl.fit_origin_r2_dS(1),  corrTbl.fit_origin_rmse_dS(1)));
L = a(sprintf("| dI_peak/dT | %.4g | %.4f | %.4g |", ...
    corrTbl.fit_origin_c_dI(1),  corrTbl.fit_origin_r2_dI(1),  corrTbl.fit_origin_rmse_dI(1)));
L = a("");
L = a("## Figures");
L = a(sprintf("![overlay](%s)", relFigPath(figures.overlay)));
L = a("");
L = a(sprintf("![pair rmi](%s)", relFigPath(figures.pair_rmi)));
L = a(sprintf("![pair dS](%s)",  relFigPath(figures.pair_dS)));
L = a(sprintf("![pair dI](%s)",  relFigPath(figures.pair_dI)));
L = a("");
L = a(sprintf("![scatter rmi](%s)", relFigPath(figures.scatter_rmi)));
L = a(sprintf("![scatter dS](%s)",  relFigPath(figures.scatter_dS)));
L = a(sprintf("![scatter dI](%s)",  relFigPath(figures.scatter_dI)));
L = a("");
L = a("## Artifacts");
L = a(sprintf("- Correlation table: `%s`", corrPath));
L = a(sprintf("- Aligned series: `%s`", seriesPath));
L = a(sprintf("- Peak table: `%s`", peakPath));
L = a("");
L = a("## Interpretation");
if isMobilityDriver
    L = a("- **Supported:** a1(T) shows strong correlation with at least one ridge");
    L = a("  mobility proxy (ridge_mobility_index), supporting the interpretation that");
    L = a("  the dynamic shape mode amplitude is a depinning susceptibility observable.");
else
    L = a("- **Not supported at threshold:** correlations between a1(T) and the");
    L = a("  tested mobility proxies do not exceed the configured threshold.");
    L = a("  Consider checking smoothing settings, temperature range, or alternative observables.");
end
L = a("- Peak alignment (ΔT columns) indicates whether the thermal scale of a1 matches the observables.");
L = a("- Limitations: finite temperature grid; correlations are descriptive only.");
L = a("");
L = a("---");
L = a(sprintf("Generated: %s", string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))));

txt = strjoin(L, newline);
end

function s = ternaryStr(cond, a, b)
if cond; s = a; else; s = b; end
end

function p = relFigPath(absPath)
% Returns a relative figures/ reference for markdown.
[~, name, ext] = fileparts(char(string(absPath)));
p = sprintf('../figures/%s%s', name, ext);
end

% =========================================================================
%  ZIP
% =========================================================================
function zipPath = buildReviewZip(runDir, zipName)
zipPath = fullfile(runDir, zipName);
try
    entries = {};
    subDirs = {'tables', 'figures', 'reports'};
    for i = 1:numel(subDirs)
        d = fullfile(runDir, subDirs{i});
        if exist(d, 'dir') == 7
            listing = dir(fullfile(d, '*'));
            for j = 1:numel(listing)
                if ~listing(j).isdir
                    entries{end + 1} = fullfile(d, listing(j).name); %#ok<AGROW>
                end
            end
        end
    end
    for f = {'notes.txt', 'log.txt'}
        fp = fullfile(runDir, f{1});
        if exist(fp, 'file') == 2
            entries{end + 1} = fp; %#ok<AGROW>
        end
    end
    if ~isempty(entries)
        zip(zipPath, entries);
    end
catch ME
    warning('switching_a1_vs_mobility_test:zipFailed', ...
        'ZIP creation failed: %s', ME.message);
end
end

% =========================================================================
%  I/O helpers (local copies — these are not globally available)
% =========================================================================
function appendText(filePath, textToAppend)
fid = fopen(filePath, 'a');
if fid < 0
    warning('switching_a1_vs_mobility_test:appendText', ...
        'Could not append to file: %s', filePath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textToAppend);
end

function stamp = stampNow()
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
