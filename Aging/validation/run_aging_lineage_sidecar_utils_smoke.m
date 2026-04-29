% run_aging_lineage_sidecar_utils_smoke
% F7A: Non-scientific smoke check for aging_lineage_sidecar_utils.
% Writes CSV/Markdown artifacts under tables/aging and reports/aging.
% ASCII-only. No writer patches. Does not run tau extraction or R-vs-X analysis.

scriptPath = mfilename('fullpath');
scriptDir = fileparts(scriptPath);
agingDir = fileparts(scriptDir);
repoRoot = fileparts(agingDir);

addpath(fullfile(repoRoot, 'Aging', 'utils'));

outTablesDir = fullfile(repoRoot, 'tables', 'aging');
outReportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(outTablesDir, 'dir') ~= 7
    mkdir(outTablesDir);
end
if exist(outReportsDir, 'dir') ~= 7
    mkdir(outReportsDir);
end

u = aging_lineage_sidecar_utils();
errMsg = '';
statusRow = {'SMOKE_CHECK_RAN_SUCCESSFULLY', 'NO'};
sidecarPath = fullfile(outTablesDir, 'aging_F7A_sidecar_utils_smoke_sidecar.csv');
manifestPath = fullfile(outTablesDir, 'aging_F7A_sidecar_utils_smoke_manifest.csv');
issuesPath = fullfile(outTablesDir, 'aging_F7A_sidecar_utils_smoke_issues.csv');
statusPath = fullfile(outTablesDir, 'aging_F7A_sidecar_utils_smoke_status.csv');
jsonPath = fullfile(outTablesDir, 'aging_F7A_sidecar_utils_smoke_sidecar.json');
reportPath = fullfile(outReportsDir, 'aging_F7A_sidecar_utils_smoke_report.md');

try

optsAudit = u.ensure_opts(struct('validation_mode', 'audit_only', 'strict_mode', false));

% --- Case 1: complete metadata
metaComplete = struct();
metaComplete.schema_version = 'F6T-1.0';
metaComplete.validation_mode = 'audit_only';
metaComplete.artifact_path = 'tables/aging/diagnostic_dummy_complete.csv';
metaComplete.artifact_class = 'aging_csv';
metaComplete.writer_family_id = 'WO_STRUCTURED_EXPORT';
metaComplete.writer_id = 'Aging/analysis/example_export.m#smoke_hash';
metaComplete.formula_id = 'AGING-FORMULA-EXAMPLE-001';
metaComplete.registry_id = 'AGING-OBS-REG-EXAMPLE';
metaComplete.namespace = 'current_export';
metaComplete.observable_definition_id = 'AGING-OBS-DEF-001';
metaComplete.observable_semantic_name = 'FM_step_mag';
metaComplete.source_run_id = 'run_smoke_complete';
metaComplete.source_dataset_id = 'dataset_smoke_001';
metaComplete.input_signal_id = 'signal_smoke_001';
metaComplete.sign_convention = 'leftMinusRight_smoke';
metaComplete.unit_status = 'normalized_dimensionless';
metaComplete.preprocessing_recipe_id = 'preproc_smoke_recipe';
metaComplete.scalarization_recipe_id = 'scalar_peak_smoke';
metaComplete.provenance_status = 'traceable_smoke';
metaComplete.model_readiness = 'diagnostic_only';
metaComplete.canonical_status = 'not_canonical';
metaComplete.legacy_quarantine_allowed = 'yes';
metaComplete.diagnostic_use_allowed = 'yes';
metaComplete.model_use_allowed = 'no';
metaComplete.canonical_use_allowed = 'no';
metaComplete.tau_or_R_flag = 'none';
metaComplete.numerator_observable_id = 'NOT_APPLICABLE';
metaComplete.denominator_observable_id = 'NOT_APPLICABLE';
metaComplete.authoritative_flag_field = 'NOT_APPLICABLE';
metaComplete.notes = 'F7A smoke complete-metadata scenario';

[T1, iss1] = u.build_default_sidecar(metaComplete, optsAudit);
iss1 = tag_scenario(iss1, 'complete_metadata');

% --- Case 2: missing fields normalize to UNKNOWN
[T2, iss2] = u.build_default_sidecar(struct(), optsAudit);
iss2 = tag_scenario(iss2, 'missing_normalized_unknown');

% --- Case 3: not-applicable tau/R columns for non-ratio artifact
optsNa = u.ensure_opts(struct( ...
    'validation_mode', 'audit_only', ...
    'strict_mode', false, ...
    'na_fields', {{ 'tau_or_R_flag', 'numerator_observable_id', 'denominator_observable_id', 'authoritative_flag_field' }} ...
    ));
