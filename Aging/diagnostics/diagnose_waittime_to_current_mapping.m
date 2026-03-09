% diagnose_waittime_to_current_mapping
% Diagnostic-only script:
% Map aging wait-time bases to switching currents without temperature shift.
% No pipeline logic is modified.

% ------------------------------
% Setup
% ------------------------------
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('cross_analysis', 'aging_vs_switching', 'waittime_current_mapping_MG119');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% Wait-time datasets (agingConfig keys)
datasetKeys = {'MG119_3sec', 'MG119_36sec', 'MG119_6min', 'MG119_60min'};
waitLabels = {'3sec', '36sec', '6min', '60min'};
nWait = numel(datasetKeys);

% Use a single switching reference set for Rsw(T)
cfgSwitch = agingConfig('MG119_60min');
currents = cfgSwitch.switchParams.available_currents_mA(:);
Tsw_ref = cfgSwitch.Tsw(:);
nCurr = numel(currents);

% Pre-load switching curves per current
RswByCurrent = cell(nCurr,1);
for j = 1:nCurr
    rswField = sprintf('Rsw_%dmA', currents(j));
    if ~isfield(cfgSwitch, rswField)
        error('Missing switching field in cfgSwitch: %s', rswField);
    end
    RswByCurrent{j} = cfgSwitch.(rswField)(:);
end

% Storage
nRows = nWait * nCurr;
waitCol = strings(nRows,1);
currCol = nan(nRows,1);
aCol = nan(nRows,1);
bCol = nan(nRows,1);
cCol = nan(nRows,1);
R2Col = nan(nRows,1);
RMSECol = nan(nRows,1);
R2mat = nan(nWait, nCurr);

row = 0;

% ------------------------------
% Main loop: wait-time x current
% ------------------------------
for w = 1:nWait
    cfgBase = agingConfig(datasetKeys{w});
    cfgBase.doPlotting = false;
    cfgBase.saveTableMode = 'none';

    % Keep diagnostics robust against signed-FM branch issues.
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

    for j = 1:nCurr
        current_mA = currents(j);
        Rsw = RswByCurrent{j};

        cfgJ = cfgBase;
        cfgJ.current_mA = current_mA;
        cfgJ.Tsw = Tsw_ref;
        cfgJ.Rsw = Rsw;

        cfgJ.switchParams.reference_current_mA = current_mA;
        cfgJ.switchParams.allowSignedFM = false;

        % Capture stage7 verbose diagnostics to keep this script's console output concise.
        stage7Log = evalc('result = stage7_reconstructSwitching(state, cfgJ);'); %#ok<NASGU>
        close all hidden;

        Tbasis = result.Tsw(:);
        A = result.A_basis(:);
        B = result.B_basis(:);

        % Enforce the switching grid used for fitting.
        if numel(Tbasis) ~= numel(Tsw_ref) || any(abs(Tbasis - Tsw_ref) > 1e-9)
            A = interp1(Tbasis, A, Tsw_ref, 'pchip', 'extrap');
            B = interp1(Tbasis, B, Tsw_ref, 'pchip', 'extrap');
        end

        n = min([numel(A), numel(B), numel(Rsw)]);
        A = A(1:n);
        B = B(1:n);
        y = Rsw(1:n);

        X = [A, B, ones(n,1)];
        valid = all(isfinite(X), 2) & isfinite(y);

        a = NaN;
        b = NaN;
        c = NaN;
        R2 = NaN;
        RMSE = NaN;

        if nnz(valid) >= 4
            Xv = X(valid, :);
            yv = y(valid);

            theta = Xv \ yv;
            yHat = Xv * theta;
            resid = yv - yHat;

            ssRes = sum(resid.^2);
            ssTot = sum((yv - mean(yv)).^2);

            a = theta(1);
            b = theta(2);
            c = theta(3);

            if ssTot > 0
                R2 = 1 - (ssRes / ssTot);
            end
            RMSE = sqrt(mean(resid.^2));
        end

        row = row + 1;
        waitCol(row) = string(waitLabels{w});
        currCol(row) = current_mA;
        aCol(row) = a;
        bCol(row) = b;
        cCol(row) = c;
        R2Col(row) = R2;
        RMSECol(row) = RMSE;

        R2mat(w, j) = R2;
    end
end

% ------------------------------
% Save fit matrix table
% ------------------------------
fitTbl = table(waitCol, currCol, aCol, bCol, cCol, R2Col, RMSECol, ...
    'VariableNames', {'wait_time', 'current_mA', 'a', 'b', 'c', 'R2', 'RMSE'});

fitCsvPath = fullfile(outDir, 'fit_matrix.csv');
writetable(fitTbl, fitCsvPath);

% ------------------------------
% Heatmap: R2(wait, current)
% ------------------------------
f = figure('Color', 'w', 'Position', [100 100 900 500], 'Visible', 'off');
imagesc(currents, 1:nWait, R2mat);
set(gca, 'YDir', 'normal', 'YTick', 1:nWait, 'YTickLabel', waitLabels);
xlabel('current\_mA');
ylabel('wait\_time');
title('R^2 heatmap: wait time vs current');
colormap(parula);
cb = colorbar;
ylabel(cb, 'R^2');
grid on;

heatmapPath = fullfile(outDir, 'R2_heatmap_wait_vs_current.png');
saveas(f, heatmapPath);
close(f);

% ------------------------------
% Best wait-time per current
% ------------------------------
bestWait = strings(nCurr,1);
bestR2 = nan(nCurr,1);

for j = 1:nCurr
    col = R2mat(:, j);
    if all(~isfinite(col))
        bestWait(j) = "";
        bestR2(j) = NaN;
    else
        [bestR2(j), idx] = max(col, [], 'omitnan');
        bestWait(j) = string(waitLabels{idx});
    end
end

bestTbl = table(currents, bestWait, bestR2, ...
    'VariableNames', {'current_mA', 'best_wait_time', 'best_R2'});

bestCsvPath = fullfile(outDir, 'best_waittime_per_current.csv');
writetable(bestTbl, bestCsvPath);

% ------------------------------
% Console output
% ------------------------------
fprintf('\nWait-time to current mapping summary (R^2)\n');
fprintf('%-10s', 'wait\\J');
for j = 1:nCurr
    fprintf('%10dmA', currents(j));
end
fprintf('\n');
for w = 1:nWait
    fprintf('%-10s', waitLabels{w});
    for j = 1:nCurr
        fprintf('%10.4f', R2mat(w, j));
    end
    fprintf('\n');
end

fprintf('\nSaved fit matrix: %s\n', fitCsvPath);
fprintf('Saved heatmap: %s\n', heatmapPath);
fprintf('Saved best-wait table: %s\n', bestCsvPath);


