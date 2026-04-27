function run_aging_Q006_S2c_map_native_matrix_export()
% Q006-S2c: export consolidated map-native matrix using approved S2b policy:
% NEAREST_NEIGHBOR_TOLERANCE_x0.25 (no interpolation, no smoothing, no normalization).

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

outMatrix = fullfile(tablesDir, 'aging_Q006_S2c_map_native_matrix.csv');
outRows = fullfile(tablesDir, 'aging_Q006_S2c_map_native_rows.csv');
outTAxis = fullfile(tablesDir, 'aging_Q006_S2c_map_native_T_axis.csv');
outDiag = fullfile(tablesDir, 'aging_Q006_S2c_alignment_diagnostics.csv');
outVal = fullfile(tablesDir, 'aging_Q006_S2c_export_validation.csv');
outReport = fullfile(reportsDir, 'aging_Q006_S2c_map_native_matrix_export.md');

tpCore = [18;22;26;30];
twCore = [360;3600];
rowPlan = [18 360;18 3600;22 360;22 3600;26 360;26 3600;30 360;30 3600];
policyName = "NEAREST_NEIGHBOR_TOLERANCE_x0.25";

statusCsv = fullfile(tablesDir, 'aging_Tp_tw_export_run_status.csv');
s2bDecisionCsv = fullfile(tablesDir, 'aging_Q006_S2b_grid_policy_decision.csv');
s2bMetricsCsv = fullfile(tablesDir, 'aging_Q006_S2b_grid_alignment_metrics.csv');
assert(exist(statusCsv,'file')==2, 'Missing status CSV: %s', statusCsv);
assert(exist(s2bDecisionCsv,'file')==2, 'Missing S2b decision CSV: %s', s2bDecisionCsv);
assert(exist(s2bMetricsCsv,'file')==2, 'Missing S2b metrics CSV: %s', s2bMetricsCsv);

dec = readtable(s2bDecisionCsv, 'TextType','string', 'VariableNamingRule','preserve');
assert(height(dec) >= 1, 'Empty S2b decision table');
assert(string(dec.RECOMMENDED_POLICY(1)) == policyName, ...
    'S2b recommended policy changed (expected %s, got %s).', policyName, string(dec.RECOMMENDED_POLICY(1)));
assert(strcmpi(string(dec.READY_FOR_S2_MATRIX_EXPORT_WITH_POLICY(1)), "YES"), ...
    'S2b did not approve S2 matrix export');

met = readtable(s2bMetricsCsv, 'TextType','string', 'VariableNamingRule','preserve');
sel = met(string(met.policy) == policyName, :);
assert(~isempty(sel), 'Missing S2b metrics row for %s', policyName);
s2bCols = double(sel.n_tscan_columns(1));
s2bMaxDisp = double(sel.max_tscan_displacement(1));
s2bMedDisp = double(sel.median_tscan_displacement(1));

statusTxt = fileread(statusCsv);
runDirByTp = containers.Map('KeyType','double','ValueType','char');
for i = 1:numel(tpCore)
    tp = tpCore(i);
    pat = sprintf('TP_%d,[^\\r\\n]*?,YES,YES,([^,\\r\\n]+)', tp);
    tok = regexp(statusTxt, pat, 'tokens', 'once');
    if isempty(tok)
        continue;
    end
    runDirByTp(tp) = strtrim(tok{1});
end

MAP_NATIVE_MATRIX_EXPORTED = false;
ALL_TP_FOUND = all(isKey(runDirByTp, num2cell(tpCore)));
ALL_TW_FOUND = true;
ALL_8_ROWS_RETAINED = false;
USED_NEAREST_NEIGHBOR = true;
USED_INTERPOLATION = false;
USED_NORMALIZATION = false;
USED_CENTERING = false;
USED_SMOOTHING = false;
USED_SIGN_FLIP = false;
SIGN_PRESERVED = false;
SHAPE_PRESERVED = false;
EXCLUDED_T_USED = false;
TP34_USED = false;
READY_FOR_MAP_NATIVE_SVD = "NO";
BLOCKER = "EXPORT_FAILED";

rowsOut = table((1:8)', rowPlan(:,1), rowPlan(:,2), repmat("",8,1), repmat("",8,1), repmat("NO",8,1), repmat("NO",8,1), repmat("NO",8,1), ...
    'VariableNames', {'row_index','Tp','tw','source_run_dir','deltaM_column_name','tp_found','tw_found','cell_extracted'});

