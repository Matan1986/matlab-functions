function out = switching_ridge_curvature_analysis(cfg)
% switching_ridge_curvature_analysis
%
% Analyze switching ridge curvature as a dynamical observable:
%   1) Load switching map S(I,T)
%   2) For each T, locate I_peak(T) and compute d2S/dI2 at I_peak
%   3) Define kappa(T) = -d2S/dI2 |_(I_peak)
%   4) Compare kappa(T) with A(T) and X(T)
%
% Requested outputs:
%   tables/ridge_curvature_vs_T.csv
%   plots/kappa_vs_T.png
%   plots/kappa_vs_A.png
%   plots/kappa_vs_X.png
%   report/ridge_curvature_analysis.md
%   review/ridge_curvature_analysis_bundle.zip

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourcePaths(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('map:%s | X:%s | A:%s', ...
    char(source.switchMapRunId), char(source.switchXRunId), char(source.relaxRunId));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching ridge-curvature analysis run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] switching ridge-curvature analysis started\n', stampNow()));
appendText(run.log_path, sprintf('map source run: %s\n', char(source.switchMapRunId)));
appendText(run.log_path, sprintf('X source run: %s\n', char(source.switchXRunId)));
appendText(run.log_path, sprintf('A source run: %s\n', char(source.relaxRunId)));

mapData = loadSwitchingMap(source.mapPath);
xData = loadXData(source.xPath);
aData = loadAData(source.aPath);

[ridgeTbl, diagnosticsTbl] = buildRidgeCurvatureTable(mapData, cfg);

[alignedTbl, corrSummary, peakSummary] = compareWithAX(ridgeTbl, aData, xData);

tablePath = save_run_table(alignedTbl, 'ridge_curvature_vs_T.csv', runDir);
diagPath = save_run_table(diagnosticsTbl, 'ridge_curvature_diagnostics.csv', runDir);
corrPath = save_run_table(corrSummary, 'ridge_curvature_correlations.csv', runDir);
peakPath = save_run_table(peakSummary, 'ridge_curvature_peaks.csv', runDir);

figT = plotKappaVsT(alignedTbl, runDir);
figA = plotKappaVsObservable(alignedTbl.A_T, alignedTbl.kappa, alignedTbl.T_K, ...
    'A(T)', 'kappa_vs_A', runDir, corrSummary.pearson_kappa_vs_A(1), corrSummary.spearman_kappa_vs_A(1));
figX = plotKappaVsObservable(alignedTbl.X_T, alignedTbl.kappa, alignedTbl.T_K, ...
    'X(T)', 'kappa_vs_X', runDir, corrSummary.pearson_kappa_vs_X(1), corrSummary.spearman_kappa_vs_X(1));

reportText = buildReportText(source, alignedTbl, corrSummary, peakSummary, ...
    tablePath, figT, figA, figX);
reportPath = save_run_report(reportText, 'ridge_curvature_analysis.md', runDir);

[plotsDir, reportDir] = ensureRequestedDirs(runDir);
plotTPath = fullfile(plotsDir, 'kappa_vs_T.png');
plotAPath = fullfile(plotsDir, 'kappa_vs_A.png');
plotXPath = fullfile(plotsDir, 'kappa_vs_X.png');
copyfile(figT.png, plotTPath, 'f');
copyfile(figA.png, plotAPath, 'f');
copyfile(figX.png, plotXPath, 'f');

reportRequestedPath = fullfile(reportDir, 'ridge_curvature_analysis.md');
copyfile(reportPath, reportRequestedPath, 'f');

zipPath = buildRequestedBundle(runDir, 'ridge_curvature_analysis_bundle.zip');

