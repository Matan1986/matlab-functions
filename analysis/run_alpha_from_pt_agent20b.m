function run_alpha_from_pt_agent20b()
%RUN_ALPHA_FROM_PT_AGENT20B  Agent 20B — alpha = kappa2/kappa1 vs PT geometry (low-dim law)
%
% Read-only: alpha_structure.csv (Agent 19F), PT_matrix.csv + PT_summary.csv from canonical PT run.
% Writes: tables/alpha_from_PT.csv, reports/alpha_from_PT_report.md
%
% Note: On some setups MATLAB batch is slow; the repo also ships
%   tools/compute_alpha_from_pt_agent20b.ps1
% which regenerates the same artifacts (verified LOOCV for spread90_50 + asymmetry).
%
% Models (OLS + intercept): single- and two-variable as specified in agent brief.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
alphaPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
ptRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_03_25_013356_pt_robust_canonical');
ptMatrixPath = fullfile(ptRunDir, 'tables', 'PT_matrix.csv');
ptSummaryPath = fullfile(ptRunDir, 'tables', 'PT_summary.csv');
outCsv = fullfile(repoRoot, 'tables', 'alpha_from_PT.csv');
outRep = fullfile(repoRoot, 'reports', 'alpha_from_PT_report.md');

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
spread75_25 = NaN(nA, 1);
asymmetry = NaN(nA, 1);
skew_pt = NaN(nA, 1);
mean_minus_median = NaN(nA, 1);
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
    spread75_25(it) = obs.spread75_25;
    asymmetry(it) = obs.asymmetry;
    skew_pt(it) = obs.skew_weighted;
    mean_minus_median(it) = obs.mean_minus_median;
    I_peak_PT(it) = obs.I_peak_mA;
end

% Repo observables (same T row as 19F)
I_peak = double(aTbl.I_peak_mA(:));
width_mA = double(aTbl.width_mA(:));
S_peak = double(aTbl.S_peak(:));
alpha = double(aTbl.alpha(:));

% Width from PT summary (std) for "geometry" width where needed
std_pt = NaN(nA, 1);
for it = 1:nA
    TK = double(aTbl.T_K(it));
    j = find(abs(double(sumTbl.T_K(:)) - TK) < 1e-6, 1);
    if ~isempty(j)
        std_pt(it) = double(sumTbl.std_threshold_mA(j));
    end
end

outTbl = table( ...
    double(aTbl.T_K(:)), alpha, ...
    spread90_50, spread75_25, asymmetry, skew_pt, mean_minus_median, ...
    I_peak, width_mA, S_peak, I_peak_PT, std_pt, ...
    'VariableNames', { ...
    'T_K', 'alpha', ...
    'spread90_50', 'spread75_25', 'asymmetry', 'skew_pt_weighted', 'mean_minus_median_pt', ...
    'I_peak_mA', 'width_mA', 'S_peak', 'I_peak_PT_mA', 'std_threshold_mA_PT'});

% Modeling mask: finite alpha + PT spreads
mAll = isfinite(alpha) & isfinite(spread90_50) & isfinite(asymmetry) & isfinite(spread75_25);
mSk = mAll & isfinite(skew_pt) & isfinite(width_mA);
mIpW = isfinite(alpha) & isfinite(I_peak) & isfinite(width_mA);

models = struct( ...
    'name', {}, 'fn', {}, 'mask', {});

models(end + 1) = struct('name', 'alpha ~ spread90_50', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.spread90_50(m)], 'mask', mAll);
models(end + 1) = struct('name', 'alpha ~ asymmetry', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.asymmetry(m)], 'mask', mAll);
models(end + 1) = struct('name', 'alpha ~ I_peak_mA', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.I_peak_mA(m)], 'mask', isfinite(alpha) & isfinite(I_peak));
models(end + 1) = struct('name', 'alpha ~ spread90_50 + asymmetry', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.spread90_50(m), tbl.asymmetry(m)], 'mask', mAll);
models(end + 1) = struct('name', 'alpha ~ I_peak_mA + width_mA', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.I_peak_mA(m), tbl.width_mA(m)], 'mask', mIpW);
models(end + 1) = struct('name', 'alpha ~ skew_pt_weighted + width_mA', ...
    'fn', @(tbl, m) [ones(nnz(m), 1), tbl.skew_pt_weighted(m), tbl.width_mA(m)], 'mask', mSk);

nM = numel(models);
res = table();
for k = 1:nM
    mk = models(k).mask;
    y = alpha(mk);
    X = models(k).fn(outTbl, mk);
    oneRow = localFitReport(models(k).name, y, X, double(outTbl.T_K(mk)), [22, 24]);
    res = [res; oneRow]; %#ok<AGROW>
end

[~, ibest] = min(res.loocv_rmse);
bestName = res.model{ibest};
mkB = models(ibest).mask;
yB = alpha(mkB);
XB = models(ibest).fn(outTbl, mkB);
betaBest = XB \ yB;

