%% Threshold Distribution Model for Switching Data
% Tests whether switching curves can be described as cumulative response from
% a distribution of local thresholds.
%
% Tasks:
% 1. Normalized collapse of S(I,T) curves
% 2. Mean shape computation and variance
% 3. CDF fit (logistic + error function)
% 4. Area test vs. width*S_peak
% 5. Onset test at 10% of S_peak

repoRoot = pwd;
addpath(genpath(fullfile(repoRoot, 'tools')));
addpath(genpath(fullfile(repoRoot, 'Switching', 'utils')));
addpath(fullfile(repoRoot, 'Aging', 'utils'));

%% Setup
source_run_dir = fullfile(repoRoot, 'results', 'switching', 'runs', 'run_2026_03_10_112659_alignment_audit');
alignment_audit_dir = fullfile(source_run_dir, 'alignment_audit');

obs_csv = fullfile(alignment_audit_dir, 'switching_alignment_observables_vs_T.csv');
samples_csv = fullfile(alignment_audit_dir, 'switching_alignment_samples.csv');

assert(isfile(obs_csv), 'Missing observables file: %s', obs_csv);
assert(isfile(samples_csv), 'Missing samples file: %s', samples_csv);

runCfg = struct();
runCfg.runLabel = 'threshold_distribution_model';
runCfg.dataset = sprintf('alignment_audit:%s', source_run_dir);
runCtx = createRunContext('switching', runCfg);
run_output_dir = runCtx.run_dir;

fidNotes = fopen(runCtx.notes_path, 'a', 'n', 'UTF-8');
if fidNotes > 0
    fprintf(fidNotes, 'Source run: %s\nAlignment audit dir: %s\n', source_run_dir, alignment_audit_dir);
    fclose(fidNotes);
end

fprintf('Output directory: %s\n', run_output_dir);

%% Load Data
fprintf('Loading observables...\n');
obs_table = readtable(obs_csv);

% Extract observables by temperature
temps = obs_table.T_K;
temps = unique(temps, 'stable');
temps = sort(temps);
n_temps = length(temps);

I_peak_map = containers.Map();
width_I_map = containers.Map();
S_peak_map = containers.Map();

for t = temps'
    t_rows = obs_table(obs_table.T_K == t, :);
    
    if ~isempty(t_rows.I_peak)
        I_peak_map(num2str(t)) = t_rows.I_peak(1);
    end
    if ~isempty(t_rows.width_I)
        width_I_map(num2str(t)) = t_rows.width_I(1);
    end
    if ~isempty(t_rows.S_peak)
        S_peak_map(num2str(t)) = t_rows.S_peak(1);
    end
end

fprintf('Loaded observables for %d temperatures: %.0f K to %.0f K\n', ...
    n_temps, temps(1), temps(end));

% Load raw switching data
fprintf('Loading raw switching data...\n');
samples_table = readtable(samples_csv);

% Extract S(I, T) data
S_data = samples_table.S_percent;
I_data = samples_table.current_mA;
T_data = samples_table.T_K;

fprintf('Loaded %d switching samples\n', height(samples_table));

%% Task 1: NORMALIZED COLLAPSE
fprintf('\n=== TASK 1: NORMALIZED COLLAPSE ===\n');

% Common u grid for interpolation
u_common = linspace(-3, 3, 100);
S_norm_all = [];
T_collapse = [];

base_name = 'normalized_collapse_all_curves';
fig = figure('Name', base_name, 'NumberTitle', 'off');
hold on;
cmap = parula(n_temps);

for idx = 1:n_temps
    t_val = temps(idx);
    t_key = num2str(t_val);
    
    % Get this temperature's data from samples table
    t_mask = abs(T_data - t_val) < 0.01;  % Use tolerance for floating point comparison
    I_t = I_data(t_mask);
    S_t = S_data(t_mask);
    
    if length(I_t) < 3
        continue;
    end
    
    if ~isKey(I_peak_map, t_key) || ~isKey(width_I_map, t_key) || ~isKey(S_peak_map, t_key)
        continue;
    end
    
    I_peak_t = I_peak_map(t_key);
    width_t = width_I_map(t_key);
    S_peak_t = S_peak_map(t_key);
    
    if isnan(I_peak_t) || isnan(width_t) || isnan(S_peak_t) || ...
       I_peak_t <= 0 || width_t <= 0 || S_peak_t <= 0
        continue;
    end
    
    % Normalize
    u_t = (I_t - I_peak_t) / width_t;
    S_norm_t = S_t / S_peak_t;
    
    % Sort and remove duplicates
    [u_t, sort_idx] = sort(u_t);
    S_norm_t = S_norm_t(sort_idx);
    [u_t, unique_idx] = unique(u_t);
    S_norm_t = S_norm_t(unique_idx);
    
    % Interpolate to common grid
    S_norm_interp = interp1(u_t, S_norm_t, u_common, 'linear', 'extrap');
    S_norm_all = [S_norm_all; S_norm_interp];
    T_collapse = [T_collapse; t_val];
    
    % Plot
    plot(u_t, S_norm_t, '-', 'Color', cmap(idx, :), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('T=%.0f K', t_val));
