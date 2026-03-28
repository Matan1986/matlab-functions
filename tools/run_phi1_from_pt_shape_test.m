function out = run_phi1_from_pt_shape_test()
% run_phi1_from_pt_shape_test
% Shape-level mechanism test:
% Can canonical Phi1(x) be generated as a simple functional of barrier
% landscape PT / CDF only (no ML, no basis search beyond strict terms)?
%
% Writes:
%   tables/phi1_from_pt_shape_test.csv
%   reports/phi1_from_pt_shape_test.md

set(0, 'DefaultFigureVisible', 'off');

repoRoot = fileparts(fileparts(mfilename('fullpath')));

markerStartPath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_start.txt');
fidM = fopen(markerStartPath, 'w');
fprintf(fidM, 'start %s\n', datestr(now));
fclose(fidM);

% -------- Canonical inputs (existing runs only) --------
phiShapePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    '_extract_run_2026_03_24_220314_residual_decomposition', ...
    'run_2026_03_24_220314_residual_decomposition', ...
    'tables', 'phi_shape.csv');
assert(exist(phiShapePath, 'file') == 2, 'Missing phi_shape.csv: %s', phiShapePath);

phiTbl = readtable(phiShapePath, 'VariableNamingRule', 'preserve');
xGrid = double(phiTbl.x(:));
phi1 = double(phiTbl.Phi(:));
assert(numel(xGrid) == numel(phi1), 'Phi1 grid mismatch.');

markerPhiLoadedPath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_phi_loaded.txt');
fidM = fopen(markerPhiLoadedPath, 'w');
fprintf(fidM, 'phi_loaded %s\n', datestr(now));
fclose(fidM);

kappaPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    '_extract_run_2026_03_24_220314_residual_decomposition', ...
    'run_2026_03_24_220314_residual_decomposition', ...
    'tables', 'kappa_vs_T.csv');
assert(exist(kappaPath, 'file') == 2, 'Missing kappa_vs_T.csv: %s', kappaPath);

kappaTbl = readtable(kappaPath, 'VariableNamingRule', 'preserve');
tempsCanonical = double(kappaTbl.T(:));

markerKappaLoadedPath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_kappa_loaded.txt');
fidM = fopen(markerKappaLoadedPath, 'w');
fprintf(fidM, 'kappa_loaded %s\n', datestr(now));
fclose(fidM);

% Canonical PT/CDF outputs (requested: canonical PT / CDF)
ptMatrixPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_25_013356_pt_robust_canonical', ...
    'tables', 'PT_matrix.csv');
assert(exist(ptMatrixPath, 'file') == 2, 'Missing PT_matrix.csv: %s', ptMatrixPath);
ptTbl = readtable(ptMatrixPath, 'VariableNamingRule', 'preserve');

markerPTLoadedPath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_pt_loaded.txt');
fidM = fopen(markerPTLoadedPath, 'w');
fprintf(fidM, 'pt_loaded %s\n', datestr(now));
fclose(fidM);

% Alignment core provides the canonical current grid to define CDF(P_T)(I).
alignmentCorePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_10_112659_alignment_audit', ...
    'switching_alignment_core_data.mat');
assert(exist(alignmentCorePath, 'file') == 2, 'Missing alignment core: %s', alignmentCorePath);
core = load(alignmentCorePath, 'currents', 'temps', 'Smap');
currents = double(core.currents(:));
[currents, ~] = sort(currents, 'ascend');

markerAlignLoadedPath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_alignment_loaded.txt');
fidM = fopen(markerAlignLoadedPath, 'w');
fprintf(fidM, 'alignment_loaded %s\n', datestr(now));
fclose(fidM);

% Full scaling parameters provide I_peak(T) and width(T) used for mapping to x.
scalePath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
    'run_2026_03_12_234016_switching_full_scaling_collapse', ...
    'tables', 'switching_full_scaling_parameters.csv');
assert(exist(scalePath, 'file') == 2, 'Missing scaling parameters: %s', scalePath);
scaleTbl = readtable(scalePath, 'VariableNamingRule', 'preserve');
[tempsScale, IpeakScale, SpeakScale, widthScale] = extractScalingColumns(scaleTbl); %#ok<ASGLU>

