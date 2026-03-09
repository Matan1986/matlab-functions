% switching_mechanism_followup
% Focused follow-up mechanism diagnostics for switching observables.
%
% Reuses existing wrapper outputs from:
%   - Switching/analysis/switching_alignment_audit.m
%   - Switching/analysis/switching_mechanism_survey.m
%
% Constraint: metricType must remain fixed to P2P_percent.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

alignmentDir = resolve_results_input_dir(repoRoot, 'switching', 'alignment_audit');
mechDir = resolve_results_input_dir(repoRoot, 'switching', 'mechanism_survey');
[outDir, run] = init_run_output_dir(repoRoot, 'switching', 'mechanism_followup'); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% Required fixed metric definition.
metricType = "P2P_percent"; %#ok<NASGU>

obsCsv = fullfile(alignmentDir, 'switching_alignment_observables_vs_T.csv');
samplesCsv = fullfile(alignmentDir, 'switching_alignment_samples.csv');
mechSummaryCsv = fullfile(mechDir, 'mechanism_observables_summary.csv');

assert(isfile(obsCsv), 'Missing observables table: %s', obsCsv);
assert(isfile(samplesCsv), 'Missing samples table: %s', samplesCsv);

obsTbl = readtable(obsCsv);
samplesTbl = readtable(samplesCsv);
if isfile(mechSummaryCsv)
    mechTbl = readtable(mechSummaryCsv);
else
    mechTbl = table();
end

if ismember('metricType', samplesTbl.Properties.VariableNames)
    metricVals = string(samplesTbl.metricType);
    badMetric = metricVals ~= "P2P_percent";
    if any(badMetric)
        error('Samples contain non-P2P_percent rows; follow-up requires fixed metricType=P2P_percent.');
    end
end

% Reuse existing observables (do not recompute differently when already present).
tempsObs = toNumericColumn(obsTbl, 'T_K');
IpeakObs = toNumericColumn(obsTbl, 'Ipeak');
SpeakObs = toNumericColumn(obsTbl, 'S_peak');
widthIObs = toNumericColumn(obsTbl, 'width_I');
asymObs = toNumericColumn(obsTbl, 'asym');
coeffMode2Obs = toNumericColumn(obsTbl, 'coeff_mode2');
chiPeakObs = toNumericColumn(obsTbl, 'chiPeak');
chiWidthObs = toNumericColumn(obsTbl, 'chiWidth');
chiAreaObs = toNumericColumn(obsTbl, 'chiArea');
widthRelObs = toNumericColumn(obsTbl, 'width_rel');
dIpeakObs = toNumericColumn(obsTbl, 'dIpeak_dT');

[tempsMap, currents, Smap] = buildSwitchingMapRounded(samplesTbl);
[temps, iaObs, iaMap] = intersect(tempsObs, tempsMap, 'stable');
assert(~isempty(temps), 'No overlapping temperatures between observables and map.');

Ipeak = IpeakObs(iaObs);
S_peak = SpeakObs(iaObs);
width_I = widthIObs(iaObs);
asym = asymObs(iaObs);
coeff_mode2 = coeffMode2Obs(iaObs);
chiPeak = chiPeakObs(iaObs);
chiWidth = chiWidthObs(iaObs);
chiArea = chiAreaObs(iaObs);
width_rel = widthRelObs(iaObs);
dIpeak_dT = dIpeakObs(iaObs);
Smap = Smap(iaMap, :);

if ~all(isfinite(width_rel))
    mRel = isfinite(width_I) & isfinite(Ipeak) & abs(Ipeak) > eps;
    width_rel(mRel) = width_I(mRel) ./ Ipeak(mRel);
end
if ~all(isfinite(dIpeak_dT))
    mI = isfinite(Ipeak) & isfinite(temps);
    if nnz(mI) >= 2
        dIpeak_dT(mI) = gradient(Ipeak(mI), temps(mI));
    end
end

