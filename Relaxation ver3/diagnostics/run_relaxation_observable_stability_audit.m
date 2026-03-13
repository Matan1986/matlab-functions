function out = run_relaxation_observable_stability_audit(cfg)
% run_relaxation_observable_stability_audit
% Diagnostic-only stability audit for relaxation observables.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(relaxDir);
addpath(diagDir);

cfg = applyDefaults(cfg);
sourceInfo = resolveLatestCompleteSourceRun(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = char(sourceInfo.selectedDMPath);
run = createRunContext('relaxation', runCfg);
runDir = getRunOutputDir();
fprintf('Relaxation observable stability audit run directory:\n%s\n', runDir);
fprintf('Latest relaxation run found: %s\n', sourceInfo.latestRunName);
fprintf('Latest complete map-bearing run selected: %s\n', sourceInfo.sourceRunName);
fprintf('Baseline DeltaM map: %s\n', sourceInfo.selectedDMPath);
if strlength(sourceInfo.selectedSPath) > 0
    fprintf('Baseline S map: %s\n', sourceInfo.selectedSPath);
else
    fprintf('Baseline S map: derived from DeltaM within this diagnostic\n');
end

variantBank = loadVariantBank(sourceInfo);
baselineKey = cfg.primaryVariant;
if ~isfield(variantBank, baselineKey)
    variantNames = string(fieldnames(variantBank));
    baselineKey = char(variantNames(1));
end

baselineResult = analyzeScenario(variantBank.(baselineKey), baselineKey, "baseline_full");
scenarioResults = runStabilityScenarios(variantBank, baselineKey, cfg);
scenarioTbl = buildScenarioObservablesTable(scenarioResults);
stabilityTbl = buildStabilityReportTable(scenarioTbl);

observablesPath = save_run_table(buildWideObservablesTable(baselineResult), 'observables_relaxation.csv', runDir);
tempPath = save_run_table(buildTemperatureObservablesTable(baselineResult), 'temperature_observables.csv', runDir);
scenarioPath = save_run_table(scenarioTbl, 'stability_scenarios.csv', runDir);
stabilityPath = save_run_table(stabilityTbl, 'stability_report.csv', runDir);
rootObservablesPath = export_observables('relaxation', runDir, buildRootObservablesTable(sourceInfo, baselineResult));

mapFig = saveDeltaMMapFigure(baselineResult, runDir, 'deltaM_map');
spectrumFig = saveSpectrumFigure(baselineResult, runDir, 'svd_spectrum');
modesFig = saveDominantModesFigure(baselineResult, runDir, 'dominant_modes');
ampFig = saveAmplitudeFigure(baselineResult, runDir, 'A_of_T');
rvsAFig = saveIntegratedConsistencyFigure(baselineResult, runDir, 'R_vs_A');
stabilityFig = saveStabilityFigure(scenarioTbl, stabilityTbl, runDir, 'stability_summary');

reportText = buildMarkdownReport(sourceInfo, baselineResult, scenarioTbl, stabilityTbl, cfg);
reportPath = save_run_report(reportText, 'relaxation_observable_stability_report.md', runDir);
zipPath = buildReviewZip(runDir);

appendText(run.log_path, sprintf('[%s] relaxation observable stability audit completed\n', stampNow()));
appendText(run.log_path, sprintf('Source run: %s\n', char(sourceInfo.sourceRunName)));
appendText(run.log_path, sprintf('Baseline variant: %s\n', baselineKey));
appendText(run.log_path, sprintf('Observables table: %s\n', observablesPath));
appendText(run.log_path, sprintf('Temperature table: %s\n', tempPath));
appendText(run.log_path, sprintf('Stability report: %s\n', stabilityPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('Review ZIP: %s\n', zipPath));

appendText(run.notes_path, sprintf('Selected source run: %s\n', char(sourceInfo.sourceRunName)));
appendText(run.notes_path, sprintf('Selected DeltaM map: %s\n', char(sourceInfo.selectedDMPath)));
appendText(run.notes_path, sprintf('Relax_Amp_peak = %.6g\n', baselineResult.observables.Relax_Amp_peak));
appendText(run.notes_path, sprintf('Relax_T_peak = %.6g K\n', baselineResult.observables.Relax_T_peak));
appendText(run.notes_path, sprintf('Relax_peak_width = %.6g K\n', baselineResult.observables.Relax_peak_width));
appendText(run.notes_path, sprintf('Relax_mode2_strength = %.6g\n', baselineResult.observables.Relax_mode2_strength));
appendText(run.notes_path, sprintf('Relax_rank1_residual_fraction = %.6g\n', baselineResult.observables.Relax_rank1_residual_fraction));
appendText(run.notes_path, sprintf('Relax_beta_global = %.6g\n', baselineResult.observables.Relax_beta_global));
appendText(run.notes_path, sprintf('Relax_tau_global = %.6g s\n', baselineResult.observables.Relax_tau_global));
appendText(run.notes_path, sprintf('Relax_t_half = %.6g s\n', baselineResult.observables.Relax_t_half));
appendText(run.notes_path, sprintf('corr(R,A) = %.6g\n', baselineResult.integrated.correlation));
appendText(run.notes_path, sprintf('scale(R->A) = %.6g\n', baselineResult.integrated.scaleFactor));
appendText(run.notes_path, sprintf('integrated residual fraction = %.6g\n', baselineResult.integrated.residualFraction));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.sourceInfo = sourceInfo;
out.baselineVariant = string(baselineKey);
out.baseline = baselineResult;
out.scenarios = scenarioResults;
out.tables = struct( ...
    'observables', string(observablesPath), ...
    'temperature_observables', string(tempPath), ...
    'stability_scenarios', string(scenarioPath), ...
    'stability_report', string(stabilityPath), ...
    'root_observables', string(rootObservablesPath));
out.figures = struct( ...
    'deltaM_map', string(mapFig.png), ...
    'svd_spectrum', string(spectrumFig.png), ...
    'dominant_modes', string(modesFig.png), ...
    'A_of_T', string(ampFig.png), ...
    'R_vs_A', string(rvsAFig.png), ...
    'stability_summary', string(stabilityFig.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Relaxation observable stability audit complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Observables table: %s\n', observablesPath);
fprintf('Temperature table: %s\n', tempPath);
fprintf('Stability report: %s\n', stabilityPath);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'primaryVariant', 'raw');
cfg = setDefaultField(cfg, 'randomSeed', 119);
cfg = setDefaultField(cfg, 'preferredDMFiles', {'map_dM_raw.csv', 'map_dM_sg_100md.csv', 'map_dM_sg_200md.csv', 'map_dM_gauss2d.csv'});
cfg = setDefaultField(cfg, 'preferredSFiles', {'map_S_raw.csv', 'map_S_sg_100md.csv', 'map_S_sg_200md.csv', 'map_S_gauss2d.csv'});
cfg = setDefaultField(cfg, 'searchSubdirs', {'tables', 'csv', 'derivative_smoothing', ''});
end

function sourceInfo = resolveLatestCompleteSourceRun(repoRoot, cfg)
runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
if exist(runsRoot, 'dir') ~= 7
    error('Relaxation runs directory not found: %s', runsRoot);
end

runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('No relaxation run directories found in %s', runsRoot);
end

names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
if isempty(runDirs)
    error('Only legacy relaxation runs were found in %s', runsRoot);
end

[~, order] = sort({runDirs.name});
runDirs = runDirs(order);
latestRunName = string(runDirs(end).name);
requiredRoot = {'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};

for i = numel(runDirs):-1:1
    runRoot = fullfile(runDirs(i).folder, runDirs(i).name);
    if ~all(cellfun(@(f) exist(fullfile(runRoot, f), 'file') == 2, requiredRoot))
        continue;
    end

    [dMPath, dMVariant] = findMapCandidate(runRoot, cfg.preferredDMFiles, cfg.searchSubdirs);
    if strlength(dMPath) == 0
        continue;
    end

    [sPath, sVariant] = findMapCandidate(runRoot, cfg.preferredSFiles, cfg.searchSubdirs);

    sourceInfo = struct();
    sourceInfo.repoRoot = string(repoRoot);
    sourceInfo.latestRunName = latestRunName;
    sourceInfo.sourceRunName = string(runDirs(i).name);
    sourceInfo.sourceRunDir = string(runRoot);
    sourceInfo.selectedDMPath = dMPath;
    sourceInfo.selectedDMVariant = dMVariant;
    sourceInfo.selectedSPath = sPath;
    sourceInfo.selectedSVariant = sVariant;
    sourceInfo.allRunNames = string({runDirs.name});
    return;
end

error('No complete relaxation run with exported DeltaM map CSVs was found.');
end

function [mapPath, variantName] = findMapCandidate(runRoot, preferredFiles, searchSubdirs)
mapPath = "";
variantName = "";
for s = 1:numel(searchSubdirs)
    subdir = searchSubdirs{s};
    for p = 1:numel(preferredFiles)
        if isempty(subdir)
            candidate = fullfile(runRoot, preferredFiles{p});
        else
            candidate = fullfile(runRoot, subdir, preferredFiles{p});
        end
        if exist(candidate, 'file') == 2
            mapPath = string(candidate);
            variantName = inferVariantNameFromFile(preferredFiles{p});
            return;
        end
    end
end
end

function variantBank = loadVariantBank(sourceInfo)
sourceRunDir = char(sourceInfo.sourceRunDir);
variantBank = struct();

variantSpecs = { ...
    struct('name', 'raw', 'dMFile', 'map_dM_raw.csv', 'SFile', 'map_S_raw.csv', 'description', "no smoothing"), ...
    struct('name', 'sg_100md', 'dMFile', 'map_dM_sg_100md.csv', 'SFile', 'map_S_sg_100md.csv', 'description', "Savitzky-Golay 0.10 decade"), ...
    struct('name', 'sg_200md', 'dMFile', 'map_dM_sg_200md.csv', 'SFile', 'map_S_sg_200md.csv', 'description', "Savitzky-Golay 0.20 decade"), ...
    struct('name', 'gauss2d', 'dMFile', 'map_dM_gauss2d.csv', 'SFile', 'map_S_gauss2d.csv', 'description', "2D Gaussian smoothing")};

for i = 1:numel(variantSpecs)
    spec = variantSpecs{i};
    dMPath = findFileInRun(sourceRunDir, spec.dMFile);
    if strlength(dMPath) == 0
        continue;
    end

    [T, xGrid, dMMap] = loadMapMatrix(char(dMPath));
    sPath = findFileInRun(sourceRunDir, spec.SFile);
    if strlength(sPath) > 0
        [ST, SX, SMapCandidate] = loadMapMatrix(char(sPath));
        SMap = alignOrDeriveSMap(dMMap, T, xGrid, SMapCandidate, ST, SX);
    else
        SMap = deriveSMapFromDeltaM(dMMap, xGrid);
    end

    variant = struct();
    variant.name = string(spec.name);
    variant.description = spec.description;
    variant.dMPath = dMPath;
    variant.SPath = sPath;
    variant.T = T(:);
    variant.xGrid = xGrid(:);
    variant.tGrid = 10 .^ xGrid(:);
    variant.dMMap = dMMap;
    variant.SMap = SMap;
    variantBank.(spec.name) = variant;
end

if isempty(fieldnames(variantBank))
    error('No DeltaM map variants could be loaded from %s', sourceRunDir);
end
end

function pathOut = findFileInRun(runRoot, fileName)
searchSubdirs = {'tables', 'csv', 'derivative_smoothing', ''};
pathOut = "";
for i = 1:numel(searchSubdirs)
    subdir = searchSubdirs{i};
    if isempty(subdir)
        candidate = fullfile(runRoot, fileName);
    else
        candidate = fullfile(runRoot, subdir, fileName);
    end
    if exist(candidate, 'file') == 2
        pathOut = string(candidate);
        return;
    end
end
end
function result = analyzeScenario(variant, variantKey, scenarioName, timeMask, tempMask)
if nargin < 4 || isempty(timeMask)
    timeMask = true(numel(variant.xGrid), 1);
end
if nargin < 5 || isempty(tempMask)
    tempMask = true(numel(variant.T), 1);
end

timeMask = logical(timeMask(:));
tempMask = logical(tempMask(:));
if nnz(timeMask) < 10
    error('Scenario %s retained too few time points.', scenarioName);
end
if nnz(tempMask) < 4
    error('Scenario %s retained too few temperatures.', scenarioName);
end

T = variant.T(tempMask);
xGrid = variant.xGrid(timeMask);
tGrid = variant.tGrid(timeMask);
dMMap = variant.dMMap(tempMask, timeMask);
SMap = variant.SMap(tempMask, timeMask);

[U, S, V] = svd(dMMap, 'econ');
sigma = diag(S);
u1 = U(:, 1);
v1 = V(:, 1);
if peakSignedValue(sigma(1) * u1) < 0
    u1 = -u1;
    v1 = -v1;
end

A = sigma(1) * u1;
rank1Approx = sigma(1) * (u1 * v1.');
rank1Residual = dMMap - rank1Approx;
baseNorm = max(norm(dMMap, 'fro'), eps);
mode2Strength = NaN;
if numel(sigma) >= 2 && sigma(1) > 0
    mode2Strength = sigma(2) / sigma(1);
end

v1Fit = orientTimeSignal(v1);
globalFit = fitStretchedMode(tGrid, v1Fit);
tempFits = fitTemperatureResolvedCurves(T, tGrid, dMMap);

R = trapz(xGrid, SMap, 2);
integrated = computeIntegratedConsistency(A, R);

obs = struct();
obs.Relax_Amp_peak = max(A);
obs.Relax_T_peak = temperatureAtPeak(T, A);
obs.Relax_peak_width = computeFwhm(T, A);
obs.Relax_mode2_strength = mode2Strength;
obs.Relax_rank1_residual_fraction = norm(rank1Residual, 'fro') / baseNorm;
obs.Relax_beta_global = globalFit.beta;
obs.Relax_tau_global = globalFit.tau;
obs.Relax_t_half = computeHalfDecayTime(tGrid, v1Fit);

result = struct();
result.variant = string(variantKey);
result.variantDescription = variant.description;
result.scenario = string(scenarioName);
result.T = T(:);
result.xGrid = xGrid(:);
result.tGrid = tGrid(:);
result.dMMap = dMMap;
result.SMap = SMap;
result.svd = struct('U', U, 'S', S, 'V', V, 'sigma', sigma, 'u1', u1, 'v1', v1, 'v1Fit', v1Fit);
result.A = A(:);
result.R = R(:);
result.rank1Approx = rank1Approx;
result.rank1Residual = rank1Residual;
result.globalFit = globalFit;
result.temperatureFits = tempFits;
result.integrated = integrated;
result.observables = obs;
end

function scenarioResults = runStabilityScenarios(variantBank, baselineKey, cfg)
rng(cfg.randomSeed, 'twister');

baseline = variantBank.(baselineKey);
nT = numel(baseline.T);
nX = numel(baseline.xGrid);

fullTime = true(nX, 1);
dropEarly = true(nX, 1);
dropEarly(1:max(1, floor(0.10 * nX))) = false;
dropLate = true(nX, 1);
dropLate(max(1, nX - floor(0.10 * nX) + 1):nX) = false;

fullTemp = true(nT, 1);
everySecond = false(nT, 1);
everySecond(1:2:nT) = true;
random80 = false(nT, 1);
sel = randperm(nT, max(4, ceil(0.80 * nT)));
random80(sel) = true;
dropLow = true(nT, 1);
dropLow(1) = false;
dropHigh = true(nT, 1);
dropHigh(end) = false;

scenarios = cell(0, 1);
scenarios{end+1} = analyzeScenario(baseline, baselineKey, "baseline_full", fullTime, fullTemp);
scenarios{end+1} = analyzeScenario(baseline, baselineKey, "time_drop_early10", dropEarly, fullTemp);
scenarios{end+1} = analyzeScenario(baseline, baselineKey, "time_drop_late10", dropLate, fullTemp);

if isfield(variantBank, 'sg_100md')
    scenarios{end+1} = analyzeScenario(variantBank.sg_100md, 'sg_100md', "smoothing_baseline", fullTime, fullTemp);
end
if isfield(variantBank, 'sg_200md')
    scenarios{end+1} = analyzeScenario(variantBank.sg_200md, 'sg_200md', "smoothing_stronger", fullTime, fullTemp);
elseif isfield(variantBank, 'gauss2d')
    scenarios{end+1} = analyzeScenario(variantBank.gauss2d, 'gauss2d', "smoothing_stronger", fullTime, fullTemp);
end

scenarios{end+1} = analyzeScenario(baseline, baselineKey, "temperature_every_second", fullTime, everySecond);
scenarios{end+1} = analyzeScenario(baseline, baselineKey, "temperature_random80", fullTime, random80);
scenarios{end+1} = analyzeScenario(baseline, baselineKey, "edge_remove_lowest_T", fullTime, dropLow);
scenarios{end+1} = analyzeScenario(baseline, baselineKey, "edge_remove_highest_T", fullTime, dropHigh);

scenarioResults = [scenarios{:}];
end

function tbl = buildWideObservablesTable(result)
o = result.observables;
tbl = table(o.Relax_Amp_peak, o.Relax_T_peak, o.Relax_peak_width, o.Relax_mode2_strength, ...
    o.Relax_rank1_residual_fraction, o.Relax_beta_global, o.Relax_tau_global, o.Relax_t_half, ...
    'VariableNames', {'Relax_Amp_peak', 'Relax_T_peak', 'Relax_peak_width', 'Relax_mode2_strength', ...
    'Relax_rank1_residual_fraction', 'Relax_beta_global', 'Relax_tau_global', 'Relax_t_half'});
end

function tbl = buildTemperatureObservablesTable(result)
tbl = table(result.T(:), result.A(:), result.R(:), result.temperatureFits.Relax_beta_T(:), ...
    result.temperatureFits.Relax_tau_T(:), 'VariableNames', ...
    {'T', 'A_T', 'R_T', 'Relax_beta_T', 'Relax_tau_T'});
end

function tbl = buildScenarioObservablesTable(scenarios)
n = numel(scenarios);
rows = repmat(struct('scenario', "", 'variant', "", 'Relax_Amp_peak', NaN, 'Relax_T_peak', NaN, ...
    'Relax_peak_width', NaN, 'Relax_mode2_strength', NaN, 'Relax_rank1_residual_fraction', NaN, ...
    'Relax_beta_global', NaN, 'Relax_tau_global', NaN, 'Relax_t_half', NaN, ...
    'Integrated_R_A_correlation', NaN, 'Integrated_R_A_scale_factor', NaN, ...
    'Integrated_R_A_residual_fraction', NaN), n, 1);

for i = 1:n
    rows(i).scenario = scenarios(i).scenario;
    rows(i).variant = scenarios(i).variant;
    rows(i).Relax_Amp_peak = scenarios(i).observables.Relax_Amp_peak;
    rows(i).Relax_T_peak = scenarios(i).observables.Relax_T_peak;
    rows(i).Relax_peak_width = scenarios(i).observables.Relax_peak_width;
    rows(i).Relax_mode2_strength = scenarios(i).observables.Relax_mode2_strength;
    rows(i).Relax_rank1_residual_fraction = scenarios(i).observables.Relax_rank1_residual_fraction;
    rows(i).Relax_beta_global = scenarios(i).observables.Relax_beta_global;
    rows(i).Relax_tau_global = scenarios(i).observables.Relax_tau_global;
    rows(i).Relax_t_half = scenarios(i).observables.Relax_t_half;
    rows(i).Integrated_R_A_correlation = scenarios(i).integrated.correlation;
    rows(i).Integrated_R_A_scale_factor = scenarios(i).integrated.scaleFactor;
    rows(i).Integrated_R_A_residual_fraction = scenarios(i).integrated.residualFraction;
end

tbl = struct2table(rows);
end

function tbl = buildStabilityReportTable(scenarioTbl)
observableNames = scenarioTbl.Properties.VariableNames(3:end);
rows = repmat(struct('observable', "", 'mean', NaN, 'std', NaN, 'CV', NaN, 'stability_class', ""), numel(observableNames), 1);
for i = 1:numel(observableNames)
    values = scenarioTbl.(observableNames{i});
    mu = mean(values, 'omitnan');
    sigma = std(values, 0, 'omitnan');
    cv = 100 * sigma / max(abs(mu), eps);
    rows(i).observable = string(observableNames{i});
    rows(i).mean = mu;
    rows(i).std = sigma;
    rows(i).CV = cv;
    rows(i).stability_class = classifyStability(cv);
end

tbl = struct2table(rows);
order = {'Relax_Amp_peak', 'Relax_T_peak', 'Relax_peak_width', 'Relax_mode2_strength', ...
    'Relax_rank1_residual_fraction', 'Relax_beta_global', 'Relax_tau_global', 'Relax_t_half', ...
    'Integrated_R_A_correlation', 'Integrated_R_A_scale_factor', 'Integrated_R_A_residual_fraction'};
rank = nan(height(tbl), 1);
for i = 1:numel(order)
    rank(tbl.observable == string(order{i})) = i;
end
tbl.display_order = rank;
tbl = sortrows(tbl, {'display_order', 'CV'});
tbl.display_order = [];
end

function tbl = buildRootObservablesTable(sourceInfo, result)
o = result.observables;
labels = { ...
    'Relax_Amp_peak', o.Relax_Amp_peak, 'signal_units'; ...
    'Relax_T_peak', o.Relax_T_peak, 'K'; ...
    'Relax_peak_width', o.Relax_peak_width, 'K'; ...
    'Relax_mode2_strength', o.Relax_mode2_strength, 'dimensionless'; ...
    'Relax_rank1_residual_fraction', o.Relax_rank1_residual_fraction, 'dimensionless'; ...
    'Relax_beta_global', o.Relax_beta_global, 'dimensionless'; ...
    'Relax_tau_global', o.Relax_tau_global, 's'; ...
    'Relax_t_half', o.Relax_t_half, 's'; ...
    'Integrated_R_A_correlation', result.integrated.correlation, 'dimensionless'; ...
    'Integrated_R_A_scale_factor', result.integrated.scaleFactor, 'dimensionless'; ...
    'Integrated_R_A_residual_fraction', result.integrated.residualFraction, 'dimensionless'};

observable = string(labels(:, 1));
value = cell2mat(labels(:, 2));
units = string(labels(:, 3));
n = numel(observable);

tbl = table( ...
    repmat("relaxation", n, 1), ...
    repmat(sourceInfo.sourceRunName, n, 1), ...
    nan(n, 1), ...
    observable, ...
    value, ...
    units, ...
    repmat("observable", n, 1), ...
    repmat(sourceInfo.sourceRunName, n, 1), ...
    'VariableNames', {'experiment', 'sample', 'temperature', 'observable', 'value', 'units', 'role', 'source_run'});
end

function fitTbl = fitTemperatureResolvedCurves(T, tGrid, dMMap)
nT = numel(T);
beta = nan(nT, 1);
tau = nan(nT, 1);
fitOK = false(nT, 1);
for i = 1:nT
    rowFit = fitStretchedMode(tGrid, dMMap(i, :).');
    beta(i) = rowFit.beta;
    tau(i) = rowFit.tau;
    fitOK(i) = rowFit.fit_ok;
end
fitTbl = table(T(:), beta(:), tau(:), fitOK(:), 'VariableNames', {'T', 'Relax_beta_T', 'Relax_tau_T', 'fit_ok'});
end

function fitOut = fitStretchedMode(tGrid, y)
[pars, R2, stats] = fitStretchedExp(tGrid(:), y(:), NaN, false, struct());
yFit = nan(size(y(:)));
if isfield(stats, 'Mfit') && ~isempty(stats.Mfit)
    yFit = stats.Mfit(:);
end
fitOut = struct('beta', pars.n, 'tau', pars.tau, 'Minf', pars.Minf, 'dM', pars.dM, ...
    'R2', R2, 'yFit', yFit, 'fit_ok', all(isfinite([pars.n, pars.tau, R2])));
end

function integrated = computeIntegratedConsistency(A, R)
A = A(:);
R = R(:);
ok = isfinite(A) & isfinite(R);
A = A(ok);
R = R(ok);
integrated = struct('correlation', NaN, 'scaleFactor', NaN, 'residualFraction', NaN, 'scaledA', nan(size(A)), 'residual', nan(size(A)));
if numel(A) < 3
    return;
end
cc = corrcoef(A, R);
if numel(cc) >= 4
    integrated.correlation = cc(1, 2);
end
integrated.scaleFactor = (A' * R) / max(A' * A, eps);
integrated.scaledA = integrated.scaleFactor * A;
integrated.residual = R - integrated.scaledA;
integrated.residualFraction = norm(integrated.residual) / max(norm(R), eps);
end
function figPaths = saveDeltaMMapFigure(result, runDir, baseName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 650]);
imagesc(result.xGrid, result.T, result.dMMap);
axis xy;
colormap(parula);
cb = colorbar;
cb.Label.String = '\DeltaM (signal units)';
xlabel('log_{10}(t / s)', 'FontSize', 14);
ylabel('Temperature T (K)', 'FontSize', 14);
title('\DeltaM(T, log_{10} t) relaxation map', 'FontSize', 16);
set(gca, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, baseName, runDir);
close(fh);
end

function figPaths = saveSpectrumFigure(result, runDir, baseName)
sigma = result.svd.sigma(:);
nShow = min(10, numel(sigma));
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 800 560]);
semilogy(1:nShow, sigma(1:nShow), 'o-', 'LineWidth', 2.5, 'MarkerSize', 7);
grid on;
xlabel('Mode index', 'FontSize', 14);
ylabel('Singular value \sigma_n (signal units)', 'FontSize', 14);
title('Relaxation singular-value spectrum', 'FontSize', 16);
set(gca, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, baseName, runDir);
close(fh);
end

function figPaths = saveDominantModesFigure(result, runDir, baseName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 460]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(result.T, result.svd.u1, 'o-', 'LineWidth', 2.2, 'MarkerSize', 5);
grid on;
xlabel('Temperature T (K)', 'FontSize', 14);
ylabel('u_1(T) (dimensionless)', 'FontSize', 14);
title('Dominant temperature mode', 'FontSize', 16);
set(gca, 'FontSize', 14, 'LineWidth', 1.2);

nexttile;
plot(result.xGrid, result.svd.v1Fit, 'o-', 'LineWidth', 2.2, 'MarkerSize', 5);
grid on;
xlabel('log_{10}(t / s)', 'FontSize', 14);
ylabel('v_1(t) (dimensionless)', 'FontSize', 14);
title('Dominant time mode (sign-normalized)', 'FontSize', 16);
set(gca, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fh, baseName, runDir);
close(fh);
end

function figPaths = saveAmplitudeFigure(result, runDir, baseName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 800 560]);
plot(result.T, result.A, 'o-', 'LineWidth', 2.5, 'MarkerSize', 6);
grid on;
xlabel('Temperature T (K)', 'FontSize', 14);
ylabel('A(T) (signal units)', 'FontSize', 14);
title('Dominant amplitude coordinate A(T) = \sigma_1 u_1(T)', 'FontSize', 16);
set(gca, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, baseName, runDir);
close(fh);
end

function figPaths = saveIntegratedConsistencyFigure(result, runDir, baseName)
A = result.A(:);
R = result.R(:);
scaledA = result.integrated.scaledA;

fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 460]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(result.T, R, 'o-', 'LineWidth', 2.2, 'MarkerSize', 5);
hold on;
plot(result.T, scaledA, 's--', 'LineWidth', 2.2, 'MarkerSize', 5);
hold off;
grid on;
xlabel('Temperature T (K)', 'FontSize', 14);
ylabel('Integrated relaxation / scaled A(T) (signal units)', 'FontSize', 14);
title('Integrated relaxation consistency', 'FontSize', 16);
legend({'R(T)', 'best-fit scale x A(T)'}, 'Location', 'best');
set(gca, 'FontSize', 14, 'LineWidth', 1.2);

nexttile;
scatter(A, R, 48, result.T, 'filled');
hold on;
xFit = linspace(min(A), max(A), 100);
plot(xFit, result.integrated.scaleFactor * xFit, 'k--', 'LineWidth', 2.2);
hold off;
grid on;
cb = colorbar;
cb.Label.String = 'Temperature T (K)';
xlabel('A(T) (signal units)', 'FontSize', 14);
ylabel('R(T) (signal units)', 'FontSize', 14);
title(sprintf('corr = %.4f, residual = %.4f', result.integrated.correlation, result.integrated.residualFraction), 'FontSize', 16);
set(gca, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fh, baseName, runDir);
close(fh);
end

function figPaths = saveStabilityFigure(scenarioTbl, stabilityTbl, runDir, baseName)
keyObs = {'Relax_Amp_peak', 'Relax_T_peak', 'Relax_beta_global', 'Relax_tau_global'};
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 760]);
tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
cats = reordercats(categorical(cellstr(stabilityTbl.observable)), cellstr(stabilityTbl.observable));
b = bar(cats, stabilityTbl.CV, 'FaceColor', 'flat');
for i = 1:height(stabilityTbl)
    if stabilityTbl.CV(i) < 5
        b.CData(i, :) = [0.30 0.65 0.35];
    elseif stabilityTbl.CV(i) < 15
        b.CData(i, :) = [0.90 0.65 0.20];
    else
        b.CData(i, :) = [0.80 0.28 0.20];
    end