% Build fast lookup maps for the x mapping.
IpeakByT = containers.Map('KeyType', 'double', 'ValueType', 'double');
widthByT = containers.Map('KeyType', 'double', 'ValueType', 'double');
for i = 1:numel(tempsScale)
    t = tempsScale(i);
    if ~isfinite(t) || ~isfinite(IpeakScale(i)) || ~isfinite(widthScale(i)) || widthScale(i) <= 0
        continue;
    end
    IpeakByT(t) = IpeakScale(i);
    widthByT(t) = widthScale(i);
end

markerMapsBuiltPath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_maps_built.txt');
fidM = fopen(markerMapsBuiltPath, 'w');
fprintf(fidM, 'maps_built %s\n', datestr(now));
fclose(fidM);

% -------- Candidate basis (strict, PT-derived) --------
% Each candidate is a 1D vector psi(x) derived from:
%   - CDF(P_T)(x) on the canonical I-grid, then mapped to x via x=(I-Ipeak)/w
% and then simple local operators in x:
%   - d/dx, d^2/dx^2, x*d/dx, x^2*d^2/dx^2,
%   - plus a single nonlocal-but-simple descriptor: smoothed curvature-like response.
%
% IMPORTANT: no "free basis fit", no PCA/ML, no broad kernel zoo.
candidateNames = {
    'CDF_PT_x'
    'd_dx_CDF_PT_x'
    'd2_dx2_CDF_PT_x'
    'x_times_d_dx_CDF_PT_x'
    'x2_times_d2_dx2_CDF_PT_x'
    'smoothed_curvature_like_x'
    };

% Nonlocal smoothing for the curvature-like descriptor.
smoothWinX = 9; % odd, small, interpretably "local averaging in x"

% -------- Robustness cases --------
caseAllField = 'canonical_T_le_30K_including_22K';
caseExField = 'canonical_T_le_30K_excluding_22K';

tempsCanonical = tempsCanonical(:);
tempsCanonical = tempsCanonical(isfinite(tempsCanonical));

tempsEx = tempsCanonical(abs(tempsCanonical - 22) > 0.5);

cases = {caseAllField, tempsCanonical; caseExField, tempsEx};

% -------- Model set: 1-term candidates + all 2-term PT-only combinations --------
% 2-term models use least-squares coefficients on the strict chosen term
% subspace (still constrained, still mechanistic, no black-box search).
modelNames = {};
nTerms = [];
termIdxs = {};

% 1-term models
for i = 1:numel(candidateNames)
    modelNames{end + 1} = candidateNames{i}; %#ok<AGROW>
    nTerms(end + 1, 1) = 1; %#ok<AGROW>
    termIdxs{end + 1} = i; %#ok<AGROW>
end

% 2-term models: all pairs i<j
for i = 1:numel(candidateNames)
    for j = i + 1:numel(candidateNames)
        modelNames{end + 1} = sprintf('%s + %s', candidateNames{i}, candidateNames{j}); %#ok<AGROW>
        nTerms(end + 1, 1) = 2; %#ok<AGROW>
        termIdxs{end + 1} = [i, j]; %#ok<AGROW>
    end
end

nModels = numel(modelNames);

safeModelFields = cell(nModels, 1);
for mi = 1:nModels
    safeModelFields{mi} = matlab.lang.makeValidName(modelNames{mi});
end

metricsByModel = struct();

