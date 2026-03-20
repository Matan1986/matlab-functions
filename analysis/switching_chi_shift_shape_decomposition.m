function out = switching_chi_shift_shape_decomposition(cfg)
% switching_chi_shift_shape_decomposition
% Decompose dS/dT into ridge-shift and internal-shape contributions.
%
% Model:
%   S(I,T) ~= F(I - I_c(T), T)
%   dS/dT = (shape term) - (dF/dI) * dI_c/dT
%
% Output:
%   A fresh cross-experiment run with:
%   - tables for chi_dyn, chi_shift, chi_shape
%   - derivative-component heatmaps
%   - comparison plots vs temperature and relaxation A(T)
%   - decomposition report and review ZIP bundle

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
runCfg.dataset = sprintf('switch:%s | relax:%s', char(source.switchRunName), char(source.relaxRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('Switching chi decomposition run directory:\n%s\n', runDir);
fprintf('Switching source run: %s\n', char(source.switchRunName));
fprintf('Relaxation source run: %s\n', char(source.relaxRunName));

appendText(run.log_path, sprintf('[%s] switching chi decomposition started\n', stampNow()));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));

dynCfg = struct();
dynCfg.switchRunName = char(source.switchRunName);
dynCfg.tempSmoothWindow = cfg.tempSmoothWindow;
dyn = switching_dynamical_susceptibility(dynCfg);

temps = double(dyn.temps(:));
currents = double(dyn.currents(:));
Smap = double(dyn.Smap);
dS_dT_full = double(dyn.dS_dT);

[I_center_raw, centerSource] = loadRidgeCenter(source.switchRunDir, temps);
[I_center, dI_center_dT] = smoothAndDifferentiate(temps, I_center_raw, cfg.ridgeSmoothWindow);
dS_dI = computeCurrentDerivative(Smap, currents, cfg.currentSmoothWindow);

dS_dT_shift = -(dS_dI .* dI_center_dT);
dS_dT_shape = dS_dT_full - dS_dT_shift;

[xGrid, dFullX, dShiftX, dShapeX] = remapToShiftedX( ...
    currents, I_center, dS_dT_full, dS_dT_shift, dS_dT_shape);

chiDyn = rmsRows(dFullX);
chiShift = rmsRows(dShiftX);
chiShape = rmsRows(dShapeX);

E_dyn = rowwiseMean(dFullX .^ 2);
E_shift = rowwiseMean(dShiftX .^ 2);
E_shape = rowwiseMean(dShapeX .^ 2);
E_cross = rowwiseMean(dShiftX .* dShapeX);

sumEnergy = E_shift + E_shape;
shiftEnergyFrac = safeDivide(E_shift, sumEnergy);
shapeEnergyFrac = safeDivide(E_shape, sumEnergy);

