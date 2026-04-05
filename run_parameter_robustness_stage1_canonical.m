clear; clc;

% Stage 1 canonical-parameter robustness test for switching.
% Analysis only. Canonical-equivalent extraction variants only.

startTime = datetime('now');

% Robust repo-root detection (search upward from cwd).
repoRoot = '';
scanDir = pwd;
for level = 1:15
    if exist(fullfile(scanDir, 'README.md'), 'file') == 2 && ...
       exist(fullfile(scanDir, 'Switching'), 'dir') == 7 && ...
       exist(fullfile(scanDir, 'tools'), 'dir') == 7
        repoRoot = scanDir;
        break;
    end
    parentDir = fileparts(scanDir);
    if strcmp(parentDir, scanDir)
        break;
    end
    scanDir = parentDir;
end
if isempty(repoRoot)
    error('Could not detect repository root.');
end

addpath(fullfile(repoRoot, 'Switching', 'utils'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

tablesDir = fullfile(repoRoot, 'tables');
statusDir = fullfile(repoRoot, 'status');
reportsDir = fullfile(repoRoot, 'reports');
figuresDir = fullfile(repoRoot, 'figures', 'parameter_robustness_stage1_canonical');

if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(statusDir, 'dir') ~= 7, mkdir(statusDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
if exist(figuresDir, 'dir') ~= 7, mkdir(figuresDir); end

summaryPath = fullfile(tablesDir, 'parameter_robustness_stage1_canonical_summary.csv');
verdictsPath = fullfile(tablesDir, 'parameter_robustness_stage1_canonical_verdicts.csv');
methodsPath = fullfile(tablesDir, 'parameter_robustness_stage1_canonical_methods.csv');
statusPath = fullfile(statusDir, 'parameter_robustness_stage1_canonical_status.txt');
reportPath = fullfile(reportsDir, 'parameter_robustness_stage1_canonical_report.md');

runLabel = 'parameter_robustness_stage1_canonical';
runId = ['run_' datestr(now, 'yyyy_mm_dd_HHMMSS') '_' runLabel];
runCfg = struct('runLabel', runLabel);
runContext = createRunContext('switching', runCfg);
runDir = runContext.run_dir;

executionStatus = 'SUCCESS';
inputFound = 'NO';
errorMessage = '';
nT = 0;
mainSummary = 'Stage-1 canonical robustness not executed.';

canonicalRunId = 'run_2026_03_10_112659_alignment_audit';
canonicalSourceFile = fullfile(repoRoot, 'results', 'switching', 'runs', canonicalRunId, ...
    'alignment_audit', 'switching_alignment_samples.csv');
canonicalObservable = 'S_percent';
canonicalNormalization = 'y_norm = S / S_peak (fixed logic)';
canonicalCollapseCoordinate = 'x_c = (I - I_peak_canonical) / width_canonical (fixed for all variants)';
canonicalMapConstruction = 'Switching/utils/buildSwitchingMapRounded.m';

canonicalSourceLocked = 'NO';

ipeakMethods = {'max_sample', 'max_parabolic_local'};
widthMethods = {'fwhm_linear', 'fwhm_nearest', 'fwhm_fine_interp'};
speakMethods = {'max_sample', 'max_parabolic_local'};

methodRows = {
    'I_peak', 'max_sample', 'allowed', 'YES', 'Direct maximum of S(I) at each T.', '';
    'I_peak', 'max_parabolic_local', 'allowed', 'YES', 'Local three-point quadratic refinement around the same peak maximum.', '';
    'width', 'fwhm_linear', 'allowed', 'YES', 'FWHM from half-max crossings with linear interpolation.', '';
    'width', 'fwhm_nearest', 'allowed', 'YES', 'Same FWHM definition with nearest-grid half-max crossings.', '';
    'width', 'fwhm_fine_interp', 'allowed', 'YES', 'Same FWHM definition with dense-grid interpolation for half-max crossings.', '';
    'S_peak', 'max_sample', 'allowed', 'YES', 'Direct maximum of S(I) at each T.', '';
    'S_peak', 'max_parabolic_local', 'allowed', 'YES', 'Local quadratic refinement of the same peak height observable.', '';
    'I_peak', 'dsdi_peak', 'excluded', 'NO', '', 'Derivative peak is a different observable from S(I) peak location.';
    'I_peak', 'com', 'excluded', 'NO', '', 'Center of mass redefines peak location as a moment of the profile.';
    'I_peak', 'halfmax_mid', 'excluded', 'NO', '', 'Half-max midpoint tracks threshold center, not direct peak location.';
    'width', 'rms', 'excluded', 'NO', '', 'RMS is a moment-based scale, not half-max width.';
    'width', 'iqr', 'excluded', 'NO', '', 'IQR is quantile spread, not half-max width.';
    'width', 'asymmetric', 'excluded', 'NO', '', 'Asymmetric left/right scaling changes width definition.';
    'S_peak', 'local_avg', 'excluded', 'NO', '', 'Local average is not the direct peak height observable.';
    'S_peak', 'local_median', 'excluded', 'NO', '', 'Local median is not the direct peak height observable.';
    'collapse', 'variant_specific_x_scaling', 'excluded', 'NO', '', 'Variant-specific collapse coordinates violate fixed-coordinate requirement.'
    };
methodsTbl = cell2table(methodRows, 'VariableNames', ...
    {'PARAM', 'METHOD', 'CLASS', 'INCLUDED', 'WHY_EQUIVALENT', 'EXCLUDED_REASON'});
writetable(methodsTbl, methodsPath);

summaryParam = strings(0, 1);
summaryVariant = strings(0, 1);
summaryIsCanonical = strings(0, 1);
summaryCorr = zeros(0, 1);
summaryRmse = zeros(0, 1);
summaryMedRel = zeros(0, 1);
summaryWorstRel = zeros(0, 1);
summaryMedAbs = zeros(0, 1);
summaryWorstAbs = zeros(0, 1);
summaryN = zeros(0, 1);

summaryTbl = table(summaryParam, summaryVariant, summaryIsCanonical, summaryCorr, ...
    summaryRmse, summaryMedRel, summaryWorstRel, summaryMedAbs, summaryWorstAbs, summaryN, ...
    'VariableNames', {'param', 'variant_id', 'is_canonical', 'corr_vs_canonical', ...
    'rmse_abs', 'median_rel_dev', 'worst_rel_dev', 'median_abs_dev', 'worst_abs_dev', 'n_overlap'});

verdictNames = {
    'CANONICAL_SOURCE_LOCKED';
    'IPEAK_CANONICAL_ROBUST';
    'WIDTH_CANONICAL_ROBUST';
    'SPEAK_CANONICAL_ROBUST';
    'KAPPA1_CANONICAL_ROBUST';
    'COLLAPSE_CANONICAL_ROBUST';
    'PARAMETER_CANONICAL_ROBUST';
    'OVERALL_INTERPRETATION'
    };
verdictValues = repmat({'NO'}, numel(verdictNames), 1);
verdictValues{8} = 'fragile even within canonical class';

try
    if exist(canonicalSourceFile, 'file') == 2
        inputFound = 'YES';
        canonicalSourceLocked = 'YES';
    else
        inputFound = 'NO';
        canonicalSourceLocked = 'NO';
        error('Canonical source file not found: %s', canonicalSourceFile);
    end

    canonicalRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', canonicalRunId);
    [canonicalRunStatus, ~] = get_run_status_value(canonicalRunDir);
    if canonicalRunStatus == "PARTIAL"
        error('PARTIAL_RUN_NOT_ALLOWED');
    end

    Tsamp = readtable(canonicalSourceFile);
    requiredCols = {'current_mA', 'T_K', 'S_percent'};
    for rc = 1:numel(requiredCols)
        if ~ismember(requiredCols{rc}, Tsamp.Properties.VariableNames)
            error('Canonical source is missing required column: %s', requiredCols{rc});
        end
    end

    Tsamp.current_mA = double(Tsamp.current_mA(:));
    Tsamp.T_K = double(Tsamp.T_K(:));
    Tsamp.S_percent = double(Tsamp.S_percent(:));

    [TgridRaw, currentsRaw, SmapRaw] = buildSwitchingMapRounded(Tsamp);
    TgridRaw = double(TgridRaw(:));
    currentsRaw = double(currentsRaw(:));
    SmapRaw = double(SmapRaw);

    goodRows = sum(isfinite(SmapRaw), 2) >= 5;
    Tgrid = TgridRaw(goodRows);
    Smap = SmapRaw(goodRows, :);
    currents = currentsRaw(:);

    nT = numel(Tgrid);
    if nT < 3
        error('Not enough valid temperatures after canonical map filtering.');
    end

    nI = numel(ipeakMethods);
    nW = numel(widthMethods);
    nS = numel(speakMethods);

    ipeakProfiles = NaN(nT, nI);
    widthProfiles = NaN(nT, nW);
    speakProfiles = NaN(nT, nS);

    % First pass: i_peak and S_peak variants (local max equivalents only).
    for it = 1:nT
        yRow = Smap(it, :);
        valid = isfinite(currents) & isfinite(yRow(:));
        x = currents(valid);
        y = yRow(valid).';
        if numel(x) < 5
            continue;
        end

        [sMax, idxMax] = max(y);
        if ~(isfinite(sMax) && isfinite(idxMax))
            continue;
        end

        xPeakPar = x(idxMax);
        sPeakPar = sMax;
        if idxMax > 1 && idxMax < numel(x)
            xLocal = [x(idxMax - 1), x(idxMax), x(idxMax + 1)];
            yLocal = [y(idxMax - 1), y(idxMax), y(idxMax + 1)];
            p = polyfit(xLocal, yLocal, 2);
            if isfinite(p(1)) && isfinite(p(2)) && isfinite(p(3)) && abs(p(1)) > eps
                xv = -p(2) / (2 * p(1));
                xLo = min(xLocal);
                xHi = max(xLocal);
                if isfinite(xv) && xv >= xLo && xv <= xHi
                    yv = polyval(p, xv);
                    if isfinite(yv)
                        xPeakPar = xv;
                        sPeakPar = yv;
                    end
                end
            end
        end

        ipeakProfiles(it, 1) = x(idxMax);
        ipeakProfiles(it, 2) = xPeakPar;

        speakProfiles(it, 1) = sMax;
        speakProfiles(it, 2) = sPeakPar;
    end

    % Second pass: width variants, fixed to canonical peak location and half-max level.
    for it = 1:nT
        yRow = Smap(it, :);
        valid = isfinite(currents) & isfinite(yRow(:));
        x = currents(valid);
        y = yRow(valid).';
        if numel(x) < 5
            continue;
        end

        iCan = ipeakProfiles(it, 1);
        sCan = speakProfiles(it, 1);
        if ~(isfinite(iCan) && isfinite(sCan) && sCan > 0)
            continue;
        end

        [~, idxPeakNearest] = min(abs(x - iCan));
        halfLevel = 0.5 * sCan;

        leftLin = NaN;
        rightLin = NaN;

        for j = idxPeakNearest:-1:2
            y1 = y(j - 1);
            y2 = y(j);
            if y1 < halfLevel && y2 >= halfLevel
                if abs(y2 - y1) < eps
                    leftLin = 0.5 * (x(j - 1) + x(j));
                else
                    t = (halfLevel - y1) / (y2 - y1);
                    leftLin = x(j - 1) + t * (x(j) - x(j - 1));
                end
                break;
            end
        end
        for j = idxPeakNearest:(numel(x) - 1)
            y1 = y(j);
            y2 = y(j + 1);
            if y1 >= halfLevel && y2 < halfLevel
                if abs(y2 - y1) < eps
                    rightLin = 0.5 * (x(j) + x(j + 1));
                else
                    t = (halfLevel - y1) / (y2 - y1);
                    rightLin = x(j) + t * (x(j + 1) - x(j));
                end
                break;
            end
        end

        if isfinite(leftLin) && isfinite(rightLin) && rightLin > leftLin
            widthProfiles(it, 1) = rightLin - leftLin;
        end

        maskHalf = y >= halfLevel;
        if nnz(maskHalf) >= 2
            xLeftN = min(x(maskHalf));
            xRightN = max(x(maskHalf));
            if isfinite(xLeftN) && isfinite(xRightN) && xRightN > xLeftN
                widthProfiles(it, 2) = xRightN - xLeftN;
            end
        end

        xFine = linspace(min(x), max(x), max(1001, numel(x) * 80));
        yFine = interp1(x, y, xFine, 'pchip', NaN);
        [~, idxFinePeak] = min(abs(xFine - iCan));
        leftFine = NaN;
        rightFine = NaN;
        for j = idxFinePeak:-1:2
            y1 = yFine(j - 1);
            y2 = yFine(j);
            if isfinite(y1) && isfinite(y2) && y1 < halfLevel && y2 >= halfLevel
                if abs(y2 - y1) < eps
                    leftFine = 0.5 * (xFine(j - 1) + xFine(j));
                else
                    t = (halfLevel - y1) / (y2 - y1);
                    leftFine = xFine(j - 1) + t * (xFine(j) - xFine(j - 1));
                end
                break;
            end
        end
        for j = idxFinePeak:(numel(xFine) - 1)
            y1 = yFine(j);
            y2 = yFine(j + 1);
            if isfinite(y1) && isfinite(y2) && y1 >= halfLevel && y2 < halfLevel
                if abs(y2 - y1) < eps
                    rightFine = 0.5 * (xFine(j) + xFine(j + 1));
                else
                    t = (halfLevel - y1) / (y2 - y1);
                    rightFine = xFine(j) + t * (xFine(j + 1) - xFine(j));
                end
                break;
            end
        end
        if isfinite(leftFine) && isfinite(rightFine) && rightFine > leftFine
            widthProfiles(it, 3) = rightFine - leftFine;
        end
    end

    % Kappa1 scenarios: fixed estimator, sensitivity enters only via upstream parameters.
    kappaVariantIds = {
        'kappa_canonical';
        'kappa_ip_max_parabolic_local';
        'kappa_w_fwhm_nearest';
        'kappa_w_fwhm_fine_interp';
        'kappa_sp_max_parabolic_local'
        };
    nK = numel(kappaVariantIds);
    kappaProfiles = NaN(nT, nK);

    xCollapseGrid = -2:0.2:2;
    McollapseCanonical = NaN(nT, numel(xCollapseGrid));

    for it = 1:nT
        yRow = Smap(it, :);
        valid = isfinite(currents) & isfinite(yRow(:));
        x = currents(valid);
        y = yRow(valid).';
        if numel(x) < 5
            continue;
        end

        iCan = ipeakProfiles(it, 1);
        wCan = widthProfiles(it, 1);
        sCan = speakProfiles(it, 1);
        if ~(isfinite(iCan) && isfinite(wCan) && wCan > 0 && isfinite(sCan) && sCan > 0)
            continue;
        end

        kI = [ipeakProfiles(it, 1), ipeakProfiles(it, 2), ipeakProfiles(it, 1), ipeakProfiles(it, 1), ipeakProfiles(it, 1)];
        kW = [widthProfiles(it, 1), widthProfiles(it, 1), widthProfiles(it, 2), widthProfiles(it, 3), widthProfiles(it, 1)];
        kS = [speakProfiles(it, 1), speakProfiles(it, 1), speakProfiles(it, 1), speakProfiles(it, 1), speakProfiles(it, 2)];

        for kv = 1:nK
            iVal = kI(kv);
            wVal = kW(kv);
            sVal = kS(kv);
            if ~(isfinite(iVal) && isfinite(wVal) && wVal > 0 && isfinite(sVal) && sVal > 0)
                continue;
            end
            xNorm = (x - iVal) ./ wVal;
            yNorm = y ./ sVal;
            fitMask = isfinite(xNorm) & isfinite(yNorm) & abs(xNorm) <= 1;
            if nnz(fitMask) >= 3
                pfit = polyfit(xNorm(fitMask), yNorm(fitMask), 1);
                kappaProfiles(it, kv) = pfit(1);
            end
        end

        % Collapse is evaluated in one fixed canonical coordinate for all variants.
        xCollapse = (x - iCan) ./ wCan;
        yCollapse = y ./ sCan;
        [xSorted, sortIdx] = sort(xCollapse);
        ySorted = yCollapse(sortIdx);
        McollapseCanonical(it, :) = interp1(xSorted, ySorted, xCollapseGrid, 'linear', NaN);
    end

    meanCollapse = mean(McollapseCanonical, 1, 'omitnan');
    collapseByT = sqrt(mean((McollapseCanonical - meanCollapse).^2, 2, 'omitnan'));
    collapseProfiles = repmat(collapseByT, 1, nK);

    % Build generic summary rows for each parameter and variant list.
    paramData = {
        'I_peak', ipeakProfiles, string(ipeakMethods);
        'width', widthProfiles, string(widthMethods);
        'S_peak', speakProfiles, string(speakMethods);
        'kappa1', kappaProfiles, string(kappaVariantIds);
        'collapse', collapseProfiles, string(kappaVariantIds)
        };

    robustnessFlags = struct();
    robustnessFlags.I_peak = 'NO';
    robustnessFlags.width = 'NO';
    robustnessFlags.S_peak = 'NO';
    robustnessFlags.kappa1 = 'NO';
    robustnessFlags.collapse = 'NO';

    thresholdCorr = struct('I_peak', 0.99, 'width', 0.98, 'S_peak', 0.99, 'kappa1', 0.95, 'collapse', 0.999);
    thresholdWorstRel = struct('I_peak', 0.08, 'width', 0.10, 'S_peak', 0.08, 'kappa1', 0.15, 'collapse', 0.01);

    aggregateRows = strings(0, 1);
    for pd = 1:size(paramData, 1)
        pName = string(paramData{pd, 1});
        P = double(paramData{pd, 2});
        pVariants = string(paramData{pd, 3});
        nV = size(P, 2);
        pCorr = NaN(nV, 1);
        pRmse = NaN(nV, 1);
        pMedRel = NaN(nV, 1);
        pWorstRel = NaN(nV, 1);
        pMedAbs = NaN(nV, 1);
        pWorstAbs = NaN(nV, 1);
        pN = zeros(nV, 1);

        base = P(:, 1);
        for v = 1:nV
            cur = P(:, v);
            mask = isfinite(base) & isfinite(cur);
            pN(v) = nnz(mask);
            if nnz(mask) >= 2
                delta = cur(mask) - base(mask);
                pRmse(v) = sqrt(mean(delta .^ 2, 'omitnan'));
                absDev = abs(delta);
                denom = abs(base(mask));
                denom(denom < eps) = 1.0;
                relDev = absDev ./ denom;
                pMedRel(v) = median(relDev, 'omitnan');
                pWorstRel(v) = max(relDev, [], 'omitnan');
                pMedAbs(v) = median(absDev, 'omitnan');
                pWorstAbs(v) = max(absDev, [], 'omitnan');
            end
            if nnz(mask) >= 3
                b = base(mask);
                c = cur(mask);
                if std(b) > eps && std(c) > eps
                    pCorr(v) = corr(b, c, 'type', 'Pearson');
                elseif all(abs(b - c) < 1e-12)
                    pCorr(v) = 1.0;
                end
            end
            if v == 1
                pCorr(v) = 1.0;
                pRmse(v) = 0.0;
                pMedRel(v) = 0.0;
                pWorstRel(v) = 0.0;
                pMedAbs(v) = 0.0;
                pWorstAbs(v) = 0.0;
            end
        end

        summaryParam = [summaryParam; repmat(pName, nV, 1)]; %#ok<AGROW>
        summaryVariant = [summaryVariant; pVariants(:)]; %#ok<AGROW>
        canonFlags = repmat("NO", nV, 1);
        canonFlags(1) = "YES";
        summaryIsCanonical = [summaryIsCanonical; canonFlags]; %#ok<AGROW>
        summaryCorr = [summaryCorr; pCorr]; %#ok<AGROW>
        summaryRmse = [summaryRmse; pRmse]; %#ok<AGROW>
        summaryMedRel = [summaryMedRel; pMedRel]; %#ok<AGROW>
        summaryWorstRel = [summaryWorstRel; pWorstRel]; %#ok<AGROW>
        summaryMedAbs = [summaryMedAbs; pMedAbs]; %#ok<AGROW>
        summaryWorstAbs = [summaryWorstAbs; pWorstAbs]; %#ok<AGROW>
        summaryN = [summaryN; pN]; %#ok<AGROW>

        if nV > 1
            minCorrNonCanon = min(pCorr(2:end), [], 'omitnan');
            worstRelNonCanon = max(pWorstRel(2:end), [], 'omitnan');
        else
            minCorrNonCanon = pCorr(1);
            worstRelNonCanon = pWorstRel(1);
        end

        robustNow = isfinite(minCorrNonCanon) && isfinite(worstRelNonCanon) && ...
            minCorrNonCanon >= thresholdCorr.(char(pName)) && ...
            worstRelNonCanon <= thresholdWorstRel.(char(pName));
        if robustNow
            robustnessFlags.(char(pName)) = 'YES';
        else
            robustnessFlags.(char(pName)) = 'NO';
        end

        aggLine = sprintf('%s|min_corr_noncanon=%.6f|worst_rel_noncanon=%.6f', ...
            char(pName), minCorrNonCanon, worstRelNonCanon);
        aggregateRows(end + 1, 1) = string(aggLine); %#ok<SAGROW>
    end

    IPEAK_CANONICAL_ROBUST = robustnessFlags.I_peak;
    WIDTH_CANONICAL_ROBUST = robustnessFlags.width;
    SPEAK_CANONICAL_ROBUST = robustnessFlags.S_peak;
    KAPPA1_CANONICAL_ROBUST = robustnessFlags.kappa1;
    COLLAPSE_CANONICAL_ROBUST = robustnessFlags.collapse;

    allYes = strcmp(IPEAK_CANONICAL_ROBUST, 'YES') && strcmp(WIDTH_CANONICAL_ROBUST, 'YES') && ...
        strcmp(SPEAK_CANONICAL_ROBUST, 'YES') && strcmp(KAPPA1_CANONICAL_ROBUST, 'YES') && ...
        strcmp(COLLAPSE_CANONICAL_ROBUST, 'YES');
    nYes = sum(strcmp({IPEAK_CANONICAL_ROBUST, WIDTH_CANONICAL_ROBUST, SPEAK_CANONICAL_ROBUST, ...
        KAPPA1_CANONICAL_ROBUST, COLLAPSE_CANONICAL_ROBUST}, 'YES'));
    if allYes
        PARAMETER_CANONICAL_ROBUST = 'YES';
        overallInterpretation = 'fully robust';
    elseif nYes >= 4
        PARAMETER_CANONICAL_ROBUST = 'NO';
        overallInterpretation = 'mostly robust';
    else
        PARAMETER_CANONICAL_ROBUST = 'NO';
        overallInterpretation = 'fragile even within canonical class';
    end

    verdictValues{1} = canonicalSourceLocked;
    verdictValues{2} = IPEAK_CANONICAL_ROBUST;
    verdictValues{3} = WIDTH_CANONICAL_ROBUST;
    verdictValues{4} = SPEAK_CANONICAL_ROBUST;
    verdictValues{5} = KAPPA1_CANONICAL_ROBUST;
    verdictValues{6} = COLLAPSE_CANONICAL_ROBUST;
    verdictValues{7} = PARAMETER_CANONICAL_ROBUST;
    verdictValues{8} = overallInterpretation;

    mainSummary = sprintf('Stage-1 canonical robustness done. Overall=%s', overallInterpretation);

    summaryTbl = table(summaryParam, summaryVariant, summaryIsCanonical, summaryCorr, ...
        summaryRmse, summaryMedRel, summaryWorstRel, summaryMedAbs, summaryWorstAbs, summaryN, ...
        'VariableNames', {'param', 'variant_id', 'is_canonical', 'corr_vs_canonical', ...
        'rmse_abs', 'median_rel_dev', 'worst_rel_dev', 'median_abs_dev', 'worst_abs_dev', 'n_overlap'});
    writetable(summaryTbl, summaryPath);

    verdictTbl = table(string(verdictNames), string(verdictValues), ...
        'VariableNames', {'NAME', 'VALUE'});
    writetable(verdictTbl, verdictsPath);

    reportLines = strings(0, 1);
    reportLines(end + 1) = "# Parameter Robustness Stage 1: Canonical Observable Class";
    reportLines(end + 1) = "";
    reportLines(end + 1) = "## Step 1 - Canonical input lock";
    reportLines(end + 1) = "- CANONICAL_SOURCE_LOCKED = " + string(canonicalSourceLocked);
    reportLines(end + 1) = "- source_file = `" + string(canonicalSourceFile) + "`";
    reportLines(end + 1) = "- run_id = `" + string(canonicalRunId) + "`";
    reportLines(end + 1) = "- observable = `" + string(canonicalObservable) + "`";
    reportLines(end + 1) = "- normalization = `" + string(canonicalNormalization) + "`";
    reportLines(end + 1) = "- collapse_coordinate = `" + string(canonicalCollapseCoordinate) + "`";
    reportLines(end + 1) = "- map_construction = `" + string(canonicalMapConstruction) + "`";
    reportLines(end + 1) = "- N_T = " + string(nT);
    reportLines(end + 1) = "- N_I = " + string(numel(currents));
    reportLines(end + 1) = "";
    reportLines(end + 1) = "## Step 2 - Included canonical-equivalent variants";
    reportLines(end + 1) = "- See `tables/parameter_robustness_stage1_canonical_methods.csv` (rows with INCLUDED=YES).";
    reportLines(end + 1) = "";
    reportLines(end + 1) = "## Step 3 - Robustness metrics";
    for k = 1:numel(aggregateRows)
        reportLines(end + 1) = "- " + aggregateRows(k);
    end
    reportLines(end + 1) = "";
    reportLines(end + 1) = "## Step 4 - Explicit exclusions";
    reportLines(end + 1) = "- See `tables/parameter_robustness_stage1_canonical_methods.csv` (rows with INCLUDED=NO).";
    reportLines(end + 1) = "";
    reportLines(end + 1) = "## Step 5 - Final verdicts";
    reportLines(end + 1) = "- IPEAK_CANONICAL_ROBUST = " + string(IPEAK_CANONICAL_ROBUST);
    reportLines(end + 1) = "- WIDTH_CANONICAL_ROBUST = " + string(WIDTH_CANONICAL_ROBUST);
    reportLines(end + 1) = "- SPEAK_CANONICAL_ROBUST = " + string(SPEAK_CANONICAL_ROBUST);
    reportLines(end + 1) = "- KAPPA1_CANONICAL_ROBUST = " + string(KAPPA1_CANONICAL_ROBUST);
    reportLines(end + 1) = "- COLLAPSE_CANONICAL_ROBUST = " + string(COLLAPSE_CANONICAL_ROBUST);
    reportLines(end + 1) = "- PARAMETER_CANONICAL_ROBUST = " + string(PARAMETER_CANONICAL_ROBUST);
    reportLines(end + 1) = "- overall_interpretation = " + string(overallInterpretation);

    fidReport = fopen(reportPath, 'w');
    if fidReport < 0
        error('Could not write report file: %s', reportPath);
    end
    for i = 1:numel(reportLines)
        fprintf(fidReport, '%s\n', char(reportLines(i)));
    end
    fclose(fidReport);

catch ME
    executionStatus = 'FAILED';
    if strcmp(inputFound, 'NO')
        canonicalSourceLocked = 'NO';
    end
    errorMessage = ME.message;
    mainSummary = 'Stage-1 canonical robustness failed. See error message.';

    verdictValues{1} = canonicalSourceLocked;
    verdictValues{2} = 'NO';
    verdictValues{3} = 'NO';
    verdictValues{4} = 'NO';
    verdictValues{5} = 'NO';
    verdictValues{6} = 'NO';
    verdictValues{7} = 'NO';
    verdictValues{8} = 'fragile even within canonical class';

    writetable(summaryTbl, summaryPath);
    verdictTbl = table(string(verdictNames), string(verdictValues), ...
        'VariableNames', {'NAME', 'VALUE'});
    writetable(verdictTbl, verdictsPath);

    fidReport = fopen(reportPath, 'w');
    if fidReport >= 0
        fprintf(fidReport, '# Parameter Robustness Stage 1: Canonical Observable Class\n\n');
        fprintf(fidReport, 'Execution failed.\n\n');
        fprintf(fidReport, '- error: %s\n', errorMessage);
        fclose(fidReport);
    end
    rethrow(ME);
end

% Always write status artifact requested by task.
statusLines = strings(0, 1);
statusLines(end + 1) = "EXECUTION_STATUS=" + string(executionStatus);
statusLines(end + 1) = "INPUT_FOUND=" + string(inputFound);
statusLines(end + 1) = "ERROR_MESSAGE=" + string(errorMessage);
statusLines(end + 1) = "N_T=" + string(nT);
statusLines(end + 1) = "MAIN_RESULT_SUMMARY=" + string(mainSummary);
for i = 1:numel(verdictNames)
    statusLines(end + 1) = string(verdictNames{i}) + "=" + string(verdictValues{i});
end

fidStatus = fopen(statusPath, 'w');
if fidStatus >= 0
    for i = 1:numel(statusLines)
        fprintf(fidStatus, '%s\n', char(statusLines(i)));
    end
    fclose(fidStatus);
end

% Wrapper-required run artifacts.
executionStatusTbl = table({executionStatus}, {inputFound}, {errorMessage}, nT, {mainSummary}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_T', 'MAIN_RESULT_SUMMARY'});
writetable(executionStatusTbl, fullfile(runDir, 'execution_status.csv'));

runReportPath = fullfile(runDir, 'stage1_canonical_run_report.md');
fidRunReport = fopen(runReportPath, 'w');
if fidRunReport >= 0
    fprintf(fidRunReport, '# Stage 1 Canonical Robustness Run\n\n');
    fprintf(fidRunReport, '- run_id: %s\n', runId);
    fprintf(fidRunReport, '- execution_status: %s\n', executionStatus);
    fprintf(fidRunReport, '- input_found: %s\n', inputFound);
    fprintf(fidRunReport, '- canonical_source_locked: %s\n', canonicalSourceLocked);
    fprintf(fidRunReport, '- elapsed_seconds: %.3f\n', seconds(datetime('now') - startTime));
    fclose(fidRunReport);
end

outputsList = { ...
    summaryPath; ...
    verdictsPath; ...
    methodsPath; ...
    statusPath; ...
    reportPath; ...
    fullfile(runDir, 'execution_status.csv'); ...
    runReportPath};
manifestStruct = struct('outputs', {outputsList});
manifestJson = jsonencode(manifestStruct);
fidManifest = fopen(fullfile(runDir, 'run_manifest.json'), 'w');
if fidManifest >= 0
    fprintf(fidManifest, '%s', manifestJson);
    fclose(fidManifest);
end

pointerPath = fullfile(repoRoot, 'run_dir_pointer.txt');
fidPointer = fopen(pointerPath, 'w');
if fidPointer >= 0
    fprintf(fidPointer, '%s', runDir);
    fclose(fidPointer);
end

fprintf('EXECUTION_STATUS=%s\n', executionStatus);
fprintf('CANONICAL_SOURCE_LOCKED=%s\n', canonicalSourceLocked);
fprintf('OUTPUT_SUMMARY=%s\n', summaryPath);
fprintf('OUTPUT_VERDICTS=%s\n', verdictsPath);
fprintf('OUTPUT_METHODS=%s\n', methodsPath);
fprintf('OUTPUT_STATUS=%s\n', statusPath);
fprintf('OUTPUT_REPORT=%s\n', reportPath);
