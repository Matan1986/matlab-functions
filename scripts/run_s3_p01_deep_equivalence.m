% S3 Deep Equivalence Verification for P01 only.
% Additive execution artifact: does not modify existing implementation files.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
statusDir = fullfile(repoRoot, 'status', 's3_p01_inputs');

if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end
if exist(statusDir, 'dir') ~= 7
    mkdir(statusDir);
end

testCases = [ ...
    struct('name', "valid_input_baseline", 'path', fullfile(statusDir, 'valid_input.csv')), ...
    struct('name', "missing_file", 'path', fullfile(statusDir, 'missing_file.csv')), ...
    struct('name', "malformed_csv", 'path', fullfile(statusDir, 'malformed_csv.csv')), ...
    struct('name', "partial_file_header_only", 'path', fullfile(statusDir, 'partial_header_only.csv')), ...
    struct('name', "wrong_schema", 'path', fullfile(statusDir, 'wrong_schema.csv')) ...
];

% Build controlled fixtures (except missing_file by design).
write_text_file(testCases(1).path, sprintf('MODULE,STATUS\nSwitching,CANONICAL\nAging,CANONICAL\n'));
if exist(testCases(2).path, 'file') == 2
    delete(testCases(2).path);
end
write_text_file(testCases(3).path, sprintf('MODULE,STATUS\n"Switching,CANONICAL\nAging,CANONICAL\n'));
write_text_file(testCases(4).path, sprintf('MODULE,STATUS\n'));
write_text_file(testCases(5).path, sprintf('MODULE,STATE\nSwitching,CANONICAL\n'));

n = numel(testCases);
test_case = strings(n, 1);
explicit_result = strings(n, 1);
readtable_result = strings(n, 1);
explicit_error_type = strings(n, 1);
readtable_error_type = strings(n, 1);
match = strings(n, 1);

for i = 1:n
    caseName = testCases(i).name;
    casePath = testCases(i).path;

    [ePass, eType] = run_explicit_validation(casePath);
    [rPass, rType] = run_readtable_behavior(casePath);

    test_case(i) = caseName;
    explicit_result(i) = ternary_pass_fail(ePass);
    readtable_result(i) = ternary_pass_fail(rPass);
    explicit_error_type(i) = string(eType);
    readtable_error_type(i) = string(rType);
    match(i) = ternary_yes_no(ePass == rPass && strcmp(eType, rType));
end

matrixTbl = table( ...
    test_case, ...
    explicit_result, ...
    readtable_result, ...
    explicit_error_type, ...
    readtable_error_type, ...
    match);

matrixPath = fullfile(tablesDir, 's3_p01_equivalence_matrix.csv');
writetable(matrixTbl, matrixPath);

totalCases = height(matrixTbl);
matchCount = sum(strcmp(matrixTbl.match, "YES"));
matchRate = (matchCount / max(totalCases, 1)) * 100;
fullEquivalence = ternary_yes_no(matchCount == totalCases);
driftDetected = ternary_yes_no(matchCount ~= totalCases);
s3Pass = ternary_yes_no((matchRate == 100) && strcmp(driftDetected, "NO"));

reportPath = fullfile(reportsDir, 's3_p01_equivalence.md');
fid = fopen(reportPath, 'w');
if fid < 0
    error('run_s3_p01_deep_equivalence:ReportWriteFailed', 'Failed writing %s', reportPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# S3 P01 Deep Equivalence Verification\n\n');
fprintf(fid, '- FULL_EQUIVALENCE = %s\n', fullEquivalence);
fprintf(fid, '- TOTAL_CASES = %d\n', totalCases);
fprintf(fid, '- MATCH_RATE = %.2f%%\n', matchRate);
fprintf(fid, '- DRIFT_DETECTED = %s\n', driftDetected);
fprintf(fid, '\n## Final Flags\n');
fprintf(fid, '- S3_EXECUTION_COMPLETE = YES\n');
fprintf(fid, '- S3_PASS = %s\n', s3Pass);
fprintf(fid, '- FULL_EQUIVALENCE = %s\n', fullEquivalence);

function [isPass, errorType] = run_explicit_validation(pathArg)
% Explicit replacement-candidate validation with no readtable call.
try
    explicit_validate_file(pathArg);
    isPass = true;
    errorType = 'NONE';
catch ME
    isPass = false;
    errorType = normalize_error_type(ME);
end
end

function explicit_validate_file(pathArg)
if exist(pathArg, 'file') ~= 2
    error('explicitValidation:MissingFile', 'File not found: %s', pathArg);
end

txt = fileread(pathArg);
lines = regexp(txt, '\r\n|\n|\r', 'split');
if ~isempty(lines) && strlength(string(lines{end})) == 0
    lines = lines(1:end-1);
end
if isempty(lines)
    error('explicitValidation:EmptyFile', 'File is empty: %s', pathArg);
end

header = strtrim(string(lines{1}));
headerCols = split(header, ',');
headerCols = strtrim(headerCols);
requiredCols = ["MODULE", "STATUS"];
if ~all(ismember(requiredCols, headerCols))
    error('explicitValidation:WrongSchema', 'Required columns MODULE,STATUS are missing in %s', pathArg);
end

if numel(lines) < 2
    error('explicitValidation:PartialFile', 'Header-only CSV is not allowed: %s', pathArg);
end

for i = 2:numel(lines)
    lineText = string(lines{i});
    if mod(count(lineText, '"'), 2) ~= 0
        error('explicitValidation:MalformedCSV', 'Unbalanced quote on line %d in %s', i, pathArg);
    end
end
end

function [isPass, errorType] = run_readtable_behavior(pathArg)
try
    T = readtable(pathArg);
    required = {'MODULE', 'STATUS'};
    for j = 1:numel(required)
        if ~ismember(required{j}, T.Properties.VariableNames)
            error('readtableBehavior:WrongSchema', ...
                'Required column %s missing in %s', required{j}, pathArg);
        end
    end
    if height(T) < 1
        error('readtableBehavior:PartialFile', 'Header-only CSV is not allowed: %s', pathArg);
    end
    isPass = true;
    errorType = 'NONE';
catch ME
    isPass = false;
    errorType = normalize_error_type(ME);
end
end

function out = normalize_error_type(ME)
if ~isempty(ME.identifier)
    out = char(string(ME.identifier));
    return;
end
msg = strtrim(string(ME.message));
if strlength(msg) == 0
    out = 'UNKNOWN_ERROR';
else
    msg = replace(msg, newline, ' ');
    out = char("MESSAGE:" + extractBefore(msg + " ", " "));
end
end

function out = ternary_pass_fail(tf)
if tf
    out = "PASS";
else
    out = "FAIL";
end
end

function out = ternary_yes_no(tf)
if tf
    out = "YES";
else
    out = "NO";
end
end

function write_text_file(pathArg, content)
fid = fopen(pathArg, 'w');
if fid < 0
    error('run_s3_p01_deep_equivalence:WriteFailed', 'Failed writing %s', pathArg);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', content);
end
