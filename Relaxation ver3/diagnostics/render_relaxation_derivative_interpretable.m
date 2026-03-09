function out = render_relaxation_derivative_interpretable(srcDir, cfg)
% render_relaxation_derivative_interpretable
% Read derivative_smoothing outputs and regenerate interpretable visual diagnostics.

if nargin < 2
    cfg = struct();
end

cfg = setDef(cfg, 'clipPrct_dM', [5 95]);
cfg = setDef(cfg, 'clipPrct_S_abs', 95);
cfg = setDef(cfg, 'fontSize', 16);
cfg = setDef(cfg, 'lineWidth', 2.0);
cfg = setDef(cfg, 'target_log_times', [2.0 2.5 3.0 3.5]);
cfg = setDef(cfg, 'target_temps', [5 11 17 23 29 35]);
cfg = setDef(cfg, 'dense_target_log_times', linspace(1.9, 3.5, 10));
cfg = setDef(cfg, 'dense_target_temps', [8 10 12 15 18 20 22 24 26 28 30 32 34 36]);
cfg = setDef(cfg, 'ridgeMethod', 'sg_010'); % raw|sg_010|sg_020|gauss2d

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

if nargin < 1 || isempty(srcDir)
    srcDir = resolve_results_input_dir(repoRoot, 'relaxation', 'derivative_smoothing');
end

srcDir = char(srcDir);
outDir = srcDir; % save directly in requested folder
fprintf('Relaxation derivative render directory:\n%s\n', outDir);

% Required source files from previous analysis
req = {
    'map_dM_raw.csv',
    'map_dM_sg_100md.csv',
    'map_dM_sg_200md.csv',
    'map_dM_gauss2d.csv',
    'map_S_raw.csv',
    'map_S_sg_100md.csv',
    'map_S_sg_200md.csv',
    'map_S_gauss2d.csv'
};
for i = 1:numel(req)
    if ~isfile(fullfile(srcDir, req{i}))
        error('Missing source file: %s', fullfile(srcDir, req{i}));
    end
end

% Load map data
[xGrid, Ts, dM_raw] = readMapCsv(fullfile(srcDir, 'map_dM_raw.csv'));
[~, ~, dM_sg010] = readMapCsv(fullfile(srcDir, 'map_dM_sg_100md.csv'));
[~, ~, dM_sg020] = readMapCsv(fullfile(srcDir, 'map_dM_sg_200md.csv'));
[~, ~, dM_g2d] = readMapCsv(fullfile(srcDir, 'map_dM_gauss2d.csv'));
[~, ~, S_raw] = readMapCsv(fullfile(srcDir, 'map_S_raw.csv'));
[~, ~, S_sg010] = readMapCsv(fullfile(srcDir, 'map_S_sg_100md.csv'));
[~, ~, S_sg020] = readMapCsv(fullfile(srcDir, 'map_S_sg_200md.csv'));
[~, ~, S_g2d] = readMapCsv(fullfile(srcDir, 'map_S_gauss2d.csv'));

tGrid = 10.^xGrid;

% Time axis verification and export
isUniform = isUniformSpacing(xGrid, 1e-6);
gridTbl = table((1:numel(xGrid))', xGrid(:), tGrid(:), ...
    repmat(string('resampled_log_time_grid'), numel(xGrid), 1), ...
    repmat(isUniform, numel(xGrid), 1), ...
    'VariableNames', {'grid_idx','log10_t_rel_s','t_rel_s','axis_type','is_uniform_log_spacing'});
writetable(gridTbl, fullfile(outDir, 'time_grid_used.csv'));

% Color scaling
clim_dM_raw = prctileFinite(dM_raw, cfg.clipPrct_dM);
clim_dM_sg010 = prctileFinite(dM_sg010, cfg.clipPrct_dM);
clim_dM_sg020 = prctileFinite(dM_sg020, cfg.clipPrct_dM);
clim_dM_g2d = prctileFinite(dM_g2d, cfg.clipPrct_dM);

