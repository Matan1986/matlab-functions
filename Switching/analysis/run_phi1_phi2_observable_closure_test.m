% run_phi1_phi2_observable_closure_test
% Pure script (no functions): tests whether a 2-observable representation
% improves closure over scalar observable for kappa1 / kappa2.

repoRoot = 'C:/Dev/matlab-functions';

inputCandidatesPath = 'C:/Dev/matlab-functions/tables/phi1_map_observable_candidates.csv';
inputKappaVsTPath = 'C:/Dev/matlab-functions/tables/kappa_vs_T.csv';
inputClosurePath = 'C:/Dev/matlab-functions/tables/closure_metrics_per_temperature.csv';
inputPhi1FailurePath = 'C:/Dev/matlab-functions/tables/phi1_observable_failure_by_T.csv';

outCsvPath = 'C:/Dev/matlab-functions/tables/phi1_phi2_observable_closure.csv';
outMdPath = 'C:/Dev/matlab-functions/reports/phi1_phi2_observable_closure.md';
outStatusPath = 'C:/Dev/matlab-functions/tables/phi1_phi2_observable_closure_status.csv';

o1Name = 'central_ridge_excess';
o2Candidates = {'antisymmetric_integral', 'slope_difference', 'local_curvature_window'};

runOk = true;
statusMessage = "OK";

resultsTbl = table();

twoObservableClosureImproves = false;
minimal2dObservableFound = false;
bestCandidate = "";
bestImprovement = NaN;

candidateListFromMap = strings(0, 1);

