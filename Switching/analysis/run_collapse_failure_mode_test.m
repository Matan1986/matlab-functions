function out = run_collapse_failure_mode_test(cfg)
% run_collapse_failure_mode_test
% Failure-of-collapse mode test: leading SVD mode of deltaS = S - S_CDF on the
% canonical x grid vs empirical Phi(x) from residual decomposition.
%
% Reads inputs from a valid residual decomposition run (phi_shape, sources);
% does not modify source runs. Writes a new results/switching/runs/... folder.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

analysisDir = fileparts(mfilename('fullpath'));
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);

decTablesDir = resolveDecompositionTablesDir(repoRoot, cfg.decompositionRunId);
phiPath = fullfile(decTablesDir, 'phi_shape.csv');
srcPath = fullfile(decTablesDir, 'residual_decomposition_sources.csv');

assert(exist(phiPath, 'file') == 2, 'Missing phi_shape.csv: %s', phiPath);

phiTbl = readtable(phiPath);
xGrid = double(phiTbl.x(:));
Phi = double(phiTbl.Phi(:));

[ptPath, alignId, scaleId] = resolvePathsFromSourcesOrCfg(repoRoot, srcPath, cfg);

runDataset = sprintf('collapse_failure_mode_test | decomp:%s', cfg.decompositionRunId);
run = createRunContext('switching', struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

fprintf('Collapse failure-mode test run directory:\n%s\n', runDir);
fprintf('Decomposition source run: %s\n', char(cfg.decompositionRunId));

appendText(run.log_path, sprintf('[%s] run_collapse_failure_mode_test started\n', stampNow()));
appendText(run.log_path, sprintf('decomposition_tables: %s\n', decTablesDir));

slice = loadAlignmentScalingSlice(repoRoot, alignId, scaleId, ptPath);
Smap = slice.Smap;
temps = slice.temps;
currents = slice.currents;
Ipeak = slice.Ipeak;
Speak = slice.Speak;
width = slice.width;
ptData = slice.ptData;

[Scdf, cdfMeta] = buildScdfMatrix(Smap, currents, temps, Speak, ptData, cfg.fallbackSmoothWindow);
assert(cdfMeta.ptRowsUsed > 0, 'PT_matrix produced no CDF rows; this test requires PT-backed S_CDF.');

deltaS = Smap - Scdf;

nT = numel(temps);
nI = numel(currents);
Xrows = NaN(nT, nI);
for it = 1:nT
    Xrows(it, :) = (currents(:)' - Ipeak(it)) ./ width(it);
end

lowMask = temps <= cfg.canonicalMaxTemperatureK;
assert(nnz(lowMask) >= cfg.minRowsSvd, 'Too few rows in canonical low-T window.');

winDefs = {
    'T_le_30_K_full_low_window', lowMask
    'T_le_30_K_exclude_22', lowMask & abs(temps(:) - 22) > 0.51
    'T_le_24_K', temps(:) <= 24
    };

nWin = size(winDefs, 1);
pearsonCol = NaN(nWin, 1);
cosineCol = NaN(nWin, 1);
rmsePhiCol = NaN(nWin, 1);
rmseSvdCol = NaN(nWin, 1);
ratioCol = NaN(nWin, 1);
rank1EfracCol = NaN(nWin, 1);
nRowsCol = zeros(nWin, 1);
varExplCol = NaN(nWin, 1);
psiCell = cell(nWin, 1);
svCell = cell(nWin, 1);

for wi = 1:nWin
    winName = winDefs{wi, 1};
    mask = winDefs{wi, 2};
    mask = mask & isfinite(mask);
    if nnz(mask) < cfg.minRowsSvd
        warning('Window %s skipped: only %d rows.', winName, nnz(mask));
        continue
    end

    R = interpolateRowsToGrid(Xrows(mask, :), deltaS(mask, :), xGrid);
    nRowsCol(wi) = size(R, 1);

    [psi, svInfo] = extractShapeModeCollapse(R, 2);
    psiCell{wi} = psi;
    svCell{wi} = svInfo.singularValues;

    m = isfinite(Phi) & isfinite(psi);
    pearsonCol(wi) = corr(Phi(m), psi(m));
    cosineCol(wi) = dot(Phi(m), psi(m)) / (norm(Phi(m)) * norm(psi(m)) + eps);

    [rmsePhi, rmseSvd, ratio] = rmsePhiVsRank1(R, Phi, psi);
    rmsePhiCol(wi) = rmsePhi;
    rmseSvdCol(wi) = rmseSvd;
    ratioCol(wi) = ratio;
    rank1EfracCol(wi) = svInfo.rank1EnergyFraction;

    varExplCol(wi) = varianceExplainedOnPhi(R, Phi);
end

modeTbl = table(winDefs(:, 1), nRowsCol, pearsonCol, cosineCol, rmsePhiCol, rmseSvdCol, ...
    ratioCol, rank1EfracCol, varExplCol, ...
    'VariableNames', {'temperature_window', 'n_temperature_rows', 'pearson_Phi_psi_collapse', ...
    'cosine_Phi_psi_collapse', 'rmse_kappa_Phi_fit', 'rmse_rank1_svd', 'rmse_ratio_Phi_over_rank1', ...
    'rank1_energy_fraction_svd', 'variance_fraction_explained_by_Phi'});

projTbl = table(winDefs(:, 1), varExplCol, nRowsCol, ...
    'VariableNames', {'temperature_window', 'variance_explained_fraction_Phi_projection', 'n_rows'});

save_run_table(modeTbl, 'collapse_failure_mode_metrics.csv', runDir);
save_run_table(projTbl, 'collapse_projection_metrics.csv', runDir);

figPaths = struct();
figPaths.phi_vs = makeFigPhiVsPsi(xGrid, Phi, psiCell, winDefs(:, 1), runDir);
figPaths.sv = makeFigSingularValues(svCell, winDefs(:, 1), runDir);

reportPath = writeCollapseReport(runDir, cfg, decTablesDir, ptPath, alignId, scaleId, ...
    cdfMeta, modeTbl, figPaths);

zipPath = buildReviewZip(runDir, 'collapse_failure_mode_bundle.zip');

appendText(run.log_path, sprintf('[%s] complete\n', stampNow()));
appendText(run.log_path, sprintf('tables: collapse_failure_mode_metrics.csv, collapse_projection_metrics.csv\n'));
appendText(run.log_path, sprintf('report: %s\n', reportPath));

out = struct();
out.runDir = string(runDir);
out.modeTable = modeTbl;
out.projectionTable = projTbl;
out.zipPath = string(zipPath);

fprintf('\n=== Collapse failure-mode test complete ===\n');
fprintf('Run dir: %s\n', runDir);
end

%% --- metrics helpers ---

function [rmsePhi, rmseSvd, ratio] = rmsePhiVsRank1(R, Phi, psi)
kappa = fitKappaRows(R, Phi);
Rphi = kappa * Phi(:)';

R0 = R;
R0(~isfinite(R0)) = 0;
[U, S, V] = svd(R0, 'econ');
s = diag(S);
if isempty(s)
    rmsePhi = NaN;
    rmseSvd = NaN;
    ratio = NaN;
    return
end
Rsvd = U(:, 1) * s(1) * V(:, 1)';

mask = isfinite(R) & isfinite(Rphi) & isfinite(Rsvd);
if ~any(mask(:))
    rmsePhi = NaN;
    rmseSvd = NaN;
    ratio = NaN;
    return
end
dPhi = R(mask) - Rphi(mask);
dSvd = R(mask) - Rsvd(mask);
rmsePhi = sqrt(mean(dPhi .^ 2, 'omitnan'));
rmseSvd = sqrt(mean(dSvd .^ 2, 'omitnan'));
ratio = rmsePhi / max(rmseSvd, eps);
end

function kappa = fitKappaRows(R, phi)
nRows = size(R, 1);
kappa = NaN(nRows, 1);
phi = phi(:);
for i = 1:nRows
    r = R(i, :)';
    m = isfinite(r) & isfinite(phi);
    if nnz(m) < 3
        continue
    end
    denom = sum(phi(m) .^ 2, 'omitnan');
    if denom <= eps
        continue
    end
    kappa(i) = sum(r(m) .* phi(m), 'omitnan') / denom;
end
end

function ve = varianceExplainedOnPhi(R, phi)
phi = phi(:);
num = 0;
den = 0;
for i = 1:size(R, 1)
    r = R(i, :)';
    m = isfinite(r) & isfinite(phi);
    if nnz(m) < 3
        continue
    end
    denomRow = sum(phi(m) .^ 2, 'omitnan');
    if denomRow <= eps
        continue
    end
    k = sum(r(m) .* phi(m), 'omitnan') / denomRow;
    num = num + sum((k * phi(m)) .^ 2);
    den = den + sum((r(m)) .^ 2);
end
if den <= eps
    ve = NaN;
else
    ve = num / den;
end
end

function [phi, info] = extractShapeModeCollapse(Rlow, maxModes)
R0 = Rlow;
R0(~isfinite(R0)) = 0;
[U, S, V] = svd(R0, 'econ');
s = diag(S);
assert(~isempty(s), 'SVD returned no singular values.');

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
        continue
    end
    x = x(m);
    y = y(m);
    [x, ord] = sort(x);
    y = y(ord);
    [x, iu] = unique(x, 'stable');
    y = y(iu);
    Rout(i, :) = interp1(x, y, xGrid(:), 'linear', NaN).';
end
end

%% --- path / IO (aligned with run_phi_temperature_derivative_test) ---

function decDir = resolveDecompositionTablesDir(repoRoot, runId)
rid = char(string(runId));
candidates = {
    fullfile(repoRoot, 'results', 'switching', 'runs', rid, 'tables')
    fullfile(repoRoot, 'results', 'switching', 'runs', ['_extract_' rid], rid, 'tables')
    };
decDir = '';
for i = 1:numel(candidates)
    p = fullfile(candidates{i}, 'phi_shape.csv');
    if exist(p, 'file') == 2
        decDir = candidates{i};
        return
    end
end
error('Decomposition tables not found for run %s (tried standard and _extract_ layouts).', rid);
end

function cfg = applyDefaults(cfg)
cfg = setDef(cfg, 'runLabel', 'collapse_failure_mode_test');
cfg = setDef(cfg, 'decompositionRunId', 'run_2026_03_24_220314_residual_decomposition');
cfg = setDef(cfg, 'alignmentRunId', '');
cfg = setDef(cfg, 'fullScalingRunId', '');
cfg = setDef(cfg, 'ptMatrixPath', '');
cfg = setDef(cfg, 'fallbackSmoothWindow', 5);
cfg = setDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = setDef(cfg, 'minRowsSvd', 5);
end

function cfg = setDef(cfg, f, v)
if ~isfield(cfg, f) || isempty(cfg.(f))
    cfg.(f) = v;
end
end

function [ptPath, alignId, scaleId] = resolvePathsFromSourcesOrCfg(repoRoot, srcPath, cfg)
alignId = string(cfg.alignmentRunId);
scaleId = string(cfg.fullScalingRunId);
ptPath = string(cfg.ptMatrixPath);

if exist(srcPath, 'file') == 2
    st = readtable(srcPath);
    vn = st.Properties.VariableNames;
    roleCol = localPickVar(vn, {'source_role', 'SourceRole'});
    fileCol = localPickVar(vn, {'source_file', 'SourceFile'});
    if ~isempty(roleCol) && ~isempty(fileCol)
        roles = string(st.(roleCol));
        for i = 1:height(st)
            if roles(i) == "alignment_core_map" && strlength(alignId) == 0
                p = char(st.(fileCol)(i));
                alignId = string(localRunIdFromPath(p));
            elseif roles(i) == "full_scaling_parameters" && strlength(scaleId) == 0
                p = char(st.(fileCol)(i));
                scaleId = string(localRunIdFromPath(p));
            elseif roles(i) == "pt_matrix" && strlength(ptPath) == 0
                ptPath = string(char(st.(fileCol)(i)));
            end
        end
    end
end

if strlength(alignId) == 0
    alignId = "run_2026_03_10_112659_alignment_audit";
end
if strlength(scaleId) == 0
    scaleId = "run_2026_03_12_234016_switching_full_scaling_collapse";
end
if strlength(ptPath) == 0
    ptPath = string(fullfile(repoRoot, 'results', 'switching', 'runs', ...
        'run_2026_03_24_212033_switching_barrier_distribution_from_map', 'tables', 'PT_matrix.csv'));
end

assert(exist(char(ptPath), 'file') == 2, 'PT_matrix.csv not found: %s', char(ptPath));
end

function col = localPickVar(varNames, candidates)
col = '';
for k = 1:numel(candidates)
    if any(strcmp(varNames, candidates{k}))
        col = candidates{k};
        return
    end
end
end

function id = localRunIdFromPath(p)
parts = split(string(p), filesep);
idx = find(parts == "runs", 1, 'last');
if isempty(idx) || idx >= numel(parts)
    id = "";
    return
end
id = parts(idx + 1);
end

function slice = loadAlignmentScalingSlice(repoRoot, alignId, scaleId, ptPath)
source.alignmentRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(alignId));
source.fullScalingRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(scaleId));
source.alignmentCorePath = fullfile(source.alignmentRunDir, 'switching_alignment_core_data.mat');
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', 'switching_full_scaling_parameters.csv');

