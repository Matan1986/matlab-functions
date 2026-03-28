function out = switching_barrier_distribution_from_map(cfg)
% switching_barrier_distribution_from_map
% Reconstruct an effective threshold/barrier distribution P_T(I_th) from
% saved switching S(I,T) map data using only derived run outputs.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(repoRoot));

cfg = applyDefaults(cfg);
source = resolveSwitchingSource(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('source_run:%s', source.sourceRunId);
run = createRunContext('switching', runCfg);
runDir = run.run_dir;
ensureArtifactDirs(runDir);

fprintf('Run directory: %s\n', runDir);
appendLog(run.log_path, sprintf('[%s] switching_barrier_distribution_from_map started', stampNow()));
appendLog(run.log_path, sprintf('Source run: %s', source.sourceRunId));
appendLog(run.log_path, sprintf('Source samples: %s', source.samplesPath));
appendLog(run.log_path, sprintf('Source core map: %s', source.corePath));

[temps, currents, SmapRaw, source] = loadSwitchingMap(source);
results = reconstructBarrierDistribution(temps, currents, SmapRaw, cfg);

ptMatrixTbl = buildPTMatrixTable(results.temps, results.currents, results.PT);
ptSummaryTbl = buildPTSummaryTable(results);
sourceManifestTbl = buildSourceManifestTable(source);

ptMatrixPath = save_run_table(ptMatrixTbl, 'PT_matrix.csv', runDir);
ptSummaryPath = save_run_table(ptSummaryTbl, 'PT_summary.csv', runDir);
manifestPath = save_run_table(sourceManifestTbl, 'source_run_manifest.csv', runDir);

figS = saveSMapFigure(results, runDir, 'switching_map_S_I_T');
figD = saveDerivativeFigure(results, runDir, 'switching_map_dS_dI');
figC = saveCDFReconstructionFigure(results, runDir, 'switching_cdf_reconstruction_vs_original');

reportText = buildReportText(results, source, cfg, ptMatrixPath, ptSummaryPath);
reportPath = save_run_report(reportText, 'switching_barrier_distribution_report.md', runDir);
zipPath = buildReviewZip(runDir, 'switching_barrier_distribution_bundle.zip');

appendLog(run.notes_path, sprintf('Source run: %s', source.sourceRunId));
appendLog(run.notes_path, sprintf('Temperatures analyzed: %d', numel(results.temps)));
appendLog(run.notes_path, sprintf('Current grid points: %d', numel(results.currents)));
appendLog(run.notes_path, sprintf('Mean CDF RMSE: %.6g', results.summary.mean_cdf_rmse));
appendLog(run.notes_path, sprintf('Median CDF RMSE: %.6g', results.summary.median_cdf_rmse));
appendLog(run.notes_path, sprintf('Max CDF RMSE: %.6g', results.summary.max_cdf_rmse));

appendLog(run.log_path, sprintf('Saved PT matrix: %s', ptMatrixPath));
appendLog(run.log_path, sprintf('Saved PT summary: %s', ptSummaryPath));
appendLog(run.log_path, sprintf('Saved source manifest: %s', manifestPath));
appendLog(run.log_path, sprintf('Saved report: %s', reportPath));
appendLog(run.log_path, sprintf('Saved review zip: %s', zipPath));
appendLog(run.log_path, sprintf('[%s] switching_barrier_distribution_from_map complete', stampNow()));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.results = results;
out.output = struct( ...
    'PT_matrix', string(ptMatrixPath), ...
    'PT_summary', string(ptSummaryPath), ...
    'source_manifest', string(manifestPath), ...
    'figure_S_map', string(figS.png), ...
    'figure_dS_dI', string(figD.png), ...
    'figure_CDF_reconstruction', string(figC.png), ...
    'report', string(reportPath), ...
    'review_zip', string(zipPath));

fprintf('\n=== switching_barrier_distribution_from_map complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Mean CDF RMSE: %.6g\n', results.summary.mean_cdf_rmse);
fprintf('PT matrix: %s\n', ptMatrixPath);
fprintf('PT summary: %s\n', ptSummaryPath);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_barrier_distribution_from_map');
cfg = setDefault(cfg, 'sourceRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'sourceRunName', '');
cfg = setDefault(cfg, 'switchLabelHint', 'alignment_audit');
cfg = setDefault(cfg, 'sampleTemperatureToleranceK', 0.12);
cfg = setDefault(cfg, 'smoothingWindow', 5);
cfg = setDefault(cfg, 'smoothingMethod', 'movmean');
cfg = setDefault(cfg, 'enforceMonotoneCDF', true);
cfg = setDefault(cfg, 'minPointsPerTemperature', 6);
end

function source = resolveSwitchingSource(repoRoot, cfg)
if strlength(string(cfg.sourceRunId)) > 0
    runDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(string(cfg.sourceRunId)));
elseif strlength(string(cfg.sourceRunName)) > 0
    runDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(string(cfg.sourceRunName)));