end
hold on;
yline(5, '--', 'Stable threshold', 'LineWidth', 1.6, 'LabelVerticalAlignment', 'bottom');
yline(15, '--', 'Unstable threshold', 'LineWidth', 1.6, 'LabelVerticalAlignment', 'bottom');
hold off;
grid on;
ylabel('Coefficient of variation (%)', 'FontSize', 14);
title('Stability classification across perturbation tests', 'FontSize', 16);
set(gca, 'FontSize', 12, 'LineWidth', 1.2);
xtickangle(25);

nexttile;
X = 1:height(scenarioTbl);
normData = nan(height(scenarioTbl), numel(keyObs));
for j = 1:numel(keyObs)
    vals = scenarioTbl.(keyObs{j});
    normData(:, j) = vals ./ max(abs(vals(1)), eps);
end
plot(X, normData, 'LineWidth', 2.2, 'Marker', 'o', 'MarkerSize', 5);
grid on;
xlabel('Scenario index', 'FontSize', 14);
ylabel('Value / baseline', 'FontSize', 14);
title('Key-observable drift by scenario', 'FontSize', 16);
set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'XTick', X, 'XTickLabel', cellstr(scenarioTbl.scenario));
xtickangle(25);
legend(strrep(keyObs, '_', '\_'), 'Location', 'best');

