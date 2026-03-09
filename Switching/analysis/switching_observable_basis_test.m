% switching_observable_basis_test
% Tests whether (I_peak, X_shape) forms a good interpretable basis for the
% dominant 2D structural shape sector of the switching map.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

alignDir = resolve_results_input_dir(repoRoot, 'switching', 'alignment_audit');
[outDir, run] = init_run_output_dir(repoRoot, 'switching', 'observable_basis_test'); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

obsCsv = fullfile(alignDir, 'switching_alignment_observables_vs_T.csv');
sampCsv = fullfile(alignDir, 'switching_alignment_samples.csv');
assert(isfile(obsCsv), 'Missing observables CSV: %s', obsCsv);
assert(isfile(sampCsv), 'Missing samples CSV: %s', sampCsv);

obsTbl = readtable(obsCsv);
sampTbl = readtable(sampCsv);

if ismember('metricType', string(sampTbl.Properties.VariableNames))
    mType = string(sampTbl.metricType);
    if any(mType ~= "P2P_percent")
        error('Found non-P2P_percent samples; basis test requires fixed metricType=P2P_percent.');
    end
end

% Inspect/reuse available observables.
Tobs = toNum(obsTbl, 'T_K');
I_peak_obs = toNum(obsTbl, 'Ipeak');
width_obs = toNum(obsTbl, 'width_I');

% Build map with same rounded-temperature convention used in shape_rank analysis.
[tempsMap, currents, Smap] = buildMapRounded(sampTbl);
[temps, iObs, iMap] = intersect(Tobs, tempsMap, 'stable');
assert(~isempty(temps), 'No overlap between observables and map temperatures.');

I_peak = I_peak_obs(iObs);
width_I = width_obs(iObs);
Smap = Smap(iMap, :);

% Reconstruct X_shape using existing XI_Xshape convention.
[X_shape, A_left, A_right] = computeXshapeFromMap(Smap, currents, I_peak);

% Shape-rank conventions from switching_shape_rank_analysis.
[S_norm, S_shape, S_peak, rowMean, validRows, robustRows, peakAbsFloor, globalPeak] = ...
    buildShapeMaps(Smap, temps);

% Prepare full-subset and robust-subset shape spaces.
idxFull = find(validRows);
idxRob = find(robustRows);

shapeFull = analyzeShapeSubspace(S_shape(idxFull,:), 2);
shapeRob = analyzeShapeSubspace(S_shape(idxRob,:), 2);

Cfull = shapeFull.C;      % (nFull x 2) temperature coefficients
Vfull = shapeFull.V2;     % (nI x 2) current modes
Mfull = shapeFull.M;
Crob = shapeRob.C;
Vrob = shapeRob.V2;
Mrob = shapeRob.M;

I_full = I_peak(idxFull);
W_full = width_I(idxFull);
X_full = X_shape(idxFull);
T_full = temps(idxFull);

I_rob = I_peak(idxRob);
W_rob = width_I(idxRob);
X_rob = X_shape(idxRob);
T_rob = temps(idxRob);

% -------------------------------------------------------------------------
% 1) Single-observable relations to c1/c2
% -------------------------------------------------------------------------
corrRows = repmat(initCorrRow(), 0, 1);

corrRows = [corrRows; oneObsRows("full", "I_peak", I_full, Cfull)]; %#ok<AGROW>
corrRows = [corrRows; oneObsRows("full", "X_shape", X_full, Cfull)]; %#ok<AGROW>
corrRows = [corrRows; oneObsRows("robust", "I_peak", I_rob, Crob)]; %#ok<AGROW>
corrRows = [corrRows; oneObsRows("robust", "X_shape", X_rob, Crob)]; %#ok<AGROW>

corrTbl = struct2table(corrRows);
corrOut = fullfile(outDir, 'observable_basis_correlations.csv');
writetable(corrTbl, corrOut);

% -------------------------------------------------------------------------
% 2) Pair basis hypothesis tests + map reconstruction tests
% -------------------------------------------------------------------------
pairRows = repmat(initPairRow(), 0, 1);
geoRows = repmat(initGeoRow(), 0, 1);

