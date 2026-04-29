function u = aging_F6U_validator_utils()
% aging_F6U_validator_utils Helper bundle for F6U audit-only validator (no analysis logic).
u.relPathFromRoot = @relPathFromRoot;
u.readFirstLineSafe = @readFirstLineSafe;
u.parseCsvHeaderLine = @parseCsvHeaderLine;
u.classifyTableType = @classifyTableType;
u.isTauRLike = @isTauRLike;
u.isCrossRunLike = @isCrossRunLike;
u.isPooledLike = @isPooledLike;
u.findSidecars = @findSidecars;
u.tern = @tern;
u.fieldEmpty = @fieldEmpty;
end

function e = fieldEmpty(v)
e = isempty(v);
end

function rp = relPathFromRoot(rootAbs, fileAbs)
rootAbs = strrep(rootAbs, '/', filesep);
fileAbs = strrep(fileAbs, '/', filesep);
if numel(fileAbs) >= numel(rootAbs) && strcmpi(fileAbs(1:numel(rootAbs)), rootAbs)
    if numel(fileAbs) > numel(rootAbs) && (fileAbs(numel(rootAbs)+1) == filesep || fileAbs(numel(rootAbs)+1) == '/')
        rp = fileAbs(numel(rootAbs)+2:end);
    else
        rp = fileAbs;
    end
else
    rp = fileAbs;
end
rp = strrep(rp, filesep, '/');
end

function line = readFirstLineSafe(p)
line = '';
fid = fopen(p, 'r');
if fid < 0
    return;
end
line = fgetl(fid);
fclose(fid);
if ~ischar(line)
    line = '';
end
end

function vars = parseCsvHeaderLine(line)
vars = {};
if isempty(line)
    return;
end
parts = strsplit(line, ',');
for i = 1:numel(parts)
    tok = strtrim(parts{i});
    if numel(tok) >= 2 && tok(1) == '"' && tok(end) == '"'
        tok = tok(2:end-1);
    end
    vars{end+1} = tok; %#ok<AGROW>
end
end

function tt = classifyTableType(relP, lowPath)
tt = 'aging_csv';
z = lower(relP);
if contains(z, 'tau') || contains(lowPath, 'tau')
    tt = 'tau_table';
end
if contains(lowPath, 'r_age') || contains(lowPath, 'clock_ratio') || ...
        contains(lowPath, 'r_vs') || contains(lowPath, 'tau_fm_over') || ...
        contains(lowPath, 'r_tau') || contains(lowPath, '_r_table')
    tt = 'R_table';
end
if contains(z, 'pool') || contains(z, 'consolidat')
    tt = 'pooled_table';
end
end

function flag = isTauRLike(tableType, lowPath)
flag = strcmp(tableType, 'tau_table') || strcmp(tableType, 'R_table');
flag = flag || contains(lowPath, 'tau');
flag = flag || contains(lowPath, 'r_vs');
flag = flag || contains(lowPath, 'clock_ratio');
flag = flag || contains(lowPath, 'r_age');
end

function flag = isCrossRunLike(relP, lowPath)
z = lower(relP);
flag = contains(z, 'cross') || contains(z, 'xrun') || contains(z, 'multi_run');
flag = flag || contains(lowPath, 'cross_run');
flag = flag || contains(lowPath, 'consolidat');
end

function flag = isPooledLike(tableType, lowPath)
flag = strcmp(tableType, 'pooled_table');
flag = flag || contains(lowPath, 'pool');
flag = flag || contains(lowPath, 'pooled');
flag = flag || contains(lowPath, 'aggregate');
end

function [hasSidecar, sidecarStr, scStructs] = findSidecars(csvPath)
hasSidecar = false;
sidecarStr = '';
scStructs = {};
[folder, base, ~] = fileparts(csvPath);
suff = { ...
    '_sidecar.csv', '_sidecar.json', '_lineage.csv', '_lineage.json', ...
    '_contract.csv', '_manifest.json' ...
    };
paths = {};
for i = 1:numel(suff)
    p = fullfile(folder, [base, suff{i}]);
    if exist(p, 'file') == 2
        paths{end+1} = p; %#ok<AGROW>
        hasSidecar = true;
    end
end
if isempty(paths)
    scStructs = {};
    return;
end
sidecarStr = strjoin(strrep(paths, '\', '/'), '; ');
for j = 1:numel(paths)
    pj = paths{j};
    le = lower(pj);
    if numel(le) >= 5 && strcmp(le(end-4:end), '.json')
        dj = dir(pj);
        if isempty(dj) || dj(1).bytes > 524288
            continue;
        end
        try
            raw = fileread(pj);
            scStructs{end+1} = jsondecode(raw); %#ok<AGROW>
        catch
        end
    end
end
end

function s = tern(cond, a, b)
if cond
    s = a;
else
    s = b;
end
end
