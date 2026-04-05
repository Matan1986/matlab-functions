# Switching analysis inventory (artifact-only)

**Rules:** Switching scope only. **Excluded by rule or stability filter:** `results/switching/runs` directories without both `execution_status.csv` and a `reports/*.md` paired with `tables/*.csv` under the same analysis bundle; `run_2026_04_04_*` runs; `run_2026_04_04_095928_switching_canonical` (only `run_switching_canonical_implementation_status.csv` in `tables/`); reports without at least one `tables/*.csv` path in this inventory; `tables/kappa1_*.csv` (no `switching_*` basename and no paired `reports/*.md` in this pass); `reports/switching_aging_utils_audit.md` (Aging-named bundle excluded). **No stage or progress claims.**

---

## Counts

| Metric | Value |
|--------|------:|
| TOTAL_ANALYSES_FOUND | 26 |
| TOTAL_CANONICAL_ANALYSES (see criterion below) | 13 |
| TOTAL_AMBIGUOUS | 13 |
| DUPLICATE_GROUPS_FOUND (see `tables/switching_analysis_duplicates.csv`) | 4 |

---

## Criterion: “clearly canonical” vs “ambiguous”

**Clearly canonical (13):** Count of rows with `depends_on_canonical_entrypoint = YES` in `tables/switching_analysis_inventory.csv` (artifact-only basis: registry path `Switching/analysis/run_switching_canonical.m`, or markdown/CSV citations of that script, or TRUSTED run paths in coverage/scaling reports).

**Ambiguous (13):** same file column `depends_on_canonical_entrypoint = UNKNOWN`.

---

## Flat list (all 26)

Identifiers match `analysis_id` in `tables/switching_analysis_inventory.csv`.

1. `exec_run_switching_canonical_2026_04_02_234844`
2. `exec_run_switching_canonical_2026_04_03_000008`
3. `exec_run_switching_canonical_2026_04_03_000147`
4. `exec_run_switching_canonical_2026_04_03_091018`
5. `inv_switching_canonical_component_classification`
6. `inv_switching_canonical_definition_audit`
7. `inv_switching_canonical_definition_extraction`
8. `inv_switching_canonical_robustness_contract`
9. `inv_switching_collapse_verification`
10. `inv_switching_core_analysis_coverage`
11. `inv_switching_scaling_canonical_test`
12. `inv_switching_layer1_robustness_reconciliation`
13. `inv_switching_parameter_robustness_update_audit`
14. `inv_switching_replay_plan`
15. `inv_switching_replay_reconciliation`
16. `inv_switching_robustness_definition_recovery`
17. `inv_switching_robustness_execution_trace`
18. `inv_switching_robustness_rerun_readiness`
19. `inv_switching_robustness_root_validation`
20. `inv_switching_robustness_unblock_plan`
21. `inv_switching_canonical_boundary_definition`
22. `inv_switching_collapse_interpretation`
23. `inv_switching_layer1_robustness_audit`
24. `inv_ver12_canonical_audit`
25. `inv_phase1_execution_audit`
26. `inv_switching_canonical_entrypoint_audit`

---

## Duplicates / variants

See **`tables/switching_analysis_duplicates.csv`** (four groups: multiple canonical run IDs; Phi1 in extraction vs run `switching_canonical_phi1.csv`; collapse tables/reports overlap; layer1 reconciliation vs audit overlap).

---

## Canonical consistency (precomputed / entrypoint outputs)

| analysis_id | uses_canonical_entrypoint_outputs (artifact basis) | uses_precomputed_repo_tables (artifact basis) |
|-------------|---------------------------------------------------|-----------------------------------------------|
| exec_run_switching_canonical_* | YES — outputs are `switching_canonical_*.csv` under `run_dir` | NO — `switching_canonical_validation.csv` includes `CHECK_NO_PRECOMPUTED_INPUTS` column value YES for cited runs |
| inv_switching_canonical_definition_extraction | YES — CSV `source_file` lists `run_switching_canonical.m` | UNKNOWN — not stated in one column here |
| inv_switching_core_analysis_coverage | YES — markdown lists TRUSTED run dirs and `switching_canonical_*.csv` | NO — describes loading from those runs |
| inv_switching_scaling_canonical_test | YES — report names files under `run_2026_04_03_000147_switching_canonical` | NO — same |
| inv_switching_canonical_entrypoint_audit | YES — discusses `run_switching_canonical.m` | UNKNOWN — cites `switching_canonical_entrypoint_candidates.csv` |
| inv_phase1_execution_audit | YES — markdown lists `run_switching_canonical.m` in batch | UNKNOWN |
| Others | See `depends_on_canonical_entrypoint` column in `tables/switching_analysis_inventory.csv` | UNKNOWN unless a cited artifact row explicitly states precomputed inputs |

---

## Grouped file

**`tables/switching_analysis_inventory_grouped.csv`** — `group_label` values are assigned only when the **basename** of a listed artifact contains a substring mapped to: `reconstruction` (`S_long`, `collapse` tables), `phi1` (`phi1`), `kappa1` (`kappa1` / observables), `robustness` (`robustness`, `layer1`, `parameter_robustness`), `validation` (`validation`, `coverage`, `boundary`, `phase1_execution_audit`, `entrypoint`), else `other`.

---

## Source files

- `tables/switching_analysis_inventory.csv`
- `tables/switching_analysis_inventory_grouped.csv`
- `tables/switching_analysis_duplicates.csv`
