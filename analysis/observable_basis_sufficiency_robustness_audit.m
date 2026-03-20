function out = observable_basis_sufficiency_robustness_audit(cfg)
% observable_basis_sufficiency_robustness_audit
% Robustness audit for basis sufficiency classifications under multiple
% alignment/interpolation methods using existing catalog outputs only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg);
input = resolveInputs(repoRoot, cfg);

catalogTbl = readtable(input.catalogPath, 'TextType', 'string');

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('basis_sufficiency_source:%s | catalog_source:%s', input.sourceRunId, input.catalogRunId);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

appendText(run.log_path, sprintf('[%s] robustness audit started\n', stampNow()));
appendText(run.log_path, sprintf('source_run: %s\n', input.sourceRunId));
appendText(run.log_path, sprintf('catalog_path: %s\n', input.catalogPath));

series = struct();
for i = 1:numel(cfg.requiredObservables)
    obsName = string(cfg.requiredObservables{i});
    [T, V] = extractSeries(catalogTbl, obsName);
    series.(char(obsName)) = struct('T', T, 'V', V);
end

targets = string(cfg.targetObservables(:));
methods = alignmentMethods();
modelSpecs = buildModelSpecs();

resultRows = [];
for ti = 1:numel(targets)
    target = targets(ti);

    for mi = 1:numel(methods)
        method = methods(mi);
        aligned = buildAlignedDataForMethod(series, target, method, cfg);

        nPts = height(aligned);
        bestModel = "none";
        bestCVR2 = NaN;
        bestRMSE = NaN;
        classLabel = "NOT_EXPLAINED_BY_BASIS";

        if nPts >= cfg.minPointsForModeling
            evalTbl = evaluateTargetModels(aligned, target, modelSpecs, cfg);
            classLabel = classifyTarget(evalTbl, cfg);
            [bestModel, bestCVR2, bestRMSE] = pickBestOverall(evalTbl);
        end

        oneRow = table( ...
            target, ...
            method.name, ...
            nPts, ...
            bestModel, ...
            bestCVR2, ...
            bestRMSE, ...
            classLabel, ...
            'VariableNames', {'target_observable','alignment_method','n_points','best_model','CV_R2','RMSE','classification'});

        resultRows = [resultRows; oneRow]; %#ok<AGROW>
    end
end

resultsTbl = resultRows;
summaryTbl = buildRobustnessSummary(resultsTbl, targets, cfg.originalProvisional);

resultsPath = save_run_table(resultsTbl, 'basis_sufficiency_robustness_results.csv', runDir);
summaryPath = save_run_table(summaryTbl, 'basis_sufficiency_robustness_summary.csv', runDir);

reportText = buildReport(resultsTbl, summaryTbl, methods, input, runDir, cfg);
reportPath = save_run_report(reportText, 'observable_basis_sufficiency_robustness_report.md', runDir);

zipPath = buildReviewZip(runDir, 'observable_basis_sufficiency_robustness_bundle.zip');

appendText(run.log_path, sprintf('results_table: %s\n', resultsPath));
appendText(run.log_path, sprintf('summary_table: %s\n', summaryPath));
appendText(run.log_path, sprintf('report: %s\n', reportPath));
appendText(run.log_path, sprintf('bundle: %s\n', zipPath));
appendText(run.log_path, sprintf('[%s] robustness audit complete\n', stampNow()));

robustTargets = summaryTbl.target_observable(summaryTbl.robustness_status == "ROBUST");
sensitiveTargets = summaryTbl.target_observable(summaryTbl.robustness_status == "SENSITIVE_TO_ALIGNMENT");
inconclusiveTargets = summaryTbl.target_observable(summaryTbl.robustness_status == "INCONCLUSIVE");

recommended = recommendFinalInterpretation(summaryTbl);

fprintf('RUN_ID=%s\n', run.run_id);
fprintf('Targets_tested=%s\n', strjoin(cellstr(targets), ', '));
fprintf('Robust_classifications=%s\n', strjoin(cellstr(robustTargets), ', '));
fprintf('Sensitive_classifications=%s\n', strjoin(cellstr(sensitiveTargets), ', '));
fprintf('Inconclusive_classifications=%s\n', strjoin(cellstr(inconclusiveTargets), ', '));
fprintf('Recommended_final_basis_interpretation=%s\n', recommended);