absPool = abs([S_raw(:); S_sg010(:); S_sg020(:); S_g2d(:)]);
maxAbsS = prctile(absPool(isfinite(absPool)), cfg.clipPrct_S_abs);
climS = [-maxAbsS, maxAbsS];

cmapDiv = divergingBlueRed(256);

% Clean dM maps
plotHeatmap(xGrid, Ts, dM_raw, clim_dM_raw, turbo(256), ...
    'DeltaM(T, log10(t_rel)) raw', 'DeltaM', cfg, fullfile(outDir, 'relaxation_dM_map_raw_clean.png'));
plotHeatmap(xGrid, Ts, dM_sg010, clim_dM_sg010, turbo(256), ...
    'DeltaM(T, log10(t_rel)) SG 0.10 decade', 'DeltaM', cfg, fullfile(outDir, 'relaxation_dM_map_sg010_clean.png'));
plotHeatmap(xGrid, Ts, dM_sg020, clim_dM_sg020, turbo(256), ...
    'DeltaM(T, log10(t_rel)) SG 0.20 decade', 'DeltaM', cfg, fullfile(outDir, 'relaxation_dM_map_sg020_clean.png'));
plotHeatmap(xGrid, Ts, dM_g2d, clim_dM_g2d, turbo(256), ...
    'DeltaM(T, log10(t_rel)) 2D Gaussian', 'DeltaM', cfg, fullfile(outDir, 'relaxation_dM_map_gauss2d_clean.png'));

% Clean S maps (diverging, zero-centered symmetric)
plotHeatmap(xGrid, Ts, S_raw, climS, cmapDiv, ...
    'S(T,t) raw = -dM/dlog10(t_rel)', 'S', cfg, fullfile(outDir, 'relaxation_S_map_raw_clean.png'));
plotHeatmap(xGrid, Ts, S_sg010, climS, cmapDiv, ...
    'S(T,t) from SG 0.10 decade', 'S', cfg, fullfile(outDir, 'relaxation_S_map_sg010_clean.png'));
plotHeatmap(xGrid, Ts, S_sg020, climS, cmapDiv, ...
    'S(T,t) from SG 0.20 decade', 'S', cfg, fullfile(outDir, 'relaxation_S_map_sg020_clean.png'));
plotHeatmap(xGrid, Ts, S_g2d, climS, cmapDiv, ...
    'S(T,t) from 2D Gaussian DeltaM', 'S', cfg, fullfile(outDir, 'relaxation_S_map_gauss2d_clean.png'));

% Ridge on chosen S map
switch lower(string(cfg.ridgeMethod))
    case 'raw'
        Sref = S_raw;
        dMref = dM_raw;
        methodLabel = 'raw';
    case 'sg_020'
        Sref = S_sg020;
        dMref = dM_sg020;
        methodLabel = 'sg_020';
    case 'gauss2d'
        Sref = S_g2d;
        dMref = dM_g2d;
        methodLabel = 'gauss2d';
    otherwise
        Sref = S_sg010;
        dMref = dM_sg010;
        methodLabel = 'sg_010';
end

[Spk, idxPk] = max(Sref, [], 2, 'omitnan');
idxPk = fillmissing(idxPk, 'nearest');
xPk = xGrid(idxPk)';
xPkSmooth = smoothdata(xPk, 'movmedian', 3);
tPk = 10.^xPkSmooth;

ridgeTbl = table(Ts, Spk, xPk, xPkSmooth, tPk, repmat(string(methodLabel), numel(Ts), 1), ...
    'VariableNames', {'Temp_K','S_peak','log10_t_peak_raw','log10_t_peak_smooth','t_peak_s','method'});
writetable(ridgeTbl, fullfile(outDir, 'ridge_trajectory_overlay.csv'));

