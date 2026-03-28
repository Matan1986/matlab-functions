function out = run_phi_asymmetry_link(cfg)
% run_phi_asymmetry_link
% Link empirical residual mode Phi(x) from the switching residual decomposition
% to asymmetric-deformation templates and to asymmetry observables from S(I,T).
%
% Reads canonical decomposition via replay of switching_residual_decomposition_analysis
% (same source runs as the reference decomposition); does not modify prior run folders.

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

runDataset = sprintf('phi_asymmetry_link | canon_decomp:%s', cfg.canonicalDecompositionRunId);
run = createRunContext('switching', struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

fprintf('Phi asymmetry link run directory:\n%s\n', runDir);

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
assert(isequal(size(Smap), size(deltaS)), 'Smap size mismatch vs deltaS.');

[asymArea, halfDiff, qAsym, wLeft, wRight] = localAsymmetryFromS(Smap, currents, Ipeak, Speak);

[asymAudit, halfAudit] = localLoadAlignmentObservables(repoRoot, cfg.alignmentRunId, temps);

phiOddFrac = localPhiOddFraction(xGrid, phiEmp);

xg = xGrid(:);
psiOddGauss = localNormalizeKernel(xg .* exp(-0.5 * xg .^ 2));
psiTanh = localNormalizeKernel(tanh(2 * xg) .* exp(-0.5 * xg .^ 2));
psiSkew = localNormalizeKernel(erf((xg - 0.35) / 0.55) - erf((-xg - 0.35) / 0.55));
Rmean = mean(Rlow, 1, 'omitnan');
psiResAnt = localNormalizeKernel(localAntisymPart(xGrid(:), Rmean(:))');
SmeanX = localMeanSOnXGrid(Smap, currents, Ipeak, width, Speak, xGrid, lowMask);
psiSant = localNormalizeKernel(localAntisymPart(xGrid(:), SmeanX(:))');
psiHalfDiffTemplate = localNormalizeKernel(localHalfProfileDiffKernel(xg));

candNames = {
    'odd_gaussian_x_exp_neg_x2'
    'tanh_times_gaussian_window'
    'skewed_erf_pair_difference'
    'mean_residual_antisymmetric_part'
    'mean_S_profile_antisymmetric_part'
    'left_right_half_profile_difference_template'
    };

candMat = [psiOddGauss(:), psiTanh(:), psiSkew(:), psiResAnt(:), psiSant(:), psiHalfDiffTemplate(:)];

nC = size(candMat, 2);
corrShape = NaN(nC, 1);
cos12 = NaN(nC, 1);
rmseRat = NaN(nC, 1);
relFrobRat = NaN(nC, 1);
medCorrRat = NaN(nC, 1);
corr_a_kappa = NaN(nC, 1);

RhatEmp = kappaEmp * phiEmp';
qEmp = localEvalQuality(Rlow, RhatEmp(lowMask, :));

for j = 1:nC
    psi = localNormalizeKernel(candMat(:, j));
    corrShape(j) = localSafeCorr(phiEmp, psi);
    cos12(j) = localCosine12(phiEmp, psi);
    aj = localFitKappaRows(Rall, psi);
    RhatJ = aj * psi';
    qJ = localEvalQuality(Rlow, RhatJ(lowMask, :));
    rmseRat(j) = qJ.rmse / max(qEmp.rmse, eps);
    relFrobRat(j) = qJ.relFrob / max(qEmp.relFrob, eps);
    medCorrRat(j) = qJ.medianRowCorr / max(qEmp.medianRowCorr, eps);
    corr_a_kappa(j) = corr(aj(lowMask), kappaEmp(lowMask), 'rows', 'pairwise');
end

cmpTbl = table( ...
    candNames(:), corrShape, cos12, rmseRat, relFrobRat, medCorrRat, corr_a_kappa, ...
    'VariableNames', {'candidate_kernel', 'corr_Phi_psi', 'cosine_Phi_psi', ...
    'rmse_ratio_to_kappaPhi', 'rel_frob_ratio_to_kappaPhi', 'median_corr_ratio_to_kappaPhi', ...
    'corr_aT_kappaEmp_lowT'});

[~, jBest] = max(abs(corrShape));
psiBest = localNormalizeKernel(candMat(:, jBest));
aBest = localFitKappaRows(Rall, psiBest);

corrKappaAsymAudit = corr(kappaEmp(lowMask), asymAudit(lowMask), 'rows', 'pairwise');
corrKappaHalfDiff = corr(kappaEmp(lowMask), halfAudit(lowMask), 'rows', 'pairwise');
corrKappaAsymArea = corr(kappaEmp(lowMask), asymArea(lowMask), 'rows', 'pairwise');
corrKappaQAsym = corr(kappaEmp(lowMask), qAsym(lowMask), 'rows', 'pairwise');

metaTbl = table( ...
    phiOddFrac, corrKappaAsymAudit, corrKappaHalfDiff, corrKappaAsymArea, corrKappaQAsym, ...
    string(candNames{jBest}), abs(corrShape(jBest)), rmseRat(jBest), ...
    'VariableNames', {'phi_l2_odd_energy_fraction', 'corr_kappa_asym_audit_lowT', ...
    'corr_kappa_halfwidth_diff_audit_lowT', 'corr_kappa_asym_area_S_lowT', 'corr_kappa_quantile_asym_lowT', ...
    'best_asym_kernel_name', 'best_abs_corr_Phi_psi', 'best_rmse_ratio_to_kappaPhi'});

save_run_table(cmpTbl, 'phi_asymmetry_comparison.csv', runDir);
save_run_table(metaTbl, 'phi_asymmetry_meta.csv', runDir);

asymKappaTbl = table(temps, kappaEmp, asymAudit, halfAudit, asymArea, halfDiff, qAsym, wLeft, wRight, ...
    'VariableNames', {'T_K', 'kappa', 'asym_alignment_audit', 'halfwidth_diff_norm_audit', ...
    'asym_area_ratio_S', 'halfwidth_diff_norm_computed', 'quantile_width_asym_ratio', 'halfmax_wLeft_mA', 'halfmax_wRight_mA'});
save_run_table(asymKappaTbl, 'asymmetry_vs_kappa.csv', runDir);

[classLetter, classLine, paperSentence] = localClassify( ...
    abs(corrShape(jBest)), rmseRat(jBest), corrKappaAsymAudit, phiOddFrac);

figK = localFigurePhiVsAsymKernels(xGrid, phiEmp, candNames, candMat, runDir);
figR = localFigureResidualReconAsymmetry(temps, xGrid, Rlow, lowMask, phiEmp, kappaEmp, psiBest, aBest, candNames{jBest}, runDir);

reportLines = strings(0, 1);
reportLines(end+1) = "# Phi(x) asymmetry link report";
reportLines(end+1) = "";
reportLines(end+1) = "## Model";
reportLines(end+1) = "- `S(I,T) ~ S_peak(T)*CDF(P_T)(I) + kappa(T)*Phi(x)` with `x = (I-I_peak)/w`.";
reportLines(end+1) = "- Canonical decomposition reference run id: `" + string(cfg.canonicalDecompositionRunId) + "`.";
reportLines(end+1) = "- Replay decomposition run (this folder): `" + string(outDec.runDir) + "`.";
reportLines(end+1) = "";
reportLines(end+1) = "## Phi shape symmetry (on x-grid)";
reportLines(end+1) = sprintf("- L2 odd energy fraction ||Phi_odd||^2 / ||Phi||^2: **%.4f**", phiOddFrac);
reportLines(end+1) = "- Interpretation: near 0 => predominantly symmetric in x; near 1 => predominantly antisymmetric.";
reportLines(end+1) = "";
reportLines(end+1) = "## Correlation Phi vs asymmetric candidate kernels";
reportLines(end+1) = "```";
reportLines(end+1) = string(localTableToPlainText(cmpTbl));
reportLines(end+1) = "```";
reportLines(end+1) = "";
reportLines(end+1) = "## Amplitude link kappa(T) vs asymmetry observables (low-T mask T <= " + sprintf('%.1f', cfg.canonicalMaxTemperatureK) + " K)";
reportLines(end+1) = sprintf("- corr(kappa, asym_alignment_audit): **%.4f**", corrKappaAsymAudit);
reportLines(end+1) = sprintf("- corr(kappa, halfwidth_diff_norm audit): **%.4f**", corrKappaHalfDiff);
reportLines(end+1) = sprintf("- corr(kappa, asym_area from S): **%.4f**", corrKappaAsymArea);
reportLines(end+1) = sprintf("- corr(kappa, quantile width asym ratio): **%.4f**", corrKappaQAsym);
reportLines(end+1) = "";
reportLines(end+1) = "## Reconstruction vs kappa*Phi baseline";
reportLines(end+1) = sprintf("- Best asymmetric-kernel |corr(Phi,psi)|: **%.4f** (`%s`)", abs(corrShape(jBest)), candNames{jBest});
reportLines(end+1) = sprintf("- RMSE ratio (best psi) / kappaPhi: **%.4f**", rmseRat(jBest));
reportLines(end+1) = "";
reportLines(end+1) = "## Classification";
reportLines(end+1) = "- **" + string(classLetter) + "** — " + string(classLine);
reportLines(end+1) = "";
reportLines(end+1) = "## One-line summary";
reportLines(end+1) = "> " + string(paperSentence);
reportLines(end+1) = "";
reportLines(end+1) = "## Artifacts";
reportLines(end+1) = "- `tables/phi_asymmetry_comparison.csv`";
reportLines(end+1) = "- `tables/asymmetry_vs_kappa.csv`";
reportLines(end+1) = "- `tables/phi_asymmetry_meta.csv`";
reportLines(end+1) = "- `" + string(figK.png) + "`";
reportLines(end+1) = "- `" + string(figR.png) + "`";

reportPath = save_run_report(strjoin(reportLines, newline), 'phi_asymmetry_link_report.md', runDir);
zipPath = localBuildReviewZip(runDir, 'phi_asymmetry_link_bundle.zip');

appendText(run.notes_path, sprintf('Classification: %s\n', classLetter));
appendText(run.log_path, sprintf('Best asym kernel: %s | |corr|=%.4f | class %s\n', candNames{jBest}, abs(corrShape(jBest)), classLetter));

out = struct();
out.runDir = string(runDir);
out.classification = string(classLetter);
out.comparisonTable = cmpTbl;
out.metaTable = metaTbl;
out.corrKappaAsymAudit = corrKappaAsymAudit;
out.bestKernel = string(candNames{jBest});
out.paperSentence = string(paperSentence);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Phi asymmetry link complete ===\n');
fprintf('Classification: %s\n', classLetter);
fprintf('Report: %s\n', reportPath);
end

%% -------------------------------------------------------------------------
function cfg = applyLocalDefaults(cfg)
cfg = localSetDef(cfg, 'runLabel', 'phi_asymmetry_link');
cfg = localSetDef(cfg, 'canonicalDecompositionRunId', 'run_2026_03_24_220314_residual_decomposition');
cfg = localSetDef(cfg, 'alignmentRunId', 'run_2026_03_10_112659_alignment_audit');
cfg = localSetDef(cfg, 'fullScalingRunId', 'run_2026_03_12_234016_switching_full_scaling_collapse');
cfg = localSetDef(cfg, 'ptRunId', 'run_2026_03_24_212033_switching_barrier_distribution_from_map');
cfg = localSetDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = localSetDef(cfg, 'nXGrid', 220);
cfg = localSetDef(cfg, 'fallbackSmoothWindow', 5);
end

function cfg = localSetDef(cfg, name, val)
if ~isfield(cfg, name) || isempty(cfg.(name))
    cfg.(name) = val;
end
end

function slice = localAlignmentSlice(repoRoot, decCfg)
source.alignmentRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(decCfg.alignmentRunId));
source.fullScalingRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(decCfg.fullScalingRunId));
source.alignmentCorePath = fullfile(source.alignmentRunDir, 'switching_alignment_core_data.mat');
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', 'switching_full_scaling_parameters.csv');

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

function [asymAudit, halfAudit] = localLoadAlignmentObservables(repoRoot, alignmentRunId, tempsDec)
obsPath = fullfile(repoRoot, 'results', 'switching', 'runs', char(alignmentRunId), 'observables.csv');
asymAudit = NaN(size(tempsDec));
halfAudit = NaN(size(tempsDec));
if exist(obsPath, 'file') ~= 2
    return
end
obs = readtable(obsPath);
if ~all(ismember({'temperature', 'observable', 'value'}, obs.Properties.VariableNames))
    return
end
obs.observable = string(obs.observable);
aRows = obs(obs.observable == "asym", :);
hRows = obs(obs.observable == "halfwidth_diff_norm", :);
[ta, ia] = unique(aRows.temperature(:));
asymU = aRows.value(ia);
[th, ih] = unique(hRows.temperature(:));
halfU = hRows.value(ih);
for i = 1:numel(tempsDec)
    ti = tempsDec(i);
    [~, ja] = min(abs(ta(:) - ti));
    if isempty(ja)
        continue
    end
    if abs(ta(ja) - ti) <= 0.51
        asymAudit(i) = asymU(ja);
    end
    [~, jh] = min(abs(th(:) - ti));
    if isempty(jh)
        continue
    end
    if abs(th(jh) - ti) <= 0.51
        halfAudit(i) = halfU(jh);
    end
end
end

function [asymArea, halfDiff, qAsym, wLeft, wRight] = localAsymmetryFromS(Smap, currents, Ipeak, Speak)
nT = size(Smap, 1);
asymArea = NaN(nT, 1);
halfDiff = NaN(nT, 1);
qAsym = NaN(nT, 1);
wLeft = NaN(nT, 1);
wRight = NaN(nT, 1);
for it = 1:nT
    row = Smap(it, :);
    valid = isfinite(row);
    if ~any(valid)
        continue
    end
    c = currents(valid);
    s = row(valid);
    Ip = Ipeak(it);
    spk = Speak(it);
    if ~isfinite(Ip) || ~isfinite(spk) || spk <= eps
        continue
    end
    leftMask = c < Ip;
    rightMask = c > Ip;
    if nnz(leftMask) >= 2 && nnz(rightMask) >= 2
        al = trapz(c(leftMask), s(leftMask));
        ar = trapz(c(rightMask), s(rightMask));
        if abs(al) > eps
            asymArea(it) = ar / al;
        end
    end
    half = 0.5 * spk;
    hm = s >= half;
    if nnz(hm) >= 2
        iL = min(c(hm));
        iR = max(c(hm));
        wL = Ip - iL;
        wR = iR - Ip;
        wLeft(it) = wL;
        wRight(it) = wR;
        den = wL + wR;
        if isfinite(den) && den > eps
            halfDiff(it) = (wR - wL) / den;
        end
    end
    thr = 0.25 * spk;
    below = s < thr;
    idxPk = find(c >= Ip, 1, 'first');
    if isempty(idxPk)
        continue
    end
    iLq = NaN;
    for k = idxPk:-1:1
        if below(k)
            iLq = k;
            break
        end
    end
    iRq = NaN;
    for k = idxPk:numel(c)
        if below(k)
            iRq = k;
            break
        end
    end
    if isfinite(iLq) && isfinite(iRq) && iLq < idxPk && iRq > idxPk
        dL = Ip - c(iLq);
        dR = c(iRq) - Ip;
        if isfinite(dL) && isfinite(dR) && (dL + dR) > eps
            qAsym(it) = (dR - dL) / (dL + dR);
        end
    end
end
end

function SmeanX = localMeanSOnXGrid(Smap, currents, Ipeak, width, Speak, xGrid, lowMask)
rows = find(lowMask(:)');
if isempty(rows)
    SmeanX = NaN(1, numel(xGrid));
    return
end
acc = zeros(1, numel(xGrid));
cnt = 0;
for it = rows
    if ~isfinite(width(it)) || width(it) <= eps || ~isfinite(Ipeak(it)) || ~isfinite(Speak(it))
        continue
    end
    Ix = Ipeak(it) + xGrid(:)' .* width(it);
    row = Smap(it, :);
    sx = interp1(currents(:), row(:), Ix(:), 'linear', NaN);
    sx = sx(:)' / max(Speak(it), eps);
    if all(isfinite(sx))
        acc = acc + sx;
        cnt = cnt + 1;
    end
end
if cnt < 1
    SmeanX = NaN(1, numel(xGrid));
else
    SmeanX = acc / cnt;
end
end

function v = localAntisymPart(xg, f)
pm = interp1(xg, f(:), -xg, 'linear', NaN);
v = 0.5 * (f(:) - pm);
v(~isfinite(v)) = NaN;
end

function psi = localHalfProfileDiffKernel(xg)
% Left/right localized bump difference (skew-like deformation) on the x-grid.
psi = exp(-0.5 * ((xg + 0.25) / 0.45) .^ 2) - exp(-0.5 * ((xg - 0.25) / 0.45) .^ 2);
psi = psi(:);
end

function f = localPhiOddFraction(xg, phi)
ph = phi(:);
xm = interp1(xg, ph, -xg, 'linear', NaN);
odd = 0.5 * (ph - xm);
even = 0.5 * (ph + xm);
m = isfinite(odd) & isfinite(even);
num = sum(odd(m) .^ 2, 'omitnan');
den = sum(ph(m) .^ 2, 'omitnan');
if ~(isfinite(den) && den > eps)
    f = NaN;
else
    f = num / den;
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

function [classLetter, classLine, paperSentence] = localClassify(bestCorr, bestRmseRat, corrKappaAsym, phiOddFrac)
lineA = "Phi(x) is strongly aligned with an explicit asymmetric x-template and kappa(T) tracks asymmetry observables; treating Phi as an asymmetric switching deformation mode is quantitatively supported.";
lineB = "Phi(x) shows partial overlap with asymmetric templates or a partial kappa–asymmetry correlation, but rank-1 asymmetric reconstruction does not fully substitute for kappa*Phi.";
lineC = "Phi(x) is not well captured by simple asymmetric x-kernels tested here and kappa(T) is weakly related to asymmetry metrics; Phi should not be read primarily as a half-width or area-asymmetry mode.";

score = 0;
if bestCorr >= 0.62
    score = score + 1;
end
if bestRmseRat <= 1.28
    score = score + 1;
end
if isfinite(corrKappaAsym) && abs(corrKappaAsym) >= 0.35
    score = score + 1;
end
if isfinite(phiOddFrac) && phiOddFrac >= 0.08
    score = score + 1;
end

if score >= 3
    classLetter = 'A';
    classLine = lineA;
    paperSentence = sprintf(['Phi(x) is an asymmetric deformation mode of the switching map in this dataset: ' ...
        'best template |corr|~%.2f, asymmetric rank-1 RMSE within ~%.0f%% of kappa*Phi, and corr(kappa,asym)~%.2f.'], ...
        bestCorr, 100 * abs(bestRmseRat - 1), corrKappaAsym);
elseif score >= 2
    classLetter = 'B';
    classLine = lineB;
    paperSentence = sprintf(['Phi(x) only partially resembles the tested asymmetric deformation templates (best |corr|~%.2f); ' ...
        'use cautious language linking kappa to asymmetry (corr~%.2f).'], bestCorr, corrKappaAsym);
else
    classLetter = 'C';
    classLine = lineC;
    paperSentence = sprintf(['Phi(x) is not primarily a simple asymmetric deformation mode here (best |corr|~%.2f; corr(kappa,asym)~%.2f).'], ...
        bestCorr, corrKappaAsym);
end
end

function figPath = localFigurePhiVsAsymKernels(xGrid, phiEmp, names, candMat, runDir)
base_name = 'phi_vs_asymmetry_kernels';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 9]);
ax = axes(fig);
hold(ax, 'on');
cols = lines(7);
plot(ax, xGrid, phiEmp, '-', 'LineWidth', 2.8, 'Color', cols(1, :), 'DisplayName', '\Phi(x)');
n = size(candMat, 2);
for j = 1:min(n, 6)
    psi = localNormalizeKernel(candMat(:, j));
    plot(ax, xGrid, psi, '-', 'LineWidth', 2.0, 'Color', cols(j+1, :), 'DisplayName', char(names{j}));
