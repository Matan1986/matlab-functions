function run_kappa2_state_vs_geometry_test()
%RUN_KAPPA2_STATE_VS_GEOMETRY_TEST Agent 19A — kappa2 vs PT geometry vs residual structure.
% Read-only: merges existing CSVs via tools/run_kappa2_state_vs_geometry.ps1
% Writes: tables/kappa2_state_vs_geometry.csv, figures/kappa2_vs_shape.png, reports/kappa2_state_geometry_report.md

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
ps1 = fullfile(repoRoot, 'tools', 'run_kappa2_state_vs_geometry.ps1');
if exist(ps1, 'file') ~= 2
    error('Missing %s', ps1);
end
cmd = sprintf('powershell -NoProfile -ExecutionPolicy Bypass -File "%s"', ps1);
[status, out] = system(cmd);
fprintf('%s', out);
if status ~= 0
    error('Agent 19A script failed with status %d.', status);
end
end
