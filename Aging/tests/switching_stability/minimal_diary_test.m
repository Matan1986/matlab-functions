%% MINimal test - just diary
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(fileparts(scriptDir)));
logDir = fullfile(repoRoot, 'tmp_debug_outputs', 'switching_stability');
if exist(logDir, 'dir') ~= 7
    mkdir(logDir);
end
logfile = fullfile(logDir, 'minimal_test.txt');
diary(logfile);
disp('TEST OUTPUT 1');
fprintf('TEST OUTPUT 2\n');
diary off;
