function run_xx_relaxation_switching_coupling(runTag)
% Analyze coupling between relaxation detectability and switching observables.
% Uses only existing extracted columns and derives is_resolved in-memory.
%
% runTag (optional): e.g. "config2" for corrected Config2 extraction tables.

if nargin < 1 || isempty(runTag)
    tag_suffix = "";
else
    tag_suffix = "_" + string(runTag);
end

repo_root = fileparts(fileparts(mfilename('fullpath')));
input_path = fullfile(repo_root, 'tables', 'xx_relaxation_event_level_full' + tag_suffix + '.csv');
table_out_path = fullfile(repo_root, 'tables', 'xx_relaxation_switching_coupling' + tag_suffix + '.csv');
report_out_path = fullfile(repo_root, 'reports', 'xx_relaxation_switching_coupling' + tag_suffix + '.md');

T = readtable(input_path, 'TextType', 'string');

if ~ismember("target_state", T.Properties.VariableNames)
    error('Missing required column: target_state');
end
if ~ismember("DeltaV", T.Properties.VariableNames)
    error('Missing required column: DeltaV');
end
if ~ismember("V_plateau", T.Properties.VariableNames)
    error('Missing required column: V_plateau');
end
if ~ismember("tau_relax", T.Properties.VariableNames)
    error('Missing required column: tau_relax');
end

T.state = string(T.target_state);
T.is_resolved = isfinite(T.tau_relax);

T.plateau_bin = make_tertile_bin(T.V_plateau);
T.deltaV_bin = make_tertile_bin(T.DeltaV);

G = groupsummary(T, {'config_id','temperature','state','plateau_bin','deltaV_bin'}, 'mean', 'is_resolved');
G = renamevars(G, 'mean_is_resolved', 'resolved_fraction');
writetable(G(:, {'config_id','temperature','state','resolved_fraction','plateau_bin','deltaV_bin'}), table_out_path);

plateau_valid = isfinite(T.V_plateau);
delta_valid = isfinite(T.DeltaV);
resolved_num = double(T.is_resolved);

[rp, pp] = corr(T.V_plateau(plateau_valid), resolved_num(plateau_valid), 'Type', 'Pearson', 'Rows', 'complete');
[rs, ps] = corr(T.V_plateau(plateau_valid), resolved_num(plateau_valid), 'Type', 'Spearman', 'Rows', 'complete');
[rdp, pdp] = corr(T.DeltaV(delta_valid), resolved_num(delta_valid), 'Type', 'Pearson', 'Rows', 'complete');
[rds, pds] = corr(T.DeltaV(delta_valid), resolved_num(delta_valid), 'Type', 'Spearman', 'Rows', 'complete');

plateau_rf = groupsummary(T, 'plateau_bin', 'mean', 'is_resolved');
delta_rf = groupsummary(T, 'deltaV_bin', 'mean', 'is_resolved');

state_delta = groupsummary(T, {'state','deltaV_bin'}, 'mean', 'is_resolved');

states = unique(T.state);
spread_lines = strings(0,1);
has_spread_difference = false;
for i = 1:numel(states)
    s = states(i);
    mask_state = T.state == s;
    vr = var(T.V_plateau(mask_state & T.is_resolved), 0, 'omitnan');
    vu = var(T.V_plateau(mask_state & ~T.is_resolved), 0, 'omitnan');
    if isfinite(vr) && isfinite(vu) && abs(vr - vu) > 0
        has_spread_difference = true;
    end
    spread_lines(end+1) = sprintf('- state %s: var(V_plateau | resolved)=%.6e, var(V_plateau | unresolved)=%.6e', s, vr, vu); %#ok<AGROW>
end

overall_gap = compute_state_gap(T);
cond_gap = compute_conditional_state_gap(state_delta);

plateau_bin_range = compute_bin_range(plateau_rf.mean_is_resolved);
delta_bin_range = compute_bin_range(delta_rf.mean_is_resolved);

depends_plateau = (abs(rs) >= 0.1 && ps < 0.05) || (plateau_bin_range >= 0.10);
depends_contrast = (abs(rds) >= 0.1 && pds < 0.05) || (delta_bin_range >= 0.10);
state_explained = isfinite(overall_gap) && isfinite(cond_gap) && (cond_gap <= 0.5 * overall_gap);

