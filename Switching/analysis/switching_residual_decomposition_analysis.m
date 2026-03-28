function out = switching_residual_decomposition_analysis(cfg)
% switching_residual_decomposition_analysis
% Decompose switching response into active CDF part and residual rigidity part:
%   S(I,T) = S0(T)*CDF(P_T) + kappa(T)*Phi((I-I_peak)/w)
%
% Main interpretation is restricted to canonical window T <= 30 K.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);
source = resolveSourcePaths(repoRoot, cfg);

datasetStr = sprintf('alignment:%s | full_scaling:%s | PT:%s', ...
    char(source.alignmentRunId), char(source.fullScalingRunId), char(source.ptDescriptor));
if isfield(cfg, 'run') && isstruct(cfg.run) && isfield(cfg.run, 'run_id')
    cfg.run.experiment = 'switching';
    if ~isfield(cfg.run, 'repo_root') || isempty(cfg.run.repo_root)
        cfg.run.repo_root = repoRoot;
    end
    run = createRunContext('switching', cfg);
else
    runCfg = struct();
    runCfg.runLabel = cfg.runLabel;
    runCfg.dataset = datasetStr;
    run = createRunContext('switching', runCfg);
end
runDir = run.run_dir;

fprintf('Switching residual decomposition run directory:\n%s\n', runDir);
fprintf('Alignment source run: %s\n', source.alignmentRunId);
fprintf('Full-scaling source run: %s\n', source.fullScalingRunId);
fprintf('PT source: %s\n', source.ptDescriptor);

appendText(run.log_path, sprintf('[%s] switching residual decomposition started\n', stampNow()));
appendText(run.log_path, sprintf('Alignment source: %s\n', char(source.alignmentRunId)));
appendText(run.log_path, sprintf('Full-scaling source: %s\n', char(source.fullScalingRunId)));
appendText(run.log_path, sprintf('PT source: %s\n', char(source.ptDescriptor)));

core = load(source.alignmentCorePath, 'Smap', 'temps', 'currents');
paramsTbl = readtable(source.fullScalingParamsPath);

[SmapAll, tempsAll, currents] = orientAndSortMap(core.Smap, core.temps(:), core.currents(:));
[tempsScale, IpeakScale, SpeakScale, widthScale] = extractScalingColumns(paramsTbl);

[tempsCommon, iMap, iScale] = intersect(tempsAll, tempsScale, 'stable');
assert(~isempty(tempsCommon), 'No common temperatures between map and scaling parameters.');

Smap = SmapAll(iMap, :);
Ipeak = IpeakScale(iScale);
Speak = SpeakScale(iScale);
width = widthScale(iScale);

valid = isfinite(tempsCommon) & isfinite(Ipeak) & isfinite(Speak) & isfinite(width);
valid = valid & (width > 0);
valid = valid & (Speak > cfg.speakFloorFraction * max(Speak, [], 'omitnan'));

temps = tempsCommon(valid);
Smap = Smap(valid, :);
Ipeak = Ipeak(valid);
Speak = Speak(valid);
width = width(valid);

assert(numel(temps) >= cfg.minRowsForDecomposition, ...
    'Too few valid rows for decomposition after filtering.');

ptData = loadPTData(source.ptMatrixPath);
if ptData.available
    cdfMethod = "PT_matrix_reconstruction";
else
    cdfMethod = "rowwise_derivative_fallback";
end

[Scdf, cdfDiagnostics] = buildCdfModel(Smap, currents, temps, Speak, ptData, cfg);
deltaS = Smap - Scdf;

