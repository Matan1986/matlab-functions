% run_relaxation_extraction_from_known_runs
% Pure script (no local functions)
% Data-location + extraction only (no fitting/interpolation/modeling).

fprintf('[RUN] run_relaxation_extraction_from_known_runs\n');
clearvars;

repoRoot = 'C:/Dev/matlab-functions';
scriptPath = 'C:/Dev/matlab-functions/Switching/analysis/run_relaxation_extraction_from_known_runs.m';

runDirs = { ...
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_10_143906_timelaw_observables', ...
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_10_133938_time_mode_analysis', ...
    'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_kww_model', ...
    'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_log_model' ...
    };

for i = 1:numel(runDirs)
    if contains(runDirs{i}, '/results/') && contains(runDirs{i}, '/runs/run_')
        error('DIRECT_RUN_ACCESS_FORBIDDEN');
    end
end

outExtracted = 'C:/Dev/matlab-functions/tables/relaxation_M_logt_extracted.csv';
outDebug = 'C:/Dev/matlab-functions/tables/relaxation_extraction_debug.csv';
outStatus = 'C:/Dev/matlab-functions/tables/relaxation_extraction_status.csv';
outReport = 'C:/Dev/matlab-functions/reports/relaxation_extraction.md';
errorLogPath = 'C:/Dev/matlab-functions/matlab_error.log';

if exist('C:/Dev/matlab-functions/tables', 'dir') ~= 7, mkdir('C:/Dev/matlab-functions/tables'); end
if exist('C:/Dev/matlab-functions/reports', 'dir') ~= 7, mkdir('C:/Dev/matlab-functions/reports'); end

extractTbl = table('Size', [0, 6], ...
    'VariableTypes', {'double', 'double', 'double', 'string', 'string', 'string'}, ...
    'VariableNames', {'T_K', 'log_t', 'M', 'source_file', 'time_column', 'signal_column'});

debugTbl = table('Size', [0, 7], ...
    'VariableTypes', {'string', 'string', 'string', 'double', 'string', 'string', 'string'}, ...
    'VariableNames', {'file_path', 'time_column', 'signal_column', 'n_points', 'is_monotonic', 'is_log_axis', 'valid_relaxation'});

VALID_RELAXATION_FOUND = "NO";
N_VALID_FILES = 0;
USED_FILES = "";
HAS_MULTIPLE_T = "NO";
EXECUTION_STATUS = "FAIL";
ERROR_MESSAGE = "";

md = strings(0, 1);
md(end+1) = "# Relaxation extraction";
md(end+1) = "";
md(end+1) = "Script: `" + string(scriptPath) + "`";
md(end+1) = "";

