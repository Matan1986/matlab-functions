clear; clc;

repoRoot = '';
searchDir = pwd;
for level = 1:15
    if exist(fullfile(searchDir, 'README.md'), 'file') == 2 && ...
       exist(fullfile(searchDir, 'Switching'), 'dir') == 7 && ...
       exist(fullfile(searchDir, 'Aging'), 'dir') == 7
        repoRoot = strrep(searchDir, '\\', '/');
        break;
    end
    parentDir = fileparts(searchDir);
    if strcmp(parentDir, searchDir)
        break;
    end
    searchDir = parentDir;
end

if isempty(repoRoot)
    error('Could not resolve repo root.');
end

tablesRoot = fullfile(repoRoot, 'tables');
reportsRoot = fullfile(repoRoot, 'reports');
if exist(tablesRoot, 'dir') ~= 7
    mkdir(tablesRoot);
end
if exist(reportsRoot, 'dir') ~= 7
    mkdir(reportsRoot);
end

addpath(genpath(repoRoot));
cfg = struct('runLabel', 'rmse_structure_vs_scale_closure');
run = createRunContext('switching', cfg);
runDir = strrep(run.run_dir, '\\', '/');
runTablesDir = fullfile(runDir, 'tables');
runReportsDir = fullfile(runDir, 'reports');
if exist(runTablesDir, 'dir') ~= 7
    mkdir(runTablesDir);
end
if exist(runReportsDir, 'dir') ~= 7
    mkdir(runReportsDir);
end

summaryOutRepo = fullfile(tablesRoot, 'map_rmse_closure_summary.csv');
statusOutRepo = fullfile(tablesRoot, 'map_rmse_closure_status.csv');
reportOutRepo = fullfile(reportsRoot, 'map_rmse_closure_summary.md');

summaryOutRun = fullfile(runTablesDir, 'map_rmse_closure_summary.csv');
statusOutRun = fullfile(runTablesDir, 'map_rmse_closure_status.csv');
statusExecOutRun = fullfile(runDir, 'execution_status.csv');
reportOutRun = fullfile(runDir, 'map_rmse_closure_summary.md');
manifestOutRun = fullfile(runDir, 'run_manifest.json');

executionStatus = 'FAIL';
inputFound = 'NO';
errorMessage = '';
mainSummary = 'map-level RMSE closure did not run';

RMSE_IS_SCALE_ONLY = 'NO';
STRUCTURAL_MISMATCH_PRESENT = 'YES';
CANONICAL_MAP_CLOSURE = 'NO';

emptySummary = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
    'VariableNames', {'variant_pair','rmse_raw','rmse_scaled','rmse_affine','corr_map','rmse_ridge','rmse_tail'});

pointerPath = fullfile(repoRoot, 'run_dir_pointer.txt');
fidPointer = fopen(pointerPath, 'w');
if fidPointer >= 0
    fprintf(fidPointer, '%s', runDir);
    fclose(fidPointer);
end

