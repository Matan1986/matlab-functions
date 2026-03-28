function out = switching_threshold_residual_structure_test(cfg)
% switching_threshold_residual_structure_test
% Quantify residual structure left after the minimal threshold-distribution
% switching model using existing run outputs only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(repoRoot));

cfg = applyDefaults(cfg);
source = resolveSourceFiles(repoRoot, cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('source_run:%s', source.sourceRunId);
run = createRunContext('switching', runCfg);
runDir = run.run_dir;
ensureArtifactDirs(runDir);

appendLog(run.log_path, sprintf('[%s] switching_threshold_residual_structure_test started', stampNow()));
appendLog(run.log_path, sprintf('Source run: %s', source.sourceRunId));
appendLog(run.log_path, sprintf('Source observables: %s', source.observablesPath));
appendLog(run.log_path, sprintf('Source samples: %s', source.samplesPath));

obs = readtable(source.observablesPath, 'VariableNamingRule', 'preserve');
samples = readtable(source.samplesPath, 'VariableNamingRule', 'preserve');

prepared = buildPreparedCurves(obs, samples, cfg);

normalizedModel = buildNormalizedModel(prepared, cfg);
residuals = computeResidualStructures(prepared, normalizedModel, cfg);
decomp = runResidualSvd(residuals, cfg);
interpretation = buildInterpretation(prepared, normalizedModel, residuals, decomp, cfg);

writeOutputs(runDir, run, source, prepared, normalizedModel, residuals, decomp, interpretation);

zipPath = buildReviewZip(runDir, 'switching_threshold_residual_structure_bundle.zip');
appendLog(run.log_path, sprintf('Review ZIP: %s', zipPath));
appendLog(run.log_path, sprintf('[%s] switching_threshold_residual_structure_test complete', stampNow()));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.bestModel = normalizedModel.bestModelName;
out.bestModelRMSE = normalizedModel.bestModelRMSE;
out.mode1Explained = decomp.explained(1);
out.mode2Explained = decomp.explained(min(2, numel(decomp.explained)));
out.answer = interpretation;
out.zipPath = string(zipPath);

fprintf('\n=== Switching threshold residual-structure analysis complete ===\n');
fprintf('Run directory: %s\n', runDir);
fprintf('Best normalized model: %s (RMSE %.6g)\n', normalizedModel.bestModelName, normalizedModel.bestModelRMSE);
fprintf('Mode-1 explained variance: %.4f\n', decomp.explained(1));
if numel(decomp.explained) >= 2
    fprintf('Mode-2 explained variance: %.4f\n', decomp.explained(2));
end
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'switching_threshold_residual_structure');
cfg = setDefault(cfg, 'sourceRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'temperatureToleranceK', 0.12);
cfg = setDefault(cfg, 'minPointsPerCurve', 6);
cfg = setDefault(cfg, 'uMin', -2.5);
cfg = setDefault(cfg, 'uMax', 2.5);
cfg = setDefault(cfg, 'nUGrid', 180);
cfg = setDefault(cfg, 'nCurrentGrid', 200);
cfg = setDefault(cfg, 'maxModes', 6);
cfg = setDefault(cfg, 'secondModeThreshold', 0.12);
cfg = setDefault(cfg, 'crossoverWindowK', 4.0);
end

function source = resolveSourceFiles(repoRoot, cfg)
source = struct();
source.sourceRunId = string(cfg.sourceRunId);
source.runDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.sourceRunId));
source.observablesPath = fullfile(source.runDir, 'alignment_audit', 'switching_alignment_observables_vs_T.csv');
source.samplesPath = fullfile(source.runDir, 'alignment_audit', 'switching_alignment_samples.csv');

if exist(source.observablesPath, 'file') ~= 2
    error('Missing source observables file: %s', source.observablesPath);
end
if exist(source.samplesPath, 'file') ~= 2
    error('Missing source samples file: %s', source.samplesPath);
end
end

function prepared = buildPreparedCurves(obs, samples, cfg)
temps = double(obs.T_K(:));
iPeak = double(obs.Ipeak(:));
sPeak = double(obs.S_peak(:));
widthI = double(obs.width_I(:));

validObs = isfinite(temps) & isfinite(iPeak) & isfinite(sPeak) & isfinite(widthI) ...
    & (sPeak > 0) & (widthI > 0);

temps = temps(validObs);
iPeak = iPeak(validObs);
sPeak = sPeak(validObs);
widthI = widthI(validObs);

