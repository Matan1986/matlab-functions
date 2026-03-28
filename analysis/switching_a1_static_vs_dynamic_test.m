function out = switching_a1_static_vs_dynamic_test(cfg)
% switching_a1_static_vs_dynamic_test
% Compare static ridge observables vs their temperature derivatives as
% predictors for dynamic shape-mode amplitude a1(T).

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

fprintf('Switching a1 static-vs-dynamic test run directory:\n%s\n', runDir);
fprintf('a1 source run: %s\n', source.a1RunName);
fprintf('Switching source run: %s\n', source.switchRunName);
appendText(run.log_path, sprintf('[%s] switching a1 static-vs-dynamic test started\n', stampNow()));
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

staticNames = {'I_peak', 'width', 'S_peak', 'X'};
dynamicNames = {'dI_peak_dT', 'dwidth_dT', 'dS_peak_dT', 'dX_dT'};
staticValues = {Ipeak, width, Speak, X};
dynamicValues = {dI, dw, dS, dX};
staticMethods = {'raw', 'raw', 'raw', 'raw'};
dynamicMethods = {methodI, methodW, methodS, methodX};

lowMask = T >= cfg.lowTSectorMinK & T <= cfg.lowTSectorMaxK;
if nnz(lowMask) < 3
    lowMask = true(size(T));
end

rowsStatic = buildPredictorRows(T, a1, staticNames, staticValues, staticMethods, ...
    repmat({'static'}, 1, numel(staticNames)), lowMask);
rowsDynamic = buildPredictorRows(T, a1, dynamicNames, dynamicValues, dynamicMethods, ...
    repmat({'dynamic'}, 1, numel(dynamicNames)), lowMask);

corrTbl = cell2table([rowsStatic; rowsDynamic], 'VariableNames', { ...
    'group', 'predictor', 'n_points', ...
    'pearson_signed', 'spearman_signed', 'pearson_abs', 'spearman_abs', ...
    'pearson_lowT_signed', 'spearman_lowT_signed', 'pearson_lowT_abs', 'spearman_lowT_abs', ...
    'score_global', 'score_lowT', 'score_peak', 'score_overall', ...
    'a1_peak_T_signed_K', 'predictor_peak_T_signed_K', 'delta_peak_T_signed_K', ...
    'a1_peak_T_abs_K', 'predictor_peak_T_abs_K', 'delta_peak_T_abs_K', ...
    'predictor_peak_to_10K_abs_K', 'derivative_method'});

corrTbl.source_run = repmat(string(source.switchRunName), height(corrTbl), 1);
corrTbl = rankWithinGroups(corrTbl);

seriesTbl = table(T, a1, normalizeSigned(a1), abs(a1), normalize01(abs(a1)), ...
    Ipeak, I_smooth, dI_raw, dI, ...
    width, w_smooth, dw_raw, dw, ...
    Speak, S_smooth, dS_raw, dS, ...
    X, X_smooth, dX_raw, dX, ...
    'VariableNames', {'T_K', 'a1', 'a1_norm_signed', 'a1_abs', 'a1_abs_norm', ...
    'I_peak_mA', 'I_peak_smoothed_mA', 'dI_peak_dT_raw', 'dI_peak_dT_smoothed', ...
    'width_mA', 'width_smoothed_mA', 'dwidth_dT_raw', 'dwidth_dT_smoothed', ...
    'S_peak', 'S_peak_smoothed', 'dS_peak_dT_raw', 'dS_peak_dT_smoothed', ...
    'X', 'X_smoothed', 'dX_dT_raw', 'dX_dT_smoothed'});

sourceManifestTbl = table( ...
    string({'a1_dynamic_shape_mode'; 'switching_observables'}), ...
    [source.a1RunName; source.switchRunName], ...
    string({source.a1Path; source.switchPath}), ...
    string({'a1(T) from dynamic shape mode'; 'I_peak,width,S_peak,X from canonical switching source run'}), ...
    string({cfg.canonicalSourceNote; cfg.canonicalSourceNote}), ...
    'VariableNames', {'source_role', 'source_run', 'source_file', 'role_note', 'source_note'});

