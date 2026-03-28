% run_a1_mobility_wrapper
% Wrapper script for switching_a1_vs_mobility_test.
% Run from the repo root with:  matlab -batch run_a1_mobility_wrapper
%
% Writes a trace log to tmp/run_a1_mobility_wrapper_trace.txt so that
% batch runs leave a record even when the console is not visible.
error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');
if ~exist('tmp', 'dir')
    mkdir('tmp');
end

logFile = fullfile('tmp', 'run_a1_mobility_wrapper_trace.txt');
fid = fopen(logFile, 'w');
if fid < 0
    error('Unable to open trace file: %s', logFile);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'run_a1_mobility_wrapper started at %s\n', char(datetime('now')));

try
    addpath('analysis');
    addpath(genpath('tools'));
    addpath(genpath('Aging'));

    out = switching_a1_vs_mobility_test(); %#ok<NASGU>

    fprintf(fid, 'Run completed successfully.\n');
    fprintf(fid, 'Run dir: %s\n', char(out.runDir));
    fprintf(fid, 'Pearson(a1, rmi)   = %.6f\n', out.metrics.pearson_rmi);
    fprintf(fid, 'Spearman(a1, rmi)  = %.6f\n', out.metrics.spearman_rmi);
    fprintf(fid, 'Pearson(a1, dS/dT) = %.6f\n', out.metrics.pearson_dS);
    fprintf(fid, 'Spearman(a1,dS/dT) = %.6f\n', out.metrics.spearman_dS);
    fprintf(fid, 'Pearson(a1, dI/dT) = %.6f\n', out.metrics.pearson_dI);
    fprintf(fid, 'Spearman(a1,dI/dT) = %.6f\n', out.metrics.spearman_dI);
    fprintf(fid, 'Best observable:    %s\n', char(out.metrics.best_observable));
    fprintf(fid, 'is_mobility_driver: %d\n', out.metrics.is_mobility_driver);
    fprintf(fid, 'Report: %s\n', char(out.paths.report));
    fprintf(fid, 'ZIP:    %s\n', char(out.paths.zip));

catch ME
    fprintf(fid, 'ERROR MESSAGE:\n%s\n\n', ME.message);
    fprintf(fid, 'ERROR IDENTIFIER:\n%s\n\n', ME.identifier);
    fprintf(fid, 'ERROR STACK:\n');
    for k = 1:numel(ME.stack)
        fprintf(fid, '  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
    rethrow(ME);
end

fprintf(fid, 'run_a1_mobility_wrapper finished at %s\n', char(datetime('now')));
