# Switching FAILED_CANONICAL repair difficulty

**Scope:** Rows with `FINAL_CLASS = FAILED_CANONICAL` in `tables/switching_analysis_full_classification.csv` (12 items). **Method:** Artifact-only; no code edits; no new runs. **Repair levels:** L1 selection; L2 rebinding; L3 rerun / new run-backed bundle; L4 partial rewrite; L5 not repairable.

---

## By failure type

| failure_type | count | analysis_ids |
|--------------|------:|--------------|
| duplicate | 4 | `exec_run_switching_canonical_2026_04_02_234844`, `exec_run_switching_canonical_2026_04_03_000008`, `inv_switching_canonical_definition_extraction`, `inv_switching_collapse_interpretation` |
| ambiguous_dependency | 1 | `exec_run_switching_canonical_2026_04_03_091018` |
| no_run | 5 | `inv_switching_canonical_definition_audit`, `inv_switching_core_analysis_coverage`, `inv_switching_canonical_boundary_definition`, `inv_phase1_execution_audit`, `inv_switching_canonical_entrypoint_audit` |
| missing_artifacts | 2 | `inv_switching_collapse_verification`, `inv_switching_scaling_canonical_test` |

---

## By repair level

| level | meaning (this pass) | count |
|-------|------------------------|------:|
| L1 | Selection / consolidation / duplicate handling only; artifacts largely valid | 4 |
| L2 | Trust or policy rebinding; valid run artifacts already on disk | 1 |
| L3 | New or relocated run-backed execution with `execution_status.csv` under `results/switching/runs/...` (or explicit acceptance as non-run docs) | 7 |
| L4 | — | 0 |
| L5 | — | 0 |

---

## Fix vs rebuild

- **Fixable without recomputing Switching science (L1–L2):** Five items — duplicate TRUSTED runs (2), duplicate extraction/interpretation (2), trust-table alignment for `091018` (1). Evidence: `tables/switching_collapse_verification.csv` (hash consistency), `tables/switching_analysis_duplicates.csv`, `tables/switching_run_trust_classification.csv`.

- **Requires new run-backed bundle or explicit non-canonical status (L3):** Seven items — inspect-only audits/coverage/boundary/entrypoint, collapse verification as a named bundle, scaling metrics without a dedicated signed run, phase1 execution log without a `results/switching/runs` run_dir. No artifact in this pass assigns L4/L5 (no mixed-pipeline or missing-logic finding recorded for these rows).

---

## Outputs

- `tables/switching_analysis_repair_difficulty.csv`
- `tables/switching_analysis_repair_summary.csv`
