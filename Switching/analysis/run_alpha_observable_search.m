% run_alpha_observable_search
% Pure script only (no local functions).
% Absolute paths only. Manual T_K alignment with tolerance.

fprintf('[RUN] run_alpha_observable_search\n');
clearvars;

repoRoot = 'C:/Dev/matlab-functions';
scriptPath = 'C:/Dev/matlab-functions/Switching/analysis/run_alpha_observable_search.m';

alphaCsvPath = 'C:/Dev/matlab-functions/tables/alpha_structure.csv';
switchingMapMatPath = 'C:/Dev/matlab-functions/results/switching/runs/run_2026_03_10_112659_alignment_audit/switching_alignment_core_data.mat';

if contains(switchingMapMatPath, '/results/') && contains(switchingMapMatPath, '/runs/run_')
    error('DIRECT_RUN_ACCESS_FORBIDDEN');
end

outModelsPath = 'C:/Dev/matlab-functions/tables/alpha_observable_models.csv';
outReportPath = 'C:/Dev/matlab-functions/reports/alpha_observable_search.md';
outStatusPath = 'C:/Dev/matlab-functions/tables/alpha_observable_status.csv';
outDebugPath = 'C:/Dev/matlab-functions/tables/alpha_observable_debug.csv';
errorLogPath = 'C:/Dev/matlab-functions/matlab_error.log';

tablesDir = 'C:/Dev/matlab-functions/tables';
reportsDir = 'C:/Dev/matlab-functions/reports';
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

modelVarNames = { ...
    'model_type', 'model_name', 'feature_1', 'feature_2', 'n_features', ...
    'n_samples', 'rmse_loocv', 'rmse_baseline', 'rmse_improvement_fraction', ...
    'pearson', 'spearman', 'stability_sign_consistency', 'stability_coef_cv', ...
    'overfit_rejected', 'accepted_model'};
modelVarTypes = { ...
    'string', 'string', 'string', 'string', 'double', ...
    'double', 'double', 'double', 'double', ...
    'double', 'double', 'double', 'double', ...
    'string', 'string'};
modelsTbl = table('Size', [0, numel(modelVarNames)], ...
    'VariableTypes', modelVarTypes, ...
    'VariableNames', modelVarNames);

debugTbl = table('Size', [0, 4], ...
    'VariableTypes', {'string', 'double', 'double', 'double'}, ...
    'VariableNames', {'stage', 'n_rows', 'n_cols', 'n_nan_total'});

executionStatus = "FAIL";
inputFound = "NO";
N_T = 0;
X_VALID = "NO";
N_ROWS_FINAL = 0;
N_FEATURES_FINAL = 0;
FAIL_REASON = "";
ALPHA_OPERATIONAL_SIGNATURE_FOUND = "NO";
ALPHA_BEST_OBSERVABLE = "NONE";
ALPHA_PREDICTABLE_FROM_SWITCHING_MAP = "NO";
errorMessage = "";

mdLines = strings(0, 1);
mdLines(end+1) = "# Alpha observable search";
mdLines(end+1) = "";
mdLines(end+1) = "Script: `" + string(scriptPath) + "`";
mdLines(end+1) = "Input alpha table: `" + string(alphaCsvPath) + "`";
mdLines(end+1) = "Input switching map: `" + string(switchingMapMatPath) + "`";
mdLines(end+1) = "";

