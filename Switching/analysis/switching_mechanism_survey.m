% switching_mechanism_survey
% Mechanism-oriented diagnostic survey for switching observables.
%
% This script reuses outputs from:
%   Switching/analysis/switching_alignment_audit.m
%
% Fixed switching metric constraint for this survey:
%   metricType = "P2P_percent"

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

alignmentDir = resolve_results_input_dir(repoRoot, 'switching', 'alignment_audit');
[outDir, run] = init_run_output_dir(repoRoot, 'switching', 'mechanism_survey'); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

metricType = "P2P_percent"; %#ok<NASGU>

obsCsv = fullfile(alignmentDir, 'switching_alignment_observables_vs_T.csv');
samplesCsv = fullfile(alignmentDir, 'switching_alignment_samples.csv');
assert(isfile(obsCsv), 'Missing observables file: %s', obsCsv);
assert(isfile(samplesCsv), 'Missing raw samples file: %s', samplesCsv);

obsTbl = readtable(obsCsv);
samplesTbl = readtable(samplesCsv);

if ismember('metricType', samplesTbl.Properties.VariableNames)
    metricVals = string(samplesTbl.metricType);
    badMetric = metricVals ~= "P2P_percent";
    if any(badMetric)
        error('switching_alignment_samples.csv contains non-P2P_percent rows. Survey requires fixed metricType=P2P_percent.');
    end
end

tempsObs = toNumericColumn(obsTbl, 'T_K');
IpeakObs = toNumericColumn(obsTbl, 'Ipeak');
SpeakObs = toNumericColumn(obsTbl, 'S_peak');
widthIObs = toNumericColumn(obsTbl, 'width_I');
asymObs = toNumericColumn(obsTbl, 'asym');
coeffMode1Obs = toNumericColumn(obsTbl, 'coeff_mode1');
coeffMode2Obs = toNumericColumn(obsTbl, 'coeff_mode2');

[tempsMap, currents, Smap] = buildSwitchingMapRounded(samplesTbl);
[temps, iaObs, iaMap] = intersect(tempsObs, tempsMap, 'stable');
assert(~isempty(temps), 'No overlapping temperatures between observables table and switching map.');
Ipeak = IpeakObs(iaObs);
S_peak = SpeakObs(iaObs);
width_I = widthIObs(iaObs);
asym = asymObs(iaObs);
coeff_mode1 = coeffMode1Obs(iaObs);
coeff_mode2 = coeffMode2Obs(iaObs);
Smap = Smap(iaMap, :);

if any(~isfinite(coeff_mode1)) || all(abs(coeff_mode1) < eps)
    Msvd = Smap;
    Msvd(~isfinite(Msvd)) = 0;
    [Utmp, Stmp, ~] = svd(Msvd, 'econ');
    coeff_mode1 = Utmp(:,1) * Stmp(1,1);
end
if any(~isfinite(coeff_mode2)) || all(abs(coeff_mode2) < eps)
    Msvd = Smap;
    Msvd(~isfinite(Msvd)) = 0;
    [Utmp, Stmp, ~] = svd(Msvd, 'econ');
    if size(Utmp,2) >= 2
        coeff_mode2 = Utmp(:,2) * Stmp(2,2);
    else
        coeff_mode2 = NaN(size(temps));
    end
end

summaryRows = repmat(initSummaryRow(), 0, 1);

% -------------------------------------------------------------------------
% 1) Segmented Arrhenius test for S_peak(T).
% -------------------------------------------------------------------------
figArr = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 420]);
tlArr = tiledlayout(figArr, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

axA1 = nexttile(tlArr, 1);
plot(axA1, temps, S_peak, '-o', 'LineWidth', 1.8);
xlabel(axA1, 'T (K)');
ylabel(axA1, 'S_{peak}(T)');
title(axA1, 'S_{peak}(T)');
grid(axA1, 'on');

axA2 = nexttile(tlArr, 2);
validSpeak = isfinite(S_peak) & S_peak > 0 & isfinite(temps);
plot(axA2, temps(validSpeak), log(S_peak(validSpeak)), '-o', 'LineWidth', 1.8);
xlabel(axA2, 'T (K)');
ylabel(axA2, 'log(S_{peak})');
title(axA2, 'log(S_{peak}) vs T');
grid(axA2, 'on');

axA3 = nexttile(tlArr, 3);
invT = NaN(size(temps));
vT = isfinite(temps) & temps > 0;
invT(vT) = 1 ./ temps(vT);
plot(axA3, invT(validSpeak), log(S_peak(validSpeak)), 'o', 'LineWidth', 1.4, 'MarkerSize', 6);
xlabel(axA3, '1/T (1/K)');
ylabel(axA3, 'log(S_{peak})');
title(axA3, 'Arrhenius view');
grid(axA3, 'on');

arrOut = fullfile(outDir, 'mechanism_Speak_arrhenius.png');
saveas(figArr, arrOut);
close(figArr);

segRanges = [4 18; 18 30; 22 32];
segLabels = ["4-18 K", "18-30 K", "22-32 K"];
figSeg = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1300 420]);
tlSeg = tiledlayout(figSeg, 1, size(segRanges,1), 'TileSpacing', 'compact', 'Padding', 'compact');