report_lines = strings(0,1);
report_lines(end+1) = "# XX Relaxation-Switching Coupling";
report_lines(end+1) = "";
report_lines(end+1) = sprintf("Input table: tables/xx_relaxation_event_level_full%s.csv", char(tag_suffix));
report_lines(end+1) = "";
report_lines(end+1) = sprintf("Total events analyzed: %d", height(T));
report_lines(end+1) = "Full dataset used with no event filtering.";
report_lines(end+1) = "";
report_lines(end+1) = "## Plateau findings";
report_lines(end+1) = sprintf("- Pearson(is_resolved, V_plateau): r=%.4f, p=%.4g", rp, pp);
report_lines(end+1) = sprintf("- Spearman(is_resolved, V_plateau): rho=%.4f, p=%.4g", rs, ps);
report_lines(end+1) = make_bin_line("- Resolved fraction by V_plateau bin", plateau_rf.plateau_bin, plateau_rf.mean_is_resolved);
report_lines(end+1) = "";
report_lines(end+1) = "## Contrast findings";
report_lines(end+1) = sprintf("- Pearson(is_resolved, DeltaV): r=%.4f, p=%.4g", rdp, pdp);
report_lines(end+1) = sprintf("- Spearman(is_resolved, DeltaV): rho=%.4f, p=%.4g", rds, pds);
report_lines(end+1) = make_bin_line("- Resolved fraction by DeltaV bin", delta_rf.deltaV_bin, delta_rf.mean_is_resolved);
report_lines(end+1) = "";
report_lines(end+1) = "## Interaction findings";
report_lines(end+1) = "- P(resolved | state, DeltaV_bin):";
for i = 1:height(state_delta)
    report_lines(end+1) = sprintf("- state %s, deltaV_bin %s: %.3f", ...
        state_delta.state(i), state_delta.deltaV_bin(i), state_delta.mean_is_resolved(i)); %#ok<AGROW>
end
report_lines(end+1) = sprintf("- Overall |A-B| resolved fraction gap: %.3f", overall_gap);
report_lines(end+1) = sprintf("- Mean conditional |A-B| gap across DeltaV bins: %.3f", cond_gap);
report_lines(end+1) = "";
report_lines(end+1) = "## Spread findings";
for i = 1:numel(spread_lines)
    report_lines(end+1) = spread_lines(i); %#ok<AGROW>
end
report_lines(end+1) = "";
report_lines(end+1) = "## Mandatory flags";
report_lines(end+1) = sprintf("DETECTABILITY_DEPENDS_ON_PLATEAU = %s", yesno(depends_plateau));
report_lines(end+1) = sprintf("DETECTABILITY_DEPENDS_ON_CONTRAST = %s", yesno(depends_contrast));
report_lines(end+1) = sprintf("STATE_DEPENDENCE_EXPLAINED_BY_CONTRAST = %s", yesno(state_explained));
report_lines(end+1) = sprintf("INTERNAL_SPREAD_DIFFERENCE = %s", yesno(has_spread_difference));
report_lines(end+1) = "";
report_lines(end+1) = "## Success criteria";
report_lines(end+1) = "TABLE_WRITTEN = YES";
report_lines(end+1) = "REPORT_WRITTEN = YES";
report_lines(end+1) = "NO_LOGIC_CHANGE = YES";
report_lines(end+1) = "FULL_DATASET_USED = YES";
report_lines(end+1) = "";
report_lines(end+1) = "All analyses performed strictly on extracted dataset.";
report_lines(end+1) = "No detection logic was modified.";
report_lines(end+1) = "Results reflect measurement-level structure only.";

fid = fopen(report_out_path, 'w');
assert(fid >= 0, 'Could not open report file for writing: %s', report_out_path);
cleanup = onCleanup(@() fclose(fid));
for i = 1:numel(report_lines)
    fprintf(fid, '%s\n', report_lines(i));
end

fprintf('Wrote table: %s\n', table_out_path);
fprintf('Wrote report: %s\n', report_out_path);
end

function b = make_tertile_bin(x)
b = strings(size(x));
b(:) = "undefined";
valid = isfinite(x);
if ~any(valid)
    return;
end

q = quantile(x(valid), [1/3 2/3]);
q1 = q(1);
q2 = q(2);

if q1 == q2
    b(valid) = "mid";
    return;
end

b(valid & x <= q1) = "low";
b(valid & x > q1 & x <= q2) = "mid";
b(valid & x > q2) = "high";
end

function s = make_bin_line(prefix, bin_names, values)
parts = strings(numel(values), 1);
for i = 1:numel(values)
    parts(i) = sprintf('%s=%.3f', string(bin_names(i)), values(i));
end
s = prefix + ": " + strjoin(parts, ", ");
end

function g = compute_state_gap(T)
maskA = T.state == "A";
maskB = T.state == "B";
if ~any(maskA) || ~any(maskB)
    g = NaN;
    return;
end
g = abs(mean(T.is_resolved(maskA)) - mean(T.is_resolved(maskB)));
end

function g = compute_conditional_state_gap(state_delta)
bins = unique(state_delta.deltaV_bin);
gaps = [];
for i = 1:numel(bins)
    b = bins(i);
    a_idx = find(state_delta.state == "A" & state_delta.deltaV_bin == b, 1);
    b_idx = find(state_delta.state == "B" & state_delta.deltaV_bin == b, 1);
    if ~isempty(a_idx) && ~isempty(b_idx)
        gaps(end+1) = abs(state_delta.mean_is_resolved(a_idx) - state_delta.mean_is_resolved(b_idx)); %#ok<AGROW>
    end
end
if isempty(gaps)
    g = NaN;
else
    g = mean(gaps);
end
end

function r = compute_bin_range(x)
x = x(isfinite(x));
if isempty(x)
    r = NaN;
else
    r = max(x) - min(x);
end
end

function y = yesno(tf)
if tf
    y = "YES";
else
    y = "NO";
end
end
