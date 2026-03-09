function out = diagnose_mode1_separability()
% diagnose_mode1_separability
% Diagnostics-only test of separability for mode-1 SVD amplitudes:
%   A1(wait_time, Tp) ~= g(wait_time) * f(Tp)

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
agingRoot = fileparts(thisDir);
repoRoot = fileparts(agingRoot);

addpath(genpath(agingRoot));

outDir = getResultsDir('aging', 'separability');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

svdOutDir = getResultsDir('aging', 'svd_pca');
coeffCsv = fullfile(svdOutDir, 'curve_mode_coefficients.csv');
if ~exist(coeffCsv, 'file')
    fprintf('SVD coefficient file not found. Running diagnose_deltaM_svd_pca first...\n');
    addpath(genpath(agingRoot));
    diagnose_deltaM_svd_pca();
end

if ~exist(coeffCsv, 'file')
    error('Missing SVD coefficient file: %s', coeffCsv);
end

T = readtable(coeffCsv);
required = {'wait_time','Tp','matrix_name','coeff_mode1'};
for i = 1:numel(required)
    assert(ismember(required{i}, T.Properties.VariableNames), ...
        'Missing required column %s in %s', required{i}, coeffCsv);
end

T.wait_time = string(T.wait_time);
T.matrix_name = string(T.matrix_name);

waitOrder = string({'3 s','36 s','6 min','60 min'});
waitSec = [3; 36; 360; 3600];
matrixOrder = string({'raw_T','shifted_Tp'});

summaryRows = table();
coeffRows = table();
resStore = struct();

for m = 1:numel(matrixOrder)
    matrixName = matrixOrder(m);
    tM = T(T.matrix_name == matrixName, :);
    if isempty(tM)
        fprintf('Skipping matrix %s (no rows).\n', matrixName);
        continue;
    end

    [A, mask, TpVals, labels, secs] = buildA1Matrix(tM, waitOrder, waitSec);
    [Ahat, g, f] = rank1ApproxMissing(A, mask);
    [g, f] = normalizeSignScale(g, f);
    Ahat = g * f.';

    vals = A(mask);
    preds = Ahat(mask);

    sst = sum((vals - mean(vals, 'omitnan')).^2, 'omitnan');
    sse = sum((vals - preds).^2, 'omitnan');
    rank1Frac = 1 - sse / max(sst, eps);

    rmsRes = sqrt(mean((vals - preds).^2, 'omitnan'));
    relRmsRes = rmsRes / (sqrt(mean(vals.^2, 'omitnan')) + eps);

    if nnz(isfinite(vals) & isfinite(preds)) >= 3
        corrPred = corr(vals, preds, 'type', 'Pearson', 'rows', 'complete');
    else
        corrPred = NaN;
    end

    rowScale = computeRowScales(A);
    ArowNorm = A ./ rowScale;

    colScale = computeColScales(A);
    AcolNorm = A ./ colScale;

    [gMonotonicRho, fPeakTp, fPeakClear] = modeShapeDiagnostics(g, f, secs, TpVals);

    makeHeatmapTriplet(A, Ahat, A - Ahat, TpVals, labels, matrixName, outDir);
    makeGPlot(g, secs, labels, matrixName, outDir);
    makeFPlot(f, TpVals, matrixName, outDir);
    makeRowCollapsePlot(ArowNorm, TpVals, labels, matrixName, outDir);
    makeColCollapsePlot(AcolNorm, secs, labels, TpVals, matrixName, outDir);
    makeScatterPlot(vals, preds, matrixName, outDir);

    summaryRows = [summaryRows; table(matrixName, rank1Frac, rmsRes, relRmsRes, corrPred, ...
        gMonotonicRho, fPeakTp, fPeakClear, ...
        'VariableNames', {'matrix_name','rank1_fraction_of_A1_variance','RMS_residual', ...
        'relative_RMS_residual','correlation_original_vs_rank1_predicted', ...
        'spearman_g_vs_wait_seconds','f_peak_Tp','f_peak_clear'})]; %#ok<AGROW>

    coeffRows = [coeffRows; makeGFTable(matrixName, labels, TpVals, g, f)]; %#ok<AGROW>

    resStore.(char(matrixName)).A = A;
    resStore.(char(matrixName)).Ahat = Ahat;
    resStore.(char(matrixName)).Tp = TpVals;
    resStore.(char(matrixName)).waitLabels = labels;
    resStore.(char(matrixName)).g = g;
    resStore.(char(matrixName)).f = f;
    resStore.(char(matrixName)).rank1Frac = rank1Frac;
