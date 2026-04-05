# Switching analysis classification conflict resolution (read-only)

This document compares two independent Switching classification artifacts:

- `tables/switching_canonical_analysis_map.csv` — per-row `connectivity_status` (here only `TRUE_CANONICAL` appears) plus `run_id` and semicolon-separated `artifact_paths`.
- `tables/switching_analysis_full_classification.csv` — per-row `FINAL_CLASS` (`CANONICAL`, `FAILED_CANONICAL`, `LEGACY`, …) plus `reason` / `evidence`.

No source is assumed correct; no code or data were modified beyond adding these three deliverables.

## Stage 1 — Alignment

### Primary join: `analysis_id`

Every `analysis_id` present in the canonical analysis map also appears in the full classification table. From `switching_canonical_analysis_map.csv` (data rows only):

1. `exec_run_switching_canonical_2026_04_03_000147`
2. `exec_run_switching_canonical_2026_04_03_091018`
3. `inv_switching_canonical_definition_audit`
4. `inv_switching_collapse_verification`
5. `inv_switching_core_analysis_coverage`
6. `inv_switching_scaling_canonical_test`
7. `inv_switching_canonical_boundary_definition`
8. `inv_phase1_execution_audit`
9. `inv_switching_canonical_entrypoint_audit`

**Total distinct ids in map: 9** (nine data rows after the header).

**Matched pairs (map ∩ survey): 9** — join key `analysis_id`.

### Secondary alignment (not used to add rows)

- **Name similarity:** Survey `analysis_name` aligns with the `inv_*` / `exec_*` stem (e.g. `switching_collapse_verification` vs `inv_switching_collapse_verification`).
- **Artifact overlap:** Map `artifact_paths` reference `results/switching/runs/...` and repo `tables/...`. Survey `evidence` columns cite overlapping table/report paths for the same logical topics (e.g. collapse, layer1). No additional **cross-file** row merges were required because every map id already exists in the survey.

### Unpaired survey rows

Full classification contains **additional** `analysis_id` values with **no** row in the canonical map (e.g. other `exec_run_switching_canonical_*` dates, `inv_switching_canonical_component_classification`, robustness and replay bundles). These are **out of scope** for map-vs-survey *conflict* rows because the map assigns no `connectivity_status` to them. They remain **classification-only** in the survey.

## Stage 2 — Comparable status extraction

| Source | Field used | Values observed (this repo snapshot) |
|--------|------------|----------------------------------------|
| Canonical map | `connectivity_status` | `TRUE_CANONICAL` for all map rows |
| Full classification | `FINAL_CLASS` | `CANONICAL`, `FAILED_CANONICAL`, `LEGACY` |

### Operational agreement rule (for conflict flagging)

For a matched `analysis_id`:

- Treat **agreement** as: map `TRUE_CANONICAL` **and** survey `FINAL_CLASS == CANONICAL`.
- Treat **conflict** as: map `TRUE_CANONICAL` **and** survey `FINAL_CLASS` is **not** `CANONICAL` (e.g. `FAILED_CANONICAL` or `LEGACY`).

Under this rule, **one** matched pair agrees: `exec_run_switching_canonical_2026_04_03_000147` (map `TRUE_CANONICAL`, survey `CANONICAL`). **Eight** pairs conflict; see `tables/switching_analysis_conflicts.csv`.

## Stage 3 — Conflict types assigned

| Type | Meaning (operational) | Count in this audit |
|------|------------------------|---------------------|
| `DUPLICATE_CONFUSION` | Map treats connectivity as canonical; survey rejects canonical class due to duplicate-family / trust rules (e.g. DG1). | 1 |
| `RUN_DEPENDENCY_MISMATCH` | Map cites a concrete `run_id` and run-scoped artifacts; survey’s gate denies run-backed canonical status for the **same** `analysis_id`. | 4 |
| `ARTIFACT_SCOPE_MISMATCH` | Map implies run-scoped or bundled artifacts; survey describes scope as inspect-only or non-primary run derivation. | 2 |
| `IDENTITY_MISMATCH` | Same `analysis_id` carries incompatible roles across sources (e.g. failed canonical vs source-of-truth flags). | 1 |
| `UNKNOWN` | Reserved; not used when a clearer type applied. | 0 |

## Stage 4–5 — Outputs

- Detailed rows: `tables/switching_analysis_conflicts.csv`
- Summary: `tables/switching_analysis_conflict_status.csv`

## Stage 6 — Where conflicts come from

1. **Different gates:** The map records **connectivity** (paths and `TRUE_CANONICAL`) for a fixed set of analyses. The survey applies **FINAL_CLASS** rules that often require a specific notion of run identity, inspect-only vs execution-backed bundles, or duplicate-group handling — without assuming the same gate as the map.
2. **Time / process lag:** L3 canonicalization `run_*` directories referenced in the map can exist while survey text still describes “no run_dir for this analysis id” for the **logical** inventory id — a **RUN_DEPENDENCY_MISMATCH** pattern.
3. **Duplicate families:** Survey **FAILED_CANONICAL** on `exec_run_switching_canonical_2026_04_03_091018` vs map **TRUE_CANONICAL** reflects **DUPLICATE_CONFUSION** (DG1) rather than random noise.
4. **Label collision:** `inv_switching_collapse_verification` is **FAILED_CANONICAL** yet **SOURCE_OF_TRUTH YES** in the survey — internally strained — while the map marks **TRUE_CANONICAL**; classified here as **IDENTITY_MISMATCH**.

## Does one source dominate?

Neither source is treated as authoritative in this audit. **Empirically**, for the **matched** set, the survey assigns **FAILED_CANONICAL** to **8/9** rows where the map says **TRUE_CANONICAL**, so **for this join the survey’s negative classifications would dominate** if one forced a single label — but that would ignore that the map contains **no** `FAILED` / `LEGACY` states in its `connectivity_status` column. The systems are **orthogonal columns**, not a strict subset relation.

## Systematic vs random

Conflicts are **systematic**: they cluster into (i) duplicate exec-run policy (DG1), (ii) run-dir / inspect-only gate mismatch for `inv_*` L3 analyses, and (iii) scope interpretation for coverage/scaling. They are **not** evenly scattered arbitrary label noise.

## Ambiguity note

“Resolve” here means **documented reconciliation of disagreement**, not choosing a winning taxonomy. Full elimination of ambiguity would require a **single** normative definition of “canonical” and a **single** join of logical analysis id to run manifest — out of scope for this read-only pass.

---

## FINAL RETURN (numeric summary)

| Metric | Value |
|--------|------:|
| TOTAL_MATCHED | 9 |
| TOTAL_CONFLICTS | 8 |
| CONFLICT_RATE | 0.8889 |
| DOMINANT_CONFLICT_TYPE | RUN_DEPENDENCY_MISMATCH |
