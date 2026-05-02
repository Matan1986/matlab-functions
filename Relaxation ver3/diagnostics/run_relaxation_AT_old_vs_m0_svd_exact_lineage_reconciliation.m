% RLX-ACTIVITY-LINEAGE-05 — A_T_old ↔ m0_svd exact lineage reconciliation (Relaxation-only diagnostic).
% Writes tables under tables/relaxation/ and report under reports/relaxation/.
% Does not rerun RF5A; reads existing score tables only.

fidTopProbe = fopen(fullfile(pwd, 'execution_probe_top.txt'), 'w');
if fidTopProbe >= 0, fclose(fidTopProbe); end

clear; clc;

repoRoot = 'C:/Dev/matlab-functions';
if exist(repoRoot, 'dir') ~= 7
    rd = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(fileparts(fileparts(rd)));
end

addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'tools'));

tblRelax = fullfile(repoRoot, 'tables', 'relaxation');
repRelax = fullfile(repoRoot, 'reports', 'relaxation');
for d = {tblRelax, repRelax}
    if exist(d{1}, 'dir') ~= 7, mkdir(d{1}); end
end

cfg = struct();
cfg.runLabel = 'relaxation_AT_old_vs_m0_lineage_05';

run = [];
executionStatus = table({'FAILED'}, {'NO'}, {'not_started'}, 0, {'LINEAGE_05_not_started'}, ...
    'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_COMMON_T', 'MAIN_RESULT_SUMMARY'});

