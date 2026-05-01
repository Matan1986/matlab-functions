# Cross-module Switching–Relaxation AX index (draft)

**Status:** Draft pointer shell — expand when artifact paths are harvested from latest runs.  
**Classification rule:** If an artifact uses **Switching `X_eff` / `X_eff_nonunique`** or Switching-matched tables with Relaxation scalars, it is **CROSS_MODULE_SWITCHING_RELAXATION**, **not** Relaxation-only, **even if stored under `reports/relaxation/` or `tables/relaxation/`**.

## P0 cross-module families (anchors)

| Family | Entry script(s) | Typical durable outputs (when run) |
|--------|-----------------|-----------------------------------|
| RLX_SW_SCALING_01 | `run_relaxation_switching_scaling_01.m` | `tables/relaxation/relaxation_switching_scaling_01_matched_observables.csv`, `relaxation_switching_scaling_01_claim_safety.csv`, report under `reports/relaxation/` |
| RLX_SW_SCALING_02 | `run_relaxation_switching_scaling_02.m` | `relaxation_switching_scaling_02A_*.csv` family |
| RLX_SW_SCALING_03 | `run_relaxation_switching_scaling_03.m` | Promoted `tables/relaxation/`, `reports/relaxation/` per script |
| RLX_ACTIVITY_SCALARIZATION_01 | `run_relaxation_activity_scalarization_01.m` | `figures/relaxation/canonical/` + audit markdown references |
| RLX_SVD_XSCALING_01 | `run_relaxation_svd_xscaling_01.m` | `relaxation_svd_xscaling_01_claim_safety.csv` |

## Supporting tooling

- `tools/rlx_sw_scaling_01_fit_utils.m`, `tools/rlx_sw_scaling_02_utils.m`

## Relaxation-only near-neighbors (do not mislabel as AX)

- `run_relaxation_activity_representation_01.m`, `_02.m` — headers state Relaxation-only; **do not** fold into Switching–Relaxation AX without re-audit.

## Governance imports

- Claim boundaries: `tables/cross_module_switching_relaxation_AX_claim_boundary_plan.csv`
- Classification rules: `tables/cross_module_switching_relaxation_AX_classification_rules.csv`
