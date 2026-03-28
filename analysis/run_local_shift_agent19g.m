function run_local_shift_agent19g()
% run_local_shift_agent19g
% Agent 19G: test whether residual deltaS is interpretable as a local shift /
% distortion of the PT-derived CDF backbone S_CDF(I,T).
% Read-only inputs; writes repo-root tables/, figures/, reports/.
%
% Canonical pipeline: same sources as run_deformation_closure_agent19e.

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
decCfg.runLabel = 'local_shift_agent19g_internal';
decCfg.alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
decCfg.fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
decCfg.ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';
decCfg.canonicalMaxTemperatureK = 30;
decCfg.nXGrid = 220;
decCfg.maxModes = 2;
decCfg.skipFigures = true;

out = switching_residual_decomposition_analysis(decCfg);

temps = out.temperaturesK(:);
nT = numel(temps);
I = out.currents_mA(:);
Smap = localLoadSmapAligned(repoRoot, decCfg, temps, I);
Scdf = Smap - out.deltaS;
deltaS = out.deltaS;
xG = out.xGrid(:);
phi1 = out.phi(:);
phi2 = out.phi2(:);
if isempty(phi2) || ~any(isfinite(phi2))
    error('Phi2 missing; set maxModes>=2 in decomposition.');
end
phi2 = phi2(:);
kappa1 = out.kappaAll(:);
Xrows = out.Xrows;
lowMask = out.lowTemperatureMask(:);

