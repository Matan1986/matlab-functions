function out = observable_basis_sufficiency_test(cfg)
% observable_basis_sufficiency_test
% Test whether X(T) and kappa(T) are sufficient coordinates to explain
% A(T), R(T), chi_ridge(T), and a1(T) using existing catalog data only.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg);
input = resolveInputFiles(repoRoot, cfg);

catalogTbl = readtable(input.catalogPath, 'TextType', 'string');
minimalTbl = readtable(input.minimalSetPath, 'TextType', 'string');

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
runCfg.dataset = sprintf('catalog_source:%s', input.catalogRunId);
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;

appendText(run.log_path, sprintf('[%s] basis sufficiency test started\n', stampNow()));
appendText(run.log_path, sprintf('catalog_path: %s\n', input.catalogPath));
appendText(run.log_path, sprintf('minimal_set_path: %s\n', input.minimalSetPath));

targets = string(cfg.targetObservables(:));
modelSpecs = buildModelSpecs();

modelRows = [];
importanceRows = [];
allAlignedRows = [];

for i = 1:numel(targets)
    yName = targets(i);

    targetTbl = buildTargetAlignedTable(catalogTbl, yName);
    appendText(run.log_path, sprintf('target=%s aligned_rows=%d\n', char(yName), height(targetTbl)));

    if height(targetTbl) < 6
        evalTbl = emptyEvalRowsForTarget(yName, modelSpecs);
        classLabel = "NOT_EXPLAINED_BY_BASIS";
        evalTbl.classification = repmat(classLabel, height(evalTbl), 1);

        impRow = table( ...
            yName, NaN, NaN, NaN, NaN, ...
            'VariableNames', {'observable','corr_with_X','corr_with_kappa','added_value_of_kappa','added_value_of_X'});

        modelRows = [modelRows; evalTbl]; %#ok<AGROW>
        importanceRows = [importanceRows; impRow]; %#ok<AGROW>
        continue;
    end

    y = double(targetTbl.target_value);
    X = double(targetTbl.X);
    K = double(targetTbl.kappa);

    evalTbl = evaluateTargetModels(targetTbl, yName, modelSpecs);
    classLabel = classifyTarget(evalTbl, cfg);
    evalTbl.classification = repmat(classLabel, height(evalTbl), 1);

    bestX = bestModelForFamily(evalTbl, "X_only");
    bestK = bestModelForFamily(evalTbl, "kappa_only");

    resX = y - bestX.yhat_full;
    resK = y - bestK.yhat_full;

    addedK = corrSafe(resX, K);
    addedX = corrSafe(resK, X);

    impRow = table( ...
        yName, ...
        corrSafe(y, X), ...
        corrSafe(y, K), ...
        addedK, ...
        addedX, ...
        'VariableNames', {'observable','corr_with_X','corr_with_kappa','added_value_of_kappa','added_value_of_X'});

    modelRows = [modelRows; evalTbl]; %#ok<AGROW>
    importanceRows = [importanceRows; impRow]; %#ok<AGROW>

    alignedRows = table( ...
        repmat(yName, height(targetTbl), 1), ...
        targetTbl.T_K, targetTbl.X, targetTbl.kappa, targetTbl.target_value, ...
        'VariableNames', {'target_observable','T_K','X','kappa','target_value'});
    allAlignedRows = [allAlignedRows; alignedRows]; %#ok<AGROW>
end

resultsTbl = modelRows(:, {'target_observable','model','CV_R2','RMSE','classification'});
importanceTbl = importanceRows;

resultsPath = save_run_table(resultsTbl, 'basis_sufficiency_results.csv', runDir);
importancePath = save_run_table(importanceTbl, 'basis_coordinate_importance.csv', runDir);
alignedPath = save_run_table(allAlignedRows, 'basis_sufficiency_aligned_data.csv', runDir);

reportText = buildReportText(minimalTbl, resultsTbl, importanceTbl, allAlignedRows, input, runDir);
reportPath = save_run_report(reportText, 'observable_basis_sufficiency_report.md', runDir);

zipPath = buildReviewZip(runDir, 'observable_basis_sufficiency_bundle.zip');