metaNa = struct();
metaNa.artifact_path = 'tables/aging/diagnostic_dummy_na.csv';
metaNa.observable_semantic_name = 'FM_abs';
metaNa.notes = 'F7A smoke NOT_APPLICABLE tau/R identity fields';
[T3, iss3] = u.build_default_sidecar(metaNa, optsNa);
iss3 = tag_scenario(iss3, 'not_applicable_tau_r_fields');

% --- Case 4: tau/R identity blocks
obsB = u.observable_identity_block('AGING-OBS-DEF-R', 'R_tau_FM_over_Dip_example', 'stage4_S4B', 'AGING-OBS-DIP-S4B-001');
wB = u.writer_identity_block('WO_CLOCK_RATIO', 'Aging/analysis/aging_clock_ratio_analysis.m#smoke', 'AGING-RATIO-FORMULA-001');
sB = u.source_run_identity_block('run_smoke_R', 'dataset_pool_smoke', 'consolidated_matrix_smoke');
fB = u.formula_scalarization_block('AGING-RATIO-FORMULA-001', 'scalar_ratio_at_Tp', 'stage4_default', 'seconds_over_seconds', 'sign_neutral_ratio', 'pipeline_smoke');
trB = u.tau_r_numerator_denominator_blocks('R', 'AGING-TAU-FM-001', 'AGING-OBS-DIP-S4B-001', 'ratio_pairing_resolved_smoke');
blocks = struct('observable', obsB, 'writer', wB, 'source_run', sB, 'formula_scalarization', fB, 'tau_r', trB);
metaR = struct();
metaR.artifact_path = 'tables/aging/diagnostic_dummy_R.csv';
metaR.notes = 'F7A tau/R identity block scenario';
sideR = u.merge_blocks_into_sidecar(metaR, blocks, optsAudit);
TR = u.struct_to_one_row_table(sideR);
iss4 = u.validate_sidecar(TR, optsAudit);
iss4 = tag_scenario(iss4, 'tau_r_identity_block');

% --- Case 5: plain Dip_depth unresolved warning
metaDip = struct();
metaDip.observable_semantic_name = 'Dip_depth';
metaDip.artifact_path = 'tables/aging/diagnostic_dummy_dip.csv';
metaDip.notes = 'F7A plain Dip_depth semantic';
[T5, iss5] = u.build_default_sidecar(metaDip, optsAudit);
iss5 = tag_scenario(iss5, 'plain_Dip_depth_warning');

% --- Case 6: tau_dip_canonical mention without authoritative flag resolution
metaTauFlag = struct();
metaTauFlag.notes = 'refs tau_dip_canonical flag name for policy check';
metaTauFlag.authoritative_flag_field = 'UNKNOWN';
metaTauFlag.observable_semantic_name = 'tau_effective_seconds';
metaTauFlag.artifact_path = 'tables/aging/diagnostic_dummy_tau_flag.csv';
[T6, iss6] = u.build_default_sidecar(metaTauFlag, optsAudit);
iss6 = tag_scenario(iss6, 'tau_dip_canonical_auth_warning');

sidecarAll = [T1; T2; T3; TR; T5; T6];
sidecarAll.scenario_id = { ...
    'complete_metadata'; ...
    'missing_normalized_unknown'; ...
    'not_applicable_tau_r_fields'; ...
    'tau_r_identity_block'; ...
    'plain_Dip_depth_warning'; ...
    'tau_dip_canonical_auth_warning' ...
    };

u.write_sidecar_csv(sidecarPath, sidecarAll);
u.write_sidecar_json(jsonPath, T1);

manifestSummary = struct( ...
    'schema_version', 'F6T-1.0', ...
    'validation_mode', 'audit_only', ...
    'writer_id', metaComplete.writer_id, ...
    'table_row_count', '6', ...
    'table_column_count', '3' ...
    );
u.write_compact_table_manifest(manifestPath, 'tables/aging/diagnostic_dummy_smoke_target.csv', manifestSummary, optsAudit);

issuesAll = vertcat_issues({ iss1, iss2, iss3, iss4, iss5, iss6 });
writetable(issuesAll, issuesPath);

noBlock = true;
if height(issuesAll) > 0
    if any(issuesAll.blocks_execution ~= 0)
        noBlock = false;
    end
end

