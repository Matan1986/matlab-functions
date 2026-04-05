function out = run_phi_even_deformation_test(cfg)
% run_phi_even_deformation_test
% Test whether canonical Phi(x) aligns with even (symmetric) deformation / curvature
% modes of the PT-backed CDF sector vs remaining an empirical residual mode.
%
% Writes only to a new run under results/switching/runs/ (via createRunContext).
% Replays switching_residual_decomposition_analysis with the canonical source stack.

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

runDataset = sprintf('phi_even_deformation | canon_decomp:%s', cfg.canonicalDecompositionRunId);
run = createSwitchingRunContext(repoRoot, struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

fprintf('Phi even-deformation test run directory:\n%s\n', runDir);

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
Rlow = Rall(outDec.lowTemperatureMask, :);
temps = outDec.temperaturesK(:);
lowMask = outDec.lowTemperatureMask(:);
kappaEmp = outDec.kappaAll(:);
currents = outDec.currents_mA(:);
Ipeak = outDec.Ipeak_mA(:);
width = outDec.width_mA(:);
Speak = outDec.Speak(:);
deltaS = outDec.deltaS;

slice = localAlignmentSlice(repoRoot, decCfg);
Smap = slice.Smap;
Scdf = Smap - deltaS;
assert(isequal(size(Scdf), size(deltaS)));

if isfield(cfg, 'canonicalPhiShapePath') && strlength(string(cfg.canonicalPhiShapePath)) > 0
    phiCanonPath = char(string(cfg.canonicalPhiShapePath));
else
    phiCanonPath = fullfile(switchingCanonicalRunRoot(repoRoot), ...
        '_extract_run_2026_03_24_220314_residual_decomposition', ...
        'run_2026_03_24_220314_residual_decomposition', 'tables', 'phi_shape.csv');
end
corrCanon = NaN;
if exist(phiCanonPath, 'file') == 2
    phiTbl = readtable(phiCanonPath);
    xc = phiTbl.x(:);
    phic = phiTbl.Phi(:);
    phiOnGrid = interp1(xc, phic, xGrid, 'linear', NaN);
    m = isfinite(phiOnGrid) & isfinite(phiEmp);
    if nnz(m) >= 5
        corrCanon = corr(phiEmp(m), phiOnGrid(m));
    end
    fprintf('Correlation recomputed Phi vs canonical CSV Phi: %.4f\n', corrCanon);
else
    fprintf('Canonical phi_shape.csv not found (skipping consistency check).\n');
end

[ScdfX, CdfX, ~] = localScdfOnXGrid(Scdf, currents, Ipeak, width, Speak, xGrid);
dSpeak_dT = localGradient1D(temps, Speak);
dWidth_dT = localGradient1D(temps, width);
dIpeak_dT = localGradient1D(temps, Ipeak);

lowIdx = find(lowMask);
Tlow = temps(lowIdx);

%% Even / odd decomposition of Phi
phiEven = localEvenPart(xGrid, phiEmp);
phiOdd = localOddPart(xGrid, phiEmp);
phiResidualEven = phiEmp - phiEven;

oddL2Num = localL2OnGrid(xGrid, phiOdd);
evenL2Num = localL2OnGrid(xGrid, phiEven);
phiL2 = localL2OnGrid(xGrid, phiEmp);
evenL2Frac = evenL2Num / max(phiL2, eps);
oddL2Frac = oddL2Num / max(phiL2, eps);
evenL2FracDiscrete = localEvenL2FractionDiscrete(xGrid, phiEmp);
oddL2FracDiscrete = localOddL2Fraction(xGrid, phiEmp);
maxAbsOdd = max(abs(phiOdd(isfinite(phiOdd))), [], 'omitnan');
maxAbsEven = max(abs(phiEven(isfinite(phiEven))), [], 'omitnan');
maxOddEvenAmpRatio = maxAbsOdd / max(maxAbsEven, eps);
corrPhiEven = localSafeCorr(phiEmp, phiEven);
corrPhiOdd = localSafeCorr(phiEmp, phiOdd);

evennessTbl = table( ...
    evenL2Frac, oddL2Frac, evenL2FracDiscrete, oddL2FracDiscrete, ...
    maxOddEvenAmpRatio, corrPhiEven, corrPhiOdd, corrCanon, ...
    cfg.widthBracketDelta, ...
    'VariableNames', {'even_l2_fraction_trapz', 'odd_l2_fraction_trapz', ...
    'even_l2_fraction_discrete_sum', 'odd_l2_fraction_discrete_sum', ...
    'max_abs_odd_over_even', 'corr_Phi_Phi_even', 'corr_Phi_Phi_odd', ...
    'corr_recomputed_phi_to_canonical_csv', 'width_bracket_delta_used'});
save_run_table(evennessTbl, 'phi_evenness_metrics.csv', runDir);

%% Build even kernel library
deltaW = cfg.widthBracketDelta;
Mcdf = localStackCdfOnX(CdfX, lowIdx);
MedScdf = median(Mcdf, 1, 'omitnan');
MedR = median(Rlow, 1, 'omitnan');
Mstot = localStackSNormOnX(Smap, currents, Ipeak, width, Speak, xGrid, lowIdx);
MedStot = median(Mstot, 1, 'omitnan');

d2cdf = localD2dx(MedScdf(:), xGrid(:));
d2res = localD2dx(MedR(:), xGrid(:));
d2stot = localD2dx(MedStot(:), xGrid(:));
medRsm = smoothdata(MedR(:), 'movmean', cfg.derivativeSmoothWindow);
d2resSm = localD2dx(medRsm, xGrid(:));

psi_d2cdf = localNormalizeKernel(d2cdf);
psi_d2res = localNormalizeKernel(d2res);
psi_d2stot = localNormalizeKernel(d2stot);
psi_d2res_sm = localNormalizeKernel(d2resSm);

psi_width_bracket = localNormalizeKernel(localMedianWidthBracketKernel( ...
    Scdf, Speak, currents, Ipeak, width, xGrid, lowIdx, deltaW));

sigmaG = cfg.fixedGaussianSigma;
xg = xGrid(:);
psi_gauss = localNormalizeKernel(exp(-0.5 * (xg / sigmaG) .^ 2));
sigmaMH = cfg.fixedMexicanHatSigma;
g0 = exp(-0.5 * (xg / sigmaMH) .^ 2);
psi_mex = localNormalizeKernel(localD2dx(g0, xGrid(:)));

psi_center_shoulder = localNormalizeKernel(exp(-(xg / 0.35) .^ 2) - 0.5 * exp(-((xg - 1.1) / 0.45) .^ 2) ...
    - 0.5 * exp(-((xg + 1.1) / 0.45) .^ 2));
psi_dog = localNormalizeKernel(exp(-0.5 * (xg / 0.4) .^ 2) - exp(-0.5 * (xg / 1.05) .^ 2));

psi_even_mean_res = localNormalizeKernel(localEvenPart(xGrid, MedR(:)));
psi_even_mean_stot = localNormalizeKernel(localEvenPart(xGrid, MedStot(:)));

R_even_low = localEvenRowProject(Rlow, xGrid);
R_even_svd = R_even_low;
R_even_svd(~isfinite(R_even_svd)) = 0;
[Uev, Sev, Vev] = svd(R_even_svd, 'econ');
sEv = diag(Sev);
if isempty(sEv)
    pc1_even = NaN(size(xGrid));
else
    pc1_even = Vev(:, 1);
    if localSafeCorr(pc1_even, phiEmp) < 0
        pc1_even = -pc1_even;
    end
end
psi_pc1_even = localNormalizeKernel(pc1_even);

d2cdf_rows = localMedianD2CdfRows(CdfX, xGrid, lowIdx);
psi_d2cdf_median_of_rows = localNormalizeKernel(d2cdf_rows);

candNames = {
    'd2_dx2_median_CDF_x_lowT'
    'd2_dx2_median_residual_deltaS_lowT'
    'd2_dx2_median_Stot_normalized_lowT'
    'cdf_width_bracket_symmetric_fd_median_lowT'
    'd2_dx2_median_dCDF_per_row_then_median'
    'gaussian_even_template_fixed_sigma'
    'mexican_hat_d2_gaussian_fixed_sigma'
    'center_shoulder_redistribution_even_template'
    'difference_of_gaussians_even_template'
    'even_part_median_residual_profile_lowT'
    'even_part_median_Stot_normalized_lowT'
    'pc1_even_projected_residual_lowT'
    'd2_dx2_median_residual_smooth_deriv'
    };

candCategory = {
    'analytic_curvature_mean_CDF'
    'analytic_curvature_mean_residual'
    'analytic_curvature_mean_total_S'
    'pt_backed_width_bracket'
    'pt_backed_curvature_median_rows'
    'geometric_template'
    'geometric_template'
    'geometric_template'
    'geometric_template'
    'data_driven_even'
    'data_driven_even'
    'data_driven_even'
    'robustness_smooth_d2'
    };

candMat = [ ...
    psi_d2cdf(:), psi_d2res(:), psi_d2stot(:), psi_width_bracket(:), ...
    psi_d2cdf_median_of_rows(:), psi_gauss(:), psi_mex(:), ...
    psi_center_shoulder(:), psi_dog(:), psi_even_mean_res(:), psi_even_mean_stot(:), ...
    psi_pc1_even(:), psi_d2res_sm(:)];

nC = size(candMat, 2);
corrShape = NaN(nC, 1);
cos12 = NaN(nC, 1);
overlapI = NaN(nC, 1);
rmseNorm = NaN(nC, 1);
signOrient = NaN(nC, 1);
oddFracPsi = NaN(nC, 1);

RhatEmp = kappaEmp * phiEmp';
qEmp = localEvalQuality(Rlow, RhatEmp(lowMask, :));
qEmpNo22 = localEvalQualityMaskRows(Rlow, RhatEmp(lowMask, :), abs(Tlow - 22) > 0.25);

for j = 1:nC
    psiRaw = candMat(:, j);
    c0 = localSafeCorr(phiEmp, psiRaw);
    signOrient(j) = sign(c0);
    if signOrient(j) == 0
        signOrient(j) = 1;
    end
    psi = localNormalizeKernel(signOrient(j) * psiRaw);
    candMat(:, j) = psi;
    corrShape(j) = localSafeCorr(phiEmp, psi);
    cos12(j) = localCosine12(phiEmp, psi);
    overlapI(j) = localOverlapTrapz(xGrid, phiEmp, psi);
    rmseNorm(j) = localRmseUnit(phiEmp, psi);
    oddFracPsi(j) = localOddL2Fraction(xGrid, psi);
end

[~, sortCorr] = sort(abs(corrShape), 'descend');
topIdx = sortCorr(1:min(6, nC));

cmpTbl = table( ...
    candNames(:), candCategory(:), corrShape, cos12, overlapI, rmseNorm, signOrient, oddFracPsi, ...
    'VariableNames', {'candidate_kernel', 'category', 'corr_Phi_psi', 'cosine_Phi_psi', ...
    'overlap_integral_trapz', 'rmse_normalized_profiles', 'sign_orientation', 'odd_l2_fraction_psi'});
save_run_table(cmpTbl, 'phi_even_kernel_comparison.csv', runDir);

%% Rank-one reconstruction
rmseRat = NaN(nC, 1);
relFrobRat = NaN(nC, 1);
medCorrRat = NaN(nC, 1);
rmseRatNo22 = NaN(nC, 1);
relFrobRatNo22 = NaN(nC, 1);
medCorrRatNo22 = NaN(nC, 1);

for j = 1:nC
    psi = candMat(:, j);
    aj = localFitKappaRows(Rall, psi);
    RhatJ = aj * psi';
    qJ = localEvalQuality(Rlow, RhatJ(lowMask, :));
    rmseRat(j) = qJ.rmse / max(qEmp.rmse, eps);
    relFrobRat(j) = qJ.relFrob / max(qEmp.relFrob, eps);
    medCorrRat(j) = qJ.medianRowCorr / max(qEmp.medianRowCorr, eps);
    qJn = localEvalQualityMaskRows(Rlow, RhatJ(lowMask, :), abs(Tlow - 22) > 0.25);
    rmseRatNo22(j) = qJn.rmse / max(qEmpNo22.rmse, eps);
    relFrobRatNo22(j) = qJn.relFrob / max(qEmpNo22.relFrob, eps);
    medCorrRatNo22(j) = qJn.medianRowCorr / max(qEmpNo22.medianRowCorr, eps);
end

reconTbl = table( ...
    candNames(:), rmseRat, relFrobRat, medCorrRat, rmseRatNo22, relFrobRatNo22, medCorrRatNo22, ...
    'VariableNames', {'candidate_kernel', 'rmse_ratio_to_kappaPhi', 'rel_frob_ratio_to_kappaPhi', ...
    'median_corr_ratio_to_kappaPhi', 'rmse_ratio_excl_22K', 'rel_frob_ratio_excl_22K', ...
    'median_corr_ratio_excl_22K'});
save_run_table(reconTbl, 'phi_even_reconstruction_comparison.csv', runDir);

%% Amplitude links (top 5 by |corr|)
[~, ordC] = sort(abs(corrShape), 'descend');
nTop = min(5, nC);
ampRows = [];
for k = 1:nTop
    j = ordC(k);
    psi = candMat(:, j);
    aj = localFitKappaRows(Rall, psi);
    obsNames = {'kappa_empirical', 'dSpeak_dT', 'width_mA', 'dWidth_dT', 'Ipeak_mA', 'dIpeak_dT'};
    obsVecs = {kappaEmp, dSpeak_dT, width, dWidth_dT, Ipeak, dIpeak_dT};
    for o = 1:numel(obsNames)
        v = obsVecs{o};
        m = lowMask & isfinite(aj) & isfinite(v);
        pr = NaN;
        sp = NaN;
        if nnz(m) >= 5
            pr = corr(aj(m), v(m), 'rows', 'pairwise');
            try
                sp = corr(aj(m), v(m), 'rows', 'pairwise', 'type', 'Spearman');
            catch
                sp = NaN;
            end
        end
        ampRows = [ampRows; {char(candNames{j}), obsNames{o}, pr, sp}]; %#ok<AGROW>
    end
end
ampTbl = cell2table(ampRows, 'VariableNames', ...
    {'candidate_kernel', 'observable', 'pearson_lowT', 'spearman_lowT'});
save_run_table(ampTbl, 'phi_even_amplitude_links.csv', runDir);

%% Even-projected residual control (uses SVD from above)
rank1EvenFrac = NaN;
leadCorrPhi = NaN;
frobLead1Ratio = NaN;
leadMode = pc1_even(:);
if ~isempty(sEv)
    rank1EvenFrac = sEv(1)^2 / max(sum(sEv .^ 2), eps);
    leadCorrPhi = localSafeCorr(leadMode, phiEmp);
    R1 = sEv(1) * Uev(:, 1) * Vev(:, 1)';
    frobLead1Ratio = norm(R1, 'fro') / max(norm(R_even_svd, 'fro'), eps);
end

projTbl = table( ...
    rank1EvenFrac, leadCorrPhi, frobLead1Ratio, size(R_even_low, 1), size(R_even_low, 2), ...
    'VariableNames', {'rank1_energy_fraction_even_projected_R', 'corr_leading_even_mode_Phi', ...
    'frob_ratio_rank1_even_to_full_even_matrix', 'n_lowT_rows', 'n_x_points'});
save_run_table(projTbl, 'phi_even_projected_residual_metrics.csv', runDir);

%% Figures
base_name = 'phi_even_odd_decomposition';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', 'Position', [2 2 12 8]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, xGrid, phiEmp, '-', 'LineWidth', 2.8, 'DisplayName', '\Phi(x)');
plot(ax, xGrid, phiEven, '--', 'LineWidth', 2.2, 'DisplayName', '\Phi_{even}');
plot(ax, xGrid, phiOdd, ':', 'LineWidth', 2.2, 'DisplayName', '\Phi_{odd}');
plot(ax, xGrid, phiResidualEven, '-.', 'LineWidth', 2.0, 'DisplayName', '\Phi - \Phi_{even}');
hold(ax, 'off');
xlabel(ax, 'x = (I - I_{peak}) / w (unitless)');
ylabel(ax, 'Mode amplitude');
legend(ax, 'Location', 'best', 'Box', 'off');
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
figEvenOdd = save_run_figure(fig, base_name, runDir);
close(fig);

base_name = 'phi_vs_top_even_kernels';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', 'Position', [2 2 14 9]);
ax = axes(fig);
hold(ax, 'on');
cols = lines(7);
plot(ax, xGrid, phiEmp, '-', 'LineWidth', 2.8, 'Color', cols(1, :), 'DisplayName', '\Phi(x)');
for ii = 1:numel(topIdx)
    j = topIdx(ii);
    plot(ax, xGrid, candMat(:, j), '-', 'LineWidth', 2.0, 'Color', cols(ii+1, :), ...
        'DisplayName', strrep(candNames{j}, '_', '\_'));
end
hold(ax, 'off');
xlabel(ax, 'x = (I - I_{peak}) / w (unitless)');
ylabel(ax, 'Normalized kernel');
legend(ax, 'Location', 'best', 'Box', 'off');
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
figTop = save_run_figure(fig, base_name, runDir);
close(fig);

base_name = 'phi_even_reconstruction_rmse_ratio_bars';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', 'Position', [2 2 12 7]);
ax = axes(fig);
[~, ordR] = sort(rmseRat, 'ascend');
nBar = min(12, nC);
barh(ax, 1:nBar, rmseRat(ordR(1:nBar)));
set(ax, 'YTick', 1:nBar, 'YTickLabel', candNames(ordR(1:nBar)));
xline(ax, 1, 'k--', 'LineWidth', 1.5);
xlabel(ax, 'RMSE ratio to \kappa\Phi baseline');
ylabel(ax, 'Candidate kernel');
title(ax, 'Rank-one reconstruction (low-T window): RMSE relative to \kappa\Phi');
set(ax, 'FontSize', 12, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
figBar = save_run_figure(fig, base_name, runDir);
close(fig);

base_name = 'phi_even_projected_residual_singular_spectrum';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', 'Position', [2 2 11 6]);
ax = axes(fig);
if ~isempty(sEv)
    semilogy(ax, 1:numel(sEv), sEv ./ max(sEv(1), eps), 'o-', 'LineWidth', 2.2, 'MarkerFaceColor', [0 0.45 0.74]);
    xlabel(ax, 'Singular value index');
    ylabel(ax, 'Normalized singular value');
    title(ax, 'Even-projected residual: singular values');
end
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
figSpec = save_run_figure(fig, base_name, runDir);
close(fig);

jBestEven = ordC(1);
psiBest = candMat(:, jBestEven);
aBest = localFitKappaRows(Rall, psiBest);
base_name = 'phi_even_top_candidate_reconstruction_examples';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', 'Position', [2 2 16 10]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
pickT = localPickExampleTemps(Tlow, [min(Tlow, [], 'omitnan'), 22, median(Tlow, 'omitnan'), max(Tlow, [], 'omitnan')]);
for p = 1:min(4, numel(pickT))
    ax = nexttile(tl, p);
    [ok, it] = localFindTempRow(temps, pickT(p), lowIdx);
    if ~ok
        title(ax, sprintf('T = %.1f K (missing)', pickT(p)));
        continue
    end
    iRow = find(temps == temps(it), 1, 'first');
    hold(ax, 'on');
    plot(ax, xGrid, Rall(iRow, :), 'k-', 'LineWidth', 2.4, 'DisplayName', '\deltaS');
    plot(ax, xGrid, kappaEmp(iRow) * phiEmp(:), '--', 'LineWidth', 2.0, 'DisplayName', '\kappa\Phi');
    plot(ax, xGrid, aBest(iRow) * psiBest(:), '-.', 'LineWidth', 2.0, 'DisplayName', 'a \psi best');
    hold(ax, 'off');
    xlabel(ax, 'x');
    ylabel(ax, '\deltaS');
    title(ax, sprintf('T = %.1f K', temps(iRow)));
    legend(ax, 'Location', 'best', 'Box', 'off');
    set(ax, 'FontSize', 13, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
end
figEx = save_run_figure(fig, base_name, runDir);
close(fig);

base_name = 'phi_even_curvature_width_templates';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', 'Position', [2 2 13 7]);
ax = axes(fig);
hold(ax, 'on');
plot(ax, xGrid, localNormalizeKernel(d2res), '-', 'LineWidth', 2.4, 'DisplayName', 'd^2\langle\deltaS\rangle/dx^2');
plot(ax, xGrid, localNormalizeKernel(d2cdf), '--', 'LineWidth', 2.2, 'DisplayName', 'd^2\langle CDF\rangle/dx^2');
plot(ax, xGrid, psi_width_bracket, '-.', 'LineWidth', 2.2, 'DisplayName', 'width bracket');
hold(ax, 'off');
xlabel(ax, 'x');
ylabel(ax, 'Normalized');
legend(ax, 'Location', 'best', 'Box', 'off');
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
figTpl = save_run_figure(fig, base_name, runDir);
close(fig);

%% Report + ZIP
[verdictKey, verdictHeaderMd, paperSentence] = localVerdict(cmpTbl, reconTbl, corrCanon, evenL2Frac, oddL2FracDiscrete);

reportLines = strings(0, 1);
reportLines(end+1) = "# Phi even deformation / curvature mode report";
reportLines(end+1) = "";
reportLines(end+1) = "## 1. Question";
reportLines(end+1) = "This run tests whether the canonical residual mode **Phi(x)** is best read as a **symmetric (even) deformation** of the switching map in normalized current space—curvature-like broadening/narrowing or symmetric redistribution around the ridge—rather than as a temperature-derivative kernel, asymmetric kernel, shift, or width linearization (addressed in prior runs).";
reportLines(end+1) = "";
reportLines(end+1) = "## 2. Canonical inputs";
reportLines(end+1) = "- **Canonical decomposition reference:** `" + string(cfg.canonicalDecompositionRunId) + "`.";
reportLines(end+1) = "- **Replay run (this folder):** `" + string(outDec.runDir) + "`.";
reportLines(end+1) = "- **Alignment core:** `" + string(decCfg.alignmentRunId) + "`.";
reportLines(end+1) = "- **Full scaling parameters:** `" + string(decCfg.fullScalingRunId) + "`.";
reportLines(end+1) = "- **PT matrix run:** `" + string(decCfg.ptRunId) + "`.";
reportLines(end+1) = "- **Canonical Phi CSV (consistency check):** `" + string(phiCanonPath) + "`.";
reportLines(end+1) = "- **Corr(recomputed Phi, canonical CSV Phi):** `" + sprintf('%.4f', corrCanon) + "`.";
reportLines(end+1) = "- **Low-T window:** T <= " + sprintf('%.1f', cfg.canonicalMaxTemperatureK) + " K.";
reportLines(end+1) = "- **Width bracket FD step (fixed, not tuned):** delta = " + sprintf('%.3f', deltaW) + " (CDF at w(1+delta) minus CDF at w/(1+delta)).";
reportLines(end+1) = "";
reportLines(end+1) = "## 3. Evenness of Phi";
reportLines(end+1) = sprintf("- **Even / odd L2 (trapz):** %.4f / %.4f | **discrete sum ratio:** %.4f / %.4f", ...
    evenL2Frac, oddL2Frac, evenL2FracDiscrete, oddL2FracDiscrete);
reportLines(end+1) = sprintf("- **max |Phi_odd| / max |Phi_even|:** %.4f", maxOddEvenAmpRatio);
reportLines(end+1) = sprintf("- **corr(Phi, Phi_even):** %.4f | **corr(Phi, Phi_odd):** %.4f", corrPhiEven, corrPhiOdd);
reportLines(end+1) = "";
reportLines(end+1) = "## 4. Candidate kernel library";
reportLines(end+1) = "Even-only constructions: median low-T **curvature** of mean CDF / residual / total S in x; **PT-backed** width bracket on CDF; per-row **d2 CDF / dx2** then median; fixed **Gaussian / Mexican-hat / DoG** templates; **even parts** of median profiles; **leading SVD mode** of the **even-projected** residual matrix; **smoothed d2** of median residual (robustness).";
reportLines(end+1) = "";
reportLines(end+1) = "## 5. Comparison to Phi";
reportLines(end+1) = localTableToMarkdown(cmpTbl(:, {'candidate_kernel', 'category', 'corr_Phi_psi', 'cosine_Phi_psi', 'overlap_integral_trapz'}));
reportLines(end+1) = "";
reportLines(end+1) = "## 6. Reconstruction test";
reportLines(end+1) = localTableToMarkdown(reconTbl);
reportLines(end+1) = "";
reportLines(end+1) = "_Baseline kappa*Phi has RMSE ratio 1.0 by construction in this table’s normalization._";
reportLines(end+1) = "";
reportLines(end+1) = "## 7. Even-projected residual control";
reportLines(end+1) = sprintf("- **Rank-1 energy fraction (even R):** %.4f", rank1EvenFrac);
reportLines(end+1) = sprintf("- **corr(leading even mode, Phi):** %.4f", leadCorrPhi);
reportLines(end+1) = "";
reportLines(end+1) = "## 8. Interpretation";
reportLines(end+1) = "- **Mostly even?** See Section 3 (even L2 fraction and corr(Phi, Phi_even)).";
reportLines(end+1) = "- **Curvature-like?** Compare d2 kernels and reconstruction ratios in Sections 5–6.";
reportLines(end+1) = "- **Broadening/narrowing?** See width-bracket kernel and reconstruction.";
reportLines(end+1) = "- **Symmetric redistribution / templates:** DoG / center-shoulder templates and PC1 of even-projected R.";
reportLines(end+1) = "";
reportLines(end+1) = "## 9. Conclusion";
reportLines(end+1) = "**" + verdictHeaderMd + "**";
reportLines(end+1) = "";
reportLines(end+1) = "> " + paperSentence;
reportLines(end+1) = "";
reportLines(end+1) = "## Artifacts";
reportLines(end+1) = "- `tables/phi_evenness_metrics.csv`";
reportLines(end+1) = "- `tables/phi_even_kernel_comparison.csv`";
reportLines(end+1) = "- `tables/phi_even_reconstruction_comparison.csv`";
reportLines(end+1) = "- `tables/phi_even_amplitude_links.csv`";
reportLines(end+1) = "- `tables/phi_even_projected_residual_metrics.csv`";
reportLines(end+1) = "- Figures: phi_even_odd_decomposition, phi_vs_top_even_kernels, phi_even_reconstruction_rmse_ratio_bars, phi_even_projected_residual_singular_spectrum, phi_even_top_candidate_reconstruction_examples, phi_even_curvature_width_templates";

reportPath = save_run_report(strjoin(reportLines, newline), 'phi_even_deformation_report.md', runDir);

reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'phi_even_deformation_bundle.zip');
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', ...
    'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);

appendText(run.notes_path, sprintf('Verdict: %s\n', verdictKey));
appendText(run.log_path, sprintf('Best |corr| even kernel: %s\n', candNames{ordC(1)}));

out = struct();
out.runDir = string(runDir);
out.comparisonTable = cmpTbl;
out.reconstructionTable = reconTbl;
out.verdict = string(verdictKey);
out.reportPath = string(reportPath);
out.figureEvenOdd = figEvenOdd;
out.zipPath = string(zipPath);

fprintf('\n=== Phi even-deformation test complete ===\n');
fprintf('Verdict: %s (see report for emoji status)\n', verdictKey);
fprintf('Report: %s\n', reportPath);
end

%% -------------------------------------------------------------------------
function cfg = applyLocalDefaults(cfg)
cfg = localSetDef(cfg, 'runLabel', 'phi_even_deformation_test');
cfg = localSetDef(cfg, 'canonicalDecompositionRunId', 'run_2026_03_24_220314_residual_decomposition');
cfg = localSetDef(cfg, 'canonicalPhiShapePath', '');
cfg = localSetDef(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = localSetDef(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = localSetDef(cfg, 'ptRunId', 'run_2026_03_24_212033_switching_barrier_distribution_from_map');
cfg = localSetDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = localSetDef(cfg, 'nXGrid', 220);
cfg = localSetDef(cfg, 'fallbackSmoothWindow', 5);
cfg = localSetDef(cfg, 'widthBracketDelta', 0.05);
cfg = localSetDef(cfg, 'fixedGaussianSigma', 0.85);
cfg = localSetDef(cfg, 'fixedMexicanHatSigma', 0.65);
cfg = localSetDef(cfg, 'derivativeSmoothWindow', 3);
end

function cfg = localSetDef(cfg, name, val)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = val;
end
end

function v = localEvenPart(xg, f)
pm = interp1(xg, f(:), -xg, 'linear', NaN);
v = 0.5 * (f(:) + pm);
v(~isfinite(v)) = NaN;
end

function v = localOddPart(xg, f)
pm = interp1(xg, f(:), -xg, 'linear', NaN);
v = 0.5 * (f(:) - pm);
v(~isfinite(v)) = NaN;
end

function s = localL2OnGrid(xg, f)
m = isfinite(f(:)) & isfinite(xg(:));
if nnz(m) < 3
    s = NaN;
    return
end
s = trapz(xg(m), f(m) .^ 2);
end

function f = localOddL2Fraction(xg, phi)
ph = phi(:);
od = localOddPart(xg, ph);
m = isfinite(od) & isfinite(ph);
num = sum(od(m) .^ 2, 'omitnan');
den = sum(ph(m) .^ 2, 'omitnan');
if ~(isfinite(den) && den > eps)
    f = NaN;
else
    f = num / den;
end
end

function f = localEvenL2FractionDiscrete(xg, phi)
ph = phi(:);
ev = localEvenPart(xg, ph);
m = isfinite(ev) & isfinite(ph);
num = sum(ev(m) .^ 2, 'omitnan');
den = sum(ph(m) .^ 2, 'omitnan');
if ~(isfinite(den) && den > eps)
    f = NaN;
else
    f = num / den;
end
end

function d2 = localD2dx(y, xg)
d1 = gradient(y(:), xg(:));
d2 = gradient(d1, xg(:));
end

function M = localStackCdfOnX(CdfX, rowIdx)
M = CdfX(rowIdx, :);
end

function M = localStackSNormOnX(Smap, currents, Ipeak, width, Speak, xGrid, rowIdx)
nx = numel(xGrid);
M = NaN(numel(rowIdx), nx);
for k = 1:numel(rowIdx)
    it = rowIdx(k);
    if ~isfinite(width(it)) || width(it) <= eps
        continue
    end
    Ix = Ipeak(it) + xGrid(:)' .* width(it);
    row = Smap(it, :);
    sx = interp1(currents(:), row(:), Ix(:), 'linear', NaN);
    if all(isfinite(sx))
        M(k, :) = sx(:)' / max(Speak(it), eps);
    end
end
end

function psi = localMedianWidthBracketKernel(Scdf, Speak, currents, Ipeak, width, xGrid, rowIdx, delta)
nx = numel(xGrid);
acc = NaN(numel(rowIdx), nx);
Ic = currents(:);
for k = 1:numel(rowIdx)
    it = rowIdx(k);
    w0 = width(it);
    sp = Speak(it);
    if ~isfinite(w0) || w0 <= eps || ~isfinite(Ipeak(it)) || ~isfinite(sp) || sp <= eps
        continue
    end
    cdfRow = (Scdf(it, :) ./ sp);
    cdfRow = cdfRow(:);
    if numel(cdfRow) ~= numel(Ic)
        continue
    end
    Ihi = Ipeak(it) + xGrid(:)' .* w0 * (1 + delta);
    Ilo = Ipeak(it) + xGrid(:)' .* w0 / (1 + delta);
    ch = interp1(Ic, cdfRow, Ihi(:), 'linear', NaN);
    cl = interp1(Ic, cdfRow, Ilo(:), 'linear', NaN);
    acc(k, :) = (ch(:) - cl(:))';
end
psi = median(acc, 1, 'omitnan');
psi = psi(:);
end

function prof = localMedianD2CdfRows(CdfX, xGrid, rowIdx)
nx = numel(xGrid);
acc = NaN(numel(rowIdx), nx);
for k = 1:numel(rowIdx)
    it = rowIdx(k);
    row = CdfX(it, :);
    acc(k, :) = localD2dx(row(:), xGrid(:))';
end
prof = median(acc, 1, 'omitnan');
prof = prof(:);
end

function R_even = localEvenRowProject(R, xGrid)
[nr, nx] = size(R);
R_even = NaN(nr, nx);
for i = 1:nr
    row = R(i, :)';
    pm = interp1(xGrid, row, -xGrid, 'linear', NaN);
    R_even(i, :) = 0.5 * (row(:) + pm(:))';
end
end

function o = localOverlapTrapz(xg, a, b)
m = isfinite(a(:)) & isfinite(b(:)) & isfinite(xg(:));
if nnz(m) < 5
    o = NaN;
    return
end
num = trapz(xg(m), a(m) .* b(m));
da = trapz(xg(m), a(m) .^ 2);
db = trapz(xg(m), b(m) .^ 2);
o = num / sqrt(max(da, eps) * max(db, eps));
end

function r = localRmseUnit(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    r = NaN;
    return
end
p = a(m) / max(norm(a(m)), eps);
q = b(m) / max(norm(b(m)), eps);
r = sqrt(mean((p - q) .^ 2, 'omitnan'));
end

function q = localEvalQualityMaskRows(R, Rhat, rowMask)
R1 = R(rowMask, :);
H1 = Rhat(rowMask, :);
q = localEvalQuality(R1, H1);
end

function tPick = localPickExampleTemps(Tlow, candidates)
tPick = [];
for c = candidates
    if any(abs(Tlow - c) < 0.21)
        tPick(end+1) = c; %#ok<AGROW>
    end
end
if isempty(tPick)
    tPick = unique(Tlow(:)');
end
tPick = unique(tPick);
end

function [ok, it] = localFindTempRow(temps, targetT, lowIdx)
ok = false;
it = lowIdx(1);
best = Inf;
for k = 1:numel(lowIdx)
    d = abs(temps(lowIdx(k)) - targetT);
    if d < best
        best = d;
        it = lowIdx(k);
    end
end
if best < 0.25
    ok = true;
end
end

function [verdictKey, headerMd, sentence] = localVerdict(cmpTbl, reconTbl, corrCanon, evenL2FracTrapz, oddL2FracDisc)
[~, jBest] = max(abs(cmpTbl.corr_Phi_psi));
bestCorr = abs(cmpTbl.corr_Phi_psi(jBest));
bestRmse = reconTbl.rmse_ratio_to_kappaPhi(jBest);
bestCos = cmpTbl.cosine_Phi_psi(jBest);

if isfinite(corrCanon) && corrCanon < 0.97
    verdictKey = 'partially_supported_replay_drift';
    headerMd = "⚠️ Partially supported";
    sentence = "Because the replayed Phi(x) did not match the archived canonical CSV within the usual tolerance, treat this even-kernel screen as provisional until decomposition replay is bit-aligned with the frozen run.";
    return
end

strong = bestCorr >= 0.80 && bestCos >= 0.85 && bestRmse <= 1.15;
partial = bestCorr >= 0.55 && bestRmse <= 1.40;

if strong
    verdictKey = 'supported';
    headerMd = "✅ Supported";
    sentence = sprintf(['The empirical mode Phi(x) is quantitatively consistent with a fixed symmetric deformation template of the PT-backed sector ' ...
        '(best |corr|~%.2f, rank-one RMSE within ~%.0f%% of kappa*Phi), supporting an even curvature or width-bracket reading rather than a purely abstract SVD shape.'], ...
        bestCorr, 100 * abs(bestRmse - 1));
elseif partial
    verdictKey = 'partially_supported';
    headerMd = "⚠️ Partially supported";
    sentence = sprintf(['Phi(x) partially overlaps symmetric curvature and width-bracket templates (best |corr|~%.2f) but no single fixed even kernel matches the kappa*Phi rank-one reconstruction closely enough to claim a sharp mechanistic identification.'], ...
        bestCorr);
else
    verdictKey = 'not_supported';
    headerMd = "❌ Not supported";
    sentence = sprintf(['Within the tested fixed even kernels, Phi(x) is best described as a robust mostly-even empirical residual mode (discrete odd L2 fraction ~%.3f; trapz even fraction ~%.3f) rather than an identified symmetric differential deformation of the CDF sector.'], ...
        oddL2FracDisc, evenL2FracTrapz);
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

function g = localGradient1D(temps, y)
g = NaN(size(y));
n = numel(temps);
for i = 1:n
    if i == 1 && n >= 2
        g(i) = (y(i+1) - y(i)) / (temps(i+1) - temps(i));
    elseif i == n && n >= 2
        g(i) = (y(i) - y(i-1)) / (temps(i) - temps(i-1));
    else
        g(i) = (y(i+1) - y(i-1)) / (temps(i+1) - temps(i-1));
    end
end
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

function c = localSafeCorr(a, b)
m = isfinite(a(:)) & isfinite(b(:));
if nnz(m) < 5
    c = NaN;
    return
end
c = corr(a(m), b(m));
end

function c = localCosine12(phiV, psiV)
m = isfinite(phiV) & isfinite(psiV);
if nnz(m) < 5
    c = NaN;
    return
end
p = phiV(m);
q = psiV(m);
c = abs(dot(p, q)) / (norm(p) * norm(q) + eps);
end

function k = localFitKappaRows(R, phi)
n = size(R, 1);
k = NaN(n, 1);
for i = 1:n
    r = R(i, :)';
    m = isfinite(r) & isfinite(phi);
    if nnz(m) < 3
        continue
    end
    den = sum(phi(m) .^ 2, 'omitnan');
    if den <= eps
        continue
    end
    k(i) = sum(r(m) .* phi(m), 'omitnan') / den;
end
end

function q = localEvalQuality(R, Rhat)
mask = isfinite(R) & isfinite(Rhat);
if ~any(mask(:))
    q = struct('rmse', NaN, 'relFrob', NaN, 'medianRowCorr', NaN);
    return
end
diffR = R(mask) - Rhat(mask);
q.rmse = sqrt(mean(diffR .^ 2, 'omitnan'));
q.relFrob = norm(diffR, 'fro') / max(norm(R(mask), 'fro'), eps);
corrs = localRowCorr(R, Rhat);
q.medianRowCorr = median(corrs, 'omitnan');
end

function c = localRowCorr(A, B)
n = size(A, 1);
c = NaN(n, 1);
for i = 1:n
    x = A(i, :)';
    y = B(i, :)';
    m = isfinite(x) & isfinite(y);
    if nnz(m) < 3
        continue
    end
    c(i) = corr(x(m), y(m));
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

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(string(textValue)));
end