end

summaryCsv = fullfile(outDir, 'separability_summary.csv');
coeffCsvOut = fullfile(outDir, 'extracted_g_f.csv');
writetable(summaryRows, summaryCsv);
writetable(coeffRows, coeffCsvOut);

summaryTxt = buildSummaryText(summaryRows);
summaryTxtPath = fullfile(outDir, 'interpretation_summary.txt');
writeText(summaryTxtPath, summaryTxt);

fprintf('\n=== Mode-1 Separability Summary ===\n');
disp(summaryRows);
fprintf('Saved: %s\n', summaryCsv);
fprintf('Saved: %s\n', coeffCsvOut);
fprintf('Saved: %s\n', summaryTxtPath);

out = struct();
out.summary = summaryRows;
out.extracted = coeffRows;
out.results = resStore;
out.outDir = outDir;
end

function [A, mask, TpVals, labels, secs] = buildA1Matrix(tM, waitOrder, waitSec)
TpVals = unique(tM.Tp(isfinite(tM.Tp)));
TpVals = sort(TpVals(:));
labels = waitOrder(:);
secs = waitSec(:);

A = nan(numel(labels), numel(TpVals));
for i = 1:numel(labels)
    for j = 1:numel(TpVals)
        m = (tM.wait_time == labels(i)) & (abs(tM.Tp - TpVals(j)) < 1e-9);
        if any(m)
            A(i,j) = mean(tM.coeff_mode1(m), 'omitnan');
        end
    end
end
mask = isfinite(A);
end

function [Ahat, g, f] = rank1ApproxMissing(A, mask)
if ~any(mask, 'all')
    error('A1 matrix has no finite values.');
end

X = fillMissingForInit(A, mask);
maxIter = 200;
tol = 1e-10;

for it = 1:maxIter
    [U, S, V] = svd(X, 'econ');
    s1 = S(1,1);
    g = U(:,1) * sqrt(max(s1, 0));
    f = V(:,1) * sqrt(max(s1, 0));
    Xr = g * f.';

    Xnew = Xr;
    Xnew(mask) = A(mask);

    delta = norm(Xnew(:) - X(:), 2) / max(norm(X(:), 2), eps);
    X = Xnew;
    if delta < tol
        break;
    end
end

[U, S, V] = svd(X, 'econ');
s1 = S(1,1);
g = U(:,1) * sqrt(max(s1, 0));
f = V(:,1) * sqrt(max(s1, 0));
Ahat = g * f.';
end

function X = fillMissingForInit(A, mask)
X = A;
colMean = mean(A, 1, 'omitnan');
if any(~isfinite(colMean))
    rowMean = mean(A, 2, 'omitnan');
else
    rowMean = nan(size(A,1), 1);
end

globalMean = mean(A(mask), 'omitnan');
if ~isfinite(globalMean)
    globalMean = 0;
end

for i = 1:size(A,1)
    for j = 1:size(A,2)
        if ~mask(i,j)
            if isfinite(colMean(j))
                X(i,j) = colMean(j);
            elseif isfinite(rowMean(i))
                X(i,j) = rowMean(i);
            else
                X(i,j) = globalMean;
            end
        end
    end
end
end

function [gOut, fOut] = normalizeSignScale(g, f)
gOut = g(:);
fOut = f(:);

scale = max(abs(fOut));
if isfinite(scale) && scale > 0
    gOut = gOut * scale;
    fOut = fOut / scale;
end

[~, imax] = max(abs(fOut));
if ~isempty(imax) && fOut(imax) < 0
    gOut = -gOut;
    fOut = -fOut;
end
end

function s = computeRowScales(A)
s = nan(size(A,1), 1);
for i = 1:size(A,1)
    row = A(i,:);
    if any(isfinite(row))
        sc = max(abs(row), [], 'omitnan');
        if isfinite(sc) && sc > 0
            s(i) = sc;
        end
    end
end
end

function s = computeColScales(A)
s = nan(1, size(A,2));
for j = 1:size(A,2)
    col = A(:,j);
    if any(isfinite(col))
        sc = max(abs(col), [], 'omitnan');
        if isfinite(sc) && sc > 0
            s(j) = sc;
        end
    end
end
end

function [rho, TpPeak, peakClear] = modeShapeDiagnostics(g, f, secs, TpVals)
validG = isfinite(g) & isfinite(secs);
if nnz(validG) >= 3
    rho = corr(secs(validG), g(validG), 'type', 'Spearman', 'rows', 'complete');