corrPath = save_run_table(corrTbl, 'a1_static_vs_dynamic_correlations.csv', runDir);
seriesPath = save_run_table(seriesTbl, 'a1_static_vs_dynamic_series.csv', runDir);
sourcePath = save_run_table(sourceManifestTbl, 'a1_static_vs_dynamic_sources.csv', runDir);

figPath = saveOverlayFigure(T, a1, staticNames, dynamicNames, staticValues, dynamicValues, corrTbl, runDir, ...
    'a1_static_vs_dynamic_overlay');

[rankingText, verdict, summary] = buildRankingReport(source, cfg, corrTbl, corrPath, seriesPath, sourcePath, figPath);
rankingPath = save_run_report(rankingText, 'a1_predictor_rankings.md', runDir);

zipPath = buildReviewZip(runDir, 'switching_a1_static_vs_dynamic_test_bundle.zip');

appendText(run.notes_path, sprintf('a1 source run = %s\n', char(source.a1RunName)));
appendText(run.notes_path, sprintf('switching source run = %s\n', char(source.switchRunName)));
appendText(run.notes_path, sprintf('decision = %s\n', verdict));
appendText(run.notes_path, sprintf('reason = %s\n', summary));
appendText(run.notes_path, sprintf('correlation table = %s\n', corrPath));
appendText(run.notes_path, sprintf('overlay figure = %s\n', figPath.png));
appendText(run.notes_path, sprintf('ranking report = %s\n', rankingPath));
appendText(run.notes_path, sprintf('zip = %s\n', zipPath));

