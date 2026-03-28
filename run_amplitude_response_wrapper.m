% run_amplitude_response_wrapper
% Batch wrapper: a1(T) vs dS_peak/dT and d2S_peak/dT2 (amplitude-response test).
%
% Run with:
%   matlab -batch "run_amplitude_response_wrapper"
%
% Creates: results/switching/runs/run_<timestamp>_switching_a1_amplitude_response_test/
error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');

repoRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'analysis'));

out = switching_a1_amplitude_response_test(); %#ok<NASGU>
