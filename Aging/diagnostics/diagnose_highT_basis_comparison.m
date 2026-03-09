% diagnose_highT_basis_comparison
% Diagnostic-only script:
% Compare AFM-only, FM-only, and AFM+FM fits in high-temperature region
% (T > 25 K) and export detailed diagnostics.
% No pipeline logic is modified.

% ------------------------------
% Setup
% ------------------------------
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

diagRoot = getResultsDir('cross_analysis', 'aging_vs_switching', 'highT_basis_comparison');
plotDir = fullfile(diagRoot, 'plots');
if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end

TminHigh = 25;

% ------------------------------
% Switching source (same as previous diagnostics)
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
% Wait-time datasets (same set as mapping diagnostics)
% ------------------------------
datasetKeys = {'MG119_3sec', 'MG119_36sec', 'MG119_6min', 'MG119_60min'};
waitLabels = {'3 sec', '36 sec', '6 min', '60 min'};
nWait = numel(datasetKeys);

stateByWait = cell(nWait,1);
cfgByWait = cell(nWait,1);

for w = 1:nWait
    cfgBase = agingConfig(datasetKeys{w});
    cfgBase.doPlotting = false;
    cfgBase.saveTableMode = 'none';

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
basisWait = strings(nCurr,1);

N_highT = nan(nCurr,1);
Tmin_highT = nan(nCurr,1);
Tmax_highT = nan(nCurr,1);
std_Rsw = nan(nCurr,1);

R2_AFM = nan(nCurr,1);
R2_FM = nan(nCurr,1);
R2_AFM_FM = nan(nCurr,1);

RMSE_AFM = nan(nCurr,1);
RMSE_FM = nan(nCurr,1);
RMSE_AFM_FM = nan(nCurr,1);

a = nan(nCurr,1);
b = nan(nCurr,1);
c = nan(nCurr,1);

corr_AFM_FM = nan(nCurr,1);
cond_design = nan(nCurr,1);

T_peak_switching = nan(nCurr,1);
T_peak_AFM = nan(nCurr,1);
T_peak_FM = nan(nCurr,1);

highTForBasisPlot = cell(nCurr,1);

% ------------------------------
% Main loop
% ------------------------------
for j = 1:nCurr
    current_mA = currents(j);
    Rsw = RswByCurrent{j};

    A_all = cell(nWait,1);
    B_all = cell(nWait,1);
    R2wait_full = nan(nWait,1);

    % Rebuild the same per-current basis selection used in prior diagnostics
    for w = 1:nWait
        cfgJ = cfgByWait{w};
        stateW = stateByWait{w};

        cfgJ.current_mA = current_mA;
        cfgJ.Tsw = Tsw_ref;
        cfgJ.Rsw = Rsw;
        cfgJ.switchParams.reference_current_mA = current_mA;
        cfgJ.switchParams.allowSignedFM = false;

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

        fitFull = fitAB(A, B, Rsw);
        R2wait_full(w) = fitFull.R2;
    end

    [~, bestIdx] = max(R2wait_full, [], 'omitnan');
    if ~isfinite(bestIdx) || bestIdx < 1 || bestIdx > nWait
        continue;
    end

    basisWait(j) = string(waitLabels{bestIdx});
    A_best = A_all{bestIdx};
    B_best = B_all{bestIdx};

    % High-T region only
    maskHigh = Tsw_ref > TminHigh;

    T_high = Tsw_ref(maskHigh);
    A_high = A_best(maskHigh);
    B_high = B_best(maskHigh);
    R_high = Rsw(maskHigh);

    validAll = isfinite(T_high) & isfinite(A_high) & isfinite(B_high) & isfinite(R_high);

    N_highT(j) = nnz(validAll);
    Tmin_highT(j) = TminHigh;
    if any(validAll)
        Tmax_highT(j) = max(T_high(validAll));
        std_Rsw(j) = std(R_high(validAll), 'omitnan');

        % Collinearity diagnostics
        [rAB, ~, ~] = safeCorr(A_high(validAll), B_high(validAll));
        corr_AFM_FM(j) = rAB;

        Xab = [A_high(validAll), B_high(validAll)];
        if size(Xab,1) >= 2
            cond_design(j) = cond(Xab);
        end

        % Peak location alignment diagnostics (optional task)
        [~, idxR] = max(R_high(validAll));
        [~, idxA] = max(A_high(validAll));
        [~, idxB] = max(B_high(validAll));
        Tv = T_high(validAll);
        T_peak_switching(j) = Tv(idxR);
        T_peak_AFM(j) = Tv(idxA);
        T_peak_FM(j) = Tv(idxB);

        highTForBasisPlot{j} = struct('T', Tv, 'A', A_high(validAll), 'B', B_high(validAll));
    else
        highTForBasisPlot{j} = struct('T', [], 'A', [], 'B', []);
    end

    fitA = fitAonly(A_high, R_high);
    fitB = fitBonly(B_high, R_high);
    fitC = fitAB(A_high, B_high, R_high);

    R2_AFM(j) = fitA.R2;
    R2_FM(j) = fitB.R2;
    R2_AFM_FM(j) = fitC.R2;

    RMSE_AFM(j) = fitA.RMSE;
    RMSE_FM(j) = fitB.RMSE;
    RMSE_AFM_FM(j) = fitC.RMSE;

    a(j) = fitC.a;
    b(j) = fitC.b;
    c(j) = fitC.c;