Xrows = NaN(size(deltaS));
for it = 1:numel(temps)
    Xrows(it, :) = (currents(:)' - Ipeak(it)) ./ width(it);
end

lowMask = temps <= cfg.canonicalMaxTemperatureK;
assert(nnz(lowMask) >= cfg.minRowsForDecomposition, ...
    'Canonical window T<=%.1f K has too few rows.', cfg.canonicalMaxTemperatureK);

xGrid = buildCommonXGrid(Xrows(lowMask, :), cfg.nXGrid);
Rlow = interpolateRowsToGrid(Xrows(lowMask, :), deltaS(lowMask, :), xGrid);
Rall = interpolateRowsToGrid(Xrows, deltaS, xGrid);

[phi, svInfo] = extractShapeMode(Rlow, cfg.maxModes);
kappaAll = fitKappa(Rall, phi);

RhatAll = kappaAll * phi';
RhatLow = RhatAll(lowMask, :);
quality = evaluateQuality(Rlow, RhatLow, svInfo);

phiTbl = table(xGrid, phi, 'VariableNames', {'x', 'Phi'});
phiPath = save_run_table(phiTbl, 'phi_shape.csv', runDir);

kappaTbl = table(temps, kappaAll, 'VariableNames', {'T', 'kappa'});
kappaPath = save_run_table(kappaTbl, 'kappa_vs_T.csv', runDir);

sourceTbl = table( ...
    ["alignment_core_map"; "full_scaling_parameters"; "pt_matrix"], ...
    [source.alignmentRunId; source.fullScalingRunId; source.ptRunId], ...
    string({source.alignmentCorePath; source.fullScalingParamsPath; source.ptMatrixPath}), ...
    [string(cdfMethod); string(cdfMethod); string(cdfMethod)], ...
    'VariableNames', {'source_role', 'source_run_id', 'source_file', 'cdf_model_method'});
sourcePath = save_run_table(sourceTbl, 'residual_decomposition_sources.csv', runDir);

qualityTbl = table( ...
    quality.rank1EnergyFraction, quality.rank12EnergyFraction, quality.dominanceRatio12, ...
    quality.lowWindowNRows, quality.lowWindowRmse, quality.lowWindowRelError, ...
    quality.lowWindowMedianCurveCorr, quality.lowWindowP10CurveCorr, ...
    cdfDiagnostics.ptRowsUsed, cdfDiagnostics.fallbackRowsUsed, ...
    'VariableNames', {'rank1_energy_fraction', 'rank12_energy_fraction', 'dominance_ratio_1_over_2', ...
    'low_window_rows', 'low_window_rmse', 'low_window_relative_error', ...
    'low_window_median_curve_corr', 'low_window_p10_curve_corr', ...
    'cdf_rows_from_pt', 'cdf_rows_from_fallback'});
qualityPath = save_run_table(qualityTbl, 'residual_decomposition_quality.csv', runDir);

if isfield(cfg, 'skipFigures') && cfg.skipFigures
    emptyFig = struct('png', "", 'pdf', "", 'fig', "");
    figCollapsePath = emptyFig;
    figPhiPath = emptyFig;
    figKappaPath = emptyFig;
    figReconPath = emptyFig;
    reportText = buildReportText(source, cfg, cdfMethod, quality, cdfDiagnostics, ...
        phiPath, kappaPath, qualityPath, sourcePath, ...
        figCollapsePath, figPhiPath, figKappaPath, figReconPath);
    reportPath = save_run_report(reportText, 'residual_decomposition_report.md', runDir);
    zipPath = "";
else
    figCollapsePath = makeResidualCollapseFigure(temps(lowMask), Rlow, xGrid, cfg, runDir);
    figPhiPath = makePhiFigure(xGrid, phi, runDir);
    figKappaPath = makeKappaFigure(temps, kappaAll, cfg, runDir);
    figReconPath = makeReconstructionFigure(temps(lowMask), xGrid, Rlow, RhatLow, runDir);

    reportText = buildReportText(source, cfg, cdfMethod, quality, cdfDiagnostics, ...
        phiPath, kappaPath, qualityPath, sourcePath, ...
        figCollapsePath, figPhiPath, figKappaPath, figReconPath);
    reportPath = save_run_report(reportText, 'residual_decomposition_report.md', runDir);

    zipPath = buildReviewZip(runDir, 'switching_residual_decomposition_bundle.zip');
end

appendText(run.notes_path, sprintf('Canonical interpretation window: T <= %.1f K\n', cfg.canonicalMaxTemperatureK));
appendText(run.notes_path, sprintf('CDF model method: %s\n', char(cdfMethod)));
appendText(run.notes_path, sprintf('rank1 energy fraction (low-T): %.6f\n', quality.rank1EnergyFraction));
appendText(run.notes_path, sprintf('rank1+2 energy fraction (low-T): %.6f\n', quality.rank12EnergyFraction));
appendText(run.notes_path, sprintf('low-T median curve corr: %.6f\n', quality.lowWindowMedianCurveCorr));

appendText(run.log_path, sprintf('[%s] switching residual decomposition complete\n', stampNow()));
appendText(run.log_path, sprintf('phi table: %s\n', phiPath));
appendText(run.log_path, sprintf('kappa table: %s\n', kappaPath));
appendText(run.log_path, sprintf('quality table: %s\n', qualityPath));
appendText(run.log_path, sprintf('report: %s\n', reportPath));
if strlength(string(zipPath)) > 0
    appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));
