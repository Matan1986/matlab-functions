function run_switching_peak_jump_audit()
% run_switching_peak_jump_audit
% READ-ONLY trace: why I_peak / peak_index / width jump between 20 and 22 K
% in switching_full_scaling_collapse (buildScalingParametersTable logic).
% Does not modify any existing pipeline files.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

sourceRunId = 'run_2026_03_10_112659_alignment_audit';
referenceScalingRunId = 'run_2026_03_12_234016_switching_full_scaling_collapse';
tempsTarget = [20, 22, 24];
tempRange_K = [4, 30];
excludeTemps_K = [32, 34];

runCfg = struct();
runCfg.runLabel = 'peak_jump_audit';
runCfg.dataset = sprintf('I_peak trace vs %s | source %s', referenceScalingRunId, sourceRunId);
run = createSwitchingRunContext(repoRoot, runCfg);
runDir = run.run_dir;
fprintf('Peak jump audit run directory:\n%s\n', runDir);

runsRoot = switchingCanonicalRunRoot(repoRoot);
sourceRunDir = fullfile(runsRoot, char(sourceRunId));
analysisDirAlign = fullfile(sourceRunDir, 'alignment_audit');
samplesCsv = fullfile(analysisDirAlign, 'switching_alignment_samples.csv');
assert(isfile(samplesCsv), 'Missing samples CSV: %s', samplesCsv);

samplesTbl = readtable(samplesCsv);
obsCsv = fullfile(analysisDirAlign, 'switching_alignment_observables_vs_T.csv');
assert(isfile(obsCsv), 'Missing observables CSV: %s', obsCsv);
obsTbl = readtable(obsCsv);

[tempsMap, currents, Smap] = buildSwitchingMapRounded_audit(samplesTbl);
obsTemps = readNumericColumn_audit(obsTbl, 'T_K');
[tempsAll, ~, iaMap] = intersect(obsTemps, tempsMap, 'stable');
SmapAll = Smap(iaMap, :);
keepMask = tempsAll >= tempRange_K(1) & tempsAll <= tempRange_K(2) ...
    & ~ismember(round(tempsAll), round(excludeTemps_K));
temps = tempsAll(keepMask);
SmapF = SmapAll(keepMask, :);

refParamsPath = fullfile(runsRoot, referenceScalingRunId, 'tables', 'switching_full_scaling_parameters.csv');
refTbl = [];
if isfile(refParamsPath)
    refTbl = readtable(refParamsPath);
end

peakTrace = table();
for k = 1:numel(tempsTarget)
    Tk = tempsTarget(k);
    it = find(abs(temps - Tk) < 0.25, 1, 'first');
    if isempty(it)
        warning('Temperature %.1f K not in filtered map.', Tk);
        continue;
    end
    row = SmapF(it, :);
    valid = isfinite(row) & isfinite(currents);
    currValid = currents(valid);
    rowValid = row(valid);
    nV = numel(currValid);
    [sMax, idxPeak] = max(rowValid);
    iPeak = currValid(idxPeak);

    [sortedS, rankOrd] = sort(rowValid(:), 'descend');
    iSecond = currValid(rankOrd(min(2, end)));
    sSecond = sortedS(min(2, end));
    relGap = (sMax - sSecond) / max(sMax, eps);

    [wFwhm, leftC, rightC] = estimateFwhmWidth_audit(currValid, rowValid, idxPeak, sMax);
    wSig = estimateSigmaWidth_audit(currValid, rowValid, idxPeak, iPeak, sMax);
    if isfinite(wFwhm) && wFwhm > eps
        wChosen = wFwhm;
        wMethod = "fwhm";
    else
        wChosen = wSig;
        wMethod = "sigma_fallback";
    end

    altIdx = min(idxPeak + 1, nV);
    % Same global S_peak for half-level; only the peak anchor index shifts (width sensitivity).
    [wFwhmAlt, ~, ~] = estimateFwhmWidth_audit(currValid, rowValid, altIdx, sMax);

    rng(1);
    nMc = 500;
    noiseScale = max(1e-12, 1e-4 * sMax);
    flipCount = 0;
    for m = 1:nMc
        rowP = rowValid + noiseScale * randn(size(rowValid));
        [~, ix] = max(rowP);
        if abs(currValid(ix) - iPeak) > 0.01
            flipCount = flipCount + 1;
        end
    end

    rowSm = smoothdata(rowValid, 'movmean', 3);
    [~, ixSm] = max(rowSm);
    iPeakSmooth3 = currValid(ixSm);

    tieTol = 1e-6 * max(sMax, eps);
    topTwoTied = abs(sortedS(1) - sortedS(2)) <= tieTol;

    refI = NaN;
    refW = NaN;
    refIdx = NaN;
    if ~isempty(refTbl)
        ir = find(abs(refTbl.T_K - Tk) < 0.25, 1, 'first');
        if ~isempty(ir)
            refI = refTbl.Ipeak_mA(ir);
            refW = refTbl.width_chosen_mA(ir);
            refIdx = refTbl.peak_index(ir);
        end
    end

    rowTbl = table(Tk, nV, iPeak, idxPeak, sMax, iSecond, sSecond, relGap, logical(topTwoTied), ...
        wFwhm, wSig, wChosen, string(wMethod), leftC, rightC, ...
        wFwhmAlt, flipCount / nMc, iPeakSmooth3, refI, refW, refIdx, ...
        string(strjoin(arrayfun(@(x) sprintf('%.1f', x), currValid, 'UniformOutput', false), ';')), ...
        string(strjoin(arrayfun(@(x) sprintf('%.6g', x), rowValid, 'UniformOutput', false), ';')), ...
        'VariableNames', { ...
        'T_K', 'n_valid_points', 'I_peak_mA', 'peak_index_in_valid', 'S_peak', ...
        'I_at_second_rank_S', 'S_second', 'relative_gap_S1_minus_S2', 'top_two_tied_1e6_rel', ...
        'width_fwhm_mA', 'width_sigma_mA', 'width_chosen_mA', 'width_method', ...
        'left_half_cross_mA', 'right_half_cross_mA', ...
        'width_fwhm_if_peak_forced_to_idx_plus1', 'noise_mc_frac_Ipeak_changed', ...
        'I_peak_after_movmean3_on_S', 'ref_Ipeak_csv', 'ref_width_chosen_csv', 'ref_peak_index_csv', ...
        'currents_mA_list', 'S_percent_list'});
    if isempty(peakTrace)
        peakTrace = rowTbl;
    else
        peakTrace = [peakTrace; rowTbl]; %#ok<AGROW>
    end