else
    runDir = findLatestSwitchingRunWithMap(repoRoot, string(cfg.switchLabelHint));
end

if exist(runDir, 'dir') ~= 7
    error('switching_barrier_distribution_from_map:MissingRunDir', 'Switching run directory not found: %s', runDir);
end

source = struct();
source.runDir = string(runDir);
source.sourceRunId = string(extractAfter(runDir, [filesep 'runs' filesep]));
source.corePath = string(fullfile(runDir, 'switching_alignment_core_data.mat'));
source.samplesPath = string(fullfile(runDir, 'alignment_audit', 'switching_alignment_samples.csv'));
if exist(char(source.samplesPath), 'file') ~= 2
    source.samplesPath = string(fullfile(runDir, 'switching_alignment_samples.csv'));
end
source.loadedFrom = "";
source.signalMetric = "";
end

function runDir = findLatestSwitchingRunWithMap(repoRoot, labelHint)
runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('switching_barrier_distribution_from_map:NoRuns', 'No switching runs found under %s', runsRoot);
end

[~, order] = sort({runDirs.name});
runDirs = runDirs(order);

for i = numel(runDirs):-1:1
    candidate = fullfile(runDirs(i).folder, runDirs(i).name);
    candidateName = string(runDirs(i).name);
    if strlength(labelHint) > 0 && ~contains(candidateName, labelHint)
        continue;
    end
    hasCore = exist(fullfile(candidate, 'switching_alignment_core_data.mat'), 'file') == 2;
    hasSamplesA = exist(fullfile(candidate, 'alignment_audit', 'switching_alignment_samples.csv'), 'file') == 2;
    hasSamplesB = exist(fullfile(candidate, 'switching_alignment_samples.csv'), 'file') == 2;
    if hasCore || hasSamplesA || hasSamplesB
        runDir = candidate;
        return;
    end
end

error('switching_barrier_distribution_from_map:NoMatchingRun', 'No switching run with map data matched requested criteria.');
end

function [temps, currents, Smap, source] = loadSwitchingMap(source)
if exist(char(source.corePath), 'file') == 2
    core = load(char(source.corePath));
    requireField(core, 'temps', char(source.corePath));
    requireField(core, 'currents', char(source.corePath));
    requireField(core, 'Smap', char(source.corePath));

    temps = double(core.temps(:));
    currents = double(core.currents(:));
    Smap = double(core.Smap);

    if isfield(core, 'metricType') && ~isempty(core.metricType)
        source.signalMetric = string(core.metricType);
    end
    source.loadedFrom = "switching_alignment_core_data.mat";
elseif exist(char(source.samplesPath), 'file') == 2
    samplesTbl = readtable(char(source.samplesPath), 'VariableNamingRule', 'preserve');
    [temps, currents, Smap] = buildSwitchingMapFromSamples(samplesTbl);
    source.loadedFrom = "switching_alignment_samples.csv";
else
    error('switching_barrier_distribution_from_map:MissingMapData', ...
        'Neither %s nor %s exists.', char(source.corePath), char(source.samplesPath));
end

[Smap, temps, currents] = orientAndSortMap(Smap, temps, currents);
end

function [Smap, temps, currents] = orientAndSortMap(Smap, temps, currents)
rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurrents = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);

if rowsAreCurrents && ~rowsAreTemps
    Smap = Smap.';
elseif ~(rowsAreTemps || rowsAreCurrents)
    error('switching_barrier_distribution_from_map:MapSizeMismatch', ...
        'Smap size [%d %d] does not match temps (%d) and currents (%d).', ...
        size(Smap, 1), size(Smap, 2), numel(temps), numel(currents));
end

[temps, tOrder] = sort(temps(:));
[currents, iOrder] = sort(currents(:));
Smap = Smap(tOrder, iOrder);

assert(all(isfinite(temps)) && all(diff(temps) > 0), 'Temperature axis must be finite and strictly increasing.');
assert(all(isfinite(currents)) && all(diff(currents) > 0), 'Current axis must be finite and strictly increasing.');
end