if ALL_TP_FOUND
    curves = repmat(struct('Tp',NaN,'tw',NaN,'run_dir',"",'col_name',"",'T',[],'Y',[]), 8, 1);
    for r = 1:8
        tp = rowPlan(r,1); tw = rowPlan(r,2);
        runDir = runDirByTp(tp);
        mapPath = fullfile(runDir, 'tables', 'DeltaM_map.csv');
        tAxisPath = fullfile(runDir, 'tables', 'T_axis.csv');
        twAxisPath = fullfile(runDir, 'tables', 'tw_axis.csv');
        if exist(mapPath,'file')~=2 || exist(tAxisPath,'file')~=2 || exist(twAxisPath,'file')~=2
            ALL_TP_FOUND = false;
            break;
        end

        mapTbl = readtable(mapPath, 'VariableNamingRule','preserve');
        tTbl = readtable(tAxisPath, 'VariableNamingRule','preserve');
        twTbl = readtable(twAxisPath, 'VariableNamingRule','preserve');
        twVals = double(twTbl.tw_seconds);
        j = find(abs(twVals - tw) < 1e-9, 1, 'first');
        if isempty(j)
            ALL_TW_FOUND = false;
        else
            col = string(mapTbl.Properties.VariableNames{j});
            y = double(mapTbl{:, j});
            t = double(tTbl.T_K);
            curves(r).Tp = tp;
            curves(r).tw = tw;
            curves(r).run_dir = string(runDir);
            curves(r).col_name = col;
            curves(r).T = t(:);
            curves(r).Y = y(:);

            rowsOut.source_run_dir(r) = string(runDir);
            rowsOut.deltaM_column_name(r) = col;
            rowsOut.tp_found(r) = "YES";
            rowsOut.tw_found(r) = "YES";
        end
    end

    if ~ALL_TW_FOUND
        BLOCKER = "MISSING_REQUIRED_TW";
    elseif ~ALL_TP_FOUND
        BLOCKER = "MISSING_PER_TP_MAP_ARTIFACTS";
    else
        % Reproduce S2b NN tolerance policy.
        allDt = [];
        for r = 1:8
            dt = diff(curves(r).T);
            dt = dt(isfinite(dt) & dt > 0);
            allDt = [allDt; dt(:)]; %#ok<AGROW>
        end
        nativeDtMedian = median(allDt, 'omitnan');
        tol = 0.25 * nativeDtMedian;

        tMins = arrayfun(@(c) min(c.T), curves);
        tMaxs = arrayfun(@(c) max(c.T), curves);
        tOverlapMin = max(tMins);
        tOverlapMax = min(tMaxs);
        tUnion = unique(sort(vertcat(curves.T)));
        tUnion = tUnion(tUnion >= tOverlapMin & tUnion <= tOverlapMax);

        keep = false(size(tUnion));
        for i = 1:numel(tUnion)
            t0 = tUnion(i);
            ok = true;
            for r = 1:8
                if min(abs(curves(r).T - t0)) > tol
                    ok = false; break
                end
            end
            keep(i) = ok;
        end
        tGrid = tUnion(keep);
        N_TSCAN_COLUMNS = numel(tGrid);

        X = nan(8, N_TSCAN_COLUMNS);
        dispAll = nan(8, N_TSCAN_COLUMNS);
        maxErr = nan(8,1);
        medErr = nan(8,1);
        corrVal = nan(8,1);
        shapeOk = false(8,1);
        signOk = false(8,1);

        for r = 1:8
            T = curves(r).T;
            Y = curves(r).Y;
            yG = nan(N_TSCAN_COLUMNS,1);
            dG = nan(N_TSCAN_COLUMNS,1);
            for j = 1:N_TSCAN_COLUMNS
                [dmin, idx] = min(abs(T - tGrid(j)));
                if dmin <= tol
                    yG(j) = Y(idx);
                    dG(j) = dmin;
                end
            end
            X(r,:) = yG(:).';
            dispAll(r,:) = dG(:).';

            % shape/sign preservation checks (native-point back-check).
            yNative = interp1(tGrid, yG, T, 'linear', NaN);
            valid = isfinite(yNative) & isfinite(Y);
            if nnz(valid) >= 10
                ae = abs(yNative(valid) - Y(valid));
                maxErr(r) = max(ae);
                medErr(r) = median(ae);
                corrVal(r) = corr(yNative(valid), Y(valid), 'Type','Pearson','Rows','complete');
                scale = max(abs(Y(valid)));
                relMax = maxErr(r) / max(scale, eps);
                shapeOk(r) = isfinite(corrVal(r)) && corrVal(r) > 0.995 && relMax < 0.10;
                signOk(r) = sign(min(yNative(valid))) == sign(min(Y(valid))) && sign(max(yNative(valid))) == sign(max(Y(valid)));
            end

            if all(isfinite(yG))
                rowsOut.cell_extracted(r) = "YES";
            end
        end

        missingVals = any(~isfinite(X), 'all');
        ALL_8_ROWS_RETAINED = all(rowsOut.cell_extracted == "YES");
        MAX_TSCAN_DISPLACEMENT = max(dispAll, [], 'all', 'omitnan');
        MEDIAN_TSCAN_DISPLACEMENT = median(dispAll, 'all', 'omitnan');
        SIGN_PRESERVED = all(signOk);
        SHAPE_PRESERVED = all(shapeOk);

        % policy reproduction check
        % Allow tiny numeric drift in displacement aggregation while enforcing same policy behavior.
        reproTolMax = max(1e-9, 2e-6 * max(abs([s2bMaxDisp, MAX_TSCAN_DISPLACEMENT, 1])));
        reproTolMed = max(2e-6, 2e-6 * max(abs([s2bMedDisp, MEDIAN_TSCAN_DISPLACEMENT, 1])));
        policyReproOk = (N_TSCAN_COLUMNS == s2bCols) && ...
                        (abs(MAX_TSCAN_DISPLACEMENT - s2bMaxDisp) <= reproTolMax) && ...
                        (abs(MEDIAN_TSCAN_DISPLACEMENT - s2bMedDisp) <= reproTolMed);

        if ~policyReproOk
            BLOCKER = "POLICY_REPRODUCTION_FAILED";
        elseif missingVals
            BLOCKER = "EXPORT_FAILED";
        elseif ~SIGN_PRESERVED || ~SHAPE_PRESERVED
            BLOCKER = "INVALID_SIGN_OR_SHAPE_PRESERVATION";
        else
            MAP_NATIVE_MATRIX_EXPORTED = true;
            BLOCKER = "";
        end

        % Always write the produced matrix/axis/diagnostics from this policy execution.
        tOut = table(tGrid, 'VariableNames', {'T_K'});
        writetable(tOut, outTAxis);

        rowId = strings(8,1);
        srcRun = strings(8,1);
        srcCol = strings(8,1);
        for r = 1:8
            rowId(r) = "Tp" + string(rowPlan(r,1)) + "_tw" + string(rowPlan(r,2));
            srcRun(r) = curves(r).run_dir;
            srcCol(r) = curves(r).col_name;
        end
        mOut = table(rowId, rowPlan(:,1), rowPlan(:,2), srcRun, srcCol, ...
            'VariableNames', {'row_id','Tp','tw','source_run_dir','source_deltaM_column'});
        for c = 1:N_TSCAN_COLUMNS
            vn = matlab.lang.makeValidName(sprintf('T_%0.6fK', tGrid(c)));
            mOut.(vn) = X(:, c);
        end
        writetable(mOut, outMatrix);

        diagTbl = table((1:8)', rowPlan(:,1), rowPlan(:,2), max(dispAll,[],2,'omitnan'), median(dispAll,2,'omitnan'), ...
            maxErr, medErr, corrVal, shapeOk, signOk, ...
            'VariableNames', {'row_index','Tp','tw','max_tscan_displacement','median_tscan_displacement', ...
            'max_abs_error','median_abs_error','pearson_correlation','shape_preserved','sign_preserved'});
        writetable(diagTbl, outDiag);
    end
