% run_geometry_deformation_wrapper.m
% Wrapper script: switching a1 vs geometric deformation test.
% Run from the repo root with:
%   matlab -batch run_geometry_deformation_wrapper

thisDir  = fileparts(mfilename('fullpath'));
repoRoot = thisDir;

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'tools', 'figures'));
addpath(fullfile(repoRoot, 'analysis'));

cfg = struct();
% Override source runs or smoothing settings here if needed, e.g.:
%   cfg.a1RunName     = 'run_XXXX_switching_dynamic_shape_mode';
%   cfg.switchRunName = 'run_XXXX_switching_effective_observables';

out = switching_a1_vs_geometry_deformation_test(cfg);

fprintf('\nWrapper complete.\n');
fprintf('Run dir: %s\n', out.runDir);
fprintf('Pearson(a1, dI_peak/dT):  %.6f\n', out.metrics.pearson_dIpeak);
fprintf('Spearman(a1, dI_peak/dT): %.6f\n', out.metrics.spearman_dIpeak);
fprintf('Pearson(a1, dwidth/dT):   %.6f\n', out.metrics.pearson_dwidth);
fprintf('Spearman(a1, dwidth/dT):  %.6f\n', out.metrics.spearman_dwidth);
fprintf('Better described by: %s\n', out.metrics.betterBy);
fprintf('T_peak(|a1|):            %.2f K\n', out.metrics.a1_peak_T_abs_K);
fprintf('T_peak(|dI_peak/dT|):    %.2f K  (delta = %.2f K)\n', ...
    out.metrics.dIpeak_peak_T_abs_K, out.metrics.delta_peak_Ipeak_K);
fprintf('T_peak(|dwidth/dT|):     %.2f K  (delta = %.2f K)\n', ...
    out.metrics.dwidth_peak_T_abs_K, out.metrics.delta_peak_width_K);
fprintf('Report: %s\n', out.paths.report);
fprintf('ZIP: %s\n', out.paths.zip);
