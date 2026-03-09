% switching_second_structural_observable_search
% Focused search for a better second structural observable X2 such that
% (I_peak, X2) spans the dominant rank-2 shape sector.

clearvars;
clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
switchingRoot = fileparts(analysisDir);
repoRoot = fileparts(switchingRoot);

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));

alignDir = resolve_results_input_dir(repoRoot, 'switching', 'alignment_audit');
followDir = resolve_results_input_dir(repoRoot, 'switching', 'mechanism_followup');
[outDir, run] = init_run_output_dir(repoRoot, 'switching', 'second_observable_search'); %#ok<ASGLU>
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
        error('Found non-P2P_percent rows in samples; this analysis requires fixed metricType=P2P_percent.');
    end
end

% Base observables
Tobs = toNum(obsTbl, 'T_K');
I_peak_obs = toNum(obsTbl, 'Ipeak');
width_obs = toNum(obsTbl, 'width_I');
asym_obs = toNum(obsTbl, 'asym');

% Reconstruct map with rounded-T convention
[tempsMap, currents, Smap] = buildMapRounded(sampTbl);
[temps, iObs, iMap] = intersect(Tobs, tempsMap, 'stable');
assert(~isempty(temps), 'No overlap between observables temperatures and map temperatures.');

I_peak = I_peak_obs(iObs);
width_I = width_obs(iObs);
asym = asym_obs(iObs);
Smap = Smap(iMap, :);

% Shape-sector target space (same convention as shape_rank_analysis)
[S_norm, S_shape, S_peak, rowMean, validRows, robustRows, peakFloor, globalPeak] = buildShapeMaps(Smap, temps);

idxFull = find(validRows);
idxRob = find(robustRows);
shapeFull = analyzeShapeSubspace(S_shape(idxFull,:), 2);
shapeRob = analyzeShapeSubspace(S_shape(idxRob,:), 2);

Cfull = shapeFull.C;
Vfull = shapeFull.V2;
Mfull = shapeFull.M;
Tfull = temps(idxFull);

Crob = shapeRob.C;
Vrob = shapeRob.V2;
Mrob = shapeRob.M;
Trob = temps(idxRob);

% Existing X_shape definition from switching_XI_Xshape_analysis
[X_shape, A_left, A_right] = computeXshapeFromMap(Smap, currents, I_peak);

% Candidate discovery / reuse
cand = struct('name',{},'category',{},'description',{},'source',{},'values',{});
cand(end+1) = mkCand("width_I", "width-like", "Half-maximum width from alignment audit", "alignment_observables", width_I);
cand(end+1) = mkCand("X_shape", "branching-like", "(A_right-A_left)/(A_right+A_left) around I_peak", "reconstructed_existing_definition", X_shape);

% Existing asym is a monotonic transform of X_shape-like area ratio; keep only one to avoid duplication.
% Use asym only if X_shape is mostly missing.
if nnz(isfinite(X_shape)) < 3 && nnz(isfinite(asym)) >= 3
    cand(end+1) = mkCand("asym_ratio", "branching-like", "Area ratio A_right/A_left from alignment audit", "alignment_observables", asym);
end

% Try to reuse follow-up shape metrics first.
followTbl = table();
if isfile(shapeCsv)
    followTbl = readtable(shapeCsv);
end

halfwidth_diff = NaN(size(temps));
curvature = NaN(size(temps));
if ~isempty(followTbl) && ismember('T_K', string(followTbl.Properties.VariableNames))
    Tf = toNum(followTbl, 'T_K');
    [~, iT, iF] = intersect(temps, Tf, 'stable');
    if ismember('halfwidth_diff_norm', string(followTbl.Properties.VariableNames))
        tmp = toNum(followTbl, 'halfwidth_diff_norm');
        halfwidth_diff(iT) = tmp(iF);
    end
    if ismember('curvature_near_peak', string(followTbl.Properties.VariableNames))
        tmp = toNum(followTbl, 'curvature_near_peak');
        curvature(iT) = tmp(iF);
    end
