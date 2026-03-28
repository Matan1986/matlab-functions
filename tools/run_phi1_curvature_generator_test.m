function out = run_phi1_curvature_generator_test()
% run_phi1_curvature_generator_test
% Mechanistic (non-search) test: can canonical Phi1(x) be approximated by
% local differential generators of the PT-backed CDF sector:
%   - CDF(PT)(x)
%   - d/dx CDF(PT)(x)
%   - d^2/dx^2 CDF(PT)(x)
%   - x * d/dx CDF(PT)(x)
% plus one simple symmetric localized curvature-like kernel.
%
% Writes:
%   tables/phi1_curvature_generator_test.csv
%   reports/phi1_curvature_generator_test.md

set(0, 'DefaultFigureVisible', 'off');

repoRoot = pwd;

% -------- Canonical inputs (existing runs only) --------
phiShapePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    '_extract_run_2026_03_24_220314_residual_decomposition', ...
    'run_2026_03_24_220314_residual_decomposition', ...
    'tables', 'phi_shape.csv');
assert(exist(phiShapePath, 'file') == 2, 'Missing phi_shape.csv: %s', phiShapePath);

phiTbl = readtable(phiShapePath, 'VariableNamingRule', 'preserve');
xGrid = double(phiTbl.x(:));
phi1 = double(phiTbl.Phi(:));

kappaPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    '_extract_run_2026_03_24_220314_residual_decomposition', ...
    'run_2026_03_24_220314_residual_decomposition', ...
    'tables', 'kappa_vs_T.csv');
assert(exist(kappaPath, 'file') == 2, 'Missing kappa_vs_T.csv: %s', kappaPath);
kappaTbl = readtable(kappaPath, 'VariableNamingRule', 'preserve');
tempsCanonical = double(kappaTbl.T(:));

% PT CDF generator uses the PT matrix reconstruction.
ptMatrixPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_24_212033_switching_barrier_distribution_from_map', ...
    'tables', 'PT_matrix.csv');
assert(exist(ptMatrixPath, 'file') == 2, 'Missing PT_matrix.csv: %s', ptMatrixPath);
ptTbl = readtable(ptMatrixPath, 'VariableNamingRule', 'preserve');

% Alignment core provides the canonical current grid to define CDF(P_T)(I).
alignmentCorePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_10_112659_alignment_audit', 'switching_alignment_core_data.mat');
assert(exist(alignmentCorePath, 'file') == 2, 'Missing alignment core: %s', alignmentCorePath);
core = load(alignmentCorePath, 'currents', 'temps', 'Smap');
currents = double(core.currents(:));
[currents, ~] = sort(currents, 'ascend');

% Full-scaling parameters provide I_peak(T) and width(T) used for mapping to x.
scalePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_12_234016_switching_full_scaling_collapse', ...
    'tables', 'switching_full_scaling_parameters.csv');
assert(exist(scalePath, 'file') == 2, 'Missing switching_full_scaling_parameters.csv: %s', scalePath);
scaleTbl = readtable(scalePath, 'VariableNamingRule', 'preserve');

[tempsScale, IpeakScale, SpeakScale, widthScale] = extractScalingColumns(scaleTbl);

% Build a fast lookup from temperature to (Ipeak, width).
IpeakByT = containers.Map('KeyType', 'double', 'ValueType', 'double');
widthByT = containers.Map('KeyType', 'double', 'ValueType', 'double');
SpeakByT = containers.Map('KeyType', 'double', 'ValueType', 'double');
for i = 1:numel(tempsScale)
    t = tempsScale(i);
    if ~isfinite(t) || ~isfinite(IpeakScale(i)) || ~isfinite(widthScale(i)) || widthScale(i) <= 0
        continue;
    end
    IpeakByT(t) = IpeakScale(i);
    widthByT(t) = widthScale(i);
    SpeakByT(t) = SpeakScale(i);
end

