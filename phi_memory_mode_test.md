# Phi memory / internal-state mode test (Agent 16C)

## Scope
Test whether `Phi` encodes hidden internal-state (memory-like) dynamics not fully encoded in `P_T`, using existing run artifacts.

Required inputs reviewed:
- `docs/repo_state.json`
- `results/cross_experiment/runs/run_2026_03_25_181142_barrier_to_dynamics_mechanism_agent13/reports/barrier_to_dynamics_mechanism.md` (resolved path for `barrier_to_dynamics_mechanism.md`)

## Signature checks

### 1) PT independence
**Result: NOT SUPPORTED**

Evidence:
- `run_2026_03_25_034055_phi_pt_independence_test` reports `VERDICT: NOT INDEPENDENT`.
- Reported diagnostics are strongly non-independent:
  - projection ratio `||proj||/||Phi|| = 1.0000`
  - reconstruction error ratio `RMSE/RMS(Phi) = 0.0056`
  - max `|corr|` with PT-derived quantities `= 0.9201`

Interpretation:
- Current evidence indicates `Phi` is highly reconstructible from PT-mode spans and PT-derived features, so strict PT independence is not met.

### 2) Observable separation (strong role in R, weak in A)
**Result: SUPPORTED**

Evidence:
- Barrier-to-dynamics report (`agent13`) gives:
  - `BARRIER_EXPLAINS_A: YES`
  - `BARRIER_EXPLAINS_R: NO`
- Closure report (`run_2026_03_25_040041_barrier_relaxation_mechanism_closure`) shows residual coupling split:
  - `A residual vs kappa`: Spearman `-0.118`, Pearson `-0.124` (weak)
  - `R residual vs kappa`: Spearman `0.536`, Pearson `0.599` (moderate/strong)

Interpretation:
- PT/barrier terms explain `A` well without requiring residual-sector amplitude.
- `R` retains a substantial residual component aligned with `kappa`, consistent with memory-like/internal-state contribution to `R`.

### 3) kappa coupling consistency
**Result: SUPPORTED**

Evidence:
- `run_2026_03_25_180406_kappa_from_pt_agent14`: `KAPPA_FROM_PT: YES`.
- Temperature-regime audit (`run_2026_03_25_041503_temperature_regime_analysis`) shows adding `kappa` strongly improves `R` LOOCV in stressed window:
  - `T<=24`: Pearson for `R` PT2-only `0.0976` -> PT2+`kappa` `0.9736`
  - `A` does not gain from adding `kappa` (small degradation in LOOCV for listed windows)

Interpretation:
- `kappa` acts as the activation channel for the residual mode in `R`, while `A` remains mostly PT-controlled.

### 4) Regime behavior (Phi shape invariant, kappa varying)
**Result: SUPPORTED**

Evidence:
- Temperature-regime report gives `Phi` shape correlations across trims:
  - baseline vs Tmax25K: `0.8727`
  - baseline vs Tmax28K: `0.8782`
  - Tmax25K vs Tmax28K: `0.9999`
- Same report shows `kappa(T)` regime structure (including a pronounced 22 K minimum) and large window sensitivity in `R` prediction without `kappa`.

Interpretation:
- `Phi(x)` is relatively stable as a shape basis; regime dependence is expressed mainly through amplitude/activation (`kappa(T)`).

## Consolidated assessment

- PT independence: **FAIL**
- R-vs-A separation: **PASS**
- kappa activation coupling: **PASS**
- regime pattern (shape-stable Phi, varying kappa): **PASS**

## FINAL VERDICT

**MEMORY_MODE: PARTIAL**

### Interpretation
`Phi` is consistent with an internal-state-like residual sector in how it enters dynamics (dominantly through `kappa` and predominantly affecting `R` rather than `A`, with regime-dependent activation).  
However, because strict PT independence is not satisfied in current diagnostics, the strongest claim ("hidden state fully outside PT encoding") is not yet supported. The present evidence supports a **partially distinct internal-state mode** rather than a fully PT-orthogonal one.
