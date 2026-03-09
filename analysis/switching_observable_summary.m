% switching_observable_summary
% Quick summary diagnostics for Switching observable-layer outputs.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
addpath(fullfile(repoRoot, 'tools'));

resultsRoot = fullfile(repoRoot, 'results');
outDir = fullfile(resultsRoot, 'switching', 'observable_summary');
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

T = load_observables(resultsRoot);
if isempty(T)
    error('No observables were found under %s', resultsRoot);
end

Ts = T(T.experiment == "switching", :);
if isempty(Ts)
    error('No switching observables found in aggregated table.');
end

obsKeep = ["S_peak", "I_peak", "halfwidth_diff_norm", "width_I", "asym"];
Ts = Ts(ismember(Ts.observable, obsKeep), :);
Ts = Ts(isfinite(Ts.temperature) & isfinite(Ts.value), :);

if isempty(Ts)
    error('No finite switching observable rows available for summary.');
end

% Mean-by-temperature aggregation across runs/samples.
G = groupsummary(Ts, {'observable','temperature'}, 'mean', 'value');
G.Properties.VariableNames{'mean_value'} = 'value_mean';
G = sortrows(G, {'observable','temperature'});

writetable(Ts, fullfile(outDir, 'switching_observables_long.csv'));
writetable(G, fullfile(outDir, 'switching_observables_mean_by_T.csv'));

% Observable(T) curves.
figCurves = figure('Color','w','Visible','off','Position',[100 100 1000 700]);
tl = tiledlayout(figCurves, 3, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
for i = 1:numel(obsKeep)
    ax = nexttile(tl, i);
    obs = obsKeep(i);
    d = G(G.observable == obs, :);
    plot(ax, d.temperature, d.value_mean, '-o', 'LineWidth', 1.8, 'MarkerSize', 5);
    xlabel(ax, 'T (K)');
    ylabel(ax, char(obs));
    title(ax, sprintf('%s(T)', obs), 'Interpreter', 'none');
    grid(ax, 'on');
end
nexttile(tl, 6);
axis off;
text(0.0, 0.8, sprintf('Rows: %d', height(Ts)));
text(0.0, 0.6, sprintf('Runs: %d', numel(unique(Ts.source_run))));
text(0.0, 0.4, sprintf('Temperatures: %d', numel(unique(Ts.temperature))));
text(0.0, 0.2, sprintf('Generated: %s', datestr(now, 'yyyy-mm-dd HH:MM:SS')));

curvesOut = fullfile(outDir, 'switching_observable_curves.png');
saveas(figCurves, curvesOut);
close(figCurves);

% Wide table for correlation / pair plots.
wideTbl = unstack(G(:, {'temperature','observable','value_mean'}), 'value_mean', 'observable');
wideTbl = sortrows(wideTbl, 'temperature');
writetable(wideTbl, fullfile(outDir, 'switching_observables_wide_by_T.csv'));

presentObs = obsKeep(ismember(obsKeep, string(wideTbl.Properties.VariableNames)));
X = NaN(height(wideTbl), numel(presentObs));
for i = 1:numel(presentObs)
    X(:,i) = wideTbl.(char(presentObs(i)));
end

C = corr(X, 'Rows', 'pairwise');
figCorr = figure('Color','w','Visible','off','Position',[100 100 850 700]);
axCorr = axes(figCorr);
imagesc(axCorr, C);
set(axCorr, 'XTick', 1:numel(presentObs), 'XTickLabel', cellstr(presentObs), ...
    'YTick', 1:numel(presentObs), 'YTickLabel', cellstr(presentObs));
xtickangle(axCorr, 30);
title(axCorr, 'Switching observable correlation matrix');
cb = colorbar(axCorr);
ylabel(cb, 'corr');
axis(axCorr, 'square');
for r = 1:size(C,1)
    for c = 1:size(C,2)
        if isfinite(C(r,c))
            text(axCorr, c, r, sprintf('%.2f', C(r,c)), ...
                'HorizontalAlignment', 'center', 'Color', 'k', 'FontSize', 9);
        end
    end
end
corrOut = fullfile(outDir, 'switching_observable_correlation_matrix.png');
saveas(figCorr, corrOut);
close(figCorr);

% Pair plots.
validRows = all(isfinite(X), 2);
figPairs = figure('Color','w','Visible','off','Position',[100 100 1000 800]);
if nnz(validRows) >= 3 && numel(presentObs) >= 2
    plotmatrix(X(validRows, :));
    sgtitle('Switching observable pair plots (aggregated by temperature)');
    axs = findobj(figPairs, 'Type', 'axes');
    for a = 1:numel(axs)
        grid(axs(a), 'on');
    end
else
    ax = axes(figPairs);
    axis(ax, 'off');
    text(ax, 0.5, 0.5, 'Not enough complete rows for pair plots', ...
        'HorizontalAlignment', 'center');
end
pairsOut = fullfile(outDir, 'switching_observable_pair_plots.png');
saveas(figPairs, pairsOut);
close(figPairs);

% Save correlation table.
corrTbl = array2table(C, 'VariableNames', cellstr(presentObs), 'RowNames', cellstr(presentObs));
writetable(corrTbl, fullfile(outDir, 'switching_observable_correlation_matrix.csv'), 'WriteRowNames', true);

fprintf('Switching observable summary outputs written to: %s\n', outDir);
fprintf('Saved curves: %s\n', curvesOut);
fprintf('Saved correlation matrix: %s\n', corrOut);
fprintf('Saved pair plots: %s\n', pairsOut);
