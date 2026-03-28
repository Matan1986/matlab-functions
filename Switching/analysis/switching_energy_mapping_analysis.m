function out = switching_energy_mapping_analysis(cfg)
% switching_energy_mapping_analysis
% Convert P_T(I_th, T) from a prior switching run into P_T(E, T) with a
% minimal no-fit mapping E = alpha * I_th and canonical T <= 30 K window.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingDir = fileparts(analysisDir);
repoRoot = fileparts(switchingDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

cfg = applyDefaults(cfg);
source = resolvePTSourceRun(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('pt_source:%s', char(source.runId));
runCfg.sourceRunId = char(source.runId);
run = createRunContext('switching', runCfg);
runDir = run.run_dir;
ensureArtifactDirs(runDir);

fprintf('Energy-mapping run directory:\n%s\n', runDir);
fprintf('PT source run: %s\n', source.runId);
fprintf('PT matrix path: %s\n', source.ptMatrixPath);

appendText(run.log_path, sprintf('[%s] switching_energy_mapping_analysis started', stampNow()));
appendText(run.log_path, sprintf('Source run: %s', source.runId));
appendText(run.log_path, sprintf('Source PT matrix: %s', source.ptMatrixPath));
appendText(run.log_path, sprintf('Source PT summary: %s', source.ptSummaryPath));

[tempsAll, currents, PTall] = loadPTMatrix(source.ptMatrixPath);

canonicalMask = isfinite(tempsAll) & tempsAll <= cfg.canonicalTemperatureMaxK;
tempsCanonical = tempsAll(canonicalMask);
PTcanonical = PTall(canonicalMask, :);

if isempty(tempsCanonical)
    error('switching_energy_mapping_analysis:NoCanonicalRows', ...
        'No rows satisfy canonical temperature window T <= %.1f K.', cfg.canonicalTemperatureMaxK);
end

[statsCanonical, mapCanonical] = computeEnergyStats(tempsCanonical, currents, PTcanonical, cfg.alpha, 1.0);
robustness = runRobustnessCheck(tempsCanonical, currents, PTcanonical, cfg.alpha, cfg.robustnessGammas, statsCanonical);

energyStatsTbl = table( ...
    tempsCanonical(:), ...
    statsCanonical.mean_E(:), ...
    statsCanonical.std_E(:), ...
    statsCanonical.skew_E(:), ...
    'VariableNames', {'T', 'mean_E', 'std_E', 'skew'});

robustByTempTbl = buildRobustnessByTempTable(tempsCanonical, statsCanonical, robustness);
robustSummaryTbl = buildRobustnessSummaryTable(robustness);
sourceManifestTbl = buildSourceManifestTable(source, cfg, tempsAll, tempsCanonical);

energyStatsPath = save_run_table(energyStatsTbl, 'energy_stats.csv', runDir);
robustByTempPath = save_run_table(robustByTempTbl, 'energy_mapping_robustness_by_temperature.csv', runDir);
robustSummaryPath = save_run_table(robustSummaryTbl, 'energy_mapping_robustness_summary.csv', runDir);
sourceManifestPath = save_run_table(sourceManifestTbl, 'energy_mapping_source_manifest.csv', runDir);

figMeanPaths = saveMeanEnergyFigure(tempsCanonical, statsCanonical.mean_E, runDir);
figStdPaths = saveStdEnergyFigure(tempsCanonical, statsCanonical.std_E, runDir);
figCurvesPaths = saveRepresentativeCurvesFigure(tempsCanonical, mapCanonical, runDir, cfg);

reportText = buildReportText(cfg, source, tempsAll, statsCanonical, robustness, ...
    energyStatsPath, robustByTempPath, robustSummaryPath, figMeanPaths, figStdPaths, figCurvesPaths);
reportPath = save_run_report(reportText, 'energy_mapping_report.md', runDir);

zipPath = buildReviewZip(runDir, 'energy_mapping_bundle.zip');

appendText(run.notes_path, sprintf('Source run: %s', source.runId));
appendText(run.notes_path, sprintf('Canonical temperature window applied: T <= %.1f K', cfg.canonicalTemperatureMaxK));
appendText(run.notes_path, sprintf('Rows in canonical window: %d / %d', numel(tempsCanonical), numel(tempsAll)));
appendText(run.notes_path, sprintf('Mapping used: E = alpha * I_th, alpha = %.6g (no fitting)', cfg.alpha));
appendText(run.notes_path, sprintf('Robustness max relative change (mean_E): %.4f', robustness.max_rel_mean));
appendText(run.notes_path, sprintf('Robustness max relative change (std_E): %.4f', robustness.max_rel_std));

appendText(run.log_path, sprintf('Saved energy stats: %s', energyStatsPath));
appendText(run.log_path, sprintf('Saved robustness-by-temperature table: %s', robustByTempPath));
appendText(run.log_path, sprintf('Saved robustness summary table: %s', robustSummaryPath));
appendText(run.log_path, sprintf('Saved source manifest: %s', sourceManifestPath));
appendText(run.log_path, sprintf('Saved figure (mean_E_vs_T): %s', figMeanPaths.png));
appendText(run.log_path, sprintf('Saved figure (std_E_vs_T): %s', figStdPaths.png));
if strlength(figCurvesPaths.png) > 0
    appendText(run.log_path, sprintf('Saved figure (representative curves): %s', figCurvesPaths.png));
end
appendText(run.log_path, sprintf('Saved report: %s', reportPath));
appendText(run.log_path, sprintf('Saved review ZIP: %s', zipPath));
appendText(run.log_path, sprintf('[%s] switching_energy_mapping_analysis complete', stampNow()));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.temps_all = tempsAll(:);
out.temps_canonical = tempsCanonical(:);
out.currents = currents(:);
out.energy_stats = energyStatsTbl;
out.robustness = robustness;
out.paths = struct( ...
    'energy_stats', string(energyStatsPath), ...
    'robustness_by_temperature', string(robustByTempPath), ...
    'robustness_summary', string(robustSummaryPath), ...
    'source_manifest', string(sourceManifestPath), ...
    'mean_E_figure', string(figMeanPaths.png), ...
    'std_E_figure', string(figStdPaths.png), ...
    'representative_curves_figure', string(figCurvesPaths.png), ...
    'report', string(reportPath), ...
    'review_zip', string(zipPath));

fprintf('\n=== switching_energy_mapping_analysis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Source run: %s\n', source.runId);
fprintf('Canonical rows: %d / %d (T <= %.1f K)\n', numel(tempsCanonical), numel(tempsAll), cfg.canonicalTemperatureMaxK);
fprintf('energy_stats.csv: %s\n', energyStatsPath);
fprintf('mean_E figure: %s\n', figMeanPaths.png);
fprintf('std_E figure: %s\n', figStdPaths.png);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'energy_mapping');
cfg = setDefaultField(cfg, 'canonicalTemperatureMaxK', 30);
cfg = setDefaultField(cfg, 'alpha', 1.0);
cfg = setDefaultField(cfg, 'robustnessGammas', [0.95, 1.05]);
cfg = setDefaultField(cfg, 'representativeTemperaturesK', [4, 10, 16, 22, 28, 30]);
cfg = setDefaultField(cfg, 'maxRepresentativeCurves', 6);
end

function source = resolvePTSourceRun(repoRoot, cfg)
runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');
if exist(runsRoot, 'dir') ~= 7
    error('switching_energy_mapping_analysis:MissingRunsRoot', 'Missing runs root: %s', runsRoot);
end

candidateRunIds = strings(0, 1);

if isfield(cfg, 'sourceRunId') && strlength(string(cfg.sourceRunId)) > 0
    candidateRunIds(end + 1) = string(cfg.sourceRunId); %#ok<AGROW>
end

try
    latestRunId = string(getLatestRun('switching'));
    if strlength(latestRunId) > 0
        candidateRunIds(end + 1) = latestRunId; %#ok<AGROW>
    end
catch
    % Fallback handled below by list_runs and direct scan.
end

try
    runsTbl = list_runs('switching');
    if istable(runsTbl) && ismember('run_id', runsTbl.Properties.VariableNames)
        ids = string(runsTbl.run_id);
        ids = ids(strlength(ids) > 0);
        candidateRunIds = [candidateRunIds; ids]; %#ok<AGROW>
    end
catch
    % Fallback handled below by direct scan.
end

candidateRunIds = unique(candidateRunIds, 'stable');

if isempty(candidateRunIds)
    d = dir(fullfile(runsRoot, 'run_*'));
    d = d([d.isdir]);
    [~, order] = sort({d.name}, 'descend');
    d = d(order);
    candidateRunIds = string({d.name}).';
end

for i = 1:numel(candidateRunIds)
    runId = candidateRunIds(i);
    runDir = fullfile(runsRoot, char(runId));
    ptMatrixPath = fullfile(runDir, 'tables', 'PT_matrix.csv');
    ptSummaryPath = fullfile(runDir, 'tables', 'PT_summary.csv');
    if exist(ptMatrixPath, 'file') ~= 2 || exist(ptSummaryPath, 'file') ~= 2
        continue;
    end

    try
        tbl = readtable(ptMatrixPath, 'VariableNamingRule', 'preserve');
        if ~ismember('T_K', tbl.Properties.VariableNames) || width(tbl) < 2
            continue;
        end
    catch
        continue;
    end

    source = struct();
    source.runId = runId;
    source.runDir = string(runDir);
    source.ptMatrixPath = string(ptMatrixPath);
    source.ptSummaryPath = string(ptSummaryPath);
    return;
end

error('switching_energy_mapping_analysis:NoValidPTSource', ...
    'No switching run was found with both tables/PT_matrix.csv and tables/PT_summary.csv.');
end

function [temps, currents, PT] = loadPTMatrix(ptMatrixPath)
tbl = readtable(char(ptMatrixPath), 'VariableNamingRule', 'preserve');
assert(ismember('T_K', tbl.Properties.VariableNames), 'PT_matrix.csv is missing required column T_K.');

varNames = tbl.Properties.VariableNames;
ptVarNames = setdiff(varNames, {'T_K'}, 'stable');
assert(~isempty(ptVarNames), 'PT_matrix.csv contains no Ith_* columns.');

temps = double(tbl.T_K(:));
PT = table2array(tbl(:, ptVarNames));
PT = double(PT);
currents = parseCurrentGrid(ptVarNames);

[currents, iOrder] = sort(currents(:), 'ascend');
PT = PT(:, iOrder);

[temps, tOrder] = sort(temps(:), 'ascend');
PT = PT(tOrder, :);
end

function currents = parseCurrentGrid(varNames)
n = numel(varNames);
currents = NaN(n, 1);

for i = 1:n
    vName = string(varNames{i});
    token = regexp(vName, '^Ith_(.*)_mA$', 'tokens', 'once');
    assert(~isempty(token), 'Unexpected PT column name: %s', vName);
    raw = string(token{1});

    candidates = [ ...
        raw; ...
        strrep(raw, "_", "."); ...
        strrep(raw, "_", ""); ...
        regexprep(raw, '_+', '.'); ...
        regexprep(raw, '_+', '')];

    val = NaN;
    for k = 1:numel(candidates)
        val = str2double(candidates(k));
        if isfinite(val)
            break;
        end
    end

    if ~isfinite(val)
        error('switching_energy_mapping_analysis:ParseCurrentFailed', ...
            'Could not parse current value from column name: %s', vName);
    end
    currents(i) = val;
end
end

function [stats, mapped] = computeEnergyStats(temps, currents, PT, alpha, gamma)
temps = temps(:);
currents = currents(:);

energyRaw = alpha .* sign(currents) .* (abs(currents) .^ gamma);
[energyAxis, order] = sort(energyRaw, 'ascend');
currentsOrdered = currents(order);

dE_dI = gradient(energyAxis, currentsOrdered);
badJacobian = ~isfinite(dE_dI) | abs(dE_dI) <= eps;
dE_dI(badJacobian) = NaN;

nT = numel(temps);
nE = numel(energyAxis);

PT_E = NaN(nT, nE);
mean_E = NaN(nT, 1);
std_E = NaN(nT, 1);
skew_E = NaN(nT, 1);
normArea = NaN(nT, 1);

for it = 1:nT
    pI = PT(it, order);
    pI = double(pI(:));
    pI(~isfinite(pI)) = 0;
    pI = max(pI, 0);

    valid = isfinite(energyAxis) & isfinite(pI) & isfinite(dE_dI);
    if nnz(valid) < 2
        continue;
    end

    E = energyAxis(valid);
    jac = abs(dE_dI(valid));
    pE = pI(valid) ./ jac;
    [pE, area] = normalizeDistribution(E, pE);
    if ~isfinite(area) || area <= 0
        continue;
    end

    PT_E(it, valid) = pE;
    normArea(it) = trapz(E, pE);

    mu = trapz(E, pE .* E);
    varE = trapz(E, pE .* (E - mu) .^ 2);
    varE = max(varE, 0);
    sigma = sqrt(varE);

    mean_E(it) = mu;
    std_E(it) = sigma;

    if sigma > 0
        skewNum = trapz(E, pE .* (E - mu) .^ 3);
        skew_E(it) = skewNum / (sigma ^ 3);
    end
end

stats = struct();
stats.temps = temps;
stats.mean_E = mean_E;
stats.std_E = std_E;
stats.skew_E = skew_E;
stats.norm_area = normArea;
stats.sign_changes_mean = countSignChanges(mean_E);
stats.sign_changes_std = countSignChanges(std_E);

mapped = struct();
mapped.energyAxis = energyAxis(:);
mapped.PT_E = PT_E;
mapped.gamma = gamma;
mapped.alpha = alpha;
end

function [pNorm, area] = normalizeDistribution(axisVals, pVals)
axisVals = axisVals(:);
pVals = pVals(:);

pVals(~isfinite(pVals)) = 0;
pVals = max(pVals, 0);

if nnz(isfinite(axisVals)) < 2
    pNorm = NaN(size(pVals));
    area = NaN;
    return;
end

area = trapz(axisVals, pVals);
if ~isfinite(area) || area <= 0
    pNorm = NaN(size(pVals));
    area = NaN;
    return;
end

pNorm = pVals ./ area;
end

function robustness = runRobustnessCheck(temps, currents, PT, alpha, gammas, canonicalStats)
gammas = unique(gammas(:).', 'stable');
gammas = gammas(isfinite(gammas));
gammas = gammas(abs(gammas - 1) > 1e-12);

allGammas = [1, gammas];
nG = numel(allGammas);
nT = numel(temps);

meanByGamma = NaN(nT, nG);
stdByGamma = NaN(nT, nG);
skewByGamma = NaN(nT, nG);
signChangesMean = NaN(nG, 1);
signChangesStd = NaN(nG, 1);

for ig = 1:nG
    [statsGamma, ~] = computeEnergyStats(temps, currents, PT, alpha, allGammas(ig));
    meanByGamma(:, ig) = statsGamma.mean_E;
    stdByGamma(:, ig) = statsGamma.std_E;
    skewByGamma(:, ig) = statsGamma.skew_E;
    signChangesMean(ig) = statsGamma.sign_changes_mean;
    signChangesStd(ig) = statsGamma.sign_changes_std;
end

meanRef = canonicalStats.mean_E(:);
stdRef = canonicalStats.std_E(:);

if nG > 1
    relMean = abs(meanByGamma(:, 2:end) - meanRef) ./ max(abs(meanRef), eps);
    relStd = abs(stdByGamma(:, 2:end) - stdRef) ./ max(abs(stdRef), eps);
else
    relMean = NaN(nT, 0);
    relStd = NaN(nT, 0);
end

if isempty(relMean)
    maxRelMeanPerT = zeros(nT, 1);
    maxRelStdPerT = zeros(nT, 1);
else
    maxRelMeanPerT = max(relMean, [], 2, 'omitnan');
    maxRelStdPerT = max(relStd, [], 2, 'omitnan');
end

robustness = struct();
robustness.gammas = allGammas(:);
robustness.mean_by_gamma = meanByGamma;
robustness.std_by_gamma = stdByGamma;
robustness.skew_by_gamma = skewByGamma;
robustness.sign_changes_mean = signChangesMean;
robustness.sign_changes_std = signChangesStd;
robustness.max_rel_mean_per_T = maxRelMeanPerT;
robustness.max_rel_std_per_T = maxRelStdPerT;
robustness.median_rel_mean = median(maxRelMeanPerT, 'omitnan');
robustness.max_rel_mean = max(maxRelMeanPerT, [], 'omitnan');
robustness.median_rel_std = median(maxRelStdPerT, 'omitnan');
robustness.max_rel_std = max(maxRelStdPerT, [], 'omitnan');
robustness.reference_sign_changes_mean = canonicalStats.sign_changes_mean;
robustness.reference_sign_changes_std = canonicalStats.sign_changes_std;
end

function tbl = buildRobustnessByTempTable(temps, canonicalStats, robustness)
tbl = table( ...
    temps(:), ...
    canonicalStats.mean_E(:), ...
    canonicalStats.std_E(:), ...
    canonicalStats.skew_E(:), ...
    robustness.max_rel_mean_per_T(:), ...
    robustness.max_rel_std_per_T(:), ...
    'VariableNames', {'T', 'mean_E', 'std_E', 'skew', 'max_rel_mean_across_gamma', 'max_rel_std_across_gamma'});
end

function tbl = buildRobustnessSummaryTable(robustness)
gamma = robustness.gammas(:);
isReference = abs(gamma - 1) < 1e-12;

medianRelMean = NaN(size(gamma));
maxRelMean = NaN(size(gamma));
medianRelStd = NaN(size(gamma));
maxRelStd = NaN(size(gamma));

medianRelMean(isReference) = 0;
maxRelMean(isReference) = 0;
medianRelStd(isReference) = 0;
maxRelStd(isReference) = 0;

for i = 1:numel(gamma)
    if isReference(i)
        continue;
    end
    relMean = abs(robustness.mean_by_gamma(:, i) - robustness.mean_by_gamma(:, 1)) ./ ...
        max(abs(robustness.mean_by_gamma(:, 1)), eps);
    relStd = abs(robustness.std_by_gamma(:, i) - robustness.std_by_gamma(:, 1)) ./ ...
        max(abs(robustness.std_by_gamma(:, 1)), eps);
    medianRelMean(i) = median(relMean, 'omitnan');
    maxRelMean(i) = max(relMean, [], 'omitnan');
    medianRelStd(i) = median(relStd, 'omitnan');
    maxRelStd(i) = max(relStd, [], 'omitnan');
end

tbl = table( ...
    gamma, ...
    string(repmat("nonlinear_perturbation", numel(gamma), 1)), ...
    medianRelMean, ...
    maxRelMean, ...
    medianRelStd, ...
    maxRelStd, ...
    robustness.sign_changes_mean(:), ...
    robustness.sign_changes_std(:), ...
    'VariableNames', {'gamma', 'mapping_type', 'median_rel_mean', 'max_rel_mean', ...
    'median_rel_std', 'max_rel_std', 'sign_changes_mean', 'sign_changes_std'});
end

function tbl = buildSourceManifestTable(source, cfg, tempsAll, tempsCanonical)
tbl = table( ...
    repmat(string(source.runId), 2, 1), ...
    string({'PT_matrix'; 'PT_summary'}), ...
    string({char(source.ptMatrixPath); char(source.ptSummaryPath)}), ...
    repmat(string(sprintf('T<=%.1fK', cfg.canonicalTemperatureMaxK)), 2, 1), ...
    repmat(numel(tempsAll), 2, 1), ...
    repmat(numel(tempsCanonical), 2, 1), ...
    'VariableNames', {'source_run_id', 'asset_role', 'asset_path', 'canonical_window', ...
    'n_total_temperatures', 'n_canonical_temperatures'});
end

function figPaths = saveMeanEnergyFigure(temps, meanE, runDir)
base_name = 'mean_E_vs_T';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Position', [2 2 12 8]);
ax = axes(fig); %#ok<LAXES>
plot(ax, temps, meanE, '-o', 'Color', [0.00 0.45 0.74], 'LineWidth', 2.3, ...
    'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerSize', 6);
grid(ax, 'on');
xlabel(ax, 'Temperature T (K)');
ylabel(ax, '\langleE\rangle(T) (arb. units)');
title(ax, 'Canonical mean effective energy vs temperature (T \leq 30 K)');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function figPaths = saveStdEnergyFigure(temps, stdE, runDir)
base_name = 'std_E_vs_T';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Position', [2 2 12 8]);
ax = axes(fig); %#ok<LAXES>
plot(ax, temps, stdE, '-s', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.3, ...
    'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerSize', 6);
grid(ax, 'on');
xlabel(ax, 'Temperature T (K)');
ylabel(ax, '\sigma_E(T) (arb. units)');
title(ax, 'Canonical effective-energy spread vs temperature (T \leq 30 K)');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function figPaths = saveRepresentativeCurvesFigure(temps, mapCanonical, runDir, cfg)
figPaths = struct('pdf', "", 'png', "", 'fig', "");

indices = pickRepresentativeIndices(temps, cfg.representativeTemperaturesK, cfg.maxRepresentativeCurves);
if isempty(indices)
    return;
end

base_name = 'pt_energy_curves_representative';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Position', [2 2 12 8]);
ax = axes(fig); %#ok<LAXES>
hold(ax, 'on');
grid(ax, 'on');

clr = lines(numel(indices));
for k = 1:numel(indices)
    idx = indices(k);
    pRow = mapCanonical.PT_E(idx, :);

    E = mapCanonical.energyAxis(:);
    P = pRow(:);
    n = min(numel(E), numel(P));
    if n < 2
        continue;
    end

    E = E(1:n);
    P = P(1:n);

    valid = isfinite(E) & isfinite(P) & P >= 0;
    if nnz(valid) < 2
        continue;
    end

    plot(ax, E(valid), P(valid), '-', ...
        'LineWidth', 2.2, 'Color', clr(k, :), ...
        'DisplayName', sprintf('T = %.1f K', temps(idx)));
end

xlabel(ax, 'Effective energy E (arb. units)');
ylabel(ax, 'P_T(E) (1/arb. units)');
title(ax, 'Representative P_T(E) curves in canonical window (T \leq 30 K)');
legend(ax, 'Location', 'best');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);

hold(ax, 'off');
figPaths = save_run_figure(fig, base_name, runDir);
close(fig);
end

function idx = pickRepresentativeIndices(temps, targets, maxCurves)
temps = temps(:);
targets = unique(targets(:), 'stable');
idx = [];

for i = 1:numel(targets)
    [~, j] = min(abs(temps - targets(i)));
    idx(end + 1) = j; %#ok<AGROW>
end

% Always include endpoints to emphasize full canonical span.
idx(end + 1) = 1; %#ok<AGROW>
idx(end + 1) = numel(temps); %#ok<AGROW>

idx = unique(idx, 'stable');
if numel(idx) > maxCurves
    idx = idx(1:maxCurves);
end
end

function reportText = buildReportText(cfg, source, tempsAll, statsCanonical, robustness, ...
    energyStatsPath, robustByTempPath, robustSummaryPath, figMeanPaths, figStdPaths, figCurvesPaths)
nAll = numel(tempsAll);
nCanonical = numel(statsCanonical.temps);
nBoundary = nAll - nCanonical;

gammaText = strjoin(compose('%.3g', robustness.gammas(2:end).'), ', ');
if isempty(gammaText)
    gammaText = 'none';
end

lines = strings(0, 1);
lines(end + 1) = "# Switching PT(I_{th},T) -> PT(E,T) energy mapping";
lines(end + 1) = "";
lines(end + 1) = "## Goal";
lines(end + 1) = "Build minimal, physically interpretable effective-energy observables from saved switching barrier distributions.";
lines(end + 1) = "";
lines(end + 1) = "## Inputs";
lines(end + 1) = sprintf("- Source run: `%s`.", source.runId);
lines(end + 1) = sprintf("- Source PT matrix: `%s`.", source.ptMatrixPath);
lines(end + 1) = sprintf("- Source PT summary: `%s`.", source.ptSummaryPath);
lines(end + 1) = "";
lines(end + 1) = "## Canonical temperature window";
lines(end + 1) = sprintf("- Applied strict canonical filter: `T <= %.1f K`.", cfg.canonicalTemperatureMaxK);
lines(end + 1) = sprintf("- Canonical rows used in all main analysis: `%d / %d`.", nCanonical, nAll);
lines(end + 1) = sprintf("- Boundary rows (`T > %.1f K`) excluded from interpretation: `%d`.", cfg.canonicalTemperatureMaxK, nBoundary);
lines(end + 1) = "";
lines(end + 1) = "## Mapping assumption";
lines(end + 1) = sprintf("- Main mapping: `E = alpha * I_{th}` with fixed `alpha = %.6g`.", cfg.alpha);
lines(end + 1) = "- No fitting was performed at any stage.";
lines(end + 1) = "- For transformed distributions, normalization was enforced after Jacobian-based axis conversion.";
lines(end + 1) = "";
lines(end + 1) = "## Extracted observables";
lines(end + 1) = "- `<E>(T)` and `sigma_E(T)` were computed from `P_T(E)` for each canonical temperature.";
lines(end + 1) = "- Optional skewness was included as a third-shape diagnostic.";
lines(end + 1) = "";
lines(end + 1) = "## Robustness check (lightweight, no fit)";
lines(end + 1) = sprintf("- Nonlinear perturbation tested: `E ~ I_{th}^{gamma}` with gamma = `%s`.", gammaText);
lines(end + 1) = sprintf("- Median relative change in `<E>` across perturbations: `%.4f`.", robustness.median_rel_mean);
lines(end + 1) = sprintf("- Max relative change in `<E>` across perturbations: `%.4f`.", robustness.max_rel_mean);
lines(end + 1) = sprintf("- Median relative change in `sigma_E` across perturbations: `%.4f`.", robustness.median_rel_std);
lines(end + 1) = sprintf("- Max relative change in `sigma_E` across perturbations: `%.4f`.", robustness.max_rel_std);
lines(end + 1) = sprintf("- Smoothness proxy (sign changes of discrete derivative): `<E>`=%d, `sigma_E`=%d.", ...
    statsCanonical.sign_changes_mean, statsCanonical.sign_changes_std);
lines(end + 1) = "";
lines(end + 1) = "## Outputs";
lines(end + 1) = sprintf("- `%s`", energyStatsPath);
lines(end + 1) = sprintf("- `%s`", robustByTempPath);
lines(end + 1) = sprintf("- `%s`", robustSummaryPath);
lines(end + 1) = sprintf("- `%s`", figMeanPaths.png);
lines(end + 1) = sprintf("- `%s`", figStdPaths.png);
if strlength(figCurvesPaths.png) > 0
    lines(end + 1) = sprintf("- `%s`", figCurvesPaths.png);
end
lines(end + 1) = "";
lines(end + 1) = "## Constraints check";
lines(end + 1) = "- Existing switching extraction outputs were not modified.";
lines(end + 1) = "- Existing runs were treated as immutable read-only sources.";
lines(end + 1) = "- `X(T)` was not recomputed.";
lines(end + 1) = "- No attempt was made to fit or explain `A(T)` / `R(T)` in this run.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 1 in each summary figure, and <=6 representative `P_T(E)` curves.";
lines(end + 1) = "- legend vs colormap: explicit legend used for representative curves (curve count <=6).";
lines(end + 1) = "- colormap used: default MATLAB line colors (`lines`) for representative curves.";
lines(end + 1) = "- smoothing applied: none in this stage (direct use of saved `P_T` tables).";
lines(end + 1) = "- justification: keep the mapping stage minimal and avoid introducing extra modeling assumptions.";

reportText = strjoin(lines, newline);
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

function ensureArtifactDirs(runDir)
required = {'figures', 'tables', 'reports', 'review'};
for i = 1:numel(required)
    pathNow = fullfile(runDir, required{i});
    if exist(pathNow, 'dir') ~= 7
        mkdir(pathNow);
    end
end
end

function value = setDefaultField(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s;
else
    s.(fieldName) = defaultValue;
    value = s;
end
end

function count = countSignChanges(series)
series = series(:);
valid = isfinite(series);
series = series(valid);
if numel(series) < 3
    count = 0;
    return;
end

d = diff(series);
d = d(abs(d) > 1e-12);
if numel(d) < 2
    count = 0;
    return;
end

s = sign(d);
count = sum(diff(s) ~= 0);
end

function appendText(pathText, lineText)
fid = fopen(pathText, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', lineText);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