end

% Minimal fallback computation only if follow-up metrics are missing.
if nnz(isfinite(halfwidth_diff)) < 3 || nnz(isfinite(curvature)) < 3
    [halfwidth_fb, curvature_fb, skew_m3] = computeShapeDescriptors(S_norm, currents, I_peak, width_I);
    if nnz(isfinite(halfwidth_diff)) < 3
        halfwidth_diff = halfwidth_fb;
    end
    if nnz(isfinite(curvature)) < 3
        curvature = curvature_fb;
    end
else
    [~, ~, skew_m3] = computeShapeDescriptors(S_norm, currents, I_peak, width_I);
end

cand(end+1) = mkCand("halfwidth_diff_norm", "branching-like", "Right-left normalized half-width difference", "mechanism_followup_or_fallback", halfwidth_diff);
cand(end+1) = mkCand("curvature_near_peak", "shoulder/branching-like", "Quadratic curvature near ridge center", "mechanism_followup_or_fallback", curvature);
cand(end+1) = mkCand("skew_m3", "skew-like", "Third central moment of S_norm profile around I_peak", "new_minimal", skew_m3);

% Keep compact set (3-5 second-coordinate candidates): currently 5.

% -------------------------------------------------------------------------
% 1) Single-observable relations to c1,c2
% -------------------------------------------------------------------------
sumRows = repmat(initSummaryRow(), 0, 1);
for i = 1:numel(cand)
    xF = cand(i).values(idxFull);
    xR = cand(i).values(idxRob);

    [c1corrF, c1R2F] = corrAndLinR2(xF, Cfull(:,1));
    [c2corrF, c2R2F] = corrAndLinR2(xF, Cfull(:,2));
    [c1corrR, c1R2R] = corrAndLinR2(xR, Crob(:,1));
    [c2corrR, c2R2R] = corrAndLinR2(xR, Crob(:,2));

    row = initSummaryRow();
    row.candidate_name = cand(i).name;
    row.category = cand(i).category;
    row.description = cand(i).description;
    row.source = cand(i).source;
    row.n_full = nnz(isfinite(xF) & all(isfinite(Cfull),2));
    row.corr_c1_full = c1corrF;
    row.corr_c2_full = c2corrF;
    row.R2_c1_full = c1R2F;
    row.R2_c2_full = c2R2F;
    row.n_robust = nnz(isfinite(xR) & all(isfinite(Crob),2));
    row.corr_c1_robust = c1corrR;
    row.corr_c2_robust = c2corrR;
    row.R2_c1_robust = c1R2R;
    row.R2_c2_robust = c2R2R;
    sumRows(end+1,1) = row; %#ok<SAGROW>
end

sumTbl = struct2table(sumRows);
sumOut = fullfile(outDir, 'second_observable_candidate_summary.csv');
writetable(sumTbl, sumOut);

% -------------------------------------------------------------------------
% 2-3) Pair-basis + map-space reconstruction tests for (I_peak, candidate)
% -------------------------------------------------------------------------
pairRows = repmat(initPairRow(), 0, 1);
geoRows = repmat(initGeoRow(), 0, 1);

for i = 1:numel(cand)
    pairName = sprintf('Ipeak_%s', cand(i).name);

    Pf = [I_peak(idxFull), cand(i).values(idxFull)];
    Pr = [I_peak(idxRob), cand(i).values(idxRob)];

    evF = evaluatePair(Pf, Cfull, Vfull, Mfull);
    evR = evaluatePair(Pr, Crob, Vrob, Mrob);

    pairRows(end+1,1) = mkPairRow("full", pairName, cand(i), evF); %#ok<SAGROW>
    pairRows(end+1,1) = mkPairRow("robust", pairName, cand(i), evR); %#ok<SAGROW>

    geoRows(end+1,1) = mkGeoRow("full", pairName, cand(i), evF); %#ok<SAGROW>
    geoRows(end+1,1) = mkGeoRow("robust", pairName, cand(i), evR); %#ok<SAGROW>