try
    if exist(inputCandidatesPath, 'file') == 2
        mapTbl = readtable(inputCandidatesPath, 'VariableNamingRule', 'preserve');
        if any(strcmpi(mapTbl.Properties.VariableNames, 'observable_name'))
            candidateListFromMap = string(mapTbl.observable_name);
        end
    end

    kappaTbl = table();
    if exist(inputKappaVsTPath, 'file') == 2
        kappaTbl = readtable(inputKappaVsTPath, 'VariableNamingRule', 'preserve');
    end

    closureTbl = table();
    if exist(inputClosurePath, 'file') == 2
        closureTbl = readtable(inputClosurePath, 'VariableNamingRule', 'preserve');
    end

    phi1Tbl = table();
    if exist(inputPhi1FailurePath, 'file') == 2
        phi1Tbl = readtable(inputPhi1FailurePath, 'VariableNamingRule', 'preserve');
    end

    % --- Resolve T_K and source vectors ---
    Tk = NaN(0, 1);
    kappa1 = NaN(0, 1);
    kappa2 = NaN(0, 1);
    O1 = NaN(0, 1);

    if ~isempty(kappaTbl) && any(strcmp(kappaTbl.Properties.VariableNames, 'T_K'))
        Tk = double(kappaTbl.T_K(:));
    elseif ~isempty(closureTbl) && any(strcmp(closureTbl.Properties.VariableNames, 'T_K'))
        Tk = double(closureTbl.T_K(:));
    elseif ~isempty(phi1Tbl) && any(strcmp(phi1Tbl.Properties.VariableNames, 'T_K'))
        Tk = double(phi1Tbl.T_K(:));
    end

    if ~isempty(kappaTbl)
        vnK = string(kappaTbl.Properties.VariableNames);
        if any(vnK == "kappa1")
            kappa1 = double(kappaTbl.kappa1(:));
        elseif any(vnK == "kappa")
            kappa1 = double(kappaTbl.kappa(:));
        end
        if any(vnK == "kappa2")
            kappa2 = double(kappaTbl.kappa2(:));
        end
        if any(vnK == o1Name)
            O1 = double(kappaTbl.(o1Name)(:));
        end
    end

    if isempty(kappa1) || all(~isfinite(kappa1))
        if ~isempty(closureTbl)
            vnC = string(closureTbl.Properties.VariableNames);
            if any(vnC == "kappa1_M3")
                kappa1 = double(closureTbl.kappa1_M3(:));
            elseif any(vnC == "kappa1_M2")
                kappa1 = double(closureTbl.kappa1_M2(:));
            elseif any(vnC == "kappa1")
                kappa1 = double(closureTbl.kappa1(:));
            end
        end
    end

    if isempty(kappa2) || all(~isfinite(kappa2))
        if ~isempty(closureTbl)
            vnC = string(closureTbl.Properties.VariableNames);
            if any(vnC == "kappa2_M3")
                kappa2 = double(closureTbl.kappa2_M3(:));
            elseif any(vnC == "kappa2")
                kappa2 = double(closureTbl.kappa2(:));
            end
        end
    end

    if isempty(O1) || all(~isfinite(O1))
        if ~isempty(phi1Tbl) && any(strcmp(phi1Tbl.Properties.VariableNames, o1Name))
            O1 = double(phi1Tbl.(o1Name)(:));
        end
    end

    if isempty(Tk) || all(~isfinite(Tk))
        error('Missing T_K in all candidate input tables.');
    end

    % Build table list for manual alignment on T_K (intersect only; no joins).
    dataTables = {};

    baseTbl = table(Tk(:), 'VariableNames', {'T_K'});
    dataTables{end + 1} = baseTbl;

    if numel(kappa1) == numel(Tk)
        dataTables{end + 1} = table(Tk(:), kappa1(:), 'VariableNames', {'T_K', 'kappa1'});
    end
    if numel(kappa2) == numel(Tk)
        dataTables{end + 1} = table(Tk(:), kappa2(:), 'VariableNames', {'T_K', 'kappa2'});
    end
    if numel(O1) == numel(Tk)
        dataTables{end + 1} = table(Tk(:), O1(:), 'VariableNames', {'T_K', 'central_ridge_excess'});
    end

    o2FoundMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for ii = 1:numel(o2Candidates)
        o2FoundMap(o2Candidates{ii}) = [];
    end

    sourceTables = {kappaTbl, closureTbl, phi1Tbl};
    for s = 1:numel(sourceTables)
        tblS = sourceTables{s};
        if isempty(tblS) || ~any(strcmp(tblS.Properties.VariableNames, 'T_K'))
            continue;
        end
        for ii = 1:numel(o2Candidates)
            colName = o2Candidates{ii};
            if any(strcmp(tblS.Properties.VariableNames, colName))
                vec = double(tblS.(colName)(:));
                o2FoundMap(colName) = table(double(tblS.T_K(:)), vec, 'VariableNames', {'T_K', colName});
            end
        end
    end

    for ii = 1:numel(o2Candidates)
        colName = o2Candidates{ii};
        tblO2 = o2FoundMap(colName);
        if ~isempty(tblO2)
            dataTables{end + 1} = tblO2;
        end
    end

    commonT = dataTables{1}.T_K(:);
    for iTbl = 2:numel(dataTables)
        commonT = intersect(commonT, dataTables{iTbl}.T_K(:), 'stable');
    end
    commonT = commonT(isfinite(commonT));

    if numel(commonT) < 6
        error('Insufficient aligned temperatures after intersect: n=%d (need >=6).', numel(commonT));
    end

    aligned = table(commonT(:), 'VariableNames', {'T_K'});
    for iTbl = 2:numel(dataTables)
        tblI = dataTables{iTbl};
        [~, ia, ib] = intersect(aligned.T_K, tblI.T_K, 'stable');
        for v = 1:numel(tblI.Properties.VariableNames)
            vn = tblI.Properties.VariableNames{v};
            if strcmp(vn, 'T_K')
                continue;
            end
            tmp = NaN(height(aligned), 1);
            tmp(ia) = double(tblI.(vn)(ib));
            aligned.(vn) = tmp;
        end
    end

    if ~any(strcmp(aligned.Properties.VariableNames, 'kappa1'))
        error('kappa1 was not resolved from available inputs.');
    end
    if ~any(strcmp(aligned.Properties.VariableNames, 'kappa2'))
        error('kappa2 was not resolved from available inputs.');
    end
    if ~any(strcmp(aligned.Properties.VariableNames, o1Name))
        error('O1 (%s) was not resolved from available inputs.', o1Name);
    end

    y1 = double(aligned.kappa1(:));
    x1 = double(aligned.(o1Name)(:));

    % Scalar baseline: kappa1 ~ O1 with LOOCV.
    n = numel(y1);
    yhatScalar = NaN(n, 1);
    for i = 1:n
        idxTrain = true(n, 1);
        idxTrain(i) = false;
        trainMask = idxTrain & isfinite(y1) & isfinite(x1);
        xt = x1(trainMask);
        yt = y1(trainMask);
        if numel(yt) < 3
            continue;
        end
        X = [ones(numel(xt), 1), xt];
        b = X \ yt;
        if isfinite(x1(i))
            yhatScalar(i) = [1, x1(i)] * b;
        end
    end

    mScalar = isfinite(y1) & isfinite(yhatScalar);
    if nnz(mScalar) < 4
        error('Scalar LOOCV for kappa1 has too few valid points.');
    end
    rmseScalar = sqrt(mean((y1(mScalar) - yhatScalar(mScalar)).^2, 'omitnan'));
    pearsonScalar = corr(y1(mScalar), yhatScalar(mScalar), 'Rows', 'complete', 'Type', 'Pearson');
    spearmanScalar = corr(y1(mScalar), yhatScalar(mScalar), 'Rows', 'complete', 'Type', 'Spearman');

    for ii = 1:numel(o2Candidates)
        o2 = o2Candidates{ii};

        if ~any(strcmp(aligned.Properties.VariableNames, o2))
            resultsTbl = [resultsTbl; table( ...
                string(o2), false, ...
                rmseScalar, pearsonScalar, spearmanScalar, ...
                NaN, NaN, NaN, ...
                NaN, NaN, NaN, ...
                NaN, NaN, ...
                "O2 column missing in aligned tables", ...
                'VariableNames', { ...
                'o2_candidate', 'o2_available', ...
                'scalar_kappa1_loocv_rmse', 'scalar_kappa1_pearson', 'scalar_kappa1_spearman', ...
                'twoD_kappa1_loocv_rmse', 'twoD_kappa1_pearson', 'twoD_kappa1_spearman', ...
                'twoD_kappa2_loocv_rmse', 'twoD_kappa2_pearson', 'twoD_kappa2_spearman', ...
                'kappa1_rmse_improvement_abs', 'kappa1_rmse_improvement_ratio', ...
                'notes'})];
            continue;
        end

        x2 = double(aligned.(o2)(:));
        y2 = double(aligned.kappa2(:));

        yhatK1_2d = NaN(n, 1);
        yhatK2_2d = NaN(n, 1);
        for i = 1:n
            idxTrain = true(n, 1);
            idxTrain(i) = false;

            trainMask1 = idxTrain & isfinite(y1) & isfinite(x1) & isfinite(x2);
            trainMask2 = idxTrain & isfinite(y2) & isfinite(x1) & isfinite(x2);

            if nnz(trainMask1) >= 4 && isfinite(x1(i)) && isfinite(x2(i))
                X1 = [ones(nnz(trainMask1), 1), x1(trainMask1), x2(trainMask1)];
                b1 = X1 \ y1(trainMask1);
                yhatK1_2d(i) = [1, x1(i), x2(i)] * b1;
            end

            if nnz(trainMask2) >= 4 && isfinite(x1(i)) && isfinite(x2(i))
                X2 = [ones(nnz(trainMask2), 1), x1(trainMask2), x2(trainMask2)];
                b2 = X2 \ y2(trainMask2);
                yhatK2_2d(i) = [1, x1(i), x2(i)] * b2;
            end
        end

        m1 = isfinite(y1) & isfinite(yhatK1_2d);
        m2 = isfinite(y2) & isfinite(yhatK2_2d);

        rmseK1_2d = NaN; pK1_2d = NaN; sK1_2d = NaN;
        rmseK2_2d = NaN; pK2_2d = NaN; sK2_2d = NaN;
        improveAbs = NaN; improveRatio = NaN;

        if nnz(m1) >= 4
            rmseK1_2d = sqrt(mean((y1(m1) - yhatK1_2d(m1)).^2, 'omitnan'));
            pK1_2d = corr(y1(m1), yhatK1_2d(m1), 'Rows', 'complete', 'Type', 'Pearson');
            sK1_2d = corr(y1(m1), yhatK1_2d(m1), 'Rows', 'complete', 'Type', 'Spearman');
            improveAbs = rmseScalar - rmseK1_2d;
            improveRatio = improveAbs / max(rmseScalar, eps);
        end

        if nnz(m2) >= 4
            rmseK2_2d = sqrt(mean((y2(m2) - yhatK2_2d(m2)).^2, 'omitnan'));
            pK2_2d = corr(y2(m2), yhatK2_2d(m2), 'Rows', 'complete', 'Type', 'Pearson');
            sK2_2d = corr(y2(m2), yhatK2_2d(m2), 'Rows', 'complete', 'Type', 'Spearman');
        end

        resultsTbl = [resultsTbl; table( ...
            string(o2), true, ...
            rmseScalar, pearsonScalar, spearmanScalar, ...
            rmseK1_2d, pK1_2d, sK1_2d, ...
            rmseK2_2d, pK2_2d, sK2_2d, ...
            improveAbs, improveRatio, ...
            "", ...
            'VariableNames', { ...
            'o2_candidate', 'o2_available', ...
            'scalar_kappa1_loocv_rmse', 'scalar_kappa1_pearson', 'scalar_kappa1_spearman', ...
            'twoD_kappa1_loocv_rmse', 'twoD_kappa1_pearson', 'twoD_kappa1_spearman', ...
            'twoD_kappa2_loocv_rmse', 'twoD_kappa2_pearson', 'twoD_kappa2_spearman', ...
            'kappa1_rmse_improvement_abs', 'kappa1_rmse_improvement_ratio', ...
            'notes'})];
    end

    validRows = resultsTbl.o2_available & isfinite(resultsTbl.kappa1_rmse_improvement_abs);
    if any(validRows)
        [bestImprovement, idxBestLocal] = max(resultsTbl.kappa1_rmse_improvement_abs(validRows), [], 'omitnan');
        validIdx = find(validRows);
        idxBest = validIdx(idxBestLocal);
        bestCandidate = string(resultsTbl.o2_candidate(idxBest));
        twoObservableClosureImproves = isfinite(bestImprovement) && bestImprovement > 0;
        minimal2dObservableFound = twoObservableClosureImproves;
    else
        bestCandidate = "NONE";
        bestImprovement = NaN;
        twoObservableClosureImproves = false;
        minimal2dObservableFound = false;
    end

