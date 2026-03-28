% run_phi1_phi2_observable_closure_fixed
% Clean rerun of observable closure analysis after O2 pipeline fix.
% Pure script only (no functions).

repoRoot = 'C:/Dev/matlab-functions';

o2AlignedCsvPath = fullfile(repoRoot, 'tables', 'o2_observables_aligned.csv');
kappaCsvPath = fullfile(repoRoot, 'tables', 'closure_metrics_per_temperature.csv');

outCsvPath = fullfile(repoRoot, 'tables', 'phi1_phi2_observable_closure_fixed.csv');
outMdPath = fullfile(repoRoot, 'reports', 'phi1_phi2_observable_closure_fixed.md');
outStatusCsvPath = fullfile(repoRoot, 'tables', 'phi1_phi2_observable_closure_fixed_status.csv');

% O2 observables expected from the aligned O2 pipeline.
o2Vars = {'antisymmetric_integral', 'slope_difference', 'local_curvature_window'};

executionStatus = "FAIL";
O2_USED_SUCCESSFULLY = "NO";
KAPPA2_OBSERVABLE_SIGNATURE_FOUND = "NO";
TWO_OBSERVABLE_CLOSURE_IMPROVES = "NO";
MINIMAL_2D_OBSERVABLE_FOUND = "NO";

ERROR_TEXT = "";

resultsTbl = table();
statusTbl = table();
mdLines = strings(0, 1);

% Ensure output directories exist.
outDirCsv = fileparts(outCsvPath);
outDirMd = fileparts(outMdPath);
outDirStatus = fileparts(outStatusCsvPath);
if exist(outDirCsv, 'dir') ~= 7, mkdir(outDirCsv); end
if exist(outDirMd, 'dir') ~= 7, mkdir(outDirMd); end
if exist(outDirStatus, 'dir') ~= 7, mkdir(outDirStatus); end

% Verdict thresholds.
% "If improvement over baseline is tiny → treat as NO"
improvementRatioTinyThreshold = 0.02; % 2% RMSE improvement ratio
improvementAbsTinyThreshold = 1e-6;   % absolute guard

