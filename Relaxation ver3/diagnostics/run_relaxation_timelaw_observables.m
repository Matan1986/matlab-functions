function out = run_relaxation_timelaw_observables(cfg)
% run_relaxation_timelaw_observables
% Standalone diagnostics for relaxation time-law observables.

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

cfg = applyDefaults(cfg);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
run = createRunContext('relaxation', runCfg);
runDir = getRunOutputDir();
fprintf('Relaxation timelaw observables run directory:\n%s\n', runDir);

inputData = resolveInputData(repoRoot, cfg);
fprintf('DeltaM source: %s\n', char(inputData.source.dMSource));
if strlength(inputData.source.SSource) > 0
    fprintf('S source: %s\n', char(inputData.source.SSource));
else
    fprintf('S source: derived from DeltaM map within this diagnostic\n');
end

[globalFitRows, residualTbl, svdOut, globalObs] = analyzeDominantTimeMode( ...
    inputData.dMMap, inputData.xGrid);
[sliceTbl, representativeIdx] = fitTemperatureSlices( ...
    inputData.dMMap, inputData.SMap, inputData.T, inputData.xGrid, cfg.representativeSlices);

timeFitResults = assembleResultsTable(globalFitRows, sliceTbl);
fitResultsPath = save_run_table(timeFitResults, 'time_fit_results.csv', runDir);
residualPath = save_run_table(residualTbl, 'time_fit_residuals.csv', runDir);

globalFigPaths = saveDominantModeFigure(inputData.xGrid, svdOut.v1, globalFitRows, runDir);
residualFigPaths = saveResidualFigure(inputData.xGrid, residualTbl, runDir);
betaFigPaths = saveBetaFigure(sliceTbl, runDir);
tauFigPaths = saveTauFigure(sliceTbl, runDir);
sliceFigPaths = saveSliceFitsFigure(inputData.xGrid, inputData.T, inputData.dMMap, representativeIdx, runDir);

observablesPath = exportTimelawObservables(runDir, run.run_id, inputData.source.sampleName, globalObs, sliceTbl);

fitParametersPath = fullfile(runDir, 'fit_parameters.mat');
fitParameters = struct();
fitParameters.source = inputData.source;
fitParameters.svd = svdOut;
fitParameters.globalFits = table2struct(globalFitRows);
fitParameters.globalObservables = globalObs;
fitParameters.temperatureFits = table2struct(sliceTbl);
save(fitParametersPath, 'fitParameters');
fprintf('Saved MAT: %s\n', fitParametersPath);

reportText = buildReport(inputData.source, globalFitRows, globalObs, sliceTbl, size(inputData.dMMap, 1));
reportPath = save_run_report(reportText, 'relaxation_timelaw_observables.md', runDir);

appendText(run.log_path, sprintf('[%s] timelaw observables completed\n', stampNow()));
appendText(run.log_path, sprintf('DeltaM source: %s\n', char(inputData.source.dMSource)));
appendText(run.log_path, sprintf('S source: %s\n', char(emptyAsDerived(inputData.source.SSource))));
appendText(run.log_path, sprintf('Best dominant-mode model: %s\n', char(globalObs.best_model)));
appendText(run.notes_path, sprintf('Relax_beta_global = %.6g\n', globalObs.Relax_beta_global));
appendText(run.notes_path, sprintf('Relax_tau_global = %.6g s\n', globalObs.Relax_tau_global));

reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, sprintf('relaxation_timelaw_observables_%s.zip', run.run_id));
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zipInputs = {'figures', 'tables', 'reports', 'fit_parameters.mat', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt', 'observables.csv'};
zip(zipPath, zipInputs, runDir);

out = struct();
out.run = run;
out.runDir = string(runDir);
out.timeFitResultsPath = string(fitResultsPath);
out.residualTablePath = string(residualPath);
out.observablesPath = string(observablesPath);
out.fitParametersPath = string(fitParametersPath);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.figures = struct( ...
    'v1_with_fits', string(globalFigPaths.png), ...
    'fit_residuals', string(residualFigPaths.png), ...
    'beta_vs_temperature', string(betaFigPaths.png), ...
    'tau_vs_temperature', string(tauFigPaths.png), ...
    'time_slice_fits', string(sliceFigPaths.png));

fprintf('\n=== Relaxation timelaw observables complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Results table: %s\n', fitResultsPath);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDef(cfg, 'runLabel', 'timelaw_observables');
cfg = setDef(cfg, 'dMMapPath', "");
cfg = setDef(cfg, 'SMapPath', "");
cfg = setDef(cfg, 'representativeSlices', 4);
end

function inputData = resolveInputData(repoRoot, cfg)
source = struct('sampleName', "relaxation", 'dMSource', "", 'SSource', "");

if strlength(strtrim(string(cfg.dMMapPath))) > 0
    dMPath = char(string(cfg.dMMapPath));
else
    [dMPath, found] = resolveLatestExistingMap(repoRoot, 'dM');
    if ~found
        error('No DeltaM map was found. Set cfg.dMMapPath to an exported relaxation map CSV.');
    end
end
[dMMap, T, xGrid] = loadMapMatrix(dMPath);
source.dMSource = string(dMPath);
source.sampleName = string(stripExtension(dMPath));

if strlength(strtrim(string(cfg.SMapPath))) > 0 && exist(char(string(cfg.SMapPath)), 'file') == 2
    [SMapCandidate, ST, SX] = loadMapMatrix(char(string(cfg.SMapPath)));
    SMap = alignOrDeriveSMap(dMMap, T, xGrid, SMapCandidate, ST, SX);
    source.SSource = string(cfg.SMapPath);
else
    [SPath, foundS] = resolveLatestExistingMap(repoRoot, 'S');
    if foundS
        [SMapCandidate, ST, SX] = loadMapMatrix(SPath);
        SMap = alignOrDeriveSMap(dMMap, T, xGrid, SMapCandidate, ST, SX);
        source.SSource = string(SPath);
    else
        SMap = deriveSMapFromDeltaM(dMMap, xGrid);
    end
end

inputData = struct('dMMap', dMMap, 'SMap', SMap, 'T', T, 'xGrid', xGrid, 'source', source);
end

function [fitRows, residualTbl, svdOut, globalObs] = analyzeDominantTimeMode(dMMap, xGrid)
[U, S, V] = svd(dMMap, 'econ');
[U, V] = orientFirstMode(U, V);
v1 = V(:, 1);
tGrid = 10 .^ xGrid(:);

fitRows = struct2table([fitStretchedModel(tGrid, v1), fitLogModel(tGrid, v1), fitPowerLawModel(tGrid, v1)]);
bestIdx = selectBestFitIndex(fitRows);
fitRows.best_model = false(height(fitRows), 1);
fitRows.best_model(bestIdx) = true;

residualTbl = table(xGrid(:), tGrid(:), v1(:), fitRows.y_fit{1}(:), fitRows.residual{1}(:), ...
    fitRows.y_fit{2}(:), fitRows.residual{2}(:), fitRows.y_fit{3}(:), fitRows.residual{3}(:), ...
    'VariableNames', {'log10_t_s', 't_s', 'v1_data', 'v1_stretched_fit', 'residual_stretched_exponential', ...
    'v1_log_fit', 'residual_logarithmic', 'v1_power_fit', 'residual_power_law'});

globalObs = struct();
globalObs.best_model = string(fitRows.model(bestIdx));
globalObs.Relax_beta_global = fitRows.param_beta(1);
globalObs.Relax_tau_global = fitRows.param_tau(1);
globalObs.Relax_t_half = fitRows.Relax_t_half(1);
globalObs.Relax_initial_slope = earlySlopeFromSignal(v1, xGrid);
globalObs.rank1_singular_value = S(1, 1);
globalObs.rank1_energy_fraction = (S(1, 1) ^ 2) / max(sum(diag(S) .^ 2), eps);

svdOut = struct('U', U, 'S', S, 'V', V, 'v1', v1, 'xGrid', xGrid(:), 'tGrid', tGrid(:));
end

function [sliceTbl, representativeIdx] = fitTemperatureSlices(dMMap, SMap, T, xGrid, nRep)
tGrid = 10 .^ xGrid(:);
rows = repmat(struct('Temp_K', NaN, 'model', "stretched_exponential", 'fit_ok', false, 'n_points', 0, ...
    'param_a', NaN, 'param_b', NaN, 'param_alpha', NaN, 'param_tau', NaN, 'param_beta', NaN, ...
    'param_amp', NaN, 'R2', NaN, 'AIC', NaN, 'rms_error', NaN, 'Relax_t_half', NaN, ...
    'Relax_initial_slope', NaN), numel(T), 1);
for i = 1:numel(T)
    fit = fitStretchedModel(tGrid, dMMap(i, :).');
    rows(i).Temp_K = T(i);
    rows(i).fit_ok = fit.fit_ok;
    rows(i).n_points = numel(tGrid);
    rows(i).param_a = fit.param_a;
    rows(i).param_b = fit.param_b;
    rows(i).param_alpha = fit.param_alpha;
    rows(i).param_tau = fit.param_tau;
    rows(i).param_beta = fit.param_beta;
    rows(i).param_amp = fit.param_amp;
    rows(i).R2 = fit.R2;
    rows(i).AIC = fit.AIC;
    rows(i).rms_error = fit.rms_error;
    rows(i).Relax_t_half = fit.Relax_t_half;
    rows(i).Relax_initial_slope = mean(SMap(i, 1:min(3, size(SMap, 2))), 2, 'omitnan');
end
sliceTbl = sortrows(struct2table(rows), 'Temp_K');
representativeIdx = chooseRepresentativeTemperatures(sliceTbl.Temp_K, nRep);
end

function resultsTbl = assembleResultsTable(globalFitRows, sliceTbl)
g = table(repmat("dominant_time_mode", height(globalFitRows), 1), globalFitRows.model, nan(height(globalFitRows), 1), ...
    globalFitRows.best_model, repmat(true, height(globalFitRows), 1), globalFitRows.param_a, globalFitRows.param_b, ...
    globalFitRows.param_alpha, globalFitRows.param_tau, globalFitRows.param_beta, globalFitRows.param_amp, ...
    globalFitRows.R2, globalFitRows.AIC, globalFitRows.rms_error, globalFitRows.Relax_t_half, ...
    globalFitRows.Relax_initial_slope, 'VariableNames', {'scope', 'model', 'Temp_K', 'best_model', 'fit_ok', ...
    'param_a', 'param_b', 'param_alpha', 'param_tau', 'param_beta', 'param_amp', 'R2', 'AIC', 'rms_error', ...
    'Relax_t_half', 'Relax_initial_slope'});
t = table(repmat("temperature_slice", height(sliceTbl), 1), sliceTbl.model, sliceTbl.Temp_K, false(height(sliceTbl), 1), ...
    sliceTbl.fit_ok, sliceTbl.param_a, sliceTbl.param_b, sliceTbl.param_alpha, sliceTbl.param_tau, ...
    sliceTbl.param_beta, sliceTbl.param_amp, sliceTbl.R2, sliceTbl.AIC, sliceTbl.rms_error, ...
    sliceTbl.Relax_t_half, sliceTbl.Relax_initial_slope, 'VariableNames', g.Properties.VariableNames);
resultsTbl = [g; t];
end

function fit = fitStretchedModel(t, y)
[pars, R2, stats] = fitStretchedExp(t, y, NaN, false, struct());
yFit = nan(size(y));
if isfield(stats, 'Mfit') && ~isempty(stats.Mfit), yFit = stats.Mfit(:); end
fit = emptyFitRow("stretched_exponential");
fit.param_a = pars.Minf;
fit.param_tau = pars.tau;
fit.param_beta = pars.n;
fit.param_amp = pars.dM;
fit.R2 = R2;
fit.y_fit = yFit;
fit.residual = y(:) - yFit(:);
fit.rms_error = computeRMSE(y, yFit);
fit.AIC = computeAIC(y, yFit, 4);
fit.Relax_t_half = computeHalfTime(t, yFit);
fit.Relax_initial_slope = earlySlopeFromSignal(y, log10(max(t, eps)));
fit.fit_ok = all(isfinite([fit.R2, fit.AIC, fit.rms_error]));
end
function fit = fitLogModel(t, y)
[pars, R2, yFit] = fitLogRelaxation(t, y, NaN, false, struct('minTimeForLog', max(min(t) * 0.1, 1e-9)));
fit = emptyFitRow("logarithmic");
fit.param_a = pars.M0;
fit.param_b = -pars.S;
fit.param_amp = pars.S;
fit.R2 = R2;
fit.y_fit = yFit(:);
fit.residual = y(:) - yFit(:);
fit.rms_error = computeRMSE(y, yFit);
fit.AIC = computeAIC(y, yFit, 2);
fit.Relax_t_half = computeHalfTime(t, yFit);
fit.Relax_initial_slope = earlySlopeFromSignal(y, log10(max(t, eps)));
fit.fit_ok = all(isfinite([fit.R2, fit.AIC, fit.rms_error]));
end

function fit = fitPowerLawModel(t, y)
t = t(:); y = y(:);
fit = emptyFitRow("power_law");
nTail = min(5, numel(y));
offset0 = mean(y(end-nTail+1:end), 'omitnan');
shifted = y - offset0;
pos = shifted > max(abs(shifted)) * 1e-6;
if nnz(pos) < 5
    pos = abs(y) > max(abs(y)) * 1e-6;
    offset0 = 0;
end
if nnz(pos) < 5
    fit.y_fit = nan(size(y));
    fit.residual = nan(size(y));
    return;
end
coeff = polyfit(log(t(pos)), log(abs(y(pos) - offset0)), 1);
alpha0 = max(0, -coeff(1));
amp0 = exp(coeff(2));
if mean(y(pos)) < offset0, amp0 = -amp0; end
obj = @(p) sum((y - (p(1) * t .^ (-abs(p(2))) + p(3))).^2, 'omitnan');
opts = optimset('Display', 'off');
try
    p = fminsearch(obj, [amp0, alpha0, offset0], opts);
    yFit = p(1) * t .^ (-abs(p(2))) + p(3);
    fit.param_a = p(3);
    fit.param_alpha = abs(p(2));
    fit.param_amp = p(1);
catch
    yFit = nan(size(y));
end
fit.R2 = computeR2(y, yFit);
fit.y_fit = yFit(:);
fit.residual = y(:) - yFit(:);
fit.rms_error = computeRMSE(y, yFit);
fit.AIC = computeAIC(y, yFit, 3);
fit.Relax_t_half = computeHalfTime(t, yFit);
fit.Relax_initial_slope = earlySlopeFromSignal(y, log10(max(t, eps)));
fit.fit_ok = all(isfinite([fit.R2, fit.AIC, fit.rms_error]));
end

function row = emptyFitRow(modelName)
row = struct('model', string(modelName), 'param_a', NaN, 'param_b', NaN, 'param_alpha', NaN, ...
    'param_tau', NaN, 'param_beta', NaN, 'param_amp', NaN, 'R2', NaN, 'AIC', NaN, ...
    'rms_error', NaN, 'Relax_t_half', NaN, 'Relax_initial_slope', NaN, 'fit_ok', false, ...
    'y_fit', [], 'residual', []);
end

function paths = saveDominantModeFigure(xGrid, v1, fitRows, runDir)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 960 560]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);
plot(ax, xGrid, v1, '-', 'Color', [0 0 0], 'LineWidth', 2.8, 'DisplayName', 'v_1 data');
cols = lines(height(fitRows));
for i = 1:height(fitRows)
    plot(ax, xGrid, fitRows.y_fit{i}, '-', 'Color', cols(i, :), 'LineWidth', 2.1, ...
        'DisplayName', sprintf('%s (R^2=%.4f, AIC=%.2f)', char(fitRows.model(i)), fitRows.R2(i), fitRows.AIC(i)));
