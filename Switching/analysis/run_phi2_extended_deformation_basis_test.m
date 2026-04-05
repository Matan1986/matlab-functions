% run_phi2_extended_deformation_basis_test
% Agent — PHI2 extended deformation basis test
%
% Goal:
% Test whether Phi2 can be represented by an extended deformation basis built from Phi1:
%   Phi2 ~ a1*dPhi1_dx + a2*d2Phi1_dx2 + a3*(x.*Phi1) + a4*(x.^2.*Phi1)
%
% Deliverables:
%   tables/phi2_extended_deformation_basis.csv
%   reports/phi2_extended_deformation_basis.md
%   tables/phi2_extended_deformation_basis_status.csv
%
% Notes:
% - PURE SCRIPT (no function wrapper).
% - Uses canonical switching residual decomposition outputs to obtain {Phi1, Phi2, xGrid}.
% - Does not recompute any other pipeline beyond what's required to obtain Phi2 on the canonical x-grid.
% - Uses stable finite differences on the existing grid via gradient(phi1, xGrid).

fprintf('[RUN] phi2 extended deformation basis test\n');
set(0, 'DefaultFigureVisible', 'off');
clearvars;
clc;

repoRoot = 'C:/Dev/matlab-functions';
analysisDir = fullfile(repoRoot, 'Switching', 'analysis');

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(genpath(fullfile(repoRoot, 'tools')));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');
addpath(analysisDir, '-begin');

tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

outCsvPath = fullfile(tablesDir, 'phi2_extended_deformation_basis.csv');
outReportPath = fullfile(reportsDir, 'phi2_extended_deformation_basis.md');
outStatusCsvPath = fullfile(tablesDir, 'phi2_extended_deformation_basis_status.csv');
errorLogPath = fullfile(repoRoot, 'matlab_error.log');

executionStatus = "FAIL";
inputSource = "";
N_POINTS = NaN;
bestModelName = "";
bestCosine = NaN;
bestRmse = NaN;
extendedImproves = "NO";
phi2HigherOrder = "NO";
phi2Irreducible = "YES";

fitTbl = table();

