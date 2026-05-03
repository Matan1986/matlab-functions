# Aging F7X5 — Partial definition contract (draft)

**Document type:** **Partial definition contract draft** — not a final **naming** contract.  
**Renaming:** **None** — this document does not rename variables, columns, files, or artifacts.  
**Physics:** **No claims** of physical validity, optimality, or mechanism — routing and definitions **as supported by code, governance docs, and F7X2–F7X4 audit tables** only.

**Execution:** No MATLAB/Python/replay/tau/ratio runs. Hygiene: [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

**Immutability:** Prior artifacts **F7W / F7X / F7X2 / F7X3 / F7X4** are **not modified** by this task; this file and `tables/aging/aging_F7X5_*.csv` are **additive** only.

---

## 1. Scope

This draft **locks** only definition-level rules that are **explicitly supported** by:

- `docs/aging_observable_branch_router.md`, `docs/aging_measurement_definition_freeze.md`
- Surveys **F7X2** (routes/methods), **F7X3** (object inventory), **F7X4** (gap resolution)
- Code anchors: `Aging/pipeline/stage4_analyzeAFM_FM.m`, `Aging/models/analyzeAFM_FM_components.m`, `Aging/models/analyzeAFM_FM_derivative.m`, `Aging/models/analyzeAFM_FM_extrema_smoothed.m`, `Aging/pipeline/stage5_fitFMGaussian.m`, `Aging/pipeline/stage6_extractMetrics.m`, `Aging/analysis/aging_timescale_extraction.m`, `Aging/analysis/aging_fm_timescale_analysis.m`, `Aging/analysis/aging_clock_ratio_analysis.m`

**In scope:** object-definition rules, branch/stage qualifiers, tau **metadata gate**, ratio/downstream boundaries, forbidden standalone vocabulary, bridge-only limits, **partial** inclusion of stage5 fit internals.

**Out of scope:** final display names, alias tables, code refactors, Switching/Relaxation/MT, editing router docs or prior F7X tables.

---

## 2. Non-goals

- Not a **final naming contract** and not **final name selection**.
- No **substitution** of Track A for Track B or tau for decomposition (per F7W guardrails narrative).
- No **closure** of `fitFMstep_plus_GaussianDip` internal algebra without a future audit (remains **PARTIAL** at interface level).

---

## 3. Contract status: partial draft

Status: **`PARTIAL_CONTRACT_ONLY = YES`** (`tables/aging/aging_F7X5_status.csv`).  
Normative rows in `tables/aging/aging_F7X5_definition_contract_rules.csv` use **`LOCKED`**, **`LOCKED_WITH_QUALIFIER`**, **`PARTIAL`**, **`EXCLUDED`**, or **`FORBIDDEN`** — never over-claim beyond F7X4 evidence.

---

## 4. Source / audit basis

| Layer | Primary artifacts |
|-------|---------------------|
| Routes / methods | `tables/aging/aging_F7X2_*.csv`, `reports/aging/aging_F7X2_route_name_method_survey.md` |
| Object definitions | `tables/aging/aging_F7X3_*.csv`, `reports/aging/aging_F7X3_object_definition_survey.md` |
| Gap resolution | `tables/aging/aging_F7X4_*.csv`, `reports/aging/aging_F7X4_definition_gap_resolution.md` |
| Bridge | F7W charter, F7X bridge tables/reports (read-only) |
| Governance | `docs/aging_observable_branch_router.md`, `docs/aging_measurement_definition_freeze.md` |

---

## 5. Contract vocabulary (normative tokens)

Use **these tokens** (or supersets explicitly mapped) in machine-facing annex rows — **not** bare English “background”, “baseline”, “residual”, or “fit” without qualification:

| Token | Meaning (contract) |
|-------|---------------------|
| `SMOOTH_COMPONENT_STAGE4_DIRECT` | `DeltaM_smooth` from `sgolayfilt` on `dM_work` derived from pipeline `DeltaM` (`dM`) |
| `SHARP_RESIDUAL_DELTA_M_OBSERVABLE` | `DeltaM_sharp = dM - DeltaM_smooth` |
| `SIGNED_DIP_RESIDUAL` | `dip_signed = DeltaM_signed - DeltaM_smooth` |
| `PLATEAU_REFERENCE_FM` | Plateau-based `FM_step_raw` / `FM_signed` path (direct family variants) |
| `DERIVATIVE_MEDIAN_BASELINE_ON_SMOOTH` | Derivative route: medians of `DeltaM_smooth` outside dip for `FM_step_raw` |
| `STAGE5_FIT_PARAMETRIC` | Outputs of `stage5_fitFMGaussian` / callee (interface-level list only where PARTIAL) |
| `EXTREMA_MOVMEAN_SMOOTH` | `movmean(DeltaM,11)` then extrema scalars |
| `TRACK_A_STAGE6_SUMMARY` | `AFM_like`, `FM_like` lane |
| `TRACK_B_CONSOLIDATION` | Five-column `aging_observable_dataset` reader contract |
| `TAU_OUTPUT` | Rows in `tau_vs_Tp.csv` / `tau_FM_vs_Tp.csv` |
| `RATIO_OUTPUT` | e.g. `R_age` from `aging_clock_ratio_analysis.m` |
| `BRIDGE_ROW` | F7X long/index semantics |

---

## 6. Object definition rules

1. **Contract-safe objects** are those with **`LOCKED`** or **`LOCKED_WITH_QUALIFIER`** in `aging_F7X5_contract_scope_matrix.csv` when all **required qualifiers** for the row are present on the artifact.
2. **Objects requiring qualifiers** include: any `DeltaM_*` / `dip_signed` row, all **tau** and **ratio** rows, all **bridge** rows, **Track A/B** references.
3. **PARTIAL** objects (e.g. stage5 internal kernel) must cite **`PARTIAL`** and must **not** be promoted to **`LOCKED`** without new evidence.

---

## 7. Branch / stage qualifier rules

- Every normative definition row SHALL include **`stage_or_route`** (see `aging_F7X5_required_metadata_schema.csv`).
- **`agingMetricMode`** values **`direct` | `model` | `fit`** SHALL be labeled **`stage4_direct_family`** in contract text — **never** “stage5 fit” by that flag alone (`R-FIT-001`).
- **Derivative** route SHALL carry token **`stage4_derivative`** and SHALL list derivative-only outputs per F7X4 appendix (`R-DER-001`).
- **Extrema** route SHALL carry **`stage4_extrema`** and SHALL not be aliased to `DeltaM_smooth` of the direct branch (`R-EXT-001`).

---

## 8. Background / baseline / residual rules

- **`background`**, **`baseline`**, and **`residual`** are **not standalone contract-safe terms** without **category + stage/route** (`R-BG-001`–`R-BG-003`).
- **Smooth** (`DeltaM_smooth`, stage4 direct) **must be distinguished** from **fit plateau / parametric background** (stage5) and from **extrema movmean** smooth (`R-BG-004`).

---

## 9. `dM` / `DeltaM_signed` / `DeltaM_smooth` / `DeltaM_sharp` / `dip_signed` rules

**Locked from code** (`analyzeAFM_FM_components.m`):

- `dM` = `pauseRuns.DeltaM(:)` — **pipeline analysis observable** (legacy-compatible comment in code).
- `DeltaM_signed` = field when present and consistent; else **fallback** to `dM` with recorded `DeltaM_signed_source`.
- **`DeltaM_sharp = dM - DeltaM_smooth`** — uses **`dM`**, not `DeltaM_signed`.
- **`dip_signed = DeltaM_signed - DeltaM_smooth`** — uses **`DeltaM_signed`**, same `DeltaM_smooth` vector.

**Contract obligations:**

- **Never** treat `DeltaM_sharp` and `dip_signed` as identical **unless** equality of `dM` and `DeltaM_signed` is documented (`R-DM-001`–`R-DM-003`).
- Exports SHOULD carry **`DeltaM_signed_source`** when both `DeltaM` and `DeltaM_signed` exist (recommended metadata; not a code change here).

---

## 10. FM sign / magnitude rules

- **`FM_signed`**: sign preserved per stage4 orchestrator assignment from `FM_step_raw` / fallback (`R-FM-001`).
- **`FM_abs`**: **`abs(FM_signed)`** when finite — **magnitude only**; **no sign reversal** claims (`R-FM-002`).
- **`FM_step_mag`**: **not** magnitude-only by name alone — contract usage **must** cite **route + measurement-freeze policy** (wide matrix signed semantics) (`R-FM-003`).

---

## 11. Direct route rules

- **`agingMetricMode` `direct` | `model` | `fit`** → **`analyzeAFM_FM_components`** — **stage4 direct family**, same entrypoint (`R-DIR-001`).
- Smoothing: **`sgolayfilt`** on interpolated `dM_work` with window derived from `smoothWindow_K` (code; not re-derived here).

---

## 12. Derivative route rules

- Orchestrator prefers **`DeltaM_signed`** over **`DeltaM`** for derivative input when available (`stage4_analyzeAFM_FM.m`).
- **`analyzeAFM_FM_derivative`** copies direct smooth/sharp/dip/AFM from nested call, then **redefines** `FM_step_raw`/`FM_step_mag` from **median `DeltaM_smooth` outside dip**; adds **`diagnostics.dMdT`** etc. (`R-DER-001`).

---

## 13. Extrema-smoothed route rules

- Input: **`run.DeltaM`**. Smooth: **`movmean(..., 11)`**. Outputs: **`FM_extrema_smoothed = max(M_s)`**, **`AFM_extrema_smoothed = min(M_s)`** (`R-EXT-001`). Not the same object as consolidation **`Dip_depth`**.

---

## 14. Stage5 / stage6 fit / summary rules

- **Stage5** persists fit fields (`FM_E`, `Dip_area_selected`, …) per `stage5_fitFMGaussian.m` — **interface list LOCKED**; **internal kernel `PARTIAL`** (`R-FIT-002`).
- **Stage6** `AFM_like` / `FM_like` are **fit-summary** vectors — **not** `Dip_depth` / `FM_abs` consolidation contract (`R-ST6-001`, freeze).

---

## 15. Bridge component rules

- **`C_DIP_DEPTH_B`**, **`C_FM_ABS_B`**, **`STREAM_*`** are **`BRIDGE_ROW`** entities — **bridge-only** for canonical physics substitution (`R-BRI-001`). Eligibility flags in F7X tables govern downstream automation — not overridden here.

---

## 16. Tau metadata gate

**Tau outputs** (files/columns) are **downstream**, not pauseRun decomposition fields.

**Minimum bundle** before any contract row references **`tau_effective_seconds`** or uses tau as authoritative time-scale without caveats:

- `tau_domain`, `tau_method` (or writer `tau_or_R_flag` / `writer_family_id` where present), **`tau_input_object`**, **`producer_script`**, **`grain`**, **`units`**, **`tau_consensus_methods`** (or explicit half_range_primary), **`lineage_status`** (`R-TAU-001`, `R-TAU-002`).

**`tau_effective_seconds`** is **not contract-safe** without this bundle — **legacy / summary column only** with disclosure (`R-TAU-002`).

---

## 17. Ratio / downstream rules

- **`R_age`** and related tables are **combinators** on **prior tau CSVs** — **not** raw observables (`R-RAT-001`). Pairing/lineage gates from F7T/F7Q narratives remain **out-of-band** enforcement — this draft only states the **definition boundary**.

---

## 18. Forbidden standalone terms

Listed in **`tables/aging/aging_F7X5_forbidden_or_qualified_terms.csv`**, including at minimum: **`background`**, **`baseline`**, **`residual`**, unqualified **`fit`**, bare **`Track A` / `Track B`**, bridge IDs without `bridge:` context, **`tau_effective_seconds`** without tau bundle, **`tau_vs_Tp` / `tau_FM_vs_Tp`** as decomposition aliases, **`R_age`** as a raw observable.

---

## 19. Objects / routes excluded from full LOCKED contract

- **Undocumented internals** of `fitFMstep_plus_GaussianDip` (**`EXCLUDED`** pending audit — `R-EXC-001`).
- Any object **not listed** in F7X3 inventory + F7X4 resolution without new evidence — default **`EXCLUDED`** until surveyed.

---

## 20. Required metadata fields (before final naming contract)

Machine-readable schema: **`tables/aging/aging_F7X5_required_metadata_schema.csv`**.  
Naming contract authors SHALL require the **`mandatory = YES`** fields for every named entity row; **`CONDITIONAL`** fields apply per `required_for` column.

---

## 21. Open blockers (before final naming contract)

See **`tables/aging/aging_F7X5_open_blockers_before_naming_contract.csv`** — includes: prose **background/baseline** cleanup vs machine rows; **fit callee** audit; **`tau_effective_seconds`** dual-algorithm disclosure; **bridge** lineage completeness; **Track label** insufficiency; cross-branch **compare** bridge materialization.

---

## 22. Recommended next safe step

**`RESOLVE_OPEN_BLOCKERS_THEN_DRAFT_FINAL_NAMING_CONTRACT_OR_EXPAND_DEFINITION_CONTRACT`** (see `aging_F7X5_status.csv` `F7X5_NEXT_SAFE_STEP`): close **B-003** metadata enforcement in writers/consumers, complete **B-004** bridge lineage or narrow eligibility, optionally run **fit callee** audit (**B-002**) before promoting any stage5 quantity to **`LOCKED`**.

---

## 23. Machine-readable annex

| File | Purpose |
|------|---------|
| `tables/aging/aging_F7X5_definition_contract_rules.csv` | Rule IDs |
| `tables/aging/aging_F7X5_contract_scope_matrix.csv` | Route/group inclusion |
| `tables/aging/aging_F7X5_required_metadata_schema.csv` | Metadata columns |
| `tables/aging/aging_F7X5_forbidden_or_qualified_terms.csv` | Term policy |
| `tables/aging/aging_F7X5_open_blockers_before_naming_contract.csv` | Blockers |
| `tables/aging/aging_F7X5_status.csv` | Verdict keys |

---

## 24. Explicit statements (required)

1. **This is not a final naming contract.**  
2. **This does not rename any object.**  
3. **This does not claim physical validity.**  
4. **`background`**, **`baseline`**, and **`residual`** are **not** standalone contract-safe terms without branch/stage/category qualifiers.  
5. **`tau_effective_seconds`** is **not** contract-safe **without** tau-domain metadata and companion columns (`tau_consensus_methods` / half_range disclosure).  
6. **`agingMetricMode='fit'`** must **not** be confused with **true stage5 fit-derived objects** — it routes **stage4 direct family** code.  
7. **Bridge components** are **bridge/export** objects, not canonical physics observables.  
8. **Tau outputs** and **ratio outputs** are **downstream** objects, **not** decomposition components.

---

## Cross-module

**No** edits to Switching, Relaxation, or MT paths.