else
    appendText(run.log_path, 'ZIP: (skipped)\n');
end

out = struct();
out.run = run;
out.runDir = string(runDir);
out.cdfMethod = string(cdfMethod);
out.lowWindowTemperatureMaxK = cfg.canonicalMaxTemperatureK;
out.phiPath = string(phiPath);
out.kappaPath = string(kappaPath);
out.qualityPath = string(qualityPath);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
% Optional replay handles for per-temperature audits (no extra compute cost).
out.temperaturesK = temps;
out.currents_mA = currents;
out.canonicalMaxTemperatureK = cfg.canonicalMaxTemperatureK;
out.lowTemperatureMask = lowMask;
out.xGrid = xGrid;
out.phi = phi;
out.kappaAll = kappaAll;
out.deltaS = deltaS;
out.Xrows = Xrows;
out.Rall = Rall;
out.RhatAll = RhatAll;
out.Ipeak_mA = Ipeak;
out.width_mA = width;
out.Speak = Speak;
out.svdSingularValues = svInfo.singularValues;
out.phi2 = svInfo.shapeMode2;
out.figures = struct( ...
    'residualCollapse', string(figCollapsePath.png), ...
    'phiShape', string(figPhiPath.png), ...
    'kappaVsT', string(figKappaPath.png), ...
    'reconstructionComparison', string(figReconPath.png));

fprintf('\n=== Switching residual decomposition complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Canonical interpretation window: T <= %.1f K\n', cfg.canonicalMaxTemperatureK);
fprintf('CDF model method: %s\n', char(cdfMethod));
fprintf('rank-1 energy fraction (low-T): %.4f\n', quality.rank1EnergyFraction);
fprintf('Report: %s\n', reportPath);
if strlength(string(zipPath)) > 0
    fprintf('ZIP: %s\n\n', zipPath);
else
    fprintf('ZIP: (skipped)\n\n');
end
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'residual_decomposition');
cfg = setDefault(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefault(cfg, 'ptRunId', '');
cfg = setDefault(cfg, 'canonicalMaxTemperatureK', 30);
cfg = setDefault(cfg, 'nXGrid', 220);
cfg = setDefault(cfg, 'maxModes', 2);
cfg = setDefault(cfg, 'speakFloorFraction', 1e-3);
cfg = setDefault(cfg, 'minRowsForDecomposition', 5);
cfg = setDefault(cfg, 'fallbackSmoothWindow', 5);
cfg = setDefault(cfg, 'skipFigures', false);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.alignmentRunId = string(cfg.alignmentRunId);
source.fullScalingRunId = string(cfg.fullScalingRunId);
source.ptRunId = string(cfg.ptRunId);

source.alignmentRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.alignmentRunId));
source.fullScalingRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.fullScalingRunId));
source.alignmentCorePath = fullfile(source.alignmentRunDir, 'switching_alignment_core_data.mat');
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', 'switching_full_scaling_parameters.csv');

if strlength(source.ptRunId) == 0
    [ptRunId, ptPath] = findLatestPTMatrix(repoRoot);
    source.ptRunId = string(ptRunId);
    source.ptMatrixPath = string(ptPath);
else
    source.ptMatrixPath = string(fullfile(repoRoot, 'results', 'switching', 'runs', ...
        char(source.ptRunId), 'tables', 'PT_matrix.csv'));
end

assert(exist(source.alignmentCorePath, 'file') == 2, ...
    'Missing alignment core map: %s', source.alignmentCorePath);
assert(exist(source.fullScalingParamsPath, 'file') == 2, ...
    'Missing full-scaling parameters: %s', source.fullScalingParamsPath);

if exist(char(source.ptMatrixPath), 'file') == 2
    source.ptDescriptor = source.ptRunId;
else
    source.ptDescriptor = "missing_PT_matrix__using_fallback";
    source.ptRunId = "none";
    source.ptMatrixPath = "";
end
end

