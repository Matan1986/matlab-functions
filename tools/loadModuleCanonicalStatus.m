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
explicitValidateModuleCanonicalStatus(statusPath);
logReadtableEnforcementMode(statusPath);

% P01 controlled shift: readtable remains IO path only for this boundary.
T = readtable(statusPath);

end

function explicitValidateModuleCanonicalStatus(statusPath)
if exist(statusPath, 'file') ~= 2
    error('loadModuleCanonicalStatus:MissingRegistry', ...
        'Missing module registry: %s', statusPath);
end

txt = fileread(statusPath);
lines = regexp(txt, '\r\n|\n|\r', 'split');
if ~isempty(lines) && strlength(string(lines{end})) == 0
    lines = lines(1:end-1);
end
if isempty(lines)
    error('loadModuleCanonicalStatus:Schema', ...
        'Registry %s must contain column MODULE.', statusPath);
end

header = strtrim(string(lines{1}));
headerCols = split(header, ',');
headerCols = strtrim(headerCols);
req = ["MODULE", "STATUS"];
for r = 1:numel(req)
    if ~any(strcmp(headerCols, req(r)))
        error('loadModuleCanonicalStatus:Schema', ...
            'Registry %s must contain column %s.', statusPath, req(r));
    end
end

if numel(lines) < 2
    error('loadModuleCanonicalStatus:Schema', ...
        'Registry %s must contain at least one data row.', statusPath);
end
end

function logReadtableEnforcementMode(statusPath)
normPath = lower(strrep(char(string(statusPath)), '/', '\'));
if contains(normPath, '\results\') && contains(normPath, '\runs\')
    warning('loadModuleCanonicalStatus:ReadtableEnforcementLogOnly', ...
        'readtable enforcement context detected for %s; enforcement is handled explicitly in this boundary.', ...
        statusPath);
end
end
