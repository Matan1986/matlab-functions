% build_rolling_surveys
% Build rolling survey markdown files from approved run reviews and claims.
%
% This script performs a preflight validation step before any survey content
% is generated. The validation is intentionally scoped to:
%   - surveys/registry.json
%   - claims/*.json
%   - results/*/runs/run_*/
%
% Safety:
%   - Never modifies results/ or report files
%   - Only creates or updates files under surveys/

thisFile = mfilename('fullpath');
scriptDir = fileparts(thisFile);
toolsDir = fileparts(scriptDir);
repoRoot = fileparts(toolsDir);

resultsRoot = fullfile(repoRoot, 'results');
claimsDir = fullfile(repoRoot, 'claims');
surveysRoot = fullfile(repoRoot, 'surveys');
registryPath = fullfile(surveysRoot, 'registry.json');

% Preflight validation checks repository state and collects run metadata in
% one pass so the builder does not need to rescan the same directories.
[runRecords, diagnostic] = runPreflightValidation(resultsRoot, claimsDir, registryPath);
printDiagnosticSummary(diagnostic);

% Registry loading is separated so schema failures are explicit after the
% filesystem preflight passes.
registry = loadSurveyRegistry(registryPath);

% Claim integration is file-by-file within claims/ and does not infer claims
% from reports or results artifacts.
claims = loadClaims(claimsDir);

approvedStatuses = ["approved", "legacy_auto_approved"];
approvedRuns = runRecords(ismember(string({runRecords.review_status}), approvedStatuses));
pendingRuns = runRecords(strcmp({runRecords.review_status}, 'pending_review'));

generateRollingSurveys(surveysRoot, registry, claims, approvedRuns, pendingRuns);

fprintf('Generated rolling surveys for %d registry entries under %s\n', ...
    numel(registry.surveys), surveysRoot);

function [runRecords, diagnostic] = runPreflightValidation(resultsRoot, claimsDir, registryPath)
% Verify the builder prerequisites before writing any survey output.

if exist(registryPath, 'file') ~= 2
    error('Survey registry not found: %s', registryPath);
end

if exist(claimsDir, 'dir') ~= 7
    error('Claims directory not found: %s', claimsDir);
end

if exist(resultsRoot, 'dir') ~= 7
    error('Results root not found: %s', resultsRoot);
end

runRecords = collectRunRecords(resultsRoot);
if isempty(runRecords)
    error('No run directories found under %s', resultsRoot);
end

hasReviewManifest = [runRecords.has_review_manifest];
if ~any(hasReviewManifest)
    error(['No run_review.json manifests were found under results/*/runs/. ' ...
           'Generate or restore review manifests before building surveys.']);
end

statuses = string({runRecords.review_status});

diagnostic = struct();
diagnostic.total_runs = numel(runRecords);
diagnostic.approved = sum(statuses == "approved");
diagnostic.legacy_auto_approved = sum(statuses == "legacy_auto_approved");
diagnostic.approved_eligible = diagnostic.approved + diagnostic.legacy_auto_approved;
diagnostic.pending_review = sum(statuses == "pending_review");
diagnostic.not_required = sum(statuses == "not_required");
diagnostic.rejected = sum(statuses == "rejected");
diagnostic.missing_review_manifest = sum(~hasReviewManifest);
diagnostic.runs_without_reports = sum(~[runRecords.has_report]);
end

function runRecords = collectRunRecords(resultsRoot)
% Scan only results/*/runs/run_*/ and load each run review manifest.

runRecords = repmat(makeEmptyRunRecord(), 0, 1);

experimentDirs = dir(resultsRoot);
experimentDirs = experimentDirs([experimentDirs.isdir]);
experimentDirs = sortStructByName(experimentDirs);

for i = 1:numel(experimentDirs)
    experimentName = string(experimentDirs(i).name);
    if experimentName == "." || experimentName == ".."
        continue;
    end

    runsRoot = fullfile(resultsRoot, char(experimentName), 'runs');
    if exist(runsRoot, 'dir') ~= 7
        continue;
    end

    runDirs = dir(fullfile(runsRoot, 'run_*'));
    runDirs = runDirs([runDirs.isdir]);
    runDirs = sortStructByName(runDirs);

    for j = 1:numel(runDirs)
        runDir = fullfile(runDirs(j).folder, runDirs(j).name);
        runRecords(end + 1, 1) = inspectRun(runDir, char(experimentName)); %#ok<AGROW>
    end
