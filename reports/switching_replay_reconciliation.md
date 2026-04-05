# Switching canonical replay: replay plan vs core coverage reconciliation

Scope: Switching only. Aging and Relaxation excluded. No MATLAB execution; file-based inspection only.

## Files read

- `tables/switching_replay_plan.csv`
- `tables/switching_core_analysis_coverage.csv`

## Exact conflict

- **`switching_replay_plan.csv`** assigns **priority 1** to `replay_tier=reconstruction` (`run_minimal_canonical.m`, `run_switching_canonical.m`) and **priority 2** to `replay_tier=phi1_phi2` (six analysis scripts under `Switching/analysis/`).
- **`switching_core_analysis_coverage.csv`** states **`replay_required=NO`** for **`RECONSTRUCTION`** and **`PHI1`**, and **`replay_required=YES`** only for **`SCALING`**, citing missing `switching_full_scaling_parameters.csv` under TRUSTED_CANONICAL runs and naming `Switching/analysis/switching_full_scaling_collapse.m`.

So the plan orders reconstruction then Phi-tier first, but coverage says those two core types do not need replay, while scaling does.

## Governing rule chosen

**`switching_core_analysis_coverage.csv` governs whether each listed core analysis type must be replayed (`replay_required`).**  
**`switching_replay_plan.csv` governs relative priority, `replay_tier`, and `guard_status` among scripts when building a replay queue; it does not override a `replay_required=NO` finding for a matched core type.**

Therefore **coverage allows SKIP** for priority 1 and priority 2 entries **with respect to canonical core reconstruction and PHI1 evidence**, without treating the replay plan as mandating replay of those tiers anyway.

## Priority 1 and 2 classification

| Priority | Classification |
| --- | --- |
| Priority 1 (reconstruction) | **SKIP_ALREADY_COVERED** — `replay_required=NO` for RECONSTRUCTION |
| Priority 2 (phi1_phi2) | **SKIP_ALREADY_COVERED** — `replay_required=NO` for PHI1 |

## Reconstruction, PHI1, scaling

| Question | Answer |
| --- | --- |
| Is reconstruction skipped (for core coverage purposes)? | **Yes** — RECONSTRUCTION `replay_required=NO`. |
| Is PHI1 skipped (for core coverage purposes)? | **Yes** — PHI1 `replay_required=NO`. |
| Does scaling become “next” in terms of **coverage gap**? | **Yes** — SCALING is the only row with `replay_required=YES`. |

## First valid next step (replay plan + coverage)

- **Core coverage gap:** SCALING (`replay_required=YES`).
- **Replay plan:** `switching_full_scaling_collapse.m` appears with **`guard_status=EXCLUDE_MIXED_MODULE`** and **`canonical_run_to_use`** text indicating non-Switching inputs. Under Switching-only constraints, this row **does not** present a clear executable next step reconciled with that guard without further policy input (hence **HOLD_PENDING_RECONCILIATION** for that script in the reconciliation table).
- **Strict numeric priority on ALLOW rows after skipping 1 and 2:** The next **`ALLOW_SWITCHING_ONLY`** priority is **4** (`robustness_audit`). The first such script by `tier_order` in the file is **`Switching/analysis/run_parameter_robustness_switching_canonical.m`** (`tier_order=34`).

## Exact next script to run (if any)

Per reconciliation: **next executable ALLOW script in plan order after skipping priorities 1 and 2** is **`Switching/analysis/run_parameter_robustness_switching_canonical.m`**.  
Closing the **SCALING** coverage gap via **`switching_full_scaling_collapse.m`** is **not** established as the immediate next step from these two tables alone because of **`EXCLUDE_MIXED_MODULE`** on that plan row.

Machine-readable rows: `tables/switching_replay_reconciliation.csv`.
