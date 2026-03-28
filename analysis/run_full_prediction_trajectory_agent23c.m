function run_full_prediction_trajectory_agent23c()
%RUN_FULL_PREDICTION_TRAJECTORY_AGENT23C  Agent 23C — full residual model + trajectory correction
%
% Model (on residual strip deltaS = S - S_CDF in x-grid coordinates):
%   R_hat = kappa1_hat * Phi1 + kappa1_hat * (alpha_geom_hat + alpha_res_hat) * Phi2
% with kappa1_hat from PT tail features (LOOCV), alpha_geom_hat from PT geometry
% (spread90_50 + asymmetry, LOOCV), alpha_res_hat from f(trajectory) (22D/22E-style,
% LOOCV, model chosen by minimum alpha_res LOOCV on the PT-valid cohort).
%
% Comparisons (temperature LOOCV; RMSE on deltaS strip = RMSE on full S(I,T)):
%   PT only: R_hat = 0
%   rank-1:  R_hat = kappa1_hat * Phi1
%   rank-2 geom: R_hat = kappa1_hat * (Phi1 + alpha_geom_hat * Phi2)
%   rank-2 + trajectory: R_hat = kappa1_hat * (Phi1 + (alpha_geom_hat + alpha_res_hat) * Phi2)
%
% Writes:
%   tables/full_prediction_trajectory.csv
%   figures/prediction_comparison.png
%   reports/full_prediction_with_trajectory.md

set(0, 'DefaultFigureVisible', 'off');

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'analysis'));
addpath(analysisDir);

decCfg = struct();
decCfg.runLabel = 'agent23c_full_prediction_trajectory_internal';
decCfg.alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
decCfg.fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
decCfg.ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';
decCfg.canonicalMaxTemperatureK = 30;
decCfg.nXGrid = 220;
decCfg.maxModes = 2;
decCfg.skipFigures = true;

dec = switching_residual_decomposition_analysis(decCfg);

tempsDec = double(dec.temperaturesK(:));
Rall = double(dec.Rall);
phi1 = double(dec.phi(:));
phi2 = double(dec.phi2(:));
if isempty(phi2) || all(~isfinite(phi2))
    error('agent23c:Phi2Missing', 'Mode-2 phi required.');
end

kappaPtPath = fullfile(repoRoot, 'tables', 'kappa1_from_PT.csv');
alphaDecPath = fullfile(repoRoot, 'tables', 'alpha_decomposition.csv');
alphaStructPath = fullfile(repoRoot, 'tables', 'alpha_structure.csv');
assert(exist(kappaPtPath, 'file') == 2, 'Missing %s', kappaPtPath);
assert(exist(alphaDecPath, 'file') == 2, 'Missing %s', alphaDecPath);
assert(exist(alphaStructPath, 'file') == 2, 'Missing %s', alphaStructPath);

kPt = readtable(kappaPtPath, 'VariableNamingRule', 'preserve');
aDec = readtable(alphaDecPath, 'VariableNamingRule', 'preserve');
aStr = readtable(alphaStructPath, 'VariableNamingRule', 'preserve');

tailW = localGetCol(kPt, {'tail_width_q90_q50', 'tail_width'});
sPeakK = localGetCol(kPt, {'S_peak'});
k1Obs = localGetCol(kPt, {'kappa1'});
T_Kk = double(kPt.T_K(:));

spread = double(aDec.spread90_50(:));
asymm = double(aDec.asymmetry(:));
alphaTrue = double(aDec.alpha(:));
alphaResTab = double(aDec.alpha_res(:));
ptValid = logical(aDec.PT_geometry_valid(:));
T_Kd = double(aDec.T_K(:));

matchDec = zeros(numel(T_Kd), 1);
for k = 1:numel(T_Kd)
    j = find(abs(tempsDec - T_Kd(k)) < 1e-6, 1, 'first');
    if ~isempty(j)
        matchDec(k) = j;
    end
end
if ~any(matchDec > 0)
    error('agent23c:AlignDec', 'Could not align alpha_decomposition T_K to decomposition temperatures.');
end

mBaseline = ptValid & isfinite(spread) & isfinite(asymm) & isfinite(alphaTrue);
valid = false(size(T_Kd));
for i = 1:numel(T_Kd)
    if ~mBaseline(i)
        continue
    end
    j = find(abs(T_Kk - T_Kd(i)) < 1e-6, 1);
    if isempty(j)
        continue
    end
    if ~(isfinite(k1Obs(j)) && isfinite(tailW(j)) && isfinite(sPeakK(j)))
        continue
    end
    ti = matchDec(i);
    if ti < 1 || ti > size(Rall, 1)
        continue
    end
    if ~all(isfinite(Rall(ti, :)))
        continue
    end
    valid(i) = true;
