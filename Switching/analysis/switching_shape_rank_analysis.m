% switching_shape_rank_analysis
% Empirical dimensionality test of switching-map shape sector after amplitude removal.
%
% Uses wrapper outputs only (no legacy pipeline modifications).
% Required fixed signal definition: metricType = P2P_percent.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

alignDir = resolve_results_input_dir(repoRoot, 'switching', 'alignment_audit');
[outDir, run] = init_run_output_dir(repoRoot, 'switching', 'shape_rank_analysis'); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

metricType = "P2P_percent"; %#ok<NASGU>

samplesCsv = fullfile(alignDir, 'switching_alignment_samples.csv');
assert(isfile(samplesCsv), 'Missing required samples file: %s', samplesCsv);

sampTbl = readtable(samplesCsv);

if ismember('metricType', string(sampTbl.Properties.VariableNames))
    mType = string(sampTbl.metricType);
    bad = mType ~= "P2P_percent";
    if any(bad)
        error('Samples include non-P2P_percent rows. shape_rank_analysis requires fixed metricType=P2P_percent.');
    end
end

% STEP 1: reconstruct map using rounded-T convention.
[temps, currents, Smap] = buildMapRounded(sampTbl);

% STEP 2: amplitude-normalized map and centered shape map.
S_peak = NaN(size(temps));
rowMean = NaN(size(temps));
S_norm = NaN(size(Smap));
S_shape = NaN(size(Smap));

for it = 1:numel(temps)
    row = Smap(it,:);
    valid = isfinite(row);
    if ~any(valid)
        continue;
    end
    sPk = max(row(valid), [], 'omitnan');
    S_peak(it) = sPk;
end

globalPeak = max(S_peak(isfinite(S_peak)), [], 'omitnan');
if ~isfinite(globalPeak)
    error('No finite peaks found in reconstructed map.');
end

% Degenerate-row thresholds (explicit and reported).
peakAbsFloor = max(1e-6, 1e-4 * globalPeak);
validRows = isfinite(S_peak) & (S_peak > peakAbsFloor);
excludedRows = ~validRows;

for it = 1:numel(temps)
    if ~validRows(it)
        continue;
    end
    row = Smap(it,:);
    valid = isfinite(row);
    rowN = NaN(size(row));
    rowN(valid) = row(valid) / S_peak(it);
    S_norm(it,:) = rowN;

    mu = mean(rowN(valid), 'omitnan');
    rowMean(it) = mu;
    rowC = rowN;
    rowC(valid) = rowN(valid) - mu;
    S_shape(it,:) = rowC;
end

% STEP 3: SVD rank analysis.
resNorm = analyzeRank(S_norm, 3);
resShape = analyzeRank(S_shape, 3);

% Optional robustness check: remove weak/high-T rows.
robustRows = validRows & isfinite(temps) & temps <= 30 & S_peak >= 0.05 * globalPeak;
S_shape_rob = S_shape(robustRows, :);
temps_rob = temps(robustRows);
resShapeRob = analyzeRank(S_shape_rob, 3);

% Singular values CSV
maxModes = max([numel(resNorm.singvals), numel(resShape.singvals), numel(resShapeRob.singvals), 3]);
modeIdx = (1:maxModes)';
svNorm = padWithNaN(resNorm.singvals, maxModes);
svShape = padWithNaN(resShape.singvals, maxModes);
svShapeRob = padWithNaN(resShapeRob.singvals, maxModes);
svNormN = padWithNaN(resNorm.normSingvals, maxModes);
svShapeN = padWithNaN(resShape.normSingvals, maxModes);
svShapeRobN = padWithNaN(resShapeRob.normSingvals, maxModes);
svNormCum = padWithNaN(resNorm.cumEnergy, maxModes);
svShapeCum = padWithNaN(resShape.cumEnergy, maxModes);
svShapeRobCum = padWithNaN(resShapeRob.cumEnergy, maxModes);

svTbl = table(modeIdx, svNorm, svShape, svShapeRob, svNormN, svShapeN, svShapeRobN, svNormCum, svShapeCum, svShapeRobCum, ...
    'VariableNames', {'mode','singval_normMap','singval_shapeCentered','singval_shapeCentered_robust', ...
    'normSingval_normMap','normSingval_shapeCentered','normSingval_shapeCentered_robust', ...
    'cumEnergy_normMap','cumEnergy_shapeCentered','cumEnergy_shapeCentered_robust'});
