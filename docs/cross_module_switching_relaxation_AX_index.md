# Cross-module Switching–Relaxation AX index (official)

**Status:** Governance index (non-executing). **Supersedes nothing in science:** it **routes** readers to committed runners and durable tables. The earlier draft remains at `docs/cross_module_switching_relaxation_AX_index_draft.md`.

**Plan lineage:** `3b750a8` — *Add Switching-Relaxation AX organization plan*.

**Classification (CM1):** If an analysis uses **Switching coordinates or Switching-matched tables** *and* **Relaxation amplitudes / RCON / RF tracks**, it is **`CROSS_MODULE_SWITCHING_RELAXATION`**, **not** Relaxation-only, **even when outputs live under** `tables/relaxation/`, `reports/relaxation/`, or `figures/relaxation/`.

**Do not** use `X_canon` in AX-facing claims without an explicit Switching contract (CM3). Treat **`get_canonical_X` / `canonical_X`** as **legacy** until a dedicated audit says otherwise (CM4). Keep **`A_obs`**, **`A_proj_nonSVD`**, **`m0_svd` / SVD score tracks**, and **legacy `A_T`** **symbolically distinct** (CM5).

---

## Manuscript evidence path — CM-SW-RLX-AX-20A (synthesis & claim boundary)

**Purpose:** one canonical entry for **manuscript-facing** cross-module Switching–Relaxation evidence. **CM-SW-RLX-AX-20A** synthesizes prior audits only (no new fits). **Start here** for discussion text, then follow links to source audits.

### AX-20A package (durable paths)

| Role | Path |
|------|------|
| Synthesis report | `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_synthesis_claim_boundary.md` |
| Evidence matrix | `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_evidence_matrix.csv` |
| Final claims | `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_final_claims.csv` |
| Variable roles | `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_variable_roles.csv` |
| Power-like scaling summary | `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_powerlike_scaling_summary.csv` |
| Manuscript wording | `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_manuscript_wording.csv` |
| Status | `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20A_status.csv` |

### AX-20A classification (read from `…_AX_20A_status.csv`)

- **AX-20A relationship class:** **`EMPIRICAL_INVD_POWERLIKE_SCALING`**
- **Coordinate reading:** **`invD = 1/(w*S_peak)`** (denominator / area-scale; see AX-20A variable-roles and AX-17B dataset join)
- **Empirical `invD_power` exponents (AX-18C/18D, descriptive log–log on n = 15):** **`POWERLAW_ALPHA_AOBS = 0.562460847`**, **`POWERLAW_ALPHA_ASVD = 0.558279495`** — summary **alpha ≈ 0.56**
- **`PHYSICAL_SCALING_LAW_ESTABLISHED`:** **`NO`**
- **Manuscript safety flag:** **`SAFE_FOR_MANUSCRIPT_DISCUSSION = YES_WITH_BOUNDED_WORDING`**

### Roles of `X_eff` vs `invD` (bounded)

- **`X_eff`:** retained as the **dimensionless composite coordinate** / **useful ratio label** (P0 `X_eff` = `I_peak/(width·S_peak)`; on the strict AX ladder `width_chosen` matches FWHM — see XEFF width audit).
- **`invD`:** **best tested empirical scaling organizer** among the audited suite — **not** a claim that **`invD` fully replaces `X_eff`** (replacement framing is **forbidden**; see synthesis and AX-18B/19A).

### Domain caveats (always with AX-20A text)

- **n = 15** on the strict inclusion ladder; temperature-ordered series.
- **Strong `T_relax`–`invD` collinearity** — dual presentation of temperature and denominator coordinate; do not assert independence or unique mechanism from ordering alone (see AX-19A).

### Evidence sources (upstream of AX-20A)

| Audit | Report (entry) |
|-------|----------------|
| **AX-17B** visual comparison | `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_17B_visual_comparison.md` |
| **XEFF width audit 18** | `reports/cross_module_switching_relaxation_CM_SW_RLX_XEFF_width_audit_18.md` |
| **AX-18B** turnover / shape | `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_18B_turnover_shape_audit.md` |
| **AX-18C** T-function & empirical scaling baseline | `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_18C_T_function_scaling_baseline_control.md` |
| **AX-18D** scaling-law closure | `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_18D_scaling_law_closure.md` |
| **AX-19A** invD / temperature reparameterization closure | `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_19A_invD_temperature_reparameterization_closure.md` |

### Index policy — forbidden extensions (AX-20A / cross-module SR)

When citing this path, **do not** use the following in manuscript claims derived from this index entry:

- Do **not** call the **`invD_power` fit** a **physical scaling law**.
- Do **not** call the exponent **universal** or a **material constant**.
- Do **not** say **`invD` proves mechanism** or causal uniqueness (collinearity; n small).
- Do **not** say **`invD` fully replaces `X_eff`** as the paper’s dimensionless ratio label.
- Do **not** say **all simple scaling laws are ruled out** (AX-18D: narrow “no physical law from tested templates” is the correct form).
- Do **not** imply **Aging** or **tau / beta / KWW** evidence — this track is **Switching–Relaxation AX only**.