else
    rho = NaN;
end

if any(isfinite(f))
    [fMax, imax] = max(f, [], 'omitnan');
    TpPeak = TpVals(imax);
    medAbs = median(abs(f), 'omitnan');
    peakClear = fMax > 1.2 * max(medAbs, eps);
else
    TpPeak = NaN;
    peakClear = false;
end
end

function t = makeGFTable(matrixName, waitLabels, TpVals, g, f)
nG = numel(g);
nF = numel(f);

matG = repmat(matrixName, nG, 1);
matF = repmat(matrixName, nF, 1);

tG = table(matG, repmat("g", nG, 1), string(waitLabels(:)), g(:), ...
    'VariableNames', {'matrix_name','type','coordinate','value'});
tF = table(matF, repmat("f", nF, 1), string(compose('%.6g', TpVals(:))), f(:), ...
    'VariableNames', {'matrix_name','type','coordinate','value'});

t = [tG; tF];
end

function makeHeatmapTriplet(A, Ahat, R, TpVals, labels, matrixName, outDir)
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 1380 420]);
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

nexttile;
imagesc(TpVals, 1:numel(labels), A);
set(gca, 'YTick', 1:numel(labels), 'YTickLabel', cellstr(labels));
xlabel('T_p (K)'); ylabel('wait time');
title(sprintf('%s: A1 original', matrixName), 'Interpreter', 'none');
colorbar; axis tight;

nexttile;
imagesc(TpVals, 1:numel(labels), Ahat);
set(gca, 'YTick', 1:numel(labels), 'YTickLabel', cellstr(labels));
xlabel('T_p (K)'); ylabel('wait time');
title('A1 rank-1 reconstruction');
colorbar; axis tight;

nexttile;
imagesc(TpVals, 1:numel(labels), R);
set(gca, 'YTick', 1:numel(labels), 'YTickLabel', cellstr(labels));
xlabel('T_p (K)'); ylabel('wait time');
title('Residual: A1 - A1_{rank1}');
colorbar; axis tight;

sgtitle(sprintf('Mode-1 separability heatmaps | %s', matrixName), 'Interpreter', 'none');
outPng = fullfile(outDir, sprintf('heatmaps_%s.png', matrixName));
saveas(figH, outPng);
close(figH);
end

function makeGPlot(g, secs, labels, matrixName, outDir)
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 720 450]);
semilogx(secs, g, 'o-', 'LineWidth', 1.6, 'MarkerSize', 7, 'Color', [0.1 0.45 0.8]);
grid on;
xticks(secs);
xticklabels(cellstr(labels));
xlabel('wait time');
ylabel('g(wait\_time)');
title(sprintf('Extracted g(wait time) | %s', matrixName), 'Interpreter', 'none');
outPng = fullfile(outDir, sprintf('g_%s.png', matrixName));
saveas(figH, outPng);
close(figH);
end

function makeFPlot(f, TpVals, matrixName, outDir)
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 720 450]);
plot(TpVals, f, 's-', 'LineWidth', 1.6, 'MarkerSize', 7, 'Color', [0.85 0.33 0.10]);
grid on;
xlabel('T_p (K)');
ylabel('f(T_p)');
title(sprintf('Extracted f(T_p) | %s', matrixName), 'Interpreter', 'none');
outPng = fullfile(outDir, sprintf('f_%s.png', matrixName));
saveas(figH, outPng);
close(figH);
end

function makeRowCollapsePlot(ArowNorm, TpVals, labels, matrixName, outDir)
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 780 500]);
cols = lines(numel(labels));
for i = 1:numel(labels)
    y = ArowNorm(i,:);
    plot(TpVals, y, 'o-', 'LineWidth', 1.4, 'MarkerSize', 5, ...
        'Color', cols(i,:), 'DisplayName', char(labels(i))); hold on;
end
grid on;
xlabel('T_p (K)');
ylabel('Row-normalized A1');
title(sprintf('Row-normalized collapse vs T_p | %s', matrixName), 'Interpreter', 'none');
lg = legend('Location', 'bestoutside');
lg.FontSize = 9;
lg.Box = 'off';
outPng = fullfile(outDir, sprintf('row_collapse_%s.png', matrixName));
saveas(figH, outPng);
close(figH);
end