svOut = fullfile(outDir, 'shape_rank_singular_values.csv');
writetable(svTbl, svOut);

% Reconstruction metrics CSV
recRows = repmat(initRecRow(), 0, 1);
for k = 1:3
    recRows(end+1,1) = mkRecRow("normMap", k, resNorm.froErr(k), resNorm.rmse(k), resNorm.cumEnergy(k), nnz(isfinite(S_norm))); %#ok<SAGROW>
    recRows(end+1,1) = mkRecRow("shapeCentered", k, resShape.froErr(k), resShape.rmse(k), resShape.cumEnergy(k), nnz(isfinite(S_shape))); %#ok<SAGROW>
    recRows(end+1,1) = mkRecRow("shapeCentered_robustRows", k, resShapeRob.froErr(k), resShapeRob.rmse(k), resShapeRob.cumEnergy(k), nnz(isfinite(S_shape_rob))); %#ok<SAGROW>
end
recTbl = struct2table(recRows);
recOut = fullfile(outDir, 'shape_rank_reconstruction_metrics.csv');
writetable(recTbl, recOut);

% STEP 4: Visual diagnostics.
% Spectrum
figSpec = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 520]);
tlSpec = tiledlayout(figSpec, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axS1 = nexttile(tlSpec, 1); hold(axS1, 'on');
plot(axS1, 1:numel(resNorm.normSingvals), resNorm.normSingvals, '-o', 'LineWidth', 1.8, 'DisplayName', 'S_{norm}');
plot(axS1, 1:numel(resShape.normSingvals), resShape.normSingvals, '-s', 'LineWidth', 1.8, 'DisplayName', 'S_{shape} centered');
plot(axS1, 1:numel(resShapeRob.normSingvals), resShapeRob.normSingvals, '-^', 'LineWidth', 1.8, 'DisplayName', 'S_{shape} centered robust');
xlabel(axS1, 'mode'); ylabel(axS1, 'normalized singular value');
title(axS1, 'Shape-rank spectrum'); grid(axS1, 'on'); legend(axS1, 'Location', 'best');

axS2 = nexttile(tlSpec, 2); hold(axS2, 'on');
plot(axS2, 1:numel(resNorm.cumEnergy), resNorm.cumEnergy, '-o', 'LineWidth', 1.8, 'DisplayName', 'S_{norm}');
plot(axS2, 1:numel(resShape.cumEnergy), resShape.cumEnergy, '-s', 'LineWidth', 1.8, 'DisplayName', 'S_{shape} centered');
plot(axS2, 1:numel(resShapeRob.cumEnergy), resShapeRob.cumEnergy, '-^', 'LineWidth', 1.8, 'DisplayName', 'S_{shape} centered robust');
plot(axS2, 1:3, resShape.froErr(1:3), '--d', 'LineWidth', 1.6, 'DisplayName', 'fro error centered');
xlabel(axS2, 'rank / mode index'); ylabel(axS2, 'cumulative energy or error');
title(axS2, 'Cumulative energy and centered-map errors'); grid(axS2, 'on'); legend(axS2, 'Location', 'best');

specOut = fullfile(outDir, 'shape_rank_spectrum.png');
saveas(figSpec, specOut);
close(figSpec);

% Right singular vectors (current modes) for centered map.
figModes = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axM = axes(figModes); hold(axM, 'on');
nModes = min(3, size(resShape.V,2));
markers = {'-o','-s','-^'};
for k = 1:nModes
    plot(axM, currents, resShape.V(:,k), markers{k}, 'LineWidth', 1.8, 'DisplayName', sprintf('mode %d', k));
end
xlabel(axM, 'I_0 (mA)'); ylabel(axM, 'right singular vector V_k(I)');
title(axM, 'Centered-shape current modes'); grid(axM, 'on'); legend(axM, 'Location', 'best');

modesOut = fullfile(outDir, 'shape_rank_modes.png');
saveas(figModes, modesOut);
close(figModes);

% Left coefficients vs temperature (U*S) for centered map.
figCoeff = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 600]);
axC = axes(figCoeff); hold(axC, 'on');
coeff = NaN(numel(temps), nModes);
for k = 1:nModes
    coeff(:,k) = resShape.U(:,k) * resShape.singvals(k);
    plot(axC, temps, coeff(:,k), markers{k}, 'LineWidth', 1.8, 'DisplayName', sprintf('mode %d coeff', k));
