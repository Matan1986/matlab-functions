# RLX-ACTIVITY-CONSOLIDATION-04 — Relaxation activity scalar evidence and lineage roadmap

## 1. Purpose and scope

This consolidation summarizes Relaxation-only evidence from **RLX-ACTIVITY-REPRESENTATION-01** (AR01), **-02** (AR02), and **-03** (AR03), aligns paper-safe wording, records claim safety, and scopes **RLX-ACTIVITY-LINEAGE-05** for **`A_T_old ↔ m0_svd`** reconciliation. No Switching inputs, no `X_eff`, no A~X fits, no power-law fitting, and no edits to existing Relaxation artifacts were performed as part of this task.

## 2. Artifact inventory summary

All checklist paths for AR01–AR03 scripts, tables, reports, and canonical PNGs **exist** in the workspace under `run_relaxation_activity_representation_*.m`, `tables/relaxation/relaxation_activity_representation_0*`, `reports/relaxation/`, and `figures/relaxation/canonical/`. Runners live at the **repository root** (placement **ambiguous** vs `Relaxation ver3/` scripts but acceptable for this repo). At consolidation time, these artifacts were **not tracked in git** (local/untracked); see `relaxation_activity_consolidation_04_artifact_inventory.csv`.

Candidate lineage scripts reviewed for naming alignment (existence only):  
`Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m`,  
`Relaxation ver3/run_relaxation_RF5A_m0_proxy_audit_RF3R.m`,  
`Relaxation ver3/run_relaxation_RF5A_RF3R2_primary_rank1_and_m0.m`,  
`Relaxation ver3/run_relaxation_activity_A_vs_m0_diagnostic_RF3R.m`.

## 3. AR01 evidence summary

| Topic | Summary |
|------|---------|
| Primary map | RF3R2 repaired curve samples + curve index + `relaxation_RCON_02B_Aproj_vs_SVD_score.csv` amplitudes (`relaxation_activity_representation_01_input_inventory.csv`). |
| Inclusion | Strict default replay without quality flag: `trace_valid_for_relaxation`, `valid_for_default_replay`, `~is_quality_flagged` (see AR01 report §5). |
| Compared scalars | `A_obs`, `A_proj_nonSVD`, `m0_svd`, `projection_mean_curve`; legacy **A_T** not joined (`LEGACY_AT_AVAILABLE = NO`). |
| Best in-sample rank-1 | **`m0_svd`** (expected with full-map rank-1 construction). |
| Best held-out (LOTO, strict raw) | **`m0_svd`**; best **non-m0** held-out **`A_proj_nonSVD`**. |
| Main-text recommendation | **`A_obs`** (`RECOMMENDED_MAIN_TEXT_SCALAR`). |
| Supplement recommendation | **`m0_svd`**, **`projection_mean_curve`**, **`A_proj_nonSVD`** (semicolon list in verdicts). |
| Unique best scalar | **NO** (`SAFE_TO_CLAIM_UNIQUE_BEST_RELAXATION_SCALAR = NO`). |
| Baseline/window sweep | **Not in AR01** (`BASELINE_WINDOW_ROBUSTNESS_DONE = NO`; superseded by AR03). |

## 4. AR02 evidence summary

| Topic | Summary |
|------|---------|
| LOO-SVD folds | **8** held-out temperatures; **`LOO_SVD_ALL_FOLDS_VALID = YES`**. |
| m0_LOO vs full m0 | Pearson/Spearman **−1** with documented **global sign convention** difference; scale ratio median ≈ **1** (`DIAGNOSTIC_median_abs_scale_ratio_LOO_over_full`). |
| **M0_LOO_SIGN_STABLE** | **YES** (verdict table). |
| **M0_LOO_HELDOUT_RECONSTRUCTION_BEST** | **YES** among non-leaky methods on aggregate summary (`relaxation_activity_representation_02_loo_svd_summary.csv`). |
| Map-variant robustness | **Partial / blocked**: **2** variants catalogued, **1** analyzed (`primary_RF3R2_repaired`); **`BASELINE_WINDOW_ROBUSTNESS_DONE = NO`**, **`BASELINE_WINDOW_ROBUSTNESS_BLOCKED_BY_MISSING_VARIANTS = YES`**. Ranking stability across map definitions **UNKNOWN** in AR02 verdicts. |
| Caveat | Fold-level table shows **one temperature** where **`A_obs`** has lowest held-out RMSE among listed scalars (`heldout_rmse_*` row at **23 K**) while non-leaky winner column still favors **`m0_LOO_SVD_projection`**—aggregate ranking remains **m0_LOO**-first. |

## 5. AR03 evidence summary

| Topic | Summary |
|------|---------|
| Variants | **12** requested and effective (`VARIANTS_EFFECTIVE = 12`). |
| Best scalar overall | **`m0_LOO_SVD_projection`** for held-out LOO RMSE in **every** variant (`ranking_summary.csv`). |
| m0_LOO always best | **YES** (`M0_LOO_ALWAYS_BEST`). |
| Ranking flips | **None** vs reference variant **`AR03_B1_W1_G1_I1`** (`relaxation_activity_representation_03_robustness_audit.md`). |
| Ranking stability | **`SCALAR_RANKING_STABLE_ACROSS_VARIANTS = YES`**. |
| Unique scalar claimable | **`UNIQUE_BEST_SCALAR_CLAIMABLE = YES`** — applies to **the 12 tested map-definition variants**, not the broader “single scalar for all scientific roles” question (contrast AR01 uniqueness verdict). |
| Caveats | **G3 LOG_TIME_GRID** not included; robustness is **explicit design-limited**, not universal over all maps. |

## 6. Current scalar hierarchy

