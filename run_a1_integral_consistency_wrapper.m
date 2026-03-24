% run_a1_integral_consistency_wrapper.m
% Wrapper script: switching a1 integral consistency test.
% Run from the repo root with:
%   matlab -batch run_a1_integral_consistency_wrapper

thisDir  = fileparts(mfilename('fullpath'));
repoRoot = thisDir;

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'analysis'));

cfg = struct();
% Override source runs or temperature range here if needed, e.g.:
%   cfg.a1RunName    = 'run_XXXX_switching_dynamic_shape_mode';
%   cfg.speakRunName = 'run_XXXX_switching_geometry_diagnostics';
%   cfg.temperatureMinK = 4;
%   cfg.temperatureMaxK = 30;

out = switching_a1_integral_consistency_test(cfg);

fprintf('\nWrapper complete.\n');
fprintf('Run dir: %s\n', out.runDir);
fprintf('Pearson(S_peak_norm, S_rec_norm):  %.6f\n', out.metrics.pearson);
fprintf('Spearman(S_peak_norm, S_rec_norm): %.6f\n', out.metrics.spearman);
fprintf('T_peak(S_peak_norm):  %.2f K\n', out.metrics.T_peak_Speak);
fprintf('T_peak(S_rec_norm):   %.2f K\n', out.metrics.T_peak_Srec);
fprintf('Delta T_peak:         %.2f K\n', out.metrics.delta_T_peak);
fprintf('Correlation table: %s\n', out.paths.correlation);
fprintf('Series table:      %s\n', out.paths.series);
fprintf('Overlay figure:    %s\n', out.paths.overlay);
fprintf('Scatter figure:    %s\n', out.paths.scatter);
fprintf('Report: %s\n', out.paths.report);
fprintf('ZIP:    %s\n', out.paths.zip);
