# Maintenance Existing Automation Prompts

Status: Historical input material only

This file captures existing maintenance automation prompts as repository-visible historical/input records.

This is not the new maintenance contract.
This is not an executable maintenance system.

## 1. Repository Drift Guard

Scan the repository for structural drift and violations of the repository architecture.

Follow the repository rules defined in:
docs/AGENT_RULES.md
docs/results_system.md
docs/repository_structure.md

Check for the following issues:

1. Generated outputs outside:
   results/<experiment>/runs/run_<timestamp>_<label>/

2. Scripts writing figures or data directly to module folders instead of using the run system.

3. Helper utilities duplicated across modules instead of being placed in shared locations such as:
   tools/
   <module>/utils/

4. Legacy outputs under:
   results/<experiment>/
   that are not inside the runs/ directory and should be migrated into pseudo-runs:
   run_legacy_<name>/

5. Any generated artifacts that should be ignored by git but are currently tracked.

For every issue found:
- show the file path
- explain the violation
- propose a minimal fix consistent with the repository rules.

Do NOT modify files automatically.
Only report issues and suggested minimal fixes.

## 2. Helper Duplication Guard

Scan the repository for duplicated helper utilities and similar functions.

Focus on helper locations such as:

tools/
<experiment>/utils/
<experiment>/analysis/

Look for:

1. MATLAB functions with identical or very similar behavior
   across different modules (Aging, Relaxation, Switching).

2. Helper utilities that appear in multiple modules but should
   likely live in a shared location such as:
   tools/

3. Similar utility functions with slightly different names
   (for example:
   toNum, toNumeric, toNumericColumn, etc).

4. Functions implementing similar logic for:
   - numeric conversion
   - map construction
   - correlation
   - smoothing
   - figure export
   - run output writing

For any suspected duplication:

Report:
- function names
- file paths
- similarity description

Suggest a minimal fix:
- consolidate into a shared helper
- reuse an existing function
- remove redundant implementations

Follow repository rules defined in:
docs/AGENT_RULES.md
docs/repository_structure.md

Do NOT modify files automatically.
Only produce a report.

## 3. Run Output Audit

Inspect the most recent runs in the repository.

Focus on directories under:

results/<experiment>/runs/

For each run directory:

1. Verify the expected run structure exists.

Required files:
- run_manifest.json
- observables.csv (if observables were exported)

Expected directories when applicable:
- figures/
- logs/

2. Verify observables.csv contains the expected schema:

experiment
sample
temperature
observable
value
units
role
source_run

3. Detect issues such as:

- missing run_manifest.json
- empty observables.csv
- runs missing figures even though analysis scripts generated plots
- duplicate run labels
- partially written runs

4. Detect suspicious runs such as:

- extremely small runs
- runs missing expected artifacts
- inconsistent metadata in run_manifest.json

Produce a concise report with the following sections:

RUN STATUS
- valid runs
- incomplete runs
- suspicious runs

For incomplete runs:
suggest which analysis scripts likely failed or which artifacts are missing.

Do NOT modify files automatically.
Only report issues.
