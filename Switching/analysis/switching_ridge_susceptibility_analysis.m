function out = switching_ridge_susceptibility_analysis(cfg)
% switching_ridge_susceptibility_analysis
%
% Extract chi_ridge(T) = max |dS/dI| near I_peak(T) from the switching map
% S(I,T).  Test whether this current-space ridge susceptibility correlates
% with the relaxation observable a1(T) and whether it scales with the
% collective creep coordinate X(T) = I_peak/(width * S_peak).
%
% Analysis steps:
% 1. Load S(I,T) from the effective-observables run.
% 2. Load geometric observables I_peak(T), width(T), S_peak(T), X(T).
% 3. Load relaxation observable a1(T) from the dynamic-shape-mode run.
% 4. For each temperature T:
%    a. Extract S(I) profile.
%    b. Compute dS/dI via numerical gradient.
%    c. chi_ridge_max  = max |dS/dI| within I_peak ± width.
%    d. chi_ridge_mean = mean |dS/dI| within I_peak ± width/2.
% 5. Correlate chi_ridge(T) with a1(T): Pearson and Spearman.
% 6. Peak alignment: T_peak(chi_ridge) vs T_peak(a1).
% 7. Log-log scaling test: chi_ridge(T) ~ X(T)^alpha.
% 8. Diagnostic: compare chi_ridge with dS_peak/dT, dI_peak/dT, dwidth/dT.
%
% Run label: switching_ridge_susceptibility_analysis

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile      = mfilename('fullpath');
analysisDir   = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot      = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg    = applyDefaults(cfg);
source = resolveSourcePaths(repoRoot, cfg);

runCfg          = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset  = sprintf('effObs:%s | a1:%s', ...
    char(source.effObsRunId), char(source.a1RunId));
run    = createSwitchingRunContext(repoRoot, runCfg);
runDir = run.run_dir;

fprintf('Ridge susceptibility analysis run directory:\n%s\n', runDir);
fprintf('Effective-observables source run: %s\n', char(source.effObsRunId));
fprintf('a1 source run:                    %s\n', char(source.a1RunId));

appendText(run.log_path, sprintf('[%s] switching_ridge_susceptibility_analysis started\n', stampNow()));
appendText(run.log_path, sprintf('Effective-observables run: %s\n', char(source.effObsRunId)));
appendText(run.log_path, sprintf('Switching map:             %s\n', source.mapPath));
appendText(run.log_path, sprintf('Observables table:         %s\n', source.obsPath));
appendText(run.log_path, sprintf('a1 run:                    %s\n', char(source.a1RunId)));
appendText(run.log_path, sprintf('a1 file:                   %s\n', source.a1Path));

% -------------------------------------------------------------------------
% Load data
% -------------------------------------------------------------------------
mapTbl = readtable(source.mapPath);
obsTbl = sortrows(readtable(source.obsPath), 'T_K');
a1Tbl  = sortrows(readtable(source.a1Path), 'T_K');

assert(all(ismember({'T_K','current_mA','S_percent'}, mapTbl.Properties.VariableNames)), ...
    'Switching map table must have T_K, current_mA, S_percent columns.');
assert(all(ismember({'T_K','I_peak_mA','width_mA','S_peak','X'}, obsTbl.Properties.VariableNames)), ...
    'Observables table must have T_K, I_peak_mA, width_mA, S_peak, X columns.');
assert(all(ismember({'T_K','a_1'}, a1Tbl.Properties.VariableNames)), ...
    'a1 table must have T_K and a_1 columns.');

% Temperature filter on observables and a1
obsT   = double(obsTbl.T_K(:));
obsKeep = obsT >= cfg.temperatureMinK & obsT <= cfg.temperatureMaxK;
obsTbl  = obsTbl(obsKeep, :);

a1T    = double(a1Tbl.T_K(:));
a1Keep = a1T >= cfg.temperatureMinK & a1T <= cfg.temperatureMaxK;
a1Tbl  = a1Tbl(a1Keep, :);

% Build switching map matrix.
% tempsMap: nT×1 column vector.
% currents: 1×nI row vector.
% Smat:     nT×nI matrix.
[tempsMap, currents, Smat] = buildMapMatrix(mapTbl);

% Filter to temperature range
mapKeep  = tempsMap >= cfg.temperatureMinK & tempsMap <= cfg.temperatureMaxK;
tempsMap = tempsMap(mapKeep);
Smat     = Smat(mapKeep, :);