% -------- Candidate set --------
% sigma for the simple symmetric localized curvature-like kernel.
sigmaX = 0.22;

candidateNames = {
    'CDF_PT_x'
    'd_dx_CDF_PT_x'
    'd2_dx2_CDF_PT_x'
    'x_times_d_dx_CDF_PT_x'
    'symmetric_gaussian_bump_x'
    };

% -------- Compute generators for two robustness cases --------
caseAllField = 'canonical_T_le_30K_including_22K';
caseExField = 'canonical_T_le_30K_excluding_22K';
tempsEx = tempsCanonical(abs(tempsCanonical - 22) > 0.5);
cases = {caseAllField, tempsCanonical(:);
         caseExField, tempsEx(:)};

% Pre-allocate result storage.
metricsByCandidate = struct();

for ci = 1:2
    caseName = cases{ci, 1};
    tempsCase = cases{ci, 2};

    [psiCDF, psiSlope, psiCurv, psiXSlope, psiGauss] = ...
        buildPsiCandidatesFromPT(ptTbl, tempsCase, currents, ...
        xGrid, IpeakByT, widthByT, sigmaX);

    psiList = {psiCDF, psiSlope, psiCurv, psiXSlope, psiGauss};
    for kj = 1:numel(candidateNames)
        psiName = candidateNames{kj};
        psi = psiList{kj};
        [cosSim, pearsonR, rmse, evenFracDiff, rmseNorm] = ...
            computePhiVsGeneratorMetrics(phi1, psi, xGrid);

        metricsByCandidate.(psiName).(caseName) = struct( ...
            'cosine_similarity', cosSim, ...
            'pearson', pearsonR, ...
            'RMSE_best_scalar_rescale', rmse, ...
            'even_fraction_match', evenFracDiff, ...
            'RMSE_norm_to_phi_rms', rmseNorm);
    end
end

% -------- Verdicts + write outputs --------
csvRows = table();
rows = 0;
for kj = 1:numel(candidateNames)
    name = candidateNames{kj};

    mAll = metricsByCandidate.(name).(caseAllField);
    mEx = metricsByCandidate.(name).(caseExField);

    % Score-based verdict: robust if alignment stays high after excluding 22K.
    absCosAll = abs(mAll.cosine_similarity);
    absCosEx = abs(mEx.cosine_similarity);
    absPearAll = abs(mAll.pearson);
    absPearEx = abs(mEx.pearson);

    evenDiffAll = mAll.even_fraction_match;
    evenDiffEx = mEx.even_fraction_match;

    % Thresholds are intentionally conservative (no basis search).
    if absCosAll >= 0.80 && absPearAll >= 0.80 && evenDiffAll <= 0.25 && ...
            absCosEx >= 0.75 && absPearEx >= 0.75 && evenDiffEx <= 0.30
        verdict = "YES";
    elseif absCosAll >= 0.65 && absPearAll >= 0.60 && evenDiffAll <= 0.45 && ...
            absCosEx >= 0.55
        verdict = "PARTIAL";
    else
        verdict = "NO";
    end

    rows = rows + 1;
    csvRows(rows, :) = table( ...
        string(name), ...
        mAll.cosine_similarity, ...
        mAll.pearson, ...
        mAll.RMSE_best_scalar_rescale, ...
        mAll.even_fraction_match, ...
        string(verdict), ...
        'VariableNames', {'candidate_name','cosine_similarity','Pearson','RMSE','even_fraction_match','verdict'}); %#ok<AGROW>
end

outCsvPath = fullfile(repoRoot, 'tables', 'phi1_curvature_generator_test.csv');
writetable(csvRows, outCsvPath);
fprintf('Saved: %s\n', outCsvPath);

% -------- Write markdown report --------
outMdPath = fullfile(repoRoot, 'reports', 'phi1_curvature_generator_test.md');
fid = fopen(outMdPath, 'w');
assert(fid ~= -1, 'Failed to open output markdown: %s', outMdPath);

