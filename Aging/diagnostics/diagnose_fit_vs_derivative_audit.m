% diagnose_fit_vs_derivative_audit
% Diagnostics-only audit of existing fit-based decomposition.
% Produces per-run figures and a summary CSV across all wait-time datasets.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('aging', 'decomposition', 'fit_vs_derivative_audit');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

datasets = {
    'MG119_3sec',  '3s';
    'MG119_36sec', '36s';
    'MG119_6min',  '6min';
    'MG119_60min', '60min'
};

wait_col = strings(0,1);
dataset_col = strings(0,1);
Tp_col = nan(0,1);
N_col = nan(0,1);

DipA_col = nan(0,1);
DipArea_col = nan(0,1);
DipSigma_col = nan(0,1);
DipT0_col = nan(0,1);

StepAmp_col = nan(0,1);
StepWidth_col = nan(0,1);
Offset_col = nan(0,1);
Slope_col = nan(0,1);

R2_col = nan(0,1);
RMSE_col = nan(0,1);
NRMSE_col = nan(0,1);
Chi2_col = nan(0,1);
ResidualL2_col = nan(0,1);
ResidualRMS_col = nan(0,1);
ResidualMean_col = nan(0,1);
ResidualStd_col = nan(0,1);
FitAvailable_col = false(0,1);

for d = 1:size(datasets,1)
    datasetKey = datasets{d,1};
    waitTag = datasets{d,2};

    cfg = agingConfig(datasetKey);
    cfg.doPlotting = false;
    cfg.saveTableMode = 'none';

    if isfield(cfg, 'debug') && isstruct(cfg.debug)
        cfg.debug.enable = false;
        cfg.debug.plotGeometry = false;
        cfg.debug.plotSwitching = false;
        cfg.debug.saveOutputs = false;
    end

    cfg = stage0_setupPaths(cfg);
    state = stage1_loadData(cfg);
    state = stage2_preprocess(state, cfg);
    state = stage3_computeDeltaM(state, cfg);
    state = stage4_analyzeAFM_FM(state, cfg);
    state = stage5_fitFMGaussian(state, cfg);

    pauseRuns = getPauseRuns(state);

    for i = 1:numel(pauseRuns)
        pr = pauseRuns(i);

        [T, dM] = extractDataCurve(pr);
        fitY = getFieldOrEmpty(pr, 'fit_curve');
        fitY = fitY(:);

        n = min([numel(T), numel(dM), numel(fitY)]);
        if n == 0
            continue;
        end

        T = T(1:n);
        dM = dM(1:n);
        fitY = fitY(1:n);

        Tp = getScalarOrNaN(pr, 'waitK');
        x = T - Tp;

        residual = dM - fitY;
        dData = gradientFinite(T, dM);
        dFit = gradientFinite(T, fitY);

        makeRunFigure(x, dM, fitY, residual, dData, dFit, Tp, waitTag, outDir);

        validResidual = isfinite(residual);
        if any(validResidual)
            residualL2 = norm(residual(validResidual), 2);
            residualRMS = sqrt(mean(residual(validResidual).^2, 'omitnan'));
            residualMean = mean(residual(validResidual), 'omitnan');
            residualStd = std(residual(validResidual), 0, 'omitnan');
        else
            residualL2 = NaN;
            residualRMS = NaN;
            residualMean = NaN;
            residualStd = NaN;
        end

        dipA = getScalarOrNaN(pr, 'Dip_A');
        dipSigma = getScalarOrNaN(pr, 'Dip_sigma');
        if isfinite(dipA) && isfinite(dipSigma)
            dipArea = dipA * sqrt(2*pi) * dipSigma;
        else
            dipArea = getScalarOrNaN(pr, 'Dip_area');
        end

        wait_col(end+1,1) = string(waitTag); %#ok<AGROW>
        dataset_col(end+1,1) = string(datasetKey); %#ok<AGROW>
        Tp_col(end+1,1) = Tp; %#ok<AGROW>
        N_col(end+1,1) = n; %#ok<AGROW>

        DipA_col(end+1,1) = dipA; %#ok<AGROW>
        DipArea_col(end+1,1) = dipArea; %#ok<AGROW>
        DipSigma_col(end+1,1) = dipSigma; %#ok<AGROW>
        DipT0_col(end+1,1) = getScalarOrNaN(pr, 'Dip_T0'); %#ok<AGROW>

        StepAmp_col(end+1,1) = getFirstFinite(pr, {'FM_step_A','FM_A','FM_step','FM_step_raw'}); %#ok<AGROW>
        StepWidth_col(end+1,1) = getFirstFinite(pr, {'FM_step_width','FM_w','step_w','fit_w','w'}); %#ok<AGROW>
        Offset_col(end+1,1) = getFirstFinite(pr, {'fit_C','C','offset'}); %#ok<AGROW>
        Slope_col(end+1,1) = getFirstFinite(pr, {'fit_m','m','slope','baseline_slope'}); %#ok<AGROW>

        R2_col(end+1,1) = getScalarOrNaN(pr, 'fit_R2'); %#ok<AGROW>
        RMSE_col(end+1,1) = getScalarOrNaN(pr, 'fit_RMSE'); %#ok<AGROW>
        NRMSE_col(end+1,1) = getScalarOrNaN(pr, 'fit_NRMSE'); %#ok<AGROW>
        Chi2_col(end+1,1) = getScalarOrNaN(pr, 'fit_chi2_red'); %#ok<AGROW>

        ResidualL2_col(end+1,1) = residualL2; %#ok<AGROW>
        ResidualRMS_col(end+1,1) = residualRMS; %#ok<AGROW>
        ResidualMean_col(end+1,1) = residualMean; %#ok<AGROW>
        ResidualStd_col(end+1,1) = residualStd; %#ok<AGROW>
        FitAvailable_col(end+1,1) = any(isfinite(fitY)); %#ok<AGROW>
    end