try
    allFiles = strings(0, 1);
    for ir = 1:numel(runDirs)
        runDir = runDirs{ir};
        if exist(runDir, 'dir') ~= 7
            continue;
        end
        rootCsv = dir(fullfile(runDir, '*.csv'));
        for i = 1:numel(rootCsv)
            allFiles(end+1, 1) = string(fullfile(rootCsv(i).folder, rootCsv(i).name)); %#ok<SAGROW>
        end
        tblCsv = dir(fullfile(runDir, 'tables', '*.csv'));
        for i = 1:numel(tblCsv)
            allFiles(end+1, 1) = string(fullfile(tblCsv(i).folder, tblCsv(i).name)); %#ok<SAGROW>
        end
    end
    if ~isempty(allFiles)
        allFiles = unique(allFiles, 'stable');
    end

    usedFilesList = strings(0, 1);
    validPointsPerFile = NaN(numel(allFiles), 1);
    fileIsValid = false(numel(allFiles), 1);

    for ifile = 1:numel(allFiles)
        filePath = allFiles(ifile);
        timeColUsed = "";
        signalColUsed = "";
        isMonoFile = "NO";
        isLogAxisFile = "NO";
        validFile = "NO";
        nPtsFile = 0;

        TfileOut = NaN(0, 1);
        logtOut = NaN(0, 1);
        Mout = NaN(0, 1);
        timeNameOut = strings(0, 1);
        signalNameOut = strings(0, 1);

        try
            T = readtable(filePath, 'VariableNamingRule', 'preserve');
            if height(T) == 0 || width(T) == 0
                debugTbl = [debugTbl; {filePath, timeColUsed, signalColUsed, 0, "NO", "NO", "NO"}]; %#ok<AGROW>
                continue;
            end

            vNames = string(T.Properties.VariableNames);
            vNamesLow = lower(vNames);

            % Detect temperature column (optional)
            idxTemp = find(contains(vNamesLow, 't_k') | (contains(vNamesLow, 'temp') & ~contains(vNamesLow, 'time')), 1, 'first');
            Tcol = NaN(height(T), 1);
            if ~isempty(idxTemp) && isnumeric(T{:, idxTemp})
                Tcol = double(T{:, idxTemp});
            end

            % Detect time column candidates using contains() only
            isTimeName = contains(vNamesLow, 'log_t') | contains(vNamesLow, 'time') | ...
                contains(vNamesLow, 't_rel') | contains(vNamesLow, 'tau') | ...
                (contains(vNamesLow, 't') & ~contains(vNamesLow, 'temp'));
            idxTimeCand = find(isTimeName);
            bestTimeScore = -Inf;
            idxTime = [];
            for ic = 1:numel(idxTimeCand)
                k = idxTimeCand(ic);
                colRaw = T{:, k};
                if ~isnumeric(colRaw)
                    continue;
                end
                col = double(colRaw(:));
                nFin = nnz(isfinite(col));
                nUni = numel(unique(col(isfinite(col))));
                if nFin < 3 || nUni < 3
                    continue;
                end
                score = 0;
                if contains(vNamesLow(k), 'log_t'), score = score + 100; end
                if contains(vNamesLow(k), 'time'), score = score + 80; end
                if contains(vNamesLow(k), 't_rel'), score = score + 60; end
                if contains(vNamesLow(k), 'tau'), score = score + 40; end
                if contains(vNamesLow(k), 't'), score = score + 10; end
                score = score + nFin / max(height(T), 1);
                if score > bestTimeScore
                    bestTimeScore = score;
                    idxTime = k;
                end
            end

            if isempty(idxTime)
                debugTbl = [debugTbl; {filePath, "", "", 0, "NO", "NO", "NO"}]; %#ok<AGROW>
                continue;
            end
            timeColUsed = vNames(idxTime);

            % Detect signal columns using contains()
            isDerivName = contains(vNamesLow, 'dmdlog') | contains(vNamesLow, 'dm_dlog') | ...
                contains(vNamesLow, 'dmdt') | contains(vNamesLow, 'deriv') | contains(vNamesLow, 'viscos');
            isSignalName = contains(vNamesLow, 'signal') | contains(vNamesLow, 'relaxation') | ...
                contains(vNamesLow, 'value') | contains(vNamesLow, 'data') | contains(vNamesLow, 'mag') | ...
                contains(vNamesLow, 'm');
            isDerivName = isDerivName(:);
            isSignalName = isSignalName(:);
            allIdx = (1:numel(vNames))';

            idxSigDirect = find(isSignalName & ~isDerivName & (allIdx ~= idxTime));
            idxSigDeriv = find(isDerivName & (allIdx ~= idxTime));

            idxSignal = [];
            reconstructFromDerivative = false;

            % prefer direct M-like columns
            if ~isempty(idxSigDirect)
                bestSigScore = -Inf;
                for ic = 1:numel(idxSigDirect)
                    k = idxSigDirect(ic);
                    colRaw = T{:, k};
                    if ~isnumeric(colRaw), continue; end
                    col = double(colRaw(:));
                    if nnz(isfinite(col)) < 3, continue; end
                    score = 0;
                    if contains(vNamesLow(k), 'mag'), score = score + 80; end
                    if contains(vNamesLow(k), 'signal'), score = score + 60; end
                    if contains(vNamesLow(k), 'relaxation'), score = score + 50; end
                    if contains(vNamesLow(k), 'data'), score = score + 120; end
                    if contains(vNamesLow(k), 'value'), score = score + 30; end
                    if contains(vNamesLow(k), 'm'), score = score + 10; end
                    if contains(vNamesLow(k), 'residual'), score = score - 40; end
                    score = score + nnz(isfinite(col)) / max(height(T), 1);
                    if score > bestSigScore
                        bestSigScore = score;
                        idxSignal = k;
                    end
                end
            end

            if isempty(idxSignal) && ~isempty(idxSigDeriv)
                idxSignal = idxSigDeriv(1);
                reconstructFromDerivative = true;
            end

            if isempty(idxSignal)
                debugTbl = [debugTbl; {filePath, timeColUsed, "", 0, "NO", "NO", "NO"}]; %#ok<AGROW>
                continue;
            end
            signalColUsed = vNames(idxSignal);
            if any(idxSigDeriv == idxSignal)
                reconstructFromDerivative = true;
            end

            timeRawAll = double(T{:, idxTime});
            sigRawAll = double(T{:, idxSignal});

            % Group by temperature when available
            tGroups = NaN(0, 1);
            if any(isfinite(Tcol))
                tGroups = unique(Tcol(isfinite(Tcol)), 'stable');
            end

            if isempty(tGroups)
                % Try temperature from filename if present, else NaN
                tok = regexp(char(filePath), '([0-9]+(?:\.[0-9]+)?)\s*[kK]', 'tokens', 'once');
                if ~isempty(tok)
                    tGroups = str2double(tok{1});
                else
                    tGroups = NaN;
                end
            end

            groupValidCount = 0;
            groupMonoAll = true;
            for ig = 1:numel(tGroups)
                Tg = tGroups(ig);
                if isnan(Tg)
                    mG = true(height(T), 1);
                else
                    mG = isfinite(Tcol) & abs(Tcol - Tg) < 1e-9;
                end

                tvec = timeRawAll(mG);
                svec = sigRawAll(mG);
                mFin = isfinite(tvec) & isfinite(svec);
                tvec = tvec(mFin);
                svec = svec(mFin);
                if numel(tvec) < 5
                    continue;
                end

                isLogAxis = contains(lower(timeColUsed), 'log_t') | contains(lower(timeColUsed), 'logt') | ...
                    contains(lower(timeColUsed), 'log10') | contains(lower(timeColUsed), 'log');
                if isLogAxis
                    logt = tvec;
                else
                    mPos = tvec > 0 & isfinite(tvec);
                    logt = NaN(size(tvec));
                    logt(mPos) = log(tvec(mPos));
                end
                mFin2 = isfinite(logt) & isfinite(svec);
                logt = logt(mFin2);
                svec = svec(mFin2);
                if numel(logt) < 5
                    continue;
                end

                dRaw = diff(logt);
                monoRaw = all(dRaw >= 0) || all(dRaw <= 0);
                if ~monoRaw
                    groupMonoAll = false;
                end

                [logtSort, ord] = sort(logt, 'ascend');
                sSort = svec(ord);

                if reconstructFromDerivative
                    Mvec = cumtrapz(logtSort, sSort);
                else
                    Mvec = sSort;
                end

                d1 = diff(Mvec);
                d2 = diff(d1);
                sigStd = std(Mvec, 'omitnan');
                if ~isfinite(sigStd), sigStd = 0; end
                if isempty(d2)
                    rough = Inf;
                else
                    rough = median(abs(d2), 'omitnan') / max(sigStd, eps);
                end
                varies = any(abs(diff(Mvec)) > 0);
                smoothEnough = isfinite(rough) && rough < 100;
                validGroup = monoRaw && smoothEnough && varies && numel(logtSort) >= 10;

                if validGroup
                    groupValidCount = groupValidCount + 1;
                    Tadd = repmat(Tg, numel(logtSort), 1);
                    if isnan(Tg), Tadd(:) = NaN; end
                    fileAdd = repmat(filePath, numel(logtSort), 1);
                    tAdd = repmat(timeColUsed, numel(logtSort), 1);
                    sAdd = repmat(signalColUsed, numel(logtSort), 1);
                    extractTbl = [extractTbl; table(Tadd, logtSort, Mvec, fileAdd, tAdd, sAdd, ...
                        'VariableNames', {'T_K', 'log_t', 'M', 'source_file', 'time_column', 'signal_column'})]; %#ok<AGROW>
                    nPtsFile = nPtsFile + numel(logtSort);
                    if isLogAxis
                        isLogAxisFile = "YES";
                    else
                        isLogAxisFile = "NO";
                    end
                end
            end

            if groupValidCount > 0
                validFile = "YES";
                fileIsValid(ifile) = true;
                validPointsPerFile(ifile) = nPtsFile;
                usedFilesList(end+1, 1) = filePath; %#ok<SAGROW>
            end
            if groupMonoAll
                isMonoFile = "YES";
            else
                isMonoFile = "NO";
            end

            debugTbl = [debugTbl; {filePath, timeColUsed, signalColUsed, nPtsFile, isMonoFile, isLogAxisFile, validFile}]; %#ok<AGROW>
        catch fileErr
            debugTbl = [debugTbl; {filePath, timeColUsed, signalColUsed, nPtsFile, "NO", "NO", "NO"}]; %#ok<AGROW>
            fidErr = fopen(errorLogPath, 'a');
            if fidErr ~= -1
                fprintf(fidErr, '%s\n', getReport(fileErr, 'basic'));
                fclose(fidErr);
            end
        end
    end

    N_VALID_FILES = nnz(fileIsValid);
    if N_VALID_FILES > 0
        USED_FILES = strjoin(cellstr(unique(usedFilesList, 'stable')), '; ');
    else
        USED_FILES = "";
    end

    if ~isempty(extractTbl)
        if any(isfinite(extractTbl.T_K))
            if numel(unique(extractTbl.T_K(isfinite(extractTbl.T_K)))) > 1
                HAS_MULTIPLE_T = "YES";
            end
        end
    end

    hasLarge = false;
    if any(isfinite(validPointsPerFile))
        hasLarge = any(validPointsPerFile(fileIsValid) > 50);
    end
    if N_VALID_FILES > 0 && hasLarge
        VALID_RELAXATION_FOUND = "YES";
    else
        VALID_RELAXATION_FOUND = "NO";
    end

    EXECUTION_STATUS = "SUCCESS";

    md(end+1) = "## Inputs scanned (strict)";
    for i = 1:numel(runDirs)
        md(end+1) = "- `" + string(runDirs{i}) + "`";
    end
    md(end+1) = "";
    md(end+1) = "## Result summary";
    md(end+1) = "- VALID_RELAXATION_FOUND: `" + VALID_RELAXATION_FOUND + "`";
    md(end+1) = "- N_VALID_FILES: `" + string(N_VALID_FILES) + "`";
    md(end+1) = "- HAS_MULTIPLE_T: `" + HAS_MULTIPLE_T + "`";
    md(end+1) = "- USED_FILES: `" + string(USED_FILES) + "`";
    md(end+1) = "- Extracted rows: `" + string(height(extractTbl)) + "`";
