function out = switching_residual_collapse_verification_analysis(cfg)
% switching_residual_collapse_verification_analysis
% Verify whether the residual after full collapse aligns with saved dynamic phi_1.

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
runCfg.dataset = sprintf('dynamic_shape_source:%s', char(source.dynamicShapeRunId));
run = createSwitchingRunContext(repoRoot, runCfg);
runDir = run.run_dir;

fprintf('Switching residual-collapse verification run directory:\n%s\n', runDir);
fprintf('Dynamic-shape source run: %s\n', source.dynamicShapeRunId);

appendText(run.log_path, sprintf('[%s] switching residual-collapse verification started\n', stampNow()));
appendText(run.log_path, sprintf('Dynamic-shape source: %s\n', char(source.dynamicShapeRunId)));

sourceCell = readcell(source.dynamicSourcesPath, 'Delimiter', ',', 'TextType', 'string');
alignmentCorePath = lookupSourceFile(sourceCell, "alignment_core_map");
fullScalingParamsPath = lookupSourceFile(sourceCell, "full_scaling_parameters");

core = load(alignmentCorePath, 'Smap', 'temps', 'currents');
paramsTbl = readtable(fullScalingParamsPath);
paramsTbl = sortrows(paramsTbl, 'T_K');

phiTbl = readtable(source.dynamicPhiPath);
ampTbl = readtable(source.dynamicAmplitudePath);

tempsAll = core.temps(:);
currents = core.currents(:);
SmapAll = core.Smap;

tMask = paramsTbl.T_K >= cfg.temperatureMinK & paramsTbl.T_K <= cfg.temperatureMaxK;
paramsTbl = paramsTbl(tMask, :);
assert(~isempty(paramsTbl), 'No full-scaling rows remain in requested temperature range.');

[temps, iMap, iPar] = intersect(tempsAll, paramsTbl.T_K, 'stable');
assert(~isempty(temps), 'No common temperatures between alignment map and full-scaling parameters.');

Smap = SmapAll(iMap, :);
Ipeak = paramsTbl.Ipeak_mA(iPar);
Speak = paramsTbl.S_peak(iPar);
width = paramsTbl.width_chosen_mA(iPar);

validRows = isfinite(temps) & isfinite(Ipeak) & isfinite(Speak) & isfinite(width);
validRows = validRows & (width > 0);
validRows = validRows & (Speak > cfg.speakFloorFraction * max(Speak, [], 'omitnan'));

temps = temps(validRows);
Ipeak = Ipeak(validRows);
Speak = Speak(validRows);
width = width(validRows);
Smap = Smap(validRows, :);

assert(numel(temps) >= 5, 'Too few valid temperature rows after filtering.');

nT = numel(temps);
nI = numel(currents);

Xscaled = NaN(nT, nI);
Yscaled = NaN(nT, nI);
for it = 1:nT
    Xscaled(it, :) = (currents - Ipeak(it)) ./ width(it);
    Yscaled(it, :) = Smap(it, :) ./ Speak(it);
end

xLower = max(min(Xscaled, [], 2, 'omitnan'));
xUpper = min(max(Xscaled, [], 2, 'omitnan'));
assert(isfinite(xLower) && isfinite(xUpper) && xUpper > xLower, ...
    'Invalid common scaled-current range for master-curve construction.');

xMaster = linspace(xLower, xUpper, nI)';
Frows = NaN(nT, nI);
for it = 1:nT
    Frows(it, :) = interp1(Xscaled(it, :), Yscaled(it, :), xMaster, 'linear', 'extrap');
end
Fmaster = mean(Frows, 1, 'omitnan')';

Scollapse = NaN(nT, nI);
for it = 1:nT
    Fi = interp1(xMaster, Fmaster, Xscaled(it, :), 'linear', 'extrap');
    Scollapse(it, :) = Speak(it) .* Fi;
end

deltaS = Smap - Scollapse;

deltaSsvd = deltaS;
deltaSsvd(~isfinite(deltaSsvd)) = 0;
[U, Sigma, V] = svd(deltaSsvd, 'econ');
singvals = diag(Sigma);
assert(~isempty(singvals), 'Residual SVD returned no singular values.');

phiResidual = V(:, 1);
aResidual = U(:, 1) .* singvals(1);

[currentsCommon, iResCurrent, iPhi] = intersect(currents, phiTbl.current_mA, 'stable');
assert(~isempty(currentsCommon), 'No common current points for phi comparison.');