% -------- Main computation loop over robustness cases --------
for ci = 1:2
    caseName = cases{ci, 1};
    tempsCase = cases{ci, 2};

    % Build PT-derived candidate basis vectors for this robustness case.
    [psiBasis] = buildPsiCandidatesFromPT( ...
        ptTbl, tempsCase, currents, xGrid, IpeakByT, widthByT, smoothWinX);

    if ci == 1
        markerFirstCaseBasisBuiltPath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_first_case_basis_built.txt');
        fidM = fopen(markerFirstCaseBasisBuiltPath, 'w');
        fprintf(fidM, 'first_case_basis_built %s\n', datestr(now));
        fclose(fidM);
    end

    for mi = 1:nModels
        try
            idx = termIdxs{mi};
            if nTerms(mi) == 1
                psi = psiBasis{idx};
            else
                % Least-squares coefficients for the strict chosen 2D subspace.
                X = [psiBasis{idx(1)}, psiBasis{idx(2)}]; % Nx2

                valid = isfinite(phi1) & all(isfinite(X), 2);
                psi = NaN(size(phi1));
                if nnz(valid) >= 3
                    c = pinv(X(valid, :)) * phi1(valid);
                    psi(valid) = X(valid, :) * c;
                end
            end

            [cosSim, pearsonR, rmse, evenFracDiff, rmseNorm] = ...
                computePhiVsGeneratorMetrics(phi1, psi, xGrid);

            metricsByModel.(safeModelFields{mi}).(caseName) = struct( ...
                'cosine_similarity', cosSim, ...
                'pearson', pearsonR, ...
                'RMSE_best_scalar_rescale', rmse, ...
                'even_fraction_match', evenFracDiff, ...
                'RMSE_norm_to_phi_rms', rmseNorm);
        catch ME
            errPath = fullfile(repoRoot, 'tables', ...
                sprintf('_phi1_from_pt_shape_test_error_case%d_model%d.txt', ci, mi));
            fidE = fopen(errPath, 'w');
            fprintf(fidE, 'caseName=%s\nmodel_name=%s\n\n', caseName, modelNames{mi});
            fprintf(fidE, '%s\n', getReport(ME, 'extended'));
            fclose(fidE);
            rethrow(ME);
        end
    end

    if ci == 1
        markerAfterCase1Path = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_after_case1_metrics_done.txt');
        fidM = fopen(markerAfterCase1Path, 'w');
        fprintf(fidM, 'after_case1_metrics_done %s\n', datestr(now));
        fclose(fidM);
    end

    if ci == 2
        markerAfterCase2Path = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_after_case2_metrics_done.txt');
        fidM = fopen(markerAfterCase2Path, 'w');
        fprintf(fidM, 'after_case2_metrics_done %s\n', datestr(now));
        fclose(fidM);
    end
end

% -------- Verdicts + write outputs --------
outCsvPath = fullfile(repoRoot, 'tables', 'phi1_from_pt_shape_test.csv');
outMdPath = fullfile(repoRoot, 'reports', 'phi1_from_pt_shape_test.md');

markerBeforeWritePath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_before_write.txt');
fidM = fopen(markerBeforeWritePath, 'w');
fprintf(fidM, 'before_write %s\n', datestr(now));
fclose(fidM);

% Table rows
csvRows = table();
rows = 0;

% For overall verdict we keep best RMSE model under the main case
bestMi = 1;
bestRmseNormAll = metricsByModel.(safeModelFields{bestMi}).(caseAllField).RMSE_norm_to_phi_rms;
bestCosAll = metricsByModel.(safeModelFields{bestMi}).(caseAllField).cosine_similarity; %#ok<NASGU>

for mi = 1:nModels
    mAll = metricsByModel.(safeModelFields{mi}).(caseAllField);
    mEx = metricsByModel.(safeModelFields{mi}).(caseExField);

    absCosAll = abs(mAll.cosine_similarity);
    absPearAll = abs(mAll.pearson);
    absCosEx = abs(mEx.cosine_similarity);
    absPearEx = abs(mEx.pearson);

    evenDiffAll = mAll.even_fraction_match; % smaller is better
    evenDiffEx = mEx.even_fraction_match;

    % RMSE thresholds are in normalized units (rmseNorm = RMSE / Phi1_rms).
    rmseNormAll = mAll.RMSE_norm_to_phi_rms;
    rmseNormEx = mEx.RMSE_norm_to_phi_rms;

    % Conservative mechanistic verdict thresholds:
    % - Require both projection quality (cos/pearson) and shape error (RMSE_norm)
    % - Require even/odd parity not to drift under the 22K-exclusion robustness split.
    if absCosAll >= 0.80 && absPearAll >= 0.75 && ...
            rmseNormAll <= 0.40 && evenDiffAll <= 0.25 && ...
            absCosEx >= 0.70 && absPearEx >= 0.65 && ...
            rmseNormEx <= 0.55 && evenDiffEx <= 0.30
        verdict = "YES";
    elseif absCosAll >= 0.65 && absPearAll >= 0.60 && ...
            rmseNormAll <= 0.60 && evenDiffAll <= 0.40 && ...
            absCosEx >= 0.55
        verdict = "PARTIAL";
    else
        verdict = "NO";
    end

    rows = rows + 1;
    csvRows(rows, :) = table( ...
        string(modelNames{mi}), ...
        double(nTerms(mi)), ...
        mAll.cosine_similarity, ...
        mAll.pearson, ...
        mAll.RMSE_best_scalar_rescale, ...
        mAll.even_fraction_match, ...
        string(verdict), ...
        'VariableNames', {'model_name','n_terms','cosine_similarity','Pearson','RMSE','even_fraction_match','verdict'}); %#ok<AGROW>

    if rmseNormAll < bestRmseNormAll
        bestMi = mi;
        bestRmseNormAll = rmseNormAll;
        bestCosAll = mAll.cosine_similarity; %#ok<NASGU>
    end