Canonical roles (detail in `relaxation_activity_consolidation_04_scalar_hierarchy.csv`):

| Layer | Scalar(s) |
|------|-----------|
| Main text — direct observable | **`A_obs`** |
| Supplement — intrinsic rank-1 map coordinate | **`m0_LOO_SVD_projection`** |
| Supplement — non-SVD compromise | **`A_proj_nonSVD`** ( **`projection_mean_curve`** optional tied proxy ) |
| Diagnostic / legacy | **`A_T_old`** until **LINEAGE-05** completes |
| Reference / leaky clarity | **`m0_svd`** full-column reference vs LOO coefficient track |

## 7. Claim safety matrix

See `relaxation_activity_consolidation_04_claim_safety_matrix.csv`. Headline outcomes:

- **SAFE**: transparent **`A_obs`** main-text role; **`m0_LOO`** as best tested **non-leaky** rank-1 reconstruction coordinate on RF3R2 under AR02/03 definitions; **`A_proj_nonSVD`** as non-SVD compromise; robustness statements **scoped** to AR03’s 12 variants and AR02 folds.
- **UNSAFE**: **`A_obs`** as reconstruction-best; **`m0_LOO`** as unique **physical** material amplitude.
- **NOT_YET_TESTED**: **`A_T_old = m0_svd`**, **0.66 exponent** universality or scalarization sensitivity (out of consolidation scope).

## 8. Confusion / contradiction audit

Recorded in `relaxation_activity_consolidation_04_confusion_audit.csv`. Highlights:

- **m0_svd** (full-column, AR01 in-sample optimality) vs **m0_LOO_SVD_projection** (LOO coefficient track, AR02/03 winner labels).
- **UNIQUE_BEST** in AR03 vs **SAFE_TO_CLAIM_UNIQUE_BEST** in AR01 — different definitions.
- AR02 report typo risk: **“m0_RCV”** vs **RCON** in scale diagnostic sentence.
- AR02 **`BASELINE_WINDOW_ROBUSTNESS_DONE = NO`** vs AR03 **`BASELINE_WINDOW_ROBUSTNESS_DONE = YES`** — interpret as **task-generation gap**, not logical contradiction.

No edits were applied to source reports in this audit-only task.

## 9. Why `A_T_old ↔ m0_svd` lineage remains necessary

AR01 did **not** attach a legacy **`A_T`** column (`LEGACY_AT_AVAILABLE = NO`). AR02–AR03 establish **`m0_LOO`** and **`m0_svd`** behavior on the **current RF3R2 + RCON** stack but **do not** ingest historical **`temperature_observables`** amplitudes. Without a dedicated join and normalization audit, **numerical identity** of legacy **`A_T`** to **`m0_svd`** (or to **`m0_LOO`**) is **not paper-safe**.

## 10. Roadmap for `RLX-ACTIVITY-LINEAGE-05`

See `relaxation_activity_consolidation_04_next_lineage_task.csv`.

**Why:** Close the definitional gap between **published/historical relaxation amplitude tracks** and **current RCON `SVD_score_mode1`**.

**What to compare:** Temperature-aligned **`A_T_old`** series vs **`m0_svd`** (and optionally **`m0_LOO`** coefficients once exported on the same index); sign/scale conventions; producer metadata.

**Relaxation-only:** Uses Relaxation tables and documented Relaxation producers; **no** Switching/`X_eff`/AX bridge.

**Why not AX yet:** AX reinterpretation assumes Relaxation observables are **stable and uniquely named** across eras; lineage must precede cross-module narrative.

**Expected artifacts:** Joined temperature table, agreement metrics CSV, verdicts CSV, reconciliation markdown report (paths listed in next-task CSV).

**Readiness for AX reinterpretation:** **After** lineage verdicts and editorial adoption of this hierarchy—not before.

## 11. Final paper-safe wording

Use wording convergent with:

> We use **`A_obs`** as the primary experimentally direct relaxation amplitude. A relaxation-only representation audit shows that **`m0_LOO_SVD_projection`** is the best rank-1 reconstruction coordinate of the RF3R2 relaxation map under leave-one-temperature-out SVD and the tested baseline/window/map variants in RLX-ACTIVITY-REPRESENTATION-03. **`A_proj_nonSVD`** provides the best non-SVD compromise on the shared map. The legacy **`A_T`** coordinate is conceptually related as an SVD/rank-1 relaxation amplitude, but **exact numerical identity** with current **`m0_svd`** remains a **separate lineage task** (**RLX-ACTIVITY-LINEAGE-05**).

Do **not** claim from this consolidation:

- **`m0_LOO`** is the unique physical amplitude of the material.
- **`A_T_old = m0_svd`** without lineage evidence.
- **0.66 exponent** universality or scalarization conclusions.
- Switching–Relaxation bridge reinterpretation.

## 12. Final verdicts

| Verdict | Value |
|---------|-------|
| Consolidation task complete | **YES** |
| Relaxation module only | **YES** |
| Switching / X / AX / power-law runs in this task | **NO** |
| AR01–AR03 artifacts located | **YES** (all checklist paths present locally) |
| Paper-safe **A_obs** main text | **PARTIAL** (editorial PARTIAL flags remain in AR01 verdicts—substantively aligned with recommendation) |
| Paper-safe **m0_LOO** rank-1 supplement | **YES** (scoped to RF3R2 audits) |
| **Unique physical amplitude** claim | **NO** |
| **`A_T_old = m0_svd`** claim | **NOT established** |
| Next lineage task documented | **YES** |
| Ready for AX reinterpretation | **NO** (pending lineage + hierarchy adoption) |

Supporting machine-readable keys: `tables/relaxation/relaxation_activity_consolidation_04_status.csv`.
