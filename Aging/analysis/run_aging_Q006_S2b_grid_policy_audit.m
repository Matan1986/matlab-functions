function run_aging_Q006_S2b_grid_policy_audit()
% Q006-S2b grid-alignment policy audit for map-native SVD readiness.
% No SVD, no mechanism analysis, no final matrix export.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
figDir = fullfile(repoRoot, 'figures', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
if exist(figDir, 'dir') ~= 7, mkdir(figDir); end

outCandidates = fullfile(tablesDir, 'aging_Q006_S2b_grid_policy_candidates.csv');
outMetrics = fullfile(tablesDir, 'aging_Q006_S2b_grid_alignment_metrics.csv');
outShape = fullfile(tablesDir, 'aging_Q006_S2b_shape_preservation.csv');
outDecision = fullfile(tablesDir, 'aging_Q006_S2b_grid_policy_decision.csv');
outReport = fullfile(reportsDir, 'aging_Q006_S2b_grid_alignment_policy_audit.md');

tpCore = [18;22;26;30];
twCore = [360;3600];
rowPlan = [18 360;18 3600;22 360;22 3600;26 360;26 3600;30 360;30 3600];

statusCsv = fullfile(tablesDir, 'aging_Tp_tw_export_run_status.csv');
assert(exist(statusCsv, 'file') == 2, 'Missing status CSV: %s', statusCsv);
stTxt = fileread(statusCsv);

% Resolve run directories by TP from status CSV text (robust to BOM/header parse issues).
runDirByTp = containers.Map('KeyType','double','ValueType','char');
for i = 1:numel(tpCore)
    tp = tpCore(i);
    pat = sprintf('TP_%d,[^\\r\\n]*?,YES,YES,([^,\\r\\n]+)', tp);
    tok = regexp(stTxt, pat, 'tokens', 'once');
    assert(~isempty(tok), 'Could not resolve run dir for Tp=%d', tp);
    runDirByTp(tp) = strtrim(tok{1});
end

% Load 8 core curves from per-TP DeltaM maps.
curves = repmat(struct('Tp',NaN,'tw',NaN,'run_dir',"",'col_name',"",'T',[],'Y',[]), size(rowPlan,1), 1);
for r = 1:size(rowPlan,1)
    tp = rowPlan(r,1); tw = rowPlan(r,2);
    runDir = runDirByTp(tp);
    mapPath = fullfile(runDir, 'tables', 'DeltaM_map.csv');
    tAxisPath = fullfile(runDir, 'tables', 'T_axis.csv');
    twAxisPath = fullfile(runDir, 'tables', 'tw_axis.csv');
    assert(exist(mapPath,'file')==2 && exist(tAxisPath,'file')==2 && exist(twAxisPath,'file')==2, ...
        'Missing per-TP map artifacts for Tp=%d', tp);

    mapTbl = readtable(mapPath, 'VariableNamingRule','preserve');
    tTbl = readtable(tAxisPath, 'VariableNamingRule','preserve');
    twTbl = readtable(twAxisPath, 'VariableNamingRule','preserve');
    twVals = double(twTbl.tw_seconds);
    j = find(abs(twVals - tw) < 1e-9, 1, 'first');
    assert(~isempty(j), 'Missing tw=%g in Tp=%g tw_axis', tw, tp);
    col = string(mapTbl.Properties.VariableNames{j});
    y = double(mapTbl{:, j});
    t = double(tTbl.T_K);
    assert(numel(t)==numel(y) && all(isfinite(t)) && all(isfinite(y)), 'Non-finite map data at Tp=%g tw=%g', tp, tw);

    curves(r).Tp = tp;
    curves(r).tw = tw;
    curves(r).run_dir = string(runDir);
    curves(r).col_name = col;
    curves(r).T = t(:);
    curves(r).Y = y(:);
end

% Shared overlap bounds across all 8 curves.
tMins = arrayfun(@(c) min(c.T), curves);
tMaxs = arrayfun(@(c) max(c.T), curves);
tOverlapMin = max(tMins);
tOverlapMax = min(tMaxs);
assert(tOverlapMax > tOverlapMin, 'No overlapping T range across core curves.');

% Typical native spacing.
allDt = [];
for r = 1:numel(curves)
    dt = diff(curves(r).T);
    dt = dt(isfinite(dt) & dt > 0);
    allDt = [allDt; dt(:)]; %#ok<AGROW>
end
nativeDtMedian = median(allDt, 'omitnan');
nativeDtMax = max(allDt);

candRows = table();
metricRows = table();
shapeRows = table();

% ---------- Policy 1: EXACT_INTERSECTION ----------
sharedExact = curves(1).T;
for r = 2:numel(curves)
    sharedExact = intersect(sharedExact, curves(r).T, 'stable');
end
nColsExact = numel(sharedExact);

[mRowExact, sRowsExact] = evaluatePolicy('EXACT_INTERSECTION', sharedExact, curves, false, false, 0);
candRows = [candRows; mRowExact]; %#ok<AGROW>
metricRows = [metricRows; mRowExact]; %#ok<AGROW>
shapeRows = [shapeRows; sRowsExact]; %#ok<AGROW>

% ---------- Policy 2: COMMON_UNIFORM_GRID_INTERPOLATION ----------
nUniform = 120; % conservative test grid size
tUniform = linspace(tOverlapMin, tOverlapMax, nUniform).';
[mRowUni, sRowsUni] = evaluatePolicy('COMMON_UNIFORM_GRID_INTERPOLATION_N120', tUniform, curves, true, false, 0);
candRows = [candRows; mRowUni]; %#ok<AGROW>
metricRows = [metricRows; mRowUni]; %#ok<AGROW>
shapeRows = [shapeRows; sRowsUni]; %#ok<AGROW>

% ---------- Policy 3: NEAREST_NEIGHBOR_TOLERANCE ----------
tUnion = unique(sort(vertcat(curves.T)));
tUnion = tUnion(tUnion >= tOverlapMin & tUnion <= tOverlapMax);
tolMult = [0.25; 0.5; 1.0];
for k = 1:numel(tolMult)
    tol = tolMult(k) * nativeDtMedian;
    tNN = filterNNCompleteColumns(tUnion, curves, tol);
    tag = sprintf('NEAREST_NEIGHBOR_TOLERANCE_x%.2g', tolMult(k));
    [mRowNN, sRowsNN] = evaluatePolicy(tag, tNN, curves, false, true, tol);
    candRows = [candRows; mRowNN]; %#ok<AGROW>
    metricRows = [metricRows; mRowNN]; %#ok<AGROW>
    shapeRows = [shapeRows; sRowsNN]; %#ok<AGROW>
end

% ---------- Policy 4: ABORT ----------
mAbort = table("ABORT_MAP_NATIVE_SVD", tOverlapMin, tOverlapMax, 0, true, false, false, false, false, false, false, ...
    NaN, NaN, true, false, false, false, ...
    'VariableNames', {'policy','overlap_t_min','overlap_t_max','n_tscan_columns','all_8_rows_retained', ...
    'interpolation_used','nearest_neighbor_used','smoothing_used','normalization_used','centering_used','sign_flip_used', ...
    'max_tscan_displacement','median_tscan_displacement','missing_values_introduced','sign_preserved','shape_preserved','acceptable_for_svd'});
candRows = [candRows; mAbort]; %#ok<AGROW>
metricRows = [metricRows; mAbort]; %#ok<AGROW>

% choose recommendation by rules
ok = metricRows.all_8_rows_retained & metricRows.n_tscan_columns >= 10 & ...
     ~metricRows.sign_flip_used & ~metricRows.smoothing_used & ...
     ~metricRows.normalization_used & metricRows.sign_preserved & metricRows.shape_preserved;

reco = "";
if any(ok)
    % Prefer non-interpolative among acceptable, else highest columns.
    idx = find(ok);
    sub = metricRows(idx,:);
    score = double(~sub.interpolation_used) * 1e6 + sub.n_tscan_columns;
    [~, ib] = max(score);
    reco = string(sub.policy(ib));
    gridDecision = "RECOMMEND_POLICY";
    readyS2 = "YES";
    readyMap = "YES";
else
    % If at least one policy has >=10 cols but shape/sign uncertain => manual.
    if any(metricRows.n_tscan_columns >= 10)
        gridDecision = "NEEDS_MANUAL_GRID_POLICY_DECISION";
    else
        gridDecision = "ABORT_MAP_NATIVE_SVD_FOR_NOW";
    end
    reco = "ABORT_MAP_NATIVE_SVD";
    readyS2 = "NO";
    readyMap = "NO";
end

exactFailed = nColsExact == 0;
interpAllowed = any(contains(metricRows.policy, "COMMON_UNIFORM_GRID_INTERPOLATION") & metricRows.acceptable_for_svd);
nnAllowed = any(contains(metricRows.policy, "NEAREST_NEIGHBOR_TOLERANCE") & metricRows.acceptable_for_svd);
nRecoCols = 0;
if gridDecision == "RECOMMEND_POLICY"
    rr = metricRows(metricRows.policy == reco, :);
    nRecoCols = rr.n_tscan_columns(1);
end

usedSmoothing = any(metricRows.smoothing_used);
usedNorm = any(metricRows.normalization_used);
tp34Used = false;
excludedUsed = false;
all8Retained = gridDecision == "RECOMMEND_POLICY";
shapePres = gridDecision == "RECOMMEND_POLICY";
signPres = gridDecision == "RECOMMEND_POLICY";

decisionTbl = table( ...
    string(gridDecision), string(reco), string(readyS2), string(exactFailed), ...
    string(interpAllowed), string(nnAllowed), string(all8Retained), nRecoCols, ...
    string(shapePres), string(signPres), string(usedSmoothing), string(usedNorm), ...
    string(tp34Used), string(excludedUsed), string(readyMap), ...
    'VariableNames', {'GRID_POLICY_DECISION','RECOMMENDED_POLICY','READY_FOR_S2_MATRIX_EXPORT_WITH_POLICY', ...
    'EXACT_INTERSECTION_FAILED','INTERPOLATION_ALLOWED','NEAREST_NEIGHBOR_ALLOWED','ALL_8_ROWS_RETAINED', ...
    'N_TSCAN_COLUMNS_RECOMMENDED','SHAPE_PRESERVED','SIGN_PRESERVED','USED_SMOOTHING','USED_NORMALIZATION', ...
    'TP34_USED','EXCLUDED_T_USED','READY_FOR_MAP_NATIVE_SVD'});

writetable(candRows, outCandidates);
writetable(metricRows, outMetrics);
writetable(shapeRows, outShape);
writetable(decisionTbl, outDecision);

% report
lines = strings(0,1);
lines(end+1) = "# Q006-S2b grid-alignment policy audit"; %#ok<AGROW>
lines(end+1) = "";
lines(end+1) = "Scope: policy audit only (no SVD, no mechanism analysis, no final SVD matrix export).";
lines(end+1) = "";
lines(end+1) = "## Core domain";
lines(end+1) = "- Tp: 18,22,26,30";
lines(end+1) = "- tw: 360,3600";
lines(end+1) = "- Rows planned: 8";
lines(end+1) = "";
lines(end+1) = "## Why exact intersection failed";
lines(end+1) = sprintf("- Exact shared Tscan column count: %d", nColsExact);
lines(end+1) = "- Per-Tp T_axis grids are close but not exactly equal, so strict set intersection is empty.";
lines(end+1) = sprintf("- Overlap range exists: [%.6f, %.6f] K", tOverlapMin, tOverlapMax);
lines(end+1) = "";
lines(end+1) = "## Policies evaluated";
for i = 1:height(metricRows)
    lines(end+1) = sprintf("- %s: cols=%d, rows_retained=%s, acceptable=%s", ...
        string(metricRows.policy(i)), metricRows.n_tscan_columns(i), ...
        tf(metricRows.all_8_rows_retained(i)), tf(metricRows.acceptable_for_svd(i))); %#ok<AGROW>
end
lines(end+1) = "";
lines(end+1) = "## Recommendation";
lines(end+1) = sprintf("- GRID_POLICY_DECISION: %s", string(decisionTbl.GRID_POLICY_DECISION(1)));
lines(end+1) = sprintf("- RECOMMENDED_POLICY: %s", string(decisionTbl.RECOMMENDED_POLICY(1)));
lines(end+1) = sprintf("- N_TSCAN_COLUMNS_RECOMMENDED: %d", decisionTbl.N_TSCAN_COLUMNS_RECOMMENDED(1));
lines(end+1) = sprintf("- INTERPOLATION_ALLOWED: %s", string(decisionTbl.INTERPOLATION_ALLOWED(1)));
lines(end+1) = sprintf("- NEAREST_NEIGHBOR_ALLOWED: %s", string(decisionTbl.NEAREST_NEIGHBOR_ALLOWED(1)));
lines(end+1) = sprintf("- SHAPE_PRESERVED: %s", string(decisionTbl.SHAPE_PRESERVED(1)));
lines(end+1) = sprintf("- SIGN_PRESERVED: %s", string(decisionTbl.SIGN_PRESERVED(1)));
lines(end+1) = sprintf("- READY_FOR_S2_MATRIX_EXPORT_WITH_POLICY: %s", string(decisionTbl.READY_FOR_S2_MATRIX_EXPORT_WITH_POLICY(1)));
lines(end+1) = sprintf("- READY_FOR_MAP_NATIVE_SVD: %s", string(decisionTbl.READY_FOR_MAP_NATIVE_SVD(1)));
lines(end+1) = "";
lines(end+1) = "## Artifacts";
lines(end+1) = "- tables/aging/aging_Q006_S2b_grid_policy_candidates.csv";
lines(end+1) = "- tables/aging/aging_Q006_S2b_grid_alignment_metrics.csv";
lines(end+1) = "- tables/aging/aging_Q006_S2b_shape_preservation.csv";
lines(end+1) = "- tables/aging/aging_Q006_S2b_grid_policy_decision.csv";

fid = fopen(outReport, 'w');
assert(fid >= 0, 'Could not write report');
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines(i));
end
fclose(fid);