function [runId, ptPath] = findLatestPTMatrix(repoRoot)
runsRoot = fullfile(repoRoot, 'results', 'switching', 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);

if isempty(runDirs)
    runId = "none";
    ptPath = "";
    return;
end

[~, order] = sort([runDirs.datenum], 'descend');
runDirs = runDirs(order);

runId = "none";
ptPath = "";
for i = 1:numel(runDirs)
    candidate = fullfile(runDirs(i).folder, runDirs(i).name, 'tables', 'PT_matrix.csv');
    if exist(candidate, 'file') == 2
        runId = string(runDirs(i).name);
        ptPath = string(candidate);
        return;
    end
end
end

function [Smap, temps, currents] = orientAndSortMap(SmapIn, tempsIn, currentsIn)
Smap = double(SmapIn);
temps = double(tempsIn(:));
currents = double(currentsIn(:));

rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurrents = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);

if rowsAreCurrents && ~rowsAreTemps
    Smap = Smap.';
elseif ~(rowsAreTemps || rowsAreCurrents)
    error('Smap dimensions [%d %d] do not match temps(%d) and currents(%d).', ...
        size(Smap, 1), size(Smap, 2), numel(temps), numel(currents));
end

[temps, tOrd] = sort(temps);
[currents, iOrd] = sort(currents);
Smap = Smap(tOrd, iOrd);
end

function [temps, Ipeak, Speak, width] = extractScalingColumns(tbl)
varNames = string(tbl.Properties.VariableNames);
temps = numericColumn(tbl, varNames, ["T_K", "T"]);
Ipeak = numericColumn(tbl, varNames, ["Ipeak_mA", "I_peak", "Ipeak"]);
Speak = numericColumn(tbl, varNames, ["S_peak", "Speak", "Speak_peak"]);
width = numericColumn(tbl, varNames, ["width_chosen_mA", "width_I", "width"]);

assert(~all(isnan(temps)), 'Scaling table missing temperature column.');
assert(~all(isnan(Ipeak)), 'Scaling table missing I_peak column.');
assert(~all(isnan(Speak)), 'Scaling table missing S_peak column.');
assert(~all(isnan(width)), 'Scaling table missing width column.');

[temps, ord] = sort(temps);
Ipeak = Ipeak(ord);
Speak = Speak(ord);
width = width(ord);
end

function col = numericColumn(tbl, varNames, candidates)
col = NaN(height(tbl), 1);
for i = 1:numel(candidates)
    idx = find(varNames == candidates(i), 1, 'first');
    if ~isempty(idx)
        raw = tbl.(varNames(idx));
        if isnumeric(raw)
            col = double(raw(:));
        else
            col = str2double(string(raw(:)));
        end
        return;
    end
end
end

function ptData = loadPTData(ptMatrixPath)
ptData = struct();
ptData.available = false;
ptData.temps = [];
ptData.currents = [];
ptData.PT = [];

if strlength(string(ptMatrixPath)) == 0 || exist(char(ptMatrixPath), 'file') ~= 2
    return;
end

tbl = readtable(char(ptMatrixPath));
varNames = string(tbl.Properties.VariableNames);
assert(~isempty(varNames), 'PT matrix table has no columns.');

if any(varNames == "T_K")
    tCol = "T_K";
else
    tCol = varNames(1);
end
temps = tbl.(tCol);
if isnumeric(temps)
    temps = double(temps(:));
else
    temps = str2double(string(temps(:)));
end

currentCols = setdiff(varNames, tCol, 'stable');
currents = NaN(numel(currentCols), 1);
for j = 1:numel(currentCols)
    currents(j) = parseCurrentFromColumnName(currentCols(j));
end

keepCols = isfinite(currents);
currents = currents(keepCols);
currentCols = currentCols(keepCols);
if isempty(currents)
    return;
end

PT = table2array(tbl(:, currentCols));
PT = double(PT);

[currents, ord] = sort(currents);
PT = PT(:, ord);

ptData.available = true;
ptData.temps = temps;
ptData.currents = currents;
ptData.PT = PT;
end

function val = parseCurrentFromColumnName(name)
s = char(string(name));
s = regexprep(s, '^Ith_', '', 'ignorecase');
s = regexprep(s, '_mA$', '', 'ignorecase');
sDot = strrep(s, '_', '.');
val = str2double(sDot);
if isfinite(val)
    return;
