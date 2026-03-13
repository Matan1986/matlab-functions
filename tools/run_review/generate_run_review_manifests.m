function summary = generate_run_review_manifests(resultsRoot)
% generate_run_review_manifests Create missing run_review.json manifests.
%
% This utility scans results/*/runs/run_* directories and creates
% run_review.json only when it does not already exist.
%
% Review status rules:
%   - run_legacy*           -> legacy_auto_approved
%   - run with report docs  -> pending_review
%   - run without reports   -> not_required
%
% A report doc is any .md or .txt file found under the run's reports/
% subtree. Root-level files such as log.txt and run_notes.txt are ignored.
%
% Usage:
%   generate_run_review_manifests
%   summary = generate_run_review_manifests('C:\path\to\results')

if nargin < 1 || isempty(resultsRoot)
    toolDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(fileparts(toolDir));
    resultsRoot = fullfile(repoRoot, 'results');
end

resultsRoot = char(string(resultsRoot));
if exist(resultsRoot, 'dir') ~= 7
    error('Results root not found: %s', resultsRoot);
end

allowedStatuses = { ...
    'legacy_auto_approved', ...
    'pending_review', ...
    'approved', ...
    'rejected', ...
    'not_required'};

runDirs = listRunDirectories(resultsRoot);
summary = struct( ...
    'results_root', resultsRoot, ...
    'total_runs', numel(runDirs), ...
    'created', 0, ...
    'skipped_existing', 0, ...
    'pending_review', 0, ...
    'not_required', 0, ...
    'legacy_auto_approved', 0);

for i = 1:numel(runDirs)
    runDir = runDirs{i};
    [~, runId] = fileparts(runDir);
    reviewPath = fullfile(runDir, 'run_review.json');

    if exist(reviewPath, 'file') == 2
        summary.skipped_existing = summary.skipped_existing + 1;
        continue;
    end

    legacy = isLegacyRun(runId);
    hasReports = hasReportDocuments(fullfile(runDir, 'reports'));
    review = buildRunReview(runId, hasReports, legacy, allowedStatuses);

    writeRunReview(reviewPath, review);

    summary.created = summary.created + 1;
    summary.(review.review_status) = summary.(review.review_status) + 1;
    fprintf('Created run review manifest: %s\n', reviewPath);
end

fprintf('\nRun review manifest generation complete.\n');
fprintf('  Results root: %s\n', summary.results_root);
fprintf('  Total runs: %d\n', summary.total_runs);
fprintf('  Created: %d\n', summary.created);
fprintf('  Skipped existing: %d\n', summary.skipped_existing);
fprintf('  pending_review: %d\n', summary.pending_review);
fprintf('  not_required: %d\n', summary.not_required);
fprintf('  legacy_auto_approved: %d\n', summary.legacy_auto_approved);
end

function runDirs = listRunDirectories(resultsRoot)
experimentEntries = dir(resultsRoot);
runDirs = {};

for i = 1:numel(experimentEntries)
    entry = experimentEntries(i);
    if ~entry.isdir || isDotDirectory(entry.name)
        continue;
    end

    runsDir = fullfile(resultsRoot, entry.name, 'runs');
    if exist(runsDir, 'dir') ~= 7
        continue;
    end

    runEntries = dir(runsDir);
    for j = 1:numel(runEntries)
        runEntry = runEntries(j);
        if ~runEntry.isdir || isDotDirectory(runEntry.name)
            continue;
        end

        if isRunDirectory(runEntry.name)
            runDirs{end + 1} = fullfile(runsDir, runEntry.name); %#ok<AGROW>
        end
    end
end
end

function tf = isRunDirectory(name)
tf = strncmpi(name, 'run_', 4);
end

function tf = isLegacyRun(runId)
tf = strncmpi(runId, 'run_legacy', 10);
end

function tf = isDotDirectory(name)
tf = strcmp(name, '.') || strcmp(name, '..');
end

function tf = hasReportDocuments(reportsDir)
if exist(reportsDir, 'dir') ~= 7
    tf = false;
    return;
end

entries = dir(reportsDir);
tf = false;

for i = 1:numel(entries)
    entry = entries(i);
    if isDotDirectory(entry.name)
        continue;
    end

    fullPath = fullfile(reportsDir, entry.name);
    if entry.isdir
        if hasReportDocuments(fullPath)
            tf = true;
            return;
        end
        continue;
    end

    [~, ~, ext] = fileparts(entry.name);
    if any(strcmpi(ext, {'.md', '.txt'}))
        tf = true;
        return;
    end
end
end

function review = buildRunReview(runId, hasReports, legacy, allowedStatuses)
if legacy
    reviewStatus = 'legacy_auto_approved';
    reviewedBy = 'system';
    reviewDate = generatedTimestamp();
    reviewNotes = 'Auto-generated manifest for a legacy run; eligible without manual review.';
elseif hasReports
    reviewStatus = 'pending_review';
    reviewedBy = '';
    reviewDate = '';
    reviewNotes = 'Auto-generated manifest; report documents were found under reports/ and require review.';
else
    reviewStatus = 'not_required';
    reviewedBy = 'system';
    reviewDate = generatedTimestamp();
    reviewNotes = 'Auto-generated manifest; no report documents were found under reports/.';
end

if ~any(strcmp(reviewStatus, allowedStatuses))
    error('Unsupported review_status generated: %s', reviewStatus);
end

review = struct( ...
    'run_id', runId, ...
    'review_status', reviewStatus, ...
    'reviewed_by', reviewedBy, ...
    'review_date', reviewDate, ...
    'review_notes', reviewNotes, ...
    'legacy', logical(legacy));
end

function timestamp = generatedTimestamp()
timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
end

function writeRunReview(reviewPath, review)
payload = sprintf(['{\n' ...
    '  "run_id": %s,\n' ...
    '  "review_status": %s,\n' ...
    '  "reviewed_by": %s,\n' ...
    '  "review_date": %s,\n' ...
    '  "review_notes": %s,\n' ...
    '  "legacy": %s\n' ...
    '}\n'], ...
    jsonencode(review.run_id), ...
    jsonencode(review.review_status), ...
    jsonencode(review.reviewed_by), ...
    jsonencode(review.review_date), ...
    jsonencode(review.review_notes), ...
    jsonencode(review.legacy));

fid = fopen(reviewPath, 'w', 'n', 'UTF-8');
if fid == -1
    error('Unable to open %s for writing.', reviewPath);
end

cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', payload);
clear cleanupObj;
end
