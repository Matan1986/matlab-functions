% diagnose_linear_combo_switching
% Diagnostic-only script:
% Fit Rsw(T) ~= a*AFM_basis(T) + b*FM_basis(T) + c for each current.
% No pipeline logic is modified.

% ------------------------------
% Setup
% ------------------------------
datasetName = 'MG119_60min';

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('cross_analysis', 'aging_vs_switching', ...
    ['linear_combo_alignment_' datasetName]);
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

% ------------------------------
% Per-current linear fits
% ------------------------------
aVals = nan(nCurr, 1);
bVals = nan(nCurr, 1);
cVals = nan(nCurr, 1);
r2Vals = nan(nCurr, 1);
rmseVals = nan(nCurr, 1);

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

    Xfull = [A, B, ones(n,1)];
    valid = all(isfinite(Xfull), 2) & isfinite(R);

    if nnz(valid) < 4
        warning('Too few valid points for %d mA. Skipping fit.', current_mA);
        continue;
    end

    Tv = T(valid);
    X = Xfull(valid, :);
    y = R(valid);

    theta = X \ y;
    a = theta(1);
    b = theta(2);
    c = theta(3);

    yHat = X * theta;
    resid = y - yHat;

    ssRes = sum(resid.^2);
    ssTot = sum((y - mean(y)).^2);
    if ssTot > 0
        R2 = 1 - (ssRes / ssTot);
    else
        R2 = nan;
    end
    RMSE = sqrt(mean(resid.^2));

    aVals(k) = a;
    bVals(k) = b;
    cVals(k) = c;
    r2Vals(k) = R2;
    rmseVals(k) = RMSE;

    f = figure('Color', 'w', 'Position', [100 100 1000 600], 'Visible', 'off');
    plot(Tv, y, 'ko-', 'LineWidth', 1.5, 'MarkerSize', 5); hold on;
    plot(Tv, yHat, 'r-', 'LineWidth', 2.0);
    plot(Tv, resid, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
    grid on;
    xlabel('Temperature (K)');
    ylabel('Amplitude');
    title(sprintf('%s | Linear combo fit | %dmA', datasetName, current_mA), ...
        'Interpreter', 'none');
    legend({'Rsw (measured)', 'Rhat linear', 'Residual'}, 'Location', 'best');

    outPng = fullfile(outDir, sprintf('linear_combo_vs_Rsw_%dmA.png', current_mA));
    saveas(f, outPng);
    close(f);
end

% ------------------------------
% Summary table and export
% ------------------------------
summaryTbl = table( ...
    currents, aVals, bVals, cVals, r2Vals, rmseVals, ...
    'VariableNames', {'current_mA', 'a', 'b', 'c', 'R2', 'RMSE'});

csvPath = fullfile(outDir, 'fit_summary.csv');
writetable(summaryTbl, csvPath);

% ------------------------------
% Console report
% ------------------------------
fprintf('\nLinear-combination fit summary (%s)\n', datasetName);
fprintf('%-8s %-12s %-12s %-12s %-12s %-12s\n', ...
    'Current', 'a', 'b', 'c', 'R2', 'RMSE');
for k = 1:nCurr
    fprintf('%-8d %-12.6g %-12.6g %-12.6g %-12.6g %-12.6g\n', ...
        summaryTbl.current_mA(k), ...
        summaryTbl.a(k), ...
        summaryTbl.b(k), ...
        summaryTbl.c(k), ...
        summaryTbl.R2(k), ...
        summaryTbl.RMSE(k));
end

fprintf('\nSaved CSV: %s\n', csvPath);
fprintf('Saved plots in: %s\n', outDir);