try
    % --------------------------
    % Load inputs
    % --------------------------
    if exist(o2AlignedCsvPath, 'file') ~= 2
        error('closure_fixed:MissingO2Aligned', 'Missing O2 aligned CSV: %s', o2AlignedCsvPath);
    end
    if exist(kappaCsvPath, 'file') ~= 2
        error('closure_fixed:MissingKappa', 'Missing canonical kappa CSV: %s', kappaCsvPath);
    end

    T_o2A = readtable(o2AlignedCsvPath, 'VariableNamingRule', 'preserve');
    T_k = readtable(kappaCsvPath, 'VariableNamingRule', 'preserve');

    % --------------------------
    % Required checks BEFORE modeling (CRITICAL)
    % --------------------------
    disp('INPUT TABLE COLUMNS:')
    disp(T_o2A.Properties.VariableNames)

    requiredCols = {'kappa1', 'kappa2', o2Vars{:}};
    % Some columns (kappa1/kappa2) are expected in aligned table, but we will
    % recompute them from canonical kappa CSV after manual alignment.
    % Still check that O2 columns exist now.
    requiredO2Cols = [o2Vars];

    anyMissing = false;
    missingList = strings(0, 1);
    for i = 1:numel(requiredO2Cols)
        if ~any(strcmp(T_o2A.Properties.VariableNames, requiredO2Cols{i}))
            anyMissing = true;
            missingList(end+1) = requiredO2Cols{i}; %#ok<SAGROW>
        end
    end
    if anyMissing
        error('closure_fixed:MissingO2Columns', 'Missing O2 columns in aligned input: %s', strjoin(missingList, ', '));
    end

    % Find T_K column in O2 aligned table.
    vnO2 = string(T_o2A.Properties.VariableNames);
    tIdxO2 = find(contains(lower(vnO2), 't_k') | (vnO2 == "T_K"), 1, 'first');
    if isempty(tIdxO2)
        tIdxO2 = find(vnO2 == "T_K", 1, 'first');
    end
    if isempty(tIdxO2)
        error('closure_fixed:MissingT_K_O2', 'Could not find T_K column in O2 aligned table.');
    end
    T_o2_T = double(T_o2A.(vnO2(tIdxO2))(:));

    % NaN counts per column (in O2 aligned table).
    disp('NaN counts per input column:')
    for i = 1:numel(T_o2A.Properties.VariableNames)
        name = T_o2A.Properties.VariableNames{i};
        col = T_o2A{:, i};
        nanCount = 0;
        if isnumeric(col)
            nanCount = sum(isnan(col));
        else
            % Non-numeric columns: count missing via ismissing.
            nanCount = sum(ismissing(col));
        end
        fprintf('%s: %d NaNs\n', name, nanCount);
    end

    % Extract kappa1/kappa2 from canonical kappa table with robust detection.
    vnK = string(T_k.Properties.VariableNames);

    % kappa2: prefer kappa2_M3.
    k2Cands = vnK(contains(lower(vnK), 'kappa2'));
    if isempty(k2Cands)
        error('closure_fixed:MissingKappa2', 'Canonical kappa table missing kappa2 columns.');
    end
    k2Pick = k2Cands(contains(lower(k2Cands), 'm3'));
    if isempty(k2Pick), k2Pick = k2Cands(1); else, k2Pick = k2Pick(1); end
    kappa2 = double(T_k.(k2Pick)(:));

    % kappa1: prefer kappa1_M3.
    k1Cands = vnK(contains(lower(vnK), 'kappa1'));
    if isempty(k1Cands)
        error('closure_fixed:MissingKappa1', 'Canonical kappa table missing kappa1 columns.');
    end
    k1Pick = k1Cands(contains(lower(k1Cands), 'm3'));
    if isempty(k1Pick), k1Pick = k1Cands(1); else, k1Pick = k1Pick(1); end
    kappa1 = double(T_k.(k1Pick)(:));

    % Temperature column in canonical kappa table.
    tIdxK = find(contains(lower(vnK), 't_k'), 1, 'first');
    if isempty(tIdxK)
        tIdxK = find(vnK == "T", 1, 'first');
    end
    if isempty(tIdxK)
        error('closure_fixed:MissingT_K_Kappa', 'Could not detect temperature column in canonical kappa table.');
    end
    T_k_T = double(T_k.(vnK(tIdxK))(:));

    % --------------------------
    % Manual alignment (no innerjoin)
    % --------------------------
    T_common = intersect(T_o2_T(:), T_k_T(:), 'stable');
    T_common = T_common(isfinite(T_common));
    if isempty(T_common) || numel(T_common) < 4
        error('closure_fixed:TooFewAlignedPoints', 'Too few common temperatures: %d', numel(T_common));
    end

    T_aligned = table(T_common, 'VariableNames', {'T_K'});
    % O2 predictors from aligned O2 table
    [~, locO2] = ismember(T_common, T_o2_T);
    for i = 1:numel(o2Vars)
        T_aligned.(o2Vars{i}) = double(T_o2A.(o2Vars{i})(locO2));
    end
    % kappa from canonical kappa table
    [~, locK] = ismember(T_common, T_k_T);
    T_aligned.kappa1 = double(kappa1(locK));
    T_aligned.kappa2 = double(kappa2(locK));

    % Post-alignment NaN counts and required column verification.
    disp('Aligned TABLE COLUMNS:')
    disp(T_aligned.Properties.VariableNames)
    disp('NaN counts per aligned column:')
    for i = 1:numel(T_aligned.Properties.VariableNames)
        col = T_aligned{:, i};
        fprintf('%s: %d NaNs\n', T_aligned.Properties.VariableNames{i}, sum(isnan(col)));
    end

    neededAllCols = {'kappa1', 'kappa2', o2Vars{:}};
    for i = 1:numel(neededAllCols)
        if ~any(strcmp(T_aligned.Properties.VariableNames, neededAllCols{i}))
            error('closure_fixed:MissingColumnAfterAlign', 'Missing required column after alignment: %s', neededAllCols{i});
        end
    end

    % Availability checks for O2.
    validAll = isfinite(T_aligned.kappa2);
    for i = 1:numel(o2Vars)
        validAll = validAll & isfinite(T_aligned.(o2Vars{i}));
    end
    N_VALID_POINTS_ALL = nnz(validAll);

    for i = 1:numel(o2Vars)
        col = T_aligned.(o2Vars{i});
        if ~any(isfinite(col))
            error('closure_fixed:O2AllNaN', 'O2 column all NaN: %s', o2Vars{i});
        end
    end

    if N_VALID_POINTS_ALL < 4
        error('closure_fixed:O2InsufficientPoints', 'Insufficient finite aligned points for modeling: %d', N_VALID_POINTS_ALL);
    end
    O2_USED_SUCCESSFULLY = "YES";

    % --------------------------
    % Modeling helpers (LOOCV + baseline + correlations)
    % --------------------------
    % NOTE: No helper functions; implemented inline via repeated blocks.

    % Build combinations of predictor indices.
    % Order in o2Vars: [1]=antisymmetric_integral, [2]=slope_difference, [3]=local_curvature_window
    predictorCount = numel(o2Vars);
    singleIdx = num2cell(1:predictorCount);
    pairIdx = {[1,2], [1,3], [2,3]};
    tripleIdx = {[1,2,3]};

    % Storage for models: target, predictors, rmse metrics.
    modelRows = table();

    % Baseline RMSE is LOOCV RMSE for constant mean model using the same valid subset.
    % Pearson/Spearman computed on the same LOOCV subset.

    % --------------------------
    % κ1 sanity models
    % --------------------------
    kappaTargetsToRun = {'kappa1', 'kappa2'};
    % κ1: singles + pairs
    k1Combs = {};
    for i = 1:numel(singleIdx), k1Combs{end+1} = singleIdx{i}; end %#ok<SAGROW>
    for i = 1:numel(pairIdx), k1Combs{end+1} = pairIdx{i}; end %#ok<SAGROW>

    for ci = 1:numel(k1Combs)
        predIdx = k1Combs{ci};
        preds = o2Vars(predIdx);

        y = double(T_aligned.kappa1(:));
        X = NaN(height(T_aligned), numel(preds));
        for j = 1:numel(preds)
            X(:, j) = double(T_aligned.(preds{j})(:));
        end

        modelMask = isfinite(y);
        for j = 1:numel(preds)
            modelMask = modelMask & isfinite(X(:, j));
        end

        ySub = y(modelMask);
        XSub = X(modelMask, :);
        nSub = numel(ySub);

        rmseBaseline = NaN; pearsonR = NaN; spearmanR = NaN; loocvRmse = NaN;
        improvementAbs = NaN; improvementRatio = NaN;

        minTrainPoints = size(XSub, 2) + 2; % degrees guard

        if nSub >= minTrainPoints
            yhatBase = NaN(nSub, 1);
            yhatModel = NaN(nSub, 1);
            for i = 1:nSub
                tr = true(nSub, 1);
                tr(i) = false;
                ytr = ySub(tr);
                Xtr = XSub(tr, :);

                baseMean = mean(ytr, 'omitnan');
                yhatBase(i) = baseMean;

                XtrAug = [ones(nnz(tr), 1), Xtr];
                beta = XtrAug \ ytr;
                xAug = [1, XSub(i, :)];
                yhatModel(i) = xAug * beta;
            end

            residModel = ySub - yhatModel;
            residBase = ySub - yhatBase;

            loocvRmse = sqrt(mean(residModel.^2, 'omitnan'));
            rmseBaseline = sqrt(mean(residBase.^2, 'omitnan'));

            good = isfinite(ySub) & isfinite(yhatModel);
            pearsonR = corr(ySub(good), yhatModel(good), 'Type', 'Pearson', 'Rows', 'complete');
            spearmanR = corr(ySub(good), yhatModel(good), 'Type', 'Spearman', 'Rows', 'complete');

            improvementAbs = rmseBaseline - loocvRmse;
            improvementRatio = improvementAbs / max(rmseBaseline, eps);
        end

        modelRows = [modelRows; table( ...
            string("kappa1"), ...
            string(strjoin(preds, "+")), ...
            numel(preds), ...
            rmseBaseline, ...
            pearsonR, ...
            spearmanR, ...
            loocvRmse, ...
            improvementAbs, ...
            improvementRatio, ...
            nSub, ...
            'VariableNames', { ...
            'target', 'predictor_set', 'n_predictors', ...
            'baseline_rmse', 'pearson_r', 'spearman_r', ...
            'loocv_rmse', 'rmse_improvement_abs', 'rmse_improvement_ratio', ...
            'n_valid_points'} )]; %#ok<AGROW>
    end

    % --------------------------
    % κ2 main models: singles, pairs, triple
    % --------------------------
    k2Combs = {};
    for i = 1:numel(singleIdx), k2Combs{end+1} = singleIdx{i}; end %#ok<SAGROW>
    for i = 1:numel(pairIdx), k2Combs{end+1} = pairIdx{i}; end %#ok<SAGROW>
    for i = 1:numel(tripleIdx), k2Combs{end+1} = tripleIdx{i}; end %#ok<SAGROW>

    for ci = 1:numel(k2Combs)
        predIdx = k2Combs{ci};
        preds = o2Vars(predIdx);

        y = double(T_aligned.kappa2(:));
        X = NaN(height(T_aligned), numel(preds));
        for j = 1:numel(preds)
            X(:, j) = double(T_aligned.(preds{j})(:));
        end

        modelMask = isfinite(y);
        for j = 1:numel(preds)
            modelMask = modelMask & isfinite(X(:, j));
        end

        ySub = y(modelMask);
        XSub = X(modelMask, :);
        nSub = numel(ySub);

        rmseBaseline = NaN; pearsonR = NaN; spearmanR = NaN; loocvRmse = NaN;
        improvementAbs = NaN; improvementRatio = NaN;

        minTrainPoints = size(XSub, 2) + 2; % degrees guard

        if nSub >= minTrainPoints
            yhatBase = NaN(nSub, 1);
            yhatModel = NaN(nSub, 1);
            for i = 1:nSub
                tr = true(nSub, 1);
                tr(i) = false;
                ytr = ySub(tr);
                Xtr = XSub(tr, :);

                baseMean = mean(ytr, 'omitnan');
                yhatBase(i) = baseMean;

                XtrAug = [ones(nnz(tr), 1), Xtr];
                beta = XtrAug \ ytr;
                xAug = [1, XSub(i, :)];
                yhatModel(i) = xAug * beta;
            end

            residModel = ySub - yhatModel;
            residBase = ySub - yhatBase;

            loocvRmse = sqrt(mean(residModel.^2, 'omitnan'));
            rmseBaseline = sqrt(mean(residBase.^2, 'omitnan'));

            good = isfinite(ySub) & isfinite(yhatModel);
            pearsonR = corr(ySub(good), yhatModel(good), 'Type', 'Pearson', 'Rows', 'complete');
            spearmanR = corr(ySub(good), yhatModel(good), 'Type', 'Spearman', 'Rows', 'complete');

            improvementAbs = rmseBaseline - loocvRmse;
            improvementRatio = improvementAbs / max(rmseBaseline, eps);
        end

        modelRows = [modelRows; table( ...
            string("kappa2"), ...
            string(strjoin(preds, "+")), ...
            numel(preds), ...
            rmseBaseline, ...
            pearsonR, ...
            spearmanR, ...
            loocvRmse, ...
            improvementAbs, ...
            improvementRatio, ...
            nSub, ...
            'VariableNames', { ...
            'target', 'predictor_set', 'n_predictors', ...
            'baseline_rmse', 'pearson_r', 'spearman_r', ...
            'loocv_rmse', 'rmse_improvement_abs', 'rmse_improvement_ratio', ...
            'n_valid_points'} )]; %#ok<AGROW>
    end

    % --------------------------
    % Ranking and verdicts
    % --------------------------
    % Rank models by loocv_rmse (best first) within each target.
    % Sort models by LOOCV RMSE (best first). Keep target grouping stable.
    modelRows = sortrows(modelRows, {'target', 'loocv_rmse'}, 'ascend');

    k2Rows = modelRows(modelRows.target == "kappa2", :);
    k1Rows = modelRows(modelRows.target == "kappa1", :); %#ok<NASGU>

    bestK2Rmse = min(k2Rows.loocv_rmse, [], 'omitnan');
    bestK2 = table();
    bestK2ImprovementRatio = NaN;
    bestK2ImprovementAbs = NaN;
    if isfinite(bestK2Rmse)
        bestK2Idx = find(k2Rows.loocv_rmse == bestK2Rmse, 1, 'first');
        bestK2 = k2Rows(bestK2Idx, :);
        bestK2ImprovementRatio = bestK2.rmse_improvement_ratio;
        bestK2ImprovementAbs = bestK2.rmse_improvement_abs;
    end

    % Best single-variable and best 2-variable models for κ2.
    k2Singles = k2Rows(k2Rows.n_predictors == 1, :);
    k2Pairs = k2Rows(k2Rows.n_predictors == 2, :);

    best1Rmse = min(k2Singles.loocv_rmse, [], 'omitnan');
    best2Rmse = min(k2Pairs.loocv_rmse, [], 'omitnan');

    best1Ok = isfinite(best1Rmse);
    best2Ok = isfinite(best2Rmse);

    % Determine improvement thresholds.
    if O2_USED_SUCCESSFULLY == "YES" && isfinite(bestK2ImprovementAbs) ...
            && (bestK2ImprovementAbs > improvementAbsTinyThreshold) ...
            && (bestK2ImprovementRatio > improvementRatioTinyThreshold)
        KAPPA2_OBSERVABLE_SIGNATURE_FOUND = "YES";
    end

    % TWO_OBSERVABLE_CLOSURE_IMPROVES verdict: best 2-variable must beat baseline.
    if best2Ok
        bestPairIdx = find(k2Pairs.loocv_rmse == best2Rmse, 1, 'first');
        bestPair = k2Pairs(bestPairIdx, :);
        if O2_USED_SUCCESSFULLY == "YES" && isfinite(bestPair.rmse_improvement_ratio) ...
                && (bestPair.rmse_improvement_abs > improvementAbsTinyThreshold) ...
                && (bestPair.rmse_improvement_ratio > improvementRatioTinyThreshold)
            TWO_OBSERVABLE_CLOSURE_IMPROVES = "YES";
        end
    end

    % MINIMAL_2D_OBSERVABLE_FOUND: 2-variable must improve over best 1-variable by meaningful margin.
    % Treat "unstable" as: 2-variable not better than best 1-variable.
    if O2_USED_SUCCESSFULLY == "YES" && best2Ok && best1Ok ...
            && best2Rmse < best1Rmse * (1 - 0.005) % 0.5% improvement margin
        MINIMAL_2D_OBSERVABLE_FOUND = "YES";
    end

    % --------------------------
    % Prepare outputs
    % --------------------------
    resultsTbl = modelRows;
    executionStatus = "SUCCESS";

    % Write results CSV.
    writetable(resultsTbl, outCsvPath);

    % Write status CSV.
    statusTbl = table( ...
        string(executionStatus), ...
        string(O2_USED_SUCCESSFULLY), ...
        string(KAPPA2_OBSERVABLE_SIGNATURE_FOUND), ...
        string(TWO_OBSERVABLE_CLOSURE_IMPROVES), ...
        string(MINIMAL_2D_OBSERVABLE_FOUND), ...
        double(N_VALID_POINTS_ALL), ...
        'VariableNames', { ...
        'EXECUTION_STATUS', ...
        'O2_USED_SUCCESSFULLY', ...
        'KAPPA2_OBSERVABLE_SIGNATURE_FOUND', ...
        'TWO_OBSERVABLE_CLOSURE_IMPROVES', ...
        'MINIMAL_2D_OBSERVABLE_FOUND', ...
        'N_VALID_POINTS_ALL_O2'} );
    writetable(statusTbl, outStatusCsvPath);

    % Write report markdown.
    mdLines(end+1) = "# Phi1/Phi2 observable closure (fixed O2 pipeline)";
    mdLines(end+1) = "";
    mdLines(end+1) = "## Verdicts";
    mdLines(end+1) = "- `O2_USED_SUCCESSFULLY`: **" + string(O2_USED_SUCCESSFULLY) + "**";
    mdLines(end+1) = "- `KAPPA2_OBSERVABLE_SIGNATURE_FOUND`: **" + string(KAPPA2_OBSERVABLE_SIGNATURE_FOUND) + "**";
    mdLines(end+1) = "- `TWO_OBSERVABLE_CLOSURE_IMPROVES`: **" + string(TWO_OBSERVABLE_CLOSURE_IMPROVES) + "**";
    mdLines(end+1) = "- `MINIMAL_2D_OBSERVABLE_FOUND`: **" + string(MINIMAL_2D_OBSERVABLE_FOUND) + "**";
    mdLines(end+1) = "- `N_VALID_POINTS_ALL_O2`: **" + string(N_VALID_POINTS_ALL) + "**";
    mdLines(end+1) = "";

    mdLines(end+1) = "## Modeling summary (LOOCV)";
    mdLines(end+1) = "- Results CSV: `" + string(outCsvPath) + "`";
    mdLines(end+1) = "";

    % Best models per target.
    mdLines(end+1) = "### Best kappa1 model (sanity)";
    mdLines(end+1) = "- Best `loocv_rmse`: **" + string(min(k1Rows.loocv_rmse, [], 'omitnan')) + "**";
    mdLines(end+1) = "";

    mdLines(end+1) = "### Best kappa2 model (main target)";
    if ~isempty(bestK2) && isfinite(bestK2.loocv_rmse)
        mdLines(end+1) = "- Best predictor set: `" + bestK2.predictor_set + "` (n=" + string(bestK2.n_predictors) + ")";
        mdLines(end+1) = "- LOOCV RMSE: **" + string(bestK2.loocv_rmse) + "**";
        mdLines(end+1) = "- Baseline RMSE: **" + string(bestK2.baseline_rmse) + "**";
        mdLines(end+1) = "- RMSE improvement (abs): **" + string(bestK2.rmse_improvement_abs) + "**";
        mdLines(end+1) = "- RMSE improvement (ratio): **" + string(bestK2.rmse_improvement_ratio) + "**";
        mdLines(end+1) = "- Pearson: **" + string(bestK2.pearson_r) + "**; Spearman: **" + string(bestK2.spearman_r) + "**";
        mdLines(end+1) = "";
    else
        mdLines(end+1) = "- Best κ₂ model unavailable (insufficient valid points / NaN metrics).";
        mdLines(end+1) = "";
    end

    % Add best 1 and best 2 comparisons.
    if best1Ok
        mdLines(end+1) = "### Best 1-variable kappa2 model";
        best1Idx = find(k2Singles.loocv_rmse == best1Rmse, 1, 'first');
        best1Row = k2Singles(best1Idx, :);
        mdLines(end+1) = "- Predictor set: `" + best1Row.predictor_set + "` (LOOCV RMSE **" + string(best1Row.loocv_rmse) + "**) ";
        mdLines(end+1) = "";
    end
    if best2Ok
        mdLines(end+1) = "### Best 2-variable kappa2 model";
        best2Idx = find(k2Pairs.loocv_rmse == best2Rmse, 1, 'first');
        best2Row = k2Pairs(best2Idx, :);
        mdLines(end+1) = "- Predictor set: `" + best2Row.predictor_set + "` (LOOCV RMSE **" + string(best2Row.loocv_rmse) + "**) ";
        mdLines(end+1) = "";
    end

    % Write report file.
    fid = fopen(outMdPath, 'w');
    if fid < 0
        error('closure_fixed:ReportWriteFail', 'Cannot write report: %s', outMdPath);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(mdLines, newline));

