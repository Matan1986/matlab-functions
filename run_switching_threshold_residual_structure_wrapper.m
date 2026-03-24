function run_switching_threshold_residual_structure_wrapper()
% RUN_SWITCHING_THRESHOLD_RESIDUAL_STRUCTURE_WRAPPER
% Wrapper for residual-structure characterization after minimal
% threshold-distribution switching model.

baseFolder = fileparts(mfilename('fullpath'));
addpath(genpath(baseFolder));

switching_threshold_residual_structure_test();
end
