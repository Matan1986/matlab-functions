% switching_XI_Xshape_analysis
% Tests geometric relation/independence between:
%   X_I(T)    = I_peak(T)
%   X_shape(T)= branching/asymmetry observable from S(T,I)
%
% Legacy switching code is NOT modified; this wrapper reuses existing CSV outputs.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

alignDir = resolve_results_input_dir(repoRoot, 'switching', 'alignment_audit');
[outDir, run] = init_run_output_dir(repoRoot, 'switching', 'XI_Xshape_analysis'); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

metricType = "P2P_percent"; %#ok<NASGU>

obsCsv = fullfile(alignDir, 'switching_alignment_observables_vs_T.csv');
samplesCsv = fullfile(alignDir, 'switching_alignment_samples.csv');
assert(isfile(obsCsv), 'Missing observables CSV: %s', obsCsv);
assert(isfile(samplesCsv), 'Missing samples CSV: %s', samplesCsv);

obsTbl = readtable(obsCsv);
sampTbl = readtable(samplesCsv);

if ismember('metricType', string(sampTbl.Properties.VariableNames))
    mType = string(sampTbl.metricType);
    bad = mType ~= "P2P_percent";
    if any(bad)
        error('switching_alignment_samples.csv includes non-P2P_percent rows; this analysis requires metricType=P2P_percent.');
    end
end

% STEP 1: required observables
tempsObs = toNumeric(obsTbl, 'T_K');
I_peak_obs = toNumeric(obsTbl, 'Ipeak');
c2_obs = toNumeric(obsTbl, 'coeff_mode2');
c3_obs = toNumeric(obsTbl, 'coeff_mode3');

assert(any(isfinite(I_peak_obs)), 'I_peak column missing or non-finite in observables CSV.');
assert(any(isfinite(c2_obs)), 'coeff_mode2 column missing or non-finite in observables CSV.');
assert(any(isfinite(c3_obs)), 'coeff_mode3 column missing or non-finite in observables CSV.');

% Build S(T,I) map from raw samples with rounded temperature bins.
[tempsMap, currents, Smap] = buildMapRounded(sampTbl);
[temps, iObs, iMap] = intersect(tempsObs, tempsMap, 'stable');
assert(~isempty(temps), 'No overlapping temperatures between observables and sample map.');

X_I = I_peak_obs(iObs);
c2 = c2_obs(iObs);
c3 = c3_obs(iObs);
Smap = Smap(iMap, :);

% STEP 2: construct X_shape from left/right areas around I_peak.
A_left = NaN(size(temps));
A_right = NaN(size(temps));
X_shape = NaN(size(temps));

for it = 1:numel(temps)
    row = Smap(it,:);
    currRow = currents(:)';
    valid = isfinite(row) & isfinite(currRow);
    if nnz(valid) < 3 || ~isfinite(X_I(it))
        continue;
    end
    cur = currRow(valid);
    s = row(valid);
    mL = cur < X_I(it);
    mR = cur > X_I(it);
    if ~any(mL) || ~any(mR)
        continue;
    end
    A_left(it) = sum(s(mL), 'omitnan');
    A_right(it) = sum(s(mR), 'omitnan');
    den = A_right(it) + A_left(it);
    if isfinite(den) && abs(den) > eps
        xs = (A_right(it) - A_left(it)) / den;
        % Keep bounded range for numerical robustness.
        X_shape(it) = max(min(xs, 1), -1);
    end
end

% STEP 3: independence test between X_I and X_shape.
vBase = isfinite(X_I) & isfinite(X_shape);
corr_XI_Xshape = safeCorr(X_I(vBase), X_shape(vBase));

linFit = fitPoly(X_I, X_shape, 1);
quadFit = fitPoly(X_I, X_shape, 2);

% Optional regime analysis.
regNames = ["global", "low_4_12K", "transition_14_20K", "high_22_30K"];
regRanges = [-inf inf; 4 12; 14 20; 22 30];

metRows = repmat(initMetricRow(), 0, 1);

% Global correlation row
r0 = initMetricRow();
r0.analysis = "XI_Xshape_correlation";
r0.regime = "global";
r0.model = "pearson";
r0.n_points = nnz(vBase);
r0.corr = corr_XI_Xshape;
r0.R2 = NaN;
r0.RMSE = NaN;
r0.beta0 = NaN;
r0.beta1 = NaN;
r0.beta2 = NaN;
metRows(end+1,1) = r0; %#ok<SAGROW>