end

writetable(csvRows, outCsvPath);

markerAfterCsvPath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_after_csv.txt');
fidM = fopen(markerAfterCsvPath, 'w');
fprintf(fidM, 'after_csv %s\n', datestr(now));
fclose(fidM);

% Overall verdict logic based on the best RMSE model under the main case.
bestModel = modelNames{bestMi};
bestAll = metricsByModel.(safeModelFields{bestMi}).(caseAllField);
bestEx = metricsByModel.(safeModelFields{bestMi}).(caseExField);

absCosAll = abs(bestAll.cosine_similarity);
absPearAll = abs(bestAll.pearson);
absCosEx = abs(bestEx.cosine_similarity);
absPearEx = abs(bestEx.pearson);

rmseNormAll = bestAll.RMSE_norm_to_phi_rms;
rmseNormEx = bestEx.RMSE_norm_to_phi_rms;
evenDiffAll = bestAll.even_fraction_match;
evenDiffEx = bestEx.even_fraction_match;

% Decide final verdict with a "genuine reconstruction" interpretation:
% YES = competitive RMSE/projection with robustness and correct parity.
if absCosAll >= 0.80 && absPearAll >= 0.75 && ...
        rmseNormAll <= 0.40 && evenDiffAll <= 0.25 && ...
        absCosEx >= 0.70 && absPearEx >= 0.65 && ...
        rmseNormEx <= 0.55 && evenDiffEx <= 0.30
    phiFromPtAloneVerd = "YES";
elseif absCosAll >= 0.65 && absPearAll >= 0.60 && ...
        rmseNormAll <= 0.60 && evenDiffAll <= 0.40 && ...
        absCosEx >= 0.55
    phiFromPtAloneVerd = "PARTIAL";
else
    phiFromPtAloneVerd = "NO";
end

% If PT-only can reproduce Phi1 shape well, Phi1 does not require an independent mode.
% If PT-only fails, Phi1 requires an independent collective mode.
switch phiFromPtAloneVerd
    case "YES"
        requiresIndepVerd = "NO";
    case "PARTIAL"
        requiresIndepVerd = "PARTIAL";
    otherwise
        requiresIndepVerd = "YES";
end

% Write markdown report
fid = fopen(outMdPath, 'w');
assert(fid ~= -1, 'Cannot open report: %s', outMdPath);

fprintf(fid, '# Phi1 From PT Alone (Shape-Level Test)\n\n');
fprintf(fid, '## Goal\n');
fprintf(fid, 'Test whether the canonical `Phi1(x)` *shape* can be generated as a constrained, mechanistic functional of the barrier landscape `PT` (via `CDF(PT)`), without any amplitude-only fitting and without a large basis search.\n\n');

fprintf(fid, '## Strict PT-derived basis\n');
fprintf(fid, 'Computed on the canonical `xGrid` after mapping `x=(I-I_{peak}(T))/w(T)` using stored scaling parameters.\n\n');
fprintf(fid, '| term | definition |\n');
fprintf(fid, '|---|---|\n');
fprintf(fid, '| `CDF_PT_x` | `CDF(P_T)(x)` |\n');
fprintf(fid, '| `d_dx_CDF_PT_x` | `d/dx CDF(P_T)(x)` |\n');
fprintf(fid, '| `d2_dx2_CDF_PT_x` | `d^2/dx^2 CDF(P_T)(x)` (smooth-then-differentiate) |\n');
fprintf(fid, '| `x_times_d_dx_CDF_PT_x` | `x * d/dx CDF(P_T)(x)` |\n');
fprintf(fid, '| `x2_times_d2_dx2_CDF_PT_x` | `x^2 * d^2/dx^2 CDF(P_T)(x)` |\n');
fprintf(fid, '| `smoothed_curvature_like_x` | `movmean(d^2/dx^2 CDF(P_T), %d)` |\n\n', smoothWinX);

fprintf(fid, '## Combination policy\n');
fprintf(fid, '1-term candidates were scored individually.\n');
fprintf(fid, 'Then every 2-term PT-only model of the form `a*term_i + b*term_j` was scored, with `(a,b)` obtained by constrained least-squares *on the strict chosen pair* (no search over the coefficients, no ML).\n\n');

