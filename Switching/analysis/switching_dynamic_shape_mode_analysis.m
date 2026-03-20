function out = switching_dynamic_shape_mode_analysis(cfg)
% switching_dynamic_shape_mode_analysis
% Identify dominant shape-evolution mode in dS/dT after removing ridge motion.
%
% Workflow:
% 1) Load saved switching map S(I,T) from an existing alignment run.
% 2) Compute stable temperature derivative D = dS/dT (light T smoothing + finite difference).
% 3) Build shift-only ridge-motion derivative model and subtract it.
% 4) SVD on residual derivative field to extract spatial modes phi_k(I) and amplitudes a_k(T).
% 5) Compare leading shape-mode amplitude with chi_dyn(T).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);
source = resolveSourcePaths(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('alignment:%s | full_scaling:%s', ...
    char(source.alignmentRunId), char(source.fullScalingRunId));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching dynamic-shape-mode run directory:\n%s\n', runDir);
fprintf('Alignment source run: %s\n', source.alignmentRunId);
fprintf('Full-scaling source run: %s\n', source.fullScalingRunId);

appendText(run.log_path, sprintf('[%s] switching dynamic-shape-mode started\n', stampNow()));
appendText(run.log_path, sprintf('Alignment source: %s\n', char(source.alignmentRunId)));
appendText(run.log_path, sprintf('Full-scaling source: %s\n', char(source.fullScalingRunId)));

core = load(source.alignmentCorePath, 'Smap', 'temps', 'currents');
paramsTbl = readtable(source.fullScalingParamsPath);
paramsTbl = sortrows(paramsTbl, 'T_K');

tempsAll = core.temps(:);
currents = core.currents(:);
SmapAll = core.Smap;

tMask = paramsTbl.T_K >= cfg.temperatureMinK & paramsTbl.T_K <= cfg.temperatureMaxK;
paramsTbl = paramsTbl(tMask, :);
assert(~isempty(paramsTbl), 'No full-scaling rows remain in requested temperature range.');

[temps, iMap, iPar] = intersect(tempsAll, paramsTbl.T_K, 'stable');
assert(~isempty(temps), ...
    'No common temperatures between alignment map and full-scaling observables.');

Smap = SmapAll(iMap, :);
Ipeak = paramsTbl.Ipeak_mA(iPar);
Speak = paramsTbl.S_peak(iPar);

validRows = isfinite(temps) & isfinite(Ipeak) & isfinite(Speak);
validRows = validRows & (Speak > cfg.speakFloorFraction * max(Speak, [], 'omitnan'));

temps = temps(validRows);
Ipeak = Ipeak(validRows);
Smap = Smap(validRows, :);
Speak = Speak(validRows); %#ok<NASGU>

assert(numel(temps) >= 5, ...
    'Too few valid temperature rows after filtering for derivative analysis.');

SmapFilled = fillMissingByColumn(Smap, temps);
SmapSmoothed = smoothAlongTemperature(SmapFilled, cfg.smoothWindowT);

D = derivativeAlongTemperature(SmapSmoothed, temps);
dSdI = derivativeAlongCurrent(SmapSmoothed, currents);
dIpeak_dT = gradient(Ipeak, temps);

D_shift = dSdI .* (-dIpeak_dT);
D_residual = D - D_shift;

chiDyn = sqrt(mean(D .^ 2, 2, 'omitnan'));

Dsvd = D_residual;
Dsvd(~isfinite(Dsvd)) = 0;
[U, Sigma, V] = svd(Dsvd, 'econ');
singvals = diag(Sigma);
nAllModes = numel(singvals);
nModes = min([cfg.numModes, size(U, 2), size(V, 2), nAllModes]);
assert(nModes >= 1, 'SVD did not return valid modes.');

phi = V(:, 1:nModes);
amps = U(:, 1:nModes) .* singvals(1:nModes)';

for k = 1:nModes
    c = safeCorr(amps(:, k), chiDyn);
    if isfinite(c) && c < 0
        phi(:, k) = -phi(:, k);
        amps(:, k) = -amps(:, k);
    end
end

ridgeTemplate = mean(dSdI, 1, 'omitnan')';
ridgeTemplate = ridgeTemplate / max(norm(ridgeTemplate), eps);

corrRidge = NaN(nModes, 1);
corrAChi = NaN(nModes, 1);
corrAbsAChi = NaN(nModes, 1);
for k = 1:nModes
    corrRidge(k) = safeCorr(phi(:, k), ridgeTemplate);
    corrAChi(k) = safeCorr(amps(:, k), chiDyn);
    corrAbsAChi(k) = safeCorr(abs(amps(:, k)), chiDyn);
end

leadingShapeMode = 1;
ridgeModeExcluded = false;
if nModes >= 2 && isfinite(corrRidge(1)) && abs(corrRidge(1)) >= cfg.ridgeCorrThreshold
    leadingShapeMode = 2;
    ridgeModeExcluded = true;
end

shapeAmp = amps(:, leadingShapeMode);
shapeAmpAbs = abs(shapeAmp);
shapePhi = phi(:, leadingShapeMode);

[~, iChiPeak] = max(chiDyn);
[~, iShapePeak] = max(shapeAmpAbs);
chiPeakTempK = temps(iChiPeak);
shapePeakTempK = temps(iShapePeak);
shapePeaksNearTarget = shapePeakTempK >= cfg.targetPeakWindowK(1) && ...
    shapePeakTempK <= cfg.targetPeakWindowK(2);

shapeCorr = safeCorr(shapeAmp, chiDyn);
shapeAbsCorr = safeCorr(shapeAmpAbs, chiDyn);

dominanceMode = leadingShapeMode;
if dominanceMode < nAllModes
    dominanceRatio = singvals(dominanceMode) / max(singvals(dominanceMode + 1), eps);
else
    dominanceRatio = Inf;
end
singleDominantShapeMode = dominanceRatio >= cfg.singleModeRatioThreshold;

zc = countZeroCrossings(shapePhi);
[~, iMaxAbsPhi] = max(abs(shapePhi));
peakCurrent_mA = currents(iMaxAbsPhi);
if zc == 0
    shapeDescriptor = "single-lobe (no zero crossing)";
elseif zc == 1
    shapeDescriptor = "bipolar (one zero crossing)";
else
    shapeDescriptor = sprintf('multi-lobe (%d zero crossings)', zc);
end

svNorm = singvals / max(sum(singvals, 'omitnan'), eps);
svCum = cumsum(singvals .^ 2, 'omitnan') / max(sum(singvals .^ 2, 'omitnan'), eps);

corrRidgeAll = NaN(nAllModes, 1);
corrAChiAll = NaN(nAllModes, 1);
corrAbsAChiAll = NaN(nAllModes, 1);
corrRidgeAll(1:nModes) = corrRidge;
corrAChiAll(1:nModes) = corrAChi;
corrAbsAChiAll(1:nModes) = corrAbsAChi;

singularValuesTbl = table( ...
    (1:nAllModes)', singvals, svNorm, svCum, corrRidgeAll, corrAChiAll, corrAbsAChiAll, ...
    'VariableNames', {'mode', 'singular_value', 'normalized_singular_value', ...
    'cumulative_energy', 'corr_phi_with_ridge_template', ...
    'corr_ak_with_chi_dyn', 'corr_abs_ak_with_chi_dyn'});
singularValuesPath = save_run_table(singularValuesTbl, ...
    'switching_dynamic_shape_singular_values.csv', runDir);

correlationTbl = table( ...
    (1:nModes)', corrAChi, corrAbsAChi, corrRidge, ...
    'VariableNames', {'mode', 'corr_ak_with_chi_dyn', ...
    'corr_abs_ak_with_chi_dyn', 'corr_phi_with_ridge_template'});
correlationPath = save_run_table(correlationTbl, ...
    'switching_dynamic_shape_correlations.csv', runDir);

phiNames = arrayfun(@(k) sprintf('phi_%d', k), 1:nModes, 'UniformOutput', false);
phiTbl = array2table(phi, 'VariableNames', phiNames);
phiTbl = addvars(phiTbl, currents, 'Before', 1, 'NewVariableNames', 'current_mA');
phiPath = save_run_table(phiTbl, 'switching_dynamic_shape_modes_phi.csv', runDir);

ampTbl = table(temps, chiDyn, dIpeak_dT, ...
    'VariableNames', {'T_K', 'chi_dyn', 'dIpeak_dT'});
for k = 1:nModes
    ampTbl.(sprintf('a_%d', k)) = amps(:, k);
end
ampTbl.leading_shape_mode = repmat(leadingShapeMode, numel(temps), 1);
ampTbl.leading_shape_abs = shapeAmpAbs;
amplitudePath = save_run_table(ampTbl, ...
    'switching_dynamic_shape_mode_amplitudes.csv', runDir);

sourceManifestTbl = table( ...
    string({'alignment_core_map'; 'full_scaling_parameters'}), ...
    [source.alignmentRunId; source.fullScalingRunId], ...
    string({source.alignmentCorePath; source.fullScalingParamsPath}), ...
    'VariableNames', {'source_role', 'source_run_id', 'source_file'});
sourceManifestPath = save_run_table(sourceManifestTbl, ...
    'switching_dynamic_shape_sources.csv', runDir);

figChi = makeLineFigure();
axChi = axes(figChi);
plot(axChi, temps, chiDyn, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6);
xlabel(axChi, 'Temperature (K)');
ylabel(axChi, '\chi_{dyn}(T) (P2P percent/K)');
title(axChi, 'Dynamic susceptibility from temperature derivative');
styleAxes(axChi);
figChiPath = save_run_figure(figChi, 'switching_dynamic_shape_chi_dyn_vs_T', runDir);
close(figChi);

figSpec = makeLineFigure();
axSpec = axes(figSpec);
nShow = min(10, nAllModes);
semilogy(axSpec, 1:nShow, singvals(1:nShow), '-o', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6);
xlabel(axSpec, 'Mode index k');
ylabel(axSpec, 'Singular value \sigma_k');
title(axSpec, 'SVD spectrum of D_{residual}(I,T)');
styleAxes(axSpec);
figSpecPath = save_run_figure(figSpec, 'switching_dynamic_shape_singular_spectrum', runDir);
close(figSpec);

figPhi = makeLineFigure();
axPhi = axes(figPhi);
hold(axPhi, 'on');
plotColors = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];
markers = {'-o', '-s', '-^'};
for k = 1:min(3, nModes)
    plot(axPhi, currents, phi(:, k), markers{k}, ...
        'LineWidth', 2.2, 'MarkerSize', 6, ...
        'Color', plotColors(k, :), 'DisplayName', sprintf('\\phi_%d(I)', k));
