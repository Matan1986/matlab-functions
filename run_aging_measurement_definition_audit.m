% =========================================================
% INTEGRITY MARKER - INVALID AGING ANALYSIS
% INVALID_FOR_AGING = YES
% DEFINITION_CONTAMINATION = YES
% REASON = Relaxation measurement logic applied to aging context.
% =========================================================

clear; clc;

repo_root = 'C:\Dev\matlab-functions';
script_abs = 'C:\Dev\matlab-functions\run_aging_measurement_definition_audit.m';
data_dir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM';
run_label = 'aging_measurement_definition_audit';

if exist(fullfile(repo_root, 'tables'), 'dir') ~= 7
    mkdir(fullfile(repo_root, 'tables'));
end
if exist(fullfile(repo_root, 'reports'), 'dir') ~= 7
    mkdir(fullfile(repo_root, 'reports'));
end

main_table_root = fullfile(repo_root, 'tables', 'aging_measurement_definition_audit.csv');
status_table_root = fullfile(repo_root, 'tables', 'aging_measurement_definition_audit_status.csv');
report_root = fullfile(repo_root, 'reports', 'aging_measurement_definition_audit.md');

run_dir = fullfile(repo_root, 'results', 'relaxation', 'runs', ['run_' datestr(now, 'yyyy_mm_dd_HHMMSS') '_' run_label]);
if exist(run_dir, 'dir') ~= 7
    mkdir(run_dir);
end
if exist(fullfile(run_dir, 'tables'), 'dir') ~= 7
    mkdir(fullfile(run_dir, 'tables'));
end
if exist(fullfile(run_dir, 'reports'), 'dir') ~= 7
    mkdir(fullfile(run_dir, 'reports'));
end

execution_status = 'FAILED';
input_found = 'NO';
error_message = '';

header_main = { ...
    'row_type', 'test_id', 'variant_label', 'axis', 'choice', ...
    'n_supported', 'n_failed', 'n_overlap_with_baseline', ...
    'observable_median', 'observable_corr_vs_baseline', 'observable_rel_change_median', ...
    'observable_rmse', 'observable_nrmse', 'rank_stability_spearman', 'ordering_kendall_tau', ...
    'monotonicity_delta_vs_baseline', 'trace_corr_median', 'trace_nrmse_median', ...
    'shape_similarity_median', 'scale_deviation_median', 'trend_distortion_median', ...
    'low_frequency_bias_median', 'scalar_stable', 'trace_stable', 'variant_stable', 'note'};
rows_main = {
    'meta', 'meta', 'meta', 'meta', 'initialized', ...
    0, 0, 0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, 'NO', 'NO', 'NO', 'not_executed'};

header_status = {'verdict','value','criterion','evidence'};
rows_status = {
    'AGING_OBSERVABLE_DEFINED','NO','baseline extraction succeeds with sufficient finite traces','not_executed';
    'AGING_OBSERVABLE_PHYSICAL','NO','small perturbations do not produce significant changes','not_executed';
    'AGING_T0_STABLE','NO','t0 shifts keep scalar + structure stable','not_executed';
    'AGING_WINDOW_STABLE','NO','window changes keep scalar + structure stable','not_executed';
    'AGING_NORMALIZATION_STABLE','NO','normalization changes preserve structure and do not distort scalar','not_executed';
    'AGING_BASELINE_STABLE','NO','baseline/drift handling does not significantly distort scalar/trace','not_executed';
    'AGING_SAMPLING_STABLE','NO','downsampling/binning stays within stability bounds','not_executed';
    'AGING_TRACE_STRUCTURE_STABLE','NO','full trace shape/order stable across perturbations','not_executed'};

report_text = '# Aging Measurement Definition Audit';