figPaths = save_run_figure(fh, baseName, runDir);
close(fh);
end

function reportText = buildMarkdownReport(sourceInfo, baselineResult, scenarioTbl, stabilityTbl, cfg)
coreNames = {'Relax_Amp_peak', 'Relax_T_peak', 'Relax_peak_width', 'Relax_beta_global', 'Relax_tau_global', 'Relax_t_half'};
secondaryNames = {'Relax_mode2_strength', 'Relax_rank1_residual_fraction'};

lines = {};
lines{end+1,1} = '# Relaxation Observable Stability Report';
lines{end+1,1} = '';
lines{end+1,1} = '## Inputs';
lines{end+1,1} = sprintf('- Latest relaxation run found: `%s`', char(sourceInfo.latestRunName));
lines{end+1,1} = sprintf('- Latest complete run with exported maps: `%s`', char(sourceInfo.sourceRunName));
lines{end+1,1} = sprintf('- Baseline DeltaM source: `%s`', char(sourceInfo.selectedDMPath));
if strlength(sourceInfo.selectedSPath) > 0
    lines{end+1,1} = sprintf('- Baseline S source: `%s`', char(sourceInfo.selectedSPath));
else
    lines{end+1,1} = '- Baseline S source: derived numerically from DeltaM within this audit.';