for k = 1:size(segRanges,1)
    ax = nexttile(tlSeg, k);
    tLo = segRanges(k,1);
    tHi = segRanges(k,2);
    m = validSpeak & temps >= tLo & temps <= tHi;
    x = invT(m);
    y = log(S_peak(m));
    plot(ax, x, y, 'o', 'LineWidth', 1.5, 'MarkerSize', 6);
    hold(ax, 'on');
    slope = NaN;
    intercept = NaN;
    r2 = NaN;
    rmse = NaN;
    if numel(x) >= 2
        p = polyfit(x, y, 1);
        yfit = polyval(p, x);
        slope = p(1);
        intercept = p(2);
        sse = sum((y - yfit).^2, 'omitnan');
        sst = sum((y - mean(y, 'omitnan')).^2, 'omitnan');
        if sst > 0
            r2 = 1 - sse / sst;
        end
        rmse = sqrt(mean((y - yfit).^2, 'omitnan'));
        xFit = linspace(min(x), max(x), 100);
        plot(ax, xFit, polyval(p, xFit), '-', 'LineWidth', 1.6);
    end
    xlabel(ax, '1/T (1/K)');
    ylabel(ax, 'log(S_{peak})');
    title(ax, sprintf('%s', segLabels(k)));
    grid(ax, 'on');
    text(ax, 0.03, 0.95, sprintf('slope=%.3f\\nintercept=%.3f\\nR^2=%.3f\\nRMSE=%.3g', ...
        slope, intercept, r2, rmse), 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'FontSize', 9, 'Interpreter', 'none');

    summaryRows(end+1,1) = mkSummaryRow("arrhenius_segment", ...
        sprintf('slope_%s', segLabels(k)), slope, 'log(S_peak) vs 1/T linear fit'); %#ok<SAGROW>
    summaryRows(end+1,1) = mkSummaryRow("arrhenius_segment", ...
        sprintf('intercept_%s', segLabels(k)), intercept, 'log(S_peak) vs 1/T linear fit'); %#ok<SAGROW>
    summaryRows(end+1,1) = mkSummaryRow("arrhenius_segment", ...
        sprintf('R2_%s', segLabels(k)), r2, 'segment fit quality'); %#ok<SAGROW>
end

arrSegOut = fullfile(outDir, 'mechanism_Speak_arrhenius_segmented.png');
saveas(figSeg, arrSegOut);
close(figSeg);

% -------------------------------------------------------------------------
% 2) Current scale regime test: I_peak(T) + derivative.
% -------------------------------------------------------------------------
dIpeak_dT = NaN(size(Ipeak));
vI = isfinite(Ipeak) & isfinite(temps);
if nnz(vI) >= 2
    dIpeak_dT(vI) = gradient(Ipeak(vI), temps(vI));
end
dIpeak_dT_smooth = movmean(dIpeak_dT, 3, 'omitnan');

