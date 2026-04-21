% S2 proof step for P01 only:
% Compare explicit validation (replicated from readtable.m guard)
% against actual readtable behavior for the canonical boundary call.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');

if exist(tablesDir, 'dir') ~= 7
    mkdir(tablesDir);
end
if exist(reportsDir, 'dir') ~= 7
    mkdir(reportsDir);
end

targetPath = fullfile(repoRoot, 'tables', 'module_canonical_status.csv');
callId = "P01_loadModuleCanonicalStatus_readtable_001";

explicitPass = explicit_validate_like_readtable_guard(targetPath);
readtablePass = observe_readtable_behavior(targetPath);

explicitResult = ternary_pass_fail(explicitPass);
readtableResult = ternary_pass_fail(readtablePass);
isMatch = strcmp(explicitResult, readtableResult);

resultsTbl = table( ...
    callId, ...
    string(explicitResult), ...
    string(readtableResult), ...
    string(ternary_yes_no(isMatch)), ...
    'VariableNames', {'call_id', 'explicit_validation_result', 'readtable_result', 'match'});

resultsPath = fullfile(tablesDir, 's2_p01_dual_validation_results.csv');
writetable(resultsTbl, resultsPath);

if ~isMatch
    mismatchTbl = table( ...
        callId, ...
        string(targetPath), ...
        string(explicitResult), ...
        string(readtableResult), ...
        string("P01 boundary call mismatch"), ...
        'VariableNames', {'call_id', 'path', 'explicit_validation_result', 'readtable_result', 'reason'});
    writetable(mismatchTbl, fullfile(tablesDir, 's2_p01_mismatch_details.csv'));
end

totalCalls = height(resultsTbl);
matchCount = sum(strcmp(resultsTbl.match, "YES"));
mismatchCount = totalCalls - matchCount;
matchRate = (matchCount / max(totalCalls, 1)) * 100;
behaviorEquivalence = ternary_yes_no(mismatchCount == 0);
s2Pass = ternary_yes_no((matchRate == 100) && (mismatchCount == 0));

reportPath = fullfile(reportsDir, 's2_p01_equivalence.md');
fid = fopen(reportPath, 'w');
if fid < 0
    error('run_s2_p01_dual_validation:ReportWriteFailed', 'Failed writing %s', reportPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# S2 P01 Dual Validation Equivalence\n\n');
fprintf(fid, '- BEHAVIOR_EQUIVALENCE = %s\n', behaviorEquivalence);
fprintf(fid, '- TOTAL_CALLS = %d\n', totalCalls);
fprintf(fid, '- MATCH_RATE = %.2f%%\n', matchRate);
fprintf(fid, '- MISMATCH_COUNT = %d\n', mismatchCount);
fprintf(fid, '\n## Final Flags\n');
fprintf(fid, '- S2_EXECUTION_COMPLETE = YES\n');
fprintf(fid, '- S2_PASS = %s\n', s2Pass);
fprintf(fid, '- BEHAVIOR_EQUIVALENCE = %s\n', behaviorEquivalence);

function out = ternary_pass_fail(tf)
if tf
    out = 'PASS';
else
    out = 'FAIL';
end
end

function out = ternary_yes_no(tf)
if tf
    out = 'YES';
else
    out = 'NO';
end
end

function isPass = observe_readtable_behavior(pathArg)
% Observe actual wrapper + builtin behavior.
try
    readtable(pathArg); %#ok<NASGU>
    isPass = true;
catch
    isPass = false;
end
end

function isPass = explicit_validate_like_readtable_guard(pathArg)
% Explicit replication of readtable.m guard logic (without calling readtable).
isPass = true;

if ~(ischar(pathArg) || isstring(pathArg))
    return;
end

pathText = char(string(pathArg));
if isempty(pathText)
    return;
end

normPath = strrep(pathText, '/', '\');
pathLower = lower(normPath);
if ~(contains(pathLower, '\results\') && contains(pathLower, '\runs\'))
    return;
end

runDir = extract_run_dir_local(normPath);
if isempty(runDir)
    return;
end

statusPath = fullfile(runDir, 'run_status.csv');
if exist(statusPath, 'file') ~= 2
    write_default_status_local(statusPath, 'INVALID');
end

statusValue = read_status_value_local(statusPath);
if strcmp(statusValue, 'PARTIAL')
    isPass = false;
end
end

function runDir = extract_run_dir_local(normPath)
runDir = '';
tokens = regexp(normPath, '^(.*[\\]results[\\][^\\]+[\\]runs[\\](run_[^\\]+))([\\].*)?$', 'tokens', 'once');
if isempty(tokens)
    return;
end
runDir = strrep(tokens{1}, '\\', filesep);
end

function statusValue = read_status_value_local(statusPath)
statusValue = 'INVALID';
fid = fopen(statusPath, 'r');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

lines = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
lines = string(lines{1});
if isempty(lines)
    return;
end

firstLine = upper(strtrim(lines(1)));
if firstLine == "RUN_STATUS"
    if numel(lines) >= 2
        statusValue = upper(strtrim(lines(2)));
    end
else
    statusValue = firstLine;
end

if ~ismember(statusValue, ["CANONICAL", "PARTIAL", "INVALID"])
    statusValue = "INVALID";
end
statusValue = char(statusValue);
end

function write_default_status_local(statusPath, value)
fid = fopen(statusPath, 'w');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'run_status\n');
fprintf(fid, '%s\n', char(string(value)));
end