pairList = { ...
    struct('name', "Ipeak_Xshape", 'Pfull', [I_full, X_full], 'Prob', [I_rob, X_rob]), ...
    struct('name', "Ipeak_width", 'Pfull', [I_full, W_full], 'Prob', [I_rob, W_rob]), ...
    struct('name', "Xshape_width", 'Pfull', [X_full, W_full], 'Prob', [X_rob, W_rob]) ...
    };

for i = 1:numel(pairList)
    % full subset
    evF = evaluatePair(pairList{i}.Pfull, Cfull, Vfull, Mfull);
    pairRows(end+1,1) = mkPairRow("full", pairList{i}.name, evF); %#ok<SAGROW>
    geoRows(end+1,1) = mkGeoRow("full", pairList{i}.name, evF); %#ok<SAGROW>

    % robust subset
    evR = evaluatePair(pairList{i}.Prob, Crob, Vrob, Mrob);
    pairRows(end+1,1) = mkPairRow("robust", pairList{i}.name, evR); %#ok<SAGROW>
    geoRows(end+1,1) = mkGeoRow("robust", pairList{i}.name, evR); %#ok<SAGROW>
end

pairTbl = struct2table(pairRows);
pairOut = fullfile(outDir, 'observable_basis_pair_comparison.csv');
writetable(pairTbl, pairOut);

geoTbl = struct2table(geoRows);
geoOut = fullfile(outDir, 'observable_basis_geometry.csv');
writetable(geoTbl, geoOut);

% -------------------------------------------------------------------------
% 3) Figures
% -------------------------------------------------------------------------
% shape_coefficients_vs_observables.png
figSO = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 900]);
tlSO = tiledlayout(figSO, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
plotScatterWithFit(nexttile(tlSO,1), I_full, Cfull(:,1), T_full, 'I_{peak}', 'c_1', 'c_1 vs I_{peak}');
plotScatterWithFit(nexttile(tlSO,2), I_full, Cfull(:,2), T_full, 'I_{peak}', 'c_2', 'c_2 vs I_{peak}');
plotScatterWithFit(nexttile(tlSO,3), X_full, Cfull(:,1), T_full, 'X_{shape}', 'c_1', 'c_1 vs X_{shape}');
plotScatterWithFit(nexttile(tlSO,4), X_full, Cfull(:,2), T_full, 'X_{shape}', 'c_2', 'c_2 vs X_{shape}');

figSOOut = fullfile(outDir, 'shape_coefficients_vs_observables.png');
saveas(figSO, figSOOut);
close(figSO);

% observable_basis_pair_comparison.png
figPC = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1200 500]);
tlPC = tiledlayout(figPC, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

axP1 = nexttile(tlPC,1); hold(axP1,'on');
fullRows = pairTbl(pairTbl.subset == "full", :);
labels = fullRows.pair_name;
bar(axP1, categorical(labels), [fullRows.joint_coeff_explained_var, fullRows.c1_explained_var, fullRows.c2_explained_var], 'grouped');
ylabel(axP1, 'explained variance');
title(axP1, 'Full subset: coefficient-space fit quality');
grid(axP1,'on'); legend(axP1, {'joint','c1','c2'}, 'Location', 'best');

axP2 = nexttile(tlPC,2); hold(axP2,'on');
bar(axP2, categorical(labels), [fullRows.map_fro_error, fullRows.native_rank2_fro_error, fullRows.excess_error_ratio], 'grouped');
ylabel(axP2, 'error metric');
title(axP2, 'Full subset: map-space reconstruction comparison');
grid(axP2,'on'); legend(axP2, {'pair map fro','native rank2 fro','excess ratio'}, 'Location', 'best');

figPCOut = fullfile(outDir, 'observable_basis_pair_comparison.png');
saveas(figPC, figPCOut);
close(figPC);

% observable_basis_reconstruction_comparison.png for (I_peak, X_shape), full subset.
basisRow = pairTbl(pairTbl.subset=="full" & pairTbl.pair_name=="Ipeak_Xshape", :);
assert(~isempty(basisRow), 'Expected Ipeak_Xshape full row missing from pair table.');

% Recompute this pair eval to retrieve maps.
evBasis = evaluatePair([I_full, X_full], Cfull, Vfull, Mfull);

figRC = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 1400 850]);
tlRC = tiledlayout(figRC, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
plotHeat(nexttile(tlRC,1), currents, T_full, evBasis.M_target, 'S_{shape} (full subset)');
plotHeat(nexttile(tlRC,2), currents, T_full, evBasis.M_native_rank2, 'Native rank-2 SVD recon');
plotHeat(nexttile(tlRC,3), currents, T_full, evBasis.M_pair_recon, '(I_{peak}, X_{shape}) recon');
plotResidual(nexttile(tlRC,4), currents, T_full, evBasis.M_target - evBasis.M_native_rank2, 'Residual: target - native rank2');
plotResidual(nexttile(tlRC,5), currents, T_full, evBasis.M_target - evBasis.M_pair_recon, 'Residual: target - observable pair');
plotResidual(nexttile(tlRC,6), currents, T_full, evBasis.M_pair_recon - evBasis.M_native_rank2, 'Difference: pair recon - native rank2');

figRCOut = fullfile(outDir, 'observable_basis_reconstruction_comparison.png');
saveas(figRC, figRCOut);
close(figRC);

% -------------------------------------------------------------------------
% 4) Report
% -------------------------------------------------------------------------
repOut = fullfile(outDir, 'observable_basis_report.md');
fid = fopen(repOut, 'w');
assert(fid >= 0, 'Failed to open report: %s', repOut);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Observable Basis Test Report\n\n');
fprintf(fid, '## Inputs and Reuse\n\n');
fprintf(fid, '- Reused `switching_alignment_observables_vs_T.csv` for I_peak and width_I\n');
fprintf(fid, '- Reused `switching_alignment_samples.csv` for map reconstruction\n');
fprintf(fid, '- X_shape is not persisted as a standalone CSV column; reconstructed with the same definition used in `switching_XI_Xshape_analysis.m`\n');
fprintf(fid, '- Shape-space conventions matched to `switching_shape_rank_analysis.m` (rounded T bins, S_norm, row-centered S_shape, robust subset rule)\n');
fprintf(fid, '- peak floor: %.3g ; global peak: %.4g\n\n', peakAbsFloor, globalPeak);