catch ME
    EXECUTION_STATUS = "FAIL";
    ERROR_MESSAGE = string(ME.message);
    fidErr = fopen(errorLogPath, 'a');
    if fidErr ~= -1
        fprintf(fidErr, '%s\n', getReport(ME, 'extended'));
        fclose(fidErr);
    end
    md(end+1) = "## Execution failure";
    md(end+1) = "- ERROR: `" + ERROR_MESSAGE + "`";
end

if isempty(extractTbl)
    extractTbl = table(NaN, NaN, NaN, "", "", "", ...
        'VariableNames', {'T_K', 'log_t', 'M', 'source_file', 'time_column', 'signal_column'});
end
if isempty(debugTbl)
    debugTbl = table("", "", "", 0, "NO", "NO", "NO", ...
        'VariableNames', {'file_path', 'time_column', 'signal_column', 'n_points', 'is_monotonic', 'is_log_axis', 'valid_relaxation'});
end

statusTbl = table(string(VALID_RELAXATION_FOUND), N_VALID_FILES, string(USED_FILES), string(HAS_MULTIPLE_T), ...
    string(EXECUTION_STATUS), string(ERROR_MESSAGE), ...
    'VariableNames', {'VALID_RELAXATION_FOUND', 'N_VALID_FILES', 'USED_FILES', 'HAS_MULTIPLE_T', 'EXECUTION_STATUS', 'ERROR_MESSAGE'});

writetable(extractTbl, outExtracted);
writetable(debugTbl, outDebug);
writetable(statusTbl, outStatus);

fid = fopen(outReport, 'w');
if fid ~= -1
    fprintf(fid, '%s\n', char(strjoin(md, newline)));
    fclose(fid);
else
    statusTbl.EXECUTION_STATUS = "FAIL_REPORT_WRITE";
    statusTbl.ERROR_MESSAGE = "Could not write relaxation extraction report.";
    writetable(statusTbl, outStatus);
end

fprintf('[DONE] run_relaxation_extraction_from_known_runs -> %s\n', outStatus);
