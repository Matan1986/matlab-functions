function run_alpha_res_origin_test()
%RUN_ALPHA_RES_ORIGIN_TEST  Agent C — alpha_res predictability from PT geometry vs switching peaks
%
% Reads: tables/alpha_decomposition.csv, tables/alpha_structure.csv
% Writes: tables/alpha_res_predictability.csv, reports/alpha_res_origin_report.md
%
% LOOCV OLS (intercept + features), same leverage shortcut as run_alpha_from_pt_agent20b.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
decPath = fullfile(repoRoot, 'tables', 'alpha_decomposition.csv');
strPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
outCsv = fullfile(repoRoot, 'tables', 'alpha_res_predictability.csv');
outRep = fullfile(repoRoot, 'reports', 'alpha_res_origin_report.md');

assert(exist(decPath, 'file') == 2, 'Missing %s', decPath);
assert(exist(strPath, 'file') == 2, 'Missing %s', strPath);
for d = {fullfile(repoRoot, 'tables'), fullfile(repoRoot, 'reports')}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

dec = readtable(decPath, 'VariableNamingRule', 'preserve');
ast = readtable(strPath, 'VariableNamingRule', 'preserve');

Tstr = double(ast.T_K(:));

I_peak_mA = NaN(height(dec), 1);
S_peak = NaN(height(dec), 1);
for i = 1:height(dec)
    tk = double(dec.T_K(i));
    j = find(abs(Tstr - tk) < 1e-6, 1);
    assert(~isempty(j), 'alpha_structure missing T_K=%.6g', tk);
    I_peak_mA(i) = double(ast.I_peak_mA(j));
    S_peak(i) = double(ast.S_peak(j));
end

y = double(dec.alpha_res(:));
spread90_50 = double(dec.spread90_50(:));
asymmetry = double(dec.asymmetry(:));
ptOk = double(dec.PT_geometry_valid(:)) >= 0.5;

mBase = ptOk & isfinite(y) & isfinite(spread90_50) & isfinite(asymmetry) & ...
    isfinite(I_peak_mA) & isfinite(S_peak);

models = struct('name', {}, 'fn', {}, 'mask', {}, 'category', {});

mS = mBase;
models(end + 1) = struct('name', 'alpha_res ~ spread90_50', ...
    'fn', @(~, m) [ones(nnz(m), 1), spread90_50(m)], 'mask', mS, 'category', "PT_only");
models(end + 1) = struct('name', 'alpha_res ~ asymmetry', ...
    'fn', @(~, m) [ones(nnz(m), 1), asymmetry(m)], 'mask', mS, 'category', "PT_only");
models(end + 1) = struct('name', 'alpha_res ~ spread90_50 + asymmetry', ...
    'fn', @(~, m) [ones(nnz(m), 1), spread90_50(m), asymmetry(m)], 'mask', mS, 'category', "PT_only");

models(end + 1) = struct('name', 'alpha_res ~ S_peak', ...
    'fn', @(~, m) [ones(nnz(m), 1), S_peak(m)], 'mask', mS, 'category', "switching_only");
models(end + 1) = struct('name', 'alpha_res ~ I_peak_mA', ...
    'fn', @(~, m) [ones(nnz(m), 1), I_peak_mA(m)], 'mask', mS, 'category', "switching_only");
models(end + 1) = struct('name', 'alpha_res ~ S_peak + I_peak_mA', ...
    'fn', @(~, m) [ones(nnz(m), 1), S_peak(m), I_peak_mA(m)], 'mask', mS, 'category', "switching_only");

% Mixed pairs
models(end + 1) = struct('name', 'alpha_res ~ spread90_50 + S_peak', ...
    'fn', @(~, m) [ones(nnz(m), 1), spread90_50(m), S_peak(m)], 'mask', mS, 'category', "mixed");
models(end + 1) = struct('name', 'alpha_res ~ spread90_50 + I_peak_mA', ...
    'fn', @(~, m) [ones(nnz(m), 1), spread90_50(m), I_peak_mA(m)], 'mask', mS, 'category', "mixed");
models(end + 1) = struct('name', 'alpha_res ~ asymmetry + S_peak', ...
    'fn', @(~, m) [ones(nnz(m), 1), asymmetry(m), S_peak(m)], 'mask', mS, 'category', "mixed");
models(end + 1) = struct('name', 'alpha_res ~ asymmetry + I_peak_mA', ...
    'fn', @(~, m) [ones(nnz(m), 1), asymmetry(m), I_peak_mA(m)], 'mask', mS, 'category', "mixed");
models(end + 1) = struct('name', 'alpha_res ~ spread90_50 + asymmetry + S_peak', ...
    'fn', @(~, m) [ones(nnz(m), 1), spread90_50(m), asymmetry(m), S_peak(m)], 'mask', mS, 'category', "mixed");
