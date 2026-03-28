function run_alpha_res_transition_agent22a(varargin)
%RUN_ALPHA_RES_TRANSITION_AGENT22A  Agent 22A — alpha_res as transition / regime coordinate.
%
%   Uses existing tables only (no decomposition recomputation).
%   alpha_res: prefer alpha_decomposition.csv (alpha_res), else residual_best from
%   alpha_from_PT.csv. T_K aligned with barrier_descriptors.csv when available.
%
%   Writes:
%     tables/alpha_res_vs_transition.csv
%     figures/alpha_res_vs_dT.png (+ alpha_res_vs_dT.fig)
%     reports/alpha_res_transition_report.md
%
%   Name-value:
%     'repoRoot' — repo root (default: two levels up from this file)
%     'decompPath', 'alphaPtPath', 'barrierPath' — CSV overrides

opts = localParseOpts(varargin{:});
repoRoot = opts.repoRoot;

decompPath = opts.decompPath;
ptPath = opts.alphaPtPath;
barrierPath = opts.barrierPath;

assert(isfile(decompPath), 'Missing %s', decompPath);
assert(isfile(ptPath), 'Missing %s', ptPath);
if ~isfile(barrierPath)
    barrierPath = localFindNewestBarrier(repoRoot);
end
assert(isfile(barrierPath), 'barrier_descriptors.csv not found (pass barrierPath).');

for d = {fullfile(repoRoot, 'tables'), fullfile(repoRoot, 'figures'), fullfile(repoRoot, 'reports')}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

dec = readtable(decompPath, 'VariableNamingRule', 'preserve');
apt = readtable(ptPath, 'VariableNamingRule', 'preserve');
bar = readtable(barrierPath, 'VariableNamingRule', 'preserve');

assert(ismember('T_K', dec.Properties.VariableNames));
assert(ismember('alpha_res', dec.Properties.VariableNames));
assert(ismember('residual_best', apt.Properties.VariableNames));
Tb = double(bar.T_K(:));

Tdec = double(dec.T_K(:));
resDec = double(dec.alpha_res(:));
if ismember('PT_geometry_valid', dec.Properties.VariableNames)
    vg = double(dec.PT_geometry_valid(:)) ~= 0;
else
    vg = true(size(Tdec));
end

Tpt = double(apt.T_K(:));
resPt = double(apt.residual_best(:));

n = numel(Tdec);
alphaRes = NaN(n, 1);
src = strings(n, 1);
for i = 1:n
    useDec = isfinite(resDec(i)) && vg(i);
    if useDec
        alphaRes(i) = resDec(i);
        src(i) = "decomposition";
    else
        j = find(abs(Tpt - Tdec(i)) < 1e-9, 1);
        if ~isempty(j) && isfinite(resPt(j))
            alphaRes(i) = resPt(j);
            src(i) = "alpha_from_PT_fallback";
        else
            src(i) = "missing";
        end
    end
end

T0 = 23;
dT = Tdec - T0;
adT = abs(dT);
reg = strings(n, 1);
for i = 1:n
    if Tdec(i) < 22
        reg(i) = "low";
    elseif Tdec(i) <= 24
        reg(i) = "mid";
    else
        reg(i) = "high";
    end
end

inBarrier = false(n, 1);
for i = 1:n
    inBarrier(i) = any(abs(Tb - Tdec(i)) < 1e-9);
end

absA = abs(alphaRes);
fin = isfinite(absA);
idxFin = find(fin);
rankAbs = NaN(n, 1);
if ~isempty(idxFin)
    [~, ordFin] = sort(absA(fin), 'descend');
    for ri = 1:numel(ordFin)
        rankAbs(idxFin(ordFin(ri))) = ri;
    end
end

% Analysis mask: finite alpha_res and present in barrier (T_K consistency)
mFit = isfinite(alphaRes) & inBarrier;
Tfit = Tdec(mFit);
y = alphaRes(mFit);
dTf = dT(mFit);
adTf = adT(mFit);
regf = reg(mFit);

% Correlations on fit set
[rp_ad, rs_ad, nad] = localCorrPair(y, adTf);
[rp_dt, rs_dt, ndt] = localCorrPair(y, dTf);

% Piecewise means / RMS
regs = ["low", "mid", "high"];
nReg = numel(regs);
meanReg = NaN(nReg, 1);
rmsReg = NaN(nReg, 1);
nRegC = zeros(nReg, 1);
for r = 1:nReg
    mm = mFit & reg == regs(r);
    nRegC(r) = nnz(mm);
    if nRegC(r) > 0
        yy = alphaRes(mm);
        meanReg(r) = mean(yy, 'omitnan');
        rmsReg(r) = sqrt(mean(yy.^2, 'omitnan'));
    end
