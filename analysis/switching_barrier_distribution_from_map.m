function out = switching_barrier_distribution_from_map(cfg)
% switching_barrier_distribution_from_map
% Estimate an effective switching-threshold distribution from a saved
% switching map S(I,T) by taking dS/dI at each temperature.
%
% Outputs (default: active run dir if available, otherwise tmp debug path):
%   barrier_distribution_series.csv
%   barrier_distribution_plots.png
%   barrier_distribution_report.md

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg, repoRoot);
cfg.outputDir = resolveOutputDir(cfg, repoRoot);
source = resolveSwitchingSource(cfg, repoRoot);
[temps, currents, Smap, source] = loadSwitchingMap(source);

results = computeDistributionSeries(temps, currents, Smap);
writeOutputs(results, cfg, source);

out = struct();
out.source = source;
out.temps = results.temps;
out.currents = results.currents;
out.dS_dI = results.dS_dI;
out.pdf = results.pdf;
out.seriesTable = results.seriesTable;
out.output = struct( ...
    'csv', string(fullfile(cfg.outputDir, 'barrier_distribution_series.csv')), ...
    'plot', string(fullfile(cfg.outputDir, 'barrier_distribution_plots.png')), ...
    'report', string(fullfile(cfg.outputDir, 'barrier_distribution_report.md')));
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefaultField(cfg, 'switchRunDir', "");
cfg = setDefaultField(cfg, 'switchRunName', "");
cfg = setDefaultField(cfg, 'switchLabelHint', "alignment_audit");
cfg = setDefaultField(cfg, 'outputDir', "");
cfg = setDefaultField(cfg, 'usePositiveDerivativeOnly', true);
end

function outputDir = resolveOutputDir(cfg, repoRoot)
if strlength(string(cfg.outputDir)) > 0
    outputDir = char(string(cfg.outputDir));
    return;
end

% Prefer active run output directory when a run context exists.
if exist('getRunOutputDir', 'file') == 2
    try
        runOutputDir = getRunOutputDir();
        if exist(runOutputDir, 'dir') == 7
            outputDir = runOutputDir;
            return;
        end
    catch
        % Fall back to debug output path when no active run context exists.
    end
end

stamp = char(datetime('now', 'Format', 'yyyy_MM_dd_HHmmss'));
preferred = fullfile(repoRoot, 'tmp', 'debug_outputs', 'switching_barrier_distribution_from_map', stamp);
fallback = fullfile(repoRoot, 'tmp_debug_outputs', 'switching_barrier_distribution_from_map', stamp);

try
    if exist(preferred, 'dir') ~= 7
        mkdir(preferred);
    end
    outputDir = preferred;
catch
    if exist(fallback, 'dir') ~= 7
        mkdir(fallback);
    end
    outputDir = fallback;
end
end
function source = resolveSwitchingSource(cfg, repoRoot)
if strlength(string(cfg.switchRunDir)) > 0
    runDir = char(string(cfg.switchRunDir));
elseif strlength(string(cfg.switchRunName)) > 0
    runDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(string(cfg.switchRunName)));
else
    runDir = findLatestSwitchingRunWithMap(repoRoot, string(cfg.switchLabelHint));
end

if exist(runDir, 'dir') ~= 7
    error('switching_barrier_distribution_from_map:MissingRunDir', ...
        'Switching run directory not found: %s', runDir);
end

source = struct();
source.switchRunDir = string(runDir);
source.switchRunName = string(extractAfter(runDir, [filesep 'runs' filesep]));
source.corePath = string(fullfile(runDir, 'switching_alignment_core_data.mat'));
source.samplesPath = string(fullfile(runDir, 'alignment_audit', 'switching_alignment_samples.csv'));
if exist(char(source.samplesPath), 'file') ~= 2
    source.samplesPath = string(fullfile(runDir, 'switching_alignment_samples.csv'));
end
source.loadedFrom = "";
source.metricType = "";
end

function runDir = findLatestSwitchingRunWithMap(repoRoot, labelHint)
runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('switching_barrier_distribution_from_map:NoRuns', ...
        'No switching runs found under %s', runsRoot);
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

error('switching_barrier_distribution_from_map:NoMatchingRun', ...
    'No switching run with map data matched the requested criteria.');
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
        source.metricType = string(core.metricType);
    end
    source.loadedFrom = "switching_alignment_core_data.mat";
elseif exist(char(source.samplesPath), 'file') == 2
    samplesTbl = readtable(char(source.samplesPath));
    [temps, currents, Smap] = buildSwitchingMapRounded(samplesTbl);
    temps = double(temps(:));
    currents = double(currents(:));
    Smap = double(Smap);
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

function results = computeDistributionSeries(temps, currents, Smap)
nT = numel(temps);
nI = numel(currents);

dS_dI = NaN(nT, nI);
pdf = NaN(nT, nI);