end

pairTbl = struct2table(pairRows);
% Ranking score: high joint EV, low excess error, robust consistency.
pairTbl.ranking_score = pairTbl.joint_coeff_explained_var - 0.5*pairTbl.excess_error_ratio;

% Relative degradation to best per subset
pairTbl.relative_degradation_vs_best = NaN(height(pairTbl),1);
for ss = ["full","robust"]
    m = pairTbl.subset == ss & isfinite(pairTbl.map_fro_error);
    if any(m)
        best = min(pairTbl.map_fro_error(m));
        pairTbl.relative_degradation_vs_best(m) = (pairTbl.map_fro_error(m) - best) ./ best;
    end
end

pairOut = fullfile(outDir, 'second_observable_pair_comparison.csv');
writetable(pairTbl, pairOut);

geoTbl = struct2table(geoRows);
geoOut = fullfile(outDir, 'second_observable_geometry.csv');
writetable(geoTbl, geoOut);

% Select top candidates by full-subset ranking
fullPairs = pairTbl(pairTbl.subset=="full", :);
fullPairs = sortrows(fullPairs, 'ranking_score', 'descend');

nTop = min(3, height(fullPairs));
topPairNames = string(fullPairs.pair_name(1:nTop));

% -------------------------------------------------------------------------
% Figures
% -------------------------------------------------------------------------
% 1) Candidate scatter for top candidates
figSc = figure('Color','w','Visible','off','Position',[100 100 1300 350*max(1,nTop)]);
tlSc = tiledlayout(figSc, nTop, 2, 'TileSpacing','compact','Padding','compact');
for k = 1:nTop
    pnm = topPairNames(k);
    cname = extractAfter(pnm, "Ipeak_");
    cidx = find(string({cand.name}) == cname, 1, 'first');
    if isempty(cidx)
        continue;
    end
    x = cand(cidx).values(idxFull);
    plotScatterWithFit(nexttile(tlSc, (k-1)*2 + 1), x, Cfull(:,1), Tfull, char(cname), 'c_1', sprintf('%s vs c_1', cname));
    plotScatterWithFit(nexttile(tlSc, (k-1)*2 + 2), x, Cfull(:,2), Tfull, char(cname), 'c_2', sprintf('%s vs c_2', cname));
end
scOut = fullfile(outDir, 'second_observable_candidate_scatter.png');
saveas(figSc, scOut);
close(figSc);

% 2) Pair comparison compact figure
figPC = figure('Color','w','Visible','off','Position',[100 100 1300 580]);
tlPC = tiledlayout(figPC, 1, 2, 'TileSpacing','compact','Padding','compact');

ax1 = nexttile(tlPC,1); hold(ax1,'on');
fp = pairTbl(pairTbl.subset=="full", :);
fp = sortrows(fp, 'ranking_score', 'descend');
bar(ax1, categorical(fp.pair_name), [fp.joint_coeff_explained_var, fp.c1_explained_var, fp.c2_explained_var], 'grouped');
ylabel(ax1,'explained variance'); title(ax1,'Full subset: coefficient-space performance'); grid(ax1,'on');
legend(ax1, {'joint','c1','c2'}, 'Location','best');

ax2 = nexttile(tlPC,2); hold(ax2,'on');
rb = pairTbl(pairTbl.subset=="robust", :);
rb = sortrows(rb, 'ranking_score', 'descend');
bar(ax2, categorical(rb.pair_name), [rb.map_fro_error, rb.excess_error_ratio, rb.relative_degradation_vs_best], 'grouped');
ylabel(ax2,'error metric'); title(ax2,'Robust subset: map-space penalties'); grid(ax2,'on');
legend(ax2, {'pair fro error','excess ratio','degradation vs best'}, 'Location','best');