end
hold(axPhi, 'off');
xlabel(axPhi, 'Current (mA)');
ylabel(axPhi, '\phi_k(I) (a.u.)');
title(axPhi, 'First spatial modes of D_{residual}');
legend(axPhi, 'Location', 'best');
styleAxes(axPhi);
figPhiPath = save_run_figure(figPhi, 'switching_dynamic_shape_spatial_modes', runDir);
close(figPhi);

figAmp = makeLineFigure();
axAmp = axes(figAmp);
hold(axAmp, 'on');
for k = 1:min(3, nModes)
    plot(axAmp, temps, amps(:, k), markers{k}, ...
        'LineWidth', 2.2, 'MarkerSize', 6, ...
        'Color', plotColors(k, :), 'DisplayName', sprintf('a_%d(T)', k));
end
hold(axAmp, 'off');
xlabel(axAmp, 'Temperature (K)');
ylabel(axAmp, 'Mode amplitude a_k(T) (a.u.)');
title(axAmp, 'Temperature amplitudes for first shape modes');
legend(axAmp, 'Location', 'best');
styleAxes(axAmp);
figAmpPath = save_run_figure(figAmp, 'switching_dynamic_shape_mode_amplitudes', runDir);
close(figAmp);

chiNorm = normalize01(chiDyn);
shapeNorm = normalize01(shapeAmpAbs);
figOverlay = makeLineFigure();
axOverlay = axes(figOverlay);
hold(axOverlay, 'on');
plot(axOverlay, temps, chiNorm, '-o', 'LineWidth', 2.3, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', '\chi_{dyn}(T) normalized');
plot(axOverlay, temps, shapeNorm, '-s', 'LineWidth', 2.3, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, ...
    'DisplayName', sprintf('|a_{%d}(T)| normalized', leadingShapeMode));
hold(axOverlay, 'off');
xlabel(axOverlay, 'Temperature (K)');
ylabel(axOverlay, 'Normalized amplitude (0 to 1)');
title(axOverlay, sprintf('Overlay: \\chi_{dyn}(T) vs leading shape mode |a_{%d}(T)|', ...
    leadingShapeMode));
legend(axOverlay, 'Location', 'best');
styleAxes(axOverlay);
figOverlayPath = save_run_figure(figOverlay, ...
    'switching_dynamic_shape_overlay_chi_vs_mode', runDir);
close(figOverlay);

reportText = buildReportText( ...
    source, temps, currents, singularValuesTbl, correlationTbl, ...
    leadingShapeMode, ridgeModeExcluded, singleDominantShapeMode, ...
    shapeDescriptor, peakCurrent_mA, shapePeakTempK, chiPeakTempK, ...
    shapePeaksNearTarget, shapeCorr, shapeAbsCorr, dominanceRatio, ...
    cfg, figChiPath, figSpecPath, figPhiPath, figAmpPath, figOverlayPath, ...
    singularValuesPath, correlationPath, phiPath, amplitudePath, sourceManifestPath);
reportPath = save_run_report(reportText, ...
    'switching_dynamic_shape_mode_report.md', runDir);

appendText(run.notes_path, sprintf('Leading shape mode index = %d\n', leadingShapeMode));
appendText(run.notes_path, sprintf('Ridge-mode excluded = %d\n', ridgeModeExcluded));
appendText(run.notes_path, sprintf('shape peak temperature = %.2f K\n', shapePeakTempK));
appendText(run.notes_path, sprintf('chi_dyn peak temperature = %.2f K\n', chiPeakTempK));
appendText(run.notes_path, sprintf('corr(|a_leading|, chi_dyn) = %.4f\n', shapeAbsCorr));

zipPath = buildReviewZip(runDir, 'switching_dynamic_shape_mode_bundle.zip');

appendText(run.log_path, sprintf('[%s] switching dynamic-shape-mode complete\n', stampNow()));
appendText(run.log_path, sprintf('Singular values: %s\n', singularValuesPath));
appendText(run.log_path, sprintf('Correlations: %s\n', correlationPath));
appendText(run.log_path, sprintf('Spatial modes: %s\n', phiPath));
appendText(run.log_path, sprintf('Amplitudes: %s\n', amplitudePath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.temps = temps;
out.currents = currents;
out.leadingShapeMode = leadingShapeMode;
out.singleDominantShapeMode = singleDominantShapeMode;
out.shapePeakTempK = shapePeakTempK;
out.chiPeakTempK = chiPeakTempK;
out.shapePeaksNearTarget = shapePeaksNearTarget;
out.shapeCorr = shapeCorr;
out.shapeAbsCorr = shapeAbsCorr;
out.paths = struct( ...
    'singularValues', string(singularValuesPath), ...
    'correlations', string(correlationPath), ...
    'spatialModes', string(phiPath), ...
    'amplitudes', string(amplitudePath), ...
    'sourceManifest', string(sourceManifestPath), ...
    'report', string(reportPath), ...
    'zip', string(zipPath), ...
    'chiFigure', string(figChiPath.png), ...
    'spectrumFigure', string(figSpecPath.png), ...
    'spatialFigure', string(figPhiPath.png), ...
    'amplitudeFigure', string(figAmpPath.png), ...
    'overlayFigure', string(figOverlayPath.png));

fprintf('\n=== Switching dynamic-shape-mode analysis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Leading shape mode index: %d\n', leadingShapeMode);
fprintf('Shape-peak temperature: %.2f K\n', shapePeakTempK);
fprintf('chi_dyn peak temperature: %.2f K\n', chiPeakTempK);
fprintf('corr(|a_leading|, chi_dyn): %.4f\n', shapeAbsCorr);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_dynamic_shape_mode');
cfg = setDefault(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefault(cfg, 'temperatureMinK', 4);
cfg = setDefault(cfg, 'temperatureMaxK', 30);
cfg = setDefault(cfg, 'smoothWindowT', 3);
cfg = setDefault(cfg, 'numModes', 3);
cfg = setDefault(cfg, 'ridgeCorrThreshold', 0.70);
cfg = setDefault(cfg, 'singleModeRatioThreshold', 1.5);
cfg = setDefault(cfg, 'targetPeakWindowK', [10, 12]);
cfg = setDefault(cfg, 'speakFloorFraction', 1e-3);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.alignmentRunId = string(cfg.alignmentRunId);
source.fullScalingRunId = string(cfg.fullScalingRunId);
source.alignmentRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.alignmentRunId));
source.fullScalingRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    char(source.fullScalingRunId));
source.alignmentCorePath = fullfile(source.alignmentRunDir, ...
    'switching_alignment_core_data.mat');
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', ...
    'switching_full_scaling_parameters.csv');

