function out = run_pt_deformation_mode_test(cfg)
% run_pt_deformation_mode_test
% Test whether empirical Phi(x) can arise from a functional deformation deltaP(I) of P_T:
%   S_CDF = S_peak * CDF(P_T);  P_T^eps = normalize(max(P_T + eps*deltaP,0));
%   deltaS ~ (S_peak*CDF(P_T^eps) - S_CDF) / eps  (linearized response)
% Map deltaS to x = (I-I_peak)/w, SVD over T (canonical low-T window), compare leading psi to Phi.
%
% Reads-only: decomposition tables, PT_matrix, alignment map, scaling parameters.
% Writes: new switching run folder (tables, figures, reports, review zip).

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

analysisDir = fileparts(mfilename('fullpath'));
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

cfg = localApplyDefaults(cfg);

decTablesDir = localResolveDecompositionTablesDir(repoRoot, cfg.decompositionRunId);
phiPath = fullfile(decTablesDir, 'phi_shape.csv');
kappaPath = fullfile(decTablesDir, 'kappa_vs_T.csv');
srcPath = fullfile(decTablesDir, 'residual_decomposition_sources.csv');

assert(exist(phiPath, 'file') == 2, 'Missing phi_shape.csv: %s', phiPath);
assert(exist(kappaPath, 'file') == 2, 'Missing kappa_vs_T.csv: %s', kappaPath);

phiTbl = readtable(phiPath);
xGrid = double(phiTbl.x(:));
phiEmp = double(phiTbl.Phi(:));

kappaTbl = readtable(kappaPath);
kn = string(kappaTbl.Properties.VariableNames);
kappaTcol = localNumericColumn(kappaTbl, kn, ["T", "T_K"]);
kappaVals = double(kappaTbl.kappa(:));

runDataset = sprintf('pt_deformation_mode_test | decomp:%s', cfg.decompositionRunId);
run = createRunContext('switching', struct('runLabel', cfg.runLabel, 'dataset', runDataset));
runDir = run.run_dir;

fprintf('PT deformation mode test run directory:\n%s\n', runDir);
fprintf('Decomposition source run: %s\n', char(cfg.decompositionRunId));

appendText(run.log_path, sprintf('[%s] run_pt_deformation_mode_test started\n', localStampNow()));
appendText(run.log_path, sprintf('decomposition_run: %s\n', char(cfg.decompositionRunId)));

[ptPath, alignId, scaleId] = localResolvePathsFromSourcesOrCfg(repoRoot, srcPath, cfg);
appendText(run.log_path, sprintf('PT_matrix: %s\n', char(ptPath)));
appendText(run.log_path, sprintf('alignment_run: %s | scaling_run: %s\n', char(alignId), char(scaleId)));

slice = localLoadAlignmentScalingSlice(repoRoot, alignId, scaleId, ptPath);
Smap = slice.Smap;
temps = slice.temps;
currents = slice.currents;
Ipeak = slice.Ipeak;
Speak = slice.Speak;
width = slice.width;
ptData = slice.ptData;

[Scdf, cdfMeta] = localBuildScdfMatrix(Smap, currents, temps, Speak, ptData, cfg.fallbackSmoothWindow);
assert(cdfMeta.ptRowsUsed == numel(temps), ...
    'This test requires all temperatures to use PT-backed CDF (got %d/%d PT rows).', ...
    cdfMeta.ptRowsUsed, numel(temps));

lowMask = temps <= cfg.canonicalMaxTemperatureK;
assert(nnz(lowMask) >= cfg.minRowsSvd, 'Canonical window has too few rows for SVD.');

