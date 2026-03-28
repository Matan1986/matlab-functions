% run_activation_signature_wrapper.m
% Batch-safe entry point for:
%   matlab -batch run_activation_signature_wrapper
%
% Runs switching_activation_signature_test with default configuration.
error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');
addpath('analysis');
addpath(genpath('Aging'));
addpath('tools');
addpath(fullfile('tools', 'figures'));

if ~exist('tmp', 'dir')
    mkdir('tmp');
end

logFile = fullfile('tmp', 'run_activation_signature_wrapper_trace.txt');
fid = fopen(logFile, 'w');
if fid < 0
    error('Unable to open trace log: %s', logFile);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'Batch wrapper started at %s\n', char(datetime('now')));

try
    out = switching_activation_signature_test(); %#ok<NASGU>
    fprintf(fid, 'Run completed successfully at %s\n', char(datetime('now')));
catch ME
    fprintf(fid, 'ERROR at %s\n', char(datetime('now')));
    fprintf(fid, 'MESSAGE:\n%s\n\n', ME.message);
    fprintf(fid, 'IDENTIFIER:\n%s\n\n', ME.identifier);
    fprintf(fid, 'STACK:\n');
    for k = 1:numel(ME.stack)
        fprintf(fid, '  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
    rethrow(ME);
end
