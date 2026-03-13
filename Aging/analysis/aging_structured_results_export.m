% aging_structured_results_export
% Structured Aging export for a selected stopping temperature Tp.
% Reuses the existing Aging pipeline stages and computes observables
% directly from stage4/stage5 outputs, without relying on legacy summaries.

clearvars -except preferredTpK tpTolK nCommonGrid;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);
addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

if ~exist('preferredTpK', 'var') || isempty(preferredTpK)
    preferredTpK = 22;
end
if ~exist('tpTolK', 'var') || isempty(tpTolK)
    tpTolK = 0.35;
end
if ~exist('nCommonGrid', 'var') || isempty(nCommonGrid)
    nCommonGrid = 450;
end

cfgRun = struct();
cfgRun.runLabel = sprintf('tp_%0.3g_structured_export', preferredTpK);
cfgRun.datasetName = 'aging_structured_export';
runCtx = createRunContext('aging', cfgRun);
run_output_dir = runCtx.run_dir;

fprintf('Aging structured export run root:\n%s\n', run_output_dir);

% Discover wait-time datasets from agingConfig.
datasetSpecs = discoverDatasetSpecs(agingRoot);
if isempty(datasetSpecs)
    datasetSpecs = {
        'MG119_3sec',   3;
        'MG119_36sec',  36;
        'MG119_6min',   360;
        'MG119_60min',  3600
    };
end

loaded = struct('datasetKey', {}, 'sampleName', {}, 'fallbackTwSec', {}, ...
    'stateStage3', {}, 'tpVals', {}, 'cfg', {});
for i = 1:size(datasetSpecs, 1)
    datasetKey = datasetSpecs{i, 1};
    fallbackTwSec = datasetSpecs{i, 2};

    cfg = agingConfig(datasetKey);
    cfg.runLabel = cfgRun.runLabel;
    cfg.doPlotting = false;
    cfg.saveTableMode = 'none';
    cfg.doFilterDeltaM = false;
    cfg.alignDeltaM = false;
    if isfield(cfg, 'debug') && isstruct(cfg.debug)
        cfg.debug.enable = false;
        cfg.debug.plotGeometry = false;
        cfg.debug.plotSwitching = false;
        cfg.debug.saveOutputs = false;
    end
    cfg.run = runCtx;

    cfg = stage0_setupPaths(cfg);
    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);

    pauseRuns = extractPauseRunsForTpDiscovery(state);
    tpVals = [pauseRuns.waitK];
    tpVals = tpVals(isfinite(tpVals));
    tpVals = sort(unique(tpVals(:)));
    if isempty(tpVals)
        continue;
    end

    loaded(end + 1).datasetKey = datasetKey; %#ok<SAGROW>
    loaded(end).sampleName = inferSampleName(datasetKey);
    loaded(end).fallbackTwSec = fallbackTwSec;
    loaded(end).stateStage3 = state;
    loaded(end).tpVals = tpVals;
    loaded(end).cfg = cfg;
end

assert(~isempty(loaded), 'No Aging datasets could be loaded.');

[TpRef, matchedCount] = selectTargetTp(loaded, preferredTpK, tpTolK);
assert(isfinite(TpRef), 'Could not find a usable stopping temperature near %.3f K.', preferredTpK);
fprintf('Selected T_p = %.3f K with %d matching wait-time datasets.\n', TpRef, matchedCount);

curves = struct('datasetKey', {}, 'sampleName', {}, 'twSec', {}, 'waitLabel', {}, ...
    'TpK', {}, 'T', {}, 'dM', {}, 'Dip_depth', {}, 'Dip_T0', {}, ...
    'Dip_sigma', {}, 'FM_abs', {}, 'FM_step_mag', {});
