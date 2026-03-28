% RUN_RELAXATION_DEEP_SEARCH  Deep search for relaxation dynamics in selected runs.
% Pure script. No local functions.
%
% Run with:
%   tools/run_matlab_safe.bat C:\Dev\matlab-functions\Switching\analysis\run_relaxation_deep_search.m
%   eval(fileread('C:/Dev/matlab-functions/Switching/analysis/run_relaxation_deep_search.m'))

repoRoot = 'C:/Dev/matlab-functions';
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

outCandidates = 'C:/Dev/matlab-functions/tables/relaxation_deep_candidates.csv';
outSamples = 'C:/Dev/matlab-functions/tables/relaxation_trace_samples.csv';
outStatus = 'C:/Dev/matlab-functions/tables/relaxation_deep_status.csv';
outReport = 'C:/Dev/matlab-functions/reports/relaxation_deep_search.md';

targetDirs = { ...
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_10_150748_relaxation_observable_stability_audit'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_11_142636_beta_T_audit'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_11_143034_beta_T_audit'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_11_143323_beta_T_audit'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_11_195951_beta_T_audit'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_corrected_geometry'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_derivative_smoothing'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_legacy_geometry_maps'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_09_205312_derivative_smoothing'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_10_014001_coordinate_audit'
    'C:/Dev/matlab-functions/results/relaxation/runs/run_2026_03_10_015246_coordinate_extraction'
    };

VALID_RELAXATION_FOUND = 'NO';
N_CANDIDATES = 0;
BEST_CANDIDATE_PATH = '';
FOUND_VISCOSITY = 'NO';
RECONSTRUCTED_SIGNAL = 'NO';
ERROR_MESSAGE = '';

file_path = strings(0, 1);
variable_path = strings(0, 1);
time_path = strings(0, 1);
signal_path = strings(0, 1);
length_col = zeros(0, 1);
is_monotonic = strings(0, 1);
is_log_spaced = strings(0, 1);
is_viscosity = strings(0, 1);
score = zeros(0, 1);

sample_file_path = strings(0, 1);
sample_variable_path = strings(0, 1);
sample_kind = strings(0, 1);
sample_position = strings(0, 1);
sample_index = zeros(0, 1);
sample_time = zeros(0, 1);
sample_signal = zeros(0, 1);

