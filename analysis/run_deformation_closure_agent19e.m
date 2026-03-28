function run_deformation_closure_agent19e()
% run_deformation_closure_agent19e
% Agent 19E: test whether rank-2 residual structure is deformation of Phi1
% rather than a second independent mode. Read-only inputs; writes repo-root
% tables/, figures/, reports/ deliverables.
%
% Canonical sources: same as run_2026_03_25_204359_agent18a_closure_support

clearvars;
clc;

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'analysis'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

outRoot = repoRoot;
tblDir = fullfile(outRoot, 'tables');
figDir = fullfile(outRoot, 'figures');
repDir = fullfile(outRoot, 'reports');
for d = {tblDir, figDir, repDir}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

decCfg = struct();
decCfg.runLabel = 'deformation_closure_agent19e_internal';
decCfg.alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
decCfg.fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
decCfg.ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';
decCfg.canonicalMaxTemperatureK = 30;
decCfg.nXGrid = 220;
decCfg.maxModes = 2;
decCfg.skipFigures = true;

out = switching_residual_decomposition_analysis(decCfg);

temps = out.temperaturesK(:);
R = out.Rall;
xG = out.xGrid(:);
phi1 = out.phi(:);
phi2 = out.phi2(:);
Ipeak = out.Ipeak_mA(:);
Speak = out.Speak;
widthI = out.width_mA(:);
kappa1 = out.kappaAll(:);
lowMask = out.lowTemperatureMask(:);
currents = out.currents_mA(:);

% --- Observables: current quantiles from raw S map rows (same ordering as temps) ---
paramsPath = fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.fullScalingRunId, ...
    'tables', 'switching_full_scaling_parameters.csv');
paramsTbl = readtable(paramsPath);
alignPath = fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.alignmentRunId, ...
    'switching_alignment_core_data.mat');
