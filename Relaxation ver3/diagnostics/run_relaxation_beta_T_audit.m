function out = run_relaxation_beta_T_audit(cfg)
% run_relaxation_beta_T_audit
% Diagnostics-only audit of whether Relaxation beta(T) is needed.

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
sources = discoverSources(repoRoot);
sourceData = loadSourceData(sources);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = char(sources.mapPath);
run = createRunContext('relaxation', runCfg);
runDir = getRunOutputDir();

fprintf('Relaxation beta(T) audit run directory:\n%s\n', runDir);
fprintf('Primary DeltaM map source: %s\n', char(sources.mapPath));

variants = buildVariants(cfg);
discoveryText = buildDiscoverySummary(sources, sourceData);
discoveryPath = saveTextInTables(runDir, 'discovery_summary.md', discoveryText);

seedResult = runVariant(sourceData, variants{1}, cfg);
results = repmat(seedResult, numel(variants), 1);
results(1) = seedResult;
for v = 2:numel(variants)
    results(v) = runVariant(sourceData, variants{v}, cfg);
end

comparisonMask = deriveComparisonMask(results(1).localFits, cfg);
for v = 1:numel(results)
    results(v).comparisonMask = comparisonMask;
    results(v).globalModel = fitGlobalModel(results(v).traces, results(v).localFits, comparisonMask, cfg);
    results(v).localSummary = summarizeModel(results(v).localFits, comparisonMask, 'local_beta');
    results(v).globalSummary = summarizeModel(results(v).globalModel.fits, comparisonMask, 'global_beta');
end

betaFitTbl = buildBetaFitTable(results, sources);
comparisonTbl = buildComparisonTable(results);
stabilityTbl = buildStabilityTable(results, cfg);
featureTbl = buildFeatureTable(results(1), stabilityTbl, sourceData, sources, cfg);
summary = summarizeAudit(results, stabilityTbl, featureTbl, cfg);

betaFitsPath = save_run_table(betaFitTbl, 'beta_T_fits.csv', runDir);
comparisonPath = save_run_table(comparisonTbl, 'global_vs_local_beta_model_comparison.csv', runDir);
stabilityPath = save_run_table(stabilityTbl, 'beta_T_stability_summary.csv', runDir);
featuresPath = save_run_table(featureTbl, 'beta_T_vs_relaxation_features.csv', runDir);

betaFig = saveBetaCurveFigure(results(1), stabilityTbl, sourceData, runDir, cfg);
comparisonFig = saveComparisonFigure(results, runDir, cfg);
stabilityFig = saveStabilityFigure(results, runDir, cfg);
overlayFig = saveOverlayFigure(results(1), sourceData, runDir, cfg);
exampleFig = saveExampleFitsFigure(results(1), comparisonMask, runDir, cfg);

reportText = buildReport(discoveryText, sources, sourceData, results, stabilityTbl, featureTbl, summary, cfg);
reportPath = save_run_report(reportText, 'beta_T_audit_report.md', runDir);
zipPath = buildReviewZip(runDir);