for i = 1:numel(loaded)
    state = stage4_analyzeAFM_FM(loaded(i).stateStage3, loaded(i).cfg);
    state = stage5_fitFMGaussian(state, loaded(i).cfg);
    pauseRuns = extractAnalyzedPauseRuns(state);

    pr = getPauseRunByTp(pauseRuns, TpRef, tpTolK);
    if isempty(pr)
        continue;
    end
    [T, dM] = extractDeltaMCurve(pr);
    if isempty(T) || isempty(dM)
        continue;
    end
    twSec = extractTwSeconds(pr, loaded(i).fallbackTwSec);
    if ~isfinite(twSec)
        continue;
    end

    c = struct();
    c.datasetKey = loaded(i).datasetKey;
    c.sampleName = loaded(i).sampleName;
    c.twSec = twSec;
    c.waitLabel = waitTimeLabel(twSec);
    c.TpK = getScalarOrNaN(pr, 'waitK');
    c.T = T(:);
    c.dM = dM(:);
    c.Dip_depth = getScalarOrNaN(pr, 'Dip_depth');
    c.Dip_T0 = getScalarOrNaN(pr, 'Dip_T0');
    c.Dip_sigma = getScalarOrNaN(pr, 'Dip_sigma');
    c.FM_abs = getScalarOrNaN(pr, 'FM_abs');
    c.FM_step_mag = getScalarOrNaN(pr, 'FM_step_mag');
    curves(end + 1) = c; %#ok<SAGROW>
end
assert(numel(curves) >= 2, 'Need at least two valid wait-time curves to build DeltaM(T,tw).');

[~, order] = sort([curves.twSec]);
curves = curves(order);
twSec = [curves.twSec].';
logTw = log10(twSec);

[Tgrid, M] = buildCommonDeltaMMap(curves, nCommonGrid);

% Export map axes and map matrix.
TaxisTbl = table(Tgrid, 'VariableNames', {'T_K'});
twAxisTbl = table((1:numel(twSec)).', twSec, logTw, string({curves.datasetKey}).', ...
    string({curves.waitLabel}).', repmat(TpRef, numel(twSec), 1), ...
    'VariableNames', {'tw_index','tw_seconds','log10_tw_seconds','dataset','wait_time','Tp_K'});
mapVarNames = arrayfun(@(x) matlab.lang.makeValidName(sprintf('tw_%0.6gs', x)), twSec, 'UniformOutput', false);
mapTbl = array2table(M, 'VariableNames', mapVarNames);
save_run_table(TaxisTbl, 'T_axis.csv', run_output_dir);
save_run_table(twAxisTbl, 'tw_axis.csv', run_output_dir);
save_run_table(mapTbl, 'DeltaM_map.csv', run_output_dir);

obsMatrixTbl = buildObservableMatrix(curves);
writetable(obsMatrixTbl, fullfile(run_output_dir, 'observables.csv'));
fprintf('Saved table: %s\n', fullfile(run_output_dir, 'observables.csv'));
save_run_table(obsMatrixTbl, 'observable_matrix.csv', run_output_dir);

% Full SVD of DeltaM(T,tw).
[U, S, V] = svd(M, 'econ');
svals = diag(S);
energy = svals.^2;
energySum = sum(energy, 'omitnan');
explained = energy ./ max(energySum, eps);
cumulative = cumsum(explained);
normalized = svals ./ max(sum(abs(svals), 'omitnan'), eps);
svdSingTbl = table((1:numel(svals)).', svals, normalized, explained, cumulative, ...
    'VariableNames', {'mode','singular_value','normalized_singular_value','explained_variance_ratio','cumulative_variance_ratio'});
save_run_table(svdSingTbl, 'svd_singular_values.csv', run_output_dir);

uTbl = table(Tgrid, 'VariableNames', {'T_K'});
for k = 1:size(U, 2)
    uTbl.(sprintf('U_mode%d', k)) = U(:, k);
end
save_run_table(uTbl, 'svd_U.csv', run_output_dir);

vTbl = table((1:numel(twSec)).', twSec, logTw, string({curves.datasetKey}).', string({curves.waitLabel}).', ...
    'VariableNames', {'tw_index','tw_seconds','log10_tw_seconds','dataset','wait_time'});
for k = 1:size(V, 2)
    vTbl.(sprintf('V_mode%d', k)) = V(:, k);
end
save_run_table(vTbl, 'svd_V.csv', run_output_dir);