[temps, ord] = sort(temps);
iPeak = iPeak(ord);
sPeak = sPeak(ord);
widthI = widthI(ord);

tempsSamples = double(samples.T_K(:));
currSamples = double(samples.current_mA(:));
respSamples = double(samples.S_percent(:));

nT = numel(temps);
curves = repmat(struct('T', NaN, 'I_peak', NaN, 'S_peak', NaN, 'width_I', NaN, ...
    'I', [], 'S', [], 'u', [], 'S_norm', []), nT, 1);
keep = false(nT, 1);

for i = 1:nT
    t = temps(i);
    m = abs(tempsSamples - t) <= cfg.temperatureToleranceK;
    I = currSamples(m);
    S = respSamples(m);

    valid = isfinite(I) & isfinite(S);
    I = I(valid);
    S = S(valid);
    if numel(I) < cfg.minPointsPerCurve
        continue;
    end

    [Iuniq, ~, g] = unique(I);
    Savg = accumarray(g, S, [], @mean);

    if numel(Iuniq) < cfg.minPointsPerCurve
        continue;
    end

    [Iuniq, sortIdx] = sort(Iuniq);
    Savg = Savg(sortIdx);

    u = (Iuniq - iPeak(i)) ./ widthI(i);
    sNorm = Savg ./ sPeak(i);

    curves(i).T = t;
    curves(i).I_peak = iPeak(i);
    curves(i).S_peak = sPeak(i);
    curves(i).width_I = widthI(i);
    curves(i).I = Iuniq;
    curves(i).S = Savg;
    curves(i).u = u;
    curves(i).S_norm = sNorm;
    keep(i) = true;
end

curves = curves(keep);
if numel(curves) < 5
    error('Too few valid temperature curves available after filtering.');
end

prepared = struct();
prepared.curves = curves;
prepared.temps = [curves.T]';
prepared.iPeak = [curves.I_peak]';
prepared.sPeak = [curves.S_peak]';
prepared.widthI = [curves.width_I]';
prepared.nTemps = numel(curves);
end

function model = buildNormalizedModel(prepared, cfg)
uGrid = linspace(cfg.uMin, cfg.uMax, cfg.nUGrid)';
nT = prepared.nTemps;

sNormGrid = NaN(nT, numel(uGrid));
for i = 1:nT
    ui = prepared.curves(i).u(:);
    yi = prepared.curves(i).S_norm(:);
    if numel(ui) < 3
        continue;
    end
    [ui, ord] = sort(ui);
    yi = yi(ord);
    [ui, uniq] = unique(ui);
    yi = yi(uniq);
    yInterp = interp1(ui, yi, uGrid, 'linear', NaN);
    sNormGrid(i, :) = yInterp;
end

sNormMean = mean(sNormGrid, 1, 'omitnan')';
sNormStd = std(sNormGrid, 0, 1, 'omitnan')';

validFit = isfinite(uGrid) & isfinite(sNormMean);
uf = uGrid(validFit);
yf = sNormMean(validFit);
yf = min(max(yf, 1e-6), 1 - 1e-6);

fitLog = fitLogisticCdf(uf, yf);
fitGauss = fitGaussianCdf(uf, yf);

yLog = logisticCdf(uf, fitLog.mu, fitLog.scale);
yGauss = gaussianCdf(uf, fitGauss.mu, fitGauss.sigma);

[rmseLog, r2Log] = fitMetrics(yf, yLog);
[rmseGauss, r2Gauss] = fitMetrics(yf, yGauss);

if rmseLog <= rmseGauss
    bestName = 'logistic_cdf';
    bestPredictor = @(u) logisticCdf(u, fitLog.mu, fitLog.scale);
    bestRMSE = rmseLog;
    bestR2 = r2Log;
else
    bestName = 'gaussian_cdf';
    bestPredictor = @(u) gaussianCdf(u, fitGauss.mu, fitGauss.sigma);
    bestRMSE = rmseGauss;
    bestR2 = r2Gauss;
end

model = struct();
model.uGrid = uGrid;
model.sNormGrid = sNormGrid;
model.sNormMean = sNormMean;
model.sNormStd = sNormStd;
model.fitLog = fitLog;
model.fitGauss = fitGauss;
model.rmseLog = rmseLog;
model.rmseGauss = rmseGauss;
model.r2Log = r2Log;
model.r2Gauss = r2Gauss;
model.bestModelName = bestName;
model.bestModelRMSE = bestRMSE;
model.bestModelR2 = bestR2;
model.bestPredictor = bestPredictor;
model.yLog = logisticCdf(uGrid, fitLog.mu, fitLog.scale);
model.yGauss = gaussianCdf(uGrid, fitGauss.mu, fitGauss.sigma);
model.yBest = bestPredictor(uGrid);
end

