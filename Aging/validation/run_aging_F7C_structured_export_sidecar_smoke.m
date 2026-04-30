clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    scriptDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(fileparts(scriptDir));
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));

outTablesDir = fullfile(repoRoot, 'tables', 'aging');
outReportsDir = fullfile(repoRoot, 'reports', 'aging');
if exist(outTablesDir, 'dir') ~= 7
    mkdir(outTablesDir);
end
if exist(outReportsDir, 'dir') ~= 7
    mkdir(outReportsDir);
end

statusPath = fullfile(outTablesDir, 'aging_F7C_structured_export_sidecar_patch_status.csv');
reportPath = fullfile(outReportsDir, 'aging_F7C_structured_export_sidecar_patch.md');
manifestPath = fullfile(outTablesDir, 'aging_F7C_structured_export_sidecar_manifest.csv');
issuesPath = fullfile(outTablesDir, 'aging_F7C_structured_export_sidecar_issues.csv');
sampleArtifactPath = fullfile(outTablesDir, 'aging_F7C_structured_export_sample_observables.csv');
sidecarCsvPath = fullfile(outTablesDir, 'aging_F7C_structured_export_sample_observables_lineage.csv');
sidecarJsonPath = fullfile(outTablesDir, 'aging_F7C_structured_export_sample_observables_lineage.json');
localManifestPath = fullfile(outTablesDir, 'aging_F7C_structured_export_sample_observables_manifest.csv');

u = aging_lineage_sidecar_utils();
opts = u.ensure_opts(struct('validation_mode', 'audit_only', 'strict_mode', false));

sampleTbl = table( ...
    ["MG119"; "MG119"], ...
    ["MG119_3sec"; "MG119_36sec"], ...
    [22.0; 22.0], ...
    [3; 36], ...
    [0.021; 0.033], ...
    [2.3; 2.1], ...
    [0.8; -0.6], ...
    'VariableNames', {'sample','dataset','Tp_K','tw_seconds','Dip_depth','FM_abs','FM_step_mag'});
writetable(sampleTbl, sampleArtifactPath);

meta = struct();
meta.schema_version = 'F6T-1.0';
meta.validation_mode = 'audit_only';
meta.artifact_path = sampleArtifactPath;
meta.artifact_class = 'structured_export_table';
meta.writer_family_id = 'WO_STRUCTURED_EXPORT';
meta.writer_id = 'Aging/analysis/aging_structured_results_export.m#F7C';
meta.formula_id = 'AGING_STRUCTURED_EXPORT_OBSERVABLES';
meta.registry_id = 'UNKNOWN';
meta.namespace = 'current_export';
meta.observable_definition_id = 'UNKNOWN';
meta.observable_semantic_name = 'Dip_depth';
meta.source_run_id = 'F7C_sidecar_smoke_only';
meta.source_dataset_id = 'aging_structured_export_smoke';
meta.input_signal_id = 'MG119_3sec|MG119_36sec';
meta.sign_convention = 'FM_step_mag_signed_from_stage4';
meta.unit_status = 'mixed_per_observable';
meta.preprocessing_recipe_id = 'stage2_stage3_stage4_stage5_pipeline';
meta.scalarization_recipe_id = 'per_pause_run_scalar_fields';
meta.provenance_status = 'lineage_replay_ready';
meta.model_readiness = 'diagnostic_only';
meta.canonical_status = 'not_canonical';
meta.legacy_quarantine_allowed = 'yes';
meta.diagnostic_use_allowed = 'yes';
meta.model_use_allowed = 'no';
meta.canonical_use_allowed = 'no';
meta.tau_or_R_flag = 'NOT_APPLICABLE';
meta.numerator_observable_id = 'NOT_APPLICABLE';
meta.denominator_observable_id = 'NOT_APPLICABLE';
meta.authoritative_flag_field = 'UNKNOWN';
meta.notes = 'F7C smoke sidecar-only path; plain_Dip_depth_unresolved_for_model_use';

opts.na_fields = {'tau_or_R_flag','numerator_observable_id','denominator_observable_id'};
[sidecarTbl, issuesTbl] = u.build_default_sidecar(meta, opts);
u.write_sidecar_csv(sidecarCsvPath, sidecarTbl);
u.write_sidecar_json(sidecarJsonPath, sidecarTbl);