% -------------------------------------------------------------------------
% For each temperature, compute chi_ridge observables
% -------------------------------------------------------------------------
nT            = numel(tempsMap);
chiRidgeMax   = NaN(nT, 1);
chiRidgeMean  = NaN(nT, 1);
IpeakUsed     = NaN(nT, 1);
widthUsed     = NaN(nT, 1);
SpeakUsed     = NaN(nT, 1);
XUsed         = NaN(nT, 1);
nPointsWindow = zeros(nT, 1);

obsT_filt = double(obsTbl.T_K(:));

for it = 1:nT
    Tc   = tempsMap(it);
    iObs = find(abs(obsT_filt - Tc) < 1e-6, 1, 'first');
    if isempty(iObs)
        continue;
    end

    Ipk  = double(obsTbl.I_peak_mA(iObs));
    wid  = double(obsTbl.width_mA(iObs));
    Spk  = double(obsTbl.S_peak(iObs));
    Xval = double(obsTbl.X(iObs));
    if ~isfinite(Ipk) || ~isfinite(wid) || wid <= 0
        continue;
    end

    IpeakUsed(it) = Ipk;
    widthUsed(it) = wid;
    SpeakUsed(it) = Spk;
    XUsed(it)     = Xval;

    % S(I) profile.  Smat(it,:) is 1×nI and currents is 1×nI, so the
    % logical mask valid is also 1×nI — no dimension mismatch.
    row   = double(Smat(it, :));
    valid = isfinite(row) & isfinite(currents);
    if nnz(valid) < 3
        continue;
    end

    I_v = currents(valid);  % 1×k
    S_v = row(valid);       % 1×k

    [I_v, sortIdx] = sort(I_v);
    S_v = S_v(sortIdx);

    % Numerical derivative dS/dI (central differences)
    dSdI = gradient(S_v, I_v);

    % Ridge window: I_peak ± max(width, minRidgeWindowMA)
    ridgeHalf = max(wid, cfg.minRidgeWindowMA);
    inRidge   = abs(I_v - Ipk) <= ridgeHalf;

    if nnz(inRidge) < 1
        chiRidgeMax(it)   = max(abs(dSdI));
        chiRidgeMean(it)  = mean(abs(dSdI));
        nPointsWindow(it) = numel(dSdI);
    else
        chiRidgeMax(it) = max(abs(dSdI(inRidge)));

        % Narrow window ±width/2 for the mean estimate
        narrowHalf = wid / 2;
        inNarrow   = abs(I_v - Ipk) <= narrowHalf;
        if nnz(inNarrow) >= 1
            chiRidgeMean(it)  = mean(abs(dSdI(inNarrow)));
            nPointsWindow(it) = nnz(inNarrow);
        else
            chiRidgeMean(it)  = mean(abs(dSdI(inRidge)));
            nPointsWindow(it) = nnz(inRidge);
        end
    end
end

chiRidge = chiRidgeMax;  % primary observable

% -------------------------------------------------------------------------
% Align temperatures: chi_ridge ∩ a1
% -------------------------------------------------------------------------
[tempsAligned, iMap, iA1] = intersect(tempsMap, double(a1Tbl.T_K(:)), 'stable');
assert(~isempty(tempsAligned), 'No common temperatures between chi_ridge and a1 series.');

chiAligned     = chiRidge(iMap);
chiMeanAligned = chiRidgeMean(iMap);
a1Aligned      = double(a1Tbl.a_1(iA1));
IpkAligned     = IpeakUsed(iMap);
widAligned     = widthUsed(iMap);
SpkAligned     = SpeakUsed(iMap);
XAligned       = XUsed(iMap);
nWinAligned    = nPointsWindow(iMap);

validMask = isfinite(chiAligned) & isfinite(a1Aligned) & isfinite(XAligned);
T     = tempsAligned(validMask);
chi   = chiAligned(validMask);
chiM  = chiMeanAligned(validMask);
a1    = a1Aligned(validMask);
X     = XAligned(validMask);
Speak = SpkAligned(validMask);
Ipeak = IpkAligned(validMask);
width = widAligned(validMask);
nWin  = nWinAligned(validMask);

assert(numel(T) >= 3, 'Need at least 3 common finite points for analysis.');
fprintf('Common temperatures after alignment: %d\n', numel(T));

% -------------------------------------------------------------------------
% Temperature-space derivatives (optional diagnostic)
% -------------------------------------------------------------------------
[dSpeak_raw, dSpeak_smooth, ~] = computeDerivative(T, Speak, cfg);
[dIpeak_raw, dIpeak_smooth, ~] = computeDerivative(T, Ipeak, cfg);
[dwidth_raw, dwidth_smooth, ~] = computeDerivative(T, width,  cfg);

