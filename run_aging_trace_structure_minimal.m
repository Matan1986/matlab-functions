clear; clc;

% minimal aging trace structure run

repo_root = 'C:/Dev/matlab-functions';
addpath(genpath(fullfile(repo_root, 'Aging')));
addpath(genpath(fullfile(repo_root, 'General ver2')));
addpath(genpath(fullfile(repo_root, 'Tools ver1')));
addpath(fullfile(repo_root, 'runs'));

cfg = struct();
cfg.runLabel = 'aging_trace_structure_minimal';
run = createRunContext('aging', cfg);

tables_dir = fullfile(run.run_dir, 'tables');
reports_dir = fullfile(run.run_dir, 'reports');
if ~exist(tables_dir, 'dir')
    mkdir(tables_dir);
end
if ~exist(reports_dir, 'dir')
    mkdir(reports_dir);
end

metrics_csv = fullfile(tables_dir, 'aging_trace_structure_metrics.csv');
status_csv = fullfile(tables_dir, 'aging_trace_structure_status.csv');
report_md = fullfile(reports_dir, 'aging_trace_structure.md');

EXECUTION_STATUS = 'SUCCESS';
INPUT_FOUND = 'YES';
ERROR_MESSAGE = '';
N_T = 0;
MAIN_RESULT_SUMMARY = 'minimal metrics written';

trace_id = {};
temperature_K = [];
monotonic_score = [];
log_time_linearity_score = [];
dynamic_range = [];

if exist('localPaths', 'file') ~= 2
    EXECUTION_STATUS = 'FAIL';
    INPUT_FOUND = 'NO';
    ERROR_MESSAGE = 'localPaths.m not found';
    MAIN_RESULT_SUMMARY = 'execution failed; localPaths.m missing';
else
    paths = localPaths();
    aging_data_dir = fullfile(paths.dataRoot, 'Aging');

    if ~exist(aging_data_dir, 'dir')
        EXECUTION_STATUS = 'FAIL';
        INPUT_FOUND = 'NO';
        ERROR_MESSAGE = ['aging data directory not found: ' aging_data_dir];
        MAIN_RESULT_SUMMARY = 'execution failed; aging data directory missing';
    else
        [~, pauseRuns] = getFileList_aging(aging_data_dir);
        N_T = numel(pauseRuns);

        if N_T == 0
            INPUT_FOUND = 'NO';
            MAIN_RESULT_SUMMARY = 'no pause runs found; wrote empty outputs';
        end

        for i = 1:N_T
            [T, M] = importFiles_aging(pauseRuns(i).file, true, false);
            finite_mask = isfinite(T) & isfinite(M);
            T_fin = T(finite_mask);
            M_fin = M(finite_mask);

            trace_id{end+1,1} = sprintf('pause_run_%d', i);
            temperature_K(end+1,1) = pauseRuns(i).waitK;

            if numel(M_fin) >= 2
                dM = diff(M_fin);
                n_pos = sum(dM > 0);
                n_neg = sum(dM < 0);
                denom = n_pos + n_neg;
                if denom > 0
                    monotonic_score(end+1,1) = abs(n_pos - n_neg) / denom;
                else
                    monotonic_score(end+1,1) = 0;
                end
                dynamic_range(end+1,1) = max(M_fin) - min(M_fin);
            else
                monotonic_score(end+1,1) = NaN;
                dynamic_range(end+1,1) = NaN;
            end

            if numel(M_fin) >= 3 && all(T_fin > 0)
                x = log(T_fin);
                p = polyfit(x, M_fin, 1);
                yhat = polyval(p, x);
                ss_res = sum((M_fin - yhat).^2);
                ss_tot = sum((M_fin - mean(M_fin)).^2);
                if ss_tot > 0
                    log_time_linearity_score(end+1,1) = 1 - (ss_res / ss_tot);
                else
                    log_time_linearity_score(end+1,1) = NaN;
                end
            else
                log_time_linearity_score(end+1,1) = NaN;
            end
        end
    end
end

T_metrics = table(trace_id, temperature_K, monotonic_score, log_time_linearity_score, dynamic_range);
writetable(T_metrics, metrics_csv);

T_status = table({EXECUTION_STATUS}, {INPUT_FOUND}, {ERROR_MESSAGE}, N_T, {MAIN_RESULT_SUMMARY}, ...
    'VariableNames', {'EXECUTION_STATUS','INPUT_FOUND','ERROR_MESSAGE','N_T','MAIN_RESULT_SUMMARY'});
writetable(T_status, status_csv);

fid = fopen(report_md, 'w');
if fid ~= -1
    fprintf(fid, '# Aging Trace Structure Minimal\n\n');
    fprintf(fid, 'Execution status: %s\n\n', EXECUTION_STATUS);
    fprintf(fid, 'Input found: %s\n\n', INPUT_FOUND);
    fprintf(fid, 'Trace count: %d\n\n', N_T);
    fprintf(fid, 'Metrics file: %s\n', metrics_csv);
    fclose(fid);
end
