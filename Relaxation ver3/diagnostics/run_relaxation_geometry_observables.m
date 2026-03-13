function out = run_relaxation_geometry_observables(cfg)
% run_relaxation_geometry_observables
% Standalone geometry diagnostics for existing relaxation map exports.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(relaxDir);
addpath(diagDir);

cfg.runLabel = getDef(cfg, 'runLabel', 'geometry_observables');
cfg.dMMapPath = getDef(cfg, 'dMMapPath', "");
cfg.SMapPath = getDef(cfg, 'SMapPath', "");

[dMPath, sPath, hasS] = resolveInputs(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = char(string(dMPath));
run = createRunContext('relaxation', runCfg);
runDir = getRunOutputDir();
fprintf('Relaxation geometry observables run directory:\n%s\n', runDir);
fprintf('DeltaM map source: %s\n', dMPath);
if hasS
    fprintf('S map source: %s\n', sPath);
end

[T, xGrid, Z] = loadMapMatrix(dMPath);
dM = analyzeMap(T, xGrid, Z);
dM.mapPath = string(dMPath);
dMObs = computeGeometryObservables(dM);

mapPaths = saveMapFigure(dM, dM.matrix, 'Relaxation map: \DeltaM(T, log_{10} t)', '\DeltaM', 'relaxation_map_heatmap', runDir, computeMapClim(dM.matrix, false));
screePaths = saveScreeFigure(dM, 'relaxation_scree_plot', runDir);
modePaths = saveTemperatureModesFigure(dM, 'temperature_modes_u1_u3', runDir);
ampPaths = saveAmplitudeFigure(dM, dMObs, 'relaxation_amplitude_curve', runDir);
rank1ReconPaths = saveMapFigure(dM, dM.rank1.approx, 'Rank-1 reconstruction of \DeltaM', '\DeltaM', 'relaxation_rank1_reconstruction', runDir, computeMapClim(dM.matrix, false));
rank2ReconPaths = saveMapFigure(dM, dM.rank2.approx, 'Rank-2 reconstruction of \DeltaM', '\DeltaM', 'relaxation_rank2_reconstruction', runDir, computeMapClim(dM.matrix, false));
rank1ResidualPaths = saveMapFigure(dM, dM.rank1.residual, 'Rank-1 residual map', '\DeltaM residual', 'relaxation_rank1_residual', runDir, computeMapClim(dM.rank1.residual, true));
rank2ResidualPaths = saveMapFigure(dM, dM.rank2.residual, 'Rank-2 residual map', '\DeltaM residual', 'relaxation_rank2_residual', runDir, computeMapClim(dM.rank2.residual, true));

firstFiveTable = buildFirstFiveTable(dM);
firstFivePath = save_run_table(firstFiveTable, 'deltaM_first_five_singular_values.csv', runDir);
modeTable = buildModeTable(dM);
modeTablePath = save_run_table(modeTable, 'deltaM_mode_profiles.csv', runDir);
reconTable = buildReconstructionTable(dM);
reconTablePath = save_run_table(reconTable, 'deltaM_reconstruction_metrics.csv', runDir);

observablesTbl = buildObservableExport(dMObs);
observablesPath = export_observables('relaxation', runDir, observablesTbl);

sSummary = struct();
if hasS
    [sT, sxGrid, sZ] = loadMapMatrix(sPath);
    sData = analyzeMap(sT, sxGrid, sZ);
    sData.mapPath = string(sPath);
    sSummary = summarizeSecondaryMap(sData);
    sFirstFivePath = save_run_table(buildFirstFiveTable(sData), 'S_first_five_singular_values.csv', runDir);
else
    sFirstFivePath = "";
end

svdData = struct();
svdData.run_id = string(run.run_id);
svdData.run_dir = string(runDir);
svdData.source_deltaM_map = string(dMPath);
svdData.deltaM = buildMatStruct(dM, dMObs);
if hasS
    svdData.source_S_map = string(sPath);
    svdData.S = buildMatStruct(sData, struct());
    svdData.S.summary = sSummary;
end
svdDataPath = fullfile(runDir, 'svd_data.mat');
save(svdDataPath, 'svdData', '-v7');

reportText = buildReport(dM, dMObs, firstFiveTable, reconTable, hasS, sSummary);
reportPath = save_run_report(reportText, 'relaxation_geometry_observables.md', runDir);

appendText(run.log_path, sprintf('[%s] GEOMETRY_OBSERVABLES_COMPLETE\n', stampNow()));
appendText(run.log_path, sprintf('Observables: %s\n', observablesPath));
appendText(run.log_path, sprintf('SVD data MAT: %s\n', svdDataPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));

appendText(run.notes_path, sprintf('Relax_Amp_peak = %.6g\n', dMObs.Relax_Amp_peak));
appendText(run.notes_path, sprintf('Relax_T_peak = %.6g K\n', dMObs.Relax_T_peak));
appendText(run.notes_path, sprintf('Relax_peak_width = %.6g K\n', dMObs.Relax_peak_width));
appendText(run.notes_path, sprintf('Relax_mode2_strength = %.6g\n', dMObs.Relax_mode2_strength));
appendText(run.notes_path, sprintf('Relax_rank1_residual_fraction = %.6g\n', dMObs.Relax_rank1_residual_fraction));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.observables = dMObs;
out.observablesPath = string(observablesPath);
out.svdDataPath = string(svdDataPath);
out.reportPath = string(reportPath);
out.tables = struct( ...
    'firstFive', string(firstFivePath), ...
    'modeProfiles', string(modeTablePath), ...
    'reconstructionMetrics', string(reconTablePath));
if hasS
    out.tables.SFirstFive = string(sFirstFivePath);
end
out.figures = struct( ...
    'heatmap', string(mapPaths.png), ...
    'scree', string(screePaths.png), ...
    'temperatureModes', string(modePaths.png), ...
    'amplitude', string(ampPaths.png), ...
    'rank1Reconstruction', string(rank1ReconPaths.png), ...
    'rank2Reconstruction', string(rank2ReconPaths.png), ...
    'rank1Residual', string(rank1ResidualPaths.png), ...
    'rank2Residual', string(rank2ResidualPaths.png));

fprintf('\n=== Relaxation geometry observables complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Observables: %s\n', observablesPath);
fprintf('SVD MAT: %s\n', svdDataPath);
fprintf('Report: %s\n\n', reportPath);
end

function [dMPath, sPath, hasS] = resolveInputs(repoRoot, cfg)
dMPath = resolveMapPath(repoRoot, cfg.dMMapPath, 'dM');
sPath = "";
hasS = false;
try
    sPath = resolveMapPath(repoRoot, cfg.SMapPath, 'S');
    hasS = true;
catch
    hasS = false;
    sPath = "";
end
end

function data = analyzeMap(T, xGrid, Z)
[U, S, V] = svd(Z, 'econ');
[U, V] = orientModes(U, V, min(3, size(U, 2)));
singularValues = diag(S);
normalized = singularValues ./ max(singularValues(1), eps);
amplitude = singularValues(1) * U(:, 1);

rank1Approx = U(:, 1) * S(1, 1) * V(:, 1)';
rank2Approx = rankReconstruction(U, S, V, 2);
rank1Residual = Z - rank1Approx;
rank2Residual = Z - rank2Approx;
baseNorm = norm(Z, 'fro');
baseNorm = max(baseNorm, eps);

rank1 = struct();
rank1.rank = 1;
rank1.approx = rank1Approx;
rank1.residual = rank1Residual;
rank1.relativeFroError = norm(rank1Residual, 'fro') / baseNorm;
rank1.varianceExplained = 1 - (norm(rank1Residual, 'fro')^2 / max(baseNorm^2, eps));
rank1.rmsResidual = sqrt(mean(rank1Residual(:).^2));

rank2 = struct();
rank2.rank = 2;
rank2.approx = rank2Approx;
rank2.residual = rank2Residual;
rank2.relativeFroError = norm(rank2Residual, 'fro') / baseNorm;
rank2.varianceExplained = 1 - (norm(rank2Residual, 'fro')^2 / max(baseNorm^2, eps));
rank2.rmsResidual = sqrt(mean(rank2Residual(:).^2));

data = struct();
data.T = T;
data.xGrid = xGrid;
data.tGrid = 10 .^ xGrid;
data.matrix = Z;
data.U = U;
data.S = S;
data.V = V;
data.singularValues = singularValues;
data.normalizedValues = normalized;
data.amplitude = amplitude;
data.rank1 = rank1;
data.rank2 = rank2;
end

function approx = rankReconstruction(U, S, V, rankValue)
rankValue = min([rankValue, size(U, 2), size(V, 2)]);
approx = U(:, 1:rankValue) * S(1:rankValue, 1:rankValue) * V(:, 1:rankValue)';
end

function [U, V] = orientModes(U, V, nModes)
for k = 1:nModes
    [~, idx] = max(abs(U(:, k)));
    if U(idx, k) < 0
        U(:, k) = -U(:, k);
        V(:, k) = -V(:, k);
    end
end
end

function obs = computeGeometryObservables(data)
A = data.amplitude(:);
T = data.T(:);
[peakVal, idxPeak] = max(A);
if isempty(idxPeak) || ~isfinite(peakVal)
    peakVal = NaN;
    Tpeak = NaN;
else
    Tpeak = T(idxPeak);
end

obs = struct();
obs.Relax_Amp_peak = peakVal;
obs.Relax_T_peak = Tpeak;
obs.Relax_peak_width = computeFwhm(T, A);
obs.Relax_mode2_strength = NaN;
if numel(data.singularValues) >= 2 && data.singularValues(1) > 0
    obs.Relax_mode2_strength = data.singularValues(2) / data.singularValues(1);
end
obs.Relax_rank1_residual_fraction = 1 - data.rank1.varianceExplained;
end

function width = computeFwhm(T, A)
width = NaN;
if numel(T) < 3
    return;
end
[peakVal, idxPeak] = max(A);
if ~(isfinite(peakVal) && peakVal > 0)
    return;
end
halfMax = peakVal / 2;
leftCross = NaN;
rightCross = NaN;
for i = idxPeak:-1:2
    if crossesHalf(A(i - 1), A(i), halfMax)
        leftCross = interpCross(T(i - 1), A(i - 1), T(i), A(i), halfMax);
        break;
    end
end
for i = idxPeak:(numel(T) - 1)
    if crossesHalf(A(i), A(i + 1), halfMax)
        rightCross = interpCross(T(i), A(i), T(i + 1), A(i + 1), halfMax);
        break;
    end
end
if isfinite(leftCross) && isfinite(rightCross) && rightCross >= leftCross
    width = rightCross - leftCross;
end
end

function tf = crossesHalf(y1, y2, target)
tf = (y1 <= target && y2 >= target) || (y1 >= target && y2 <= target);
end

function x = interpCross(x1, y1, x2, y2, target)
if abs(y2 - y1) < eps
    x = mean([x1, x2]);
else
    x = x1 + (target - y1) * (x2 - x1) / (y2 - y1);
end
end

function tbl = buildFirstFiveTable(data)
nKeep = min(5, numel(data.singularValues));
tbl = table((1:nKeep)', data.singularValues(1:nKeep), data.normalizedValues(1:nKeep), ...
    'VariableNames', {'mode','singular_value','sigma_over_sigma1'});
end

function tbl = buildModeTable(data)
nModes = min(3, size(data.U, 2));
vars = {'temperature_K'};
cols = {data.T(:)};
for k = 1:nModes
    vars{end + 1} = sprintf('u%d', k); %#ok<AGROW>
    cols{end + 1} = data.U(:, k); %#ok<AGROW>
end
vars{end + 1} = 'A_T';
cols{end + 1} = data.amplitude(:);
tbl = table(cols{:}, 'VariableNames', vars);
end

function tbl = buildReconstructionTable(data)
tbl = table([1; 2], ...
    [data.rank1.relativeFroError; data.rank2.relativeFroError], ...
    [data.rank1.varianceExplained; data.rank2.varianceExplained], ...
    [data.rank1.rmsResidual; data.rank2.rmsResidual], ...
    'VariableNames', {'rank_used','relative_fro_error','variance_explained','rms_reconstruction_error'});
end

function tbl = buildObservableExport(obs)
tbl = table( ...
    ["relaxation"; "relaxation"; "relaxation"; "relaxation"; "relaxation"], ...
    ["relaxation_map"; "relaxation_map"; "relaxation_map"; "relaxation_map"; "relaxation_map"], ...
    [obs.Relax_T_peak; obs.Relax_T_peak; obs.Relax_T_peak; NaN; NaN], ...
    ["Relax_Amp_peak"; "Relax_T_peak"; "Relax_peak_width"; "Relax_mode2_strength"; "Relax_rank1_residual_fraction"], ...
    [obs.Relax_Amp_peak; obs.Relax_T_peak; obs.Relax_peak_width; obs.Relax_mode2_strength; obs.Relax_rank1_residual_fraction], ...
    ["deltaM_map_units"; "K"; "K"; "ratio"; "fraction"], ...
    ["observable"; "observable"; "observable"; "observable"; "observable"], ...
    'VariableNames', {'experiment','sample','temperature','observable','value','units','role'});
end

function summary = summarizeSecondaryMap(data)
summary = struct();
summary.mode2_strength = NaN;
if numel(data.singularValues) >= 2 && data.singularValues(1) > 0
    summary.mode2_strength = data.singularValues(2) / data.singularValues(1);
end
summary.rank1_residual_fraction = 1 - data.rank1.varianceExplained;
summary.first_five_singular_values = data.singularValues(1:min(5, numel(data.singularValues)));
summary.first_five_normalized = data.normalizedValues(1:min(5, numel(data.normalizedValues)));
end

function matStruct = buildMatStruct(data, obs)
matStruct = struct();
matStruct.T = data.T;
matStruct.log10_t = data.xGrid;
matStruct.t_seconds = data.tGrid;
matStruct.map = data.matrix;
matStruct.U = data.U;
matStruct.S = data.S;
matStruct.V = data.V;
matStruct.singular_values = data.singularValues;
matStruct.normalized_spectrum = data.normalizedValues;
matStruct.amplitude_T = data.amplitude;
matStruct.rank1 = data.rank1;
matStruct.rank2 = data.rank2;
if ~isempty(fieldnames(obs))
    matStruct.observables = obs;
end
end

function paths = saveMapFigure(data, Z, ttl, cbarLabel, baseName, runDir, clim)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 940 580]);
ax = axes(fig);
imagesc(ax, data.xGrid, data.T, Z);
set(ax, 'YDir', 'normal', 'FontSize', 14, 'LineWidth', 1.2);
grid(ax, 'on');
box(ax, 'on');
colormap(ax, parula);
if numel(clim) == 2 && all(isfinite(clim)) && clim(2) > clim(1)
    caxis(ax, clim);
