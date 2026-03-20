function out = creep_activation_scaling(cfg)
% creep_activation_scaling
% Test activated creep-like scaling for existing relaxation and aging timescales
% using saved run tables only.

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
runCfg.dataset = sprintf('dip:%s | fm:%s | relax:%s', ...
    char(source.dipRunName), char(source.fmRunName), char(source.relaxRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

appendLog(run.log_path, sprintf('[%s] creep_activation_scaling started', stampNow()));
appendLog(run.log_path, sprintf('Dip source: %s', source.dipPath));
appendLog(run.log_path, sprintf('FM source: %s', source.fmPath));
appendLog(run.log_path, sprintf('Relax source: %s', source.relaxPath));
appendLog(run.log_path, sprintf('Relax global source: %s', source.relaxGlobalPath));

data = loadAndAlignData(source);
fits = fitAllScalings(data, cfg);

csvTbl = buildOutputTable(data, fits, source);
csvPath = save_run_table(csvTbl, 'creep_activation_scaling.csv', runDir);

fig = buildFigure(data, fits);
plotPath = savePlotPng(fig, runDir, 'creep_activation_plots.png');
close(fig);

reportText = buildReport(data, fits, source, runDir);
reportPath = saveReportMd(reportText, runDir, 'creep_activation_report.md');

appendLog(run.log_path, sprintf('Saved CSV: %s', csvPath));
appendLog(run.log_path, sprintf('Saved figure: %s', plotPath));
appendLog(run.log_path, sprintf('Saved report: %s', reportPath));
appendLog(run.log_path, sprintf('[%s] creep_activation_scaling complete', stampNow()));

out = struct();
out.runDir = string(runDir);
out.source = source;
out.data = data;
out.fits = fits;
out.outputs = struct('csv', string(csvPath), 'plot', string(plotPath), 'report', string(reportPath));
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'creep_activation_scaling');
cfg = setDefault(cfg, 'dipHint', 'aging_timescale_extraction');
cfg = setDefault(cfg, 'fmHint', 'aging_fm_timescale_analysis');
cfg = setDefault(cfg, 'relaxHint', 'timelaw_observables');
cfg = setDefault(cfg, 'alphaGrid', (0.25:0.05:3.00));
cfg = setDefault(cfg, 'minPointsForFit', 3);
end

function source = resolveSourceRuns(repoRoot, cfg)
[dipRunDir, dipRunName] = findLatestRunWithFiles(repoRoot, 'aging', {'tables\tau_vs_Tp.csv'}, cfg.dipHint);
[fmRunDir, fmRunName] = findLatestRunWithFiles(repoRoot, 'aging', {'tables\tau_FM_vs_Tp.csv'}, cfg.fmHint);
[relaxRunDir, relaxRunName] = findLatestRunWithFiles(repoRoot, 'relaxation', {'tables\time_fit_results.csv'}, cfg.relaxHint);
[relaxGlobalDir, relaxGlobalName] = findLatestRunWithFiles(repoRoot, 'relaxation', {'tables\observables_relaxation.csv'}, 'relaxation_observable_stability');

source = struct();
source.repoRoot = string(repoRoot);
source.dipRunDir = string(dipRunDir);
source.dipRunName = string(dipRunName);
source.fmRunDir = string(fmRunDir);
source.fmRunName = string(fmRunName);
source.relaxRunDir = string(relaxRunDir);
source.relaxRunName = string(relaxRunName);
source.relaxGlobalRunDir = string(relaxGlobalDir);
source.relaxGlobalRunName = string(relaxGlobalName);
source.dipPath = string(fullfile(dipRunDir, 'tables', 'tau_vs_Tp.csv'));
source.fmPath = string(fullfile(fmRunDir, 'tables', 'tau_FM_vs_Tp.csv'));
source.relaxPath = string(fullfile(relaxRunDir, 'tables', 'time_fit_results.csv'));
source.relaxGlobalPath = string(fullfile(relaxGlobalDir, 'tables', 'observables_relaxation.csv'));
end

function data = loadAndAlignData(source)
dipTbl = readtable(source.dipPath, 'VariableNamingRule', 'preserve');
fmTbl = readtable(source.fmPath, 'VariableNamingRule', 'preserve');
relaxTbl = readtable(source.relaxPath, 'VariableNamingRule', 'preserve');
relaxGlobalTbl = readtable(source.relaxGlobalPath, 'VariableNamingRule', 'preserve');

requireColumns(dipTbl, {'Tp', 'tau_effective_seconds'}, char(source.dipPath));
requireColumns(fmTbl, {'Tp', 'tau_effective_seconds'}, char(source.fmPath));
requireColumns(relaxTbl, {'scope', 'Temp_K', 'Relax_t_half', 'fit_ok'}, char(source.relaxPath));
requireColumns(relaxGlobalTbl, {'Relax_tau_global', 'Relax_t_half'}, char(source.relaxGlobalPath));

[relaxT, relaxTHalf] = extractRelaxTHalfByTemperature(relaxTbl);

dipT = double(dipTbl.Tp(:));
dipTau = double(dipTbl.tau_effective_seconds(:));
fmT = double(fmTbl.Tp(:));
fmTau = double(fmTbl.tau_effective_seconds(:));

allT = unique([dipT(:); fmT(:); relaxT(:)]);
allT = sort(allT(isfinite(allT)));

alignedDip = mapOntoGrid(allT, dipT, dipTau);
alignedFm = mapOntoGrid(allT, fmT, fmTau);
alignedRelax = mapOntoGrid(allT, relaxT, relaxTHalf);

data = struct();
data.T = allT(:);
data.tau_dip_seconds = alignedDip(:);
data.tau_FM_seconds = alignedFm(:);
data.Relax_t_half_seconds = alignedRelax(:);
data.Relax_tau_global = asScalarOrNaN(relaxGlobalTbl.Relax_tau_global);
data.Relax_t_half_global = asScalarOrNaN(relaxGlobalTbl.Relax_t_half);
data.observables = ["tau_dip_seconds", "tau_FM_seconds", "Relax_t_half_seconds"];
end

function [T, tHalf] = extractRelaxTHalfByTemperature(relaxTbl)
scope = string(relaxTbl.scope);
isSlice = strcmpi(scope, 'temperature_slice');
ok = logical(double(relaxTbl.fit_ok) ~= 0);
Traw = double(relaxTbl.Temp_K);
tHalfRaw = double(relaxTbl.Relax_t_half);

mask = isSlice & ok & isfinite(Traw) & isfinite(tHalfRaw) & tHalfRaw > 0;
sliceTbl = table(Traw(mask), tHalfRaw(mask), 'VariableNames', {'T', 'tHalf'});
sliceTbl = sortrows(sliceTbl, 'T');

uT = unique(sliceTbl.T);
tHalf = NaN(size(uT));
for i = 1:numel(uT)
    rows = sliceTbl.T == uT(i);
    tHalf(i) = median(sliceTbl.tHalf(rows), 'omitnan');
end

T = uT(:);
tHalf = tHalf(:);
end

function fits = fitAllScalings(data, cfg)
obsNames = data.observables;
fitRows = repmat(struct( ...
    'observable', "", 'transform', "", 'alpha', NaN, ...
    'slope', NaN, 'intercept', NaN, 'R2', NaN, 'n_points', 0, ...
    'T_min_K', NaN, 'T_max_K', NaN), 0, 1);

for i = 1:numel(obsNames)
    obs = obsNames(i);
    tau = data.(char(obs));
    fitRows(end + 1) = fitSingleTransform(data.T, tau, "invT", NaN, cfg.minPointsForFit, obs); %#ok<AGROW>
    fitRows(end + 1) = fitBestAlphaTransform(data.T, tau, cfg.alphaGrid, cfg.minPointsForFit, obs); %#ok<AGROW>
end

fits = struct();
fits.rows = fitRows;
end

function row = fitSingleTransform(T, tau, transformName, alpha, minPoints, obs)
[x, y, Tused] = buildTransform(T, tau, transformName, alpha);
[slope, intercept, R2, nPts, Tmin, Tmax] = linearFitWithR2(x, y, Tused, minPoints);

row = struct();
row.observable = obs;
row.transform = transformName;
row.alpha = alpha;
row.slope = slope;
row.intercept = intercept;
row.R2 = R2;
row.n_points = nPts;
row.T_min_K = Tmin;
row.T_max_K = Tmax;
end

function bestRow = fitBestAlphaTransform(T, tau, alphaGrid, minPoints, obs)
bestRow = fitSingleTransform(T, tau, "T_neg_alpha", NaN, minPoints, obs);
bestR2 = -Inf;

for a = alphaGrid
    [x, y, Tused] = buildTransform(T, tau, "T_neg_alpha", a);
    [slope, intercept, R2, nPts, Tmin, Tmax] = linearFitWithR2(x, y, Tused, minPoints);
    if nPts >= minPoints && isfinite(R2) && R2 > bestR2
        bestR2 = R2;
        bestRow.observable = obs;
        bestRow.transform = "T_neg_alpha";
        bestRow.alpha = a;
        bestRow.slope = slope;
        bestRow.intercept = intercept;
        bestRow.R2 = R2;
        bestRow.n_points = nPts;
        bestRow.T_min_K = Tmin;
        bestRow.T_max_K = Tmax;
    end
end
end

function [x, y, Tused] = buildTransform(T, tau, transformName, alpha)
T = double(T(:));
tau = double(tau(:));

mask = isfinite(T) & isfinite(tau) & T > 0 & tau > 0;
T = T(mask);
tau = tau(mask);
Tused = T;
y = log(tau);

if strcmpi(transformName, 'invT')
    x = 1 ./ T;
elseif strcmpi(transformName, 'T_neg_alpha')
    if ~isfinite(alpha)
        x = NaN(size(T));
    else
        x = T .^ (-alpha);
    end
else
    error('Unsupported transform: %s', transformName);
end
end

function [slope, intercept, R2, nPts, Tmin, Tmax] = linearFitWithR2(x, y, T, minPoints)
x = double(x(:));
y = double(y(:));
T = double(T(:));

mask = isfinite(x) & isfinite(y) & isfinite(T);
x = x(mask);
y = y(mask);
T = T(mask);
nPts = numel(x);

if nPts < minPoints
    slope = NaN;
    intercept = NaN;
    R2 = NaN;
    Tmin = NaN;
    Tmax = NaN;
    return;
end

p = polyfit(x, y, 1);
yhat = polyval(p, x);
ssRes = sum((y - yhat) .^ 2);
ssTot = sum((y - mean(y)) .^ 2);
if ssTot <= 0
    R2 = NaN;
else
    R2 = 1 - ssRes / ssTot;
end

slope = p(1);
intercept = p(2);
Tmin = min(T);
Tmax = max(T);
end

function tbl = buildOutputTable(data, fits, source)
aligned = buildAlignedRows(data);
fitSummary = buildFitRows(fits, source);
tbl = [aligned; fitSummary];
end

function tbl = buildAlignedRows(data)
obs = data.observables;
N = numel(data.T);
rows = repmat(struct( ...
    'row_type', "aligned_data", ...
    'observable', "", ...
    'transform', "none", ...
    'alpha', NaN, ...
    'T_K', NaN, ...
    'tau_seconds', NaN, ...
    'x_value', NaN, ...
    'y_value', NaN, ...
    'effective_activation_slope', NaN, ...
    'intercept', NaN, ...
    'R2', NaN, ...
    'n_points', NaN, ...
    'source_file', ""), N * numel(obs), 1);

k = 0;
for i = 1:numel(obs)
    tau = data.(char(obs(i)));
    for j = 1:N
        k = k + 1;
        rows(k).observable = obs(i);
        rows(k).T_K = data.T(j);
        rows(k).tau_seconds = tau(j);
        if isfinite(data.T(j)) && data.T(j) > 0 && isfinite(tau(j)) && tau(j) > 0
            rows(k).x_value = 1 / data.T(j);
            rows(k).y_value = log(tau(j));
        end
    end
end

tbl = struct2table(rows);
end

function tbl = buildFitRows(fits, source)
rows = fits.rows;
if isempty(rows)
    tbl = table();
    return;
end

out = repmat(struct( ...
    'row_type', "fit_summary", ...
    'observable', "", ...
    'transform', "", ...
    'alpha', NaN, ...
    'T_K', NaN, ...
    'tau_seconds', NaN, ...
    'x_value', NaN, ...
    'y_value', NaN, ...
    'effective_activation_slope', NaN, ...
    'intercept', NaN, ...
    'R2', NaN, ...
    'n_points', NaN, ...
    'source_file', ""), numel(rows), 1);

for i = 1:numel(rows)
    out(i).observable = rows(i).observable;
    out(i).transform = rows(i).transform;
    out(i).alpha = rows(i).alpha;
    out(i).effective_activation_slope = rows(i).slope;
    out(i).intercept = rows(i).intercept;
    out(i).R2 = rows(i).R2;
    out(i).n_points = rows(i).n_points;
    out(i).source_file = sourcePathForObservable(rows(i).observable, source);
end

tbl = struct2table(out);
end

function p = sourcePathForObservable(obs, source)
if strcmp(obs, "tau_dip_seconds")
    p = source.dipPath;
elseif strcmp(obs, "tau_FM_seconds")
    p = source.fmPath;
elseif strcmp(obs, "Relax_t_half_seconds")
    p = source.relaxPath;
else
    p = "";
end
end

function fig = buildFigure(data, fits)
fig = create_figure('Position', [2 2 20 12]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Activated Creep Scaling: ln(tau) vs 1/T and T^{-alpha}');

obsMeta = {
    "tau_dip_seconds", 'tau_{dip}(T)', [0.10 0.45 0.80];
    "tau_FM_seconds", 'tau_{FM}(T)', [0.85 0.33 0.10];
    "Relax_t_half_seconds", 'Relax t_{1/2}(T)', [0.20 0.60 0.25]};

for i = 1:size(obsMeta, 1)
    obs = obsMeta{i, 1};
    displayName = obsMeta{i, 2};
    c = obsMeta{i, 3};
    tau = data.(char(obs));

    invFit = selectFit(fits.rows, obs, "invT");
    ax1 = nexttile(tl, i);
    plotTransformPanel(ax1, data.T, tau, "invT", NaN, invFit, displayName, c);

    alphaFit = selectFit(fits.rows, obs, "T_neg_alpha");
    ax2 = nexttile(tl, i + 3);
    plotTransformPanel(ax2, data.T, tau, "T_neg_alpha", alphaFit.alpha, alphaFit, displayName, c);
end
end

function plotTransformPanel(ax, T, tau, transformName, alpha, fitRow, displayName, colorValue)
[x, y] = buildTransform(T, tau, transformName, alpha);
plot(ax, x, y, 'o', 'Color', colorValue, 'MarkerFaceColor', colorValue, 'MarkerSize', 5, 'LineStyle', 'none');
hold(ax, 'on');

if isfinite(fitRow.slope) && isfinite(fitRow.intercept)
    xx = linspace(min(x), max(x), 100);
    yy = fitRow.slope .* xx + fitRow.intercept;
    plot(ax, xx, yy, '-', 'Color', [0 0 0], 'LineWidth', 1.1);
end

hold(ax, 'off');
grid(ax, 'on');
set(ax, 'Box', 'off', 'FontSize', 8, 'LineWidth', 1.0, 'TickDir', 'out');

if strcmpi(transformName, 'invT')
    xlabel(ax, '1 / T (K^{-1})');
    title(ax, sprintf('%s: ln(tau) vs 1/T', displayName), 'Interpreter', 'tex');
else
    xlabel(ax, sprintf('T^{-%.2f}', alpha));
    title(ax, sprintf('%s: ln(tau) vs T^{-alpha}', displayName), 'Interpreter', 'tex');
end
ylabel(ax, 'ln(tau / s)');

if isfinite(fitRow.R2)
    txt = sprintf('slope = %.4g\nR^2 = %.4f\nn = %d', fitRow.slope, fitRow.R2, fitRow.n_points);
    text(ax, 0.03, 0.96, txt, 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', 'FontSize', 7, 'BackgroundColor', 'w', 'Margin', 2);
end
end

function row = selectFit(rows, obs, transformName)
row = struct('observable', obs, 'transform', transformName, 'alpha', NaN, ...
    'slope', NaN, 'intercept', NaN, 'R2', NaN, 'n_points', 0, 'T_min_K', NaN, 'T_max_K', NaN);

for i = 1:numel(rows)
    if strcmp(rows(i).observable, obs) && strcmp(rows(i).transform, transformName)
        row = rows(i);
        return;
    end
end
end

function textOut = buildReport(data, fits, source, runDir)
lines = strings(0, 1);
lines(end + 1) = "# Creep Activation Scaling";
lines(end + 1) = "";
lines(end + 1) = "## Goal";
lines(end + 1) = "Test whether relaxation and aging timescales follow activated creep-like scaling using existing saved tables only.";
lines(end + 1) = "";
lines(end + 1) = "## Source Tables Reused";
lines(end + 1) = "- tau_dip(T): `" + source.dipPath + "`";
lines(end + 1) = "- tau_FM(T): `" + source.fmPath + "`";
lines(end + 1) = "- Relax_t_half(T): `" + source.relaxPath + "` (scope=`temperature_slice`)";
lines(end + 1) = "- Relax global reference (`Relax_tau_global`, `Relax_t_half`): `" + source.relaxGlobalPath + "`";
lines(end + 1) = "";
lines(end + 1) = "## Temperature-Aligned Dataset";
lines(end + 1) = sprintf('- Unified temperature grid points: %d', numel(data.T));
lines(end + 1) = sprintf('- tau_dip valid points: %d', nnz(isfinite(data.tau_dip_seconds) & data.tau_dip_seconds > 0));
lines(end + 1) = sprintf('- tau_FM valid points: %d', nnz(isfinite(data.tau_FM_seconds) & data.tau_FM_seconds > 0));
lines(end + 1) = sprintf('- Relax_t_half(T) valid points: %d', nnz(isfinite(data.Relax_t_half_seconds) & data.Relax_t_half_seconds > 0));
lines(end + 1) = "";
lines(end + 1) = "## Fit Results";

for i = 1:numel(fits.rows)
    r = fits.rows(i);
    if strcmp(r.transform, "invT")
        modelName = "ln(tau) vs 1/T";
    else
        modelName = "ln(tau) vs T^{-alpha_best}";
    end
    lines(end + 1) = sprintf('- %s | %s: slope = %.6g, intercept = %.6g, R^2 = %.6f, n = %d, alpha = %.3f', ...
        r.observable, modelName, r.slope, r.intercept, r.R2, r.n_points, r.alpha);
end

lines(end + 1) = "";
lines(end + 1) = "## Effective Activation Slopes";
lines(end + 1) = "The effective activation slope is reported as the fitted linear slope in each transformed coordinate.";
lines(end + 1) = "";
lines(end + 1) = "## Outputs";
lines(end + 1) = "- `tables/creep_activation_scaling.csv`";
lines(end + 1) = "- `figures/creep_activation_plots.png`";
lines(end + 1) = "- `reports/creep_activation_report.md`";
lines(end + 1) = "";
lines(end + 1) = "## Run Directory";
lines(end + 1) = "`" + string(runDir) + "`";

textOut = strjoin(lines, newline);
end

function [runDir, runName] = findLatestRunWithFiles(repoRoot, experiment, requiredFiles, labelHint)
runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
assert(exist(runsRoot, 'dir') == 7, 'Missing runs directory: %s', runsRoot);

d = dir(fullfile(runsRoot, 'run_*'));
d = d([d.isdir]);
if isempty(d)
    error('No run directories found in %s', runsRoot);
end

names = string({d.name});
if nargin >= 4 && strlength(string(labelHint)) > 0
    hint = lower(string(labelHint));
    keep = contains(lower(names), hint);
    if any(keep)
        d = d(keep);
        names = string({d.name});
    end
end

[~, order] = sort(names, 'descend');
d = d(order);

for i = 1:numel(d)
    candidate = fullfile(runsRoot, d(i).name);
    allPresent = true;
    for j = 1:numel(requiredFiles)
        if exist(fullfile(candidate, requiredFiles{j}), 'file') ~= 2
            allPresent = false;
            break;
        end
    end
    if allPresent
        runDir = candidate;
        runName = d(i).name;
        return;
    end
end

error('No %s run satisfies required files: %s', experiment, strjoin(requiredFiles, ', '));
end

function y = mapOntoGrid(gridT, srcT, srcV)
gridT = double(gridT(:));
srcT = double(srcT(:));
srcV = double(srcV(:));
y = NaN(size(gridT));

for i = 1:numel(gridT)
    m = srcT == gridT(i);
    if any(m)
        y(i) = median(srcV(m), 'omitnan');
    end
end
end

function requireColumns(tbl, cols, tablePath)
missing = cols(~ismember(cols, tbl.Properties.VariableNames));
if ~isempty(missing)
    error('Missing columns in %s: %s', tablePath, strjoin(missing, ', '));
end
end

function v = asScalarOrNaN(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = x(1);
end
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end

function appendLog(path, lineText)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', lineText);
end

function outPath = savePlotPng(fig, runDir, fileName)
figuresDir = fullfile(runDir, 'figures');
if exist(figuresDir, 'dir') ~= 7
    mkdir(figuresDir);
end
outPath = fullfile(figuresDir, fileName);
set(fig, 'Color', 'w');
exportgraphics(fig, outPath, 'Resolution', 300);
end

function outPath = saveReportMd(reportText, runDir, fileName)
reportsDir = fullfile(runDir, 'reports');
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end
outPath = fullfile(reportsDir, fileName);
fid = fopen(outPath, 'w', 'n', 'UTF-8');
if fid < 0
    error('Could not write report: %s', outPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', reportText);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end