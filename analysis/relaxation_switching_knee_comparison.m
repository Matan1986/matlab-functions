function out = relaxation_switching_knee_comparison(cfg)
% relaxation_switching_knee_comparison
% Cross-experiment diagnostic comparing relaxation windowing to switching current-knee structure.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | switch:%s', char(source.relaxRunName), char(source.switchRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = getRunOutputDir();
fprintf('Relaxation-switching knee comparison run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Switching source run: %s\n', source.switchRunName);
if strlength(source.mechRunName) > 0
    fprintf('Switching mechanism follow-up source run: %s\n', source.mechRunName);
end

relax = loadRelaxationWindow(source.relaxRunDir);
switching = loadSwitchingData(source.switchRunDir, source.mechMetricsPath, cfg);
transition = computeSwitchingTransitionMetrics(switching, cfg);
summaryTbl = buildSwitchingSummaryTable(transition, relax);
comparisonTbl = buildComparisonTable(relax, transition, summaryTbl);
primaryMetric = selectPrimaryMetric(comparisonTbl);
summaryTbl.primary_metric = summaryTbl.metric_name == primaryMetric;
comparisonTbl.primary_metric = comparisonTbl.metric_name == primaryMetric;

relaxTbl = buildRelaxationWindowTable(relax);
transitionTbl = transition.metricTable;