appendText(run.log_path, sprintf('results_table: %s\n', resultsPath));
appendText(run.log_path, sprintf('importance_table: %s\n', importancePath));
appendText(run.log_path, sprintf('aligned_table: %s\n', alignedPath));
appendText(run.log_path, sprintf('report: %s\n', reportPath));
appendText(run.log_path, sprintf('bundle: %s\n', zipPath));
appendText(run.log_path, sprintf('[%s] basis sufficiency test complete\n', stampNow()));

summary = summarizeClassifications(resultsTbl, targets);

fprintf('RUN_ID=%s\n', run.run_id);
fprintf('Number_of_targets_tested=%d\n', numel(targets));
fprintf('Observables_explained_by_X=%s\n', strjoin(cellstr(summary.byX), ', '));
fprintf('Observables_explained_by_kappa=%s\n', strjoin(cellstr(summary.byKappa), ', '));
fprintf('Observables_explained_by_X_kappa=%s\n', strjoin(cellstr(summary.byBoth), ', '));
fprintf('Observables_not_explained=%s\n', strjoin(cellstr(summary.notExplained), ', '));

out = struct();
out.run = run;
out.targets = targets;
out.classificationSummary = summary;
out.paths = struct( ...
    'results', string(resultsPath), ...
    'importance', string(importancePath), ...
    'aligned', string(alignedPath), ...
    'report', string(reportPath), ...
    'bundle', string(zipPath));
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'observable_basis_sufficiency_test');
cfg = setDefault(cfg, 'catalogPath', '');
cfg = setDefault(cfg, 'minimalSetPath', fullfile('results', 'cross_experiment', 'runs', ...
    'run_2026_03_16_145120_observable_physics_reduction', 'tables', 'minimal_observable_set.csv'));
cfg = setDefault(cfg, 'requiredObservables', {'X','kappa','A','R','chi_ridge','a1'});
cfg = setDefault(cfg, 'targetObservables', {'A','R','chi_ridge','a1'});
cfg = setDefault(cfg, 'r2ExplainThreshold', 0.50);
cfg = setDefault(cfg, 'deltaImproveThreshold', 0.05);
end

function input = resolveInputFiles(repoRoot, cfg)
input = struct();

input.minimalSetPath = cfg.minimalSetPath;
if ~isabsolute(input.minimalSetPath)
    input.minimalSetPath = fullfile(repoRoot, input.minimalSetPath);
end
if exist(input.minimalSetPath, 'file') ~= 2
    error('minimal_observable_set.csv not found: %s', input.minimalSetPath);
end

if strlength(strtrim(string(cfg.catalogPath))) > 0
    input.catalogPath = cfg.catalogPath;
    if ~isabsolute(input.catalogPath)
        input.catalogPath = fullfile(repoRoot, input.catalogPath);
    end
else
    [input.catalogPath, input.catalogRunId] = resolveCatalogPath(repoRoot, input.minimalSetPath);
end

if exist(input.catalogPath, 'file') ~= 2
    error('observable_catalog.csv not found: %s', input.catalogPath);
end

if ~isfield(input, 'catalogRunId') || strlength(input.catalogRunId) == 0
    input.catalogRunId = extractRunIdFromPath(fileparts(input.catalogPath));
end
end

function [catalogPath, runId] = resolveCatalogPath(repoRoot, minimalSetPath)
catalogPath = '';
runId = "";

reductionRunDir = fileparts(fileparts(minimalSetPath));
reportPath = fullfile(reductionRunDir, 'reports', 'observable_physics_reduction_report.md');
if exist(reportPath, 'file') == 2
    txt = fileread(reportPath);
    tok = regexp(txt, 'Catalog file:\s*`([^`]+)`', 'tokens', 'once');
    if ~isempty(tok)
        catalogPath = tok{1};
        runId = extractRunIdFromPath(fileparts(catalogPath));
    end
end