coeff = V .* reshape(svals(:).', 1, []);
coeffTbl = table((1:numel(twSec)).', twSec, logTw, string({curves.datasetKey}).', string({curves.waitLabel}).', ...
    repmat(TpRef, numel(twSec), 1), ...
    'VariableNames', {'tw_index','tw_seconds','log10_tw_seconds','dataset','wait_time','Tp_K'});
for k = 1:size(coeff, 2)
    coeffTbl.(sprintf('coeff_mode%d', k)) = coeff(:, k);
end
save_run_table(coeffTbl, 'svd_mode_coefficients.csv', run_output_dir);

corrTbl = buildObservableModeCorrelationTable(obsMatrixTbl, coeffTbl);
save_run_table(corrTbl, 'observable_mode_correlations.csv', run_output_dir);

% Figures.
fig1 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax1 = axes(fig1);
imagesc(ax1, Tgrid, logTw, M.');
axis(ax1, 'xy');
colormap(ax1, parula);
cb1 = colorbar(ax1);
ylabel(cb1, 'DeltaM');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'log10(t_w [s])');
title(ax1, sprintf('Aging DeltaM map at T_p = %.2f K', TpRef));
set(ax1, 'FontSize', 14);
save_run_figure(fig1, 'aging_DeltaM_map', run_output_dir);
close(fig1);

fig2 = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 920 620]);
ax2 = axes(fig2);
hold(ax2, 'on');
plot(ax2, svdSingTbl.mode, svdSingTbl.normalized_singular_value, '-o', 'LineWidth', 2.2, 'Color', [0.1 0.35 0.75]);
plot(ax2, svdSingTbl.mode, svdSingTbl.cumulative_variance_ratio, '-s', 'LineWidth', 2.2, 'Color', [0.85 0.33 0.10]);
legend(ax2, {'Normalized singular value','Cumulative variance'}, 'Location', 'eastoutside');
grid(ax2, 'on');
xlabel(ax2, 'Mode index');
ylabel(ax2, 'Value');
title(ax2, 'Aging SVD singular spectrum');
set(ax2, 'FontSize', 14);
save_run_figure(fig2, 'aging_svd_singular_spectrum', run_output_dir);
close(fig2);

% Report.
reportLines = strings(0, 1);
reportLines(end + 1) = '# Aging Observable Summary'; %#ok<SAGROW>
reportLines(end + 1) = '';
reportLines(end + 1) = sprintf('Generated: %s', datestr(now, 31));
reportLines(end + 1) = sprintf('Run root: %s', string(run_output_dir));
reportLines(end + 1) = '';
reportLines(end + 1) = '## Scope and dataset provenance';
reportLines(end + 1) = sprintf('- Selected stopping temperature: %.3f K', TpRef);
reportLines(end + 1) = sprintf('- Requested stopping temperature: %.3f K', preferredTpK);
reportLines(end + 1) = sprintf('- Tp matching tolerance: %.3f K', tpTolK);
reportLines(end + 1) = sprintf('- Wait-time datasets included: %d', numel(curves));
reportLines(end + 1) = sprintf('- Dataset keys: %s', strjoin(string({curves.datasetKey}), ', '));
reportLines(end + 1) = sprintf('- Wait times (s): %s', strjoin(string(compose('%.0f', twSec)), ', '));
reportLines(end + 1) = sprintf('- Temperature grid points: %d', numel(Tgrid));
reportLines(end + 1) = sprintf('- Common temperature range: %.3f to %.3f K', min(Tgrid), max(Tgrid));
reportLines(end + 1) = '';
reportLines(end + 1) = '## Pipeline stages reused';
reportLines(end + 1) = '- stage0_setupPaths';
reportLines(end + 1) = '- stage1_loadData';
reportLines(end + 1) = '- stage2_preprocess';
reportLines(end + 1) = '- stage3_computeDeltaM';
reportLines(end + 1) = '- stage4_analyzeAFM_FM';
reportLines(end + 1) = '- stage5_fitFMGaussian';
reportLines(end + 1) = '';
reportLines(end + 1) = '## Observable definitions';
reportLines(end + 1) = '- Dip_depth: direct dip amplitude from stage4_analyzeAFM_FM, with the stage4 fallback to the minimum DeltaM magnitude inside the dip window when needed.';
reportLines(end + 1) = '- Dip_T0: Gaussian dip center from stage5_fitFMGaussian.';
reportLines(end + 1) = '- Dip_sigma: Gaussian dip width from stage5_fitFMGaussian.';
reportLines(end + 1) = '- FM_abs: absolute FM/background step amplitude from stage4_analyzeAFM_FM.';
reportLines(end + 1) = '- FM_step_mag: signed FM step magnitude stored by stage4_analyzeAFM_FM.';
reportLines(end + 1) = '';
reportLines(end + 1) = '## Structured outputs';
reportLines(end + 1) = '- observables.csv: one row per physical point (sample, dataset, T_p, t_w).';
reportLines(end + 1) = '- tables/observable_matrix.csv: wide observable table with the same physical-point rows.';
reportLines(end + 1) = '- tables/DeltaM_map.csv';
reportLines(end + 1) = '- tables/T_axis.csv';
reportLines(end + 1) = '- tables/tw_axis.csv';
reportLines(end + 1) = '- tables/svd_singular_values.csv';
reportLines(end + 1) = '- tables/svd_U.csv';
reportLines(end + 1) = '- tables/svd_V.csv';
reportLines(end + 1) = '- tables/svd_mode_coefficients.csv';
reportLines(end + 1) = '- tables/observable_mode_correlations.csv';
reportLines(end + 1) = '- figures/aging_DeltaM_map.png';
reportLines(end + 1) = '- figures/aging_svd_singular_spectrum.png';
reportLines(end + 1) = '';
reportLines(end + 1) = '## Correlation summary';
if isempty(corrTbl)
    reportLines(end + 1) = '- No observable-mode correlations were available.';