try
    addpath(fullfile(repo_root, 'Aging', 'utils'));
    addpath(fullfile(repo_root, 'Relaxation ver3'));

    if exist(data_dir, 'dir') ~= 7
        error('Raw data directory not found: %s', data_dir);
    end
    input_found = 'YES';

    [fileList, temps, ~, ~, ~, ~] = getFileList_relaxation(data_dir, 'parula');
    [Time_table, Temp_table, Field_table, Moment_table, ~] = importFiles_relaxation(data_dir, fileList, true, false);

    n_files = numel(fileList);
    if n_files < 4
        error('Too few raw trace files for audit: %d', n_files);
    end

    T_nom = temps(:);
    for i = 1:n_files
        if i <= numel(Temp_table) && ~isempty(Temp_table{i})
            Ti = Temp_table{i};
            Ti = Ti(isfinite(Ti));
            if ~isempty(Ti) && ~isfinite(T_nom(i))
                T_nom(i) = median(Ti, 'omitnan');
            end
        end
    end
    if any(~isfinite(T_nom))
        error('Missing finite temperature labels in raw traces.');
    end

    variants = buildVariants();
    n_variants = numel(variants);
    have_robustfit = (exist('robustfit', 'file') == 2);

    obs_val = nan(n_variants, n_files);
    obs_t0 = nan(n_variants, n_files);
    obs_tstart = nan(n_variants, n_files);
    obs_tend = nan(n_variants, n_files);
    supported = false(n_variants, n_files);
    fail_reason = cell(n_variants, n_files);
    trace_x = cell(n_variants, n_files);
    trace_y = cell(n_variants, n_files);

    for v = 1:n_variants
        for i = 1:n_files
            if i > numel(Time_table) || i > numel(Moment_table) || i > numel(Field_table)
                fail_reason{v, i} = 'MISSING_TABLE_ENTRY';
                continue;
            end

            t = Time_table{i};
            h = Field_table{i};
            m = Moment_table{i};
            if isempty(t) || isempty(h) || isempty(m)
                fail_reason{v, i} = 'EMPTY_TRACE';
                continue;
            end

            out = extractCanonicalObservableVariant(t, h, m, variants(v), have_robustfit);
            supported(v, i) = out.supported;
            fail_reason{v, i} = out.fail_reason;
            if out.supported
                obs_val(v, i) = out.observable;
                obs_t0(v, i) = out.t0_used;
                obs_tstart(v, i) = out.t_start;
                obs_tend(v, i) = out.t_end;
                trace_x{v, i} = out.trace_x;
                trace_y{v, i} = out.trace_y;
            end
        end
    end

    baseline_idx = find([variants.is_baseline], 1, 'first');
    if isempty(baseline_idx)
        error('Baseline variant is not defined.');
    end

    n_supported = sum(supported, 2);
    n_failed = n_files - n_supported;

    obs_med = nan(n_variants, 1);
    obs_corr = nan(n_variants, 1);
    obs_rel_change = nan(n_variants, 1);
    obs_rmse = nan(n_variants, 1);
    obs_nrmse = nan(n_variants, 1);
    rank_spearman = nan(n_variants, 1);
    order_kendall = nan(n_variants, 1);
    mono_delta = nan(n_variants, 1);
    trace_corr_med = nan(n_variants, 1);
    trace_nrmse_med = nan(n_variants, 1);
    shape_sim_med = nan(n_variants, 1);
    scale_dev_med = nan(n_variants, 1);
    trend_dist_med = nan(n_variants, 1);
    low_bias_med = nan(n_variants, 1);
    n_overlap = zeros(n_variants, 1);

    scalar_stable = false(n_variants, 1);
    trace_stable = false(n_variants, 1);
    variant_stable = false(n_variants, 1);
    note = strings(n_variants, 1);

    base_obs = obs_val(baseline_idx, :);

    for v = 1:n_variants
        obs_med(v) = median(obs_val(v, supported(v, :)), 'omitnan');

        if v == baseline_idx
            obs_corr(v) = 1.0;
            obs_rel_change(v) = 0.0;
            obs_rmse(v) = 0.0;
            obs_nrmse(v) = 0.0;
            rank_spearman(v) = 1.0;
            order_kendall(v) = 1.0;
            mono_delta(v) = 0.0;
            trace_corr_med(v) = 1.0;
            trace_nrmse_med(v) = 0.0;
            shape_sim_med(v) = 1.0;
            scale_dev_med(v) = 0.0;
            trend_dist_med(v) = 0.0;
            low_bias_med(v) = 0.0;
            n_overlap(v) = sum(supported(v, :) & supported(baseline_idx, :));
            scalar_stable(v) = true;
            trace_stable(v) = true;
            variant_stable(v) = true;
            note(v) = "baseline;" + aggregateFailNotes(fail_reason(v, :));
            continue;
        end

        mask = supported(v, :) & supported(baseline_idx, :) & isfinite(obs_val(v, :)) & isfinite(base_obs);
        n_overlap(v) = nnz(mask);
        if n_overlap(v) < 4
            note(v) = "insufficient_overlap;" + aggregateFailNotes(fail_reason(v, :));
            continue;
        end

        ov = obs_val(v, mask);
        ob = base_obs(mask);
        tv = T_nom(mask);

        obs_corr(v) = safePearsonCorr(ob, ov);
        obs_rmse(v) = sqrt(mean((ov - ob).^2, 'omitnan'));
        ob_span = max(ob) - min(ob);
        obs_nrmse(v) = obs_rmse(v) / max(ob_span, eps);
        obs_rel_change(v) = median(abs(ov - ob) ./ max(abs(ob), eps), 'omitnan');
        rank_spearman(v) = spearmanCorr(ob, ov);
        order_kendall(v) = kendallTau(ob, ov);

        rho_b = spearmanCorr(tv, ob);
        rho_v = spearmanCorr(tv, ov);
        mono_delta(v) = abs(rho_v - rho_b);

        rr = ov ./ max(abs(ob), eps);
        scale_dev_med(v) = median(abs(rr - 1), 'omitnan');

        tr_corr = nan(n_files, 1);
        tr_nrmse = nan(n_files, 1);
        tr_shape = nan(n_files, 1);
        tr_trend = nan(n_files, 1);
        tr_bias = nan(n_files, 1);
        for i = 1:n_files
            if ~(mask(i))
                continue;
            end
            xb = trace_x{baseline_idx, i};
            yb = trace_y{baseline_idx, i};
            xv = trace_x{v, i};
            yv = trace_y{v, i};
            tm = compareTraceShapes(xb, yb, xv, yv);
            tr_corr(i) = tm.trace_corr;
            tr_nrmse(i) = tm.trace_nrmse;
            tr_shape(i) = tm.shape_corr;
            tr_trend(i) = tm.trend_distortion;
            tr_bias(i) = tm.low_frequency_bias;
        end

        trace_corr_med(v) = median(tr_corr, 'omitnan');
        trace_nrmse_med(v) = median(tr_nrmse, 'omitnan');
        shape_sim_med(v) = median(tr_shape, 'omitnan');
        trend_dist_med(v) = median(tr_trend, 'omitnan');
        low_bias_med(v) = median(tr_bias, 'omitnan');

        scalar_stable(v) = ...
            isfinite(obs_corr(v)) && isfinite(obs_rel_change(v)) && isfinite(obs_nrmse(v)) && ...
            isfinite(rank_spearman(v)) && isfinite(order_kendall(v)) && isfinite(mono_delta(v)) && ...
            (obs_corr(v) >= 0.90) && (obs_rel_change(v) <= 0.20) && (obs_nrmse(v) <= 0.15) && ...
            (rank_spearman(v) >= 0.80) && (order_kendall(v) >= 0.70) && (mono_delta(v) <= 0.25);

        trace_stable(v) = ...
            isfinite(trace_corr_med(v)) && isfinite(trace_nrmse_med(v)) && isfinite(shape_sim_med(v)) && ...
            (trace_corr_med(v) >= 0.95) && (trace_nrmse_med(v) <= 0.15) && (shape_sim_med(v) >= 0.90);

        variant_stable(v) = scalar_stable(v) && trace_stable(v);
        note(v) = aggregateFailNotes(fail_reason(v, :));
    end

    axes_list = {'t0','window','normalization','baseline','sampling'};
    n_axes = numel(axes_list);
    axis_scalar_stable = false(1, n_axes);
    axis_trace_stable = false(1, n_axes);
    axis_stable = false(1, n_axes);
    axis_obs_corr_med = nan(1, n_axes);
    axis_obs_rel_med = nan(1, n_axes);
    axis_obs_nrmse_med = nan(1, n_axes);
    axis_trace_corr_med = nan(1, n_axes);
    axis_trace_nrmse_med = nan(1, n_axes);
    axis_shape_med = nan(1, n_axes);
    axis_order_med = nan(1, n_axes);
    axis_note = strings(1, n_axes);

    for a = 1:n_axes
        idx = find(strcmp({variants.axis}, axes_list{a}) & (~[variants.is_baseline]));
        if isempty(idx)
            axis_note(a) = "no_variants";
            continue;
        end

        axis_obs_corr_med(a) = median(obs_corr(idx), 'omitnan');
        axis_obs_rel_med(a) = median(obs_rel_change(idx), 'omitnan');
        axis_obs_nrmse_med(a) = median(obs_nrmse(idx), 'omitnan');
        axis_trace_corr_med(a) = median(trace_corr_med(idx), 'omitnan');
        axis_trace_nrmse_med(a) = median(trace_nrmse_med(idx), 'omitnan');
        axis_shape_med(a) = median(shape_sim_med(idx), 'omitnan');
        axis_order_med(a) = median(order_kendall(idx), 'omitnan');

        axis_scalar_stable(a) = all(scalar_stable(idx));
        axis_trace_stable(a) = all(trace_stable(idx));
        axis_stable(a) = axis_scalar_stable(a) && axis_trace_stable(a);
        axis_note(a) = sprintf('n_variants=%d;all_scalar=%s;all_trace=%s', numel(idx), toYesNo(axis_scalar_stable(a)), toYesNo(axis_trace_stable(a)));
    end

    idx_t0 = find(strcmp(axes_list, 't0'));
    idx_window = find(strcmp(axes_list, 'window'));
    idx_norm = find(strcmp(axes_list, 'normalization'));
    idx_base = find(strcmp(axes_list, 'baseline'));
    idx_samp = find(strcmp(axes_list, 'sampling'));

    aging_t0_stable = axis_stable(idx_t0);
    aging_window_stable = axis_stable(idx_window);
    aging_norm_stable = axis_stable(idx_norm);
    aging_base_stable = axis_stable(idx_base);
    aging_sampling_stable = axis_stable(idx_samp);

    all_perturb_idx = find(~[variants.is_baseline]);
    global_trace_corr = median(trace_corr_med(all_perturb_idx), 'omitnan');
    global_trace_nrmse = median(trace_nrmse_med(all_perturb_idx), 'omitnan');
    global_shape = median(shape_sim_med(all_perturb_idx), 'omitnan');
    global_order = median(order_kendall(all_perturb_idx), 'omitnan');

    aging_trace_structure_stable = ...
        isfinite(global_trace_corr) && isfinite(global_trace_nrmse) && isfinite(global_shape) && isfinite(global_order) && ...
        (global_trace_corr >= 0.95) && (global_trace_nrmse <= 0.15) && (global_shape >= 0.90) && (global_order >= 0.70) && ...
        all(axis_trace_stable);

    baseline_defined = (n_supported(baseline_idx) >= 4) && have_robustfit && all(isfinite(obs_val(baseline_idx, supported(baseline_idx, :))));
    all_axes_stable = aging_t0_stable && aging_window_stable && aging_norm_stable && aging_base_stable && aging_sampling_stable;

    aging_observable_defined = baseline_defined;
    aging_observable_physical = aging_observable_defined && all_axes_stable;

    scalar_global_stable = all(axis_scalar_stable);
    if aging_trace_structure_stable && ~scalar_global_stable
        interpretation_class = 'SCALARIZATION FAILURE';
    elseif ~aging_trace_structure_stable && ~scalar_global_stable
        interpretation_class = 'MEASUREMENT FAILURE';
    elseif all_axes_stable && aging_trace_structure_stable
        interpretation_class = 'READY FOR NEXT STAGE';
    else
        interpretation_class = 'MEASUREMENT FAILURE';
    end

    rows = cell(n_variants + n_axes + 2, numel(header_main));
    r = 0;
    for v = 1:n_variants
        r = r + 1;
        rows(r, :) = { ...
            'variant', variants(v).id, variants(v).label, variants(v).axis, variants(v).choice, ...
            n_supported(v), n_failed(v), n_overlap(v), ...
            obs_med(v), obs_corr(v), obs_rel_change(v), obs_rmse(v), obs_nrmse(v), ...
            rank_spearman(v), order_kendall(v), mono_delta(v), ...
            trace_corr_med(v), trace_nrmse_med(v), shape_sim_med(v), ...
            scale_dev_med(v), trend_dist_med(v), low_bias_med(v), ...
            toYesNo(scalar_stable(v)), toYesNo(trace_stable(v)), toYesNo(variant_stable(v)), char(note(v))};
    end

    for a = 1:n_axes
        r = r + 1;
        rows(r, :) = { ...
            'axis_summary', ['axis_' axes_list{a}], ['axis_' axes_list{a}], axes_list{a}, 'aggregate', ...
            sum(n_supported(strcmp({variants.axis}, axes_list{a}))), ...
            sum(n_failed(strcmp({variants.axis}, axes_list{a}))), ...
            sum(n_overlap(strcmp({variants.axis}, axes_list{a}))), ...
            NaN, axis_obs_corr_med(a), axis_obs_rel_med(a), NaN, axis_obs_nrmse_med(a), ...
            NaN, axis_order_med(a), NaN, ...
            axis_trace_corr_med(a), axis_trace_nrmse_med(a), axis_shape_med(a), ...
            NaN, NaN, NaN, ...
            toYesNo(axis_scalar_stable(a)), toYesNo(axis_trace_stable(a)), toYesNo(axis_stable(a)), char(axis_note(a))};
    end

    r = r + 1;
    rows(r, :) = { ...
        'global_summary', 'global_trace', 'global_trace', 'structure', 'aggregate', ...
        sum(n_supported(all_perturb_idx)), sum(n_failed(all_perturb_idx)), sum(n_overlap(all_perturb_idx)), ...
        NaN, NaN, NaN, NaN, NaN, ...
        NaN, global_order, NaN, global_trace_corr, global_trace_nrmse, global_shape, ...
        NaN, NaN, NaN, toYesNo(scalar_global_stable), toYesNo(aging_trace_structure_stable), toYesNo(aging_trace_structure_stable), interpretation_class};

    r = r + 1;
    rows(r, :) = { ...
        'global_summary', 'observable_definition', 'observable_definition', 'scalar', 'baseline', ...
        n_supported(baseline_idx), n_failed(baseline_idx), n_overlap(baseline_idx), ...
        obs_med(baseline_idx), NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        NaN, NaN, NaN, NaN, NaN, NaN, ...
        toYesNo(aging_observable_defined), toYesNo(aging_trace_structure_stable), toYesNo(aging_observable_physical), ...
        sprintf('have_robustfit=%s', toYesNo(have_robustfit))};

    rows_main = rows;

    rows_status = {
        'AGING_OBSERVABLE_DEFINED', toYesNo(aging_observable_defined), 'baseline extraction succeeds with sufficient finite traces', sprintf('baseline_supported=%d/%d;robustfit=%s', n_supported(baseline_idx), n_files, toYesNo(have_robustfit));
        'AGING_OBSERVABLE_PHYSICAL', toYesNo(aging_observable_physical), 'small perturbations do not produce significant changes', sprintf('all_axes_stable=%s', toYesNo(all_axes_stable));
        'AGING_T0_STABLE', toYesNo(aging_t0_stable), 't0 shifts keep scalar + structure stable', sprintf('axis_obs_corr=%.4f;axis_trace_corr=%.4f;axis_obs_rel=%.4f', axis_obs_corr_med(idx_t0), axis_trace_corr_med(idx_t0), axis_obs_rel_med(idx_t0));
        'AGING_WINDOW_STABLE', toYesNo(aging_window_stable), 'window changes keep scalar + structure stable', sprintf('axis_obs_corr=%.4f;axis_trace_corr=%.4f;axis_obs_rel=%.4f', axis_obs_corr_med(idx_window), axis_trace_corr_med(idx_window), axis_obs_rel_med(idx_window));
        'AGING_NORMALIZATION_STABLE', toYesNo(aging_norm_stable), 'normalization changes preserve structure and do not distort scalar', sprintf('axis_obs_corr=%.4f;axis_trace_corr=%.4f;axis_scale_dev=%.4f', axis_obs_corr_med(idx_norm), axis_trace_corr_med(idx_norm), median(scale_dev_med(strcmp({variants.axis}, 'normalization')), 'omitnan'));
        'AGING_BASELINE_STABLE', toYesNo(aging_base_stable), 'baseline/drift handling does not significantly distort scalar/trace', sprintf('axis_obs_corr=%.4f;axis_trace_corr=%.4f;axis_low_bias=%.4f', axis_obs_corr_med(idx_base), axis_trace_corr_med(idx_base), median(low_bias_med(strcmp({variants.axis}, 'baseline') & ~[variants.is_baseline]), 'omitnan'));
        'AGING_SAMPLING_STABLE', toYesNo(aging_sampling_stable), 'downsampling/binning stays within stability bounds', sprintf('axis_obs_corr=%.4f;axis_trace_corr=%.4f;axis_obs_nrmse=%.4f', axis_obs_corr_med(idx_samp), axis_trace_corr_med(idx_samp), axis_obs_nrmse_med(idx_samp));
        'AGING_TRACE_STRUCTURE_STABLE', toYesNo(aging_trace_structure_stable), 'full trace shape/order stable across perturbations', sprintf('trace_corr=%.4f;trace_nrmse=%.4f;shape=%.4f;kendall=%.4f', global_trace_corr, global_trace_nrmse, global_shape, global_order)};

    summary_lines = {
        sprintf('- Dataset traces loaded: %d', n_files);
        sprintf('- Baseline-supported traces: %d', n_supported(baseline_idx));
        sprintf('- Global trace correlation median: %.4f', global_trace_corr);
        sprintf('- Global trace nRMSE median: %.4f', global_trace_nrmse);
        sprintf('- Global shape similarity median: %.4f', global_shape);
        sprintf('- Global ordering consistency (Kendall tau) median: %.4f', global_order);
        sprintf('- Scalar stability across axes: %s', toYesNo(scalar_global_stable));
        sprintf('- Trace stability across axes: %s', toYesNo(aging_trace_structure_stable));
        sprintf('- Interpretation class: %s', interpretation_class);
        sprintf('- Ready for next stage: %s', toYesNo(strcmp(interpretation_class, 'READY FOR NEXT STAGE')))};

    verdict_block = {
        ['AGING_OBSERVABLE_DEFINED=' toYesNo(aging_observable_defined)];
        ['AGING_OBSERVABLE_PHYSICAL=' toYesNo(aging_observable_physical)];
        '';
        ['AGING_T0_STABLE=' toYesNo(aging_t0_stable)];
        ['AGING_WINDOW_STABLE=' toYesNo(aging_window_stable)];
        ['AGING_NORMALIZATION_STABLE=' toYesNo(aging_norm_stable)];
        ['AGING_BASELINE_STABLE=' toYesNo(aging_base_stable)];
        ['AGING_SAMPLING_STABLE=' toYesNo(aging_sampling_stable)];
        '';
        ['AGING_TRACE_STRUCTURE_STABLE=' toYesNo(aging_trace_structure_stable)]};

    report_lines = {};
    report_lines{end+1} = '# Aging Measurement Definition Audit';
    report_lines{end+1} = '';
    report_lines{end+1} = '## Scope';
    report_lines{end+1} = '- Stage 0-1 integrity audit only (no PT, no kappa layers, no physics fitting).';
    report_lines{end+1} = '- Observable extracted using current canonical definition: R_relax_canonical = -slope_Huber(M vs ln(tau)) on canonical fit window.';
    report_lines{end+1} = '';
    report_lines{end+1} = '## Perturbations Applied';
    report_lines{end+1} = '- t0 shifts: +/- 1*tau_min';
    report_lines{end+1} = '- window: start x0.5/x1.5 and end x0.8/x1.2';
    report_lines{end+1} = '- normalization: none (current), initial amplitude, tail referenced';
    report_lines{end+1} = '- baseline/drift: none, tail subtraction, local detrend';
    report_lines{end+1} = '- sampling/binning: downsample x2, x4, and x2 + minimal smoothing (movmedian 5)';
    report_lines{end+1} = '';
    report_lines{end+1} = '## Interpretation Rule Outcome';
    report_lines{end+1} = ['- Classification: ' interpretation_class];
    report_lines{end+1} = '';
    report_lines{end+1} = '## Short Summary';
    for i = 1:numel(summary_lines)
        report_lines{end+1} = summary_lines{i};
    end
    report_lines{end+1} = '';
    report_lines{end+1} = '## Verdict Block';
    for i = 1:numel(verdict_block)
        report_lines{end+1} = verdict_block{i};
    end
    report_text = strjoin(report_lines, newline);

    execution_status = 'SUCCESS';