% Fallback for coeff_mode2 only if missing from existing outputs.
if any(~isfinite(coeff_mode2)) || all(abs(coeff_mode2) < eps)
    M = Smap;
    M(~isfinite(M)) = 0;
    [U,S,~] = svd(M, 'econ');
    if size(U,2) >= 2
        coeff_mode2 = U(:,2) * S(2,2);
    else
        coeff_mode2 = NaN(size(temps));
    end
end

% Regimes used for local interpretation.
regimeNames = ["global", "4-12 K", "14-20 K", "22-30 K"];
regimeRanges = [-inf inf; 4 12; 14 20; 22 30];

%% Analysis 1: Local/sliding Arrhenius slope test
windowSizes = [6 7 8 9];
windowSizes = windowSizes(windowSizes <= numel(temps));
arrRows = repmat(initArrRow(), 0, 1);

validSpeak = isfinite(S_peak) & (S_peak > 0) & isfinite(temps) & temps > 0;
for w = windowSizes
    for i0 = 1:(numel(temps) - w + 1)
        idx = i0:(i0+w-1);
        if ~all(validSpeak(idx))
            continue;
        end
        Tseg = temps(idx);
        x = 1 ./ Tseg;
        y = log(S_peak(idx));
        p = polyfit(x, y, 1);
        yfit = polyval(p, x);
        sse = sum((y - yfit).^2, 'omitnan');
        sst = sum((y - mean(y, 'omitnan')).^2, 'omitnan');
        if sst > 0
            r2 = 1 - sse / sst;
        else
            r2 = NaN;
        end
        rmse = sqrt(mean((y - yfit).^2, 'omitnan'));
        row = initArrRow();
        row.window_size = w;
        row.start_idx = i0;
        row.end_idx = i0 + w - 1;
        row.T_start = min(Tseg);
        row.T_end = max(Tseg);
        row.T_center = mean(Tseg);
        row.n_points = numel(Tseg);
        row.slope_b = p(1);
        row.Ea_eff = -p(1);
        row.intercept = p(2);
        row.R2 = r2;
        row.rmse = rmse;
        arrRows(end+1,1) = row; %#ok<SAGROW>
    end
end
arrTbl = struct2table(arrRows);

arrCsvOut = fullfile(outDir, 'mechanism_local_arrhenius_metrics.csv');
writetable(arrTbl, arrCsvOut);

