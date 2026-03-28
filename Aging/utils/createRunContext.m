function run = createRunContext(experiment, cfg)
% createRunContext Create/reuse run-scoped output context and metadata artifacts.
%
% Usage:
%   run = createRunContext('aging', cfg);
%
% Creates (new run):
%   results/<experiment>/runs/<run_id>/
%     - run_manifest.json
%     - config_snapshot.m
%     - log.txt
%     - run_notes.txt

if nargin < 1 || isempty(experiment)
    error('createRunContext requires experiment name.');
end
if nargin < 2 || ~isstruct(cfg)
    cfg = struct();
end

experiment = char(string(experiment));

thisFile = mfilename('fullpath');
utilsDir = fileparts(thisFile);
agingDir = fileparts(utilsDir);
repoRoot = fileparts(agingDir);

% Reuse existing run context if provided by caller.
if isfield(cfg, 'run') && isstruct(cfg.run) && isfield(cfg.run, 'run_id') && ~isempty(cfg.run.run_id)
    run = cfg.run;

    if ~isfield(run, 'experiment') || isempty(run.experiment)
        run.experiment = experiment;
    end
    if ~isfield(run, 'repo_root') || isempty(run.repo_root)
        run.repo_root = repoRoot;
    end
    if ~isfield(run, 'run_dir') || isempty(run.run_dir)
        run.run_dir = fullfile(repoRoot, 'results', experiment, 'runs', run.run_id);
    end

    if ~exist(run.run_dir, 'dir')
        mkdir(run.run_dir);
    end

    run = ensureRunFilePaths(run);
    ensureRunNotesFile(run);

    setRunContextAppdata(run);
    return;
end

runsRoot = fullfile(repoRoot, 'results', experiment, 'runs');
if ~exist(runsRoot, 'dir')
    mkdir(runsRoot);
end

runLabel = resolveRunLabel(cfg);
runId = makeUniqueRunId(runsRoot, runLabel);
runDir = fullfile(runsRoot, runId);
if ~exist(runDir, 'dir')
    mkdir(runDir);
end

run = struct();
run.run_id = runId;
run.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
run.experiment = experiment;
run.label = runLabel;
run.repo_root = repoRoot;
run.run_dir = runDir;
fingerprint = computeRunFingerprint(repoRoot);

run = ensureRunFilePaths(run);

writeManifest(run, cfg, fingerprint);
writeConfigSnapshot(run.config_snapshot_path, cfg, run);
writeLogHeader(run.log_path, run);
ensureRunNotesFile(run);

setRunContextAppdata(run);
end

function run = ensureRunFilePaths(run)
run.manifest_path = fullfile(run.run_dir, 'run_manifest.json');
run.config_snapshot_path = fullfile(run.run_dir, 'config_snapshot.m');
run.log_path = fullfile(run.run_dir, 'log.txt');
run.notes_path = fullfile(run.run_dir, 'run_notes.txt');
end

function runId = makeUniqueRunId(runsRoot, runLabel)
ts = char(datetime('now', 'Format', 'yyyy_MM_dd_HHmmss'));
baseId = ['run_' ts];
if ~isempty(runLabel)
    baseId = [baseId '_' runLabel];
end

runId = baseId;
k = 1;
while exist(fullfile(runsRoot, runId), 'dir') == 7
    runId = sprintf('%s_%02d', baseId, k);
    k = k + 1;
end
end

function label = resolveRunLabel(cfg)
label = '';

candidateFields = {'runLabel', 'analysisLabel', 'dataset', 'datasetName'};
for i = 1:numel(candidateFields)
    f = candidateFields{i};
    if isfield(cfg, f)
        v = cfg.(f);
        if ~isempty(v)
            label = sanitizeLabel(v);
            if ~isempty(label)
                return;
            end
        end
    end
end
end

function label = sanitizeLabel(v)
label = char(string(v));
label = strtrim(label);
if isempty(label)
    return;
end

label = regexprep(label, '\s+', '_');
label = regexprep(label, '[^A-Za-z0-9_-]', '_');
label = regexprep(label, '_+', '_');
label = regexprep(label, '-+', '-');
label = regexprep(label, '^[_-]+', '');
label = regexprep(label, '[_-]+$', '');