meanThreshold = NaN(nT, 1);
stdThreshold = NaN(nT, 1);
skewnessThreshold = NaN(nT, 1);
kurtosisThreshold = NaN(nT, 1);
areaRaw = NaN(nT, 1);
areaPositive = NaN(nT, 1);

for it = 1:nT
    row = Smap(it, :);
    row = row(:)';
    Iaxis = currents(:)';
    valid = isfinite(Iaxis) & isfinite(row);
    if nnz(valid) < 3
        continue;
    end

    I = Iaxis(valid);
    S = row(valid);
    d = gradient(S, I);

    dFull = NaN(1, nI);
    dFull(valid) = d;
    dS_dI(it, :) = dFull;

    p = max(d, 0);
    aRaw = trapz(I, d);
    aPos = trapz(I, p);
    areaRaw(it) = aRaw;
    areaPositive(it) = aPos;

    if ~(isfinite(aPos) && aPos > 0)
        continue;
    end

    p = p ./ aPos;

    pFull = NaN(1, nI);
    pFull(valid) = p;
    pdf(it, :) = pFull;

    mu = trapz(I, I .* p);
    varI = trapz(I, ((I - mu) .^ 2) .* p);
    sigma = sqrt(max(varI, 0));

    meanThreshold(it) = mu;
    stdThreshold(it) = sigma;

    if sigma > 0
        z = (I - mu) ./ sigma;
        skewnessThreshold(it) = trapz(I, (z .^ 3) .* p);
        kurtosisThreshold(it) = trapz(I, (z .^ 4) .* p);
    end
end

seriesTable = table( ...
    temps(:), meanThreshold(:), stdThreshold(:), skewnessThreshold(:), kurtosisThreshold(:), ...
    areaRaw(:), areaPositive(:), ...
    repmat(min(currents), nT, 1), repmat(max(currents), nT, 1), ...
    'VariableNames', {'T_K','mean_threshold_mA','std_threshold_mA','skewness','kurtosis','integral_dS_dI','integral_positive_dS_dI','current_min_mA','current_max_mA'});

results = struct();
results.temps = temps;
results.currents = currents;
results.dS_dI = dS_dI;
results.pdf = pdf;
results.seriesTable = seriesTable;
end

function writeOutputs(results, cfg, source)
outDir = char(string(cfg.outputDir));
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

csvPath = fullfile(outDir, 'barrier_distribution_series.csv');
plotPath = fullfile(outDir, 'barrier_distribution_plots.png');
reportPath = fullfile(outDir, 'barrier_distribution_report.md');

writetable(results.seriesTable, csvPath);
makePlots(results, plotPath);
writeReport(results, source, cfg, reportPath, csvPath, plotPath);
end

function makePlots(results, plotPath)
T = results.temps;
I = results.currents;
S = results.seriesTable;

