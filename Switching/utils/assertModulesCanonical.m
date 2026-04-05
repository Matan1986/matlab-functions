function assertModulesCanonical(moduleNames)
%ASSERTMODULESCANONICAL Enforce cross-module analysis only when all modules are CANONICAL.
%
%   assertModulesCanonical({'Switching'})
%   modules_used = {'Switching','Relaxation'};
%   assertModulesCanonical(modules_used);

if nargin < 1 || isempty(moduleNames)
    error('CrossModuleNotAllowed:NonCanonicalModule', ...
        'moduleNames must be a non-empty cell array of module name strings.');
end

if ~iscell(moduleNames)
    moduleNames = cellstr(string(moduleNames));
end

thisFile = mfilename('fullpath');
if isempty(thisFile)
    error('assertModulesCanonical:path', 'Cannot resolve helper path.');
end
utilsDir = fileparts(thisFile);
repoRoot = fileparts(fileparts(utilsDir));
statusPath = fullfile(repoRoot, 'tables', 'module_canonical_status.csv');

if exist(statusPath, 'file') ~= 2
    error('CrossModuleNotAllowed:NonCanonicalModule', ...
        'Missing module registry: %s', statusPath);
end

T = readtable(statusPath);
req = {'MODULE', 'STATUS'};
for r = 1:numel(req)
    if ~ismember(req{r}, T.Properties.VariableNames)
        error('CrossModuleNotAllowed:NonCanonicalModule', ...
            'Registry %s must contain column %s.', statusPath, req{r});
    end
end

for k = 1:numel(moduleNames)
    modName = char(string(moduleNames{k}));
    idx = strcmp(cellstr(string(T.MODULE)), modName);
    if ~any(idx)
        error('CrossModuleNotAllowed:NonCanonicalModule', ...
            'Module not in registry: %s', modName);
    end
    row = find(idx, 1);
    st = T.STATUS(row);
    if iscell(st)
        st = st{1};
    end
    st = char(string(st));
    if ~strcmp(st, 'CANONICAL')
        error('CrossModuleNotAllowed:NonCanonicalModule', ...
            ['Cross-module analysis blocked: module %s has STATUS=%s ', ...
            '(CANONICAL required).'], modName, st);
    end
end

end
