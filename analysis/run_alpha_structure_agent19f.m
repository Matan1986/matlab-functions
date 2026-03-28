function run_alpha_structure_agent19f()
%RUN_ALPHA_STRUCTURE_AGENT19F  AGENT 19F — deformation ratio alpha = kappa2/kappa1
%
% Read-only inputs (same canonical sources as run_deformation_closure_agent19e).
% Writes:
%   tables/alpha_structure.csv
%   figures/alpha_vs_T.png
%   reports/alpha_structure_report.md
%
% Definitions: kappa1 = rank-1 residual amplitude (kappaAll); kappa2 = rank-2
% LSQ coefficient on Phi2 in R ~ kappa1*Phi1 + kappa2*Phi2 (per T).

set(0, 'DefaultFigureVisible', 'off');

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
decCfg.runLabel = 'alpha_structure_agent19f_internal';
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
phi1 = out.phi(:);
phi2 = out.phi2(:);
Ipeak = out.Ipeak_mA(:);
Speak = out.Speak;
widthI = out.width_mA(:);
kappa1 = out.kappaAll(:);

% --- Current distribution moments (same quantile construction as 19E) ---
paramsPath = fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.fullScalingRunId, ...
    'tables', 'switching_full_scaling_parameters.csv');
paramsTbl = readtable(paramsPath);
alignPath = fullfile(repoRoot, 'results', 'switching', 'runs', decCfg.alignmentRunId, ...
    'switching_alignment_core_data.mat');