else
    BLOCKER = "MISSING_PER_TP_MAP_ARTIFACTS";
    N_TSCAN_COLUMNS = 0;
    MAX_TSCAN_DISPLACEMENT = NaN;
    MEDIAN_TSCAN_DISPLACEMENT = NaN;
end

% Excluded temperature usage checks.
usedTp = unique(rowPlan(:,1));
EXCLUDED_T_USED = any(ismember(usedTp, [6 10 14]));
TP34_USED = any(usedTp == 34);

N_ROWS = 8;
if MAP_NATIVE_MATRIX_EXPORTED && ALL_8_ROWS_RETAINED && ALL_TP_FOUND && ALL_TW_FOUND && ...
        USED_NEAREST_NEIGHBOR && ~USED_INTERPOLATION && ~USED_NORMALIZATION && ...
        ~USED_CENTERING && ~USED_SMOOTHING && ~USED_SIGN_FLIP && SIGN_PRESERVED && ...
        SHAPE_PRESERVED && ~EXCLUDED_T_USED && ~TP34_USED
    READY_FOR_MAP_NATIVE_SVD = "YES";
    finalDecision = "READY_FOR_MAP_NATIVE_SVD";
else
    if BLOCKER == ""
        BLOCKER = "EXPORT_FAILED";
    end
    finalDecision = string(BLOCKER);
end

% Ensure required files exist even on failure.
writetable(rowsOut, outRows);
if exist(outTAxis,'file') ~= 2
    writetable(table([], 'VariableNames', {'T_K'}), outTAxis);