Xrows = NaN(numel(temps), numel(currents));
for it = 1:numel(temps)
    Xrows(it, :) = (currents(:)' - Ipeak(it)) ./ width(it);
end

currPT = ptData.currents(:);
bases = localBuildDeformationBases(currPT, ptData.PT, cfg);

nB = numel(bases);
corrPearson = NaN(nB, 1);
cosSim = NaN(nB, 1);
rmseKappaPhi = NaN(nB, 1);
rmseRank1 = NaN(nB, 1);
rmseRatio = NaN(nB, 1);
sigma1 = NaN(nB, 1);
sigma2 = NaN(nB, 1);
rank1Frac = NaN(nB, 1);
basisIds = strings(nB, 1);

bestPsiCell = cell(nB, 1);
svCell = cell(nB, 1);

for bi = 1:nB
    b = bases(bi);
    basisIds(bi) = b.id;
    dI = localInterpBasisToCurrents(currPT, b.vec, currents);
    dI = localUnitL2OnGrid(currents, dI);

    R_I = localLinearizedDeltaS(ptData, temps, currents, Speak, Scdf, dI, cfg.finiteDiffEpsilon);

    Rx = localInterpolateRowsToGrid(Xrows(lowMask, :), R_I(lowMask, :), xGrid);

    [psi, sv, s1f] = localLeadingModeFromResidual(Rx);
    ms = isfinite(psi) & isfinite(phiEmp);
    if nnz(ms) >= 1 && dot(psi(ms), phiEmp(ms)) < 0
        psi = -psi;
    end
    bestPsiCell{bi} = psi;
    svCell{bi} = sv;

    m = isfinite(psi) & isfinite(phiEmp);
    if nnz(m) >= 3
        corrPearson(bi) = corr(phiEmp(m), psi(m), 'Rows', 'complete');
    else
        corrPearson(bi) = NaN;
    end
    cosSim(bi) = localCosine(phiEmp(m), psi(m));

    kLow = localLookupKappaAtT(kappaTcol, kappaVals, temps(lowMask));
    RhatK = kLow .* phiEmp';
    rmseKappaPhi(bi) = localRmse(Rx, RhatK);

    aOpt = localFitKappaPerRow(Rx, psi);
    Rhat1 = aOpt .* psi';
    rmseRank1(bi) = localRmse(Rx, Rhat1);

    rmseRatio(bi) = rmseKappaPhi(bi) / max(rmseRank1(bi), eps);
    if ~isempty(sv)
        sigma1(bi) = sv(1);
        if numel(sv) >= 2
            sigma2(bi) = sv(2);
        end
        rank1Frac(bi) = s1f;
    end
end

[bestCorr, ixBest] = max(corrPearson, [], 'omitnan');
if isnan(bestCorr)
    ixBest = 1;
    bestCorr = corrPearson(ixBest);
end
bestId = basisIds(ixBest);
bestRatio = rmseRatio(ixBest);

verdict = "NOT_SUPPORTED";
verdictLine = sprintf(['Best Pearson = %.4f (need >= %.2f) | best RMSE ratio = %.4g ' ...
    '(need <= %.2f).'], bestCorr, cfg.corrThreshold, bestRatio, cfg.rmseRatioThreshold);
if bestCorr >= cfg.corrThreshold && bestRatio <= cfg.rmseRatioThreshold
    verdict = "SUPPORTED";
    verdictLine = sprintf('Best basis "%s": Pearson = %.4f, RMSE ratio = %.4g.', ...
        bestId, bestCorr, bestRatio);
end

corrTbl = table(basisIds, corrPearson, cosSim, rmseKappaPhi, rmseRank1, rmseRatio, ...
    sigma1, sigma2, rank1Frac, ...
    'VariableNames', {'basis_id', 'pearson_psi_phi', 'cosine_psi_phi', ...
    'rmse_kappa_phi', 'rmse_rank1_psi', 'rmse_ratio_kappaPhi_over_rank1', ...
    'sigma1', 'sigma2', 'rank1_energy_fraction'});
save_run_table(corrTbl, 'pt_deformation_mode_correlation.csv', runDir);

bestRow = table(string(bestId), bestCorr, bestRatio, ...
    'VariableNames', {'best_basis_id', 'best_pearson_psi_phi', 'best_rmse_ratio'});
reconTbl = table(basisIds, rmseKappaPhi, rmseRank1, rmseRatio, rank1Frac, ...
    'VariableNames', {'basis_id', 'rmse_kappa_phi_reconstruction', 'rmse_optimal_rank1', ...
    'rmse_ratio', 'rank1_energy_fraction'});
save_run_table(reconTbl, 'pt_deformation_reconstruction_metrics.csv', runDir);
save_run_table(bestRow, 'pt_deformation_best_basis.csv', runDir);

psiBest = bestPsiCell{ixBest};
dIBest = localInterpBasisToCurrents(currPT, bases(ixBest).vec, currents);
dIBest = localUnitL2OnGrid(currents, dIBest);
R_I_best = localLinearizedDeltaS(ptData, temps, currents, Speak, Scdf, dIBest, cfg.finiteDiffEpsilon);
Rx_best = localInterpolateRowsToGrid(Xrows(lowMask, :), R_I_best(lowMask, :), xGrid);
kLow = localLookupKappaAtT(kappaTcol, kappaVals, temps(lowMask));
aBest = localFitKappaPerRow(Rx_best, psiBest);
tempsLow = temps(lowMask);

localFigPhiVsBest(xGrid, phiEmp, psiBest, runDir);
localFigReconCompare(xGrid, Rx_best, phiEmp, psiBest, kLow, aBest, tempsLow, runDir);
localFigSingularValues(svCell{ixBest}, runDir);

reportLines = localBuildReport(cfg, decTablesDir, ptPath, alignId, scaleId, cdfMeta, ...
    corrTbl, verdict, verdictLine, bestId, bestCorr, bestRatio);
reportPath = save_run_report(strjoin(reportLines, newline), 'pt_deformation_test_report.md', runDir);

zipPath = localBuildReviewZip(runDir, 'pt_deformation_bundle.zip');

appendText(run.notes_path, sprintf('Verdict: %s\n', verdict));
appendText(run.log_path, sprintf('[%s] complete | report: %s\n', localStampNow(), char(reportPath)));

out = struct();
out.runDir = string(runDir);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
out.verdict = verdict;
out.bestCorrelation = bestCorr;
out.bestRmseRatio = bestRatio;
out.bestBasisId = bestId;

fprintf('\n=== PT deformation mode test complete ===\n');
fprintf('VERDICT: %s\n', upper(char(strrep(verdict, '_', ' '))));
fprintf('Best correlation (Pearson psi vs Phi): %.4f\n', bestCorr);
fprintf('Best RMSE ratio (kappa*Phi vs rank-1): %.4g\n', bestRatio);
fprintf('Best deltaP mode: %s\n', char(bestId));
fprintf('Report: %s\n', char(reportPath));
end

%% -------------------------------------------------------------------------
function cfg = localApplyDefaults(cfg)
cfg = localSetDef(cfg, 'runLabel', 'pt_deformation_mode_test');
cfg = localSetDef(cfg, 'decompositionRunId', 'run_2026_03_24_220314_residual_decomposition');
cfg = localSetDef(cfg, 'alignmentRunId', '');
cfg = localSetDef(cfg, 'fullScalingRunId', '');
cfg = localSetDef(cfg, 'ptMatrixPath', '');
cfg = localSetDef(cfg, 'fallbackSmoothWindow', 5);
cfg = localSetDef(cfg, 'canonicalMaxTemperatureK', 30);
cfg = localSetDef(cfg, 'minRowsSvd', 5);
cfg = localSetDef(cfg, 'finiteDiffEpsilon', 1e-4);
cfg = localSetDef(cfg, 'corrThreshold', 0.8);
cfg = localSetDef(cfg, 'rmseRatioThreshold', 2.0);
cfg = localSetDef(cfg, 'nPcaModes', 5);
cfg = localSetDef(cfg, 'speakFloorFraction', 1e-3);
end

function cfg = localSetDef(cfg, f, v)
if ~isfield(cfg, f) || isempty(cfg.(f))
    cfg.(f) = v;
end
end

function decDir = localResolveDecompositionTablesDir(repoRoot, runId)
rid = char(string(runId));
candidates = {
    fullfile(repoRoot, 'results', 'switching', 'runs', rid, 'tables')
    fullfile(repoRoot, 'results', 'switching', 'runs', ['_extract_' rid], rid, 'tables')
    };
decDir = '';
for i = 1:numel(candidates)
    p = fullfile(candidates{i}, 'phi_shape.csv');
    if exist(p, 'file') == 2
        decDir = candidates{i};
        return
    end
end
error('Decomposition tables not found for run %s (tried standard and _extract_ layouts).', rid);
end

function [ptPath, alignId, scaleId] = localResolvePathsFromSourcesOrCfg(repoRoot, srcPath, cfg)
alignId = string(cfg.alignmentRunId);
scaleId = string(cfg.fullScalingRunId);
ptPath = string(cfg.ptMatrixPath);

if exist(srcPath, 'file') == 2
    st = readtable(srcPath);
    vn = st.Properties.VariableNames;
    roleCol = localPickVar(vn, {'source_role', 'SourceRole'});
    fileCol = localPickVar(vn, {'source_file', 'SourceFile'});
    if ~isempty(roleCol) && ~isempty(fileCol)
        roles = string(st.(roleCol));
        for i = 1:height(st)
            if roles(i) == "alignment_core_map" && strlength(alignId) == 0
                p = char(st.(fileCol)(i));
                alignId = string(localRunIdFromPath(p));
            elseif roles(i) == "full_scaling_parameters" && strlength(scaleId) == 0
                p = char(st.(fileCol)(i));
                scaleId = string(localRunIdFromPath(p));
            elseif roles(i) == "pt_matrix" && strlength(ptPath) == 0
                ptPath = string(char(st.(fileCol)(i)));
            end
        end
    end
end

if strlength(alignId) == 0
    alignId = "run_2026_03_10_112659_alignment_audit";
end
if strlength(scaleId) == 0
    scaleId = "run_2026_03_12_234016_switching_full_scaling_collapse";
end
if strlength(ptPath) == 0
    ptPath = string(fullfile(repoRoot, 'results', 'switching', 'runs', ...
        'run_2026_03_24_212033_switching_barrier_distribution_from_map', 'tables', 'PT_matrix.csv'));
end

assert(exist(char(ptPath), 'file') == 2, 'PT_matrix.csv not found: %s', char(ptPath));
end

function col = localPickVar(varNames, candidates)
col = '';
for k = 1:numel(candidates)
    if any(strcmp(varNames, candidates{k}))
        col = candidates{k};
        return
    end
end
end

function id = localRunIdFromPath(p)
parts = split(string(p), filesep);
idx = find(parts == "runs", 1, 'last');
if isempty(idx) || idx >= numel(parts)
    id = "";
    return
end
id = parts(idx + 1);
end

function slice = localLoadAlignmentScalingSlice(repoRoot, alignId, scaleId, ptPath)
source.alignmentRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(alignId));
source.fullScalingRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', char(scaleId));
source.alignmentCorePath = fullfile(source.alignmentRunDir, 'switching_alignment_core_data.mat');
source.fullScalingParamsPath = fullfile(source.fullScalingRunDir, 'tables', 'switching_full_scaling_parameters.csv');