% -------------------------------------------------------------------------
% Correlation analysis: chi_ridge vs a1
% -------------------------------------------------------------------------
[pearsonR,    nPoints]  = safeCorr(chi,  a1, 'Pearson');
[spearmanRho, ~]        = safeCorr(chi,  a1, 'Spearman');
[pearsonR_m,  ~]        = safeCorr(chiM, a1, 'Pearson');
[spearmanR_m, ~]        = safeCorr(chiM, a1, 'Spearman');

[pearsonDs, spearmanDs] = corrPair(chi, dSpeak_smooth);
[pearsonDi, spearmanDi] = corrPair(chi, abs(dIpeak_smooth));
[pearsonDw, spearmanDw] = corrPair(chi, dwidth_smooth);

% -------------------------------------------------------------------------
% Peak alignment
% -------------------------------------------------------------------------
[chiPeakT, ~] = peakOf(T, chi, true);
[a1PeakT, ~]  = peakOf(T, a1,  true);
deltaPeakT    = chiPeakT - a1PeakT;

% -------------------------------------------------------------------------
% Log-log scaling test: chi_ridge ~ X^alpha
% -------------------------------------------------------------------------
logX      = log(max(X,   eps));
logChi    = log(max(chi, eps));
logLogFit = fitLogLog(logX, logChi);

fprintf('Log-log fit: alpha = %.4f,  R2 = %.4f,  N = %d\n', ...
    logLogFit.alpha, logLogFit.R2, logLogFit.N);

% -------------------------------------------------------------------------
% Save tables
% -------------------------------------------------------------------------
seriesTbl = table( ...
    T(:), chi(:), chiM(:), a1(:), Speak(:), Ipeak(:), width(:), X(:), nWin(:), ...
    dSpeak_raw(:), dIpeak_raw(:), dwidth_raw(:), ...
    dSpeak_smooth(:), dIpeak_smooth(:), dwidth_smooth(:), ...
    'VariableNames', { ...
        'T_K','chi_ridge_max','chi_ridge_mean','a1', ...
        'S_peak','I_peak_mA','width_mA','X','n_window_points', ...
        'dS_peak_dT_raw','dI_peak_dT_raw','dwidth_dT_raw', ...
        'dS_peak_dT_smooth','dI_peak_dT_smooth','dwidth_dT_smooth'});
seriesPath = save_run_table(seriesTbl, 'ridge_susceptibility_vs_temperature.csv', runDir);

corrTbl = table( ...
    nPoints, pearsonR, spearmanRho, pearsonR_m, spearmanR_m, ...
    pearsonDs, spearmanDs, pearsonDi, spearmanDi, pearsonDw, spearmanDw, ...
    'VariableNames', { ...
        'n_points', ...
        'pearson_chi_vs_a1','spearman_chi_vs_a1', ...
        'pearson_chiMean_vs_a1','spearman_chiMean_vs_a1', ...
        'pearson_chi_vs_dSpeak','spearman_chi_vs_dSpeak', ...
        'pearson_chi_vs_absDIpeak','spearman_chi_vs_absDIpeak', ...
        'pearson_chi_vs_dwidth','spearman_chi_vs_dwidth'});
corrPath = save_run_table(corrTbl, 'ridge_susceptibility_correlations.csv', runDir);

peakTbl = table(chiPeakT, a1PeakT, deltaPeakT, ...
    'VariableNames', {'chi_ridge_peak_T_K','a1_peak_T_K','delta_peak_T_K'});
peakPath = save_run_table(peakTbl, 'ridge_susceptibility_peak_alignment.csv', runDir);

logLogTbl = table(logLogFit.alpha, logLogFit.logA, logLogFit.R2, logLogFit.RMSE, logLogFit.N, ...
    'VariableNames', {'alpha','log_prefactor','R2','RMSE','N_points'});
logLogPath = save_run_table(logLogTbl, 'ridge_susceptibility_loglog_fit.csv', runDir);

% -------------------------------------------------------------------------
% Figures
% -------------------------------------------------------------------------
figT      = plotChiVsT(T, chi, chiM, a1, runDir);
figA      = plotChiVsA(chi, a1, pearsonR, spearmanRho, runDir);
figLogLog = plotLogLog(X, chi, logLogFit, runDir);