end
if exist(outMatrix,'file') ~= 2
    writetable(table(strings(0,1), zeros(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', {'row_id','Tp','tw','source_run_dir','source_deltaM_column'}), outMatrix);
end
if exist(outDiag,'file') ~= 2
    writetable(table(zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), false(0,1), false(0,1), ...
        'VariableNames', {'row_index','Tp','tw','max_tscan_displacement','median_tscan_displacement', ...
        'max_abs_error','median_abs_error','pearson_correlation','shape_preserved','sign_preserved'}), outDiag);
end

valTbl = table(string(MAP_NATIVE_MATRIX_EXPORTED), string(policyName), N_ROWS, N_TSCAN_COLUMNS, ...
    string(ALL_8_ROWS_RETAINED), string(ALL_TP_FOUND), string(ALL_TW_FOUND), ...
    string(USED_NEAREST_NEIGHBOR), string(USED_INTERPOLATION), string(USED_NORMALIZATION), ...
    string(USED_CENTERING), string(USED_SMOOTHING), string(USED_SIGN_FLIP), ...
    MAX_TSCAN_DISPLACEMENT, MEDIAN_TSCAN_DISPLACEMENT, string(SIGN_PRESERVED), string(SHAPE_PRESERVED), ...
    string(EXCLUDED_T_USED), string(TP34_USED), string(READY_FOR_MAP_NATIVE_SVD), string(BLOCKER), string(finalDecision), ...
    'VariableNames', {'MAP_NATIVE_MATRIX_EXPORTED','GRID_POLICY_USED','N_ROWS','N_TSCAN_COLUMNS', ...
    'ALL_8_ROWS_RETAINED','ALL_TP_FOUND','ALL_TW_FOUND','USED_NEAREST_NEIGHBOR','USED_INTERPOLATION', ...
    'USED_NORMALIZATION','USED_CENTERING','USED_SMOOTHING','USED_SIGN_FLIP','MAX_TSCAN_DISPLACEMENT', ...
    'MEDIAN_TSCAN_DISPLACEMENT','SIGN_PRESERVED','SHAPE_PRESERVED','EXCLUDED_T_USED','TP34_USED', ...
    'READY_FOR_MAP_NATIVE_SVD','BLOCKER','FINAL_DECISION'});
writetable(valTbl, outVal);

% report
lines = strings(0,1);
lines(end+1) = "# Q006-S2c map-native matrix export"; %#ok<AGROW>
lines(end+1) = "";
lines(end+1) = "Exported using fixed approved policy from S2b.";
lines(end+1) = "";
lines(end+1) = "## Policy";
lines(end+1) = "- GRID_POLICY_USED: " + policyName;
lines(end+1) = "- interpolation: NO";
lines(end+1) = "- nearest-neighbor: YES";
lines(end+1) = "- smoothing: NO";
lines(end+1) = "- normalization: NO";
lines(end+1) = "- centering: NO";
lines(end+1) = "- sign flip: NO";
lines(end+1) = "";
lines(end+1) = "## Source folders";
for i = 1:numel(tpCore)
    if isKey(runDirByTp, tpCore(i))
        lines(end+1) = "- Tp " + string(tpCore(i)) + ": " + string(runDirByTp(tpCore(i))); %#ok<AGROW>
    end
end
lines(end+1) = "";
lines(end+1) = "## Dimensions and diagnostics";
lines(end+1) = sprintf("- N_ROWS: %d", N_ROWS);
lines(end+1) = sprintf("- N_TSCAN_COLUMNS: %d", N_TSCAN_COLUMNS);
lines(end+1) = sprintf("- MAX_TSCAN_DISPLACEMENT: %.12g", MAX_TSCAN_DISPLACEMENT);
lines(end+1) = sprintf("- MEDIAN_TSCAN_DISPLACEMENT: %.12g", MEDIAN_TSCAN_DISPLACEMENT);
lines(end+1) = "";
lines(end+1) = "## Verdict";
lines(end+1) = "- FINAL_DECISION: " + string(finalDecision);
lines(end+1) = "- READY_FOR_MAP_NATIVE_SVD: " + string(READY_FOR_MAP_NATIVE_SVD);
lines(end+1) = "- BLOCKER: " + string(BLOCKER);
lines(end+1) = "";
lines(end+1) = "## Outputs";
lines(end+1) = "- " + string(outMatrix);
lines(end+1) = "- " + string(outRows);
lines(end+1) = "- " + string(outTAxis);
lines(end+1) = "- " + string(outDiag);
lines(end+1) = "- " + string(outVal);

fid = fopen(outReport, 'w');
assert(fid >= 0, 'Could not write report');
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines(i));
end
fclose(fid);

fprintf('Q006-S2c export complete: %s\n', finalDecision);
end
