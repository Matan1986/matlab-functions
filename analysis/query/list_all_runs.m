function out = list_all_runs()
% list_all_runs
%   Returns all runs from analysis/knowledge/run_registry.csv.
%
% Output:
%   out.table  - table with one row per run (sorted by experiment)
%   out.grouped - struct array grouped by experiment

repoRoot = resolveRepoRoot();
registryPath = fullfile(repoRoot, 'analysis', 'knowledge', 'run_registry.csv');
if exist(registryPath, 'file') ~= 2
    error('run_registry.csv not found: %s', registryPath);
end

T = readtable(registryPath, 'Delimiter', ',', 'TextType', 'string');

if ~all(ismember({'run_id','experiment','run_rel_path'}, T.Properties.VariableNames))
    error('run_registry.csv missing expected columns.');
end

T.run_id = string(T.run_id);
T.experiment = string(T.experiment);

T = sortrows(T, {'experiment','run_id'});

out = struct();
keepCols = intersect({'run_id','experiment','run_rel_path','snapshot_has_entry'}, T.Properties.VariableNames);
out.table = T(:, keepCols);

uniqueExps = unique(out.table.experiment);
grouped = struct('experiment', {}, 'run_ids', {}, 'count', {});
for i = 1:numel(uniqueExps)
    exp = uniqueExps(i);
    mask = out.table.experiment == exp;
    grouped(i).experiment = exp; %#ok<AGROW>
    grouped(i).run_ids = out.table.run_id(mask); %#ok<AGROW>
    grouped(i).count = sum(mask); %#ok<AGROW>
end
out.grouped = grouped;

fprintf('list_all_runs: %d runs across %d experiments\n', height(out.table), numel(uniqueExps));

end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
toolsDir = fileparts(thisFile);   % analysis/query
repoRoot = fileparts(toolsDir);   % analysis
repoRoot = fileparts(repoRoot); % repo root
end