assert(exist(source.alignmentCorePath, 'file') == 2, 'Missing %s', source.alignmentCorePath);
assert(exist(source.fullScalingParamsPath, 'file') == 2, 'Missing %s', source.fullScalingParamsPath);

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
slice.ptData = localLoadPTData(char(ptPath));
end

function kOut = localLookupKappaAtT(Tref, kappaVals, Tq)
kOut = NaN(size(Tq));
for i = 1:numel(Tq)
    d = abs(Tref(:) - Tq(i));
    [md, ix] = min(d, [], 'omitnan');
    if isfinite(md) && md < 0.51
        kOut(i) = kappaVals(ix);
    end
end
end

function bases = localBuildDeformationBases(currPT, PT, cfg)
currPT = currPT(:);
n = numel(currPT);
bases = struct('id', {}, 'vec', {});

I0 = (currPT - mean(currPT, 'omitnan')) ./ (std(currPT, 'omitnan') + eps);
M = [ones(n, 1), I0, I0.^2, I0.^3];
[Q, ~] = qr(M, 0);
for k = 1:size(Q, 2)
    v = localNormalizeDensityShape(currPT, Q(:, k));
    bases(end + 1) = struct('id', sprintf('poly_q%d', k), 'vec', v); %#ok<AGROW>
end