dScdf = NaN(size(Scdf));
for it = 1:nT
    dScdf(it, :) = gradient(Scdf(it, :), I(:)');
end

halfRange = 0.35 * (max(I) - min(I));
halfRange = min(max(halfRange, 2), 80);

deltaI = NaN(nT, 1);
rmse_S_vs_shifted = NaN(nT, 1);
corr_S_vs_shifted = NaN(nT, 1);
rmse_deltaS_row = NaN(nT, 1);
kappa2 = NaN(nT, 1);
rmse_tangent = NaN(nT, 1);
corr_tangent = NaN(nT, 1);
rmse_rank2_I = NaN(nT, 1);
corr_rank2_I = NaN(nT, 1);
frac_var_tangent = NaN(nT, 1);
rmse_ratio_tan_over_r2 = NaN(nT, 1);

for it = 1:nT
    Sobs = Smap(it, :)';
    rowC = Scdf(it, :)';
    ds = deltaS(it, :)';
    m0 = isfinite(Sobs) & isfinite(rowC) & isfinite(ds);
    if nnz(m0) < 5
        continue;
    end
    rmse_deltaS_row(it) = sqrt(mean(ds(m0) .^ 2));

    diHat = localArgminShiftGrid(Sobs, I, rowC, m0, halfRange, 161);
    fval = localRmseShift(Sobs, I, rowC, diHat, m0);
    deltaI(it) = diHat;
    if isfinite(fval)
        rmse_S_vs_shifted(it) = fval;
    end
    Spred = localScdfShifted(I, rowC, diHat);
    m1 = m0 & isfinite(Spred);
    if nnz(m1) >= 5
        corr_S_vs_shifted(it) = corr(Sobs(m1), Spred(m1));
    end

    dRow = dScdf(it, :)';
    tang = diHat .* dRow;
    mt = m0 & isfinite(tang);
    if nnz(mt) >= 5
        rmse_tangent(it) = sqrt(mean((ds(mt) - tang(mt)) .^ 2));
        corr_tangent(it) = corr(ds(mt), tang(mt));
        v0 = var(ds(mt), 0, 'omitnan');
        if isfinite(v0) && v0 > eps
            frac_var_tangent(it) = 1 - mean((ds(mt) - tang(mt)) .^ 2, 'omitnan') / v0;
        end
    end

    xr = Xrows(it, :)';
    p1 = interp1(xG, phi1, xr, 'linear', NaN);
    p2 = interp1(xG, phi2, xr, 'linear', NaN);
    mask = m0 & isfinite(p1) & isfinite(p2);
    if nnz(mask) >= 5
        rr = ds(mask);
        XB = [p1(mask), p2(mask)];
        th = XB \ rr;
        kappa2(it) = th(2);
        pred2 = XB * th;
        rmse_rank2_I(it) = sqrt(mean((rr - pred2) .^ 2));
        corr_rank2_I(it) = corr(rr, pred2);
    end
    if isfinite(rmse_tangent(it)) && isfinite(rmse_rank2_I(it)) && rmse_rank2_I(it) > eps
        rmse_ratio_tan_over_r2(it) = rmse_tangent(it) / rmse_rank2_I(it);
    end
end

alpha = kappa2 ./ max(abs(kappa1), eps);

mLow = lowMask & isfinite(deltaI) & isfinite(kappa2);
r_dI_k2 = localSafeCorr(deltaI(mLow), kappa2(mLow));
r_dI_alpha = localSafeCorr(deltaI(mLow), alpha(mLow));

medTan = median(rmse_tangent(lowMask), 'omitnan');
medR2 = median(rmse_rank2_I(lowMask), 'omitnan');
medCorrTan = median(corr_tangent(lowMask), 'omitnan');
medCorrR2 = median(corr_rank2_I(lowMask), 'omitnan');

stab = localLoocvCorr(deltaI(lowMask), kappa2(lowMask));

metricsTbl = table( ...
    temps, deltaI, rmse_S_vs_shifted, corr_S_vs_shifted, rmse_deltaS_row, ...
    kappa1, kappa2, alpha, ...
    rmse_tangent, corr_tangent, frac_var_tangent, ...
    rmse_rank2_I, corr_rank2_I, rmse_ratio_tan_over_r2, ...
    'VariableNames', { ...
    'T_K', 'deltaI_mA', 'rmse_S_vs_SCDF_shifted', 'corr_S_vs_SCDF_shifted', 'rmse_deltaS_row', ...
    'kappa1', 'kappa2', 'alpha_kappa2_over_kappa1', ...
    'rmse_deltaS_vs_tangent', 'corr_deltaS_vs_tangent', 'R2_like_tangent_frac', ...
    'rmse_deltaS_vs_rank2_Igrid', 'corr_deltaS_vs_rank2_Igrid', 'rmse_tangent_over_rank2'});

writetable(metricsTbl, fullfile(tblDir, 'local_shift_metrics.csv'));

summaryRow = table( ...
    medTan, medR2, medCorrTan, medCorrR2, r_dI_k2, r_dI_alpha, stab, ...
    'VariableNames', { ...
    'median_rmse_tangent_lowT', 'median_rmse_rank2_lowT', ...
    'median_corr_tangent_lowT', 'median_corr_rank2_lowT', ...
    'corr_deltaI_kappa2_lowT', 'corr_deltaI_alpha_lowT', ...
    'loocv_mean_abs_corr_deltaI_kappa2'});

writetable(summaryRow, fullfile(tblDir, 'local_shift_summary.csv'));

fontName = 'Arial';
makeDeltaIFig(figDir, temps(lowMask), deltaI(lowMask), kappa2(lowMask), fontName);

verdict = localVerdict( ...
    medTan, medR2, medCorrTan, medCorrR2, r_dI_k2, metricsTbl, lowMask);

writeLocalShiftReport(fullfile(repDir, 'local_shift_report.md'), decCfg, verdict, summaryRow, metricsTbl);

fprintf('Agent 19G complete.\nTables -> %s\nFigures -> %s\nReport -> %s\n', tblDir, figDir, repDir);
end

function Smap = localLoadSmapAligned(repoRoot, decCfg, temps, currents)
alignPath = fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.alignmentRunId, ...
    'switching_alignment_core_data.mat');
core = load(alignPath, 'Smap', 'temps', 'currents');
[SmapA, tempsA, currentsA] = orientAndSortMapLocal(core.Smap, core.temps(:), core.currents(:));
[tf, loc] = ismember(temps, tempsA);
assert(all(tf), 'Temperature alignment failed.');
assert(isequal(currentsA(:), currents(:)), 'Current grid mismatch.');
Smap = SmapA(loc, :);
end

function y = localScdfShifted(I, scdfRow, deltaI)
% S_CDF evaluated at I - deltaI (shift of backbone relative to observation axis).
y = interp1(I(:), scdfRow(:), I(:) - deltaI, 'linear', NaN);
end