catch ME
    runOk = false;
    statusMessage = "FAILED: " + string(ME.message);
    if isempty(resultsTbl)
        resultsTbl = table( ...
            string("N/A"), false, ...
            NaN, NaN, NaN, ...
            NaN, NaN, NaN, ...
            NaN, NaN, NaN, ...
            NaN, NaN, ...
            "Exception: " + string(ME.message), ...
            'VariableNames', { ...
            'o2_candidate', 'o2_available', ...
            'scalar_kappa1_loocv_rmse', 'scalar_kappa1_pearson', 'scalar_kappa1_spearman', ...
            'twoD_kappa1_loocv_rmse', 'twoD_kappa1_pearson', 'twoD_kappa1_spearman', ...
            'twoD_kappa2_loocv_rmse', 'twoD_kappa2_pearson', 'twoD_kappa2_spearman', ...
            'kappa1_rmse_improvement_abs', 'kappa1_rmse_improvement_ratio', ...
            'notes'});
    end
end

% Always-write outputs (CSV + MD + status)
writetable(resultsTbl, outCsvPath);

if twoObservableClosureImproves
    v1 = "YES";
else
    v1 = "NO";
end
if minimal2dObservableFound
    v2 = "YES";
else
    v2 = "NO";
end

mdLines = strings(0, 1);
mdLines(end + 1) = "# Phi1/Phi2 two-observable closure test";
mdLines(end + 1) = "";
mdLines(end + 1) = "## Inputs";
mdLines(end + 1) = "- Candidate list: `" + string(inputCandidatesPath) + "`";
mdLines(end + 1) = "- Kappa table (primary): `" + string(inputKappaVsTPath) + "`";
mdLines(end + 1) = "- Residual decomposition table (fallback/augment): `" + string(inputClosurePath) + "`";
mdLines(end + 1) = "- Phi1 observable table (fallback for O1): `" + string(inputPhi1FailurePath) + "`";
mdLines(end + 1) = "";
if ~isempty(candidateListFromMap)
    mdLines(end + 1) = "## Candidate list seen in map file";
    for i = 1:numel(candidateListFromMap)
        mdLines(end + 1) = "- `" + candidateListFromMap(i) + "`";
    end
    mdLines(end + 1) = "";