Imin = min(currPT);
Imax = max(currPT);
span = Imax - Imin + eps;
sigW = 0.14 * span;
mus = [Imin + 0.15 * span; mean([Imin, Imax]); Imax - 0.15 * span];
for k = 1:numel(mus)
    v = exp(-0.5 * ((currPT - mus(k)) / sigW) .^ 2);
    v = localNormalizeDensityShape(currPT, v);
    bases(end + 1) = struct('id', sprintf('gauss_mu%d', k), 'vec', v); %#ok<AGROW>
end

sigN = 0.035 * span;
for k = 1:numel(mus)
    v = exp(-0.5 * ((currPT - mus(k)) / sigN) .^ 2);
    v = localNormalizeDensityShape(currPT, v);
    bases(end + 1) = struct('id', sprintf('narrow_gauss_mu%d', k), 'vec', v); %#ok<AGROW>
end

for k = 1:numel(mus)
    v = localHatBump(currPT, mus(k), 0.08 * span);
    v = localNormalizeDensityShape(currPT, v);
    bases(end + 1) = struct('id', sprintf('spline_hat_mu%d', k), 'vec', v); %#ok<AGROW>
end

vL = localHatBump(currPT, Imin + 0.05 * span, 0.06 * span);
vR = localHatBump(currPT, Imax - 0.05 * span, 0.06 * span);
bases(end + 1) = struct('id', 'local_left', 'vec', localNormalizeDensityShape(currPT, vL)); %#ok<AGROW>
bases(end + 1) = struct('id', 'local_right', 'vec', localNormalizeDensityShape(currPT, vR)); %#ok<AGROW>

