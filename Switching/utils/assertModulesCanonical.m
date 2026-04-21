function assertModulesCanonical(moduleNames, varargin)
%ASSERTMODULESCANONICAL Enforce cross-module analysis only when all modules are CANONICAL.
%
%   assertModulesCanonical({'Switching'})
%   modules_used = {'Switching','Relaxation'};
%   assertModulesCanonical(modules_used);
%   assertModulesCanonical({'Switching'}, 'RepoRoot', alternateRepoRoot)

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
k = 1;
while k <= numel(varargin)
    if strcmpi(char(string(varargin{k})), 'RepoRoot')
        if k + 1 > numel(varargin)
            error('assertModulesCanonical:BadArgs', 'RepoRoot requires a value.');
        end
        repoRoot = char(string(varargin{k + 1}));
        k = k + 2;
    else
        error('assertModulesCanonical:UnknownOption', 'Unknown option: %s', varargin{k});
    end
end
statusPath = fullfile(repoRoot, 'tables', 'module_canonical_status.csv');

if exist(statusPath, 'file') ~= 2
    error('CrossModuleNotAllowed:NonCanonicalModule', ...
        'Missing module registry: %s', statusPath);
end

if ~local_module_registry_csv_header_ok(statusPath)
    error('CrossModuleNotAllowed:NonCanonicalModule', ...
        'Module registry failed header precondition: %s', statusPath);
end

T = readtable(statusPath);
req = {'MODULE', 'STATUS'};
for r = 1:numel(req)
    if ~ismember(req{r}, T.Properties.VariableNames)
        error('CrossModuleNotAllowed:NonCanonicalModule', ...
            'Registry %s must contain column %s.', statusPath, req{r});
    end
end

for im = 1:numel(moduleNames)
    modName = char(string(moduleNames{im}));
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

function tf = local_module_registry_csv_header_ok(path)
tf = false;
try
    tbl = readtable(path);
    if ~all(ismember({'MODULE', 'STATUS'}, tbl.Properties.VariableNames))
        return;
    end
    tf = height(tbl) >= 1;
catch
    tf = false;
end
end