plotSWithRidge(xGrid, Ts, Sref, climS, cmapDiv, xPkSmooth, methodLabel, cfg, ...
    fullfile(outDir, 'S_map_with_ridge_overlay.png'));

% Time cuts (4 representative log-times)
[xCut, idxCut, tCut] = pickLogTimes(xGrid, cfg.target_log_times);
S_timeCuts = Sref(:, idxCut);

timeCutTbl = table(Ts, S_timeCuts(:,1), S_timeCuts(:,2), S_timeCuts(:,3), S_timeCuts(:,4), ...
    'VariableNames', {'Temp_K','S_t1','S_t2','S_t3','S_t4'});
timeMetaTbl = table((1:4)', cfg.target_log_times(:), xCut(:), tCut(:), ...
    'VariableNames', {'cut_idx','target_log10_t','actual_log10_t','actual_t_s'});
writetable(timeCutTbl, fullfile(outDir, 'S_time_cuts_values.csv'));
writetable(timeMetaTbl, fullfile(outDir, 'S_time_cuts_meta.csv'));

plotTimeCuts(Ts, S_timeCuts, xCut, tCut, cfg, fullfile(outDir, 'relaxation_time_cuts_S_interpretable.png'));

% Temperature cuts (selected 5-7 curves)
[TsSel, idxSel] = pickTemperatures(Ts, cfg.target_temps, 6);
S_tempCuts = Sref(idxSel, :);

% Export long-form temperature cut table
nSel = numel(TsSel);
Tlong = table();
for j = 1:nSel
    tj = table(repmat(TsSel(j), numel(xGrid), 1), xGrid(:), tGrid(:), S_tempCuts(j,:)', ...
        'VariableNames', {'Temp_K','log10_t_rel_s','t_rel_s','S'});
    Tlong = [Tlong; tj]; %#ok<AGROW>
end
writetable(Tlong, fullfile(outDir, 'S_temperature_cuts_values_long.csv'));

plotTemperatureCuts(xGrid, TsSel, S_tempCuts, cfg, fullfile(outDir, 'relaxation_temperature_cuts_S_interpretable.png'));

% Dense time cuts (8 representative log-times) for both S and DeltaM
[xCutDense, idxCutDense, tCutDense] = pickLogTimes(xGrid, cfg.dense_target_log_times);
S_timeCutsDense = Sref(:, idxCutDense);
dM_timeCutsDense = dMref(:, idxCutDense);

denseTimeMetaTbl = table((1:numel(idxCutDense))', cfg.dense_target_log_times(:), xCutDense(:), tCutDense(:), ...
    'VariableNames', {'cut_idx','target_log10_t','actual_log10_t','actual_t_s'});
writetable(denseTimeMetaTbl, fullfile(outDir, 'dense_time_cuts_meta.csv'));

timeCutSTblDense = matrixCutsTable(Ts, S_timeCutsDense, 'S');
timeCutdMTblDense = matrixCutsTable(Ts, dM_timeCutsDense, 'DeltaM');
writetable(timeCutSTblDense, fullfile(outDir, 'dense_time_cuts_S_values.csv'));
writetable(timeCutdMTblDense, fullfile(outDir, 'dense_time_cuts_dM_values.csv'));

plotDenseTimeCuts(Ts, S_timeCutsDense, xCutDense, tCutDense, 'S(T,t)', ...
    'S(T) = -dM/dlog10(t_rel)', cfg, fullfile(outDir, 'relaxation_time_cuts_dense_S_all.png'));
plotDenseTimeCuts(Ts, dM_timeCutsDense, xCutDense, tCutDense, 'DeltaM(T,t)', ...
    'DeltaM(T)', cfg, fullfile(outDir, 'relaxation_time_cuts_dense_dM_all.png'));

