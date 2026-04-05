function out = run_phi_pt_independence_test(cfg)
% run_phi_pt_independence_test
% Test whether universal residual shape Phi(x) is approximately orthogonal to a
% span of PT-derived x-space modes (derivatives, PT(T) perturbations, PCA of P_T(x),
% smooth analytic templates). Does not rerun P_T extraction; replays the existing
% residual decomposition pipeline on canonical source runs only.

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

cfg = applyLocalDefaults(cfg);

runDataset = sprintf('phi_pt_independence | sources align:%s fs:%s pt:%s', ...
    cfg.alignmentRunId, cfg.fullScalingRunId, cfg.ptRunId);
run = createSwitchingRunContext(repoRoot, struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

fprintf('Phi / PT independence test run directory:\n%s\n', runDir);

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
phi = outDec.phi(:);
nx = numel(xGrid);
lowMask = outDec.lowTemperatureMask(:);
temps = outDec.temperaturesK(:);
Rlow = outDec.Rall(lowMask, :);
kappaAll = outDec.kappaAll(:);
currents = outDec.currents_mA(:);
Ipeak = outDec.Ipeak_mA(:);
width = outDec.width_mA(:);
deltaS = outDec.deltaS;
slice = localAlignmentSlice(repoRoot, decCfg);
Smap = slice.Smap;
Scdf = Smap - deltaS;

[ScdfX, CdfX, dCdf_dI_on_x] = localScdfOnXGrid(Scdf, currents, Ipeak, width, outDec.Speak, xGrid);

%% P_T as PDF on x-grid (per temperature, full row set)
nT = numel(temps);
Ptx = NaN(nT, nx);
for it = 1:nT
    pI = localPTpdfOnCurrents(slice.ptData, temps(it), currents);
    if isempty(pI)
        continue
    end
    xRow = (currents(:) - Ipeak(it)) ./ width(it);
    Ptx(it, :) = localInterpXYtoXgrid(xRow, pI(:), xGrid);
end

dPdT_I = localDdtSlice2(slice.ptData, currents, temps, Ipeak, width);
Ptx_dPdT = NaN(nT, nx);
for it = 1:nT
    if isempty(dPdT_I{it})
        continue
    end
    xRow = (currents(:) - Ipeak(it)) ./ width(it);
    Ptx_dPdT(it, :) = localInterpXYtoXgrid(xRow, dPdT_I{it}(:), xGrid);
end

lowIdx = find(lowMask);
Plow = Ptx(lowIdx, :);
mFin = isfinite(Plow);
if nnz(mFin) < 10
    error('Too few finite P_T(x) samples in canonical window.');
end

psi_cdf_dI = localNormalizeKernel(localAggregateLowT(dCdf_dI_on_x, lowMask));
psi_dPdT = localNormalizeKernel(localAggregateLowT(Ptx_dPdT, lowMask));
psi_mean_PT = localNormalizeKernel(mean(Plow, 1, 'omitnan'));

%% PCA of P_T(x) on low-T rows (rows centered)
Pcent = Plow - mean(Plow, 1, 'omitnan');
Pcent(~isfinite(Pcent)) = 0;
[Up, Sp, Vp] = svd(Pcent, 'econ');
nPca = min(cfg.nPcaModes, size(Vp, 2));
psi_pca = NaN(nx, nPca);
for k = 1:nPca
    psi_pca(:, k) = localNormalizeKernel(Vp(:, k));
end

%% Local PT perturbations: finite-diff wrt T on mean-normalized PDF
PtxN = localRowNormalize(Ptx);
dPtxN_dT = localDdtSlice(PtxN, temps);
psi_dPnorm_dT = localNormalizeKernel(localAggregateLowT(dPtxN_dT, lowMask));

%% Smooth analytic modes on x
sig = cfg.gaussianModeSigma;
g0 = exp(-0.5 * (xGrid / sig) .^ 2);
g1 = xGrid .* g0;
g2 = (xGrid .^ 2 - sig ^ 2) .* g0;
psi_g0 = localNormalizeKernel(g0);
psi_g1 = localNormalizeKernel(g1);
psi_g2 = localNormalizeKernel(g2);

bumpCenters = cfg.splineBumpCenters;
psi_bumps = NaN(nx, numel(bumpCenters));
for b = 1:numel(bumpCenters)
    psi_bumps(:, b) = localNormalizeKernel(exp(-0.5 * ((xGrid - bumpCenters(b)) / cfg.splineBumpSigma) .^ 2));
end

%% Quantile profiles of P_T(x) across low-T
qLev = cfg.quantileLevels;
Qprofiles = NaN(numel(qLev), nx);
for j = 1:nx
    col = Plow(:, j);
    col = col(isfinite(col));
    if numel(col) >= 3
        Qprofiles(:, j) = prctile(col, qLev)';
    end
end

modeNames = {
    'dCDF_dI_median_lowT'
    'dP_T_dT_median_lowT'
    'dPnorm_dT_median_lowT'
    'mean_P_T_x_median_rows'
    };
for k = 1:nPca
    modeNames{end+1} = sprintf('P_T_x_PCA_%d', k); %#ok<AGROW>
end
modeNames{end+1} = 'gauss_base';
modeNames{end+1} = 'gauss_skew_x';
modeNames{end+1} = 'gauss_curvature';
for b = 1:numel(bumpCenters)
    modeNames{end+1} = sprintf('gauss_bump_x_%g', bumpCenters(b)); %#ok<AGROW>
end

Psi = [psi_cdf_dI(:), psi_dPdT(:), psi_dPnorm_dT(:), psi_mean_PT(:), psi_pca, ...
    psi_g0(:), psi_g1(:), psi_g2(:), psi_bumps];

nModes = size(Psi, 2);
mAll = isfinite(phi) & all(isfinite(Psi), 2);
if nnz(mAll) < max(15, round(0.5 * nx))
    mAll = isfinite(phi);
    for j = 1:nModes
        v = Psi(:, j);
        mu = mean(v(isfinite(v)), 'omitnan');
        v(~isfinite(v)) = mu;
        Psi(:, j) = v;
    end
    mAll = isfinite(phi);
end

phi_v = phi(mAll);
Psi_v = Psi(mAll, :);
[Qb, ~] = qr(Psi_v, 0);
proj_v = Qb * (Qb' * phi_v);
res_v = phi_v - proj_v;
phiNorm = norm(phi_v);
projNorm = norm(proj_v);
resNorm = norm(res_v);
projRatio = projNorm / max(phiNorm, eps);
resFrac = resNorm / max(phiNorm, eps);
varExplained = (projNorm ^ 2) / max(phiNorm ^ 2, eps);

coeff_ls = Psi_v \ phi_v;
recon_v = Psi_v * coeff_ls;
reconRmse = sqrt(mean((phi_v - recon_v) .^ 2, 'omitnan'));
phiRms = sqrt(mean(phi_v .^ 2, 'omitnan'));

%% kappa*Phi baseline RMSE on low-T residual stack (same as decomposition quality)
RhatLow = kappaAll(lowMask) * phi';
maskR = isfinite(Rlow) & isfinite(RhatLow);
baselineKappaPhiRmse = sqrt(mean((Rlow(maskR) - RhatLow(maskR)) .^ 2, 'omitnan'));

projTbl = table( ...
    projRatio, resFrac, varExplained, phiNorm, projNorm, resNorm, ...
    reconRmse, phiRms, reconRmse / max(phiRms, eps), baselineKappaPhiRmse, ...
    nnz(mAll), nModes, ...
    'VariableNames', {'projection_norm_ratio', 'residual_norm_ratio', 'variance_explained_pt_space', ...
    'phi_l2_on_mask', 'projection_l2', 'residual_l2', 'reconstruction_rmse', 'phi_rms_on_mask', ...
    'reconstruction_rmse_over_phi_rms', 'baseline_kappa_phi_rmse_lowT', 'n_grid_points_used', 'n_pt_modes'});

projPath = save_run_table(projTbl, 'phi_projection_metrics.csv', runDir);

coefNames = string(modeNames(:));
recRows = table(coefNames, coeff_ls(:), (1:nModes)', ...
    'VariableNames', {'mode_name', 'least_squares_coefficient', 'mode_index'});
recRows.reconstruction_rmse_global = repmat(reconRmse, nModes, 1);
recRows.phi_rms_on_mask = repmat(phiRms, nModes, 1);
recPath = save_run_table(recRows, 'phi_reconstruction_from_pt_space.csv', runDir);

%% Cross-correlations (shape vs shape; scalars vs PT_summary)
cq = strings(0, 1);
cc = zeros(0, 1);

cq(end+1, 1) = "mean_P_T_x_profile";
cc(end+1, 1) = localSafeCorr(phi, psi_mean_PT);

cq(end+1, 1) = "dCDF_dI_profile";
cc(end+1, 1) = localSafeCorr(phi, psi_cdf_dI);

for k = 1:nPca
    cq(end+1, 1) = sprintf("P_T_x_PCA_%d_loading", k);
    cc(end+1, 1) = localSafeCorr(phi, psi_pca(:, k));
end

for qi = 1:numel(qLev)
    qv = localNormalizeKernel(Qprofiles(qi, :));
    cq(end+1, 1) = sprintf("P_T_x_q%g_profile", qLev(qi));
    cc(end+1, 1) = localSafeCorr(phi, qv(:));
end

ptSumPath = fullfile(switchingCanonicalRunRoot(repoRoot), char(cfg.ptRunId), 'tables', 'PT_summary.csv');
if exist(ptSumPath, 'file') == 2
    ptSum = readtable(ptSumPath);
    Tsum = localNumericFromTable(ptSum, 'T_K');
    meanI = localNumericFromTable(ptSum, 'mean_threshold_mA');
    stdI = localNumericFromTable(ptSum, 'std_threshold_mA');
    skewI = localNumericFromTable(ptSum, 'skewness');
    [~, ia, ib] = intersect(temps(:), Tsum(:), 'stable');
    if numel(ia) >= 4
        sDot = NaN(numel(temps), 1);
        for ii = 1:numel(ia)
            it = ia(ii);
            pr = Ptx(it, :)';
            ph = phi(:);
            m = isfinite(pr) & isfinite(ph);
            if nnz(m) >= 5
                sDot(it) = dot(ph(m), pr(m));
            end
        end
        cq(end+1, 1) = "dot_phi_PT_vs_T_mean_mA";
        cc(end+1, 1) = localSafeCorr(sDot(ia), meanI(ib));
        cq(end+1, 1) = "dot_phi_PT_vs_T_std_mA";
        cc(end+1, 1) = localSafeCorr(sDot(ia), stdI(ib));
        cq(end+1, 1) = "dot_phi_PT_vs_T_skew";
        cc(end+1, 1) = localSafeCorr(sDot(ia), skewI(ib));
    end
    if numel(ia) >= 4
        cq(end+1, 1) = "kappa_vs_mean_threshold_mA";
        cc(end+1, 1) = localSafeCorr(kappaAll(ia), meanI(ib));
        cq(end+1, 1) = "kappa_vs_std_threshold_mA";
        cc(end+1, 1) = localSafeCorr(kappaAll(ia), stdI(ib));
        cq(end+1, 1) = "kappa_vs_skewness";
        cc(end+1, 1) = localSafeCorr(kappaAll(ia), skewI(ib));
    end
end

corrRows = table(cq, cc, 'VariableNames', {'quantity', 'corr_with_phi'});

corrPath = save_run_table(corrRows, 'phi_pt_correlation_metrics.csv', runDir);

maxAbsCorr = max(abs(corrRows.corr_with_phi(isfinite(corrRows.corr_with_phi))), [], 'omitnan');
if isempty(maxAbsCorr) || ~isfinite(maxAbsCorr)
    maxAbsCorr = NaN;
end

%% Figures
figProj = localFigProjectionBar(runDir, coeff_ls, modeNames);
figRecon = localFigReconstruction(runDir, xGrid, phi, recon_v, mAll);
figSv = localFigSingularValues(runDir, Sp);

%% Verdict
indepProj = projRatio < cfg.thresholdProjectionRatio;
indepRecon = (reconRmse / max(phiRms, eps)) > cfg.thresholdReconRmseFrac;
indepCorr = maxAbsCorr < cfg.thresholdCorr;
verdictSupported = indepProj && indepRecon && indepCorr;
if verdictSupported
    verdictStr = 'INDEPENDENT';
else
    verdictStr = 'NOT INDEPENDENT';
end

reportLines = strings(0, 1);
reportLines(end+1) = "# Phi vs PT-deformation space (independence diagnostic)";
reportLines(end+1) = "";
reportLines(end+1) = sprintf("**Run directory:** `%s`", runDir);
reportLines(end+1) = sprintf("**Sources:** alignment `%s`, full_scaling `%s`, PT matrix `%s`", ...
    cfg.alignmentRunId, cfg.fullScalingRunId, cfg.ptRunId);
reportLines(end+1) = "";
reportLines(end+1) = "## Verdict";
reportLines(end+1) = sprintf("**VERDICT: %s**", verdictStr);
reportLines(end+1) = "";
reportLines(end+1) = "### Metrics";
reportLines(end+1) = sprintf("- Projection norm ratio ||proj||/||Phi||: **%.4f** (threshold < %.2f for independence)", ...
    projRatio, cfg.thresholdProjectionRatio);
reportLines(end+1) = sprintf("- Best linear reconstruction RMSE / RMS(Phi): **%.4f** (independence favors >> %.2f)", ...
    reconRmse / max(phiRms, eps), cfg.thresholdReconRmseFrac);
reportLines(end+1) = sprintf("- Max |correlation| with listed PT-derived quantities: **%.4f** (threshold < %.2f)", ...
    maxAbsCorr, cfg.thresholdCorr);
reportLines(end+1) = sprintf("- Variance of Phi explained by PT-mode span (squared ratio): **%.4f**", varExplained);
reportLines(end+1) = sprintf("- Low-T baseline RMSE of kappa*Phi vs deltaS: **%.6g**", baselineKappaPhiRmse);
reportLines(end+1) = "";
reportLines(end+1) = "### Criteria checklist";
reportLines(end+1) = sprintf("- Projection ratio << 1: %s", ternaryStr(indepProj));
reportLines(end+1) = sprintf("- Reconstruction poor vs Phi RMS: %s", ternaryStr(indepRecon));
reportLines(end+1) = sprintf("- Weak correlations: %s", ternaryStr(indepCorr));
reportLines(end+1) = "";
reportLines(end+1) = "## Mode inventory";
reportLines(end+1) = localTableToMarkdown(recRows(:, {'mode_name', 'least_squares_coefficient'}));
reportLines(end+1) = "";
reportLines(end+1) = "## Correlations";
reportLines(end+1) = localTableToMarkdown(corrRows);
reportLines(end+1) = "";
reportLines(end+1) = "## Artifacts";
reportLines(end+1) = sprintf("- `%s`", projPath);
reportLines(end+1) = sprintf("- `%s`", recPath);
reportLines(end+1) = sprintf("- `%s`", corrPath);
reportLines(end+1) = sprintf("- `%s`", figProj.png);
reportLines(end+1) = sprintf("- `%s`", figRecon.png);
reportLines(end+1) = sprintf("- `%s`", figSv.png);

reportPath = save_run_report(strjoin(reportLines, newline), 'phi_independence_report.md', runDir);
zipPath = buildReviewZip(runDir, 'phi_independence_bundle.zip');

appendText(run.log_path, sprintf('VERDICT: %s | proj_ratio=%.4f recon_rmse/phi_rms=%.4f max|corr|=%.4f\n', ...
    verdictStr, projRatio, reconRmse / max(phiRms, eps), maxAbsCorr));

out = struct();
out.runDir = string(runDir);
out.verdict = string(verdictStr);
out.projectionNormRatio = projRatio;
out.reconstructionRmse = reconRmse;
out.reconstructionRmseOverPhiRms = reconRmse / max(phiRms, eps);
out.maxAbsCorrelation = maxAbsCorr;
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Phi / PT independence test complete ===\n');
fprintf('VERDICT: %s\n', verdictStr);
fprintf('Projection norm ratio: %.4f\n', projRatio);
fprintf('Reconstruction RMSE / RMS(Phi): %.4f\n', reconRmse / max(phiRms, eps));
fprintf('Max |correlation| (PT-derived): %.4f\n', maxAbsCorr);
fprintf('Report: %s\n', reportPath);
end

function s = ternaryStr(flag)
if flag
    s = "pass";
else
    s = "fail";
end
end

%% -------------------------------------------------------------------------
function cfg = applyLocalDefaults(cfg)
cfg = localSetDef(cfg, 'runLabel', 'phi_pt_independence_test');
cfg = localSetDef(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = localSetDef(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = localSetDef(cfg, 'ptRunId', 'run_2026_03_25_013356_pt_robust_canonical');
cfg = localSetDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = localSetDef(cfg, 'nXGrid', 220);
cfg = localSetDef(cfg, 'fallbackSmoothWindow', 5);
cfg = localSetDef(cfg, 'nPcaModes', 4);
cfg = localSetDef(cfg, 'gaussianModeSigma', 0.65);
cfg = localSetDef(cfg, 'splineBumpCenters', [-1.1, 0, 1.1]);
cfg = localSetDef(cfg, 'splineBumpSigma', 0.35);
cfg = localSetDef(cfg, 'quantileLevels', [25, 50, 75]);
cfg = localSetDef(cfg, 'thresholdProjectionRatio', 0.5);
cfg = localSetDef(cfg, 'thresholdReconRmseFrac', 0.5);
cfg = localSetDef(cfg, 'thresholdCorr', 0.5);
end

function cfg = localSetDef(cfg, name, val)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = val;
end
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
[tempsScale, IpeakScale, SpeakScale, widthScale] = localExtractScalingColumns(paramsTbl);
[tempsCommon, iMap, iScale] = intersect(tempsAll, tempsScale, 'stable');
Smap = SmapAll(iMap, :);
Ipeak = IpeakScale(iScale);
Speak = SpeakScale(iScale);
width = widthScale(iScale);
valid = isfinite(tempsCommon) & isfinite(Ipeak) & isfinite(Speak) & isfinite(width);
valid = valid & (width > 0);
valid = valid & (Speak > 1e-3 * max(Speak, [], 'omitnan'));
slice = struct();
slice.Smap = Smap(valid, :);
slice.temps = tempsCommon(valid);
slice.currents = currents;
slice.Ipeak = Ipeak(valid);
slice.Speak = Speak(valid);
slice.width = width(valid);
slice.ptData = localLoadPTData(source.ptMatrixPath);
end

function pFull = localPTpdfOnCurrents(ptData, targetT, currents)
pFull = [];
if ~ptData.available
    return
end
tempsPT = ptData.temps(:);
currPT = ptData.currents(:);
PT = ptData.PT;
if numel(tempsPT) < 2 || size(PT, 2) ~= numel(currPT)
    return
end
pAtT = NaN(numel(currPT), 1);
for j = 1:numel(currPT)
    col = PT(:, j);
    m = isfinite(tempsPT) & isfinite(col);
    if nnz(m) < 2
        continue
    end
    pAtT(j) = interp1(tempsPT(m), col(m), targetT, 'linear', NaN);
end
if all(~isfinite(pAtT))
    return
end
pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);
areaPT = trapz(currPT, pAtT);
if ~(isfinite(areaPT) && areaPT > 0)
    return
end
pAtT = pAtT ./ areaPT;
pOnCurrents = interp1(currPT, pAtT, currents(:), 'linear', 0);
pOnCurrents = max(pOnCurrents, 0);
area = trapz(currents, pOnCurrents);
if ~(isfinite(area) && area > 0)
    return
end
pFull = (pOnCurrents ./ area);
end

function yx = localInterpXYtoXgrid(xRow, yRow, xGrid)
m = isfinite(xRow) & isfinite(yRow);
if nnz(m) < 3
    yx = NaN(1, numel(xGrid));
    return
end
xr = xRow(m);
yr = yRow(m);
[xr, ord] = sort(xr);
yr = yr(ord);
[xu, iu] = unique(xr, 'stable');
yu = yr(iu);
yx = interp1(xu, yu, xGrid(:), 'linear', NaN)';
end

function D = localDdtSlice(F, temps)
D = NaN(size(F));
nT = size(F, 1);
for it = 1:nT
    if it == 1 && nT >= 2
        alpha = (temps(it+1) - temps(it));
        if alpha ~= 0
            D(it, :) = (F(it+1, :) - F(it, :)) / alpha;
        end
    elseif it == nT && nT >= 2
        alpha = (temps(it) - temps(it-1));
        if alpha ~= 0
            D(it, :) = (F(it, :) - F(it-1, :)) / alpha;
        end
    else
        den = (temps(it+1) - temps(it-1));
        if den ~= 0
            D(it, :) = (F(it+1, :) - F(it-1, :)) / den;
        end
    end
end
end

function dCell = localDdtSlice2(ptData, currents, temps, Ipeak, width)
nT = numel(temps);
dCell = cell(nT, 1);
if ~ptData.available
    return
end
Pall = NaN(nT, numel(currents));
for it = 1:nT
    p = localPTpdfOnCurrents(ptData, temps(it), currents);
    if ~isempty(p)
        Pall(it, :) = p(:)';
    end
end
for it = 1:nT
    if it == 1 && nT >= 2
        dCell{it} = (Pall(it+1, :) - Pall(it, :)) / (temps(it+1) - temps(it));
    elseif it == nT && nT >= 2
        dCell{it} = (Pall(it, :) - Pall(it-1, :)) / (temps(it) - temps(it-1));
    else
        den = (temps(it+1) - temps(it-1));
        if den ~= 0
            dCell{it} = (Pall(it+1, :) - Pall(it-1, :)) / den;
        else
            dCell{it} = NaN(1, numel(currents));
        end
    end
end
end

function Pn = localRowNormalize(P)
Pn = P;
for i = 1:size(P, 1)
    r = P(i, :);
    m = isfinite(r);
    s = sum(r(m), 'omitnan');
    if isfinite(s) && s > 0
        Pn(i, m) = r(m) / s;
    end
end
end

function v = localAggregateLowT(M, lowMask)
rows = find(lowMask(:));
if numel(rows) < 1
    v = NaN(1, size(M, 2));
    return
end
v = median(M(rows, :), 1, 'omitnan');
end

function psi = localNormalizeKernel(psiRow)
v = psiRow(:);
m = isfinite(v);
if nnz(m) < 3
    psi = NaN(size(v));
    return
end
scale = max(abs(v(m)), [], 'omitnan');
if ~(isfinite(scale) && scale > 0)
    scale = 1;
end
psi = v ./ scale;
end

function [ScdfX, CdfX, dCdf_dI_on_x] = localScdfOnXGrid(Scdf, currents, Ipeak, width, Speak, xGrid)
nT = size(Scdf, 1);
nx = numel(xGrid);
ScdfX = NaN(nT, nx);
CdfX = NaN(nT, nx);
dCdf_dI_on_x = NaN(nT, nx);
for it = 1:nT
    Ix = Ipeak(it) + xGrid(:)' .* width(it);
    rowS = Scdf(it, :);
    cdfRow = rowS / Speak(it);
    dCdf_dI = gradient(cdfRow(:), currents(:));
    for k = 1:nx
        ik = Ix(k);
        ScdfX(it, k) = interp1(currents(:), rowS(:), ik, 'linear', NaN);
        CdfX(it, k) = interp1(currents(:), cdfRow(:), ik, 'linear', NaN);
        dCdf_dI_on_x(it, k) = interp1(currents(:), dCdf_dI(:), ik, 'linear', NaN);
    end
end
end

function c = localSafeCorr(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    c = NaN;
    return
end
c = corr(a(m), b(m));
end

function col = localNumericFromTable(tbl, preferred)
vn = string(tbl.Properties.VariableNames);
idx = find(vn == preferred, 1);
if isempty(idx)
    col = NaN(height(tbl), 1);
    return
end
raw = tbl.(vn(idx));
if isnumeric(raw)
    col = double(raw(:));
else
    col = str2double(string(raw(:)));
end
end

function ptData = localLoadPTData(ptMatrixPath)
ptData = struct('available', false, 'temps', [], 'currents', [], 'PT', []);
if exist(ptMatrixPath, 'file') ~= 2
    return
end
tbl = readtable(ptMatrixPath);
varNames = string(tbl.Properties.VariableNames);
if isempty(varNames)
    return
end
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

function figPath = localFigProjectionBar(runDir, coeff, modeNames)
base_name = 'projection_bar';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 12 10]);
ax = axes(fig);
bar(ax, 1:numel(coeff), coeff, 'FaceColor', [0.2 0.45 0.7]);
set(ax, 'XTick', 1:numel(coeff), 'XTickLabel', cellstr(modeNames), 'XTickLabelRotation', 55);
ylabel(ax, 'LS coefficient');
xlabel(ax, 'PT-space mode');
grid(ax, 'on');
set(ax, 'FontSize', 14);
figPath = save_run_figure(fig, base_name, runDir);
close(fig);
end

function figPath = localFigReconstruction(runDir, xGrid, phi, recon_v, mAll)
base_name = 'reconstruction_error';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 12 7]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, xGrid(mAll), phi(mAll), '-', 'LineWidth', 2.4, 'Color', [0 0.45 0.74], 'DisplayName', '\Phi(x)');
plot(ax, xGrid(mAll), recon_v, '--', 'LineWidth', 2.2, 'Color', [0.85 0.33 0.1], 'DisplayName', 'PT-space LS fit');
hold(ax, 'off');
xlabel(ax, 'x = (I - I_{peak}) / w');
ylabel(ax, 'Amplitude (normalized modes)');
legend(ax, 'Location', 'best');
grid(ax, 'on');
set(ax, 'FontSize', 14);
figPath = save_run_figure(fig, base_name, runDir);
close(fig);
end

function figPath = localFigSingularValues(runDir, Sp)
base_name = 'pt_space_singular_values';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 10 6]);
ax = axes(fig);
s = diag(Sp);
plot(ax, 1:numel(s), s, '-o', 'LineWidth', 2.2, 'MarkerFaceColor', [0.2 0.55 0.35]);
xlabel(ax, 'Index (low-T P_T(x) stack SVD)');
ylabel(ax, 'Singular value');
grid(ax, 'on');
set(ax, 'FontSize', 14);
set(ax, 'YScale', 'log');
figPath = save_run_figure(fig, base_name, runDir);
close(fig);
end

function zipPath = buildReviewZip(runDir, zipName)
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

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(string(textValue)));
end