end
end

function runRecord = inspectRun(runDir, experimentName)
% Read the run review manifest and a small amount of adjacent metadata for
% survey generation. No result files are modified.

runRecord = makeEmptyRunRecord();
runRecord.run_dir = string(runDir);
runRecord.experiment = string(experimentName);
runRecord.run_id = string(getRunIdFromFolder(runDir));
runRecord.has_report = hasReportFiles(runDir);

reviewPath = fullfile(runDir, 'run_review.json');
runRecord.has_review_manifest = exist(reviewPath, 'file') == 2;

manifestPath = fullfile(runDir, 'run_manifest.json');
if exist(manifestPath, 'file') == 2
    manifest = safeJsonDecode(manifestPath);
    if isfield(manifest, 'run_id') && ~isempty(manifest.run_id)
        runRecord.run_id = string(manifest.run_id);
    end
    if isfield(manifest, 'experiment') && ~isempty(manifest.experiment)
        runRecord.experiment = string(manifest.experiment);
    end
end

if ~runRecord.has_review_manifest
    runRecord.review_status = 'missing';
    return;
end

review = safeJsonDecode(reviewPath);
if isfield(review, 'run_id') && ~isempty(review.run_id)
    runRecord.run_id = string(review.run_id);
end

runRecord.review_status = char(normalizeReviewStatus(getOptionalScalar(review, 'review_status', 'missing')));
runRecord.interpretation_summary = getOptionalScalar(review, 'interpretation_summary', '');
end

function registry = loadSurveyRegistry(registryPath)
% Load and validate surveys/registry.json.

registry = safeJsonDecode(registryPath);
if ~isstruct(registry) || ~isfield(registry, 'surveys')
    error('Invalid survey registry format: missing "surveys" field.');
end
if ~isstruct(registry.surveys)
    error('Invalid survey registry format: "surveys" must decode to a struct array.');
end
end