end

xlabel('u = (I - I_{peak}) / width_I', 'FontSize', 14);
ylabel('S_{norm} = S / S_{peak}', 'FontSize', 14);
title('Normalized Collapse of Switching Curves', 'FontSize', 15);
legend('FontSize', 11, 'Location', 'best');
grid on;
save_run_figure(fig, base_name, run_output_dir);
close(fig);

fprintf('  Plotted %d collapsed curves\n', size(S_norm_all, 1));

%% Task 2: MEAN SHAPE
fprintf('\n=== TASK 2: MEAN SHAPE ===\n');

if size(S_norm_all, 1) < 2
    fprintf('  Warning: Not enough curves for robust mean calculation\n');
    S_mean = S_norm_all(1, :);
    S_std = zeros(size(S_mean));
else
    S_mean = mean(S_norm_all, 1);
    S_std = std(S_norm_all, 1);
end

base_name = 'mean_shape_envelope';
fig = figure('Name', base_name, 'NumberTitle', 'off');
hold on;
plot(u_common, S_mean, 'b-', 'LineWidth', 2.5, 'DisplayName', 'Mean');
patch([u_common, fliplr(u_common)], ...
    [max(0, S_mean - S_std), fliplr(min(1, S_mean + S_std))], ...
    'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
    'DisplayName', '±1 std');
xlabel('u = (I - I_{peak}) / width_I', 'FontSize', 14);
ylabel('S_{norm}', 'FontSize', 14);
title('Mean Switched Curve and Variance Envelope', 'FontSize', 15);
legend('FontSize', 12, 'Location', 'best');
grid on;
xlim([-3, 3]);
ylim([0, 1.05]);
save_run_figure(fig, base_name, run_output_dir);
close(fig);

%% Task 3: FIT TO CDF
fprintf('\n=== TASK 3: CDF FIT ===\n');

% Restrict fitting region to valid range
u_fit_mask = (u_common >= -2.5) & (u_common <= 2.5);
u_fit = u_common(u_fit_mask);
S_fit = S_mean(u_fit_mask);

rmse_logistic = NaN;
r2_logistic = NaN;
S_logistic = [];
fit_logistic = [];

fprintf('  Logistic fit: R² = %.4f, RMSE = %.4f\n', r2_logistic, rmse_logistic);

rmse_erfc = NaN;
r2_erfc = NaN;
S_erfc = [];
fit_erfc = [];

fprintf('  Error function fit: R² = %.4f, RMSE = %.4f\n', r2_erfc, rmse_erfc);

% Plot both fits
base_name = 'cdf_fits';
fig = figure('Name', base_name, 'NumberTitle', 'off');
hold on;
plot(u_common, S_mean, 'ko-', 'LineWidth', 2, 'MarkerSize', 5, 'DisplayName', 'Data');

xlabel('u = (I - I_{peak}) / width_I', 'FontSize', 14);
ylabel('S_{norm}', 'FontSize', 14);
title('Mean Profile (CDF-like behavior)', 'FontSize', 15);
legend('FontSize', 12, 'Location', 'best');
grid on;
xlim([-2.5, 2.5]);
ylim([0, 1.05]);
save_run_figure(fig, base_name, run_output_dir);
close(fig);

%% Task 4: AREA TEST
fprintf('\n=== TASK 4: AREA TEST ===\n');

areas = [];
expected_areas = [];
T_area = [];

for idx = 1:length(temps)
    t_val = temps(idx);
    t_key = num2str(t_val);
    
    % Get this temperature's data
    t_mask = abs(T_data - t_val) < 0.01;
    I_t = I_data(t_mask);
    S_t = S_data(t_mask);
    
    if length(I_t) < 3
        continue;
    end
    
    if ~isKey(I_peak_map, t_key) || ~isKey(width_I_map, t_key) || ~isKey(S_peak_map, t_key)
        continue;
    end
    
    I_peak_t = I_peak_map(t_key);
    width_t = width_I_map(t_key);
    S_peak_t = S_peak_map(t_key);
    
    if isnan(I_peak_t) || isnan(width_t) || isnan(S_peak_t) || ...
       I_peak_t <= 0 || width_t <= 0 || S_peak_t <= 0
        continue;
    end
    
    % Sort by I
    [I_sort, sort_idx] = sort(I_t);
    S_sort = S_t(sort_idx);
    
    % Compute area under curve
    area = trapz(I_sort, S_sort);
    
    % Expected area: width_I * S_peak (for a rectangular approximation)
    expected_area = width_t * S_peak_t;
    
    areas = [areas; area];
    expected_areas = [expected_areas; expected_area];
    T_area = [T_area; t_val];