function residuals = computeResidualStructures(prepared, model, cfg)
nT = prepared.nTemps;

allCurr = [];
for i = 1:nT
    allCurr = [allCurr; prepared.curves(i).I(:)]; %#ok<AGROW>
end
allCurr = unique(allCurr);
if numel(allCurr) > cfg.nCurrentGrid
    currentGrid = linspace(min(allCurr), max(allCurr), cfg.nCurrentGrid)';
else
    currentGrid = allCurr(:);
end

uGrid = model.uGrid;
residMapI = NaN(nT, numel(currentGrid));
residMapU = NaN(nT, numel(uGrid));

residNormL2 = NaN(nT, 1);
residVar = NaN(nT, 1);
residRMSE = NaN(nT, 1);
nPoints = NaN(nT, 1);

curveModels = cell(nT, 1);

for i = 1:nT
    c = prepared.curves(i);
    u = c.u(:);
    predNorm = model.bestPredictor(u);
    pred = c.S_peak .* predNorm;
    res = c.S(:) - pred;

    nPoints(i) = numel(res);
    residNormL2(i) = sqrt(mean(res .^ 2, 'omitnan'));
    residVar(i) = var(res, 1, 'omitnan');
    residRMSE(i) = sqrt(mean(res .^ 2, 'omitnan'));

    rI = interp1(c.I(:), res, currentGrid, 'linear', NaN);
    rU = interp1(u, res ./ c.S_peak, uGrid, 'linear', NaN);

    residMapI(i, :) = rI;
    residMapU(i, :) = rU;

    curveModels{i} = struct('I', c.I(:), 'S_data', c.S(:), 'S_model', pred, 'residual', res, ...
        'u', u, 'S_norm_data', c.S_norm(:), 'S_norm_model', predNorm);
end

residuals = struct();
residuals.currentGrid = currentGrid;
residuals.uGrid = uGrid;
residuals.residMapI = residMapI;
residuals.residMapU = residMapU;
residuals.residNormL2 = residNormL2;
residuals.residVar = residVar;
residuals.residRMSE = residRMSE;
residuals.nPoints = nPoints;
residuals.curveModels = curveModels;
end

function decomp = runResidualSvd(residuals, cfg)
X = residuals.residMapI;
X(~isfinite(X)) = 0;

[U, S, V] = svd(X, 'econ');
s = diag(S);
if isempty(s)
    error('Residual SVD returned empty spectrum.');
end

energy = s .^ 2;
explained = energy / max(sum(energy), eps);
cumulative = cumsum(explained);

nKeep = min([cfg.maxModes, numel(s), size(U, 2), size(V, 2)]);

amps = U(:, 1:nKeep) * diag(s(1:nKeep));
shapes = V(:, 1:nKeep);

decomp = struct();
decomp.U = U;
decomp.S = S;
decomp.V = V;
decomp.singular = s;
decomp.explained = explained;
decomp.cumulative = cumulative;
decomp.nKeep = nKeep;
decomp.modeAmplitudes = amps;
decomp.modeShapes = shapes;
end

function interpretation = buildInterpretation(prepared, model, residuals, decomp, cfg)
mode1 = decomp.explained(1);
mode2 = 0;
if numel(decomp.explained) >= 2
    mode2 = decomp.explained(2);
end

if model.bestModelRMSE <= 0.06 && mode1 <= 0.65
    sufficiency = 'largely sufficient at leading order';
elseif model.bestModelRMSE <= 0.10
    sufficiency = 'partially sufficient but with visible structured correction';
else
    sufficiency = 'not sufficient at leading order';
end

if mode2 >= cfg.secondModeThreshold
    hasSecondMode = true;
    secondModeText = 'yes, a clear second mode is present';
else
    hasSecondMode = false;
    secondModeText = 'no clear second mode beyond the leading residual mode';
end

mode1Amp = decomp.modeAmplitudes(:, 1);
mode1EnergyByT = mode1Amp .^ 2;