appendText(run.notes_path, sprintf('map source file = %s\n', source.mapPath));
appendText(run.notes_path, sprintf('x source file = %s\n', source.xPath));
appendText(run.notes_path, sprintf('a source file = %s\n', source.aPath));
appendText(run.notes_path, sprintf('n points = %d\n', height(alignedTbl)));
appendText(run.notes_path, sprintf('Pearson(kappa,A) = %.6f\n', corrSummary.pearson_kappa_vs_A(1)));
appendText(run.notes_path, sprintf('Spearman(kappa,A) = %.6f\n', corrSummary.spearman_kappa_vs_A(1)));
appendText(run.notes_path, sprintf('Pearson(kappa,X) = %.6f\n', corrSummary.pearson_kappa_vs_X(1)));
appendText(run.notes_path, sprintf('Spearman(kappa,X) = %.6f\n', corrSummary.spearman_kappa_vs_X(1)));
appendText(run.notes_path, sprintf('requested table = %s\n', tablePath));
appendText(run.notes_path, sprintf('requested plot T = %s\n', plotTPath));
appendText(run.notes_path, sprintf('requested plot A = %s\n', plotAPath));
appendText(run.notes_path, sprintf('requested plot X = %s\n', plotXPath));
appendText(run.notes_path, sprintf('requested report = %s\n', reportRequestedPath));
appendText(run.notes_path, sprintf('bundle = %s\n', zipPath));

appendText(run.log_path, sprintf('[%s] switching ridge-curvature analysis complete\n', stampNow()));
appendText(run.log_path, sprintf('Table: %s\n', tablePath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('Bundle: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.metrics = struct( ...
    'pearson_kappa_vs_A', corrSummary.pearson_kappa_vs_A(1), ...
    'spearman_kappa_vs_A', corrSummary.spearman_kappa_vs_A(1), ...
    'pearson_kappa_vs_X', corrSummary.pearson_kappa_vs_X(1), ...
    'spearman_kappa_vs_X', corrSummary.spearman_kappa_vs_X(1), ...
    'kappa_peak_T_K', peakSummary.kappa_peak_T_K(1), ...
    'A_peak_T_K', peakSummary.A_peak_T_K(1), ...
    'X_peak_T_K', peakSummary.X_peak_T_K(1));
out.paths = struct( ...
    'table', string(tablePath), ...
    'plotT', string(plotTPath), ...
    'plotA', string(plotAPath), ...
    'plotX', string(plotXPath), ...
    'report', string(reportRequestedPath), ...
    'zip', string(zipPath));

fprintf('\n=== Switching ridge-curvature analysis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('corr(kappa, A): Pearson %.4f, Spearman %.4f\n', ...
    corrSummary.pearson_kappa_vs_A(1), corrSummary.spearman_kappa_vs_A(1));
fprintf('corr(kappa, X): Pearson %.4f, Spearman %.4f\n', ...
    corrSummary.pearson_kappa_vs_X(1), corrSummary.spearman_kappa_vs_X(1));
fprintf('Bundle: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_ridge_curvature_analysis');
cfg = setDefault(cfg, 'switchMapRunId', 'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefault(cfg, 'switchXRunId', 'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefault(cfg, 'relaxRunId', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefault(cfg, 'temperatureMinK', 4);
cfg = setDefault(cfg, 'temperatureMaxK', 30);
cfg = setDefault(cfg, 'peakUseAbs', false);
cfg = setDefault(cfg, 'minFinitePointsPerT', 5);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.switchMapRunId = string(cfg.switchMapRunId);
source.switchXRunId = string(cfg.switchXRunId);
source.relaxRunId = string(cfg.relaxRunId);

mapRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchMapRunId));
xRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchXRunId));
relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunId));

source.mapPath = fullfile(mapRunDir, 'tables', 'switching_effective_switching_map.csv');
source.xPath = fullfile(xRunDir, 'tables', 'switching_effective_coordinate_x.csv');
source.aPath = fullfile(relaxRunDir, 'tables', 'temperature_observables.csv');