end

m = regexp(s, '[-+]?\d*\.?\d+', 'match', 'once');
if isempty(m)
    val = NaN;
else
    val = str2double(m);
end
end

function [Scdf, diagnostics] = buildCdfModel(Smap, currents, temps, Speak, ptData, cfg)
nT = numel(temps);
nI = numel(currents);

Scdf = NaN(nT, nI);
ptRowsUsed = 0;
fallbackRowsUsed = 0;

for it = 1:nT
    cdfRow = [];
    if ptData.available
        cdfRow = cdfFromPT(ptData, temps(it), currents);
    end
    if isempty(cdfRow)
        cdfRow = cdfFallbackFromRow(Smap(it, :), currents, cfg.fallbackSmoothWindow);
        fallbackRowsUsed = fallbackRowsUsed + 1;
    else
        ptRowsUsed = ptRowsUsed + 1;
    end
    Scdf(it, :) = Speak(it) .* cdfRow(:)';
end

diagnostics = struct();
diagnostics.ptRowsUsed = ptRowsUsed;
diagnostics.fallbackRowsUsed = fallbackRowsUsed;
end

function cdfRow = cdfFromPT(ptData, targetT, currents)
tempsPT = ptData.temps(:);
currPT = ptData.currents(:);
PT = ptData.PT;

if numel(tempsPT) < 2 || size(PT, 2) ~= numel(currPT)
    cdfRow = [];
    return;
end

pAtT = NaN(numel(currPT), 1);
for j = 1:numel(currPT)
    col = PT(:, j);
    m = isfinite(tempsPT) & isfinite(col);
    if nnz(m) < 2
        continue;
    end
    pAtT(j) = interp1(tempsPT(m), col(m), targetT, 'linear', NaN);
end

if all(~isfinite(pAtT))
    cdfRow = [];
    return;
end

pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);
areaPT = trapz(currPT, pAtT);
if ~(isfinite(areaPT) && areaPT > 0)
    cdfRow = [];
    return;
end
pAtT = pAtT ./ areaPT;

pOnCurrents = interp1(currPT, pAtT, currents(:), 'linear', 0);
pOnCurrents = max(pOnCurrents, 0);
area = trapz(currents, pOnCurrents);
if ~(isfinite(area) && area > 0)
    cdfRow = [];
    return;
end
pOnCurrents = pOnCurrents ./ area;

cdfRow = cumtrapz(currents, pOnCurrents);
if cdfRow(end) <= 0
    cdfRow = [];
    return;
end
cdfRow = cdfRow ./ cdfRow(end);
cdfRow = min(max(cdfRow, 0), 1);
end