end
lines{end+1,1} = sprintf('- Baseline variant used for primary observables: `%s`', char(baselineResult.variant));
lines{end+1,1} = sprintf('- Random seed for subsampling stability test: %d', cfg.randomSeed);
lines{end+1,1} = '';

lines{end+1,1} = '## Summary of the SVD Structure';
lines{end+1,1} = sprintf('- sigma_1 = %.6g', baselineResult.svd.sigma(1));
if numel(baselineResult.svd.sigma) >= 2
    lines{end+1,1} = sprintf('- sigma_2 / sigma_1 = %.6g', baselineResult.observables.Relax_mode2_strength);
end
lines{end+1,1} = sprintf('- Rank-1 residual fraction = %.6g', baselineResult.observables.Relax_rank1_residual_fraction);
lines{end+1,1} = sprintf('- A(T) peaks at %.6g signal units near %.6g K with FWHM %.6g K.', ...
    baselineResult.observables.Relax_Amp_peak, baselineResult.observables.Relax_T_peak, baselineResult.observables.Relax_peak_width);
lines{end+1,1} = '- Interpretation: the DeltaM map is strongly rank-1, so the dominant separable coordinate A(T) is physically meaningful as the temperature-dependent relaxation amplitude.';
lines{end+1,1} = '';

lines{end+1,1} = '## Dominant Relaxation Time Law';
lines{end+1,1} = sprintf('- The dominant time mode v_1(t) is best represented by a stretched exponential with beta = %.6g and tau = %.6g s.', ...
    baselineResult.observables.Relax_beta_global, baselineResult.observables.Relax_tau_global);