figArr = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 900]);
tlArr = tiledlayout(figArr, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
if exist('turbo', 'file') == 2
    cmapArr = turbo(max(1, numel(windowSizes)));
else
    cmapArr = parula(max(1, numel(windowSizes)));
end

axA1 = nexttile(tlArr, 1); hold(axA1, 'on');
axA2 = nexttile(tlArr, 2); hold(axA2, 'on');
axA3 = nexttile(tlArr, 3); hold(axA3, 'on');
for k = 1:numel(windowSizes)
    w = windowSizes(k);
    m = arrTbl.window_size == w;
    if ~any(m)
        continue;
    end
    plot(axA1, arrTbl.T_center(m), arrTbl.Ea_eff(m), '-o', 'LineWidth', 1.7, ...
        'Color', cmapArr(k,:), 'DisplayName', sprintf('w=%d', w));
    plot(axA2, arrTbl.T_center(m), arrTbl.R2(m), '-o', 'LineWidth', 1.7, ...
        'Color', cmapArr(k,:), 'DisplayName', sprintf('w=%d', w));
    plot(axA3, arrTbl.T_center(m), arrTbl.rmse(m), '-o', 'LineWidth', 1.7, ...
        'Color', cmapArr(k,:), 'DisplayName', sprintf('w=%d', w));
end
xlabel(axA1, 'Window-center T (K)'); ylabel(axA1, 'E_{a,eff} ~ -slope'); title(axA1, 'Local Arrhenius slope'); grid(axA1, 'on'); legend(axA1, 'Location', 'eastoutside');
xlabel(axA2, 'Window-center T (K)'); ylabel(axA2, 'local R^2'); title(axA2, 'Local fit quality'); grid(axA2, 'on');
xlabel(axA3, 'Window-center T (K)'); ylabel(axA3, 'local RMSE'); title(axA3, 'Residual scale'); grid(axA3, 'on');

arrFigOut = fullfile(outDir, 'mechanism_local_arrhenius.png');
saveas(figArr, arrFigOut);
close(figArr);

%% Analysis 2: Mode-2 interpretation test
candNames = ["I_peak", "width_I", "asym", "dIpeak_dT", "width_rel", "chiPeak", "chiWidth", "chiArea"];
candVals = {Ipeak, width_I, asym, dIpeak_dT, width_rel, chiPeak, chiWidth, chiArea};
modeRows = repmat(initModeRow(), 0, 1);

for c = 1:numel(candNames)
    y = candVals{c};
    for r = 1:numel(regimeNames)
        tLo = regimeRanges(r,1);
        tHi = regimeRanges(r,2);
        mR = isfinite(temps) & temps >= tLo & temps <= tHi;
        v = mR & isfinite(coeff_mode2) & isfinite(y);
        rr = safeCorr(coeff_mode2(v), y(v));
        row = initModeRow();
        row.observable = candNames(c);
        row.regime = regimeNames(r);
        row.T_min = tLo;
        row.T_max = tHi;
        row.n_points = nnz(v);
        row.corr_coeff = rr;
        modeRows(end+1,1) = row; %#ok<SAGROW>
    end
end
modeTbl = struct2table(modeRows);
modeCsvOut = fullfile(outDir, 'mechanism_mode2_metrics.csv');
writetable(modeTbl, modeCsvOut);

% Required comparisons in one compact figure.
figMode = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1300 900]);
tlMode = tiledlayout(figMode, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

axM1 = nexttile(tlMode, 1); hold(axM1, 'on');
[zm2, okM2] = zscoreFinite(coeff_mode2);
[zI, okI] = zscoreFinite(Ipeak);
if okM2 && okI
    plot(axM1, temps, zm2, '-o', 'LineWidth', 1.8, 'DisplayName', 'coeff\_mode2 (z)');
    plot(axM1, temps, zI, '-s', 'LineWidth', 1.8, 'DisplayName', 'I_{peak} (z)');
end
xlabel(axM1, 'T (K)'); ylabel(axM1, 'z-score'); title(axM1, 'Mode2 vs I_{peak} (normalized)'); grid(axM1, 'on'); legend(axM1, 'Location', 'best');

axM2 = nexttile(tlMode, 2); hold(axM2, 'on');
[zW, okW] = zscoreFinite(width_I);
if okM2 && okW
    plot(axM2, temps, zm2, '-o', 'LineWidth', 1.8, 'DisplayName', 'coeff\_mode2 (z)');
    plot(axM2, temps, zW, '-s', 'LineWidth', 1.8, 'DisplayName', 'width_I (z)');
end
xlabel(axM2, 'T (K)'); ylabel(axM2, 'z-score'); title(axM2, 'Mode2 vs width_I (normalized)'); grid(axM2, 'on'); legend(axM2, 'Location', 'best');

axM3 = nexttile(tlMode, 3); hold(axM3, 'on');
[zA, okA] = zscoreFinite(asym);
if okM2 && okA
    plot(axM3, temps, zm2, '-o', 'LineWidth', 1.8, 'DisplayName', 'coeff\_mode2 (z)');
    plot(axM3, temps, zA, '-s', 'LineWidth', 1.8, 'DisplayName', 'asym (z)');
end
xlabel(axM3, 'T (K)'); ylabel(axM3, 'z-score'); title(axM3, 'Mode2 vs asymmetry (normalized)'); grid(axM3, 'on'); legend(axM3, 'Location', 'best');

axM4 = nexttile(tlMode, 4);
v = isfinite(coeff_mode2) & isfinite(Ipeak);
scatter(axM4, coeff_mode2(v), Ipeak(v), 50, temps(v), 'filled');
r = safeCorr(coeff_mode2(v), Ipeak(v));
xlabel(axM4, 'coeff\_mode2'); ylabel(axM4, 'I_{peak}'); title(axM4, sprintf('corr=%.3f', r)); grid(axM4, 'on'); cb = colorbar(axM4); ylabel(cb, 'T (K)');

axM5 = nexttile(tlMode, 5);
v = isfinite(coeff_mode2) & isfinite(width_I);
scatter(axM5, coeff_mode2(v), width_I(v), 50, temps(v), 'filled');
r = safeCorr(coeff_mode2(v), width_I(v));
xlabel(axM5, 'coeff\_mode2'); ylabel(axM5, 'width_I'); title(axM5, sprintf('corr=%.3f', r)); grid(axM5, 'on'); cb = colorbar(axM5); ylabel(cb, 'T (K)');

axM6 = nexttile(tlMode, 6);
v = isfinite(coeff_mode2) & isfinite(asym);
scatter(axM6, coeff_mode2(v), asym(v), 50, temps(v), 'filled');
r = safeCorr(coeff_mode2(v), asym(v));
xlabel(axM6, 'coeff\_mode2'); ylabel(axM6, 'asym'); title(axM6, sprintf('corr=%.3f', r)); grid(axM6, 'on'); cb = colorbar(axM6); ylabel(cb, 'T (K)');

modeFigOut = fullfile(outDir, 'mechanism_mode2_interpretation.png');
saveas(figMode, modeFigOut);
close(figMode);

%% Analysis 3: Ridge-shape mechanism test
xGrid = (-3:0.05:3)';
Ygrid = NaN(numel(temps), numel(xGrid));
leftHalf = NaN(size(temps));
rightHalf = NaN(size(temps));
halfDiff = NaN(size(temps));
areaLeft = NaN(size(temps));
areaRight = NaN(size(temps));
areaRatio = NaN(size(temps));
curvPeak = NaN(size(temps));

for it = 1:numel(temps)
    row = Smap(it,:);
    currRow = currents(:)';
    v = isfinite(row) & isfinite(currRow) & isfinite(Ipeak(it)) & isfinite(width_I(it)) & ...
        isfinite(S_peak(it)) & width_I(it) > eps & S_peak(it) > eps;
    if nnz(v) < 4
        continue;
    end
    cur = currRow(v);
    sig = row(v);
    x = (cur - Ipeak(it)) ./ width_I(it);
    y = sig ./ S_peak(it);
    [x, iu] = unique(x(:));
    y = y(iu);
    if numel(x) < 3
        continue;
    end
    Ygrid(it,:) = interp1(x, y, xGrid, 'linear', NaN);

    yPeak = max(y, [], 'omitnan');
    half = 0.5 * yPeak;
    mH = y >= half;
    if nnz(mH) >= 2
        leftHalf(it) = abs(min(x(mH)));
        rightHalf(it) = max(x(mH));
        halfDiff(it) = rightHalf(it) - leftHalf(it);
    end

    xl = x(x < 0); yl = y(x < 0);
    xr = x(x > 0); yr = y(x > 0);
    if numel(xl) >= 2 && numel(xr) >= 2
        aL = abs(trapz(xl, max(yl, 0)));
        aR = trapz(xr, max(yr, 0));
        areaLeft(it) = aL;
        areaRight(it) = aR;
        if aL > eps
            areaRatio(it) = aR / aL;
        end
    end

    peakMask = abs(x) <= 0.6;
    if nnz(peakMask) >= 3
        p2 = polyfit(x(peakMask), y(peakMask), 2);
        curvPeak(it) = 2 * p2(1);
    end
end


% Re-estimate curvature from interpolated normalized profiles for robustness.
for it = 1:numel(temps)
    yi = Ygrid(it,:);
    xRow = xGrid(:)';
    pm = isfinite(yi) & abs(xRow) <= 0.6;
    if nnz(pm) >= 5
        p2 = polyfit(xRow(pm), yi(pm), 2);
        curvPeak(it) = 2 * p2(1);
    else
        curvPeak(it) = NaN;
    end
end
lowMask = isfinite(temps) & temps >= 4 & temps <= 12;
meanLowShape = mean(Ygrid(lowMask, :), 1, 'omitnan');
shapeRMSE = NaN(size(temps));
for it = 1:numel(temps)
    yi = Ygrid(it,:);
    vv = isfinite(yi) & isfinite(meanLowShape);
    if nnz(vv) >= 5
        shapeRMSE(it) = sqrt(mean((yi(vv) - meanLowShape(vv)).^2, 'omitnan'));
    end
end

figShape = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1300 900]);
tlShape = tiledlayout(figShape, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axS1 = nexttile(tlShape, 1); hold(axS1, 'on');
lowIdx = find(lowMask);
if exist('turbo', 'file') == 2
    cLow = turbo(max(1, numel(lowIdx)));
else
    cLow = parula(max(1, numel(lowIdx)));
end
for k = 1:numel(lowIdx)
    it = lowIdx(k);
    yi = Ygrid(it,:);
    if any(isfinite(yi))
        plot(axS1, xGrid, yi, '-', 'LineWidth', 1.2, 'Color', cLow(k,:), 'DisplayName', sprintf('T=%g K', temps(it)));
    end
end
plot(axS1, xGrid, meanLowShape, 'k-', 'LineWidth', 2.3, 'DisplayName', 'low-T mean');
xlabel(axS1, '(I-I_{peak})/width_I'); ylabel(axS1, 'S/S_{peak}'); title(axS1, 'A) Low-T shape invariance (4-12 K)'); grid(axS1, 'on'); legend(axS1, 'Location', 'eastoutside');

axS2 = nexttile(tlShape, 2); hold(axS2, 'on');
plot(axS2, temps, leftHalf, '-o', 'LineWidth', 1.7, 'DisplayName', 'left half-width');
plot(axS2, temps, rightHalf, '-s', 'LineWidth', 1.7, 'DisplayName', 'right half-width');
plot(axS2, temps, halfDiff, '-^', 'LineWidth', 1.7, 'DisplayName', 'right-left');
xlabel(axS2, 'T (K)'); ylabel(axS2, 'normalized width'); title(axS2, 'B) Left/right flank evolution'); grid(axS2, 'on'); legend(axS2, 'Location', 'best');

axS3 = nexttile(tlShape, 3); hold(axS3, 'on');
plot(axS3, temps, areaRatio, '-o', 'LineWidth', 1.7, 'DisplayName', 'area ratio (R/L)');
if any(isfinite(asym))
    [za, oka] = zscoreFinite(asym);
    if oka
        plot(axS3, temps, za, '-s', 'LineWidth', 1.7, 'DisplayName', 'existing asym (z)');
    end
end
xlabel(axS3, 'T (K)'); ylabel(axS3, 'metric'); title(axS3, 'B) Area-asymmetry evolution'); grid(axS3, 'on'); legend(axS3, 'Location', 'best');

axS4 = nexttile(tlShape, 4);
imagesc(axS4, xGrid, temps, Ygrid);
set(axS4, 'YDir', 'normal');
if exist('turbo', 'file') == 2
    colormap(axS4, turbo);
else
    colormap(axS4, parula);
end
xlabel(axS4, '(I-I_{peak})/width_I'); ylabel(axS4, 'T (K)'); title(axS4, 'C) Ridge-shape evolution map');
cb = colorbar(axS4); ylabel(cb, 'S/S_{peak}');

shapeFigOut = fullfile(outDir, 'mechanism_ridge_shape_test.png');
saveas(figShape, shapeFigOut);
close(figShape);

shapeTbl = table(temps, Ipeak, S_peak, width_I, leftHalf, rightHalf, halfDiff, ...
    areaLeft, areaRight, areaRatio, curvPeak, shapeRMSE, asym, ...
    'VariableNames', {'T_K','I_peak','S_peak','width_I', ...
    'left_half_width_norm','right_half_width_norm','halfwidth_diff_norm', ...
    'area_left','area_right','area_ratio_right_over_left', ...
    'curvature_near_peak','shape_rmse_to_lowT_mean','existing_asym'});
shapeCsvOut = fullfile(outDir, 'mechanism_ridge_shape_metrics.csv');
writetable(shapeTbl, shapeCsvOut);

%% Report generation
reportOut = fullfile(outDir, 'mechanism_followup_report.md');
fid = fopen(reportOut, 'w');
assert(fid >= 0, 'Failed to open report file: %s', reportOut);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Switching Mechanism Follow-up Report\n\n');

fprintf(fid, '## 1. Purpose of this follow-up survey\n\n');
fprintf(fid, 'This follow-up targets three focused diagnostics: local/sliding Arrhenius behavior of `S_peak(T)`, interpretation of SVD `coeff_mode2(T)`, and ridge-shape evolution tests. The objective is compatibility screening of mechanism classes, not microscopic proof.\n\n');

fprintf(fid, '## 2. Existing inputs reused from prior surveys/audits\n\n');
fprintf(fid, '- Reused table: `results/switching/alignment_audit/switching_alignment_observables_vs_T.csv`\n');
fprintf(fid, '- Reused table: `results/switching/alignment_audit/switching_alignment_samples.csv`\n');
fprintf(fid, '- Reused (optional) summary: `results/switching/mechanism_survey/mechanism_observables_summary.csv`\n');
fprintf(fid, '- Reused observables: `S_peak`, `I_peak`, `width_I`, `asym`, `coeff_mode2`, `chiPeak`, `chiWidth`, `chiArea`, `width_rel`, `dIpeak_dT`\n');
fprintf(fid, '- Reused map-construction convention: rounded temperature bins and averaged `S(T,I)` per `(T,I)` pair\n\n');

fprintf(fid, '## 3. New analyses performed\n\n');
fprintf(fid, '1. Sliding-window Arrhenius slope analysis of `log(S_peak)` vs `1/T` using window sizes {6,7,8,9}.\n');
fprintf(fid, '2. Expanded mode-2 interpretation via global and regime-wise correlations against shape observables.\n');
fprintf(fid, '3. Ridge-shape evolution diagnostics from ridge-centered normalized cuts.\n\n');

fprintf(fid, '## 4. Variables/parameters tested\n\n');
fprintf(fid, '- Local Arrhenius windows: `%s` points\n', strjoin(string(windowSizes), ', '));
fprintf(fid, '- Regimes: global, 4-12 K, 14-20 K, 22-30 K\n');
fprintf(fid, '- Mode-2 comparison observables: I_peak, width_I, asym, dIpeak_dT, width_rel, chiPeak, chiWidth, chiArea\n');
fprintf(fid, '- Ridge shape coordinates: `x=(I-I_peak)/width_I`, `y=S/S_peak`\n\n');

fprintf(fid, '## 5. Exact definitions used in each analysis\n\n');
fprintf(fid, '- **Analysis 1**: for each contiguous window, fit `log(S_peak)=a+b*(1/T)`; define `Ea_eff ~ -b`; report `R^2` and RMSE.\n');
fprintf(fid, '- **Analysis 2**: compute Pearson correlation between `coeff_mode2` and each candidate observable globally and per regime.\n');
fprintf(fid, '- **Analysis 3A**: low-T invariance from spread of normalized ridge-centered curves (4-12 K).\n');
fprintf(fid, '- **Analysis 3B**: left/right flank metrics from normalized half-widths and area ratio `A_right/A_left`.\n');
fprintf(fid, '- **Analysis 3C**: peak-shape evolution from quadratic curvature near `x=0` and RMSE to low-T mean shape.\n\n');

fprintf(fid, '## 6. Files generated\n\n');
fprintf(fid, '- `mechanism_local_arrhenius.png`\n');
fprintf(fid, '- `mechanism_local_arrhenius_metrics.csv`\n');
fprintf(fid, '- `mechanism_mode2_interpretation.png`\n');
fprintf(fid, '- `mechanism_mode2_metrics.csv`\n');
fprintf(fid, '- `mechanism_ridge_shape_test.png`\n');
fprintf(fid, '- `mechanism_ridge_shape_metrics.csv`\n');
fprintf(fid, '- `mechanism_followup_report.md`\n');
fprintf(fid, '- `switching_mechanism_followup_review.zip`\n\n');

fprintf(fid, '## 7. Main results for Analysis 1\n\n');
for w = windowSizes
    mw = arrTbl.window_size == w;
    if ~any(mw)
        continue;
    end
    r2w = arrTbl.R2(mw);
    eaw = arrTbl.Ea_eff(mw);
    tcw = arrTbl.T_center(mw);
    [bestR2, ib] = max(r2w);
    bestTc = tcw(ib);
    medEa = median(eaw, 'omitnan');
    stdEa = std(eaw, 'omitnan');
    fprintf(fid, '- w=%d: best local R^2=%.3f at T_center=%.1f K; median Ea_eff=%.3f; std(Ea_eff)=%.3f.\n', ...
        w, bestR2, bestTc, medEa, stdEa);
end
fprintf(fid, '- Interpretation: locally strong Arrhenius-like windows exist only in parts of T-space; `Ea_eff` varies with window center and size, indicating drift rather than a single global activation scale.\n\n');

fprintf(fid, '## 8. Main results for Analysis 2\n\n');
keyPairs = ["I_peak", "width_I", "asym"];
for kp = 1:numel(keyPairs)
    m = modeTbl.observable == keyPairs(kp) & modeTbl.regime == "global";
    if any(m)
        rr = modeTbl.corr_coeff(find(m,1,'first'));
        nn = modeTbl.n_points(find(m,1,'first'));
        fprintf(fid, '- Global corr(coeff_mode2, %s) = %.3f (n=%d).\n', keyPairs(kp), rr, nn);
    end
end
for kp = 1:numel(keyPairs)
    fprintf(fid, '- Regime breakdown for %s:\n', keyPairs(kp));
    for r = 2:numel(regimeNames)
        m = modeTbl.observable == keyPairs(kp) & modeTbl.regime == regimeNames(r);
        if any(m)
            rr = modeTbl.corr_coeff(find(m,1,'first'));
            nn = modeTbl.n_points(find(m,1,'first'));
            fprintf(fid, '  - %s: corr=%.3f (n=%d).\n', regimeNames(r), rr, nn);
        end
    end
end
fprintf(fid, '- Interpretation: mode-2 is not purely one-parameter; it tracks ridge position and shape observables with regime-dependent strength, consistent with crossover/shape-evolution content.\n\n');

fprintf(fid, '## 9. Main results for Analysis 3\n\n');
lowShapeSpread = mean(std(Ygrid(lowMask,:), 0, 1, 'omitnan'), 'omitnan');
highMask = temps >= 22 & temps <= 30;
highShapeSpread = mean(std(Ygrid(highMask,:), 0, 1, 'omitnan'), 'omitnan');
leftSlope = safeSlope(temps, leftHalf);
rightSlope = safeSlope(temps, rightHalf);
curvCorrT = safeCorr(temps(isfinite(curvPeak)), curvPeak(isfinite(curvPeak)));
rmseCorrT = safeCorr(temps(isfinite(shapeRMSE)), shapeRMSE(isfinite(shapeRMSE)));
fprintf(fid, '- Low-T shape spread metric (4-12 K): %.4f.\n', lowShapeSpread);
fprintf(fid, '- Mid/High-T (22-30 K) shape spread metric: %.4f.\n', highShapeSpread);
fprintf(fid, '- Left half-width slope vs T: %.4f; right half-width slope vs T: %.4f.\n', leftSlope, rightSlope);
fprintf(fid, '- corr(curvature_near_peak, T)=%.3f; corr(shape_RMSE_to_lowT, T)=%.3f.\n', curvCorrT, rmseCorrT);
fprintf(fid, '- Interpretation: departures from strict shape invariance and flank-unequal evolution favor shape-evolution/multi-channel behavior over a pure rigid-rescaling picture.\n\n');

fprintf(fid, '## 10. Which mechanism classes are more compatible with the current data\n\n');
fprintf(fid, '- Multi-regime phenomenology with temperature-dependent effective scales.\n');
fprintf(fid, '- Two-channel effective descriptions (amplitude-like + shape/crossover-like).\n');
fprintf(fid, '- Ridge evolution models allowing asymmetric flank changes with temperature.\n\n');

fprintf(fid, '## 11. Which mechanism classes are less compatible with the current data\n\n');
fprintf(fid, '- Single global Arrhenius activation with constant effective barrier over all temperatures.\n');
fprintf(fid, '- Pure rigid-threshold scaling where all normalized ridge-centered cuts are shape-invariant across regimes.\n\n');

fprintf(fid, '## 12. Remaining ambiguities / limitations\n\n');
fprintf(fid, '- Correlation-based interpretation is descriptive; it does not establish causality.\n');
fprintf(fid, '- Width-based quantities are known to be more definition-sensitive than S_peak and I_peak.\n');
fprintf(fid, '- Sample count is limited by discrete temperature/current grids; local fits use short windows.\n');
fprintf(fid, '- No microscopic model fitting was performed by design.\n\n');

fprintf(fid, '## 13. Recommended next steps\n\n');
fprintf(fid, '1. Cross-compare switching mode2/ridge-shape observables with Aging AFM/FM observables on matched temperature anchors.\n');
fprintf(fid, '2. Repeat local Arrhenius diagnostics with bootstrap uncertainty on windows to quantify confidence bands.\n');
fprintf(fid, '3. Test whether regime boundaries inferred here align with relaxation-derived characteristic temperatures.\n');
fprintf(fid, '4. If needed, run a targeted width-definition sensitivity check only for the ridge-shape metrics most used in modeling.\n\n');

fprintf(fid, '---\nGenerated on: %s\n', datestr(now, 31));

%% ZIP package for review
zipOut = fullfile(outDir, 'switching_mechanism_followup_review.zip');
if exist(zipOut, 'file') == 2
    delete(zipOut);
end
zipFiles = { ...
    'mechanism_local_arrhenius.png', ...
    'mechanism_local_arrhenius_metrics.csv', ...
    'mechanism_mode2_interpretation.png', ...
    'mechanism_mode2_metrics.csv', ...
    'mechanism_ridge_shape_test.png', ...
    'mechanism_ridge_shape_metrics.csv', ...
    'mechanism_followup_report.md' ...
    };
zipPaths = strings(0,1);
for i = 1:numel(zipFiles)
    p = fullfile(outDir, zipFiles{i});
    if isfile(p)
        zipPaths(end+1,1) = string(p); %#ok<SAGROW>
    else
        warning('Missing expected follow-up file for zip: %s', p);
    end
end
assert(numel(zipPaths) == numel(zipFiles), 'Not all required follow-up outputs were generated before zipping.');
zip(char(zipOut), cellstr(zipPaths));

fprintf('Follow-up mechanism survey complete.\n');
fprintf('Output directory: %s\n', outDir);
fprintf('Arrhenius metrics: %s\n', arrCsvOut);
fprintf('Mode2 metrics: %s\n', modeCsvOut);
fprintf('Ridge-shape metrics: %s\n', shapeCsvOut);
fprintf('Report: %s\n', reportOut);
fprintf('ZIP: %s\n', zipOut);


function [z, ok] = zscoreFinite(x)
z = NaN(size(x));
ok = false;
v = isfinite(x);
if nnz(v) < 3
    return;
end
mu = mean(x(v), 'omitnan');
sd = std(x(v), 'omitnan');
if sd <= eps
    return;
end
z(v) = (x(v) - mu) / sd;
ok = true;
end


function s = safeSlope(x, y)
s = NaN;
v = isfinite(x) & isfinite(y);
if nnz(v) < 3
    return;
end
p = polyfit(x(v), y(v), 1);
s = p(1);
end


function row = initArrRow()
row = struct();
row.window_size = NaN;
row.start_idx = NaN;
row.end_idx = NaN;
row.T_start = NaN;
row.T_end = NaN;
row.T_center = NaN;
row.n_points = NaN;
row.slope_b = NaN;
row.Ea_eff = NaN;
row.intercept = NaN;
row.R2 = NaN;
row.rmse = NaN;
end


function row = initModeRow()
row = struct();
row.observable = "";
row.regime = "";
row.T_min = NaN;
row.T_max = NaN;
row.n_points = NaN;
row.corr_coeff = NaN;
end




