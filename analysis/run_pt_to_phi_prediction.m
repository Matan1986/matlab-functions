function out = run_pt_to_phi_prediction()
%RUN_PT_TO_PHI_PREDICTION Read-only audit: barrier/PT descriptors vs kappa(T).
set(0, 'DefaultFigureVisible', 'off');

thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(thisDir);
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));

runCfg = struct('runLabel', 'pt_to_phi_prediction');
run = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
for s = ["figures", "tables", "reports", "review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7, mkdir(d); end
end

barrierPath = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv');
kappaPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    '_extract_run_2026_03_24_220314_residual_decomposition', 'run_2026_03_24_220314_residual_decomposition', ...
    'tables', 'kappa_vs_T.csv');
phiPath = fullfile(fileparts(kappaPath), 'phi_shape.csv');
ptSumPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_25_013849_pt_robust_minpts7', 'tables', 'PT_summary.csv');

bd = readtable(barrierPath, 'VariableNamingRule', 'preserve');
kap = readtable(kappaPath, 'VariableNamingRule', 'preserve');
if ismember('T', kap.Properties.VariableNames) && ~ismember('T_K', kap.Properties.VariableNames)
    kap.Properties.VariableNames{'T'} = 'T_K';
end
merged = innerjoin(bd, kap(:, {'T_K', 'kappa'}), 'Keys', 'T_K');

pt = readtable(ptSumPath, 'VariableNamingRule', 'preserve');
pt = renamevars(pt, {'mean_threshold_mA', 'skewness', 'cdf_rmse'}, ...
    {'pt_sum_mean_thr_mA', 'pt_sum_thr_skewness', 'pt_sum_cdf_rmse'});
pt = pt(:, {'T_K', 'pt_sum_mean_thr_mA', 'pt_sum_thr_skewness', 'pt_sum_cdf_rmse'});
merged = outerjoin(merged, pt, 'Keys', 'T_K', 'MergeKeys', true);

merged.tail_ratio_log10 = log10(max(merged.tail_ratio_high_over_low, 1e-300));

widthEx = {'iq75_25_mA', 'iq90_10_mA', 'tail_ratio_high_over_low'};
baseSw = {'X_T_interp', 'I_peak_mA', 'S_peak'};
notPred = [{'T_K', 'row_valid', 'kappa', 'A_T_interp', 'R_T_interp'}, baseSw];

vn = merged.Properties.VariableNames;
ptPool = {};
for i = 1:numel(vn)
    c = vn{i};
    if any(strcmp(c, notPred)) || any(strcmp(c, widthEx))
        continue;
    end
    if isnumeric(merged.(c)) || islogical(merged.(c))
        ptPool{end+1} = c; %#ok<AGROW>
    end
end

use = merged.row_valid == 1 & isfinite(merged.kappa);
df = merged(use, :);
df = sortrows(df, 'T_K');

y = df.kappa;
Tcol = df.T_K;
n = height(df);

ptPool = ptPool(:)';

rows = struct('model_id', {}, 'family', {}, 'predictors', {}, 'n', {}, ...
    'loocv_rmse', {}, 'pearson_loocv', {}, 'spearman_loocv', {});

rows(end+1) = fitStruct('naive_mean', 'naive', '(constant)', n, loocvMeanBaseline(y), NaN, NaN); %#ok<AGROW>
rT = naiveFitRow(df, 'naive_T_linear', 'naive', {'T_K'});
rows(end+1) = rT; %#ok<AGROW>

bestPt1 = '';
bestRm1 = inf;
for i = 1:numel(ptPool)
    r = naiveFitRow(df, ['PT1__' ptPool{i}], 'PT_only', {ptPool{i}});
    rows(end+1) = r; %#ok<AGROW>
    if isfinite(r.loocv_rmse) && r.loocv_rmse < bestRm1
        bestRm1 = r.loocv_rmse;
        bestPt1 = ptPool{i};
    end
end