out = struct();
out.run = run;
out.paths = struct('results', string(resultsPath), 'summary', string(summaryPath), ...
    'report', string(reportPath), 'bundle', string(zipPath));
out.summary = summaryTbl;
out.interpretation = recommended;
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'observable_basis_sufficiency_robustness_audit');
cfg = setDefault(cfg, 'sourceRunId', 'run_2026_03_16_151440_observable_basis_sufficiency_test');
cfg = setDefault(cfg, 'catalogPath', fullfile('results', 'cross_experiment', 'runs', ...
    'run_2026_03_16_110632_observable_catalog_completion', 'tables', 'observable_catalog.csv'));
cfg = setDefault(cfg, 'requiredObservables', {'X','kappa','A','R','chi_ridge','a1'});
cfg = setDefault(cfg, 'targetObservables', {'A','R','chi_ridge','a1'});
cfg = setDefault(cfg, 'nearestToleranceK', 1.1);
cfg = setDefault(cfg, 'minPointsForModeling', 3);
cfg = setDefault(cfg, 'minPointsForConfident', 6);
cfg = setDefault(cfg, 'r2ExplainThreshold', 0.50);
cfg = setDefault(cfg, 'deltaImproveThreshold', 0.05);

cfg = setDefault(cfg, 'originalProvisional', struct( ...
    'A', "EXPLAINED_BY_X", ...
    'R', "NOT_EXPLAINED_BY_BASIS", ...
    'chi_ridge', "EXPLAINED_BY_X", ...
    'a1', "EXPLAINED_BY_X_KAPPA"));
end

function input = resolveInputs(repoRoot, cfg)
input = struct();
input.sourceRunId = string(cfg.sourceRunId);

input.catalogPath = cfg.catalogPath;
if ~isabsolute(input.catalogPath)
    input.catalogPath = fullfile(repoRoot, input.catalogPath);
end
if exist(input.catalogPath, 'file') ~= 2
    error('observable_catalog.csv not found: %s', input.catalogPath);
end

input.catalogRunId = extractRunIdFromPath(fileparts(input.catalogPath));
end

function runId = extractRunIdFromPath(pathValue)
parts = split(string(strrep(pathValue, '/', filesep)), filesep);
idx = find(startsWith(parts, "run_"), 1, 'last');
if isempty(idx)
    runId = "unknown_run";
else
    runId = parts(idx);
end
end

function methods = alignmentMethods()
methods = [ ...
    struct('name', "nearest_neighbor_tol", 'kind', "nearest"), ...
    struct('name', "linear_interpolation", 'kind', "linear"), ...
    struct('name', "pchip_interpolation", 'kind', "pchip"), ...
    struct('name', "overlap_only", 'kind', "overlap"), ...
    struct('name', "linear_no_edge_extrapolation", 'kind', "linear_no_edge") ...
    ];
end

function aligned = buildAlignedDataForMethod(series, target, method, cfg)
Tx = series.X.T; Xv = series.X.V;
Tk = series.kappa.T; Kv = series.kappa.V;
Tt = series.(char(target)).T; Yv = series.(char(target)).V;

