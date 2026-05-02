# RLX-ACTIVITY-FINAL-CLOSURE-07

## 1. Purpose and scope

This closure package summarizes the Relaxation-only activity-scalar evidence chain after RLX-ACTIVITY-REPRESENTATION-01 through RLX-ACTIVITY-LINEAGE-06. It freezes claim boundaries, scalar roles, and cross-module handoff readiness without running Switching analysis, X_eff fits, AX fits, or power-law fits.

## 2. What was already completed in AR01 through AR06

| Stage | Completion summary (verified from local verdict or status tables) |
|-------|---------------------------------------------------------------------|
| AR01 | Common RF3R2 map built; **A_obs** recommended main text; **m0_svd** best in-sample rank-1 reconstruction; unique global best scalar not claimable at AR01; baseline/window robustness not done. |
| AR02 | LOO-SVD valid folds; **m0_LOO_SVD_projection** best non-leaky held-out reconstruction; baseline/window robustness not complete at AR02 (blocked by missing variants). |
| AR03 | 12 effective variants; **m0_LOO_SVD_projection** best in every variant; ranking stable; uniqueness claimable **within tested variant grid** only. |
| Consolidation-04 | Scalar hierarchy and claim safety matrix documented; confusion audit recorded naming clashes. |
| Lineage-05 | Historical **A_T_old** export **not found**; exact identity with **m0_svd** unsafe; same conceptual SVD family safe; AX readiness **NO** until canon bridge. |
| Lineage-06 | **A_T_canon** reconstructed; affine-equivalent to m0/SVD family on RF3R2 strict subset; **A_obs** monotonic-only vs canon; **READY_FOR_AX_REINTERPRETATION** YES per Lineage-06 status. |

## 3. Final scalar dictionary

See `tables/relaxation/relaxation_activity_final_closure_07_scalar_dictionary.csv` for definitions, allowed or forbidden wording, and roles.

## 4. Final scalar hierarchy

See `tables/relaxation/relaxation_activity_final_closure_07_scalar_hierarchy.csv`.

Summary:

- **Main text:** **A_obs** (direct experimentally transparent amplitude).
- **Robust map coordinate:** **m0_LOO_SVD_projection** (non-leaky LOO rank-1 coefficient; stable across AR03 variants).
- **SVD-family equivalent references:** **m0_svd**, **SVD_score_mode1**, **A_T_canon** (affine-equivalent class on current RF3R2 object per Lineage-06 within tested mask).
- **Non-SVD / projection references:** **A_proj_nonSVD**, **projection_mean_curve** (supplement or diagnostic; **A_proj_nonSVD** not grossly distinct from SVD family on Lineage-06 tests).
- **Historical diagnostic:** **A_T_old** numerically unavailable (export missing).

## 5. Evidence summary

- **Transparency:** AR01 and AR02 retain **A_obs** as the clearest direct observable amplitude.
- **Reconstruction / coordinate:** AR02 and AR03 converge on **m0_LOO_SVD_projection** as the robust intrinsic rank-1 coordinate under the tested RF3R2 map variants.
- **Definition bridge:** Lineage-06 shows the legacy row-major **sigma1*U(:,1)** reconstruction (**A_T_canon**) aligns with the current m0/SVD-family coordinates in an affine equivalence class on the strict inclusion run.
- **Legacy gap:** Lineage-05 remains authoritative that the **historical A_T_old** table was **not** recovered; Lineage-06 does **not** restore that file.

## 6. Claim boundaries

See `tables/relaxation/relaxation_activity_final_closure_07_claim_boundaries.csv`. Safe claims include direct-transparency language for **A_obs**, LOO coordinate robustness language scoped to tested variants, and reconstruction language for **A_T_canon** without implying recovery of the missing export.

## 7. Confusion resolutions

See `tables/relaxation/relaxation_activity_final_closure_07_confusion_resolution.csv`. Key resolutions include separating **m0_svd** versus **m0_LOO**, scoping **unique best** to AR03 variant sweep, and treating Lineage-06 MATLAB script naming limits as tooling-only.

## 8. Status of A_T_old versus A_T_canon

- **A_T_old:** Not present as a repo artifact for numeric reconciliation (Lineage-05). Do **not** cite as data.
- **A_T_canon:** Definition-level reconstruction on the current RF3R2 object (Lineage-06). Affine-equivalent to m0/SVD-family coordinates under conservative thresholds on the Lineage-06 strict temperature mask (eight temperatures in that run). Not identical to an absent historical CSV row-by-row.

## 9. What is ready for cross-module AX

Relaxation-internal lineage is sufficient to **authorize** a **separate** cross-module AX reinterpretation task using canonical Relaxation scalars. Recommended candidates: **m0_LOO_SVD_projection** primary; **m0_svd**, **SVD_score_mode1**, **A_T_canon** as SVD-family references; **A_obs** as direct-observable comparison. No AX fit was executed in this closure.

## 10. What is not claimed yet

- No proof of Switching Relaxation AX relation from Relaxation tables alone.
- No restoration or universality of any legacy exponent including **0.66**.
- No statement that **m0_LOO** is the unique physical material amplitude in a materials sense.
- No exact numeric identity **A_T_old = m0_svd** or recovery of **A_T_old**.

## 11. Archival / tracking plan

Most generated **tables/relaxation/** and **reports/relaxation/** paths are **gitignored** (`tables/**`, `reports/**`). See `tables/relaxation/relaxation_activity_final_closure_07_archival_plan.csv` for suggested future `git add -f` grouping. **Do not execute staging in this task.**

## 12. Final verdicts

Convergent wording for manuscripts and downstream AX briefs:

**A_obs** is retained as the direct experimentally transparent relaxation amplitude. The robust map coordinate is **m0_LOO_SVD_projection**, which is the best rank-1 reconstruction coordinate across leave-one-temperature-out SVD and the tested RF3R2 baseline/window/map variants in AR03. The legacy **A_T** definition was reconstructed canonically as **A_T_canon = sigma1*U(:,1)** on the current RF3R2 object and is affine-equivalent to the current m0/SVD-family coordinates within Lineage-06 scope. The historical **A_T_old** table was not recovered, so claims of exact identity with the historical artifact remain unsafe. This Relaxation-only closure does not run AX or power-law fits, but it authorizes a separate cross-module AX reinterpretation using the canonical SVD-family relaxation coordinate candidates above.

### Forbidden wording (do not use)

- `A_T_old was recovered`
- `A_T_old = m0_svd` (exact numeric)
- `m0_LOO is the unique physical material amplitude`
- `the old 0.66 law is restored` / `the exponent is universal`
- `Switching Relaxation bridge is proven here`

---

Artifacts for this closure: `relaxation_activity_final_closure_07_*.csv`, this report, status key file.
