% aging_observable_mode_correlation
% Link legacy Aging SVD coefficients to physical observables.
% This is a standalone diagnostic analysis and does not modify the pipeline.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);
addpath(genpath(agingRoot));
addpath(genpath(fullfile(repoRoot, 'tools')));

cfg = struct();
cfg.runLabel = 'observable_mode_correlation';
cfg.datasetName = 'legacy_join';
runCtx = createRunContext('aging', cfg); %#ok<NASGU>
run_output_dir = getRunOutputDir();

fprintf('Aging observable-mode correlation run root:\n%s\n', run_output_dir);
fprintf('Figures dir: %s\n', fullfile(run_output_dir, 'figures'));
fprintf('Tables dir: %s\n', fullfile(run_output_dir, 'tables'));
fprintf('Reports dir: %s\n', fullfile(run_output_dir, 'reports'));
fprintf('Review dir: %s\n', fullfile(run_output_dir, 'review'));

svdPath = fullfile(repoRoot, 'results', 'aging', 'runs', 'run_legacy_svd_pca', ...
    'tables', 'curve_mode_coefficients.csv');
decompPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_legacy_decomposition_stability', 'tables', 'decomposition_stability_raw.csv');
fmAuxPath = fullfile(repoRoot, 'results', 'aging', 'runs', ...
    'run_legacy_decomposition', 'tables', 'FM_sign_stability', 'FM_AFM_summary.csv');

assert(exist(svdPath, 'file') == 2, 'Missing SVD coefficient table: %s', svdPath);
assert(exist(decompPath, 'file') == 2, 'Missing decomposition observables table: %s', decompPath);

svdTbl = readtable(svdPath);
decompRaw = readtable(decompPath);
if exist(fmAuxPath, 'file') == 2
    fmAux = readtable(fmAuxPath);
else
    fmAux = table();
end

svdTbl = normalizeLegacyTable(svdTbl);
decompRaw = normalizeLegacyTable(decompRaw);
fmAux = normalizeLegacyTable(fmAux);

obsVars = {'Dip_depth', 'Dip_sigma', 'Dip_T0', 'FM_abs', 'FM_E', 'FM_step_mag'};
coeffVars = {'coeff_mode1', 'coeff_mode2', 'coeff_mode3'};

obsAgg = aggregateObservableRows(decompRaw, obsVars);
if ~isempty(fmAux)
    obsAgg = mergeAuxiliaryFM(obsAgg, fmAux);
end

joinedTbl = joinSvdAndObservables(svdTbl, obsAgg, coeffVars, obsVars);
joinedTbl = sortrows(joinedTbl, {'matrix_name', 'wait_time', 'Tp'});

correlationTbl = computeCorrelationTable(joinedTbl, coeffVars, obsVars);
correlationTbl = sortrows(correlationTbl, {'best_abs_correlation', 'matrix_name'}, {'descend', 'ascend'});

joinedPath = save_run_table(joinedTbl, 'observable_mode_joined_table.csv', run_output_dir);
correlationPath = save_run_table(correlationTbl, 'observable_mode_correlations.csv', run_output_dir);

figSaved = strings(0, 1);
plotPairs = {
    'coeff_mode1', 'Dip_depth';
    'coeff_mode2', 'FM_abs';
    'coeff_mode2', 'Dip_sigma';
    'coeff_mode3', 'Dip_T0'
};

for i = 1:size(plotPairs, 1)
    coeffName = plotPairs{i, 1};
    obsName = plotPairs{i, 2};
    [figH, figBaseName] = makeCorrelationScatter(joinedTbl, correlationTbl, coeffName, obsName);
    if ~isempty(figH)
        paths = save_run_figure(figH, figBaseName, run_output_dir);
        figSaved(end + 1, 1) = string(paths.png); %#ok<SAGROW>
        close(figH);
    end
end

reportText = buildReportText(joinedTbl, correlationTbl, obsAgg, obsVars, coeffVars, svdPath, decompPath, fmAuxPath);
reportPath = save_run_report(reportText, 'observable_mode_correlation_report.md', run_output_dir);

reviewDir = fullfile(run_output_dir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'observable_mode_correlation_review.zip');

