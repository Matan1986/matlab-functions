# Aging/Relaxation Confusion Audit

## Scope Executed
- Code scan: Aging core, aging-named analysis scripts, and shared utility boundaries.
- Output scan: `tables/*`, `results/*` with focus on aging paths.
- Report scan: aging-related markdown content.
- Relaxation confusion markers: `t0`, `time_origin`, `field removal`, `R_relax_canonical`, `tau=t-t0`, `Huber slope`.

## Key Findings
- Core `Aging/` code shows **no strong relaxation-canonical injection** (`AGING_STRONG_PATTERN_HITS=0`).
- `results/aging` contents show **no strong relaxation markers** (`RESULTS_AGING_CONTENT_HITS=0`).
- A **localized contamination lineage exists** in aging-labeled audit artifacts created from relaxation logic.
- The contaminated lineage explicitly uses `R_relax_canonical`, `t0`, and `tau=t-t0` semantics.

## Short Summary
- Core aging pipeline code is clean of strong relaxation-canonical markers.
- No systemic shared-utility leak from Relaxation helpers into Aging core was detected.
- Contamination is localized to aging-labeled measurement-audit artifacts.
- Those artifacts use relaxation `t0` and `R_relax_canonical` definitions.
- This is a physics-definition integrity breach for aging interpretation.
- Affected artifacts must be quarantined before further aging analysis.

## Affected Files / Scripts
- `C:\Dev\matlab-functions\run_aging_measurement_definition_audit.m`
- `C:\Dev\matlab-functions\reports\aging_measurement_definition_audit.md`
- `C:\Dev\matlab-functions\tables\aging_measurement_definition_audit.csv`
- `C:\Dev\matlab-functions\tables\aging_measurement_definition_audit_status.csv`
- `C:\Dev\matlab-functions\results\relaxation\runs\run_2026_03_30_124149_aging_measurement_definition_audit`
- `C:\Dev\matlab-functions\results\relaxation\runs\run_2026_03_30_133703_aging_measurement_definition_audit`

## Verdict Block
RELAXATION_LOGIC_USED_IN_AGING=YES
T0_USED_IN_AGING=YES
RELAXATION_OBSERVABLE_USED_IN_AGING=YES

CONFUSION_LOCALIZED=YES
CONFUSION_SYSTEMIC=NO

AFFECTED_FILES_IDENTIFIED=YES
REQUIRES_PIPELINE_FIX=YES

## Containment Recommendation
- Disable immediately: `run_aging_measurement_definition_audit.m` from any aging decision path.
- Disable immediately: root and run-derived `aging_measurement_definition_audit` tables/reports listed above.
- Can remain: core `Aging/` pipeline scripts and existing `results/aging` outputs not tied to the contaminated lineage.
- Can remain: cross-experiment comparison scripts that reference both domains for comparison only.
- Must be rewritten: any aging measurement-definition audit must use aging-native definitions only (no `t0`, no post-field-removal transient logic, no `R_relax_canonical`).
