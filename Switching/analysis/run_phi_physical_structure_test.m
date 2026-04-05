function out = run_phi_physical_structure_test(cfg)
% run_phi_physical_structure_test
% Compare empirical Phi(x) from switching residual decomposition to PT-derived
% physical kernels (curvature of CDF, PDF Laplacian, Gaussian bump, PT-PCA modes).
% Writes tables, figures, and report under a new switching run folder.

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

runDataset = sprintf('phi_physical_structure | decomp_ref:%s', cfg.canonicalDecompositionRunId);
run = createSwitchingRunContext(repoRoot, struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

fprintf('Phi physical structure test run directory:\n%s\n', runDir);

decCfg = struct();
decCfg.run = run;
decCfg.alignmentRunId = cfg.alignmentRunId;
decCfg.fullScalingRunId = cfg.fullScalingRunId;
decCfg.ptRunId = cfg.ptRunId;
decCfg.canonicalMaxTemperatureK = cfg.canonicalMaxTemperatureK;
decCfg.nXGrid = cfg.nXGrid;
decCfg.fallbackSmoothWindow = cfg.fallbackSmoothWindow;

outDec = switching_residual_decomposition_analysis(decCfg);

xGrid = outDec.xGrid(:);
phiEmp = outDec.phi(:);
Rall = outDec.Rall;
temps = outDec.temperaturesK(:);
lowMask = outDec.lowTemperatureMask(:);
kappaEmp = outDec.kappaAll(:);
currents = outDec.currents_mA(:);
Ipeak = outDec.Ipeak_mA(:);
width = outDec.width_mA(:);

slice = localAlignmentSlice(repoRoot, decCfg);
ptData = slice.ptData;
assert(ptData.available, 'PT matrix required for physical kernel test.');

kernelNames = {
    'cdf_curvature_d2dI2'
    'pt_pdf_laplacian_d2dI2'
    'symmetric_gaussian_bump_x'
    'pt_pca_mode_1'
    'pt_pca_mode_2'
    'pt_pca_mode_3'
    };

stabilityCases = {
    'canonical_T_le_30K'
    'lowT_T_le_20K'
    'canonical_exclude_22K'
    };

masks = {
    lowMask & (temps <= cfg.canonicalMaxTemperatureK)
    lowMask & (temps <= 20)
    lowMask & (abs(temps - 22) > 0.5)
    };

% --- Build raw kernel surfaces (per-T rows), then aggregate + normalize per case ---
corrRows = [];
reconRows = [];

for si = 1:numel(stabilityCases)
    caseName = stabilityCases{si};
    mT = masks{si};
    mT = mT(:) & isfinite(mT);
    assert(nnz(mT) >= 3, 'Stability mask %s has too few rows.', caseName);

    Kraw = localBuildKernelRows(ptData, currents, Ipeak, width, xGrid, temps, mT, cfg.gaussianSigmaX);

    nK = numel(kernelNames);
    psiMat = NaN(numel(xGrid), nK);
    for j = 1:nK
        psiMat(:, j) = localMedianAggregate(Kraw{j}, mT);
        psiMat(:, j) = localZeroMeanUnitL2(psiMat(:, j));
    end

    phiN = localZeroMeanUnitL2(phiEmp);
    [phiEvenFrac, phiEvenVec] = localEvenPart(xGrid, phiEmp);

    for j = 1:nK
        psi = psiMat(:, j);
        r = localSafeCorr(phiN, psi);
        c = localCosineSim(phiN, psi);
        [keFrac, keVec] = localEvenPart(xGrid, psi);
        rEven = localSafeCorr(phiEvenVec, keVec);
        corrRows = [corrRows; {caseName, kernelNames{j}, r, c, rEven, phiEvenFrac, keFrac}]; %#ok<AGROW>
    end

    q0 = localEvalRmse(Rall, kappaEmp, phiEmp, mT);
    [pairIdx, rat2] = localGlobalBestPairRmse(Rall, psiMat, mT, q0.rmse);
    nm2 = strjoin(kernelNames(pairIdx), '+');
    for j = 1:nK
        aj = localFitKappaRows(Rall, psiMat(:, j));
        qj = localEvalRmse(Rall, aj, psiMat(:, j), mT);
        rat1 = qj.rmse / max(q0.rmse, eps);
        reconRows = [reconRows; {caseName, kernelNames{j}, q0.rmse, qj.rmse, rat1, nm2, rat2}]; %#ok<AGROW>
    end
end

% Fix best index for primary figure (canonical block first nK rows)
corrMat = cell2table(corrRows, 'VariableNames', ...
    {'stability_case', 'kernel_name', 'pearson_r', 'cosine_similarity', ...
    'corr_even_parts', 'phi_even_energy_fraction', 'kernel_even_energy_fraction'});
save_run_table(corrMat, 'phi_physical_kernel_correlations.csv', runDir);

reconTbl = cell2table(reconRows, 'VariableNames', ...
    {'stability_case', 'kernel_name', 'rmse_baseline_kappa_phi', 'rmse_single_kernel', ...
    'rmse_ratio_single', 'best_pair_kernels', 'rmse_ratio_best_pair'});
save_run_table(reconTbl, 'phi_kernel_reconstruction_metrics.csv', runDir);

% Primary figures from canonical case
mCanon = masks{1};
Kraw1 = localBuildKernelRows(ptData, currents, Ipeak, width, xGrid, temps, mCanon, cfg.gaussianSigmaX);
psiCanon = NaN(numel(xGrid), numel(kernelNames));
for j = 1:numel(kernelNames)
    psiCanon(:, j) = localZeroMeanUnitL2(localMedianAggregate(Kraw1{j}, mCanon));
end
phiN = localZeroMeanUnitL2(phiEmp);
figPhi = localFigPhiVsKernels(xGrid, phiN, psiCanon, kernelNames, runDir);

[~, jb] = max(abs(localCorrColumns(phiN, psiCanon)));
psiBest = psiCanon(:, jb);
aBest = localFitKappaRows(Rall, psiBest);
figRecon = localFigReconstructionComparison(temps, xGrid, Rall, mCanon, phiEmp, kappaEmp, ...
    psiBest, aBest, kernelNames{jb}, runDir);

% Summary for report
canonCorr = corrMat(strcmp(corrMat.stability_case, 'canonical_T_le_30K'), :);
[~, ix] = max(abs(canonCorr.pearson_r));
bestName = canonCorr.kernel_name{ix};
bestR = canonCorr.pearson_r(ix);
reconCanon = reconTbl(strcmp(reconTbl.stability_case, 'canonical_T_le_30K'), :);
bestRat = min(reconCanon.rmse_ratio_single, [], 'omitnan');
bestRatPair = reconCanon.rmse_ratio_best_pair(1);
verdict = localVerdict(bestR, bestRat, bestRatPair);

reportLines = strings(0, 1);
reportLines(end+1) = "# Phi physical structure test";
reportLines(end+1) = "";
reportLines(end+1) = "## Reference decomposition";
reportLines(end+1) = "- Canonical run id: `" + string(cfg.canonicalDecompositionRunId) + "`.";
reportLines(end+1) = "- Replay / output run: `" + string(runDir) + "`.";
reportLines(end+1) = "";
reportLines(end+1) = "## Kernels";
reportLines(end+1) = "1. **cdf_curvature_d2dI2** — second derivative of CDF(P_T) w.r.t. I (movmean(3) pre-smooth), interpolated to x=(I-I_peak)/w per T, median over stability rows.";
reportLines(end+1) = "2. **pt_pdf_laplacian_d2dI2** — second derivative of normalized PT PDF on I, mapped to x, median aggregate.";
reportLines(end+1) = "3. **symmetric_gaussian_bump_x** — exp(-0.5*(x/σ)^2) on x with σ = " + sprintf('%.3g', cfg.gaussianSigmaX) + " (dimensionless x).";
reportLines(end+1) = "4. **pt_pca_mode_{1..3}** — PCA across temperatures (rows) of per-T PDF vectors on the alignment current grid; modes evaluated along I_peak(T)+x w(T), median over rows.";
reportLines(end+1) = "";
reportLines(end+1) = "## Normalization";
reportLines(end+1) = "- All kernels and Phi use **zero mean + unit L2** on the shared x-grid for correlation and cosine.";
reportLines(end+1) = "";
reportLines(end+1) = "## Stability subsets";
reportLines(end+1) = "- `canonical_T_le_30K`: T ≤ 30 K (decomposition low window).";
reportLines(end+1) = "- `lowT_T_le_20K`: T ≤ 20 K.";
reportLines(end+1) = "- `canonical_exclude_22K`: T ≤ 30 K excluding T≈22 K.";
reportLines(end+1) = "";
reportLines(end+1) = "## Correlations (table excerpt)";
reportLines(end+1) = localTableToMarkdown(corrMat);
reportLines(end+1) = "";
reportLines(end+1) = "## Reconstruction (table excerpt)";
reportLines(end+1) = localTableToMarkdown(reconTbl);
reportLines(end+1) = "";
reportLines(end+1) = "## Verdict";
reportLines(end+1) = "- Best |Pearson| kernel (canonical window): **" + string(bestName) + "** (r = " + sprintf('%.4f', bestR) + ").";
reportLines(end+1) = "- Best single-kernel RMSE ratio: **" + sprintf('%.4f', bestRat) + "**; best pair ratio: **" + sprintf('%.4f', bestRatPair) + "**.";
reportLines(end+1) = "- **" + string(verdict) + "**";
reportLines(end+1) = "";
reportLines(end+1) = "## Artifacts";
reportLines(end+1) = "- `tables/phi_physical_kernel_correlations.csv`";
reportLines(end+1) = "- `tables/phi_kernel_reconstruction_metrics.csv`";
reportLines(end+1) = "- `figures/phi_vs_physical_kernels.*`";
reportLines(end+1) = "- `figures/reconstruction_comparison.*`";

reportPath = save_run_report(strjoin(reportLines, newline), 'phi_physical_structure_report.md', runDir);

zipPath = localBuildReviewZip(runDir, 'phi_physical_structure_bundle.zip');

appendText(run.log_path, sprintf('Best kernel (canonical): %s\n', char(bestName)));
appendText(run.log_path, sprintf('Verdict: %s\n', char(verdict)));

out = struct();
out.runDir = string(runDir);
out.correlationTable = corrMat;
out.reconstructionTable = reconTbl;
out.bestKernelCanonical = string(bestName);
out.bestPearsonCanonical = bestR;
out.bestRmseRatioSingle = bestRat;
out.bestRmseRatioPair = bestRatPair;
out.verdict = string(verdict);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.figureKernels = figPhi;
out.figureRecon = figRecon;

fprintf('\n=== Phi physical structure test complete ===\n');
fprintf('Verdict: %s\n', verdict);
fprintf('Report: %s\n', reportPath);
end

%% -------------------------------------------------------------------------
function cfg = applyDefaults(cfg)
cfg = localSetDef(cfg, 'runLabel', 'phi_physical_structure_test');
cfg = localSetDef(cfg, 'canonicalDecompositionRunId', 'run_2026_03_24_220314_residual_decomposition');
cfg = localSetDef(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = localSetDef(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = localSetDef(cfg, 'ptRunId', 'run_2026_03_24_212033_switching_barrier_distribution_from_map');
cfg = localSetDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = localSetDef(cfg, 'nXGrid', 220);
cfg = localSetDef(cfg, 'fallbackSmoothWindow', 5);
cfg = localSetDef(cfg, 'gaussianSigmaX', 0.22);
end

function cfg = localSetDef(cfg, name, val)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = val;
end
end

function Kcell = localBuildKernelRows(ptData, currents, Ipeak, width, xGrid, temps, rowMask, sigmaX)
nT = numel(temps);
nx = numel(xGrid);
K_curv = NaN(nT, nx);
K_lap = NaN(nT, nx);
K_bump = NaN(nT, nx);
for it = 1:nT
    if ~rowMask(it)
        continue
    end
    cdfRow = localCdfFromPT(ptData, temps(it), currents);
    pRow = localPdfFromPT(ptData, temps(it), currents);
    if isempty(cdfRow) || isempty(pRow)
        continue
    end
    d2c = localSecondDerivSmooth(cdfRow(:), currents(:));
    d2p = localSecondDerivSmooth(pRow(:), currents(:));
    Ix = Ipeak(it) + xGrid(:)' .* width(it);
    for k = 1:nx
        K_curv(it, k) = interp1(currents(:), d2c(:), Ix(k), 'linear', NaN);
        K_lap(it, k) = interp1(currents(:), d2p(:), Ix(k), 'linear', NaN);
    end
    K_bump(it, :) = exp(-0.5 * (xGrid(:)' ./ sigmaX) .^ 2);
end

% PT PCA on PDF rows (masked temperatures)
idx = find(rowMask(:)');
pdfStack = NaN(numel(idx), numel(currents));
for ii = 1:numel(idx)
    it = idx(ii);
    pRow = localPdfFromPT(ptData, temps(it), currents);
    if ~isempty(pRow)
        pdfStack(ii, :) = pRow(:)';
    end
end
Vmodes = localPcaModes(pdfStack, 3);
K_pca = cell(1, 3);
for j = 1:3
    K_pca{j} = NaN(nT, nx);
end
for it = 1:nT
    if ~rowMask(it)
        continue
    end
    Ix = Ipeak(it) + xGrid(:)' .* width(it);
    for j = 1:3
        vj = Vmodes(:, j);
        for k = 1:nx
            K_pca{j}(it, k) = interp1(currents(:), vj(:), Ix(k), 'linear', NaN);
        end
    end
end

Kcell = [{K_curv}, {K_lap}, {K_bump}, K_pca{:}];
end

function V = localPcaModes(X, nModes)
[nr, nc] = size(X);
V = zeros(nc, nModes);
if nr < 2 || nc < 2
    return
end
colM = mean(X, 1, 'omitnan');
Xc = X - colM;
Xc(~isfinite(Xc)) = 0;
try
    [~, ~, Vfull] = svd(Xc, 'econ');
catch
    return
end
k = min(nModes, size(Vfull, 2));
V(:, 1:k) = Vfull(:, 1:k);
end

function v = localMedianAggregate(M, rowMask)
rows = find(rowMask(:)');
if isempty(rows)
    v = NaN(1, size(M, 2));
    return
end
v = median(M(rows, :), 1, 'omitnan');
v = v(:);
end

function y = localZeroMeanUnitL2(y)
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

function d2 = localSecondDerivSmooth(y, x)
y = y(:);
x = x(:);
d2 = NaN(size(y));
if numel(y) < 5
    return
end
ys = movmean(y, 3, 'omitnan');
d1 = gradient(ys, x);
d2 = gradient(d1, x);
end

function cdfRow = localCdfFromPT(ptData, targetT, currents)
tempsPT = ptData.temps(:);
currPT = ptData.currents(:);
PT = ptData.PT;
if numel(tempsPT) < 2 || size(PT, 2) ~= numel(currPT)
    cdfRow = [];
    return
end
pAtT = NaN(numel(currPT), 1);
for j = 1:numel(currPT)
    col = PT(:, j);
    mk = isfinite(tempsPT) & isfinite(col);
    if nnz(mk) < 2
        continue
    end
    pAtT(j) = interp1(tempsPT(mk), col(mk), targetT, 'linear', NaN);
end
if all(~isfinite(pAtT))
    cdfRow = [];
    return
end
pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);
areaPT = trapz(currPT, pAtT);
if ~(isfinite(areaPT) && areaPT > 0)
    cdfRow = [];
    return
end
pAtT = pAtT ./ areaPT;
pOnCurrents = interp1(currPT, pAtT, currents(:), 'linear', 0);
pOnCurrents = max(pOnCurrents, 0);
area = trapz(currents, pOnCurrents);
if ~(isfinite(area) && area > 0)
    cdfRow = [];
    return
end
pOnCurrents = pOnCurrents ./ area;
cdfRow = cumtrapz(currents, pOnCurrents);
if cdfRow(end) <= 0
    cdfRow = [];
    return
end
cdfRow = cdfRow ./ cdfRow(end);
cdfRow = min(max(cdfRow, 0), 1);
cdfRow = cdfRow(:)';
end

function pRow = localPdfFromPT(ptData, targetT, currents)
cdfCheck = localCdfFromPT(ptData, targetT, currents);
if isempty(cdfCheck)
    pRow = [];
    return
end
tempsPT = ptData.temps(:);
currPT = ptData.currents(:);
PT = ptData.PT;
pAtT = NaN(numel(currPT), 1);
for j = 1:numel(currPT)
    col = PT(:, j);
    mk = isfinite(tempsPT) & isfinite(col);
    if nnz(mk) < 2
        continue
    end
    pAtT(j) = interp1(tempsPT(mk), col(mk), targetT, 'linear', NaN);
end
pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);
areaPT = trapz(currPT, pAtT);
if ~(isfinite(areaPT) && areaPT > 0)
    pRow = [];
    return
end
pAtT = pAtT ./ areaPT;
pOnCurrents = interp1(currPT, pAtT, currents(:), 'linear', 0);
pOnCurrents = max(pOnCurrents, 0);
area = trapz(currents, pOnCurrents);
if ~(isfinite(area) && area > 0)
    pRow = [];
    return
end
pRow = (pOnCurrents ./ area)';
end

function c = localSafeCorr(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    c = NaN;
    return
end
c = corr(a(m), b(m));
end

function c = localCosineSim(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    c = NaN;
    return
end
p = a(m);
q = b(m);
c = dot(p, q) / (norm(p) * norm(q) + eps);
end

function [evenFrac, evenVec] = localEvenPart(xg, phi)
p = phi(:);
xn = xg(:);
pneg = interp1(xn, p, -xn, 'linear', NaN);
m = isfinite(p) & isfinite(pneg);
evenVec = NaN(size(p));
evenVec(m) = 0.5 * (p(m) + pneg(m));
evenFrac = sum(evenVec(m) .^ 2, 'omitnan') / sum(p(m) .^ 2, 'omitnan');
end

function q = localEvalRmse(R, kappa, phi, rowMask)
rows = find(rowMask(:)');
se = [];
for ii = 1:numel(rows)
    it = rows(ii);
    r = R(it, :)';
    ph = phi(:);
    m = isfinite(r) & isfinite(ph);
    if nnz(m) < 3
        continue
    end
    pred = kappa(it) * ph(m);
    se = [se; (r(m) - pred) .^ 2]; %#ok<AGROW>
end
if isempty(se)
    q = struct('rmse', NaN);
    return
end
q.rmse = sqrt(mean(se, 'omitnan'));
end

function k = localFitKappaRows(R, phi)
n = size(R, 1);
k = NaN(n, 1);
ph = phi(:);
for i = 1:n
    r = R(i, :)';
    m = isfinite(r) & isfinite(ph);
    if nnz(m) < 3
        continue
    end
    den = sum(ph(m) .^ 2, 'omitnan');
    if den <= eps
        continue
    end
    k(i) = sum(r(m) .* ph(m), 'omitnan') / den;
end
end

function [pairIdx, rat] = localGlobalBestPairRmse(R, psiMat, rowMask, rmse0)
nK = size(psiMat, 2);
rows = find(rowMask(:)');
best = inf;
pairIdx = [1, min(2, nK)];
for i = 1:nK - 1
    for j = i + 1:nK
        sse = 0;
        cnt = 0;
        for ii = 1:numel(rows)
            it = rows(ii);
            r = R(it, :)';
            k1 = psiMat(:, i);
            k2 = psiMat(:, j);
            m = isfinite(r) & isfinite(k1) & isfinite(k2);
            if nnz(m) < 3
                continue
            end
            A = [k1(m), k2(m)];
            coeff = A \ r(m);
            pred = A * coeff;
            sse = sse + sum((r(m) - pred) .^ 2);
            cnt = cnt + nnz(m);
        end
        if cnt == 0
            continue
        end
        rm = sqrt(sse / cnt);
        rr = rm / max(rmse0, eps);
        if rr < best
            best = rr;
            pairIdx = [i, j];
        end
    end
end
rat = best;
end

function rc = localCorrColumns(phiN, psiMat)
nK = size(psiMat, 2);
rc = NaN(1, nK);
for j = 1:nK
    rc(j) = localSafeCorr(phiN, psiMat(:, j));
end
end

function figPath = localFigPhiVsKernels(xGrid, phiN, psiMat, names, runDir)
baseName = 'phi_vs_physical_kernels';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 11]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
cols = lines(7);
n = size(psiMat, 2);

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, xGrid, phiN, '-', 'LineWidth', 2.6, 'Color', cols(1, :), 'DisplayName', '\Phi (z-scored)');
for j = 1:min(4, n)
    plot(ax1, xGrid, psiMat(:, j), '-', 'LineWidth', 2.0, 'Color', cols(j+1, :), 'DisplayName', char(names{j}));
end
hold(ax1, 'off');
xlabel(ax1, 'x = (I - I_{peak}) / w (dimensionless)');
ylabel(ax1, 'Amplitude (zero-mean, unit L2)');
title(ax1, '\Phi vs PT-derived kernels 1–4');
legend(ax1, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax1);

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, xGrid, phiN, '-', 'LineWidth', 2.6, 'Color', cols(1, :), 'DisplayName', '\Phi (z-scored)');
for j = 5:n
    plot(ax2, xGrid, psiMat(:, j), '-', 'LineWidth', 2.0, 'Color', cols(min(j, 7), :), 'DisplayName', char(names{j}));
end
hold(ax2, 'off');
xlabel(ax2, 'x = (I - I_{peak}) / w (dimensionless)');
ylabel(ax2, 'Amplitude (zero-mean, unit L2)');
title(ax2, '\Phi vs PT-derived kernels 5–6');
legend(ax2, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax2);

figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPath = localFigReconstructionComparison(temps, xGrid, Rall, rowMask, phiEmp, kappaEmp, psiBest, aBest, bestName, runDir)
baseName = 'reconstruction_comparison';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 16 9]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
Tsub = temps(rowMask);
idx = find(rowMask);
[~, iMid] = min(abs(Tsub - median(Tsub, 'omitnan')));
it = idx(iMid);

ax1 = nexttile(tl, 1);
plot(ax1, xGrid, Rall(it, :), 'k-', 'LineWidth', 2.4, 'DisplayName', '\delta S');
hold(ax1, 'on');
plot(ax1, xGrid, kappaEmp(it) * phiEmp(:), '--', 'LineWidth', 2.0, 'DisplayName', '\kappa\Phi');
hold(ax1, 'off');
xlabel(ax1, 'x (dimensionless)');
ylabel(ax1, '\delta S');
title(ax1, sprintf('Residual slice T = %.1f K', temps(it)));
legend(ax1, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax1);

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, xGrid, Rall(it, :), 'k-', 'LineWidth', 2.4, 'DisplayName', '\delta S');
plot(ax2, xGrid, aBest(it) * psiBest(:), '--', 'LineWidth', 2.0, 'Color', [0.85 0.33 0.10], ...
    'DisplayName', ['a \psi (' char(bestName) ')']);
hold(ax2, 'off');
xlabel(ax2, 'x (dimensionless)');
ylabel(ax2, '\delta S');
title(ax2, 'Best physical kernel vs data');
legend(ax2, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax2);

ax3 = nexttile(tl, 3);
plot(ax3, temps(rowMask), kappaEmp(rowMask), 'o-', 'LineWidth', 2.0, 'DisplayName', '\kappa(T)');
hold(ax3, 'on');
plot(ax3, temps(rowMask), aBest(rowMask), 's-', 'LineWidth', 2.0, 'DisplayName', 'a(T) kernel');
hold(ax3, 'off');
xlabel(ax3, 'T (K)');
ylabel(ax3, 'Amplitude');
title(ax3, 'Low-window amplitudes');
legend(ax3, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax3);

ax4 = nexttile(tl, 4);
barh(ax4, abs([localSafeCorr(localZeroMeanUnitL2(phiEmp), localZeroMeanUnitL2(psiBest)); ...
    localCosineSim(localZeroMeanUnitL2(phiEmp), localZeroMeanUnitL2(psiBest))]));
set(ax4, 'YTickLabel', {'|corr|', 'cosine'});
xlabel(ax4, 'Metric value');
ylabel(ax4, 'Shape match');
title(ax4, 'Best kernel vs \Phi');
localStyleAxes(ax4);

figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function localStyleAxes(ax)
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
end

function slice = localAlignmentSlice(repoRoot, decCfg)
source.alignmentRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), char(decCfg.alignmentRunId));
source.fullScalingRunDir = fullfile(switchingCanonicalRunRoot(repoRoot), char(decCfg.fullScalingRunId));
source.alignmentCorePath = fullfile(source.alignmentRunDir, 'switching_alignment_core_data.mat');
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', 'switching_full_scaling_parameters.csv');
source.ptMatrixPath = fullfile(switchingCanonicalRunRoot(repoRoot), ...
    char(decCfg.ptRunId), 'tables', 'PT_matrix.csv');

core = load(source.alignmentCorePath, 'Smap', 'temps', 'currents');
paramsTbl = readtable(source.fullScalingParamsPath);
[SmapAll, tempsAll, currents] = localOrientAndSortMap(core.Smap, core.temps(:), core.currents(:));
[tempsScale, ~, ~, ~] = localExtractScalingColumns(paramsTbl);
[tempsCommon, iMap, iScale] = intersect(tempsAll, tempsScale, 'stable');
Smap = SmapAll(iMap, :);
valid = isfinite(tempsCommon);
slice = struct();
slice.Smap = Smap(valid, :);
slice.temps = tempsCommon(valid);
slice.currents = currents;
slice.ptData = localLoadPTData(source.ptMatrixPath);
end

function [Smap, temps, currents] = localOrientAndSortMap(SmapIn, tempsIn, currentsIn)
Smap = double(SmapIn);
temps = double(tempsIn(:));
currents = double(currentsIn(:));
rowsAreTemps = size(Smap, 1) == numel(temps) && size(Smap, 2) == numel(currents);
rowsAreCurrents = size(Smap, 1) == numel(currents) && size(Smap, 2) == numel(temps);
if rowsAreCurrents && ~rowsAreTemps
    Smap = Smap.';
elseif ~(rowsAreTemps || rowsAreCurrents)
    error('Smap dimensions do not match temps/currents.');
end
[temps, tOrd] = sort(temps);
[currents, iOrd] = sort(currents);
Smap = Smap(tOrd, iOrd);
end

function [temps, Ipeak, Speak, width] = localExtractScalingColumns(tbl)
varNames = string(tbl.Properties.VariableNames);
temps = localNumericColumn(tbl, varNames, ["T_K", "T"]);
Ipeak = localNumericColumn(tbl, varNames, ["Ipeak_mA", "I_peak", "Ipeak"]);
Speak = localNumericColumn(tbl, varNames, ["S_peak", "Speak", "Speak_peak"]);
width = localNumericColumn(tbl, varNames, ["width_chosen_mA", "width_I", "width"]);
[temps, ord] = sort(temps);
Ipeak = Ipeak(ord);
Speak = Speak(ord);
width = width(ord);
end

function col = localNumericColumn(tbl, varNames, candidates)
col = NaN(height(tbl), 1);
for i = 1:numel(candidates)
    idx = find(varNames == candidates(i), 1, 'first');
    if ~isempty(idx)
        raw = tbl.(varNames(idx));
        if isnumeric(raw)
            col = double(raw(:));
        else
            col = str2double(string(raw(:)));
        end
        return
    end
end
end

function ptData = localLoadPTData(ptMatrixPath)
ptData = struct('available', false, 'temps', [], 'currents', [], 'PT', []);
if exist(char(ptMatrixPath), 'file') ~= 2
    return
end
tbl = readtable(char(ptMatrixPath));
varNames = string(tbl.Properties.VariableNames);
if any(varNames == "T_K")
    tCol = "T_K";
else
    tCol = varNames(1);
end
temps = tbl.(tCol);
if isnumeric(temps)
    temps = double(temps(:));
else
    temps = str2double(string(temps(:)));
end
currentCols = setdiff(varNames, tCol, 'stable');
currents = NaN(numel(currentCols), 1);
for j = 1:numel(currentCols)
    currents(j) = localParseCurrentFromColumnName(currentCols(j));
end
keepCols = isfinite(currents);
currents = currents(keepCols);
currentCols = currentCols(keepCols);
if isempty(currents)
    return
end
PT = table2array(tbl(:, currentCols));
PT = double(PT);
[currents, ord] = sort(currents);
PT = PT(:, ord);
ptData.available = true;
ptData.temps = temps;
ptData.currents = currents;
ptData.PT = PT;
end

function val = localParseCurrentFromColumnName(name)
s = char(string(name));
s = regexprep(s, '^Ith_', '', 'ignorecase');
s = regexprep(s, '_mA$', '', 'ignorecase');
sDot = strrep(s, '_', '.');
val = str2double(sDot);
if isfinite(val)
    return
end
m = regexp(s, '[-+]?\d*\.?\d+', 'match', 'once');
if isempty(m)
    val = NaN;
else
    val = str2double(m);
end
end

function zipPath = localBuildReviewZip(runDir, zipName)
reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, zipName);
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
end

function md = localTableToMarkdown(T)
vars = T.Properties.VariableNames;
header = strjoin(vars, ' | ');
sep = strjoin(repmat({'---'}, 1, numel(vars)), ' | ');
rows = strings(height(T), 1);
for r = 1:height(T)
    cells = strings(1, numel(vars));
    for c = 1:numel(vars)
        v = T{r, c};
        if isnumeric(v) || islogical(v)
            if isscalar(v)
                if isnan(v)
                    cells(c) = "NaN";
                else
                    cells(c) = sprintf('%.6g', double(v));
                end
            else
                cells(c) = mat2str(v);
            end
        else
            cells(c) = string(v);
        end
    end
    rows(r) = strjoin(cells, ' | ');
end
md = strjoin([header; sep; rows], newline);
end

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(string(textValue)));
end

function verdict = localVerdict(bestR, bestRatSingle, bestRatPair)
absR = abs(bestR);
if absR >= 0.75 && bestRatSingle <= 1.25
    verdict = 'YES';
elseif absR >= 0.8 && bestRatSingle > 1.25
    verdict = 'PARTIAL';
elseif absR >= 0.5 && (bestRatSingle <= 1.5 || bestRatPair <= 1.25)
    verdict = 'PARTIAL';
else
    verdict = 'NO';
end
end