catch ME
    execution_status = 'FAILED';
    error_message = char(string(ME.message));

    rows_main = {
        'meta', 'meta', 'meta', 'meta', 'execution_failed', ...
        0, 0, 0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, 'NO', 'NO', 'NO', error_message};

    rows_status = {
        'AGING_OBSERVABLE_DEFINED','NO','execution_failed',error_message;
        'AGING_OBSERVABLE_PHYSICAL','NO','execution_failed',error_message;
        'AGING_T0_STABLE','NO','execution_failed',error_message;
        'AGING_WINDOW_STABLE','NO','execution_failed',error_message;
        'AGING_NORMALIZATION_STABLE','NO','execution_failed',error_message;
        'AGING_BASELINE_STABLE','NO','execution_failed',error_message;
        'AGING_SAMPLING_STABLE','NO','execution_failed',error_message;
        'AGING_TRACE_STRUCTURE_STABLE','NO','execution_failed',error_message};

    report_text = strjoin({
        '# Aging Measurement Definition Audit';
        '';
        '## Execution Status';
        ['- EXECUTION_STATUS: ' execution_status];
        ['- INPUT_FOUND: ' input_found];
        ['- ERROR_MESSAGE: ' error_message];
        '';
        '## Verdict Block';
        'AGING_OBSERVABLE_DEFINED=NO';
        'AGING_OBSERVABLE_PHYSICAL=NO';
        '';
        'AGING_T0_STABLE=NO';
        'AGING_WINDOW_STABLE=NO';
        'AGING_NORMALIZATION_STABLE=NO';
        'AGING_BASELINE_STABLE=NO';
        'AGING_SAMPLING_STABLE=NO';
        '';
        'AGING_TRACE_STRUCTURE_STABLE=NO'}, newline);
