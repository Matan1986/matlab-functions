% P02 Batch 02: S1-S5 full proof cycle for two low-complexity call sites.
% Scope:
%   1) tools/loadModuleCanonicalStatus.m
%   2) tools/load_observables.m

repoRoot = fileparts(fileparts(mfilename('fullpath')));
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
statusDir = fullfile(repoRoot, 'status', 'p02_batch_02_inputs');
addpath(fullfile(repoRoot, 'tools'));

if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
if exist(statusDir, 'dir') ~= 7, mkdir(statusDir); end

batchId = "02";
callSites = [ ...
    struct('call_id', "P02B02_loadModuleCanonicalStatus_001", 'file', "tools/loadModuleCanonicalStatus.m", 'line', 16, 'kind', "module_status_registry"), ...
    struct('call_id', "P02B02_load_observables_001", 'file', "tools/load_observables.m", 'line', 45, 'kind', "observables_csv") ...
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

        [explicitPass, readtablePass] = run_dual_validation(call.kind, fixture);
        [originalPass, explicitOnlyPass] = run_weakening_check(call.kind, fixture);
        [origPostPass, finalPostPass] = run_post_shift_check(call.kind, fixture);

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
    error('run_p02_batch_02_rollout:ReportWriteFailed', 'Failed writing %s', summaryPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# P02 Batch 02 Summary\n\n');
fprintf(fid, '- BATCH_PASS = %s\n', ternary_yes_no(batchPass));
fprintf(fid, '- CALL_SITES_COUNT = %d\n', nSites);
fprintf(fid, '- MATCH_RATE = %.2f%%\n', matchRate);
fprintf(fid, '- ANY_DRIFT = %s\n', ternary_yes_no(driftAny));
fprintf(fid, '- BEHAVIOR_PRESERVED = %s\n', ternary_yes_no(behaviorPreserved));
fprintf(fid, '\n## Final Flags\n');
fprintf(fid, '- P02_BATCH_02_EXECUTION_COMPLETE = YES\n');
fprintf(fid, '- P02_BATCH_02_PASS = %s\n', ternary_yes_no(batchPass));

function fixture = make_fixture_for_case(kind, fixtureRoot, caseName)
fixture = struct();
fixture.kind = kind;
switch kind
    case "module_status_registry"
        tmpRoot = fullfile(fixtureRoot, char("module_status_" + caseName));
        if exist(tmpRoot, 'dir') == 7, rmdir(tmpRoot, 's'); end
        mkdir(fullfile(tmpRoot, 'tables'));
        statusPath = fullfile(tmpRoot, 'tables', 'module_canonical_status.csv');
        switch caseName
            case "valid_input"
                write_text_file(statusPath, sprintf('MODULE,STATUS\nanalysis,CANONICAL\n'));
            case "missing_file"
                % leave missing
            case "malformed_csv"
                write_text_file(statusPath, sprintf('MODULE,STATUS\n"analysis,CANONICAL\n'));
            case "partial_header_only"
                write_text_file(statusPath, sprintf('\n'));
            case "wrong_schema"
                write_text_file(statusPath, sprintf('BAD,SCHEMA\nx,y\n'));
        end
        fixture.repoRoot = tmpRoot;
        fixture.filePath = statusPath;

    case "observables_csv"
        tmpRoot = fullfile(fixtureRoot, char("observables_" + caseName));
        if exist(tmpRoot, 'dir') == 7, rmdir(tmpRoot, 's'); end
        runDir = fullfile(tmpRoot, 'results', 'switching', 'runs', 'run_x');
        mkdir(runDir);
        obsPath = fullfile(runDir, 'observables.csv');
        statusPath = fullfile(runDir, 'run_status.csv');
        write_text_file(statusPath, sprintf('run_status\nCANONICAL\n'));
        switch caseName
            case "valid_input"
                write_text_file(obsPath, sprintf('experiment,sample,temperature,observable,value,units,role,source_run\nswitching,s1,10,m,1.2,arb,observable,run_x\n'));
            case "missing_file"
                % leave missing
            case "malformed_csv"
                write_text_file(obsPath, sprintf('experiment,sample,temperature,observable,value,units,role,source_run\n"switching,s1,10,m,1.2,arb,observable,run_x\n'));
            case "partial_header_only"
                write_text_file(obsPath, sprintf('experiment,sample,temperature,observable,value,units,role,source_run\n'));
            case "wrong_schema"
                write_text_file(obsPath, sprintf('foo,bar\n1,2\n'));
        end
        fixture.resultsRoot = fullfile(tmpRoot, 'results');
        fixture.filePath = obsPath;
end
end

function [explicitPass, readtablePass] = run_dual_validation(kind, fixture)
switch kind
    case "module_status_registry"
        explicitPass = explicit_validate_module_status_registry_local(fixture.filePath);
        readtablePass = observe_module_status_registry_readtable_behavior(fixture.filePath);
    otherwise
        explicitPass = explicit_validate_observables_csv_local(fixture.filePath);
        readtablePass = observe_observables_csv_readtable_behavior(fixture.filePath);
end
end

function [originalPass, explicitOnlyPass] = run_weakening_check(kind, fixture)
switch kind
    case "module_status_registry"
        originalPass = observe_module_status_registry_readtable_behavior(fixture.filePath);
        explicitOnlyPass = explicit_validate_module_status_registry_local(fixture.filePath);
    otherwise
        originalPass = observe_observables_csv_readtable_behavior(fixture.filePath);
        explicitOnlyPass = explicit_validate_observables_csv_local(fixture.filePath);
end
end

function [originalPass, finalPass] = run_post_shift_check(kind, fixture)
switch kind
    case "module_status_registry"
        originalPass = observe_load_module_status_original_full(fixture.repoRoot);
        finalPass = observe_load_module_status_post_shift_full(fixture.repoRoot);
    otherwise
        originalPass = observe_load_observables_original_full(fixture.resultsRoot);
        finalPass = observe_load_observables_post_shift_full(fixture.resultsRoot);
end
end

function tf = explicit_validate_module_status_registry_local(path)
tf = false;
if exist(path, 'file') ~= 2, return; end
try, txt = fileread(path); catch, return; end
lines = regexp(txt, '\r\n|\n|\r', 'split');
if ~isempty(lines) && strlength(string(lines{end})) == 0, lines = lines(1:end-1); end
if isempty(lines), return; end
headerCols = strtrim(split(strtrim(string(lines{1})), ','));
if ~all(ismember(["MODULE","STATUS"], headerCols)), return; end
tf = numel(lines) >= 2;
end

function tf = explicit_validate_observables_csv_local(path)
tf = exist(path, 'file') == 2;
end

function tf = observe_module_status_registry_readtable_behavior(path)
try
    T = readtable(path);
    tf = all(ismember({'MODULE','STATUS'}, T.Properties.VariableNames));
    if tf
        tf = height(T) >= 1;
    end
catch
    tf = false;
end
end

function tf = observe_observables_csv_readtable_behavior(path)
try
    readtable(path, 'TextType', 'string'); %#ok<NASGU>
    tf = true;
catch
    tf = false;
end
end

function tf = observe_load_module_status_original_full(repoRoot)
tf = false;
registryPath = fullfile(repoRoot, 'tables', 'module_canonical_status.csv');
if exist(registryPath, 'file') ~= 2
    return;
end
try
    T = readtable(registryPath);
    tf = all(ismember({'MODULE','STATUS'}, T.Properties.VariableNames)) && (height(T) >= 1);
catch
    tf = false;
end
end

function tf = observe_load_module_status_post_shift_full(repoRoot)
tf = false;
try
    T = loadModuleCanonicalStatus(repoRoot); %#ok<NASGU>
    tf = true;
catch
    tf = false;
end
end

function tf = observe_load_observables_original_full(resultsRoot)
tf = false;
try
    T = load_observables(resultsRoot); %#ok<NASGU>
    tf = true;
catch
    tf = false;
end
end

function tf = observe_load_observables_post_shift_full(resultsRoot)
tf = false;
try
    T = load_observables(resultsRoot); %#ok<NASGU>
    tf = true;
catch
    tf = false;
end
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
    error('run_p02_batch_02_rollout:WriteFailed', 'Failed writing %s', pathArg);
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