assert(exist(source.alignmentCorePath, 'file') == 2, 'Missing %s', source.alignmentCorePath);
assert(exist(source.fullScalingParamsPath, 'file') == 2, 'Missing %s', source.fullScalingParamsPath);

core = load(source.alignmentCorePath, 'Smap', 'temps', 'currents');
paramsTbl = readtable(source.fullScalingParamsPath);
[SmapAll, tempsAll, currents] = orientAndSortMap(core.Smap, core.temps(:), core.currents(:));
[tempsScale, IpeakScale, SpeakScale, widthScale] = extractScalingColumns(paramsTbl);
[tempsCommon, iMap, iScale] = intersect(tempsAll, tempsScale, 'stable');
Smap = SmapAll(iMap, :);
Ipeak = IpeakScale(iScale);
Speak = SpeakScale(iScale);
width = widthScale(iScale);
valid = isfinite(tempsCommon) & isfinite(Ipeak) & isfinite(Speak) & isfinite(width);
valid = valid & (width > 0);
valid = valid & (Speak > 1e-3 * max(Speak, [], 'omitnan'));

slice = struct();
slice.Smap = Smap(valid, :);
slice.temps = tempsCommon(valid);
slice.currents = currents;
slice.Ipeak = Ipeak(valid);
slice.Speak = Speak(valid);
slice.width = width(valid);
slice.ptData = loadPTData(char(ptPath));
end