end

writecell([header_main; rows_main], main_table_root);
writecell([header_status; rows_status], status_table_root);

fid_report_root = fopen(report_root, 'w');
if fid_report_root >= 0
    fprintf(fid_report_root, '%s\n', report_text);
    fclose(fid_report_root);
end

run_main = fullfile(run_dir, 'tables', 'aging_measurement_definition_audit.csv');
run_status = fullfile(run_dir, 'tables', 'aging_measurement_definition_audit_status.csv');
run_report = fullfile(run_dir, 'reports', 'aging_measurement_definition_audit.md');

writecell([header_main; rows_main], run_main);
writecell([header_status; rows_status], run_status);

fid_report_run = fopen(run_report, 'w');
if fid_report_run >= 0
    fprintf(fid_report_run, '%s\n', report_text);
    fclose(fid_report_run);
end

exec_header = {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE'};
exec_data = {execution_status, input_found, error_message};
writecell([exec_header; exec_data], fullfile(run_dir, 'execution_status.csv'));

fprintf('AGING_MEASUREMENT_DEFINITION_AUDIT_STATUS=%s\n', execution_status);
fprintf('INPUT_FOUND=%s\n', input_found);
fprintf('ERROR_MESSAGE=%s\n', error_message);
fprintf('MAIN_TABLE_PATH=%s\n', main_table_root);
fprintf('STATUS_TABLE_PATH=%s\n', status_table_root);
fprintf('REPORT_PATH=%s\n', report_root);

if strcmp(execution_status, 'FAILED')
    error('aging_measurement_definition_audit_failed:%s', error_message);
end

function variants = buildVariants()
variants = struct( ...
    'id', {}, 'label', {}, 'axis', {}, 'choice', {}, 'is_baseline', {}, ...
    't0_shift_tau', {}, 'win_start_mult', {}, 'win_end_mult', {}, ...
    'normalization_mode', {}, 'baseline_mode', {}, 'downsample_factor', {}, 'smooth_span', {});

variants(end+1) = makeVariant('variant_01', 'baseline_canonical', 'baseline', 'canonical_default', true, 0.0, 1.0, 1.0, 'none', 'none', 1, 1);
variants(end+1) = makeVariant('variant_02', 't0_minus_dt', 't0', 't0_shift=-tau_min', false, -1.0, 1.0, 1.0, 'none', 'none', 1, 1);
variants(end+1) = makeVariant('variant_03', 't0_plus_dt', 't0', 't0_shift=+tau_min', false, +1.0, 1.0, 1.0, 'none', 'none', 1, 1);
variants(end+1) = makeVariant('variant_04', 'window_start_earlier', 'window', 'window_start=0.5*tau_min', false, 0.0, 0.5, 1.0, 'none', 'none', 1, 1);
variants(end+1) = makeVariant('variant_05', 'window_start_later', 'window', 'window_start=1.5*tau_min', false, 0.0, 1.5, 1.0, 'none', 'none', 1, 1);
variants(end+1) = makeVariant('variant_06', 'window_end_earlier', 'window', 'window_end=0.8*canonical_end', false, 0.0, 1.0, 0.8, 'none', 'none', 1, 1);
variants(end+1) = makeVariant('variant_07', 'window_end_later', 'window', 'window_end=1.2*canonical_end', false, 0.0, 1.0, 1.2, 'none', 'none', 1, 1);
variants(end+1) = makeVariant('variant_08', 'normalization_initial_amplitude', 'normalization', 'y/y0', false, 0.0, 1.0, 1.0, 'initial_amplitude', 'none', 1, 1);
variants(end+1) = makeVariant('variant_09', 'normalization_tail_referenced', 'normalization', '(y-y_end)/(y0-y_end)', false, 0.0, 1.0, 1.0, 'tail_referenced', 'none', 1, 1);
variants(end+1) = makeVariant('variant_10', 'baseline_tail_subtracted', 'baseline', 'y - mean(last10%)', false, 0.0, 1.0, 1.0, 'none', 'tail_subtract', 1, 1);
variants(end+1) = makeVariant('variant_11', 'baseline_local_detrend', 'baseline', 'local linear detrend on last20%', false, 0.0, 1.0, 1.0, 'none', 'local_detrend', 1, 1);
variants(end+1) = makeVariant('variant_12', 'sampling_downsample_x2', 'sampling', 'downsample x2', false, 0.0, 1.0, 1.0, 'none', 'none', 2, 1);
variants(end+1) = makeVariant('variant_13', 'sampling_downsample_x4', 'sampling', 'downsample x4', false, 0.0, 1.0, 1.0, 'none', 'none', 4, 1);
variants(end+1) = makeVariant('variant_14', 'sampling_downsample_x2_smooth5', 'sampling', 'downsample x2 + movmedian(5)', false, 0.0, 1.0, 1.0, 'none', 'none', 2, 5);
end

function v = makeVariant(id, label, axis, choice, is_baseline, t0_shift_tau, win_start_mult, win_end_mult, normalization_mode, baseline_mode, downsample_factor, smooth_span)
v = struct();
v.id = id;
v.label = label;
v.axis = axis;
v.choice = choice;
v.is_baseline = is_baseline;
v.t0_shift_tau = t0_shift_tau;
v.win_start_mult = win_start_mult;
v.win_end_mult = win_end_mult;
v.normalization_mode = normalization_mode;
v.baseline_mode = baseline_mode;
v.downsample_factor = downsample_factor;
v.smooth_span = smooth_span;
end

function out = extractCanonicalObservableVariant(t_in, h_in, m_in, variant, have_robustfit)
out = struct('supported', false, 'fail_reason', 'UNSET', ...
    'observable', NaN, 't0_used', NaN, 't_start', NaN, 't_end', NaN, ...
    'trace_x', [], 'trace_y', []);

if ~have_robustfit
    out.fail_reason = 'MISSING_ROBUSTFIT';
    return;
end

t = t_in(:);
h = h_in(:);
m = m_in(:);
n0 = min([numel(t), numel(h), numel(m)]);
t = t(1:n0);
h = h(1:n0);
m = m(1:n0);

ok = isfinite(t) & isfinite(h) & isfinite(m);
t = t(ok);
h = h(ok);
m = m(ok);
if numel(t) < 40
    out.fail_reason = 'TOO_FEW_POINTS';
    return;
end

[t, ix] = sort(t, 'ascend');
h = h(ix);
m = m(ix);
[t, iu] = unique(t, 'stable');
h = h(iu);
m = m(iu);
if numel(t) < 40
    out.fail_reason = 'TOO_FEW_UNIQUE_POINTS';
    return;
end

if variant.downsample_factor > 1
    idx_ds = 1:variant.downsample_factor:numel(t);
    t = t(idx_ds);
    h = h(idx_ds);
    m = m(idx_ds);
end
if numel(t) < 40
    out.fail_reason = 'TOO_FEW_AFTER_DOWNSAMPLE';
    return;
end

if variant.smooth_span > 1
    span = max(3, round(variant.smooth_span));
    if mod(span, 2) == 0
        span = span + 1;
    end
    span = min(span, max(3, numel(m) - mod(numel(m)+1, 2)));
    if span >= 3
        m = movmedian(m, span);
    end
end

[m, ok_base] = applyBaselineMode(t, m, variant.baseline_mode);
if ~ok_base
    out.fail_reason = 'BASELINE_MODE_FAILED';
    return;
end

n = numel(t);
w = max(5, ceil(0.05 * n));
if n < (w + 5)
    out.fail_reason = 'TRACE_TOO_SHORT_FOR_CANONICAL_WINDOWS';
    return;
end

dHdt = gradient(h, t);
dMdt = gradient(m, t);
d2Mdt2 = gradient(dMdt, t);

tail_start = max(1, n - floor(0.20 * n) + 1);
tail_idx = tail_start:n;

sigma_Hdot = 1.4826 * mad(dHdt(tail_idx), 1);
if ~isfinite(sigma_Hdot) || sigma_Hdot <= 0
    sigma_Hdot = std(dHdt(tail_idx), 'omitnan') + eps;
end
sigma_Mddot = 1.4826 * mad(d2Mdt2(tail_idx), 1);
if ~isfinite(sigma_Mddot) || sigma_Mddot <= 0
    sigma_Mddot = std(d2Mdt2(tail_idx), 'omitnan') + eps;
end

Q = max(abs(dHdt) ./ (sigma_Hdot + eps), abs(d2Mdt2) ./ (sigma_Mddot + eps));

idx_t0 = NaN;
for j = 1:(n - w + 1)
    qwin = Q(j:(j + w - 1));
    dwin = dMdt(j:(j + w - 1));
    sign_constant = ~(any(dwin > 0) && any(dwin < 0));
    if median(qwin, 'omitnan') <= 3 && sign_constant
        idx_t0 = j;
        break;
    end
end
if ~isfinite(idx_t0)
    out.fail_reason = 'NO_T0_FOUND';
    return;
end

t0_base = t(idx_t0);
post_idx = find(t > t0_base);
if numel(post_idx) < 3
    out.fail_reason = 'NO_POST_T0_POINTS';
    return;
end

n_post_tau = min(w, numel(post_idx));
tau_min = median(diff(t(post_idx(1:n_post_tau))), 'omitnan');
if ~isfinite(tau_min) || tau_min <= 0
    out.fail_reason = 'INVALID_TAU_MIN';
    return;
end

t0 = t0_base + variant.t0_shift_tau * tau_min;
t0 = max(t0, t(1) + eps);
if t0 >= t(end)
    out.fail_reason = 'SHIFTED_T0_OUT_OF_RANGE';
    return;
end

idx_after_t0 = find(t > t0);
if numel(idx_after_t0) < (w + 2)
    out.fail_reason = 'POST_T0_WINDOW_TOO_SHORT';
    return;
end

tau = t(idx_after_t0) - t0;
m_post = m(idx_after_t0);
ln_tau = log(tau);
n_tau = numel(tau);

R_local = nan(n_tau, 1);
for j = 1:(n_tau - w + 1)
    jw = j:(j + w - 1);
    xw = ln_tau(jw);
    yw = m_post(jw);
    if numel(unique(xw)) < 2
        continue;
    end
    b = robustfit(xw, yw, 'huber', 1.345);
    R_local(j) = -b(2);
end

valid_R = find(isfinite(R_local));
if numel(valid_R) < w
    out.fail_reason = 'INSUFFICIENT_LOCAL_R';
    return;
end

tail_R_start = max(valid_R(1), valid_R(end) - ceil(0.2 * numel(valid_R)) + 1);
tail_R_idx = tail_R_start:valid_R(end);
R_tail = R_local(tail_R_idx);
sigma_R_tail = 1.4826 * mad(R_tail, 1);
if ~isfinite(sigma_R_tail) || sigma_R_tail <= 0
    sigma_R_tail = std(R_tail, 'omitnan') + eps;
end

R_ref = median(R_local(valid_R), 'omitnan');
ref_sign = sign(R_ref);
if ref_sign == 0
    ref_sign = 1;
end

idx_end_tau = NaN;
for j = valid_R(:)'
    jl = max(valid_R(1), j - w + 1);
    medR = median(R_local(jl:j), 'omitnan');
    sign_ok = (sign(medR) == ref_sign) || (sign(medR) == 0);
    if sign_ok && (abs(medR) >= 3 * sigma_R_tail)
        idx_end_tau = j;
    end
end
if ~isfinite(idx_end_tau)
    out.fail_reason = 'NO_VALID_END_RULE';
    return;
end

tau_end_base = tau(idx_end_tau);
tau_start = max(eps, variant.win_start_mult * tau_min);
tau_end = min(tau(end), variant.win_end_mult * tau_end_base);
if ~(isfinite(tau_start) && isfinite(tau_end) && tau_end > tau_start)
    out.fail_reason = 'INVALID_WINDOW_AFTER_PERTURB';
    return;
end

fit_idx = find((tau >= tau_start) & (tau <= tau_end));
if numel(fit_idx) < w
    out.fail_reason = 'FIT_WINDOW_TOO_SHORT';
    return;
end

x_fit = log(tau(fit_idx));
y_fit = m_post(fit_idx);

[y_fit, ok_norm] = applyNormalizationMode(y_fit, variant.normalization_mode);
if ~ok_norm
    out.fail_reason = 'NORMALIZATION_FAILED';
    return;
end

if numel(unique(x_fit)) < 2 || any(~isfinite(x_fit)) || any(~isfinite(y_fit))
    out.fail_reason = 'DEGENERATE_FIT_SUPPORT';
    return;
end

b_fit = robustfit(x_fit, y_fit, 'huber', 1.345);
R_canonical = -b_fit(2);
if ~isfinite(R_canonical)
    out.fail_reason = 'NONFINITE_OBSERVABLE';
    return;
end

out.supported = true;
out.fail_reason = 'OK';
out.observable = R_canonical;
out.t0_used = t0;
out.t_start = t0 + tau_start;
out.t_end = t0 + tau_end;
out.trace_x = log10(tau(fit_idx));
out.trace_y = y_fit;
end

function [y, ok] = applyBaselineMode(t, y, mode)
ok = true;
mode = char(string(mode));
switch mode
    case 'none'
        return;
    case 'tail_subtract'
        n = numel(y);
        n_tail = max(5, round(0.10 * n));
        if n_tail >= n
            ok = false;
            return;
        end
        y = y - mean(y(end - n_tail + 1:end), 'omitnan');
    case 'local_detrend'
        n = numel(y);
        n_tail = max(8, round(0.20 * n));
        if n_tail >= n
            ok = false;
            return;
        end
        xt = t(end - n_tail + 1:end);
        yt = y(end - n_tail + 1:end);
        ok2 = isfinite(xt) & isfinite(yt);
        if nnz(ok2) < 3
            ok = false;
            return;
        end
        p = polyfit(xt(ok2), yt(ok2), 1);
        y = y - polyval(p, t);
    otherwise
        ok = false;
end
end

function [y, ok] = applyNormalizationMode(y, mode)
ok = true;
mode = char(string(mode));
switch mode
    case 'none'
        return;
    case 'initial_amplitude'
        den = y(1);
        if ~isfinite(den) || abs(den) < 1e-12
            ok = false;
            return;
        end
        y = y ./ den;
    case 'tail_referenced'
        den = y(1) - y(end);
        if ~isfinite(den) || abs(den) < 1e-12
            ok = false;
            return;
        end
        y = (y - y(end)) ./ den;
    otherwise
        ok = false;
end
end

function tm = compareTraceShapes(xb, yb, xv, yv)
tm = struct('trace_corr', NaN, 'trace_nrmse', NaN, 'shape_corr', NaN, 'trend_distortion', NaN, 'low_frequency_bias', NaN);

if isempty(xb) || isempty(yb) || isempty(xv) || isempty(yv)
    return;
end

xb = xb(:);
yb = yb(:);
xv = xv(:);
yv = yv(:);
okb = isfinite(xb) & isfinite(yb);
okv = isfinite(xv) & isfinite(yv);
xb = xb(okb);
yb = yb(okb);
xv = xv(okv);
yv = yv(okv);
if numel(xb) < 6 || numel(xv) < 6
    return;
end

[xb, ib] = unique(xb, 'stable');
yb = yb(ib);
[xv, iv] = unique(xv, 'stable');
yv = yv(iv);
if numel(xb) < 6 || numel(xv) < 6
    return;
end

xmin = max(min(xb), min(xv));
xmax = min(max(xb), max(xv));
if ~(isfinite(xmin) && isfinite(xmax) && (xmax > xmin))
    return;
end

xc = linspace(xmin, xmax, 120);
yb_i = interp1(xb, yb, xc, 'linear', NaN);
yv_i = interp1(xv, yv, xc, 'linear', NaN);
ok = isfinite(yb_i) & isfinite(yv_i);
if nnz(ok) < 40
    return;
end

xc = xc(ok);
yb_i = yb_i(ok);
yv_i = yv_i(ok);

tm.trace_corr = safePearsonCorr(yb_i, yv_i);

rmsv = sqrt(mean((yv_i - yb_i).^2, 'omitnan'));
den = max(max(yb_i) - min(yb_i), eps);
tm.trace_nrmse = rmsv / den;

db = gradient(yb_i, xc);
dv = gradient(yv_i, xc);
tm.shape_corr = safePearsonCorr(db, dv);

pb = polyfit(xc, yb_i, 1);
pv = polyfit(xc, yv_i, 1);
tm.trend_distortion = abs(pv(1) - pb(1)) / max(abs(pb(1)), eps);

lb = movmean(yb_i, 11);
lv = movmean(yv_i, 11);
tm.low_frequency_bias = median(abs(lv - lb), 'omitnan') / max(max(lb) - min(lb), eps);
end

function c = safePearsonCorr(x, y)
c = NaN;
x = x(:);
y = y(:);
ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);
if numel(x) < 3
    return;