else
    topN = min(5, height(corrTbl));
    for i = 1:topN
        reportLines(end + 1) = sprintf('- %s vs %s: Pearson = %.4f, Spearman = %.4f, |best| = %.4f', ...
            string(corrTbl.mode(i)), string(corrTbl.observable(i)), ...
            corrTbl.pearson_correlation(i), corrTbl.spearman_correlation(i), corrTbl.best_abs_correlation(i));
    end
end
reportPath = save_run_report(reportLines, 'aging_observable_summary.md', run_output_dir);

reviewDir = fullfile(run_output_dir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'aging_run_review.zip');
if isfile(zipPath)
    delete(zipPath);
end
zipInputs = {
    fullfile(run_output_dir, 'observables.csv'), ...
    fullfile(run_output_dir, 'tables', 'DeltaM_map.csv'), ...
    fullfile(run_output_dir, 'tables', 'T_axis.csv'), ...
    fullfile(run_output_dir, 'tables', 'tw_axis.csv'), ...
    fullfile(run_output_dir, 'tables', 'observable_matrix.csv'), ...
    fullfile(run_output_dir, 'tables', 'svd_singular_values.csv'), ...
    fullfile(run_output_dir, 'tables', 'svd_U.csv'), ...
    fullfile(run_output_dir, 'tables', 'svd_V.csv'), ...
    fullfile(run_output_dir, 'tables', 'svd_mode_coefficients.csv'), ...
    fullfile(run_output_dir, 'tables', 'observable_mode_correlations.csv'), ...
    fullfile(run_output_dir, 'figures', 'aging_DeltaM_map.png'), ...
    fullfile(run_output_dir, 'figures', 'aging_svd_singular_spectrum.png'), ...
    reportPath};
zip(zipPath, zipInputs);

fprintf('Structured Aging export complete.\n');
fprintf('Run root: %s\n', run_output_dir);
fprintf('Review ZIP: %s\n', zipPath);

function pauseRuns = extractPauseRunsForTpDiscovery(state)
if isfield(state, 'pauseRuns_raw') && ~isempty(state.pauseRuns_raw)
    pauseRuns = state.pauseRuns_raw;
elseif isfield(state, 'pauseRuns') && ~isempty(state.pauseRuns)
    pauseRuns = state.pauseRuns;
else
    error('No pause runs were found in pipeline output.');
end
end

function pauseRuns = extractAnalyzedPauseRuns(state)
if isfield(state, 'pauseRuns') && ~isempty(state.pauseRuns)
    pauseRuns = state.pauseRuns;
elseif isfield(state, 'pauseRuns_raw') && ~isempty(state.pauseRuns_raw)
    pauseRuns = state.pauseRuns_raw;
else
    error('No pause runs were found in pipeline output.');
end
end

function [TpRef, matchedCount] = selectTargetTp(loaded, preferredTpK, tol)
allTp = [];
for i = 1:numel(loaded)
    allTp = [allTp; loaded(i).tpVals(:)]; %#ok<AGROW>
end
allTp = sort(unique(allTp));
assert(~isempty(allTp), 'No stopping temperatures were discovered in the loaded datasets.');

