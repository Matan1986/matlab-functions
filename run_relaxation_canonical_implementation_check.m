clear; clc;

% run_relaxation_canonical_implementation_check
% CLEAN CANONICAL SCRIPT  VALIDATOR COMPLIANT


try
    %% ===== 0. RUN CONTEXT =====
    run_ctx = createRunContext( ...
        'relaxation', ...
        'relaxation_canonical_implementation_check' ...
    );

    if isfield(run_ctx, 'tables') && ~isempty(run_ctx.tables)
        tables_dir = run_ctx.tables;
    elseif isfield(run_ctx, 'run_dir') && ~isempty(run_ctx.run_dir)
        tables_dir = fullfile(run_ctx.run_dir, 'tables');
    else
        tables_dir = fullfile(pwd, 'tables');
    end
    if exist(tables_dir, 'dir') ~= 7
        mkdir(tables_dir);
    end

    if isfield(run_ctx, 'reports') && ~isempty(run_ctx.reports)
        reports_dir = run_ctx.reports;
    elseif isfield(run_ctx, 'run_dir') && ~isempty(run_ctx.run_dir)
        reports_dir = fullfile(run_ctx.run_dir, 'reports');
    else
        reports_dir = fullfile(pwd, 'reports');
    end
    if exist(reports_dir, 'dir') ~= 7
        mkdir(reports_dir);
    end

    if isfield(run_ctx, 'figures') && ~isempty(run_ctx.figures)
        figures_dir = run_ctx.figures;
    elseif isfield(run_ctx, 'run_dir') && ~isempty(run_ctx.run_dir)
        figures_dir = fullfile(run_ctx.run_dir, 'figures');
    else
        figures_dir = fullfile(pwd, 'figures');
    end
    if exist(figures_dir, 'dir') ~= 7
        mkdir(figures_dir);
    end

    %% ===== 1. LOAD DATA =====
    data = load_relaxation_dataset();

    nT = numel(data.T_K);
    MAX_TRACE_EXPORTS = 3;
    MAX_POINTS_PER_TRACE = 500;
    SMALL_DELTA_THRESHOLD = 1e-6;
    n_trace_exports = min(nT, MAX_TRACE_EXPORTS);

    results = table();
    status_rows = {};

    trace_snapshot_rows = table();
    trace_summary_rows = table();

    delta_M_values = nan(nT, 1);
    above_small_threshold_flags = false(nT, 1);

    %% ===== 2. MAIN LOOP =====
    for i = 1:nT

        T = data.T_K(i);
        t = data.time{i};
        M = data.signal{i};

        if numel(t) < 5 || numel(M) < 5
            t0_found = false;
            reason = "FAIL_EMPTY_WINDOW";
        else
            dt = diff(t);
            dMdt = diff(M) ./ dt;

            sigma = std(dMdt, 'omitnan');
            threshold = 3 * sigma;

            idx = find(abs(dMdt) > threshold, 1, 'first');

            if isempty(idx)
                t0_found = false;
                reason = "NO_T0_FOUND";
            else
                t0_found = true;
                reason = "OK";
            end
        end

        results = [results; table(T, t0_found, string(reason))]; %#ok<AGROW>

        finite_mask = isfinite(t) & isfinite(M);
        t_trace = t(finite_mask);
        M_trace = M(finite_mask);

        if ~isempty(t_trace) && ~isempty(M_trace)
            n_points = numel(t_trace);
            min_M = min(M_trace);
            max_M = max(M_trace);
            delta_M = max_M - min_M;
            std_M = std(M_trace, 'omitnan');

            delta_M_values(i) = delta_M;
            above_small_threshold_flags(i) = (delta_M > SMALL_DELTA_THRESHOLD);

            summary_chunk = table( ...
                T, min_M, max_M, delta_M, std_M, n_points, ...
                'VariableNames', {'T_K', 'min_M', 'max_M', 'delta_M', 'std_M', 'n_points'});
            trace_summary_rows = [trace_summary_rows; summary_chunk]; %#ok<AGROW>

            if i <= n_trace_exports
                idx = round(linspace(1, numel(t_trace), min(MAX_POINTS_PER_TRACE, numel(t_trace))));
                t_sample = t_trace(idx);
                M_sample = M_trace(idx);
                n_sample = numel(t_sample);

                snapshot_chunk = table( ...
                    repmat(T, n_sample, 1), ...
                    t_sample(:), ...
                    M_sample(:), ...
                    'VariableNames', {'T_K', 'time', 'signal'});
                trace_snapshot_rows = [trace_snapshot_rows; snapshot_chunk]; %#ok<AGROW>

                t_tag = strrep(sprintf('%.3f', T), '.', 'p');

                fig_raw = figure('Visible', 'off');
                plot(t_trace, M_trace, 'LineWidth', 1.2);
                xlabel('time');
                ylabel('M(t)');
                title(sprintf('Relaxation trace T = %.3f K', T));
                grid on;
                saveas(fig_raw, fullfile(figures_dir, sprintf('trace_T_%s.png', t_tag)));
                close(fig_raw);

                t_log = log10(t_trace - t_trace(1) + eps);
                fig_log = figure('Visible', 'off');
                plot(t_log, M_trace, 'LineWidth', 1.2);
                xlabel('log10(time - time(1) + eps)');
                ylabel('M(t)');
                title(sprintf('Relaxation trace (log-time) T = %.3f K', T));
                grid on;
                saveas(fig_log, fullfile(figures_dir, sprintf('trace_log_T_%s.png', t_tag)));
                close(fig_log);
            end
        end

    end

    %% ===== 3. STATUS =====
    n_fail = sum(~results.t0_found);

    delta_M_valid = delta_M_values(isfinite(delta_M_values));
    if isempty(delta_M_valid)
        delta_M_mean = NaN;
        delta_M_min = NaN;
        pct_above_small = 0;
    else
        delta_M_mean = mean(delta_M_valid);
        delta_M_min = min(delta_M_valid);
        pct_above_small = 100 * mean(double(above_small_threshold_flags(isfinite(delta_M_values))));
    end

    if isempty(trace_summary_rows)
        trace_data_available = "NO";
        signal_variation_present = "NO";
    else
        trace_data_available = "YES";
        if any(above_small_threshold_flags(isfinite(delta_M_values)))
            signal_variation_present = "YES";
        else
            signal_variation_present = "NO";
        end
    end

    if isfinite(delta_M_mean)
        delta_M_mean_txt = sprintf('%.10g', delta_M_mean);
    else
        delta_M_mean_txt = 'NaN';
    end

    if isfinite(delta_M_min)
        delta_M_min_txt = sprintf('%.10g', delta_M_min);
    else
        delta_M_min_txt = 'NaN';
    end

    status_rows = [
        status_rows;
        {"EXECUTION_STATUS","SUCCESS"};
        {"TOTAL_TRACES", num2str(nT)};
        {"FAILED_TRACES", num2str(n_fail)};
        {"TRACE_DATA_AVAILABLE", char(trace_data_available)};
        {"SIGNAL_VARIATION_PRESENT", char(signal_variation_present)};
        {"DELTA_M_MEAN", delta_M_mean_txt};
        {"DELTA_M_MIN", delta_M_min_txt}
    ];

    %% ===== 4. WRITE OUTPUTS =====
    writetable(results, fullfile(tables_dir, ...
        'relaxation_canonical_implementation_check.csv'));

    writetable(trace_snapshot_rows, fullfile(tables_dir, ...
        'relaxation_trace_snapshot.csv'));

    writetable(trace_summary_rows, fullfile(tables_dir, ...
        'relaxation_trace_summary.csv'));

    write_status_csv(status_rows, ...
        fullfile(tables_dir, ...
        'relaxation_canonical_implementation_check_status.csv'));

    write_simple_report(run_ctx, results);

    report_path = fullfile(reports_dir, 'relaxation_canonical_implementation_check.md');
    if isempty(delta_M_valid)
        delta_line = 'delta_M distribution: no valid trace deltas available';
    else
        delta_line = sprintf('delta_M distribution: min=%.6g, max=%.6g, mean=%.6g, median=%.6g, std=%.6g', ...
            min(delta_M_valid), max(delta_M_valid), mean(delta_M_valid), median(delta_M_valid), std(delta_M_valid, 'omitnan'));
    end

    fid = fopen(report_path, 'a');
    if fid < 0
        error('Failed to append trace visibility section: %s', report_path);
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '\n## Trace Visibility\n');
    fprintf(fid, '- TRACE_VISIBILITY = ENABLED\n');
    fprintf(fid, '- traces exported: %d\n', n_trace_exports);
    fprintf(fid, '- %s\n', delta_line);
    fprintf(fid, '- delta_M mean: %.6g\n', delta_M_mean);
    fprintf(fid, '- delta_M min: %.6g\n', delta_M_min);
    fprintf(fid, '- %% of traces with delta_M > %.1e: %.2f%%\n', SMALL_DELTA_THRESHOLD, pct_above_small);

    fprintf(fid, '\n## Trace Visibility Verdicts\n');
    fprintf(fid, '- TRACE_DATA_AVAILABLE = %s\n', char(trace_data_available));
    fprintf(fid, '- SIGNAL_VARIATION_PRESENT = %s\n', char(signal_variation_present));
    fprintf(fid, '- DELTA_M_MEAN = %s\n', delta_M_mean_txt);
    fprintf(fid, '- DELTA_M_MIN = %s\n', delta_M_min_txt);

catch ME
    write_failure_outputs(ME);
    rethrow(ME);
end