zipInputs = cellstr(figSaved);
zipInputs{end + 1} = correlationPath;
zipInputs{end + 1} = joinedPath;
zipInputs{end + 1} = reportPath;
zip(zipPath, zipInputs);
fprintf('Saved review ZIP: %s\n', zipPath);

function T = normalizeLegacyTable(T)
if isempty(T)
    return;
end

vars = T.Properties.VariableNames;
for i = 1:numel(vars)
    vn = vars{i};
    if iscellstr(T.(vn)) || ischar(T.(vn))
        T.(vn) = string(T.(vn));
    elseif iscell(T.(vn))
        try
            T.(vn) = string(T.(vn));
        catch
            % Leave unsupported cell arrays untouched.
        end
    end
end
end

function obsAgg = aggregateObservableRows(decompRaw, obsVars)
required = {'wait_time', 'dataset', 'Tp', 'setting_name'};
for i = 1:numel(required)
    assert(ismember(required{i}, decompRaw.Properties.VariableNames), ...
        'Missing required column %s in decomposition table.', required{i});
end

keys = unique(decompRaw(:, {'wait_time', 'dataset', 'Tp'}), 'rows');
rows = repmat(initObsAggRow(obsVars), height(keys), 1);

for i = 1:height(keys)
    rowMask = decompRaw.wait_time == keys.wait_time(i) & ...
        decompRaw.dataset == keys.dataset(i) & ...
        abs(decompRaw.Tp - keys.Tp(i)) < 1e-9;
    sub = decompRaw(rowMask, :);

    rows(i).sample = extractSampleName(keys.dataset(i));
    rows(i).dataset = string(keys.dataset(i));
    rows(i).wait_time = string(keys.wait_time(i));
    rows(i).Tp = keys.Tp(i);
    rows(i).temperature = keys.Tp(i);
    rows(i).n_settings = height(sub);
    rows(i).n_default_settings = sum(sub.setting_name == "default");

    for j = 1:numel(obsVars)
        obsName = obsVars{j};
        if ismember(obsName, sub.Properties.VariableNames)
            vals = sub.(obsName);
            rows(i).(obsName) = mean(vals, 'omitnan');
            rows(i).([obsName '_std']) = std(vals, 'omitnan');
            rows(i).([obsName '_n']) = nnz(isfinite(vals));
        end
    end
end

obsAgg = struct2table(rows);
obsAgg = sortrows(obsAgg, {'wait_time', 'Tp'});
end

function row = initObsAggRow(obsVars)
row = struct();
row.sample = "";
row.dataset = "";
row.wait_time = "";
row.Tp = NaN;
row.temperature = NaN;
row.n_settings = NaN;
row.n_default_settings = NaN;

for i = 1:numel(obsVars)
    obsName = obsVars{i};
    row.(obsName) = NaN;
    row.([obsName '_std']) = NaN;
    row.([obsName '_n']) = NaN;
end

row.FM_abs_aux = NaN;
row.FM_signed_aux = NaN;
row.FM_present_aux = NaN;
end

function sample = extractSampleName(datasetName)
parts = split(string(datasetName), "_");
if isempty(parts)
    sample = string(datasetName);
else
    sample = parts(1);
end
end

function obsAgg = mergeAuxiliaryFM(obsAgg, fmAux)
needed = {'wait_time', 'Tp', 'FM_abs'};
for i = 1:numel(needed)
    if ~ismember(needed{i}, fmAux.Properties.VariableNames)
        return;
    end
end

if ismember('FM_signed', fmAux.Properties.VariableNames)
    signedVals = fmAux.FM_signed;
else
    signedVals = nan(height(fmAux), 1);
end

if ismember('FM_present', fmAux.Properties.VariableNames)
    presentVals = double(fmAux.FM_present);
else
    presentVals = nan(height(fmAux), 1);
end

for i = 1:height(obsAgg)
    auxMask = fmAux.wait_time == obsAgg.wait_time(i) & abs(fmAux.Tp - obsAgg.Tp(i)) < 1e-9;
    if ~any(auxMask)
        continue;
    end

    auxRows = fmAux(auxMask, :);
    obsAgg.FM_abs_aux(i) = mean(auxRows.FM_abs, 'omitnan');
    obsAgg.FM_signed_aux(i) = mean(signedVals(auxMask), 'omitnan');
    obsAgg.FM_present_aux(i) = mean(presentVals(auxMask), 'omitnan');

    if ~isfinite(obsAgg.FM_abs(i))
        obsAgg.FM_abs(i) = obsAgg.FM_abs_aux(i);
    end