switch method.kind
    case "nearest"
        [xOnT, okX] = nearestMatch(Tx, Xv, Tt, cfg.nearestToleranceK);
        [kOnT, okK] = nearestMatch(Tk, Kv, Tt, cfg.nearestToleranceK);
        mask = okX & okK & isfinite(Yv);
        aligned = table(Tt(mask), xOnT(mask), kOnT(mask), Yv(mask), ...
            'VariableNames', {'T_K','X','kappa','target_value'});

    case "linear"
        xOnT = interp1(Tx, Xv, Tt, 'linear', NaN);
        kOnT = interp1(Tk, Kv, Tt, 'linear', NaN);
        mask = isfinite(xOnT) & isfinite(kOnT) & isfinite(Yv);
        aligned = table(Tt(mask), xOnT(mask), kOnT(mask), Yv(mask), ...
            'VariableNames', {'T_K','X','kappa','target_value'});

    case "pchip"
        xOnT = interp1(Tx, Xv, Tt, 'pchip', NaN);
        kOnT = interp1(Tk, Kv, Tt, 'pchip', NaN);
        mask = isfinite(xOnT) & isfinite(kOnT) & isfinite(Yv);
        aligned = table(Tt(mask), xOnT(mask), kOnT(mask), Yv(mask), ...
            'VariableNames', {'T_K','X','kappa','target_value'});

    case "overlap"
        tol = 1e-12;
        overlapT = Tt;
        overlapT = overlapT(hasExactTemp(overlapT, Tx, tol));
        overlapT = overlapT(hasExactTemp(overlapT, Tk, tol));
        overlapT = unique(overlapT);
        yMap = valuesAtTemps(Tt, Yv, overlapT);
        xMap = valuesAtTemps(Tx, Xv, overlapT);
        kMap = valuesAtTemps(Tk, Kv, overlapT);
        mask = isfinite(yMap) & isfinite(xMap) & isfinite(kMap);
        aligned = table(overlapT(mask), xMap(mask), kMap(mask), yMap(mask), ...
            'VariableNames', {'T_K','X','kappa','target_value'});

    case "linear_no_edge"
        tMin = max([min(Tx), min(Tk)]);
        tMax = min([max(Tx), max(Tk)]);
        interior = Tt > tMin & Tt < tMax;
        qT = Tt(interior);
        qY = Yv(interior);
        xOnT = interp1(Tx, Xv, qT, 'linear', NaN);
        kOnT = interp1(Tk, Kv, qT, 'linear', NaN);
        mask = isfinite(xOnT) & isfinite(kOnT) & isfinite(qY);
        aligned = table(qT(mask), xOnT(mask), kOnT(mask), qY(mask), ...
            'VariableNames', {'T_K','X','kappa','target_value'});

    otherwise
        aligned = table([], [], [], [], 'VariableNames', {'T_K','X','kappa','target_value'});
end

aligned = sortrows(aligned, 'T_K');
end

function [matchedValues, ok] = nearestMatch(Tsrc, Vsrc, Tquery, tol)
matchedValues = NaN(size(Tquery));
ok = false(size(Tquery));

for i = 1:numel(Tquery)
    [d, idx] = min(abs(Tsrc - Tquery(i)));
    if ~isempty(idx) && isfinite(d) && d <= tol
        matchedValues(i) = Vsrc(idx);
        ok(i) = true;
    end
end
end

function tf = hasExactTemp(Tquery, Tsrc, tol)
tf = false(size(Tquery));
for i = 1:numel(Tquery)
    tf(i) = any(abs(Tsrc - Tquery(i)) <= tol);
end
end

function outVals = valuesAtTemps(Tsrc, Vsrc, Tpick)
outVals = NaN(size(Tpick));
for i = 1:numel(Tpick)
    idx = find(abs(Tsrc - Tpick(i)) <= 1e-12, 1, 'first');
    if ~isempty(idx)
        outVals(i) = Vsrc(idx);
    end
end
end

function [T, V] = extractSeries(catalogTbl, obsName)
required = {'observable_name','temperature_K','value'};
for i = 1:numel(required)
    if ~ismember(required{i}, catalogTbl.Properties.VariableNames)
        error('Catalog missing required column: %s', required{i});
    end
end

obs = lower(strtrim(string(catalogTbl.observable_name)));
mask = obs == lower(strtrim(string(obsName)));
sub = catalogTbl(mask, :);

if isempty(sub)
    T = [];
    V = [];
    return;
end

agg = groupsummary(sub, 'temperature_K', 'mean', 'value');
T = double(agg.temperature_K);
V = double(agg.mean_value);
[T, ord] = sort(T);
V = V(ord);
end

function specs = buildModelSpecs()
specs = table( ...
    ["X_only";"X_only";"X_only";"kappa_only";"kappa_only";"kappa_only";"X_kappa";"X_kappa";"X_kappa"], ...
    ["linear";"power";"poly2";"linear";"power";"poly2";"linear";"power";"poly2"], ...
    ["X";"X";"X";"kappa";"kappa";"kappa";"X,kappa";"X,kappa";"X,kappa"], ...
    'VariableNames', {'family','model_type','predictors'});
end

function evalTbl = evaluateTargetModels(dataTbl, targetName, modelSpecs, cfg)
y = double(dataTbl.target_value);
n = height(modelSpecs);

target_observable = repmat(string(targetName), n, 1);
model = strings(n,1);
family = strings(n,1);
CV_R2 = NaN(n,1);
RMSE = NaN(n,1);