end

% Models (in-sample design matrices)
nObs = numel(y);
one = ones(nObs, 1);

% Model 1: y ~ 1 + |dT|
X1 = [one, adTf];
[b1, ~, ~, ~] = localSafeLm(y, X1);
R2_1 = localR2(y, X1 * b1);

% Model 2: piecewise dummies, mid reference
Ilow = double(strcmp(string(regf), "low"));
Ihigh = double(strcmp(string(regf), "high"));
X2 = [one, Ilow, Ihigh];
[b2, ~, ~, ~] = localSafeLm(y, X2);
R2_2 = localR2(y, X2 * b2);

% Model 3: quadratic in dT
X3 = [one, dTf, dTf.^2];
[b3, ~, ~, ~] = localSafeLm(y, X3);
R2_3 = localR2(y, X3 * b3);

% Constant
mu0 = mean(y, 'omitnan');
R2_0 = 0;

% LOOCV RMSE
rmseCv1 = localLoocvLinear(y, X1);
rmseCv2 = localLoocvLinear(y, X2);
rmseCv3 = localLoocvLinear(y, X3);
rmseCv0 = localLoocvConstant(y);

imp1 = rmseCv0 - rmseCv1;
imp2 = rmseCv0 - rmseCv2;
imp3 = rmseCv0 - rmseCv3;

% Peak-at-transition: |alpha_res| by regime (on full finite rows in barrier)
meanAbs = NaN(nReg, 1);
for r = 1:nReg
    mm = mFit & reg == regs(r);
    if nnz(mm) > 0
        meanAbs(r) = mean(abs(alphaRes(mm)), 'omitnan');
    end
end
[~, idxMaxMeanAbs] = max(meanAbs);
peakReg = regs(idxMaxMeanAbs);

% Top |alpha_res| temperatures (among mFit)
if numel(y) >= 1
    [~, ordY] = sort(abs(y), 'descend');
    ntop = min(5, numel(y));
    Ttop = Tfit(ordY(1:ntop));
else
    Ttop = [];
end
maxAbsY = max(abs(y), [], 'omitnan');
idxMaxY = find(abs(y) == maxAbsY, 1, 'first');
if ~isempty(idxMaxY)
    T_at_max_abs = Tfit(idxMaxY);
else
    T_at_max_abs = NaN;
end
peakAtBand = isfinite(T_at_max_abs) && T_at_max_abs >= 22 && T_at_max_abs <= 24;

% Flags (documented thresholds)
thrCorr = 0.45;
thrR2 = 0.2;
thrImp = 0.02;
okCorr = (isfinite(rp_ad) && abs(rp_ad) >= thrCorr) || (isfinite(rs_ad) && abs(rs_ad) >= thrCorr);
okR2 = max([R2_1, R2_2, R2_3], [], 'omitnan') >= thrR2;
okLoocv = max([imp1, imp2, imp3], [], 'omitnan') >= thrImp;
ALPHA_RES_IS_DISTANCE_TO_TRANSITION = localYesNo(okCorr || (okR2 && okLoocv));

ALPHA_RES_PEAKS_AT_TRANSITION = localYesNo(strcmp(peakReg, "mid") || peakAtBand);

bestR2 = max([R2_1, R2_2, R2_3], [], 'omitnan');
TRANSITION_MODEL_EXPLAINS_RESIDUAL = localYesNo(bestR2 >= 0.25 || max([imp1, imp2, imp3], [], 'omitnan') >= 0.05);

% --- CSV: per-row + summary key-value rows
rowKind = repmat("sample", n, 1);
Tout = Tdec;
outTbl = table(Tout, alphaRes, src, dT, adT, reg, inBarrier, rowKind, rankAbs, ...
    'VariableNames', {'T_K', 'alpha_res', 'res_source', 'dT_K', 'abs_dT_K', 'regime', 'T_K_in_barrier', 'row_kind', 'rank_abs_alpha_res_desc'});