end
mdLines(end + 1) = "## Models";
mdLines(end + 1) = "- Scalar baseline: `kappa1 ~ central_ridge_excess` (LOOCV).";
mdLines(end + 1) = "- 2D models per O2 candidate:";
mdLines(end + 1) = "  - `kappa1 ~ central_ridge_excess + O2` (LOOCV).";
mdLines(end + 1) = "  - `kappa2 ~ central_ridge_excess + O2` (LOOCV).";
mdLines(end + 1) = "";
mdLines(end + 1) = "## Results table";
mdLines(end + 1) = "- See `" + string(outCsvPath) + "`.";
mdLines(end + 1) = "";
if ~isempty(resultsTbl)
    mdLines(end + 1) = "## Per-candidate summary";
    for i = 1:height(resultsTbl)
        mdLines(end + 1) = "- O2=`" + string(resultsTbl.o2_candidate(i)) + "` | avail=" + string(resultsTbl.o2_available(i)) + ...
            " | scalar RMSE(k1)=" + sprintf('%.6g', resultsTbl.scalar_kappa1_loocv_rmse(i)) + ...
            " | 2D RMSE(k1)=" + sprintf('%.6g', resultsTbl.twoD_kappa1_loocv_rmse(i)) + ...
            " | 2D RMSE(k2)=" + sprintf('%.6g', resultsTbl.twoD_kappa2_loocv_rmse(i)) + ...
            " | improvement=" + sprintf('%.6g', resultsTbl.kappa1_rmse_improvement_abs(i));
    end
    mdLines(end + 1) = "";
