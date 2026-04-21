function result = analyzeAFM_FM_derivative(T, dM, Tp, cfg)
% =========================================================
% analyzeAFM_FM_derivative
%
% PURPOSE:
%   Experimental AFM/FM extraction mode using d(DeltaM)/dT diagnostics.
%   Reuses stage4 direct decomposition logic for smoothing + AFM metrics,
%   and computes FM from median levels outside the dip window.
%   Canonical signed variables are carried through when available:
%     DeltaM_signed = M_pause - M_noPause
%     dip_signed    = DeltaM_signed - DeltaM_smooth
%
% INPUTS:
%   T   - temperature vector
%   dM  - DeltaM(T)
%   Tp  - pause temperature
%   cfg - configuration struct
%
% OUTPUTS:
%   result struct with stage4-compatible AFM/FM fields and diagnostics
% =========================================================

T = T(:);
dM = dM(:);
n = min(numel(T), numel(dM));
T = T(1:n);
dM = dM(1:n);

result = initResult(n);
if n < 5 || ~isfinite(Tp)
    result.FM_plateau_reason = 'insufficient_input';
    result.baseline_status = 'insufficient_input';
    return;
end

cfg = applyDefaults(cfg);

% Reuse existing stage4 decomposition path (smoothing + AFM metrics).
tmpRun = struct('T_common', T, 'DeltaM', dM, 'waitK', Tp);
tmpOut = analyzeAFM_FM_components( ...
    tmpRun, cfg.dip_window_K, cfg.smoothWindow_K, ...
    cfg.excludeLowT_FM, cfg.excludeLowT_K, ...
    cfg.FM_plateau_K, cfg.excludeLowT_mode, cfg.FM_buffer_K, ...
    cfg.AFM_metric_main, cfg);

tmp = tmpOut(1);
result = copyFieldIfExists(result, tmp, 'DeltaM_smooth');
result = copyFieldIfExists(result, tmp, 'DeltaM_sharp');
result = copyFieldIfExists(result, tmp, 'DeltaM_definition_canonical');
result = copyFieldIfExists(result, tmp, 'dip_signed');
result = copyFieldIfExists(result, tmp, 'dip_definition_canonical');
result = copyFieldIfExists(result, tmp, 'AFM_amp');
result = copyFieldIfExists(result, tmp, 'AFM_amp_err');
result = copyFieldIfExists(result, tmp, 'AFM_area');
result = copyFieldIfExists(result, tmp, 'AFM_area_err');

fieldsToCarry = {
    'dip_window_K', 'smoothWindow_K', 'FM_plateau_K', 'FM_buffer_K', ...
    'excludeLowT_FM', 'excludeLowT_K', 'excludeLowT_mode'};
for kk = 1:numel(fieldsToCarry)
    result = copyFieldIfExists(result, tmp, fieldsToCarry{kk});
end

if ~isfield(result, 'DeltaM_smooth') || isempty(result.DeltaM_smooth)
    result.FM_plateau_reason = 'missing_smooth_signal';
    result.baseline_status = 'missing_smooth_signal';
    return;
end

dM_smooth = result.DeltaM_smooth(:);
if numel(dM_smooth) ~= n
    n2 = min(n, numel(dM_smooth));
    T = T(1:n2);
    dM = dM(1:n2);
    dM_smooth = dM_smooth(1:n2);
    n = n2;
end

% Derivative diagnostics on finite support.
dMdT = nan(n, 1);
finiteMask = isfinite(T) & isfinite(dM_smooth);
if nnz(finiteMask) >= 2
    dMdT(finiteMask) = gradient(dM_smooth(finiteMask), T(finiteMask));
end

dipMask = isfinite(T) & (abs(T - Tp) <= cfg.dip_window_K);
leftMask = isfinite(T) & isfinite(dM_smooth) & (T < Tp - cfg.dip_window_K);
rightMask = isfinite(T) & isfinite(dM_smooth) & (T > Tp + cfg.dip_window_K);

nLeft = nnz(leftMask);
nRight = nnz(rightMask);

baseL = NaN;
baseR = NaN;
if nLeft >= 3
    baseL = median(dM_smooth(leftMask), 'omitnan');
end
if nRight >= 3
    baseR = median(dM_smooth(rightMask), 'omitnan');
end

if isfinite(baseL) && isfinite(baseR)
    % FM CONVENTION OPTIONS:
    %   'rightMinusLeft' -> baseR - baseL
    %   'leftMinusRight' -> baseL - baseR
    %
    % CURRENT PROJECT DEFAULT:
    %   FM = baseL - baseR
    %
    % With this convention:
    %   Left plateau higher -> FM > 0
    result.FM_step_raw = computeFMFromBases(baseL, baseR, cfg.FMConvention);
    result.FM_definition_used = resolveFMDefinitionText(cfg.FMConvention);
    result.FM_step_mag = result.FM_step_raw;  % preserve sign
    result.FM_plateau_valid = true;
    result.FM_plateau_reason = '';
    result.baseline_status = 'ok';