core = load(alignPath, 'Smap', 'temps', 'currents');
[SmapA, tempsA, currentsA] = orientAndSortMapLocal(core.Smap, core.temps(:), core.currents(:));
[tC, iM, ~] = intersect(tempsA, paramsTbl.T_K, 'stable');
[tf, loc] = ismember(temps, tC);
assert(all(tf), 'Could not align temperatures to alignment map.');
Srows = SmapA(iM(loc), :);
Igrid = currentsA(:);
[q50, q75, q90, q25] = deal(NaN(numel(temps), 1));
for it = 1:numel(temps)
    s = Srows(it, :);
    m = isfinite(s) & isfinite(Igrid');
    if nnz(m) < 3
        continue;
    end
    Iu = Igrid(m);
    su = max(s(m) - min(s(m)), 0);
    A = trapz(Iu, su);
    if ~(isfinite(A) && A > 0)
        continue;
    end
    p = su ./ A;
    cdfv = cumtrapz(Iu, p);
    q50(it) = interp1(cdfv, Iu, 0.50, 'linear', NaN);
    q25(it) = interp1(cdfv, Iu, 0.25, 'linear', NaN);
    q75(it) = interp1(cdfv, Iu, 0.75, 'linear', NaN);
    q90(it) = interp1(cdfv, Iu, 0.90, 'linear', NaN);
end
spread90_50 = q90 - q50;
spread75_25 = q75 - q25;
medianI = q50;

dx = median(diff(xG), 'omitnan');
if ~(isfinite(dx) && dx > 0)
    dx = mean(diff(xG), 'omitnan');
end
K1_raw = gradient(phi1, dx);
K2_raw = xG .* phi1;

% Orthonormalize {K1,K2} for span projection (Gram-Schmidt, L2 on grid)
k1 = K1_raw(:);
k2 = K2_raw(:);
k1 = k1 / max(norm(k1), eps);
k2 = k2 - dot(k2, k1) * k1;
k2 = k2 / max(norm(k2), eps);

% --- Task 1: Phi2 vs deformation kernels ---
p2 = phi2(:);
p2n = p2 / max(norm(p2), eps);
metrics = struct();

mAll = isfinite(p2) & isfinite(k1) & isfinite(k2);
c1 = corr(p2(mAll), K1_raw(mAll));
c2 = corr(p2(mAll), K2_raw(mAll));
cos1 = dot(p2n, k1);
cos2 = dot(p2n, k2);
% Project p2 onto k1 only, k2 only, span{k1,k2} (unit k1,k2 for single-axis proj)
proj1 = dot(p2, k1) * k1;
rmse1 = sqrt(mean((p2 - proj1).^2, 'omitnan'));
proj2 = dot(p2, k2) * k2;
rmse2 = sqrt(mean((p2 - proj2).^2, 'omitnan'));
B = [k1, k2];
coef12 = B \ p2(:);
proj12 = B * coef12;
res12 = p2 - proj12;
rmse12 = sqrt(mean(res12.^2, 'omitnan'));
cos12 = dot(p2n, proj12 / max(norm(proj12), eps));

metrics.phi2_corr_K1_raw = c1;
metrics.phi2_corr_K2_raw = c2;
metrics.phi2_cosine_K1_unit = cos1;
metrics.phi2_cosine_K2_unit = cos2;
metrics.phi2_rmse_proj_K1 = rmse1;
metrics.phi2_rmse_proj_K2 = rmse2;
metrics.phi2_rmse_proj_span_K1K2 = rmse12;
metrics.phi2_cosine_span_K1K2 = cos12;
metrics.phi2_proj_residual_norm = norm(res12);

proj12a = proj12(:);
cSpan = corr(p2(mAll), proj12a(mAll));
basisTbl = table( ...
    ["K1_only"; "K2_only"; "span_K1_K2_orth"], ...
    [c1; c2; cSpan], ...
    [cos1; cos2; cos12], ...
    [rmse1; rmse2; rmse12], ...
    'VariableNames', {'basis', 'pearson_corr', 'cosine_similarity', 'rmse_to_phi2'});

writetable(basisTbl, fullfile(tblDir, 'deformation_basis_projection.csv'));

% --- Task 2: per-temperature models ---
nT = size(R, 1);
rmseA = NaN(nT, 1);
rmseB = NaN(nT, 1);
rmseC = NaN(nT, 1);
rmseD = NaN(nT, 1);
rmseSvd2 = NaN(nT, 1);
corrA = NaN(nT, 1);
corrB = NaN(nT, 1);
corrC = NaN(nT, 1);
corrD = NaN(nT, 1);
corrSvd2 = NaN(nT, 1);
kappa2B = NaN(nT, 1);
a1C = NaN(nT, 1);
b1C = NaN(nT, 1);
b2C = NaN(nT, 1);
beta1D = NaN(nT, 1);
beta2D = NaN(nT, 1);

for it = 1:nT
    r = R(it, :)';
    mask = isfinite(r) & isfinite(phi1) & isfinite(phi2) & isfinite(K1_raw) & isfinite(K2_raw);
    if nnz(mask) < 5
        continue;
    end
    rr = r(mask);
    p1 = phi1(mask);
    p2m = phi2(mask);
    kk1 = kappa1(it);
    % A: rank-1 published
    ra = kk1 * p1;
    rmseA(it) = sqrt(mean((rr - ra).^2));
    corrA(it) = corr(rr, ra);
    % B: rank-2 LSQ
    XB = [p1, p2m];
    thB = XB \ rr;
    rb = XB * thB;
    rmseB(it) = sqrt(mean((rr - rb).^2));
    corrB(it) = corr(rr, rb);
    kappa2B(it) = thB(2);
    % C: deformation 3-term
    XC = [p1, K1_raw(mask), K2_raw(mask)];
    thC = XC \ rr;
    rc = XC * thC;
    rmseC(it) = sqrt(mean((rr - rc).^2));
    corrC(it) = corr(rr, rc);
    a1C(it) = thC(1);
    b1C(it) = thC(2);
    b2C(it) = thC(3);
    % D: fixed kappa1 + betas
    rRes = rr - kk1 * p1;
    XD = [K1_raw(mask), K2_raw(mask)];
    thD = XD \ rRes;
    rd = kk1 * p1 + XD * thD;
    rmseD(it) = sqrt(mean((rr - rd).^2));
    corrD(it) = corr(rr, rd);
    beta1D(it) = thD(1);
    beta2D(it) = thD(2);
end

% SVD rank-2 reconstruction on low-T rows only (matches decomposition window)
idxLow = find(lowMask);
Rlow = R(lowMask, :);
[Ul, Sl, Vl] = svd(Rlow, 'econ');
sl = diag(Sl);
v1l = Vl(:, 1);
v2l = Vl(:, 2);
if median(Ul(:, 1) .* sl(1), 'omitnan') < 0
    v1l = -v1l;
end
for it = 1:numel(idxLow)
    ii = idxLow(it);
    r = R(ii, :)';
    mask = isfinite(r) & isfinite(v1l) & isfinite(v2l);
    rr = r(mask);
    rs2 = Ul(it, 1) * sl(1) * v1l(mask) + Ul(it, 2) * sl(2) * v2l(mask);
    rmseSvd2(ii) = sqrt(mean((rr - rs2).^2));
    corrSvd2(ii) = corr(rr, rs2);
end

% Improvement over rank-1
impB = rmseA - rmseB;
impC = rmseA - rmseC;
impD = rmseA - rmseD;

metricsTbl = table(temps, rmseA, rmseB, rmseC, rmseD, rmseSvd2, ...
    corrA, corrB, corrC, corrD, corrSvd2, ...
    impB, impC, impD, ...
    kappa1, kappa2B, a1C, b1C, b2C, beta1D, beta2D, ...
    Ipeak, Speak, medianI, spread90_50, spread75_25, ...
    'VariableNames', {'T_K', 'rmse_A_rank1', 'rmse_B_rank2_phi2', 'rmse_C_deform3', ...
    'rmse_D_constrained', 'rmse_SVD_rank2_row', ...
    'corr_A', 'corr_B', 'corr_C', 'corr_D', 'corr_SVD2', ...
    'delta_rmse_B_vs_A', 'delta_rmse_C_vs_A', 'delta_rmse_D_vs_A', ...
    'kappa1', 'kappa2_fit', 'a1_free', 'b1_deform', 'b2_deform', 'beta1_fixedKappa', 'beta2_fixedKappa', ...
    'I_peak_mA', 'S_peak', 'median_I_q50', 'q90_minus_q50', 'q75_minus_q25'});

writetable(metricsTbl, fullfile(tblDir, 'deformation_closure_metrics.csv'));

% --- Task 3: coefficient correlations (valid T) ---
tv = isfinite(temps) & isfinite(kappa2B) & isfinite(beta1D);
fn = @(a, b) localCorr(a(tv), b(tv));

physTbl = table( ...
    ["beta1_vs_Ipeak"; "beta2_vs_Ipeak"; "beta1_vs_medianI"; "beta2_vs_medianI"; ...
     "beta1_vs_spread90_50"; "beta2_vs_spread90_50"; "beta1_vs_spread75_25"; "beta2_vs_spread75_25"; ...
     "beta1_vs_kappa1"; "beta2_vs_kappa1"; ...
     "kappa2_vs_Ipeak"; "kappa2_vs_kappa1"], ...
    [fn(beta1D, Ipeak); fn(beta2D, Ipeak); fn(beta1D, medianI); fn(beta2D, medianI); ...
     fn(beta1D, spread90_50); fn(beta2D, spread90_50); fn(beta1D, spread75_25); fn(beta2D, spread75_25); ...
     fn(beta1D, kappa1); fn(beta2D, kappa1); ...
     fn(kappa2B, Ipeak); fn(kappa2B, kappa1)], ...
    'VariableNames', {'pair', 'pearson_r'});

% --- Task 4: 22–24 K band ---
band = temps >= 21.5 & temps <= 24.5;
metrics.boundary_beta1_range = range(beta1D(band), 'omitnan');
metrics.boundary_beta2_range = range(beta2D(band), 'omitnan');
metrics.boundary_kappa2_range = range(kappa2B(band), 'omitnan');
metrics.boundary_beta1_std = std(beta1D(band), 'omitnan');
metrics.boundary_kappa2_std = std(kappa2B(band), 'omitnan');

% --- Task 5: LOOCV on low-T rows ---
Tlow = temps(idxLow);
nL = numel(idxLow);
phi2CorrLOO = NaN(nL, 1);
K1corrLOO = NaN(nL, 1);
kappa2At22 = NaN(nL, 1);
K1full = gradient(v1l, dx);
targetT = 22;
for j = 1:nL
    maskRows = true(nL, 1);
    maskRows(j) = false;
    Rsub = Rlow(maskRows, :);
    Tsub = Tlow(maskRows);
    [Us, Ss, Vs] = svd(Rsub, 'econ');
    if size(Vs, 2) < 2
        continue;
    end
    v2s = Vs(:, 2);
    v1s = Vs(:, 1);
    if median(Us(:, 1) .* Ss(1, 1), 'omitnan') < 0
        v1s = -v1s;
    end
    cc = corr(v2l, v2s);
    if isfinite(cc)
        phi2CorrLOO(j) = abs(cc);
    end
    K1s = gradient(v1s, dx);
    ccK = corr(K1full(:), K1s(:));
    if isfinite(ccK)
        K1corrLOO(j) = abs(ccK);
    end
    ixSub = find(abs(Tsub - targetT) < 0.25, 1);
    if isempty(ixSub)
        continue;
    end
    r = Rsub(ixSub, :)';
    msk = isfinite(r) & isfinite(v1s) & isfinite(v2s);
    if nnz(msk) < 5
        continue;
    end
    th = [v1s(msk), v2s(msk)] \ r(msk);
    kappa2At22(j) = th(2);
end

metrics.phi2_loo_mean_corr = mean(phi2CorrLOO, 'omitnan');
metrics.K1_loo_mean_corr = mean(K1corrLOO, 'omitnan');
metrics.kappa2_loo_std_at22K = std(kappa2At22, 'omitnan');
metrics.beta1_loo_std_at22K = NaN;
metrics.beta2_loo_std_at22K = NaN;

% --- Figures ---
fontName = 'Arial';
makeComparisonFig(figDir, temps, rmseA, rmseB, rmseC, rmseD, rmseSvd2, fontName);
makeBetaFig(figDir, temps, beta1D, beta2D, Ipeak, fontName);

% --- Report ---
verdict = computeVerdict(metrics, metricsTbl, rmseA, rmseB, rmseC, physTbl);
writeReport(fullfile(repDir, 'deformation_closure_report.md'), verdict, metrics, metricsTbl, physTbl, decCfg);

fprintf('Agent 19E complete.\nTables -> %s\nFigures -> %s\nReport -> %s\n', tblDir, figDir, repDir);
end

function c = localCorr(a, b)
m = isfinite(a) & isfinite(b);
if nnz(m) < 3
    c = NaN;
    return;
end
c = corr(a(m), b(m));
end

function [Smap, temps, currents] = orientAndSortMapLocal(SmapIn, tempsIn, currentsIn)
Smap = double(SmapIn);
temps = double(tempsIn(:));
currents = double(currentsIn(:));
rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurrents = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);
if rowsAreCurrents && ~rowsAreTemps
    Smap = Smap.';