function [temps, currents, Smap] = buildSwitchingMapFromSamples(samplesTbl)
T = readNumericColumn(samplesTbl, 'T_K');
I = readNumericColumn(samplesTbl, 'current_mA');
S = readNumericColumn(samplesTbl, 'S_percent');

valid = isfinite(T) & isfinite(I) & isfinite(S);
T = T(valid);
I = I(valid);
S = S(valid);

temps = unique(T);
currents = unique(I);
temps = sort(temps(:));
currents = sort(currents(:));

Smap = NaN(numel(temps), numel(currents));
for it = 1:numel(temps)
    for ii = 1:numel(currents)
        mask = abs(T - temps(it)) < 1e-9 & abs(I - currents(ii)) < 1e-9;
        if any(mask)
            Smap(it, ii) = mean(S(mask), 'omitnan');
        end
    end
end
end

function results = reconstructBarrierDistribution(temps, currents, SmapRaw, cfg)
nT = numel(temps);
nI = numel(currents);

S_norm = NaN(nT, nI);
S_smooth = NaN(nT, nI);
dS_dI_raw = NaN(nT, nI);
dS_dI_positive = NaN(nT, nI);
PT = NaN(nT, nI);
CDF_recon = NaN(nT, nI);

meanI = NaN(nT, 1);
stdI = NaN(nT, 1);
skewI = NaN(nT, 1);
cdfRMSE = NaN(nT, 1);
ptArea = NaN(nT, 1);

Iaxis = currents(:).';
for it = 1:nT
    sRow = SmapRaw(it, :);
    valid = isfinite(Iaxis) & isfinite(sRow);
    if nnz(valid) < cfg.minPointsPerTemperature
        continue;
    end

    I = Iaxis(valid);
    S = sRow(valid);

    sMin = min(S);
    sMax = max(S);
    if ~(isfinite(sMin) && isfinite(sMax) && sMax > sMin)
        continue;
    end

    sNorm = (S - sMin) ./ (sMax - sMin);

    sSmooth = smoothMinimal(sNorm, cfg.smoothingWindow, cfg.smoothingMethod);
    sSmooth = min(max(sSmooth, 0), 1);

    if cfg.enforceMonotoneCDF
        sSmooth = enforceMonotoneNondecreasing(sSmooth);
    end

    d = gradient(sSmooth, I);
    p = max(d, 0);
    area = trapz(I, p);
    if ~(isfinite(area) && area > 0)
        continue;
    end
    p = p ./ area;

    cdf = cumtrapz(I, p);
    cdf = cdf ./ max(cdf, eps);

    mu = trapz(I, I .* p);
    varI = trapz(I, ((I - mu) .^ 2) .* p);
    sigma = sqrt(max(varI, 0));

    S_norm(it, valid) = sNorm;
    S_smooth(it, valid) = sSmooth;
    dS_dI_raw(it, valid) = d;
    dS_dI_positive(it, valid) = p .* area;
    PT(it, valid) = p;
    CDF_recon(it, valid) = cdf;

    meanI(it) = mu;
    stdI(it) = sigma;
    ptArea(it) = trapz(I, p);

    if sigma > 0
        z = (I - mu) ./ sigma;
        skewI(it) = trapz(I, (z .^ 3) .* p);
    end

    cdfRMSE(it) = sqrt(mean((cdf - sSmooth) .^ 2, 'omitnan'));
end

summary = struct();
summary.mean_cdf_rmse = mean(cdfRMSE, 'omitnan');
summary.median_cdf_rmse = median(cdfRMSE, 'omitnan');
summary.max_cdf_rmse = max(cdfRMSE, [], 'omitnan');

results = struct();
results.temps = temps(:);
results.currents = currents(:);
results.S_raw = SmapRaw;
results.S_norm = S_norm;
results.S_smooth = S_smooth;
results.dS_dI_raw = dS_dI_raw;
results.dS_dI_positive = dS_dI_positive;
results.PT = PT;
results.CDF_recon = CDF_recon;
results.mean_threshold = meanI;
results.std_threshold = stdI;
results.skew_threshold = skewI;
results.cdf_rmse = cdfRMSE;
results.pt_area = ptArea;
results.summary = summary;
end

function y = smoothMinimal(x, window, method)
x = x(:).';
y = x;

if numel(x) < 3
    return;
end

w = max(3, round(window));
if mod(w, 2) == 0
    w = w + 1;
end
w = min(w, numel(x) - mod(numel(x) + 1, 2));
if w < 3
    w = min(3, numel(x));
end
if w <= 1
    return;
end

switch lower(char(string(method)))
    case 'movmean'
        y = smoothdata(x, 'movmean', w);
    case 'sgolay'
        y = smoothdata(x, 'sgolay', w);
    otherwise
        y = smoothdata(x, 'movmean', w);
