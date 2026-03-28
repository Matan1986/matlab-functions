% LOCATE_RELAXATION_RAW_RUNS  Locate raw relaxation S(t) candidates in .mat artifacts.
% Pure script, no local functions.
%
% Run:
%   tools/run_matlab_safe.bat C:\Dev\matlab-functions\Switching\analysis\locate_relaxation_raw_runs.m
%   eval(fileread('C:/Dev/matlab-functions/Switching/analysis/locate_relaxation_raw_runs.m'))

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

outCsv = 'C:/Dev/matlab-functions/tables/relaxation_raw_candidates.csv';
outMd = 'C:/Dev/matlab-functions/reports/relaxation_raw_candidates.md';
outStatus = 'C:/Dev/matlab-functions/tables/relaxation_raw_status.csv';

EXECUTION_STATUS = 'FAIL';
N_FILES = 0;
VALID_RELAXATION_FOUND = 'NO';
BEST_CANDIDATE = '';
ERROR_MESSAGE = '';

file_path = strings(0, 1);
variable_name = strings(0, 1);
has_time_axis = strings(0, 1);
has_signal = strings(0, 1);
time_length = zeros(0, 1);
signal_shape = strings(0, 1);
is_valid_relaxation = strings(0, 1);

bestScore = -inf;

try
    matFiles = {};
    if exist(resultsRoot, 'dir') == 7
        d = dir(fullfile(resultsRoot, '**', '*.mat'));
        for i = 1:numel(d)
            if ~d(i).isdir
                matFiles{end + 1} = fullfile(d(i).folder, d(i).name); %#ok<AGROW>
            end
        end
    end
    matFiles = sort(matFiles);
    N_FILES = numel(matFiles);

    for i = 1:numel(matFiles)
        fp = matFiles{i};
        vars = whos('-file', fp);
        if isempty(vars)
            continue;
        end

        for v = 1:numel(vars)
            vname = string(vars(v).name);
            lowName = lower(vname);

            varHasTime = false;
            varHasSignal = false;
            tLen = 0;
            sigShape = "";
            isValid = false;
            monotonicTime = false;

            if contains(lowName, 'time') || strcmp(lowName, "t") || contains(lowName, 'sec')
                varHasTime = true;
            end
            if contains(lowName, 'signal') || contains(lowName, 'magnet') || strcmp(lowName, "s") ...
                    || strcmp(lowName, "m") || contains(lowName, 'delta_m') || contains(lowName, 'deltam')
                varHasSignal = true;
            end

            loadData = load(fp, char(vname));
            x = loadData.(char(vname));

            if isnumeric(x) || islogical(x)
                s = size(x);
                sigShape = string(mat2str(s));
                n = numel(x);

                if n >= 3 && (varHasTime || contains(lowName, 'axis'))
                    xv = double(x(:));
                    if all(isfinite(xv))
                        dx = diff(xv);
                        if all(dx >= 0) || all(dx <= 0)
                            monotonicTime = true;
                            varHasTime = true;
                            tLen = n;
                        end
                    end
                end

                if ~varHasSignal
                    if numel(s) >= 2
                        if (s(1) > 1 && s(2) > 1) || n > 5
                            if contains(lowName, 'map') || contains(lowName, 'trace') || contains(lowName, 'curve')
                                varHasSignal = true;
                            end
                        end
                    end
                end
            elseif isstruct(x)
                fns = fieldnames(x);
                sigShape = "struct";
                for fi = 1:numel(fns)
                    f = string(fns{fi});
                    lf = lower(f);
                    if contains(lf, 'time') || strcmp(lf, "t") || contains(lf, 'sec')
                        varHasTime = true;
                    end
                    if contains(lf, 'signal') || contains(lf, 'magnet') || strcmp(lf, "s") ...
                            || strcmp(lf, "m") || contains(lf, 'delta_m') || contains(lf, 'deltam')
                        varHasSignal = true;
                    end
                end

                if ~isempty(x)
                    x0 = x(1);
                    fns0 = fieldnames(x0);
                    timeField = "";
                    signalField = "";
                    for fi = 1:numel(fns0)
                        f = string(fns0{fi});
                        lf = lower(f);
                        if strlength(timeField) == 0
                            if contains(lf, 'time') || strcmp(lf, "t") || contains(lf, 'sec')
                                timeField = f;
                            end
                        end
                        if strlength(signalField) == 0
                            if contains(lf, 'signal') || contains(lf, 'magnet') || strcmp(lf, "s") ...
                                    || strcmp(lf, "m") || contains(lf, 'delta_m') || contains(lf, 'deltam')
                                signalField = f;
                            end
                        end
                    end

                    if strlength(timeField) > 0 && isfield(x0, char(timeField))
                        tCand = x0.(char(timeField));
                        if isnumeric(tCand) || islogical(tCand)
                            tv = double(tCand(:));
                            if numel(tv) >= 3 && all(isfinite(tv))
                                dtt = diff(tv);
                                if all(dtt >= 0) || all(dtt <= 0)
                                    monotonicTime = true;
                                    tLen = numel(tv);
                                    varHasTime = true;
                                end
                            end
                        end
                    end

                    if strlength(signalField) > 0
                        varHasSignal = true;
                        sc = x0.(char(signalField));
                        if isnumeric(sc) || islogical(sc)
                            sigShape = string(mat2str(size(sc)));
                        end
                    end
                end
            else
                sigShape = string(class(x));
            end

            if varHasTime && varHasSignal && tLen >= 3 && monotonicTime
                isValid = true;
            end

            if varHasTime || varHasSignal
                file_path(end + 1, 1) = string(fp); %#ok<AGROW>
                variable_name(end + 1, 1) = vname; %#ok<AGROW>
                if varHasTime, has_time_axis(end + 1, 1) = "YES"; else, has_time_axis(end + 1, 1) = "NO"; end %#ok<AGROW>
                if varHasSignal, has_signal(end + 1, 1) = "YES"; else, has_signal(end + 1, 1) = "NO"; end %#ok<AGROW>
                time_length(end + 1, 1) = tLen; %#ok<AGROW>
                signal_shape(end + 1, 1) = sigShape; %#ok<AGROW>
                if isValid, is_valid_relaxation(end + 1, 1) = "YES"; else, is_valid_relaxation(end + 1, 1) = "NO"; end %#ok<AGROW>
            end

            if isValid
                VALID_RELAXATION_FOUND = 'YES';
                score = double(tLen);
                if score > bestScore
                    bestScore = score;
                    BEST_CANDIDATE = char(string(fp) + " :: " + vname);
                end
            end
        end
    end

    outTbl = table(file_path, variable_name, has_time_axis, has_signal, time_length, signal_shape, is_valid_relaxation, ...
        'VariableNames', {'file_path', 'variable_name', 'has_time_axis', 'has_signal', 'time_length', 'signal_shape', 'is_valid_relaxation'});
    writetable(outTbl, outCsv);

    EXECUTION_STATUS = 'SUCCESS';