% Dense temperature cuts (10-11 representative temperatures) for both S and DeltaM
[TsDense, idxDense] = pickTemperatures(Ts, cfg.dense_target_temps, inf);
S_tempCutsDense = Sref(idxDense, :);
dM_tempCutsDense = dMref(idxDense, :);

denseTargetsUsed = cfg.dense_target_temps(:);
if numel(denseTargetsUsed) > numel(TsDense)
    denseTargetsUsed = denseTargetsUsed(1:numel(TsDense));
end

denseTempMetaTbl = table(denseTargetsUsed, TsDense(:), idxDense(:), ...
    'VariableNames', {'target_temp_K','actual_temp_K','temp_index'});
writetable(denseTempMetaTbl, fullfile(outDir, 'dense_temperature_cuts_meta.csv'));

S_longDense = toLongCutTable(TsDense, xGrid, tGrid, S_tempCutsDense, 'S');
dM_longDense = toLongCutTable(TsDense, xGrid, tGrid, dM_tempCutsDense, 'DeltaM');
writetable(S_longDense, fullfile(outDir, 'dense_temperature_cuts_S_values_long.csv'));
writetable(dM_longDense, fullfile(outDir, 'dense_temperature_cuts_dM_values_long.csv'));

plotDenseTemperatureCuts(xGrid, TsDense, S_tempCutsDense, 'S(log10(t_rel))', ...
    'S(log10(t_rel)) = -dM/dlog10(t_rel)', cfg, fullfile(outDir, 'relaxation_temperature_cuts_dense_S_all.png'));
plotDenseTemperatureCuts(xGrid, TsDense, dM_tempCutsDense, 'DeltaM(log10(t_rel))', ...
    'DeltaM(log10(t_rel))', cfg, fullfile(outDir, 'relaxation_temperature_cuts_dense_dM_all.png'));

% Multi-map panel for quick human inspection
plotSMapPanel(xGrid, Ts, S_raw, S_sg010, S_sg020, S_g2d, climS, cmapDiv, cfg, ...
    fullfile(outDir, 'relaxation_S_maps_interpretable_panel.png'));

% Updated markdown report
writeInterpretableReport(fullfile(outDir, 'analysis_summary_relaxation_derivative_smoothing.md'), ...
    cfg, isUniform, xGrid, tGrid, timeMetaTbl, climS, methodLabel, ridgeTbl, TsSel, denseTimeMetaTbl, denseTempMetaTbl);

% Rebuild ZIP with updated outputs
zipPath = fullfile(outDir, 'relaxation_derivative_smoothing_analysis.zip');
if exist(zipPath, 'file')
    delete(zipPath);
end
allFiles = dir(fullfile(outDir, '*'));
zipList = strings(0,1);
for k = 1:numel(allFiles)
    if allFiles(k).isdir
        continue;
    end
    if strcmpi(allFiles(k).name, 'relaxation_derivative_smoothing_analysis.zip')
        continue;
    end
    zipList(end+1) = string(fullfile(allFiles(k).folder, allFiles(k).name)); %#ok<AGROW>
end
zip(zipPath, cellstr(zipList));

out = struct();
out.outDir = string(outDir);
out.zipPath = string(zipPath);
out.timeGrid = gridTbl;
out.ridge = ridgeTbl;
out.timeCutMeta = timeMetaTbl;
out.tempSelected = TsSel;

fprintf('\n=== Interpretable derivative plots complete ===\n');
fprintf('Output dir: %s\n', outDir);
fprintf('ZIP: %s\n\n', zipPath);

end

function [xGrid, Ts, Z] = readMapCsv(path)
A = readmatrix(path);
xGrid = A(1,2:end);
Ts = A(2:end,1);
Z = A(2:end,2:end);
end

function tf = isUniformSpacing(x, tol)
dx = diff(x(:));
if isempty(dx)
    tf = false;
    return;
end
tf = max(abs(dx - median(dx))) <= tol;
end

function clim = prctileFinite(Z, pr)
z = Z(isfinite(Z));
if isempty(z)
    clim = [0 1];
    return;