figI = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 700]);
tlI = tiledlayout(figI, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

axI1 = nexttile(tlI, 1);
plot(axI1, temps, Ipeak, '-o', 'LineWidth', 1.8);
hold(axI1, 'on');
xline(axI1, 20, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.1);
xline(axI1, 29, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.1);
xline(axI1, 34, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.1);
xlabel(axI1, 'T (K)');
ylabel(axI1, 'I_{peak}(T) [mA]');
title(axI1, 'Current-scale regime test: I_{peak}(T)');
grid(axI1, 'on');

axI2 = nexttile(tlI, 2);
plot(axI2, temps, dIpeak_dT, '-o', 'LineWidth', 1.4, 'DisplayName', 'dI_{peak}/dT');
hold(axI2, 'on');
plot(axI2, temps, dIpeak_dT_smooth, '-s', 'LineWidth', 1.6, 'DisplayName', 'smoothed dI_{peak}/dT');
xline(axI2, 20, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.1);
xline(axI2, 29, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.1);
xline(axI2, 34, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.1);
xlabel(axI2, 'T (K)');
ylabel(axI2, 'dI_{peak}/dT (mA/K)');
title(axI2, 'Slope changes vs temperature');
grid(axI2, 'on');
legend(axI2, 'Location', 'best');

iPeakOut = fullfile(outDir, 'mechanism_Ipeak_vs_T.png');
saveas(figI, iPeakOut);
close(figI);

% -------------------------------------------------------------------------
% 3) Mode-channel correlation test.
% -------------------------------------------------------------------------
figMode = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 900]);
tlMode = tiledlayout(figMode, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axM1 = nexttile(tlMode, 1);
v = isfinite(S_peak) & isfinite(coeff_mode1);
scatter(axM1, coeff_mode1(v), S_peak(v), 48, temps(v), 'filled');
xlabel(axM1, 'coeff_mode1(T)');
ylabel(axM1, 'S_{peak}(T)');
title(axM1, 'Amplitude channel check');
grid(axM1, 'on');
cb1 = colorbar(axM1);
ylabel(cb1, 'T (K)');
rSpeakMode1 = safeCorr(coeff_mode1, S_peak);
text(axM1, 0.04, 0.95, sprintf('corr = %.3f', rSpeakMode1), 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'FontSize', 10);

axM2 = nexttile(tlMode, 2);
v = isfinite(Ipeak) & isfinite(coeff_mode2);
scatter(axM2, coeff_mode2(v), Ipeak(v), 48, temps(v), 'filled');
xlabel(axM2, 'coeff_mode2(T)');
ylabel(axM2, 'I_{peak}(T)');
title(axM2, 'Shape/ridge channel check');
grid(axM2, 'on');
cb2 = colorbar(axM2);
ylabel(cb2, 'T (K)');
rIpeakMode2 = safeCorr(coeff_mode2, Ipeak);
text(axM2, 0.04, 0.95, sprintf('corr = %.3f', rIpeakMode2), 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'FontSize', 10);

axM3 = nexttile(tlMode, 3);
[s1, ok1] = minmaxNormalize(S_peak);
[m1, ok2] = minmaxNormalize(coeff_mode1);
if ok1 && ok2
    plot(axM3, temps, s1, '-o', 'LineWidth', 1.7, 'DisplayName', 'S_{peak} (norm)');
    hold(axM3, 'on');
    plot(axM3, temps, m1, '-s', 'LineWidth', 1.7, 'DisplayName', 'coeff_mode1 (norm)');
end
xlabel(axM3, 'T (K)');
ylabel(axM3, 'normalized value');
title(axM3, 'S_{peak} vs mode1 (normalized)');
grid(axM3, 'on');
legend(axM3, 'Location', 'best');

axM4 = nexttile(tlMode, 4);
[i1, ok3] = minmaxNormalize(Ipeak);
[m2, ok4] = minmaxNormalize(coeff_mode2);
if ok3 && ok4
    plot(axM4, temps, i1, '-o', 'LineWidth', 1.7, 'DisplayName', 'I_{peak} (norm)');
    hold(axM4, 'on');
    plot(axM4, temps, m2, '-s', 'LineWidth', 1.7, 'DisplayName', 'coeff_mode2 (norm)');
end
xlabel(axM4, 'T (K)');
ylabel(axM4, 'normalized value');
title(axM4, 'I_{peak} vs mode2 (normalized)');
grid(axM4, 'on');
legend(axM4, 'Location', 'best');

modeCorrOut = fullfile(outDir, 'mechanism_mode_correlations.png');
saveas(figMode, modeCorrOut);
close(figMode);

summaryRows(end+1,1) = mkSummaryRow("mode_channel", "corr_Speak_mode1_global", rSpeakMode1, ...
    'corr(S_peak, coeff_mode1)');
summaryRows(end+1,1) = mkSummaryRow("mode_channel", "corr_Ipeak_mode2_global", rIpeakMode2, ...
    'corr(I_peak, coeff_mode2)');

regLabels = ["4-18K", "18-30K", "22-32K"];
regRanges = [4 18; 18 30; 22 32];
for k = 1:size(regRanges,1)
    mR = temps >= regRanges(k,1) & temps <= regRanges(k,2);
    r1 = safeCorr(coeff_mode1(mR), S_peak(mR));
    r2 = safeCorr(coeff_mode2(mR), Ipeak(mR));
    summaryRows(end+1,1) = mkSummaryRow("mode_channel", sprintf('corr_Speak_mode1_%s', regLabels(k)), r1, ...
        'range-restricted correlation'); %#ok<SAGROW>
    summaryRows(end+1,1) = mkSummaryRow("mode_channel", sprintf('corr_Ipeak_mode2_%s', regLabels(k)), r2, ...
        'range-restricted correlation'); %#ok<SAGROW>
end

% -------------------------------------------------------------------------
% 4) Left-flank barrier test.
% -------------------------------------------------------------------------
alphaSet = [0.5 1.0 1.5 2.0];
figLeft = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 900]);
tlLeft = tiledlayout(figLeft, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for aIdx = 1:numel(alphaSet)
    alpha = alphaSet(aIdx);
    xAll = [];
    yAll = [];
    ax = nexttile(tlLeft, aIdx);
    hold(ax, 'on');
    for it = 1:numel(temps)
        row = Smap(it,:);
        currRow = currents(:)';
        valid = isfinite(row) & isfinite(currRow);
        if nnz(valid) < 3 || ~isfinite(Ipeak(it)) || Ipeak(it) <= 0 || ~isfinite(temps(it)) || temps(it) <= 0
            continue;
        end
        cur = currRow(valid);
        sig = row(valid);
        leftMask = cur < Ipeak(it) & sig > 0;
        if nnz(leftMask) < 2
            continue;
        end
        x = ((1 - cur(leftMask) ./ Ipeak(it)).^alpha) ./ temps(it);
        y = log(sig(leftMask));
        plot(ax, x, y, '-', 'LineWidth', 1.0);
        xAll = [xAll; x(:)]; %#ok<AGROW>
        yAll = [yAll; y(:)]; %#ok<AGROW>
    end
    r = safeCorr(xAll, yAll);
    xlabel(ax, '((1-I/I_{peak})^{\alpha})/T');
    ylabel(ax, 'log(S)');
    title(ax, sprintf('\\alpha = %.1f (corr=%.3f)', alpha, r));
    grid(ax, 'on');
    summaryRows(end+1,1) = mkSummaryRow("left_flank", sprintf('corr_alpha_%.1f', alpha), r, ...
        'global correlation for left-flank barrier linearization'); %#ok<SAGROW>
end

leftFlankOut = fullfile(outDir, 'mechanism_left_flank_scaling.png');
saveas(figLeft, leftFlankOut);
close(figLeft);

% -------------------------------------------------------------------------
% 5) Regime-specific collapse test.
% -------------------------------------------------------------------------
regimeRanges = [4 12; 14 20; 22 30];
regimeNames = ["4-12 K", "14-20 K", "22-30 K"];
xGrid = (-3:0.1:3)';