end

% ------------------------------
% Save tables
% ------------------------------
diagTbl = table( ...
    currents, N_highT, Tmin_highT, Tmax_highT, std_Rsw, ...
    R2_AFM, R2_FM, R2_AFM_FM, ...
    RMSE_AFM, RMSE_FM, RMSE_AFM_FM, ...
    a, b, c, corr_AFM_FM, cond_design, ...
    T_peak_switching, T_peak_AFM, T_peak_FM, ...
    basisWait, ...
    'VariableNames', { ...
    'current_mA', 'N_highT', 'Tmin_highT', 'Tmax_highT', 'std_Rsw', ...
    'R2_AFM', 'R2_FM', 'R2_AFM_FM', ...
    'RMSE_AFM', 'RMSE_FM', 'RMSE_AFM_FM', ...
    'a', 'b', 'c', 'corr_AFM_FM', 'cond_design', ...
    'T_peak_switching', 'T_peak_AFM', 'T_peak_FM', ...
    'basis_wait_time'});

csvMain = fullfile(diagRoot, 'highT_basis_diagnostics.csv');
writetable(diagTbl, csvMain);

% Keep existing compact output for backward compatibility
compatTbl = diagTbl(:, {'current_mA','basis_wait_time','R2_AFM','R2_FM','R2_AFM_FM','a','b','c'});
writetable(compatTbl, fullfile(diagRoot, 'highT_basis_comparison.csv'));

% ------------------------------
% Plots
% ------------------------------
% Requested: fit weights vs current
fW = figure('Color','w','Position',[100 100 820 520],'Visible','off');
plot(currents, a, 'o-', 'LineWidth', 1.8, 'MarkerSize', 7); hold on;
plot(currents, b, 's-', 'LineWidth', 1.8, 'MarkerSize', 7);
grid on;
xlabel('Current (mA)');
ylabel('Fit weight');
legend({'a (AFM weight)','b (FM weight)'}, 'Location', 'best');
title('High-T fit weights vs current');
saveas(fW, fullfile(diagRoot, 'fit_weights_vs_current.png'));
close(fW);

% Requested: Rsw high-T comparison 20 mA vs 25 mA
idx20 = find(currents == 20, 1);
idx25 = find(currents == 25, 1);
if ~isempty(idx20) && ~isempty(idx25)
    mask20 = Tsw_ref > TminHigh & isfinite(RswByCurrent{idx20});
    mask25 = Tsw_ref > TminHigh & isfinite(RswByCurrent{idx25});

    T20 = Tsw_ref(mask20);
    R20 = RswByCurrent{idx20}(mask20);
    T25 = Tsw_ref(mask25);
    R25 = RswByCurrent{idx25}(mask25);

    fComp = figure('Color','w','Position',[100 100 820 520],'Visible','off');
    plot(T20, R20, 'o-', 'LineWidth', 1.8, 'MarkerSize', 7); hold on;
    plot(T25, R25, 's-', 'LineWidth', 1.8, 'MarkerSize', 7);
    grid on;
    xlabel('Temperature (K)');
    ylabel('Rsw');
    legend({'20 mA','25 mA'}, 'Location', 'best');
    title('High-T switching comparison (T > 25 K)');
    saveas(fComp, fullfile(diagRoot, 'Rsw_highT_20_vs_25.png'));
    close(fComp);
end