bestIdx = [];
bestCount = -Inf;
bestDistance = Inf;
for i = 1:numel(allTp)
    candidate = allTp(i);
    count = 0;
    for j = 1:numel(loaded)
        if any(abs(loaded(j).tpVals - candidate) <= tol)
            count = count + 1;
        end
    end
    if count < 2
        continue;
    end
    distance = abs(candidate - preferredTpK);
    if distance > tol
        continue;
    end
    if isempty(bestIdx) || distance < bestDistance || (abs(distance - bestDistance) <= eps && count > bestCount)
        bestIdx = i;
        bestCount = count;
        bestDistance = distance;
    end
end

if isempty(bestIdx)
    TpRef = NaN;
    matchedCount = 0;
    return;
end
TpRef = allTp(bestIdx);
matchedCount = bestCount;
end

function pr = getPauseRunByTp(pauseRuns, tpTarget, tol)
pr = [];
if isempty(pauseRuns)
    return;
end
tpVals = [pauseRuns.waitK];
idx = find(isfinite(tpVals) & abs(tpVals - tpTarget) <= tol, 1, 'first');
if ~isempty(idx)
    pr = pauseRuns(idx);
end
end

function [Tgrid, M] = buildCommonDeltaMMap(curves, nCommonGrid)
Tmin = -Inf;
Tmax = Inf;
for i = 1:numel(curves)
    Tmin = max(Tmin, min(curves(i).T));
    Tmax = min(Tmax, max(curves(i).T));
end
assert(Tmax > Tmin, 'No overlapping temperature range across wait times.');

Tgrid = linspace(Tmin, Tmax, nCommonGrid).';
M = nan(nCommonGrid, numel(curves));
for i = 1:numel(curves)
    M(:, i) = interp1(curves(i).T, curves(i).dM, Tgrid, 'linear', NaN);
end
assert(all(isfinite(M(:))), 'Structured export requires a finite DeltaM map on the common grid.');
end

function [T, dM] = extractDeltaMCurve(pr)
T = [];
dM = [];
if isfield(pr, 'T_common') && ~isempty(pr.T_common)
    T = pr.T_common(:);
elseif isfield(pr, 'T') && ~isempty(pr.T)
    T = pr.T(:);
end
if isfield(pr, 'DeltaM') && ~isempty(pr.DeltaM)
    dM = pr.DeltaM(:);
elseif isfield(pr, 'DeltaM_aligned') && ~isempty(pr.DeltaM_aligned)
    dM = pr.DeltaM_aligned(:);
end
n = min(numel(T), numel(dM));
if n < 10
    T = [];
    dM = [];
    return;
end
T = T(1:n);
dM = dM(1:n);
ok = isfinite(T) & isfinite(dM);
T = T(ok);
dM = dM(ok);
[T, idx] = unique(T, 'stable');
dM = dM(idx);
end

function twSec = extractTwSeconds(pr, fallbackTwSec)
twSec = NaN;
if isfield(pr, 'waitHours') && ~isempty(pr.waitHours) && isfinite(pr.waitHours) && pr.waitHours > 0
    twSec = 3600 * pr.waitHours;
elseif nargin >= 2
    twSec = fallbackTwSec;
end
end

function obsMatrixTbl = buildObservableMatrix(curves)
n = numel(curves);
obsMatrixTbl = table(strings(n, 1), string({curves.datasetKey}).', string({curves.waitLabel}).', ...
    [curves.twSec].', log10([curves.twSec].'), [curves.TpK].', ...
    [curves.Dip_depth].', [curves.Dip_T0].', [curves.Dip_sigma].', ...
    [curves.FM_abs].', [curves.FM_step_mag].', ...
    'VariableNames', {'sample','dataset','wait_time','tw_seconds','log10_tw_seconds','Tp_K', ...
    'Dip_depth','Dip_T0','Dip_sigma','FM_abs','FM_step_mag'});
for i = 1:n
    obsMatrixTbl.sample(i) = string(curves(i).sampleName);
end
end

function corrTbl = buildObservableModeCorrelationTable(obsMatrixTbl, coeffTbl)
obsNames = {'Dip_depth','Dip_T0','Dip_sigma','FM_abs','FM_step_mag'};
modeCount = min(3, sum(startsWith(coeffTbl.Properties.VariableNames, 'coeff_mode')));
rows = repmat(struct('mode', "", 'observable', "", 'n_points', NaN, ...
    'pearson_correlation', NaN, 'spearman_correlation', NaN, 'best_abs_correlation', NaN), 0, 1);
