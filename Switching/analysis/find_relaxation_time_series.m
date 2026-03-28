% FIND_RELAXATION_TIME_SERIES  Detect true relaxation time-series CSVs under results/.
% Pure script, no functions. Uses contains() heuristics only.
%
% Run with:
%   tools/run_matlab_safe.bat C:\Dev\matlab-functions\Switching\analysis\find_relaxation_time_series.m
%   eval(fileread('C:/Dev/matlab-functions/Switching/analysis/find_relaxation_time_series.m'))

repoRoot = 'C:/Dev/matlab-functions';
resultsRoot = fullfile(repoRoot, 'results');
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

outCsv = 'C:/Dev/matlab-functions/tables/relaxation_time_series_scan.csv';
outMd = 'C:/Dev/matlab-functions/reports/relaxation_time_series_scan.md';
outStatus = 'C:/Dev/matlab-functions/tables/relaxation_time_series_status.csv';

EXECUTION_STATUS = 'FAIL';
N_FILES = 0;
VALID_RELAXATION_FOUND = 'NO';
BEST_CANDIDATE = '';
ERROR_MESSAGE = '';

scanTbl = table();

try
    csvList = {};
    if exist(resultsRoot, 'dir') == 7
        p = genpath(resultsRoot);
        parts = strsplit(p, pathsep);
        for ip = 1:numel(parts)
            folder = parts{ip};
            if isempty(folder)
                continue;
            end
            d = dir(fullfile(folder, '*.csv'));
            for k = 1:numel(d)
                if ~d(k).isdir
                    csvList{end + 1} = fullfile(folder, d(k).name); %#ok<AGROW>
                end
            end
        end
    end
    csvList = sort(csvList);
    N_FILES = numel(csvList);

    file_path = strings(0, 1);
    has_time_axis = strings(0, 1);
    has_signal = strings(0, 1);
    signal_varies_with_time = strings(0, 1);
    valid_relaxation = strings(0, 1);
    score_valid = nan(0, 1);

    bestScore = -inf;
    bestPath = '';

    for i = 1:numel(csvList)
        fp = csvList{i};
        yn_time = "NO";
        yn_signal = "NO";
        yn_varies = "NO";
        yn_valid = "NO";
        score = NaN;

        try
            T = readtable(fp, 'VariableNamingRule', 'preserve');
            vn = T.Properties.VariableNames;
            nCols = numel(vn);

            rejectByName = false;
            lowPath = lower(string(fp));
            if contains(lowPath, 'tw_') || contains(lowPath, 'observable') || contains(lowPath, 'feature') ...
                    || contains(lowPath, 'svd') || contains(lowPath, 'mode')
                rejectByName = true;
            end

            timeIdx = [];
            signalIdx = [];
            for jc = 1:nCols
                low = lower(string(vn{jc}));

                if contains(low, 'tw_') || contains(low, 'wait_time')
                    rejectByName = true;
                end
                if contains(low, 'observable') || contains(low, 'feature') ...
                        || contains(low, 'svd') || contains(low, 'mode')
                    rejectByName = true;
                end

                isTime = false;
                if contains(low, 'tau') && contains(low, 'second')
                    isTime = false;
                elseif (contains(low, 'time') && ~contains(low, 'temperature')) ...
                        || (strlength(low) == 1 && contains(low, 't')) ...
                        || (contains(low, 'second') && ~contains(low, 'wait') && ~contains(low, 'tau') && ~contains(low, 'tw'))
                    isTime = true;
                end
                if isTime
                    timeIdx(end + 1) = jc; %#ok<AGROW>
                end

                isSignal = false;
                if contains(low, 'signal') || contains(low, 'magnet') || contains(low, 'delta_m') ...
                        || contains(low, 'deltam') || contains(low, 's(t)') || contains(low, 'relaxation_signal')
                    isSignal = true;
                elseif strlength(low) == 1 && contains(low, 's')
                    isSignal = true;
                end
                if isSignal
                    signalIdx(end + 1) = jc; %#ok<AGROW>
                end
            end

            if ~isempty(timeIdx)
                yn_time = "YES";
            end
            if ~isempty(signalIdx)
                yn_signal = "YES";
            end

            timeCol = [];
            sigCol = [];
            if ~isempty(timeIdx)
                for a = 1:numel(timeIdx)
                    cand = T{:, timeIdx(a)};
                    if isnumeric(cand)
                        timeCol = double(cand(:));
                        break;
                    end
                end
            end
            if ~isempty(signalIdx)
                for b = 1:numel(signalIdx)
                    cand = T{:, signalIdx(b)};
                    if isnumeric(cand)
                        sigCol = double(cand(:));
                        break;
                    end
                end
            end

            if ~isempty(timeCol) && ~isempty(sigCol)
                ok = isfinite(timeCol) & isfinite(sigCol);
                tx = timeCol(ok);
                sx = sigCol(ok);
                if numel(tx) >= 4
                    nTu = numel(unique(tx));
                    if nTu >= 3
                        [tu, ~, ic] = unique(tx);
                        su = accumarray(ic, sx, [], @mean);
                        if numel(unique(su)) >= 3
                            if range(su) > 0
                                yn_varies = "YES";
                            end
                        end
                        score = nTu;
                    end
                end
            end

            if rejectByName
                yn_valid = "NO";
            else
                if yn_time == "YES" && yn_signal == "YES" && yn_varies == "YES"
                    yn_valid = "YES";
                end
            end

            if yn_valid == "YES"
                if strcmp(VALID_RELAXATION_FOUND, 'NO')
                    VALID_RELAXATION_FOUND = 'YES';
                end
                if isfinite(score) && score > bestScore
                    bestScore = score;
                    bestPath = fp;
                end
            end

        catch ME_file
            if isempty(ERROR_MESSAGE)
                ERROR_MESSAGE = getReport(ME_file);
            end
        end

        file_path(end + 1, 1) = string(fp); %#ok<AGROW>
        has_time_axis(end + 1, 1) = yn_time; %#ok<AGROW>
        has_signal(end + 1, 1) = yn_signal; %#ok<AGROW>
        signal_varies_with_time(end + 1, 1) = yn_varies; %#ok<AGROW>
        valid_relaxation(end + 1, 1) = yn_valid; %#ok<AGROW>
        score_valid(end + 1, 1) = score; %#ok<AGROW>
    end

    if strcmp(VALID_RELAXATION_FOUND, 'YES')
        BEST_CANDIDATE = bestPath;
    else
        BEST_CANDIDATE = '';
    end

    scanTbl = table(file_path, has_time_axis, has_signal, signal_varies_with_time, valid_relaxation, ...
        'VariableNames', {'file_path', 'has_time_axis', 'has_signal', 'signal_varies_with_time', 'valid_relaxation'});
    writetable(scanTbl, outCsv);

    EXECUTION_STATUS = 'SUCCESS';

