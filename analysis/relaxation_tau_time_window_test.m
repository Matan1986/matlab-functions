function out = relaxation_tau_time_window_test(cfg)
% relaxation_tau_time_window_test
% Cross-experiment tau(T) extraction and experiment-window hypothesis test
% built on saved Relaxation, Aging, and Switching runs.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
sources = discoverSources(repoRoot);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = buildDatasetLabel(sources);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Relaxation tau time-window test run directory:\n%s\n', runDir);
appendText(run.log_path, sprintf('[%s] started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source run: %s\n', char(sources.relax.stabilityRunName)));
appendText(run.log_path, sprintf('Aging source run: %s\n', char(sources.aging.shapeRunName)));
appendText(run.log_path, sprintf('Switching source run: %s\n', char(sources.switching.switchRunName)));

relax = loadRelaxationBundle(sources, cfg);
aging = loadAgingBundle(sources, cfg);
switching = loadSwitchingBundle(sources, cfg);
analysis = analyzeTauHypothesis(relax, aging, switching, cfg);

save_run_table(analysis.tauVsTemperatureTable, 'tau_vs_temperature.csv', runDir);
save_run_table(analysis.modelComparisonTable, 'tau_model_comparison.csv', runDir);
save_run_table(analysis.alignmentSummaryTable, 'time_window_alignment_summary.csv', runDir);
save_run_table(analysis.fitQualityTable, 'fit_quality_summary.csv', runDir);

figTau = saveTauVsTemperatureFigure(relax, analysis, runDir, 'tau_vs_temperature');
figTauA = saveTauVsAFigure(relax, analysis, runDir, 'tau_vs_A_of_T');
figWindow = saveTauVsExperimentalWindowFigure(relax, analysis, runDir, 'tau_vs_experimental_window');
figExamples = saveFitExamplesFigure(relax, analysis, runDir, 'fit_examples_selected_temperatures');
figAlign = saveTauAlignmentFigure(relax, aging, switching, analysis, runDir, 'tau_alignment_with_switching_and_aging');
figArrh = saveArrheniusDiagnosticFigure(relax, analysis, runDir, 'Arrhenius_or_nonArrhenius_diagnostic');

reportText = buildReport(relax, aging, switching, analysis, sources, cfg, runDir);
reportPath = save_run_report(reportText, 'relaxation_tau_time_window_test.md', runDir);
zipPath = buildReviewZip(runDir, 'relaxation_tau_time_window_test_bundle.zip');