end
end

function y = enforceMonotoneNondecreasing(x)
y = x(:).';
for k = 2:numel(y)
    if y(k) < y(k - 1)
        y(k) = y(k - 1);
    end
end
if y(end) > 0
    y = y ./ y(end);
end
end

function tbl = buildPTMatrixTable(temps, currents, PT)
colNames = cell(numel(currents) + 1, 1);
colNames{1} = 'T_K';
for i = 1:numel(currents)
    colNames{i + 1} = matlab.lang.makeValidName(sprintf('Ith_%0.6g_mA', currents(i)));
end

data = [temps(:), PT];
tbl = array2table(data, 'VariableNames', colNames);
end

function tbl = buildPTSummaryTable(results)
tbl = table( ...
    results.temps(:), ...
    results.mean_threshold(:), ...
    results.std_threshold(:), ...
    results.skew_threshold(:), ...
    results.cdf_rmse(:), ...
    results.pt_area(:), ...
    'VariableNames', {'T_K', 'mean_threshold_mA', 'std_threshold_mA', 'skewness', 'cdf_rmse', 'PT_area'});
end

function tbl = buildSourceManifestTable(source)
metric = source.signalMetric;
if strlength(metric) == 0
    metric = "unknown";
end

tbl = table( ...
    repmat(string(source.sourceRunId), 2, 1), ...
    string({'switching_alignment_samples'; 'switching_alignment_core'}), ...
    string({char(source.samplesPath); char(source.corePath)}), ...
    repmat(string(source.loadedFrom), 2, 1), ...
    repmat(metric, 2, 1), ...
    'VariableNames', {'source_run_id', 'asset_role', 'asset_path', 'loaded_from', 'signal_metric'});
end

function figPaths = saveSMapFigure(results, runDir, baseName)
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Position', [2 2 14 10]);
ax = axes(fig);

imagesc(ax, results.currents, results.temps, results.S_norm);
axis(ax, 'xy');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'S_{norm}(I,T)';

xlabel(ax, 'Current I (mA)');
ylabel(ax, 'Temperature T (K)');
title(ax, 'Normalized switching map S(I,T)');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPaths = saveDerivativeFigure(results, runDir, baseName)
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Position', [2 2 14 10]);
ax = axes(fig);

imagesc(ax, results.currents, results.temps, results.PT);
axis(ax, 'xy');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'P_T(I_{th}) from positive dS/dI (1/mA)';

xlabel(ax, 'Threshold current I_{th} (mA)');
ylabel(ax, 'Temperature T (K)');
title(ax, 'Reconstructed barrier distribution P_T(I_{th})');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);

figPaths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPaths = saveCDFReconstructionFigure(results, runDir, baseName)
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off');
set(fig, 'Position', [2 2 14 10]);
ax = axes(fig);
hold(ax, 'on');

T = results.temps(:);
I = results.currents(:);
nT = numel(T);
cmap = parula(max(nT, 2));