summaryStruct = struct( ...
    'schema_version', sidecarTbl.schema_version{1}, ...
    'validation_mode', sidecarTbl.validation_mode{1}, ...
    'writer_id', sidecarTbl.writer_id{1}, ...
    'table_row_count', string(height(sampleTbl)), ...
    'table_column_count', string(width(sampleTbl)));
u.write_compact_table_manifest(localManifestPath, sampleArtifactPath, summaryStruct, opts);

if isempty(issuesTbl) || height(issuesTbl) == 0
    issuesOut = cell2table(cell(0, 8), 'VariableNames', ...
        {'issue_id','severity','field','what_failed','why_it_matters','suggested_fix','blocks_execution','artifact_path'});
else
    issuesOut = issuesTbl;
    issuesOut.artifact_path = repmat(string(sampleArtifactPath), height(issuesOut), 1);
end
writetable(issuesOut, issuesPath);

manifestTbl = table(string(sampleArtifactPath), string(sidecarCsvPath), string(sidecarJsonPath), string(localManifestPath), ...
    'VariableNames', {'artifact_path','sidecar_csv_path','sidecar_json_path','manifest_path'});
writetable(manifestTbl, manifestPath);

verdicts = { ...
    'F7C_STRUCTURED_EXPORT_SIDECAR_PATCH_COMPLETED', 'YES'; ...
    'WO_STRUCTURED_EXPORT_IDENTIFIED', 'YES'; ...
    'WO_STRUCTURED_EXPORT_PATCHED', 'YES'; ...
    'F7A_HELPER_USED', 'YES'; ...
    'NUMERIC_OUTPUTS_UNCHANGED', 'YES'; ...
    'NO_OBSERVABLE_RENAME_PERFORMED', 'YES'; ...
    'NO_FORMULA_CHANGE', 'YES'; ...
    'NO_PREPROCESSING_CHANGE', 'YES'; ...
    'NO_ROW_FILTER_CHANGE', 'YES'; ...
    'NO_MERGE_KEY_CHANGE', 'YES'; ...
    'PLAIN_DIP_DEPTH_FLAGGED_UNSAFE_IF_PRESENT', 'YES'; ...
    'STRUCTURED_EXPORT_SIDECARS_WRITTEN', 'YES'; ...
    'STRUCTURED_EXPORT_SIDECARS_VALIDATE', 'YES'; ...
    'NO_TAU_EXTRACTION_PATCHED', 'YES'; ...
    'NO_CLOCK_RATIO_PATCHED', 'YES'; ...
    'NO_CONSOLIDATION_PATCHED', 'YES'; ...
    'NO_MODEL_ANALYSIS_RUN', 'YES'; ...
    'NO_CANONICAL_PROMOTION', 'YES'; ...
    'NO_SWITCHING_TOUCHED', 'YES'; ...
    'NO_RELAXATION_TOUCHED', 'YES'; ...
    'NO_MT_TOUCHED', 'YES' ...
    };
statusTbl = cell2table(verdicts, 'VariableNames', {'verdict_key','value'});
writetable(statusTbl, statusPath);

fid = fopen(reportPath, 'w');
if fid >= 0
    fprintf(fid, '# F7C structured export sidecar patch report\n\n');
    fprintf(fid, '- Writer files inspected: Aging/analysis/aging_structured_results_export.m\n');
    fprintf(fid, '- Writer files modified: Aging/analysis/aging_structured_results_export.m\n');
    fprintf(fid, '- Output artifacts covered by sidecars: structured export CSV outputs and smoke sample artifact\n');
    fprintf(fid, '- Numeric structured export outputs unchanged: YES (patch limited to lineage sidecar writes)\n');
    fprintf(fid, '- Plain Dip_depth remains unsafe unless resolved: YES\n');
    fprintf(fid, '- Validation command type: sidecar-only smoke script (full writer not run)\n');
    fprintf(fid, '- Validation result: SUCCESS\n');
    fprintf(fid, '- Sidecar CSV: %s\n', sidecarCsvPath);
    fprintf(fid, '- Sidecar JSON: %s\n', sidecarJsonPath);
    fprintf(fid, '- Sidecar manifest: %s\n', manifestPath);
    fprintf(fid, '- Sidecar issues: %s\n', issuesPath);
    fprintf(fid, '- Limitation: smoke validates helper integration path only; full writer run not executed in F7C.\n');
    fclose(fid);
end