Xcoord = prepared.iPeak ./ (prepared.widthI .* prepared.sPeak);
[~, idxCross] = max(Xcoord);
tCross = prepared.temps(idxCross);
lowMask = prepared.temps < (tCross - cfg.crossoverWindowK);
crossMask = abs(prepared.temps - tCross) <= cfg.crossoverWindowK;
highMask = prepared.temps > (tCross + cfg.crossoverWindowK);

lowEnergy = sum(mode1EnergyByT(lowMask));
crossEnergy = sum(mode1EnergyByT(crossMask));
highEnergy = sum(mode1EnergyByT(highMask));

[~, idxRegion] = max([lowEnergy, crossEnergy, highEnergy]);
if idxRegion == 1
    regionText = 'mainly low T';
elseif idxRegion == 2
    regionText = 'mainly near crossover';
else
    regionText = 'mainly high T';
end

phi1 = decomp.modeShapes(:, 1);
phi1 = phi1(:);
phiFlip = flipud(phi1);
oddPart = 0.5 * (phi1 - phiFlip);
evenPart = 0.5 * (phi1 + phiFlip);
oddPower = sum(oddPart .^ 2);
evenPower = sum(evenPart .^ 2);

if oddPower > 1.2 * evenPower
    correctionText = 'asymmetry-dominated secondary effect';
elseif evenPower > 1.2 * oddPower
    correctionText = 'rigidity-like secondary effect';
else
    correctionText = 'mixed/other secondary effect';
end

interpretation = struct();
interpretation.sufficiencyText = sufficiency;
interpretation.secondModeText = secondModeText;
interpretation.hasSecondMode = hasSecondMode;
interpretation.regionText = regionText;
interpretation.correctionText = correctionText;
interpretation.tCross = tCross;
interpretation.lowEnergy = lowEnergy;
interpretation.crossEnergy = crossEnergy;
interpretation.highEnergy = highEnergy;
interpretation.mode1 = mode1;
interpretation.mode2 = mode2;
interpretation.modelRmse = model.bestModelRMSE;
interpretation.oddPower = oddPower;
interpretation.evenPower = evenPower;
interpretation.Xcoord = Xcoord;
end

function writeOutputs(runDir, run, source, prepared, model, residuals, decomp, interpretation)
writeTables(runDir, source, prepared, model, residuals, decomp, interpretation);
writeFigures(runDir, prepared, model, residuals, decomp, interpretation);
writeReport(runDir, run, source, prepared, model, residuals, decomp, interpretation);
end

function writeTables(runDir, source, prepared, model, residuals, decomp, interpretation)
sourceTbl = table(string(source.sourceRunId), string(source.observablesPath), string(source.samplesPath), ...
    'VariableNames', {'source_run_id', 'observables_csv', 'samples_csv'});
save_run_table(sourceTbl, 'switching_threshold_residual_sources.csv', runDir);

fitTbl = table( ...
    model.fitLog.mu, model.fitLog.scale, model.rmseLog, model.r2Log, ...
    model.fitGauss.mu, model.fitGauss.sigma, model.rmseGauss, model.r2Gauss, ...
    string(model.bestModelName), model.bestModelRMSE, model.bestModelR2, ...
    'VariableNames', {'logistic_mu', 'logistic_scale', 'logistic_rmse', 'logistic_r2', ...
    'gaussian_mu', 'gaussian_sigma', 'gaussian_rmse', 'gaussian_r2', ...
    'best_model', 'best_model_rmse', 'best_model_r2'});
save_run_table(fitTbl, 'switching_threshold_residual_fit_summary.csv', runDir);

collapseTbl = table(model.uGrid, model.sNormMean, model.sNormStd, model.yLog, model.yGauss, model.yBest, ...
    'VariableNames', {'u', 'S_norm_mean', 'S_norm_std', 'logistic_cdf', 'gaussian_cdf', 'best_cdf'});
save_run_table(collapseTbl, 'switching_threshold_residual_normalized_model.csv', runDir);

residualMetricTbl = table(prepared.temps, prepared.iPeak, prepared.widthI, prepared.sPeak, ...
    residuals.nPoints, residuals.residRMSE, residuals.residVar, residuals.residNormL2, ...
    interpretation.Xcoord, ...
    'VariableNames', {'T_K', 'I_peak', 'width_I', 'S_peak', ...
    'n_points', 'residual_rmse', 'residual_variance', 'residual_l2', 'X_coord'});
save_run_table(residualMetricTbl, 'switching_threshold_residual_metrics_vs_temperature.csv', runDir);

