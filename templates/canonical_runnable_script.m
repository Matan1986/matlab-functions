% Canonical runnable script template for tools/run_matlab_safe.bat
% Contract:
% 1) Keep this file as a pure script (no function definitions).
% 2) Place helper logic in separate helper .m files.
% 3) Always write output and status/error artifacts.

try
    repoRoot = 'C:/Dev/matlab-functions';
    outDir = fullfile(repoRoot, 'results', 'example', 'runs', 'run_YYYYMMDD_HHMMSS_template');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    statusPath = fullfile(outDir, 'status.txt');
    resultPath = fullfile(outDir, 'result.txt');

    fid = fopen(resultPath, 'w');
    fprintf(fid, 'Canonical runnable executed at %s\n', datestr(now, 31));
    fclose(fid);

    fid = fopen(statusPath, 'w');
    fprintf(fid, 'SUCCESS\n');
    fclose(fid);
catch ME
    errPath = fullfile('C:/Dev/matlab-functions', 'matlab_error.log');
    fid = fopen(errPath, 'w');
    fprintf(fid, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    fclose(fid);
    rethrow(ME);
end
