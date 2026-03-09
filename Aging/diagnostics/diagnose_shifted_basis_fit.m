% diagnose_shifted_basis_fit
% Diagnostic-only script:
% Compare AFM-shift and FM-shift linear models for Rsw(T).
% No pipeline logic is modified.

% ------------------------------
% Setup
% ------------------------------
datasetName = 'MG119_60min';
shiftGrid = (-10:0.5:10)';

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('cross_analysis', 'aging_vs_switching', ...
    ['shifted_basis_comparison_' datasetName]);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% ------------------------------
% Build stage1-6 state once
% ------------------------------
cfgBase = agingConfig(datasetName);
cfgBase.doPlotting = false;
cfgBase.saveTableMode = 'none';

% Keep this script robust against known signed-FM diagnostic branch issues.
cfgBase.allowSignedFM = false;
if isfield(cfgBase, 'switchParams') && isstruct(cfgBase.switchParams)
    cfgBase.switchParams.allowSignedFM = false;
end

if isfield(cfgBase, 'debug') && isstruct(cfgBase.debug)
    cfgBase.debug.enable = false;
    cfgBase.debug.plotSwitching = false;
    cfgBase.debug.plotGeometry = false;
    cfgBase.debug.saveOutputs = false;
end

cfgBase = stage0_setupPaths(cfgBase);
state = stage1_loadData(cfgBase);
state = stage2_preprocess(state, cfgBase);
state = stage3_computeDeltaM(state, cfgBase);
state = stage4_analyzeAFM_FM(state, cfgBase);
state = stage5_fitFMGaussian(state, cfgBase);
state = stage6_extractMetrics(state, cfgBase);

currents = cfgBase.switchParams.available_currents_mA(:);
nCurr = numel(currents);

bestShiftAFM = nan(nCurr, 1);
bestR2AFM = nan(nCurr, 1);
bestShiftFM = nan(nCurr, 1);
bestR2FM = nan(nCurr, 1);

