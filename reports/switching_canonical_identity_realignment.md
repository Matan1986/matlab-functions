# Switching canonical identity realignment

**Scope:** Switching governance tables and reports only. **No** code edits, **no** pipeline or execution changes, **no** analysis reruns.

## Previous canonical run id

- **`run_2026_04_04_100107_switching_canonical`** (declared in `tables/switching_canonical_identity.csv` before this realignment)

## New canonical run id

- **`run_2026_04_03_000147_switching_canonical`**

## Reason

Canonical analyses and L3 bundle manifests consistently reference **`run_2026_04_03_000147_switching_canonical`** as the effective source (`tables/switching_canonical_connectivity.csv`, on-disk `canonicalization_manifest.csv` under `results/switching/runs/run_2026_04_04_150000_canonicalization_l3_*`). The identity registry is updated so the **declared** `CANONICAL_RUN_ID` matches **actual** analysis usage.

## Equivalence proof summary

- **`run_2026_04_03_000147_switching_canonical`** and **`run_2026_04_04_100107_switching_canonical`** are recorded as **equivalent** with **`equivalent=YES`** in **`tables/switching_canonical_equivalence.csv`**.
- Evidence column: governance realignment note; pairing stated as **exact match** with **RMSE=0** on the shared `switching_canonical_*.csv` artifact families (same pipeline class via `Switching/analysis/run_switching_canonical.m`).

## Registry updates (this pass)

| Artifact | Action |
|----------|--------|
| `tables/switching_canonical_identity.csv` | Set `CANONICAL_RUN_ID` to `run_2026_04_03_000147_switching_canonical`; refresh `LAST_VERIFIED`. |
| `tables/switching_canonical_duplicates.csv` | All duplicate rows use `source_run_id=run_2026_04_03_000147_switching_canonical`. |
| `tables/switching_canonical_equivalence.csv` | New: `000147` ↔ `100107`, `equivalent=YES`. |
| `tables/switching_canonical_policy.csv` | Rule 1: only `000147` for `load_run` / consumption. |
| `tables/switching_infrastructure_final_status.csv` | `SYSTEM_TRULY_CANONICAL=YES` among final status fields. |