assert(exist(source.mapPath, 'file') == 2, 'Missing map source file: %s', source.mapPath);
assert(exist(source.xPath, 'file') == 2, 'Missing X source file: %s', source.xPath);
assert(exist(source.aPath, 'file') == 2, 'Missing A source file: %s', source.aPath);
end

function data = loadSwitchingMap(filePath)
tbl = readtable(filePath);
required = {'T_K', 'current_mA', 'S_percent'};
for i = 1:numel(required)
    assert(ismember(required{i}, tbl.Properties.VariableNames), ...
        'Map table missing required column %s: %s', required{i}, filePath);
end

data = struct();
data.T_K = double(tbl.T_K(:));
data.current_mA = double(tbl.current_mA(:));
data.S_percent = double(tbl.S_percent(:));
end

function data = loadXData(filePath)
tbl = readtable(filePath);
assert(ismember('T_K', tbl.Properties.VariableNames), 'X table missing T_K: %s', filePath);
assert(ismember('X', tbl.Properties.VariableNames), 'X table missing X: %s', filePath);
tbl = sortrows(tbl, 'T_K');

data = struct();
data.T_K = double(tbl.T_K(:));
data.X = double(tbl.X(:));
end

function data = loadAData(filePath)
tbl = readtable(filePath);
assert(ismember('T', tbl.Properties.VariableNames) || ismember('T_K', tbl.Properties.VariableNames), ...
    'A table missing temperature column: %s', filePath);
if ismember('T', tbl.Properties.VariableNames)
    T = double(tbl.T(:));
else
    T = double(tbl.T_K(:));
end

if ismember('A_T', tbl.Properties.VariableNames)
    A = double(tbl.A_T(:));
elseif ismember('A', tbl.Properties.VariableNames)
    A = double(tbl.A(:));
else
    error('A table missing A_T/A column: %s', filePath);
end

[T, idx] = sort(T, 'ascend');
A = A(idx);

data = struct();
data.T_K = T(:);
data.A_T = A(:);
end

function [ridgeTbl, diagTbl] = buildRidgeCurvatureTable(mapData, cfg)
temps = unique(mapData.T_K(:));
temps = temps(isfinite(temps));
temps = sort(temps, 'ascend');
temps = temps(temps >= cfg.temperatureMinK & temps <= cfg.temperatureMaxK);

nT = numel(temps);
Ipeak = NaN(nT, 1);
Speak = NaN(nT, 1);
d2AtPeak = NaN(nT, 1);
kappa = NaN(nT, 1);
nPoints = NaN(nT, 1);
usedIndex = NaN(nT, 1);

for i = 1:nT
    t = temps(i);
    rows = mapData.T_K == t;
    I = mapData.current_mA(rows);
    S = mapData.S_percent(rows);

    [Iu, ia] = unique(I, 'stable');
    Su = S(ia);
    [Iu, order] = sort(Iu, 'ascend');
    Su = Su(order);

    m = isfinite(Iu) & isfinite(Su);
    Iu = Iu(m);
    Su = Su(m);

    nPoints(i) = numel(Iu);
    if numel(Iu) < cfg.minFinitePointsPerT
        continue;
    end

    [sPeakVal, idxPeak] = max(Su);
    Ipeak(i) = Iu(idxPeak);
    Speak(i) = sPeakVal;
    usedIndex(i) = idxPeak;

    d1 = gradient(Su, Iu);
    d2 = gradient(d1, Iu);

    d2AtPeak(i) = d2(idxPeak);
    kappa(i) = -d2AtPeak(i);
end

ridgeTbl = table(temps, Ipeak, Speak, d2AtPeak, kappa, nPoints, usedIndex, ...
    'VariableNames', {'T_K', 'I_peak_mA', 'S_peak', 'd2S_dI2_at_Ipeak', ...
    'kappa', 'n_points_in_I_grid', 'peak_index_in_sorted_grid'});

diagTbl = ridgeTbl;
diagTbl.kappa_norm = normalize01(kappa);
diagTbl.kappa_signed_norm = normalizeSigned(kappa);
end

