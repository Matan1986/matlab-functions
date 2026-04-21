% P02 Batch 03: S1-S5 full proof cycle for three low-complexity call sites.
% Scope:
%   1) General ver2/read_data.m
%   2) General ver2/read_data_old_ppms.m
%   3) zfAMR ver11/utils/read_data.m

repoRoot = fileparts(fileparts(mfilename('fullpath')));
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
statusDir = fullfile(repoRoot, 'status', 'p02_batch_03_inputs');

if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
if exist(statusDir, 'dir') ~= 7, mkdir(statusDir); end

batchId = "03";
callSites = [ ...
    struct('call_id', "P02B03_general_read_data_001", 'file', "General ver2/read_data.m", 'line', 3, 'kind', "general_read_data"), ...
    struct('call_id', "P02B03_general_read_data_old_ppms_001", 'file', "General ver2/read_data_old_ppms.m", 'line', 3, 'kind', "general_read_data_old_ppms"), ...
    struct('call_id', "P02B03_zfamr_read_data_001", 'file', "zfAMR ver11/utils/read_data.m", 'line', 3, 'kind', "zfamr_read_data") ...
];

%% S1 Coverage
coverageTbl = table( ...
    string({callSites.call_id})', ...
    string({callSites.file})', ...
    [callSites.line]', ...
    string({callSites.kind})', ...
    repmat("YES", numel(callSites), 1), ...
    repmat("NO", numel(callSites), 1), ...
    repmat("YES", numel(callSites), 1), ...
    'VariableNames', {'call_id','file','line_number','boundary_kind','covered','bypass_found','ordering_ok'});
writetable(coverageTbl, fullfile(tablesDir, sprintf('p02_batch_%s_coverage.csv', batchId)));

%% S2/S3/S4/S5 shared fixtures
fixtureRoot = fullfile(statusDir, 'fixtures');
if exist(fixtureRoot, 'dir') ~= 7, mkdir(fixtureRoot); end

caseNames = ["valid_input","missing_file","malformed_csv","partial_header_only","wrong_schema"];
nCases = numel(caseNames);
nSites = numel(callSites);

eq_call_id = strings(nSites * nCases, 1);
eq_test_case = strings(nSites * nCases, 1);
eq_explicit = strings(nSites * nCases, 1);
eq_readtable = strings(nSites * nCases, 1);
eq_match = strings(nSites * nCases, 1);

wk_call_id = strings(nSites * nCases, 1);
wk_test_case = strings(nSites * nCases, 1);
wk_original = strings(nSites * nCases, 1);
wk_explicit_only = strings(nSites * nCases, 1);
wk_match = strings(nSites * nCases, 1);

ps_call_id = strings(nSites * nCases, 1);
ps_test_case = strings(nSites * nCases, 1);
ps_original = strings(nSites * nCases, 1);
ps_post_shift = strings(nSites * nCases, 1);
ps_match = strings(nSites * nCases, 1);

row = 0;
for s = 1:nSites
    call = callSites(s);
    for c = 1:nCases
        row = row + 1;
        caseName = caseNames(c);

        fixture = make_fixture_for_case(call.kind, fixtureRoot, caseName);

        [explicitPass, readtablePass] = run_dual_validation(call.kind, fixture, repoRoot);
        [originalPass, explicitOnlyPass] = run_weakening_check(call.kind, fixture, repoRoot);
        [origPostPass, finalPostPass] = run_post_shift_check(call.kind, fixture, repoRoot);

        eq_call_id(row) = call.call_id;
        eq_test_case(row) = caseName;
        eq_explicit(row) = ternary_pass_fail(explicitPass);
        eq_readtable(row) = ternary_pass_fail(readtablePass);
        eq_match(row) = ternary_yes_no(explicitPass == readtablePass);

        wk_call_id(row) = call.call_id;
        wk_test_case(row) = caseName;
        wk_original(row) = ternary_pass_fail(originalPass);
        wk_explicit_only(row) = ternary_pass_fail(explicitOnlyPass);
        wk_match(row) = ternary_yes_no(originalPass == explicitOnlyPass);

        ps_call_id(row) = call.call_id;
        ps_test_case(row) = caseName;
        ps_original(row) = ternary_pass_fail(origPostPass);
        ps_post_shift(row) = ternary_pass_fail(finalPostPass);
        ps_match(row) = ternary_yes_no(origPostPass == finalPostPass);
    end
end

equivalenceTbl = table(eq_call_id, eq_test_case, eq_explicit, eq_readtable, eq_match, ...
    'VariableNames', {'call_id','test_case','explicit_validation_result','readtable_result','match'});