relaxPath = save_run_table(relaxTbl, 'relaxation_window_metrics.csv', runDir);
transitionPath = save_run_table(transitionTbl, 'switching_transition_metrics_vs_T.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'switching_transition_summary.csv', runDir);
comparisonPath = save_run_table(comparisonTbl, 'relaxation_switching_comparison.csv', runDir);

mapFig = saveSwitchingMapFigure(switching, transition, runDir, 'switching_map');
cutsFig = saveCurrentCutsFigure(switching, transition, relax, runDir, 'switching_current_cuts');
derivFig = saveDerivativeCutsFigure(switching, transition, relax, runDir, 'switching_dIdI_cuts');
transFig = saveTransitionVsTFigure(transition, runDir, 'switching_transition_vs_T');
compareFig = saveRelaxationComparisonFigure(relax, transition, primaryMetric, runDir, 'relaxation_vs_switching_window');
summaryFig = saveSummaryFigure(relax, transition, summaryTbl, comparisonTbl, primaryMetric, runDir, 'relaxation_switching_summary');

reportText = buildReport(source, relax, switching, transition, summaryTbl, comparisonTbl, primaryMetric, cfg);
reportPath = save_run_report(reportText, 'relaxation_switching_knee_comparison_report.md', runDir);
zipPath = buildReviewZip(runDir);

appendText(run.log_path, sprintf('[%s] relaxation-switching knee comparison complete\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Primary switching metric: %s\n', char(primaryMetric)));
appendText(run.log_path, sprintf('Relaxation table: %s\n', relaxPath));
appendText(run.log_path, sprintf('Switching transition table: %s\n', transitionPath));
appendText(run.log_path, sprintf('Comparison table: %s\n', comparisonPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

bestRow = comparisonTbl(comparisonTbl.metric_name == primaryMetric, :);
appendText(run.notes_path, sprintf('Relax_T_peak = %.6g K\n', relax.Relax_T_peak));
appendText(run.notes_path, sprintf('Relax_peak_width = %.6g K\n', relax.Relax_peak_width));
appendText(run.notes_path, sprintf('Primary switching metric = %s\n', char(primaryMetric)));
appendText(run.notes_path, sprintf('T_knee_peak = %.6g K\n', bestRow.T_knee_peak(1)));
appendText(run.notes_path, sprintf('T_transition_window_width = %.6g K\n', bestRow.T_transition_window_width(1)));
appendText(run.notes_path, sprintf('corr(metric, A) = %.6g\n', bestRow.corr_with_A(1)));
appendText(run.notes_path, sprintf('corr(metric, R) = %.6g\n', bestRow.corr_with_R(1)));
appendText(run.notes_path, sprintf('peak_position_difference_K = %.6g\n', bestRow.peak_position_difference_K(1)));
appendText(run.notes_path, sprintf('width_difference_K = %.6g\n', bestRow.width_difference_K(1)));
appendText(run.notes_path, sprintf('hypothesis_verdict = %s\n', char(bestRow.hypothesis_verdict(1))));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.relax = relax;
out.switching = switching;
out.transition = transition;
out.summaryTable = summaryTbl;
out.comparisonTable = comparisonTbl;
out.primaryMetric = string(primaryMetric);
out.tables = struct('relaxation', string(relaxPath), 'transition', string(transitionPath), 'summary', string(summaryPath), 'comparison', string(comparisonPath));
out.figures = struct('switching_map', string(mapFig.png), 'switching_current_cuts', string(cutsFig.png), 'switching_dIdI_cuts', string(derivFig.png), 'switching_transition_vs_T', string(transFig.png), 'relaxation_vs_switching_window', string(compareFig.png), 'relaxation_switching_summary', string(summaryFig.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Relaxation-switching knee comparison complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Primary switching metric: %s\n', primaryMetric);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'relaxation_switching_knee_comparison');
cfg = setDefaultField(cfg, 'currentSmoothWindow', 3);
cfg = setDefaultField(cfg, 'comparisonGridPoints', 400);
cfg = setDefaultField(cfg, 'maxRepresentativeCuts', 6);
end

function source = resolveSourceRuns(repoRoot)
source = struct();
[source.relaxRunDir, source.relaxRunName] = findLatestRunWithFiles(repoRoot, 'relaxation', {'tables\temperature_observables.csv', 'tables\observables_relaxation.csv'}, "relaxation_observable_stability_audit");
[source.switchRunDir, source.switchRunName] = findLatestRunWithFiles(repoRoot, 'switching', {'switching_alignment_core_data.mat', 'observables.csv', 'observable_matrix.csv'}, "alignment_audit");
[source.mechRunDir, source.mechRunName] = findLatestRunWithFilesOptional(repoRoot, 'switching', {'mechanism_followup\mechanism_ridge_shape_metrics.csv'}, "mechanism_followup");
source.relaxTempPath = string(fullfile(source.relaxRunDir, 'tables', 'temperature_observables.csv'));
source.relaxObsPath = string(fullfile(source.relaxRunDir, 'tables', 'observables_relaxation.csv'));
source.switchObsPath = string(fullfile(source.switchRunDir, 'observables.csv'));
source.switchMatrixPath = string(fullfile(source.switchRunDir, 'observable_matrix.csv'));
source.switchCoreDataPath = string(fullfile(source.switchRunDir, 'switching_alignment_core_data.mat'));
if strlength(source.mechRunDir) > 0
    source.mechMetricsPath = string(fullfile(source.mechRunDir, 'mechanism_followup', 'mechanism_ridge_shape_metrics.csv'));
else
    source.mechMetricsPath = "";
end
end

function [runDir, runName] = findLatestRunWithFiles(repoRoot, experiment, requiredFiles, labelHint)
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('No run directories found under %s', runsRoot);
end
names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);
for i = numel(runDirs):-1:1
    candidateName = string(runDirs(i).name);
    if strlength(labelHint) > 0 && ~contains(candidateName, labelHint)
        continue;
    end
    candidateDir = fullfile(runDirs(i).folder, runDirs(i).name);
    ok = true;
    for k = 1:numel(requiredFiles)
        if exist(fullfile(candidateDir, requiredFiles{k}), 'file') ~= 2
            ok = false;
            break;
        end
    end
    if ok
        runDir = string(candidateDir);
        runName = candidateName;
        return;
    end
end
error('No %s run matched the requested files and label hint %s.', experiment, labelHint);
end

function [runDir, runName] = findLatestRunWithFilesOptional(repoRoot, experiment, requiredFiles, labelHint)
runDir = "";
runName = "";
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
if exist(runsRoot, 'dir') ~= 7
    return;
end
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    return;
end
names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);
for i = numel(runDirs):-1:1
    candidateName = string(runDirs(i).name);
    if strlength(labelHint) > 0 && ~contains(candidateName, labelHint)
        continue;
    end
    candidateDir = fullfile(runDirs(i).folder, runDirs(i).name);
    ok = true;
    for k = 1:numel(requiredFiles)
        if exist(fullfile(candidateDir, requiredFiles{k}), 'file') ~= 2
            ok = false;
            break;
        end
    end
    if ok
        runDir = string(candidateDir);
        runName = candidateName;
        return;
    end
end
end

function relax = loadRelaxationWindow(relaxRunDir)
obsTbl = readtable(fullfile(relaxRunDir, 'tables', 'observables_relaxation.csv'));
tempTbl = readtable(fullfile(relaxRunDir, 'tables', 'temperature_observables.csv'));

relax = struct();
relax.T = tempTbl.T(:);
relax.A = tempTbl.A_T(:);
relax.R = tempTbl.R_T(:);
relax.betaT = tempTbl.Relax_beta_T(:);
relax.tauT = tempTbl.Relax_tau_T(:);
relax.Relax_Amp_peak = obsTbl.Relax_Amp_peak(1);
relax.Relax_T_peak = obsTbl.Relax_T_peak(1);
relax.Relax_peak_width = obsTbl.Relax_peak_width(1);
relax.Relax_mode2_strength = obsTbl.Relax_mode2_strength(1);
relax.Relax_rank1_residual_fraction = obsTbl.Relax_rank1_residual_fraction(1);
relax.Relax_beta_global = obsTbl.Relax_beta_global(1);
relax.Relax_tau_global = obsTbl.Relax_tau_global(1);
relax.Relax_t_half = obsTbl.Relax_t_half(1);
[relax.windowLow, relax.windowHigh, relax.windowWidth] = computeHalfMaxWindow(relax.T, relax.A);
if ~isfinite(relax.windowWidth)
    relax.windowWidth = relax.Relax_peak_width;
    relax.windowLow = relax.Relax_T_peak - 0.5 * relax.Relax_peak_width;
    relax.windowHigh = relax.Relax_T_peak + 0.5 * relax.Relax_peak_width;
end
relax.A_norm = normalizeToMax(relax.A);
relax.R_norm = normalizeToMax(relax.R);
end

function switching = loadSwitchingData(switchRunDir, mechMetricsPath, cfg)
core = load(fullfile(switchRunDir, 'switching_alignment_core_data.mat'));
obsWide = readtable(fullfile(switchRunDir, 'observable_matrix.csv'));
obsLong = readtable(fullfile(switchRunDir, 'observables.csv'));

switching = struct();
switching.temps = core.temps(:);
switching.currents = core.currents(:);
switching.Smap = core.Smap;
switching.rawTbl = core.rawTbl;
switching.metricType = string(core.metricType);
switching.channelMode = string(core.channelMode);
switching.parentDir = string(core.parentDir);
switching.observableMatrix = obsWide;
switching.observablesLong = obsLong;
switching.smoothingDescription = sprintf('movmean window = %d current points before current-axis derivatives', cfg.currentSmoothWindow);

switching.obsByT = table(obsWide.T(:), obsWide.S_peak(:), obsWide.I_peak(:), obsWide.width_I(:), obsWide.halfwidth_diff_norm(:), obsWide.asym(:), ...
    'VariableNames', {'T','S_peak_exported','Ipeak_exported','width_I_exported','halfwidth_diff_norm_exported','asym_exported'});

switching.curvatureTbl = table();
if strlength(mechMetricsPath) > 0 && exist(char(mechMetricsPath), 'file') == 2
    switching.curvatureTbl = readtable(char(mechMetricsPath));
end
end
function transition = computeSwitchingTransitionMetrics(switching, cfg)
T = switching.temps(:);
I = switching.currents(:);
Smap = switching.Smap;

nT = numel(T);
nI = numel(I);
Ssmooth = NaN(size(Smap));
dS_dI = NaN(size(Smap));
d2S_dI2 = NaN(size(Smap));
I_knee = NaN(nT,1);
max_slope = NaN(nT,1);
transition_width_I = NaN(nT,1);
knee_prominence = NaN(nT,1);
curvature_metric = NaN(nT,1);
I_peak = NaN(nT,1);
S_peak = NaN(nT,1);

for it = 1:nT
    row = Smap(it,:);
    valid = isfinite(row) & isfinite(I.');
    if nnz(valid) < 3
        continue;
    end
    iValid = I(valid);
    sValid = row(valid);
    if cfg.currentSmoothWindow >= 3 && nnz(valid) >= cfg.currentSmoothWindow
        sSmooth = smoothdata(sValid, 'movmean', cfg.currentSmoothWindow);
    else
        sSmooth = sValid;
    end

    rowSmooth = NaN(1, nI);
    rowSmooth(valid) = sSmooth;
    Ssmooth(it,:) = rowSmooth;

    d1 = gradient(sSmooth, iValid);
    d2 = gradient(d1, iValid);
    rowD1 = NaN(1, nI);
    rowD2 = NaN(1, nI);
    rowD1(valid) = d1;
    rowD2(valid) = d2;
    dS_dI(it,:) = rowD1;
    d2S_dI2(it,:) = rowD2;

    [sMax, idxPeak] = max(sSmooth);
    I_peak(it) = iValid(idxPeak);
    S_peak(it) = sMax;

    [slopeMax, idxKnee] = max(d1);
    if isfinite(slopeMax) && slopeMax > 0
        max_slope(it) = slopeMax;
        I_knee(it) = iValid(idxKnee);
        knee_prominence(it) = trapz(iValid, max(d1, 0));
        curvature_metric(it) = abs(d2(idxKnee));
        halfMask = d1 >= 0.5 * slopeMax;
        if nnz(halfMask) >= 2
            transition_width_I(it) = max(iValid(halfMask)) - min(iValid(halfMask));
        end
    end
end

dI_knee_dT = NaN(nT,1);
validShift = isfinite(I_knee) & isfinite(T);
if nnz(validShift) >= 2
    dtmp = gradient(I_knee(validShift), T(validShift));
    dI_knee_dT(validShift) = dtmp;
end
shift_activity = abs(dI_knee_dT);

exported = alignExportedObservables(T, switching.obsByT);
curvImport = alignImportedCurvature(T, switching.curvatureTbl);
useImportedCurv = isfinite(curvImport);
curvature_metric(useImportedCurv) = abs(curvImport(useImportedCurv));

metricTable = table(T, I_peak, S_peak, I_knee, max_slope, transition_width_I, knee_prominence, curvature_metric, shift_activity, dI_knee_dT, ...
    exported.Ipeak_exported, exported.width_I_exported, exported.halfwidth_diff_norm_exported, exported.asym_exported, exported.S_peak_exported, ...
    'VariableNames', {'T','I_peak','S_peak','I_knee','max_slope','transition_width_I','knee_prominence','curvature_metric','shift_activity','dI_knee_dT', ...
    'Ipeak_exported','width_I_exported','halfwidth_diff_norm_exported','asym_exported','S_peak_exported'});

metricList = { ...
    struct('name', "max_slope", 'values', max_slope, 'units', "signal_per_mA", 'description', "Maximum positive current-axis derivative max(dS/dI) after minimal smoothing"), ...
    struct('name', "knee_prominence", 'values', knee_prominence, 'units', "signal", 'description', "Positive derivative area integral trapz(max(dS/dI,0))"), ...
    struct('name', "shift_activity", 'values', shift_activity, 'units', "mA_per_K", 'description', "Absolute temperature derivative of knee current |dI_knee/dT|"), ...
    struct('name', "curvature_metric", 'values', curvature_metric, 'units', "signal_per_mA2", 'description', "Absolute second current derivative at the detected knee" )};

transition = struct();
transition.T = T;
transition.I = I;
transition.Smap = Smap;
transition.Ssmooth = Ssmooth;
transition.dS_dI = dS_dI;
transition.d2S_dI2 = d2S_dI2;
transition.metricTable = metricTable;
transition.metricList = metricList;
end

function exported = alignExportedObservables(T, obsByT)
exported = struct('Ipeak_exported', NaN(size(T)), 'width_I_exported', NaN(size(T)), 'halfwidth_diff_norm_exported', NaN(size(T)), 'asym_exported', NaN(size(T)), 'S_peak_exported', NaN(size(T)));
if isempty(obsByT)
    return;
end
[~, iT, iO] = intersect(T, obsByT.T, 'stable');
exported.Ipeak_exported(iT) = obsByT.Ipeak_exported(iO);
exported.width_I_exported(iT) = obsByT.width_I_exported(iO);
exported.halfwidth_diff_norm_exported(iT) = obsByT.halfwidth_diff_norm_exported(iO);
exported.asym_exported(iT) = obsByT.asym_exported(iO);
exported.S_peak_exported(iT) = obsByT.S_peak_exported(iO);
end

function curvature = alignImportedCurvature(T, curvatureTbl)
curvature = NaN(size(T));
if isempty(curvatureTbl)
    return;
end
if ~ismember('T_K', string(curvatureTbl.Properties.VariableNames)) || ~ismember('curvature_near_peak', string(curvatureTbl.Properties.VariableNames))
    return;
end
[~, iT, iC] = intersect(T, curvatureTbl.T_K, 'stable');
curvature(iT) = curvatureTbl.curvature_near_peak(iC);
end

function tbl = buildRelaxationWindowTable(relax)
tbl = table(relax.Relax_Amp_peak, relax.Relax_T_peak, relax.Relax_peak_width, relax.windowLow, relax.windowHigh, ...
    max(relax.R), corrSafe(relax.A, relax.R), ...
    'VariableNames', {'Relax_Amp_peak','Relax_T_peak','Relax_peak_width','Relax_window_T_low','Relax_window_T_high','Relax_R_peak','Relax_A_R_correlation'});
end

function summaryTbl = buildSwitchingSummaryTable(transition, relax)
rows = repmat(struct('metric_name', "", 'metric_units', "", 'metric_description', "", 'T_knee_peak', NaN, 'T_transition_window_width', NaN, 'T_window_low', NaN, 'T_window_high', NaN), numel(transition.metricList), 1);
for i = 1:numel(transition.metricList)
    metric = transition.metricList{i};
    [tLow, tHigh, tWidth, tPeak] = computeHalfMaxWindow(transition.T, metric.values);
    rows(i).metric_name = metric.name;
    rows(i).metric_units = metric.units;
    rows(i).metric_description = metric.description;
    rows(i).T_knee_peak = tPeak;
    rows(i).T_transition_window_width = tWidth;
    rows(i).T_window_low = tLow;
    rows(i).T_window_high = tHigh;
end
summaryTbl = struct2table(rows);
summaryTbl.Relax_T_peak = repmat(relax.Relax_T_peak, height(summaryTbl), 1);
summaryTbl.Relax_peak_width = repmat(relax.Relax_peak_width, height(summaryTbl), 1);
end

function comparisonTbl = buildComparisonTable(relax, transition, summaryTbl)
rows = repmat(struct('metric_name', "", 'corr_with_A', NaN, 'corr_with_R', NaN, 'scale_A_to_metric', NaN, 'scale_R_to_metric', NaN, 'overlap_with_A', NaN, 'overlap_with_R', NaN, 'T_knee_peak', NaN, 'T_transition_window_width', NaN, 'peak_position_difference_K', NaN, 'width_difference_K', NaN, 'hypothesis_verdict', ""), numel(transition.metricList), 1);
for i = 1:numel(transition.metricList)
    metric = transition.metricList{i};
    cmpA = compareCurves(relax.T, relax.A, transition.T, metric.values);
    cmpR = compareCurves(relax.T, relax.R, transition.T, metric.values);
    rows(i).metric_name = metric.name;
    rows(i).corr_with_A = cmpA.correlation;
    rows(i).corr_with_R = cmpR.correlation;
    rows(i).scale_A_to_metric = cmpA.scaleFactor;
    rows(i).scale_R_to_metric = cmpR.scaleFactor;
    rows(i).overlap_with_A = cmpA.overlap;
    rows(i).overlap_with_R = cmpR.overlap;
    rows(i).T_knee_peak = summaryTbl.T_knee_peak(i);
    rows(i).T_transition_window_width = summaryTbl.T_transition_window_width(i);
    rows(i).peak_position_difference_K = summaryTbl.T_knee_peak(i) - relax.Relax_T_peak;
    rows(i).width_difference_K = summaryTbl.T_transition_window_width(i) - relax.Relax_peak_width;
    rows(i).hypothesis_verdict = classifyHypothesis(cmpA.correlation, cmpA.overlap, rows(i).peak_position_difference_K, rows(i).width_difference_K);
end
comparisonTbl = struct2table(rows);
end

function metricName = selectPrimaryMetric(comparisonTbl)
valid = isfinite(comparisonTbl.overlap_with_A);
if ~any(valid)
    metricName = comparisonTbl.metric_name(1);
    return;
end
score = -inf(height(comparisonTbl),1);
score(valid) = comparisonTbl.overlap_with_A(valid) + 0.25 * max(comparisonTbl.corr_with_A(valid), 0) - 0.01 * abs(comparisonTbl.peak_position_difference_K(valid));
[~, idx] = max(score);
metricName = comparisonTbl.metric_name(idx);
end

function cmp = compareCurves(Ta, Ya, Tb, Yb)
Ta = Ta(:); Ya = Ya(:); Tb = Tb(:); Yb = Yb(:);
oka = isfinite(Ta) & isfinite(Ya);
okb = isfinite(Tb) & isfinite(Yb);
Ta = Ta(oka); Ya = Ya(oka);
Tb = Tb(okb); Yb = Yb(okb);
lo = max(min(Ta), min(Tb));
hi = min(max(Ta), max(Tb));
cmp = struct('correlation', NaN, 'scaleFactor', NaN, 'overlap', NaN, 'Tgrid', [], 'curveA', [], 'curveB', []);
if ~(isfinite(lo) && isfinite(hi) && hi > lo)
    return;
end
Tgrid = linspace(lo, hi, 400).';
curveA = interp1(Ta, Ya, Tgrid, 'pchip', NaN);
curveB = interp1(Tb, Yb, Tgrid, 'pchip', NaN);
ok = isfinite(curveA) & isfinite(curveB);
if nnz(ok) < 4
    return;
end
curveA = curveA(ok);
curveB = curveB(ok);
Tgrid = Tgrid(ok);
cmp.correlation = corrSafe(curveA, curveB);
cmp.scaleFactor = (curveA' * curveB) / max(curveA' * curveA, eps);
fa = normalizeToArea(max(curveA, 0), Tgrid);
fb = normalizeToArea(max(curveB, 0), Tgrid);
if all(isfinite(fa)) && all(isfinite(fb))
    cmp.overlap = trapz(Tgrid, min(fa, fb));
end
cmp.Tgrid = Tgrid;
cmp.curveA = curveA;
cmp.curveB = curveB;
end
function figPaths = saveSwitchingMapFigure(switching, transition, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 650]);
imagesc(switching.currents, switching.temps, switching.Smap);
axis xy;
colormap(parula);
cb = colorbar;
cb.Label.String = 'Switching signal S(T,I)';
hold on;
plot(transition.metricTable.I_knee, transition.metricTable.T, 'w--o', 'LineWidth', 2, 'MarkerSize', 4, 'DisplayName', 'I_{knee}');
plot(transition.metricTable.I_peak, transition.metricTable.T, 'k-o', 'LineWidth', 2, 'MarkerSize', 4, 'DisplayName', 'I_{peak}');
hold off;
xlabel('Current I (mA)', 'FontSize', 14);
ylabel('Temperature T (K)', 'FontSize', 14);
title('Switching map S(T,I) with knee and peak currents', 'FontSize', 16);
legend('Location', 'southwest');
set(gca, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveCurrentCutsFigure(switching, transition, relax, runDir, figureName)
idx = chooseRepresentativeTemperatures(switching.temps, relax, 6);
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 620]);
ax = axes(fh); hold(ax, 'on');
colors = lines(numel(idx));
for k = 1:numel(idx)
    plot(ax, switching.currents, transition.Ssmooth(idx(k),:), '-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'Color', colors(k,:), 'DisplayName', sprintf('T = %.1f K', switching.temps(idx(k))));
end
xlabel(ax, 'Current I (mA)', 'FontSize', 14);
ylabel(ax, 'S(I|T)', 'FontSize', 14);
title(ax, 'Representative switching current cuts', 'FontSize', 16);
grid(ax, 'on');
legend(ax, 'Location', 'eastoutside');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveDerivativeCutsFigure(switching, transition, relax, runDir, figureName)
idx = chooseRepresentativeTemperatures(switching.temps, relax, 6);
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 620]);
ax = axes(fh); hold(ax, 'on');
colors = lines(numel(idx));
for k = 1:numel(idx)
    plot(ax, switching.currents, transition.dS_dI(idx(k),:), '-o', 'LineWidth', 2.0, 'MarkerSize', 5, 'Color', colors(k,:), 'DisplayName', sprintf('T = %.1f K', switching.temps(idx(k))));
end
xlabel(ax, 'Current I (mA)', 'FontSize', 14);
ylabel(ax, 'dS/dI (signal / mA)', 'FontSize', 14);
title(ax, 'Current-axis derivatives for representative temperatures', 'FontSize', 16);
grid(ax, 'on');
legend(ax, 'Location', 'eastoutside');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveTransitionVsTFigure(transition, runDir, figureName)
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 760]);
tl = tiledlayout(fh, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
vars = {'max_slope', 'I_knee', 'transition_width_I', 'knee_prominence'};
ylabels = {'max slope (signal / mA)', 'I_{knee} (mA)', 'transition width (mA)', 'knee prominence (signal)'};
titles = {'Maximum current slope', 'Knee current', 'Transition width', 'Knee prominence'};
for i = 1:4
    ax = nexttile(tl, i);
    plot(ax, transition.metricTable.T, transition.metricTable.(vars{i}), '-o', 'LineWidth', 2.0, 'MarkerSize', 5);
    grid(ax, 'on');
    xlabel(ax, 'Temperature T (K)', 'FontSize', 14);
    ylabel(ax, ylabels{i}, 'FontSize', 14);
    title(ax, titles{i}, 'FontSize', 16);
    set(ax, 'FontSize', 14, 'LineWidth', 1.2);
end
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveRelaxationComparisonFigure(relax, transition, primaryMetric, runDir, figureName)
metric = getMetricByName(transition.metricList, primaryMetric);
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 950 620]);
ax = axes(fh); hold(ax, 'on');
plot(ax, relax.T, normalizeToMax(relax.A), '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'A(T) / max');
plot(ax, relax.T, normalizeToMax(max(relax.R, 0)), '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'R(T) / max');
plot(ax, transition.T, normalizeToMax(metric.values), '-^', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', sprintf('%s / max', strrep(primaryMetric, '_', '\_')));
hold off;
grid(ax, 'on');
xlabel(ax, 'Temperature T (K)', 'FontSize', 14);
ylabel(ax, 'Normalized window coordinate', 'FontSize', 14);
title(ax, sprintf('Relaxation vs Switching window coordinate: %s', strrep(primaryMetric, '_', '\_')), 'FontSize', 16, 'Interpreter', 'tex');
legend(ax, 'Location', 'best');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function figPaths = saveSummaryFigure(relax, transition, summaryTbl, comparisonTbl, primaryMetric, runDir, figureName)
metric = getMetricByName(transition.metricList, primaryMetric);
rowSummary = summaryTbl(summaryTbl.metric_name == primaryMetric, :);
rowCompare = comparisonTbl(comparisonTbl.metric_name == primaryMetric, :);

fh = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 760]);
tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1); hold(ax1, 'on');
patch(ax1, [relax.windowLow relax.windowHigh relax.windowHigh relax.windowLow], [0 0 1.05 1.05], [0.75 0.85 1.00], 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'DisplayName', 'Relaxation window');
patch(ax1, [rowSummary.T_window_low rowSummary.T_window_high rowSummary.T_window_high rowSummary.T_window_low], [0 0 1.05 1.05], [1.00 0.85 0.75], 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'DisplayName', 'Switching window');
plot(ax1, relax.T, normalizeToMax(relax.A), '-o', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'A(T) / max');
plot(ax1, relax.T, normalizeToMax(max(relax.R, 0)), '-s', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', 'R(T) / max');
plot(ax1, transition.T, normalizeToMax(metric.values), '-^', 'LineWidth', 2.2, 'MarkerSize', 5, 'DisplayName', sprintf('%s / max', strrep(primaryMetric, '_', '\_')));
hold(ax1, 'off');
grid(ax1, 'on');
ylim(ax1, [0 1.05]);
xlabel(ax1, 'Temperature T (K)', 'FontSize', 14);
ylabel(ax1, 'Normalized strength', 'FontSize', 14);
title(ax1, 'Window overlap summary', 'FontSize', 16);
legend(ax1, 'Location', 'eastoutside');
set(ax1, 'FontSize', 14, 'LineWidth', 1.2);

ax2 = nexttile(tl, 2);
y = [1 2];
plot(ax2, [relax.windowLow relax.windowHigh], [y(1) y(1)], '-', 'LineWidth', 8, 'Color', [0.2 0.45 0.85]);
hold(ax2, 'on');
plot(ax2, [rowSummary.T_window_low rowSummary.T_window_high], [y(2) y(2)], '-', 'LineWidth', 8, 'Color', [0.85 0.45 0.2]);
plot(ax2, relax.Relax_T_peak, y(1), 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8);
plot(ax2, rowSummary.T_knee_peak, y(2), 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8);
text(ax2, rowSummary.T_window_high + 0.5, y(1), sprintf('Relax: peak %.1f K, width %.1f K', relax.Relax_T_peak, relax.Relax_peak_width), 'VerticalAlignment', 'middle', 'FontSize', 12);
text(ax2, rowSummary.T_window_high + 0.5, y(2), sprintf('Switch: peak %.1f K, width %.1f K', rowSummary.T_knee_peak, rowSummary.T_transition_window_width), 'VerticalAlignment', 'middle', 'FontSize', 12);
text(ax2, min([relax.windowLow, rowSummary.T_window_low]), 0.4, sprintf('corr(metric,A)=%.3f | overlap=%.3f | peak diff=%.2f K | width diff=%.2f K', rowCompare.corr_with_A, rowCompare.overlap_with_A, rowCompare.peak_position_difference_K, rowCompare.width_difference_K), 'FontSize', 12);
hold(ax2, 'off');
set(ax2, 'YTick', y, 'YTickLabel', {'Relaxation','Switching'}, 'FontSize', 14, 'LineWidth', 1.2);
xlabel(ax2, 'Temperature T (K)', 'FontSize', 14);
ylim(ax2, [0.2 2.5]);
grid(ax2, 'on');
title(ax2, sprintf('Peak and FWHM comparison using %s', strrep(primaryMetric, '_', '\_')), 'FontSize', 16, 'Interpreter', 'tex');

figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function reportText = buildReport(source, relax, switching, transition, summaryTbl, comparisonTbl, primaryMetric, cfg)
row = comparisonTbl(comparisonTbl.metric_name == primaryMetric, :);
summaryRow = summaryTbl(summaryTbl.metric_name == primaryMetric, :);

lines = {};
lines{end+1,1} = '# Relaxation-Switching Knee Comparison Report';
lines{end+1,1} = '';
lines{end+1,1} = '## Repository / function discovery summary';
lines{end+1,1} = sprintf('- Latest relaxation audit reused: `%s`', char(source.relaxRunName));
lines{end+1,1} = sprintf('- Latest switching alignment run reused: `%s`', char(source.switchRunName));
if strlength(source.mechRunName) > 0
    lines{end+1,1} = sprintf('- Latest switching mechanism-followup run reused: `%s`', char(source.mechRunName));
end
lines{end+1,1} = '- Inspected files: `Switching/analysis/switching_alignment_audit.m`, `Switching/analysis/switching_mechanism_followup.m`, `Switching/analysis/switching_second_structural_observable_search.m`, the relaxation stability-audit report, and the latest run-scoped CSV/MAT exports.';
lines{end+1,1} = '- Reused switching observables/helpers: `Ipeak`, `width_I`, `halfwidth_diff_norm`, `asym`, the alignment-audit core-data MAT (`temps`, `currents`, `Smap`), and mechanism-followup `curvature_near_peak` when available.';
lines{end+1,1} = '- New code required: one cross-experiment diagnostic only. No switching or relaxation production pipeline code was modified.';
lines{end+1,1} = '';

lines{end+1,1} = '## Definitions of the comparison metrics';
lines{end+1,1} = sprintf('- Current-axis smoothing before derivatives: %s.', switching.smoothingDescription);
lines{end+1,1} = '- `max_slope(T)`: maximum positive current-axis derivative `max(dS/dI)` for each temperature.';
lines{end+1,1} = '- `I_knee(T)`: current location of `max_slope(T)`.';
lines{end+1,1} = '- `transition_width_I(T)`: half-maximum width of the positive derivative lobe.';
lines{end+1,1} = '- `knee_prominence(T)`: positive derivative area `trapz(max(dS/dI,0))`, consistent with the alignment-audit susceptibility-area idea.';
lines{end+1,1} = '- `shift_activity(T)`: `|dI_knee/dT|`, used as a temperature-sector indicator for where the current knee moves most strongly.';
lines{end+1,1} = '- `curvature_metric(T)`: absolute second current derivative at the knee, imported from mechanism-followup when available and otherwise computed directly.';
lines{end+1,1} = '';

lines{end+1,1} = '## Relaxation window summary';
lines{end+1,1} = sprintf('- Relax_T_peak = %.6g K', relax.Relax_T_peak);
lines{end+1,1} = sprintf('- Relax_peak_width = %.6g K', relax.Relax_peak_width);
lines{end+1,1} = sprintf('- Relaxation FWHM window from A(T): [%.6g, %.6g] K', relax.windowLow, relax.windowHigh);
lines{end+1,1} = sprintf('- A(T) and R(T) remain tightly aligned: corr(A,R) = %.6g', corrSafe(relax.A, relax.R));
lines{end+1,1} = '';

lines{end+1,1} = '## Switching transition-window summary';
lines{end+1,1} = sprintf('- Primary switching metric selected for direct comparison: `%s`', char(primaryMetric));
lines{end+1,1} = sprintf('- T_knee_peak = %.6g K', summaryRow.T_knee_peak);
lines{end+1,1} = sprintf('- T_transition_window_width = %.6g K', summaryRow.T_transition_window_width);
lines{end+1,1} = sprintf('- Switching FWHM window for the primary metric: [%.6g, %.6g] K', summaryRow.T_window_low, summaryRow.T_window_high);
lines{end+1,1} = '';

lines{end+1,1} = '## Quantitative comparison results';
lines{end+1,1} = '| metric | corr with A | corr with R | overlap with A | overlap with R | T_knee_peak (K) | width (K) | peak diff (K) | width diff (K) | verdict |';
lines{end+1,1} = '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |';
for i = 1:height(comparisonTbl)
    lines{end+1,1} = sprintf('| %s | %.4f | %.4f | %.4f | %.4f | %.3f | %.3f | %.3f | %.3f | %s |', comparisonTbl.metric_name(i), comparisonTbl.corr_with_A(i), comparisonTbl.corr_with_R(i), comparisonTbl.overlap_with_A(i), comparisonTbl.overlap_with_R(i), comparisonTbl.T_knee_peak(i), comparisonTbl.T_transition_window_width(i), comparisonTbl.peak_position_difference_K(i), comparisonTbl.width_difference_K(i), comparisonTbl.hypothesis_verdict(i));
end
lines{end+1,1} = '';

lines{end+1,1} = '## Hypothesis test';
lines{end+1,1} = 'Hypothesis: "If we take a derivative of the Switching map along current near the switching maximum, we may find a knee whose temperature position matches the Relaxation peak, and whose temperature width is similarly broad."';
lines{end+1,1} = sprintf('- Primary metric `%s` gives corr(metric,A)=%.4f, overlap=%.4f, peak-position difference=%.3f K, and width difference=%.3f K.', char(primaryMetric), row.corr_with_A, row.overlap_with_A, row.peak_position_difference_K, row.width_difference_K);
lines{end+1,1} = sprintf('- Verdict for the primary metric: **%s**.', row.hypothesis_verdict);
if row.hypothesis_verdict == "supported"
    lines{end+1,1} = '- Interpretation: the switching current-knee window and the relaxation participation window align in both temperature location and width within the tolerance of this dataset.';
elseif row.hypothesis_verdict == "partially_supported"
    lines{end+1,1} = '- Interpretation: there is some temperature-window agreement, but either the peak position, the width, or the curve-shape overlap remains noticeably mismatched.';
else
    lines{end+1,1} = '- Interpretation: the current-axis knee structure does not track the relaxation participation window closely enough to support a shared window interpretation in this dataset.';
end
lines{end+1,1} = '';

lines{end+1,1} = '## Important caveats';
lines{end+1,1} = '- Switching derivatives are computed on a sparse current grid, so knee positions and widths are quantized by the current step size.';
lines{end+1,1} = '- A minimal 3-point moving-average smoothing was applied before current-axis differentiation to suppress obvious derivative noise without changing the coarse transition geometry.';
lines{end+1,1} = '- `width_I` and related flank metrics are known in this repository to be more definition-sensitive than `S_peak` and `I_peak`.';
lines{end+1,1} = '- The latest switching alignment run uses an older artifact layout, so this comparison reuses its saved MAT/CSV products rather than rerunning the switching pipeline.';
lines{end+1,1} = '';

lines{end+1,1} = '## Visualization choices';
lines{end+1,1} = '- number of curves: one heatmap with two overlays, up to 6 representative current cuts, up to 6 derivative cuts, 4 single-metric temperature traces, and 3 normalized comparison curves';
lines{end+1,1} = '- legend vs colormap: legends for the representative-cut and comparison figures because each panel shows 6 or fewer curves; parula plus colorbar for the heatmap';
lines{end+1,1} = '- colormap used: parula for heatmaps, default MATLAB line colors for line plots';
lines{end+1,1} = sprintf('- smoothing applied: %s', switching.smoothingDescription);
lines{end+1,1} = '- justification: the figure set isolates the current-knee geometry, the derivative signatures, and the temperature-window overlap with relaxation without overloading any one panel';

reportText = strjoin(lines, newline);
end

function figPaths = savePlaceholderFigure(runDir, figureName)
fh = figure('Visible', 'off');
figPaths = save_run_figure(fh, figureName, runDir);
close(fh);
end

function zipPath = buildReviewZip(runDir)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'relaxation_switching_knee_comparison.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zipInputs = {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};
zip(zipPath, zipInputs, runDir);
end

function idx = chooseRepresentativeTemperatures(T, relax, nMax)
anchors = [min(T), relax.windowLow, relax.Relax_T_peak, relax.windowHigh, median(T), max(T)];
idx = zeros(0,1);
for i = 1:numel(anchors)
    [~, k] = min(abs(T - anchors(i)));
    idx(end+1,1) = k; %#ok<AGROW>
end
idx = unique(idx, 'stable');
if numel(idx) > nMax
    idx = idx(1:nMax);
elseif numel(idx) < nMax
    fillIdx = round(linspace(1, numel(T), nMax));
    idx = unique([idx; fillIdx(:)], 'stable');
    if numel(idx) > nMax
        idx = idx(1:nMax);
    end
end
end

function metric = getMetricByName(metricList, metricName)
metric = metricList{1};
for i = 1:numel(metricList)
    if metricList{i}.name == metricName
        metric = metricList{i};
        return;
    end
end
end
function [windowLow, windowHigh, width, peakT] = computeHalfMaxWindow(T, y)
T = T(:);
y = y(:);
windowLow = NaN;
windowHigh = NaN;
width = NaN;
peakT = NaN;
ok = isfinite(T) & isfinite(y);
T = T(ok);
y = y(ok);
if numel(T) < 3
    return;
end
[peakVal, idxPeak] = max(y);
if ~(isfinite(peakVal) && peakVal > 0)
    return;
end
peakT = T(idxPeak);
halfVal = 0.5 * peakVal;
leftIdx = find(y(1:idxPeak) <= halfVal, 1, 'last');
if isempty(leftIdx)
    windowLow = T(1);
elseif leftIdx == idxPeak
    windowLow = T(idxPeak);
else
    windowLow = interpCross(T(leftIdx), T(leftIdx + 1), y(leftIdx) - halfVal, y(leftIdx + 1) - halfVal);
end
rightRel = find(y(idxPeak:end) <= halfVal, 1, 'first');
if isempty(rightRel)
    windowHigh = T(end);
else
    rightIdx = idxPeak + rightRel - 1;
    if rightIdx == idxPeak
        windowHigh = T(idxPeak);
    else
        windowHigh = interpCross(T(rightIdx - 1), T(rightIdx), y(rightIdx - 1) - halfVal, y(rightIdx) - halfVal);
    end
end
width = windowHigh - windowLow;
if ~(isfinite(width) && width >= 0)
    width = NaN;
end
end

function yNorm = normalizeToMax(y)
y = y(:);
yNorm = NaN(size(y));
mx = max(y, [], 'omitnan');
if isfinite(mx) && mx > 0
    yNorm = y ./ mx;
end
end

function yNorm = normalizeToArea(y, x)
y = y(:);
x = x(:);
yNorm = NaN(size(y));
area = trapz(x, y);
if isfinite(area) && area > 0
    yNorm = y ./ area;
end
end

function r = corrSafe(x, y)
x = x(:);
y = y(:);
ok = isfinite(x) & isfinite(y);
r = NaN;
if nnz(ok) < 3
    return;
end
cc = corrcoef(x(ok), y(ok));
if numel(cc) >= 4
    r = cc(1,2);
end
end

function x0 = interpCross(x1, x2, y1, y2)
if ~all(isfinite([x1 x2 y1 y2]))
    x0 = NaN;
    return;
end
if abs(y2 - y1) < eps
    x0 = mean([x1 x2]);
    return;
end
x0 = x1 - y1 * (x2 - x1) / (y2 - y1);
end

function verdict = classifyHypothesis(corrA, overlapA, peakDiff, widthDiff)
if isfinite(corrA) && isfinite(overlapA) && abs(peakDiff) <= 3 && abs(widthDiff) <= 4 && corrA >= 0.75 && overlapA >= 0.60
    verdict = "supported";
elseif isfinite(corrA) && isfinite(overlapA) && abs(peakDiff) <= 8 && abs(widthDiff) <= 8 && corrA >= 0.40 && overlapA >= 0.35
    verdict = "partially_supported";
else
    verdict = "not_supported";
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


