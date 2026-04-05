function out = run_kappa2_operational_signature_test(cfg)
% run_kappa2_operational_signature_test
% Search for weak operational signatures of kappa2(T) from switching-map
% derived observables.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

cfg = applyDefaults(cfg, repoRoot);

samplesTbl = readtable(cfg.switchingSamplesCsv, 'VariableNamingRule', 'preserve');
kappaTbl = readtable(cfg.kappa2TableCsv, 'VariableNamingRule', 'preserve');

obsTbl = buildObservableTable(samplesTbl, cfg);
k2Tbl = table( ...
    numericColumn(kappaTbl, ["T_K", "T"]), ...
    numericColumn(kappaTbl, ["kappa2_M3", "kappa2"]), ...
    'VariableNames', {'T_K', 'kappa2'});

merged = outerjoin(obsTbl, k2Tbl, 'Keys', 'T_K', 'MergeKeys', true, 'Type', 'left');
merged = sortrows(merged, 'T_K');

featureNames = { ...
    'antisymmetric_area', ...
    'slope_asymmetry', ...
    'local_curvature_imbalance', ...
    'center_vs_tail_difference'};

rows = table();
for i = 1:numel(featureNames)
    fn = featureNames{i};
    row = evaluateModel(merged, {fn}, sprintf('%s', fn), 'single');
    rows = [rows; row]; %#ok<AGROW>
end

pairIdx = nchoosek(1:numel(featureNames), 2);
for i = 1:size(pairIdx, 1)
    f1 = featureNames{pairIdx(i, 1)};
    f2 = featureNames{pairIdx(i, 2)};
    row = evaluateModel(merged, {f1, f2}, sprintf('%s + %s', f1, f2), 'pair');
    rows = [rows; row]; %#ok<AGROW>
end

rows = sortrows(rows, {'loocv_rmse', 'rmse_ratio_vs_baseline'}, {'ascend', 'ascend'});

singleRows = rows(rows.model_type == "single", :);
[bestSingleRmse, iBestSingle] = min(singleRows.loocv_rmse, [], 'omitnan');
if isempty(iBestSingle) || ~isfinite(bestSingleRmse)
    bestSingleName = "none";
    bestSinglePearson = NaN;
    bestSingleSpearman = NaN;
else
    bestSingleName = string(singleRows.model_name(iBestSingle));
    bestSinglePearson = singleRows.pearson(iBestSingle);
    bestSingleSpearman = singleRows.spearman(iBestSingle);
end

baseRef = min(rows.baseline_rmse, [], 'omitnan');
bestRef = min(rows.loocv_rmse, [], 'omitnan');
if ~(isfinite(baseRef) && isfinite(bestRef) && baseRef > 0)
    improvementFrac = NaN;
else
    improvementFrac = (baseRef - bestRef) / baseRef;
end

bestCorr = max(abs([bestSinglePearson, bestSingleSpearman]), [], 'omitnan');
if ~isfinite(bestCorr)
    bestCorr = NaN;
end

if isfinite(improvementFrac) && improvementFrac >= cfg.yesImprovementThreshold && ...
        isfinite(bestCorr) && bestCorr >= cfg.yesCorrelationThreshold
    verdict = "YES";
elseif isfinite(improvementFrac) && improvementFrac >= cfg.partialImprovementThreshold && ...
        isfinite(bestCorr) && bestCorr >= cfg.partialCorrelationThreshold
    verdict = "PARTIAL";
else
    verdict = "NO";
end

tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

resultCsvPath = fullfile(tablesDir, 'kappa2_operational_signature.csv');
writetable(rows, resultCsvPath);

reportPath = fullfile(reportsDir, 'kappa2_operational_signature.md');
reportText = buildReport(rows, merged, featureNames, verdict, bestSingleName, improvementFrac, cfg);
writeText(reportPath, reportText);

fprintf('\n=== kappa2 operational signature test complete ===\n');
fprintf('table: %s\n', resultCsvPath);
fprintf('report: %s\n', reportPath);
fprintf('KAPPA2_OPERATIONAL_SIGNATURE_FOUND: %s\n', verdict);
fprintf('BEST_SIGNATURE_VARIABLE: %s\n\n', bestSingleName);