end

idxV = find(valid);
nV = numel(idxV);
assert(nV >= 5, 'Too few valid rows for LOOCV (need n >= 5).');

TV = T_Kd(idxV);
[TVs, ord] = sort(TV);
idxSorted = idxV(ord);
decRow = zeros(nV, 1);
for ii = 1:nV
    decRow(ii) = matchDec(idxSorted(ii));
end

spreadV = spread(idxSorted);
asymmV = asymm(idxSorted);
alphaV = alphaTrue(idxSorted);
alphaResV = alphaResTab(idxSorted);
TW = tailW(arrayfun(@(t) find(abs(T_Kk - t) < 1e-6, 1), TVs)); %#ok<FNDSB>
SP = sPeakK(arrayfun(@(t) find(abs(T_Kk - t) < 1e-6, 1), TVs)); %#ok<FNDSB>
k1V = k1Obs(arrayfun(@(t) find(abs(T_Kk - t) < 1e-6, 1), TVs)); %#ok<FNDSB>

aStrSorted = sortrows(aStr, 'T_K');
k1full = double(aStrSorted.kappa1(:));
k2full = double(aStrSorted.kappa2(:));
Tfull = double(aStrSorted.T_K(:));
thetaFull = atan2(k2full, k1full);
thu = unwrap(thetaFull);
dthetaRaw = localForwardDiff(thu);
ths = localSmoothAngle(thu, numel(thu));
dthetaSm = localForwardDiff(ths);
dsStep = localForwardDiff(k1full);
dsStep2 = localForwardDiff(k2full);
dsEucl = NaN(numel(Tfull), 1);
dsEucl(2:end) = sqrt(dsStep(2:end).^2 + dsStep2(2:end).^2);
dTfull = localForwardDiff(Tfull);
kapCurv = NaN(numel(Tfull), 1);
if numel(Tfull) >= 2
    kapCurv(2:end) = abs(dthetaRaw(2:end)) ./ max(dTfull(2:end), eps);
end

[~, iMapV] = ismember(TVs, Tfull);
if any(iMapV == 0)
    error('agent23c:AlphaStructAlign', 'Some valid T missing from alpha_structure.');
end

trajPack = struct();
trajPack.delta_theta_rad = dthetaRaw(iMapV);
trajPack.delta_theta_smoothed_rad = dthetaSm(iMapV);
trajPack.kappa_curve = kapCurv(iMapV);
trajPack.ds_step = dsEucl(iMapV);
trajPack.theta_raw = thetaFull(iMapV);

maWindow = min(5, max(3, 2 * floor(nV / 6) + 1));
if mod(maWindow, 2) == 0
    maWindow = maWindow + 1;
end
[sgLen, sgOrd] = localSgParams(numel(k1full));
k1_ma = movmean(k1full, maWindow, 'Endpoints', 'shrink');
k2_ma = movmean(k2full, maWindow, 'Endpoints', 'shrink');
[th_ma, dth_ma] = localThetaDthetaFromKappa(k1_ma, k2_ma);
k1_sg = sgolayfilt(k1full, sgOrd, sgLen);
k2_sg = sgolayfilt(k2full, sgOrd, sgLen);
[~, dth_sg] = localThetaDthetaFromKappa(k1_sg, k2_sg);
trajPack.delta_theta_ma = dth_ma(iMapV);
trajPack.delta_theta_sg = dth_sg(iMapV);

trajCandidates = {
    'delta_theta_rad', @(p) p.delta_theta_rad;
    'delta_theta_smoothed_rad', @(p) p.delta_theta_smoothed_rad;
    'kappa_curve', @(p) p.kappa_curve;
    'ds_step', @(p) p.ds_step;
    'delta_theta_ma', @(p) p.delta_theta_ma;
    'delta_theta_sg', @(p) p.delta_theta_sg;
    'theta_raw', @(p) p.theta_raw;
    };

bestTrajName = '';
bestTrajLoocv = inf;
for c = 1:size(trajCandidates, 1)
    xv = trajCandidates{c, 2}(trajPack);
    mfin = isfinite(xv);
    if nnz(mfin) < 4
        continue
    end
    rep = localOlsLoocvReport(char(trajCandidates{c, 1}), alphaResV, ...
        localMaskCols([ones(nV, 1), xv(:)], mfin));
    if isfinite(rep.loocv_rmse) && rep.loocv_rmse < bestTrajLoocv
        bestTrajLoocv = rep.loocv_rmse;
        bestTrajName = char(trajCandidates{c, 1});
    end
