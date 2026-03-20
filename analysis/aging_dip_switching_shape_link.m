function out = aging_dip_switching_shape_link(cfg)
% aging_dip_switching_shape_link
% Test whether Switching shape dynamics correspond to the Aging dip sector
% using saved run artifacts only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('aging:%s,%s,%s | switching:%s', ...
    char(source.agingDatasetRunName), ...
    char(source.agingCoeffRunName), ...
    char(source.agingTauRunName), ...
    char(source.switchingChiRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Aging dip <-> Switching shape run directory:\n%s\n', runDir);
fprintf('Aging dataset source run: %s\n', char(source.agingDatasetRunName));
fprintf('Aging coeff source run: %s\n', char(source.agingCoeffRunName));
fprintf('Aging tau source run: %s\n', char(source.agingTauRunName));
fprintf('Switching chi source run: %s\n', char(source.switchingChiRunName));

appendText(run.log_path, sprintf('[%s] aging_dip_switching_shape_link started\n', stampNow()));
appendText(run.log_path, sprintf('Aging dataset source: %s\n', char(source.agingDatasetPath)));
appendText(run.log_path, sprintf('Aging coeff source: %s\n', char(source.agingCoeffPath)));
appendText(run.log_path, sprintf('Aging tau source: %s\n', char(source.agingTauPath)));
appendText(run.log_path, sprintf('Switching chi source: %s\n', char(source.switchingChiPath)));

aging = loadAgingObservables(source);
switching = loadSwitchingObservables(source);
[comparisonTbl, overlayTbl, verdict] = compareObservables(aging, switching);
peakTbl = buildPeakTable(aging, switching);
agingTbl = buildObservableTable(aging);
switchTbl = buildObservableTable(switching);
sourceTbl = buildSourceManifest(source, aging);

agingPath = save_run_table(agingTbl, 'aging_observables_vs_temperature.csv', runDir);
switchPath = save_run_table(switchTbl, 'switching_shape_observables_vs_temperature.csv', runDir);
comparisonPath = save_run_table(comparisonTbl, 'dip_shape_correlation_table.csv', runDir);
peakPath = save_run_table(peakTbl, 'dip_shape_peak_comparison.csv', runDir);
overlayPath = save_run_table(overlayTbl, 'dip_shape_aligned_overlays.csv', runDir);
sourcePath = save_run_table(sourceTbl, 'source_run_manifest.csv', runDir);

figShape = saveOverlayFamilyFigure(aging, switching, comparisonTbl, "chi_shape", ...
    'Normalized overlays: chi_shape(T) vs Aging dip-sector observables', ...
    runDir, 'chi_shape_vs_aging_dip_sector_overlays');
figDyn = saveOverlayFamilyFigure(aging, switching, comparisonTbl, "chi_dyn", ...
    'Normalized overlays: chi_dyn(T) vs Aging dip-sector observables', ...
    runDir, 'chi_dyn_vs_aging_dip_sector_overlays');
figStrength = saveCorrelationStrengthFigure(comparisonTbl, runDir, ...
    'shape_vs_dyn_correlation_strength_summary');

reportText = buildReportText(thisFile, source, aging, switching, comparisonTbl, peakTbl, verdict, runDir);
reportPath = save_run_report(reportText, 'aging_dip_switching_shape_link_report.md', runDir);
zipPath = buildReviewZip(runDir, 'aging_dip_switching_shape_link_bundle.zip');

appendText(run.notes_path, sprintf('Overall verdict: %s\n', char(verdict.overall)));
appendText(run.notes_path, sprintf('Shape-favored observables: %d\n', verdict.nShapeFavored));
appendText(run.notes_path, sprintf('Dynamic-favored observables: %d\n', verdict.nDynFavored));
appendText(run.log_path, sprintf('[%s] aging_dip_switching_shape_link complete\n', stampNow()));
appendText(run.log_path, sprintf('Aging table: %s\n', agingPath));
appendText(run.log_path, sprintf('Switching table: %s\n', switchPath));
appendText(run.log_path, sprintf('Comparison table: %s\n', comparisonPath));
appendText(run.log_path, sprintf('Peak table: %s\n', peakPath));
appendText(run.log_path, sprintf('Overlay table: %s\n', overlayPath));
appendText(run.log_path, sprintf('Source table: %s\n', sourcePath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.aging = aging;
out.switching = switching;
out.tables = struct( ...
    'aging', string(agingPath), ...
    'switching', string(switchPath), ...
    'comparison', string(comparisonPath), ...
    'peak', string(peakPath), ...
    'overlay', string(overlayPath), ...
    'source', string(sourcePath));
out.figures = struct( ...
    'shape_overlay', string(figShape.png), ...
    'dyn_overlay', string(figDyn.png), ...
    'strength_summary', string(figStrength.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.verdict = verdict;
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'aging_dip_switching_shape_link');
cfg = setDefaultField(cfg, 'agingDatasetRunName', 'run_2026_03_12_211204_aging_dataset_build');
cfg = setDefaultField(cfg, 'agingCoeffRunName', 'run_2026_03_10_200643_observable_mode_correlation');
cfg = setDefaultField(cfg, 'agingTauRunName', 'run_2026_03_12_223709_aging_timescale_extraction');
cfg = setDefaultField(cfg, 'switchingChiRunName', 'run_2026_03_14_121511_switching_chi_shift_shape_decomposition');
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.agingDatasetRunName = string(cfg.agingDatasetRunName);
source.agingCoeffRunName = string(cfg.agingCoeffRunName);
source.agingTauRunName = string(cfg.agingTauRunName);
source.switchingChiRunName = string(cfg.switchingChiRunName);

source.agingDatasetRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.agingDatasetRunName));
source.agingCoeffRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.agingCoeffRunName));
source.agingTauRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.agingTauRunName));
source.switchingChiRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.switchingChiRunName));

