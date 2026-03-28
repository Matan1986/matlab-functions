% INSPECT_RELAXATION_DATA_STRUCTURE  Scan CSV headers/shape under results/aging and results/switching only.
% Read-only: no transforms, no tau extraction. Column heuristics use contains() only.
%
% Run: tools/run_matlab_safe.bat C:\Dev\matlab-functions\Switching\analysis\inspect_relaxation_data_structure.m
%      eval(fileread('C:/Dev/matlab-functions/Switching/analysis/inspect_relaxation_data_structure.m'))

repoRoot = 'C:/Dev/matlab-functions';
agingRoot = fullfile(repoRoot, 'results', 'aging');
switchRoot = fullfile(repoRoot, 'results', 'switching');
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

outCsv = 'C:/Dev/matlab-functions/tables/relaxation_structure_scan.csv';
outMd = 'C:/Dev/matlab-functions/reports/relaxation_structure_scan.md';
outStatus = 'C:/Dev/matlab-functions/tables/relaxation_structure_status.csv';

maxFiles = 20;
EXECUTION_STATUS = 'FAIL';
N_FILES_SCANNED = 0;
LONG_FORMAT_FOUND = 'NO';
WIDE_FORMAT_FOUND = 'NO';
LIKELY_SOURCE_FILE = '';
ERROR_MESSAGE = '';

scanRows = table();
col_names_cell = cell(0, 1);

try
    csvList = {};
    for root = {agingRoot, switchRoot}
        r = root{1};
        if exist(r, 'dir') ~= 7
            continue;
        end
        p = genpath(r);
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
    nAvail = numel(csvList);
    nTake = min(maxFiles, nAvail);
    if nTake > 0
        csvList = csvList(1:nTake);
    else
        csvList = {};
    end

    file_path = strings(0, 1);
    n_rows = zeros(0, 1);
    n_cols = zeros(0, 1);
    has_temperature = strings(0, 1);
    has_time = strings(0, 1);
    has_signal = strings(0, 1);
    format_type = strings(0, 1);
    col_names_cell = cell(0, 1);

    for ii = 1:numel(csvList)
        fp = csvList{ii};
        ht = 0;
        wt = 0;
        vn = {''};
        htemperature = false;
        htime = false;
        hsignal = false;
        timeLikeCount = 0;
        try
            T = readtable(fp, 'VariableNamingRule', 'preserve');
            ht = height(T);
            wt = width(T);
            vn = T.Properties.VariableNames;
        catch ME
            ERROR_MESSAGE = getReport(ME);
            ht = NaN;
            wt = NaN;
            vn = {''};
        end

        for jc = 1:numel(vn)
            low = lower(string(vn{jc}));
            if contains(low, 't_k') || (contains(low, 'tp') && strlength(low) <= 3) || contains(low, 'temperature')
                htemperature = true;
            end
            if contains(low, 'tau') && contains(low, 'second')
                continue;
            end
            isTimeLike = false;
            if (contains(low, 'time') && ~contains(low, 'temperature')) ...
                    || (contains(low, 'second') && ~contains(low, 'tau'))
                isTimeLike = true;
            end
            if contains(low, 't_') && ~contains(low, 't_k')
                isTimeLike = true;
            end
            if isTimeLike
                htime = true;
                timeLikeCount = timeLikeCount + 1;
            end
            if contains(low, 'signal') || contains(low, 'relaxation') ...
                    || (strlength(low) == 1 && contains(low, 's')) ...
                    || (contains(low, 'normalized') && contains(low, 'signal'))
                hsignal = true;
            end
        end

        fmt = "unknown";
        if htemperature && htime && hsignal && timeLikeCount <= 2 && wt <= 25
            fmt = "long";
        elseif htemperature && htime && (timeLikeCount >= 3 || wt > 40)
            fmt = "wide";
        elseif htemperature && ~htime
            fmt = "feature";
        elseif ~htime && wt > 0
            fmt = "feature";
        else
            fmt = "unknown";
        end

        if fmt == "unknown" && htemperature && hsignal && ~htime
            fmt = "feature";
        end

        if htemperature
            ynT = "YES";
        else
            ynT = "NO";
        end
        if htime
            ynTi = "YES";
        else
            ynTi = "NO";
        end
        if hsignal
            ynS = "YES";
        else
            ynS = "NO";
        end

        file_path(end + 1, 1) = string(fp); %#ok<AGROW>
        n_rows(end + 1, 1) = ht; %#ok<AGROW>
        n_cols(end + 1, 1) = wt; %#ok<AGROW>
        has_temperature(end + 1, 1) = ynT; %#ok<AGROW>
        has_time(end + 1, 1) = ynTi; %#ok<AGROW>
        has_signal(end + 1, 1) = ynS; %#ok<AGROW>
        format_type(end + 1, 1) = fmt; %#ok<AGROW>
        col_names_cell{end + 1, 1} = strjoin(string(vn), '; '); %#ok<AGROW>

        if fmt == "long"
            LONG_FORMAT_FOUND = 'YES';
            if isempty(LIKELY_SOURCE_FILE)
                LIKELY_SOURCE_FILE = fp;
            end
        end
        if fmt == "wide"
            WIDE_FORMAT_FOUND = 'YES';
        end
    end

    N_FILES_SCANNED = numel(csvList);

    scanRows = table(file_path, n_rows, n_cols, has_temperature, has_time, has_signal, format_type, ...
        'VariableNames', {'file_path', 'n_rows', 'n_cols', 'has_temperature', 'has_time', 'has_signal', 'format_type'});

    writetable(scanRows, outCsv);

    EXECUTION_STATUS = 'SUCCESS';