metrics = { ...
    'n_fit_barrier'; 'corr_pearson_alpha_res_abs_dT'; 'corr_spearman_alpha_res_abs_dT'; ...
    'corr_pearson_alpha_res_dT'; 'corr_spearman_alpha_res_dT'; ...
    'mean_alpha_res_regime_low'; 'mean_alpha_res_regime_mid'; 'mean_alpha_res_regime_high'; ...
    'rms_alpha_res_regime_low'; 'rms_alpha_res_regime_mid'; 'rms_alpha_res_regime_high'; ...
    'n_regime_low'; 'n_regime_mid'; 'n_regime_high'; ...
    'R2_model_abs_dT'; 'R2_model_regime_dummy'; 'R2_model_quadratic_dT'; ...
    'LOOCV_RMSE_abs_dT'; 'LOOCV_RMSE_regime_dummy'; 'LOOCV_RMSE_quadratic_dT'; 'LOOCV_RMSE_constant'; ...
    'LOOCV_improvement_abs_dT'; 'LOOCV_improvement_regime_dummy'; 'LOOCV_improvement_quadratic_dT'; ...
    'mean_abs_alpha_res_regime_low'; 'mean_abs_alpha_res_regime_mid'; 'mean_abs_alpha_res_regime_high'; ...
    'peak_mean_abs_regime'; 'ALPHA_RES_IS_DISTANCE_TO_TRANSITION'; ...
    'ALPHA_RES_PEAKS_AT_TRANSITION'; 'TRANSITION_MODEL_EXPLAINS_RESIDUAL' ...
    };
vals = { ...
    nObs; rp_ad; rs_ad; rp_dt; rs_dt; ...
    meanReg(1); meanReg(2); meanReg(3); ...
    rmsReg(1); rmsReg(2); rmsReg(3); ...
    nRegC(1); nRegC(2); nRegC(3); ...
    R2_1; R2_2; R2_3; ...
    rmseCv1; rmseCv2; rmseCv3; rmseCv0; ...
    imp1; imp2; imp3; ...
    meanAbs(1); meanAbs(2); meanAbs(3); ...
    char(peakReg); ALPHA_RES_IS_DISTANCE_TO_TRANSITION; ...
    ALPHA_RES_PEAKS_AT_TRANSITION; TRANSITION_MODEL_EXPLAINS_RESIDUAL ...
    };
valStr = cell(size(metrics));
for ii = 1:numel(vals)
    v = vals{ii};
    if isnumeric(v) || islogical(v)
        valStr{ii} = sprintf('%.12g', double(v));
    else
        valStr{ii} = char(string(v));
    end
end
meta = table(metrics, valStr, 'VariableNames', {'metric', 'value'});

outCsv = fullfile(repoRoot, 'tables', 'alpha_res_vs_transition.csv');
writetable(outTbl, outCsv);
fidm = fopen(outCsv, 'a');
assert(fidm > 0, 'Cannot append %s', outCsv);
fprintf(fidm, '\n');
fprintf(fidm, 'metric,value\n');
for ii = 1:height(meta)
    fprintf(fidm, '%s,%s\n', meta.metric{ii}, meta.value{ii});
end
fclose(fidm);

% --- Figure
base_name = 'alpha_res_vs_dT';
fig = figure('Name', base_name, 'NumberTitle', 'off', 'Position', [100 100 720 520]);
hold on;
scatter(adTf, y, 80, dTf, 'filled');
colormap(parula);
cb = colorbar;
cb.Label.String = 'dT = T - 23 (K)';
xlabel('|dT| = |T - 23 K| (K)');
ylabel('\alpha_{res}');
set(gca, 'FontSize', 14);
grid on;
box on;
hold off;

figPathPng = fullfile(repoRoot, 'figures', [base_name '.png']);
figPathFig = fullfile(repoRoot, 'figures', [base_name '.fig']);
exportgraphics(fig, figPathPng, 'Resolution', 300);
savefig(fig, figPathFig);