bestPair = {};
bestRm2 = inf;
for i = 1:numel(ptPool)
    for j = i+1:numel(ptPool)
        p = {ptPool{i}, ptPool{j}};
        mid = sprintf('PT2__%s__%s', p{1}, p{2});
        r = naiveFitRow(df, mid, 'PT_only', p);
        rows(end+1) = r; %#ok<AGROW>
        if isfinite(r.loocv_rmse) && r.loocv_rmse < bestRm2
            bestRm2 = r.loocv_rmse;
            bestPair = p;
        end
    end
end

if ~isempty(bestPt1)
    rows(end+1) = naiveFitRow(df, 'best_PT1_selected', 'PT_only', {bestPt1}); %#ok<AGROW>
end
if ~isempty(bestPair)
    rows(end+1) = naiveFitRow(df, 'best_PT2_selected', 'PT_only', bestPair); %#ok<AGROW>
end

rows(end+1) = naiveFitRow(df, 'baseline_X_only', 'switching_baseline', {'X_T_interp'}); %#ok<AGROW>
rows(end+1) = naiveFitRow(df, 'baseline_Ipeak_Speak', 'switching_baseline', {'I_peak_mA', 'S_peak'}); %#ok<AGROW>
rows(end+1) = naiveFitRow(df, 'baseline_X_Ipeak_Speak', 'switching_baseline', ...
    {'X_T_interp', 'I_peak_mA', 'S_peak'}); %#ok<AGROW>

if ~isempty(bestPt1)
    rows(end+1) = naiveFitRow(df, 'PT1_best_plus_X', 'PT_plus_X', [bestPt1, {'X_T_interp'}]); %#ok<AGROW>
    rows(end+1) = naiveFitRow(df, 'PT1_best_plus_switching3', 'PT_plus_switching_baseline', ...
        [bestPt1, {'X_T_interp', 'I_peak_mA', 'S_peak'}]); %#ok<AGROW>
end
if ~isempty(bestPair)
    rows(end+1) = naiveFitRow(df, 'PT2_best_plus_X', 'PT_plus_X', [bestPair, {'X_T_interp'}]); %#ok<AGROW>
    rows(end+1) = naiveFitRow(df, 'PT2_best_plus_switching3', 'PT_plus_switching_baseline', ...
        [bestPair, {'X_T_interp', 'I_peak_mA', 'S_peak'}]); %#ok<AGROW>
end

mdf = struct2table(rows);
[~, ord] = sort(mdf.loocv_rmse, 'ascend', 'MissingPlacement', 'last');
mdf = mdf(ord, :);
writetable(mdf, fullfile(runDir, 'tables', 'kappa_prediction_models.csv'));

want = {'naive_mean', 'naive_T_linear', 'best_PT1_selected', 'best_PT2_selected', ...
    'baseline_X_only', 'baseline_Ipeak_Speak', 'PT1_best_plus_X', 'PT2_best_plus_X', ...
    'PT1_best_plus_switching3', 'PT2_best_plus_switching3'};
minimal = mdf(ismember(mdf.model_id, want), :);
writetable(minimal, fullfile(runDir, 'tables', 'kappa_prediction_minimal_models.csv'));

maskNo22 = df.T_K ~= 22;
stabRows = [];
if ~isempty(bestPt1)
    stabRows = [stabRows; naiveFitRow(df, 'best_PT1_selected_no22K', 'stability', {bestPt1}, maskNo22)];
end
if ~isempty(bestPair)
    stabRows = [stabRows; naiveFitRow(df, 'best_PT2_selected_no22K', 'stability', bestPair, maskNo22)];
end
stabRows = [stabRows; naiveFitRow(df, 'naive_T_linear_no22K', 'stability', {'T_K'}, maskNo22)];
stabRows = [stabRows; naiveFitRow(df, 'baseline_X_only_no22K', 'stability', {'X_T_interp'}, maskNo22)];
if ~isempty(bestPair)
    stabRows = [stabRows; naiveFitRow(df, 'PT2_best_plus_X_no22K', 'stability', ...
        [bestPair, {'X_T_interp'}], maskNo22)];
end
stabDf = struct2table(stabRows);