if size(PT, 1) >= 3 && size(PT, 2) == n
    Pc = PT - mean(PT, 1, 'omitnan');
    [~, ~, V] = svd(Pc, 'econ');
    nk = min(cfg.nPcaModes, size(V, 2));
    for k = 1:nk
        v = localNormalizeDensityShape(currPT, V(:, k));
        bases(end + 1) = struct('id', sprintf('pca_mode_%d', k), 'vec', v); %#ok<AGROW>
    end
end
end

function v = localHatBump(Ic, mu, halfw)
v = max(0, 1 - abs(Ic - mu) / max(halfw, eps));
end

function v = localNormalizeDensityShape(currPT, v)
v = double(v(:));
m = isfinite(v) & isfinite(currPT);
if nnz(m) < 2
    return
end
v = v - mean(v(m));
nv = sqrt(trapz(currPT(m), v(m) .^ 2));
if nv > eps
    v = v / nv;
end
end

function dI = localInterpBasisToCurrents(currPT, vec, currents)
dI = interp1(currPT(:), vec(:), currents(:), 'linear', 0);
dI = double(dI(:));
end

function v = localUnitL2OnGrid(currents, v)
m = isfinite(v) & isfinite(currents);
if nnz(m) < 2
    return
end
nv = sqrt(trapz(currents(m), v(m) .^ 2));
if nv > eps
    v = v / nv;
end
end

function R_I = localLinearizedDeltaS(ptData, temps, currents, Speak, Scdf, dOnCurr, eps0)
nT = numel(temps);
nI = numel(currents);
R_I = NaN(nT, nI);
for it = 1:nT
    p0 = localNormDensityOnCurrents(ptData, temps(it), currents);
    if isempty(p0)
        continue
    end
    p1 = max(p0(:) + eps0 * dOnCurr(:), 0);
    a = trapz(currents, p1);
    if ~(isfinite(a) && a > 0)
        continue
    end
    p1 = p1 / a;
    cdf1 = cumtrapz(currents, p1);
    if cdf1(end) <= 0
        continue
    end
    cdf1 = cdf1 / cdf1(end);
    cdf1 = min(max(cdf1, 0), 1);
    S1 = Speak(it) .* cdf1(:).';
    R_I(it, :) = (S1 - Scdf(it, :)) / eps0;
end
end

function pOn = localNormDensityOnCurrents(ptData, targetT, currents)
cdfRow = []; %#ok<NASGU>
tempsPT = ptData.temps(:);
currPT = ptData.currents(:);
PT = ptData.PT;
if numel(tempsPT) < 2 || size(PT, 2) ~= numel(currPT)
    pOn = [];
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
    pOn = [];
    return
end
pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);
areaPT = trapz(currPT, pAtT);
if ~(isfinite(areaPT) && areaPT > 0)
    pOn = [];
    return
end
pAtT = pAtT ./ areaPT;
pOn = interp1(currPT, pAtT, currents(:), 'linear', 0);
pOn = max(pOn, 0);
area = trapz(currents, pOn);
if ~(isfinite(area) && area > 0)
    pOn = [];
    return