% --- Report
outRep = fullfile(repoRoot, 'reports', 'alpha_res_transition_report.md');
fid = fopen(outRep, 'w');
assert(fid > 0, 'Cannot write %s', outRep);
fprintf(fid, '# Alpha residual vs transition coordinate (Agent 22A)\n\n');
fprintf(fid, '**Goal:** test whether `alpha_res` behaves as a **transition coordinate** / distance-to-regime variable relative to the 22--24 K band (center **T = 23 K**).\n\n');
fprintf(fid, '- **alpha_res:** prefer `tables/alpha_decomposition.csv` (`alpha_res`), else `residual_best` from `tables/alpha_from_PT.csv`.\n');
fprintf(fid, '- **Barrier alignment:** analysis uses rows with `T_K` present in `%s` (inner consistency).\n', strrep(barrierPath, '\', '/'));
fprintf(fid, '- **Fit sample size (barrier-aligned, finite alpha_res):** %d\n\n', nObs);

fprintf(fid, '## Transition-centered coordinates\n\n');
fprintf(fid, '- `dT = T_K - 23`, `|dT|`, regimes: **low** (T < 22), **mid** (22 ≤ T ≤ 24), **high** (T > 24).\n\n');

fprintf(fid, '## Correlations (barrier-aligned finite sample)\n\n');
fprintf(fid, '| pair | Pearson | Spearman | n |\n');
fprintf(fid, '|---|---:|---:|---:|\n');
fprintf(fid, '| alpha_res vs |dT| | %.6g | %.6g | %d |\n', rp_ad, rs_ad, nad);
fprintf(fid, '| alpha_res vs dT | %.6g | %.6g | %d |\n\n', rp_dt, rs_dt, ndt);

fprintf(fid, '## Piecewise statistics (mean and RMS of alpha_res)\n\n');
fprintf(fid, '| regime | n | mean(alpha_res) | RMS(alpha_res) | mean(|alpha_res|) |\n');
fprintf(fid, '|---|---:|---:|---:|---:|\n');
for r = 1:nReg
    fprintf(fid, '| %s | %d | %.6g | %.6g | %.6g |\n', ...
        char(regs(r)), nRegC(r), meanReg(r), rmsReg(r), meanAbs(r));
end
fprintf(fid, '\n');

fprintf(fid, '## Models (in-sample R²)\n\n');
fprintf(fid, '| model | R² |\n');
fprintf(fid, '|---|---:|\n');
fprintf(fid, '| constant mean | 0 (reference) |\n');
fprintf(fid, '| (1) alpha_res ~ |dT| | %.6g |\n', R2_1);
fprintf(fid, '| (2) alpha_res ~ regime dummies (mid ref) | %.6g |\n', R2_2);
fprintf(fid, '| (3) alpha_res ~ dT + dT^2 | %.6g |\n\n', R2_3);

fprintf(fid, '## LOOCV RMSE and improvement vs constant\n\n');
fprintf(fid, '| model | LOOCV RMSE | vs constant (Δ RMSE) |\n');
fprintf(fid, '|---|---:|---:|\n');
fprintf(fid, '| constant | %.6g | 0 |\n', rmseCv0);
fprintf(fid, '| (1) | %.6g | %.6g |\n', rmseCv1, imp1);
fprintf(fid, '| (2) | %.6g | %.6g |\n', rmseCv2, imp2);
fprintf(fid, '| (3) | %.6g | %.6g |\n\n', rmseCv3, imp3);

fprintf(fid, '## Peak-at-transition (|alpha_res|)\n\n');
fprintf(fid, '- **Largest mean(|alpha_res|)** among regimes: **%s**.\n', char(peakReg));
fprintf(fid, '- **Top temperatures by |alpha_res|** (barrier-aligned): ');
if ~isempty(Ttop)
    fprintf(fid, '%s', mat2str(Ttop(:)', 4));
end
fprintf(fid, '\n');
fprintf(fid, '- **T at global max |alpha_res|** (barrier-aligned): %.6g K\n\n', T_at_max_abs);

fprintf(fid, '## Final flags\n\n');
fprintf(fid, '- **ALPHA_RES_IS_DISTANCE_TO_TRANSITION** = **%s** (heuristic: |ρ|≥%.2f vs |dT|, or R²≥%.2f with LOOCV gain ≥ %.2f)\n', ...
    ALPHA_RES_IS_DISTANCE_TO_TRANSITION, thrCorr, thrR2, thrImp);
fprintf(fid, '- **ALPHA_RES_PEAKS_AT_TRANSITION** = **%s** (mid regime has highest mean(|α_res|), or top |α_res| only in 22--24)\n', ALPHA_RES_PEAKS_AT_TRANSITION);
fprintf(fid, '- **TRANSITION_MODEL_EXPLAINS_RESIDUAL** = **%s** (best R² ≥ 0.25 or LOOCV Δ ≥ 0.05)\n\n', TRANSITION_MODEL_EXPLAINS_RESIDUAL);

fprintf(fid, '## Visualization choices\n\n');
fprintf(fid, '- Single scatter: |dT| vs alpha_res, marker color = signed dT (parula colormap).\n');
fprintf(fid, '- Legend: colorbar (n > 6 curves rule N/A); distinct regime not split into separate series to keep one panel.\n');
fprintf(fid, '- Exports: PNG 300 dpi + editable FIG; figure Name matches file base `%s`.\n\n', base_name);

fprintf(fid, '## Artifacts\n\n');
fprintf(fid, '- `%s`\n', strrep(outCsv, '\', '/'));
fprintf(fid, '- `%s`\n', strrep(figPathPng, '\', '/'));
fprintf(fid, '- `%s`\n\n', strrep(outRep, '\', '/'));
fprintf(fid, '*Auto-generated by `analysis/run_alpha_res_transition_agent22a.m`.*\n');
fclose(fid);

fprintf('Wrote:\n%s\n%s\n%s\n%s\n', outCsv, figPathPng, figPathFig, outRep);
end

function s = localYesNo(tf)
if tf
    s = 'YES';
else
    s = 'NO';
end
end

function [b, se, t, p] = localSafeLm(y, X)
b = NaN(size(X, 2), 1);
se = b;
t = b;
p = b;
m = isfinite(y) & all(isfinite(X), 2);
if nnz(m) < size(X, 2)
    return
end
yy = y(m);
XX = X(m, :);
try
    [bb, ~, ~, ~, st] = regress(yy, XX);
    b = bb(:);
    if isfield(st, 'bint')
        se = (st.bint(:, 2) - st.bint(:, 1)) / (2 * 1.96);
    end
catch
    b = XX \ yy;
end
end

function R2 = localR2(y, yhat)
m = isfinite(y) & isfinite(yhat);
if nnz(m) < 2
    R2 = NaN; return
end
yy = y(m) - mean(y(m));
R2 = 1 - sum((y(m) - yhat(m)).^2) / sum(yy.^2);
end

function rmse = localLoocvConstant(y)
n = numel(y);
if n < 2
    rmse = NaN; return
end
e = zeros(n, 1);
for i = 1:n
    yi = y([1:i - 1, i + 1:end]);
    pred = mean(yi, 'omitnan');
    e(i) = y(i) - pred;
end
rmse = sqrt(mean(e.^2, 'omitnan'));
end

function rmse = localLoocvLinear(y, X)
n = numel(y);
p = size(X, 2);
if n < p + 1
    rmse = NaN; return
end
e = zeros(n, 1);
for i = 1:n
    mask = true(n, 1); mask(i) = false;
    yy = y(mask);
    XX = X(mask, :);
    if rank(XX) < p
        b = pinv(XX) * yy;
    else
        b = XX \ yy;
    end
    e(i) = y(i) - X(i, :) * b;
end
rmse = sqrt(mean(e.^2, 'omitnan'));
end

function [rp, rs, n] = localCorrPair(a, b)
m = isfinite(a) & isfinite(b);
n = nnz(m);
if n < 2
    rp = NaN; rs = NaN; return
end
rp = corr(a(m), b(m), 'type', 'Pearson', 'rows', 'complete');
if n >= 3
    rs = corr(a(m), b(m), 'type', 'Spearman', 'rows', 'complete');
else
    rs = NaN;
end
end

function pth = localFindNewestBarrier(repoRoot)
base = fullfile(repoRoot, 'results', 'cross_experiment', 'runs');
pth = '';
if exist(base, 'dir') ~= 7
    return
end
d = dir(base);
best = '';
bestTime = datetime(1970, 1, 1);
for i = 1:numel(d)
    if ~d(i).isdir || strcmp(d(i).name, '.') || strcmp(d(i).name, '..')
        continue
    end
    cand = fullfile(base, d(i).name, 'tables', 'barrier_descriptors.csv');
    if exist(cand, 'file') ~= 2
        continue
    end
    t = dir(cand);
    if isempty(t), continue; end
    tt = datetime(t(1).date);
    if isempty(best) || tt > bestTime
        best = cand;
        bestTime = tt;
    end
end
pth = best;
end

function opts = localParseOpts(varargin)
thisPath = mfilename('fullpath');
opts = struct();
opts.repoRoot = fileparts(fileparts(thisPath));
opts.decompPath = fullfile(opts.repoRoot, 'tables', 'alpha_decomposition.csv');
opts.alphaPtPath = fullfile(opts.repoRoot, 'tables', 'alpha_from_PT.csv');
opts.barrierPath = fullfile(opts.repoRoot, 'results', 'cross_experiment', 'runs', ...
    'run_2026_03_25_031904_barrier_to_relaxation_mechanism', 'tables', 'barrier_descriptors.csv');

if mod(numel(varargin), 2) ~= 0
    error('Name-value pairs expected');
end
for k = 1:2:numel(varargin)
    nm = lower(string(varargin{k}));
    val = varargin{k + 1};
    switch nm
        case "reporoot"
            opts.repoRoot = char(string(val));
        case "decomppath"
            opts.decompPath = char(string(val));
        case "alphaptpath"
            opts.alphaPtPath = char(string(val));
        case "barrierpath"
            opts.barrierPath = char(string(val));
        otherwise
            error('Unknown option: %s', varargin{k});
    end
end
opts.decompPath = fullfile(opts.decompPath);
opts.alphaPtPath = fullfile(opts.alphaPtPath);
opts.barrierPath = char(string(opts.barrierPath));
end