end
xlabel(ax, 'log_{10}(t_{rel} [s])', 'FontSize', 15);
ylabel(ax, 'Temperature (K)', 'FontSize', 15);
title(ax, ttl, 'FontSize', 16, 'FontWeight', 'bold');
cb = colorbar(ax);
ylabel(cb, cbarLabel, 'FontSize', 14);
paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function paths = saveScreeFigure(data, baseName, runDir)
nKeep = min(5, numel(data.singularValues));
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [110 110 900 540]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.2);
semilogy(ax, 1:nKeep, data.singularValues(1:nKeep), '-o', 'LineWidth', 2.4, 'MarkerSize', 7, 'Color', [0.10 0.35 0.75]);
for i = 1:nKeep
    text(ax, i, data.singularValues(i), sprintf('  %.3g', data.normalizedValues(i)), 'FontSize', 11, 'VerticalAlignment', 'bottom');
end
xlabel(ax, 'Mode index', 'FontSize', 15);
ylabel(ax, 'Singular value \sigma_i', 'FontSize', 15);
title(ax, 'Singular value scree plot', 'FontSize', 16, 'FontWeight', 'bold');
xticks(ax, 1:nKeep);
paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function paths = saveTemperatureModesFigure(data, baseName, runDir)
nModes = min(3, size(data.U, 2));
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [110 80 920 930]);
tiledlayout(fig, nModes, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
cols = lines(max(3, nModes));
for k = 1:nModes
    ax = nexttile;
    plot(ax, data.T, data.U(:, k), '-', 'LineWidth', 2.4, 'Color', cols(k, :));
    grid(ax, 'on');
    box(ax, 'on');
    set(ax, 'FontSize', 14, 'LineWidth', 1.1);
    ylabel(ax, sprintf('u_%d(T)', k), 'FontSize', 15);
    title(ax, sprintf('Temperature mode u_%d(T)', k), 'FontSize', 15, 'FontWeight', 'bold');
    if k == nModes
        xlabel(ax, 'Temperature (K)', 'FontSize', 15);
    else
        set(ax, 'XTickLabel', []);
    end
end
paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function paths = saveAmplitudeFigure(data, obs, baseName, runDir)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [110 110 920 520]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);
plot(ax, data.T, data.amplitude, '-', 'LineWidth', 2.6, 'Color', [0.80 0.20 0.10]);
if isfinite(obs.Relax_Amp_peak) && isfinite(obs.Relax_T_peak)
    plot(ax, obs.Relax_T_peak, obs.Relax_Amp_peak, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', [0 0 0]);
    yline(ax, obs.Relax_Amp_peak / 2, '--', 'Half max', 'LineWidth', 1.5, 'Color', [0.2 0.2 0.2]);
end
xlabel(ax, 'Temperature (K)', 'FontSize', 15);
ylabel(ax, 'A(T)', 'FontSize', 15);
title(ax, 'Amplitude curve from mode-1 projection', 'FontSize', 16, 'FontWeight', 'bold');
paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function reportText = buildReport(data, obs, firstFiveTable, reconTable, hasS, sSummary)
rank1 = reconTable(reconTable.rank_used == 1, :);
rank2 = reconTable(reconTable.rank_used == 2, :);
u2 = data.U(:, min(2, size(data.U, 2)));
v2 = data.V(:, min(2, size(data.V, 2)));

lines = {};
lines{end + 1, 1} = '# Relaxation Geometry Observables';
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Inputs';
lines{end + 1, 1} = ['- DeltaM map source: `' char(data.mapPath) '`'];
if hasS
    lines{end + 1, 1} = '- Secondary S(T,t) analysis was available and is summarized below.';
else
    lines{end + 1, 1} = '- S(T,t) was not found in the existing relaxation outputs.';
end
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## SVD Spectrum';
lines{end + 1, 1} = '| mode | singular value | sigma_i / sigma_1 |';
lines{end + 1, 1} = '| --- | ---: | ---: |';
for i = 1:height(firstFiveTable)
    lines{end + 1, 1} = sprintf('| %d | %.6g | %.6g |', firstFiveTable.mode(i), firstFiveTable.singular_value(i), firstFiveTable.sigma_over_sigma1(i));
end
lines{end + 1, 1} = sprintf('- Relax_mode2_strength = %.6g', obs.Relax_mode2_strength);
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Geometry of the Map';
lines{end + 1, 1} = sprintf('- Relax_Amp_peak = %.6g', obs.Relax_Amp_peak);
lines{end + 1, 1} = sprintf('- Relax_T_peak = %.6g K', obs.Relax_T_peak);
lines{end + 1, 1} = sprintf('- Relax_peak_width = %.6g K', obs.Relax_peak_width);
lines{end + 1, 1} = sprintf('- Relax_rank1_residual_fraction = %.6g', obs.Relax_rank1_residual_fraction);
lines{end + 1, 1} = geometryInterpretation(obs);
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Reconstruction Test';
lines{end + 1, 1} = sprintf('- Rank-1 RMS reconstruction error = %.6g', rank1.rms_reconstruction_error(1));
lines{end + 1, 1} = sprintf('- Rank-2 RMS reconstruction error = %.6g', rank2.rms_reconstruction_error(1));
lines{end + 1, 1} = sprintf('- Rank-1 variance explained = %.6f', rank1.variance_explained(1));
lines{end + 1, 1} = sprintf('- Rank-2 variance explained = %.6f', rank2.variance_explained(1));
lines{end + 1, 1} = '- Residual maps for rank-1 and rank-2 are saved in the figures folder.';
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Mode-2 Structure';
lines{end + 1, 1} = mode2Interpretation(obs.Relax_mode2_strength, u2, v2);
if hasS
    lines{end + 1, 1} = sprintf('- For S(T,t), sigma_2 / sigma_1 = %.6g and the rank-1 residual fraction is %.6g.', sSummary.mode2_strength, sSummary.rank1_residual_fraction);
    lines{end + 1, 1} = '- The S map keeps more higher-mode structure than DeltaM, consistent with derivative-like amplification of weaker corrections.';
end
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Visualization choices';
lines{end + 1, 1} = '- number of curves: one heatmap, one scree curve, three temperature-mode curves in separate subplots, and one amplitude curve';
lines{end + 1, 1} = '- legend vs colormap: no legend for single-curve plots; parula plus colorbar for heatmaps';
lines{end + 1, 1} = '- colormap used: parula';
lines{end + 1, 1} = '- smoothing applied: none; this diagnostic uses existing exported maps directly';
lines{end + 1, 1} = '- justification: the figure set isolates the dominant separable geometry and the residual corrections without adding dense overlays';
reportText = strjoin(lines, newline);
end

function line = geometryInterpretation(obs)
if obs.Relax_rank1_residual_fraction <= 5e-4 && obs.Relax_mode2_strength <= 0.02
    line = '- The map is effectively rank-1: one temperature amplitude profile times one common time profile explains almost all of the variance.';
elseif obs.Relax_rank1_residual_fraction <= 0.02
    line = '- The map is still strongly low-rank, with only weak structured corrections beyond the leading component.';
else
    line = '- Higher-mode geometry remains important beyond the rank-1 picture.';
end
end

function line = mode2Interpretation(mode2Strength, u2, v2)
u2Cross = countZeroCrossings(u2);
v2Cross = countZeroCrossings(v2);
if mode2Strength <= 0.02
    strengthText = 'very weak';
elseif mode2Strength <= 0.08
    strengthText = 'weak but coherent';
else
    strengthText = 'substantial';
end
if u2Cross == 1
    tempText = 'The temperature-side mode-2 shape changes sign once, which is consistent with reweighting the low- and high-temperature sides of the main peak.';
elseif u2Cross > 1
    tempText = 'The temperature-side mode-2 shape has multiple sign changes, indicating a more structured distortion than a simple shift.';
else
    tempText = 'The temperature-side mode-2 shape keeps one sign, indicating a largely uniform correction to the main amplitude profile.';
end
if v2Cross <= 1
    timeText = 'The time-side mode remains simple, so the correction mainly reshapes the dominant relaxation profile.';
else
    timeText = 'The time-side mode is more oscillatory, which points to a genuine secondary time-shape correction.';
end
line = sprintf('- Mode 2 is %s (sigma_2 / sigma_1 = %.6g). %s %s', strengthText, mode2Strength, tempText, timeText);
end

function n = countZeroCrossings(y)
y = y(:);
mask = isfinite(y) & abs(y) > eps;
y = y(mask);
if numel(y) < 2
    n = 0;
    return;
end
n = sum(sign(y(1:end - 1)) ~= sign(y(2:end)));
end

function clim = computeMapClim(Z, symmetric)
vals = Z(isfinite(Z));
if isempty(vals)
    clim = [0 1];
    return;
end
if symmetric
    vmax = prctile(abs(vals), 98);
    vmax = max(vmax, max(abs(vals)));
    if ~(isfinite(vmax) && vmax > 0)
        vmax = 1;
    end
    clim = [-vmax, vmax];
else
    clim = prctile(vals, [2 98]);
    if ~(all(isfinite(clim)) && clim(2) > clim(1))
        clim = [min(vals) max(vals)];
    end
end
end

function [T, xGrid, Z] = loadMapMatrix(mapPath)
raw = readmatrix(mapPath);
if isempty(raw) || size(raw, 1) < 2 || size(raw, 2) < 2
    error('Map file is empty or malformed: %s', mapPath);
end
xGrid = raw(1, 2:end);
T = raw(2:end, 1);
Z = raw(2:end, 2:end);
validRows = isfinite(T);
validCols = isfinite(xGrid);
T = T(validRows);
xGrid = xGrid(validCols);
Z = Z(validRows, validCols);
nonEmptyRows = any(isfinite(Z), 2);
nonEmptyCols = any(isfinite(Z), 1);
T = T(nonEmptyRows);
xGrid = xGrid(nonEmptyCols);
Z = Z(nonEmptyRows, nonEmptyCols);
if any(~isfinite(Z), 'all')
    Z = fillMapMissing(Z);
end
if any(~isfinite(Z), 'all')
    error('Map still contains non-finite values after filling: %s', mapPath);
end
end

function Z = fillMapMissing(Z)
for r = 1:size(Z, 1)
    Z(r, :) = fillRowMissing(Z(r, :));
end
for c = 1:size(Z, 2)
    Z(:, c) = fillRowMissing(Z(:, c)')';
end
if any(~isfinite(Z), 'all')
    rowMeans = mean(Z, 2, 'omitnan');
    for r = 1:size(Z, 1)
        miss = ~isfinite(Z(r, :));
        if any(miss)
            if isfinite(rowMeans(r))
                Z(r, miss) = rowMeans(r);
            else
                Z(r, miss) = 0;
            end
        end
    end
end
end

function row = fillRowMissing(row)
if all(isfinite(row))
    return;
end
x = 1:numel(row);
good = isfinite(row);
if ~any(good)
    row(:) = 0;
    return;
end
if sum(good) == 1
    row(~good) = row(good);
    return;
end
row(~good) = interp1(x(good), row(good), x(~good), 'linear', 'extrap');
end

function mapPath = resolveMapPath(repoRoot, providedPath, kind)
if strlength(strtrim(string(providedPath))) > 0
    mapPath = char(string(providedPath));
    if exist(mapPath, 'file') ~= 2
        error('Provided %s map path not found: %s', kind, mapPath);
    end
    return;
end
runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
[~, order] = sort({runDirs.name});
runDirs = runDirs(order);
if strcmpi(kind, 'dM')
    preferred = {'map_dM_raw.csv', 'map_dM_sg_100md.csv', 'map_dM_sg_200md.csv', 'map_dM_gauss2d.csv'};
else
    preferred = {'map_S_raw.csv', 'map_S_sg_100md.csv', 'map_S_sg_200md.csv', 'map_S_gauss2d.csv'};
end
subdirs = {'tables', 'csv', 'derivative_smoothing'};
for i = numel(runDirs):-1:1
    runRoot = fullfile(runDirs(i).folder, runDirs(i).name);
    for s = 1:numel(subdirs)
        for p = 1:numel(preferred)
            candidate = fullfile(runRoot, subdirs{s}, preferred{p});
            if exist(candidate, 'file') == 2
                mapPath = candidate;
                return;
            end
        end
    end
end
error('Could not locate a %s map in recent relaxation runs.', kind);
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function v = getDef(s, f, d)
if isfield(s, f)
    v = s.(f);
else
    v = d;
end
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
