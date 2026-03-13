function out = run_relaxation_svd_audit(cfg)
% run_relaxation_svd_audit
% Perform an SVD audit on existing relaxation map exports without rerunning pipelines.

if nargin < 1 || ~isstruct(cfg)
    cfg = struct();
end

thisFile = mfilename('fullpath');
diagDir = fileparts(thisFile);
relaxDir = fileparts(diagDir);
repoRoot = fileparts(relaxDir);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(diagDir);

cfg.runLabel = getDef(cfg, 'runLabel', 'svd_audit');
cfg.dMMapPath = getDef(cfg, 'dMMapPath', "");
cfg.SMapPath = getDef(cfg, 'SMapPath', "");
cfg.maxModes = getDef(cfg, 'maxModes', 10);
cfg.plotModes = getDef(cfg, 'plotModes', 5);
cfg.reconstructionRanks = getDef(cfg, 'reconstructionRanks', [1 2]);

runCfg = struct();
runCfg.runLabel = cfg.runLabel;
run = createRunContext('relaxation', runCfg);
runDir = getRunOutputDir();
fprintf('Relaxation SVD audit run directory:\n%s\n', runDir);

dMPath = resolveMapPath(repoRoot, cfg.dMMapPath, 'dM');
fprintf('DeltaM map source: %s\n', dMPath);

dMData = analyzeSingleMap(dMPath, '\DeltaM(T, log_{10} t)', 'dM', cfg);
dMData = addReconstructionDiagnostics(dMData, cfg.reconstructionRanks);
dMSpectrumPath = save_run_table(dMData.spectrumTable, 'svd_spectrum.csv', runDir);
dMScree = saveScreeFigure(dMData, 'singular_value_spectrum', runDir);
dMModeT = saveSpatialModesFigure(dMData, 'mode_T_1_to_5', runDir);
dMModeTt = saveTemporalModesFigure(dMData, 'mode_t_1_to_5', runDir);
[dMReconRows, dMReconPaths] = saveReconstructionArtifacts(dMData, 'dM', runDir);

hasS = false;
sData = struct();
sSpectrumPath = "";
sScree = struct();
sModeT = struct();
sModeTt = struct();
sReconRows = table();
sReconPaths = struct();
SPath = "";

if strlength(strtrim(string(cfg.SMapPath))) > 0
    SPath = char(string(cfg.SMapPath));
    if exist(SPath, 'file') ~= 2
        error('Provided SMapPath not found: %s', SPath);
    end
    hasS = true;
else
    [SPath, foundS] = resolveOptionalSMapPath(repoRoot);
    hasS = foundS;
end

if hasS
    fprintf('S map source: %s\n', SPath);
    sData = analyzeSingleMap(SPath, 'S(T, t)', 'S', cfg);
    sData = addReconstructionDiagnostics(sData, cfg.reconstructionRanks);
    sSpectrumPath = save_run_table(sData.spectrumTable, 'svd_spectrum_S.csv', runDir);
    sScree = saveScreeFigure(sData, 'singular_value_spectrum_S', runDir);
    sModeT = saveSpatialModesFigure(sData, 'mode_T_1_to_5_S', runDir);
    sModeTt = saveTemporalModesFigure(sData, 'mode_t_1_to_5_S', runDir);
    [sReconRows, sReconPaths] = saveReconstructionArtifacts(sData, 'S', runDir);
end

reconstructionSummary = dMReconRows;
if hasS
    reconstructionSummary = [reconstructionSummary; sReconRows]; %#ok<AGROW>
end
reconstructionSummaryPath = save_run_table(reconstructionSummary, 'reconstruction_error_summary.csv', runDir);

reportText = buildReport(dMData, dMPath, dMReconRows, hasS, sData, SPathOrEmpty(hasS, SPath), sReconRows);
reportPath = save_run_report(reportText, 'relaxation_svd_audit.md', runDir);

appendText(run.log_path, sprintf('[%s] SVD audit completed\n', stampNow()));
appendText(run.log_path, sprintf('DeltaM source: %s\n', dMPath));
appendText(run.log_path, sprintf('Reconstruction summary: %s\n', reconstructionSummaryPath));
if hasS
    appendText(run.log_path, sprintf('S source: %s\n', SPath));
