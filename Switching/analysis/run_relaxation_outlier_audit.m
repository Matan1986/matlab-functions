% run_relaxation_outlier_audit
% Pure script only. One focused analysis pass for relaxation outlier audit.

fprintf('[RUN] run_relaxation_outlier_audit\n');
clearvars;

repoRoot = 'C:/Dev/matlab-functions';
scriptPath = 'C:/Dev/matlab-functions/Switching/analysis/run_relaxation_outlier_audit.m';

inRelaxPath = 'C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv';
inFlagsPath = 'C:/Dev/matlab-functions/tables/relaxation_dataset_validation_status.csv';
inAlphaPath = 'C:/Dev/matlab-functions/tables/alpha_structure.csv';
inSwitchingPath = 'C:/Dev/matlab-functions/results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_parameters.csv';

outAuditPath = 'C:/Dev/matlab-functions/tables/relaxation_outlier_audit.csv';
outStatusPath = 'C:/Dev/matlab-functions/tables/relaxation_outlier_audit_status.csv';
outReportPath = 'C:/Dev/matlab-functions/reports/relaxation_outlier_audit.md';

if exist('C:/Dev/matlab-functions/tables', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/tables');
end
if exist('C:/Dev/matlab-functions/reports', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/reports');
end

EXECUTION_STATUS = "FAIL";
INPUT_FOUND = "NO";
ERROR_MESSAGE = "";
N_T = 0;
MAIN_RESULT_SUMMARY = "Not executed.";
PRIOR_FLAGS_HAS_OUTLIERS = "UNKNOWN";

OUTLIERS_LOCALIZED_AT_TRANSITION = "NO";
OUTLIERS_CORRELATED_WITH_KAPPA2 = "NO";
OUTLIERS_HAVE_CURVATURE_SIGNATURE = "NO";
OUTLIERS_FORM_CONSISTENT_SHAPE = "NO";
OUTLIERS_ARE_PHYSICAL = "NO";
OUTLIERS_ARE_ARTIFACT = "YES";

alignmentRule = "Nearest-neighbor manual alignment by |T_relax - T_kappa| <= 1 K (tie resolves to lower T_relax).";
alignmentN = 0;
alignmentMeanDeltaT = NaN;

meanOutlierInside = NaN;
meanOutlierOutside = NaN;
insideOutsideRatio = NaN;

pearsonOutlierKappa2 = NaN;
spearmanOutlierKappa2 = NaN;
pearsonShapeFlipKappa2 = NaN;
spearmanShapeFlipKappa2 = NaN;
pearsonWidthZKappa2 = NaN;
spearmanWidthZKappa2 = NaN;
pearsonCurvOutlier = NaN;
spearmanCurvOutlier = NaN;
pearsonCurvKappa2 = NaN;
spearmanCurvKappa2 = NaN;

meanSimWithinOutlier = NaN;
varSimWithinOutlier = NaN;
meanSimWithinNonOutlier = NaN;
varSimWithinNonOutlier = NaN;
meanSimBetweenGroups = NaN;

Tuniq = zeros(0,1);
nPointsPerT = zeros(0,1);
shapeFlip = zeros(0,1);
rSignChange = zeros(0,1);
dRNonMonotonic = zeros(0,1);
widthMetric = NaN(0,1);
widthZ = NaN(0,1);
widthOutlier = zeros(0,1);
outlierScore = NaN(0,1);
curvMaxAbs = NaN(0,1);
curvAnom = NaN(0,1);
anyOutlier = zeros(0,1);
inTransition = zeros(0,1);
alignedAlphaT = NaN(0,1);
alignedKappa1 = NaN(0,1);
alignedKappa2 = NaN(0,1);

md = strings(0,1);
md(end+1) = "# Relaxation Outlier Audit";
md(end+1) = "";
md(end+1) = "Script: `" + string(scriptPath) + "`";
md(end+1) = "Input relaxation: `" + string(inRelaxPath) + "`";
md(end+1) = "Input outlier flags: `" + string(inFlagsPath) + "`";
md(end+1) = "Input kappa: `" + string(inAlphaPath) + "`";
md(end+1) = "Optional switching observables: `" + string(inSwitchingPath) + "`";
md(end+1) = "";

try
    hasRelax = exist(inRelaxPath, 'file') == 2;
    hasAlpha = exist(inAlphaPath, 'file') == 2;
    hasFlags = exist(inFlagsPath, 'file') == 2;
    hasSwitching = exist(inSwitchingPath, 'file') == 2; %#ok<NASGU>

    if hasRelax && hasAlpha
        INPUT_FOUND = "YES";
    else
        INPUT_FOUND = "NO";
        error('run_relaxation_outlier_audit:MissingInput', ...
            'Required inputs missing. relaxation_full_dataset=%d, alpha_structure=%d', hasRelax, hasAlpha);
    end

    if hasFlags
        flagsTbl = readtable(inFlagsPath, 'VariableNamingRule', 'preserve');
        if height(flagsTbl) >= 1
            flagNames = string(flagsTbl.Properties.VariableNames);
            flagLow = lower(flagNames);
            idxHasOut = find(contains(flagLow, 'has_outliers'), 1, 'first');
            if ~isempty(idxHasOut)
                PRIOR_FLAGS_HAS_OUTLIERS = string(flagsTbl{1, idxHasOut});
            end
        end
    end

    relaxTbl = readtable(inRelaxPath, 'VariableNamingRule', 'preserve');
    relaxNames = string(relaxTbl.Properties.VariableNames);
    relaxLow = lower(relaxNames);

    idxT = find(contains(relaxLow, 't_k') | (relaxLow == "t") | contains(relaxLow, 'temp'), 1, 'first');
    idxLogt = find(contains(relaxLow, 'logt') | contains(relaxLow, 'log_t') | contains(relaxLow, 'log10_t') | (contains(relaxLow, 'log10') & contains(relaxLow, 't')), 1, 'first');
    idxM = find((relaxLow == "m") | contains(relaxLow, 'magnet') | contains(relaxLow, 'signal'), 1, 'first');

    miss = strings(0,1);
    if isempty(idxT), miss(end+1) = "T_K"; end
    if isempty(idxLogt), miss(end+1) = "logt"; end
    if isempty(idxM), miss(end+1) = "M"; end
    if ~isempty(miss)
        error('run_relaxation_outlier_audit:MissingColumns', ...
            'Missing required columns in relaxation table: %s', strjoin(miss, ', '));
    end

    Tk = double(relaxTbl{:, idxT});
    logt = double(relaxTbl{:, idxLogt});
    M = double(relaxTbl{:, idxM});

    finiteRelax = isfinite(Tk) & isfinite(logt) & isfinite(M);
    Tk = Tk(finiteRelax);
    logt = logt(finiteRelax);
    M = M(finiteRelax);

    if isempty(Tk)
        error('run_relaxation_outlier_audit:NoFiniteRows', 'No finite rows in relaxation dataset.');
    end

    Tuniq = unique(Tk, 'stable');
    N_T = numel(Tuniq);
    if N_T < 1
        error('run_relaxation_outlier_audit:NoTemperatures', 'No temperatures in relaxation dataset.');
    end

    nPointsPerT = zeros(N_T,1);
    shapeFlip = zeros(N_T,1);
    rSignChange = zeros(N_T,1);
    dRNonMonotonic = zeros(N_T,1);
    widthMetric = NaN(N_T,1);
    curvMaxAbs = NaN(N_T,1);
    RnormCell = cell(N_T,1);

    for i = 1:N_T
        tNow = Tuniq(i);
        msk = abs(Tk - tNow) < 1e-12;
        li = logt(msk);
        mi = M(msk);

        [li, ord] = sort(li, 'ascend');
        mi = mi(ord);

        nPointsPerT(i) = numel(li);
        if numel(li) < 3
            continue;
        end

        dM = gradient(mi, li);
        R_relax_calc = -dM;
        dR = gradient(R_relax_calc, li);
        d2M = gradient(dM, li);

        ampR = max(abs(R_relax_calc), [], 'omitnan');
        if isfinite(ampR) && ampR > 0
            RnormCell{i} = R_relax_calc ./ ampR;
        else
            RnormCell{i} = zeros(size(R_relax_calc));
        end

        pairProd = R_relax_calc(1:end-1) .* R_relax_calc(2:end);
        rSignChange(i) = double(any(pairProd < 0));

        dRthr = 0.05 * max(abs(dR), [], 'omitnan');
        if ~isfinite(dRthr)
            dRthr = 0;
        end
        dRsgn = sign(dR);
        dRsgn(~isfinite(dRsgn)) = 0;
        dRsgn(abs(dR) <= dRthr) = 0;
        dRsgn = dRsgn(dRsgn ~= 0);
        if numel(dRsgn) >= 2
            dRNonMonotonic(i) = double(any(diff(dRsgn) ~= 0));
        else
            dRNonMonotonic(i) = 0;
        end

        shapeFlip(i) = double((rSignChange(i) > 0) || (dRNonMonotonic(i) > 0));

        rPeak = max(R_relax_calc, [], 'omitnan');
        wNow = NaN;
        if isfinite(rPeak) && rPeak > 0
            mh = R_relax_calc >= (0.5 * rPeak);
            if any(mh)
                wNow = max(li(mh), [], 'omitnan') - min(li(mh), [], 'omitnan');
            end
        end

        if ~isfinite(wNow) || wNow <= 0
            wp = max(R_relax_calc, 0);
            sw = sum(wp, 'omitnan');
            if isfinite(sw) && sw > 0
                [ls, o2] = sort(li, 'ascend');
                ws = wp(o2);
                cdfw = cumsum(ws) ./ max(sum(ws), eps);
                idx25 = find(cdfw >= 0.25, 1, 'first');
                idx75 = find(cdfw >= 0.75, 1, 'first');
                if ~isempty(idx25) && ~isempty(idx75)
                    wNow = ls(idx75) - ls(idx25);
                end
            end
        end

        widthMetric(i) = wNow;
        curvMaxAbs(i) = max(abs(d2M), [], 'omitnan');
    end

    muW = mean(widthMetric, 'omitnan');
    sdW = std(widthMetric, 0, 'omitnan');
    if ~isfinite(sdW) || sdW <= 0
        sdW = eps;
    end
    widthZ = abs((widthMetric - muW) ./ sdW);
    widthOutlier = double(widthZ > 2);
    outlierScore = shapeFlip + widthZ;
    anyOutlier = double((shapeFlip > 0) | (widthOutlier > 0));

    muC = mean(curvMaxAbs, 'omitnan');
    sdC = std(curvMaxAbs, 0, 'omitnan');
    if ~isfinite(sdC) || sdC <= 0
        sdC = eps;
    end
    curvAnom = abs((curvMaxAbs - muC) ./ sdC);

    inTransition = double((Tuniq >= 22) & (Tuniq <= 24));
    inMask = logical(inTransition);
    outMask = ~inMask;
    if any(inMask) && any(outMask)
        meanOutlierInside = mean(outlierScore(inMask), 'omitnan');
        meanOutlierOutside = mean(outlierScore(outMask), 'omitnan');
        if isfinite(meanOutlierOutside) && abs(meanOutlierOutside) > eps
            insideOutsideRatio = meanOutlierInside / meanOutlierOutside;
        end
    end
    if isfinite(insideOutsideRatio) && (insideOutsideRatio > 1.5)
        OUTLIERS_LOCALIZED_AT_TRANSITION = "YES";
    else
        OUTLIERS_LOCALIZED_AT_TRANSITION = "NO";
    end

    alphaTbl = readtable(inAlphaPath, 'VariableNamingRule', 'preserve');
    alphaNames = string(alphaTbl.Properties.VariableNames);
    alphaLow = lower(alphaNames);

    idxAT = find(contains(alphaLow, 't_k') | (alphaLow == "t") | contains(alphaLow, 'temp'), 1, 'first');
    idxK1 = find(contains(alphaLow, 'kappa1'), 1, 'first');
    idxK2 = find(contains(alphaLow, 'kappa2'), 1, 'first');
    missA = strings(0,1);
    if isempty(idxAT), missA(end+1) = "T_K"; end
    if isempty(idxK1), missA(end+1) = "kappa1"; end
    if isempty(idxK2), missA(end+1) = "kappa2"; end
    if ~isempty(missA)
        error('run_relaxation_outlier_audit:MissingAlphaColumns', ...
            'Missing required columns in alpha table: %s', strjoin(missA, ', '));
    end

    TkAlpha = double(alphaTbl{:, idxAT});
    kappa1 = double(alphaTbl{:, idxK1});
    kappa2 = double(alphaTbl{:, idxK2});

    finiteAlpha = isfinite(TkAlpha) & isfinite(kappa1) & isfinite(kappa2);
    TkAlpha = TkAlpha(finiteAlpha);
    kappa1 = kappa1(finiteAlpha);
    kappa2 = kappa2(finiteAlpha);

    nA = numel(TkAlpha);
    mapRelaxIdx = NaN(nA,1);
    mapDelta = NaN(nA,1);
    for i = 1:nA
        dif = abs(Tuniq - TkAlpha(i));
        [dmin, idxMin] = min(dif);
        if ~isempty(idxMin) && isfinite(dmin) && (dmin <= 1)
            mapRelaxIdx(i) = idxMin;
            mapDelta(i) = TkAlpha(i) - Tuniq(idxMin);
        end
    end

    validMap = isfinite(mapRelaxIdx);
    alignmentN = sum(validMap);
    if any(validMap)
        alignmentMeanDeltaT = mean(mapDelta(validMap), 'omitnan');
    end

    alignedAlphaT = NaN(N_T,1);
    alignedKappa1 = NaN(N_T,1);
    alignedKappa2 = NaN(N_T,1);
    for i = 1:nA
        if isfinite(mapRelaxIdx(i))
            ir = mapRelaxIdx(i);
            if ~isfinite(alignedAlphaT(ir))
                alignedAlphaT(ir) = TkAlpha(i);
                alignedKappa1(ir) = kappa1(i);
                alignedKappa2(ir) = kappa2(i);
            else
                oldDelta = abs(alignedAlphaT(ir) - Tuniq(ir));
                newDelta = abs(TkAlpha(i) - Tuniq(ir));
                if newDelta < oldDelta
                    alignedAlphaT(ir) = TkAlpha(i);
                    alignedKappa1(ir) = kappa1(i);
                    alignedKappa2(ir) = kappa2(i);
                end
            end
        end
    end

    outlierAligned = NaN(0,1);
    shapeAligned = NaN(0,1);
    widthAligned = NaN(0,1);
    curvAligned = NaN(0,1);
    kappa2Aligned = NaN(0,1);
    if any(validMap)
        ridx = mapRelaxIdx(validMap);
        outlierAligned = outlierScore(ridx);
        shapeAligned = shapeFlip(ridx);
        widthAligned = widthZ(ridx);
        curvAligned = curvAnom(ridx);
        kappa2Aligned = kappa2(validMap);
    end

    m = isfinite(outlierAligned) & isfinite(kappa2Aligned);
    if sum(m) >= 3
        pearsonOutlierKappa2 = corr(outlierAligned(m), kappa2Aligned(m), 'type', 'Pearson', 'rows', 'complete');
        spearmanOutlierKappa2 = corr(outlierAligned(m), kappa2Aligned(m), 'type', 'Spearman', 'rows', 'complete');
    end

    m = isfinite(shapeAligned) & isfinite(kappa2Aligned);
    if sum(m) >= 3
        pearsonShapeFlipKappa2 = corr(shapeAligned(m), kappa2Aligned(m), 'type', 'Pearson', 'rows', 'complete');
        spearmanShapeFlipKappa2 = corr(shapeAligned(m), kappa2Aligned(m), 'type', 'Spearman', 'rows', 'complete');
    end

    m = isfinite(widthAligned) & isfinite(kappa2Aligned);
    if sum(m) >= 3
        pearsonWidthZKappa2 = corr(widthAligned(m), kappa2Aligned(m), 'type', 'Pearson', 'rows', 'complete');
        spearmanWidthZKappa2 = corr(widthAligned(m), kappa2Aligned(m), 'type', 'Spearman', 'rows', 'complete');
    end

    m = isfinite(curvAnom) & isfinite(outlierScore);
    if sum(m) >= 3
        pearsonCurvOutlier = corr(curvAnom(m), outlierScore(m), 'type', 'Pearson', 'rows', 'complete');
        spearmanCurvOutlier = corr(curvAnom(m), outlierScore(m), 'type', 'Spearman', 'rows', 'complete');
    end

    m = isfinite(curvAligned) & isfinite(kappa2Aligned);
    if sum(m) >= 3
        pearsonCurvKappa2 = corr(curvAligned(m), kappa2Aligned(m), 'type', 'Pearson', 'rows', 'complete');
        spearmanCurvKappa2 = corr(curvAligned(m), kappa2Aligned(m), 'type', 'Spearman', 'rows', 'complete');
    end

    maxAbsOutlierK2 = max(abs([pearsonOutlierKappa2, spearmanOutlierKappa2]), [], 'omitnan');
    if isfinite(maxAbsOutlierK2) && (maxAbsOutlierK2 > 0.5)
        OUTLIERS_CORRELATED_WITH_KAPPA2 = "YES";
    else
        OUTLIERS_CORRELATED_WITH_KAPPA2 = "NO";
    end

    maxAbsCurvOut = max(abs([pearsonCurvOutlier, spearmanCurvOutlier]), [], 'omitnan');
    if isfinite(maxAbsCurvOut) && (maxAbsCurvOut > 0.5)
        OUTLIERS_HAVE_CURVATURE_SIGNATURE = "YES";
    else
        OUTLIERS_HAVE_CURVATURE_SIGNATURE = "NO";
    end

    outIdx = find(anyOutlier > 0);
    nonIdx = find(anyOutlier == 0);
    simWithinOut = NaN(0,1);
    simWithinNon = NaN(0,1);
    simBetween = NaN(0,1);

    if numel(outIdx) >= 2
        for i = 1:(numel(outIdx)-1)
            for j = (i+1):numel(outIdx)
                v1 = RnormCell{outIdx(i)};
                v2 = RnormCell{outIdx(j)};
                if ~isempty(v1) && ~isempty(v2) && (numel(v1) == numel(v2))
                    fm = isfinite(v1) & isfinite(v2);
                    if sum(fm) >= 3
                        s = dot(v1(fm), v2(fm)) / (norm(v1(fm)) * norm(v2(fm)) + eps);
                        simWithinOut(end+1,1) = s; %#ok<SAGROW>
                    end
                end
            end
        end
    end

    if numel(nonIdx) >= 2
        for i = 1:(numel(nonIdx)-1)
            for j = (i+1):numel(nonIdx)
                v1 = RnormCell{nonIdx(i)};
                v2 = RnormCell{nonIdx(j)};
                if ~isempty(v1) && ~isempty(v2) && (numel(v1) == numel(v2))
                    fm = isfinite(v1) & isfinite(v2);
                    if sum(fm) >= 3
                        s = dot(v1(fm), v2(fm)) / (norm(v1(fm)) * norm(v2(fm)) + eps);
                        simWithinNon(end+1,1) = s; %#ok<SAGROW>
                    end
                end
            end
        end
    end

    if ~isempty(outIdx) && ~isempty(nonIdx)
        for i = 1:numel(outIdx)
            for j = 1:numel(nonIdx)
                v1 = RnormCell{outIdx(i)};
                v2 = RnormCell{nonIdx(j)};
                if ~isempty(v1) && ~isempty(v2) && (numel(v1) == numel(v2))
                    fm = isfinite(v1) & isfinite(v2);
                    if sum(fm) >= 3
                        s = dot(v1(fm), v2(fm)) / (norm(v1(fm)) * norm(v2(fm)) + eps);
                        simBetween(end+1,1) = s; %#ok<SAGROW>
                    end
                end
            end
        end
    end

    meanSimWithinOutlier = mean(simWithinOut, 'omitnan');
    varSimWithinOutlier = var(simWithinOut, 0, 'omitnan');
    meanSimWithinNonOutlier = mean(simWithinNon, 'omitnan');
    varSimWithinNonOutlier = var(simWithinNon, 0, 'omitnan');
    meanSimBetweenGroups = mean(simBetween, 'omitnan');

    if numel(simWithinOut) >= 1 && isfinite(meanSimWithinOutlier) && isfinite(meanSimBetweenGroups)
        condHighIntra = meanSimWithinOutlier >= 0.90;
        condLowInter = meanSimBetweenGroups <= 0.80;
        condLowVar = isfinite(varSimWithinOutlier) && (varSimWithinOutlier <= 0.02);
        if condHighIntra && condLowInter && condLowVar
            OUTLIERS_FORM_CONSISTENT_SHAPE = "YES";
        else
            OUTLIERS_FORM_CONSISTENT_SHAPE = "NO";
        end
    else
        OUTLIERS_FORM_CONSISTENT_SHAPE = "NO";
    end

    if (OUTLIERS_LOCALIZED_AT_TRANSITION == "YES") ...
            && (OUTLIERS_CORRELATED_WITH_KAPPA2 == "YES") ...
            && (OUTLIERS_HAVE_CURVATURE_SIGNATURE == "YES")
        OUTLIERS_ARE_PHYSICAL = "YES";
        OUTLIERS_ARE_ARTIFACT = "NO";
    else
        OUTLIERS_ARE_PHYSICAL = "NO";
        OUTLIERS_ARE_ARTIFACT = "YES";
    end

    MAIN_RESULT_SUMMARY = "ratio_inside_outside=" + string(insideOutsideRatio) ...
        + "; corr_outlier_kappa2(P,S)=(" + string(pearsonOutlierKappa2) + "," + string(spearmanOutlierKappa2) + ")" ...
        + "; corr_curvature_outlier(P,S)=(" + string(pearsonCurvOutlier) + "," + string(spearmanCurvOutlier) + ")" ...
        + "; final_physical=" + OUTLIERS_ARE_PHYSICAL;

    EXECUTION_STATUS = "SUCCESS";

catch ME
    ERROR_MESSAGE = string(getReport(ME, 'extended', 'hyperlinks', 'off'));
    EXECUTION_STATUS = "FAIL";
    if INPUT_FOUND ~= "YES"
        INPUT_FOUND = "NO";
    end
end

auditTbl = table( ...
    double(Tuniq), ...
    double(nPointsPerT), ...
    double(shapeFlip), ...
    double(rSignChange), ...
    double(dRNonMonotonic), ...
    double(widthMetric), ...
    double(widthZ), ...
    double(widthOutlier), ...
    double(outlierScore), ...
    double(curvMaxAbs), ...
    double(curvAnom), ...
    double(anyOutlier), ...
    double(inTransition), ...
    double(alignedAlphaT), ...
    double(alignedKappa1), ...
    double(alignedKappa2), ...
    'VariableNames', { ...
        'T_K', ...
        'N_POINTS', ...
        'SHAPE_FLIP', ...
        'R_SIGN_CHANGE', ...
        'DR_NON_MONOTONIC', ...
        'WIDTH_METRIC_LOGT', ...
        'WIDTH_ZSCORE', ...
        'WIDTH_OUTLIER', ...
        'OUTLIER_SCORE', ...
        'CURVATURE_MAX_ABS', ...
        'CURVATURE_ANOMALY_SCORE', ...
        'ANY_OUTLIER', ...
        'IN_TRANSITION_22_24', ...
        'ALIGNED_ALPHA_T_K', ...
        'ALIGNED_KAPPA1', ...
        'ALIGNED_KAPPA2' ...
    });
writetable(auditTbl, outAuditPath);

statusTbl = table( ...
    string(EXECUTION_STATUS), ...
    string(INPUT_FOUND), ...
    string(ERROR_MESSAGE), ...
    double(N_T), ...
    string(MAIN_RESULT_SUMMARY), ...
    string(PRIOR_FLAGS_HAS_OUTLIERS), ...
    string(alignmentRule), ...
    double(alignmentN), ...
    double(alignmentMeanDeltaT), ...
    double(meanOutlierInside), ...
    double(meanOutlierOutside), ...
    double(insideOutsideRatio), ...
    double(pearsonOutlierKappa2), ...
    double(spearmanOutlierKappa2), ...
    double(pearsonShapeFlipKappa2), ...
    double(spearmanShapeFlipKappa2), ...
    double(pearsonWidthZKappa2), ...
    double(spearmanWidthZKappa2), ...
    double(pearsonCurvOutlier), ...
    double(spearmanCurvOutlier), ...
    double(pearsonCurvKappa2), ...
    double(spearmanCurvKappa2), ...
    double(meanSimWithinOutlier), ...
    double(varSimWithinOutlier), ...
    double(meanSimWithinNonOutlier), ...
    double(varSimWithinNonOutlier), ...
    double(meanSimBetweenGroups), ...
    string(OUTLIERS_LOCALIZED_AT_TRANSITION), ...
    string(OUTLIERS_CORRELATED_WITH_KAPPA2), ...
    string(OUTLIERS_HAVE_CURVATURE_SIGNATURE), ...
    string(OUTLIERS_FORM_CONSISTENT_SHAPE), ...
    string(OUTLIERS_ARE_PHYSICAL), ...
    string(OUTLIERS_ARE_ARTIFACT), ...
    'VariableNames', { ...
        'EXECUTION_STATUS', ...
        'INPUT_FOUND', ...
        'ERROR_MESSAGE', ...
        'N_T', ...
        'MAIN_RESULT_SUMMARY', ...
        'PRIOR_FLAGS_HAS_OUTLIERS', ...
        'ALIGNMENT_RULE', ...
        'ALIGNMENT_N', ...
        'ALIGNMENT_MEAN_DELTA_T', ...
        'OUTLIER_SCORE_MEAN_INSIDE_22_24', ...
        'OUTLIER_SCORE_MEAN_OUTSIDE', ...
        'OUTLIER_SCORE_RATIO_INSIDE_OUTSIDE', ...
        'PEARSON_OUTLIER_KAPPA2', ...
        'SPEARMAN_OUTLIER_KAPPA2', ...
        'PEARSON_SHAPEFLIP_KAPPA2', ...
        'SPEARMAN_SHAPEFLIP_KAPPA2', ...
        'PEARSON_WIDTHZSCORE_KAPPA2', ...
        'SPEARMAN_WIDTHZSCORE_KAPPA2', ...
        'PEARSON_CURVATURE_OUTLIER', ...
        'SPEARMAN_CURVATURE_OUTLIER', ...
        'PEARSON_CURVATURE_KAPPA2', ...
        'SPEARMAN_CURVATURE_KAPPA2', ...
        'MEAN_SIM_WITHIN_OUTLIER', ...
        'VAR_SIM_WITHIN_OUTLIER', ...
        'MEAN_SIM_WITHIN_NONOUTLIER', ...
        'VAR_SIM_WITHIN_NONOUTLIER', ...
        'MEAN_SIM_BETWEEN_GROUPS', ...
        'OUTLIERS_LOCALIZED_AT_TRANSITION', ...
        'OUTLIERS_CORRELATED_WITH_KAPPA2', ...
        'OUTLIERS_HAVE_CURVATURE_SIGNATURE', ...
        'OUTLIERS_FORM_CONSISTENT_SHAPE', ...
        'OUTLIERS_ARE_PHYSICAL', ...
        'OUTLIERS_ARE_ARTIFACT' ...
    });
writetable(statusTbl, outStatusPath);

md(end+1) = "## Execution";
md(end+1) = "- EXECUTION_STATUS: " + EXECUTION_STATUS;
md(end+1) = "- INPUT_FOUND: " + INPUT_FOUND;
md(end+1) = "- N_T: " + string(N_T);
md(end+1) = "- PRIOR_FLAGS_HAS_OUTLIERS: " + PRIOR_FLAGS_HAS_OUTLIERS;
md(end+1) = "- ALIGNMENT_RULE: " + alignmentRule;
md(end+1) = "- ALIGNMENT_N: " + string(alignmentN);
md(end+1) = "- ALIGNMENT_MEAN_DELTA_T: " + string(alignmentMeanDeltaT);
md(end+1) = "";

md(end+1) = "## Step 2 (Localization)";
md(end+1) = "- mean OUTLIER_SCORE inside 22-24 K: " + string(meanOutlierInside);
md(end+1) = "- mean OUTLIER_SCORE outside: " + string(meanOutlierOutside);
md(end+1) = "- ratio inside/outside: " + string(insideOutsideRatio);
md(end+1) = "";

md(end+1) = "## Step 3 (Kappa2 Correlations)";
md(end+1) = "- Pearson corr(OUTLIER_SCORE, kappa2): " + string(pearsonOutlierKappa2);
md(end+1) = "- Spearman corr(OUTLIER_SCORE, kappa2): " + string(spearmanOutlierKappa2);
md(end+1) = "- Pearson corr(SHAPE_FLIP, kappa2): " + string(pearsonShapeFlipKappa2);
md(end+1) = "- Spearman corr(SHAPE_FLIP, kappa2): " + string(spearmanShapeFlipKappa2);
md(end+1) = "- Pearson corr(WIDTH_ZSCORE, kappa2): " + string(pearsonWidthZKappa2);
md(end+1) = "- Spearman corr(WIDTH_ZSCORE, kappa2): " + string(spearmanWidthZKappa2);
md(end+1) = "";

md(end+1) = "## Step 4 (Curvature)";
md(end+1) = "- Pearson corr(curvature anomaly, OUTLIER_SCORE): " + string(pearsonCurvOutlier);
md(end+1) = "- Spearman corr(curvature anomaly, OUTLIER_SCORE): " + string(spearmanCurvOutlier);
md(end+1) = "- Pearson corr(curvature anomaly, kappa2): " + string(pearsonCurvKappa2);
md(end+1) = "- Spearman corr(curvature anomaly, kappa2): " + string(spearmanCurvKappa2);
md(end+1) = "";

md(end+1) = "## Step 5 (Shape Consistency)";
md(end+1) = "- mean cosine similarity within outliers: " + string(meanSimWithinOutlier);
md(end+1) = "- var cosine similarity within outliers: " + string(varSimWithinOutlier);
md(end+1) = "- mean cosine similarity within non-outliers: " + string(meanSimWithinNonOutlier);
md(end+1) = "- var cosine similarity within non-outliers: " + string(varSimWithinNonOutlier);
md(end+1) = "- mean cosine similarity between groups: " + string(meanSimBetweenGroups);
md(end+1) = "";

md(end+1) = "## Final Verdicts";
md(end+1) = "- OUTLIERS_LOCALIZED_AT_TRANSITION: " + OUTLIERS_LOCALIZED_AT_TRANSITION;
md(end+1) = "- OUTLIERS_CORRELATED_WITH_KAPPA2: " + OUTLIERS_CORRELATED_WITH_KAPPA2;
md(end+1) = "- OUTLIERS_HAVE_CURVATURE_SIGNATURE: " + OUTLIERS_HAVE_CURVATURE_SIGNATURE;
md(end+1) = "- OUTLIERS_FORM_CONSISTENT_SHAPE: " + OUTLIERS_FORM_CONSISTENT_SHAPE;
md(end+1) = "- OUTLIERS_ARE_PHYSICAL: " + OUTLIERS_ARE_PHYSICAL;
md(end+1) = "- OUTLIERS_ARE_ARTIFACT: " + OUTLIERS_ARE_ARTIFACT;
md(end+1) = "";
md(end+1) = "## Error Message";
md(end+1) = "```";
md(end+1) = string(ERROR_MESSAGE);
md(end+1) = "```";

fid = fopen(outReportPath, 'w');
if fid >= 0
    md(ismissing(md)) = "";
    for i = 1:numel(md)
        fprintf(fid, '%s\n', md(i));
    end
    fclose(fid);
end

fprintf('[DONE] %s\n', EXECUTION_STATUS);
fprintf('Audit: %s\n', outAuditPath);
fprintf('Status: %s\n', outStatusPath);
fprintf('Report: %s\n', outReportPath);
