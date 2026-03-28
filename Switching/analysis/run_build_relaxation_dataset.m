% run_build_relaxation_dataset
% Pure script only (no local functions).
% Build unified relaxation dataset: T_K | logt | M | R_relax | C

fprintf('[RUN] run_build_relaxation_dataset\n');
clearvars;

repoRoot = 'C:/Dev/matlab-functions';
scriptPath = 'C:/Dev/matlab-functions/Switching/analysis/run_build_relaxation_dataset.m';

outDatasetPath = 'C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv';
outStatusPath = 'C:/Dev/matlab-functions/tables/relaxation_full_dataset_status.csv';
outReportPath = 'C:/Dev/matlab-functions/reports/relaxation_full_dataset.md';
errorLogPath = 'C:/Dev/matlab-functions/matlab_error.log';

scanRoots = { ...
    'C:/Dev/matlab-functions/results', ...
    'C:/Dev/matlab-functions/Switching', ...
    'C:/Dev/matlab-functions/analysis' ...
    };

if exist('C:/Dev/matlab-functions/tables', 'dir') ~= 7, mkdir('C:/Dev/matlab-functions/tables'); end
if exist('C:/Dev/matlab-functions/reports', 'dir') ~= 7, mkdir('C:/Dev/matlab-functions/reports'); end

EXECUTION_STATUS = "FAIL";
N_FILES_FOUND = 0;
N_VALID_DATASETS = 0;
N_TEMPERATURES = 0;
COMMON_GRID_SIZE = 0;
ERROR_MESSAGE = "";

outTbl = table();
md = strings(0, 1);
md(end+1) = "# Relaxation full dataset";
md(end+1) = "";
md(end+1) = "Script: `" + string(scriptPath) + "`";
md(end+1) = "";

