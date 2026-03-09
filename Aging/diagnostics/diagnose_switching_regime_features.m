% diagnose_switching_regime_features
% Diagnostic-only script:
% Analyze AFM/FM fit weights, temperature-split fit quality, and switching
% curve features vs current using the same switching source as the wait-time
% mapping diagnostic.
% No pipeline logic is modified.

% ------------------------------
% Setup
% ------------------------------
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

diagRoot = getResultsDir('cross_analysis', 'aging_vs_switching', 'switching_feature_analysis');
plotDir = fullfile(diagRoot, 'plots');
if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end

% ------------------------------
% Switching source (reused exactly from previous diagnostic)
% ------------------------------
cfgSwitch = agingConfig('MG119_60min');
currents = cfgSwitch.switchParams.available_currents_mA(:);
Tsw_ref = cfgSwitch.Tsw(:);
nCurr = numel(currents);

RswByCurrent = cell(nCurr,1);
for j = 1:nCurr
    rswField = sprintf('Rsw_%dmA', currents(j));
    if ~isfield(cfgSwitch, rswField)
        error('Missing switching field in cfgSwitch: %s', rswField);
    end
    RswByCurrent{j} = cfgSwitch.(rswField)(:);
end

% ------------------------------
% Wait-time datasets (same family as mapping diagnostic)
% ------------------------------
datasetKeys = {'MG119_3sec', 'MG119_36sec', 'MG119_6min', 'MG119_60min'};
waitLabels = {'3 sec', '36 sec', '6 min', '60 min'};
nWait = numel(datasetKeys);

% Build stage1-6 states once per wait-time dataset
stateByWait = cell(nWait,1);
cfgByWait = cell(nWait,1);

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

    stateByWait{w} = state;
    cfgByWait{w} = cfgBase;
end

% ------------------------------
% Storage
% ------------------------------
bestWaitLabel = strings(nCurr,1);
bestWaitR2 = nan(nCurr,1);

aVals = nan(nCurr,1);
bVals = nan(nCurr,1);
cVals = nan(nCurr,1);
R2Vals = nan(nCurr,1);
RMSEVals = nan(nCurr,1);

R2LowT = nan(nCurr,1);
R2HighT = nan(nCurr,1);

T_peak_high = nan(nCurr,1);
peak_height_high = nan(nCurr,1);
lowT_area = nan(nCurr,1);
lowT_width = nan(nCurr,1);

R2wait = nan(nWait, nCurr);

% ------------------------------
% Main diagnostics loop
% ------------------------------
for j = 1:nCurr
    current_mA = currents(j);
    Rsw = RswByCurrent{j};

    A_all = cell(nWait,1);
    B_all = cell(nWait,1);

    for w = 1:nWait
        cfgJ = cfgByWait{w};
        stateW = stateByWait{w};

        cfgJ.current_mA = current_mA;
        cfgJ.Tsw = Tsw_ref;
        cfgJ.Rsw = Rsw;
        cfgJ.switchParams.reference_current_mA = current_mA;
        cfgJ.switchParams.allowSignedFM = false;

        % Capture stage7 verbose output to keep console concise.
        stage7Log = evalc('result = stage7_reconstructSwitching(stateW, cfgJ);'); %#ok<NASGU>
        close all hidden;

        Tbasis = result.Tsw(:);
        A = result.A_basis(:);
        B = result.B_basis(:);

        if numel(Tbasis) ~= numel(Tsw_ref) || any(abs(Tbasis - Tsw_ref) > 1e-9)
            A = interp1(Tbasis, A, Tsw_ref, 'pchip', 'extrap');
            B = interp1(Tbasis, B, Tsw_ref, 'pchip', 'extrap');
        end

        A_all{w} = A;
        B_all{w} = B;

        fitW = fitLinearModel(A, B, Rsw);
        R2wait(w, j) = fitW.R2;
    end

    [bestR2, bestIdx] = max(R2wait(:, j), [], 'omitnan');
    if ~isfinite(bestR2)
        continue;
    end

    A_best = A_all{bestIdx};
    B_best = B_all{bestIdx};

    fitFull = fitLinearModel(A_best, B_best, Rsw);

    aVals(j) = fitFull.a;
    bVals(j) = fitFull.b;
    cVals(j) = fitFull.c;
    R2Vals(j) = fitFull.R2;
    RMSEVals(j) = fitFull.RMSE;
    bestWaitLabel(j) = string(waitLabels{bestIdx});
    bestWaitR2(j) = bestR2;

    maskLow = Tsw_ref < 20;
    maskHigh = Tsw_ref > 25;

    fitLow = fitLinearModel(A_best(maskLow), B_best(maskLow), Rsw(maskLow));
    fitHigh = fitLinearModel(A_best(maskHigh), B_best(maskHigh), Rsw(maskHigh));

    R2LowT(j) = fitLow.R2;
    R2HighT(j) = fitHigh.R2;

    % Switching-curve feature extraction (from measured Rsw only).
    validHigh = isfinite(Tsw_ref) & isfinite(Rsw) & (Tsw_ref > 25);
    if any(validHigh)
        Th = Tsw_ref(validHigh);
        Rh = Rsw(validHigh);
        [peak_height_high(j), idxPk] = max(Rh);
        T_peak_high(j) = Th(idxPk);
    end

    validLow = isfinite(Tsw_ref) & isfinite(Rsw) & (Tsw_ref < 20);
    if nnz(validLow) >= 2
        Tl = Tsw_ref(validLow);
        Rl = Rsw(validLow);
        lowT_area(j) = trapz(Tl, Rl);
        lowT_width(j) = computeHalfMaxWidth(Tl, Rl);
    end