end
xlabel(ax, 'log_{10}(t [s])', 'FontSize', 15);
ylabel(ax, 'v_1(t)', 'FontSize', 15);
title(ax, 'Dominant time mode with time-law fits', 'FontSize', 16, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', 11);
paths = save_run_figure(fig, 'v1_time_mode_with_fits', runDir);
close(fig);
end

function paths = saveResidualFigure(xGrid, residualTbl, runDir)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 960 560]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);
plot(ax, xGrid, residualTbl.residual_stretched_exponential, '-', 'LineWidth', 2.1, 'DisplayName', 'stretched exponential');
plot(ax, xGrid, residualTbl.residual_logarithmic, '-', 'LineWidth', 2.1, 'DisplayName', 'logarithmic');
plot(ax, xGrid, residualTbl.residual_power_law, '-', 'LineWidth', 2.1, 'DisplayName', 'power law');
yline(ax, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.4, 'HandleVisibility', 'off');
xlabel(ax, 'log_{10}(t [s])', 'FontSize', 15);
ylabel(ax, 'Residual', 'FontSize', 15);
title(ax, 'Dominant time-mode fit residuals', 'FontSize', 16, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', 11);
paths = save_run_figure(fig, 'time_mode_fit_residuals', runDir);
close(fig);
end

function paths = saveBetaFigure(sliceTbl, runDir)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 920 540]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);
ok = sliceTbl.fit_ok & isfinite(sliceTbl.param_beta);
plot(ax, sliceTbl.Temp_K(ok), sliceTbl.param_beta(ok), '-o', 'Color', [0.10 0.35 0.75], 'LineWidth', 2.2, 'MarkerSize', 6);
xlabel(ax, 'Temperature (K)', 'FontSize', 15);
ylabel(ax, '\beta(T)', 'FontSize', 15);
title(ax, 'Stretched-exponential \beta(T)', 'FontSize', 16, 'FontWeight', 'bold');
paths = save_run_figure(fig, 'beta_vs_temperature', runDir);
close(fig);
end