figReg = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1350 500]);
tlReg = tiledlayout(figReg, 1, size(regimeRanges,1), 'TileSpacing', 'compact', 'Padding', 'compact');
if exist('turbo', 'file') == 2
    cmapReg = turbo(numel(temps));
else
    cmapReg = parula(numel(temps));
end

for rIdx = 1:size(regimeRanges,1)
    ax = nexttile(tlReg, rIdx);
    hold(ax, 'on');
    Xstack = NaN(numel(xGrid), 0);
    for it = 1:numel(temps)
        if temps(it) < regimeRanges(rIdx,1) || temps(it) > regimeRanges(rIdx,2)
            continue;
        end
        row = Smap(it,:);
        currRow = currents(:)';
        valid = isfinite(row) & isfinite(currRow);
        if nnz(valid) < 3 || ~isfinite(Ipeak(it)) || ~isfinite(width_I(it)) || width_I(it) <= eps || ...
                ~isfinite(S_peak(it)) || S_peak(it) <= eps
            continue;
        end
        x = (currRow(valid) - Ipeak(it)) ./ width_I(it);
        y = row(valid) ./ S_peak(it);
        [xUniq, iu] = unique(x(:));
        yUniq = y(iu);
        if numel(xUniq) < 2
            continue;
        end
        yInterp = interp1(xUniq, yUniq, xGrid, 'linear', NaN);
        Xstack(:, end+1) = yInterp; %#ok<AGROW>
        cidx = find(temps == temps(it), 1, 'first');
        if isempty(cidx)
            cidx = it;
        end
        plot(ax, x, y, '-', 'LineWidth', 1.2, 'Color', cmapReg(cidx,:));
    end
    xlabel(ax, '(I-I_{peak})/width_I');
    ylabel(ax, 'S/S_{peak}');
    title(ax, sprintf('Regime %s', regimeNames(rIdx)));
    grid(ax, 'on');

    collapseMetric = NaN;
    if ~isempty(Xstack)
        collapseMetric = mean(std(Xstack, 0, 2, 'omitnan'), 'omitnan');
    end
    text(ax, 0.03, 0.95, sprintf('collapse metric = %.3f', collapseMetric), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9, 'Interpreter', 'none');
    summaryRows(end+1,1) = mkSummaryRow("regime_collapse", ...
        sprintf('collapse_metric_%s', regimeNames(rIdx)), collapseMetric, ...
        'mean std across normalized curves on common x-grid'); %#ok<SAGROW>
