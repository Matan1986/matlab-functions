function out = ax_functional_relation_analysis(cfg)
% ax_functional_relation_analysis
% Compare empirical functional forms linking relaxation activity A(T) to
% X(T) = I_peak(T) / (width(T) * S_peak(T)) using saved run outputs only.

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
runCfg.dataset = sprintf('relax:%s | switch:%s', char(source.relaxRunName), char(source.switchRunName));
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

fprintf('AX functional relation run directory:\n%s\n', runDir);
fprintf('Relaxation source run: %s\n', source.relaxRunName);
fprintf('Switching source run: %s\n', source.switchRunName);

appendText(run.log_path, sprintf('[%s] AX functional relation analysis started\n', stampNow()));
appendText(run.log_path, sprintf('Relaxation source: %s\n', char(source.relaxRunName)));
appendText(run.log_path, sprintf('Switching source: %s\n', char(source.switchRunName)));

relax = loadRelaxationData(source.relaxRunDir);
switching = loadSwitchingData(source.switchRunDir, cfg);
aligned = buildAlignedData(relax, switching, cfg);

[familyTbl, modelTbl, parameterTbl, bestCurveTbl, bestFamily, fits] = fitAllModels(aligned, cfg);
[loocvDetailTbl, loocvSummaryTbl] = runLeaveOneOut(aligned, cfg);
[bootstrapDetailTbl, bootstrapSummaryTbl] = runBootstrap(aligned, cfg);
manifestTbl = buildSourceManifestTable(source, cfg);

alignedPath = save_run_table(aligned.table, 'AX_aligned_data.csv', runDir);
familyPath = save_run_table(familyTbl, 'AX_family_comparison.csv', runDir);
modelPath = save_run_table(modelTbl, 'AX_model_comparison.csv', runDir);
paramPath = save_run_table(parameterTbl, 'AX_parameter_estimates.csv', runDir);
curvePath = save_run_table(bestCurveTbl, 'AX_best_fit_curve.csv', runDir);
loocvDetailPath = save_run_table(loocvDetailTbl, 'AX_loocv_family_rankings.csv', runDir);
loocvSummaryPath = save_run_table(loocvSummaryTbl, 'AX_loocv_family_summary.csv', runDir);
bootstrapDetailPath = save_run_table(bootstrapDetailTbl, 'AX_bootstrap_family_rankings.csv', runDir);
bootstrapSummaryPath = save_run_table(bootstrapSummaryTbl, 'AX_bootstrap_family_summary.csv', runDir);
manifestPath = save_run_table(manifestTbl, 'source_run_manifest.csv', runDir);

fig1 = saveTemperatureFigure(aligned, runDir, 'AX_figure_1_A_and_X_vs_temperature');
fig2 = saveScatterFigure(aligned.X, aligned.A, aligned.T_K, ...
    'Composite observable X(T)', 'Relaxation activity A(T)', ...
    'A(T) vs X(T)', runDir, 'AX_figure_2_A_vs_X');
lnx1 = linspace(min(aligned.X), max(aligned.X), 250);
fig3 = saveScatterWithLine(aligned.X, aligned.lnA, aligned.T_K, ...
    'Composite observable X(T)', 'ln(A(T))', ...
    'ln(A(T)) vs X(T)', runDir, 'AX_figure_3_lnA_vs_X', ...
    lnx1, log(predictExponential(fits.exponential.params, lnx1)));
lnx2 = linspace(min(aligned.lnX), max(aligned.lnX), 250);
fig4 = saveScatterWithLine(aligned.lnX, aligned.lnA, aligned.T_K, ...
    'ln(X(T))', 'ln(A(T))', ...
    'ln(A(T)) vs ln(X(T))', runDir, 'AX_figure_4_lnA_vs_lnX', ...
    lnx2, fits.power_law.params(1) + fits.power_law.params(2) .* lnx2);
fig5 = saveBestFitFigure(aligned, bestFamily, runDir, 'AX_figure_5_best_fit_model');
fig6 = saveResidualFigure(aligned, bestFamily, runDir, 'AX_figure_6_residuals_vs_temperature');

reportText = buildReportText(source, aligned, familyTbl, modelTbl, parameterTbl, ...
    loocvSummaryTbl, bootstrapSummaryTbl, bestFamily, cfg);
reportPath = save_run_report(reportText, 'AX_functional_relation_analysis.md', runDir);
zipPath = buildReviewZip(runDir, 'AX_functional_relation_analysis_bundle.zip');

bestModel = pickBestModel(modelTbl);
appendText(run.notes_path, sprintf('Best-supported model: %s\n', char(bestModel.display_name(1))));
appendText(run.notes_path, sprintf('Best family: %s\n', char(bestFamily.family_label)));
appendText(run.notes_path, sprintf('A(T) peak on aligned grid: %.1f K\n', findPeakT(aligned.T_K, aligned.A)));
appendText(run.notes_path, sprintf('X(T) peak on aligned grid: %.1f K\n', findPeakT(aligned.T_K, aligned.X)));
appendText(run.notes_path, sprintf('Interpolation: %s\n', cfg.interpMethod));