end
xlabel(axC, 'T (K)'); ylabel(axC, 'U_k(T) * s_k');
title(axC, 'Centered-shape temperature coefficients'); grid(axC, 'on'); legend(axC, 'Location', 'best');

coeffOut = fullfile(outDir, 'shape_rank_temperature_coefficients.png');
saveas(figCoeff, coeffOut);
close(figCoeff);

% Reconstruction comparison (normalized map and centered-map recon transformed back).
rowMeanMat = repmat(rowMean, 1, size(S_norm,2));
R1_center_back = resShape.recon{1} + rowMeanMat;
R2_center_back = resShape.recon{2} + rowMeanMat;
R3_center_back = resShape.recon{3} + rowMeanMat;

figRec = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1300 900]);
tlRec = tiledlayout(figRec, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
plotHeat(nexttile(tlRec,1), currents, temps, S_norm, 'S_{norm}(T,I)');
plotHeat(nexttile(tlRec,2), currents, temps, R1_center_back, 'rank-1 reconstruction');
plotHeat(nexttile(tlRec,3), currents, temps, R2_center_back, 'rank-2 reconstruction');
plotHeat(nexttile(tlRec,4), currents, temps, R3_center_back, 'rank-3 reconstruction');

recCmpOut = fullfile(outDir, 'shape_rank_reconstruction_comparison.png');
saveas(figRec, recCmpOut);
close(figRec);

% STEP 5: Residual anatomy maps.
resid1 = S_norm - R1_center_back;
resid2 = S_norm - R2_center_back;

figRes1 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 620]);
axR1 = axes(figRes1);
plotResidual(axR1, currents, temps, resid1, 'Residual map (rank-1)');
res1Out = fullfile(outDir, 'shape_rank_residual_rank1.png');
saveas(figRes1, res1Out);
close(figRes1);

figRes2 = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 620]);
axR2 = axes(figRes2);
plotResidual(axR2, currents, temps, resid2, 'Residual map (rank-2)');
res2Out = fullfile(outDir, 'shape_rank_residual_rank2.png');
saveas(figRes2, res2Out);
close(figRes2);