naiveRmse = rows(1).loocv_rmse;
m1 = minimal(strcmp(minimal.model_id, 'best_PT1_selected'), :);
m2 = minimal(strcmp(minimal.model_id, 'best_PT2_selected'), :);
mx = minimal(strcmp(minimal.model_id, 'baseline_X_only'), :);
mTlin = minimal(strcmp(minimal.model_id, 'naive_T_linear'), :);
rmsePt1 = pickScalar(m1, 'loocv_rmse', NaN);
rmsePt2 = pickScalar(m2, 'loocv_rmse', NaN);
rmseX = pickScalar(mx, 'loocv_rmse', NaN);
rmseTlin = pickScalar(mTlin, 'loocv_rmse', NaN);

verdict = materialVerdict(rmsePt1, naiveRmse);
if strcmp(verdict, 'NO') && ~isempty(m2)
    verdict = materialVerdict(rmsePt2, naiveRmse);
end

pt2x = minimal(strcmp(minimal.model_id, 'PT2_best_plus_X'), :);
pt2xRmse = NaN;
if ~isempty(pt2x), pt2xRmse = pt2x.loocv_rmse(1); end
xImp = '';
if isfinite(pt2xRmse) && isfinite(rmsePt2)
    if pt2xRmse < 0.95 * rmsePt2
        xImp = 'X reduces LOOCV RMSE vs best PT-only pair moderately.';
    elseif pt2xRmse > 1.02 * rmsePt2
        xImp = 'X does not improve; PT-only pairs remain competitive.';
    else
        xImp = 'X gives only marginal change vs best PT-only pair.';
    end
end
sw = minimal(strcmp(minimal.model_id, 'PT2_best_plus_switching3'), :);
if ~isempty(sw)
    swRmse = sw.loocv_rmse(1);
    if isfinite(swRmse) && isfinite(rmsePt2) && swRmse < 0.92 * rmsePt2
        xImp = [xImp ' Full switching baseline (X,I_peak,S_peak) improves clearly over PT-only.'];
    elseif isfinite(pt2xRmse) && isfinite(sw.loocv_rmse(1)) && sw.loocv_rmse(1) < 0.98 * pt2xRmse
        xImp = [xImp ' Switching baseline edges PT+X slightly.'];
    end
end
if isempty(xImp)
    xImp = 'See kappa_prediction_minimal_models.csv.';
end

stabNo22 = NaN;
ix = find(strcmp(stabDf.model_id, 'best_PT2_selected_no22K'), 1);
if ~isempty(ix), stabNo22 = stabDf.loocv_rmse(ix); end

linkVals = { ...
    bestPt1; ...
    strjoin(bestPair, '|'); ...
    sprintf('%.17g', rmsePt1); ...
    sprintf('%.17g', rmsePt2); ...
    sprintf('%.17g', naiveRmse); ...
    sprintf('%.17g', rmseTlin); ...
    sprintf('%.17g', rmseX); ...
    verdict; ...
    'no'; ...
    char(phiPath); ...
    sprintf('%.17g', stabNo22)};
linkTbl = table( ...
    {'best_PT_single_predictor'; 'best_PT_pair'; 'loocv_rmse_best_PT1'; 'loocv_rmse_best_PT2'; ...
    'loocv_rmse_naive_mean_kappa'; 'loocv_rmse_T_linear'; 'loocv_rmse_X_only'; ...
    'verdict_PT_predicts_kappa_materially'; 'phi_per_T_coefficients_available'; ...
    'phi_shape_path'; 'stability_no22K_best_PT2_loocv_rmse'}, ...
    linkVals, ...
    'VariableNames', {'quantity', 'value'});
writetable(linkTbl, fullfile(runDir, 'tables', 'pt_to_phi_link_summary.csv'));

% --- Figures
predCols = bestPair;
if isempty(predCols), predCols = {bestPt1}; end
[~, ~, yhat] = loocvLinearCore(df, predCols);
fig1 = create_figure('Name', 'kappa_actual_vs_pred', 'NumberTitle', 'off');
ax = axes(fig1);
plot(ax, y, yhat, 'o', 'MarkerSize', 10, 'LineWidth', 2);
hold(ax, 'on');
lo = min([min(y); min(yhat); 0]);
hi = max([max(y); max(yhat)]);
plot(ax, [lo, hi], [lo, hi], 'k--', 'LineWidth', 2);
for ii = 1:n
    text(ax, y(ii), yhat(ii), sprintf('  %g', df.T_K(ii)), 'FontSize', 11);
