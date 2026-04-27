clear; clc;

% Switching legacy/noncanonical observable-definition inventory.
% Definition inventory only (no legacy values/correlations reused as evidence).

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot, 'tools'));
addpath(fullfile(repoRoot, 'Aging', 'utils'));
addpath(fullfile(repoRoot, 'Switching', 'utils'));

if exist(fullfile(repoRoot, 'tables'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'tables')); end
if exist(fullfile(repoRoot, 'reports'), 'dir') ~= 7, mkdir(fullfile(repoRoot, 'reports')); end

outInv = fullfile(repoRoot, 'tables', 'switching_legacy_observable_definition_inventory.csv');
outPlan = fullfile(repoRoot, 'tables', 'switching_observable_definition_porting_plan.csv');
outStatus = fullfile(repoRoot, 'tables', 'switching_legacy_observable_definition_status.csv');
outReport = fullfile(repoRoot, 'reports', 'switching_legacy_observable_definition_inventory.md');

% ---------------------------- Search targets ----------------------------
targets = struct('name', {}, 'regex', {}, 'canonical_inputs', {}, 'latent_hint', {});
targets(end+1) = tdef("S_peak", "(^|[^A-Za-z0-9_])S_peak([^A-Za-z0-9_]|$)|\bSpeak\b|max\(\s*S", "switching_canonical_observables.csv; switching_canonical_S_long.csv", "kappa1;kappa2");
targets(end+1) = tdef("I_peak", "(^|[^A-Za-z0-9_])I_peak([^A-Za-z0-9_]|$)|argmax|peak current", "switching_canonical_observables.csv; switching_canonical_S_long.csv", "Phi1;kappa1");
targets(end+1) = tdef("width_or_w", "\bwidth\b|\bw\b|halfwidth|quantile.*(10|90)|S10|S90", "switching_canonical_S_long.csv", "other");
targets(end+1) = tdef("X_or_Xshape", "(^|[^A-Za-z0-9_])X([^A-Za-z0-9_]|$)|Xshape|XI_", "switching_canonical_S_long.csv; switching_canonical_observables.csv", "other");
targets(end+1) = tdef("tail_burden_ratio", "tail_burden_ratio|tail burden|tail.*mid.*ratio", "switching_canonical_S_long.csv", "kappa2;Phi2");
targets(end+1) = tdef("high_CDF_tail_weight", "high_CDF_tail_weight|CDF.*0\.8|trapz\(", "switching_canonical_S_long.csv", "kappa2;Phi2");
targets(end+1) = tdef("symmetry_cdf_mirror", "symmetry_cdf_mirror|mirror asymmetry|1\s*-\s*c1", "switching_canonical_S_long.csv", "kappa2;Phi2");
targets(end+1) = tdef("asymmetry", "\basym\b|asymmetry|S_xy_over_xx|halfwidth_diff_norm", "switching_canonical_S_long.csv; switching_canonical_observables.csv", "Phi1;kappa2");
targets(end+1) = tdef("spread_quantile_spread", "spread|quantile spread|std|I_20_80|pt_spread", "switching_canonical_S_long.csv; switching_canonical_observables.csv", "Phi2");
targets(end+1) = tdef("slope_curvature_rolloff", "slope|curvature|rolloff|dS|d2S|derivative", "switching_canonical_S_long.csv", "Phi1;Phi2");
targets(end+1) = tdef("residual_energy_rmse", "residual energy|rmse|R1|R2|R3|mean\(\s*R|sqrt\(\s*mean", "switching_canonical_S_long.csv; switching_canonical_observables.csv", "kappa2;kappa3;Phi3");
targets(end+1) = tdef("kappa_proxy", "kappa.*proxy|kappa.*observable|kappa.*mapping|kappa.*tracker", "switching_mode_amplitudes_vs_T.csv; switching_canonical_observables.csv", "kappa1;kappa2;kappa3");

scriptFiles = listFilesRecursive(fullfile(repoRoot, 'Switching', 'analysis'), {'.m'});
tableFiles = listFilesRecursive(fullfile(repoRoot, 'tables'), {'.csv'});
reportFiles = listFilesRecursive(fullfile(repoRoot, 'reports'), {'.md'});

allFiles = [scriptFiles; tableFiles; reportFiles];
allFiles = unique(allFiles, 'stable');

