clear; clc;

repo_root = 'C:\Dev\matlab-functions';
script_abs = 'C:\Dev\matlab-functions\Relaxation ver3\diagnostics\run_relaxation_measurement_robustness_audit_script.m';
data_dir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM';
run_label = 'relaxation_measurement_robustness_audit';

run_id = ['run_' datestr(now,'yyyy_mm_dd_HHMMSS') '_' run_label];
run_dir = fullfile(repo_root, 'results', 'relaxation', 'runs', run_id);
if exist(run_dir, 'dir') ~= 7
    mkdir(run_dir);
end
if exist(fullfile(run_dir, 'tables'), 'dir') ~= 7
    mkdir(fullfile(run_dir, 'tables'));
end
if exist(fullfile(run_dir, 'reports'), 'dir') ~= 7
    mkdir(fullfile(run_dir, 'reports'));
end
if exist(fullfile(repo_root, 'tables'), 'dir') ~= 7
    mkdir(fullfile(repo_root, 'tables'));
end
if exist(fullfile(repo_root, 'reports'), 'dir') ~= 7
    mkdir(fullfile(repo_root, 'reports'));
end

ptr_file = ['run_dir_pointer' char(46) 'txt'];
ptr_id = fopen(fullfile(repo_root, ptr_file), 'w');
if ptr_id >= 0
    fprintf(ptr_id, '%s', run_dir);
    fclose(ptr_id);
end

execution_status = 'FAILED';
input_found = 'NO';
error_message = '';
main_result_summary = 'not_run';
n_files = 0;

header_summary = {'row_type','variant_label','axis','choice','supported','n_traces','signal_corr_median','nrmse_median','nrmse_worst','slope_corr_median','curvature_corr_median','amplitude_scale','t_half_s','mean_log_slope','rel_change_amplitude','rel_change_t_half','rel_change_mean_log_slope','temp_of_max_sensitivity_K','max_temp_nrmse','notes'};
summary_rows = {'meta','meta','meta','meta','NO',0,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,'not_run'};

header_status = {'verdict','value','criterion','evidence'};
status_rows = {
    'RELAXATION_MEASUREMENT_STABLE','NO','pending','not_executed';
    'T0_SENSITIVE','NO','pending','not_executed';
    'WINDOW_SENSITIVE','NO','pending','not_executed';
    'BASELINE_SENSITIVE','NO','pending','not_executed';
    'NORMALIZATION_SENSITIVE','NO','pending','not_executed';
    'SMOOTHING_SENSITIVE','NO','pending','not_executed';
    'RELAXATION_OBSERVABLE_PHYSICAL','NO','pending','not_executed';
    'SAFE_TO_PROCEED_TO_PARAMETER_ROBUSTNESS','NO','pending','not_executed'};

report_text = '# Relaxation Measurement Robustness Audit';