function cdfRow = cdfFallbackFromRow(row, currents, smoothWindow)
row = double(row(:)');
currents = double(currents(:));

valid = isfinite(row) & isfinite(currents(:)');
if nnz(valid) < 3
    cdfRow = zeros(size(currents));
    return;
end

r = row(valid);
I = currents(valid);

rMin = min(r, [], 'omitnan');
rMax = max(r, [], 'omitnan');
if ~(isfinite(rMin) && isfinite(rMax) && rMax > rMin)
    cdfRow = zeros(size(currents));
    return;
end

rNorm = (r - rMin) ./ (rMax - rMin);
if smoothWindow >= 2
    rNorm = smoothdata(rNorm, 'movmean', min(smoothWindow, numel(rNorm)));
end
rNorm = enforceMonotoneNondecreasing(rNorm);

p = gradient(rNorm, I);
p = max(p, 0);
area = trapz(I, p);
if ~(isfinite(area) && area > 0)
    cdfRow = zeros(size(currents));
    return;
end
p = p ./ area;

pFull = interp1(I, p, currents, 'linear', 0);
pFull = max(pFull, 0);
areaFull = trapz(currents, pFull);
if areaFull > 0
    pFull = pFull ./ areaFull;
end

cdfRow = cumtrapz(currents, pFull);
if cdfRow(end) > 0
    cdfRow = cdfRow ./ cdfRow(end);
end
cdfRow = min(max(cdfRow, 0), 1);
end

function y = enforceMonotoneNondecreasing(x)
y = x(:).';
for i = 2:numel(y)
    if y(i) < y(i - 1)
        y(i) = y(i - 1);
    end
end
if y(end) > 0
    y = y ./ y(end);
end
end

function xGrid = buildCommonXGrid(Xrows, nX)
nRows = size(Xrows, 1);
xLower = -Inf;
xUpper = Inf;

for i = 1:nRows
    row = Xrows(i, :);
    m = isfinite(row);
    if nnz(m) < 3
        continue;
    end
    xLower = max(xLower, min(row(m)));
    xUpper = min(xUpper, max(row(m)));
end

if ~(isfinite(xLower) && isfinite(xUpper) && xUpper > xLower)
    vals = Xrows(isfinite(Xrows));
    xLower = min(vals);
    xUpper = max(vals);
end

if ~(isfinite(xLower) && isfinite(xUpper) && xUpper > xLower)
    xLower = -2.5;
    xUpper = 2.5;
end

xGrid = linspace(xLower, xUpper, nX)';
end

function Rout = interpolateRowsToGrid(Xrows, Yrows, xGrid)
nRows = size(Xrows, 1);
nX = numel(xGrid);
Rout = NaN(nRows, nX);

for i = 1:nRows
    x = Xrows(i, :);
    y = Yrows(i, :);
    m = isfinite(x) & isfinite(y);
    if nnz(m) < 3
        continue;
    end
    x = x(m);
    y = y(m);
    [x, ord] = sort(x);
    y = y(ord);
    [x, iu] = unique(x, 'stable');
    y = y(iu);
    Rout(i, :) = interp1(x, y, xGrid, 'linear', NaN);
end
end

function [phi, info] = extractShapeMode(Rlow, maxModes)
R0 = Rlow;
R0(~isfinite(R0)) = 0;

[U, S, V] = svd(R0, 'econ');
s = diag(S);
assert(~isempty(s), 'Residual decomposition SVD returned no singular values.');

phi = V(:, 1);
kappaRaw = U(:, 1) * s(1);
if median(kappaRaw, 'omitnan') < 0
    phi = -phi;
end

scale = max(abs(phi), [], 'omitnan');
if ~(isfinite(scale) && scale > 0)
    scale = 1;
end
phi = phi ./ scale;

energy = s .^ 2;
energyFrac = energy / max(sum(energy, 'omitnan'), eps);
rank12 = sum(energyFrac(1:min(2, numel(energyFrac))), 'omitnan');
if numel(s) >= 2 && s(2) > 0
    dominance = s(1) / s(2);
else
    dominance = Inf;
end

info = struct();
info.singularValues = s;
info.energyFraction = energyFrac;
info.rank1EnergyFraction = energyFrac(1);
info.rank12EnergyFraction = rank12;
info.dominanceRatio12 = dominance;
info.maxModes = maxModes;
info.shapeMode2 = [];
if size(V, 2) >= 2
    info.shapeMode2 = V(:, 2);
end
end

function kappa = fitKappa(R, phi)
nRows = size(R, 1);
kappa = NaN(nRows, 1);

for i = 1:nRows
    r = R(i, :)';
    m = isfinite(r) & isfinite(phi);
    if nnz(m) < 3
        continue;
    end
    denom = sum(phi(m) .^ 2, 'omitnan');
    if denom <= eps
        continue;
    end
    kappa(i) = sum(r(m) .* phi(m), 'omitnan') / denom;
end
end

function q = evaluateQuality(R, Rhat, svInfo)
mask = isfinite(R) & isfinite(Rhat);
if ~any(mask(:))
    relError = NaN;
    rmse = NaN;
else
    diffR = R(mask) - Rhat(mask);
    rmse = sqrt(mean(diffR .^ 2, 'omitnan'));
    relError = norm(diffR, 'fro') / max(norm(R(mask), 'fro'), eps);
end

corrs = rowCorr(R, Rhat);

q = struct();
q.rank1EnergyFraction = svInfo.rank1EnergyFraction;
q.rank12EnergyFraction = svInfo.rank12EnergyFraction;
q.dominanceRatio12 = svInfo.dominanceRatio12;
q.lowWindowNRows = size(R, 1);
q.lowWindowRmse = rmse;
q.lowWindowRelError = relError;
q.lowWindowMedianCurveCorr = median(corrs, 'omitnan');
q.lowWindowP10CurveCorr = prctile(corrs, 10);
end

function c = rowCorr(A, B)
n = size(A, 1);
c = NaN(n, 1);
for i = 1:n
    x = A(i, :)';
    y = B(i, :)';
    m = isfinite(x) & isfinite(y);
    if nnz(m) < 3
        continue;
    end
    c(i) = corr(x(m), y(m));
end
end

function figPath = makeResidualCollapseFigure(temps, Rlow, xGrid, cfg, runDir)
baseName = 'residual_collapse';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 9]);
ax = axes(fig);
hold(ax, 'on');

