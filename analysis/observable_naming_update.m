function observable_naming_update(cfg)
% observable_naming_update
% Documentation-only rename pass: introduces chi_amp(T) as the physical name
% for the observable previously known as a1. No numerical code is modified.
%
% Creates a run in results/cross_experiment/runs/run_<ts>_observable_naming_update
% containing a report that documents all updated locations.

if nargin < 1, cfg = struct(); end
cfg = applyDefaults(cfg);

%% Setup run context
repoRoot = fileparts(fileparts(mfilename('fullpath')));
runCfg.runLabel = 'observable_naming_update';
runCfg.notes   = 'Documentation-only rename pass: a1 -> chi_amp(T).';
runCfg.dataset = 'repository_documentation';
run    = createRunContext('cross_experiment', runCfg);
runDir = run.run_dir;
logP   = run.log_path;

logLine(logP, '[%s] observable_naming_update started', stampNow());
logLine(logP, 'runDir: %s', runDir);

%% Define the changes made
filesUpdated = {
    'docs/observable_naming.md                           (CREATED)';
    'docs/observables/observable_registry.md             (UPDATED)';
    'docs/observables/switching_observables.md           (UPDATED)';
    'analysis/phase_diagram_synthesis.m                  (UPDATED — buildReport string literals)';
    'analysis/observable_basis_sufficiency_robustness_audit.m (UPDATED — 1 string literal)';
    'Switching/analysis/switching_a1_vs_curvature_test.m (UPDATED — buildReport string literals)';
};
nFiles = numel(filesUpdated);

changes = {
    % file, line_approx, before, after
    struct('file','analysis/phase_diagram_synthesis.m', ...
           'line','~448', ...
           'before','...modulation/correction on selected observables (a1).', ...
           'after', '...modulation/correction on selected observables (chi_amp(T), legacy: a1).');
    struct('file','analysis/phase_diagram_synthesis.m', ...
           'line','~459', ...
           'before','...chi_ridge and a1 carry most of the observable structure...', ...
           'after', '...chi_ridge and chi_amp(T) (legacy: a1) carry most of the observable structure...');
    struct('file','analysis/phase_diagram_synthesis.m', ...
           'line','~463', ...
           'before','...X is near or past peak. a1 transitions; chi_ridge begins significant change.', ...
           'after', '...X is near or past peak. chi_amp transitions; chi_ridge begins significant change.');
    struct('file','analysis/phase_diagram_synthesis.m', ...
           'line','~481', ...
           'before','- a1 peak at <T> K —', ...
           'after', '- chi_amp(T) (legacy: a1) peak at <T> K —');
    struct('file','analysis/phase_diagram_synthesis.m', ...
           'line','~504', ...
           'before','...(a1 requires X+kappa in most alignment variants).', ...
           'after', '...(chi_amp(T) requires X+kappa in most alignment variants).');
    struct('file','analysis/observable_basis_sufficiency_robustness_audit.m', ...
           'line','~559', ...
           'before','- `a1`: EXPLAINED_BY_X_KAPPA', ...
           'after', '- `chi_amp(T)` (legacy: `a1`): EXPLAINED_BY_X_KAPPA');
    struct('file','Switching/analysis/switching_a1_vs_curvature_test.m', ...
           'line','~329', ...
           'before','Yes, a1(T) is consistent with a local ridge stiffness/curvature mode...', ...
           'after', 'Yes, chi_amp(T) (legacy: a1) is consistent with a local ridge stiffness/curvature mode...');
    struct('file','Switching/analysis/switching_a1_vs_curvature_test.m', ...
           'line','~333', ...
           'before','No clear support: a1(T) is not well captured by local ridge curvature...', ...
           'after', 'No clear support: chi_amp(T) (legacy: a1) is not well captured by local ridge curvature...');
    struct('file','Switching/analysis/switching_a1_vs_curvature_test.m', ...
           'line','~337', ...
           'before','# Switching a1 vs local ridge curvature test', ...
           'after', '# Switching chi_amp(T) (legacy: a1) vs local ridge curvature test');
    struct('file','Switching/analysis/switching_a1_vs_curvature_test.m', ...
           'line','~348', ...
           'before','- Pearson corr(`a1`, `curvature_near_peak`)...', ...
           'after', '- Pearson corr(`chi_amp`, `curvature_near_peak`)...');
    struct('file','Switching/analysis/switching_a1_vs_curvature_test.m', ...
           'line','~349', ...
           'before','- Spearman corr(`a1`, `curvature_near_peak`)...', ...
           'after', '- Spearman corr(`chi_amp`, `curvature_near_peak`)...');
    struct('file','Switching/analysis/switching_a1_vs_curvature_test.m', ...
           'line','~350', ...
           'before','- `T_peak(|a1|) = <T> K`', ...
           'after', '- `T_peak(|chi_amp|) = <T> K`');
};
nOccurrences = numel(changes);