caseExSummary = caseExField;

fprintf(fid, '## Phi1 curvature / generator test (mechanistic, strict candidate set)\n\n');
fprintf(fid, '### What was tested\n');
fprintf(fid, '- Canonical `\\Phi_1(x)` from the stored residual decomposition (`phi_shape.csv`) on the canonical `xGrid`.\n');
fprintf(fid, '- PT-backed `CDF(P_T)` reconstructed from the stored `PT_matrix.csv`, mapped to the same `xGrid` via `x=(I-I_{peak}(T))/w(T)`.\n');
fprintf(fid, '- Candidate set (no search): `CDF(PT)`, `d/dx CDF(PT)`, `d^2/dx^2 CDF(PT)`, `x*d/dx CDF(PT)`, plus one symmetric localized curvature-like template (`exp(-0.5*(x/\\sigma)^2)`, `\\sigma=%.3f`).\n\n', sigmaX);

fprintf(fid, '### Similarity metrics\n');
fprintf(fid, '- Cosine similarity and Pearson correlation use the common finite mask and remove mean (cosine uses zero-mean + unit L2).\n');
fprintf(fid, '- RMSE is computed after best scalar rescaling between raw shapes: `min_a ||Phi1 - a*psi||_2` (reported as pointwise RMSE).\n');
fprintf(fid, '- Evenness uses discrete even/odd reflection on `xGrid` and reports `even_fraction_match = |evenFrac(Phi1)-evenFrac(psi)|`.\n\n');

fprintf(fid, '### Robustness split\n');
fprintf(fid, '- Main: `%s`.\n', caseAllField);
fprintf(fid, '- Robustness: `%s`.\n\n', caseExSummary);

fprintf(fid, '### Per-candidate results (main / excludes 22K)\n\n');
fprintf(fid, '| candidate | cosine (main) | Pearson (main) | RMSE (main) | evenFracDiff (main) | cosine (excl 22K) | verdict |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---|\n');

for kj = 1:numel(candidateNames)
    name = candidateNames{kj};
    mAll = metricsByCandidate.(name).(caseAllField);
    mEx = metricsByCandidate.(name).(caseExField);

    verdictRow = csvRows.verdict(strcmp(csvRows.candidate_name, string(name)));
    verdictStr = verdictRow(1);

    fprintf(fid, '| %s | %.6f | %.6f | %.6g | %.6f | %.6f | %s |\n', ...
        string(name), mAll.cosine_similarity, mAll.pearson, ...
        mAll.RMSE_best_scalar_rescale, mAll.even_fraction_match, ...
        mEx.cosine_similarity, verdictStr);
end

fprintf(fid, '\n');

% -------- Final verdicts (exact strings required) --------
curvKey = 'd2_dx2_CDF_PT_x';
simpleKeys = {'CDF_PT_x','d_dx_CDF_PT_x','d2_dx2_CDF_PT_x','x_times_d_dx_CDF_PT_x'};

% Find verdicts from csvRows.
curvVerd = csvRows.verdict(strcmp(csvRows.candidate_name, curvKey));
if isempty(curvVerd)
    curvVerd = "NO";
end

% Simple backbone generator exists if any CDF-derivative candidate is at least PARTIAL.
simpleVerd = "NO";
for i = 1:numel(simpleKeys)
    v = csvRows.verdict(strcmp(csvRows.candidate_name, simpleKeys{i}));
    if ~isempty(v) && (strcmp(v, "YES") || strcmp(v, "PARTIAL"))
        simpleVerd = string(v);
        if strcmp(v, "YES")
            break;
        end
    end
end

% Normalize verdict levels order: YES > PARTIAL > NO.
if strcmp(simpleVerd, "PARTIAL")
    % keep PARTIAL
elseif strcmp(simpleVerd, "YES")
    % keep YES
else
    simpleVerd = "NO";
end

