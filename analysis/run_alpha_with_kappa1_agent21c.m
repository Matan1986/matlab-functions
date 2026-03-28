function run_alpha_with_kappa1_agent21c()
%RUN_ALPHA_WITH_KAPPA1_AGENT21C  Agent 21C — alpha = f(PT features, kappa1)
%
% Tests whether kappa1 reduces LOOCV error beyond PT spread + asymmetry.
% Reads: tables/alpha_structure.csv, canonical PT_matrix + PT_summary (same as Agent 20B).
% Writes: tables/alpha_with_kappa1.csv, reports/alpha_with_kappa1_report.md

repoRoot = fileparts(fileparts(mfilename('fullpath')));
alphaPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
ptRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_03_25_013356_pt_robust_canonical');
ptMatrixPath = fullfile(ptRunDir, 'tables', 'PT_matrix.csv');
ptSummaryPath = fullfile(ptRunDir, 'tables', 'PT_summary.csv');
outCsv = fullfile(repoRoot, 'tables', 'alpha_with_kappa1.csv');
outRep = fullfile(repoRoot, 'reports', 'alpha_with_kappa1_report.md');

assert(exist(alphaPath, 'file') == 2, 'Missing %s', alphaPath);
assert(exist(ptMatrixPath, 'file') == 2, 'Missing %s', ptMatrixPath);
assert(exist(ptSummaryPath, 'file') == 2, 'Missing %s', ptSummaryPath);

for d = {fullfile(repoRoot, 'tables'), fullfile(repoRoot, 'reports')}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

aTbl = readtable(alphaPath, 'VariableNamingRule', 'preserve');
[temps, currents, PT] = localLoadPTMatrix(ptMatrixPath);
sumTbl = readtable(ptSummaryPath, 'VariableNamingRule', 'preserve');

nA = height(aTbl);
spread90_50 = NaN(nA, 1);
asymmetry = NaN(nA, 1);
I_peak_PT = NaN(nA, 1);

for it = 1:nA
    TK = double(aTbl.T_K(it));
    [~, ip] = ismember(TK, temps);
    if ip < 1
        continue
    end
    pRow = PT(ip, :);
    if ~localRowValidPT(pRow)
        continue
    end
    obs = localPTGeometryObservables(currents(:), pRow(:));
    spread90_50(it) = obs.spread90_50;
    asymmetry(it) = obs.asymmetry;
    I_peak_PT(it) = obs.I_peak_mA;
end

kappa1 = double(aTbl.kappa1(:));
alpha = double(aTbl.alpha(:));
width_PT = NaN(nA, 1);
for it = 1:nA
    TK = double(aTbl.T_K(it));
    j = find(abs(double(sumTbl.T_K(:)) - TK) < 1e-6, 1);
    if ~isempty(j)
        width_PT(it) = double(sumTbl.std_threshold_mA(j));
    end
end

mPT = isfinite(alpha) & isfinite(kappa1) & isfinite(spread90_50) & isfinite(asymmetry);
sig = std(alpha(mPT), 'omitnan');

models = struct('name', {}, 'fn', {}, 'mask', {});
models(end + 1) = struct('name', 'alpha ~ spread90_50 + asymmetry', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.spread90_50(m), tbl.asymmetry(m)], 'mask', mPT);
models(end + 1) = struct('name', 'alpha ~ spread90_50 + asymmetry + kappa1', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.spread90_50(m), tbl.asymmetry(m), tbl.kappa1(m)], 'mask', mPT);
models(end + 1) = struct('name', 'alpha ~ kappa1 + spread90_50', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.kappa1(m), tbl.spread90_50(m)], 'mask', mPT);
models(end + 1) = struct('name', 'alpha ~ kappa1 + asymmetry', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.kappa1(m), tbl.asymmetry(m)], 'mask', mPT);

outTbl = table( ...
    double(aTbl.T_K(:)), alpha, kappa1, ...
    spread90_50, asymmetry, width_PT, I_peak_PT, ...
    'VariableNames', {'T_K', 'alpha', 'kappa1', 'spread90_50', 'asymmetry', 'width_mA_PT', 'I_peak_mA_PT'});