end
end

function joinedTbl = joinSvdAndObservables(svdTbl, obsAgg, coeffVars, obsVars)
requiredSvd = {'wait_time', 'Tp', 'matrix_name'};
for i = 1:numel(requiredSvd)
    assert(ismember(requiredSvd{i}, svdTbl.Properties.VariableNames), ...
        'Missing required column %s in SVD table.', requiredSvd{i});
end

keepVars = [{'wait_time', 'Tp', 'matrix_name'}, coeffVars, ...
    {'reconstruction_error_rank1', 'reconstruction_error_rank2', 'reconstruction_error_rank3'}];
keepVars = keepVars(ismember(keepVars, svdTbl.Properties.VariableNames));
svdSmall = svdTbl(:, keepVars);

joinedTbl = innerjoin(svdSmall, obsAgg, 'Keys', {'wait_time', 'Tp'});
joinedTbl.temperature = joinedTbl.Tp;

colOrder = [{'sample', 'dataset', 'wait_time', 'temperature', 'Tp', 'matrix_name'}, ...
    coeffVars, obsVars, {'n_settings', 'n_default_settings', 'FM_abs_aux', 'FM_signed_aux', 'FM_present_aux'}];
colOrder = colOrder(ismember(colOrder, joinedTbl.Properties.VariableNames));

remaining = joinedTbl.Properties.VariableNames(~ismember(joinedTbl.Properties.VariableNames, colOrder));
joinedTbl = joinedTbl(:, [colOrder, remaining]);
end

function corrTbl = computeCorrelationTable(joinedTbl, coeffVars, obsVars)
matrixNames = unique(joinedTbl.matrix_name, 'stable');
rows = repmat(initCorrRow(), 0, 1);

for i = 1:numel(matrixNames)
    matrixName = matrixNames(i);
    matrixMask = joinedTbl.matrix_name == matrixName;

    for c = 1:numel(coeffVars)
        coeffName = coeffVars{c};
        for o = 1:numel(obsVars)
            obsName = obsVars{o};
            valid = matrixMask & isfinite(joinedTbl.(coeffName)) & isfinite(joinedTbl.(obsName));
            x = joinedTbl.(coeffName)(valid);
            y = joinedTbl.(obsName)(valid);

            row = initCorrRow();
            row.matrix_name = matrixName;
            row.coefficient = string(coeffName);
            row.observable = string(obsName);
            row.n_points = numel(x);
            row.wait_time_count = numel(unique(joinedTbl.wait_time(valid)));
            row.tp_min = minWithNaN(joinedTbl.Tp(valid));
            row.tp_max = maxWithNaN(joinedTbl.Tp(valid));

            if numel(x) >= 3
                [row.pearson_r, row.pearson_p] = safeCorr(x, y, 'Pearson');
                [row.spearman_rho, row.spearman_p] = safeCorr(x, y, 'Spearman');
                row.best_abs_correlation = max(abs([row.pearson_r, row.spearman_rho]));
            end

            rows(end + 1, 1) = row; %#ok<AGROW>
        end
    end
end

corrTbl = struct2table(rows);
end

function row = initCorrRow()
row = struct();
row.matrix_name = "";
row.coefficient = "";
row.observable = "";
row.n_points = NaN;
row.wait_time_count = NaN;
row.tp_min = NaN;
row.tp_max = NaN;
row.pearson_r = NaN;
row.pearson_p = NaN;
row.spearman_rho = NaN;
row.spearman_p = NaN;
row.best_abs_correlation = NaN;
end

function [r, p] = safeCorr(x, y, corrType)
r = NaN;
p = NaN;
try
    [r, p] = corr(x, y, 'Type', corrType, 'Rows', 'complete');
catch
    valid = isfinite(x) & isfinite(y);
    if nnz(valid) >= 3
        if strcmpi(corrType, 'Spearman')
            x = tiedrank(x(valid));
            y = tiedrank(y(valid));
        else
            x = x(valid);
            y = y(valid);
        end
        C = corrcoef(x, y);
        if numel(C) >= 4
            r = C(1, 2);
        end
    end