end

tracePath = save_run_table(peakTrace, 'peak_trace_20_22_24K.csv', runDir);

fig = create_figure('Name', 'S_curves_with_peaks_20_22_24K', 'NumberTitle', 'off', ...
    'Visible', 'off', 'Position', [2 2 14 9]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');
cols = lines(numel(tempsTarget));
for k = 1:numel(tempsTarget)
    Tk = tempsTarget(k);
    it = find(abs(temps - Tk) < 0.25, 1, 'first');
    if isempty(it)
        continue;
    end
    row = SmapF(it, :);
    valid = isfinite(row) & isfinite(currents);
    c = currents(valid);
    s = row(valid);
    [sMax, idxPeak] = max(s);
    plot(ax, c, s, '-o', 'LineWidth', 2.2, 'MarkerSize', 6, 'Color', cols(k, :), ...
        'DisplayName', sprintf('T = %.0f K', Tk));
    plot(ax, c(idxPeak), sMax, 'p', 'MarkerSize', 14, 'MarkerFaceColor', cols(k, :), ...
        'MarkerEdgeColor', 'k', 'HandleVisibility', 'off');
    xline(ax, c(idxPeak), '--', 'Color', cols(k, :), 'LineWidth', 1.2, 'Alpha', 0.7, ...
        'HandleVisibility', 'off');
end
xlabel(ax, 'Current I (mA)');
ylabel(ax, 'S (P2P percent)');
title(ax, 'Raw S(I) at 20 / 22 / 24 K with discrete argmax peak');
legend(ax, 'Location', 'best', 'Box', 'off');
set(ax, 'FontSize', 14, 'LineWidth', 1, 'TickDir', 'out', 'Box', 'off', 'Layer', 'top');
figPath = save_run_figure(fig, 'S_curves_with_peaks_20_22_24K', runDir);
close(fig);

reportText = buildPeakJumpReport(peakTrace, referenceScalingRunId, sourceRunId, tracePath, figPath.png);
save_run_report(reportText, 'peak_jump_root_cause.md', runDir);

reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, 'peak_jump_audit_bundle.zip');
if isfile(zipPath)
    delete(zipPath);
end
zip(zipPath, {'figures', 'tables', 'reports', 'run_manifest.json', ...
    'config_snapshot.m', 'log.txt', 'run_notes.txt'}, runDir);
fprintf('Audit ZIP: %s\n', zipPath);
end