end
if isempty(bestTrajName)
    error('agent23c:TrajModel', 'No valid trajectory model for alpha_res.');
end

XgFull = [ones(nV, 1), spreadV, asymmV];
XkFull = [ones(nV, 1), TW, SP];

rmsePT = nan(nV, 1);
rmseR1 = nan(nV, 1);
rmseR2g = nan(nV, 1);
rmseR2t = nan(nV, 1);
k1Hat = nan(nV, 1);
agHat = nan(nV, 1);
arHat = nan(nV, 1);

for ii = 1:nV
    ho = ii;
    tr = true(nV, 1);
    tr(ho) = false;
    nt = nnz(tr);
    if nt < 4
        continue
    end

    rowH = decRow(ho);
    Rh = Rall(rowH, :)';

    k1Hat(ho) = localLoocvScalarPredict(k1V, XkFull, ho);
    agHat(ho) = localLoocvScalarPredict(alphaV, XgFull, ho);

    xv = trajPack.(bestTrajName)(:);
    Xtraj = [ones(nV, 1), xv(:)];
    eligTr = all(isfinite(Xtraj), 2);
    arHat(ho) = localLoocvMasked(alphaResV, Xtraj, ho, eligTr);

    k1h = k1Hat(ho);
    agh = agHat(ho);
    arh = arHat(ho);
    if ~isfinite(arh)
        arh = 0;
    end

    if ~(isfinite(k1h) && isfinite(agh))
        continue
    end

    ePT = Rh;
    e1 = Rh - k1h * phi1;
    e2g = Rh - k1h * (phi1 + agh * phi2);
    e2t = Rh - k1h * (phi1 + (agh + arh) * phi2);

    rmsePT(ii) = sqrt(mean(ePT.^2, 'omitnan'));
    rmseR1(ii) = sqrt(mean(e1.^2, 'omitnan'));
    rmseR2g(ii) = sqrt(mean(e2g.^2, 'omitnan'));
    rmseR2t(ii) = sqrt(mean(e2t.^2, 'omitnan'));
end

aggPT = sqrt(mean(rmsePT.^2, 'omitnan'));
aggR1 = sqrt(mean(rmseR1.^2, 'omitnan'));
aggR2g = sqrt(mean(rmseR2g.^2, 'omitnan'));
aggR2t = sqrt(mean(rmseR2t.^2, 'omitnan'));

TRAJECTORY_IMPROVES_S_PREDICTION = 'NO';
if isfinite(aggR2g) && isfinite(aggR2t) && (aggR2t < aggR2g - 1e-12)
    TRAJECTORY_IMPROVES_S_PREDICTION = 'YES';
end

MODEL_PREDICTS_S = 'NO';
if isfinite(aggR2t) && isfinite(aggPT) && (aggR2t < aggPT - 1e-12)
    MODEL_PREDICTS_S = 'YES';
end

seg = repmat({'loocv_holdout_T'}, nV, 1);
outTbl = table(seg, TVs, rmsePT, rmseR1, rmseR2g, rmseR2t, k1Hat, agHat, arHat, ...
    'VariableNames', {'row_kind', 'T_K', 'loocv_rmse_PT_only', 'loocv_rmse_rank1', ...
    'loocv_rmse_rank2_geom', 'loocv_rmse_rank2_traj', 'kappa1_hat_PT_loocv', ...
    'alpha_geom_hat_PT_loocv', 'alpha_res_hat_traj_loocv'});

sumRow = table({'aggregate_rms_over_T'}, NaN, aggPT, aggR1, aggR2g, aggR2t, NaN, NaN, NaN, ...
    'VariableNames', outTbl.Properties.VariableNames);
meanRow = table({'mean_rmse_per_T'}, NaN, mean(rmsePT,'omitnan'), mean(rmseR1,'omitnan'), ...
    mean(rmseR2g,'omitnan'), mean(rmseR2t,'omitnan'), NaN, NaN, NaN, ...
    'VariableNames', outTbl.Properties.VariableNames);
outAll = [outTbl; sumRow; meanRow];

tablesDir = fullfile(repoRoot, 'tables');
figDir = fullfile(repoRoot, 'figures');
repDir = fullfile(repoRoot, 'reports');
for d = {tablesDir, figDir, repDir}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

