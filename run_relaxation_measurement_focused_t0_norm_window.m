clear; clc;

repo_root = 'C:\Dev\matlab-functions';
script_abs = 'C:\Dev\matlab-functions\run_relaxation_measurement_focused_t0_norm_window.m';
data_dir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM';
run_label = 'relaxation_measurement_focused_t0_norm_window_audit';

writecell({'SCRIPT_START','run_relaxation_measurement_focused_t0_norm_window',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'))}, fullfile(repo_root, 'tables', 'relaxation_measurement_focused_t0_norm_window_startup.csv'));

if exist(fullfile(repo_root, 'tables'), 'dir') ~= 7
    mkdir(fullfile(repo_root, 'tables'));
end
if exist(fullfile(repo_root, 'reports'), 'dir') ~= 7
    mkdir(fullfile(repo_root, 'reports'));
end

summary_root = fullfile(repo_root, 'tables', 'relaxation_measurement_focused_t0_norm_window_summary.csv');
status_root = fullfile(repo_root, 'tables', 'relaxation_measurement_focused_t0_norm_window_status.csv');
report_root = fullfile(repo_root, 'reports', 'relaxation_measurement_focused_t0_norm_window.md');

if exist(summary_root, 'file') == 2
    k = 2;
    while true
        candidate = fullfile(repo_root, 'tables', sprintf('relaxation_measurement_focused_t0_norm_window_summary_v%d.csv', k));
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
        candidate = fullfile(repo_root, 'tables', sprintf('relaxation_measurement_focused_t0_norm_window_status_v%d.csv', k));
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
        candidate = fullfile(repo_root, 'reports', sprintf('relaxation_measurement_focused_t0_norm_window_v%d.md', k));
        if exist(candidate, 'file') ~= 2
            report_root = candidate;
            break;
        end
        k = k + 1;
    end
end

header_summary = {'combo_id','t0_choice','normalization_choice','window_choice','supported','n_valid_traces','trace_corr_median','nrmse_median','nrmse_worst','log_slope_consistency_median','amplitude_like','timescale_like_s','mean_log_slope','rel_change_amplitude','rel_change_timescale','rel_change_mean_log_slope','median_temp_sensitivity','worst_temp_sensitivity','temp_of_worst_sensitivity_K','instability_localized_at_specific_T','stable_under_thresholds','stability_rank','stability_score'};
summary_rows = {'combo_000','not_run','not_run','not_run','NO',0,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,'NO','NO',NaN,NaN};

header_status = {'verdict','value','criterion','evidence'};
status_rows = {
    'STABLE_SUBREGION_EXISTS','NO','pending','not_executed';
    'CANONICAL_T0_IDENTIFIED','NO','pending','not_executed';
    'CANONICAL_NORMALIZATION_IDENTIFIED','NO','pending','not_executed';
    'CANONICAL_WINDOW_IDENTIFIED','NO','pending','not_executed';
    'RELAXATION_MEASUREMENT_CAN_BE_STABILIZED','NO','pending','not_executed';
    'SAFE_TO_DEFINE_NEW_CANONICAL_MEASUREMENT','NO','pending','not_executed'};

report_text = '# Relaxation Measurement Focused Audit: t0 + normalization + window';

execution_status = 'FAILED';
input_found = 'NO';
error_message = '';
main_result_summary = 'not_run';
n_files = 0;

run_dir = fullfile(repo_root, 'results', 'relaxation', 'runs', ['run_' datestr(now,'yyyy_mm_dd_HHMMSS') '_' run_label]);
if exist(run_dir, 'dir') ~= 7
    mkdir(run_dir);
end
if exist(fullfile(run_dir, 'tables'), 'dir') ~= 7
    mkdir(fullfile(run_dir, 'tables'));
end
if exist(fullfile(run_dir, 'reports'), 'dir') ~= 7
    mkdir(fullfile(run_dir, 'reports'));
end

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
    if exist(fullfile(run_dir, 'tables'), 'dir') ~= 7
        mkdir(fullfile(run_dir, 'tables'));
    end
    if exist(fullfile(run_dir, 'reports'), 'dir') ~= 7
        mkdir(fullfile(run_dir, 'reports'));
    end

    [fileList, temps, ~, ~, ~, ~] = getFileList_relaxation(data_dir, 'parula');
    [Time_table, Temp_table, ~, Moment_table, ~] = importFiles_relaxation(data_dir, fileList, true, false);

    n_files = numel(fileList);
    if n_files < 4
        error('Too few raw trace files for focused audit: %d', n_files);
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

    t0_labels = {'earliest_valid_start','post_settling_start_10pct','conservative_delayed_start_20pct'};
    norm_labels = {'none','initial_amplitude_y_over_y0','tail_referenced_contrast'};
    win_labels = {'full_usable_window','early_heavy_70pct','conservative_late_trimmed_85pct'};

    n_t0 = numel(t0_labels);
    n_norm = numel(norm_labels);
    n_win = numel(win_labels);
    n_combo = n_t0 * n_norm * n_win;
    min_points = 25;

    combo_id = cell(n_combo, 1);
    combo_t0 = cell(n_combo, 1);
    combo_norm = cell(n_combo, 1);
    combo_win = cell(n_combo, 1);

    trace_x = cell(n_combo, n_files);
    trace_y = cell(n_combo, n_files);
    valid_mask = false(n_combo, n_files);
    supported = false(n_combo, 1);

    amp_desc = nan(n_combo, n_files);
    tau_desc = nan(n_combo, n_files);
    slope_desc = nan(n_combo, n_files);

    c = 0;
    for it0 = 1:n_t0
        for inorm = 1:n_norm
            for iwin = 1:n_win
                c = c + 1;
                combo_id{c} = sprintf('combo_%02d', c);
                combo_t0{c} = t0_labels{it0};
                combo_norm{c} = norm_labels{inorm};
                combo_win{c} = win_labels{iwin};

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

                    i0 = 1;
                    if it0 == 2
                        i0 = 1 + floor(0.10 * (numel(t) - 1));
                    elseif it0 == 3
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
                    if iwin == 2
                        iend = max(min_points, floor(0.70 * numel(trel)));
                    elseif iwin == 3
                        iend = max(min_points, floor(0.85 * numel(trel)));
                    end
                    trel = trel(1:iend);
                    y = y(1:iend);
                    if numel(trel) < min_points
                        continue;
                    end

                    x = log10(trel);
                    yv = y;
                    if inorm == 2
                        den = yv(1);
                        if abs(den) < 1e-12
                            continue;
                        end
                        yv = yv ./ den;
                    elseif inorm == 3
                        den = yv(1) - yv(end);
                        if abs(den) < 1e-12
                            continue;
                        end
                        yv = (yv - yv(end)) ./ den;
                    end

                    if any(~isfinite(x)) || any(~isfinite(yv)) || numel(x) < min_points
                        continue;
                    end

                    trace_x{c, i} = x(:)';
                    trace_y{c, i} = yv(:)';
                    valid_mask(c, i) = true;

                    amp_desc(c, i) = abs(yv(1) - yv(end));
                    slope_desc(c, i) = mean(gradient(yv, x), 'omitnan');

                    denh = yv(1) - yv(end);
                    if abs(denh) >= 1e-12
                        yn = (yv - yv(end)) ./ denh;
                        j = find(yn(1:end-1) >= 0.5 & yn(2:end) <= 0.5, 1, 'first');
                        if ~isempty(j)
                            x1 = x(j);
                            x2 = x(j + 1);
                            y1 = yn(j) - 0.5;
                            y2 = yn(j + 1) - 0.5;
                            if abs(y2 - y1) < eps
                                xh = 0.5 * (x1 + x2);
                            else
                                xh = x1 - y1 * (x2 - x1) / (y2 - y1);
                            end
                            tau_desc(c, i) = 10.^xh;
                        end
                    end
                end

                if nnz(valid_mask(c, :)) >= 4
                    supported(c) = true;
                end
            end
        end
    end

    ref_idx = find(strcmp(combo_t0, 'earliest_valid_start') & strcmp(combo_norm, 'none') & strcmp(combo_win, 'full_usable_window'), 1, 'first');
    if isempty(ref_idx) || ~supported(ref_idx)
        error('Reference combination unsupported on raw traces.');
    end

    trace_corr_med = nan(n_combo, 1);
    nrmse_med = nan(n_combo, 1);
    nrmse_max = nan(n_combo, 1);
    slope_corr_med = nan(n_combo, 1);

    rel_amp = nan(n_combo, 1);
    rel_tau = nan(n_combo, 1);
    rel_slope = nan(n_combo, 1);

    med_temp_sens = nan(n_combo, 1);
    worst_temp_sens = nan(n_combo, 1);
    temp_worst = nan(n_combo, 1);
    temp_localized = cell(n_combo, 1);

    score = nan(n_combo, 1);
    stable_combo = false(n_combo, 1);

    ref_amp = median(amp_desc(ref_idx, valid_mask(ref_idx, :)), 'omitnan');
    ref_tau = median(tau_desc(ref_idx, valid_mask(ref_idx, :)), 'omitnan');
    ref_slope = median(slope_desc(ref_idx, valid_mask(ref_idx, :)), 'omitnan');

    for v = 1:n_combo
        temp_localized{v} = 'NO';
        if ~supported(v)
            continue;
        end

        if v == ref_idx
            trace_corr_med(v) = 1;
            nrmse_med(v) = 0;
            nrmse_max(v) = 0;
            slope_corr_med(v) = 1;
            med_temp_sens(v) = 0;
            worst_temp_sens(v) = 0;
            temp_worst(v) = NaN;
        else
            corr_vals = nan(n_files, 1);
            nrmse_vals = nan(n_files, 1);
            slope_vals = nan(n_files, 1);

            for i = 1:n_files
                xb = trace_x{ref_idx, i};
                yb = trace_y{ref_idx, i};
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

                sb = gradient(ybc, xc);
                sv = gradient(yvc, xc);
                cs = corrcoef(sb, sv);
                if numel(cs) >= 4
                    slope_vals(i) = cs(1, 2);
                end
            end

            trace_corr_med(v) = median(corr_vals, 'omitnan');
            nrmse_med(v) = median(nrmse_vals, 'omitnan');
            nrmse_max(v) = max(nrmse_vals, [], 'omitnan');
            slope_corr_med(v) = median(slope_vals, 'omitnan');

            temp_u = unique(T_nom(isfinite(T_nom)));
            temp_vec = nan(numel(temp_u), 1);
            for jt = 1:numel(temp_u)
                mt = abs(T_nom - temp_u(jt)) < 1e-9;
                temp_vec(jt) = median(nrmse_vals(mt), 'omitnan');
            end
            med_temp_sens(v) = median(temp_vec, 'omitnan');
            [mx, imx] = max(temp_vec, [], 'omitnan');
            worst_temp_sens(v) = mx;
            if ~isempty(imx) && isfinite(imx)
                temp_worst(v) = temp_u(imx);
            end
            medv = median(temp_vec, 'omitnan');
            if isfinite(mx) && isfinite(medv) && medv > 0 && mx > 1.8 * medv
                temp_localized{v} = 'YES';
            end
        end

        amp_v = median(amp_desc(v, valid_mask(v, :)), 'omitnan');
        tau_v = median(tau_desc(v, valid_mask(v, :)), 'omitnan');
        slope_v = median(slope_desc(v, valid_mask(v, :)), 'omitnan');

        rel_amp(v) = abs(amp_v - ref_amp) / max(abs(ref_amp), eps);
        rel_tau(v) = abs(tau_v - ref_tau) / max(abs(ref_tau), eps);
        rel_slope(v) = abs(slope_v - ref_slope) / max(abs(ref_slope), eps);

        drift_max = max([rel_amp(v), rel_tau(v), rel_slope(v)]);
        stable_combo(v) = (trace_corr_med(v) >= 0.95) && (nrmse_med(v) <= 0.08) && (nrmse_max(v) <= 0.15) && (slope_corr_med(v) >= 0.90) && (drift_max <= 0.20);
        score(v) = (1 - trace_corr_med(v)) + nrmse_med(v) + (1 - slope_corr_med(v)) + max(0, nrmse_max(v) - 0.15) + drift_max;
    end

    rank_vec = nan(n_combo, 1);
    idx_sort = find(supported & isfinite(score));
    [~, ord] = sort(score(idx_sort), 'ascend');
    for j = 1:numel(ord)
        rank_vec(idx_sort(ord(j))) = j;
    end

    stable_idx = find(stable_combo);
    stable_subregion_exists = ~isempty(stable_idx);

    best_idx = NaN;
    best_stable = false;
    if stable_subregion_exists
        [~, ib] = min(score(stable_idx));
        best_idx = stable_idx(ib);
        best_stable = true;
    elseif ~isempty(idx_sort)
        [~, ib] = min(score(idx_sort));
        best_idx = idx_sort(ib);
        best_stable = false;
    end

    can_stabilize = stable_subregion_exists;
    safe_new = stable_subregion_exists && best_stable;

    t0_identified = 'NO';
    norm_identified = 'NO';
    win_identified = 'NO';
    cand_t0 = 'not_identified';
    cand_norm = 'not_identified';
    cand_win = 'not_identified';

    if isfinite(best_idx) && stable_subregion_exists
        t0_identified = 'YES';
        norm_identified = 'YES';
        win_identified = 'YES';
        cand_t0 = combo_t0{best_idx};
        cand_norm = combo_norm{best_idx};
        cand_win = combo_win{best_idx};
    end

    summary_rows = cell(n_combo, 23);
    for v = 1:n_combo
        amp_v = median(amp_desc(v, valid_mask(v, :)), 'omitnan');
        tau_v = median(tau_desc(v, valid_mask(v, :)), 'omitnan');
        slope_v = median(slope_desc(v, valid_mask(v, :)), 'omitnan');
        summary_rows(v, :) = {combo_id{v}, combo_t0{v}, combo_norm{v}, combo_win{v}, char(string(supported(v))), nnz(valid_mask(v, :)), trace_corr_med(v), nrmse_med(v), nrmse_max(v), slope_corr_med(v), amp_v, tau_v, slope_v, rel_amp(v), rel_tau(v), rel_slope(v), med_temp_sens(v), worst_temp_sens(v), temp_worst(v), temp_localized{v}, char(string(stable_combo(v))), rank_vec(v), score(v)};
    end

    best_evidence = 'no_supported_combination';
    if isfinite(best_idx)
        best_evidence = sprintf('best_combo=%s; stable=%s; score=%.5f; corr_med=%.4f; nrmse_med=%.4f; nrmse_worst=%.4f; slope_med=%.4f', combo_id{best_idx}, char(string(best_stable)), score(best_idx), trace_corr_med(best_idx), nrmse_med(best_idx), nrmse_max(best_idx), slope_corr_med(best_idx));
    end

    status_rows = {
        'STABLE_SUBREGION_EXISTS', char(string(stable_subregion_exists)), 'exists if >=1 combination passes all thresholds', sprintf('stable_combo_count=%d of %d', numel(stable_idx), n_combo);
        'CANONICAL_T0_IDENTIFIED', t0_identified, 'identified only when stable subregion exists', ['candidate_t0=' cand_t0];
        'CANONICAL_NORMALIZATION_IDENTIFIED', norm_identified, 'identified only when stable subregion exists', ['candidate_normalization=' cand_norm];
        'CANONICAL_WINDOW_IDENTIFIED', win_identified, 'identified only when stable subregion exists', ['candidate_window=' cand_win];
        'RELAXATION_MEASUREMENT_CAN_BE_STABILIZED', char(string(can_stabilize)), 'true only if stable subregion exists', best_evidence;
        'SAFE_TO_DEFINE_NEW_CANONICAL_MEASUREMENT', char(string(safe_new)), 'true only if best candidate is actually stable (not least bad)', best_evidence};

    recommendation = 'continue measurement redesign';
    stable_text = 'least bad only (not stable)';
    if safe_new
        recommendation = 'adopt candidate';
        stable_text = 'actually stable';
    end

    report_lines = {};
    report_lines{end+1} = '# Relaxation Measurement Focused Audit: t0 + normalization + window';
    report_lines{end+1} = '';
    report_lines{end+1} = '## Objective';
    report_lines{end+1} = 'Can relaxation measurement be stabilized by a clean choice of t0 + normalization + window?';
    report_lines{end+1} = '';
    report_lines{end+1} = '## Raw Input';
    report_lines{end+1} = ['- script: `' script_abs '`'];
    report_lines{end+1} = ['- dataDir: `' data_dir '`'];
    report_lines{end+1} = ['- trace_count: ' num2str(n_files)];
    report_lines{end+1} = ['- run_dir: `' run_dir '`'];
    report_lines{end+1} = '';
    report_lines{end+1} = '## Exact Tested Variant Grid';
    report_lines{end+1} = '- t0: earliest_valid_start, post_settling_start_10pct, conservative_delayed_start_20pct';
    report_lines{end+1} = '- normalization: none, initial_amplitude_y_over_y0, tail_referenced_contrast';
    report_lines{end+1} = '- window: full_usable_window, early_heavy_70pct, conservative_late_trimmed_85pct';
    report_lines{end+1} = ['- combinations tested: ' num2str(n_combo)];
    report_lines{end+1} = '';
    report_lines{end+1} = '## Stability Ranking (Top 8)';
    top_k = min(8, numel(idx_sort));
    if top_k == 0
        report_lines{end+1} = '- No supported combinations.';
    else
        [~, ord_all] = sort(score(idx_sort), 'ascend');
        for k = 1:top_k
            idx = idx_sort(ord_all(k));
            report_lines{end+1} = sprintf('- rank %d: %s | t0=%s | norm=%s | window=%s | stable=%s | score=%.5f | corr_med=%.4f | nrmse_med=%.4f | nrmse_worst=%.4f | slope_med=%.4f', k, combo_id{idx}, combo_t0{idx}, combo_norm{idx}, combo_win{idx}, char(string(stable_combo(idx))), score(idx), trace_corr_med(idx), nrmse_med(idx), nrmse_max(idx), slope_corr_med(idx));
        end
    end
    report_lines{end+1} = '';
    report_lines{end+1} = '## Best Candidate Canonical Combination';
    if isfinite(best_idx)
        report_lines{end+1} = ['- combination: ' combo_id{best_idx}];
        report_lines{end+1} = ['- t0: ' combo_t0{best_idx}];
        report_lines{end+1} = ['- normalization: ' combo_norm{best_idx}];
        report_lines{end+1} = ['- window: ' combo_win{best_idx}];
        report_lines{end+1} = ['- classification: ' stable_text];
    else
        report_lines{end+1} = '- no_supported_combination';
    end
    report_lines{end+1} = '';
    report_lines{end+1} = '## Verdicts';
    for ii = 1:size(status_rows, 1)
        report_lines{end+1} = ['- ' status_rows{ii, 1} ': ' status_rows{ii, 2}];
    end
    report_lines{end+1} = '';
    report_lines{end+1} = '## Recommendation';
    report_lines{end+1} = ['- ' recommendation];

    report_text = strjoin(report_lines, newline);

    execution_status = 'SUCCESS';
    if safe_new
        main_result_summary = 'stable_subregion_yes_safe_new_canonical_yes';
    elseif stable_subregion_exists
        main_result_summary = 'stable_subregion_yes_safe_new_canonical_no';
    else
        main_result_summary = 'stable_subregion_no';
    end

catch ME
    execution_status = 'FAILED';
    error_message = char(string(ME.message));
    main_result_summary = 'focused_t0_norm_window_audit_failed';

    summary_rows = {'combo_000','not_run','not_run','not_run','NO',0,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,'NO','NO',NaN,NaN};
    status_rows = {
        'STABLE_SUBREGION_EXISTS','NO','execution_failed',error_message;
        'CANONICAL_T0_IDENTIFIED','NO','execution_failed',error_message;
        'CANONICAL_NORMALIZATION_IDENTIFIED','NO','execution_failed',error_message;
        'CANONICAL_WINDOW_IDENTIFIED','NO','execution_failed',error_message;
        'RELAXATION_MEASUREMENT_CAN_BE_STABILIZED','NO','execution_failed',error_message;
        'SAFE_TO_DEFINE_NEW_CANONICAL_MEASUREMENT','NO','execution_failed',error_message};

    report_text = strjoin({
        '# Relaxation Measurement Focused Audit: t0 + normalization + window';
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

run_summary = fullfile(run_dir, 'relaxation_measurement_focused_t0_norm_window_summary.csv');
run_status = fullfile(run_dir, 'relaxation_measurement_focused_t0_norm_window_status.csv');
run_report = fullfile(run_dir, 'relaxation_measurement_focused_t0_norm_window.md');
run_summary_sub = fullfile(run_dir, 'tables', 'relaxation_measurement_focused_t0_norm_window_summary.csv');
run_status_sub = fullfile(run_dir, 'tables', 'relaxation_measurement_focused_t0_norm_window_status.csv');
run_report_sub = fullfile(run_dir, 'reports', 'relaxation_measurement_focused_t0_norm_window.md');

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

fprintf('FOCUSED_RELAXATION_AUDIT_STATUS=%s\n', execution_status);
fprintf('INPUT_FOUND=%s\n', input_found);
fprintf('ERROR_MESSAGE=%s\n', error_message);
fprintf('MAIN_RESULT_SUMMARY=%s\n', main_result_summary);
fprintf('SUMMARY_TABLE_PATH=%s\n', summary_root);
fprintf('STATUS_TABLE_PATH=%s\n', status_root);
fprintf('REPORT_PATH=%s\n', report_root);
for i = 1:size(status_rows, 1)
    fprintf('%s=%s\n', status_rows{i, 1}, status_rows{i, 2});
end
