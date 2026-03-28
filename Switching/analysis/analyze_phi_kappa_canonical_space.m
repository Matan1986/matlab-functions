%% PHI/KAPPA STABILITY IN CANONICAL NORMALIZED SPACE
% Recompute verdicts excluding raw_xy_delta
% Tasks: Filter to canonical space only; extract metrics; apply thresholds;
% write summary and status files with _canonical suffix

clear; clc;

%% SETUP
baseFolder = 'C:\Dev\matlab-functions';
addpath(genpath(fullfile(baseFolder, 'General ver2')));
addpath(genpath(fullfile(baseFolder, 'Tools ver1')));

tablesDir = fullfile(baseFolder, 'tables');

%% CREATE RUN CONTEXT
context = createRunContext('Switching', 'phi_kappa_canonical_space_analysis', ...
    fullfile(baseFolder, 'results', 'switching', 'runs'));
run_dir = context.run_dir;
output_tables_dir = context.table_output_dir;
output_reports_dir = context.report_output_dir;

%% INPUT FILES
summary_file = fullfile(baseFolder, 'tables', 'phi_kappa_stability_summary.csv');
status_file = fullfile(baseFolder, 'tables', 'phi_kappa_stability_status.csv');

%% READ EXISTING DATA
fprintf('Reading existing phi_kappa_stability tables...\n');

try
    summary_table = readtable(summary_file);
catch ME
    rethrow(ME);
end

try
    status_table = readtable(status_file);
catch ME
    rethrow(ME);
end

%% FILTER TO CANONICAL SPACE ONLY
% Keep only pairs where BOTH variants are in {xy_over_xx, baseline_aware}
canonical_variants = {'xy_over_xx', 'baseline_aware'};

pairs = summary_table.pair;
is_canonical = false(size(pairs));

for i = 1:length(pairs)
    pair_str = pairs{i};
    % Extract variant names from pair string (format: "variant_a vs variant_b")
    parts = strsplit(pair_str, ' vs ');
    if length(parts) == 2
        var_a = strtrim(parts{1});
        var_b = strtrim(parts{2});
        
        is_a_canonical = any(strcmp(var_a, canonical_variants));
        is_b_canonical = any(strcmp(var_b, canonical_variants));
        
        is_canonical(i) = is_a_canonical && is_b_canonical;
    end
end

canonical_summary = summary_table(is_canonical, :);

fprintf('\nCanonical Pairs (excluded raw_xy_delta):\n');
disp(canonical_summary);

%% EXTRACT METRICS FOR CANONICAL PAIRS
phi_shape_corrs = canonical_summary.phi_shape_corr;
kappa_corrs = canonical_summary.kappa_corr;
abs_kappa_corrs = canonical_summary.abs_kappa_corr;
kappa_signs = canonical_summary.kappa_sign;

% Check for residual_structure_corr if available
residual_available = ismember('residual_structure_corr', canonical_summary.Properties.VariableNames);
if residual_available
    residual_corrs = canonical_summary.residual_structure_corr;
else
    residual_corrs = nan(size(phi_shape_corrs));
end

%% APPLY THRESHOLDS
PHI_THRESHOLD = 0.90;
KAPPA_THRESHOLD = 0.90;
RESIDUAL_THRESHOLD = 0.95;

phi_pair_stable_vec = phi_shape_corrs >= PHI_THRESHOLD;
kappa_pair_stable_vec = abs_kappa_corrs >= KAPPA_THRESHOLD;

if residual_available
    residual_stable_vec = residual_corrs >= RESIDUAL_THRESHOLD;
else
    residual_stable_vec = true(size(residual_corrs));
end

%% DETERMINE KAPPA SIGN STATUS
% All canonical pairs should have consistent signs
kappa_signs_set = unique(kappa_signs);

if length(kappa_signs_set) == 1
    kappa_sign_status = 'CONSISTENT';
elseif length(kappa_signs_set) == 2
    % Mixed signs
    kappa_sign_status = 'INCONSISTENT';
else
    kappa_sign_status = 'AMBIGUOUS';
end

%% COMPUTE OVERALL VERDICTS IN CANONICAL SPACE
% Phi stable if ALL canonical pairs have phi_shape_corr >= 0.90
phi_stable_in_canonical = all(phi_pair_stable_vec);

% Kappa stable if ALL canonical pairs have |kappa_corr| >= 0.90
kappa_stable_in_canonical = all(kappa_pair_stable_vec);

% Phi invariant = Phi stable in canonical space
phi_canonical_invariant = phi_stable_in_canonical;