for it = 1:nT
    sRow = results.S_smooth(it, :);
    cRow = results.CDF_recon(it, :);
    valid = isfinite(I.') & isfinite(sRow) & isfinite(cRow);
    if nnz(valid) < 3
        continue;
    end
    plot(ax, I(valid), sRow(valid), '-', 'Color', cmap(it, :), 'LineWidth', 2.0, 'HandleVisibility', 'off');
    plot(ax, I(valid), cRow(valid), '--', 'Color', cmap(it, :), 'LineWidth', 2.0, 'HandleVisibility', 'off');
end

h1 = plot(ax, NaN, NaN, '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 2.4, 'DisplayName', 'Original S_{norm}(I,T)');
h2 = plot(ax, NaN, NaN, '--', 'Color', [0.15 0.15 0.15], 'LineWidth', 2.4, 'DisplayName', 'Reconstructed CDF from P_T');
legend(ax, [h1 h2], 'Location', 'best');

colormap(ax, cmap);
cb = colorbar(ax);
cb.Label.String = 'Temperature T (K)';
if nT > 1
    cb.Ticks = linspace(0, 1, min(6, nT));
    cb.TickLabels = compose('%.0f', linspace(min(T), max(T), min(6, nT)));
else
    cb.Ticks = 0.5;
    cb.TickLabels = compose('%.0f', T);
end

xlabel(ax, 'Current I (mA)');
ylabel(ax, 'CDF value');
title(ax, 'Original normalized S(I,T) vs reconstructed CDF(P_T)');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
grid(ax, 'on');

hold(ax, 'off');
figPaths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function reportText = buildReportText(results, source, cfg, ptMatrixPath, ptSummaryPath)
validRMSE = results.cdf_rmse(isfinite(results.cdf_rmse));
if isempty(validRMSE)
    rmseText = 'No finite CDF reconstruction RMSE values were available.';
else
    rmseText = sprintf('CDF reconstruction RMSE (mean/median/max): %.6g / %.6g / %.6g.', ...
        results.summary.mean_cdf_rmse, results.summary.median_cdf_rmse, results.summary.max_cdf_rmse);
end

lines = strings(0, 1);
lines(end + 1) = '# Switching barrier distribution from map';
lines(end + 1) = '';
lines(end + 1) = '## Goal';
lines(end + 1) = 'Reconstruct an effective threshold/barrier distribution `P_T(I_{th})` from saved switching `S(I,T)` using physically interpretable derived transformations only.';
lines(end + 1) = '';
lines(end + 1) = '## Inputs';
lines(end + 1) = sprintf('- Source run: `%s`.', source.sourceRunId);
lines(end + 1) = sprintf('- Loaded map source: `%s`.', source.loadedFrom);
lines(end + 1) = sprintf('- Saved samples path: `%s`.', char(source.samplesPath));
lines(end + 1) = sprintf('- Saved core-map path: `%s`.', char(source.corePath));
lines(end + 1) = '';
lines(end + 1) = '## Method';
lines(end + 1) = '1. Load saved `S(I,T)` map from canonical switching run artifacts.';
lines(end + 1) = '2. Normalize each temperature slice to `[0,1]`.';
lines(end + 1) = sprintf('3. Apply minimal smoothing (`%s`, window=%d) before derivative.', char(string(cfg.smoothingMethod)), cfg.smoothingWindow);
lines(end + 1) = '4. Compute numerical derivative `dS/dI` as a proxy for `P_T(I_{th})`.';
lines(end + 1) = '5. Enforce positivity and normalize by area to obtain a probability distribution.';
lines(end + 1) = '6. Reconstruct CDF via cumulative integration and compare against normalized switching curve.';
lines(end + 1) = '';
lines(end + 1) = '## Outputs';
lines(end + 1) = sprintf('- `%s`', ptMatrixPath);
lines(end + 1) = sprintf('- `%s`', ptSummaryPath);
lines(end + 1) = '- `figures/switching_map_S_I_T.png`';
lines(end + 1) = '- `figures/switching_map_dS_dI.png`';
lines(end + 1) = '- `figures/switching_cdf_reconstruction_vs_original.png`';
lines(end + 1) = '';
lines(end + 1) = '## Reconstruction quality';
lines(end + 1) = ['- ' rmseText];
lines(end + 1) = '';
lines(end + 1) = '## Constraints check';
lines(end + 1) = '- Raw switching extraction code was not modified.';
lines(end + 1) = '- `X(T)` was not recomputed or used in this workflow.';
lines(end + 1) = '- Analysis used only derived run data (`switching_alignment_core_data.mat` / `switching_alignment_samples.csv`).';
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- number of curves: heatmaps for `S(I,T)` and `P_T(I_th,T)`; reconstruction panel overlays many temperature slices.';
lines(end + 1) = '- legend vs colormap: reconstruction panel uses line-style legend (original vs reconstructed) plus colormap/colorbar for temperature indexing.';
lines(end + 1) = '- colormap used: `parula`.';
lines(end + 1) = sprintf('- smoothing applied: `%s` with window `%d` per temperature before derivative.', char(string(cfg.smoothingMethod)), cfg.smoothingWindow);
lines(end + 1) = '- justification: minimal denoising stabilizes derivative while preserving physically interpretable threshold-shape trends.';

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
    p = fullfile(runDir, required{i});
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end
end

function value = setDefault(s, fieldName, defaultValue)
if isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s;
else
    s.(fieldName) = defaultValue;
    value = s;
end
end

function requireField(s, fieldName, pathLabel)
if ~isfield(s, fieldName)
    error('switching_barrier_distribution_from_map:MissingField', 'Missing field "%s" in %s', fieldName, pathLabel);
end
end

function values = readNumericColumn(tbl, name)
assert(any(strcmp(tbl.Properties.VariableNames, name)), 'Missing required column "%s".', name);
values = tbl.(name);
if iscell(values) || isstring(values) || iscategorical(values)
    values = str2double(string(values));
else
    values = double(values);
end
values = values(:);
end

function appendLog(pathText, lineText)
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
