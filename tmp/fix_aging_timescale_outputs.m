function fix_aging_timescale_outputs()
repoRoot = 'C:\Dev\matlab-functions';
runDir = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_2026_03_12_223709_aging_timescale_extraction');
datasetPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_2026_03_12_211204_aging_dataset_build', 'tables', 'aging_observable_dataset.csv');

addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

T = readtable(fullfile(runDir, 'tables', 'tau_vs_Tp.csv'), 'TextType', 'string');
T = normalizeTauTable(T);
T = recomputeConsensus(T);
save_run_table(T, 'tau_vs_Tp.csv', runDir);

fig = makeTauFigure(T);
save_run_figure(fig, 'tau_vs_Tp', runDir);
close(fig);

dataTbl = loadObservableDataset(datasetPath);
reportText = buildReportText(runDir, datasetPath, dataTbl, T);
save_run_report(reportText, 'aging_timescale_extraction_report.md', runDir);

zipPath = fullfile(runDir, 'review', 'aging_timescale_extraction.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);

fprintf('Updated run: %s\n', runDir);
end

function T = normalizeTauTable(T)
stringVars = {'tau_logistic_status', 'tau_stretched_status', 'tau_half_range_status', 'tau_consensus_methods', 'source_run'};
for i = 1:numel(stringVars)
    vn = stringVars{i};
    if ismember(vn, T.Properties.VariableNames)
        T.(vn) = string(T.(vn));
    end
end
end

function T = recomputeConsensus(T)
T.tau_effective_seconds(:) = NaN;
T.tau_consensus_method_count(:) = 0;
T.tau_consensus_methods(:) = "";
T.tau_method_spread_decades(:) = NaN;

for i = 1:height(T)
    if T.tau_half_range_status(i) ~= "ok" || ~isfinite(T.tau_half_range_seconds(i)) || T.tau_half_range_seconds(i) <= 0
        continue;
    end

    tauVals = T.tau_half_range_seconds(i);
    names = "half_range";

    if logical(T.tau_logistic_trusted(i)) && isfinite(T.tau_logistic_half_seconds(i)) && T.tau_logistic_half_seconds(i) > 0
        tauVals(end + 1, 1) = T.tau_logistic_half_seconds(i); %#ok<AGROW>
        names(end + 1, 1) = "logistic_log_tw"; %#ok<AGROW>
    end

    if logical(T.tau_stretched_trusted(i)) && isfinite(T.tau_stretched_half_seconds(i)) && T.tau_stretched_half_seconds(i) > 0
        tauVals(end + 1, 1) = T.tau_stretched_half_seconds(i); %#ok<AGROW>
        names(end + 1, 1) = "stretched_exp"; %#ok<AGROW>
    end

    logTau = log10(tauVals);
    T.tau_effective_seconds(i) = 10.^median(logTau);
    T.tau_consensus_method_count(i) = numel(tauVals);
    T.tau_consensus_methods(i) = strjoin(names.', ', ');
    T.tau_method_spread_decades(i) = max(logTau) - min(logTau);
end
end

function dataTbl = loadObservableDataset(datasetPath)
fid = fopen(datasetPath, 'r');
assert(fid >= 0, 'Failed to open dataset: %s', datasetPath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
headerLine = fgetl(fid);
assert(ischar(headerLine), 'Dataset is empty: %s', datasetPath);
cols = textscan(fid, '%q%q%q%q%q', 'Delimiter', ',', 'CollectOutput', false);
dataTbl = table( ...
    str2double(cols{1}), ...
    str2double(cols{2}), ...
    str2double(cols{3}), ...
    str2double(cols{4}), ...
    string(cols{5}), ...
    'VariableNames', {'Tp', 'tw', 'Dip_depth', 'FM_abs', 'source_run'});
dataTbl = sortrows(dataTbl, {'Tp', 'tw'});
end

function fig = makeTauFigure(T)
fig = create_figure('Visible', 'off', 'Position', [2 2 12.0 8.0]);
ax = axes(fig);
hold(ax, 'on');

plot(ax, T.Tp, T.tau_logistic_half_seconds, '-o', ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 5.5, 'LineWidth', 2.0, ...
    'DisplayName', 'Logistic fit in log(t_w)');
plot(ax, T.Tp, T.tau_stretched_half_seconds, '-s', ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 5.5, 'LineWidth', 2.0, ...
    'DisplayName', 'Stretched-exp half time');
plot(ax, T.Tp, T.tau_half_range_seconds, '-^', ...
    'Color', [0.00 0.62 0.45], 'MarkerFaceColor', [0.00 0.62 0.45], ...
    'MarkerSize', 5.5, 'LineWidth', 2.0, ...
    'DisplayName', 'Direct half-range');
plot(ax, T.Tp, T.tau_effective_seconds, '-d', ...
    'Color', [0.00 0.00 0.00], 'MarkerFaceColor', [0.00 0.00 0.00], ...
    'MarkerSize', 5.5, 'LineWidth', 2.4, ...
    'DisplayName', 'Consensus');

fragileMask = T.fragile_low_point_count & isfinite(T.tau_logistic_half_seconds);
if any(fragileMask)
    plot(ax, T.Tp(fragileMask), T.tau_logistic_half_seconds(fragileMask), 'ko', ...
        'MarkerSize', 8, 'LineWidth', 1.2, 'MarkerFaceColor', 'w', ...
        'DisplayName', 'Fragile T_p (3 points)');
end

set(ax, 'YScale', 'log');
xlabel(ax, 'Stopping temperature T_p (K)');
ylabel(ax, 'Effective aging timescale \tau (s)');
title(ax, 'Aging timescale estimates vs stopping temperature');
set(ax, 'FontSize', 9, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off');
legend(ax, 'Location', 'eastoutside');
end

function reportText = buildReportText(runDir, datasetPath, dataTbl, T)
lines = strings(0, 1);
lines(end + 1) = "# Aging timescale extraction";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
lines(end + 1) = sprintf("Run root: `%s`", string(runDir));
lines(end + 1) = sprintf("Input dataset: `%s`", string(datasetPath));
lines(end + 1) = "";
lines(end + 1) = "## Dataset summary";
lines(end + 1) = sprintf("- Total rows: %d.", height(dataTbl));
lines(end + 1) = sprintf("- Distinct stopping temperatures: %d (`%s` K).", numel(unique(dataTbl.Tp)), strjoin(string(unique(dataTbl.Tp).'), ", "));
lines(end + 1) = sprintf("- Waiting-time window: %.3g s to %.3g s.", min(dataTbl.tw), max(dataTbl.tw));
lines(end + 1) = "- Fragile high-T_p cases with only 3 points: `30, 34` K.";
lines(end + 1) = "";
lines(end + 1) = "## Methods";
lines(end + 1) = "- `Logistic fit in log(t_w)`: fit a sigmoid in `log10(t_w)` and report its half-rise time.";
lines(end + 1) = "- `Stretched exponential`: fit `Dip_depth = y_0 + \Delta (1 - exp(-(t_w / \tau_c)^{\beta}))` and convert it to a half-rise time.";
lines(end + 1) = "- `Direct half-range`: interpolate the earliest upward crossing of half the rise from the shortest-time point to the observed peak.";
lines(end + 1) = "- `Consensus`: reported only when the direct half-range is resolved; it is the median of the available method estimates in log-time.";
lines(end + 1) = "";
lines(end + 1) = "## Main findings";
valid = T(isfinite(T.tau_effective_seconds), :);
[~, minIdx] = min(valid.tau_effective_seconds);
[~, maxIdx] = max(valid.tau_effective_seconds);
lines(end + 1) = sprintf("- The shortest resolved consensus timescale appears at `T_p = %g K` with `\\tau \\approx %.3g s`.", valid.Tp(minIdx), valid.tau_effective_seconds(minIdx));
lines(end + 1) = sprintf("- The longest resolved consensus timescale appears at `T_p = %g K` with `\\tau \\approx %.3g s`.", valid.Tp(maxIdx), valid.tau_effective_seconds(maxIdx));
lines(end + 1) = "- `30 K` and `34 K` remain unresolved in the consensus curve because the direct Dip-depth half-range is not observed within the sampled waiting-time window.";
lines(end + 1) = "- Across the resolved `6-26 K` range, the effective tau grows from a few seconds up to roughly `10^2 s`, with the clearest agreement between methods around `18-22 K`.";
lines(end + 1) = "";
lines(end + 1) = "## Per-T_p summary";
for i = 1:height(T)
    lines(end + 1) = sprintf(['- `T_p = %g K`: logistic `%.3g s` (%s), stretched `%.3g s` (%s, ' ...
        '\\beta = %.2f), direct half-range `%.3g s` (%s), consensus `%.3g s` from `%s`.'], ...
        T.Tp(i), T.tau_logistic_half_seconds(i), T.tau_logistic_status(i), ...
        T.tau_stretched_half_seconds(i), T.tau_stretched_status(i), T.tau_stretched_beta(i), ...
        T.tau_half_range_seconds(i), T.tau_half_range_status(i), ...
        T.tau_effective_seconds(i), T.tau_consensus_methods(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Method comparison";
lines(end + 1) = sprintf("- Logistic vs direct half-range: %d overlapping T_p values, median |\\Delta log_{10} \\tau| = %.3f decades.", pairCount(T.tau_logistic_half_seconds, T.tau_half_range_seconds), pairMedian(T.tau_logistic_half_seconds, T.tau_half_range_seconds));
lines(end + 1) = sprintf("- Stretched-exp vs direct half-range: %d overlapping T_p values, median |\\Delta log_{10} \\tau| = %.3f decades.", pairCount(T.tau_stretched_half_seconds, T.tau_half_range_seconds), pairMedian(T.tau_stretched_half_seconds, T.tau_half_range_seconds));
lines(end + 1) = sprintf("- Logistic vs stretched-exp: %d overlapping T_p values, median |\\Delta log_{10} \\tau| = %.3f decades.", pairCount(T.tau_logistic_half_seconds, T.tau_stretched_half_seconds), pairMedian(T.tau_logistic_half_seconds, T.tau_stretched_half_seconds));
lines(end + 1) = "- The high-T_p fit-only cases (`30, 34 K`) disagree by many decades and should be treated as unresolved rather than as genuine long aging times.";
lines(end + 1) = "";
lines(end + 1) = "## Cautions";
lines(end + 1) = "- `30 K` and `34 K` are structurally fragile because only 3 waiting times are available and the shortest sampled point is already the local maximum.";
lines(end + 1) = "- `6 K`, `10 K`, and `26 K` show late-time downturns after an earlier peak, so the monotone fit models summarize the buildup only approximately.";
lines(end + 1) = "- These taus are effective timescales extracted from the saved Dip-depth observable only; they are not a claim of a unique microscopic relaxation law.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- Number of curves in `Dip_depth_vs_tw_by_Tp`: 8, so a `parula` colormap plus labeled colorbar is used; dashed lines mark 3-point fragile T_p values.";
lines(end + 1) = "- Number of curves in `tau_vs_Tp`: 4 method/summary curves, so an explicit legend is used instead of a colormap.";
lines(end + 1) = "- Colormaps: `parula` for the multi-T_p Dip-depth sweep; no colormap for the tau comparison figure.";
lines(end + 1) = "- Smoothing applied: none; all methods fit or interpolate the saved scalar Dip-depth points directly.";
lines(end + 1) = "- Justification: the figure set compares the observed Dip-depth growth law first and then the method-dependent tau extraction.";
lines(end + 1) = "";
lines(end + 1) = "## Exported artifacts";
lines(end + 1) = "- `tables/tau_vs_Tp.csv`";
lines(end + 1) = "- `figures/Dip_depth_vs_tw_by_Tp.png`";
lines(end + 1) = "- `figures/tau_vs_Tp.png`";
lines(end + 1) = "- `reports/aging_timescale_extraction_report.md`";
lines(end + 1) = "- `review/aging_timescale_extraction.zip`";
reportText = strjoin(lines, newline);
end

function n = pairCount(a, b)
mask = isfinite(a) & a > 0 & isfinite(b) & b > 0;
n = nnz(mask);
end

function m = pairMedian(a, b)
mask = isfinite(a) & a > 0 & isfinite(b) & b > 0;
if ~any(mask)
    m = NaN;
    return;
end
m = median(abs(log10(a(mask)) - log10(b(mask))), 'omitnan');
end