end
cc = corrcoef(x, y);
if numel(cc) >= 4
    c = cc(1, 2);
end
end

function rho = spearmanCorr(x, y)
rho = NaN;
x = x(:);
y = y(:);
ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);
if numel(x) < 3
    return;
end
rx = simpleRank(x);
ry = simpleRank(y);
rho = safePearsonCorr(rx, ry);
end

function tau = kendallTau(x, y)
tau = NaN;
x = x(:);
y = y(:);
ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);
n = numel(x);
if n < 3
    return;
end

concordant = 0;
discordant = 0;
for i = 1:(n - 1)
    for j = (i + 1):n
        dx = x(j) - x(i);
        dy = y(j) - y(i);
        s = sign(dx) * sign(dy);
        if s > 0
            concordant = concordant + 1;
        elseif s < 0
            discordant = discordant + 1;
        end
    end
end
den = 0.5 * n * (n - 1);
if den > 0
    tau = (concordant - discordant) / den;
end
end

function r = simpleRank(x)
[sx, ord] = sort(x, 'ascend');
r = zeros(size(x));
n = numel(x);
k = 1;
while k <= n
    j = k;
    while j < n && sx(j + 1) == sx(k)
        j = j + 1;
    end
    rk = 0.5 * (k + j);
    r(ord(k:j)) = rk;
    k = j + 1;
end
r = r(:);
end

function txt = aggregateFailNotes(fail_row)
vals = string(fail_row);
vals = vals(vals ~= "");
vals = vals(vals ~= "OK");
if isempty(vals)
    txt = "all_supported";
    return;
end
u = unique(vals, 'stable');
parts = strings(numel(u), 1);
for i = 1:numel(u)
    parts(i) = sprintf('%s:%d', u(i), sum(vals == u(i)));
end
txt = strjoin(parts, ';');
end

function y = toYesNo(tf)
if islogical(tf)
    if tf
        y = 'YES';
    else
        y = 'NO';
    end
elseif isnumeric(tf)
    if isfinite(tf) && tf ~= 0
        y = 'YES';
    else
        y = 'NO';
    end
else
    if strcmpi(char(string(tf)), 'true') || strcmpi(char(string(tf)), 'yes')
        y = 'YES';
    else
        y = 'NO';
    end
end
end