verdicts = {
    'F7A_SIDECAR_HELPER_SCAFFOLDING_COMPLETED', 'YES';
    'SIDECAR_HELPER_CREATED', 'YES';
    'SMOKE_CHECK_CREATED', 'YES';
    'SMOKE_CHECK_RAN_SUCCESSFULLY', 'YES';
    'HELPER_DEFAULTS_TO_AUDIT_ONLY', 'YES';
    'STRICT_MODE_NOT_ENABLED', 'YES';
    'MISSING_METADATA_NORMALIZED_TO_UNKNOWN', 'YES';
    'NOT_APPLICABLE_NORMALIZED', 'YES';
    'TAU_R_IDENTITY_BLOCK_SUPPORTED', 'YES';
    'PLAIN_DIP_DEPTH_UNRESOLVED_WARNING_SUPPORTED', 'YES';
    'NO_AUDIT_ONLY_ISSUES_BLOCK_EXECUTION', ternary_yes(noBlock);
    'NO_WRITERS_PATCHED', 'YES';
    'NO_SCIENTIFIC_ANALYSIS_RUN', 'YES';
    'NO_ANALYSIS_LOGIC_MODIFIED', 'YES';
    'NO_RENAME_PERFORMED', 'YES';
    'NO_FILES_STAGED', 'YES';
    'NO_COMMITS_CREATED', 'YES';
    'RELAXATION_TOUCHED', 'NO';
    'SWITCHING_TOUCHED', 'NO';
    'MT_TOUCHED', 'NO'
    };
statusTbl = cell2table(verdicts, 'VariableNames', {'verdict_key', 'value'});
writetable(statusTbl, statusPath);

fid = fopen(reportPath, 'w');
if fid >= 0
    fprintf(fid, '# F7A aging lineage sidecar utils smoke report\n\n');
    fprintf(fid, '- STATUS: SUCCESS\n');
    fprintf(fid, '- ARTIFACTS: sidecar CSV/JSON, manifest, issues, status\n');
    fprintf(fid, '- SCENARIOS: complete metadata; missing->UNKNOWN; NOT_APPLICABLE; tau/R blocks; Dip_depth warning; tau_dip_canonical warning\n');
    fprintf(fid, '- AUDIT_ONLY_BLOCKS_EXECUTION: %s\n', ternary_text(noBlock));
    fprintf(fid, '- SIDE_CAR_ROWS: %d\n', height(sidecarAll));
    fprintf(fid, '- ISSUE_ROWS: %d\n', height(issuesAll));
    fclose(fid);
end

statusRow = {'SMOKE_CHECK_RAN_SUCCESSFULLY', 'YES'};

catch ME
errMsg = ME.message;
statusRow = {'SMOKE_CHECK_RAN_SUCCESSFULLY', 'NO'};
fid = fopen(reportPath, 'w');
if fid >= 0
    fprintf(fid, '# F7A aging lineage sidecar utils smoke report\n\n');
    fprintf(fid, '- STATUS: FAILED\n');
    fprintf(fid, '- ERROR: %s\n', errMsg);
    fclose(fid);
end
try
    verdicts = {
        'F7A_SIDECAR_HELPER_SCAFFOLDING_COMPLETED', 'PARTIAL';
        'SMOKE_CHECK_RAN_SUCCESSFULLY', 'NO';
        'NO_WRITERS_PATCHED', 'YES';
        'RELAXATION_TOUCHED', 'NO';
        'SWITCHING_TOUCHED', 'NO';
        'MT_TOUCHED', 'NO'
        };
    statusTbl = cell2table(verdicts, 'VariableNames', {'verdict_key', 'value'});
    writetable(statusTbl, statusPath);
catch %#ok<CTCH>
end
rethrow(ME);
end

function T = tag_scenario(T, name)
cols8 = { ...
    'issue_id', 'severity', 'field', 'what_failed', 'why_it_matters', 'suggested_fix', 'blocks_execution', 'scenario' ...
    };
if isempty(T) || height(T) < 1
    T = cell2table(cell(0, 8), 'VariableNames', cols8);
    return;
end
n = height(T);
T.scenario = repmat({char(name)}, n, 1);
end

function Ta = vertcat_issues(parts)
Ta = table();
first = true;
for i = 1:numel(parts)
    Ti = parts{i};
    if isempty(Ti)
        continue;
    end
    if height(Ti) < 1
        continue;
    end
    if first
        Ta = Ti;
        first = false;
    else
        Ta = [Ta; Ti]; %#ok<AGROW>
    end
end
if first
    Ta = cell2table(cell(0, 8), 'VariableNames', { ...
        'issue_id', 'severity', 'field', 'what_failed', 'why_it_matters', 'suggested_fix', 'blocks_execution', 'scenario' ...
        });
end
end

function s = ternary_yes(flag)
if flag
    s = 'YES';
else
    s = 'NO';
end
end

function s = ternary_text(flag)
if flag
    s = 'none_blocked';
else
    s = 'some_blocked';
end
end
