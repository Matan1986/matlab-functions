function out = switching_a1_model_scan(cfg)
% switching_a1_model_scan
% Empirical model scan for dynamic shape-mode amplitude a1(T) using
% switching geometric observables and temperature derivatives.

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
runCfg.dataset = sprintf('a1:%s | obs:%s | deriv:%s', ...
    char(source.a1RunName), char(source.obsRunName), char(source.derivRunName));
run = createRunContext('switching', runCfg);
runDir = run.run_dir;

fprintf('Switching a1 model-scan run directory:\n%s\n', runDir);
fprintf('a1 source run: %s\n', source.a1RunName);
fprintf('effective-observables source run: %s\n', source.obsRunName);
fprintf('derivative source run: %s\n', source.derivRunName);

appendText(run.log_path, sprintf('[%s] switching a1 model scan started\n', stampNow()));
appendText(run.log_path, sprintf('a1 source: %s\n', char(source.a1RunName)));
appendText(run.log_path, sprintf('effective-observables source: %s\n', char(source.obsRunName)));
appendText(run.log_path, sprintf('derivative source: %s\n', char(source.derivRunName)));

data = loadAndAlignData(source, cfg);
predictorDefs = getPredictorDefinitions();
scan = runModelScan(data, predictorDefs, cfg);

scanTbl = scan.scanTable;
selectedRow = scan.selectedModel;
selectionTbl = buildSelectedPredictionTable(data, selectedRow);
sourceManifest = buildSourceManifestTable(source, data);

scanPath = save_run_table(scanTbl, 'a1_model_scan.csv', runDir);
predPath = save_run_table(selectionTbl, 'observed_vs_predicted_a1_table.csv', runDir);
manifestPath = save_run_table(sourceManifest, 'source_run_manifest.csv', runDir);

figPaths = saveObservedVsPredictedFigure(data, selectedRow, runDir);
reportText = buildBestModelsReport(source, data, scan, cfg, scanPath, predPath, figPaths);
reportPath = save_run_report(reportText, 'best_a1_models.md', runDir);

zipPath = buildReviewZip(runDir, 'switching_a1_model_scan_bundle.zip');

rootScanPath = fullfile(runDir, 'a1_model_scan.csv');
rootReportPath = fullfile(runDir, 'best_a1_models.md');
rootFigurePath = fullfile(runDir, 'observed_vs_predicted_a1.png');
rootZipPath = fullfile(runDir, 'switching_a1_model_scan_review_bundle.zip');
copyfile(scanPath, rootScanPath);
copyfile(reportPath, rootReportPath);
copyfile(figPaths.png, rootFigurePath);
copyfile(zipPath, rootZipPath);

appendText(run.notes_path, sprintf('Selected model = %s\n', char(selectedRow.predictors)));
appendText(run.notes_path, sprintf('Selected model family = %s\n', char(selectedRow.model_family)));
appendText(run.notes_path, sprintf('Selected model adjusted R^2 = %.6f\n', selectedRow.adj_r2));
appendText(run.notes_path, sprintf('Selected model LOTO-CV RMSE = %.6f\n', selectedRow.cv_rmse));
appendText(run.notes_path, sprintf('Three-predictor models tested = %d\n', scan.threeSummary.allowThree));
appendText(run.notes_path, sprintf('Three-predictor rule reason: %s\n', char(scan.threeSummary.reason)));
appendText(run.notes_path, sprintf('Output CSV = %s\n', rootScanPath));
appendText(run.notes_path, sprintf('Output report = %s\n', rootReportPath));
appendText(run.notes_path, sprintf('Output figure = %s\n', rootFigurePath));
appendText(run.notes_path, sprintf('Review bundle = %s\n', rootZipPath));

appendText(run.log_path, sprintf('[%s] switching a1 model scan complete\n', stampNow()));
appendText(run.log_path, sprintf('Model scan table: %s\n', scanPath));
appendText(run.log_path, sprintf('Predictions table: %s\n', predPath));
appendText(run.log_path, sprintf('Manifest: %s\n', manifestPath));
appendText(run.log_path, sprintf('Figure: %s\n', figPaths.png));
appendText(run.log_path, sprintf('Report: %s\n', reportPath));
appendText(run.log_path, sprintf('ZIP: %s\n', zipPath));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.source = source;
out.data = data;
out.scanTable = scanTbl;
out.selectedModel = selectedRow;
out.paths = struct( ...
    'scanTable', string(scanPath), ...
    'predictions', string(predPath), ...
    'manifest', string(manifestPath), ...
    'figure', string(figPaths.png), ...
    'report', string(reportPath), ...
    'zip', string(zipPath), ...
    'rootScan', string(rootScanPath), ...
    'rootReport', string(rootReportPath), ...
    'rootFigure', string(rootFigurePath), ...
    'rootZip', string(rootZipPath));