fprintf(fid, '## Metrics and robustness\n');
fprintf(fid, '- Cosine similarity and Pearson correlation use the finite common mask; cosine is zero-mean unit-L2.\n');
fprintf(fid, '- RMSE is after best scalar rescaling: `min_alpha ||Phi1 - alpha*psi||_2`.\n');
fprintf(fid, '- Even/odd uses reflection on `xGrid` and compares even-energy fractions: `even_fraction_match = |evenFrac(Phi1)-evenFrac(psi)|`.\n');
fprintf(fid, '- Robustness split: main uses `%s`, robustness uses `%s`.\n\n', caseAllField, caseExField);

fprintf(fid, '## Best PT-only model (by lowest normalized RMSE)\n\n');
fprintf(fid, '- Model: `%s` (n_terms=%d)\n', bestModel, nTerms(bestMi));
fprintf(fid, '- Main: cosine=%.6f, Pearson=%.6f, RMSE=%.6g, even_fraction_match=%.6f, RMSE_norm=%.6f\n', ...
    bestAll.cosine_similarity, bestAll.pearson, bestAll.RMSE_best_scalar_rescale, ...
    bestAll.even_fraction_match, bestAll.RMSE_norm_to_phi_rms);
fprintf(fid, '- Excl 22K: cosine=%.6f, Pearson=%.6f, RMSE=%.6g, even_fraction_match=%.6f, RMSE_norm=%.6f\n\n', ...
    bestEx.cosine_similarity, bestEx.pearson, bestEx.RMSE_best_scalar_rescale, ...
    bestEx.even_fraction_match, bestEx.RMSE_norm_to_phi_rms);

fprintf(fid, '## Baseline (canonical Phi1 shape)\n\n');
fprintf(fid, '- Phi1 vs Phi1 under the same finite-mask metric definitions is exact: cosine=1, Pearson=1, RMSE=0, even_fraction_match=0.\n');
fprintf(fid, '- This is the shape-level gold standard; PT-only models are judged by how close they get to this baseline on both RMSE and parity under the 22K robustness split.\n\n');

fprintf(fid, '## Final verdicts (required format)\n\n');
fprintf(fid, 'PHI1_FROM_PT_ALONE_SUPPORTED: %s\n', phiFromPtAloneVerd);
fprintf(fid, 'PHI1_REQUIRES_INDEPENDENT_COLLECTIVE_MODE: %s\n\n', requiresIndepVerd);

% Plain language interpretation required by user.
fprintf(fid, '## Interpretation (plain language)\n\n');
if phiFromPtAloneVerd == "YES"
    fprintf(fid, 'A strict, non-search PT-derived functional basis is sufficient to reproduce the canonical `Phi1(x)` shape competitively (including robustness under 22K exclusion). This supports the view that Phi1 is not an independent collective response mode but is induced by (and reducible to) PT/CDF structure.\n');
elseif phiFromPtAloneVerd == "PARTIAL"
    fprintf(fid, 'PT-derived differential/curvature-weighted descriptors capture a nontrivial part of Phi1’s symmetry/curvature structure, but the best PT-only combination still falls short of the canonical Phi1 shape quality (especially in normalized RMSE and/or robustness). This supports a “partial geometric resemblance” view: Phi1’s shape partly tracks barrier/CDF operators, but not fully reducible to PT alone.\n');
else
    fprintf(fid, 'No strict PT-derived basis (nor any constrained 2-term PT-only combination) reconstructs Phi1’s canonical shape competitively on both RMSE and parity. The result supports Phi1 as an independent collective residual mode (a structured switching-response component not generated by low-order PT/CDF differential operators alone).\n');
end

fprintf(fid, '\n*Auto-generated by `tools/run_phi1_from_pt_shape_test.m`.*\n');
fclose(fid);

markerAfterMdPath = fullfile(repoRoot, 'tables', '_phi1_from_pt_shape_test_marker_after_md.txt');
fidM = fopen(markerAfterMdPath, 'w');
fprintf(fidM, 'after_md %s\n', datestr(now));
fclose(fidM);

fprintf('Saved:\n  %s\n  %s\n', outCsvPath, outMdPath);

out = struct('outCsvPath', outCsvPath, 'outMdPath', outMdPath, ...
    'bestModel', bestModel, 'phiFromPtAloneVerd', phiFromPtAloneVerd, ...
    'requiresIndepVerd', requiresIndepVerd);
