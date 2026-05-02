# RLX-ACTIVITY-LINEAGE-06: Legacy A_T definition on RF3R2

## 1. Purpose and scope

Reconstruct **A_T_canon = sigma1 * U(:,1)** from **D(T,t)** with rows=temperature, columns=time, using the same RF3R2 curve inclusion and time grid as RLX-AR01 (`strict_default_no_quality_flag` with fallback to default replay if fewer than 3 temperatures). Relaxation module only.

## 2. Not recovery of missing A_T_old

This is a **new canonical reconstruction** on the current RF3R2 object. It does **not** recover the missing exported legacy `temperature_observables.csv` artifact.

## 3. RF3R2 input and inclusion audit

See `relaxation_AT_canon_lineage_06_input_audit.csv`.

## 4. Construction of D(T,t)

- Build **M** as AR01: columns are traces vs common **linspace** time grid (**nGrid=320**) on intersection of per-trace time support.
- **D = M.'** so **rows = temperature**, **columns = time** (legacy orientation).

## 5. Legacy definition reconstruction

`[U,S,V] = svd(D,'econ')`, **A_T_canon_raw = S(1,1)*U(:,1)**.

## 6. Sign convention

- Compare raw vector to **RCON SVD_score_mode1** (`m0_svd`).
- If Pearson correlation is negative, flip **A_T** and **V(:,1)**.
- Recorded in `relaxation_AT_canon_lineage_06_svd_summary.csv`.

## 7. Rank-1 SVD summary

- **sigma1** = 0.0009524741509687567
- **rank-1 energy fraction** = 0.9991759524142521

## 8. Comparison to m0_svd

Relationship class: **affine-equivalent** (see scalar comparison table).

## 9. Comparison to m0_LOO_SVD_projection

Relationship class: **affine-equivalent**. LOO table present: **YES**.

## 10. Comparison to SVD_score_mode1

Relationship class: **affine-equivalent**.

## 11. Comparison to A_obs and A_proj_nonSVD

- **A_obs:** monotonic-only
- **A_proj_nonSVD:** affine-equivalent

## 12. Relationship classification

Thresholds (conservative): **|Pearson|** >= 0.995 for equivalence claims; affine NRMSE vs **std(y)** <= 0.020 for affine-equivalent; Spearman >= 0.90 suggests monotonic-only if affine fails.

## 13. Equivalence to current m0/SVD coordinates

On this RF3R2 object, **A_T_canon** matches current **m0_svd / SVD_score_mode1** within the stated thresholds. The gap noted in LINEAGE-05 vs missing **A_T_old** was therefore likely dominated by **source object / artifact lineage** rather than a different SVD temperature-amplitude definition.

## 14. Future AX reinterpretation

**READY_FOR_AX_REINTERPRETATION = YES** (task does not run AX).

## 15. Future power-law retest

**READY_FOR_POWERLAW_RETEST = YES** (authorization only; no fit run).

## 16. Final verdicts

- **Legacy definition reconstructed on RF3R2:** YES.
- **Exact old A_T table recovered:** NO.
