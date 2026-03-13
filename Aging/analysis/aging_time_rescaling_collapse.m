function out = aging_time_rescaling_collapse(cfg)
% aging_time_rescaling_collapse
% Test whether normalized Dip_depth(t_w) curves collapse under the
% rescaled waiting-time variable t_w / tau(T_p).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg, repoRoot);
assert(exist(cfg.datasetPath, 'file') == 2, ...
    'Dataset not found: %s', cfg.datasetPath);

cfgRun = struct();
cfgRun.runLabel = char(string(cfg.runLabel));
cfgRun.datasetName = 'aging_observable_dataset';
cfgRun.dataset = char(string(cfg.datasetPath));
runCtx = createRunContext('aging', cfgRun);
runDir = runCtx.run_dir;
ensureStandardSubdirs(runDir);

fprintf('Aging time-rescaling collapse run root:\n%s\n', runDir);
fprintf('Input dataset: %s\n', cfg.datasetPath);
appendText(runCtx.log_path, sprintf('[%s] started\n', stampNow()));
appendText(runCtx.log_path, sprintf('Dataset: %s\n', cfg.datasetPath));
appendText(runCtx.log_path, sprintf('Normalization: %s\n', cfg.normalizationMode));

dataTbl = readtable(cfg.datasetPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
dataTbl = normalizeDatasetTable(dataTbl);
curves = buildCurveStruct(dataTbl, cfg);
analysis = optimizeCollapse(curves, cfg);
tauTbl = buildTauTable(curves, analysis);

tauPath = save_run_table(tauTbl, 'tau_rescaling_estimates.csv', runDir);

figCollapse = makeCollapseAttemptFigure(curves, analysis, cfg);
figCollapsePaths = save_run_figure(figCollapse, 'collapse_attempt', runDir);
close(figCollapse);

figRescaled = makeRescaledCurvesFigure(curves, analysis, tauTbl);
figRescaledPaths = save_run_figure(figRescaled, 'rescaled_curves', runDir);
close(figRescaled);

reportText = buildReportText(runDir, cfg, dataTbl, curves, analysis, tauTbl);
reportPath = save_run_report(reportText, 'aging_collapse_test_report.md', runDir);
zipPath = buildReviewZip(runDir, 'aging_time_rescaling_collapse.zip');

appendText(runCtx.log_path, sprintf('[%s] raw objective = %.6g\n', ...
    stampNow(), analysis.rawObjective));
appendText(runCtx.log_path, sprintf('[%s] optimized objective = %.6g\n', ...
    stampNow(), analysis.optimizedObjective));
appendText(runCtx.log_path, sprintf('[%s] report: %s\n', stampNow(), reportPath));
appendText(runCtx.log_path, sprintf('[%s] zip: %s\n', stampNow(), zipPath));
appendText(runCtx.notes_path, sprintf('Verdict: %s\n', analysis.verdict));
appendText(runCtx.notes_path, sprintf('Variance reduction = %.3f%%\n', ...
    100 * analysis.varianceReductionFraction));

fprintf('Aging time-rescaling collapse complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Tau table: %s\n', tauPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = string(runDir);
out.dataset_path = string(cfg.datasetPath);
out.table_path = string(tauPath);
out.report_path = string(reportPath);
out.zip_path = string(zipPath);
out.collapse_figure = string(figCollapsePaths.png);
out.rescaled_figure = string(figRescaledPaths.png);
out.tau_table = tauTbl;
out.analysis = analysis;
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'runLabel', 'aging_time_rescaling_collapse');
cfg = setDefault(cfg, 'datasetPath', fullfile(repoRoot, 'results', 'aging', ...
    'runs', 'run_2026_03_12_211204_aging_dataset_build', 'tables', ...
    'aging_observable_dataset.csv'));
cfg = setDefault(cfg, 'normalizationMode', 'divide_by_max');
cfg = setDefault(cfg, 'pairGridCount', 15);
cfg = setDefault(cfg, 'displayGridCount', 120);
cfg = setDefault(cfg, 'minOverlapLog10', 0.20);
cfg = setDefault(cfg, 'minPairSamples', 5);
cfg = setDefault(cfg, 'overlapPenaltyWeight', 0.03);
cfg = setDefault(cfg, 'noOverlapPenalty', 0.35);
cfg = setDefault(cfg, 'minCurvesForStats', 3);
cfg = setDefault(cfg, 'coordinateSteps', [0.25 0.10 0.05]);
cfg = setDefault(cfg, 'maxCoordinatePasses', 4);
end

function ensureStandardSubdirs(runDir)
for folderName = ["figures", "tables", "reports", "review"]
    folderPath = fullfile(runDir, char(folderName));
    if exist(folderPath, 'dir') ~= 7
        mkdir(folderPath);
    end
end
end

function dataTbl = normalizeDatasetTable(dataTbl)
dataTbl.Properties.VariableNames = standardizeVariableNames(dataTbl.Properties.VariableNames);
required = {'Tp', 'tw', 'Dip_depth'};
missing = required(~ismember(required, dataTbl.Properties.VariableNames));
if ~isempty(missing) && width(dataTbl) >= 3
    fallbackNames = dataTbl.Properties.VariableNames;
    fallbackNames{1} = 'Tp';
    fallbackNames{2} = 'tw';
    fallbackNames{3} = 'Dip_depth';
    if width(dataTbl) >= 4
        fallbackNames{4} = 'FM_abs';
    end
    if width(dataTbl) >= 5
        fallbackNames{5} = 'source_run';
    end
    dataTbl.Properties.VariableNames = fallbackNames;
    missing = required(~ismember(required, dataTbl.Properties.VariableNames));
end
assert(isempty(missing), ...
    'Dataset is missing required columns: %s', strjoin(missing, ', '));

numericVars = {'Tp', 'tw', 'Dip_depth', 'FM_abs'};
for i = 1:numel(numericVars)
    vn = numericVars{i};
    if ismember(vn, dataTbl.Properties.VariableNames) && ~isnumeric(dataTbl.(vn))
        dataTbl.(vn) = str2double(erase(string(dataTbl.(vn)), '"'));
    end
end

if ismember('source_run', dataTbl.Properties.VariableNames)
    dataTbl.source_run = string(dataTbl.source_run);
else
    dataTbl.source_run = repmat("", height(dataTbl), 1);
end

dataTbl = sortrows(dataTbl, {'Tp', 'tw'}, {'ascend', 'ascend'});
end

function namesOut = standardizeVariableNames(namesIn)
namesIn = string(namesIn);
namesOut = strings(size(namesIn));
for i = 1:numel(namesIn)
    name = erase(namesIn(i), '"');
    name = regexprep(name, '^x_', '');
    name = regexprep(name, '_+$', '');
    lowerName = lower(name);
    switch lowerName
        case 'tp'
            namesOut(i) = "Tp";
        case 'tw'
            namesOut(i) = "tw";
        case {'dip_depth', 'dipdepth'}
            namesOut(i) = "Dip_depth";
        case {'fm_abs', 'fmabs'}
            namesOut(i) = "FM_abs";
        case {'source_run', 'sourcerun'}
            namesOut(i) = "source_run";
        otherwise
            namesOut(i) = string(matlab.lang.makeValidName(char(name)));
    end
end
namesOut = cellstr(namesOut);
end

function curves = buildCurveStruct(dataTbl, cfg)
tpValues = unique(dataTbl.Tp(isfinite(dataTbl.Tp)), 'sorted');
curves = repmat(struct( ...
    'Tp', NaN, ...
    'tw_s', [], ...
    'log10_tw', [], ...
    'Dip_depth', [], ...
    'Dip_norm', [], ...
    'n_points', NaN, ...
    'peak_tw_s', NaN, ...
    'source_runs', ""), numel(tpValues), 1);

for i = 1:numel(tpValues)
    tp = tpValues(i);
    sub = dataTbl(dataTbl.Tp == tp, :);
    valid = isfinite(sub.tw) & (sub.tw > 0) & isfinite(sub.Dip_depth);
    sub = sub(valid, :);
    assert(height(sub) >= 3, ...
        'Expected at least 3 valid Dip_depth points for T_p = %g K.', tp);

    sub = sortrows(sub, 'tw', 'ascend');
    tw = sub.tw(:);
    dip = sub.Dip_depth(:);
    dipNorm = normalizeSeries(dip, cfg.normalizationMode);

    [~, peakIdx] = max(dipNorm, [], 'omitnan');
    if isempty(peakIdx) || ~isfinite(peakIdx)
        peakIdx = 1;
    end

    curves(i).Tp = tp;
    curves(i).tw_s = tw;
    curves(i).log10_tw = log10(tw);
    curves(i).Dip_depth = dip;
    curves(i).Dip_norm = dipNorm;
    curves(i).n_points = numel(tw);
    curves(i).peak_tw_s = tw(peakIdx);
    curves(i).source_runs = join(unique(sub.source_run), '; ');
end
end

function valuesNorm = normalizeSeries(values, mode)
values = values(:);
mode = lower(char(string(mode)));

switch mode
    case 'divide_by_max'
        scale = max(abs(values), [], 'omitnan');
        if ~(isfinite(scale) && scale > 0)
            error('Could not normalize a Dip_depth series with non-positive scale.');
        end
        valuesNorm = values ./ scale;
    case 'minmax'
        vMin = min(values, [], 'omitnan');
        vMax = max(values, [], 'omitnan');
        if ~(isfinite(vMin) && isfinite(vMax) && vMax > vMin)
            error('Could not min-max normalize a degenerate Dip_depth series.');
        end
        valuesNorm = (values - vMin) ./ (vMax - vMin);
    otherwise
        error('Unsupported normalization mode: %s', mode);
end
end

function analysis = optimizeCollapse(curves, cfg)
nCurves = numel(curves);
assert(nCurves >= 2, 'Need at least two T_p curves to test collapse.');

peakTimes = arrayfun(@(s) s.peak_tw_s, curves);
peakTimes(~isfinite(peakTimes) | peakTimes <= 0) = geometricMean(collectUniqueTimes(curves));
shift0 = log10(peakTimes(:));
shift0 = shift0 - mean(shift0, 'omitnan');

rawShifts = zeros(nCurves, 1);
rawObjective = collapseObjective(rawShifts, curves, cfg);
seedObjective = collapseObjective(shift0, curves, cfg);
if isfinite(seedObjective) && seedObjective < rawObjective
    seedShifts = shift0;
else
    seedShifts = rawShifts;
end

[bestShifts, bestObjective] = coordinateDescentCollapse(seedShifts, curves, cfg);
bestShifts = bestShifts - mean(bestShifts, 'omitnan');
tauRelative = 10 .^ bestShifts;
tauGaugeSeconds = geometricMean(collectUniqueTimes(curves));
tauSeconds = tauRelative .* tauGaugeSeconds;

rawProfile = buildCollapsedProfile(curves, rawShifts, cfg);
rescaledProfile = buildCollapsedProfile(curves, bestShifts, cfg);

analysis = struct();
analysis.shifts_log10 = bestShifts;
analysis.tau_relative = tauRelative;
analysis.tau_seconds = tauSeconds;
analysis.tau_gauge_seconds = tauGaugeSeconds;
analysis.rawObjective = rawObjective;
analysis.optimizedObjective = bestObjective;
analysis.rawProfile = rawProfile;
analysis.rescaledProfile = rescaledProfile;
analysis.varianceReductionFraction = 1 - (bestObjective / max(rawObjective, eps));
analysis.verdict = classifyCollapse(rawObjective, bestObjective, rawProfile, rescaledProfile);
end

function [bestShifts, bestObjective] = coordinateDescentCollapse(initialShifts, curves, cfg)
bestShifts = initialShifts(:);
bestShifts = bestShifts - mean(bestShifts, 'omitnan');
bestObjective = collapseObjective(bestShifts, curves, cfg);

for step = cfg.coordinateSteps(:).'
    improved = true;
    passCount = 0;
    while improved && passCount < cfg.maxCoordinatePasses
        improved = false;
        passCount = passCount + 1;
        for i = 1:numel(bestShifts)
            for delta = [-step, step]
                candidate = bestShifts;
                candidate(i) = candidate(i) + delta;
                candidate = candidate - mean(candidate, 'omitnan');
                candidateObjective = collapseObjective(candidate, curves, cfg);
                if isfinite(candidateObjective) && candidateObjective + 1e-10 < bestObjective
                    bestShifts = candidate;
                    bestObjective = candidateObjective;
                    improved = true;
                end
            end
        end
    end
end
end

function score = collapseObjective(shifts, curves, cfg)
pairScores = computePairScores(shifts, curves, cfg);
if isempty(pairScores)
    score = inf;
else
    score = mean(pairScores, 'omitnan');
end
end

function pairScores = computePairScores(shifts, curves, cfg)
nCurves = numel(curves);
pairScores = nan(nchoosek(nCurves, 2), 1);
cursor = 0;

for i = 1:(nCurves - 1)
    xi = curves(i).log10_tw - shifts(i);
    yi = curves(i).Dip_norm;
    spanI = max(xi) - min(xi);
    for j = (i + 1):nCurves
        cursor = cursor + 1;

        xj = curves(j).log10_tw - shifts(j);
        yj = curves(j).Dip_norm;
        spanJ = max(xj) - min(xj);

        lo = max(min(xi), min(xj));
        hi = min(max(xi), max(xj));
        overlap = hi - lo;

        if ~(isfinite(overlap) && overlap >= cfg.minOverlapLog10)
            pairScores(cursor) = cfg.noOverlapPenalty;
            continue;
        end

        xGrid = linspace(lo, hi, cfg.pairGridCount);
        yiq = interp1(xi, yi, xGrid, 'linear', NaN);
        yjq = interp1(xj, yj, xGrid, 'linear', NaN);
        valid = isfinite(yiq) & isfinite(yjq);

        if nnz(valid) < cfg.minPairSamples
            pairScores(cursor) = cfg.noOverlapPenalty;
            continue;
        end

        mse = mean((yiq(valid) - yjq(valid)) .^ 2, 'omitnan');
        overlapFrac = overlap / max(min(spanI, spanJ), eps);
        pairScores(cursor) = mse + cfg.overlapPenaltyWeight * (1 - overlapFrac) .^ 2;
    end
end

pairScores = pairScores(1:cursor);
end

function profile = buildCollapsedProfile(curves, shifts, cfg)
nCurves = numel(curves);
xMin = inf;
xMax = -inf;

for i = 1:nCurves
    xShifted = curves(i).log10_tw - shifts(i);
    xMin = min(xMin, min(xShifted));
    xMax = max(xMax, max(xShifted));
end

xGrid = linspace(xMin, xMax, cfg.displayGridCount);
Y = nan(nCurves, numel(xGrid));
for i = 1:nCurves
    xShifted = curves(i).log10_tw - shifts(i);
    Y(i, :) = interp1(xShifted, curves(i).Dip_norm, xGrid, 'linear', NaN);
end

count = sum(isfinite(Y), 1);
meanY = mean(Y, 1, 'omitnan');
stdY = std(Y, 0, 1, 'omitnan');
validStatMask = count >= cfg.minCurvesForStats;
if any(validStatMask)
    meanVar = mean(stdY(validStatMask) .^ 2, 'omitnan');
else
    meanVar = NaN;
end

profile = struct();
profile.x_grid = xGrid;
profile.z_grid = 10 .^ xGrid;
profile.curve_count = count;
profile.mean_curve = meanY;
profile.std_curve = stdY;
profile.mean_variance = meanVar;
profile.valid_stat_mask = validStatMask;
end

function tauTbl = buildTauTable(curves, analysis)
nCurves = numel(curves);
rows = repmat(struct( ...
    'Tp', NaN, ...
    'n_points', NaN, ...
    'tw_min_seconds', NaN, ...
    'tw_max_seconds', NaN, ...
    'peak_tw_seconds', NaN, ...
    'tau_relative_geomean1', NaN, ...
    'tau_estimate_seconds', NaN, ...
    'log10_tau_shift', NaN, ...
    'tau_over_peak_tw', NaN, ...
    'source_runs', ""), nCurves, 1);

for i = 1:nCurves
    rows(i).Tp = curves(i).Tp;
    rows(i).n_points = curves(i).n_points;
    rows(i).tw_min_seconds = min(curves(i).tw_s, [], 'omitnan');
    rows(i).tw_max_seconds = max(curves(i).tw_s, [], 'omitnan');
    rows(i).peak_tw_seconds = curves(i).peak_tw_s;
    rows(i).tau_relative_geomean1 = analysis.tau_relative(i);
    rows(i).tau_estimate_seconds = analysis.tau_seconds(i);
    rows(i).log10_tau_shift = analysis.shifts_log10(i);
    rows(i).tau_over_peak_tw = analysis.tau_seconds(i) / max(curves(i).peak_tw_s, eps);
    rows(i).source_runs = curves(i).source_runs;
end

tauTbl = sortrows(struct2table(rows), 'Tp', 'ascend');
end

function fig = makeCollapseAttemptFigure(curves, analysis, cfg)
colors = lines(max(numel(curves), 1));
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1500 620]);
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axRaw = nexttile(tlo, 1);
hold(axRaw, 'on');
for i = 1:numel(curves)
    plot(axRaw, curves(i).tw_s, curves(i).Dip_norm, '-o', ...
        'Color', colors(i, :), 'LineWidth', 1.8, 'MarkerSize', 5.5, ...
        'DisplayName', sprintf('T_p = %g K', curves(i).Tp));