for k = 1:nCurr
    current_mA = currents(k);

    cfgJ = cfgBase;
    cfgJ.current_mA = current_mA;

    rswField = sprintf('Rsw_%dmA', current_mA);
    if ~isfield(cfgJ, rswField)
        warning('Missing field %s. Skipping current %d mA.', rswField, current_mA);
        continue;
    end

    cfgJ.Rsw = cfgJ.(rswField);
    cfgJ.switchParams.reference_current_mA = current_mA;
    cfgJ.switchParams.allowSignedFM = false;

    [result, ~] = stage7_reconstructSwitching(state, cfgJ);

    T = result.Tsw(:);
    A = result.A_basis(:);
    B = result.B_basis(:);
    R = cfgJ.Rsw(:);

    n = min([numel(T), numel(A), numel(B), numel(R)]);
    T = T(1:n);
    A = A(1:n);
    B = B(1:n);
    R = R(1:n);

    % Model A: shift AFM only.
    bestA.R2 = -inf;
    bestA.shift = nan;
    bestA.y = nan(size(R));

    % Model B: shift FM only.
    bestB.R2 = -inf;
    bestB.shift = nan;
    bestB.y = nan(size(R));

    for d = 1:numel(shiftGrid)
        delta = shiftGrid(d);

        Ashift = interp1(T, A, T - delta, 'pchip', 'extrap');
        Xafm = [Ashift, B, ones(n,1)];
        validA = all(isfinite(Xafm), 2) & isfinite(R);
        if nnz(validA) >= 4
            XA = Xafm(validA, :);
            yA = R(validA);
            thetaA = XA \ yA;
            yHatA = XA * thetaA;
            ssResA = sum((yA - yHatA).^2);
            ssTotA = sum((yA - mean(yA)).^2);
            if ssTotA > 0
                R2A = 1 - (ssResA / ssTotA);
                if R2A > bestA.R2
                    bestA.R2 = R2A;
                    bestA.shift = delta;
                    yPlotA = nan(n,1);
                    yPlotA(validA) = yHatA;
                    bestA.y = yPlotA;
                end
            end
        end

        Bshift = interp1(T, B, T - delta, 'pchip', 'extrap');
        Xfm = [A, Bshift, ones(n,1)];
        validB = all(isfinite(Xfm), 2) & isfinite(R);
        if nnz(validB) >= 4
            XB = Xfm(validB, :);
            yB = R(validB);
            thetaB = XB \ yB;
            yHatB = XB * thetaB;
            ssResB = sum((yB - yHatB).^2);
            ssTotB = sum((yB - mean(yB)).^2);
            if ssTotB > 0
                R2B = 1 - (ssResB / ssTotB);
                if R2B > bestB.R2
                    bestB.R2 = R2B;
                    bestB.shift = delta;
                    yPlotB = nan(n,1);
                    yPlotB(validB) = yHatB;
                    bestB.y = yPlotB;
                end
            end
        end
    end

    if isfinite(bestA.R2)
        bestShiftAFM(k) = bestA.shift;
        bestR2AFM(k) = bestA.R2;
    end
    if isfinite(bestB.R2)
        bestShiftFM(k) = bestB.shift;
        bestR2FM(k) = bestB.R2;
    end

    fA = figure('Color', 'w', 'Position', [100 100 1000 600], 'Visible', 'off');
    plot(T, R, 'ko-', 'LineWidth', 1.5, 'MarkerSize', 5); hold on;
    plot(T, bestA.y, 'r-', 'LineWidth', 2.0);
    grid on;
    xlabel('Temperature (K)');
    ylabel('Amplitude');
    title(sprintf('%s | AFM-shift model | %dmA | best \\Delta = %.2f K | R^2 = %.4f', ...
        datasetName, current_mA, bestShiftAFM(k), bestR2AFM(k)), 'Interpreter', 'tex');
    legend({'Rsw (measured)', 'Rhat (best AFM shift)'}, 'Location', 'best');
    saveas(fA, fullfile(outDir, sprintf('AFM_shift_fit_%dmA.png', current_mA)));
    close(fA);

    fB = figure('Color', 'w', 'Position', [100 100 1000 600], 'Visible', 'off');
    plot(T, R, 'ko-', 'LineWidth', 1.5, 'MarkerSize', 5); hold on;
    plot(T, bestB.y, 'b-', 'LineWidth', 2.0);
    grid on;
    xlabel('Temperature (K)');
    ylabel('Amplitude');
    title(sprintf('%s | FM-shift model | %dmA | best \\Delta = %.2f K | R^2 = %.4f', ...
        datasetName, current_mA, bestShiftFM(k), bestR2FM(k)), 'Interpreter', 'tex');
    legend({'Rsw (measured)', 'Rhat (best FM shift)'}, 'Location', 'best');
    saveas(fB, fullfile(outDir, sprintf('FM_shift_fit_%dmA.png', current_mA)));
    close(fB);
end

summaryTbl = table( ...
    currents, bestShiftAFM, bestR2AFM, bestShiftFM, bestR2FM, ...
    'VariableNames', {'current_mA', 'best_shift_AFM', 'R2_AFM_shift', ...
    'best_shift_FM', 'R2_FM_shift'});

csvPath = fullfile(outDir, 'fit_summary_shifted_basis.csv');
writetable(summaryTbl, csvPath);

fprintf('\nShifted-basis comparison summary (%s)\n', datasetName);
fprintf('%-8s %-18s %-18s\n', 'Current', 'R2 (AFM shift)', 'R2 (FM shift)');
for k = 1:nCurr
    fprintf('%-8d %-18.6g %-18.6g\n', ...
        summaryTbl.current_mA(k), ...
        summaryTbl.R2_AFM_shift(k), ...
        summaryTbl.R2_FM_shift(k));
end

fprintf('\nSaved CSV: %s\n', csvPath);
fprintf('Saved plots in: %s\n', outDir);