fprintf('\n=== Switching a1 model scan complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Selected model: %s\n', char(selectedRow.predictors));
fprintf('Adjusted R^2: %.4f\n', selectedRow.adj_r2);
fprintf('LOTO-CV RMSE: %.4f\n', selectedRow.cv_rmse);
fprintf('Model scan CSV: %s\n', rootScanPath);
fprintf('Report: %s\n', rootReportPath);
fprintf('Figure: %s\n', rootFigurePath);
fprintf('ZIP: %s\n\n', rootZipPath);
end

function cfg = applyDefaults(cfg)
cfg = setDefaultField(cfg, 'runLabel', 'switching_a1_model_scan');
cfg = setDefaultField(cfg, 'a1RunName', 'run_2026_03_14_161801_switching_dynamic_shape_mode');
cfg = setDefaultField(cfg, 'obsRunName', 'run_2026_03_13_152008_switching_effective_observables');
cfg = setDefaultField(cfg, 'derivRunName', 'run_2026_03_14_212255_switching_ridge_motion_decomposition');
cfg = setDefaultField(cfg, 'temperatureMinK', 4);
cfg = setDefaultField(cfg, 'temperatureMaxK', 30);
cfg = setDefaultField(cfg, 'minimalityToleranceFraction', 0.05);
cfg = setDefaultField(cfg, 'threePredictorGainCvFraction', 0.08);
cfg = setDefaultField(cfg, 'threePredictorGainAdjR2', 0.03);
cfg = setDefaultField(cfg, 'maxAbsCorrForThree', 0.92);
cfg = setDefaultField(cfg, 'topTwoSeedsForThree', 4);
cfg = setDefaultField(cfg, 'maxThreeModels', 12);
cfg = setDefaultField(cfg, 'topReportCount', 12);
end

function source = resolveSourceRuns(repoRoot, cfg)
source = struct();
source.a1RunName = string(cfg.a1RunName);
source.obsRunName = string(cfg.obsRunName);
source.derivRunName = string(cfg.derivRunName);

source.a1RunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.a1RunName));
source.obsRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.obsRunName));
source.derivRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(source.derivRunName));

source.a1Path = fullfile(source.a1RunDir, 'tables', 'switching_dynamic_shape_mode_amplitudes.csv');
source.obsPath = fullfile(source.obsRunDir, 'tables', 'switching_effective_observables_table.csv');
if exist(source.obsPath, 'file') ~= 2
    source.obsPath = fullfile(source.obsRunDir, 'observables.csv');
end
source.derivPath = fullfile(source.derivRunDir, 'tables', 'ridge_motion_contributions_vs_temperature.csv');