maxLen = 40;
if numel(label) > maxLen
    label = label(1:maxLen);
    label = regexprep(label, '[_-]+$', '');
end
end

function commit = resolveGitCommit(repoRoot)
commit = '';
try
    [status, out] = system(sprintf('git -C "%s" rev-parse HEAD', repoRoot));
    if status == 0
        commit = strtrim(out);
    end
catch
    commit = '';
end
if isempty(commit)
    commit = 'unknown';
end
end

function writeManifest(run, cfg, fingerprint)
if exist(run.manifest_path, 'file') == 2
    warning('Run manifest already exists; preserving existing file: %s', run.manifest_path);
    return;
end

if nargin < 3 || ~isstruct(fingerprint)
    error('writeManifest requires a fingerprint struct from computeRunFingerprint.');
end

normalizedRepoRoot = normalizeAbsolutePath(run.repo_root);
normalizedRunDir = normalizeAbsolutePath(run.run_dir);
if ~isfield(fingerprint, 'git_commit') || isempty(fingerprint.git_commit)
    fingerprint.git_commit = 'unknown';
end
if ~isfield(fingerprint, 'script_path') || isempty(fingerprint.script_path)
    fingerprint.script_path = '';
end
if ~isfield(fingerprint, 'script_hash') || isempty(fingerprint.script_hash)
    fingerprint.script_hash = '';
end
if ~isfield(fingerprint, 'matlab_version') || isempty(fingerprint.matlab_version)
    fingerprint.matlab_version = 'unknown';
end
if ~isfield(fingerprint, 'host') || isempty(fingerprint.host)
    fingerprint.host = 'unknown';
end
if ~isfield(fingerprint, 'user') || isempty(fingerprint.user)
    fingerprint.user = 'unknown';
end
requiredOutputs = sort({ ...
    normalizeAbsolutePath(run.manifest_path), ...
    normalizeAbsolutePath(run.config_snapshot_path), ...
    normalizeAbsolutePath(run.log_path), ...
    normalizeAbsolutePath(run.notes_path)});

manifest = struct();
manifest.run_id = run.run_id;
manifest.timestamp = run.timestamp;
manifest.execution_start = run.timestamp;
manifest.experiment = run.experiment;
manifest.label = run.label;
manifest.git_commit = fingerprint.git_commit;
manifest.matlab_version = fingerprint.matlab_version;
manifest.host = fingerprint.host;
manifest.user = fingerprint.user;
manifest.repo_root = normalizedRepoRoot;
manifest.run_dir = normalizedRunDir;
manifest.script_path = fingerprint.script_path;
manifest.script_hash = fingerprint.script_hash;
manifest.required_outputs = requiredOutputs;
manifest.manifest_valid = true;

if isfield(cfg, 'datasetName')
    manifest.dataset = cfg.datasetName;
elseif isfield(cfg, 'dataset')
    manifest.dataset = cfg.dataset;
else
    manifest.dataset = '';
end

try
    jsonText = jsonencode(manifest, 'PrettyPrint', true);
catch
    jsonText = jsonencode(manifest);
end

fid = fopen(run.manifest_path, 'w');
if fid < 0
    error('Failed to write run manifest: %s', run.manifest_path);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', jsonText);
end

function fingerprint = computeRunFingerprint(repoRoot)
fingerprint = struct();
fingerprint.git_commit = resolveGitCommit(repoRoot);
fingerprint.script_path = resolveCallingScriptPath();
fingerprint.script_hash = computeFileSha256(fingerprint.script_path);
fingerprint.matlab_version = version;
fingerprint.host = getComputerName();
fingerprint.user = getUserName();
end

function absPath = normalizeAbsolutePath(pathValue)
pathText = strtrim(char(string(pathValue)));
if isempty(pathText)
    absPath = '';
    return;
end
try
    absPath = char(java.io.File(pathText).getCanonicalPath());
catch
    if isAbsolutePath(pathText)
        absPath = pathText;
    else
        absPath = fullfile(pwd, pathText);
    end
end
absPath = strrep(absPath, '/', filesep);
absPath = strrep(absPath, '\\', filesep);
end

function tf = isAbsolutePath(pathText)
if isempty(pathText)
    tf = false;
    return;
end
tf = (~isempty(regexp(pathText, '^[A-Za-z]:[\\/]', 'once')) || startsWith(pathText, '\\\\'));
end