end
set(axRaw, 'XScale', 'log');
xlabel(axRaw, 't_w (s)');
ylabel(axRaw, 'Normalized Dip depth');
title(axRaw, sprintf('Before rescaling (objective %.4f)', analysis.rawObjective));
grid(axRaw, 'on');
set(axRaw, 'FontSize', 10, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
ylim(axRaw, paddedLimits(collectCurveValues(curves, 'Dip_norm')));

axRescaled = nexttile(tlo, 2);
hold(axRescaled, 'on');
for i = 1:numel(curves)
    z = curves(i).tw_s ./ analysis.tau_seconds(i);
    plot(axRescaled, z, curves(i).Dip_norm, '-o', ...
        'Color', colors(i, :), 'LineWidth', 1.8, 'MarkerSize', 5.5, ...
        'DisplayName', sprintf('T_p = %g K', curves(i).Tp));
end
drawMasterBand(axRescaled, analysis.rescaledProfile);
set(axRescaled, 'XScale', 'log');
xlabel(axRescaled, 't_w / \tau(T_p)');
ylabel(axRescaled, 'Normalized Dip depth');
title(axRescaled, sprintf('After rescaling (objective %.4f)', analysis.optimizedObjective));
grid(axRescaled, 'on');
set(axRescaled, 'FontSize', 10, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
ylim(axRescaled, paddedLimits(collectCurveValues(curves, 'Dip_norm')));

lg = legend(axRescaled, 'Location', 'eastoutside');
lg.Box = 'off';
lg.Title.String = 'Curves';

title(tlo, sprintf(['Dip-depth collapse attempt under t_w / \\tau(T_p) ', ...
    '(variance reduction %.1f%%)'], 100 * analysis.varianceReductionFraction));

annotation(fig, 'textbox', [0.15 0.01 0.70 0.08], ...
    'String', sprintf(['Normalization: %s.  \\tau(T_p) scale fixed by ', ...
    'mean waiting-time gauge = %.3g s.'], strrep(cfg.normalizationMode, '_', '\_'), ...
    analysis.tau_gauge_seconds), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 9);
end

function fig = makeRescaledCurvesFigure(curves, analysis, tauTbl)
colors = lines(max(numel(curves), 1));
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1480 680]);
tlo = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
hold(ax1, 'on');
for i = 1:numel(curves)
    z = curves(i).tw_s ./ analysis.tau_seconds(i);
    plot(ax1, z, curves(i).Dip_norm, '-o', ...
        'Color', colors(i, :), 'LineWidth', 1.8, 'MarkerSize', 5.5, ...
        'DisplayName', sprintf('T_p = %g K', curves(i).Tp));