relaxTbl = readtable(fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv'));
[T_relax, A_relax] = loadRelaxationAT(relaxTbl);
A_interp = interp1(T_relax, A_relax, temps, cfg.interpMethod, NaN);

chiDynNorm = normalizeToMax(chiDyn);
chiShiftNorm = normalizeToMax(chiShift);
chiShapeNorm = normalizeToMax(chiShape);
A_norm = normalizeToMax(A_interp);

corrTbl = buildCorrelationTable(A_interp, chiDyn, chiShift, chiShape);
peakInfo = analyzeLowTPeak(temps, chiDyn, E_shift, E_shape, cfg);

decompTbl = table(temps, I_center_raw, I_center, dI_center_dT, ...
    chiDyn, chiShift, chiShape, chiDynNorm, chiShiftNorm, chiShapeNorm, ...
    E_dyn, E_shift, E_shape, E_cross, shiftEnergyFrac, shapeEnergyFrac, ...
    A_interp, A_norm, ...
    'VariableNames', {'T_K','I_center_raw_mA','I_center_smooth_mA','dI_center_dT_mA_per_K', ...
    'chi_dyn','chi_shift','chi_shape','chi_dyn_norm','chi_shift_norm','chi_shape_norm', ...
    'E_dyn','E_shift','E_shape','E_cross','shift_energy_fraction','shape_energy_fraction', ...
    'A_interp','A_norm'});

xMapTbl = buildShiftedMapLongTable(temps, xGrid, dFullX, dShiftX, dShapeX);
sourceTbl = buildSourceManifest(source, centerSource);

decompPath = save_run_table(decompTbl, 'chi_decomposition_vs_T.csv', runDir);
corrPath = save_run_table(corrTbl, 'chi_decomposition_correlations.csv', runDir);
xMapPath = save_run_table(xMapTbl, 'chi_decomposition_shifted_maps.csv', runDir);
sourcePath = save_run_table(sourceTbl, 'source_run_manifest.csv', runDir);

figFull = saveComponentHeatmap(temps, xGrid, dFullX, ...
    'Full derivative in shifted coordinate: dS/dT', ...
    'dS/dT (signal/K)', runDir, 'chi_decomposition_full_derivative_heatmap');
figShift = saveComponentHeatmap(temps, xGrid, dShiftX, ...
    'Shift-only term: -(dS/dI) dI_c/dT', ...
    'shift term (signal/K)', runDir, 'chi_decomposition_shift_term_heatmap');
figShape = saveComponentHeatmap(temps, xGrid, dShapeX, ...
    'Residual shape term: full - shift', ...
    'shape term (signal/K)', runDir, 'chi_decomposition_shape_term_heatmap');
figChiT = saveChiVsTFigure(temps, chiDyn, chiShift, chiShape, runDir, ...
    'chi_decomposition_components_vs_T');
figOverlay = saveOverlayWithAFigure(temps, chiDynNorm, chiShiftNorm, chiShapeNorm, A_norm, runDir, ...
    'chi_decomposition_components_with_A');
figShiftScatter = saveScatterFigure(A_interp, chiShift, temps, ...
    'A(T) (signal units)', 'chi_shift(T) (signal/K)', ...
    runDir, 'chi_decomposition_shift_vs_A');
figShapeScatter = saveScatterFigure(A_interp, chiShape, temps, ...
    'A(T) (signal units)', 'chi_shape(T) (signal/K)', ...
    runDir, 'chi_decomposition_shape_vs_A');
figFrac = saveEnergyFractionFigure(temps, shiftEnergyFrac, shapeEnergyFrac, peakInfo, runDir, ...
    'chi_decomposition_energy_fractions');

reportText = buildReportText(cfg, source, centerSource, peakInfo, corrTbl, xGrid, runDir);
reportPath = save_run_report(reportText, 'chi_shift_shape_decomposition_report.md', runDir);
zipPath = buildReviewZip(runDir, 'chi_shift_shape_decomposition_bundle.zip');

appendText(run.notes_path, sprintf('T_peak_chi_dyn = %.6g K\n', peakInfo.peakT));
appendText(run.notes_path, sprintf('T_peak_low_band = %.6g K\n', peakInfo.lowPeakT));
appendText(run.notes_path, sprintf('Low-band verdict = %s\n', char(peakInfo.verdict)));
appendText(run.notes_path, sprintf('Low-band E_shift/E_shape = %.6g\n', peakInfo.lowRatio));
appendText(run.log_path, sprintf('[%s] switching chi decomposition complete\n', stampNow()));
appendText(run.log_path, sprintf('Decomposition table: %s\n', decompPath));
appendText(run.log_path, sprintf('Correlations table: %s\n', corrPath));
appendText(run.log_path, sprintf('Shifted-map table: %s\n', xMapPath));
appendText(run.log_path, sprintf('Source manifest: %s\n', sourcePath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.peak = peakInfo;
out.tables = struct( ...
    'chi_decomposition', string(decompPath), ...
    'correlations', string(corrPath), ...
    'shifted_maps', string(xMapPath), ...
    'manifest', string(sourcePath));
out.figures = struct( ...
    'full_heatmap', string(figFull.png), ...
    'shift_heatmap', string(figShift.png), ...
    'shape_heatmap', string(figShape.png), ...
    'chi_vs_T', string(figChiT.png), ...
    'overlay_with_A', string(figOverlay.png), ...
    'shift_vs_A', string(figShiftScatter.png), ...
    'shape_vs_A', string(figShapeScatter.png), ...
    'energy_fraction', string(figFrac.png));
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== switching chi decomposition complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Global peak T: %.3f K\n', peakInfo.peakT);
fprintf('Low-band peak T: %.3f K\n', peakInfo.lowPeakT);
fprintf('Low-band verdict: %s\n', char(peakInfo.verdict));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_chi_shift_shape_decomposition');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'tempSmoothWindow', 3);
cfg = setDefaultField(cfg, 'currentSmoothWindow', 3);
cfg = setDefaultField(cfg, 'ridgeSmoothWindow', 3);
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'lowTempMinK', 4);
cfg = setDefaultField(cfg, 'lowTempMaxK', 14);
cfg = setDefaultField(cfg, 'dominanceRatioThreshold', 1.2);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.switchRunName = string(cfg.switchRunName);
source.relaxRunName = string(cfg.relaxRunName);
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));

