function out = aging_log_time_scaling_test()
% aging_log_time_scaling_test
% Test whether Dip_depth follows logarithmic aging:
%   Dip_depth(Tp, tw) ~= A(Tp) + B(Tp) log(tw)
%
% Inputs are read from the canonical aging observable dataset build run.
% Outputs are written into a new run-scoped directory under results/aging/runs.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

datasetPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_211204_aging_dataset_build', 'tables', 'aging_observable_dataset.csv');
assert(isfile(datasetPath), 'Dataset not found: %s', datasetPath);

cfgRun = struct();
cfgRun.runLabel = 'aging_log_time_scaling_test';
cfgRun.datasetName = 'aging_observable_dataset';
runCtx = createRunContext('aging', cfgRun);
runDir = runCtx.run_dir;

fprintf('Aging log-time scaling test run root:\n%s\n', runDir);
fprintf('Source dataset:\n%s\n', datasetPath);

dataTbl = read_dataset_csv(datasetPath);
fitTbl = fit_log_scaling_by_tp(dataTbl);

save_run_table(fitTbl, 'log_slope_vs_Tp.csv', runDir);

figByTp = make_by_tp_figure(dataTbl, fitTbl);
save_run_figure(figByTp, 'Dip_depth_vs_log_tw_by_Tp', runDir);
close(figByTp);

figSlope = make_slope_figure(fitTbl);
save_run_figure(figSlope, 'log_slope_vs_Tp', runDir);
close(figSlope);

reportText = build_report_text(runDir, datasetPath, dataTbl, fitTbl);
reportPath = save_run_report(reportText, 'aging_log_scaling_report.md', runDir);
zipPath = create_review_zip(runDir);

fprintf('Aging log-time scaling test complete.\n');
fprintf('Run root: %s\n', runDir);
fprintf('Review ZIP: %s\n', zipPath);

out = struct();
out.run_dir = runDir;
out.dataset_path = datasetPath;
out.fit_table = fitTbl;
out.report_path = reportPath;
out.zip_path = zipPath;
end

