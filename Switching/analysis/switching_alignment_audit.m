% NOTE:
% R_relax = time-dependent relaxation (-dM/dlog t)
% R_age   = aging scalar (tau ratio)
% These MUST NOT be confused

% switching_alignment_audit
% Safe analysis-layer audit for switching alignment structure.
% This script does not modify the legacy Switching pipeline.

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingSafeRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingSafeRoot);
legacyRoot = fullfile(repoRoot, 'Switching ver12');

assert(isfolder(legacyRoot), 'Legacy Switching module not found: %s', legacyRoot);
addpath(genpath(legacyRoot));

% Optional: reuse results helper if available.
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

if ~exist('metricType', 'var') || isempty(metricType)
    metricType = "P2P_percent";  % "P2P_percent" | "meanP2P" | "medianAbs"
end
if ~exist('channelMode', 'var') || isempty(channelMode)
    channelMode = "switchCh";    % "switchCh" | "all"
end
if ~exist('tempTargets_K', 'var') || isempty(tempTargets_K)
    tempTargets_K = [6 10 14 18 22 28 34];
end
if ~exist('maxCurrentCurves', 'var') || isempty(maxCurrentCurves)
    maxCurrentCurves = 8;
end
if ~exist('tempMatchTol_K', 'var') || isempty(tempMatchTol_K)
    tempMatchTol_K = 1.0;
end
if ~exist('decompositionMode','var') || isempty(decompositionMode)
    decompositionMode = "both";   % "svd" | "nmf" | "both"
end

decompositionMode = lower(string(decompositionMode));
runSVD = decompositionMode == "svd" || decompositionMode == "both";
runNMF = decompositionMode == "nmf" || decompositionMode == "both";
if ~(runSVD || runNMF)
    warning('Unknown decompositionMode "%s". Using "both".', char(decompositionMode));
    decompositionMode = "both";
    runSVD = true;
    runNMF = true;
end

if ~exist('parentDir', 'var') || isempty(parentDir)
    parentDir = resolveDefaultParentDir(fullfile(legacyRoot, 'main', 'Switching_main.m'));
end

% If resolveDefaultParentDir returned a specific "Temp Dep ..." folder,
% move up one directory so that parentDir contains the Temp Dep folders.
if isfolder(parentDir)
    [~, name] = fileparts(parentDir);
    if startsWith(string(name), "Temp Dep", 'IgnoreCase', true)
        parentDir = fileparts(parentDir);
    end
end

assert(isfolder(parentDir), [ ...
    'parentDir does not exist: %s\n' ...
    'Set parentDir before running, for example:\n' ...
    'parentDir = ''L:\\...\\Amp Temp Dep all'';'], parentDir);

[outDir, switchingRun] = init_run_output_dir(repoRoot, 'switching', 'alignment_audit', parentDir); %#ok<NASGU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
if isstruct(switchingRun) && isfield(switchingRun, 'run_dir') && exist(switchingRun.run_dir, 'dir') == 7
    reviewDir = fullfile(switchingRun.run_dir, 'review');
    if exist(reviewDir, 'dir') ~= 7
        mkdir(reviewDir);
    end
end

subDirs = findAmpTempSubdirs(parentDir);
assert(~isempty(subDirs), 'No "Temp Dep ..." subfolders were found under: %s', parentDir);

rows = repmat(initRow(), 0, 1);

for iDir = 1:numel(subDirs)
    thisDir = fullfile(parentDir, subDirs(iDir).name);

    dep_type = extract_dep_type_from_folder(thisDir);
    [fileList, sortedValues, ~, meta] = getFileListSwitching(thisDir, dep_type);
    if isempty(fileList)
        continue;
    end

    current_mA = meta.Current_mA;
    if ~isfinite(current_mA)
        continue;
    end

    pulseScheme = extractPulseSchemeFromFolder(thisDir);
    delay_between_pulses_in_msec = extract_delay_between_pulses_from_name(thisDir) * 1e3;
    num_of_pulses_with_same_dep = pulseScheme.totalPulses;

    normalize_to = resolveNormalizeTo(fileList);
    [I_A, scaling_factor] = resolveCurrentAndScale(thisDir, fileList, current_mA);

    [stored_data, tableData] = processFilesSwitching( ...
        thisDir, fileList, sortedValues, I_A, scaling_factor, ...
        4000, 16, 4, ...
        2, 11, ...
        false, delay_between_pulses_in_msec, ...
        num_of_pulses_with_same_dep, 15, ...
        NaN, NaN, normalize_to, ...
        true, 1.5, 50, false, pulseScheme);

    chList = resolveChannels(channelMode, stored_data, tableData, sortedValues, ...
        delay_between_pulses_in_msec, pulseScheme);

    negP2P = false;
    if exist('resolveNegP2P', 'file') == 2
        negP2P = resolveNegP2P(thisDir, "auto");
    end

    for c = 1:numel(chList)
        ch = chList(c);
        [Tvec, Svec] = extractMetricFromTable(tableData, ch, metricType, negP2P);
        if isempty(Tvec)
            continue;
        end

        [Tvec, Svec] = collapseDuplicateTemperatures(Tvec, Svec);

        for k = 1:numel(Tvec)
            row = initRow();
            row.current_mA = current_mA;
            row.T_K = Tvec(k);
            row.S_percent = Svec(k);
            row.channel = ch;
            row.folder = string(subDirs(iDir).name);
            row.metricType = string(metricType);
            rows(end+1,1) = row; %#ok<AGROW>
        end
    end
end

assert(~isempty(rows), 'No switching samples were collected from: %s', parentDir);

rawTbl = struct2table(rows);
rawTbl = sortrows(rawTbl, {'current_mA', 'T_K', 'channel'});

rawCsv = fullfile(outDir, 'switching_alignment_samples.csv');
writetable(rawTbl, rawCsv);

% Build S(T,I) map from raw table by averaging samples at each (T, I_0).
temps = unique(rawTbl.T_K(isfinite(rawTbl.T_K)));
currents = unique(rawTbl.current_mA(isfinite(rawTbl.current_mA)));
temps = sort(temps(:));
currents = sort(currents(:));
[TT, II] = ndgrid(temps, currents);
Smap = NaN(size(TT));
for it = 1:numel(temps)
    for ii = 1:numel(currents)
        m = abs(rawTbl.T_K - temps(it)) < 1e-9 & abs(rawTbl.current_mA - currents(ii)) < 1e-9;
        if any(m)
            Smap(it, ii) = mean(rawTbl.S_percent(m), 'omitnan');
        end
    end
end

% Temperature cleanup: merge near-duplicate temperatures into rounded-K bins.
tempsOriginal = temps;
Tclean = round(tempsOriginal);
[TuniqClean, ~, idxClean] = unique(Tclean, 'sorted');
SmapOriginal = Smap;
SmapClean = NaN(numel(TuniqClean), numel(currents));
for k = 1:numel(TuniqClean)
    mk = idxClean == k;
    SmapClean(k, :) = mean(SmapOriginal(mk, :), 1, 'omitnan');
end
temps = TuniqClean(:);
Smap = SmapClean;
[TT, II] = ndgrid(temps, currents); %#ok<ASGLU>
numTempsOriginal = numel(tempsOriginal);
numTempsCleaned = numel(temps);

figTempCleanup = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axTempCleanup = axes(figTempCleanup);
scatter(axTempCleanup, tempsOriginal, Tclean, 35, 'filled');
hold(axTempCleanup, 'on')
tMinCleanup = min([tempsOriginal(:); Tclean(:)], [], 'omitnan');
tMaxCleanup = max([tempsOriginal(:); Tclean(:)], [], 'omitnan');
if isfinite(tMinCleanup) && isfinite(tMaxCleanup)
    plot(axTempCleanup, [tMinCleanup tMaxCleanup], [tMinCleanup tMaxCleanup], 'k--', 'LineWidth', 1.2);
end
xlabel(axTempCleanup, 'Original T (K)')
ylabel(axTempCleanup, 'Cleaned T (K)')
title(axTempCleanup, 'Temperature cleanup: original vs rounded bins')
grid(axTempCleanup, 'on')
tempCleanupOut = export_alignment_figure(figTempCleanup, 'switching_alignment_temperature_cleanup', outDir);
close(figTempCleanup);

% Temperature-dependent switching observables from S(T,I).
Ipeak = NaN(size(temps));
S_peak = NaN(size(temps));
width_I = NaN(size(temps));
halfwidth_diff_norm = NaN(size(temps));
for it = 1:numel(temps)
    row = Smap(it,:);
    valid = isfinite(row);
    if ~any(valid)
        Ipeak(it) = NaN;
        continue
    end

    rowValid = row(valid);
    currValid = currents(valid);
    [smax, idx] = max(rowValid);
    Ipeak(it) = currValid(idx);
    S_peak(it) = smax;

    if smax < eps
        width_I(it) = NaN;
        continue
    end

    half = 0.5 * smax;
    halfMask = rowValid >= half;
    if nnz(halfMask) >= 2
        iLeft = min(currValid(halfMask));
        iRight = max(currValid(halfMask));
        wL = Ipeak(it) - iLeft;
        wR = iRight - Ipeak(it);
        width_I(it) = wL + wR;
        denom = wL + wR;
        if isfinite(denom) && denom > eps
            halfwidth_diff_norm(it) = (wR - wL) / denom;
        else
            halfwidth_diff_norm(it) = NaN;
        end
    else
        width_I(it) = NaN;
        halfwidth_diff_norm(it) = NaN;
    end
end

width_rel = NaN(size(width_I));
validWidthRel = isfinite(width_I) & isfinite(Ipeak) & abs(Ipeak) > eps;
width_rel(validWidthRel) = width_I(validWidthRel) ./ Ipeak(validWidthRel);

% Current susceptibility map: dS/dI (dimension 2 = current axis).
dS_dI = NaN(size(Smap));
for it = 1:size(Smap, 1)
    row = Smap(it,:);
    valid = isfinite(row);
    if nnz(valid) >= 2
        rowDer = NaN(size(row));
        rowDer(valid) = gradient(reshape(row(valid), 1, []), currents(valid));
        dS_dI(it,:) = rowDer;
    end
end

% Susceptibility observables and second derivative map from dS/dI.
Ichi = NaN(size(temps));
chiPeak = NaN(size(temps));
chiWidth = NaN(size(temps));
chiArea = NaN(size(temps));
d2S_dI2 = NaN(size(Smap));
for it = 1:size(Smap, 1)
    chiRow = dS_dI(it,:);
    validChi = isfinite(chiRow);
    if ~any(validChi)
        continue
    end

    chiValid = chiRow(validChi);
    currValid = currents(validChi);
    [chiMax, idxChi] = max(chiValid);
    Ichi(it) = currValid(idxChi);
    chiPeak(it) = chiMax;

    if chiMax > eps
        halfChi = 0.5 * chiMax;
        halfMask = chiValid >= halfChi;
        if nnz(halfMask) >= 2
            chiWidth(it) = max(currValid(halfMask)) - min(currValid(halfMask));
        else
            chiWidth(it) = NaN;
        end
    else
        chiWidth(it) = NaN;
    end

    chiPos = max(chiValid, 0);
    if numel(currValid) >= 2
        chiArea(it) = trapz(currValid, chiPos);
    end

    if nnz(validChi) >= 2
        rowDer2 = NaN(size(chiRow));
        rowDer2(validChi) = gradient(reshape(chiValid, 1, []), currValid);
        d2S_dI2(it,:) = rowDer2;
    end
end


% Peak asymmetry observable: area_right / area_left around I_peak.
asym = NaN(size(temps));
for it = 1:numel(temps)
    if ~isfinite(Ipeak(it))
        continue
    end
    row = Smap(it,:);
    valid = isfinite(row);
    if ~any(valid)
        continue
    end
    currValid = currents(valid);
    rowValid = row(valid);
    leftMask = currValid < Ipeak(it);
    rightMask = currValid > Ipeak(it);
    if nnz(leftMask) < 2 || nnz(rightMask) < 2
        continue
    end
    areaLeft = trapz(currValid(leftMask), rowValid(leftMask));
    areaRight = trapz(currValid(rightMask), rowValid(rightMask));
    if abs(areaLeft) > eps
        asym(it) = areaRight / areaLeft;
    end
end


% SVD-derived observables initialized as NaN; filled after SVD if available.
mode1_T = NaN(size(temps));
mode2_T = NaN(size(temps));
mode_ratio = NaN(size(temps));
mode_ratio_smooth = NaN(size(temps));
coeff_mode1 = NaN(size(temps));
coeff_mode2 = NaN(size(temps));
coeff_mode3 = NaN(size(temps));
coeffI_mode1 = NaN(size(currents));
coeffI_mode2 = NaN(size(currents));
coeffI_mode3 = NaN(size(currents));

% Export compact observables-vs-temperature table for downstream analysis.
obsTbl = table(temps, Ipeak, S_peak, halfwidth_diff_norm, width_I, Ichi, chiPeak, chiWidth, chiArea, asym, ...
    mode1_T, mode2_T, coeff_mode1, coeff_mode2, coeff_mode3, mode_ratio, mode_ratio_smooth, ...
    'VariableNames', {'T_K','Ipeak','S_peak','halfwidth_diff_norm','width_I','Ichi','chiPeak','chiWidth','chiArea','asym', ...
    'mode1_T','mode2_T','coeff_mode1','coeff_mode2','coeff_mode3','mode_ratio','mode_ratio_smooth'});
obsCsvOut = fullfile(outDir, 'switching_alignment_observables_vs_T.csv');
writetable(obsTbl, obsCsvOut);

% Export switching observables to run-scoped observable-layer CSV.
obsRunCsvOut = "";
if exist('export_observables', 'file') == 2
    try
        if ~exist('switchingRunDir', 'var') || isempty(switchingRunDir)
            switchingRunDir = createSwitchingObservableRunDir(repoRoot, "switching_alignment_audit", parentDir, metricType);
        end
        sampleName = deriveSwitchingSampleName(parentDir, metricType);
        obsLongTbl = buildSwitchingObservableLongTable( ...
            temps, S_peak, Ipeak, halfwidth_diff_norm, width_I, asym, sampleName);
        obsRunCsvOut = export_observables('switching', switchingRunDir, obsLongTbl);
    catch ME
        warning('Switching observable export failed: %s', ME.message);
    end
else
    warning('export_observables.m not found on path; skipping run-scoped observable export.');
end