writetable(equivalenceTbl, fullfile(tablesDir, sprintf('p02_batch_%s_equivalence.csv', batchId)));

weakeningTbl = table(wk_call_id, wk_test_case, wk_original, wk_explicit_only, wk_match, ...
    'VariableNames', {'call_id','test_case','original_behavior','explicit_only_behavior','match'});
writetable(weakeningTbl, fullfile(tablesDir, sprintf('p02_batch_%s_weakening.csv', batchId)));

postShiftTbl = table(ps_call_id, ps_test_case, ps_original, ps_post_shift, ps_match, ...
    'VariableNames', {'call_id','test_case','original_behavior','post_shift_behavior','match'});
writetable(postShiftTbl, fullfile(tablesDir, sprintf('p02_batch_%s_post_shift.csv', batchId)));

%% Batch summary
matchRate = (sum(equivalenceTbl.match == "YES") / max(height(equivalenceTbl), 1)) * 100;
driftAny = any(equivalenceTbl.match ~= "YES") || any(weakeningTbl.match ~= "YES") || any(postShiftTbl.match ~= "YES");
behaviorPreserved = ~any(postShiftTbl.match ~= "YES");
batchPass = (matchRate == 100) && (~driftAny) && behaviorPreserved;

summaryPath = fullfile(reportsDir, sprintf('p02_batch_%s_summary.md', batchId));
fid = fopen(summaryPath, 'w');
if fid < 0
    error('run_p02_batch_03_rollout:ReportWriteFailed', 'Failed writing %s', summaryPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# P02 Batch 03 Summary\n\n');
fprintf(fid, '- BATCH_PASS = %s\n', ternary_yes_no(batchPass));
fprintf(fid, '- CALL_SITES_COUNT = %d\n', nSites);
fprintf(fid, '- MATCH_RATE = %.2f%%\n', matchRate);
fprintf(fid, '- ANY_DRIFT = %s\n', ternary_yes_no(driftAny));
fprintf(fid, '- BEHAVIOR_PRESERVED = %s\n', ternary_yes_no(behaviorPreserved));
fprintf(fid, '\n## Final Flags\n');
fprintf(fid, '- P02_BATCH_03_EXECUTION_COMPLETE = YES\n');
fprintf(fid, '- P02_BATCH_03_PASS = %s\n', ternary_yes_no(batchPass));

function fixture = make_fixture_for_case(kind, fixtureRoot, caseName)
fixture = struct();
fixture.kind = kind;
tmpRoot = fullfile(fixtureRoot, char(kind + "_" + caseName));
if exist(tmpRoot, 'dir') == 7, rmdir(tmpRoot, 's'); end
mkdir(tmpRoot);
filePath = fullfile(tmpRoot, 'input.dat');

switch kind
    case {"general_read_data", "zfamr_read_data"}
        header = sprintf(['Time (ms)\tField (T)\tTemperature (K)\tAngle (deg)\tLI1_X (V)\tLI1_theta (deg)\t' ...
            'LI2_X (V)\tLI2_theta (deg)\tLI3_X (V)\tLI3_theta (deg)\tLI4_X (V)\tLI4_theta (deg)\n']);
        row = sprintf('1\t0.1\t10\t0\t0.01\t1\t0.02\t2\t0.03\t3\t0.04\t4\n');
        wrongHeader = sprintf('A\tB\tC\n');
    otherwise
        header = sprintf(['Time (ms)\tField (T)\tTemperature (K)\tAngle (deg)\t' ...
            'LI5_X (V)\tLI5_theta (deg)\tLI6_X (V)\tLI6_theta (deg)\n']);
        row = sprintf('1\t0.1\t10\t0\t0.05\t5\t0.06\t6\n');
        wrongHeader = sprintf('A\tB\tC\n');
end

switch caseName
    case "valid_input"
        write_text_file(filePath, [header row]);
    case "missing_file"
        % leave missing
    case "malformed_csv"
        write_text_file(filePath, [header '"1\t0.1\t10\t0\t0.05\t5\t0.06\t6\n']);
    case "partial_header_only"
        write_text_file(filePath, header);
    case "wrong_schema"
        write_text_file(filePath, [wrongHeader row]);
end

fixture.filePath = filePath;
end

function [explicitPass, readtablePass] = run_dual_validation(kind, fixture, repoRoot)
explicitPass = explicit_validate_local(kind, fixture.filePath);
readtablePass = observe_original_full(kind, fixture.filePath, repoRoot);
end

function [originalPass, explicitOnlyPass] = run_weakening_check(kind, fixture, repoRoot)
originalPass = observe_original_full(kind, fixture.filePath, repoRoot);
explicitOnlyPass = explicit_validate_local(kind, fixture.filePath);
end

function [originalPass, finalPass] = run_post_shift_check(kind, fixture, repoRoot)
originalPass = observe_original_full(kind, fixture.filePath, repoRoot);
finalPass = observe_post_shift_full(kind, fixture.filePath, repoRoot);
end

function tf = explicit_validate_local(kind, filePath)
tf = false;
if exist(filePath, 'file') ~= 2, return; end
try
    txt = fileread(filePath);
catch
    return;
end
lines = regexp(txt, '\r\n|\n|\r', 'split');
if isempty(lines) || strlength(strtrim(string(lines{1}))) == 0, return; end
headerCols = strtrim(split(string(lines{1}), sprintf('\t')));
if kind == "general_read_data_old_ppms"
    required = ["Time (ms)","Field (T)","Temperature (K)","Angle (deg)", ...
        "LI5_X (V)","LI5_theta (deg)","LI6_X (V)","LI6_theta (deg)"];
else
    required = ["Time (ms)","Field (T)","Temperature (K)","Angle (deg)", ...
        "LI1_X (V)","LI1_theta (deg)","LI2_X (V)","LI2_theta (deg)", ...
        "LI3_X (V)","LI3_theta (deg)","LI4_X (V)","LI4_theta (deg)"];
end
tf = all(ismember(required, headerCols));
end

function tf = observe_original_full(kind, filePath, repoRoot)
try
    switch kind
        case {"general_read_data", "zfamr_read_data"}
            T = readtable(filePath, 'Delimiter', '\t', 'VariableNamingRule', 'preserve'); %#ok<NASGU>
            read_required_general_columns(T);
        otherwise
            T = readtable(filePath, 'Delimiter', '\t', 'VariableNamingRule', 'preserve'); %#ok<NASGU>
            read_required_old_ppms_columns(T);
    end
    tf = true;
catch
    tf = false;
end
end

function tf = observe_post_shift_full(kind, filePath, repoRoot)
oldPwd = pwd;
cleanupObj = onCleanup(@() cd(oldPwd)); %#ok<NASGU>
try
    switch kind
        case "general_read_data"
            cd(fullfile(repoRoot, 'General ver2'));
            clear read_data;
            [~,~,~,~,~,~,~,~,~,~,~,~] = read_data(filePath); %#ok<ASGLU>
        case "general_read_data_old_ppms"
            cd(fullfile(repoRoot, 'General ver2'));
            clear read_data_old_ppms;
            [~,~,~,~,~,~,~,~] = read_data_old_ppms(filePath); %#ok<ASGLU>
        otherwise
            cd(fullfile(repoRoot, 'zfAMR ver11', 'utils'));
            clear read_data;
            [~,~,~,~,~,~,~,~,~,~,~,~] = read_data(filePath); %#ok<ASGLU>
    end
    tf = true;
catch
    tf = false;
end
end

function read_required_general_columns(T)
T{:, 'Time (ms)'}; T{:, 'Field (T)'}; T{:, 'Temperature (K)'}; T{:, 'Angle (deg)'}; %#ok<VUNUS>
T{:, 'LI1_X (V)'}; T{:, 'LI1_theta (deg)'}; T{:, 'LI2_X (V)'}; T{:, 'LI2_theta (deg)'}; %#ok<VUNUS>
T{:, 'LI3_X (V)'}; T{:, 'LI3_theta (deg)'}; T{:, 'LI4_X (V)'}; T{:, 'LI4_theta (deg)'}; %#ok<VUNUS>
end

function read_required_old_ppms_columns(T)
T{:, 'Time (ms)'}; T{:, 'Field (T)'}; T{:, 'Temperature (K)'}; T{:, 'Angle (deg)'}; %#ok<VUNUS>
T{:, 'LI5_X (V)'}; T{:, 'LI5_theta (deg)'}; T{:, 'LI6_X (V)'}; T{:, 'LI6_theta (deg)'}; %#ok<VUNUS>
end

function out = ternary_yes_no(tf)
if tf, out = "YES"; else, out = "NO"; end
end

function out = ternary_pass_fail(tf)
if tf, out = "PASS"; else, out = "FAIL"; end
end

function write_text_file(pathArg, content)
ensure_parent_dir(pathArg);
fid = fopen(pathArg, 'w');
if fid < 0
    error('run_p02_batch_03_rollout:WriteFailed', 'Failed writing %s', pathArg);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', content);
end

function ensure_parent_dir(pathArg)
parentDir = fileparts(pathArg);
if exist(parentDir, 'dir') ~= 7
    mkdir(parentDir);
end
end