% Kappa sign consistent = all pairs have consistent sign
kappa_canonical_sign_consistent = strcmp(kappa_sign_status, 'CONSISTENT');

%% WRITE PAIR SUMMARY (canonical only)
output_summary_file = fullfile(output_tables_dir, 'phi_kappa_stability_canonical_summary.csv');

output_summary = canonical_summary(:, {'pair', 'phi_shape_corr', 'kappa_corr', 'abs_kappa_corr', ...
    'PHI_PAIR_STABLE', 'KAPPA_PAIR_STABLE', 'KAPPA_SIGN_STATUS'});

if residual_available
    output_summary = [output_summary, canonical_summary(:, {'residual_structure_corr'})];
else
    % Add NaN column for residual_structure_corr
    output_summary.residual_structure_corr = nan(height(output_summary), 1);
end

try
    writetable(output_summary, output_summary_file);
catch ME
    rethrow(ME);
end
fprintf('\nWrote: %s\n', output_summary_file);

%% WRITE STATUS FILE (canonical only)
output_status_file = fullfile(output_tables_dir, 'phi_kappa_stability_canonical_status.csv');

status_data = table();
status_data.EXECUTION_STATUS = {'SUCCESS'};
status_data.PHI_STABLE_IN_CANONICAL_SPACE = {char(phi_stable_in_canonical)};
status_data.KAPPA_STABLE_IN_CANONICAL_SPACE = {char(kappa_stable_in_canonical)};
status_data.PHI_CANONICAL_INVARIANT = {char(phi_canonical_invariant)};
status_data.KAPPA_CANONICAL_SIGN_CONSISTENT = {char(kappa_canonical_sign_consistent)};
status_data.EXCLUDED_VARIANT = {'raw_xy_delta'};

notes = sprintf('analysis=canonical_only; canonical_pairs=%d; phi_threshold=%.2f; kappa_threshold=%.2f; residual_threshold=%.2f', ...
    height(output_summary), PHI_THRESHOLD, KAPPA_THRESHOLD, RESIDUAL_THRESHOLD);
status_data.NOTES = {notes};

try
    writetable(status_data, output_status_file);
catch ME
    rethrow(ME);
end
fprintf('Wrote: %s\n', output_status_file);

%% CONVERT VERDICTS TO STRING FOR OUTPUT
if phi_stable_in_canonical
    phi_verdict = 'YES';
else
    phi_verdict = 'NO';
end

if kappa_stable_in_canonical
    kappa_verdict = 'YES';
else
    kappa_verdict = 'NO';
end

if phi_canonical_invariant
    phi_inv_verdict = 'YES';
else
    phi_inv_verdict = 'NO';
end

if kappa_canonical_sign_consistent
    kappa_sign_verdict = 'YES';
else
    kappa_sign_verdict = 'NO';
end