else
    result.FM_step_raw = NaN;
    result.FM_step_mag = NaN;
    result.FM_plateau_valid = false;
    result.FM_plateau_reason = 'derivative_baseline_insufficient';
    result.baseline_status = 'insufficient_points';
    result.FM_definition_used = resolveFMDefinitionText(cfg.FMConvention);
end

result.FM_step_err = NaN;

TL = NaN;
TR = NaN;
if nLeft >= 1
    TL = median(T(leftMask), 'omitnan');
end
if nRight >= 1
    TR = median(T(rightMask), 'omitnan');
end
result.baseline_TL = TL;
result.baseline_TR = TR;

if isfinite(baseL) && isfinite(baseR) && isfinite(TL) && isfinite(TR) && (TR > TL)
    result.baseline_slope = (baseR - baseL) / (TR - TL);
else
    result.baseline_slope = NaN;
end

result.diagnostics = struct();
result.diagnostics.baseL = baseL;
result.diagnostics.baseR = baseR;
result.diagnostics.FM_convention = string(cfg.FMConvention);
result.diagnostics.dMdT = dMdT;
result.diagnostics.dM_smooth = dM_smooth;
result.diagnostics.leftMask = leftMask;
result.diagnostics.rightMask = rightMask;
result.diagnostics.dipMask = dipMask;
result.diagnostics.leftCount = nLeft;
result.diagnostics.rightCount = nRight;
result.diagnostics.FM_method = 'median_outside_dip';

if isfield(cfg, 'enableDerivativeDiagnostics') && logical(cfg.enableDerivativeDiagnostics)
    plotDerivativeShapeDiagnostic(T, dM_smooth, dMdT, Tp, cfg);
end

end

function cfg = applyDefaults(cfg)
if ~isfield(cfg, 'dip_window_K') || isempty(cfg.dip_window_K)
    cfg.dip_window_K = 5;
end
if ~isfield(cfg, 'smoothWindow_K') || isempty(cfg.smoothWindow_K)
    cfg.smoothWindow_K = 4 * cfg.dip_window_K;
end
if ~isfield(cfg, 'excludeLowT_FM') || isempty(cfg.excludeLowT_FM)
    cfg.excludeLowT_FM = false;
end
if ~isfield(cfg, 'excludeLowT_K') || isempty(cfg.excludeLowT_K)
    cfg.excludeLowT_K = -inf;
end
if ~isfield(cfg, 'FM_plateau_K') || isempty(cfg.FM_plateau_K)
    cfg.FM_plateau_K = 6;
end
if ~isfield(cfg, 'excludeLowT_mode') || isempty(cfg.excludeLowT_mode)
    cfg.excludeLowT_mode = 'pre';
end
if ~isfield(cfg, 'FM_buffer_K') || isempty(cfg.FM_buffer_K)
    cfg.FM_buffer_K = 3;
end
if ~isfield(cfg, 'AFM_metric_main') || isempty(cfg.AFM_metric_main)
    cfg.AFM_metric_main = 'height';
end
if ~isfield(cfg, 'enableDerivativeDiagnostics') || isempty(cfg.enableDerivativeDiagnostics)
    cfg.enableDerivativeDiagnostics = false;
end
if ~isfield(cfg, 'FMConvention') || isempty(cfg.FMConvention)
    cfg.FMConvention = 'leftMinusRight';
end
end

function result = initResult(n)
result = struct();
result.DeltaM_smooth = nan(n, 1);
result.DeltaM_sharp = nan(n, 1);
result.DeltaM_definition_canonical = 'DeltaM = M_{pause} - M_{no-pause}';
result.dip_signed = nan(n, 1);
result.dip_definition_canonical = 'dip_signed = DeltaM_signed - DeltaM_smooth';
result.AFM_amp = NaN;
result.AFM_amp_err = NaN;
result.AFM_area = NaN;
result.AFM_area_err = NaN;
result.FM_step_raw = NaN;
result.FM_step_mag = NaN;
result.FM_step_err = NaN;
result.FM_definition_used = '';
result.FM_plateau_valid = false;
result.FM_plateau_reason = '';
result.baseline_TL = NaN;
result.baseline_TR = NaN;
result.baseline_slope = NaN;
result.baseline_status = 'unknown';
result.diagnostics = struct();
end

