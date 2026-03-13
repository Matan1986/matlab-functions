function out = aging_component_clock_test()
% aging_component_clock_test
% Compare Dip_depth and FM_abs aging trajectories using the consolidated
% observable dataset and test whether they share a common aging clock.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfgRun = struct();
cfgRun.runLabel = 'aging_component_clock_test';
cfgRun.datasetName = 'aging_observable_dataset';
cfgRun.source_dataset = fullfile('results', 'aging', 'runs', ...
    'run_2026_03_12_211204_aging_dataset_build', 'tables', 'aging_observable_dataset.csv');

runCtx = createRunContext('aging', cfgRun);
run_output_dir = runCtx.run_dir;

fprintf('Aging component clock test run root:\n%s\n', run_output_dir);

datasetPath = fullfile(repoRoot, cfgRun.source_dataset);
assert(exist(datasetPath, 'file') == 2, 'Missing dataset: %s', datasetPath);

dataTbl = loadObservableDataset(datasetPath);
tpValues = unique(dataTbl.Tp, 'sorted');

plotData = repmat(initPlotData(), numel(tpValues), 1);
metricRows = repmat(initMetricRow(), numel(tpValues), 1);
for i = 1:numel(tpValues)
    tpTbl = dataTbl(dataTbl.Tp == tpValues(i), :);
    [plotData(i), metricRows(i)] = analyzeTpSlice(tpTbl);
end

metricTbl = struct2table(metricRows);
metricTbl = sortrows(metricTbl, 'Tp');
tablePath = save_run_table(metricTbl, 'component_correlation_vs_Tp.csv', run_output_dir);

figDip = makeObservableFigure(plotData, 'dip', 'Dip depth vs t_w for each T_p', ...
    'Dip depth (memory component)');
saveFigureOutputs(figDip, 'dip_vs_tw', run_output_dir);
close(figDip);

figFm = makeObservableFigure(plotData, 'fm', 'FM amplitude vs t_w for each T_p', ...
    'FM abs (background component)');
saveFigureOutputs(figFm, 'fm_vs_tw', run_output_dir);
close(figFm);

figNorm = makeNormalizedComparisonFigure(plotData, metricTbl);
saveFigureOutputs(figNorm, 'normalized_component_comparison', run_output_dir);
close(figNorm);

reportText = buildReportText(metricTbl, dataTbl, cfgRun.source_dataset);
reportPath = save_run_report(reportText, 'aging_component_clock_report.md', run_output_dir);

zipPath = createReviewZip(run_output_dir);

fprintf('Aging component clock test complete.\n');
fprintf('Run root: %s\n', run_output_dir);
fprintf('Summary table: %s\n', tablePath);
fprintf('Report: %s\n', reportPath);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = run_output_dir;
out.table_path = tablePath;
out.report_path = reportPath;
out.zip_path = zipPath;
out.metric_table = metricTbl;
end

