% run_validate_relaxation_dataset
% Pure script only. Validation-only read of relaxation_full_dataset.csv.

fprintf('[RUN] run_validate_relaxation_dataset\n');
clearvars;

repoRoot = 'C:/Dev/matlab-functions';
scriptPath = 'C:/Dev/matlab-functions/Switching/analysis/run_validate_relaxation_dataset.m';
inCsvPath = 'C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv';
outReportPath = 'C:/Dev/matlab-functions/reports/relaxation_dataset_validation.md';
outStatusPath = 'C:/Dev/matlab-functions/tables/relaxation_dataset_validation_status.csv';

if exist('C:/Dev/matlab-functions/tables', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/tables');
end
if exist('C:/Dev/matlab-functions/reports', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/reports');
end

EXECUTION_STATUS = "FAIL";
N_TEMPERATURES = 0;
POINTS_PER_T = "0";
GRID_CONSISTENT = "NO";
HAS_NAN = "YES";
HAS_OUTLIERS = "NO";
DERIVATIVE_STABLE = "NO";
CURVATURE_STABLE = "NO";
DATA_VALID_FOR_ANALYSIS = "NO";
ERROR_MESSAGE = "";
yn = ["NO","YES"];

nRowsTotal = 0;
nColsTotal = 0;
maxGridDeviation = NaN;
allStrictIncreasing = false;
normalizationConsistent = false;
nOscillatoryM = 0;
nDiscontinuousM = 0;
nFlippedShape = 0;
nPeakOutlier = 0;
nWidthOutlier = 0;
medianRPositiveFraction = NaN;
maxRSpikeRatio = NaN;
maxCSpikeRatio = NaN;
maxCtoRScale = NaN;
R_abs_max = NaN;
R_abs_median = NaN;
R_abs_std = NaN;
C_abs_max = NaN;
C_abs_median = NaN;
C_abs_std = NaN;

md = strings(0, 1);
md(end+1) = "# Relaxation Dataset Validation";
md(end+1) = "";
md(end+1) = "Script: `" + string(scriptPath) + "`";
md(end+1) = "Input: `" + string(inCsvPath) + "`";
md(end+1) = "";

try
    if exist(inCsvPath, 'file') ~= 2
        error('run_validate_relaxation_dataset:MissingInput', 'Input file not found: %s', inCsvPath);
    end

    Ttbl = readtable(inCsvPath, 'VariableNamingRule', 'preserve');
    nRowsTotal = height(Ttbl);
    nColsTotal = width(Ttbl);

    if nRowsTotal < 1
        error('run_validate_relaxation_dataset:EmptyTable', 'Input table is empty.');
    end

    vNames = string(Ttbl.Properties.VariableNames);
    vLow = lower(vNames);

    idxT = find(contains(vLow, 't_k') | (vLow == "t") | contains(vLow, 'temp'), 1, 'first');
    idxLogt = find(contains(vLow, 'logt') | contains(vLow, 'log_t') | contains(vLow, 'log10_t') | (contains(vLow, 'log10') & contains(vLow, 't')), 1, 'first');
    idxM = find((vLow == "m") | contains(vLow, 'magnet') | contains(vLow, 'signal'), 1, 'first');
    idxR = find(contains(vLow, 'r_relax') | (contains(vLow, 'r') & contains(vLow, 'relax')), 1, 'first');
    idxC = find((vLow == "c") | contains(vLow, 'curv'), 1, 'first');

    missingCols = strings(0, 1);
    if isempty(idxT), missingCols(end+1) = "T_K"; end
    if isempty(idxLogt), missingCols(end+1) = "logt"; end
    if isempty(idxM), missingCols(end+1) = "M"; end
    if isempty(idxR), missingCols(end+1) = "R_relax"; end
    if isempty(idxC), missingCols(end+1) = "C"; end
    if ~isempty(missingCols)
        error('run_validate_relaxation_dataset:MissingColumns', ...
            'Required columns not found (contains-based): %s', strjoin(missingCols, ', '));
    end

    Tk = double(Ttbl{:, idxT});
    logt = double(Ttbl{:, idxLogt});
    M = double(Ttbl{:, idxM});
    Rrelax = double(Ttbl{:, idxR});
    Ccurv = double(Ttbl{:, idxC});

    finiteMaskAll = isfinite(Tk) & isfinite(logt) & isfinite(M) & isfinite(Rrelax) & isfinite(Ccurv);
    HAS_NAN = string(yn(1 + double(~all(finiteMaskAll))));

    if ~all(finiteMaskAll)
        TkV = Tk(finiteMaskAll);
        logtV = logt(finiteMaskAll);
        MV = M(finiteMaskAll);
        RV = Rrelax(finiteMaskAll);
        CV = Ccurv(finiteMaskAll);
    else
        TkV = Tk;
        logtV = logt;
        MV = M;
        RV = Rrelax;
        CV = Ccurv;
    end

    if isempty(TkV)
        error('run_validate_relaxation_dataset:NoFiniteRows', 'No finite rows after filtering NaN/Inf.');
    end

    Tuniq = unique(TkV, 'stable');
    N_TEMPERATURES = numel(Tuniq);
    if N_TEMPERATURES < 1
        error('run_validate_relaxation_dataset:NoTemperatures', 'No finite temperatures were found.');
    end

    nPerT = zeros(N_TEMPERATURES, 1);
    strictIncPerT = false(N_TEMPERATURES, 1);
    mJumpRatio = NaN(N_TEMPERATURES, 1);
    mOscFrac = NaN(N_TEMPERATURES, 1);
    mNearMono = false(N_TEMPERATURES, 1);
    rPosFrac = NaN(N_TEMPERATURES, 1);
    rSpikeRatio = NaN(N_TEMPERATURES, 1);
    cSpikeRatio = NaN(N_TEMPERATURES, 1);
    cToRScale = NaN(N_TEMPERATURES, 1);
    shapeCorrToRef = NaN(N_TEMPERATURES, 1);
    rPeakLogt = NaN(N_TEMPERATURES, 1);
    rWidth = NaN(N_TEMPERATURES, 1);
    mRange = NaN(N_TEMPERATURES, 1);
    mStart = NaN(N_TEMPERATURES, 1);

    gridCell = cell(N_TEMPERATURES, 1);
    mCell = cell(N_TEMPERATURES, 1);
    rCell = cell(N_TEMPERATURES, 1);
    cCell = cell(N_TEMPERATURES, 1);

    for i = 1:N_TEMPERATURES
        tk = Tuniq(i);
        msk = abs(TkV - tk) < 1e-12;
        li = logtV(msk);
        mi = MV(msk);
        ri = RV(msk);
        ci = CV(msk);

        [li, ord] = sort(li, 'ascend');
        mi = mi(ord);
        ri = ri(ord);
        ci = ci(ord);

        nPerT(i) = numel(li);
        gridCell{i} = li;
        mCell{i} = mi;
        rCell{i} = ri;
        cCell{i} = ci;

        if numel(li) >= 2
            dli = diff(li);
            strictIncPerT(i) = all(dli > 0);
        else
            strictIncPerT(i) = false;
        end

        if numel(mi) >= 2
            d1 = diff(mi);
            medAbsD1 = median(abs(d1), 'omitnan');
            mJumpRatio(i) = max(abs(d1), [], 'omitnan') / max(medAbsD1, eps);

            s1 = sign(d1);
            s1 = s1(s1 ~= 0 & isfinite(s1));
            if numel(s1) >= 2
                mOscFrac(i) = sum(abs(diff(s1)) > 0) / (numel(s1) - 1);
            else
                mOscFrac(i) = 0;
            end

            fracPos = mean(d1 > 0, 'omitnan');
            fracNeg = mean(d1 < 0, 'omitnan');
            mNearMono(i) = max(fracPos, fracNeg) >= 0.80;
        end

        if numel(ri) >= 2
            rPosFrac(i) = mean(ri > 0, 'omitnan');
            dr = diff(ri);
            medAbsDR = median(abs(dr), 'omitnan');
            rSpikeRatio(i) = max(abs(dr), [], 'omitnan') / max(medAbsDR, eps);

            [rpk, ipk] = max(ri);
            if ~isfinite(rpk)
                [~, ipk] = max(abs(ri));
            end
            if isfinite(ipk) && ipk >= 1 && ipk <= numel(li)
                rPeakLogt(i) = li(ipk);
            end

            rHalf = 0.5 * max(ri, [], 'omitnan');
            if isfinite(rHalf)
                mh = ri >= rHalf;
                if any(mh)
                    lLow = min(li(mh), [], 'omitnan');
                    lHigh = max(li(mh), [], 'omitnan');
                    rWidth(i) = lHigh - lLow;
                end
            end
        end

        if numel(ci) >= 2
            dc = diff(ci);
            medAbsDC = median(abs(dc), 'omitnan');
            cSpikeRatio(i) = max(abs(dc), [], 'omitnan') / max(medAbsDC, eps);
            cToRScale(i) = median(abs(ci), 'omitnan') / max(median(abs(ri), 'omitnan'), eps);
        end

        mRange(i) = max(mi, [], 'omitnan') - min(mi, [], 'omitnan');
        mStart(i) = mean(mi(1:min(5, numel(mi))), 'omitnan');
    end

    ptsUnique = unique(nPerT(:));
    POINTS_PER_T = string(strtrim(mat2str(ptsUnique(:).')));
    allStrictIncreasing = all(strictIncPerT);

    if all(nPerT == nPerT(1)) && allStrictIncreasing
        refGrid = gridCell{1};
        maxDev = 0;
        for i = 2:N_TEMPERATURES
            gi = gridCell{i};
            dev = max(abs(gi - refGrid), [], 'omitnan');
            if isfinite(dev)
                maxDev = max(maxDev, dev);
            end
        end
        maxGridDeviation = maxDev;
    else
        maxGridDeviation = inf;
    end

    gridTol = 1e-10;
    gridConsistentLogical = all(nPerT == nPerT(1)) && allStrictIncreasing && isfinite(maxGridDeviation) && (maxGridDeviation <= gridTol);
    GRID_CONSISTENT = string(yn(1 + double(gridConsistentLogical)));

    refM = mCell{1};
    refMzn = (refM - mean(refM, 'omitnan')) ./ max(std(refM, 0, 'omitnan'), eps);
    for i = 1:N_TEMPERATURES
        mi = mCell{i};
        mizn = (mi - mean(mi, 'omitnan')) ./ max(std(mi, 0, 'omitnan'), eps);
        c = corr(refMzn, mizn, 'rows', 'complete', 'type', 'Pearson');
        shapeCorrToRef(i) = c;
    end

    nOscillatoryM = sum(mOscFrac > 0.60 & isfinite(mOscFrac));
    nDiscontinuousM = sum(mJumpRatio > 200 & isfinite(mJumpRatio));
    nFlippedShape = sum(shapeCorrToRef < -0.20 & isfinite(shapeCorrToRef));

    peakMed = median(rPeakLogt, 'omitnan');
    peakMad = median(abs(rPeakLogt - peakMed), 'omitnan');
    if ~isfinite(peakMad) || peakMad == 0
        peakMad = eps;
    end
    nPeakOutlier = sum(abs(rPeakLogt - peakMed) > 6 * peakMad & isfinite(rPeakLogt));

    widthMed = median(rWidth, 'omitnan');
    widthMad = median(abs(rWidth - widthMed), 'omitnan');
    if ~isfinite(widthMad) || widthMad == 0
        widthMad = eps;
    end
    nWidthOutlier = sum(abs(rWidth - widthMed) > 6 * widthMad & isfinite(rWidth));

    R_abs_max = max(abs(RV), [], 'omitnan');
    R_abs_median = median(abs(RV), 'omitnan');
    R_abs_std = std(abs(RV), 0, 'omitnan');
    C_abs_max = max(abs(CV), [], 'omitnan');
    C_abs_median = median(abs(CV), 'omitnan');
    C_abs_std = std(abs(CV), 0, 'omitnan');

    medianRPositiveFraction = median(rPosFrac, 'omitnan');
    maxRSpikeRatio = max(rSpikeRatio, [], 'omitnan');
    maxCSpikeRatio = max(cSpikeRatio, [], 'omitnan');
    maxCtoRScale = max(cToRScale, [], 'omitnan');

    derivativeStableLogical = isfinite(medianRPositiveFraction) && isfinite(maxRSpikeRatio) ...
        && (medianRPositiveFraction >= 0.60) && (maxRSpikeRatio <= 500);
    curvatureStableLogical = isfinite(maxCSpikeRatio) && isfinite(maxCtoRScale) ...
        && (maxCSpikeRatio <= 2000) && (maxCtoRScale <= 1e5);

    DERIVATIVE_STABLE = string(yn(1 + double(derivativeStableLogical)));
    CURVATURE_STABLE = string(yn(1 + double(curvatureStableLogical)));

    if N_TEMPERATURES > 1
        scaleCV = std(mRange, 0, 'omitnan') / max(mean(abs(mRange), 'omitnan'), eps);
        baseCV = std(mStart, 0, 'omitnan') / max(mean(abs(mStart), 'omitnan'), eps);
        normalizationConsistent = isfinite(scaleCV) && isfinite(baseCV) && (scaleCV <= 0.75) && (baseCV <= 0.75);
    else
        normalizationConsistent = true;
    end

    outlierLogical = (nOscillatoryM > 0) || (nDiscontinuousM > 0) || (nFlippedShape > 0) || (nPeakOutlier > 0) || (nWidthOutlier > 0);
    HAS_OUTLIERS = string(yn(1 + double(outlierLogical)));

    validLogical = (HAS_NAN == "NO") ...
        && (GRID_CONSISTENT == "YES") ...
        && (DERIVATIVE_STABLE == "YES") ...
        && (CURVATURE_STABLE == "YES") ...
        && (HAS_OUTLIERS == "NO") ...
        && (nRowsTotal > 0);
    DATA_VALID_FOR_ANALYSIS = string(yn(1 + double(validLogical)));

    EXECUTION_STATUS = "SUCCESS";

    md(end+1) = "## Basic Integrity";
    md(end+1) = "- Rows: " + string(nRowsTotal);
    md(end+1) = "- Columns: " + string(nColsTotal);
    md(end+1) = "- Required columns found: YES";
    md(end+1) = "- HAS_NAN: " + HAS_NAN;
    md(end+1) = "";

    md(end+1) = "## Temperature Consistency";
    md(end+1) = "- N_TEMPERATURES: " + string(N_TEMPERATURES) + " (expected near 19)";
    md(end+1) = "- POINTS_PER_T (unique): " + POINTS_PER_T;
    md(end+1) = "- Same points per temperature: " + string(yn(1 + double(all(nPerT == nPerT(1)))));
    md(end+1) = "";

    md(end+1) = "## logt Grid";
    md(end+1) = "- Strictly increasing per T: " + string(yn(1 + double(allStrictIncreasing)));
    md(end+1) = "- Max grid deviation across T: " + string(maxGridDeviation);
    md(end+1) = "- GRID_CONSISTENT: " + GRID_CONSISTENT;
    md(end+1) = "";

    md(end+1) = "## Signal Sanity (M)";
    md(end+1) = "- Oscillatory curves flagged: " + string(nOscillatoryM);
    md(end+1) = "- Discontinuity flags: " + string(nDiscontinuousM);
    md(end+1) = "- Shape flips vs reference: " + string(nFlippedShape);
    md(end+1) = "- Near-monotonic curves: " + string(sum(mNearMono)) + "/" + string(N_TEMPERATURES);
    md(end+1) = "";

    md(end+1) = "## Derivative Sanity (R_relax)";
    md(end+1) = "- median positive fraction: " + string(medianRPositiveFraction);
    md(end+1) = "- max spike ratio: " + string(maxRSpikeRatio);
    md(end+1) = "- |R| max / median / std: " + string(R_abs_max) + " / " + string(R_abs_median) + " / " + string(R_abs_std);
    md(end+1) = "- DERIVATIVE_STABLE: " + DERIVATIVE_STABLE;
    md(end+1) = "";

    md(end+1) = "## Curvature Sanity (C)";
    md(end+1) = "- max spike ratio: " + string(maxCSpikeRatio);
    md(end+1) = "- max median(|C|)/median(|R|) scale: " + string(maxCtoRScale);
    md(end+1) = "- |C| max / median / std: " + string(C_abs_max) + " / " + string(C_abs_median) + " / " + string(C_abs_std);
    md(end+1) = "- CURVATURE_STABLE: " + CURVATURE_STABLE;
    md(end+1) = "";

    md(end+1) = "## Cross-Temperature Consistency";
    md(end+1) = "- R_relax peak-location outliers: " + string(nPeakOutlier);
    md(end+1) = "- R_relax width outliers: " + string(nWidthOutlier);
    md(end+1) = "";

    md(end+1) = "## Normalization Check";
    md(end+1) = "- Consistent M scale/baseline across T: " + string(yn(1 + double(normalizationConsistent)));
    md(end+1) = "";

    md(end+1) = "## Physical Plausibility Verdict";
    md(end+1) = "- HAS_OUTLIERS: " + HAS_OUTLIERS;
    md(end+1) = "- DATA_VALID_FOR_ANALYSIS: " + DATA_VALID_FOR_ANALYSIS;

catch ME
    ERROR_MESSAGE = string(getReport(ME, 'extended', 'hyperlinks', 'off'));
    EXECUTION_STATUS = "FAIL";

    md(end+1) = "## Error";
    md(end+1) = "```";
    md(end+1) = ERROR_MESSAGE;
    md(end+1) = "```";
end

statusTbl = table( ...
    string(EXECUTION_STATUS), ...
    double(N_TEMPERATURES), ...
    string(POINTS_PER_T), ...
    string(GRID_CONSISTENT), ...
    string(HAS_NAN), ...
    string(HAS_OUTLIERS), ...
    string(DERIVATIVE_STABLE), ...
    string(CURVATURE_STABLE), ...
    string(DATA_VALID_FOR_ANALYSIS), ...
    string(ERROR_MESSAGE), ...
    'VariableNames', {'EXECUTION_STATUS','N_TEMPERATURES','POINTS_PER_T','GRID_CONSISTENT','HAS_NAN','HAS_OUTLIERS','DERIVATIVE_STABLE','CURVATURE_STABLE','DATA_VALID_FOR_ANALYSIS','ERROR_MESSAGE'});
writetable(statusTbl, outStatusPath);

fid = fopen(outReportPath, 'w');
if fid >= 0
    for i = 1:numel(md)
        fprintf(fid, '%s\n', md(i));
    end
    fclose(fid);
end

fprintf('[DONE] %s\n', EXECUTION_STATUS);
fprintf('Status: %s\n', outStatusPath);
fprintf('Report: %s\n', outReportPath);