catch ME
    ERROR_MESSAGE = getReport(ME);
    EXECUTION_STATUS = 'FAIL';
    writetable(table(), outCsv);
end

if isempty(ERROR_MESSAGE)
    ERROR_MESSAGE = '';
end

st = table( ...
    {EXECUTION_STATUS}, N_FILES_SCANNED, {LONG_FORMAT_FOUND}, {WIDE_FORMAT_FOUND}, {LIKELY_SOURCE_FILE}, {ERROR_MESSAGE}, ...
    'VariableNames', {'EXECUTION_STATUS', 'N_FILES_SCANNED', 'LONG_FORMAT_FOUND', 'WIDE_FORMAT_FOUND', 'LIKELY_SOURCE_FILE', 'ERROR_MESSAGE'});
writetable(st, outStatus);

lines = cell(0, 1);
lines{end + 1, 1} = '# Relaxation data structure scan';
lines{end + 1, 1} = '';
lines{end + 1, 1} = sprintf('**Scope:** `%s`, `%s` (first ~%d CSV files, sorted paths)', ...
    strrep(agingRoot, '\', '/'), strrep(switchRoot, '\', '/'), maxFiles);
lines{end + 1, 1} = sprintf('**EXECUTION_STATUS:** %s', EXECUTION_STATUS);
lines{end + 1, 1} = sprintf('**N_FILES_SCANNED:** %d', N_FILES_SCANNED);
lines{end + 1, 1} = sprintf('**LONG_FORMAT_FOUND:** %s', LONG_FORMAT_FOUND);
lines{end + 1, 1} = sprintf('**WIDE_FORMAT_FOUND:** %s', WIDE_FORMAT_FOUND);
lines{end + 1, 1} = sprintf('**LIKELY_SOURCE_FILE:** `%s`', strrep(LIKELY_SOURCE_FILE, '\', '/'));
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Per-file summary';
lines{end + 1, 1} = '| file | n_rows | n_cols | temp | time | signal | format |';
lines{end + 1, 1} = '|---|---:|---:|:--:|:--:|:--:|:---|';
for ir = 1:height(scanRows)
    lines{end + 1, 1} = sprintf('| `%s` | %g | %g | %s | %s | %s | %s |', ...
        strrep(char(scanRows.file_path(ir)), '\', '/'), scanRows.n_rows(ir), scanRows.n_cols(ir), ...
        char(scanRows.has_temperature(ir)), char(scanRows.has_time(ir)), char(scanRows.has_signal(ir)), ...
        char(scanRows.format_type(ir)));
end
lines{end + 1, 1} = '';
lines{end + 1, 1} = '## Column names (semicolon-separated)';
for ir = 1:height(scanRows)
    lines{end + 1, 1} = sprintf('- **%s**', strrep(char(scanRows.file_path(ir)), '\', '/'));
    lines{end + 1, 1} = sprintf('  `%s`', col_names_cell{ir});
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
