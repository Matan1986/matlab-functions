function p = switchingResolveLatestCanonicalTable(repoRoot, fileName)
%SWITCHINGRESOLVELATESTCANONICALTABLE Latest path to a canonical run table artifact.

p = '';

% Identity-first resolution: prefer locked canonical run id when available.
identityPath = fullfile(repoRoot, 'tables', 'switching_canonical_identity.csv');
if exist(identityPath, 'file') == 2
    try
        idTbl = readtable(identityPath, 'VariableNamingRule', 'preserve');
        if ~all(ismember({'field', 'value'}, idTbl.Properties.VariableNames))
            warning('Switching:IdentityResolverFallback', ...
                'Identity table malformed (missing field/value columns): %s. Falling back to mtime resolver.', ...
                identityPath);
        else
            fields = string(idTbl.field);
            values = string(idTbl.value);
            idx = find(strtrim(fields) == "CANONICAL_RUN_ID", 1, 'first');
            if isempty(idx)
                warning('Switching:IdentityResolverFallback', ...
                    'CANONICAL_RUN_ID not found in identity table: %s. Falling back to mtime resolver.', ...
                    identityPath);
            else
                canonicalRunId = strtrim(values(idx));
                if strlength(canonicalRunId) == 0
                    warning('Switching:IdentityResolverFallback', ...
                        'CANONICAL_RUN_ID is empty in identity table: %s. Falling back to mtime resolver.', ...
                        identityPath);
                else
                    anchorPath = fullfile(repoRoot, 'results', 'switching', 'runs', ...
                        char(canonicalRunId), 'tables', fileName);
                    if exist(anchorPath, 'file') == 2
                        p = anchorPath;
                        return;
                    end
                    warning('Switching:IdentityResolverFallback', ...
                        'Identity-anchored artifact missing: %s. Falling back to mtime resolver.', ...
                        anchorPath);
                end
            end
        end
    catch ME
        warning('Switching:IdentityResolverFallback', ...
            'Failed to parse identity table %s (%s). Falling back to mtime resolver.', ...
            identityPath, ME.message);
    end
else
    warning('Switching:IdentityResolverFallback', ...
        'Identity table missing: %s. Falling back to mtime resolver.', identityPath);
end

runsRoot = switchingCanonicalRunRoot(repoRoot);
if exist(runsRoot, 'dir') ~= 7, return; end
d = dir(fullfile(runsRoot, 'run_*_switching_canonical'));
paths = {};
for i = 1:numel(d)
    f = fullfile(runsRoot, d(i).name, 'tables', fileName);
    if exist(f, 'file') == 2, paths{end+1,1} = f; end %#ok<AGROW>
end
if isempty(paths), return; end
[~, idx] = max(cellfun(@(x) dir(x).datenum, paths));
p = paths{idx};
end