try
    addpath(fullfile(repo_root, 'Aging', 'utils'));
    addpath(fullfile(repo_root, 'Relaxation ver3'));

    if exist(data_dir, 'dir') ~= 7
        error('Raw data directory not found: %s', data_dir);
    end
    input_found = 'YES';

    run_cfg = struct();
    run_cfg.runLabel = run_label;
    run_cfg.dataset = data_dir;
    run_ctx = createRunContext('relaxation', run_cfg);
    if isfield(run_ctx, 'run_dir') && ~isempty(run_ctx.run_dir)
        run_dir = run_ctx.run_dir;
    end
    if isfield(run_ctx, 'run_id') && ~isempty(run_ctx.run_id)
        run_id = run_ctx.run_id;
    end
    if exist(fullfile(run_dir, 'tables'), 'dir') ~= 7
        mkdir(fullfile(run_dir, 'tables'));
    end
    if exist(fullfile(run_dir, 'reports'), 'dir') ~= 7
        mkdir(fullfile(run_dir, 'reports'));
    end

    ptr_id = fopen(fullfile(repo_root, ptr_file), 'w');
    if ptr_id >= 0
        fprintf(ptr_id, '%s', run_dir);
        fclose(ptr_id);
    end

    [fileList, temps, ~, ~, ~, ~] = getFileList_relaxation(data_dir, 'parula');
    [Time_table, Temp_table, ~, Moment_table, ~] = importFiles_relaxation(data_dir, fileList, true, false);

    n_files = numel(fileList);
    if n_files < 4
        error('Too few raw trace files for robustness audit: %d', n_files);
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

    variant_label = {'baseline_default','t0_post_settling','t0_delayed_conservative','window_early_heavy','window_late_trimmed','baseline_tail_subtracted','baseline_tail_linear_detrend','normalization_initial_amplitude','normalization_area_logtime','smoothing_default','smoothing_stronger'};
    variant_axis = {'baseline','t0','t0','window','window','baseline','baseline','normalization','normalization','smoothing','smoothing'};
    variant_choice = {'t0=earliest;window=full;baseline=raw;norm=none;smooth=none','t0=post_settling_10pct','t0=delayed_20pct','window=end70pct','window=end85pct','baseline=tail_subtract_last10pct','baseline=tail_linear_detrend_last20pct','norm=initial_amplitude','norm=area_over_logtime','smooth=moving_median_5','smooth=moving_median_11'};

    n_variants = numel(variant_label);
    min_points = 25;

    trace_x = cell(n_variants, n_files);
    trace_y = cell(n_variants, n_files);
    supported = false(n_variants, 1);
    notes = cell(n_variants, 1);

    amp_desc = nan(n_variants, 1);
    thalf_desc = nan(n_variants, 1);
    slope_desc = nan(n_variants, 1);
    monotonic_desc = nan(n_variants, 1);

    for v = 1:n_variants
        amp_row = nan(n_files, 1);
        thalf_row = nan(n_files, 1);
        slope_row = nan(n_files, 1);
        neg_slope_row = false(n_files, 1);
        valid_row = false(n_files, 1);

        for i = 1:n_files
            if i > numel(Time_table) || i > numel(Moment_table)
                continue;
            end
            if isempty(Time_table{i}) || isempty(Moment_table{i})
                continue;
            end

            t = Time_table{i}(:);
            y = Moment_table{i}(:);
            ok = isfinite(t) & isfinite(y);
            t = t(ok);
            y = y(ok);
            if numel(t) < 40
                continue;
            end

            [t, ix] = sort(t, 'ascend');
            y = y(ix);
            [t, iu] = unique(t, 'stable');
            y = y(iu);
            if numel(t) < 40
                continue;
            end

            if strcmp(variant_label{v}, 'smoothing_default')
                y = movmedian(y, 5);
            elseif strcmp(variant_label{v}, 'smoothing_stronger')
                y = movmedian(y, 11);
            end

            i0 = 1;
            if strcmp(variant_label{v}, 't0_post_settling')
                i0 = 1 + floor(0.10 * (numel(t) - 1));
            elseif strcmp(variant_label{v}, 't0_delayed_conservative')
                i0 = 1 + floor(0.20 * (numel(t) - 1));
            end
            t = t(i0:end);
            y = y(i0:end);

            trel = t - t(1);
            keep = trel > 0;
            trel = trel(keep);
            y = y(keep);
            if numel(trel) < min_points
                continue;
            end

            iend = numel(trel);
            if strcmp(variant_label{v}, 'window_early_heavy')
                iend = max(min_points, floor(0.70 * numel(trel)));
            elseif strcmp(variant_label{v}, 'window_late_trimmed')
                iend = max(min_points, floor(0.85 * numel(trel)));
            end
            trel = trel(1:iend);
            y = y(1:iend);
            if numel(trel) < min_points
                continue;
            end

            x = log10(trel);

            if strcmp(variant_label{v}, 'baseline_tail_subtracted')
                n_tail = max(5, round(0.10 * numel(y)));
                y = y - mean(y(end-n_tail+1:end), 'omitnan');
            elseif strcmp(variant_label{v}, 'baseline_tail_linear_detrend')
                n_tail = max(8, round(0.20 * numel(y)));
                xt = x(end-n_tail+1:end);
                yt = y(end-n_tail+1:end);
                ok2 = isfinite(xt) & isfinite(yt);
                if nnz(ok2) < 3
                    continue;
                end
                p = polyfit(xt(ok2), yt(ok2), 1);
                y = y - polyval(p, x);
            end

            if strcmp(variant_label{v}, 'normalization_initial_amplitude')
                den = y(1) - y(end);
                if abs(den) < 1e-12
                    continue;
                end
                y = y ./ den;
            elseif strcmp(variant_label{v}, 'normalization_area_logtime')
                den = trapz(x, abs(y));
                if abs(den) < 1e-12
                    continue;
                end
                y = y ./ den;
            end

            if any(~isfinite(x)) || any(~isfinite(y)) || numel(x) < min_points
                continue;
            end

            trace_x{v, i} = x(:)';
            trace_y{v, i} = y(:)';

            amp_row(i) = y(1) - y(end);
            slope_local = gradient(y, x);
            slope_row(i) = mean(slope_local, 'omitnan');
            neg_slope_row(i) = slope_row(i) < 0;

            denh = y(1) - y(end);
            if abs(denh) >= 1e-12
                yn = (y - y(end)) ./ denh;
                j = find(yn(1:end-1) >= 0.5 & yn(2:end) <= 0.5, 1, 'first');
                if ~isempty(j)
                    x1 = x(j);
                    x2 = x(j+1);
                    y1 = yn(j) - 0.5;
                    y2 = yn(j+1) - 0.5;
                    if abs(y2 - y1) < eps
                        xh = 0.5 * (x1 + x2);
                    else
                        xh = x1 - y1 * (x2 - x1) / (y2 - y1);
                    end
                    thalf_row(i) = 10.^xh;
                end
            end

            valid_row(i) = true;
        end

        if nnz(valid_row) >= 4
            supported(v) = true;
            amp_desc(v) = median(abs(amp_row(valid_row)), 'omitnan');
            thalf_desc(v) = median(thalf_row(valid_row), 'omitnan');
            slope_desc(v) = median(slope_row(valid_row), 'omitnan');
            monotonic_desc(v) = mean(neg_slope_row(valid_row));
            notes{v} = sprintf('ok;valid_traces=%d', nnz(valid_row));
        else
            notes{v} = sprintf('unsupported;valid_traces=%d', nnz(valid_row));
        end
    end

    if ~supported(1)
        error('Baseline variant unsupported from raw traces.');
    end

    corr_med = nan(n_variants, 1);
    nrmse_med = nan(n_variants, 1);
    nrmse_max = nan(n_variants, 1);
    slope_corr_med = nan(n_variants, 1);
    curv_corr_med = nan(n_variants, 1);
    rel_amp = nan(n_variants, 1);
    rel_thalf = nan(n_variants, 1);
    rel_slope = nan(n_variants, 1);
    per_trace_nrmse = nan(n_variants, n_files);

    for v = 1:n_variants
        if ~supported(v)
            continue;
        end

        if v == 1
            corr_med(v) = 1;
            nrmse_med(v) = 0;
            nrmse_max(v) = 0;
            slope_corr_med(v) = 1;
            curv_corr_med(v) = 1;
            per_trace_nrmse(v, :) = 0;
            continue;
        end

        corr_vals = nan(n_files, 1);
        nrmse_vals = nan(n_files, 1);
        slope_vals = nan(n_files, 1);
        curv_vals = nan(n_files, 1);

        for i = 1:n_files
            xb = trace_x{1, i};
            yb = trace_y{1, i};
            xv = trace_x{v, i};
            yv = trace_y{v, i};
            if isempty(xb) || isempty(yb) || isempty(xv) || isempty(yv)
                continue;
            end

            xmin = max(min(xb), min(xv));
            xmax = min(max(xb), max(xv));
            if ~(isfinite(xmin) && isfinite(xmax) && xmax > xmin)
                continue;
            end

            xc = linspace(xmin, xmax, 120);
            ybc = interp1(xb, yb, xc, 'linear', NaN);
            yvc = interp1(xv, yv, xc, 'linear', NaN);
            ok = isfinite(ybc) & isfinite(yvc);
            if nnz(ok) < 30
                continue;
            end
            xc = xc(ok);
            ybc = ybc(ok);
            yvc = yvc(ok);

            cc = corrcoef(ybc, yvc);
            if numel(cc) >= 4
                corr_vals(i) = cc(1, 2);
            end

            rms_val = sqrt(mean((yvc - ybc).^2, 'omitnan'));
            den = max(max(ybc) - min(ybc), eps);
            nrmse_vals(i) = rms_val / den;
            per_trace_nrmse(v, i) = nrmse_vals(i);

            sb = gradient(ybc, xc);
            sv = gradient(yvc, xc);
            cs = corrcoef(sb, sv);
            if numel(cs) >= 4
                slope_vals(i) = cs(1, 2);
            end

            cb = gradient(sb, xc);
            cv = gradient(sv, xc);
            ck = corrcoef(cb, cv);
            if numel(ck) >= 4
                curv_vals(i) = ck(1, 2);
            end
        end

        corr_med(v) = median(corr_vals, 'omitnan');
        nrmse_med(v) = median(nrmse_vals, 'omitnan');
        nrmse_max(v) = max(nrmse_vals, [], 'omitnan');
        slope_corr_med(v) = median(slope_vals, 'omitnan');
        curv_corr_med(v) = median(curv_vals, 'omitnan');
    end

    base_amp = amp_desc(1);
    base_thalf = thalf_desc(1);
    base_slope = slope_desc(1);

    for v = 1:n_variants
        if supported(v)
            rel_amp(v) = abs(amp_desc(v) - base_amp) / max(abs(base_amp), eps);
            rel_thalf(v) = abs(thalf_desc(v) - base_thalf) / max(abs(base_thalf), eps);
            rel_slope(v) = abs(slope_desc(v) - base_slope) / max(abs(base_slope), eps);
        end
    end

    axes_list = {'t0','window','baseline','normalization','smoothing'};
    axis_sensitive = false(1, 5);
    axis_med_nrmse = nan(1, 5);
    axis_max_nrmse = nan(1, 5);
    axis_med_corr = nan(1, 5);
    axis_med_drift = nan(1, 5);
    axis_temp = nan(1, 5);
    axis_temp_nrmse = nan(1, 5);

    for a = 1:5
        idx = find(strcmp(variant_axis, axes_list{a}));

        axis_med_nrmse(a) = median(nrmse_med(idx), 'omitnan');
        axis_max_nrmse(a) = max(nrmse_max(idx), [], 'omitnan');
        axis_med_corr(a) = median(corr_med(idx), 'omitnan');
        drift_vec = max([rel_amp(idx), rel_thalf(idx), rel_slope(idx)], [], 2);
        axis_med_drift(a) = median(drift_vec, 'omitnan');

        temp_vec = nan(1, n_files);
        for i = 1:n_files
            temp_vec(i) = median(per_trace_nrmse(idx, i), 'omitnan');
        end
        [mx, imx] = max(temp_vec, [], 'omitnan');
        axis_temp_nrmse(a) = mx;
        if ~isempty(imx) && isfinite(imx)
            axis_temp(a) = T_nom(imx);
        end

        axis_sensitive(a) = (axis_med_nrmse(a) > 0.08) || (axis_max_nrmse(a) > 0.15) || (axis_med_corr(a) < 0.95) || (axis_med_drift(a) > 0.20);
    end

    overall_med_nrmse = median(nrmse_med(2:end), 'omitnan');
    overall_max_nrmse = max(nrmse_max(2:end), [], 'omitnan');
    overall_med_corr = median(corr_med(2:end), 'omitnan');

    stable = (~any(axis_sensitive)) && (overall_med_nrmse <= 0.08) && (overall_max_nrmse <= 0.15) && (overall_med_corr >= 0.95);
    physical = stable && isfinite(base_amp) && (base_amp > 0) && isfinite(base_thalf) && (base_thalf > 0) && isfinite(base_slope) && (base_slope < 0) && isfinite(monotonic_desc(1)) && (monotonic_desc(1) >= 0.70);
    safe = physical && all(supported(2:end));

    rows = cell(n_variants + 5, 20);
    for v = 1:n_variants
        rows(v, :) = {'variant', variant_label{v}, variant_axis{v}, variant_choice{v}, char(string(supported(v))), n_files, corr_med(v), nrmse_med(v), nrmse_max(v), slope_corr_med(v), curv_corr_med(v), amp_desc(v), thalf_desc(v), slope_desc(v), rel_amp(v), rel_thalf(v), rel_slope(v), NaN, NaN, notes{v}};
    end
    for a = 1:5
        r = n_variants + a;
        rows(r, :) = {'axis_summary', ['axis_' axes_list{a}], axes_list{a}, 'aggregate', 'YES', n_files, axis_med_corr(a), axis_med_nrmse(a), axis_max_nrmse(a), NaN, NaN, NaN, NaN, NaN, axis_med_drift(a), NaN, NaN, axis_temp(a), axis_temp_nrmse(a), char(string(axis_sensitive(a)))};
    end
    summary_rows = rows;

    status_rows = {
        'RELAXATION_MEASUREMENT_STABLE', char(string(stable)), 'overall thresholds', sprintf('median_nRMSE=%.4f; max_nRMSE=%.4f; median_corr=%.4f', overall_med_nrmse, overall_max_nrmse, overall_med_corr);
        'T0_SENSITIVE', char(string(axis_sensitive(1))), 'axis thresholds', sprintf('median_nRMSE=%.4f; max_nRMSE=%.4f; median_corr=%.4f', axis_med_nrmse(1), axis_max_nrmse(1), axis_med_corr(1));
        'WINDOW_SENSITIVE', char(string(axis_sensitive(2))), 'axis thresholds', sprintf('median_nRMSE=%.4f; max_nRMSE=%.4f; median_corr=%.4f', axis_med_nrmse(2), axis_max_nrmse(2), axis_med_corr(2));
        'BASELINE_SENSITIVE', char(string(axis_sensitive(3))), 'axis thresholds', sprintf('median_nRMSE=%.4f; max_nRMSE=%.4f; median_corr=%.4f', axis_med_nrmse(3), axis_max_nrmse(3), axis_med_corr(3));
        'NORMALIZATION_SENSITIVE', char(string(axis_sensitive(4))), 'axis thresholds', sprintf('median_nRMSE=%.4f; max_nRMSE=%.4f; median_corr=%.4f', axis_med_nrmse(4), axis_max_nrmse(4), axis_med_corr(4));
        'SMOOTHING_SENSITIVE', char(string(axis_sensitive(5))), 'axis thresholds', sprintf('median_nRMSE=%.4f; max_nRMSE=%.4f; median_corr=%.4f', axis_med_nrmse(5), axis_max_nrmse(5), axis_med_corr(5));
        'RELAXATION_OBSERVABLE_PHYSICAL', char(string(physical)), 'shape + descriptor checks', sprintf('amp=%.6g; t_half=%.6g; slope=%.6g; monotonic_fraction=%.3f', base_amp, base_thalf, base_slope, monotonic_desc(1));
        'SAFE_TO_PROCEED_TO_PARAMETER_ROBUSTNESS', char(string(safe)), 'physical + support checks', sprintf('physical=%s; all_nonbaseline_supported=%s', char(string(physical)), char(string(all(supported(2:end))))) };

    recommendation_line = 'Do not proceed to parameter robustness yet.';
    if safe
        recommendation_line = 'Proceed to parameter robustness.';
    end

    report_text = strjoin({
        '# Relaxation Measurement Robustness Audit';
        '';
        '## Audit Purpose';
        'Assess whether the relaxation observable is stable under measurement-definition choices using raw traces only.';
        '';
        '## Scripts And Inputs';
        ['- script: `' script_abs '`'];
        ['- dataDir: `' data_dir '`'];
        ['- trace_count: ' num2str(n_files)];
        ['- run_dir: `' run_dir '`'];
        '';
        '## Variant Definitions';
        '- t0: earliest valid start, post-settling 10%, delayed 20%';
        '- window: full usable, early-heavy end at 70%, late-trimmed end at 85%';
        '- baseline: raw, tail subtraction (last 10%), tail linear detrend (last 20%)';
        '- normalization: none, initial-amplitude, area-over-logtime';
        '- smoothing: none, moving median 5, moving median 11';
        '';
        '## Key Quantitative Results';
        ['- overall_median_corr: ' num2str(overall_med_corr, '%.4f')];
        ['- overall_median_nRMSE: ' num2str(overall_med_nrmse, '%.4f')];
        ['- overall_worst_nRMSE: ' num2str(overall_max_nrmse, '%.4f')];
        ['- baseline_amplitude_scale: ' num2str(base_amp, '%.6g')];
        ['- baseline_t_half_s: ' num2str(base_thalf, '%.6g')];
        ['- baseline_mean_log_slope: ' num2str(base_slope, '%.6g')];
        '';
        '## Interpretation';
        'Axis sensitivity is declared when median nRMSE is above 0.08, worst nRMSE above 0.15, median correlation below 0.95, or median descriptor drift above 20%.';
        '';
        '## Verdicts';
        ['- RELAXATION_MEASUREMENT_STABLE: ' char(string(stable))];
        ['- T0_SENSITIVE: ' char(string(axis_sensitive(1)))];
        ['- WINDOW_SENSITIVE: ' char(string(axis_sensitive(2)))];
        ['- BASELINE_SENSITIVE: ' char(string(axis_sensitive(3)))];
        ['- NORMALIZATION_SENSITIVE: ' char(string(axis_sensitive(4)))];
        ['- SMOOTHING_SENSITIVE: ' char(string(axis_sensitive(5)))];
        ['- RELAXATION_OBSERVABLE_PHYSICAL: ' char(string(physical))];
        ['- SAFE_TO_PROCEED_TO_PARAMETER_ROBUSTNESS: ' char(string(safe))];
        '';
        '## Recommendation';
        recommendation_line}, newline);

    execution_status = 'SUCCESS';
    main_result_summary = sprintf('stable=%s; physical=%s; safe=%s', char(string(stable)), char(string(physical)), char(string(safe)));

