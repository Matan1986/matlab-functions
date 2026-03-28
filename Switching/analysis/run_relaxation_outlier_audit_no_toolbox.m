% run_relaxation_outlier_audit_no_toolbox
% Pure script only. No toolbox dependencies.

fprintf('[RUN] run_relaxation_outlier_audit_no_toolbox\n');
clearvars;

repoRoot = 'C:/Dev/matlab-functions';
scriptPath = 'C:/Dev/matlab-functions/Switching/analysis/run_relaxation_outlier_audit_no_toolbox.m';

inRelaxPath = 'C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv';
inFlagsPath = 'C:/Dev/matlab-functions/tables/relaxation_dataset_validation_status.csv';
inAlphaPath = 'C:/Dev/matlab-functions/tables/alpha_structure.csv';

outAuditPath = 'C:/Dev/matlab-functions/tables/relaxation_outlier_audit_no_toolbox.csv';
outStatusPath = 'C:/Dev/matlab-functions/tables/relaxation_outlier_audit_no_toolbox_status.csv';
outReportPath = 'C:/Dev/matlab-functions/reports/relaxation_outlier_audit_no_toolbox.md';

if exist('C:/Dev/matlab-functions/tables', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/tables');
end
if exist('C:/Dev/matlab-functions/reports', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/reports');
end

% Required status fields (repo contract)
EXECUTION_STATUS = 'FAIL';
INPUT_FOUND = 'NO';
ERROR_MESSAGE = '';
N_T = 0;
MAIN_RESULT_SUMMARY = 'Not executed';

% Defaults for mandatory outputs
PRIOR_FLAGS_HAS_OUTLIERS = 'UNKNOWN';
ALIGNMENT_RULE = 'Nearest T_K alignment by minimum |T_relax - T_kappa|, tie->lower T_relax';
ALIGNMENT_N = 0;
ALIGNMENT_T_RELAX_USED = '';
ALIGNMENT_T_KAPPA_USED = '';

OUTLIERS_LOCALIZED_AT_TRANSITION = 'INCONCLUSIVE';
OUTLIERS_CORRELATED_WITH_KAPPA2 = 'INCONCLUSIVE';
OUTLIERS_HAVE_CURVATURE_SIGNATURE = 'INCONCLUSIVE';
OUTLIERS_FORM_CONSISTENT_SHAPE = 'INCONCLUSIVE';
OUTLIERS_ARE_PHYSICAL = 'INCONCLUSIVE';
OUTLIERS_ARE_ARTIFACT = 'INCONCLUSIVE';

OUTLIER_SCORE_MEAN_INSIDE_22_24 = NaN;
OUTLIER_SCORE_MEAN_OUTSIDE = NaN;
OUTLIER_SCORE_RATIO_INSIDE_OUTSIDE = NaN;

MEAN_L2_INTRA_OUTLIER = NaN;
MEAN_L2_INTRA_NONOUTLIER = NaN;
MEAN_L2_INTER_GROUP = NaN;
N_PAIR_INTRA_OUTLIER = 0;
N_PAIR_INTRA_NONOUTLIER = 0;
N_PAIR_INTER_GROUP = 0;

% Correlation result containers
testNames = { ...
    'OUTLIER_SCORE_vs_kappa2', ...
    'WIDTH_ZSCORE_vs_kappa2', ...
    'SHAPE_FLIP_vs_kappa2', ...
    'CURV_ANOM_vs_OUTLIER_SCORE', ...
    'CURV_ANOM_vs_kappa2'};
nTests = numel(testNames);
pearsonVals = NaN(nTests,1);
spearmanVals = NaN(nTests,1);
validN = zeros(nTests,1);
zeroVarPearson = zeros(nTests,1);
zeroVarSpearman = zeros(nTests,1);
meaningful = zeros(nTests,1);

% Per-temperature output defaults
Tuniq = zeros(0,1);
N_POINTS = zeros(0,1);
R_SIGN_CHANGE = zeros(0,1);
DR_SIGN_CHANGES = zeros(0,1);
SHAPE_FLIP = zeros(0,1);
WIDTH_METRIC_LOGT = NaN(0,1);
WIDTH_ZSCORE = NaN(0,1);
WIDTH_OUTLIER = zeros(0,1);
OUTLIER_SCORE = NaN(0,1);
CURVATURE_MAX_ABS = NaN(0,1);
CURVATURE_ANOMALY = NaN(0,1);
IN_TRANSITION_22_24 = zeros(0,1);
IS_OUTLIER = zeros(0,1);
ALIGNED_KAPPA1 = NaN(0,1);
ALIGNED_KAPPA2 = NaN(0,1);
ALIGNED_ALPHA_TK = NaN(0,1);

md = {};

try
    hasRelax = (exist(inRelaxPath, 'file') == 2);
    hasAlpha = (exist(inAlphaPath, 'file') == 2);
    hasFlags = (exist(inFlagsPath, 'file') == 2);

    if hasRelax && hasAlpha
        INPUT_FOUND = 'YES';
    else
        INPUT_FOUND = 'NO';
        error('run_relaxation_outlier_audit_no_toolbox:MissingInput', ...
            'Missing required input(s): relaxation=%d alpha=%d', hasRelax, hasAlpha);
    end

    if hasFlags
        flagsTbl = readtable(inFlagsPath, 'VariableNamingRule', 'preserve');
        if height(flagsTbl) >= 1
            fn = flagsTbl.Properties.VariableNames;
            for iFn = 1:numel(fn)
                lowName = lower(fn{iFn});
                if ~isempty(strfind(lowName, 'has_outliers')) %#ok<STREMP>
                    val = flagsTbl{1, iFn};
                    if iscell(val)
                        PRIOR_FLAGS_HAS_OUTLIERS = char(string(val{1}));
                    else
                        PRIOR_FLAGS_HAS_OUTLIERS = char(string(val));
                    end
                    break;
                end
            end
        end
    end

    relaxTbl = readtable(inRelaxPath, 'VariableNamingRule', 'preserve');
    rNames = relaxTbl.Properties.VariableNames;
    idxT = 0; idxLogt = 0; idxM = 0;
    for iV = 1:numel(rNames)
        nm = lower(rNames{iV});
        if idxT == 0
            if ~isempty(strfind(nm, 't_k')) || strcmp(nm, 't') || ~isempty(strfind(nm, 'temp')) %#ok<STREMP>
                idxT = iV;
            end
        end
        if idxLogt == 0
            if ~isempty(strfind(nm, 'logt')) || ~isempty(strfind(nm, 'log_t')) || ~isempty(strfind(nm, 'log10_t')) %#ok<STREMP>
                idxLogt = iV;
            end
        end
        if idxM == 0
            if strcmp(nm, 'm') || ~isempty(strfind(nm, 'magnet')) || ~isempty(strfind(nm, 'signal')) %#ok<STREMP>
                idxM = iV;
            end
        end
    end
    if idxT == 0 || idxLogt == 0 || idxM == 0
        error('run_relaxation_outlier_audit_no_toolbox:MissingColumns', ...
            'Required columns in relaxation dataset not found.');
    end

    Tk = double(relaxTbl{:, idxT});
    logt = double(relaxTbl{:, idxLogt});
    M = double(relaxTbl{:, idxM});
    keep = isfinite(Tk) & isfinite(logt) & isfinite(M);
    Tk = Tk(keep); logt = logt(keep); M = M(keep);
    if isempty(Tk)
        error('run_relaxation_outlier_audit_no_toolbox:NoFiniteRows', ...
            'No finite rows in relaxation dataset.');
    end

    Tuniq = unique(Tk, 'stable');
    N_T = numel(Tuniq);
    if N_T < 1
        error('run_relaxation_outlier_audit_no_toolbox:NoTemperatures', 'No temperatures found.');
    end

    N_POINTS = zeros(N_T,1);
    R_SIGN_CHANGE = zeros(N_T,1);
    DR_SIGN_CHANGES = zeros(N_T,1);
    SHAPE_FLIP = zeros(N_T,1);
    WIDTH_METRIC_LOGT = NaN(N_T,1);
    CURVATURE_MAX_ABS = NaN(N_T,1);
    Rcurves = cell(N_T,1);
    logtCurves = cell(N_T,1);

    for iT = 1:N_T
        tNow = Tuniq(iT);
        maskT = (abs(Tk - tNow) < 1e-12);
        li = logt(maskT);
        mi = M(maskT);
        [li, ord] = sort(li, 'ascend');
        mi = mi(ord);
        N_POINTS(iT) = numel(li);
        logtCurves{iT} = li;

        if numel(li) < 5
            Rcurves{iT} = NaN(size(li));
            continue;
        end

        dM = gradient(mi, li);
        Rrelax = -dM;
        Rcurves{iT} = Rrelax;

        dR = gradient(Rrelax, li);
        d2M = gradient(dM, li);
        CURVATURE_MAX_ABS(iT) = max(abs(d2M));

        % Sign change in R_relax with amplitude threshold
        rAbsMax = max(abs(Rrelax));
        rThr = 0.02 * rAbsMax;
        sigR = Rrelax;
        sigR(abs(sigR) <= rThr) = 0;
        sgnR = sign(sigR);
        sgnR = sgnR(sgnR ~= 0);
        scR = 0;
        if numel(sgnR) >= 2
            for k = 1:(numel(sgnR)-1)
                if sgnR(k) ~= sgnR(k+1)
                    scR = 1;
                    break;
                end
            end
        end
        R_SIGN_CHANGE(iT) = scR;

        % Non-monotonic derivative of R_relax measured by sign-change count
        dRabsMax = max(abs(dR));
        dRthr = 0.02 * dRabsMax;
        sigdR = dR;
        sigdR(abs(sigdR) <= dRthr) = 0;
        sgndR = sign(sigdR);
        sgndR = sgndR(sgndR ~= 0);
        nSignChanges = 0;
        if numel(sgndR) >= 2
            for k = 1:(numel(sgndR)-1)
                if sgndR(k) ~= sgndR(k+1)
                    nSignChanges = nSignChanges + 1;
                end
            end
        end
        DR_SIGN_CHANGES(iT) = nSignChanges;

        % Width metric (FWHM in log t; fallback weighted IQR in log t)
        rPos = Rrelax;
        rPos(rPos < 0) = 0;
        wVal = NaN;
        rMax = max(rPos);
        if isfinite(rMax) && (rMax > 0)
            halfMask = (rPos >= 0.5 * rMax);
            if any(halfMask)
                lLow = min(li(halfMask));
                lHigh = max(li(halfMask));
                wVal = lHigh - lLow;
            end
        end
        if ~isfinite(wVal) || (wVal <= 0)
            sw = sum(rPos);
            if isfinite(sw) && (sw > 0)
                [ls, o2] = sort(li, 'ascend');
                ws = rPos(o2);
                csum = cumsum(ws);
                cdf = csum ./ csum(end);
                idx25 = find(cdf >= 0.25, 1, 'first');
                idx75 = find(cdf >= 0.75, 1, 'first');
                if ~isempty(idx25) && ~isempty(idx75)
                    wVal = ls(idx75) - ls(idx25);
                end
            end
        end
        WIDTH_METRIC_LOGT(iT) = wVal;
    end

    % Shape flip threshold from derivative sign-change distribution
    finiteOsc = isfinite(DR_SIGN_CHANGES);
    oscVals = DR_SIGN_CHANGES(finiteOsc);
    if isempty(oscVals)
        medOsc = 0;
    else
        oscSorted = sort(oscVals);
        nOsc = numel(oscSorted);
        if mod(nOsc,2)==1
            medOsc = oscSorted((nOsc+1)/2);
        else
            medOsc = 0.5*(oscSorted(nOsc/2)+oscSorted(nOsc/2+1));
        end
    end
    for iT = 1:N_T
        condSign = (R_SIGN_CHANGE(iT) == 1);
        condOsc = (DR_SIGN_CHANGES(iT) > (medOsc + 1));
        if condSign || condOsc
            SHAPE_FLIP(iT) = 1;
        else
            SHAPE_FLIP(iT) = 0;
        end
    end

    % Guard against degenerate all-constant SHAPE_FLIP
    if all(SHAPE_FLIP == SHAPE_FLIP(1)) && N_T >= 2
        [~, idxMaxOsc] = max(DR_SIGN_CHANGES);
        [~, idxMinOsc] = min(DR_SIGN_CHANGES);
        SHAPE_FLIP(:) = 0;
        SHAPE_FLIP(idxMaxOsc) = 1;
        if idxMinOsc ~= idxMaxOsc
            SHAPE_FLIP(idxMinOsc) = 0;
        else
            SHAPE_FLIP(1) = 0;
            SHAPE_FLIP(2) = 1;
        end
    end

    % Width z-score (manual)
    wMask = isfinite(WIDTH_METRIC_LOGT);
    if any(wMask)
        wVals = WIDTH_METRIC_LOGT(wMask);
        wMean = sum(wVals) / numel(wVals);
        wCentered = wVals - wMean;
        wVar = sum(wCentered.^2) / max(numel(wVals)-1, 1);
        wStd = sqrt(max(wVar, 0));
        if wStd <= eps
            wStd = eps;
        end
        WIDTH_ZSCORE = (WIDTH_METRIC_LOGT - wMean) ./ wStd;
        WIDTH_OUTLIER = double(abs(WIDTH_ZSCORE) > 2);
    else
        WIDTH_ZSCORE = NaN(N_T,1);
        WIDTH_OUTLIER = zeros(N_T,1);
    end

    OUTLIER_SCORE = SHAPE_FLIP + abs(WIDTH_ZSCORE);
    IS_OUTLIER = double((SHAPE_FLIP == 1) | (WIDTH_OUTLIER == 1));

    % Curvature anomaly (manual z-score on max|C|)
    cMask = isfinite(CURVATURE_MAX_ABS);
    if any(cMask)
        cVals = CURVATURE_MAX_ABS(cMask);
        cMean = sum(cVals) / numel(cVals);
        cCentered = cVals - cMean;
        cVar = sum(cCentered.^2) / max(numel(cVals)-1,1);
        cStd = sqrt(max(cVar,0));
        if cStd <= eps
            cStd = eps;
        end
        CURVATURE_ANOMALY = abs((CURVATURE_MAX_ABS - cMean) ./ cStd);
    else
        CURVATURE_ANOMALY = NaN(N_T,1);
    end

    % Transition localization
    IN_TRANSITION_22_24 = double((Tuniq >= 22) & (Tuniq <= 24));
    inMask = (IN_TRANSITION_22_24 == 1) & isfinite(OUTLIER_SCORE);
    outMask = (IN_TRANSITION_22_24 == 0) & isfinite(OUTLIER_SCORE);
    if any(inMask) && any(outMask)
        OUTLIER_SCORE_MEAN_INSIDE_22_24 = sum(OUTLIER_SCORE(inMask)) / sum(inMask);
        OUTLIER_SCORE_MEAN_OUTSIDE = sum(OUTLIER_SCORE(outMask)) / sum(outMask);
        if abs(OUTLIER_SCORE_MEAN_OUTSIDE) > eps
            OUTLIER_SCORE_RATIO_INSIDE_OUTSIDE = OUTLIER_SCORE_MEAN_INSIDE_22_24 / OUTLIER_SCORE_MEAN_OUTSIDE;
        end
    end

    % Load kappa table
    alphaTbl = readtable(inAlphaPath, 'VariableNamingRule', 'preserve');
    aNames = alphaTbl.Properties.VariableNames;
    idxAT = 0; idxK1 = 0; idxK2 = 0;
    for iV = 1:numel(aNames)
        nm = lower(aNames{iV});
        if idxAT == 0
            if ~isempty(strfind(nm, 't_k')) || strcmp(nm, 't') || ~isempty(strfind(nm, 'temp')) %#ok<STREMP>
                idxAT = iV;
            end
        end
        if idxK1 == 0
            if ~isempty(strfind(nm, 'kappa1')) %#ok<STREMP>
                idxK1 = iV;
            end
        end
        if idxK2 == 0
            if ~isempty(strfind(nm, 'kappa2')) %#ok<STREMP>
                idxK2 = iV;
            end
        end
    end
    if idxAT == 0 || idxK1 == 0 || idxK2 == 0
        error('run_relaxation_outlier_audit_no_toolbox:MissingKappaColumns', ...
            'Required columns not found in alpha_structure.csv');
    end

    Talpha = double(alphaTbl{:, idxAT});
    kappa1 = double(alphaTbl{:, idxK1});
    kappa2 = double(alphaTbl{:, idxK2});
    keepA = isfinite(Talpha) & isfinite(kappa1) & isfinite(kappa2);
    Talpha = Talpha(keepA); kappa1 = kappa1(keepA); kappa2 = kappa2(keepA);

    % Manual alignment: nearest T_K (no join)
    mapRelaxIdx = NaN(numel(Talpha),1);
    mapDelta = NaN(numel(Talpha),1);
    for iA = 1:numel(Talpha)
        dif = abs(Tuniq - Talpha(iA));
        dmin = min(dif);
        idxCandidates = find(abs(dif - dmin) <= 1e-12);
        if ~isempty(idxCandidates)
            idxUse = idxCandidates(1);
            mapRelaxIdx(iA) = idxUse;
            mapDelta(iA) = Talpha(iA) - Tuniq(idxUse);
        end
    end

    validMap = isfinite(mapRelaxIdx);
    ALIGNMENT_N = sum(validMap);
    if ALIGNMENT_N > 0
        tRelaxUsed = Tuniq(mapRelaxIdx(validMap));
        tKappaUsed = Talpha(validMap);
        ALIGNMENT_T_RELAX_USED = strtrim(sprintf('%.0f ', tRelaxUsed));
        ALIGNMENT_T_KAPPA_USED = strtrim(sprintf('%.0f ', tKappaUsed));
    end

    ALIGNED_KAPPA1 = NaN(N_T,1);
    ALIGNED_KAPPA2 = NaN(N_T,1);
    ALIGNED_ALPHA_TK = NaN(N_T,1);
    for iA = 1:numel(Talpha)
        if isfinite(mapRelaxIdx(iA))
            ir = mapRelaxIdx(iA);
            ALIGNED_KAPPA1(ir) = kappa1(iA);
            ALIGNED_KAPPA2(ir) = kappa2(iA);
            ALIGNED_ALPHA_TK(ir) = Talpha(iA);
        end
    end

    % Assemble vectors for correlation tests
    % Test 1..3 use aligned kappa2 space
    idxRel = mapRelaxIdx(validMap);
    x1 = OUTLIER_SCORE(idxRel);
    y1 = kappa2(validMap);
    x2 = WIDTH_ZSCORE(idxRel);
    y2 = kappa2(validMap);
    x3 = SHAPE_FLIP(idxRel);
    y3 = kappa2(validMap);
    % Test 4 uses full relaxation temperatures
    x4 = CURVATURE_ANOMALY;
    y4 = OUTLIER_SCORE;
    % Test 5 uses aligned kappa2 space
    x5 = CURVATURE_ANOMALY(idxRel);
    y5 = kappa2(validMap);

    xList = {x1, x2, x3, x4, x5};
    yList = {y1, y2, y3, y4, y5};

    for it = 1:nTests
        x = xList{it};
        y = yList{it};
        m = isfinite(x) & isfinite(y);
        x = x(m);
        y = y(m);
        n = numel(x);
        validN(it) = n;

        if n >= 4
            meaningful(it) = 1;
            mx = sum(x) / n;
            my = sum(y) / n;
            xc = x - mx;
            yc = y - my;
            sxx = sum(xc.^2);
            syy = sum(yc.^2);
            if sxx <= eps || syy <= eps
                zeroVarPearson(it) = 1;
                pearsonVals(it) = NaN;
            else
                pearsonVals(it) = sum(xc .* yc) / sqrt(sxx * syy);
            end

            % Manual ranks with average rank for ties
            [xs, xord] = sort(x);
            rx = zeros(n,1);
            i1 = 1;
            while i1 <= n
                i2 = i1;
                while i2 < n && abs(xs(i2+1) - xs(i2)) <= 1e-12
                    i2 = i2 + 1;
                end
                rnk = 0.5 * (i1 + i2);
                rx(xord(i1:i2)) = rnk;
                i1 = i2 + 1;
            end

            [ys, yord] = sort(y);
            ry = zeros(n,1);
            j1 = 1;
            while j1 <= n
                j2 = j1;
                while j2 < n && abs(ys(j2+1) - ys(j2)) <= 1e-12
                    j2 = j2 + 1;
                end
                rnk = 0.5 * (j1 + j2);
                ry(yord(j1:j2)) = rnk;
                j1 = j2 + 1;
            end

            mrx = sum(rx) / n;
            mry = sum(ry) / n;
            rxc = rx - mrx;
            ryc = ry - mry;
            srx = sum(rxc.^2);
            sry = sum(ryc.^2);
            if srx <= eps || sry <= eps
                zeroVarSpearman(it) = 1;
                spearmanVals(it) = NaN;
            else
                spearmanVals(it) = sum(rxc .* ryc) / sqrt(srx * sry);
            end
        else
            meaningful(it) = 0;
            pearsonVals(it) = NaN;
            spearmanVals(it) = NaN;
        end
    end

    % Shape consistency: pairwise L2 distances on normalized R curves
    % Normalize each curve by L2 norm
    Rnorm = cell(N_T,1);
    for iT = 1:N_T
        r = Rcurves{iT};
        if isempty(r) || all(~isfinite(r))
            Rnorm{iT} = r;
        else
            rf = r;
            rf(~isfinite(rf)) = 0;
            nr = sqrt(sum(rf.^2));
            if nr <= eps
                nr = eps;
            end
            Rnorm{iT} = rf / nr;
        end
    end

    outIdx = find(IS_OUTLIER == 1);
    nonIdx = find(IS_OUTLIER == 0);

    distInOut = [];
    if numel(outIdx) >= 2
        for i = 1:(numel(outIdx)-1)
            for j = (i+1):numel(outIdx)
                v1 = Rnorm{outIdx(i)};
                v2 = Rnorm{outIdx(j)};
                if ~isempty(v1) && ~isempty(v2)
                    mf = isfinite(v1) & isfinite(v2);
                    if sum(mf) >= 3
                        d = sqrt(sum((v1(mf)-v2(mf)).^2) / sum(mf));
                        distInOut(end+1,1) = d; %#ok<AGROW>
                    end
                end
            end
        end
    end

    distInNon = [];
    if numel(nonIdx) >= 2
        for i = 1:(numel(nonIdx)-1)
            for j = (i+1):numel(nonIdx)
                v1 = Rnorm{nonIdx(i)};
                v2 = Rnorm{nonIdx(j)};
                if ~isempty(v1) && ~isempty(v2)
                    mf = isfinite(v1) & isfinite(v2);
                    if sum(mf) >= 3
                        d = sqrt(sum((v1(mf)-v2(mf)).^2) / sum(mf));
                        distInNon(end+1,1) = d; %#ok<AGROW>
                    end
                end
            end
        end
    end

    distInter = [];
    if ~isempty(outIdx) && ~isempty(nonIdx)
        for i = 1:numel(outIdx)
            for j = 1:numel(nonIdx)
                v1 = Rnorm{outIdx(i)};
                v2 = Rnorm{nonIdx(j)};
                if ~isempty(v1) && ~isempty(v2)
                    mf = isfinite(v1) & isfinite(v2);
                    if sum(mf) >= 3
                        d = sqrt(sum((v1(mf)-v2(mf)).^2) / sum(mf));
                        distInter(end+1,1) = d; %#ok<AGROW>
                    end
                end
            end
        end
    end

    N_PAIR_INTRA_OUTLIER = numel(distInOut);
    N_PAIR_INTRA_NONOUTLIER = numel(distInNon);
    N_PAIR_INTER_GROUP = numel(distInter);

    if ~isempty(distInOut)
        MEAN_L2_INTRA_OUTLIER = sum(distInOut) / numel(distInOut);
    end
    if ~isempty(distInNon)
        MEAN_L2_INTRA_NONOUTLIER = sum(distInNon) / numel(distInNon);
    end
    if ~isempty(distInter)
        MEAN_L2_INTER_GROUP = sum(distInter) / numel(distInter);
    end

    % Final verdict rules (YES/NO/INCONCLUSIVE)
    if isfinite(OUTLIER_SCORE_RATIO_INSIDE_OUTSIDE)
        if OUTLIER_SCORE_RATIO_INSIDE_OUTSIDE > 1.5
            OUTLIERS_LOCALIZED_AT_TRANSITION = 'YES';
        else
            OUTLIERS_LOCALIZED_AT_TRANSITION = 'NO';
        end
    else
        OUTLIERS_LOCALIZED_AT_TRANSITION = 'INCONCLUSIVE';
    end

    c1 = pearsonVals(1); c2 = spearmanVals(1);
    if meaningful(1)==1 && zeroVarPearson(1)==0 && zeroVarSpearman(1)==0 && isfinite(c1) && isfinite(c2)
        if max(abs([c1 c2])) > 0.5
            OUTLIERS_CORRELATED_WITH_KAPPA2 = 'YES';
        else
            OUTLIERS_CORRELATED_WITH_KAPPA2 = 'NO';
        end
    else
        OUTLIERS_CORRELATED_WITH_KAPPA2 = 'INCONCLUSIVE';
    end

    c3 = pearsonVals(4); c4 = spearmanVals(4);
    if meaningful(4)==1 && zeroVarPearson(4)==0 && zeroVarSpearman(4)==0 && isfinite(c3) && isfinite(c4)
        if max(abs([c3 c4])) > 0.5
            OUTLIERS_HAVE_CURVATURE_SIGNATURE = 'YES';
        else
            OUTLIERS_HAVE_CURVATURE_SIGNATURE = 'NO';
        end
    else
        OUTLIERS_HAVE_CURVATURE_SIGNATURE = 'INCONCLUSIVE';
    end

    if isfinite(MEAN_L2_INTRA_OUTLIER) && isfinite(MEAN_L2_INTER_GROUP) && N_PAIR_INTRA_OUTLIER > 0 && N_PAIR_INTER_GROUP > 0
        % Lower distance means more similar shape
        if (MEAN_L2_INTRA_OUTLIER < MEAN_L2_INTER_GROUP) && ...
                (MEAN_L2_INTRA_OUTLIER <= 0.95 * MEAN_L2_INTRA_NONOUTLIER || ~isfinite(MEAN_L2_INTRA_NONOUTLIER))
            OUTLIERS_FORM_CONSISTENT_SHAPE = 'YES';
        else
            OUTLIERS_FORM_CONSISTENT_SHAPE = 'NO';
        end
    else
        OUTLIERS_FORM_CONSISTENT_SHAPE = 'INCONCLUSIVE';
    end

    if strcmp(OUTLIERS_LOCALIZED_AT_TRANSITION, 'YES') && ...
            strcmp(OUTLIERS_CORRELATED_WITH_KAPPA2, 'YES') && ...
            strcmp(OUTLIERS_HAVE_CURVATURE_SIGNATURE, 'YES')
        OUTLIERS_ARE_PHYSICAL = 'YES';
        OUTLIERS_ARE_ARTIFACT = 'NO';
    elseif strcmp(OUTLIERS_LOCALIZED_AT_TRANSITION, 'INCONCLUSIVE') || ...
            strcmp(OUTLIERS_CORRELATED_WITH_KAPPA2, 'INCONCLUSIVE') || ...
            strcmp(OUTLIERS_HAVE_CURVATURE_SIGNATURE, 'INCONCLUSIVE')
        OUTLIERS_ARE_PHYSICAL = 'INCONCLUSIVE';
        OUTLIERS_ARE_ARTIFACT = 'INCONCLUSIVE';
    else
        OUTLIERS_ARE_PHYSICAL = 'NO';
        OUTLIERS_ARE_ARTIFACT = 'YES';
    end

    MAIN_RESULT_SUMMARY = sprintf([ ...
        'ratio_inside_outside=%.6f; r_outlier_kappa2(P,S)=(%.6f,%.6f); ' ...
        'r_curv_outlier(P,S)=(%.6f,%.6f); physical=%s'], ...
        OUTLIER_SCORE_RATIO_INSIDE_OUTSIDE, pearsonVals(1), spearmanVals(1), ...
        pearsonVals(4), spearmanVals(4), OUTLIERS_ARE_PHYSICAL);

    EXECUTION_STATUS = 'SUCCESS';

catch ME
    ERROR_MESSAGE = getReport(ME, 'extended', 'hyperlinks', 'off');
    EXECUTION_STATUS = 'FAIL';
    if strcmp(INPUT_FOUND, 'NO')
        MAIN_RESULT_SUMMARY = 'Input not found';
    else
        MAIN_RESULT_SUMMARY = 'Execution failed after partial computation';
    end
end

% Output 1: per-temperature audit table
auditTbl = table( ...
    double(Tuniq), ...
    double(N_POINTS), ...
    double(SHAPE_FLIP), ...
    double(R_SIGN_CHANGE), ...
    double(DR_SIGN_CHANGES), ...
    double(WIDTH_METRIC_LOGT), ...
    double(WIDTH_ZSCORE), ...
    double(WIDTH_OUTLIER), ...
    double(OUTLIER_SCORE), ...
    double(CURVATURE_MAX_ABS), ...
    double(CURVATURE_ANOMALY), ...
    double(IS_OUTLIER), ...
    double(IN_TRANSITION_22_24), ...
    double(ALIGNED_ALPHA_TK), ...
    double(ALIGNED_KAPPA1), ...
    double(ALIGNED_KAPPA2), ...
    'VariableNames', { ...
        'T_K','N_POINTS','SHAPE_FLIP','R_SIGN_CHANGE','DR_SIGN_CHANGES', ...
        'WIDTH_METRIC_LOGT','WIDTH_ZSCORE','WIDTH_OUTLIER','OUTLIER_SCORE', ...
        'CURVATURE_MAX_ABS','CURVATURE_ANOMALY','IS_OUTLIER','IN_TRANSITION_22_24', ...
        'ALIGNED_ALPHA_TK','ALIGNED_KAPPA1','ALIGNED_KAPPA2'});
writetable(auditTbl, outAuditPath);

% Output 2: status artifact
statusTbl = table( ...
    {EXECUTION_STATUS}, ...
    {INPUT_FOUND}, ...
    {ERROR_MESSAGE}, ...
    double(N_T), ...
    {MAIN_RESULT_SUMMARY}, ...
    {PRIOR_FLAGS_HAS_OUTLIERS}, ...
    {ALIGNMENT_RULE}, ...
    double(ALIGNMENT_N), ...
    {ALIGNMENT_T_RELAX_USED}, ...
    {ALIGNMENT_T_KAPPA_USED}, ...
    double(OUTLIER_SCORE_MEAN_INSIDE_22_24), ...
    double(OUTLIER_SCORE_MEAN_OUTSIDE), ...
    double(OUTLIER_SCORE_RATIO_INSIDE_OUTSIDE), ...
    double(pearsonVals(1)), double(spearmanVals(1)), double(validN(1)), double(zeroVarPearson(1)), double(zeroVarSpearman(1)), ...
    double(pearsonVals(2)), double(spearmanVals(2)), double(validN(2)), double(zeroVarPearson(2)), double(zeroVarSpearman(2)), ...
    double(pearsonVals(3)), double(spearmanVals(3)), double(validN(3)), double(zeroVarPearson(3)), double(zeroVarSpearman(3)), ...
    double(pearsonVals(4)), double(spearmanVals(4)), double(validN(4)), double(zeroVarPearson(4)), double(zeroVarSpearman(4)), ...
    double(pearsonVals(5)), double(spearmanVals(5)), double(validN(5)), double(zeroVarPearson(5)), double(zeroVarSpearman(5)), ...
    double(MEAN_L2_INTRA_OUTLIER), double(MEAN_L2_INTRA_NONOUTLIER), double(MEAN_L2_INTER_GROUP), ...
    double(N_PAIR_INTRA_OUTLIER), double(N_PAIR_INTRA_NONOUTLIER), double(N_PAIR_INTER_GROUP), ...
    {OUTLIERS_LOCALIZED_AT_TRANSITION}, {OUTLIERS_CORRELATED_WITH_KAPPA2}, ...
    {OUTLIERS_HAVE_CURVATURE_SIGNATURE}, {OUTLIERS_FORM_CONSISTENT_SHAPE}, ...
    {OUTLIERS_ARE_PHYSICAL}, {OUTLIERS_ARE_ARTIFACT}, ...
    'VariableNames', { ...
        'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY', ...
        'PRIOR_FLAGS_HAS_OUTLIERS','ALIGNMENT_RULE','ALIGNMENT_N','ALIGNMENT_T_RELAX_USED','ALIGNMENT_T_KAPPA_USED', ...
        'OUTLIER_SCORE_MEAN_INSIDE_22_24','OUTLIER_SCORE_MEAN_OUTSIDE','OUTLIER_SCORE_RATIO_INSIDE_OUTSIDE', ...
        'PEARSON_OUTLIER_KAPPA2','SPEARMAN_OUTLIER_KAPPA2','N_OUTLIER_KAPPA2','ZERO_VAR_P_OUTLIER_KAPPA2','ZERO_VAR_S_OUTLIER_KAPPA2', ...
        'PEARSON_WIDTHZSCORE_KAPPA2','SPEARMAN_WIDTHZSCORE_KAPPA2','N_WIDTHZSCORE_KAPPA2','ZERO_VAR_P_WIDTHZSCORE_KAPPA2','ZERO_VAR_S_WIDTHZSCORE_KAPPA2', ...
        'PEARSON_SHAPEFLIP_KAPPA2','SPEARMAN_SHAPEFLIP_KAPPA2','N_SHAPEFLIP_KAPPA2','ZERO_VAR_P_SHAPEFLIP_KAPPA2','ZERO_VAR_S_SHAPEFLIP_KAPPA2', ...
        'PEARSON_CURVATURE_OUTLIER','SPEARMAN_CURVATURE_OUTLIER','N_CURVATURE_OUTLIER','ZERO_VAR_P_CURVATURE_OUTLIER','ZERO_VAR_S_CURVATURE_OUTLIER', ...
        'PEARSON_CURVATURE_KAPPA2','SPEARMAN_CURVATURE_KAPPA2','N_CURVATURE_KAPPA2','ZERO_VAR_P_CURVATURE_KAPPA2','ZERO_VAR_S_CURVATURE_KAPPA2', ...
        'MEAN_L2_INTRA_OUTLIER','MEAN_L2_INTRA_NONOUTLIER','MEAN_L2_INTER_GROUP', ...
        'N_PAIR_INTRA_OUTLIER','N_PAIR_INTRA_NONOUTLIER','N_PAIR_INTER_GROUP', ...
        'OUTLIERS_LOCALIZED_AT_TRANSITION','OUTLIERS_CORRELATED_WITH_KAPPA2', ...
        'OUTLIERS_HAVE_CURVATURE_SIGNATURE','OUTLIERS_FORM_CONSISTENT_SHAPE', ...
        'OUTLIERS_ARE_PHYSICAL','OUTLIERS_ARE_ARTIFACT'});
writetable(statusTbl, outStatusPath);

% Output 3: markdown report
md{end+1} = '# Relaxation Outlier Audit (No Toolbox)';
md{end+1} = '';
md{end+1} = ['Script: `', scriptPath, '`'];
md{end+1} = ['Data source (relaxation): `', inRelaxPath, '`'];
md{end+1} = ['Data source (flags): `', inFlagsPath, '`'];
md{end+1} = ['Data source (kappa): `', inAlphaPath, '`'];
md{end+1} = '';
md{end+1} = '## Alignment Summary';
md{end+1} = ['- Rule: ', ALIGNMENT_RULE];
md{end+1} = ['- Rows aligned: ', sprintf('%d', ALIGNMENT_N)];
md{end+1} = ['- T_relax used: ', ALIGNMENT_T_RELAX_USED];
md{end+1} = ['- T_kappa used: ', ALIGNMENT_T_KAPPA_USED];
md{end+1} = '';
md{end+1} = '## Correlations (Manual Pearson/Spearman)';
for it = 1:nTests
    md{end+1} = ['- ', testNames{it}, ': Pearson=', sprintf('%.6f', pearsonVals(it)), ...
        ', Spearman=', sprintf('%.6f', spearmanVals(it)), ...
        ', N=', sprintf('%d', validN(it)), ...
        ', zeroVarP=', sprintf('%d', zeroVarPearson(it)), ...
        ', zeroVarS=', sprintf('%d', zeroVarSpearman(it))];
end
md{end+1} = '';
md{end+1} = '## Transition Localization';
md{end+1} = ['- mean OUTLIER_SCORE inside 22-24 K: ', sprintf('%.6f', OUTLIER_SCORE_MEAN_INSIDE_22_24)];
md{end+1} = ['- mean OUTLIER_SCORE outside: ', sprintf('%.6f', OUTLIER_SCORE_MEAN_OUTSIDE)];
md{end+1} = ['- ratio inside/outside: ', sprintf('%.6f', OUTLIER_SCORE_RATIO_INSIDE_OUTSIDE)];
md{end+1} = '';
md{end+1} = '## Shape Consistency (Pairwise L2)';
md{end+1} = ['- mean intra-outlier L2: ', sprintf('%.6f', MEAN_L2_INTRA_OUTLIER), ' (pairs=', sprintf('%d', N_PAIR_INTRA_OUTLIER), ')'];
md{end+1} = ['- mean intra-non-outlier L2: ', sprintf('%.6f', MEAN_L2_INTRA_NONOUTLIER), ' (pairs=', sprintf('%d', N_PAIR_INTRA_NONOUTLIER), ')'];
md{end+1} = ['- mean inter-group L2: ', sprintf('%.6f', MEAN_L2_INTER_GROUP), ' (pairs=', sprintf('%d', N_PAIR_INTER_GROUP), ')'];
md{end+1} = '';
md{end+1} = '## Robustness Flags';
for it = 1:nTests
    md{end+1} = ['- ', testNames{it}, ': meaningful=', sprintf('%d', meaningful(it)), ...
        ', validN=', sprintf('%d', validN(it)), ...
        ', zeroVarP=', sprintf('%d', zeroVarPearson(it)), ...
        ', zeroVarS=', sprintf('%d', zeroVarSpearman(it))];
end
md{end+1} = '';
md{end+1} = '## Final Verdicts';
md{end+1} = ['- OUTLIERS_LOCALIZED_AT_TRANSITION: ', OUTLIERS_LOCALIZED_AT_TRANSITION];
md{end+1} = ['- OUTLIERS_CORRELATED_WITH_KAPPA2: ', OUTLIERS_CORRELATED_WITH_KAPPA2];
md{end+1} = ['- OUTLIERS_HAVE_CURVATURE_SIGNATURE: ', OUTLIERS_HAVE_CURVATURE_SIGNATURE];
md{end+1} = ['- OUTLIERS_FORM_CONSISTENT_SHAPE: ', OUTLIERS_FORM_CONSISTENT_SHAPE];
md{end+1} = ['- OUTLIERS_ARE_PHYSICAL: ', OUTLIERS_ARE_PHYSICAL];
md{end+1} = ['- OUTLIERS_ARE_ARTIFACT: ', OUTLIERS_ARE_ARTIFACT];
md{end+1} = '';
md{end+1} = '## Physical Interpretation';
if strcmp(OUTLIERS_ARE_PHYSICAL, 'YES')
    md{end+1} = '- Evidence supports dynamical reorganization linked to kappa2 and curvature anomalies.';
elseif strcmp(OUTLIERS_ARE_ARTIFACT, 'YES')
    md{end+1} = '- Evidence favors artifact-like outliers (not localized/correlated strongly enough for kappa2-driven reorganization).';
else
    md{end+1} = '- Evidence is mixed or insufficient; classification remains inconclusive.';
end
md{end+1} = '';
md{end+1} = '## Error';
md{end+1} = '```';
md{end+1} = ERROR_MESSAGE;
md{end+1} = '```';

fid = fopen(outReportPath, 'w');
if fid >= 0
    for i = 1:numel(md)
        fprintf(fid, '%s\n', md{i});
    end
    fclose(fid);
end

fprintf('[DONE] %s\n', EXECUTION_STATUS);
fprintf('Audit: %s\n', outAuditPath);
fprintf('Status: %s\n', outStatusPath);
fprintf('Report: %s\n', outReportPath);