% Pull key rows
fullIpeakX = pairTbl(pairTbl.subset=="full" & pairTbl.pair_name=="Ipeak_Xshape", :);
fullIpeakW = pairTbl(pairTbl.subset=="full" & pairTbl.pair_name=="Ipeak_width", :);
robIpeakX = pairTbl(pairTbl.subset=="robust" & pairTbl.pair_name=="Ipeak_Xshape", :);
robIpeakW = pairTbl(pairTbl.subset=="robust" & pairTbl.pair_name=="Ipeak_width", :);

fprintf(fid, '## Basis Test: (I_peak, X_shape)\n\n');
if ~isempty(fullIpeakX)
    fprintf(fid, '- Full subset: c1 EV=%.3f, c2 EV=%.3f, joint EV=%.3f\n', fullIpeakX.c1_explained_var(1), fullIpeakX.c2_explained_var(1), fullIpeakX.joint_coeff_explained_var(1));
    fprintf(fid, '- Full subset: pair map fro error=%.3f, native rank2 fro=%.3f, excess ratio=%.3f\n', fullIpeakX.map_fro_error(1), fullIpeakX.native_rank2_fro_error(1), fullIpeakX.excess_error_ratio(1));
end
if ~isempty(robIpeakX)
    fprintf(fid, '- Robust subset: c1 EV=%.3f, c2 EV=%.3f, joint EV=%.3f\n', robIpeakX.c1_explained_var(1), robIpeakX.c2_explained_var(1), robIpeakX.joint_coeff_explained_var(1));
    fprintf(fid, '- Robust subset: pair map fro error=%.3f, native rank2 fro=%.3f, excess ratio=%.3f\n', robIpeakX.map_fro_error(1), robIpeakX.native_rank2_fro_error(1), robIpeakX.excess_error_ratio(1));
end
fprintf(fid, '\n');

fprintf(fid, '## Comparison vs (I_peak, width)\n\n');
if ~isempty(fullIpeakW)
    fprintf(fid, '- Full subset (I_peak,width): joint EV=%.3f, excess ratio=%.3f\n', fullIpeakW.joint_coeff_explained_var(1), fullIpeakW.excess_error_ratio(1));
end
if ~isempty(robIpeakW)
    fprintf(fid, '- Robust subset (I_peak,width): joint EV=%.3f, excess ratio=%.3f\n', robIpeakW.joint_coeff_explained_var(1), robIpeakW.excess_error_ratio(1));
end
fprintf(fid, '\n');