function [alignedTbl, corrTbl, peakTbl] = compareWithAX(ridgeTbl, aData, xData)
T = double(ridgeTbl.T_K(:));
kappa = double(ridgeTbl.kappa(:));
Ipeak = double(ridgeTbl.I_peak_mA(:));
Speak = double(ridgeTbl.S_peak(:));

Ta = double(aData.T_K(:));
Aa = double(aData.A_T(:));
Tx = double(xData.T_K(:));
Xx = double(xData.X(:));

if nnz(isfinite(Ta) & isfinite(Aa)) < 2
    error('A(T) source does not have enough finite points for interpolation.');
end
if nnz(isfinite(Tx) & isfinite(Xx)) < 2
    error('X(T) source does not have enough finite points for interpolation.');
end

A = interp1(Ta, Aa, T, 'linear', NaN);
X = interp1(Tx, Xx, T, 'linear', NaN);

valid = isfinite(T) & isfinite(kappa) & isfinite(A) & isfinite(X) & isfinite(Ipeak) & isfinite(Speak);
T = T(valid);
kappa = kappa(valid);
A = A(valid);
X = X(valid);
Ipeak = Ipeak(valid);
Speak = Speak(valid);

if numel(T) < 3
    error('Need at least 3 finite matched points for correlations.');
end

alignedTbl = table(T, Ipeak, Speak, kappa, A, X, ...
    normalizeSigned(kappa), normalizeSigned(A), normalizeSigned(X), ...
    normalize01(kappa), normalize01(A), normalize01(X), ...
    'VariableNames', {'T_K', 'I_peak_mA', 'S_peak', 'kappa', 'A_T', 'X_T', ...
    'kappa_signed_norm', 'A_signed_norm', 'X_signed_norm', ...
    'kappa_norm01', 'A_norm01', 'X_norm01'});

pearA = safeCorr(kappa, A, 'Pearson');
spearA = safeCorr(kappa, A, 'Spearman');
pearX = safeCorr(kappa, X, 'Pearson');
spearX = safeCorr(kappa, X, 'Spearman');

[kPeakT, kPeakV] = peakOf(T, kappa, false);
[aPeakT, aPeakV] = peakOf(T, A, false);
[xPeakT, xPeakV] = peakOf(T, X, false);

corrTbl = table(numel(T), pearA, spearA, pearX, spearX, ...
    'VariableNames', {'n_points', 'pearson_kappa_vs_A', 'spearman_kappa_vs_A', ...
    'pearson_kappa_vs_X', 'spearman_kappa_vs_X'});

peakTbl = table(kPeakT, aPeakT, xPeakT, ...
    aPeakT - kPeakT, xPeakT - kPeakT, ...
    kPeakV, aPeakV, xPeakV, ...
    'VariableNames', {'kappa_peak_T_K', 'A_peak_T_K', 'X_peak_T_K', ...
    'delta_A_minus_kappa_peak_K', 'delta_X_minus_kappa_peak_K', ...
    'kappa_peak_value', 'A_peak_value', 'X_peak_value'});
end

