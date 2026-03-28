error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');
addpath(genpath(pwd));
out = switching_barrier_distribution_from_map();
disp('barrier distribution analysis complete');
disp(out.output);