if isempty(catalogPath) || exist(catalogPath, 'file') ~= 2
    candidates = dir(fullfile(repoRoot, 'results', 'cross_experiment', 'runs', 'run_*', 'tables', 'observable_catalog.csv'));
    if isempty(candidates)
        error('No observable_catalog.csv found under cross_experiment run tables.');
    end
    runIds = strings(numel(candidates),1);
    for i = 1:numel(candidates)
        runIds(i) = extractRunIdFromPath(candidates(i).folder);
    end
    [~, ord] = sort(runIds, 'descend');
    pick = candidates(ord(1));
    catalogPath = fullfile(pick.folder, pick.name);
    runId = runIds(ord(1));
end
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

function wideTbl = buildAlignedWideTable(catalogTbl, obsNames)
required = {'observable_name','temperature_K','value'};
for i = 1:numel(required)
    if ~ismember(required{i}, catalogTbl.Properties.VariableNames)
        error('Catalog missing required column: %s', required{i});
    end
end

obsMask = ismember(lower(strtrim(string(catalogTbl.observable_name))), lower(strtrim(string(obsNames))));
sub = catalogTbl(obsMask, :);

if isempty(sub)
    error('No required observables found in catalog.');
end

obsNorm = string(sub.observable_name);
for i = 1:numel(obsNames)
    m = lower(strtrim(obsNorm)) == lower(strtrim(string(obsNames{i})));
    obsNorm(m) = string(obsNames{i});
end
sub.observable_name = obsNorm;

agg = groupsummary(sub, {'temperature_K','observable_name'}, 'mean', 'value');
agg.value = agg.mean_value;
agg.mean_value = [];

wideTbl = unstack(agg(:, {'temperature_K','observable_name','value'}), 'value', 'observable_name');
wideTbl = sortrows(wideTbl, 'temperature_K');
wideTbl.Properties.VariableNames{strcmp(wideTbl.Properties.VariableNames, 'temperature_K')} = 'T_K';
end

function tbl = buildTargetAlignedTable(catalogTbl, targetName)
[Tx, Xv] = extractSeries(catalogTbl, "X");
[Tk, Kv] = extractSeries(catalogTbl, "kappa");
[Tt, Yv] = extractSeries(catalogTbl, targetName);

if isempty(Tx) || isempty(Tk) || isempty(Tt)
    tbl = table([], [], [], [], 'VariableNames', {'T_K','X','kappa','target_value'});
    return;
end

xOnT = interp1(Tx, Xv, Tt, 'linear', NaN);
kOnT = interp1(Tk, Kv, Tt, 'linear', NaN);

mask = isfinite(Tt) & isfinite(Yv) & isfinite(xOnT) & isfinite(kOnT);
tbl = table(Tt(mask), xOnT(mask), kOnT(mask), Yv(mask), ...
    'VariableNames', {'T_K','X','kappa','target_value'});
tbl = sortrows(tbl, 'T_K');
end

function [T, V] = extractSeries(catalogTbl, obsName)
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

function evalTbl = emptyEvalRowsForTarget(yName, modelSpecs)
n = height(modelSpecs);
target_observable = repmat(string(yName), n, 1);
model = strings(n,1);
family = strings(n,1);
CV_R2 = NaN(n,1);
RMSE = NaN(n,1);
yhat_full_cell = cell(n,1);

for i = 1:n
    family(i) = string(modelSpecs.family(i));
    modelType = string(modelSpecs.model_type(i));
    model(i) = family(i) + ":" + modelType;
    yhat_full_cell{i} = NaN;
end

evalTbl = table(target_observable, model, family, CV_R2, RMSE, yhat_full_cell, ...
    'VariableNames', {'target_observable','model','family','CV_R2','RMSE','yhat_full'});
end

function specs = buildModelSpecs()
specs = table( ...
    ["X_only";"X_only";"X_only";"kappa_only";"kappa_only";"kappa_only";"X_kappa";"X_kappa";"X_kappa"], ...
    ["linear";"power";"poly2";"linear";"power";"poly2";"linear";"power";"poly2"], ...
    ["X";"X";"X";"kappa";"kappa";"kappa";"X,kappa";"X,kappa";"X,kappa"], ...
    'VariableNames', {'family','model_type','predictors'});
end

function evalTbl = evaluateTargetModels(dataTbl, yName, modelSpecs)
y = double(dataTbl.target_value);
n = height(modelSpecs);