function makeColCollapsePlot(AcolNorm, secs, labels, TpVals, matrixName, outDir)
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [120 120 900 500]);
cols = turbo(numel(TpVals));
for j = 1:numel(TpVals)
    y = AcolNorm(:,j);
    semilogx(secs, y, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, ...
        'Color', cols(j,:), 'DisplayName', sprintf('T_p=%.0f K', TpVals(j))); hold on;
end
grid on;
xticks(secs);
xticklabels(cellstr(labels));
xlabel('wait time');
ylabel('Column-normalized A1');
title(sprintf('Column-normalized collapse vs wait time | %s', matrixName), 'Interpreter', 'none');
lg = legend('Location', 'bestoutside');
lg.FontSize = 8;
lg.Box = 'off';
outPng = fullfile(outDir, sprintf('col_collapse_%s.png', matrixName));
saveas(figH, outPng);
close(figH);
end

function makeScatterPlot(vals, preds, matrixName, outDir)
figH = figure('Color', 'w', 'Visible', 'off', 'Position', [150 150 620 520]);
scatter(vals, preds, 45, 'filled', 'MarkerFaceColor', [0.2 0.55 0.85], 'MarkerFaceAlpha', 0.85); hold on;
mn = min([vals; preds], [], 'omitnan');
mx = max([vals; preds], [], 'omitnan');
if isfinite(mn) && isfinite(mx) && mx > mn
    pad = 0.05 * (mx - mn);
    lo = mn - pad;
    hi = mx + pad;
    plot([lo hi], [lo hi], 'k--', 'LineWidth', 1.2);
    xlim([lo hi]);
    ylim([lo hi]);
end
grid on;
xlabel('Original A1 entries');
ylabel('Rank-1 predicted A1');
title(sprintf('A1 original vs rank-1 prediction | %s', matrixName), 'Interpreter', 'none');
outPng = fullfile(outDir, sprintf('scatter_%s.png', matrixName));
saveas(figH, outPng);
close(figH);
end

function summaryTxt = buildSummaryText(summaryRows)
if isempty(summaryRows)
    summaryTxt = 'No matrix rows available for separability diagnostics.';
    return;
end

lines = strings(0,1);
for i = 1:height(summaryRows)
    row = summaryRows(i,:);
    sepFlag = tf(row.rank1_fraction_of_A1_variance >= 0.8 && row.relative_RMS_residual <= 0.4);
    monoFlag = tf(isfinite(row.spearman_g_vs_wait_seconds) && abs(row.spearman_g_vs_wait_seconds) >= 0.8);
    peakFlag = tf(row.f_peak_clear);

    lines(end+1,1) = sprintf('%s: rank1_fraction=%.4f, relRMS=%.4f, corr(orig,pred)=%.4f', ...
        row.matrix_name, row.rank1_fraction_of_A1_variance, row.relative_RMS_residual, ...
        row.correlation_original_vs_rank1_predicted);
    lines(end+1,1) = sprintf('  approximately separable? %s', sepFlag);
    lines(end+1,1) = sprintf('  g(wait) monotonic trend (|Spearman|>=0.8)? %s (rho=%.4f)', ...
        monoFlag, row.spearman_g_vs_wait_seconds);
    lines(end+1,1) = sprintf('  f(Tp) clear peak? %s (peak at Tp=%.3g K)', peakFlag, row.f_peak_Tp);
end

rawIdx = find(summaryRows.matrix_name == "raw_T", 1);
shiftIdx = find(summaryRows.matrix_name == "shifted_Tp", 1);
if ~isempty(rawIdx) && ~isempty(shiftIdx)
    better = 'raw_T';
    if summaryRows.rank1_fraction_of_A1_variance(shiftIdx) > summaryRows.rank1_fraction_of_A1_variance(rawIdx)
        better = 'shifted_Tp';
    end
    lines(end+1,1) = sprintf('Shifted vs raw separability: better rank-1 fit appears in %s.', better);
end

cand = false(height(summaryRows),1);
for i = 1:height(summaryRows)
    cand(i) = summaryRows.rank1_fraction_of_A1_variance(i) >= 0.8 && ...
        summaryRows.correlation_original_vs_rank1_predicted(i) >= 0.85;
end
lines(end+1,1) = sprintf('Mode-1 coefficient as global aging observable candidate: %s', tf(all(cand)));

summaryTxt = strjoin(cellstr(lines), newline);
end

function s = tf(flag)
if flag
    s = 'yes';
else
    s = 'no';
end
end

function writeText(filePath, txt)
fid = fopen(filePath, 'w');
assert(fid >= 0, 'Failed to open file for writing: %s', filePath);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', txt);
end