end
hold(ax, 'off');
xlabel(ax, 'x = (I - I_{peak}) / w (unitless)');
ylabel(ax, 'Normalized amplitude');
grid(ax, 'on');
legend(ax, 'Location', 'best', 'Box', 'off');
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
figPath = save_run_figure(fig, base_name, runDir);
close(fig);
end

function figPath = localFigureResidualReconAsymmetry(temps, xGrid, Rlow, lowMask, phiEmp, kappaEmp, psiBest, aBest, bestName, runDir)
base_name = 'residual_reconstruction_asymmetry';
fig = create_figure('Name', base_name, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 16 9]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
Tlow = temps(lowMask);
idx = find(lowMask);
[~, iMid] = min(abs(Tlow - median(Tlow, 'omitnan')));
it = idx(iMid);

ax1 = nexttile(tl, 1);
plot(ax1, xGrid, Rlow(iMid, :), 'k-', 'LineWidth', 2.4, 'DisplayName', '\deltaS on x-grid');
hold(ax1, 'on');
plot(ax1, xGrid, kappaEmp(it) * phiEmp(:), '--', 'LineWidth', 2.0, 'DisplayName', '\kappa\Phi');
hold(ax1, 'off');
xlabel(ax1, 'x (unitless)');
ylabel(ax1, '\deltaS (P2P %)');
grid(ax1, 'on');
legend(ax1, 'Location', 'best', 'Box', 'off');
set(ax1, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, xGrid, Rlow(iMid, :), 'k-', 'LineWidth', 2.4, 'DisplayName', '\deltaS');
plot(ax2, xGrid, aBest(it) * psiBest(:), '--', 'LineWidth', 2.0, 'Color', [0.85 0.33 0.10], ...
    'DisplayName', 'a \psi_{asym}');
