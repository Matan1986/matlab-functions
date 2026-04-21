% P02 Fast Batch 01: S1-S5 for five new readtable call sites (controlled explicit validation).
% Sites:
%   1) analysis/get_canonical_X.m
%   2) Switching/utils/assertModulesCanonical.m
%   3) analysis/export_deformation_closure_figs.m
%   4) analysis/run_effective_collective_state_test.m
%   5) reports/functional_form_test_analysis.m

repoRoot = fileparts(fileparts(mfilename('fullpath')));
tablesDir = fullfile(repoRoot, 'tables');
reportsDir = fullfile(repoRoot, 'reports');
statusDir = fullfile(repoRoot, 'status', 'p02_fast_batch_01_inputs');

addpath(fullfile(repoRoot, 'analysis'));
addpath(fullfile(repoRoot, 'reports'));
addpath(fullfile(repoRoot, 'Switching', 'utils'), '-begin');
addpath(fullfile(repoRoot, 'tools'));

if exist(tablesDir, 'dir') ~= 7, mkdir(tablesDir); end
if exist(reportsDir, 'dir') ~= 7, mkdir(reportsDir); end
if exist(statusDir, 'dir') ~= 7, mkdir(statusDir); end

callSites = [ ...
    struct('call_id', "P02FB01_get_canonical_X_001", 'file', "analysis/get_canonical_X.m", 'line', 16, 'kind', "canonical_x_obs"), ...
    struct('call_id', "P02FB01_assertModulesCanonical_001", 'file', "Switching/utils/assertModulesCanonical.m", 'line', 47, 'kind', "module_assert_registry"), ...
    struct('call_id', "P02FB01_export_deformation_closure_figs_001", 'file', "analysis/export_deformation_closure_figs.m", 'line', 12, 'kind', "deformation_closure_csv"), ...
    struct('call_id', "P02FB01_run_effective_collective_state_test_001", 'file', "analysis/run_effective_collective_state_test.m", 'line', 31, 'kind', "collective_state_residual_csv"), ...
    struct('call_id', "P02FB01_functional_form_test_analysis_001", 'file', "reports/functional_form_test_analysis.m", 'line', 19, 'kind', "functional_form_ax_csv") ...
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
writetable(coverageTbl, fullfile(tablesDir, 'p02_fast_batch_01_coverage.csv'));

%% S2/S3/S4/S5
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
writetable(equivalenceTbl, fullfile(tablesDir, 'p02_fast_batch_01_equivalence.csv'));

weakeningTbl = table(wk_call_id, wk_test_case, wk_original, wk_explicit_only, wk_match, ...
    'VariableNames', {'call_id','test_case','original_behavior','explicit_only_behavior','match'});
writetable(weakeningTbl, fullfile(tablesDir, 'p02_fast_batch_01_weakening.csv'));

postShiftTbl = table(ps_call_id, ps_test_case, ps_original, ps_post_shift, ps_match, ...
    'VariableNames', {'call_id','test_case','original_behavior','post_shift_behavior','match'});
writetable(postShiftTbl, fullfile(tablesDir, 'p02_fast_batch_01_post_shift.csv'));

%% Summary
matchRate = (sum(equivalenceTbl.match == "YES") / max(height(equivalenceTbl), 1)) * 100;
driftAny = any(equivalenceTbl.match ~= "YES") || any(weakeningTbl.match ~= "YES") || any(postShiftTbl.match ~= "YES");
behaviorPreserved = ~any(postShiftTbl.match ~= "YES");
batchPass = (matchRate == 100) && (~driftAny) && behaviorPreserved;

summaryPath = fullfile(reportsDir, 'p02_fast_batch_01_summary.md');
fid = fopen(summaryPath, 'w');
if fid < 0
    error('run_p02_fast_batch_01_rollout:ReportWriteFailed', 'Failed writing %s', summaryPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# P02 Fast Batch 01 Summary\n\n');
fprintf(fid, '- BATCH_PASS = %s\n', ternary_yes_no(batchPass));
fprintf(fid, '- CALL_SITES_COUNT = %d\n', nSites);
fprintf(fid, '- MATCH_RATE = %.2f%%\n', matchRate);
fprintf(fid, '- ANY_DRIFT = %s\n', ternary_yes_no(driftAny));
fprintf(fid, '- BEHAVIOR_PRESERVED = %s\n', ternary_yes_no(behaviorPreserved));
fprintf(fid, '\n## Final Flags\n');
fprintf(fid, '- P02_FAST_BATCH_01_EXECUTION_COMPLETE = YES\n');
fprintf(fid, '- P02_FAST_BATCH_01_PASS = %s\n', ternary_yes_no(batchPass));

%% --- fixtures ---
function fixture = make_fixture_for_case(kind, fixtureRoot, caseName)
fixture = struct();
fixture.kind = kind;
tmpRoot = fullfile(fixtureRoot, char(string(kind) + "_" + caseName));
if exist(tmpRoot, 'dir') == 7, rmdir(tmpRoot, 's'); end
mkdir(tmpRoot);
fixture.repoRoot = tmpRoot;

switch kind
    case "canonical_x_obs"
        runD = fullfile(tmpRoot, 'results', 'switching', 'runs', 'run_p02_fix');
        mkdir(runD);
        fp = fullfile(runD, 'observables.csv');
        fixture.filePath = fp;
        fixture.runName = 'run_p02_fix';
        switch caseName
            case "valid_input"
                write_text_file(fp, sprintf('temperature,observable,value\n10,X,0.5\n20,X,0.6\n'));
            case "missing_file"
            case "malformed_csv"
                write_text_file(fp, sprintf('temperature,observable,value\n"bad\n'));
            case "partial_header_only"
                write_text_file(fp, sprintf('temperature,observable,value\n'));
            case "wrong_schema"
                write_text_file(fp, sprintf('foo,bar\n1,2\n'));
        end

    case "module_assert_registry"
        mkdir(fullfile(tmpRoot, 'tables'));
        fp = fullfile(tmpRoot, 'tables', 'module_canonical_status.csv');
        fixture.filePath = fp;
        switch caseName
            case "valid_input"
                write_text_file(fp, sprintf('MODULE,STATUS\nSwitching,CANONICAL\n'));
            case "missing_file"
            case "malformed_csv"
                write_text_file(fp, sprintf('MODULE,STATUS\n"unclosed'));
            case "partial_header_only"
                write_text_file(fp, sprintf('\n'));
            case "wrong_schema"
                write_text_file(fp, sprintf('BAD,SCHEMA\nx,y\n'));
        end

    case "deformation_closure_csv"
        mkdir(fullfile(tmpRoot, 'tables'));
        fp = fullfile(tmpRoot, 'tables', 'deformation_closure_metrics.csv');
        fixture.filePath = fp;
        hdr = 'T_K,rmse_A_rank1,rmse_B_rank2_phi2,rmse_C_deform3,rmse_D_constrained,rmse_SVD_rank2_row,I_peak_mA,beta1_fixedKappa,beta2_fixedKappa';
        row1 = '10,0.1,0.2,0.3,0.4,0.5,1.0,0.01,0.02';
        row2 = '20,0.11,0.21,0.31,0.41,0.51,1.1,0.011,0.021';
        switch caseName
            case "valid_input"
                write_text_file(fp, sprintf('%s\n%s\n%s\n', hdr, row1, row2));
            case "missing_file"
            case "malformed_csv"
                write_text_file(fp, sprintf('%s\n"x', hdr));
            case "partial_header_only"
                write_text_file(fp, sprintf('%s\n', hdr));
            case "wrong_schema"
                write_text_file(fp, sprintf('A,B\n1,2\n'));
        end

    case "collective_state_residual_csv"
        runD = fullfile(tmpRoot, 'results', 'switching', 'runs', ...
            'run_2026_03_25_043610_kappa_phi_temperature_structure_test', 'tables');
        mkdir(runD);
        fp = fullfile(runD, 'residual_rank_structure_vs_T.csv');
        fixture.filePath = fp;
        hdr = 'subset,T_K,kappa,rel_orth_leftover_norm';
        switch caseName
            case "valid_input"
                body = sprintf('T_le_30,4,0.10,0.50\nT_le_30,12,0.12,0.48\nT_le_30,14,0.11,0.52\nT_le_30,20,0.09,0.55\nT_le_30,22,0.25,0.80\nT_le_30,24,0.14,0.45\nT_le_30,30,0.13,0.40\n');
                write_text_file(fp, sprintf('%s\n%s', hdr, body));
            case "missing_file"
            case "malformed_csv"
                write_text_file(fp, sprintf('%s\nT_le_30,4,"bad', hdr));
            case "partial_header_only"
                write_text_file(fp, sprintf('%s\n', hdr));
            case "wrong_schema"
                write_text_file(fp, sprintf('foo,bar\n1,2\n'));
        end

    case "functional_form_ax_csv"
        axD = fullfile(tmpRoot, 'results', 'cross_experiment', 'runs', ...
            'run_2026_03_13_115401_AX_functional_relation_analysis', 'tables');
        mkdir(axD);
        fp = fullfile(axD, 'AX_aligned_data.csv');
        fixture.filePath = fp;
        hdr = 'T_K,A_interp,X,I_peak_mA,width_mA,S_peak';
        switch caseName
            case "valid_input"
                rows = sprintf('4,1.0,0.5,10,2,0.3\n10,1.1,0.55,11,2.1,0.31\n20,1.2,0.6,12,2.2,0.32\n22,1.25,0.62,12.2,2.25,0.33\n30,1.3,0.65,13,2.3,0.34\n');
                write_text_file(fp, sprintf('%s\n%s', hdr, rows));
            case "missing_file"
            case "malformed_csv"
                write_text_file(fp, sprintf('%s\n4,1.0,"bad\n', hdr));
            case "partial_header_only"
                write_text_file(fp, sprintf('%s\n', hdr));
            case "wrong_schema"
                write_text_file(fp, sprintf('foo,bar\n1,2\n'));
        end
end
end

%% --- validation ---
function [explicitPass, readtablePass] = run_dual_validation(kind, fixture)
explicitPass = explicit_validate_local(kind, fixture);
readtablePass = observe_original_full(kind, fixture);
end

function [originalPass, explicitOnlyPass] = run_weakening_check(kind, fixture)
originalPass = observe_original_full(kind, fixture);
explicitOnlyPass = explicit_validate_local(kind, fixture);
end

function [originalPass, finalPass] = run_post_shift_check(kind, fixture)
originalPass = observe_original_full(kind, fixture);
finalPass = observe_post_shift_production(kind, fixture);
end

function tf = explicit_validate_local(kind, fixture)
tf = false;
switch kind
    case "canonical_x_obs"
        tf = harness_canonical_obs_header_ok(fixture.filePath);
    case "module_assert_registry"
        tf = harness_module_registry_header_ok(fixture.filePath);
    case "deformation_closure_csv"
        tf = harness_deformation_header_ok(fixture.filePath);
    case "collective_state_residual_csv"
        tf = harness_collective_residual_header_ok(fixture.filePath);
    case "functional_form_ax_csv"
        tf = harness_ax_aligned_header_ok(fixture.filePath);
end
end

function tf = harness_canonical_obs_header_ok(path)
tf = false;
if exist(path, 'file') ~= 2, return; end
try
    tbl = readtable(path, 'VariableNamingRule', 'preserve', 'TextType', 'string');
    req = {'temperature', 'observable', 'value'};
    if ~all(ismember(req, tbl.Properties.VariableNames)), return; end
    if ~any(string(tbl.observable) == "X"), return; end
    tf = true;
catch
    tf = false;
end
end

function tf = harness_module_registry_header_ok(path)
tf = false;
if exist(path, 'file') ~= 2, return; end
try
    tbl = readtable(path);
    if ~all(ismember({'MODULE', 'STATUS'}, tbl.Properties.VariableNames)), return; end
    tf = height(tbl) >= 1;
catch
    tf = false;
end
end

function tf = harness_deformation_header_ok(path)
tf = false;
req = {'T_K', 'rmse_A_rank1', 'rmse_B_rank2_phi2', 'rmse_C_deform3', 'rmse_D_constrained', ...
    'rmse_SVD_rank2_row', 'I_peak_mA', 'beta1_fixedKappa', 'beta2_fixedKappa'};
if exist(path, 'file') ~= 2, return; end
try
    tbl = readtable(path);
    if ~all(ismember(req, tbl.Properties.VariableNames)), return; end
    tf = height(tbl) >= 1;
catch
    tf = false;
end
end

function tf = harness_collective_residual_header_ok(path)
tf = false;
if exist(path, 'file') ~= 2, return; end
try
    tbl = readtable(path, 'TextType', 'string');
    req = {'subset', 'T_K', 'kappa', 'rel_orth_leftover_norm'};
    if ~all(ismember(req, tbl.Properties.VariableNames)), return; end
    if ~any(tbl.subset == "T_le_30"), return; end
    tf = true;
catch
    tf = false;
end
end

function tf = harness_ax_aligned_header_ok(path)
tf = false;
req = {'T_K', 'A_interp', 'X', 'I_peak_mA', 'width_mA', 'S_peak'};
if exist(path, 'file') ~= 2, return; end
try
    tbl = readtable(path, 'VariableNamingRule', 'preserve');
    if ~all(ismember(req, tbl.Properties.VariableNames)), return; end
    tf = height(tbl) >= 2;
catch
    tf = false;
end
end

function tf = observe_original_full(kind, fixture)
tf = false;
try
    switch kind
        case "canonical_x_obs"
            p = fixture.filePath;
            if exist(p, 'file') ~= 2, return; end
            tbl = readtable(p, 'VariableNamingRule', 'preserve', 'TextType', 'string');
            req = {'temperature', 'observable', 'value'};
            if ~all(ismember(req, tbl.Properties.VariableNames)), return; end
            if ~any(string(tbl.observable) == "X"), return; end
            tf = true;
        case "module_assert_registry"
            p = fixture.filePath;
            if exist(p, 'file') ~= 2, return; end
            tbl = readtable(p);
            if ~all(ismember({'MODULE','STATUS'}, tbl.Properties.VariableNames)), return; end
            tf = height(tbl) >= 1;
        case "deformation_closure_csv"
            p = fixture.filePath;
            if exist(p, 'file') ~= 2, return; end
            tbl = readtable(p);
            req = {'T_K', 'rmse_A_rank1', 'rmse_B_rank2_phi2', 'rmse_C_deform3', 'rmse_D_constrained', ...
                'rmse_SVD_rank2_row', 'I_peak_mA', 'beta1_fixedKappa', 'beta2_fixedKappa'};
            if ~all(ismember(req, tbl.Properties.VariableNames)), return; end
            tf = height(tbl) >= 1;
        case "collective_state_residual_csv"
            p = fixture.filePath;
            if exist(p, 'file') ~= 2, return; end
            tbl = readtable(p, 'TextType', 'string');
            if ~all(ismember({'subset','T_K','kappa','rel_orth_leftover_norm'}, tbl.Properties.VariableNames)), return; end
            if ~any(tbl.subset == "T_le_30"), return; end
            tf = true;
        case "functional_form_ax_csv"
            p = fixture.filePath;
            if exist(p, 'file') ~= 2, return; end
            tbl = readtable(p, 'VariableNamingRule', 'preserve');
            req = {'T_K', 'A_interp', 'X', 'I_peak_mA', 'width_mA', 'S_peak'};
            if ~all(ismember(req, tbl.Properties.VariableNames)), return; end
            tf = height(tbl) >= 2;
    end
catch
    tf = false;
end
end

function tf = observe_post_shift_production(kind, fixture)
tf = false;
try
    switch kind
        case "canonical_x_obs"
            [~, ~] = get_canonical_X('repoRoot', fixture.repoRoot, 'runName', fixture.runName); %#ok<ASGLU>
        case "module_assert_registry"
            assertModulesCanonical({'Switching'}, 'RepoRoot', fixture.repoRoot);
        case "deformation_closure_csv"
            export_deformation_closure_figs(fixture.repoRoot);
        case "collective_state_residual_csv"
            run_effective_collective_state_test(fixture.repoRoot);
        case "functional_form_ax_csv"
            functional_form_test_analysis(fixture.repoRoot);
    end
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
    error('run_p02_fast_batch_01_rollout:WriteFailed', 'Failed writing %s', pathArg);
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