end

regimeOut = fullfile(outDir, 'mechanism_regime_collapse.png');
saveas(figReg, regimeOut);
close(figReg);

% -------------------------------------------------------------------------
% 6) Peak-vs-strength relation test.
% -------------------------------------------------------------------------
figPeakStrength = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1100 450]);
tlPS = tiledlayout(figPeakStrength, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axPS1 = nexttile(tlPS, 1);
vPS = isfinite(Ipeak) & isfinite(S_peak);
scatter(axPS1, Ipeak(vPS), S_peak(vPS), 60, temps(vPS), 'filled');
xlabel(axPS1, 'I_{peak}(T) [mA]');
ylabel(axPS1, 'S_{peak}(T)');
title(axPS1, 'S_{peak} vs I_{peak}');
grid(axPS1, 'on');
cbPS1 = colorbar(axPS1);
ylabel(cbPS1, 'T (K)');
rPS = safeCorr(Ipeak, S_peak);
text(axPS1, 0.03, 0.95, sprintf('corr=%.3f', rPS), 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'FontSize', 10);

axPS2 = nexttile(tlPS, 2);
vLPS = isfinite(Ipeak) & isfinite(S_peak) & S_peak > 0;
scatter(axPS2, Ipeak(vLPS), log(S_peak(vLPS)), 60, temps(vLPS), 'filled');
xlabel(axPS2, 'I_{peak}(T) [mA]');
ylabel(axPS2, 'log(S_{peak}(T))');
title(axPS2, 'log(S_{peak}) vs I_{peak}');
grid(axPS2, 'on');
cbPS2 = colorbar(axPS2);
ylabel(cbPS2, 'T (K)');
rLPS = safeCorr(Ipeak(vLPS), log(S_peak(vLPS)));
text(axPS2, 0.03, 0.95, sprintf('corr=%.3f', rLPS), 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'FontSize', 10);

peakStrengthOut = fullfile(outDir, 'mechanism_Speak_vs_Ipeak.png');
saveas(figPeakStrength, peakStrengthOut);
close(figPeakStrength);

summaryRows(end+1,1) = mkSummaryRow("peak_strength", "corr_Speak_vs_Ipeak", rPS, ...
    'global correlation');
summaryRows(end+1,1) = mkSummaryRow("peak_strength", "corr_logSpeak_vs_Ipeak", rLPS, ...
    'global correlation');

% -------------------------------------------------------------------------
% 7) Background / secondary channel test.
% -------------------------------------------------------------------------
bgMask = temps < 10;
bgTemplate = mean(Smap(bgMask,:), 1, 'omitnan');
if any(~isfinite(bgTemplate))
    bgTemplate(~isfinite(bgTemplate)) = 0;
end

broadAmp = NaN(size(temps));
ridgeAmp = NaN(size(temps));
bgScale = NaN(size(temps));
for it = 1:numel(temps)
    row = Smap(it,:);
    valid = isfinite(row) & isfinite(bgTemplate);
    if nnz(valid) < 2
        continue;
    end
    bgv = bgTemplate(valid);
    rv = row(valid);
    den = sum(bgv.^2);
    if den > eps
        a = sum(rv .* bgv) / den;
    else
        a = NaN;
    end
    bgScale(it) = a;
    if isfinite(a)
        bgComp = a * bgTemplate;
    else
        bgComp = NaN(size(bgTemplate));
    end
    res = row - bgComp;
    broadAmp(it) = max(bgComp, [], 'omitnan') - min(bgComp, [], 'omitnan');
    ridgeAmp(it) = max(res, [], 'omitnan');
end