% -------------------------------------------------------------------------
% Report
% -------------------------------------------------------------------------
reportText = buildReportText(source, cfg, nPoints, pearsonR, spearmanRho, ...
    pearsonR_m, spearmanR_m, chiPeakT, a1PeakT, deltaPeakT, logLogFit, ...
    pearsonDs, spearmanDs, pearsonDi, spearmanDi, pearsonDw, spearmanDw, ...
    seriesPath, corrPath, peakPath, logLogPath, figT, figA, figLogLog);
reportPath = save_run_report(reportText, 'ridge_susceptibility_analysis.md', runDir);

% -------------------------------------------------------------------------
% Review ZIP
% -------------------------------------------------------------------------
zipPath = buildReviewZip(runDir, 'ridge_susceptibility_analysis_bundle.zip');

% -------------------------------------------------------------------------
% Log completion
% -------------------------------------------------------------------------
appendText(run.notes_path, sprintf('n common points = %d\n', nPoints));
appendText(run.notes_path, sprintf('Pearson(chi_ridge, a1) = %.6g\n', pearsonR));
appendText(run.notes_path, sprintf('Spearman(chi_ridge, a1) = %.6g\n', spearmanRho));
appendText(run.notes_path, sprintf('T_peak(chi_ridge) = %.2f K\n', chiPeakT));
appendText(run.notes_path, sprintf('T_peak(a1) = %.2f K\n', a1PeakT));
appendText(run.notes_path, sprintf('Delta peak T = %.2f K\n', deltaPeakT));
appendText(run.notes_path, sprintf('Log-log alpha = %.6g\n', logLogFit.alpha));
appendText(run.notes_path, sprintf('Log-log R2 = %.6g\n', logLogFit.R2));
appendText(run.notes_path, sprintf('Report: %s\n', reportPath));
appendText(run.notes_path, sprintf('ZIP: %s\n', zipPath));

