clear; clc;

SCRIPT_STARTED = 'NO';
FILES_FOUND = 0;
RUN_DIR_CREATED = 'NO';
WRITE_OK = 'NO';
TABLE_WRITE_OK = 'NO';
ROOT_CAUSE = 'UNKNOWN';

runDir = '';
runId = '';
stopNow = false;

disp('STEP_1_SCRIPT_STARTED');
SCRIPT_STARTED = 'YES';

repoRoot = 'C:/Dev/matlab-functions';
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'runs'));

files = [];
try
    if exist('localPaths', 'file') == 2
        paths = localPaths();
        agingDataDir = fullfile(paths.dataRoot, 'Aging');
        [~, files] = getFileList_aging(agingDataDir);
    else
        disp('STEP_2_ERROR=localPaths.m not found');
    end
catch ME
    disp(['STEP_2_ERROR=', ME.message]);
    files = [];
end

FILES_FOUND = length(files);
disp(['FILES_FOUND=', num2str(FILES_FOUND)]);

if FILES_FOUND == 0
    ROOT_CAUSE = 'NO_DATA';
    stopNow = true;
end

if ~stopNow
    cfg = struct();
    cfg.runLabel = 'aging_execution_diagnostics';

    try
        runCtx = createRunContext('aging', cfg);
        if isstruct(runCtx) && isfield(runCtx, 'run_dir')
            runDir = runCtx.run_dir;
        end
        if isstruct(runCtx) && isfield(runCtx, 'run_id')
            runId = runCtx.run_id;
        end
    catch ME
        disp(['STEP_3_ERROR=', ME.message]);
    end

    disp(['RUN_DIR=', runDir]);
    if exist(runDir, 'dir') == 7
        RUN_DIR_CREATED = 'YES';
    else
        ROOT_CAUSE = 'RUN_CONTEXT_FAILURE';
        stopNow = true;
    end
end

if ~stopNow
    testFile = fullfile(runDir, 'test.txt');
    fid = -1;
    try
        fid = fopen(testFile, 'w');
        if fid >= 0
            fprintf(fid, 'OK');
            fclose(fid);
            fid = -1;
        end
    catch ME
        disp(['STEP_4_ERROR=', ME.message]);
    end

    if fid >= 0
        fclose(fid);
    end

    if exist(testFile, 'file') == 2
        WRITE_OK = 'YES';
    else
        ROOT_CAUSE = 'WRITE_FAILURE';
        stopNow = true;
    end
end

if ~stopNow
    testCsvPath = fullfile(runDir, 'tables', 'test.csv');
    try
        T = table((1:3)');
        writetable(T, testCsvPath);
    catch ME
        disp(['STEP_5_ERROR=', ME.message]);
    end

    if exist(testCsvPath, 'file') == 2
        TABLE_WRITE_OK = 'YES';
    else
        ROOT_CAUSE = 'TABLE_WRITE_FAILURE';
        stopNow = true;
    end
end

if ~stopNow
    disp('STEP_6_COMPLETED');
end

disp(['SCRIPT_STARTED=', SCRIPT_STARTED]);
disp(['FILES_FOUND=', num2str(FILES_FOUND)]);
disp(['RUN_DIR_CREATED=', RUN_DIR_CREATED]);
disp(['WRITE_OK=', WRITE_OK]);
disp(['TABLE_WRITE_OK=', TABLE_WRITE_OK]);
disp(['ROOT_CAUSE=', ROOT_CAUSE]);
disp(['RUN_ID=', runId]);