end

summaryTbl = table( ...
    wait_col, dataset_col, Tp_col, N_col, ...
    DipA_col, DipArea_col, DipSigma_col, DipT0_col, ...
    StepAmp_col, StepWidth_col, Offset_col, Slope_col, ...
    R2_col, RMSE_col, NRMSE_col, Chi2_col, ...
    ResidualL2_col, ResidualRMS_col, ResidualMean_col, ResidualStd_col, ...
    FitAvailable_col, ...
    'VariableNames', { ...
    'wait_time','dataset','pause_Tp_K','N_points', ...
    'dip_amplitude','dip_area','dip_sigma','dip_T0', ...
    'step_amplitude','step_width','offset','slope', ...
    'fit_R2','fit_RMSE','fit_NRMSE','fit_chi2_red', ...
    'residual_norm_L2','residual_rms','residual_mean','residual_std', ...
    'fit_curve_available'});

summaryTbl = sortrows(summaryTbl, {'wait_time','pause_Tp_K'});
outCsv = fullfile(outDir, 'fit_vs_derivative_audit_summary.csv');
writetable(summaryTbl, outCsv);

fprintf('Saved fit/derivative audit summary: %s\n', outCsv);
fprintf('Saved per-run figures under: %s\n', outDir);

function [T, dM] = extractDataCurve(pr)
T = getFieldOrEmpty(pr, 'T_common');
if isempty(T)
    T = getFieldOrEmpty(pr, 'T');
end
T = T(:);

dM = getFieldOrEmpty(pr, 'DeltaM');
dM = dM(:);

if isempty(T) || isempty(dM)
    T = [];
    dM = [];
    return;
end
end

function makeRunFigure(x, dM, fitY, residual, dData, dFit, Tp, waitTag, outDir)
valid1 = isfinite(x) & isfinite(dM);
valid2 = isfinite(x) & isfinite(fitY);
valid3 = isfinite(x) & isfinite(residual);
valid4a = isfinite(x) & isfinite(dData);
valid4b = isfinite(x) & isfinite(dFit);

figH = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 860]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

