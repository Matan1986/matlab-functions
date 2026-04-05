# Switching canonical connectivity verification

**Scope:** Switching only. **Inputs:** `tables/switching_analysis_canonical_final.csv`, `tables/switching_canonical_identity.csv`. **Code changes:** none. **Re-runs:** none.

## Canonical run identity (from input)

From `tables/switching_canonical_identity.csv`, **`CANONICAL_RUN_ID`** is **`run_2026_04_04_100107_switching_canonical`**.

## `load_run(CANONICAL_RUN_ID)`

Repository-wide search for a MATLAB callable **`load_run(`** (parenthesis form): **no matches** in `*.m` files. Related APIs present on disk include `tools/load_run_manifest.m` and `analysis/knowledge/load_run_evidence.m`; neither is `load_run`, and neither was found consuming `run_2026_04_04_100107_switching_canonical` in Switching canonical analysis paths checked for this task.

**Per-analysis answer for “uses `load_run(CANONICAL_RUN_ID)`”:** **NO** for all nine rows (symbol absent; no equivalent `load_run` call located).

## SOURCE vs DUPLICATE (closure table)

`tables/switching_canonical_run_closure.csv` classifies **`run_2026_04_04_100107_switching_canonical`** as **`SOURCE`** and **`run_2026_04_03_000147_switching_canonical`** as **`DUPLICATE`**.

No row in `tables/switching_analysis_canonical_final.csv` lists **`run_2026_04_04_100107_switching_canonical`** as `run_id`, and every L3 **`canonicalization_manifest.csv`** read under `results/switching/runs/run_2026_04_04_150000_canonicalization_l3_*/tables/` records **`source_canonical_run_id=run_2026_04_03_000147_switching_canonical`**, not `CANONICAL_RUN_ID`.

## Entrypoint execution (exec rows)

`Switching/analysis/run_switching_canonical.m` obtains a fresh `run_dir` via `createRunContext` and does not call `load_run` or read a prior canonical run id for Switching tables (raw upstream is read through the legacy Switching stack). Example:

```55:60:C:\Dev\matlab-functions\Switching\analysis\run_switching_canonical.m
    cfg = struct();
    cfg.runLabel = 'switching_canonical';
    cfg.dataset = 'raw_switching_dat_only';
    ctx = createRunContext('Switching', cfg);
    run = ctx;
```

**Copied artifacts / precomputed (exec):** **NO** for “copied canonical run bundle” semantics; **NO** for consuming precomputed `switching_canonical_*.csv` from an older run inside this script (outputs are written into the new `run_dir`).

Verified on disk: `results/switching/runs/run_2026_04_03_000147_switching_canonical/execution_status.csv` and `run_manifest.json` exist.

## L3 inventory analyses (inv_* rows)

For each `run_2026_04_04_150000_canonicalization_l3_*` bundle, **`tables/canonicalization_manifest.csv`** sets **`source_canonical_run_id`** to **`run_2026_04_03_000147_switching_canonical`**. Example (`canonicalization_l3_definition_audit`):

- `results/switching/runs/run_2026_04_04_150000_canonicalization_l3_definition_audit/tables/canonicalization_manifest.csv`

**`reports/canonicalization_l3_report.md`** under each bundle states copy-only provenance (example read: `canonicalization_l3_collapse_verification`).

**Copied artifacts:** **YES** (bundle `tables/` includes copied `switching_canonical_*.csv` files; example listing: `canonicalization_l3_definition_audit/tables/` contains `switching_canonical_S_long.csv` alongside `canonicalization_manifest.csv`).

**Precomputed data:** **YES** (audit tables and copied canonical CSV snapshots; no recomputation claimed in those reports).

## Connectivity status assignment

| Status | Count | Rule used |
|--------|------|-----------|
| **TRUE_CANONICAL** | 1 | Direct `run_switching_canonical.m` execution artifacts for `run_2026_04_03_000147_switching_canonical` (`SOURCE_OF_TRUTH=YES` in input CSV); not `load_run`-based. |
| **WEAK_CANONICAL** | 8 | Second direct exec row (`091018`, `SOURCE_OF_TRUTH=NO` in input CSV) plus seven L3 bundles whose manifests name **`000147`**, not **`CANONICAL_RUN_ID` (`100107`)**, and whose reports describe copy-only bundling. |
| **FAKE_CANONICAL** | 0 | No row lacked a documented chain to the Switching canonical entrypoint or to on-disk run-backed artifacts. |

**`SYSTEM_TRULY_CANONICAL`:** **NO** — manifests and `run_id` values in the final canonical analysis list do not reference **`CANONICAL_RUN_ID`** from `tables/switching_canonical_identity.csv`; closure marks **`100107`** as SOURCE while L3 inputs name **`000147`** (DUPLICATE). No `load_run(CANONICAL_RUN_ID)` usage exists to close that gap in code.

## Outputs written by this verification

- `tables/switching_canonical_connectivity.csv`
- `tables/switching_canonical_connectivity_status.csv`
- `tables/switching_canonical_analysis_map.csv`