try
    if exist(outDatasetPath, 'file') == 2 || exist(outStatusPath, 'file') == 2 || exist(outReportPath, 'file') == 2
        error('run_build_relaxation_dataset:OutputExists', ...
            'Target output already exists. Refusing to overwrite existing files.');
    end

    fileList = strings(0, 1);
    for ir = 1:numel(scanRoots)
        rootDir = scanRoots{ir};
        if exist(rootDir, 'dir') ~= 7
            continue;
        end
        found = dir(fullfile(rootDir, '**', '*.csv'));
        for i = 1:numel(found)
            fileList(end+1, 1) = string(fullfile(found(i).folder, found(i).name)); %#ok<SAGROW>
        end
    end
    if ~isempty(fileList)
        fileList = unique(fileList, 'stable');
    end
    N_FILES_FOUND = numel(fileList);

    % Storage for valid relaxation datasets before gridding
    validT = NaN(0, 1);
    validLogt = cell(0, 1);
    validM = cell(0, 1);
    validFile = strings(0, 1);
    validTimeCol = strings(0, 1);
    validSignalCol = strings(0, 1);

    for ifile = 1:numel(fileList)
        fpath = fileList(ifile);
        try
            T = readtable(fpath, 'VariableNamingRule', 'preserve');
        catch
            continue;
        end
        if height(T) < 2 || width(T) < 2
            continue;
        end

        vNames = string(T.Properties.VariableNames);
        vLow = lower(vNames);
        allIdx = (1:numel(vNames))';

        idxTemp = find(contains(vLow, 't_k') | (contains(vLow, 'temp') & ~contains(vLow, 'time')), 1, 'first');
        Tcol = NaN(height(T), 1);
        if ~isempty(idxTemp) && isnumeric(T{:, idxTemp})
            Tcol = double(T{:, idxTemp});
        end

        % Time column detection (contains-only logic)
        isTime = contains(vLow, 'logt') | contains(vLow, 'log_t') | contains(vLow, 'log10') | ...
            contains(vLow, 'time') | contains(vLow, 't_rel') | contains(vLow, 'tau') | ...
            (contains(vLow, 't') & ~contains(vLow, 'temp'));
        idxTimeCand = find(isTime);
        idxTime = [];
        bestTimeScore = -Inf;
        for ic = 1:numel(idxTimeCand)
            k = idxTimeCand(ic);
            raw = T{:, k};
            if ~isnumeric(raw), continue; end
            x = double(raw(:));
            nFin = nnz(isfinite(x));
            nUni = numel(unique(x(isfinite(x))));
            if nFin < 50 || nUni < 10
                continue;
            end
            score = nFin / max(height(T), 1);
            if contains(vLow(k), 'logt') || contains(vLow(k), 'log_t'), score = score + 100; end
            if contains(vLow(k), 'log10'), score = score + 90; end
            if contains(vLow(k), 'time'), score = score + 80; end
            if contains(vLow(k), 't_rel'), score = score + 60; end
            if contains(vLow(k), 'tau'), score = score + 30; end
            if score > bestTimeScore
                bestTimeScore = score;
                idxTime = k;
            end
        end
        if isempty(idxTime)
            continue;
        end
        timeColName = vNames(idxTime);
        timeColLow = lower(timeColName);

        % Signal detection (direct M preferred; derivative fallback)
        isDeriv = contains(vLow, 'dmdlog') | contains(vLow, 'dm_dlog') | contains(vLow, 'dmdt') | ...
            contains(vLow, 'deriv') | contains(vLow, 'viscos');
        isSignal = contains(vLow, 'magnet') | contains(vLow, 'signal') | contains(vLow, 'response') | ...
            contains(vLow, 'value') | contains(vLow, 'data') | contains(vLow, 'm');
        isSignal = isSignal(:);
        isDeriv = isDeriv(:);

        idxSigDirect = find(isSignal & ~isDeriv & (allIdx ~= idxTime));
        idxSigDeriv = find(isDeriv & (allIdx ~= idxTime));

        idxSig = [];
        useDerivative = false;
        bestSigScore = -Inf;
        for ic = 1:numel(idxSigDirect)
            k = idxSigDirect(ic);
            raw = T{:, k};
            if ~isnumeric(raw), continue; end
            y = double(raw(:));
            if nnz(isfinite(y)) < 50
                continue;
            end
            score = nnz(isfinite(y)) / max(height(T), 1);
            if contains(vLow(k), 'data'), score = score + 100; end
            if contains(vLow(k), 'magnet'), score = score + 90; end
            if contains(vLow(k), 'signal'), score = score + 70; end
            if contains(vLow(k), 'response'), score = score + 60; end
            if contains(vLow(k), 'value'), score = score + 40; end
            if contains(vLow(k), 'residual'), score = score - 40; end
            if score > bestSigScore
                bestSigScore = score;
                idxSig = k;
            end
        end
        if isempty(idxSig) && ~isempty(idxSigDeriv)
            idxSig = idxSigDeriv(1);
            useDerivative = true;
        end
        if isempty(idxSig)
            continue;
        end
        sigColName = vNames(idxSig);

        tRawAll = double(T{:, idxTime});
        sRawAll = double(T{:, idxSig});

        groups = NaN(0, 1);
        if any(isfinite(Tcol))
            groups = unique(Tcol(isfinite(Tcol)), 'stable');
        end
        if isempty(groups)
            groups = NaN;
        end

        for ig = 1:numel(groups)
            Tg = groups(ig);
            if isnan(Tg)
                mG = true(height(T), 1);
            else
                mG = isfinite(Tcol) & abs(Tcol - Tg) < 1e-9;
            end
            tx = tRawAll(mG);
            sy = sRawAll(mG);
            mf = isfinite(tx) & isfinite(sy);
            tx = tx(mf);
            sy = sy(mf);
            if numel(tx) < 50
                continue;
            end

            isLogAxis = contains(timeColLow, 'logt') | contains(timeColLow, 'log_t') | ...
                contains(timeColLow, 'log10') | contains(timeColLow, 'log');
            if isLogAxis
                lx = tx;
            else
                pos = tx > 0 & isfinite(tx);
                lx = NaN(size(tx));
                lx(pos) = log10(tx(pos));
            end
            mf2 = isfinite(lx) & isfinite(sy);
            lx = lx(mf2);
            sy = sy(mf2);
            if numel(lx) < 50
                continue;
            end

            d = diff(lx);
            isMono = all(d >= 0) || all(d <= 0);
            if ~isMono
                continue;
            end

            d1 = diff(sy);
            if isempty(d1)
                continue;
            end
            sigStd = std(sy, 'omitnan');
            if ~isfinite(sigStd), sigStd = 0; end
            rough = median(abs(diff(d1)), 'omitnan') / max(sigStd, eps);
            continuousSignal = isfinite(rough) && rough < 100 && any(abs(d1) > 0);
            if ~continuousSignal
                continue;
            end

            [lxSort, ord] = sort(lx, 'ascend');
            sySort = sy(ord);
            if useDerivative
                Mvec = cumtrapz(lxSort, sySort);
            else
                Mvec = sySort;
            end

            N_VALID_DATASETS = N_VALID_DATASETS + 1;
            validT(end+1, 1) = Tg; %#ok<SAGROW>
            validLogt{end+1, 1} = lxSort; %#ok<SAGROW>
            validM{end+1, 1} = Mvec; %#ok<SAGROW>
            validFile(end+1, 1) = fpath; %#ok<SAGROW>
            validTimeCol(end+1, 1) = timeColName; %#ok<SAGROW>
            validSignalCol(end+1, 1) = sigColName; %#ok<SAGROW>
        end
    end

    if N_VALID_DATASETS < 1
        EXECUTION_STATUS = "SUCCESS";
        md(end+1) = "No valid relaxation datasets found under scan roots.";
    else
        allMin = NaN(N_VALID_DATASETS, 1);
        allMax = NaN(N_VALID_DATASETS, 1);
        for i = 1:N_VALID_DATASETS
            li = validLogt{i};
            allMin(i) = min(li, [], 'omitnan');
            allMax(i) = max(li, [], 'omitnan');
        end
        minLogt = min(allMin, [], 'omitnan');
        maxLogt = max(allMax, [], 'omitnan');
        logtGrid = linspace(minLogt, maxLogt, 200).';
        COMMON_GRID_SIZE = numel(logtGrid);

        outTbl = table();
        for i = 1:N_VALID_DATASETS
            li = validLogt{i};
            Mi = validM{i};
            [li, ord] = sort(li, 'ascend');
            Mi = Mi(ord);
            [liU, ia] = unique(li, 'stable');
            MiU = Mi(ia);
            if numel(liU) < 2
                continue;
            end
            Mgrid = interp1(liU, MiU, logtGrid, 'linear', NaN);
            Rrelax = -gradient(Mgrid, logtGrid);
            C = gradient(Rrelax, logtGrid);
            mf = isfinite(Mgrid) & isfinite(Rrelax) & isfinite(C);
            if ~any(mf)
                continue;
            end
            Tadd = repmat(validT(i), nnz(mf), 1);
            logAdd = logtGrid(mf);
            Madd = Mgrid(mf);
            Radd = Rrelax(mf);
            Cadd = C(mf);
            srcFile = repmat(validFile(i), nnz(mf), 1);
            srcTime = repmat(validTimeCol(i), nnz(mf), 1);
            srcSig = repmat(validSignalCol(i), nnz(mf), 1);
            tblAdd = table(Tadd, logAdd, Madd, Radd, Cadd, srcFile, srcTime, srcSig, ...
                'VariableNames', {'T_K', 'logt', 'M', 'R_relax', 'C', 'source_file', 'time_column', 'signal_column'});
            outTbl = [outTbl; tblAdd]; %#ok<AGROW>
        end

        if isempty(outTbl)
            outTbl = table(NaN, NaN, NaN, NaN, NaN, "", "", "", ...
                'VariableNames', {'T_K', 'logt', 'M', 'R_relax', 'C', 'source_file', 'time_column', 'signal_column'});
        end

        if any(isfinite(outTbl.T_K))
            N_TEMPERATURES = numel(unique(outTbl.T_K(isfinite(outTbl.T_K))));
        else
            N_TEMPERATURES = 0;
        end

        if any(cellfun(@numel, validLogt) > 50)
            VALID_SET_FOUND = true;
        else
            VALID_SET_FOUND = false;
        end
        if VALID_SET_FOUND
            EXECUTION_STATUS = "SUCCESS";
        else
            EXECUTION_STATUS = "SUCCESS";
        end

        md(end+1) = "## Scan roots";
        for ir = 1:numel(scanRoots)
            md(end+1) = "- `" + string(scanRoots{ir}) + "`";
        end
        md(end+1) = "";
        md(end+1) = "## Summary";
        md(end+1) = "- N_FILES_FOUND: `" + string(N_FILES_FOUND) + "`";
        md(end+1) = "- N_VALID_DATASETS: `" + string(N_VALID_DATASETS) + "`";
        md(end+1) = "- N_TEMPERATURES: `" + string(N_TEMPERATURES) + "`";
        md(end+1) = "- COMMON_GRID_SIZE: `" + string(COMMON_GRID_SIZE) + "`";
        md(end+1) = "- Output rows: `" + string(height(outTbl)) + "`";
    end

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