source.agingDatasetPath = string(fullfile(source.agingDatasetRunDir, 'tables', 'aging_observable_dataset.csv'));
source.agingCoeffPath = string(fullfile(source.agingCoeffRunDir, 'tables', 'svd_mode_coefficients.csv'));
source.agingTauPath = string(fullfile(source.agingTauRunDir, 'tables', 'tau_vs_Tp.csv'));
source.switchingChiPath = string(fullfile(source.switchingChiRunDir, 'tables', 'chi_decomposition_vs_T.csv'));

requiredFiles = { ...
    char(source.agingDatasetPath), ...
    char(source.agingCoeffPath), ...
    char(source.agingTauPath), ...
    char(source.switchingChiPath)};
for i = 1:numel(requiredFiles)
    if exist(requiredFiles{i}, 'file') ~= 2
        error('Required source file not found: %s', requiredFiles{i});
    end
end
end

function aging = loadAgingObservables(source)
datasetTbl = readtable(char(source.agingDatasetPath), 'VariableNamingRule', 'preserve', 'Delimiter', ',');
coeffTbl = readtable(char(source.agingCoeffPath), 'VariableNamingRule', 'preserve', 'Delimiter', ',');
tauTbl = readtable(char(source.agingTauPath), 'VariableNamingRule', 'preserve', 'Delimiter', ',');

datasetTbl = standardizeVariableNames(makeNumericColumns(datasetTbl));
coeffTbl = standardizeVariableNames(makeNumericColumns(coeffTbl));
tauTbl = standardizeVariableNames(makeNumericColumns(tauTbl));

dip = aggregateByTemperature(datasetTbl.Tp, datasetTbl.Dip_depth, 'Dip_depth', ...
    'Aging dip depth (median over t_w)', 'arb.');

coeffMatrix = chooseCoeffMatrix(coeffTbl);
coeffMask = true(height(coeffTbl), 1);
if ismember('matrix_name', coeffTbl.Properties.VariableNames)
    coeffMask = strcmp(string(coeffTbl.matrix_name), coeffMatrix);
end
coeffRaw = aggregateByTemperature(coeffTbl.Tp(coeffMask), coeffTbl.coeff_mode1(coeffMask), ...
    'coeff_mode1', sprintf('Aging coeff mode 1 (%s, median over t_w)', coeffMatrix), 'arb.');

dipOnCoeff = interp1(dip.T, dip.values, coeffRaw.T, 'linear', NaN);
coeffCorr = corrSafe(coeffRaw.values, dipOnCoeff, 'Pearson');
orientationSign = 1;
if isfinite(coeffCorr) && coeffCorr < 0
    orientationSign = -1;
end
coeff = coeffRaw;
coeff.values = orientationSign * coeffRaw.values;
coeff.note = sprintf('Sign %s to align with Dip_depth orientation.', ternary(orientationSign < 0, 'flipped', 'kept'));