modeCount = numel(decomp.singular);
spectrumTbl = table((1:modeCount)', decomp.singular, decomp.explained, decomp.cumulative, ...
    'VariableNames', {'mode_index', 'singular_value', 'explained_variance', 'cumulative_explained'});
save_run_table(spectrumTbl, 'switching_threshold_residual_svd_spectrum.csv', runDir);

nShape = min(3, size(decomp.modeShapes, 2));
shapeData = [residuals.currentGrid, decomp.modeShapes(:, 1:nShape)];
shapeNames = [{'current_mA'}, arrayfun(@(k) sprintf('mode_%d_shape', k), 1:nShape, 'UniformOutput', false)];
shapeTbl = array2table(shapeData, 'VariableNames', shapeNames);
save_run_table(shapeTbl, 'switching_threshold_residual_mode_shapes_current.csv', runDir);

nAmp = min(3, size(decomp.modeAmplitudes, 2));
ampData = [prepared.temps, decomp.modeAmplitudes(:, 1:nAmp)];
ampNames = [{'T_K'}, arrayfun(@(k) sprintf('mode_%d_amplitude', k), 1:nAmp, 'UniformOutput', false)];
ampTbl = array2table(ampData, 'VariableNames', ampNames);
save_run_table(ampTbl, 'switching_threshold_residual_mode_amplitudes_vs_temperature.csv', runDir);

summaryTbl = table(string(interpretation.sufficiencyText), string(interpretation.secondModeText), ...
    string(interpretation.regionText), string(interpretation.correctionText), ...
    interpretation.mode1, interpretation.mode2, interpretation.tCross, ...
    interpretation.lowEnergy, interpretation.crossEnergy, interpretation.highEnergy, ...
    'VariableNames', {'minimal_model_assessment', 'second_mode_assessment', ...
    'dominant_temperature_region', 'correction_character', ...
    'mode1_explained', 'mode2_explained', 'crossover_temperature_K', ...
    'low_energy', 'crossover_energy', 'high_energy'});
save_run_table(summaryTbl, 'switching_threshold_residual_summary_answers.csv', runDir);
end

function writeFigures(runDir, prepared, model, residuals, decomp, interpretation)
baseName = 'switching_threshold_residual_normalized_collapse';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Position', [2 2 12 8]);
ax = axes(fig);
hold(ax, 'on');
nT = prepared.nTemps;
if nT <= 6
    colors = lines(nT);
    for i = 1:nT
        plot(ax, prepared.curves(i).u, prepared.curves(i).S_norm, '-', 'LineWidth', 1.8, ...
            'Color', colors(i, :), 'DisplayName', sprintf('T = %.0f K', prepared.curves(i).T));
    end
    legend(ax, 'Location', 'best');
else
    cmap = parula(nT);
    for i = 1:nT
        plot(ax, prepared.curves(i).u, prepared.curves(i).S_norm, '-', 'LineWidth', 1.4, ...
            'Color', cmap(i, :));
    end
    colormap(ax, parula);
    cb = colorbar(ax);
    cb.Label.String = 'Temperature (K)';
    caxis(ax, [min(prepared.temps), max(prepared.temps)]);
end
plot(ax, model.uGrid, model.yBest, 'k-', 'LineWidth', 2.8, 'DisplayName', 'Best CDF model');
hold(ax, 'off');
xlabel(ax, 'u = (I - I_{peak}) / width_I');
ylabel(ax, 'S / S_{peak}');
title(ax, sprintf('Normalized collapse with best model (%s)', strrep(model.bestModelName, '_', '\_')));
grid(ax, 'on');
styleAxes(ax);
save_run_figure(fig, baseName, runDir);
close(fig);

baseName = 'switching_threshold_residual_model_fit_comparison';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Position', [2 2 12 8]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, model.uGrid, model.sNormMean, 'ko', 'LineWidth', 1.6, 'MarkerSize', 4, 'DisplayName', 'Mean normalized data');
plot(ax, model.uGrid, model.yLog, '-', 'LineWidth', 2.2, 'Color', [0.00 0.45 0.74], 'DisplayName', ...
    sprintf('Logistic (RMSE=%.4g)', model.rmseLog));
plot(ax, model.uGrid, model.yGauss, '--', 'LineWidth', 2.2, 'Color', [0.85 0.33 0.10], 'DisplayName', ...
    sprintf('Gaussian CDF (RMSE=%.4g)', model.rmseGauss));