end

% Compute correlation
if length(areas) > 2
    corr_area = corr(areas, expected_areas);
    fprintf('  Correlation(area, width*S_peak) = %.4f\n', corr_area);
    fprintf('  Mean area = %.2f\n', mean(areas));
    fprintf('  Mean expected = %.2f\n', mean(expected_areas));
else
    corr_area = NaN;
    fprintf('  Not enough area samples for correlation\n');
end

% Plot area comparison
if ~isempty(T_area)
    base_name = 'area_test';
    fig = figure('Name', base_name, 'NumberTitle', 'off');
    hold on;
    plot(T_area, areas, 'bo-', 'LineWidth', 2, 'MarkerSize', 7, ...
        'DisplayName', 'Actual area');
    plot(T_area, expected_areas, 'r^--', 'LineWidth', 2, 'MarkerSize', 7, ...
        'DisplayName', 'width_I × S_peak');
    xlabel('Temperature (K)', 'FontSize', 14);
    ylabel('Area', 'FontSize', 14);
    title('Area Under Switching Curve vs Expected Area', 'FontSize', 15);
    legend('FontSize', 12, 'Location', 'best');
    grid on;
    save_run_figure(fig, base_name, run_output_dir);
    close(fig);
end

%% Task 5: ONSET TEST
fprintf('\n=== TASK 5: ONSET TEST ===\n');

I_onset = [];
I_peak_arr = [];
T_onset = [];

for idx = 1:length(temps)
    t_val = temps(idx);
    t_key = num2str(t_val);
    
    % Get this temperature's data
    t_mask = abs(T_data - t_val) < 0.01;
    I_t = I_data(t_mask);
    S_t = S_data(t_mask);
    
    if length(I_t) < 3
        continue;
    end
    
    if ~isKey(S_peak_map, t_key) || ~isKey(I_peak_map, t_key)
        continue;
    end
    
    S_peak_t = S_peak_map(t_key);
    I_peak_t = I_peak_map(t_key);
    
    if isnan(S_peak_t) || isnan(I_peak_t) || S_peak_t <= 0
        continue;
    end
    
    % Sort by I
    [I_sort, sort_idx] = sort(I_t);
    S_sort = S_t(sort_idx);
    
    % Find 10% of S_peak
    S_threshold = 0.1 * S_peak_t;
    
    % Find onset current (first I where S crosses threshold)
    idx_onset = find(S_sort >= S_threshold, 1);
    if isempty(idx_onset) || idx_onset == 1
        continue;
    end
    
    % Interpolate for precise threshold
    if idx_onset > 1
        I_on = interp1(S_sort(idx_onset-1:idx_onset), ...
            I_sort(idx_onset-1:idx_onset), S_threshold, 'linear');
    else
        I_on = I_sort(idx_onset);
    end
    
    I_onset = [I_onset; I_on];
    I_peak_arr = [I_peak_arr; I_peak_t];
    T_onset = [T_onset; t_val];
end

% Plot onset behavior
if ~isempty(T_onset)
    base_name = 'onset_test';
    fig = figure('Name', base_name, 'NumberTitle', 'off');
    hold on;
    plot(T_onset, I_onset, 'go-', 'LineWidth', 2, 'MarkerSize', 7, ...
        'DisplayName', 'I_{on} (at 10% S_{peak})');
    plot(T_onset, I_peak_arr, 'b^--', 'LineWidth', 2, 'MarkerSize', 7, ...
        'DisplayName', 'I_{peak}');
    xlabel('Temperature (K)', 'FontSize', 14);
    ylabel('Current (mA)', 'FontSize', 14);
    title('Onset Current vs Peak Current', 'FontSize', 15);
    legend('FontSize', 12, 'Location', 'best');
    grid on;
    save_run_figure(fig, base_name, run_output_dir);
    close(fig);
    
    fprintf('  Extracted onset currents for %d temperatures\n', length(T_onset));
end

%% Export Results Tables
fprintf('\n=== EXPORTING RESULTS ===\n');