% Report
repOut = fullfile(outDir, 'shape_rank_report.md');
fid = fopen(repOut, 'w');
assert(fid >= 0, 'Failed opening report file: %s', repOut);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Shape Rank Analysis Report\n\n');
fprintf(fid, '## Inputs and Preprocessing\n\n');
fprintf(fid, '- Source map data: `results/switching/alignment_audit/switching_alignment_samples.csv`\n');
fprintf(fid, '- metricType verified: `P2P_percent`\n');
fprintf(fid, '- Map reconstruction convention: rounded temperature bins, mean S at each (T,I)\n');
fprintf(fid, '- Amplitude normalization: `S_norm(T,I)=S(T,I)/S_peak(T)`\n');
fprintf(fid, '- Shape-centered map: `S_shape(T,I)=S_norm(T,I)-mean_I[S_norm(T,I)]`\n');
fprintf(fid, '- Peak validity threshold: S_peak > %.3g\n', peakAbsFloor);
fprintf(fid, '- Excluded degenerate rows: %d/%d\n', nnz(excludedRows), numel(temps));
if any(excludedRows)
    fprintf(fid, '- Excluded temperatures (K): %s\n', strjoin(string(temps(excludedRows))', ', '));
end
fprintf(fid, '\n');

fprintf(fid, '## Rank Diagnostics (Centered Shape Map)\n\n');
for k = 1:3
    fprintf(fid, '- rank-%d: cumulative energy = %.3f, fro error = %.3f, RMSE = %.4f\n', ...
        k, resShape.cumEnergy(k), resShape.froErr(k), resShape.rmse(k));
end
fprintf(fid, '\n');

fprintf(fid, '## Robustness Check (Centered map, robust rows only: T<=30K and S_peak>=5%% max)\n\n');
fprintf(fid, '- Rows kept: %d / %d\n', nnz(robustRows), numel(temps));
for k = 1:3
    fprintf(fid, '- rank-%d robust: cumulative energy = %.3f, fro error = %.3f\n', ...
        k, resShapeRob.cumEnergy(k), resShapeRob.froErr(k));
end
fprintf(fid, '\n');

% Empirical dimensionality decision logic.
impr12 = resShape.froErr(1) - resShape.froErr(2);
impr23 = resShape.froErr(2) - resShape.froErr(3);
if resShape.cumEnergy(1) >= 0.90 && impr12 < 0.06
    dimText = 'effectively 1D';
    finalLine = 'Shape evolution is effectively one-dimensional after amplitude normalization, so a single X_shape observable is likely sufficient.';
elseif resShape.cumEnergy(2) >= 0.90 && impr12 >= 0.06 && impr23 < 0.05
    dimText = 'effectively 2D';
    finalLine = 'Shape evolution remains intrinsically two-dimensional after amplitude normalization, so a single X_shape observable is likely insufficient and at least two structural coordinates are needed.';
else
    dimText = 'higher-than-2D or mixed';
    finalLine = 'Shape evolution is not cleanly captured by one dimension and may require at least two, possibly more, structural coordinates in this dataset.';
end

fprintf(fid, '## Answers to Main Questions\n\n');
fprintf(fid, '1. After removing amplitude, effective shape dimensionality appears **%s**.\n', dimText);
fprintf(fid, '2. Rank-1 residual anatomy: inspect `shape_rank_residual_rank1.png` for structured branch/arm residuals.\n');
fprintf(fid, '3. Rank-2 residual anatomy: inspect `shape_rank_residual_rank2.png` for remaining systematic structure.\n');
fprintf(fid, '4. Single X_shape sufficiency: see explicit conclusion below.\n\n');

fprintf(fid, '## Explicit Conclusion\n\n');
fprintf(fid, '%s\n\n', finalLine);

fprintf(fid, '## Files\n\n');
fprintf(fid, '- shape_rank_singular_values.csv\n');
fprintf(fid, '- shape_rank_reconstruction_metrics.csv\n');
fprintf(fid, '- shape_rank_spectrum.png\n');
fprintf(fid, '- shape_rank_modes.png\n');
fprintf(fid, '- shape_rank_reconstruction_comparison.png\n');
fprintf(fid, '- shape_rank_residual_rank1.png\n');
fprintf(fid, '- shape_rank_residual_rank2.png\n');
fprintf(fid, '- shape_rank_temperature_coefficients.png\n');
fprintf(fid, '- shape_rank_report.md\n\n');

fprintf(fid, 'Generated: %s\n', datestr(now, 31));

% Review ZIP (exact required files only)
zipOut = fullfile(outDir, 'shape_rank_analysis_review.zip');
if isfile(zipOut)
    delete(zipOut);
end
reqFiles = { ...
    'shape_rank_singular_values.csv', ...
    'shape_rank_reconstruction_metrics.csv', ...
    'shape_rank_spectrum.png', ...
    'shape_rank_modes.png', ...
    'shape_rank_reconstruction_comparison.png', ...
    'shape_rank_residual_rank1.png', ...
    'shape_rank_residual_rank2.png', ...
    'shape_rank_temperature_coefficients.png', ...
    'shape_rank_report.md' ...
    };
zipPaths = strings(0,1);
for i = 1:numel(reqFiles)
    p = fullfile(outDir, reqFiles{i});
    if isfile(p)
        zipPaths(end+1,1) = string(p); %#ok<SAGROW>
    else
        error('Missing required output for ZIP: %s', p);
    end
end
zip(char(zipOut), cellstr(zipPaths));

fprintf('Shape-rank analysis complete.\n');
fprintf('Output directory: %s\n', outDir);
fprintf('Singular values CSV: %s\n', svOut);
fprintf('Reconstruction metrics CSV: %s\n', recOut);
fprintf('Report: %s\n', repOut);
fprintf('Review ZIP: %s\n', zipOut);


function [temps, currents, Smap] = buildMapRounded(tbl)
Traw = toNumeric(tbl, 'T_K');
Iraw = toNumeric(tbl, 'current_mA');
Sraw = toNumeric(tbl, 'S_percent');

v = isfinite(Traw) & isfinite(Iraw) & isfinite(Sraw);
Traw = Traw(v);
Iraw = Iraw(v);
Sraw = Sraw(v);

Tbin = round(Traw);
temps = unique(Tbin);
currents = unique(Iraw);
temps = sort(temps(:));
currents = sort(currents(:));

Smap = NaN(numel(temps), numel(currents));
for it = 1:numel(temps)
    for ii = 1:numel(currents)
        m = Tbin == temps(it) & abs(Iraw - currents(ii)) < 1e-9;
        if any(m)
            Smap(it,ii) = mean(Sraw(m), 'omitnan');
        end
    end
end
end


function x = toNumeric(tbl, varName)
if ~ismember(varName, string(tbl.Properties.VariableNames))
    x = NaN(height(tbl), 1);
    return;
end
col = tbl.(varName);
if isnumeric(col)
    x = double(col(:));
else
    x = str2double(string(col(:)));
end
end


function res = analyzeRank(M, maxRank)
res = struct();
mask = isfinite(M);
M0 = M;
M0(~mask) = 0;

if isempty(M0)
    [U,S,V] = deal([]);
else
    [U,S,V] = svd(M0, 'econ');
end
sv = diag(S);
if isempty(sv)
    sv = NaN;
end

res.U = U;
res.S = S;
res.V = V;
res.singvals = sv;

if any(isfinite(sv)) && sum(sv, 'omitnan') > 0
    res.normSingvals = sv / sum(sv, 'omitnan');
else
    res.normSingvals = NaN(size(sv));
end

if any(isfinite(sv)) && sum(sv.^2, 'omitnan') > 0
    res.cumEnergy = cumsum(sv.^2, 'omitnan') / sum(sv.^2, 'omitnan');
else
    res.cumEnergy = NaN(size(sv));
end

nK = min([maxRank, size(U,2), size(V,2)]);
res.recon = cell(maxRank,1);
res.froErr = NaN(maxRank,1);
res.rmse = NaN(maxRank,1);

base = M(mask);
if isempty(base)
    denom = NaN;
else
    denom = norm(base, 'fro');
end

for k = 1:maxRank
    if k <= nK
        R = U(:,1:k) * S(1:k,1:k) * V(:,1:k)';
    else
        R = NaN(size(M));
    end
    res.recon{k} = R;

    if ~isempty(base) && any(isfinite(R(mask)))
        d = base - R(mask);
        if isfinite(denom) && denom > 0
            res.froErr(k) = norm(d, 'fro') / denom;
        end
        res.rmse(k) = sqrt(mean(d.^2, 'omitnan'));
    end
end

% Ensure cumEnergy has at least maxRank entries for convenience.
if numel(res.cumEnergy) < maxRank
    res.cumEnergy = [res.cumEnergy; NaN(maxRank-numel(res.cumEnergy),1)];
end
end


function y = padWithNaN(x, n)
y = NaN(n,1);
if isempty(x)
    return;
end
m = min(numel(x), n);
y(1:m) = x(1:m);
end


function row = initRecRow()
row = struct();
row.variant = "";
row.rank = NaN;
row.fro_error = NaN;
row.rmse = NaN;
row.cumulative_energy = NaN;
row.n_valid_points = NaN;
end


function row = mkRecRow(variant, rank, fErr, rmse, cume, nPts)
row = initRecRow();
row.variant = string(variant);
row.rank = rank;
row.fro_error = fErr;
row.rmse = rmse;
row.cumulative_energy = cume;
row.n_valid_points = nPts;
end


function plotHeat(ax, currents, temps, M, ttl)
imagesc(ax, currents, temps, M);
set(ax, 'YDir', 'normal');
if exist('turbo', 'file') == 2
    colormap(ax, turbo);
else
    colormap(ax, parula);
end
xlabel(ax, 'I_0 (mA)');
ylabel(ax, 'T (K)');
title(ax, ttl);
cb = colorbar(ax);
ylabel(cb, 'normalized switching');
end


function plotResidual(ax, currents, temps, R, ttl)
imagesc(ax, currents, temps, R);
set(ax, 'YDir', 'normal');
applyDivergingColormap(ax);
vals = R(isfinite(R));
if ~isempty(vals)
    lim = max(abs(vals));
    if isfinite(lim) && lim > 0
        caxis(ax, [-lim lim]);
    end
end
xlabel(ax, 'I_0 (mA)');
ylabel(ax, 'T (K)');
title(ax, ttl);
cb = colorbar(ax);
ylabel(cb, 'residual');
end


function applyDivergingColormap(ax)
try
    if exist('redbluecmap', 'file') == 2
        rb = redbluecmap();
        if size(rb,2) == 3
            colormap(ax, rb);
            return;
        end
    end
catch
    % fall through to local diverging colormap
end
n = 256;
r = [(0:(n/2-1))/(n/2), ones(1,n/2)];
g = [(0:(n/2-1))/(n/2), ((n/2-1):-1:0)/(n/2)];
b = [ones(1,n/2), ((n/2-1):-1:0)/(n/2)];
colormap(ax, [r(:), g(:), b(:)]);
end