% Panel 1
ax1 = nexttile;
if any(valid1)
    plot(ax1, x(valid1), dM(valid1), 'k-', 'LineWidth', 1.4, 'DisplayName', '\DeltaM data');
    hold(ax1, 'on');
else
    hold(ax1, 'on');
end
xline(ax1, 0, '--k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
grid(ax1, 'on');
xlabel(ax1, 'T - T_p (K)');
ylabel(ax1, '\Delta M');
title(ax1, 'Data \DeltaM');
legend(ax1, 'Location', 'bestoutside');

% Panel 2
ax2 = nexttile;
if any(valid1)
    plot(ax2, x(valid1), dM(valid1), 'k-', 'LineWidth', 1.2, 'DisplayName', '\DeltaM data');
    hold(ax2, 'on');
else
    hold(ax2, 'on');
end
if any(valid2)
    plot(ax2, x(valid2), fitY(valid2), 'r--', 'LineWidth', 1.6, 'DisplayName', '\DeltaM fit');
end
xline(ax2, 0, '--k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
grid(ax2, 'on');
xlabel(ax2, 'T - T_p (K)');
ylabel(ax2, '\Delta M');
title(ax2, 'Data + Fit');
legend(ax2, 'Location', 'bestoutside');

% Panel 3
ax3 = nexttile;
if any(valid3)
    plot(ax3, x(valid3), residual(valid3), 'b-', 'LineWidth', 1.3, 'DisplayName', 'residual');
    hold(ax3, 'on');
else
    hold(ax3, 'on');
end
yline(ax3, 0, ':k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
xline(ax3, 0, '--k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
grid(ax3, 'on');
xlabel(ax3, 'T - T_p (K)');
ylabel(ax3, 'data - fit');
title(ax3, 'Residual');
legend(ax3, 'Location', 'bestoutside');

% Panel 4
ax4 = nexttile;
if any(valid4a)
    plot(ax4, x(valid4a), dData(valid4a), 'k-', 'LineWidth', 1.2, 'DisplayName', 'd(\DeltaM_{data})/dT');
    hold(ax4, 'on');
else
    hold(ax4, 'on');
end
if any(valid4b)
    plot(ax4, x(valid4b), dFit(valid4b), 'r--', 'LineWidth', 1.5, 'DisplayName', 'd(\DeltaM_{fit})/dT');
end
xline(ax4, 0, '--k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
grid(ax4, 'on');
xlabel(ax4, 'T - T_p (K)');
ylabel(ax4, 'd\DeltaM/dT');
title(ax4, 'Derivative Comparison');
legend(ax4, 'Location', 'bestoutside');

sgtitle(sprintf('Fit vs Derivative Audit | wait=%s | T_p=%.1f K', waitTag, Tp));

fileName = sprintf('FitDerivativeAudit_wait_%s_Tp_%s.png', waitTag, formatTpTag(Tp));
outPng = fullfile(outDir, fileName);
saveas(figH, outPng);
close(figH);
end

function y = gradientFinite(T, x)
y = nan(size(x));
mask = isfinite(T) & isfinite(x);
if nnz(mask) >= 2
    y(mask) = gradient(x(mask), T(mask));
end
end

function x = getFieldOrEmpty(s, fieldName)
if isfield(s, fieldName)
    x = s.(fieldName);
else
    x = [];
end
end

function v = getScalarOrNaN(s, fieldName)
v = NaN;
if isfield(s, fieldName)
    x = s.(fieldName);
    if ~isempty(x) && isscalar(x) && isfinite(x)
        v = double(x);
    end
end
end

function v = getFirstFinite(s, candidates)
v = NaN;
for i = 1:numel(candidates)
    c = candidates{i};
    if isfield(s, c)
        x = s.(c);
        if ~isempty(x) && isscalar(x) && isfinite(x)
            v = double(x);
            return;
        end
    end
end
end

function tag = formatTpTag(Tp)
if abs(Tp - round(Tp)) < 1e-9
    tag = sprintf('%dK', round(Tp));
else
    tag = sprintf('%.1fK', Tp);
    tag = strrep(tag, '.', 'p');
end
end