fprintf('Q006-S2b audit complete: %s\n', string(decisionTbl.GRID_POLICY_DECISION(1)));
end

function tOut = filterNNCompleteColumns(tCandidate, curves, tol)
maskKeep = false(size(tCandidate));
for i = 1:numel(tCandidate)
    t0 = tCandidate(i);
    ok = true;
    for r = 1:numel(curves)
        d = abs(curves(r).T - t0);
        if min(d) > tol
            ok = false;
            break
        end
    end
    maskKeep(i) = ok;
end
tOut = tCandidate(maskKeep);
end

function [mRow, sRows] = evaluatePolicy(policyName, tGrid, curves, useInterp, useNN, tol)
nRows = numel(curves);
nCols = numel(tGrid);
Yg = nan(nRows, nCols);
dispMax = nan(nRows,1);
dispMed = nan(nRows,1);
missing = false;
signPres = true;
shapePres = true;
sRows = table();

for r = 1:nRows
    T = curves(r).T;
    Y = curves(r).Y;
    if nCols == 0
        missing = true;
        dispMax(r) = NaN;
        dispMed(r) = NaN;
        sRows = [sRows; shapeRow(policyName, curves(r).Tp, curves(r).tw, NaN, NaN, NaN, false, false, false)]; %#ok<AGROW>
        continue
    end

    if useInterp
        Ygi = interp1(T, Y, tGrid, 'linear', NaN);
        Yg(r,:) = Ygi(:).';
        disp = zeros(size(tGrid));
    elseif useNN
        Ygi = nan(size(tGrid));
        disp = nan(size(tGrid));
        for j = 1:nCols
            [dmin, idx] = min(abs(T - tGrid(j)));
            if dmin <= tol
                Ygi(j) = Y(idx);
                disp(j) = dmin;
            end
        end
        Yg(r,:) = Ygi(:).';
    else
        [tf, ia, ib] = intersect(tGrid, T, 'stable');
        Ygi = nan(size(tGrid));
        Ygi(ia) = Y(ib);
        Yg(r,:) = Ygi(:).';
        disp = zeros(size(tGrid));
        disp(~ismember(tGrid, tf)) = NaN;
    end

    if any(~isfinite(Yg(r,:)))
        missing = true;
    end
    dispMax(r) = max(disp, [], 'omitnan');
    dispMed(r) = median(disp, 'omitnan');

    % Shape preservation test where reconstruction is defined:
    if useInterp || useNN
        Yn = interp1(tGrid, Yg(r,:), T, 'linear', NaN);
    else
        Yn = Y; % exact sampling at original points
    end
    valid = isfinite(Y) & isfinite(Yn);
    if nnz(valid) >= 10
        absErr = abs(Yn(valid) - Y(valid));
        maxErr = max(absErr);
        medErr = median(absErr);
        c = corr(Yn(valid), Y(valid), 'Type','Pearson','Rows','complete');
        scale = max(abs(Y(valid)));
        relMax = maxErr / max(scale, eps);
        qShape = isfinite(c) && c > 0.995 && relMax < 0.10;
        sSign = sign(min(Yn(valid))) == sign(min(Y(valid))) && sign(max(Yn(valid))) == sign(max(Y(valid)));
        signPres = signPres && sSign;
        shapePres = shapePres && qShape;
        sRows = [sRows; shapeRow(policyName, curves(r).Tp, curves(r).tw, maxErr, medErr, c, qShape, sSign, false)]; %#ok<AGROW>
    else
        signPres = false;
        shapePres = false;
        sRows = [sRows; shapeRow(policyName, curves(r).Tp, curves(r).tw, NaN, NaN, NaN, false, false, true)]; %#ok<AGROW>
    end