end
clim = prctile(z, pr);
if ~(isfinite(clim(1)) && isfinite(clim(2)) && clim(2) > clim(1))
    clim = [min(z), max(z)];
end
end

function cmap = divergingBlueRed(n)
if nargin < 1, n = 256; end
x = linspace(0,1,n)';
% blue -> white -> red
r = interp1([0 0.5 1], [0.1 1 0.8], x);
g = interp1([0 0.5 1], [0.2 1 0.1], x);
b = interp1([0 0.5 1], [0.8 1 0.1], x);
cmap = [r g b];
end

function plotHeatmap(xGrid, Ts, Z, clim, cmap, ttl, cbLabel, cfg, outFile)
fig = figure('Color','w','Visible','off','Position',[100 100 980 620]);
ax = axes(fig); %#ok<LAXES>
imagesc(ax, xGrid, Ts, Z);
set(ax, 'YDir', 'normal', 'FontSize', cfg.fontSize);
xlabel(ax, 'log10(t_rel / s)', 'FontSize', cfg.fontSize);
ylabel(ax, 'Temperature (K)', 'FontSize', cfg.fontSize);
title(ax, ttl, 'FontSize', cfg.fontSize + 1, 'FontWeight', 'bold');
colormap(ax, cmap);
if isfinite(clim(1)) && isfinite(clim(2)) && clim(2) > clim(1)
    caxis(ax, clim);
end
cb = colorbar(ax);
ylabel(cb, cbLabel, 'FontSize', cfg.fontSize);
cb.FontSize = cfg.fontSize - 1;
box(ax, 'on');
grid(ax, 'on');
saveas(fig, outFile);
close(fig);
end