function paths = saveTauFigure(sliceTbl, runDir)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 920 540]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1, 'YScale', 'log');
ok = sliceTbl.fit_ok & isfinite(sliceTbl.param_tau) & (sliceTbl.param_tau > 0);
plot(ax, sliceTbl.Temp_K(ok), sliceTbl.param_tau(ok), '-o', 'Color', [0.80 0.20 0.10], 'LineWidth', 2.2, 'MarkerSize', 6);
xlabel(ax, 'Temperature (K)', 'FontSize', 15);
ylabel(ax, '\tau(T) [s]', 'FontSize', 15);
title(ax, 'Stretched-exponential \tau(T)', 'FontSize', 16, 'FontWeight', 'bold');
paths = save_run_figure(fig, 'tau_vs_temperature', runDir);
close(fig);
end

function paths = saveSliceFitsFigure(xGrid, T, dMMap, representativeIdx, runDir)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100 80 1100 700]);
tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
tGrid = 10 .^ xGrid(:);
for k = 1:numel(representativeIdx)
    idx = representativeIdx(k);
    ax = nexttile; hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    set(ax, 'FontSize', 13, 'LineWidth', 1.0);
    fit = fitStretchedModel(tGrid, dMMap(idx, :).');
    plot(ax, xGrid, dMMap(idx, :), '-', 'Color', [0 0 0], 'LineWidth', 2.2, 'DisplayName', 'data');
    plot(ax, xGrid, fit.y_fit, '--', 'Color', [0.10 0.35 0.75], 'LineWidth', 2.2, 'DisplayName', 'stretched exp');
    xlabel(ax, 'log_{10}(t [s])', 'FontSize', 14);
    ylabel(ax, '\DeltaM(T,t)', 'FontSize', 14);
    title(ax, sprintf('T = %.3f K, beta = %.3f, tau = %.3g s', T(idx), fit.param_beta, fit.param_tau), 'FontSize', 14);
    legend(ax, 'Location', 'best', 'FontSize', 10);
end
paths = save_run_figure(fig, 'time_slice_fits', runDir);
close(fig);
end

function outPath = exportTimelawObservables(runDir, runId, sampleName, globalObs, sliceTbl)
obsGlobal = table( ...
    repmat("relaxation", 3, 1), repmat(string(sampleName), 3, 1), nan(3, 1), ...
    ["Relax_beta_global"; "Relax_tau_global"; "Relax_initial_slope"], ...
    [globalObs.Relax_beta_global; globalObs.Relax_tau_global; globalObs.Relax_initial_slope], ...
    ["unitless"; "s"; "signal_per_log10s"], repmat("observable", 3, 1), repmat(string(runId), 3, 1), ...
    'VariableNames', {'experiment', 'sample', 'temperature', 'observable', 'value', 'units', 'role', 'source_run'});
ok = sliceTbl.fit_ok;
obsPerT = table();
for i = find(ok).'
    rows = table( ...
        repmat("relaxation", 2, 1), repmat(string(sampleName), 2, 1), repmat(sliceTbl.Temp_K(i), 2, 1), ...
        ["Relax_tau_T"; "Relax_initial_slope"], ...
        [sliceTbl.param_tau(i); sliceTbl.Relax_initial_slope(i)], ...
        ["s"; "signal_per_log10s"], repmat("observable", 2, 1), repmat(string(runId), 2, 1), ...
        'VariableNames', obsGlobal.Properties.VariableNames);
    obsPerT = [obsPerT; rows]; %#ok<AGROW>
end
outPath = export_observables('relaxation', runDir, [obsGlobal; obsPerT]);
end

function reportText = buildReport(source, globalFitRows, globalObs, sliceTbl, nTemps)
bestIdx = find(globalFitRows.best_model, 1, 'first');
lines = {};
lines{end+1,1} = '# Relaxation Timelaw Observables';
lines{end+1,1} = '';
lines{end+1,1} = '## Inputs';
lines{end+1,1} = ['- DeltaM source: `' char(source.dMSource) '`'];
if strlength(source.SSource) > 0
    lines{end+1,1} = ['- S source: `' char(source.SSource) '`'];
else
    lines{end+1,1} = '- S source: derived from the DeltaM map in this diagnostic';
end
lines{end+1,1} = sprintf('- Temperatures analyzed in the map: %d', nTemps);
lines{end+1,1} = '';
lines{end+1,1} = '## Best Time-Law Model';
lines{end+1,1} = ['- Best model for v_1(t): `' char(globalFitRows.model(bestIdx)) '`'];
lines{end+1,1} = sprintf('- Fit quality: R^2 = %.6f, AIC = %.3f, RMSE = %.6g', globalFitRows.R2(bestIdx), globalFitRows.AIC(bestIdx), globalFitRows.rms_error(bestIdx));
lines{end+1,1} = '';
lines{end+1,1} = '## Global Time Observables';
lines{end+1,1} = sprintf('- Relax_beta_global = %.6g', globalObs.Relax_beta_global);
lines{end+1,1} = sprintf('- Relax_tau_global = %.6g s', globalObs.Relax_tau_global);
lines{end+1,1} = sprintf('- Relax_t_half = %.6g s', globalObs.Relax_t_half);
lines{end+1,1} = sprintf('- Relax_initial_slope = %.6g signal per log10(s)', globalObs.Relax_initial_slope);
lines{end+1,1} = '';
lines{end+1,1} = '## Fit Quality Comparison';
lines{end+1,1} = '| model | R^2 | AIC | RMSE |';
lines{end+1,1} = '| --- | ---: | ---: | ---: |';
for i = 1:height(globalFitRows)
    lines{end+1,1} = sprintf('| %s | %.6f | %.3f | %.6g |', char(globalFitRows.model(i)), globalFitRows.R2(i), globalFitRows.AIC(i), globalFitRows.rms_error(i));
end
lines{end+1,1} = '';
lines{end+1,1} = '## Temperature Dependence';
lines{end+1,1} = sprintf('- Valid stretched-exponential temperature slices: %d / %d', nnz(sliceTbl.fit_ok), height(sliceTbl));
lines{end+1,1} = sprintf('- beta(T) range: %.6g to %.6g', min(sliceTbl.param_beta(sliceTbl.fit_ok), [], 'omitnan'), max(sliceTbl.param_beta(sliceTbl.fit_ok), [], 'omitnan'));
lines{end+1,1} = sprintf('- tau(T) range: %.6g to %.6g s', min(sliceTbl.param_tau(sliceTbl.fit_ok), [], 'omitnan'), max(sliceTbl.param_tau(sliceTbl.fit_ok), [], 'omitnan'));
lines{end+1,1} = '';
lines{end+1,1} = '## Visualization choices';
lines{end+1,1} = '- number of curves: 4 in the dominant-mode fit figure, 3 in residuals, 1 in beta(T), 1 in tau(T), and up to 4 representative temperature slices';
lines{end+1,1} = '- legend vs colormap: legends for all figures because each panel shows 6 or fewer curves';
lines{end+1,1} = '- colormap used: default MATLAB line colors';
lines{end+1,1} = '- smoothing applied: none in this diagnostic; fits operate on the loaded DeltaM map and optional S map as provided';
lines{end+1,1} = '- justification: direct overlays make model comparison and temperature trends easiest to audit quantitatively';
reportText = strjoin(lines, newline);
end
function [mapPath, found] = resolveLatestExistingMap(repoRoot, kind)
found = false; mapPath = '';
runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
if exist(runsRoot, 'dir') ~= 7, return; end
runDirs = dir(fullfile(runsRoot, 'run_*')); runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs), return; end
names = string({runDirs.name});
runDirs = runDirs(~startsWith(names, "run_legacy", 'IgnoreCase', true));
if isempty(runDirs), return; end
[~, order] = sort({runDirs.name}); runDirs = runDirs(order);
if strcmpi(kind, 'dM')
    preferred = {'map_dM_raw.csv', 'map_dM_sg_100md.csv', 'map_dM_sg_200md.csv', 'map_dM_gauss2d.csv'};