tauMask = isfinite(tauTbl.Tp) & isfinite(tauTbl.tau_effective_seconds) & tauTbl.tau_effective_seconds > 0;
tau = makeObservable( ...
    'tau_dip', ...
    'Aging tau_dip(T_p) from tau_effective_seconds', ...
    double(tauTbl.Tp(tauMask)), ...
    double(tauTbl.tau_effective_seconds(tauMask)), ...
    's', ...
    source.agingTauRunName, ...
    "tau_effective_seconds from dip timescale extraction", ...
    ones(nnz(tauMask), 1));
tau = sortObservable(tau);

aging = struct();
aging.list = [conformObservable(dip); conformObservable(coeff); conformObservable(tau)];
aging.coeff_matrix = coeffMatrix;
aging.coeff_orientation_corr = coeffCorr;
end

function switching = loadSwitchingObservables(source)
tbl = readtable(char(source.switchingChiPath), 'VariableNamingRule', 'preserve', 'Delimiter', ',');
tbl = standardizeVariableNames(makeNumericColumns(tbl));

shapeMask = isfinite(tbl.T_K) & isfinite(tbl.chi_shape);
dynMask = isfinite(tbl.T_K) & isfinite(tbl.chi_dyn);

chiShape = makeObservable( ...
    'chi_shape', ...
    'Switching chi_shape(T)', ...
    double(tbl.T_K(shapeMask)), ...
    double(tbl.chi_shape(shapeMask)), ...
    'signal/K', ...
    source.switchingChiRunName, ...
    "", ...
    ones(nnz(shapeMask), 1));
chiDyn = makeObservable( ...
    'chi_dyn', ...
    'Switching chi_dyn(T)', ...
    double(tbl.T_K(dynMask)), ...
    double(tbl.chi_dyn(dynMask)), ...
    'signal/K', ...
    source.switchingChiRunName, ...
    "", ...
    ones(nnz(dynMask), 1));

switching = struct();
switching.list = [conformObservable(sortObservable(chiShape)); conformObservable(sortObservable(chiDyn))];
end

function obs = aggregateByTemperature(T, values, key, label, units)
T = double(T(:));
values = double(values(:));
mask = isfinite(T);
T = T(mask);
values = values(mask);
[Tu, ~, g] = unique(T);
n = splitapply(@(x) sum(isfinite(x)), values, g);
med = splitapply(@medianNoNan, values, g);
obs = makeObservable( ...
    key, ...
    label, ...
    Tu(:), ...
    med(:), ...
    units, ...
    "", ...
    "median aggregation over available wait times", ...
    n(:));
obs = sortObservable(obs);
end

function obs = makeObservable(key, label, T, values, units, sourceRun, note, nCounts)
obs = struct();
obs.key = string(key);
obs.label = string(label);
obs.T = double(T(:));
obs.values = double(values(:));
obs.units = string(units);
obs.source_run = string(sourceRun);
obs.note = string(note);
obs.n_counts = double(nCounts(:));
end

function obs = conformObservable(obs)
base = makeObservable("", "", [], [], "", "", "", []);
baseFields = fieldnames(base);
obsFields = fieldnames(obs);
extra = setdiff(obsFields, baseFields);
if ~isempty(extra)
    obs = rmfield(obs, extra);
end
for i = 1:numel(baseFields)
    fn = baseFields{i};
    if ~isfield(obs, fn)
        obs.(fn) = base.(fn);
    end
end
obs = orderfields(obs, base);
end

function obs = sortObservable(obs)
[obs.T, order] = sort(obs.T);
obs.values = obs.values(order);
if numel(obs.n_counts) == numel(order)
    obs.n_counts = obs.n_counts(order);
end
end

function coeffMatrix = chooseCoeffMatrix(coeffTbl)
coeffMatrix = "unspecified";
if ~ismember('matrix_name', coeffTbl.Properties.VariableNames)
    return;
end
available = unique(string(coeffTbl.matrix_name));
if any(available == "shifted_Tp")
    coeffMatrix = "shifted_Tp";
elseif any(available == "raw_T")
    coeffMatrix = "raw_T";
elseif ~isempty(available)
    coeffMatrix = available(1);
end
end

function [comparisonTbl, overlayTbl, verdict] = compareObservables(aging, switching)
rows = repmat(emptyComparisonRow(), 0, 1);
overlayRows = repmat(emptyOverlayRow(), 0, 1);