core = load(alignPath, 'Smap', 'temps', 'currents');
[SmapA, tempsA, currentsA] = orientAndSortMapLocal(core.Smap, core.temps(:), core.currents(:));
[tC, iM, iS] = intersect(tempsA, paramsTbl.T_K, 'stable');
assert(numel(tC) == numel(temps), 'Temperature alignment mismatch.');
Srows = SmapA(iM, :);
Igrid = currentsA(:);
[q50, q75, q90, q25] = deal(NaN(numel(temps), 1));
skewI = NaN(numel(temps), 1);
for it = 1:numel(temps)
    s = Srows(it, :);
    m = isfinite(s) & isfinite(Igrid');
    if nnz(m) < 3
        continue;
    end
    Iu = Igrid(m);
    su = max(s(m) - min(s(m)), 0);
    Iu = Iu(:);
    su = su(:);
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
    mu = trapz(Iu, p .* Iu);
    v2 = trapz(Iu, p .* (Iu - mu).^2);
    v3 = trapz(Iu, p .* (Iu - mu).^3);
    if isfinite(v2) && v2 > 0
        skewI(it) = v3 / (v2^1.5);
    end
end
spread90_50 = q90 - q50;
spread75_25 = q75 - q25;
medianI = q50;
% Asymmetry: normalized difference of upper vs lower half-spread (dimensionless)
asymmetry = (q90 - q50) - (q50 - q25);
asymmetry(~isfinite(q90) | ~isfinite(q50) | ~isfinite(q25)) = NaN;

% --- kappa2 from rank-2 LSQ (same as 19E) ---
nT = size(R, 1);
kappa2 = NaN(nT, 1);
for it = 1:nT
    r = R(it, :)';
    mask = isfinite(r) & isfinite(phi1) & isfinite(phi2);
    if nnz(mask) < 5
        continue;
    end
    rr = r(mask);
    p1 = phi1(mask);
    p2m = phi2(mask);
    XB = [p1, p2m];
    thB = XB \ rr;
    kappa2(it) = thB(2);
end

epsK = max(abs(kappa1), 1e-12);
alpha = kappa2 ./ kappa1;
alpha(abs(kappa1) < 1e-14) = NaN;

% --- Regime / sharp change near 22–24 K ---
[Ts, ord] = sort(temps);
alS = alpha(ord);
d1 = [diff(alS) ./ max(diff(Ts), eps); NaN];
band22 = Ts >= 21.5 & Ts <= 24.5;
idx22 = find(abs(Ts - 22) < 0.31, 1);
idx24 = find(abs(Ts - 24) < 0.31, 1);
slope_before = NaN;
slope_after = NaN;
slope_mid = NaN;
if ~isempty(idx22) && idx24 > idx22
    i0 = max(1, idx22 - 2);
    slope_before = (alS(idx22) - alS(i0)) / max(Ts(idx22) - Ts(i0), eps);
    slope_mid = (alS(idx24) - alS(idx22)) / max(Ts(idx24) - Ts(idx22), eps);
    i1 = min(numel(Ts), idx24 + 2);
    slope_after = (alS(i1) - alS(idx24)) / max(Ts(i1) - Ts(idx24), eps);
end
max_dalpha_dT_band = max(abs(d1(band22)), [], 'omitnan');
d1_out = d1(~band22 & isfinite(d1));
med_abs_dalpha = median(abs(d1_out), 'omitnan');
if ~isfinite(med_abs_dalpha) || med_abs_dalpha < 1e-12
    med_abs_dalpha = median(abs(d1(isfinite(d1))), 'omitnan');
end
sharp_ratio = max_dalpha_dT_band / max(med_abs_dalpha, eps);
sharp_change_22_24 = isfinite(sharp_ratio) && sharp_ratio > 2.5;

% --- Correlations (valid rows) ---
maskF = isfinite(alpha) & isfinite(kappa1) & isfinite(kappa2);
targets = struct( ...
    'I_peak', Ipeak, ...
    'median_I_q50', medianI, ...
    'q90_minus_q50', spread90_50, ...
    'q75_minus_q25', spread75_25, ...
    'skew_I_weighted', skewI, ...
    'asymmetry_q_spread', asymmetry, ...
    'T_K', temps, ...
    'width_mA', widthI, ...
    'S_peak', Speak);
fnames = fieldnames(targets);
corrPear = NaN(numel(fnames), 1);
corrSpear = NaN(numel(fnames), 1);
for k = 1:numel(fnames)
    v = targets.(fnames{k});
    m = maskF & isfinite(v);
    if nnz(m) >= 4
        corrPear(k) = corr(alpha(m), v(m));
        corrSpear(k) = corr(alpha(m), v(m), 'type', 'Spearman');
    end
end

% --- Stability: multiplicative perturbation ---
rng(19);
nMc = 400;
relNoise = 0.01;
alphaMc = NaN(nMc, 1);
k2Mc = NaN(nMc, 1);
idxV = find(maskF);
if ~isempty(idxV)
    k1v = kappa1(idxV);
    k2v = kappa2(idxV);
    for s = 1:nMc
        k1p = k1v .* (1 + relNoise * randn(size(k1v)));
        k2p = k2v .* (1 + relNoise * randn(size(k2v)));
        al = k2p ./ k1p;
        alphaMc(s) = mean(al, 'omitnan');
        k2Mc(s) = mean(k2p, 'omitnan');
    end
end
cv_alpha_mc = std(alphaMc, 'omitnan') / max(mean(abs(alpha(maskF)), 'omitnan'), eps);
cv_kappa2_mc = std(k2Mc, 'omitnan') / max(mean(abs(kappa2(maskF)), 'omitnan'), eps);
alpha_more_sensitive_than_k2 = cv_alpha_mc > cv_kappa2_mc * 1.05;

% LOO stability at 22 K (kappa2 only — same construction as 19E)
lowMask = out.lowTemperatureMask(:);
idxLow = find(lowMask);
Rlow = R(lowMask, :);
Tlow = temps(lowMask);
kappa2At22 = NaN(numel(idxLow), 1);
targetT = 22;
for j = 1:numel(idxLow)
    maskRows = true(numel(idxLow), 1);
    maskRows(j) = false;
    Rsub = Rlow(maskRows, :);
    [~, ~, Vs] = svd(Rsub, 'econ');
    v2s = Vs(:, 2);
    v1s = Vs(:, 1);
    ix = find(abs(Tlow - targetT) < 0.25, 1);
    if isempty(ix)
        continue;
    end
    r = Rlow(ix, :)';
    msk = isfinite(r) & isfinite(v1s) & isfinite(v2s);
    th = [v1s(msk), v2s(msk)] \ r(msk);
    kappa2At22(j) = th(2);
end
loo_std_k2 = std(kappa2At22, 'omitnan');
ix22f = find(abs(temps - 22) < 0.31, 1);
k1_22 = NaN;
if ~isempty(ix22f)
    k1_22 = kappa1(ix22f);
end
alpha_loo = kappa2At22 / max(abs(k1_22), eps);
loo_std_alpha = std(alpha_loo, 'omitnan');

% --- Output table ---
mainTbl = table(temps, kappa1, kappa2, alpha, Ipeak, medianI, spread90_50, spread75_25, ...
    skewI, asymmetry, widthI, Speak, ...
    'VariableNames', {'T_K', 'kappa1', 'kappa2', 'alpha', 'I_peak_mA', 'median_I_q50', ...
    'q90_minus_q50', 'q75_minus_q25', 'skew_I_weighted', 'asymmetry_q_spread', ...
    'width_mA', 'S_peak'});

writetable(mainTbl, fullfile(tblDir, 'alpha_structure.csv'));

% --- Figure ---
fontName = 'Arial';
figPath = fullfile(figDir, 'alpha_vs_T.png');
fig = figure('Name', 'alpha_vs_T', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [80 80 820 420], 'Visible', 'off');
hold on;
amin = min(alpha, [], 'omitnan');
amax = max(alpha, [], 'omitnan');
pad = 0.05 * max(amax - amin, max(abs([amin; amax; eps])));
y1 = amin - pad;
y2 = amax + pad;
patch([21.5 24.5 24.5 21.5], [y1 y1 y2 y2], ...
    [0.92 0.95 1], 'EdgeColor', 'none', 'FaceAlpha', 0.35);
plot(temps, alpha, 'o-', 'LineWidth', 2, 'MarkerSize', 7, 'Color', [0.15 0.35 0.65]);
grid on;
ylim([y1, y2]);
xlabel('T (K)', 'FontSize', 14, 'FontName', fontName);
ylabel('\alpha = \kappa_2 / \kappa_1', 'FontSize', 14, 'FontName', fontName);
title('Deformation ratio \alpha(T) with 22–24 K band shaded', 'FontSize', 15, 'FontName', fontName);
set(gca, 'FontSize', 13, 'LineWidth', 1.2);
exportgraphics(fig, figPath, 'Resolution', 300);
close(fig);

% --- Verdict ---
verdict = computeVerdict19f(corrPear, corrSpear, fnames, sharp_change_22_24, sharp_ratio, ...
    cv_alpha_mc, cv_kappa2_mc, loo_std_alpha, loo_std_k2);

writeReport19f(fullfile(repDir, 'alpha_structure_report.md'), verdict, decCfg, ...
    fnames, corrPear, corrSpear, sharp_ratio, max_dalpha_dT_band, slope_before, slope_mid, slope_after, ...
    cv_alpha_mc, cv_kappa2_mc, loo_std_alpha, loo_std_k2, alpha_more_sensitive_than_k2);

fprintf('Agent 19F complete.\nTables -> %s\nFigures -> %s\nReport -> %s\n', ...
    fullfile(tblDir, 'alpha_structure.csv'), figPath, fullfile(repDir, 'alpha_structure_report.md'));
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

function v = computeVerdict19f(corrPear, ~, fnames, sharpFlag, sharpRatio, ...
    cvA, cvK2, looA, looK2)
% Heuristic gates — documented in report (binary YES/NO)
ixIp = find(strcmp(fnames, 'I_peak'), 1);
ixW = find(strcmp(fnames, 'width_mA'), 1);
ixT = find(strcmp(fnames, 'T_K'), 1);
rIp = abs(corrPear(ixIp));
rW = abs(corrPear(ixW));
rT = abs(corrPear(ixT));
rGeom = max(rIp, rW);
mt = ~strcmp(fnames, 'T_K');
maxObsCorr = max(abs(corrPear(mt)), [], 'omitnan');
stableEnough = ~(isfinite(cvA) && isfinite(cvK2) && cvA > cvK2 * 3 && isfinite(looA) && isfinite(looK2) && looA > looK2 * 2.5);
physical = stableEnough && ((isfinite(maxObsCorr) && maxObsCorr > 0.32) || rT > 0.42);
geometry = rGeom > 0.28;
regime = sharpFlag || (isfinite(sharpRatio) && sharpRatio > 2.2);

v = struct();
v.ALPHA_IS_PHYSICAL_COORDINATE = "NO";
if physical
    v.ALPHA_IS_PHYSICAL_COORDINATE = "YES";
end
v.ALPHA_LINKED_TO_GEOMETRY = "NO";
if geometry
    v.ALPHA_LINKED_TO_GEOMETRY = "YES";
end
v.ALPHA_EXPLAINS_REGIME_CHANGE = "NO";
if regime
    v.ALPHA_EXPLAINS_REGIME_CHANGE = "YES";
end
end

function r = localAbsCorr(corrPear, ix)
if isempty(ix)
    r = NaN;
else
    r = abs(corrPear(ix));
end
end

function writeReport19f(path, verdict, decCfg, fnames, corrPear, corrSpear, ...
    sharpRatio, maxBand, sb, sm, sa, cvA, cvK2, looA, looK2, alphaMoreSens)
fid = fopen(path, 'w');
assert(fid > 0, 'Cannot write report');
fprintf(fid, '# Deformation ratio structure (Agent 19F)\n\n');
fprintf(fid, '## Definition\n');
fprintf(fid, '- **alpha(T)** = `kappa2 / kappa1`, with `kappa1` = rank-1 amplitude (`kappaAll`), ');
fprintf(fid, '`kappa2` = coefficient on **Phi2** in the per-temperature rank-2 fit to the residual strip.\n');
fprintf(fid, '- Same pipeline as Agent 19E (`switching_residual_decomposition_analysis`).\n\n');

fprintf(fid, '## Sources\n');
fprintf(fid, '- Alignment: `%s`\n', decCfg.alignmentRunId);
fprintf(fid, '- Full scaling: `%s`\n', decCfg.fullScalingRunId);
fprintf(fid, '- PT run: `%s`\n\n', decCfg.ptRunId);

fprintf(fid, '## 1. Correlations with alpha\n');
fprintf(fid, '| Variable | Pearson | Spearman |\n| --- | --- | --- |\n');
for i = 1:numel(fnames)
    fprintf(fid, '| %s | %.4f | %.4f |\n', fnames{i}, corrPear(i), corrSpear(i));
end
fprintf(fid, '\n');

fprintf(fid, '## 2. Regime / 22–24 K\n');
fprintf(fid, '- max |d alpha / dT| in 21.5–24.5 K / median |d alpha / dT| elsewhere: **%.3f** (sharp if > 2.5)\n', sharpRatio);
fprintf(fid, '- max |d alpha / dT| in band (raw discrete): **%.6g**\n', maxBand);
fprintf(fid, '- Slopes (discrete, sorted T): before 22K **%.6g**, 22→24 **%.6g**, after 24K **%.6g**\n\n', sb, sm, sa);

fprintf(fid, '## 3. Stability\n');
fprintf(fid, '- Monte Carlo: 1%% multiplicative noise on kappa1,kappa2 (valid T); relative std of batch-mean **alpha**: **%.4f**; of batch-mean **kappa2**: **%.4f**\n', cvA, cvK2);
fprintf(fid, '- LOO at 22K: std(kappa2): **%.6g**; std(alpha) using kappa2_LOO / kappa1(22K full): **%.6g**\n', looK2, looA);
fprintf(fid, '- Alpha more MC-sensitive than kappa2: **%d** (1=yes)\n\n', alphaMoreSens);

fprintf(fid, '## 4. Artifacts\n');
fprintf(fid, '- Per-temperature table: `tables/alpha_structure.csv`\n');
fprintf(fid, '- Figure: `figures/alpha_vs_T.png`\n\n');

fprintf(fid, '## Final verdict\n\n');
fprintf(fid, '- **ALPHA_IS_PHYSICAL_COORDINATE**: %s\n', verdict.ALPHA_IS_PHYSICAL_COORDINATE);
fprintf(fid, '- **ALPHA_LINKED_TO_GEOMETRY**: %s\n', verdict.ALPHA_LINKED_TO_GEOMETRY);
fprintf(fid, '- **ALPHA_EXPLAINS_REGIME_CHANGE**: %s\n\n', verdict.ALPHA_EXPLAINS_REGIME_CHANGE);

fprintf(fid, '### Notes\n');
fprintf(fid, 'Ratios amplify relative noise when |kappa1| is small; interpret MC and LOO ');
fprintf(fid, 'stability together with correlation structure.\n');
fclose(fid);
end
