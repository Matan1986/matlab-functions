% switching_second_coordinate_duel
% Focused head-to-head comparison between width_I and halfwidth_diff_norm
% as the second structural coordinate paired with I_peak.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');

alignDir = resolve_results_input_dir(repoRoot, 'switching', 'alignment_audit');
followDir = resolve_results_input_dir(repoRoot, 'switching', 'mechanism_followup');
[outDir, run] = init_run_output_dir(repoRoot, 'switching', 'second_coordinate_duel'); %#ok<ASGLU>
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

obsCsv = fullfile(alignDir, 'switching_alignment_observables_vs_T.csv');
sampCsv = fullfile(alignDir, 'switching_alignment_samples.csv');
shapeCsv = fullfile(followDir, 'mechanism_ridge_shape_metrics.csv');

assert(isfile(obsCsv), 'Missing observables CSV: %s', obsCsv);
assert(isfile(sampCsv), 'Missing samples CSV: %s', sampCsv);

obsTbl = readtable(obsCsv);
sampTbl = readtable(sampCsv);
if ismember('metricType', string(sampTbl.Properties.VariableNames))
    mType = string(sampTbl.metricType);
    if any(mType ~= "P2P_percent")
        error('Samples include non-P2P_percent rows; duel requires fixed metricType=P2P_percent.');
    end
end

% Reuse key observables.
Tobs = toNum(obsTbl, 'T_K');
IpeakObs = toNum(obsTbl, 'Ipeak');
widthObs = toNum(obsTbl, 'width_I');

% Map reconstruction with rounded-T convention.
[tempsMap, currents, Smap] = buildMapRounded(sampTbl);
[temps, iObs, iMap] = intersect(Tobs, tempsMap, 'stable');
assert(~isempty(temps), 'No overlap between observables and map temperatures.');

I_peak = IpeakObs(iObs);
width_I = widthObs(iObs);
Smap = Smap(iMap,:);

% Reuse halfwidth_diff_norm from follow-up output if available.
halfwidth_diff = NaN(size(temps));
halfwidthSource = "mechanism_followup";
if isfile(shapeCsv)
    shpTbl = readtable(shapeCsv);
    if ismember('T_K', string(shpTbl.Properties.VariableNames)) && ismember('halfwidth_diff_norm', string(shpTbl.Properties.VariableNames))
        Tf = toNum(shpTbl, 'T_K');
        hf = toNum(shpTbl, 'halfwidth_diff_norm');
        [~, iT, iF] = intersect(temps, Tf, 'stable');
        halfwidth_diff(iT) = hf(iF);
    end
end

% Minimal fallback only if missing.
if nnz(isfinite(halfwidth_diff)) < 3
    [half_fb, ~] = computeHalfwidthAndCurvFallback(Smap, currents, I_peak, width_I);
    halfwidth_diff = half_fb;
    halfwidthSource = "fallback_from_map";
end

% Shape map conventions from shape_rank_analysis.
[S_norm, S_shape, S_peak, rowMean, validRows, robustRows, peakFloor, globalPeak] = buildShapeMaps(Smap, temps); %#ok<NASGU>

idxFull = find(validRows);
idxRob = find(robustRows);

shapeFull = analyzeShapeSubspace(S_shape(idxFull,:), 3);
shapeRob = analyzeShapeSubspace(S_shape(idxRob,:), 3);

% Build per-subset data.
fullDat = makeSubsetData(idxFull, temps, I_peak, width_I, halfwidth_diff, shapeFull);
robDat = makeSubsetData(idxRob, temps, I_peak, width_I, halfwidth_diff, shapeRob);

% Evaluate both candidates in each subset.
candList = { ...
    struct('name',"width_I",'category',"width-like",'x',[]), ...
    struct('name',"halfwidth_diff_norm",'category',"deformation/asymmetry-like",'x',[]) ...
    };

metricRows = repmat(initMetricRow(), 0, 1);
geoRows = repmat(initGeoRow(), 0, 1);

% Store eval objects for plots and residual tables.
evStore = struct();

subsetNames = ["full","robust"];
subsetData = {fullDat, robDat};