nCurves = numel(temps);
if nCurves <= 6
    colors = lines(nCurves);
    for i = 1:nCurves
        plot(ax, xGrid, Rlow(i, :), '-', 'LineWidth', 2.0, ...
            'Color', colors(i, :), 'DisplayName', sprintf('T = %.0f K', temps(i)));
    end
    legend(ax, 'Location', 'best', 'Box', 'off');
else
    cmap = parula(nCurves);
    for i = 1:nCurves
        plot(ax, xGrid, Rlow(i, :), '-', 'LineWidth', 1.8, 'Color', cmap(i, :));
    end
    colormap(ax, parula);
    cb = colorbar(ax);
    cb.Label.String = 'Temperature (K)';
    clim(ax, [min(temps), max(temps)]);
end

hold(ax, 'off');
xlabel(ax, 'x = (I - I_{peak}) / w');
ylabel(ax, '\deltaS = S - S_{CDF} (P2P percent)');
title(ax, sprintf('Residual collapse in canonical window T <= %.1f K', cfg.canonicalMaxTemperatureK));
styleAxes(ax);
figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPath = makePhiFigure(xGrid, phi, runDir)
baseName = 'phi_shape';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 12 8]);
ax = axes(fig);
plot(ax, xGrid, phi, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerSize', 5);
xlabel(ax, 'x = (I - I_{peak}) / w');
ylabel(ax, '\Phi(x)');
title(ax, 'Extracted universal residual shape \Phi(x)');
grid(ax, 'on');
styleAxes(ax);
figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPath = makeKappaFigure(temps, kappa, cfg, runDir)
baseName = 'kappa_vs_T';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 12 8]);
ax = axes(fig);
plot(ax, temps, kappa, '-o', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerSize', 5);
hold(ax, 'on');
xline(ax, cfg.canonicalMaxTemperatureK, '--k', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('T = %.1f K boundary', cfg.canonicalMaxTemperatureK));
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, '\kappa(T)');
title(ax, 'Residual amplitude \kappa(T)');
grid(ax, 'on');
styleAxes(ax);
figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPath = makeReconstructionFigure(temps, xGrid, R, Rhat, runDir)
baseName = 'residual_reconstruction_comparison';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 15 10]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
imagesc(ax1, xGrid, temps, R);
axis(ax1, 'xy');
colormap(ax1, parula);
cb1 = colorbar(ax1);
cb1.Label.String = '\deltaS (P2P percent)';
xlabel(ax1, 'x = (I - I_{peak}) / w');
ylabel(ax1, 'Temperature (K)');
title(ax1, 'Original residual');
styleAxes(ax1);

ax2 = nexttile(tl, 2);
imagesc(ax2, xGrid, temps, Rhat);
axis(ax2, 'xy');
colormap(ax2, parula);
cb2 = colorbar(ax2);
cb2.Label.String = '\kappa(T)\Phi(x)';
xlabel(ax2, 'x = (I - I_{peak}) / w');
ylabel(ax2, 'Temperature (K)');
title(ax2, 'Rank-1 reconstruction');
styleAxes(ax2);

figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.0, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top', ...
    'XMinorTick', 'off', ...
    'YMinorTick', 'off');
end

function reportText = buildReportText(source, cfg, cdfMethod, quality, cdfDiagnostics, ...
    phiPath, kappaPath, qualityPath, sourcePath, ...
    figCollapsePath, figPhiPath, figKappaPath, figReconPath)