required = { ...
    fullfile(char(source.switchRunDir), 'switching_alignment_core_data.mat'); ...
    fullfile(char(source.switchRunDir), 'observable_matrix.csv'); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv')};
for i = 1:numel(required)
    if exist(required{i}, 'file') ~= 2
        error('Required source file not found: %s', required{i});
    end
end
end

function [I_center, centerSource] = loadRidgeCenter(switchRunDir, temps)
I_center = NaN(size(temps));
centerSource = "";

mainPath = fullfile(char(switchRunDir), 'observable_matrix.csv');
if exist(mainPath, 'file') == 2
    tbl = readtable(mainPath);
    [T, I] = extractCenterColumns(tbl);
    I_center = alignCenterToTemps(temps, T, I);
    if any(isfinite(I_center))
        centerSource = "observable_matrix.csv";
        return;
    end
end

fallbackPath = fullfile(char(switchRunDir), 'alignment_audit', 'switching_alignment_observables_vs_T.csv');
if exist(fallbackPath, 'file') == 2
    tbl = readtable(fallbackPath);
    [T, I] = extractCenterColumns(tbl);
    I_center = alignCenterToTemps(temps, T, I);
    if any(isfinite(I_center))
        centerSource = "alignment_audit/switching_alignment_observables_vs_T.csv";
        return;
    end
end

error('Could not extract a finite ridge center I_c(T) from switching run: %s', char(switchRunDir));
end

function [T, I] = extractCenterColumns(tbl)
vars = string(tbl.Properties.VariableNames);
T = NaN(height(tbl), 1);
I = NaN(height(tbl), 1);

if any(vars == "T")
    T = double(tbl.T);
elseif any(vars == "T_K")
    T = double(tbl.T_K);
else
    error('Ridge-center table is missing a temperature column (T or T_K).');
end

if any(vars == "I_peak")
    I = double(tbl.I_peak);
elseif any(vars == "Ipeak")
    I = double(tbl.Ipeak);
elseif any(vars == "I_center")
    I = double(tbl.I_center);
else
    error('Ridge-center table is missing an I-center column.');
end
end

function I_aligned = alignCenterToTemps(temps, Tsource, Isource)
I_aligned = NaN(size(temps));
mask = isfinite(Tsource) & isfinite(Isource);
if nnz(mask) < 2
    return;
end
Tsource = Tsource(mask);
Isource = Isource(mask);
[Tsource, iu] = unique(Tsource, 'stable');
Isource = Isource(iu);

[lia, loc] = ismember(temps, Tsource);
I_aligned(lia) = Isource(loc(lia));

missing = ~lia;
if any(missing)
    I_aligned(missing) = interp1(Tsource, Isource, temps(missing), 'pchip', NaN);
end
end

function [ySmooth, dydT] = smoothAndDifferentiate(T, y, window)
ySmooth = NaN(size(y));
dydT = NaN(size(y));
mask = isfinite(T) & isfinite(y);
if nnz(mask) < 3
    return;
end
Tg = T(mask);
Yg = y(mask);
if window >= 2
    Yg = smoothdata(Yg, 'movmean', min(window, numel(Yg)));
end
ySmooth(mask) = Yg;
dydT(mask) = gradient(Yg, Tg);
end

function dS_dI = computeCurrentDerivative(Smap, currents, smoothWindow)
dS_dI = NaN(size(Smap));
for it = 1:size(Smap, 1)
    row = Smap(it, :);
    valid = isfinite(row) & isfinite(currents(:)');
    if nnz(valid) < 2
        continue;
    end
    x = currents(valid);
    y = row(valid);
    if smoothWindow >= 2
        y = smoothdata(y, 'movmean', min(smoothWindow, numel(y)));
    end
    d = gradient(y, x);
    outRow = NaN(size(row));
    outRow(valid) = d;
    dS_dI(it, :) = outRow;
end
end

function [xGrid, fullX, shiftX, shapeX] = remapToShiftedX(currents, I_center, fullMap, shiftMap, shapeMap)
nT = numel(I_center);
fullX = NaN(size(fullMap));
shiftX = NaN(size(shiftMap));
shapeX = NaN(size(shapeMap));

step = median(diff(currents), 'omitnan');
if ~(isfinite(step) && step > 0)
    step = 1;
end

xMinRows = NaN(nT, 1);
xMaxRows = NaN(nT, 1);
for it = 1:nT
    if ~isfinite(I_center(it))
        continue;
    end
    xRow = currents(:) - I_center(it);
    xMinRows(it) = min(xRow, [], 'omitnan');
    xMaxRows(it) = max(xRow, [], 'omitnan');
end

validRange = isfinite(xMinRows) & isfinite(xMaxRows);
if any(validRange)
    xMin = max(xMinRows(validRange));
    xMax = min(xMaxRows(validRange));
else
    xMin = min(currents);
    xMax = max(currents);
end

if ~(isfinite(xMin) && isfinite(xMax) && xMax > xMin)
    xMin = min(currents);
    xMax = max(currents);
end

xStart = ceil(xMin / step) * step;
xStop = floor(xMax / step) * step;
if xStop > xStart
    xGrid = (xStart:step:xStop)';
else
    xGrid = linspace(xMin, xMax, max(3, numel(currents)))';
end

fullX = NaN(nT, numel(xGrid));
shiftX = NaN(nT, numel(xGrid));
shapeX = NaN(nT, numel(xGrid));

for it = 1:nT
    if ~isfinite(I_center(it))
        continue;
    end
    xRow = currents(:) - I_center(it);
    [xRow, iu] = unique(xRow, 'stable');

    fRow = fullMap(it, :);
    sRow = shiftMap(it, :);
    rRow = shapeMap(it, :);
    fRow = fRow(iu);
    sRow = sRow(iu);
    rRow = rRow(iu);

    vf = isfinite(xRow) & isfinite(fRow(:));
    vs = isfinite(xRow) & isfinite(sRow(:));
    vr = isfinite(xRow) & isfinite(rRow(:));

    if nnz(vf) >= 2
        fullX(it, :) = interp1(xRow(vf), fRow(vf), xGrid, 'linear', NaN);
    end
    if nnz(vs) >= 2
        shiftX(it, :) = interp1(xRow(vs), sRow(vs), xGrid, 'linear', NaN);
    end
    if nnz(vr) >= 2
        shapeX(it, :) = interp1(xRow(vr), rRow(vr), xGrid, 'linear', NaN);
    end
end
end

function y = rmsRows(X)
y = sqrt(rowwiseMean(X .^ 2));
end

function y = rowwiseMean(X)
valid = isfinite(X);
counts = sum(valid, 2);
X(~valid) = 0;
y = sum(X, 2) ./ counts;
y(counts == 0) = NaN;
end

function out = safeDivide(a, b)
out = NaN(size(a));
mask = isfinite(a) & isfinite(b) & abs(b) > eps;
out(mask) = a(mask) ./ b(mask);
end

function [T, A] = loadRelaxationAT(tbl)
vars = string(tbl.Properties.VariableNames);
if any(vars == "T")
    T = double(tbl.T(:));
else
    error('Relaxation table is missing T column.');
end
if any(vars == "A_T")
    A = double(tbl.A_T(:));
elseif any(vars == "A")
    A = double(tbl.A(:));
else
    error('Relaxation table is missing A_T or A column.');
end
mask = isfinite(T) & isfinite(A);
T = T(mask);
A = A(mask);
[T, order] = sort(T);
A = A(order);
end

function y = normalizeToMax(x)
y = NaN(size(x));
mask = isfinite(x);
if ~any(mask)
    return;
end
mx = max(abs(x(mask)));
if isfinite(mx) && mx > 0
    y(mask) = x(mask) ./ mx;
end
end

function tbl = buildCorrelationTable(A_interp, chiDyn, chiShift, chiShape)
pairs = { ...
    'chi_dyn_vs_A', chiDyn, A_interp; ...
    'chi_shift_vs_A', chiShift, A_interp; ...
    'chi_shape_vs_A', chiShape, A_interp; ...
    'chi_dyn_vs_chi_shift', chiDyn, chiShift; ...
    'chi_dyn_vs_chi_shape', chiDyn, chiShape};

metric = strings(size(pairs, 1), 1);
pearson_r = NaN(size(pairs, 1), 1);
spearman_r = NaN(size(pairs, 1), 1);
n_points = NaN(size(pairs, 1), 1);

for i = 1:size(pairs, 1)
    x = pairs{i, 2};
    y = pairs{i, 3};
    mask = isfinite(x) & isfinite(y);
    metric(i) = string(pairs{i, 1});
    n_points(i) = nnz(mask);
    pearson_r(i) = corrSafe(x(mask), y(mask));
    spearman_r(i) = spearmanSafe(x(mask), y(mask));
end

tbl = table(metric, pearson_r, spearman_r, n_points);
end

function peakInfo = analyzeLowTPeak(temps, chiDyn, E_shift, E_shape, cfg)
peakInfo = struct();
peakInfo.peakT = findPeakTemperature(temps, chiDyn);

lowMask = isfinite(temps) & temps >= cfg.lowTempMinK & temps <= cfg.lowTempMaxK ...
    & isfinite(chiDyn);
peakInfo.lowPeakT = NaN;
peakInfo.lowPeakIdx = NaN;
if any(lowMask)
    Tlow = temps(lowMask);
    Chilow = chiDyn(lowMask);
    [~, idx] = max(Chilow);
    peakInfo.lowPeakT = Tlow(idx);
    lowIdxGlobal = find(lowMask);
    peakInfo.lowPeakIdx = lowIdxGlobal(idx);
end

idx = peakInfo.lowPeakIdx;
if isfinite(idx)
    peakInfo.lowEshift = E_shift(idx);
    peakInfo.lowEshape = E_shape(idx);
    peakInfo.lowRatio = safeSingleDivide(E_shift(idx), E_shape(idx));
else
    peakInfo.lowEshift = NaN;
    peakInfo.lowEshape = NaN;
    peakInfo.lowRatio = NaN;
end

r = peakInfo.lowRatio;
if isfinite(r)
    if r >= cfg.dominanceRatioThreshold
        peakInfo.verdict = "shift-driven";
    elseif r <= 1 / cfg.dominanceRatioThreshold
        peakInfo.verdict = "shape-driven";
    else
        peakInfo.verdict = "mixed";
    end
else
    peakInfo.verdict = "undetermined";
end
end

function tPeak = findPeakTemperature(T, y)
tPeak = NaN;
mask = isfinite(T) & isfinite(y);
if ~any(mask)
    return;
end
[~, idx] = max(y(mask));
Tvalid = T(mask);
tPeak = Tvalid(idx);
end

function value = safeSingleDivide(a, b)
if ~(isfinite(a) && isfinite(b) && abs(b) > eps)
    value = NaN;
else
    value = a / b;
end
end

function tbl = buildShiftedMapLongTable(temps, xGrid, fullMap, shiftMap, shapeMap)
nT = numel(temps);
nX = numel(xGrid);
nRows = nT * nX;

Tcol = NaN(nRows, 1);
xcol = NaN(nRows, 1);
fullCol = NaN(nRows, 1);
shiftCol = NaN(nRows, 1);
shapeCol = NaN(nRows, 1);

idx = 0;
for it = 1:nT
    for ix = 1:nX
        idx = idx + 1;
        Tcol(idx) = temps(it);
        xcol(idx) = xGrid(ix);
        fullCol(idx) = fullMap(it, ix);
        shiftCol(idx) = shiftMap(it, ix);
        shapeCol(idx) = shapeMap(it, ix);
    end
end

tbl = table(Tcol, xcol, fullCol, shiftCol, shapeCol, ...
    'VariableNames', {'T_K','x_mA','dS_dT_full','dS_dT_shift','dS_dT_shape'});
end

function tbl = buildSourceManifest(source, centerSource)
tbl = table( ...
    ["switching"; "switching"; "relaxation"], ...
    [source.switchRunName; source.switchRunName; source.relaxRunName], ...
    string({ ...
    fullfile(char(source.switchRunDir), 'switching_alignment_core_data.mat'); ...
    fullfile(char(source.switchRunDir), char(centerSource)); ...
    fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv')}), ...
    ["S(I,T) map source"; "Ridge center I_c(T) source"; "Relaxation A(T) source"], ...
    'VariableNames', {'experiment','source_run','source_file','role'});
end

function figPaths = saveComponentHeatmap(temps, xGrid, mapData, ttl, cbLabel, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 17.0 10.0]);
ax = axes(fig);
imagesc(ax, xGrid, temps, mapData);
axis(ax, 'xy');
colormap(ax, blueWhiteRedMap(256));
lim = finiteMaxAbs(mapData);
if ~(isfinite(lim) && lim > 0)
    lim = 1;
end
caxis(ax, [-lim lim]);
cb = colorbar(ax);
cb.Label.String = cbLabel;
xlabel(ax, 'x = I - I_c(T) (mA)');
ylabel(ax, 'Temperature (K)');
title(ax, ttl);
styleAxis(ax, true);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveChiVsTFigure(temps, chiDyn, chiShift, chiShape, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 16.2 9.2]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, temps, chiDyn, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', 'chi_dyn(T)');
plot(ax, temps, chiShift, '-s', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', 'chi_shift(T)');
plot(ax, temps, chiShape, '-^', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', 'chi_shape(T)');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'RMS_x derivative amplitude (signal/K)');
title(ax, 'Dynamical susceptibility decomposition versus temperature');
legend(ax, 'Location', 'best', 'Box', 'off');
styleAxis(ax, false);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveOverlayWithAFigure(temps, chiDynNorm, chiShiftNorm, chiShapeNorm, A_norm, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 16.2 9.2]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, temps, chiDynNorm, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', 'chi_dyn/max');
plot(ax, temps, chiShiftNorm, '-s', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', 'chi_shift/max');
plot(ax, temps, chiShapeNorm, '-^', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', 'chi_shape/max');
plot(ax, temps, A_norm, '--d', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', 'A(T)/max');
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Normalized amplitude (arb. units)');
title(ax, 'Normalized susceptibility components and relaxation A(T)');
ylim(ax, [-0.05 1.05]);
legend(ax, 'Location', 'best', 'Box', 'off');
styleAxis(ax, false);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveScatterFigure(x, y, temps, xLabel, yLabel, runDir, figureName)
mask = isfinite(x) & isfinite(y) & isfinite(temps);
fig = create_figure('Visible', 'off', 'Position', [2 2 13.0 9.0]);
ax = axes(fig);
scatter(ax, x(mask), y(mask), 56, temps(mask), 'filled');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
xlabel(ax, xLabel);
ylabel(ax, yLabel);
title(ax, sprintf('%s versus %s', yLabel, xLabel));
styleAxis(ax, false);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveEnergyFractionFigure(temps, shiftFrac, shapeFrac, peakInfo, runDir, figureName)
fig = create_figure('Visible', 'off', 'Position', [2 2 16.2 9.2]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, temps, shiftFrac, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', 'E_shift/(E_shift+E_shape)');
plot(ax, temps, shapeFrac, '-s', 'LineWidth', 2.2, 'MarkerSize', 6, ...
    'DisplayName', 'E_shape/(E_shift+E_shape)');
if isfinite(peakInfo.lowPeakT)
    xline(ax, peakInfo.lowPeakT, '--', 'LineWidth', 1.8, ...
        'DisplayName', sprintf('low-T peak %.1f K', peakInfo.lowPeakT));
end
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Energy fraction');
title(ax, sprintf('Shift-versus-shape energy fractions (%s)', char(peakInfo.verdict)));
ylim(ax, [-0.05 1.05]);
legend(ax, 'Location', 'best', 'Box', 'off');
styleAxis(ax, false);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function textOut = buildReportText(cfg, source, centerSource, peakInfo, corrTbl, xGrid, runDir)
line = strings(0, 1);
line(end + 1) = '# Switching chi_dyn decomposition report';
line(end + 1) = '';
line(end + 1) = '## Repository-state summary';
line(end + 1) = sprintf('- Switching source run: `%s`', source.switchRunName);
line(end + 1) = sprintf('- Relaxation source run: `%s`', source.relaxRunName);
line(end + 1) = '- Reused derivative engine: `analysis/switching_dynamical_susceptibility.m`.';
line(end + 1) = sprintf('- Reused ridge coordinate source: `%s`.', centerSource);
line(end + 1) = '';
line(end + 1) = '## Definitions';
line(end + 1) = '- Ridge coordinate: `I_c(T) = I_peak(T)`.';
line(end + 1) = '- Shifted current coordinate: `x = I - I_c(T)`.';
line(end + 1) = '- Full derivative: `D_full = dS/dT` (at fixed I, then remapped to x-grid).';
line(end + 1) = '- Shift term: `D_shift = -(dS/dI) dI_c/dT`.';
line(end + 1) = '- Shape term: `D_shape = D_full - D_shift`.';
line(end + 1) = '- Susceptibilities: `chi_dyn = RMS_x(D_full)`, `chi_shift = RMS_x(D_shift)`, `chi_shape = RMS_x(D_shape)`.';
line(end + 1) = '';
line(end + 1) = '## Derivative and interpolation settings';
line(end + 1) = sprintf('- Temperature smoothing before `dS/dT`: %d-point moving mean.', cfg.tempSmoothWindow);
line(end + 1) = sprintf('- Current smoothing before `dS/dI`: %d-point moving mean.', cfg.currentSmoothWindow);
line(end + 1) = sprintf('- Ridge smoothing before `dI_c/dT`: %d-point moving mean.', cfg.ridgeSmoothWindow);
line(end + 1) = sprintf('- Common shifted grid size: %d points, x-range `[%.3g, %.3g]` mA.', ...
    numel(xGrid), min(xGrid), max(xGrid));
line(end + 1) = '';
line(end + 1) = '## Main decomposition result';
line(end + 1) = sprintf('- Global peak of `chi_dyn(T)`: `%.3f K`.', peakInfo.peakT);
line(end + 1) = sprintf('- Low-T analysis band: `[%.1f, %.1f] K`.', cfg.lowTempMinK, cfg.lowTempMaxK);
line(end + 1) = sprintf('- Low-T peak temperature: `%.3f K`.', peakInfo.lowPeakT);
line(end + 1) = sprintf('- At low-T peak: `E_shift = %.4g`, `E_shape = %.4g`, `E_shift/E_shape = %.4g`.', ...
    peakInfo.lowEshift, peakInfo.lowEshape, peakInfo.lowRatio);
line(end + 1) = sprintf('- Verdict for low-T peak: **%s**.', char(peakInfo.verdict));
line(end + 1) = '';
line(end + 1) = '## Correlations';
for i = 1:height(corrTbl)
    line(end + 1) = sprintf('- `%s`: Pearson `%.4f`, Spearman `%.4f` (n=%d).', ...
        corrTbl.metric(i), corrTbl.pearson_r(i), corrTbl.spearman_r(i), corrTbl.n_points(i));
end
line(end + 1) = '';
line(end + 1) = '## Output artifacts';
line(end + 1) = sprintf('- Run directory: `%s`', runDir);
line(end + 1) = '- `tables/chi_decomposition_vs_T.csv`';
line(end + 1) = '- `tables/chi_decomposition_correlations.csv`';
line(end + 1) = '- `tables/chi_decomposition_shifted_maps.csv`';
line(end + 1) = '- `figures/chi_decomposition_*` (heatmaps and comparison plots)';
line(end + 1) = '- `reports/chi_shift_shape_decomposition_report.md`';
line(end + 1) = '- `review/chi_shift_shape_decomposition_bundle.zip`';
line(end + 1) = '';
line(end + 1) = '## Visualization choices';
line(end + 1) = '- number of curves: up to 4 curves in line overlays; single curve-pair in energy-fraction plot; single scatter cloud in each A-comparison scatter.';
line(end + 1) = '- legend vs colormap: legends for line plots (<=6 curves); parula+colorbar for scatter temperature encoding; diverging map for signed derivative heatmaps.';
line(end + 1) = '- colormap used: custom blue-white-red for signed derivatives, parula for scatter panels.';
line(end + 1) = '- smoothing applied: light moving-mean smoothing along T and I only for derivative stability.';
line(end + 1) = '- justification: this set isolates map-level decomposition and direct comparisons requested for chi_dyn, chi_shift, chi_shape, and A(T).';
textOut = strjoin(line, newline);
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

function r = corrSafe(x, y)
x = x(:);
y = y(:);
mask = isfinite(x) & isfinite(y);
r = NaN;
if nnz(mask) < 3
    return;
end
c = corrcoef(x(mask), y(mask));
if numel(c) >= 4
    r = c(1, 2);
end
end

function rho = spearmanSafe(x, y)
rho = corrSafe(tiedRank(x), tiedRank(y));
end

function r = tiedRank(x)
x = x(:);
r = NaN(size(x));
valid = isfinite(x);
if ~any(valid)
    return;
end
xs = x(valid);
[xsSorted, order] = sort(xs);
ranks = zeros(size(xsSorted));
ii = 1;
while ii <= numel(xsSorted)
    jj = ii;
    while jj < numel(xsSorted) && xsSorted(jj + 1) == xsSorted(ii)
        jj = jj + 1;
    end
    ranks(ii:jj) = mean(ii:jj);
    ii = jj + 1;
end
tmp = zeros(size(xsSorted));
tmp(order) = ranks;
r(valid) = tmp;
end

function cmap = blueWhiteRedMap(n)
if nargin < 1 || isempty(n)
    n = 256;
end
half = floor(n / 2);
blue = [0.23 0.30 0.75];
white = [1.00 1.00 1.00];
red = [0.71 0.02 0.15];
down = [linspace(blue(1), white(1), half)', ...
    linspace(blue(2), white(2), half)', ...
    linspace(blue(3), white(3), half)'];
up = [linspace(white(1), red(1), n - half)', ...
    linspace(white(2), red(2), n - half)', ...
    linspace(white(3), red(3), n - half)'];
cmap = [down; up];
end

function value = finiteMaxAbs(x)
x = abs(double(x(:)));
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x);
end
end

function styleAxis(ax, isHeatmap)
if nargin < 2
    isHeatmap = false;
end
if isHeatmap
    boxMode = 'on';
else
    boxMode = 'off';
end
set(ax, 'FontName', 'Helvetica', 'FontSize', 14, 'LineWidth', 1.1, ...
    'TickDir', 'out', 'Box', boxMode, 'Layer', 'top');
grid(ax, 'on');
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

function cfg = setDefaultField(cfg, fieldName, value)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = value;
end
end