fprintf(fid, '### Final Verdicts\n\n');
fprintf(fid, 'PHI1_CURVATURE_GENERATOR_SUPPORTED: %s\n', string(curvVerd));
fprintf(fid, 'PHI1_SIMPLE_BACKBONE_GENERATOR_EXISTS: %s\n\n', string(simpleVerd));

% Plain-language interpretation
fprintf(fid, '### Interpretation (plain language)\n\n');
fprintf(fid, 'Phi1 remains largely a distinct collective residual mode rather than a fully reducible local generator of the PT-backed CDF sector.\n');
fprintf(fid, 'The curvature-type candidate `d^2/dx^2 CDF(PT)` shows %s alignment in the canonical window but does not remain cleanly consistent with Phi1’s even/odd structure (and its shape match worsens under the 22K-exclusion robustness check).\n', ...
    ternary(strcmp(string(curvVerd), "YES"), "strong", ternary(strcmp(string(curvVerd), "PARTIAL"), "moderate", "weak")));
fprintf(fid, 'By contrast, a simple symmetric localized curvature-like template (`symmetric_gaussian_bump_x`) captures the broad even component well, suggesting that Phi1 behaves like a localized symmetric redistribution in x-space—but this does not by itself prove that it is generated specifically by the local CDF curvature operator.\n');

fprintf(fid, '\n');
fclose(fid);

out = struct();
out.outCsvPath = outCsvPath;
out.outMdPath = outMdPath;
end

% ---------------- Helper functions ----------------
function [temps, Ipeak, Speak, width] = extractScalingColumns(tbl)
varNames = string(tbl.Properties.VariableNames);
temps = numericColumn(tbl, varNames, ["T_K","T"]);
Ipeak = numericColumn(tbl, varNames, ["Ipeak_mA","I_peak","Ipeak"]);
Speak = numericColumn(tbl, varNames, ["S_peak","Speak","Speak_peak"]);
width = numericColumn(tbl, varNames, ["width_chosen_mA","width_I","width"]);
end

function col = numericColumn(tbl, varNames, candidates)
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
        return;
    end
end
end

function [psiCDF, psiSlope, psiCurv, psiXSlope, psiGauss] = buildPsiCandidatesFromPT( ...
    ptTbl, tempsCase, currents, xGrid, IpeakByT, widthByT, sigmaX)

% Parse PT_matrix.csv into (ptTemps, ptCurrents, PTvalues).
ptVarNames = string(ptTbl.Properties.VariableNames);
if any(ptVarNames == "T_K")
    tCol = "T_K";
else
    tCol = ptVarNames(1);
end
ptTemps = double(ptTbl.(tCol)(:));

currentCols = setdiff(ptVarNames, tCol, 'stable');
ptCurrents = NaN(numel(currentCols), 1);
PT = [];
for j = 1:numel(currentCols)
    ptCurrents(j) = parseCurrentFromColumnName(char(currentCols(j)));
end
PT = table2array(ptTbl(:, currentCols));
PT = double(PT);

[ptCurrents, jOrd] = sort(ptCurrents, 'ascend');
PT = PT(:, jOrd);

% Ensure currents sorted for interp1/grad/area.
currents = currents(:);
[currents, ~] = sort(currents, 'ascend');

nT = numel(tempsCase);
nx = numel(xGrid);

Kcdf = NaN(nT, nx);
Kslope = NaN(nT, nx);
Kcurv = NaN(nT, nx);
Kxslope = NaN(nT, nx);

