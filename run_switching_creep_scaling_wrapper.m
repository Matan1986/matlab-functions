function run_switching_creep_scaling_wrapper()
% RUN_SWITCHING_CREEP_SCALING_WRAPPER
% Wrapper that runs creep-style scaling analysis from existing switching tables.
error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');
baseFolder = fileparts(mfilename('fullpath'));
addpath(genpath(baseFolder));

switching_creep_scaling_test();
end