appendText(run.log_path, sprintf('[%s] AX functional relation analysis complete\n', stampNow()));
appendText(run.log_path, sprintf('Aligned table: %s\n', alignedPath));
appendText(run.log_path, sprintf('Family table: %s\n', familyPath));
appendText(run.log_path, sprintf('Model table: %s\n', modelPath));
appendText(run.log_path, sprintf('Parameter table: %s\n', paramPath));
appendText(run.log_path, sprintf('Best-fit curve: %s\n', curvePath));
appendText(run.log_path, sprintf('LOOCV detail: %s\n', loocvDetailPath));
appendText(run.log_path, sprintf('LOOCV summary: %s\n', loocvSummaryPath));
appendText(run.log_path, sprintf('Bootstrap detail: %s\n', bootstrapDetailPath));
appendText(run.log_path, sprintf('Bootstrap summary: %s\n', bootstrapSummaryPath));
appendText(run.log_path, sprintf('Manifest: %s\n', manifestPath));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.aligned = aligned;
out.familyComparison = familyTbl;
out.modelComparison = modelTbl;
out.parameterEstimates = parameterTbl;
out.bestFamily = bestFamily;
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== AX functional relation analysis complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Best-supported model: %s\n', char(bestModel.display_name(1)));
fprintf('Best family: %s\n', char(bestFamily.family_label));
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'AX_functional_relation_analysis');
cfg = setDefaultField(cfg, 'relaxRunName', 'run_2026_03_10_175048_relaxation_observable_stability_audit');
cfg = setDefaultField(cfg, 'switchRunName', 'run_2026_03_13_112155_switching_geometry_diagnostics');
cfg = setDefaultField(cfg, 'interpMethod', 'pchip');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'bootstrapCount', 500);
cfg = setDefaultField(cfg, 'randomSeed', 20260313);
cfg = setDefaultField(cfg, 'maxIter', 5000);
cfg = setDefaultField(cfg, 'maxFunEvals', 5000);
cfg = setDefaultField(cfg, 'deltaCriterion', 2.0);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.relaxRunName = string(cfg.relaxRunName);
source.switchRunName = string(cfg.switchRunName);
source.relaxRunDir = fullfile(repoRoot, 'results', 'relaxation', 'runs', char(source.relaxRunName));
source.switchRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.switchRunName));
source.relaxPath = fullfile(char(source.relaxRunDir), 'tables', 'temperature_observables.csv');
source.switchPath = fullfile(char(source.switchRunDir), 'tables', 'switching_geometry_observables.csv');

required = {
    source.relaxRunDir, source.relaxPath;
    source.switchRunDir, source.switchPath
    };
for i = 1:size(required, 1)
    if exist(required{i, 1}, 'dir') ~= 7
        error('Required source run directory not found: %s', required{i, 1});
    end
    if exist(required{i, 2}, 'file') ~= 2
        error('Required source file not found: %s', required{i, 2});
    end
end
end

function relax = loadRelaxationData(runDir)
tbl = readtable(fullfile(runDir, 'tables', 'temperature_observables.csv'));
tbl = sortrows(tbl, 'T');
relax = struct();
relax.T = tbl.T(:);
relax.A = tbl.A_T(:);
end

function switching = loadSwitchingData(runDir, cfg)
tbl = readtable(fullfile(runDir, 'tables', 'switching_geometry_observables.csv'));
mask = tbl.T_K >= cfg.temperatureMinK & tbl.T_K <= cfg.temperatureMaxK;
mask = mask & isfinite(tbl.I_peak_mA) & isfinite(tbl.width_mA) & isfinite(tbl.S_peak);
tbl = sortrows(tbl(mask, :), 'T_K');
switching = struct();
switching.T = tbl.T_K(:);
switching.I_peak = tbl.I_peak_mA(:);
switching.width = tbl.width_mA(:);
switching.S_peak = tbl.S_peak(:);
end

function aligned = buildAlignedData(relax, switching, cfg)
T = switching.T(:);
A = interp1(relax.T, relax.A, T, cfg.interpMethod, NaN);
X = switching.I_peak ./ (switching.width .* switching.S_peak);
mask = isfinite(T) & isfinite(A) & isfinite(X) & A > 0 & X > 0;
if nnz(mask) < 5
    error('Too few valid points remain after interpolation.');
end

aligned = struct();
aligned.T_K = T(mask);
aligned.A = A(mask);
aligned.X = X(mask);
aligned.lnA = log(aligned.A);
aligned.lnX = log(aligned.X);
aligned.I_peak_mA = switching.I_peak(mask);
aligned.width_mA = switching.width(mask);
aligned.S_peak = switching.S_peak(mask);
aligned.A_norm = normalize01(aligned.A);
aligned.X_norm = normalize01(aligned.X);
aligned.table = table(aligned.T_K, aligned.A, aligned.X, aligned.lnA, aligned.lnX, ...
    aligned.I_peak_mA, aligned.width_mA, aligned.S_peak, aligned.A_norm, aligned.X_norm, ...
    'VariableNames', {'T_K','A_interp','X','ln_A','ln_X','I_peak_mA','width_mA','S_peak','A_norm','X_norm'});
end

function [familyTbl, modelTbl, parameterTbl, bestCurveTbl, bestFamily, fits] = fitAllModels(aligned, cfg)
x = aligned.X(:);
y = aligned.A(:);
fits = fitFamilies(x, y, cfg);
familyTbl = buildFamilyTable(fits, cfg);
modelTbl = buildModelTable(fits, cfg);
parameterTbl = buildParameterTable(fits);
bestModel = pickBestModel(modelTbl);
bestFamily = fits.(char(bestModel.family_key(1)));
bestCurveTbl = table(aligned.T_K, aligned.X, aligned.A, bestFamily.yhat, bestFamily.residuals, ...
    'VariableNames', {'T_K','X','A_data','A_fit','residual'});
bestCurveTbl = sortrows(bestCurveTbl, 'X');
end

function fits = fitFamilies(x, y, cfg)
fits = struct();