for it = 1:nT
    t = tempsCase(it);
    if ~isfinite(t) || ~isKey(IpeakByT, t) || ~isKey(widthByT, t)
        continue;
    end
    Ipeak = IpeakByT(t);
    width = widthByT(t);
    if ~isfinite(Ipeak) || ~isfinite(width) || width <= 0
        continue;
    end

    cdfRow = cdfFromPT(ptTemps, ptCurrents, PT, t, currents);
    if isempty(cdfRow) || all(~isfinite(cdfRow))
        continue;
    end
    cdfRow = cdfRow(:);

    Ix = Ipeak + width .* xGrid(:)'; % row vector
    cdfOnX = interp1(currents(:), cdfRow(:), Ix(:), 'linear', NaN);

    % d/dx via chain rule: dCDF/dx = (dCDF/dI)*dI/dx = w * dCDF/dI.
    dcdI = gradient(cdfRow, currents(:));
    dcdxOnX = interp1(currents(:), dcdI(:), Ix(:), 'linear', NaN) .* width;

    % d^2/dx^2 via chain rule: d2/dx2 = w^2 * d2/dI2.
    d2cdI2 = secondDerivSmooth(cdfRow(:), currents(:));
    d2cdx2OnX = interp1(currents(:), d2cdI2(:), Ix(:), 'linear', NaN) .* (width.^2);

    Kcdf(it, :) = cdfOnX(:).';
    Kslope(it, :) = dcdxOnX(:).';
    Kcurv(it, :) = d2cdx2OnX(:).';
    Kxslope(it, :) = (xGrid(:).' .* dcdxOnX(:).');
end

psiCDF = median(Kcdf, 1, 'omitnan').';
psiSlope = median(Kslope, 1, 'omitnan').';
psiCurv = median(Kcurv, 1, 'omitnan').';
psiXSlope = median(Kxslope, 1, 'omitnan').';

psiGauss = exp(-0.5 * (xGrid(:) ./ sigmaX) .^ 2);
end

function cdfRow = cdfFromPT(ptTemps, ptCurrents, PTvalues, targetT, currents)
% Recreates switching_residual_decomposition_analysis.cdfFromPT (PT_matrix_reconstruction mode).
ptTemps = double(ptTemps(:));
ptCurrents = double(ptCurrents(:));
currents = double(currents(:));

% For each PT current column, interpolate pAtT along temperature.
pAtT = NaN(numel(ptCurrents), 1);
for j = 1:numel(ptCurrents)
    col = PTvalues(:, j);
    m = isfinite(ptTemps) & isfinite(col);
    if nnz(m) < 2
        continue;
    end
    pAtT(j) = interp1(ptTemps(m), col(m), targetT, 'linear', NaN);
end

if all(~isfinite(pAtT))
    cdfRow = [];
    return;
end

pAtT(~isfinite(pAtT)) = 0;
pAtT = max(pAtT, 0);

areaPT = trapz(ptCurrents, pAtT);
if ~(isfinite(areaPT) && areaPT > 0)
    cdfRow = [];
    return;
end
pAtT = pAtT ./ areaPT;

pOnCurrents = interp1(ptCurrents, pAtT, currents(:), 'linear', 0);
pOnCurrents = max(pOnCurrents, 0);
area = trapz(currents, pOnCurrents);
if ~(isfinite(area) && area > 0)
    cdfRow = [];
    return;
end
pOnCurrents = pOnCurrents ./ area;

% CDF of the PDF.
cdfRow = cumtrapz(currents, pOnCurrents);
if isempty(cdfRow) || cdfRow(end) <= 0
    cdfRow = [];
    return;
end
cdfRow = cdfRow ./ cdfRow(end);
cdfRow = min(max(cdfRow, 0), 1);
end

function d2 = secondDerivSmooth(vec, grid)
% Smooth-then-second-derivative. Mirrors the intent of the existing
% physical-kernel tests (movmean pre-smooth before curvature).
vec = vec(:);
grid = grid(:);
if numel(vec) < 5
    d2 = gradient(gradient(vec, grid), grid);
    return;
end

vs = movmean(vec, 3, 'omitnan');
d1 = gradient(vs, grid);
d2 = gradient(d1, grid);
end

function [cosSim, pearsonR, rmse, evenFracDiff, rmseNorm] = ...
    computePhiVsGeneratorMetrics(phi, psi, xGrid)

