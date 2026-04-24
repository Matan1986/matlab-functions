function meta = validateCanonicalInputTable(tablePath, context)
%VALIDATECANONICALINPUTTABLE Validate canonical metadata sidecar for table input.
% Hard-fail validator for canonical collapse input gating.

if nargin < 2 || ~isstruct(context)
    error('validateCanonicalInputTable:BadContext', 'context struct is required.');
end
if nargin < 1 || strlength(string(tablePath)) == 0
    error('validateCanonicalInputTable:BadPath', 'tablePath is required.');
end

tablePath = char(string(tablePath));
if exist(tablePath, 'file') ~= 2
    error('validateCanonicalInputTable:MissingTable', 'Input table not found: %s', tablePath);
end

sidecarPath = [tablePath '.meta.json'];
if exist(sidecarPath, 'file') ~= 2
    error('validateCanonicalInputTable:MissingMetadata', ...
        'Missing metadata sidecar for canonical validation: %s', sidecarPath);
end

txt = fileread(sidecarPath);
try
    m = jsondecode(txt);
catch ME
    error('validateCanonicalInputTable:BadMetadataJson', ...
        'Invalid metadata JSON at %s (%s)', sidecarPath, ME.message);
end

requiredFields = {'is_canonical','producer_script','source_run_id','lineage_tags','forbidden_transformations','uses_width_scaling','valid_contexts'};
for i = 1:numel(requiredFields)
    f = requiredFields{i};
    if ~isfield(m, f)
        error('validateCanonicalInputTable:MissingField', ...
            'Metadata sidecar missing required field "%s": %s', f, sidecarPath);
    end
end

if ~toLogical(m.is_canonical)
    error('validateCanonicalInputTable:NonCanonicalInput', ...
        'Input is not canonical per metadata: %s', tablePath);
end
if toLogical(m.uses_width_scaling)
    error('validateCanonicalInputTable:WidthScalingDetected', ...
        'Metadata declares width scaling usage (blocked): %s', tablePath);
end

producerScript = strtrim(char(string(m.producer_script)));
sourceRunId = strtrim(char(string(m.source_run_id)));
if isempty(producerScript)
    error('validateCanonicalInputTable:MissingProducerScript', ...
        'Metadata producer_script is empty: %s', sidecarPath);
end
if isempty(sourceRunId)
    error('validateCanonicalInputTable:MissingSourceRunId', ...
        'Metadata source_run_id is empty: %s', sidecarPath);
end

lineageTags = toStringArray(m.lineage_tags);
forbiddenTransforms = toStringArray(m.forbidden_transformations);
validContexts = toStringArray(m.valid_contexts);

blockedTagTokens = ["width_scaling","width_normalization","legacy_scaling","fwhm_scaling","normalized_by_width"];
if any(contains(lower(lineageTags), blockedTagTokens))
    error('validateCanonicalInputTable:BlockedLineageTag', ...
        'Metadata lineage_tags include blocked width/legacy scaling tag(s): %s', tablePath);
end
if any(contains(lower(forbiddenTransforms), "width_scaling"))
    error('validateCanonicalInputTable:ForbiddenTransformation', ...
        'Metadata forbidden_transformations contains width_scaling: %s', tablePath);
end

requiredContext = "canonical_collapse";
if isfield(context, 'required_context') && strlength(string(context.required_context)) > 0
    requiredContext = string(context.required_context);
end
if isempty(validContexts) || ~any(strcmpi(validContexts, requiredContext))
    error('validateCanonicalInputTable:InvalidContext', ...
        'Context "%s" is not allowed by metadata for %s', char(requiredContext), tablePath);
end

if isfield(m, 'table_sha256') && strlength(string(m.table_sha256)) > 0
    actualHash = computeSha256Hex(tablePath);
    expectedHash = lower(char(string(m.table_sha256)));
    if ~strcmpi(actualHash, expectedHash)
        error('validateCanonicalInputTable:HashMismatch', ...
            'table_sha256 mismatch for %s', tablePath);
    end
end

if isfield(context, 'repo_root') && strlength(string(context.repo_root)) > 0
    repoRoot = char(string(context.repo_root));
    runsRoot = switchingCanonicalRunRoot(repoRoot);
    manifestPath = fullfile(runsRoot, sourceRunId, 'run_manifest.json');
    if exist(manifestPath, 'file') ~= 2
        error('validateCanonicalInputTable:MissingManifest', ...
            'Manifest not found for source_run_id=%s at %s', sourceRunId, manifestPath);
    end
    try
        jm = jsondecode(fileread(manifestPath));
    catch
        error('validateCanonicalInputTable:BadManifestJson', ...
            'Invalid run manifest JSON: %s', manifestPath);
    end
    if ~isfield(jm, 'label') || ~strcmp(string(jm.label), "switching_canonical")
        error('validateCanonicalInputTable:ManifestNotCanonical', ...
            'Manifest label is not switching_canonical for source_run_id=%s', sourceRunId);
    end
end

meta = struct();
meta.table_path = string(tablePath);
meta.metadata_path = string(sidecarPath);
meta.is_canonical = true;
meta.uses_width_scaling = false;
meta.producer_script = string(producerScript);
meta.source_run_id = string(sourceRunId);
meta.lineage_tags = lineageTags;
meta.valid_contexts = validContexts;
meta.table_sha256_present = isfield(m, 'table_sha256') && strlength(string(m.table_sha256)) > 0;
end

function a = toStringArray(v)
if isstring(v)
    a = v(:);
elseif ischar(v)
    a = string({v});
elseif iscell(v)
    a = string(v(:));
else
    a = string(v);
end
a = strtrim(a);
a = a(strlength(a) > 0);
end

function tf = toLogical(v)
if islogical(v)
    tf = logical(v);
    return;
end
s = lower(strtrim(char(string(v))));
tf = strcmp(s, 'true') || strcmp(s, '1') || strcmp(s, 'yes');
end

function h = computeSha256Hex(pathIn)
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