target_observable = repmat(string(yName), n, 1);
model = strings(n,1);
family = strings(n,1);
CV_R2 = NaN(n,1);
RMSE = NaN(n,1);
yhat_full_cell = cell(n,1);

for i = 1:n
    family(i) = string(modelSpecs.family(i));
    modelType = string(modelSpecs.model_type(i));
    predNames = split(string(modelSpecs.predictors(i)), ',');
    predNames = strtrim(predNames);
    model(i) = family(i) + ":" + modelType;

    X = zeros(height(dataTbl), numel(predNames));
    for j = 1:numel(predNames)
        X(:,j) = double(dataTbl.(char(predNames(j))));
    end

    [cvR2, rmse, yhat] = runLotoCv(y, X, modelType);
    CV_R2(i) = cvR2;
    RMSE(i) = rmse;
    yhat_full_cell{i} = yhat;
end

evalTbl = table(target_observable, model, family, CV_R2, RMSE, yhat_full_cell, ...
    'VariableNames', {'target_observable','model','family','CV_R2','RMSE','yhat_full'});
end

function [cvR2, rmse, yhatCv] = runLotoCv(y, X, modelType)
n = numel(y);
yhatCv = NaN(n,1);

for k = 1:n
    idxTrain = true(n,1);
    idxTrain(k) = false;

    yTrain = y(idxTrain);
    XTrain = X(idxTrain,:);
    xTest = X(k,:);

    yhatCv(k) = fitPredictSingle(yTrain, XTrain, xTest, modelType);
end

mask = isfinite(y) & isfinite(yhatCv);
if nnz(mask) < 3
    cvR2 = NaN;
    rmse = NaN;
    return;
end

res = y(mask) - yhatCv(mask);
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

function best = bestModelForFamily(evalTbl, familyName)
sub = evalTbl(evalTbl.family == familyName, :);
if isempty(sub)
    best = struct('yhat_full', NaN(height(evalTbl),1));
    return;
end

[~, idx] = max(sub.CV_R2);
if isempty(idx) || ~isfinite(sub.CV_R2(idx))
    [~, idx] = min(sub.RMSE);
end

best = struct();
best.yhat_full = sub.yhat_full{idx};
best.CV_R2 = sub.CV_R2(idx);
best.RMSE = sub.RMSE(idx);
best.model = sub.model(idx);
end

function classLabel = classifyTarget(evalTbl, cfg)
bestX = bestMetric(evalTbl, "X_only");
bestK = bestMetric(evalTbl, "kappa_only");
bestB = bestMetric(evalTbl, "X_kappa");

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

function val = bestMetric(evalTbl, familyName)
sub = evalTbl(evalTbl.family == familyName, :);
if isempty(sub)
    val = NaN;
    return;
end
val = max(sub.CV_R2, [], 'omitnan');
if isempty(val)
    val = NaN;
end
end

function summary = summarizeClassifications(resultsTbl, targets)
summary = struct();
targetStr = string(targets(:));

classPerTarget = strings(numel(targetStr),1);
for i = 1:numel(targetStr)
    rows = resultsTbl(resultsTbl.target_observable == targetStr(i), :);
    if isempty(rows)
        classPerTarget(i) = "NOT_EXPLAINED_BY_BASIS";
    else
        classPerTarget(i) = rows.classification(1);
    end
end

summary.byX = targetStr(classPerTarget == "EXPLAINED_BY_X");
summary.byKappa = targetStr(classPerTarget == "EXPLAINED_BY_KAPPA");
summary.byBoth = targetStr(classPerTarget == "EXPLAINED_BY_X_KAPPA");
summary.notExplained = targetStr(classPerTarget == "NOT_EXPLAINED_BY_BASIS");
end

function textOut = buildReportText(minimalTbl, resultsTbl, importanceTbl, dataTbl, input, runDir)
targets = unique(string(resultsTbl.target_observable), 'stable');
summary = summarizeClassifications(resultsTbl, targets);

line = strings(0,1);
line(end+1) = '# Observable Basis Sufficiency Test';
line(end+1) = '';
line(end+1) = 'Generated: ' + string(stampNow());
line(end+1) = 'Catalog source: `' + string(input.catalogPath) + '`';
line(end+1) = 'Minimal set source: `' + string(input.minimalSetPath) + '`';
line(end+1) = 'Run dir: `' + string(runDir) + '`';
line(end+1) = '';