function tbl = read_dataset_csv(datasetPath)
fid = fopen(datasetPath, 'r');
if fid == -1
    error('Failed to open dataset CSV: %s', datasetPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

headerLine = fgetl(fid); %#ok<NASGU>
assert(ischar(headerLine), 'Dataset file is empty: %s', datasetPath);

raw = textscan(fid, '%q%q%q%q%q', 'Delimiter', ',', 'ReturnOnError', false);
assert(numel(raw) == 5, 'Unexpected dataset format in %s', datasetPath);

tbl = table();
tbl.Tp = str2double(raw{1});
tbl.tw = str2double(raw{2});
tbl.Dip_depth = str2double(raw{3});
tbl.FM_abs = str2double(raw{4});
tbl.source_run = string(raw{5});
tbl = normalize_dataset_table(tbl);
end

function tbl = normalize_dataset_table(tbl)
requiredVars = {'Tp', 'tw', 'Dip_depth'};
for i = 1:numel(requiredVars)
    assert(ismember(requiredVars{i}, tbl.Properties.VariableNames), ...
        'Dataset is missing required column: %s', requiredVars{i});
end

tbl.Tp = to_numeric_column(tbl.Tp);
tbl.tw = to_numeric_column(tbl.tw);
tbl.Dip_depth = to_numeric_column(tbl.Dip_depth);

if ismember('source_run', tbl.Properties.VariableNames)
    tbl.source_run = string(tbl.source_run);
else
    tbl.source_run = repmat("", height(tbl), 1);
end

tbl = sortrows(tbl, {'Tp', 'tw'}, {'ascend', 'ascend'});
end

function values = to_numeric_column(valuesIn)
if isnumeric(valuesIn)
    values = double(valuesIn);
    return;
end
if iscell(valuesIn)
    values = str2double(string(valuesIn));
    return;
end
if isstring(valuesIn) || ischar(valuesIn) || iscategorical(valuesIn)
    values = str2double(string(valuesIn));
    return;
end
error('Unsupported column type for numeric conversion: %s', class(valuesIn));
end

function fitTbl = fit_log_scaling_by_tp(dataTbl)
tpValues = unique(dataTbl.Tp(isfinite(dataTbl.Tp)));
tpValues = sort(tpValues(:));

rows = repmat(struct( ...
    'Tp', NaN, ...
    'n_total_points', NaN, ...
    'n_points_used', NaN, ...
    'n_missing_or_invalid', NaN, ...
    'tw_min_seconds', NaN, ...
    'tw_max_seconds', NaN, ...
    'intercept_A', NaN, ...
    'slope_B', NaN, ...
    'R_squared', NaN, ...
    'rmse', NaN, ...
    'log_base', "", ...
    'fit_status', "", ...
    'source_runs', ""), 0, 1);

for i = 1:numel(tpValues)
    tp = tpValues(i);
    subTbl = dataTbl(dataTbl.Tp == tp, :);
    validMask = isfinite(subTbl.tw) & (subTbl.tw > 0) & isfinite(subTbl.Dip_depth);
    x = log(subTbl.tw(validMask));
    y = subTbl.Dip_depth(validMask);

    intercept = NaN;
    slope = NaN;
    rSquared = NaN;
    rmse = NaN;
    fitStatus = "ok";

    if nnz(validMask) < 2
        fitStatus = "insufficient_points";
    elseif numel(unique(x)) < 2
        fitStatus = "degenerate_log_tw";
    else
        coeffs = polyfit(x, y, 1);
        slope = coeffs(1);
        intercept = coeffs(2);
        yHat = polyval(coeffs, x);
        rmse = sqrt(mean((y - yHat).^2, 'omitnan'));
        rSquared = compute_r_squared(y, yHat);
    end

    twValid = subTbl.tw(validMask);
    rows(end + 1, 1) = struct( ... %#ok<AGROW>
        'Tp', tp, ...
        'n_total_points', height(subTbl), ...
        'n_points_used', nnz(validMask), ...
        'n_missing_or_invalid', height(subTbl) - nnz(validMask), ...
        'tw_min_seconds', safe_min(twValid), ...
        'tw_max_seconds', safe_max(twValid), ...
        'intercept_A', intercept, ...
        'slope_B', slope, ...
        'R_squared', rSquared, ...
        'rmse', rmse, ...
        'log_base', "natural", ...
        'fit_status', fitStatus, ...
        'source_runs', join(unique(subTbl.source_run), '; '));
end

fitTbl = struct2table(rows);
fitTbl = sortrows(fitTbl, 'Tp', 'ascend');
end

function value = compute_r_squared(y, yHat)
ssRes = sum((y - yHat).^2, 'omitnan');
ssTot = sum((y - mean(y, 'omitnan')).^2, 'omitnan');
if ssTot <= eps
    value = double(ssRes <= eps);
else
    value = 1 - (ssRes / ssTot);
end
end

function value = safe_min(values)
if isempty(values)
    value = NaN;
else
    value = min(values, [], 'omitnan');
end
end

function value = safe_max(values)
if isempty(values)
    value = NaN;
else
    value = max(values, [], 'omitnan');
end
end

function fig = make_by_tp_figure(dataTbl, fitTbl)
nTp = height(fitTbl);
nCols = min(4, max(1, nTp));
nRows = ceil(nTp / nCols);
colors = lines(max(nTp, 1));

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1800 880]);
tlo = tiledlayout(fig, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:nTp
    ax = nexttile(tlo, i);
    hold(ax, 'on');

    tp = fitTbl.Tp(i);
    subTbl = dataTbl(dataTbl.Tp == tp, :);
    validMask = isfinite(subTbl.tw) & (subTbl.tw > 0) & isfinite(subTbl.Dip_depth);
    x = log(subTbl.tw(validMask));
    y = subTbl.Dip_depth(validMask);

    scatter(ax, x, y, 42, colors(i, :), 'filled', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.6);

    if strcmp(fitTbl.fit_status(i), "ok")
        xLine = linspace(min(x), max(x), 200);
        yLine = fitTbl.intercept_A(i) + fitTbl.slope_B(i) * xLine;
        plot(ax, xLine, yLine, '-', 'Color', colors(i, :), 'LineWidth', 1.8);
        annotationText = sprintf('B = %.3e\nR^2 = %.4f\nn = %d', ...
            fitTbl.slope_B(i), fitTbl.R_squared(i), fitTbl.n_points_used(i));
    else
        annotationText = sprintf('status: %s\nn = %d', ...
            char(fitTbl.fit_status(i)), fitTbl.n_points_used(i));
    end

    title(ax, sprintf('T_p = %g K', tp));
    xlabel(ax, 'log(t_w / s)');
    ylabel(ax, 'Dip depth');
    grid(ax, 'on');
    set(ax, 'FontSize', 9, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
    text(ax, 0.04, 0.96, annotationText, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
        'FontSize', 8, 'BackgroundColor', [1 1 1], 'Margin', 4);
end

title(tlo, 'Dip depth vs log(t_w) by T_p');
end

function fig = make_slope_figure(fitTbl)
validMask = strcmp(fitTbl.fit_status, "ok") & isfinite(fitTbl.slope_B);

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 980 560]);
ax = axes(fig);
hold(ax, 'on');

if any(validMask)
    plot(ax, fitTbl.Tp(validMask), fitTbl.slope_B(validMask), '-', ...
        'Color', [0.35 0.35 0.35], 'LineWidth', 1.2);
    scatter(ax, fitTbl.Tp(validMask), fitTbl.slope_B(validMask), 80, ...
        fitTbl.R_squared(validMask), 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.7);
    colormap(ax, parula(256));
    cb = colorbar(ax);
    cb.Label.String = 'R^2';

    for i = find(validMask).'
        text(ax, fitTbl.Tp(i), fitTbl.slope_B(i), sprintf('  %.4f', fitTbl.R_squared(i)), ...
            'FontSize', 8, 'VerticalAlignment', 'bottom', 'Color', [0.1 0.1 0.1]);
    end
end

