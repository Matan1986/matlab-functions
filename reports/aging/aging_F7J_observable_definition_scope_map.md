# F7J — Aging observable-definition scope map and multi-branch architecture audit

Read-only governance artifact. No MATLAB execution, code edits, dataset rebuilds, tau/R writer runs, staging, commits, or pushes were performed for this deliverable. Repository execution hygiene remains per [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

## Purpose (non-collapsing)

This audit maps **coexisting observable-definition branches** and downstream tau/time-scale machinery **without selecting a single canonical physics truth**. Multiple branches remain valid for different contracts (Track A summaries vs Track B stage4 scalars vs consolidation reader CSV vs diagnostic audits).

## HEAD anchor

Audit workspace **`HEAD`:** `ddbe212` (matches **Add Aging F7I dataset lineage audit** at authoring time). Governance anchors referenced elsewhere: `84431dc` (F7H roadmap), `ced4798` (F7G tau/R metadata columns).

## Deliverables index

| Artifact | Role |
|----------|------|
| `tables/aging/aging_F7J_observable_definition_branch_inventory.csv` | Observable branches |
| `tables/aging/aging_F7J_tau_method_inventory.csv` | Tau / time-scale / ratio writers |
| `tables/aging/aging_F7J_FM_short_tw_sign_policy_audit.csv` | FM sign / short-tw behavior matrix |
| `tables/aging/aging_F7J_dataset_branch_coverage_comparison.csv` | 22-row vs 30-row metadata-only comparison |
| `tables/aging/aging_F7J_allowed_claims_map.csv` | Allowed claims by branch |
| `tables/aging/aging_F7J_config_taxonomy_proposal.csv` | Future config keys (names only) |
| `tables/aging/aging_F7J_duplication_risk_inventory.csv` | Duplication risks |
| `tables/aging/aging_F7J_status.csv` | Verdict keys |

## Architecture snapshot (multi-branch)

```text
Raw DeltaM(T) pipelines
   |
   +-- cfg.agingMetricMode router (stage4_analyzeAFM_FM)
   |      direct -> analyzeAFM_FM_components (dip_signed sharp/smooth FM_step_raw)
   |      derivative -> analyzeAFM_FM_derivative
   |      extrema_smoothed -> analyzeAFM_FM_extrema_smoothed
   |
   +-- stage5_fitFMGaussian (Gaussian dip / tanh step) -> Dip_area_* FM_E (Track A feeds)
   |
   +-- stage6_extractMetrics -> AFM_like FM_like (fit-summary Track A vectors)
   |
   +-- aging_structured_results_export -> observable_matrix (+ observables.csv narrowed)
   |
   +-- run_aging_observable_dataset_consolidation -> five-column CSV (+ sidecar)
   |
   +-- tau producers (read consolidated magnitudes or prior tau CSVs)
          aging_timescale_extraction (Dip_depth curves)
          aging_fm_timescale_analysis (FM_abs curves)
          aging_time_rescaling_collapse (rescaling optimizer)
          aging_clock_ratio_analysis / aging_clock_ratio_temperature_scaling (R_age from taus)
          aging_fm_using_dip_clock (collapse metrics under dip tau clock)
```

**Separation rule (frozen in docs):** Track A `AFM_like`/`FM_like` **must not** be substituted for Track B consolidation `Dip_depth`/`FM_abs` (`docs/aging_measurement_definition_freeze.md`).

## Fit vs direct (high level)

| Class | Examples |
|-------|----------|
| **Fit-heavy Track A** | `Dip_area_selected`, `FM_E`, Gaussian dip (`stage5`), tanh RMS window |
| **Direct stage4 scalars** | Residual dip metrics (`AFM_amp`→`Dip_depth` path), plateau `FM_signed`→`FM_abs` |
| **Derivative / extrema branches** | `analyzeAFM_FM_derivative`, `analyzeAFM_FM_extrema_smoothed` |
| **Tau curve fits on exported scalars** | Log-time logistic / stretched / half-range families (`aging_timescale_extraction`, `aging_fm_timescale_analysis`) |
| **Thin consolidation** | Identity rename — **non-fit** |

## Dip / background decomposition

- **Continuous diagnostic:** `DeltaM_smooth` + `DeltaM_sharp` (`dip_signed` conceptual layer) inside direct decomposition (`analyzeAFM_FM_components.m`).
- **Stage4 orchestrator fallbacks:** `Dip_depth` may bind to `AFM_amp` with `Dip_depth_source` marking (`stage4_analyzeAFM_FM.m`).
- **Baseline diagnostics:** `baseline_slope`, `baseline_status` fields carried on pauseRuns for window validity narratives.

## FM signed / absolute / short waiting time

**Preservation vs collapse:**

| Surface | Sign |
|---------|------|
| `pauseRuns.FM_signed` after stage4 | **Preserved** (physics-oriented) |
| `observable_matrix.csv` `FM_step_mag` | **Signed** plateau raw per measurement freeze (misleading column name) |
| `aging_observable_dataset.csv` `FM_abs` | **`abs(...)` magnitude — sign reversal not representable** |
| Tau inputs `aging_fm_timescale_analysis` | Reads **`FM_abs` only** — reversal invisible at tau-ingest layer |

**Short \(t_w\) (e.g. 3 s):** Still appears in both 22-row and 30-row consolidated grids **when present upstream**; **sign reversal** must be traced via **`FM_step_mag` / `FM_signed` paths or audits** (e.g. `run_aging_F3b_FM_signed_short_tw_rescue.m`), **not** via the five-column magnitude contract alone.

## 22-row vs 30-row datasets (metadata only)

| Feature | `tables/aging/aging_observable_dataset.csv` (22 rows) | `results_old/...` snapshot (30 rows) |
|---------|---------------------|----------------------|
| **Tp grid** | 14–34 K (six stops) | Adds **6 K and 10 K** (eight stops total) |
| **tw grid** | {3, 36, 360, 3600} s | Same tw grid |
| **FM columns (five-column)** | `FM_abs` magnitude only | Same schema; historical rows may include **NaN `FM_abs`** at low-T per diagnostics elsewhere |
| **Lineage** | `source_run` composite present | `source_run` composite present |
| **Interpretation** | Different consolidation/export epoch / producer scope — **no physics ranking performed here** |

## Duplication risks (summary)

See `aging_F7J_duplication_risk_inventory.csv` — prominent items: parallel tau curve engines (`aging_timescale_extraction` vs `aging_fm_timescale_analysis`), repeated historical default run-id strings across analyses, Track A vs B naming collisions.

## Allowed claims (summary)

`aging_F7J_allowed_claims_map.csv` ties branches to **metadata verification**, **replay parity**, **pipeline validation**, **exploration**, and **blocked** layers. Default stance: **pending lineage** flags from F7G/F7I remain binding until dataset pointer + dip-branch metadata stabilize.

## Documentation gaps before any canonical choice

1. **Single-page routing diagram** from cfg modes → pauseRuns fields → export columns → reader contracts (extends freeze tables).
2. **Explicit “sign visibility matrix”** linking five-column CSV vs matrix vs pauseRuns (this audit seeds `aging_F7J_FM_short_tw_sign_policy_audit.csv`).
3. **Named presets** for low-T / short-tw validity (`excludeLowT_*`, `FM_plateau_valid`) mapped to observable outputs (policy strings only).
4. **Orchestrated registry** for default `results/.../run_*` identifiers vs `tables/aging` consolidation outputs (pointer file exists; UX lacks).

## Next safe implementation step (minimal)

**Documentation-only:** publish a short **`docs/aging_observable_branch_router.md`** (new file in a future commit) listing:

- cfg mode → producer fields → export columns → allowed claims row (copy from this audit tables verbatim).

**Avoid** adding parallel extraction code until a gap is proven **after** router doc lands — prefer consolidating narrative + linking existing freeze CSV rows.

## Verdict block

See `tables/aging/aging_F7J_status.csv` for machine-readable YES/NO gates (`F7J_*`, `NO_*` hygiene).

---

**Principle reaffirmed:** clarity and controlled comparability — **no winning branch selected.**