out = struct();
out.tablePath = string(resultCsvPath);
out.reportPath = string(reportPath);
out.rows = rows;
out.aligned = merged;
out.verdict = struct( ...
    'KAPPA2_OPERATIONAL_SIGNATURE_FOUND', char(verdict), ...
    'BEST_SIGNATURE_VARIABLE', char(bestSingleName));
out.metrics = struct( ...
    'best_improvement_fraction', improvementFrac, ...
    'best_single_correlation_abs', bestCorr);
end

function cfg = applyDefaults(cfg, repoRoot)
cfg = setDefault(cfg, 'switchingSamplesCsv', fullfile(switchingCanonicalRunRoot(repoRoot), ...
    'run_2026_03_10_112659_alignment_audit', 'alignment_audit', 'switching_alignment_samples.csv'));
cfg = setDefault(cfg, 'kappa2TableCsv', fullfile(repoRoot, 'tables', 'closure_metrics_per_temperature.csv'));
cfg = setDefault(cfg, 'centerWindow_mA', 5.0);
cfg = setDefault(cfg, 'tailWindow_mA', 10.0);
cfg = setDefault(cfg, 'curvatureWindow_mA', 10.0);
cfg = setDefault(cfg, 'minRowsPerModel', 6);
cfg = setDefault(cfg, 'yesImprovementThreshold', 0.10);
cfg = setDefault(cfg, 'yesCorrelationThreshold', 0.40);
cfg = setDefault(cfg, 'partialImprovementThreshold', 0.03);
cfg = setDefault(cfg, 'partialCorrelationThreshold', 0.25);
end

function tbl = buildObservableTable(samplesTbl, cfg)
Traw = numericColumn(samplesTbl, ["T_K", "T"]);
Iraw = numericColumn(samplesTbl, ["current_mA", "I_mA", "I"]);
Sraw = numericColumn(samplesTbl, ["S_percent", "S", "switching_percent"]);

ok = isfinite(Traw) & isfinite(Iraw) & isfinite(Sraw);
Traw = Traw(ok);
Iraw = Iraw(ok);
Sraw = Sraw(ok);
Tclean = round(Traw);

temps = unique(Tclean, 'sorted');

tbl = table();
for it = 1:numel(temps)
    t0 = temps(it);
    mT = abs(Tclean - t0) < 1e-9;
    if ~any(mT)
        continue;
    end
    I = Iraw(mT);
    S = Sraw(mT);
    [Iu, ~, gi] = unique(I, 'sorted');
    Su = accumarray(gi, S, [], @(x) mean(x, 'omitnan'));
    if numel(Iu) < 5
        continue;
    end
    obs = deriveShapeObservables(Iu(:), Su(:), cfg);
    row = table(t0, obs.antisymmetric_area, obs.slope_asymmetry, ...
        obs.local_curvature_imbalance, obs.center_vs_tail_difference, ...
        'VariableNames', {'T_K', 'antisymmetric_area', 'slope_asymmetry', ...
        'local_curvature_imbalance', 'center_vs_tail_difference'});
    tbl = [tbl; row]; %#ok<AGROW>
end
end

function obs = deriveShapeObservables(I, S, cfg)
obs = struct('antisymmetric_area', NaN, 'slope_asymmetry', NaN, ...
    'local_curvature_imbalance', NaN, 'center_vs_tail_difference', NaN);

m = isfinite(I) & isfinite(S);
I = I(m);
S = S(m);
if numel(I) < 5
    return;
end
[I, io] = sort(I, 'ascend');
S = S(io);

[sPeak, iPeak] = max(S);
if ~(isfinite(sPeak) && isfinite(iPeak) && iPeak >= 1)
    return;
end
Ipk = I(iPeak);
x = I - Ipk;
y = S - min(S, [], 'omitnan');
y = max(y, 0);

