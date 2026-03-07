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
run.git_commit = resolveGitCommit(repoRoot);
run.matlab_version = version;
run.host = getComputerName();
run.user = getUserName();

run = ensureRunFilePaths(run);

writeManifest(run, cfg);
writeConfigSnapshot(run.config_snapshot_path, cfg, run);
writeLogHeader(run.log_path, run);
ensureRunNotesFile(run);
updateRunIndex(run, cfg);
updateLatestRunPointer(run);

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

function writeManifest(run, cfg)
manifest = struct();
manifest.run_id = run.run_id;
manifest.timestamp = run.timestamp;
manifest.experiment = run.experiment;
manifest.label = run.label;
manifest.git_commit = run.git_commit;
manifest.matlab_version = run.matlab_version;
manifest.host = run.host;
manifest.user = run.user;
manifest.repo_root = run.repo_root;
manifest.run_dir = run.run_dir;

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
fprintf(fid, 'git_commit: %s\n', run.git_commit);
fprintf(fid, 'matlab_version: %s\n\n', run.matlab_version);
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

function updateRunIndex(run, cfg)
% Maintain per-experiment run index: results/<experiment>/run_index.csv
expRoot = fullfile(run.repo_root, 'results', run.experiment);
if ~exist(expRoot, 'dir')
    mkdir(expRoot);
end

indexPath = fullfile(expRoot, 'run_index.csv');

datasetVal = "";
if isfield(cfg, 'dataset') && ~isempty(cfg.dataset)
    datasetVal = string(cfg.dataset);
end

row = table( ...
    string(run.run_id), ...
    string(run.timestamp), ...
    string(run.label), ...
    string(run.experiment), ...
    datasetVal, ...
    string(run.git_commit), ...
    'VariableNames', {'run_id','timestamp','label','experiment','dataset','git_commit'});

if exist(indexPath, 'file') == 2
    try
        idx = readtable(indexPath, 'TextType', 'string');
    catch
        idx = readtable(indexPath);
    end

    required = row.Properties.VariableNames;
    for i = 1:numel(required)
        v = required{i};
        if ~ismember(v, idx.Properties.VariableNames)
            idx.(v) = strings(height(idx), 1);
        else
            idx.(v) = string(idx.(v));
        end
    end
    idx = idx(:, required);

    % Guard against duplicates by run_id.
    idx = idx(idx.run_id ~= row.run_id(1), :);
    idx = [idx; row];
else
    idx = row;
end

writetable(idx, indexPath);
end

function updateLatestRunPointer(run)
% Write latest run pointer: results/<experiment>/latest_run.txt
expRoot = fullfile(run.repo_root, 'results', run.experiment);
if ~exist(expRoot, 'dir')
    mkdir(expRoot);
end

pointerPath = fullfile(expRoot, 'latest_run.txt');
fid = fopen(pointerPath, 'w');
if fid < 0
    error('Failed to write latest run pointer: %s', pointerPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', run.run_id);
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