end
end

function [figH, figBaseName] = makeCorrelationScatter(joinedTbl, corrTbl, coeffName, obsName)
pairRows = corrTbl(corrTbl.coefficient == string(coeffName) & corrTbl.observable == string(obsName), :);
if isempty(pairRows)
    figH = [];
    figBaseName = '';
    return;
end

[~, bestIdx] = max(pairRows.best_abs_correlation);
bestRow = pairRows(bestIdx, :);
matrixName = string(bestRow.matrix_name);

mask = joinedTbl.matrix_name == matrixName & ...
    isfinite(joinedTbl.(coeffName)) & isfinite(joinedTbl.(obsName));
sub = joinedTbl(mask, :);
if height(sub) < 3
    figH = [];
    figBaseName = '';
    return;
end

waitCats = unique(sub.wait_time, 'stable');
colors = lines(numel(waitCats));
markers = {'o', 's', '^', 'd', 'v', '>'};

figH = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 880 620]);
ax = axes(figH); hold(ax, 'on');

for i = 1:numel(waitCats)
    waitMask = sub.wait_time == waitCats(i);
    scatter(ax, sub.(coeffName)(waitMask), sub.(obsName)(waitMask), 64, ...
        'Marker', markers{mod(i - 1, numel(markers)) + 1}, ...
        'MarkerFaceColor', colors(i, :), ...
        'MarkerEdgeColor', colors(i, :), ...
        'DisplayName', char(waitCats(i)));
end

xAll = sub.(coeffName);
yAll = sub.(obsName);
if numel(xAll) >= 2 && numel(unique(xAll)) >= 2
    pFit = polyfit(xAll, yAll, 1);
    xLine = linspace(min(xAll), max(xAll), 200);
    yLine = polyval(pFit, xLine);
    plot(ax, xLine, yLine, 'k--', 'LineWidth', 2, 'DisplayName', 'linear fit');
end