end

appendRankNotes(run.notes_path, 'DeltaM', dMData, dMReconRows);
if hasS
    appendRankNotes(run.notes_path, 'S', sData, sReconRows);
end

reviewDir = fullfile(runDir, 'review');
if exist(reviewDir, 'dir') ~= 7
    mkdir(reviewDir);
end
zipPath = fullfile(reviewDir, sprintf('relaxation_svd_audit_%s.zip', run.run_id));
if exist(zipPath, 'file') == 2
    delete(zipPath);
end
zipInputs = {'figures', 'tables', 'reports', 'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};
zip(zipPath, zipInputs, runDir);

out = struct();
out.run = run;
out.runDir = string(runDir);
out.deltaM = dMData;
out.deltaMSpectrumPath = string(dMSpectrumPath);
out.deltaMScree = string(dMScree.png);
out.deltaMModeT = string(dMModeT.png);
out.deltaMModeTt = string(dMModeTt.png);
out.deltaMReconstructionFigures = dMReconPaths;
out.reconstructionSummaryPath = string(reconstructionSummaryPath);
out.reportPath = string(reportPath);
out.zipPath = string(zipPath);
if hasS
    out.S = sData;
    out.SSpectrumPath = string(sSpectrumPath);
    out.SScree = string(sScree.png);
    out.SModeT = string(sModeT.png);
    out.SModeTt = string(sModeTt.png);
    out.SReconstructionFigures = sReconPaths;
end

fprintf('\n=== Relaxation SVD audit complete ===\n');
fprintf('Run dir: %s\n', runDir);
fprintf('Spectrum CSV: %s\n', dMSpectrumPath);
fprintf('Reconstruction summary: %s\n', reconstructionSummaryPath);
fprintf('Report: %s\n', reportPath);
fprintf('ZIP: %s\n\n', zipPath);
end

function data = analyzeSingleMap(mapPath, displayName, shortName, cfg)
[T, xGrid, Z, prep] = loadMapMatrix(mapPath);

[U, S, V] = svd(Z, 'econ');
singVals = diag(S);
energy = singVals .^ 2;
energyFrac = energy ./ max(sum(energy), eps);
cumulative = cumsum(energyFrac);
normalized = singVals ./ max(singVals(1), eps);

nKeep = min(cfg.maxModes, numel(singVals));
modes = (1:nKeep)';
spectrumTable = table(modes, singVals(1:nKeep), normalized(1:nKeep), cumulative(1:nKeep), ...
    'VariableNames', {'mode', 'singular_value', 'normalized_value', 'cumulative_fraction'});

rank95 = find(cumulative >= 0.95, 1, 'first');
if isempty(rank95)
    rank95 = numel(singVals);
end
rank90 = find(cumulative >= 0.90, 1, 'first');
if isempty(rank90)
    rank90 = numel(singVals);
end

if rank95 <= 1
    rankLabel = 'rank-1';
elseif rank95 == 2
    rankLabel = 'rank-2';
elseif rank95 == 3
    rankLabel = 'rank-3';
else
    rankLabel = 'higher';
end

data = struct();
data.mapPath = string(mapPath);
data.displayName = string(displayName);
data.shortName = string(shortName);
data.T = T;
data.xGrid = xGrid;
data.tGrid = 10 .^ xGrid;
data.matrix = Z;
data.prep = prep;
data.U = U;
data.S = S;
data.V = V;
data.singularValues = singVals;
data.normalizedValues = normalized;
data.cumulative = cumulative;
data.rank90 = rank90;
data.rank95 = rank95;
data.rankLabel = string(rankLabel);
data.nPlotModes = min(cfg.plotModes, size(U, 2));
data.spectrumTable = spectrumTable;
data.originalClim = computeMapClim(Z, false);
end

function data = addReconstructionDiagnostics(data, requestedRanks)
maxRank = min(size(data.U, 2), size(data.V, 2));
ranks = unique(requestedRanks(:)');
ranks = ranks(ranks >= 1 & ranks <= maxRank);
if isempty(ranks)
    ranks = 1;
end

origFro = norm(data.matrix, 'fro');
if ~(isfinite(origFro) && origFro > 0)
    origFro = eps;
end

recon = repmat(struct( ...
    'rank', NaN, ...
    'approx', [], ...
    'residual', [], ...
    'froErrorNorm', NaN, ...
    'relativeFroError', NaN, ...
    'energyCaptured', NaN, ...
    'maxAbsResidual', NaN, ...
    'rmsResidual', NaN), 0, 1);

for i = 1:numel(ranks)
    rankUsed = ranks(i);
    approx = data.U(:, 1:rankUsed) * data.S(1:rankUsed, 1:rankUsed) * data.V(:, 1:rankUsed)';
    residual = data.matrix - approx;
    froErr = norm(residual, 'fro');
    energyCaptured = 1 - (froErr.^2 / max(origFro.^2, eps));
    recon(end+1) = struct( ...
        'rank', rankUsed, ...
        'approx', approx, ...
        'residual', residual, ...
        'froErrorNorm', froErr, ...
        'relativeFroError', froErr / origFro, ...
        'energyCaptured', energyCaptured, ...
        'maxAbsResidual', max(abs(residual), [], 'all'), ...
        'rmsResidual', sqrt(mean(residual(:) .^ 2))); %#ok<AGROW>
end

data.reconstruction = recon;
end

function [rows, paths] = saveReconstructionArtifacts(data, prefix, runDir)
rows = table();
paths = struct();

for i = 1:numel(data.reconstruction)
    recon = data.reconstruction(i);
    reconBase = sprintf('%s_rank%d_reconstruction', prefix, recon.rank);
    residualBase = sprintf('%s_rank%d_residual', prefix, recon.rank);

    reconTitle = sprintf('%s rank-%d reconstruction', char(data.displayName), recon.rank);
    residualTitle = sprintf('%s rank-%d residual: original - reconstruction', char(data.displayName), recon.rank);

    reconPaths = saveMapFigure(data, recon.approx, reconTitle, char(data.shortName), reconBase, runDir, data.originalClim);
    residualPaths = saveMapFigure(data, recon.residual, residualTitle, sprintf('%s residual', char(data.shortName)), ...
        residualBase, runDir, computeMapClim(recon.residual, true));

    row = table(string(prefix), recon.rank, recon.froErrorNorm, recon.relativeFroError, ...
        recon.energyCaptured, recon.maxAbsResidual, recon.rmsResidual, ...
        'VariableNames', {'map_name','rank_used','fro_error_norm','relative_fro_error', ...
        'variance_explained_or_energy_captured','max_abs_residual','rms_residual'});
    rows = [rows; row]; %#ok<AGROW>

    paths.(sprintf('rank%d_reconstruction_png', recon.rank)) = string(reconPaths.png);
    paths.(sprintf('rank%d_reconstruction_fig', recon.rank)) = string(reconPaths.fig);
    paths.(sprintf('rank%d_residual_png', recon.rank)) = string(residualPaths.png);
    paths.(sprintf('rank%d_residual_fig', recon.rank)) = string(residualPaths.fig);
end
end

function paths = saveMapFigure(data, Z, ttl, cbarLabel, baseName, runDir, clim)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [110 110 920 580]);
ax = axes(fig);
imagesc(ax, data.xGrid, data.T, Z);
set(ax, 'YDir', 'normal', 'FontSize', 14, 'LineWidth', 1.1);
colormap(ax, parula);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'log_{10}(t_{rel} [s])', 'FontSize', 15);
ylabel(ax, 'Temperature (K)', 'FontSize', 15);
title(ax, ttl, 'FontSize', 16, 'FontWeight', 'bold');
cb = colorbar(ax);
ylabel(cb, cbarLabel, 'FontSize', 14);
if numel(clim) == 2 && all(isfinite(clim)) && clim(2) > clim(1)
    caxis(ax, clim);