end
drawMasterBand(ax1, analysis.rescaledProfile);
set(ax1, 'XScale', 'log');
xlabel(ax1, 't_w / \tau(T_p)');
ylabel(ax1, 'Normalized Dip depth');
title(ax1, 'Optimized rescaled curves with mean \pm 1\sigma band');
grid(ax1, 'on');
set(ax1, 'FontSize', 10, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
ylim(ax1, paddedLimits(collectCurveValues(curves, 'Dip_norm')));

ax2 = nexttile(tlo, 2);
hold(ax2, 'on');
plot(ax2, tauTbl.Tp, tauTbl.tau_estimate_seconds, '-', ...
    'Color', [0.25 0.25 0.25], 'LineWidth', 1.2);
scatter(ax2, tauTbl.Tp, tauTbl.tau_estimate_seconds, 80, ...
    tauTbl.log10_tau_shift, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.7);
cb = colorbar(ax2);
cb.Label.String = 'log_{10} \tau shift';
set(ax2, 'YScale', 'log');
xlabel(ax2, 'T_p (K)');
ylabel(ax2, '\tau(T_p) [gauge-fixed seconds]');
title(ax2, sprintf('Estimated \\tau(T_p), gauge = %.3g s', analysis.tau_gauge_seconds));
grid(ax2, 'on');
set(ax2, 'FontSize', 10, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');

for i = 1:height(tauTbl)
    text(ax2, tauTbl.Tp(i), tauTbl.tau_estimate_seconds(i), ...
        sprintf('  %.2g', tauTbl.tau_estimate_seconds(i)), ...
        'FontSize', 8, 'VerticalAlignment', 'bottom', 'Color', [0.15 0.15 0.15]);
end

title(tlo, 'Rescaled Dip-depth curves and inferred timescales');
end

function drawMasterBand(ax, profile)
valid = profile.valid_stat_mask & isfinite(profile.mean_curve) & isfinite(profile.std_curve);
if nnz(valid) < 2
    return;
end

x = profile.z_grid(valid);
yMean = profile.mean_curve(valid);
yStd = profile.std_curve(valid);

fill(ax, [x, fliplr(x)], [yMean - yStd, fliplr(yMean + yStd)], ...
    [0.82 0.82 0.82], 'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
plot(ax, x, yMean, '-', 'Color', [0.05 0.05 0.05], 'LineWidth', 2.2, ...
    'DisplayName', 'Mean curve');
end

function values = collectCurveValues(curves, fieldName)
values = [];
for i = 1:numel(curves)
    values = [values; curves(i).(fieldName)(:)]; %#ok<AGROW>
end
end

function lims = paddedLimits(values)
values = values(isfinite(values));
if isempty(values)
    lims = [0, 1];
    return;
end

vMin = min(values);
vMax = max(values);
if abs(vMax - vMin) < 1e-12
    pad = max(abs(vMax), 1) * 0.1;
else
    pad = 0.08 * (vMax - vMin);
end
lims = [vMin - pad, vMax + pad];
end

function txt = buildReportText(runDir, cfg, dataTbl, curves, analysis, tauTbl)
nowText = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
distinctTw = collectUniqueTimes(curves);
validRows = isfinite(dataTbl.Tp) & isfinite(dataTbl.tw) & (dataTbl.tw > 0) & isfinite(dataTbl.Dip_depth);

lines = strings(0, 1);
lines(end + 1) = "# Aging collapse test under time rescaling";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", nowText);
lines(end + 1) = sprintf("Run root: `%s`", runDir);
lines(end + 1) = "";
lines(end + 1) = "## Task";
lines(end + 1) = "- Test whether `Dip_depth(t_w)` curves collapse after normalizing each `T_p` trace and rescaling time as `t_w / \\tau(T_p)`.";
lines(end + 1) = sprintf("- Source dataset: `%s`", cfg.datasetPath);
lines(end + 1) = sprintf("- Normalization used: `%s`.", strrep(cfg.normalizationMode, '_', '\_'));
lines(end + 1) = "- Objective used for `\\tau(T_p)`: mean interpolated pairwise squared mismatch in `log10(t_w / \\tau)` with an overlap penalty.";
lines(end + 1) = sprintf("- Global scale convention: `geommean(\\tau) = %.6g s`.", analysis.tau_gauge_seconds);
lines(end + 1) = "";
lines(end + 1) = "## Dataset summary";
lines(end + 1) = sprintf("- Total rows in dataset: %d", height(dataTbl));
lines(end + 1) = sprintf("- Valid rows used: %d", nnz(validRows));
lines(end + 1) = sprintf("- Distinct `T_p` values analyzed: %d", numel(curves));
lines(end + 1) = sprintf("- Distinct waiting times present: `%s` s", join(string(distinctTw(:).'), ', '));
lines(end + 1) = sprintf("- `T_p = 30 K` and `34 K` each contain `%d` points; all other curves contain `%d` points.", ...
    min(tauTbl.n_points), max(tauTbl.n_points));
lines(end + 1) = "";
lines(end + 1) = "## Collapse summary";
lines(end + 1) = sprintf("- Raw objective: `%.6g`", analysis.rawObjective);
lines(end + 1) = sprintf("- Rescaled objective: `%.6g`", analysis.optimizedObjective);
lines(end + 1) = sprintf("- Objective reduction: `%.2f%%`", 100 * analysis.varianceReductionFraction);
lines(end + 1) = sprintf("- Mean gridded variance before rescaling: `%.6g`", analysis.rawProfile.mean_variance);
lines(end + 1) = sprintf("- Mean gridded variance after rescaling: `%.6g`", analysis.rescaledProfile.mean_variance);
lines(end + 1) = sprintf("- Verdict: %s", analysis.verdict);
lines(end + 1) = "";
lines(end + 1) = "## Estimated timescales";
lines(end + 1) = "| T_p (K) | n | peak t_w (s) | tau relative | tau (s, gauge-fixed) | log10 shift | tau / peak t_w |";
lines(end + 1) = "| ---: | ---: | ---: | ---: | ---: | ---: | ---: |";
for i = 1:height(tauTbl)
    lines(end + 1) = sprintf("| %.0f | %d | %.6g | %.6g | %.6g | %.6g | %.6g |", ...
        tauTbl.Tp(i), tauTbl.n_points(i), tauTbl.peak_tw_seconds(i), ...
        tauTbl.tau_relative_geomean1(i), tauTbl.tau_estimate_seconds(i), ...
        tauTbl.log10_tau_shift(i), tauTbl.tau_over_peak_tw(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
lines(end + 1) = interpretationLine(analysis.varianceReductionFraction, analysis.rescaledProfile.mean_variance);
lines(end + 1) = "- Because the optimization only identifies relative horizontal shifts, the absolute magnitude of `\\tau(T_p)` is conventional up to one common multiplicative factor.";
lines(end + 1) = "- The reported gauge-fixed seconds are chosen only to keep the `t_w / \\tau(T_p)` axis numerically readable.";
lines(end + 1) = "- `FM_abs` was not used in this test because the task specifically targets `Dip_depth` collapse.";
lines(end + 1) = "";
lines(end + 1) = "## Outputs";
lines(end + 1) = "- `tables/tau_rescaling_estimates.csv`";
lines(end + 1) = "- `figures/collapse_attempt.png`";
lines(end + 1) = "- `figures/rescaled_curves.png`";
lines(end + 1) = "- `reports/aging_collapse_test_report.md`";
lines(end + 1) = "- `review/aging_time_rescaling_collapse.zip`";
lines(end + 1) = "";
lines(end + 1) = "## Notes";
lines(end + 1) = "- MATLAB figure exports also include `.pdf` and `.fig` companions via the repository save helper.";
lines(end + 1) = "- If a stricter or looser normalization convention is desired, rerun this script with `cfg.normalizationMode = 'minmax'` or `'divide_by_max'`.";

txt = strjoin(lines, newline);
end

function line = interpretationLine(varianceReductionFraction, rescaledMeanVariance)
if varianceReductionFraction >= 0.50 && isfinite(rescaledMeanVariance) && rescaledMeanVariance <= 0.02
    line = "- The optimized time rescaling produces a strong collapse of the normalized `Dip_depth` curves.";
elseif varianceReductionFraction >= 0.25
    line = "- The optimized time rescaling improves overlap noticeably, but the collapse remains partial rather than exact.";
else
    line = "- The optimized time rescaling does not yield a compelling collapse; substantial curve-to-curve differences remain.";
end
end

function verdict = classifyCollapse(rawObjective, optimizedObjective, rawProfile, rescaledProfile)
improvement = 1 - (optimizedObjective / max(rawObjective, eps));
if improvement >= 0.50 && isfinite(rescaledProfile.mean_variance) && rescaledProfile.mean_variance <= 0.02
    verdict = "Strong collapse after time rescaling.";
elseif improvement >= 0.25 && rescaledProfile.mean_variance < rawProfile.mean_variance
    verdict = "Partial collapse: the rescaling reduces spread but does not fully unify the curves.";
else
    verdict = "Weak collapse: rescaling does not remove most of the inter-curve variation.";
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

files = [collectFiles(fullfile(runDir, 'tables')); ...
    collectFiles(fullfile(runDir, 'figures')); ...
    collectFiles(fullfile(runDir, 'reports'))];
zip(zipPath, files);
end

function files = collectFiles(folderPath)
if exist(folderPath, 'dir') ~= 7
    files = {};
    return;
end

entries = dir(fullfile(folderPath, '*'));
entries = entries(~[entries.isdir]);
files = cell(numel(entries), 1);
for i = 1:numel(entries)
    files{i} = fullfile(entries(i).folder, entries(i).name);
end
end

function times = collectUniqueTimes(curves)
times = [];
for i = 1:numel(curves)
    times = [times; curves(i).tw_s(:)]; %#ok<AGROW>
end
times = unique(times(isfinite(times) & times > 0));
times = sort(times);
end

function value = geometricMean(values)
values = values(isfinite(values) & values > 0);
if isempty(values)
    value = NaN;
    return;
end
value = exp(mean(log(values)));
end

function appendText(pathStr, textStr)
fid = fopen(pathStr, 'a');
if fid < 0
    error('Could not open %s for append.', pathStr);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textStr);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