appendText(run.log_path, sprintf('[%s] completed\n', stampNow()));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));
appendText(run.notes_path, sprintf('Final tau strategy: %s\n', char(analysis.finalSummary.strategy_id)));
appendText(run.notes_path, sprintf('Final verdict: %s\n', char(analysis.hypothesisVerdict)));
appendText(run.notes_path, sprintf('tau(A_peak)/t_exp = %.6g\n', analysis.finalSummary.tau_at_A_peak_s / analysis.timeWindow.t_experiment_s));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.sources = sources;
out.relax = relax;
out.aging = aging;
out.switching = switching;
out.analysis = analysis;
out.figures = struct( ...
    'tau_vs_temperature', string(figTau.png), ...
    'tau_vs_A_of_T', string(figTauA.png), ...
    'tau_vs_experimental_window', string(figWindow.png), ...
    'fit_examples_selected_temperatures', string(figExamples.png), ...
    'tau_alignment_with_switching_and_aging', string(figAlign.png), ...
    'Arrhenius_or_nonArrhenius_diagnostic', string(figArrh.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Relaxation tau time-window test complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Final tau strategy: %s\n', char(analysis.finalSummary.strategy_id));
fprintf('Final verdict: %s\n', char(analysis.hypothesisVerdict));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'relaxation_tau_time_window_test');
cfg = setDefault(cfg, 'relaxSignalFloorFrac', 0.05);
cfg = setDefault(cfg, 'switchingSignalFloorFrac', 0.05);
cfg = setDefault(cfg, 'headCount', 5);
cfg = setDefault(cfg, 'tailCount', 12);
cfg = setDefault(cfg, 'switchingSmoothWindow', 3);
cfg = setDefault(cfg, 'selectedExampleTemps', [15, 27, 35]);
cfg = setDefault(cfg, 'agingShapeVariationThreshold', 0.25);
cfg = setDefault(cfg, 'agingRank1Threshold', 0.85);
cfg = setDefault(cfg, 'supportFactorStrong', 2.0);
cfg = setDefault(cfg, 'supportFactorWeak', 5.0);
cfg = setDefault(cfg, 'arrheniusStrongR2Min', 0.5);
cfg = setDefault(cfg, 'arrheniusStrongDeltaAICMin', 6.0);
cfg = setDefault(cfg, 'markerAlignmentToleranceK', 3.0);
cfg = setDefault(cfg, 'finalTauStrategy', 'map_fixed_beta_tau');
end

function sources = discoverSources(repoRoot)
relaxRunsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
agingRunsRoot = fullfile(repoRoot, 'results', 'aging', 'runs');
switchRunsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');

sources = struct();

sources.relax = struct();
sources.relax.mapRunDir = findLatestRunWithFiles(relaxRunsRoot, {fullfile('csv', 'map_dM_raw.csv'), fullfile('csv', 'time_grid_used.csv')});
sources.relax.mapRunName = string(filepartsToName(sources.relax.mapRunDir));
sources.relax.mapPath = fullfile(sources.relax.mapRunDir, 'csv', 'map_dM_raw.csv');
sources.relax.timeGridPath = fullfile(sources.relax.mapRunDir, 'csv', 'time_grid_used.csv');
sources.relax.timelawRunDir = findLatestRunWithFiles(relaxRunsRoot, {fullfile('tables', 'time_fit_results.csv'), fullfile('reports', 'relaxation_timelaw_observables.md')});
sources.relax.timelawRunName = string(filepartsToName(sources.relax.timelawRunDir));
sources.relax.stabilityRunDir = findLatestRunWithFiles(relaxRunsRoot, {fullfile('tables', 'temperature_observables.csv'), fullfile('tables', 'observables_relaxation.csv')});
sources.relax.stabilityRunName = string(filepartsToName(sources.relax.stabilityRunDir));
sources.relax.timeModeRunDir = findLatestRunWithFiles(relaxRunsRoot, {fullfile('tables', 'time_mode_fits.csv'), fullfile('tables', 'collapse_metrics.csv')});
sources.relax.timeModeRunName = string(filepartsToName(sources.relax.timeModeRunDir));
sources.relax.betaAuditRunDir = findLatestRunWithFiles(relaxRunsRoot, {fullfile('tables', 'beta_T_stability_summary.csv'), fullfile('tables', 'global_vs_local_beta_model_comparison.csv')});
sources.relax.betaAuditRunName = string(filepartsToName(sources.relax.betaAuditRunDir));
sources.relax.legacySurveyRunDir = fullfile(relaxRunsRoot, 'run_legacy_observable_survey');
sources.relax.legacySurveyRunName = "run_legacy_observable_survey";

sources.aging = struct();
sources.aging.shapeRunDir = findLatestRunWithFiles(agingRunsRoot, {fullfile('tables', 'aging_shape_variation_vs_Tp.csv'), fullfile('reports', 'aging_shape_collapse_analysis.md')});
sources.aging.shapeRunName = string(filepartsToName(sources.aging.shapeRunDir));

sources.switching = struct();
sources.switching.switchRunDir = findLatestRunWithFiles(switchRunsRoot, {'observable_matrix.csv'});
sources.switching.switchRunName = string(filepartsToName(sources.switching.switchRunDir));
sources.switching.observablesPath = fullfile(sources.switching.switchRunDir, 'observable_matrix.csv');
sources.switching.characteristicPath = fullfile(sources.switching.switchRunDir, 'alignment_audit', 'switching_alignment_characteristic_temperatures.csv');

sources.inspectedFiles = string({ ...
    fullfile(repoRoot, 'docs', 'AGENT_RULES.md'), ...
    fullfile(repoRoot, 'docs', 'results_system.md'), ...
    fullfile(repoRoot, 'docs', 'repository_structure.md'), ...
    fullfile(repoRoot, 'docs', 'output_artifacts.md'), ...
    fullfile(repoRoot, 'docs', 'visualization_rules.md'), ...
    fullfile(repoRoot, 'docs', 'figure_style_guide.md'), ...
    fullfile(repoRoot, 'Relaxation ver3', 'diagnostics', 'run_relaxation_timelaw_observables.m'), ...
    fullfile(repoRoot, 'Relaxation ver3', 'diagnostics', 'run_relaxation_observable_stability_audit.m'), ...
    fullfile(repoRoot, 'Relaxation ver3', 'diagnostics', 'run_relaxation_beta_T_audit.m'), ...
    fullfile(repoRoot, 'Relaxation ver3', 'diagnostics', 'run_relaxation_time_mode_analysis.m'), ...
    fullfile(repoRoot, 'Relaxation ver3', 'diagnostics', 'compare_relaxation_models.m'), ...
    fullfile(repoRoot, 'Relaxation ver3', 'fitStretchedExp.m'), ...
    fullfile(repoRoot, 'Relaxation ver3', 'plotArrhenius.m'), ...
    fullfile(repoRoot, 'analysis', 'relaxation_switching_motion_test.m'), ...
    fullfile(repoRoot, 'analysis', 'ridge_crossover_vs_relaxation.m')});
end

function label = buildDatasetLabel(sources)
label = sprintf('relax:%s | aging:%s | switch:%s', char(sources.relax.stabilityRunName), char(sources.aging.shapeRunName), char(sources.switching.switchRunName));
end

function runDir = findLatestRunWithFiles(runsRoot, relativeFiles)
entries = dir(fullfile(runsRoot, 'run_*'));
entries = entries([entries.isdir]);
if isempty(entries)
    error('No run directories found under %s', runsRoot);
end

names = string({entries.name});
entries = entries(~startsWith(names, "run_legacy", 'IgnoreCase', true));
if isempty(entries)
    error('No non-legacy runs found under %s', runsRoot);
end

[~, order] = sort({entries.name});
entries = entries(order);
runDir = '';
for i = numel(entries):-1:1
    candidate = fullfile(entries(i).folder, entries(i).name);
    ok = true;
    for j = 1:numel(relativeFiles)
        if exist(fullfile(candidate, relativeFiles{j}), 'file') ~= 2
            ok = false;
            break;
        end
    end
    if ok
        runDir = candidate;
        return;
    end
end
error('No run matching required files was found under %s', runsRoot);
end

function name = filepartsToName(pathStr)
[~, name] = fileparts(char(pathStr));
end

function relax = loadRelaxationBundle(sources, cfg)
[map, Tmap, xGrid] = loadMapMatrix(sources.relax.mapPath);
timeGridTbl = readtable(sources.relax.timeGridPath);
if ismember('t_rel_s', string(timeGridTbl.Properties.VariableNames))
    tGrid = timeGridTbl.t_rel_s(:);
else
    tGrid = 10 .^ xGrid(:);
end

tempObs = sortrows(readtable(fullfile(sources.relax.stabilityRunDir, 'tables', 'temperature_observables.csv')), 'T');
obs = readtable(fullfile(sources.relax.stabilityRunDir, 'tables', 'observables_relaxation.csv'));
timelaw = readtable(fullfile(sources.relax.timelawRunDir, 'tables', 'time_fit_results.csv'));
timeModeFits = readtable(fullfile(sources.relax.timeModeRunDir, 'tables', 'time_mode_fits.csv'));
collapseMetrics = readtable(fullfile(sources.relax.timeModeRunDir, 'tables', 'collapse_metrics.csv'));
barrierMetrics = readtable(fullfile(sources.relax.timeModeRunDir, 'tables', 'barrier_scaling_metrics.csv'));
betaStability = sortrows(readtable(fullfile(sources.relax.betaAuditRunDir, 'tables', 'beta_T_stability_summary.csv')), 'T');
betaModelComp = readtable(fullfile(sources.relax.betaAuditRunDir, 'tables', 'global_vs_local_beta_model_comparison.csv'));
legacyStability = readtable(fullfile(sources.relax.legacySurveyRunDir, 'tables', 'fit_observable_stability_by_temp.csv'));
legacyRaw = readtable(fullfile(sources.relax.legacySurveyRunDir, 'tables', 'fit_observables_raw.csv'));

sliceMask = strcmpi(string(timelaw.scope), 'temperature_slice') & strcmpi(string(timelaw.model), 'stretched_exponential');
freeTbl = sortrows(timelaw(sliceMask, :), 'Temp_K');
legacyTau = sortrows(legacyStability(strcmpi(string(legacyStability.observable), 'tau_kww'), :), 'Temp_K');

globalBeta = obs.Relax_beta_global(1);
fixedTbl = fitFixedBetaTau(Tmap, tGrid, map, globalBeta, cfg);
empiricalTbl = computeEmpiricalTimes(Tmap, tGrid, map, cfg);

[A_low, A_high, A_width, A_peak] = computeHalfMaxWindow(tempObs.T, tempObs.A_T);
if ~(isfinite(A_peak) && isfinite(A_width))
    A_peak = obs.Relax_T_peak(1);
    A_width = obs.Relax_peak_width(1);
    A_low = A_peak - 0.5 * A_width;
    A_high = A_peak + 0.5 * A_width;
end

signalFloor = cfg.relaxSignalFloorFrac * max(tempObs.A_T, [], 'omitnan');
signalMask = tempObs.A_T >= signalFloor;

tbl = table(tempObs.T(:), tempObs.A_T(:), tempObs.R_T(:), 'VariableNames', {'T_K', 'A_T', 'R_T'});
tbl.A_norm = normalizePositive(tbl.A_T);
tbl.signal_bearing = signalMask(:);
tbl.free_beta_tau_s = matchByTemperature(freeTbl.Temp_K, freeTbl.param_tau, tbl.T_K);
tbl.free_beta_beta = matchByTemperature(freeTbl.Temp_K, freeTbl.param_beta, tbl.T_K);
tbl.free_beta_R2 = matchByTemperature(freeTbl.Temp_K, freeTbl.R2, tbl.T_K);
tbl.free_beta_AIC = matchByTemperature(freeTbl.Temp_K, getOrDefault(freeTbl, 'AIC', NaN(height(freeTbl), 1)), tbl.T_K);
tbl.free_beta_RMSE = matchByTemperature(freeTbl.Temp_K, getOrDefault(freeTbl, 'rms_error', NaN(height(freeTbl), 1)), tbl.T_K);
tbl.fixed_beta_tau_s = matchByTemperature(fixedTbl.T_K, fixedTbl.tau_s, tbl.T_K);
tbl.fixed_beta_R2 = matchByTemperature(fixedTbl.T_K, fixedTbl.R2, tbl.T_K);
tbl.fixed_beta_RMSE = matchByTemperature(fixedTbl.T_K, fixedTbl.RMSE, tbl.T_K);
tbl.fixed_beta_t_half_s = matchByTemperature(fixedTbl.T_K, fixedTbl.t_half_s, tbl.T_K);
tbl.fixed_beta_fit_ok = logical(matchByTemperature(fixedTbl.T_K, double(fixedTbl.fit_ok), tbl.T_K));
tbl.empirical_t_half_s = matchByTemperature(empiricalTbl.T_K, empiricalTbl.t_half_s, tbl.T_K);
tbl.empirical_t_one_over_e_s = matchByTemperature(empiricalTbl.T_K, empiricalTbl.t_one_over_e_s, tbl.T_K);
tbl.empirical_amplitude = matchByTemperature(empiricalTbl.T_K, empiricalTbl.amplitude, tbl.T_K);
tbl.legacy_tau_kww_mean_s = matchByTemperature(legacyTau.Temp_K, legacyTau.mean_value, tbl.T_K);
tbl.legacy_tau_kww_cv = matchByTemperature(legacyTau.Temp_K, legacyTau.cv, tbl.T_K);
tbl.legacy_tau_kww_coverage = matchByTemperature(legacyTau.Temp_K, legacyTau.coverage, tbl.T_K);
tbl.beta_stability_flag = matchByTemperatureString(betaStability.T, betaStability.stability_flag, tbl.T_K);
tbl.beta_spread_metric = matchByTemperature(betaStability.T, betaStability.spread_metric, tbl.T_K);
tbl.beta_comments = matchByTemperatureString(betaStability.T, betaStability.comments, tbl.T_K);
tbl.final_tau_s = tbl.fixed_beta_tau_s;

relax = struct();
relax.T = Tmap(:);
relax.tGrid = tGrid(:);
relax.xGrid = xGrid(:);
relax.map = map;
relax.temperatureTable = tbl;
relax.timelawTable = freeTbl;
relax.fixedBetaTable = fixedTbl;
relax.empiricalTable = empiricalTbl;
relax.legacyTauByTemp = legacyTau;
relax.legacyRaw = legacyRaw;
relax.observables = obs;
relax.timeModeFits = timeModeFits;
relax.collapseMetrics = collapseMetrics;
relax.barrierMetrics = barrierMetrics;
relax.betaStability = betaStability;
relax.betaModelComparison = betaModelComp;
relax.globalBeta = globalBeta;
relax.globalTau = obs.Relax_tau_global(1);
relax.globalHalf = obs.Relax_t_half(1);
relax.A_peak_T_K = A_peak;
relax.A_halfmax_low_K = A_low;
relax.A_halfmax_high_K = A_high;
relax.A_halfmax_width_K = A_width;
relax.A_peak_value = obs.Relax_Amp_peak(1);
relax.signalFloor = signalFloor;
relax.mapRunName = sources.relax.mapRunName;
relax.timelawRunName = sources.relax.timelawRunName;
relax.stabilityRunName = sources.relax.stabilityRunName;
relax.timeModeRunName = sources.relax.timeModeRunName;
relax.betaAuditRunName = sources.relax.betaAuditRunName;
relax.legacySurveyRunName = sources.relax.legacySurveyRunName;
end

function aging = loadAgingBundle(sources, cfg)
shapePath = fullfile(sources.aging.shapeRunDir, 'tables', 'aging_shape_variation_vs_Tp.csv');
opts = detectImportOptions(shapePath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
shapeTbl = readtable(shapePath, opts);
TpName = pickVariableName(shapeTbl.Properties.VariableNames, ["Tp_K", "Tp"]);
shapeName = pickVariableName(shapeTbl.Properties.VariableNames, ["shape_variation", "shape"]);
rankName = pickVariableName(shapeTbl.Properties.VariableNames, ["rank1_explained_variance_ratio", "rank1"]);
Tp = numericColumn(shapeTbl.(TpName));
shapeVar = numericColumn(shapeTbl.(shapeName));
rankVar = numericColumn(shapeTbl.(rankName));
shapeTbl.Tp_K = Tp;
shapeTbl.shape_variation = shapeVar;
shapeTbl.rank1_explained_variance_ratio = rankVar;
shapeTbl = sortrows(shapeTbl, 'Tp_K');
strongMask = shapeTbl.shape_variation <= cfg.agingShapeVariationThreshold & shapeTbl.rank1_explained_variance_ratio >= cfg.agingRank1Threshold;
if any(strongMask)
    strongLow = min(shapeTbl.Tp_K(strongMask));
    strongHigh = max(shapeTbl.Tp_K(strongMask));
else
    strongLow = NaN;
    strongHigh = NaN;
end
[~, idxBest] = min(shapeTbl.shape_variation);
referenceTp = NaN;
if any(abs(shapeTbl.Tp_K - 26) <= 1e-9)
    referenceTp = 26;
elseif ~isempty(idxBest)
    referenceTp = shapeTbl.Tp_K(idxBest);
end
aging = struct();
aging.shapeTable = shapeTbl;
aging.shapeRunName = sources.aging.shapeRunName;
aging.referenceTp_K = referenceTp;
aging.bestVariationTp_K = shapeTbl.Tp_K(idxBest);
aging.bestShapeVariation = shapeTbl.shape_variation(idxBest);
aging.bestRank1Ratio = shapeTbl.rank1_explained_variance_ratio(idxBest);
aging.strongBandLow_K = strongLow;
aging.strongBandHigh_K = strongHigh;
aging.strongBandMid_K = mean([strongLow, strongHigh], 'omitnan');
end

function switching = loadSwitchingBundle(sources, cfg)
switching = struct();
switching.available = false;
switching.switchRunName = sources.switching.switchRunName;
switching.savedCharacteristicTemps = table();

if exist(sources.switching.observablesPath, 'file') ~= 2
    return;
end

obsTbl = readtable(sources.switching.observablesPath);
vars = string(obsTbl.Properties.VariableNames);
if all(ismember(["T", "I_peak", "S_peak"], vars))
    T = obsTbl.T(:);
    I = obsTbl.I_peak(:);
    S = obsTbl.S_peak(:);
else
    fallbackPath = fullfile(sources.switching.switchRunDir, 'alignment_audit', 'switching_alignment_observables_vs_T.csv');
    if exist(fallbackPath, 'file') ~= 2
        return;
    end
    obsTbl = readtable(fallbackPath);
    T = getColumn(obsTbl, 'T_K');
    I = getColumn(obsTbl, 'Ipeak');
    S = getColumn(obsTbl, 'S_peak');
end

switching.available = true;
switching.T = T(:);
switching.I_peak = I(:);
switching.S_peak = S(:);
switching.signalFloor = cfg.switchingSignalFloorFrac * max(S, [], 'omitnan');
switching.robustMask = isfinite(T) & isfinite(I) & isfinite(S) & S >= switching.signalFloor;
switching.I_peak_smooth = NaN(size(T));
switching.S_peak_smooth = NaN(size(T));
switching.dI_peak_dT = NaN(size(T));
switching.dS_peak_dT = NaN(size(T));
switching.motion = NaN(size(T));
switching.growth = NaN(size(T));
switching.balance = NaN(size(T));
switching.crossover_indicator = NaN(size(T));
switching.motionPeakT_K = NaN;
switching.crossoverPeakT_K = NaN;
switching.balanceCrossT_K = NaN;

Tg = switching.T(switching.robustMask);
Ig = switching.I_peak(switching.robustMask);
Sg = switching.S_peak(switching.robustMask);
if numel(Tg) >= 3
    span = min(cfg.switchingSmoothWindow, numel(Tg));
    Is = smoothdata(Ig, 'movmean', span);
    Ss = smoothdata(Sg, 'movmean', span);
    motion = abs(gradient(Is, Tg));
    growth = abs(gradient(Ss, Tg));
    motionNorm = normalizePositive(motion);
    growthNorm = normalizePositive(growth);
    balance = growthNorm - motionNorm;
    indicator = 0.5 * (motionNorm + growthNorm) .* max(0, 1 - abs(balance));

    switching.I_peak_smooth(switching.robustMask) = Is;
    switching.S_peak_smooth(switching.robustMask) = Ss;
    switching.dI_peak_dT(switching.robustMask) = gradient(Is, Tg);
    switching.dS_peak_dT(switching.robustMask) = gradient(Ss, Tg);
    switching.motion(switching.robustMask) = motionNorm;
    switching.growth(switching.robustMask) = growthNorm;
    switching.balance(switching.robustMask) = balance;
    switching.crossover_indicator(switching.robustMask) = indicator;

    [~, idxMotion] = max(motionNorm);
    [~, idxCross] = max(indicator);
    switching.motionPeakT_K = Tg(idxMotion);
    switching.crossoverPeakT_K = Tg(idxCross);
    switching.balanceCrossT_K = zeroCross(Tg, balance);
end

if exist(sources.switching.characteristicPath, 'file') == 2
    switching.savedCharacteristicTemps = readtable(sources.switching.characteristicPath);
end
end

function analysis = analyzeTauHypothesis(relax, aging, switching, cfg)
TW = struct();
TW.t_min_s = min(relax.tGrid);
TW.t_max_s = max(relax.tGrid);
TW.t_span_s = max(relax.tGrid) - min(relax.tGrid);
TW.t_geometric_mid_s = sqrt(max(TW.t_min_s, eps) * max(TW.t_max_s, eps));
TW.t_experiment_s = TW.t_max_s;

T = relax.temperatureTable.T_K;
A = relax.temperatureTable.A_T;
signalMask = relax.temperatureTable.signal_bearing;

freeLaw = fitConstantVsArrhenius(T(signalMask), relax.temperatureTable.free_beta_tau_s(signalMask));
fixedLaw = fitConstantVsArrhenius(T(signalMask), relax.temperatureTable.fixed_beta_tau_s(signalMask));
empLaw = fitConstantVsArrhenius(T(signalMask), relax.temperatureTable.empirical_t_half_s(signalMask));
legacyLaw = fitConstantVsArrhenius(T(isfinite(relax.temperatureTable.legacy_tau_kww_mean_s)), relax.temperatureTable.legacy_tau_kww_mean_s(isfinite(relax.temperatureTable.legacy_tau_kww_mean_s)));

freeSummary = summarizeTauStrategy('map_free_beta_tau', 'Saved per-temperature KWW tau(T) with free beta(T)', 'stretched_exponential_free_beta', char(relax.timelawRunName), T, relax.temperatureTable.free_beta_tau_s, signalMask, A, relax.A_peak_T_K, TW.t_experiment_s, freeLaw, cfg);
fixedSummary = summarizeTauStrategy('map_fixed_beta_tau', 'Fixed-beta KWW tau(T) fit to saved DeltaM(T,t)', 'stretched_exponential_fixed_beta', char(relax.timelawRunName), T, relax.temperatureTable.fixed_beta_tau_s, signalMask, A, relax.A_peak_T_K, TW.t_experiment_s, fixedLaw, cfg);
empSummary = summarizeTauStrategy('empirical_t_half', 'Empirical half-time from normalized saved DeltaM(T,t)', 'empirical_half_time', char(relax.mapRunName), T, relax.temperatureTable.empirical_t_half_s, signalMask, A, relax.A_peak_T_K, TW.t_experiment_s, empLaw, cfg);
legacyMask = isfinite(relax.temperatureTable.legacy_tau_kww_mean_s);
legacySummary = summarizeTauStrategy('legacy_windowed_kww_mean', 'Legacy windowed KWW tau summary from saved raw-curve survey', 'legacy_windowed_kww', char(relax.legacySurveyRunName), T, relax.temperatureTable.legacy_tau_kww_mean_s, legacyMask, A, relax.A_peak_T_K, TW.t_experiment_s, legacyLaw, cfg);

rows = [freeSummary; fixedSummary; empSummary; legacySummary];
modelComparisonTable = struct2table(rows);
modelComparisonTable.chosen_final = modelComparisonTable.strategy_id == string(cfg.finalTauStrategy);

absLogA = abs(log10(max(fixedSummary.tau_at_A_peak_s, eps) / TW.t_experiment_s));
markerSupport = pointInWindow(relax.A_peak_T_K, aging.strongBandLow_K, aging.strongBandHigh_K);
if switching.available
    markerSupport = markerSupport || abs(switching.motionPeakT_K - relax.A_peak_T_K) <= cfg.markerAlignmentToleranceK || abs(switching.crossoverPeakT_K - relax.A_peak_T_K) <= cfg.markerAlignmentToleranceK;
end
if absLogA <= log10(cfg.supportFactorStrong)
    verdict = "supported";
elseif absLogA <= log10(cfg.supportFactorWeak)
    verdict = "partially_supported";
else
    verdict = "not_supported";
end
if verdict == "supported" && ~markerSupport
    verdict = "partially_supported";
end
arrheniusDeltaAIC = fixedSummary.constant_AIC - fixedSummary.arrhenius_AIC;
if strcmpi(char(fixedSummary.preferred_law), 'Arrhenius') && isfinite(fixedSummary.arrhenius_R2) ...
        && fixedSummary.arrhenius_R2 >= cfg.arrheniusStrongR2Min && isfinite(arrheniusDeltaAIC) ...
        && arrheniusDeltaAIC >= cfg.arrheniusStrongDeltaAICMin
    lawCharacter = "more_global_law_like";
else
    lawCharacter = "local_or_crossover_like";
end

alignmentSummaryTable = struct2table(buildAlignmentRows(relax, aging, switching, fixedSummary, freeSummary, empSummary, legacySummary, TW));

tauTbl = relax.temperatureTable;
tauTbl.t_experiment_s = repmat(TW.t_experiment_s, height(tauTbl), 1);
tauTbl.final_tau_over_t_experiment = tauTbl.final_tau_s ./ TW.t_experiment_s;
tauTbl.free_beta_tau_over_t_experiment = tauTbl.free_beta_tau_s ./ TW.t_experiment_s;
tauTbl.empirical_t_half_over_t_experiment = tauTbl.empirical_t_half_s ./ TW.t_experiment_s;
tauTbl.abs_log10_final_tau_over_t_experiment = abs(log10(max(tauTbl.final_tau_s, eps) ./ TW.t_experiment_s));

analysis = struct();
analysis.timeWindow = TW;
analysis.freeLaw = freeLaw;
analysis.fixedLaw = fixedLaw;
analysis.empLaw = empLaw;
analysis.legacyLaw = legacyLaw;
analysis.freeSummary = freeSummary;
analysis.finalSummary = fixedSummary;
analysis.empiricalSummary = empSummary;
analysis.legacySummary = legacySummary;
analysis.modelComparisonTable = modelComparisonTable;
analysis.alignmentSummaryTable = alignmentSummaryTable;
analysis.tauVsTemperatureTable = tauTbl;
analysis.fitQualityTable = buildFitQualitySummary(relax, freeSummary, fixedSummary, empSummary, legacySummary);
analysis.hypothesisVerdict = verdict;
analysis.lawCharacter = lawCharacter;
analysis.finalArrheniusDeltaAIC = arrheniusDeltaAIC;
end

function summary = summarizeTauStrategy(strategyId, label, modelFamily, sourceRun, T, tau, validityMask, A, ApeakT, tExperiment, law, cfg)
mask = isfinite(T) & isfinite(tau) & (tau > 0) & logical(validityMask(:));
summary = struct();
summary.strategy_id = string(strategyId);
summary.strategy_label = string(label);
summary.model_family = string(modelFamily);
summary.source_run = string(sourceRun);
summary.n_valid = nnz(mask);
summary.temp_min_K = min(T(mask), [], 'omitnan');
summary.temp_max_K = max(T(mask), [], 'omitnan');
summary.median_tau_s = median(tau(mask), 'omitnan');
summary.tau_min_s = min(tau(mask), [], 'omitnan');
summary.tau_max_s = max(tau(mask), [], 'omitnan');
summary.tau_at_A_peak_s = interp1Safe(T(mask), tau(mask), ApeakT);
summary.tau_over_t_experiment_at_A_peak = summary.tau_at_A_peak_s / tExperiment;
if any(mask)
    [~, idxNear] = min(abs(log10(tau(mask) ./ tExperiment)));
    validT = T(mask);
    validTau = tau(mask);
    summary.nearest_t_experiment_T_K = validT(idxNear);
    summary.nearest_t_experiment_tau_s = validTau(idxNear);
    summary.min_abs_log10_tau_over_t_experiment = abs(log10(validTau(idxNear) / tExperiment));
else
    summary.nearest_t_experiment_T_K = NaN;
    summary.nearest_t_experiment_tau_s = NaN;
    summary.min_abs_log10_tau_over_t_experiment = NaN;
end
summary.preferred_law = string(law.preferredLaw);
summary.arrhenius_AIC = law.arrheniusAIC;
summary.constant_AIC = law.constantAIC;
summary.arrhenius_R2 = law.arrheniusR2;
summary.corr_tau_with_A = corrSafe(A(mask), tau(mask));
if strcmp(strategyId, 'map_fixed_beta_tau')
    summary.robustness_class = "current_primary";
    summary.note = "Chosen final tau: current saved-map basis with fixed beta.";
elseif strcmp(strategyId, 'map_free_beta_tau')
    summary.robustness_class = "current_secondary";
    summary.note = "Saved current-workflow tau with free beta(T).";
elseif strcmp(strategyId, 'empirical_t_half')
    summary.robustness_class = "robust_nonparametric";
    summary.note = "Beta-free empirical time scale for cross-checking.";
else
    summary.robustness_class = "legacy_secondary";
    summary.note = "Legacy raw-curve tau summary is informative but not robust enough for the final claim.";
end
summary.support_factor_2 = summary.min_abs_log10_tau_over_t_experiment <= log10(cfg.supportFactorStrong);
summary.support_factor_5 = summary.min_abs_log10_tau_over_t_experiment <= log10(cfg.supportFactorWeak);
end

function rows = buildAlignmentRows(relax, aging, switching, fixedSummary, freeSummary, empSummary, legacySummary, TW)
rows = repmat(struct('marker_name', "", 'marker_kind', "", 'source_run', "", 'T_low_K', NaN, 'T_high_K', NaN, 'T_center_K', NaN, 'final_tau_s', NaN, 'free_beta_tau_s', NaN, 'empirical_t_half_s', NaN, 'legacy_tau_s', NaN, 't_experiment_s', TW.t_experiment_s, 'final_tau_over_t_experiment', NaN, 'abs_log10_final_tau_over_t_experiment', NaN, 'deltaT_to_A_peak_K', NaN, 'deltaT_to_nearest_tau_match_K', NaN, 'within_factor_2', false, 'note', ""), 0, 1);
rows(end + 1) = makeAlignmentRow('relaxation_A_peak', 'point', relax.stabilityRunName, relax.A_peak_T_K, relax.A_peak_T_K, relax.A_peak_T_K, relax, fixedSummary, TW, 'Saved A(T) peak from Relaxation stability audit.');
rows(end + 1) = makeAlignmentRow('aging_reference_Tp26', 'point', aging.shapeRunName, aging.referenceTp_K, aging.referenceTp_K, aging.referenceTp_K, relax, fixedSummary, TW, 'Reference Aging collapse point emphasized in the saved report.');
rows(end + 1) = makeAlignmentRow('aging_best_shape_variation', 'point', aging.shapeRunName, aging.bestVariationTp_K, aging.bestVariationTp_K, aging.bestVariationTp_K, relax, fixedSummary, TW, 'Best shape-variation point from the saved Aging T_p sweep.');
if isfinite(aging.strongBandLow_K) && isfinite(aging.strongBandHigh_K)
    rows(end + 1) = makeAlignmentRow('aging_strong_band_midpoint', 'band_midpoint', aging.shapeRunName, aging.strongBandLow_K, aging.strongBandHigh_K, aging.strongBandMid_K, relax, fixedSummary, TW, 'Midpoint of the saved strong-collapse Aging band.');
end
if switching.available
    rows(end + 1) = makeAlignmentRow('switching_motion_peak', 'point', switching.switchRunName, switching.motionPeakT_K, switching.motionPeakT_K, switching.motionPeakT_K, relax, fixedSummary, TW, 'Derived from saved I_peak(T) using the existing motion-observable definition.');
    rows(end + 1) = makeAlignmentRow('switching_crossover_peak', 'point', switching.switchRunName, switching.crossoverPeakT_K, switching.crossoverPeakT_K, switching.crossoverPeakT_K, relax, fixedSummary, TW, 'Derived from saved switching observables using the existing crossover indicator.');
end
row = makeAlignmentRow('final_tau_nearest_t_experiment', 'point', fixedSummary.source_run, fixedSummary.nearest_t_experiment_T_K, fixedSummary.nearest_t_experiment_T_K, fixedSummary.nearest_t_experiment_T_K, relax, fixedSummary, TW, 'Temperature where the chosen final tau comes closest to t_experiment.');
row.final_tau_s = fixedSummary.nearest_t_experiment_tau_s;
row.deltaT_to_nearest_tau_match_K = 0;
rows(end + 1) = row;
end

function row = makeAlignmentRow(name, kind, sourceRun, Tlow, Thigh, Tcenter, relax, fixedSummary, TW, note)
row = struct('marker_name', string(name), 'marker_kind', string(kind), 'source_run', string(sourceRun), 'T_low_K', Tlow, 'T_high_K', Thigh, 'T_center_K', Tcenter, 'final_tau_s', interp1Safe(relax.temperatureTable.T_K, relax.temperatureTable.final_tau_s, Tcenter), 'free_beta_tau_s', interp1Safe(relax.temperatureTable.T_K, relax.temperatureTable.free_beta_tau_s, Tcenter), 'empirical_t_half_s', interp1Safe(relax.temperatureTable.T_K, relax.temperatureTable.empirical_t_half_s, Tcenter), 'legacy_tau_s', interp1Safe(relax.temperatureTable.T_K, relax.temperatureTable.legacy_tau_kww_mean_s, Tcenter), 't_experiment_s', TW.t_experiment_s, 'final_tau_over_t_experiment', NaN, 'abs_log10_final_tau_over_t_experiment', NaN, 'deltaT_to_A_peak_K', Tcenter - relax.A_peak_T_K, 'deltaT_to_nearest_tau_match_K', Tcenter - fixedSummary.nearest_t_experiment_T_K, 'within_factor_2', false, 'note', string(note));
row.final_tau_over_t_experiment = row.final_tau_s / TW.t_experiment_s;
row.abs_log10_final_tau_over_t_experiment = abs(log10(max(row.final_tau_s, eps) / TW.t_experiment_s));
row.within_factor_2 = row.abs_log10_final_tau_over_t_experiment <= log10(2);
end

function tbl = buildFitQualitySummary(relax, freeSummary, fixedSummary, empSummary, legacySummary)
rows = repmat(struct('scope', "", 'item_id', "", 'description', "", 'n_valid', NaN, 'mean_R2', NaN, 'median_R2', NaN, 'mean_RMSE', NaN, 'median_RMSE', NaN, 'AIC_or_score', NaN, 'deltaAIC_vs_reference', NaN, 'coverage', NaN, 'median_cv', NaN, 'fit_quality_class', "", 'notes', ""), 0, 1);
freeMask = isfinite(relax.temperatureTable.free_beta_tau_s);
fixedMask = isfinite(relax.temperatureTable.fixed_beta_tau_s);
empMask = isfinite(relax.temperatureTable.empirical_t_half_s);
legacyMask = isfinite(relax.temperatureTable.legacy_tau_kww_mean_s);
rows(end + 1) = struct('scope', "temperature_strategy", 'item_id', freeSummary.strategy_id, 'description', freeSummary.strategy_label, 'n_valid', freeSummary.n_valid, 'mean_R2', mean(relax.temperatureTable.free_beta_R2(freeMask), 'omitnan'), 'median_R2', median(relax.temperatureTable.free_beta_R2(freeMask), 'omitnan'), 'mean_RMSE', mean(relax.temperatureTable.free_beta_RMSE(freeMask), 'omitnan'), 'median_RMSE', median(relax.temperatureTable.free_beta_RMSE(freeMask), 'omitnan'), 'AIC_or_score', mean(relax.temperatureTable.free_beta_AIC(freeMask), 'omitnan'), 'deltaAIC_vs_reference', NaN, 'coverage', mean(double(freeMask), 'omitnan'), 'median_cv', median(relax.temperatureTable.beta_spread_metric(freeMask), 'omitnan'), 'fit_quality_class', "current_saved_fit", 'notes', freeSummary.note);
rows(end + 1) = struct('scope', "temperature_strategy", 'item_id', fixedSummary.strategy_id, 'description', fixedSummary.strategy_label, 'n_valid', fixedSummary.n_valid, 'mean_R2', mean(relax.temperatureTable.fixed_beta_R2(fixedMask), 'omitnan'), 'median_R2', median(relax.temperatureTable.fixed_beta_R2(fixedMask), 'omitnan'), 'mean_RMSE', mean(relax.temperatureTable.fixed_beta_RMSE(fixedMask), 'omitnan'), 'median_RMSE', median(relax.temperatureTable.fixed_beta_RMSE(fixedMask), 'omitnan'), 'AIC_or_score', NaN, 'deltaAIC_vs_reference', NaN, 'coverage', mean(double(fixedMask), 'omitnan'), 'median_cv', median(relax.temperatureTable.beta_spread_metric(fixedMask), 'omitnan'), 'fit_quality_class', "current_refit", 'notes', fixedSummary.note);
rows(end + 1) = struct('scope', "temperature_strategy", 'item_id', empSummary.strategy_id, 'description', empSummary.strategy_label, 'n_valid', empSummary.n_valid, 'mean_R2', NaN, 'median_R2', NaN, 'mean_RMSE', NaN, 'median_RMSE', NaN, 'AIC_or_score', NaN, 'deltaAIC_vs_reference', NaN, 'coverage', mean(double(empMask), 'omitnan'), 'median_cv', NaN, 'fit_quality_class', "nonparametric_crosscheck", 'notes', empSummary.note);
rows(end + 1) = struct('scope', "temperature_strategy", 'item_id', legacySummary.strategy_id, 'description', legacySummary.strategy_label, 'n_valid', legacySummary.n_valid, 'mean_R2', NaN, 'median_R2', NaN, 'mean_RMSE', NaN, 'median_RMSE', NaN, 'AIC_or_score', NaN, 'deltaAIC_vs_reference', NaN, 'coverage', median(relax.temperatureTable.legacy_tau_kww_coverage(legacyMask), 'omitnan'), 'median_cv', median(relax.temperatureTable.legacy_tau_kww_cv(legacyMask), 'omitnan'), 'fit_quality_class', "legacy_unstable", 'notes', legacySummary.note);

bestAIC = min(getOrDefault(relax.timeModeFits, 'AIC', NaN(height(relax.timeModeFits), 1)), [], 'omitnan');
for i = 1:height(relax.timeModeFits)
    rows(end + 1) = struct('scope', "dominant_time_mode", 'item_id', string(relax.timeModeFits.model(i)), 'description', sprintf('Saved v_1(t) %s fit', char(relax.timeModeFits.model(i))), 'n_valid', numel(relax.tGrid), 'mean_R2', relax.timeModeFits.R2(i), 'median_R2', relax.timeModeFits.R2(i), 'mean_RMSE', relax.timeModeFits.rms_error(i), 'median_RMSE', relax.timeModeFits.rms_error(i), 'AIC_or_score', getScalarTableValue(relax.timeModeFits, 'AIC', i), 'deltaAIC_vs_reference', getScalarTableValue(relax.timeModeFits, 'AIC', i) - bestAIC, 'coverage', 1, 'median_cv', NaN, 'fit_quality_class', "saved_global_model", 'notes', "Saved time-mode comparison reused directly.");
end

refMask = strcmpi(string(relax.betaModelComparison.variant_label), 'reference_raw_full');
for i = find(refMask(:)).'
    rows(end + 1) = struct('scope', "beta_audit", 'item_id', string(relax.betaModelComparison.model_name(i)), 'description', sprintf('Saved beta audit: %s', char(relax.betaModelComparison.model_name(i))), 'n_valid', relax.betaModelComparison.temperatures_compared(i), 'mean_R2', NaN, 'median_R2', NaN, 'mean_RMSE', NaN, 'median_RMSE', NaN, 'AIC_or_score', relax.betaModelComparison.sse_total(i), 'deltaAIC_vs_reference', NaN, 'coverage', 1, 'median_cv', NaN, 'fit_quality_class', "saved_beta_comparison", 'notes', "Saved beta(T) audit reused to decide whether beta(T) is stable enough.");
    end

tbl = struct2table(rows);
end

function figPaths = saveTauVsTemperatureFigure(relax, analysis, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.8, 7.2);
ax = axes(fh);
hold(ax, 'on');
plot(ax, relax.temperatureTable.T_K, relax.temperatureTable.free_beta_tau_s, '-o', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'Saved free-beta KWW tau(T)');
plot(ax, relax.temperatureTable.T_K, relax.temperatureTable.fixed_beta_tau_s, '-s', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', sprintf('Fixed-beta KWW tau(T), beta=%.3f', relax.globalBeta));
plot(ax, relax.temperatureTable.T_K, relax.temperatureTable.empirical_t_half_s, '-^', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'Empirical t_{1/2}(T)');
plot(ax, relax.temperatureTable.T_K, relax.temperatureTable.legacy_tau_kww_mean_s, '--d', 'LineWidth', 1.5, 'MarkerSize', 5, 'DisplayName', 'Legacy windowed KWW tau_{mean}(T)');
xline(ax, relax.A_peak_T_K, ':', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.4, 'DisplayName', 'A(T) peak');
hold(ax, 'off');
set(ax, 'YScale', 'log');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Characteristic time (s)');
title(ax, 'Relaxation characteristic times versus temperature');
legend(ax, 'Location', 'eastoutside');
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveTauVsAFigure(relax, analysis, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.8, 7.8);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, relax.temperatureTable.T_K, normalizePositive(relax.temperatureTable.fixed_beta_tau_s), '-s', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'Fixed-beta tau(T) / max');
plot(ax1, relax.temperatureTable.T_K, normalizePositive(relax.temperatureTable.empirical_t_half_s), '-^', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'Empirical t_{1/2}(T) / max');
plot(ax1, relax.temperatureTable.T_K, relax.temperatureTable.A_norm, '-o', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'A(T) / max');
hold(ax1, 'off');
grid(ax1, 'on');
xlabel(ax1, 'Temperature (K)');
ylabel(ax1, 'Normalized magnitude');
title(ax1, 'Temperature trends of A(T) and tau-like scales');
legend(ax1, 'Location', 'best');
setAxisStyle(ax1);
addPanelLabel(ax1, 'a');
ax2 = nexttile(tl, 2);
scatter(ax2, relax.temperatureTable.A_norm, relax.temperatureTable.fixed_beta_tau_s, 48, relax.temperatureTable.T_K, 'filled');
cb = colorbar(ax2); cb.Label.String = 'Temperature (K)';
grid(ax2, 'on');
set(ax2, 'YScale', 'log');
xlabel(ax2, 'A(T) / max(A)');
ylabel(ax2, 'Fixed-beta tau(T) (s)');
title(ax2, 'tau(T) against normalized A(T)');
setAxisStyle(ax2);
colormap(ax2, parula);
addPanelLabel(ax2, 'b');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveTauVsExperimentalWindowFigure(relax, analysis, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.8, 7.2);
ax = axes(fh);
hold(ax, 'on');
xlow = min(relax.temperatureTable.T_K); xhigh = max(relax.temperatureTable.T_K);
ylow = analysis.timeWindow.t_experiment_s / 2; yhigh = analysis.timeWindow.t_experiment_s * 2;
patch(ax, [xlow xhigh xhigh xlow], [ylow ylow yhigh yhigh], [0.92 0.92 0.92], 'FaceAlpha', 0.45, 'EdgeColor', 'none', 'DisplayName', 'factor-2 band around t_{exp}');
patch(ax, [xlow xhigh xhigh xlow], [analysis.timeWindow.t_min_s analysis.timeWindow.t_min_s analysis.timeWindow.t_experiment_s analysis.timeWindow.t_experiment_s], [0.85 0.90 1.00], 'FaceAlpha', 0.18, 'EdgeColor', 'none', 'DisplayName', 'saved observation window');
plot(ax, relax.temperatureTable.T_K, relax.temperatureTable.fixed_beta_tau_s, '-s', 'LineWidth', 1.9, 'MarkerSize', 5, 'DisplayName', 'Final fixed-beta tau(T)');
plot(ax, relax.temperatureTable.T_K, relax.temperatureTable.empirical_t_half_s, '--^', 'LineWidth', 1.6, 'MarkerSize', 5, 'DisplayName', 'Empirical t_{1/2}(T)');
yline(ax, analysis.timeWindow.t_experiment_s, '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.5, 'DisplayName', sprintf('t_{exp}=%.0f s', analysis.timeWindow.t_experiment_s));
hold(ax, 'off');
set(ax, 'YScale', 'log');
grid(ax, 'on');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Time scale (s)');
title(ax, 'Relaxation time scales against the saved experimental window');
legend(ax, 'Location', 'eastoutside');
setAxisStyle(ax);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveFitExamplesFigure(relax, analysis, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.8, 6.8);
targets = unique(nearestAvailableTemperatures(relax.temperatureTable.T_K, [15 27 35]));
tl = tiledlayout(fh, 1, numel(targets), 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:numel(targets)
    idx = find(abs(relax.temperatureTable.T_K - targets(i)) <= 1e-9, 1, 'first');
    ax = nexttile(tl, i);
    [tRel, yNorm, ~] = normalizeRelaxationTrace(relax.tGrid, relax.map(idx, :), 5, 12);
    freeFit = buildFreeBetaFit(relax, idx);
    fixedFit = buildFixedBetaFit(relax, idx);
    semilogx(ax, tRel, yNorm, 'k-', 'LineWidth', 2.0, 'DisplayName', 'data'); hold(ax, 'on');
    semilogx(ax, tRel, freeFit, '-', 'Color', [0.00 0.45 0.74], 'LineWidth', 1.7, 'DisplayName', 'saved free-beta fit');
    semilogx(ax, tRel, fixedFit, '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.7, 'DisplayName', 'fixed-beta fit');
    xline(ax, relax.temperatureTable.empirical_t_half_s(idx), ':', 'Color', [0.30 0.30 0.30], 'LineWidth', 1.3, 'DisplayName', 'empirical t_{1/2}');
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, 'Elapsed time (s)');
    ylabel(ax, 'Normalized DeltaM(T,t)');
    title(ax, sprintf('T = %.0f K', targets(i)));
    text(ax, 0.03, 0.08, sprintf('tau_{free}=%.0f s\ntau_{fixed}=%.0f s\nbeta_{free}=%.3f', relax.temperatureTable.free_beta_tau_s(idx), relax.temperatureTable.fixed_beta_tau_s(idx), relax.temperatureTable.free_beta_beta(idx)), 'Units', 'normalized', 'BackgroundColor', 'w', 'Margin', 5, 'FontSize', 8);
    setAxisStyle(ax);
    addPanelLabel(ax, char('a' + i - 1));
    if i == 1
        legend(ax, 'Location', 'best');
    end
end
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveTauAlignmentFigure(relax, aging, switching, analysis, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.8, 10.0);
tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1);
hold(ax1, 'on');
if isfinite(aging.strongBandLow_K) && isfinite(aging.strongBandHigh_K)
    patch(ax1, [aging.strongBandLow_K aging.strongBandHigh_K aging.strongBandHigh_K aging.strongBandLow_K], [1e1 1e1 1e4 1e4], [1.00 0.90 0.82], 'FaceAlpha', 0.22, 'EdgeColor', 'none', 'DisplayName', 'Aging strong-collapse band');
end
plot(ax1, relax.temperatureTable.T_K, relax.temperatureTable.fixed_beta_tau_s, '-s', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'Final fixed-beta tau(T)');
plot(ax1, relax.temperatureTable.T_K, relax.temperatureTable.free_beta_tau_s, '--o', 'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName', 'Saved free-beta tau(T)');
yline(ax1, analysis.timeWindow.t_experiment_s, '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.4, 'DisplayName', 't_{exp}');
xline(ax1, relax.A_peak_T_K, ':', 'Color', [0 0 0], 'LineWidth', 1.4, 'DisplayName', 'Relaxation A peak');
if switching.available
    xline(ax1, switching.motionPeakT_K, '--', 'Color', [0.00 0.45 0.74], 'LineWidth', 1.4, 'DisplayName', 'Switching motion peak');
    xline(ax1, switching.crossoverPeakT_K, '-.', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.4, 'DisplayName', 'Switching crossover peak');
end
hold(ax1, 'off');
set(ax1, 'YScale', 'log'); ylim(ax1, [1e1 1e4]);
grid(ax1, 'on'); xlabel(ax1, 'Temperature (K)'); ylabel(ax1, 'Time scale (s)'); title(ax1, 'Final tau(T) against Relaxation, Aging, and Switching markers'); legend(ax1, 'Location', 'eastoutside'); setAxisStyle(ax1); addPanelLabel(ax1, 'a');
ax2 = nexttile(tl, 2);
hold(ax2, 'on');
if isfinite(aging.strongBandLow_K) && isfinite(aging.strongBandHigh_K)
    patch(ax2, [aging.strongBandLow_K aging.strongBandHigh_K aging.strongBandHigh_K aging.strongBandLow_K], [0 0 1.05 1.05], [1.00 0.90 0.82], 'FaceAlpha', 0.22, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
plot(ax2, relax.temperatureTable.T_K, relax.temperatureTable.A_norm, '-o', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'Relaxation A(T) / max');
if switching.available
    plot(ax2, switching.T, switching.motion, '-s', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'Switching motion(T)');
    plot(ax2, switching.T, switching.crossover_indicator, '-^', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'Switching crossover indicator');
end
xline(ax2, relax.A_peak_T_K, ':', 'Color', [0 0 0], 'LineWidth', 1.4, 'HandleVisibility', 'off');
hold(ax2, 'off');
grid(ax2, 'on'); ylim(ax2, [0 1.05]); xlabel(ax2, 'Temperature (K)'); ylabel(ax2, 'Normalized magnitude'); title(ax2, 'Observable markers used in the alignment test'); legend(ax2, 'Location', 'eastoutside'); setAxisStyle(ax2); addPanelLabel(ax2, 'b');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveArrheniusDiagnosticFigure(relax, analysis, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w');
setFigureGeometry(fh, 17.8, 7.6);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1); plotLawDiagnostic(ax1, relax.temperatureTable.T_K(relax.temperatureTable.signal_bearing), relax.temperatureTable.fixed_beta_tau_s(relax.temperatureTable.signal_bearing), analysis.fixedLaw, 'Final fixed-beta tau(T)'); addPanelLabel(ax1, 'a');
legacyMask = isfinite(relax.temperatureTable.legacy_tau_kww_mean_s);
ax2 = nexttile(tl, 2); plotLawDiagnostic(ax2, relax.temperatureTable.T_K(legacyMask), relax.temperatureTable.legacy_tau_kww_mean_s(legacyMask), analysis.legacyLaw, 'Legacy windowed KWW tau(T)'); addPanelLabel(ax2, 'b');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function plotLawDiagnostic(ax, T, tau, law, ttl)
hold(ax, 'on');
mask = isfinite(T) & isfinite(tau) & tau > 0;
if nnz(mask) >= 4
    T = T(mask); tau = tau(mask);
    scatter(ax, 1 ./ T, log(tau), 30, T, 'filled', 'DisplayName', 'data');
    plot(ax, 1 ./ T, law.constantFitY, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.5, 'DisplayName', 'constant-tau baseline');
    plot(ax, 1 ./ T, law.arrheniusFitY, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.7, 'DisplayName', 'Arrhenius fit');
    cb = colorbar(ax); cb.Label.String = 'Temperature (K)'; colormap(ax, parula);
else
    text(ax, 0.5, 0.5, 'Insufficient valid points', 'Units', 'normalized', 'HorizontalAlignment', 'center');
end
hold(ax, 'off');
grid(ax, 'on'); xlabel(ax, '1 / T (1/K)'); ylabel(ax, 'log(tau / s)'); title(ax, ttl); setAxisStyle(ax);
text(ax, 0.03, 0.08, sprintf('Preferred law: %s\nAIC const = %.2f\nAIC Arrh = %.2f\nR^2_{Arrh} = %.3f', char(law.preferredLaw), law.constantAIC, law.arrheniusAIC, law.arrheniusR2), 'Units', 'normalized', 'BackgroundColor', 'w', 'Margin', 5, 'FontSize', 8);
legend(ax, 'Location', 'best');
end

function reportText = buildReport(relax, aging, switching, analysis, sources, cfg, runDir)
L = strings(0, 1);
L(end + 1) = '# Relaxation tau(T) time-window test';
L(end + 1) = '';
L(end + 1) = sprintf('Generated: %s', stampNow());
L(end + 1) = sprintf('Run root: `%s`', runDir);
L(end + 1) = '';
L(end + 1) = '## Repository-state summary';
L(end + 1) = '- Relevant scripts/files found and inspected:';
for i = 1:numel(sources.inspectedFiles)
    L(end + 1) = sprintf('  - `%s`', char(sources.inspectedFiles(i)));
end
L(end + 1) = '- Existing saved runs reused:';
L(end + 1) = sprintf('  - Relaxation map source: `%s`', char(sources.relax.mapRunName));
L(end + 1) = sprintf('  - Relaxation timelaw source: `%s`', char(sources.relax.timelawRunName));
L(end + 1) = sprintf('  - Relaxation stability source: `%s`', char(sources.relax.stabilityRunName));
L(end + 1) = sprintf('  - Relaxation time-mode source: `%s`', char(sources.relax.timeModeRunName));
L(end + 1) = sprintf('  - Relaxation beta audit source: `%s`', char(sources.relax.betaAuditRunName));
L(end + 1) = sprintf('  - Relaxation legacy observable survey: `%s`', char(sources.relax.legacySurveyRunName));
L(end + 1) = sprintf('  - Aging shape-collapse source: `%s`', char(sources.aging.shapeRunName));
L(end + 1) = sprintf('  - Switching alignment source: `%s`', char(sources.switching.switchRunName));
L(end + 1) = '- Tau already partially available before this analysis:';
L(end + 1) = sprintf('  - Saved current-workflow per-temperature tau(T) and beta(T): `%s/tables/time_fit_results.csv`', char(sources.relax.timelawRunDir));
L(end + 1) = sprintf('  - Saved current-workflow A(T), Relax_tau_T, Relax_beta_T, and Relax_T_peak: `%s/tables/temperature_observables.csv` and `%s/tables/observables_relaxation.csv`', char(sources.relax.stabilityRunDir), char(sources.relax.stabilityRunDir));
L(end + 1) = sprintf('  - Saved legacy raw-curve tau_kww stability summary: `%s/tables/fit_observable_stability_by_temp.csv`', char(sources.relax.legacySurveyRunDir));
L(end + 1) = '- New code added or modified for this task:';
L(end + 1) = sprintf('  - Added `%s`', fullfile(fileparts(fileparts(sources.inspectedFiles(1))), 'analysis', 'relaxation_tau_time_window_test.m'));
L(end + 1) = '';
L(end + 1) = '## What was reused';
L(end + 1) = '- Reused without recomputation: saved raw DeltaM(T,t) map, saved log-time grid, saved per-temperature KWW table, saved A(T) table, saved dominant-mode model comparison, saved beta(T) audit, saved Aging shape-collapse sweep, and saved Switching ridge observables.';
L(end + 1) = '- Reused code definitions: the current-workflow KWW basis from `fitStretchedExp.m`, the saved time-mode model comparison from `run_relaxation_time_mode_analysis.m`, and the existing Switching motion/crossover definitions from `analysis/relaxation_switching_motion_test.m` and `analysis/ridge_crossover_vs_relaxation.m`.';
L(end + 1) = '- New computation was limited to a fixed-beta per-temperature refit on the saved Relaxation map, empirical characteristic times from the same saved map, and a consolidated cross-experiment alignment summary.';
L(end + 1) = '';
L(end + 1) = '## Fit models tested';
L(end + 1) = '- Saved dominant time-mode fits: stretched exponential, logarithmic, and power law.';
L(end + 1) = '- Saved beta-structure comparison: shared global beta versus local beta(T).';
L(end + 1) = '- New temperature-resolved tau definitions on the saved map: free-beta KWW tau (reused), fixed-beta KWW tau (new), and empirical half-time from normalized curves (new).';
L(end + 1) = '- Optional law-level diagnostic on each tau strategy: constant-log-tau baseline versus global Arrhenius fit.';
L(end + 1) = '';
L(end + 1) = '## Why the final tau observable was chosen';
L(end + 1) = sprintf('- Final tau observable: `%s`.', char(analysis.finalSummary.strategy_id));
L(end + 1) = '- Reason: it stays on the current run-based Relaxation architecture, keeps a direct KWW interpretation, and removes the need to promote a temperature-dependent beta(T) after the dedicated beta audit concluded that local beta(T) is not stable enough for strong claims.';
L(end + 1) = sprintf('- The chosen fixed-beta tau remains numerically close to the saved free-beta tau: median tau = %.3f s versus %.3f s.', analysis.finalSummary.median_tau_s, analysis.freeSummary.median_tau_s);
L(end + 1) = '';
L(end + 1) = '## Extraction method for tau(T)';
L(end + 1) = sprintf('- Saved Relaxation time grid reused directly from `%s`.', char(sources.relax.timeGridPath));
L(end + 1) = sprintf('- Saved observation window: %.3f s to %.3f s, with `t_experiment = max(t_rel) = %.3f s`.', analysis.timeWindow.t_min_s, analysis.timeWindow.t_max_s, analysis.timeWindow.t_experiment_s);
L(end + 1) = '- Fixed-beta extraction used the same KWW form as the Relaxation workflow, `DeltaM(T,t) = M_inf(T) + A(T) * exp(-((t-t0)/tau(T))^beta)`, with `beta` fixed to the saved current-workflow global value and `t0` fixed to the first saved time point.';
L(end + 1) = '- Empirical half-time extraction normalized each saved DeltaM(T,t) curve by its first-minus-tail amplitude and interpolated the elapsed time where the normalized curve dropped to 0.5.';
L(end + 1) = '';
L(end + 1) = '## Model comparison results';
L(end + 1) = sprintf('- Saved dominant time-mode best model remains stretched exponential; its saved global fit quality is R^2 = %.6f.', getValueForModel(relax.timeModeFits, 'stretched_exponential', 'R2'));
L(end + 1) = sprintf('- Saved dominant time-mode global KWW parameters: beta = %.6g and tau = %.6g s.', relax.globalBeta, relax.globalTau);
L(end + 1) = sprintf('- In the saved beta audit, the carry-forward conclusion was: global beta is sufficient for now (`%s`).', char(relax.betaAuditRunName));
L(end + 1) = sprintf('- Strategy nearest to `t_experiment`: `%s` at T = %.3f K with tau = %.3f s (minimum |log10(tau / t_experiment)| = %.3f).', char(analysis.finalSummary.strategy_id), analysis.finalSummary.nearest_t_experiment_T_K, analysis.finalSummary.nearest_t_experiment_tau_s, analysis.finalSummary.min_abs_log10_tau_over_t_experiment);
L(end + 1) = sprintf('- For the chosen final strategy, Arrhenius versus constant-law comparison gives %s with deltaAIC = %.3f and Arrhenius R^2 = %.3f, so this is treated as a weak diagnostic rather than a global-law claim.', char(analysis.finalSummary.preferred_law), analysis.finalArrheniusDeltaAIC, analysis.finalSummary.arrhenius_R2);
L(end + 1) = '';
L(end + 1) = '## Alignment with A(T), Aging, and Switching';
L(end + 1) = sprintf('- Relaxation A(T) peak from the saved stability run: %.3f K, with half-maximum window [%.3f, %.3f] K.', relax.A_peak_T_K, relax.A_halfmax_low_K, relax.A_halfmax_high_K);
L(end + 1) = sprintf('- Tau at the Relaxation A(T) peak: %.3f s, so tau(A_peak) / t_experiment = %.3f.', analysis.finalSummary.tau_at_A_peak_s, analysis.finalSummary.tau_over_t_experiment_at_A_peak);
L(end + 1) = sprintf('- Aging reference point from the saved shape-collapse sweep: T_p = %.3f K.', aging.referenceTp_K);
L(end + 1) = sprintf('- Best Aging shape-variation point in the saved sweep: T_p = %.3f K with shape variation %.6g.', aging.bestVariationTp_K, aging.bestShapeVariation);
if isfinite(aging.strongBandLow_K) && isfinite(aging.strongBandHigh_K)
    L(end + 1) = sprintf('- Strong Aging collapse band used here: [%.3f, %.3f] K.', aging.strongBandLow_K, aging.strongBandHigh_K);
end
if switching.available
    L(end + 1) = sprintf('- Switching ridge-motion peak derived from saved I_peak(T): %.3f K.', switching.motionPeakT_K);
    L(end + 1) = sprintf('- Switching crossover-indicator peak derived from the saved ridge observables: %.3f K.', switching.crossoverPeakT_K);
else
    L(end + 1) = '- Switching ridge observables were not available in a reusable saved form.';
end
L(end + 1) = '';
L(end + 1) = '## Hypothesis verdict';
L(end + 1) = sprintf('- Final verdict: **%s**.', strrep(analysis.hypothesisVerdict, '_', ' '));
if analysis.hypothesisVerdict == "supported"
    L(end + 1) = '- The chosen tau(T) reaches the saved experiment window closely enough near the known crossover markers to support `tau(T*) ~ t_experiment` in the stored data.';
elseif analysis.hypothesisVerdict == "partially_supported"
    L(end + 1) = '- The chosen tau(T) stays in the same broad order of magnitude as the saved experiment window near the crossover region, but there is no sharp or unique temperature where tau(T) cleanly crosses `t_experiment`.';
else
    L(end + 1) = '- The chosen tau(T) does not approach the saved experiment window closely enough near the crossover markers to support `tau(T*) ~ t_experiment`.';
end
L(end + 1) = sprintf('- Evidence character: **%s**.', strrep(analysis.lawCharacter, '_', ' '));
if analysis.lawCharacter == "more_global_law_like"
    L(end + 1) = '- The tau(T) trend shows some law-like structure, but without a time-window crossing near the crossover markers it is still not promoted to a global claim.';
else
    L(end + 1) = '- The present evidence is therefore treated as local and crossover-like, not as a global law spanning the full temperature range.';
end
L(end + 1) = '';
L(end + 1) = '## Main findings';
L(end + 1) = sprintf('- The current saved Relaxation workflow already contained a reproducible tau(T), but that tau(T) is narrow and almost flat: saved free-beta tau spans %.3f to %.3f s.', analysis.freeSummary.tau_min_s, analysis.freeSummary.tau_max_s);
L(end + 1) = sprintf('- The chosen fixed-beta tau span is %.3f to %.3f s, so the beta-stabilized refit does not create a new sharp tau(T) crossover.', analysis.finalSummary.tau_min_s, analysis.finalSummary.tau_max_s);
L(end + 1) = sprintf('- The experimental observation endpoint is %.3f s, which remains above the chosen tau(T) at the Relaxation peak by a factor of %.3f.', analysis.timeWindow.t_experiment_s, analysis.timeWindow.t_experiment_s / max(analysis.finalSummary.tau_at_A_peak_s, eps));
if switching.available
    L(end + 1) = sprintf('- The Switching ridge-motion marker at %.1f K was compared explicitly in the alignment summary.', switching.motionPeakT_K);
end
L(end + 1) = '';
L(end + 1) = '## Beta(T) usability';
L(end + 1) = '- Saved current-state conclusion carried forward: beta(T) remains too unstable for strong new claims.';
L(end + 1) = '- Practical consequence in this analysis: beta(T) was inspected and reported, but the final tau observable fixed beta to the saved global current-workflow value rather than promoting a new local beta(T) narrative.';
L(end + 1) = '';
L(end + 1) = '## Uncertainties and robustness limits';
L(end + 1) = '- The saved Relaxation map is near rank-1, so any temperature-dependent time scale extracted from it is expected to vary only weakly unless one uses a noisier raw-curve basis.';
L(end + 1) = '- The empirical and fixed-beta time scales were computed on the saved map rather than on newly re-imported raw traces, because the task requested a safe run-scoped reuse-first workflow.';
L(end + 1) = '- The legacy raw-curve tau_kww summary remains incomplete above 31 K and carries high median CV, so it was not used as the final tau.';
L(end + 1) = '- The Switching ridge-motion peak is derived from saved I_peak(T) finite differences because the saved Switching characteristic-temperature table did not already export a direct |dI_peak/dT| maximum.';
L(end + 1) = '- A global Arrhenius claim is not made unless it clearly beats a flat-log-tau baseline; the present data do not justify forcing that interpretation.';
L(end + 1) = '';
L(end + 1) = '## Visualization choices';
L(end + 1) = '- number of curves: up to 4 curves in the main tau(T) panel, 2-3 curves per comparison panel, and 3 curves in the selected-fit examples';
L(end + 1) = '- legend vs colormap: legends for line plots because each panel stays at 6 or fewer curves; parula colorbar only in the tau-vs-A scatter and Arrhenius diagnostics';
L(end + 1) = '- colormap used: parula';
L(end + 1) = sprintf('- smoothing applied: %d-point moving mean on saved Switching I_peak(T) and S_peak(T) only before finite differences', cfg.switchingSmoothWindow);
L(end + 1) = '- justification: the figures are organized to separate tau extraction, experiment-window comparison, fit examples, and cross-experiment marker alignment';
reportText = strjoin(L, newline);
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

function [map, T, xGrid] = loadMapMatrix(mapPath)
raw = readmatrix(mapPath);
xGrid = raw(1, 2:end).';
T = raw(2:end, 1);
map = raw(2:end, 2:end);
validRows = isfinite(T); validCols = isfinite(xGrid);
T = T(validRows); xGrid = xGrid(validCols); map = map(validRows, validCols);
if any(~isfinite(map), 'all')
    map = fillMissingMap(map);
end
end

function map = fillMissingMap(map)
for r = 1:size(map, 1)
    row = map(r, :);
    if any(~isfinite(row))
        x = 1:numel(row); good = isfinite(row);
        row(~good) = interp1(x(good), row(good), x(~good), 'linear', 'extrap');
        map(r, :) = row;
    end
end
for c = 1:size(map, 2)
    col = map(:, c);
    if any(~isfinite(col))
        x = 1:numel(col); good = isfinite(col);
        col(~good) = interp1(x(good), col(good), x(~good), 'linear', 'extrap');
        map(:, c) = col;
    end
end
end

function fitTbl = fitFixedBetaTau(T, tGrid, map, betaRef, cfg)
rows = repmat(struct('T_K', NaN, 'Minf', NaN, 'dM', NaN, 'tau_s', NaN, 'R2', NaN, 'RMSE', NaN, 'SSE', NaN, 't_half_s', NaN, 'fit_ok', false, 'note', ""), numel(T), 1);
tRel = max(tGrid(:) - tGrid(1), 0);
for i = 1:numel(T)
    fit = fitFixedBetaTrace(tRel, map(i, :).', betaRef, cfg);
    rows(i).T_K = T(i); rows(i).Minf = fit.Minf; rows(i).dM = fit.dM; rows(i).tau_s = fit.tau_s; rows(i).R2 = fit.R2; rows(i).RMSE = fit.RMSE; rows(i).SSE = fit.SSE; rows(i).t_half_s = fit.t_half_s; rows(i).fit_ok = fit.fit_ok; rows(i).note = fit.note;
end
fitTbl = struct2table(rows);
end

function fit = fitFixedBetaTrace(tRel, y, betaRef, cfg)
fit = struct('Minf', NaN, 'dM', NaN, 'tau_s', NaN, 'R2', NaN, 'RMSE', NaN, 'SSE', NaN, 't_half_s', NaN, 'fit_ok', false, 'note', "");
mask = isfinite(tRel) & isfinite(y); tRel = tRel(mask); y = y(mask);
if numel(tRel) < 10
    fit.note = "too_few_points"; return;
end
tailMean = mean(y(max(1, end - cfg.tailCount + 1):end), 'omitnan');
headMean = mean(y(1:min(cfg.headCount, numel(y))), 'omitnan');
dM0 = headMean - tailMean;
tauSeeds = unique(max([median(tRel(tRel > 0), 'omitnan'); max(tRel) / 3; max(tRel) / 1.5; 300; 1000], 1e-3));
opts = optimset('Display', 'off', 'MaxIter', 4000, 'MaxFunEvals', 8000);
bestP = []; bestSSE = Inf;
for k = 1:numel(tauSeeds)
    p0 = [tailMean, dM0, log(tauSeeds(k))];
    obj = @(p) fixedBetaObjective(p, tRel, y, betaRef);
    try
        p = fminsearch(obj, p0, opts);
    catch
        continue;
    end
    sse = obj(p);
    if isfinite(sse) && sse < bestSSE
        bestP = p; bestSSE = sse;
    end
end
if isempty(bestP)
    fit.note = "fit_failed"; return;
end
Minf = bestP(1); dM = bestP(2); tau = exp(bestP(3)); tau = max(tau, eps);
yFit = evaluateFixedBeta(Minf, dM, tau, betaRef, tRel);
sse = sum((y - yFit) .^ 2, 'omitnan'); sst = sum((y - mean(y, 'omitnan')) .^ 2, 'omitnan'); rmse = sqrt(mean((y - yFit) .^ 2, 'omitnan')); r2 = 1 - sse / max(sst, eps);
fit.Minf = Minf; fit.dM = dM; fit.tau_s = tau; fit.R2 = r2; fit.RMSE = rmse; fit.SSE = sse; fit.t_half_s = tau * (log(2)) ^ (1 / betaRef); fit.fit_ok = isfinite(tau) && isfinite(r2) && isfinite(rmse); if abs(dM) < eps, fit.note = "low_signal"; else, fit.note = "ok"; end
end

function sse = fixedBetaObjective(p, tRel, y, betaRef)
Minf = p(1); dM = p(2); tau = exp(p(3));
if ~(isfinite(tau) && tau > 0)
    sse = Inf; return;
end
yFit = evaluateFixedBeta(Minf, dM, tau, betaRef, tRel); res = y - yFit; sse = sum(res .^ 2, 'omitnan'); if ~isfinite(sse), sse = Inf; end
end

function yFit = evaluateFixedBeta(Minf, dM, tau, betaRef, tRel)
z = max(tRel(:), 0) ./ max(tau, eps); yFit = Minf + dM .* exp(-(z .^ betaRef));
end

function empiricalTbl = computeEmpiricalTimes(T, tGrid, map, cfg)
rows = repmat(struct('T_K', NaN, 'amplitude', NaN, 't_half_s', NaN, 't_one_over_e_s', NaN, 'fit_ok', false), numel(T), 1);
for i = 1:numel(T)
    [tRel, yNorm, amp] = normalizeRelaxationTrace(tGrid, map(i, :), cfg.headCount, cfg.tailCount);
    rows(i).T_K = T(i); rows(i).amplitude = amp; rows(i).t_half_s = thresholdCrossingTime(tRel, yNorm, 0.5); rows(i).t_one_over_e_s = thresholdCrossingTime(tRel, yNorm, exp(-1)); rows(i).fit_ok = isfinite(rows(i).t_half_s);
end
empiricalTbl = struct2table(rows);
end

function [tRel, yNorm, amp] = normalizeRelaxationTrace(tGrid, y, headCount, tailCount)
t = tGrid(:); y = y(:); tRel = t - t(1); headMean = mean(y(1:min(headCount, numel(y))), 'omitnan'); tailMean = mean(y(max(1, numel(y) - tailCount + 1):end), 'omitnan'); amp = headMean - tailMean; if isfinite(amp) && abs(amp) > eps, yNorm = (y - tailMean) ./ amp; else, yNorm = NaN(size(y)); end
end

function tCross = thresholdCrossingTime(tRel, yNorm, level)
tCross = NaN; mask = isfinite(tRel) & isfinite(yNorm); tRel = tRel(mask); yNorm = yNorm(mask); if numel(tRel) < 2 || yNorm(1) < level, return; end
for i = 2:numel(tRel)
    if yNorm(i) <= level
        tCross = crossInterp(tRel(i - 1), tRel(i), yNorm(i - 1) - level, yNorm(i) - level);
        return;
    end
end
end

function fit = buildFreeBetaFit(relax, idx)
[tRel, ~, ~] = normalizeRelaxationTrace(relax.tGrid, relax.map(idx, :), 5, 12);
y = relax.map(idx, :).'; headMean = mean(y(1:min(5, numel(y))), 'omitnan'); tailMean = mean(y(max(1, numel(y) - 12 + 1):end), 'omitnan'); amp = headMean - tailMean; yFit = tailMean + amp .* exp(-((tRel ./ max(relax.temperatureTable.free_beta_tau_s(idx), eps)) .^ relax.temperatureTable.free_beta_beta(idx))); if abs(amp) > eps, fit = (yFit - tailMean) ./ amp; else, fit = NaN(size(yFit)); end
end

function fit = buildFixedBetaFit(relax, idx)
[tRel, ~, ~] = normalizeRelaxationTrace(relax.tGrid, relax.map(idx, :), 5, 12);
y = relax.map(idx, :).'; headMean = mean(y(1:min(5, numel(y))), 'omitnan'); tailMean = mean(y(max(1, numel(y) - 12 + 1):end), 'omitnan'); amp = headMean - tailMean; yFit = tailMean + amp .* exp(-((tRel ./ max(relax.temperatureTable.fixed_beta_tau_s(idx), eps)) .^ relax.globalBeta)); if abs(amp) > eps, fit = (yFit - tailMean) ./ amp; else, fit = NaN(size(yFit)); end
end

function law = fitConstantVsArrhenius(T, tau)
law = struct('preferredLaw', "constant_or_flat", 'constantAIC', NaN, 'arrheniusAIC', NaN, 'arrheniusR2', NaN, 'constantFitY', [], 'arrheniusFitY', []);
mask = isfinite(T) & isfinite(tau) & tau > 0; T = T(mask); tau = tau(mask); if numel(T) < 4, return; end
x = 1 ./ T; y = log(tau); n = numel(y); sst = sum((y - mean(y, 'omitnan')) .^ 2, 'omitnan'); yConst = mean(y, 'omitnan') + zeros(size(y)); sseConst = sum((y - yConst) .^ 2, 'omitnan'); aicConst = n * log(max(sseConst, eps) / n) + 2; p = polyfit(x, y, 1); yArr = polyval(p, x); sseArr = sum((y - yArr) .^ 2, 'omitnan'); aicArr = n * log(max(sseArr, eps) / n) + 4; r2Arr = 1 - sseArr / max(sst, eps);
law.constantAIC = aicConst; law.arrheniusAIC = aicArr; law.arrheniusR2 = r2Arr; law.constantFitY = yConst; law.arrheniusFitY = yArr; if aicArr + 2 < aicConst, law.preferredLaw = "Arrhenius"; end
end

function values = matchByTemperature(sourceT, sourceValues, targetT)
values = NaN(numel(targetT), 1); sourceT = sourceT(:); sourceValues = sourceValues(:); targetT = targetT(:);
for i = 1:numel(targetT)
    idx = find(abs(sourceT - targetT(i)) <= 1e-9, 1, 'first'); if ~isempty(idx), values(i) = sourceValues(idx); end
end
end

function values = matchByTemperatureString(sourceT, sourceValues, targetT)
values = repmat("", numel(targetT), 1); sourceT = sourceT(:); sourceValues = string(sourceValues(:)); targetT = targetT(:);
for i = 1:numel(targetT)
    idx = find(abs(sourceT - targetT(i)) <= 1e-9, 1, 'first'); if ~isempty(idx), values(i) = sourceValues(idx); end
end
end

function vals = getOrDefault(tbl, varName, defaultVals)
if ismember(varName, string(tbl.Properties.VariableNames)), vals = tbl.(varName); else, vals = defaultVals; end
end

function val = getScalarTableValue(tbl, varName, idx)
if ismember(varName, string(tbl.Properties.VariableNames)), val = tbl.(varName)(idx); else, val = NaN; end
end

function val = getValueForModel(tbl, modelName, varName)
idx = find(strcmpi(string(tbl.model), modelName), 1, 'first'); if isempty(idx) || ~ismember(varName, string(tbl.Properties.VariableNames)), val = NaN; else, val = tbl.(varName)(idx); end
end

function x = numericColumn(v)
if isnumeric(v)
    x = v;
elseif iscell(v)
    x = str2double(string(v));
else
    x = str2double(string(v));
end
x = x(:);
end

function data = getColumn(tbl, varName)
if ismember(varName, string(tbl.Properties.VariableNames)), data = tbl.(varName)(:); else, data = NaN(height(tbl), 1); end
end

function name = pickVariableName(varNames, preferred)
varNames = string(varNames(:));
preferred = string(preferred(:));
for i = 1:numel(preferred)
    idx = find(strcmpi(varNames, preferred(i)), 1, 'first');
    if ~isempty(idx)
        name = varNames(idx);
        return;
    end
end
for i = 1:numel(preferred)
    idx = find(contains(lower(varNames), lower(preferred(i))), 1, 'first');
    if ~isempty(idx)
        name = varNames(idx);
        return;
    end
end
error('Could not resolve expected variable name.');
end

function y = normalizePositive(x)
x = x(:); y = NaN(size(x)); mx = max(x, [], 'omitnan'); if isfinite(mx) && mx > 0, y = x ./ mx; end
end

function r = corrSafe(x, y)
x = x(:); y = y(:); mask = isfinite(x) & isfinite(y); r = NaN; if nnz(mask) < 3, return; end; c = corrcoef(x(mask), y(mask)); if numel(c) >= 4, r = c(1, 2); end
end

function [low, high, width, peakT] = computeHalfMaxWindow(T, y)
low = NaN; high = NaN; width = NaN; peakT = NaN; mask = isfinite(T) & isfinite(y); T = T(mask); y = y(mask); if numel(T) < 3, return; end
[peakVal, idxPeak] = max(y); if ~(isfinite(peakVal) && peakVal > 0), return; end; peakT = T(idxPeak); halfVal = 0.5 * peakVal; leftIdx = find(y(1:idxPeak) <= halfVal, 1, 'last');
if isempty(leftIdx), low = T(1); elseif leftIdx == idxPeak, low = T(idxPeak); else, low = crossInterp(T(leftIdx), T(leftIdx + 1), y(leftIdx) - halfVal, y(leftIdx + 1) - halfVal); end
rightRel = find(y(idxPeak:end) <= halfVal, 1, 'first');
if isempty(rightRel), high = T(end); else, rightIdx = idxPeak + rightRel - 1; if rightIdx == idxPeak, high = T(idxPeak); else, high = crossInterp(T(rightIdx - 1), T(rightIdx), y(rightIdx - 1) - halfVal, y(rightIdx) - halfVal); end, end
width = high - low; if ~(isfinite(width) && width >= 0), width = NaN; end
end

function tf = pointInWindow(x, low, high)
tf = all(isfinite([x, low, high])) && x >= low && x <= high;
end

function t = zeroCross(T, y)
t = NaN; mask = isfinite(T) & isfinite(y); T = T(mask); y = y(mask); for i = 1:(numel(T) - 1), if y(i) == 0, t = T(i); return; end, if y(i) * y(i + 1) < 0, t = crossInterp(T(i), T(i + 1), y(i), y(i + 1)); return; end, end
end

function x0 = crossInterp(x1, x2, y1, y2)
if ~all(isfinite([x1, x2, y1, y2])), x0 = NaN; return; end
if abs(y2 - y1) < eps, x0 = mean([x1, x2]); else, x0 = x1 - y1 * (x2 - x1) / (y2 - y1); end
end

function yq = interp1Safe(x, y, xq)
yq = NaN; mask = isfinite(x) & isfinite(y); if nnz(mask) < 2 || ~isfinite(xq), return; end; yq = interp1(x(mask), y(mask), xq, 'pchip', NaN);
end

function temps = nearestAvailableTemperatures(Tavailable, targets)
temps = NaN(size(targets)); for i = 1:numel(targets), [~, idx] = min(abs(Tavailable - targets(i))); temps(i) = Tavailable(idx); end
end

function setFigureGeometry(fig, widthCm, heightCm)
set(fig, 'Units', 'centimeters', 'Position', [2 2 widthCm heightCm], 'PaperUnits', 'centimeters', 'PaperPosition', [0 0 widthCm heightCm], 'PaperSize', [widthCm heightCm], 'Color', 'w');
end

function setAxisStyle(ax)
set(ax, 'FontName', 'Helvetica', 'FontSize', 9, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
end

function addPanelLabel(ax, label)
text(ax, -0.12, 1.05, label, 'Units', 'normalized', 'FontWeight', 'bold', 'FontSize', 11);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a'); if fid < 0, return; end; cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, field, value)
if ~isfield(cfg, field) || isempty(cfg.(field)), cfg.(field) = value; end
end