end
paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function clim = computeMapClim(Z, symmetric)
vals = Z(isfinite(Z));
if isempty(vals)
    clim = [0 1];
    return;
end

if symmetric
    vmax = prctile(abs(vals), 98);
    if ~(isfinite(vmax) && vmax > 0)
        vmax = max(abs(vals));
    end
    if ~(isfinite(vmax) && vmax > 0)
        vmax = 1;
    end
    clim = [-vmax, vmax];
else
    clim = prctile(vals, [2 98]);
    if ~(all(isfinite(clim)) && clim(2) > clim(1))
        clim = [min(vals), max(vals)];
    end
    if ~(all(isfinite(clim)) && clim(2) > clim(1))
        span = max(abs(vals));
        if ~(isfinite(span) && span > 0)
            span = 1;
        end
        clim = [-span, span];
    end
end
end

function [T, xGrid, Z, prep] = loadMapMatrix(mapPath)
raw = readmatrix(mapPath);
if isempty(raw) || size(raw, 1) < 2 || size(raw, 2) < 2
    error('Map file is empty or malformed: %s', mapPath);
end

xGrid = raw(1, 2:end);
T = raw(2:end, 1);
Z = raw(2:end, 2:end);

validRows = isfinite(T);
validCols = isfinite(xGrid);
T = T(validRows);
xGrid = xGrid(validCols);
Z = Z(validRows, validCols);