requiredFiles = {source.alignmentCorePath, source.fullScalingParamsPath};
for i = 1:numel(requiredFiles)
    if exist(requiredFiles{i}, 'file') ~= 2
        error('Required source file missing: %s', requiredFiles{i});
    end
end
end

function fig = makeLineFigure()
fig = figure('Color', 'w', 'Visible', 'off');
set(fig, 'Units', 'centimeters', 'Position', [2 2 8.6 6.2], ...
    'PaperUnits', 'centimeters', 'PaperPosition', [0 0 8.6 6.2], ...
    'PaperSize', [8.6 6.2]);
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
grid(ax, 'on');
end

function Xout = smoothAlongTemperature(Xin, window)
Xout = Xin;
if window <= 1
    return;
end
for j = 1:size(Xin, 2)
    Xout(:, j) = movmean(Xin(:, j), window, 'omitnan', 'Endpoints', 'shrink');
end
end

function Xfilled = fillMissingByColumn(Xin, xAxis)
Xfilled = Xin;
for j = 1:size(Xin, 2)
    col = Xin(:, j);
    finiteMask = isfinite(col);
    if nnz(finiteMask) < 2
        continue;
    end
    if any(~finiteMask)
        Xfilled(~finiteMask, j) = interp1(xAxis(finiteMask), col(finiteMask), ...
            xAxis(~finiteMask), 'linear', 'extrap');
    end