for ss = 1:numel(subsetNames)
    dat = subsetData{ss};
    for cc = 1:numel(candList)
        if candList{cc}.name == "width_I"
            x2 = dat.width;
        else
            x2 = dat.half;
        end
        ev = evaluateCandidatePair(dat.Ipeak, x2, dat.C2, dat.V2, dat.Mtarget, dat.c3);

        row = initMetricRow();
        row.subset = subsetNames(ss);
        row.candidate = candList{cc}.name;
        row.category = candList{cc}.category;
        row.n_points = ev.n;
        row.corr_c1 = ev.corr_c1;
        row.corr_c2 = ev.corr_c2;
        row.R2_c1 = ev.R2_c1;
        row.R2_c2 = ev.R2_c2;
        row.pair_joint_EV = ev.jointEV;
        row.native_rank2_fro_error = ev.nativeFro;
        row.map_fro_error = ev.pairFro;
        row.excess_error_ratio = ev.excessRatio;
        row.corr_with_Ipeak = ev.corr_with_Ipeak;
        row.partial_corr_c1_given_Ipeak = ev.partial_c1_given_I;
        row.partial_corr_c2_given_Ipeak = ev.partial_c2_given_I;
        row.inverse_R2_Ipeak = ev.invR2_I;
        row.inverse_R2_candidate = ev.invR2_X2;
        row.residual_c3_corr = ev.residual_c3_corr;
        row.residual_struct_metric = ev.residual_struct_metric;
        metricRows(end+1,1) = row; %#ok<SAGROW>

        grow = initGeoRow();
        grow.subset = subsetNames(ss);
        grow.candidate = candList{cc}.name;
        grow.n_points = ev.n;
        grow.principal_angle1_deg = ev.ang1;
        grow.principal_angle2_deg = ev.ang2;
        grow.span_overlap_mean_cos = ev.spanOverlap;
        grow.collinearity_with_Ipeak = ev.corr_with_Ipeak;
        geoRows(end+1,1) = grow; %#ok<SAGROW>

        evStore.(subsetNames(ss)).(candList{cc}.name) = ev;
    end
end

metricsTbl = struct2table(metricRows);
metricsOut = fullfile(outDir, 'second_coordinate_duel_metrics.csv');
writetable(metricsTbl, metricsOut);

geoTbl = struct2table(geoRows);
geoOut = fullfile(outDir, 'second_coordinate_duel_geometry.csv');
writetable(geoTbl, geoOut);

% Residual-by-temperature table
resRows = repmat(initResidualRow(), 0, 1);
for ss = 1:numel(subsetNames)
    dat = subsetData{ss};
    eW = evStore.(subsetNames(ss)).width_I;
    eH = evStore.(subsetNames(ss)).halfwidth_diff_norm;

    for i = 1:numel(dat.T)
        row = initResidualRow();
        row.subset = subsetNames(ss);
        row.T_K = dat.T(i);
        row.native_residual_norm = eW.resNorm_native(i); % same native for both
        row.width_residual_norm = eW.resNorm_pair(i);
        row.halfwidth_residual_norm = eH.resNorm_pair(i);
        row.delta_half_minus_width = row.halfwidth_residual_norm - row.width_residual_norm;
        resRows(end+1,1) = row; %#ok<SAGROW>
    end
end
resTbl = struct2table(resRows);
resOut = fullfile(outDir, 'second_coordinate_duel_residuals.csv');
writetable(resTbl, resOut);

% -------------------------------------------------------------------------
% Figures
% -------------------------------------------------------------------------
% 1) Scatter vs c1/c2
figSc = figure('Color','w','Visible','off','Position',[100 100 1200 800]);
tlSc = tiledlayout(figSc, 2, 2, 'TileSpacing','compact','Padding','compact');
plotScatter(nexttile(tlSc,1), fullDat.width, fullDat.C2(:,1), fullDat.T, 'width_I', 'c_1', 'width_I vs c_1');
plotScatter(nexttile(tlSc,2), fullDat.width, fullDat.C2(:,2), fullDat.T, 'width_I', 'c_2', 'width_I vs c_2');
plotScatter(nexttile(tlSc,3), fullDat.half, fullDat.C2(:,1), fullDat.T, 'halfwidth_diff_norm', 'c_1', 'halfwidth_diff_norm vs c_1');
plotScatter(nexttile(tlSc,4), fullDat.half, fullDat.C2(:,2), fullDat.T, 'halfwidth_diff_norm', 'c_2', 'halfwidth_diff_norm vs c_2');