phiResidualCmp = phiResidual(iResCurrent);
phi1 = phiTbl.phi_1(iPhi);
corrPhiRaw = safeCorr(phiResidualCmp, phi1);

if isfinite(corrPhiRaw) && corrPhiRaw < 0
    phiResidual = -phiResidual;
    aResidual = -aResidual;
    phiResidualCmp = -phiResidualCmp;
end
corrPhi = safeCorr(phiResidualCmp, phi1);

[tempsCommon, iResTemp, iA1] = intersect(temps, ampTbl.T_K, 'stable');
assert(~isempty(tempsCommon), 'No common temperatures for amplitude comparison.');

aResidualCmp = aResidual(iResTemp);
a1 = ampTbl.a_1(iA1);
corrA = safeCorr(aResidualCmp, a1);
corrAbsA = safeCorr(abs(aResidualCmp), abs(a1));

[~, iPeakResidual] = max(abs(aResidual));
peakResidualTempK = temps(iPeakResidual);

sectorMask = temps >= cfg.targetSectorK(1) & temps <= cfg.targetSectorK(2);
sectorEnergyFraction = sum(abs(aResidual(sectorMask)) .^ 2, 'omitnan') / ...
    max(sum(abs(aResidual) .^ 2, 'omitnan'), eps);
sectorConfirmed = (peakResidualTempK >= cfg.targetSectorK(1)) && ...
    (peakResidualTempK <= cfg.targetSectorK(2)) && ...
    isfinite(corrPhi) && (corrPhi >= cfg.minPhiCorr);

correlationTbl = table( ...
    corrPhiRaw, corrPhi, corrA, corrAbsA, peakResidualTempK, sectorEnergyFraction, sectorConfirmed, ...
    'VariableNames', {'corr_phi_residual_phi1_raw', 'corr_phi_residual_phi1', ...
    'corr_a_residual_a1', 'corr_abs_a_residual_abs_a1', ...
    'residual_peak_temp_K', 'sector_energy_fraction', 'sector_confirmed'});
correlationPath = save_run_table(correlationTbl, ...
    'switching_residual_collapse_correlations.csv', runDir);

amplitudeTbl = table(tempsCommon, aResidualCmp, a1, abs(aResidualCmp), abs(a1), ...
    'VariableNames', {'T_K', 'a_residual', 'a_1', 'abs_a_residual', 'abs_a_1'});
amplitudePath = save_run_table(amplitudeTbl, ...
    'switching_residual_collapse_amplitude_comparison.csv', runDir);

masterTbl = table(xMaster, Fmaster, 'VariableNames', {'scaled_current', 'F_master'});
masterPath = save_run_table(masterTbl, 'switching_residual_collapse_master_curve.csv', runDir);

figHeat = makeFigure();
axHeat = axes(figHeat);
imagesc(axHeat, currents, temps, deltaS);
axis(axHeat, 'xy');
xlabel(axHeat, 'Current (mA)');
ylabel(axHeat, 'Temperature (K)');
title(axHeat, '\DeltaS(I,T) = S - S_{collapse}');
colormap(axHeat, parula);
cb = colorbar(axHeat);
cb.Label.String = '\DeltaS (P2P percent)';
styleAxes(axHeat);
figHeatPath = save_run_figure(figHeat, 'switching_residual_collapse_deltaS_heatmap', runDir);
close(figHeat);

figPhi = makeFigure();
axPhi = axes(figPhi);
plot(axPhi, currents, phiResidual, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], 'MarkerSize', 6);
xlabel(axPhi, 'Current (mA)');
ylabel(axPhi, '\phi_{residual}(I)');
title(axPhi, 'Leading residual spatial mode');
styleAxes(axPhi);
figPhiPath = save_run_figure(figPhi, 'switching_residual_collapse_phi_residual', runDir);
close(figPhi);

figPhiCmp = makeFigure();
axPhiCmp = axes(figPhiCmp);
hold(axPhiCmp, 'on');
plot(axPhiCmp, currentsCommon, phiResidualCmp, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', '\phi_{residual}');
plot(axPhiCmp, currentsCommon, phi1, '-s', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, 'DisplayName', '\phi_1 (saved)');
hold(axPhiCmp, 'off');
xlabel(axPhiCmp, 'Current (mA)');
ylabel(axPhiCmp, 'Mode weight (a.u.)');
title(axPhiCmp, sprintf('\\phi comparison, corr = %.4f', corrPhi));
legend(axPhiCmp, 'Location', 'best');
styleAxes(axPhiCmp);
figPhiCmpPath = save_run_figure(figPhiCmp, 'switching_residual_collapse_phi_vs_phi1', runDir);
close(figPhiCmp);

figAmp = makeFigure();
axAmp = axes(figAmp);
hold(axAmp, 'on');
plot(axAmp, tempsCommon, aResidualCmp, '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], ...
    'MarkerSize', 6, 'DisplayName', 'a_{residual}(T)');
plot(axAmp, tempsCommon, a1, '-s', 'LineWidth', 2.2, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], ...
    'MarkerSize', 6, 'DisplayName', 'a_1(T) saved');