left = x < 0;
right = x > 0;
if nnz(left) >= 2 && nnz(right) >= 2
    aL = trapz(-x(left), y(left));
    aR = trapz(x(right), y(right));
    obs.antisymmetric_area = (aR - aL) / max(aR + aL, eps);
end

dy = gradient(S, I);
if nnz(left) >= 2 && nnz(right) >= 2
    lMag = mean(abs(dy(left)), 'omitnan');
    rMag = mean(abs(dy(right)), 'omitnan');
    obs.slope_asymmetry = (rMag - lMag) / max(rMag + lMag, eps);
end

d2 = gradient(dy, I);
near = abs(x) <= cfg.curvatureWindow_mA;
leftNear = left & near;
rightNear = right & near;
if nnz(leftNear) >= 2 && nnz(rightNear) >= 2
    cL = trapz(-x(leftNear), abs(d2(leftNear)));
    cR = trapz(x(rightNear), abs(d2(rightNear)));
    obs.local_curvature_imbalance = (cR - cL) / max(cR + cL, eps);
end

center = abs(x) <= cfg.centerWindow_mA;
tail = abs(x) >= cfg.tailWindow_mA;
if nnz(center) >= 2 && nnz(tail) >= 2
    cMean = mean(S(center), 'omitnan');
    tMean = mean(S(tail), 'omitnan');
    obs.center_vs_tail_difference = (cMean - tMean) / max(abs(sPeak), eps);
end
end

function row = evaluateModel(merged, featureList, modelName, modelType)
y = merged.kappa2;
nFeat = numel(featureList);
X = NaN(height(merged), nFeat);
for i = 1:nFeat
    X(:, i) = merged.(featureList{i});
end

ok = isfinite(y);
for i = 1:nFeat
    ok = ok & isfinite(X(:, i));
end
yv = y(ok);
Xv = X(ok, :);
n = numel(yv);

pearsonVal = NaN;
spearmanVal = NaN;
rmseModel = NaN;
rmseBase = NaN;
rmseRatio = NaN;
rmseGain = NaN;

if n >= 2
    if nFeat == 1
        pearsonVal = safePearson(Xv(:, 1), yv);
        spearmanVal = safeSpearman(Xv(:, 1), yv);
    else
        yHatFit = fitPredictLinear(Xv, yv, Xv);
        pearsonVal = safePearson(yHatFit, yv);
        spearmanVal = safeSpearman(yHatFit, yv);
    end
end

if n >= 6
    yHatLoo = NaN(n, 1);
    yHatBase = NaN(n, 1);
    for i = 1:n
        idxTrain = true(n, 1);
        idxTrain(i) = false;
        Xtr = Xv(idxTrain, :);
        ytr = yv(idxTrain);
        xte = Xv(i, :);
        yHatLoo(i) = fitPredictLinear(Xtr, ytr, xte);
        yHatBase(i) = mean(ytr, 'omitnan');
    end
    rmseModel = sqrt(mean((yv - yHatLoo).^2, 'omitnan'));
    rmseBase = sqrt(mean((yv - yHatBase).^2, 'omitnan'));
    rmseRatio = rmseModel / max(rmseBase, eps);
    rmseGain = rmseBase - rmseModel;
end

row = table(string(modelType), string(modelName), n, pearsonVal, spearmanVal, ...
    rmseModel, rmseBase, rmseRatio, rmseGain, ...
    'VariableNames', {'model_type', 'model_name', 'n', 'pearson', 'spearman', ...
    'loocv_rmse', 'baseline_rmse', 'rmse_ratio_vs_baseline', 'rmse_gain_vs_baseline'});
end

function yHat = fitPredictLinear(Xtr, ytr, Xte)
Xtr = [ones(size(Xtr, 1), 1), Xtr];
beta = Xtr \ ytr;
Xte = [ones(size(Xte, 1), 1), Xte];
yHat = Xte * beta;
end

function v = safePearson(a, b)
m = isfinite(a) & isfinite(b);
if nnz(m) < 2
    v = NaN;
    return;
end
x = a(m);
y = b(m);
if std(x, 'omitnan') < 1e-14 || std(y, 'omitnan') < 1e-14
    v = NaN;
    return;
