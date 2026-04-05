clear; clc;

% Stage 1B forensic audit: width / kappa1 failure mode (switching).
% Analysis-only stage with canonical source lock.

startTime = datetime('now');

% Detect repo root.
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
    if strcmp(parentDir, scanDir), break; end
    scanDir = parentDir;
end
if isempty(repoRoot), error('Could not detect repository root.'); end

addpath(fullfile(repoRoot, 'Switching', 'utils'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

tablesDir = fullfile(repoRoot, 'tables');
statusDir = fullfile(repoRoot, 'status');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(statusDir, 'dir') ~= 7, mkdir(statusDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

summaryPath = fullfile(tablesDir, 'parameter_robustness_stage1b_width_kappa_summary.csv');
widthByTPath = fullfile(tablesDir, 'parameter_robustness_stage1b_width_by_temperature.csv');
kappaControlsPath = fullfile(tablesDir, 'parameter_robustness_stage1b_kappa_controls.csv');
verdictsPath = fullfile(tablesDir, 'parameter_robustness_stage1b_verdicts.csv');
statusPath = fullfile(statusDir, 'parameter_robustness_stage1b_status.txt');
reportPath = fullfile(reportsDir, 'parameter_robustness_stage1b_width_kappa_report.md');

runLabel = 'parameter_robustness_stage1b_width_kappa';
runCfg = struct('runLabel', runLabel);
runContext = createRunContext('switching', runCfg);
runDir = runContext.run_dir;

executionStatus = 'SUCCESS';
inputFound = 'NO';
errorMessage = '';
nT = 0;
mainSummary = 'Stage 1B not executed.';

canonicalRunId = 'run_2026_03_10_112659_alignment_audit';
canonicalSourceFile = fullfile(repoRoot, 'results', 'switching', 'runs', canonicalRunId, ...
    'alignment_audit', 'switching_alignment_samples.csv');
canonicalSourceLocked = 'NO';

summaryTbl = table();
widthByTTbl = table();
kappaControlsTbl = table();
verdictTbl = table();

try
    if exist(canonicalSourceFile, 'file') ~= 2
        error('Canonical source file not found: %s', canonicalSourceFile);
    end
    inputFound = 'YES';
    canonicalSourceLocked = 'YES';

    canonicalRunDir = fullfile(repoRoot, 'results', 'switching', 'runs', canonicalRunId);
    [canonicalRunStatus, ~] = get_run_status_value(canonicalRunDir);
    if canonicalRunStatus == "PARTIAL"
        error('PARTIAL_RUN_NOT_ALLOWED');
    end

    Tsamp = readtable(canonicalSourceFile);
    reqCols = {'current_mA', 'T_K', 'S_percent'};
    for i = 1:numel(reqCols)
        if ~ismember(reqCols{i}, Tsamp.Properties.VariableNames)
            error('Canonical source missing required column: %s', reqCols{i});
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
    if nT < 3, error('Not enough valid temperatures.'); end

    % Stage 1-equivalent peak extraction.
    iCan = NaN(nT, 1);
    iPar = NaN(nT, 1);
    sCan = NaN(nT, 1);
    sPar = NaN(nT, 1);
    for it = 1:nT
        yRow = Smap(it, :);
        valid = isfinite(currents) & isfinite(yRow(:));
        x = currents(valid);
        y = yRow(valid).';
        if numel(x) < 5, continue; end
        [sMax, idxMax] = max(y);
        if ~(isfinite(sMax) && isfinite(idxMax)), continue; end
        xPeakPar = x(idxMax);
        sPeakPar = sMax;
        if idxMax > 1 && idxMax < numel(x)
            xLocal = [x(idxMax - 1), x(idxMax), x(idxMax + 1)];
            yLocal = [y(idxMax - 1), y(idxMax), y(idxMax + 1)];
            p = polyfit(xLocal, yLocal, 2);
            if isfinite(p(1)) && isfinite(p(2)) && isfinite(p(3)) && abs(p(1)) > eps
                xv = -p(2) / (2 * p(1));
                if isfinite(xv) && xv >= min(xLocal) && xv <= max(xLocal)
                    yv = polyval(p, xv);
                    if isfinite(yv)
                        xPeakPar = xv;
                        sPeakPar = yv;
                    end
                end
            end
        end
        iCan(it) = x(idxMax);
        iPar(it) = xPeakPar;
        sCan(it) = sMax;
        sPar(it) = sPeakPar;
    end

    % Width + grid diagnostics.
    wLin = NaN(nT, 1); wNear = NaN(nT, 1); wFine = NaN(nT, 1); wLinIPar = NaN(nT, 1); wLinAug40 = NaN(nT, 1);
    halfLvl = NaN(nT, 1);
    medDx = NaN(nT, 1); maxDx = NaN(nT, 1);
    peakLeftDx = NaN(nT, 1); peakRightDx = NaN(nT, 1);
    peakLeftMargin = NaN(nT, 1); peakRightMargin = NaN(nT, 1); edgeMarginOverWidth = NaN(nT, 1);
    crossCountLin = NaN(nT, 1); crossCountNear = NaN(nT, 1); crossCountFine = NaN(nT, 1);
    leftDistLin = NaN(nT, 1); rightDistLin = NaN(nT, 1);
    leftDistNear = NaN(nT, 1); rightDistNear = NaN(nT, 1);
    leftDistFine = NaN(nT, 1); rightDistFine = NaN(nT, 1);
    leftGapLin = NaN(nT, 1); rightGapLin = NaN(nT, 1);
    leftGapNear = NaN(nT, 1); rightGapNear = NaN(nT, 1);
    leftGapFine = NaN(nT, 1); rightGapFine = NaN(nT, 1);
    qualLin = strings(nT, 1); qualNear = strings(nT, 1); qualFine = strings(nT, 1);
    halfmaxInLargeGap = false(nT, 1);
    oneSideUnderresolved = false(nT, 1);
    halfmaxCrossesMissing40 = false(nT, 1);
    peakNearEdge = false(nT, 1);
    asymRatio = NaN(nT, 1);
    deltaInsert40 = NaN(nT, 1);
    maxCrossDistLin = NaN(nT, 1);

    for it = 1:nT
        yRow = Smap(it, :);
        valid = isfinite(currents) & isfinite(yRow(:));
        x = currents(valid);
        y = yRow(valid).';
        qualLin(it) = "missing|missing";
        qualNear(it) = "missing|missing";
        qualFine(it) = "missing|missing";
        if numel(x) < 5, continue; end
        if ~(isfinite(iCan(it)) && isfinite(sCan(it)) && sCan(it) > 0), continue; end

        halfLvl(it) = 0.5 * sCan(it);
        medDx(it) = median(diff(x), 'omitnan');
        maxDx(it) = max(diff(x), [], 'omitnan');
        [~, idxPeak] = min(abs(x - iCan(it)));
        if idxPeak > 1, peakLeftDx(it) = x(idxPeak) - x(idxPeak - 1); end
        if idxPeak < numel(x), peakRightDx(it) = x(idxPeak + 1) - x(idxPeak); end
        peakLeftMargin(it) = iCan(it) - min(x);
        peakRightMargin(it) = max(x) - iCan(it);
        peakNearEdge(it) = (idxPeak <= 2) || (idxPeak >= (numel(x) - 1));

        % linear
        leftLin = NaN; rightLin = NaN; jL = NaN; jR = NaN;
        for j = idxPeak:-1:2
            if y(j - 1) < halfLvl(it) && y(j) >= halfLvl(it)
                if abs(y(j) - y(j - 1)) < eps
                    leftLin = 0.5 * (x(j - 1) + x(j));
                else
                    t = (halfLvl(it) - y(j - 1)) / (y(j) - y(j - 1));
                    leftLin = x(j - 1) + t * (x(j) - x(j - 1));
                end
                jL = j;
                break;
            end
        end
        for j = idxPeak:(numel(x) - 1)
            if y(j) >= halfLvl(it) && y(j + 1) < halfLvl(it)
                if abs(y(j + 1) - y(j)) < eps
                    rightLin = 0.5 * (x(j) + x(j + 1));
                else
                    t = (halfLvl(it) - y(j)) / (y(j + 1) - y(j));
                    rightLin = x(j) + t * (x(j + 1) - x(j));
                end
                jR = j;
                break;
            end
        end
        if isfinite(leftLin) && isfinite(rightLin) && rightLin > leftLin
            wLin(it) = rightLin - leftLin;
            lhw = iCan(it) - leftLin; rhw = rightLin - iCan(it);
            if lhw > 0 && rhw > 0
                asymRatio(it) = max(lhw, rhw) / min(lhw, rhw);
            end
            edgeMarginOverWidth(it) = min(peakLeftMargin(it), peakRightMargin(it)) / wLin(it);
        end
        crossCountLin(it) = double(isfinite(leftLin)) + double(isfinite(rightLin));
        if isfinite(leftLin), leftDistLin(it) = min(abs(x - leftLin), [], 'omitnan'); end
        if isfinite(rightLin), rightDistLin(it) = min(abs(x - rightLin), [], 'omitnan'); end
        maxCrossDistLin(it) = max([leftDistLin(it), rightDistLin(it)], [], 'omitnan');
        lq = "missing"; rq = "missing";
        if isfinite(jL)
            leftGapLin(it) = x(jL) - x(jL - 1);
            if leftGapLin(it) <= 1.25 * medDx(it), lq = "tight"; else, lq = "loose"; end
            if x(jL - 1) < 40 && x(jL) > 40, halfmaxCrossesMissing40(it) = true; end
        end
        if isfinite(jR)
            rightGapLin(it) = x(jR + 1) - x(jR);
            if rightGapLin(it) <= 1.25 * medDx(it), rq = "tight"; else, rq = "loose"; end
            if x(jR) < 40 && x(jR + 1) > 40, halfmaxCrossesMissing40(it) = true; end
        end
        qualLin(it) = lq + "|" + rq;
        halfmaxInLargeGap(it) = (isfinite(leftGapLin(it)) && leftGapLin(it) > 1.25 * medDx(it)) || ...
                                (isfinite(rightGapLin(it)) && rightGapLin(it) > 1.25 * medDx(it));
        oneSideUnderresolved(it) = xor( ...
            (isfinite(leftGapLin(it)) && leftGapLin(it) > 1.25 * medDx(it)), ...
            (isfinite(rightGapLin(it)) && rightGapLin(it) > 1.25 * medDx(it)));

        % nearest
        maskHalf = y >= halfLvl(it);
        lq = "missing"; rq = "missing";
        if nnz(maskHalf) >= 2
            idx = find(maskHalf); iL = idx(1); iR = idx(end);
            xL = x(iL); xR = x(iR);
            if isfinite(xL) && isfinite(xR) && xR > xL, wNear(it) = xR - xL; end
            leftUsable = iL > 1 && y(iL - 1) < halfLvl(it) && y(iL) >= halfLvl(it);
            rightUsable = iR < numel(x) && y(iR) >= halfLvl(it) && y(iR + 1) < halfLvl(it);
            crossCountNear(it) = double(leftUsable) + double(rightUsable);
            leftDistNear(it) = 0; rightDistNear(it) = 0;
            if iL > 1
                leftGapNear(it) = x(iL) - x(iL - 1);
                if leftGapNear(it) <= 1.25 * medDx(it), lq = "tight"; else, lq = "loose"; end
                if x(iL - 1) < 40 && x(iL) > 40, halfmaxCrossesMissing40(it) = true; end
            end
            if iR < numel(x)
                rightGapNear(it) = x(iR + 1) - x(iR);
                if rightGapNear(it) <= 1.25 * medDx(it), rq = "tight"; else, rq = "loose"; end
                if x(iR) < 40 && x(iR + 1) > 40, halfmaxCrossesMissing40(it) = true; end
            end
        end
        qualNear(it) = lq + "|" + rq;

        % fine interp
        xFine = linspace(min(x), max(x), max(1001, numel(x) * 80));
        yFine = interp1(x, y, xFine, 'pchip', NaN);
        [~, idxFinePeak] = min(abs(xFine - iCan(it)));
        leftFine = NaN; rightFine = NaN;
        for j = idxFinePeak:-1:2
            if isfinite(yFine(j - 1)) && isfinite(yFine(j)) && yFine(j - 1) < halfLvl(it) && yFine(j) >= halfLvl(it)
                if abs(yFine(j) - yFine(j - 1)) < eps
                    leftFine = 0.5 * (xFine(j - 1) + xFine(j));
                else
                    t = (halfLvl(it) - yFine(j - 1)) / (yFine(j) - yFine(j - 1));
                    leftFine = xFine(j - 1) + t * (xFine(j) - xFine(j - 1));
                end
                break;
            end
        end
        for j = idxFinePeak:(numel(xFine) - 1)
            if isfinite(yFine(j)) && isfinite(yFine(j + 1)) && yFine(j) >= halfLvl(it) && yFine(j + 1) < halfLvl(it)
                if abs(yFine(j + 1) - yFine(j)) < eps
                    rightFine = 0.5 * (xFine(j) + xFine(j + 1));
                else
                    t = (halfLvl(it) - yFine(j)) / (yFine(j + 1) - yFine(j));
                    rightFine = xFine(j) + t * (xFine(j + 1) - xFine(j));
                end
                break;
            end
        end
        if isfinite(leftFine) && isfinite(rightFine) && rightFine > leftFine, wFine(it) = rightFine - leftFine; end
        crossCountFine(it) = double(isfinite(leftFine)) + double(isfinite(rightFine));
        if isfinite(leftFine), leftDistFine(it) = min(abs(x - leftFine), [], 'omitnan'); end
        if isfinite(rightFine), rightDistFine(it) = min(abs(x - rightFine), [], 'omitnan'); end
        lq = "missing"; rq = "missing";
        if isfinite(leftFine)
            il = find(x <= leftFine, 1, 'last'); ir = find(x >= leftFine, 1, 'first');
            if ~isempty(il) && ~isempty(ir)
                if ir > il, leftGapFine(it) = x(ir) - x(il); else, leftGapFine(it) = 0; end
                if leftGapFine(it) <= 1.25 * medDx(it), lq = "tight"; else, lq = "loose"; end
                if ir > il && x(il) < 40 && x(ir) > 40, halfmaxCrossesMissing40(it) = true; end
            end
        end
        if isfinite(rightFine)
            il = find(x <= rightFine, 1, 'last'); ir = find(x >= rightFine, 1, 'first');
            if ~isempty(il) && ~isempty(ir)
                if ir > il, rightGapFine(it) = x(ir) - x(il); else, rightGapFine(it) = 0; end
                if rightGapFine(it) <= 1.25 * medDx(it), rq = "tight"; else, rq = "loose"; end
                if ir > il && x(il) < 40 && x(ir) > 40, halfmaxCrossesMissing40(it) = true; end
            end
        end
        qualFine(it) = lq + "|" + rq;

        % Peak-shift-only width.
        if isfinite(iPar(it))
            [~, idxPeakPar] = min(abs(x - iPar(it)));
            leftPar = NaN; rightPar = NaN;
            for j = idxPeakPar:-1:2
                if y(j - 1) < halfLvl(it) && y(j) >= halfLvl(it)
                    if abs(y(j) - y(j - 1)) < eps
                        leftPar = 0.5 * (x(j - 1) + x(j));
                    else
                        t = (halfLvl(it) - y(j - 1)) / (y(j) - y(j - 1));
                        leftPar = x(j - 1) + t * (x(j) - x(j - 1));
                    end
                    break;
                end
            end
            for j = idxPeakPar:(numel(x) - 1)
                if y(j) >= halfLvl(it) && y(j + 1) < halfLvl(it)
                    if abs(y(j + 1) - y(j)) < eps
                        rightPar = 0.5 * (x(j) + x(j + 1));
                    else
                        t = (halfLvl(it) - y(j)) / (y(j + 1) - y(j));
                        rightPar = x(j) + t * (x(j + 1) - x(j));
                    end
                    break;
                end
            end
            if isfinite(leftPar) && isfinite(rightPar) && rightPar > leftPar, wLinIPar(it) = rightPar - leftPar; end
        end

        % Missing-40 diagnostic (synthetic insertion).
        if min(x) < 40 && max(x) > 40 && ~any(abs(x - 40) < 1e-9)
            y40 = interp1(x, y, 40, 'linear', NaN);
            if isfinite(y40)
                xAug = [x(:); 40];
                yAug = [y(:); y40];
                [xAug, ord] = sort(xAug); yAug = yAug(ord).';
                [~, idxAug] = min(abs(xAug - iCan(it)));
                leftAug = NaN; rightAug = NaN;
                for j = idxAug:-1:2
                    if yAug(j - 1) < halfLvl(it) && yAug(j) >= halfLvl(it)
                        if abs(yAug(j) - yAug(j - 1)) < eps
                            leftAug = 0.5 * (xAug(j - 1) + xAug(j));
                        else
                            t = (halfLvl(it) - yAug(j - 1)) / (yAug(j) - yAug(j - 1));
                            leftAug = xAug(j - 1) + t * (xAug(j) - xAug(j - 1));
                        end
                        break;
                    end
                end
                for j = idxAug:(numel(xAug) - 1)
                    if yAug(j) >= halfLvl(it) && yAug(j + 1) < halfLvl(it)
                        if abs(yAug(j + 1) - yAug(j)) < eps
                            rightAug = 0.5 * (xAug(j) + xAug(j + 1));
                        else
                            t = (halfLvl(it) - yAug(j)) / (yAug(j + 1) - yAug(j));
                            rightAug = xAug(j) + t * (xAug(j + 1) - xAug(j));
                        end
                        break;
                    end
                end
                if isfinite(leftAug) && isfinite(rightAug) && rightAug > leftAug
                    wLinAug40(it) = rightAug - leftAug;
                    if isfinite(wLin(it)), deltaInsert40(it) = wLinAug40(it) - wLin(it); end
                end
            end
        end
    end

    absDevNear = abs(wNear - wLin); relDevNear = absDevNear ./ max(abs(wLin), eps);
    absDevFine = abs(wFine - wLin); relDevFine = absDevFine ./ max(abs(wLin), eps);
    absDevPeakOnly = abs(wLinIPar - wLin); relDevPeakOnly = absDevPeakOnly ./ max(abs(wLin), eps);
    dI = iPar - iCan;

    widthByTTbl = table(Tgrid, iCan, iPar, dI, sCan, sPar, halfLvl, medDx, maxDx, ...
        peakLeftDx, peakRightDx, peakLeftMargin, peakRightMargin, edgeMarginOverWidth, ...
        wLin, wNear, wFine, wLinIPar, absDevNear, relDevNear, absDevFine, relDevFine, ...
        absDevPeakOnly, relDevPeakOnly, crossCountLin, crossCountNear, crossCountFine, ...
        leftDistLin, rightDistLin, leftDistNear, rightDistNear, leftDistFine, rightDistFine, ...
        leftGapLin, rightGapLin, leftGapNear, rightGapNear, leftGapFine, rightGapFine, ...
        qualLin, qualNear, qualFine, halfmaxInLargeGap, oneSideUnderresolved, ...
        halfmaxCrossesMissing40, peakNearEdge, asymRatio, wLinAug40, deltaInsert40, ...
        'VariableNames', {'T_K','i_peak_canonical_mA','i_peak_parabolic_mA','delta_i_peak_mA', ...
        's_peak_canonical','s_peak_parabolic','half_level', ...
        'median_grid_spacing_mA','max_grid_spacing_mA','peak_left_spacing_mA','peak_right_spacing_mA', ...
        'peak_left_margin_mA','peak_right_margin_mA','edge_margin_over_width', ...
        'width_fwhm_linear_mA','width_fwhm_nearest_mA','width_fwhm_fine_interp_mA','width_linear_with_parabolic_peak_mA', ...
        'abs_dev_nearest_vs_linear_mA','rel_dev_nearest_vs_linear','abs_dev_fine_vs_linear_mA','rel_dev_fine_vs_linear', ...
        'abs_dev_peak_only_vs_linear_mA','rel_dev_peak_only_vs_linear', ...
        'usable_crossings_linear','usable_crossings_nearest','usable_crossings_fine_interp', ...
        'left_cross_dist_linear_mA','right_cross_dist_linear_mA','left_cross_dist_nearest_mA','right_cross_dist_nearest_mA', ...
        'left_cross_dist_fine_mA','right_cross_dist_fine_mA','left_bracket_gap_linear_mA','right_bracket_gap_linear_mA', ...
        'left_bracket_gap_nearest_mA','right_bracket_gap_nearest_mA','left_bracket_gap_fine_mA','right_bracket_gap_fine_mA', ...
        'bracket_quality_linear','bracket_quality_nearest','bracket_quality_fine_interp', ...
        'halfmax_in_large_gap','one_side_underresolved','halfmax_crosses_missing40_gap','peak_near_edge', ...
        'asymmetry_ratio','width_linear_augmented_with_40_mA','delta_width_if_insert40_mA'});
    writetable(widthByTTbl, widthByTPath);

    % kappa variants.
    K = NaN(nT, 6);
    xCollapseGrid = -2:0.2:2;
    Mcollapse = NaN(nT, numel(xCollapseGrid));
    for it = 1:nT
        yRow = Smap(it, :);
        valid = isfinite(currents) & isfinite(yRow(:));
        x = currents(valid);
        y = yRow(valid).';
        if numel(x) < 5, continue; end
        iVals = [iCan(it), iPar(it), iCan(it), iCan(it), iCan(it), iPar(it)];
        wVals = [wLin(it), wLin(it), wNear(it), wFine(it), wLin(it), wLin(it)];
        sVals = [sCan(it), sCan(it), sCan(it), sCan(it), sPar(it), sPar(it)];
        for kv = 1:6
            if ~(isfinite(iVals(kv)) && isfinite(wVals(kv)) && wVals(kv) > 0 && isfinite(sVals(kv)) && sVals(kv) > 0), continue; end
            xNorm = (x - iVals(kv)) ./ wVals(kv);
            yNorm = y ./ sVals(kv);
            m = isfinite(xNorm) & isfinite(yNorm) & abs(xNorm) <= 1;
            if nnz(m) >= 3
                p = polyfit(xNorm(m), yNorm(m), 1);
                K(it, kv) = p(1);
            end
        end
        if isfinite(iCan(it)) && isfinite(wLin(it)) && wLin(it) > 0 && isfinite(sCan(it)) && sCan(it) > 0
            xC = (x - iCan(it)) ./ wLin(it);
            yC = y ./ sCan(it);
            [xS, ord] = sort(xC);
            yS = yC(ord);
            Mcollapse(it, :) = interp1(xS, yS, xCollapseGrid, 'linear', NaN);
        end
    end

    meanCollapse = mean(Mcollapse, 1, 'omitnan');
    collapseByT = sqrt(mean((Mcollapse - meanCollapse).^2, 2, 'omitnan'));
    collapseRep = repmat(collapseByT, 1, 5);

    varIds = ["kappa_canonical";"kappa_ip_max_parabolic_local";"kappa_w_fwhm_nearest"; ...
              "kappa_w_fwhm_fine_interp";"kappa_sp_max_parabolic_local";"kappa_ip_sp_parabolic_w_canonical"];
    nV = size(K, 2);
    corrV = NaN(nV, 1); medRelV = NaN(nV, 1); worstRelV = NaN(nV, 1); rmseV = NaN(nV, 1); nVov = zeros(nV, 1);
    for v = 1:nV
        b = K(:, 1); c = K(:, v); m = isfinite(b) & isfinite(c); nVov(v) = nnz(m);
        if nnz(m) >= 2
            d = c(m) - b(m);
            den = abs(b(m)); den(den < eps) = 1;
            rel = abs(d) ./ den;
            medRelV(v) = median(rel, 'omitnan');
            worstRelV(v) = max(rel, [], 'omitnan');
            rmseV(v) = sqrt(mean(d.^2, 'omitnan'));
        end
        if nnz(m) >= 3
            if std(b(m)) > eps && std(c(m)) > eps
                corrV(v) = corr(b(m), c(m), 'type', 'Pearson');
            elseif all(abs(b(m) - c(m)) < 1e-12)
                corrV(v) = 1;
            end
        end
        if v == 1
            corrV(v) = 1; medRelV(v) = 0; worstRelV(v) = 0; rmseV(v) = 0;
        end
    end

    caseIds = ["A";"B";"C";"D"];
    caseDesc = ["Stage1 pipeline";"Width fixed canonical; vary peaks";"Width+I fixed; S only";"Width only"];
    caseSets = {[1 2 3 4 5],[1 2 5 6],[1 5],[1 3 4]};
    cMinCorr = NaN(4,1); cMedRel = NaN(4,1); cWorstRel = NaN(4,1); cValidT = zeros(4,1); cNPairs = zeros(4,1);
    for ci = 1:4
        idxSet = caseSets{ci}; nc = idxSet(2:end);
        cMinCorr(ci) = min(corrV(nc), [], 'omitnan');
        relAll = []; tMask = false(nT,1);
        for v = nc
            b = K(:,1); c = K(:,v); m = isfinite(b) & isfinite(c);
            tMask = tMask | m;
            if nnz(m) > 0
                d = c(m) - b(m);
                den = abs(b(m)); den(den < eps) = 1;
                relAll = [relAll; abs(d)./den]; %#ok<AGROW>
            end
        end
        cValidT(ci) = nnz(tMask); cNPairs(ci) = numel(relAll);
        if ~isempty(relAll)
            cMedRel(ci) = median(relAll, 'omitnan');
            cWorstRel(ci) = max(relAll, [], 'omitnan');
        end
    end

    kappaControlsTbl = [ ...
        table(repmat("variant", nV, 1), repmat("ALL", nV, 1), varIds, repmat("", nV, 1), ...
              corrV, medRelV, worstRelV, rmseV, nVov, repmat(NaN, nV, 1), repmat(NaN, nV, 1), ...
              'VariableNames', {'row_type','case_id','entry_id','description','corr_vs_canonical','median_rel_dev','worst_rel_dev','rmse_abs','n_overlap','valid_temperature_count','n_pairs'}); ...
        table(repmat("case_aggregate", 4, 1), caseIds, repmat("aggregate", 4, 1), caseDesc, ...
              cMinCorr, cMedRel, cWorstRel, repmat(NaN, 4, 1), repmat(NaN, 4, 1), cValidT, cNPairs, ...
              'VariableNames', {'row_type','case_id','entry_id','description','corr_vs_canonical','median_rel_dev','worst_rel_dev','rmse_abs','n_overlap','valid_temperature_count','n_pairs'})];
    writetable(kappaControlsTbl, kappaControlsPath);

    % Step 2/3/5/6/7 verdict logic.
    widthFail = isfinite(relDevNear) & relDevNear > 0.30;
    if nnz(widthFail) == 0
        [~, ord] = sort(relDevNear, 'descend');
        ord = ord(isfinite(relDevNear(ord)));
        widthFail = false(size(relDevNear));
        widthFail(ord(1:min(3, numel(ord)))) = true;
    end

    kRelW = NaN(nT,1);
    mKW = isfinite(K(:,1)) & isfinite(K(:,3));
    if nnz(mKW) > 0
        den = abs(K(mKW,1)); den(den < eps) = 1;
        kRelW(mKW) = abs(K(mKW,3)-K(mKW,1))./den;
    end
    kFail = isfinite(kRelW) & kRelW > 0.50;
    if nnz(kFail) == 0
        [~, ord] = sort(kRelW, 'descend');
        ord = ord(isfinite(kRelW(ord)));
        kFail = false(size(kRelW));
        kFail(ord(1:min(3, numel(ord)))) = true;
    end

    ratioLoose = NaN; ratioUnder = NaN; ratioEdgeAsym = NaN;
    if nnz(widthFail) > 0
        ratioLoose = mean(halfmaxInLargeGap(widthFail), 'omitnan');
        ratioUnder = mean((oneSideUnderresolved(widthFail) | maxCrossDistLin(widthFail) > 1.5), 'omitnan');
        ratioEdgeAsym = mean((peakNearEdge(widthFail) | asymRatio(widthFail) > 1.8), 'omitnan');
    end
    COARSE_GRID_CAUSE = "NO"; if isfinite(ratioLoose) && ratioLoose >= 0.60, COARSE_GRID_CAUSE = "YES"; end
    HALFMAX_UNDERSAMPLED = "NO"; if isfinite(ratioUnder) && ratioUnder >= 0.60, HALFMAX_UNDERSAMPLED = "YES"; end
    EDGE_OR_ASYMMETRY_CAUSE = "NO"; if isfinite(ratioEdgeAsym) && ratioEdgeAsym >= 0.50, EDGE_OR_ASYMMETRY_CAUSE = "YES"; end

    corrAbsDIAW = NaN; corrAbsDIRelNear = NaN;
    m1 = isfinite(dI) & isfinite(absDevPeakOnly);
    if nnz(m1) >= 3 && std(abs(dI(m1))) > eps && std(absDevPeakOnly(m1)) > eps
        corrAbsDIAW = corr(abs(dI(m1)), absDevPeakOnly(m1), 'type', 'Pearson');
    end
    m2 = isfinite(dI) & isfinite(relDevNear);
    if nnz(m2) >= 3 && std(abs(dI(m2))) > eps && std(relDevNear(m2)) > eps
        corrAbsDIRelNear = corr(abs(dI(m2)), relDevNear(m2), 'type', 'Pearson');
    end
    medRelPeakOnly = median(relDevPeakOnly, 'omitnan');
    medRelNear = median(relDevNear, 'omitnan');
    WIDTH_DEPENDS_ON_IPEAK = "NO";
    if (isfinite(corrAbsDIAW) && corrAbsDIAW >= 0.50) || (isfinite(medRelPeakOnly) && medRelPeakOnly >= 0.20)
        WIDTH_DEPENDS_ON_IPEAK = "YES";
    end
    WIDTH_PRIMARY_FAILURE = "NO";
    if isfinite(medRelNear) && isfinite(medRelPeakOnly) && medRelNear > 2*max(medRelPeakOnly,1e-6) && WIDTH_DEPENDS_ON_IPEAK=="NO"
        WIDTH_PRIMARY_FAILURE = "YES";
    end

    KAPPA1_SENSITIVE_TO_WIDTH = "NO"; if (isfinite(cMinCorr(4)) && cMinCorr(4) < 0.90) || (isfinite(cWorstRel(4)) && cWorstRel(4) > 0.50), KAPPA1_SENSITIVE_TO_WIDTH = "YES"; end
    KAPPA1_SENSITIVE_TO_IPEAK = "NO"; if (isfinite(corrV(2)) && corrV(2) < 0.90) || (isfinite(worstRelV(2)) && worstRelV(2) > 0.50), KAPPA1_SENSITIVE_TO_IPEAK = "YES"; end
    KAPPA1_SENSITIVE_TO_SPEAK = "NO"; if (isfinite(corrV(5)) && corrV(5) < 0.95) || (isfinite(worstRelV(5)) && worstRelV(5) > 0.15), KAPPA1_SENSITIVE_TO_SPEAK = "YES"; end

    regionNames = ["low_T","mid_T","T22_24","high_T"];
    reg = false(nT,4); reg(:,1)=Tgrid<=12; reg(:,2)=Tgrid>12&Tgrid<22; reg(:,3)=Tgrid>=22&Tgrid<=24; reg(:,4)=Tgrid>24;
    wCounts = zeros(4,1); kCounts = zeros(4,1);
    for r=1:4, wCounts(r)=nnz(widthFail&reg(:,r)); kCounts(r)=nnz(kFail&reg(:,r)); end
    [mw, iw] = max(wCounts); [mk, ik] = max(kCounts);
    WIDTH_FAILURE_LOCALIZED = "NO"; if sum(wCounts)>0 && mw>=ceil(0.5*sum(wCounts)), WIDTH_FAILURE_LOCALIZED="YES"; end
    KAPPA1_FAILURE_LOCALIZED = "NO"; if sum(kCounts)>0 && mk>=ceil(0.5*sum(kCounts)), KAPPA1_FAILURE_LOCALIZED="YES"; end
    FAILURE_REGION = "none";
    if sum(wCounts)>0 || sum(kCounts)>0
        FAILURE_REGION = strjoin(cellstr(unique([regionNames(iw), regionNames(ik)], 'stable')), ',');
    end

    collapseCorr = ones(5,1);
    for v=2:5
        b = collapseRep(:,1); c = collapseRep(:,v); m = isfinite(b)&isfinite(c);
        if nnz(m)>=3 && std(b(m))>eps && std(c(m))>eps
            collapseCorr(v)=corr(b(m),c(m),'type','Pearson');
        else
            collapseCorr(v)=1;
        end
    end
    collapseMinCorr = min(collapseCorr(2:end), [], 'omitnan');
    mA = isfinite(wLin) & isfinite(wNear); cA = NaN; if nnz(mA)>=3 && std(wLin(mA))>eps && std(wNear(mA))>eps, cA = corr(wLin(mA),wNear(mA),'type','Pearson'); end
    mB = isfinite(wLin) & isfinite(wFine); cB = NaN; if nnz(mB)>=3 && std(wLin(mB))>eps && std(wFine(mB))>eps, cB = corr(wLin(mB),wFine(mB),'type','Pearson'); end
    widthMinCorr = min([cA;cB], [], 'omitnan');
    MAP_STABLE_BUT_SCALARIZATION_FRAGILE = "NO";
    if isfinite(collapseMinCorr) && collapseMinCorr >= 0.999 && isfinite(widthMinCorr) && widthMinCorr < 0.98
        MAP_STABLE_BUT_SCALARIZATION_FRAGILE = "YES";
    end
    WIDTH_GOOD_PHYSICAL_COORDINATE = "YES";
    if COARSE_GRID_CAUSE=="YES" || HALFMAX_UNDERSAMPLED=="YES", WIDTH_GOOD_PHYSICAL_COORDINATE="NO"; end

    WIDTH_FAILURE_EXPLAINED_BY_GRID = "NO"; if COARSE_GRID_CAUSE=="YES" || HALFMAX_UNDERSAMPLED=="YES", WIDTH_FAILURE_EXPLAINED_BY_GRID="YES"; end
    WIDTH_FAILURE_EXPLAINED_BY_PEAK_SHIFT = WIDTH_DEPENDS_ON_IPEAK;
    KAPPA1_FAILURE_EXPLAINED_BY_WIDTH = "NO";
    if KAPPA1_SENSITIVE_TO_WIDTH=="YES"
        if isfinite(cWorstRel(4)) && isfinite(worstRelV(2))
            if cWorstRel(4) >= 0.9 * worstRelV(2), KAPPA1_FAILURE_EXPLAINED_BY_WIDTH = "YES"; end
        else
            KAPPA1_FAILURE_EXPLAINED_BY_WIDTH = "YES";
        end
    end
    KAPPA1_FAILURE_INDEPENDENT = "NO"; if (KAPPA1_SENSITIVE_TO_IPEAK=="YES" || KAPPA1_SENSITIVE_TO_SPEAK=="YES") && isfinite(cMinCorr(2)) && cMinCorr(2)<0.90, KAPPA1_FAILURE_INDEPENDENT="YES"; end
    MAP_STABILITY_THREATENED = "NO"; if ~isfinite(collapseMinCorr) || collapseMinCorr < 0.999, MAP_STABILITY_THREATENED = "YES"; end

    FINAL_INTERPRETATION = "mixed but interpretable";
    if WIDTH_FAILURE_EXPLAINED_BY_GRID=="YES" && KAPPA1_FAILURE_EXPLAINED_BY_WIDTH=="YES" && KAPPA1_FAILURE_INDEPENDENT=="NO"
        FINAL_INTERPRETATION = "width artifact dominates";
    elseif WIDTH_FAILURE_EXPLAINED_BY_GRID=="NO" && KAPPA1_FAILURE_EXPLAINED_BY_WIDTH=="NO"
        FINAL_INTERPRETATION = "genuine canonical fragility";
    elseif KAPPA1_FAILURE_EXPLAINED_BY_WIDTH=="NO" && KAPPA1_FAILURE_INDEPENDENT=="YES"
        FINAL_INTERPRETATION = "kappa estimator artifact dominates";
    end

    % Summary table.
    sec = strings(0,1); met = strings(0,1); valNum = NaN(0,1); valText = strings(0,1);
    rows = { ...
        "source","CANONICAL_SOURCE_LOCKED",NaN,string(canonicalSourceLocked); ...
        "width","min_corr_noncanonical",widthMinCorr,""; ...
        "width","median_rel_dev_nearest_vs_linear",median(relDevNear,'omitnan'),""; ...
        "width","median_rel_dev_fine_vs_linear",median(relDevFine,'omitnan'),""; ...
        "width","median_abs_delta_if_insert40_mA",median(abs(deltaInsert40),'omitnan'),""; ...
        "grid","ratio_loose_brackets_in_width_fail",ratioLoose,""; ...
        "grid","ratio_undersampled_in_width_fail",ratioUnder,""; ...
        "grid","ratio_edge_or_asym_in_width_fail",ratioEdgeAsym,""; ...
        "peak","corr_abs_deltaI_vs_abs_deltaW_peak_only",corrAbsDIAW,""; ...
        "peak","corr_abs_deltaI_vs_rel_dev_nearest",corrAbsDIRelNear,""; ...
        "peak","median_rel_peak_only_width_change",medRelPeakOnly,""; ...
        "peak","median_rel_nearest_width_change",medRelNear,""; ...
        "kappa_A","min_corr",cMinCorr(1),""; ...
        "kappa_A","median_rel_dev",cMedRel(1),""; ...
        "kappa_A","worst_rel_dev",cWorstRel(1),""; ...
        "kappa_A","valid_temperature_count",cValidT(1),""; ...
        "kappa_B","min_corr",cMinCorr(2),""; ...
        "kappa_B","median_rel_dev",cMedRel(2),""; ...
        "kappa_B","worst_rel_dev",cWorstRel(2),""; ...
        "kappa_B","valid_temperature_count",cValidT(2),""; ...
        "kappa_C","min_corr",cMinCorr(3),""; ...
        "kappa_C","median_rel_dev",cMedRel(3),""; ...
        "kappa_C","worst_rel_dev",cWorstRel(3),""; ...
        "kappa_C","valid_temperature_count",cValidT(3),""; ...
        "kappa_D","min_corr",cMinCorr(4),""; ...
        "kappa_D","median_rel_dev",cMedRel(4),""; ...
        "kappa_D","worst_rel_dev",cWorstRel(4),""; ...
        "kappa_D","valid_temperature_count",cValidT(4),""; ...
        "collapse","min_corr_noncanonical",collapseMinCorr,""; ...
        "temperature","width_failure_region",NaN,regionNames(iw); ...
        "temperature","kappa_failure_region",NaN,regionNames(ik); ...
        "interpretation","final_interpretation",NaN,FINAL_INTERPRETATION};
    for r = 1:size(rows,1)
        sec(end+1,1)=string(rows{r,1}); met(end+1,1)=string(rows{r,2}); valNum(end+1,1)=rows{r,3}; valText(end+1,1)=string(rows{r,4}); %#ok<SAGROW>
    end
    summaryTbl = table(sec, met, valNum, valText, 'VariableNames', {'section','metric','value_numeric','value_text'});
    writetable(summaryTbl, summaryPath);

    vNames = [ ...
        "CANONICAL_SOURCE_LOCKED";"COARSE_GRID_CAUSE";"HALFMAX_UNDERSAMPLED";"EDGE_OR_ASYMMETRY_CAUSE"; ...
        "WIDTH_DEPENDS_ON_IPEAK";"WIDTH_PRIMARY_FAILURE";"KAPPA1_SENSITIVE_TO_WIDTH";"KAPPA1_SENSITIVE_TO_IPEAK"; ...
        "KAPPA1_SENSITIVE_TO_SPEAK";"WIDTH_FAILURE_LOCALIZED";"KAPPA1_FAILURE_LOCALIZED";"FAILURE_REGION"; ...
        "MAP_STABLE_BUT_SCALARIZATION_FRAGILE";"WIDTH_GOOD_PHYSICAL_COORDINATE"; ...
        "WIDTH_FAILURE_EXPLAINED_BY_GRID";"WIDTH_FAILURE_EXPLAINED_BY_PEAK_SHIFT"; ...
        "KAPPA1_FAILURE_EXPLAINED_BY_WIDTH";"KAPPA1_FAILURE_INDEPENDENT";"MAP_STABILITY_THREATENED";"FINAL_INTERPRETATION"];
    vVals = [ ...
        canonicalSourceLocked;COARSE_GRID_CAUSE;HALFMAX_UNDERSAMPLED;EDGE_OR_ASYMMETRY_CAUSE; ...
        WIDTH_DEPENDS_ON_IPEAK;WIDTH_PRIMARY_FAILURE;KAPPA1_SENSITIVE_TO_WIDTH;KAPPA1_SENSITIVE_TO_IPEAK; ...
        KAPPA1_SENSITIVE_TO_SPEAK;WIDTH_FAILURE_LOCALIZED;KAPPA1_FAILURE_LOCALIZED;string(FAILURE_REGION); ...
        MAP_STABLE_BUT_SCALARIZATION_FRAGILE;WIDTH_GOOD_PHYSICAL_COORDINATE; ...
        WIDTH_FAILURE_EXPLAINED_BY_GRID;WIDTH_FAILURE_EXPLAINED_BY_PEAK_SHIFT; ...
        KAPPA1_FAILURE_EXPLAINED_BY_WIDTH;KAPPA1_FAILURE_INDEPENDENT;MAP_STABILITY_THREATENED;string(FINAL_INTERPRETATION)];
    verdictTbl = table(vNames, vVals, 'VariableNames', {'NAME','VALUE'});
    writetable(verdictTbl, verdictsPath);

    mainSummary = 'Stage 1B width/kappa forensic audit completed.';
    fidStatus = fopen(statusPath, 'w');
    if fidStatus < 0, error('Could not write status file.'); end
    fprintf(fidStatus, 'EXECUTION_STATUS=%s\n', executionStatus);
    fprintf(fidStatus, 'INPUT_FOUND=%s\n', inputFound);
    fprintf(fidStatus, 'ERROR_MESSAGE=%s\n', errorMessage);
    fprintf(fidStatus, 'N_T=%d\n', nT);
    fprintf(fidStatus, 'MAIN_RESULT_SUMMARY=%s\n', mainSummary);
    fprintf(fidStatus, 'CANONICAL_RUN_ID=%s\n', canonicalRunId);
    fprintf(fidStatus, 'CANONICAL_SOURCE_LOCKED=%s\n', canonicalSourceLocked);
    for i = 1:height(verdictTbl)
        fprintf(fidStatus, '%s=%s\n', verdictTbl.NAME(i), verdictTbl.VALUE(i));
    end
    fclose(fidStatus);

    rpt = strings(0,1);
    rpt(end+1) = "# Parameter Robustness Stage 1B: Width/Kappa1 Forensic Audit";
    rpt(end+1) = "";
    rpt(end+1) = "## Canonical lock";
    rpt(end+1) = "- run_id: `" + string(canonicalRunId) + "`";
    rpt(end+1) = "- source_file: `" + string(canonicalSourceFile) + "`";
    rpt(end+1) = "- CANONICAL_SOURCE_LOCKED = " + canonicalSourceLocked;
    rpt(end+1) = "";
    rpt(end+1) = "## Q1 - Width failure origin";
    rpt(end+1) = "- COARSE_GRID_CAUSE = " + COARSE_GRID_CAUSE + " (ratio_loose=" + string(ratioLoose) + ")";
    rpt(end+1) = "- HALFMAX_UNDERSAMPLED = " + HALFMAX_UNDERSAMPLED + " (ratio_under=" + string(ratioUnder) + ")";
    rpt(end+1) = "- EDGE_OR_ASYMMETRY_CAUSE = " + EDGE_OR_ASYMMETRY_CAUSE + " (ratio_edge_asym=" + string(ratioEdgeAsym) + ")";
    rpt(end+1) = "- median_rel_dev_nearest_vs_linear = " + string(medRelNear);
    rpt(end+1) = "- median_rel_dev_fine_vs_linear = " + string(median(relDevFine,'omitnan'));
    rpt(end+1) = "- median_abs_delta_if_insert40_mA = " + string(median(abs(deltaInsert40),'omitnan'));
    rpt(end+1) = "";
    rpt(end+1) = "## Q2/Q3 - kappa1 dependence";
    rpt(end+1) = "- Case A: min_corr=" + string(cMinCorr(1)) + ", median_rel=" + string(cMedRel(1)) + ", worst_rel=" + string(cWorstRel(1)) + ", valid_T=" + string(cValidT(1));
    rpt(end+1) = "- Case B: min_corr=" + string(cMinCorr(2)) + ", median_rel=" + string(cMedRel(2)) + ", worst_rel=" + string(cWorstRel(2)) + ", valid_T=" + string(cValidT(2));
    rpt(end+1) = "- Case C: min_corr=" + string(cMinCorr(3)) + ", median_rel=" + string(cMedRel(3)) + ", worst_rel=" + string(cWorstRel(3)) + ", valid_T=" + string(cValidT(3));
    rpt(end+1) = "- Case D: min_corr=" + string(cMinCorr(4)) + ", median_rel=" + string(cMedRel(4)) + ", worst_rel=" + string(cWorstRel(4)) + ", valid_T=" + string(cValidT(4));
    rpt(end+1) = "- KAPPA1_SENSITIVE_TO_WIDTH = " + KAPPA1_SENSITIVE_TO_WIDTH;
    rpt(end+1) = "- KAPPA1_SENSITIVE_TO_IPEAK = " + KAPPA1_SENSITIVE_TO_IPEAK;
    rpt(end+1) = "- KAPPA1_SENSITIVE_TO_SPEAK = " + KAPPA1_SENSITIVE_TO_SPEAK;
    rpt(end+1) = "";
    rpt(end+1) = "## Q4 - Map vs scalarization";
    rpt(end+1) = "- collapse_min_corr_noncanonical = " + string(collapseMinCorr);
    rpt(end+1) = "- width_min_corr_noncanonical = " + string(widthMinCorr);
    rpt(end+1) = "- MAP_STABLE_BUT_SCALARIZATION_FRAGILE = " + MAP_STABLE_BUT_SCALARIZATION_FRAGILE;
    rpt(end+1) = "";
    rpt(end+1) = "## Temperature structure";
    rpt(end+1) = "- WIDTH_FAILURE_LOCALIZED = " + WIDTH_FAILURE_LOCALIZED;
    rpt(end+1) = "- KAPPA1_FAILURE_LOCALIZED = " + KAPPA1_FAILURE_LOCALIZED;
    rpt(end+1) = "- FAILURE_REGION = " + string(FAILURE_REGION);
    rpt(end+1) = "";
    rpt(end+1) = "## Final verdicts";
    rpt(end+1) = "- WIDTH_FAILURE_EXPLAINED_BY_GRID = " + WIDTH_FAILURE_EXPLAINED_BY_GRID;
    rpt(end+1) = "- WIDTH_FAILURE_EXPLAINED_BY_PEAK_SHIFT = " + WIDTH_FAILURE_EXPLAINED_BY_PEAK_SHIFT;
    rpt(end+1) = "- KAPPA1_FAILURE_EXPLAINED_BY_WIDTH = " + KAPPA1_FAILURE_EXPLAINED_BY_WIDTH;
    rpt(end+1) = "- KAPPA1_FAILURE_INDEPENDENT = " + KAPPA1_FAILURE_INDEPENDENT;
    rpt(end+1) = "- MAP_STABILITY_THREATENED = " + MAP_STABILITY_THREATENED;
    rpt(end+1) = "- FINAL_INTERPRETATION = " + string(FINAL_INTERPRETATION);
    fidReport = fopen(reportPath, 'w');
    if fidReport < 0, error('Could not write report file.'); end
    for i = 1:numel(rpt), fprintf(fidReport, '%s\n', char(rpt(i))); end
    fclose(fidReport);

catch ME
    executionStatus = 'FAILED';
    errorMessage = ME.message;
    mainSummary = 'Stage 1B failed.';
    writetable(summaryTbl, summaryPath);
    writetable(widthByTTbl, widthByTPath);
    writetable(kappaControlsTbl, kappaControlsPath);
    writetable(verdictTbl, verdictsPath);
    fidStatus = fopen(statusPath, 'w');
    if fidStatus >= 0
        fprintf(fidStatus, 'EXECUTION_STATUS=%s\n', executionStatus);
        fprintf(fidStatus, 'INPUT_FOUND=%s\n', inputFound);
        fprintf(fidStatus, 'ERROR_MESSAGE=%s\n', errorMessage);
        fprintf(fidStatus, 'N_T=%d\n', nT);
        fprintf(fidStatus, 'MAIN_RESULT_SUMMARY=%s\n', mainSummary);
        fclose(fidStatus);
    end
    fidReport = fopen(reportPath, 'w');
    if fidReport >= 0
        fprintf(fidReport, '# Parameter Robustness Stage 1B: Width/Kappa1 Forensic Audit\n\n');
        fprintf(fidReport, 'Execution failed.\n\n- error: %s\n', errorMessage);
        fclose(fidReport);
    end
    rethrow(ME);
end

executionStatusTbl = table({executionStatus},{inputFound},{errorMessage},nT,{mainSummary}, ...
    'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
writetable(executionStatusTbl, fullfile(runDir, 'execution_status.csv'));

fidRun = fopen(fullfile(runDir, 'stage1b_width_kappa_run_report.md'), 'w');
if fidRun >= 0
    fprintf(fidRun, '# Stage 1B Width/Kappa Forensic Run\n\n');
    fprintf(fidRun, '- execution_status: %s\n', executionStatus);
    fprintf(fidRun, '- canonical_source_locked: %s\n', canonicalSourceLocked);
    fprintf(fidRun, '- elapsed_seconds: %.3f\n', seconds(datetime('now') - startTime));
    fclose(fidRun);
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
fprintf('OUTPUT_WIDTH_BY_T=%s\n', widthByTPath);
fprintf('OUTPUT_KAPPA_CONTROLS=%s\n', kappaControlsPath);
fprintf('OUTPUT_VERDICTS=%s\n', verdictsPath);
fprintf('OUTPUT_STATUS=%s\n', statusPath);
fprintf('OUTPUT_REPORT=%s\n', reportPath);