appendText(run.log_path, sprintf('[%s] switching_ridge_susceptibility_analysis complete\n', stampNow()));
appendText(run.log_path, sprintf('Series table: %s\n', seriesPath));
appendText(run.log_path, sprintf('Correlations: %s\n', corrPath));
appendText(run.log_path, sprintf('Peak alignment: %s\n', peakPath));
appendText(run.log_path, sprintf('Log-log fit: %s\n', logLogPath));
appendText(run.log_path, sprintf('chi_ridge vs T: %s\n', figT.png));
appendText(run.log_path, sprintf('chi_ridge vs A: %s\n', figA.png));
appendText(run.log_path, sprintf('chi_ridge vs X loglog: %s\n', figLogLog.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

fprintf('\n=== Switching ridge susceptibility analysis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Pearson(chi_ridge, a1): %.4f\n', pearsonR);
fprintf('Spearman(chi_ridge, a1): %.4f\n', spearmanRho);
fprintf('T_peak(chi_ridge): %.2f K\n', chiPeakT);
fprintf('T_peak(a1): %.2f K\n', a1PeakT);
fprintf('Delta peak T: %.2f K\n', deltaPeakT);
fprintf('Log-log alpha: %.4f,  R2 = %.4f\n', logLogFit.alpha, logLogFit.R2);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);

out = struct();
out.run         = run;
out.runDir      = string(runDir);
out.pearson     = pearsonR;
out.spearman    = spearmanRho;
out.chiPeakT    = chiPeakT;
out.a1PeakT     = a1PeakT;
out.deltaPeakT  = deltaPeakT;
out.logLogAlpha = logLogFit.alpha;
out.logLogR2    = logLogFit.R2;
out.paths = struct( ...
    'series',        string(seriesPath), ...
    'correlations',  string(corrPath), ...
    'peakAlignment', string(peakPath), ...
    'logLogFit',     string(logLogPath), ...
    'chiVsT',        string(figT.png), ...
    'chiVsA',        string(figA.png), ...
    'chiVsX',        string(figLogLog.png), ...
    'report',        string(reportPath), ...
    'zip',           string(zipPath));
end

% =========================================================================
% Local helpers
% =========================================================================

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel',              'switching_ridge_susceptibility_analysis');
cfg = setDefault(cfg, 'effObsRunId',           'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefault(cfg, 'a1RunId',               'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefault(cfg, 'temperatureMinK',       4);
cfg = setDefault(cfg, 'temperatureMaxK',       30);
cfg = setDefault(cfg, 'minRidgeWindowMA',      5);
cfg = setDefault(cfg, 'sgolayPolynomialOrder', 2);
cfg = setDefault(cfg, 'sgolayFrameLength',     5);
cfg = setDefault(cfg, 'movmeanWindow',         3);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.effObsRunId = string(cfg.effObsRunId);
source.a1RunId     = string(cfg.a1RunId);

effObsDir      = fullfile(switchingCanonicalRunRoot(repoRoot), char(source.effObsRunId));
source.mapPath = fullfile(effObsDir, 'tables', 'switching_effective_switching_map.csv');
source.obsPath = fullfile(effObsDir, 'tables', 'switching_effective_observables_table.csv');

a1Dir          = fullfile(switchingCanonicalRunRoot(repoRoot), char(source.a1RunId));
source.a1Path  = fullfile(a1Dir, 'tables', 'switching_dynamic_shape_mode_amplitudes.csv');

required = {source.mapPath, source.obsPath, source.a1Path};
for i = 1:numel(required)
    assert(exist(required{i}, 'file') == 2, 'Required source file missing: %s', required{i});
end
end

function [tempsVec, currVec, Smat] = buildMapMatrix(mapTbl)
% Build a temperatures×currents matrix from a long-format switching map.
% Returns tempsVec as nT×1 column vector, currVec as 1×nI row vector,
% and Smat as nT×nI matrix.
T_all = double(mapTbl.T_K(:));
I_all = double(mapTbl.current_mA(:));
S_all = double(mapTbl.S_percent(:));

tempsVec = unique(T_all, 'sorted');   % nT×1
currVec  = unique(I_all, 'sorted')';  % 1×nI  (transpose to enforce row)
nT = numel(tempsVec);
nI = numel(currVec);

Smat = NaN(nT, nI);
for k = 1:numel(T_all)
    iT = find(tempsVec == T_all(k), 1, 'first');
    iI = find(currVec  == I_all(k), 1, 'first');
    if ~isempty(iT) && ~isempty(iI)
        Smat(iT, iI) = S_all(k);
    end
end
end

function [dRaw, dSmooth, methodText] = computeDerivative(x, y, cfg)
x = x(:); y = y(:);
dRaw = gradient(y, x);
n    = numel(y);
frame = min(max(3, round(cfg.sgolayFrameLength)), n);
if mod(frame, 2) == 0; frame = frame - 1; end
poly = min(max(1, round(cfg.sgolayPolynomialOrder)), frame - 1);

ySmooth = y; methodText = "none";
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
    if mod(w, 2) == 0 && w > 1; w = w - 1; end
    if w > 1
        ySmooth    = smoothdata(y, 'movmean', w, 'omitnan');
        methodText = sprintf('movmean(window=%d)', w);
    end
end
dSmooth = gradient(ySmooth, x);
end

function fit = fitLogLog(logX, logY)
fit = struct('alpha', NaN, 'logA', NaN, 'A', NaN, 'R2', NaN, 'RMSE', NaN, 'N', 0);
valid = isfinite(logX(:)) & isfinite(logY(:));
N = nnz(valid);
if N < 2; return; end
lx = logX(valid); ly = logY(valid);
p    = polyfit(lx, ly, 1);
yhat = polyval(p, lx);
res  = ly - yhat;
sst  = sum((ly - mean(ly)).^2);
sse  = sum(res.^2);
fit.alpha = p(1);
fit.logA  = p(2);
fit.A     = exp(p(2));
fit.RMSE  = sqrt(sse / N);
if sst > 0; fit.R2 = 1 - sse/sst; end
fit.N = N;
end

function [r, n] = safeCorr(x, y, corrType)
x = x(:); y = y(:);
mask = isfinite(x) & isfinite(y); n = nnz(mask);
if n < 3; r = NaN; return; end
try
    r = corr(x(mask), y(mask), 'Type', corrType, 'Rows', 'complete');
catch
    if strcmpi(corrType, 'Pearson')
        r = corr(x(mask), y(mask));
    else
        [~, rx] = sort(x(mask)); rv = zeros(n,1); rv(rx) = 1:n;
        [~, ry] = sort(y(mask)); sv = zeros(n,1); sv(ry) = 1:n;
        r = corr(double(rv), double(sv));
    end
end
end

function [p, s] = corrPair(x, y)
[p, ~] = safeCorr(x, y, 'Pearson');
[s, ~] = safeCorr(x, y, 'Spearman');
end

function [peakT, peakVal] = peakOf(T, y, useAbs)
peakT = NaN; peakVal = NaN;
if isempty(T) || isempty(y); return; end
if useAbs; [~, idx] = max(abs(y)); peakVal = y(idx);
else;      [peakVal, idx] = max(y); end
if ~isempty(idx); peakT = T(idx); end
end

% -------------------------------------------------------------------------
% Figure helpers
% -------------------------------------------------------------------------
function figPaths = plotChiVsT(T, chi, chiM, a1, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 14 11]);
tl  = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
yyaxis(ax1, 'left');
plot(ax1, T, chi, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', '\chi_{ridge,max}(T)');
plot(ax1, T, chiM, '--s', 'LineWidth', 1.8, ...
    'Color', [0.30 0.75 0.93], 'MarkerFaceColor', [0.30 0.75 0.93], ...
    'MarkerSize', 5, 'DisplayName', '\chi_{ridge,mean}(T)');
ylabel(ax1, '|\partial S/\partial I| (% mA^{-1})');
yyaxis(ax1, 'right');
plot(ax1, T, a1, '-d', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, 'DisplayName', 'a_1(T)');
ylabel(ax1, 'a_1(T) (a.u.)');
xlabel(ax1, 'Temperature (K)');
title(ax1, '\chi_{ridge}(T) and a_1(T) vs temperature');
legend(ax1, 'Location', 'best');
styleAxes(ax1); hold(ax1, 'off');

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, T, normalize01(chi), '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', '\chi_{ridge}(T) norm');
plot(ax2, T, normalize01(a1), '-d', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, 'DisplayName', 'a_1(T) norm');
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, 'Normalized [0, 1]');
title(ax2, 'Normalized comparison: \chi_{ridge}(T) vs a_1(T)');
legend(ax2, 'Location', 'best');
styleAxes(ax2); hold(ax2, 'off');

