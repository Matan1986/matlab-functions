clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    repoRoot = pwd;
end

tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

backboneOutPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_backbone_map.csv');
residualOutPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_residual_map.csv');
phiOutPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_phi1.csv');
kappaOutPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_kappa1.csv');
mode1OutPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_mode1_reconstruction_map.csv');
resAfterOutPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_residual_after_mode1_map.csv');
qualityOutPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_quality_metrics.csv');
statusOutPath = fullfile(tablesDir, 'switching_corrected_old_authoritative_builder_status.csv');
reportOutPath = fullfile(reportsDir, 'switching_corrected_old_authoritative_builder.md');

CORRECTED_OLD_AUTHORITATIVE_BUILDER_IMPLEMENTED = "YES";
PREVIOUS_GATES_RECHECKED = "NO";
ALL_REQUIRED_GATES_PASSED = "NO";
SOURCE_VIEW_USED = "NO";
SOURCE_VIEW_IS_CLEAN = "NO";
LOCKED_EFFECTIVE_OBSERVABLES_USED = "NO";
LEGACY_PT_MATRIX_USED = "NO";
OLD_AUTHORITATIVE_BRANCH_PT_ONLY = "NO";
FALLBACK_USED = "NO";
CANON_GEN_DIAGNOSTIC_OUTPUTS_USED = "NO";
QUARANTINED_CORRECTED_OLD_ARTIFACTS_USED = "NO";
OLD_FIGURES_USED_AS_DATA = "NO";
BACKBONE_MAP_WRITTEN = "NO";
RESIDUAL_MAP_WRITTEN = "NO";
PHI1_WRITTEN = "NO";
KAPPA1_WRITTEN = "NO";
MODE1_RECONSTRUCTION_WRITTEN = "NO";
RESIDUAL_AFTER_MODE1_WRITTEN = "NO";
QUALITY_METRICS_WRITTEN = "NO";
CORRECTED_OLD_AUTH_NAMESPACE_UNBLOCKED = "NO";
SAFE_TO_USE_CORRECTED_OLD_AS_AUTHORITATIVE = "NO";
SAFE_TO_CREATE_PUBLICATION_FIGURES = "NO";
PHYSICS_LOGIC_CHANGED = "NO";
FILES_DELETED = "NO";

notes = strings(0,1);

sourceViewPath = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_04_24_233348_switching_canonical', 'tables', 'switching_canonical_source_view.csv');
lockedObsPath = fullfile(repoRoot, 'tables', 'switching_corrected_old_effective_observables_locked.csv');
provenancePath = fullfile(repoRoot, 'tables', 'switching_corrected_old_recipe_provenance_verification.csv');
separationStatusPath = fullfile(repoRoot, 'tables', 'switching_canonical_output_separation_status.csv');
readinessStatusPath = fullfile(repoRoot, 'tables', 'switching_corrected_old_builder_readiness_status.csv');
lockStatusPath = fullfile(repoRoot, 'tables', 'switching_corrected_old_effective_observable_validation_status.csv');
blockedMarkerPath = fullfile(repoRoot, 'tables', 'switching_corrected_old_namespace_blocked_marker.csv');

expectedT = (4:2:30)';
xGrid = [];
ptMatrixPath = "";
missingTemps = strings(0,1);
interpFailureCount = 0;