for ia = 1:numel(aging.list)
    aObs = aging.list(ia);
    for is = 1:numel(switching.list)
        sObs = switching.list(is);
        [Tover, aVals, sVals] = overlapVectors(aObs.T, aObs.values, sObs.T, sObs.values);
        aNorm = normalizeMinMax(aVals);
        sNorm = normalizeMinMax(sVals);

        row = emptyComparisonRow();
        row.aging_observable = aObs.key;
        row.switching_observable = sObs.key;
        row.n_overlap = numel(Tover);
        row.overlap_temperatures = joinNumbers(Tover);
        row.pearson_raw = corrSafe(aVals, sVals, 'Pearson');
        row.spearman_raw = corrSafe(aVals, sVals, 'Spearman');
        row.pearson_norm = corrSafe(aNorm, sNorm, 'Pearson');
        row.spearman_norm = corrSafe(aNorm, sNorm, 'Spearman');
        row.aging_peak_T_full = peakTemperature(aObs.T, aObs.values);
        row.switching_peak_T_full = peakTemperature(sObs.T, sObs.values);
        row.peak_delta_full_K = row.switching_peak_T_full - row.aging_peak_T_full;
        row.aging_peak_T_overlap = peakTemperature(Tover, aVals);
        row.switching_peak_T_overlap = peakTemperature(Tover, sVals);
        row.peak_delta_overlap_K = row.switching_peak_T_overlap - row.aging_peak_T_overlap;
        row.aging_source_run = aObs.source_run;
        row.switching_source_run = sObs.source_run;
        rows(end + 1, 1) = row; %#ok<AGROW>

        for k = 1:numel(Tover)
            orow = emptyOverlayRow();
            orow.aging_observable = aObs.key;
            orow.switching_observable = sObs.key;
            orow.T_K = Tover(k);
            orow.aging_value = aVals(k);
            orow.switching_value = sVals(k);
            orow.aging_norm = aNorm(k);
            orow.switching_norm = sNorm(k);
            overlayRows(end + 1, 1) = orow; %#ok<AGROW>
        end
    end
end

comparisonTbl = struct2table(rows);
overlayTbl = struct2table(overlayRows);
verdict = evaluateShapeResemblance(comparisonTbl, unique(comparisonTbl.aging_observable));
end

function verdict = evaluateShapeResemblance(comparisonTbl, agingKeys)
detailRows = strings(0, 1);
nShape = 0;
nDyn = 0;
nTie = 0;

for i = 1:numel(agingKeys)
    key = agingKeys(i);
    shapeRow = comparisonTbl(comparisonTbl.aging_observable == key & comparisonTbl.switching_observable == "chi_shape", :);
    dynRow = comparisonTbl(comparisonTbl.aging_observable == key & comparisonTbl.switching_observable == "chi_dyn", :);
    if isempty(shapeRow) || isempty(dynRow)
        continue;
    end

    shapeScore = resemblanceScore(shapeRow);
    dynScore = resemblanceScore(dynRow);
    if shapeScore > dynScore + 1e-9
        winner = "chi_shape";
        nShape = nShape + 1;
    elseif dynScore > shapeScore + 1e-9
        winner = "chi_dyn";
        nDyn = nDyn + 1;
    else
        winner = "tie";
        nTie = nTie + 1;
    end

    detailRows(end + 1, 1) = sprintf('%s: shape_score=%.4f, dyn_score=%.4f, winner=%s', ...
        key, shapeScore, dynScore, winner);
end

overall = "mixed evidence";
if nShape >= 2 && nShape > nDyn
    overall = "supports shape-sector correspondence";
elseif nDyn >= 2 && nDyn > nShape
    overall = "does not support shape-sector correspondence";
end

verdict = struct();
verdict.overall = overall;
verdict.nShapeFavored = nShape;
verdict.nDynFavored = nDyn;
verdict.nTied = nTie;
verdict.detail_lines = detailRows;
end

function score = resemblanceScore(row)
score = NaN;
if isempty(row)
    return;
end
r1 = row.pearson_norm(1);
r2 = row.spearman_norm(1);
if ~(isfinite(r1) || isfinite(r2))
    r1 = row.pearson_raw(1);
    r2 = row.spearman_raw(1);
end
if ~isfinite(r1), r1 = 0; end
if ~isfinite(r2), r2 = 0; end
peakPenalty = abs(row.peak_delta_overlap_K(1));
if ~isfinite(peakPenalty), peakPenalty = 10; end
score = abs(r1) + abs(r2) - 0.05 * peakPenalty;
end