for i = 1:n
    family(i) = string(modelSpecs.family(i));
    modelType = string(modelSpecs.model_type(i));
    predNames = split(string(modelSpecs.predictors(i)), ',');
    predNames = strtrim(predNames);

    X = zeros(height(dataTbl), numel(predNames));
    for j = 1:numel(predNames)
        X(:,j) = double(dataTbl.(char(predNames(j))));
    end

    if numel(y) >= 3
        [cvR2, rmse] = runLotoCv(y, X, modelType);
    else
        cvR2 = NaN;
        rmse = NaN;
    end

    CV_R2(i) = cvR2;
    RMSE(i) = rmse;
    model(i) = family(i) + ":" + modelType;
end

evalTbl = table(target_observable, model, family, CV_R2, RMSE, ...
    'VariableNames', {'target_observable','model','family','CV_R2','RMSE'});

% If every CV_R2 is NaN due low support, keep NOT_EXPLAINED classification pathway.
if all(~isfinite(evalTbl.CV_R2)) && height(dataTbl) >= cfg.minPointsForModeling
    evalTbl.CV_R2(:) = NaN;
end
end

function [cvR2, rmse] = runLotoCv(y, X, modelType)
n = numel(y);
yhat = NaN(n,1);

for k = 1:n
    idxTrain = true(n,1);
    idxTrain(k) = false;

    yTrain = y(idxTrain);
    XTrain = X(idxTrain,:);
    xTest = X(k,:);

    yhat(k) = fitPredictSingle(yTrain, XTrain, xTest, modelType);
end

mask = isfinite(y) & isfinite(yhat);
if nnz(mask) < 3
    cvR2 = NaN;
    rmse = NaN;
    return;
end

res = y(mask) - yhat(mask);
rmse = sqrt(mean(res.^2));
ssRes = sum(res.^2);
ssTot = sum((y(mask) - mean(y(mask))).^2);
if ssTot <= eps
    cvR2 = NaN;
else
    cvR2 = 1 - ssRes / ssTot;
end
end

function yhat = fitPredictSingle(yTrain, XTrain, xTest, modelType)
yhat = NaN;

if any(~isfinite(yTrain)) || any(~isfinite(XTrain(:))) || any(~isfinite(xTest))
    return;
end

switch lower(char(modelType))
    case 'linear'
        [Phi, phiTest] = buildDesignLinear(XTrain, xTest);
        b = pinv(Phi) * yTrain;
        yhat = phiTest * b;

    case 'poly2'
        [Phi, phiTest] = buildDesignPoly2(XTrain, xTest);
        b = pinv(Phi) * yTrain;
        yhat = phiTest * b;

    case 'power'
        if any(yTrain <= 0) || any(XTrain(:) <= 0) || any(xTest <= 0)
            yhat = NaN;
            return;
        end
        z = log(yTrain);
        U = log(XTrain);
        [Phi, phiTest] = buildDesignLinear(U, log(xTest));
        b = pinv(Phi) * z;
        yhat = exp(phiTest * b);

    otherwise
        yhat = NaN;
end
end

function [Phi, phiTest] = buildDesignLinear(XTrain, xTest)
Phi = [ones(size(XTrain,1),1), XTrain];
phiTest = [1, xTest];
end

function [Phi, phiTest] = buildDesignPoly2(XTrain, xTest)
p = size(XTrain,2);
if p == 1
    x = XTrain(:,1);
    Phi = [ones(size(XTrain,1),1), x, x.^2];
    xt = xTest(1);
    phiTest = [1, xt, xt.^2];
elseif p == 2
    x1 = XTrain(:,1);
    x2 = XTrain(:,2);
    Phi = [ones(size(XTrain,1),1), x1, x2, x1.^2, x2.^2, x1.*x2];
    xt1 = xTest(1);
    xt2 = xTest(2);
    phiTest = [1, xt1, xt2, xt1.^2, xt2.^2, xt1.*xt2];
else
    Phi = [ones(size(XTrain,1),1), XTrain];
    phiTest = [1, xTest];
end
end

function [bestModel, bestCVR2, bestRMSE] = pickBestOverall(evalTbl)
if isempty(evalTbl)
    bestModel = "none";
    bestCVR2 = NaN;
    bestRMSE = NaN;
    return;
end

