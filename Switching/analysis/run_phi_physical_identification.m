function out = run_phi_physical_identification(cfg)
% run_phi_physical_identification
% Compare empirical residual mode Phi(x) from the switching residual decomposition
% to a small set of physically motivated candidate kernels on the same x-grid.
%
% Uses the same data pipeline as switching_residual_decomposition_analysis (via direct
% call) and recovers S_CDF as Smap - deltaS for temperature-derivative kernels.

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

runDataset = sprintf('phi_kernel_id | canon_decomp:%s', cfg.canonicalDecompositionRunId);
run = createSwitchingRunContext(repoRoot, struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

fprintf('Phi physical identification run directory:\n%s\n', runDir);

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
if exist(phiCanonPath, 'file') == 2
    phiTbl = readtable(phiCanonPath);
    xc = phiTbl.x(:);
    phic = phiTbl.Phi(:);
    phiOnGrid = interp1(xc, phic, xGrid, 'linear', NaN);
    m = isfinite(phiOnGrid) & isfinite(phiEmp);
    corrCanon = corr(phiEmp(m), phiOnGrid(m));
    fprintf('Correlation recomputed Phi vs canonical CSV Phi: %.4f\n', corrCanon);
else
    corrCanon = NaN;
    fprintf('Canonical phi_shape.csv not found at %s (skipping consistency check).\n', phiCanonPath);
end

[ScdfX, CdfX, dCdf_dI_on_x] = localScdfOnXGrid(Scdf, currents, Ipeak, width, Speak, xGrid);
dSpeak_dT = localGradient1D(temps, Speak);
dScdf_dT = localDdtSlice(ScdfX, temps);
dCdf_dT = localDdtSlice(CdfX, temps);
dIpeak_dT = localGradient1D(temps, Ipeak);
dWidth_dT = localGradient1D(temps, width);

psi_Tresp = localNormalizeKernel(localAggregateLowT(dScdf_dT, lowMask));
psi_cdf_T = localNormalizeKernel(localAggregateLowT(dCdf_dT, lowMask));
psi_cdf_x = localNormalizeKernel(localAggregateLowT(dCdf_dI_on_x .* width, lowMask));
psi_shift_geom = localNormalizeKernel(localAggregateLowT(-dCdf_dI_on_x .* dIpeak_dT, lowMask));
psi_width_geom = localNormalizeKernel(localAggregateLowT(-dCdf_dI_on_x .* (xGrid(:)' .* dWidth_dT), lowMask));
cdf_mean_profile = localNormalizeKernel(mean(CdfX(lowMask, :), 1, 'omitnan'));

candNames = {
    'dScdf_dT_median_lowT'
    'dCDF_dT_median_lowT'
    'dCDF_dx_chainrule_median_lowT'
    'shift_geom_dIp_peak_dCDF_dI'
    'width_geom_x_dWidth_dCDF_dI'
    'mean_CDF_x_profile_lowT'
    };

candMat = [psi_Tresp(:), psi_cdf_T(:), psi_cdf_x(:), psi_shift_geom(:), psi_width_geom(:), cdf_mean_profile(:)];

nC = size(candMat, 2);
corrShape = NaN(nC, 1);
cos12 = NaN(nC, 1);
rmseRat = NaN(nC, 1);
relFrobRat = NaN(nC, 1);
medCorrRat = NaN(nC, 1);
corr_a_kappa = NaN(nC, 1);
corr_a_dSpeak = NaN(nC, 1);

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
    corr_a_dSpeak(j) = corr(aj(lowMask), dSpeak_dT(lowMask), 'rows', 'pairwise');
end

cmpTbl = table( ...
    candNames(:), corrShape, cos12, rmseRat, relFrobRat, medCorrRat, corr_a_kappa, corr_a_dSpeak, ...
    'VariableNames', {'candidate_kernel', 'corr_Phi_psi', 'cosine_Phi_psi', ...
    'rmse_ratio_to_kappaPhi', 'rel_frob_ratio_to_kappaPhi', 'median_corr_ratio_to_kappaPhi', ...
    'corr_aT_kappaEmp_lowT', 'corr_aT_dSpeak_dT_lowT'});

absCorr = abs(corrShape);
absCorr(~isfinite(absCorr)) = -Inf;
[~, jBest] = max(absCorr);
if ~isfinite(absCorr(jBest))
    jBest = 1;
end
bestName = candNames{jBest};

reconRows = (1:numel(temps))';
recTbl = table( ...
    reconRows, temps, kappaEmp, localFitKappaRows(Rall, psi_Tresp), localFitKappaRows(Rall, psi_cdf_T), ...
    localFitKappaRows(Rall, psi_shift_geom), dSpeak_dT, ...
    'VariableNames', {'row_index', 'T_K', 'kappa_empirical', 'a_dScdf_dT', 'a_dCDF_dT', ...
    'a_shift_geom', 'dSpeak_dT'});

cmpPath = save_run_table(cmpTbl, 'phi_candidate_kernel_comparison.csv', runDir);
recPath = save_run_table(recTbl, 'phi_reconstruction_comparison.csv', runDir);

metaTbl = table( ...
    string(cfg.canonicalDecompositionRunId), string(outDec.runDir), corrCanon, ...
    string(bestName), abs(corrShape(jBest)), rmseRat(jBest), relFrobRat(jBest), ...
    'VariableNames', {'canonical_phi_source_run', 'replay_decomposition_run', ...
    'corr_recomputed_phi_to_canonical_csv', 'best_candidate_by_abs_corr', ...
    'best_abs_corr_shape', 'best_rmse_ratio', 'best_rel_frob_ratio'});
save_run_table(metaTbl, 'phi_identification_meta.csv', runDir);

figCmp = localFigurePhiVsCandidates(xGrid, phiEmp, candNames, candMat, runDir);
figRecon = localFigureReconCompare(temps, xGrid, Rlow, lowMask, phiEmp, kappaEmp, ...
    localNormalizeKernel(candMat(:, jBest)), localFitKappaRows(Rall, localNormalizeKernel(candMat(:, jBest))), ...
    bestName, runDir);

[statusLetter, statusLine, paperSentence] = localVerdict(cmpTbl, jBest, corrCanon);

reportLines = strings(0, 1);
reportLines(end+1) = "# Phi(x) physical identification report";
reportLines(end+1) = "";
reportLines(end+1) = "## Scope";
reportLines(end+1) = "- Model context: `S(I,T) ~ S_peak(T)*CDF + kappa(T)*Phi(x)` with `x = (I-I_peak)/w`.";
reportLines(end+1) = "- Canonical Phi source run (reference): `" + string(cfg.canonicalDecompositionRunId) + "`.";
reportLines(end+1) = "- Replay decomposition run (this folder): `" + string(outDec.runDir) + "`.";
reportLines(end+1) = "- Corr(recomputed Phi, canonical CSV Phi): `" + sprintf('%.4f', corrCanon) + "`.";
reportLines(end+1) = "";
reportLines(end+1) = "## Candidate kernels (motivation)";
reportLines(end+1) = "1. **dScdf_dT** — temperature response of the full PT-backed CDF sector (includes dS_peak/dT and dCDF/dT).";
reportLines(end+1) = "2. **dCDF_dT** — temperature response of the normalized CDF at fixed amplitude factor (barrier distribution evolution).";
reportLines(end+1) = "3. **dCDF/dx** via chain rule `(dCDF/dI)*w` — slope of the CDF in normalized current units (edge/shift sensitivity).";
reportLines(end+1) = "4. **Shift geometric** — `-dCDF/dI * dI_peak/dT` (first-order shift of the CDF with moving peak).";
reportLines(end+1) = "5. **Width geometric** — `-dCDF/dI * x * d(width)/dT` (first-order width scaling in x).";
reportLines(end+1) = "6. **Mean CDF profile** — average normalized CDF in x over low T (amplitude-response template for the CDF sector).";
reportLines(end+1) = "";
reportLines(end+1) = "## Prior context (not re-run here)";
reportLines(end+1) = "- Dynamic shape mode / a1(T) geometry analyses: see `Switching/analysis/switching_dynamic_shape_geometry_match_analysis.m` and run `run_2026_03_14_161801_switching_dynamic_shape_mode`.";
reportLines(end+1) = "- Residual sector robustness / Phi stability: see `Switching/analysis/run_residual_sector_robustness.m` and related switching RSR runs.";
reportLines(end+1) = "";
reportLines(end+1) = "## Summary metrics";
reportLines(end+1) = localTableToMarkdown(cmpTbl);
reportLines(end+1) = "";
reportLines(end+1) = "_Note: the shift kernel uses `-dCDF/dI * dI_{peak}/dT`; if `I_{peak}` is nearly flat in T in the canonical window, that template collapses and metrics become NaN (not a numerical failure)._";
reportLines(end+1) = "";
reportLines(end+1) = "## Interpretation status";
reportLines(end+1) = "- **Status: " + string(statusLetter) + "** — " + string(statusLine);
reportLines(end+1) = "";
reportLines(end+1) = "## Paper-ready sentence";
reportLines(end+1) = "> " + string(paperSentence);
reportLines(end+1) = "";
reportLines(end+1) = "## Artifacts";
reportLines(end+1) = "- `" + string(cmpPath) + "`";
reportLines(end+1) = "- `" + string(recPath) + "`";
reportLines(end+1) = "- `" + string(figCmp.png) + "`";
reportLines(end+1) = "- `" + string(figRecon.png) + "`";

reportPath = save_run_report(strjoin(reportLines, newline), 'phi_physical_identification_report.md', runDir);

zipPath = localBuildReviewZip(runDir, 'phi_physical_identification_bundle.zip');

appendText(run.notes_path, sprintf('Interpretation status: %s\n', statusLetter));
appendText(run.log_path, sprintf('Best candidate: %s | status %s\n', bestName, statusLetter));

out = struct();
out.runDir = string(runDir);
out.canonicalPhiSourceRun = string(cfg.canonicalDecompositionRunId);
out.comparisonTable = cmpTbl;
out.bestCandidate = string(bestName);
out.status = string(statusLetter);
out.paperSentence = string(paperSentence);
out.figurePhiVsCandidates = figCmp;
out.figureReconstruction = figRecon;
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);

fprintf('\n=== Phi physical identification complete ===\n');
fprintf('Status: %s\n', statusLetter);
fprintf('Best candidate: %s\n', bestName);
fprintf('Report: %s\n', reportPath);
end

%% -------------------------------------------------------------------------
function cfg = applyLocalDefaults(cfg)
cfg = localSetDef(cfg, 'runLabel', 'phi_physical_identification');
cfg = localSetDef(cfg, 'canonicalDecompositionRunId', ...
    'run_2026_03_24_220314_residual_decomposition');
cfg = localSetDef(cfg, 'canonicalPhiShapePath', '');
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

function figPath = localFigurePhiVsCandidates(xGrid, phiEmp, names, candMat, runDir)
baseName = 'phi_vs_candidate_kernels';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 11]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
cols = lines(4);
n = size(candMat, 2);

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, xGrid, phiEmp, '-', 'LineWidth', 2.6, 'Color', cols(1, :), 'DisplayName', '\Phi_{emp}(x)');
for j = 1:min(3, n)
    psi = localNormalizeKernel(candMat(:, j));
    plot(ax1, xGrid, psi, '-', 'LineWidth', 2.0, 'Color', cols(j+1, :), 'DisplayName', char(names{j}));
end
hold(ax1, 'off');
xlabel(ax1, 'x = (I - I_{peak}) / w');
ylabel(ax1, 'Normalized kernel');
title(ax1, '\Phi(x) vs candidates 1–3');
legend(ax1, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax1);

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, xGrid, phiEmp, '-', 'LineWidth', 2.6, 'Color', cols(1, :), 'DisplayName', '\Phi_{emp}(x)');
for j = 4:n
    psi = localNormalizeKernel(candMat(:, j));
    plot(ax2, xGrid, psi, '-', 'LineWidth', 2.0, 'Color', cols(min(j-2, 4), :), 'DisplayName', char(names{j}));
