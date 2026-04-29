# Switching anti-confusion persistence hardening plan

- **namespace_id:** `CORRECTED_CANONICAL_OLD_ANALYSIS`
- **analysis_role:** `DIAGNOSTIC_FORENSIC`
- **source_data_namespace:** `CANON_GEN_SOURCE`
- **primary_input_artifacts:** `reports/switching_old_vs_new_canonical_confusion_persistence_audit.md`, `tables/switching_governance_artifact_persistence_status.csv`, `tables/switching_old_new_namespace_source_of_truth_map.csv`, `tables/switching_analysis_classification_status.csv`, `tables/switching_old_recipe_verification_status.csv`
- **claim_status:** `DIAGNOSTIC`
- **manuscript_safe:** `YES` (governance hardening plan only)

## Scope and constraints

- Planning/reporting only.
- No staging, commit, push, move, rename, or delete.
- No `.gitignore` edits performed in this task.
- Unrelated gauge atlas / figure / script changes excluded.
- `PHYSICS_LOGIC_CHANGED=NO`
- `FILES_DELETED=NO`

## 1) Minimal durable source-of-truth set

The smallest set that makes old-vs-new classification/quarantine durable in git:

1. `docs/switching_analysis_map.md`
2. `docs/templates/switching_analysis_namespace_header.md`
3. `tables/switching_old_new_namespace_source_of_truth_map.csv`
4. `tables/switching_analysis_classification_status.csv`
5. `tables/switching_old_recipe_verification_status.csv`
6. `docs/switching_governance_persistence_manifest.md` (recommended new tracked summary manifest)

Why this is minimal:

- Items 1-2 provide the durable namespace contract and required declaration pattern.
- Item 3 provides the machine-readable old-vs-new role map.
- Items 4-5 provide compact durable verdict keys without requiring all high-churn detail tables/reports.
- Item 6 is the single tracked anchor for non-negotiable governance facts that are otherwise trapped in ignored artifacts.

## 2) Per-file handling decision

Decision matrix is captured in:

- `tables/switching_anti_confusion_persistence_hardening_plan.csv`

Policy summary:

- **Track directly (no force-add):**
  - `docs/switching_analysis_map.md`
  - `docs/templates/switching_analysis_namespace_header.md`
- **Track with force-add now (or exception rule first):**
  - `tables/switching_old_new_namespace_source_of_truth_map.csv`
  - `tables/switching_analysis_classification_status.csv`
  - `tables/switching_old_recipe_verification_status.csv`
- **Prefer docs-summary (leave detailed artifacts ignored):**
  - `tables/switching_governance_artifact_persistence_status.csv`
  - `reports/switching_old_vs_new_canonical_confusion_persistence_audit.md`
  - `tables/switching_misleading_or_dangerous_artifacts.csv`
  - `tables/switching_corrected_old_artifact_gap_status.csv`
- **Leave ignored (not in minimal durable core):**
  - Detailed inventory/classification and long-form report artifacts not needed for minimal durability.

## 3) Recommended `.gitignore` exception lines (recommendation only)

If you prefer durable tracking without recurring `git add -f`, add these exact lines:

`!tables/switching_old_new_namespace_source_of_truth_map.csv`  
`!tables/switching_analysis_classification_status.csv`  
`!tables/switching_old_recipe_verification_status.csv`

No `.gitignore` changes were made here.

## 4) Safe staging boundary (persistence-only)

Safe-to-stage persistence-only is feasible **if and only if** staging is restricted to the minimal whitelist paths above (and optionally the new docs manifest when created).

This excludes all unrelated figures, scripts, and gauge-atlas artifacts.

## Required verdicts

- `MINIMAL_DURABLE_SET_DEFINED=YES`
- `FORCE_ADD_REQUIRED=YES`
- `DOCS_SUMMARY_REQUIRED=YES`
- `GITIGNORE_EXCEPTION_RECOMMENDED=YES`
- `SAFE_TO_STAGE_PERSISTENCE_ONLY=YES`
- `PHYSICS_LOGIC_CHANGED=NO`
- `FILES_DELETED=NO`
