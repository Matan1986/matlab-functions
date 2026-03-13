function T = list_claims(claimsDir)
% list_claims List manually curated scientific claims and linked runs.
%
% Usage:
%   list_claims();
%   T = list_claims();
%   T = list_claims('C:\repo\claims');

if nargin < 1 || isempty(claimsDir)
    repoRoot = resolveRepoRoot();
    claimsDir = fullfile(repoRoot, 'claims');
end

claimsDir = char(string(claimsDir));
if exist(claimsDir, 'dir') ~= 7
    fprintf('No claims directory found: %s\n', claimsDir);
    T = table();
    return;
end

files = dir(fullfile(claimsDir, '*.json'));
if isempty(files)
    fprintf('No claim JSON files found in: %s\n', claimsDir);
    T = table();
    return;
end

[~, order] = sort(string({files.name}));
files = files(order);

n = numel(files);
claim_id = strings(n, 1);
status = strings(n, 1);
statement = strings(n, 1);
source_runs = strings(n, 1);
related_surveys = strings(n, 1);
notes = strings(n, 1);

for i = 1:n
    claimPath = fullfile(files(i).folder, files(i).name);
    [~, fileStem] = fileparts(files(i).name);

    claim_id(i) = string(fileStem);
    status(i) = "<invalid>";
    statement(i) = "";
    source_runs(i) = "";
    related_surveys(i) = "";
    notes(i) = "";

    try
        claim = jsondecode(fileread(claimPath));
        claim_id(i) = getStringField(claim, 'claim_id', string(fileStem));
        status(i) = getStringField(claim, 'status', '');
        statement(i) = getStringField(claim, 'statement', '');
        source_runs(i) = joinStringArray(getCellStringField(claim, 'source_runs'));
        related_surveys(i) = joinStringArray(getCellStringField(claim, 'related_surveys'));
        notes(i) = getStringField(claim, 'notes', '');
    catch ME
        statement(i) = "Invalid claim file";
        notes(i) = string(ME.message);
    end
end

T = table(claim_id, status, statement, source_runs, related_surveys, notes);

fprintf('\nScientific claims in %s\n', claimsDir);
disp(T(:, {'claim_id', 'status', 'source_runs'}));
end

function repoRoot = resolveRepoRoot()
thisFile = mfilename('fullpath');
claimsToolsDir = fileparts(thisFile);
toolsDir = fileparts(claimsToolsDir);
repoRoot = fileparts(toolsDir);
end

function s = getStringField(st, fieldName, defaultValue)
if nargin < 3
    defaultValue = "";
end

s = string(defaultValue);
if isstruct(st) && isfield(st, fieldName)
    value = st.(fieldName);
    if ~isempty(value)
        s = string(value);
    end
end
end

function values = getCellStringField(st, fieldName)
values = strings(0, 1);
if ~(isstruct(st) && isfield(st, fieldName))
    return;
end

raw = st.(fieldName);
if isempty(raw)
    return;
end

if isstring(raw)
    values = raw(:);
    return;
end

if ischar(raw)
    values = string({raw});
    return;
end

if iscell(raw)
    values = strings(numel(raw), 1);
    for k = 1:numel(raw)
        values(k) = string(raw{k});
    end
    return;
end

if isnumeric(raw) || islogical(raw)
    values = string(raw(:));
end
end

function out = joinStringArray(values)
if isempty(values)
    out = "";
    return;
end

out = strjoin(cellstr(values(:)), ', ');
out = string(out);
end