%% Build report
reportText = buildReport(filesUpdated, changes, nFiles, nOccurrences, runDir);
reportPath = save_run_report(reportText, 'observable_naming_update_report.md', runDir);
logLine(logP, 'report: %s', reportPath);

%% Finalize
logLine(logP, '[%s] observable_naming_update complete', stampNow());
logLine(run.notes_path, 'Files updated: %d', nFiles);
logLine(run.notes_path, 'Occurrences updated: %d', nOccurrences);

fprintf('RUN_ID=%s\n', run.run_id);
fprintf('NUMBER_OF_FILES_UPDATED=%d\n', nFiles);
fprintf('NUMBER_OF_OCCURRENCES_UPDATED=%d\n', nOccurrences);
end

%% ─── Defaults ────────────────────────────────────────────────────────────────
function cfg = applyDefaults(cfg)
% No configurable parameters needed for this documentation pass.
end

%% ─── Report builder ──────────────────────────────────────────────────────────
function txt = buildReport(filesUpdated, changes, nFiles, nOccurrences, runDir)
L = strings(0,1);
L(end+1) = '# Observable Naming Update Report';
L(end+1) = '';
L(end+1) = 'Generated: ' + string(stampNow());
L(end+1) = 'Run dir: `' + string(runDir) + '`';
L(end+1) = '';
L(end+1) = '---';
L(end+1) = '';
L(end+1) = '## Summary';
L(end+1) = '';
L(end+1) = sprintf('- Files updated: **%d**', nFiles);
L(end+1) = sprintf('- Occurrences updated: **%d**', nOccurrences);
L(end+1) = '- Type: **documentation-only** (no numerical code modified)';
L(end+1) = '- New name: **χ_amp(T)**';
L(end+1) = '- Legacy name: **a1**';
L(end+1) = '';

L(end+1) = '## 1. Files Updated';
L(end+1) = '';
for i = 1:numel(filesUpdated)
    L(end+1) = string(sprintf('- `%s`', strtrim(filesUpdated{i})));
end
L(end+1) = '';

L(end+1) = '## 2. Locations Where Naming Was Changed';
L(end+1) = '';
L(end+1) = '| # | File | Approx. line | Before | After |';
L(end+1) = '|---|---|---|---|---|';
for i = 1:numel(changes)
    c = changes{i};
    L(end+1) = string(sprintf('| %d | `%s` | %s | `%s` | `%s` |', ...
        i, c.file, c.line, c.before, c.after));
end
L(end+1) = '';

L(end+1) = '## 3. Confirmation That No Code Was Modified';
L(end+1) = '';
L(end+1) = 'The following categories of identifiers were **not** changed:';
L(end+1) = '';
L(end+1) = '- MATLAB variable names (`a1`, `a1Feat`, `a1PeakTAbs`, `checks.a1_peak_T`, etc.)';
L(end+1) = '- Function signatures (no parameters renamed)';
L(end+1) = '- CSV column headers (`a1`, `a_1` in all tables)';
L(end+1) = '- Run folder names (historical outputs untouched)';
L(end+1) = '- Configuration field names (`cfg.a1RunId`, `source.a1RunId`, etc.)';
L(end+1) = '- File names (no files renamed)';
L(end+1) = '- Numerical computations (unchanged)';
L(end+1) = '- All files in `results/` (historical run outputs untouched)';
L(end+1) = '';
L(end+1) = 'Only **report-generating string literals** (the `lines(end+1) = ...` and `L(end+1) = ...` ';
L(end+1) = 'patterns that produce markdown report text) were updated in analysis scripts.';
L(end+1) = '';