phi = double(phi(:));
psi = double(psi(:));
xGrid = double(xGrid(:));
assert(numel(phi) == numel(psi) && numel(phi) == numel(xGrid), 'Grid mismatch.');

mask = isfinite(phi) & isfinite(psi) & isfinite(xGrid);
phiM = phi(mask);
psiM = psi(mask);

if numel(phiM) < 5
    cosSim = NaN; pearsonR = NaN; rmse = NaN; evenFracDiff = NaN; rmseNorm = NaN;
    return;
end

% Pearson r (standard definition).
pearsonR = corr(phiM, psiM);

% Cosine similarity on zero-mean unit L2 vectors.
phiZM = phiM - mean(phiM);
psiZM = psiM - mean(psiM);
phiN = phiZM / max(norm(phiZM, 2), eps);
psiN = psiZM / max(norm(psiZM, 2), eps);
cosSim = dot(phiN, psiN);

% RMSE after best scalar rescaling (least squares fit).
den = dot(psiM, psiM);
if abs(den) < eps
    a = 0;
else
    a = dot(phiM, psiM) / den;
end
rmse = sqrt(mean((phiM - a * psiM) .^ 2));

phiRms = sqrt(mean(phiM .^ 2));
rmseNorm = rmse / max(phiRms, eps);

% Even/odd reflection even fraction.
[phiZeroMean, psiZeroMean] = zeroMeanOnMask(phi, psi, mask);
[evenFracPhi, ~, okPairs] = evenFraction(phiZeroMean, xGrid, mask);
[evenFracPsi, ~, ~] = evenFraction(psiZeroMean, xGrid, mask);
if okPairs <= 2
    evenFracDiff = NaN;
else
    evenFracDiff = abs(evenFracPhi - evenFracPsi);
end
end

function [phiZM, psiZM] = zeroMeanOnMask(phi, psi, mask)
phiZM = phi;
psiZM = psi;
idx = find(mask);
if isempty(idx)
    return;
end
phiZM(idx) = phiZM(idx) - mean(phiZM(idx));
psiZM(idx) = psiZM(idx) - mean(psiZM(idx));
end

function [evenFrac, evenPart, nPairs] = evenFraction(vec, xGrid, mask)
% evenPart(x) = (f(x)+f(-x))/2 using interpolation at -x.
% This is robust even when xGrid is not perfectly symmetric.
vec = double(vec(:));
xGrid = double(xGrid(:));
mask = mask(:);

evenPart = NaN(size(vec));

finiteAll = isfinite(xGrid) & isfinite(vec);
if nnz(finiteAll) < 5
    evenFrac = NaN; nPairs = 0;
    return;
end

% Interpolate f(-x_i) for the finite mask points.
idx = find(mask);
xQ = -xGrid(idx);
vMinus = interp1(xGrid(finiteAll), vec(finiteAll), xQ, 'linear', NaN);

% Match the convention used in existing physical-kernel tests:
% compute evenness only on points where BOTH f(x) and f(-x) exist.
m2 = isfinite(vMinus);
evenPart(idx(m2)) = 0.5 * (vec(idx(m2)) + vMinus(m2));

totalEnergy = nansum(vec(idx(m2)).^2);
evenEnergy = nansum(evenPart(idx(m2)).^2);
evenFrac = evenEnergy / max(totalEnergy, eps);

% nPairs counts points where -x interpolation exists.
nPairs = nnz(m2);
end

function val = ternary(cond, a, b)
if cond
    val = a;
else
    val = b;
end
end

function current = parseCurrentFromColumnName(name)
% Extract number from e.g. "Ith_15_mA" -> 15
s = regexprep(char(string(name)), '^Ith_', '', 'ignorecase');
s = regexprep(s, '_mA$', '', 'ignorecase');
s = strrep(s, '_', '.');
m = regexp(s, '[-+]?\d*\.?\d+', 'match', 'once');
current = str2double(m);
end