figPaths = save_run_figure(fig, 'chi_ridge_vs_T', runDir);
close(fig);
end

function figPaths = plotChiVsA(chi, a1, pearsonR, spearmanRho, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 12 10]);
ax  = axes(fig);
hold(ax, 'on');
scatter(ax, a1, chi, 70, 'filled', ...
    'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerEdgeColor', 'none', ...
    'DisplayName', 'data');
validM = isfinite(a1) & isfinite(chi);
if nnz(validM) >= 2
    p   = polyfit(a1(validM), chi(validM), 1);
    xLn = linspace(min(a1(validM)), max(a1(validM)), 50);
    plot(ax, xLn, polyval(p, xLn), '-', 'LineWidth', 2.0, ...
        'Color', [0.85 0.33 0.10], 'DisplayName', 'linear fit');
end
xlabel(ax, 'a_1(T) (a.u.)');
ylabel(ax, '\chi_{ridge}(T) (% mA^{-1})');
title(ax, '\chi_{ridge}(T) vs relaxation observable a_1(T)');
styleAxes(ax); legend(ax, 'Location', 'best');
xL = xlim(ax); yL = ylim(ax);
text(ax, xL(1)+0.04*(xL(2)-xL(1)), yL(2)-0.04*(yL(2)-yL(1)), ...
    sprintf('Pearson r = %.4f\nSpearman \\rho = %.4f', pearsonR, spearmanRho), ...
    'VerticalAlignment', 'top', 'FontSize', 11, ...
    'BackgroundColor', 'w', 'EdgeColor', [0.8 0.8 0.8], 'Margin', 5);
hold(ax, 'off');
figPaths = save_run_figure(fig, 'chi_ridge_vs_A', runDir);
close(fig);
end

function figPaths = plotLogLog(X, chi, fitResult, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 12 10]);
ax  = axes(fig);
hold(ax, 'on');
validM = isfinite(X) & isfinite(chi) & chi > 0 & X > 0;
scatter(ax, log(X(validM)), log(chi(validM)), 70, 'filled', ...
    'MarkerFaceColor', [0.49 0.18 0.56], 'MarkerEdgeColor', 'none', ...
    'DisplayName', 'data: (log X, log \chi_{ridge})');
if isfinite(fitResult.alpha) && nnz(validM) >= 2
    lxFit = linspace(min(log(X(validM))), max(log(X(validM))), 60);
    lyFit = fitResult.alpha .* lxFit + fitResult.logA;
    plot(ax, lxFit, lyFit, '-', 'LineWidth', 2.2, 'Color', [0.85 0.33 0.10], ...
        'DisplayName', sprintf('\\alpha = %.3f', fitResult.alpha));