try
    if exist(alphaCsvPath, 'file') ~= 2
        error('run_alpha_observable_search:MissingAlphaCsv', 'Missing alpha CSV: %s', alphaCsvPath);
    end
    if exist(switchingMapMatPath, 'file') ~= 2
        error('run_alpha_observable_search:MissingSwitchingMapMat', 'Missing switching map MAT: %s', switchingMapMatPath);
    end
    inputFound = "YES";

    alphaTbl = readtable(alphaCsvPath, 'VariableNamingRule', 'preserve');
    alphaNames = string(alphaTbl.Properties.VariableNames);
    alphaNamesLow = lower(alphaNames);

    idxTk = find(contains(alphaNamesLow, 't_k') | contains(alphaNamesLow, 'temp'), 1, 'first');
    idxK1 = find(contains(alphaNamesLow, 'kappa1'), 1, 'first');
    idxK2 = find(contains(alphaNamesLow, 'kappa2'), 1, 'first');
    if isempty(idxTk), error('run_alpha_observable_search:MissingTK', 'Missing T_K column (contains-based detection).'); end
    if isempty(idxK1), error('run_alpha_observable_search:MissingKappa1', 'Missing kappa1 column (contains-based detection).'); end
    if isempty(idxK2), error('run_alpha_observable_search:MissingKappa2', 'Missing kappa2 column (contains-based detection).'); end

    T_alpha = double(alphaTbl{:, idxTk});
    kappa1 = double(alphaTbl{:, idxK1});
    kappa2 = double(alphaTbl{:, idxK2});
    alphaTarget = NaN(size(kappa1));
    mDen = isfinite(kappa1) & abs(kappa1) > eps & isfinite(kappa2);
    alphaTarget(mDen) = kappa2(mDen) ./ kappa1(mDen);

    mapData = load(switchingMapMatPath);
    mapFields = string(fieldnames(mapData));
    mapFieldsLow = lower(mapFields);

    sCandidates = find(mapFieldsLow == "smap");
    if isempty(sCandidates)
        sCandidates = find(contains(mapFieldsLow, 'smap') | (contains(mapFieldsLow, 'switch') & contains(mapFieldsLow, 'map')));
    end
    if isempty(sCandidates)
        error('run_alpha_observable_search:MissingSmap', 'Could not detect switching map field via contains().');
    end

    tCandidates = find(mapFieldsLow == "temps");
    if isempty(tCandidates), tCandidates = find(contains(mapFieldsLow, 'temp')); end
    iCandidates = find(mapFieldsLow == "currents");
    if isempty(iCandidates), iCandidates = find(contains(mapFieldsLow, 'currents') | contains(mapFieldsLow, 'current')); end
    if isempty(tCandidates), error('run_alpha_observable_search:MissingTemps', 'Could not detect temperature field via contains().'); end
    if isempty(iCandidates), error('run_alpha_observable_search:MissingCurrents', 'Could not detect current field via contains().'); end

    bestScore = -Inf;
    matchedDims = false;
    Smap = [];
    T_map = [];
    I_axis = [];

    for is = 1:numel(sCandidates)
        Stry = double(mapData.(mapFields(sCandidates(is))));
        if ~isnumeric(Stry) || ndims(Stry) > 2
            continue;
        end
        if min(size(Stry)) < 2
            continue;
        end
        for it = 1:numel(tCandidates)
            tVec = double(mapData.(mapFields(tCandidates(it))));
            tVec = tVec(:);
            for ii = 1:numel(iCandidates)
                iVec = double(mapData.(mapFields(iCandidates(ii))));
                iVec = iVec(:);
                rowsAreT = size(Stry, 1) == numel(tVec) && size(Stry, 2) == numel(iVec);
                colsAreT = size(Stry, 2) == numel(tVec) && size(Stry, 1) == numel(iVec);
                if ~(rowsAreT || colsAreT)
                    continue;
                end
                if numel(tVec) < 5 || numel(iVec) < 8
                    continue;
                end
                if rowsAreT
                    Suse = Stry;
                else
                    Suse = Stry.';
                end
                finiteFrac = nnz(isfinite(Suse)) / max(numel(Suse), 1);
                if finiteFrac <= 0
                    continue;
                end
                spread = std(Suse(isfinite(Suse)), 'omitnan');
                if ~isfinite(spread), spread = 0; end
                score = finiteFrac + 1e-3 * numel(iVec) + 1e-6 * spread;
                if score > bestScore
                    bestScore = score;
                    matchedDims = true;
                    Smap = Suse;
                    T_map = tVec;
                    I_axis = iVec;
                end
            end
        end
    end
    if ~matchedDims
        for is = 1:numel(sCandidates)
            Stry = double(mapData.(mapFields(sCandidates(is))));
            if ~isnumeric(Stry) || ndims(Stry) > 2
                continue;
            end
            for it = 1:numel(tCandidates)
                tVec = double(mapData.(mapFields(tCandidates(it))));
                tVec = tVec(:);
                for ii = 1:numel(iCandidates)
                    iVec = double(mapData.(mapFields(iCandidates(ii))));
                    iVec = iVec(:);
                    rowsAreT = size(Stry, 1) == numel(tVec) && size(Stry, 2) == numel(iVec);
                    colsAreT = size(Stry, 2) == numel(tVec) && size(Stry, 1) == numel(iVec);
                    if rowsAreT || colsAreT
                        if rowsAreT
                            Smap = Stry;
                        else
                            Smap = Stry.';
                        end
                        T_map = tVec;
                        I_axis = iVec;
                        matchedDims = true;
                        break;
                    end
                end
                if matchedDims, break; end
            end
            if matchedDims, break; end
        end
    end
    if ~matchedDims
        error('run_alpha_observable_search:DimensionMismatch', ...
            'No Smap/temperature/current candidate triplet was found via contains() + dimension matching.');
    end

    [T_map, ordT] = sort(T_map, 'ascend');
    Smap = Smap(ordT, :);
    [I_axis, ordI] = sort(I_axis, 'ascend');
    Smap = Smap(:, ordI);

    nMapT = numel(T_map);
    center_vs_tail_integral = NaN(nMapT, 1);
    signed_center_integral = NaN(nMapT, 1);
    slope_asymmetry_left_right = NaN(nMapT, 1);
    curvature_imbalance_center = NaN(nMapT, 1);
    odd_even_energy_ratio = NaN(nMapT, 1);
    local_skewness_near_peak = NaN(nMapT, 1);
    left_right_integral_ratio = NaN(nMapT, 1);
    left_right_integral_diff = NaN(nMapT, 1);
    center_tail_integral_ratio = NaN(nMapT, 1);
    center_tail_integral_diff = NaN(nMapT, 1);
    center_vs_tail_integral_div_speak = NaN(nMapT, 1);
    signed_center_integral_div_speak = NaN(nMapT, 1);
    slope_asymmetry_left_right_div_speak = NaN(nMapT, 1);
    curvature_imbalance_center_div_speak = NaN(nMapT, 1);
    odd_even_energy_ratio_div_speak = NaN(nMapT, 1);
    local_skewness_near_peak_div_speak = NaN(nMapT, 1);
    center_vs_tail_integral_div_integral = NaN(nMapT, 1);
    signed_center_integral_div_integral = NaN(nMapT, 1);
    slope_asymmetry_left_right_div_integral = NaN(nMapT, 1);
    curvature_imbalance_center_div_integral = NaN(nMapT, 1);
    odd_even_energy_ratio_div_integral = NaN(nMapT, 1);
    local_skewness_near_peak_div_integral = NaN(nMapT, 1);

    centerWindow_mA = 6.0;
    tailStart_mA = 12.0;
    slopeWindow_mA = 10.0;
    curvatureWindow_mA = 8.0;
    skewWindow_mA = 10.0;

    for it = 1:nMapT
        rI = I_axis(:);
        rS = Smap(it, :).';
        mFin = isfinite(rI) & isfinite(rS);
        if nnz(mFin) < 8, continue; end
        rI = rI(mFin);
        rS = rS(mFin);
        [rI, ord] = sort(rI, 'ascend');
        rS = rS(ord);
        [rIu, ~, g] = unique(rI, 'sorted');
        if numel(rIu) < 8, continue; end
        rS = accumarray(g, rS, [], @(x) mean(x, 'omitnan'));
        rI = rIu;

        [Speak, iPk] = max(rS);
        if ~isfinite(Speak) || ~isfinite(iPk), continue; end
        Ipk = rI(iPk);
        x = rI - Ipk;

        tailMask = abs(x) >= tailStart_mA;
        if nnz(tailMask) >= 2
            baseline = mean(rS(tailMask), 'omitnan');
        else
            baseline = min(rS, [], 'omitnan');
        end
        Srel = rS - baseline;
        Spos = max(Srel, 0);

        totalInt = trapz(rI, Spos);
        if ~(isfinite(totalInt) && totalInt > eps)
            totalInt = trapz(rI, abs(Srel));
        end
        if ~(isfinite(totalInt) && totalInt > eps)
            totalInt = trapz(rI, abs(rS - mean(rS, 'omitnan')));
        end
        if ~(isfinite(totalInt) && totalInt > eps)
            totalInt = 1.0;
        end

        centerMask = abs(x) <= centerWindow_mA;
        leftMask = x < 0;
        rightMask = x > 0;
        if nnz(centerMask) < 2 || nnz(~centerMask) < 2
            [~, ordAbs] = sort(abs(x), 'ascend');
            nCenter = max(2, floor(0.35 * numel(x)));
            nCenter = min(nCenter, max(numel(x) - 2, 2));
            centerMask = false(numel(x), 1);
            centerMask(ordAbs(1:nCenter)) = true;
        end
        tailMask = ~centerMask;
        if nnz(leftMask) < 2 || nnz(rightMask) < 2
            xMid = median(x, 'omitnan');
            leftMask = x <= xMid;
            rightMask = x > xMid;
        end
        leftNear = leftMask & (abs(x) <= slopeWindow_mA);
        rightNear = rightMask & (abs(x) <= slopeWindow_mA);
        if nnz(leftNear) < 2, leftNear = leftMask; end
        if nnz(rightNear) < 2, rightNear = rightMask; end
        leftCurv = leftMask & (abs(x) <= curvatureWindow_mA);
        rightCurv = rightMask & (abs(x) <= curvatureWindow_mA);
        if nnz(leftCurv) < 2, leftCurv = leftMask; end
        if nnz(rightCurv) < 2, rightCurv = rightMask; end
        skewMask = abs(x) <= skewWindow_mA;
        if nnz(skewMask) < 3, skewMask = centerMask; end

        cInt = trapz(rI(centerMask), Spos(centerMask));
        tInt = trapz(rI(tailMask), Spos(tailMask));
        lInt = trapz(rI(leftMask), Spos(leftMask));
        rInt = trapz(rI(rightMask), Spos(rightMask));

        center_vs_tail_integral(it) = (cInt - tInt) / max(totalInt, eps);
        center_tail_integral_ratio(it) = cInt / max(tInt, eps);
        center_tail_integral_diff(it) = cInt - tInt;
        signed_center_integral(it) = trapz(rI(centerMask), Srel(centerMask)) / max(totalInt, eps);
        left_right_integral_ratio(it) = rInt / max(lInt, eps);
        left_right_integral_diff(it) = rInt - lInt;

        dS = gradient(rS, rI);
        sL = mean(abs(dS(leftNear)), 'omitnan');
        sR = mean(abs(dS(rightNear)), 'omitnan');
        slope_asymmetry_left_right(it) = (sR - sL) / max(abs(sR) + abs(sL), eps);

        d2S = gradient(dS, rI);
        cL = trapz(abs(x(leftCurv)), abs(d2S(leftCurv)));
        cR = trapz(abs(x(rightCurv)), abs(d2S(rightCurv)));
        curvature_imbalance_center(it) = (cR - cL) / max(cR + cL, eps);

        xMax = min(max(x(rightMask)), max(-x(leftMask)));
        if isfinite(xMax) && xMax > 0
            xs = linspace(0, xMax, 121).';
            Sp = interp1(x, Srel, xs, 'linear', NaN);
            Sm = interp1(x, Srel, -xs, 'linear', NaN);
            v = isfinite(xs) & isfinite(Sp) & isfinite(Sm);
            if nnz(v) >= 3
                oddPart = 0.5 * (Sp(v) - Sm(v));
                evenPart = 0.5 * (Sp(v) + Sm(v));
                oddE = trapz(xs(v), oddPart .^ 2);
                evenE = trapz(xs(v), evenPart .^ 2);
                odd_even_energy_ratio(it) = oddE / max(evenE, eps);
            end
        end
        if ~isfinite(odd_even_energy_ratio(it))
            odd_even_energy_ratio(it) = abs(rInt - lInt) / max(abs(rInt) + abs(lInt), eps);
        end

        xloc = x(skewMask);
        wloc = max(Srel(skewMask), 0);
        wsum = sum(wloc, 'omitnan');
        if isfinite(wsum) && wsum > eps
            mu = sum(wloc .* xloc, 'omitnan') / wsum;
            vloc = sum(wloc .* (xloc - mu) .^ 2, 'omitnan') / wsum;
            sig = sqrt(vloc);
            if isfinite(sig) && sig > eps
                local_skewness_near_peak(it) = sum(wloc .* ((xloc - mu) ./ sig) .^ 3, 'omitnan') / wsum;
            end
        end
        if ~isfinite(local_skewness_near_peak(it))
            local_skewness_near_peak(it) = 0;
        end

        scaleSpeak = max(abs(Speak), eps);
        scaleInt = max(totalInt, eps);
        center_vs_tail_integral_div_speak(it) = center_vs_tail_integral(it) / scaleSpeak;
        signed_center_integral_div_speak(it) = signed_center_integral(it) / scaleSpeak;
        slope_asymmetry_left_right_div_speak(it) = slope_asymmetry_left_right(it) / scaleSpeak;
        curvature_imbalance_center_div_speak(it) = curvature_imbalance_center(it) / scaleSpeak;
        odd_even_energy_ratio_div_speak(it) = odd_even_energy_ratio(it) / scaleSpeak;
        local_skewness_near_peak_div_speak(it) = local_skewness_near_peak(it) / scaleSpeak;
        center_vs_tail_integral_div_integral(it) = center_vs_tail_integral(it) / scaleInt;
        signed_center_integral_div_integral(it) = signed_center_integral(it) / scaleInt;
        slope_asymmetry_left_right_div_integral(it) = slope_asymmetry_left_right(it) / scaleInt;
        curvature_imbalance_center_div_integral(it) = curvature_imbalance_center(it) / scaleInt;
        odd_even_energy_ratio_div_integral(it) = odd_even_energy_ratio(it) / scaleInt;
        local_skewness_near_peak_div_integral(it) = local_skewness_near_peak(it) / scaleInt;

        if ~isfinite(center_vs_tail_integral(it)), center_vs_tail_integral(it) = 0; end
        if ~isfinite(signed_center_integral(it)), signed_center_integral(it) = 0; end
        if ~isfinite(slope_asymmetry_left_right(it)), slope_asymmetry_left_right(it) = 0; end
        if ~isfinite(curvature_imbalance_center(it)), curvature_imbalance_center(it) = 0; end
        if ~isfinite(odd_even_energy_ratio(it)), odd_even_energy_ratio(it) = 0; end
        if ~isfinite(local_skewness_near_peak(it)), local_skewness_near_peak(it) = 0; end
        if ~isfinite(left_right_integral_ratio(it)), left_right_integral_ratio(it) = 0; end
        if ~isfinite(left_right_integral_diff(it)), left_right_integral_diff(it) = 0; end
        if ~isfinite(center_tail_integral_ratio(it)), center_tail_integral_ratio(it) = 0; end
        if ~isfinite(center_tail_integral_diff(it)), center_tail_integral_diff(it) = 0; end
        if ~isfinite(center_vs_tail_integral_div_speak(it)), center_vs_tail_integral_div_speak(it) = 0; end
        if ~isfinite(signed_center_integral_div_speak(it)), signed_center_integral_div_speak(it) = 0; end
        if ~isfinite(slope_asymmetry_left_right_div_speak(it)), slope_asymmetry_left_right_div_speak(it) = 0; end
        if ~isfinite(curvature_imbalance_center_div_speak(it)), curvature_imbalance_center_div_speak(it) = 0; end
        if ~isfinite(odd_even_energy_ratio_div_speak(it)), odd_even_energy_ratio_div_speak(it) = 0; end
        if ~isfinite(local_skewness_near_peak_div_speak(it)), local_skewness_near_peak_div_speak(it) = 0; end
        if ~isfinite(center_vs_tail_integral_div_integral(it)), center_vs_tail_integral_div_integral(it) = 0; end
        if ~isfinite(signed_center_integral_div_integral(it)), signed_center_integral_div_integral(it) = 0; end
        if ~isfinite(slope_asymmetry_left_right_div_integral(it)), slope_asymmetry_left_right_div_integral(it) = 0; end
        if ~isfinite(curvature_imbalance_center_div_integral(it)), curvature_imbalance_center_div_integral(it) = 0; end
        if ~isfinite(odd_even_energy_ratio_div_integral(it)), odd_even_energy_ratio_div_integral(it) = 0; end
        if ~isfinite(local_skewness_near_peak_div_integral(it)), local_skewness_near_peak_div_integral(it) = 0; end
    end

    featTbl = table(T_map, ...
        center_vs_tail_integral, signed_center_integral, slope_asymmetry_left_right, ...
        curvature_imbalance_center, odd_even_energy_ratio, local_skewness_near_peak, ...
        left_right_integral_ratio, left_right_integral_diff, center_tail_integral_ratio, center_tail_integral_diff, ...
        center_vs_tail_integral_div_speak, signed_center_integral_div_speak, slope_asymmetry_left_right_div_speak, ...
        curvature_imbalance_center_div_speak, odd_even_energy_ratio_div_speak, local_skewness_near_peak_div_speak, ...
        center_vs_tail_integral_div_integral, signed_center_integral_div_integral, slope_asymmetry_left_right_div_integral, ...
        curvature_imbalance_center_div_integral, odd_even_energy_ratio_div_integral, local_skewness_near_peak_div_integral, ...
        'VariableNames', { ...
        'T_map', ...
        'center_vs_tail_integral', 'signed_center_integral', 'slope_asymmetry_left_right', ...
        'curvature_imbalance_center', 'odd_even_energy_ratio', 'local_skewness_near_peak', ...
        'left_right_integral_ratio', 'left_right_integral_diff', 'center_tail_integral_ratio', 'center_tail_integral_diff', ...
        'center_vs_tail_integral_div_speak', 'signed_center_integral_div_speak', 'slope_asymmetry_left_right_div_speak', ...
        'curvature_imbalance_center_div_speak', 'odd_even_energy_ratio_div_speak', 'local_skewness_near_peak_div_speak', ...
        'center_vs_tail_integral_div_integral', 'signed_center_integral_div_integral', 'slope_asymmetry_left_right_div_integral', ...
        'curvature_imbalance_center_div_integral', 'odd_even_energy_ratio_div_integral', 'local_skewness_near_peak_div_integral'});

    nAlpha = numel(T_alpha);
    alignedTbl = table(T_alpha(:), alphaTarget(:), NaN(nAlpha, 1), NaN(nAlpha, 1), ...
        'VariableNames', {'T_K', 'alpha', 'T_map_matched', 'T_match_abs_delta'});
    fNames = featTbl.Properties.VariableNames;
    for iv = 2:numel(fNames)
        alignedTbl.(fNames{iv}) = NaN(nAlpha, 1);
    end

    tTol = 0.25;
    for ia = 1:nAlpha
        if ~isfinite(T_alpha(ia)), continue; end
        dT = abs(featTbl.T_map - T_alpha(ia));
        [dMin, idxMin] = min(dT);
        if ~isempty(idxMin) && isfinite(dMin) && dMin <= tTol
            alignedTbl.T_map_matched(ia) = featTbl.T_map(idxMin);
            alignedTbl.T_match_abs_delta(ia) = dMin;
            for iv = 2:numel(fNames)
                alignedTbl.(fNames{iv})(ia) = featTbl.(fNames{iv})(idxMin);
            end
        end
    end

    % Debug stage: raw_join
    XfullRaw = alignedTbl{:, fNames(2:end)};
    yfullRaw = alignedTbl.alpha;
    nRawRows = size(XfullRaw, 1);
    nRawCols = size(XfullRaw, 2);
    nanRaw = sum(isnan(XfullRaw(:))) + sum(isnan(yfullRaw(:)));
    debugTbl = [debugTbl; {"raw_join", nRawRows, nRawCols, nanRaw}]; %#ok<AGROW>

    % Debug stage: after_alignment
    mAlign = isfinite(alignedTbl.T_map_matched);
    alignedUse = alignedTbl(mAlign, :);
    Xalign = alignedUse{:, fNames(2:end)};
    yalign = alignedUse.alpha;
    debugTbl = [debugTbl; {"after_alignment", size(Xalign, 1), size(Xalign, 2), sum(isnan(Xalign(:))) + sum(isnan(yalign(:)))}]; %#ok<AGROW>

    % Debug stage: after_finite_filter (filter only target)
    mY = isfinite(alignedUse.alpha);
    modelTbl = alignedUse(mY, :);
    Xraw = modelTbl{:, fNames(2:end)};
    yraw = modelTbl.alpha;
    debugTbl = [debugTbl; {"after_finite_filter", size(Xraw, 1), size(Xraw, 2), sum(isnan(Xraw(:))) + sum(isnan(yraw(:)))}]; %#ok<AGROW>

    % Fill missing features to preserve rows and avoid empty X.
    for j = 1:size(Xraw, 2)
        col = Xraw(:, j);
        col(~isfinite(col)) = NaN;
        if any(isfinite(col))
            col = fillmissing(col, 'linear', 'EndValues', 'nearest');
            col = fillmissing(col, 'nearest');
            if any(~isfinite(col))
                medv = median(col, 'omitnan');
                if ~isfinite(medv), medv = 0; end
                col(~isfinite(col)) = medv;
            end
        else
            col(:) = 0;
        end
        Xraw(:, j) = col;
    end

    X = double(Xraw);
    y = double(yraw);
    X(~isfinite(X)) = NaN;
    y(~isfinite(y)) = NaN;

    % Final finite pass: keep rows with finite y and fully finite X.
    mFinal = isfinite(y);
    if ~isempty(X)
        mFinal = mFinal & all(isfinite(X), 2);
    end
    X = X(mFinal, :);
    y = y(mFinal, :);

    % Debug stage: before_model
    debugTbl = [debugTbl; {"before_model", size(X, 1), size(X, 2), sum(isnan(X(:))) + sum(isnan(y(:)))}]; %#ok<AGROW>

    N_T = size(X, 1);
    N_ROWS_FINAL = size(X, 1);
    N_FEATURES_FINAL = size(X, 2);

    fprintf('size(X) = [%d, %d]\n', size(X, 1), size(X, 2));
    fprintf('size(y) = [%d, %d]\n', size(y, 1), size(y, 2));
    fprintf('rows before filtering = %d\n', nRawRows);
    fprintf('rows after filtering = %d\n', N_ROWS_FINAL);
    for j = 1:size(Xraw, 2)
        fprintf('NaNs in feature column %d before final finite filter: %d\n', j, sum(isnan(Xraw(:, j))));
    end

    % Hard guards required by policy.
    if isempty(X)
        executionStatus = "FAIL_EMPTY_MATRIX";
        FAIL_REASON = "X is empty after alignment/filter pipeline.";
    elseif size(X, 2) == 0
        executionStatus = "FAIL_NO_FEATURES";
        FAIL_REASON = "X has zero feature columns.";
    elseif size(X, 1) < 3
        executionStatus = "FAIL_DATA_TOO_SMALL";
        FAIL_REASON = "X has fewer than 3 rows.";
    elseif ~isnumeric(X)
        executionStatus = "FAIL_INVALID_X";
        FAIL_REASON = "X is not numeric.";
    elseif any(~isfinite(X), 'all')
        executionStatus = "FAIL_INVALID_X";
        FAIL_REASON = "X contains non-finite values.";
    else
        X_VALID = "YES";
    end

    if X_VALID == "YES"
        featureList = fNames(2:end);

        % Single-feature models
        for fi = 1:numel(featureList)
            f1 = featureList{fi};
            x1 = X(:, fi);
            n = numel(y);
            p = 1;

            yhat = NaN(n, 1);
            yhatBase = NaN(n, 1);
            betaLOO = NaN(n, p + 1);

            if n >= 5
                for ii = 1:n
                    tr = true(n, 1); tr(ii) = false;
                    ytr = y(tr);
                    xtr = x1(tr);
                    yhatBase(ii) = mean(ytr, 'omitnan');
                    Ztr = [ones(nnz(tr), 1), xtr];
                    b = pinv(Ztr) * ytr;
                    betaLOO(ii, :) = b.';
                    yhat(ii) = [1, x1(ii)] * b;
                end
            end

            rmseBase = sqrt(mean((y - yhatBase) .^ 2, 'omitnan'));
            rmseLoo = sqrt(mean((y - yhat) .^ 2, 'omitnan'));
            impFrac = (rmseBase - rmseLoo) / max(rmseBase, eps);

            mCorr = isfinite(y) & isfinite(yhat);
            if nnz(mCorr) >= 2
                pear = corr(y(mCorr), yhat(mCorr), 'rows', 'pairwise');
                spear = corr(y(mCorr), yhat(mCorr), 'type', 'Spearman', 'rows', 'pairwise');
            else
                pear = NaN;
                spear = NaN;
            end

            bcol = betaLOO(:, 2);
            bcol = bcol(isfinite(bcol));
            if isempty(bcol)
                signStability = NaN;
                coefCv = NaN;
            else
                signStability = max(mean(bcol > 0), mean(bcol < 0));
                coefCv = std(bcol, 'omitnan') / max(abs(mean(bcol, 'omitnan')), eps);
            end

            overfitRejected = "YES";
            acceptedModel = "NO";
            if isfinite(rmseLoo) && isfinite(rmseBase) && (rmseLoo < rmseBase - 1e-12)
                overfitRejected = "NO";
                acceptedModel = "YES";
            end

            row = table("single_feature", "alpha ~ " + string(f1), string(f1), "", ...
                1, n, rmseLoo, rmseBase, impFrac, pear, spear, signStability, coefCv, ...
                overfitRejected, acceptedModel, ...
                'VariableNames', modelVarNames);
            modelsTbl = [modelsTbl; row]; %#ok<AGROW>
        end

        % Two-feature linear models
        pairIdx = nchoosek(1:numel(featureList), 2);
        for pi = 1:size(pairIdx, 1)
            i1 = pairIdx(pi, 1);
            i2 = pairIdx(pi, 2);
            f1 = featureList{i1};
            f2 = featureList{i2};
            xPair = X(:, [i1, i2]);
            n = numel(y);
            p = 2;

            yhat = NaN(n, 1);
            yhatBase = NaN(n, 1);
            betaLOO = NaN(n, p + 1);

            if n >= 5
                for ii = 1:n
                    tr = true(n, 1); tr(ii) = false;
                    ytr = y(tr);
                    Xtr = xPair(tr, :);
                    yhatBase(ii) = mean(ytr, 'omitnan');
                    Ztr = [ones(nnz(tr), 1), Xtr];
                    b = pinv(Ztr) * ytr;
                    betaLOO(ii, :) = b.';
                    yhat(ii) = [1, xPair(ii, :)] * b;
                end
            end

            rmseBase = sqrt(mean((y - yhatBase) .^ 2, 'omitnan'));
            rmseLoo = sqrt(mean((y - yhat) .^ 2, 'omitnan'));
            impFrac = (rmseBase - rmseLoo) / max(rmseBase, eps);

            mCorr = isfinite(y) & isfinite(yhat);
            if nnz(mCorr) >= 2
                pear = corr(y(mCorr), yhat(mCorr), 'rows', 'pairwise');
                spear = corr(y(mCorr), yhat(mCorr), 'type', 'Spearman', 'rows', 'pairwise');
            else
                pear = NaN;
                spear = NaN;
            end

            b1 = betaLOO(:, 2); b1 = b1(isfinite(b1));
            b2 = betaLOO(:, 3); b2 = b2(isfinite(b2));
            sc = NaN(2, 1);
            cv = NaN(2, 1);
            if ~isempty(b1)
                sc(1) = max(mean(b1 > 0), mean(b1 < 0));
                cv(1) = std(b1, 'omitnan') / max(abs(mean(b1, 'omitnan')), eps);
            end
            if ~isempty(b2)
                sc(2) = max(mean(b2 > 0), mean(b2 < 0));
                cv(2) = std(b2, 'omitnan') / max(abs(mean(b2, 'omitnan')), eps);
            end
            signStability = mean(sc, 'omitnan');
            coefCv = mean(cv, 'omitnan');

            overfitRejected = "YES";
            acceptedModel = "NO";
            if isfinite(rmseLoo) && isfinite(rmseBase) && (rmseLoo < rmseBase - 1e-12)
                overfitRejected = "NO";
                acceptedModel = "YES";
            end

            row = table("two_feature_linear", "alpha ~ " + string(f1) + " + " + string(f2), ...
                string(f1), string(f2), ...
                2, n, rmseLoo, rmseBase, impFrac, pear, spear, signStability, coefCv, ...
                overfitRejected, acceptedModel, ...
                'VariableNames', modelVarNames);
            modelsTbl = [modelsTbl; row]; %#ok<AGROW>
        end

        if ~isempty(modelsTbl)
            modelsTbl = sortrows(modelsTbl, {'accepted_model', 'rmse_loocv', 'n_features'}, {'descend', 'ascend', 'ascend'});
        end

        okModel = isfinite(modelsTbl.rmse_loocv);
        if nnz(okModel) == 0
            executionStatus = "FAIL_NO_VALID_MODELS";
            FAIL_REASON = "No models produced finite LOOCV RMSE.";
        else
            acceptedMask = modelsTbl.accepted_model == "YES";
            if any(acceptedMask)
                bestRows = modelsTbl(acceptedMask, :);
                bestRows = sortrows(bestRows, {'rmse_loocv', 'n_features'}, {'ascend', 'ascend'});
                best = bestRows(1, :);
                ALPHA_BEST_OBSERVABLE = string(best.model_name(1));
                bestImp = best.rmse_improvement_fraction(1);
                bestCorr = max(abs([best.pearson(1), best.spearman(1)]), [], 'omitnan');
                if isfinite(bestImp) && isfinite(bestCorr) && bestImp >= 0.03 && bestCorr >= 0.40
                    ALPHA_OPERATIONAL_SIGNATURE_FOUND = "YES";
                end
                if isfinite(bestImp) && isfinite(best.pearson(1)) && isfinite(best.spearman(1)) && ...
                        bestImp >= 0.08 && abs(best.pearson(1)) >= 0.55 && abs(best.spearman(1)) >= 0.55
                    ALPHA_PREDICTABLE_FROM_SWITCHING_MAP = "YES";
                end
            end
            executionStatus = "SUCCESS";
        end
    end

    mdLines(end+1) = "## Data pipeline debug";
    mdLines(end+1) = "- size(X): `" + string(size(X, 1)) + " x " + string(size(X, 2)) + "`";
    mdLines(end+1) = "- size(y): `" + string(size(y, 1)) + " x " + string(size(y, 2)) + "`";
    mdLines(end+1) = "- rows before filtering: `" + string(nRawRows) + "`";
    mdLines(end+1) = "- rows after filtering: `" + string(N_ROWS_FINAL) + "`";
    mdLines(end+1) = "";
    mdLines(end+1) = "## Status";
    mdLines(end+1) = "- EXECUTION_STATUS: `" + executionStatus + "`";
    mdLines(end+1) = "- INPUT_FOUND: `" + inputFound + "`";
    mdLines(end+1) = "- N_T: `" + string(N_T) + "`";
    mdLines(end+1) = "- X_VALID: `" + X_VALID + "`";
    mdLines(end+1) = "- N_ROWS_FINAL: `" + string(N_ROWS_FINAL) + "`";
    mdLines(end+1) = "- N_FEATURES_FINAL: `" + string(N_FEATURES_FINAL) + "`";
    mdLines(end+1) = "- FAIL_REASON: `" + FAIL_REASON + "`";
    mdLines(end+1) = "- ALPHA_OPERATIONAL_SIGNATURE_FOUND: `" + ALPHA_OPERATIONAL_SIGNATURE_FOUND + "`";
    mdLines(end+1) = "- ALPHA_BEST_OBSERVABLE: `" + ALPHA_BEST_OBSERVABLE + "`";
    mdLines(end+1) = "- ALPHA_PREDICTABLE_FROM_SWITCHING_MAP: `" + ALPHA_PREDICTABLE_FROM_SWITCHING_MAP + "`";
    mdLines(end+1) = "";

    if ~isempty(modelsTbl)
        topN = min(height(modelsTbl), 10);
        mdLines(end+1) = "## Top models";
        mdLines(end+1) = "| model | rmse_loocv | rmse_baseline | improvement | pearson | spearman | accepted |";
        mdLines(end+1) = "|---|---:|---:|---:|---:|---:|---|";
        for i = 1:topN
            mdLines(end+1) = "| " + string(modelsTbl.model_name(i)) + ...
                " | " + sprintf('%.6g', modelsTbl.rmse_loocv(i)) + ...
                " | " + sprintf('%.6g', modelsTbl.rmse_baseline(i)) + ...
                " | " + sprintf('%.6g', modelsTbl.rmse_improvement_fraction(i)) + ...
                " | " + sprintf('%.6g', modelsTbl.pearson(i)) + ...
                " | " + sprintf('%.6g', modelsTbl.spearman(i)) + ...
                " | " + string(modelsTbl.accepted_model(i)) + " |";
        end
    end

