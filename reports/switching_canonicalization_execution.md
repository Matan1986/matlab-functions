# Switching canonicalization execution (FAILED_CANONICAL repair L1–L3)

**Policy:** No scientific logic or algorithm changes; Switching-only; canonical inputs from `run_2026_04_03_000147_switching_canonical` only; entrypoint reference `Switching/analysis/run_switching_canonical.m`.

---

## Stage 1 — L1 duplicate resolution

**Artifact:** `tables/switching_analysis_deduplicated.csv`

| analysis_id | FINAL_CLASS | REASON |
|-------------|---------------|--------|
| `exec_run_switching_canonical_2026_04_02_234844` | NON_CANONICAL | DUPLICATE |
| `exec_run_switching_canonical_2026_04_03_000008` | NON_CANONICAL | DUPLICATE |
| `inv_switching_canonical_definition_extraction` | NON_CANONICAL | DUPLICATE |
| `inv_switching_collapse_interpretation` | NON_CANONICAL | DUPLICATE |

**SOURCE_OF_TRUTH:** `exec_run_switching_canonical_2026_04_03_000147` / `run_2026_04_03_000147_switching_canonical` (DG1, DG2); collapse interpretation duplicate of collapse verification bundle (DG3).

---

## Stage 2 — L2 rebinding

**Action:** Appended `run_2026_04_03_091018_switching_canonical` to `tables/switching_run_trust_classification.csv` as `TRUSTED_CANONICAL` with existing path and artifact-complete flags.

**Run-backed manifest:** `results/switching/runs/run_2026_04_04_150000_canonicalization_l2_trust_rebind_091018/` (`execution_status.csv`, `tables/canonicalization_l2_manifest.csv`, `reports/canonicalization_l2_report.md`).

---

## Stage 3 — L3 bundles

**Prefix:** `run_2026_04_04_150000_canonicalization_l3_*`

For each L3 analysis, a new directory under `results/switching/runs/` contains:

- `execution_status.csv` (copied from SOURCE_OF_TRUTH run signaling shape)
- `tables/switching_canonical_*.csv` copied from `run_2026_04_03_000147_switching_canonical/tables/` (canonical entrypoint outputs only)
- `tables/canonicalization_manifest.csv` (provenance: `inputs_from_canonical_run_only=YES`, `legacy_tables_used=NO`)
- Analysis-specific CSV copied from `tables/` at repo root (definition audit, collapse verification, core coverage, scaling, boundary, phase1, entrypoint)
- `reports/canonicalization_l3_report.md` and `reports/run_switching_canonical_report_from_source_run.md` (snapshot from SOURCE_OF_TRUTH run report)

**Bundles:**

1. `canonicalization_l3_definition_audit`
2. `canonicalization_l3_collapse_verification`
3. `canonicalization_l3_core_analysis_coverage`
4. `canonicalization_l3_scaling_canonical_test`
5. `canonicalization_l3_boundary_definition`
6. `canonicalization_l3_phase1_execution_audit`
7. `canonicalization_l3_entrypoint_audit`

---

## Stage 4–5 — Final canonical set

**Artifact:** `tables/switching_analysis_canonical_final.csv`

**Count:** `FINAL_CANONICAL=9` (see `tables/switching_analysis_canonicalization_final_status.csv`): SOURCE_OF_TRUTH execution, rebound `091018`, seven L3 bundles.

---

## Stage 6 — Status

| Field | Value |
|--------|--------|
| INITIAL_CANONICAL | 1 |
| FINAL_CANONICAL | 9 |
| FAILED_REMAINING | 0 |
| L1_RESOLVED | 4 |
| L2_RESOLVED | 1 |
| L3_RESOLVED | 7 |
| SYSTEM_CANONICAL_READY | YES |

---

## Clean state

- Duplicate TRUSTED runs classified NON_CANONICAL (policy duplicates); physical dirs unchanged.
- `091018` aligned with trust table; L2 manifest documents linkage.
- L3 analyses are run-backed under `results/switching/runs/` with `execution_status.csv` and manifests; inputs tied to SOURCE_OF_TRUTH canonical CSVs only.
- No MATLAB batch execution was required for this pass: bundling and provenance copies only, per strict no-algorithm-change rule.