function T = loadObservableDataset(datasetPath)
fid = fopen(datasetPath, 'r', 'n', 'UTF-8');
assert(fid ~= -1, 'Could not open dataset: %s', datasetPath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

headerLine = fgetl(fid);
headerLine = erase(string(headerLine), char(65279));
assert(contains(headerLine, 'Tp') && contains(headerLine, 'Dip_depth') && contains(headerLine, 'FM_abs'), ...
    'Unexpected dataset header: %s', headerLine);

raw = textscan(fid, '%q%q%q%q%q', 'Delimiter', ',', 'ReturnOnError', false);
T = table(raw{1}, raw{2}, raw{3}, raw{4}, raw{5}, ...
    'VariableNames', {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'});

T.Tp = makeNumericColumn(T.Tp);
T.tw = makeNumericColumn(T.tw);
T.Dip_depth = makeNumericColumn(T.Dip_depth);
T.FM_abs = makeNumericColumn(T.FM_abs);
T.source_run = string(T.source_run);
T = sortrows(T, {'Tp', 'tw'});
end

function values = makeNumericColumn(valuesIn)
if isnumeric(valuesIn)
    values = double(valuesIn);
    return;
end

if islogical(valuesIn)
    values = double(valuesIn);
    return;
end

try
    values = str2double(string(valuesIn));
catch
    error('Could not convert dataset column to numeric values.');
end
end

function row = initMetricRow()
row = struct();
row.Tp = NaN;
row.n_tw_points = NaN;
row.n_fm_points = NaN;
row.n_common_points = NaN;
row.dip_max = NaN;
row.fm_max = NaN;
row.pearson_r_raw = NaN;
row.pearson_r_normalized = NaN;
row.best_shift_log10_tw_decades = NaN;
row.best_shift_factor = NaN;
row.best_shift_rmse = NaN;
end

function plotRow = initPlotData()
plotRow = struct();
plotRow.Tp = NaN;
plotRow.tw = NaN(0, 1);
plotRow.dip = NaN(0, 1);
plotRow.fm = NaN(0, 1);
plotRow.dip_norm = NaN(0, 1);
plotRow.fm_norm = NaN(0, 1);
end

function [plotRow, metricRow] = analyzeTpSlice(tpTbl)
[tw, order] = sort(tpTbl.tw);
dip = tpTbl.Dip_depth(order);
fm = tpTbl.FM_abs(order);
tp = tpTbl.Tp(order);
assert(all(abs(tp - tp(1)) < 1e-9), 'Unexpected mixed Tp values in a single slice.');

plotRow = initPlotData();
plotRow.Tp = tp(1);
plotRow.tw = tw(:);
plotRow.dip = dip(:);
plotRow.fm = fm(:);
plotRow.dip_norm = normalizeByFiniteMaximum(dip(:));
plotRow.fm_norm = normalizeByFiniteMaximum(fm(:));

commonMask = isfinite(plotRow.dip) & isfinite(plotRow.fm);

metricRow = initMetricRow();
metricRow.Tp = tp(1);
metricRow.n_tw_points = numel(tw);
metricRow.n_fm_points = nnz(isfinite(plotRow.fm));
metricRow.n_common_points = nnz(commonMask);
metricRow.dip_max = max(plotRow.dip, [], 'omitnan');
metricRow.fm_max = max(plotRow.fm, [], 'omitnan');

if metricRow.n_common_points >= 2
    metricRow.pearson_r_raw = pearsonCorrelation(plotRow.dip(commonMask), plotRow.fm(commonMask));
    metricRow.pearson_r_normalized = pearsonCorrelation( ...
        plotRow.dip_norm(commonMask), plotRow.fm_norm(commonMask));
end

if nnz(isfinite(plotRow.dip_norm)) >= 2 && nnz(isfinite(plotRow.fm_norm)) >= 2
    [shiftDecades, shiftFactor, shiftRmse] = estimateClockShift( ...
        plotRow.tw(isfinite(plotRow.dip_norm)), plotRow.dip_norm(isfinite(plotRow.dip_norm)), ...
        plotRow.tw(isfinite(plotRow.fm_norm)), plotRow.fm_norm(isfinite(plotRow.fm_norm)));
    metricRow.best_shift_log10_tw_decades = shiftDecades;
    metricRow.best_shift_factor = shiftFactor;
    metricRow.best_shift_rmse = shiftRmse;
end
end

function valuesNorm = normalizeByFiniteMaximum(values)
valuesNorm = nan(size(values));
validMask = isfinite(values);
if ~any(validMask)
    return;
end

maxVal = max(values(validMask));
if ~isfinite(maxVal) || abs(maxVal) <= eps
    return;
end

valuesNorm(validMask) = values(validMask) ./ maxVal;
end

function r = pearsonCorrelation(x, y)
x = x(:);
y = y(:);
validMask = isfinite(x) & isfinite(y);
x = x(validMask);
y = y(validMask);

if numel(x) < 2
    r = NaN;
    return;
end

x = x - mean(x);
y = y - mean(y);
denom = sqrt(sum(x .^ 2) * sum(y .^ 2));
if denom <= eps
    r = NaN;
else
    r = sum(x .* y) / denom;
end
end

function [bestShiftDecades, bestShiftFactor, bestShiftRmse] = estimateClockShift(twDip, dipNorm, twFm, fmNorm)
xDip = log10(twDip(:));
yDip = dipNorm(:);
xFm = log10(twFm(:));
yFm = fmNorm(:);

validDip = isfinite(xDip) & isfinite(yDip);
validFm = isfinite(xFm) & isfinite(yFm);
xDip = xDip(validDip);
yDip = yDip(validDip);
xFm = xFm(validFm);
yFm = yFm(validFm);

bestShiftDecades = NaN;
bestShiftFactor = NaN;
bestShiftRmse = NaN;

if numel(xDip) < 2 || numel(xFm) < 2
    return;
end

deltaGrid = linspace(-2.5, 2.5, 1001);
rmseVals = nan(size(deltaGrid));

for i = 1:numel(deltaGrid)
    rmseVals(i) = shiftedCurveRmse(xDip, yDip, xFm, yFm, deltaGrid(i));
end

validMask = isfinite(rmseVals);
if ~any(validMask)
    return;
end

candidateIdx = find(validMask);
candidateRmse = rmseVals(validMask);
bestRmse = min(candidateRmse);
bestCandidates = candidateIdx(abs(rmseVals(validMask) - bestRmse) <= 1e-12);
if numel(bestCandidates) > 1
    [~, localIdx] = min(abs(deltaGrid(bestCandidates)));
    bestIdx = bestCandidates(localIdx);
else
    bestIdx = bestCandidates(1);
end

bestShiftDecades = deltaGrid(bestIdx);
bestShiftFactor = 10 .^ bestShiftDecades;
bestShiftRmse = rmseVals(bestIdx);
end

function rmse = shiftedCurveRmse(xDip, yDip, xFm, yFm, delta)
xFmShifted = xFm + delta;
overlapStart = max(min(xDip), min(xFmShifted));
overlapEnd = min(max(xDip), max(xFmShifted));

if ~isfinite(overlapStart) || ~isfinite(overlapEnd) || overlapEnd <= overlapStart
    rmse = NaN;
    return;
end

if overlapEnd - overlapStart < 0.15
    rmse = NaN;
    return;
end

xEval = linspace(overlapStart, overlapEnd, 200);
yDipEval = interp1(xDip, yDip, xEval, 'linear', NaN);
yFmEval = interp1(xFmShifted, yFm, xEval, 'linear', NaN);

validMask = isfinite(yDipEval) & isfinite(yFmEval);
if nnz(validMask) < 20
    rmse = NaN;
    return;
end

deltaY = yDipEval(validMask) - yFmEval(validMask);
rmse = sqrt(mean(deltaY .^ 2));
end

function fig = makeObservableFigure(plotData, valueField, titleText, yLabel)
fig = create_figure('Visible', 'off', 'Position', [2 2 16.8 10.2]);
ax = axes(fig);
hold(ax, 'on');

colors = lines(numel(plotData));
allTw = collectAllTw(plotData);

for i = 1:numel(plotData)
    x = plotData(i).tw;
    switch valueField
        case 'dip'
            y = plotData(i).dip;
            marker = 'o';
        case 'fm'
            y = plotData(i).fm;
            marker = 's';
        otherwise
            error('Unsupported valueField: %s', valueField);
    end

    validMask = isfinite(x) & isfinite(y);
    if ~any(validMask)
        continue;
    end

    plot(ax, x(validMask), y(validMask), ['-' marker], ...
        'Color', colors(i, :), ...
        'MarkerFaceColor', colors(i, :), ...
        'MarkerSize', 6, ...
        'DisplayName', sprintf('T_p = %g K', plotData(i).Tp));
end

set(ax, 'XScale', 'log');
if ~isempty(allTw)
    xticks(ax, allTw);
end
grid(ax, 'on');
xlabel(ax, 't_w (s)');
ylabel(ax, yLabel);
title(ax, titleText);
legend(ax, 'Location', 'eastoutside');
end

function fig = makeNormalizedComparisonFigure(plotData, metricTbl)
fig = create_figure('Visible', 'off', 'Position', [2 2 19.2 11.8]);
tl = tiledlayout(fig, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Normalized component comparison by T_p');
xlabel(tl, 't_w (s)');
ylabel(tl, 'Observable / max per T_p');

allTw = collectAllTw(plotData);
legendAx = gobjects(0);
dipHandle = gobjects(0);
fmHandle = gobjects(0);

for i = 1:numel(plotData)
    ax = nexttile(tl, i);
    if isempty(legendAx) || ~isgraphics(legendAx)
        legendAx = ax;
    end
    hold(ax, 'on');

    dipMask = isfinite(plotData(i).tw) & isfinite(plotData(i).dip_norm);
    fmMask = isfinite(plotData(i).tw) & isfinite(plotData(i).fm_norm);

    if any(dipMask)
        hDip = plot(ax, plotData(i).tw(dipMask), plotData(i).dip_norm(dipMask), '-o', ...
            'Color', [0.0000 0.4470 0.7410], ...
            'MarkerFaceColor', [0.0000 0.4470 0.7410], ...
            'MarkerSize', 5, ...
            'DisplayName', 'Dip_depth');
        if isempty(dipHandle) || ~isgraphics(dipHandle)
            dipHandle = hDip;
        end
    end

    if any(fmMask)
        hFm = plot(ax, plotData(i).tw(fmMask), plotData(i).fm_norm(fmMask), '-s', ...
            'Color', [0.8500 0.3250 0.0980], ...
            'MarkerFaceColor', [0.8500 0.3250 0.0980], ...
            'MarkerSize', 5, ...
            'DisplayName', 'FM_abs');
        if isempty(fmHandle) || ~isgraphics(fmHandle)
            fmHandle = hFm;
        end
    end

    set(ax, 'XScale', 'log', 'YLim', [0 1.08]);
    if ~isempty(allTw)
        xticks(ax, allTw);
    end
    grid(ax, 'on');
    title(ax, sprintf('T_p = %g K', plotData(i).Tp));

    row = metricTbl(metricTbl.Tp == plotData(i).Tp, :);
    annotationText = buildTileAnnotation(row);
    text(ax, 0.05, 0.95, annotationText, 'Units', 'normalized', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
        'FontSize', 7, 'BackgroundColor', 'w', 'Margin', 4);
end

if isgraphics(legendAx) && isgraphics(dipHandle) && isgraphics(fmHandle)
    legend(legendAx, [dipHandle, fmHandle], {'Dip_depth', 'FM_abs'}, ...
        'Location', 'southoutside', 'Orientation', 'horizontal');
end
end

function annotationText = buildTileAnnotation(row)
if isempty(row)
    annotationText = 'No summary available';
    return;
end

if row.n_fm_points == 0
    annotationText = 'FM_abs unavailable';
    return;
end

if row.n_common_points < 2 || ~isfinite(row.pearson_r_normalized)
    annotationText = 'Insufficient paired points';
    return;
end

if isfinite(row.best_shift_log10_tw_decades)
    annotationText = sprintf('r = %.2f\n\\Delta log_{10} t_w = %.2f', ...
        row.pearson_r_normalized, row.best_shift_log10_tw_decades);
else
    annotationText = sprintf('r = %.2f\nShift unavailable', row.pearson_r_normalized);
end
end

function twValues = collectAllTw(plotData)
twValues = [];
for i = 1:numel(plotData)
    twValues = [twValues; plotData(i).tw(:)]; %#ok<AGROW>
end
twValues = unique(twValues(isfinite(twValues)));
twValues = twValues(:).';
end

function reportText = buildReportText(metricTbl, dataTbl, datasetRelPath)
lines = strings(0, 1);
lines(end + 1) = "# Aging Component Clock Test";
lines(end + 1) = "";
lines(end + 1) = "## Input";
lines(end + 1) = sprintf('- Source dataset: `%s`', datasetRelPath);
lines(end + 1) = sprintf('- Source runs represented in dataset: %s', join(unique(dataTbl.source_run), ', '));
lines(end + 1) = '- `Dip_depth` is treated as the memory component.';
lines(end + 1) = '- `FM_abs` is treated as the background component.';
lines(end + 1) = '- `FM_abs` rows with `NaN` were ignored in every FM-specific calculation.';
lines(end + 1) = "";
lines(end + 1) = "## Method";
lines(end + 1) = '- Plotted `Dip_depth(t_w)` and `FM_abs(t_w)` separately for each `T_p` on a logarithmic `t_w` axis.';
lines(end + 1) = '- Normalized each observable by its own finite maximum within the same `T_p` slice.';
lines(end + 1) = '- Computed Pearson correlation using only paired finite `(Dip_depth, FM_abs)` values at the same `t_w`.';
lines(end + 1) = '- Estimated a horizontal shift on `log10(t_w)` by moving the normalized `FM_abs` curve until the interpolation-based RMSE versus normalized `Dip_depth` was minimized.';
lines(end + 1) = '- Positive shift means `FM_abs` must move to larger `t_w` to align with `Dip_depth`; negative shift means it must move to smaller `t_w`.';
lines(end + 1) = "";
lines(end + 1) = "## Summary";
lines(end + 1) = summarizeClockAgreement(metricTbl);

missingFmRows = metricTbl(metricTbl.n_fm_points == 0, :);
if ~isempty(missingFmRows)
    lines(end + 1) = sprintf('- `FM_abs` is absent for `T_p = %s K`, so those temperatures cannot test the shared-clock hypothesis directly.', ...
        join(string(missingFmRows.Tp.'), ', '));
end

bestCorrRow = bestFiniteRow(metricTbl, 'pearson_r_normalized', 'descend');
if ~isempty(bestCorrRow)
    lines(end + 1) = sprintf('- Strongest normalized shape agreement: `T_p = %.0f K` with `r = %.3f` and shift `%.3f` decades (factor `%.2fx`).', ...
        bestCorrRow.Tp, bestCorrRow.pearson_r_normalized, ...
        bestCorrRow.best_shift_log10_tw_decades, bestCorrRow.best_shift_factor);
end

worstCorrRow = bestFiniteRow(metricTbl, 'pearson_r_normalized', 'ascend');
if ~isempty(worstCorrRow)
    lines(end + 1) = sprintf('- Weakest normalized agreement: `T_p = %.0f K` with `r = %.3f` and shift `%.3f` decades (factor `%.2fx`).', ...
        worstCorrRow.Tp, worstCorrRow.pearson_r_normalized, ...
        worstCorrRow.best_shift_log10_tw_decades, worstCorrRow.best_shift_factor);
end

smallestShiftRow = bestFiniteRowByAbs(metricTbl, 'best_shift_log10_tw_decades');
if ~isempty(smallestShiftRow)
    lines(end + 1) = sprintf('- Smallest inferred clock offset: `T_p = %.0f K` with `|shift| = %.3f` decades and normalized RMSE `%.3f`.', ...
        smallestShiftRow.Tp, abs(smallestShiftRow.best_shift_log10_tw_decades), smallestShiftRow.best_shift_rmse);
end

largestShiftRow = worstFiniteRowByAbs(metricTbl, 'best_shift_log10_tw_decades');
if ~isempty(largestShiftRow)
    lines(end + 1) = sprintf('- Largest inferred clock offset: `T_p = %.0f K` with `|shift| = %.3f` decades and normalized RMSE `%.3f`.', ...
        largestShiftRow.Tp, abs(largestShiftRow.best_shift_log10_tw_decades), largestShiftRow.best_shift_rmse);
end

lines(end + 1) = "";
lines(end + 1) = "## Per-Tp Metrics";
lines(end + 1) = "| T_p (K) | paired points | FM points | r raw | r normalized | shift (decades) | shift factor | best-shift RMSE |";
lines(end + 1) = "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |";
for i = 1:height(metricTbl)
    lines(end + 1) = sprintf('| %.0f | %s | %s | %s | %s | %s | %s | %s |', ...
        metricTbl.Tp(i), ...
        formatScalar(metricTbl.n_common_points(i), '%.0f'), ...
        formatScalar(metricTbl.n_fm_points(i), '%.0f'), ...
        formatScalar(metricTbl.pearson_r_raw(i), '%.3f'), ...
        formatScalar(metricTbl.pearson_r_normalized(i), '%.3f'), ...
        formatScalar(metricTbl.best_shift_log10_tw_decades(i), '%.3f'), ...
        formatScalar(metricTbl.best_shift_factor(i), '%.2f'), ...
        formatScalar(metricTbl.best_shift_rmse(i), '%.3f'));
end

lines(end + 1) = "";
lines(end + 1) = "## Outputs";
lines(end + 1) = '- `figures/dip_vs_tw.png`';
lines(end + 1) = '- `figures/fm_vs_tw.png`';
lines(end + 1) = '- `figures/normalized_component_comparison.png`';
lines(end + 1) = '- `tables/component_correlation_vs_Tp.csv`';
lines(end + 1) = '- `reports/aging_component_clock_report.md`';

reportText = strjoin(lines, newline);
end

function summaryLine = summarizeClockAgreement(metricTbl)
validRows = metricTbl(isfinite(metricTbl.pearson_r_normalized) & ...
    isfinite(metricTbl.best_shift_log10_tw_decades), :);

if isempty(validRows)
    summaryLine = '- There are not enough paired finite values to judge a shared aging clock.';
    return;
end

medianCorr = median(validRows.pearson_r_normalized, 'omitnan');
medianAbsShift = median(abs(validRows.best_shift_log10_tw_decades), 'omitnan');

if medianCorr >= 0.8 && medianAbsShift <= 0.15
    summaryLine = '- Across temperatures with usable `FM_abs`, the normalized curves stay closely aligned, which is consistent with a shared aging clock at the present resolution.';
elseif medianCorr >= 0.5 && medianAbsShift <= 0.5
    summaryLine = '- The two components show partial similarity after normalization, but the inferred shift changes with `T_p`; this supports only a loose shared clock, not a single universal one.';
else
    summaryLine = '- The normalized `Dip_depth` and `FM_abs` curves do not align consistently across `T_p`, so this dataset does not support a single common aging clock for both components.';
end
end

function row = bestFiniteRow(metricTbl, fieldName, direction)
validMask = isfinite(metricTbl.(fieldName));
if ~any(validMask)
    row = [];
    return;
end

subTbl = metricTbl(validMask, :);
subTbl = sortrows(subTbl, fieldName, direction);
row = subTbl(1, :);
end

function row = bestFiniteRowByAbs(metricTbl, fieldName)
validMask = isfinite(metricTbl.(fieldName));
if ~any(validMask)
    row = [];
    return;
end

subTbl = metricTbl(validMask, :);
[~, idx] = min(abs(subTbl.(fieldName)));
row = subTbl(idx, :);
end

function row = worstFiniteRowByAbs(metricTbl, fieldName)
validMask = isfinite(metricTbl.(fieldName));
if ~any(validMask)
    row = [];
    return;
end

subTbl = metricTbl(validMask, :);
[~, idx] = max(abs(subTbl.(fieldName)));
row = subTbl(idx, :);
end

function textOut = formatScalar(value, fmt)
if ~isfinite(value)
    textOut = 'NA';
else
    textOut = sprintf(fmt, value);
end
end

function zipPath = createReviewZip(run_output_dir)
reviewDir = fullfile(run_output_dir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end

zipPath = fullfile(reviewDir, 'aging_component_clock_test_outputs.zip');
if isfile(zipPath)
    delete(zipPath);
end

zipInputs = collectRelativeOutputFiles(run_output_dir);
assert(~isempty(zipInputs), 'No output files were found to package.');
zip(zipPath, cellstr(zipInputs), run_output_dir);
end

function files = collectRelativeOutputFiles(run_output_dir)
targetDirs = {'figures', 'tables', 'reports'};
files = strings(0, 1);

for i = 1:numel(targetDirs)
    thisDir = fullfile(run_output_dir, targetDirs{i});
    if exist(thisDir, 'dir') ~= 7
        continue;
    end
    files = [files; collectFilesRecursively(thisDir, run_output_dir)]; %#ok<AGROW>
end
end

function files = collectFilesRecursively(targetDir, rootDir)
entries = dir(targetDir);
files = strings(0, 1);

for i = 1:numel(entries)
    name = string(entries(i).name);
    if name == "." || name == ".."
        continue;
    end

    fullPath = fullfile(entries(i).folder, char(name));
    if entries(i).isdir
        files = [files; collectFilesRecursively(fullPath, rootDir)]; %#ok<AGROW>
    else
        files(end + 1, 1) = string(relativePathWithinRun(fullPath, rootDir)); %#ok<AGROW>
    end
end
end

function relPath = relativePathWithinRun(fullPath, rootDir)
fullPath = char(string(fullPath));
rootDir = char(string(rootDir));

if startsWith(lower(fullPath), lower(rootDir))
    relPath = fullPath(numel(rootDir) + 2:end);
else
    relPath = fullPath;
end
end
function paths = saveFigureOutputs(fig, baseName, run_output_dir)
figuresDir = fullfile(run_output_dir, 'figures');
if exist(figuresDir, 'dir') ~= 7
    mkdir(figuresDir);
end

paths = struct();
paths.pdf = fullfile(figuresDir, [baseName '.pdf']);
paths.png = fullfile(figuresDir, [baseName '.png']);
paths.fig = fullfile(figuresDir, [baseName '.fig']);

set(fig, 'Color', 'w');
exportgraphics(fig, paths.pdf, 'ContentType', 'vector');
exportgraphics(fig, paths.png, 'Resolution', 300);
savefig(fig, paths.fig);

fprintf('Saved figure PDF: %s\n', paths.pdf);
fprintf('Saved figure PNG: %s\n', paths.png);
fprintf('Saved figure FIG: %s\n', paths.fig);
end