function [Scdf, meta] = buildScdfMatrix(Smap, currents, temps, Speak, ptData, fallbackSmoothWindow)
nT = numel(temps);
nI = numel(currents);
Scdf = NaN(nT, nI);
ptRows = 0;
fbRows = 0;
for it = 1:nT
    cdfRow = [];
    if ptData.available
        cdfRow = cdfFromPT(ptData, temps(it), currents);
    end
    if isempty(cdfRow)
        cdfRow = cdfFallbackFromRow(Smap(it, :), currents, fallbackSmoothWindow);
        fbRows = fbRows + 1;
    else
        ptRows = ptRows + 1;
    end
    Scdf(it, :) = Speak(it) .* cdfRow(:).';
end
meta = struct('ptRowsUsed', ptRows, 'fallbackRowsUsed', fbRows);
end

function ptData = loadPTData(ptMatrixPath)
ptData = struct('available', false, 'temps', [], 'currents', [], 'PT', []);
if exist(ptMatrixPath, 'file') ~= 2
    return
end
tbl = readtable(ptMatrixPath);
varNames = string(tbl.Properties.VariableNames);
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
    return
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
    return
end
m = regexp(s, '[-+]?\d*\.?\d+', 'match', 'once');
if isempty(m)
    val = NaN;
else
    val = str2double(m);
