# Switching Phase 3 — Semantic preflight / lint (WARN-first)

Generated (UTC): 2026-04-29T21:25:20Z

## Inputs loaded

The following committed contract artifacts were required and read when present:

- `tables/switching_semantic_taxonomy.csv`
- `tables/switching_semantic_alias_map.csv`
- `tables/switching_semantic_forbidden_terms.csv`
- `tables/switching_semantic_rename_plan.csv`
- `tables/switching_semantic_synthesis_status.csv`
- `tables/switching_semantic_materialized_artifact_registry.csv`
- `tables/switching_semantic_allowed_use_matrix.csv`
- `tables/switching_semantic_writer_contract.csv`
- `tables/switching_semantic_lint_rules.csv`
- `tables/switching_semantic_materialization_status.csv`
- `tables/switching_semantic_sidecar_template.csv`
- `tables/switching_semantic_run_manifest_template.csv`
- `tables/switching_semantic_helper_contract.csv`
- `tables/switching_semantic_phase3_preflight_integration_plan.csv`
- `tables/switching_semantic_phase25_status.csv`
- `reports/switching_semantic_synthesis_and_rename_plan.md`
- `reports/switching_semantic_contract_materialization.md`
- `reports/switching_semantic_sidecar_manifest_helper_contract.md`

## Schema checks

Required column subsets were verified for Phase 2 / Phase 2.5 tables listed in `SCHEMA_REQUIRED` inside `scripts/run_switching_semantic_phase3_preflight.py`. Missing columns emit WARN or HARD_FAIL depending on whether unsafe canonical promotion detection is impaired.

## Lint rules applied

Loaded **19** rows from `tables/switching_semantic_lint_rules.csv`. Text scans matched governance patterns across committed semantic CSV/MD inputs (see findings table). Default policy: **WARN-first**. **SW_LINT_008** (forbidden stems `X_canon`, `collapse_canon`, `Phi_canon`, `kappa_canon`) emits **WARN** when the match is only in governance/policy columns or clearly forbids the stem; **HARD_FAIL** only when a risky column (e.g. path, alias, allowed_use) combines the stem with affirmative manuscript/replay/canonical authority flags. **HARD_FAIL** also applies when registry **canonical_safe** contradicts `switching_semantic_allowed_use_matrix.csv`.

## Mixed producer classification

Registry rows referencing `switching_canonical_S_long` were checked (**8** row hits). Column-level paths must map **S_percent / T_K / current_mA** to **CANON_GEN_SOURCE** and **PT_pdf / CDF_pt / S_model_pt_percent / residual_percent** to **EXPERIMENTAL_PTCDF_DIAGNOSTIC**. **CANON_GEN_SOURCE split preserved:** YES. **EXPERIMENTAL PT/CDF quarantine preserved:** YES.

## Allowed-use consistency

Cross-checked **38** registry rows against `tables/switching_semantic_allowed_use_matrix.csv` for unsafe **canonical_safe** posture.

## Findings summary

- Total findings: **171**
- HARD_FAIL: **0**
- WARN: **171**
- SUGGEST: **0**

Machine-readable detail: `tables/switching_semantic_phase3_preflight_findings.csv`.

## HARD_FAIL status

Any HARD_FAIL indicates a policy or schema defect that must be addressed before treating outputs as authority-safe; WARN findings do not prevent committing Phase 3 **preflight artifacts** once reviewed.

## Why rename execution remains blocked

`tables/switching_semantic_rename_plan.csv` remains planning-only; governed rename waves are not enabled by this preflight. Status: **RENAME_EXECUTION_ALLOWED_NOW = NO**.

## Why broad old-analysis replay remains blocked

Broad legacy replay requires Phase 4 gates and passing replay-safe posture — **BROAD_OLD_ANALYSIS_REPLAY_ALLOWED_NOW = NO**.

## Why Phase 4 corrected-old replay remains blocked

Phase 3 preflight implementation validates contracts but is **not sufficient** for Phase 4 replay enablement; repository review and explicit Phase 4 readiness remain required — **SAFE_TO_PROCEED_TO_PHASE4_CORRECTED_OLD_REPLAY = NO**.

## Next step

1. Review `tables/switching_semantic_phase3_preflight_findings.csv` and resolve HARD_FAIL items.
2. Commit Phase 3 preflight artifacts when ready (`SAFE_TO_COMMIT_PHASE3_PREFLIGHT_ARTIFACTS` may be YES even with WARN).
3. Schedule Phase 4 corrected-old replay only after Phase 3 artifacts are committed, reviewed, and HARD_FAIL policy is clear.
