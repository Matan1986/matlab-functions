% switching_mode23_analysis
% Quantifies whether switching ridge/shape evolution is better described by
% coeff_mode2 alone, coeff_mode3 alone, or the joint mode2+mode3 subspace.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

alignDir = resolve_results_input_dir(repoRoot, 'switching', 'alignment_audit');
followupDir = resolve_results_input_dir(repoRoot, 'switching', 'mechanism_followup');
[outDir, run] = init_run_output_dir(repoRoot, 'switching', 'mode23_analysis'); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

metricType = "P2P_percent"; %#ok<NASGU>

obsCsv = fullfile(alignDir, 'switching_alignment_observables_vs_T.csv');
samplesCsv = fullfile(alignDir, 'switching_alignment_samples.csv');
shapeCsv = fullfile(followupDir, 'mechanism_ridge_shape_metrics.csv');

assert(isfile(obsCsv), 'Missing observables CSV: %s', obsCsv);
assert(isfile(samplesCsv), 'Missing samples CSV: %s', samplesCsv);

obsTbl = readtable(obsCsv);
samplesTbl = readtable(samplesCsv);

if ismember('metricType', samplesTbl.Properties.VariableNames)
    metricVals = string(samplesTbl.metricType);
    bad = metricVals ~= "P2P_percent";
    if any(bad)
        error('Found non-P2P_percent rows in samples CSV. mode23 analysis requires fixed metricType=P2P_percent.');
    end
end

T = toNumericColumn(obsTbl, 'T_K');
I_peak = toNumericColumn(obsTbl, 'Ipeak');
width_I = toNumericColumn(obsTbl, 'width_I');
coeff_mode2 = toNumericColumn(obsTbl, 'coeff_mode2');
coeff_mode3 = toNumericColumn(obsTbl, 'coeff_mode3');

assert(any(isfinite(coeff_mode2)), 'coeff_mode2 is missing or non-finite in observables CSV.');
assert(any(isfinite(coeff_mode3)), 'coeff_mode3 is missing or non-finite in observables CSV.');

% Optional shape metrics from mechanism_followup outputs.
shapeTbl = table();
shapeColsFound = strings(0,1);
if isfile(shapeCsv)
    shapeTbl = readtable(shapeCsv);
    shapeNames = ["shape_rmse_to_lowT_mean", "left_half_width_norm", "right_half_width_norm", ...
        "halfwidth_diff_norm", "area_ratio_right_over_left", "curvature_near_peak"];
    for k = 1:numel(shapeNames)
        if ismember(shapeNames(k), string(shapeTbl.Properties.VariableNames))
            shapeColsFound(end+1,1) = shapeNames(k); %#ok<SAGROW>
        end
    end
end

shapeAligned = struct();
shapeMissing = strings(0,1);
for k = 1:numel(shapeColsFound)
    shapeAligned.(shapeColsFound(k)) = NaN(size(T));
end
if ~isempty(shapeTbl) && ismember('T_K', string(shapeTbl.Properties.VariableNames))
    Ts = toNumericColumn(shapeTbl, 'T_K');
    [~, iObs, iShape] = intersect(T, Ts, 'stable');
    for k = 1:numel(shapeColsFound)
        col = toNumericColumn(shapeTbl, char(shapeColsFound(k)));
        v = NaN(size(T));
        if ~isempty(iObs)
            v(iObs) = col(iShape);
        end
        shapeAligned.(shapeColsFound(k)) = v;
    end
else
    if isfile(shapeCsv)
        shapeMissing(end+1,1) = "T_K missing in mechanism_ridge_shape_metrics.csv"; %#ok<SAGROW>
    else
        shapeMissing(end+1,1) = "mechanism_ridge_shape_metrics.csv not found"; %#ok<SAGROW>
    end
end

regimeNames = ["global", "low_4_12K", "transition_14_20K", "high_22_30K"];
regimeRanges = [-inf inf; 4 12; 14 20; 22 30];

% -------------------------------------------------------------------------
% STEP 2: Mode correlation analysis (global + optional regimes).
% -------------------------------------------------------------------------
corrRows = repmat(initCorrRow(), 0, 1);

