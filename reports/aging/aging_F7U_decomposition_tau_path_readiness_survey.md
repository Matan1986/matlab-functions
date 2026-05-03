# Aging F7U — Decomposition and tau-path readiness survey (pre clock-ratio execution)

## Charter

Read-only **survey** of **decomposition families**, **tau extraction families**, and **candidate ratio paths** before any `R_age` / clock-ratio **execution**. This document does **not** run ratios, extract tau, rerun decomposition, rank branches, select canonical physics, or synthesize across Switching / Relaxation / MT.

## Anchors

- **F7T** scoped ratio charter: `c702cea` — Define Aging F7T scoped R age charter  
- **Governance**: F7J observable-definition map (`reports/aging/aging_F7J_observable_definition_scope_map.md`), `docs/AGING_DECOMPOSITION_MAP.md`, `docs/aging_measurement_definition_freeze.md`, `docs/aging_observable_branch_router.md`  
- **FM tau hardening**: F7R2 (`074a9c7`)

## Executive answers

### 1. Decomposition-path inventory

Multiple **distinct** producer paths separate AFM/Dip vs FM surfaces (see `tables/aging/aging_F7U_decomposition_path_inventory.csv`). **`FM_abs`** and **`Dip_depth`** in the five-column consolidation CSV are **exported artifacts** from upstream stage4/stage5 semantics—not decomposition “methods” by themselves. Their meaning is **contract-bound** (Track B consolidation vs Track A summaries).

### 2. Fit vs non-fit decomposition comparison readiness

At least **two** families exist:

- **Fit-heavy Track A**: `stage5_fitFMGaussian` → `stage6_extractMetrics` → `AFM_like` / `FM_like` summaries.  
- **Direct / non-fit stage4**: `stage4_analyzeAFM_FM` → `analyzeAFM_FM_components` (and derivative/extrema modes).

**Readiness for naive side-by-side “same observable” comparison:** **PARTIAL**. `docs/aging_measurement_definition_freeze.md` and F7J explicitly **forbid** substituting Track A summaries for consolidation **`Dip_depth`/`FM_abs`** without a controlled mapping. **Tp/tw grids** can align (e.g. six or eight Tp stops × shared tw set for consolidated snapshots), but **semantic identity** across families is **not** automatically guaranteed.

### 3. Tau-path inventory

Tau-like quantities are produced mainly by **curve-fitting families** on **`Dip_depth` vs `tw`** (`aging_timescale_extraction.m`) and **`FM_abs` vs `tw`** (`aging_fm_timescale_analysis.m`), plus **rescaling optimizer** (`aging_time_rescaling_collapse.m`), **clock-ratio combinators** (`aging_clock_ratio_analysis.m`, `aging_clock_ratio_temperature_scaling.m`), and **diagnostic** harnesses (tri-clock, log-slope tests). See `tables/aging/aging_F7U_tau_method_inventory.csv` (extends F7J tau inventory with F7U eligibility columns).

### 4. Decomposition ↔ tau compatibility

See `tables/aging/aging_F7U_decomposition_tau_compatibility_matrix.csv`. Consolidated **`FM_abs`/`Dip_depth`** feed standard tau extractors; Track A **`FM_like`/`AFM_like`** do **not** automatically plug into the same `aging_fm_timescale_analysis` input contract without an explicit column/registry bridge (**new implementation** or **narrow diagnostic**).

### 5. Candidate ratio paths (declarative only)

See `tables/aging/aging_F7U_candidate_ratio_path_matrix.csv`. Includes a **baseline F7T-style** path (hardened `tau_FM_vs_Tp.csv` + explicit `tau_vs_Tp.csv`) and **notional** multipath variants (fit-direct pairing classes) marked **not ready** until decomposition alignment is chartered.

### 6. Module readiness (A–D)

| Item | Verdict | Evidence |
|------|---------|----------|
| **A. Single scoped F7T-style ratio** | **READY (technical)** | Hardened FM tau + explicit dip tau + F7T gates; `row_ratio_use_allowed` remains NO — use CEL + disclosure per F7T. |
| **B. Multi-path decomposition/tau robustness** | **NOT READY** | Multiple decomposition and tau families exist, but **cross-family comparability** and **paired artifacts** for each path are incomplete. |
| **C. Fit vs direct decomposition comparison** | **PARTIAL** | Both families exist; **freeze** blocks naive substitution. Needs alignment charter or diagnostic harness. |
| **D. Direct tau extraction (non-curvefit)** | **PARTIAL** | Standard tau outputs are **curve-fit-heavy**; “direct” half-life style paths are limited or legacy-adjacent in inventory. |

### 7. Baseline ratio vs robustness goal

| Flag | Value |
|------|--------|
| **BASELINE_RATIO_TECHNICALLY_READY** | **YES** (inputs + F7T contract + F7R2 metadata discipline). |
| **BASELINE_RATIO_SCIENTIFICALLY_INSUFFICIENT_FOR_ROBUSTNESS_GOAL** | **YES** — the stated scientific goal requires **multiple classified decomposition × tau paths**; baseline single-path ratio does **not** demonstrate robustness across methods. |

### 8. Recommended next safe step

**Commit F7U survey artifacts only**, then **author a multipath clock-ratio robustness charter** (or **decomposition-alignment diagnostic charter**) **before** treating baseline ratio execution as scientifically sufficient for the robustness goal. Baseline F7T execution remains an optional **narrow** lane if governance accepts “contract bookkeeping only.”

Machine-readable tables: `tables/aging/aging_F7U_*.csv`; verdicts: `tables/aging/aging_F7U_status.csv`.