end

% ---------------- Helper functions ----------------
function [temps, Ipeak, Speak, width] = extractScalingColumns(tbl)
varNames = string(tbl.Properties.VariableNames);
temps = numericColumn(tbl, varNames, ["T_K","T"]);
Ipeak = numericColumn(tbl, varNames, ["Ipeak_mA","I_peak","Ipeak"]);
Speak = numericColumn(tbl, varNames, ["S_peak","Speak","Speak_peak"]); %#ok<NASGU>
width = numericColumn(tbl, varNames, ["width_chosen_mA","width_I","width"]);
end

function col = numericColumn(tbl, varNames, candidates)
col = NaN(height(tbl), 1);
for i = 1:numel(candidates)
    idx = find(varNames == candidates(i), 1, 'first');
    if isempty(idx)
        continue;
    end
    raw = tbl.(varNames(idx));
    if isnumeric(raw)
        col = double(raw(:));
    else
        col = str2double(string(raw(:)));
    end
    return;
end
end

function psiBasis = buildPsiCandidatesFromPT(ptTbl, tempsCase, currents, xGrid, IpeakByT, widthByT, smoothWinX) %#ok<INUSD>
% buildPsiCandidatesFromPT
% Returns a cell array psiBasis{termIdx} matching candidateNames order.
%
% Candidate set corresponds to:
%   1) CDF_PT_x
%   2) d_dx_CDF_PT_x
%   3) d2_dx2_CDF_PT_x
%   4) x_times_d_dx_CDF_PT_x
%   5) x2_times_d2_dx2_CDF_PT_x
%   6) smoothed_curvature_like_x

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
Kx2curv = NaN(nT, nx);

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
    Kx2curv(it, :) = ((xGrid(:).').^2 .* d2cdx2OnX(:).');
end

psiCDF = median(Kcdf, 1, 'omitnan').';
psiSlope = median(Kslope, 1, 'omitnan').';
psiCurv = median(Kcurv, 1, 'omitnan').';
psiXSlope = median(Kxslope, 1, 'omitnan').';
psiX2Curv = median(Kx2curv, 1, 'omitnan').';

% Nonlocal, still simple: smoothed curvature-like response.
psiCurvSmooth = movmean(psiCurv, smoothWinX, 'omitnan');

psiBasis = {psiCDF, psiSlope, psiCurv, psiXSlope, psiX2Curv, psiCurvSmooth};
end

function cdfRow = cdfFromPT(ptTemps, ptCurrents, PTvalues, targetT, currents)
% Recreates the PT-backed CDF(P_T)(I) using stored PT_matrix.csv.
ptTemps = double(ptTemps(:));
ptCurrents = double(ptCurrents(:));
currents = double(currents(:));

% Interpolate P_T(Ith) from PT_matrix across temperature for each I-grid point.
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

% Interpolate onto the canonical alignment current grid.
pOnCurrents = interp1(ptCurrents, pAtT, currents, 'linear', 0);
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
% Mirrors the existing intent of the physical kernel tests:
% smooth-then-second-derivative with a small local movmean.
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

% RMSE after best scalar rescaling (least squares scalar).
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
[evenFracPhi, ~, okPairs] = evenFraction(phi, xGrid, mask); %#ok<ASGLU>
[evenFracPsi, ~, ~] = evenFraction(psi, xGrid, mask);
if okPairs <= 2
    evenFracDiff = NaN;
else
    evenFracDiff = abs(evenFracPhi - evenFracPsi);
end
end

function [evenFrac, evenPart, nPairs] = evenFraction(vec, xGrid, mask)
% evenPart(x) = (f(x)+f(-x))/2 using interpolation at -x.
vec = double(vec(:));
xGrid = double(xGrid(:));
mask = mask(:);

evenPart = NaN(size(vec));

finiteAll = isfinite(xGrid) & isfinite(vec);
if nnz(finiteAll) < 5
    evenFrac = NaN; nPairs = 0;
    return;
end

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

function current = parseCurrentFromColumnName(name)
% Extract number from e.g. "Ith_15_mA" -> 15
s = regexprep(char(string(name)), '^Ith_', '', 'ignorecase');
s = regexprep(s, '_mA$', '', 'ignorecase');
s = strrep(s, '_', '.');
m = regexp(s, '[-+]?\d*\.?\d+', 'match', 'once');
current = str2double(m);
end