end
end

function cdfRow = cdfFromPT(ptData, targetT, currents)
tempsPT = ptData.temps(:);
currPT = ptData.currents(:);
PT = ptData.PT;
if numel(tempsPT) < 2 || size(PT, 2) ~= numel(currPT)
    cdfRow = [];
    return
end
pAtT = NaN(numel(currPT), 1);
for j = 1:numel(currPT)
    col = PT(:, j);
    m = isfinite(tempsPT) & isfinite(col);
    if nnz(m) < 2
        continue
    end
    pAtT(j) = interp1(tempsPT(m), col(m), targetT, 'linear', NaN);
end
if all(~isfinite(pAtT))
    cdfRow = [];
    return
end
pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);
areaPT = trapz(currPT, pAtT);
if ~(isfinite(areaPT) && areaPT > 0)
    cdfRow = [];
    return
end
pAtT = pAtT ./ areaPT;
pOnCurrents = interp1(currPT, pAtT, currents(:), 'linear', 0);
pOnCurrents = max(pOnCurrents, 0);
area = trapz(currents, pOnCurrents);
if ~(isfinite(area) && area > 0)
    cdfRow = [];
    return
end
pOnCurrents = pOnCurrents ./ area;
cdfRow = cumtrapz(currents, pOnCurrents);
if cdfRow(end) <= 0
    cdfRow = [];
    return
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
    return