hold(ax, 'off');
xlabel(ax, 'u = (I - I_{peak}) / width_I');
ylabel(ax, 'S / S_{peak}');
title(ax, 'Best normalized threshold-model fit');
legend(ax, 'Location', 'best');
grid(ax, 'on');
styleAxes(ax);
save_run_figure(fig, baseName, runDir);
close(fig);

baseName = 'switching_threshold_residual_map_current_temperature';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Position', [2 2 12 8]);
ax = axes(fig);
imagesc(ax, residuals.currentGrid, prepared.temps, residuals.residMapI);
axis(ax, 'xy');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'Residual S_data - S_model (P2P percent)';
xlabel(ax, 'Current (mA)');
ylabel(ax, 'Temperature (K)');
title(ax, 'Residual map in current-temperature coordinates');
grid(ax, 'on');
styleAxes(ax);
save_run_figure(fig, baseName, runDir);
close(fig);

baseName = 'switching_threshold_residual_map_normalized_temperature';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Position', [2 2 12 8]);
ax = axes(fig);
imagesc(ax, residuals.uGrid, prepared.temps, residuals.residMapU);
axis(ax, 'xy');
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = 'Residual (S_data - S_model) / S_peak';
xlabel(ax, 'u = (I - I_{peak}) / width_I');
ylabel(ax, 'Temperature (K)');
title(ax, 'Residual map in normalized coordinates');
grid(ax, 'on');
styleAxes(ax);
save_run_figure(fig, baseName, runDir);
close(fig);

baseName = 'switching_threshold_residual_metrics_vs_temperature';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Position', [2 2 12 8]);
ax = axes(fig);
yyaxis(ax, 'left');
plot(ax, prepared.temps, residuals.residRMSE, '-o', 'LineWidth', 2.0, 'Color', [0.00 0.45 0.74], ...
    'MarkerFaceColor', [0.00 0.45 0.74], 'DisplayName', 'RMSE');
ylabel(ax, 'Residual RMSE (P2P percent)');
yyaxis(ax, 'right');
plot(ax, prepared.temps, residuals.residVar, '-s', 'LineWidth', 2.0, 'Color', [0.85 0.33 0.10], ...
    'MarkerFaceColor', [0.85 0.33 0.10], 'DisplayName', 'Variance');
ylabel(ax, 'Residual variance');
xlabel(ax, 'Temperature (K)');
title(ax, 'Per-temperature residual strength');
grid(ax, 'on');
styleAxes(ax);
save_run_figure(fig, baseName, runDir);
close(fig);

baseName = 'switching_threshold_residual_svd_explained_variance';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Position', [2 2 12 8]);
ax = axes(fig);
modeIdx = (1:numel(decomp.explained))';
bar(ax, modeIdx, decomp.explained, 'FaceColor', [0.20 0.55 0.30], 'EdgeColor', 'none');
hold(ax, 'on');
plot(ax, modeIdx, decomp.cumulative, '-o', 'LineWidth', 2.0, 'Color', [0.85 0.33 0.10], ...
    'MarkerFaceColor', [0.85 0.33 0.10], 'DisplayName', 'Cumulative');
hold(ax, 'off');
xlabel(ax, 'Residual mode index');
ylabel(ax, 'Explained variance fraction');
title(ax, 'Residual-mode explained variance spectrum');
legend(ax, {'Per mode', 'Cumulative'}, 'Location', 'best');
grid(ax, 'on');
styleAxes(ax);
save_run_figure(fig, baseName, runDir);
close(fig);

baseName = 'switching_threshold_residual_mode_shapes';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Position', [2 2 12 8]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, residuals.currentGrid, decomp.modeShapes(:, 1), '-', 'LineWidth', 2.4, ...
    'Color', [0.00 0.45 0.74], 'DisplayName', 'Mode 1 shape');
if size(decomp.modeShapes, 2) >= 2
    plot(ax, residuals.currentGrid, decomp.modeShapes(:, 2), '--', 'LineWidth', 2.2, ...
        'Color', [0.85 0.33 0.10], 'DisplayName', 'Mode 2 shape');
end
hold(ax, 'off');
xlabel(ax, 'Current (mA)');
ylabel(ax, 'Mode shape (a.u.)');
title(ax, 'Leading residual mode shapes');
legend(ax, 'Location', 'best');
grid(ax, 'on');
styleAxes(ax);
save_run_figure(fig, baseName, runDir);
close(fig);

