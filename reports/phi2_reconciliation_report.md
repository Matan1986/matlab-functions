# Phi2/Kappa2 Reconciliation Audit

## What old results said (file evidence)
- `reports/rank2_report.md` and `tables/rank2_metrics.csv` stated `MODE2_REAL=YES`, `MODE2_LINKED_TO_LANDSCAPE=YES`, `RANK1_SUFFICIENT=NO`.
- `reports/deformation_closure_report.md` stated `PHI2_IS_DEFORMATION_OF_PHI1=PARTIAL` and `DEFORMATION_BASIS_MATCHES_RANK2=NO`.
- `tables/phi2_extended_deformation_basis_status.csv` and `tables/phi2_second_order_deformation_status.csv` kept strict deformation-closure verdicts negative (`...SUFFICIENT=NO`, irreducible=YES).
- Legacy mode23/mechanism reports supported a two-dimensional structural interpretation via regression/correlation gains.

## What new canonical result says
- `tables/phi2_verdicts.csv`: `MODE2_SIGNIFICANT=NO`, `PHI2_IS_DEFORMATION=YES`, `RANK2_IMPROVES_RECONSTRUCTION=YES`.
- `status/phi2_status.txt`: `SECOND_MODE_PHYSICAL=NO`.
- Quantitatively on the canonical matrix: mode-1 variance 0.957642, mode-2 variance 0.025487, global rank2/rank1 RMSE ratio 0.631104.

## Same-input replay result (data vs logic)
- Same residual matrix (`tables/phi2_residual_map.csv`) reproduces legacy no_22K metrics: sigma1/sigma2 6.263467, rank2 relFro gain 0.075052, best|corr| 0.926461.
- Therefore, the old/new mismatch is not caused by a different residual matrix.
- Primary difference is decision logic: old narrative treated strong RMSE gain + correlations as sufficient for 'real mode-2', while new logic requires mode-2 explained variance >= 0.05 (not met).
- Additional discrepancy: legacy 'mode2 stability' values match mode-1 LOO values (labeling mismatch), inflating prior stability confidence.
- Deformation verdict differences come from criterion choice: strict basis-closure (old) vs correlation threshold (new).

## Is the contradiction real or methodological?
- Classification: methodological, not a direct physics contradiction.
- Flags: DATA_SELECTION_DIFFERENCE=YES, SIGNIFICANCE_THRESHOLD_DIFFERENCE=YES, DEFORMATION_TEST_DIFFERENCE=YES, PURE_LABELING_DIFFERENCE=YES, GENUINE_PHYSICS_CONTRADICTION=NO.

## Current support status for Phi2 claims
- rank-2 structure: **supported** (rank-2 materially reduces reconstruction error).
- stable structure: **not supported as a robust Phi2 shape claim** under true Phi2 LOO; legacy stability label was inconsistent.
- independent mode: **not currently supported** by new significance gate (`MODE2_SIGNIFICANT=NO`).
- deformation of Phi1: **supported in weak/correlation sense** (`PHI2_IS_DEFORMATION=YES`), but **not closed** under old strict basis RMSE criteria.

## Safe statement now
- Safe: the canonical residual has a dominant rank-1 mode plus a subleading structured correction; that correction improves reconstruction but does not pass the new independent-mode significance criterion.

## Not yet safe statement
- Not safe: claiming a universally stable, independently physical mode-2 based solely on old rank2 labels.
- Not safe: claiming strict deformation-basis closure is achieved.
