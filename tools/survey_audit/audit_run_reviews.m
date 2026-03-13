% audit_run_reviews
% Audit run-review coverage and survey readiness across results/*/runs/run_*.

thisFile = mfilename('fullpath');
scriptDir = fileparts(thisFile);
toolsDir = fileparts(scriptDir);
repoRoot = fileparts(toolsDir);
resultsRoot = fullfile(repoRoot, 'results');
outputDir = fullfile(repoRoot, 'reports');
outputPath = fullfile(outputDir, 'run_review_audit.md');

if exist(resultsRoot, 'dir') ~= 7
    error('Results root not found: %s', resultsRoot);
end

if exist(outputDir, 'dir') ~= 7
    mkdir(outputDir);
end

runInfos = collectRunInfos(resultsRoot);
if isempty(runInfos)
    error('No run directories found under %s', resultsRoot);
end

runAuditTable = struct2table(runInfos);
runAuditTable = sortrows(runAuditTable, {'experiment', 'run_id'}, {'ascend', 'ascend'});

[allRunIds, allRunIdx] = unique(runAuditTable.run_id, 'stable');
statusByRun = containers.Map('KeyType', 'char', 'ValueType', 'char');
existsByRun = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for i = 1:numel(allRunIds)
    statusByRun(char(allRunIds(i))) = char(runAuditTable.review_status(allRunIdx(i)));
    existsByRun(char(allRunIds(i))) = true;
end

surveyReferenceRows = collectSurveyReferences(runAuditTable, statusByRun, existsByRun);
if isempty(surveyReferenceRows)
    surveyReferenceTable = table( ...
        strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'referenced_run_id', 'review_status', 'approval_state', 'referenced_by'});
else
    surveyReferenceTable = struct2table(surveyReferenceRows);
    surveyReferenceTable = sortrows(surveyReferenceTable, {'referenced_run_id', 'referenced_by'});
end

runAuditTable.pending_review = runAuditTable.has_report & ...
    ~(runAuditTable.review_status == "approved") & ...
    ~(runAuditTable.review_status == "rejected");

summaryMetrics = [ ...
    "total runs"; ...
    "runs with reports"; ...
    "runs with run_review.json"; ...
    "runs pending review"; ...
    "runs approved"; ...
    "runs rejected"; ...
    "runs without report"; ...
    "reports without review manifest"; ...
    "runs referenced in surveys but not approved" ...
    ];

summaryCounts = [ ...
    height(runAuditTable); ...
    sum(runAuditTable.has_report); ...
    sum(runAuditTable.has_review_manifest); ...
    sum(runAuditTable.pending_review); ...
    sum(runAuditTable.review_status == "approved"); ...
    sum(runAuditTable.review_status == "rejected"); ...
    sum(~runAuditTable.has_report); ...
    sum(runAuditTable.has_report & ~runAuditTable.has_review_manifest); ...
    height(surveyReferenceTable) ...
    ];

summaryTable = table(summaryMetrics, summaryCounts, ...
    'VariableNames', {'Metric', 'Count'});

reportLines = buildMarkdownReport(repoRoot, runAuditTable, surveyReferenceTable, summaryTable);
writeTextFile(outputPath, strjoin(cellstr(reportLines), newline));

disp(summaryTable);
fprintf('Run review audit report: %s\n', outputPath);

function runInfos = collectRunInfos(resultsRoot)
resultsEntries = dir(resultsRoot);
resultsEntries = resultsEntries([resultsEntries.isdir]);

runInfos = repmat(makeEmptyRunInfo(), 0, 1);
for i = 1:numel(resultsEntries)
    name = string(resultsEntries(i).name);
    if name == "." || name == ".."
        continue;
    end

    experimentRoot = fullfile(resultsRoot, char(name));
    runsRoot = fullfile(experimentRoot, 'runs');
    if exist(runsRoot, 'dir') ~= 7
        continue;
    end

    runDirs = dir(fullfile(runsRoot, 'run_*'));
    runDirs = runDirs([runDirs.isdir]);
    runDirs = sortStructByName(runDirs);
    for j = 1:numel(runDirs)
        runDir = fullfile(runsRoot, runDirs(j).name);
        runInfos(end + 1, 1) = inspectRun(runDir, char(name)); %#ok<AGROW>
    end
end
end

function runInfo = inspectRun(runDir, experimentName)
runInfo = makeEmptyRunInfo();
runInfo.experiment = string(experimentName);
runInfo.run_dir = string(runDir);
runInfo.run_id = string(getRunId(runDir));

manifestPath = fullfile(runDir, 'run_manifest.json');
if exist(manifestPath, 'file') == 2
    manifest = safeJsonDecode(manifestPath);
    if isfield(manifest, 'run_id') && ~isempty(manifest.run_id)
        runInfo.run_id = string(manifest.run_id);
    end
    if isfield(manifest, 'label') && ~isempty(manifest.label)
        runInfo.label = string(manifest.label);
    else
        runInfo.label = string(extractRunLabel(char(runInfo.run_id)));
    end
    if isfield(manifest, 'experiment') && ~isempty(manifest.experiment)
        runInfo.experiment = string(manifest.experiment);
    end
else
    runInfo.label = string(extractRunLabel(char(runInfo.run_id)));
end

reportFiles = collectReportFiles(runDir);
reviewFiles = collectFilesByName(runDir, 'run_review.json');
reviewFiles = sort(reviewFiles);

runInfo.has_report = ~isempty(reportFiles);
runInfo.report_count = numel(reportFiles);
runInfo.report_paths = join(string(reportFiles), newline);

runInfo.has_review_manifest = ~isempty(reviewFiles);
runInfo.review_manifest_count = numel(reviewFiles);
runInfo.review_manifest_paths = join(string(reviewFiles), newline);
runInfo.review_status = normalizeRunReviewStatus(reviewFiles);

runInfo.is_survey_run = isSurveyLikeRun(runInfo.run_id, runInfo.label, reportFiles, runDir);
end

function surveyReferenceRows = collectSurveyReferences(runAuditTable, statusByRun, existsByRun)
surveyReferenceRows = repmat(struct( ...
    'referenced_run_id', "", ...
    'review_status', "", ...
    'approval_state', "", ...
    'referenced_by', ""), 0, 1);

seenPairs = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for i = 1:height(runAuditTable)
    if ~runAuditTable.is_survey_run(i)
        continue;
    end

    runDirText = toTextScalar(runAuditTable.run_dir(i));
    reportBlob = toTextScalar(runAuditTable.report_paths(i));
    surveyRunId = toTextScalar(runAuditTable.run_id(i));

    rawTexts = {};
    rawTexts{end + 1} = safeReadText(fullfile(char(runDirText), 'run_manifest.json')); %#ok<AGROW>
    rawTexts{end + 1} = safeReadText(fullfile(char(runDirText), 'manifest.json')); %#ok<AGROW>

    reportPaths = splitlines(reportBlob);
    reportPaths = reportPaths(reportPaths ~= "");
    for j = 1:numel(reportPaths)
        rawTexts{end + 1} = safeReadText(char(reportPaths(j))); %#ok<AGROW>
    end

    referencedRunIds = strings(0, 1);
    for j = 1:numel(rawTexts)
        referencedRunIds = [referencedRunIds; extractRunIds(rawTexts{j})]; %#ok<AGROW>
    end

    referencedRunIds = unique(referencedRunIds);
    referencedRunIds = referencedRunIds(referencedRunIds ~= "" & referencedRunIds ~= surveyRunId);
    for j = 1:numel(referencedRunIds)
        refId = char(referencedRunIds(j));
        if ~isKey(existsByRun, refId)
            continue;
        end

        reviewStatus = string(statusByRun(refId));
        if reviewStatus == "approved"
            continue;
        end

        key = sprintf('%s|%s', refId, char(surveyRunId));
        if isKey(seenPairs, key)
            continue;
        end
        seenPairs(key) = true;

        surveyReferenceRows(end + 1, 1) = struct( ... %#ok<AGROW>
            'referenced_run_id', string(refId), ...
            'review_status', reviewStatus, ...
            'approval_state', approvalStateLabel(reviewStatus), ...
            'referenced_by', surveyRunId);
    end
end
end

function lines = buildMarkdownReport(repoRoot, runAuditTable, surveyReferenceTable, summaryTable)
generatedAt = string(datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
reportsMissingReview = runAuditTable(runAuditTable.has_report & ~runAuditTable.has_review_manifest, :);
runsWithoutReport = runAuditTable(~runAuditTable.has_report, :);
runsApproved = runAuditTable(runAuditTable.review_status == "approved", :);
runsRejected = runAuditTable(runAuditTable.review_status == "rejected", :);
runsPending = runAuditTable(runAuditTable.pending_review, :);

lines = cell(0, 1);
lines(end + 1, 1) = {'# Run Review Audit'};
lines(end + 1, 1) = {''};
lines(end + 1, 1) = {sprintf('- Generated: %s', char(generatedAt))};
lines(end + 1, 1) = {sprintf('- Repository root: `%s`', repoRoot)};
lines(end + 1, 1) = {''};
lines(end + 1, 1) = {'## Summary'};
lines(end + 1, 1) = {''};
lines = [lines; tableToMarkdown(summaryTable)];
lines(end + 1, 1) = {''};

lines(end + 1, 1) = {'## Coverage Snapshot'};
lines(end + 1, 1) = {''};
lines(end + 1, 1) = {sprintf('- Survey-like runs detected: `%d`', sum(runAuditTable.is_survey_run))};
lines(end + 1, 1) = {sprintf('- Runs pending review: `%d`', height(runsPending))};
lines(end + 1, 1) = {sprintf('- Reports without review manifest: `%d`', height(reportsMissingReview))};
lines(end + 1, 1) = {sprintf('- Survey references blocked by missing approval: `%d`', height(surveyReferenceTable))};
lines(end + 1, 1) = {''};

lines(end + 1, 1) = {sprintf('## Reports Without Review Manifest (%d)', height(reportsMissingReview))};
lines(end + 1, 1) = {''};
if isempty(reportsMissingReview)
    lines(end + 1, 1) = {'None.'};
else
    lines = [lines; tableToMarkdown(reportsMissingReview(:, {'experiment', 'run_id', 'report_count'}))];
end
lines(end + 1, 1) = {''};

lines(end + 1, 1) = {sprintf('## Runs Referenced In Surveys But Not Approved (%d)', height(surveyReferenceTable))};
lines(end + 1, 1) = {''};
if isempty(surveyReferenceTable)
    lines(end + 1, 1) = {'None.'};
else
    lines = [lines; tableToMarkdown(surveyReferenceTable(:, {'referenced_run_id', 'review_status', 'approval_state', 'referenced_by'}))];
end
lines(end + 1, 1) = {''};

lines(end + 1, 1) = {sprintf('## Pending Review Runs (%d)', height(runsPending))};
lines(end + 1, 1) = {''};
if isempty(runsPending)
    lines(end + 1, 1) = {'None.'};
else
    lines = [lines; tableToMarkdown(runsPending(:, {'experiment', 'run_id', 'report_count', 'has_review_manifest', 'review_status'}))];
end
lines(end + 1, 1) = {''};

lines(end + 1, 1) = {sprintf('## Approved Runs (%d)', height(runsApproved))};
lines(end + 1, 1) = {''};
if isempty(runsApproved)
    lines(end + 1, 1) = {'None.'};
else
    lines = [lines; tableToMarkdown(runsApproved(:, {'experiment', 'run_id', 'review_manifest_count'}))];
end
lines(end + 1, 1) = {''};

lines(end + 1, 1) = {sprintf('## Rejected Runs (%d)', height(runsRejected))};
lines(end + 1, 1) = {''};
if isempty(runsRejected)
    lines(end + 1, 1) = {'None.'};
else
    lines = [lines; tableToMarkdown(runsRejected(:, {'experiment', 'run_id', 'review_manifest_count'}))];
end
lines(end + 1, 1) = {''};

lines(end + 1, 1) = {sprintf('## Runs Without Report (%d)', height(runsWithoutReport))};
lines(end + 1, 1) = {''};
if isempty(runsWithoutReport)
    lines(end + 1, 1) = {'None.'};
else
    lines = [lines; tableToMarkdown(runsWithoutReport(:, {'experiment', 'run_id', 'has_review_manifest'}))];
end
lines(end + 1, 1) = {''};
end

function lines = tableToMarkdown(tbl)
headers = string(tbl.Properties.VariableNames);
lines = cell(height(tbl) + 2, 1);
lines{1} = ['| ' strjoin(cellstr(headers), ' | ') ' |'];
lines{2} = ['| ' strjoin(repmat({'---'}, 1, numel(headers)), ' | ') ' |'];
for i = 1:height(tbl)
    values = cell(1, width(tbl));
    for j = 1:width(tbl)
        values{j} = markdownCell(tbl{i, j});
    end
    lines{i + 2} = ['| ' strjoin(values, ' | ') ' |'];
end
end

function out = markdownCell(value)
if isstring(value) || ischar(value)
    out = char(string(value));
elseif islogical(value)
    out = char(string(value));
elseif isnumeric(value)
    if isscalar(value)
        out = char(string(value));
    else
        out = strjoin(compose('%g', value(:).'), ', ');
    end
else
    out = char(string(value));
end
out = strrep(out, newline, '<br>');
out = strrep(out, '|', '\|');
if isempty(out)
    out = '';
end
end

function runId = getRunId(runDir)
[~, runId] = fileparts(runDir);
end

function label = extractRunLabel(runId)
tokens = regexp(runId, '^run_(?:\d{4}_\d{2}_\d{2}_\d{6}_)?(.+)$', 'tokens', 'once');
if isempty(tokens)
    label = runId;
else
    label = tokens{1};
end
end

function reviewStatus = normalizeRunReviewStatus(reviewFiles)
if isempty(reviewFiles)
    reviewStatus = "missing";
    return;
end

statuses = strings(0, 1);
for i = 1:numel(reviewFiles)
    reviewJson = safeJsonDecode(reviewFiles{i});
    statuses(end + 1, 1) = extractStatusFromStruct(reviewJson); %#ok<AGROW>
end

statuses = unique(statuses);
if any(statuses == "approved") && any(statuses == "rejected")
    reviewStatus = "conflict";
elseif any(statuses == "approved")
    reviewStatus = "approved";
elseif any(statuses == "rejected")
    reviewStatus = "rejected";
elseif any(statuses == "pending")
    reviewStatus = "pending";
else
    reviewStatus = "unknown";
end
end

function status = extractStatusFromStruct(value)
status = "unknown";
if isstruct(value)
    fields = fieldnames(value);
    preferredFields = {'status', 'review_status', 'decision', 'outcome', 'state', 'approval_status'};
    for i = 1:numel(preferredFields)
        fieldName = preferredFields{i};
        if isfield(value, fieldName)
            status = classifyStatusValue(value.(fieldName));
            if status ~= "unknown"
                return;
            end
        end
    end

    for i = 1:numel(fields)
        status = extractStatusFromStruct(value.(fields{i}));
        if status ~= "unknown"
            return;
        end
    end
elseif iscell(value)
    for i = 1:numel(value)
        status = extractStatusFromStruct(value{i});
        if status ~= "unknown"
            return;
        end
    end
elseif isstring(value) || ischar(value)
    status = classifyStatusValue(value);
end
end

function status = classifyStatusValue(value)
textValue = lower(strtrim(char(string(value))));
status = "unknown";
if isempty(textValue)
    return;
end

if contains(textValue, 'approve') || contains(textValue, 'accept') || strcmp(textValue, 'pass')
    status = "approved";
elseif contains(textValue, 'reject') || contains(textValue, 'declin') || strcmp(textValue, 'fail')
    status = "rejected";
elseif contains(textValue, 'pend') || contains(textValue, 'todo') || contains(textValue, 'review') || ...
        contains(textValue, 'open') || contains(textValue, 'queue')
    status = "pending";
end
end

function reportFiles = collectReportFiles(runDir)
mdFiles = dir(fullfile(runDir, '**', '*.md'));
mdFiles = mdFiles(~[mdFiles.isdir]);
reportFiles = {};
for i = 1:numel(mdFiles)
    fullPath = fullfile(mdFiles(i).folder, mdFiles(i).name);
    relativePath = erase(fullPath, [runDir filesep]);
    if isReportCandidate(relativePath)
        reportFiles{end + 1, 1} = fullPath; %#ok<AGROW>
    end
end
end

function tf = isReportCandidate(relativePath)
parts = splitPath(relativePath);
lowerParts = lower(string(parts));
tf = endsWith(lower(string(relativePath)), ".md") && ...
    ~any(lowerParts == "tables") && ...
    ~any(lowerParts == "review") && ...
    ~any(lowerParts == "repaired_figures");
end

function files = collectFilesByName(rootDir, fileName)
entries = dir(fullfile(rootDir, '**', fileName));
entries = entries(~[entries.isdir]);
files = arrayfun(@(s) fullfile(s.folder, s.name), entries, 'UniformOutput', false);
end

function tf = isSurveyLikeRun(runId, label, reportFiles, runDir)
haystack = lower(strjoin([{char(runId)}, {char(label)}, {char(runDir)}], ' '));
if contains(haystack, 'survey')
    tf = true;
    return;
end

tf = false;
for i = 1:numel(reportFiles)
    if contains(lower(reportFiles{i}), 'survey')
        tf = true;
        return;
    end
end
end

function runIds = extractRunIds(textValue)
tokens = regexp(textValue, 'run_[A-Za-z0-9_]+', 'match');
if isempty(tokens)
    runIds = strings(0, 1);
else
    runIds = string(tokens(:));
end
end

function label = approvalStateLabel(reviewStatus)
switch char(reviewStatus)
    case 'approved'
        label = "approved";
    case 'rejected'
        label = "rejected";
    otherwise
        label = "not approved";
end
end

function parts = splitPath(pathValue)
pathValue = strrep(pathValue, '/', filesep);
parts = regexp(pathValue, ['[^' regexptranslate('escape', filesep) ']+'], 'match');
end

function textValue = toTextScalar(value)
if iscell(value)
    if isempty(value)
        textValue = "";
        return;
    end
    value = value{1};
end

if isstring(value)
    if isempty(value)
        textValue = "";
    else
        textValue = string(value(1));
    end
elseif ischar(value)
    textValue = string(value);
elseif ismissing(value)
    textValue = "";
else
    textValue = string(value);
end
end

function manifest = safeJsonDecode(filePath)
raw = fileread(filePath);
raw = sanitizeTextPayload(raw, true, filePath);
manifest = jsondecode(raw);
end

function textValue = safeReadText(filePath)
if exist(filePath, 'file') ~= 2
    textValue = '';
    return;
end
textValue = fileread(filePath);
textValue = sanitizeTextPayload(textValue, false, filePath);
end

function textValue = sanitizeTextPayload(textValue, isJson, filePath)
textValue = char(textValue);
textValue = textValue(:).';
textValue(textValue == 0) = [];
textValue = strrep(textValue, char(65279), '');
if isJson
    firstJsonChar = regexp(textValue, '[\{\[]', 'once');
    if isempty(firstJsonChar)
        error('No JSON object found in %s', filePath);
    end
    textValue = textValue(firstJsonChar:end);
end
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

function runInfo = makeEmptyRunInfo()
runInfo = struct( ...
    'experiment', "", ...
    'run_id', "", ...
    'label', "", ...
    'run_dir', "", ...
    'has_report', false, ...
    'report_count', 0, ...
    'report_paths', "", ...
    'has_review_manifest', false, ...
    'review_manifest_count', 0, ...
    'review_manifest_paths', "", ...
    'review_status', "missing", ...
    'is_survey_run', false);
end

function structs = sortStructByName(structs)
if isempty(structs)
    return;
end
[~, order] = sort(lower(string({structs.name})));
structs = structs(order);
end




