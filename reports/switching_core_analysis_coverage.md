# Switching core analysis coverage (reconstruction, Φ₁, scaling)

**Rules:** Inspection only (no MATLAB, no code or pipeline changes). Definitions: `tables/switching_run_trust_classification.csv`, `reports/switching_canonical_boundary_definition.md`, `docs/repo_execution_rules.md`.

**TRUSTED_CANONICAL runs (Switching, signaling-complete, science tables):**

- `run_2026_04_03_000147_switching_canonical` (primary reference below)
- `run_2026_04_03_000008_switching_canonical`
- `run_2026_04_02_234844_switching_canonical`

All three include the same canonical **`switching_canonical_*.csv`** set under each run’s `tables/`.

---

## 1. Reconstruction (PT vs PT+Φ₁)

### What already exists

| Evidence | Role |
|----------|------|
| `.../tables/switching_canonical_validation.csv` | **RMSE_PT**, **RMSE_FULL**, **RECONSTRUCTION_IMPROVES** |
| `.../tables/switching_canonical_S_long.csv` | **S_model_pt_percent** vs **S_model_full_percent** (and residuals) on the canonical grid |
| `.../reports/run_switching_canonical_report.md` | Human-readable summary; **RECONSTRUCTION_IMPROVES**, **RMSE_PT**, **RMSE_FULL** |

### Trusted run link

- Artifacts live under **`run_2026_04_03_*`** and **`run_2026_04_02_234844_*`** as above — **yes**, formally tied to TRUSTED_CANONICAL runs.

### Coverage level

**FULLY_CANONICAL** — run-backed, trusted canonical run, metrics present.

### Recommendation

**SKIP** duplicate replay for this core question — already satisfied by `run_switching_canonical` outputs on TRUSTED_CANONICAL runs.

---

## 2. Φ₁ analysis (shape, dominance, stability)

### What already exists

| Evidence | Role |
|----------|------|
| `.../tables/switching_canonical_phi1.csv` | **Phi1** vs **current_mA** (first SVD mode amplitude) |
| `.../tables/switching_canonical_observables.csv` | Per-**T_K**: **phi_cosine_row**, **rmse_pt_row**, **rmse_full_row**, **kappa1**, etc. |
| `.../tables/switching_canonical_validation.csv` | **PHI_SHAPE_STABLE**, **PHI_MEDIAN_COSINE** |

### Trusted run link

- Same TRUSTED_CANONICAL runs as above.

### Other / near-canonical material (do not treat as duplicate core Φ₁)

- **`results/switching/runs/run_2026_04_02_213408_phi_kappa_canonical_space_analysis`**: manifest/log only — **no** `execution_status.csv`, **no** `tables/` (UNVERIFIED per `tables/switching_run_trust_classification.csv`).
- **`reports/phi_kappa_canonical_verdict.md`**: useful **reference**; not a substitute for run-backed trusted artifacts.

### Coverage level

**FULLY_CANONICAL** for the **canonical pipeline’s** Φ₁ and stability metrics.

### Recommendation

**SKIP** duplicate replay for core Φ₁ shape/dominance/stability — already in trusted **`switching_canonical_*`** tables. If you need **canonical-space** Φ–κ analysis as a **separate** deliverable, that is a **LIGHT_REPLAY** (re-execute `analyze_phi_kappa_canonical_space.m` with signaling fixed), not a duplicate of the main Φ₁ table.

---

## 3. Scaling / collapse

### What already exists (within trusted canonical)

| Evidence | Role |
|----------|------|
| `.../tables/switching_canonical_validation.csv` | **KAPPA_SPEAK_CORR**, **KAPPA_SCALING_REASONABLE** |
| `.../reports/run_switching_canonical_report.md` | **KAPPA_SCALING_REASONABLE** (Spearman cited) |

This addresses **κ–Speak scaling sanity** inside the canonical validation gate — **not** the full **shift-and-scale collapse** parameterization.

### What is missing on TRUSTED_CANONICAL runs

- **`switching_full_scaling_parameters.csv`** — expected by `Switching ver12/plots/plotSwitchingPanelF.m` / overlay helpers — **not** present under `run_2026_04_03_*` or `run_2026_04_02_234844_*` (inspected `results/switching/runs` tree).
- **`Switching/analysis/switching_full_scaling_collapse.m`** (and related) default **source/comparison run IDs** to **`run_2026_03_*`**, not **`run_2026_04_03_*`**, so existing collapse outputs are **not** automatically equivalent to the current TRUSTED_CANONICAL default.

### Coverage level

**PARTIAL** — κ scaling metrics: **yes**, run-backed, trusted; **full** collapse / `switching_full_scaling_parameters`: **not** present on trusted runs.

### Recommendation

- **κ scaling row only:** **SKIP** full replay; optional **LIGHT_REPLAY** = re-read validation row for documentation.
- **Full collapse hypothesis (parameters, figures):** **FULL_REPLAY** targeted at a **TRUSTED_CANONICAL**-sourced alignment run (re-point `sourceRunId` / pipeline to `run_2026_04_03_*` or equivalent) — **not** a duplicate of work already in `switching_canonical_validation.csv`.

---

## Summary table (machine-readable)

See **`tables/switching_core_analysis_coverage.csv`**.

---

## Final verdict

**CORE_REPLAY_SCOPE = PARTIAL**

- **Reconstruction** and **Φ₁**: effectively **already implemented** on TRUSTED_CANONICAL runs — **no duplicate replay** needed for those cores.
- **Scaling / collapse**: **partial** — canonical validation covers **κ scaling checks**; **full scaling-collapse** artifacts are **missing** from trusted run directories and remain tied to **older** run IDs in scripts — scope a **dedicated** replay if collapse parameters are required, not a second `run_switching_canonical` pass.

---

## Artifact paths (this verification)

| Path |
|------|
| `tables/switching_core_analysis_coverage.csv` |
| `reports/switching_core_analysis_coverage.md` |
| `tables/switching_run_trust_classification.csv` |
| `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_validation.csv` |
| `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv` |
| `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_phi1.csv` |
| `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_observables.csv` |
| `results/switching/runs/run_2026_04_03_000147_switching_canonical/reports/run_switching_canonical_report.md` |
| `results/switching/runs/run_2026_04_03_000008_switching_canonical/tables/` (same five science CSVs) |
| `results/switching/runs/run_2026_04_02_234844_switching_canonical/tables/` (same five science CSVs) |