res = table();
for k = 1:numel(models)
    mk = models(k).mask;
    y = alpha(mk);
    X = models(k).fn(outTbl, mk);
    oneRow = localFitReport(models(k).name, y, X);
    res = [res; oneRow]; %#ok<AGROW>
end

idxBase = find(strcmp(res.model, 'alpha ~ spread90_50 + asymmetry'), 1);
idxExt = find(strcmp(res.model, 'alpha ~ spread90_50 + asymmetry + kappa1'), 1);
rmseB = res.loocv_rmse(idxBase);
rmseE = res.loocv_rmse(idxExt);
deltaRmse = rmseB - rmseE;
relImp = deltaRmse / max(rmseB, eps);

mk = models(idxExt).mask;
yE = alpha(mk);
XE = models(idxExt).fn(outTbl, mk);
betaE = XE \ yE;
yhatE = NaN(size(alpha));
yhatE(mk) = XE * betaE;

mkB = models(idxBase).mask;
yB = alpha(mkB);
XB = models(idxBase).fn(outTbl, mkB);
betaB = XB \ yB;
yhatB = NaN(size(alpha));
yhatB(mkB) = XB * betaB;

outTbl.yhat_PT_only = yhatB;
outTbl.yhat_PT_kappa1 = yhatE;
outTbl.residual_PT_only = alpha - yhatB;
outTbl.residual_PT_kappa1 = alpha - yhatE;
writetable(outTbl, outCsv);

% Flags
KAPPA1_IMPROVES_ALPHA = localKappaImproves(rmseB, rmseE, sig);
ALPHA_CLOSED_WITH_PT_AND_KAPPA1 = localClosedFlag(res.pearson_alpha_yhat(idxExt), rmseE, sig);

aM = alpha(mPT);
kM = kappa1(mPT);
sM = spread90_50(mPT);
asM = asymmetry(mPT);
wM = width_PT(mPT);
ipM = I_peak_PT(mPT);
corrRows = { ...
    'kappa1', corr(aM, kM, 'rows', 'complete'), corr(aM, kM, 'type', 'Spearman', 'rows', 'complete'); ...
    'spread90_50', corr(aM, sM, 'rows', 'complete'), corr(aM, sM, 'type', 'Spearman', 'rows', 'complete'); ...
    'asymmetry', corr(aM, asM, 'rows', 'complete'), corr(aM, asM, 'type', 'Spearman', 'rows', 'complete'); ...
    'width_mA_PT', corr(aM, wM, 'rows', 'complete'), corr(aM, wM, 'type', 'Spearman', 'rows', 'complete'); ...
    'I_peak_mA_PT', corr(aM, ipM, 'rows', 'complete'), corr(aM, ipM, 'type', 'Spearman', 'rows', 'complete')};