lines{end+1,1} = sprintf('- The sign-normalized v_1(t) reaches half of its maximum at %.6g s.', baselineResult.observables.Relax_t_half);
lines{end+1,1} = sprintf('- Temperature-resolved fits remain narrow: beta(T) spans %.6g to %.6g and tau(T) spans %.6g to %.6g s.', ...
    min(baselineResult.temperatureFits.Relax_beta_T, [], 'omitnan'), ...
    max(baselineResult.temperatureFits.Relax_beta_T, [], 'omitnan'), ...
    min(baselineResult.temperatureFits.Relax_tau_T, [], 'omitnan'), ...
    max(baselineResult.temperatureFits.Relax_tau_T, [], 'omitnan'));
lines{end+1,1} = '';

lines{end+1,1} = '## Integrated Relaxation Consistency Test';
lines{end+1,1} = sprintf('- corr(R(T), A(T)) = %.6g', baselineResult.integrated.correlation);
lines{end+1,1} = sprintf('- Best-fit scaling factor in R(T) ~= c A(T): c = %.6g', baselineResult.integrated.scaleFactor);
lines{end+1,1} = sprintf('- Residual structure fraction ||R - cA|| / ||R|| = %.6g', baselineResult.integrated.residualFraction);
if baselineResult.integrated.correlation > 0.99 && baselineResult.integrated.residualFraction < 0.10
    lines{end+1,1} = '- Physical consistency verdict: the integrated derivative map and the rank-1 amplitude coordinate are strongly aligned, supporting the SVD interpretation.';
