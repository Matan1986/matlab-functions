# Switching-only canonical replay plan

**Generated:** inspection-only (no MATLAB, no pipeline or code changes).  
**Trusted default run:** `run_2026_04_03_000147_switching_canonical` (`tables/switching_run_trust_classification.csv`).

---

## Scope

- **In scope:** All `.m` files under `Switching/analysis/**` (103 entries): runnable analyses plus local helpers.
- **Out of scope for strict replay:** Scripts that touch Relaxation/Aging science paths or `genpath(Aging)` / `tables_old` as **inputs** per `tables/switching_analysis_inventory.csv` (`uses_noncanonical_sources = YES`).
- **Reports / `tables` folders:** Used indirectly by parsing absolute paths inside scripts; no separate row per CSV file. Legacy material under `tables_old/**` remains **reference-only**.

---

## Counts (from machine-generated CSVs)

| Metric | Value |
|--------|------:|
| Total Switching analyses (inventory rows) | 103 |
| `uses_noncanonical_sources = NO` (strict Switching-only detector) | 37 |
| `uses_noncanonical_sources = YES` (mixed / legacy science inputs) | 66 |
| `FULLY_CANONICAL = YES` (`tables/switching_analysis_canonical_status.csv`) | 1 |
| `FULLY_CANONICAL = PARTIAL` (Switching-only but outputs not verified at repo-root literals) | 36 |
| `FULLY_CANONICAL = NO` (mixed-module or noncanonical inputs) | 66 |

The single **FULLY_CANONICAL = YES** row is **`run_switching_canonical`**, verified against on-disk artifacts under the trusted run (`switching_canonical_S_long.csv`, `switching_canonical_phi1.csv`).

---

## Prioritized replay order

Order is defined in **`tables/switching_replay_plan.csv`** (columns `priority`, `replay_tier`):

1. **Reconstruction (priority 1):** `run_switching_canonical`, `run_minimal_canonical`.
2. **Φ / deformation / closure (priority 2):** scripts whose names match `run_phi*`, `analyze_phi*`, `phi1_phi2*`, `run_phi2_*` (see CSV for full list).
3. **Scaling / collapse (priority 3):** `switching_full_scaling*`, `switching_energy_scale*`, `run_collapse*`, `switching_residual_collapse*`, `switching_shape_rank*`, `switching_XI*`, `switching_second*`.
4. **Robustness / audits (priority 4):** parameter robustness, tail ablation, PT energy extraction audit, residual sector robustness, peak-jump audit, `*_audit` patterns.
5. **Remaining Switching analyses (priority 5)** and **helpers (priority 99)** — helpers are not standalone “runs” but support other scripts.

**Excluded tier (priority 0):** rows with `guard_status = EXCLUDE_MIXED_MODULE` — do **not** schedule in a strict Switching-only replay until dependencies are removed or explicitly signed off as out-of-scope.

---

## Contamination guard summary

See **`reports/switching_replay_guard_rules.md`**: module isolation, TRUSTED_CANONICAL-only loading, forbidden sources, detection rules, mandatory validation, and fail conditions.

---

## Final verdict

**REPLAY_READY = NO** for a **complete** replay of all 103 Switching analysis files under strict isolation rules: **66** scripts remain flagged as using noncanonical science inputs; only **`run_switching_canonical`** is **FULLY_CANONICAL** on the automated checks used here.

**Conditional:** A **37-script Switching-only** subset (`uses_noncanonical_sources = NO`) is **eligible** for a guarded replay plan using **`run_2026_04_03_000147_switching_canonical`**, subject to per-script verification of `run_dir` outputs (many rows are **PARTIAL** because helpers and dynamic writers do not embed fixed `C:/Dev/.../tables/` literals).

---

## Artifact paths

| Artifact |
|-----------|
| `tables/switching_analysis_inventory.csv` |
| `tables/switching_analysis_canonical_status.csv` |
| `tables/switching_analysis_gaps.csv` |
| `tables/switching_replay_plan.csv` |
| `reports/switching_replay_guard_rules.md` |
| `reports/switching_replay_plan.md` |