function diHat = localArgminShiftGrid(Sobs, I, scdfRow, m0, halfRange, nGrid)
if nargin < 6 || isempty(nGrid)
    nGrid = 161;
end
dis = linspace(-halfRange, halfRange, nGrid);
best = inf;
diHat = NaN;
for k = 1:numel(dis)
    v = localRmseShift(Sobs, I, scdfRow, dis(k), m0);
    if v < best
        best = v;
        diHat = dis(k);
    end
end
end

function r = localRmseShift(Sobs, I, scdfRow, deltaI, m)
Sp = localScdfShifted(I, scdfRow, deltaI);
mm = m & isfinite(Sobs) & isfinite(Sp);
if nnz(mm) < 3
    r = 1e9;
    return;
end
d = Sobs(mm) - Sp(mm);
r = sqrt(mean(d .^ 2));
end

function c = localSafeCorr(a, b)
m = isfinite(a) & isfinite(b);
if nnz(m) < 4
    c = NaN;
    return;
end
c = corr(a(m), b(m));
end

function s = localLoocvCorr(a, b)
m = isfinite(a) & isfinite(b);
a = a(m);
b = b(m);
n = numel(a);
if n < 6
    s = NaN;
    return;
end
fullR = corr(a, b);
dev = 0;
for i = 1:n
    mask = true(n, 1);
    mask(i) = false;
    dev = dev + abs(corr(a(mask), b(mask)) - fullR);
end
s = dev / n;
end

function v = localVerdict(medTan, medR2, medCorrTan, medCorrR2, r_dI_k2, tbl, lowMask)
% Heuristic thresholds — documented in report.
tangentOk = isfinite(medCorrTan) && medCorrTan >= 0.55;
tangentCompetitive = isfinite(medTan) && isfinite(medR2) && medTan <= medR2 * 1.15;
shiftExplainsS = isfinite(median(tbl.corr_S_vs_SCDF_shifted(lowMask), 'omitnan')) && ...
    median(tbl.corr_S_vs_SCDF_shifted(lowMask), 'omitnan') >= 0.92;

v = struct();
if tangentOk && tangentCompetitive && shiftExplainsS
    v.RESIDUAL_IS_LOCAL_SHIFT = "YES";
elseif (tangentOk || shiftExplainsS) && tangentCompetitive
    v.RESIDUAL_IS_LOCAL_SHIFT = "PARTIAL";
else
    v.RESIDUAL_IS_LOCAL_SHIFT = "NO";
end

if isfinite(r_dI_k2) && abs(r_dI_k2) >= 0.45
    v.SHIFT_EXPLAINS_KAPPA2 = "YES";
elseif isfinite(r_dI_k2) && abs(r_dI_k2) >= 0.25
    v.SHIFT_EXPLAINS_KAPPA2 = "PARTIAL";
else
    v.SHIFT_EXPLAINS_KAPPA2 = "NO";
end

rank2edge = isfinite(medCorrR2) && medCorrR2 > medCorrTan + 0.08;
if (strcmp(v.RESIDUAL_IS_LOCAL_SHIFT, "YES") || strcmp(v.RESIDUAL_IS_LOCAL_SHIFT, "PARTIAL")) && ...
        strcmp(v.SHIFT_EXPLAINS_KAPPA2, "YES") && ~rank2edge
    v.DEFORMATION_INTERPRETATION_VALID = "YES";
elseif strcmp(v.RESIDUAL_IS_LOCAL_SHIFT, "NO") && rank2edge
    v.DEFORMATION_INTERPRETATION_VALID = "NO";
else
    v.DEFORMATION_INTERPRETATION_VALID = "PARTIAL";
end
end

function writeLocalShiftReport(path, decCfg, verdict, summaryRow, tbl)
fid = fopen(path, 'w');
assert(fid > 0, 'Cannot write report');
fprintf(fid, '# Local shift / backbone deformation test (Agent 19G)\n\n');
fprintf(fid, '## Sources\n');
fprintf(fid, '- Alignment: `%s`\n', decCfg.alignmentRunId);
fprintf(fid, '- Full scaling: `%s`\n', decCfg.fullScalingRunId);
fprintf(fid, '- PT matrix: `%s`\n', decCfg.ptRunId);
fprintf(fid, '- Canonical window: T <= %.0f K\n\n', decCfg.canonicalMaxTemperatureK);