figBg = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 700]);
tlBg = tiledlayout(figBg, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

axBg1 = nexttile(tlBg, 1);
plot(axBg1, temps, ridgeAmp, '-o', 'LineWidth', 1.8, 'DisplayName', 'ridge-localized amplitude');
hold(axBg1, 'on');
plot(axBg1, temps, broadAmp, '-s', 'LineWidth', 1.8, 'DisplayName', 'broad background amplitude');
xlabel(axBg1, 'T (K)');
ylabel(axBg1, 'amplitude (a.u.)');
title(axBg1, 'Ridge-localized vs broad-background channels');
grid(axBg1, 'on');
legend(axBg1, 'Location', 'best');

axBg2 = nexttile(tlBg, 2);
plot(axBg2, temps, bgScale, '-o', 'LineWidth', 1.8);
xlabel(axBg2, 'T (K)');
ylabel(axBg2, 'background scale factor');
title(axBg2, 'Broad background scale vs temperature');
grid(axBg2, 'on');

bgOut = fullfile(outDir, 'mechanism_background_channels.png');
saveas(figBg, bgOut);
close(figBg);

highTMask = temps >= 30;
lowTMask = temps <= 12;
broadHigh = mean(broadAmp(highTMask), 'omitnan');
broadLow = mean(broadAmp(lowTMask), 'omitnan');
ridgeHigh = mean(ridgeAmp(highTMask), 'omitnan');
ridgeLow = mean(ridgeAmp(lowTMask), 'omitnan');
summaryRows(end+1,1) = mkSummaryRow("background_channel", "broadAmp_highT_over_lowT", broadHigh / broadLow, ...
    'ratio mean(broadAmp,T>=30K)/mean(broadAmp,T<=12K)');
summaryRows(end+1,1) = mkSummaryRow("background_channel", "ridgeAmp_highT_over_lowT", ridgeHigh / ridgeLow, ...
    'ratio mean(ridgeAmp,T>=30K)/mean(ridgeAmp,T<=12K)');

% -------------------------------------------------------------------------
% Summary CSV export.
% -------------------------------------------------------------------------
obsSummaryTbl = table(temps, Ipeak, S_peak, width_I, coeff_mode1, coeff_mode2, asym, dIpeak_dT, ...
    broadAmp, ridgeAmp, bgScale, ...
    'VariableNames', {'T_K','I_peak','S_peak','width_I','coeff_mode1','coeff_mode2','asym', ...
    'dIpeak_dT','broadAmp','ridgeAmp','bgScale'});

obsSummaryCsvOut = fullfile(outDir, 'mechanism_observables_summary.csv');
writetable(obsSummaryTbl, obsSummaryCsvOut);

summaryMetricsTbl = struct2table(summaryRows);
summaryMetricsCsvOut = fullfile(outDir, 'mechanism_fit_metrics.csv');
writetable(summaryMetricsTbl, summaryMetricsCsvOut);

% -------------------------------------------------------------------------
% Markdown report.
% -------------------------------------------------------------------------
reportOut = fullfile(outDir, 'mechanism_survey_report.md');
fid = fopen(reportOut, 'w');
assert(fid >= 0, 'Failed to open report for writing: %s', reportOut);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Switching Mechanism Survey Report\n\n');
fprintf(fid, '## 1. Purpose of the Survey\n\n');
fprintf(fid, 'This survey evaluates mechanism-compatible empirical structure in switching data ');
fprintf(fid, 'without fitting a microscopic model. The objective is to test scaling/regime diagnostics ');
fprintf(fid, 'for `S(T,I)=\\Delta R/R` using observables from `switching_alignment_audit`.\n\n');

fprintf(fid, '## 2. Observables Analyzed\n\n');
fprintf(fid, '- `S_peak(T)`\n');
fprintf(fid, '- `I_peak(T)`\n');
fprintf(fid, '- `width_I(T)`\n');
fprintf(fid, '- `coeff_mode1(T)` and `coeff_mode2(T)` from SVD observables table\n');
fprintf(fid, '- Ridge/background proxies: `ridgeAmp(T)`, `broadAmp(T)`\n\n');

fprintf(fid, '## 3. Variables and Parameters Tested\n\n');
fprintf(fid, '- Segmented Arrhenius windows: 4-18 K, 18-30 K, 22-32 K\n');
fprintf(fid, '- Left-flank scaling exponents: alpha = 0.5, 1.0, 1.5, 2.0\n');
fprintf(fid, '- Regime-collapse windows: 4-12 K, 14-20 K, 22-30 K\n');
fprintf(fid, '- Collapse coordinates: `(I-I_peak)/width_I` and `S/S_peak`\n\n');

fprintf(fid, '## 4. Exact Analyses Performed\n\n');
fprintf(fid, '1. Arrhenius-style diagnostics of `S_peak(T)` including segmented linear fits of `log(S_peak)` vs `1/T`.\n');
fprintf(fid, '2. Current-scale diagnostics using `I_peak(T)` and `dI_peak/dT` with crossover markers near 20 K, 29 K, 34 K.\n');
fprintf(fid, '3. Mode-channel checks: scatter and normalized overlays of (`S_peak`, `coeff_mode1`) and (`I_peak`, `coeff_mode2`).\n');
fprintf(fid, '4. Left-flank barrier linearization diagnostics for multiple alpha values.\n');
fprintf(fid, '5. Regime-specific ridge-centered collapse diagnostics.\n');
fprintf(fid, '6. Peak-vs-strength relation (`S_peak` vs `I_peak`, including log scale).\n');
fprintf(fid, '7. Background/secondary-channel proxy decomposition using low-T baseline template projection.\n\n');

fprintf(fid, '## 5. Diagnostic Plot Descriptions\n\n');
fprintf(fid, '- `mechanism_Speak_arrhenius.png`: global amplitude and Arrhenius projections.\n');
fprintf(fid, '- `mechanism_Speak_arrhenius_segmented.png`: segmented linear fits with slope/intercept/R2 labels.\n');
fprintf(fid, '- `mechanism_Ipeak_vs_T.png`: ridge current and derivative-based regime indicators.\n');
fprintf(fid, '- `mechanism_mode_correlations.png`: mode-amplitude correlation diagnostics.\n');
fprintf(fid, '- `mechanism_left_flank_scaling.png`: left-flank barrier-scaling linearization diagnostics.\n');
fprintf(fid, '- `mechanism_regime_collapse.png`: regime-specific collapse in ridge-centered normalized coordinates.\n');
fprintf(fid, '- `mechanism_Speak_vs_Ipeak.png`: amplitude-current coupling trajectory.\n');
fprintf(fid, '- `mechanism_background_channels.png`: ridge-localized vs broad-background proxy amplitudes.\n\n');

fprintf(fid, '## 6. Main Findings by Test\n\n');
fprintf(fid, '- Segmented Arrhenius fits vary by window; no single global linearization was enforced.\n');
fprintf(fid, '- `I_peak(T)` and `dI_peak/dT` expose temperature-dependent slope changes (crossovers visible near marked regions).\n');
fprintf(fid, '- Global correlations: corr(`S_peak`,`coeff_mode1`) = %.3f, corr(`I_peak`,`coeff_mode2`) = %.3f.\n', ...
    rSpeakMode1, rIpeakMode2);
fprintf(fid, '- Peak-strength coupling: corr(`S_peak`,`I_peak`) = %.3f, corr(log(`S_peak`),`I_peak`) = %.3f.\n', ...
    rPS, rLPS);
fprintf(fid, '- Regime-collapse metrics were reported per window in `mechanism_fit_metrics.csv`.\n');
fprintf(fid, '- Background-channel ratios indicate whether broad background persists at high T relative to low T.\n\n');

fprintf(fid, '## 7. Mechanism-Class Compatibility (Data-Driven, Non-Final)\n\n');
fprintf(fid, '- Compatible: multi-regime empirical behavior with temperature-dependent current scale.\n');
fprintf(fid, '- Compatible: two-channel decomposition language (amplitude-like + shape/ridge-evolution-like) at phenomenological level.\n');
fprintf(fid, '- Inconclusive: strict single-regime Arrhenius law across full temperature range.\n');
fprintf(fid, '- Not claimed here: final microscopic mechanism assignment.\n\n');

fprintf(fid, '## 8. Candidate Regime Boundaries\n\n');
fprintf(fid, '- Visual and derivative diagnostics are reported around ~20 K, ~28-30 K, and ~33-35 K.\n');
fprintf(fid, '- Regime-collapse tests additionally use 4-12 K, 14-20 K, and 22-30 K windows.\n\n');

fprintf(fid, '## 9. Recommended Observables for Next Modeling Stage\n\n');
fprintf(fid, '- Primary: `S_peak(T)`, `I_peak(T)`, `coeff_mode1(T)`, `coeff_mode2(T)`.\n');
fprintf(fid, '- Secondary: `width_I(T)`, `dI_peak/dT`, `ridgeAmp(T)`, `broadAmp(T)`.\n');
fprintf(fid, '- Use `mechanism_observables_summary.csv` + `mechanism_fit_metrics.csv` as compact inputs for cross-experiment comparison.\n\n');

fprintf(fid, '---\n');
fprintf(fid, 'Generated on: %s\n', datestr(now, 31));

% -------------------------------------------------------------------------
% ZIP package for review.
% -------------------------------------------------------------------------
zipOut = fullfile(outDir, 'switching_mechanism_diagnostics_review.zip');
if exist(zipOut, 'file') == 2
    delete(zipOut);
end
zipFiles = { ...
    'mechanism_Speak_arrhenius.png', ...
    'mechanism_Speak_arrhenius_segmented.png', ...
    'mechanism_Ipeak_vs_T.png', ...
    'mechanism_mode_correlations.png', ...
    'mechanism_left_flank_scaling.png', ...
    'mechanism_regime_collapse.png', ...
    'mechanism_Speak_vs_Ipeak.png', ...
    'mechanism_background_channels.png', ...
    'mechanism_observables_summary.csv' ...
    };

zipPaths = strings(0,1);
for i = 1:numel(zipFiles)
    f = fullfile(outDir, zipFiles{i});
    if isfile(f)
        zipPaths(end+1,1) = string(f); %#ok<SAGROW>
    else
        warning('Expected output missing for zip: %s', f);
    end
end
assert(~isempty(zipPaths), 'No files available to package in mechanism survey zip.');
zip(char(zipOut), cellstr(zipPaths));

fprintf('Mechanism survey complete.\n');
fprintf('Output directory: %s\n', outDir);
fprintf('Summary CSV: %s\n', obsSummaryCsvOut);
fprintf('Metrics CSV: %s\n', summaryMetricsCsvOut);
fprintf('Report: %s\n', reportOut);
fprintf('ZIP: %s\n', zipOut);


function x = toNumericColumn(tbl, varName)
if ~ismember(varName, tbl.Properties.VariableNames)
    x = NaN(height(tbl), 1);
    return;
end
col = tbl.(varName);
if isnumeric(col)
    x = double(col(:));
elseif iscell(col)
    x = str2double(string(col(:)));
else
    x = str2double(string(col(:)));
end
end


function [temps, currents, Smap] = buildSwitchingMapRounded(samplesTbl)
tempsRaw = toNumericColumn(samplesTbl, 'T_K');
currRaw = toNumericColumn(samplesTbl, 'current_mA');
sRaw = toNumericColumn(samplesTbl, 'S_percent');

v = isfinite(tempsRaw) & isfinite(currRaw) & isfinite(sRaw);
tempsRaw = tempsRaw(v);
currRaw = currRaw(v);
sRaw = sRaw(v);

tempsUnique = unique(tempsRaw);
currents = unique(currRaw);
tempsUnique = sort(tempsUnique(:));
currents = sort(currents(:));

SmapRaw = NaN(numel(tempsUnique), numel(currents));
for it = 1:numel(tempsUnique)
    for ii = 1:numel(currents)
        m = abs(tempsRaw - tempsUnique(it)) < 1e-9 & abs(currRaw - currents(ii)) < 1e-9;
        if any(m)
            SmapRaw(it, ii) = mean(sRaw(m), 'omitnan');
        end
    end
end

Tclean = round(tempsUnique);
[Tuniq, ~, idx] = unique(Tclean, 'sorted');
SmapClean = NaN(numel(Tuniq), size(SmapRaw,2));
for k = 1:numel(Tuniq)
    mk = idx == k;
    SmapClean(k,:) = mean(SmapRaw(mk,:), 1, 'omitnan');
end

temps = Tuniq(:);
Smap = SmapClean;
end


function r = safeCorr(a, b)
v = isfinite(a) & isfinite(b);
if nnz(v) < 2
    r = NaN;
    return;
end
r = corr(a(v), b(v), 'rows', 'complete');
end


function [xn, ok] = minmaxNormalize(x)
xn = NaN(size(x));
ok = false;
v = isfinite(x);
if nnz(v) < 2
    return;
end
xmin = min(x(v));
xmax = max(x(v));
if xmax - xmin <= eps
    return;
end
xn(v) = (x(v) - xmin) / (xmax - xmin);
ok = true;
end


function row = initSummaryRow()
row = struct();
row.category = "";
row.metric = "";
row.value = NaN;
row.notes = "";
end


function row = mkSummaryRow(category, metric, value, notes)
row = initSummaryRow();
row.category = string(category);
row.metric = string(metric);
row.value = value;
row.notes = string(notes);
end