lines = strings(0, 1);
lines(end + 1) = "# Switching residual decomposition report";
lines(end + 1) = "";
lines(end + 1) = "## Scope";
lines(end + 1) = "- Target model: `S(I,T) = S0(T)*CDF(P_T) + kappa(T)*Phi((I-I_peak)/w)`.";
lines(end + 1) = "- Canonical interpretation window: **T <= " + sprintf('%.1f K', cfg.canonicalMaxTemperatureK) + "**.";
lines(end + 1) = "- T > " + sprintf('%.1f K', cfg.canonicalMaxTemperatureK) + " is treated as boundary/breakdown reference only.";
lines(end + 1) = "";
lines(end + 1) = "## Data sources";
lines(end + 1) = "- Alignment map run: `" + source.alignmentRunId + "`.";
lines(end + 1) = "- Full scaling parameters run: `" + source.fullScalingRunId + "`.";
lines(end + 1) = "- PT source descriptor: `" + source.ptDescriptor + "`.";
lines(end + 1) = "- Source manifest table: `" + string(sourcePath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Decomposition method";
lines(end + 1) = "1. Reconstruct active component `S_CDF(I,T)` using `" + string(cdfMethod) + "`.";
lines(end + 1) = "2. Compute residual `deltaS(I,T) = S - S_CDF`.";
lines(end + 1) = "3. Normalize current axis `x = (I-I_peak)/w` and interpolate residuals on common x-grid.";
lines(end + 1) = "4. Extract dominant residual shape via rank-1 SVD in canonical window.";
lines(end + 1) = "5. Fit `kappa(T)` by least-squares projection of each residual curve onto `Phi(x)`.";
lines(end + 1) = "";
lines(end + 1) = "## Minimal-model check (no overfitting)";
lines(end + 1) = "- rank-1 energy fraction: `" + sprintf('%.4f', quality.rank1EnergyFraction) + "`.";
lines(end + 1) = "- rank-(1+2) energy fraction: `" + sprintf('%.4f', quality.rank12EnergyFraction) + "`.";
lines(end + 1) = "- dominance ratio sigma1/sigma2: `" + sprintf('%.4f', quality.dominanceRatio12) + "`.";
lines(end + 1) = "- Main model uses one mode only (`Phi`, `kappa`). Mode 2 is diagnostic-only.";
lines(end + 1) = "";
lines(end + 1) = "## Collapse quality (canonical window)";
lines(end + 1) = "- Number of low-T rows: `" + string(quality.lowWindowNRows) + "`.";
lines(end + 1) = "- RMSE of rank-1 reconstruction: `" + sprintf('%.6g', quality.lowWindowRmse) + "`.";
lines(end + 1) = "- Relative Frobenius error: `" + sprintf('%.6g', quality.lowWindowRelError) + "`.";
lines(end + 1) = "- Median per-curve correlation (`deltaS` vs `kappa*Phi`): `" + sprintf('%.4f', quality.lowWindowMedianCurveCorr) + "`.";
lines(end + 1) = "- 10th percentile per-curve correlation: `" + sprintf('%.4f', quality.lowWindowP10CurveCorr) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## CDF reconstruction diagnostics";
lines(end + 1) = "- Rows using PT matrix: `" + string(cdfDiagnostics.ptRowsUsed) + "`.";
lines(end + 1) = "- Rows using fallback CDF reconstruction: `" + string(cdfDiagnostics.fallbackRowsUsed) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Requested outputs";
lines(end + 1) = "- `phi_shape.csv`: `" + string(phiPath) + "`.";
lines(end + 1) = "- `kappa_vs_T.csv`: `" + string(kappaPath) + "`.";
lines(end + 1) = "- quality table: `" + string(qualityPath) + "`.";
lines(end + 1) = "- residual collapse figure: `" + string(figCollapsePath.png) + "`.";
lines(end + 1) = "- phi figure: `" + string(figPhiPath.png) + "`.";
lines(end + 1) = "- kappa figure: `" + string(figKappaPath.png) + "`.";
lines(end + 1) = "- optional reconstruction comparison: `" + string(figReconPath.png) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: collapse panel uses all `T<=30 K` curves; phi and kappa panels are single-curve diagnostics.";
lines(end + 1) = "- legend vs colormap: explicit legend for <=6 curves, otherwise parula + temperature colorbar.";
lines(end + 1) = "- colormap used: `parula`.";
lines(end + 1) = "- smoothing applied: fallback CDF only, movmean window = " + string(cfg.fallbackSmoothWindow) + ".";
lines(end + 1) = "- justification: preserves physical interpretability and keeps decomposition minimal (rank-1 primary model).";

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
zip(zipPath, {'figures', 'tables', 'reports', ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(string(textValue)));
end

function out = stampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end