% Global linear/quadratic rows
rLin = initMetricRow();
rLin.analysis = "XI_Xshape_function";
rLin.regime = "global";
rLin.model = "linear";
rLin.n_points = linFit.n;
rLin.corr = NaN;
rLin.R2 = linFit.R2;
rLin.RMSE = linFit.RMSE;
rLin.beta0 = linFit.beta0;
rLin.beta1 = linFit.beta1;
rLin.beta2 = NaN;
metRows(end+1,1) = rLin; %#ok<SAGROW>

rQuad = initMetricRow();
rQuad.analysis = "XI_Xshape_function";
rQuad.regime = "global";
rQuad.model = "quadratic";
rQuad.n_points = quadFit.n;
rQuad.corr = NaN;
rQuad.R2 = quadFit.R2;
rQuad.RMSE = quadFit.RMSE;
rQuad.beta0 = quadFit.beta0;
rQuad.beta1 = quadFit.beta1;
rQuad.beta2 = quadFit.beta2;
metRows(end+1,1) = rQuad; %#ok<SAGROW>

% Regime-specific correlation rows
for rr = 2:numel(regNames)
    mR = isfinite(temps) & temps >= regRanges(rr,1) & temps <= regRanges(rr,2) & isfinite(X_I) & isfinite(X_shape);
    row = initMetricRow();
    row.analysis = "XI_Xshape_correlation";
    row.regime = regNames(rr);
    row.model = "pearson";
    row.n_points = nnz(mR);
    row.corr = safeCorr(X_I(mR), X_shape(mR));
    row.R2 = NaN;
    row.RMSE = NaN;
    row.beta0 = NaN;
    row.beta1 = NaN;
    row.beta2 = NaN;
    metRows(end+1,1) = row; %#ok<SAGROW>
end

% STEP 4: mode-space interpretation models.
fitXI = fitLinearMode23(X_I, c2, c3);
fitXS = fitLinearMode23(X_shape, c2, c3);

v_I = [fitXI.a_c2, fitXI.b_c3];
v_S = [fitXS.a_c2, fitXS.b_c3];
ang = angleBetween(v_I, v_S);

% Add mode-model metrics to the main metrics CSV as well.
rowXI = initMetricRow();
rowXI.analysis = "mode23_regression";
rowXI.regime = "global";
rowXI.model = "X_I_from_c2c3";
rowXI.n_points = fitXI.n;
rowXI.corr = NaN;
rowXI.R2 = fitXI.R2;
rowXI.RMSE = fitXI.RMSE;
rowXI.beta0 = fitXI.intercept;
rowXI.beta1 = fitXI.a_c2;
rowXI.beta2 = fitXI.b_c3;
metRows(end+1,1) = rowXI; %#ok<SAGROW>

rowXS = initMetricRow();
rowXS.analysis = "mode23_regression";
rowXS.regime = "global";
rowXS.model = "X_shape_from_c2c3";
rowXS.n_points = fitXS.n;
rowXS.corr = NaN;
rowXS.R2 = fitXS.R2;
rowXS.RMSE = fitXS.RMSE;
rowXS.beta0 = fitXS.intercept;
rowXS.beta1 = fitXS.a_c2;
rowXS.beta2 = fitXS.b_c3;
metRows(end+1,1) = rowXS; %#ok<SAGROW>

rowAng = initMetricRow();
rowAng.analysis = "mode23_geometry";
rowAng.regime = "global";
rowAng.model = "angle_deg(vI,vS)";
rowAng.n_points = min(fitXI.n, fitXS.n);
rowAng.corr = NaN;
rowAng.R2 = NaN;
rowAng.RMSE = NaN;
rowAng.beta0 = ang;
rowAng.beta1 = NaN;
rowAng.beta2 = NaN;
metRows(end+1,1) = rowAng; %#ok<SAGROW>

metricsTbl = struct2table(metRows);
metricsOut = fullfile(outDir, 'XI_Xshape_regression_metrics.csv');
writetable(metricsTbl, metricsOut);