else
    preferred = {'map_S_raw.csv', 'map_S_sg_100md.csv', 'map_S_sg_200md.csv', 'map_S_gauss2d.csv'};
end
subdirs = {'tables', 'csv', 'derivative_smoothing', ''};
for i = numel(runDirs):-1:1
    runRoot = fullfile(runDirs(i).folder, runDirs(i).name);
    for s = 1:numel(subdirs)
        for p = 1:numel(preferred)
            if strlength(subdirs{s}) == 0
                candidate = fullfile(runRoot, preferred{p});
            else
                candidate = fullfile(runRoot, subdirs{s}, preferred{p});
            end
            if exist(candidate, 'file') == 2
                mapPath = candidate; found = true; return;
            end
        end
    end
end
end

function [Z, T, xGrid] = loadMapMatrix(mapPath)
raw = readmatrix(mapPath);
if isempty(raw) || size(raw, 1) < 2 || size(raw, 2) < 2
    error('Map file is empty or malformed: %s', mapPath);
end
xGrid = raw(1, 2:end); T = raw(2:end, 1); Z = raw(2:end, 2:end);
validRows = isfinite(T); validCols = isfinite(xGrid);
T = T(validRows); xGrid = xGrid(validCols); Z = Z(validRows, validCols);
if any(~isfinite(Z), 'all'), Z = fillMissingMap(Z); end
if any(~isfinite(Z), 'all'), error('Map still contains non-finite values after filling: %s', mapPath); end
end