end
r = row(valid);
I = currents(valid);
rMin = min(r, [], 'omitnan');
rMax = max(r, [], 'omitnan');
if ~(isfinite(rMin) && isfinite(rMax) && rMax > rMin)
    cdfRow = zeros(size(currents));
    return
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
    return
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

function [Smap, temps, currents] = orientAndSortMap(SmapIn, tempsIn, currentsIn)
Smap = double(SmapIn);
temps = double(tempsIn(:));
currents = double(currentsIn(:));
rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurrents = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);
if rowsAreCurrents && ~rowsAreTemps
    Smap = Smap.';
elseif ~(rowsAreTemps || rowsAreCurrents)
    error('Smap dimensions do not match temps/currents.');
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
        return
    end
end
end

%% --- figures / report ---

function figPath = makeFigPhiVsPsi(xGrid, Phi, psiCell, winNames, runDir)
baseName = 'phi_vs_collapse_mode';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 16 10]);
cols = min(3, numel(psiCell));
rows = ceil(numel(psiCell) / cols);
for wi = 1:numel(psiCell)
    ax = subplot(rows, cols, wi);
    hold(ax, 'on');
    plot(ax, xGrid, Phi, '-', 'LineWidth', 2.2, 'DisplayName', '\Phi(x) (decomposition)');
    if ~isempty(psiCell{wi}) && all(isfinite(psiCell{wi}))
        plot(ax, xGrid, psiCell{wi}, '--', 'LineWidth', 2.0, 'DisplayName', '\psi_{collapse}(x)');
    end
    hold(ax, 'off');
    xlabel(ax, 'x = (I - I_{peak}) / w');
    ylabel(ax, 'Shape (max-abs normalized)');
    title(ax, char(strrep(winNames{wi}, '_', ' ')));
    legend(ax, 'Location', 'best', 'Box', 'off');
    grid(ax, 'on');
    styleAxes(ax);
end
figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPath = makeFigSingularValues(svCell, winNames, runDir)
baseName = 'collapse_mode_singular_values';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 9]);
ax = axes(fig);
hold(ax, 'on');
colors = lines(numel(svCell));
for wi = 1:numel(svCell)
    s = svCell{wi};
    if isempty(s)
        continue
    end
    plot(ax, 1:numel(s), s, 'o-', 'LineWidth', 2.2, 'Color', colors(wi, :), ...
        'DisplayName', char(strrep(winNames{wi}, '_', ' ')));
end
hold(ax, 'off');
xlabel(ax, 'Singular value index');
ylabel(ax, 'Magnitude');
title(ax, 'Singular spectrum of \deltaS_{collapse}(x, T)');
legend(ax, 'Location', 'eastoutside', 'Box', 'off');
grid(ax, 'on');
styleAxes(ax);
figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', 'FontSize', 14, 'LineWidth', 1.0, ...
    'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
end

function reportPath = writeCollapseReport(runDir, cfg, decTablesDir, ptPath, alignId, scaleId, ...
    cdfMeta, modeTbl, figPaths)