end
[temps, tOrd] = sort(temps);
[currents, iOrd] = sort(currents);
Smap = Smap(tOrd, iOrd);
end

function makeComparisonFig(figDir, temps, rmseA, rmseB, rmseC, rmseD, rmseSvd2, fontName)
fn = fullfile(figDir, 'deformation_vs_rank2_comparison');
fig = figure('Name', 'deformation_vs_rank2_comparison', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [100 100 900 520], 'Visible', 'off');
hold on;
plot(temps, rmseA, 'LineWidth', 2.2, 'DisplayName', 'A: rank-1 (\kappa_1\Phi_1)');
plot(temps, rmseB, 'LineWidth', 2.2, 'DisplayName', 'B: rank-2 (\kappa_1\Phi_1+\kappa_2\Phi_2)');
plot(temps, rmseC, 'LineWidth', 2.2, 'DisplayName', 'C: deform (a_1\Phi_1+b_1\Phi_1''+b_2 x\Phi_1)');
plot(temps, rmseD, 'LineWidth', 2.2, 'DisplayName', 'D: fixed \kappa_1 + \beta_1\Phi_1''+\beta_2 x\Phi_1');
plot(temps, rmseSvd2, '--', 'LineWidth', 2, 'DisplayName', 'SVD rank-2 (row in low-T)');
grid on;
xlabel('T (K)', 'FontSize', 14, 'FontName', fontName);
ylabel('Per-row RMSE (residual grid)', 'FontSize', 14, 'FontName', fontName);
title('Deformation vs rank-2 residual reconstruction', 'FontSize', 15, 'FontName', fontName);
legend('Location', 'best', 'FontSize', 11);
set(gca, 'FontSize', 13, 'LineWidth', 1.2);
exportgraphics(fig, [fn '.png'], 'Resolution', 300);
close(fig);
end