end
R = corrcoef(x, y);
v = R(1, 2);
end

function v = safeSpearman(a, b)
m = isfinite(a) & isfinite(b);
if nnz(m) < 2
    v = NaN;
    return;
end
v = corr(a(m), b(m), 'Type', 'Spearman', 'rows', 'complete');
end

function report = buildReport(rows, merged, featureNames, verdict, bestSingleName, improvementFrac, cfg)
alignedN = nnz(isfinite(merged.kappa2));

lines = strings(0, 1);
lines(end+1) = "# Kappa2 operational signature search";
lines(end+1) = "";
lines(end+1) = "## Inputs";
lines(end+1) = "- Switching map source: `" + string(cfg.switchingSamplesCsv) + "`";
lines(end+1) = "- Kappa2 source: `" + string(cfg.kappa2TableCsv) + "` (`kappa2_M3` fallback `kappa2`)";
lines(end+1) = "- Aligned temperatures with finite kappa2: **" + string(alignedN) + "**";
lines(end+1) = "";
lines(end+1) = "## Candidate observables";
for i = 1:numel(featureNames)
    lines(end+1) = "- `" + string(featureNames{i}) + "`";
end
lines(end+1) = "";
lines(end+1) = "## Model tests";
lines(end+1) = "- Tested all single-variable models and all 2-variable combinations (linear with intercept).";
lines(end+1) = "- Metrics per row: Pearson, Spearman, LOOCV RMSE, baseline RMSE, and RMSE gain.";
lines(end+1) = "- Full metric table: `tables/kappa2_operational_signature.csv`.";
lines(end+1) = "";
lines(end+1) = "## Best result snapshot";
if height(rows) > 0
    top = rows(1, :);
    lines(end+1) = "- Best model by LOOCV RMSE: `" + top.model_name + "`";
    lines(end+1) = "- Best LOOCV RMSE: **" + sprintf('%.6f', top.loocv_rmse) + "**";
    lines(end+1) = "- Baseline RMSE: **" + sprintf('%.6f', top.baseline_rmse) + "**";
    lines(end+1) = "- Pearson / Spearman: **" + sprintf('%.4f / %.4f', top.pearson, top.spearman) + "**";
else
    lines(end+1) = "- No evaluable models.";
end
lines(end+1) = "";
lines(end+1) = "## Verdicts";
lines(end+1) = "- **KAPPA2_OPERATIONAL_SIGNATURE_FOUND: " + verdict + "**";
lines(end+1) = "- **BEST_SIGNATURE_VARIABLE: " + bestSingleName + "**";
lines(end+1) = "";
lines(end+1) = "## Decision rule";
lines(end+1) = "- YES: best RMSE improvement >= " + sprintf('%.2f', cfg.yesImprovementThreshold) + ...
    " and best single-feature |corr| >= " + sprintf('%.2f', cfg.yesCorrelationThreshold) + ".";
lines(end+1) = "- PARTIAL: best RMSE improvement >= " + sprintf('%.2f', cfg.partialImprovementThreshold) + ...
    " and best single-feature |corr| >= " + sprintf('%.2f', cfg.partialCorrelationThreshold) + ".";
lines(end+1) = "- Current best improvement fraction: **" + sprintf('%.4f', improvementFrac) + "**.";

report = strjoin(lines, newline);
end

function col = numericColumn(tbl, candidates)
names = string(tbl.Properties.VariableNames);
col = NaN(height(tbl), 1);
for i = 1:numel(candidates)
    idx = find(names == string(candidates(i)), 1, 'first');
    if ~isempty(idx)
        raw = tbl.(names(idx));
        if isnumeric(raw)
            col = double(raw(:));
        else
            col = str2double(string(raw(:)));
        end
        return;
    end
end
end

function cfg = setDefault(cfg, name, value)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = value;
end
end

function writeText(pathOut, txt)
fid = fopen(pathOut, 'w', 'n', 'UTF-8');
if fid < 0
    error('run_kappa2_operational_signature_test:WriteFail', ...
        'Unable to write report: %s', pathOut);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', char(txt));
end
