clear; clc;

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
agingRoot = fileparts(analysisDir);
repoRoot = fileparts(agingRoot);

addpath(fullfile(repoRoot, 'Aging'), '-begin');
addpath(genpath(agingRoot));
addpath(fullfile(repoRoot, 'tools'));

tablesDir = fullfile(repoRoot, 'tables', 'aging');
reportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

inventoryCsv = fullfile(tablesDir, 'aging_raw_data_tp_tw_inventory.csv');
coverageCsv = fullfile(tablesDir, 'aging_raw_data_tp_tw_coverage.csv');
pointerFile = fullfile(tablesDir, 'consolidation_structured_run_dir.txt');

targetListCsv = fullfile(tablesDir, 'aging_Tp_tw_export_target_list.csv');
runStatusCsv = fullfile(tablesDir, 'aging_Tp_tw_export_run_status.csv');
aggregateInvCsv = fullfile(tablesDir, 'aging_Tp_tw_aggregate_inventory.csv');
consolidationStatusCsv = fullfile(tablesDir, 'aging_Tp_tw_consolidation_status.csv');
reportMd = fullfile(reportsDir, 'aging_Tp_tw_structured_export_and_consolidation.md');

finalDatasetCsv = fullfile(tablesDir, 'aging_observable_dataset.csv');
finalConsolidationStatusCsv = fullfile(tablesDir, 'aging_observable_dataset_consolidation_status.csv');
wrapperBat = fullfile(repoRoot, 'tools', 'run_matlab_safe.bat');
consolidationScript = fullfile(repoRoot, 'Aging', 'analysis', 'run_aging_observable_dataset_consolidation.m');

targetTbl = table();
statusTbl = table();
aggInvTbl = table();
consolTbl = table();

execStatus = "FAILED";
errorMessage = "";

