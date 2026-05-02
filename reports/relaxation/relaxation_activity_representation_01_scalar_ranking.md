# RLX-ACTIVITY-REPRESENTATION-01 — independent relaxation-amplitude scalar ranking

## 1. Executive summary

We built a **common relaxation map** `M(t, T)` from **RF3R2 repaired** `delta_m` samples and **per-temperature** candidate amplitudes from **RCON_02B** plus a **mean-template projection** (`projection_mean_curve`, same construction as the RF5A m0-proxy audit). For each candidate we fit a **shared temporal mode** `psi(t)` in closed form: `psi = M a / (a' a)` and tested **in-sample** Frobenius error, **leave-one-temperature-out (LOTO)** curve RMSE, **inclusion-set** sensitivity, **sign / abs / z-score** variants, and **temperature smoothness** diagnostics.

**Key scientific point:** The **SVD mode-1 temperature weight** `m0_svd` (RCON `SVD_score_mode1`) is, by construction, the **first right singular vector** of the same `M` (up to sign). Using it as the fixed amplitude vector in a rank-1 outer product recovers the **optimal rank-1** fit in Frobenius norm. Therefore **in-sample and LOTO minima for `m0_svd` are expected**; they are **not** an independent argument that a new “unknown” scalar is best. The more policy-relevant comparison is **non-m0** candidates: **best non-m0 in-sample and LOTO (strict, raw) is `A_proj_nonSVD`**, with `projection_mean_curve` nearly identical (see tables).

- **n (strict default, no quality flag):** 8 temperatures (see `relaxation_activity_representation_01_common_scalar_table.csv`).
- **Map grid:** 320 time points on the intersection of post-field-off time support across those traces; linear interpolation in time.
- **Verdict on unique “best” scalar:** **NO** — `SAFE_TO_CLAIM_UNIQUE_BEST_RELAXATION_SCALAR = NO` in `relaxation_activity_representation_01_verdicts.csv`.

## 2. Confirmation: no Switching / X inputs

**No** `X_eff`, `X_canon`, `X_replay`, `X_eff_nonunique`, or any Switching table was read. All inputs are under `tables/relaxation/` (plus optional prior audit path recorded in the input inventory).

## 3. Prior evidence (RLX-ACTIVITY-REPRESENTATION-00)

`reports/relaxation/relaxation_activity_representation_00_prior_evidence_audit.md` found **PARTIAL** prior work: qualitative inventory, X-bridge–dominant fits, and proxy-vs-`m0` tables that did not simultaneously rank `A_obs` / `A_proj` / `m0` on a **common** `M` with **LOTO**. This run addresses that gap.

## 4. Input provenance

| Role | File |
|------|------|
| **Curve map** | `tables/relaxation/relaxation_RF3R2_repaired_curve_samples.csv` |
| **Trace / T / flags** | `tables/relaxation/relaxation_RF3R2_repaired_curve_index.csv` |
| **A_obs, A_proj_nonSVD, SVD_score_mode1** | `tables/relaxation/relaxation_RCON_02B_Aproj_vs_SVD_score.csv` |
| **Run context** | `results/relaxation/runs/<run_id>/` from `createRunContext` (this execution) |

**Common map source (authoritative for this task):** `relaxation_RF3R2_repaired_curve_samples.csv` joined to the inclusion-filtered `curve_index` rows, `rf3r2_repaired_20260427_193555_src_run_2026_04_26_234453` build (see `relaxation_RF3R2_repaired_build_status.csv` for lineage).

**Legacy A_T:** not found in-repo → `LEGACY_AT_AVAILABLE = NO`.

## 5. Common map definition

- **M:** `nTime` x `nT` with `nTime = 320`, `delta_m` interpolated onto `tGrid = linspace(tMinCommon, tMaxCommon, 320)`.
- **Sign:** stored RF3R2 `delta_m` (already canon/sign-processed in producer).
- **Normalization:** none applied beyond interpolation (same `M` for all scalar tests).
- **Strict inclusion:** `trace_valid_for_relaxation == YES`, `valid_for_default_replay == YES`, `is_quality_flagged == NO`.
- **Default replay / all valid:** same masks as in script (`relaxation_activity_representation_01_verdicts.csv` inputs).

## 6. Scalar definitions