nonEmptyRows = any(isfinite(Z), 2);
nonEmptyCols = any(isfinite(Z), 1);
T = T(nonEmptyRows);
xGrid = xGrid(nonEmptyCols);
Z = Z(nonEmptyRows, nonEmptyCols);

nMissingInitial = sum(~isfinite(Z), 'all');
if nMissingInitial > 0
    Z = fillMapMissing(Z);
end

if any(~isfinite(Z), 'all')
    error('Map still contains non-finite values after filling: %s', mapPath);
end

prep = struct();
prep.nRows = size(Z, 1);
prep.nCols = size(Z, 2);
prep.nMissingFilled = nMissingInitial;
end

function Z = fillMapMissing(Z)
for r = 1:size(Z, 1)
    Z(r, :) = fillRowMissing(Z(r, :));
end
for c = 1:size(Z, 2)
    Z(:, c) = fillRowMissing(Z(:, c)')';
end

if any(~isfinite(Z), 'all')
    rowMeans = mean(Z, 2, 'omitnan');
    for r = 1:size(Z, 1)
        miss = ~isfinite(Z(r, :));
        if any(miss)
            if isfinite(rowMeans(r))
                Z(r, miss) = rowMeans(r);
            else
                Z(r, miss) = 0;
            end
        end
    end
end
end

function row = fillRowMissing(row)
if all(isfinite(row))
    return;
end

x = 1:numel(row);
good = isfinite(row);
if ~any(good)
    row(:) = 0;
    return;
end
if sum(good) == 1
    row(~good) = row(good);
    return;
end

row(~good) = interp1(x(good), row(good), x(~good), 'linear', 'extrap');
end

function paths = saveScreeFigure(data, baseName, runDir)
nShow = min(10, numel(data.singularValues));
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 900 540]);
ax = axes(fig);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 14, 'LineWidth', 1.1);

modes = 1:nShow;
yyaxis(ax, 'left');
plot(ax, modes, data.normalizedValues(1:nShow), '-o', ...
    'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.10 0.35 0.75], ...
    'DisplayName', 'normalized singular value');
ylabel(ax, '\sigma_i / \sigma_1', 'FontSize', 15);
set(ax, 'YScale', 'log');

yyaxis(ax, 'right');
plot(ax, modes, data.cumulative(1:nShow), '-s', ...
    'LineWidth', 2.2, 'MarkerSize', 6, 'Color', [0.80 0.20 0.10], ...
    'DisplayName', 'cumulative energy');
ylabel(ax, 'Cumulative fraction', 'FontSize', 15);
ylim(ax, [0 1.02]);

xlabel(ax, 'Mode index', 'FontSize', 15);
title(ax, sprintf('Singular-value spectrum: %s', char(data.displayName)), ...
    'FontSize', 16, 'FontWeight', 'bold');
legend(ax, 'Location', 'best', 'FontSize', 12);
xticks(ax, modes);

paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function paths = saveSpatialModesFigure(data, baseName, runDir)
nPlot = data.nPlotModes;
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100 80 980 1100]);
tiledlayout(fig, nPlot, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
cols = lines(max(nPlot, 3));

for k = 1:nPlot
    ax = nexttile;
    plot(ax, data.T, data.U(:, k), '-', 'LineWidth', 2.1, 'Color', cols(k, :));
    grid(ax, 'on');
    box(ax, 'on');
    set(ax, 'FontSize', 13, 'LineWidth', 1.0);
    ylabel(ax, sprintf('u_%d(T)', k), 'FontSize', 14);
    title(ax, sprintf('%s mode u_%d(T)', char(data.shortName), k), 'FontSize', 14);
    if k == nPlot
        xlabel(ax, 'Temperature (K)', 'FontSize', 14);
    else
        set(ax, 'XTickLabel', []);
    end
end

paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function paths = saveTemporalModesFigure(data, baseName, runDir)
nPlot = data.nPlotModes;
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100 80 980 1100]);
tiledlayout(fig, nPlot, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
cols = lines(max(nPlot, 3));

for k = 1:nPlot
    ax = nexttile;
    plot(ax, data.xGrid, data.V(:, k), '-', 'LineWidth', 2.1, 'Color', cols(k, :));
    grid(ax, 'on');
    box(ax, 'on');
    set(ax, 'FontSize', 13, 'LineWidth', 1.0);
    ylabel(ax, sprintf('v_%d(t)', k), 'FontSize', 14);
    title(ax, sprintf('%s mode v_%d(t)', char(data.shortName), k), 'FontSize', 14);
    if k == nPlot
        xlabel(ax, 'log_{10}(t_{rel} [s])', 'FontSize', 14);
    else
        set(ax, 'XTickLabel', []);
    end
end

paths = save_run_figure(fig, baseName, runDir);
close(fig);
end

function reportText = buildReport(dMData, dMPath, dMReconRows, hasS, sData, sPath, sReconRows)
lines = {};
lines{end+1,1} = '# Relaxation SVD Audit';
lines{end+1,1} = '';
lines{end+1,1} = '## Inputs';
lines{end+1,1} = ['- DeltaM map source: `' char(string(dMPath)) '`'];
if hasS
    lines{end+1,1} = ['- S map source: `' char(string(sPath)) '`'];
else
    lines{end+1,1} = '- S map source: not found in existing relaxation outputs';
end
lines{end+1,1} = '';
sectionLines = buildSpectrumSection(dMData);
lines = [lines; sectionLines(:)];
lines{end+1,1} = '';
sectionLines = buildReconstructionSection(dMData, dMReconRows);
lines = [lines; sectionLines(:)];
if hasS
    lines{end+1,1} = '';
    sectionLines = buildSpectrumSection(sData);
    lines = [lines; sectionLines(:)];
    lines{end+1,1} = '';
    sectionLines = buildReconstructionSection(sData, sReconRows);
    lines = [lines; sectionLines(:)];
end
lines{end+1,1} = '';
lines{end+1,1} = '## Visualization choices';
lines{end+1,1} = '- number of curves: scree plot uses 2 curves; mode figures use 1 curve per subplot; reconstruction diagnostics use one heatmap per figure';
lines{end+1,1} = '- legend vs colormap: legend for scree plot; colormap plus colorbar for reconstruction and residual heatmaps';
lines{end+1,1} = '- colormap used: parula';
lines{end+1,1} = '- smoothing applied: none in this audit; SVD and reconstructions were computed from existing exported maps';
lines{end+1,1} = '- justification: the reconstruction and residual heatmaps directly test whether the map is effectively low-rank';

reportText = strjoin(lines, newline);
end

function lines = buildSpectrumSection(data)
lines = {};
lines{end+1,1} = ['## ' char(data.displayName)];
lines{end+1,1} = sprintf('- matrix size used for SVD: %d temperatures x %d time samples', size(data.matrix, 1), size(data.matrix, 2));
lines{end+1,1} = sprintf('- missing values filled before SVD: %d', data.prep.nMissingFilled);
lines{end+1,1} = sprintf('- estimated effective rank (95%% cumulative energy): %d', data.rank95);
lines{end+1,1} = sprintf('- 90%% cumulative energy rank: %d', data.rank90);
lines{end+1,1} = ['- dominant structure classification: ' char(data.rankLabel)];
lines{end+1,1} = '';
lines{end+1,1} = '### Singular-value spectrum';
lines{end+1,1} = '| mode | singular value | normalized value | cumulative fraction |';
lines{end+1,1} = '| --- | ---: | ---: | ---: |';
for i = 1:height(data.spectrumTable)
    lines{end+1,1} = sprintf('| %d | %.6g | %.6g | %.6f |', ...
        data.spectrumTable.mode(i), ...
        data.spectrumTable.singular_value(i), ...
        data.spectrumTable.normalized_value(i), ...
        data.spectrumTable.cumulative_fraction(i));
end
lines{end+1,1} = '';
lines{end+1,1} = '### Interpretation';
lines{end+1,1} = '- The cumulative fraction uses squared singular values, so it tracks captured map energy.';
lines{end+1,1} = '- The estimated effective rank is reported from the first mode count that reaches 95% cumulative energy.';
lines{end+1,1} = '- Visual elbow inspection should be read together with the rank estimate and the first five mode shapes.';
end

function lines = buildReconstructionSection(data, reconRows)
lines = {};
rank1 = reconRows(reconRows.rank_used == 1, :);
rank2 = reconRows(reconRows.rank_used == 2, :);

lines{end+1,1} = ['## ' char(data.displayName) ' reconstruction diagnostics'];
lines{end+1,1} = sprintf('- rank-1 relative Frobenius error: %.6f', rank1.relative_fro_error(1));
lines{end+1,1} = sprintf('- rank-1 energy captured: %.6f', rank1.variance_explained_or_energy_captured(1));
lines{end+1,1} = sprintf('- rank-1 max absolute residual: %.6g', rank1.max_abs_residual(1));
lines{end+1,1} = sprintf('- rank-1 RMS residual: %.6g', rank1.rms_residual(1));
if ~isempty(rank2)
    gain = rank2.variance_explained_or_energy_captured(1) - rank1.variance_explained_or_energy_captured(1);
    lines{end+1,1} = sprintf('- rank-2 relative Frobenius error: %.6f', rank2.relative_fro_error(1));
    lines{end+1,1} = sprintf('- rank-2 energy captured: %.6f', rank2.variance_explained_or_energy_captured(1));
    lines{end+1,1} = sprintf('- additional energy captured by rank-2 beyond rank-1: %.6f', gain);
end
lines{end+1,1} = ['- rank-1 visual reproduction: ' assessRank1Visual(rank1)];
lines{end+1,1} = ['- rank-1 residual assessment: ' assessResidualNature(data, rank1)];
lines{end+1,1} = ['- higher-mode interpretation: ' assessHigherModes(data, rank1, rank2)];
lines{end+1,1} = '- These reconstruction judgments are inferred from the saved reconstruction/residual maps together with the error metrics above.';
end

function txt = assessRank1Visual(rank1)
err = rank1.relative_fro_error(1);
captured = rank1.variance_explained_or_energy_captured(1);
if err <= 0.02 || captured >= 0.995
    txt = 'yes; the rank-1 reconstruction should be visually almost indistinguishable from the original map.';
elseif err <= 0.08 || captured >= 0.97
    txt = 'yes; the rank-1 reconstruction should reproduce the dominant map with only modest secondary corrections.';
elseif err <= 0.18 || captured >= 0.90
    txt = 'partially; rank-1 captures the dominant structure but visible secondary structure should remain.';
else
    txt = 'no; substantial structure should remain outside the first singular mode.';
end
end

function txt = assessResidualNature(data, rank1)
captured = rank1.variance_explained_or_energy_captured(1);
if captured >= 0.995
    txt = 'the residual is very weak and is most consistent with small corrections or noise rather than strong remaining structure.';
elseif captured >= 0.95
    if strcmpi(char(data.shortName), 'S')
        txt = 'the residual is weaker than the original map but still retains coherent structure, consistent with derivative amplification and weak higher-mode corrections rather than pure noise.';
    else
        txt = 'the residual is weaker than the original map but still retains coherent structure, so it contains weak higher-mode corrections rather than pure noise.';
    end
else
    txt = 'the residual retains substantial structured physics, so rank-1 alone is not sufficient.';
end
end

function txt = assessHigherModes(data, rank1, rank2)
gain = NaN;
if ~isempty(rank2)
    gain = rank2.variance_explained_or_energy_captured(1) - rank1.variance_explained_or_energy_captured(1);
end
captured = rank1.variance_explained_or_energy_captured(1);

if captured >= 0.995 && (~isfinite(gain) || gain < 0.002)
    txt = 'higher modes look negligible and are most consistent with weak noise-like corrections.';
elseif captured >= 0.95 && isfinite(gain) && gain < 0.01
    if strcmpi(char(data.shortName), 'S')
        txt = 'higher modes appear to be weak structured corrections, likely dominated by derivative amplification and minor secondary shape changes rather than a new dominant component.';
    else
        txt = 'higher modes appear to be weak structured corrections; they are real but clearly subdominant to the first mode.';
    end
elseif isfinite(gain) && gain >= 0.01
    txt = 'higher modes appear to contain genuine structured corrections beyond a purely rank-1 picture.';
else
    txt = 'higher modes are present but remain clearly subdominant to the first mode.';
end
end

function appendRankNotes(notesPath, label, data, reconRows)
rank1 = reconRows(reconRows.rank_used == 1, :);
appendText(notesPath, sprintf('%s effective rank (95%% energy): %d\n', label, data.rank95));
appendText(notesPath, sprintf('%s dominant structure: %s\n', label, char(data.rankLabel)));
appendText(notesPath, sprintf('%s rank-1 relative Frobenius error: %.6f\n', label, rank1.relative_fro_error(1)));
appendText(notesPath, sprintf('%s rank-1 energy captured: %.6f\n', label, rank1.variance_explained_or_energy_captured(1)));
end

function mapPath = resolveMapPath(repoRoot, providedPath, kind)
if strlength(strtrim(string(providedPath))) > 0
    mapPath = char(string(providedPath));
    if exist(mapPath, 'file') ~= 2
        error('Provided %s map path not found: %s', kind, mapPath);
    end
    return;
end

runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
if exist(runsRoot, 'dir') ~= 7
    error('Relaxation runs directory not found: %s', runsRoot);
end

runDirs = dir(fullfile(runsRoot, 'run_*'));
runDirs = runDirs([runDirs.isdir]);
if isempty(runDirs)
    error('No relaxation run directories found under %s', runsRoot);
end

names = string({runDirs.name});
valid = ~startsWith(names, "run_legacy", 'IgnoreCase', true);
runDirs = runDirs(valid);
if isempty(runDirs)
    error('No non-legacy relaxation runs found under %s', runsRoot);
end

[~, ord] = sort({runDirs.name});
runDirs = runDirs(ord);

if strcmpi(kind, 'dM')
    preferred = {'map_dM_raw.csv', 'map_dM_sg_100md.csv', 'map_dM_sg_200md.csv', 'map_dM_gauss2d.csv'};
else
    preferred = {'map_S_raw.csv', 'map_S_sg_100md.csv', 'map_S_sg_200md.csv', 'map_S_gauss2d.csv'};
end

subdirs = {'tables', 'csv', 'derivative_smoothing'};
for i = numel(runDirs):-1:1
    runRoot = fullfile(runDirs(i).folder, runDirs(i).name);
    for s = 1:numel(subdirs)
        for p = 1:numel(preferred)
            candidate = fullfile(runRoot, subdirs{s}, preferred{p});
            if exist(candidate, 'file') == 2
                mapPath = candidate;
                return;
            end
        end
    end
end

error('Could not locate a %s map in recent relaxation runs.', kind);
end

function [mapPath, found] = resolveOptionalSMapPath(repoRoot)
found = false;
mapPath = "";
try
    mapPath = resolveMapPath(repoRoot, "", 'S');
    found = true;
catch
    found = false;
end
end

function out = SPathOrEmpty(hasS, pathValue)
if hasS
    out = string(pathValue);
else
    out = "";
end
end

function appendText(path, txt)
fid = fopen(path, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', txt);
end

function v = getDef(s, f, d)
if isfield(s, f)
    v = s.(f);
else
    v = d;
end
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