function claims = loadClaims(claimsDir)
% Load claims/*.json and extract the fields used by rolling surveys.

claimFiles = dir(fullfile(claimsDir, '*.json'));
claimFiles = claimFiles(~[claimFiles.isdir]);
claimFiles = sortStructByName(claimFiles);

claims = repmat(makeEmptyClaimRecord(), 0, 1);
for i = 1:numel(claimFiles)
    claimPath = fullfile(claimFiles(i).folder, claimFiles(i).name);
    [~, stem] = fileparts(claimFiles(i).name);

    claimData = safeJsonDecode(claimPath);

    claimRecord = makeEmptyClaimRecord();
    claimRecord.claim_id = getOptionalScalar(claimData, 'claim_id', stem);
    claimRecord.statement = getOptionalScalar(claimData, 'statement', '');
    claimRecord.status = getOptionalScalar(claimData, 'status', '');
    claimRecord.source_runs = getStringArrayField(claimData, 'source_runs');
    claimRecord.related_surveys = getStringArrayField(claimData, 'related_surveys');

    claims(end + 1, 1) = claimRecord; %#ok<AGROW>
end
end

function generateRollingSurveys(surveysRoot, registry, claims, approvedRuns, pendingRuns)
% Create or update surveys/<survey_id>/rolling_survey.md for every registry
% entry using claim-linked approved runs plus globally pending reviews.

surveys = registry.surveys;
for i = 1:numel(surveys)
    survey = surveys(i);
    surveyId = char(getOptionalScalar(survey, 'survey_id', sprintf('survey_%d', i)));

    surveyDir = fullfile(surveysRoot, surveyId);
    if exist(surveyDir, 'dir') ~= 7
        mkdir(surveyDir);
    end

    linkedClaims = selectClaimsForSurvey(claims, surveyId);
    if isempty(linkedClaims)
        claimRunIds = strings(0, 1);
    else
        claimRunIds = unique(vertcat(linkedClaims.source_runs));
        claimRunIds = claimRunIds(claimRunIds ~= "");
    end

    if isempty(claimRunIds)
        contributingRuns = repmat(makeEmptyRunRecord(), 0, 1);
    else
        contributingRuns = approvedRuns(ismember(string({approvedRuns.run_id}), claimRunIds));
    end

    surveyPath = fullfile(surveyDir, 'rolling_survey.md');
    markdown = buildSurveyMarkdown(surveyId, linkedClaims, contributingRuns, pendingRuns);
    writeTextFile(surveyPath, markdown);
end
end

function linkedClaims = selectClaimsForSurvey(claims, surveyId)
if isempty(claims)
    linkedClaims = repmat(makeEmptyClaimRecord(), 0, 1);
    return;
end

matches = false(numel(claims), 1);
for i = 1:numel(claims)
    matches(i) = any(strcmpi(cellstr(claims(i).related_surveys), surveyId));
end
linkedClaims = claims(matches);
end

function markdown = buildSurveyMarkdown(surveyId, linkedClaims, contributingRuns, pendingRuns)
% Assemble the rolling survey markdown with clearly separated sections for
% claims, approved run contributions, and pending review visibility.

lines = cell(0, 1);
lines{end + 1, 1} = sprintf('# Rolling Survey: %s', surveyId);
lines{end + 1, 1} = '';

lines{end + 1, 1} = '## Supported Claims';
lines{end + 1, 1} = '';
if isempty(linkedClaims)
    lines{end + 1, 1} = 'No claims currently reference this survey.';
else
    for i = 1:numel(linkedClaims)
        supportingRuns = joinForMarkdown(linkedClaims(i).source_runs);
        if strlength(supportingRuns) == 0
            supportingRuns = "None listed";
        end

        lines{end + 1, 1} = sprintf('- `%s`: %s', ...
            char(linkedClaims(i).claim_id), char(defaultIfEmpty(linkedClaims(i).statement, "No statement provided.")));
        lines{end + 1, 1} = sprintf('  Status: `%s`', char(defaultIfEmpty(linkedClaims(i).status, "unknown")));
        lines{end + 1, 1} = sprintf('  Supporting runs: %s', char(supportingRuns));
    end
end
lines{end + 1, 1} = '';

lines{end + 1, 1} = '## Contributing Runs';
lines{end + 1, 1} = '';
if isempty(contributingRuns)
    lines{end + 1, 1} = 'No approved or legacy auto-approved runs are linked to this survey through claims.';
else
    for i = 1:numel(contributingRuns)
        summaryText = defaultIfEmpty(string(contributingRuns(i).interpretation_summary), "No interpretation summary provided.");
        lines{end + 1, 1} = sprintf('- `%s` (%s)', char(contributingRuns(i).run_id), char(contributingRuns(i).experiment));
        lines{end + 1, 1} = sprintf('  Summary: %s', char(summaryText));
    end
end
lines{end + 1, 1} = '';

lines{end + 1, 1} = '## Pending Reviews';
lines{end + 1, 1} = '';
if isempty(pendingRuns)
    lines{end + 1, 1} = 'No runs are currently waiting on review.';
else
    for i = 1:numel(pendingRuns)
        reportState = ternary(pendingRuns(i).has_report, 'report found', 'no report found');
        lines{end + 1, 1} = sprintf('- `%s` (%s, %s)', ...
            char(pendingRuns(i).run_id), char(pendingRuns(i).experiment), char(reportState));
    end
end
lines{end + 1, 1} = '';

markdown = strjoin(lines, newline);
end

function printDiagnosticSummary(diagnostic)
% Print a compact preflight summary before survey generation starts.

fprintf('Preflight validation summary\n');
fprintf('  Total runs: %d\n', diagnostic.total_runs);
fprintf('  Approved runs: %d\n', diagnostic.approved_eligible);
fprintf('    Manual approved: %d\n', diagnostic.approved);
fprintf('    Legacy auto-approved: %d\n', diagnostic.legacy_auto_approved);
fprintf('  Pending review: %d\n', diagnostic.pending_review);
fprintf('  Not required: %d\n', diagnostic.not_required);
fprintf('  Rejected: %d\n', diagnostic.rejected);
fprintf('  Runs without reports: %d\n', diagnostic.runs_without_reports);
fprintf('  Runs without run_review.json: %d\n', diagnostic.missing_review_manifest);
end

function value = defaultIfEmpty(value, fallbackValue)
value = string(value);
if strlength(strtrim(value)) == 0
    value = string(fallbackValue);
end
end

function out = ternary(condition, trueValue, falseValue)
if condition
    out = string(trueValue);
else
    out = string(falseValue);
end
end

function hasReport = hasReportFiles(runDir)
reportFiles = dir(fullfile(runDir, '**', '*.md'));
reportFiles = reportFiles(~[reportFiles.isdir]);

hasReport = false;
for i = 1:numel(reportFiles)
    relativePath = erase(fullfile(reportFiles(i).folder, reportFiles(i).name), [runDir filesep]);
    if isReportCandidate(relativePath)
        hasReport = true;
        return;
    end
end
end

function tf = isReportCandidate(relativePath)
parts = splitPath(relativePath);
lowerParts = lower(string(parts));
tf = endsWith(lower(string(relativePath)), ".md") && ...
    ~any(lowerParts == "tables") && ...
    ~any(lowerParts == "review") && ...
    ~any(lowerParts == "repaired_figures") && ...
    ~strcmpi(string(relativePath), "rolling_survey.md");
end

function out = joinForMarkdown(values)
if isempty(values)
    out = "";
    return;
end
out = string(strjoin(cellstr(values(:)), ', '));
end

function value = getOptionalScalar(st, fieldName, defaultValue)
value = string(defaultValue);
if ~(isstruct(st) && isfield(st, fieldName))
    return;
end

raw = st.(fieldName);
if isempty(raw)
    return;
end

if isstring(raw)
    value = string(raw(1));
elseif ischar(raw)
    value = string(raw);
elseif isnumeric(raw) || islogical(raw)
    value = string(raw(1));
elseif iscell(raw) && ~isempty(raw)
    value = string(raw{1});
else
    value = string(raw);
end
end

function values = getStringArrayField(st, fieldName)
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
elseif ischar(raw)
    values = string({raw});
elseif iscell(raw)
    values = strings(numel(raw), 1);
    for i = 1:numel(raw)
        values(i) = string(raw{i});
    end
elseif isnumeric(raw) || islogical(raw)
    values = string(raw(:));
end
end

function runId = getRunIdFromFolder(runDir)
[~, runId] = fileparts(runDir);
end

function manifest = safeJsonDecode(filePath)
raw = fileread(filePath);
raw = sanitizeTextPayload(raw, filePath);
manifest = jsondecode(raw);
end

function textValue = sanitizeTextPayload(textValue, filePath)
textValue = char(textValue);
textValue = textValue(:).';
textValue(textValue == 0) = [];
textValue = strrep(textValue, char(65279), '');

firstBrace = strfind(textValue, '{');
firstBracket = strfind(textValue, '[');
firstCandidates = [firstBrace, firstBracket];
if isempty(firstCandidates)
    error('No JSON object found in %s', filePath);
end
textValue = textValue(min(firstCandidates):end);
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, 'w', 'n', 'UTF-8');
if fid == -1
    error('Could not open %s for writing.', filePath);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', textValue);
clear cleanupObj;
end

function parts = splitPath(pathValue)
pathValue = strrep(pathValue, '/', filesep);
parts = regexp(pathValue, ['[^' regexptranslate('escape', filesep) ']+'], 'match');
end

function status = normalizeReviewStatus(value)
status = lower(strtrim(char(string(value))));
switch status
    case {'approved', 'legacy_auto_approved', 'pending_review', 'not_required', 'rejected'}
        % recognized review states
    otherwise
        if isempty(status)
            status = 'missing';
        end
end
end

function record = makeEmptyRunRecord()
record = struct( ...
    'run_id', "", ...
    'experiment', "", ...
    'run_dir', "", ...
    'review_status', "missing", ...
    'interpretation_summary', "", ...
    'has_review_manifest', false, ...
    'has_report', false);
end

function record = makeEmptyClaimRecord()
record = struct( ...
    'claim_id', "", ...
    'statement', "", ...
    'status', "", ...
    'source_runs', strings(0, 1), ...
    'related_surveys', strings(0, 1));
end

function structs = sortStructByName(structs)
if isempty(structs)
    return;
end
[~, order] = sort(lower(string({structs.name})));
structs = structs(order);
end