fprintf(fid, '## Geometric Span Metrics\n\n');
geoMain = geoTbl(geoTbl.subset=="full" & geoTbl.pair_name=="Ipeak_Xshape", :);
if ~isempty(geoMain)
    fprintf(fid, '- Principal angles (deg): [%.2f, %.2f]\n', geoMain.principal_angle1_deg(1), geoMain.principal_angle2_deg(1));
    fprintf(fid, '- Span overlap metric (mean cos angle): %.3f\n', geoMain.span_overlap_mean_cos(1));
end
fprintf(fid, '\n');

fprintf(fid, '## Conclusion\n\n');
conclusion = "Inconclusive.";
if ~isempty(fullIpeakX) && ~isempty(fullIpeakW)
    betterEV = fullIpeakX.joint_coeff_explained_var(1) > fullIpeakW.joint_coeff_explained_var(1);
    betterErr = fullIpeakX.excess_error_ratio(1) < fullIpeakW.excess_error_ratio(1);
    goodBasis = fullIpeakX.joint_coeff_explained_var(1) >= 0.70 && fullIpeakX.excess_error_ratio(1) <= 0.30;

    if goodBasis && betterEV && betterErr
        conclusion = "(I_peak, X_shape) provides a good and interpretable basis for the rank-2 shape sector, and performs better than (I_peak, width).";
    elseif betterEV || betterErr
        conclusion = "(I_peak, X_shape) captures substantial shape information, but basis quality is moderate and only partially superior to (I_peak, width).";
    else
        conclusion = "(I_peak, X_shape) does not clearly outperform (I_peak, width) as a basis for the rank-2 shape sector in this dataset.";
    end
end
fprintf(fid, '%s\n\n', conclusion);

fprintf(fid, '## Files\n\n');
fprintf(fid, '- observable_basis_correlations.csv\n');
fprintf(fid, '- observable_basis_pair_comparison.csv\n');
fprintf(fid, '- observable_basis_geometry.csv\n');
fprintf(fid, '- shape_coefficients_vs_observables.png\n');
fprintf(fid, '- observable_basis_pair_comparison.png\n');
fprintf(fid, '- observable_basis_reconstruction_comparison.png\n');
fprintf(fid, '- observable_basis_report.md\n\n');

fprintf(fid, 'Generated: %s\n', datestr(now,31));

% ZIP key review files (exact set)
zipOut = fullfile(outDir, 'observable_basis_review.zip');
if isfile(zipOut)
    delete(zipOut);
end
zipFiles = { ...
    'observable_basis_correlations.csv', ...
    'observable_basis_pair_comparison.csv', ...
    'observable_basis_geometry.csv', ...
    'shape_coefficients_vs_observables.png', ...
    'observable_basis_pair_comparison.png', ...
    'observable_basis_reconstruction_comparison.png', ...
    'observable_basis_report.md' ...
    };
paths = strings(0,1);
for i = 1:numel(zipFiles)
    p = fullfile(outDir, zipFiles{i});
    if isfile(p)
        paths(end+1,1) = string(p); %#ok<SAGROW>
    else
        error('Missing file for review ZIP: %s', p);
    end
end
zip(char(zipOut), cellstr(paths));

fprintf('Observable basis test complete.\n');
fprintf('Output directory: %s\n', outDir);
fprintf('Correlations CSV: %s\n', corrOut);
fprintf('Pair comparison CSV: %s\n', pairOut);
fprintf('Geometry CSV: %s\n', geoOut);
fprintf('Report: %s\n', repOut);
fprintf('Review ZIP: %s\n', zipOut);


function x = toNum(tbl, name)
if ~ismember(name, string(tbl.Properties.VariableNames))
    x = NaN(height(tbl),1);
    return;
end
col = tbl.(name);
if isnumeric(col)
    x = double(col(:));
else
    x = str2double(string(col(:)));
end
end


function [temps, currents, Smap] = buildMapRounded(tbl)
Traw = toNum(tbl, 'T_K');
Iraw = toNum(tbl, 'current_mA');
Sraw = toNum(tbl, 'S_percent');
v = isfinite(Traw) & isfinite(Iraw) & isfinite(Sraw);
Traw = Traw(v); Iraw = Iraw(v); Sraw = Sraw(v);
Tbin = round(Traw);
temps = sort(unique(Tbin));
currents = sort(unique(Iraw));
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


