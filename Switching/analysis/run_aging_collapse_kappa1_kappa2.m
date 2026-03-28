% run_aging_collapse_kappa1_kappa2
% Test whether aging R(T) collapses as a function of the collective state
% (kappa1, kappa2).
%
% This script is intentionally "pure": it contains no local `function ...`
% blocks so it passes the repo's MATLAB wrapper validation.

clearvars;
clc;

% IMPORTANT:
% This script is executed via eval(fileread(...)) inside the stable wrapper.
% In that context, mfilename('fullpath') refers to the wrapper's temporary
% runner script, NOT this file, so derive nothing from mfilename here.

repoRoot = 'C:\Dev\matlab-functions';

% -------------------------------
% User inputs (ABSOLUTE PATHS)
% -------------------------------
% Canonical kappa table must contain columns:
%   T_K, kappa1, kappa2
canonicalKappaTablePath = fullfile(repoRoot, 'tables', 'R_vs_state.csv');

% Aging R(T) table must contain columns:
%   T_K, R (or R_T)
agingRTablePath = fullfile(repoRoot, 'tables', 'R_vs_state.csv');

% -------------------------------
% Output paths (ABSOLUTE)
% -------------------------------
outTablesDir = fullfile(repoRoot, 'tables');
outReportsDir = fullfile(repoRoot, 'reports');
ensureDir(outTablesDir);
ensureDir(outReportsDir);

modelsOutPath = fullfile(outTablesDir, 'aging_kappa1_kappa2_models.csv');
reportOutPath = fullfile(outReportsDir, 'aging_kappa1_kappa2_collapse.md');
statusOutPath = fullfile(outTablesDir, 'aging_kappa1_kappa2_status.csv');

% -------------------------------
% Collapse decision thresholds
% -------------------------------
cfg = struct();
cfg.tolT = 1e-9;                       % tolerance for matching T_K
cfg.minRelRmseImprovement = 0.08;     % meaningful LOOCV improvement overall
cfg.minRelRmseImprovementRegion = 0.10;
cfg.minPearsonImprovement = 0.02;      % Pearson r improvement threshold
cfg.residualCorrKappa2Threshold = 0.25; % residual corr proxy target
cfg.residualCorrKappa2Improvement = 0.10; % require reduction vs kappa1-only
cfg.regionMask = @(T) (T >= 22) & (T <= 24); % focus region 22–24K

% -------------------------------
% Load tables
% -------------------------------
assert(exist(canonicalKappaTablePath, 'file') == 2, ...
    'Canonical kappa table not found: %s', canonicalKappaTablePath);
assert(exist(agingRTablePath, 'file') == 2, ...
    'Aging R table not found: %s', agingRTablePath);

