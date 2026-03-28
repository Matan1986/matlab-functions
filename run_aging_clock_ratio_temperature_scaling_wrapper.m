error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');
baseFolder = fileparts(mfilename('fullpath'));
addpath(genpath(baseFolder));
out = aging_clock_ratio_temperature_scaling();
disp('Aging clock ratio temperature scaling complete.');
disp(out.runDir);