appendText(run.log_path, sprintf('[%s] beta(T) audit completed\n', stampNow()));
appendText(run.log_path, sprintf('Discovery: %s\n', discoveryPath));
appendText(run.log_path, sprintf('beta(T) fits: %s\n', betaFitsPath));
appendText(run.log_path, sprintf('Model comparison: %s\n', comparisonPath));
appendText(run.log_path, sprintf('Stability: %s\n', stabilityPath));
appendText(run.log_path, sprintf('Features: %s\n', featuresPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

appendText(run.notes_path, sprintf('Reference global beta = %.6g\n', summary.referenceGlobalBeta));
appendText(run.notes_path, sprintf('Reference deltaAIC(local-global) = %.6g\n', summary.referenceDeltaAIC));
appendText(run.notes_path, sprintf('Reference deltaBIC(local-global) = %.6g\n', summary.referenceDeltaBIC));
appendText(run.notes_path, sprintf('Final conclusion: %s\n', summary.finalConclusion));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.sources = sources;
out.summary = summary;
out.tables = struct('discovery', string(discoveryPath), 'beta_fits', string(betaFitsPath), ...
    'comparison', string(comparisonPath), 'stability', string(stabilityPath), 'features', string(featuresPath));
out.figures = struct('beta_curve', string(betaFig.png), 'comparison', string(comparisonFig.png), ...
    'stability', string(stabilityFig.png), 'overlay', string(overlayFig.png), 'examples', string(exampleFig.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDef(cfg, 'runLabel', 'beta_T_audit');
cfg = setDef(cfg, 'dropFrac', 0.10);
cfg = setDef(cfg, 'tailCount', 12);
cfg = setDef(cfg, 'minAmpSNR', 5.0);
cfg = setDef(cfg, 'minR2Ok', 0.98);
cfg = setDef(cfg, 'betaBounds', [0.10, 1.30]);
cfg = setDef(cfg, 'tauBoundsNorm', [0.01, 10.00]);
cfg = setDef(cfg, 'peakBand', [25, 29]);
cfg = setDef(cfg, 'shoulderBand', [11, 17]);
cfg = setDef(cfg, 'mainBand', [23, 27]);
cfg = setDef(cfg, 'stableShift', 0.015);
cfg = setDef(cfg, 'borderlineShift', 0.030);
cfg = setDef(cfg, 'representativeTemperatures', [15, 27, 35]);
cfg = setDef(cfg, 'figureVisible', 'off');
end

function sources = discoverSources(repoRoot)
runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
sources = struct();
sources.runsRoot = string(runsRoot);
[sources.mapRunName, sources.mapPath, sources.timeGridPath] = findLatestMapRun(runsRoot);
[sources.timelawRunName, sources.timeFitResultsPath, sources.timelawReportPath] = findLatestRunWithFile(runsRoot, fullfile('tables', 'time_fit_results.csv'), fullfile('reports', 'relaxation_timelaw_observables.md'));
[sources.timeModeRunName, sources.timeModeFitsPath, sources.timeModeReportPath] = findLatestRunWithFile(runsRoot, fullfile('tables', 'time_mode_fits.csv'), fullfile('reports', 'relaxation_time_mode_analysis.md'));
[sources.stabilityRunName, sources.temperatureObsPath, sources.stabilityReportPath] = findLatestRunWithFile(runsRoot, fullfile('tables', 'temperature_observables.csv'), fullfile('reports', 'relaxation_observable_stability_report.md'));
[sources.geometryRunName, sources.modeProfilesPath, sources.geometryReportPath] = findLatestRunWithFile(runsRoot, fullfile('tables', 'deltaM_mode_profiles.csv'), fullfile('reports', 'relaxation_geometry_observables.md'));
sources.coordinateAuditReportPath = fullfile(runsRoot, 'run_2026_03_10_014001_coordinate_audit', 'reports', 'relaxation_coordinate_audit.md');
sources.coordinateExtractionPath = fullfile(runsRoot, 'run_2026_03_10_015246_coordinate_extraction', 'tables', 'coordinates_relaxation.csv');
sources.legacyObservableOverallPath = fullfile(runsRoot, 'run_legacy_observable_survey', 'tables', 'fit_observable_stability_overall.csv');
sources.legacyObservableRecommendedPath = fullfile(runsRoot, 'run_legacy_observable_survey', 'tables', 'recommended_observables.csv');
end

function [runName, filePath, reportPath] = findLatestRunWithFile(runsRoot, relativeFile, relativeReport)
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
names = {runDirs.name};
keep = cellfun(@(s) isempty(regexpi(s, '^run_legacy')), names);
runDirs = runDirs(keep);
[~, ord] = sort({runDirs.name});
runDirs = runDirs(ord);
runName = '';
filePath = '';
reportPath = '';
for i = numel(runDirs):-1:1
    root = fullfile(runDirs(i).folder, runDirs(i).name);
    candidate = fullfile(root, relativeFile);
    if exist(candidate, 'file') == 2
        runName = runDirs(i).name;
        filePath = candidate;
        reportCandidate = fullfile(root, relativeReport);
        if exist(reportCandidate, 'file') == 2
            reportPath = reportCandidate;
        end
        return;
    end
end
error('Missing run artifact: %s', relativeFile);
end

function [runName, mapPath, timeGridPath] = findLatestMapRun(runsRoot)
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
names = {runDirs.name};
keep = cellfun(@(s) isempty(regexpi(s, '^run_legacy')), names);
runDirs = runDirs(keep);
[~, ord] = sort({runDirs.name});
runDirs = runDirs(ord);
searchSubdirs = {'tables', 'csv', 'derivative_smoothing', ''};
runName = '';
mapPath = '';
timeGridPath = '';
for i = numel(runDirs):-1:1
    root = fullfile(runDirs(i).folder, runDirs(i).name);
    for s = 1:numel(searchSubdirs)
        if isempty(searchSubdirs{s})
            mapCandidate = fullfile(root, 'map_dM_raw.csv');
            timeCandidate = fullfile(root, 'time_grid_used.csv');
        else
            mapCandidate = fullfile(root, searchSubdirs{s}, 'map_dM_raw.csv');
            timeCandidate = fullfile(root, searchSubdirs{s}, 'time_grid_used.csv');
        end
        if isempty(mapPath) && exist(mapCandidate, 'file') == 2
            runName = runDirs(i).name;
            mapPath = mapCandidate;
        end
        if isempty(timeGridPath) && exist(timeCandidate, 'file') == 2
            timeGridPath = timeCandidate;
        end
    end
    if ~isempty(mapPath)
        return;
    end
end
error('No non-legacy relaxation map run found.');
end

function sourceData = loadSourceData(sources)
[map, T, xGrid] = loadMapMatrix(sources.mapPath);
sourceData = struct();
sourceData.T = T(:);
sourceData.xGrid = xGrid(:);
sourceData.tGrid = (10 .^ xGrid(:));
sourceData.dMMap = map;
sourceData.timelawTable = readtable(sources.timeFitResultsPath);
sourceData.temperatureObsTable = sortrows(readtable(sources.temperatureObsPath), 'T');
sourceData.modeProfilesTable = sortrows(readtable(sources.modeProfilesPath), 'temperature_K');
sourceData.A_T = nan(numel(T), 1);
sourceData.R_T = nan(numel(T), 1);
for i = 1:numel(T)
    idx = find(abs(sourceData.temperatureObsTable.T - T(i)) <= 1e-9, 1, 'first');
    if ~isempty(idx)
        sourceData.A_T(i) = sourceData.temperatureObsTable.A_T(idx);
        sourceData.R_T(i) = sourceData.temperatureObsTable.R_T(idx);
    end
end
sourceData.A_norm = sourceData.A_T ./ max(sourceData.A_T, [], 'omitnan');
sourceData.timeGridTable = table();
if ~isempty(sources.timeGridPath) && exist(sources.timeGridPath, 'file') == 2
    sourceData.timeGridTable = readtable(sources.timeGridPath);
end
sourceData.referenceBetaRange = getReferenceBetaRange(sourceData.timelawTable);
[sourceData.A_relax, sourceData.T_relax, sourceData.skew_relax, sourceData.shoulder_strength, sourceData.coordinateDetail] = compute_relaxation_coordinates(sourceData.T, sourceData.A_T);
end

function betaRange = getReferenceBetaRange(tbl)
mask = strcmp(tbl.scope, 'temperature_slice') & isfinite(tbl.param_beta);
if any(mask)
    betaRange = [min(tbl.param_beta(mask)), max(tbl.param_beta(mask))];
else
    betaRange = [NaN, NaN];
end
end

function [Z, T, xGrid] = loadMapMatrix(mapPath)
raw = readmatrix(mapPath);
xGrid = raw(1, 2:end);
T = raw(2:end, 1);
Z = raw(2:end, 2:end);
validRows = isfinite(T);
validCols = isfinite(xGrid);
T = T(validRows);
xGrid = xGrid(validCols);
Z = Z(validRows, validCols);
if any(~isfinite(Z), 'all')
    Z = fillMissingMap(Z);
end
end

function Z = fillMissingMap(Z)
for r = 1:size(Z, 1)
    row = Z(r, :);
    if any(~isfinite(row))
        x = 1:numel(row);
        good = isfinite(row);
        row(~good) = interp1(x(good), row(good), x(~good), 'linear', 'extrap');
        Z(r, :) = row;
    end
end
for c = 1:size(Z, 2)
    col = Z(:, c);
    if any(~isfinite(col))
        x = 1:numel(col);
        good = isfinite(col);
        col(~good) = interp1(x(good), col(good), x(~good), 'linear', 'extrap');
        Z(:, c) = col;
    end
end
end

function variants = buildVariants(cfg)
variants = {
    struct('id', 'reference_raw_full', 'title', 'Full window, raw traces', 'dropEarly', 0, 'dropLate', 0, 'timeWeight', false, 'normalized', false), ...
    struct('id', 'drop_early_raw', 'title', 'Exclude earliest 10%', 'dropEarly', cfg.dropFrac, 'dropLate', 0, 'timeWeight', false, 'normalized', false), ...
    struct('id', 'drop_late_raw', 'title', 'Exclude latest 10%', 'dropEarly', 0, 'dropLate', cfg.dropFrac, 'timeWeight', false, 'normalized', false), ...
    struct('id', 'weighted_raw', 'title', 'Existing early-time weighting', 'dropEarly', 0, 'dropLate', 0, 'timeWeight', true, 'normalized', false), ...
    struct('id', 'normalized_full', 'title', 'Full window, amplitude-normalized', 'dropEarly', 0, 'dropLate', 0, 'timeWeight', false, 'normalized', true)};
end

function text = buildDiscoverySummary(sources, sourceData)
lines = {};
lines{end+1} = '# Discovery Summary';
lines{end+1} = '';
lines{end+1} = '## 1. Existing Relaxation scripts that already compare stretched exponential vs log law';
lines{end+1} = '- `Relaxation ver3/diagnostics/compare_relaxation_models.m` compares per-temperature KWW vs logarithmic fits on matched windows.';
lines{end+1} = '- `Relaxation ver3/diagnostics/run_relaxation_time_mode_analysis.m` compares stretched exponential, logarithmic, and power-law fits for the dominant time mode `v_1(t)`.';
lines{end+1} = '- `Relaxation ver3/diagnostics/run_relaxation_timelaw_observables.m` already exports global and per-temperature stretched-exponential fits.';
lines{end+1} = '- `Relaxation ver3/analyzeRelaxationAdvanced.m` contains additive multistart/log-model comparison logic without changing the legacy pipeline.';
lines{end+1} = '';
lines{end+1} = '## 2. Existing files/runs that already contain fit-ready time traces by temperature';
lines{end+1} = sprintf('- Primary saved DeltaM matrix reused here: `%s` from `%s`.', sources.mapPath, sources.mapRunName);
if ~isempty(sources.timeGridPath)
    lines{end+1} = sprintf('- Matching saved time grid reused here: `%s`.', sources.timeGridPath);
end
lines{end+1} = sprintf('- Existing per-temperature timelaw table: `%s` from `%s`.', sources.timeFitResultsPath, sources.timelawRunName);
lines{end+1} = sprintf('- Existing amplitude/beta summary table: `%s` from `%s`.', sources.temperatureObsPath, sources.stabilityRunName);
lines{end+1} = sprintf('- Existing rank-1 amplitude profile table: `%s` from `%s`.', sources.modeProfilesPath, sources.geometryRunName);
lines{end+1} = '';
lines{end+1} = '## 3. Existing beta-related extraction already present in the repository';
lines{end+1} = '- `Relaxation ver3/fitStretchedExp.m` is the existing KWW fitting helper.';
lines{end+1} = '- `run_relaxation_timelaw_observables` already reports beta(T) over 19 temperatures and a global stretched-exponential time law.';
lines{end+1} = '- `run_relaxation_observable_stability_audit` already exports `Relax_beta_T`, `Relax_tau_T`, and `A(T)` on the saved raw map.';
lines{end+1} = '- `diagnose_tau_beta_degeneracy.m` already audits tau-beta tradeoff risk for raw-curve fits.';
lines{end+1} = '- The legacy observable survey already tracked `beta_kww`, but on a different raw-curve fit basis than the saved-map audit used here.';
lines{end+1} = '';
lines{end+1} = '## 4. Source runs selected for reuse';
lines{end+1} = sprintf('- Map source run: `%s` (saved raw DeltaM map with %d temperatures and %d log-time samples).', sources.mapRunName, numel(sourceData.T), numel(sourceData.tGrid));
lines{end+1} = sprintf('- Timelaw reference run: `%s`.', sources.timelawRunName);
lines{end+1} = sprintf('- Stability reference run: `%s`.', sources.stabilityRunName);
lines{end+1} = sprintf('- Geometry reference run: `%s` with `A(T)` peaking near %.1f K.', sources.geometryRunName, sourceData.T_relax);
lines{end+1} = '';
lines{end+1} = '## 5. What will and will not be recomputed';
lines{end+1} = '- Reused without recomputation: saved raw DeltaM map, saved log-time grid, saved per-temperature timelaw tables, saved `A(T)` profile, and prior diagnostics/reports.';
lines{end+1} = '- Recomputed downstream only: local beta(T) fits on the saved map for a small audit set of window/weighting/normalization choices, plus the missing shared-beta comparison.';
lines{end+1} = '- Not recomputed: raw data import, upstream Relaxation windows, derivative smoothing, geometry/SVD runs, or prior run directories.';
lines{end+1} = '- Reason limited recomputation is necessary: no saved run currently contains the exact shared-beta model comparison or the requested stability audit across analysis choices.';
lines{end+1} = '';
lines{end+1} = '## Discovery Takeaway';
lines{end+1} = sprintf('- The repository already shows that the dominant time dependence is stretched-exponential and that the map is strongly rank-1. The remaining question is whether the saved map supports beta(T) as a stable observable beyond the prior beta(T) range of %.3f to %.3f.', sourceData.referenceBetaRange(1), sourceData.referenceBetaRange(2));
text = strjoin(lines, newline);
end

function result = runVariant(sourceData, variant, cfg)
nX = numel(sourceData.tGrid);
mask = true(nX, 1);
dropEarlyN = floor(variant.dropEarly * nX);
dropLateN = floor(variant.dropLate * nX);
if dropEarlyN > 0
    mask(1:dropEarlyN) = false;
end
if dropLateN > 0
    mask(max(1, nX - dropLateN + 1):nX) = false;
end
result = struct();
result.variant = variant;
result.T = sourceData.T;
firstTrace = prepareTrace(sourceData.tGrid(mask), sourceData.dMMap(1, mask).', variant, cfg);
result.traces = repmat(firstTrace, numel(sourceData.T), 1);
result.traces(1) = firstTrace;
firstFit = fitLocalTrace(firstTrace, sourceData.T(1), variant, cfg);
result.localFits = repmat(firstFit, numel(sourceData.T), 1);
result.localFits(1) = firstFit;
for i = 2:numel(sourceData.T)
    result.traces(i) = prepareTrace(sourceData.tGrid(mask), sourceData.dMMap(i, mask).', variant, cfg);
    result.localFits(i) = fitLocalTrace(result.traces(i), sourceData.T(i), variant, cfg);
end
end

function trace = prepareTrace(t, y, variant, cfg)
trace = struct();
trace.t = t(:);
trace.yRaw = y(:);
trace.variant = variant;
trace.valid = true;
tailN = min(cfg.tailCount, numel(trace.yRaw));
trace.tailLevel = mean(trace.yRaw(end-tailN+1:end), 'omitnan');
trace.empiricalScale = trace.yRaw(1) - trace.tailLevel;
if trace.empiricalScale == 0
    trace.empiricalScale = 1;
end
if variant.normalized
    trace.y = (trace.yRaw - trace.tailLevel) / max(abs(trace.empiricalScale), eps);
else
    trace.y = trace.yRaw;
end
if numel(trace.t) < 20 || ~all(isfinite(trace.y))
    trace.valid = false;
end
end

function fit = fitLocalTrace(trace, T, variant, cfg)
fit = emptyFitRow(T, variant);
if ~trace.valid
    fit.fit_status = 'failed';
    return;
end
params = struct();
params.timeWeight = variant.timeWeight;
try
    [pars, R2, stats] = fitStretchedExp(trace.t, trace.y, NaN, false, params);
catch
    fit.fit_status = 'failed';
    return;
end
if isfield(stats, 'Mfit') && ~isempty(stats.Mfit)
    yFit = stats.Mfit(:);
else
    yFit = pars.Minf + pars.dM .* exp(-(((trace.t - min(trace.t)) ./ max(pars.tau, eps)) .^ pars.n));
end
fit.Minf = pars.Minf;
fit.amplitude = pars.dM;
fit.tau = pars.tau;
fit.beta = pars.n;
fit.R2 = R2;
fit.RMSE = computeRMSE(trace.y, yFit);
fit.SSE = sum((trace.y - yFit) .^ 2);
fit.yFit = yFit;
fit.amp_snr = abs(pars.dM) / max(fit.RMSE, eps);
fit.fit_status = classifyFit(fit, cfg);
fit.notes = makeFitNote(trace, fit);
end

function fit = emptyFitRow(T, variant)
fit = struct('T', T, 'variant_id', variant.id, 'fit_window_label', variantWindowLabel(variant), ...
    'weighting_label', variantWeightLabel(variant), 'normalization_label', variantNormalizationLabel(variant), ...
    'fit_status', 'failed', 'beta', NaN, 'beta_uncertainty', NaN, 'tau', NaN, 'tau_uncertainty', NaN, ...
    'amplitude', NaN, 'amplitude_uncertainty', NaN, 'Minf', NaN, 'R2', NaN, 'RMSE', NaN, 'SSE', NaN, ...
    'yFit', [], 'amp_snr', NaN);
end

function label = variantWindowLabel(variant)
if variant.dropEarly > 0
    label = 'exclude_early_10pct';
elseif variant.dropLate > 0
    label = 'exclude_late_10pct';
else
    label = 'full_window';
end
end

function label = variantWeightLabel(variant)
if variant.timeWeight
    label = 'existing_timeWeight';
else
    label = 'unweighted';
end
end

function label = variantNormalizationLabel(variant)
if variant.normalized
    label = 'amplitude_normalized';
else
    label = 'raw';
end
end

function status = classifyFit(fit, cfg)
if ~isfinite(fit.beta) || ~isfinite(fit.tau)
    status = 'failed';
elseif fit.amp_snr < cfg.minAmpSNR
    status = 'low_signal';
elseif fit.R2 < cfg.minR2Ok
    status = 'borderline_fit';
else
    status = 'ok';
end
end

function txt = makeFitNote(trace, fit)
parts = {};
if strcmp(fit.fit_status, 'low_signal')
    parts{end+1} = sprintf('amp_snr=%.3f', fit.amp_snr);
end
if trace.variant.normalized
    parts{end+1} = sprintf('empirical_scale=%.6g', abs(trace.empiricalScale));
end
if trace.variant.timeWeight
    parts{end+1} = 'existing_fitStretchedExp_timeWeight=true';
end
if isempty(parts)
    txt = '';
else
    txt = strjoin(parts, '; ');
end
end
function mask = deriveComparisonMask(localFits, cfg)
mask = false(numel(localFits), 1);
for i = 1:numel(localFits)
    mask(i) = isfinite(localFits(i).beta) && isfinite(localFits(i).tau) && (localFits(i).amp_snr >= cfg.minAmpSNR);
end
end

function globalModel = fitGlobalModel(traces, localFits, comparisonMask, cfg)
globalModel = struct();
globalModel.beta = NaN;
globalModel.beta_uncertainty = NaN;
globalModel.fits = repmat(struct(), numel(traces), 1);
if nnz(comparisonMask) < 3
    globalModel.fits = localFits;
    return;
end
betaSeed = [localFits(comparisonMask).beta];
betaLo = max(cfg.betaBounds(1), min(betaSeed) - 0.08);
betaHi = min(cfg.betaBounds(2), max(betaSeed) + 0.08);
coarseGrid = linspace(betaLo, betaHi, 31);
coarseSSE = nan(size(coarseGrid));
for i = 1:numel(coarseGrid)
    coarseSSE(i) = objectiveGlobalSSE(coarseGrid(i), traces, localFits, comparisonMask, cfg);
end
[~, idxBest] = min(coarseSSE);
beta0 = coarseGrid(idxBest);
try
    betaBest = fminbnd(@(b) objectiveGlobalSSE(b, traces, localFits, comparisonMask, cfg), max(cfg.betaBounds(1), beta0 - 0.08), min(cfg.betaBounds(2), beta0 + 0.08));
catch
    betaBest = beta0;
end
profileGrid = linspace(max(cfg.betaBounds(1), betaBest - 0.08), min(cfg.betaBounds(2), betaBest + 0.08), 41);
profileSSE = nan(size(profileGrid));
for i = 1:numel(profileGrid)
    profileSSE(i) = objectiveGlobalSSE(profileGrid(i), traces, localFits, comparisonMask, cfg);
end
fits = repmat(localFits(1), numel(traces), 1);
for i = 1:numel(traces)
    fits(i) = fitFixedBetaTrace(traces(i), localFits(i), betaBest, cfg);
end
globalModel.beta = betaBest;
globalModel.beta_uncertainty = estimateGlobalBetaUncertainty(profileGrid, profileSSE);
globalModel.profileGrid = profileGrid(:);
globalModel.profileSSE = profileSSE(:);
globalModel.fits = fits;
end

function sse = objectiveGlobalSSE(betaValue, traces, localFits, comparisonMask, cfg)
if ~isfinite(betaValue)
    sse = Inf;
    return;
end
sse = 0;
for i = find(comparisonMask(:)).'
    fit = fitFixedBetaTrace(traces(i), localFits(i), betaValue, cfg);
    if ~isfinite(fit.SSE)
        sse = Inf;
        return;
    end
    sse = sse + fit.SSE;
end
end

function fit = fitFixedBetaTrace(trace, initFit, betaValue, cfg)
variant = trace.variant;
fit = emptyFitRow(initFit.T, variant);
if ~trace.valid || ~isfinite(betaValue)
    return;
end
params = struct();
params.timeWeight = variant.timeWeight;
model = @(x, tn) x(1) + x(2) .* exp(-(tn ./ max(x(3), eps)) .^ betaValue);
tmin = min(trace.t);
dt = max(trace.t) - min(trace.t);
tn = (trace.t - tmin) ./ max(dt, eps);
if params.timeWeight
    w = 1 + 4 * (1 - tn);
    wSqrt = sqrt(w);
    modelEval = @(x, xdata) wSqrt .* model(x, xdata);
    ydata = wSqrt .* trace.y;
else
    modelEval = @(x, xdata) model(x, xdata);
    ydata = trace.y;
end
if isfinite(initFit.Minf) && isfinite(initFit.amplitude) && isfinite(initFit.tau)
    x0 = [initFit.Minf, initFit.amplitude, initFit.tau / max(dt, eps)];
else
    x0 = [trace.tailLevel, trace.y(1) - trace.tailLevel, 0.35];
end
lb = [-Inf, -Inf, cfg.tauBoundsNorm(1)];
ub = [ Inf,  Inf, cfg.tauBoundsNorm(2)];
opts = optimoptions('lsqcurvefit', 'Display', 'off', 'MaxFunctionEvaluations', 4000, 'MaxIterations', 1000);
try
    [x, ~, ~, exitflag] = lsqcurvefit(modelEval, x0, tn, ydata, lb, ub, opts);
catch
    return;
end
yFit = model(x, tn);
fit.Minf = x(1);
fit.amplitude = x(2);
fit.tau = x(3) * dt;
fit.beta = betaValue;
fit.R2 = computeR2(trace.y, yFit);
fit.RMSE = computeRMSE(trace.y, yFit);
fit.SSE = sum((trace.y - yFit) .^ 2);
fit.yFit = yFit;
fit.amp_snr = abs(fit.amplitude) / max(fit.RMSE, eps);
fit.fit_status = classifyFit(fit, cfg);
fit.notes = sprintf('global_beta=%.6g; exitflag=%d', betaValue, exitflag);
end

function sigma = estimateGlobalBetaUncertainty(betaGrid, sseGrid)
sigma = NaN;
ok = isfinite(betaGrid) & isfinite(sseGrid);
betaGrid = betaGrid(ok);
sseGrid = sseGrid(ok);
if numel(betaGrid) < 7
    return;
end
[~, idxMin] = min(sseGrid);
idx = max(1, idxMin - 3):min(numel(betaGrid), idxMin + 3);
p = polyfit(betaGrid(idx), sseGrid(idx), 2);
if numel(p) < 3 || p(1) <= 0
    return;
end
sigma = sqrt(1 / p(1));
end

function summary = summarizeModel(fits, comparisonMask, modelName)
summary = struct('model_name', modelName, 'parameter_count', NaN, 'temperature_count', 0, 'point_count', 0, ...
    'sse_total', NaN, 'rmse_total', NaN, 'median_rmse_by_T', NaN, 'aic', NaN, 'bic', NaN, 'beta_summary', NaN);
mask = comparisonMask(:);
mask = mask & arrayfun(@(f) isfinite(f.SSE), fits(:));
summary.temperature_count = nnz(mask);
if summary.temperature_count == 0
    return;
end
sseByT = [fits(mask).SSE];
rmseByT = [fits(mask).RMSE];
summary.point_count = sum(arrayfun(@(f) numel(f.yFit), fits(mask)));
summary.sse_total = sum(sseByT);
summary.rmse_total = sqrt(summary.sse_total / max(summary.point_count, 1));
summary.median_rmse_by_T = median(rmseByT, 'omitnan');
if strcmp(modelName, 'local_beta')
    summary.parameter_count = 4 * summary.temperature_count;
    summary.beta_summary = mean([fits(mask).beta], 'omitnan');
else
    summary.parameter_count = 3 * summary.temperature_count + 1;
    summary.beta_summary = fits(find(mask, 1, 'first')).beta;
end
summary.aic = computeAIC(summary.sse_total, summary.point_count, summary.parameter_count);
summary.bic = computeBIC(summary.sse_total, summary.point_count, summary.parameter_count);
end

function tbl = buildBetaFitTable(results, sources)
rows = cell(0, 16);
for v = 1:numel(results)
    fits = results(v).localFits;
    for i = 1:numel(fits)
        rows(end+1, :) = {fits(i).T, fits(i).fit_status, fits(i).beta, fits(i).beta_uncertainty, ...
            fits(i).tau, fits(i).tau_uncertainty, fits(i).amplitude, fits(i).amplitude_uncertainty, ...
            fits(i).R2, fits(i).RMSE, fits(i).SSE, fits(i).fit_window_label, fits(i).weighting_label, ...
            fits(i).normalization_label, sources.mapRunName, fits(i).notes}; %#ok<AGROW>
    end
end
tbl = cell2table(rows, 'VariableNames', {'T', 'fit_status', 'beta', 'beta_uncertainty', 'tau', 'tau_uncertainty', ...
    'amplitude', 'amplitude_uncertainty', 'goodness_of_fit_R2', 'goodness_of_fit_RMSE', 'goodness_of_fit_SSE', ...
    'fit_window_label', 'weighting_label', 'normalization_label', 'source_run', 'notes'});
tbl = sortrows(tbl, {'normalization_label', 'fit_window_label', 'weighting_label', 'T'});
end

function tbl = buildComparisonTable(results)
rows = cell(0, 17);
for v = 1:numel(results)
    localSummary = results(v).localSummary;
    globalSummary = results(v).globalSummary;
    deltaAIC = localSummary.aic - globalSummary.aic;
    deltaBIC = localSummary.bic - globalSummary.bic;
    rows(end+1, :) = {results(v).variant.id, 'global_beta', globalSummary.parameter_count, globalSummary.temperature_count, globalSummary.point_count, ...
        variantWindowLabel(results(v).variant), variantWeightLabel(results(v).variant), variantNormalizationLabel(results(v).variant), ...
        globalSummary.beta_summary, globalSummary.sse_total, globalSummary.rmse_total, globalSummary.median_rmse_by_T, globalSummary.aic, globalSummary.bic, ...
        'parsimonious shared shape', 'cannot absorb T-specific beta drift', compareConclusion(deltaAIC, deltaBIC)}; %#ok<AGROW>
    rows(end+1, :) = {results(v).variant.id, 'beta_T', localSummary.parameter_count, localSummary.temperature_count, localSummary.point_count, ...
        variantWindowLabel(results(v).variant), variantWeightLabel(results(v).variant), variantNormalizationLabel(results(v).variant), ...
        localSummary.beta_summary, localSummary.sse_total, localSummary.rmse_total, localSummary.median_rmse_by_T, localSummary.aic, localSummary.bic, ...
        'allows per-temperature beta(T)', 'adds one beta parameter per temperature', compareConclusion(deltaAIC, deltaBIC)}; %#ok<AGROW>
end
tbl = cell2table(rows, 'VariableNames', {'variant_label', 'model_name', 'number_of_effective_parameters', ...
    'temperatures_compared', 'points_compared', 'fit_window_label', 'weighting_label', 'normalization_label', ...
    'beta_summary', 'sse_total', 'rmse_total', 'median_rmse_by_T', 'aic', 'bic', 'main_strengths', 'main_weaknesses', 'conclusion'});
end

function verdict = compareConclusion(deltaAIC, deltaBIC)
if ~isfinite(deltaAIC) || ~isfinite(deltaBIC)
    verdict = 'inconclusive';
elseif deltaBIC <= -10
    verdict = 'local_beta_materially_preferred';
elseif deltaAIC <= -10 && deltaBIC < 0
    verdict = 'local_beta_moderately_preferred';
elseif abs(deltaAIC) < 2 || deltaBIC >= 0
    verdict = 'global_beta_sufficient';
else
    verdict = 'mixed';
end
end

function tbl = buildStabilityTable(results, cfg)
ref = results(1).localFits;
early = results(2).localFits;
late = results(3).localFits;
weighted = results(4).localFits;
normd = results(5).localFits;
rows = cell(numel(ref), 8);
for i = 1:numel(ref)
        vals = [ref(i).beta, early(i).beta, late(i).beta, weighted(i).beta, normd(i).beta];
        maxShift = max(abs(vals(2:end) - vals(1)), [], 'omitnan');
        spread = max(vals, [], 'omitnan') - min(vals, [], 'omitnan');
        if strcmp(ref(i).fit_status, 'failed') || strcmp(ref(i).fit_status, 'low_signal')
            flag = 'unstable';
        elseif maxShift <= cfg.stableShift
            flag = 'stable';
        elseif maxShift <= cfg.borderlineShift
            flag = 'borderline';
        else
            flag = 'unstable';
        end
        comments = {};
        if ref(i).T <= 5 || ref(i).T >= 35
            comments{end+1} = 'edge_temperature';
        end
        if ~strcmp(ref(i).fit_status, 'ok')
            comments{end+1} = ['reference_status=' ref(i).fit_status];
        end
        rows(i, :) = {ref(i).T, ref(i).beta, early(i).beta, late(i).beta, weighted(i).beta, normd(i).beta, spread, flag};
        commentCol{i,1} = strjoin(comments, '; '); %#ok<AGROW>
end
tbl = cell2table(rows, 'VariableNames', {'T', 'beta_reference', 'beta_alt_window_1', 'beta_alt_window_2', 'beta_alt_weighting', 'beta_alt_normalized', 'spread_metric', 'stability_flag'});
tbl.comments = commentCol;
tbl = sortrows(tbl, 'T');
end

function tbl = buildFeatureTable(referenceResult, stabilityTbl, sourceData, sources, cfg)
refFits = referenceResult.localFits;
globalBeta = referenceResult.globalModel.beta;
rows = cell(numel(refFits), 7);
for i = 1:numel(refFits)
    region = regionLabel(refFits(i).T, cfg);
    stab = stabilityTbl.stability_flag{i};
    comment = {};
    if refFits(i).T >= cfg.peakBand(1) && refFits(i).T <= cfg.peakBand(2)
        comment{end+1} = sprintf('near A(T) peak (A/max=%.3f)', sourceData.A_norm(i));
    elseif refFits(i).T >= cfg.shoulderBand(1) && refFits(i).T <= cfg.shoulderBand(2)
        comment{end+1} = sprintf('inside prior low-T shoulder band (A/max=%.3f)', sourceData.A_norm(i));
    end
    if abs(refFits(i).beta - globalBeta) <= 0.01
        comment{end+1} = 'beta close to shared-beta reference';
    elseif refFits(i).beta > globalBeta
        comment{end+1} = 'beta above shared-beta reference';
    else
        comment{end+1} = 'beta below shared-beta reference';
    end
    comment{end+1} = ['stability=' stab];
    rows(i, :) = {refFits(i).T, refFits(i).beta, sourceData.A_T(i), sourceData.A_norm(i), region, sources.geometryRunName, strjoin(comment, '; ')};
end
tbl = cell2table(rows, 'VariableNames', {'T', 'beta', 'A_if_available', 'normalized_A_if_available', 'shoulder_or_region_label_if_defined', 'source_run', 'comments'});
end

function label = regionLabel(T, cfg)
if T >= cfg.shoulderBand(1) && T <= cfg.shoulderBand(2)
    label = 'lowT_shoulder_band_from_coordinate_audit';
elseif T >= cfg.mainBand(1) && T <= cfg.mainBand(2)
    label = 'main_lobe_band_from_coordinate_audit';
elseif T >= cfg.peakBand(1) && T <= cfg.peakBand(2)
    label = 'peak_core_around_27K';
elseif T <= 5
    label = 'lowT_edge';
elseif T >= 35
    label = 'highT_edge';
else
    label = 'no_prior_band_label';
end
end

function summary = summarizeAudit(results, stabilityTbl, featureTbl, cfg)
summary = struct();
summary.referenceGlobalBeta = results(1).globalModel.beta;
summary.referenceGlobalBetaUncertainty = results(1).globalModel.beta_uncertainty;
if ~(isfinite(summary.referenceGlobalBetaUncertainty) && summary.referenceGlobalBetaUncertainty < 0.1)
    summary.referenceGlobalBetaUncertainty = NaN;
end
summary.referenceDeltaAIC = results(1).localSummary.aic - results(1).globalSummary.aic;
summary.referenceDeltaBIC = results(1).localSummary.bic - results(1).globalSummary.bic;
usable = isfinite(featureTbl.beta) & ~strcmp(stabilityTbl.stability_flag, 'unstable');
shapeMask = isfinite(featureTbl.beta) & (featureTbl.normalized_A_if_available > 0.01);
summary.nStable = nnz(strcmp(stabilityTbl.stability_flag, 'stable'));
summary.nBorderline = nnz(strcmp(stabilityTbl.stability_flag, 'borderline'));
if any(usable)
    summary.usableRange = [min(featureTbl.beta(usable), [], 'omitnan'), max(featureTbl.beta(usable), [], 'omitnan')];
    summary.betaStd = std(featureTbl.beta(usable), 0, 'omitnan');
    summary.medianSpread = median(stabilityTbl.spread_metric(usable), 'omitnan');
else
    summary.usableRange = [NaN, NaN];
    summary.betaStd = NaN;
    summary.medianSpread = NaN;
end
if any(shapeMask)
    summary.shapeRange = [min(featureTbl.beta(shapeMask), [], 'omitnan'), max(featureTbl.beta(shapeMask), [], 'omitnan')];
    summary.betaPeakBandMean = mean(featureTbl.beta(featureTbl.T >= cfg.peakBand(1) & featureTbl.T <= cfg.peakBand(2) & shapeMask), 'omitnan');
    summary.betaShoulderBandMean = mean(featureTbl.beta(featureTbl.T >= cfg.shoulderBand(1) & featureTbl.T <= cfg.shoulderBand(2) & shapeMask), 'omitnan');
    summary.betaAcorrelation = corrSafe(featureTbl.beta(shapeMask), featureTbl.normalized_A_if_available(shapeMask));
else
    summary.shapeRange = [NaN, NaN];
    summary.betaPeakBandMean = NaN;
    summary.betaShoulderBandMean = NaN;
    summary.betaAcorrelation = NaN;
end
strongBIC = 0;
strongAIC = 0;
for v = 1:numel(results)
    dAIC = results(v).localSummary.aic - results(v).globalSummary.aic;
    dBIC = results(v).localSummary.bic - results(v).globalSummary.bic;
    if isfinite(dBIC) && dBIC <= -10
        strongBIC = strongBIC + 1;
    end
    if isfinite(dAIC) && dAIC <= -10
        strongAIC = strongAIC + 1;
    end
end
summary.strongBICCount = strongBIC;
summary.strongAICCount = strongAIC;
signalDominatesSpread = isfinite(summary.betaStd) && isfinite(summary.medianSpread) && (summary.betaStd > 1.5 * max(summary.medianSpread, eps));
if strongBIC >= 3 && signalDominatesSpread && summary.nStable >= 10
    summary.finalConclusion = 'beta(T) is robust enough to carry forward.';
elseif (strongAIC >= 2 || summary.referenceDeltaAIC <= -10) && ~signalDominatesSpread
    summary.finalConclusion = 'beta(T) variation is tentative but not stable enough to promote beyond the shared-beta summary.';
else
    summary.finalConclusion = 'A global beta is sufficient for now.';
end
end

function reportText = buildReport(discoveryText, sources, sourceData, results, stabilityTbl, featureTbl, summary, cfg)
lines = {};
if isfinite(summary.referenceGlobalBetaUncertainty)
    globalBetaLine = sprintf('- Reference global beta = %.4f +/- %.4f', summary.referenceGlobalBeta, summary.referenceGlobalBetaUncertainty);
else
    globalBetaLine = sprintf('- Reference global beta = %.4f (profile-curvature uncertainty not reliable in this audit)', summary.referenceGlobalBeta);
end
if all(isfinite(summary.usableRange))
    usableRangeLine = sprintf('- Usable beta(T) range after stability screening = %.4f to %.4f', summary.usableRange(1), summary.usableRange(2));
else
    usableRangeLine = '- Usable beta(T) range after stability screening = not available';
end
if all(isfinite(summary.shapeRange))
    shapeRangeLine = sprintf('- Raw signal-bearing beta(T) range before stability screening = %.4f to %.4f', summary.shapeRange(1), summary.shapeRange(2));
else
    shapeRangeLine = '- Raw signal-bearing beta(T) range before stability screening = not available';
end
if isfinite(summary.betaPeakBandMean)
    peakBandLine = sprintf('- Mean beta(T) in the 27 K peak band = %.4f', summary.betaPeakBandMean);
else
    peakBandLine = '- Mean beta(T) in the 27 K peak band = not robustly defined';
end
if isfinite(summary.betaShoulderBandMean)
    shoulderBandLine = sprintf('- Mean beta(T) in the previously labeled low-T shoulder band = %.4f', summary.betaShoulderBandMean);
else
    shoulderBandLine = '- Mean beta(T) in the previously labeled low-T shoulder band = not robustly defined';
end
if isfinite(summary.betaAcorrelation)
    corrLine = sprintf('- Correlation between beta(T) and normalized A(T) over signal-bearing temperatures = %.4f', summary.betaAcorrelation);
else
    corrLine = '- Correlation between beta(T) and normalized A(T) over signal-bearing temperatures = not robustly defined';
end
lines{end+1} = '# beta(T) Audit Report';
lines{end+1} = '';
lines{end+1} = '## 1. Discovery summary';
lines{end+1} = '';
lines{end+1} = discoveryText;
lines{end+1} = '';
lines{end+1} = '## 2. Data sources used';
lines{end+1} = ['- Saved DeltaM map: `' sources.mapPath '`'];
if ~isempty(sources.timeGridPath)
    lines{end+1} = ['- Saved time grid: `' sources.timeGridPath '`'];
end
lines{end+1} = ['- Prior timelaw table: `' sources.timeFitResultsPath '`'];
lines{end+1} = ['- Prior temperature-observable table: `' sources.temperatureObsPath '`'];
lines{end+1} = ['- Prior rank-1 amplitude profile table: `' sources.modeProfilesPath '`'];
lines{end+1} = sprintf('- Temperatures analyzed: %d from %.1f K to %.1f K', numel(sourceData.T), min(sourceData.T), max(sourceData.T));
lines{end+1} = sprintf('- Time points analyzed: %d from %.3f s to %.3f s', numel(sourceData.tGrid), min(sourceData.tGrid), max(sourceData.tGrid));
lines{end+1} = '';
lines{end+1} = '## 3. Fit definition';
lines{end+1} = '- Raw-trace model: `DeltaM(T,t) = M_inf(T) + A(T) * exp(-((t-t0)/tau(T))^beta)` with `t0` fixed to the first point of the selected saved window.';
lines{end+1} = '- Global-beta model: shared `beta` with per-temperature `M_inf`, `A`, and `tau`.';
lines{end+1} = '- Local-beta model: one free `beta(T)` per temperature.';
lines{end+1} = '- Weighting audit: the existing `fitStretchedExp` early-time weighting option (`timeWeight=true`) was reused rather than inventing a new weighting rule.';
lines{end+1} = '- Normalized audit: each trace was rescaled by its empirical first-minus-tail amplitude so raw and normalized analyses stay clearly separated.';
lines{end+1} = sprintf('- Bounds reused for the downstream audit: beta in [%.2f, %.2f] and tau/window_span in [%.2f, %.2f].', cfg.betaBounds(1), cfg.betaBounds(2), cfg.tauBoundsNorm(1), cfg.tauBoundsNorm(2));
lines{end+1} = '';
lines{end+1} = '## 4. Candidate models tested';
lines{end+1} = '- Model A: global beta.';
lines{end+1} = '- Model B: beta(T).';
lines{end+1} = '- Audit variants: raw full window, raw without earliest 10%, raw without latest 10%, raw with existing time weighting, and normalized full-window fits.';
lines{end+1} = '';
lines{end+1} = '## 5. Stability audit';
lines{end+1} = sprintf('- Stable beta(T) points: %d / %d', summary.nStable, numel(sourceData.T));
lines{end+1} = sprintf('- Borderline beta(T) points: %d', summary.nBorderline);
lines{end+1} = sprintf('- Median beta spread across audit variants on usable temperatures: %.4f', summary.medianSpread);
lines{end+1} = '- Edge temperatures were flagged conservatively rather than forced into the main interpretation.';
lines{end+1} = '';
lines{end+1} = '## 6. Main empirical findings';
lines{end+1} = globalBetaLine;
lines{end+1} = usableRangeLine;
lines{end+1} = shapeRangeLine;
lines{end+1} = sprintf('- Reference deltaAIC(local-global) = %.3f', summary.referenceDeltaAIC);
lines{end+1} = sprintf('- Reference deltaBIC(local-global) = %.3f', summary.referenceDeltaBIC);
lines{end+1} = sprintf('- Variants with strong BIC support for local beta(T): %d / %d', summary.strongBICCount, numel(results));
lines{end+1} = sprintf('- Variants with strong AIC support for local beta(T): %d / %d', summary.strongAICCount, numel(results));
lines{end+1} = '';
lines{end+1} = '## 7. Relation to known Relaxation structure';
lines{end+1} = sprintf('- Reused rank-1 amplitude profile peaks near %.1f K.', sourceData.T_relax);
lines{end+1} = peakBandLine;
lines{end+1} = shoulderBandLine;
lines{end+1} = corrLine;
lines{end+1} = '- No separate beta-specific crossover band already existed in saved Relaxation outputs, so any crossover language here is limited to comparing beta(T) with the previously saved shoulder-like and peak-like bands.';
lines{end+1} = '';
lines{end+1} = '## 8. Interpretation limits';
lines{end+1} = '- This audit only tests whether beta(T) behaves like a stable downstream observable on the saved map.';
lines{end+1} = '- It does not justify claims about glass transitions, barrier distributions, microscopic mechanisms, or distinct barrier populations.';
lines{end+1} = '- The reported uncertainties are limited because the reused helper does not export full confidence intervals for every audit variant.';
lines{end+1} = '';
lines{end+1} = '## 9. Final conclusion';
lines{end+1} = ['- ' summary.finalConclusion];
lines{end+1} = '- Practical carry-forward rule from this audit: keep global beta in summary-level reporting unless a later independent check reproduces the same beta(T) structure with comparable stability.';
lines{end+1} = '';
lines{end+1} = '## Visualization choices';
lines{end+1} = '- number of curves: at most 5 beta(T) audit curves in one panel, 2 score bars per variant, 2 overlays in the beta-vs-A figure, and 3 representative fit overlays.';
lines{end+1} = '- legend vs colormap: legends for all line plots because each panel stays at 6 curves or fewer.';
lines{end+1} = '- colormap used: default MATLAB line colors plus light neutral band shading for the prior shoulder and main-lobe bands.';
lines{end+1} = '- smoothing applied: none in the new audit figures; all fits operate on the saved exported map or explicit window/normalization variants of it.';
reportText = strjoin(lines, newline);
end
function paths = saveBetaCurveFigure(referenceResult, stabilityTbl, sourceData, runDir, cfg)
fig = figure('Color', 'w', 'Visible', cfg.figureVisible, 'Position', [120 120 980 560]);
ax = axes(fig);
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);
addBand(ax, cfg.shoulderBand, [0.97 0.94 0.85]);
addBand(ax, cfg.mainBand, [0.90 0.94 0.99]);
refFits = referenceResult.localFits;
stable = strcmp(stabilityTbl.stability_flag, 'stable');
borderline = strcmp(stabilityTbl.stability_flag, 'borderline');
unstable = strcmp(stabilityTbl.stability_flag, 'unstable');
plot(ax, [refFits(stable).T], [refFits(stable).beta], 'o-', 'Color', [0.10 0.35 0.75], 'LineWidth', 2.2, 'MarkerSize', 6, 'DisplayName', 'stable beta(T)');
if any(borderline)
    plot(ax, [refFits(borderline).T], [refFits(borderline).beta], 's--', 'Color', [0.85 0.45 0.10], 'LineWidth', 2.0, 'MarkerSize', 6, 'DisplayName', 'borderline beta(T)');
end
if any(unstable)
    plot(ax, [refFits(unstable).T], [refFits(unstable).beta], 'x', 'Color', [0.75 0.20 0.20], 'LineWidth', 2.0, 'MarkerSize', 8, 'DisplayName', 'unstable / low-signal');
end
yline(ax, referenceResult.globalModel.beta, '--', 'Color', [0.20 0.20 0.20], 'LineWidth', 1.7, 'DisplayName', sprintf('global beta = %.4f', referenceResult.globalModel.beta));
xline(ax, 27, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.4, 'DisplayName', '27 K');
xlabel(ax, 'Temperature (K)', 'FontSize', 15);
ylabel(ax, '\beta', 'FontSize', 15);
title(ax, 'Relaxation \beta(T) audit', 'FontSize', 16, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', 11);
paths = save_run_figure(fig, 'beta_T_curve', runDir);
close(fig);
end

function paths = saveComparisonFigure(results, runDir, cfg)
labels = cell(numel(results), 1);
dAIC = nan(numel(results), 1);
dBIC = nan(numel(results), 1);
rmseGain = nan(numel(results(1).T), 1);
for i = 1:numel(results)
    labels{i} = results(i).variant.id;
    dAIC(i) = results(i).localSummary.aic - results(i).globalSummary.aic;
    dBIC(i) = results(i).localSummary.bic - results(i).globalSummary.bic;
end
for i = 1:numel(rmseGain)
    lf = results(1).localFits(i);
    gf = results(1).globalModel.fits(i);
    if isfinite(lf.RMSE) && isfinite(gf.RMSE)
        rmseGain(i) = gf.RMSE - lf.RMSE;
    end
end
fig = figure('Color', 'w', 'Visible', cfg.figureVisible, 'Position', [100 100 1120 720]);
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile; hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
set(ax1, 'FontSize', 13, 'LineWidth', 1.1);
X = 1:numel(labels);
bar(ax1, X - 0.15, dAIC, 0.30, 'FaceColor', [0.15 0.45 0.75], 'DisplayName', '\DeltaAIC (local-global)');
bar(ax1, X + 0.15, dBIC, 0.30, 'FaceColor', [0.80 0.35 0.10], 'DisplayName', '\DeltaBIC (local-global)');
yline(ax1, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.3);
set(ax1, 'XTick', X, 'XTickLabel', labels);
xtickangle(ax1, 20);
xlabel(ax1, 'Audit variant', 'FontSize', 14);
ylabel(ax1, 'Penalized score difference', 'FontSize', 14);
title(ax1, 'Global vs local beta model comparison', 'FontSize', 16, 'FontWeight', 'bold');
legend(ax1, 'Location', 'best', 'FontSize', 11);
ax2 = nexttile; hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
set(ax2, 'FontSize', 13, 'LineWidth', 1.1);
plot(ax2, results(1).T, rmseGain, 'o-', 'Color', [0.10 0.35 0.75], 'LineWidth', 2.2, 'MarkerSize', 6);
yline(ax2, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.3);
xline(ax2, 27, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.3);
xlabel(ax2, 'Temperature (K)', 'FontSize', 14);
ylabel(ax2, 'RMSE(global) - RMSE(local)', 'FontSize', 14);
title(ax2, 'Where local beta(T) improves the reference raw fit', 'FontSize', 15, 'FontWeight', 'bold');
paths = save_run_figure(fig, 'global_vs_local_beta_comparison', runDir);
close(fig);
end

function paths = saveStabilityFigure(results, runDir, cfg)
fig = figure('Color', 'w', 'Visible', cfg.figureVisible, 'Position', [100 100 1080 620]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);
cols = lines(numel(results));
styles = {'-o', '--s', '--d', '-.^', ':x'};
for i = 1:numel(results)
    plot(ax, results(i).T, [results(i).localFits.beta], styles{i}, 'Color', cols(i, :), 'LineWidth', 2.0, 'MarkerSize', 5, 'DisplayName', results(i).variant.title);
end
addBand(ax, cfg.mainBand, [0.92 0.96 1.00]);
xline(ax, 27, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.4);
xlabel(ax, 'Temperature (K)', 'FontSize', 15);
ylabel(ax, '\beta', 'FontSize', 15);
title(ax, '\beta(T) stability across audit variants', 'FontSize', 16, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', 10);
paths = save_run_figure(fig, 'beta_T_stability_audit', runDir);
close(fig);
end

function paths = saveOverlayFigure(referenceResult, sourceData, runDir, cfg)
fig = figure('Color', 'w', 'Visible', cfg.figureVisible, 'Position', [110 110 980 560]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);
addBand(ax, cfg.shoulderBand, [0.97 0.94 0.85]);
addBand(ax, cfg.mainBand, [0.90 0.94 0.99]);
yyaxis(ax, 'left');
plot(ax, referenceResult.T, [referenceResult.localFits.beta], 'o-', 'Color', [0.10 0.35 0.75], 'LineWidth', 2.3, 'MarkerSize', 6, 'DisplayName', '\beta(T)');
yline(ax, referenceResult.globalModel.beta, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.7, 'DisplayName', 'global beta');
ylabel(ax, '\beta', 'FontSize', 15);
yyaxis(ax, 'right');
plot(ax, sourceData.T, sourceData.A_norm, 's-', 'Color', [0.80 0.25 0.10], 'LineWidth', 2.4, 'MarkerSize', 6, 'DisplayName', 'A(T) / max(A)');
ylabel(ax, 'Normalized A(T)', 'FontSize', 15);
xline(ax, 27, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.4, 'DisplayName', '27 K');
xlabel(ax, 'Temperature (K)', 'FontSize', 15);
title(ax, '\beta(T) overlaid with A(T)', 'FontSize', 16, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', 11);
paths = save_run_figure(fig, 'beta_T_vs_A_overlay', runDir);
close(fig);
end

function paths = saveExampleFitsFigure(referenceResult, comparisonMask, runDir, cfg)
idx = chooseRepresentativeIndices(referenceResult.T, comparisonMask, cfg.representativeTemperatures);
fig = figure('Color', 'w', 'Visible', cfg.figureVisible, 'Position', [80 80 1200 420]);
tiledlayout(fig, 1, numel(idx), 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:numel(idx)
    i = idx(k);
    ax = nexttile; hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    set(ax, 'FontSize', 13, 'LineWidth', 1.0, 'XScale', 'log');
    trace = referenceResult.traces(i);
    lf = referenceResult.localFits(i);
    gf = referenceResult.globalModel.fits(i);
    plot(ax, trace.t, trace.yRaw, 'k-', 'LineWidth', 2.0, 'DisplayName', 'data');
    plot(ax, trace.t, unnormalizeFit(trace, lf.yFit), '-', 'Color', [0.10 0.35 0.75], 'LineWidth', 2.2, 'DisplayName', sprintf('local \beta=%.3f', lf.beta));
    plot(ax, trace.t, unnormalizeFit(trace, gf.yFit), '--', 'Color', [0.80 0.25 0.10], 'LineWidth', 2.2, 'DisplayName', sprintf('global \beta=%.3f', gf.beta));
    xlabel(ax, 't (s)', 'FontSize', 14);
    ylabel(ax, '\DeltaM(T,t)', 'FontSize', 14);
    title(ax, sprintf('T = %.1f K', trace.yRaw(1)*0 + referenceResult.T(i)), 'FontSize', 15, 'FontWeight', 'bold');
    if k == 1
        legend(ax, 'Location', 'best', 'FontSize', 10);
    end
end
paths = save_run_figure(fig, 'example_fits_by_temperature', runDir);
close(fig);
end

function y = unnormalizeFit(trace, yFit)
if trace.variant.normalized
    y = trace.tailLevel + sign(trace.empiricalScale) * abs(trace.empiricalScale) * yFit(:);
else
    y = yFit(:);
end
end

function idx = chooseRepresentativeIndices(T, mask, targets)
valid = find(mask);
if isempty(valid)
    idx = 1:min(numel(T), numel(targets));
    return;
end
idx = zeros(size(targets));
for i = 1:numel(targets)
    [~, rel] = min(abs(T(valid) - targets(i)));
    idx(i) = valid(rel);
end
idx = unique(idx, 'stable');
end

function addBand(ax, band, colorVal)
yl = ylim(ax);
patch(ax, [band(1) band(2) band(2) band(1)], [yl(1) yl(1) yl(2) yl(2)], colorVal, 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

function zipPath = buildReviewZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'beta_T_audit_bundle.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function outPath = saveTextInTables(runDir, fileName, txt)
tablesDir = fullfile(runDir, 'tables');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
outPath = fullfile(tablesDir, fileName);
fid = fopen(outPath, 'w', 'n', 'UTF-8');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function R2 = computeR2(y, yFit)
ssRes = sum((y(:) - yFit(:)) .^ 2, 'omitnan');
ssTot = sum((y(:) - mean(y(:), 'omitnan')) .^ 2, 'omitnan');
if ssTot <= 0
    R2 = 1;
else
    R2 = 1 - ssRes / ssTot;
end
end

function rmse = computeRMSE(y, yFit)
rmse = sqrt(mean((y(:) - yFit(:)) .^ 2, 'omitnan'));
end

function aic = computeAIC(sse, n, k)
aic = n * log(max(sse, eps) / max(n, 1)) + 2 * k;
end

function bic = computeBIC(sse, n, k)
bic = n * log(max(sse, eps) / max(n, 1)) + k * log(max(n, 1));
end

function r = corrSafe(x, y)
r = NaN;
ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);
if numel(x) < 3
    return;
end
cc = corrcoef(x, y);
if numel(cc) >= 4
    r = cc(1, 2);
end
end

function appendText(pathValue, txt)
fid = fopen(pathValue, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function cfg = setDef(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end