function plotSWithRidge(xGrid, Ts, S, climS, cmapDiv, xRidge, methodLabel, cfg, outFile)
fig = figure('Color','w','Visible','off','Position',[100 100 980 620]);
ax = axes(fig); %#ok<LAXES>
imagesc(ax, xGrid, Ts, S);
set(ax, 'YDir', 'normal', 'FontSize', cfg.fontSize);
colormap(ax, cmapDiv);
caxis(ax, climS);
hold(ax, 'on');
plot(ax, xRidge, Ts, 'w-', 'LineWidth', 2.8, 'DisplayName', 'Ridge');
plot(ax, xRidge, Ts, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');

xlabel(ax, 'log10(t_rel / s)', 'FontSize', cfg.fontSize);
ylabel(ax, 'Temperature (K)', 'FontSize', cfg.fontSize);
title(ax, sprintf('S map with ridge overlay (%s)', methodLabel), 'FontSize', cfg.fontSize + 1, 'FontWeight', 'bold');
cb = colorbar(ax);
ylabel(cb, 'S', 'FontSize', cfg.fontSize);
cb.FontSize = cfg.fontSize - 1;
legend(ax, 'Location', 'northwest', 'FontSize', cfg.fontSize - 1);
box(ax, 'on'); grid(ax, 'on');
saveas(fig, outFile);
close(fig);
end

function [xCut, idxCut, tCut] = pickLogTimes(xGrid, xTargets)
idxCut = zeros(size(xTargets));
xCut = zeros(size(xTargets));
tCut = zeros(size(xTargets));
for k = 1:numel(xTargets)
    [~, idx] = min(abs(xGrid - xTargets(k)));
    idxCut(k) = idx;
    xCut(k) = xGrid(idx);
    tCut(k) = 10.^xCut(k);
end
end

function plotTimeCuts(Ts, Svals, xCut, tCut, cfg, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 900 620]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', cfg.fontSize);
cc = lines(size(Svals,2));
for k = 1:size(Svals,2)
    lbl = sprintf('log10(t_rel)=%.2f (t=%.0f s)', xCut(k), tCut(k));
    plot(ax, Ts, Svals(:,k), '-o', 'Color', cc(k,:), 'LineWidth', cfg.lineWidth, ...
        'MarkerSize', 6, 'DisplayName', lbl);
end
xlabel(ax, 'Temperature (K)', 'FontSize', cfg.fontSize);
ylabel(ax, 'S(T)', 'FontSize', cfg.fontSize);
title(ax, 'S vs Temperature at four representative times', 'FontSize', cfg.fontSize + 1, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', cfg.fontSize - 2);
saveas(fig, outFile);
close(fig);
end

function T = matrixCutsTable(Ts, vals, prefix)
n = size(vals,2);
names = cell(1, n + 1);
names{1} = 'Temp_K';
for k = 1:n
    names{k+1} = sprintf('%s_cut_%02d', prefix, k);
end
T = array2table([Ts(:), vals], 'VariableNames', names);
end

function Tlong = toLongCutTable(TsSel, xGrid, tGrid, vals, valueName)
Tlong = table();
for j = 1:numel(TsSel)
    tj = table(repmat(TsSel(j), numel(xGrid), 1), xGrid(:), tGrid(:), vals(j,:)', ...
        'VariableNames', {'Temp_K','log10_t_rel_s','t_rel_s', valueName});
    Tlong = [Tlong; tj]; %#ok<AGROW>
end
end

function plotDenseTimeCuts(Ts, vals, xCut, tCut, ttl, ylab, cfg, outFile)
nCuts = size(vals,2);
cols = turbo(max(nCuts, 3));
cols = cols(1:nCuts,:);

fig = figure('Color','w','Visible','off','Position',[80 80 1300 760]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', cfg.fontSize);

for j = 1:nCuts
    lbl = sprintf('log10(t_rel)=%.2f (t=%.0f s)', xCut(j), tCut(j));
    plot(ax, Ts, vals(:,j), '-', 'Color', cols(j,:), 'LineWidth', cfg.lineWidth, ...
        'DisplayName', lbl);
end

xlabel(ax, 'Temperature (K)', 'FontSize', cfg.fontSize);
ylabel(ax, ylab, 'FontSize', cfg.fontSize);
title(ax, sprintf('%s vs Temperature (all dense time slices)', ttl), ...
    'FontSize', cfg.fontSize + 1, 'FontWeight', 'bold');

colormap(ax, cols);
if nCuts > 1
    caxis(ax, [min(xCut) max(xCut)]);
else
    caxis(ax, [xCut(1)-0.5, xCut(1)+0.5]);
end
cb = colorbar(ax, 'southoutside');
ylabel(cb, 'log10(t_rel / s)', 'FontSize', cfg.fontSize - 1);
cb.FontSize = cfg.fontSize - 2;

legend(ax, 'Location', 'eastoutside', 'FontSize', cfg.fontSize - 4);
saveas(fig, outFile);
close(fig);
end

function plotDenseTemperatureCuts(xGrid, TsSel, vals, ttl, ylab, cfg, outFile)
nCurves = numel(TsSel);
cols = turbo(max(nCurves, 3));
cols = cols(1:nCurves,:);

fig = figure('Color','w','Visible','off','Position',[80 80 1300 760]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', cfg.fontSize);

for j = 1:nCurves
    plot(ax, xGrid, vals(j,:), '-', 'Color', cols(j,:), 'LineWidth', cfg.lineWidth, ...
        'DisplayName', sprintf('T = %.0f K', TsSel(j)));
end

xlabel(ax, 'log10(t_rel / s)', 'FontSize', cfg.fontSize);
ylabel(ax, ylab, 'FontSize', cfg.fontSize);
title(ax, sprintf('%s vs log-time (all dense temperature slices)', ttl), ...
    'FontSize', cfg.fontSize + 1, 'FontWeight', 'bold');

colormap(ax, cols);
if nCurves > 1
    caxis(ax, [min(TsSel) max(TsSel)]);
else
    caxis(ax, [TsSel(1)-0.5, TsSel(1)+0.5]);
end
cb = colorbar(ax, 'southoutside');
ylabel(cb, 'Temperature (K)', 'FontSize', cfg.fontSize - 1);
cb.FontSize = cfg.fontSize - 2;

legend(ax, 'Location', 'eastoutside', 'FontSize', cfg.fontSize - 4);
saveas(fig, outFile);
close(fig);
end

function groups = splitIndices(nItems, nGroups)
groups = cell(1, nGroups);
edges = round(linspace(0, nItems, nGroups + 1));
for g = 1:nGroups
    i1 = edges(g) + 1;
    i2 = edges(g + 1);
    if i1 <= i2
        groups{g} = i1:i2;
    else
        groups{g} = [];
    end
end
end
function [TsSel, idxSel] = pickTemperatures(Ts, targetTemps, maxN)
idx = zeros(size(targetTemps));
for k = 1:numel(targetTemps)
    [~, idx(k)] = min(abs(Ts - targetTemps(k)));
end
idx = unique(idx, 'stable');
if numel(idx) > maxN
    idx = idx(round(linspace(1, numel(idx), maxN)));
end
idxSel = idx(:)';
TsSel = Ts(idxSel);
end

function plotTemperatureCuts(xGrid, TsSel, Srows, cfg, outFile)
fig = figure('Color','w','Visible','off','Position',[120 120 980 620]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', cfg.fontSize);
cols = turbo(max(numel(TsSel), 3));
for j = 1:numel(TsSel)
    plot(ax, xGrid, Srows(j,:), '-', 'Color', cols(j,:), 'LineWidth', cfg.lineWidth, ...
        'DisplayName', sprintf('T = %.0f K', TsSel(j)));
end
xlabel(ax, 'log10(t_rel / s)', 'FontSize', cfg.fontSize);
ylabel(ax, 'S(log t)', 'FontSize', cfg.fontSize);
title(ax, 'S vs log-time for selected temperatures', 'FontSize', cfg.fontSize + 1, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', cfg.fontSize - 2);
saveas(fig, outFile);
close(fig);
end

function plotSMapPanel(xGrid, Ts, Sraw, Ssg010, Ssg020, Sg2d, climS, cmapDiv, cfg, outFile)
fig = figure('Color','w','Visible','off','Position',[60 60 1400 860]);
tl = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact'); %#ok<NASGU>
maps = {Sraw, Ssg010, Ssg020, Sg2d};
titles = {'S raw', 'S SG 0.10 decade', 'S SG 0.20 decade', 'S 2D Gaussian'};
for i = 1:4
    ax = nexttile; %#ok<LAXES>
    imagesc(ax, xGrid, Ts, maps{i});
    set(ax, 'YDir', 'normal', 'FontSize', cfg.fontSize - 2);
    colormap(ax, cmapDiv);
    caxis(ax, climS);
    title(ax, titles{i}, 'FontSize', cfg.fontSize, 'FontWeight', 'bold');
    xlabel(ax, 'log10(t_rel / s)', 'FontSize', cfg.fontSize - 1);
    ylabel(ax, 'Temperature (K)', 'FontSize', cfg.fontSize - 1);
    cb = colorbar(ax);
    ylabel(cb, 'S');
    box(ax, 'on'); grid(ax, 'on');
end
saveas(fig, outFile);
close(fig);
end

function writeInterpretableReport(path, cfg, isUniform, xGrid, tGrid, timeMetaTbl, climS, methodLabel, ridgeTbl, TsSel, denseTimeMetaTbl, denseTempMetaTbl)
fid = fopen(path, 'w');
if fid < 0
    warning('Cannot write report: %s', path);
    return;
end

fprintf(fid, '# Relaxation Derivative Smoothing: Interpretable Plot Layer\n\n');
fprintf(fid, '## Time Axis Verification\n');
fprintf(fid, '- Axis used in maps is a **resampled log-time grid** (not raw timestamps).\n');
fprintf(fid, '- Uniform log spacing: `%s`.\n', string(isUniform));
fprintf(fid, '- log10(t_rel/s) range: `%.4f` to `%.4f`\n', xGrid(1), xGrid(end));
fprintf(fid, '- t_rel range: `%.3f s` to `%.3f s`\n', tGrid(1), tGrid(end));
fprintf(fid, '- Exported grid file: `time_grid_used.csv`.\n\n');

fprintf(fid, '## Plot Design Choices\n');
fprintf(fid, '- DeltaM maps: percentile clipping 5-95, colormap `turbo`.\n');
fprintf(fid, '- S maps: diverging colormap centered at zero with symmetric limits.\n');
fprintf(fid, '- Symmetric S color limits: `[%.3e, %.3e]`.\n', climS(1), climS(2));
fprintf(fid, '- Ridge overlay method: `%s`.\n\n', methodLabel);

fprintf(fid, '## Representative Cuts\n');
fprintf(fid, '- Time cuts (target vs actual):\n');
for k = 1:height(timeMetaTbl)
    fprintf(fid, '  - target log10=%.2f -> actual log10=%.4f (t=%.1f s)\n', ...
        timeMetaTbl.target_log10_t(k), timeMetaTbl.actual_log10_t(k), timeMetaTbl.actual_t_s(k));
end
fprintf(fid, '- Temperature cuts shown for: %s K\n\n', strjoin(string(TsSel'), ', '));

fprintf(fid, '## Dense Geometry Cuts (for inspection)\n');
fprintf(fid, '- Dense time targets (log10(t_rel/s)): %s\n', strjoin(string(cfg.dense_target_log_times), ', '));
fprintf(fid, '- Dense temperature targets (K): %s\n', strjoin(string(cfg.dense_target_temps), ', '));
fprintf(fid, '- Dense time-cut files: relaxation_time_cuts_dense_S_all.png, relaxation_time_cuts_dense_dM_all.png.\n');
fprintf(fid, '- Dense temperature-cut files: relaxation_temperature_cuts_dense_S_all.png, relaxation_temperature_cuts_dense_dM_all.png.\n');
fprintf(fid, '- Dense cut metadata: dense_time_cuts_meta.csv, dense_temperature_cuts_meta.csv.\n');
fprintf(fid, '- Dense cut values: dense_time_cuts_S_values.csv, dense_time_cuts_dM_values.csv,\n');
fprintf(fid, '  dense_temperature_cuts_S_values_long.csv, dense_temperature_cuts_dM_values_long.csv.\n');
fprintf(fid, '- Matched dense time cuts: %d.\n', height(denseTimeMetaTbl));
fprintf(fid, '- Matched dense temperature cuts: %d.\n\n', height(denseTempMetaTbl));
fprintf(fid, '## Ridge Visualization\n');
fprintf(fid, '- Dedicated figure: `S_map_with_ridge_overlay.png`.\n');
fprintf(fid, '- Ridge CSV: `ridge_trajectory_overlay.csv` (Temp, S_peak, log10(t_peak), t_peak).\n');
fprintf(fid, '- Ridge is overlaid directly on the smoothed S map for visual validation.\n\n');

fprintf(fid, '## Interpretability Outcome\n');
fprintf(fid, '- Updated maps emphasize the temperature envelope and the strongest relaxation-time window by inspection.\n');
fprintf(fid, '- S ridges/plateau-like zones are easier to inspect due to zero-centered symmetric scaling and reduced saturation.\n');
fprintf(fid, '- The visualization layer is now suitable for geometry-first review before additional physics extraction.\n');

fclose(fid);
end

function v = setDef(s, f, d)
if ~isfield(s, f)
    s.(f) = d;
end
v = s;
end