% Decomposition outputs.
svdTOut = "";
svdIOut = "";
nmfTOut = "";
nmfIOut = "";
nmfComp1Out = "";
nmfComp2Out = "";
nmfRecOut = "";
svdRec2Out = "";
svdRec3Out = "";
nmfRec3Out = "";
svdScreeOut = "";
svdExplainedOut = "";
svdSingValsOut = "";
svdModeAmpOut = "";
svdModeRatioOut = "";
svdModeRatioSmoothOut = "";
svdCurrentModesOut = "";
svdModeReconOut = "";
svdModeScatterOut = "";
svdModeObsCorrOut = "";
svdModeObsCorrCsvOut = "";
modeObsOut = "";
nmfStabilityOut = "";
ridgeCurveOut = "";
heatNormOut = "";
scalingIoverIpeakOut = "";
scalingInormOut = "";
energyScaleCollapseOut = "";
scalingImIpeakOut = "";
scalingThreshNormOut = "";
residualRank2Out = "";
residualRank3Out = "";
widthVsTOut = "";
activationWidthOut = "";
IpeakVsTOut = "";
chiPeakVsTOut = "";
chiWidthVsTOut = "";
susCutsOut = "";
additionalObsOut = "";
derivTestsOut = "";
ridgeObsOut = "";
ridgeDerivOut = "";
ridgeLawOut = "";
charTempsOut = "";
ridgeScalingMessage = "";
activationTestOut = "";
mapWithRidgeOut = "";
ridgeCollapseMapOut = "";
ridgeCollapseCurvesOut = "";
tempPeakTrackOut = "";
lowTBackgroundOut = "";
modeMapsOut = "";
widthScalingOut = "";
bgSubMapOut = "";
svdStabilityOut = "";
curvatureMapOut = "";
modeCorrOut = "";
modeLocalizationOut = "";
extendedObsCsvOut = "";
ranSVD = false;
ranNMF = false;
err_svd_1 = NaN;
err_svd_2 = NaN;
err_svd_3 = NaN;
err_nmf_2 = NaN;
err_nmf_3 = NaN;
imp_svd_12 = NaN;
imp_svd_23 = NaN;
rel_svd_23 = NaN;
imp_nmf_23 = NaN;
rel_nmf_23 = NaN;
M2 = NaN(size(Smap));
M3 = NaN(size(Smap));
corr12 = NaN;