scOut = fullfile(outDir, 'second_coordinate_duel_scatter.png');
saveas(figSc, scOut);
close(figSc);

% 2) Reconstruction comparison (full subset)
eW = evStore.full.width_I;
eH = evStore.full.halfwidth_diff_norm;

figRc = figure('Color','w','Visible','off','Position',[100 100 1400 900]);
tlRc = tiledlayout(figRc, 2, 4, 'TileSpacing','compact','Padding','compact');
plotHeat(nexttile(tlRc,1), currents, fullDat.T, fullDat.Mtarget, 'Target S_{shape}');
plotHeat(nexttile(tlRc,2), currents, fullDat.T, eW.M_native_rank2, 'Native rank-2');
plotHeat(nexttile(tlRc,3), currents, fullDat.T, eW.M_pair, '(I_{peak}, width_I)');
plotHeat(nexttile(tlRc,4), currents, fullDat.T, eH.M_pair, '(I_{peak}, halfwidth_diff_norm)');

plotResidual(nexttile(tlRc,5), currents, fullDat.T, fullDat.Mtarget - eW.M_native_rank2, 'Residual target-native');
plotResidual(nexttile(tlRc,6), currents, fullDat.T, fullDat.Mtarget - eW.M_pair, 'Residual target-(I_{peak}, width)');
plotResidual(nexttile(tlRc,7), currents, fullDat.T, fullDat.Mtarget - eH.M_pair, 'Residual target-(I_{peak}, halfwidth)');
plotResidual(nexttile(tlRc,8), currents, fullDat.T, eH.M_pair - eW.M_pair, 'Difference: halfwidth recon - width recon');

rcOut = fullfile(outDir, 'second_coordinate_duel_reconstruction.png');
saveas(figRc, rcOut);
close(figRc);

% 3) Temperature trajectories
figTr = figure('Color','w','Visible','off','Position',[100 100 1100 700]);
tlTr = tiledlayout(figTr, 2, 1, 'TileSpacing','compact','Padding','compact');

axT1 = nexttile(tlTr,1); hold(axT1,'on');
plot(axT1, fullDat.T, fullDat.width, '-o', 'LineWidth', 1.8, 'DisplayName', 'width_I');
plot(axT1, fullDat.T, fullDat.half, '-s', 'LineWidth', 1.8, 'DisplayName', 'halfwidth_diff_norm');
xlabel(axT1, 'T (K)'); ylabel(axT1, 'raw value'); title(axT1, 'Raw temperature trajectories'); grid(axT1,'on'); legend(axT1,'Location','best');

axT2 = nexttile(tlTr,2); hold(axT2,'on');
[wz, okW] = zscoreFinite(fullDat.width);
[hz, okH] = zscoreFinite(fullDat.half);
if okW
    plot(axT2, fullDat.T, wz, '-o', 'LineWidth', 1.8, 'DisplayName', 'width_I (z)');
end
if okH
    plot(axT2, fullDat.T, hz, '-s', 'LineWidth', 1.8, 'DisplayName', 'halfwidth_diff_norm (z)');
