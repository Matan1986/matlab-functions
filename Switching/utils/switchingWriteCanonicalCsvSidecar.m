function switchingWriteCanonicalCsvSidecar(csvPaths, repoRoot, opts)
%SWITCHINGWRITECANONICALCSVSIDECAR Write canonical .csv.meta.json beside one or more identical CSV paths.
%   switchingWriteCanonicalCsvSidecar({runPath, repoPath}, repoRoot, opts)
%   All listed files must exist and share the same SHA-256 as the first path.

if nargin < 3 || ~isstruct(opts)
    error('switchingWriteCanonicalCsvSidecar:BadArgs', 'opts struct is required.');
end
if nargin < 2 || strlength(string(repoRoot)) == 0
    error('switchingWriteCanonicalCsvSidecar:BadArgs', 'repoRoot is required.');
end
if nargin < 1 || isempty(csvPaths)
    error('switchingWriteCanonicalCsvSidecar:BadArgs', 'csvPaths cell array is required.');
end

repoRoot = char(string(repoRoot));
paths = cellfun(@(p) char(string(p)), csvPaths, 'UniformOutput', false);
for i = 1:numel(paths)
    if exist(paths{i}, 'file') ~= 2
        error('switchingWriteCanonicalCsvSidecar:MissingCsv', 'CSV not found: %s', paths{i});
    end
end

h0 = localSha256Hex(paths{1});
for i = 2:numel(paths)
    hi = localSha256Hex(paths{i});
    if ~strcmpi(h0, hi)
        error('switchingWriteCanonicalCsvSidecar:HashMismatch', ...
            'CSV byte mismatch between %s and %s', paths{1}, paths{i});
    end
end

reqO = {'table_name', 'expected_role', 'producer_script', 'source_run_id', ...
    'lineage_tags', 'valid_contexts', 'forbidden_transformations'};
for k = 1:numel(reqO)
    f = reqO{k};
    if ~isfield(opts, f)
        error('switchingWriteCanonicalCsvSidecar:BadOpts', 'opts missing field: %s', f);
    end
end

meta = struct();
meta.is_canonical = true;
meta.table_name = char(string(opts.table_name));
meta.expected_role = char(string(opts.expected_role));
meta.producer_script = char(string(opts.producer_script));
meta.source_run_id = char(string(opts.source_run_id));
meta.lineage_tags = opts.lineage_tags;
meta.forbidden_transformations = opts.forbidden_transformations;
meta.uses_width_scaling = false;
meta.valid_contexts = opts.valid_contexts;
meta.table_sha256 = h0;
meta.created_at_utc = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

jsonText = jsonencode(meta);
for i = 1:numel(paths)
    sidecarPath = [paths{i} '.meta.json'];
    tmpPath = [sidecarPath '.tmp'];
    fid = fopen(tmpPath, 'w');
    if fid < 0
        error('switchingWriteCanonicalCsvSidecar:WriteFail', 'Cannot open for write: %s', tmpPath);
    end
    try
        fprintf(fid, '%s', jsonText);
    catch ME
        fclose(fid);
        if exist(tmpPath, 'file') == 2
            delete(tmpPath);
        end
        rethrow(ME);
    end
    fclose(fid);
    if exist(sidecarPath, 'file') == 2
        delete(sidecarPath);
    end
    movefile(tmpPath, sidecarPath, 'f');
end
end

function h = localSha256Hex(pathIn)
md = java.security.MessageDigest.getInstance('SHA-256');
fis = java.io.FileInputStream(java.io.File(pathIn));
dis = java.security.DigestInputStream(fis, md);
buf = zeros(1, 8192, 'int8');
while dis.read(buf) ~= -1
end
dis.close();
bytes = typecast(md.digest(), 'uint8');
h = lower(reshape(dec2hex(bytes)', 1, []));
end