function [Xshape, Aleft, Aright] = computeXshapeFromMap(Smap, currents, Ipeak)
Xshape = NaN(size(Ipeak));
Aleft = NaN(size(Ipeak));
Aright = NaN(size(Ipeak));
for it = 1:numel(Ipeak)
    row = Smap(it,:);
    cur = currents(:)';
    v = isfinite(row) & isfinite(cur) & isfinite(Ipeak(it));
    if nnz(v) < 3
        continue;
    end
    rv = row(v);
    cv = cur(v);
    mL = cv < Ipeak(it);
    mR = cv > Ipeak(it);
    if ~any(mL) || ~any(mR)
        continue;
    end
    Aleft(it) = sum(rv(mL), 'omitnan');
    Aright(it) = sum(rv(mR), 'omitnan');
    den = Aleft(it) + Aright(it);
    if isfinite(den) && abs(den) > eps
        Xshape(it) = max(min((Aright(it)-Aleft(it))/den, 1), -1);
    end
end
end


function [S_norm, S_shape, Speak, rowMean, validRows, robustRows, peakFloor, gPeak] = buildShapeMaps(Smap, temps)
Speak = NaN(size(temps));
S_norm = NaN(size(Smap));
S_shape = NaN(size(Smap));
rowMean = NaN(size(temps));
for it = 1:numel(temps)
    row = Smap(it,:);
    v = isfinite(row);
    if ~any(v)
        continue;
    end
    Speak(it) = max(row(v), [], 'omitnan');
end

gPeak = max(Speak(isfinite(Speak)), [], 'omitnan');
peakFloor = max(1e-6, 1e-4*gPeak);
validRows = isfinite(Speak) & Speak > peakFloor;

for it = 1:numel(temps)
    if ~validRows(it)
        continue;
    end
    row = Smap(it,:);
    v = isfinite(row);
    rn = NaN(size(row));
    rn(v) = row(v) / Speak(it);
    S_norm(it,:) = rn;
    mu = mean(rn(v), 'omitnan');
    rowMean(it) = mu;
    rc = rn;
    rc(v) = rn(v) - mu;
    S_shape(it,:) = rc;
end

robustRows = validRows & isfinite(temps) & temps <= 30 & Speak >= 0.05*gPeak;
end


function sh = analyzeShapeSubspace(M, rankK)
mask = isfinite(M);
M0 = M;
M0(~mask) = 0;
[U,S,V] = svd(M0, 'econ');
sv = diag(S);
k = min([rankK, numel(sv), size(U,2), size(V,2)]);
C = U(:,1:k) * S(1:k,1:k);
V2 = V(:,1:k);
M_native = C * V2';
sh = struct('M', M, 'U', U, 'S', S, 'V', V, 'C', C, 'V2', V2, 'M_native', M_native, 'rank', k);
end


function rows = oneObsRows(subsetName, obsName, x, C)
rows = repmat(initCorrRow(), 2, 1);
for j = 1:2
    y = C(:,j);
    v = isfinite(x) & isfinite(y);
    corrVal = safeCorr(x(v), y(v));
    fitL = fitPoly1(x(v), y(v));
    fitQ = fitPoly2(x(v), y(v));

    r = initCorrRow();
    r.subset = string(subsetName);
    r.observable = string(obsName);
    r.coefficient = sprintf('c%d', j);
    r.n_points = nnz(v);
    r.pearson_corr = corrVal;
    r.linear_R2 = fitL.R2;
    r.quadratic_R2 = fitQ.R2;
    r.delta_R2_quad_minus_lin = fitQ.R2 - fitL.R2;
    rows(j,1) = r;
end
end


function ev = evaluatePair(P, C, V2, M)
ev = struct('n_points',NaN,'c1R2',NaN,'c2R2',NaN,'jointEV',NaN, ...
    'invR2_p1',NaN,'invR2_p2',NaN,'nativeFro',NaN,'pairFro',NaN,'excessRatio',NaN, ...
    'angle1',NaN,'angle2',NaN,'spanOverlap',NaN,'M_target',M,'M_native_rank2',NaN(size(M)),'M_pair_recon',NaN(size(M)));

if size(C,2) < 2 || size(P,2) < 2
    return;
end

v = all(isfinite(P),2) & all(isfinite(C),2);
if nnz(v) < 5
    return;