xline(axAmp, 10, '--k', 'LineWidth', 1.3, 'DisplayName', '10 K');
hold(axAmp, 'off');
xlabel(axAmp, 'Temperature (K)');
ylabel(axAmp, 'Amplitude (a.u.)');
title(axAmp, 'Residual amplitude vs saved shape-mode amplitude');
legend(axAmp, 'Location', 'best');
styleAxes(axAmp);
figAmpPath = save_run_figure(figAmp, 'switching_residual_collapse_amplitude_vs_temperature', runDir);
close(figAmp);

reportText = buildReportText(source, alignmentCorePath, fullScalingParamsPath, ...
    corrPhi, corrA, corrAbsA, peakResidualTempK, sectorEnergyFraction, sectorConfirmed, ...
    figHeatPath, figPhiPath, figPhiCmpPath, figAmpPath, correlationPath, amplitudePath, masterPath);
reportPath = save_run_report(reportText, ...
    'switching_residual_collapse_verification_report.md', runDir);

appendText(run.notes_path, sprintf('corr(phi_residual, phi_1) = %.6f\n', corrPhi));
appendText(run.notes_path, sprintf('residual peak temperature = %.2f K\n', peakResidualTempK));
appendText(run.notes_path, sprintf('10K sector confirmed = %d\n', sectorConfirmed));

zipPath = buildReviewZip(runDir, 'switching_residual_collapse_verification_bundle.zip');

