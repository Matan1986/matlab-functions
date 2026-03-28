function out = run_prediction_falsification_test(cfg)
%RUN_PREDICTION_FALSIFICATION_TEST Predictive holdout test for S(I,T) model.
%   S(I,T) ~= S_peak(T)*CDF(P_T) + kappa(T)*Phi(x), x=(I-I_peak)/w

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = applyDefaults(cfg);
runDataset = sprintf('prediction_falsification | align:%s fs:%s pt:%s barrier:%s', ...
    cfg.alignmentRunId, cfg.fullScalingRunId, cfg.ptRunId, cfg.barrierRunId);
run = createRunContext('cross_experiment', struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

for s = ["figures", "tables", "reports", "review"]
    d = fullfile(runDir, char(s));
    if exist(d, 'dir') ~= 7, mkdir(d); end
end

slice = loadCanonicalSlice(repoRoot, cfg);
Smap = slice.Smap;
temps = slice.temps;
currents = slice.currents;
Ipeak = slice.Ipeak;
Speak = slice.Speak;
width = slice.width;
Scdf = slice.Scdf;

deltaS = Smap - Scdf;
Xrows = NaN(size(deltaS));
for it = 1:numel(temps)
    Xrows(it, :) = (currents(:)' - Ipeak(it)) ./ width(it);
end

xGrid = buildCommonXGrid(Xrows, cfg.nXGrid);
Rall = interpolateRowsToGrid(Xrows, deltaS, xGrid);

holdoutMask = selectHoldoutMask(temps, cfg.holdoutTemperaturesK);
trainMask = ~holdoutMask;
assert(nnz(holdoutMask) >= 1, 'No held-out temperatures found.');
assert(nnz(trainMask) >= 5, 'Too few training temperatures after holdout selection.');

trainForPhi = trainMask & (temps <= cfg.canonicalMaxTemperatureK);
if nnz(trainForPhi) < 5
    trainForPhi = trainMask;
end
phi = extractPhiFromRows(Rall(trainForPhi, :));
kappaActual = fitKappaRows(Rall, phi);

ptFeatures = loadPTFeatures(repoRoot, cfg, temps);
barrierTbl = loadBarrierTable(repoRoot, cfg, temps);

kappaPred = linearPredict(ptFeatures, kappaActual, trainMask);
Apred = linearPredict(ptFeatures, barrierTbl.A_T_interp, trainMask);
Rpred = linearPredict(kappaActual, barrierTbl.R_T_interp, trainMask);

[SptOnly, SptResidual] = predictHeldoutCurves(Scdf, xGrid, phi, kappaPred, Xrows, holdoutMask);
Strue = Smap(holdoutMask, :);

[rmsePtOnly, corrPtOnly] = matrixMetrics(Strue, SptOnly);
[rmsePtResidual, corrPtResidual] = matrixMetrics(Strue, SptResidual);
[rmseA, corrA] = vectorMetrics(barrierTbl.A_T_interp(holdoutMask), Apred(holdoutMask));
[rmseR, corrR] = vectorMetrics(barrierTbl.R_T_interp(holdoutMask), Rpred(holdoutMask));
[rmseKappa, corrKappa] = vectorMetrics(kappaActual(holdoutMask), kappaPred(holdoutMask));

rmseImprovementFrac = (rmsePtOnly - rmsePtResidual) / max(rmsePtOnly, eps);
corrGain = corrPtResidual - corrPtOnly;

modelPredictive = (isfinite(corrPtResidual) && corrPtResidual >= cfg.predictiveCorrThreshold) && ...
    (isfinite(rmseImprovementFrac) && rmseImprovementFrac >= cfg.predictiveRmseImprovementThreshold);
residualNeeded = (isfinite(rmseImprovementFrac) && rmseImprovementFrac >= cfg.residualNeededRmseImprovementThreshold) || ...
    (isfinite(corrGain) && corrGain >= cfg.residualNeededCorrGainThreshold);

boundaryMask = holdoutMask & temps >= cfg.boundaryWindowK(1) & temps <= cfg.boundaryWindowK(2);
if nnz(boundaryMask) == 0
    failureBoundary = false;
else
    [rmseBoundary, corrBoundary] = matrixMetrics(Smap(boundaryMask, :), ...
        SptResidual(ismember(find(holdoutMask), find(boundaryMask)), :));
    failureBoundary = (~isfinite(corrBoundary) || corrBoundary < cfg.boundaryCorrThreshold) || ...
        (isfinite(rmseBoundary) && isfinite(rmsePtResidual) && rmseBoundary > cfg.boundaryRmseInflation * rmsePtResidual);
end

verdictModel = yn(modelPredictive);
verdictResidual = yn(residualNeeded);
verdictBoundary = yn(failureBoundary);

metrics = table( ...
    rmsePtOnly, corrPtOnly, rmsePtResidual, corrPtResidual, rmseImprovementFrac, corrGain, ...
    rmseA, corrA, rmseR, corrR, rmseKappa, corrKappa, ...
    string(verdictModel), string(verdictResidual), string(verdictBoundary), ...
    'VariableNames', {'rmse_S_pt_only', 'corr_S_pt_only', 'rmse_S_pt_plus_residual', 'corr_S_pt_plus_residual', ...
    'rmse_improvement_fraction', 'corr_gain', ...
    'rmse_A_from_PT', 'corr_A_from_PT', 'rmse_R_from_kappa', 'corr_R_from_kappa', ...
    'rmse_kappa_from_PT', 'corr_kappa_from_PT', ...
    'MODEL_PREDICTIVE', 'RESIDUAL_NEEDED_FOR_PREDICTION', 'FAILURE_AT_REGIME_BOUNDARY'});
metricsPath = fullfile(runDir, 'tables', 'prediction_metrics.csv');
writetable(metrics, metricsPath);

predRows = table();
predRows.T_K = temps(holdoutMask);
predRows.kappa_true = kappaActual(holdoutMask);
predRows.kappa_pred = kappaPred(holdoutMask);
predRows.A_true = barrierTbl.A_T_interp(holdoutMask);
predRows.A_pred = Apred(holdoutMask);
predRows.R_true = barrierTbl.R_T_interp(holdoutMask);
predRows.R_pred = Rpred(holdoutMask);
writetable(predRows, fullfile(runDir, 'tables', 'heldout_scalar_predictions.csv'));

fig = create_figure('Name', 'pred_vs_true', 'NumberTitle', 'off', 'Visible', 'off', 'Position', [2 2 14 6]);
t = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(t, 1);
plot(ax1, Strue(:), SptOnly(:), '.', 'MarkerSize', 8, 'Color', [0.2 0.2 0.2]);
hold(ax1, 'on');
plotIdentity(ax1, Strue(:), SptOnly(:));
hold(ax1, 'off');
xlabel(ax1, 'S true (held-out)');
ylabel(ax1, 'S pred (PT-only)');
title(ax1, sprintf('PT-only | RMSE=%.4g, corr=%.3f', rmsePtOnly, corrPtOnly));
grid(ax1, 'on');

ax2 = nexttile(t, 2);
plot(ax2, Strue(:), SptResidual(:), '.', 'MarkerSize', 8, 'Color', [0 0.45 0.74]);
hold(ax2, 'on');
plotIdentity(ax2, Strue(:), SptResidual(:));
hold(ax2, 'off');
xlabel(ax2, 'S true (held-out)');
ylabel(ax2, 'S pred (PT + residual)');
title(ax2, sprintf('PT+residual | RMSE=%.4g, corr=%.3f', rmsePtResidual, corrPtResidual));
grid(ax2, 'on');

save_run_figure(fig, 'pred_vs_true', runDir);
close(fig);

reportPath = fullfile(runDir, 'reports', 'prediction_test_report.md');
fid = fopen(reportPath, 'w');
fprintf(fid, '# Prediction / falsification test\n\n');
fprintf(fid, 'Model tested:\n\n');
fprintf(fid, '- `S(I,T) ~= S_{peak}(T) * CDF(P_T) + kappa(T) * Phi(x)` with `x=(I-I_{peak})/w`.\n\n');
fprintf(fid, '## Holdout setup\n\n');
fprintf(fid, '- Holdout temperatures (requested): `%s` K\n', mat2str(cfg.holdoutTemperaturesK));
fprintf(fid, '- Holdout temperatures (used): `%s` K\n', mat2str(temps(holdoutMask)'));
fprintf(fid, '- Training temperatures count: `%d`\n', nnz(trainMask));
fprintf(fid, '- Held-out temperatures count: `%d`\n\n', nnz(holdoutMask));
fprintf(fid, '## Main metrics (held-out)\n\n');
fprintf(fid, '- PT-only: RMSE(S)=**%.6g**, corr(S)=**%.4f**\n', rmsePtOnly, corrPtOnly);
fprintf(fid, '- PT+residual: RMSE(S)=**%.6g**, corr(S)=**%.4f**\n', rmsePtResidual, corrPtResidual);
fprintf(fid, '- RMSE improvement fraction: **%.4f**\n', rmseImprovementFrac);
fprintf(fid, '- Correlation gain: **%.4f**\n\n', corrGain);
fprintf(fid, '## Derived predictions\n\n');
fprintf(fid, '- A(T) from PT: RMSE=**%.6g**, corr=**%.4f**\n', rmseA, corrA);
fprintf(fid, '- R(T) from kappa: RMSE=**%.6g**, corr=**%.4f**\n', rmseR, corrR);
fprintf(fid, '- kappa(T) from PT: RMSE=**%.6g**, corr=**%.4f**\n\n', rmseKappa, corrKappa);
fprintf(fid, '## Final verdict\n\n');
fprintf(fid, '- **MODEL_PREDICTIVE: %s**\n', verdictModel);
fprintf(fid, '- **RESIDUAL_NEEDED_FOR_PREDICTION: %s**\n', verdictResidual);
fprintf(fid, '- **FAILURE_AT_REGIME_BOUNDARY: %s**\n\n', verdictBoundary);
fprintf(fid, '## Artifacts\n\n');
fprintf(fid, '- `tables/prediction_metrics.csv`\n');
fprintf(fid, '- `figures/pred_vs_true.png`\n');
fprintf(fid, '- `reports/prediction_test_report.md`\n');
fclose(fid);

appendText(run.log_path, sprintf('[%s] prediction_falsification complete | MODEL_PREDICTIVE=%s | RESIDUAL_NEEDED=%s | BOUNDARY_FAILURE=%s\n', ...
    stampNow(), verdictModel, verdictResidual, verdictBoundary));

out = struct();
out.run = run;
out.runDir = string(runDir);
out.metricsPath = string(metricsPath);
out.reportPath = string(reportPath);
out.verdict = struct( ...
    'MODEL_PREDICTIVE', string(verdictModel), ...
    'RESIDUAL_NEEDED_FOR_PREDICTION', string(verdictResidual), ...
    'FAILURE_AT_REGIME_BOUNDARY', string(verdictBoundary));
end

function cfg = applyDefaults(cfg)
cfg = setDefault(cfg, 'runLabel', 'prediction_falsification_test');
cfg = setDefault(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = setDefault(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = setDefault(cfg, 'ptRunId', 'run_2026_03_25_013356_pt_robust_canonical');
cfg = setDefault(cfg, 'barrierRunId', 'run_2026_03_25_031904_barrier_to_relaxation_mechanism');
cfg = setDefault(cfg, 'holdoutTemperaturesK', [22, 24]);
cfg = setDefault(cfg, 'canonicalMaxTemperatureK', 30);
cfg = setDefault(cfg, 'nXGrid', 220);
cfg = setDefault(cfg, 'fallbackSmoothWindow', 5);
cfg = setDefault(cfg, 'predictiveCorrThreshold', 0.90);
cfg = setDefault(cfg, 'predictiveRmseImprovementThreshold', 0.10);
cfg = setDefault(cfg, 'residualNeededRmseImprovementThreshold', 0.05);
cfg = setDefault(cfg, 'residualNeededCorrGainThreshold', 0.05);
cfg = setDefault(cfg, 'boundaryWindowK', [22, 24]);
cfg = setDefault(cfg, 'boundaryCorrThreshold', 0.85);
cfg = setDefault(cfg, 'boundaryRmseInflation', 1.20);
end

function slice = loadCanonicalSlice(repoRoot, cfg)
alignPath = fullfile(repoRoot, 'results', 'switching', 'runs', cfg.alignmentRunId, 'switching_alignment_core_data.mat');
scalePath = fullfile(repoRoot, 'results', 'switching', 'runs', cfg.fullScalingRunId, 'tables', 'switching_full_scaling_parameters.csv');
ptPath = fullfile(repoRoot, 'results', 'switching', 'runs', cfg.ptRunId, 'tables', 'PT_matrix.csv');

core = load(alignPath, 'Smap', 'temps', 'currents');
[SmapAll, tempsAll, currents] = orientAndSortMap(core.Smap, core.temps(:), core.currents(:));
paramsTbl = readtable(scalePath);
[tempsScale, IpeakScale, SpeakScale, widthScale] = extractScalingColumns(paramsTbl);

[tempsCommon, iMap, iScale] = intersect(tempsAll, tempsScale, 'stable');
Smap = SmapAll(iMap, :);
Ipeak = IpeakScale(iScale);
Speak = SpeakScale(iScale);
width = widthScale(iScale);

valid = isfinite(tempsCommon) & isfinite(Ipeak) & isfinite(Speak) & isfinite(width) & width > 0;
temps = tempsCommon(valid);
Smap = Smap(valid, :);
Ipeak = Ipeak(valid);
Speak = Speak(valid);
width = width(valid);

ptData = loadPTData(ptPath);
Scdf = NaN(size(Smap));
for it = 1:numel(temps)
    cdfRow = [];
    if ptData.available
        cdfRow = cdfFromPT(ptData, temps(it), currents);
    end
    if isempty(cdfRow)
        cdfRow = cdfFallbackFromRow(Smap(it, :), currents, cfg.fallbackSmoothWindow);
    end
    Scdf(it, :) = Speak(it) .* cdfRow(:)';
end

slice = struct('Smap', Smap, 'temps', temps, 'currents', currents, ...
    'Ipeak', Ipeak, 'Speak', Speak, 'width', width, 'Scdf', Scdf);
end

function ptFeatures = loadPTFeatures(repoRoot, cfg, temps)
ptSummaryPath = fullfile(repoRoot, 'results', 'switching', 'runs', cfg.ptRunId, 'tables', 'PT_summary.csv');
if exist(ptSummaryPath, 'file') ~= 2
    error('Missing PT summary table: %s', ptSummaryPath);
end
tbl = readtable(ptSummaryPath, 'VariableNamingRule', 'preserve');
Tsum = numericColumn(tbl, ["T_K", "T"]);
m1 = numericColumn(tbl, ["mean_threshold_mA", "mean_threshold", "mean_mA"]);
m2 = numericColumn(tbl, ["std_threshold_mA", "std_threshold", "std_mA"]);
m3 = numericColumn(tbl, ["skewness", "skew"]);
m4 = numericColumn(tbl, ["cdf_rmse", "cdf_error"]);
[~, ia, ib] = intersect(temps, Tsum, 'stable');
ptFeatures = NaN(numel(temps), 4);
ptFeatures(ia, 1) = m1(ib);
ptFeatures(ia, 2) = m2(ib);
ptFeatures(ia, 3) = m3(ib);
ptFeatures(ia, 4) = m4(ib);
end

function barrierTbl = loadBarrierTable(repoRoot, cfg, temps)
barrierPath = fullfile(repoRoot, 'results', 'cross_experiment', 'runs', cfg.barrierRunId, 'tables', 'barrier_descriptors.csv');
if exist(barrierPath, 'file') ~= 2
    error('Missing barrier descriptors table: %s', barrierPath);
end
tbl = readtable(barrierPath, 'VariableNamingRule', 'preserve');
Tb = numericColumn(tbl, ["T_K", "T"]);
A = numericColumn(tbl, ["A_T_interp", "A_T", "A"]);
R = numericColumn(tbl, ["R_T_interp", "R_T", "R"]);
[~, ia, ib] = intersect(temps, Tb, 'stable');
barrierTbl = table(temps, NaN(size(temps)), NaN(size(temps)), 'VariableNames', {'T_K', 'A_T_interp', 'R_T_interp'});
barrierTbl.A_T_interp(ia) = A(ib);
barrierTbl.R_T_interp(ia) = R(ib);
end

function yPred = linearPredict(Xin, y, trainMask)
if isvector(Xin)
    Xin = Xin(:);
end
n = size(Xin, 1);
X = [ones(n, 1), Xin];
okTrain = trainMask(:) & isfinite(y(:)) & all(isfinite(X), 2);
if nnz(okTrain) < size(X, 2)
    yPred = NaN(size(y));
    return;
end
b = X(okTrain, :) \ y(okTrain);
yPred = X * b;
end

function [SptOnly, SptResidual] = predictHeldoutCurves(Scdf, xGrid, phi, kappaPred, Xrows, holdoutMask)
SptOnly = Scdf(holdoutMask, :);
SptResidual = SptOnly;
idx = find(holdoutMask);
for j = 1:numel(idx)
    it = idx(j);
    phiOnRow = interp1(xGrid, phi, Xrows(it, :)', 'linear', 0);
    SptResidual(j, :) = SptOnly(j, :) + (kappaPred(it) .* phiOnRow(:))';
end
end

function mask = selectHoldoutMask(temps, holdoutTemperaturesK)
mask = false(size(temps));
for i = 1:numel(holdoutTemperaturesK)
    [d, ix] = min(abs(temps - holdoutTemperaturesK(i)));
    if isfinite(d) && d <= 0.6
        mask(ix) = true;
    end
end
if nnz(mask) == 0
    [~, ord] = sort(abs(temps - mean(holdoutTemperaturesK(:))), 'ascend');
    mask(ord(1:min(2, numel(ord)))) = true;
end
end

function phi = extractPhiFromRows(Rtrain)
R0 = Rtrain;
R0(~isfinite(R0)) = 0;
[U, S, V] = svd(R0, 'econ'); %#ok<ASGLU>
phi = V(:, 1);
kap = U(:, 1) * S(1, 1);
if median(kap, 'omitnan') < 0
    phi = -phi;
end
sc = max(abs(phi), [], 'omitnan');
if ~(isfinite(sc) && sc > 0), sc = 1; end
phi = phi / sc;
end

function kappa = fitKappaRows(R, phi)
kappa = NaN(size(R, 1), 1);
for i = 1:size(R, 1)
    r = R(i, :)';
    m = isfinite(r) & isfinite(phi);
    if nnz(m) < 3, continue; end
    den = sum(phi(m).^2, 'omitnan');
    if den <= eps, continue; end
    kappa(i) = sum(r(m) .* phi(m), 'omitnan') / den;
end
end

function [rmse, c] = matrixMetrics(A, B)
m = isfinite(A) & isfinite(B);
if ~any(m(:))
    rmse = NaN; c = NaN; return;
end
d = A(m) - B(m);
rmse = sqrt(mean(d.^2, 'omitnan'));
if nnz(m) < 5
    c = NaN;
else
    c = corr(A(m), B(m), 'rows', 'pairwise');
end
end

function [rmse, c] = vectorMetrics(a, b)
m = isfinite(a) & isfinite(b);
if nnz(m) < 2
    rmse = NaN; c = NaN; return;
end
rmse = sqrt(mean((a(m) - b(m)).^2, 'omitnan'));
if nnz(m) < 3
    c = NaN;
else
    c = corr(a(m), b(m), 'rows', 'pairwise');
end
end

function plotIdentity(ax, x, y)
v = [x(:); y(:)];
v = v(isfinite(v));
if isempty(v), return; end
lo = min(v);
hi = max(v);
plot(ax, [lo, hi], [lo, hi], 'k--', 'LineWidth', 1.4);
end

function tbl = loadPTData(ptMatrixPath)
tbl = struct('available', false, 'temps', [], 'currents', [], 'PT', []);
if exist(ptMatrixPath, 'file') ~= 2, return; end
t = readtable(ptMatrixPath);
vn = string(t.Properties.VariableNames);
if any(vn == "T_K"), tcol = "T_K"; else, tcol = vn(1); end
temps = t.(tcol);
if ~isnumeric(temps), temps = str2double(string(temps)); end
cc = setdiff(vn, tcol, 'stable');
cur = NaN(numel(cc), 1);
for j = 1:numel(cc), cur(j) = parseCurrentFromColumnName(cc(j)); end
keep = isfinite(cur);
cur = cur(keep);
cc = cc(keep);
if isempty(cur), return; end
PT = table2array(t(:, cc));
[cur, ord] = sort(cur);
PT = PT(:, ord);
tbl.available = true;
tbl.temps = double(temps(:));
tbl.currents = double(cur(:));
tbl.PT = double(PT);
end

function cdfRow = cdfFromPT(ptData, targetT, currents)
tempsPT = ptData.temps;
currPT = ptData.currents;
PT = ptData.PT;
if numel(tempsPT) < 2, cdfRow = []; return; end
pAtT = NaN(numel(currPT), 1);
for j = 1:numel(currPT)
    col = PT(:, j);
    m = isfinite(tempsPT) & isfinite(col);
    if nnz(m) < 2, continue; end
    pAtT(j) = interp1(tempsPT(m), col(m), targetT, 'linear', NaN);
end
if all(~isfinite(pAtT)), cdfRow = []; return; end
pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);
area = trapz(currPT, pAtT);
if ~(isfinite(area) && area > 0), cdfRow = []; return; end
pAtT = pAtT / area;
p = interp1(currPT, pAtT, currents(:), 'linear', 0);
p = max(p, 0);
area2 = trapz(currents, p);
if ~(isfinite(area2) && area2 > 0), cdfRow = []; return; end
p = p / area2;
cdfRow = cumtrapz(currents, p);
if cdfRow(end) <= 0, cdfRow = []; return; end
cdfRow = min(max(cdfRow / cdfRow(end), 0), 1);
end

function cdfRow = cdfFallbackFromRow(row, currents, smoothWindow)
row = double(row(:)');
currents = double(currents(:));
m = isfinite(row) & isfinite(currents(:)');
if nnz(m) < 3, cdfRow = zeros(size(currents)); return; end
r = row(m);
I = currents(m);
rMin = min(r, [], 'omitnan');
rMax = max(r, [], 'omitnan');
if ~(isfinite(rMin) && isfinite(rMax) && rMax > rMin)
    cdfRow = zeros(size(currents)); return;
end
rNorm = (r - rMin) / (rMax - rMin);
if smoothWindow >= 2
    rNorm = smoothdata(rNorm, 'movmean', min(smoothWindow, numel(rNorm)));
end
rNorm = enforceMonotone(rNorm);
p = gradient(rNorm, I);
p = max(p, 0);
area = trapz(I, p);
if ~(isfinite(area) && area > 0)
    cdfRow = zeros(size(currents)); return;
end
p = p / area;
pFull = interp1(I, p, currents, 'linear', 0);
pFull = max(pFull, 0);
area2 = trapz(currents, pFull);
if area2 > 0, pFull = pFull / area2; end
cdfRow = cumtrapz(currents, pFull);
if cdfRow(end) > 0, cdfRow = cdfRow / cdfRow(end); end
cdfRow = min(max(cdfRow, 0), 1);
end

function y = enforceMonotone(x)
y = x(:)';
for i = 2:numel(y)
    if y(i) < y(i-1), y(i) = y(i-1); end
end
if y(end) > 0, y = y / y(end); end
end

function [Smap, temps, currents] = orientAndSortMap(SmapIn, tempsIn, currentsIn)
Smap = double(SmapIn);
temps = double(tempsIn(:));
currents = double(currentsIn(:));
rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurr = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);
if rowsAreCurr && ~rowsAreTemps
    Smap = Smap.';
elseif ~(rowsAreTemps || rowsAreCurr)
    error('Smap dimensions do not match temperature/current vectors.');
end
[temps, tOrd] = sort(temps);
[currents, iOrd] = sort(currents);
Smap = Smap(tOrd, iOrd);
end

function [temps, Ipeak, Speak, width] = extractScalingColumns(tbl)
temps = numericColumn(tbl, ["T_K", "T"]);
Ipeak = numericColumn(tbl, ["Ipeak_mA", "I_peak", "Ipeak"]);
Speak = numericColumn(tbl, ["S_peak", "Speak", "Speak_peak"]);
width = numericColumn(tbl, ["width_chosen_mA", "width_I", "width"]);
[temps, ord] = sort(temps);
Ipeak = Ipeak(ord);
Speak = Speak(ord);
width = width(ord);
end

function col = numericColumn(tbl, candidates)
vn = string(tbl.Properties.VariableNames);
col = NaN(height(tbl), 1);
for i = 1:numel(candidates)
    idx = find(vn == candidates(i), 1, 'first');
    if ~isempty(idx)
        raw = tbl.(vn(idx));
        if isnumeric(raw), col = double(raw(:));
        else, col = str2double(string(raw(:))); end
        return;
    end
end
end

function v = parseCurrentFromColumnName(name)
s = char(string(name));
s = regexprep(s, '^Ith_', '', 'ignorecase');
s = regexprep(s, '_mA$', '', 'ignorecase');
s = strrep(s, '_', '.');
v = str2double(s);
if isfinite(v), return; end
m = regexp(s, '[-+]?\d*\.?\d+', 'match', 'once');
if isempty(m), v = NaN; else, v = str2double(m); end
end

function xGrid = buildCommonXGrid(Xrows, nX)
xVals = Xrows(isfinite(Xrows));
if isempty(xVals)
    xGrid = linspace(-2.5, 2.5, nX)';
    return;
end
xGrid = linspace(prctile(xVals, 5), prctile(xVals, 95), nX)';
end

function Rout = interpolateRowsToGrid(Xrows, Yrows, xGrid)
nRows = size(Xrows, 1);
Rout = NaN(nRows, numel(xGrid));
for i = 1:nRows
    x = Xrows(i, :);
    y = Yrows(i, :);
    m = isfinite(x) & isfinite(y);
    if nnz(m) < 3, continue; end
    x = x(m); y = y(m);
    [x, ord] = sort(x);
    y = y(ord);
    [x, iu] = unique(x, 'stable');
    y = y(iu);
    Rout(i, :) = interp1(x, y, xGrid, 'linear', NaN);
end
end

function s = yn(flag)
if flag, s = 'YES'; else, s = 'NO'; end
end

function appendText(pathStr, txt)
fid = fopen(pathStr, 'a');
if fid < 0, return; end
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function cfg = setDefault(cfg, fieldName, defaultValue)
if ~isfield(cfg, fieldName) || isempty(cfg.(fieldName))
    cfg.(fieldName) = defaultValue;
end
end