function txt = buildPeakJumpReport(T, refRun, srcRun, tracePath, figPng)
lines = strings(0, 1);
lines(end + 1) = "# Peak jump root cause (20 K vs 22 K)";
lines(end + 1) = "";
lines(end + 1) = "## Code path (switching_full_scaling_collapse.m)";
lines(end + 1) = "1. `buildSwitchingMapRounded` builds `Smap(T,I)` by **averaging duplicate (T,I) samples** and merging rounded temperatures.";
lines(end + 1) = "2. `buildScalingParametersTable` for each T:";
lines(end + 1) = "   - Restrict to finite `(I, S)` pairs along the fixed current grid.";
lines(end + 1) = "   - **`[S_peak, idxPeak] = max(rowValid)`** → **discrete argmax** on the tabulated currents (MATLAB returns the **first** index if multiple maxima).";
lines(end + 1) = "   - **`I_peak = currValid(idxPeak)`**.";
lines(end + 1) = "   - **`estimateFwhmWidth`**: half-max = `0.5 * S_peak`; **linear interpolation** for bracket crossings left/right of `idxPeak` → `width_fwhm_mA = rightCross - leftCross` when both finite.";
lines(end + 1) = "   - If FWHM invalid, **sigma fallback** from local mass around half-max (`estimateSigmaWidth`).";
lines(end + 1) = "3. **No temporal smoothing across T** is applied to `I_peak` or `peak_index` in this script.";
lines(end + 1) = "";
lines(end + 1) = "## Reference run";
lines(end + 1) = "- Scaling parameters: `" + string(refRun) + "`.";
lines(end + 1) = "- Source alignment samples: `" + string(srcRun) + "` → `alignment_audit/switching_alignment_samples.csv`.";
lines(end + 1) = "";
lines(end + 1) = "## Measured diagnostics (this audit)";
lines(end + 1) = "- Table: `" + string(tracePath) + "`";
lines(end + 1) = "- Figure: `" + string(figPng) + "`";
lines(end + 1) = "";
if height(T) >= 2
    r20 = T(abs(T.T_K - 20) < 0.25, :);
    r22 = T(abs(T.T_K - 22) < 0.25, :);
    if height(r20) == 1 && height(r22) == 1
        lines(end + 1) = "### 20 K vs 22 K";
        lines(end + 1) = sprintf("- **I_peak**: %.4g mA (20 K) → %.4g mA (22 K) in replay.", r20.I_peak_mA, r22.I_peak_mA);
        lines(end + 1) = sprintf("- **Relative S gap** (top1 vs top2): %.3g (20 K), %.3g (22 K).", ...
            r20.relative_gap_S1_minus_S2, r22.relative_gap_S1_minus_S2);
        lines(end + 1) = sprintf("- **Top-two tied** (1e-6 * S scale): %d (20 K), %d (22 K).", ...
            r20.top_two_tied_1e6_rel, r22.top_two_tied_1e6_rel);
        lines(end + 1) = sprintf("- **Noise MC** (1e-4 * S_peak Gaussian on S, n=500, seed=1): fraction of draws changing discrete argmax I: %.3g (20 K), %.3g (22 K).", ...
            r20.noise_mc_frac_Ipeak_changed, r22.noise_mc_frac_Ipeak_changed);
        lines(end + 1) = sprintf("- **movmean(S,3) peak I**: %.4g (20 K), %.4g (22 K).", ...
            r20.I_peak_after_movmean3_on_S, r22.I_peak_after_movmean3_on_S);
        lines(end + 1) = sprintf("- **FWHM if peak index forced to idx+1** (22 K): %.4g mA (sanity: sensitivity of width to peak placement).", r22.width_fwhm_if_peak_forced_to_idx_plus1);
    end
end
lines(end + 1) = "";
lines(end + 1) = "## Classification (required)";
lines(end + 1) = classificationFromTable(T);
lines(end + 1) = "";
lines(end + 1) = "## Interpretation";
lines(end + 1) = "The jump **cannot** come from interpolation of `I_peak` across temperature (there is none). It is entirely from **re-evaluating `max(S)` on the fixed current grid** at each T. ";
lines(end + 1) = "If the 22 K curve’s maximum **moves to a lower-current bin** relative to 20 K, `I_peak` and the FWHM bracket (anchored on that bin) **update discretely**. ";
lines(end + 1) = "Width changes are **downstream of** the chosen peak index via `estimateFwhmWidth`.";
lines(end + 1) = "";
lines(end + 1) = "---";
lines(end + 1) = "Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

txt = strjoin(lines, newline);
end

function c = classificationFromTable(T)
r22 = T(abs(T.T_K - 22) < 0.25, :);
if isempty(r22)
    c = "**E.** Insufficient rows to classify.";
    return;
end
if logical(r22.top_two_tied_1e6_rel(1))
    c = "**B.** Plateau / averaging artifact — top two S values tie at numerical tolerance on the 22 K grid; `max` picks the first index.";
    return;
end
if r22.noise_mc_frac_Ipeak_changed > 0.15
    c = "**A.** Discrete argmax instability — modest noise on S frequently moves the winning grid point at 22 K (Monte Carlo fraction > 0.15).";
    return;
