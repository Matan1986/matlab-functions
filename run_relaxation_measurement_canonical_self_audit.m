clear; clc;

repo_root = 'C:\Dev\matlab-functions';
script_abs = 'C:\Dev\matlab-functions\run_relaxation_measurement_canonical_self_audit.m';
data_dir = 'L:\My Drive\Quantum materials lab\Analysis Lab measurments\Magnetic Intercalated TMD\Co1_3TaS2\MG 119\MG 119 M2 in plane along long edge relax aging\Relaxation TRM';
run_label = 'relaxation_measurement_canonical_self_audit';

if exist(fullfile(repo_root, 'tables'), 'dir') ~= 7
    mkdir(fullfile(repo_root, 'tables'));
end
if exist(fullfile(repo_root, 'reports'), 'dir') ~= 7
    mkdir(fullfile(repo_root, 'reports'));
end

main_table_root = fullfile(repo_root, 'tables', 'relaxation_measurement_canonical_self_audit.csv');
status_table_root = fullfile(repo_root, 'tables', 'relaxation_measurement_canonical_self_audit_status.csv');
report_root = fullfile(repo_root, 'reports', 'relaxation_measurement_canonical_self_audit.md');

if exist(main_table_root, 'file') == 2
    k = 2;
    while true
        candidate = fullfile(repo_root, 'tables', sprintf('relaxation_measurement_canonical_self_audit_v%d.csv', k));
        if exist(candidate, 'file') ~= 2
            main_table_root = candidate;
            break;
        end
        k = k + 1;
    end
end
if exist(status_table_root, 'file') == 2
    k = 2;
    while true
        candidate = fullfile(repo_root, 'tables', sprintf('relaxation_measurement_canonical_self_audit_status_v%d.csv', k));
        if exist(candidate, 'file') ~= 2
            status_table_root = candidate;
            break;
        end
        k = k + 1;
    end
end
if exist(report_root, 'file') == 2
    k = 2;
    while true
        candidate = fullfile(repo_root, 'reports', sprintf('relaxation_measurement_canonical_self_audit_v%d.md', k));
        if exist(candidate, 'file') ~= 2
            report_root = candidate;
            break;
        end
        k = k + 1;
    end
end

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

execution_status = 'FAILED';
error_message = '';
input_found = 'NO';

header_main = {'metric','value','criterion','evidence'};
rows_main = {
    'AUDIT_STATUS','FAILED','must run end-to-end','initialized';
    'INPUT_FOUND','NO','raw path exists and files load','initialized'};

header_status = {'verdict','value','criterion','evidence'};
rows_status = {
    'EARLIEST_T0_IS_AFTER_FIELD_REMOVAL','false','true only if earliest start is low-field and no in-window field transition','not_executed';
    'EARLIEST_T0_CONTAINS_TRANSIENT','true','true if early segment has transient-like jump/slope discontinuity or field transition','not_executed';
    'NO_NORMALIZATION_IS_PHYSICALLY_MEANINGFUL','false','true only if absolute scale appears physically consistent and not dominated by scaling artifact','not_executed';
    'FULL_WINDOW_IS_PHYSICALLY_VALID','false','true only if early and late segments are physically usable for relaxation','not_executed';
    'STABLE_CHOICE_IS_ALSO_PHYSICAL','false','true only if all physical checks pass','not_executed';
    'CANONICAL_CHOICE_CONFIRMED','false','true only if stable choice is also physical','not_executed';
    'REQUIRES_REVISED_CANONICAL_DEFINITION','true','true if any physical check fails or is uncertain','not_executed'};