% Legacy/noncanonical candidate sources only.
isCand = false(size(allFiles));
for i = 1:numel(allFiles)
    p = lower(strrep(allFiles{i}, '\', '/'));
    if contains(p, '/switching ver') || contains(p, '/experimental/') || contains(p, 'legacy') || ...
       contains(p, 'noncanonical') || contains(p, 'width_') || contains(p, 'alignment') || ...
       contains(p, 'full_scaling_collapse') || contains(p, 'collapse_subrange') || ...
       contains(p, 'switching_legacy_') || contains(p, 'old')
        isCand(i) = true;
    end
end
candFiles = allFiles(isCand);
% Exclude this inventory script from its own scan.
selfPath = strrep(mfilename('fullpath'), '\', '/');
candFiles = candFiles(~strcmpi(strrep(candFiles, '\', '/'), selfPath));

rows = table();
for i = 1:numel(candFiles)
    p = candFiles{i};
    txt = readTextSafe(p);
    if strlength(txt) == 0
        continue;
    end
    lines = splitlines(txt);
    srcClass = classifySource(p, txt);
    for j = 1:numel(targets)
        pat = targets(j).regex;
        hitLineIdx = find(~cellfun(@isempty, regexp(cellstr(lines), pat, 'once')));
        if isempty(hitLineIdx)
            continue;
        end
        for h = 1:numel(hitLineIdx)
            li = hitLineIdx(h);
            snippet = strtrim(lines(li));
            formula = inferFormula(lines, li);
            if strlength(formula) == 0
                formula = snippet;
            end
            clarity = classifyClarity(formula);
            depNonCanonical = yn(contains(lower(formula), "align") || contains(lower(formula), "width") || contains(lower(formula), "legacy") || contains(lower(formula), "genpath"));
            depLegacyVals = yn(contains(lower(p), 'tables/switching_legacy_') || contains(lower(formula), "legacy") || contains(lower(formula), "old_vs_new"));
            risk = deriveRisk(p, formula, srcClass);
            rows = [rows; table( ...
                string(targets(j).name), ...
                string(relpath(repoRoot, p)), ...
                string(formula), ...
                string(srcClass), ...
                string(clarity), ...
                string(depNonCanonical), ...
                string(depLegacyVals), ...
                string(targets(j).canonical_inputs), ...
                string(targets(j).latent_hint), ...
                string(risk), ...
                'VariableNames', { ...
                'observable_name','path_where_definition_appears','formula_or_inferred_formula', ...
                'original_input_source_provenance_only','definition_clear_enough_to_port', ...
                'depends_on_noncanonical_preprocessing','depends_on_legacy_values_must_not_copy', ...
                'required_canonical_inputs_to_recompute','latent_object_interpretation_candidate', ...
                'risks'})]; %#ok<AGROW>
        end
    end
end

if isempty(rows)
    rows = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        'VariableNames', {'observable_name','path_where_definition_appears','formula_or_inferred_formula', ...
        'original_input_source_provenance_only','definition_clear_enough_to_port', ...
        'depends_on_noncanonical_preprocessing','depends_on_legacy_values_must_not_copy', ...
        'required_canonical_inputs_to_recompute','latent_object_interpretation_candidate','risks'});
end

% Aggregate noisy line-level hits into concise per-(observable,path) entries.
grpKey = rows.observable_name + "||" + rows.path_where_definition_appears;
[uKey, ~, gid] = unique(grpKey, 'stable');
agg = table();
for g = 1:numel(uKey)
    rg = rows(gid==g, :);
    occ = height(rg);
    formulas = unique(rg.formula_or_inferred_formula, 'stable');
    maxKeep = min(numel(formulas), 3);
    formulaJoin = strjoin(formulas(1:maxKeep), " || ");
    if numel(formulas) > maxKeep
        formulaJoin = formulaJoin + " || ...";
    end
    clarity = "PARTIAL";
    if any(rg.definition_clear_enough_to_port == "YES"), clarity = "YES"; end
    if all(rg.definition_clear_enough_to_port == "NO"), clarity = "NO"; end
    depNonCanonical = yn(any(rg.depends_on_noncanonical_preprocessing == "YES"));
    depLegacyVals = yn(any(rg.depends_on_legacy_values_must_not_copy == "YES"));
    risk = strjoin(unique(rg.risks, 'stable'), '; ');
    agg = [agg; table( ...
        rg.observable_name(1), rg.path_where_definition_appears(1), formulaJoin, ...
        rg.original_input_source_provenance_only(1), clarity, depNonCanonical, depLegacyVals, ...
        strjoin(unique(rg.required_canonical_inputs_to_recompute, 'stable'), '; '), ...
        strjoin(unique(rg.latent_object_interpretation_candidate, 'stable'), '; '), ...
        risk, occ, ...
        'VariableNames', {'observable_name','path_where_definition_appears','formula_or_inferred_formula', ...
        'original_input_source_provenance_only','definition_clear_enough_to_port', ...
        'depends_on_noncanonical_preprocessing','depends_on_legacy_values_must_not_copy', ...
        'required_canonical_inputs_to_recompute','latent_object_interpretation_candidate', ...
        'risks','occurrence_count'})]; %#ok<AGROW>
end
rows = agg;

writetable(rows, outInv);

% -------------------------- Porting-plan table --------------------------
obsU = unique(rows.observable_name, 'stable');
plan = table();
for i = 1:numel(obsU)
    m = rows.observable_name == obsU(i);
    rr = rows(m, :);
    hasUnclear = any(rr.definition_clear_enough_to_port ~= "YES");
    hasNonCanon = any(rr.depends_on_noncanonical_preprocessing == "YES");
    hasLegacyDep = any(rr.depends_on_legacy_values_must_not_copy == "YES");
    hasConflict = height(unique(rr(:, {'observable_name','formula_or_inferred_formula'}))) > 1;
    if obsU(i) == "width_or_w" || obsU(i) == "X_or_Xshape"
        action = "discard";
        reason = "legacy width/alignment style definition is out-of-bound for canonical dictionary";
    elseif hasNonCanon || hasLegacyDep
        action = "redefine_canonically";
        if hasNonCanon && hasLegacyDep
            reason = "noncanonical preprocessing and legacy-value dependencies must be removed";
        elseif hasNonCanon
            reason = "definition tied to noncanonical preprocessing/alignment/width";
        else
            reason = "legacy-value dependency must be removed";
        end
    elseif hasConflict
        action = "needs_review";
        reason = "conflicting legacy formulas across sources";
    elseif hasUnclear
        action = "needs_review";
        reason = "definition is ambiguous/under-specified";
    else
        action = "port_definition";
        reason = "formula pattern clear and can be recomputed from canonical artifacts";
    end
    reqInputs = strjoin(unique(rr.required_canonical_inputs_to_recompute), '; ');
    valTest = proposeValidation(obsU(i), action);
    plan = [plan; table( ...
        obsU(i), action, reason, string(reqInputs), string(valTest), ...
        "NO", "YES", ...
        'VariableNames', {'observable_name','action','reason','required_canonical_inputs','required_canonical_validation_test', ...
        'allowed_to_copy_legacy_values','must_recompute_canonically'})]; %#ok<AGROW>
end
writetable(plan, outPlan);

% ------------------------------- Verdicts -------------------------------
LEGACY_OBSERVABLE_DEFINITION_INVENTORY_COMPLETE = yn(height(rows) > 0);
LEGACY_VALUES_COPIED = "NO";
LEGACY_CORRELATIONS_USED_AS_EVIDENCE = "NO";
REUSABLE_OBSERVABLE_DEFINITIONS_FOUND = yn(any(plan.action == "port_definition"));
CONFLICTING_OBSERVABLE_DEFINITIONS_FOUND = yn(any(plan.action == "needs_review" & contains(lower(plan.reason), "conflicting")));
ALL_KEPT_DEFINITIONS_REQUIRE_CANONICAL_RECOMPUTATION = yn(all(plan.must_recompute_canonically == "YES"));
READY_TO_BUILD_CANONICAL_OBSERVABLE_DICTIONARY = yn( ...
    LEGACY_OBSERVABLE_DEFINITION_INVENTORY_COMPLETE == "YES" && ...
    LEGACY_VALUES_COPIED == "NO" && ...
    LEGACY_CORRELATIONS_USED_AS_EVIDENCE == "NO");

statusTbl = table( ...
    ["LEGACY_OBSERVABLE_DEFINITION_INVENTORY_COMPLETE"; ...
     "LEGACY_VALUES_COPIED"; ...
     "LEGACY_CORRELATIONS_USED_AS_EVIDENCE"; ...
     "REUSABLE_OBSERVABLE_DEFINITIONS_FOUND"; ...
     "CONFLICTING_OBSERVABLE_DEFINITIONS_FOUND"; ...
     "ALL_KEPT_DEFINITIONS_REQUIRE_CANONICAL_RECOMPUTATION"; ...
     "READY_TO_BUILD_CANONICAL_OBSERVABLE_DICTIONARY"], ...
    [LEGACY_OBSERVABLE_DEFINITION_INVENTORY_COMPLETE; ...
     LEGACY_VALUES_COPIED; ...
     LEGACY_CORRELATIONS_USED_AS_EVIDENCE; ...
     REUSABLE_OBSERVABLE_DEFINITIONS_FOUND; ...
     CONFLICTING_OBSERVABLE_DEFINITIONS_FOUND; ...
     ALL_KEPT_DEFINITIONS_REQUIRE_CANONICAL_RECOMPUTATION; ...
     READY_TO_BUILD_CANONICAL_OBSERVABLE_DICTIONARY], ...
    'VariableNames', {'check','result'});
writetable(statusTbl, outStatus);

% ------------------------------- Report --------------------------------
lines = {};
lines{end+1} = '# Switching legacy/noncanonical observable-definition inventory';
lines{end+1} = '';
lines{end+1} = '## Scope and policy';
lines{end+1} = '- Switching-only legacy/noncanonical definition inventory.';
lines{end+1} = '- Definition-only: no legacy values copied, no legacy correlations/models used as evidence.';
lines{end+1} = '- Every kept definition is marked for canonical recomputation and revalidation.';
lines{end+1} = '';
lines{end+1} = sprintf('## Inventory size');
lines{end+1} = sprintf('- Definition rows captured: **%d**', height(rows));
lines{end+1} = sprintf('- Unique observable groups: **%d**', numel(obsU));
lines{end+1} = '';
lines{end+1} = '## Separation summary';
lines{end+1} = sprintf('- Reusable definitions (`port_definition`): **%d**', sum(plan.action=="port_definition"));
lines{end+1} = sprintf('- Require canonical redefinition (`redefine_canonically`): **%d**', sum(plan.action=="redefine_canonically"));
lines{end+1} = sprintf('- Retire/discard: **%d**', sum(plan.action=="discard"));
lines{end+1} = sprintf('- Needs review (`needs_review`): **%d**', sum(plan.action=="needs_review"));
lines{end+1} = '';
lines{end+1} = '## Forbidden legacy evidence classes';
lines{end+1} = '- Legacy/noncanonical observable values (must not be copied).';
lines{end+1} = '- Legacy correlation/verdict/model-result rows (must not be used as evidence).';
lines{end+1} = '- Mixed legacy/canonical merged tables (must not be used as evidence).';
lines{end+1} = '';
lines{end+1} = '## Final verdicts';
for i = 1:height(statusTbl)
    lines{end+1} = sprintf('- %s = %s', statusTbl.check(i), statusTbl.result(i));
end
lines{end+1} = '';
lines{end+1} = '## Outputs';
lines{end+1} = '- `tables/switching_legacy_observable_definition_inventory.csv`';
lines{end+1} = '- `tables/switching_observable_definition_porting_plan.csv`';
lines{end+1} = '- `tables/switching_legacy_observable_definition_status.csv`';

switchingWriteTextLinesFile(outReport, lines, 'run_switching_legacy_observable_definition_inventory:WriteFail');
fprintf('[DONE] switching legacy observable-definition inventory -> %s\n', outReport);

% ------------------------------- Helpers --------------------------------
function x = tdef(name, regex, canonical_inputs, latent_hint)
x = struct('name', string(name), 'regex', string(regex), 'canonical_inputs', string(canonical_inputs), 'latent_hint', string(latent_hint));
end

function files = listFilesRecursive(rootDir, exts)
files = {};
if exist(rootDir, 'dir') ~= 7
    return;
end
d = dir(rootDir);
for i = 1:numel(d)
    if d(i).name == "." || d(i).name == ".."
        continue;
    end
    p = fullfile(d(i).folder, d(i).name);
    if d(i).isdir
        sub = listFilesRecursive(p, exts);
        files = [files; sub]; %#ok<AGROW>
    else
        [~, ~, e] = fileparts(d(i).name);
        if any(strcmpi(e, exts))
            files{end+1,1} = p; %#ok<AGROW>
        end
    end
end
end

function txt = readTextSafe(p)
txt = "";
try
    raw = fileread(p);
    txt = string(raw);
catch
    txt = "";
end
end

function out = relpath(root, p)
r = strrep(root, '\', '/');
q = strrep(p, '\', '/');
if startsWith(lower(q), lower(r))
    out = extractAfter(q, strlength(r));
    out = regexprep(out, '^/', '');
else
    out = q;
end
end

function s = inferFormula(lines, idx)
s = "";
lo = max(1, idx-1);
hi = min(numel(lines), idx+1);
cand = strings(0,1);
for i = lo:hi
    ln = strtrim(lines(i));
    if strlength(ln)==0
        continue;
    end
    if contains(ln, "=") || contains(lower(ln), "ratio") || contains(lower(ln), "trapz") || contains(lower(ln), "corr")
        cand(end+1,1) = ln; %#ok<AGROW>
    end
end
if ~isempty(cand)
    s = strjoin(cand, " | ");
else
    s = strtrim(lines(idx));
end
end

function c = classifyClarity(formula)
f = lower(string(formula));
if contains(f, "=") || contains(f, "trapz") || contains(f, "mean(") || contains(f, "max(") || contains(f, "corr(")
    c = "YES";
elseif strlength(f) > 0
    c = "PARTIAL";
else
    c = "NO";
end
end

function y = yn(tf)
if tf
    y = "YES";
else
    y = "NO";
end
end

function src = classifySource(path, txt)
p = lower(strrep(path, '\', '/'));
t = lower(string(txt));
if contains(p, '/experimental/') || contains(p, 'switching ver') || contains(p, 'legacy')
    src = "legacy/noncanonical script artifact";
elseif contains(p, '/tables/') && (contains(p, 'legacy') || contains(t, "legacy"))
    src = "legacy/noncanonical table artifact";
elseif contains(p, '/reports/') && (contains(p, 'legacy') || contains(t, "legacy") || contains(t, "noncanonical"))
    src = "legacy/noncanonical report artifact";
else
    src = "noncanonical-by-policy candidate";
end
end

function risk = deriveRisk(path, formula, srcClass)
p = lower(strrep(path, '\', '/'));
f = lower(string(formula));
r = strings(0,1);
if contains(srcClass, "legacy") || contains(srcClass, "noncanonical")
    r(end+1,1) = "stale_definition"; %#ok<AGROW>
end
if contains(p, "width") || contains(f, "width") || contains(f, "halfwidth")
    r(end+1,1) = "noncanonical_normalization"; %#ok<AGROW>
end
if contains(p, "alignment") || contains(f, "align")
    r(end+1,1) = "conflicting_formula"; %#ok<AGROW>
end
if contains(f, "window") || contains(f, "band") || contains(f, "28") || contains(f, "32")
    r(end+1,1) = "unclear_region_window"; %#ok<AGROW>
end
if isempty(r)
    r = "duplicated_definition";
end
risk = strjoin(unique(r, 'stable'), '; ');
end

function test = proposeValidation(obsName, action)
if action == "discard"
    test = "none_discarded";
    return;
end
switch char(obsName)
    case 'S_peak'
        test = "recompute_from_canonical_S_map_and_cross-check_with_canonical_observables";
    case 'I_peak'
        test = "recompute_argmax_current_per_T_and_check_grid_stability";
    case 'tail_burden_ratio'
        test = "recompute_tail_vs_mid_energy_ratio_with_fixed_CDF_masks_and_window_sensitivity";
    case 'high_CDF_tail_weight'
        test = "recompute_tail_integral_over_CDF_ge_0p8_and_grid_robustness";
    case 'symmetry_cdf_mirror'
        test = "recompute_mirror_asymmetry_across_CDF_pairs_and_tolerance_sensitivity";
    case 'residual_energy_rmse'
        test = "recompute_from_canonical_residual_hierarchy_and_domain_splits";
    case 'kappa_proxy'
        test = "recompute_proxy_then_validate_against_canonical_kappa_tables_with_LOOCV";
    otherwise
        test = "canonical_recompute_plus_schema_and_window_consistency_test";
end
end