try
    allMatFiles = {};
    allCsvFiles = {};
    allTxtFiles = {};
    for d = 1:numel(targetDirs)
        root = targetDirs{d};
        if exist(root, 'dir') ~= 7
            continue;
        end
        dm = dir(fullfile(root, '**', '*.mat'));
        for k = 1:numel(dm)
            if ~dm(k).isdir
                allMatFiles{end + 1} = fullfile(dm(k).folder, dm(k).name); %#ok<AGROW>
            end
        end
        dc = dir(fullfile(root, '**', '*.csv'));
        for k = 1:numel(dc)
            if ~dc(k).isdir
                allCsvFiles{end + 1} = fullfile(dc(k).folder, dc(k).name); %#ok<AGROW>
            end
        end
        dt = dir(fullfile(root, '**', '*.txt'));
        for k = 1:numel(dt)
            if ~dt(k).isdir
                allTxtFiles{end + 1} = fullfile(dt(k).folder, dt(k).name); %#ok<AGROW>
            end
        end
    end
    allMatFiles = sort(allMatFiles);
    allCsvFiles = sort(allCsvFiles);
    allTxtFiles = sort(allTxtFiles);

    topScore = -inf;
    topSignal = [];
    topTime = [];
    topVarPath = "";
    topFilePath = "";
    topIsVisc = false;

    for fi = 1:numel(allMatFiles)
        matPath = allMatFiles{fi};
        matData = load(matPath);
        rootFields = fieldnames(matData);

        stackVals = cell(0, 1);
        stackPaths = strings(0, 1);
        for rf = 1:numel(rootFields)
            nm = string(rootFields{rf});
            stackVals{end + 1, 1} = matData.(char(nm)); %#ok<AGROW>
            stackPaths(end + 1, 1) = nm; %#ok<AGROW>
        end

        vecPaths = strings(0, 1);
        vecVals = cell(0, 1);
        vecIsTimeLike = false(0, 1);
        vecIsSignalLike = false(0, 1);
        vecIsViscLike = false(0, 1);
        vecLen = zeros(0, 1);

        while ~isempty(stackVals)
            curVal = stackVals{end};
            curPath = stackPaths(end);
            stackVals(end) = [];
            stackPaths(end) = [];

            if isstruct(curVal)
                if isscalar(curVal)
                    fn = fieldnames(curVal);
                    for jf = 1:numel(fn)
                        f = string(fn{jf});
                        stackVals{end + 1, 1} = curVal.(char(f)); %#ok<AGROW>
                        stackPaths(end + 1, 1) = curPath + "." + f; %#ok<AGROW>
                    end
                else
                    nEl = numel(curVal);
                    for je = 1:nEl
                        fn = fieldnames(curVal(je));
                        for jf = 1:numel(fn)
                            f = string(fn{jf});
                            stackVals{end + 1, 1} = curVal(je).(char(f)); %#ok<AGROW>
                            stackPaths(end + 1, 1) = curPath + "(" + string(je) + ")." + f; %#ok<AGROW>
                        end
                    end
                end
            elseif iscell(curVal)
                for jc = 1:numel(curVal)
                    stackVals{end + 1, 1} = curVal{jc}; %#ok<AGROW>
                    stackPaths(end + 1, 1) = curPath + "{" + string(jc) + "}"; %#ok<AGROW>
                end
            else
                if isnumeric(curVal) || islogical(curVal)
                    n = numel(curVal);
                    if n >= 20
                        lowPath = lower(curPath);
                        isVec = isvector(curVal);
                        if isVec
                            x = double(curVal(:));
                            if all(isfinite(x))
                                isTimeLikeName = contains(lowPath, 'time') || contains(lowPath, '.t') || endsWith(lowPath, 't') || contains(lowPath, 'sec');
                                isSignalLikeName = contains(lowPath, 'signal') || contains(lowPath, 'magnet') || contains(lowPath, 'delta_m') ...
                                    || contains(lowPath, 'deltam') || contains(lowPath, 'trace') || contains(lowPath, 'curve') || contains(lowPath, 's(');
                                isViscName = contains(lowPath, 'viscos') || contains(lowPath, 'dlog') || contains(lowPath, 'deriv') || contains(lowPath, 'ds');
                                vecPaths(end + 1, 1) = curPath; %#ok<AGROW>
                                vecVals{end + 1, 1} = x; %#ok<AGROW>
                                vecIsTimeLike(end + 1, 1) = isTimeLikeName; %#ok<AGROW>
                                vecIsSignalLike(end + 1, 1) = isSignalLikeName; %#ok<AGROW>
                                vecIsViscLike(end + 1, 1) = isViscName; %#ok<AGROW>
                                vecLen(end + 1, 1) = n; %#ok<AGROW>
                            end
                        elseif ndims(curVal) <= 2
                            s = size(curVal);
                            if (s(1) >= 20 && s(2) >= 2) || (s(2) >= 20 && s(1) >= 2)
                                lowPath = lower(curPath);
                                isSignalLikeName = contains(lowPath, 'signal') || contains(lowPath, 'magnet') || contains(lowPath, 'delta_m') ...
                                    || contains(lowPath, 'deltam') || contains(lowPath, 'trace') || contains(lowPath, 'curve') || contains(lowPath, 's(');
                                isViscName = contains(lowPath, 'viscos') || contains(lowPath, 'dlog') || contains(lowPath, 'deriv') || contains(lowPath, 'ds');
                                vecPaths(end + 1, 1) = curPath; %#ok<AGROW>
                                vecVals{end + 1, 1} = double(curVal(:)); %#ok<AGROW>
                                vecIsTimeLike(end + 1, 1) = false; %#ok<AGROW>
                                vecIsSignalLike(end + 1, 1) = isSignalLikeName; %#ok<AGROW>
                                vecIsViscLike(end + 1, 1) = isViscName; %#ok<AGROW>
                                vecLen(end + 1, 1) = numel(curVal); %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end

        for ti = 1:numel(vecVals)
            tRaw = vecVals{ti};
            if numel(tRaw) < 20
                continue;
            end
            dt = diff(tRaw);
            monoInc = all(dt > 0);
            if ~monoInc
                continue;
            end
            dlog = diff(log(max(tRaw, eps)));
            logSp = false;
            if all(isfinite(dlog)) && ~isempty(dlog)
                if std(dlog) < 0.15 * max(abs(mean(dlog)), eps)
                    logSp = true;
                end
            end

            for si = 1:numel(vecVals)
                if si == ti
                    continue;
                end
                sRaw = vecVals{si};
                if numel(sRaw) ~= numel(tRaw)
                    continue;
                end
                if numel(sRaw) < 20
                    continue;
                end
                if max(sRaw) - min(sRaw) <= 0
                    continue;
                end
                d1 = diff(sRaw);
                d2 = diff(d1);
                smooth = 1 / (1 + std(d2) / max(std(d1), eps));
                if ~isfinite(smooth)
                    smooth = 0;
                end
                trend = abs(corr(tRaw, sRaw, 'rows', 'complete'));
                if ~isfinite(trend)
                    trend = 0;
                end
                logcorr = abs(corr(log(max(tRaw, eps)), sRaw, 'rows', 'complete'));
                if ~isfinite(logcorr)
                    logcorr = 0;
                end
                monoScore = 1.0;
                if logSp
                    logSpScore = 1.0;
                else
                    logSpScore = 0.0;
                end

                viscLike = vecIsViscLike(si) || contains(lower(vecPaths(si)), 'dlog') || contains(lower(vecPaths(si)), 'viscos');
                if viscLike
                    FOUND_VISCOSITY = 'YES';
                end

                sc = 0.35 * monoScore + 0.15 * logSpScore + 0.30 * smooth + 0.20 * max(trend, logcorr);
                if viscLike
                    sc = sc + 0.1;
                end

                file_path(end + 1, 1) = string(matPath); %#ok<AGROW>
                variable_path(end + 1, 1) = vecPaths(si); %#ok<AGROW>
                time_path(end + 1, 1) = vecPaths(ti); %#ok<AGROW>
                signal_path(end + 1, 1) = vecPaths(si); %#ok<AGROW>
                length_col(end + 1, 1) = numel(tRaw); %#ok<AGROW>
                is_monotonic(end + 1, 1) = "YES"; %#ok<AGROW>
                if logSp, is_log_spaced(end + 1, 1) = "YES"; else, is_log_spaced(end + 1, 1) = "NO"; end %#ok<AGROW>
                if viscLike, is_viscosity(end + 1, 1) = "YES"; else, is_viscosity(end + 1, 1) = "NO"; end %#ok<AGROW>
                score(end + 1, 1) = sc; %#ok<AGROW>

                if sc > topScore
                    topScore = sc;
                    topSignal = sRaw;
                    topTime = tRaw;
                    topVarPath = vecPaths(si);
                    topFilePath = string(matPath);
                    topIsVisc = viscLike;
                end
            end
        end
    end

    candTbl = table(file_path, variable_path, time_path, signal_path, length_col, is_monotonic, is_log_spaced, is_viscosity, score, ...
        'VariableNames', {'file_path', 'variable_path', 'time_path', 'signal_path', 'length', 'is_monotonic', 'is_log_spaced', 'is_viscosity', 'score'});
    if ~isempty(candTbl)
        candTbl = sortrows(candTbl, 'score', 'descend');
    end
    writetable(candTbl, outCandidates);

    N_CANDIDATES = height(candTbl);
    if N_CANDIDATES > 0
        ok = candTbl.length > 50 & candTbl.score > 0.55;
        if any(ok)
            VALID_RELAXATION_FOUND = 'YES';
            BEST_CANDIDATE_PATH = char(candTbl.file_path(find(ok, 1, 'first')) + " :: " + candTbl.variable_path(find(ok, 1, 'first')));
        elseif strcmp(FOUND_VISCOSITY, 'YES')
            VALID_RELAXATION_FOUND = 'YES';
            BEST_CANDIDATE_PATH = char(candTbl.file_path(1) + " :: " + candTbl.variable_path(1));
        else
            BEST_CANDIDATE_PATH = char(candTbl.file_path(1) + " :: " + candTbl.variable_path(1));
        end
    end

    if strcmp(FOUND_VISCOSITY, 'YES') && ~isempty(topTime) && ~isempty(topSignal) && topIsVisc
        sRec = cumtrapz(log(max(topTime, eps)), topSignal);
        topSignal = sRec;
        RECONSTRUCTED_SIGNAL = 'YES';
    end

    if ~isempty(candTbl)
        nTop = min(5, height(candTbl));
        for r = 1:nTop
            tPath = candTbl.time_path(r);
            sPath = candTbl.signal_path(r);
            fPath = candTbl.file_path(r);

            mData = load(char(fPath));
            rootNames = fieldnames(mData);
            stackVals = cell(0, 1);
            stackPaths = strings(0, 1);
            for rr = 1:numel(rootNames)
                nm = string(rootNames{rr});
                stackVals{end + 1, 1} = mData.(char(nm)); %#ok<AGROW>
                stackPaths(end + 1, 1) = nm; %#ok<AGROW>
            end
            tVec = [];
            sVec = [];
            while ~isempty(stackVals)
                curVal = stackVals{end};
                curPath = stackPaths(end);
                stackVals(end) = [];
                stackPaths(end) = [];
                if isstruct(curVal)
                    if isscalar(curVal)
                        fn = fieldnames(curVal);
                        for jf = 1:numel(fn)
                            f = string(fn{jf});
                            stackVals{end + 1, 1} = curVal.(char(f)); %#ok<AGROW>
                            stackPaths(end + 1, 1) = curPath + "." + f; %#ok<AGROW>
                        end
                    end
                elseif iscell(curVal)
                    for jc = 1:numel(curVal)
                        stackVals{end + 1, 1} = curVal{jc}; %#ok<AGROW>
                        stackPaths(end + 1, 1) = curPath + "{" + string(jc) + "}"; %#ok<AGROW>
                    end
                else
                    if (isnumeric(curVal) || islogical(curVal)) && isvector(curVal)
                        if curPath == tPath
                            tVec = double(curVal(:));
                        end
                        if curPath == sPath
                            sVec = double(curVal(:));
                        end
                    end
                end
            end

            if isempty(tVec) || isempty(sVec) || numel(tVec) ~= numel(sVec)
                continue;
            end
            n = numel(tVec);
            nSamp = min(30, n);
            idxFirst = (1:nSamp).';
            idxLast = ((n - nSamp + 1):n).';
            for k = 1:numel(idxFirst)
                ii = idxFirst(k);
                sample_file_path(end + 1, 1) = fPath; %#ok<AGROW>
                sample_variable_path(end + 1, 1) = sPath; %#ok<AGROW>
                sample_kind(end + 1, 1) = "original"; %#ok<AGROW>
                sample_position(end + 1, 1) = "first"; %#ok<AGROW>
                sample_index(end + 1, 1) = ii; %#ok<AGROW>
                sample_time(end + 1, 1) = tVec(ii); %#ok<AGROW>
                sample_signal(end + 1, 1) = sVec(ii); %#ok<AGROW>
            end
            for k = 1:numel(idxLast)
                ii = idxLast(k);
                sample_file_path(end + 1, 1) = fPath; %#ok<AGROW>
                sample_variable_path(end + 1, 1) = sPath; %#ok<AGROW>
                sample_kind(end + 1, 1) = "original"; %#ok<AGROW>
                sample_position(end + 1, 1) = "last"; %#ok<AGROW>
                sample_index(end + 1, 1) = ii; %#ok<AGROW>
                sample_time(end + 1, 1) = tVec(ii); %#ok<AGROW>
                sample_signal(end + 1, 1) = sVec(ii); %#ok<AGROW>
            end
        end
    end

    if strcmp(RECONSTRUCTED_SIGNAL, 'YES') && ~isempty(topTime) && ~isempty(topSignal)
        n = numel(topTime);
        nSamp = min(30, n);
        idxFirst = (1:nSamp).';
        idxLast = ((n - nSamp + 1):n).';
        for k = 1:numel(idxFirst)
            ii = idxFirst(k);
            sample_file_path(end + 1, 1) = topFilePath; %#ok<AGROW>
            sample_variable_path(end + 1, 1) = topVarPath; %#ok<AGROW>
            sample_kind(end + 1, 1) = "reconstructed"; %#ok<AGROW>
            sample_position(end + 1, 1) = "first"; %#ok<AGROW>
            sample_index(end + 1, 1) = ii; %#ok<AGROW>
            sample_time(end + 1, 1) = topTime(ii); %#ok<AGROW>
            sample_signal(end + 1, 1) = topSignal(ii); %#ok<AGROW>
        end
        for k = 1:numel(idxLast)
            ii = idxLast(k);
            sample_file_path(end + 1, 1) = topFilePath; %#ok<AGROW>
            sample_variable_path(end + 1, 1) = topVarPath; %#ok<AGROW>
            sample_kind(end + 1, 1) = "reconstructed"; %#ok<AGROW>
            sample_position(end + 1, 1) = "last"; %#ok<AGROW>
            sample_index(end + 1, 1) = ii; %#ok<AGROW>
            sample_time(end + 1, 1) = topTime(ii); %#ok<AGROW>
            sample_signal(end + 1, 1) = topSignal(ii); %#ok<AGROW>
        end
    end

    smpTbl = table(sample_file_path, sample_variable_path, sample_kind, sample_position, sample_index, sample_time, sample_signal, ...
        'VariableNames', {'file_path', 'variable_path', 'sample_kind', 'sample_position', 'index', 'time', 'signal'});
    writetable(smpTbl, outSamples);

