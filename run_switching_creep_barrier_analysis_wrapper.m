function run_switching_creep_barrier_analysis_wrapper()
% RUN_SWITCHING_CREEP_BARRIER_ANALYSIS_WRAPPER
% Wrapper that runs observable-only switching creep barrier analysis.
error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');
baseFolder = fileparts(mfilename('fullpath'));
addpath(genpath(baseFolder));

out = switching_creep_barrier_analysis();
disp('switching creep barrier analysis complete');
disp(out.outputs);
end