line(end+1) = '## Tested observables';
for i = 1:numel(targets)
    line(end+1) = '- `' + targets(i) + '`';
end
line(end+1) = '';

line(end+1) = '## Model performance';
for i = 1:height(resultsTbl)
    line(end+1) = '- `' + string(resultsTbl.target_observable(i)) + '` | ' + string(resultsTbl.model(i)) + ...
        ': CV_R2=' + sprintf('%.4f', resultsTbl.CV_R2(i)) + ', RMSE=' + sprintf('%.4g', resultsTbl.RMSE(i));
end
line(end+1) = '';

line(end+1) = '## Added-value analysis';
for i = 1:height(importanceTbl)
    line(end+1) = '- `' + string(importanceTbl.observable(i)) + ...
        '`: corr_with_X=' + sprintf('%.4f', importanceTbl.corr_with_X(i)) + ...
        ', corr_with_kappa=' + sprintf('%.4f', importanceTbl.corr_with_kappa(i)) + ...
        ', added_value_of_kappa=' + sprintf('%.4f', importanceTbl.added_value_of_kappa(i)) + ...
        ', added_value_of_X=' + sprintf('%.4f', importanceTbl.added_value_of_X(i));
end
line(end+1) = '';

line(end+1) = '## Observables explained by X';
if isempty(summary.byX)
    line(end+1) = '- None';
else
    for i = 1:numel(summary.byX), line(end+1) = '- `' + summary.byX(i) + '`'; end
end
line(end+1) = '';

line(end+1) = '## Observables explained by kappa';
if isempty(summary.byKappa)
    line(end+1) = '- None';
else
    for i = 1:numel(summary.byKappa), line(end+1) = '- `' + summary.byKappa(i) + '`'; end
end
line(end+1) = '';

line(end+1) = '## Observables requiring additional coordinates';
if isempty(summary.notExplained)
    line(end+1) = '- None';
else
    for i = 1:numel(summary.notExplained), line(end+1) = '- `' + summary.notExplained(i) + '`'; end
end
line(end+1) = '';

line(end+1) = '## Conclusion';
if isempty(summary.notExplained)
    line(end+1) = '- Within this catalog-aligned dataset, X and kappa are sufficient to explain all tested targets under simple model families.';
else
    line(end+1) = '- X and kappa explain part of the target space, but at least one target remains not explained by this 2-coordinate basis under simple models.';
end
line(end+1) = '- This test is constrained to existing catalog values and does not recompute any observable.';
line(end+1) = '- Leave-one-temperature-out CV was used for all model families.';
line(end+1) = '';

line(end+1) = '## Alignment details';
line(end+1) = '- Complete aligned rows used: `' + string(height(dataTbl)) + '`';
line(end+1) = '- Basis coordinates tested: `X(T)`, `kappa(T)`';
line(end+1) = '- Targets tested: `A(T)`, `R(T)`, `chi_ridge(T)`, `a1(T)`';
line(end+1) = '';

line(end+1) = '## Minimal basis reference';
for i = 1:height(minimalTbl)
    line(end+1) = '- `' + string(minimalTbl.observable_name(i)) + '` (' + string(minimalTbl.experiment(i)) + ')';
end

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

zip(zipPath, { ...
    fullfile('tables', 'basis_sufficiency_results.csv'), ...
    fullfile('tables', 'basis_coordinate_importance.csv'), ...
    fullfile('tables', 'basis_sufficiency_aligned_data.csv'), ...
    fullfile('reports', 'observable_basis_sufficiency_report.md'), ...
    'run_manifest.json', ...
    'config_snapshot.m', ...
    'log.txt', ...
    'run_notes.txt' ...
    }, runDir);
end

function c = corrSafe(a, b)
a = double(a(:));
b = double(b(:));
mask = isfinite(a) & isfinite(b);
if nnz(mask) < 3
    c = NaN;
    return;
end
c = corr(a(mask), b(mask), 'Type', 'Pearson', 'Rows', 'complete');
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