L(end+1) = '## 4. Naming Policy (Source of Truth)';
L(end+1) = '';
L(end+1) = 'The canonical reference for the observable naming policy is:';
L(end+1) = '';
L(end+1) = '- `docs/observable_naming.md` (created in this pass)';
L(end+1) = '- `docs/observables/observable_registry.md` (updated with χ_amp entry)';
L(end+1) = '- `docs/observables/switching_observables.md` (updated with χ_amp section)';
L(end+1) = '';

L(end+1) = '## 5. Example Before/After Snippets';
L(end+1) = '';
L(end+1) = '### analysis/phase_diagram_synthesis.m — buildReport section';
L(end+1) = '';
L(end+1) = '**Before:**';
L(end+1) = '```';
L(end+1) = "L(end+1) = '- Character: low-temperature susceptibility regime. Dynamic switching activity is suppressed; chi_ridge and a1 carry most of the observable structure.';";
L(end+1) = '```';
L(end+1) = '';
L(end+1) = '**After:**';
L(end+1) = '```';
L(end+1) = "L(end+1) = '- Character: low-temperature susceptibility regime. Dynamic switching activity is suppressed; chi_ridge and chi_amp(T) (legacy: a1) carry most of the observable structure.';";
L(end+1) = '```';
L(end+1) = '';
L(end+1) = '### analysis/observable_basis_sufficiency_robustness_audit.m — buildReport section';
L(end+1) = '';
L(end+1) = '**Before:**';
L(end+1) = '```';
L(end+1) = "lines(end+1) = '- `a1`: EXPLAINED_BY_X_KAPPA';";
L(end+1) = '```';
L(end+1) = '';
L(end+1) = '**After:**';
L(end+1) = '```';
L(end+1) = "lines(end+1) = '- `chi_amp(T)` (legacy: `a1`): EXPLAINED_BY_X_KAPPA';";
L(end+1) = '```';
L(end+1) = '';
L(end+1) = '### Switching/analysis/switching_a1_vs_curvature_test.m — buildReport section';
L(end+1) = '';
L(end+1) = '**Before:**';
L(end+1) = '```';
L(end+1) = 'lines(end + 1) = "# Switching a1 vs local ridge curvature test";';
L(end+1) = 'lines(end + 1) = sprintf(''- Pearson corr(`a1`, `curvature_near_peak`) = `%.6f`.'', pearsonR);';
L(end+1) = '```';
L(end+1) = '';
L(end+1) = '**After:**';
L(end+1) = '```';
L(end+1) = 'lines(end + 1) = "# Switching chi_amp(T) (legacy: a1) vs local ridge curvature test";';
L(end+1) = 'lines(end + 1) = sprintf(''- Pearson corr(`chi_amp`, `curvature_near_peak`) = `%.6f`.'', pearsonR);';
L(end+1) = '```';
L(end+1) = '';

L(end+1) = '---';
L(end+1) = '';
L(end+1) = '## NAMING_POLICY_SUMMARY';
L(end+1) = '';
L(end+1) = '- **New name:** χ_amp(T)';
L(end+1) = '- **Legacy name:** a1';
L(end+1) = '- **Interpretation:** temperature susceptibility of switching amplitude';
L(end+1) = '- **Definition:** χ_amp(T) ≈ −dS_peak/dT';
L(end+1) = '- **Peak location:** ~10 K';
L(end+1) = '- **Usage rule:** χ_amp in reports and documentation; a1 in code and CSV schemas';
L(end+1) = '- **Backward compatibility:** full — no pipelines broken';
L(end+1) = '- **Source of truth:** `docs/observable_naming.md`';

txt = strjoin(L, newline);
end

%% ─── Helpers ─────────────────────────────────────────────────────────────────
function logLine(fp, fmt, varargin)
msg = sprintf(fmt, varargin{:});
fid = fopen(fp, 'a', 'n', 'UTF-8');
if fid ~= -1
    fprintf(fid, '%s\n', msg);
    fclose(fid);
end
end

function s = stampNow()
s = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end