end

all8 = nRows == 8;
accept = all8 && nCols >= 10 && ~missing && signPres && shapePres;
if isempty(tGrid)
    tMinPol = NaN;
    tMaxPol = NaN;
else
    tMinPol = min(tGrid);
    tMaxPol = max(tGrid);
end
mRow = table(string(policyName), tMinPol, tMaxPol, nCols, all8, ...
    useInterp, useNN, false, false, false, false, ...
    max(dispMax, [], 'omitnan'), median(dispMed, 'omitnan'), missing, signPres, shapePres, accept, ...
    'VariableNames', {'policy','overlap_t_min','overlap_t_max','n_tscan_columns','all_8_rows_retained', ...
    'interpolation_used','nearest_neighbor_used','smoothing_used','normalization_used','centering_used','sign_flip_used', ...
    'max_tscan_displacement','median_tscan_displacement','missing_values_introduced','sign_preserved','shape_preserved','acceptable_for_svd'});
end

function r = shapeRow(policy, tp, tw, maxErr, medErr, corrVal, qShape, sSign, insuff)
r = table(string(policy), tp, tw, maxErr, medErr, corrVal, qShape, sSign, insuff, ...
    'VariableNames', {'policy','Tp','tw','max_abs_error','median_abs_error','pearson_correlation', ...
    'qualitative_shape_preserved','sign_preserved','insufficient_points'});
end

function s = tf(v)
if v, s = 'YES'; else, s = 'NO'; end
end