models(end + 1) = struct('name', 'alpha_res ~ spread90_50 + asymmetry + I_peak_mA', ...
    'fn', @(~, m) [ones(nnz(m), 1), spread90_50(m), asymmetry(m), I_peak_mA(m)], 'mask', mS, 'category', "mixed");
models(end + 1) = struct('name', 'alpha_res ~ spread90_50 + asymmetry + S_peak + I_peak_mA', ...
    'fn', @(~, m) [ones(nnz(m), 1), spread90_50(m), asymmetry(m), S_peak(m), I_peak_mA(m)], ...
    'mask', mS, 'category', "mixed");

nM = numel(models);
res = table();
for k = 1:nM
    mk = models(k).mask;
    yk = y(mk);
    Xk = models(k).fn([], mk);
    n = numel(yk);
    p = size(Xk, 2);
    if n < p + 1
        continue
    end
    row = localFitRow(models(k).name, models(k).category, yk, Xk);
    res = [res; row]; %#ok<AGROW>
end

% Constant baselines on same cohort
mk0 = mS;
y0 = y(mk0);
n0 = numel(y0);
Ssum = sum(y0);
loo_const = (n0 * y0 - Ssum) ./ max(n0 - 1, 1);
baseline_loocv_rmse = sqrt(mean(loo_const.^2, 'omitnan'));
baseline_insample_rmse = sqrt(mean((y0 - mean(y0)).^2, 'omitnan'));
sig_y = std(y0, 'omitnan');

res.baseline_loocv_rmse = repmat(baseline_loocv_rmse, height(res), 1);
res.rmse_ratio_model_over_baseline = res.loocv_rmse ./ baseline_loocv_rmse;
res.baseline_insample_rmse = repmat(baseline_insample_rmse, height(res), 1);
res.beats_loocv_baseline = res.loocv_rmse < baseline_loocv_rmse;

[~, ibest] = min(res.loocv_rmse);
bestName = res.model{ibest};

isPT = strcmp(res.category, 'PT_only');
[~, iptBest] = min(res.loocv_rmse(isPT));
idxPT = find(isPT);
iptBest = idxPT(iptBest);
bestPTName = res.model{iptBest};

ALPHA_RES_GEOMETRY_CONTROLLED = localVerdict( ...
    res.loocv_rmse(iptBest), baseline_loocv_rmse, res.pearson_y_yhat(iptBest), ...
    res.loocv_rmse(ibest), bestName, bestPTName, sig_y);

writetable(res, outCsv);

fid = fopen(outRep, 'w');
assert(fid > 0, 'Cannot write report');
fprintf(fid, '# Alpha residual origin test (Agent C)\n\n');
fprintf(fid, ['**Goal:** assess whether `alpha_res` (from `alpha_decomposition.csv`) can be predicted ', ...
    'from PT geometry (`spread90_50`, `asymmetry`) and/or switching peaks (`S_peak`, `I_peak_mA`), ', ...
    'versus a constant baseline, using **LOOCV** linear regression.\n\n']);