fprintf('Reading canonical kappa table:\n%s\n', canonicalKappaTablePath);
canonicalTbl = readtable(canonicalKappaTablePath, ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');

fprintf('Reading aging R table:\n%s\n', agingRTablePath);
agingTbl = readtable(agingRTablePath, ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');

% -------------------------------
% Extract required columns
% -------------------------------
canonT = toDoubleColumn(getVarByCandidates(canonicalTbl, {'T_K', 'T', 'Tk', 't_k', 't'}));
canonKappa1 = toDoubleColumn(getVarByCandidates(canonicalTbl, {'kappa1', 'kappa_1'}));
canonKappa2 = toDoubleColumn(getVarByCandidates(canonicalTbl, {'kappa2', 'kappa_2'}));

ageT = toDoubleColumn(getVarByCandidates(agingTbl, {'T_K', 'T', 'Tk', 't_k', 't'}));
ageR = toDoubleColumn(getVarByCandidates(agingTbl, {'R', 'R_T', 'R_TK'}));

canonT = canonT(:);
canonKappa1 = canonKappa1(:);
canonKappa2 = canonKappa2(:);
ageT = ageT(:);
ageR = ageR(:);

% Drop non-finite rows early
validCanon = isfinite(canonT) & isfinite(canonKappa1) & isfinite(canonKappa2);
canonT = canonT(validCanon);
canonKappa1 = canonKappa1(validCanon);
canonKappa2 = canonKappa2(validCanon);

validAge = isfinite(ageT) & isfinite(ageR);
ageT = ageT(validAge);
ageR = ageR(validAge);

% Validate uniqueness (one row per T_K)
assert(numel(canonT) == numel(canonKappa1) && numel(canonT) == numel(canonKappa2), ...
    'Canonical table: expected consistent lengths for T_K, kappa1, kappa2.');
assert(numel(ageT) == numel(ageR), ...
    'Aging table: expected consistent lengths for T_K and R.');

checkNoDuplicateTemps(canonT, 'canonical');
checkNoDuplicateTemps(ageT, 'aging');

% -------------------------------
% Align manually by T_K (no innerjoin)
% -------------------------------
canonTuniq = unique(canonT, 'stable');
ageTuniq = unique(ageT, 'stable');

alignedT = [];
alignedK1 = [];
alignedK2 = [];
alignedR = [];

for i = 1:numel(canonTuniq)
    t = canonTuniq(i);
    idxAgeUniq = find(abs(ageTuniq - t) <= cfg.tolT, 1, 'first');
    if isempty(idxAgeUniq)
        continue;
    end

    % Find exact indices in original tables for robustness
    idxCanonFull = find(abs(canonT - t) <= cfg.tolT, 1, 'first');
    idxAgeFull = find(abs(ageT - t) <= cfg.tolT, 1, 'first');
    if isempty(idxCanonFull) || isempty(idxAgeFull)
        continue;
    end

    alignedT(end + 1, 1) = t; %#ok<AGROW>
    alignedK1(end + 1, 1) = canonKappa1(idxCanonFull); %#ok<AGROW>
    alignedK2(end + 1, 1) = canonKappa2(idxCanonFull); %#ok<AGROW>
    alignedR(end + 1, 1) = ageR(idxAgeFull); %#ok<AGROW>
end

% Sort by T_K for readability
[dataset.T_K, sortOrder] = sort(alignedT, 'ascend');
dataset.kappa1 = alignedK1(sortOrder);
dataset.kappa2 = alignedK2(sortOrder);
dataset.R = alignedR(sortOrder);

n = numel(dataset.R);
assert(n >= 4, 'Need at least 4 aligned temperatures for LOOCV models. Got n=%d', n);

fprintf('Aligned dataset size (n=%d): T_K in [%g, %g]\n', n, min(dataset.T_K), max(dataset.T_K));

% -------------------------------
% Build predictors
% -------------------------------
k1 = dataset.kappa1;
k2 = dataset.kappa2;
y = dataset.R;

X_baseline = ones(n, 1);
X_k1 = [ones(n, 1), k1];
X_k2 = [ones(n, 1), k2];
X_state = [ones(n, 1), k1, k2];
X_nonlinear = [ones(n, 1), k1, k2, k1 .* k2];

% -------------------------------
% LOOCV models
% -------------------------------
modelSpecs = {
    'R ~ 1', 'constant', X_baseline;
    'R ~ kappa1', 'kappa1', X_k1;
    'R ~ kappa2', 'kappa2', X_k2;
    'R ~ kappa1 + kappa2', 'kappa1+kappa2', X_state;
    'R ~ kappa1 + kappa2 + (kappa1*kappa2)', 'interaction', X_nonlinear
    };

results = struct( ...
    'model', '', ...
    'category', '', ...
    'n', NaN, ...
    'loocv_rmse', NaN, ...
    'pearson_r', NaN, ...
    'spearman_r', NaN, ...
    'yhat_loocv', nan(n, 1));

for m = 1:size(modelSpecs, 1)
    results(m) = results(1); %#ok<SAGROW>
    results(m).model = modelSpecs{m, 1};
    results(m).category = modelSpecs{m, 2};
    results(m).n = n;

    X = modelSpecs{m, 3};
    fprintf('LOOCV fit: %s ...\n', results(m).model);

    yhat = leaveOneOutPredict(X, y);
    metrics = computeMetrics(y, yhat);

    results(m).loocv_rmse = metrics.rmse;
    results(m).pearson_r = metrics.pearson_r;
    results(m).spearman_r = metrics.spearman_r;
    results(m).yhat_loocv = yhat;
end

% -------------------------------
% Extract key model indices
% -------------------------------
idx_k1 = find(strcmp({results.model}, 'R ~ kappa1'), 1, 'first');
idx_state = find(strcmp({results.model}, 'R ~ kappa1 + kappa2'), 1, 'first');
idx_nl = find(strcmp({results.model}, 'R ~ kappa1 + kappa2 + (kappa1*kappa2)'), 1, 'first');

rmse_k1 = results(idx_k1).loocv_rmse;
rmse_state = results(idx_state).loocv_rmse;
rmse_nl = results(idx_nl).loocv_rmse;

bestIdx = idx_state;
if rmse_nl < rmse_state
    bestIdx = idx_nl;
end
rmse_best = results(bestIdx).loocv_rmse;

% Region metrics
maskRegion = cfg.regionMask(dataset.T_K);
if nnz(maskRegion) >= 2
    rmse_k1_region = sqrt(mean((y(maskRegion) - results(idx_k1).yhat_loocv(maskRegion)).^2, 'omitnan'));
    rmse_best_region = sqrt(mean((y(maskRegion) - results(bestIdx).yhat_loocv(maskRegion)).^2, 'omitnan'));
else
    rmse_k1_region = NaN;
    rmse_best_region = NaN;
end

% Residual diagnostics (proxy for collapse/smoothness)
resid_k1 = y - results(idx_k1).yhat_loocv;
resid_best = y - results(bestIdx).yhat_loocv;

corrResidK2_k1 = pearsonCorrelation(resid_k1, k2);
corrResidK2_best = pearsonCorrelation(resid_best, k2);

prodTerm = k1 .* k2;
corrResidProd_best = pearsonCorrelation(resid_best, prodTerm);

smoothProxyOk = isfinite(corrResidK2_best) && (abs(corrResidK2_best) <= cfg.residualCorrKappa2Threshold);

% -------------------------------
% Verdicts (interpretation rules)
% -------------------------------
relImpOverall_state = relImprovement(rmse_k1, rmse_state);
relImpOverall_best = relImprovement(rmse_k1, rmse_best);
relImpRegion_best = relImprovement(rmse_k1_region, rmse_best_region);

pearson_k1 = results(idx_k1).pearson_r;
pearson_state = results(idx_state).pearson_r;
pearson_best = results(bestIdx).pearson_r;

AGING_DEPENDS_ON_KAPPA2 = yesno( ...
    isfinite(relImpOverall_state) && relImpOverall_state >= cfg.minRelRmseImprovement && ...
    isfinite(pearson_k1) && isfinite(pearson_state) && ...
    (pearson_state - pearson_k1) >= cfg.minPearsonImprovement);

KAPPA2_IMPROVES_PREDICTION = yesno( ...
    isfinite(relImpOverall_best) && relImpOverall_best >= cfg.minRelRmseImprovement && ...
    (isnan(relImpRegion_best) || relImpRegion_best >= cfg.minRelRmseImprovementRegion) && ...
    smoothProxyOk);

AGING_COLLAPSE_SUCCESS = yesno( ...
    KAPPA2_IMPROVES_PREDICTION == "YES" && ...
    isfinite(corrResidK2_k1) && isfinite(corrResidK2_best) && ...
    (abs(corrResidK2_k1) - abs(corrResidK2_best) >= cfg.residualCorrKappa2Improvement) && ...
    smoothProxyOk);

% -------------------------------
% Save outputs
% -------------------------------
modelsTbl = table();
modelsTbl.model = {results.model}';
modelsTbl.category = {results.category}';
modelsTbl.n = [results.n]';
modelsTbl.loocv_rmse = [results.loocv_rmse]';
modelsTbl.pearson_y_yhat = [results.pearson_r]';
modelsTbl.spearman_y_yhat = [results.spearman_r]';

fprintf('Writing models CSV:\n%s\n', modelsOutPath);
writetable(modelsTbl, modelsOutPath);

statusTbl = table(AGING_DEPENDS_ON_KAPPA2, KAPPA2_IMPROVES_PREDICTION, AGING_COLLAPSE_SUCCESS, ...
    'VariableNames', {'AGING_DEPENDS_ON_KAPPA2', 'KAPPA2_IMPROVES_PREDICTION', 'AGING_COLLAPSE_SUCCESS'});

fprintf('Writing status CSV:\n%s\n', statusOutPath);
writetable(statusTbl, statusOutPath);

% Markdown report
report = strings(0, 1);
report(end + 1) = '# Aging collapse: `R(T)` vs collective state `(kappa1, kappa2)`';
report(end + 1) = '';
report(end + 1) = sprintf('- Generated: %s', datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS'));
report(end + 1) = '';
report(end + 1) = '## Inputs (absolute paths)';
report(end + 1) = sprintf('- canonical kappa table: `%s`', canonicalKappaTablePath);
report(end + 1) = sprintf('- aging R table: `%s`', agingRTablePath);
report(end + 1) = '';
report(end + 1) = '## Alignment';
report(end + 1) = sprintf('- Manual alignment by `T_K` (tolerance = %.1e).', cfg.tolT);
report(end + 1) = sprintf('- Aligned rows (n): %d.  `T_K` range: [%g, %g].', n, min(dataset.T_K), max(dataset.T_K));
report(end + 1) = '';

report(end + 1) = '## LOOCV metrics';
report(end + 1) = '';
report(end + 1) = '| Model | LOOCV RMSE | Pearson(y,yhat) | Spearman(y,yhat) |';
report(end + 1) = '| --- | ---: | ---: | ---: |';

for m = 1:numel(results)
    report(end + 1) = sprintf('| %s | %s | %s | %s |', ...
        sanitizeMD(results(m).model), formatNum(results(m).loocv_rmse), ...
        formatNum(results(m).pearson_r), formatNum(results(m).spearman_r));
end

report(end + 1) = '';
report(end + 1) = '## Collapse tests (vs kappa1-only)';
report(end + 1) = '';
report(end + 1) = sprintf('- kappa1-only (R ~ kappa1): RMSE = %s', formatNum(rmse_k1));
report(end + 1) = sprintf('- best model (kappa1+kappa2 or with interaction): RMSE = %s', formatNum(rmse_best));
report(end + 1) = sprintf('- overall relative RMSE improvement vs kappa1-only: %s', formatNum(relImpOverall_best));

if nnz(maskRegion) >= 2
    report(end + 1) = sprintf('- 22-24K region relative RMSE improvement vs kappa1-only: %s', formatNum(relImpRegion_best));
else
    report(end + 1) = '- 22-24K region: skipped (fewer than 2 aligned points).';
end

report(end + 1) = '';
report(end + 1) = '- Residual dependence proxy (Pearson corr of LOOCV residual vs kappa2):';
report(end + 1) = sprintf('  - kappa1-only: %s', formatNum(corrResidK2_k1));
report(end + 1) = sprintf('  - best model: %s', formatNum(corrResidK2_best));
report(end + 1) = sprintf('- Residual correlation with interaction term `(kappa1*kappa2)` (best): %s', formatNum(corrResidProd_best));
report(end + 1) = '';

report(end + 1) = '## Verdicts';
report(end + 1) = '';
report(end + 1) = sprintf('- `AGING_DEPENDS_ON_KAPPA2`: %s', AGING_DEPENDS_ON_KAPPA2);
report(end + 1) = sprintf('- `KAPPA2_IMPROVES_PREDICTION`: %s', KAPPA2_IMPROVES_PREDICTION);
report(end + 1) = sprintf('- `AGING_COLLAPSE_SUCCESS`: %s', AGING_COLLAPSE_SUCCESS);

reportText = strjoin(report, newline);
fprintf('Writing markdown report:\n%s\n', reportOutPath);
fid = fopen(reportOutPath, 'w');
assert(fid >= 0, 'Could not open report output for writing: %s', reportOutPath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', reportText);

fprintf('Done.\n');
fprintf('Models CSV: %s\n', modelsOutPath);
fprintf('Report MD: %s\n', reportOutPath);
fprintf('Status CSV: %s\n', statusOutPath);