end
xlabel(ax, 'log X(T)');
ylabel(ax, 'log \chi_{ridge}(T)');
title(ax, 'Log-log scaling: \chi_{ridge}(T) vs X(T)');
styleAxes(ax); legend(ax, 'Location', 'best');
xL = xlim(ax); yL = ylim(ax);
text(ax, xL(1)+0.04*(xL(2)-xL(1)), yL(2)-0.04*(yL(2)-yL(1)), ...
    sprintf('\\alpha = %.4f\nR^2 = %.4f\nN = %d', ...
        fitResult.alpha, fitResult.R2, fitResult.N), ...
    'VerticalAlignment', 'top', 'FontSize', 11, ...
    'BackgroundColor', 'w', 'EdgeColor', [0.8 0.8 0.8], 'Margin', 5);
hold(ax, 'off');
figPaths = save_run_figure(fig, 'chi_ridge_vs_X_loglog', runDir);
close(fig);
end

% -------------------------------------------------------------------------
% Report builder
% -------------------------------------------------------------------------
function reportText = buildReportText(source, cfg, nPoints, pearsonR, spearmanRho, ...
        pearsonR_m, spearmanR_m, chiPeakT, a1PeakT, deltaPeakT, logLogFit, ...
        pearsonDs, spearmanDs, pearsonDi, spearmanDi, pearsonDw, spearmanDw, ...
        seriesPath, corrPath, peakPath, logLogPath, figT, figA, figLogLog)

corrStrength = 'weak or moderate';
if isfinite(pearsonR) && abs(pearsonR) > 0.7 && isfinite(spearmanRho) && abs(spearmanRho) > 0.7
    corrStrength = 'strong';
end

lines = strings(0, 1);
lines(end+1) = "# Ridge susceptibility analysis";
lines(end+1) = "";
lines(end+1) = "## Definition";
lines(end+1) = "";
lines(end+1) = "```";
lines(end+1) = "chi_ridge(T) = max |dS/dI|  within  I_peak(T) +/- width(T)";
lines(end+1) = "```";
lines(end+1) = "";
lines(end+1) = "This measures the maximum steepness of the switching transition in";
lines(end+1) = "current-space near the ridge, i.e. how sharply the switching fraction";
lines(end+1) = "changes with applied current around the depinning threshold.";
lines(end+1) = "";
lines(end+1) = "## Data sources";
lines(end+1) = "- Effective-observables run: `" + source.effObsRunId + "`.";
lines(end+1) = "- Switching map: `" + string(source.mapPath) + "`.";
lines(end+1) = "- Observables table: `" + string(source.obsPath) + "`.";
lines(end+1) = "- Dynamic shape-mode run (a1): `" + source.a1RunId + "`.";
lines(end+1) = "- a1 file: `" + string(source.a1Path) + "`.";
lines(end+1) = sprintf('- Temperature range: %.1f to %.1f K.', ...
    cfg.temperatureMinK, cfg.temperatureMaxK);
lines(end+1) = "";
lines(end+1) = "## Correlation with relaxation activity";
lines(end+1) = "";
lines(end+1) = sprintf('- Matched points: **%d**.', nPoints);
lines(end+1) = sprintf('- Pearson( chi_ridge_max, a1 ) = **%.4f**.', pearsonR);
lines(end+1) = sprintf('- Spearman( chi_ridge_max, a1 ) = **%.4f**.', spearmanRho);
lines(end+1) = sprintf('- Pearson( chi_ridge_mean, a1 ) = **%.4f**.', pearsonR_m);
lines(end+1) = sprintf('- Spearman( chi_ridge_mean, a1 ) = **%.4f**.', spearmanR_m);
lines(end+1) = "- Correlation strength (|r| > 0.7 criterion): **" + corrStrength + "**.";
lines(end+1) = "";
lines(end+1) = "## Peak alignment";
lines(end+1) = "";
lines(end+1) = sprintf('- T_peak( |chi_ridge| ) = **%.2f K**.', chiPeakT);
lines(end+1) = sprintf('- T_peak( |a1| )        = **%.2f K**.', a1PeakT);
lines(end+1) = sprintf('- Delta T_peak          = **%.2f K** (chi minus a1).', deltaPeakT);
lines(end+1) = "";
lines(end+1) = "## Scaling test: chi_ridge ~ X(T)^alpha";
lines(end+1) = "";
lines(end+1) = "X(T) = I_peak / ( width * S_peak )  (collective creep coordinate).";
lines(end+1) = "";
lines(end+1) = sprintf('- Fit: log chi_ridge = %.4f * log X + %.4f.', ...
    logLogFit.alpha, logLogFit.logA);