function Z = fillMissingMap(Z)
for r = 1:size(Z, 1), Z(r, :) = fillMissingRow(Z(r, :)); end
for c = 1:size(Z, 2), Z(:, c) = fillMissingRow(Z(:, c)')'; end
if any(~isfinite(Z), 'all')
    rowMeans = mean(Z, 2, 'omitnan');
    for r = 1:size(Z, 1)
        miss = ~isfinite(Z(r, :));
        if any(miss)
            if isfinite(rowMeans(r)), Z(r, miss) = rowMeans(r); else, Z(r, miss) = 0; end
        end
    end
end
end

function row = fillMissingRow(row)
if all(isfinite(row)), return; end
x = 1:numel(row); good = isfinite(row);
if ~any(good), row(:) = 0; return; end
if nnz(good) == 1, row(~good) = row(good); return; end
row(~good) = interp1(x(good), row(good), x(~good), 'linear', 'extrap');
end

function SMap = alignOrDeriveSMap(dMMap, T, xGrid, SMapCandidate, ST, SX)
if isequal(size(dMMap), size(SMapCandidate)) && sameGrid(T, ST) && sameGrid(xGrid, SX)
    SMap = SMapCandidate;
else
    SMap = deriveSMapFromDeltaM(dMMap, xGrid);
end
end

function tf = sameGrid(a, b)
a = a(:); b = b(:);
tf = isequal(size(a), size(b)) && all(abs(a - b) <= 1e-9);
end

function SMap = deriveSMapFromDeltaM(dMMap, xGrid)
SMap = nan(size(dMMap));
for i = 1:size(dMMap, 1)
    SMap(i, :) = -gradient(dMMap(i, :), xGrid);
end
end

function [U, V] = orientFirstMode(U, V)
v1 = V(:, 1); nHead = max(1, min(5, floor(numel(v1) / 5)));
if mean(v1(1:nHead), 'omitnan') < mean(v1(end-nHead+1:end), 'omitnan')
    U(:, 1) = -U(:, 1); V(:, 1) = -V(:, 1);
end
end

function idx = selectBestFitIndex(fitRows)
finiteAIC = isfinite(fitRows.AIC);
if any(finiteAIC)
    candidates = find(finiteAIC);
    [~, rel] = min(fitRows.AIC(candidates)); idx = candidates(rel); return;
end
[~, idx] = max(fitRows.R2);
end

function idx = chooseRepresentativeTemperatures(T, nSelect)
if numel(T) <= nSelect, idx = 1:numel(T); return; end
targets = round(linspace(1, numel(T), nSelect)); idx = unique(targets, 'stable');
while numel(idx) < nSelect, idx(end+1) = idx(end) + 1; end
idx = idx(1:nSelect);
end

function slope = earlySlopeFromSignal(y, xGrid)
y = y(:); xGrid = xGrid(:); n = min(5, numel(y));
if n < 3, slope = NaN; return; end
p = polyfit(xGrid(1:n), y(1:n), 1); slope = -p(1);
end

function tHalf = computeHalfTime(t, yFit)
t = t(:); yFit = yFit(:);
ok = isfinite(t) & isfinite(yFit); t = t(ok); yFit = yFit(ok);
if numel(t) < 3, tHalf = NaN; return; end
y0 = yFit(1); yf = yFit(end); signRef = sign(y0 - yf);
if signRef == 0, tHalf = NaN; return; end
halfValue = yf + 0.5 * (y0 - yf); f = signRef * (yFit - halfValue);
idx = find(f(1:end-1) >= 0 & f(2:end) <= 0, 1, 'first');
if isempty(idx), idx = find(f(1:end-1) <= 0 & f(2:end) >= 0, 1, 'first'); end
if isempty(idx), tHalf = NaN; return; end
tHalf = interpCross(t(idx), t(idx+1), f(idx), f(idx+1));
end

function x0 = interpCross(x1, x2, y1, y2)
if ~all(isfinite([x1, x2])) || ~all(isfinite([y1, y2])) || y1 == y2
    x0 = mean([x1, x2], 'omitnan'); return;
end
x0 = x1 + (0 - y1) * (x2 - x1) / (y2 - y1);
end

function rmse = computeRMSE(y, yFit)
ok = isfinite(y) & isfinite(yFit);
if ~any(ok), rmse = NaN; return; end
rmse = sqrt(mean((y(ok) - yFit(ok)) .^ 2));
end

function R2 = computeR2(y, yFit)
ok = isfinite(y) & isfinite(yFit); y = y(ok); yFit = yFit(ok);
if isempty(y), R2 = NaN; return; end
ssRes = sum((y - yFit) .^ 2); ssTot = sum((y - mean(y, 'omitnan')) .^ 2);
if ssTot <= 0, R2 = 1; else, R2 = 1 - ssRes / ssTot; end
end

function aic = computeAIC(y, yFit, k)
ok = isfinite(y) & isfinite(yFit); y = y(ok); yFit = yFit(ok); n = numel(y);
if n == 0, aic = NaN; return; end
sse = max(sum((y - yFit) .^ 2), eps); aic = n * log(sse / n) + 2 * k;
end

function out = stripExtension(p)
[~, name, ~] = fileparts(char(string(p))); out = name;
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0, return; end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function v = setDef(s, f, d)
if ~isfield(s, f), s.(f) = d; end
v = s;
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function value = emptyAsDerived(strValue)
if strlength(strValue) == 0, value = "derived from DeltaM"; else, value = strValue; end
end