fid = fopen(outRep, 'w');
assert(fid > 0, 'Cannot write report');
fprintf(fid, '# Alpha from PT + kappa1 (Agent 21C)\n\n');
fprintf(fid, '**Goal:** test `alpha = f(PT features, kappa1)` with PT spreads from `PT_matrix` and `kappa1` from `alpha_structure.csv`.\n\n');
fprintf(fid, '- **alpha / kappa1:** `%s`\n', strrep(alphaPath, '\', '/'));
fprintf(fid, '- **PT_matrix.csv:** `%s`\n', strrep(ptMatrixPath, '\', '/'));
fprintf(fid, '- **PT_summary.csv:** `%s`\n\n', strrep(ptSummaryPath, '\', '/'));

fprintf(fid, '## Feature definitions (per T)\n\n');
fprintf(fid, '- **spread90_50**, **asymmetry**, **I_peak_mA_PT** (argmax on PT PMF): from `PT_matrix` row.\n');
fprintf(fid, '- **width_mA_PT**: `std_threshold_mA` from `PT_summary` (PT-side width).\n');
fprintf(fid, '- **kappa1**, **alpha**: from `alpha_structure.csv`.\n\n');

fprintf(fid, '## Univariate correlations (alpha vs predictor, PT-valid rows)\n\n');
fprintf(fid, '| predictor | Pearson | Spearman |\n');
fprintf(fid, '|---|---:|---:|\n');
for r = 1:size(corrRows, 1)
    fprintf(fid, '| %s | %.6g | %.6g |\n', corrRows{r, 1}, corrRows{r, 2}, corrRows{r, 3});
end
fprintf(fid, '\n');

fprintf(fid, '## Baseline vs extended (main comparison)\n\n');
fprintf(fid, 'Nested models per spec: **baseline** = PT spread + asymmetry only; **extended** adds **kappa1**. ');
fprintf(fid, '(This is not necessarily the same as the global best model in Agent 20B, which searches additional predictors.)\n\n');
fprintf(fid, '| model | n | LOOCV RMSE | Pearson | Spearman | max leverage |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|\n');
fprintf(fid, '| %s | %d | %.6g | %.6g | %.6g | %.6g |\n', ...
    res.model{idxBase}, res.n(idxBase), res.loocv_rmse(idxBase), ...
    res.pearson_alpha_yhat(idxBase), res.spearman_alpha_yhat(idxBase), res.max_leverage(idxBase));
fprintf(fid, '| %s | %d | %.6g | %.6g | %.6g | %.6g |\n', ...
    res.model{idxExt}, res.n(idxExt), res.loocv_rmse(idxExt), ...
    res.pearson_alpha_yhat(idxExt), res.spearman_alpha_yhat(idxExt), res.max_leverage(idxExt));
fprintf(fid, '\n');
fprintf(fid, '- **Delta LOOCV RMSE** (baseline − extended): **%.6g**\n', deltaRmse);
fprintf(fid, '- **Relative improvement**: **%.4g** (fraction of baseline RMSE removed)\n', relImp);
fprintf(fid, '- **std(alpha)** on PT-valid rows: **%.6g**\n\n', sig);

fprintf(fid, '## Minimal alternatives\n\n');
fprintf(fid, '| model | n | LOOCV RMSE | Pearson | Spearman |\n');
fprintf(fid, '|---|---:|---:|---:|---:|\n');
for k = 1:height(res)
    if k == idxBase || k == idxExt
        continue
    end
    fprintf(fid, '| %s | %d | %.6g | %.6g | %.6g |\n', ...
        res.model{k}, res.n(k), res.loocv_rmse(k), res.pearson_alpha_yhat(k), res.spearman_alpha_yhat(k));
end
fprintf(fid, '\n');

fprintf(fid, '## Extended model (PT + kappa1) formula\n\n');
fprintf(fid, '%s\n\n', localFormulaStringExtended(betaE));

fprintf(fid, '## Final flags\n\n');
fprintf(fid, '- **KAPPA1_IMPROVES_ALPHA** = **%s**\n', KAPPA1_IMPROVES_ALPHA);
fprintf(fid, '- **ALPHA_CLOSED_WITH_PT_AND_KAPPA1** = **%s**\n', ALPHA_CLOSED_WITH_PT_AND_KAPPA1);
fprintf(fid, '\n*Auto-generated by `analysis/run_alpha_with_kappa1_agent21c.m`.*\n');
fclose(fid);

fprintf('Wrote %s\n%s\n', outCsv, outRep);
fprintf('KAPPA1_IMPROVES_ALPHA = %s\nALPHA_CLOSED_WITH_PT_AND_KAPPA1 = %s\n', ...
    KAPPA1_IMPROVES_ALPHA, ALPHA_CLOSED_WITH_PT_AND_KAPPA1);
end

%% --- helpers (aligned with run_alpha_from_pt_agent20b.m) ---

function obs = localPTGeometryObservables(I, p)
p = double(p(:));
I = double(I(:));
obs = struct('spread90_50', NaN, 'spread75_25', NaN, 'asymmetry', NaN, ...
    'skew_weighted', NaN, 'mean_minus_median', NaN, 'I_peak_mA', NaN);
s = sum(p);
if ~(s > 0) || all(~isfinite(p))
    return
end
pn = p / s;
mu = sum(I .* pn);
q25 = localDiscreteQuantile(I, pn, 0.25);
q50 = localDiscreteQuantile(I, pn, 0.50);
q75 = localDiscreteQuantile(I, pn, 0.75);
q90 = localDiscreteQuantile(I, pn, 0.90);
v2 = sum(pn .* (I - mu).^2);
v3 = sum(pn .* (I - mu).^3);
sig = sqrt(max(v2, 0));
obs.spread90_50 = q90 - q50;
obs.spread75_25 = q75 - q25;
obs.asymmetry = (q90 - q50) - (q50 - q25);
obs.mean_minus_median = mu - q50;
if sig > 1e-12
    obs.skew_weighted = v3 / (sig^3);
else
    obs.skew_weighted = NaN;
end
[~, imx] = max(pn);
obs.I_peak_mA = I(imx);
end

function q = localDiscreteQuantile(I, p, u)
c = cumsum(p);
if u <= c(1)
    q = I(1);
    return
end
if u >= c(end)
    q = I(end);
    return
end
idx = find(c >= u, 1, 'first');
if idx <= 1
    q = I(1);
    return
end
c0 = c(idx - 1);
c1 = c(idx);
if c1 <= c0
    q = I(idx);
    return
end
t = (u - c0) / (c1 - c0);
q = I(idx - 1) + t * (I(idx) - I(idx - 1));
end

function ok = localRowValidPT(pRow)
pRow = double(pRow(:));
ok = all(isfinite(pRow)) && sum(pRow) > 1e-12;
end

function [temps, currents, PT] = localLoadPTMatrix(ptMatrixPath)
tbl = readtable(ptMatrixPath, 'VariableNamingRule', 'preserve');
assert(ismember('T_K', tbl.Properties.VariableNames), 'T_K missing');
vn = tbl.Properties.VariableNames;
ptNames = setdiff(vn, {'T_K'}, 'stable');
temps = double(tbl.T_K(:));
PT = double(table2array(tbl(:, ptNames)));
currents = localParseCurrents(ptNames);
[currents, io] = sort(currents(:), 'ascend');
PT = PT(:, io);
[temps, it] = sort(temps(:), 'ascend');
PT = PT(it, :);
end

function currents = localParseCurrents(varNames)
n = numel(varNames);
currents = NaN(n, 1);
for i = 1:n
    vName = string(varNames{i});
    token = regexp(vName, '^Ith_(.*)_mA$', 'tokens', 'once');
    assert(~isempty(token), 'Bad column %s', vName);
    raw = string(token{1});
    candidates = [raw; strrep(raw, "_", "."); strrep(raw, "_", ""); ...
        regexprep(raw, '_+', '.'); regexprep(raw, '_+', '')];
    val = NaN;
    for kk = 1:numel(candidates)
        val = str2double(candidates(kk));
        if isfinite(val)
            break
        end
    end
    assert(isfinite(val), 'Parse fail %s', vName);
    currents(i) = val;
end
end

function row = localFitReport(name, y, X)
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
    {char(name)}, n, loocv_rmse, pear, spear, maxlev, ...
    'VariableNames', {'model', 'n', 'loocv_rmse', 'pearson_alpha_yhat', ...
    'spearman_alpha_yhat', 'max_leverage'});
end

function s = localFormulaStringExtended(beta)
s = sprintf(['alpha = %.6g + %.6g * spread90_50 + %.6g * asymmetry + ' ...
    '%.6g * kappa1'], beta(1), beta(2), beta(3), beta(4));
end

function f = localKappaImproves(rmseB, rmseE, sig)
if ~isfinite(rmseB) || ~isfinite(rmseE) || ~isfinite(sig)
    f = 'NO';
    return
end
if rmseE >= rmseB
    f = 'NO';
    return
end
absGain = rmseB - rmseE;
relGain = absGain / max(rmseB, eps);
% Meaningful if >=3% relative drop or >=5% of alpha scale (same order as Agent 20B thresholds)
if relGain >= 0.03 || absGain >= 0.05 * sig
    f = 'YES';
else
    f = 'NO';
end
end

function f = localClosedFlag(r, rmse, sig)
if ~isfinite(r) || ~isfinite(rmse) || ~isfinite(sig) || sig < 1e-12
    f = 'NO';
    return
end
if abs(r) >= 0.72 && rmse <= 0.55 * sig
    f = 'YES';
elseif abs(r) >= 0.45 || rmse <= 0.75 * sig
    f = 'PARTIAL';
else
    f = 'NO';
end
end