end
end

function D = derivativeAlongTemperature(Smap, temps)
D = NaN(size(Smap));
for j = 1:size(Smap, 2)
    D(:, j) = gradient(Smap(:, j), temps);
end
end

function dSdI = derivativeAlongCurrent(Smap, currents)
dSdI = NaN(size(Smap));
for it = 1:size(Smap, 1)
    dSdI(it, :) = gradient(Smap(it, :), currents);
end
end

function c = safeCorr(x, y)
x = x(:);
y = y(:);
m = isfinite(x) & isfinite(y);
if nnz(m) < 3
    c = NaN;
    return;
end
c = corr(x(m), y(m));
end

function out = normalize01(x)
x = x(:);
mn = min(x, [], 'omitnan');
mx = max(x, [], 'omitnan');
if ~isfinite(mn) || ~isfinite(mx) || mx <= mn
    out = zeros(size(x));
else
    out = (x - mn) ./ (mx - mn);
end
end

function n = countZeroCrossings(x)
x = x(:);
x = x(isfinite(x));
if numel(x) < 2
    n = 0;
    return;
end
s = sign(x);
for i = 2:numel(s)
    if s(i) == 0
        s(i) = s(i - 1);
    end
end
s(s == 0) = 1;
n = nnz(diff(s) ~= 0);
end