if any(~validMask)
    yMissing = zeros(nnz(~validMask), 1);
    scatter(ax, fitTbl.Tp(~validMask), yMissing, 70, 'x', 'LineWidth', 1.6, ...
        'MarkerEdgeColor', [0.8 0.1 0.1], 'DisplayName', 'No valid fit');
end

yline(ax, 0, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.0);
xlabel(ax, 'T_p (K)');
ylabel(ax, 'B(T_p) for A + B log(t_w)');
title(ax, 'Log-time aging slope vs T_p');
grid(ax, 'on');
set(ax, 'FontSize', 10, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
end

function txt = build_report_text(runDir, datasetPath, dataTbl, fitTbl)
nowText = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
validRowMask = isfinite(dataTbl.tw) & (dataTbl.tw > 0) & isfinite(dataTbl.Dip_depth);
fitValidMask = strcmp(fitTbl.fit_status, "ok") & isfinite(fitTbl.slope_B);

lines = strings(0, 1);
lines(end + 1) = "# Aging log-time scaling test";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", nowText);
lines(end + 1) = sprintf("Run root: `%s`", runDir);
lines(end + 1) = "";
lines(end + 1) = "## Model";
lines(end + 1) = "- Tested relation: `Dip_depth(T_p, t_w) ~= A(T_p) + B(T_p) log(t_w)`.";
lines(end + 1) = "- `log` denotes the natural logarithm and `t_w` is measured in seconds.";
lines(end + 1) = sprintf("- Source dataset: `%s`", datasetPath);
lines(end + 1) = "- Missing or invalid points (`NaN` Dip_depth or non-positive `t_w`) were excluded independently for each `T_p` fit.";
lines(end + 1) = "";
lines(end + 1) = "## Dataset summary";
lines(end + 1) = sprintf("- Total dataset rows: %d", height(dataTbl));
lines(end + 1) = sprintf("- Valid rows used by the per-`T_p` fits: %d", nnz(validRowMask));
lines(end + 1) = sprintf("- Distinct `T_p` values analyzed: %d", height(fitTbl));

if any(fitValidMask)
    validIdx = find(fitValidMask);
    [~, bestIdxLocal] = max(fitTbl.R_squared(fitValidMask));
    bestIdx = validIdx(bestIdxLocal);

    [~, steepIdxLocal] = max(abs(fitTbl.slope_B(fitValidMask)));
    steepIdx = validIdx(steepIdxLocal);

    nPositive = nnz(fitTbl.slope_B(fitValidMask) > 0);
    nNegative = nnz(fitTbl.slope_B(fitValidMask) < 0);

    lines(end + 1) = "";
    lines(end + 1) = "## Highlights";
    lines(end + 1) = sprintf("- Best linear-in-log fit: `T_p = %g K` with `R^2 = %.4f`.", ...
        fitTbl.Tp(bestIdx), fitTbl.R_squared(bestIdx));
    lines(end + 1) = sprintf("- Largest-magnitude slope: `T_p = %g K` with `B = %.6g`.", ...
        fitTbl.Tp(steepIdx), fitTbl.slope_B(steepIdx));
    lines(end + 1) = sprintf("- Positive slopes: %d; negative slopes: %d.", nPositive, nNegative);
end

lines(end + 1) = "";
lines(end + 1) = "## Per-Tp fit summary";
lines(end + 1) = "| Tp (K) | n used | A | B | R^2 | RMSE | Status |";
lines(end + 1) = "| ---: | ---: | ---: | ---: | ---: | ---: | :--- |";

for i = 1:height(fitTbl)
    lines(end + 1) = sprintf("| %.0f | %d | %.6g | %.6g | %.4f | %.6g | %s |", ...
        fitTbl.Tp(i), fitTbl.n_points_used(i), fitTbl.intercept_A(i), ...
        fitTbl.slope_B(i), fitTbl.R_squared(i), fitTbl.rmse(i), char(fitTbl.fit_status(i)));
end

lines(end + 1) = "";
lines(end + 1) = "## Outputs";
lines(end + 1) = "- `tables/log_slope_vs_Tp.csv`";
lines(end + 1) = "- `figures/Dip_depth_vs_log_tw_by_Tp.png`";
lines(end + 1) = "- `figures/log_slope_vs_Tp.png`";
lines(end + 1) = "- `review/aging_log_time_scaling_test.zip`";
lines(end + 1) = "";
lines(end + 1) = "## Notes";
lines(end + 1) = "- MATLAB figure exports also include `.pdf` and `.fig` companions via the repository save helper.";
lines(end + 1) = "- `T_p = 30 K` and `34 K` each use three waiting-time points because the source dataset has no `t_w = 3 s` entry there.";

txt = strjoin(lines, newline);
end

function zipPath = create_review_zip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end

zipPath = fullfile(reviewDir, 'aging_log_time_scaling_test.zip');
if isfile(zipPath)
    delete(zipPath);
end

files = [collect_files(fullfile(runDir, 'tables')); ...
    collect_files(fullfile(runDir, 'figures')); ...
    collect_files(fullfile(runDir, 'reports'))];
zip(zipPath, files);
end

function files = collect_files(folderPath)
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