%% WRITE EXECUTION STATUS
execution_status_file = fullfile(output_tables_dir, 'execution_status.csv');
execution_status = table();
execution_status.SCRIPT = {'analyze_phi_kappa_canonical_space.m'};
execution_status.STATUS = {'SUCCESS'};
execution_status.DESCRIPTION = {'Canonical normalized space verdict recompute'};
execution_status.PHI_VERDICT = {phi_verdict};
execution_status.KAPPA_VERDICT = {kappa_verdict};
execution_status.PHI_INVARIANT = {phi_inv_verdict};
execution_status.KAPPA_SIGN_CONSISTENT = {kappa_sign_verdict};
execution_status.CANONICAL_PAIRS = {sprintf('%d', height(output_summary))};
execution_status.TIMESTAMP = {datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')};

try
    writetable(execution_status, execution_status_file);
catch ME
    rethrow(ME);
end
fprintf('Wrote: %s\n', execution_status_file);

%% WRITE BRIEF REPORT
report_file = fullfile(output_reports_dir, 'phi_kappa_canonical_analysis_report.md');

try
    fid = fopen(report_file, 'w');
    fprintf(fid, '# Phi/Kappa Stability in Canonical Normalized Space\n\n');
    fprintf(fid, '## Summary\n\n');
    fprintf(fid, '**Analysis Date:** %s\n\n', datetime('now'));
    fprintf(fid, '### Verdicts\n\n');
    fprintf(fid, '- **PHI_STABLE_IN_CANONICAL_SPACE:** %s\n', phi_verdict);
    fprintf(fid, '- **KAPPA_STABLE_IN_CANONICAL_SPACE:** %s\n', kappa_verdict);
    fprintf(fid, '- **PHI_CANONICAL_INVARIANT:** %s\n', phi_inv_verdict);
    fprintf(fid, '- **KAPPA_CANONICAL_SIGN_CONSISTENT:** %s\n\n', kappa_sign_verdict);
    
    fprintf(fid, '### Configuration\n\n');
    fprintf(fid, '- **Excluded Variant:** raw_xy_delta\n');
    fprintf(fid, '- **Canonical Variants:** xy_over_xx, baseline_aware\n');
    fprintf(fid, '- **Phi Threshold:** >= %.2f\n', PHI_THRESHOLD);
    fprintf(fid, '- **Kappa Threshold:** >= %.2f\n', KAPPA_THRESHOLD);
    fprintf(fid, '- **Residual Threshold:** >= %.2f\n\n', RESIDUAL_THRESHOLD);
    
    fprintf(fid, '### Pair Analysis\n\n');
    fprintf(fid, '**Canonical pairs analyzed: %d**\n\n', height(output_summary));
    fprintf(fid, '| Pair | Phi Shape Corr | Kappa Corr | |Kappa| | Phi Stable | Kappa Stable | Sign Status |\n');
    fprintf(fid, '|------|---|---|---|---|---|---|\n');
    for i = 1:height(output_summary)
        phi_sc = output_summary.phi_shape_corr(i);
        kappa_c = output_summary.kappa_corr(i);
        abs_kappa_c = output_summary.abs_kappa_corr(i);
        phi_st = output_summary.PHI_PAIR_STABLE(i);
        kappa_st = output_summary.KAPPA_PAIR_STABLE(i);
        sign_st = output_summary.KAPPA_SIGN_STATUS(i);
        fprintf(fid, '| %s | %.6f | %.6f | %.6f | %s | %s | %s |\n', ...
            output_summary.pair{i}, phi_sc, kappa_c, abs_kappa_c, phi_st, kappa_st, sign_st);
    end
    fprintf(fid, '\n## Justification\n\n');
    fprintf(fid, 'This analysis computes Phi/Kappa stability verdict in **canonical normalized space only**.\n\n');
    fprintf(fid, '**Reason:** `raw_xy_delta` cannot be used to judge Phi invariance because:\n');
    fprintf(fid, '- Phi amplitude is carried by the scale sector (through S_peak / kappa coupling)\n');
    fprintf(fid, '- Raw representation can create false non-invariance for Phi\n');
    fprintf(fid, '- Physical verdict must be based only on normalized/canonical variants\n\n');
    fprintf(fid, '**Canonical Space:** Only pairs composed of `xy_over_xx` and `baseline_aware` variants\n\n');
    fprintf(fid, '## Output Files\n\n');
    fprintf(fid, '- `phi_kappa_stability_canonical_summary.csv` - Pair metrics\n');
    fprintf(fid, '- `phi_kappa_stability_canonical_status.csv` - Execution status\n');
    fprintf(fid, '- `execution_status.csv` - Script execution record\n');
    
    fclose(fid);
catch ME
    rethrow(ME);
end
fprintf('Wrote: %s\n', report_file);

%% PRINT VERDICTS
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('PHI/KAPPA STABILITY VERDICT IN CANONICAL NORMALIZED SPACE\n');
fprintf('%s\n', repmat('=', 1, 70));
fprintf('KAPPA_STABLE_IN_CANONICAL_SPACE=%s\n', kappa_verdict);
fprintf('PHI_CANONICAL_INVARIANT=%s\n', phi_inv_verdict);
fprintf('KAPPA_CANONICAL_SIGN_CONSISTENT=%s\n', kappa_sign_verdict);
fprintf('EXECUTION_STATUS=SUCCESS\n');

fprintf('\n%s\n', repmat('-', 1, 70));
fprintf('DETAILS:\n');
fprintf('%s\n', repmat('-', 1, 70));
fprintf('Canonical pairs analyzed: %d\n', height(output_summary));
fprintf('Thresholds: phi>=%.2f, |kappa|>=%.2f, residual>=%.2f\n', PHI_THRESHOLD, KAPPA_THRESHOLD, RESIDUAL_THRESHOLD);
fprintf('Excluded variant: raw_xy_delta\n');
fprintf('\nPair metrics:\n');
disp(output_summary);

fprintf('\nStatus:\n');
disp(status_data);

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('SUCCESS: Canonical space analysis complete\n');
fprintf('%s\n', repmat('=', 1, 70));