p1 = polyfit(x, y, 1);
fits.linear = makeFit('linear', 'Linear', 'A = a X + b', 2, p1(:).', predictLinear(p1, x), y);

linExp = polyfit(x, log(y), 1);
qExp = optimizeModel(@(q, xdata) predictExponential(q, xdata), y, x, ...
    [linExp(2), linExp(1); linExp(2) + log(0.9), linExp(1); linExp(2), 1.1 * linExp(1)], cfg);
fits.exponential = makeFit('exponential', 'Exponential', 'A = exp(b) exp(a X)', 2, qExp, predictExponential(qExp, x), y);

linPow = polyfit(log(x), log(y), 1);
qPow = optimizeModel(@(q, xdata) predictPowerLaw(q, xdata), y, x, ...
    [linPow(2), linPow(1); linPow(2) + log(0.9), linPow(1); linPow(2), 1.1 * linPow(1)], cfg);
fits.power_law = makeFit('power_law', 'Power law', 'A = exp(b) X^a', 2, qPow, predictPowerLaw(qPow, x), y);

minY = min(y);
qExp0 = fits.exponential.params;
qExpOff = optimizeModel(@(q, xdata) predictExponentialOffset(q, xdata), y, x, ...
    [qExp0(1), qExp0(2), 0; qExp0(1), qExp0(2), 0.1 * minY; qExp0(1), qExp0(2), -0.1 * minY], cfg);
fits.exponential_offset = makeFit('exponential_offset', 'Exponential with offset', 'A = a exp(b X) + c', 3, qExpOff, predictExponentialOffset(qExpOff, x), y);

minX = min(x);
dx = max(1e-6, 0.1 * (max(x) - min(x)));
qPow0 = fits.power_law.params;
rawOffPow = optimizeModel(@(q, xdata) predictOffsetPowerLawRaw(q, xdata, minX), y, x, ...
    [qPow0(1), qPow0(2), log(dx); qPow0(1), 0.9 * qPow0(2), log(dx); qPow0(1), 1.1 * qPow0(2), log(dx)], cfg);
qOffPow = [rawOffPow(1), rawOffPow(2), minX - exp(rawOffPow(3))];
fits.offset_power_law = makeFit('offset_power_law', 'Offset power law', 'A = a (X - X_0)^b', 3, qOffPow, predictOffsetPowerLaw(qOffPow, x), y);
end

function fit = makeFit(key, label, formula, k, params, yhat, y)
fit = struct();
fit.family_key = string(key);
fit.family_label = string(label);
fit.formula = string(formula);
fit.k = k;
fit.params = params(:).';
fit.yhat = yhat(:);
fit.residuals = y(:) - fit.yhat(:);
fit.sse = sum(fit.residuals .^ 2);
fit.r_squared = computeR2(y, fit.yhat);
fit.rmse = sqrt(fit.sse / numel(y));
fit.aic = computeAIC(fit.sse, numel(y), k);
fit.bic = computeBIC(fit.sse, numel(y), k);
end

function bestQ = optimizeModel(modelFun, y, x, initList, cfg)
opts = optimset('Display', 'off', 'MaxIter', cfg.maxIter, 'MaxFunEvals', cfg.maxFunEvals, 'TolX', 1e-9, 'TolFun', 1e-12);
objective = @(q) computeSSE(y, modelFun(q, x));
bestVal = inf;
bestQ = initList(1, :);
for i = 1:size(initList, 1)
    q0 = initList(i, :);
    try
        [qTry, valTry] = fminsearch(objective, q0, opts);
    catch
        qTry = q0;
        valTry = objective(q0);
    end
    if isfinite(valTry) && valTry < bestVal
        bestVal = valTry;
        bestQ = qTry;
    end
end
end
function familyTbl = buildFamilyTable(fits, cfg)
fitList = {fits.linear, fits.exponential, fits.power_law, fits.exponential_offset, fits.offset_power_law};
fitList = [fitList{:}];
family_key = strings(numel(fitList), 1);
family_label = strings(numel(fitList), 1);
formula = strings(numel(fitList), 1);
k = NaN(numel(fitList), 1);
r_squared = NaN(numel(fitList), 1);
rmse = NaN(numel(fitList), 1);
aic = NaN(numel(fitList), 1);
bic = NaN(numel(fitList), 1);
for i = 1:numel(fitList)
    family_key(i) = fitList(i).family_key;
    family_label(i) = fitList(i).family_label;
    formula(i) = fitList(i).formula;
    k(i) = fitList(i).k;
    r_squared(i) = fitList(i).r_squared;
    rmse(i) = fitList(i).rmse;
    aic(i) = fitList(i).aic;
    bic(i) = fitList(i).bic;
end
familyTbl = table(family_key, family_label, formula, k, r_squared, rmse, aic, bic);
familyTbl.aic_rank = competitionRank(familyTbl.aic);
familyTbl.bic_rank = competitionRank(familyTbl.bic);
familyTbl.delta_aic = familyTbl.aic - min(familyTbl.aic);
familyTbl.delta_bic = familyTbl.bic - min(familyTbl.bic);
familyTbl.indistinguishable_aic = familyTbl.delta_aic <= cfg.deltaCriterion;
familyTbl.indistinguishable_bic = familyTbl.delta_bic <= cfg.deltaCriterion;
familyTbl = sortrows(familyTbl, {'aic_rank','bic_rank','rmse'});
end

function modelTbl = buildModelTable(fits, cfg)
rows = [
    modelRow(1, 'MODEL 1: A = a X + b', 'linear', fits.linear.k, fits.linear.r_squared, fits.linear.rmse, fits.linear.aic, fits.linear.bic, fits.linear.params(1), fits.linear.params(2), NaN, NaN, '');
    modelRow(2, 'MODEL 2: ln(A) = a X + b', 'exponential', fits.exponential.k, fits.exponential.r_squared, fits.exponential.rmse, fits.exponential.aic, fits.exponential.bic, fits.exponential.params(2), fits.exponential.params(1), NaN, NaN, 'Equivalent to MODEL 5 on the A scale.');
    modelRow(3, 'MODEL 3: ln(A) = a ln(X) + b', 'power_law', fits.power_law.k, fits.power_law.r_squared, fits.power_law.rmse, fits.power_law.aic, fits.power_law.bic, fits.power_law.params(2), fits.power_law.params(1), NaN, NaN, 'Equivalent to MODEL 4 on the A scale.');
    modelRow(4, 'MODEL 4: A = a X^b', 'power_law', fits.power_law.k, fits.power_law.r_squared, fits.power_law.rmse, fits.power_law.aic, fits.power_law.bic, exp(fits.power_law.params(1)), fits.power_law.params(2), NaN, NaN, 'Equivalent to MODEL 3 on the A scale.');
    modelRow(5, 'MODEL 5: A = a exp(b X)', 'exponential', fits.exponential.k, fits.exponential.r_squared, fits.exponential.rmse, fits.exponential.aic, fits.exponential.bic, exp(fits.exponential.params(1)), fits.exponential.params(2), NaN, NaN, 'Equivalent to MODEL 2 on the A scale.');
    modelRow(6, 'MODEL 6: A = a exp(b X) + c', 'exponential_offset', fits.exponential_offset.k, fits.exponential_offset.r_squared, fits.exponential_offset.rmse, fits.exponential_offset.aic, fits.exponential_offset.bic, exp(fits.exponential_offset.params(1)), fits.exponential_offset.params(2), fits.exponential_offset.params(3), NaN, '');
    modelRow(7, 'MODEL 7: A = a (X - X_0)^b', 'offset_power_law', fits.offset_power_law.k, fits.offset_power_law.r_squared, fits.offset_power_law.rmse, fits.offset_power_law.aic, fits.offset_power_law.bic, exp(fits.offset_power_law.params(1)), fits.offset_power_law.params(2), NaN, fits.offset_power_law.params(3), '')
    ];
modelTbl = struct2table(rows);
modelTbl.aic_rank = competitionRank(modelTbl.aic);
modelTbl.bic_rank = competitionRank(modelTbl.bic);
modelTbl.delta_aic = modelTbl.aic - min(modelTbl.aic);
modelTbl.delta_bic = modelTbl.bic - min(modelTbl.bic);
modelTbl.indistinguishable_aic = modelTbl.delta_aic <= cfg.deltaCriterion;
modelTbl.indistinguishable_bic = modelTbl.delta_bic <= cfg.deltaCriterion;
modelTbl = sortrows(modelTbl, {'aic_rank','bic_rank','rmse','model_number'});
end

function row = modelRow(modelNumber, displayName, familyKey, k, r2, rmse, aic, bic, a, b, c, x0, note)
row = struct();
row.model_number = modelNumber;
row.display_name = string(displayName);
row.family_key = string(familyKey);
row.k = k;
row.r_squared = r2;
row.rmse = rmse;
row.aic = aic;
row.bic = bic;
row.param_a = a;
row.param_b = b;
row.param_c = c;
row.param_X0 = x0;
row.note = string(note);
end

function parameterTbl = buildParameterTable(fits)
model_number = [1;1;2;2;3;3;4;4;5;5;6;6;6;7;7;7];
model_label = [ ...
    "MODEL 1";"MODEL 1";"MODEL 2";"MODEL 2";"MODEL 3";"MODEL 3"; ...
    "MODEL 4";"MODEL 4";"MODEL 5";"MODEL 5";"MODEL 6";"MODEL 6";"MODEL 6"; ...
    "MODEL 7";"MODEL 7";"MODEL 7"];
parameter_name = [ ...
    "a";"b";"a";"b";"a";"b";"a";"b";"a";"b";"a";"b";"c";"a";"b";"X_0"];
parameter_value = [ ...
    fits.linear.params(1); fits.linear.params(2); ...
    fits.exponential.params(2); fits.exponential.params(1); ...
    fits.power_law.params(2); fits.power_law.params(1); ...
    exp(fits.power_law.params(1)); fits.power_law.params(2); ...
    exp(fits.exponential.params(1)); fits.exponential.params(2); ...
    exp(fits.exponential_offset.params(1)); fits.exponential_offset.params(2); fits.exponential_offset.params(3); ...
    exp(fits.offset_power_law.params(1)); fits.offset_power_law.params(2); fits.offset_power_law.params(3)];
parameterTbl = table(model_number, model_label, parameter_name, parameter_value);
end

function [detailTbl, summaryTbl] = runLeaveOneOut(aligned, cfg)
n = numel(aligned.A);
rows = repmat(struct('split_id', NaN, 'omitted_T_K', NaN, 'family_key', "", 'family_label', "", ...
    'aic', NaN, 'bic', NaN, 'rmse_train', NaN, 'r_squared_train', NaN, ...
    'abs_error_test', NaN, 'sq_error_test', NaN, 'aic_rank', NaN, 'bic_rank', NaN), 0, 1);
for i = 1:n
    keep = true(n, 1);
    keep(i) = false;
    fits = fitFamilies(aligned.X(keep), aligned.A(keep), cfg);
    fitList = {fits.linear, fits.exponential, fits.power_law, fits.exponential_offset, fits.offset_power_law};
    fitList = [fitList{:}];
    aicVals = arrayfun(@(s) s.aic, fitList);
    bicVals = arrayfun(@(s) s.bic, fitList);
    aRank = competitionRank(aicVals);
    bRank = competitionRank(bicVals);
    for j = 1:numel(fitList)
        yhat = predictFamily(fitList(j), aligned.X(i));
        rows(end + 1) = struct( ... %#ok<AGROW>
            'split_id', i, ...
            'omitted_T_K', aligned.T_K(i), ...
            'family_key', fitList(j).family_key, ...
            'family_label', fitList(j).family_label, ...
            'aic', fitList(j).aic, ...
            'bic', fitList(j).bic, ...
            'rmse_train', fitList(j).rmse, ...
            'r_squared_train', fitList(j).r_squared, ...
            'abs_error_test', abs(aligned.A(i) - yhat), ...
            'sq_error_test', (aligned.A(i) - yhat).^2, ...
            'aic_rank', aRank(j), ...
            'bic_rank', bRank(j));
    end
end
detailTbl = struct2table(rows);
summaryTbl = summarizeRobustness(detailTbl, true);
end

function [detailTbl, summaryTbl] = runBootstrap(aligned, cfg)
rng(cfg.randomSeed, 'twister');
n = numel(aligned.A);
rows = repmat(struct('replicate_id', NaN, 'family_key', "", 'family_label', "", ...
    'aic', NaN, 'bic', NaN, 'rmse', NaN, 'r_squared', NaN, ...
    'aic_rank', NaN, 'bic_rank', NaN), 0, 1);
for i = 1:cfg.bootstrapCount
    idx = randi(n, n, 1);
    fits = fitFamilies(aligned.X(idx), aligned.A(idx), cfg);
    fitList = {fits.linear, fits.exponential, fits.power_law, fits.exponential_offset, fits.offset_power_law};
    fitList = [fitList{:}];
    aicVals = arrayfun(@(s) s.aic, fitList);
    bicVals = arrayfun(@(s) s.bic, fitList);
    aRank = competitionRank(aicVals);
    bRank = competitionRank(bicVals);
    for j = 1:numel(fitList)
        rows(end + 1) = struct( ... %#ok<AGROW>
            'replicate_id', i, ...
            'family_key', fitList(j).family_key, ...
            'family_label', fitList(j).family_label, ...
            'aic', fitList(j).aic, ...
            'bic', fitList(j).bic, ...
            'rmse', fitList(j).rmse, ...
            'r_squared', fitList(j).r_squared, ...
            'aic_rank', aRank(j), ...
            'bic_rank', bRank(j));
    end
end
detailTbl = struct2table(rows);
summaryTbl = summarizeRobustness(detailTbl, false);
end

function summaryTbl = summarizeRobustness(detailTbl, hasTestError)
keys = unique(detailTbl.family_key, 'stable');
rows = repmat(struct('family_key', "", 'family_label', "", 'n_cases', NaN, ...
    'aic_win_count', NaN, 'bic_win_count', NaN, 'aic_win_fraction', NaN, 'bic_win_fraction', NaN, ...
    'mean_aic_rank', NaN, 'mean_bic_rank', NaN, 'mean_rmse', NaN, 'mean_r_squared', NaN, ...
    'mean_abs_error_test', NaN, 'rmse_test', NaN), numel(keys), 1);
for i = 1:numel(keys)
    mask = detailTbl.family_key == keys(i);
    subset = detailTbl(mask, :);
    rows(i).family_key = keys(i);
    rows(i).family_label = subset.family_label(1);
    rows(i).n_cases = height(subset);
    rows(i).aic_win_count = nnz(subset.aic_rank == 1);
    rows(i).bic_win_count = nnz(subset.bic_rank == 1);
    rows(i).aic_win_fraction = rows(i).aic_win_count / max(1, rows(i).n_cases);
    rows(i).bic_win_fraction = rows(i).bic_win_count / max(1, rows(i).n_cases);
    rows(i).mean_aic_rank = mean(subset.aic_rank, 'omitnan');
    rows(i).mean_bic_rank = mean(subset.bic_rank, 'omitnan');
    if ismember('rmse', subset.Properties.VariableNames)
        rows(i).mean_rmse = mean(subset.rmse, 'omitnan');
        rows(i).mean_r_squared = mean(subset.r_squared, 'omitnan');
    else
        rows(i).mean_rmse = mean(subset.rmse_train, 'omitnan');
        rows(i).mean_r_squared = mean(subset.r_squared_train, 'omitnan');
    end
    if hasTestError
        rows(i).mean_abs_error_test = mean(subset.abs_error_test, 'omitnan');
        rows(i).rmse_test = sqrt(mean(subset.sq_error_test, 'omitnan'));
    else
        rows(i).mean_abs_error_test = NaN;
        rows(i).rmse_test = NaN;
    end
end
summaryTbl = struct2table(rows);
summaryTbl = sortrows(summaryTbl, {'mean_aic_rank','mean_bic_rank','mean_rmse'});
end

function manifestTbl = buildSourceManifestTable(source, cfg)
manifestTbl = table( ...
    ["relaxation"; "switching"], ...
    [source.relaxRunName; source.switchRunName], ...
    [string(source.relaxPath); string(source.switchPath)], ...
    ["A(T) source"; "I_peak(T), width(T), S_peak(T) source"], ...
    repmat(string(cfg.interpMethod), 2, 1), ...
    'VariableNames', {'experiment','source_run','source_file','role','interp_method'});
end
function figPaths = saveTemperatureFigure(aligned, runDir, figureName)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 17.8 10.2]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl, 1);
plot(ax1, aligned.T_K, aligned.A, '-o', 'Color', [0.78 0.21 0.10], 'MarkerFaceColor', [0.78 0.21 0.10], 'LineWidth', 2, 'MarkerSize', 5);
xline(ax1, findPeakT(aligned.T_K, aligned.A), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1);
ylabel(ax1, 'A(T)');
title(ax1, 'A(T) and X(T) vs temperature');
styleAxes(ax1);
ax2 = nexttile(tl, 2);
plot(ax2, aligned.T_K, aligned.X, '-s', 'Color', [0.00 0.45 0.74], 'MarkerFaceColor', [0.00 0.45 0.74], 'LineWidth', 2, 'MarkerSize', 5);
xline(ax2, findPeakT(aligned.T_K, aligned.X), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1);
xlabel(ax2, 'Temperature (K)');
ylabel(ax2, 'X(T)');
styleAxes(ax2);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveScatterFigure(x, y, T, xLabel, yLabel, titleText, runDir, figureName)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
scatter(ax, x, y, 56, T, 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.6);
xlabel(ax, xLabel);
ylabel(ax, yLabel);
title(ax, titleText);
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
colormap(ax, parula(256));
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveScatterWithLine(x, y, T, xLabel, yLabel, titleText, runDir, figureName, xLine, yLine)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
scatter(ax, x, y, 56, T, 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.6);
hold(ax, 'on');
plot(ax, xLine, yLine, '-', 'Color', [0 0 0], 'LineWidth', 1.8);
hold(ax, 'off');
xlabel(ax, xLabel);
ylabel(ax, yLabel);
title(ax, titleText);
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
colormap(ax, parula(256));
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveBestFitFigure(aligned, bestFamily, runDir, figureName)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
scatter(ax, aligned.X, aligned.A, 58, aligned.T_K, 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.6);
hold(ax, 'on');
xFit = linspace(min(aligned.X), max(aligned.X), 300);
plot(ax, xFit, predictFamily(bestFamily, xFit), '-', 'Color', [0 0 0], 'LineWidth', 2);
hold(ax, 'off');
xlabel(ax, 'Composite observable X(T)');
ylabel(ax, 'Relaxation activity A(T)');
title(ax, sprintf('Best-fit family: %s', char(bestFamily.family_label)));
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
colormap(ax, parula(256));
text(ax, 0.04, 0.96, sprintf('%s\nR^2 = %.3f\nRMSE = %.3g', char(bestFamily.family_label), bestFamily.r_squared, bestFamily.rmse), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1], 'Margin', 4, 'FontSize', 8);
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function figPaths = saveResidualFigure(aligned, bestFamily, runDir, figureName)
fig = create_figure('Visible', 'off');
set(fig, 'Position', [2 2 8.6 6.6]);
ax = axes(fig);
scatter(ax, aligned.T_K, bestFamily.residuals, 58, aligned.T_K, 'filled', 'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.6);
hold(ax, 'on');
yline(ax, 0, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.2);
hold(ax, 'off');
xlabel(ax, 'Temperature (K)');
ylabel(ax, 'Residual A_{data} - A_{fit}');
title(ax, sprintf('Residuals vs temperature: %s', char(bestFamily.family_label)));
cb = colorbar(ax);
cb.Label.String = 'Temperature (K)';
colormap(ax, parula(256));
styleAxes(ax);
figPaths = save_run_figure(fig, figureName, runDir);
close(fig);
end

function reportText = buildReportText(source, aligned, familyTbl, modelTbl, parameterTbl, loocvSummaryTbl, bootstrapSummaryTbl, bestFamily, cfg)
bestModel = pickBestModel(modelTbl);
peakA = findPeakT(aligned.T_K, aligned.A);
peakX = findPeakT(aligned.T_K, aligned.X);
bestAIC = joinQuoted(modelTbl.display_name(modelTbl.indistinguishable_aic));
bestBIC = joinQuoted(modelTbl.display_name(modelTbl.indistinguishable_bic));
loocvWinner = loocvSummaryTbl(1, :);
bootstrapWinner = bootstrapSummaryTbl(1, :);

lines = strings(0, 1);
lines(end + 1) = '# AX functional relation analysis';
lines(end + 1) = '';
lines(end + 1) = '## Inputs and construction';
lines(end + 1) = sprintf('- Relaxation source run: `%s` using `A_T` from `tables/temperature_observables.csv`.', char(source.relaxRunName));
lines(end + 1) = sprintf('- Switching source run: `%s` using `I_peak_mA`, `width_mA`, and `S_peak` from `tables/switching_geometry_observables.csv`.', char(source.switchRunName));
lines(end + 1) = '- Composite observable definition: `X(T) = I_peak(T) / (width(T) * S_peak(T))`.';
lines(end + 1) = sprintf('- Relaxation activity was interpolated onto the switching grid with `%s` interpolation.', cfg.interpMethod);
lines(end + 1) = sprintf('- Aligned temperatures: `%s`.', formatTemperatureList(aligned.T_K));
lines(end + 1) = sprintf('- Number of aligned points: `%d`.', height(aligned.table));
lines(end + 1) = '';
lines(end + 1) = '## Candidate models';
lines(end + 1) = '- MODEL 1: `A = a X + b`';
lines(end + 1) = '- MODEL 2: `ln(A) = a X + b`';
lines(end + 1) = '- MODEL 3: `ln(A) = a ln(X) + b`';
lines(end + 1) = '- MODEL 4: `A = a X^b`';
lines(end + 1) = '- MODEL 5: `A = a exp(b X)`';
lines(end + 1) = '- MODEL 6: `A = a exp(b X) + c`';
lines(end + 1) = '- MODEL 7: `A = a (X - X_0)^b`';
lines(end + 1) = '';
lines(end + 1) = '## Fitting convention';
lines(end + 1) = '- All models were compared on the same `A`-scale least-squares objective so that `R^2`, `RMSE`, `AIC`, and `BIC` are directly comparable across candidate forms.';
lines(end + 1) = '- Under that convention, MODEL 2 and MODEL 5 are algebraically identical on the `A` scale, and MODEL 3 and MODEL 4 are algebraically identical on the `A` scale.';
lines(end + 1) = sprintf('- Models with `delta AIC <= %.1f` or `delta BIC <= %.1f` are treated as empirically indistinguishable under that criterion.', cfg.deltaCriterion, cfg.deltaCriterion);
lines(end + 1) = '';
lines(end + 1) = '## Peak alignment';
lines(end + 1) = sprintf('- On the common grid, `A(T)` peaks at `%.1f K` and `X(T)` peaks at `%.1f K`.', peakA, peakX);
lines(end + 1) = '';
lines(end + 1) = '## Unique functional families';
lines(end + 1) = '| Family | Formula | k | R^2 | RMSE | AIC | BIC |';
lines(end + 1) = '| --- | --- | ---: | ---: | ---: | ---: | ---: |';
for i = 1:height(familyTbl)
    lines(end + 1) = sprintf('| %s | `%s` | %d | %.6f | %.6g | %.6f | %.6f |', ...
        familyTbl.family_label(i), familyTbl.formula(i), familyTbl.k(i), ...
        familyTbl.r_squared(i), familyTbl.rmse(i), familyTbl.aic(i), familyTbl.bic(i));
end
lines(end + 1) = '';
lines(end + 1) = '## Seven-model comparison';
lines(end + 1) = '| Model | Family | a | b | c | X_0 | R^2 | RMSE | AIC | BIC |';
lines(end + 1) = '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |';
for i = 1:height(modelTbl)
    lines(end + 1) = sprintf('| %s | %s | %s | %s | %s | %s | %.6f | %.6g | %.6f | %.6f |', ...
        modelTbl.display_name(i), modelTbl.family_key(i), fmt(modelTbl.param_a(i)), fmt(modelTbl.param_b(i)), ...
        fmt(modelTbl.param_c(i)), fmt(modelTbl.param_X0(i)), modelTbl.r_squared(i), modelTbl.rmse(i), modelTbl.aic(i), modelTbl.bic(i));
end
lines(end + 1) = '';
lines(end + 1) = '## Parameter estimates';
lines(end + 1) = '| Model | Parameter | Value |';
lines(end + 1) = '| --- | --- | ---: |';
for i = 1:height(parameterTbl)
    lines(end + 1) = sprintf('| %s | %s | %s |', parameterTbl.model_label(i), parameterTbl.parameter_name(i), fmt(parameterTbl.parameter_value(i)));
end
lines(end + 1) = '';
lines(end + 1) = '## Best-supported model';
lines(end + 1) = sprintf('- Best-supported model in the joint AIC/BIC sense: `%s`.', char(bestModel.display_name(1)));
lines(end + 1) = sprintf('- Best unique family: `%s` with `R^2 = %.6f`, `RMSE = %.6g`, `AIC = %.6f`, `BIC = %.6f`.', ...
    char(bestFamily.family_label), bestFamily.r_squared, bestFamily.rmse, bestFamily.aic, bestFamily.bic);
lines(end + 1) = sprintf('- Models indistinguishable by AIC: %s.', bestAIC);
lines(end + 1) = sprintf('- Models indistinguishable by BIC: %s.', bestBIC);
lines(end + 1) = '';
lines(end + 1) = '## Robustness checks';
lines(end + 1) = sprintf('- Leave-one-temperature-out winner by mean rank: `%s` with AIC win fraction `%.3f` and BIC win fraction `%.3f`.', ...
    char(loocvWinner.family_label(1)), loocvWinner.aic_win_fraction(1), loocvWinner.bic_win_fraction(1));
if isfinite(loocvWinner.rmse_test(1))
    lines(end + 1) = sprintf('- Leave-one-temperature-out predictive error for that family: RMSE_test `= %.6g`, mean absolute error `= %.6g`.', ...
        loocvWinner.rmse_test(1), loocvWinner.mean_abs_error_test(1));
end
lines(end + 1) = sprintf('- Bootstrap summary winner by mean rank: `%s` with AIC win fraction `%.3f` and BIC win fraction `%.3f` over `%d` resamples.', ...
    char(bootstrapWinner.family_label(1)), bootstrapWinner.aic_win_fraction(1), bootstrapWinner.bic_win_fraction(1), cfg.bootstrapCount);
lines(end + 1) = interpretRobustness(loocvWinner, bootstrapWinner, bestFamily);
lines(end + 1) = '';
lines(end + 1) = '## Interpretation';
lines(end + 1) = interpretBestFamily(bestFamily);
lines(end + 1) = 'This should still be interpreted as an empirical relationship between saved observables, not as proof of a unique microscopic law.';
lines(end + 1) = '';
lines(end + 1) = '## Visualization choices';
lines(end + 1) = '- number of curves: Figure 1 uses two temperature traces; Figures 2-4 use one temperature-colored scatter cloud each; Figure 5 uses one scatter cloud plus one best-fit curve; Figure 6 uses one residual cloud.';
lines(end + 1) = '- legend vs colormap: temperature is encoded by a labeled `parula` colorbar in the scatter figures; the temperature traces use direct axis labeling.';
lines(end + 1) = '- smoothing applied: none; all observables were loaded directly from immutable run outputs.';
lines(end + 1) = '- justification: the figure set separates temperature evolution, transformed scatter views, the best-fit curve, and residual structure.';
lines(end + 1) = '';
lines(end + 1) = '## Output files';
lines(end + 1) = '- `tables/AX_aligned_data.csv`';
lines(end + 1) = '- `tables/AX_family_comparison.csv`';
lines(end + 1) = '- `tables/AX_model_comparison.csv`';
lines(end + 1) = '- `tables/AX_parameter_estimates.csv`';
lines(end + 1) = '- `tables/AX_best_fit_curve.csv`';
lines(end + 1) = '- `tables/AX_loocv_family_rankings.csv`';
lines(end + 1) = '- `tables/AX_loocv_family_summary.csv`';
lines(end + 1) = '- `tables/AX_bootstrap_family_rankings.csv`';
lines(end + 1) = '- `tables/AX_bootstrap_family_summary.csv`';
lines(end + 1) = '- `reports/AX_functional_relation_analysis.md`';
lines(end + 1) = '- `review/AX_functional_relation_analysis_bundle.zip`';
reportText = strjoin(lines, newline);
end

function txt = interpretBestFamily(bestFamily)
switch char(bestFamily.family_key)
    case 'linear'
        txt = 'The data are best described by a linear relation in the original variables, so `X` behaves empirically like a direct affine proxy for relaxation activity over this temperature window.';
    case 'exponential'
        txt = 'The data are best described by an exponential relation in `X`, which is equivalent to an approximately linear `ln(A)` vs `X` relation. Empirically, that supports treating `X` as an activation-like coordinate.';
    case 'power_law'
        txt = 'The data are best described by a power law in `X`, which is equivalent to an approximately linear `ln(A)` vs `ln(X)` relation. Empirically, `X` behaves more like a scaling coordinate than a simple additive one.';
    case 'exponential_offset'
        txt = 'The data are best described by an exponential relation plus a finite offset, indicating that a mostly exponential trend is improved by a nonzero baseline term.';
    otherwise
        txt = 'The data are best described by an offset power law, indicating that a shifted scaling coordinate fits better than a zero-origin power law or pure exponential.';
end
end

function txt = interpretRobustness(loocvWinner, bootstrapWinner, bestFamily)
sameWinner = loocvWinner.family_key == bestFamily.family_key && bootstrapWinner.family_key == bestFamily.family_key;
if sameWinner && loocvWinner.aic_win_fraction >= 0.6 && bootstrapWinner.aic_win_fraction >= 0.6
    txt = 'The ranking is stable: the same unique family wins the full fit, leave-one-out analysis, and bootstrap summary with clear support fractions.';
elseif sameWinner
    txt = 'The same unique family remains nominally best across the full fit, leave-one-out analysis, and bootstrap summary, but nearby alternatives still compete nontrivially.';
else
    txt = 'The robustness checks show meaningful sensitivity: at least one alternative family overtakes the full-fit winner in leave-one-out or bootstrap summaries.';
end
end
function bestModel = pickBestModel(modelTbl)
joint = modelTbl(modelTbl.aic_rank == 1 & modelTbl.bic_rank == 1, :);
if ~isempty(joint)
    bestModel = joint(1, :);
else
    score = modelTbl.aic_rank + modelTbl.bic_rank;
    [~, idx] = min(score);
    bestModel = modelTbl(idx, :);
end
end

function yhat = predictFamily(fit, x)
switch char(fit.family_key)
    case 'linear'
        yhat = predictLinear(fit.params, x);
    case 'exponential'
        yhat = predictExponential(fit.params, x);
    case 'power_law'
        yhat = predictPowerLaw(fit.params, x);
    case 'exponential_offset'
        yhat = predictExponentialOffset(fit.params, x);
    otherwise
        yhat = predictOffsetPowerLaw(fit.params, x);
end
end

function yhat = predictLinear(p, x)
yhat = p(1) .* x + p(2);
end

function yhat = predictExponential(q, x)
yhat = exp(q(1) + q(2) .* x);
end

function yhat = predictPowerLaw(q, x)
yhat = exp(q(1)) .* x .^ q(2);
end

function yhat = predictExponentialOffset(q, x)
yhat = exp(q(1)) .* exp(q(2) .* x) + q(3);
end

function yhat = predictOffsetPowerLawRaw(q, x, minX)
yhat = exp(q(1)) .* (x - (minX - exp(q(3)))) .^ q(2);
end

function yhat = predictOffsetPowerLaw(q, x)
yhat = exp(q(1)) .* (x - q(3)) .^ q(2);
end

function sse = computeSSE(y, yhat)
if any(~isfinite(yhat)) || any(~isreal(yhat))
    sse = inf;
else
    res = y(:) - yhat(:);
    if any(~isfinite(res))
        sse = inf;
    else
        sse = sum(res .^ 2);
    end
end
end

function r2 = computeR2(y, yhat)
ssRes = sum((y(:) - yhat(:)) .^ 2);
ssTot = sum((y(:) - mean(y(:))) .^ 2);
if ssTot <= 0
    r2 = NaN;
else
    r2 = 1 - ssRes / ssTot;
end
end

function aic = computeAIC(sse, n, k)
aic = n * log(max(sse, eps) / n) + 2 * k;
end

function bic = computeBIC(sse, n, k)
bic = n * log(max(sse, eps) / n) + k * log(n);
end

function ranks = competitionRank(values)
ranks = NaN(size(values));
for i = 1:numel(values)
    ranks(i) = 1 + nnz(values < values(i));
end
end

function peakT = findPeakT(T, y)
[~, idx] = max(y);
peakT = T(idx);
end

function yNorm = normalize01(y)
y = y(:);
yMin = min(y);
yMax = max(y);
if abs(yMax - yMin) < 1e-12
    yNorm = 0.5 * ones(size(y));
else
    yNorm = (y - yMin) ./ (yMax - yMin);
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
zip(zipPath, {'figures', 'tables', 'reports'}, runDir);
end

function styleAxes(ax)
set(ax, 'FontSize', 8, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top', 'XMinorTick', 'off', 'YMinorTick', 'off');
end

function txt = formatTemperatureList(T)
txt = strjoin(compose('%.0f K', T(:).'), ', ');
end

function txt = joinQuoted(items)
if isempty(items)
    txt = '`none`';
else
    txt = strjoin(compose('`%s`', items), ', ');
end
end

function txt = fmt(x)
if isfinite(x)
    txt = sprintf('%.6g', x);
else
    txt = '-';
end
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

function cfg = setDefaultField(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