pcOut = fullfile(outDir, 'second_observable_pair_comparison.png');
saveas(figPC, pcOut);
close(figPC);

% 3) Reconstruction comparison for top pairs (full subset)
figRC = figure('Color','w','Visible','off','Position',[100 100 1400 340*(nTop+1)]);
tlRC = tiledlayout(figRC, nTop+1, 3, 'TileSpacing','compact','Padding','compact');

% Native references on first row
plotHeat(nexttile(tlRC,1), currents, Tfull, Mfull, 'Target S_{shape} (full)');
plotHeat(nexttile(tlRC,2), currents, Tfull, shapeFull.M_native, 'Native rank-2 SVD');
plotResidual(nexttile(tlRC,3), currents, Tfull, Mfull-shapeFull.M_native, 'Residual: target-native');

for k = 1:nTop
    pnm = topPairNames(k);
    cname = extractAfter(pnm, "Ipeak_");
    cidx = find(string({cand.name}) == cname, 1, 'first');
    if isempty(cidx)
        continue;
    end
    ev = evaluatePair([I_peak(idxFull), cand(cidx).values(idxFull)], Cfull, Vfull, Mfull);
    plotHeat(nexttile(tlRC, 3*k + 1), currents, Tfull, ev.M_pair_recon, sprintf('%s recon', pnm));
    plotResidual(nexttile(tlRC, 3*k + 2), currents, Tfull, ev.M_target - ev.M_pair_recon, sprintf('Residual target-%s', pnm));
    plotResidual(nexttile(tlRC, 3*k + 3), currents, Tfull, ev.M_pair_recon - shapeFull.M_native, sprintf('Diff %s-native', pnm));
end

rcOut = fullfile(outDir, 'second_observable_reconstruction_comparison.png');
saveas(figRC, rcOut);
close(figRC);

% -------------------------------------------------------------------------
% Decision and report
% -------------------------------------------------------------------------
% Best pair by average normalized rank across full+robust
pairTbl.rank_in_subset = NaN(height(pairTbl),1);
for ss = ["full","robust"]
    m = pairTbl.subset == ss;
    [~, ord] = sort(pairTbl.ranking_score(m), 'descend');
    idx = find(m);
    rk = NaN(sum(m),1); rk(ord) = 1:numel(ord);
    pairTbl.rank_in_subset(idx) = rk;
end

uniquePairs = unique(pairTbl.pair_name);
agg = table(uniquePairs, NaN(numel(uniquePairs),1), NaN(numel(uniquePairs),1), ...
    'VariableNames', {'pair_name','avg_rank','avg_score'});
for i = 1:numel(uniquePairs)
    m = pairTbl.pair_name == uniquePairs(i);
    agg.avg_rank(i) = mean(pairTbl.rank_in_subset(m), 'omitnan');
    agg.avg_score(i) = mean(pairTbl.ranking_score(m), 'omitnan');
end
agg = sortrows(agg, {'avg_rank','avg_score'}, {'ascend','descend'});
bestPair = string(agg.pair_name(1));

repOut = fullfile(outDir, 'second_observable_report.md');
fid = fopen(repOut, 'w');
assert(fid >= 0, 'Failed opening report: %s', repOut);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# Second Structural Observable Search Report\n\n');
fprintf(fid, '## Inspect/Reuse Summary\n\n');
fprintf(fid, '- Reused from alignment audit: I_peak, width_I, asym, and map samples.\n');
fprintf(fid, '- Reused from XI/Xshape analysis: X_shape definition `(A_R-A_L)/(A_R+A_L)`.\n');
fprintf(fid, '- Reused from shape-rank analysis: S_norm/S_shape construction and robust subset rule (`T<=30K`, `S_peak>=5%% max`).\n');
fprintf(fid, '- Reused from mechanism_followup when available: halfwidth_diff_norm, curvature_near_peak.\n');
fprintf(fid, '- Implemented only one minimal new descriptor: skew_m3 (third central moment of S_norm around I_peak).\n\n');

