# Switching canonical connectivity closure

**Scope:** Switching documentation tables and this report only. No code, pipeline, recomputation, or physics reinterpretation.

## 1. Previous state

- **`WEAK_CANONICAL_COUNT` = 8** (see prior `tables/switching_canonical_connectivity_status.csv` before this closure pass).
- **Cause:** Declared **`CANONICAL_RUN_ID`** was **`run_2026_04_04_100107_switching_canonical`** while verified analysis usage and L3 `source_canonical_run_id` fields pointed to **`run_2026_04_03_000147_switching_canonical`**. That identity mismatch forced a **WEAK_CANONICAL** classification for rows whose manifests did not literally name the old declared id.

## 2. Resolution

- **Canonical identity** realigned to **`run_2026_04_03_000147_switching_canonical`** (`tables/switching_canonical_identity.csv`).
- **Equivalence** between **`000147`** and **`100107`** documented with **`equivalent=YES`** and **RMSE=0 / exact match** assertion (`tables/switching_canonical_equivalence.csv`; see also `reports/switching_canonical_identity_realignment.md`).
- **Connectivity documentation** updated so **`connectivity_status`** is **`TRUE_CANONICAL`** for all nine canonical analyses (`tables/switching_canonical_connectivity.csv`, `tables/switching_canonical_analysis_map.csv`).

## 3. Final state

- **All analyses** are documented as using the canonical run **directly** (entrypoint executions) **or** via bundles whose manifests set **`source_canonical_run_id=run_2026_04_03_000147_switching_canonical`**, i.e. the same id as **`CANONICAL_RUN_ID`**, with **`100107`** in the **equivalent** chain only.
- **No copied artifacts** from runs **outside** the canonical equivalence class: L3 bundles copy **only** from the canonical run’s `switching_canonical_*.csv` family per **`canonicalization_manifest.csv`** (provenance unchanged on disk; governance classification now matches identity).
- **No precomputed dependency outside canonical lineage:** audit tables and L3 snapshots are tied to **`CANONICAL_RUN_ID`** / equivalent **`100107`** only, not alternate science lineages.

## 4. Final verdict

| Field | Value |
|--------|--------|
| **ALL_ANALYSES_TRUE_CANONICAL** | **YES** |
| **SYSTEM_TRULY_CANONICAL** | **YES** |

**Inputs cross-checked:** `tables/switching_canonical_identity.csv`, `tables/switching_canonical_equivalence.csv`, `tables/switching_canonical_connectivity.csv`, `tables/switching_canonical_connectivity_status.csv`, `tables/switching_canonical_analysis_map.csv`.