See `tables/relaxation/relaxation_activity_representation_01_scalar_definitions.csv`.

## 7. Rank-1 reconstruction (in-sample)

Per scalar `a(T)`, fit `psi = M*a/(a'a)`, reconstruction `M_hat = psi * a'`. Metrics in `relaxation_activity_representation_01_reconstruction_metrics.csv`.

On **strict** raw variants, **lowest Frobenius relative error** is **`m0_svd`** (consistent with rank-1 optimality). **`A_obs`** is worst among tested scalars (still excellent variance explained, ~0.9989).

## 8. Held-out temperature reconstruction (LOTO)

For each held-out `T`, fit `psi` on remaining temperatures, predict held-out column. Results: `relaxation_activity_representation_01_heldout_temperature_metrics.csv`.

**Best mean LOTO RMSE (strict, raw):** `m0_svd`. **Best among non-m0:** **`A_proj_nonSVD`** (`BEST_HELDOUT_NON_M0_SCALAR`).

## 9. Inclusion-set sensitivity

`relaxation_activity_representation_01_inclusion_set_sensitivity.csv`. On this run, **raw** winners did **not** change between `default_replay`, `strict_default_no_quality_flag`, and `all_trace_valid` for the top tie among m0 / A_proj / projection_mean (see `SCALAR_RANKING_DEPENDS_ON_INCLUSION_SET`).

## 10. Sign / scale sensitivity

`relaxation_activity_representation_01_sign_scale_sensitivity.csv`. **raw** vs **sign_flip_if_negative_mean** are identical for this dataset (so **no** winner change). **zscore_diagnostic** deliberately destroys scale and is not a primary candidate.

## 11. Temperature smoothness

`relaxation_activity_representation_01_temperature_smoothness.csv` (second-difference roughness and crude monotonicity fraction on sorted T). Used as **sanity only**, not a ranking objective.

## 12. Baseline / window robustness

**Not tested** — no second pre-stored `M` variant (different baseline/window) was loaded. `BASELINE_WINDOW_ROBUSTNESS_DONE = NO`. See `NEED_FOLLOWUP_BASELINE_WINDOW = YES`.

## 13. Pairwise scalar relationships

`relaxation_activity_representation_01_scalar_pairwise_comparison.csv` (Pearson / Spearman on the strict common table). Diagnostic only.

## 14. Decision matrix

`relaxation_activity_representation_01_decision_matrix.csv` — per-scalar **fro_rel** and **variance explained** (strict, raw).

**Interpretation matrix (qualitative + quantitative):**

| Scalar | Directness | Reconstruction (strict, raw fro_rel) | Note |
|--------|------------|--------------------------------------|------|
| `A_obs` | highest | higher error vs m0 / Aproj / proj_mean | best for transparency |
| `A_proj_nonSVD` | medium | ties near m0 | signed projection |
| `m0_svd` | lower (global mode weight) | **best** (expected) | same basis as rank-1 |
| `projection_mean_curve` | proxy | ties near m0 | template leakage |

## 15. Recommended primary scalar for paper

- **Main text (`RECOMMENDED_MAIN_TEXT_SCALAR`):** **`A_obs`** — most **direct** measurable amplitude; reconstruction gap vs optimal rank-1 is acceptable but not minimal.
- **Supplement (`RECOMMENDED_SUPPLEMENT_SCALARS`):** **`m0_svd`** (rank-1 coefficient / diagnostic), **`projection_mean_curve`**, **`A_proj_nonSVD`**.
- **Best compromise among non-m0 (`BEST_COMPROMISE_SCALAR`):** **`A_proj_nonSVD`** (ties **projection_mean_curve** numerically on strict raw fro_rel in this build).

## 16. What remains unresolved

- **LOO-SVD / basis stability** when temperatures are deleted from the matrix (`NEED_FOLLOWUP_LOO_SVD = YES`).
- **Alternate baseline/window maps** for ranking stability (`NEED_FOLLOWUP_BASELINE_WINDOW`).
- **Legacy A_T** lineage file absent locally.

---

**Artifacts:** see `tables/relaxation/relaxation_activity_representation_01_*.csv` and `relaxation_activity_representation_01_status.csv`. Optional PNGs under `figures/relaxation/canonical/`.
