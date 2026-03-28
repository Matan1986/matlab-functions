% run_ridge_temperature_susceptibility_wrapper
% Batch wrapper: a1(T) vs d/dT[S_ridge(T)] (ridge temperature susceptibility test).
%
% Run with:
%   matlab -batch "run_ridge_temperature_susceptibility_wrapper"
%
% Creates:
%   results/switching/runs/run_<timestamp>_switching_ridge_temperature_susceptibility_test/
error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');
repoRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'analysis'));

out = switching_ridge_temperature_susceptibility_test(); %#ok<NASGU>
