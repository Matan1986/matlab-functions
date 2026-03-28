% run_relaxation_temperature_scaling_wrapper
% Wrapper script for relaxation_temperature_scaling_test.
% Run from the repo root with:
%   matlab -batch run_relaxation_temperature_scaling_wrapper
error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');
if ~exist('tmp', 'dir')
    mkdir('tmp');
end

logFile = fullfile('tmp', 'run_relaxation_temperature_scaling_wrapper_trace.txt');
fid = fopen(logFile, 'w');
if fid < 0
    error('Unable to open trace file: %s', logFile);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'run_relaxation_temperature_scaling_wrapper started at %s\n', char(datetime('now')));

try
    addpath('analysis');
    addpath(genpath('tools'));
    addpath(genpath('Aging'));

    out = relaxation_temperature_scaling_test(); %#ok<NASGU>

    fprintf(fid, 'Run completed successfully.\n');
    fprintf(fid, 'Run ID:   %s\n', char(out.run_id));
    fprintf(fid, 'alpha:    %.6g\n', out.alpha);
    fprintf(fid, 'R2:       %.6f\n', out.R2);
    fprintf(fid, 'RMSE:     %.6g\n', out.RMSE);
    fprintf(fid, 'N_points: %d\n', out.N_points);
    fprintf(fid, 'Report:   %s\n', char(out.reportPath));
    fprintf(fid, 'ZIP:      %s\n', char(out.zipPath));

catch ME
    fprintf(fid, 'ERROR: %s\n', ME.message);
    for i = 1:numel(ME.stack)
        fprintf(fid, '  at %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    rethrow(ME);
end