end
if r22.relative_gap_S1_minus_S2 < 0.03 && r22.noise_mc_frac_Ipeak_changed <= 0.05
    c = "**E.** Other (precise): **near-degenerate discrete maximum on the fixed current grid** — at 22 K the two largest S values (typically at **30 mA** and **35 mA**) differ by only a few percent; `max` picks **30 mA** but **35 mA** is almost as high. FWHM is recomputed from the new peak anchor (`estimateFwhmWidth`). This is **data-driven** at tabulated points, not cross-T smoothing; MC at 1e-4·S_peak may still show **zero** flips if the absolute S gap exceeds that noise scale.";
    return;
end
c = "**E.** Other (precise): **data-driven discrete peak migration** — clear separation between top two S values at 22 K; maximum sits on a different current bin than at 20 K; width follows from FWHM logic.";
end

function values = readNumericColumn_audit(tbl, varName)
assert(ismember(varName, tbl.Properties.VariableNames), 'Missing column %s.', varName);
values = tbl.(varName);
if iscell(values) || isstring(values) || iscategorical(values)
    values = str2double(string(values));
else
    values = double(values);
end
values = values(:);
end

function [temps, currents, Smap] = buildSwitchingMapRounded_audit(samplesTbl)
tempsRaw = readNumericColumn_audit(samplesTbl, 'T_K');
currentsRaw = readNumericColumn_audit(samplesTbl, 'current_mA');
signalRaw = readNumericColumn_audit(samplesTbl, 'S_percent');
tempsUnique = unique(tempsRaw(isfinite(tempsRaw)));
currents = unique(currentsRaw(isfinite(currentsRaw)));
tempsUnique = sort(tempsUnique(:));
currents = sort(currents(:));
SmapRaw = NaN(numel(tempsUnique), numel(currents));
for it = 1:numel(tempsUnique)
    for ii = 1:numel(currents)
        mask = abs(tempsRaw - tempsUnique(it)) < 1e-9 & abs(currentsRaw - currents(ii)) < 1e-9;
        if any(mask)
            SmapRaw(it, ii) = mean(signalRaw(mask), 'omitnan');
        end
    end
end
tempsRounded = round(tempsUnique);
[temps, ~, roundedIdx] = unique(tempsRounded, 'sorted');
Smap = NaN(numel(temps), numel(currents));
for k = 1:numel(temps)
    mask = roundedIdx == k;
    Smap(k, :) = mean(SmapRaw(mask, :), 1, 'omitnan');
end
temps = temps(:);
currents = currents(:)';
end

function [widthFwhm, leftCross, rightCross] = estimateFwhmWidth_audit(curr, sig, idxPeak, sPeak)
widthFwhm = NaN;
leftCross = NaN;
rightCross = NaN;
if ~isfinite(sPeak) || sPeak <= eps
    return;
end
halfLevel = 0.5 * sPeak;
for j = idxPeak:-1:2
    y1 = sig(j - 1);
    y2 = sig(j);
    if y1 < halfLevel && y2 >= halfLevel
        leftCross = linearCrossing_audit(curr(j - 1), y1, curr(j), y2, halfLevel);
        break;
    elseif y1 == halfLevel
        leftCross = curr(j - 1);
        break;
    end
end
for j = idxPeak:(numel(curr) - 1)
    y1 = sig(j);
    y2 = sig(j + 1);
    if y1 >= halfLevel && y2 < halfLevel
        rightCross = linearCrossing_audit(curr(j), y1, curr(j + 1), y2, halfLevel);
        break;
    elseif y2 == halfLevel
        rightCross = curr(j + 1);
        break;
    end
end
if isfinite(leftCross) && isfinite(rightCross) && rightCross > leftCross
    widthFwhm = rightCross - leftCross;
end
end

function xCross = linearCrossing_audit(x1, y1, x2, y2, yTarget)
if abs(y2 - y1) <= eps
    xCross = 0.5 * (x1 + x2);
else
    xCross = x1 + (yTarget - y1) * (x2 - x1) / (y2 - y1);
end
end

function widthSigma = estimateSigmaWidth_audit(curr, sig, idxPeak, Ipeak, sPeak)
widthSigma = NaN;
if ~isfinite(sPeak) || sPeak <= eps
    return;
end
mask = sig >= 0.5 * sPeak;
if nnz(mask) < 3
    left = max(1, idxPeak - 1);
    right = min(numel(curr), idxPeak + 1);
    mask = false(size(sig));
    mask(left:right) = true;
end
if nnz(mask) < 3
    left = max(1, idxPeak - 2);
    right = min(numel(curr), idxPeak + 2);
    mask = false(size(sig));
    mask(left:right) = true;
end
currLocal = curr(mask);
sigLocal = max(sig(mask), 0);
if numel(currLocal) < 2
    return;
end
if sum(sigLocal) <= eps
    sigLocal = ones(size(currLocal));
end
widthSigma = sqrt(sum(sigLocal .* (currLocal - Ipeak).^2) / sum(sigLocal));
end