baseTargets = struct('name', {"I_peak", "width_I"}, 'vec', {I_peak, width_I});
for tt = 1:numel(baseTargets)
    y = baseTargets(tt).vec;
    for rr = 1:numel(regimeNames)
        mReg = T >= regimeRanges(rr,1) & T <= regimeRanges(rr,2) & isfinite(T);

        v2 = mReg & isfinite(y) & isfinite(coeff_mode2);
        row2 = initCorrRow();
        row2.target = baseTargets(tt).name;
        row2.predictor = "coeff_mode2";
        row2.regime = regimeNames(rr);
        row2.T_min = regimeRanges(rr,1);
        row2.T_max = regimeRanges(rr,2);
        row2.n_points = nnz(v2);
        row2.corr_pearson = safeCorr(coeff_mode2(v2), y(v2));
        corrRows(end+1,1) = row2; %#ok<SAGROW>

        v3 = mReg & isfinite(y) & isfinite(coeff_mode3);
        row3 = initCorrRow();
        row3.target = baseTargets(tt).name;
        row3.predictor = "coeff_mode3";
        row3.regime = regimeNames(rr);
        row3.T_min = regimeRanges(rr,1);
        row3.T_max = regimeRanges(rr,2);
        row3.n_points = nnz(v3);
        row3.corr_pearson = safeCorr(coeff_mode3(v3), y(v3));
        corrRows(end+1,1) = row3; %#ok<SAGROW>
    end
end

% Optional extra correlations with existing ridge-shape metrics if available.
for k = 1:numel(shapeColsFound)
    nm = shapeColsFound(k);
    y = shapeAligned.(nm);
    for rr = 1:numel(regimeNames)
        mReg = T >= regimeRanges(rr,1) & T <= regimeRanges(rr,2) & isfinite(T);

        v2 = mReg & isfinite(y) & isfinite(coeff_mode2);
        row2 = initCorrRow();
        row2.target = nm;
        row2.predictor = "coeff_mode2";
        row2.regime = regimeNames(rr);
        row2.T_min = regimeRanges(rr,1);
        row2.T_max = regimeRanges(rr,2);
        row2.n_points = nnz(v2);
        row2.corr_pearson = safeCorr(coeff_mode2(v2), y(v2));
        corrRows(end+1,1) = row2; %#ok<SAGROW>

        v3 = mReg & isfinite(y) & isfinite(coeff_mode3);
        row3 = initCorrRow();
        row3.target = nm;
        row3.predictor = "coeff_mode3";
        row3.regime = regimeNames(rr);
        row3.T_min = regimeRanges(rr,1);
        row3.T_max = regimeRanges(rr,2);
        row3.n_points = nnz(v3);
        row3.corr_pearson = safeCorr(coeff_mode3(v3), y(v3));
        corrRows(end+1,1) = row3; %#ok<SAGROW>
    end
end

corrTbl = struct2table(corrRows);
corrOut = fullfile(outDir, 'mode23_correlation_table.csv');
writetable(corrTbl, corrOut);

% -------------------------------------------------------------------------
% STEP 3: Structural subspace regression tests.
% -------------------------------------------------------------------------
regRows = repmat(initRegRow(), 0, 1);
predStore = struct();