end
xlabel(ax, '\kappa actual', 'FontSize', 14);
ylabel(ax, '\kappa LOOCV prediction', 'FontSize', 14);
title(ax, 'Kappa: actual vs best PT-only LOOCV fit', 'FontSize', 14);
grid(ax, 'on');
save_run_figure(fig1, 'kappa_actual_vs_pred', runDir);
close(fig1);

cmpModels = {'naive_mean', 'naive_T_linear', 'best_PT1_selected', 'best_PT2_selected', ...
    'baseline_X_only', 'PT2_best_plus_X', 'PT2_best_plus_switching3'};
barRmse = zeros(numel(cmpModels), 1);
ok = false(numel(cmpModels), 1);
for k = 1:numel(cmpModels)
    ix = find(strcmp(mdf.model_id, cmpModels{k}), 1);
    if ~isempty(ix)
        barRmse(k) = mdf.loocv_rmse(ix);
        ok(k) = true;
    end
end
fig2 = create_figure('Name', 'loocv_kappa_model_comparison', 'NumberTitle', 'off');
ax2 = axes(fig2);
bar(ax2, barRmse(ok), 'FaceColor', [0, 0.447, 0.741], 'LineWidth', 2, 'EdgeColor', 'k');
set(ax2, 'XTick', 1:sum(ok), 'XTickLabel', cmpModels(ok), 'XTickLabelRotation', 35);
ylabel(ax2, 'LOOCV RMSE (\kappa)', 'FontSize', 14);
title(ax2, 'Model comparison (lower is better)', 'FontSize', 14);
grid(ax2, 'on');
save_run_figure(fig2, 'loocv_kappa_model_comparison', runDir);
close(fig2);

% Report
fid = fopen(fullfile(runDir, 'reports', 'pt_to_phi_prediction_report.md'), 'w');
fprintf(fid, '# PT to \\kappa (residual amplitude) prediction audit\n\n');
fprintf(fid, '## Inputs (read-only)\n\n');
fprintf(fid, '- `barrier_descriptors.csv`: `%s`\n', barrierPath);
fprintf(fid, '- `kappa_vs_T.csv`: `%s`\n', kappaPath);
fprintf(fid, '- `phi_shape.csv`: `%s` (global Phi slice only)\n', phiPath);
fprintf(fid, '- `PT_summary.csv`: `%s`\n\n', ptSumPath);
fprintf(fid, 'Merged n=%d temperatures on common T after row_valid==1 and finite kappa.\n\n', n);
fprintf(fid, '## Results\n\n');
fprintf(fid, '- **Best single PT-family predictor**: `%s`, LOOCV RMSE **%.5f**.\n', bestPt1, rmsePt1);
fprintf(fid, '- **Best PT-only pair**: `%s`, LOOCV RMSE **%.5f**.\n', strjoin(bestPair, ', '), rmsePt2);
fprintf(fid, '- **Naive mean** LOOCV RMSE: **%.5f**; **T-linear** RMSE: **%.5f**; **X-only** RMSE: **%.5f**.\n\n', ...
    naiveRmse, rmseTlin, rmseX);
fprintf(fid, '### Correlations (LOOCV)\n\n');
fprintf(fid, '- Best PT1: Pearson **%.3f**, Spearman **%.3f**.\n', pickScalar(m1, 'pearson_loocv', NaN), ...
    pickScalar(m1, 'spearman_loocv', NaN));
if ~isempty(m2)
    fprintf(fid, '- Best PT2: Pearson **%.3f**, Spearman **%.3f**.\n\n', m2.pearson_loocv(1), m2.spearman_loocv(1));
else
    fprintf(fid, '- Best PT2: N/A (insufficient predictor pool for pair model).\n\n');