baseName = 'switching_threshold_residual_mode1_amplitude_vs_temperature';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Position', [2 2 12 8]);
ax = axes(fig);
plot(ax, prepared.temps, decomp.modeAmplitudes(:, 1), '-o', 'LineWidth', 2.2, ...
    'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74]);
hold(ax, 'on');
xline(ax, interpretation.tCross, '--k', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Crossover T*=%.1f K', interpretation.tCross));
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Mode 1 amplitude (a.u.)');
title(ax, 'Leading residual mode amplitude vs temperature');
legend(ax, 'Location', 'best');
grid(ax, 'on');
styleAxes(ax);
save_run_figure(fig, baseName, runDir);
close(fig);

baseName = 'switching_threshold_residual_reconstruction_examples';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Position', [2 2 14 9]);
ax = axes(fig);
hold(ax, 'on');
idxLow = 1;
idxMid = round(prepared.nTemps / 2);
idxHigh = prepared.nTemps;
sel = unique([idxLow, idxMid, idxHigh]);
colors = lines(numel(sel));
for k = 1:numel(sel)
    i = sel(k);
    c = residuals.curveModels{i};
    plot(ax, c.I, c.S_data, '-', 'LineWidth', 2.2, 'Color', colors(k, :), ...
        'DisplayName', sprintf('Data %.0f K', prepared.temps(i)));
    plot(ax, c.I, c.S_model, '--', 'LineWidth', 2.0, 'Color', colors(k, :), ...
        'DisplayName', sprintf('Model %.0f K', prepared.temps(i)));
end
hold(ax, 'off');
xlabel(ax, 'Current (mA)');
ylabel(ax, 'Switching response S (P2P percent)');
title(ax, 'Model reconstruction examples across temperature');
legend(ax, 'Location', 'bestoutside');
grid(ax, 'on');
styleAxes(ax);
save_run_figure(fig, baseName, runDir);
close(fig);
end

function writeReport(runDir, run, source, prepared, model, residuals, decomp, interpretation)
lines = strings(0, 1);
lines(end + 1) = '# Switching threshold residual-structure analysis';
lines(end + 1) = '';
lines(end + 1) = '## Scope';
lines(end + 1) = '- Task: characterize residual structure after the minimal threshold-distribution model.';
lines(end + 1) = '- Constraint: existing run outputs only; historical runs were not modified.';
lines(end + 1) = '- Source run: `' + source.sourceRunId + '`';
lines(end + 1) = '- Source observables: `' + string(source.observablesPath) + '`';
lines(end + 1) = '- Source samples: `' + string(source.samplesPath) + '`';
lines(end + 1) = '';
lines(end + 1) = '## Minimal model used';
lines(end + 1) = '- Data normalization: `u = (I-I_peak)/width_I`, `S_norm = S/S_peak`';
lines(end + 1) = '- Fitted normalized CDF candidates: logistic and Gaussian CDF.';
lines(end + 1) = '- Best normalized model: `' + string(model.bestModelName) + '`';
lines(end + 1) = sprintf('- Logistic: RMSE = %.6g, R2 = %.6f', model.rmseLog, model.r2Log);
lines(end + 1) = sprintf('- Gaussian CDF: RMSE = %.6g, R2 = %.6f', model.rmseGauss, model.r2Gauss);
lines(end + 1) = sprintf('- Best model RMSE = %.6g, R2 = %.6f', model.bestModelRMSE, model.bestModelR2);
lines(end + 1) = '';
lines(end + 1) = '## Residual analysis outputs';
lines(end + 1) = sprintf('- Temperatures used: %d', prepared.nTemps);
lines(end + 1) = sprintf('- Current-grid points in residual map: %d', numel(residuals.currentGrid));
lines(end + 1) = '- Residual map generated in both `I-T` and normalized `u-T` coordinates.';
lines(end + 1) = '- Per-temperature residual norm/variance exported to `tables/`.';
lines(end + 1) = '';
lines(end + 1) = '## Residual PCA/SVD';
lines(end + 1) = sprintf('- Mode 1 explained variance: %.4f', decomp.explained(1));
if numel(decomp.explained) >= 2
    lines(end + 1) = sprintf('- Mode 2 explained variance: %.4f', decomp.explained(2));
end
if numel(decomp.explained) >= 3
    lines(end + 1) = sprintf('- Mode 3 explained variance: %.4f', decomp.explained(3));
end
lines(end + 1) = '';
lines(end + 1) = '## Required answers';
lines(end + 1) = '- Is the minimal model sufficient at leading order? **' + string(interpretation.sufficiencyText) + '**.';
lines(end + 1) = '- Is there a clear second mode? **' + string(interpretation.secondModeText) + '**.';
lines(end + 1) = '- Where does correction dominate? **' + string(interpretation.regionText) + '**.';
lines(end + 1) = '- Correction character: **' + string(interpretation.correctionText) + '**.';
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- number of curves in normalized collapse: ' + string(prepared.nTemps);
if prepared.nTemps <= 6
    lines(end + 1) = '- legend vs colormap: explicit legend';
else
    lines(end + 1) = '- legend vs colormap: colormap + colorbar (parula)';
end
lines(end + 1) = '- colormap used: parula';
lines(end + 1) = '- smoothing applied: none';
lines(end + 1) = '- justification: residual-mode structure is resolved directly from measured curves and model reconstruction; no derivative noise amplification step used.';
lines(end + 1) = '';
lines(end + 1) = '## Output inventory';
lines(end + 1) = '- `figures/switching_threshold_residual_normalized_collapse.*`';
lines(end + 1) = '- `figures/switching_threshold_residual_model_fit_comparison.*`';
lines(end + 1) = '- `figures/switching_threshold_residual_map_current_temperature.*`';
lines(end + 1) = '- `figures/switching_threshold_residual_map_normalized_temperature.*`';
lines(end + 1) = '- `figures/switching_threshold_residual_metrics_vs_temperature.*`';
lines(end + 1) = '- `figures/switching_threshold_residual_svd_explained_variance.*`';
lines(end + 1) = '- `figures/switching_threshold_residual_mode_shapes.*`';
lines(end + 1) = '- `figures/switching_threshold_residual_mode1_amplitude_vs_temperature.*`';
lines(end + 1) = '- `figures/switching_threshold_residual_reconstruction_examples.*`';
lines(end + 1) = '- `tables/switching_threshold_residual_*.csv`';
lines(end + 1) = '- `review/switching_threshold_residual_structure_bundle.zip`';
lines(end + 1) = '';
lines(end + 1) = 'Generated: ' + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
lines(end + 1) = 'Run id: `' + string(run.run_id) + '`';

save_run_report(strjoin(lines, newline), 'switching_threshold_residual_structure_report.md', runDir);
end

function fit = fitLogisticCdf(u, y)
u = u(:);
y = y(:);
mu0 = median(u);
scale0 = std(u);
if ~isfinite(scale0) || scale0 <= 0
    scale0 = 1;
end
p0 = [mu0; log(scale0)];
obj = @(p) sum((y - logisticCdf(u, p(1), exp(p(2)))).^2, 'omitnan');
opts = optimset('Display', 'off', 'MaxFunEvals', 2e4, 'MaxIter', 2e4);
p = fminsearch(obj, p0, opts);
fit = struct();
fit.mu = p(1);
fit.scale = max(exp(p(2)), 1e-6);
end

function fit = fitGaussianCdf(u, y)
u = u(:);
y = y(:);
mu0 = median(u);
sigma0 = std(u);
if ~isfinite(sigma0) || sigma0 <= 0
    sigma0 = 1;
end
p0 = [mu0; log(sigma0)];
obj = @(p) sum((y - gaussianCdf(u, p(1), exp(p(2)))).^2, 'omitnan');
opts = optimset('Display', 'off', 'MaxFunEvals', 2e4, 'MaxIter', 2e4);
p = fminsearch(obj, p0, opts);
fit = struct();
fit.mu = p(1);
fit.sigma = max(exp(p(2)), 1e-6);
end

function y = logisticCdf(u, mu, scale)
z = (u - mu) ./ max(scale, 1e-12);
y = 1 ./ (1 + exp(-z));
y = min(max(y, 0), 1);
end

function y = gaussianCdf(u, mu, sigma)
z = (u - mu) ./ (sqrt(2) * max(sigma, 1e-12));
y = 0.5 * (1 + erf(z));
y = min(max(y, 0), 1);
end

function [rmse, r2] = fitMetrics(y, yhat)
res = y - yhat;
rmse = sqrt(mean(res.^2, 'omitnan'));
ssRes = sum(res.^2, 'omitnan');
ssTot = sum((y - mean(y, 'omitnan')).^2, 'omitnan');
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
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

function ensureArtifactDirs(runDir)
required = {'figures', 'tables', 'reports', 'review'};
for i = 1:numel(required)
    p = fullfile(runDir, required{i});
    if exist(p, 'dir') ~= 7
        mkdir(p);
    end
end
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

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
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