end
xline(axT2, 12, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
xline(axT2, 20, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
xline(axT2, 30, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
xlabel(axT2, 'T (K)'); ylabel(axT2, 'z-score'); title(axT2, 'Normalized trajectories and crossover markers'); grid(axT2,'on'); legend(axT2,'Location','best');

trOut = fullfile(outDir, 'second_coordinate_duel_temperature_trajectories.png');
saveas(figTr, trOut);
close(figTr);

% -------------------------------------------------------------------------
% Decision + report
% -------------------------------------------------------------------------
mFullW = metricsTbl(metricsTbl.subset=="full" & metricsTbl.candidate=="width_I", :);
mFullH = metricsTbl(metricsTbl.subset=="full" & metricsTbl.candidate=="halfwidth_diff_norm", :);
mRobW = metricsTbl(metricsTbl.subset=="robust" & metricsTbl.candidate=="width_I", :);
mRobH = metricsTbl(metricsTbl.subset=="robust" & metricsTbl.candidate=="halfwidth_diff_norm", :);

% Primary criterion: map-space fidelity.
mapWinH = (mFullH.map_fro_error < mFullW.map_fro_error) && (mRobH.map_fro_error < mRobW.map_fro_error);
mapGapFull = mFullW.map_fro_error - mFullH.map_fro_error;
mapGapRob = mRobW.map_fro_error - mRobH.map_fro_error;

% Secondary: complementarity with I_peak (lower |corr_with_Ipeak| preferred).
compWinH = abs(mFullH.corr_with_Ipeak) < abs(mFullW.corr_with_Ipeak);

% Third: interpretability category.
% width_I = width-like ; halfwidth = deformation/asymmetry-like.

recommendation = "Outcome C";
recText = "width_I and halfwidth_diff_norm remain too close; use one as practical proxy while second coordinate remains partially unresolved.";
modelText = "(A, I_peak, unresolved_X2_proxy)";

if mapWinH && (mapGapFull > 0.01 || mapGapRob > 0.01)
    recommendation = "Outcome A";
    recText = "halfwidth_diff_norm is the better second coordinate and should be adopted as current working X2.";
    modelText = "(A, I_peak, halfwidth_diff_norm)";
elseif (~mapWinH) && ((mFullW.map_fro_error < mFullH.map_fro_error) || (mRobW.map_fro_error < mRobH.map_fro_error))
    recommendation = "Outcome B";
    recText = "width_I is the better second coordinate and should be adopted as current working X2.";
    modelText = "(A, I_peak, width_I)";
else
    % If tiny map difference, choose C regardless of tiny numerical edge.
    recommendation = "Outcome C";
    if mapWinH
        recText = "halfwidth_diff_norm has a small map-fidelity edge, but differences are too small to claim a uniquely resolved second scalar coordinate.";
    else
        recText = "width_I has a small edge in some criteria, but differences are too small to claim a uniquely resolved second scalar coordinate.";
    end
    if mapWinH
        modelText = "Practical proxy: (A, I_peak, halfwidth_diff_norm)";
    else
        modelText = "Practical proxy: (A, I_peak, width_I)";
    end
end

repOut = fullfile(outDir, 'second_coordinate_duel_report.md');
fid = fopen(repOut, 'w');
assert(fid >= 0, 'Failed opening report file: %s', repOut);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Second Coordinate Duel Report\n\n');
fprintf(fid, '## Inspect/Reuse\n\n');
fprintf(fid, '- width_I from alignment observables CSV.\n');
fprintf(fid, '- halfwidth_diff_norm from mechanism_followup CSV (source used: %s).\n', halfwidthSource);
fprintf(fid, '- S_shape target space from shape_rank conventions (rounded T bins, S_norm, row-centering, robust subset rule).\n\n');

fprintf(fid, '## Coefficient-space fidelity\n\n');
fprintf(fid, '- Full width_I: c1EV=%.3f, c2EV=%.3f, jointEV=%.3f\n', mFullW.R2_c1, mFullW.R2_c2, mFullW.pair_joint_EV);
fprintf(fid, '- Full halfwidth_diff_norm: c1EV=%.3f, c2EV=%.3f, jointEV=%.3f\n', mFullH.R2_c1, mFullH.R2_c2, mFullH.pair_joint_EV);
fprintf(fid, '- Robust width_I: c1EV=%.3f, c2EV=%.3f, jointEV=%.3f\n', mRobW.R2_c1, mRobW.R2_c2, mRobW.pair_joint_EV);
fprintf(fid, '- Robust halfwidth_diff_norm: c1EV=%.3f, c2EV=%.3f, jointEV=%.3f\n\n', mRobH.R2_c1, mRobH.R2_c2, mRobH.pair_joint_EV);

fprintf(fid, '## Map-space fidelity (primary criterion)\n\n');
fprintf(fid, '- Full map Fro: width_I=%.3f, halfwidth=%.3f (gap width-half=%.3f)\n', mFullW.map_fro_error, mFullH.map_fro_error, mapGapFull);
fprintf(fid, '- Full excess ratio: width_I=%.3f, halfwidth=%.3f\n', mFullW.excess_error_ratio, mFullH.excess_error_ratio);
fprintf(fid, '- Robust map Fro: width_I=%.3f, halfwidth=%.3f (gap width-half=%.3f)\n', mRobW.map_fro_error, mRobH.map_fro_error, mapGapRob);
fprintf(fid, '- Robust excess ratio: width_I=%.3f, halfwidth=%.3f\n\n', mRobW.excess_error_ratio, mRobH.excess_error_ratio);

fprintf(fid, '## Residual-structure comparison\n\n');
fprintf(fid, '- Full residual-vs-c3 corr: width_I=%.3f, halfwidth=%.3f\n', mFullW.residual_c3_corr, mFullH.residual_c3_corr);
fprintf(fid, '- Full residual structure metric: width_I=%.3f, halfwidth=%.3f\n', mFullW.residual_struct_metric, mFullH.residual_struct_metric);
fprintf(fid, '- Robust residual-vs-c3 corr: width_I=%.3f, halfwidth=%.3f\n', mRobW.residual_c3_corr, mRobH.residual_c3_corr);
fprintf(fid, '- Robust residual structure metric: width_I=%.3f, halfwidth=%.3f\n\n', mRobW.residual_struct_metric, mRobH.residual_struct_metric);

fprintf(fid, '## Geometric cleanliness / complementarity\n\n');
fprintf(fid, '- Full corr(candidate, I_peak): width_I=%.3f, halfwidth=%.3f\n', mFullW.corr_with_Ipeak, mFullH.corr_with_Ipeak);
fprintf(fid, '- Full principal angles (deg): width_I=[%.1f, %.1f], halfwidth=[%.1f, %.1f]\n', ...
    geoTbl.principal_angle1_deg(geoTbl.subset=="full" & geoTbl.candidate=="width_I"), ...
    geoTbl.principal_angle2_deg(geoTbl.subset=="full" & geoTbl.candidate=="width_I"), ...
    geoTbl.principal_angle1_deg(geoTbl.subset=="full" & geoTbl.candidate=="halfwidth_diff_norm"), ...
    geoTbl.principal_angle2_deg(geoTbl.subset=="full" & geoTbl.candidate=="halfwidth_diff_norm"));
fprintf(fid, '- Complementarity winner by corr-with-I_peak criterion: %s\n\n', ternary(compWinH, 'halfwidth_diff_norm', 'width_I'));

fprintf(fid, '## Final Recommendation\n\n');
fprintf(fid, '- %s\n', recommendation);
fprintf(fid, '- %s\n', recText);
fprintf(fid, '- Working description: %s\n\n', modelText);

fprintf(fid, 'Generated: %s\n', datestr(now,31));

% ZIP key review files
zipOut = fullfile(outDir, 'second_coordinate_duel_review.zip');
if isfile(zipOut)
    delete(zipOut);
end
zipFiles = { ...
    'second_coordinate_duel_metrics.csv', ...
    'second_coordinate_duel_residuals.csv', ...
    'second_coordinate_duel_geometry.csv', ...
    'second_coordinate_duel_scatter.png', ...
    'second_coordinate_duel_reconstruction.png', ...
    'second_coordinate_duel_temperature_trajectories.png', ...
    'second_coordinate_duel_report.md' ...
    };
paths = strings(0,1);
for i = 1:numel(zipFiles)
    p = fullfile(outDir, zipFiles{i});
    if isfile(p)
        paths(end+1,1) = string(p); %#ok<SAGROW>
    else
        error('Missing key duel output for ZIP: %s', p);
    end
end
zip(char(zipOut), cellstr(paths));

fprintf('Second-coordinate duel complete.\n');
fprintf('Output directory: %s\n', outDir);
fprintf('Metrics CSV: %s\n', metricsOut);
fprintf('Residual CSV: %s\n', resOut);
fprintf('Geometry CSV: %s\n', geoOut);
fprintf('Report: %s\n', repOut);
fprintf('Review ZIP: %s\n', zipOut);


function dat = makeSubsetData(idx, temps, I_peak, width_I, halfwidth_diff, shapeSub)
dat = struct();
dat.idx = idx;
dat.T = temps(idx);
dat.Ipeak = I_peak(idx);
dat.width = width_I(idx);
dat.half = halfwidth_diff(idx);
dat.C2 = shapeSub.C(:,1:2);
dat.V2 = shapeSub.V2(:,1:2);
dat.Mtarget = shapeSub.M;
if size(shapeSub.C,2) >= 3
    dat.c3 = shapeSub.C(:,3);
else
    dat.c3 = NaN(size(dat.T));
end
end


function ev = evaluateCandidatePair(Ipeak, X2, C2, V2, Mtarget, c3)
ev = struct('n',NaN,'corr_c1',NaN,'corr_c2',NaN,'R2_c1',NaN,'R2_c2',NaN,'jointEV',NaN, ...
    'nativeFro',NaN,'pairFro',NaN,'excessRatio',NaN,'corr_with_Ipeak',NaN, ...
    'partial_c1_given_I',NaN,'partial_c2_given_I',NaN,'invR2_I',NaN,'invR2_X2',NaN, ...
    'residual_c3_corr',NaN,'residual_struct_metric',NaN,'ang1',NaN,'ang2',NaN,'spanOverlap',NaN, ...
    'M_native_rank2',NaN(size(Mtarget)),'M_pair',NaN(size(Mtarget)), ...
    'resNorm_native',NaN(size(Mtarget,1),1),'resNorm_pair',NaN(size(Mtarget,1),1));

v = isfinite(Ipeak) & isfinite(X2) & all(isfinite(C2),2);
if nnz(v) < 5
    return;
end
I = Ipeak(v);
X = X2(v);
C = C2(v,:);
M = Mtarget(v,:);

% Single-observable relations
[ev.corr_c1, ev.R2_c1] = corrAndLinR2(X, C(:,1));
[ev.corr_c2, ev.R2_c2] = corrAndLinR2(X, C(:,2));
ev.corr_with_Ipeak = safeCorr(X, I);

% Partial correlation with c1/c2 after controlling I_peak
ev.partial_c1_given_I = partialCorr(C(:,1), X, I);
ev.partial_c2_given_I = partialCorr(C(:,2), X, I);

% Pair model C_hat = f(Ipeak, X2)
P = [I, X];
Xp = [ones(size(P,1),1), P];
B = Xp \ C;
C_hat = Xp * B;

% Inverse mapping
Bi = [ones(size(C,1),1), C] \ P;
P_hat = [ones(size(C,1),1), C] * Bi;
ev.invR2_I = calcR2(P(:,1), P_hat(:,1));
ev.invR2_X2 = calcR2(P(:,2), P_hat(:,2));

% EV metrics
ev.R2_c1 = calcR2(C(:,1), C_hat(:,1));
ev.R2_c2 = calcR2(C(:,2), C_hat(:,2));
ev.jointEV = calcJointEV(C, C_hat);

% Map reconstructions
M_native = C * V2';
M_pair = C_hat * V2';

nf = froErr(M, M_native);
pf = froErr(M, M_pair);
ev.nativeFro = nf;
ev.pairFro = pf;
if isfinite(nf) && nf > 0
    ev.excessRatio = (pf - nf) / nf;
end

% Residual norms by row
resN = rowResidualNorms(M, M_native);
resP = rowResidualNorms(M, M_pair);

% Store in full-length vectors aligned to subset rows
ev.resNorm_native(v) = resN;
ev.resNorm_pair(v) = resP;

% Residual structure metrics
if nargin >= 6 && numel(c3) == size(Mtarget,1)
    c3v = c3(v);
    ev.residual_c3_corr = safeCorr(resP, abs(c3v));
end
% Simple structure metric: normalized std of row residual norms
if any(isfinite(resP))
    ev.residual_struct_metric = std(resP, 'omitnan') / (mean(abs(resP), 'omitnan') + eps);
end

% Geometry: principal angles between predictor and coefficient spans
Pc = P - mean(P,1,'omitnan');
Cc = C - mean(C,1,'omitnan');
Qp = orth(Pc); Qc = orth(Cc);
if ~isempty(Qp) && ~isempty(Qc)
    s = svd(Qp' * Qc);
    s = max(min(s,1),-1);
    ang = acosd(s);
    if numel(ang) >= 1, ev.ang1 = ang(1); end
    if numel(ang) >= 2, ev.ang2 = ang(2); end
    ev.spanOverlap = mean(s, 'omitnan');
end

MnatFull = NaN(size(Mtarget));
MpairFull = NaN(size(Mtarget));
MnatFull(v,:) = M_native;
MpairFull(v,:) = M_pair;
ev.M_native_rank2 = MnatFull;
ev.M_pair = MpairFull;
ev.n = nnz(v);
end


function rn = rowResidualNorms(A, B)
rn = NaN(size(A,1),1);
for i = 1:size(A,1)
    v = isfinite(A(i,:)) & isfinite(B(i,:));
    if nnz(v) < 3
        continue;
    end
    a = A(i,v); b = B(i,v);
    denom = norm(a, 2);
    if denom > 0
        rn(i) = norm(a-b,2)/denom;
    end
end
end


function [halfDiff, curvature] = computeHalfwidthAndCurvFallback(Smap, currents, Ipeak, widthI)
N = size(Smap,1);
halfDiff = NaN(N,1);
curvature = NaN(N,1);
for it = 1:N
    row = Smap(it,:);
    cur = currents(:)';
    v = isfinite(row) & isfinite(cur) & isfinite(Ipeak(it));
    if nnz(v) < 5
        continue;
    end
    rv = row(v);
    cv = cur(v);

    % S_norm for this row fallback
    pk = max(rv, [], 'omitnan');
    if ~(isfinite(pk) && pk > eps)
        continue;
    end
    rv = rv / pk;

    w = widthI(it);
    if ~isfinite(w) || w <= eps
        span = max(cv)-min(cv);
        w = max(span/6, eps);
    end
    x = (cv - Ipeak(it)) / w;

    mH = rv >= 0.5;
    if nnz(mH) >= 2
        halfDiff(it) = max(x(mH)) - abs(min(x(mH)));
    end

    mP = abs(x) <= 0.6;
    if nnz(mP) >= 5
        p2 = polyfit(x(mP), rv(mP), 2);
        curvature(it) = 2*p2(1);
    end
end
end


function [corrVal, r2] = corrAndLinR2(x,y)
v = isfinite(x) & isfinite(y);
if nnz(v) < 3
    corrVal = NaN; r2 = NaN; return;
end
corrVal = corr(x(v), y(v), 'rows','complete');
X = [ones(nnz(v),1), x(v)];
b = X \ y(v);
yh = X*b;
r2 = calcR2(y(v), yh);
end


function p = partialCorr(y, x, z)
v = isfinite(y) & isfinite(x) & isfinite(z);
if nnz(v) < 5
    p = NaN; return;
end
Y = y(v); X = x(v); Z = z(v);
ry = Y - [ones(numel(Z),1), Z] * ([ones(numel(Z),1), Z] \ Y);
rx = X - [ones(numel(Z),1), Z] * ([ones(numel(Z),1), Z] \ X);
p = safeCorr(ry, rx);
end


function r2 = calcR2(y, yh)
v = isfinite(y) & isfinite(yh);
if nnz(v) < 3
    r2 = NaN; return;
end
yv = y(v); yhv = yh(v);
sse = sum((yv-yhv).^2, 'omitnan');
sst = sum((yv-mean(yv,'omitnan')).^2, 'omitnan');
if sst <= 0
    r2 = NaN;
else
    r2 = 1 - sse/sst;
end
end


function ev = calcJointEV(Y, Yh)
v = all(isfinite(Y),2) & all(isfinite(Yh),2);
if nnz(v) < 3
    ev = NaN; return;
end
Y0 = Y(v,:); Yh0 = Yh(v,:);
Ym = Y0 - mean(Y0,1,'omitnan');
res = Y0 - Yh0;
den = norm(Ym, 'fro');
if den <= 0
    ev = NaN;
else
    ev = 1 - (norm(res, 'fro')^2)/(den^2);
end
end


function r = froErr(A, B)
v = isfinite(A) & isfinite(B);
if nnz(v) < 3
    r = NaN; return;
end
a = A(v); b = B(v);
den = norm(a, 'fro');
if den <= 0
    r = NaN;
else
    r = norm(a-b, 'fro') / den;
end
end


function [z, ok] = zscoreFinite(x)
z = NaN(size(x)); ok = false;
v = isfinite(x);
if nnz(v) < 3
    return;
end
mu = mean(x(v), 'omitnan');
sd = std(x(v), 'omitnan');
if sd <= eps
    return;
end
z(v) = (x(v)-mu)/sd;
ok = true;
end


function row = initMetricRow()
row = struct();
row.subset = "";
row.candidate = "";
row.category = "";
row.n_points = NaN;
row.corr_c1 = NaN;
row.corr_c2 = NaN;
row.R2_c1 = NaN;
row.R2_c2 = NaN;
row.pair_joint_EV = NaN;
row.native_rank2_fro_error = NaN;
row.map_fro_error = NaN;
row.excess_error_ratio = NaN;
row.corr_with_Ipeak = NaN;
row.partial_corr_c1_given_Ipeak = NaN;
row.partial_corr_c2_given_Ipeak = NaN;
row.inverse_R2_Ipeak = NaN;
row.inverse_R2_candidate = NaN;
row.residual_c3_corr = NaN;
row.residual_struct_metric = NaN;
end


function row = initGeoRow()
row = struct();
row.subset = "";
row.candidate = "";
row.n_points = NaN;
row.principal_angle1_deg = NaN;
row.principal_angle2_deg = NaN;
row.span_overlap_mean_cos = NaN;
row.collinearity_with_Ipeak = NaN;
end


function row = initResidualRow()
row = struct();
row.subset = "";
row.T_K = NaN;
row.native_residual_norm = NaN;
row.width_residual_norm = NaN;
row.halfwidth_residual_norm = NaN;
row.delta_half_minus_width = NaN;
end


function plotScatter(ax, x, y, T, xlbl, ylbl, ttl)
v = isfinite(x) & isfinite(y) & isfinite(T);
scatter(ax, x(v), y(v), 55, T(v), 'filled');
hold(ax,'on');
if nnz(v) >= 3
    X = [ones(nnz(v),1), x(v)];
    b = X \ y(v);
    xg = linspace(min(x(v)), max(x(v)), 200)';
    yg = [ones(numel(xg),1), xg] * b;
    plot(ax, xg, yg, '-', 'LineWidth', 2);
end
xlabel(ax, xlbl); ylabel(ax, ylbl); title(ax, ttl); grid(ax,'on');
cb = colorbar(ax); ylabel(cb,'T (K)');
end


function plotHeat(ax, currents, temps, M, ttl)
imagesc(ax, currents, temps, M);
set(ax,'YDir','normal');
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
set(ax,'YDir','normal');
applyDiverging(ax);
vals = R(isfinite(R));
if ~isempty(vals)
    lim = max(abs(vals));
    if isfinite(lim) && lim > 0
        caxis(ax, [-lim lim]);
    end
end
xlabel(ax, 'I_0 (mA)'); ylabel(ax, 'T (K)'); title(ax, ttl);
cb = colorbar(ax); ylabel(cb,'residual');
end


function applyDiverging(ax)
n = 256;
r = [(0:(n/2-1))/(n/2), ones(1,n/2)];
g = [(0:(n/2-1))/(n/2), ((n/2-1):-1:0)/(n/2)];
b = [ones(1,n/2), ((n/2-1):-1:0)/(n/2)];
colormap(ax, [r(:), g(:), b(:)]);
end


function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end

