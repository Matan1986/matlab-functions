function run_aging_Q006_S2_map_native_matrix_export()
% Q006 S2: Export consolidated canonical map-native matrix for Q005b core.
% No SVD, no mechanism analysis, no observable-only columns.

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end

outMatrix = fullfile(tablesDir, 'aging_Q006_S2_map_native_matrix.csv');
outRows = fullfile(tablesDir, 'aging_Q006_S2_map_native_rows.csv');
outTAxis = fullfile(tablesDir, 'aging_Q006_S2_map_native_T_axis.csv');
outVal = fullfile(tablesDir, 'aging_Q006_S2_map_native_export_validation.csv');
outReport = fullfile(reportsDir, 'aging_Q006_S2_map_native_matrix_export.md');

statusCsv = fullfile(tablesDir, 'aging_Tp_tw_export_run_status.csv');
assert(exist(statusCsv, 'file') == 2, 'Missing export status: %s', statusCsv);
st = readtable(statusCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
st = stripBomVarNames(st);
if width(st) >= 14
    st.Properties.VariableNames(1:14) = { ...
        'target_id','dataset_folder','dataset_branch','Tp','tw_values_expected', ...
        'attempted','export_success','run_dir','observable_matrix_found','row_count', ...
        'tw_values_exported','failure_class','failure_message','notes'};
end

tpCore = [18; 22; 26; 30];
twCore = [360; 3600];
plannedRows = [
    18 360
    18 3600
    22 360
    22 3600
    26 360
    26 3600
    30 360
    30 3600
];

ALL_TP_FOUND = true;
ALL_TW_FOUND = true;
SHARED_T_AXIS_FOUND = false;
USED_INTERPOLATION = false;
USED_NORMALIZATION = false;
USED_CENTERING = false;
USED_SMOOTHING = false;
USED_SIGN_FLIP = false;
EXCLUDED_T_USED = false;
TP34_USED = false;
MAP_NATIVE_MATRIX_EXPORTED = false;
BLOCKER = "EXPORT_FAILED";
READY_FOR_MAP_NATIVE_SVD = "NO";

runDirs = strings(numel(tpCore), 1);
tpFound = false(numel(tpCore), 1);
for i = 1:numel(tpCore)
    tp = tpCore(i);
    targetIds = getColString(st, 'target_id');
    exportSuccess = getColString(st, 'export_success');
    key = "TP_" + string(tp);
    m = st(contains(strtrim(targetIds), key) & contains(strtrim(exportSuccess), "YES"), :);
    if ~isempty(m)
        runDirs(i) = m.run_dir(1);
        tpFound(i) = true;
    else
        txt = fileread(statusCsv);
        pat = sprintf('TP_%d,[^\\r\\n]*?,YES,YES,([^,\\r\\n]+)', tp);
        tok = regexp(txt, pat, 'tokens', 'once');
        if ~isempty(tok)
            runDirs(i) = string(strtrim(tok{1}));
            tpFound(i) = true;
        end
    end
end
ALL_TP_FOUND = all(tpFound);

rowsOut = table((1:size(plannedRows,1))', plannedRows(:,1), plannedRows(:,2), ...
    repmat("", size(plannedRows,1), 1), repmat("", size(plannedRows,1), 1), ...
    repmat("NO", size(plannedRows,1), 1), repmat("NO", size(plannedRows,1), 1), ...
    repmat("NO", size(plannedRows,1), 1), ...
    'VariableNames', {'row_index','Tp','tw','source_run_dir','deltaM_column_name','tp_found','tw_found','cell_extracted'});

Tsets = cell(numel(tpCore), 1);
mapTbls = cell(numel(tpCore), 1);
twAxisTbls = cell(numel(tpCore), 1);

if ALL_TP_FOUND
    for i = 1:numel(tpCore)
        runDir = char(runDirs(i));
        mapPath = fullfile(runDir, 'tables', 'DeltaM_map.csv');
        tAxisPath = fullfile(runDir, 'tables', 'T_axis.csv');
        twAxisPath = fullfile(runDir, 'tables', 'tw_axis.csv');
        if exist(mapPath, 'file') ~= 2 || exist(tAxisPath, 'file') ~= 2 || exist(twAxisPath, 'file') ~= 2
            ALL_TP_FOUND = false;
            break;
        end
        mapTbl = readtable(mapPath, 'VariableNamingRule', 'preserve');
        tAxis = readtable(tAxisPath, 'VariableNamingRule', 'preserve');
        twAxis = readtable(twAxisPath, 'VariableNamingRule', 'preserve');
        mapTbls{i} = mapTbl;
        twAxisTbls{i} = twAxis;
        Tsets{i} = double(tAxis.T_K);
    end
end

if ~ALL_TP_FOUND
    BLOCKER = "MISSING_PER_TP_MAP_ARTIFACTS";
else
    % Verify required tw for each Tp.
    for i = 1:numel(tpCore)
        twVals = double(twAxisTbls{i}.tw_seconds);
        if ~all(ismember(twCore, twVals))
            ALL_TW_FOUND = false;
        end
    end

    if ~ALL_TW_FOUND
        BLOCKER = "MISSING_REQUIRED_TW";
    else
        % Record source availability even if grid policy blocks export.
        for r = 1:size(plannedRows, 1)
            tp = plannedRows(r, 1);
            tw = plannedRows(r, 2);
            iTp = find(tpCore == tp, 1, 'first');
            rowsOut.source_run_dir(r) = runDirs(iTp);
            rowsOut.tp_found(r) = "YES";
            twVals = double(twAxisTbls{iTp}.tw_seconds);
            if any(abs(twVals - tw) < 1e-9)
                rowsOut.tw_found(r) = "YES";
                mapTbl = mapTbls{iTp};
                twRow = find(abs(twVals - tw) < 1e-9, 1, 'first');
                rowsOut.deltaM_column_name(r) = string(mapTbl.Properties.VariableNames{twRow});
            else
                rowsOut.tw_found(r) = "NO";
            end
        end

        % Exact shared T intersection only (no interpolation).
        sharedT = Tsets{1};
        for i = 2:numel(Tsets)
            sharedT = intersect(sharedT, Tsets{i}, 'stable');
        end
        SHARED_T_AXIS_FOUND = ~isempty(sharedT);

        minColsForShape = 50;
        if ~SHARED_T_AXIS_FOUND || numel(sharedT) < minColsForShape
            BLOCKER = "NEEDS_GRID_ALIGNMENT_POLICY";
        else
            % Build matrix with strict row order.
            X = nan(size(plannedRows, 1), numel(sharedT));
            srcRunCol = strings(size(plannedRows,1),1);
            srcDeltaCol = strings(size(plannedRows,1),1);

            for r = 1:size(plannedRows, 1)
                tp = plannedRows(r, 1);
                tw = plannedRows(r, 2);
                iTp = find(tpCore == tp, 1, 'first');
                runDir = runDirs(iTp);
                mapTbl = mapTbls{iTp};
                twAxis = twAxisTbls{iTp};
                tAxis = Tsets{iTp};

                rowMask = rowsOut.Tp == tp & rowsOut.tw == tw;
                rowsOut.source_run_dir(rowMask) = runDir;
                rowsOut.tp_found(rowMask) = "YES";

                twRow = find(abs(double(twAxis.tw_seconds) - tw) < 1e-9, 1, 'first');
                if isempty(twRow)
                    rowsOut.tw_found(rowMask) = "NO";
                    ALL_TW_FOUND = false;
                    continue;
                end
                rowsOut.tw_found(rowMask) = "YES";

                colName = string(mapTbl.Properties.VariableNames{twRow});
                srcDeltaCol(r) = colName;
                rowsOut.deltaM_column_name(rowMask) = colName;

                [~, ia, ib] = intersect(sharedT, tAxis, 'stable');
                dCol = double(mapTbl{ib, twRow});
                X(r, ia) = dCol;
                rowsOut.cell_extracted(rowMask) = "YES";
                srcRunCol(r) = runDir;
            end

            if any(~isfinite(X), 'all') || any(rowsOut.cell_extracted ~= "YES")
                BLOCKER = "EXPORT_FAILED";
            else
                tOut = table(sharedT, 'VariableNames', {'T_K'});
                writetable(tOut, outTAxis);

                rowId = strings(size(plannedRows,1),1);
                for r = 1:size(plannedRows,1)
                    rowId(r) = "Tp" + string(plannedRows(r,1)) + "_tw" + string(plannedRows(r,2));
                end
                mOut = table(rowId, plannedRows(:,1), plannedRows(:,2), srcRunCol, srcDeltaCol, ...
                    'VariableNames', {'row_id','Tp','tw','source_run_dir','source_deltaM_column'});
                for c = 1:numel(sharedT)
                    vn = matlab.lang.makeValidName(sprintf('T_%0.6fK', sharedT(c)));
                    mOut.(vn) = X(:, c);
                end
                writetable(mOut, outMatrix);
                MAP_NATIVE_MATRIX_EXPORTED = true;
                BLOCKER = "";
            end
        end
    end
end

% Excluded Tp usage checks.
if MAP_NATIVE_MATRIX_EXPORTED
    usedTp = unique(plannedRows(:,1));
else
    usedTp = unique(rowsOut.Tp(rowsOut.cell_extracted == "YES"));
end
EXCLUDED_T_USED = any(ismember(usedTp, [6 10 14]));
TP34_USED = any(usedTp == 34);

N_ROWS = size(plannedRows, 1);
N_TSCAN_COLUMNS = 0;
if exist(outTAxis, 'file') == 2
    tx = readtable(outTAxis);
    N_TSCAN_COLUMNS = height(tx);
end

if MAP_NATIVE_MATRIX_EXPORTED && ALL_TP_FOUND && ALL_TW_FOUND && SHARED_T_AXIS_FOUND && ...
        ~USED_INTERPOLATION && ~USED_NORMALIZATION && ~USED_CENTERING && ~USED_SMOOTHING && ...
        ~USED_SIGN_FLIP && ~EXCLUDED_T_USED && ~TP34_USED
    READY_FOR_MAP_NATIVE_SVD = "YES";
    finalDecision = "READY_FOR_MAP_NATIVE_SVD";
elseif BLOCKER == "NEEDS_GRID_ALIGNMENT_POLICY"
    finalDecision = "NEEDS_GRID_ALIGNMENT_POLICY";
elseif BLOCKER == "MISSING_PER_TP_MAP_ARTIFACTS"
    finalDecision = "MISSING_PER_TP_MAP_ARTIFACTS";
elseif BLOCKER == "MISSING_REQUIRED_TW"
    finalDecision = "MISSING_REQUIRED_TW";
elseif EXCLUDED_T_USED || TP34_USED
    finalDecision = "INVALID_SIGN_OR_SHAPE_PRESERVATION";
else
    finalDecision = "EXPORT_FAILED";
end

% Always emit required files.
writetable(rowsOut, outRows);
if exist(outTAxis, 'file') ~= 2
    writetable(table([], 'VariableNames', {'T_K'}), outTAxis);
end
if exist(outMatrix, 'file') ~= 2
    writetable(table(strings(0,1), zeros(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', {'row_id','Tp','tw','source_run_dir','source_deltaM_column'}), outMatrix);
end

val = table( ...
    string(MAP_NATIVE_MATRIX_EXPORTED), N_ROWS, N_TSCAN_COLUMNS, ...
    string(ALL_TP_FOUND), string(ALL_TW_FOUND), string(SHARED_T_AXIS_FOUND), ...
    string(USED_INTERPOLATION), string(USED_NORMALIZATION), string(USED_CENTERING), ...
    string(USED_SMOOTHING), string(USED_SIGN_FLIP), string(EXCLUDED_T_USED), ...
    string(TP34_USED), string(READY_FOR_MAP_NATIVE_SVD), string(BLOCKER), string(finalDecision), ...
    'VariableNames', {'MAP_NATIVE_MATRIX_EXPORTED','N_ROWS','N_TSCAN_COLUMNS','ALL_TP_FOUND','ALL_TW_FOUND', ...
    'SHARED_T_AXIS_FOUND','USED_INTERPOLATION','USED_NORMALIZATION','USED_CENTERING','USED_SMOOTHING', ...
    'USED_SIGN_FLIP','EXCLUDED_T_USED','TP34_USED','READY_FOR_MAP_NATIVE_SVD','BLOCKER','FINAL_DECISION'});
writetable(val, outVal);

% Report
lines = strings(0,1);
lines(end+1) = "# Q006 S2 map-native matrix export"; %#ok<AGROW>
lines(end+1) = "";
lines(end+1) = "This step exports a consolidated map-native matrix only (no SVD/mechanism).";
lines(end+1) = "";
lines(end+1) = "## Domain";
lines(end+1) = "- Tp core: 18,22,26,30";
lines(end+1) = "- tw core: 360,3600";
lines(end+1) = "- Required row order fixed to 8 rows.";
lines(end+1) = "";
lines(end+1) = "## Source runs used";
for i = 1:numel(tpCore)
    lines(end+1) = "- Tp " + string(tpCore(i)) + ": " + runDirs(i); %#ok<AGROW>
end
lines(end+1) = "";
lines(end+1) = "## Grid handling";
lines(end+1) = "- Shared T grid policy: exact intersection only.";
lines(end+1) = "- Interpolation used: " + string(USED_INTERPOLATION);
lines(end+1) = "- N shared T columns: " + string(N_TSCAN_COLUMNS);
lines(end+1) = "";
lines(end+1) = "## Integrity flags";
lines(end+1) = "- Normalization used: " + string(USED_NORMALIZATION);
lines(end+1) = "- Centering used: " + string(USED_CENTERING);
lines(end+1) = "- Smoothing used: " + string(USED_SMOOTHING);
lines(end+1) = "- Sign flip used: " + string(USED_SIGN_FLIP);
lines(end+1) = "- Excluded T used: " + string(EXCLUDED_T_USED);
lines(end+1) = "- Tp34 used: " + string(TP34_USED);
lines(end+1) = "";
lines(end+1) = "## Verdict";
lines(end+1) = "- FINAL_DECISION = " + string(finalDecision);
lines(end+1) = "- READY_FOR_MAP_NATIVE_SVD = " + string(READY_FOR_MAP_NATIVE_SVD);
lines(end+1) = "- BLOCKER = " + string(BLOCKER);
lines(end+1) = "";
lines(end+1) = "## Outputs";
lines(end+1) = "- " + string(outMatrix);
lines(end+1) = "- " + string(outRows);
lines(end+1) = "- " + string(outTAxis);
lines(end+1) = "- " + string(outVal);

fid = fopen(outReport, 'w');
assert(fid >= 0, 'Could not write report');
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines(i));
end
fclose(fid);

fprintf('Q006 S2 export done. Decision: %s\n', finalDecision);
end

function T = stripBomVarNames(T)
vn = string(T.Properties.VariableNames);
if ~isempty(vn)
    vn(1) = replace(vn(1), char(65279), "");
    T.Properties.VariableNames = cellstr(vn);
end
end

function x = getColNumeric(T, name)
vn = string(T.Properties.VariableNames);
idx = find(lower(vn) == lower(string(name)), 1, 'first');
assert(~isempty(idx), 'Missing required numeric column: %s', name);
x = double(T.(T.Properties.VariableNames{idx}));
end

function s = getColString(T, name)
vn = string(T.Properties.VariableNames);
idx = find(lower(vn) == lower(string(name)), 1, 'first');
assert(~isempty(idx), 'Missing required string column: %s', name);
s = string(T.(T.Properties.VariableNames{idx}));
end