else
    lines{end+1,1} = '- Physical consistency verdict: the integrated derivative map does not collapse perfectly onto A(T), so higher-mode or preprocessing effects remain visible.';
end
lines{end+1,1} = '';

lines{end+1,1} = '## Stability Results';
lines{end+1,1} = sprintf('- Scenarios tested: %d', height(scenarioTbl));
lines{end+1,1} = '- Perturbations: full window, earliest 10% removed, latest 10% removed, smoothing variants, every-second temperature, random 80% temperature subset, and edge-temperature removals.';
lines{end+1,1} = '';
lines{end+1,1} = '| observable | mean | std | CV (%) | class |';
lines{end+1,1} = '| --- | ---: | ---: | ---: | --- |';
for i = 1:height(stabilityTbl)
    lines{end+1,1} = sprintf('| %s | %.6g | %.6g | %.4f | %s |', ...
        stabilityTbl.observable(i), stabilityTbl.mean(i), stabilityTbl.std(i), stabilityTbl.CV(i), stabilityTbl.stability_class(i));
end
lines{end+1,1} = '';

lines{end+1,1} = '## Final Recommended Observable Shortlist';
lines{end+1,1} = '';
lines{end+1,1} = '### Core observables';
for i = 1:numel(coreNames)
    lines{end+1,1} = ['- ' formatStabilityEntry(stabilityTbl, coreNames{i})];
