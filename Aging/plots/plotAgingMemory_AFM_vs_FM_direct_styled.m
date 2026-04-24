function [hFig, out] = plotAgingMemory_AFM_vs_FM_direct_styled(pauseRuns, cfg)
% ============================================================
% CANONICAL DIRECT FIGURE
%
% Paper-ready AFM/FM vs Tp figure for direct decomposition.
% Uses:
%   - AFM_RMS (direct AFM observable)
%   - direct FM selection logic (signed or magnitude)
%   - styled two-panel layout
% ============================================================

if nargin < 2 || isempty(cfg)
    cfg = struct();
end
if ~isfield(cfg, 'fontsize') || isempty(cfg.fontsize)
    cfg.fontsize = 24;
end

Tp = [pauseRuns.waitK];
AFM = [pauseRuns.AFM_RMS];

useSignedFM = true;
if isfield(cfg, 'allowSignedFM') && ~isempty(cfg.allowSignedFM)
    useSignedFM = logical(cfg.allowSignedFM);
end

if useSignedFM
    if isfield(pauseRuns, 'FM_signed')
        FM = [pauseRuns.FM_signed];
    elseif isfield(pauseRuns, 'FM_step_raw')
        FM = [pauseRuns.FM_step_raw];
    else
        FM = [pauseRuns.FM_step_mag];
    end
else
    if isfield(pauseRuns, 'FM_abs')
        FM = [pauseRuns.FM_abs];
    elseif isfield(pauseRuns, 'FM_step_mag')
        FM = abs([pauseRuns.FM_step_mag]);
    else
        FM = abs([pauseRuns.FM_step_raw]);
    end
end

validTp = isfinite(Tp);
validAFM = validTp & isfinite(AFM);
pipelineValidFM = true(size(validTp));
if isfield(pauseRuns, 'FM_plateau_valid')
    pipelineValidFM = logical([pauseRuns.FM_plateau_valid]);
end
validFM = validTp & isfinite(FM) & pipelineValidFM;

scale = 1e6;
AFM_plot = AFM * scale;
FM_plot = FM * scale;

if any(validTp)
    tpValidVals = Tp(validTp);
    tpMin = min(tpValidVals);
    tpMax = max(tpValidVals);
else
    tpMin = 0;
    tpMax = 1;
end

tpSpan = max(tpMax - tpMin, eps);
xPad = max(0.5, 0.05 * tpSpan);
xLimCommon = [tpMin - xPad, tpMax + xPad];

cmap = cmocean('thermal', 256);
tpNorm = (Tp - min(Tp)) ./ (max(Tp) - min(Tp) + eps);
tpIdx = round(1 + tpNorm * (size(cmap, 1) - 1));
tpIdx(~isfinite(tpIdx)) = 1;
tpIdx = min(max(tpIdx, 1), size(cmap, 1));
tpColors = cmap(tpIdx, :);

hFig = figure('Color', 'w', 'Name', 'Direct AFM/FM Styled Summary', 'NumberTitle', 'off');

lineColor = [0.60 0.60 0.60];
lineWidth = 1.2;
markerSize = 9;
markerEdgeColor = 'k';
markerEdgeWidth = 0.6;

ax1 = subplot(2,1,1);
hold(ax1, 'on');
plot(ax1, Tp(validAFM), AFM_plot(validAFM), '-', 'Color', lineColor, 'LineWidth', lineWidth);
for i = 1:numel(Tp)
    if validAFM(i)
        plot(ax1, Tp(i), AFM_plot(i), 'o', ...
            'MarkerSize', markerSize, ...
            'MarkerFaceColor', tpColors(i, :), ...
            'MarkerEdgeColor', markerEdgeColor, ...
            'LineWidth', markerEdgeWidth, ...
            'LineStyle', 'none');
    end
end
hY1 = ylabel(ax1, 'AFM (RMS) $(10^{-6}\ \mu_{\mathrm{B}}/\mathrm{Co})$', 'Interpreter', 'latex');
set(hY1, 'FontSize', cfg.fontsize - 2);
title(ax1, 'Direct decomposition');
xlim(ax1, xLimCommon);
set(ax1, 'FontSize', cfg.fontsize - 2);
set(ax1, 'XTick', Tp(validTp));
ax1.TickDir = 'in';
ax1.Box = 'on';
ax1.Layer = 'top';
ax1.FontName = 'Times New Roman';
ax1.TickLabelInterpreter = 'latex';
ax1.XMinorTick = 'off';
ax1.YMinorTick = 'off';
grid(ax1, 'off');

ax2 = subplot(2,1,2);
hold(ax2, 'on');
plot(ax2, Tp(validFM), FM_plot(validFM), '-', 'Color', lineColor, 'LineWidth', lineWidth);
for i = 1:numel(Tp)
    if validFM(i)
        plot(ax2, Tp(i), FM_plot(i), 'o', ...
            'MarkerSize', markerSize, ...
            'MarkerFaceColor', tpColors(i, :), ...
            'MarkerEdgeColor', markerEdgeColor, ...
            'LineWidth', markerEdgeWidth, ...
            'LineStyle', 'none');
    end
end
hY2 = ylabel(ax2, 'FM (plateau) $(10^{-6}\ \mu_{\mathrm{B}}/\mathrm{Co})$', 'Interpreter', 'latex');
set(hY2, 'FontSize', cfg.fontsize - 2);
xlabel(ax2, 'Pause temperature $T_p$ (K)', 'Interpreter', 'latex');
xlim(ax2, xLimCommon);
set(ax2, 'FontSize', cfg.fontsize - 2);
set(ax2, 'XTick', Tp(validTp));
ax2.TickDir = 'in';
ax2.Box = 'on';
ax2.Layer = 'top';
ax2.FontName = 'Times New Roman';
ax2.TickLabelInterpreter = 'latex';
ax2.XMinorTick = 'off';
ax2.YMinorTick = 'off';
grid(ax2, 'off');

set(ax1, 'XTickLabel', []);

if any(validAFM)
    afmVals = AFM_plot(validAFM);
    ymin = min(afmVals);
    ymax = max(afmVals);
    pad = 0.1 * (ymax - ymin + eps);
    ylim(ax1, [ymin - pad, ymax + pad]);
else
    ylim(ax1, [0 1]);
end

if any(validFM)
    fmVals = FM_plot(validFM);
    ymin = min(fmVals);
    ymax = max(fmVals);
    pad = 0.1 * (ymax - ymin + eps);
    ylim(ax2, [ymin - pad, ymax + pad]);
else
    ylim(ax2, [0 1]);
end

ax1.YAxis.Exponent = 0;
ax2.YAxis.Exponent = 0;

pos1 = ax1.Position;
pos2 = ax2.Position;
newHeight = 0.38;
ax1.Position = [pos1(1), 0.58, pos1(3), newHeight];
ax2.Position = [pos2(1), 0.08, pos2(3), newHeight];

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    thisFile = mfilename('fullpath');
    plotsDir = fileparts(thisFile);
    agingDir = fileparts(plotsDir);
    repoRoot = fileparts(agingDir);
end

outDir = fullfile(repoRoot, 'results', 'aging', 'figures');
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

out.png = fullfile(outDir, 'AFM_RMS_vs_Tp_direct_styled.png');
out.fig = fullfile(outDir, 'AFM_RMS_vs_Tp_direct_styled.fig');

saveas(hFig, out.png);
savefig(hFig, out.fig);
end