appendText(run.log_path, sprintf('[%s] switching a1 static-vs-dynamic test complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlation table: %s\n', corrPath));
appendText(run.log_path, sprintf('Series table: %s\n', seriesPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', sourcePath));
appendText(run.log_path, sprintf('Overlay figure: %s\n', figPath.png));
appendText(run.log_path, sprintf('Rankings report: %s\n', rankingPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.verdict = string(verdict);
out.summary = string(summary);
out.paths = struct( ...
    'correlations', string(corrPath), ...
    'series', string(seriesPath), ...
    'sourceManifest', string(sourcePath), ...
    'figure', string(figPath.png), ...
    'rankings', string(rankingPath), ...
    'zip', string(zipPath));

fprintf('\n=== Switching a1 static-vs-dynamic test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Decision: %s\n', verdict);
fprintf('Correlation table: %s\n', corrPath);
fprintf('Overlay figure: %s\n', figPath.png);
fprintf('Rankings report: %s\n', rankingPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_a1_static_vs_dynamic_test');
cfg = setDefaultField(cfg, 'a1RunName', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefaultField(cfg, 'a1ColumnName', 'a_1');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'lowTSectorMinK', 8);
cfg = setDefaultField(cfg, 'lowTSectorMaxK', 12);
cfg = setDefaultField(cfg, 'sgolayPolynomialOrder', 2);
cfg = setDefaultField(cfg, 'sgolayFrameLength', 5);
cfg = setDefaultField(cfg, 'movmeanWindow', 3);
cfg = setDefaultField(cfg, 'canonicalSourceNote', ...
    'Canonical source for this comparison run follows prior a1 analyses in results/switching.');
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
if exist(source.switchPath, 'file') ~= 2
    source.switchPath = fullfile(source.switchRunDir, 'observable_matrix.csv');
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

if ~ismember('X', tbl.Properties.VariableNames)
    [canonicalT, canonicalX] = get_canonical_X();
    % X is loaded from canonical run to avoid drift from duplicated implementations
    tbl.X = interp1(canonicalT, canonicalX, double(tbl.T_K(:)), 'linear', NaN);
end

tbl = sortrows(tbl, 'T_K');
data = struct();
data.T_K = double(tbl.T_K(:));
data.I_peak_mA = double(tbl.I_peak_mA(:));
data.width_mA = double(tbl.width_mA(:));
data.S_peak = double(tbl.S_peak(:));
data.X = double(tbl.X(:));
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
X = NaN(n, 1);

for i = 1:n
    t = T(i);
    rows = tblLong(double(tblLong.temperature) == t, :);
    obs = lower(string(rows.observable));
    vals = double(rows.value);
    I_peak(i) = firstValue(obs, vals, ["i_peak"]);
    width(i) = firstValue(obs, vals, ["width_i", "width"]);
    S_peak(i) = firstValue(obs, vals, ["s_peak"]);
    X(i) = firstValue(obs, vals, ["x"]);
end

tbl = table(T, I_peak, width, S_peak, X, ...
    'VariableNames', {'T_K', 'I_peak_mA', 'width_mA', 'S_peak', 'X'});
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

function rows = buildPredictorRows(T, a1, names, values, methods, groups, lowMask)
rows = cell(numel(names), 23);
for i = 1:numel(names)
    p = values{i}(:);
    valid = isfinite(T) & isfinite(a1) & isfinite(p);
    n = nnz(valid);

    pearsonSigned = safeCorr(a1(valid), p(valid), 'Pearson');
    spearmanSigned = safeCorr(a1(valid), p(valid), 'Spearman');
    pearsonAbs = safeCorr(abs(a1(valid)), abs(p(valid)), 'Pearson');
    spearmanAbs = safeCorr(abs(a1(valid)), abs(p(valid)), 'Spearman');

    lowValid = valid & lowMask(:);
    pearsonLowSigned = safeCorr(a1(lowValid), p(lowValid), 'Pearson');
    spearmanLowSigned = safeCorr(a1(lowValid), p(lowValid), 'Spearman');
    pearsonLowAbs = safeCorr(abs(a1(lowValid)), abs(p(lowValid)), 'Pearson');
    spearmanLowAbs = safeCorr(abs(a1(lowValid)), abs(p(lowValid)), 'Spearman');

    [a1PeakTSigned, ~] = peakOf(T(valid), a1(valid), false);
    [pPeakTSigned, ~] = peakOf(T(valid), p(valid), false);
    [a1PeakTAbs, ~] = peakOf(T(valid), a1(valid), true);
    [pPeakTAbs, ~] = peakOf(T(valid), p(valid), true);

    scoreGlobal = mean(abs([pearsonSigned, spearmanSigned, pearsonAbs, spearmanAbs]), 'omitnan');
    scoreLowT = mean(abs([pearsonLowSigned, spearmanLowSigned, pearsonLowAbs, spearmanLowAbs]), 'omitnan');
    scorePeak = mean(exp(-abs([pPeakTSigned - a1PeakTSigned, pPeakTAbs - a1PeakTAbs]) ./ 4), 'omitnan');
    scoreOverall = 0.55 * zeroIfNaN(scoreGlobal) + 0.25 * zeroIfNaN(scoreLowT) + 0.20 * zeroIfNaN(scorePeak);

    rows(i, :) = { ...
        groups{i}, names{i}, n, ...
        pearsonSigned, spearmanSigned, pearsonAbs, spearmanAbs, ...
        pearsonLowSigned, spearmanLowSigned, pearsonLowAbs, spearmanLowAbs, ...
        scoreGlobal, scoreLowT, scorePeak, scoreOverall, ...
        a1PeakTSigned, pPeakTSigned, pPeakTSigned - a1PeakTSigned, ...
        a1PeakTAbs, pPeakTAbs, pPeakTAbs - a1PeakTAbs, ...
        abs(pPeakTAbs - 10), methods{i}};
end
end

function out = zeroIfNaN(v)
if isnan(v) || ~isfinite(v)
    out = 0;
else
    out = v;
end
end

function tbl = rankWithinGroups(tbl)
tbl.rank_in_group = NaN(height(tbl), 1);
groups = unique(string(tbl.group));
for i = 1:numel(groups)
    g = groups(i);
    idx = find(string(tbl.group) == g);
    sub = tbl(idx, :);
    sub = sortrows(sub, {'score_overall', 'score_lowT', 'score_global', 'delta_peak_T_abs_K'}, ...
        {'descend', 'descend', 'descend', 'ascend'});
    sub.rank_in_group = (1:height(sub)).';
    tbl(idx, :) = sub;
end
tbl = sortrows(tbl, {'group', 'rank_in_group'}, {'ascend', 'ascend'});
end

function figOut = saveOverlayFigure(T, a1, staticNames, dynamicNames, staticValues, dynamicValues, corrTbl, runDir, baseName)
fig = create_figure('Visible', 'off', 'Position', [2 2 24 20]);
tl = tiledlayout(fig, 4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:4
    axL = nexttile(tl, 2 * i - 1);
    rowStatic = corrTbl(strcmp(corrTbl.predictor, staticNames{i}), :);
    drawOverlayPanel(axL, T, a1, staticValues{i}, staticNames{i}, rowStatic, 'Static');

    axR = nexttile(tl, 2 * i);
    rowDyn = corrTbl(strcmp(corrTbl.predictor, dynamicNames{i}), :);
    drawOverlayPanel(axR, T, a1, dynamicValues{i}, dynamicNames{i}, rowDyn, 'Dynamic');
end

title(tl, 'a1(T) overlays: static ridge observables vs derivative observables');
figOut = save_run_figure(fig, baseName, runDir);
close(fig);
end

function drawOverlayPanel(ax, T, a1, pred, name, row, groupName)
hold(ax, 'on');
plot(ax, T, normalizeSigned(a1), '-o', 'Color', [0.00 0.45 0.74], ...
    'LineWidth', 2.1, 'MarkerSize', 4.5, 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'DisplayName', 'a1(T) signed-norm');
plot(ax, T, normalizeSigned(pred), '-s', 'Color', [0.85 0.33 0.10], ...
    'LineWidth', 2.1, 'MarkerSize', 4.5, 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'DisplayName', sprintf('%s signed-norm', name));
yline(ax, 0, '-', 'LineWidth', 1.0, 'Color', [0.70 0.70 0.70]);
hold(ax, 'off');

xlabel(ax, 'Temperature (K)', 'FontSize', 14);
ylabel(ax, 'Normalized amplitude', 'FontSize', 14);
title(ax, sprintf('%s | %s | r=%.3f, \\rho=%.3f, \\DeltaT=%.1f K', ...
    groupName, name, row.pearson_signed(1), row.spearman_signed(1), row.delta_peak_T_abs_K(1)), ...
    'FontSize', 11);
set(ax, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'FontSize', 9);
end

function [reportText, verdict, summary] = buildRankingReport(source, cfg, corrTbl, corrPath, seriesPath, sourcePath, figPath)
staticTbl = corrTbl(strcmp(corrTbl.group, 'static'), :);
dynamicTbl = corrTbl(strcmp(corrTbl.group, 'dynamic'), :);

bestStatic = staticTbl(1, :);
bestDynamic = dynamicTbl(1, :);

staticComposite = 0.60 * bestStatic.score_overall + 0.40 * mean(staticTbl.score_overall, 'omitnan');
dynamicComposite = 0.60 * bestDynamic.score_overall + 0.40 * mean(dynamicTbl.score_overall, 'omitnan');

if dynamicComposite >= staticComposite
    verdict = 'B) temperature sensitivity of ridge geometry (derivative observables)';
else
    verdict = 'A) static ridge geometry';
end

summary = sprintf([ ...
    'dynamic composite=%.4f vs static composite=%.4f; ' ...
    'best dynamic=%s (overall=%.4f, lowT=%.4f, |delta_peak|=%.2f K), ' ...
    'best static=%s (overall=%.4f, lowT=%.4f, |delta_peak|=%.2f K).'], ...
    dynamicComposite, staticComposite, ...
    string(bestDynamic.predictor), bestDynamic.score_overall, bestDynamic.score_lowT, abs(bestDynamic.delta_peak_T_abs_K), ...
    string(bestStatic.predictor), bestStatic.score_overall, bestStatic.score_lowT, abs(bestStatic.delta_peak_T_abs_K));

lines = strings(0, 1);
lines(end + 1) = "# a1(T) static vs dynamic ridge-geometry comparison";
lines(end + 1) = "";
lines(end + 1) = "## Sources and scope";
lines(end + 1) = "- a1 source run: `" + source.a1RunName + "`";
lines(end + 1) = "- switching source run: `" + source.switchRunName + "`";
lines(end + 1) = "- temperature range analyzed: `" + sprintf('%.1f to %.1f K', cfg.temperatureMinK, cfg.temperatureMaxK) + "`";
lines(end + 1) = "- low-temperature focus window: `" + sprintf('%.1f to %.1f K', cfg.lowTSectorMinK, cfg.lowTSectorMaxK) + "`";
lines(end + 1) = "- derivative smoothing: `sgolayfilt(p=2, frame=5)` with movmean fallback only if SG fails.";
lines(end + 1) = "- source manifest: `" + string(sourcePath) + "`";
lines(end + 1) = "";
lines(end + 1) = "## Requested outputs";
lines(end + 1) = "- `a1_static_vs_dynamic_correlations.csv`: `" + string(corrPath) + "`";
lines(end + 1) = "- `a1_static_vs_dynamic_overlay.png`: `" + string(figPath.png) + "`";
lines(end + 1) = "- `a1_predictor_rankings.md`: this report";
lines(end + 1) = "- aligned series table: `" + string(seriesPath) + "`";
lines(end + 1) = "";
lines(end + 1) = "![a1_static_dynamic_overlay](../figures/a1_static_vs_dynamic_overlay.png)";
lines(end + 1) = "";
lines(end + 1) = "## Static-group ranking";
for i = 1:height(staticTbl)
    r = staticTbl(i, :);
    lines(end + 1) = sprintf('%d. `%s`: overall=%.4f, global=%.4f, lowT=%.4f, Pearson=%.4f, Spearman=%.4f, |DeltaPeak|=%.2f K, peak-to-10K=%.2f K.', ...
        r.rank_in_group, string(r.predictor), r.score_overall, r.score_global, r.score_lowT, ...
        r.pearson_signed, r.spearman_signed, abs(r.delta_peak_T_abs_K), r.predictor_peak_to_10K_abs_K);
end
lines(end + 1) = "";
lines(end + 1) = "## Dynamic-group ranking";
for i = 1:height(dynamicTbl)
    r = dynamicTbl(i, :);
    lines(end + 1) = sprintf('%d. `%s`: overall=%.4f, global=%.4f, lowT=%.4f, Pearson=%.4f, Spearman=%.4f, |DeltaPeak|=%.2f K, peak-to-10K=%.2f K.', ...
        r.rank_in_group, string(r.predictor), r.score_overall, r.score_global, r.score_lowT, ...
        r.pearson_signed, r.spearman_signed, abs(r.delta_peak_T_abs_K), r.predictor_peak_to_10K_abs_K);
end
lines(end + 1) = "";
lines(end + 1) = "## Interpretation for the ~10 K shape sector";
lines(end + 1) = "- Decision: **" + verdict + "**";
lines(end + 1) = "- Evidence summary: " + string(summary);
lines(end + 1) = "- Criterion: group composite = `0.60*best_overall + 0.40*group_mean_overall`.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 2 curves per panel, 8 panels total (4 static + 4 dynamic)";
lines(end + 1) = "- legend vs colormap: legends used (each panel has <= 6 curves)";
lines(end + 1) = "- colormap used: not used for line overlays";
lines(end + 1) = "- smoothing applied: SG smoothing before derivatives (`p=2`, `frame=5`), minimum fallback only if unavailable";
lines(end + 1) = "- justification: panel-wise normalized overlays make timing and shape agreement visible per predictor.";
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

files = { ...
    fullfile(runDir, 'tables', 'a1_static_vs_dynamic_correlations.csv'), ...
    fullfile(runDir, 'figures', 'a1_static_vs_dynamic_overlay.png'), ...
    fullfile(runDir, 'reports', 'a1_predictor_rankings.md'), ...
    fullfile(runDir, 'tables', 'a1_static_vs_dynamic_sources.csv'), ...
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
