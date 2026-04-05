# Layer 1 robustness evidence audit (Switching only)

**Layer 1 definition (this audit):** Data formation **raw `.dat` → `Smap`** via **Switching ver12** (`getFileListSwitching`, `processFilesSwitching`, `analyzeSwitchingStability`, channel/metric selection, preprocessing embedded there), as consumed by **`run_switching_canonical.m`** (see `reports/switching_canonical_definition_audit.md`).

**Rules:** Inspect-only. No code changes. No new MATLAB runs. **Switching only** (Aging/Relaxation science excluded; `createRunContext` host path noted only as technical).

---

## A. Executive summary

**Did Layer 1 robustness testing (systematic variation + map-level proof) already occur?** **NO**

**Did related robustness work exist for downstream observables / post-sample grids?** **PARTIAL** (reports + `tables_old/` CSVs; several cited **run directories are missing** from the current `results/` tree).

---

## B. Evidence breakdown (by required dimension)

### 1. Parameter sensitivity (P2P_percent, channel, preprocessing flags)

| Evidence | What it shows |
|----------|----------------|
| `Switching/analysis/run_parameter_robustness_switching_canonical.m` | Reads **`switching_alignment_samples.csv`**; builds **`Smap`** with **`buildMapOnGrid`** — **does not** call **`processFilesSwitching`**. |
| `reports/parameter_robustness_stage1_canonical_report.md` | Locks **`S_percent`** sample file from **`run_2026_03_10_112659_alignment_audit`**; varies **IPEAK/WIDTH/S_PEAK/KAPPA1** *extraction* definitions — **not** ver12 ingest parameters. |
| `tables_old/parameter_robustness_stage1_canonical_summary.csv` | Numeric **`corr_vs_canonical`**, **RMSE** for those variants — **downstream of fixed samples**. |

**Conclusion:** **No** artifact demonstrates a **systematic sweep of Layer 1 (ver12) parameters** with comparison of **two independently formed `Smap`s** from raw.

### 2. Measurement definition stability

| Evidence | What it shows |
|----------|----------------|
| `reports/switching_measurement_robustness_report.md` | Observable correlations / NRMSE across variants; cites **`run_2026_03_29_014529_switching_physics_output_robustness_fast`** — **that path was not found** under `results/Switching/runs/`. |
| `reports/switching_intra_measurement_robustness_report.md` | Intra-definition groups (**raw_xy_delta** vs **baseline_aware**); same **missing run** reference. |

**Conclusion:** **PARTIAL** documentation exists; **run-backed** verification **not available** in this workspace for those citations.

### 3. Map-level stability (CRITICAL for Layer 1)

**Required:** RMSE/corr between **maps** or explicit **ΔS** / **Φ₁** map comparison **for formation outputs**.

| Evidence | Gap |
|----------|-----|
| `tables_old/parameter_robustness_stage1_canonical_summary.csv` | Correlations on **scalar profiles** / observables — **not** pairwise **`Smap`** from two ver12 configurations. |
| `reports/parameter_robustness_stage1b_width_kappa_report.md` | **`MAP_STABLE_BUT_SCALARIZATION_FRAGILE`** — about **collapse / width** behavior vs **scalarization**, **not** duplicate raw→**`Smap`** ingest. |
| `results/Switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv` | Single **`S_percent`** field — **one** formation outcome per run; **no** second map variant from altered Layer 1 in repo. |

**Conclusion:** **Map-level stability of Layer 1 `Smap` under controlled ver12 variation** is **not proven** by existing artifacts.

### 4. Structural invariance (Φ₁ shape, reconstruction)

| Evidence | Layer 1? |
|----------|----------|
| `reports/switching_pipeline_stability.md`, `reports/switching_pipeline_stability_post_enforcement.md` | **`PHI1_STABLE`**, reconstruction — refer to **canonical SVD φ₁** and downstream metrics **after** **`Smap`**, **not** invariance of **ver12** formation. |

**Conclusion:** **Not** Layer 1 structural invariance evidence.

### 5. Multi-run consistency

| Evidence | What it shows |
|----------|----------------|
| `results/Switching/runs/run_2026_04_03_000008_switching_canonical`, `run_2026_04_03_000147_switching_canonical` | **Two** successful **`switching_canonical`** runs — **reproducibility** of the **same** pipeline recipe. |
| Missing **`run_2026_03_10_*`**, **`run_2026_03_29_*`** | Cited by robustness reports but **absent** from current **`results/Switching/runs`** listing. |

**Conclusion:** **PARTIAL** — multi-run **canonical** execution exists; **not** a **parameter matrix** for Layer 1.

### 6. Code audit vs robustness testing

| Evidence | Role |
|----------|------|
| `reports/ver12_canonical_audit.md` | **Static** enumeration of **`processFilesSwitching`** / **`analyzeSwitchingStability`** behavior — **valuable** for **definition**, **not** substitute for **multi-config empirical robustness**. |

---

## C. Critical gaps

1. **No** workspace run artifacts showing **two or more `Smap`s** from **different explicit Layer 1 configurations** (metric/channel/preprocess) **with** **map–map** RMSE/correlation.
2. **No** **`results/Switching/runs`** folders found for **several run IDs** named in robustness **reports** — **cannot** treat those as **run-backed** here.
3. **Parameter robustness** scripts and **Stage 1** tables operate on **locked sample CSVs** — by construction **downstream** of Layer 1.

---

## D. Final verdicts

| Verdict | Value | Justification |
|---------|-------|----------------|
| **LAYER1_ROBUSTNESS_AUDITED** | **NO** | No systematic Layer 1 (ver12) variation + map-level proof located. Code audit and downstream observable robustness **do not** satisfy Layer 1 robustness as defined above. |
| **MAP_LEVEL_STABILITY_PROVEN** | **NO** | No pairwise **`Smap`** comparison under Layer 1 sweeps documented with present run artifacts. |
| **EVIDENCE_IS_RUN_BACKED** | **NO** | **Current** `results/Switching/runs` **only** contains a small set of runs (e.g. **`switching_canonical`**, **`phi_kappa_canonical_space_analysis`**, **`minimal_canonical`**); **robustness** reports cite **missing** run paths. Claims rely on **markdown + `tables_old/`** for historical robustness, **not** on co-located run directories. |

---

## Machine-readable tables

- `tables/switching_layer1_robustness_evidence.csv`
- `tables/switching_layer1_robustness_verdicts.csv`

---

*Inspect-only; no code or execution changes.*