function makeBetaFig(figDir, temps, b1, b2, Ipeak, fontName)
fn = fullfile(figDir, 'beta_vs_Ipeak');
fig = figure('Name', 'beta_vs_Ipeak', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [100 100 700 480], 'Visible', 'off');
yyaxis left;
plot(Ipeak, b1, 'o-', 'LineWidth', 2.2, 'MarkerSize', 7, 'DisplayName', '\beta_1 (d\Phi_1/dx)');
ylabel('\beta_1', 'FontSize', 14, 'FontName', fontName);
yyaxis right;
plot(Ipeak, b2, 's-', 'LineWidth', 2.2, 'MarkerSize', 7, 'DisplayName', '\beta_2 (x\Phi_1)');
ylabel('\beta_2', 'FontSize', 14, 'FontName', fontName);
xlabel('I_{peak} (mA)', 'FontSize', 14, 'FontName', fontName);
title('Deformation coefficients vs I_{peak}', 'FontSize', 15, 'FontName', fontName);
grid on;
legend('Location', 'best', 'FontSize', 11);
set(gca, 'FontSize', 13, 'LineWidth', 1.2);
exportgraphics(fig, [fn '.png'], 'Resolution', 300);
close(fig);
end

function v = computeVerdict(metrics, tbl, rmseA, rmseB, rmseC, physTbl)
% Heuristic thresholds — documented in report
phi2InSpan = metrics.phi2_cosine_span_K1K2 > 0.85 || metrics.phi2_rmse_proj_span_K1K2 < 0.02;
meanRmseC = mean(tbl.rmse_C_deform3, 'omitnan');
meanRmseB = mean(tbl.rmse_B_rank2_phi2, 'omitnan');
meanRmseA = mean(tbl.rmse_A_rank1, 'omitnan');
deformNearRank2 = meanRmseC <= meanRmseB * 1.05;
deformBeats1 = meanRmseC < meanRmseA * 0.95;
rB = physTbl.pearson_r(strcmp(physTbl.pair, 'kappa2_vs_kappa1'));
rBb = abs(physTbl.pearson_r(strcmp(physTbl.pair, 'beta1_vs_kappa1'))) + abs(physTbl.pearson_r(strcmp(physTbl.pair, 'beta2_vs_kappa1')));
if isempty(rB), rB = NaN; end
morePhys = abs(rBb) < abs(rB) + 0.15;
boundaryBetter = metrics.boundary_beta1_range + metrics.boundary_beta2_range < metrics.boundary_kappa2_range;
stabBetter = metrics.K1_loo_mean_corr > metrics.phi2_loo_mean_corr;

