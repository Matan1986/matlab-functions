clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
cd(repoRoot);

addpath(fullfile(repoRoot, 'Aging'));
addpath(fullfile(repoRoot, 'Aging', 'pipeline'));

figDir = fullfile(repoRoot, 'results', 'aging', 'figures');
tblDir = fullfile(repoRoot, 'tables', 'aging');
rptDir = fullfile(repoRoot, 'reports', 'aging');

if exist(figDir, 'dir') ~= 7, mkdir(figDir); end
if exist(tblDir, 'dir') ~= 7, mkdir(tblDir); end
if exist(rptDir, 'dir') ~= 7, mkdir(rptDir); end

cfg = agingConfig('MG119_60min');
cfg.agingMetricMode = 'direct';
cfg.doPlotting = false;
cfg.enableStage7 = false;

state = Main_Aging(cfg);
pauseRuns = state.pauseRuns;

Tp = [pauseRuns.waitK]';

% Direct AFM metric currently used in direct decomposition summary path.
AFM = [pauseRuns.AFM_RMS]';
AFM_metric_name = "AFM_RMS";

useSignedFM = true;
if isfield(cfg, 'allowSignedFM') && ~isempty(cfg.allowSignedFM)
    useSignedFM = logical(cfg.allowSignedFM);
end

if useSignedFM
    if isfield(pauseRuns, 'FM_signed')
        FM = [pauseRuns.FM_signed]';
        FM_source_name = "FM_signed";
    elseif isfield(pauseRuns, 'FM_step_raw')
        FM = [pauseRuns.FM_step_raw]';
        FM_source_name = "FM_step_raw";
    else
        FM = [pauseRuns.FM_step_mag]';
        FM_source_name = "FM_step_mag";
    end
else
    if isfield(pauseRuns, 'FM_abs')
        FM = [pauseRuns.FM_abs]';
        FM_source_name = "FM_abs";
    elseif isfield(pauseRuns, 'FM_step_mag')
        FM = abs([pauseRuns.FM_step_mag]');
        FM_source_name = "abs(FM_step_mag)";
    else
        FM = abs([pauseRuns.FM_step_raw]');
        FM_source_name = "abs(FM_step_raw)";
    end
end

FM_valid = true(size(Tp));
if isfield(pauseRuns, 'FM_plateau_valid')
    FM_valid = logical([pauseRuns.FM_plateau_valid])';
end

validTp = isfinite(Tp);
validAFM = validTp & isfinite(AFM);
validFM = validTp & isfinite(FM) & FM_valid;

scale = 1e6;
AFM_plot = AFM * scale;
FM_plot = FM * scale;

hFig = figure('Color', 'w', 'Name', 'Aging Direct Summary vs Tp', 'NumberTitle', 'off');

lineColor = [0.60 0.60 0.60];
markerEdgeColor = 'k';
markerEdgeWidth = 0.6;
markerSize = 8;

if any(validTp)
    tpMin = min(Tp(validTp));
    tpMax = max(Tp(validTp));
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

ax1 = subplot(2,1,1); hold(ax1, 'on');
plot(ax1, Tp(validAFM), AFM_plot(validAFM), '-', 'Color', lineColor, 'LineWidth', 1.2);
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
ylabel(ax1, 'AFM (10^{-6} \mu_B / Co)');
title(ax1, 'Direct phenomenological decomposition summary');
xlim(ax1, xLimCommon);
set(ax1, 'XTick', Tp(validTp), 'FontName', 'Times New Roman', 'FontSize', 18, ...
    'TickDir', 'in', 'Box', 'on', 'Layer', 'top');
grid(ax1, 'off');

ax2 = subplot(2,1,2); hold(ax2, 'on');
plot(ax2, Tp(validFM), FM_plot(validFM), '-', 'Color', lineColor, 'LineWidth', 1.2);
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
xlabel(ax2, 'Pause temperature T_p (K)');
ylabel(ax2, 'FM (10^{-6} \mu_B / Co)');
xlim(ax2, xLimCommon);
set(ax2, 'XTick', Tp(validTp), 'FontName', 'Times New Roman', 'FontSize', 18, ...
    'TickDir', 'in', 'Box', 'on', 'Layer', 'top');
grid(ax2, 'off');

set(ax1, 'XTickLabel', []);

figPng = fullfile(figDir, 'aging_direct_summary_vs_Tp.png');
figFig = fullfile(figDir, 'aging_direct_summary_vs_Tp.fig');
saveas(hFig, figPng);
savefig(hFig, figFig);

tbl = table(Tp, AFM, FM, FM_valid, 'VariableNames', {'Tp', 'AFM', 'FM', 'FM_valid'});
tblPath = fullfile(tblDir, 'aging_direct_summary_vs_Tp.csv');
writetable(tbl, tblPath);

rptPath = fullfile(rptDir, 'aging_direct_summary_vs_Tp_report.md');
fid = fopen(rptPath, 'w');
if fid < 0
    error('Could not write report: %s', rptPath);
end

fprintf(fid, '# Aging Direct Summary vs Tp (Paper-1 Style)\n\n');
fprintf(fid, 'This figure is a **direct phenomenological decomposition summary**.\n\n');
fprintf(fid, 'It is intended for simple qualitative/phenomenological presentation and is not a final robustness-optimized measurement definition.\n\n');
fprintf(fid, '## Definitions used (as currently implemented)\n\n');
fprintf(fid, '- AFM metric: `%s`\n', AFM_metric_name);
fprintf(fid, '- FM metric source: `%s`\n', FM_source_name);
fprintf(fid, '- FM validity gating: uses `FM_plateau_valid` when present.\n\n');
fprintf(fid, '## Interpretation note\n\n');
fprintf(fid, '- Missing low-T FM points reflect missing plateau support in the direct decomposition.\n');
fprintf(fid, '- No alternative observable redefinition or fit-based replacement was used in this figure.\n\n');
fprintf(fid, '## Outputs\n\n');
fprintf(fid, '- `%s`\n', figPng);
fprintf(fid, '- `%s`\n', figFig);
fprintf(fid, '- `%s`\n', tblPath);

fclose(fid);

fprintf('Wrote figure: %s\n', figPng);
fprintf('Wrote figure: %s\n', figFig);
fprintf('Wrote table: %s\n', tblPath);
fprintf('Wrote report: %s\n', rptPath);