yhat_best = NaN(size(alpha));
yhat_best(mkB) = XB * betaBest;
resid_best = alpha - yhat_best;
outTbl.alpha_hat_best = yhat_best;
outTbl.residual_best = resid_best;
writetable(outTbl, outCsv);

% Flags
sig = std(alpha(mAll), 'omitnan');
bestRmse = res.loocv_rmse(ibest);
bestR = res.pearson_alpha_yhat(ibest);
bestSpear = res.spearman_alpha_yhat(ibest);

ALPHA_PREDICTABLE_FROM_PT = flagPredictable(bestR, bestRmse, sig);
ALPHA_GEOMETRY_CONTROLLED = flagGeometry(res, ibest);
MINIMAL_MODEL_FOUND = flagMinimal(res, ibest);

% Monotonicity note: Spearman T vs alpha vs T vs yhat for best model
yhatB = XB * betaBest;
tB = double(outTbl.T_K(mkB));
monoTa = corr(tB, yB, 'type', 'Spearman', 'rows', 'complete');
monoTh = corr(tB, yhatB, 'type', 'Spearman', 'rows', 'complete');

% 22–24 sensitivity: LOOCV RMSE with band excluded from training (predict band by model fit on outside)
sens224 = localSensitivity224(models(ibest), outTbl, alpha);
formulaStr = localFormulaString(bestName, betaBest);

