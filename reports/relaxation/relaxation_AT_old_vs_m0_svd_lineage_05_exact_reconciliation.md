# RLX-ACTIVITY-LINEAGE-05 — Exact lineage reconciliation (A_T_old vs m0_svd)

## 1. Purpose and scope

Relaxation-only diagnostic comparing legacy **`A_T`** from the observable stability audit export to current **`m0_svd`** scores. No Switching, no `X_eff`, no AX fits.

## 2. Why Relaxation-only

All inputs are Relaxation producers/tables; no cross-module bridge claims.

## 3. Old A_T lineage

Producer: `Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m`.

- `buildTemperatureObservablesTable` writes **`A_T = result.A`** where **`A = sigma(1)*U(:,1)`** from **`[U,S,V] = svd(dMMap,"econ")`** with **`dMMap`** shaped **temperature × time** (`analyzeScenario`).
- Orientation: `peakSignedValue(sigma(1)*u1)` flips sign of **U and V columns** together.

Canonical saved table path checked: `C:\Dev\matlab-functions\results\relaxation\runs\run_2026_03_10_175048_relaxation_observable_stability_audit\tables\temperature_observables.csv` — **exists: false**.

## 4. Current m0_svd lineage

- RF5A script: `Relaxation ver3/run_relaxation_RF5A_m0_proxy_audit_RF3R.m` builds **`X`** rows=time, cols=temp, then **`m0_svd = S(1,1)*V(:,1)`**, with **`psi = U(:,1)`** sign flip via sum(psi).
- Saved scores: `C:\Dev\matlab-functions\tables\relaxation_RF5A_m0_svd_scores_RF3R.csv`
- RCON reference (AR01 stack): `C:\Dev\matlab-functions\tables\relaxation\relaxation_RCON_02B_Aproj_vs_SVD_score.csv`

## 5. Matrix orientation and SVD definition comparison

For **`dMMap = X'`**, the **left** singular vector of **`dMMap`** (temperature axis) corresponds to the **right** singular vector of **`X`** (temperature axis) — **transpose pair**, same rank-1 temperature weights up to sign conventions in code.

## 6. Temperature-set alignment

**Common temperatures with stored `A_T` and RF5A `m0_svd_score`:** 0.

## 7. Row-level numerical reconciliation

**Blocked:** insufficient overlap or missing legacy **`temperature_observables.csv`** in workspace.

## 8. Difference diagnosis

See `relaxation_AT_old_vs_m0_svd_lineage_05_difference_diagnosis.csv`.

## 9. Relationship classification (conservative)

| Relationship | Verdict this workspace |
|--------------|-------------------------|
| Numerically identical | **NOT established** — no stored **`A_T`** column to join (`COMMON_TEMPERATURES_FOUND = NO`). |
| Sign-equivalent | **UNKNOWN** — row-level comparison blocked. |
| Scale-equivalent | **UNKNOWN** — row-level comparison blocked. |
| Affine-equivalent | **UNKNOWN** — row-level comparison blocked. |
| Monotonic only | **UNKNOWN** for **`A_T_old` vs `m0_svd`**; RF5A vs RCON Spearman = **1** on **n = 8** (internal consistency only). |
| Same conceptual family (rank-1 SVD temperature amplitude) | **YES** at definition level — transpose pairing **`dMMap = X'`** links **`sigma*U(:,1)`** on temp×time to **`sigma*V(:,1)`** on time×temp when the underlying matrix is the same object. |
| Different numerical artifacts | **PARTIAL evidence** — **`SOURCE_OBJECT_DIFFERENCE = YES`** (legacy DeltaM map stack vs RF3R canonical **`run_2026_04_26_234453`** curves) independent of whether transpose algebra would agree on a recovered matrix. |

## 10. Is exact identity claim safe?

**NO.** **`EXACT_IDENTITY_CLAIM_SAFE = NO`** until **`temperature_observables.csv`** with **`A_T`** from the stability audit is located and matched per-temperature to **`m0_svd`**.

## 11. Is same conceptual family claim safe?

**YES**, narrowly: both objects are **rank-1 singular-value temperature weights** from a relaxation **ΔM** map matrix; orientation differs (**rows=T vs cols=T**) per **`svd` conventions** documented above.

## 12. Is RLX-ACTIVITY-LINEAGE-06 justified?

**PARTIAL** — **`LINEAGE_06_JUSTIFIED = PARTIAL`**. Reason: canonical **`run_2026_03_10_175048_relaxation_observable_stability_audit`** export is **missing** here; recovering **`dMMap`** CSVs or re-running the stability audit is required before a **canonical reconstruction** of legacy **`A_T`** can be audited.

## 13. Ready for AX reinterpretation

**NO** — **`READY_FOR_AX_REINTERPRETATION = NO`** until the legacy **`A_T`** source is recovered or definitively ruled unavailable with a written fallback policy.

## 14. Final verdicts

Machine-readable keys: `tables/relaxation/relaxation_AT_old_vs_m0_svd_lineage_05_status.csv`.

**Internal consistency check (current pipeline only):** `relaxation_AT_old_vs_m0_svd_lineage_05_numeric_comparison.csv` shows **RF5A `m0_svd_score` vs RCON `SVD_score_mode1`** Pearson ≈ **1**, Spearman **1**, affine normalized RMSE ≈ **4.6e-4** on **n = 8** common temperatures — this **does not** validate **`A_T_old`**; it only shows today’s RF5A export matches the RCON column on the RF3R grid subset.

### What changed between legacy `A_T` and current `m0_svd` (working explanation)

At **definition** level, the stability audit **`A_T`** is **`σ₁ u₁`** from **`svd(dMMap)`** with **`dMMap`** oriented **temperature × time**, while RF5A **`m0_svd`** is **`σ₁ V(:,1)`** from **`svd(X)`** with **`X`** oriented **time × temperature** — these are the standard **transpose pair** of singular vectors when **`dMMap = X'`**. Separately, **provenance** differs: the audit selects historic **DeltaM map variants** from **`resolveLatestCompleteSourceRun`**, whereas **`m0_svd`** here comes from **RF3R canonical post-field-off** curves (**`run_2026_04_26_234453`**) with strict default-replay filtering. In **this** workspace the exported **`temperature_observables.csv`** that would carry **`A_T`** is **absent**, so **numeric** equality vs **`m0_svd`** cannot be tested; the dominant diagnosed gap is **missing legacy artifact** plus **source-object / preprocessing** lineage, not a demonstrated new physical mechanism.