try
    % ============================================================
    % REUSE MODE (CSV ONLY) — FAST + TYPE-SAFE
    % ============================================================
    csvPath = outCsvPath;
    % Use `isfile` as the primary check, with a fallback for robustness.
    useExistingFit = isfile(csvPath);
    if ~useExistingFit
        useExistingFit = exist(csvPath, 'file') == 2;
    end
    if useExistingFit
        inputSource = "CSV_REUSE";

        % Load and normalize CSV types.
        T = readtable(csvPath);

        % --- Safe field access (before any column usage) ---
        requiredCols = {'model_name', 'n_basis', 'cosine_similarity', 'rmse', 'rel_rmse', 'r_squared', ...
            'coeff_1', 'coeff_2', 'coeff_3', 'coeff_4', 'notes'};
        for ci = 1:numel(requiredCols)
            if ~ismember(requiredCols{ci}, T.Properties.VariableNames)
                error('Missing required CSV column: %s', requiredCols{ci});
            end
        end

        % --- Step 2 — Fix cell type errors by normalizing numeric columns ---
        % We only coerce if the column comes in as a cell array (common for mixed/NaN entries).
        numericCols = {'rmse', 'rel_rmse', 'cosine_similarity', 'r_squared', ...
            'coeff_1', 'coeff_2', 'coeff_3', 'coeff_4', 'n_basis'};
        for ni = 1:numel(numericCols)
            col = numericCols{ni};
            if iscell(T.(col))
                T.(col) = cellfun(@str2double, T.(col));
            end
        end

        % Ensure all numeric vectors are double row-safe.
        T.rmse = T.rmse(:);
        T.rel_rmse = T.rel_rmse(:);
        T.cosine_similarity = T.cosine_similarity(:);
        T.r_squared = T.r_squared(:);
        T.coeff_1 = T.coeff_1(:);
        T.coeff_2 = T.coeff_2(:);
        T.coeff_3 = T.coeff_3(:);
        T.coeff_4 = T.coeff_4(:);
        T.n_basis = T.n_basis(:);

        % --- Step 4 — Compute best model (reuse mode) ---
        rel = T.rel_rmse;
        rel(~isfinite(rel)) = inf;
        [~, idxBest] = min(rel);
        bestRow = T(idxBest, :);

        bestModelName = string(bestRow.model_name);
        bestCosine = bestRow.cosine_similarity(1);
        bestRmse = bestRow.rmse(1);
        bestRelRmse = bestRow.rel_rmse(1);

        % --- Step 5 — Define improvement metric ---
        prev_best_rmse = 0.0057; % from previous phi2 extended/2-basis benchmark
        if isfinite(bestRmse) && bestRmse < prev_best_rmse
            EXTENDED_BASIS_IMPROVES = "YES";
        else
            EXTENDED_BASIS_IMPROVES = "NO";
        end

        % --- Step 6 — Verdicts ---
        if isfinite(bestCosine) && isfinite(bestRelRmse) && (bestCosine > 0.9) && (bestRelRmse < 0.5)
            PHI2_HIGHER_ORDER_DEFORMATION = "YES";
        elseif isfinite(bestCosine) && (bestCosine > 0.8)
            PHI2_HIGHER_ORDER_DEFORMATION = "PARTIAL";
        else
            PHI2_HIGHER_ORDER_DEFORMATION = "NO";
        end

        if PHI2_HIGHER_ORDER_DEFORMATION == "YES"
            PHI2_IRREDUCIBLE_BEYOND_DEFORMATION = "NO";
        else
            PHI2_IRREDUCIBLE_BEYOND_DEFORMATION = "YES";
        end

        % Also compute best models per n_basis group.
        bestSingle = table();
        bestTwo = table();
        bestThree = table();
        bestFour = table();

        if any(T.n_basis == 1)
            S = T(T.n_basis == 1, :);
            r = S.rel_rmse; r(~isfinite(r)) = inf;
            [~, iS] = min(r);
            bestSingle = S(iS, :);
        end
        if any(T.n_basis == 2)
            S = T(T.n_basis == 2, :);
            r = S.rel_rmse; r(~isfinite(r)) = inf;
            [~, iS] = min(r);
            bestTwo = S(iS, :);
        end
        if any(T.n_basis == 3)
            S = T(T.n_basis == 3, :);
            r = S.rel_rmse; r(~isfinite(r)) = inf;
            [~, iS] = min(r);
            bestThree = S(iS, :);
        end
        if any(T.n_basis == 4)
            S = T(T.n_basis == 4, :);
            r = S.rel_rmse; r(~isfinite(r)) = inf;
            [~, iS] = min(r);
            bestFour = S(iS, :);
        end

        % --- Step 7 — Write markdown report ---
        lines = strings(0, 1);
        lines(end+1) = '# Phi2 extended deformation basis test (reuse mode)';
        lines(end+1) = '';
        lines(end+1) = '## Inputs';
        lines(end+1) = sprintf('- CSV path: `%s`', char(csvPath));
        lines(end+1) = '';

        lines(end+1) = '## Best models';
        if ~isempty(bestSingle)
            lines(end+1) = sprintf('- Best single basis (n_basis=1): %s (cosine=%.4f, rmse=%.6g, rel_rmse=%.6g)', ...
                char(string(bestSingle.model_name(1))), bestSingle.cosine_similarity(1), bestSingle.rmse(1), bestSingle.rel_rmse(1));
        else
            lines(end+1) = '- Best single basis (n_basis=1): not found';
        end
        if ~isempty(bestTwo)
            lines(end+1) = sprintf('- Best 2-basis model (n_basis=2): %s (cosine=%.4f, rmse=%.6g, rel_rmse=%.6g)', ...
                char(string(bestTwo.model_name(1))), bestTwo.cosine_similarity(1), bestTwo.rmse(1), bestTwo.rel_rmse(1));
        else
            lines(end+1) = '- Best 2-basis model (n_basis=2): not found';
        end
        if ~isempty(bestThree)
            lines(end+1) = sprintf('- Best 3-basis model (n_basis=3): %s (cosine=%.4f, rmse=%.6g, rel_rmse=%.6g)', ...
                char(string(bestThree.model_name(1))), bestThree.cosine_similarity(1), bestThree.rmse(1), bestThree.rel_rmse(1));
        else
            lines(end+1) = '- Best 3-basis model (n_basis=3): not found';
        end
        if ~isempty(bestFour)
            lines(end+1) = sprintf('- Best 4-basis model (n_basis=4): %s (cosine=%.4f, rmse=%.6g, rel_rmse=%.6g)', ...
                char(string(bestFour.model_name(1))), bestFour.cosine_similarity(1), bestFour.rmse(1), bestFour.rel_rmse(1));
        else
            lines(end+1) = '- Best 4-basis model (n_basis=4): not found';
        end
        lines(end+1) = '';

        lines(end+1) = '## Best overall model';
        lines(end+1) = sprintf('- Model: %s (cosine=%.4f, rmse=%.6g, rel_rmse=%.6g)', ...
            char(bestModelName), bestCosine, bestRmse, bestRelRmse);
        lines(end+1) = '';

        lines(end+1) = '## Comparison to previous 2-basis result';
        lines(end+1) = sprintf('- Previous best rmse reference: %.6g', prev_best_rmse);
        lines(end+1) = sprintf('- Current best rmse: %.6g', bestRmse);
        lines(end+1) = sprintf('- EXTENDED_BASIS_IMPROVES (best_rmse < prev_best_rmse): %s', char(EXTENDED_BASIS_IMPROVES));
        lines(end+1) = '';

        lines(end+1) = '## Verdicts';
        lines(end+1) = '- EXTENDED_BASIS_IMPROVES: ' + string(EXTENDED_BASIS_IMPROVES);
        lines(end+1) = '- PHI2_HIGHER_ORDER_DEFORMATION: ' + string(PHI2_HIGHER_ORDER_DEFORMATION);
        lines(end+1) = '- PHI2_IRREDUCIBLE_BEYOND_DEFORMATION: ' + string(PHI2_IRREDUCIBLE_BEYOND_DEFORMATION);
        lines(end+1) = '';

        % Explicit required verdict block at the end of the report.
        lines(end+1) = 'EXTENDED_BASIS_IMPROVES: ' + string(EXTENDED_BASIS_IMPROVES);
        lines(end+1) = 'PHI2_HIGHER_ORDER_DEFORMATION: ' + string(PHI2_HIGHER_ORDER_DEFORMATION);
        lines(end+1) = 'PHI2_IRREDUCIBLE_BEYOND_DEFORMATION: ' + string(PHI2_IRREDUCIBLE_BEYOND_DEFORMATION);
        lines(end+1) = '';

        fid = fopen(outReportPath, 'w');
        assert(fid ~= -1, 'Unable to open report for writing: %s', outReportPath);
        fprintf(fid, '%s\n', char(strjoin(lines, newline)));
        fclose(fid);

        % --- Step 8 — Write status CSV ---
        executionStatus = "SUCCESS";
        statusTbl = table();
        statusTbl.EXECUTION_STATUS = executionStatus;
        statusTbl.INPUT_SOURCE = "CSV_REUSE";
        statusTbl.BEST_MODEL = bestModelName;
        statusTbl.BEST_COSINE = bestCosine;
        statusTbl.BEST_RMSE = bestRmse;
        statusTbl.EXTENDED_BASIS_IMPROVES = EXTENDED_BASIS_IMPROVES;
        statusTbl.PHI2_HIGHER_ORDER_DEFORMATION = PHI2_HIGHER_ORDER_DEFORMATION;
        statusTbl.PHI2_IRREDUCIBLE_BEYOND_DEFORMATION = PHI2_IRREDUCIBLE_BEYOND_DEFORMATION;
        writetable(statusTbl, outStatusCsvPath);

        fprintf('[DONE] phi2 extended deformation basis test (reuse) -> %s\n', outReportPath);
        fprintf('[DONE] reuse status -> %s\n', outStatusCsvPath);
        return;
    end

    % ----------------------------
    % Canonical inputs (robust, absolute paths)
    % ----------------------------
    % Prefer the same canonical source as the recent phi2 deformation fit analysis:
    % (mirrors run_phi2_deformation_structure_test.m)
    alignmentRunId = 'run_2026_03_10_112659_alignment_audit';
    fullScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
    ptRunId = 'run_2026_03_24_212033_switching_barrier_distribution_from_map';

    alignmentCorePath = fullfile(switchingCanonicalRunRoot(repoRoot), alignmentRunId, ...
        'switching_alignment_core_data.mat');
    fullScalingParamsPath = fullfile(switchingCanonicalRunRoot(repoRoot), fullScalingRunId, ...
        'tables', 'switching_full_scaling_parameters.csv');
    ptMatrixPath = fullfile(switchingCanonicalRunRoot(repoRoot), ptRunId, ...
        'tables', 'PT_matrix.csv');

    % Existence checks (explicit for robustness).
    assert(exist(alignmentCorePath, 'file') == 2, 'Missing alignment core: %s', alignmentCorePath);
    assert(exist(fullScalingParamsPath, 'file') == 2, 'Missing full scaling params: %s', fullScalingParamsPath);
    assert(exist(ptMatrixPath, 'file') == 2, 'Missing PT matrix: %s', ptMatrixPath);

    % Reuse existing fit results when available (avoid expensive recomputation).
    useExistingFit = exist(outCsvPath, 'file') == 2;
    if useExistingFit
        requiredCols = {'model_name', 'n_basis', 'coeff_1', 'coeff_2', 'coeff_3', 'coeff_4', ...
            'cosine_similarity', 'rmse', 'rel_rmse', 'r_squared', 'notes'};
        try
            fitTblFull = readtable(outCsvPath);
            if all(ismember(requiredCols, fitTblFull.Properties.VariableNames))
                fitTblFull.rmse_unit = NaN(height(fitTblFull), 1);
                parsedMaskPoints = NaN;
                for i = 1:height(fitTblFull)
                    nt = string(fitTblFull.notes(i));
                    mRmse = regexp(nt, 'rmse_unit=([0-9eE+\\-\\.]+)', 'tokens', 'once');
                    if ~isempty(mRmse)
                        fitTblFull.rmse_unit(i) = str2double(mRmse{1});
                    end
                    if ~isfinite(parsedMaskPoints)
                        mPts = regexp(nt, 'mask_points=([0-9]+)', 'tokens', 'once');
                        if ~isempty(mPts)
                            parsedMaskPoints = str2double(mPts{1});
                        end
                    end
                end
                if isfinite(parsedMaskPoints)
                    N_POINTS = parsedMaskPoints;
                end
                fitTbl = fitTblFull(:, requiredCols);
            else
                useExistingFit = false;
            end
        catch
            useExistingFit = false;
        end
    end

    if ~useExistingFit
        cfg = struct();
    cfg.alignmentRunId = alignmentRunId;
    cfg.fullScalingRunId = fullScalingRunId;
    cfg.ptRunId = ptRunId;
    cfg.canonicalMaxTemperatureK = 30;
    cfg.nXGrid = 220;
    cfg.fallbackSmoothWindow = 5;
    cfg.skipFigures = true;
    cfg.maxModes = 2;
    cfg.minRowsForDecomposition = 5;

    outDec = switching_residual_decomposition_analysis(cfg);

    % Output variable discovery (robust column discovery using contains).
    % We do not assume any specific field ordering, only required canonical fields.
    decFields = fieldnames(outDec);
    if isfield(outDec, 'phi')
        phi1 = outDec.phi;
    else
        error('Phi1Missing: switching_residual_decomposition_analysis output lacks field `phi`.');
    end

    if isfield(outDec, 'phi2')
        phi2 = outDec.phi2;
    else
        error('Phi2Missing: switching_residual_decomposition_analysis output lacks field `phi2`.');
    end

    if isfield(outDec, 'xGrid')
        xGrid = outDec.xGrid;
    else
        error('XGridMissing: switching_residual_decomposition_analysis output lacks field `xGrid`.');
    end

    % ----------------------------
    % Shape alignment checks
    % ----------------------------
    xGrid = xGrid(:);
    phi1 = phi1(:);
    phi2 = phi2(:);

    n = numel(xGrid);
    assert(numel(phi1) == n, 'Phi1 length mismatch: numel(phi1)=%d, numel(xGrid)=%d', numel(phi1), n);
    assert(numel(phi2) == n, 'Phi2 length mismatch: numel(phi2)=%d, numel(xGrid)=%d', numel(phi2), n);
    assert(n >= 20, 'xGrid too short: %d', n);

    % Ensure xGrid is monotone increasing; if not, sort consistently.
    if any(diff(xGrid) <= 0)
        [xGrid, ord] = sort(xGrid, 'ascend');
        phi1 = phi1(ord);
        phi2 = phi2(ord);
    end

    % ----------------------------
    % Basis definitions (stable finite differences)
    % ----------------------------
    % b1 = dPhi1/dx
    % b2 = d2Phi1/dx2
    % b3 = x .* Phi1
    % b4 = x.^2 .* Phi1
    dPhi1dx = gradient(phi1, xGrid);
    d2Phi1dx2 = gradient(dPhi1dx, xGrid);
    xTimesPhi1 = xGrid .* phi1;
    x2TimesPhi1 = (xGrid .^ 2) .* phi1;

    % Convert to column vectors explicitly.
    b1 = dPhi1dx(:);
    b2 = d2Phi1dx2(:);
    b3 = xTimesPhi1(:);
    b4 = x2TimesPhi1(:);

    % ----------------------------
    % Fit mask and consistent vector shapes
    % ----------------------------
    % Exclude boundaries to stabilize derivatives.
    edgeExclude = 2;
    maskFit = isfinite(phi2) & isfinite(phi1) & isfinite(xGrid) & ...
        isfinite(b1) & isfinite(b2) & isfinite(b3) & isfinite(b4);

    if n > 2 * edgeExclude + 5
        maskFit(1:edgeExclude) = false;
        maskFit(end-edgeExclude+1:end) = false;
    end

    idxFit = find(maskFit);
    assert(numel(idxFit) >= 8, 'Not enough valid fit points after masking: %d', numel(idxFit));

    % Final consistent column vectors on the same grid subset.
    tRaw = phi2(idxFit);
    bRaw1 = b1(idxFit);
    bRaw2 = b2(idxFit);
    bRaw3 = b3(idxFit);
    bRaw4 = b4(idxFit);

    PhiNorm = norm(tRaw);
    assert(isfinite(PhiNorm) && PhiNorm > eps, 'Invalid ||Phi2|| on fit mask.');

    tUnit = tRaw ./ PhiNorm; % unit L2 target

    basisRaw = [bRaw1, bRaw2, bRaw3, bRaw4];
    basisNorms = zeros(1, 4);
    basisUnit = NaN(numel(idxFit), 4);
    for j = 1:4
        bn = norm(basisRaw(:, j));
        basisNorms(j) = bn;
        if isfinite(bn) && bn > eps
            basisUnit(:, j) = basisRaw(:, j) ./ bn;
        end
    end

    % ----------------------------
    % Helper metrics (inline logic, no functions)
    % ----------------------------
    basisNames = {...
        'dPhi1_dx', ...
        'd2Phi1_dx2', ...
        'x_times_Phi1', ...
        'x2_times_Phi1'};

    % Generate all model combinations: 1-basis, 2-basis, 3-basis, 4-basis.
    modelRows = [];
    modelNames = {};
    nBasisList = [];
    coeffMat = NaN(0, 4);
    cosineList = NaN(0, 1);
    rmseList = NaN(0, 1);
    relRmseList = NaN(0, 1);
    rmseUnitList = NaN(0, 1);
    r2List = NaN(0, 1);
    notesList = strings(0, 1);

    for k = 1:4
        combos = nchoosek(1:4, k);
        if k == 1
            combos = combos(:); % ensure consistent iteration
        end
        for ci = 1:size(combos, 1)
            if k == 1
                idxSet = combos(ci);
            else
                idxSet = combos(ci, :);
            end
            idxSet = idxSet(:).';

            % Skip ill-conditioned basis columns with near-zero norm.
            basisOk = true;
            for jj = idxSet
                if ~(isfinite(basisNorms(jj)) && basisNorms(jj) > eps)
                    basisOk = false;
                end
            end
            if ~basisOk
                continue;
            end

            Xunit = basisUnit(:, idxSet); % design matrix on unit-normalized basis

            % Unit-L2 LSQ fit.
            % Prefer mldivide; fall back to pinv if needed.
            coefUnit = NaN(1, k);
            predUnit = NaN(numel(idxFit), 1);
            yhatUnit = NaN(numel(idxFit), 1);
            try
                coefUnitVec = Xunit \ tUnit;
                if any(~isfinite(coefUnitVec))
                    error('NonFiniteCoef');
                end
                yhatUnit = Xunit * coefUnitVec;
                coefUnit = coefUnitVec(:).';
            catch
                coefUnitVec = pinv(Xunit) * tUnit;
                yhatUnit = Xunit * coefUnitVec;
                coefUnit = coefUnitVec(:).';
            end

            % Convert coefficients to raw basis coordinates.
            % If basisUnit(:,j) = basisRaw(:,j)/basisNorms(j) and tUnit = tRaw/PhiNorm,
            % then:
            %   predRaw = PhiNorm * predUnit
            %           = sum_j (PhiNorm * coefUnit_j / basisNorms(j)) * basisRaw_j
            coefRaw = NaN(1, 4);
            for jjk = 1:k
                jj = idxSet(jjk);
                coefRaw(jj) = (PhiNorm * coefUnit(jjk)) / max(basisNorms(jj), eps);
            end

            % Predicted raw target on the fit mask subset.
            yhatRaw = PhiNorm * yhatUnit;

            % Metrics on raw vectors (required: RMSE and rel_rmse vs ||Phi2||).
            err = tRaw - yhatRaw;
            rmse = sqrt(mean(err .^ 2, 'omitnan'));
            relRmse = rmse / max(PhiNorm, eps);

            cosSim = abs(dot(tRaw, yhatRaw) / (norm(tRaw) * norm(yhatRaw) + eps));

            % R^2 (explained variance) in a standard way; NaN if degenerate.
            yMean = mean(tRaw, 'omitnan');
            sse = sum(err .^ 2, 'omitnan');
            sst = sum((tRaw - yMean) .^ 2, 'omitnan');
            if ~(isfinite(sst) && sst > eps)
                r2 = NaN;
            else
                r2 = 1 - (sse / sst);
            end

            % rmse_unit for consistent comparison vs previous 2-basis test.
            errUnit = tUnit - yhatUnit;
            rmseUnit = sqrt(mean(errUnit .^ 2, 'omitnan'));

            modelNames{end+1, 1} = strjoin(basisNames(idxSet), ' + ');
            nBasisList(end+1, 1) = k;
            coeffMat(end+1, :) = coefRaw;
            cosineList(end+1, 1) = cosSim;
            rmseList(end+1, 1) = rmse;
            relRmseList(end+1, 1) = relRmse;
            rmseUnitList(end+1, 1) = rmseUnit;
            r2List(end+1, 1) = r2;
            notesList(end+1, 1) = "mask_points=" + string(numel(idxFit)) + ...
                "; edgeExclude=" + string(edgeExclude) + ...
                "; LSQ_unit_L2_design";
            % Keep rmse_unit in notes for verdict comparisons.
            notesList(end) = notesList(end) + "; rmse_unit=" + sprintf('%.6g', rmseUnit);
        end
    end

    if isempty(modelNames)
        error('NoValidModels: all basis subsets were skipped (zero-norm basis on mask).');
    end

    % Rank models best->worst (cosine desc, rmse asc).
    % We always rank by absolute cosine; RMSE by ascending (lower is better).
    % Note: r_squared is still computed but ranking does not depend on it.
    [~, ordCos] = sort(cosineList, 'descend');
    % Use rmse as secondary key (within blocks).
    ordCos = ordCos(:);
    % Stable tie-break: sort by cosine then rmse.
    Ttmp = table(modelNames, nBasisList, coeffMat(:, 1), coeffMat(:, 2), coeffMat(:, 3), coeffMat(:, 4), ...
        cosineList, rmseList, relRmseList, rmseUnitList, r2List, notesList, ...
        'VariableNames', {'model_name', 'n_basis', 'coeff_1', 'coeff_2', 'coeff_3', 'coeff_4', ...
        'cosine_similarity', 'rmse', 'rel_rmse', 'rmse_unit', 'r_squared', 'notes'});

    % Sort order:
    % 1) cosine_similarity desc
    % 2) rmse asc
    Ttmp = sortrows(Ttmp, {'cosine_similarity', 'rmse'}, {'descend', 'ascend'});
    fitTblFull = Ttmp;

    % Deliverable CSV columns (exact set required).
    fitTbl = fitTblFull(:, {'model_name', 'n_basis', 'coeff_1', 'coeff_2', 'coeff_3', 'coeff_4', ...
        'cosine_similarity', 'rmse', 'rel_rmse', 'r_squared', 'notes'});

    % Write CSV deliverable.
    writetable(fitTbl, outCsvPath);

    end % ~useExistingFit

    % ----------------------------
    % Baseline: previous failed 2-basis test
    % ----------------------------
    baselinePath = fullfile(tablesDir, 'phi2_deformation_fit.csv');
    assert(exist(baselinePath, 'file') == 2, 'Missing baseline: %s', baselinePath);
    baselineTbl = readtable(baselinePath);

    % Robustly locate baseline row via contains.
    baseMask = false(height(baselineTbl), 1);
    for i = 1:height(baselineTbl)
        baseMask(i) = contains(string(baselineTbl.model(i)), 'a_dPhi1_dx_plus_b_xPhi1');
    end
    assert(any(baseMask), 'Baseline row not found for model a_dPhi1_dx_plus_b_xPhi1 in %s', baselinePath);

    baseCos = baselineTbl.cosine_similarity(baseMask);
    baseRmseUnit = baselineTbl.rmse_reconstruction(baseMask);

    % If multiple matches (shouldn't happen), pick the first.
    baseCos = baseCos(1);
    baseRmseUnit = baseRmseUnit(1);

    % Best models by model size (use fitTblFull for rmse_unit verdict logic).
    bestSingle = fitTbl(fitTbl.n_basis == 1, :);
    bestTwo = fitTbl(fitTbl.n_basis == 2, :);
    bestThree = fitTbl(fitTbl.n_basis == 3, :);
    bestFour = fitTbl(fitTbl.n_basis == 4, :);

    if ~isempty(bestSingle)
        bestSingle = bestSingle(1, :);
    end
    if ~isempty(bestTwo)
        bestTwo = bestTwo(1, :);
    end
    if ~isempty(bestThree)
        bestThree = bestThree(1, :);
    end
    if ~isempty(bestFour)
        bestFour = bestFour(1, :);
    end

    bestExtendedCandFull = fitTblFull(fitTblFull.n_basis >= 3, :);
    assert(~isempty(bestExtendedCandFull), 'No extended models found.');
    bestExtendedFull = bestExtendedCandFull(1, :);
    bestExtended = bestExtendedFull(:, fitTbl.Properties.VariableNames);

    bestExtendedRmseUnit = bestExtendedFull.rmse_unit(1);

    bestFourFull = fitTblFull(fitTblFull.n_basis == 4, :);
    if ~isempty(bestFourFull)
        bestFourRmseUnit = bestFourFull.rmse_unit(1);
        bestFourCos = bestFourFull.cosine_similarity(1);
    else
        bestFourRmseUnit = NaN;
        bestFourCos = NaN;
    end

    % Coefficient-based indicator for higher-order terms.
    bestExtendedCoeffs = [bestExtended.coeff_1(1), bestExtended.coeff_2(1), bestExtended.coeff_3(1), bestExtended.coeff_4(1)];
    bestExtendedCoeffs(isnan(bestExtendedCoeffs)) = 0;
    higherOrderWeight = abs(bestExtendedCoeffs(2)) + abs(bestExtendedCoeffs(4));
    mainWeight = abs(bestExtendedCoeffs(1)) + abs(bestExtendedCoeffs(3));
    if mainWeight <= eps
        mainWeight = eps;
    end
    higherOrderRatio = higherOrderWeight / mainWeight;

    % ----------------------------
    % Verdicts (strict, verdict-driven)
    % ----------------------------
    % EXTENDED_BASIS_IMPROVES compares best n_basis>=3 against previous 2-basis baseline.
    % Baseline rmse is on unit-L2 space (see phi2_deformation_fit.csv).
    % We require a "material" improvement.
    if isfinite(baseRmseUnit) && isfinite(bestExtendedRmseUnit)
        rmseImproves = bestExtendedRmseUnit <= baseRmseUnit * 0.90;
    else
        rmseImproves = false;
    end

    bestExtendedCos = bestExtended.cosine_similarity(1);
    cosImproves = isfinite(baseCos) && (bestExtendedCos >= baseCos + 0.05);

    if rmseImproves || cosImproves
        extendedImproves = "YES";
    else
        extendedImproves = "NO";
    end

    % PHI2_HIGHER_ORDER_DEFORMATION
    if strcmp(extendedImproves, "YES")
        % Require some meaningful usage of higher-order basis terms (b2 or b4).
        if higherOrderRatio >= 0.15
            phi2HigherOrder = "YES";
        else
            phi2HigherOrder = "PARTIAL";
        end
    else
        % If cosine improves a bit but rmse doesn't, call it partial at most.
        if bestExtendedCos >= baseCos + 0.02 && isfinite(bestExtendedRmseUnit) && bestExtendedRmseUnit <= baseRmseUnit * 0.97
            phi2HigherOrder = "PARTIAL";
        else
            phi2HigherOrder = "NO";
        end
    end

    % PHI2_IRREDUCIBLE_BEYOND_DEFORMATION
    % We treat "proper closure" as: high cosine AND small unit-space RMSE.
    % This avoids false confidence from cosine alone.
    properCosThreshold = 0.90;
    properRmseUnitThreshold = 0.02;
    properClosure = isfinite(bestFourCos) && isfinite(bestFourRmseUnit) && ...
        (bestFourCos >= properCosThreshold) && (bestFourRmseUnit <= properRmseUnitThreshold);

    if properClosure
        phi2Irreducible = "NO";
    else
        phi2Irreducible = "YES";
    end

    % ----------------------------
    % Physical interpretation (concise)
    % ----------------------------
    if strcmp(phi2Irreducible, "YES")
        physicalInterpretation = "irreducible residual mode";
    else
        if higherOrderRatio >= 0.30
            physicalInterpretation = "higher-order deformation";
        else
            physicalInterpretation = "simple deformation";
        end
    end

    % ----------------------------
    % Markdown report deliverable
    % ----------------------------
    lines = strings(0, 1);
    lines(end+1) = '# Phi2 extended deformation basis test';
    lines(end+1) = '';
    lines(end+1) = '## Exact inputs used';
    lines(end+1) = '- Alignment core: `' + string(alignmentCorePath) + '`';
    lines(end+1) = '- Full scaling parameters: `' + string(fullScalingParamsPath) + '`';
    lines(end+1) = '- PT matrix: `' + string(ptMatrixPath) + '`';
    lines(end+1) = '- Canonical decomposition window: `T <= 30 K`';
    lines(end+1) = '- Canonical x-grid: `nXGrid = 220` points';
    lines(end+1) = '';
    lines(end+1) = '## Basis definitions (built from Phi1 on the canonical x-grid)';
    lines(end+1) = '- `b1(x) = dPhi1/dx` (gradient on existing grid)';
    lines(end+1) = '- `b2(x) = d2Phi1/dx2` (second gradient)';
    lines(end+1) = '- `b3(x) = x * Phi1`';
    lines(end+1) = '- `b4(x) = x^2 * Phi1`';
    lines(end+1) = '';
    lines(end+1) = '## Fit methodology (unit-L2 stable least squares)';
    lines(end+1) = '- All vectors are aligned to the same canonical `xGrid` and converted to column vectors.';
    lines(end+1) = '- Finite-difference basis is evaluated for all grid points; the fit mask excludes boundary points (`edgeExclude = ' + string(edgeExclude) + '`) to reduce derivative edge artifacts.';
    lines(end+1) = '- Each basis column is L2-normalized on the fit mask; the target `Phi2` is L2-normalized; coefficients are obtained via least squares: `Xunit \\ tUnit`.';
    lines(end+1) = '- Output metrics are computed back on the raw scale of `Phi2` for `rmse`, `rel_rmse`, `r_squared` (cosine uses absolute alignment).';
    lines(end+1) = '';

    % Best single / two / three / four from computed table.
    lines(end+1) = '## Best single basis';
    if ~isempty(bestSingle)
        lines(end+1) = sprintf('- %s (cosine=%.4f, rmse=%.6g)', bestSingle.model_name(1), bestSingle.cosine_similarity(1), bestSingle.rmse(1));
    else
        lines(end+1) = '- (not found; basis columns may be degenerate on the fit mask)';
    end
    lines(end+1) = '';

    lines(end+1) = '## Best 2-basis model';
    if ~isempty(bestTwo)
        lines(end+1) = sprintf('- %s (cosine=%.4f, rmse=%.6g)', bestTwo.model_name(1), bestTwo.cosine_similarity(1), bestTwo.rmse(1));
    else
        lines(end+1) = '- (not found; basis columns may be degenerate on the fit mask)';
    end
    lines(end+1) = '';

    if ~isempty(bestThree) && any(fitTbl.n_basis == 3)
        lines(end+1) = '## Best 3-basis model';
        lines(end+1) = sprintf('- %s (cosine=%.4f, rmse=%.6g)', bestThree.model_name(1), bestThree.cosine_similarity(1), bestThree.rmse(1));
        lines(end+1) = '';
    else
        lines(end+1) = '## Best 3-basis model';
        lines(end+1) = '- (not found; basis columns may be degenerate on the fit mask)';
        lines(end+1) = '';
    end

    if ~isempty(bestFour) && any(fitTbl.n_basis == 4)
        lines(end+1) = '## Best full 4-basis model';
        lines(end+1) = sprintf('- %s (cosine=%.4f, rmse=%.6g)', bestFour.model_name(1), bestFour.cosine_similarity(1), bestFour.rmse(1));
        lines(end+1) = '';
    else
        lines(end+1) = '## Best full 4-basis model';
        lines(end+1) = '- (not found; basis columns may be degenerate on the fit mask)';
        lines(end+1) = '';
    end

    % Compare extended vs previous failed 2-basis test.
    lines(end+1) = '## Extended basis improvement vs previous failed 2-basis test';
    lines(end+1) = '- Previous 2-basis baseline (`a_dPhi1_dx_plus_b_xPhi1`) from `tables/phi2_deformation_fit.csv`:';
    lines(end+1) = sprintf('  - cosine(Phi2, recon)=%.4f', baseCos);
    lines(end+1) = sprintf('  - rmse_unit(recon vs Phi2)=%.6g (unit-L2 metric)', baseRmseUnit);
    lines(end+1) = '- Best extended model among `n_basis>=3`:';
    lines(end+1) = sprintf('  - model=%s', bestExtended.model_name(1));
    lines(end+1) = sprintf('  - cosine(Phi2, recon)=%.4f', bestExtended.cosine_similarity(1));
    lines(end+1) = sprintf('  - rmse_unit(recon vs Phi2)=%.6g (unit-L2 metric)', bestExtendedRmseUnit);
    lines(end+1) = '- Extended basis materially improves over the baseline: **' + extendedImproves + '**';
    lines(end+1) = '';

    % Interpretation
    lines(end+1) = '## Concise physical interpretation';
    lines(end+1) = '- Verdict direction: **' + physicalInterpretation + '**';
    lines(end+1) = '';
    lines(end+1) = '## Final verdicts';
    lines(end+1) = '- `EXTENDED_BASIS_IMPROVES: ' + extendedImproves + '`';
    lines(end+1) = '- `PHI2_HIGHER_ORDER_DEFORMATION: ' + phi2HigherOrder + '`';
    lines(end+1) = '- `PHI2_IRREDUCIBLE_BEYOND_DEFORMATION: ' + phi2Irreducible + '`';
    lines(end+1) = '';

    fid = fopen(outReportPath, 'w');
    assert(fid ~= -1, 'Unable to open report for writing: %s', outReportPath);
    fprintf(fid, '%s\n', char(strjoin(lines, newline)));
    fclose(fid);

    % ----------------------------
    % Status CSV deliverable
    % ----------------------------
    executionStatus = "SUCCESS";
    % In reuse mode (`useExistingFit==true`), idxFit may not exist.
    if ~isfinite(N_POINTS)
        if exist('idxFit', 'var') == 1
            N_POINTS = numel(idxFit);
        end
    end
    bestRow = fitTbl(1, :);
    bestModelName = string(bestRow.model_name(1));
    bestCosine = bestRow.cosine_similarity(1);
    bestRmse = bestRow.rmse(1);
    extendedImproves = string(extendedImproves);
    phi2HigherOrder = string(phi2HigherOrder);
    phi2Irreducible = string(phi2Irreducible);

    inputSource = sprintf(['switching_residual_decomposition_analysis (canonical sources) | alignmentRunId=%s | fullScalingRunId=%s | ptRunId=%s'], ...
        alignmentRunId, fullScalingRunId, ptRunId);

    statusTbl = table();
    statusTbl.EXECUTION_STATUS = executionStatus;
    statusTbl.INPUT_SOURCE = {inputSource};
    statusTbl.N_POINTS = N_POINTS;
    statusTbl.BEST_MODEL = {bestModelName};
    statusTbl.BEST_COSINE = bestCosine;
    statusTbl.BEST_RMSE = bestRmse;
    statusTbl.EXTENDED_BASIS_IMPROVES = extendedImproves;
    statusTbl.PHI2_HIGHER_ORDER_DEFORMATION = phi2HigherOrder;
    statusTbl.PHI2_IRREDUCIBLE_BEYOND_DEFORMATION = phi2Irreducible;

    writetable(statusTbl, outStatusCsvPath);

catch ME
    % ----------------------------
    % Failure handling: emit status artifact even on partial failure
    % ----------------------------
    executionStatus = "FAIL";

    % Try to write whatever exists.
    try
        if ~isempty(fitTbl) && (istable(fitTbl) || isstruct(fitTbl))
            if istable(fitTbl) && height(fitTbl) > 0
                writetable(fitTbl, outCsvPath);
            end
        end
    catch
        % best-effort only
    end

    % Write status CSV with best-effort fields.
    try
        statusTbl = table();
        statusTbl.EXECUTION_STATUS = executionStatus;
        statusTbl.INPUT_SOURCE = {inputSource};
        statusTbl.N_POINTS = N_POINTS;
        statusTbl.BEST_MODEL = {bestModelName};
        statusTbl.BEST_COSINE = bestCosine;
        statusTbl.BEST_RMSE = bestRmse;
        statusTbl.EXTENDED_BASIS_IMPROVES = extendedImproves;
        statusTbl.PHI2_HIGHER_ORDER_DEFORMATION = phi2HigherOrder;
        statusTbl.PHI2_IRREDUCIBLE_BEYOND_DEFORMATION = phi2Irreducible;
        statusTbl.ERROR_MESSAGE = {ME.message};
        if ~isempty(Me.identifier)
            statusTbl.ERROR_IDENTIFIER = {ME.identifier};
        end
        writetable(statusTbl, outStatusCsvPath);
    catch
        % ignore
    end

    % Append to error log
    try
        fidErr = fopen(errorLogPath, 'a');
        if fidErr ~= -1
            fprintf(fidErr, '%s\n', getReport(ME, 'extended'));
            fclose(fidErr);
        end
    catch
        % ignore
    end

    % Emit minimal report describing failure
    try
        fid = fopen(outReportPath, 'w');
        if fid ~= -1
            fprintf(fid, '# Phi2 extended deformation basis test\n\n');
            fprintf(fid, 'FAIL\n\n');
            fprintf(fid, 'Error: %s\n', ME.message);
            fclose(fid);
        end
    catch
        % ignore
    end
end

fprintf('[DONE] phi2 extended deformation basis test -> %s\n', outCsvPath);

