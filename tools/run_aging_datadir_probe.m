clear; clc;

% run_aging_datadir_probe
% Minimal probe: verify agingConfig resolves MG119_3sec dataDir to an existing folder.
% Pure script. ASCII only.

thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);
repoRoot = fileparts(toolsDir);

fidProbe = fopen(fullfile(repoRoot, 'tables', 'aging', 'execution_probe_datadir_probe.txt'), 'w');
if fidProbe >= 0
    fprintf(fidProbe, 'SCRIPT_ENTERED run_aging_datadir_probe\n');
    fclose(fidProbe);
end

addpath(genpath(fullfile(repoRoot, 'Aging')));
addpath(toolsDir);

cfg = agingConfig('MG119_3sec');
p = cfg.dataDir;
fprintf('RESOLVED_DATA_DIR=%s\n', p);
assert(isfolder(p), 'Resolved data directory does not exist: %s', p);
fprintf('AGING_DATADIR_PROBE_OK\n');