end
hold(ax2, 'off');
xlabel(ax2, 'x = (I - I_{peak}) / w');
ylabel(ax2, 'Normalized kernel');
title(ax2, '\Phi(x) vs candidates 4–6');
legend(ax2, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax2);

figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function figPath = localFigureReconCompare(temps, xGrid, Rlow, lowMask, phiEmp, kappaEmp, psiBest, aBest, bestName, runDir)
baseName = 'residual_reconstruction_candidate_comparison';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 16 9]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
Tlow = temps(lowMask);
idx = find(lowMask);
if isempty(idx)
    error('lowMask empty');
end
[~, iMid] = min(abs(Tlow - median(Tlow, 'omitnan')));
it = idx(iMid);

ax1 = nexttile(tl, 1);
plot(ax1, xGrid, Rlow(iMid, :), 'k-', 'LineWidth', 2.4, 'DisplayName', '\deltaS');
hold(ax1, 'on');
plot(ax1, xGrid, kappaEmp(it) * phiEmp(:), '--', 'LineWidth', 2.0, 'DisplayName', '\kappa\Phi');
hold(ax1, 'off');
xlabel(ax1, 'x');
ylabel(ax1, '\deltaS (P2P %)');
title(ax1, sprintf('Single-T slice T = %.1f K', temps(it)));
legend(ax1, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax1);

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, xGrid, Rlow(iMid, :), 'k-', 'LineWidth', 2.4, 'DisplayName', '\deltaS');
plot(ax2, xGrid, aBest(it) * psiBest(:), '--', 'LineWidth', 2.0, 'Color', [0.85 0.33 0.10], ...
    'DisplayName', ['a \psi (' char(bestName) ')']);