catch ME
    ERROR_MESSAGE = getReport(ME);
    EXECUTION_STATUS = 'FAIL';
    writetable(table(), outCsv);
end

statusTbl = table({EXECUTION_STATUS}, N_FILES, {VALID_RELAXATION_FOUND}, {BEST_CANDIDATE}, {ERROR_MESSAGE}, ...
    'VariableNames', {'EXECUTION_STATUS', 'N_FILES', 'VALID_RELAXATION_FOUND', 'BEST_CANDIDATE', 'ERROR_MESSAGE'});
writetable(statusTbl, outStatus);

lines = cell(0, 1);
lines{end + 1, 1} = '# Relaxation time-series scan';
lines{end + 1, 1} = '';
lines{end + 1, 1} = sprintf('**EXECUTION_STATUS:** %s', EXECUTION_STATUS);
lines{end + 1, 1} = sprintf('**N_FILES:** %d', N_FILES);
lines{end + 1, 1} = sprintf('**VALID_RELAXATION_FOUND:** %s', VALID_RELAXATION_FOUND);
lines{end + 1, 1} = sprintf('**BEST_CANDIDATE:** `%s`', strrep(BEST_CANDIDATE, '\', '/'));
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Per-file classification';
lines{end + 1, 1} = '| file | has_time_axis | has_signal | signal_varies_with_time | valid_relaxation |';
lines{end + 1, 1} = '|---|:--:|:--:|:--:|:--:|';
for r = 1:height(scanTbl)
    lines{end + 1, 1} = sprintf('| `%s` | %s | %s | %s | %s |', ...
        strrep(char(scanTbl.file_path(r)), '\', '/'), ...
        char(scanTbl.has_time_axis(r)), char(scanTbl.has_signal(r)), ...
        char(scanTbl.signal_varies_with_time(r)), char(scanTbl.valid_relaxation(r)));
end
if ~isempty(ERROR_MESSAGE)
    lines{end + 1, 1} = '';
    lines{end + 1, 1} = '## ERROR_MESSAGE';
    lines{end + 1, 1} = '```';
    lines{end + 1, 1} = ERROR_MESSAGE;
    lines{end + 1, 1} = '```';
end

fid = fopen(outMd, 'w');
if fid > 0
    for z = 1:numel(lines)
        fprintf(fid, '%s\n', lines{z});
    end
    fclose(fid);
end