% Directions CSV
modeDirTbl = table( ...
    ["X_I"; "X_shape"], ...
    [fitXI.intercept; fitXS.intercept], ...
    [fitXI.a_c2; fitXS.a_c2], ...
    [fitXI.b_c3; fitXS.b_c3], ...
    [fitXI.R2; fitXS.R2], ...
    [fitXI.RMSE; fitXS.RMSE], ...
    [fitXI.n; fitXS.n], ...
    [norm(v_I); norm(v_S)], ...
    [ang; ang], ...
    'VariableNames', {'observable','intercept','a_c2','b_c3','R2','RMSE','n_points','vector_norm','angle_deg_between_directions'});
modeDirOut = fullfile(outDir, 'mode_space_directions.csv');
writetable(modeDirTbl, modeDirOut);

% STEP 4/5 figures
% 1) XI_Xshape_scatter.png
figSc = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 900 650]);
axSc = axes(figSc);
scatter(axSc, X_I(vBase), X_shape(vBase), 70, temps(vBase), 'filled');
hold(axSc, 'on');

if linFit.n >= 3
    xg = linspace(min(X_I(vBase)), max(X_I(vBase)), 200);
    ygLin = linFit.beta0 + linFit.beta1 * xg;
    plot(axSc, xg, ygLin, '-', 'LineWidth', 2, 'DisplayName', sprintf('linear R^2=%.3f', linFit.R2));
end
if quadFit.n >= 4
    xg = linspace(min(X_I(vBase)), max(X_I(vBase)), 200);
    ygQ = quadFit.beta0 + quadFit.beta1 * xg + quadFit.beta2 * xg.^2;
    plot(axSc, xg, ygQ, '--', 'LineWidth', 2, 'DisplayName', sprintf('quadratic R^2=%.3f', quadFit.R2));
end
xlabel(axSc, 'X_I = I_{peak} (mA)');
ylabel(axSc, 'X_{shape} = (A_R-A_L)/(A_R+A_L)');
title(axSc, sprintf('X_{shape} vs X_I | corr=%.3f', corr_XI_Xshape));
grid(axSc, 'on');
cb = colorbar(axSc); ylabel(cb, 'T (K)');
legend(axSc, 'Location', 'best');

scatterOut = fullfile(outDir, 'XI_Xshape_scatter.png');
saveas(figSc, scatterOut);
close(figSc);

% 2) mode_space_geometry.png
figGeo = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1000 700]);
axGeo = axes(figGeo);
vC = isfinite(c2) & isfinite(c3);
scatter(axGeo, c2(vC), c3(vC), 70, temps(vC), 'filled');
hold(axGeo, 'on');
plot(axGeo, c2(vC), c3(vC), '-', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.0, 'HandleVisibility', 'off');

if all(isfinite(v_I)) && norm(v_I) > eps
    uI = v_I / norm(v_I);
    quiver(axGeo, 0, 0, uI(1), uI(2), 0.8, 'LineWidth', 2.5, 'MaxHeadSize', 0.8, 'DisplayName', 'v_I direction');
end
if all(isfinite(v_S)) && norm(v_S) > eps
    uS = v_S / norm(v_S);
    quiver(axGeo, 0, 0, uS(1), uS(2), 0.8, 'LineWidth', 2.5, 'MaxHeadSize', 0.8, 'DisplayName', 'v_{shape} direction');
end
for it = 1:numel(temps)
    if isfinite(c2(it)) && isfinite(c3(it))
        text(axGeo, c2(it), c3(it), sprintf('  %gK', temps(it)), 'FontSize', 8);
    end
end
xlabel(axGeo, 'coeff\_mode2');
ylabel(axGeo, 'coeff\_mode3');
title(axGeo, sprintf('Mode-space geometry | angle(v_I,v_{shape})=%.1f deg', ang));
grid(axGeo, 'on'); axis(axGeo, 'equal');
cb = colorbar(axGeo); ylabel(cb, 'T (K)');
legend(axGeo, 'Location', 'best');

geoOut = fullfile(outDir, 'mode_space_geometry.png');
saveas(figGeo, geoOut);
close(figGeo);