catch ME
    executionStatus = "FAIL";
    ERROR_TEXT = string(getReport(ME));
    % Always write outputs (best effort).
    try
        if isempty(resultsTbl) || ~istable(resultsTbl)
            resultsTbl = table();
        end
        writetable(resultsTbl, outCsvPath);
    catch
        % ignore
    end
    try
        statusTbl = table( ...
            string(executionStatus), ...
            string(O2_USED_SUCCESSFULLY), ...
            string(KAPPA2_OBSERVABLE_SIGNATURE_FOUND), ...
            string(TWO_OBSERVABLE_CLOSURE_IMPROVES), ...
            string(MINIMAL_2D_OBSERVABLE_FOUND), ...
            double(0), ...
            'VariableNames', { ...
            'EXECUTION_STATUS', ...
            'O2_USED_SUCCESSFULLY', ...
            'KAPPA2_OBSERVABLE_SIGNATURE_FOUND', ...
            'TWO_OBSERVABLE_CLOSURE_IMPROVES', ...
            'MINIMAL_2D_OBSERVABLE_FOUND', ...
            'N_VALID_POINTS_ALL_O2'} );
        writetable(statusTbl, outStatusCsvPath);
    catch
        % ignore
    end
    try
        fid = fopen(outMdPath, 'w');
        if fid >= 0
            cleanupObj = onCleanup(@() fclose(fid));
            fprintf(fid, '# Phi1/Phi2 observable closure (fixed O2 pipeline)\n\n');
            fprintf(fid, 'Execution failed.\n\n');
            fprintf(fid, '```\n%s\n```\n', char(ERROR_TEXT));
        end
    catch
        % ignore
    end
    % Re-throw to ensure non-zero exit is possible for wrapper scripts.
    error(ERROR_TEXT);
end

disp('=== run_phi1_phi2_observable_closure_fixed complete ===');
disp(outCsvPath);
disp(outMdPath);
disp(outStatusCsvPath);