required = {
    source.a1RunDir, source.a1Path;
    source.obsRunDir, source.obsPath;
    source.derivRunDir, source.derivPath
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

function data = loadAndAlignData(source, cfg)
a1Tbl = readtable(source.a1Path);
obsTbl = readtable(source.obsPath);
derivTbl = readtable(source.derivPath);

requiredA1 = {'T_K', 'a_1'};
requiredObs = {'T_K', 'I_peak_mA', 'width_mA', 'S_peak', 'X'};
requiredDeriv = {'T_K', 'dI_peak_dT_smoothed_mA_per_K', 'dwidth_dT_smoothed_mA_per_K', ...
    'dS_peak_dT_smoothed_per_K', 'dX_dT_smoothed_per_K'};
assertColumns(a1Tbl, requiredA1, source.a1Path);
assertColumns(obsTbl, requiredObs, source.obsPath);
assertColumns(derivTbl, requiredDeriv, source.derivPath);

Ta1 = double(a1Tbl.T_K(:));
Tobs = double(obsTbl.T_K(:));
Tderiv = double(derivTbl.T_K(:));

[Tcommon, ia, ib] = intersect(Ta1, Tobs, 'stable');
[Tcommon, ic, id] = intersect(Tcommon, Tderiv, 'stable');
idxA1 = ia(ic);
idxObs = ib(ic);
idxDeriv = id;

if isempty(Tcommon)
    error('No overlapping temperatures across source tables.');
end

maskRange = Tcommon >= cfg.temperatureMinK & Tcommon <= cfg.temperatureMaxK;
T = Tcommon(maskRange);
idxA1 = idxA1(maskRange);
idxObs = idxObs(maskRange);
idxDeriv = idxDeriv(maskRange);

a1 = double(a1Tbl.a_1(idxA1));
I_peak = double(obsTbl.I_peak_mA(idxObs));
width = double(obsTbl.width_mA(idxObs));
S_peak = double(obsTbl.S_peak(idxObs));
X = double(obsTbl.X(idxObs));

dI_peak_dT = double(derivTbl.dI_peak_dT_smoothed_mA_per_K(idxDeriv));
dwidth_dT = double(derivTbl.dwidth_dT_smoothed_mA_per_K(idxDeriv));
dS_peak_dT = double(derivTbl.dS_peak_dT_smoothed_per_K(idxDeriv));
dX_dT = double(derivTbl.dX_dT_smoothed_per_K(idxDeriv));

allValues = [a1, dI_peak_dT, dwidth_dT, dS_peak_dT, dX_dT, I_peak, width, S_peak, X];
validMask = all(isfinite(allValues), 2);

T = T(validMask);
a1 = a1(validMask);
dI_peak_dT = dI_peak_dT(validMask);
dwidth_dT = dwidth_dT(validMask);
dS_peak_dT = dS_peak_dT(validMask);
dX_dT = dX_dT(validMask);
I_peak = I_peak(validMask);
width = width(validMask);
S_peak = S_peak(validMask);
X = X(validMask);

if numel(T) < 8
    error('Need at least 8 aligned temperature points for stable LOTO validation.');
end

data = struct();
data.T_K = T(:);
data.a1 = a1(:);
data.predictorMatrix = [dI_peak_dT(:), dwidth_dT(:), dS_peak_dT(:), dX_dT(:), ...
    I_peak(:), width(:), S_peak(:), X(:)];
data.predictorNames = {'dI_peak_dT', 'dwidth_dT', 'dS_peak_dT', 'dX_dT', ...
    'I_peak', 'width', 'S_peak', 'X'};
end

function predictorDefs = getPredictorDefinitions()
predictorDefs = struct();
predictorDefs.names = {'dI_peak_dT', 'dwidth_dT', 'dS_peak_dT', 'dX_dT', ...
    'I_peak', 'width', 'S_peak', 'X'};
predictorDefs.family = {'derivative', 'derivative', 'derivative', 'derivative', ...
    'static', 'static', 'static', 'static'};
end

function scan = runModelScan(data, predictorDefs, cfg)
y = data.a1(:);
Xall = data.predictorMatrix;
names = predictorDefs.names;
family = predictorDefs.family;
nPredictors = numel(names);

singleCombos = num2cell((1:nPredictors).', 2);
pairCombos = num2cell(nchoosek(1:nPredictors, 2), 2);

singleRows = evaluateCombinationSet(y, Xall, names, family, singleCombos, false);
pairRows = evaluateCombinationSet(y, Xall, names, family, pairCombos, false);

singleTbl = rowsToTable(singleRows);
pairTbl = rowsToTable(pairRows);

[bestSingle, bestTwo] = bestFromTables(singleTbl, pairTbl);
[allowThree, reason] = shouldTestThreePredictorModels(bestSingle, bestTwo, cfg);

threeRows = struct([]);
if allowThree
    tripleCombos = buildLimitedThreePredictorCombos(pairTbl, Xall, cfg, names);
    if ~isempty(tripleCombos)
        threeRows = evaluateCombinationSet(y, Xall, names, family, tripleCombos, true);
    end
end

allRows = [singleRows; pairRows; threeRows];
scanTable = rowsToTable(allRows);
scanTable = sortrows(scanTable, {'cv_rmse', 'n_predictors', 'adj_r2'}, {'ascend', 'ascend', 'descend'});
scanTable.cv_rank = (1:height(scanTable)).';

selectedModel = selectPreferredMinimalModel(scanTable, cfg);
categoryBest = findCategoryWinners(scanTable);

scan = struct();
scan.scanTable = scanTable;
scan.selectedModel = selectedModel;
scan.bestSingle = bestSingle;
scan.bestTwo = bestTwo;
scan.categoryBest = categoryBest;
scan.threeSummary = struct('allowThree', allowThree, 'reason', string(reason), ...
    'testedCount', sum(scanTable.n_predictors == 3));
end

function rows = evaluateCombinationSet(y, Xall, predictorNames, predictorFamily, combos, isThreeSet)
rows = repmat(emptyRow(), 0, 1);
for i = 1:numel(combos)
    idx = combos{i};
    Xsel = Xall(:, idx);
    fit = evaluateLinearModel(y, Xsel);

    predNames = predictorNames(idx);
    predFamily = predictorFamily(idx);
    modelInfo = classifyModel(predNames, predFamily);

    row = emptyRow();
    row.model_id = string(sprintf('M%03d', i));
    row.n_predictors = numel(idx);
    row.predictor_1 = string(predNames{1});
    if numel(idx) >= 2
        row.predictor_2 = string(predNames{2});
    end
    if numel(idx) >= 3
        row.predictor_3 = string(predNames{3});
    end
    row.predictors = string(strjoin(predNames, ' + '));
    row.model_family = modelInfo.family;
    row.interpretability_tier = modelInfo.tier;
    row.interpretability_note = modelInfo.note;
    row.train_r2 = fit.r2;
    row.adj_r2 = fit.adjR2;
    row.train_rmse = fit.trainRmse;
    row.cv_rmse = fit.cvRmse;
    row.cv_mae = fit.cvMae;
    row.cv_r2 = fit.cvR2;
    row.intercept = fit.beta(1);
    row.coef_1 = fit.beta(2);
    if numel(fit.beta) >= 3
        row.coef_2 = fit.beta(3);
    end
    if numel(fit.beta) >= 4
        row.coef_3 = fit.beta(4);
    end
    row.three_predictor_set = logical(isThreeSet);

    rows(end + 1, 1) = row; %#ok<AGROW>
end
end

function row = emptyRow()
row = struct( ...
    'model_id', "", ...
    'n_predictors', NaN, ...
    'predictor_1', "", ...
    'predictor_2', "", ...
    'predictor_3', "", ...
    'predictors', "", ...
    'model_family', "", ...
    'interpretability_tier', "", ...
    'interpretability_note', "", ...
    'train_r2', NaN, ...
    'adj_r2', NaN, ...
    'train_rmse', NaN, ...
    'cv_rmse', NaN, ...
    'cv_mae', NaN, ...
    'cv_r2', NaN, ...
    'intercept', NaN, ...
    'coef_1', NaN, ...
    'coef_2', NaN, ...
    'coef_3', NaN, ...
    'three_predictor_set', false);
end

function fit = evaluateLinearModel(y, Xsel)
y = y(:);
n = numel(y);
k = size(Xsel, 2);
X = [ones(n, 1), Xsel];

beta = pinv(X) * y;
yhat = X * beta;
resid = y - yhat;
sse = sum(resid .^ 2);
sst = sum((y - mean(y)).^2);

r2 = NaN;
adjR2 = NaN;
if isfinite(sst) && sst > 0
    r2 = 1 - (sse / sst);
    if n > k + 1
        adjR2 = 1 - ((1 - r2) * (n - 1) / (n - k - 1));
    end
end

cvPred = NaN(n, 1);
for i = 1:n
    mask = true(n, 1);
    mask(i) = false;
    Xi = [ones(sum(mask), 1), Xsel(mask, :)];
    yi = y(mask);
    betai = pinv(Xi) * yi;
    cvPred(i) = [1, Xsel(i, :)] * betai;
end
cvErr = y - cvPred;
cvSse = sum(cvErr .^ 2);
cvR2 = NaN;
if isfinite(sst) && sst > 0
    cvR2 = 1 - (cvSse / sst);
end

fit = struct();
fit.beta = beta(:);
fit.r2 = r2;
fit.adjR2 = adjR2;
fit.trainRmse = sqrt(mean(resid.^2));
fit.cvRmse = sqrt(mean(cvErr.^2));
fit.cvMae = mean(abs(cvErr));
fit.cvR2 = cvR2;
fit.yhat = yhat;
fit.cvPred = cvPred;
end

function modelInfo = classifyModel(predNames, predFamily)
n = numel(predNames);
isDeriv = strcmp(predFamily, 'derivative');
nDeriv = nnz(isDeriv);
nStatic = n - nDeriv;

if n == 1 && nDeriv == 1
    modelInfo.family = "single_derivative";
    modelInfo.tier = "high";
    modelInfo.note = "single-derivative observable";
elseif n == 1
    modelInfo.family = "single_static";
    modelInfo.tier = "high";
    modelInfo.note = "single static geometric observable";
elseif n == 2 && nDeriv == 1 && nStatic == 1
    modelInfo.family = "derivative_plus_static";
    modelInfo.tier = "medium-high";
    modelInfo.note = "derivative-plus-static geometric combination";
elseif n == 2 && nDeriv == 2
    modelInfo.family = "two_derivative";
    modelInfo.tier = "medium";
    modelInfo.note = "two-derivative mixed coordinate";
elseif n == 2
    modelInfo.family = "two_static";
    modelInfo.tier = "medium";
    modelInfo.note = "mixed geometric deformation coordinate";
elseif n == 3 && nDeriv >= 1 && nStatic >= 1
    modelInfo.family = "three_mixed";
    modelInfo.tier = "low";
    modelInfo.note = "three-term mixed derivative/static coordinate";
elseif n == 3 && nDeriv == 3
    modelInfo.family = "three_derivative";
    modelInfo.tier = "low";
    modelInfo.note = "three-derivative coordinate";
else
    modelInfo.family = "three_static";
    modelInfo.tier = "low";
    modelInfo.note = "three-static geometric coordinate";
end
end

function tbl = rowsToTable(rows)
if isempty(rows)
    tbl = struct2table(repmat(emptyRow(), 0, 1));
    return;
end
tbl = struct2table(rows);
end

function [bestSingle, bestTwo] = bestFromTables(singleTbl, pairTbl)
bestSingle = table();
bestTwo = table();
if ~isempty(singleTbl)
    tmp = sortrows(singleTbl, {'cv_rmse', 'adj_r2'}, {'ascend', 'descend'});
    bestSingle = tmp(1, :);
end
if ~isempty(pairTbl)
    tmp = sortrows(pairTbl, {'cv_rmse', 'adj_r2'}, {'ascend', 'descend'});
    bestTwo = tmp(1, :);
end
end

function [allowThree, reason] = shouldTestThreePredictorModels(bestSingle, bestTwo, cfg)
allowThree = false;
reason = "three-predictor models not tested";

if isempty(bestSingle) || isempty(bestTwo)
    reason = "insufficient single/two model results";
    return;
end

cvImprovement = (bestSingle.cv_rmse(1) - bestTwo.cv_rmse(1)) / bestSingle.cv_rmse(1);
adjGain = bestTwo.adj_r2(1) - bestSingle.adj_r2(1);

if cvImprovement >= cfg.threePredictorGainCvFraction && adjGain >= cfg.threePredictorGainAdjR2
    allowThree = true;
    reason = sprintf(['two-predictor gain is material (CV improve %.2f%%, adjR2 gain %.4f), ', ...
        'so limited three-predictor extensions were tested'], 100 * cvImprovement, adjGain);
else
    reason = sprintf(['two-predictor gain is not large enough (CV improve %.2f%%, adjR2 gain %.4f), ', ...
        'so three-predictor models were skipped to prefer minimality'], 100 * cvImprovement, adjGain);
end
end

function combos = buildLimitedThreePredictorCombos(pairTbl, Xall, cfg, predictorNames)
combos = {};
if isempty(pairTbl)
    return;
end

sortedPairs = sortrows(pairTbl, {'cv_rmse', 'adj_r2'}, {'ascend', 'descend'});
nSeed = min(cfg.topTwoSeedsForThree, height(sortedPairs));
sortedPairs = sortedPairs(1:nSeed, :);

nameToIdx = containers.Map();
for i = 1:numel(predictorNames)
    nameToIdx(predictorNames{i}) = i;
end

corrM = corr(Xall, 'Rows', 'pairwise');
if any(~isfinite(corrM(:)))
    corrM(~isfinite(corrM)) = 0;
end

comboKey = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for i = 1:height(sortedPairs)
    p1 = char(sortedPairs.predictor_1(i));
    p2 = char(sortedPairs.predictor_2(i));
    idx1 = nameToIdx(p1);
    idx2 = nameToIdx(p2);
    others = setdiff(1:size(Xall, 2), [idx1, idx2], 'stable');

    score = inf(size(others));
    keep = false(size(others));
    for j = 1:numel(others)
        idx3 = others(j);
        c1 = abs(corrM(idx1, idx3));
        c2 = abs(corrM(idx2, idx3));
        maxCorr = max(c1, c2);
        score(j) = maxCorr;
        keep(j) = maxCorr <= cfg.maxAbsCorrForThree;
    end

    if ~any(keep) && ~isempty(others)
        [~, bestJ] = min(score);
        keep(bestJ) = true;
    end

    selectedThird = others(keep);
    for j = 1:numel(selectedThird)
        triple = sort([idx1, idx2, selectedThird(j)]);
        key = sprintf('%d_%d_%d', triple(1), triple(2), triple(3));
        if ~isKey(comboKey, key)
            comboKey(key) = true;
            combos{end + 1, 1} = triple; %#ok<AGROW>
            if numel(combos) >= cfg.maxThreeModels
                return;
            end
        end
    end
end
end

function selectedRow = selectPreferredMinimalModel(scanTable, cfg)
minCv = min(scanTable.cv_rmse);
nearBest = scanTable(scanTable.cv_rmse <= minCv * (1 + cfg.minimalityToleranceFraction), :);
nearBest = sortrows(nearBest, {'n_predictors', 'cv_rmse', 'adj_r2'}, {'ascend', 'ascend', 'descend'});
selectedRow = nearBest(1, :);
end

function winners = findCategoryWinners(scanTable)
winners = struct();
winners.singleDerivative = pickBest(scanTable, scanTable.n_predictors == 1 & scanTable.model_family == "single_derivative");
winners.singleStatic = pickBest(scanTable, scanTable.n_predictors == 1 & scanTable.model_family == "single_static");
winners.mixedGeometric = pickBest(scanTable, ...
    scanTable.model_family == "two_derivative" | ...
    scanTable.model_family == "three_derivative" | ...
    scanTable.model_family == "two_static" | ...
    scanTable.model_family == "three_static");
winners.derivativePlusStatic = pickBest(scanTable, scanTable.model_family == "derivative_plus_static" | scanTable.model_family == "three_mixed");
end

function row = pickBest(tbl, mask)
if nnz(mask) == 0
    row = table();
    return;
end
tmp = sortrows(tbl(mask, :), {'cv_rmse', 'n_predictors', 'adj_r2'}, {'ascend', 'ascend', 'descend'});
row = tmp(1, :);
end

function predTbl = buildSelectedPredictionTable(data, selectedRow)
y = data.a1(:);
T = data.T_K(:);
[yhat, ycv] = predictForRow(selectedRow, data);
predTbl = table(T, y, yhat, ycv, y - yhat, y - ycv, ...
    'VariableNames', {'T_K', 'a1_observed', 'a1_predicted_train', 'a1_predicted_loto_cv', ...
    'train_residual', 'loto_cv_residual'});
end

function manifestTbl = buildSourceManifestTable(source, data)
manifestTbl = table( ...
    string({'a1_dynamic_shape_mode'; 'effective_observables'; 'ridge_motion_derivatives'}), ...
    string({source.a1RunName; source.obsRunName; source.derivRunName}), ...
    string({source.a1Path; source.obsPath; source.derivPath}), ...
    string({'a1(T) target'; 'static geometric predictors'; 'temperature-derivative predictors'}), ...
    repmat(string(sprintf('%d temperatures after intersection/range filter', numel(data.T_K))), 3, 1), ...
    'VariableNames', {'source_role', 'source_run', 'source_file', 'role_note', 'alignment_note'});
end

function figPaths = saveObservedVsPredictedFigure(data, selectedRow, runDir)
T = data.T_K(:);
y = data.a1(:);
[yhat, ycv] = predictForRow(selectedRow, data);

fig = create_figure('Visible', 'off', 'Position', [2 2 16 8]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
scatter(ax1, y, yhat, 80, T, 'filled');
hold(ax1, 'on');
drawIdentityLine(ax1, y, yhat);
hold(ax1, 'off');
xlabel(ax1, 'Observed a_1(T)');
ylabel(ax1, 'Predicted a_1(T) (fit on full set)');
title(ax1, 'In-sample prediction');
cb1 = colorbar(ax1);
ylabel(cb1, 'Temperature (K)');
styleAxes(ax1);

ax2 = nexttile(tl, 2);
scatter(ax2, y, ycv, 80, T, 'filled');
hold(ax2, 'on');
drawIdentityLine(ax2, y, ycv);
hold(ax2, 'off');
xlabel(ax2, 'Observed a_1(T)');
ylabel(ax2, 'Predicted a_1(T) (leave-one-T-out)');
title(ax2, 'Cross-validated prediction');
cb2 = colorbar(ax2);
ylabel(cb2, 'Temperature (K)');
styleAxes(ax2);

title(tl, sprintf('Selected model: %s', char(selectedRow.predictors)));
figPaths = save_run_figure(fig, 'observed_vs_predicted_a1', runDir);
close(fig);
end

function drawIdentityLine(ax, x, y)
vals = [x(:); y(:)];
vmin = min(vals);
vmax = max(vals);
if ~isfinite(vmin) || ~isfinite(vmax)
    return;
end
pad = 0.05 * max(1e-6, vmax - vmin);
lims = [vmin - pad, vmax + pad];
plot(ax, lims, lims, '--', 'LineWidth', 1.4, 'Color', [0.35 0.35 0.35]);
xlim(ax, lims);
ylim(ax, lims);
end

function [yhat, ycv] = predictForRow(row, data)
predNames = {};
if strlength(row.predictor_1(1)) > 0
    predNames{end + 1} = char(row.predictor_1(1)); %#ok<AGROW>
end
if strlength(row.predictor_2(1)) > 0
    predNames{end + 1} = char(row.predictor_2(1)); %#ok<AGROW>
end
if strlength(row.predictor_3(1)) > 0
    predNames{end + 1} = char(row.predictor_3(1)); %#ok<AGROW>
end

allNames = data.predictorNames;
idx = zeros(1, numel(predNames));
for i = 1:numel(predNames)
    idx(i) = find(strcmp(allNames, predNames{i}), 1, 'first');
end
Xsel = data.predictorMatrix(:, idx);
y = data.a1(:);
fit = evaluateLinearModel(y, Xsel);
yhat = fit.yhat;
ycv = fit.cvPred;
end

function reportText = buildBestModelsReport(source, data, scan, cfg, scanPath, predPath, figPaths)
scanTbl = scan.scanTable;
selected = scan.selectedModel;
topCount = min(cfg.topReportCount, height(scanTbl));
topTbl = scanTbl(1:topCount, :);

lines = strings(0, 1);
lines(end + 1) = "# a1(T) empirical model scan";
lines(end + 1) = "";
lines(end + 1) = "## Scope";
lines(end + 1) = "- Target: `a1(T)` from dynamic shape-mode SVD amplitudes.";
lines(end + 1) = "- Predictors tested:";
lines(end + 1) = "  `dI_peak/dT`, `dwidth/dT`, `dS_peak/dT`, `dX/dT`, `I_peak(T)`, `width(T)`, `S_peak(T)`, `X(T)`.";
lines(end + 1) = "- Validation: leave-one-temperature-out (LOTO), one held-out temperature per fold.";
lines(end + 1) = sprintf("- Sample count after alignment: `%d` temperatures (`%.1f` to `%.1f` K).", ...
    numel(data.T_K), min(data.T_K), max(data.T_K));
lines(end + 1) = "";
lines(end + 1) = "## Source runs";
lines(end + 1) = sprintf("- a1 source run: `%s`.", char(source.a1RunName));
lines(end + 1) = sprintf("- effective-observables source run: `%s`.", char(source.obsRunName));
lines(end + 1) = sprintf("- derivative source run: `%s`.", char(source.derivRunName));
lines(end + 1) = "";
lines(end + 1) = "## Model-space policy";
lines(end + 1) = "- Single-predictor models: tested all 8 candidates.";
lines(end + 1) = "- Two-predictor linear models: tested all 28 unique pairs.";
lines(end + 1) = sprintf("- Three-predictor models tested: `%d`.", scan.threeSummary.testedCount);
lines(end + 1) = "- Three-predictor gating reason:";
lines(end + 1) = "  " + string(scan.threeSummary.reason);
lines(end + 1) = "";
lines(end + 1) = "## Top models by CV error (and adjusted R^2)";
lines(end + 1) = "| Rank | Predictors | n | Family | Adjusted R^2 | LOTO CV RMSE | LOTO CV MAE | Interpretability |";
lines(end + 1) = "| ---: | --- | ---: | --- | ---: | ---: | ---: | --- |";
for i = 1:height(topTbl)
    lines(end + 1) = sprintf("| %d | %s | %d | %s | %.4f | %.5f | %.5f | %s |", ...
        i, topTbl.predictors(i), topTbl.n_predictors(i), topTbl.model_family(i), ...
        topTbl.adj_r2(i), topTbl.cv_rmse(i), topTbl.cv_mae(i), topTbl.interpretability_note(i));
end
lines(end + 1) = "";
lines(end + 1) = "## Best models by interpretation category";
lines = appendWinnerLine(lines, "single-derivative observable", scan.categoryBest.singleDerivative);
lines = appendWinnerLine(lines, "mixed geometric deformation coordinate", scan.categoryBest.mixedGeometric);
lines = appendWinnerLine(lines, "derivative-plus-static combination", scan.categoryBest.derivativePlusStatic);
lines(end + 1) = "";
lines(end + 1) = "## Selected minimal model";
lines(end + 1) = sprintf("- Selected predictors: `%s`.", selected.predictors(1));
lines(end + 1) = sprintf("- Family: `%s`.", selected.model_family(1));
lines(end + 1) = sprintf("- adjusted R^2 = `%.4f`.", selected.adj_r2(1));
lines(end + 1) = sprintf("- LOTO CV RMSE = `%.5f`.", selected.cv_rmse(1));
lines(end + 1) = sprintf("- LOTO CV MAE = `%.5f`.", selected.cv_mae(1));
lines(end + 1) = "- Selection rule: choose the smallest model within 5% of the minimum CV RMSE.";
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
lines(end + 1) = interpretationStatement(selected);
lines(end + 1) = "";
lines(end + 1) = "## Requested outputs";
lines(end + 1) = "- `a1_model_scan.csv`: `" + string(scanPath) + "`.";
lines(end + 1) = "- `best_a1_models.md`: this report.";
lines(end + 1) = "- `observed_vs_predicted_a1.png`: `" + string(figPaths.png) + "`.";
lines(end + 1) = "- predictions table: `" + string(predPath) + "`.";
lines(end + 1) = "- review bundle ZIP: `review/switching_a1_model_scan_bundle.zip`.";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated on: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

reportText = strjoin(lines, newline);
end

function lines = appendWinnerLine(lines, label, winnerTbl)
if isempty(winnerTbl)
    lines(end + 1) = sprintf("- %s: no model in scanned space.", label);
    return;
end
lines(end + 1) = sprintf("- %s: `%s` (adj R^2 %.4f, CV RMSE %.5f).", ...
    label, winnerTbl.predictors(1), winnerTbl.adj_r2(1), winnerTbl.cv_rmse(1));
end

function txt = interpretationStatement(selected)
family = string(selected.model_family(1));
if family == "single_derivative"
    txt = "- Best support is for a **single-derivative observable** controlling `a1(T)` in this dataset.";
elseif family == "single_static"
    txt = "- Best support is for a **single static geometric observable**, not a multi-coordinate mixture.";
elseif family == "derivative_plus_static" || family == "three_mixed"
    txt = "- Best support is for a **derivative-plus-static geometry combination**, consistent with a coupled deformation coordinate.";
else
    txt = "- Best support is for a **mixed geometric deformation coordinate** rather than a single-predictor description.";
end
end

function styleAxes(ax)
set(ax, 'FontName', 'Helvetica', ...
    'FontSize', 14, ...
    'LineWidth', 1.1, ...
    'TickDir', 'out', ...
    'Box', 'off', ...
    'Layer', 'top', ...
    'XMinorTick', 'off', ...
    'YMinorTick', 'off');
grid(ax, 'on');
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
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function assertColumns(tbl, names, tablePath)
for i = 1:numel(names)
    if ~ismember(names{i}, tbl.Properties.VariableNames)
        error('Required column "%s" missing in %s', names{i}, tablePath);
    end
end
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

function stamp = stampNow()
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefaultField(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end

