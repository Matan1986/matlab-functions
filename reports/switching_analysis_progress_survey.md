# Switching canonical analysis progress survey (artifact-only)

**Scope:** Switching only (Aging and Relaxation excluded). **Method:** Read existing tables, reports, and stable `results/switching/runs` artifacts; no code changes; no new runs. **Runtime safety:** Conclusions rely on `tables/switching_run_trust_classification.csv` **TRUSTED_CANONICAL** runs and internally consistent file sets; UNVERIFIED runs and recent `run_2026_04_04_*_post_entry_runtime_fail` directories are excluded from stopping-point conclusions.

---

## Stopping point (precise)

Work is **reliably complete through** the **canonical `run_switching_canonical` pipeline outputs** on **TRUSTED_CANONICAL** runs: **core reconstruction (PT-only and PT + κ₁Φ₁)** with **global and per-row RMSE**, plus **Φ₁ shape/stability metrics** and **κ–S_peak sanity checks** as recorded in `switching_canonical_validation.csv` and companion tables.

The **first clear gap after that**, in this repository’s own inventory, is **Φ₁ irreducibility / rank beyond rank-1**: there is **no TRUSTED_CANONICAL run-backed artifact** for a rank-2 or irreducibility battery under `results/switching/runs` (see `tables/switching_analysis_canonical_status.csv` and trust table notes). **Parallel gap (documented elsewhere):** **full shift-and-scale scaling collapse** on the same TRUSTED_CANONICAL run IDs is **not** present—see `reports/switching_core_analysis_coverage.md` and `tables/switching_core_analysis_coverage.csv` (**SCALING = PARTIAL**).

---

## Stage-by-stage (status tokens)

Legend: **NOT_STARTED** | **PARTIAL** | **COMPLETE** | **UNKNOWN**

### A. Canonical object definition

| Substage | Status | Evidence |
|----------|--------|----------|
| S(I,T) | COMPLETE | `docs/switching_canonical_definition.md`; `tables/switching_canonical_definition_extraction.csv`; `tables/switching_canonical_definition_audit.csv`; `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv` |
| S_CDF | COMPLETE | Same + `S_model_pt_percent` / CDF construction in extraction table |
| ΔS | COMPLETE | `tables/switching_collapse_verification.csv`; `switching_canonical_S_long.csv` (`residual_percent`) |
| ΔS_norm | PARTIAL | No dedicated `DeltaS_norm` export located; `residual_percent` and Φ₁ max-abs normalization are documented separately (`docs/switching_canonical_definition.md`, extraction CSV) |
| Phi1 | COMPLETE | `switching_canonical_phi1.csv`; validation row `PHI_SHAPE_STABLE`, `PHI_MEDIAN_COSINE` |
| kappa1 | COMPLETE | `switching_canonical_observables.csv`; `KAPPA_SPEAK_CORR`, `KAPPA_SCALING_REASONABLE` |

### B. Core reconstruction

| Substage | Status | Evidence |
|----------|--------|----------|
| PT-only reconstruction | COMPLETE | `switching_canonical_validation.csv` (`RMSE_PT`); `switching_canonical_S_long.csv` |
| PT + kappa1*Phi1 | COMPLETE | `RMSE_FULL`; `S_model_full_percent`; reconstruction identity in `tables/switching_canonical_definition_extraction.csv` |
| RMSE map-level evaluation | COMPLETE | Global RMSE + `rmse_pt_row` / `rmse_full_row` in `switching_canonical_observables.csv` |

### C. Phi1 basic validation

| Substage | Status | Evidence |
|----------|--------|----------|
| Dominance (rank-1) | COMPLETE | Rank-1 SVD + single mode in extraction CSV and outputs |
| Stability | COMPLETE | Validation + per-T `phi_cosine_row` |
| Irreducibility tests | UNKNOWN | No trusted run-backed rank-2 / irreducibility output identified; `run_residual_rank2_audit` not matched to canonical outputs in `tables/switching_analysis_canonical_status.csv` |

### D. Kappa1 analysis

| Substage | Status | Evidence |
|----------|--------|----------|
| Observable mapping | COMPLETE | `kappa1` in `switching_canonical_observables.csv`; `tables/kappa1_vs_temperature.csv` |
| Relation to S_peak / PT features | COMPLETE | `KAPPA_SPEAK_CORR`; `S_peak` / `I_peak`; `tables/kappa1_control_analysis.csv` |
| Simplified model attempts | PARTIAL | `tables/kappa1_control_analysis.csv` and `tables_old/parameter_robustness_stage1_canonical_summary.csv` exist; `tables/switching_layer1_robustness_reconciliation.csv` marks cited alignment runs **MISSING**—chain not fully run-backed |

### E. Robustness / bottom integrity

**Overall: PARTIAL** (`tables/switching_layer1_robustness_verdicts.csv`: several dimensions **NO**; measurement **PARTIAL**). **Invariant row on canonical validation:** `INVARIANCE_VALID=YES` in `run_2026_04_03_000147_switching_canonical/tables/switching_canonical_validation.csv`—**does not** substitute for a full bottom-integrity matrix. Measurement/baseline reports cite **MISSING** run paths per `tables/switching_layer1_robustness_reconciliation.csv`.

### F. Runtime / execution validation

**COMPLETE** for TRUSTED_CANONICAL: `execution_status.csv` present; full `tables/switching_canonical_*.csv` set; see `tables/switching_run_trust_classification.csv`. **Note:** `docs/execution_status_schema.md` describes a different column layout than the CSV observed on TRUSTED_CANONICAL runs—**schema documentation vs artifact mismatch** (both files cited in survey CSV).

---

## Partial or inconsistent work (high level)

- **`analyze_phi_kappa_canonical_space` run dir** (`run_2026_04_02_213408_...`): **UNVERIFIED** (no `execution_status.csv`) per `tables/switching_run_trust_classification.csv`—**not** a stable completion signal.
- **`reports/phi_kappa_canonical_verdict.md`:** Verdict text exists; `tables/switching_layer1_robustness_reconciliation.csv` flags **no run_id** linkage—**supplementary** only for strict run-backed claims.
- **Scaling / collapse:** **PARTIAL** relative to TRUSTED_CANONICAL IDs (`reports/switching_core_analysis_coverage.md`).
- **Parameter / measurement robustness reports:** Often cite **MISSING** run directories in `tables/switching_layer1_robustness_reconciliation.csv`.

---

## What must be done next (consequence only)

1. **If irreducibility is required:** Produce a **signaling-complete** run with explicit rank-2 / residual-mode diagnostics **or** document why the canonical validation row suffices—artifact-backed either way.
2. **If full scaling-collapse on current canonical IDs is required:** Follow `reports/switching_core_analysis_coverage.md` replay guidance (re-point sources to TRUSTED_CANONICAL runs)—not inferred here.

---

## Machine-readable exports

- `tables/switching_analysis_progress_survey.csv`
- `tables/switching_analysis_progress_status.csv`