end
pOn = (pOn / area);
pOn = pOn(:);
end

function [Scdf, meta] = localBuildScdfMatrix(Smap, currents, temps, Speak, ptData, fallbackSmoothWindow)
nT = numel(temps);
nI = numel(currents);
Scdf = NaN(nT, nI);
ptRows = 0;
fbRows = 0;
for it = 1:nT
    cdfRow = [];
    if ptData.available
        cdfRow = localCdfFromPT(ptData, temps(it), currents);
    end
    if isempty(cdfRow)
        cdfRow = localCdfFallbackFromRow(Smap(it, :), currents, fallbackSmoothWindow);
        fbRows = fbRows + 1;
    else
        ptRows = ptRows + 1;
    end
    Scdf(it, :) = Speak(it) .* cdfRow(:).';
end
meta = struct('ptRowsUsed', ptRows, 'fallbackRowsUsed', fbRows);
end

function cdfRow = localCdfFromPT(ptData, targetT, currents)
pOn = localNormDensityOnCurrents(ptData, targetT, currents);
if isempty(pOn)
    cdfRow = [];
    return
end
cdfRow = cumtrapz(currents, pOn);
if cdfRow(end) <= 0
    cdfRow = [];
    return
end
cdfRow = cdfRow ./ cdfRow(end);
cdfRow = min(max(cdfRow, 0), 1);
end

function cdfRow = localCdfFallbackFromRow(row, currents, smoothWindow)
row = double(row(:)');
currents = double(currents(:));
valid = isfinite(row) & isfinite(currents(:)');
if nnz(valid) < 3
    cdfRow = zeros(size(currents));
    return
end
r = row(valid);
I = currents(valid);
rMin = min(r, [], 'omitnan');
rMax = max(r, [], 'omitnan');
if ~(isfinite(rMin) && isfinite(rMax) && rMax > rMin)
    cdfRow = zeros(size(currents));
    return
end
rNorm = (r - rMin) ./ (rMax - rMin);
if smoothWindow >= 2
    rNorm = smoothdata(rNorm, 'movmean', min(smoothWindow, numel(rNorm)));
end
rNorm = localEnforceMonotoneNondecreasing(rNorm);
p = gradient(rNorm, I);
p = max(p, 0);
area = trapz(I, p);
if ~(isfinite(area) && area > 0)
    cdfRow = zeros(size(currents));
    return
end
p = p ./ area;
pFull = interp1(I, p, currents, 'linear', 0);
pFull = max(pFull, 0);
areaFull = trapz(currents, pFull);
if areaFull > 0
    pFull = pFull ./ areaFull;
end
cdfRow = cumtrapz(currents, pFull);
if cdfRow(end) > 0
    cdfRow = cdfRow ./ cdfRow(end);
end
cdfRow = min(max(cdfRow, 0), 1);
end

function y = localEnforceMonotoneNondecreasing(x)
y = x(:).';
for i = 2:numel(y)
    if y(i) < y(i - 1)
        y(i) = y(i - 1);
    end
end
if y(end) > 0
    y = y ./ y(end);
end
end

function ptData = localLoadPTData(ptMatrixPath)
ptData = struct('available', false, 'temps', [], 'currents', [], 'PT', []);
if exist(ptMatrixPath, 'file') ~= 2
    return
end
tbl = readtable(ptMatrixPath);
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
keep = isfinite(currents);
currents = currents(keep);
currentCols = currentCols(keep);
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

function Rout = localInterpolateRowsToGrid(Xrows, Yrows, xGrid)
nRows = size(Xrows, 1);
nX = numel(xGrid);
Rout = NaN(nRows, nX);
for i = 1:nRows
    x = Xrows(i, :);
    y = Yrows(i, :);
    m = isfinite(x) & isfinite(y);
    if nnz(m) < 3
        continue
    end
    x = x(m);
    y = y(m);
    [x, ord] = sort(x);
    y = y(ord);
    [x, iu] = unique(x, 'stable');
    y = y(iu);
    Rout(i, :) = interp1(x, y, xGrid, 'linear', NaN);
end
end

function [psi, sv, rank1Frac] = localLeadingModeFromResidual(Rlow)
R0 = Rlow;
R0(~isfinite(R0)) = 0;
[U, S, V] = svd(R0, 'econ');
s = diag(S);
psi = V(:, 1);
scale = max(abs(psi), [], 'omitnan');
if ~(isfinite(scale) && scale > 0)
    scale = 1;
end
psi = psi ./ scale;
sv = s;
rank1Frac = s(1) ^ 2 / max(sum(s .^ 2), eps);
end

function kappa = localFitKappaPerRow(R, phi)
nRows = size(R, 1);
kappa = NaN(nRows, 1);
for i = 1:nRows
    r = R(i, :)';
    m = isfinite(r) & isfinite(phi);
    if nnz(m) < 3
        continue
    end
    denom = sum(phi(m) .^ 2, 'omitnan');
    if denom <= eps
        continue
    end
    kappa(i) = sum(r(m) .* phi(m), 'omitnan') / denom;
end
end

function r = localRmse(A, B)
d = (A - B) .^ 2;
r = sqrt(mean(d(:), 'omitnan'));
end

function c = localCosine(p, q)
c = dot(p(:), q(:)) / (norm(p(:)) * norm(q(:)) + eps);
end

function localFigPhiVsBest(xGrid, phiEmp, psiBest, runDir)
baseName = 'phi_vs_best_pt_deformation';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 10]);
hold on;
m = isfinite(phiEmp) & isfinite(psiBest) & isfinite(xGrid);
plot(xGrid(m), phiEmp(m), 'LineWidth', 2, 'DisplayName', '\Phi(x) (decomposition)');
plot(xGrid(m), psiBest(m), 'LineWidth', 2, 'DisplayName', '\psi(x) (best \deltaP mode)');
hold off;
grid on;
xlabel('x = (I - I_{peak}) / w (1)');
ylabel('Mode amplitude (arb.)');
legend('Location', 'best');
title('Empirical \Phi vs leading PT-deformation mode');
save_run_figure(fig, baseName, runDir);
close(fig);
end