end

% ------------------------------
% Save tables
% ------------------------------
fitTbl = table(currents, bestWaitLabel, aVals, bVals, cVals, R2Vals, RMSEVals, ...
    'VariableNames', {'current_mA', 'basis_wait_time', 'a', 'b', 'c', 'R2', 'RMSE'});

splitTbl = table(currents, bestWaitLabel, R2LowT, R2HighT, ...
    'VariableNames', {'current_mA', 'basis_wait_time', 'R2_lowT', 'R2_highT'});

featTbl = table(currents, T_peak_high, peak_height_high, lowT_area, lowT_width, ...
    'VariableNames', {'current_mA', 'T_peak_high', 'peak_height_high', 'lowT_area', 'lowT_width'});

writetable(fitTbl, fullfile(diagRoot, 'fit_weights_vs_current.csv'));
writetable(splitTbl, fullfile(diagRoot, 'R2_split_by_temperature.csv'));
writetable(featTbl, fullfile(diagRoot, 'switching_features_vs_current.csv'));

% ------------------------------
% Plots
% ------------------------------
saveMetricPlot(currents, aVals, 'a', 'AFM weight a vs current', fullfile(plotDir, 'a_vs_current.png'));
saveMetricPlot(currents, bVals, 'b', 'FM weight b vs current', fullfile(plotDir, 'b_vs_current.png'));
saveMetricPlot(currents, R2LowT, 'R^2_{lowT}', 'Low-T fit quality (T < 20 K)', fullfile(plotDir, 'R2_lowT_vs_current.png'));
saveMetricPlot(currents, R2HighT, 'R^2_{highT}', 'High-T fit quality (T > 25 K)', fullfile(plotDir, 'R2_highT_vs_current.png'));
saveMetricPlot(currents, T_peak_high, 'T_{peak,high} (K)', 'High-T peak temperature vs current', fullfile(plotDir, 'T_peak_high_vs_current.png'));
saveMetricPlot(currents, lowT_area, 'lowT area', 'Low-T area vs current', fullfile(plotDir, 'lowT_area_vs_current.png'));

% ------------------------------
% Console summary
% ------------------------------
fprintf('\nDiagnostics summary (best basis wait-time per current)\n');
disp(fitTbl);

disp(splitTbl);

disp(featTbl);

fprintf('Saved: %s\n', fullfile(diagRoot, 'fit_weights_vs_current.csv'));
fprintf('Saved: %s\n', fullfile(diagRoot, 'R2_split_by_temperature.csv'));
fprintf('Saved: %s\n', fullfile(diagRoot, 'switching_features_vs_current.csv'));
fprintf('Saved plots in: %s\n', plotDir);

% ============================== Local functions ==============================
function fit = fitLinearModel(A, B, R)
A = A(:);
B = B(:);
R = R(:);
n = min([numel(A), numel(B), numel(R)]);
A = A(1:n);
B = B(1:n);
R = R(1:n);

X = [A, B, ones(n,1)];
valid = all(isfinite(X), 2) & isfinite(R);

fit = struct('a', NaN, 'b', NaN, 'c', NaN, 'R2', NaN, 'RMSE', NaN);
if nnz(valid) < 4
    return;
end

Xv = X(valid, :);
yv = R(valid);
theta = Xv \ yv;
yhat = Xv * theta;
resid = yv - yhat;

ssRes = sum(resid.^2);
ssTot = sum((yv - mean(yv)).^2);

fit.a = theta(1);
fit.b = theta(2);
fit.c = theta(3);
if ssTot > 0
    fit.R2 = 1 - ssRes / ssTot;
end
fit.RMSE = sqrt(mean(resid.^2));
end

function w = computeHalfMaxWidth(T, R)
T = T(:);
R = R(:);
valid = isfinite(T) & isfinite(R);
T = T(valid);
R = R(valid);

if numel(T) < 2
    w = NaN;
    return;
end

peak = max(R);
if ~isfinite(peak) || peak <= 0
    w = NaN;
    return;
end

thr = 0.5 * peak;
idx = find(R >= thr);
if isempty(idx)
    w = NaN;
else
    w = T(max(idx)) - T(min(idx));
end
end

function saveMetricPlot(x, y, ylab, ttl, outPath)
f = figure('Color', 'w', 'Position', [100 100 780 480], 'Visible', 'off');
plot(x, y, 'o-', 'LineWidth', 1.8, 'MarkerSize', 7, 'Color', [0.1 0.35 0.75]);
grid on;
xlabel('Current (mA)');
ylabel(ylab);
title(ttl);
saveas(f, outPath);
close(f);
end