fprintf(fid, '## Method\n');
fprintf(fid, '- For each T, **deltaI** minimizes RMSE between **S(I)** and **S_CDF(I - deltaI)** on the alignment current grid (PT-derived CDF backbone times S_peak).\n');
fprintf(fid, '- **Tangent model:** `deltaS(I) ~ deltaI(T) * dS_CDF/dI`.\n');
fprintf(fid, '- **Rank-2 reference:** `deltaS ~ kappa1*Phi1 + kappa2*Phi2` with LSQ **kappa2** on the same I samples as the residual (Phi evaluated at row-wise x).\n\n');

fprintf(fid, '## Aggregate metrics (low-T window)\n');
fprintf(fid, '| Quantity | Value |\n| --- | --- |\n');
fprintf(fid, '| Median RMSE (tangent vs deltaS) | %.6g |\n', summaryRow.median_rmse_tangent_lowT);
fprintf(fid, '| Median RMSE (rank-2 vs deltaS, I grid) | %.6g |\n', summaryRow.median_rmse_rank2_lowT);
fprintf(fid, '| Median corr (deltaS, tangent) | %.4f |\n', summaryRow.median_corr_tangent_lowT);
fprintf(fid, '| Median corr (deltaS, rank-2) | %.4f |\n', summaryRow.median_corr_rank2_lowT);
fprintf(fid, '| corr(deltaI, kappa2) | %.4f |\n', summaryRow.corr_deltaI_kappa2_lowT);
fprintf(fid, '| corr(deltaI, alpha) | %.4f |\n', summaryRow.corr_deltaI_alpha_lowT);
fprintf(fid, '| LOOCV mean |Delta corr| (deltaI vs kappa2) | %.4f |\n\n', summaryRow.loocv_mean_abs_corr_deltaI_kappa2);

fprintf(fid, '## Final verdict\n\n');
fprintf(fid, '| Verdict | Value |\n| --- | --- |\n');
fprintf(fid, '| **RESIDUAL_IS_LOCAL_SHIFT** | %s |\n', verdict.RESIDUAL_IS_LOCAL_SHIFT);
fprintf(fid, '| **SHIFT_EXPLAINS_KAPPA2** | %s |\n', verdict.SHIFT_EXPLAINS_KAPPA2);
fprintf(fid, '| **DEFORMATION_INTERPRETATION_VALID** | %s |\n\n', verdict.DEFORMATION_INTERPRETATION_VALID);

fprintf(fid, '### Interpretation notes\n');
fprintf(fid, '- **RESIDUAL_IS_LOCAL_SHIFT** is YES when the tangent approximation tracks deltaS about as well as the rank-2 surface fit and **S** matches the shifted CDF backbone with high correlation.\n');
fprintf(fid, '- **SHIFT_EXPLAINS_KAPPA2** reports whether the scalar shift moves with the second amplitude kappa2 across low-T rows.\n');
fprintf(fid, '- **DEFORMATION_INTERPRETATION_VALID** combines the above; a strong rank-2 edge without tangent support favors an independent second mode rather than pure I-space shear of the CDF.\n\n');

fprintf(fid, '## Per-temperature table\n');
fprintf(fid, 'See `tables/local_shift_metrics.csv` for full rows.\n');
fclose(fid);
end

function makeDeltaIFig(figDir, T, dI, k2, fontName)
fn = fullfile(figDir, 'deltaI_vs_kappa2');
fig = figure('Name', 'deltaI_vs_kappa2', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [100 100 720 520], 'Visible', 'off');
scatter(k2, dI, 36, T, 'filled');
cb = colorbar;
cb.Label.String = 'T (K)';
xlabel('\kappa_2 (rank-2 LSQ on I grid)', 'FontSize', 14, 'FontName', fontName);
ylabel('\Delta I (mA) — shift minimizing ||S - S_{CDF}(I-\Delta I)||', 'FontSize', 13, 'FontName', fontName);
title('Local CDF shift vs \kappa_2 (low-T)', 'FontSize', 15, 'FontName', fontName);
grid on;
set(gca, 'FontSize', 13, 'LineWidth', 1.2);
exportgraphics(fig, [fn '.png'], 'Resolution', 300);
close(fig);
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