if runSVD
    % SVD decomposition of S(T, I).
    M = Smap;
    M(~isfinite(M)) = 0;
    [U,S,V] = svd(M,'econ');
    svals_raw = diag(S);
    singvals = svals_raw;
    if sum(singvals) > 0
        singvals = singvals / sum(singvals);
    else
        singvals = nan(size(singvals));
    end
    disp('Normalized singular values:')
    disp(singvals')

    svdSingValsTbl = table((1:numel(svals_raw))', svals_raw(:), singvals(:), ...
        cumsum(svals_raw(:).^2) ./ sum(svals_raw(:).^2), ...
        'VariableNames', {'mode','singular_value','normalized_singular_value','cumulative_energy'});
    svdSingValsOut = fullfile(outDir, 'switching_alignment_svd_singular_values.csv');
    writetable(svdSingValsTbl, svdSingValsOut);

    figSvdScree = figure('Color','w','Visible','off', 'Position', [100 100 900 600]);
    axSvdScree = axes(figSvdScree);
    plot(axSvdScree, 1:numel(singvals), singvals, 'o-','LineWidth',2);
    xlabel(axSvdScree, 'mode')
    ylabel(axSvdScree, 'normalized singular value')
    title(axSvdScree, 'SVD scree plot')
    grid(axSvdScree, 'on')
    svdScreeOut = export_alignment_figure(figSvdScree, 'switching_alignment_svd_scree', outDir);
    close(figSvdScree);

    figSvdEV = figure('Color','w','Visible','off', 'Position', [100 100 900 600]);
    axSvdEV = axes(figSvdEV);
    if sum(svals_raw.^2) > 0
        evCurve = cumsum(svals_raw.^2) / sum(svals_raw.^2);
    else
        evCurve = nan(size(svals_raw));
    end
    plot(axSvdEV, 1:numel(evCurve), evCurve, 'o-','LineWidth',2);
    xlabel(axSvdEV, 'mode k')
    ylabel(axSvdEV, 'explained variance')
    title(axSvdEV, 'SVD explained variance')
    grid(axSvdEV, 'on')
    svdExplainedOut = export_alignment_figure(figSvdEV, 'switching_alignment_svd_explained_variance', outDir);
    close(figSvdEV);

    M1 = U(:,1)*S(1,1)*V(:,1)';
    if size(U,2) >= 2 && size(V,2) >= 2
        M2 = U(:,1:2)*S(1:2,1:2)*V(:,1:2)';
    else
        M2 = M1;
    end

    if size(U,2) >= 3 && size(V,2) >= 3
        M3 = U(:,1:3)*S(1:3,1:3)*V(:,1:3)';
    else
        M3 = NaN(size(M));
    end

    if norm(M,'fro') > 0
        err_svd_1 = norm(M - M1,'fro') / norm(M,'fro');
        err_svd_2 = norm(M - M2,'fro') / norm(M,'fro');
        if all(isfinite(M3(:)))
            err_svd_3 = norm(M - M3,'fro') / norm(M,'fro');
        end
    end

    if isfinite(err_svd_1) && isfinite(err_svd_2)
        imp_svd_12 = err_svd_1 - err_svd_2;
    end
    if isfinite(err_svd_2) && isfinite(err_svd_3)
        imp_svd_23 = err_svd_2 - err_svd_3;
        if err_svd_2 > 0
            rel_svd_23 = imp_svd_23 / err_svd_2;
        end
    end

    fprintf('1-mode error: %.3f\n',err_svd_1);
    fprintf('2-mode error: %.3f\n',err_svd_2);
    fprintf('3-mode error: %.3f\n',err_svd_3);
    fprintf('SVD improvement 1->2: %.3f\n', imp_svd_12);
    fprintf('SVD improvement 2->3: %.3f\n', imp_svd_23);
    fprintf('SVD relative improvement 2->3: %.3f\n', rel_svd_23);

    nModesT = min(2, size(U,2));
    figModesT = figure('Color','w','Visible','off', 'Position', [100 100 900 600]);
    axModesT = axes(figModesT);
    hT = gobjects(0);
    for k = 1:nModesT
        if k == 1
            hT(end+1) = plot(axModesT, temps, U(:,k), '-o');
        else
            hold(axModesT, 'on');
            hT(end+1) = plot(axModesT, temps, U(:,k), '-s');
        end
    end
    xlabel(axModesT,'T (K)')
    title(axModesT,'SVD temperature modes')
    legend(axModesT, hT, compose('mode %d', 1:nModesT), 'Location', 'best')
    grid(axModesT,'on')
    svdTOut = export_alignment_figure(figModesT, 'switching_alignment_svd_T', outDir);
    close(figModesT);

    nModesI = min(2, size(V,2));
    figModesI = figure('Color','w','Visible','off', 'Position', [100 100 900 600]);
    axModesI = axes(figModesI);
    hI = gobjects(0);
    for k = 1:nModesI
        if k == 1
            hI(end+1) = plot(axModesI, currents, V(:,k), '-o');
        else
            hold(axModesI, 'on');
            hI(end+1) = plot(axModesI, currents, V(:,k), '-s');
        end
    end
    xlabel(axModesI,'I (mA)')
    title(axModesI,'SVD current modes')
    legend(axModesI, hI, compose('mode %d', 1:nModesI), 'Location', 'best')
    grid(axModesI,'on')
    svdIOut = export_alignment_figure(figModesI, 'switching_alignment_svd_I', outDir);
    close(figModesI);

    figSvdRec2 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
    axSvdRec2 = axes(figSvdRec2);
    imagesc(axSvdRec2, currents, temps, M2);
    set(axSvdRec2, 'YDir', 'normal');
    colormap(axSvdRec2, turbo)
    xlabel(axSvdRec2, 'I_0 (mA)');
    ylabel(axSvdRec2, 'T (K)');
    title(axSvdRec2, 'SVD rank-2 reconstruction');
    cbSvdRec2 = colorbar(axSvdRec2);
    ylabel(cbSvdRec2, 'Switching amplitude \DeltaR/R (%)');
    svdRec2Out = export_alignment_figure(figSvdRec2, 'switching_alignment_svd_rank2_reconstruction', outDir);
    close(figSvdRec2);

    if all(isfinite(M3(:)))
        figSvdRec3 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
        axSvdRec3 = axes(figSvdRec3);
        imagesc(axSvdRec3, currents, temps, M3);
        set(axSvdRec3, 'YDir', 'normal');
        colormap(axSvdRec3, turbo)
        xlabel(axSvdRec3, 'I_0 (mA)');
        ylabel(axSvdRec3, 'T (K)');
        title(axSvdRec3, 'SVD rank-3 reconstruction');
        cbSvdRec3 = colorbar(axSvdRec3);
        ylabel(cbSvdRec3, 'Switching amplitude \DeltaR/R (%)');
        svdRec3Out = export_alignment_figure(figSvdRec3, 'switching_alignment_svd_rank3_reconstruction', outDir);
        close(figSvdRec3);
    end

    ranSVD = true;
end


% Additional SVD mode diagnostics (no SVD recomputation).
if ranSVD
    nModeObs = min([3, size(U,2), size(V,2), size(S,1)]);
    if nModeObs >= 1
        coeffMatT = NaN(numel(temps), 3);
        coeffMatI = NaN(numel(currents), 3);
        for kObs = 1:nModeObs
            coeffMatT(:,kObs) = U(:,kObs) * S(kObs,kObs);
            coeffMatI(:,kObs) = V(:,kObs) * S(kObs,kObs);
        end
        coeff_mode1 = coeffMatT(:,1);
        coeffI_mode1 = coeffMatI(:,1);
        if nModeObs >= 2
            coeff_mode2 = coeffMatT(:,2);
            coeffI_mode2 = coeffMatI(:,2);
        end
        if nModeObs >= 3
            coeff_mode3 = coeffMatT(:,3);
            coeffI_mode3 = coeffMatI(:,3);
        end

        mode1_T = coeff_mode1;
        mode2_T = coeff_mode2;

        figModeObs = figure('Color','w','Visible','off','Position',[100 100 1100 500]);
        tlModeObsMain = tiledlayout(figModeObs, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        axModeObsT = nexttile(tlModeObsMain, 1);
        hold(axModeObsT, 'on')
        grid(axModeObsT, 'on')
        mStyles = {'-o','-s','-^'};
        mNames = {'mode 1','mode 2','mode 3'};
        for kObs = 1:nModeObs
            plot(axModeObsT, temps, coeffMatT(:,kObs), mStyles{kObs}, 'LineWidth', 1.8, 'DisplayName', mNames{kObs});
        end
        xlabel(axModeObsT, 'T (K)')
        ylabel(axModeObsT, 'coeff_modek(T)')
        title(axModeObsT, 'Temperature mode observables')
        legend(axModeObsT, 'Location', 'best');

        axModeObsI = nexttile(tlModeObsMain, 2);
        hold(axModeObsI, 'on')
        grid(axModeObsI, 'on')
        for kObs = 1:nModeObs
            plot(axModeObsI, currents, coeffMatI(:,kObs), mStyles{kObs}, 'LineWidth', 1.8, 'DisplayName', mNames{kObs});
        end
        xlabel(axModeObsI, 'I_0 (mA)')
        ylabel(axModeObsI, 'coeffI_modek(I)')
        title(axModeObsI, 'Current mode observables')
        legend(axModeObsI, 'Location', 'best');
        modeObsOut = export_alignment_figure(figModeObs, 'switching_alignment_mode_observables', outDir);
        close(figModeObs);

        fprintf('Mode observables summary:\n');
        for kObs = 1:3
            vec = coeffMatT(:,kObs);
            v = isfinite(vec) & isfinite(temps);
            if nnz(v) >= 1
                aMin = min(vec(v));
                aMax = max(vec(v));
                aStd = std(vec(v), 0);
                if nnz(v) >= 2
                    dVec = gradient(vec(v), temps(v));
                    dStd = std(dVec, 0);
                    smoothMetric = mean(abs(diff(vec(v))));
                else
                    dStd = NaN;
                    smoothMetric = NaN;
                end
                fprintf('  mode%d amplitude range = [%.4g, %.4g], std = %.4g, d/dT std = %.4g, smoothness = %.4g\n', ...
                    kObs, aMin, aMax, aStd, dStd, smoothMetric);
            else
                fprintf('  mode%d amplitude range = n/a\n', kObs);
            end
        end
    end

    if size(U,2) >= 2 && size(V,2) >= 2
        mode1_T = U(:,1) * S(1,1);
        mode2_T = U(:,2) * S(2,2);
        denom = abs(mode1_T);
        validRatio = isfinite(denom) & (denom > eps) & isfinite(mode2_T);
        mode_ratio(validRatio) = abs(mode2_T(validRatio)) ./ denom(validRatio);
        mode_ratio_smooth = movmean(mode_ratio, 3, 'omitnan');

        figModeAmp = figure('Color','w','Visible','off','Position',[100 100 900 600]);
        axModeAmp = axes(figModeAmp);
        plot(axModeAmp, temps, mode1_T, '-o', 'LineWidth', 1.8, 'DisplayName', 'mode 1');
        hold(axModeAmp, 'on')
        plot(axModeAmp, temps, mode2_T, '-s', 'LineWidth', 1.8, 'DisplayName', 'mode 2');
        xlabel(axModeAmp, 'T (K)')
        ylabel(axModeAmp, 'U(:,k)S(k,k)')
        title(axModeAmp, 'SVD mode amplitudes vs temperature')
        grid(axModeAmp, 'on')
        legend(axModeAmp, 'Location', 'best');
        svdModeAmpOut = export_alignment_figure(figModeAmp, 'switching_alignment_svd_mode_amplitudes_vs_T', outDir);
        close(figModeAmp);

        figModeRatio = figure('Color','w','Visible','off','Position',[100 100 900 600]);
        axModeRatio = axes(figModeRatio);
        plot(axModeRatio, temps, mode_ratio, '-o', 'LineWidth', 1.8);
        xlabel(axModeRatio, 'T (K)')
        ylabel(axModeRatio, '|mode2|/|mode1|')
        title(axModeRatio, 'SVD mode ratio vs temperature')
        grid(axModeRatio, 'on')
        svdModeRatioOut = export_alignment_figure(figModeRatio, 'switching_alignment_mode_ratio_vs_T', outDir);
        close(figModeRatio);

        figModeRatioSmooth = figure('Color','w','Visible','off','Position',[100 100 900 600]);
        axModeRatioSmooth = axes(figModeRatioSmooth);
        plot(axModeRatioSmooth, temps, mode_ratio_smooth, '-o', 'LineWidth', 1.8);
        xlabel(axModeRatioSmooth, 'T (K)')
        ylabel(axModeRatioSmooth, 'smoothed |mode2|/|mode1|')
        title(axModeRatioSmooth, 'Smoothed SVD mode ratio')
        grid(axModeRatioSmooth, 'on')
        svdModeRatioSmoothOut = export_alignment_figure(figModeRatioSmooth, 'switching_alignment_mode_ratio_smoothed', outDir);
        close(figModeRatioSmooth);

        figCurrModes2 = figure('Color','w','Visible','off','Position',[100 100 900 600]);
        axCurrModes2 = axes(figCurrModes2);
        plot(axCurrModes2, currents, V(:,1), '-o', 'LineWidth', 1.8, 'DisplayName', 'G1(I)');
        hold(axCurrModes2, 'on')
        plot(axCurrModes2, currents, V(:,2), '-s', 'LineWidth', 1.8, 'DisplayName', 'G2(I)');
        xlabel(axCurrModes2, 'I_0 (mA)')
        ylabel(axCurrModes2, 'V(:,k)')
        title(axCurrModes2, 'SVD current-mode structure')
        grid(axCurrModes2, 'on')
        legend(axCurrModes2, 'Location', 'best');
        svdCurrentModesOut = export_alignment_figure(figCurrModes2, 'switching_alignment_svd_current_modes', outDir);
        close(figCurrModes2);

        S1 = U(:,1) * S(1,1) * V(:,1)';
        S2 = U(:,2) * S(2,2) * V(:,2)';
        figModeRecon = figure('Color','w','Visible','off','Position',[100 100 1100 500]);
        tlModeRecon = tiledlayout(figModeRecon, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        axS1 = nexttile(tlModeRecon, 1);
        imagesc(axS1, currents, temps, S1);
        set(axS1, 'YDir', 'normal');
        colormap(axS1, turbo)
        xlabel(axS1, 'I_0 (mA)')
        ylabel(axS1, 'T (K)')
        title(axS1, 'Mode-1 reconstruction')
        cbS1 = colorbar(axS1);
        ylabel(cbS1, '\DeltaR/R (%)')
        axS2 = nexttile(tlModeRecon, 2);
        imagesc(axS2, currents, temps, S2);
        set(axS2, 'YDir', 'normal');
        colormap(axS2, turbo)
        xlabel(axS2, 'I_0 (mA)')
        ylabel(axS2, 'T (K)')
        title(axS2, 'Mode-2 reconstruction')
        cbS2 = colorbar(axS2);
        ylabel(cbS2, '\DeltaR/R (%)')
        svdModeReconOut = export_alignment_figure(figModeRecon, 'switching_alignment_mode_reconstruction', outDir);
        close(figModeRecon);

        valid12 = isfinite(mode1_T) & isfinite(mode2_T);
        if nnz(valid12) >= 2
            corr12 = corr(mode1_T(valid12), mode2_T(valid12), 'rows', 'complete');
        else
            corr12 = NaN;
        end
        figModeScatter = figure('Color','w','Visible','off','Position',[100 100 900 600]);
        axModeScatter = axes(figModeScatter);
        scatter(axModeScatter, mode1_T, mode2_T, 45, temps, 'filled');
        grid(axModeScatter, 'on')
        xlabel(axModeScatter, 'mode1\_T')
        ylabel(axModeScatter, 'mode2\_T')
        title(axModeScatter, 'Mode independence scatter')
        cbModeScatter = colorbar(axModeScatter);
        ylabel(cbModeScatter, 'T (K)')
        text(axModeScatter, 0.03, 0.95, sprintf('r = %.3f', corr12), 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontWeight', 'bold');
        svdModeScatterOut = export_alignment_figure(figModeScatter, 'switching_alignment_mode_scatter', outDir);
        close(figModeScatter);

        figModeObsCorr = figure('Color','w','Visible','off','Position',[100 100 1000 800]);
        tlModeObs = tiledlayout(figModeObsCorr, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        xSets = {mode1_T, mode2_T, mode1_T, mode2_T};
        ySets = {S_peak, S_peak, Ipeak, Ipeak};
        xlbl = {'mode1_T', 'mode2_T', 'mode1_T', 'mode2_T'};
        ylbl = {'S_{peak}', 'S_{peak}', 'I_{peak} (mA)', 'I_{peak} (mA)'};
        ttl = {'mode1_T vs S_{peak}', 'mode2_T vs S_{peak}', 'mode1_T vs I_{peak}', 'mode2_T vs I_{peak}'};
        for i = 1:4
            ax = nexttile(tlModeObs, i);
            scatter(ax, xSets{i}, ySets{i}, 35, temps, 'filled');
            grid(ax, 'on')
            xlabel(ax, xlbl{i})
            ylabel(ax, ylbl{i})
            title(ax, ttl{i})
            v = isfinite(xSets{i}) & isfinite(ySets{i});
            r = NaN;
            if nnz(v) >= 2
                r = corr(xSets{i}(v), ySets{i}(v), 'rows', 'complete');
            end
            text(ax, 0.03, 0.95, sprintf('r = %.3f', r), 'Units', 'normalized', 'VerticalAlignment', 'top', 'FontWeight', 'bold');
            if i == 4
                cb = colorbar(ax);
                ylabel(cb, 'T (K)')
            end
        end
        svdModeObsCorrOut = export_alignment_figure(figModeObsCorr, 'switching_alignment_mode_observable_correlations', outDir);
        close(figModeObsCorr);

        modeObsCorrTbl = table( ...
            string({'mode1_T_vs_S_peak';'mode2_T_vs_S_peak';'mode1_T_vs_I_peak';'mode2_T_vs_I_peak'}), ...
            [safeCorr(mode1_T, S_peak, 2); safeCorr(mode2_T, S_peak, 2); safeCorr(mode1_T, Ipeak, 2); safeCorr(mode2_T, Ipeak, 2)], ...
            [nnz(isfinite(mode1_T) & isfinite(S_peak)); nnz(isfinite(mode2_T) & isfinite(S_peak)); ...
             nnz(isfinite(mode1_T) & isfinite(Ipeak)); nnz(isfinite(mode2_T) & isfinite(Ipeak))], ...
            'VariableNames', {'comparison','correlation_r','n_points'});
        svdModeObsCorrCsvOut = fullfile(outDir, 'switching_alignment_mode_observable_correlations.csv');
        writetable(modeObsCorrTbl, svdModeObsCorrCsvOut);


        obsTbl.mode1_T = mode1_T;
        obsTbl.mode2_T = mode2_T;
        obsTbl.coeff_mode1 = coeff_mode1;
        obsTbl.coeff_mode2 = coeff_mode2;
        obsTbl.coeff_mode3 = coeff_mode3;
        obsTbl.mode_ratio = mode_ratio;
        obsTbl.mode_ratio_smooth = mode_ratio_smooth;
        writetable(obsTbl, obsCsvOut);
    else
        warning('SVD mode diagnostics skipped: fewer than 2 SVD modes available.');
    end
end

if runNMF
    if exist('nnmf', 'file') == 2
        M_nmf = Smap;
        M_nmf(~isfinite(M_nmf)) = 0;
        M_nmf(M_nmf < 0) = 0;

        if all(M_nmf(:) == 0)
            warning('NMF skipped because nonnegative map is all zeros.');
        else
            rngState = rng;
            try
                rng(0);
                [W,H] = nnmf(M_nmf, 2, 'replicates', 5);

                ranNMF = true;
                M_nmf_rec = W * H;
                M_nmf_rec3 = NaN(size(M_nmf));
                if norm(M_nmf,'fro') > 0
                    err_nmf_2 = norm(M_nmf - M_nmf_rec,'fro') / norm(M_nmf,'fro');
                end
                fprintf('NMF 2-component error: %.3f\n', err_nmf_2);
                fprintf('NMF rank-2 error: %.3f\n', err_nmf_2);

                nmfStabErr = NaN(7,1);
                for iStab = 1:numel(nmfStabErr)
                    try
                        rng(iStab);
                        [Wstab,Hstab] = nnmf(M_nmf, 2, 'replicates', 1);
                        if norm(M_nmf,'fro') > 0
                            nmfStabErr(iStab) = norm(M_nmf - Wstab*Hstab,'fro') / norm(M_nmf,'fro');
                        end
                    catch
                        nmfStabErr(iStab) = NaN;
                    end
                end
                figNmfStab = figure('Color','w','Visible','off', 'Position', [100 100 900 600]);
                axNmfStab = axes(figNmfStab);
                validStab = isfinite(nmfStabErr);
                if any(validStab)
                    plot(axNmfStab, find(validStab), nmfStabErr(validStab), 'o-','LineWidth',1.8);
                else
                    plot(axNmfStab, nan, nan);
                end
                xlabel(axNmfStab, 'run index')
                ylabel(axNmfStab, 'reconstruction error')
                title(axNmfStab, 'NMF stability (rank 2)')
                grid(axNmfStab, 'on')
                nmfStabilityOut = export_alignment_figure(figNmfStab, 'switching_alignment_nmf_stability', outDir);
                close(figNmfStab);

                try
                    rng(0);
                    [W3,H3] = nnmf(M_nmf, 3, 'replicates', 5);
                    M_nmf_rec3 = W3 * H3;
                    if norm(M_nmf,'fro') > 0
                        err_nmf_3 = norm(M_nmf - M_nmf_rec3,'fro') / norm(M_nmf,'fro');
                    end
                    fprintf('NMF rank-3 error: %.3f\n', err_nmf_3);
                catch ME3
                    warning('NMF rank-3 audit failed: %s', ME3.message);
                end

                if isfinite(err_nmf_2) && isfinite(err_nmf_3)
                    imp_nmf_23 = err_nmf_2 - err_nmf_3;
                    if err_nmf_2 > 0
                        rel_nmf_23 = imp_nmf_23 / err_nmf_2;
                    end
                end
                fprintf('NMF improvement 2->3: %.3f\n', imp_nmf_23);
                fprintf('NMF relative improvement 2->3: %.3f\n', rel_nmf_23);
                rng(rngState);

                figNmfT = figure('Color','w','Visible','off', 'Position', [100 100 900 600]);
                axNmfT = axes(figNmfT);
                plot(axNmfT, temps, W(:,1), '-o', temps, W(:,2), '-s');
                xlabel(axNmfT, 'T (K)')
                title(axNmfT, 'NMF temperature components')
                legend(axNmfT, 'component 1', 'component 2', 'Location', 'best')
                grid(axNmfT, 'on')
                nmfTOut = export_alignment_figure(figNmfT, 'switching_alignment_nmf_T', outDir);
                close(figNmfT);

                figNmfI = figure('Color','w','Visible','off', 'Position', [100 100 900 600]);
                axNmfI = axes(figNmfI);
                plot(axNmfI, currents, H(1,:), '-o', currents, H(2,:), '-s');
                xlabel(axNmfI, 'I (mA)')
                title(axNmfI, 'NMF current components')
                legend(axNmfI, 'component 1', 'component 2', 'Location', 'best')
                grid(axNmfI, 'on')
                nmfIOut = export_alignment_figure(figNmfI, 'switching_alignment_nmf_I', outDir);
                close(figNmfI);

                Mcomp1 = W(:,1) * H(1,:);
                figNmfC1 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
                axNmfC1 = axes(figNmfC1);
                imagesc(axNmfC1, currents, temps, Mcomp1);
                set(axNmfC1, 'YDir', 'normal');
                colormap(axNmfC1, turbo)
                xlabel(axNmfC1, 'I_0 (mA)');
                ylabel(axNmfC1, 'T (K)');
                title(axNmfC1, 'NMF component 1');
                cbNmfC1 = colorbar(axNmfC1);
                ylabel(cbNmfC1, 'Switching amplitude \DeltaR/R (%)');
                nmfComp1Out = export_alignment_figure(figNmfC1, 'switching_alignment_nmf_component1', outDir);
                close(figNmfC1);

                Mcomp2 = W(:,2) * H(2,:);
                figNmfC2 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
                axNmfC2 = axes(figNmfC2);
                imagesc(axNmfC2, currents, temps, Mcomp2);
                set(axNmfC2, 'YDir', 'normal');
                colormap(axNmfC2, turbo)
                xlabel(axNmfC2, 'I_0 (mA)');
                ylabel(axNmfC2, 'T (K)');
                title(axNmfC2, 'NMF component 2');
                cbNmfC2 = colorbar(axNmfC2);
                ylabel(cbNmfC2, 'Switching amplitude \DeltaR/R (%)');
                nmfComp2Out = export_alignment_figure(figNmfC2, 'switching_alignment_nmf_component2', outDir);
                close(figNmfC2);

                figNmfRec = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
                axNmfRec = axes(figNmfRec);
                imagesc(axNmfRec, currents, temps, M_nmf_rec);
                set(axNmfRec, 'YDir', 'normal');
                colormap(axNmfRec, turbo)
                xlabel(axNmfRec, 'I_0 (mA)');
                ylabel(axNmfRec, 'T (K)');
                title(axNmfRec, 'NMF reconstruction W*H');
                cbNmfRec = colorbar(axNmfRec);
                ylabel(cbNmfRec, 'Switching amplitude \DeltaR/R (%)');
                nmfRecOut = export_alignment_figure(figNmfRec, 'switching_alignment_nmf_reconstruction', outDir);
                close(figNmfRec);

                if all(isfinite(M_nmf_rec3(:)))
                    figNmfRec3 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
                    axNmfRec3 = axes(figNmfRec3);
                    imagesc(axNmfRec3, currents, temps, M_nmf_rec3);
                    set(axNmfRec3, 'YDir', 'normal');
                    colormap(axNmfRec3, turbo)
                    xlabel(axNmfRec3, 'I_0 (mA)');
                    ylabel(axNmfRec3, 'T (K)');
                    title(axNmfRec3, 'NMF rank-3 reconstruction');
                    cbNmfRec3 = colorbar(axNmfRec3);
                    ylabel(cbNmfRec3, 'Switching amplitude \DeltaR/R (%)');
                    nmfRec3Out = export_alignment_figure(figNmfRec3, 'switching_alignment_nmf_rank3_reconstruction', outDir);
                    close(figNmfRec3);
                end
            catch ME
                rng(rngState);
                warning('NMF decomposition failed: %s', ME.message);
            end
        end
    else
        warning('nnmf is unavailable. Skipping NMF decomposition outputs.');
    end
end
figHeat = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axHeat = axes(figHeat);
imagesc(axHeat, currents, temps, Smap);
set(axHeat, 'YDir', 'normal');
colormap(axHeat, turbo)
sVals = Smap(isfinite(Smap));
if ~isempty(sVals)
    vmin = prctile(sVals, 5);
    vmax = prctile(sVals, 95);
    if isfinite(vmin) && isfinite(vmax) && (vmax > vmin)
        caxis(axHeat, [vmin vmax]);
    end
end
hold(axHeat,'on')
plot(axHeat, Ipeak, temps,'w-','LineWidth',2)
xlabel(axHeat, 'I_0 (mA)');
ylabel(axHeat, 'T (K)');
title(axHeat, 'Switching map S(T,I)');
cbHeat = colorbar(axHeat);
ylabel(cbHeat, 'Switching amplitude \DeltaR/R (%)');
heatOut = export_alignment_figure(figHeat, 'switching_alignment_heatmap', outDir);
close(figHeat);

if ranSVD
    residualRank2 = NaN(size(Smap));
    validRes2 = isfinite(Smap) & isfinite(M2);
    residualRank2(validRes2) = Smap(validRes2) - M2(validRes2);
    figRes2 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
    axRes2 = axes(figRes2);
    imagesc(axRes2, currents, temps, residualRank2);
    set(axRes2, 'YDir', 'normal');
    applyDivergingColormap(axRes2)
    valsRes2 = residualRank2(isfinite(residualRank2));
    if ~isempty(valsRes2)
        limRes2 = max(abs(valsRes2));
        if isfinite(limRes2) && limRes2 > 0
            caxis(axRes2, [-limRes2 limRes2]);
        end
    end
    xlabel(axRes2, 'I_0 (mA)');
    ylabel(axRes2, 'T (K)');
    title(axRes2, 'Residual map: rank-2 (S - SVD_{rank2})');
    cbRes2 = colorbar(axRes2);
    ylabel(cbRes2, 'Residual \DeltaR/R (%)');
    residualRank2Out = export_alignment_figure(figRes2, 'switching_alignment_residual_rank2', outDir);
    close(figRes2);

    if all(isfinite(M3(:)))
        residualRank3 = NaN(size(Smap));
        validRes3 = isfinite(Smap) & isfinite(M3);
        residualRank3(validRes3) = Smap(validRes3) - M3(validRes3);
        figRes3 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
        axRes3 = axes(figRes3);
        imagesc(axRes3, currents, temps, residualRank3);
        set(axRes3, 'YDir', 'normal');
        applyDivergingColormap(axRes3)
        valsRes3 = residualRank3(isfinite(residualRank3));
        if ~isempty(valsRes3)
            limRes3 = max(abs(valsRes3));
            if isfinite(limRes3) && limRes3 > 0
                caxis(axRes3, [-limRes3 limRes3]);
            end
        end
        xlabel(axRes3, 'I_0 (mA)');
        ylabel(axRes3, 'T (K)');
        title(axRes3, 'Residual map: rank-3 (S - SVD_{rank3})');
        cbRes3 = colorbar(axRes3);
        ylabel(cbRes3, 'Residual \DeltaR/R (%)');
        residualRank3Out = export_alignment_figure(figRes3, 'switching_alignment_residual_rank3', outDir);
        close(figRes3);
    end
end


SmapNorm = NaN(size(Smap));
for it = 1:size(Smap,1)
    row = Smap(it,:);
    valid = isfinite(row);
    if any(valid)
        rowMax = max(row(valid));
        if isfinite(rowMax) && rowMax > 0
            SmapNorm(it,valid) = row(valid) / rowMax;
        end
    end
end
figHeatNorm = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axHeatNorm = axes(figHeatNorm);
imagesc(axHeatNorm, currents, temps, SmapNorm);
set(axHeatNorm, 'YDir', 'normal');
colormap(axHeatNorm, turbo)
caxis(axHeatNorm, [0 1]);
xlabel(axHeatNorm, 'I_0 (mA)');
ylabel(axHeatNorm, 'T (K)');
title(axHeatNorm, 'Normalized switching map S/max(S)');
cbHeatNorm = colorbar(axHeatNorm);
ylabel(cbHeatNorm, 'Normalized switching amplitude');
heatNormOut = export_alignment_figure(figHeatNorm, 'switching_alignment_heatmap_normalized', outDir);
close(figHeatNorm);

figdSdI = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axdSdI = axes(figdSdI);
imagesc(axdSdI, currents, temps, dS_dI);
set(axdSdI, 'YDir', 'normal');
applyDivergingColormap(axdSdI)
dVals = dS_dI(isfinite(dS_dI));
if ~isempty(dVals)
    lim = max(abs(dVals));
    if isfinite(lim) && lim > 0
        caxis(axdSdI, [-lim lim]);
    end
end
xlabel(axdSdI, 'I_0 (mA)');
ylabel(axdSdI, 'T (K)');
title(axdSdI, 'Current susceptibility \partialS/\partialI');
cbdSdI = colorbar(axdSdI);
ylabel(cbdSdI, '\partialS/\partialI');
dSdIOut = export_alignment_figure(figdSdI, 'switching_alignment_dSdI_heatmap', outDir);
close(figdSdI);
figd2SdI2 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axd2SdI2 = axes(figd2SdI2);
imagesc(axd2SdI2, currents, temps, d2S_dI2);
set(axd2SdI2, 'YDir', 'normal');
applyDivergingColormap(axd2SdI2)
d2Vals = d2S_dI2(isfinite(d2S_dI2));
if ~isempty(d2Vals)
    lim2 = max(abs(d2Vals));
    if isfinite(lim2) && lim2 > 0
        caxis(axd2SdI2, [-lim2 lim2]);
    end
end
xlabel(axd2SdI2, 'I_0 (mA)');
ylabel(axd2SdI2, 'T (K)');
title(axd2SdI2, 'Second current derivative \partial^2S/\partialI^2');
cbd2 = colorbar(axd2SdI2);
ylabel(cbd2, '\partial^2S/\partialI^2');
d2SdI2Out = export_alignment_figure(figd2SdI2, 'switching_alignment_d2SdI2_heatmap', outDir);
close(figd2SdI2);

figSusCuts = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axSusCuts = axes(figSusCuts);
hold(axSusCuts, 'on')
grid(axSusCuts, 'on')
numTempsSus = numel(temps);
if exist('turbo', 'file') == 2
    cmapSus = turbo(max(1,numTempsSus));
else
    cmapSus = parula(max(1,numTempsSus));
end
for it = 1:numTempsSus
    row = dS_dI(it,:);
    valid = isfinite(row);
    if nnz(valid) < 2
        continue;
    end
    plot(axSusCuts, currents(valid), row(valid), '-','LineWidth',1.6,'Color',cmapSus(it,:), ...
        'DisplayName', sprintf('T = %.2f K', temps(it)));
end
xlabel(axSusCuts, 'I_0 (mA)');
ylabel(axSusCuts, '\partialS/\partialI');
title(axSusCuts, 'Susceptibility cuts');
legend(axSusCuts, 'Location', 'eastoutside');
susCutsOut = export_alignment_figure(figSusCuts, 'switching_alignment_susceptibility_cuts', outDir);
close(figSusCuts);

figRidge = figure('Color','w','Visible','off','Position',[100 100 900 600]);
axRidge = axes(figRidge);
plot(axRidge, temps, Ipeak, '-o','LineWidth',1.5);
xlabel(axRidge,'T (K)')
ylabel(axRidge,'I_{peak} (mA)')
title(axRidge,'Peak switching current I_{peak}(T)')
grid(axRidge,'on')
ridgeOut = export_alignment_figure(figRidge, 'switching_alignment_ridge', outDir);
close(figRidge);

I_ridge_smooth = Ipeak;
validRidge = isfinite(Ipeak);
if nnz(validRidge) >= 2
    I_ridge_smooth(validRidge) = movmean(Ipeak(validRidge), 3);
end
figRidgeCurve = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axRidgeCurve = axes(figRidgeCurve);
plot(axRidgeCurve, temps, Ipeak, '-o', 'LineWidth', 1.6, 'DisplayName', 'I_{peak}');
hold(axRidgeCurve, 'on')
plot(axRidgeCurve, temps, I_ridge_smooth, '-', 'LineWidth', 2.2, 'DisplayName', 'smoothed ridge');
xlabel(axRidgeCurve, 'T (K)')
ylabel(axRidgeCurve, 'I (mA)')
title(axRidgeCurve, 'Ridge tracking curve')
grid(axRidgeCurve, 'on')
legend(axRidgeCurve, 'Location', 'best');
ridgeCurveOut = export_alignment_figure(figRidgeCurve, 'switching_alignment_ridge_curve', outDir);
close(figRidgeCurve);

figIpeakVsT = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axIpeakVsT = axes(figIpeakVsT);
plot(axIpeakVsT, temps, Ipeak, '-o', 'LineWidth', 1.8);
xlabel(axIpeakVsT, 'T (K)')
ylabel(axIpeakVsT, 'I_{peak} (mA)')
title(axIpeakVsT, 'Peak position vs temperature')
grid(axIpeakVsT, 'on')
IpeakVsTOut = export_alignment_figure(figIpeakVsT, 'switching_alignment_Ipeak_vs_T', outDir);
close(figIpeakVsT);

figRidgeLaw = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 700]);
tlRidgeLaw = tiledlayout(figRidgeLaw, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axRL1 = nexttile(tlRidgeLaw, 1);
plot(axRL1, temps, Ipeak, '-o', 'LineWidth', 1.7);
xlabel(axRL1, 'T (K)')
ylabel(axRL1, 'I_{peak} (mA)')
title(axRL1, 'Ridge law test: I_{peak} vs T')
grid(axRL1, 'on')

invT = NaN(size(temps));
validTinv = isfinite(temps) & (temps > 0);
invT(validTinv) = 1 ./ temps(validTinv);

axRL2 = nexttile(tlRidgeLaw, 2);
v2 = isfinite(invT) & isfinite(Ipeak);
plot(axRL2, invT(v2), Ipeak(v2), '-o', 'LineWidth', 1.7);
xlabel(axRL2, '1/T (K^{-1})')
ylabel(axRL2, 'I_{peak} (mA)')
title(axRL2, 'Ridge law test: I_{peak} vs 1/T')
grid(axRL2, 'on')

axRL3 = nexttile(tlRidgeLaw, [1 2]);
v3 = isfinite(invT) & isfinite(Ipeak) & (Ipeak > 0);
plot(axRL3, invT(v3), log(Ipeak(v3)), '-o', 'LineWidth', 1.7);
xlabel(axRL3, '1/T (K^{-1})')
ylabel(axRL3, 'log(I_{peak})')
title(axRL3, 'Ridge law test: log(I_{peak}) vs 1/T')
grid(axRL3, 'on')

ridgeLawOut = export_alignment_figure(figRidgeLaw, 'switching_alignment_ridge_law_tests', outDir);
close(figRidgeLaw);


figWidthVsT = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axWidthVsT = axes(figWidthVsT);
plot(axWidthVsT, temps, width_I, '-o', 'LineWidth', 1.8);
xlabel(axWidthVsT, 'T (K)')
ylabel(axWidthVsT, 'width_I (mA)')
title(axWidthVsT, 'Peak width vs temperature')
grid(axWidthVsT, 'on')
widthVsTOut = export_alignment_figure(figWidthVsT, 'switching_alignment_peak_width_vs_T', outDir);
close(figWidthVsT);

figRidgeObs = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 800]);
tlRidgeObs = tiledlayout(figRidgeObs, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axRO1 = nexttile(tlRidgeObs, 1);
plot(axRO1, temps, Ipeak, '-o', 'LineWidth', 1.6);
xlabel(axRO1, 'T (K)')
ylabel(axRO1, 'I_{peak} (mA)')
title(axRO1, 'Ridge: I_{peak}(T)')
grid(axRO1, 'on')
axRO2 = nexttile(tlRidgeObs, 2);
plot(axRO2, temps, S_peak, '-o', 'LineWidth', 1.6);
xlabel(axRO2, 'T (K)')
ylabel(axRO2, 'S_{peak}')
title(axRO2, 'Ridge: S_{peak}(T)')
grid(axRO2, 'on')
axRO3 = nexttile(tlRidgeObs, 3);
plot(axRO3, temps, width_I, '-o', 'LineWidth', 1.6);
xlabel(axRO3, 'T (K)')
ylabel(axRO3, 'width_I (mA)')
title(axRO3, 'Ridge: width_I(T)')
grid(axRO3, 'on')
axRO4 = nexttile(tlRidgeObs, 4);
plot(axRO4, temps, width_rel, '-o', 'LineWidth', 1.6);
xlabel(axRO4, 'T (K)')
ylabel(axRO4, 'width_{rel} = width_I/I_{peak}')
title(axRO4, 'Ridge: relative width')
grid(axRO4, 'on')
ridgeObsOut = export_alignment_figure(figRidgeObs, 'switching_alignment_ridge_observables', outDir);
close(figRidgeObs);


dWidth_dT = NaN(size(width_I));
validWidth = isfinite(width_I) & isfinite(temps);
if nnz(validWidth) >= 2
    dtmp = gradient(width_I(validWidth), temps(validWidth));
    dWidth_dT(validWidth) = dtmp;
end

figActWidth = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 700]);
tlActWidth = tiledlayout(figActWidth, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axActW1 = nexttile(tlActWidth, 1);
plot(axActW1, temps, width_I, '-o', 'LineWidth', 1.8);
xlabel(axActW1, 'T (K)')
ylabel(axActW1, 'width_I (mA)')
title(axActW1, 'Activation width vs temperature')
grid(axActW1, 'on')

axActW2 = nexttile(tlActWidth, 2);
plot(axActW2, temps, dWidth_dT, '-o', 'LineWidth', 1.6);
xlabel(axActW2, 'T (K)')
ylabel(axActW2, 'd(width_I)/dT')
title(axActW2, 'Width slope vs temperature')
grid(axActW2, 'on')

activationWidthOut = export_alignment_figure(figActWidth, 'switching_alignment_activation_width_vs_T', outDir);
close(figActWidth);


figChiPeakVsT = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axChiPeakVsT = axes(figChiPeakVsT);
plot(axChiPeakVsT, temps, chiPeak, '-o', 'LineWidth', 1.8);
xlabel(axChiPeakVsT, 'T (K)')
ylabel(axChiPeakVsT, '\chi_{peak}')
title(axChiPeakVsT, 'Susceptibility peak vs temperature')
grid(axChiPeakVsT, 'on')
chiPeakVsTOut = export_alignment_figure(figChiPeakVsT, 'switching_alignment_chiPeak_vs_T', outDir);
close(figChiPeakVsT);

chiWidth_I = chiWidth;
figChiWidth = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axChiWidth = axes(figChiWidth);
plot(axChiWidth, temps, chiWidth_I, '-o', 'LineWidth', 1.8);
xlabel(axChiWidth, 'T (K)')
ylabel(axChiWidth, 'chiWidth_I (mA)')
title(axChiWidth, 'Susceptibility width vs temperature')
grid(axChiWidth, 'on')
chiWidthVsTOut = export_alignment_figure(figChiWidth, 'switching_alignment_susceptibility_width_vs_T', outDir);
close(figChiWidth);

dS_peak_dT = NaN(size(S_peak));
dIpeak_dT = NaN(size(Ipeak));
d2S_peak_dT2 = NaN(size(S_peak));
validSP = isfinite(S_peak) & isfinite(temps);
if nnz(validSP) >= 2
    dS_peak_dT(validSP) = gradient(S_peak(validSP), temps(validSP));
end
validIp = isfinite(Ipeak) & isfinite(temps);
if nnz(validIp) >= 2
    dIpeak_dT(validIp) = gradient(Ipeak(validIp), temps(validIp));
end
validD1 = isfinite(dS_peak_dT) & isfinite(temps);
if nnz(validD1) >= 2
    d2S_peak_dT2(validD1) = gradient(dS_peak_dT(validD1), temps(validD1));
end

figDeriv = figure('Color','w','Visible','off','Position',[100 100 1000 800]);
tlDeriv = tiledlayout(figDeriv, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axD1 = nexttile(tlDeriv, 1);
plot(axD1, temps, dS_peak_dT, '-o', 'LineWidth', 1.6);
xlabel(axD1, 'T (K)')
ylabel(axD1, 'dS_{peak}/dT')
title(axD1, 'Derivative test: dS_{peak}/dT')
grid(axD1, 'on')
axD2 = nexttile(tlDeriv, 2);
plot(axD2, temps, dIpeak_dT, '-o', 'LineWidth', 1.6);
xlabel(axD2, 'T (K)')
ylabel(axD2, 'dI_{peak}/dT')
title(axD2, 'Derivative test: dI_{peak}/dT')
grid(axD2, 'on')
axD3 = nexttile(tlDeriv, 3);
plot(axD3, temps, S_peak, '-o', 'LineWidth', 1.6, 'DisplayName', 'S_{peak}');
hold(axD3, 'on')
plot(axD3, temps, dS_peak_dT, '-s', 'LineWidth', 1.6, 'DisplayName', 'dS_{peak}/dT');
xlabel(axD3, 'T (K)')
ylabel(axD3, 'value (a.u.)')
title(axD3, 'Shape comparison: S_{peak} and dS_{peak}/dT')
grid(axD3, 'on')
legend(axD3, 'Location', 'best');
axD4 = nexttile(tlDeriv, 4);
plot(axD4, temps, d2S_peak_dT2, '-o', 'LineWidth', 1.6);
xlabel(axD4, 'T (K)')
ylabel(axD4, 'd^2S_{peak}/dT^2')
title(axD4, 'Curvature diagnostic')
grid(axD4, 'on')
derivTestsOut = export_alignment_figure(figDeriv, 'switching_alignment_derivative_tests', outDir);
close(figDeriv);

dSpeak_dT = dS_peak_dT;
figRidgeDeriv = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 500]);
tlRidgeDeriv = tiledlayout(figRidgeDeriv, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axRD1 = nexttile(tlRidgeDeriv, 1);
plot(axRD1, temps, dIpeak_dT, '-o', 'LineWidth', 1.6);
xlabel(axRD1, 'T (K)')
ylabel(axRD1, 'dI_{peak}/dT')
title(axRD1, 'Ridge derivative: dI_{peak}/dT')
grid(axRD1, 'on')
axRD2 = nexttile(tlRidgeDeriv, 2);
plot(axRD2, temps, dSpeak_dT, '-o', 'LineWidth', 1.6);
xlabel(axRD2, 'T (K)')
ylabel(axRD2, 'dS_{peak}/dT')
title(axRD2, 'Ridge derivative: dS_{peak}/dT')
grid(axRD2, 'on')
ridgeDerivOut = export_alignment_figure(figRidgeDeriv, 'switching_alignment_ridge_derivatives', outDir);
close(figRidgeDeriv);

charNames = strings(0,1);
charTemps = NaN(0,1);
vS = isfinite(S_peak) & isfinite(temps);
if any(vS)
    tSub = temps(vS);
    sSub = S_peak(vS);
    [~, iMinS] = min(sSub);
    charNames(end+1,1) = "T_min_Speak";
    charTemps(end+1,1) = tSub(iMinS);
end
vA = isfinite(asym) & isfinite(temps);
if any(vA)
    tSub = temps(vA);
    aSub = asym(vA);
    [~, iMaxA] = max(aSub);
    charNames(end+1,1) = "T_max_asym";
    charTemps(end+1,1) = tSub(iMaxA);
end
if exist('mode_ratio', 'var') == 1
    vM = isfinite(mode_ratio) & isfinite(temps);
    if any(vM)
        tSub = temps(vM);
        mSub = mode_ratio(vM);
        [~, iMaxM] = max(mSub);
        charNames(end+1,1) = "T_max_mode_ratio";
        charTemps(end+1,1) = tSub(iMaxM);
    end
end
vD = isfinite(dSpeak_dT) & isfinite(temps);
if any(vD)
    tSub = temps(vD);
    dSub = abs(dSpeak_dT(vD));
    [~, iMaxD] = max(dSub);
    charNames(end+1,1) = "T_max_abs_dSpeak_dT";
    charTemps(end+1,1) = tSub(iMaxD);
end
charTbl = table(charNames, charTemps, 'VariableNames', {'name','temperature_K'});
charTempsOut = fullfile(outDir, 'switching_alignment_characteristic_temperatures.csv');
writetable(charTbl, charTempsOut);

% Extend observables CSV with ridge-derived columns.
obsTbl.width_rel = width_rel;
obsTbl.dIpeak_dT = dIpeak_dT;
obsTbl.dSpeak_dT = dSpeak_dT;
obsTbl.coeff_mode1 = coeff_mode1;
obsTbl.coeff_mode2 = coeff_mode2;
obsTbl.coeff_mode3 = coeff_mode3;
if exist('mode_ratio', 'var') == 1
    obsTbl.mode_ratio = mode_ratio;
end
if exist('mode_ratio_smooth', 'var') == 1
    obsTbl.mode_ratio_smooth = mode_ratio_smooth;
end
writetable(obsTbl, obsCsvOut);




figObs = figure('Color','w','Visible','off','Position',[100 100 900 600]);
tlObs = tiledlayout(figObs, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axObs1 = nexttile(tlObs, 1);
plot(axObs1, temps, Ipeak, '-o', 'LineWidth', 1.5);
xlabel(axObs1, 'T (K)')
ylabel(axObs1, 'I_{peak} (mA)')
title(axObs1, 'Peak current')
grid(axObs1, 'on')

axObs2 = nexttile(tlObs, 2);
plot(axObs2, temps, S_peak, '-o', 'LineWidth', 1.5);
xlabel(axObs2, 'T (K)')
ylabel(axObs2, 'S_{peak} (\DeltaR/R [%])')
title(axObs2, 'Peak switching amplitude')
grid(axObs2, 'on')

axObs3 = nexttile(tlObs, 3);
plot(axObs3, temps, width_I, '-o', 'LineWidth', 1.5);
xlabel(axObs3, 'T (K)')
ylabel(axObs3, 'width_I (mA)')
title(axObs3, 'Half-maximum width')
grid(axObs3, 'on')

obsOut = export_alignment_figure(figObs, 'switching_alignment_observables', outDir);
close(figObs);
figChiObs = figure('Color','w','Visible','off','Position',[100 100 900 600]);
tlChiObs = tiledlayout(figChiObs, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axChi1 = nexttile(tlChiObs, 1);
plot(axChi1, temps, Ichi, '-o', 'LineWidth', 1.5);
xlabel(axChi1, 'T (K)')
ylabel(axChi1, 'I_{\chi} (mA)')
title(axChi1, 'Activation current from \partialS/\partialI')
grid(axChi1, 'on')

axChi2 = nexttile(tlChiObs, 2);
plot(axChi2, temps, chiPeak, '-o', 'LineWidth', 1.5);
xlabel(axChi2, 'T (K)')
ylabel(axChi2, '\chi_{peak}')
title(axChi2, 'Peak susceptibility')
grid(axChi2, 'on')

axChi3 = nexttile(tlChiObs, 3);
plot(axChi3, temps, chiWidth, '-o', 'LineWidth', 1.5);
xlabel(axChi3, 'T (K)')
ylabel(axChi3, 'chiWidth (mA)')
title(axChi3, 'Half-maximum susceptibility width')
grid(axChi3, 'on')

axChi4 = nexttile(tlChiObs, 4);
plot(axChi4, temps, chiArea, '-o', 'LineWidth', 1.5);
xlabel(axChi4, 'T (K)')
ylabel(axChi4, 'chiArea')
title(axChi4, 'Integrated positive susceptibility')
grid(axChi4, 'on')

susObsOut = export_alignment_figure(figChiObs, 'switching_alignment_susceptibility_observables', outDir);
close(figChiObs);

figScaling = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axScaling = axes(figScaling);
hold(axScaling, 'on')
grid(axScaling, 'on')
if exist('turbo', 'file') == 2
    cmapScale = turbo(max(1,numel(temps)));
else
    cmapScale = parula(max(1,numel(temps)));
end
for it = 1:numel(temps)
    if ~isfinite(Ipeak(it)) || Ipeak(it) == 0
        continue;
    end
    row = Smap(it,:);
    valid = isfinite(row);
    if nnz(valid) < 2
        continue;
    end
    x = currents(valid) / Ipeak(it);
    y = row(valid);
    [x, ord] = sort(x);
    y = y(ord);
    plot(axScaling, x, y, '-','LineWidth',1.8,'Color',cmapScale(it,:), ...
        'DisplayName', sprintf('T = %.2f K', temps(it)));
end
xlabel(axScaling, 'I / I_{peak}(T)');
ylabel(axScaling, 'S(T,I)');
title(axScaling, 'Scaling test: S vs I/I_{peak}');
legend(axScaling, 'Location', 'eastoutside');
scalingIoverIpeakOut = export_alignment_figure(figScaling, 'switching_alignment_scaling_I_over_Ipeak', outDir);
close(figScaling);

figEnergyCollapse = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axEnergyCollapse = axes(figEnergyCollapse);
hold(axEnergyCollapse, 'on')
grid(axEnergyCollapse, 'on')
if exist('turbo', 'file') == 2
    cmapEnergy = turbo(max(1,numel(temps)));
else
    cmapEnergy = parula(max(1,numel(temps)));
end
for it = 1:numel(temps)
    if ~isfinite(Ipeak(it)) || Ipeak(it) == 0 || ~isfinite(S_peak(it)) || S_peak(it) <= eps
        continue;
    end
    row = Smap(it,:);
    valid = isfinite(row);
    if nnz(valid) < 2
        continue;
    end
    x = currents(valid) / Ipeak(it);
    y = row(valid) / S_peak(it);
    [x, ord] = sort(x);
    y = y(ord);
    plot(axEnergyCollapse, x, y, '-','LineWidth',1.8,'Color',cmapEnergy(it,:), ...
        'DisplayName', sprintf('T = %.2f K', temps(it)));
end
xlabel(axEnergyCollapse, 'I / I_{peak}(T)');
ylabel(axEnergyCollapse, 'S(T,I) / S_{peak}(T)');
title(axEnergyCollapse, 'Energy-scale collapse: normalized S vs I/I_{peak}');
legend(axEnergyCollapse, 'Location', 'eastoutside');
energyScaleCollapseOut = export_alignment_figure(figEnergyCollapse, 'switching_alignment_energy_scale_collapse', outDir);
close(figEnergyCollapse);


if exist('turbo', 'file') == 2
    cmapThresh = turbo(max(1,numel(temps)));
else
    cmapThresh = parula(max(1,numel(temps)));
end

figScalingShift = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axScalingShift = axes(figScalingShift);
hold(axScalingShift, 'on')
grid(axScalingShift, 'on')
for it = 1:numel(temps)
    if ~isfinite(Ipeak(it))
        continue;
    end
    row = Smap(it,:);
    valid = isfinite(row);
    if nnz(valid) < 2
        continue;
    end
    x = currents(valid) - Ipeak(it);
    y = row(valid);
    [x, ord] = sort(x);
    y = y(ord);
    plot(axScalingShift, x, y, '-','LineWidth',1.8,'Color',cmapThresh(it,:), ...
        'DisplayName', sprintf('T = %.2f K', temps(it)));
end
xlabel(axScalingShift, 'I - I_{peak}(T) (mA)');
ylabel(axScalingShift, 'S(T,I)');
title(axScalingShift, 'Threshold-collapse test: S vs I - I_{peak}');
legend(axScalingShift, 'Location', 'eastoutside');
scalingImIpeakOut = export_alignment_figure(figScalingShift, 'switching_alignment_scaling_I_minus_Ipeak', outDir);
close(figScalingShift);

figScalingNormThresh = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axScalingNormThresh = axes(figScalingNormThresh);
hold(axScalingNormThresh, 'on')
grid(axScalingNormThresh, 'on')
for it = 1:numel(temps)
    if ~isfinite(Ipeak(it)) || ~isfinite(width_I(it)) || width_I(it) <= eps
        continue;
    end
    row = Smap(it,:);
    valid = isfinite(row);
    if nnz(valid) < 2
        continue;
    end
    x = (currents(valid) - Ipeak(it)) / width_I(it);
    y = row(valid);
    [x, ord] = sort(x);
    y = y(ord);
    plot(axScalingNormThresh, x, y, '-','LineWidth',1.8,'Color',cmapThresh(it,:), ...
        'DisplayName', sprintf('T = %.2f K', temps(it)));
end
xlabel(axScalingNormThresh, '(I - I_{peak}(T)) / width_I(T)');
ylabel(axScalingNormThresh, 'S(T,I)');
title(axScalingNormThresh, 'Normalized threshold-collapse test');
legend(axScalingNormThresh, 'Location', 'eastoutside');
scalingThreshNormOut = export_alignment_figure(figScalingNormThresh, 'switching_alignment_scaling_threshold_normalized', outDir);
close(figScalingNormThresh);
ridgeScalingMessage = sprintf('Reused ridge scaling diagnostics: %s ; %s', scalingImIpeakOut, scalingThreshNormOut);


figScalingInorm = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axScalingInorm = axes(figScalingInorm);
hold(axScalingInorm, 'on')
grid(axScalingInorm, 'on')
for it = 1:numel(temps)
    if ~isfinite(Ichi(it)) || ~isfinite(chiWidth(it)) || chiWidth(it) <= eps
        continue;
    end
    row = Smap(it,:);
    valid = isfinite(row);
    if nnz(valid) < 2
        continue;
    end
    I_norm = (currents(valid) - Ichi(it)) / chiWidth(it);
    y = row(valid);
    [I_norm, ord] = sort(I_norm);
    y = y(ord);
    plot(axScalingInorm, I_norm, y, '-','LineWidth',1.8,'Color',cmapThresh(it,:), ...
        'DisplayName', sprintf('T = %.2f K', temps(it)));
end
xlabel(axScalingInorm, 'I_{norm} = (I - I_{\chi}(T))/chiWidth(T)');
ylabel(axScalingInorm, 'S(T,I)');
title(axScalingInorm, 'Scaling collapse test: S vs I_{norm}');
legend(axScalingInorm, 'Location', 'eastoutside');
scalingInormOut = export_alignment_figure(figScalingInorm, 'switching_alignment_scaling_I_norm', outDir);
close(figScalingInorm);


figAddObs = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 700]);
tlAddObs = tiledlayout(figAddObs, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axAdd1 = nexttile(tlAddObs, 1);
plot(axAdd1, temps, Ipeak, '-o', 'LineWidth', 1.6);
xlabel(axAdd1, 'T (K)')
ylabel(axAdd1, 'I_{peak} (mA)')
title(axAdd1, 'Peak current')
grid(axAdd1, 'on')

axAdd2 = nexttile(tlAddObs, 2);
plot(axAdd2, temps, width_I, '-o', 'LineWidth', 1.6);
xlabel(axAdd2, 'T (K)')
ylabel(axAdd2, 'width_I (mA)')
title(axAdd2, 'Peak width')
grid(axAdd2, 'on')

axAdd3 = nexttile(tlAddObs, 3);
plot(axAdd3, temps, chiPeak, '-o', 'LineWidth', 1.6);
xlabel(axAdd3, 'T (K)')
ylabel(axAdd3, '\chi_{peak}')
title(axAdd3, 'Susceptibility peak')
grid(axAdd3, 'on')

axAdd4 = nexttile(tlAddObs, 4);
plot(axAdd4, temps, asym, '-o', 'LineWidth', 1.6);
xlabel(axAdd4, 'T (K)')
ylabel(axAdd4, 'asym = area_{right}/area_{left}')
title(axAdd4, 'Peak asymmetry around I_{peak}')
grid(axAdd4, 'on')

additionalObsOut = export_alignment_figure(figAddObs, 'switching_alignment_additional_observables', outDir);
close(figAddObs);

% --- Extended empirical structural diagnostics (ridge, scaling, SVD structure) ---
validAct = isfinite(temps) & (temps > 0) & isfinite(Ipeak) & (Ipeak > 0);
xAct = 1 ./ temps(validAct);
yAct = log(Ipeak(validAct));
pAct = [NaN NaN];
figActTest = figure('Color','w','Visible','off','Position',[100 100 900 600]);
axActTest = axes(figActTest);
plot(axActTest, xAct, yAct, 'o', 'LineWidth', 1.5, 'DisplayName', 'data');
hold(axActTest, 'on')
if numel(xAct) >= 2
    pAct = polyfit(xAct, yAct, 1);
    xFit = linspace(min(xAct), max(xAct), 200);
    yFit = polyval(pAct, xFit);
    plot(axActTest, xFit, yFit, '-', 'LineWidth', 1.8, 'DisplayName', 'linear fit');
end
xlabel(axActTest, '1/T (K^{-1})')
ylabel(axActTest, 'log(I_{peak})')
title(axActTest, 'Activation test: log(I_{peak}) vs 1/T')
grid(axActTest, 'on')
legend(axActTest, 'Location', 'best');
activationTestOut = export_alignment_figure(figActTest, 'switching_alignment_activation_test', outDir);
close(figActTest);

if isfile(heatOut)
    mapWithRidgeOut = fullfile(outDir, 'switching_alignment_map_with_ridge.png');
    copyfile(heatOut, mapWithRidgeOut);
else
    figMapRidge = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
    axMapRidge = axes(figMapRidge);
    imagesc(axMapRidge, currents, temps, Smap);
    set(axMapRidge, 'YDir', 'normal');
    colormap(axMapRidge, turbo)
    hold(axMapRidge, 'on')
    plot(axMapRidge, Ipeak, temps, 'w-', 'LineWidth', 2);
    xlabel(axMapRidge, 'I_0 (mA)'); ylabel(axMapRidge, 'T (K)');
    title(axMapRidge, 'Switching map with ridge');
    colorbar(axMapRidge);
    mapWithRidgeOut = export_alignment_figure(figMapRidge, 'switching_alignment_map_with_ridge', outDir);
    close(figMapRidge);
end

minDI = NaN(size(temps));
maxDI = NaN(size(temps));
for it = 1:numel(temps)
    row = Smap(it,:);
    valid = isfinite(row) & isfinite(currents');
    if nnz(valid) < 2 || ~isfinite(Ipeak(it))
        continue;
    end
    dI = currents(valid) - Ipeak(it);
    minDI(it) = min(dI);
    maxDI(it) = max(dI);
end
validDI = isfinite(minDI) & isfinite(maxDI);
dIgrid = [];
S_shifted = NaN(numel(temps), 200);
if any(validDI)
    dImin = min(minDI(validDI));
    dImax = max(maxDI(validDI));
    if isfinite(dImin) && isfinite(dImax) && dImax > dImin
        dIgrid = linspace(dImin, dImax, 200);
        for it = 1:numel(temps)
            row = Smap(it,:);
            valid = isfinite(row) & isfinite(currents');
            if nnz(valid) < 2 || ~isfinite(Ipeak(it))
                continue;
            end
            dI = currents(valid) - Ipeak(it);
            y = row(valid);
            [dI, ord] = sort(dI); y = y(ord);
            S_shifted(it,:) = interp1(dI, y, dIgrid, 'linear', NaN);
        end
    end
end
if ~isempty(dIgrid)
    figRCMap = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
    axRCMap = axes(figRCMap);
    imagesc(axRCMap, dIgrid, temps, S_shifted);
    set(axRCMap, 'YDir', 'normal');
    colormap(axRCMap, turbo)
    xlabel(axRCMap, '\DeltaI = I - I_{peak}(T) (mA)')
    ylabel(axRCMap, 'T (K)')
    title(axRCMap, 'Ridge-centered collapse map')
    colorbar(axRCMap);
    ridgeCollapseMapOut = export_alignment_figure(figRCMap, 'switching_alignment_ridge_collapse_map', outDir);
    close(figRCMap);

    figRCCurves = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
    axRCCurves = axes(figRCCurves); hold(axRCCurves, 'on'); grid(axRCCurves, 'on');
    if exist('turbo', 'file') == 2
        cmapRC = turbo(max(1,numel(temps)));
    else
        cmapRC = parula(max(1,numel(temps)));
    end
    for it = 1:numel(temps)
        row = S_shifted(it,:);
        valid = isfinite(row);
        if nnz(valid) < 2
            continue;
        end
        plot(axRCCurves, dIgrid(valid), row(valid), '-', 'LineWidth', 1.4, 'Color', cmapRC(it,:), 'DisplayName', sprintf('T = %.2f K', temps(it)));
    end
    xlabel(axRCCurves, '\DeltaI = I - I_{peak}(T) (mA)')
    ylabel(axRCCurves, 'S(T,I)')
    title(axRCCurves, 'Ridge-centered collapse curves')
    legend(axRCCurves, 'Location', 'eastoutside');
    ridgeCollapseCurvesOut = export_alignment_figure(figRCCurves, 'switching_alignment_ridge_collapse_curves', outDir);
    close(figRCCurves);
end

T_peak_high = NaN(size(currents));
T_width_high = NaN(size(currents));
for ii = 1:numel(currents)
    col = Smap(:,ii);
    valid = isfinite(col) & isfinite(temps) & (temps > 20);
    if nnz(valid) < 2
        continue;
    end
    tV = temps(valid); sV = col(valid);
    [sMax, idxMax] = max(sV);
    T_peak_high(ii) = tV(idxMax);
    half = 0.5 * sMax;
    maskHalf = sV >= half;
    if nnz(maskHalf) >= 2
        T_width_high(ii) = max(tV(maskHalf)) - min(tV(maskHalf));
    end
end
figTPeakTrack = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 500]);
tlTPeak = tiledlayout(figTPeakTrack, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axTP1 = nexttile(tlTPeak, 1);
plot(axTP1, currents, T_peak_high, '-o', 'LineWidth', 1.6);
xlabel(axTP1, 'I_0 (mA)'); ylabel(axTP1, 'T_{peak,high} (K)'); title(axTP1, 'High-T peak tracking'); grid(axTP1, 'on');
axTP2 = nexttile(tlTPeak, 2);
plot(axTP2, currents, T_width_high, '-o', 'LineWidth', 1.6);
xlabel(axTP2, 'I_0 (mA)'); ylabel(axTP2, 'T_{width,high} (K)'); title(axTP2, 'High-T peak width'); grid(axTP2, 'on');
tempPeakTrackOut = export_alignment_figure(figTPeakTrack, 'switching_alignment_temperature_peak_tracking', outDir);
close(figTPeakTrack);

lowTMask = isfinite(temps) & temps >= 4 & temps <= 8;
S_lowT = NaN(size(currents));
if any(lowTMask)
    S_lowT = mean(Smap(lowTMask, :), 1, 'omitnan')';
end
figLowT = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axLowT = axes(figLowT);
plot(axLowT, currents, S_lowT, '-o', 'LineWidth', 1.7);
xlabel(axLowT, 'I_0 (mA)'); ylabel(axLowT, 'S_{lowT}'); title(axLowT, 'Low-T background: mean(4-8 K)'); grid(axLowT, 'on');
lowTBackgroundOut = export_alignment_figure(figLowT, 'switching_alignment_lowT_background', outDir);
close(figLowT);

if ranSVD && size(U,2) >= 2 && size(V,2) >= 2
    S1_map = U(:,1) * S(1,1) * V(:,1)';
    S2_map = U(:,2) * S(2,2) * V(:,2)';
    S12 = S1_map + S2_map;
    modeResidual = NaN(size(Smap));
    vRes = isfinite(Smap) & isfinite(S12);
    modeResidual(vRes) = Smap(vRes) - S12(vRes);
    figModeMaps = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 400]);
    tlMM = tiledlayout(figModeMaps, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    axMM1 = nexttile(tlMM, 1); imagesc(axMM1, currents, temps, S1_map); set(axMM1,'YDir','normal'); colormap(axMM1,turbo); title(axMM1,'Mode1 reconstruction'); xlabel(axMM1,'I_0 (mA)'); ylabel(axMM1,'T (K)'); colorbar(axMM1);
    axMM2 = nexttile(tlMM, 2); imagesc(axMM2, currents, temps, S2_map); set(axMM2,'YDir','normal'); colormap(axMM2,turbo); title(axMM2,'Mode2 reconstruction'); xlabel(axMM2,'I_0 (mA)'); ylabel(axMM2,'T (K)'); colorbar(axMM2);
    axMM3 = nexttile(tlMM, 3); imagesc(axMM3, currents, temps, modeResidual); set(axMM3,'YDir','normal'); applyDivergingColormap(axMM3); title(axMM3,'Residual (S - mode1 - mode2)'); xlabel(axMM3,'I_0 (mA)'); ylabel(axMM3,'T (K)'); colorbar(axMM3);
    modeMapsOut = export_alignment_figure(figModeMaps, 'switching_alignment_mode_maps', outDir);
    close(figModeMaps);

    figModeLoc = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 450]);
    tlLoc = tiledlayout(figModeLoc, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    mode1_energy = abs(S1_map).^2;
    mode2_energy = abs(S2_map).^2;
    axLoc1 = nexttile(tlLoc, 1); imagesc(axLoc1, currents, temps, mode1_energy); set(axLoc1,'YDir','normal'); colormap(axLoc1,turbo); title(axLoc1,'Mode1 energy localization'); xlabel(axLoc1,'I_0 (mA)'); ylabel(axLoc1,'T (K)'); colorbar(axLoc1);
    axLoc2 = nexttile(tlLoc, 2); imagesc(axLoc2, currents, temps, mode2_energy); set(axLoc2,'YDir','normal'); colormap(axLoc2,turbo); title(axLoc2,'Mode2 energy localization'); xlabel(axLoc2,'I_0 (mA)'); ylabel(axLoc2,'T (K)'); colorbar(axLoc2);
    modeLocalizationOut = export_alignment_figure(figModeLoc, 'switching_alignment_mode_localization', outDir);
    close(figModeLoc);

    rU = corr(U(:,1), U(:,2), 'rows', 'complete');
    rV = corr(V(:,1), V(:,2), 'rows', 'complete');
    figModeCorr = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 450]);
    tlMC = tiledlayout(figModeCorr, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    axMC1 = nexttile(tlMC, 1); scatter(axMC1, U(:,1), U(:,2), 30, temps, 'filled'); grid(axMC1,'on'); xlabel(axMC1,'U(:,1)'); ylabel(axMC1,'U(:,2)'); title(axMC1,'Temperature mode correlation'); text(axMC1,0.03,0.95,sprintf('r = %.3f',rU),'Units','normalized','VerticalAlignment','top'); colorbar(axMC1);
    axMC2 = nexttile(tlMC, 2); scatter(axMC2, V(:,1), V(:,2), 30, currents, 'filled'); grid(axMC2,'on'); xlabel(axMC2,'V(:,1)'); ylabel(axMC2,'V(:,2)'); title(axMC2,'Current mode correlation'); text(axMC2,0.03,0.95,sprintf('r = %.3f',rV),'Units','normalized','VerticalAlignment','top'); colorbar(axMC2);
    modeCorrOut = export_alignment_figure(figModeCorr, 'switching_alignment_mode_correlation', outDir);
    close(figModeCorr);
end

figWidthScale = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 500]);
tlWS = tiledlayout(figWidthScale, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axWS1 = nexttile(tlWS, 1); plot(axWS1, temps, width_I, '-o', 'LineWidth', 1.6); xlabel(axWS1,'T (K)'); ylabel(axWS1,'width_I (mA)'); title(axWS1,'Width scaling: width_I'); grid(axWS1,'on');
axWS2 = nexttile(tlWS, 2); plot(axWS2, temps, width_rel, '-o', 'LineWidth', 1.6); xlabel(axWS2,'T (K)'); ylabel(axWS2,'width_{rel}'); title(axWS2,'Width scaling: width_{rel}'); grid(axWS2,'on');
widthScalingOut = export_alignment_figure(figWidthScale, 'switching_alignment_width_scaling', outDir);
close(figWidthScale);

bgMask = isfinite(temps) & (temps < 10);
S_background = NaN(size(Smap));
if any(bgMask)
    bgI = mean(Smap(bgMask,:), 1, 'omitnan');
    S_background = repmat(bgI, numel(temps), 1);
end
S_residual = Smap - S_background;
figBgSub = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axBgSub = axes(figBgSub); imagesc(axBgSub, currents, temps, S_residual); set(axBgSub,'YDir','normal'); applyDivergingColormap(axBgSub); xlabel(axBgSub,'I_0 (mA)'); ylabel(axBgSub,'T (K)'); title(axBgSub,'Background-subtracted map (T<10 K baseline)'); colorbar(axBgSub);
bgSubMapOut = export_alignment_figure(figBgSub, 'switching_alignment_background_subtracted_map', outDir);
close(figBgSub);

Mfull = Smap; Mfull(~isfinite(Mfull)) = 0;
sBefore = NaN(1, min(size(Mfull)));
sAfter = NaN(1, min(size(Mfull)));
if ~isempty(Mfull)
    [~, Sbef, ~] = svd(Mfull, 'econ');
    sBefore = diag(Sbef);
end
keepMask = ~(temps < 10);
Mhigh = Mfull(keepMask, :);
if ~isempty(Mhigh)
    [~, Saft, ~] = svd(Mhigh, 'econ');
    sAfter = diag(Saft);
end
if sum(sBefore, 'omitnan') > 0, sBefore = sBefore ./ sum(sBefore, 'omitnan'); end
if sum(sAfter, 'omitnan') > 0, sAfter = sAfter ./ sum(sAfter, 'omitnan'); end
figSvdStab = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axSvdStab = axes(figSvdStab); hold(axSvdStab, 'on');
plot(axSvdStab, 1:numel(sBefore), sBefore, '-o', 'LineWidth', 1.8, 'DisplayName', 'all T');
plot(axSvdStab, 1:numel(sAfter), sAfter, '-s', 'LineWidth', 1.8, 'DisplayName', 'T >= 10 K');
xlabel(axSvdStab, 'mode'); ylabel(axSvdStab, 'normalized singular value'); title(axSvdStab, 'SVD stability vs low-T removal'); grid(axSvdStab, 'on'); legend(axSvdStab,'Location','best');
svdStabilityOut = export_alignment_figure(figSvdStab, 'switching_alignment_svd_stability', outDir);
close(figSvdStab);

curvT = NaN(size(Smap));
for ii = 1:numel(currents)
    col = Smap(:,ii);
    v = isfinite(col) & isfinite(temps);
    if nnz(v) >= 3
        d1 = gradient(col(v), temps(v));
        d2 = gradient(d1, temps(v));
        curvT(v,ii) = d2;
    end
end
figCurv = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axCurv = axes(figCurv); imagesc(axCurv, currents, temps, curvT); set(axCurv,'YDir','normal'); applyDivergingColormap(axCurv); xlabel(axCurv,'I_0 (mA)'); ylabel(axCurv,'T (K)'); title(axCurv,'Curvature map: \partial^2S/\partialT^2'); colorbar(axCurv);
curvatureMapOut = export_alignment_figure(figCurv, 'switching_alignment_curvature_map', outDir);
close(figCurv);

nRowsExt = max(numel(temps), numel(currents));
T_ext = NaN(nRowsExt,1); invT_ext = NaN(nRowsExt,1); logIpeak_ext = NaN(nRowsExt,1);
S_lowT_ext = NaN(nRowsExt,1); T_peak_high_ext = NaN(nRowsExt,1); T_width_high_ext = NaN(nRowsExt,1); I0_ext = NaN(nRowsExt,1);
T_ext(1:numel(temps)) = temps;
vInv = isfinite(temps) & temps > 0; invTmp = NaN(size(temps)); invTmp(vInv) = 1 ./ temps(vInv); invT_ext(1:numel(temps)) = invTmp;
vLog = isfinite(Ipeak) & Ipeak > 0; logTmp = NaN(size(Ipeak)); logTmp(vLog) = log(Ipeak(vLog)); logIpeak_ext(1:numel(temps)) = logTmp;
I0_ext(1:numel(currents)) = currents;
S_lowT_ext(1:numel(currents)) = S_lowT;
T_peak_high_ext(1:numel(currents)) = T_peak_high;
T_width_high_ext(1:numel(currents)) = T_width_high;
extTbl = table(T_ext, I0_ext, invT_ext, logIpeak_ext, S_lowT_ext, T_peak_high_ext, T_width_high_ext, ...
    'VariableNames', {'T_K','I0_mA','invT','log_Ipeak','S_lowT','T_peak_high','T_width_high'});
extendedObsCsvOut = fullfile(outDir, 'switching_alignment_extended_observables.csv');
writetable(extTbl, extendedObsCsvOut);



currentsAll = unique(rawTbl.current_mA(isfinite(rawTbl.current_mA)));
currentsAll = sort(currentsAll(:)');
currentsToPlot = chooseRepresentative(currentsAll, maxCurrentCurves);

allTemps = unique(round(rawTbl.T_K(isfinite(rawTbl.T_K))));
allTemps = sort(allTemps(:)');
tempsToPlot = allTemps;

figCombined = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
tl = tiledlayout(figCombined, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact'); %#ok<NASGU>
axLeft = nexttile(tl, 1);
plotTemperatureCuts(axLeft, rawTbl, currentsToPlot);
axRight = nexttile(tl, 2);
plotCurrentCuts(axRight, rawTbl, tempsToPlot, tempMatchTol_K);
combinedOut = export_alignment_figure(figCombined, 'switching_alignment_two_panel', outDir);
close(figCombined);

figTemp = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axTemp = axes(figTemp);
plotTemperatureCuts(axTemp, rawTbl, currentsToPlot);
tempOut = export_alignment_figure(figTemp, 'switching_alignment_temperature_cuts', outDir);
close(figTemp);

figCurr = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axCurr = axes(figCurr);
plotCurrentCuts(axCurr, rawTbl, tempsToPlot, tempMatchTol_K);
currOut = export_alignment_figure(figCurr, 'switching_alignment_current_cuts', outDir);
close(figCurr);

% Mirror key SVD/observable-SVD outputs into the run-scoped folder when available.
observableMatrixOut = "";
svdModeCoeffOut = "";
if strlength(obsRunCsvOut) > 0
    runObsDir = fileparts(char(obsRunCsvOut));

    observableMatrixTbl = table(temps, S_peak, Ipeak, width_I, halfwidth_diff_norm, asym, ...
        'VariableNames', {'T','S_peak','I_peak','width_I','halfwidth_diff_norm','asym'});
    observableMatrixOut = fullfile(runObsDir, 'observable_matrix.csv');
    writetable(observableMatrixTbl, observableMatrixOut);

    copyFileIfExists(svdSingValsOut, fullfile(runObsDir, 'switching_alignment_svd_singular_values.csv'));
    copyFileIfExists(svdScreeOut, fullfile(runObsDir, 'switching_alignment_svd_scree.png'));
    copyFileIfExists(svdExplainedOut, fullfile(runObsDir, 'switching_alignment_svd_explained_variance.png'));
    copyFileIfExists(svdTOut, fullfile(runObsDir, 'switching_alignment_svd_T.png'));
    copyFileIfExists(svdIOut, fullfile(runObsDir, 'switching_alignment_svd_I.png'));
    copyFileIfExists(svdModeObsCorrOut, fullfile(runObsDir, 'switching_alignment_mode_observable_correlations.png'));
    copyFileIfExists(svdModeObsCorrCsvOut, fullfile(runObsDir, 'switching_alignment_mode_observable_correlations.csv'));
    copyFileIfExists(modeObsOut, fullfile(runObsDir, 'switching_alignment_mode_observables.png'));

    coreDataPath = fullfile(runObsDir, 'switching_alignment_core_data.mat');
    save(coreDataPath, 'temps', 'currents', 'Smap', 'rawTbl', 'metricType', 'channelMode', 'tempMatchTol_K', 'parentDir');

    if ranSVD && exist('U','var') == 1 && exist('S','var') == 1 && exist('V','var') == 1
        svdDataPath = fullfile(runObsDir, 'switching_alignment_svd_data.mat');
        save(svdDataPath, 'U', 'S', 'V', 'svals_raw', 'singvals', 'mode1_T', 'mode2_T', ...
            'coeff_mode1', 'coeff_mode2', 'coeff_mode3', 'err_svd_1', 'err_svd_2', 'err_svd_3');

        svdModeCoeffTbl = table(temps, coeff_mode1, coeff_mode2, coeff_mode3, ...
            'VariableNames', {'T','mode1_coeff','mode2_coeff','mode3_coeff'});
        svdModeCoeffOut = fullfile(runObsDir, 'svd_mode_coefficients.csv');
        writetable(svdModeCoeffTbl, svdModeCoeffOut);
    end
end

fprintf('Saved switching alignment raw table: %s\n', rawCsv);
fprintf('Saved observables CSV: %s\n', obsCsvOut);
if strlength(obsRunCsvOut) > 0
    fprintf('Saved run-scoped observable-layer CSV: %s\n', obsRunCsvOut);
end
if strlength(observableMatrixOut) > 0
    fprintf('Saved run-scoped observable matrix CSV: %s\n', observableMatrixOut);
end
if strlength(svdModeCoeffOut) > 0
    fprintf('Saved run-scoped SVD mode coefficients CSV: %s\n', svdModeCoeffOut);
end
fprintf('Saved temperature-cleanup figure: %s\n', tempCleanupOut);
fprintf('Temperature cleanup: original points = %d, cleaned bins = %d\n', numTempsOriginal, numTempsCleaned);
fprintf('Final temperature grid (K): %s\n', mat2str(temps(:)'));
fprintf('Saved activation-test figure: %s\n', activationTestOut);
fprintf('Saved map-with-ridge figure: %s\n', mapWithRidgeOut);
fprintf('Saved ridge-collapse map: %s\n', ridgeCollapseMapOut);
fprintf('Saved ridge-collapse curves: %s\n', ridgeCollapseCurvesOut);
fprintf('Saved temperature peak-tracking figure: %s\n', tempPeakTrackOut);
fprintf('Saved low-T background figure: %s\n', lowTBackgroundOut);
fprintf('Saved mode maps figure: %s\n', modeMapsOut);
fprintf('Saved width-scaling figure: %s\n', widthScalingOut);
fprintf('Saved background-subtracted map: %s\n', bgSubMapOut);
fprintf('Saved SVD stability figure: %s\n', svdStabilityOut);
fprintf('Saved curvature map: %s\n', curvatureMapOut);
fprintf('Saved mode-correlation figure: %s\n', modeCorrOut);
fprintf('Saved mode-localization figure: %s\n', modeLocalizationOut);
fprintf('Saved extended observables CSV: %s\n', extendedObsCsvOut);
if all(isfinite(pAct))
    fprintf('Activation-test linear fit (log(Ipeak)=a*(1/T)+b): a=%.6f, b=%.6f\n', pAct(1), pAct(2));
end
fprintf('Saved ridge observables figure: %s\n', ridgeObsOut);
fprintf('Saved ridge derivatives figure: %s\n', ridgeDerivOut);
fprintf('Saved ridge law-tests figure: %s\n', ridgeLawOut);
fprintf('Saved characteristic temperatures CSV: %s\n', charTempsOut);
fprintf('Saved derivative-tests figure: %s\n', derivTestsOut);
fprintf('Saved combined two-panel figure: %s\n', combinedOut);
fprintf('Saved temperature cuts figure: %s\n', tempOut);
fprintf('Saved current cuts figure: %s\n', currOut);
fprintf('Saved heatmap figure: %s\n', heatOut);
fprintf('Saved dS/dI heatmap figure: %s\n', dSdIOut);
fprintf('Saved d2S/dI2 heatmap figure: %s\n', d2SdI2Out);
fprintf('Saved ridge figure: %s\n', ridgeOut);
fprintf('Saved observables figure: %s\n', obsOut);
fprintf('Saved susceptibility observables figure: %s\n', susObsOut);
fprintf('Saved normalized heatmap figure: %s\n', heatNormOut);
fprintf('Saved ridge curve figure: %s\n', ridgeCurveOut);
fprintf('Saved scaling figure (I/Ipeak): %s\n', scalingIoverIpeakOut);
fprintf('Saved scaling figure (I_norm): %s\n', scalingInormOut);
fprintf('Saved energy-scale collapse figure: %s\n', energyScaleCollapseOut);
fprintf('Saved peak width vs T figure: %s\n', widthVsTOut);
fprintf('Saved activation-width figure: %s\n', activationWidthOut);
fprintf('Saved Ipeak vs T figure: %s\n', IpeakVsTOut);
fprintf('Saved chiPeak vs T figure: %s\n', chiPeakVsTOut);
fprintf('Saved susceptibility-width figure: %s\n', chiWidthVsTOut);
fprintf('Saved susceptibility cuts figure: %s\n', susCutsOut);
fprintf('Saved scaling figure (I-Ipeak): %s\n', scalingImIpeakOut);
fprintf('Saved scaling figure ((I-Ipeak)/width): %s\n', scalingThreshNormOut);
if strlength(ridgeScalingMessage) > 0
    fprintf('%s\n', ridgeScalingMessage);
end
fprintf('Saved additional observables figure: %s\n', additionalObsOut);

if ranSVD
    fprintf('Saved SVD temperature modes figure: %s\n', svdTOut);
    fprintf('Saved SVD current modes figure: %s\n', svdIOut);
    if strlength(svdModeAmpOut) > 0
        fprintf('Saved SVD mode amplitudes vs T figure: %s\n', svdModeAmpOut);
    end
    if strlength(svdModeRatioOut) > 0
        fprintf('Saved SVD mode ratio figure: %s\n', svdModeRatioOut);
    end
    if strlength(svdModeRatioSmoothOut) > 0
        fprintf('Saved SVD smoothed mode ratio figure: %s\n', svdModeRatioSmoothOut);
    end
    if strlength(svdCurrentModesOut) > 0
        fprintf('Saved SVD current-mode structure figure: %s\n', svdCurrentModesOut);
    end
    if strlength(svdModeReconOut) > 0
        fprintf('Saved SVD mode reconstruction figure: %s\n', svdModeReconOut);
    end
    if strlength(svdModeScatterOut) > 0
        fprintf('Saved SVD mode scatter figure: %s\n', svdModeScatterOut);
    end
    if strlength(svdModeObsCorrOut) > 0
        fprintf('Saved SVD mode-observable correlations figure: %s\n', svdModeObsCorrOut);
    end
    if strlength(svdModeObsCorrCsvOut) > 0
        fprintf('Saved SVD mode-observable correlations CSV: %s\n', svdModeObsCorrCsvOut);
    end
    if strlength(modeObsOut) > 0
        fprintf('Saved mode observables figure: %s\n', modeObsOut);
    end
    if strlength(svdScreeOut) > 0
        fprintf('Saved SVD scree plot: %s\n', svdScreeOut);
    end
    if strlength(svdExplainedOut) > 0
        fprintf('Saved SVD explained variance plot: %s\n', svdExplainedOut);
    end
    if strlength(svdSingValsOut) > 0
        fprintf('Saved SVD singular values CSV: %s\n', svdSingValsOut);
    end
    if strlength(svdRec2Out) > 0
        fprintf('Saved SVD rank-2 reconstruction heatmap: %s\n', svdRec2Out);
    end
    if strlength(svdRec3Out) > 0
        fprintf('Saved SVD rank-3 reconstruction heatmap: %s\n', svdRec3Out);
    end
    if strlength(residualRank2Out) > 0
        fprintf('Saved residual rank-2 heatmap: %s\n', residualRank2Out);
    end
    if strlength(residualRank3Out) > 0
        fprintf('Saved residual rank-3 heatmap: %s\n', residualRank3Out);
    end
end

if ranNMF
    fprintf('Saved NMF temperature components figure: %s\n', nmfTOut);
    fprintf('Saved NMF current components figure: %s\n', nmfIOut);
    fprintf('Saved NMF component 1 heatmap: %s\n', nmfComp1Out);
    fprintf('Saved NMF component 2 heatmap: %s\n', nmfComp2Out);
    fprintf('Saved NMF reconstruction heatmap: %s\n', nmfRecOut);
    if strlength(nmfStabilityOut) > 0
        fprintf('Saved NMF stability plot: %s\n', nmfStabilityOut);
    end
    if strlength(nmfRec3Out) > 0
        fprintf('Saved NMF rank-3 reconstruction heatmap: %s\n', nmfRec3Out);
    end
elseif runNMF
    fprintf('NMF decomposition requested but no NMF outputs were generated.\n');
end

if ranSVD && ranNMF
    fprintf('Decomposition paths executed: both\n');
elseif ranSVD
    fprintf('Decomposition paths executed: SVD only\n');
elseif ranNMF
    fprintf('Decomposition paths executed: NMF only\n');
else
    fprintf('Decomposition paths executed: none\n');
end

fprintf('SVD 1-mode error: %.3f\n', err_svd_1);
fprintf('SVD 2-mode error: %.3f\n', err_svd_2);
fprintf('SVD 3-mode error: %.3f\n', err_svd_3);
fprintf('SVD improvement 1->2: %.3f\n', imp_svd_12);
fprintf('SVD improvement 2->3: %.3f\n', imp_svd_23);
fprintf('SVD relative improvement 2->3: %.3f\n', rel_svd_23);

fprintf('NMF rank-2 error: %.3f\n', err_nmf_2);
fprintf('NMF rank-3 error: %.3f\n', err_nmf_3);
fprintf('NMF improvement 2->3: %.3f\n', imp_nmf_23);
fprintf('NMF relative improvement 2->3: %.3f\n', rel_nmf_23);

if isfinite(rel_svd_23)
    if rel_svd_23 < 0.10
        fprintf('SVD audit summary: rank-2 likely sufficient (relative improvement 2->3 = %.3f).\n', rel_svd_23);
    else
        fprintf('SVD audit summary: rank-3 gives material improvement (relative improvement 2->3 = %.3f).\n', rel_svd_23);
    end
else
    fprintf('SVD audit summary: insufficient data for rank-3 sufficiency decision.\n');
end

if isfinite(rel_nmf_23)
    if rel_nmf_23 < 0.10
        fprintf('NMF audit summary: rank-2 likely sufficient (relative improvement 2->3 = %.3f).\n', rel_nmf_23);
    else
        fprintf('NMF audit summary: rank-3 gives material improvement (relative improvement 2->3 = %.3f).\n', rel_nmf_23);
    end
else
    fprintf('NMF audit summary: insufficient data for rank-3 sufficiency decision.\n');
end

function pngPath = export_alignment_figure(figHandle, figureName, run_output_dir)
paths = save_run_figure(figHandle, figureName, run_output_dir);
pngPath = paths.png;
end

function copyFileIfExists(srcPath, dstPath)
if strlength(string(srcPath)) == 0
    return
end
if exist(char(string(srcPath)), 'file') ~= 2
    return
end
copyfile(char(string(srcPath)), char(string(dstPath)));
end

function obsTblLong = buildSwitchingObservableLongTable(temps, S_peak, Ipeak, halfwidth_diff_norm, width_I, asym, sampleName)
X = NaN(size(Ipeak(:)));
denom = width_I(:) .* S_peak(:);
validX = isfinite(Ipeak(:)) & isfinite(width_I(:)) & isfinite(S_peak(:)) & abs(denom) > eps;
X(validX) = Ipeak(validX) ./ denom(validX);
obsNames = ["S_peak", "I_peak", "halfwidth_diff_norm", "width_I", "asym", "X"];
obsRoles = ["coordinate", "coordinate", "coordinate", "observable", "observable", "observable"];
obsUnits = ["percent", "mA", "unitless", "mA", "unitless", "unitless"];
obsValues = [S_peak(:), Ipeak(:), halfwidth_diff_norm(:), width_I(:), asym(:), X(:)];
nT = numel(temps);
nObs = numel(obsNames);
nRows = nT * nObs;

experiment = repmat("switching", nRows, 1);
sample = repmat(string(sampleName), nRows, 1);
temperature = NaN(nRows,1);
observable = strings(nRows,1);
value = NaN(nRows,1);
units = strings(nRows,1);
role = strings(nRows,1);

idx = 0;
for it = 1:nT
    for io = 1:nObs
        idx = idx + 1;
        temperature(idx) = temps(it);
        observable(idx) = obsNames(io);
        value(idx) = obsValues(it, io);
        units(idx) = obsUnits(io);
        role(idx) = obsRoles(io);
    end
end

obsTblLong = table(experiment, sample, temperature, observable, value, units, role);
end

function sampleName = deriveSwitchingSampleName(parentDir, metricType)
[~, baseName] = fileparts(char(string(parentDir)));
if strlength(string(baseName)) == 0
    baseName = 'switching_sample';
end
sampleName = string(baseName) + "_" + string(metricType);
end

function runDir = createSwitchingObservableRunDir(repoRoot, label, parentDir, metricType)
if nargin < 3
    parentDir = "";
end
if nargin < 4
    metricType = "";
end
if isappdata(0, 'runContext')
    activeRun = getappdata(0, 'runContext');
    if isstruct(activeRun) && isfield(activeRun, 'experiment') && strcmpi(string(activeRun.experiment), "switching") ...
            && isfield(activeRun, 'run_dir') && strlength(string(activeRun.run_dir)) > 0
        runDir = char(string(activeRun.run_dir));
        return;
    end
end

if exist('createRunContext', 'file') == 2
    cfgRun = struct();
    cfgRun.runLabel = char(string(label));
    cfgRun.dataset = char(string(parentDir));
    cfgRun.metricType = char(string(metricType));
    run = createSwitchingRunContext(repoRoot, cfgRun);
    runDir = run.run_dir;
    return;
end

runsRoot = switchingCanonicalRunRoot(repoRoot);
if exist(runsRoot, 'dir') ~= 7
    mkdir(runsRoot);
end

label = lower(char(string(label)));
label = regexprep(label, '[^a-zA-Z0-9_]+', '_');
label = regexprep(label, '_+', '_');
label = regexprep(label, '^_|_$', '');
if isempty(label)
    label = 'switching_observables';
end

runId = ['run_' datestr(now, 'yyyy_mm_dd_HHMMSS') '_' label];
runDir = fullfile(runsRoot, runId);
if exist(runDir, 'dir') ~= 7
    mkdir(runDir);
end

latestPtr = fullfile(repoRoot, 'results', 'switching', 'latest_run.txt');
fid = fopen(latestPtr, 'w');
if fid >= 0
    fprintf(fid, '%s', runId);
    fclose(fid);
end
end
function row = initRow()
row = struct();
row.current_mA = NaN;
row.T_K = NaN;
row.S_percent = NaN;
row.channel = NaN;
row.folder = "";
row.metricType = "";
end


function parentDir = resolveDefaultParentDir(switchMainPath)
parentDir = "";
if ~isfile(switchMainPath)
    return;
end

txt = fileread(switchMainPath);
pat = 'dir\s*=\s*"([^"]+)"';
tok = regexp(txt, pat, 'tokens', 'once');
if isempty(tok)
    return;
end

candidate = string(tok{1});
if isfolder(candidate)
    parentDir = candidate;
end
end


function outDir = resolveOutputDir(repoRoot)
if exist('getResultsDir', 'file') == 2
    outDir = getResultsDir('switching', 'alignment_audit');
else
    outDir = fullfile(repoRoot, 'results', 'switching', 'alignment_audit');
end
end


function subDirs = findAmpTempSubdirs(parentDir)
subDirs = dir(parentDir);
names = string({subDirs.name});
isSub = [subDirs.isdir] & ~startsWith(names, ".");
isTempDep = startsWith(names, "Temp Dep", 'IgnoreCase', true);
subDirs = subDirs(isSub & isTempDep);
end


function normalize_to = resolveNormalizeTo(fileList)
normalize_to = 1;
if isempty(fileList) || ~isfield(fileList, 'name')
    return;
end

if exist('resolve_preset', 'file') ~= 2 || exist('select_preset', 'file') ~= 2
    return;
end

try
    preset_name = resolve_preset(fileList(1).name, true, '1xy_3xx');
    [~, ~, ~, normalize_to_candidate] = select_preset(preset_name);
    if ~isempty(normalize_to_candidate)
        normalize_to = normalize_to_candidate;
    end
catch
    normalize_to = 1;
end
end


function [I_A, scaling_factor] = resolveCurrentAndScale(thisDir, fileList, current_mA)
I_A = current_mA / 1000;
if ~isfinite(I_A) || I_A == 0
    I_A = 1;
end

if exist('extract_current_I', 'file') == 2
    try
        I_try = extract_current_I(thisDir, fileList(1).name, NaN);
        if isfinite(I_try) && I_try ~= 0
            I_A = I_try;
        end
    catch
        % keep fallback
    end
end

scaling_factor = 1e3;
if exist('extract_growth_FIB', 'file') == 2 && exist('getScalingFactor', 'file') == 2
    try
        [growth_num, FIB_num] = extract_growth_FIB(thisDir, fileList(1).name);
        [sc_try, ~] = getScalingFactor(growth_num, FIB_num);
        if isfinite(sc_try) && sc_try ~= 0
            scaling_factor = 1e3;
        end
    catch
        % keep fallback
    end
end
end


function chList = resolveChannels(channelMode, stored_data, tableData, sortedValues, delay_ms, pulseScheme)
channelsPresent = find(~cellfun(@isempty, {tableData.ch1, tableData.ch2, tableData.ch3, tableData.ch4}));
if isempty(channelsPresent)
    chList = [];
    return;
end

if channelMode == "all"
    chList = channelsPresent;
    return;
end

stbOpts = struct();
stbOpts.useFiltered = true;
stbOpts.useCentered = false;
stbOpts.stateMethod = pulseScheme.mode;
stbOpts.skipFirstPlateaus = 1;
stbOpts.skipLastPlateaus = 0;
stbOpts.pulseScheme = pulseScheme;
stbOpts.debugMode = false;

try
    stability = analyzeSwitchingStability(stored_data, sortedValues, delay_ms, 15, stbOpts);
    ch = stability.switching.globalChannel;
    if isfinite(ch)
        chList = ch;
    else
        chList = channelsPresent(1);
    end
catch
    chList = channelsPresent(1);
end
end


function [Tvec, Svec] = extractMetricFromTable(tableData, ch, metricType, negP2P)
chName = sprintf('ch%d', ch);
if ~isfield(tableData, chName) || isempty(tableData.(chName))
    Tvec = [];
    Svec = [];
    return;
end

tbl = tableData.(chName);
Tvec = tbl(:,1);

switch string(metricType)
    case "P2P_percent"
        Svec = tbl(:,4);
        if negP2P
            Svec = -Svec;
        end
    case "meanP2P"
        Svec = tbl(:,2);
        if negP2P
            Svec = -Svec;
        end
    case "medianAbs"
        Svec = abs(tbl(:,4));
    otherwise
        error('Unknown metricType: %s', string(metricType));
end

mask = isfinite(Tvec) & isfinite(Svec);
Tvec = Tvec(mask);
Svec = Svec(mask);
end


function [Tuniq, Suniq] = collapseDuplicateTemperatures(Tvec, Svec)
if isempty(Tvec)
    Tuniq = Tvec;
    Suniq = Svec;
    return;
end

[Tuniq, ~, grp] = unique(Tvec(:));
Suniq = accumarray(grp, Svec(:), [], @mean, NaN);
end


function valsOut = chooseRepresentative(valsIn, nMax)
valsIn = valsIn(:)';
if isempty(valsIn)
    valsOut = valsIn;
    return;
end
if numel(valsIn) <= nMax
    valsOut = valsIn;
    return;
end

idx = unique(round(linspace(1, numel(valsIn), nMax)));
valsOut = valsIn(idx);
end


function selected = chooseNearestUnique(poolVals, targetVals)
selected = [];
used = false(size(poolVals));
for i = 1:numel(targetVals)
    d = abs(poolVals - targetVals(i));
    d(used) = inf;
    [dmin, idx] = min(d);
    if isfinite(dmin)
        selected(end+1) = poolVals(idx); %#ok<AGROW>
        used(idx) = true;
    end
end
selected = sort(selected);
end


function plotTemperatureCuts(ax, rawTbl, currentsToPlot)
hold(ax, 'on');
grid(ax, 'on');

if exist('turbo', 'file') == 2
    cmap = turbo(max(1, numel(currentsToPlot)));
else
    cmap = parula(max(1, numel(currentsToPlot)));
end
for i = 1:numel(currentsToPlot)
    I0 = currentsToPlot(i);
    m = abs(rawTbl.current_mA - I0) < 1e-9;
    T = rawTbl.T_K(m);
    S = rawTbl.S_percent(m);
    [T, ord] = sort(T);
    S = S(ord);

    if numel(T) < 2
        continue;
    end
    plot(ax, T, S, '-o', 'LineWidth', 1.4, 'MarkerSize', 5, ...
        'Color', cmap(i,:), 'DisplayName', sprintf('I_0 = %.0f mA', I0));
end

xlabel(ax, 'T (K)');
ylabel(ax, 'S(T,I_0) = \DeltaR/R [%]');
title(ax, 'Temperature cuts: S(T) at fixed I_0');
legend(ax, 'Location', 'bestoutside');
end


function plotCurrentCuts(ax, rawTbl, tempsToPlot, tempTol)
hold(ax, 'on');
grid(ax, 'on');

currents = unique(rawTbl.current_mA(isfinite(rawTbl.current_mA)));
currents = sort(currents(:));
if exist('turbo', 'file') == 2
    cmap = turbo(max(1, numel(tempsToPlot)));
else
    cmap = parula(max(1, numel(tempsToPlot)));
end

for i = 1:numel(tempsToPlot)
    T0 = tempsToPlot(i);
    Ilist = nan(size(currents));
    Slist = nan(size(currents));

    for j = 1:numel(currents)
        I0 = currents(j);
        m = abs(rawTbl.current_mA - I0) < 1e-9;
        T = rawTbl.T_K(m);
        S = rawTbl.S_percent(m);
        if isempty(T)
            continue;
        end

        mT = abs(round(T) - T0) <= tempTol;
        if any(mT)
            Ilist(j) = I0;
            Slist(j) = mean(S(mT), 'omitnan');
        end
    end

    valid = isfinite(Ilist) & isfinite(Slist);
    if nnz(valid) < 2
        continue;
    end

    plot(ax, Ilist(valid), Slist(valid), '-s', 'LineWidth', 1.9, 'MarkerSize', 6, ...
        'Color', cmap(i,:), 'DisplayName', sprintf('T \approx %.1f K', T0));
end

xlabel(ax, 'I_0 (mA)');
ylabel(ax, 'S(T,I_0) = \DeltaR/R [%]');
title(ax, 'Current cuts: S(I_0) at selected T');
legend(ax, 'Location', 'eastoutside');
end
function applyDivergingColormap(ax)
try
    colormap(ax, balance);
catch
    n = 256;
    n2 = floor(n/2);
    blueToWhite = [linspace(0.23, 1, n2)' linspace(0.30, 1, n2)' ones(n2,1)];
    whiteToRed = [ones(n2,1) linspace(1, 0.23, n2)' linspace(1, 0.30, n2)'];
    cmap = [blueToWhite; whiteToRed];
    colormap(ax, cmap);
end
end