hold(ax2, 'off');
xlabel(ax2, 'x');
ylabel(ax2, '\deltaS (P2P %)');
title(ax2, 'Best candidate vs data (same T)');
legend(ax2, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax2);

ax3 = nexttile(tl, 3);
plot(ax3, temps(lowMask), kappaEmp(lowMask), 'o-', 'LineWidth', 2.0, 'DisplayName', '\kappa(T)');
hold(ax3, 'on');
plot(ax3, temps(lowMask), aBest(lowMask), 's-', 'LineWidth', 2.0, 'DisplayName', 'a(T) candidate');
hold(ax3, 'off');
xlabel(ax3, 'T (K)');
ylabel(ax3, 'Amplitude');
title(ax3, 'Low-T amplitudes');
legend(ax3, 'Location', 'best', 'Box', 'off');
localStyleAxes(ax3);

ax4 = nexttile(tl, 4);
barh(ax4, abs([localSafeCorr(phiEmp, psiBest); localCosine12(phiEmp, psiBest)]));
set(ax4, 'YTickLabel', {'|corr|', 'cosine'});
xlabel(ax4, 'Metric value');
ylabel(ax4, 'Shape metric');
title(ax4, 'Shape match (best candidate)');
localStyleAxes(ax4);

figPath = save_run_figure(fig, baseName, runDir);
close(fig);
end