% 3) XI_Xshape_temperature_trajectory.png
figTraj = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 520]);
tl = tiledlayout(figTraj, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axT1 = nexttile(tl, 1);
plot(axT1, c2(vC), c3(vC), '-o', 'LineWidth', 1.8);
hold(axT1, 'on');
for it = 1:numel(temps)
    if isfinite(c2(it)) && isfinite(c3(it))
        text(axT1, c2(it), c3(it), sprintf(' %g', temps(it)), 'FontSize', 8);
    end
end
xlabel(axT1, 'coeff\_mode2'); ylabel(axT1, 'coeff\_mode3');
title(axT1, 'Temperature trajectory in (mode2, mode3)');
grid(axT1, 'on');

axT2 = nexttile(tl, 2);
vX = isfinite(X_I) & isfinite(X_shape);
plot(axT2, X_I(vX), X_shape(vX), '-o', 'LineWidth', 1.8);
hold(axT2, 'on');
for it = 1:numel(temps)
    if isfinite(X_I(it)) && isfinite(X_shape(it))
        text(axT2, X_I(it), X_shape(it), sprintf(' %g', temps(it)), 'FontSize', 8);
    end
end
xlabel(axT2, 'X_I = I_{peak} (mA)'); ylabel(axT2, 'X_{shape}');
title(axT2, 'Temperature trajectory in (X_I, X_{shape})');
grid(axT2, 'on');

trajOut = fullfile(outDir, 'XI_Xshape_temperature_trajectory.png');
saveas(figTraj, trajOut);
close(figTraj);

% Report
reportOut = fullfile(outDir, 'XI_Xshape_analysis_report.md');
fid = fopen(reportOut, 'w');
assert(fid >= 0, 'Failed opening report: %s', reportOut);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# X_I vs X_shape Analysis Report\n\n');
fprintf(fid, '## 1. Correlation between X_I and X_shape\n\n');
fprintf(fid, '- corr(X_I, X_shape) = %.3f (n=%d finite points)\n', corr_XI_Xshape, nnz(vBase));
for rr = 2:numel(regNames)
    row = metricsTbl(metricsTbl.analysis == "XI_Xshape_correlation" & metricsTbl.regime == regNames(rr), :);
    if ~isempty(row)
        fprintf(fid, '- %s: corr = %.3f (n=%d)\n', regNames(rr), row.corr(1), row.n_points(1));
    end
end
fprintf(fid, '\n');

fprintf(fid, '## 2. Can X_shape be explained as a simple function of X_I?\n\n');
fprintf(fid, '- Linear fit X_shape(X_I): R^2 = %.3f, RMSE = %.3g\n', linFit.R2, linFit.RMSE);
fprintf(fid, '- Quadratic fit X_shape(X_I): R^2 = %.3f, RMSE = %.3g\n', quadFit.R2, quadFit.RMSE);
if isfinite(quadFit.R2) && isfinite(linFit.R2)
    fprintf(fid, '- DeltaR^2 (quadratic - linear) = %.3f\n', quadFit.R2 - linFit.R2);
end
fprintf(fid, '\n');

fprintf(fid, '## 3. Angle between regression directions in (mode2, mode3) plane\n\n');
fprintf(fid, '- X_I model: X_I = %.3g + %.3g*c2 + %.3g*c3 (R^2=%.3f)\n', fitXI.intercept, fitXI.a_c2, fitXI.b_c3, fitXI.R2);
fprintf(fid, '- X_shape model: X_shape = %.3g + %.3g*c2 + %.3g*c3 (R^2=%.3f)\n', fitXS.intercept, fitXS.a_c2, fitXS.b_c3, fitXS.R2);
fprintf(fid, '- angle(v_I, v_shape) = %.2f degrees\n\n', ang);

fprintf(fid, '## 4. Structural degree-of-freedom conclusion\n\n');
if isfinite(corr_XI_Xshape) && isfinite(linFit.R2) && isfinite(quadFit.R2) && isfinite(ang)
    if abs(corr_XI_Xshape) > 0.9 && quadFit.R2 > 0.8 && ang < 20
        concl = 'X_I and X_shape are largely compatible with a single structural coordinate.';
    elseif ang > 30 || quadFit.R2 < 0.7
        concl = 'X_I and X_shape are better described as two independent effective structural variables.';
    else
        concl = 'X_I and X_shape show partial dependence but are not reducible to a clearly single coordinate.';
    end
else
    concl = 'Insufficient finite metrics for a strict single-vs-two-variable decision.';
end
fprintf(fid, '%s\n\n', concl);

fprintf(fid, '## Output Files\n\n');
fprintf(fid, '- XI_Xshape_scatter.png\n');
fprintf(fid, '- XI_Xshape_regression_metrics.csv\n');
fprintf(fid, '- mode_space_directions.csv\n');
fprintf(fid, '- mode_space_geometry.png\n');
fprintf(fid, '- XI_Xshape_temperature_trajectory.png\n');
fprintf(fid, '- XI_Xshape_analysis_report.md\n\n');

fprintf(fid, 'Generated: %s\n', datestr(now, 31));

fprintf('XI/Xshape analysis complete.\n');
fprintf('Output directory: %s\n', outDir);
fprintf('Metrics CSV: %s\n', metricsOut);
fprintf('Directions CSV: %s\n', modeDirOut);
fprintf('Report: %s\n', reportOut);


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


function [temps, currents, Smap] = buildMapRounded(sampTbl)
Traw = toNumeric(sampTbl, 'T_K');
Iraw = toNumeric(sampTbl, 'current_mA');
Sraw = toNumeric(sampTbl, 'S_percent');

v = isfinite(Traw) & isfinite(Iraw) & isfinite(Sraw);
Traw = Traw(v);
Iraw = Iraw(v);
Sraw = Sraw(v);

Tclean = round(Traw);
temps = unique(Tclean);
currents = unique(Iraw);
temps = sort(temps(:));
currents = sort(currents(:));

Smap = NaN(numel(temps), numel(currents));
for it = 1:numel(temps)
    for ii = 1:numel(currents)
        m = Tclean == temps(it) & abs(Iraw - currents(ii)) < 1e-9;
        if any(m)
            Smap(it,ii) = mean(Sraw(m), 'omitnan');
        end
    end
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


function fit = fitPoly(x, y, deg)
fit = struct('n', 0, 'beta0', NaN, 'beta1', NaN, 'beta2', NaN, 'R2', NaN, 'RMSE', NaN);
v = isfinite(x) & isfinite(y);
if nnz(v) < max(3, deg+2)
    return;
end
xv = x(v); yv = y(v);
if deg == 1
    X = [ones(nnz(v),1), xv];
elseif deg == 2
    X = [ones(nnz(v),1), xv, xv.^2];
else
    return;
end
b = X \ yv;
yh = X * b;
fit.n = nnz(v);
fit.beta0 = b(1);
fit.beta1 = b(2);
if deg == 2
    fit.beta2 = b(3);
end
sse = sum((yv - yh).^2, 'omitnan');
sst = sum((yv - mean(yv, 'omitnan')).^2, 'omitnan');
if sst > 0
    fit.R2 = 1 - sse/sst;
end
fit.RMSE = sqrt(mean((yv - yh).^2, 'omitnan'));
end


function fit = fitLinearMode23(y, c2, c3)
fit = struct('n',0,'intercept',NaN,'a_c2',NaN,'b_c3',NaN,'R2',NaN,'RMSE',NaN,'yhat',NaN(size(y)));
v = isfinite(y) & isfinite(c2) & isfinite(c3);
if nnz(v) < 4
    return;
end
X = [ones(nnz(v),1), c2(v), c3(v)];
yv = y(v);
b = X \ yv;
yh = X * b;

yhat = NaN(size(y));
yhat(v) = yh;

fit.n = nnz(v);
fit.intercept = b(1);
fit.a_c2 = b(2);
fit.b_c3 = b(3);
fit.yhat = yhat;

sse = sum((yv - yh).^2, 'omitnan');
sst = sum((yv - mean(yv, 'omitnan')).^2, 'omitnan');
if sst > 0
    fit.R2 = 1 - sse/sst;
end
fit.RMSE = sqrt(mean((yv - yh).^2, 'omitnan'));
end


function a = angleBetween(v1, v2)
a = NaN;
if any(~isfinite(v1)) || any(~isfinite(v2))
    return;
end
n1 = norm(v1);
n2 = norm(v2);
if n1 <= eps || n2 <= eps
    return;
end
c = dot(v1, v2) / (n1*n2);
c = max(min(c,1),-1);
a = acosd(c);
end


function row = initMetricRow()
row = struct();
row.analysis = "";
row.regime = "";
row.model = "";
row.n_points = NaN;
row.corr = NaN;
row.R2 = NaN;
row.RMSE = NaN;
row.beta0 = NaN;
row.beta1 = NaN;
row.beta2 = NaN;
end