for modeIdx = 1:modeCount
    modeName = sprintf('coeff_mode%d', modeIdx);
    x = coeffTbl.(modeName);
    for j = 1:numel(obsNames)
        y = obsMatrixTbl.(obsNames{j});
        valid = isfinite(x) & isfinite(y);
        row = struct('mode', string(modeName), 'observable', string(obsNames{j}), 'n_points', nnz(valid), ...
            'pearson_correlation', NaN, 'spearman_correlation', NaN, 'best_abs_correlation', NaN);
        if nnz(valid) >= 3
            row.pearson_correlation = corr(x(valid), y(valid), 'Type', 'Pearson', 'Rows', 'complete');
            row.spearman_correlation = corr(x(valid), y(valid), 'Type', 'Spearman', 'Rows', 'complete');
            row.best_abs_correlation = max(abs([row.pearson_correlation, row.spearman_correlation]));
        end
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
end
corrTbl = struct2table(rows);
if ~isempty(corrTbl)
    corrTbl = sortrows(corrTbl, 'best_abs_correlation', 'descend');
end
end

function sampleName = inferSampleName(datasetKey)
sampleName = string(datasetKey);
tok = regexp(char(datasetKey), '^(MG\d+)', 'tokens', 'once');
if ~isempty(tok)
    sampleName = string(tok{1});
end
end

function label = waitTimeLabel(twSec)
if abs(twSec - 3) < 1e-9
    label = "3 s";
elseif abs(twSec - 36) < 1e-9
    label = "36 s";
elseif abs(twSec - 360) < 1e-9
    label = "6 min";
elseif abs(twSec - 3600) < 1e-9
    label = "60 min";
elseif twSec < 60
    label = string(sprintf('%.3g s', twSec));
elseif twSec < 3600
    label = string(sprintf('%.3g min', twSec / 60));
else
    label = string(sprintf('%.3g h', twSec / 3600));
end
end

function value = getScalarOrNaN(s, fieldName)
value = NaN;
if isfield(s, fieldName)
    candidate = s.(fieldName);
    if ~isempty(candidate)
        candidate = candidate(1);
        if isnumeric(candidate) && isfinite(candidate)
            value = double(candidate);
        end
    end
end
end

function datasetSpecs = discoverDatasetSpecs(agingRoot)
datasetSpecs = {};
cfgPath = fullfile(agingRoot, 'pipeline', 'agingConfig.m');
if ~isfile(cfgPath)
    return;
end
try
    txt = fileread(cfgPath);
catch
    return;
end
toks = regexp(txt, 'case\s+''([^'']+)''', 'tokens');
if isempty(toks)
    return;
end
keys = strings(0, 1);
for i = 1:numel(toks)
    keys(end + 1, 1) = string(toks{i}{1}); %#ok<SAGROW>
end
keys = unique(keys, 'stable');
keys = keys(contains(keys, 'MG119_'));
fallbackSec = nan(numel(keys), 1);
for i = 1:numel(keys)
    fallbackSec(i) = parseDatasetWaitSeconds(keys(i));
end
sortKey = fallbackSec;
sortKey(~isfinite(sortKey)) = Inf;
[~, order] = sort(sortKey, 'ascend');
keys = keys(order);
fallbackSec = fallbackSec(order);
datasetSpecs = cell(numel(keys), 2);
for i = 1:numel(keys)
    datasetSpecs{i, 1} = char(keys(i));
    datasetSpecs{i, 2} = fallbackSec(i);
end
end

function twSec = parseDatasetWaitSeconds(datasetKey)
twSec = NaN;
k = lower(char(datasetKey));
tokSec = regexp(k, '(\d+(?:\.\d+)?)\s*sec', 'tokens', 'once');
if ~isempty(tokSec)
    twSec = str2double(tokSec{1});
    return;
end
tokMin = regexp(k, '(\d+(?:\.\d+)?)\s*min', 'tokens', 'once');
if ~isempty(tokMin)
    twSec = 60 * str2double(tokMin{1});
    return;
end
tokHour = regexp(k, '(\d+(?:\.\d+)?)\s*(?:hour|hr|h)', 'tokens', 'once');
if ~isempty(tokHour)
    twSec = 3600 * str2double(tokHour{1});
end
end