function fmValue = computeFMFromBases(baseL, baseR, fmConvention)
switch lower(string(fmConvention))
    case "rightminusleft"
        fmValue = baseR - baseL;
    case "leftminusright"
        fmValue = baseL - baseR;
    otherwise
        error('Unknown FMConvention: %s', string(fmConvention));
end

function txt = resolveFMDefinitionText(fmConvention)
switch lower(string(fmConvention))
    case "rightminusleft"
        txt = 'FM = baseR - baseL';
    case "leftminusright"
        txt = 'FM = baseL - baseR';
    otherwise
        error('Unknown FMConvention: %s', string(fmConvention));
end
end
end

function out = copyFieldIfExists(out, in, fieldName)
if isfield(in, fieldName)
    out.(fieldName) = in.(fieldName);
end
end



function plotDerivativeShapeDiagnostic(T, dM_smooth, dMdT, Tp, cfg)
if isempty(T) || isempty(dM_smooth) || isempty(dMdT) || ~isfinite(Tp)
    return;
end

x = T(:) - Tp;
yTop = dM_smooth(:);
yBottom = dMdT(:);

validTop = isfinite(x) & isfinite(yTop);
validBottom = isfinite(x) & isfinite(yBottom);
if ~any(validTop) && ~any(validBottom)
    return;
end

thisFile = mfilename('fullpath');
modelsDir = fileparts(thisFile);
agingRoot = fileparts(modelsDir);
repoRoot = fileparts(agingRoot);
outDir = getResultsDir('aging', 'decomposition', 'derivative_shapes');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

waitTag = resolveDerivativeWaitTag(cfg);
tpTag = formatDerivativeTpTag(Tp);
outPng = fullfile(outDir, sprintf('DerivativeShape_wait_%s_Tp_%s.png', waitTag, tpTag));

figH = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 760]);
tl = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); %#ok<NASGU>

ax1 = nexttile;
hTop = gobjects(0);
if any(validTop)
    hTop = plot(ax1, x(validTop), yTop(validTop), 'b-', 'LineWidth', 1.6, ...
        'DisplayName', '\DeltaM (smoothed)');
    hold(ax1, 'on');
else
    hold(ax1, 'on');
end
xline(ax1, 0, '--k', 'LineWidth', 1.1, 'HandleVisibility', 'off');
grid(ax1, 'on');
xlabel(ax1, 'T - T_p (K)');
ylabel(ax1, '\Delta M');
title(ax1, sprintf('Derivative Shape | wait=%s | T_p=%.1f K', waitTag, Tp));
if ~isempty(hTop)
    legend(ax1, 'Location', 'bestoutside');
end

ax2 = nexttile;
hBottom = gobjects(0);
if any(validBottom)
    hBottom = plot(ax2, x(validBottom), yBottom(validBottom), 'r-', 'LineWidth', 1.6, ...
        'DisplayName', 'd\DeltaM/dT');
    hold(ax2, 'on');
else
    hold(ax2, 'on');
end
xline(ax2, 0, '--k', 'LineWidth', 1.1, 'HandleVisibility', 'off');
grid(ax2, 'on');
xlabel(ax2, 'T - T_p (K)');
ylabel(ax2, 'd\DeltaM/dT');
if ~isempty(hBottom)
    legend(ax2, 'Location', 'bestoutside');
end

saveas(figH, outPng);
close(figH);
end

function waitTag = resolveDerivativeWaitTag(cfg)
waitTag = 'unknown';
if isfield(cfg, 'datasetName') && ~isempty(cfg.datasetName)
    switch lower(string(cfg.datasetName))
        case 'mg119_3sec'
            waitTag = '3s';
        case 'mg119_36sec'
            waitTag = '36s';
        case 'mg119_6min'
            waitTag = '6min';
        case 'mg119_60min'
            waitTag = '60min';
        otherwise
            waitTag = char(lower(string(cfg.datasetName)));
    end
elseif isfield(cfg, 'dataDir') && ~isempty(cfg.dataDir)
    dataDirStr = lower(char(string(cfg.dataDir)));
    if contains(dataDirStr, '3sec')
        waitTag = '3s';
    elseif contains(dataDirStr, '36sec')
        waitTag = '36s';
    elseif contains(dataDirStr, '6min')
        waitTag = '6min';
    elseif contains(dataDirStr, '60min')
        waitTag = '60min';
    end
end

waitTag = regexprep(waitTag, '[^a-zA-Z0-9_\-]', '_');
end

function tpTag = formatDerivativeTpTag(Tp)
if abs(Tp - round(Tp)) < 1e-9
    tpTag = sprintf('%dK', round(Tp));
else
    tpTag = sprintf('%.1fK', Tp);
    tpTag = strrep(tpTag, '.', 'p');
end
end