function reportText = buildReportText( ...
    source, temps, currents, singularValuesTbl, correlationTbl, ...
    leadingShapeMode, ridgeModeExcluded, singleDominantShapeMode, ...
    shapeDescriptor, peakCurrent_mA, shapePeakTempK, chiPeakTempK, ...
    shapePeaksNearTarget, shapeCorr, shapeAbsCorr, dominanceRatio, ...
    cfg, figChiPath, figSpecPath, figPhiPath, figAmpPath, figOverlayPath, ...
    singularValuesPath, correlationPath, phiPath, amplitudePath, sourceManifestPath)

if singleDominantShapeMode
    dominantText = "A single dominant shape mode is present in D_residual.";
else
    dominantText = "Shape evolution is multi-mode; the leading mode is not strongly isolated.";
end

if ridgeModeExcluded
    ridgeText = sprintf(['Mode 1 showed strong ridge-template alignment (threshold = %.2f), ', ...
        'so mode 2 was selected as the leading shape mode.'], cfg.ridgeCorrThreshold);
else
    ridgeText = "Mode 1 was retained as the leading shape mode (no strong ridge-template contamination).";
end

if shapePeaksNearTarget
    peakText = sprintf(['The leading shape-mode amplitude peaks at %.2f K, within the target ', ...
        '10-12 K window.'], shapePeakTempK);