function localFigReconCompare(xGrid, Rx, phiEmp, psiBest, kLow, aBest, tempsLow, runDir)
baseName = 'reconstruction_comparison';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 14 10]);
nT = size(Rx, 1);
idxPick = unique(round(linspace(1, nT, min(4, nT))));
hold on;
for k = 1:numel(idxPick)
    ik = idxPick(k);
    mk = isfinite(Rx(ik, :));
    Tk = tempsLow(ik);
    plot(xGrid(mk), Rx(ik, mk), 'LineWidth', 2.2, 'DisplayName', sprintf('\\delta S (T=%.1f K)', Tk));
end
i0 = idxPick(1);
m0 = isfinite(Rx(i0, :)) & isfinite(phiEmp(:))';
plot(xGrid(m0), kLow(i0) .* phiEmp(m0), '--', 'LineWidth', 2, 'DisplayName', '\kappa(T)\Phi(x) @ slice');
plot(xGrid(m0), aBest(i0) .* psiBest(m0), ':', 'LineWidth', 2.2, 'DisplayName', 'a(T)\psi(x) @ slice');
hold off;
grid on;
xlabel('x (1)');
ylabel('\delta S linearized (arb.)');
legend('Location', 'best');
title('Linearized \deltaS vs \kappa\Phi and rank-1 \psi reconstruction (representative T)');
save_run_figure(fig, baseName, runDir);
close(fig);
end

function localFigSingularValues(sv, runDir)
baseName = 'singular_values';
fig = create_figure('Name', baseName, 'NumberTitle', 'off', 'Visible', 'off', ...
    'Position', [2 2 12 8]);
sv = sv(:);
n = min(20, numel(sv));
semilogy(1:n, sv(1:n) + eps, 'o-', 'LineWidth', 2);
grid on;
xlabel('Index');
ylabel('Singular value');
title('SVD spectrum (best \deltaP basis, low-T stack)');
save_run_figure(fig, baseName, runDir);
close(fig);
end

function lines = localBuildReport(cfg, decTablesDir, ptPath, alignId, scaleId, cdfMeta, ...
    corrTbl, verdict, verdictLine, bestId, bestCorr, bestRatio)