function peakTbl = buildPeakTable(aging, switching)
rows = repmat(struct('observable',"",'sector',"",'peak_T_K',NaN,'peak_value',NaN,'units',""), 0, 1);
for i = 1:numel(aging.list)
    obs = aging.list(i);
    [pkT, pkV] = peakLocation(obs.T, obs.values);
    rows(end + 1, 1) = struct('observable', obs.key, 'sector', "aging", 'peak_T_K', pkT, 'peak_value', pkV, 'units', obs.units); %#ok<AGROW>
end
for i = 1:numel(switching.list)
    obs = switching.list(i);
    [pkT, pkV] = peakLocation(obs.T, obs.values);
    rows(end + 1, 1) = struct('observable', obs.key, 'sector', "switching", 'peak_T_K', pkT, 'peak_value', pkV, 'units', obs.units); %#ok<AGROW>
end
peakTbl = struct2table(rows);
end

function tbl = buildObservableTable(group)
rows = repmat(struct('observable',"",'T_K',NaN,'value',NaN,'units',"",'source_run',"",'n_contributing_points',NaN,'note',""), 0, 1);
for i = 1:numel(group.list)
    obs = group.list(i);
    for k = 1:numel(obs.T)
        row = struct();
        row.observable = obs.key;
        row.T_K = obs.T(k);
        row.value = obs.values(k);
        row.units = obs.units;
        row.source_run = obs.source_run;
        if k <= numel(obs.n_counts)
            row.n_contributing_points = obs.n_counts(k);
        else
            row.n_contributing_points = NaN;
        end
        row.note = obs.note;
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
end
tbl = struct2table(rows);
end

function tbl = buildSourceManifest(source, aging)
tbl = table( ...
    ["aging"; "aging"; "aging"; "cross_experiment"], ...
    [source.agingDatasetRunName; source.agingCoeffRunName; source.agingTauRunName; source.switchingChiRunName], ...
    [source.agingDatasetPath; source.agingCoeffPath; source.agingTauPath; source.switchingChiPath], ...
    ["Dip_depth source"; sprintf('coeff_mode1 source (%s)', aging.coeff_matrix); "tau_dip source"; "chi_shape and chi_dyn source"], ...
    'VariableNames', {'experiment', 'source_run', 'source_file', 'role'});
end

function figPaths = saveOverlayFamilyFigure(aging, switching, comparisonTbl, switchingKey, mainTitle, runDir, figureName)
sObs = findObservable(switching.list, switchingKey);
fig = create_figure('Visible', 'off', 'Position', [2 2 16.8 12.0]);
tl = tiledlayout(fig, numel(aging.list), 1, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numel(aging.list)
    aObs = aging.list(i);
    ax = nexttile(tl, i);
    [Tover, aVals, sVals] = overlapVectors(aObs.T, aObs.values, sObs.T, sObs.values);
    aNorm = normalizeMinMax(aVals);
    sNorm = normalizeMinMax(sVals);
    hold(ax, 'on');
    plot(ax, Tover, aNorm, '-o', 'LineWidth', 2.2, 'MarkerSize', 5.5, ...
        'Color', [0.00 0.45 0.74], 'DisplayName', char(aObs.key));
    plot(ax, Tover, sNorm, '-s', 'LineWidth', 2.2, 'MarkerSize', 5.5, ...
        'Color', [0.85 0.33 0.10], 'DisplayName', char(sObs.key));
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, 'Temperature (K)');
    ylabel(ax, 'Normalized magnitude');
    row = comparisonTbl(comparisonTbl.aging_observable == aObs.key & comparisonTbl.switching_observable == sObs.key, :);
    if ~isempty(row)
        title(ax, sprintf('%s vs %s: Pearson=%.3f, Spearman=%.3f, peak delta=%.1f K', ...
            aObs.key, sObs.key, row.pearson_raw(1), row.spearman_raw(1), row.peak_delta_overlap_K(1)));
    else
        title(ax, sprintf('%s vs %s', aObs.key, sObs.key));
    end
    legend(ax, 'Location', 'best', 'Box', 'off');
    styleAxes(ax);