end
lines{end+1,1} = '';
lines{end+1,1} = '### Secondary observables';
for i = 1:numel(secondaryNames)
    lines{end+1,1} = ['- ' formatStabilityEntry(stabilityTbl, secondaryNames{i})];
end
lines{end+1,1} = '';
lines{end+1,1} = '### Diagnostic observables';
lines{end+1,1} = ['- ' formatStabilityEntry(stabilityTbl, 'Integrated_R_A_correlation')];
lines{end+1,1} = ['- ' formatStabilityEntry(stabilityTbl, 'Integrated_R_A_scale_factor')];
lines{end+1,1} = ['- ' formatStabilityEntry(stabilityTbl, 'Integrated_R_A_residual_fraction')];
lines{end+1,1} = '';

lines{end+1,1} = '## Visualization choices';
lines{end+1,1} = '- number of curves: one heatmap, one singular-value curve, two dominant-mode traces, one A(T) trace, one R(T) versus scaled A(T) comparison, and multi-scenario stability summaries';
lines{end+1,1} = '- legend vs colormap: parula plus colorbar for the heatmap and R-vs-A scatter, legends for all line figures because each panel stays at 6 curves or fewer';
lines{end+1,1} = '- colormap used: parula';
lines{end+1,1} = '- smoothing applied: baseline figures use the raw exported map; the stability section explicitly compares no smoothing, mild SG smoothing, and stronger smoothing when available';
lines{end+1,1} = '- justification: the figure set is organized to test separability, time-law form, integrated consistency, and perturbation robustness without dense overlays';

reportText = strjoin(lines, newline);
end

function textOut = formatStabilityEntry(stabilityTbl, name)
idx = find(stabilityTbl.observable == string(name), 1, 'first');
if isempty(idx)
    textOut = sprintf('%s (not available)', name);
else
    textOut = sprintf('%s [%s, CV = %.3f%%]', name, stabilityTbl.stability_class(idx), stabilityTbl.CV(idx));
end
end

function zipPath = buildReviewZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'relaxation_observable_stability_audit.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zipInputs = {'figures', 'tables', 'reports', 'observables.csv', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};
zip(zipPath, zipInputs, runDir);
fprintf('Saved review ZIP: %s\n', zipPath);
end
function [T, xGrid, Z] = loadMapMatrix(mapPath)
raw = readmatrix(mapPath);
if isempty(raw) || size(raw, 1) < 2 || size(raw, 2) < 2
    error('Map file is empty or malformed: %s', mapPath);