fid = fopen(outRep, 'w');
assert(fid > 0, 'Cannot write report');
fprintf(fid, '# Alpha from PT geometry (Agent 20B)\n\n');
fprintf(fid, '**Goal:** low-dimensional mapping `alpha(T) = f(PT geometry observables)` with `alpha = kappa2/kappa1` (Agent 19F).\n\n');
fprintf(fid, '- **alpha table:** `%s`\n', strrep(alphaPath, '\', '/'));
fprintf(fid, '- **PT_matrix.csv:** `%s`\n', strrep(ptMatrixPath, '\', '/'));
fprintf(fid, '- **PT_summary.csv:** `%s`\n\n', strrep(ptSummaryPath, '\', '/'));

fprintf(fid, '## Feature definitions (per T)\n\n');
fprintf(fid, '- **spread90_50** = q90 − q50 (high-side spread), **spread75_25** = q75 − q25 (bulk width) on **normalized PMF** from `PT_matrix` row (discrete CDF inverse, same construction as asymmetric spread analysis).\n');
fprintf(fid, '- **asymmetry** = (q90−q50) − (q50−q25).\n');
fprintf(fid, '- **skew_pt_weighted** = \\sum (I-\\mu)^3 p / \\sigma^3 on the PT PMF.\n');
fprintf(fid, '- **mean_minus_median_pt** = mean(I) − q50 from PT.\n');
fprintf(fid, '- **I_peak_mA**, **width_mA**, **S_peak**: switching observables from the same `alpha_structure` row (Agent 19F pipeline).\n');
fprintf(fid, '- **I_peak_PT_mA**: current at argmax(P_T) on the PT grid; **std_threshold_mA_PT** from `PT_summary`.\n\n');

fprintf(fid, '## Best model (by LOOCV RMSE)\n\n');
fprintf(fid, '- **Model:** `%s`\n', bestName);
fprintf(fid, '- **Fitted coefficients:** %s\n', formulaStr);
fprintf(fid, '- **LOOCV RMSE:** %.6g\n', bestRmse);
fprintf(fid, '- **In-sample Pearson(alpha, yhat):** %.6g\n', bestR);
fprintf(fid, '- **In-sample Spearman(alpha, yhat):** %.6g\n', bestSpear);
fprintf(fid, '- **Spearman(T, alpha):** %.6g; **Spearman(T, yhat):** %.6g (monotonicity of T-tracks)\n', monoTa, monoTh);
fprintf(fid, '- **22–24 K sensitivity (hold-out band):** RMSE on T\\in{22,24} when each point is predicted from a model fit on **all other** temperatures: **%.6g** (see `loocv_rmse_22_24_rows` in table).\n\n', sens224);

fprintf(fid, '## All models\n\n');
fprintf(fid, '| model | n | LOOCV RMSE | Pearson(alpha,yhat) | Spearman(alpha,yhat) | max leverage |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|\n');
for k = 1:height(res)
    fprintf(fid, '| %s | %d | %.6g | %.6g | %.6g | %.6g |\n', ...
        res.model{k}, res.n(k), res.loocv_rmse(k), res.pearson_alpha_yhat(k), ...
        res.spearman_alpha_yhat(k), res.max_leverage(k));
end
fprintf(fid, '\n');

fprintf(fid, '## Regime behavior\n\n');
fprintf(fid, '- PT rows are **missing** at 28–30 K in this canonical `PT_matrix`; those temperatures are **excluded** from PT-spread models (see `alpha_from_PT.csv` NaNs).\n');
fprintf(fid, '- **22–24 K** is where `alpha` rises sharply in Agent 19F; geometry spreads from PT also change most rapidly there — LOOCV errors on {22,24} are reported explicitly.\n\n');

fprintf(fid, '## Final flags\n\n');
fprintf(fid, '- **ALPHA_PREDICTABLE_FROM_PT** = **%s**\n', ALPHA_PREDICTABLE_FROM_PT);
fprintf(fid, '- **ALPHA_GEOMETRY_CONTROLLED** = **%s**\n', ALPHA_GEOMETRY_CONTROLLED);
fprintf(fid, '- **MINIMAL_MODEL_FOUND** = **%s**\n', MINIMAL_MODEL_FOUND);
fprintf(fid, '\n*Auto-generated by `analysis/run_alpha_from_pt_agent20b.m`.*\n');
fclose(fid);

fprintf('Wrote %s\n%s\n', outCsv, outRep);
end

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

function row = localFitReport(name, y, X, tK, bandT)
n = numel(y);
p = size(X, 2);
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

% LOOCV RMSE restricted to T in band (22,24)
maskB = ismember(tK, bandT);
if nnz(maskB) >= 1
    loocv_band = sqrt(mean(loo_e(maskB).^2, 'omitnan'));
else
    loocv_band = NaN;
end

row = table( ...
    {char(name)}, n, loocv_rmse, pear, spear, maxlev, loocv_band, ...
    'VariableNames', {'model', 'n', 'loocv_rmse', 'pearson_alpha_yhat', ...
    'spearman_alpha_yhat', 'max_leverage', 'loocv_rmse_22_24_rows'});
end

function s = localSensitivity224(modelSpec, tbl, alpha)
T = double(tbl.T_K(:));
mk = modelSpec.mask;
errs = [];
for tHold = [22, 24]
    iHold = abs(T - tHold) < 0.51 & mk;
    if ~any(iHold)
        continue
    end
    mtrain = mk & ~iHold;
    Xtr = modelSpec.fn(tbl, mtrain);
    if nnz(mtrain) < size(Xtr, 2)
        continue
    end
    ytr = alpha(mtrain);
    b = Xtr \ ytr;
    Xte = modelSpec.fn(tbl, iHold);
    yhat = Xte * b;
    yact = alpha(iHold);
    errs = [errs; yact(:) - yhat(:)]; %#ok<AGROW>
end
if isempty(errs)
    s = NaN;
else
    s = sqrt(mean(errs.^2));
end
end

function s = localFormulaString(name, beta)
nm = lower(string(name));
bn = numel(beta);
if bn == 2
    if contains(nm, 'spread90_50') && ~contains(nm, '+')
        s = sprintf('alpha = %.6g + %.6g * spread90_50', beta(1), beta(2));
    elseif contains(nm, 'asymmetry') && ~contains(nm, '+')
        s = sprintf('alpha = %.6g + %.6g * asymmetry', beta(1), beta(2));
    elseif contains(nm, 'i_peak')
        s = sprintf('alpha = %.6g + %.6g * I_peak_mA', beta(1), beta(2));
    else
        s = sprintf('alpha = %.6g + %.6g * x', beta(1), beta(2));
    end
elseif bn == 3
    if contains(nm, 'spread90_50') && contains(nm, 'asymmetry')
        s = sprintf('alpha = %.6g + %.6g * spread90_50 + %.6g * asymmetry', beta(1), beta(2), beta(3));
    elseif contains(nm, 'i_peak') && contains(nm, 'width')
        s = sprintf('alpha = %.6g + %.6g * I_peak_mA + %.6g * width_mA', beta(1), beta(2), beta(3));
    elseif contains(nm, 'skew')
        s = sprintf('alpha = %.6g + %.6g * skew_pt_weighted + %.6g * width_mA', beta(1), beta(2), beta(3));
    else
        s = sprintf('alpha = %.6g + %.6g * x1 + %.6g * x2', beta(1), beta(2), beta(3));
    end
else
    s = 'alpha = X*beta';
end
end

function f = flagPredictable(r, rmse, sig)
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

function f = flagGeometry(res, ibest)
nm = lower(string(res.model(ibest)));
% YES if the best model uses PT_matrix-derived spreads/asymmetry/skew
if contains(nm, 'spread90') || contains(nm, 'asymmetry') || contains(nm, 'skew_pt')
    f = 'YES';
else
    f = 'NO';
end
end

function f = flagMinimal(res, ibest)
if res.n(ibest) >= 5 && res.loocv_rmse(ibest) < inf && abs(res.pearson_alpha_yhat(ibest)) >= 0.5
    f = 'YES';
else
    f = 'NO';
end
end