end
title(tl, mainTitle, 'FontSize', 16, 'FontWeight', 'bold');
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveCorrelationStrengthFigure(comparisonTbl, runDir, figureName)
agingKeys = unique(comparisonTbl.aging_observable, 'stable');
pearsonShape = NaN(numel(agingKeys), 1);
pearsonDyn = NaN(numel(agingKeys), 1);
spearmanShape = NaN(numel(agingKeys), 1);
spearmanDyn = NaN(numel(agingKeys), 1);

for i = 1:numel(agingKeys)
    key = agingKeys(i);
    rShape = comparisonTbl(comparisonTbl.aging_observable == key & comparisonTbl.switching_observable == "chi_shape", :);
    rDyn = comparisonTbl(comparisonTbl.aging_observable == key & comparisonTbl.switching_observable == "chi_dyn", :);
    if ~isempty(rShape)
        pearsonShape(i) = abs(rShape.pearson_norm(1));
        spearmanShape(i) = abs(rShape.spearman_norm(1));
    end
    if ~isempty(rDyn)
        pearsonDyn(i) = abs(rDyn.pearson_norm(1));
        spearmanDyn(i) = abs(rDyn.spearman_norm(1));
    end
end

fig = create_figure('Visible', 'off', 'Position', [2 2 16.0 10.0]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
bar(ax1, [pearsonShape pearsonDyn], 'grouped');
grid(ax1, 'on');
set(ax1, 'XTick', 1:numel(agingKeys), 'XTickLabel', cellstr(agingKeys));
ylabel(ax1, '|Normalized Pearson|');
title(ax1, 'Absolute normalized Pearson correlation');
legend(ax1, {'chi\_shape', 'chi\_dyn'}, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
styleAxes(ax1);

ax2 = nexttile(tl, 2);
bar(ax2, [spearmanShape spearmanDyn], 'grouped');
grid(ax2, 'on');
set(ax2, 'XTick', 1:numel(agingKeys), 'XTickLabel', cellstr(agingKeys));
ylabel(ax2, '|Normalized Spearman|');
xlabel(ax2, 'Aging observable');
title(ax2, 'Absolute normalized Spearman correlation');
legend(ax2, {'chi\_shape', 'chi\_dyn'}, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
styleAxes(ax2);

title(tl, 'Shape-vs-dynamic resemblance strength by Aging observable', ...
    'FontSize', 16, 'FontWeight', 'bold');
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function reportText = buildReportText(thisFile, source, aging, switching, comparisonTbl, peakTbl, verdict, runDir)
lines = strings(0, 1);
lines(end + 1) = '# Aging dip sector vs Switching shape sector';
lines(end + 1) = '';
lines(end + 1) = sprintf('Generated: %s', stampNow());
lines(end + 1) = sprintf('Run root: `%s`', runDir);
lines(end + 1) = '';
lines(end + 1) = '## Repository-state summary';
lines(end + 1) = sprintf('- New script: `%s`', thisFile);
lines(end + 1) = '- Reused saved outputs only; no source pipeline reruns.';
lines(end + 1) = sprintf('- Aging Dip_depth source run: `%s`', source.agingDatasetRunName);
lines(end + 1) = sprintf('- Aging coeff_mode1 source run: `%s`', source.agingCoeffRunName);
lines(end + 1) = sprintf('- Aging tau_dip source run: `%s`', source.agingTauRunName);
lines(end + 1) = sprintf('- Switching chi source run: `%s`', source.switchingChiRunName);
lines(end + 1) = '';
lines(end + 1) = '## Observable definitions used';
lines(end + 1) = '- `Dip_depth(T_p)`: median across available waiting times at each `T_p`.';
lines(end + 1) = sprintf('- `coeff_mode1(T_p)`: median across waiting times from `%s` basis with oriented sign to match Dip_depth direction.', aging.coeff_matrix);
lines(end + 1) = '- `tau_dip(T_p)`: `tau_effective_seconds` from dip timescale extraction.';
lines(end + 1) = '- `chi_shape(T)` and `chi_dyn(T)`: from switching chi decomposition table.';
lines(end + 1) = '';
lines(end + 1) = '## Temperature-axis alignment';
lines(end + 1) = '- Pairwise comparisons use exact overlap temperatures between each Aging observable and each Switching observable.';
for i = 1:height(comparisonTbl)
    lines(end + 1) = sprintf('- `%s` vs `%s`: overlap temperatures `%s` (n=%d).', ...
        comparisonTbl.aging_observable(i), comparisonTbl.switching_observable(i), ...
        comparisonTbl.overlap_temperatures(i), comparisonTbl.n_overlap(i));
end
lines(end + 1) = '';
lines(end + 1) = '## Correlations';
for i = 1:height(comparisonTbl)
    lines(end + 1) = sprintf('- `%s` vs `%s`: Pearson=%.4f, Spearman=%.4f, normalized Pearson=%.4f, normalized Spearman=%.4f.', ...
        comparisonTbl.aging_observable(i), comparisonTbl.switching_observable(i), ...
        comparisonTbl.pearson_raw(i), comparisonTbl.spearman_raw(i), ...
        comparisonTbl.pearson_norm(i), comparisonTbl.spearman_norm(i));
end
lines(end + 1) = '';
lines(end + 1) = '## Peak-temperature comparison';
for i = 1:height(comparisonTbl)
    lines(end + 1) = sprintf('- `%s` vs `%s`: full-curve peak delta (switching-aging)=%.2f K; overlap peak delta=%.2f K.', ...
        comparisonTbl.aging_observable(i), comparisonTbl.switching_observable(i), ...
        comparisonTbl.peak_delta_full_K(i), comparisonTbl.peak_delta_overlap_K(i));
end
lines(end + 1) = '';
lines(end + 1) = '## Sector correspondence verdict';
for i = 1:numel(verdict.detail_lines)
    lines(end + 1) = "- " + verdict.detail_lines(i);
end
lines(end + 1) = sprintf('- Shape-favored observables: %d, dyn-favored observables: %d, ties: %d.', ...
    verdict.nShapeFavored, verdict.nDynFavored, verdict.nTied);
lines(end + 1) = sprintf('- Overall conclusion: **%s**.', verdict.overall);
lines(end + 1) = '';
lines(end + 1) = '## Outputs';
lines(end + 1) = '- `tables/aging_observables_vs_temperature.csv`';
lines(end + 1) = '- `tables/switching_shape_observables_vs_temperature.csv`';
lines(end + 1) = '- `tables/dip_shape_correlation_table.csv`';
lines(end + 1) = '- `tables/dip_shape_peak_comparison.csv`';
lines(end + 1) = '- `tables/dip_shape_aligned_overlays.csv`';
lines(end + 1) = '- `figures/chi_shape_vs_aging_dip_sector_overlays.*`';
lines(end + 1) = '- `figures/chi_dyn_vs_aging_dip_sector_overlays.*`';
lines(end + 1) = '- `figures/shape_vs_dyn_correlation_strength_summary.*`';
lines(end + 1) = '- `review/aging_dip_switching_shape_link_bundle.zip`';
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- number of curves: each overlay panel has two curves; each family figure has three panels.';
lines(end + 1) = '- legend vs colormap: legends only (two curves per panel).';
lines(end + 1) = '- colormap used: none (line plots and grouped bars).';
lines(end + 1) = '- smoothing applied: none; normalization is min-max scaling over overlap points only.';
lines(end + 1) = '- justification: direct pair overlays make the shape-vs-dyn sector comparison explicit for each Aging observable.';
lines(end + 1) = '';
lines(end + 1) = '## Notes and limits';
lines(end + 1) = '- `coeff_mode1` sign is convention-dependent and was oriented for comparison clarity.';
lines(end + 1) = '- High-temperature Aging points can be sparse for some observables, so overlap size remains limited.';

if ~isempty(peakTbl)
    lines(end + 1) = '';
    lines(end + 1) = '## Peak summary';
    for i = 1:height(peakTbl)
        lines(end + 1) = sprintf('- `%s` (%s): peak at %.2f K, value %.4g %s.', ...
            peakTbl.observable(i), peakTbl.sector(i), peakTbl.peak_T_K(i), ...
            peakTbl.peak_value(i), peakTbl.units(i));
    end
end

reportText = strjoin(lines, newline);
end

function obs = findObservable(obsList, key)
idx = find(string({obsList.key}) == string(key), 1, 'first');
if isempty(idx)
    error('Observable not found: %s', key);
end
obs = obsList(idx);
end

function [Tov, x, y] = overlapVectors(T1, x1, T2, y2)
t1 = table(double(T1(:)), double(x1(:)), 'VariableNames', {'T', 'x'});
t2 = table(double(T2(:)), double(y2(:)), 'VariableNames', {'T', 'y'});
t = innerjoin(t1, t2, 'Keys', 'T');
t = t(isfinite(t.x) & isfinite(t.y), :);
t = sortrows(t, 'T');
Tov = t.T;
x = t.x;
y = t.y;
end

function [pkT, pkV] = peakLocation(T, values)
pkT = NaN;
pkV = NaN;
mask = isfinite(T) & isfinite(values);
if ~any(mask)
    return;
end
[pkV, idx] = max(values(mask));
Tv = T(mask);
pkT = Tv(idx);
end

function Tpk = peakTemperature(T, values)
[Tpk, ~] = peakLocation(T, values);
end

function y = normalizeMinMax(x)
x = double(x(:));
y = NaN(size(x));
mask = isfinite(x);
if ~any(mask)
    return;
end
xm = min(x(mask));
xM = max(x(mask));
if ~(isfinite(xm) && isfinite(xM)) || xM <= xm
    y(mask) = 0;
else
    y(mask) = (x(mask) - xm) ./ (xM - xm);
end
end

function r = corrSafe(x, y, corrType)
if nargin < 3
    corrType = 'Pearson';
end
r = NaN;
x = double(x(:));
y = double(y(:));
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 3
    return;
end
x = x(mask);
y = y(mask);
if strcmpi(corrType, 'Spearman')
    x = tiedRank(x);
    y = tiedRank(y);
end
c = corrcoef(x, y);
if numel(c) >= 4
    r = c(1, 2);
end
end

function ranks = tiedRank(x)
[xs, order] = sort(x);
ranks = zeros(size(x));
i = 1;
while i <= numel(xs)
    j = i;
    while j < numel(xs) && xs(j + 1) == xs(i)
        j = j + 1;
    end
    ranks(order(i:j)) = mean(i:j);
    i = j + 1;
end
end

function s = joinNumbers(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
    s = "";
    return;
end
parts = strings(numel(x), 1);
for i = 1:numel(x)
    if abs(x(i) - round(x(i))) < 1e-9
        parts(i) = sprintf('%.0f', x(i));
    else
        parts(i) = sprintf('%.3g', x(i));
    end
end
s = strjoin(parts.', ', ');
end

function row = emptyComparisonRow()
row = struct( ...
    'aging_observable', "", ...
    'switching_observable', "", ...
    'n_overlap', 0, ...
    'overlap_temperatures', "", ...
    'pearson_raw', NaN, ...
    'spearman_raw', NaN, ...
    'pearson_norm', NaN, ...
    'spearman_norm', NaN, ...
    'aging_peak_T_full', NaN, ...
    'switching_peak_T_full', NaN, ...
    'peak_delta_full_K', NaN, ...
    'aging_peak_T_overlap', NaN, ...
    'switching_peak_T_overlap', NaN, ...
    'peak_delta_overlap_K', NaN, ...
    'aging_source_run', "", ...
    'switching_source_run', "");
end

function row = emptyOverlayRow()
row = struct( ...
    'aging_observable', "", ...
    'switching_observable', "", ...
    'T_K', NaN, ...
    'aging_value', NaN, ...
    'switching_value', NaN, ...
    'aging_norm', NaN, ...
    'switching_norm', NaN);
end

function out = medianNoNan(x)
x = x(isfinite(x));
if isempty(x)
    out = NaN;
else
    out = median(x);
end
end

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', 'FontSize', 14, 'LineWidth', 1.1, ...
    'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
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
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function tbl = standardizeVariableNames(tbl)
vars = string(tbl.Properties.VariableNames);
for i = 1:numel(vars)
    clean = regexprep(vars(i), '[^A-Za-z0-9_]', '');
    if strlength(clean) == 0
        continue;
    end
    vars(i) = clean;
end
tbl.Properties.VariableNames = matlab.lang.makeUniqueStrings(cellstr(vars));
end

function out = makeNumericColumns(tbl)
out = tbl;
for i = 1:numel(out.Properties.VariableNames)
    vn = out.Properties.VariableNames{i};
    col = out.(vn);
    if iscell(col) || isstring(col)
        num = str2double(string(col));
        if nnz(isfinite(num)) > 0
            out.(vn) = num;
        end
    end
end
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function out = setDefaultField(s, fieldName, defaultValue)
out = s;
if ~isfield(out, fieldName) || isempty(out.(fieldName))
    out.(fieldName) = defaultValue;
end
end

function out = ternary(condition, trueValue, falseValue)
if condition
    out = trueValue;
else
    out = falseValue;
end
end





