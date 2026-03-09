% cross_experiment_observables
% Entry point for cross-experiment observable comparison.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
toolsDir = fullfile(repoRoot, 'tools');
addpath(toolsDir);

resultsRoot = fullfile(repoRoot, 'results');
outDir = fullfile(resultsRoot, 'cross_experiment', 'observables');
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

allObs = load_observables(resultsRoot);
if isempty(allObs)
    fprintf('No observables were found under: %s\n', resultsRoot);
    return;
end

allObs = allObs(isfinite(allObs.temperature) & isfinite(allObs.value), :);
if isempty(allObs)
    fprintf('No finite temperature/value rows found in aggregated observables.\n');
    return;
end

aggTbl = groupsummary(allObs, {'experiment','observable','temperature'}, 'mean', 'value');
aggTbl.Properties.VariableNames{'mean_value'} = 'value_mean';

writetable(allObs, fullfile(outDir, 'cross_experiment_observables_all.csv'));
writetable(aggTbl, fullfile(outDir, 'cross_experiment_observables_mean_by_T.csv'));

experiments = unique(aggTbl.experiment);
for i = 1:numel(experiments)
    expName = experiments(i);
    expTbl = aggTbl(aggTbl.experiment == expName, {'temperature','observable','value_mean'});
    pivotTbl = unstack(expTbl, 'value_mean', 'observable');
    pivotTbl = sortrows(pivotTbl, 'temperature');
    outName = sprintf('pivot_%s_temperature_vs_observable.csv', sanitizeToken(expName));
    writetable(pivotTbl, fullfile(outDir, outName));
end

figCurves = figure('Color','w','Visible','off','Position',[100 100 950 600]);
axCurves = axes(figCurves);
hold(axCurves, 'on');

pairs = unique(aggTbl(:, {'experiment','observable'}));
colors = lines(height(pairs));
legendText = strings(height(pairs), 1);

for i = 1:height(pairs)
    expName = pairs.experiment(i);
    obsName = pairs.observable(i);
    curve = aggTbl(aggTbl.experiment == expName & aggTbl.observable == obsName, :);
    curve = sortrows(curve, 'temperature');

    plot(axCurves, curve.temperature, curve.value_mean, '-', 'LineWidth', 1.5, ...
        'Color', colors(i,:));
    legendText(i) = expName + " | " + obsName;
end

xlabel(axCurves, 'Temperature (K)');
ylabel(axCurves, 'Mean observable value');
title(axCurves, 'Cross-experiment observable curves');
grid(axCurves, 'on');
legend(axCurves, cellstr(legendText), 'Location', 'eastoutside', 'Interpreter', 'none');

saveas(figCurves, fullfile(outDir, 'cross_experiment_observable_curves.png'));
close(figCurves);

figPairs = figure('Color','w','Visible','off','Position',[100 100 1100 500]);
tl = tiledlayout(figPairs, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

plotPairComparison(nexttile(tl), aggTbl, "switching", "width_I", "relaxation", "log_slope", ...
    "Switching width_I(T) vs Relaxation log_slope(T)");
plotPairComparison(nexttile(tl), aggTbl, "switching", "S_peak", "aging", "Dip_depth", ...
    "Switching S_peak(T) vs Aging Dip_depth(T)");

saveas(figPairs, fullfile(outDir, 'cross_experiment_pair_examples.png'));
close(figPairs);

fprintf('Cross-experiment observable outputs written to: %s\n', outDir);

function token = sanitizeToken(v)
token = lower(char(string(v)));
token = regexprep(token, '[^a-zA-Z0-9_]+', '_');
token = regexprep(token, '_+', '_');
token = regexprep(token, '^_|_$', '');
if isempty(token)
    token = 'unnamed';
end
end

function plotPairComparison(ax, aggTbl, expA, obsA, expB, obsB, ttl)
curveA = aggTbl(aggTbl.experiment == expA & aggTbl.observable == obsA, {'temperature','value_mean'});
curveB = aggTbl(aggTbl.experiment == expB & aggTbl.observable == obsB, {'temperature','value_mean'});

if isempty(curveA) || isempty(curveB)
    axis(ax, 'off');
    text(ax, 0.5, 0.5, sprintf('Missing data for\n%s vs %s', obsA, obsB), ...
        'HorizontalAlignment', 'center', 'Interpreter', 'none');
    title(ax, ttl, 'Interpreter', 'none');
    return;
end

curveA.temperature_round = round(curveA.temperature);
curveB.temperature_round = round(curveB.temperature);

curveA = groupsummary(curveA, 'temperature_round', 'mean', 'value_mean');
curveB = groupsummary(curveB, 'temperature_round', 'mean', 'value_mean');

curveA.Properties.VariableNames{'temperature_round'} = 'temperature';
curveB.Properties.VariableNames{'temperature_round'} = 'temperature';
curveA.Properties.VariableNames{'mean_value_mean'} = 'valueA';
curveB.Properties.VariableNames{'mean_value_mean'} = 'valueB';

joined = innerjoin(curveA(:, {'temperature','valueA'}), curveB(:, {'temperature','valueB'}), ...
    'Keys', 'temperature');
joined = sortrows(joined, 'temperature');

if isempty(joined)
    axis(ax, 'off');
    text(ax, 0.5, 0.5, 'No overlapping temperatures after rounding', ...
        'HorizontalAlignment', 'center');
    title(ax, ttl, 'Interpreter', 'none');
    return;
end

yyaxis(ax, 'left');
plot(ax, joined.temperature, joined.valueA, '-o', 'LineWidth', 1.5);
ylabel(ax, sprintf('%s | %s', expA, obsA), 'Interpreter', 'none');

yyaxis(ax, 'right');
plot(ax, joined.temperature, joined.valueB, '-s', 'LineWidth', 1.5);
ylabel(ax, sprintf('%s | %s', expB, obsB), 'Interpreter', 'none');

xlabel(ax, 'Temperature (K)');
title(ax, ttl, 'Interpreter', 'none');
grid(ax, 'on');
end
