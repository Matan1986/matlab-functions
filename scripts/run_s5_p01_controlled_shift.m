% S5 Controlled Enforcement Shift for P01 only.
% Validates behavior preservation after moving enforcement out of readtable.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
statusDir = fullfile(repoRoot, 'status', 's5_p01_inputs');
addpath(fullfile(repoRoot, 'tools'));

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
    struct('name', "valid input", 'path', fullfile(statusDir, 'valid_input.csv')), ...
    struct('name', "missing file", 'path', fullfile(statusDir, 'missing_file.csv')), ...
    struct('name', "malformed_csv", 'path', fullfile(statusDir, 'malformed_csv.csv')), ...
    struct('name', "partial header", 'path', fullfile(statusDir, 'partial_header_only.csv')), ...
    struct('name', "wrong schema", 'path', fullfile(statusDir, 'wrong_schema.csv')) ...
];

write_text_file(testCases(1).path, sprintf('MODULE,STATUS\nSwitching,CANONICAL\nAging,CANONICAL\n'));
if exist(testCases(2).path, 'file') == 2
    delete(testCases(2).path);
end
write_text_file(testCases(3).path, sprintf('MODULE,STATUS\n"Switching,CANONICAL\nAging,CANONICAL\n'));
write_text_file(testCases(4).path, sprintf('MODULE,STATUS\n'));
write_text_file(testCases(5).path, sprintf('MODULE,STATE\nSwitching,CANONICAL\n'));

n = numel(testCases);
test_case = strings(n, 1);
final_behavior = strings(n, 1);
matches_original = strings(n, 1);

for i = 1:n
    caseName = testCases(i).name;
    casePath = testCases(i).path;
    caseRoot = make_case_repo_root(repoRoot, caseName, casePath);

    originalPass = observe_original_p01_behavior(caseRoot);
    finalPass = observe_final_p01_behavior(caseRoot);

    test_case(i) = caseName;
    final_behavior(i) = ternary_pass_fail(finalPass);
    matches_original(i) = ternary_yes_no(finalPass == originalPass);
end

outTbl = table(test_case, final_behavior, matches_original);
outPath = fullfile(tablesDir, 's5_p01_post_shift_results.csv');
writetable(outTbl, outPath);

totalCases = height(outTbl);
matchCount = sum(strcmp(outTbl.matches_original, "YES"));
matchRate = (matchCount / max(totalCases, 1)) * 100;
behaviorPreserved = ternary_yes_no(matchCount == totalCases);
shiftSuccess = ternary_yes_no(strcmp(behaviorPreserved, "YES"));
s5Pass = ternary_yes_no((matchRate == 100) && strcmp(behaviorPreserved, "YES"));

reportPath = fullfile(reportsDir, 's5_p01_shift.md');
fid = fopen(reportPath, 'w');
if fid < 0
    error('run_s5_p01_controlled_shift:ReportWriteFailed', 'Failed writing %s', reportPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# S5 P01 Controlled Enforcement Shift\n\n');
fprintf(fid, '- SHIFT_SUCCESS = %s\n', shiftSuccess);
fprintf(fid, '- MATCH_RATE = %.2f%%\n', matchRate);
fprintf(fid, '- BEHAVIOR_PRESERVED = %s\n', behaviorPreserved);
fprintf(fid, '\n## Final Flags\n');
fprintf(fid, '- S5_EXECUTION_COMPLETE = YES\n');
fprintf(fid, '- S5_PASS = %s\n', s5Pass);
fprintf(fid, '- SHIFT_SUCCESS = %s\n', shiftSuccess);

function caseRoot = make_case_repo_root(repoRoot, caseName, casePath)
safeName = regexprep(char(caseName), '[^a-zA-Z0-9]+', '_');
caseRoot = fullfile(repoRoot, 'status', 's5_p01_case_roots', safeName);
tablesCase = fullfile(caseRoot, 'tables');
if exist(tablesCase, 'dir') ~= 7
    mkdir(tablesCase);
end
targetPath = fullfile(tablesCase, 'module_canonical_status.csv');
if exist(targetPath, 'file') == 2
    delete(targetPath);
end
if exist(casePath, 'file') == 2
    copyfile(casePath, targetPath);
end
end

function isPass = observe_original_p01_behavior(caseRoot)
statusPath = fullfile(caseRoot, 'tables', 'module_canonical_status.csv');
try
    T = readtable(statusPath);
    req = {'MODULE', 'STATUS'};
    for j = 1:numel(req)
        if ~ismember(req{j}, T.Properties.VariableNames)
            error('s5_original:Schema', 'Missing required column %s', req{j});
        end
    end
    if height(T) < 1
        error('s5_original:HeaderOnly', 'Header-only data not accepted');
    end
    isPass = true;
catch
    isPass = false;
end
end

function isPass = observe_final_p01_behavior(caseRoot)
try
    loadModuleCanonicalStatus(caseRoot); %#ok<NASGU>
    isPass = true;
catch
    isPass = false;
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
    error('run_s5_p01_controlled_shift:WriteFailed', 'Failed writing %s', pathArg);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', content);
end