catch ME
    ERROR_MESSAGE = getReport(ME);
    EXECUTION_STATUS = 'FAIL';
    writetable(table(), outCsv);
end

statusTbl = table({EXECUTION_STATUS}, N_FILES, {VALID_RELAXATION_FOUND}, {BEST_CANDIDATE}, {ERROR_MESSAGE}, ...
    'VariableNames', {'EXECUTION_STATUS', 'N_FILES', 'VALID_RELAXATION_FOUND', 'BEST_CANDIDATE', 'ERROR_MESSAGE'});
writetable(statusTbl, outStatus);

md = cell(0, 1);
md{end + 1, 1} = '# Relaxation raw run candidates';
md{end + 1, 1} = '';
md{end + 1, 1} = sprintf('**EXECUTION_STATUS:** %s', EXECUTION_STATUS);
md{end + 1, 1} = sprintf('**N_FILES:** %d', N_FILES);
md{end + 1, 1} = sprintf('**VALID_RELAXATION_FOUND:** %s', VALID_RELAXATION_FOUND);
md{end + 1, 1} = sprintf('**BEST_CANDIDATE:** `%s`', strrep(BEST_CANDIDATE, '\', '/'));
md{end + 1, 1} = '';
md{end + 1, 1} = '## Candidate variables';
md{end + 1, 1} = '| file_path | variable_name | has_time_axis | has_signal | time_length | signal_shape | is_valid_relaxation |';
md{end + 1, 1} = '|---|---|:--:|:--:|---:|---|:--:|';

try
    if exist('outTbl', 'var') == 1 && height(outTbl) > 0
        for r = 1:height(outTbl)
            md{end + 1, 1} = sprintf('| `%s` | `%s` | %s | %s | %d | `%s` | %s |', ...
                strrep(char(outTbl.file_path(r)), '\', '/'), ...
                char(outTbl.variable_name(r)), ...
                char(outTbl.has_time_axis(r)), ...
                char(outTbl.has_signal(r)), ...
                outTbl.time_length(r), ...
                char(outTbl.signal_shape(r)), ...
                char(outTbl.is_valid_relaxation(r)));
        end
    else
        md{end + 1, 1} = '| _none_ | _none_ | NO | NO | 0 | _n/a_ | NO |';
    end
catch
    md{end + 1, 1} = '| _error_rendering_table_ |  |  |  |  |  |  |';
end

if ~isempty(ERROR_MESSAGE)
    md{end + 1, 1} = '';
    md{end + 1, 1} = '## ERROR_MESSAGE';
    md{end + 1, 1} = '```';
    md{end + 1, 1} = ERROR_MESSAGE;
    md{end + 1, 1} = '```';
end

fid = fopen(outMd, 'w');
if fid > 0
    for i = 1:numel(md)
        fprintf(fid, '%s\n', md{i});
    end
    fclose(fid);
end