targets = struct('name', {"I_peak", "width_I"}, 'vec', {I_peak, width_I});
for tt = 1:numel(targets)
    y = targets(tt).vec;

    for rr = 1:numel(regimeNames)
        mReg = T >= regimeRanges(rr,1) & T <= regimeRanges(rr,2) & isfinite(T);

        % Model A: mode2 only
        mA = mReg & isfinite(y) & isfinite(coeff_mode2);
        [metA, yhatA] = fitLinearModel(y, coeff_mode2, coeff_mode3, "mode2_only", mA);
        rowA = initRegRow();
        rowA.target = targets(tt).name;
        rowA.regime = regimeNames(rr);
        rowA.model = "mode2_only";
        rowA.n_points = metA.n_points;
        rowA.R2 = metA.R2;
        rowA.RMSE = metA.RMSE;
        rowA.intercept = metA.intercept;
        rowA.beta_mode2 = metA.beta_mode2;
        rowA.beta_mode3 = metA.beta_mode3;
        regRows(end+1,1) = rowA; %#ok<SAGROW>

        % Model B: mode3 only
        mB = mReg & isfinite(y) & isfinite(coeff_mode3);
        [metB, yhatB] = fitLinearModel(y, coeff_mode2, coeff_mode3, "mode3_only", mB);
        rowB = initRegRow();
        rowB.target = targets(tt).name;
        rowB.regime = regimeNames(rr);
        rowB.model = "mode3_only";
        rowB.n_points = metB.n_points;
        rowB.R2 = metB.R2;
        rowB.RMSE = metB.RMSE;
        rowB.intercept = metB.intercept;
        rowB.beta_mode2 = metB.beta_mode2;
        rowB.beta_mode3 = metB.beta_mode3;
        regRows(end+1,1) = rowB; %#ok<SAGROW>

        % Model C: mode2 + mode3
        mC = mReg & isfinite(y) & isfinite(coeff_mode2) & isfinite(coeff_mode3);
        [metC, yhatC] = fitLinearModel(y, coeff_mode2, coeff_mode3, "mode23", mC);
        rowC = initRegRow();
        rowC.target = targets(tt).name;
        rowC.regime = regimeNames(rr);
        rowC.model = "mode23";
        rowC.n_points = metC.n_points;
        rowC.R2 = metC.R2;
        rowC.RMSE = metC.RMSE;
        rowC.intercept = metC.intercept;
        rowC.beta_mode2 = metC.beta_mode2;
        rowC.beta_mode3 = metC.beta_mode3;
        regRows(end+1,1) = rowC; %#ok<SAGROW>

        if regimeNames(rr) == "global"
            predStore.(targets(tt).name).obs = y;
            predStore.(targets(tt).name).hat_mode2 = yhatA;
            predStore.(targets(tt).name).hat_mode3 = yhatB;
            predStore.(targets(tt).name).hat_mode23 = yhatC;
        end
    end
end

regTbl = struct2table(regRows);
regOut = fullfile(outDir, 'mode23_regression_metrics.csv');
writetable(regTbl, regOut);

% -------------------------------------------------------------------------
% STEP 4: Visualization outputs.
% -------------------------------------------------------------------------
figI = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1100 450]);
tlI = tiledlayout(figI, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axI1 = nexttile(tlI, 1);
v = isfinite(coeff_mode2) & isfinite(I_peak);
scatter(axI1, coeff_mode2(v), I_peak(v), 60, T(v), 'filled');
xlabel(axI1, 'coeff\_mode2'); ylabel(axI1, 'I_{peak} (mA)');
title(axI1, sprintf('I_{peak} vs mode2 (corr=%.3f)', safeCorr(coeff_mode2(v), I_peak(v))));
grid(axI1, 'on'); cb = colorbar(axI1); ylabel(cb, 'T (K)');

axI2 = nexttile(tlI, 2);
v = isfinite(coeff_mode3) & isfinite(I_peak);
scatter(axI2, coeff_mode3(v), I_peak(v), 60, T(v), 'filled');
xlabel(axI2, 'coeff\_mode3'); ylabel(axI2, 'I_{peak} (mA)');
title(axI2, sprintf('I_{peak} vs mode3 (corr=%.3f)', safeCorr(coeff_mode3(v), I_peak(v))));
grid(axI2, 'on'); cb = colorbar(axI2); ylabel(cb, 'T (K)');

scatterIOut = fullfile(outDir, 'mode23_scatter_Ipeak.png');
saveas(figI, scatterIOut);
close(figI);

figW = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1100 450]);
tlW = tiledlayout(figW, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axW1 = nexttile(tlW, 1);
v = isfinite(coeff_mode2) & isfinite(width_I);
scatter(axW1, coeff_mode2(v), width_I(v), 60, T(v), 'filled');
xlabel(axW1, 'coeff\_mode2'); ylabel(axW1, 'width_I (mA)');
title(axW1, sprintf('width_I vs mode2 (corr=%.3f)', safeCorr(coeff_mode2(v), width_I(v))));
grid(axW1, 'on'); cb = colorbar(axW1); ylabel(cb, 'T (K)');

axW2 = nexttile(tlW, 2);
v = isfinite(coeff_mode3) & isfinite(width_I);
scatter(axW2, coeff_mode3(v), width_I(v), 60, T(v), 'filled');
xlabel(axW2, 'coeff\_mode3'); ylabel(axW2, 'width_I (mA)');
title(axW2, sprintf('width_I vs mode3 (corr=%.3f)', safeCorr(coeff_mode3(v), width_I(v))));
grid(axW2, 'on'); cb = colorbar(axW2); ylabel(cb, 'T (K)');

scatterWOut = fullfile(outDir, 'mode23_scatter_width.png');
saveas(figW, scatterWOut);
close(figW);

fig3D = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 800 650]);
ax3 = axes(fig3D);
v = isfinite(coeff_mode2) & isfinite(coeff_mode3) & isfinite(I_peak);
scatter3(ax3, coeff_mode2(v), coeff_mode3(v), I_peak(v), 70, T(v), 'filled');
xlabel(ax3, 'coeff\_mode2'); ylabel(ax3, 'coeff\_mode3'); zlabel(ax3, 'I_{peak} (mA)');
title(ax3, '3D structural view: (mode2, mode3, I_{peak})');
grid(ax3, 'on'); view(ax3, 38, 24); cb = colorbar(ax3); ylabel(cb, 'T (K)');