csvPath = fullfile(tablesDir, 'full_prediction_trajectory.csv');
writetable(outAll, csvPath);

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 720 420]);
vals = [aggPT, aggR1, aggR2g, aggR2t];
bar(vals, 'FaceColor', [0.25 0.45 0.72]);
set(gca, 'XTickLabel', {'PT only', 'rank-1', 'rank-2 geom', 'rank-2 + traj'}, ...
    'XTickLabelRotation', 20, 'FontSize', 11);
ylabel('RMSE aggregate (LOOCV, dS strip)', 'FontSize', 12);
title('S prediction via residual closure (Agent 23C)', 'FontSize', 13);
grid(gca, 'on');
for k = 1:numel(vals)
    if isfinite(vals(k))
        text(k, vals(k), sprintf(' %.4f', vals(k)), 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 9);
    end
end
figPath = fullfile(figDir, 'prediction_comparison.png');
try
    exportgraphics(fig, figPath, 'Resolution', 150);
catch
    print(fig, figPath, '-dpng', '-r150');
end
close(fig);

repPath = fullfile(repDir, 'full_prediction_with_trajectory.md');
fid2 = fopen(repPath, 'w');
fprintf(fid2, '%s\n', '# Full S prediction with trajectory-corrected rank-2 (Agent 23C)');
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', '**Goal:** Temperature LOOCV on the residual strip dS = S - S_CDF on the common x-grid; RMSE matches full S(I,T) up to the shared backbone S_CDF.');
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', '## Model');
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', ['R_hat = kappa1_hat * Phi1 + kappa1_hat * (alpha_geom_hat + alpha_res_hat) * Phi2, with ', ...
    'kappa1_hat from PT tail (`tail_width_q90_q50`, `S_peak`), alpha_geom_hat from PT (`spread90_50`, `asymmetry`), ', ...
    'alpha_res_hat from a single trajectory scalar (22D/22E-style), selected by minimum alpha_res LOOCV on this cohort.']);
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', ['**Selected trajectory term:** `', bestTrajName, '`.']);
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', '## Inputs');
fprintf(fid2, '%s\n', '');
fprintf(fid2, '- Residual decomposition: same sources as `run_alpha_structure_agent19f` (this run: `%s`).\n', decCfg.runLabel);
fprintf(fid2, '- `%s`\n', strrep(kappaPtPath, '\', '/'));
fprintf(fid2, '- `%s`\n', strrep(alphaDecPath, '\', '/'));
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', '## LOOCV RMSE (aggregate_rms_over_T in CSV: sqrt(mean of squared per-T strip RMSEs))');
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', '| model | RMSE |');
fprintf(fid2, '%s\n', '|---|---:|');
fprintf(fid2, '| PT only | %s |\n', localNum(aggPT));
fprintf(fid2, '| rank-1 | %s |\n', localNum(aggR1));
fprintf(fid2, '| rank-2 (geom only) | %s |\n', localNum(aggR2g));
fprintf(fid2, '| rank-2 + trajectory | %s |\n', localNum(aggR2t));
fprintf(fid2, '%s\n', '');
fprintf(fid2, '| n (valid PT temperatures) | %d |\n', nV);
fprintf(fid2, '| cohort alpha_res trajectory model LOOCV (selection rule) | %s |\n', localNum(bestTrajLoocv));
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', '## Flags');
fprintf(fid2, '%s\n', '');
fprintf(fid2, '- **TRAJECTORY_IMPROVES_S_PREDICTION** = **%s** (rank-2+traj aggregate RMSE strictly below rank-2 geom)\n', ...
    TRAJECTORY_IMPROVES_S_PREDICTION);
fprintf(fid2, '- **MODEL_PREDICTS_S** = **%s** (rank-2+traj aggregate RMSE strictly below PT-only baseline)\n', ...
    MODEL_PREDICTS_S);
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', ['**Note:** If `alpha_res_hat` is undefined for a holdout temperature (NaN trajectory feature), it is taken as **0** ', ...
    '(rank-2+traj reduces to rank-2 geom for that row). `alpha_res` training targets use `tables/alpha_decomposition.csv`.']);
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', '## Artifacts');
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', '- `tables/full_prediction_trajectory.csv`');
fprintf(fid2, '%s\n', '- `figures/prediction_comparison.png`');
fprintf(fid2, '%s\n', '');
fprintf(fid2, '%s\n', '*Auto-generated by `analysis/run_full_prediction_trajectory_agent23c.m`.*');
fclose(fid2);

fprintf(1, 'Wrote %s\n%s\n%s\n', csvPath, figPath, repPath);
fprintf(1, 'TRAJECTORY_IMPROVES_S_PREDICTION = %s\nMODEL_PREDICTS_S = %s\n', ...
    TRAJECTORY_IMPROVES_S_PREDICTION, MODEL_PREDICTS_S);
end

%% --- helpers ---

function s = localNum(v)
if isfinite(v)
    s = sprintf('%.8g', v);
else
    s = 'NaN';
end
end

function col = localGetCol(tbl, names)
for i = 1:numel(names)
    if ismember(names{i}, tbl.Properties.VariableNames)
        col = double(tbl.(names{i})(:));
        return
    end
end
error('Missing one of columns: %s', strjoin(names, ', '));
end

function d = localForwardDiff(y)
y = double(y(:));
n = numel(y);
d = nan(n, 1);
if n >= 2
    d(2:end) = diff(y);
end
end

function ths = localSmoothAngle(thu, n)
if n < 3
    ths = thu;
    return
end
wl = min(9, 2 * floor(n / 2) - 1);
wl = max(wl, 3);
if mod(wl, 2) == 0
    wl = wl - 1;
end
wl = min(wl, n);
if mod(wl, 2) == 0
    wl = wl - 1;
end
try
    ths = smoothdata(thu, 'sgolay', wl);
catch
    try
        ths = sgolayfilt(thu, 2, wl);
    catch
        ths = movmean(thu, min(3, n), 'Endpoints', 'shrink');
    end
end
end

function [theta, dtheta] = localThetaDthetaFromKappa(k1, k2)
k1 = double(k1(:));
k2 = double(k2(:));
n = numel(k1);
theta = atan2(k2, k1);
thu = unwrap(theta);
dtheta = nan(n, 1);
if n >= 2
    dtheta(2:end) = diff(thu);
end
end

function [framelen, polyorder] = localSgParams(n)
polyorder = 2;
candidates = [7, 5, 3];
framelen = 3;
for c = candidates
    if c <= n && mod(c, 2) == 1 && c >= polyorder + 2
        framelen = c;
        break
    end
end
if framelen > n
    framelen = max(3, 2 * floor(n / 2) - 1);
end
if mod(framelen, 2) == 0
    framelen = framelen - 1;
end
framelen = max(3, min(framelen, n));
if polyorder >= framelen
    polyorder = max(1, framelen - 2);
end
end

function S = localMaskCols(X, m)
S.X = X(m, :);
S.m = m(:);
end

function row = localOlsLoocvReport(name, y, M)
if isstruct(M)
    X = M.X;
    y = double(y(M.m));
else
    X = M;
    y = double(y(:));
end
X = double(X);
n = numel(y);
p = size(X, 2);
if n < p || isempty(X) || rank(X) < p
    row = table({char(name)}, n, NaN, 'VariableNames', {'model', 'n', 'loocv_rmse'});
    return
end
beta = X \ y;
yhat = X * beta;
e = y - yhat;
Hmat = X * ((X' * X) \ X');
h = diag(Hmat);
loo_e = e ./ max(1 - h, 1e-12);
row = table({char(name)}, n, sqrt(mean(loo_e.^2, 'omitnan')), ...
    'VariableNames', {'model', 'n', 'loocv_rmse'});
end

function yh = localLoocvScalarPredict(y, X, idxHold)
y = double(y(:));
X = double(X);
n = size(X, 1);
yh = NaN;
tr = true(n, 1);
tr(idxHold) = false;
if nnz(tr) < size(X, 2)
    return
end
Xt = X(tr, :);
yt = y(tr);
if ~all(isfinite(Xt), 'all') || ~all(isfinite(yt))
    return
end
if rank(Xt) < size(Xt, 2)
    return
end
beta = Xt \ yt;
xh = X(idxHold, :);
yh = xh * beta;
end

function yh = localLoocvMasked(y, X, idxHold, eligible)
y = double(y(:));
X = double(X);
n = size(X, 1);
yh = NaN;
if idxHold < 1 || idxHold > n || ~eligible(idxHold)
    return
end
tr = eligible(:);
tr(idxHold) = false;
if nnz(tr) < size(X, 2)
    return
end
Xt = X(tr, :);
yt = y(tr);
if rank(Xt) < size(Xt, 2)
    return
end
beta = Xt \ yt;
xh = X(idxHold, :);
yh = xh * beta;
end