catch ME
    execution_status = 'FAILED';
    error_message = char(string(ME.message));
    main_result_summary = 'measurement_robustness_audit_failed';

    summary_rows = {'meta','meta','meta','meta','NO',n_files,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,error_message};
    status_rows = {
        'RELAXATION_MEASUREMENT_STABLE','NO','execution_failed',error_message;
        'T0_SENSITIVE','NO','execution_failed',error_message;
        'WINDOW_SENSITIVE','NO','execution_failed',error_message;
        'BASELINE_SENSITIVE','NO','execution_failed',error_message;
        'NORMALIZATION_SENSITIVE','NO','execution_failed',error_message;
        'SMOOTHING_SENSITIVE','NO','execution_failed',error_message;
        'RELAXATION_OBSERVABLE_PHYSICAL','NO','execution_failed',error_message;
        'SAFE_TO_PROCEED_TO_PARAMETER_ROBUSTNESS','NO','execution_failed',error_message};

    report_text = strjoin({
        '# Relaxation Measurement Robustness Audit';
        '';
        '## Execution Status';
        ['- EXECUTION_STATUS: ' execution_status];
        ['- INPUT_FOUND: ' input_found];
        ['- ERROR_MESSAGE: ' error_message];
        ['- MAIN_RESULT_SUMMARY: ' main_result_summary];
        ['- script: `' script_abs '`'];
        ['- dataDir: `' data_dir '`'];
        ['- run_dir: `' run_dir '`']}, newline);

    if false
        rethrow(ME);
    end