function figOut = plotKappaVsT(tbl, runDir)
fig = create_figure('Visible', 'off', 'Position', [2 2 14 10]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, tbl.T_K, tbl.kappa, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', '\kappa(T)');
xlabel(ax, 'Temperature (K)');
ylabel(ax, '\kappa(T) = -d^2S/dI^2|_{I_{peak}}');
title(ax, 'Ridge curvature vs temperature');
styleAxes(ax);
legend(ax, 'Location', 'best');
hold(ax, 'off');

figOut = robustSaveFigure(fig, 'kappa_vs_T', runDir);
close(fig);
end

function figOut = plotKappaVsObservable(x, kappa, T, xLabel, figName, runDir, pearsonR, spearmanR)
fig = create_figure('Visible', 'off', 'Position', [2 2 12 10]);
ax = axes(fig);
hold(ax, 'on');

m = isfinite(x) & isfinite(kappa) & isfinite(T);
scatter(ax, x(m), kappa(m), 64, T(m), 'filled', 'MarkerEdgeColor', 'none');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';

if nnz(m) >= 2
    p = polyfit(x(m), kappa(m), 1);
    xg = linspace(min(x(m)), max(x(m)), 200);
    yg = polyval(p, xg);
    plot(ax, xg, yg, '-', 'LineWidth', 2.1, 'Color', [0.85 0.33 0.10]);
end

xlabel(ax, xLabel);
ylabel(ax, '\kappa(T)');
title(ax, sprintf('\kappa(T) vs %s', xLabel));
styleAxes(ax);

xL = xlim(ax);
yL = ylim(ax);
textX = xL(1) + 0.03 * (xL(2) - xL(1));
textY = yL(2) - 0.06 * (yL(2) - yL(1));
text(ax, textX, textY, sprintf('Pearson r = %.4f\nSpearman rho = %.4f', pearsonR, spearmanR), ...
    'VerticalAlignment', 'top', 'FontSize', 11, ...
    'BackgroundColor', [1 1 1], 'EdgeColor', [0.8 0.8 0.8], 'Margin', 6);

hold(ax, 'off');
figOut = robustSaveFigure(fig, figName, runDir);
close(fig);
end

function figOut = robustSaveFigure(fig, baseName, runDir)
try
    figOut = save_run_figure(fig, baseName, runDir);
catch ME
    warning('switching_ridge_curvature_analysis:saveFigureFallback', ...
        'save_run_figure failed (%s); using fallback export.', ME.message);
    figuresDir = fullfile(runDir, 'figures');
    if exist(figuresDir, 'dir') ~= 7
        mkdir(figuresDir);
    end
    figOut = struct();
    figOut.png = fullfile(figuresDir, [baseName '.png']);
    figOut.fig = fullfile(figuresDir, [baseName '.fig']);
    figOut.pdf = fullfile(figuresDir, [baseName '.pdf']);

    pngSaved = false;
    try
        exportgraphics(fig, figOut.png, 'Resolution', 300);
        pngSaved = true;
    catch
        % Continue to alternate PNG exporters.
    end
    if ~pngSaved
        try
            print(fig, figOut.png, '-dpng', '-r200');
            pngSaved = true;
        catch
            % Continue to alternate PNG exporters.
        end
    end
    if ~pngSaved
        try
            saveas(fig, figOut.png);
            pngSaved = true;
        catch
            % Last-resort failure leaves warning only.
            warning('switching_ridge_curvature_analysis:pngExportFailed', ...
                'Failed to export PNG for figure %s.', baseName);
        end
    end

    try
        savefig(fig, figOut.fig);
    catch
        % Optional in fallback path.
    end

    try
        exportgraphics(fig, figOut.pdf, 'ContentType', 'vector');
    catch
        % Optional in fallback path.
    end
end
end

function textOut = buildReportText(source, alignedTbl, corrTbl, peakTbl, tablePath, figT, figA, figX)
lines = strings(0,1);
lines(end+1) = '# Switching Ridge Curvature Analysis';
lines(end+1) = '';
lines(end+1) = '## Definition';
lines(end+1) = '- Ridge curvature observable: `kappa(T) = -d^2S/dI^2` evaluated at `I_peak(T)`.';
lines(end+1) = '- `I_peak(T)` is taken from the maximum of `S(I,T)` for each temperature slice.';
lines(end+1) = '';
lines(end+1) = '## Sources';
lines(end+1) = '- Switching map run: `' + source.switchMapRunId + '`.';
lines(end+1) = '- X(T) run: `' + source.switchXRunId + '`.';
lines(end+1) = '- A(T) run: `' + source.relaxRunId + '`.';
lines(end+1) = '- Map file: `' + string(source.mapPath) + '`.';
lines(end+1) = '- X file: `' + string(source.xPath) + '`.';
lines(end+1) = '- A file: `' + string(source.aPath) + '`.';
lines(end+1) = '';
lines(end+1) = '## Correlations';
lines(end+1) = sprintf('- corr(kappa, A): Pearson = `%.6f`, Spearman = `%.6f`.', ...
    corrTbl.pearson_kappa_vs_A(1), corrTbl.spearman_kappa_vs_A(1));
lines(end+1) = sprintf('- corr(kappa, X): Pearson = `%.6f`, Spearman = `%.6f`.', ...
    corrTbl.pearson_kappa_vs_X(1), corrTbl.spearman_kappa_vs_X(1));
lines(end+1) = '';
lines(end+1) = '## Peak Positions';
lines(end+1) = sprintf('- T_peak(kappa) = `%.2f K`.', peakTbl.kappa_peak_T_K(1));
lines(end+1) = sprintf('- T_peak(A) = `%.2f K`; delta(A-kappa) = `%+.2f K`.', ...
    peakTbl.A_peak_T_K(1), peakTbl.delta_A_minus_kappa_peak_K(1));
lines(end+1) = sprintf('- T_peak(X) = `%.2f K`; delta(X-kappa) = `%+.2f K`.', ...
    peakTbl.X_peak_T_K(1), peakTbl.delta_X_minus_kappa_peak_K(1));
lines(end+1) = '';
lines(end+1) = '## Outputs';
lines(end+1) = '- Table: `' + string(tablePath) + '`.';
lines(end+1) = '- Figure: `' + string(figT.png) + '`.';
lines(end+1) = '- Figure: `' + string(figA.png) + '`.';
lines(end+1) = '- Figure: `' + string(figX.png) + '`.';
lines(end+1) = sprintf('- Matched temperature points: `%d`.', height(alignedTbl));
lines(end+1) = '';
lines(end+1) = '![kappa_vs_T](../plots/kappa_vs_T.png)';
lines(end+1) = '';
lines(end+1) = '![kappa_vs_A](../plots/kappa_vs_A.png)';
lines(end+1) = '';
lines(end+1) = '![kappa_vs_X](../plots/kappa_vs_X.png)';
lines(end+1) = '';
lines(end+1) = '---';
lines(end+1) = 'Generated on: ' + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
textOut = strjoin(lines, newline);
end

function [plotsDir, reportDir] = ensureRequestedDirs(runDir)
plotsDir = fullfile(runDir, 'plots');
reportDir = fullfile(runDir, 'report');
if exist(plotsDir, 'dir') ~= 7
    mkdir(plotsDir);
end
if exist(reportDir, 'dir') ~= 7
    mkdir(reportDir);
end
end

function zipPath = buildRequestedBundle(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end

items = { ...
    'tables', ...
    'plots', ...
    'report', ...
    'run_manifest.json', ...
    'config_snapshot.m', ...
    'log.txt', ...
    'run_notes.txt'};

existing = {};
for i = 1:numel(items)
    p = fullfile(runDir, items{i});
    if exist(p, 'dir') == 7 || exist(p, 'file') == 2
        existing{end+1} = items{i}; %#ok<AGROW>
    end
end

zip(zipPath, existing, runDir);
end

function c = safeCorr(x, y, corrType)
x = x(:);
y = y(:);
m = isfinite(x) & isfinite(y);
if nnz(m) < 3
    c = NaN;
    return;
end
try
    c = corr(x(m), y(m), 'Type', corrType, 'Rows', 'complete');
catch
    c = corr(x(m), y(m));
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
peakT = T(idx);
end

function y = normalizeSigned(x)
x = x(:);
s = max(abs(x), [], 'omitnan');
if ~isfinite(s) || s <= 0
    y = zeros(size(x));
else
    y = x ./ s;
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

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.2, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top');
grid(ax, 'on');
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

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