valid = isfinite(evalTbl.CV_R2);
if any(valid)
    sub = evalTbl(valid, :);
    [~, idx] = max(sub.CV_R2);
    bestModel = sub.model(idx);
    bestCVR2 = sub.CV_R2(idx);
    bestRMSE = sub.RMSE(idx);
else
    [~, idx] = min(evalTbl.RMSE);
    if isempty(idx) || ~isfinite(evalTbl.RMSE(idx))
        bestModel = "none";
        bestCVR2 = NaN;
        bestRMSE = NaN;
    else
        bestModel = evalTbl.model(idx);
        bestCVR2 = evalTbl.CV_R2(idx);
        bestRMSE = evalTbl.RMSE(idx);
    end
end
end

function classLabel = classifyTarget(evalTbl, cfg)
bestX = bestFamilyMetric(evalTbl, "X_only");
bestK = bestFamilyMetric(evalTbl, "kappa_only");
bestB = bestFamilyMetric(evalTbl, "X_kappa");

if isfinite(bestB) && bestB >= cfg.r2ExplainThreshold && bestB >= max(bestX, bestK) + cfg.deltaImproveThreshold
    classLabel = "EXPLAINED_BY_X_KAPPA";
elseif isfinite(bestX) && bestX >= cfg.r2ExplainThreshold && bestX >= bestK + cfg.deltaImproveThreshold && bestX >= bestB - 0.02
    classLabel = "EXPLAINED_BY_X";
elseif isfinite(bestK) && bestK >= cfg.r2ExplainThreshold && bestK >= bestX + cfg.deltaImproveThreshold && bestK >= bestB - 0.02
    classLabel = "EXPLAINED_BY_KAPPA";
elseif isfinite(bestB) && bestB >= cfg.r2ExplainThreshold
    classLabel = "EXPLAINED_BY_X_KAPPA";
else
    classLabel = "NOT_EXPLAINED_BY_BASIS";
end
end

function v = bestFamilyMetric(evalTbl, family)
sub = evalTbl(evalTbl.family == family, :);
if isempty(sub)
    v = NaN;
    return;
end
v = max(sub.CV_R2, [], 'omitnan');
if isempty(v)
    v = NaN;
end
end

function summaryTbl = buildRobustnessSummary(resultsTbl, targets, provisional)
rows = [];
for i = 1:numel(targets)
    t = targets(i);
    sub = resultsTbl(resultsTbl.target_observable == t, :);

    classes = string(sub.classification);
    allLabels = ["EXPLAINED_BY_X","EXPLAINED_BY_KAPPA","EXPLAINED_BY_X_KAPPA","NOT_EXPLAINED_BY_BASIS"];
    counts = zeros(size(allLabels));
    for j = 1:numel(allLabels)
        counts(j) = nnz(classes == allLabels(j));
    end

    [maxCount, idx] = max(counts);
    if isempty(idx) || maxCount == 0
        modeClass = "NOT_EXPLAINED_BY_BASIS";
    else
        modeClass = allLabels(idx);
    end

    nConfident = nnz(sub.n_points >= 6);
    uniqueClasses = unique(classes);

    if nConfident < 3
        status = "INCONCLUSIVE";
        notes = "Fewer than 3 alignment variants reached confident sample count (n>=6).";
    elseif numel(uniqueClasses) == 1
        status = "ROBUST";
        notes = "Classification consistent across tested alignment methods.";
    else
        status = "SENSITIVE_TO_ALIGNMENT";
        notes = "Classification changes across alignment methods.";
    end

    original = getOriginalClass(provisional, t);
    if modeClass ~= original
        notes = notes + " Most common class differs from provisional result.";
    else
        notes = notes + " Most common class matches provisional result.";
    end

    countsText = sprintf('EXPLAINED_BY_X=%d; EXPLAINED_BY_KAPPA=%d; EXPLAINED_BY_X_KAPPA=%d; NOT_EXPLAINED_BY_BASIS=%d', ...
        counts(1), counts(2), counts(3), counts(4));

    row = table(t, modeClass, status, string(countsText), string(notes), ...
        'VariableNames', {'target_observable','most_common_classification','robustness_status','classification_counts','notes'});

    rows = [rows; row]; %#ok<AGROW>
end

summaryTbl = rows;
end

function original = getOriginalClass(provisional, target)
if isfield(provisional, char(target))
    original = string(provisional.(char(target)));
