clear; clc;

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

cfg = struct('runLabel', 'minimal_canonical');
run = createSwitchingRunContext(repoRoot, cfg);
rd = run.run_dir;

% Ensure run_dir exists
if ~isfolder(rd)
    mkdir(rd);
end

T = table((1:3)', 'VariableNames', {'x'});
writetable(T, fullfile(rd, 'minimal_data.csv'));

fid = fopen(fullfile(rd, 'minimal_report.md'), 'w');
if fid < 0
    error('failed to open md');
end
fprintf(fid, '# Minimal canonical run\n\nOK\n');
fclose(fid);

nT = height(T);
writeSwitchingExecutionStatus(rd, {'SUCCESS'}, {'YES'}, {''}, nT, {'minimal canonical end-to-end proof'}, true);

% Create run_manifest.json with outputs list
manifest_path = fullfile(rd, 'run_manifest.json');
outputs_list = {
    fullfile(rd, 'minimal_data.csv');
    fullfile(rd, 'minimal_report.md');
    fullfile(rd, 'execution_status.csv')
};
manifest = struct('outputs', {outputs_list});
json_str = jsonencode(manifest);
fid = fopen(manifest_path, 'w');
if fid < 0
    error('failed to open manifest');
end
fprintf(fid, '%s', json_str);
fclose(fid);

pf = fullfile(repoRoot, 'run_dir_pointer.txt');
pf_parent = fileparts(pf);
pf_parent_exists = exist(pf_parent, 'dir') == 7;
if ~pf_parent_exists
    error('run_dir_pointer_parent_missing');
end

fidp = fopen(pf, 'w');
if fidp < 0
    error('failed to open run_dir_pointer');
end

nw = fprintf(fidp, '%s', rd);
if nw <= 0
    fclose(fidp);
    error('run_dir_pointer_write_failed');
end

fc = fclose(fidp);
if fc ~= 0
    error('run_dir_pointer_write_failed');
end

pf_exists_after_write = exist(pf, 'file');
if pf_exists_after_write ~= 2
    error('run_dir_pointer_write_failed');
end

fid_diag = fopen(fullfile(rd, 'minimal_report.md'), 'a');
if fid_diag < 0
    error('failed_to_append_pointer_diagnostics');
end
fprintf(fid_diag, '\n## Pointer diagnostics\n');
fprintf(fid_diag, 'pointer_path: %s\n', pf);
fprintf(fid_diag, 'run_dir: %s\n', rd);
fprintf(fid_diag, 'pointer_exist_after_write: %d\n', pf_exists_after_write);
fclose(fid_diag);