fprintf(fid, '## Candidate Observables Tested\n\n');
for i = 1:numel(cand)
    fprintf(fid, '- `%s` (%s): %s [source: %s]\n', cand(i).name, cand(i).category, cand(i).description, cand(i).source);
end
fprintf(fid, '\n');

fprintf(fid, '## Pair Basis Results (I_peak, X2)\n\n');
fullTop = pairTbl(pairTbl.subset=="full", :);
fullTop = sortrows(fullTop, 'ranking_score', 'descend');
for i = 1:min(5,height(fullTop))
    fprintf(fid, '- %s: jointEV=%.3f, mapFro=%.3f, excess=%.3f\n', fullTop.pair_name(i), fullTop.joint_coeff_explained_var(i), fullTop.map_fro_error(i), fullTop.excess_error_ratio(i));
end
fprintf(fid, '\n');

fprintf(fid, '## Robustness\n\n');
robTop = pairTbl(pairTbl.subset=="robust", :);
robTop = sortrows(robTop, 'ranking_score', 'descend');
for i = 1:min(5,height(robTop))
    fprintf(fid, '- %s: jointEV=%.3f, mapFro=%.3f, excess=%.3f\n', robTop.pair_name(i), robTop.joint_coeff_explained_var(i), robTop.map_fro_error(i), robTop.excess_error_ratio(i));
end
fprintf(fid, '\n');

% Determine outcome A/B/C
bestFull = fullTop(1,:);
bestRob = robTop(1,:);
fullGap = NaN; robustGap = NaN;
if height(fullTop) >= 2
    fullGap = bestFull.ranking_score - fullTop.ranking_score(2);
end
if height(robTop) >= 2
    robustGap = bestRob.ranking_score - robTop.ranking_score(2);
end

outcome = "C";
outcomeText = "No simple scalar second observable is clearly adequate.";
if bestFull.joint_coeff_explained_var >= 0.80 && bestFull.excess_error_ratio <= 0.50 && ...
   bestRob.joint_coeff_explained_var >= 0.75 && bestRob.excess_error_ratio <= 0.60 && ...
   isfinite(fullGap) && fullGap >= 0.05
    outcome = "A";
    outcomeText = "A clear best second observable exists and with I_peak spans the rank-2 structural sector well.";
elseif bestFull.joint_coeff_explained_var >= 0.70 && bestRob.joint_coeff_explained_var >= 0.70 && ...
       isfinite(fullGap) && fullGap < 0.05
    outcome = "B";
    outcomeText = "Several candidates perform similarly; second coordinate is identifiable up to a small family.";
end

fprintf(fid, '## Decision\n\n');
fprintf(fid, '- Outcome: **%s**\n', outcome);
fprintf(fid, '- %s\n\n', outcomeText);

fprintf(fid, '## Recommended Minimal Interpretable Model\n\n');
fprintf(fid, '- Current best from this search: `(A, I_peak, %s)`\n', extractAfter(bestPair, "Ipeak_"));
if bestPair == "Ipeak_width_I"
    fprintf(fid, '- This supports a width-like second coordinate in this dataset.\n');
elseif contains(bestPair, "halfwidth") || contains(bestPair, "curvature") || contains(bestPair, "X_shape") || contains(bestPair, "skew")
    fprintf(fid, '- This supports a deformation/asymmetry-like second coordinate in this dataset.\n');
end
fprintf(fid, '\n');

fprintf(fid, 'Generated: %s\n', datestr(now,31));

% Review ZIP
zipOut = fullfile(outDir, 'second_observable_review.zip');
if isfile(zipOut)
    delete(zipOut);