end

summary_root = fullfile(repo_root, 'tables', 'relaxation_measurement_robustness_summary.csv');
status_root = fullfile(repo_root, 'tables', 'relaxation_measurement_robustness_status.csv');
report_root = fullfile(repo_root, 'reports', 'relaxation_measurement_robustness_audit.md');

if exist(summary_root, 'file') == 2
    k = 2;
    while true
        candidate = fullfile(repo_root, 'tables', sprintf('relaxation_measurement_robustness_summary_v%d.csv', k));
        if exist(candidate, 'file') ~= 2
            summary_root = candidate;
            break;
        end
        k = k + 1;
    end
end
if exist(status_root, 'file') == 2
    k = 2;
    while true
        candidate = fullfile(repo_root, 'tables', sprintf('relaxation_measurement_robustness_status_v%d.csv', k));
        if exist(candidate, 'file') ~= 2
            status_root = candidate;
            break;
        end
        k = k + 1;
    end
end
if exist(report_root, 'file') == 2
    k = 2;
    while true
        candidate = fullfile(repo_root, 'reports', sprintf('relaxation_measurement_robustness_audit_v%d.md', k));
        if exist(candidate, 'file') ~= 2
            report_root = candidate;
            break;
        end
        k = k + 1;
    end
end

run_summary = fullfile(run_dir, 'relaxation_measurement_robustness_summary.csv');
run_status = fullfile(run_dir, 'relaxation_measurement_robustness_status.csv');
run_report = fullfile(run_dir, 'relaxation_measurement_robustness_audit.md');
run_summary_sub = fullfile(run_dir, 'tables', 'relaxation_measurement_robustness_summary.csv');
run_status_sub = fullfile(run_dir, 'tables', 'relaxation_measurement_robustness_status.csv');
run_report_sub = fullfile(run_dir, 'reports', 'relaxation_measurement_robustness_audit.md');