lines(end+1) = sprintf('- Scaling exponent alpha = **%.4f**.', logLogFit.alpha);
lines(end+1) = sprintf('- R2 = %.4f,  RMSE = %.4f,  N = %d.', ...
    logLogFit.R2, logLogFit.RMSE, logLogFit.N);
lines(end+1) = "";

if isfinite(logLogFit.alpha)
    if logLogFit.alpha > 0
        alphaNote = "Positive exponent: chi_ridge increases with X, consistent with " + ...
            "divergence of current-space sensitivity near a collective threshold.";
    else
        alphaNote = "Negative exponent: chi_ridge decreases as X increases.  " + ...
            "The current-space sharpness and creep coordinate vary in opposite senses.";
    end
    if isfinite(logLogFit.R2) && logLogFit.R2 > 0.8
        alphaNote = alphaNote + "  High R2 supports a power-law relationship.";
    end
    lines(end+1) = alphaNote;
    lines(end+1) = "";
end

lines(end+1) = "## Diagnostic: chi_ridge vs temperature-derivative observables";
lines(end+1) = "";
lines(end+1) = sprintf('- Pearson( chi_ridge, dS_peak/dT )   = %.4f,  Spearman = %.4f.', ...
    pearsonDs, spearmanDs);
lines(end+1) = sprintf('- Pearson( chi_ridge, |dI_peak/dT| ) = %.4f,  Spearman = %.4f.', ...
    pearsonDi, spearmanDi);
lines(end+1) = sprintf('- Pearson( chi_ridge, dwidth/dT )    = %.4f,  Spearman = %.4f.', ...
    pearsonDw, spearmanDw);
lines(end+1) = "";
lines(end+1) = "## Interpretation notes";
lines(end+1) = "";
lines(end+1) = "chi_ridge(T) = max |dS/dI| measures how steeply the switching probability";
lines(end+1) = "changes with current near the depinning ridge.  A larger chi_ridge implies";
lines(end+1) = "a more abrupt transition, analogous to a sharper domain-wall depinning";
lines(end+1) = "threshold.";
lines(end+1) = "";
lines(end+1) = "If chi_ridge(T) correlates strongly with a1(T) or X(T), this supports";
lines(end+1) = "a picture in which the switching map geometry encodes collective dynamics";
lines(end+1) = "rather than single-barrier activation.  Independent or anticorrelated";
lines(end+1) = "chi_ridge and a1 would suggest they are governed by different microscopic";
lines(end+1) = "processes.";
lines(end+1) = "";
lines(end+1) = "## Outputs";
lines(end+1) = "- Series table:       `" + string(seriesPath) + "`.";
lines(end+1) = "- Correlations table: `" + string(corrPath) + "`.";
lines(end+1) = "- Peak alignment:     `" + string(peakPath) + "`.";
lines(end+1) = "- Log-log fit:        `" + string(logLogPath) + "`.";
lines(end+1) = "- Figure (chi vs T):  `" + string(figT.png) + "`.";
lines(end+1) = "- Figure (chi vs A):  `" + string(figA.png) + "`.";
lines(end+1) = "- Figure (loglog):    `" + string(figLogLog.png) + "`.";
lines(end+1) = "";
lines(end+1) = "![chi_ridge_vs_T](../figures/chi_ridge_vs_T.png)";
lines(end+1) = "";
lines(end+1) = "![chi_ridge_vs_A](../figures/chi_ridge_vs_A.png)";
lines(end+1) = "";
lines(end+1) = "![chi_ridge_vs_X_loglog](../figures/chi_ridge_vs_X_loglog.png)";
lines(end+1) = "";
lines(end+1) = "---";
lines(end+1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

% -------------------------------------------------------------------------
% Review ZIP
% -------------------------------------------------------------------------
function zipPath = buildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7; mkdir(reviewDir); end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2; delete(zipPath); end
zip(zipPath, {'figures','tables','reports', ...
    'run_manifest.json','config_snapshot.m','log.txt','run_notes.txt'}, runDir);
end

% -------------------------------------------------------------------------
% Micro-utilities
% -------------------------------------------------------------------------
function y = normalize01(x)
x  = x(:); mn = min(x,[],'omitnan'); mx = max(x,[],'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn
    y = zeros(size(x));
else
    y = (x - mn) ./ (mx - mn);
end
end

function styleAxes(ax)
set(ax, 'FontSize', 13, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
end

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1; warning('Unable to append to %s.', filePath); return; end
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