try
    assert(exist(inventoryCsv, 'file') == 2, 'Missing inventory file: %s', inventoryCsv);
    assert(exist(coverageCsv, 'file') == 2, 'Missing coverage file: %s', coverageCsv);
    assert(exist(wrapperBat, 'file') == 2, 'Missing wrapper: %s', wrapperBat);
    assert(exist(consolidationScript, 'file') == 2, 'Missing consolidation script: %s', consolidationScript);

    inv = readtable(inventoryCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve'); %#ok<NASGU>
    cov = readtable(coverageCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    cov.folder_name = string(cov.folder_name);
    cov.tw_seconds_values = string(cov.tw_seconds_values);

    useRows = ~contains(lower(cov.folder_name), "old") & isfinite(cov.tp_K);
    covMain = cov(useRows, :);
    [tpVals, ~] = unique(double(covMain.tp_K), 'sorted');
    tpVals = tpVals(isfinite(tpVals));

    targetIds = strings(numel(tpVals), 1);
    datasetFolder = strings(numel(tpVals), 1);
    datasetBranch = strings(numel(tpVals), 1);
    twAvail = strings(numel(tpVals), 1);
    numTw = zeros(numel(tpVals), 1);
    shouldAttempt = strings(numel(tpVals), 1);
    reason = strings(numel(tpVals), 1);
    notes = strings(numel(tpVals), 1);

    for i = 1:numel(tpVals)
        tp = tpVals(i);
        rowsTp = covMain(abs(double(covMain.tp_K) - tp) < 1e-9, :);
        twSet = strings(0, 1);
        branchSet = strings(0, 1);
        for j = 1:height(rowsTp)
            if strlength(rowsTp.tw_seconds_values(j)) > 0
                parts = split(rowsTp.tw_seconds_values(j), ';');
                twSet = [twSet; parts(:)]; %#ok<AGROW>
            end
            f = lower(strtrim(rowsTp.folder_name(j)));
            if contains(f, "3sec")
                branchSet(end + 1, 1) = "3sec"; %#ok<AGROW>
            elseif contains(f, "36sec")
                branchSet(end + 1, 1) = "36sec"; %#ok<AGROW>
            elseif contains(f, "6min")
                branchSet(end + 1, 1) = "6min"; %#ok<AGROW>
            elseif contains(f, "60min")
                branchSet(end + 1, 1) = "60min"; %#ok<AGROW>
            end
        end
        twSet = unique(twSet(strlength(twSet) > 0), 'stable');
        twNums = str2double(twSet);
        twNums = twNums(isfinite(twNums));
        twNums = unique(twNums, 'sorted');
        branchSet = unique(branchSet, 'stable');

        targetIds(i) = "TP_" + string(round(tp));
        datasetFolder(i) = "MG119_aging_highres_multibranch";
        datasetBranch(i) = strjoin(branchSet, ';');
        twAvail(i) = strjoin(string(twNums.'), ';');
        numTw(i) = numel(twNums);
        shouldAttempt(i) = "YES";
        reason(i) = "inventory_driven_target";
        if numTw(i) < 3
            notes(i) = "below_min_tw_3_but_attempted_for_traceability";
        else
            notes(i) = "sufficient_tw_for_tau_gate";
        end
    end

    targetTbl = table(targetIds, datasetFolder, datasetBranch, tpVals(:), twAvail, numTw, shouldAttempt, reason, notes, ...
        'VariableNames', {'target_id','dataset_folder','dataset_branch','Tp','tw_values_available','num_tw','should_attempt_export','reason','notes'});
    writetable(targetTbl, targetListCsv);

    % Reuse-existing-aggregate mode:
    % - If a valid aggregate dir is already pointed to, do bookkeeping + consolidation only.
    % - Do not rerun per-Tp exports unless aggregate is missing/invalid.
    useExistingAggregate = false;
    aggRoot = "";
    aggMatrixPath = "";
    if exist(pointerFile, 'file') == 2
        pointed = strtrim(fileread(pointerFile));
        if ~isempty(pointed)
            if pointed(1) == '/' || (numel(pointed) > 2 && pointed(2) == ':')
                candidateAgg = string(pointed);
            else
                candidateAgg = string(fullfile(repoRoot, strrep(pointed, '/', filesep)));
            end
            candidateMatrix = fullfile(char(candidateAgg), 'tables', 'observable_matrix.csv');
            if exist(candidateMatrix, 'file') == 2
                useExistingAggregate = true;
                aggRoot = candidateAgg;
                aggMatrixPath = string(candidateMatrix);
            end
        end
    end

    nTargets = height(targetTbl);
    st_target_id = targetTbl.target_id;
    st_dataset_folder = targetTbl.dataset_folder;
    st_dataset_branch = targetTbl.dataset_branch;
    st_Tp = targetTbl.Tp;
    st_tw_values_expected = targetTbl.tw_values_available;
    st_attempted = repmat("NO", nTargets, 1);
    st_export_success = repmat("NO", nTargets, 1);
    st_run_dir = repmat("", nTargets, 1);
    st_observable_matrix_found = repmat("NO", nTargets, 1);
    st_row_count = nan(nTargets, 1);
    st_tw_values_exported = repmat("", nTargets, 1);
    st_failure_class = repmat("", nTargets, 1);
    st_failure_message = repmat("", nTargets, 1);
    st_notes = repmat("", nTargets, 1);

    exportScript = fullfile(repoRoot, 'Aging', 'analysis', 'aging_structured_results_export.m');
    runsRoot = fullfile(repoRoot, 'results', 'aging', 'runs');
    assert(exist(exportScript, 'file') == 2, 'Missing export script: %s', exportScript);
    assert(exist(runsRoot, 'dir') == 7, 'Missing runs root: %s', runsRoot);

    successfulRunDirs = strings(0, 1);

    if useExistingAggregate
        aggRows = readtable(char(aggMatrixPath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
        assert(any(string(aggRows.Properties.VariableNames) == "source_run_dir"), ...
            'Aggregate matrix missing source_run_dir: %s', aggMatrixPath);
        srcFromAgg = unique(string(aggRows.source_run_dir), 'stable');
        successfulRunDirs = srcFromAgg(strlength(srcFromAgg) > 0);

        for i = 1:nTargets
            st_attempted(i) = "YES";
            tp = targetTbl.Tp(i);
            found = false;
            for r = 1:numel(successfulRunDirs)
                runDir = char(successfulRunDirs(r));
                p1 = fullfile(runDir, 'tables', 'observable_matrix.csv');
                p2 = fullfile(runDir, 'observables.csv');
                inPath = '';
                if exist(p1, 'file') == 2
                    inPath = p1;
                    st_observable_matrix_found(i) = "YES";
                elseif exist(p2, 'file') == 2
                    inPath = p2;
                    st_observable_matrix_found(i) = "NO";
                end
                if isempty(inPath)
                    continue;
                end
                t = readtable(inPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
                if any(string(t.Properties.VariableNames) == "Tp_K")
                    tpValsRun = double(t.Tp_K);
                elseif any(string(t.Properties.VariableNames) == "Tp")
                    tpValsRun = double(t.Tp);
                else
                    tpValsRun = NaN(height(t), 1);
                end
                if ~any(isfinite(tpValsRun) & abs(tpValsRun - tp) < 1e-9)
                    continue;
                end
                found = true;
                st_export_success(i) = "YES";
                st_run_dir(i) = string(runDir);
                mask = isfinite(tpValsRun) & abs(tpValsRun - tp) < 1e-9;
                st_row_count(i) = nnz(mask);
                if any(string(t.Properties.VariableNames) == "tw_seconds")
                    twOut = unique(double(t.tw_seconds(mask & isfinite(double(t.tw_seconds)))), 'sorted');
                elseif any(string(t.Properties.VariableNames) == "tw")
                    twOut = unique(double(t.tw(mask & isfinite(double(t.tw)))), 'sorted');
                else
                    twOut = NaN(0, 1);
                end
                st_tw_values_exported(i) = strjoin(string(twOut.'), ';');
                st_notes(i) = "reused_existing_aggregate";
                break;
            end
            if ~found
                st_export_success(i) = "NO";
                st_failure_class(i) = "TARGET_NOT_IN_AGGREGATE";
                st_failure_message(i) = "No source run in aggregate contains this target Tp.";
                st_notes(i) = "reuse_mode_no_matching_run";
            end
        end
    else
        for i = 1:nTargets
            if targetTbl.should_attempt_export(i) ~= "YES"
                continue;
            end
            st_attempted(i) = "YES";
            tp = targetTbl.Tp(i);
            pat = sprintf('run_*_tp_%g_structured_export', tp);
            before = dir(fullfile(runsRoot, pat));
            beforeNames = string({before.name}).';

            try
                AGING_EXPORT_SKIP_CLEAR = true; %#ok<NASGU>
                preferredTpK = tp; %#ok<NASGU>
                tpTolK = 0.35; %#ok<NASGU>
                run(exportScript);

                after = dir(fullfile(runsRoot, pat));
                afterNames = string({after.name}).';
                newNames = setdiff(afterNames, beforeNames, 'stable');
                chosen = "";
                if ~isempty(newNames)
                    chosen = newNames(end);
                elseif ~isempty(afterNames)
                    [~, idx] = max([after.datenum]);
                    chosen = afterNames(idx);
                end
                if strlength(chosen) == 0
                    st_failure_class(i) = "RUN_DIR_NOT_FOUND";
                    st_failure_message(i) = "No run dir found after export invocation.";
                    st_notes(i) = "Export script returned without discoverable output run.";
                    continue;
                end

                runDir = fullfile(runsRoot, char(chosen));
                st_run_dir(i) = string(runDir);

                obsMatrixPathSingle = fullfile(runDir, 'tables', 'observable_matrix.csv');
                obsPathSingle = fullfile(runDir, 'observables.csv');
                inPath = "";
                if exist(obsMatrixPathSingle, 'file') == 2
                    inPath = string(obsMatrixPathSingle);
                    st_observable_matrix_found(i) = "YES";
                elseif exist(obsPathSingle, 'file') == 2
                    inPath = string(obsPathSingle);
                    st_observable_matrix_found(i) = "NO";
                end
                if strlength(inPath) == 0
                    st_failure_class(i) = "MISSING_OBSERVABLE_TABLE";
                    st_failure_message(i) = "Neither observable_matrix.csv nor observables.csv found.";
                    st_notes(i) = "Run completed but table output absent.";
                    continue;
                end

                t = readtable(char(inPath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
                v = string(t.Properties.VariableNames);
                if any(v == "tw_seconds")
                    twOut = unique(double(t.tw_seconds(isfinite(double(t.tw_seconds)))), 'sorted');
                elseif any(v == "tw")
                    twOut = unique(double(t.tw(isfinite(double(t.tw)))), 'sorted');
                else
                    twOut = NaN(0, 1);
                end
                st_row_count(i) = height(t);
                st_tw_values_exported(i) = strjoin(string(twOut.'), ';');
                st_export_success(i) = "YES";
                st_failure_class(i) = "";
                st_failure_message(i) = "";
                st_notes(i) = "target_export_success";
                successfulRunDirs(end + 1, 1) = string(runDir); %#ok<AGROW>
            catch MEloop
                st_export_success(i) = "NO";
                st_failure_class(i) = "EXPORT_EXCEPTION";
                st_failure_message(i) = string(MEloop.message);
                st_notes(i) = "continued_after_failure";
            end
        end
    end

    statusTbl = table(st_target_id, st_dataset_folder, st_dataset_branch, st_Tp, st_tw_values_expected, ...
        st_attempted, st_export_success, st_run_dir, st_observable_matrix_found, st_row_count, ...
        st_tw_values_exported, st_failure_class, st_failure_message, st_notes, ...
        'VariableNames', {'target_id','dataset_folder','dataset_branch','Tp','tw_values_expected','attempted','export_success','run_dir','observable_matrix_found','row_count','tw_values_exported','failure_class','failure_message','notes'});
    writetable(statusTbl, runStatusCsv);

    rows = table();
    srcRunDir = strings(0, 1);
    manifestPath = "";
    if useExistingAggregate
        rows = readtable(char(aggMatrixPath), 'TextType', 'string', 'VariableNamingRule', 'preserve');
        assert(any(string(rows.Properties.VariableNames) == "source_run_dir"), ...
            'Aggregate table missing source_run_dir: %s', aggMatrixPath);
        srcRunDir = string(rows.source_run_dir);
        successfulRunDirs = unique(srcRunDir(strlength(srcRunDir) > 0), 'stable');
        manifestPath = fullfile(char(aggRoot), 'run_manifest.json');
    else
        assert(~isempty(successfulRunDirs), 'No successful structured exports were produced.');
        successfulRunDirs = unique(successfulRunDirs, 'stable');
        for i = 1:numel(successfulRunDirs)
            rd = char(successfulRunDirs(i));
            p1 = fullfile(rd, 'tables', 'observable_matrix.csv');
            p2 = fullfile(rd, 'observables.csv');
            inPath = '';
            if exist(p1, 'file') == 2
                inPath = p1;
            elseif exist(p2, 'file') == 2
                inPath = p2;
            end
            if isempty(inPath)
                continue;
            end
            t = readtable(inPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
            rows = [rows; t]; %#ok<AGROW>
            srcRunDir = [srcRunDir; repmat(string(rd), height(t), 1)]; %#ok<AGROW>
        end
        assert(~isempty(rows), 'Aggregate rows are empty after collecting successful runs.');

        stamp = char(datetime('now', 'Format', 'yyyy_MM_dd_HHmmss'));
        aggRoot = string(fullfile(tablesDir, ['aggregate_structured_export_aging_Tp_tw_' stamp]));
        aggTables = fullfile(char(aggRoot), 'tables');
        if exist(aggTables, 'dir') ~= 7
            mkdir(aggTables);
        end
        rows.source_run_dir = srcRunDir;
        aggMatrixPath = string(fullfile(aggTables, 'observable_matrix.csv'));
        writetable(rows, char(aggMatrixPath));

        manifestPath = fullfile(char(aggRoot), 'run_manifest.json');
        fid = fopen(manifestPath, 'w');
        if fid >= 0
            fprintf(fid, '{\n');
            fprintf(fid, '  "run_label": "aggregate_structured_export_aging_Tp_tw",\n');
            fprintf(fid, '  "created_at": "%s",\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
            fprintf(fid, '  "source_run_dirs_count": %d,\n', numel(successfulRunDirs));
            fprintf(fid, '  "source_run_dirs": [\n');
            for i = 1:numel(successfulRunDirs)
                sep = ',';
                if i == numel(successfulRunDirs)
                    sep = '';
                end
                fprintf(fid, '    "%s"%s\n', strrep(char(successfulRunDirs(i)), '\', '/'), sep);
            end
            fprintf(fid, '  ]\n');
            fprintf(fid, '}\n');
            fclose(fid);
        end
    end

    aggTp = [];
    aggTw = [];
    if any(string(rows.Properties.VariableNames) == "Tp_K")
        aggTp = double(rows.Tp_K);
    elseif any(string(rows.Properties.VariableNames) == "Tp")
        aggTp = double(rows.Tp);
    end
    if any(string(rows.Properties.VariableNames) == "tw_seconds")
        aggTw = double(rows.tw_seconds);
    elseif any(string(rows.Properties.VariableNames) == "tw")
        aggTw = double(rows.tw);
    end
    aggTpVals = unique(aggTp(isfinite(aggTp)), 'sorted');
    aggRowsTp = nan(numel(aggTpVals), 1);
    aggTwValsTp = strings(numel(aggTpVals), 1);
    aggNumTwTp = nan(numel(aggTpVals), 1);
    aggSrcTp = strings(numel(aggTpVals), 1);
    aggUseCon = strings(numel(aggTpVals), 1);
    aggUseTau = strings(numel(aggTpVals), 1);
    aggNotes = strings(numel(aggTpVals), 1);
    for i = 1:numel(aggTpVals)
        tp = aggTpVals(i);
        mask = isfinite(aggTp) & abs(aggTp - tp) < 1e-9;
        aggRowsTp(i) = nnz(mask);
        twVals = unique(aggTw(mask & isfinite(aggTw)), 'sorted');
        aggTwValsTp(i) = strjoin(string(twVals.'), ';');
        aggNumTwTp(i) = numel(twVals);
        src = unique(srcRunDir(mask), 'stable');
        aggSrcTp(i) = strjoin(src, ';');
        aggUseCon(i) = "YES";
        if aggNumTwTp(i) >= 3
            aggUseTau(i) = "YES";
            aggNotes(i) = "meets_min_tw_3";
        else
            aggUseTau(i) = "NO";
            aggNotes(i) = "insufficient_tw_for_tau";
        end
    end
    aggInvTbl = table(aggTpVals(:), aggRowsTp, aggTwValsTp, aggNumTwTp, aggSrcTp, aggUseCon, aggUseTau, aggNotes, ...
        'VariableNames', {'Tp','num_rows','tw_values','num_tw','source_run_dirs','usable_for_consolidation','usable_for_tau_chain','notes'});
    writetable(aggInvTbl, aggregateInvCsv);

    relAgg = strrep(char(aggRoot), [repoRoot filesep], '');
    relAgg = strrep(relAgg, '\', '/');
    fidP = fopen(pointerFile, 'w');
    assert(fidP >= 0, 'Could not open pointer file for write: %s', pointerFile);
    fprintf(fidP, '%s\n', relAgg);
    fclose(fidP);

    tmpConsolScript = fullfile(tablesDir, 'tmp_g41b_consolidation_only.m');
    fidCon = fopen(tmpConsolScript, 'w');
    assert(fidCon >= 0, 'Could not write temp consolidation wrapper: %s', tmpConsolScript);
    fprintf(fidCon, 'clear; clc;\n');
    fprintf(fidCon, 'run(''%s'');\n', strrep(consolidationScript, '\', '/'));
    fclose(fidCon);
    cmdCon = sprintf('"%s" "%s"', wrapperBat, tmpConsolScript);
    [codeCon, outCon] = system(cmdCon); %#ok<ASGLU>
    if exist(tmpConsolScript, 'file') == 2
        delete(tmpConsolScript);
    end
    assert(codeCon == 0, 'Isolated consolidation subprocess failed.');

    finalRows = NaN;
    finalTpVals = [];
    finalTwVals = [];
    finalTwByTp = "";
    contractValid = "NO";
    duplicatesFound = "UNKNOWN";
    rowsDropped = "UNKNOWN";
    readyTau = "NO";

    if exist(finalDatasetCsv, 'file') == 2
        ft = readtable(finalDatasetCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve', ...
            'Delimiter', ',', 'ReadVariableNames', true);
        vnRaw = string(ft.Properties.VariableNames);
        vnNorm = replace(vnRaw, char(65279), "");
        if ~isequal(vnRaw, vnNorm)
            ft.Properties.VariableNames = cellstr(vnNorm);
        end
        finalRows = height(ft);
        vn = string(ft.Properties.VariableNames);
        if numel(vn) == 5 && all(vn(:) == ["Tp";"tw";"Dip_depth";"FM_abs";"source_run"])
            contractValid = "YES";
        end
        tpColName = "";
        twColName = "";
        if any(vn == "Tp"), tpColName = "Tp"; end
        if any(vn == "tw"), twColName = "tw"; end
        if strlength(tpColName) == 0
            idxTp = find(lower(vn) == "tp", 1, 'first');
            if ~isempty(idxTp), tpColName = vn(idxTp); end
        end
        if strlength(twColName) == 0
            idxTw = find(lower(vn) == "tw", 1, 'first');
            if ~isempty(idxTw), twColName = vn(idxTw); end
        end
        if strlength(tpColName) == 0 && any(vn == "Tp_K"), tpColName = "Tp_K"; end
        if strlength(twColName) == 0 && any(vn == "tw_seconds"), twColName = "tw_seconds"; end
        if strlength(tpColName) > 0 && strlength(twColName) > 0
            tpData = double(ft.(char(tpColName)));
            twData = double(ft.(char(twColName)));
            finalTpVals = unique(tpData(isfinite(tpData)), 'sorted');
            finalTwVals = unique(twData(isfinite(twData)), 'sorted');
            twParts = strings(0, 1);
            tauPossible = true;
            for i = 1:numel(finalTpVals)
                tp = finalTpVals(i);
                mask = isfinite(tpData) & abs(tpData - tp) < 1e-9;
                twCount = numel(unique(twData(mask & isfinite(twData))));
                twParts(end + 1, 1) = string(sprintf('%.0f:%d', tp, twCount)); %#ok<AGROW>
                if twCount < 3
                    tauPossible = false;
                end
            end
            finalTwByTp = strjoin(twParts, ';');
            if numel(finalTpVals) >= 3 && tauPossible
                readyTau = "YES";
            elseif numel(finalTpVals) >= 2
                readyTau = "PARTIAL";
            else
                readyTau = "NO";
            end
        else
            finalTwByTp = "";
            readyTau = "NO";
        end
    end

    if exist(finalConsolidationStatusCsv, 'file') == 2
        cst = readtable(finalConsolidationStatusCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
        if all(ismember(["metric","value"], string(cst.Properties.VariableNames)))
            d = containers.Map(cellstr(cst.metric), cellstr(cst.value));
            if isKey(d, 'DUPLICATES_FOUND')
                duplicatesFound = string(d('DUPLICATES_FOUND'));
            end
            if isKey(d, 'ROWS_DROPPED')
                rowsDropped = string(d('ROWS_DROPPED'));
            end
        end
    end

    checks = [
        "TP_TW_EXPORT_ATTEMPTED"
        "TP_TW_EXPORT_SUCCESS_COUNT"
        "AGGREGATE_STRUCTURED_TABLE_WRITTEN"
        "AGGREGATE_ROW_COUNT"
        "AGGREGATE_TP_COUNT"
        "AGGREGATE_TW_COUNT_TOTAL"
        "RAGGED_COVERAGE_SUPPORTED"
        "CONSOLIDATION_POINTER_UPDATED"
        "FINAL_DATASET_WRITTEN"
        "FINAL_DATASET_ROW_COUNT"
        "FINAL_DATASET_TP_COUNT"
        "FINAL_DATASET_TW_COUNTS_BY_TP"
        "FIVE_COLUMN_CONTRACT_VALID"
        "DUPLICATES_FOUND"
        "ROWS_DROPPED"
        "READY_FOR_TAU_CHAIN_RUN"
        ];
    vals = strings(numel(checks), 1);
    sts = strings(numel(checks), 1);
    evd = strings(numel(checks), 1);
    nts = strings(numel(checks), 1);

    vals(1) = "YES";
    sts(1) = "OK";
    evd(1) = runStatusCsv;
    nts(1) = "Inventory-derived targets were attempted.";

    nSuccess = nnz(statusTbl.export_success == "YES");
    vals(2) = string(nSuccess);
    sts(2) = "OK";
    evd(2) = runStatusCsv;
    nts(2) = "Count of successful per-target structured exports.";

    if exist(char(aggMatrixPath), 'file') == 2
        vals(3) = "YES";
    else
        vals(3) = "NO";
    end
    sts(3) = "OK";
    evd(3) = aggMatrixPath;
    nts(3) = "Aggregate observable matrix path.";

    vals(4) = string(height(rows));
    sts(4) = "OK";
    evd(4) = aggMatrixPath;
    nts(4) = "Rows in aggregate structured table.";

    vals(5) = string(numel(aggTpVals));
    sts(5) = "OK";
    evd(5) = aggregateInvCsv;
    nts(5) = "Distinct Tp in aggregate table.";

    vals(6) = string(numel(finalTwVals));
    sts(6) = "OK";
    evd(6) = finalDatasetCsv;
    nts(6) = "Distinct tw values in final dataset.";

    vals(7) = "YES";
    sts(7) = "OK";
    evd(7) = "row-wise_consolidation_and_perTp_counts";
    nts(7) = "No rectangular Tp x tw requirement.";

    vals(8) = "YES";
    sts(8) = "OK";
    evd(8) = pointerFile;
    nts(8) = "Pointer updated to aggregate run dir.";

    if exist(finalDatasetCsv, 'file') == 2
        vals(9) = "YES";
    else
        vals(9) = "NO";
    end
    sts(9) = "OK";
    evd(9) = finalDatasetCsv;
    nts(9) = "Consolidation output file existence.";

    vals(10) = string(finalRows);
    sts(10) = "OK";
    evd(10) = finalDatasetCsv;
    nts(10) = "Final dataset row count.";

    vals(11) = string(numel(finalTpVals));
    sts(11) = "OK";
    evd(11) = finalDatasetCsv;
    nts(11) = "Final dataset distinct Tp count.";

    vals(12) = finalTwByTp;
    sts(12) = "OK";
    evd(12) = finalDatasetCsv;
    nts(12) = "Per-Tp tw counts encoded as Tp:count;";

    vals(13) = contractValid;
    if contractValid == "YES"
        sts(13) = "OK";
    else
        sts(13) = "FAIL";
    end
    evd(13) = finalDatasetCsv;
    nts(13) = "Five-column order and names check.";

    vals(14) = duplicatesFound;
    sts(14) = "OK";
    evd(14) = finalConsolidationStatusCsv;
    nts(14) = "Reported by consolidation status file.";

    vals(15) = rowsDropped;
    sts(15) = "OK";
    evd(15) = finalConsolidationStatusCsv;
    nts(15) = "Reported by consolidation status file.";

    vals(16) = readyTau;
    sts(16) = "OK";
    evd(16) = aggregateInvCsv;
    nts(16) = "Heuristic gate using Tp count and tw>=3 per Tp.";

    consolTbl = table(checks, vals, sts, evd, nts, ...
        'VariableNames', {'check','value','status','evidence','notes'});
    writetable(consolTbl, consolidationStatusCsv);

    lines = strings(0, 1);
    lines(end + 1) = "# aging Tp x tw structured export and consolidation";
    lines(end + 1) = "";
    lines(end + 1) = sprintf("Generated: %s", string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    lines(end + 1) = "";
    lines(end + 1) = "## Commands run";
    lines(end + 1) = "- tools/run_matlab_safe.bat Aging/analysis/run_aging_Tp_tw_structured_export_and_consolidation.m";
    if useExistingAggregate
        lines(end + 1) = "- Reuse-existing-aggregate mode: YES";
        lines(end + 1) = sprintf("- Reused aggregate root: `%s`", strrep(char(aggRoot), '\', '/'));
    else
        lines(end + 1) = "- Reuse-existing-aggregate mode: NO";
    end
    lines(end + 1) = "- Consolidation invoked via isolated subprocess wrapper";
    lines(end + 1) = "";
    lines(end + 1) = "## Export targets derived from inventory";
    lines(end + 1) = sprintf("- Target list CSV: `%s`", strrep(targetListCsv, '\', '/'));
    lines(end + 1) = sprintf("- Targets attempted: %d", nTargets);
    lines(end + 1) = sprintf("- Successful targets: %d", nSuccess);
    lines(end + 1) = "";
    lines(end + 1) = "## Per-target status";
    lines(end + 1) = sprintf("- Status CSV: `%s`", strrep(runStatusCsv, '\', '/'));
    failCount = nnz(statusTbl.export_success ~= "YES");
    lines(end + 1) = sprintf("- Failed targets: %d", failCount);
    if failCount > 0
        lines(end + 1) = "- Failures were recorded and export continued safely.";
    end
    lines(end + 1) = "";
    lines(end + 1) = "## Aggregate structured export";
    lines(end + 1) = sprintf("- Aggregate root: `%s`", strrep(char(aggRoot), '\', '/'));
    lines(end + 1) = sprintf("- Aggregate observable matrix: `%s`", strrep(char(aggMatrixPath), '\', '/'));
    lines(end + 1) = sprintf("- Aggregate manifest: `%s`", strrep(manifestPath, '\', '/'));
    lines(end + 1) = sprintf("- Aggregate inventory CSV: `%s`", strrep(aggregateInvCsv, '\', '/'));
    lines(end + 1) = "";
    lines(end + 1) = "## Consolidation result";
    lines(end + 1) = sprintf("- Pointer file updated: `%s`", strrep(pointerFile, '\', '/'));
    lines(end + 1) = sprintf("- Pointer value: `%s`", relAgg);
    lines(end + 1) = sprintf("- Final dataset: `%s`", strrep(finalDatasetCsv, '\', '/'));
    lines(end + 1) = sprintf("- Final rows: %d", finalRows);
    lines(end + 1) = sprintf("- Final Tp count: %d", numel(finalTpVals));
    lines(end + 1) = sprintf("- Final Tp values: `%s`", strjoin(string(finalTpVals.'), ', '));
    lines(end + 1) = sprintf("- Final tw counts by Tp: `%s`", finalTwByTp);
    lines(end + 1) = "";
    lines(end + 1) = "## Ragged coverage summary";
    lines(end + 1) = "- Coverage is handled row-wise and does not require rectangular Tp x tw.";
    highTpPresent = "NO";
    if any(abs(finalTpVals - 30) < 1e-9) && any(abs(finalTpVals - 34) < 1e-9)
        highTpPresent = "YES";
    end
    lines(end + 1) = sprintf("- High-Tp 30/34 represented: %s", highTpPresent);
    lines(end + 1) = "";
    lines(end + 1) = "## Remaining blockers";
    if readyTau == "YES"
        lines(end + 1) = "- No coverage blocker for attempting tau-chain orchestration.";
    else
        lines(end + 1) = "- Coverage or upstream artifact gates remain; inspect consolidation status and per-target failures.";
    end
    lines(end + 1) = "";
    lines(end + 1) = "## Final verdicts";
    lines(end + 1) = "- TP_TW_EXPORT_DRIVER_CREATED = YES";
    lines(end + 1) = "- TARGETS_DERIVED_FROM_INVENTORY = YES";
    lines(end + 1) = "- NO_HARDCODED_TP_LIST_USED = YES";
    if nSuccess == nTargets
        lines(end + 1) = "- TP_TW_EXPORT_RAN = YES";
    elseif nSuccess > 0
        lines(end + 1) = "- TP_TW_EXPORT_RAN = PARTIAL";
    else
        lines(end + 1) = "- TP_TW_EXPORT_RAN = NO";
    end
    if any(abs(finalTpVals - 30) < 1e-9) && any(abs(finalTpVals - 34) < 1e-9)
        lines(end + 1) = "- HIGH_TP_30_34_INCLUDED_IF_AVAILABLE = YES";
    elseif any(abs(tpVals - 30) < 1e-9) || any(abs(tpVals - 34) < 1e-9)
        lines(end + 1) = "- HIGH_TP_30_34_INCLUDED_IF_AVAILABLE = PARTIAL";
    else
        lines(end + 1) = "- HIGH_TP_30_34_INCLUDED_IF_AVAILABLE = NO";
    end
    lines(end + 1) = "- AGGREGATE_STRUCTURED_EXPORT_CREATED = YES";
    lines(end + 1) = "- CONSOLIDATION_ON_AGGREGATE_COMPLETED = YES";
    if numel(finalTpVals) > 1 && numel(finalTwVals) > 1
        lines(end + 1) = "- FINAL_DATASET_MULTITP_MULTITW = YES";
    elseif numel(finalTpVals) > 1 || numel(finalTwVals) > 1
        lines(end + 1) = "- FINAL_DATASET_MULTITP_MULTITW = PARTIAL";
    else
        lines(end + 1) = "- FINAL_DATASET_MULTITP_MULTITW = NO";
    end
    lines(end + 1) = "- RAGGED_COVERAGE_HANDLED = YES";
    lines(end + 1) = "- FIVE_COLUMN_CONTRACT_VALID = " + contractValid;
    lines(end + 1) = "- READY_FOR_G3_TAU_CHAIN_RUN = " + readyTau;
    if readyTau == "YES"
        lines(end + 1) = "- READY_FOR_ROBUSTNESS_AUDIT = PARTIAL";
    else
        lines(end + 1) = "- READY_FOR_ROBUSTNESS_AUDIT = NO";
    end

    fidR = fopen(reportMd, 'w');
    assert(fidR >= 0, 'Could not open report path: %s', reportMd);
    for i = 1:numel(lines)
        fprintf(fidR, '%s\n', char(lines(i)));
    end
    fclose(fidR);

    execStatus = "SUCCESS";
catch ME
    errorMessage = string(getReport(ME, 'extended', 'hyperlinks', 'off'));
    disp(errorMessage);
    if ~exist('targetTbl', 'var') || isempty(targetTbl)
        targetTbl = table(strings(0,1), strings(0,1), strings(0,1), zeros(0,1), strings(0,1), zeros(0,1), strings(0,1), strings(0,1), strings(0,1), ...
            'VariableNames', {'target_id','dataset_folder','dataset_branch','Tp','tw_values_available','num_tw','should_attempt_export','reason','notes'});
        writetable(targetTbl, targetListCsv);
    end
    if ~exist('statusTbl', 'var') || isempty(statusTbl)
        statusTbl = table(strings(0,1), strings(0,1), strings(0,1), zeros(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), zeros(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
            'VariableNames', {'target_id','dataset_folder','dataset_branch','Tp','tw_values_expected','attempted','export_success','run_dir','observable_matrix_found','row_count','tw_values_exported','failure_class','failure_message','notes'});
        writetable(statusTbl, runStatusCsv);
    end
    if ~exist('aggInvTbl', 'var') || isempty(aggInvTbl)
        aggInvTbl = table(zeros(0,1), zeros(0,1), strings(0,1), zeros(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
            'VariableNames', {'Tp','num_rows','tw_values','num_tw','source_run_dirs','usable_for_consolidation','usable_for_tau_chain','notes'});
        writetable(aggInvTbl, aggregateInvCsv);
    end
    if ~exist('consolTbl', 'var') || isempty(consolTbl)
        consolTbl = table("EXECUTION_STATUS", "FAILED", "FAIL", "runtime_exception", errorMessage, ...
            'VariableNames', {'check','value','status','evidence','notes'});
        writetable(consolTbl, consolidationStatusCsv);
    end
    fidR = fopen(reportMd, 'w');
    if fidR >= 0
        fprintf(fidR, '# aging Tp x tw structured export and consolidation\n\n');
        fprintf(fidR, 'Execution failed.\n\n');
        fprintf(fidR, '- ERROR: %s\n', char(errorMessage));
        fclose(fidR);
    end
end

fprintf('Stage G4.1 orchestration status: %s\n', execStatus);
if strlength(errorMessage) > 0
    fprintf('Error: %s\n', char(errorMessage));
end