if isempty(outTbl)
    outTbl = table(NaN, NaN, NaN, NaN, NaN, "", "", "", ...
        'VariableNames', {'T_K', 'logt', 'M', 'R_relax', 'C', 'source_file', 'time_column', 'signal_column'});
end

statusTbl = table(string(EXECUTION_STATUS), N_FILES_FOUND, N_VALID_DATASETS, N_TEMPERATURES, COMMON_GRID_SIZE, string(ERROR_MESSAGE), ...
    'VariableNames', {'EXECUTION_STATUS', 'N_FILES_FOUND', 'N_VALID_DATASETS', 'N_TEMPERATURES', 'COMMON_GRID_SIZE', 'ERROR_MESSAGE'});

writetable(outTbl, outDatasetPath);
writetable(statusTbl, outStatusPath);

fid = fopen(outReportPath, 'w');
if fid ~= -1
    fprintf(fid, '%s\n', char(strjoin(md, newline)));
    fclose(fid);
else
    statusTbl.EXECUTION_STATUS = "FAIL_REPORT_WRITE";
    statusTbl.ERROR_MESSAGE = "Could not write markdown report.";
    writetable(statusTbl, outStatusPath);
end

fprintf('[DONE] run_build_relaxation_dataset -> %s\n', outStatusPath);