% Requested: AFM/FM basis shapes in high-T window for each current
fBasis = figure('Color','w','Position',[100 100 1200 780],'Visible','off');
tl = tiledlayout(3,2,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>
for j = 1:nCurr
    nexttile;
    dataJ = highTForBasisPlot{j};
    if isempty(dataJ.T)
        axis off;
        title(sprintf('%dmA (no valid high-T data)', currents(j)));
        continue;
    end
    plot(dataJ.T, dataJ.A, 'o-', 'LineWidth', 1.3, 'MarkerSize', 5); hold on;
    plot(dataJ.T, dataJ.B, 's-', 'LineWidth', 1.3, 'MarkerSize', 5);
    grid on;
    xlabel('T (K)');
    ylabel('Basis amplitude');
    title(sprintf('%dmA | %s', currents(j), basisWait(j)), 'Interpreter', 'none');
    if j == 1
        legend({'AFM_{highT}','FM_{highT}'}, 'Location', 'best');
    end
end
saveas(fBasis, fullfile(diagRoot, 'basis_shapes_highT.png'));
close(fBasis);

% Keep existing R2 model plots in dedicated folder
saveR2Plot(currents, R2_AFM, 'R^2_{AFM}', 'High-T AFM-only fit', fullfile(plotDir, 'R2_AFM_vs_current.png'));
saveR2Plot(currents, R2_FM, 'R^2_{FM}', 'High-T FM-only fit', fullfile(plotDir, 'R2_FM_vs_current.png'));
saveR2Plot(currents, R2_AFM_FM, 'R^2_{AFM+FM}', 'High-T AFM+FM fit', fullfile(plotDir, 'R2_AFM_FM_vs_current.png'));

fR = figure('Color','w','Position',[100 100 820 520],'Visible','off');
plot(currents, R2_AFM, 'o-', 'LineWidth', 1.8, 'MarkerSize', 7); hold on;
plot(currents, R2_FM, 's-', 'LineWidth', 1.8, 'MarkerSize', 7);
plot(currents, R2_AFM_FM, 'd-', 'LineWidth', 1.8, 'MarkerSize', 7);
grid on;
xlabel('Current (mA)');
ylabel('R^2 (T > 25 K)');
legend({'AFM only', 'FM only', 'AFM + FM'}, 'Location', 'best');
title('High-T basis comparison');
saveas(fR, fullfile(plotDir, 'R2_models_vs_current.png'));
close(fR);

% ------------------------------
% Console summary
% ------------------------------
fprintf('\nHigh-T diagnostics summary (T > %.1f K)\n', TminHigh);
disp(diagTbl(:, {'current_mA','N_highT','R2_AFM','R2_FM','R2_AFM_FM','a','b','corr_AFM_FM','cond_design', ...
                 'T_peak_switching','T_peak_AFM','T_peak_FM'}));

fprintf('Saved table: %s\n', csvMain);
fprintf('Saved plots in: %s and %s\n', diagRoot, plotDir);

% ============================== Local functions ==============================
function fit = fitAonly(A, R)
A = A(:);
R = R(:);
n = min(numel(A), numel(R));
A = A(1:n);
R = R(1:n);
X = [A, ones(n,1)];
valid = all(isfinite(X),2) & isfinite(R);
fit = struct('a',NaN,'c',NaN,'R2',NaN,'RMSE',NaN);
if nnz(valid) < 3
    return;
end
Xv = X(valid,:);
y = R(valid);
theta = Xv \ y;
yhat = Xv * theta;
fit.a = theta(1);
fit.c = theta(2);
fit.R2 = computeR2(y, yhat);
fit.RMSE = sqrt(mean((y-yhat).^2));
end

function fit = fitBonly(B, R)
B = B(:);
R = R(:);
n = min(numel(B), numel(R));
B = B(1:n);
R = R(1:n);
X = [B, ones(n,1)];
valid = all(isfinite(X),2) & isfinite(R);
fit = struct('b',NaN,'c',NaN,'R2',NaN,'RMSE',NaN);
if nnz(valid) < 3
    return;
end
Xv = X(valid,:);
y = R(valid);
theta = Xv \ y;
yhat = Xv * theta;
fit.b = theta(1);
fit.c = theta(2);
fit.R2 = computeR2(y, yhat);
fit.RMSE = sqrt(mean((y-yhat).^2));
end

function fit = fitAB(A, B, R)
A = A(:);
B = B(:);
R = R(:);
n = min([numel(A), numel(B), numel(R)]);
A = A(1:n);
B = B(1:n);
R = R(1:n);
X = [A, B, ones(n,1)];
valid = all(isfinite(X),2) & isfinite(R);
fit = struct('a',NaN,'b',NaN,'c',NaN,'R2',NaN,'RMSE',NaN);
if nnz(valid) < 4
    return;
end
Xv = X(valid,:);
y = R(valid);
theta = Xv \ y;
yhat = Xv * theta;
fit.a = theta(1);
fit.b = theta(2);
fit.c = theta(3);
fit.R2 = computeR2(y, yhat);
fit.RMSE = sqrt(mean((y-yhat).^2));
end

function R2 = computeR2(y, yhat)
ssRes = sum((y - yhat).^2);
ssTot = sum((y - mean(y)).^2);
if ssTot > 0
    R2 = 1 - ssRes / ssTot;
else
    R2 = NaN;
end
end

function saveR2Plot(x, y, ylab, ttl, outPath)
f = figure('Color','w','Position',[100 100 780 480],'Visible','off');
plot(x, y, 'o-', 'LineWidth', 1.8, 'MarkerSize', 7, 'Color', [0.1 0.35 0.75]);
grid on;
xlabel('Current (mA)');
ylabel(ylab);
title(ttl);
saveas(f, outPath);
close(f);
end