hold(ax2, 'off');
xlabel(ax2, 'x (unitless)');
ylabel(ax2, '\deltaS (P2P %)');
grid(ax2, 'on');
legend(ax2, 'Location', 'best', 'Box', 'off');
set(ax2, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');

ax3 = nexttile(tl, 3);
plot(ax3, temps(lowMask), kappaEmp(lowMask), 'o-', 'LineWidth', 2.0, 'DisplayName', '\kappa(T)');
xlabel(ax3, 'T (K)');
ylabel(ax3, '\kappa');
grid(ax3, 'on');
legend(ax3, 'Location', 'best', 'Box', 'off');
set(ax3, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');

ax4 = nexttile(tl, 4);
barh(ax4, abs([localSafeCorr(phiEmp, psiBest); localCosine12(phiEmp, psiBest)]));
set(ax4, 'YTickLabel', {'|corr(\Phi,\psi)|', 'cosine'});
xlabel(ax4, 'Metric');
ylabel(ax4, 'Shape match');
grid(ax4, 'on');
set(ax4, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');

figPath = save_run_figure(fig, base_name, runDir);
close(fig);
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

function txt = localTableToPlainText(T)
% Plain-text table for markdown (avoid HTML from evalc(disp(table)) in R2023b+).
rows = strings(height(T) + 1, 1);
rows(1) = strjoin(string(T.Properties.VariableNames), ' | ');
for r = 1:height(T)
    parts = strings(1, width(T));
    for c = 1:width(T)
        x = T{r, c};
        if iscell(x) && ~isempty(x)
            x = x{1};
        end
        if isnumeric(x) && isscalar(x)
            parts(c) = sprintf('%.6g', x);
        else
            parts(c) = strtrim(string(x));
        end
    end
    rows(r + 1) = strjoin(parts, ' | ');
end
txt = strjoin(rows, newline);
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