end
mdLines(end + 1) = "## Verdicts";
mdLines(end + 1) = "- **TWO_OBSERVABLE_CLOSURE_IMPROVES: " + v1 + "**";
mdLines(end + 1) = "- **MINIMAL_2D_OBSERVABLE_FOUND: " + v2 + "**";
mdLines(end + 1) = "- Best O2 candidate by kappa1 RMSE improvement: `" + string(bestCandidate) + "`.";
mdLines(end + 1) = "- Best absolute RMSE improvement: `" + sprintf('%.6g', bestImprovement) + "`.";
mdLines(end + 1) = "";
mdLines(end + 1) = "## Run status";
mdLines(end + 1) = "- Script status: **" + string(statusMessage) + "**";

fid = fopen(outMdPath, 'w');
if fid >= 0
    fprintf(fid, '%s\n', strjoin(mdLines, newline));
    fclose(fid);
end

statusTbl = table( ...
    string(datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    string(repoRoot), ...
    runOk, ...
    string(statusMessage), ...
    string(v1), ...
    string(v2), ...
    string(bestCandidate), ...
    bestImprovement, ...
    'VariableNames', { ...
    'timestamp_local', 'repo_root', 'run_ok', 'status_message', ...
    'TWO_OBSERVABLE_CLOSURE_IMPROVES', 'MINIMAL_2D_OBSERVABLE_FOUND', ...
    'best_o2_candidate', 'best_kappa1_rmse_improvement_abs'});
writetable(statusTbl, outStatusPath);

disp('=== run_phi1_phi2_observable_closure_test complete ===');
disp(outCsvPath);
disp(outMdPath);
disp(outStatusPath);
