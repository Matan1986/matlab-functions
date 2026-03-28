function run_kappa1_from_pt_agent20a()
% run_kappa1_from_pt_agent20a  Agent 20A: kappa1 ~ PT tail observables.
% Delegates to tools/run_kappa1_from_pt_agent20a.ps1 (numeric core; LOOCV, OLS).
% Writes: tables/kappa1_from_PT.csv, reports/kappa1_from_PT_report.md

thisFile = mfilename('fullpath');
analysisDir = fileparts(thisFile);
repoRoot = fileparts(analysisDir);
ps1 = fullfile(repoRoot, 'tools', 'run_kappa1_from_pt_agent20a.ps1');
if exist(ps1, 'file') ~= 2
    error('run_kappa1_from_pt_agent20a:MissingScript', 'Not found: %s', ps1);
end
cmd = sprintf('powershell -NoProfile -ExecutionPolicy Bypass -File "%s"', ps1);
[s, out] = system(cmd);
fprintf('%s', out);
if s ~= 0
    error('run_kappa1_from_pt_agent20a:PowerShellFailed', ...
        'PowerShell exit code %d. Command: %s', s, cmd);
end
fprintf('Done. See tables/kappa1_from_PT.csv and reports/kappa1_from_PT_report.md\n');
end