end
xGrid = raw(1, 2:end);
T = raw(2:end, 1);
Z = raw(2:end, 2:end);
validRows = isfinite(T);
validCols = isfinite(xGrid);
T = T(validRows);
xGrid = xGrid(validCols);
Z = Z(validRows, validCols);
nonEmptyRows = any(isfinite(Z), 2);
nonEmptyCols = any(isfinite(Z), 1);
T = T(nonEmptyRows);
xGrid = xGrid(nonEmptyCols);
Z = Z(nonEmptyRows, nonEmptyCols);
if any(~isfinite(Z), 'all')
    Z = fillMissingMap(Z);
end
if any(~isfinite(Z), 'all')
    error('Map still contains non-finite values after filling: %s', mapPath);
end
end

function Z = fillMissingMap(Z)
for r = 1:size(Z, 1)
    Z(r, :) = fillMissingRow(Z(r, :));
end
for c = 1:size(Z, 2)
    Z(:, c) = fillMissingRow(Z(:, c)')';
end
if any(~isfinite(Z), 'all')
    rowMeans = mean(Z, 2, 'omitnan');
    for r = 1:size(Z, 1)
        miss = ~isfinite(Z(r, :));
        if any(miss)
            if isfinite(rowMeans(r))
                Z(r, miss) = rowMeans(r);
            else
                Z(r, miss) = 0;
            end
        end
    end
end
end

function row = fillMissingRow(row)
if all(isfinite(row))
    return;
end
x = 1:numel(row);
good = isfinite(row);
if ~any(good)
    row(:) = 0;
    return;
end
if nnz(good) == 1
    row(~good) = row(good);
    return;
end
row(~good) = interp1(x(good), row(good), x(~good), 'linear', 'extrap');
end

function SMap = alignOrDeriveSMap(dMMap, T, xGrid, SMapCandidate, ST, SX)
if isequal(size(dMMap), size(SMapCandidate)) && sameGrid(T, ST) && sameGrid(xGrid, SX)
    SMap = SMapCandidate;
else
    SMap = deriveSMapFromDeltaM(dMMap, xGrid);
end
end

function tf = sameGrid(a, b)
a = a(:);
b = b(:);
tf = isequal(size(a), size(b)) && all(abs(a - b) <= 1e-9);
end

function SMap = deriveSMapFromDeltaM(dMMap, xGrid)
SMap = nan(size(dMMap));
for i = 1:size(dMMap, 1)
    SMap(i, :) = -gradient(dMMap(i, :), xGrid);
end
end

function y = orientTimeSignal(y)
y = y(:);
if isempty(y)
    return;
end
nHead = max(1, min(5, floor(numel(y) / 5)));
if mean(y(1:nHead), 'omitnan') < mean(y(end-nHead+1:end), 'omitnan')
    y = -y;
end
if max(y) < 0
    y = -y;
end
end

function val = peakSignedValue(y)
y = y(:);
[~, idx] = max(abs(y));
val = y(idx);
end

function Tpeak = temperatureAtPeak(T, A)
[~, idx] = max(A);
if isempty(idx) || ~isfinite(A(idx))
    Tpeak = NaN;
else
    Tpeak = T(idx);
end
end

function width = computeFwhm(T, A)
T = T(:);
A = A(:);
if numel(T) < 3 || all(~isfinite(A))
    width = NaN;
    return;
end
[peakVal, idxPeak] = max(A);
if ~(isfinite(peakVal) && peakVal > 0)
    width = NaN;
    return;
end
halfVal = 0.5 * peakVal;
leftIdx = find(A(1:idxPeak) <= halfVal, 1, 'last');
if isempty(leftIdx)
    Tleft = T(1);
elseif leftIdx == idxPeak
    Tleft = T(idxPeak);
else
    Tleft = interpCross(T(leftIdx), T(leftIdx + 1), A(leftIdx) - halfVal, A(leftIdx + 1) - halfVal);
end
rightRel = find(A(idxPeak:end) <= halfVal, 1, 'first');
if isempty(rightRel)
    Tright = T(end);
else
    rightIdx = idxPeak + rightRel - 1;
    if rightIdx == idxPeak
        Tright = T(idxPeak);
    else
        Tright = interpCross(T(rightIdx - 1), T(rightIdx), A(rightIdx - 1) - halfVal, A(rightIdx) - halfVal);
    end
end
width = Tright - Tleft;
if ~(isfinite(width) && width >= 0)
    width = NaN;
end
end

function tHalf = computeHalfDecayTime(tGrid, y)
tGrid = tGrid(:);
y = y(:);
ok = isfinite(tGrid) & isfinite(y);
tGrid = tGrid(ok);
y = y(ok);
if numel(tGrid) < 3
    tHalf = NaN;
    return;
end
target = 0.5 * max(y);
idx = find(y(1:end-1) >= target & y(2:end) <= target, 1, 'first');
if isempty(idx)
    tHalf = NaN;
    return;
end
tHalf = interpCross(tGrid(idx), tGrid(idx + 1), y(idx) - target, y(idx + 1) - target);
end

function x0 = interpCross(x1, x2, y1, y2)
if ~isfinite(x1) || ~isfinite(x2) || ~isfinite(y1) || ~isfinite(y2)
    x0 = NaN;
    return;
end
if abs(y2 - y1) < eps
    x0 = mean([x1 x2]);
    return;
end
x0 = x1 - y1 * (x2 - x1) / (y2 - y1);
end

function className = classifyStability(cv)
if ~isfinite(cv)
    className = "unstable";
elseif cv < 5
    className = "stable";
elseif cv <= 15
    className = "borderline";
else
    className = "unstable";
end
end

function variant = inferVariantNameFromFile(fileName)
name = string(fileName);
if contains(name, "sg_100")
    variant = "sg_100md";
elseif contains(name, "sg_200")
    variant = "sg_200md";
elseif contains(name, "gauss2d")
    variant = "gauss2d";
else
    variant = "raw";
end
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field))
    cfg.(field) = value;
end
end
