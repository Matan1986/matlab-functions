function out = aging_timescale_bridge(cfg)
% aging_timescale_bridge
% Bridge aging timescales to the saved Relaxation/Switching dynamical
% coordinate using existing run outputs only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(analysisDir);

cfg = applyDefaults(cfg);
source = resolveSourceRuns(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('relax:%s | composite:%s | dip:%s | fm:%s', ...
    char(source.relaxRunName), char(source.switchCompositeRunName), ...
    char(source.dipTauRunName), char(source.fmTauRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Aging timescale bridge run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Switching composite source run: %s\n', source.switchCompositeRunName);
fprintf('Dip timescale source run: %s\n', source.dipTauRunName);
fprintf('FM timescale source run: %s\n', source.fmTauRunName);

appendText(run.log_path, sprintf('[%s] aging_timescale_bridge started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Switching composite source: %s\n', char(source.switchCompositeRunName)));
appendText(run.log_path, sprintf('Dip timescale source: %s\n', char(source.dipTauRunName)));
appendText(run.log_path, sprintf('FM timescale source: %s\n', char(source.fmTauRunName)));

data = loadSourceData(source);
aligned = buildAlignedDataset(data, cfg);
correlations = buildCorrelationTables(aligned);
alignmentTbl = buildTemperatureAlignmentTable(data, aligned);
manifestTbl = buildSourceManifestTable(source, cfg);

alignedPath = save_run_table(aligned.datasetTbl, 'aligned_dynamical_timescale_dataset.csv', runDir);
summaryPath = save_run_table(correlations.summaryTbl, 'correlation_summary.csv', runDir);
pearsonPath = save_run_table(correlations.pearsonTbl, 'pearson_correlation_table.csv', runDir);
spearmanPath = save_run_table(correlations.spearmanTbl, 'spearman_correlation_table.csv', runDir);
alignmentPath = save_run_table(alignmentTbl, 'temperature_alignment_summary.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

figDip = saveTimescaleTemperatureFigure(aligned.Tp, aligned.tau_dip_seconds, ...
    '\tau_{dip}', 'Dip timescale vs aging temperature', cfg.colors.dip, runDir, 'tau_dip_vs_temperature');
figFm = saveTimescaleTemperatureFigure(aligned.Tp, aligned.tau_FM_seconds, ...
    '\tau_{FM}', 'FM timescale vs aging temperature', cfg.colors.fm, runDir, 'tau_fm_vs_temperature');
figOverlay = saveNormalizedOverlayFigure(aligned, cfg, runDir, 'normalized_bridge_overlay');
figADip = saveTimescaleScatterFigure(aligned.A_Tp, aligned.tau_dip_seconds, aligned.Tp, ...
    'Relaxation activity A(T_p)', '\tau_{dip}', 'A(T_p) vs dip timescale', cfg.colors.A, runDir, 'A_vs_tau_dip_scatter');
figAFm = saveTimescaleScatterFigure(aligned.A_Tp, aligned.tau_FM_seconds, aligned.Tp, ...
    'Relaxation activity A(T_p)', '\tau_{FM}', 'A(T_p) vs FM timescale', cfg.colors.A, runDir, 'A_vs_tau_FM_scatter');
figXDip = saveTimescaleScatterFigure(aligned.X_Tp, aligned.tau_dip_seconds, aligned.Tp, ...
    'Switching composite X(T_p)', '\tau_{dip}', 'X(T_p) vs dip timescale', cfg.colors.X, runDir, 'X_vs_tau_dip_scatter');
figXFm = saveTimescaleScatterFigure(aligned.X_Tp, aligned.tau_FM_seconds, aligned.Tp, ...
    'Switching composite X(T_p)', '\tau_{FM}', 'X(T_p) vs FM timescale', cfg.colors.X, runDir, 'X_vs_tau_FM_scatter');

reportText = buildReportText(source, aligned, correlations, alignmentTbl, cfg);
reportPath = save_run_report(reportText, 'aging_timescale_bridge_analysis.md', runDir);
zipPath = buildReviewZip(runDir, 'aging_timescale_bridge_bundle.zip');

bestDipA = selectBestRepresentation(correlations.summaryTbl, "dip", "A");
bestDipX = selectBestRepresentation(correlations.summaryTbl, "dip", "X");
bestFmA = selectBestRepresentation(correlations.summaryTbl, "FM", "A");
bestFmX = selectBestRepresentation(correlations.summaryTbl, "FM", "X");
alignedAPeak = getAlignmentRow(alignmentTbl, "A_Tp_max");
alignedXPeak = getAlignmentRow(alignmentTbl, "X_Tp_max");
dipMin = getAlignmentRow(alignmentTbl, "tau_dip_min");
dipMax = getAlignmentRow(alignmentTbl, "tau_dip_max");
fmMin = getAlignmentRow(alignmentTbl, "tau_FM_min");
fmMax = getAlignmentRow(alignmentTbl, "tau_FM_max");

appendText(run.notes_path, sprintf('Interpolation method: %s (no extrapolation)\n', cfg.interpMethod));
appendText(run.notes_path, sprintf('Common Tp grid: %s K\n', char(join(compose('%.0f', aligned.Tp.'), ', '))));
appendText(run.notes_path, sprintf('Aligned A(Tp) peak: %.0f K\n', alignedAPeak.temperature_K));
appendText(run.notes_path, sprintf('Aligned X(Tp) peak: %.0f K\n', alignedXPeak.temperature_K));
appendText(run.notes_path, sprintf('tau_dip min/max temperatures: %.0f / %.0f K\n', dipMin.temperature_K, dipMax.temperature_K));
appendText(run.notes_path, sprintf('tau_FM min/max temperatures: %.0f / %.0f K\n', fmMin.temperature_K, fmMax.temperature_K));
appendText(run.notes_path, sprintf('Best dip vs A representation: %s (Pearson %.6g, Spearman %.6g, n=%d)\n', ...
    char(bestDipA.display_name), bestDipA.pearson_r, bestDipA.spearman_r, bestDipA.n_pairs));
appendText(run.notes_path, sprintf('Best dip vs X representation: %s (Pearson %.6g, Spearman %.6g, n=%d)\n', ...
    char(bestDipX.display_name), bestDipX.pearson_r, bestDipX.spearman_r, bestDipX.n_pairs));
appendText(run.notes_path, sprintf('Best FM vs A representation: %s (Pearson %.6g, Spearman %.6g, n=%d)\n', ...
    char(bestFmA.display_name), bestFmA.pearson_r, bestFmA.spearman_r, bestFmA.n_pairs));
appendText(run.notes_path, sprintf('Best FM vs X representation: %s (Pearson %.6g, Spearman %.6g, n=%d)\n', ...
    char(bestFmX.display_name), bestFmX.pearson_r, bestFmX.spearman_r, bestFmX.n_pairs));

appendText(run.log_path, sprintf('[%s] aging_timescale_bridge complete\n', stampNow()));
appendText(run.log_path, sprintf('Aligned dataset: %s\n', alignedPath));
appendText(run.log_path, sprintf('Correlation summary: %s\n', summaryPath));
appendText(run.log_path, sprintf('Pearson table: %s\n', pearsonPath));
appendText(run.log_path, sprintf('Spearman table: %s\n', spearmanPath));
appendText(run.log_path, sprintf('Temperature alignment: %s\n', alignmentPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', manifestPath));
appendText(run.log_path, sprintf('Figure 1: %s\n', figDip.png));
appendText(run.log_path, sprintf('Figure 2: %s\n', figFm.png));
appendText(run.log_path, sprintf('Figure 3: %s\n', figOverlay.png));
appendText(run.log_path, sprintf('Figure 4: %s\n', figADip.png));
appendText(run.log_path, sprintf('Figure 5: %s\n', figAFm.png));
appendText(run.log_path, sprintf('Figure 6: %s\n', figXDip.png));
appendText(run.log_path, sprintf('Figure 7: %s\n', figXFm.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.aligned = aligned;
out.correlations = correlations;
out.alignmentTable = alignmentTbl;
out.tables = struct( ...
    'aligned', string(alignedPath), ...
    'summary', string(summaryPath), ...
    'pearson', string(pearsonPath), ...
    'spearman', string(spearmanPath), ...
    'alignment', string(alignmentPath), ...
    'manifest', string(manifestPath));
out.figures = struct( ...
    'tau_dip', string(figDip.png), ...
    'tau_fm', string(figFm.png), ...
    'overlay', string(figOverlay.png), ...
    'A_vs_tau_dip', string(figADip.png), ...
    'A_vs_tau_FM', string(figAFm.png), ...
    'X_vs_tau_dip', string(figXDip.png), ...
    'X_vs_tau_FM', string(figXFm.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'aging_timescale_bridge');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'switchCompositeRunName', 'run_2026_03_13_071713_switching_composite_observable_scan');
cfg = setDefaultField(cfg, 'dipTauRunName', 'run_2026_03_12_223709_aging_timescale_extraction');
cfg = setDefaultField(cfg, 'fmTauRunName', 'run_2026_03_13_013634_aging_fm_timescale_analysis');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'compositeObservableColumn', 'I_over_wS');

colors = struct();
colors.A = [0.12 0.38 0.72];
colors.X = [0.86 0.28 0.16];
colors.dip = [0.17 0.60 0.30];
colors.fm = [0.55 0.29 0.71];
cfg = setDefaultField(cfg, 'colors', colors);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.repoRoot = string(repoRoot);
source.relaxRunName = string(cfg.relaxRunName);
source.switchCompositeRunName = string(cfg.switchCompositeRunName);
source.dipTauRunName = string(cfg.dipTauRunName);
source.fmTauRunName = string(cfg.fmTauRunName);

source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.switchCompositeRunDir = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', char(source.switchCompositeRunName));
source.dipTauRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.dipTauRunName));
source.fmTauRunDir = fullfile(repoRoot, 'results', 'aging', 'runs', char(source.fmTauRunName));

requiredPaths = {
    source.relaxRunDir, fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
    source.switchCompositeRunDir, fullfile(char(source.switchCompositeRunDir), 'tables', 'composite_observables_table.csv');
    source.dipTauRunDir, fullfile(char(source.dipTauRunDir), 'tables', 'tau_vs_Tp.csv');
    source.fmTauRunDir, fullfile(char(source.fmTauRunDir), 'tables', 'tau_FM_vs_Tp.csv')};

for i = 1:size(requiredPaths, 1)
    assert(exist(requiredPaths{i, 1}, 'dir') == 7, 'Missing source run directory: %s', requiredPaths{i, 1});
    assert(exist(requiredPaths{i, 2}, 'file') == 2, 'Missing source file: %s', requiredPaths{i, 2});
end
end

function data = loadSourceData(source)
relaxTbl = readtable(fullfile(source.relaxRunDir, 'tables', 'temperature_observables.csv'), 'VariableNamingRule', 'preserve');
compTbl = readtable(fullfile(source.switchCompositeRunDir, 'tables', 'composite_observables_table.csv'), 'VariableNamingRule', 'preserve');
dipTbl = readtable(fullfile(source.dipTauRunDir, 'tables', 'tau_vs_Tp.csv'), 'VariableNamingRule', 'preserve');
fmTbl = readtable(fullfile(source.fmTauRunDir, 'tables', 'tau_FM_vs_Tp.csv'), 'VariableNamingRule', 'preserve');

requiredRelaxCols = {'T', 'A_T'};
requiredCompCols = {'T_K', 'I_over_wS'};
requiredTauCols = {'Tp', 'tau_effective_seconds'};
assert(all(ismember(requiredRelaxCols, relaxTbl.Properties.VariableNames)), ...
    'Relaxation table is missing one of: %s', strjoin(requiredRelaxCols, ', '));
assert(all(ismember(requiredCompCols, compTbl.Properties.VariableNames)), ...
    'Composite table is missing one of: %s', strjoin(requiredCompCols, ', '));
assert(all(ismember(requiredTauCols, dipTbl.Properties.VariableNames)), ...
    'Dip timescale table is missing one of: %s', strjoin(requiredTauCols, ', '));
assert(all(ismember(requiredTauCols, fmTbl.Properties.VariableNames)), ...
    'FM timescale table is missing one of: %s', strjoin(requiredTauCols, ', '));

relaxTbl = sortrows(relaxTbl, 'T');
compTbl = sortrows(compTbl, 'T_K');
dipTbl = sortrows(dipTbl, 'Tp');
fmTbl = sortrows(fmTbl, 'Tp');

data = struct();
data.relax.table = relaxTbl;
data.relax.T = double(relaxTbl.T(:));
data.relax.A = double(relaxTbl.A_T(:));
data.relax.peakT_source = findExtremumT(data.relax.T, data.relax.A, 'max');
data.relax.peakValue_source = findExtremumValue(data.relax.T, data.relax.A, 'max');

data.switch.table = compTbl;
data.switch.T = double(compTbl.T_K(:));
data.switch.X = double(compTbl.I_over_wS(:));
data.switch.peakT_source = findExtremumT(data.switch.T, data.switch.X, 'max');
data.switch.peakValue_source = findExtremumValue(data.switch.T, data.switch.X, 'max');

data.dip.table = dipTbl;
data.dip.Tp = double(dipTbl.Tp(:));
data.dip.tau = double(dipTbl.tau_effective_seconds(:));

data.fm.table = fmTbl;
data.fm.Tp = double(fmTbl.Tp(:));
data.fm.tau = double(fmTbl.tau_effective_seconds(:));
end

function aligned = buildAlignedDataset(data, cfg)
Tp = unique([data.dip.Tp(:); data.fm.Tp(:)]);
Tp = sort(Tp(isfinite(Tp)));

A_Tp = interp1(data.relax.T, data.relax.A, Tp, cfg.interpMethod, NaN);
X_Tp = interp1(data.switch.T, data.switch.X, Tp, cfg.interpMethod, NaN);

tauDip = mapOntoGrid(Tp, data.dip.Tp, data.dip.tau);
tauFm = mapOntoGrid(Tp, data.fm.Tp, data.fm.tau);

aligned = struct();
aligned.Tp = Tp(:);
aligned.A_Tp = A_Tp(:);
aligned.X_Tp = X_Tp(:);
aligned.tau_dip_seconds = tauDip(:);
aligned.tau_FM_seconds = tauFm(:);
aligned.inv_tau_dip_per_s = positiveInverse(aligned.tau_dip_seconds);
aligned.inv_tau_FM_per_s = positiveInverse(aligned.tau_FM_seconds);
aligned.log_tau_dip = positiveLog(aligned.tau_dip_seconds);
aligned.log_tau_FM = positiveLog(aligned.tau_FM_seconds);

aligned.A_Tp_norm = normalizeUnitMax(aligned.A_Tp);
aligned.X_Tp_norm = normalizeUnitMax(aligned.X_Tp);
aligned.inv_tau_dip_norm = normalizeUnitMax(aligned.inv_tau_dip_per_s);
aligned.inv_tau_FM_norm = normalizeUnitMax(aligned.inv_tau_FM_per_s);

aligned.datasetTbl = table( ...
    aligned.Tp, ...
    aligned.A_Tp, ...
    aligned.X_Tp, ...
    aligned.tau_dip_seconds, ...
    aligned.tau_FM_seconds, ...
    aligned.inv_tau_dip_per_s, ...
    aligned.inv_tau_FM_per_s, ...
    aligned.log_tau_dip, ...
    aligned.log_tau_FM, ...
    'VariableNames', { ...
    'Tp', 'A_Tp', 'X_Tp', 'tau_dip_seconds', 'tau_FM_seconds', ...
    'inv_tau_dip_per_s', 'inv_tau_FM_per_s', 'log_tau_dip', 'log_tau_FM'});

aligned.A_peak_Tp = findExtremumT(aligned.Tp, aligned.A_Tp, 'max');
aligned.A_peak_value_Tp = findExtremumValue(aligned.Tp, aligned.A_Tp, 'max');
aligned.X_peak_Tp = findExtremumT(aligned.Tp, aligned.X_Tp, 'max');
aligned.X_peak_value_Tp = findExtremumValue(aligned.Tp, aligned.X_Tp, 'max');
aligned.tau_dip_min_Tp = findExtremumT(aligned.Tp, aligned.tau_dip_seconds, 'min');
aligned.tau_dip_min_value = findExtremumValue(aligned.Tp, aligned.tau_dip_seconds, 'min');
aligned.tau_dip_max_Tp = findExtremumT(aligned.Tp, aligned.tau_dip_seconds, 'max');
aligned.tau_dip_max_value = findExtremumValue(aligned.Tp, aligned.tau_dip_seconds, 'max');
aligned.tau_FM_min_Tp = findExtremumT(aligned.Tp, aligned.tau_FM_seconds, 'min');
aligned.tau_FM_min_value = findExtremumValue(aligned.Tp, aligned.tau_FM_seconds, 'min');
aligned.tau_FM_max_Tp = findExtremumT(aligned.Tp, aligned.tau_FM_seconds, 'max');
aligned.tau_FM_max_value = findExtremumValue(aligned.Tp, aligned.tau_FM_seconds, 'max');
end

function valuesOnGrid = mapOntoGrid(grid, sourceT, sourceValues)
valuesOnGrid = NaN(size(grid));
[lia, loc] = ismember(grid, sourceT);
valuesOnGrid(lia) = sourceValues(loc(lia));
end

function y = positiveInverse(x)
y = NaN(size(x));
mask = isfinite(x) & x > 0;
y(mask) = 1 ./ x(mask);
end

function y = positiveLog(x)
y = NaN(size(x));
mask = isfinite(x) & x > 0;
y(mask) = log(x(mask));
end

function y = normalizeUnitMax(x)
y = NaN(size(x));
mask = isfinite(x);
if ~any(mask)
    return;
end
peak = max(abs(x(mask)));
if ~isfinite(peak) || peak <= 0
    return;
end
y(mask) = x(mask) ./ peak;
end
function correlations = buildCorrelationTables(aligned)
representations = { ...
    struct('sector',"dip",'transform',"tau",'key',"tau_dip",'display',"tau_dip",'values',aligned.tau_dip_seconds), ...
    struct('sector',"dip",'transform',"inv_tau",'key',"inv_tau_dip",'display',"1/tau_dip",'values',aligned.inv_tau_dip_per_s), ...
    struct('sector',"dip",'transform',"log_tau",'key',"log_tau_dip",'display',"log(tau_dip)",'values',aligned.log_tau_dip), ...
    struct('sector',"FM",'transform',"tau",'key',"tau_FM",'display',"tau_FM",'values',aligned.tau_FM_seconds), ...
    struct('sector',"FM",'transform',"inv_tau",'key',"inv_tau_FM",'display',"1/tau_FM",'values',aligned.inv_tau_FM_per_s), ...
    struct('sector',"FM",'transform',"log_tau",'key',"log_tau_FM",'display',"log(tau_FM)",'values',aligned.log_tau_FM)};

observables = { ...
    struct('key',"A",'display',"A(T_p)",'values',aligned.A_Tp), ...
    struct('key',"X",'display',"X(T_p)",'values',aligned.X_Tp)};

rows = repmat(summaryRowTemplate(), 0, 1);
for i = 1:numel(representations)
    rep = representations{i};
    for j = 1:numel(observables)
        obs = observables{j};
        stats = computeCorrelationStats(rep.values, obs.values);
        row = summaryRowTemplate();
        row.sector = rep.sector;
        row.transform = rep.transform;
        row.representation_key = rep.key;
        row.display_name = rep.display;
        row.observable_key = obs.key;
        row.observable_display = obs.display;
        row.n_pairs = stats.n_pairs;
        row.pearson_r = stats.pearson_r;
        row.pearson_p = stats.pearson_p;
        row.spearman_r = stats.spearman_r;
        row.spearman_p = stats.spearman_p;
        row.score_abs_sum = abs(stats.pearson_r) + abs(stats.spearman_r);
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
end

summaryTbl = struct2table(rows);
summaryTbl = sortrows(summaryTbl, {'sector', 'observable_key', 'score_abs_sum'}, {'ascend', 'ascend', 'descend'});

pearsonTbl = buildMethodTable(summaryTbl, 'pearson');
spearmanTbl = buildMethodTable(summaryTbl, 'spearman');

correlations = struct();
correlations.summaryTbl = summaryTbl;
correlations.pearsonTbl = pearsonTbl;
correlations.spearmanTbl = spearmanTbl;
end

function row = summaryRowTemplate()
row = struct( ...
    'sector', "", ...
    'transform', "", ...
    'representation_key', "", ...
    'display_name', "", ...
    'observable_key', "", ...
    'observable_display', "", ...
    'n_pairs', 0, ...
    'pearson_r', NaN, ...
    'pearson_p', NaN, ...
    'spearman_r', NaN, ...
    'spearman_p', NaN, ...
    'score_abs_sum', NaN);
end

function stats = computeCorrelationStats(x, y)
mask = isfinite(x) & isfinite(y);
stats = struct('n_pairs', nnz(mask), 'pearson_r', NaN, 'pearson_p', NaN, 'spearman_r', NaN, 'spearman_p', NaN);
if nnz(mask) < 2
    return;
end
[stats.pearson_r, stats.pearson_p] = corr(x(mask), y(mask), 'Rows', 'complete', 'Type', 'Pearson');
[stats.spearman_r, stats.spearman_p] = corr(x(mask), y(mask), 'Rows', 'complete', 'Type', 'Spearman');
end

function methodTbl = buildMethodTable(summaryTbl, methodName)
repOrder = ["tau_dip", "inv_tau_dip", "log_tau_dip", "tau_FM", "inv_tau_FM", "log_tau_FM"];
displayOrder = ["tau_dip", "1/tau_dip", "log(tau_dip)", "tau_FM", "1/tau_FM", "log(tau_FM)"];
rows = repmat(struct('sector',"",'representation_key',"",'display_name',"", ...
    'A_r',NaN,'A_p',NaN,'A_n_pairs',0,'X_r',NaN,'X_p',NaN,'X_n_pairs',0), numel(repOrder), 1);

for i = 1:numel(repOrder)
    rows(i).representation_key = repOrder(i);
    rows(i).display_name = displayOrder(i);
    if contains(repOrder(i), "dip")
        rows(i).sector = "dip";
    else
        rows(i).sector = "FM";
    end

    subA = summaryTbl(summaryTbl.representation_key == repOrder(i) & summaryTbl.observable_key == "A", :);
    subX = summaryTbl(summaryTbl.representation_key == repOrder(i) & summaryTbl.observable_key == "X", :);

    if ~isempty(subA)
        rows(i).A_n_pairs = subA.n_pairs(1);
        if strcmp(methodName, 'pearson')
            rows(i).A_r = subA.pearson_r(1);
            rows(i).A_p = subA.pearson_p(1);
        else
            rows(i).A_r = subA.spearman_r(1);
            rows(i).A_p = subA.spearman_p(1);
        end
    end

    if ~isempty(subX)
        rows(i).X_n_pairs = subX.n_pairs(1);
        if strcmp(methodName, 'pearson')
            rows(i).X_r = subX.pearson_r(1);
            rows(i).X_p = subX.pearson_p(1);
        else
            rows(i).X_r = subX.spearman_r(1);
            rows(i).X_p = subX.spearman_p(1);
        end
    end
end

methodTbl = struct2table(rows);
end

function alignmentTbl = buildTemperatureAlignmentTable(data, aligned)
aSourcePeak = data.relax.peakT_source;
xSourcePeak = data.switch.peakT_source;
aTpPeak = aligned.A_peak_Tp;
xTpPeak = aligned.X_peak_Tp;

rows = [
    makeAlignmentRow("A_source_max", "Relaxation A(T) source max", "relaxation_source", "max", aSourcePeak, data.relax.peakValue_source, aSourcePeak, xSourcePeak, aTpPeak, xTpPeak);
    makeAlignmentRow("X_source_max", "Switching X(T) source max", "switching_source", "max", xSourcePeak, data.switch.peakValue_source, aSourcePeak, xSourcePeak, aTpPeak, xTpPeak);
    makeAlignmentRow("A_Tp_max", "Interpolated A(T_p) max", "aging_common_grid", "max", aTpPeak, aligned.A_peak_value_Tp, aSourcePeak, xSourcePeak, aTpPeak, xTpPeak);
    makeAlignmentRow("X_Tp_max", "Interpolated X(T_p) max", "aging_common_grid", "max", xTpPeak, aligned.X_peak_value_Tp, aSourcePeak, xSourcePeak, aTpPeak, xTpPeak);
    makeAlignmentRow("tau_dip_min", "tau_dip(T_p) min", "aging_common_grid", "min", aligned.tau_dip_min_Tp, aligned.tau_dip_min_value, aSourcePeak, xSourcePeak, aTpPeak, xTpPeak);
    makeAlignmentRow("tau_dip_max", "tau_dip(T_p) max", "aging_common_grid", "max", aligned.tau_dip_max_Tp, aligned.tau_dip_max_value, aSourcePeak, xSourcePeak, aTpPeak, xTpPeak);
    makeAlignmentRow("tau_FM_min", "tau_FM(T_p) min", "aging_common_grid", "min", aligned.tau_FM_min_Tp, aligned.tau_FM_min_value, aSourcePeak, xSourcePeak, aTpPeak, xTpPeak);
    makeAlignmentRow("tau_FM_max", "tau_FM(T_p) max", "aging_common_grid", "max", aligned.tau_FM_max_Tp, aligned.tau_FM_max_value, aSourcePeak, xSourcePeak, aTpPeak, xTpPeak)];

alignmentTbl = struct2table(rows);
end

function row = makeAlignmentRow(featureKey, displayName, gridName, extremumType, T, value, aSourcePeak, xSourcePeak, aTpPeak, xTpPeak)
row = struct();
row.feature_key = string(featureKey);
row.display_name = string(displayName);
row.reference_grid = string(gridName);
row.extremum_type = string(extremumType);
row.temperature_K = T;
row.value = value;
row.offset_vs_A_source_K = T - aSourcePeak;
row.offset_vs_X_source_K = T - xSourcePeak;
row.offset_vs_A_Tp_K = T - aTpPeak;
row.offset_vs_X_Tp_K = T - xTpPeak;
end

function manifestTbl = buildSourceManifestTable(source, cfg)
manifestTbl = table( ...
    string({'relaxation'; 'cross_experiment'; 'aging'; 'aging'}), ...
    string({'A(T)'; 'X(T)'; 'tau_dip(Tp)'; 'tau_FM(Tp)'}), ...
    string({char(source.relaxRunName); char(source.switchCompositeRunName); char(source.dipTauRunName); char(source.fmTauRunName)}), ...
    string({char(source.relaxRunDir); char(source.switchCompositeRunDir); char(source.dipTauRunDir); char(source.fmTauRunDir)}), ...
    string({ ...
        fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'); ...
        fullfile(char(source.switchCompositeRunDir), 'tables', 'composite_observables_table.csv'); ...
        fullfile(char(source.dipTauRunDir), 'tables', 'tau_vs_Tp.csv'); ...
        fullfile(char(source.fmTauRunDir), 'tables', 'tau_FM_vs_Tp.csv')}), ...
    string({'A_T'; cfg.compositeObservableColumn; 'tau_effective_seconds'; 'tau_effective_seconds'}), ...
    'VariableNames', {'experiment', 'observable', 'run_name', 'run_dir', 'file_path', 'column_used'});
end
function paths = saveTimescaleTemperatureFigure(Tp, tauValues, tauLabel, plotTitle, color, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 8.8 6.5]);
ax = axes(fig);
hold(ax, 'on');

mask = isfinite(Tp) & isfinite(tauValues) & tauValues > 0;
semilogy(ax, Tp(mask), tauValues(mask), '-o', ...
    'Color', color, 'MarkerFaceColor', color, 'MarkerEdgeColor', color, ...
    'LineWidth', 2, 'MarkerSize', 6);

[minT, minValue] = extremumPair(Tp, tauValues, 'min');
[maxT, maxValue] = extremumPair(Tp, tauValues, 'max');
if isfinite(minT) && isfinite(minValue)
    plot(ax, minT, minValue, 'ks', 'MarkerSize', 8, 'LineWidth', 1.25);
    text(ax, minT, minValue, sprintf('  min %.0f K', minT), 'FontSize', 8, 'VerticalAlignment', 'bottom');
end
if isfinite(maxT) && isfinite(maxValue)
    plot(ax, maxT, maxValue, 'kd', 'MarkerSize', 8, 'LineWidth', 1.25);
    text(ax, maxT, maxValue, sprintf('  max %.0f K', maxT), 'FontSize', 8, 'VerticalAlignment', 'top');
end

xlabel(ax, 'Aging temperature T_p (K)');
ylabel(ax, sprintf('%s (s)', tauLabel));
title(ax, plotTitle);
xlim(ax, [min(Tp) - 1, max(Tp) + 1]);

paths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function paths = saveNormalizedOverlayFigure(aligned, cfg, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 17.8 6.8]);
ax = axes(fig);
hold(ax, 'on');

plot(ax, aligned.Tp, aligned.A_Tp_norm, '-o', ...
    'Color', cfg.colors.A, 'MarkerFaceColor', cfg.colors.A, 'LineWidth', 2, 'MarkerSize', 5);
plot(ax, aligned.Tp, aligned.X_Tp_norm, '-s', ...
    'Color', cfg.colors.X, 'MarkerFaceColor', cfg.colors.X, 'LineWidth', 2, 'MarkerSize', 5);
plot(ax, aligned.Tp, aligned.inv_tau_dip_norm, '-^', ...
    'Color', cfg.colors.dip, 'MarkerFaceColor', cfg.colors.dip, 'LineWidth', 2, 'MarkerSize', 5);
plot(ax, aligned.Tp, aligned.inv_tau_FM_norm, '-d', ...
    'Color', cfg.colors.fm, 'MarkerFaceColor', cfg.colors.fm, 'LineWidth', 2, 'MarkerSize', 5);

xlabel(ax, 'Aging temperature T_p (K)');
ylabel(ax, 'Normalized value (unit max)');
title(ax, 'Normalized bridge observables on the aging temperature grid');
legend(ax, {'A(T_p)', 'X(T_p)', '1/tau_dip', '1/tau_FM'}, 'Location', 'best');
xlim(ax, [min(aligned.Tp) - 1, max(aligned.Tp) + 1]);

paths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function paths = saveTimescaleScatterFigure(xValues, tauValues, Tp, xLabel, tauLabel, plotTitle, color, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 8.8 6.6]);
ax = axes(fig);
hold(ax, 'on');

mask = isfinite(xValues) & isfinite(tauValues) & tauValues > 0;
xPlot = xValues(mask);
yPlot = tauValues(mask);
tPlot = Tp(mask);

scatter(ax, xPlot, yPlot, 45, 'MarkerFaceColor', color, 'MarkerEdgeColor', 'k', 'LineWidth', 0.75);
if numel(xPlot) > 1
    plot(ax, xPlot, yPlot, '-', 'Color', 0.6 * color + 0.4 * [1 1 1], 'LineWidth', 1.25);
end

for i = 1:numel(tPlot)
    text(ax, xPlot(i), yPlot(i), sprintf('  %.0f K', tPlot(i)), 'FontSize', 7, 'VerticalAlignment', 'bottom');
end

set(ax, 'YScale', 'log');
xlabel(ax, xLabel);
ylabel(ax, sprintf('%s (s)', tauLabel));
title(ax, plotTitle);

stats = computeCorrelationStats(xPlot, yPlot);
txt = sprintf('n = %d\nPearson = %s\nSpearman = %s', ...
    stats.n_pairs, fmtFixed(stats.pearson_r, '%.3f'), fmtFixed(stats.spearman_r, '%.3f'));
text(ax, 0.05, 0.95, txt, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'w', 'Margin', 6, 'FontSize', 8);

paths = save_run_figure(fig, figureName, runDir);
close(fig);
end
function reportText = buildReportText(source, aligned, correlations, alignmentTbl, cfg)
bestDipA = selectBestRepresentation(correlations.summaryTbl, "dip", "A");
bestDipX = selectBestRepresentation(correlations.summaryTbl, "dip", "X");
bestFmA = selectBestRepresentation(correlations.summaryTbl, "FM", "A");
bestFmX = selectBestRepresentation(correlations.summaryTbl, "FM", "X");

tauDipRow = getSummaryRow(correlations.summaryTbl, "tau_dip", "A");
tauDipXRow = getSummaryRow(correlations.summaryTbl, "tau_dip", "X");
tauFmRow = getSummaryRow(correlations.summaryTbl, "tau_FM", "A");
tauFmXRow = getSummaryRow(correlations.summaryTbl, "tau_FM", "X");

sourceAPeak = getAlignmentRow(alignmentTbl, "A_source_max");
sourceXPeak = getAlignmentRow(alignmentTbl, "X_source_max");
alignedAPeak = getAlignmentRow(alignmentTbl, "A_Tp_max");
dipMin = getAlignmentRow(alignmentTbl, "tau_dip_min");
dipMax = getAlignmentRow(alignmentTbl, "tau_dip_max");
fmMin = getAlignmentRow(alignmentTbl, "tau_FM_min");
fmMax = getAlignmentRow(alignmentTbl, "tau_FM_max");

lines = strings(0, 1);
lines(end + 1) = "# Aging timescale bridge analysis";
lines(end + 1) = "";
lines(end + 1) = "## Datasets used";
lines(end + 1) = "- Relaxation activity `A(T)` from `" + fullfile(char(source.relaxRunName), 'tables', 'temperature_observables.csv') + "`, column `A_T`.";
lines(end + 1) = "- Switching composite `X(T) = I_peak / (width * S_peak)` from `" + fullfile(char(source.switchCompositeRunName), 'tables', 'composite_observables_table.csv') + "`, column `I_over_wS`.";
lines(end + 1) = "- Dip-sector timescale `tau_dip(T_p)` from `" + fullfile(char(source.dipTauRunName), 'tables', 'tau_vs_Tp.csv') + "`, column `tau_effective_seconds`.";
lines(end + 1) = "- FM-sector timescale `tau_FM(T_p)` from `" + fullfile(char(source.fmTauRunName), 'tables', 'tau_FM_vs_Tp.csv') + "`, column `tau_effective_seconds`.";
lines(end + 1) = "";
lines(end + 1) = "## Alignment and common grid";
lines(end + 1) = "- Aging `T_p` values used as the common grid: `" + join(compose('%.0f', aligned.Tp.'), ', ') + "` K.";
lines(end + 1) = "- `A(T)` and `X(T)` were interpolated onto `T_p` with `" + string(cfg.interpMethod) + "` and no extrapolation.";
lines(end + 1) = "- Finite samples on the common grid: `A(T_p)` = " + string(nnz(isfinite(aligned.A_Tp))) + ...
    ", `X(T_p)` = " + string(nnz(isfinite(aligned.X_Tp))) + ...
    ", `tau_dip(T_p)` = " + string(nnz(isfinite(aligned.tau_dip_seconds))) + ...
    ", `tau_FM(T_p)` = " + string(nnz(isfinite(aligned.tau_FM_seconds))) + ".";
lines(end + 1) = "- `X(T_p)` is undefined at `34 K` because the saved switching composite scan ends at `30 K`.";
lines(end + 1) = "- `log(tau)` denotes the natural logarithm.";
lines(end + 1) = "";
lines(end + 1) = "## Pearson correlations";
lines(end + 1) = renderMethodMarkdown(correlations.pearsonTbl);
lines(end + 1) = "";
lines(end + 1) = "## Spearman correlations";
lines(end + 1) = renderMethodMarkdown(correlations.spearmanTbl);
lines(end + 1) = "";
lines(end + 1) = "## Temperature alignment analysis";
lines(end + 1) = "- On the source grids, `A(T)` peaks at `" + fmtFixed(sourceAPeak.temperature_K, '%.0f') + " K` and `X(T)` peaks at `" + fmtFixed(sourceXPeak.temperature_K, '%.0f') + " K`.";
lines(end + 1) = "- After interpolation onto the aging grid, both `A(T_p)` and `X(T_p)` peak at `" + fmtFixed(alignedAPeak.temperature_K, '%.0f') + " K`.";
lines(end + 1) = "- `tau_dip` reaches its minimum at `" + fmtFixed(dipMin.temperature_K, '%.0f') + " K` and maximum at `" + fmtFixed(dipMax.temperature_K, '%.0f') + " K`, giving offsets of `" + fmtSigned(dipMin.offset_vs_A_Tp_K, '%.0f') + " K` and `" + fmtSigned(dipMax.offset_vs_A_Tp_K, '%.0f') + " K` relative to the aligned `A/X` peak.";
lines(end + 1) = "- `tau_FM` reaches its minimum at `" + fmtFixed(fmMin.temperature_K, '%.0f') + " K` and maximum at `" + fmtFixed(fmMax.temperature_K, '%.0f') + " K`, giving offsets of `" + fmtSigned(fmMin.offset_vs_A_Tp_K, '%.0f') + " K` and `" + fmtSigned(fmMax.offset_vs_A_Tp_K, '%.0f') + " K` relative to the aligned `A/X` peak.";
lines(end + 1) = "";
lines(end + 1) = "## Conservative interpretation";
lines(end + 1) = "- Best dip-sector link to `A(T_p)`: `" + bestDipA.display_name + "` with Pearson `" + fmtFixed(bestDipA.pearson_r, '%.3f') + "`, Spearman `" + fmtFixed(bestDipA.spearman_r, '%.3f') + "`, `n = " + string(bestDipA.n_pairs) + "`.";
lines(end + 1) = "- Best dip-sector link to `X(T_p)`: `" + bestDipX.display_name + "` with Pearson `" + fmtFixed(bestDipX.pearson_r, '%.3f') + "`, Spearman `" + fmtFixed(bestDipX.spearman_r, '%.3f') + "`, `n = " + string(bestDipX.n_pairs) + "`.";
lines(end + 1) = "- Best FM-sector link to `A(T_p)`: `" + bestFmA.display_name + "` with Pearson `" + fmtFixed(bestFmA.pearson_r, '%.3f') + "`, Spearman `" + fmtFixed(bestFmA.spearman_r, '%.3f') + "`, `n = " + string(bestFmA.n_pairs) + "`.";
lines(end + 1) = "- Best FM-sector link to `X(T_p)`: `" + bestFmX.display_name + "` with Pearson `" + fmtFixed(bestFmX.pearson_r, '%.3f') + "`, Spearman `" + fmtFixed(bestFmX.spearman_r, '%.3f') + "`, `n = " + string(bestFmX.n_pairs) + "`.";
lines(end + 1) = "- Dip-sector raw timescale monotonicity: " + describeRawMonotonicity("tau_dip", tauDipRow, tauDipXRow) + ".";
lines(end + 1) = "- FM-sector raw timescale monotonicity: " + describeRawMonotonicity("tau_FM", tauFmRow, tauFmXRow) + ".";
lines(end + 1) = "- Peak-alignment check near `26 K`: neither aging timescale has a minimum or maximum at the common `A/X` peak. Both maxima occur at `22 K`, while the minima are at `10 K` (`tau_dip`) and `14 K` (`tau_FM`).";
lines(end + 1) = "- Empirically, any bridge that appears here should be treated as a small-sample descriptive trend rather than a settled dynamical law.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- Number of curves: Figure 1 = 1, Figure 2 = 1, Figure 3 = 4, Figures 4-7 = 1 scatter series each.";
lines(end + 1) = "- Legend vs colormap: explicit legend only in the four-curve overlay; no colormap was needed.";
lines(end + 1) = "- Colormap used: none. Fixed publication-safe colors were used for `A`, `X`, `tau_dip`, and `tau_FM`.";
lines(end + 1) = "- Smoothing applied: none. The only transformation beyond reusing saved outputs is `pchip` interpolation of `A(T)` and `X(T)` onto the aging grid.";
lines(end + 1) = "- Justification: the datasets contain only 5-8 usable temperatures per comparison, so direct point-marked line plots and temperature-labeled scatters preserve the empirical support more clearly than denser derived visual encodings.";

reportText = strjoin(lines, newline);
end

function textOut = renderMethodMarkdown(methodTbl)
lines = strings(0, 1);
lines(end + 1) = "| Representation | vs A(T_p) | vs X(T_p) |";
lines(end + 1) = "| --- | --- | --- |";
for i = 1:height(methodTbl)
    lines(end + 1) = "| `" + methodTbl.display_name(i) + "` | " + ...
        fmtCorrelationCell(methodTbl.A_r(i), methodTbl.A_p(i), methodTbl.A_n_pairs(i)) + " | " + ...
        fmtCorrelationCell(methodTbl.X_r(i), methodTbl.X_p(i), methodTbl.X_n_pairs(i)) + " |";
end
textOut = strjoin(lines, newline);
end

function cellText = fmtCorrelationCell(r, p, nPairs)
cellText = fmtFixed(r, '%.3f') + " (`p = " + fmtFixed(p, '%.3g') + "`, `n = " + string(nPairs) + "`)";
end

function description = describeRawMonotonicity(label, rowA, rowX)
bestAbsSpearman = max(abs([rowA.spearman_r, rowX.spearman_r]));
if ~isfinite(bestAbsSpearman)
    description = label + " has no usable paired samples";
elseif bestAbsSpearman >= 0.9
    description = label + " shows a strong monotonic relation on the sampled points";
elseif bestAbsSpearman >= 0.7
    description = label + " shows a moderate monotonic relation on the sampled points";
elseif bestAbsSpearman >= 0.5
    description = label + " shows only a weak monotonic tendency";
else
    description = label + " does not show a clear monotonic relation";
end
end
function row = selectBestRepresentation(summaryTbl, sectorKey, observableKey)
subset = summaryTbl(summaryTbl.sector == sectorKey & summaryTbl.observable_key == observableKey, :);
if isempty(subset)
    row = summaryRowTemplate();
    return;
end
[~, idx] = max(subset.score_abs_sum);
row = tableRowToStruct(subset(idx, :));
end

function row = getSummaryRow(summaryTbl, representationKey, observableKey)
subset = summaryTbl(summaryTbl.representation_key == representationKey & summaryTbl.observable_key == observableKey, :);
if isempty(subset)
    row = summaryRowTemplate();
    return;
end
row = tableRowToStruct(subset(1, :));
end

function row = getAlignmentRow(alignmentTbl, featureKey)
subset = alignmentTbl(alignmentTbl.feature_key == featureKey, :);
if isempty(subset)
    error('Alignment row not found: %s', featureKey);
end
row = tableRowToStruct(subset(1, :));
end

function s = tableRowToStruct(tblRow)
vars = tblRow.Properties.VariableNames;
s = struct();
for i = 1:numel(vars)
    value = tblRow.(vars{i});
    if iscell(value)
        value = value{1};
    elseif isnumeric(value) || islogical(value)
        value = value(1);
    else
        value = value(1);
    end
    s.(vars{i}) = value;
end
end

function [T, value] = extremumPair(grid, y, modeName)
T = findExtremumT(grid, y, modeName);
value = findExtremumValue(grid, y, modeName);
end

function T = findExtremumT(grid, y, modeName)
mask = isfinite(grid) & isfinite(y);
if strcmp(modeName, 'min')
    mask = mask & y > 0;
end
if ~any(mask)
    T = NaN;
    return;
end
grid = grid(mask);
y = y(mask);
if strcmp(modeName, 'min')
    [~, idx] = min(y);
else
    [~, idx] = max(y);
end
T = grid(idx);
end

function value = findExtremumValue(grid, y, modeName)
mask = isfinite(grid) & isfinite(y);
if strcmp(modeName, 'min')
    mask = mask & y > 0;
end
if ~any(mask)
    value = NaN;
    return;
end
y = y(mask);
if strcmp(modeName, 'min')
    value = min(y);
else
    value = max(y);
end
end

function value = setDefaultField(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s;
    return;
end
s.(fieldName) = defaultValue;
value = s;
end

function appendText(filePath, textToAppend)
fid = fopen(filePath, 'a');
if fid < 0
    error('Could not append to file: %s', filePath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', textToAppend);
end

function stamp = stampNow()
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
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
zip(zipPath, {'figures', 'tables', 'reports'}, runDir);
end

function txt = fmtFixed(value, pattern)
if nargin < 2
    pattern = '%.3g';
end
if ~isfinite(value)
    txt = "NaN";
else
    txt = string(sprintf(pattern, value));
end
end

function txt = fmtSigned(value, pattern)
if nargin < 2
    pattern = '%.3g';
end
if ~isfinite(value)
    txt = "NaN";
elseif value >= 0
    txt = string(sprintf(['+' pattern], value));
else
    txt = string(sprintf(pattern, value));
end
end

