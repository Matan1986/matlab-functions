# Switching analysis classification (LEGACY / CANONICAL / FAILED_CANONICAL)

**Inputs:** `tables/switching_analysis_inventory.csv`, `tables/switching_analysis_duplicates.csv`. **Rules:** Artifact-backed only; Switching scope; no code changes; no new runs. **Normative definitions:** User task text (CANONICAL requires run_dir + `execution_status` + full tables/reports + `depends_on_canonical_entrypoint = YES` + no disqualifying legacy/precomputed evidence; any doubt → FAILED_CANONICAL).

---

## Summary counts

| Field | Value |
|--------|------:|
| TOTAL_ANALYSES | 26 |
| CANONICAL_COUNT | 1 |
| FAILED_CANONICAL_COUNT | 12 |
| LEGACY_COUNT | 13 |
| DUPLICATES_RESOLVED | 4 |
| SYSTEM_FULLY_CLASSIFIED | YES |

**Designated canonical SOURCE_OF_TRUTH (single run-backed analysis):** `exec_run_switching_canonical_2026_04_03_000147` → `run_2026_04_03_000147_switching_canonical` (TRUSTED_CANONICAL in `tables/switching_run_trust_classification.csv`; full `switching_canonical_*.csv` + reports under `results/switching/runs/...`; `CHECK_NO_PRECOMPUTED_INPUTS` on validation table).

---

## 1. CANONICAL (final set)

| analysis_id | Notes |
|-------------|--------|
| `exec_run_switching_canonical_2026_04_03_000147` | Only row satisfying strict CANONICAL gate; `SOURCE_OF_TRUTH = YES` for duplicate groups DG1 and DG2. |

---

## 2. FAILED_CANONICAL

**A. Same-script run family (DG1)** — three additional `run_switching_canonical` executions: same artifact pattern and hash-equivalence family per `tables/switching_collapse_verification.csv`, but not selected as SOURCE_OF_TRUTH; `run_2026_04_03_091018` additionally not listed TRUSTED_CANONICAL in `tables/switching_run_trust_classification.csv`.

| analysis_id |
|-------------|
| `exec_run_switching_canonical_2026_04_02_234844` |
| `exec_run_switching_canonical_2026_04_03_000008` |
| `exec_run_switching_canonical_2026_04_03_091018` |

**B. Depends YES but not run-backed as this analysis** — inspect-only or repo-root audits / derivatives; no `results/switching/runs/<analysis_run_id>/` with `execution_status.csv` for that bundle under strict CANONICAL definition.

| analysis_id |
|-------------|
| `inv_switching_canonical_definition_audit` |
| `inv_switching_canonical_definition_extraction` (also DG2 duplicate of Phi1 in SOURCE_OF_TRUTH run) |
| `inv_switching_collapse_verification` (DG3 SOURCE_OF_TRUTH for pair; still not a standalone canonical *run* row) |
| `inv_switching_core_analysis_coverage` |
| `inv_switching_scaling_canonical_test` |
| `inv_switching_canonical_boundary_definition` |
| `inv_switching_collapse_interpretation` (DG3 duplicate relative to collapse verification) |
| `inv_phase1_execution_audit` |
| `inv_switching_canonical_entrypoint_audit` |

*Note:* `inv_switching_collapse_verification` is **FAILED_CANONICAL** (fails run-backed CANONICAL for this row) but **`SOURCE_OF_TRUTH = YES`** within DG3 for ordering the duplicate pair.

---

## 3. LEGACY

**Criterion applied:** `depends_on_canonical_entrypoint` not YES in inventory (treated as no established canonical-entrypoint dependency for classification), **or** explicit pre-grid / non-entrypoint scope (e.g. `ver12` code audit).

Includes: component classification, robustness contract, layer1 reconciliation (SOURCE_OF_TRUTH YES within DG4 for pairing), parameter robustness update, replay plan/reconciliation, robustness definition recovery / execution trace / rerun readiness / root validation / unblock plan, layer1 robustness audit (DG4 legacy duplicate), `ver12_canonical_audit`.

---

## Duplicate groups (resolved)

| Group | SOURCE_OF_TRUTH analysis_id | Other members |
|-------|------------------------------|---------------|
| DG1 | `exec_run_switching_canonical_2026_04_03_000147` | Three other `exec_run_switching_canonical_*` |
| DG2 | `exec_run_switching_canonical_2026_04_03_000147` | `inv_switching_canonical_definition_extraction` |
| DG3 | `inv_switching_collapse_verification` | `inv_switching_collapse_interpretation` |
| DG4 | `inv_switching_layer1_robustness_reconciliation` | `inv_switching_layer1_robustness_audit` (legacy duplicate → LEGACY) |

---

## Machine-readable outputs

- `tables/switching_analysis_full_classification.csv`
- `tables/switching_analysis_classification_status.csv`