appendText(run.log_path, sprintf('[%s] switching residual-collapse verification complete\n', stampNow()));
appendText(run.log_path, sprintf('Correlations: %s\n', correlationPath));
appendText(run.log_path, sprintf('Amplitude comparison: %s\n', amplitudePath));
appendText(run.log_path, sprintf('Master curve: %s\n', masterPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.corrPhi = corrPhi;
out.peakResidualTempK = peakResidualTempK;
out.sectorConfirmed = sectorConfirmed;
out.paths = struct( ...
    'correlations', string(correlationPath), ...
    'amplitudes', string(amplitudePath), ...
    'masterCurve', string(masterPath), ...
    'report', string(reportPath), ...
    'zip', string(zipPath), ...
    'deltaSFigure', string(figHeatPath.png), ...
    'residualPhiFigure', string(figPhiPath.png), ...
    'phiComparisonFigure', string(figPhiCmpPath.png), ...
    'amplitudeFigure', string(figAmpPath.png));

fprintf('\n=== Switching residual-collapse verification complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('corr(phi_residual, phi_1): %.6f\n', corrPhi);
fprintf('Residual peak temperature: %.2f K\n', peakResidualTempK);
fprintf('10K sector confirmed: %d\n', sectorConfirmed);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_residual_collapse_verification');
cfg = setDefault(cfg, 'dynamicShapeRunId', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefault(cfg, 'temperatureMinK', 4);
cfg = setDefault(cfg, 'temperatureMaxK', 30);
cfg = setDefault(cfg, 'speakFloorFraction', 1e-3);
cfg = setDefault(cfg, 'targetSectorK', [8, 12]);
cfg = setDefault(cfg, 'minPhiCorr', 0.70);
end

function source = resolveSourcePaths(repoRoot, cfg)
source = struct();
source.dynamicShapeRunId = string(cfg.dynamicShapeRunId);
source.dynamicShapeRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), ...
    char(source.dynamicShapeRunId));
source.dynamicSourcesPath = fullfile(source.dynamicShapeRunDir, 'tables', ...
    'switching_dynamic_shape_sources.csv');
source.dynamicPhiPath = fullfile(source.dynamicShapeRunDir, 'tables', ...
    'switching_dynamic_shape_modes_phi.csv');
source.dynamicAmplitudePath = fullfile(source.dynamicShapeRunDir, 'tables', ...
    'switching_dynamic_shape_mode_amplitudes.csv');

requiredFiles = {source.dynamicSourcesPath, source.dynamicPhiPath, source.dynamicAmplitudePath};
for i = 1:numel(requiredFiles)
    if exist(requiredFiles{i}, 'file') ~= 2
        error('Required source file missing: %s', requiredFiles{i});
    end
end
end

function outPath = lookupSourceFile(sourceCell, sourceRole)
assert(size(sourceCell, 1) >= 2 && size(sourceCell, 2) >= 3, ...
    'Invalid source manifest format: %s', sourceRole);

headers = string(sourceCell(1, :));
roleCol = find(contains(lower(headers), "source_role"), 1, 'first');
fileCol = find(contains(lower(headers), "source_file"), 1, 'first');
if isempty(roleCol)
    roleCol = 1;
end
if isempty(fileCol)
    fileCol = 3;
end

roles = string(sourceCell(2:end, roleCol));
files = string(sourceCell(2:end, fileCol));
roles = regexprep(lower(strtrim(roles)), '[^a-z0-9_]', '');
target = regexprep(lower(string(sourceRole)), '[^a-z0-9_]', '');
idx = (roles == target);

assert(nnz(idx) == 1, 'Missing unique source role: %s', char(sourceRole));
outPath = char(strtrim(files(find(idx, 1, 'first'))));
if exist(outPath, 'file') ~= 2
    error('Source file listed in manifest is missing: %s', outPath);
end
end

function fig = makeFigure()
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

function reportText = buildReportText(source, alignmentCorePath, fullScalingParamsPath, ...
    corrPhi, corrA, corrAbsA, peakResidualTempK, sectorEnergyFraction, sectorConfirmed, ...
    figHeatPath, figPhiPath, figPhiCmpPath, figAmpPath, correlationPath, amplitudePath, masterPath)

if sectorConfirmed
    sectorText = "Confirmed";
else
    sectorText = "Not confirmed";
end

lines = strings(0, 1);
lines(end + 1) = "# Switching residual-collapse verification";
lines(end + 1) = "";
lines(end + 1) = "## Inputs";
lines(end + 1) = "- Dynamic-shape run: `" + source.dynamicShapeRunId + "`";
lines(end + 1) = "- Alignment core map: `" + string(alignmentCorePath) + "`";
lines(end + 1) = "- Full-scaling parameters: `" + string(fullScalingParamsPath) + "`";
lines(end + 1) = "- Saved phi/amplitude source: `" + string(source.dynamicShapeRunDir) + "`";
lines(end + 1) = "";
lines(end + 1) = "## Residual-collapse model";
lines(end + 1) = "- `S_collapse(I,T) = S_peak(T) * F((I-I_peak(T))/width(T))`";
lines(end + 1) = "- `deltaS(I,T) = S(I,T) - S_collapse(I,T)`";
lines(end + 1) = "- Leading SVD residual mode compared against saved `phi_1`.";
lines(end + 1) = "";
lines(end + 1) = "## Key numbers";
lines(end + 1) = "- `corr(phi_residual, phi_1) = " + sprintf('%.6f', corrPhi) + "`";
lines(end + 1) = "- `corr(a_residual, a_1) = " + sprintf('%.6f', corrA) + "`";
lines(end + 1) = "- `corr(|a_residual|, |a_1|) = " + sprintf('%.6f', corrAbsA) + "`";
lines(end + 1) = "- Residual amplitude peak temperature: `" + sprintf('%.2f K', peakResidualTempK) + "`";
lines(end + 1) = "- 10 K sector energy fraction (8-12 K): `" + sprintf('%.4f', sectorEnergyFraction) + "`";
lines(end + 1) = "- 10 K sector confirmation: **" + sectorText + "**";
lines(end + 1) = "";
lines(end + 1) = "## Artifacts";
lines(end + 1) = "- DeltaS heatmap: `" + string(figHeatPath.png) + "`";
lines(end + 1) = "- Leading residual mode: `" + string(figPhiPath.png) + "`";
lines(end + 1) = "- phi comparison: `" + string(figPhiCmpPath.png) + "`";
lines(end + 1) = "- Amplitude comparison: `" + string(figAmpPath.png) + "`";
lines(end + 1) = "- Correlation table: `" + string(correlationPath) + "`";
lines(end + 1) = "- Amplitude table: `" + string(amplitudePath) + "`";
lines(end + 1) = "- Master-curve table: `" + string(masterPath) + "`";
lines(end + 1) = "";
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