else
    original = "NOT_EXPLAINED_BY_BASIS";
end
end

function txt = buildReport(resultsTbl, summaryTbl, methods, input, runDir, cfg)
lines = strings(0,1);
lines(end+1) = '# Observable Basis Sufficiency Robustness Audit';
lines(end+1) = '';
lines(end+1) = 'Generated: ' + string(stampNow());
lines(end+1) = 'Source run: `' + string(cfg.sourceRunId) + '`';
lines(end+1) = 'Catalog file: `' + string(input.catalogPath) + '`';
lines(end+1) = 'Run dir: `' + string(runDir) + '`';
lines(end+1) = '';

lines(end+1) = '## 1. Original provisional result';
lines(end+1) = '- `A`: EXPLAINED_BY_X';
lines(end+1) = '- `chi_ridge`: EXPLAINED_BY_X';
lines(end+1) = '- `χ_amp(T)` (legacy: `a1`): EXPLAINED_BY_X_KAPPA';
lines(end+1) = '- `R`: NOT_EXPLAINED_BY_BASIS';
lines(end+1) = '';

lines(end+1) = '## 2. Alignment methods tested';
for i = 1:numel(methods)
    lines(end+1) = '- `' + methods(i).name + '`';
end
lines(end+1) = '- No extrapolation beyond predictor support ranges was allowed.';
lines(end+1) = '';

lines(end+1) = '## 3. Per-target robustness';
for i = 1:height(summaryTbl)
    lines(end+1) = '- `' + string(summaryTbl.target_observable(i)) + ...
        '` => mode: ' + string(summaryTbl.most_common_classification(i)) + ...
        ', status: ' + string(summaryTbl.robustness_status(i)) + ...
        ', counts: ' + string(summaryTbl.classification_counts(i));
    lines(end+1) = '  Note: ' + string(summaryTbl.notes(i));
end
lines(end+1) = '';

lines(end+1) = '## 4. Which conclusions are robust';
robust = summaryTbl(summaryTbl.robustness_status == "ROBUST", :);
if isempty(robust)
    lines(end+1) = '- None';
else
    for i = 1:height(robust)
        lines(end+1) = '- `' + string(robust.target_observable(i)) + '` => `' + string(robust.most_common_classification(i)) + '`';
    end
end
lines(end+1) = '';

lines(end+1) = '## 5. Which conclusions remain uncertain';
unc = summaryTbl(summaryTbl.robustness_status ~= "ROBUST", :);
if isempty(unc)
    lines(end+1) = '- None';
else
    for i = 1:height(unc)
        lines(end+1) = '- `' + string(unc.target_observable(i)) + '` => `' + string(unc.robustness_status(i)) + '`';
    end
end
lines(end+1) = '';

lines(end+1) = '## 6. Recommended final interpretation';
lines(end+1) = '- ' + recommendFinalInterpretation(summaryTbl);

txt = strjoin(lines, newline);
end

function s = recommendFinalInterpretation(summaryTbl)
robust = summaryTbl(summaryTbl.robustness_status == "ROBUST", :);
sensitive = summaryTbl(summaryTbl.robustness_status == "SENSITIVE_TO_ALIGNMENT", :);
inconclusive = summaryTbl(summaryTbl.robustness_status == "INCONCLUSIVE", :);

if height(inconclusive) == 0 && height(sensitive) == 0
    s = "All target classifications are robust across tested alignments; treat the original provisional basis conclusion as stable.";
elseif height(inconclusive) > 0 && height(robust) == 0
    s = "Evidence is insufficient for a stable two-coordinate conclusion; retain provisional interpretation and prioritize denser matched temperature coverage.";
else
    s = "Adopt robust target-level conclusions, but treat sensitive or inconclusive targets as provisional due to alignment dependence and sample support limits.";
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

zip(zipPath, { ...
    fullfile('tables', 'basis_sufficiency_robustness_results.csv'), ...
    fullfile('tables', 'basis_sufficiency_robustness_summary.csv'), ...
    fullfile('reports', 'observable_basis_sufficiency_robustness_report.md'), ...
    'run_manifest.json', ...
    'config_snapshot.m', ...
    'log.txt', ...
    'run_notes.txt' ...
    }, runDir);
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

function tf = isabsolute(p)
p = char(string(p));
tf = ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
end