**Registration note:** CM-SW-RLX-AX-20B added this section; see `reports/cross_module_switching_relaxation_CM_SW_RLX_AX_20B_index_registration.md` and `tables/cross_module_switching_relaxation_CM_SW_RLX_AX_20B_index_registration_status.csv`.

---

## P0 — Current pipeline families (X–A and matched-T scaling)

| `family_id` | Entry script | Durable / default outputs (when inputs exist) | True class |
|-------------|--------------|-----------------------------------------------|------------|
| `RLX_SW_SCALING_01` | `run_relaxation_switching_scaling_01.m` | `tables/relaxation/relaxation_switching_scaling_01_matched_observables.csv`, `relaxation_switching_scaling_01_claim_safety.csv`, run-scoped copies under `results/relaxation/runs/…` | `CROSS_MODULE_SWITCHING_RELAXATION` |
| `RLX_SW_SCALING_02` | `run_relaxation_switching_scaling_02.m` | `relaxation_switching_scaling_02A_*.csv`, consumes scaling_01 matched table | `CROSS_MODULE_SWITCHING_RELAXATION` |
| `RLX_SW_SCALING_03` | `run_relaxation_switching_scaling_03.m` | Promoted `tables/relaxation/*scaling_03*`, `reports/relaxation/*`; affine / piecewise / fractional power-law diagnostics | `CROSS_MODULE_SWITCHING_RELAXATION` |
| `RLX_ACTIVITY_SCALARIZATION_01` | `run_relaxation_activity_scalarization_01.m` | Reads scaling_01 CSVs; scalarization vs **`X_eff_nonunique`**; audit prose under `reports/relaxation/` when run | `CROSS_MODULE_SWITCHING_RELAXATION` |
| `RLX_SVD_XSCALING_01` | `run_relaxation_svd_xscaling_01.m` | `relaxation_svd_xscaling_01_claim_safety.csv`, duplicate-check CSV; PNG canonical figures path | `CROSS_MODULE_SWITCHING_RELAXATION` |

**Support libraries:** `tools/rlx_sw_scaling_01_fit_utils.m`, `tools/rlx_sw_scaling_02_utils.m`.

---

## P1 — Legacy functional AX (blocked outputs in typical checkout)

| `family_id` | Entry script | Notes | True class |
|-------------|--------------|-------|------------|
| `LEGACY_AX_FUNCTIONAL` | `analysis/ax_functional_relation_analysis.m` | **`cross_experiment`** run; Relaxation **`A_T`** + **`get_canonical_X()`** for **`X`**; numeric **`AX_*.csv`** often **absent** locally — treat as **`BLOCKED_MISSING_OUTPUTS`** until restored | `CROSS_MODULE_SWITCHING_RELAXATION` (when runnable) |
| `LEGACY_AX_ROBUSTNESS` | `analysis/ax_scaling_temperature_robustness.m` | Consumes saved **`AX_aligned_data.csv`** | `OLD_CODE_ONLY` / **blocked** without upstream AX tables |

---

## P1 — Bridge / replay tooling (cross-module intent)

| `family_id` | Path | Notes |
|-------------|------|-------|
| `RLX_SW_NONSVD_BRIDGE_REPLAY` | `scripts/run_relaxation_switching_nonSVD_bridge_replay_01.m` | Verify outputs when run; index as cross-module |
| `RLX_SW_ANALYSIS_HELPERS` | `analysis/relaxation_switching_bridge_visualization.m`, `analysis/relaxation_switching_knee_comparison.m`, `analysis/relaxation_switching_motion_test.m` | Visualization / motion / knee tests — **cross-module intent** |

---

## Relaxation-only neighbors (do not relabel without re-audit)

| `family_id` | Entry script | Notes |
|-------------|--------------|-------|
| `RLX_ACTIVITY_REPRESENTATION_01_02` | `run_relaxation_activity_representation_01.m`, `_02.m` | Headers assert **`RELAXATION_ONLY_NO_SWITCHING_USED`** — **not** AX until proven otherwise |

---

## Machine-readable indices

- **Artifact index:** `tables/cross_module_switching_relaxation_AX_artifact_index.csv`
- **Script index:** `tables/cross_module_switching_relaxation_AX_script_index.csv`
- **Relationship-test coverage:** `tables/cross_module_switching_relaxation_AX_relationship_test_coverage.csv`
- **Old ↔ current crosswalk:** `tables/cross_module_switching_relaxation_AX_old_current_crosswalk.csv`
- **Claim readiness:** `tables/cross_module_switching_relaxation_AX_claim_readiness_matrix.csv`
- **Placement plan:** `tables/cross_module_switching_relaxation_AX_artifact_placement_plan.csv`
- **Future naming:** `tables/cross_module_switching_relaxation_AX_future_naming_convention.csv`

**Broader Switching–Relaxation (non-AX) draft:** `docs/cross_module_switching_relaxation_index_draft.md`

---

## Governance imports

- `tables/cross_module_switching_relaxation_AX_classification_rules.csv`
- `tables/cross_module_switching_relaxation_AX_claim_boundary_plan.csv`
- `tables/cross_module_switching_relaxation_AX_completion_order.csv`
- Workspace audit: `reports/cross_module_switching_relaxation_workspace_organization_report.md`
