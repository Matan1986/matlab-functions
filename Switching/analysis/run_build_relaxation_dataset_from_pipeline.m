% run_build_relaxation_dataset_from_pipeline
% Pure script (no local functions).
% Build relaxation dataset from canonical pipeline in-memory output.

fprintf('[RUN] run_build_relaxation_dataset_from_pipeline\n');
clearvars;

repoRoot = 'C:/Dev/matlab-functions';
scriptPath = 'C:/Dev/matlab-functions/Switching/analysis/run_build_relaxation_dataset_from_pipeline.m';

outDatasetPath = 'C:/Dev/matlab-functions/tables/relaxation_full_dataset.csv';
outStatusPath = 'C:/Dev/matlab-functions/tables/relaxation_full_dataset_status.csv';
outReportPath = 'C:/Dev/matlab-functions/reports/relaxation_full_dataset.md';

if exist('C:/Dev/matlab-functions/tables', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/tables');
end
if exist('C:/Dev/matlab-functions/reports', 'dir') ~= 7
    mkdir('C:/Dev/matlab-functions/reports');
end

EXECUTION_STATUS = "FAIL";
N_TEMPERATURES = 0;
N_POINTS_PER_T = "0";
PIPELINE_USED = "run_relaxation_observable_stability_audit: resolveLatestCompleteSourceRun + loadMapMatrix";
ERROR_MESSAGE = "";

outTbl = table(NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', {'T_K','logt','M','R_relax','C'});

md = strings(0,1);
md(end+1) = "# Relaxation Full Dataset (Pipeline)";
md(end+1) = "";
md(end+1) = "Script: `" + string(scriptPath) + "`";
md(end+1) = "Pipeline: `" + PIPELINE_USED + "`";
md(end+1) = "";

try
    runsRoot = fullfile(repoRoot, 'results', 'relaxation', 'runs');
    requiredRoot = {'run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt'};
    preferredDMFiles = {'map_dM_raw.csv', 'map_dM_sg_100md.csv', 'map_dM_sg_200md.csv', 'map_dM_gauss2d.csv'};
    searchSubdirs = {'tables', 'csv', 'derivative_smoothing', ''};

    if exist(runsRoot, 'dir') ~= 7
        error('run_build_relaxation_dataset_from_pipeline:MissingRunsRoot', ...
            'Missing relaxation runs root: %s', runsRoot);
    end

    runDirs = dir(fullfile(runsRoot, 'run_*'));
    runDirs = runDirs([runDirs.isdir]);
    if isempty(runDirs)
        error('run_build_relaxation_dataset_from_pipeline:NoRuns', ...
            'No run_* directories under: %s', runsRoot);
    end
    runNames = string({runDirs.name});
    runDirs = runDirs(~startsWith(runNames, "run_legacy", 'IgnoreCase', true));
    if isempty(runDirs)
        error('run_build_relaxation_dataset_from_pipeline:OnlyLegacyRuns', ...
            'Only legacy run directories were found under: %s', runsRoot);
    end
    [~, ordRuns] = sort({runDirs.name});
    runDirs = runDirs(ordRuns);

    selectedRunDir = "";
    selectedDMPath = "";
    for ir = numel(runDirs):-1:1
        runRoot = fullfile(runDirs(ir).folder, runDirs(ir).name);
        hasRequired = true;
        for rq = 1:numel(requiredRoot)
            if exist(fullfile(runRoot, requiredRoot{rq}), 'file') ~= 2
                hasRequired = false;
                break;
            end
        end
        if ~hasRequired
            continue;
        end

        localDM = "";
        for isub = 1:numel(searchSubdirs)
            subdir = searchSubdirs{isub};
            for ip = 1:numel(preferredDMFiles)
                if isempty(subdir)
                    cand = fullfile(runRoot, preferredDMFiles{ip});
                else
                    cand = fullfile(runRoot, subdir, preferredDMFiles{ip});
                end
                if exist(cand, 'file') == 2
                    localDM = string(cand);
                    break;
                end
            end
            if strlength(localDM) > 0
                break;
            end
        end

        if strlength(localDM) > 0
            selectedRunDir = string(runRoot);
            selectedDMPath = localDM;
            break;
        end
    end

    if strlength(selectedDMPath) == 0
        error('run_build_relaxation_dataset_from_pipeline:NoMapFound', ...
            'No complete run with a DeltaM map candidate was found in %s', runsRoot);
    end

    raw = readmatrix(char(selectedDMPath));
    if size(raw, 1) < 3 || size(raw, 2) < 3
        error('run_build_relaxation_dataset_from_pipeline:InvalidMapShape', ...
            'DeltaM map must include header row/column and at least 2x2 payload.');
    end

    logtNative = double(raw(1, 2:end)).';
    T = double(raw(2:end, 1));
    Mmap = double(raw(2:end, 2:end));

    if isempty(T) || isempty(logtNative) || isempty(Mmap)
        error('run_build_relaxation_dataset_from_pipeline:EmptyData', ...
            'Pipeline map extraction returned empty T/logt/dM data.');
    end

    if size(Mmap, 1) ~= numel(T) || size(Mmap, 2) ~= numel(logtNative)
        error('run_build_relaxation_dataset_from_pipeline:DimensionMismatch', ...
            'dMMap size does not match T and xGrid dimensions.');
    end

    validRows = isfinite(T);
    validCols = isfinite(logtNative);
    T = T(validRows);
    logtNative = logtNative(validCols);
    Mmap = Mmap(validRows, validCols);

    nonEmptyRows = any(isfinite(Mmap), 2);
    nonEmptyCols = any(isfinite(Mmap), 1);
    T = T(nonEmptyRows);
    logtNative = logtNative(nonEmptyCols);
    Mmap = Mmap(nonEmptyRows, nonEmptyCols);

    [logtGrid, ord] = sort(logtNative(:), 'ascend');
    Mmap = Mmap(:, ord);
    [logtGrid, ia] = unique(logtGrid, 'stable');
    Mmap = Mmap(:, ia);

    if numel(logtGrid) < 3
        error('run_build_relaxation_dataset_from_pipeline:TimeGridTooSmall', ...
            'Need at least 3 logt points, got %d.', numel(logtGrid));
    end

    keepT = isfinite(T);
    T = T(keepT);
    Mmap = Mmap(keepT, :);

    if isempty(T)
        error('run_build_relaxation_dataset_from_pipeline:NoFiniteT', ...
            'No finite temperatures returned by pipeline.');
    end

    commonMask = isfinite(logtGrid) & all(isfinite(Mmap), 1).';
    if nnz(commonMask) < 3
        error('run_build_relaxation_dataset_from_pipeline:NoCommonGrid', ...
            'Common finite logt grid across temperatures is too small: %d', nnz(commonMask));
    end
    logtGrid = logtGrid(commonMask);
    Mmap = Mmap(:, commonMask);

    nT = numel(T);
    rowCounts = zeros(nT, 1);

    T_all = NaN(0, 1);
    logt_all = NaN(0, 1);
    M_all = NaN(0, 1);
    R_all = NaN(0, 1);
    C_all = NaN(0, 1);

    for it = 1:nT
        Mi = Mmap(it, :).';
        Rrel = -gradient(Mi, logtGrid);
        Ccurv = gradient(Rrel, logtGrid);

        m = isfinite(logtGrid) & isfinite(Mi) & isfinite(Rrel) & isfinite(Ccurv);
        if ~any(m)
            continue;
        end

        nn = nnz(m);
        rowCounts(it) = nn;

        T_all = [T_all; repmat(T(it), nn, 1)]; %#ok<AGROW>
        logt_all = [logt_all; logtGrid(m)]; %#ok<AGROW>
        M_all = [M_all; Mi(m)]; %#ok<AGROW>
        R_all = [R_all; Rrel(m)]; %#ok<AGROW>
        C_all = [C_all; Ccurv(m)]; %#ok<AGROW>
    end

    validTMask = rowCounts > 0;
    if ~any(validTMask)
        error('run_build_relaxation_dataset_from_pipeline:NoValidRows', ...
            'No valid finite rows after derivative construction.');
    end

    outTbl = table(T_all, logt_all, M_all, R_all, C_all, ...
        'VariableNames', {'T_K','logt','M','R_relax','C'});

    N_TEMPERATURES = numel(unique(T(validTMask)));
    ptsUnique = unique(rowCounts(validTMask));
    N_POINTS_PER_T = string(strtrim(mat2str(ptsUnique(:).')));

    EXECUTION_STATUS = "SUCCESS";

    md(end+1) = "## Summary";
    md(end+1) = "- Pipeline logic executed from canonical run selection and map extraction.";
    md(end+1) = "- Selected run: `" + selectedRunDir + "`";
    md(end+1) = "- Selected DeltaM map: `" + selectedDMPath + "`";
    md(end+1) = "- `N_TEMPERATURES`: " + string(N_TEMPERATURES);
    md(end+1) = "- `N_POINTS_PER_T` (unique): " + N_POINTS_PER_T;
    md(end+1) = "- Output table columns: `T_K | logt | M | R_relax | C`.";

catch ME
    ERROR_MESSAGE = string(getReport(ME, 'extended', 'hyperlinks', 'off'));
    EXECUTION_STATUS = "FAIL";

    md(end+1) = "## Error";
    md(end+1) = "```";
    md(end+1) = ERROR_MESSAGE;
    md(end+1) = "```";
end

writetable(outTbl, outDatasetPath);

statusTbl = table(string(EXECUTION_STATUS), double(N_TEMPERATURES), string(N_POINTS_PER_T), ...
    string(PIPELINE_USED), string(ERROR_MESSAGE), ...
    'VariableNames', {'EXECUTION_STATUS','N_TEMPERATURES','N_POINTS_PER_T','PIPELINE_USED','ERROR_MESSAGE'});
writetable(statusTbl, outStatusPath);

fid = fopen(outReportPath, 'w');
if fid >= 0
    for i = 1:numel(md)
        fprintf(fid, '%s\n', md(i));
    end
    fclose(fid);
end

fprintf('[DONE] %s\n', EXECUTION_STATUS);
fprintf('Dataset: %s\n', outDatasetPath);
fprintf('Status : %s\n', outStatusPath);
fprintf('Report : %s\n', outReportPath);