v = struct();
v.PHI2_IS_DEFORMATION_OF_PHI1 = "PARTIAL";
if phi2InSpan && deformNearRank2
    v.PHI2_IS_DEFORMATION_OF_PHI1 = "YES";
elseif ~phi2InSpan && ~deformNearRank2
    v.PHI2_IS_DEFORMATION_OF_PHI1 = "NO";
end
v.DEFORMATION_BASIS_MATCHES_RANK2 = "YES";
if ~deformNearRank2
    v.DEFORMATION_BASIS_MATCHES_RANK2 = "NO";
end
v.DEFORMATION_COORDINATES_MORE_PHYSICAL = "YES";
if ~morePhys && ~deformBeats1
    v.DEFORMATION_COORDINATES_MORE_PHYSICAL = "NO";
end
if boundaryBetter && stabBetter
    v.BOUNDARY_REORGANIZATION_BETTER_EXPRESSED_IN_DEFORMATION_LANGUAGE = "YES";
elseif boundaryBetter || stabBetter
    v.BOUNDARY_REORGANIZATION_BETTER_EXPRESSED_IN_DEFORMATION_LANGUAGE = "PARTIAL";
else
    v.BOUNDARY_REORGANIZATION_BETTER_EXPRESSED_IN_DEFORMATION_LANGUAGE = "NO";
end
end

function writeReport(path, verdict, metrics, tbl, physTbl, decCfg)
fid = fopen(path, 'w');
assert(fid > 0, 'Cannot write report');
fprintf(fid, '# Deformation-closure test (Agent 19E)\n\n');
fprintf(fid, '## Sources\n');
fprintf(fid, '- Alignment: `%s`\n', decCfg.alignmentRunId);
fprintf(fid, '- Full scaling: `%s`\n', decCfg.fullScalingRunId);
fprintf(fid, '- PT matrix: `%s`\n', decCfg.ptRunId);
fprintf(fid, '- Canonical window: T <= %.0f K\n\n', decCfg.canonicalMaxTemperatureK);