fh = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 1200 900]);
tl = tiledlayout(fh, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
plot(ax1, T, S.mean_threshold_mA, '-o', 'LineWidth', 1.8, 'MarkerSize', 5);
grid(ax1, 'on');
xlabel(ax1, 'T (K)');
ylabel(ax1, 'Mean threshold (mA)');
title(ax1, 'Mean threshold vs temperature');

ax2 = nexttile(tl, 2);
plot(ax2, T, S.std_threshold_mA, '-o', 'LineWidth', 1.8, 'MarkerSize', 5);
grid(ax2, 'on');
xlabel(ax2, 'T (K)');
ylabel(ax2, 'Std threshold (mA)');
title(ax2, 'Width vs temperature');

ax3 = nexttile(tl, 3);
plot(ax3, T, S.skewness, '-o', 'LineWidth', 1.8, 'MarkerSize', 5);
grid(ax3, 'on');
xlabel(ax3, 'T (K)');
ylabel(ax3, 'Skewness');
title(ax3, 'Skewness vs temperature');

ax4 = nexttile(tl, 4);
plot(ax4, T, S.kurtosis, '-o', 'LineWidth', 1.8, 'MarkerSize', 5);
grid(ax4, 'on');
xlabel(ax4, 'T (K)');
ylabel(ax4, 'Kurtosis');
title(ax4, 'Kurtosis vs temperature');

ax5 = nexttile(tl, [1 2]);
imagesc(ax5, I, T, results.pdf);
axis(ax5, 'xy');
cb = colorbar(ax5);
ylabel(cb, 'p(I|T) from positive dS/dI');
xlabel(ax5, 'Current I (mA)');
ylabel(ax5, 'Temperature T (K)');
title(ax5, 'Effective threshold distribution p(I|T)');

title(tl, 'Barrier distribution moments derived from dS/dI');

exportgraphics(fh, plotPath, 'Resolution', 200);
close(fh);
end

function writeReport(results, source, cfg, reportPath, csvPath, plotPath)
S = results.seriesTable;
validMask = isfinite(S.mean_threshold_mA) & isfinite(S.std_threshold_mA) & isfinite(S.skewness) & isfinite(S.kurtosis);

nTotal = height(S);
nValid = nnz(validMask);

lines = strings(0, 1);
lines(end + 1) = "# Barrier Distribution Report";
lines(end + 1) = "";
lines(end + 1) = "## Goal";
lines(end + 1) = "Estimate an effective switching-threshold distribution from a saved switching map using dS/dI at each temperature.";
lines(end + 1) = "";
lines(end + 1) = "## Inputs Reused";
lines(end + 1) = sprintf('- Switching run directory: `%s`.', char(source.switchRunDir));
lines(end + 1) = sprintf('- Map source file used: `%s`.', char(source.loadedFrom));
if strlength(source.metricType) > 0
    lines(end + 1) = sprintf('- Signal metric type from source: `%s`.', char(source.metricType));
end
lines(end + 1) = "";
lines(end + 1) = "## Method";
lines(end + 1) = "1. Load S(I,T) from saved switching-map data.";
lines(end + 1) = "2. For each temperature row, compute dS/dI on the current axis with finite differences.";
lines(end + 1) = "3. Interpret positive dS/dI as an effective threshold density and normalize by its area.";
lines(end + 1) = "4. Compute weighted moments over current: mean, standard deviation, skewness, and kurtosis.";
lines(end + 1) = "";
lines(end + 1) = "## Coverage";
lines(end + 1) = sprintf('- Temperatures with finite all-moment estimates: %d / %d.', nValid, nTotal);
lines(end + 1) = sprintf('- Current range used: %.6g to %.6g mA.', min(results.currents), max(results.currents));
lines(end + 1) = "";
lines(end + 1) = "## Output Files";
lines(end + 1) = sprintf('- `%s`', csvPath);
lines(end + 1) = sprintf('- `%s`', plotPath);
lines(end + 1) = sprintf('- `%s`', reportPath);
lines(end + 1) = "";
lines(end + 1) = "## Notes";
lines(end + 1) = "- The distribution is an effective proxy derived from slope along current, not a direct microscopic barrier histogram.";
lines(end + 1) = "- Negative derivative regions were clipped to zero before normalization to avoid non-probabilistic weights.";
lines(end + 1) = sprintf('- Output directory: `%s`.', char(string(cfg.outputDir)));

fid = fopen(reportPath, 'w');
if fid < 0
    error('switching_barrier_distribution_from_map:ReportWriteFailed', ...
        'Failed to write report: %s', reportPath);
end
cleanupObj = onCleanup(@() fclose(fid));
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines(i));
end
clear cleanupObj;
end

function value = setDefaultField(s, fieldName, defaultValue)
if isfield(s, fieldName)
    value = s;
else
    s.(fieldName) = defaultValue;
    value = s;
end
end

function requireField(s, fieldName, pathLabel)
if ~isfield(s, fieldName)
    error('switching_barrier_distribution_from_map:MissingField', ...
        'Missing field "%s" in %s', fieldName, pathLabel);
end
end

function [temps, currents, Smap] = buildSwitchingMapRounded(samplesTbl)
tempsRaw = readNumericColumn(samplesTbl, 'T_K');
currentsRaw = readNumericColumn(samplesTbl, 'current_mA');
signalRaw = readNumericColumn(samplesTbl, 'S_percent');

tempsUnique = unique(tempsRaw(isfinite(tempsRaw)));
currents = unique(currentsRaw(isfinite(currentsRaw)));
tempsUnique = sort(tempsUnique(:));
currents = sort(currents(:));

SmapRaw = NaN(numel(tempsUnique), numel(currents));
for it = 1:numel(tempsUnique)
    for ii = 1:numel(currents)
        mask = abs(tempsRaw - tempsUnique(it)) < 1e-9 & abs(currentsRaw - currents(ii)) < 1e-9;
        if any(mask)
            SmapRaw(it, ii) = mean(signalRaw(mask), 'omitnan');
        end
    end
end

tempsRounded = round(tempsUnique);
[temps, ~, roundedIdx] = unique(tempsRounded, 'sorted');
Smap = NaN(numel(temps), numel(currents));
for k = 1:numel(temps)
    mask = roundedIdx == k;
    Smap(k, :) = mean(SmapRaw(mask, :), 1, 'omitnan');
end

temps = temps(:);
currents = currents(:)';
end

function values = readNumericColumn(tbl, name)
assert(any(strcmp(tbl.Properties.VariableNames, name)), ...
    'Missing required column "%s".', name);
values = tbl.(name);
if iscell(values) || isstring(values) || iscategorical(values)
    values = str2double(string(values));
else
    values = double(values);
end
values = values(:);
end