scatter3DOut = fullfile(outDir, 'mode23_3D_scatter.png');
saveas(fig3D, scatter3DOut);
close(fig3D);

figFit = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1300 820]);
tlF = tiledlayout(figFit, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

plotPredObs(nexttile(tlF,1), predStore.I_peak.obs, predStore.I_peak.hat_mode2, 'I_{peak}: mode2 only', regTbl, 'I_peak', 'mode2_only');
plotPredObs(nexttile(tlF,2), predStore.I_peak.obs, predStore.I_peak.hat_mode3, 'I_{peak}: mode3 only', regTbl, 'I_peak', 'mode3_only');
plotPredObs(nexttile(tlF,3), predStore.I_peak.obs, predStore.I_peak.hat_mode23, 'I_{peak}: mode2+mode3', regTbl, 'I_peak', 'mode23');
plotPredObs(nexttile(tlF,4), predStore.width_I.obs, predStore.width_I.hat_mode2, 'width_I: mode2 only', regTbl, 'width_I', 'mode2_only');
plotPredObs(nexttile(tlF,5), predStore.width_I.obs, predStore.width_I.hat_mode3, 'width_I: mode3 only', regTbl, 'width_I', 'mode3_only');
plotPredObs(nexttile(tlF,6), predStore.width_I.obs, predStore.width_I.hat_mode23, 'width_I: mode2+mode3', regTbl, 'width_I', 'mode23');

fitOut = fullfile(outDir, 'mode23_regression_fits.png');
saveas(figFit, fitOut);
close(figFit);

% -------------------------------------------------------------------------
% Report
% -------------------------------------------------------------------------
reportOut = fullfile(outDir, 'mode23_analysis_report.md');
fid = fopen(reportOut, 'w');
assert(fid >= 0, 'Failed opening report: %s', reportOut);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Mode2/Mode3 Structural Analysis Report\n\n');
fprintf(fid, '## Inputs Reused\n\n');
fprintf(fid, '- `results/switching/alignment_audit/switching_alignment_observables_vs_T.csv`\n');
fprintf(fid, '- `results/switching/alignment_audit/switching_alignment_samples.csv` (metricType verified as `P2P_percent`)\n');
if ~isempty(shapeColsFound)
    fprintf(fid, '- Optional shape metrics loaded from `results/switching/mechanism_followup/mechanism_ridge_shape_metrics.csv`: %s\n', strjoin(cellstr(shapeColsFound), ', '));
else
    fprintf(fid, '- Optional shape metrics from mechanism_followup: not available / not used\n');
end
if ~isempty(shapeMissing)
    fprintf(fid, '- Missing/notes: %s\n', strjoin(cellstr(shapeMissing), '; '));
end
fprintf(fid, '\n');

fprintf(fid, '## Core Correlations (Global)\n\n');
printCorr(fid, corrTbl, 'I_peak', 'coeff_mode2', 'global');
printCorr(fid, corrTbl, 'I_peak', 'coeff_mode3', 'global');
printCorr(fid, corrTbl, 'width_I', 'coeff_mode2', 'global');
printCorr(fid, corrTbl, 'width_I', 'coeff_mode3', 'global');
fprintf(fid, '\n');

fprintf(fid, '## Regression Results (Global)\n\n');
printReg(fid, regTbl, 'I_peak', 'mode2_only');
printReg(fid, regTbl, 'I_peak', 'mode3_only');
printReg(fid, regTbl, 'I_peak', 'mode23');
fprintf(fid, '\n');
printReg(fid, regTbl, 'width_I', 'mode2_only');
printReg(fid, regTbl, 'width_I', 'mode3_only');
printReg(fid, regTbl, 'width_I', 'mode23');
fprintf(fid, '\n');

r2I2 = getR2(regTbl, 'I_peak', 'mode2_only');
r2I3 = getR2(regTbl, 'I_peak', 'mode3_only');
r2I23 = getR2(regTbl, 'I_peak', 'mode23');
r2W2 = getR2(regTbl, 'width_I', 'mode2_only');
r2W3 = getR2(regTbl, 'width_I', 'mode3_only');
r2W23 = getR2(regTbl, 'width_I', 'mode23');

dI2to23 = r2I23 - max(r2I2, r2I3);
dW2to23 = r2W23 - max(r2W2, r2W3);

fprintf(fid, '## Regime-wise Summary\n\n');
for rr = 2:numel(regimeNames)
    fprintf(fid, '- %s:\n', regimeNames(rr));
    printCorr(fid, corrTbl, 'I_peak', 'coeff_mode2', regimeNames(rr));
    printCorr(fid, corrTbl, 'I_peak', 'coeff_mode3', regimeNames(rr));
    printCorr(fid, corrTbl, 'width_I', 'coeff_mode2', regimeNames(rr));
    printCorr(fid, corrTbl, 'width_I', 'coeff_mode3', regimeNames(rr));
end
fprintf(fid, '\n');

fprintf(fid, '## Interpretation\n\n');
fprintf(fid, '1. **Individual explanatory power**: mode2 and mode3 each correlate with ridge observables, but with different strengths for `I_peak` and `width_I`.\n');
fprintf(fid, '2. **Joint model gain**: relative to the better single-mode model, adding the second mode changes R^2 by:\n');
fprintf(fid, '   - `I_peak`: DeltaR^2 = %.3f\n', dI2to23);
fprintf(fid, '   - `width_I`: DeltaR^2 = %.3f\n', dW2to23);
if isfinite(dI2to23) && isfinite(dW2to23)
    if dI2to23 > 0.05 || dW2to23 > 0.05
        fprintf(fid, '3. **Subspace conclusion**: the combined mode2+mode3 model gives a material improvement for at least one ridge-shape observable, which is consistent with a two-dimensional structural subspace.\n');
    else
        fprintf(fid, '3. **Subspace conclusion**: the combined mode2+mode3 model provides limited gain over the best single mode, so current evidence for a strongly two-dimensional shape subspace is moderate rather than definitive.\n');
    end
else
    fprintf(fid, '3. **Subspace conclusion**: insufficient finite regression metrics for a strict subspace decision.\n');
end
fprintf(fid, '\n');

fprintf(fid, '## Output Files\n\n');
fprintf(fid, '- `mode23_correlation_table.csv`\n');
fprintf(fid, '- `mode23_regression_metrics.csv`\n');
fprintf(fid, '- `mode23_scatter_Ipeak.png`\n');
fprintf(fid, '- `mode23_scatter_width.png`\n');
fprintf(fid, '- `mode23_3D_scatter.png`\n');
fprintf(fid, '- `mode23_regression_fits.png`\n');
fprintf(fid, '- `mode23_analysis_report.md`\n\n');

fprintf(fid, 'Generated: %s\n', datestr(now, 31));

fprintf('Mode23 analysis complete.\n');
fprintf('Output directory: %s\n', outDir);
fprintf('Correlation table: %s\n', corrOut);
fprintf('Regression table: %s\n', regOut);
fprintf('Report: %s\n', reportOut);


function x = toNumericColumn(tbl, varName)
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


function r = safeCorr(a, b)
if isempty(a) || isempty(b)
    r = NaN;
    return;
end
v = isfinite(a) & isfinite(b);
if nnz(v) < 3
    r = NaN;
    return;
end
r = corr(a(v), b(v), 'rows', 'complete');
end


function [m, yhat] = fitLinearModel(y, c2, c3, modelName, mask)
yhat = NaN(size(y));
m = struct('n_points', nnz(mask), 'R2', NaN, 'RMSE', NaN, ...
    'intercept', NaN, 'beta_mode2', NaN, 'beta_mode3', NaN);

if nnz(mask) < 3
    return;
end

switch string(modelName)
    case "mode2_only"
        X = [ones(nnz(mask),1), c2(mask)];
    case "mode3_only"
        X = [ones(nnz(mask),1), c3(mask)];
    case "mode23"
        X = [ones(nnz(mask),1), c2(mask), c3(mask)];
    otherwise
        return;
end

yv = y(mask);
beta = X \ yv;
yfit = X * beta;
yhat(mask) = yfit;

sse = sum((yv - yfit).^2, 'omitnan');
sst = sum((yv - mean(yv, 'omitnan')).^2, 'omitnan');
if sst > 0
    m.R2 = 1 - sse / sst;
else
    m.R2 = NaN;
end
m.RMSE = sqrt(mean((yv - yfit).^2, 'omitnan'));
m.intercept = beta(1);
if string(modelName) == "mode2_only"
    m.beta_mode2 = beta(2);
elseif string(modelName) == "mode3_only"
    m.beta_mode3 = beta(2);
elseif string(modelName) == "mode23"
    m.beta_mode2 = beta(2);
    m.beta_mode3 = beta(3);
end
end


function row = initCorrRow()
row = struct();
row.target = "";
row.predictor = "";
row.regime = "";
row.T_min = NaN;
row.T_max = NaN;
row.n_points = NaN;
row.corr_pearson = NaN;
end


function row = initRegRow()
row = struct();
row.target = "";
row.regime = "";
row.model = "";
row.n_points = NaN;
row.R2 = NaN;
row.RMSE = NaN;
row.intercept = NaN;
row.beta_mode2 = NaN;
row.beta_mode3 = NaN;
end


function plotPredObs(ax, yObs, yHat, ttl, regTbl, target, model)
v = isfinite(yObs) & isfinite(yHat);
if nnz(v) >= 2
    scatter(ax, yObs(v), yHat(v), 55, 'filled');
    hold(ax, 'on');
    lo = min([yObs(v); yHat(v)]);
    hi = max([yObs(v); yHat(v)]);
    if isfinite(lo) && isfinite(hi)
        plot(ax, [lo hi], [lo hi], 'k--', 'LineWidth', 1.2);
    end
else
    text(ax, 0.5, 0.5, 'insufficient finite points', 'Units', 'normalized', ...
        'HorizontalAlignment', 'center');
end
xlabel(ax, 'Observed'); ylabel(ax, 'Predicted');
row = regTbl(regTbl.target == string(target) & regTbl.regime == "global" & regTbl.model == string(model), :);
if ~isempty(row)
    title(ax, sprintf('%s | R^2=%.3f, RMSE=%.3g', ttl, row.R2(1), row.RMSE(1)));
else
    title(ax, ttl);
end
grid(ax, 'on');
end


function printCorr(fid, corrTbl, target, predictor, regime)
row = corrTbl(corrTbl.target == string(target) & corrTbl.predictor == string(predictor) & corrTbl.regime == string(regime), :);
if isempty(row)
    fprintf(fid, '- corr(%s, %s) [%s]: unavailable\n', target, predictor, regime);
else
    fprintf(fid, '- corr(%s, %s) [%s] = %.3f (n=%d)\n', target, predictor, regime, row.corr_pearson(1), row.n_points(1));
end
end


function printReg(fid, regTbl, target, model)
row = regTbl(regTbl.target == string(target) & regTbl.regime == "global" & regTbl.model == string(model), :);
if isempty(row)
    fprintf(fid, '- %s / %s: unavailable\n', target, model);
else
    fprintf(fid, '- %s / %s: R^2=%.3f, RMSE=%.3g, n=%d\n', target, model, row.R2(1), row.RMSE(1), row.n_points(1));
end
end


function r2 = getR2(regTbl, target, model)
r2 = NaN;
row = regTbl(regTbl.target == string(target) & regTbl.regime == "global" & regTbl.model == string(model), :);
if ~isempty(row)
    r2 = row.R2(1);
end
end