fprintf(fid, '- **Decomposition table:** `%s`\n', strrep(decPath, '\', '/'));
fprintf(fid, '- **Switching peaks:** `%s` (joined on `T_K`)\n\n', strrep(strPath, '\', '/'));

fprintf(fid, '## Cohort\n\n');
fprintf(fid, '- Rows with `PT_geometry_valid == 1` and finite `alpha_res`, `spread90_50`, `asymmetry`, `I_peak_mA`, `S_peak`.\n');
fprintf(fid, '- **n = %d** temperatures: %s K.\n\n', n0, mat2str(double(dec.T_K(mk0))'));

fprintf(fid, '## Baselines (same cohort)\n\n');
fprintf(fid, '| quantity | value |\n|---|---:|\n');
fprintf(fid, '| LOOCV RMSE, predict mean(alpha_res) leave-one-out | %.6g |\n', baseline_loocv_rmse);
fprintf(fid, '| In-sample RMSE, constant mean(alpha_res) | %.6g |\n', baseline_insample_rmse);
fprintf(fid, '| std(alpha_res) | %.6g |\n\n', sig_y);

anyBeat = any(res.beats_loocv_baseline);
fprintf(fid, '## LOOCV vs baseline (all models)\n\n');
if anyBeat
    fprintf(fid, '- At least one linear model achieves **lower** LOOCV RMSE than the constant-mean baseline.\n\n');
else
    fprintf(fid, '- **No** tested linear model beats the constant-mean baseline under LOOCV: every specification has LOOCV RMSE **≥** %.6g.\n', baseline_loocv_rmse);
    fprintf(fid, '- The **least bad** fit (lowest LOOCV RMSE among models) is still a **worse** out-of-sample predictor than always using the leave-one-out mean.\n\n');
end

fprintf(fid, '## Best models\n\n');
fprintf(fid, '- **Best overall (min LOOCV RMSE):** `%s` — LOOCV RMSE = %.6g, ratio vs baseline = %.6g, Pearson(y,ŷ) = %.6g\n', ...
    bestName, res.loocv_rmse(ibest), res.rmse_ratio_model_over_baseline(ibest), res.pearson_y_yhat(ibest));
fprintf(fid, '- **Best PT-only (spread/asym, no S_peak/I_peak):** `%s` — LOOCV RMSE = %.6g, ratio vs baseline = %.6g, Pearson = %.6g\n\n', ...
    bestPTName, res.loocv_rmse(iptBest), res.rmse_ratio_model_over_baseline(iptBest), res.pearson_y_yhat(iptBest));

fprintf(fid, '## All models\n\n');
fprintf(fid, '| category | model | n | LOOCV RMSE | ratio vs LOOCV baseline | beats baseline | Pearson(y,ŷ) | Spearman(y,ŷ) | max leverage |\n');
fprintf(fid, '|---|---|---:|---:|---:|---:|---:|---:|---:|\n');
for r = 1:height(res)
    if logical(res.beats_loocv_baseline(r))
        beatStr = 'yes';
    else
        beatStr = 'no';
    end
    fprintf(fid, '| %s | %s | %d | %.6g | %.6g | %s | %.6g | %.6g | %.6g |\n', ...
        res.category{r}, res.model{r}, res.n(r), res.loocv_rmse(r), ...
        res.rmse_ratio_model_over_baseline(r), beatStr, res.pearson_y_yhat(r), ...
        res.spearman_y_yhat(r), res.max_leverage(r));
end
fprintf(fid, '\n');

fprintf(fid, '## Interpretation\n\n');
fprintf(fid, '- **PT-only** uses only quantile spreads from the PT row (same construction as Agent 20B).\n');
fprintf(fid, '- **switching_only** uses `S_peak` and/or `I_peak_mA` from `alpha_structure`.\n');
fprintf(fid, '- **mixed** combines both families.\n\n');

fprintf(fid, '## Final flag\n\n');
fprintf(fid, '- **ALPHA_RES_GEOMETRY_CONTROLLED** = **%s**\n\n', ALPHA_RES_GEOMETRY_CONTROLLED);
fprintf(fid, ['*Verdict rule:* **YES** if the best PT-only model improves LOOCV RMSE by at least 10%% over the ', ...
    'constant baseline and |Pearson(y,ŷ)| ≥ 0.5; **NO** if PT-only does not beat the baseline; ', ...
    '**PARTIAL** otherwise (including weak geometry signal or switching-heavy best overall).\n\n']);
fprintf(fid, '*Auto-generated by `analysis/run_alpha_res_origin_test.m`.*\n');
fclose(fid);

fprintf('Wrote %s\n%s\nALPHA_RES_GEOMETRY_CONTROLLED = %s\n', outCsv, outRep, ALPHA_RES_GEOMETRY_CONTROLLED);
end

function row = localFitRow(name, category, y, X)
n = numel(y);
beta = X \ y;
yhat = X * beta;
e = y - yhat;
H = X * ((X' * X) \ X');
h = diag(H);
loo_e = e ./ max(1 - h, 1e-12);
loocv_rmse = sqrt(mean(loo_e.^2, 'omitnan'));
pear = corr(y, yhat, 'rows', 'complete');
spear = corr(y, yhat, 'type', 'Spearman', 'rows', 'complete');
maxlev = max(h);
row = table( ...
    {char(name)}, {char(category)}, n, loocv_rmse, pear, spear, maxlev, ...
    'VariableNames', {'model', 'category', 'n', 'loocv_rmse', ...
    'pearson_y_yhat', 'spearman_y_yhat', 'max_leverage'});
end

function v = localVerdict(rmsePT, rmseBase, rPT, rmseBest, bestName, bestPTName, sig)
if ~isfinite(rmsePT) || ~isfinite(rmseBase) || rmseBase < 1e-12
    v = 'NO';
    return
end
rel = rmsePT / rmseBase;
improves = rel <= 0.90;
strongR = abs(rPT) >= 0.5;
if improves && strongR
    v = 'YES';
elseif rmsePT >= rmseBase
    v = 'NO';
else
    v = 'PARTIAL';
end
% If std tiny, downgrade
if sig < 1e-8
    v = 'NO';
end
% Optional: if best overall is purely switching and crushes PT-only, note partial
if contains(lower(string(bestName)), 'spread') || contains(lower(string(bestName)), 'asymmetry')
    return
end
if rmseBest < 0.85 * rmsePT && ~strcmp(bestPTName, bestName)
    if strcmp(v, 'YES')
        v = 'PARTIAL';
    end
end
end