catch ME
    ERROR_MESSAGE = getReport(ME);
    emptyCand = table('Size', [0 9], ...
        'VariableTypes', {'string','string','string','string','double','string','string','string','double'}, ...
        'VariableNames', {'file_path','variable_path','time_path','signal_path','length','is_monotonic','is_log_spaced','is_viscosity','score'});
    writetable(emptyCand, outCandidates);
    emptySmp = table('Size', [0 7], ...
        'VariableTypes', {'string','string','string','string','double','double','double'}, ...
        'VariableNames', {'file_path','variable_path','sample_kind','sample_position','index','time','signal'});
    writetable(emptySmp, outSamples);
end

statusTbl = table({VALID_RELAXATION_FOUND}, N_CANDIDATES, {BEST_CANDIDATE_PATH}, {FOUND_VISCOSITY}, {RECONSTRUCTED_SIGNAL}, {ERROR_MESSAGE}, ...
    'VariableNames', {'VALID_RELAXATION_FOUND', 'N_CANDIDATES', 'BEST_CANDIDATE_PATH', 'FOUND_VISCOSITY', 'RECONSTRUCTED_SIGNAL', 'ERROR_MESSAGE'});
writetable(statusTbl, outStatus);

md = cell(0,1);
md{end+1,1} = '# Relaxation deep search';
md{end+1,1} = '';
md{end+1,1} = sprintf('- VALID_RELAXATION_FOUND: %s', VALID_RELAXATION_FOUND);
md{end+1,1} = sprintf('- N_CANDIDATES: %d', N_CANDIDATES);
md{end+1,1} = sprintf('- BEST_CANDIDATE_PATH: `%s`', strrep(BEST_CANDIDATE_PATH, '\', '/'));
md{end+1,1} = sprintf('- FOUND_VISCOSITY: %s', FOUND_VISCOSITY);
md{end+1,1} = sprintf('- RECONSTRUCTED_SIGNAL: %s', RECONSTRUCTED_SIGNAL);
md{end+1,1} = sprintf('- MAT files scanned: %d', numel(allMatFiles));
md{end+1,1} = sprintf('- CSV files discovered: %d', numel(allCsvFiles));
md{end+1,1} = sprintf('- TXT files discovered: %d', numel(allTxtFiles));
if ~isempty(ERROR_MESSAGE)
    md{end+1,1} = '';
    md{end+1,1} = '## ERROR_MESSAGE';
    md{end+1,1} = '```';
    md{end+1,1} = ERROR_MESSAGE;
    md{end+1,1} = '```';
end
fid = fopen(outReport, 'w');
if fid > 0
    for i = 1:numel(md)
        fprintf(fid, '%s\n', md{i});
    end
    fclose(fid);
end