function scriptPath = resolveCallingScriptPath()
stack = dbstack('-completenames');
thisFile = mfilename('fullpath');

scriptPath = '';
for i = 1:numel(stack)
    if isfield(stack(i), 'file')
        candidate = char(string(stack(i).file));
        if ~isempty(candidate) && ~strcmpi(candidate, thisFile)
            scriptPath = normalizeAbsolutePath(candidate);
            return;
        end
    end
end

scriptPath = normalizeAbsolutePath(thisFile);
end

function hashHex = computeFileSha256(filePath)
hashHex = '';
if isempty(filePath) || exist(filePath, 'file') ~= 2
    return;
end

fid = fopen(filePath, 'rb');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

bytes = fread(fid, Inf, '*uint8');
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest = typecast(md.digest(), 'uint8');
hashHex = lower(reshape(dec2hex(digest).', 1, []));
end

function writeConfigSnapshot(snapshotPath, cfg, run)
% Preferred: exact MATLAB script snapshot when available.
if exist('matlab.io.saveVariablesToScript', 'file') == 2
    try
        matlab.io.saveVariablesToScript(snapshotPath, 'cfg');
        appendRunInfo(snapshotPath, run);
        return;
    catch
        % Fall through to JSON snapshot fallback.
    end
end

% Fallback: reproducible value snapshot via JSON.
try
    cfgJson = jsonencode(cfg);
catch
    cfgJson = '{}';
end
cfgJsonEscaped = strrep(cfgJson, '''', '''''');

fid = fopen(snapshotPath, 'w');
if fid < 0
    error('Failed to write config snapshot: %s', snapshotPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '%% Auto-generated config snapshot for %s\n', run.run_id);
fprintf(fid, '%% Timestamp: %s\n', run.timestamp);
fprintf(fid, '%% Experiment: %s\n', run.experiment);
fprintf(fid, '%% Label: %s\n\n', run.label);
fprintf(fid, 'cfg_snapshot_json = ''%s'';\n', cfgJsonEscaped);
fprintf(fid, 'cfg_snapshot = jsondecode(cfg_snapshot_json);\n');
fprintf(fid, 'cfg = cfg_snapshot;\n');
end

function appendRunInfo(snapshotPath, run)
fid = fopen(snapshotPath, 'a');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '\n%% Run metadata\n');
fprintf(fid, 'run_info = struct();\n');
fprintf(fid, 'run_info.run_id = ''%s'';\n', run.run_id);
fprintf(fid, 'run_info.timestamp = ''%s'';\n', run.timestamp);
fprintf(fid, 'run_info.experiment = ''%s'';\n', run.experiment);
fprintf(fid, 'run_info.label = ''%s'';\n', run.label);
fprintf(fid, 'if ~exist(''cfg_snapshot'',''var'') && exist(''cfg'',''var''), cfg_snapshot = cfg; end\n');
end

function writeLogHeader(logPath, run)
fid = fopen(logPath, 'a');
if fid < 0
    error('Failed to write run log: %s', logPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '[%s] Run initialized\n', run.timestamp);
fprintf(fid, 'run_id: %s\n', run.run_id);
fprintf(fid, 'label: %s\n', run.label);
fprintf(fid, 'experiment: %s\n', run.experiment);
fprintf(fid, '\n');
end

function ensureRunNotesFile(run)
if ~isfield(run, 'notes_path') || isempty(run.notes_path)
    return;
end
if exist(run.notes_path, 'file') == 2
    return;
end
fid = fopen(run.notes_path, 'w');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
% Intentionally empty template for manual notes.
end


function setRunContextAppdata(run)
% Canonical root appdata storage for active run context.
setappdata(0, 'runContext', run);
% Backward-compatible key for existing callers.
setappdata(0, 'MATLAB_FUNCTIONS_ACTIVE_RUN_CONTEXT', run);
end

function name = getComputerName()
name = getenv('COMPUTERNAME');
if isempty(name)
    name = getenv('HOSTNAME');
end
if isempty(name)
    name = 'unknown';
end
end

function user = getUserName()
user = getenv('USERNAME');
if isempty(user)
    user = getenv('USER');
end
if isempty(user)
    user = 'unknown';
end
end