end
P0 = P(v,:);
C0 = C(v,:);
M0 = M(v,:);

% Predict coefficients from observables
X = [ones(size(P0,1),1), P0];
B = X \ C0;
C_hat = X * B;

% Per-target EV
ev.c1R2 = calcR2(C0(:,1), C_hat(:,1));
ev.c2R2 = calcR2(C0(:,2), C_hat(:,2));
ev.jointEV = calcJointEV(C0, C_hat);

% Inverse map (optional): predict observables from coefficients
Xi = [ones(size(C0,1),1), C0] \ P0;
P_hat = [ones(size(C0,1),1), C0] * Xi;
ev.invR2_p1 = calcR2(P0(:,1), P_hat(:,1));
ev.invR2_p2 = calcR2(P0(:,2), P_hat(:,2));

% Map-space reconstructions
M_native = C0 * V2';
M_pair = C_hat * V2';

nF = froErr(M0, M_native);
pF = froErr(M0, M_pair);
ev.nativeFro = nF;
ev.pairFro = pF;
if isfinite(nF) && nF > 0
    ev.excessRatio = (pF - nF) / nF;
end

% Geometric subspace comparison (principal angles)
Pc = P0 - mean(P0,1,'omitnan');
Cc = C0 - mean(C0,1,'omitnan');
Qp = orth(Pc);
Qc = orth(Cc);
if ~isempty(Qp) && ~isempty(Qc)
    s = svd(Qp' * Qc);
    s = max(min(s,1),-1);
    ang = acosd(s);
    if numel(ang) >= 1
        ev.angle1 = ang(1);
    end
    if numel(ang) >= 2
        ev.angle2 = ang(2);
    end
    ev.spanOverlap = mean(s, 'omitnan');
end

% Full matrices for plotting (NaN outside valid rows)
MnatFull = NaN(size(M));
MpairFull = NaN(size(M));
MnatFull(v,:) = M_native;
MpairFull(v,:) = M_pair;
ev.M_native_rank2 = MnatFull;
ev.M_pair_recon = MpairFull;
ev.n_points = nnz(v);
end


function r = froErr(A, B)
v = isfinite(A) & isfinite(B);
if nnz(v) < 3
    r = NaN;
    return;
end
a = A(v); b = B(v);
d = a - b;
denom = norm(a, 'fro');
if denom <= 0
    r = NaN;
    return;
end
r = norm(d, 'fro') / denom;
end


function r2 = calcR2(y, yhat)
v = isfinite(y) & isfinite(yhat);
if nnz(v) < 3
    r2 = NaN;
    return;
end
yv = y(v); yh = yhat(v);
sse = sum((yv - yh).^2, 'omitnan');
sst = sum((yv - mean(yv,'omitnan')).^2, 'omitnan');
if sst <= 0
    r2 = NaN;
else
    r2 = 1 - sse/sst;
end
end


function ev = calcJointEV(Y, Yhat)
v = all(isfinite(Y),2) & all(isfinite(Yhat),2);
if nnz(v) < 3
    ev = NaN;
    return;
end
Y0 = Y(v,:);
Yh = Yhat(v,:);
Ym = Y0 - mean(Y0,1,'omitnan');
res = Y0 - Yh;
den = norm(Ym, 'fro');
if den <= 0
    ev = NaN;
else
    ev = 1 - (norm(res, 'fro')^2)/(den^2);
end
end


function fit = fitPoly1(x, y)
fit = struct('R2', NaN);
if numel(x) < 3
    return;
end
X = [ones(numel(x),1), x(:)];
b = X \ y(:);
yh = X*b;
fit.R2 = calcR2(y(:), yh(:));
end


function fit = fitPoly2(x, y)
fit = struct('R2', NaN);
if numel(x) < 4
    return;
end
X = [ones(numel(x),1), x(:), x(:).^2];
b = X \ y(:);
yh = X*b;
fit.R2 = calcR2(y(:), yh(:));
end


function c = safeCorr(a,b)
if isempty(a) || isempty(b)
    c = NaN;
    return;
end
v = isfinite(a) & isfinite(b);
if nnz(v) < 3
    c = NaN;
    return;
end
c = corr(a(v), b(v), 'rows', 'complete');
end


function row = initCorrRow()
row = struct();
row.subset = "";
row.observable = "";
row.coefficient = "";
row.n_points = NaN;
row.pearson_corr = NaN;
row.linear_R2 = NaN;
row.quadratic_R2 = NaN;
row.delta_R2_quad_minus_lin = NaN;
end


function row = initPairRow()
row = struct();
row.subset = "";
row.pair_name = "";
row.n_points = NaN;
row.c1_explained_var = NaN;
row.c2_explained_var = NaN;
row.joint_coeff_explained_var = NaN;
row.inverse_R2_obs1 = NaN;
row.inverse_R2_obs2 = NaN;
row.native_rank2_fro_error = NaN;
row.map_fro_error = NaN;
row.excess_error_ratio = NaN;
end


function row = mkPairRow(subsetName, pairName, ev)
row = initPairRow();
row.subset = string(subsetName);
row.pair_name = string(pairName);
row.n_points = ev.n_points;
row.c1_explained_var = ev.c1R2;
row.c2_explained_var = ev.c2R2;
row.joint_coeff_explained_var = ev.jointEV;
row.inverse_R2_obs1 = ev.invR2_p1;
row.inverse_R2_obs2 = ev.invR2_p2;
row.native_rank2_fro_error = ev.nativeFro;
row.map_fro_error = ev.pairFro;
row.excess_error_ratio = ev.excessRatio;
end


function row = initGeoRow()
row = struct();
row.subset = "";
row.pair_name = "";
row.n_points = NaN;
row.principal_angle1_deg = NaN;
row.principal_angle2_deg = NaN;
row.span_overlap_mean_cos = NaN;
end


function row = mkGeoRow(subsetName, pairName, ev)
row = initGeoRow();
row.subset = string(subsetName);
row.pair_name = string(pairName);
row.n_points = ev.n_points;
row.principal_angle1_deg = ev.angle1;
row.principal_angle2_deg = ev.angle2;
row.span_overlap_mean_cos = ev.spanOverlap;
end


function plotScatterWithFit(ax, x, y, T, xlbl, ylbl, ttl)
v = isfinite(x) & isfinite(y) & isfinite(T);
scatter(ax, x(v), y(v), 55, T(v), 'filled');
hold(ax, 'on');
fit1 = fitPoly1(x(v), y(v));
if nnz(v) >= 3
    xg = linspace(min(x(v)), max(x(v)), 200)';
    Xg = [ones(numel(xg),1), xg];
    b = Xg \ (Xg * [0;0]); %#ok<NASGU>
    X = [ones(nnz(v),1), x(v)];
    beta = X \ y(v);
    yg = Xg * beta;
    plot(ax, xg, yg, '-', 'LineWidth', 2, 'DisplayName', sprintf('linear R^2=%.3f', fit1.R2));
end
xlabel(ax, xlbl); ylabel(ax, ylbl); title(ax, ttl); grid(ax,'on');
cb = colorbar(ax); ylabel(cb, 'T (K)');
if nnz(v) >= 3
    legend(ax, 'Location', 'best');
end
end


function plotHeat(ax, currents, temps, M, ttl)
imagesc(ax, currents, temps, M);
set(ax, 'YDir', 'normal');
if exist('turbo','file') == 2
    colormap(ax, turbo);
else
    colormap(ax, parula);
end
xlabel(ax, 'I_0 (mA)'); ylabel(ax, 'T (K)'); title(ax, ttl);
cb = colorbar(ax); ylabel(cb, 'value');
end


function plotResidual(ax, currents, temps, R, ttl)
imagesc(ax, currents, temps, R);
set(ax, 'YDir', 'normal');
applyDiverging(ax);
vals = R(isfinite(R));
if ~isempty(vals)
    lim = max(abs(vals));
    if lim > 0 && isfinite(lim)
        caxis(ax, [-lim lim]);
    end
end
xlabel(ax, 'I_0 (mA)'); ylabel(ax, 'T (K)'); title(ax, ttl);
cb = colorbar(ax); ylabel(cb, 'residual');
end


function applyDiverging(ax)
n = 256;
r = [(0:(n/2-1))/(n/2), ones(1,n/2)];
g = [(0:(n/2-1))/(n/2), ((n/2-1):-1:0)/(n/2)];
b = [ones(1,n/2), ((n/2-1):-1:0)/(n/2)];
colormap(ax, [r(:), g(:), b(:)]);
end