end
zipFiles = { ...
    'second_observable_candidate_summary.csv', ...
    'second_observable_pair_comparison.csv', ...
    'second_observable_geometry.csv', ...
    'second_observable_candidate_scatter.png', ...
    'second_observable_pair_comparison.png', ...
    'second_observable_reconstruction_comparison.png', ...
    'second_observable_report.md' ...
    };
paths = strings(0,1);
for i = 1:numel(zipFiles)
    p = fullfile(outDir, zipFiles{i});
    if isfile(p)
        paths(end+1,1) = string(p); %#ok<SAGROW>
    else
        error('Missing key output for ZIP: %s', p);
    end
end
zip(char(zipOut), cellstr(paths));

fprintf('Second-observable search complete.\n');
fprintf('Output directory: %s\n', outDir);
fprintf('Candidate summary CSV: %s\n', sumOut);
fprintf('Pair comparison CSV: %s\n', pairOut);
fprintf('Geometry CSV: %s\n', geoOut);
fprintf('Report: %s\n', repOut);
fprintf('Review ZIP: %s\n', zipOut);


function c = mkCand(name, cat, desc, src, vals)
c = struct('name', string(name), 'category', string(cat), 'description', string(desc), 'source', string(src), 'values', vals(:));
end


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
Traw = toNum(tbl,'T_K');
Iraw = toNum(tbl,'current_mA');
Sraw = toNum(tbl,'S_percent');
v = isfinite(Traw) & isfinite(Iraw) & isfinite(Sraw);
Traw = Traw(v); Iraw = Iraw(v); Sraw = Sraw(v);
Tbin = round(Traw);
temps = sort(unique(Tbin));
currents = sort(unique(Iraw));
Smap = NaN(numel(temps), numel(currents));
for it = 1:numel(temps)
    for ii = 1:numel(currents)
        m = Tbin==temps(it) & abs(Iraw-currents(ii))<1e-9;
        if any(m)
            Smap(it,ii) = mean(Sraw(m), 'omitnan');
        end
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
    if ~any(v), continue; end
    Speak(it) = max(row(v), [], 'omitnan');
end

gPeak = max(Speak(isfinite(Speak)), [], 'omitnan');
peakFloor = max(1e-6, 1e-4*gPeak);
validRows = isfinite(Speak) & Speak > peakFloor;

for it = 1:numel(temps)
    if ~validRows(it), continue; end
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

robustRows = validRows & isfinite(temps) & temps<=30 & Speak >= 0.05*gPeak;
end