else
    peakText = sprintf(['The leading shape-mode amplitude peaks at %.2f K, outside the target ', ...
        '10-12 K window.'], shapePeakTempK);
end

lines = strings(0, 1);
lines(end + 1) = "# Switching dynamic shape-mode report";
lines(end + 1) = "";
lines(end + 1) = "## Data sources";
lines(end + 1) = "- Alignment run (map source): `" + source.alignmentRunId + "`.";
lines(end + 1) = "- Full-scaling run (ridge observables source): `" + source.fullScalingRunId + "`.";
lines(end + 1) = "- Source manifest table: `" + string(sourceManifestPath) + "`.";
lines(end + 1) = "- Temperature range analyzed: `" + sprintf('%.1f-%.1f K', min(temps), max(temps)) + "` (" + string(numel(temps)) + " rows).";
lines(end + 1) = "- Current grid analyzed: `" + sprintf('%d points (%.1f to %.1f mA)', numel(currents), min(currents), max(currents)) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Method summary";
lines(end + 1) = "- Temperature derivative: `D(I,T) = dS/dT` with a light moving-average smoothing window of `" + string(cfg.smoothWindowT) + "` temperature points before finite differences.";
lines(end + 1) = "- Ridge-motion model: `D_{shift}(I,T) = -(dI_{peak}/dT) * (dS/dI)`.";
lines(end + 1) = "- Residual for shape evolution: `D_{residual}(I,T) = D - D_{shift}`.";
lines(end + 1) = "- SVD decomposition: `D_{residual} = U \\Sigma V^T`, with `\\phi_k(I)=V(:,k)` and `a_k(T)=U(:,k)\\sigma_k`.";
lines(end + 1) = "";
lines(end + 1) = "## Requested conclusions";
lines(end + 1) = "1. Dominant mode existence: " + dominantText + " (dominance ratio = `" + sprintf('%.3f', dominanceRatio) + "`).";
lines(end + 1) = "2. Spatial structure: the selected shape mode is `" + shapeDescriptor + "` with largest absolute weight near `" + sprintf('%.2f mA', peakCurrent_mA) + "`.";
lines(end + 1) = "3. Peak near 10-12 K: " + peakText + " (`chi_dyn` peak is at `" + sprintf('%.2f K', chiPeakTempK) + "`).";
lines(end + 1) = "4. Agreement with `chi_dyn`: `corr(a_leading, chi_dyn) = " + sprintf('%.4f', shapeCorr) + "`, `corr(|a_leading|, chi_dyn) = " + sprintf('%.4f', shapeAbsCorr) + "`.";
lines(end + 1) = "- Ridge exclusion decision: " + ridgeText;
lines(end + 1) = "";
lines(end + 1) = "## Figures";
lines(end + 1) = "- `chi_dyn(T)`: `" + string(figChiPath.png) + "`.";
lines(end + 1) = "- Singular spectrum: `" + string(figSpecPath.png) + "`.";
lines(end + 1) = "- First spatial modes: `" + string(figPhiPath.png) + "`.";
lines(end + 1) = "- Mode amplitudes: `" + string(figAmpPath.png) + "`.";
lines(end + 1) = "- Overlay `a_k(T)` vs `chi_dyn(T)`: `" + string(figOverlayPath.png) + "`.";
lines(end + 1) = "";
lines(end + 1) = "![chi_dyn](../figures/switching_dynamic_shape_chi_dyn_vs_T.png)";
lines(end + 1) = "";
lines(end + 1) = "![spectrum](../figures/switching_dynamic_shape_singular_spectrum.png)";
lines(end + 1) = "";
lines(end + 1) = "![spatial_modes](../figures/switching_dynamic_shape_spatial_modes.png)";
lines(end + 1) = "";
lines(end + 1) = "![amplitudes](../figures/switching_dynamic_shape_mode_amplitudes.png)";
lines(end + 1) = "";
lines(end + 1) = "![overlay](../figures/switching_dynamic_shape_overlay_chi_vs_mode.png)";
lines(end + 1) = "";
lines(end + 1) = "## Tables and saved mode files";
lines(end + 1) = "- Singular values: `" + string(singularValuesPath) + "`.";
lines(end + 1) = "- Correlations (`a_k` vs `chi_dyn`): `" + string(correlationPath) + "`.";
lines(end + 1) = "- Spatial modes `\\phi_k(I)`: `" + string(phiPath) + "`.";
lines(end + 1) = "- Mode amplitudes `a_k(T)`: `" + string(amplitudePath) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Quick numeric summary";
lines(end + 1) = "- Leading shape mode index: `" + string(leadingShapeMode) + "`.";
lines(end + 1) = "- Cumulative SVD energy at mode 1: `" + sprintf('%.4f', singularValuesTbl.cumulative_energy(1)) + "`.";
if height(singularValuesTbl) >= 2
    lines(end + 1) = "- Cumulative SVD energy at mode 2: `" + sprintf('%.4f', singularValuesTbl.cumulative_energy(2)) + "`.";
end
lines(end + 1) = "- Correlation table rows: `" + string(height(correlationTbl)) + "`.";
lines(end + 1) = "";
lines(end + 1) = "## Visualization choices";
lines(end + 1) = "- number of curves: 1 curve for `chi_dyn`, 1 curve for spectrum, 3 curves for spatial modes, 3 curves for amplitudes, 2 curves for overlay";
lines(end + 1) = "- legend vs colormap: legends used (all multi-curve panels have <= 6 curves)";
lines(end + 1) = "- colormap used: none (line plots only)";
lines(end + 1) = "- smoothing applied: moving-average over temperature with window = " + string(cfg.smoothWindowT) + " prior to finite-difference derivative";
lines(end + 1) = "- justification: line plots directly answer mode-spectrum and amplitude-vs-temperature questions with minimal ambiguity";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

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
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
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