lines = strings(0, 1);
lines(end + 1) = "# PT deformation mode test";
lines(end + 1) = "";
lines(end + 1) = "## Hypothesis";
lines(end + 1) = "Does there exist a functional **deltaP(I)** such that a small renormalized perturbation of **P_T** produces a linearized **deltaS(I,T)** whose dominant **x**-mode matches empirical **Phi(x)** and amplitudes align with decomposition **kappa(T) Phi(x)**?";
lines(end + 1) = "";
lines(end + 1) = "## Method";
lines(end + 1) = "- **S_CDF:** identical to `switching_residual_decomposition_analysis` (PT density on alignment currents, trapz-normalize, **cumtrapz** CDF, multiply **S_peak**).";
lines(end + 1) = "- **Perturbation:** **P' = normalize(max(P + eps deltaP,0))** on the alignment current grid; **deltaS ~ (S_peak CDF(P') - S_CDF)/eps**.";
lines(end + 1) = "- **deltaP bases:** low-order polynomials (QR on **[1,z,z^2,z^3]**), wide/narrow Gaussians, triangular hats, left/right local bumps, leading **PCA** columns of **PT** after row-mean removal.";
lines(end + 1) = "- **x-map:** same interpolation as decomposition (**x = (I-I_peak)/w** onto **phi_shape.csv** grid); **SVD** on low-T (**T <= canonicalMaxTemperatureK**) stack.";
lines(end + 1) = "- **Metrics:** Pearson / cosine between **psi** and **Phi**; **RMSE** of **kappa*Phi** vs stack vs optimal rank-1 **a*psi** (ratio reported).";
lines(end + 1) = "";
lines(end + 1) = "## Inputs";
lines(end + 1) = "- Decomposition: `" + string(cfg.decompositionRunId) + "` | tables: `" + string(decTablesDir) + "`";
lines(end + 1) = "- PT: `" + string(ptPath) + "`";
lines(end + 1) = "- Alignment: `" + alignId + "` | Scaling: `" + scaleId + "`";
lines(end + 1) = sprintf("- CDF rows: PT-backed %d, fallback %d", cdfMeta.ptRowsUsed, cdfMeta.fallbackRowsUsed);
lines(end + 1) = "";
lines(end + 1) = "## Results (all bases)";
lines(end + 1) = localTableToMd(corrTbl);
lines(end + 1) = "";
lines(end + 1) = "## Verdict";
lines(end + 1) = "**" + verdict + "** — " + string(verdictLine);
lines(end + 1) = "";
lines(end + 1) = sprintf("- **Best basis id:** `%s`", bestId);
lines(end + 1) = sprintf("- **Best Pearson (psi vs Phi):** %.4f", bestCorr);
lines(end + 1) = sprintf("- **Best RMSE ratio (kappa*Phi / rank-1):** %.4g", bestRatio);
lines(end + 1) = "";
lines(end + 1) = "## Criteria";
lines(end + 1) = sprintf("- Correlation threshold: **%.2f** | RMSE ratio threshold: **%.2f** (configurable in script).", ...
    cfg.corrThreshold, cfg.rmseRatioThreshold);
end

function s = localTableToMd(tbl)
if isempty(tbl) || height(tbl) == 0
    s = "_No rows._";
    return
end
vn = tbl.Properties.VariableNames;
sep = " | ";
head = "| " + strjoin(string(vn), sep) + " |";
rule = "|" + strjoin(repmat("---", 1, numel(vn)), "|") + "|";
rows = strings(height(tbl), 1);
for i = 1:height(tbl)
    cells = strings(1, numel(vn));
    for j = 1:numel(vn)
        v = tbl.(vn{j})(i);
        if iscell(v)
            v = v{1};
        end
        if isstring(v) || ischar(v)
            cells(j) = string(v);
        elseif isnumeric(v)
            cells(j) = sprintf('%.6g', double(v));
        else
            cells(j) = string(v);
        end
    end
    rows(i) = "| " + strjoin(cells, sep) + " |";
end
s = strjoin([head; rule; rows], newline);
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

function appendText(filePath, textValue)
fid = fopen(filePath, 'a', 'n', 'UTF-8');
if fid == -1
    warning('Unable to append to %s.', filePath);
    return;
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', char(string(textValue)));
end

function out = localStampNow()
out = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