try
    requiredVariants = ["raw_xy_delta"; "xy_over_xx"; "baseline_aware"];

    obsSeedFiles = dir(fullfile(repoRoot, 'results', 'switching', 'runs', 'run_*', 'physics_output_robustness', 'tables', 'variant_observables_xy_over_xx.csv'));
    obsDir = '';
    bestObsTime = -inf;
    for iObs = 1:numel(obsSeedFiles)
        thisDir = obsSeedFiles(iObs).folder;
        hasRaw = exist(fullfile(thisDir, 'variant_observables_raw_xy_delta.csv'), 'file') == 2;
        hasBase = exist(fullfile(thisDir, 'variant_observables_baseline_aware.csv'), 'file') == 2;
        if hasRaw && hasBase && obsSeedFiles(iObs).datenum > bestObsTime
            bestObsTime = obsSeedFiles(iObs).datenum;
            obsDir = thisDir;
        end
    end

    if isempty(obsDir)
        error('Could not locate required variant observables tables.');
    end

    mapFiles = dir(fullfile(repoRoot, 'results', 'switching', 'runs', 'run_*', 'tables', 'switching_effective_switching_map.csv'));
    if isempty(mapFiles)
        error('Could not locate switching_effective_switching_map.csv input.');
    end
    [~, idxNewestMap] = max([mapFiles.datenum]);
    mapPath = fullfile(mapFiles(idxNewestMap).folder, mapFiles(idxNewestMap).name);

    allObs = table();
    for iV = 1:numel(requiredVariants)
        vName = requiredVariants(iV);
        vPath = fullfile(obsDir, sprintf('variant_observables_%s.csv', vName));
        vTbl = readtable(vPath);
        vCols = lower(string(vTbl.Properties.VariableNames));

        iT = find(contains(vCols, 't_k') | strcmp(vCols, 't'), 1);
        iI = find(contains(vCols, 'i_peak'), 1);
        iS = find(contains(vCols, 's_peak'), 1);
        iW = find(strcmp(vCols, 'width') | contains(vCols, 'width'), 1);
        if isempty(iT) || isempty(iI) || isempty(iS) || isempty(iW)
            error('Variant observables table missing required columns: %s', vPath);
        end

        nRows = height(vTbl);
        tVec = double(vTbl{:, iT});
        iVec = double(vTbl{:, iI});
        sVec = double(vTbl{:, iS});
        wVec = double(vTbl{:, iW});
        vOut = table(repmat(vName, nRows, 1), tVec, iVec, sVec, wVec, ...
            'VariableNames', {'variant','T_K','I_peak','S_peak','width'});
        allObs = [allObs; vOut]; %#ok<AGROW>
    end

    keyObs = strcat(allObs.variant, '|', string(allObs.T_K));
    [~, iaObs] = unique(keyObs, 'stable');
    obsTbl = allObs(iaObs, :);

    mapTblRaw = readtable(mapPath);
    mapCols = lower(string(mapTblRaw.Properties.VariableNames));
    iMapT = find(contains(mapCols, 't_k') | strcmp(mapCols, 't'), 1);
    iMapI = find(contains(mapCols, 'current') | strcmp(mapCols, 'i') | contains(mapCols, 'i_ma'), 1);
    iMapS = find(contains(mapCols, 's_percent') | strcmp(mapCols, 's') | contains(mapCols, 'switch'), 1);
    if isempty(iMapT) || isempty(iMapI) || isempty(iMapS)
        error('Map input table missing required columns: %s', mapPath);
    end

    mapTbl = table(double(mapTblRaw{:, iMapT}), double(mapTblRaw{:, iMapI}), double(mapTblRaw{:, iMapS}), ...
        'VariableNames', {'T_K','I_mA','S'});
    mapTbl = mapTbl(isfinite(mapTbl.T_K) & isfinite(mapTbl.I_mA) & isfinite(mapTbl.S), :);

    iGrid = unique(mapTbl.I_mA);
    baseVariant = "xy_over_xx";
    baseObs = obsTbl(obsTbl.variant == baseVariant, :);
    if isempty(baseObs)
        error('Base variant xy_over_xx not available in observables input.');
    end

    shapeLong = table();
    baseTemps = intersect(unique(baseObs.T_K), unique(mapTbl.T_K));
    for iT = 1:numel(baseTemps)
        tVal = baseTemps(iT);
        iObsRow = find(baseObs.T_K == tVal, 1);
        if isempty(iObsRow)
            continue;
        end
        ip = baseObs.I_peak(iObsRow);
        sp = baseObs.S_peak(iObsRow);
        wp = baseObs.width(iObsRow);
        if ~(isfinite(ip) && isfinite(sp) && isfinite(wp) && wp > 0 && sp ~= 0)
            continue;
        end

        mRows = mapTbl(mapTbl.T_K == tVal, :);
        if isempty(mRows)
            continue;
        end

        xBase = (mRows.I_mA - ip) ./ wp;
        yBase = mRows.S ./ sp;
        validBase = isfinite(xBase) & isfinite(yBase);
        if nnz(validBase) < 3
            continue;
        end

        xBase = xBase(validBase);
        yBase = yBase(validBase);
        [xUnique, iaX] = unique(xBase, 'stable');
        yUnique = yBase(iaX);
        tCol = repmat(tVal, numel(xUnique), 1);
        shapeLong = [shapeLong; table(tCol, xUnique, yUnique, 'VariableNames', {'T_K','x','shape'})]; %#ok<AGROW>
    end

    if isempty(shapeLong)
        error('Canonical shape map could not be built from base inputs.');
    end

    mapLong = table();
    for iV = 1:numel(requiredVariants)
        vName = requiredVariants(iV);
        vObs = obsTbl(obsTbl.variant == vName, :);
        tCommon = intersect(unique(vObs.T_K), unique(shapeLong.T_K));

        for iT = 1:numel(tCommon)
            tVal = tCommon(iT);
            iObsRow = find(vObs.T_K == tVal, 1);
            iShapeRows = find(shapeLong.T_K == tVal);
            if isempty(iObsRow) || isempty(iShapeRows)
                continue;
            end

            ip = vObs.I_peak(iObsRow);
            sp = vObs.S_peak(iObsRow);
            wp = vObs.width(iObsRow);
            if ~(isfinite(ip) && isfinite(sp) && isfinite(wp) && wp > 0)
                continue;
            end

            xShape = shapeLong.x(iShapeRows);
            yShape = shapeLong.shape(iShapeRows);
            [xShapeSorted, iSort] = sort(xShape);
            yShapeSorted = yShape(iSort);

            xQuery = (iGrid - ip) ./ wp;
            shapeQuery = interp1(xShapeSorted, yShapeSorted, xQuery, 'linear', NaN);
            sQuery = sp .* shapeQuery;

            validQ = isfinite(shapeQuery) & isfinite(sQuery);
            if nnz(validQ) < 3
                continue;
            end

            nKeep = nnz(validQ);
            outVariant = repmat(vName, nKeep, 1);
            outT = repmat(tVal, nKeep, 1);
            outI = iGrid(validQ);
            outX = xQuery(validQ);
            outS = sQuery(validQ);
            mapLong = [mapLong; table(outVariant, outT, outI, outX, outS, ...
                'VariableNames', {'variant','T_K','I_mA','x','S'})]; %#ok<AGROW>
        end
    end

    if isempty(mapLong)
        error('No variant maps were reconstructed on the common grid.');
    end

    pairs = ["raw_xy_delta|xy_over_xx"; "raw_xy_delta|baseline_aware"; "xy_over_xx|baseline_aware"];
    x0 = 0.75;
    x1 = 1.75;

    nPairs = numel(pairs);
    outPair = strings(nPairs, 1);
    outRmseRaw = nan(nPairs, 1);
    outRmseScaled = nan(nPairs, 1);
    outRmseAffine = nan(nPairs, 1);
    outCorrMap = nan(nPairs, 1);
    outRmseRidge = nan(nPairs, 1);
    outRmseTail = nan(nPairs, 1);
    outResidualRidgeCorr = nan(nPairs, 1);

    for iPair = 1:nPairs
        parts = split(pairs(iPair), '|');
        v1 = parts(1);
        v2 = parts(2);
        outPair(iPair) = v1 + " vs " + v2;

        m1 = mapLong(mapLong.variant == v1, :);
        m2 = mapLong(mapLong.variant == v2, :);
        if isempty(m1) || isempty(m2)
            continue;
        end

        key1 = strcat(string(m1.T_K), '|', string(m1.I_mA));
        key2 = strcat(string(m2.T_K), '|', string(m2.I_mA));
        [~, i1, i2] = intersect(key1, key2, 'stable');
        if numel(i1) < 5
            continue;
        end

        s1 = m1.S(i1);
        s2 = m2.S(i2);
        xRef = 0.5 .* (m1.x(i1) + m2.x(i2));

        valid = isfinite(s1) & isfinite(s2) & isfinite(xRef);
        s1 = s1(valid);
        s2 = s2(valid);
        xRef = xRef(valid);
        if numel(s1) < 5
            continue;
        end

        eRaw = s2 - s1;
        rmseRaw = sqrt(mean(eRaw .^ 2));

        denomScale = sum(s1 .^ 2);
        aScale = sum(s1 .* s2) / denomScale;
        eScale = s2 - aScale .* s1;
        rmseScaled = sqrt(mean(eScale .^ 2));

        Xaff = [s1, ones(size(s1))];
        beta = Xaff \ s2;
        s2Aff = Xaff * beta;
        eAff = s2 - s2Aff;
        rmseAffine = sqrt(mean(eAff .^ 2));

        cMap = corr(s1, s2);

        idxRidge = abs(xRef) < x0;
        idxTail = abs(xRef) > x1;
        if nnz(idxRidge) > 0
            rmseRidge = sqrt(mean((eRaw(idxRidge)) .^ 2));
        else
            rmseRidge = NaN;
        end
        if nnz(idxTail) > 0
            rmseTail = sqrt(mean((eRaw(idxTail)) .^ 2));
        else
            rmseTail = NaN;
        end

        ridgeProfile = exp(-0.5 .* (xRef ./ 0.6) .^ 2);
        cResidualRidge = corr(eAff, ridgeProfile);

        outRmseRaw(iPair) = rmseRaw;
        outRmseScaled(iPair) = rmseScaled;
        outRmseAffine(iPair) = rmseAffine;
        outCorrMap(iPair) = cMap;
        outRmseRidge(iPair) = rmseRidge;
        outRmseTail(iPair) = rmseTail;
        outResidualRidgeCorr(iPair) = cResidualRidge;
    end

    summaryTbl = table(outPair, outRmseRaw, outRmseScaled, outRmseAffine, outCorrMap, outRmseRidge, outRmseTail, ...
        'VariableNames', {'variant_pair','rmse_raw','rmse_scaled','rmse_affine','corr_map','rmse_ridge','rmse_tail'});

    validRows = isfinite(summaryTbl.rmse_raw) & isfinite(summaryTbl.rmse_scaled) & isfinite(summaryTbl.rmse_affine) & isfinite(summaryTbl.corr_map);
    validSummary = summaryTbl(validRows, :);
    validResidualCorr = outResidualRidgeCorr(validRows);

    if isempty(validSummary)
        error('No valid pairwise map comparisons were produced.');
    end

    ratioScale = validSummary.rmse_scaled ./ validSummary.rmse_raw;
    ratioAffine = validSummary.rmse_affine ./ validSummary.rmse_raw;
    medScale = median(ratioScale, 'omitnan');
    medAffine = median(ratioAffine, 'omitnan');
    medCorrMap = median(validSummary.corr_map, 'omitnan');
    medResidualRidgeAbs = median(abs(validResidualCorr), 'omitnan');

    if isfinite(medScale) && isfinite(medAffine) && isfinite(medCorrMap) && medScale <= 0.30 && medAffine <= 0.25 && medCorrMap >= 0.995
        RMSE_IS_SCALE_ONLY = 'YES';
    else
        RMSE_IS_SCALE_ONLY = 'NO';
    end

    if (isfinite(medAffine) && medAffine > 0.25) || (isfinite(medCorrMap) && medCorrMap < 0.99) || (isfinite(medResidualRidgeAbs) && medResidualRidgeAbs > 0.30)
        STRUCTURAL_MISMATCH_PRESENT = 'YES';
    else
        STRUCTURAL_MISMATCH_PRESENT = 'NO';
    end

    if strcmp(RMSE_IS_SCALE_ONLY, 'YES') && strcmp(STRUCTURAL_MISMATCH_PRESENT, 'NO')
        CANONICAL_MAP_CLOSURE = 'YES';
    else
        CANONICAL_MAP_CLOSURE = 'NO';
    end

    executionStatus = 'SUCCESS';
    inputFound = 'YES';
    errorMessage = '';
    mainSummary = sprintf('pairs=%d; med_scale=%.4f; med_affine=%.4f; med_corr=%.6f; med_abs_corr_resid_ridge=%.4f', ...
        height(validSummary), medScale, medAffine, medCorrMap, medResidualRidgeAbs);

    writetable(summaryTbl, summaryOutRun);
    writetable(summaryTbl, summaryOutRepo);

    reportFid = fopen(reportOutRun, 'w');
    if reportFid < 0
        error('Could not open run report output file.');
    end
    fprintf(reportFid, '# Map-Level RMSE Closure Summary\n\n');
    fprintf(reportFid, '- Variant observables source: %s\n', strrep(obsDir, '\\', '/'));
    fprintf(reportFid, '- Canonical map source: %s\n', strrep(mapPath, '\\', '/'));
    fprintf(reportFid, '- Pair count analyzed: %d\n', height(validSummary));
    fprintf(reportFid, '- Median ratio rmse_scaled/rmse_raw: %.6f\n', medScale);
    fprintf(reportFid, '- Median ratio rmse_affine/rmse_raw: %.6f\n', medAffine);
    fprintf(reportFid, '- Median corr_map: %.6f\n', medCorrMap);
    fprintf(reportFid, '- Median |corr(residual_affine, ridge_profile)|: %.6f\n\n', medResidualRidgeAbs);

    fprintf(reportFid, '## Verdicts\n');
    fprintf(reportFid, '- RMSE_IS_SCALE_ONLY=%s\n', RMSE_IS_SCALE_ONLY);
    fprintf(reportFid, '- STRUCTURAL_MISMATCH_PRESENT=%s\n', STRUCTURAL_MISMATCH_PRESENT);
    fprintf(reportFid, '- CANONICAL_MAP_CLOSURE=%s\n\n', CANONICAL_MAP_CLOSURE);

    fprintf(reportFid, '## Interpretation\n');
    fprintf(reportFid, '- Whether RMSE disappears after scaling: compare rmse_scaled against rmse_raw and rmse_affine against rmse_scaled.\n');
    fprintf(reportFid, '- Whether residual is localized or structural: compare rmse_ridge and rmse_tail and inspect corr(residual_affine, ridge_profile).\n\n');

    fprintf(reportFid, '## Pair Metrics\n\n');
    fprintf(reportFid, '| variant_pair | rmse_raw | rmse_scaled | rmse_affine | corr_map | rmse_ridge | rmse_tail | corr(residual_affine,ridge_profile) |\n');
    fprintf(reportFid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
    for iRow = 1:height(summaryTbl)
        fprintf(reportFid, '| %s | %.8g | %.8g | %.8g | %.8g | %.8g | %.8g | %.8g |\n', ...
            summaryTbl.variant_pair(iRow), summaryTbl.rmse_raw(iRow), summaryTbl.rmse_scaled(iRow), ...
            summaryTbl.rmse_affine(iRow), summaryTbl.corr_map(iRow), summaryTbl.rmse_ridge(iRow), ...
            summaryTbl.rmse_tail(iRow), outResidualRidgeCorr(iRow));
    end
    fclose(reportFid);

    copyfile(reportOutRun, reportOutRepo, 'f');

catch ME
    executionStatus = 'FAIL';
    if isempty(errorMessage)
        errorMessage = strrep(ME.message, newline, ' ');
    end

    writetable(emptySummary, summaryOutRun);
    writetable(emptySummary, summaryOutRepo);

    statusFailTbl = table({RMSE_IS_SCALE_ONLY}, {STRUCTURAL_MISMATCH_PRESENT}, {CANONICAL_MAP_CLOSURE}, ...
        'VariableNames', {'RMSE_IS_SCALE_ONLY','STRUCTURAL_MISMATCH_PRESENT','CANONICAL_MAP_CLOSURE'});
    writetable(statusFailTbl, statusOutRun);
    writetable(statusFailTbl, statusOutRepo);

    reportFid = fopen(reportOutRun, 'w');
    if reportFid >= 0
        fprintf(reportFid, '# Map-Level RMSE Closure Summary\n\n');
        fprintf(reportFid, 'Execution failed: %s\n', errorMessage);
        fclose(reportFid);
    end

    reportFid2 = fopen(reportOutRepo, 'w');
    if reportFid2 >= 0
        fprintf(reportFid2, '# Map-Level RMSE Closure Summary\n\n');
        fprintf(reportFid2, 'Execution failed: %s\n', errorMessage);
        fclose(reportFid2);
    end
end

statusTbl = table({RMSE_IS_SCALE_ONLY}, {STRUCTURAL_MISMATCH_PRESENT}, {CANONICAL_MAP_CLOSURE}, ...
    'VariableNames', {'RMSE_IS_SCALE_ONLY','STRUCTURAL_MISMATCH_PRESENT','CANONICAL_MAP_CLOSURE'});

writetable(statusTbl, statusOutRun);
writetable(statusTbl, statusOutRepo);

statusExecTbl = table({executionStatus}, {inputFound}, {errorMessage}, {mainSummary}, ...
    'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','MAIN_RESULT_SUMMARY'});
writetable(statusExecTbl, statusExecOutRun);

manifest = struct();
manifest.outputs = {'tables/map_rmse_closure_summary.csv', 'tables/map_rmse_closure_status.csv', 'execution_status.csv', 'map_rmse_closure_summary.md'};
manifestText = jsonencode(manifest);
fidManifest = fopen(manifestOutRun, 'w');
if fidManifest >= 0
    fprintf(fidManifest, '%s', manifestText);
    fclose(fidManifest);
end

fprintf('RMSE_IS_SCALE_ONLY=%s\n', RMSE_IS_SCALE_ONLY);
fprintf('STRUCTURAL_MISMATCH_PRESENT=%s\n', STRUCTURAL_MISMATCH_PRESENT);
fprintf('CANONICAL_MAP_CLOSURE=%s\n', CANONICAL_MAP_CLOSURE);
fprintf('EXECUTION_STATUS=%s\n', executionStatus);