try
    run = createRunContext('relaxation', cfg);

    oldRunId = 'run_2026_03_10_175048_relaxation_observable_stability_audit';
    oldTempPath = fullfile(repoRoot, 'results', 'relaxation', 'runs', oldRunId, 'tables', 'temperature_observables.csv');

    invPath = fullfile(tblRelax, 'relaxation_AT_old_vs_m0_svd_lineage_05_inventory.csv');
    srcPath = fullfile(tblRelax, 'relaxation_AT_old_vs_m0_svd_lineage_05_source_object_comparison.csv');
    alignPath = fullfile(tblRelax, 'relaxation_AT_old_vs_m0_svd_lineage_05_temperature_alignment.csv');
    numPath = fullfile(tblRelax, 'relaxation_AT_old_vs_m0_svd_lineage_05_numeric_comparison.csv');
    diagPath = fullfile(tblRelax, 'relaxation_AT_old_vs_m0_svd_lineage_05_difference_diagnosis.csv');
    nextPath = fullfile(tblRelax, 'relaxation_AT_old_vs_m0_svd_lineage_05_next_step_decision.csv');
    statPath = fullfile(tblRelax, 'relaxation_AT_old_vs_m0_svd_lineage_05_status.csv');
    reportPath = fullfile(repRelax, 'relaxation_AT_old_vs_m0_svd_lineage_05_exact_reconciliation.md');

    m0Rf5aPath = fullfile(repoRoot, 'tables', 'relaxation_RF5A_m0_svd_scores_RF3R.csv');
    m0RconPath = fullfile(tblRelax, 'relaxation_RCON_02B_Aproj_vs_SVD_score.csv');

    oldExists = exist(oldTempPath, 'file') == 2;
    rf5aExists = exist(m0Rf5aPath, 'file') == 2;
    rconExists = exist(m0RconPath, 'file') == 2;

    invRows = {
        'legacy_temperature_observables_export', oldTempPath, oldExists, oldRunId, ...
            'Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m', ...
            'T;A_T;R_T;Relax_beta_T;Relax_tau_T', nan, nan, ...
            iif(oldExists, 'high_if_present', 'none_missing'), ...
            'Canonical historical path referenced across repo analysis scripts'; ...
        'current_m0_RF5A_saved_scores', m0Rf5aPath, rf5aExists, 'run_2026_04_26_234453', ...
            'Relaxation ver3/run_relaxation_RF5A_m0_proxy_audit_RF3R.m', ...
            'run_id;temperature;m0_svd_score', nan, nan, ...
            iif(rf5aExists, 'high', 'none'), ...
            'Full-data SVD on RF3R canonical curve matrix X (time x temp); m0 = S(1)*V(:,1)'; ...
        'current_m0_RCON_table_AR01_stack', m0RconPath, rconExists, 'same_matrix_same_grid', ...
            'tables producer / RCON 02B', ...
            'temperature_K;A_obs;A_proj_nonSVD;SVD_score_mode1;match_rule', nan, nan, ...
            iif(rconExists, 'high', 'none'), ...
            'Per-temperature SVD_score_mode1 aligned with AR01 common map'; ...
        'prior_diagnostic_script', fullfile(repoRoot, 'Relaxation ver3', 'run_relaxation_activity_A_vs_m0_diagnostic_RF3R.m'), ...
            exist(fullfile(repoRoot, 'Relaxation ver3', 'run_relaxation_activity_A_vs_m0_diagnostic_RF3R.m'), 'file') == 2, ...
            '', 'Relaxation ver3/run_relaxation_activity_A_vs_m0_diagnostic_RF3R.m', ...
            'see_diagnostic_outputs_RF3R_csv_inventory', nan, nan, 'medium', ...
            'Did not join canonical temperature_observables A_T — not closure for LINEAGE-05'
        };
    invTbl = cell2table(invRows, 'VariableNames', ...
        {'artifact_role', 'path', 'exists', 'run_id', 'producer_script', 'columns', ...
        'n_temperatures', 'temperature_range', 'confidence', 'notes'});
    writetable(invTbl, invPath);

    srcRows = {
        'old_stability_audit_dMMap', ...
            'embedded_in_producer_resolveLatestCompleteSourceRun_variantBank', ...
            'from_selected_relaxation_run', ...
            'rows=temperatures cols=time_or_log_time', ...
            nan, nan, ...
            'variant.T variant.xGrid variant.tGrid', ...
            'variant.dMMap from selected DeltaM map CSV stack', ...
            'baseline_variant_primaryVariant_smoothing_variants', ...
            'strict_subset_masks_supported_in_analyzeScenario', ...
            ['[U,S,V]=svd(dMMap,econ); A_T_row = sigma(1)*U(:,1); peakSignedValue orientation on sigma*u1 — ', ...
             'left singular vector = temperature dimension for temp-by-time matrix']; ...
        'RF5A_RF3R_canonical_curve_matrix_X', ...
            fullfile(repoRoot, 'results', 'relaxation_post_field_off_RF3R_canonical', 'runs', 'run_2026_04_26_234453'), ...
            'run_2026_04_26_234453', ...
            'rows=time_columns=temperature', ...
            320, nan, ...
            'manifest_and_curve_index_in_RF3R_tables', ...
            'linspace_common_intersection_320', ...
            'default_replay_non_quality_flagged_traces', ...
            'interp1_linear_on_delta_m', ...
            'X=XtempTime.'' then [U,S,V]=svd(X); m0_svd=S(1,1)*V(:,1); flip psi sign via sum(psi)' ...
        };
    srcTbl = cell2table(srcRows, 'VariableNames', ...
        {'object_name', 'path', 'run_id', 'matrix_orientation', 'n_rows', 'n_columns', ...
        'temperature_source', 'time_grid_source', 'baseline_or_smoothing', ...
        'trace_selection', 'notes'});
    writetable(srcTbl, srcPath);

    T_at = [];
    AT_old = [];
    At_rec = [];
    if oldExists
        ot = readtable(oldTempPath, 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
        if ismember('T', ot.Properties.VariableNames) && ismember('A_T', ot.Properties.VariableNames)
            T_at = double(ot.T(:));
            AT_old = double(ot.A_T(:));
        end
    end

    T_m0 = [];
    M0_rf = [];
    if rf5aExists
        rt = readtable(m0Rf5aPath, 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
        T_m0 = double(rt.temperature(:));
        M0_rf = double(rt.m0_svd_score(:));
    end

    T_rc = [];
    M0_rc = [];
    if rconExists
        rc = readtable(m0RconPath, 'TextType', 'string', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
        T_rc = double(rc.temperature_K(:));
        M0_rc = double(rc.SVD_score_mode1(:));
    end

    uT = unique([T_m0(:); T_at(:); T_rc(:)]);
    uT = uT(isfinite(uT));
    uT = sort(uT);

    presAt = false(numel(uT), 1);
    presM0 = false(numel(uT), 1);
    atCol = nan(numel(uT), 1);
    m0Col = nan(numel(uT), 1);
    for ii = 1:numel(uT)
        tt = uT(ii);
        if ~isempty(T_at)
            [d, ix] = min(abs(T_at - tt));
            if d < 0.05
                presAt(ii) = true;
                atCol(ii) = AT_old(ix);
            end
        end
        if ~isempty(T_m0)
            [d2, ix2] = min(abs(T_m0 - tt));
            if d2 < 0.05
                presM0(ii) = true;
                m0Col(ii) = M0_rf(ix2);
            end
        end
    end

    alignTbl = table(uT, presAt, presM0, atCol, nan(numel(uT), 1), m0Col, ...
        repmat("LINEAGE_05", numel(uT), 1), 'VariableNames', ...
        {'T_K', 'present_in_AT_old', 'present_in_m0_svd', 'A_T_old', 'A_T_recomputed', 'm0_svd', 'notes'});
    writetable(alignTbl, alignPath);

    commonMask = presAt & presM0;
    nCommon = sum(commonMask);
    x = atCol(commonMask);
    y = m0Col(commonMask);

    numRows = cell(0, 11);
    [numRows, row_at_m0] = rlx05_add_numeric_row(numRows, 'AT_old_vs_m0_RF5A_saved', x, y, nCommon);

    if rf5aExists && rconExists && numel(T_m0) >= 2 && numel(T_rc) >= 2
        [xr, yr, ncR] = rlx05_align_nearest(T_rc, M0_rc, T_m0, M0_rf);
        [numRows, ~] = rlx05_add_numeric_row(numRows, 'RF5A_m0_vs_RCON_SVD_score_internal_consistency', xr, yr, ncR);
    end

    numTbl = cell2table(numRows, 'VariableNames', ...
        {'comparison_type', 'n_common', 'pearson', 'spearman', 'scale_c', 'affine_intercept_b', ...
        'affine_slope_c', 'normalized_rmse', 'max_abs_residual', 'largest_residual_T', 'notes'});
    writetable(numTbl, numPath);

    diagTbl = build_diagnosis(oldExists, rf5aExists, rconExists, nCommon, row_at_m0);
    writetable(diagTbl, diagPath);

    nextJust = next06_justified(oldExists, nCommon, row_at_m0);
    nextReason = next06_reason(oldExists, nCommon);
    nextTbl = table({'RLX-ACTIVITY-LINEAGE-06'}, {nextJust}, {nextReason}, ...
        {'recover_legacy_run_or_temperature_observables.csv;DeltaM_map_stack'}, ...
        {'rebuild_A_T_from_documented_dMMap_if_maps_recovered'}, ...
        {'blocked_until_old_export_present'}, ...
        'VariableNames', {'next_task_id', 'justified', 'reason', 'required_inputs', 'proposed_scope', 'notes'});
    writetable(nextTbl, nextPath);

    statKeys = build_status_struct(oldExists, rf5aExists, rconExists, nCommon, row_at_m0);
    writetable(struct2table(statKeys), statPath);

    rlx05_write_report(reportPath, oldExists, oldTempPath, m0Rf5aPath, m0RconPath, ...
        nCommon, row_at_m0, nextJust);

    executionStatus = table({'SUCCESS'}, {'YES'}, {''}, nCommon, {'LINEAGE_05_tables_written'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_COMMON_T', 'MAIN_RESULT_SUMMARY'});

catch ME
    executionStatus = table({'FAILED'}, {'NO'}, {ME.message}, 0, {'LINEAGE_05_failed'}, ...
        'VariableNames', {'EXECUTION_STATUS', 'INPUT_FOUND', 'ERROR_MESSAGE', 'N_COMMON_T', 'MAIN_RESULT_SUMMARY'});
    if ~isempty(run) && isfield(run, 'run_dir')
        writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
    end
    rethrow(ME);
end

if ~isempty(run) && isfield(run, 'run_dir')
    writetable(executionStatus, fullfile(run.run_dir, 'execution_status.csv'));
end

fidBot = fopen(fullfile(pwd, 'execution_probe_bottom.txt'), 'w');
if fidBot >= 0, fclose(fidBot); end

function s = iif(tf, a, b)
    if tf, s = a; else, s = b; end
end

function [rows, detail] = rlx05_add_numeric_row(rows, ctype, x, y, nCommon)
detail = struct('pearson', nan, 'spearman', nan, 'scale_c', nan, 'b', nan, 'c', nan, ...
    'nrmse', nan, 'maxres', nan, 'Tres', nan, 'nrmse_affine', nan);
if isempty(x) || isempty(y) || numel(x) < 2 || numel(y) < 2 || nCommon < 2
    rows(end+1, :) = {ctype, nCommon, nan, nan, nan, nan, nan, nan, nan, nan, 'insufficient_overlap_or_missing_series'};
    detail.nrmse_affine = nan;
    return;
end
x = x(:);
y = y(:);
detail.pearson = corr(x, y, 'rows', 'complete');
detail.spearman = corr(x, y, 'type', 'Spearman', 'rows', 'complete');
p1 = corr(x, -y, 'rows', 'complete');
if abs(p1) > abs(detail.pearson)
    detail.pearson_signflip = p1;
else
    detail.pearson_signflip = detail.pearson;
end
scale_c = (x' * y) / max(x' * x, eps);
detail.scale_c = scale_c;
res_s = y - scale_c * x;
detail.nrmse = sqrt(mean(res_s.^2)) / max(sqrt(mean(y.^2)), eps);
pc = polyfit(x, y, 1);
detail.c = pc(1);
detail.b = pc(2);
res_a = y - (pc(2) + pc(1) * x);
nrmse_a = sqrt(mean(res_a.^2)) / max(sqrt(mean(y.^2)), eps);
[~, ixm] = max(abs(res_a));
detail.maxres = abs(res_a(ixm));
detail.Tres = nan;
rows(end+1, :) = {ctype, nCommon, detail.pearson, detail.spearman, scale_c, pc(2), pc(1), ...
    nrmse_a, detail.maxres, nan, 'affine_normalized_rmse_column_uses_affine_fit'};
detail.nrmse_affine = nrmse_a;
end

function [x, y, nc] = rlx05_align_nearest(Ta, va, Tb, vb)
x = [];
y = [];
nc = 0;
for i = 1:numel(Tb)
    [d, j] = min(abs(Ta - Tb(i)));
    if d < 0.05
        x(end+1, 1) = va(j); %#ok<AGROW>
        y(end+1, 1) = vb(i); %#ok<AGROW>
    end
end
nc = numel(x);
end

function diagTbl = build_diagnosis(oldExists, rf5aExists, rconExists, nCommon, rowDetail)
pk = {};
vv = {};
ev = {};
nt = {};
pk{end+1,1} = 'TRANSPOSE_ONLY';
vv{end+1,1} = 'PARTIAL';
ev{end+1,1} = 'Old svd(dMMap) with A=sigma(1)*U(:,1) on temp-by-time; RF5A svd(X) with m0=S(1)*V(:,1) on time-by-temp — transpose pairs U and V';
nt{end+1,1} = 'Equivalence only if dMMap equals X. numerically';

pk{end+1,1} = 'SIGN_ONLY';
if nCommon >= 2 && isfield(rowDetail, 'pearson') && isfinite(rowDetail.pearson)
    vv{end+1,1} = iif(abs(rowDetail.pearson) > 0.95, 'PARTIAL', 'NO');
else
    vv{end+1,1} = 'UNKNOWN';
end
ev{end+1,1} = 'peakSignedValue vs RF5A psi flip';
nt{end+1,1} = 'Needs overlapping series';

pk{end+1,1} = 'SOURCE_OBJECT_DIFFERENCE';
vv{end+1,1} = 'YES';
ev{end+1,1} = 'Legacy stability maps vs RF3R canonical RF5A matrix';
nt{end+1,1} = 'Independent CSV stacks';

pk{end+1,1} = 'OLD_AT_OUTPUT_MISSING';
vv{end+1,1} = iif(~oldExists, 'YES', 'NO');
ev{end+1,1} = 'temperature_observables path check';
nt{end+1,1} = iif(~oldExists, 'Workspace lacks canonical run export', 'found');

pk{end+1,1} = 'CURRENT_M0_OUTPUT_MISSING';
vv{end+1,1} = iif(~rf5aExists && ~rconExists, 'YES', 'NO');
ev{end+1,1} = 'RF5A and RCON tables';
nt{end+1,1} = '';

pk{end+1,1} = 'TEMPERATURE_MASK_DIFFERENCE';
vv{end+1,1} = 'PARTIAL';
ev{end+1,1} = 'RF5A n=8 vs RCON full index';
nt{end+1,1} = '';

pk{end+1,1} = 'TIME_GRID_DIFFERENCE';
vv{end+1,1} = 'PARTIAL';
ev{end+1,1} = 'RF5A 320 linspace vs variant xGrid';
nt{end+1,1} = '';

pk{end+1,1} = 'TRACE_SELECTION_DIFFERENCE';
vv{end+1,1} = 'PARTIAL';
ev{end+1,1} = 'RF3R2 replay filters vs legacy map resolution';
nt{end+1,1} = '';

pk{end+1,1} = 'BASELINE_OR_SMOOTHING_DIFFERENCE';
vv{end+1,1} = 'PARTIAL';
ev{end+1,1} = 'variantBank smoothing variants vs raw interp';
nt{end+1,1} = '';

pk{end+1,1} = 'NORMALIZATION_DIFFERENCE';
vv{end+1,1} = 'PARTIAL';
ev{end+1,1} = 'RCON join rules vs raw SVD on unnormalized X';
nt{end+1,1} = '';

diagTbl = table(pk, vv, ev, nt, 'VariableNames', {'diagnosis_key', 'verdict', 'evidence', 'notes'});
end

function j = next06_justified(oldExists, nCommon, rowDetail)
if ~oldExists
    j = 'PARTIAL';
    return;
end
if nCommon < 2
    j = 'PARTIAL';
    return;
end
if isfield(rowDetail, 'nrmse_affine') && isfinite(rowDetail.nrmse_affine) && rowDetail.nrmse_affine < 1e-6
    j = 'YES';
    return;
end
j = 'PARTIAL';
end

function r = next06_reason(oldExists, nCommon)
if ~oldExists
    r = 'OLD_AT_TABLE_OR_RUN_DIRECTORY_MISSING_FROM_WORKSPACE';
elseif nCommon < 2
    r = 'NO_TEMPERATURE_OVERLAP_BETWEEN_STORED_AT_AND_CURRENT_M0';
else
    r = 'NUMERIC_CLOSURE_NOT_VERIFIED_AT_MACHINE_PRECISION';
end
end

function st = build_status_struct(oldExists, rf5aExists, rconExists, nCommon, rowDetail)
keys = {
    'TASK_COMPLETED', 'YES'; ...
    'RELAXATION_MODULE_ONLY', 'YES'; ...
    'SWITCHING_USED', 'NO'; ...
    'X_USED', 'NO'; ...
    'AX_FIT_RUN', 'NO'; ...
    'POWERLAW_FIT_RUN', 'NO'; ...
    'CROSS_MODULE_CLAIM_CREATED', 'NO'; ...
    'OLD_AT_TABLE_FOUND', iif(oldExists, 'YES', 'NO'); ...
    'OLD_AT_SOURCE_MAP_FOUND', 'UNKNOWN'; ...
    'OLD_AT_RECOMPUTED', 'NO'; ...
    'CURRENT_M0_SVD_TABLE_FOUND', iif(rf5aExists || rconExists, 'YES', 'NO'); ...
    'COMMON_TEMPERATURES_FOUND', iif(nCommon >= 1, 'YES', 'NO'); ...
    'ROW_LEVEL_NUMERIC_COMPARISON_DONE', iif(nCommon >= 2, 'YES', 'NO'); ...
    'AT_EQUALS_M0_BY_DEFINITION', 'NO'; ...
    'AT_EQUALS_M0_NUMERICALLY', 'NO'; ...
    'AT_EQUIVALENT_TO_M0_UP_TO_SIGN', 'UNKNOWN'; ...
    'AT_EQUIVALENT_TO_M0_UP_TO_SCALE', 'UNKNOWN'; ...
    'AT_EQUIVALENT_TO_M0_UP_TO_AFFINE', 'UNKNOWN'; ...
    'AT_MONOTONIC_WITH_M0', 'UNKNOWN'; ...
    'AT_AND_M0_DIFFER_BY_SOURCE_OBJECT', 'YES'; ...
    'AT_AND_M0_DIFFER_BY_TEMPERATURE_MASK', 'PARTIAL'; ...
    'AT_AND_M0_DIFFER_BY_TIME_GRID', 'PARTIAL'; ...
    'AT_AND_M0_DIFFER_BY_TRACE_SELECTION', 'PARTIAL'; ...
    'AT_AND_M0_DIFFER_BY_BASELINE_OR_SMOOTHING', 'PARTIAL'; ...
    'EXACT_IDENTITY_CLAIM_SAFE', 'NO'; ...
    'SAME_CONCEPTUAL_FAMILY_CLAIM_SAFE', 'YES'; ...
    'READY_FOR_AX_REINTERPRETATION', 'NO'; ...
    'LINEAGE_06_JUSTIFIED', 'PARTIAL' ...
    };

numEq = 'NO';
if nCommon >= 2 && isfield(rowDetail, 'nrmse_affine') && isfinite(rowDetail.nrmse_affine) && rowDetail.nrmse_affine < 1e-9
    numEq = 'YES';
end
keys = rlx05_set_key(keys, 'AT_EQUALS_M0_NUMERICALLY', numEq);

signEq = 'UNKNOWN';
scEq = 'UNKNOWN';
afEq = 'UNKNOWN';
mono = 'UNKNOWN';
if nCommon >= 2 && isfield(rowDetail, 'pearson') && isfinite(rowDetail.pearson)
    if abs(abs(rowDetail.pearson) - 1) < 1e-4
        signEq = 'YES';
    elseif abs(rowDetail.pearson) > 0.9
        signEq = 'PARTIAL';
    end
end
if nCommon >= 2 && isfield(rowDetail, 'nrmse_affine') && isfinite(rowDetail.nrmse_affine)
    if rowDetail.nrmse_affine < 1e-4
        afEq = 'YES';
        scEq = 'YES';
    elseif rowDetail.nrmse_affine < 0.01
        afEq = 'PARTIAL';
    end
end
if nCommon >= 2 && isfield(rowDetail, 'spearman') && isfinite(rowDetail.spearman)
    if rowDetail.spearman > 0.99
        mono = 'YES';
    end
end
keys = rlx05_set_key(keys, 'AT_EQUIVALENT_TO_M0_UP_TO_SIGN', signEq);
keys = rlx05_set_key(keys, 'AT_EQUIVALENT_TO_M0_UP_TO_SCALE', scEq);
keys = rlx05_set_key(keys, 'AT_EQUIVALENT_TO_M0_UP_TO_AFFINE', afEq);
keys = rlx05_set_key(keys, 'AT_MONOTONIC_WITH_M0', mono);

numRows = size(keys, 1);
st.metric_key = cell(numRows, 1);
st.metric_value = cell(numRows, 1);
for i = 1:numRows
    st.metric_key{i} = keys{i, 1};
    st.metric_value{i} = keys{i, 2};
end
end

function keys = rlx05_set_key(keys, kname, val)
for i = 1:size(keys, 1)
    if strcmp(keys{i, 1}, kname)
        keys{i, 2} = val;
        return;
    end
end
end

function rlx05_write_report(fp, oldExists, oldPath, pRf5a, pRcon, nCommon, rowDetail, nextJust)
fid = fopen(fp, 'w');
if fid < 0, error('report'); end
fprintf(fid, '# RLX-ACTIVITY-LINEAGE-05 — Exact lineage reconciliation (A_T_old vs m0_svd)\n\n');
fprintf(fid, '## 1. Purpose and scope\n\n');
fprintf(fid, 'Relaxation-only diagnostic comparing legacy **`A_T`** from the observable stability audit export to current **`m0_svd`** scores. No Switching, no `X_eff`, no AX fits.\n\n');
fprintf(fid, '## 2. Why Relaxation-only\n\n');
fprintf(fid, 'All inputs are Relaxation producers/tables; no cross-module bridge claims.\n\n');
fprintf(fid, '## 3. Old A_T lineage\n\n');
fprintf(fid, 'Producer: `Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m`.\n\n');
fprintf(fid, '- `buildTemperatureObservablesTable` writes **`A_T = result.A`** where **`A = sigma(1)*U(:,1)`** from **`[U,S,V] = svd(dMMap,\"econ\")`** with **`dMMap`** shaped **temperature × time** (`analyzeScenario`).\n');
fprintf(fid, '- Orientation: `peakSignedValue(sigma(1)*u1)` flips sign of **U and V columns** together.\n\n');
fprintf(fid, 'Canonical saved table path checked: `%s` — **exists: %s**.\n\n', oldPath, char(string(oldExists)));
fprintf(fid, '## 4. Current m0_svd lineage\n\n');
fprintf(fid, '- RF5A script: `Relaxation ver3/run_relaxation_RF5A_m0_proxy_audit_RF3R.m` builds **`X`** rows=time, cols=temp, then **`m0_svd = S(1,1)*V(:,1)`**, with **`psi = U(:,1)`** sign flip via sum(psi).\n');
fprintf(fid, '- Saved scores: `%s`\n', pRf5a);
fprintf(fid, '- RCON reference (AR01 stack): `%s`\n\n', pRcon);
fprintf(fid, '## 5. Matrix orientation and SVD definition comparison\n\n');
fprintf(fid, 'For **`dMMap = X''`**, the **left** singular vector of **`dMMap`** (temperature axis) corresponds to the **right** singular vector of **`X`** (temperature axis) — **transpose pair**, same rank-1 temperature weights up to sign conventions in code.\n\n');
fprintf(fid, '## 6. Temperature-set alignment\n\n');
fprintf(fid, '**Common temperatures with stored `A_T` and RF5A `m0_svd_score`:** %d.\n\n', nCommon);
fprintf(fid, '## 7. Row-level numerical reconciliation\n\n');
if nCommon < 2
    fprintf(fid, '**Blocked:** insufficient overlap or missing legacy **`temperature_observables.csv`** in workspace.\n\n');
else
    fprintf(fid, 'Pearson(raw): %.12g; affine normalized RMSE (diag): see numeric CSV.\n\n', rowDetail.pearson);
end
fprintf(fid, '## 8. Difference diagnosis\n\n');
fprintf(fid, 'See `relaxation_AT_old_vs_m0_svd_lineage_05_difference_diagnosis.csv`.\n\n');
fprintf(fid, '## 9–12. Relationship classification and claims\n\n');
fprintf(fid, '- **Numeric identity:** **NOT** established (`EXACT_IDENTITY_CLAIM_SAFE = NO`).\n');
fprintf(fid, '- **Same conceptual family (rank-1 temperature amplitude):** **YES** at definition level (`SAME_CONCEPTUAL_FAMILY_CLAIM_SAFE = YES`).\n');
fprintf(fid, '- **LINEAGE-06 justified:** **%s** (missing legacy export ⇒ cannot canonically reconstruct old **`A_T`** without recovering map inputs).\n\n', nextJust);
fprintf(fid, '## 13. Ready for AX reinterpretation\n\n');
fprintf(fid, '**NO** — legacy export missing or reconciliation incomplete (`READY_FOR_AX_REINTERPRETATION = NO`).\n\n');
fprintf(fid, '## 14. Final verdicts\n\n');
fprintf(fid, 'Machine-readable: `relaxation_AT_old_vs_m0_svd_lineage_05_status.csv`.\n');
fclose(fid);
end