report_text = '# Relaxation Canonical Self-Audit';

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
        error('Too few files for canonical self audit: %d', n_files);
    end

    temp_nom = temps(:);
    for i = 1:n_files
        if i <= numel(Temp_table) && ~isempty(Temp_table{i})
            Ti = Temp_table{i};
            Ti = Ti(isfinite(Ti));
            if ~isempty(Ti) && ~isfinite(temp_nom(i))
                temp_nom(i) = median(Ti, 'omitnan');
            end
        end
    end

    h_thresh = 1.0;
    early_fraction = 0.10;
    tail_fraction = 0.10;

    trace_supported = false(n_files, 1);
    earliest_is_lowH = false(n_files, 1);
    has_early_field_transition = false(n_files, 1);
    earliest_to_lowH_delay_s = nan(n_files, 1);

    early_jump_ratio = nan(n_files, 1);
    early_slope_ratio = nan(n_files, 1);
    late_noise_ratio = nan(n_files, 1);
    monotonic_fraction = nan(n_files, 1);

    m_start = nan(n_files, 1);
    m_tail = nan(n_files, 1);
    m_span = nan(n_files, 1);

    for i = 1:n_files
        if i > numel(Time_table) || i > numel(Field_table) || i > numel(Moment_table)
            continue;
        end
        t = Time_table{i};
        h = Field_table{i};
        m = Moment_table{i};
        if isempty(t) || isempty(h) || isempty(m)
            continue;
        end

        t = t(:);
        h = h(:);
        m = m(:);
        n0 = min([numel(t), numel(h), numel(m)]);
        t = t(1:n0);
        h = h(1:n0);
        m = m(1:n0);

        ok = isfinite(t) & isfinite(h) & isfinite(m);
        t = t(ok);
        h = h(ok);
        m = m(ok);
        if numel(t) < 40
            continue;
        end

        [t, ix] = sort(t, 'ascend');
        h = h(ix);
        m = m(ix);

        [t, iu] = unique(t, 'stable');
        h = h(iu);
        m = m(iu);
        if numel(t) < 40
            continue;
        end

        trace_supported(i) = true;

        n = numel(t);
        ne = max(5, floor(early_fraction * n));
        nt = max(5, floor(tail_fraction * n));
        ne = min(ne, n - 2);
        nt = min(nt, n - 2);

        earliest_is_lowH(i) = abs(h(1)) < h_thresh;
        ilow = find(abs(h) < h_thresh, 1, 'first');
        if isempty(ilow)
            ilow = n;
        end
        earliest_to_lowH_delay_s(i) = t(ilow) - t(1);

        early_field = h(1:ne);
        has_early_field_transition(i) = (max(abs(early_field)) - min(abs(early_field))) > h_thresh;

        m_early = m(1:ne);
        m_mid = m(ne+1:min(n-ne, ne+max(5, floor(0.15 * n))));
        if isempty(m_mid)
            m_mid = m(ne+1:min(n, ne+5));
        end
        m_tail_seg = m(n-nt+1:n);

        m_start(i) = median(m_early, 'omitnan');
        m_tail(i) = median(m_tail_seg, 'omitnan');
        span_abs = abs(m_start(i) - m_tail(i));
        m_span(i) = span_abs;

        early_step = abs(median(m_mid, 'omitnan') - median(m_early, 'omitnan'));
        if span_abs > 1e-15
            early_jump_ratio(i) = early_step / span_abs;
            late_noise_ratio(i) = std(m_tail_seg, 'omitnan') / span_abs;
        end

        trel = t - t(1);
        keep = trel > 0;
        if nnz(keep) >= 20
            x = log10(trel(keep));
            y = m(keep);
            if numel(x) >= 20 && all(isfinite(x))
                dy = gradient(y, x);
                k1 = 1:min(ne, numel(dy));
                k2 = max(1, numel(dy)-nt+1):numel(dy);
                s1 = median(abs(dy(k1)), 'omitnan');
                s2 = median(abs(dy(k2)), 'omitnan');
                if isfinite(s1) && isfinite(s2) && s2 > 0
                    early_slope_ratio(i) = s1 / s2;
                end
                monotonic_fraction(i) = mean(dy < 0, 'omitnan');
            end
        end
    end

    valid = find(trace_supported);
    n_valid = numel(valid);
    if n_valid < 4
        error('Too few valid traces after finite filtering: %d', n_valid);
    end

    p_lowH_at_first = mean(earliest_is_lowH(valid));
    p_early_transition = mean(has_early_field_transition(valid));
    med_delay_to_lowH = median(earliest_to_lowH_delay_s(valid), 'omitnan');

    med_early_jump_ratio = median(early_jump_ratio(valid), 'omitnan');
    med_early_slope_ratio = median(early_slope_ratio(valid), 'omitnan');
    med_late_noise_ratio = median(late_noise_ratio(valid), 'omitnan');
    med_monotonic_fraction = median(monotonic_fraction(valid), 'omitnan');

    temp_valid = temp_nom(valid);
    span_valid = m_span(valid);
    start_valid = abs(m_start(valid));
    tail_valid = abs(m_tail(valid));

    ok_temp = isfinite(temp_valid) & isfinite(span_valid);
    if nnz(ok_temp) >= 4
        c = corrcoef(temp_valid(ok_temp), span_valid(ok_temp));
        amp_temp_corr = c(1,2);
    else
        amp_temp_corr = NaN;
    end

    ok_scale = isfinite(start_valid) & isfinite(tail_valid) & (tail_valid > 0);
    scale_ratio = nan(size(start_valid));
    scale_ratio(ok_scale) = start_valid(ok_scale) ./ tail_valid(ok_scale);
    med_scale_ratio = median(scale_ratio, 'omitnan');
    iqr_scale_ratio = iqr(scale_ratio(isfinite(scale_ratio)));

    earliest_after_field_removal = (p_lowH_at_first >= 0.95) && (p_early_transition <= 0.10) && (med_delay_to_lowH <= 1.0);

    contains_transient = (p_early_transition > 0.10) || (med_early_jump_ratio > 0.20) || (med_early_slope_ratio > 2.5);

    no_norm_phys_meaningful = isfinite(amp_temp_corr) && (abs(amp_temp_corr) >= 0.40) && isfinite(med_scale_ratio) && (iqr_scale_ratio <= 0.60 * max(med_scale_ratio, eps));

    full_window_valid = (~contains_transient) && isfinite(med_late_noise_ratio) && (med_late_noise_ratio <= 0.15) && isfinite(med_monotonic_fraction) && (med_monotonic_fraction >= 0.70);

    stable_also_physical = earliest_after_field_removal && no_norm_phys_meaningful && full_window_valid;
    canonical_confirmed = stable_also_physical;
    requires_revised = ~canonical_confirmed;

    rows_main = {
        'AUDIT_STATUS','SUCCESS','must run end-to-end','completed';
        'INPUT_FOUND','YES','raw path exists and files load',sprintf('n_files=%d;n_valid=%d', n_files, n_valid);
        'T0_LOW_FIELD_AT_FIRST_POINT_FRACTION',sprintf('%.4f', p_lowH_at_first),'>=0.95 supports earliest t0 after field removal','fraction of traces with |H(1)|<1 Oe';
        'T0_EARLY_FIELD_TRANSITION_FRACTION',sprintf('%.4f', p_early_transition),'<=0.10 required for clean post-removal start','fraction of traces with large |H| variation in first 10%%';
        'T0_MEDIAN_DELAY_TO_LOW_FIELD_S',sprintf('%.4f', med_delay_to_lowH),'<=1 s expected for immediate low-field start','time from first sample to first |H|<1 Oe';
        'EARLY_TRANSIENT_MEDIAN_JUMP_RATIO',sprintf('%.4f', med_early_jump_ratio),'<=0.20 preferred','early magnetization step normalized by full trace span';
        'EARLY_TRANSIENT_MEDIAN_SLOPE_RATIO',sprintf('%.4f', med_early_slope_ratio),'<=2.5 preferred','median |dM/dlogt| early / late';
        'LATE_NOISE_MEDIAN_RATIO',sprintf('%.4f', med_late_noise_ratio),'<=0.15 preferred for usable tail','tail std normalized by full trace span';
        'MONOTONIC_MEDIAN_FRACTION',sprintf('%.4f', med_monotonic_fraction),'>=0.70 preferred for relaxation-like behavior','fraction of negative dM/dlogt';
        'ABS_SPAN_VS_TEMP_CORR',sprintf('%.4f', amp_temp_corr'),'|corr|>=0.40 indicates non-random temperature structure','corr(temp, |M_start - M_tail|)';
        'ABS_SCALE_RATIO_MEDIAN',sprintf('%.4f', med_scale_ratio),'descriptive','median |M_start|/|M_tail|';
        'ABS_SCALE_RATIO_IQR',sprintf('%.4f', iqr_scale_ratio),'low spread supports stable absolute scaling','IQR of |M_start|/|M_tail| across traces';
        'MATHEMATICAL_STABLE_CHOICE','t0=earliest_valid_start;norm=none;window=full_usable_window','from prior focused audit','numerically top-ranked stable choice';
        'PHYSICAL_INTERPRETATION_NOTE','conservative','if any physical check fails, canonical must be revised','self-audit intentionally tries to falsify prior conclusion'};

    rows_status = {
        'EARLIEST_T0_IS_AFTER_FIELD_REMOVAL',string(earliest_after_field_removal), 'true only if earliest start is low-field and no in-window field transition',sprintf('p_lowH=%.3f;p_transition=%.3f;delay=%.3fs', p_lowH_at_first, p_early_transition, med_delay_to_lowH);
        'EARLIEST_T0_CONTAINS_TRANSIENT',string(contains_transient), 'true if early segment has transient-like jump/slope discontinuity or field transition',sprintf('jump_ratio=%.3f;slope_ratio=%.3f;p_transition=%.3f', med_early_jump_ratio, med_early_slope_ratio, p_early_transition);
        'NO_NORMALIZATION_IS_PHYSICALLY_MEANINGFUL',string(no_norm_phys_meaningful), 'true only if absolute scale appears physically consistent and not dominated by scaling artifact',sprintf('corr_span_temp=%.3f;scale_ratio_med=%.3f;scale_ratio_iqr=%.3f', amp_temp_corr, med_scale_ratio, iqr_scale_ratio);
        'FULL_WINDOW_IS_PHYSICALLY_VALID',string(full_window_valid), 'true only if early and late segments are physically usable for relaxation',sprintf('contains_transient=%s;late_noise=%.3f;monotonic=%.3f', string(contains_transient), med_late_noise_ratio, med_monotonic_fraction);
        'STABLE_CHOICE_IS_ALSO_PHYSICAL',string(stable_also_physical), 'true only if all physical checks pass',sprintf('earliest_after_field_removal=%s;no_norm_phys=%s;full_window_valid=%s', string(earliest_after_field_removal), string(no_norm_phys_meaningful), string(full_window_valid));
        'CANONICAL_CHOICE_CONFIRMED',string(canonical_confirmed), 'true only if stable choice is also physical',sprintf('stable_also_physical=%s', string(stable_also_physical));
        'REQUIRES_REVISED_CANONICAL_DEFINITION',string(requires_revised), 'true if any physical check fails or is uncertain',sprintf('revised=%s', string(requires_revised))};

    report_lines = {};
    report_lines{end+1} = '# Relaxation Canonical Self-Audit';
    report_lines{end+1} = '';
    report_lines{end+1} = '## Scope';
    report_lines{end+1} = '- Prior mathematically stable choice under test: t0=earliest_valid_start, normalization=none, window=full_usable_window.';
    report_lines{end+1} = '- This self-audit checks physical meaning against raw time/field/moment traces, not only numerical stability.';
    report_lines{end+1} = '';
    report_lines{end+1} = '## Data and Method';
    report_lines{end+1} = ['- script: `' script_abs '`'];
    report_lines{end+1} = ['- dataDir: `' data_dir '`'];
    report_lines{end+1} = sprintf('- traces loaded: %d, valid analyzed: %d', n_files, n_valid);
    report_lines{end+1} = '- t0 audit: checks whether first sample is already in low field and whether early region includes field transition.';
    report_lines{end+1} = '- normalization audit: checks whether absolute moment span carries coherent temperature structure and stable scaling.';
    report_lines{end+1} = '- full-window audit: checks early transient indicators and late-tail noise relative to total relaxation span.';
    report_lines{end+1} = '';
    report_lines{end+1} = '## Key Metrics';
    report_lines{end+1} = sprintf('- p_lowH_at_first_point = %.4f', p_lowH_at_first);
    report_lines{end+1} = sprintf('- p_early_field_transition = %.4f', p_early_transition);
    report_lines{end+1} = sprintf('- median_delay_to_lowH_s = %.4f', med_delay_to_lowH);
    report_lines{end+1} = sprintf('- median_early_jump_ratio = %.4f', med_early_jump_ratio);
    report_lines{end+1} = sprintf('- median_early_slope_ratio = %.4f', med_early_slope_ratio);
    report_lines{end+1} = sprintf('- median_late_noise_ratio = %.4f', med_late_noise_ratio);
    report_lines{end+1} = sprintf('- median_monotonic_fraction = %.4f', med_monotonic_fraction);
    report_lines{end+1} = sprintf('- corr(temp, |M_start-M_tail|) = %.4f', amp_temp_corr);
    report_lines{end+1} = sprintf('- scale_ratio median/IQR = %.4f / %.4f', med_scale_ratio, iqr_scale_ratio);
    report_lines{end+1} = '';
    report_lines{end+1} = '## Verdicts';
    report_lines{end+1} = ['- EARLIEST_T0_IS_AFTER_FIELD_REMOVAL: ' char(string(earliest_after_field_removal))];
    report_lines{end+1} = ['- EARLIEST_T0_CONTAINS_TRANSIENT: ' char(string(contains_transient))];
    report_lines{end+1} = ['- NO_NORMALIZATION_IS_PHYSICALLY_MEANINGFUL: ' char(string(no_norm_phys_meaningful))];
    report_lines{end+1} = ['- FULL_WINDOW_IS_PHYSICALLY_VALID: ' char(string(full_window_valid))];
    report_lines{end+1} = ['- STABLE_CHOICE_IS_ALSO_PHYSICAL: ' char(string(stable_also_physical))];
    report_lines{end+1} = ['- CANONICAL_CHOICE_CONFIRMED: ' char(string(canonical_confirmed))];
    report_lines{end+1} = ['- REQUIRES_REVISED_CANONICAL_DEFINITION: ' char(string(requires_revised))];
    report_lines{end+1} = '';
    report_lines{end+1} = '## Distinction';
    report_lines{end+1} = '- Mathematical stability identifies reproducibility under perturbations.';
    report_lines{end+1} = '- Physical canonical validity additionally requires that t0 maps to post-field-removal relaxation and that the selected normalization/window do not mix artifacts with physics.';

    report_text = strjoin(report_lines, newline);

    execution_status = 'SUCCESS';

catch ME
    execution_status = 'FAILED';
    error_message = ME.message;
end

% Always write artifacts, even on failure, to preserve audit trail.
C_main = [header_main; rows_main];
writecell(C_main, main_table_root);
writecell(C_main, fullfile(run_dir, 'tables', 'relaxation_measurement_canonical_self_audit.csv'));

C_status = [header_status; rows_status];
writecell(C_status, status_table_root);
writecell(C_status, fullfile(run_dir, 'tables', 'relaxation_measurement_canonical_self_audit_status.csv'));

fid = fopen(report_root, 'w');
if fid >= 0
    fprintf(fid, '%s\n', report_text);
    fclose(fid);
end
fid = fopen(fullfile(run_dir, 'reports', 'relaxation_measurement_canonical_self_audit.md'), 'w');
if fid >= 0
    fprintf(fid, '%s\n', report_text);
    fclose(fid);
end

writecell({'status', execution_status; 'input_found', input_found; 'error_message', error_message}, fullfile(run_dir, 'execution_status.csv'));

fprintf('RELAXATION_CANONICAL_SELF_AUDIT_STATUS=%s\n', execution_status);
fprintf('INPUT_FOUND=%s\n', input_found);
fprintf('ERROR_MESSAGE=%s\n', error_message);
fprintf('SELF_AUDIT_TABLE=%s\n', main_table_root);
fprintf('SELF_AUDIT_STATUS_TABLE=%s\n', status_table_root);
fprintf('SELF_AUDIT_REPORT=%s\n', report_root);
if strcmp(execution_status, 'FAILED')
    error('self_audit_failed:%s', error_message);
end
