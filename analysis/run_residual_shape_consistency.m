function out = run_residual_shape_consistency()
%RUN_RESIDUAL_SHAPE_CONSISTENCY  Agent B — compare Phi2 (switching) vs alpha_res-implied x-shape
%
% Spatial model (same as Agent 23C header):
%   R(x,T) ~ kappa1(T) * ( Phi1(x) + (alpha_geom(T)+alpha_res(T)) * Phi2(x) ).
% The x-profile associated with alpha_res is Phi2; an empirical estimate is
%   ( R - kappa1*(Phi1 + alpha_geom*Phi2) ) / (kappa1*alpha_res)
% on rows with finite PT geometry and non-degenerate scale.
%
% Writes (repo root):
%   tables/residual_shape_comparison.csv
%   reports/residual_shape_consistency_report.md

set(0, 'DefaultFigureVisible', 'off');

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'analysis'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

outRoot = repoRoot;
tblDir = fullfile(outRoot, 'tables');
repDir = fullfile(outRoot, 'reports');
for d = {tblDir, repDir}
    if exist(d{1}, 'dir') ~= 7
        mkdir(d{1});
    end
end

decCfg = struct();
decCfg.runLabel = 'residual_shape_consistency_internal';
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
k1 = double(dec.kappaAll(:));
xGrid = double(dec.xGrid(:));

if isempty(phi2) || all(~isfinite(phi2))
    error('run_residual_shape_consistency:Phi2Missing', 'Mode-2 phi required.');
end

alphaDecPath = fullfile(repoRoot, 'tables', 'alpha_decomposition.csv');
assert(exist(alphaDecPath, 'file') == 2, 'Missing %s', alphaDecPath);
aDec = readtable(alphaDecPath, 'VariableNamingRule', 'preserve');

T_Kd = double(aDec.T_K(:));
ag = double(aDec.alpha_geom(:));
ar = double(aDec.alpha_res(:));
ptOk = logical(aDec.PT_geometry_valid(:));

matchDec = zeros(numel(T_Kd), 1);
for k = 1:numel(T_Kd)
    j = find(abs(tempsDec - T_Kd(k)) < 1e-6, 1, 'first');
    if ~isempty(j)
        matchDec(k) = j;
    end
end

% --- Build per-row scaled residual strip (alpha_res channel) ---
nX = numel(xGrid);
phi1r = phi1(:).';
phi2r = phi2(:).';
U = NaN(0, nX);
rowT = [];
for i = 1:numel(T_Kd)
    if ~ptOk(i) || ~isfinite(ag(i)) || ~isfinite(ar(i))
        continue
    end
    ti = matchDec(i);
    if ti < 1 || ti > size(Rall, 1)
        continue
    end
    kk = k1(ti);
    if ~isfinite(kk) || abs(kk) < 1e-14
        continue
    end
    den = kk * ar(i);
    if abs(den) < 1e-14 * max(abs(k1), [], 'omitnan')
        continue
    end
    rrow = Rall(ti, :);
    if ~all(isfinite(rrow))
        continue
    end
    rhatG = kk .* (phi1r + ag(i) .* phi2r);
    v = rrow - rhatG;
    U(end + 1, :) = v ./ den; %#ok<AGROW>
    rowT(end + 1, 1) = T_Kd(i); %#ok<AGROW>
end

if size(U, 1) < 3
    error('run_residual_shape_consistency:TooFewRows', 'Need >= 3 valid rows for aggregation.');
end