try
    gateFailures = strings(0,1);

    if exist(separationStatusPath, 'file') ~= 2
        error('builder:MissingSeparationStatus', 'Missing gate file: %s', separationStatusPath);
    end
    if exist(readinessStatusPath, 'file') ~= 2
        error('builder:MissingReadinessStatus', 'Missing gate file: %s', readinessStatusPath);
    end
    if exist(lockStatusPath, 'file') ~= 2
        error('builder:MissingLockStatus', 'Missing gate file: %s', lockStatusPath);
    end

    sep = readtable(separationStatusPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    ready = readtable(readinessStatusPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    lockv = readtable(lockStatusPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');

    sepKeysNorm = upper(strtrim(replace(string(sep.status_key), char(65279), "")));
    readyKeysNorm = upper(strtrim(replace(string(ready.status_key), char(65279), "")));
    lockKeysNorm = upper(strtrim(replace(string(lockv.verdict_key), char(65279), "")));

    sepReqKeys = ["SOURCE_VIEW_CREATED";"SOURCE_VIEW_DIAGNOSTIC_COLUMNS_REMOVED";"DIAGNOSTIC_VIEWS_CREATED";"CORRECTED_OLD_NAMESPACE_REMAINS_BLOCKED"];
    sepReqVals = ["YES";"YES";"YES";"YES"];
    for i = 1:numel(sepReqKeys)
        idx = find(sepKeysNorm == sepReqKeys(i), 1, 'first');
        if isempty(idx)
            gateFailures(end+1,1) = "Missing separation gate key: " + sepReqKeys(i); %#ok<AGROW>
        else
            v = upper(strtrim(sep.status_value(idx)));
            if v ~= sepReqVals(i)
                gateFailures(end+1,1) = "Separation gate " + sepReqKeys(i) + " expected " + sepReqVals(i) + " got " + v; %#ok<AGROW>
            end
        end
    end

    readyReqKeys = ["SOURCE_VIEW_USED";"SOURCE_VIEW_IS_CLEAN";"LEGACY_PT_MATRIX_FOUND";"OLD_AUTHORITATIVE_BRANCH_PT_ONLY";"FALLBACK_ONLY_REPLAY_FORBIDDEN"];
    readyReqVals = ["YES";"YES";"YES";"YES";"YES"];
    for i = 1:numel(readyReqKeys)
        idx = find(readyKeysNorm == readyReqKeys(i), 1, 'first');
        if isempty(idx)
            gateFailures(end+1,1) = "Missing readiness gate key: " + readyReqKeys(i); %#ok<AGROW>
        else
            v = upper(strtrim(ready.status_value(idx)));
            if v ~= readyReqVals(i)
                gateFailures(end+1,1) = "Readiness gate " + readyReqKeys(i) + " expected " + readyReqVals(i) + " got " + v; %#ok<AGROW>
            end
        end
    end

    lockReqKeys = ["I_PEAK_VALIDATED_FOR_BUILDER";"S_PEAK_VALIDATED_FOR_BUILDER";"WIDTH_VALIDATED_FOR_ALIGNMENT";"WIDTH_CANONICAL_OVERCLAIMED";"X_CANONICAL_OVERCLAIMED";"LOCKED_EFFECTIVE_OBSERVABLE_TABLE_CREATED";"SAFE_TO_IMPLEMENT_FULL_CORRECTED_OLD_BUILDER"];
    lockReqVals = ["YES";"YES";"YES";"NO";"NO";"YES";"YES"];
    for i = 1:numel(lockReqKeys)
        idx = find(lockKeysNorm == lockReqKeys(i), 1, 'first');
        if isempty(idx)
            gateFailures(end+1,1) = "Missing lock gate key: " + lockReqKeys(i); %#ok<AGROW>
        else
            v = upper(strtrim(lockv.verdict_value(idx)));
            if v ~= lockReqVals(i)
                gateFailures(end+1,1) = "Lock gate " + lockReqKeys(i) + " expected " + lockReqVals(i) + " got " + v; %#ok<AGROW>
            end
        end
    end

    PREVIOUS_GATES_RECHECKED = "YES";
    if isempty(gateFailures)
        ALL_REQUIRED_GATES_PASSED = "YES";
    else
        ALL_REQUIRED_GATES_PASSED = "NO";
        notes = [notes; gateFailures];
    end

    if ALL_REQUIRED_GATES_PASSED ~= "YES"
        error('builder:GatesFailed', 'Required authorization gates failed closed.');
    end

    if exist(sourceViewPath, 'file') ~= 2
        error('builder:MissingSourceView', 'Missing clean source view: %s', sourceViewPath);
    end
    src = readtable(sourceViewPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    SOURCE_VIEW_USED = "YES";

    srcNames = string(src.Properties.VariableNames);
    srcNamesLow = lower(strtrim(replace(srcNames, char(65279), "")));
    reqSrcCols = ["T_K","current_mA","S_percent"];
    for i = 1:numel(reqSrcCols)
        if ~any(srcNamesLow == lower(reqSrcCols(i)))
            error('builder:MissingSourceCol', 'Source view missing required column: %s', reqSrcCols(i));
        end
    end

    forbiddenExact = ["S_model_pt_percent","residual_percent","PT_pdf","CDF_pt","S_model_full_percent"];
    forbiddenFound = strings(0,1);
    for i = 1:numel(forbiddenExact)
        if ~isempty(find(srcNamesLow == lower(forbiddenExact(i)), 1))
            forbiddenFound(end+1,1) = forbiddenExact(i); %#ok<AGROW>
        end
    end
    for i = 1:numel(srcNamesLow)
        if startsWith(srcNamesLow(i), 'phi') || startsWith(srcNamesLow(i), 'kappa')
            forbiddenFound(end+1,1) = srcNames(i); %#ok<AGROW>
        end
    end
    forbiddenFound = unique(forbiddenFound);
    if isempty(forbiddenFound)
        SOURCE_VIEW_IS_CLEAN = "YES";
    else
        SOURCE_VIEW_IS_CLEAN = "NO";
        error('builder:ForbiddenSourceColumns', 'Source view has forbidden columns: %s', strjoin(forbiddenFound, ', '));
    end

    if exist(lockedObsPath, 'file') ~= 2
        error('builder:MissingLockedObservables', 'Missing locked effective-observable table: %s', lockedObsPath);
    end
    obsCell = readcell(lockedObsPath, 'FileType', 'text', 'Delimiter', ',');
    if size(obsCell, 1) < 2
        error('builder:LockedObsEmpty', 'Locked observables table is empty: %s', lockedObsPath);
    end
    obsNames = string(obsCell(1, :));
    obsNamesLow = lower(strtrim(replace(replace(obsNames, char(65279), ""), """", "")));
    idxObsT = find(obsNamesLow == "t_k", 1, 'first');
    idxObsI = find(obsNamesLow == "i_peak_ma", 1, 'first');
    idxObsS = find(obsNamesLow == "s_peak", 1, 'first');
    idxObsW = find(obsNamesLow == "width_for_alignment_ma", 1, 'first');
    if isempty(idxObsT) || isempty(idxObsI) || isempty(idxObsS) || isempty(idxObsW)
        error('builder:MissingObsCol', 'Locked observables table missing one of required columns: T_K,I_peak_mA,S_peak,width_for_alignment_mA');
    end
    LOCKED_EFFECTIVE_OBSERVABLES_USED = "YES";

    if exist(provenancePath, 'file') ~= 2
        error('builder:MissingProvenance', 'Missing provenance verification table: %s', provenancePath);
    end
    prov = readtable(provenancePath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    provItemsNorm = strtrim(replace(string(prov.verification_item), char(65279), ""));
    idxPtPath = find(provItemsNorm == "legacy_template_pt_matrix_file", 1, 'first');
    idxMode = find(provItemsNorm == "old_execution_mode", 1, 'first');
    idxPtRows = find(provItemsNorm == "old_execution_pt_rows", 1, 'first');
    idxFbRows = find(provItemsNorm == "old_execution_fallback_rows", 1, 'first');
    if isempty(idxPtPath) || isempty(idxMode) || isempty(idxPtRows) || isempty(idxFbRows)
        error('builder:ProvenanceMissingKeys', 'Provenance table missing PT-only verification keys.');
    end

    ptMatrixPath = char(strtrim(prov.result(idxPtPath)));
    if exist(ptMatrixPath, 'file') ~= 2
        error('builder:MissingPTMatrix', 'Legacy PT_matrix missing at: %s', ptMatrixPath);
    end
    modeVal = upper(strtrim(prov.result(idxMode)));
    ptRows = str2double(prov.result(idxPtRows));
    fbRows = str2double(prov.result(idxFbRows));
    if modeVal ~= "PT_ONLY" || ~(isfinite(ptRows) && ptRows > 0) || ~(isfinite(fbRows) && fbRows == 0)
        error('builder:NotPTOnly', 'Legacy branch is not PT-only by provenance gate.');
    end
    LEGACY_PT_MATRIX_USED = "YES";
    OLD_AUTHORITATIVE_BRANCH_PT_ONLY = "YES";

    srcT = str2double(string(src.T_K));
    srcI = str2double(string(src.current_mA));
    srcS = str2double(string(src.S_percent));
    keep = isfinite(srcT) & isfinite(srcI) & isfinite(srcS) & srcT <= 30 & ismember(srcT, expectedT);
    srcT = srcT(keep);
    srcI = srcI(keep);
    srcS = srcS(keep);

    presentT = unique(srcT);
    miss = expectedT(~ismember(expectedT, presentT));
    if ~isempty(miss)
        missingTemps = string(miss);
        error('builder:MissingTemps', 'Source view does not cover full corrected-old window T=4:2:30.');
    end

    currentsAll = sort(unique(srcI));
    nT = numel(expectedT);
    nIAll = numel(currentsAll);
    SmapAll = nan(nT, nIAll);
    for iT = 1:nT
        tVal = expectedT(iT);
        for iI = 1:nIAll
            cVal = currentsAll(iI);
            idx = find(srcT == tVal & srcI == cVal, 1, 'first');
            if ~isempty(idx)
                SmapAll(iT, iI) = srcS(idx);
            end
        end
    end
    currentFiniteMask = all(isfinite(SmapAll), 1);
    if sum(currentFiniteMask) < 2
        error('builder:InsufficientFiniteCurrents', 'Not enough fully finite current bins across T=4:2:30.');
    end
    excludedCurrents = currentsAll(~currentFiniteMask);
    if ~isempty(excludedCurrents)
        notes(end+1,1) = "Excluded current bins with non-finite S_percent in window: " + strjoin(string(excludedCurrents), ','); %#ok<AGROW>
    end
    currents = currentsAll(currentFiniteMask);
    Smap = SmapAll(:, currentFiniteMask);
    nI = numel(currents);

    obsT = str2double(string(obsCell(2:end, idxObsT)));
    obsIpeak = str2double(string(obsCell(2:end, idxObsI)));
    obsSpeak = str2double(string(obsCell(2:end, idxObsS)));
    obsWidth = str2double(string(obsCell(2:end, idxObsW)));

    Ipeak = nan(nT,1);
    Speak = nan(nT,1);
    Width = nan(nT,1);
    for iT = 1:nT
        tVal = expectedT(iT);
        idx = find(obsT == tVal, 1, 'first');
        if isempty(idx)
            error('builder:MissingObsTemp', 'Locked observables missing T=%g K.', tVal);
        end
        Ipeak(iT) = obsIpeak(idx);
        Speak(iT) = obsSpeak(idx);
        Width(iT) = obsWidth(idx);
    end
    if any(~isfinite(Ipeak)) || any(~isfinite(Speak)) || any(~isfinite(Width)) || any(Width <= 0)
        error('builder:InvalidObsValues', 'Locked observables contain invalid I_peak/S_peak/width values.');
    end

    pt = readtable(ptMatrixPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    ptNames = string(pt.Properties.VariableNames);
    ptNamesLow = lower(strtrim(replace(ptNames, char(65279), "")));
    idxPTT = find(ptNamesLow == "t_k", 1, 'first');
    if isempty(idxPTT)
        error('builder:PTMissingT', 'PT_matrix does not contain T_K column.');
    end

    ptCurrVals = [];
    ptCurrColIdx = [];
    for i = 1:numel(ptNames)
        nm = ptNames(i);
        nml = lower(nm);
        if startsWith(nml, 'ith_') && endsWith(nml, '_ma')
            token = erase(erase(nml, 'ith_'), '_ma');
            c = str2double(token);
            if isfinite(c)
                ptCurrVals(end+1,1) = c; %#ok<AGROW>
                ptCurrColIdx(end+1,1) = i; %#ok<AGROW>
            end
        end
    end
    if isempty(ptCurrVals)
        error('builder:PTNoCurrentCols', 'No Ith_*_mA columns found in PT_matrix.');
    end

    ptT = str2double(string(pt{:, idxPTT}));
    ptCurrSorted = ptCurrVals;
    ptColSorted = ptCurrColIdx;
    [ptCurrSorted, ordPT] = sort(ptCurrSorted);
    ptColSorted = ptColSorted(ordPT);
    ptMatrixSorted = nan(height(pt), numel(ptCurrSorted));
    for j = 1:numel(ptCurrSorted)
        ptMatrixSorted(:, j) = str2double(string(pt{:, ptColSorted(j)}));
    end

    backbone = nan(nT, nI);
    residual = nan(nT, nI);
    xRows = nan(nT, nI);

    for iT = 1:nT
        tVal = expectedT(iT);
        pAtT = nan(numel(ptCurrSorted), 1);
        for j = 1:numel(ptCurrSorted)
            col = ptMatrixSorted(:, j);
            m = isfinite(ptT) & isfinite(col);
            if sum(m) >= 2
                pAtT(j) = interp1(ptT(m), col(m), tVal, 'linear', NaN);
            end
        end

        if all(~isfinite(pAtT))
            error('builder:PTAllNaNAtT', 'PT branch cannot reconstruct CDF at T=%g K from legacy PT matrix.', tVal);
        end

        pAtT(~isfinite(pAtT)) = 0;
        pAtT = max(pAtT, 0);
        areaPT = trapz(ptCurrSorted, pAtT);
        if ~(isfinite(areaPT) && areaPT > 0)
            error('builder:PTZeroMass', 'PT branch has zero area at T=%g K.', tVal);
        end
        pAtT = pAtT ./ areaPT;

        pOnCurr = interp1(ptCurrSorted, pAtT, currents(:), 'linear', 0);
        pOnCurr = max(pOnCurr, 0);
        areaCurr = trapz(currents, pOnCurr);
        if ~(isfinite(areaCurr) && areaCurr > 0)
            error('builder:PTZeroMassCurrentGrid', 'PT branch has zero area on source-current grid at T=%g K.', tVal);
        end
        pOnCurr = pOnCurr ./ areaCurr;
        cdf = cumtrapz(currents, pOnCurr);
        if cdf(end) <= 0
            error('builder:PTInvalidCDF', 'PT CDF failed normalization at T=%g K.', tVal);
        end
        cdf = cdf ./ cdf(end);
        cdf = min(max(cdf, 0), 1);

        backbone(iT, :) = Speak(iT) .* cdf(:)';
        residual(iT, :) = Smap(iT, :) - backbone(iT, :);
        xRows(iT, :) = (currents - Ipeak(iT)) ./ Width(iT);
    end

    minX = min(xRows(:));
    maxX = max(xRows(:));
    if ~(isfinite(minX) && isfinite(maxX) && maxX > minX)
        error('builder:InvalidXRange', 'Aligned x range is invalid.');
    end
    nX = 220;
    xGrid = linspace(minX, maxX, nX);

    alignedResidual = nan(nT, nX);
    for iT = 1:nT
        xv = xRows(iT, :);
        rv = residual(iT, :);
        [xvSorted, ord] = sort(xv);
        rvSorted = rv(ord);
        xu = unique(xvSorted);
        if numel(xu) < 2
            error('builder:DegenerateRow', 'Residual alignment row has <2 unique x values at T=%g K.', expectedT(iT));
        end
        if numel(xu) < numel(xvSorted)
            rvU = zeros(size(xu));
            for k = 1:numel(xu)
                rvU(k) = mean(rvSorted(abs(xvSorted - xu(k)) < 1e-12));
            end
        else
            rvU = rvSorted;
        end
        alignedResidual(iT, :) = interp1(xu, rvU, xGrid, 'linear', NaN);
    end

    finiteFrac = sum(isfinite(alignedResidual), 'all') / numel(alignedResidual);
    validCols = all(isfinite(alignedResidual), 1);
    if sum(validCols) < 2
        error('builder:InsufficientFiniteCols', 'Insufficient fully finite aligned columns for SVD.');
    end

    A = alignedResidual(:, validCols);
    [U, S, V] = svd(A, 'econ');
    svals = diag(S);
    if isempty(svals) || svals(1) <= 0
        error('builder:SVDInvalid', 'SVD did not produce a valid leading mode.');
    end

    kappa1 = U(:,1) * svals(1);
    phi1Valid = V(:,1);
    signConvention = "flipped_to_positive_mean_kappa";
    if mean(kappa1, 'omitnan') < 0
        kappa1 = -kappa1;
        phi1Valid = -phi1Valid;
    else
        signConvention = "native_positive_mean_kappa";
    end

    xValid = xGrid(validCols);
    phi1Grid = interp1(xValid, phi1Valid, xGrid, 'linear', NaN);

    mode1 = nan(nT, nI);
    residualAfter = nan(nT, nI);
    for iT = 1:nT
        phiAtRow = interp1(xGrid, phi1Grid, xRows(iT, :), 'linear', NaN);
        bad = sum(~isfinite(phiAtRow));
        interpFailureCount = interpFailureCount + bad;
        mode1(iT, :) = backbone(iT, :) + kappa1(iT) .* phiAtRow;
        residualAfter(iT, :) = Smap(iT, :) - mode1(iT, :);
    end

    rmseBackbone = sqrt(mean((Smap(:) - backbone(:)).^2, 'omitnan'));
    rmseAfter = sqrt(mean((Smap(:) - mode1(:)).^2, 'omitnan'));
    improvement = NaN;
    if isfinite(rmseBackbone) && isfinite(rmseAfter) && rmseAfter > 0
        improvement = rmseBackbone / rmseAfter;
    end
    evMode1 = (svals(1)^2) / sum(svals.^2);

    nRows = nT * nI;
    Tcol = zeros(nRows,1);
    Icol = zeros(nRows,1);
    Xcol = zeros(nRows,1);
    Scol = zeros(nRows,1);
    Bcol = zeros(nRows,1);
    Rcol = zeros(nRows,1);
    Mcol = zeros(nRows,1);
    RAcol = zeros(nRows,1);
    p = 0;
    for iT = 1:nT
        for iI = 1:nI
            p = p + 1;
            Tcol(p) = expectedT(iT);
            Icol(p) = currents(iI);
            Xcol(p) = xRows(iT, iI);
            Scol(p) = Smap(iT, iI);
            Bcol(p) = backbone(iT, iI);
            Rcol(p) = residual(iT, iI);
            Mcol(p) = mode1(iT, iI);
            RAcol(p) = residualAfter(iT, iI);
        end
    end

    backboneTbl = table(Tcol, Icol, Xcol, Scol, Bcol, 'VariableNames', {'T_K','current_mA','x_aligned','S_percent','S_backbone_old_recipe'});
    residualTbl = table(Tcol, Icol, Xcol, Rcol, 'VariableNames', {'T_K','current_mA','x_aligned','DeltaS'});
    mode1Tbl = table(Tcol, Icol, Xcol, Mcol, 'VariableNames', {'T_K','current_mA','x_aligned','S_mode1_reconstruction'});
    resAfterTbl = table(Tcol, Icol, Xcol, RAcol, 'VariableNames', {'T_K','current_mA','x_aligned','DeltaS_after_mode1'});
    phiTbl = table(xGrid(:), phi1Grid(:), 'VariableNames', {'x_aligned','Phi1_corrected_old'});
    kappaTbl = table(expectedT, kappa1, 'VariableNames', {'T_K','kappa1_corrected_old'});

    writetable(backboneTbl, backboneOutPath);
    BACKBONE_MAP_WRITTEN = "YES";
    writetable(residualTbl, residualOutPath);
    RESIDUAL_MAP_WRITTEN = "YES";
    writetable(phiTbl, phiOutPath);
    PHI1_WRITTEN = "YES";
    writetable(kappaTbl, kappaOutPath);
    KAPPA1_WRITTEN = "YES";
    writetable(mode1Tbl, mode1OutPath);
    MODE1_RECONSTRUCTION_WRITTEN = "YES";
    writetable(resAfterTbl, resAfterOutPath);
    RESIDUAL_AFTER_MODE1_WRITTEN = "YES";

    tempList = strjoin(string(expectedT(:))', ';');
    missTxt = "NONE";
    if ~isempty(missingTemps)
        missTxt = strjoin(missingTemps', ';');
    end

    metricKey = [
        "n_temperatures";
        "temperature_list_K";
        "n_current_points";
        "n_x_grid_points";
        "fraction_finite_aligned_residual";
        "svd_mode1_explained_variance";
        "rmse_backbone_only";
        "rmse_after_mode1";
        "improvement_factor_backbone_to_mode1";
        "phi1_kappa1_sign_convention";
        "missing_temperatures";
        "interpolation_failures_count"
    ];
    metricValue = [
        string(nT);
        tempList;
        string(nI);
        string(numel(xGrid));
        string(finiteFrac);
        string(evMode1);
        string(rmseBackbone);
        string(rmseAfter);
        string(improvement);
        signConvention;
        missTxt;
        string(interpFailureCount)
    ];
    metricDetails = [
        "Temperature rows used in authoritative corrected-old build.";
        "T window locked to old recipe primary window.";
        "Current bins from clean source view and PT matrix intersection.";
        "Common aligned x-grid for SVD residual decomposition.";
        "Finite fraction over aligned residual matrix before finite-column SVD reduction.";
        "Leading singular value energy fraction over finite aligned residual columns.";
        "RMSE between S_percent and PT-only backbone.";
        "RMSE between S_percent and mode-1 reconstruction.";
        "rmse_backbone_only / rmse_after_mode1.";
        "Sign lock applied to ensure positive-mean kappa1 convention.";
        "Missing temperatures in expected T=4:2:30 window.";
        "Count of NaN phi interpolation points on original current rows."
    ];
    qualityTbl = table(metricKey, metricValue, metricDetails, 'VariableNames', {'metric_key','metric_value','details'});
    writetable(qualityTbl, qualityOutPath);
    QUALITY_METRICS_WRITTEN = "YES";

    marker = table("CORRECTED_CANONICAL_OLD_ANALYSIS", "YES", "NO", ...
        "Authoritative corrected-old artifacts now exist from gated PT-only builder run.", ...
        "reports/switching_corrected_old_authoritative_builder.md", ...
        string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
        'VariableNames', {'namespace_id','authoritative_artifacts_exist','build_blocked','reason','source_file_to_read_first','updated_utc'});
    writetable(marker, blockedMarkerPath);

    CORRECTED_OLD_AUTH_NAMESPACE_UNBLOCKED = "YES";
    SAFE_TO_USE_CORRECTED_OLD_AS_AUTHORITATIVE = "YES";
    if isfinite(improvement) && improvement > 1
        SAFE_TO_CREATE_PUBLICATION_FIGURES = "PARTIAL";
    else
        SAFE_TO_CREATE_PUBLICATION_FIGURES = "NO";
    end

catch ME
    notes(end+1,1) = "Builder failed closed: " + string(ME.message); %#ok<AGROW>
    CORRECTED_OLD_AUTH_NAMESPACE_UNBLOCKED = "NO";
    SAFE_TO_USE_CORRECTED_OLD_AS_AUTHORITATIVE = "NO";
    SAFE_TO_CREATE_PUBLICATION_FIGURES = "NO";
end

statusKey = [
    "CORRECTED_OLD_AUTHORITATIVE_BUILDER_IMPLEMENTED";
    "PREVIOUS_GATES_RECHECKED";
    "ALL_REQUIRED_GATES_PASSED";
    "SOURCE_VIEW_USED";
    "SOURCE_VIEW_IS_CLEAN";
    "LOCKED_EFFECTIVE_OBSERVABLES_USED";
    "LEGACY_PT_MATRIX_USED";
    "OLD_AUTHORITATIVE_BRANCH_PT_ONLY";
    "FALLBACK_USED";
    "CANON_GEN_DIAGNOSTIC_OUTPUTS_USED";
    "QUARANTINED_CORRECTED_OLD_ARTIFACTS_USED";
    "OLD_FIGURES_USED_AS_DATA";
    "BACKBONE_MAP_WRITTEN";
    "RESIDUAL_MAP_WRITTEN";
    "PHI1_WRITTEN";
    "KAPPA1_WRITTEN";
    "MODE1_RECONSTRUCTION_WRITTEN";
    "RESIDUAL_AFTER_MODE1_WRITTEN";
    "QUALITY_METRICS_WRITTEN";
    "CORRECTED_OLD_AUTH_NAMESPACE_UNBLOCKED";
    "SAFE_TO_USE_CORRECTED_OLD_AS_AUTHORITATIVE";
    "SAFE_TO_CREATE_PUBLICATION_FIGURES";
    "PHYSICS_LOGIC_CHANGED";
    "FILES_DELETED"
];
statusValue = [
    CORRECTED_OLD_AUTHORITATIVE_BUILDER_IMPLEMENTED;
    PREVIOUS_GATES_RECHECKED;
    ALL_REQUIRED_GATES_PASSED;
    SOURCE_VIEW_USED;
    SOURCE_VIEW_IS_CLEAN;
    LOCKED_EFFECTIVE_OBSERVABLES_USED;
    LEGACY_PT_MATRIX_USED;
    OLD_AUTHORITATIVE_BRANCH_PT_ONLY;
    FALLBACK_USED;
    CANON_GEN_DIAGNOSTIC_OUTPUTS_USED;
    QUARANTINED_CORRECTED_OLD_ARTIFACTS_USED;
    OLD_FIGURES_USED_AS_DATA;
    BACKBONE_MAP_WRITTEN;
    RESIDUAL_MAP_WRITTEN;
    PHI1_WRITTEN;
    KAPPA1_WRITTEN;
    MODE1_RECONSTRUCTION_WRITTEN;
    RESIDUAL_AFTER_MODE1_WRITTEN;
    QUALITY_METRICS_WRITTEN;
    CORRECTED_OLD_AUTH_NAMESPACE_UNBLOCKED;
    SAFE_TO_USE_CORRECTED_OLD_AS_AUTHORITATIVE;
    SAFE_TO_CREATE_PUBLICATION_FIGURES;
    PHYSICS_LOGIC_CHANGED;
    FILES_DELETED
];

statusDetails = strings(size(statusKey));
for i = 1:numel(statusKey)
    statusDetails(i) = "";
end
if ~isempty(notes)
    statusDetails(1) = strjoin(notes, ' | ');
end

statusTbl = table(statusKey, statusValue, statusDetails, 'VariableNames', {'status_key','status_value','details'});
writetable(statusTbl, statusOutPath);

fid = fopen(reportOutPath, 'w');
if fid >= 0
    fprintf(fid, '# Switching full corrected-old authoritative builder\n\n');
    fprintf(fid, '- Run mode: gated authorized full builder\n');
    fprintf(fid, '- Source view: `%s`\n', sourceViewPath);
    fprintf(fid, '- Locked observables: `%s`\n', lockedObsPath);
    fprintf(fid, '- Legacy PT_matrix: `%s`\n\n', char(ptMatrixPath));

    fprintf(fid, '## Required verdicts\n\n');
    for i = 1:height(statusTbl)
        fprintf(fid, '- %s=%s\n', statusTbl.status_key(i), statusTbl.status_value(i));
    end

    if exist(qualityOutPath, 'file') == 2
        qCell = readcell(qualityOutPath, 'FileType', 'text', 'Delimiter', ',');
        fprintf(fid, '\n## Quality metrics\n\n');
        for i = 2:size(qCell, 1)
            k = string(qCell{i, 1});
            v = string(qCell{i, 2});
            fprintf(fid, '- %s: %s\n', char(k), char(v));
        end
    end

    fprintf(fid, '\n## Output artifacts\n\n');
    fprintf(fid, '- `%s`\n', backboneOutPath);
    fprintf(fid, '- `%s`\n', residualOutPath);
    fprintf(fid, '- `%s`\n', phiOutPath);
    fprintf(fid, '- `%s`\n', kappaOutPath);
    fprintf(fid, '- `%s`\n', mode1OutPath);
    fprintf(fid, '- `%s`\n', resAfterOutPath);
    fprintf(fid, '- `%s`\n', qualityOutPath);
    fprintf(fid, '- `%s`\n', statusOutPath);

    if ~isempty(notes)
        fprintf(fid, '\n## Notes\n\n');
        for i = 1:numel(notes)
            fprintf(fid, '- %s\n', notes(i));
        end
    end
    fclose(fid);
end
