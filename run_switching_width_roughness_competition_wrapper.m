function run_switching_width_roughness_competition_wrapper()
% RUN_SWITCHING_WIDTH_ROUGHNESS_COMPETITION_WRAPPER
% Batch wrapper for width_I roughness/competition diagnostics from existing runs.

baseFolder = fileparts(mfilename('fullpath'));
addpath(genpath(baseFolder));

switching_width_roughness_competition_test();
end