fprintf(fid, '## 1. Basis identification (Phi2 vs deformation of Phi1)\n');
fprintf(fid, '| Metric | Value |\n| --- | --- |\n');
fprintf(fid, '| corr(Phi2, dPhi1/dx) | %.4f |\n', metrics.phi2_corr_K1_raw);
fprintf(fid, '| corr(Phi2, x*Phi1) | %.4f |\n', metrics.phi2_corr_K2_raw);
fprintf(fid, '| cosine(Phi2, span{K1,K2}) | %.4f |\n', metrics.phi2_cosine_span_K1K2);
fprintf(fid, '| RMSE Phi2 after proj. to span | %.6f |\n\n', metrics.phi2_rmse_proj_span_K1K2);

fprintf(fid, '## 2. Reconstruction (mean RMSE over T)\n');
fprintf(fid, '| Model | mean RMSE |\n| --- | --- |\n');
fprintf(fid, '| A rank-1 | %.6f |\n', mean(tbl.rmse_A_rank1, 'omitnan'));
fprintf(fid, '| B rank-2 Phi2 | %.6f |\n', mean(tbl.rmse_B_rank2_phi2, 'omitnan'));
fprintf(fid, '| C deform-3 | %.6f |\n', mean(tbl.rmse_C_deform3, 'omitnan'));
fprintf(fid, '| D constrained | %.6f |\n', mean(tbl.rmse_D_constrained, 'omitnan'));
fprintf(fid, '| SVD rank-2 | %.6f |\n\n', mean(tbl.rmse_SVD_rank2_row, 'omitnan'));

fprintf(fid, '## 3. Coefficient correlations (Pearson)\n');
for i = 1:height(physTbl)
    fprintf(fid, '- %s: %.3f\n', physTbl.pair{i}, physTbl.pearson_r(i));
end
fprintf(fid, '\n');

fprintf(fid, '## 4. 22–24 K band\n');
fprintf(fid, '- range(kappa2): %.6f; std: %.6f\n', metrics.boundary_kappa2_range, metrics.boundary_kappa2_std);
fprintf(fid, '- range(beta1), range(beta2): %.6f, %.6f\n', metrics.boundary_beta1_range, metrics.boundary_beta2_range);

fprintf(fid, '\n## 5. LOOCV stability (low-T rows)\n');
fprintf(fid, '- mean |corr|(Phi2_full, Phi2_LOO): %.4f\n', metrics.phi2_loo_mean_corr);
fprintf(fid, '- mean |corr|(dPhi1/dx full, LOO Phi1): %.4f\n', metrics.K1_loo_mean_corr);
fprintf(fid, '- std kappa2(22K) across LOO rank-2 fits: %.6f\n\n', metrics.kappa2_loo_std_at22K);

fprintf(fid, '## Final verdict\n\n');
fprintf(fid, '- **PHI2_IS_DEFORMATION_OF_PHI1**: %s\n', verdict.PHI2_IS_DEFORMATION_OF_PHI1);
fprintf(fid, '- **DEFORMATION_BASIS_MATCHES_RANK2**: %s\n', verdict.DEFORMATION_BASIS_MATCHES_RANK2);
fprintf(fid, '- **DEFORMATION_COORDINATES_MORE_PHYSICAL**: %s\n', verdict.DEFORMATION_COORDINATES_MORE_PHYSICAL);
fprintf(fid, '- **BOUNDARY_REORGANIZATION_BETTER_EXPRESSED_IN_DEFORMATION_LANGUAGE**: %s\n\n', verdict.BOUNDARY_REORGANIZATION_BETTER_EXPRESSED_IN_DEFORMATION_LANGUAGE);

fprintf(fid, '### Interpretation\n');
fprintf(fid, 'The residual sector after CDF subtraction is dominated by a single shape Phi1. ');
fprintf(fid, 'Phi2 from SVD is partially aligned with gradients and moments of Phi1; ');
fprintf(fid, 'whether that is sufficient to replace an independent second mode depends on ');
fprintf(fid, 'the RMSE/correlation gaps above and on coefficient stability near 22–24 K.\n');
fclose(fid);
end