writecell([header_summary; summary_rows], summary_root);
writecell([header_status; status_rows], status_root);

fid_report_root = fopen(report_root, 'w');
if fid_report_root >= 0
    fprintf(fid_report_root, '%s\n', report_text);
    fclose(fid_report_root);
end

writecell([header_summary; summary_rows], run_summary);
writecell([header_status; status_rows], run_status);
writecell([header_summary; summary_rows], run_summary_sub);
writecell([header_status; status_rows], run_status_sub);

fid_report_run = fopen(run_report, 'w');
if fid_report_run >= 0
    fprintf(fid_report_run, '%s\n', report_text);
    fclose(fid_report_run);
end
fid_report_run_sub = fopen(run_report_sub, 'w');
if fid_report_run_sub >= 0
    fprintf(fid_report_run_sub, '%s\n', report_text);
    fclose(fid_report_run_sub);
end

exec_header = {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'};
exec_data = {execution_status, input_found, error_message, n_files, main_result_summary};
writecell([exec_header; exec_data], fullfile(run_dir, 'execution_status.csv'));

manifest = struct();
manifest.run_id = run_id;
manifest.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
manifest.execution_start = manifest.timestamp;
manifest.experiment = 'relaxation';
manifest.label = run_label;
manifest.repo_root = repo_root;
manifest.run_dir = run_dir;
manifest.script_path = script_abs;
manifest.dataset = data_dir;
manifest.outputs = {run_summary, run_status, run_report, fullfile(run_dir, 'execution_status.csv')};
manifest.manifest_valid = true;

fid_manifest = fopen(fullfile(run_dir, 'run_manifest.json'), 'w');
if fid_manifest >= 0
    fprintf(fid_manifest, '%s', jsonencode(manifest));
    fclose(fid_manifest);
end

fprintf('RELAXATION_MEASUREMENT_ROBUSTNESS_AUDIT_STATUS=%s\n', execution_status);
fprintf('INPUT_FOUND=%s\n', input_found);
fprintf('ERROR_MESSAGE=%s\n', error_message);
fprintf('MAIN_RESULT_SUMMARY=%s\n', main_result_summary);
fprintf('SUMMARY_TABLE_PATH=%s\n', summary_root);
fprintf('STATUS_TABLE_PATH=%s\n', status_root);
fprintf('REPORT_PATH=%s\n', report_root);