function sh = analyzeShapeSubspace(M, rankK)
mask = isfinite(M);
M0 = M; M0(~mask)=0;
[U,S,V] = svd(M0, 'econ');
sv = diag(S);
k = min([rankK, numel(sv), size(U,2), size(V,2)]);
C = U(:,1:k) * S(1:k,1:k);
V2 = V(:,1:k);
sh = struct('M',M,'U',U,'S',S,'V',V,'C',C,'V2',V2,'M_native',C*V2');
end


function [Xshape, Aleft, Aright] = computeXshapeFromMap(Smap, currents, Ipeak)
Xshape = NaN(size(Ipeak));
Aleft = NaN(size(Ipeak));
Aright = NaN(size(Ipeak));
for it = 1:numel(Ipeak)
    row = Smap(it,:);
    cur = currents(:)';
    v = isfinite(row) & isfinite(cur) & isfinite(Ipeak(it));
    if nnz(v) < 3, continue; end
    rv = row(v); cv = cur(v);
    mL = cv < Ipeak(it); mR = cv > Ipeak(it);
    if ~any(mL) || ~any(mR), continue; end
    Aleft(it) = sum(rv(mL), 'omitnan');
    Aright(it) = sum(rv(mR), 'omitnan');
    den = Aleft(it)+Aright(it);
    if isfinite(den) && abs(den)>eps
        Xshape(it) = max(min((Aright(it)-Aleft(it))/den,1),-1);
    end
end
end


function [halfDiff, curvature, skew3] = computeShapeDescriptors(S_norm, currents, Ipeak, widthI)
N = size(S_norm,1);
halfDiff = NaN(N,1);
curvature = NaN(N,1);
skew3 = NaN(N,1);

for it = 1:N
    row = S_norm(it,:);
    cur = currents(:)';
    v = isfinite(row) & isfinite(cur) & isfinite(Ipeak(it));
    if nnz(v) < 5
        continue;
    end
    rv = row(v);
    cv = cur(v);

    % Width-normalized coordinate
    w = widthI(it);
    if ~isfinite(w) || w <= eps
        span = max(cv)-min(cv);
        w = max(span/6, eps);
    end
    x = (cv - Ipeak(it)) / w;

    % Half-width difference
    pmax = max(rv, [], 'omitnan');
    if isfinite(pmax) && pmax > eps
        mH = rv >= 0.5*pmax;
        if nnz(mH) >= 2
            left = abs(min(x(mH)));
            right = max(x(mH));
            halfDiff(it) = right - left;
        end
    end

    % Curvature near peak
    mP = abs(x) <= 0.6;
    if nnz(mP) >= 5
        p2 = polyfit(x(mP), rv(mP), 2);
        curvature(it) = 2*p2(1);
    end

    % Skewness-like third moment (using nonnegative weights)
    wgt = max(rv, 0);
    if sum(wgt, 'omitnan') > eps
        mu = sum(wgt .* x, 'omitnan') / sum(wgt, 'omitnan');
        xc = x - mu;
        m2 = sum(wgt .* (xc.^2), 'omitnan') / sum(wgt, 'omitnan');
        if m2 > eps
            m3 = sum(wgt .* (xc.^3), 'omitnan') / sum(wgt, 'omitnan');
            skew3(it) = m3 / (m2^(1.5));
        end
    end
end
end


function [corrVal, r2] = corrAndLinR2(x, y)
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


function ev = evaluatePair(P, C, V2, M)
ev = struct('n_points',NaN,'c1R2',NaN,'c2R2',NaN,'jointEV',NaN, ...
    'invR2_p1',NaN,'invR2_p2',NaN,'nativeFro',NaN,'pairFro',NaN,'excessRatio',NaN, ...
    'angle1',NaN,'angle2',NaN,'spanOverlap',NaN,'M_target',M,'M_pair_recon',NaN(size(M)));

if size(P,2) < 2 || size(C,2) < 2
    return;
end

v = all(isfinite(P),2) & all(isfinite(C),2);
if nnz(v) < 5
    return;
end
P0 = P(v,:); C0 = C(v,:); M0 = M(v,:);

X = [ones(size(P0,1),1), P0];
B = X \ C0;
C_hat = X*B;

ev.c1R2 = calcR2(C0(:,1), C_hat(:,1));
ev.c2R2 = calcR2(C0(:,2), C_hat(:,2));
ev.jointEV = calcJointEV(C0, C_hat);

Xi = [ones(size(C0,1),1), C0] \ P0;
P_hat = [ones(size(C0,1),1), C0] * Xi;
ev.invR2_p1 = calcR2(P0(:,1), P_hat(:,1));
ev.invR2_p2 = calcR2(P0(:,2), P_hat(:,2));

M_native = C0 * V2';
M_pair = C_hat * V2';

nf = froErr(M0, M_native);
pf = froErr(M0, M_pair);
ev.nativeFro = nf;
ev.pairFro = pf;
if isfinite(nf) && nf > 0
    ev.excessRatio = (pf - nf) / nf;
end

Pc = P0 - mean(P0,1,'omitnan');
Cc = C0 - mean(C0,1,'omitnan');
Qp = orth(Pc); Qc = orth(Cc);
if ~isempty(Qp) && ~isempty(Qc)
    s = svd(Qp' * Qc);
    s = max(min(s,1),-1);
    ang = acosd(s);
    if numel(ang)>=1, ev.angle1 = ang(1); end
    if numel(ang)>=2, ev.angle2 = ang(2); end
    ev.spanOverlap = mean(s, 'omitnan');
end

MpairFull = NaN(size(M));
MpairFull(v,:) = M_pair;
ev.M_pair_recon = MpairFull;
ev.n_points = nnz(v);
end


function r = froErr(A, B)
v = isfinite(A) & isfinite(B);
if nnz(v) < 3
    r = NaN; return;
end
a = A(v); b = B(v);
denom = norm(a, 'fro');
if denom <= 0
    r = NaN; return;
end
r = norm(a-b, 'fro') / denom;
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


function row = initSummaryRow()
row = struct();
row.candidate_name = "";
row.category = "";
row.description = "";
row.source = "";
row.n_full = NaN;
row.corr_c1_full = NaN;
row.corr_c2_full = NaN;
row.R2_c1_full = NaN;
row.R2_c2_full = NaN;
row.n_robust = NaN;
row.corr_c1_robust = NaN;
row.corr_c2_robust = NaN;
row.R2_c1_robust = NaN;
row.R2_c2_robust = NaN;
end


function row = initPairRow()
row = struct();
row.subset = "";
row.pair_name = "";
row.candidate = "";
row.category = "";
row.n_points = NaN;
row.c1_explained_var = NaN;
row.c2_explained_var = NaN;
row.joint_coeff_explained_var = NaN;
row.inverse_R2_Ipeak = NaN;
row.inverse_R2_candidate = NaN;
row.native_rank2_fro_error = NaN;
row.map_fro_error = NaN;
row.excess_error_ratio = NaN;
end


function row = mkPairRow(subsetName, pairName, cand, ev)
row = initPairRow();
row.subset = string(subsetName);
row.pair_name = string(pairName);
row.candidate = cand.name;
row.category = cand.category;
row.n_points = ev.n_points;
row.c1_explained_var = ev.c1R2;
row.c2_explained_var = ev.c2R2;
row.joint_coeff_explained_var = ev.jointEV;
row.inverse_R2_Ipeak = ev.invR2_p1;
row.inverse_R2_candidate = ev.invR2_p2;
row.native_rank2_fro_error = ev.nativeFro;
row.map_fro_error = ev.pairFro;
row.excess_error_ratio = ev.excessRatio;
end


function row = initGeoRow()
row = struct();
row.subset = "";
row.pair_name = "";
row.candidate = "";
row.category = "";
row.n_points = NaN;
row.principal_angle1_deg = NaN;
row.principal_angle2_deg = NaN;
row.span_overlap_mean_cos = NaN;
end


function row = mkGeoRow(subsetName, pairName, cand, ev)
row = initGeoRow();
row.subset = string(subsetName);
row.pair_name = string(pairName);
row.candidate = cand.name;
row.category = cand.category;
row.n_points = ev.n_points;
row.principal_angle1_deg = ev.angle1;
row.principal_angle2_deg = ev.angle2;
row.span_overlap_mean_cos = ev.spanOverlap;
end


function plotScatterWithFit(ax, x, y, T, xlbl, ylbl, ttl)
v = isfinite(x) & isfinite(y) & isfinite(T);
scatter(ax, x(v), y(v), 50, T(v), 'filled');
hold(ax, 'on');
if nnz(v) >= 3
    X = [ones(nnz(v),1), x(v)];
    b = X \ y(v);
    xg = linspace(min(x(v)), max(x(v)), 200)';
    yg = [ones(numel(xg),1), xg] * b;
    plot(ax, xg, yg, '-', 'LineWidth', 2);
end
xlabel(ax, xlbl); ylabel(ax, ylbl); title(ax, ttl); grid(ax, 'on');
cb = colorbar(ax); ylabel(cb, 'T (K)');
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
    if isfinite(lim) && lim > 0
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