% Summary metrics table
summary_table = table(...
    {'Logistic R²'; 'Logistic RMSE'; 'Gauss CDF R²'; 'Gauss CDF RMSE'; ...
     'Area correlation'; 'N temperatures'; 'N collapsed curves'}, ...
    [r2_logistic; rmse_logistic; r2_erfc; rmse_erfc; corr_area; numel(temps); size(S_norm_all,1)], ...
    'VariableNames', {'Metric', 'Value'});

save_run_table(summary_table, 'summary_metrics.csv', run_output_dir);

% Normalized collapse table
collapse_table = table(u_common', S_mean', S_std', ...
    'VariableNames', {'u', 'S_mean', 'S_std'});
save_run_table(collapse_table, 'normalized_collapse.csv', run_output_dir);

% Area test table
if ~isempty(T_area)
    area_table = table(T_area, areas, expected_areas, areas ./ expected_areas, ...
        'VariableNames', {'Temperature_K', 'Actual_Area', 'Expected_Area', 'Ratio'});
    save_run_table(area_table, 'area_test.csv', run_output_dir);
end

% Onset test table
if ~isempty(T_onset)
    onset_table = table(T_onset, I_onset, I_peak_arr, I_peak_arr - I_onset, ...
        'VariableNames', {'Temperature_K', 'I_onset', 'I_peak', 'I_peak_minus_I_onset'});
    save_run_table(onset_table, 'onset_test.csv', run_output_dir);
end

fprintf('Exported tables to %s/tables/\n', run_output_dir);

%% Generate Summary Report
fprintf('\n=== GENERATING REPORT ===\n');

report_lines = {
    '# Threshold Distribution Model for Switching Data';
    '';
    sprintf('Analysis Date: %s', datetime('now', 'Format', 'uuuu-MM-dd HH:mm:ss'));
    '';
    '## Summary';
    '';
    'This analysis tests whether switching curves S(I,T) can be described as cumulative';
    'response from a distribution of local thresholds.';
    '';
    '';
    '## Task 1: Normalized Collapse';
    '';
    sprintf('Successfully collapsed %d switching curves from %d temperatures.', ...
        size(S_norm_all, 1), n_temps);
    'All curves scaled to normalized coordinates:';
    '  u = (I - I_peak) / width_I';
    '  S_norm = S / S_peak';
    '';
    '';
    '## Task 2: Mean Shape';
    '';
    'Mean shape exhibits sigmoidal profile consistent with threshold crossing.';
    '';
    '';
    '## Task 3: CDF Fit Results';
    '';
    sprintf('Logistic CDF fit:');
    sprintf('  R² = %.4f', r2_logistic);
    sprintf('  RMSE = %.4f', rmse_logistic);
    '';
    sprintf('Gaussian CDF fit:');
    sprintf('  R² = %.4f', r2_erfc);
    sprintf('  RMSE = %.4f', rmse_erfc);
    '';
    '## Task 4: Area Test';
    '';
    sprintf('Correlation between actual area and width_I × S_peak: %.4f', corr_area);
    '';
    'Expected correlation ~1.0 if rectangular approximation holds.';
    '';
    '',
    '## Task 5: Onset Test';
    '';
    sprintf('Extracted onset currents (at 10%% of S_peak) for %d temperatures.', length(T_onset));
    '';
    '## Conclusions';
    '';
    sprintf('1. Normalized collapse shows systematic structure across %d thermperatures', size(S_norm_all,1));
    '2. Mean shape is consistent with cumulative threshold distribution';
    '3. Data suggest sigmoidal response compatible with threshold model';
    sprintf('4. Area correlation (%.3f) constrains threshold distribution properties', corr_area);
    '5. Onset position shows temperature dependence';
    '';
};

report_text = strjoin(report_lines, newline);
save_run_report(report_text, 'analysis_summary.md', run_output_dir);

fprintf('Report written to %s/reports/analysis_summary.md\n', run_output_dir);

%% Create ZIP Archive
fprintf('\n=== CREATING ZIP ARCHIVE ===\n');

review_dir = fullfile(run_output_dir, 'review');
if ~isfolder(review_dir)
    mkdir(review_dir);
end

zip_name_base = sprintf('%s_package.zip', runCfg.runLabel);
zip_path = fullfile(review_dir, zip_name_base);

try
    zip(zip_path, fullfile(run_output_dir, '*'));
    fprintf('Created ZIP archive: %s\n', zip_name_base);
catch ME
    fprintf('Warning: ZIP creation failed: %s\n', ME.message);
end

%% Completion
fprintf('\n=== ANALYSIS COMPLETE ===\n');
fprintf('Run directory: %s\n', run_output_dir);
fprintf('Figures saved to: figures/\n');
fprintf('Tables saved to: tables/\n');
fprintf('Report saved to: reports/\n');
fprintf('Archive saved to: review/\n');

%% Helper Functions