catch ME
    if executionStatus == "FAIL"
        executionStatus = "FAIL_EXCEPTION";
    end
    errorMessage = string(ME.message);
    if strlength(FAIL_REASON) == 0
        FAIL_REASON = errorMessage;
    end
    try
        fidErr = fopen(errorLogPath, 'a');
        if fidErr ~= -1
            fprintf(fidErr, '%s\n', getReport(ME, 'extended'));
            fclose(fidErr);
        end
    catch
    end
    mdLines(end+1) = "## Execution failure";
    mdLines(end+1) = "- ERROR_MESSAGE: `" + errorMessage + "`";
end

if strlength(errorMessage) == 0 && strlength(FAIL_REASON) > 0 && executionStatus ~= "SUCCESS"
    errorMessage = FAIL_REASON;
end

statusTbl = table( ...
    executionStatus, ...
    inputFound, ...
    N_T, ...
    X_VALID, ...
    N_ROWS_FINAL, ...
    N_FEATURES_FINAL, ...
    FAIL_REASON, ...
    ALPHA_OPERATIONAL_SIGNATURE_FOUND, ...
    ALPHA_BEST_OBSERVABLE, ...
    ALPHA_PREDICTABLE_FROM_SWITCHING_MAP, ...
    errorMessage, ...
    'VariableNames', { ...
    'EXECUTION_STATUS', ...
    'INPUT_FOUND', ...
    'N_T', ...
    'X_VALID', ...
    'N_ROWS_FINAL', ...
    'N_FEATURES_FINAL', ...
    'FAIL_REASON', ...
    'ALPHA_OPERATIONAL_SIGNATURE_FOUND', ...
    'ALPHA_BEST_OBSERVABLE', ...
    'ALPHA_PREDICTABLE_FROM_SWITCHING_MAP', ...
    'ERROR_MESSAGE'});

if isempty(debugTbl)
    debugTbl = table("before_model", 0, 0, 0, ...
        'VariableNames', {'stage', 'n_rows', 'n_cols', 'n_nan_total'});
end

if numel(mdLines) == 0
    mdLines = "# Alpha observable search" + newline + "No report content generated.";
end

writetable(modelsTbl, outModelsPath);
writetable(debugTbl, outDebugPath);
writetable(statusTbl, outStatusPath);

fid = fopen(outReportPath, 'w');
if fid ~= -1
    fprintf(fid, '%s\n', char(strjoin(mdLines, newline)));
    fclose(fid);
else
    statusTbl.EXECUTION_STATUS = "FAIL_REPORT_WRITE";
    statusTbl.ERROR_MESSAGE = "Failed to write markdown report.";
    writetable(statusTbl, outStatusPath);
end

fprintf('[DONE] run_alpha_observable_search -> %s\n', outStatusPath);