grid(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
xlabel(ax, strrep(coeffName, '_', '\_'), 'FontSize', 14);
ylabel(ax, formatObservableLabel(obsName), 'FontSize', 14);
title(ax, sprintf('%s vs %s (%s)', strrep(obsName, '_', '\_'), strrep(coeffName, '_', '\_'), matrixName), ...
    'Interpreter', 'none', 'FontSize', 14);

statsText = sprintf('Pearson r = %.3f | Spearman \\rho = %.3f | n = %d', ...
    bestRow.pearson_r, bestRow.spearman_rho, bestRow.n_points);
text(ax, 0.02, 0.98, statsText, 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'FontSize', 12, 'BackgroundColor', 'w');

legend(ax, 'Location', 'eastoutside');
figBaseName = sprintf('observable_mode_%s_vs_%s_%s', coeffName, obsName, matrixName);
end

function label = formatObservableLabel(obsName)
switch char(obsName)
    case 'Dip_depth'
        label = 'Dip depth';
    case 'Dip_sigma'
        label = 'Dip sigma (K)';
    case 'Dip_T0'
        label = 'Dip T0 (K)';
    case 'FM_abs'
        label = 'FM abs';
    case 'FM_E'
        label = 'FM_E';
    case 'FM_step_mag'
        label = 'FM step magnitude';
    otherwise
        label = char(obsName);
end
end

function txt = buildReportText(joinedTbl, corrTbl, obsAgg, obsVars, coeffVars, svdPath, decompPath, fmAuxPath)
topRows = corrTbl(1:min(10, height(corrTbl)), :);

mode1Dip = lookupBestRow(corrTbl, 'coeff_mode1', 'Dip_depth');
mode2Bg = bestBackgroundRow(corrTbl, 'coeff_mode2', {'FM_abs', 'FM_E', 'FM_step_mag'});
mode3Best = bestModeRow(corrTbl, 'coeff_mode3');

mode1Text = interpretMode1(mode1Dip);
mode2Text = interpretMode2(mode2Bg);
mode3Text = interpretMode3(mode3Best);

lines = strings(0, 1);
lines(end + 1) = "# Observable-mode correlation";
lines(end + 1) = "";
lines(end + 1) = "## Data sources";
lines(end + 1) = "- SVD coefficients: `" + string(svdPath) + "`";
lines(end + 1) = "- Decomposition observables: `" + string(decompPath) + "`";
if exist(fmAuxPath, 'file') == 2
    lines(end + 1) = "- Auxiliary FM observables: `" + string(fmAuxPath) + "`";
end
lines(end + 1) = "";
lines(end + 1) = "## Join strategy";
lines(end + 1) = "- Aggregated decomposition-stability rows by `sample`, `dataset`, `wait_time`, and `Tp`.";
lines(end + 1) = "- Used the mean across audit settings for `Dip_depth`, `Dip_sigma`, `Dip_T0`, `FM_abs`, `FM_E`, and `FM_step_mag`.";
lines(end + 1) = "- Joined the aggregated observable layer to the SVD coefficient table on `wait_time` and `Tp`.";
lines(end + 1) = "- Defined `temperature = Tp` for this legacy curve-level join because the stored SVD rows are indexed by pause temperature.";
lines(end + 1) = "";
lines(end + 1) = "## Coverage";
lines(end + 1) = "- Joined rows: " + height(joinedTbl);
lines(end + 1) = "- Distinct wait times: " + numel(unique(joinedTbl.wait_time));
lines(end + 1) = "- Distinct `Tp` values: " + numel(unique(joinedTbl.Tp));
lines(end + 1) = "- Observable table rows before join: " + height(obsAgg);
lines(end + 1) = "";
lines(end + 1) = "## Strongest correlations";
for i = 1:height(topRows)
    lines(end + 1) = sprintf('- `%s` vs `%s` (%s): Pearson %.3f, Spearman %.3f, n=%d', ...
        topRows.coefficient(i), topRows.observable(i), topRows.matrix_name(i), ...
        topRows.pearson_r(i), topRows.spearman_rho(i), topRows.n_points(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
lines(end + 1) = "- Mode 1 vs dip amplitude: " + mode1Text;
lines(end + 1) = "- Mode 2 vs background-like observables: " + mode2Text;
lines(end + 1) = "- Mode 3 structure: " + mode3Text;
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- Number of curves/groups in each scatter: 4 wait-time groups.";
lines(end + 1) = "- Legend vs colormap: explicit legend, no colormap, because the group count is <= 6.";
lines(end + 1) = "- Colormap used: none for scatter plots.";
lines(end + 1) = "- Smoothing applied: none.";
lines(end + 1) = "- Justification: small-group overlays are clearer than colorbar encodings for these mode-observable checks.";
lines(end + 1) = "";
lines(end + 1) = "## Observable layer present in this run";
for i = 1:numel(obsVars)
    obsName = obsVars{i};
    nFinite = nnz(isfinite(joinedTbl.(obsName)));
    lines(end + 1) = sprintf('- `%s`: finite joined values = %d', obsName, nFinite);
end

lines(end + 1) = "";
lines(end + 1) = "## Notes";
lines(end + 1) = "- `Dip_width` was not found as a stored column in the legacy Aging runs; the available width-like variable is `Dip_sigma`.";
lines(end + 1) = "- Observable-mode correlations are computed separately for `raw_T` and `shifted_Tp`.";
lines(end + 1) = "- Interpretations above are inferences from the saved correlation table, not new pipeline observables.";

txt = strjoin(lines, newline);
end

function row = lookupBestRow(corrTbl, coeffName, obsName)
mask = corrTbl.coefficient == string(coeffName) & corrTbl.observable == string(obsName);
sub = corrTbl(mask, :);
if isempty(sub)
    row = table();
    return;
end
[~, idx] = max(sub.best_abs_correlation);
row = sub(idx, :);
end

function row = bestBackgroundRow(corrTbl, coeffName, obsList)
obsMask = false(height(corrTbl), 1);
for i = 1:numel(obsList)
    obsMask = obsMask | corrTbl.observable == string(obsList{i});
end
sub = corrTbl(corrTbl.coefficient == string(coeffName) & obsMask, :);
if isempty(sub)
    row = table();
    return;
end
[~, idx] = max(sub.best_abs_correlation);
row = sub(idx, :);
end

function row = bestModeRow(corrTbl, coeffName)
sub = corrTbl(corrTbl.coefficient == string(coeffName), :);
if isempty(sub)
    row = table();
    return;
end
[~, idx] = max(sub.best_abs_correlation);
row = sub(idx, :);
end

function txt = interpretMode1(mode1Dip)
if isempty(mode1Dip)
    txt = "no joined `coeff_mode1` / `Dip_depth` pair was available.";
    return;
end

if abs(mode1Dip.spearman_rho) >= 0.7 || abs(mode1Dip.pearson_r) >= 0.7
    txt = sprintf('strong link to `Dip_depth` in `%s` (Pearson %.3f, Spearman %.3f), consistent with mode 1 tracking dip amplitude.', ...
        mode1Dip.matrix_name, mode1Dip.pearson_r, mode1Dip.spearman_rho);
elseif abs(mode1Dip.spearman_rho) >= 0.4 || abs(mode1Dip.pearson_r) >= 0.4
    txt = sprintf('moderate link to `Dip_depth` in `%s` (Pearson %.3f, Spearman %.3f); this suggests partial amplitude tracking but not a clean one-parameter mapping.', ...
        mode1Dip.matrix_name, mode1Dip.pearson_r, mode1Dip.spearman_rho);
else
    txt = sprintf('weak link to `Dip_depth` in `%s` (Pearson %.3f, Spearman %.3f); mode 1 does not cleanly reduce to dip amplitude alone.', ...
        mode1Dip.matrix_name, mode1Dip.pearson_r, mode1Dip.spearman_rho);
end
end

function txt = interpretMode2(mode2Bg)
if isempty(mode2Bg)
    txt = "no background-like correlation could be computed for `coeff_mode2`.";
    return;
end

if abs(mode2Bg.best_abs_correlation) >= 0.6
    txt = sprintf('strongest with `%s` in `%s` (Pearson %.3f, Spearman %.3f), which supports a background-like amplitude interpretation.', ...
        mode2Bg.observable, mode2Bg.matrix_name, mode2Bg.pearson_r, mode2Bg.spearman_rho);
elseif abs(mode2Bg.best_abs_correlation) >= 0.35
    txt = sprintf('moderate with `%s` in `%s` (Pearson %.3f, Spearman %.3f); that is suggestive but not decisive for a background-amplitude assignment.', ...
        mode2Bg.observable, mode2Bg.matrix_name, mode2Bg.pearson_r, mode2Bg.spearman_rho);
else
    txt = sprintf('weak across `FM_abs`, `FM_E`, and `FM_step_mag`; strongest was `%s` in `%s` (Pearson %.3f, Spearman %.3f), so the background interpretation remains tentative.', ...
        mode2Bg.observable, mode2Bg.matrix_name, mode2Bg.pearson_r, mode2Bg.spearman_rho);
end
end

function txt = interpretMode3(mode3Best)
if isempty(mode3Best)
    txt = "no joined `coeff_mode3` correlations were available.";
    return;
end

if abs(mode3Best.best_abs_correlation) >= 0.55
    txt = sprintf('its strongest link is `%s` in `%s` (Pearson %.3f, Spearman %.3f), so mode 3 likely carries structured physics rather than pure noise.', ...
        mode3Best.observable, mode3Best.matrix_name, mode3Best.pearson_r, mode3Best.spearman_rho);
elseif abs(mode3Best.best_abs_correlation) >= 0.3
    txt = sprintf('it shows only a modest link to `%s` in `%s` (Pearson %.3f, Spearman %.3f), which suggests weak structure mixed with residual complexity.', ...
        mode3Best.observable, mode3Best.matrix_name, mode3Best.pearson_r, mode3Best.spearman_rho);
else
    txt = sprintf('all tested links are weak; strongest was `%s` in `%s` (Pearson %.3f, Spearman %.3f), so mode 3 looks mostly noise-like at the current observable level.', ...
        mode3Best.observable, mode3Best.matrix_name, mode3Best.pearson_r, mode3Best.spearman_rho);
end
end

function m = minWithNaN(x)
if isempty(x)
    m = NaN;
elseif all(~isfinite(x))
    m = NaN;
else
    m = min(x(isfinite(x)));
end
end

function m = maxWithNaN(x)
if isempty(x)
    m = NaN;
elseif all(~isfinite(x))
    m = NaN;
else
    m = max(x(isfinite(x)));
end
end