function localStyleAxes(ax)
set(ax, 'FontSize', 14, 'LineWidth', 1.0, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
end

function [statusLetter, statusLine, paperSentence] = localVerdict(cmpTbl, jBest, corrCanon)
bestCorr = abs(cmpTbl.corr_Phi_psi(jBest));
bestRmseR = cmpTbl.rmse_ratio_to_kappaPhi(jBest);
bestCos = cmpTbl.cosine_Phi_psi(jBest);

lineA = "Phi(x) aligns closely with a temperature-response / CDF-sector kernel; rank-1 residual reconstruction is nearly as good as kappa*Phi.";
lineB = "Phi(x) shares partial geometric structure with CDF-sector temperature derivatives and shift-width kernels, but no single kernel matches at full rank-1 quality.";
lineC = "Phi(x) is not well represented by the tested CDF-sector temperature-response or local geometric kernels; it remains an empirical dominant mode.";

if bestCorr >= 0.82 && bestRmseR <= 1.18 && bestCos >= 0.88
    statusLetter = 'A';
    statusLine = lineA;
    paperSentence = sprintf(['The empirical residual mode \\Phi(x) is quantitatively consistent (|corr| \\approx %.2f, reconstruction RMSE within %.0f%% of the \\kappa\\Phi baseline) ', ...
        'with a temperature-derived kernel built from the PT-backed CDF sector, supporting a physical interpretation as a CDF-sector temperature response rather than a purely abstract SVD shape.'], ...
        bestCorr, 100 * (bestRmseR - 1));
elseif bestCorr >= 0.55 && bestRmseR <= 1.45
    statusLetter = 'B';
    statusLine = lineB;
    paperSentence = sprintf(['The dominant residual shape \\Phi(x) is only partially aligned (|corr| \\approx %.2f) with explicit CDF-sector temperature-derivative and shift/width kernels, ', ...
        'so a physical reading is plausible but not yet sharp enough to replace the empirical mode language.'], bestCorr);
else
    statusLetter = 'C';
    statusLine = lineC;
    paperSentence = sprintf(['Within tested CDF-sector temperature-response and local geometric constructions, no kernel matched the empirical \\Phi(x) (best |corr| \\approx %.2f), ', ...
        'so \\Phi(x) should still be treated as the leading empirical residual mode pending a sharper mechanistic map.'], bestCorr);
end

if isfinite(corrCanon) && corrCanon < 0.97
    statusLetter = 'B';
    statusLine = statusLine + " (Replay Phi drifted vs canonical CSV; interpret metrics cautiously.)";
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
