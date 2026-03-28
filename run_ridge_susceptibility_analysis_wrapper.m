% run_ridge_susceptibility_analysis_wrapper
% Batch wrapper: extract chi_ridge(T) = |dS/dI| near I_peak from switching
% map S(I,T) and test its relationship to a1(T) and X(T).
%
% Run with:
%   matlab -batch "run_ridge_susceptibility_analysis_wrapper"
%
% Creates:
%   results/switching/runs/run_<timestamp>_switching_ridge_susceptibility_analysis/
error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution');
repoRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'Switching', 'analysis'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

out = switching_ridge_susceptibility_analysis(); %#ok<NASGU>