end
fprintf(fid, '### Stability excluding 22 K\n\n');
fprintf(fid, '%s\n\n', evalc('disp(stabDf)'));
fprintf(fid, '### Interpretation\n\n');
fprintf(fid, '- **Material vs naive mean:** `%s` (>10%% drop = PARTIAL, >25%% = YES).\n', verdict);
fprintf(fid, '- **X / switching baseline:** %s\n\n', xImp);
fprintf(fid, '## Artifact paths\n\n');
fprintf(fid, '- tables/kappa_prediction_models.csv\n- tables/kappa_prediction_minimal_models.csv\n');
fprintf(fid, '- tables/pt_to_phi_link_summary.csv\n');
fprintf(fid, '- figures/kappa_actual_vs_pred.{pdf,png,fig}\n');
fprintf(fid, '- figures/loocv_kappa_model_comparison.{pdf,png,fig}\n');
fclose(fid);

appendText(run.log_path, sprintf('[%s] pt_to_phi_prediction complete\n', stampNow()));

zipPath = buildReviewZipLocal(runDir, 'pt_to_phi_prediction_bundle.zip');
fprintf('\nRun directory:\n%s\n', runDir);

out = struct('run', run, 'runDir', string(runDir), 'zipPath', string(zipPath));
end

function r = fitStruct(model_id, family, predictors, n, loocv_rmse, pearson_loocv, spearman_loocv)
r = struct('model_id', model_id, 'family', family, 'predictors', predictors, ...
    'n', n, 'loocv_rmse', loocv_rmse, 'pearson_loocv', pearson_loocv, 'spearman_loocv', spearman_loocv);
end

function r = naiveFitRow(df, model_id, family, predCols, mask)
if nargin < 5
    mask = true(height(df), 1);
end
d = df(mask, :);
yv = d.kappa;
if height(d) < 3
    r = fitStruct(model_id, family, strjoin(predCols, '|'), height(d), NaN, NaN, NaN);
    return;
end
mfin = true(height(d), 1);
for k = 1:numel(predCols)
    v = d.(predCols{k});
    mfin = mfin & isfinite(v);
end
d = d(mfin, :);
yv = d.kappa;
if height(d) < 3
    r = fitStruct(model_id, family, strjoin(predCols, '|'), height(d), NaN, NaN, NaN);
    return;
end
[rmse, rp, rs] = loocvLinearCore(d, predCols);
r = fitStruct(model_id, family, strjoin(predCols, '|'), height(d), rmse, rp, rs);
end

function [rmse, pear_r, spear_r, yhatFull] = loocvLinearCore(d, predCols)
yv = d.kappa;
n = height(d);
X = ones(n, 1);
for k = 1:numel(predCols)
    X = [X, d.(predCols{k})]; %#ok<AGROW>
end
p = size(X, 2);
sse = 0;
yhat = nan(n, 1);
for i = 1:n
    mask = true(n, 1);
    mask(i) = false;
    Xi = X(mask, :);
    yi = yv(mask);
    if rank(Xi) < p
        rmse = NaN; pear_r = NaN; spear_r = NaN; yhatFull = yhat; return;
    end
    b = Xi \ yi;
    yhat(i) = X(i, :) * b;
    sse = sse + (yv(i) - yhat(i))^2;
end
rmse = sqrt(sse / n);
pear_r = corr(yv, yhat, 'rows', 'pairwise');
spear_r = corr(yv, yhat, 'rows', 'pairwise', 'type', 'Spearman');
yhatFull = yhat;
end

function v = loocvMeanBaseline(y)
n = numel(y);
if n < 2, v = NaN; return; end
sse = 0;
s = sum(y);
for i = 1:n
    pred = (s - y(i)) / (n - 1);
    sse = sse + (y(i) - pred)^2;
end
v = sqrt(sse / n);
end

function v = materialVerdict(rmsePt, naiveRmse)
if ~(isfinite(rmsePt) && isfinite(naiveRmse))
    v = 'unknown';
    return;
end
imp = (naiveRmse - rmsePt) / naiveRmse;
if imp > 0.25
    v = 'YES';
elseif imp > 0.10
    v = 'PARTIAL';
else
    v = 'NO';
end
end

function zipPath = buildReviewZipLocal(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, ...
    runDir);
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0, return; end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function v = pickScalar(tbl, fname, defaultVal)
if isempty(tbl) || ~ismember(fname, tbl.Properties.VariableNames)
    v = defaultVal;
    return;
end
v = tbl.(fname)(1);
end