lines = strings(0, 1);
lines(end + 1) = "# Collapse failure-mode test";
lines(end + 1) = "";
lines(end + 1) = sprintf("Generated: %s", char(datetime('now')));
lines(end + 1) = "";
lines(end + 1) = "## Inputs";
lines(end + 1) = sprintf("- Decomposition tables: `%s`", decTablesDir);
lines(end + 1) = sprintf("- PT rows used / fallback: %d / %d", cdfMeta.ptRowsUsed, cdfMeta.fallbackRowsUsed);
lines(end + 1) = sprintf("- Alignment run: `%s`", char(alignId));
lines(end + 1) = sprintf("- Full-scaling run: `%s`", char(scaleId));
lines(end + 1) = sprintf("- PT matrix: `%s`", char(ptPath));
lines(end + 1) = "";
lines(end + 1) = "## Procedure";
lines(end + 1) = "1. Rebuild `S_CDF(I,T) = S_peak(T) * CDF(P_T)` with the same PT interpolation as residual decomposition.";
lines(end + 1) = "2. `deltaS = S - S_CDF`, map each row to `x = (I - I_peak) / w`, interpolate onto `x` from `phi_shape.csv`.";
lines(end + 1) = "3. SVD on `deltaS(x,T)` for each temperature window; leading right singular vector `psi_collapse` (max-abs normalized, sign from median row score).";
lines(end + 1) = "4. Compare `psi_collapse` to decomposition `Phi`; projection variance = fraction of `||deltaS||^2` captured by `kappa(T)*Phi(x)` with LS `kappa` per row.";
lines(end + 1) = "";
lines(end + 1) = "## Metrics (by window)";
lines(end + 1) = localTableToMd(modeTbl);
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
idx = strcmp(modeTbl.temperature_window, 'T_le_30_K_full_low_window');
if any(idx)
    r = modeTbl.pearson_Phi_psi_collapse(idx);
    ve = modeTbl.variance_fraction_explained_by_Phi(idx);
    rr = modeTbl.rmse_ratio_Phi_over_rank1(idx);
    lines(end + 1) = sprintf("- **Canonical window (T <= 30 K)**: Pearson(Phi, psi_collapse) = %.6f; variance explained by Phi projection = %.6f; RMSE ratio (Phi fit / rank-1 SVD) = %.6f.", r, ve, rr);
    lines(end + 1) = "  For this window, `psi_collapse` is computed with the same construction as decomposition `Phi`; agreement should be near exact up to numerical detail.";
end
lines(end + 1) = "";
lines(end + 1) = "## Figures";
lines(end + 1) = sprintf("- `%s`", figPaths.phi_vs.png);
lines(end + 1) = sprintf("- `%s`", figPaths.sv.png);
lines(end + 1) = "";

verdict = localVerdict(modeTbl);
lines(end + 1) = sprintf("## Verdict: **%s**", verdict);

reportPath = save_run_report(strjoin(lines, newline), 'collapse_failure_mode_report.md', runDir);
end

function s = localTableToMd(tbl)
s = "";
if height(tbl) == 0
    return
end
vn = tbl.Properties.VariableNames;
s = strjoin(vn, " | ") + newline;
s = s + strjoin(repmat("---", 1, numel(vn)), " | ") + newline;
for r = 1:height(tbl)
    row = strings(1, numel(vn));
    for c = 1:numel(vn)
        v = tbl{r, c};
        if isnumeric(v) && isscalar(v)
            row(c) = sprintf('%.6g', v);
        else
            row(c) = string(v);
        end
    end
    s = s + strjoin(row, " | ") + newline;
end
end

function verdict = localVerdict(modeTbl)
hit = modeTbl(strcmp(modeTbl.temperature_window, 'T_le_30_K_full_low_window'), :);
if height(hit) < 1
    verdict = "NO (missing canonical row)";
    return
end
r = abs(hit.pearson_Phi_psi_collapse(1));
rr = hit.rmse_ratio_Phi_over_rank1(1);
ve = hit.variance_fraction_explained_by_Phi(1);
r1 = hit.rank1_energy_fraction_svd(1);
if r > 0.995 && rr < 1.02 && ve > 0.99 * r1
    verdict = "YES (Phi matches leading collapse mode in canonical window; construction-equivalent)";
elseif r > 0.85 && rr < 1.15
    verdict = "PARTIAL";
else
    verdict = "NO";
end
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
    return
end
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(string(textValue)));
end

function out = stampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
