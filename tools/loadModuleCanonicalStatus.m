function T = loadModuleCanonicalStatus(repoRoot)
%LOADMODULECANONICALSTATUS Load tables/module_canonical_status.csv from repo root.

if nargin < 1 || isempty(repoRoot)
    error('loadModuleCanonicalStatus:repoRoot', 'repoRoot must be provided.');
end
repoRoot = char(string(repoRoot));
if isempty(strtrim(repoRoot))
    error('loadModuleCanonicalStatus:repoRoot', 'repoRoot must be non-empty.');
end
statusPath = fullfile(repoRoot, 'tables', 'module_canonical_status.csv');
if exist(statusPath, 'file') ~= 2
    error('loadModuleCanonicalStatus:MissingRegistry', ...
        'Missing module registry: %s', statusPath);
end
T = readtable(statusPath);
req = {'MODULE', 'STATUS'};
for r = 1:numel(req)
    if ~ismember(req{r}, T.Properties.VariableNames)
        error('loadModuleCanonicalStatus:Schema', ...
            'Registry %s must contain column %s.', statusPath, req{r});
    end
end

end