% Sign-correct each row toward Phi2 (SVD ref), then mean
phi2Ref = localZmuL2(phi2);
agg = zeros(1, nX);
for r = 1:size(U, 1)
    w = localZmuL2(U(r, :).');
    if all(~isfinite(w))
        continue
    end
    sgn = sign(dot(phi2Ref, w));
    if sgn == 0
        sgn = 1;
    end
    agg = agg + sgn * U(r, :);
end
phiAging = (agg / size(U, 1)).';

% Normalized curves for cosine / projection
p2 = localZmuL2(phi2);
pa = localZmuL2(phiAging);
cosSim = localCos(p2, pa);
projCoeff = dot(p2, pa);
projErr = norm(p2 - projCoeff * pa); % both unit -> sqrt(1 - c^2) if aligned

% --- Symmetry & localization (same constructions as phi2 physics test) ---
sigmaG = 0.22;
locRad = 1.0;
locTight = 0.5;
tailRx = 0.35;

[m2_even, ~] = localEvenFrac(xGrid, p2);
[m2_odd, ~] = localOddFrac(xGrid, p2);
[mA_even, ~] = localEvenFrac(xGrid, pa);
[mA_odd, ~] = localOddFrac(xGrid, pa);

[ce2, ct2, rx2] = localLocalize(xGrid, p2, locRad, locTight);
[ceA, ctA, rxA] = localLocalize(xGrid, pa, locRad, locTight);

dPhi1 = gradient(phi1(:), xGrid(:));
kernNames = {'dPhi1_dx', 'gaussian_bump', 'x_times_Phi1'};
kernels = {
    localZmuL2(dPhi1)
    localZmuL2(exp(-0.5 * (xGrid ./ sigmaG) .^ 2))
    localZmuL2(xGrid .* phi1(:))
    };

best2 = localBestKernel(p2, kernels, kernNames);
bestA = localBestKernel(pa, kernels, kernNames);

% Full rank-2 residual (sanity): R - k1*(phi1 + alpha*phi2), alpha = ag+ar
alphaFull = ag + ar;
Vfull = NaN(0, nX);
for i = 1:numel(T_Kd)
    if ~ptOk(i) || ~isfinite(alphaFull(i))
        continue
    end
    ti = matchDec(i);
    if ti < 1 || ti > size(Rall, 1)
        continue
    end
    kk = k1(ti);
    if ~isfinite(kk)
        continue
    end
    rrow = Rall(ti, :);
    if ~all(isfinite(rrow))
        continue
    end
    rhat = kk .* (phi1r + alphaFull(i) .* phi2r);
    Vfull(end + 1, :) = rrow - rhat; %#ok<AGROW>
end
phiRank3Mean = localZmuL2(mean(Vfull, 1, 'omitnan').');
cosRank3toPhi2 = localCos(p2, phiRank3Mean);

% --- CSV: single summary row + per-kernel correlations as wide columns ---
r2 = NaN(numel(kernels), 1);
rA = r2;
for ki = 1:numel(kernels)
    r2(ki) = localCorr(p2, kernels{ki});
    rA(ki) = localCorr(pa, kernels{ki});
end

summaryRow = table( ...
    size(aDec, 1), numel(rowT), cosSim, projErr, projCoeff, ...
    m2_even, m2_odd, mA_even, mA_odd, ...
    ce2, ct2, rx2, ceA, ctA, rxA, ...
    string(best2.name), best2.corr, string(bestA.name), bestA.corr, ...
    cosRank3toPhi2, ...
    'VariableNames', { ...
    'n_alpha_decomposition_rows', 'n_rows_aggregated_scaled_residual', ...
    'cosine_phi2_vs_alpha_res_shape', 'projection_l2_error_unit_vectors', 'projection_coeff_on_aging_shape', ...
    'phi2_even_energy_frac', 'phi2_odd_energy_frac', ...
    'aging_res_shape_even_energy_frac', 'aging_res_shape_odd_energy_frac', ...
    'phi2_center_energy_frac_wide', 'phi2_center_energy_frac_tight', 'phi2_rms_x_weighted', ...
    'aging_res_center_energy_frac_wide', 'aging_res_center_energy_frac_tight', 'aging_res_rms_x_weighted', ...
    'phi2_best_kernel', 'phi2_best_kernel_corr', ...
    'aging_res_best_kernel', 'aging_res_best_kernel_corr', ...
    'cosine_phi2_vs_mean_rank3plus_residual'});

for ki = 1:numel(kernels)
    cn = matlab.lang.makeValidName(['kern_pearson_phi2_' kernNames{ki}]);
    summaryRow.(cn) = r2(ki);
    cnA = matlab.lang.makeValidName(['kern_pearson_aging_' kernNames{ki}]);
    summaryRow.(cnA) = rA(ki);
end

cmpPath = fullfile(tblDir, 'residual_shape_comparison.csv');
writetable(summaryRow, cmpPath);
fprintf('Saved: %s\n', cmpPath);

% --- Verdict ---
absCos = abs(cosSim);
evenDiff = abs(m2_even - mA_even);
kernelAgree = strcmpi(strtrim(best2.name), strtrim(bestA.name)) || ...
    (abs(best2.corr - bestA.corr) < 0.12 && abs(best2.corr) > 0.5 && abs(bestA.corr) > 0.5);
locAgree = abs(ct2 - ctA) < 0.12 || abs(rx2 - rxA) < 0.08;

if absCos >= 0.92 && evenDiff <= 0.12 && (locAgree || kernelAgree)
    verdict = "YES";
    verdictDetail = "High cosine, symmetry and localization/kernel broadly agree.";
elseif absCos >= 0.78 || (absCos >= 0.65 && (evenDiff <= 0.18 || kernelAgree))
    verdict = "PARTIAL";
    verdictDetail = "Meaningful alignment but not tight on all structural checks.";
else
    verdict = "NO";
    verdictDetail = "Low shape agreement between SVD Phi2 and alpha_res-scaled residual.";
end

lines = strings(0, 1);
lines(end+1) = "# Residual shape consistency (switching Phi2 vs alpha_res channel)";
lines(end+1) = "";
lines(end+1) = "## Definitions";
lines(end+1) = "- **Phi2**: second shape mode from low-T SVD on switching residual strips `R(x,T)` (same pipeline as `switching_residual_decomposition_analysis`).";
lines(end+1) = "- **Aging residual x-shape (alpha_res channel)**: row-wise `(R - kappa1*(Phi1 + alpha_geom*Phi2)) / (kappa1*alpha_res)` from `tables/alpha_decomposition.csv`, rows with `PT_geometry_valid==1` and non-degenerate scale; each row sign-flipped to align with Phi2, then averaged.";
lines(end+1) = "- **Normalization for metrics**: zero-mean, unit L2 on the common x-grid (finite samples only).";
lines(end+1) = "";
lines(end+1) = "## Similarity";
lines(end+1) = sprintf("- **Cosine(Phi2, aging alpha_res shape):** %.4f", cosSim);
lines(end+1) = sprintf("- **Projection coefficient** (Phi2 on aging shape): %.4f", projCoeff);
lines(end+1) = sprintf("- **L2 projection error** (unit vectors): %.4f (`sqrt(1-c^2)` when signs aligned)", projErr);
lines(end+1) = sprintf("- **Cosine(Phi2, mean rank-3+ residual)** after full rank-2 fit `kappa1*(Phi1+alpha*Phi2)`: %.4f (sanity — should be small)", cosRank3toPhi2);
lines(end+1) = "";
lines(end+1) = "## Symmetry";
lines(end+1) = sprintf("| mode | even energy frac | odd energy frac |");
lines(end+1) = sprintf("|------|------------------|-----------------|");
lines(end+1) = sprintf("| Phi2 | %.4f | %.4f |", m2_even, m2_odd);
lines(end+1) = sprintf("| alpha_res shape | %.4f | %.4f |", mA_even, mA_odd);
lines(end+1) = "";
lines(end+1) = "## Localization (|x| energy fractions, Phi^2-weighted RMS |x|)";
lines(end+1) = sprintf("- **Phi2:** center frac |x|≤%.2f: %.4f; tight |x|≤%.2f: %.4f; RMS|x|: %.4f", locRad, ce2, locTight, ct2, rx2);
lines(end+1) = sprintf("- **alpha_res shape:** center frac |x|≤%.2f: %.4f; tight |x|≤%.2f: %.4f; RMS|x|: %.4f", locRad, ceA, locTight, ctA, rxA);
lines(end+1) = "";
lines(end+1) = "## Kernel correlations (Pearson vs zero-mean unit L2 curves)";
for ki = 1:numel(kernNames)
    lines(end+1) = sprintf("- `%s`: Phi2 r=%.4f; alpha_res shape r=%.4f", ...
        kernNames{ki}, r2(ki), rA(ki));
end
lines(end+1) = "";
lines(end+1) = "## Data";
lines(end+1) = sprintf("- Rows used in aggregation: **%d** (of %d decomposition temperatures).", numel(rowT), numel(tempsDec));
lines(end+1) = "- Kernel correlations are wide columns in `tables/residual_shape_comparison.csv`.";
lines(end+1) = "";
lines(end+1) = "## Final";
lines(end+1) = "**RESIDUAL_SHAPE_SHARED:** " + verdict;
lines(end+1) = "";
lines(end+1) = verdictDetail;
lines(end+1) = "";
lines(end+1) = "*Auto-generated by `analysis/run_residual_shape_consistency.m`.*";

repPath = fullfile(repDir, 'residual_shape_consistency_report.md');
fid = fopen(repPath, 'w');
if fid < 0
    error('Could not write %s', repPath);
end
fprintf(fid, '%s', strjoin(lines, newline));
fclose(fid);
fprintf('Saved: %s\n', repPath);

out = struct();
out.tablePath = string(cmpPath);
out.reportPath = string(repPath);
out.cosine = cosSim;
out.verdict = verdict;
end

%% --- locals ---
function y = localZmuL2(y)
y = y(:);
m = isfinite(y);
if nnz(m) < 5
    y(:) = NaN;
    return
end
w = y(m) - mean(y(m), 'omitnan');
nrm = norm(w);
if ~(isfinite(nrm) && nrm > eps)
    y(:) = NaN;
    return
end
y(:) = 0;
y(m) = w ./ nrm;
end

function c = localCos(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    c = NaN;
    return
end
p = a(m);
q = b(m);
c = dot(p, q) / (norm(p) * norm(q) + eps);
end

function c = localCorr(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    c = NaN;
    return
end
c = corr(a(m), b(m));
end

function [evenFrac, evenVec] = localEvenFrac(xg, phi)
p = phi(:);
xn = xg(:);
pneg = interp1(xn, p, -xn, 'linear', NaN);
m = isfinite(p) & isfinite(pneg);
evenVec = NaN(size(p));
evenVec(m) = 0.5 * (p(m) + pneg(m));
evenFrac = sum(evenVec(m) .^ 2, 'omitnan') / sum(p(m) .^ 2, 'omitnan');
end

function [oddFrac, oddVec] = localOddFrac(xg, phi)
p = phi(:);
xn = xg(:);
pneg = interp1(xn, p, -xn, 'linear', NaN);
m = isfinite(p) & isfinite(pneg);
oddVec = NaN(size(p));
oddVec(m) = 0.5 * (p(m) - pneg(m));
oddFrac = sum(oddVec(m) .^ 2, 'omitnan') / sum(p(m) .^ 2, 'omitnan');
end

function [centerWide, centerTight, rmsX] = localLocalize(xGrid, phi, rw, rt)
p = phi(:);
xg = xGrid(:);
m = isfinite(p);
eTot = sum(p(m) .^ 2, 'omitnan');
centerWide = sum((p(abs(xg) <= rw & m)).^2, 'omitnan') / max(eTot, eps);
centerTight = sum((p(abs(xg) <= rt & m)).^2, 'omitnan') / max(eTot, eps);
sx2 = sum((xg.^2) .* (p.^2), 'omitnan') / max(eTot, eps);
rmsX = sqrt(max(sx2, 0));
end

function best = localBestKernel(phiN, kernels, names)
best = struct('name', '', 'corr', NaN);
cc = NaN(numel(kernels), 1);
for j = 1:numel(kernels)
    cc(j) = abs(localCorr(phiN, kernels{j}));
end
[~, jm] = max(cc, [], 'omitnan');
if isempty(jm) || ~isfinite(cc(jm))
    return
end
best.name = names{jm};
best.corr = localCorr(phiN, kernels{jm});
end
