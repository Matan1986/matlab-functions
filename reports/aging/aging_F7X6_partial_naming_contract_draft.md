# Aging F7X6 -- Partial naming contract (draft only)

**Archive anchor (read-only):** `36d817e` -- `Archive Aging F7X route and definition contract audits`  
**Execution:** No MATLAB, Python, replay, tau extraction, or ratio computation. Hygiene: [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Edits:** This task adds **only** F7X6 artifacts. **No** edits to F7W, F7X, F7X2--F7X5, router docs, or code.

---

## 1. Scope

This document is a **partial naming and display contract** for Aging routes and objects that F7X5 already marks as **definition-contract-safe** or **safe with explicit qualifiers** (see `tables/aging/aging_F7X5_contract_scope_matrix.csv` and `tables/aging/aging_F7X5_definition_contract_rules.csv`).

**In scope:**

- Display **structure** (what must appear next to a human-facing label).
- **Required metadata** fields that must accompany any display name (prefer metadata over infinitely long names).
- **Candidate** display patterns and **forbidden** patterns for **resolved or explicitly qualified** groups only.
- **Bridge-only**, **downstream-only**, **display-only**, and **diagnostic** naming lanes where F7X5 already locked boundaries.

**Out of scope:**

- Final global display names, alias tables, repo renames, column renames, variable refactors.
- Declaring all Aging routes resolved or physically valid.
- Switching, Relaxation, MT, or router document edits.

---

## 2. Non-goals

- **Not** a final naming contract and **not** final name selection for unresolved objects.
- **Not** a license to shorten labels by hiding branch, stage, decomposition role, or tau metadata requirements.
- **Not** a substitute for the F7X5 definition contract; naming here **inherits** F7X5 **LOCKED**, **LOCKED_WITH_QUALIFIER**, and **PARTIAL** rows -- nothing is promoted beyond them.

---

## 3. Contract status: partial naming draft

**`PARTIAL_NAMING_CONTRACT_DRAFT = YES`**  
Machine verdicts: `tables/aging/aging_F7X6_status.csv`.

This layer sits **after** F7X2 (route/method survey), F7X3 (object definitions), F7X4 (high-risk gap resolution), and F7X5 (partial definition contract with branch qualifiers and tau metadata gate). It does **not** close open F7X5 blockers.

---

## 4. Basis: F7X2 through F7X5

| Layer | Primary read-only inputs for this draft |
|-------|----------------------------------------|
| Routes / methods | `reports/aging/aging_F7X2_route_name_method_survey.md`, `tables/aging/aging_F7X2_*.csv` |
| Objects | `reports/aging/aging_F7X3_object_definition_survey.md`, `tables/aging/aging_F7X3_*.csv` |
| Gaps | `reports/aging/aging_F7X4_definition_gap_resolution.md`, `tables/aging/aging_F7X4_*.csv` |
| Definition contract | `reports/aging/aging_F7X5_definition_contract_draft.md`, `tables/aging/aging_F7X5_*.csv` |

Context only (not edited): `docs/aging_observable_branch_router.md`.

---

## 5. End-user clarity objective

A future user, reading a **display label plus its required metadata panel**, should be able to answer:

1. **What object** is shown (entity kind: decomposition field, tau output, ratio, bridge row, dataset row, diagnostic).
2. **What signal or source field** it came from (pauseRuns column, consolidation column, script output file).
3. **Which branch or stage** produced it (stage4 direct family, derivative, extrema, stage5 interface, stage6 summary, tau script, ratio script, bridge export).
4. Whether it is a **decomposition component**, **processed observable**, **tau input**, **tau output**, **ratio output**, **bridge object**, or **diagnostic-only** artifact.
5. **Sign or magnitude convention** that applies (signed vs ABS_ONLY vs route-specific signed semantics for legacy names such as `FM_step_mag`).
6. Whether **tau metadata** is **required** before showing any tau-related quantity (including `tau_effective_seconds`).
7. Whether the row is **safe** for physical interpretation, **bridge** use, **diagnostic** use, or **downstream-only** use -- per F7X5 **allowed_use** / **excluded_use** columns, not per new physics claims.

**Principle:** User clarity beats short names. Uncertainty belongs in **metadata and status fields**, not in a pretty but misleading label.

---

## 6. Required naming / display structure

Every user-visible Aging quantity SHOULD be presented as:

1. **Optional short headline label** (candidate only; not final) -- may be opaque if metadata is complete.
2. **Required metadata block** (machine or UI panel) satisfying at minimum the F7X5 **mandatory** fields in `tables/aging/aging_F7X5_required_metadata_schema.csv` for that entity kind, plus F7X6 **route_id** schema fields in `tables/aging/aging_F7X6_route_id_schema.csv`.
3. **Explicit `allowed_use`** token (for example `decomposition_component`, `tau_input_candidate`, `bridge_only`, `downstream_ratio`) so automation and humans share one vocabulary.

**Rule:** If a field cannot be shown with its mandatory metadata, **do not show it** as a standalone primary label -- use **DISPLAY_ONLY** or **EXCLUDED** policy per tables.

---

## 7. Required metadata next to any display name

Minimum bundles (summarized from F7X5; normative detail remains in F7X5 CSVs):

- **All non-tau decomposition rows:** `entity_kind`, `object_name`, `stage_or_route`, `decomposition_method` or equivalent, `sign_policy` when FM-related, `contract_status`, `lineage_status`, `source_artifact`, `producer_script`.
- **Tau outputs:** full **tau metadata bundle** (`tau_domain`, `tau_method`, `tau_input_object`, `producer_script`, `grain`, `units`, consensus or half-range disclosure, `lineage_status`) per R-TAU-001 and R-TAU-002 in F7X5 rules.
- **Ratio outputs:** `ratio_inputs`, `downstream_status`, pairing lineage per R-RAT-001.
- **Bridge rows:** `bridge` qualifier, component id, branch family, sign policy where applicable per R-BRI-001.
- **Track A / B references:** never alone -- pair with **object list** and **stage** tokens per R-TRK-001.

---

## 8. Route / object group naming decisions

Each group below is assigned **only** one of: **NAMING_ALLOWED**, **NAMING_ALLOWED_WITH_QUALIFIER**, **DISPLAY_ONLY**, **BRIDGE_ONLY**, **DOWNSTREAM_ONLY**, **DIAGNOSTIC_ONLY**, **EXCLUDED_FROM_NAMING** (for final-style primary labels; diagnostics may still carry technical names with banners).

| Group | Decision | Rationale (F7X5) |
|-------|----------|------------------|
| Stage4 direct core objects | **NAMING_ALLOWED_WITH_QUALIFIER** | LOCKED_WITH_QUALIFIER; dM vs signed dip separation |
| Stage4 derivative objects | **NAMING_ALLOWED_WITH_QUALIFIER** | LOCKED_WITH_QUALIFIER; FM redefinition vs direct |
| Stage4 extrema-smoothed objects | **NAMING_ALLOWED_WITH_QUALIFIER** | LOCKED_WITH_QUALIFIER; not sgolay smooth |
| Stage5 fit objects (interface list) | **NAMING_ALLOWED_WITH_QUALIFIER** / **PARTIAL** lane | PARTIAL contract on callee; interface fields cite stage5 |
| Stage6 summary objects (`AFM_like`, `FM_like`) | **NAMING_ALLOWED_WITH_QUALIFIER** | Fit-summary; not consolidation Dip_depth |
| Five-column dataset objects | **NAMING_ALLOWED** with strict reader contract | LOCKED reader contract; magnitude-only FM |
| F7X bridge components | **BRIDGE_ONLY** | Not canonical physics observables |
| Tau dip outputs | **DOWNSTREAM_ONLY** with metadata | Tau CSV; not pauseRun decomposition |
| Tau FM outputs | **DOWNSTREAM_ONLY** with metadata | Same |
| `tau_effective_seconds` | **DISPLAY_ONLY** or **DOWNSTREAM_ONLY** with full bundle | Never primary without tau bundle |
| Ratio outputs (`R_age`, etc.) | **DOWNSTREAM_ONLY** | Combinator on prior tau tables |
| Track A | **DIAGNOSTIC_ONLY** / governance label -- **not** a semantic name | Pair with stage6 objects |
| Track B | **DIAGNOSTIC_ONLY** / governance label -- **not** a semantic name | Pair with five-column semantics |
| Fit callee internals (undocumented kernel) | **EXCLUDED_FROM_NAMING** for LOCKED promotion | R-EXC-001 |

---

## 9. Safe naming patterns

- **Pattern A (decomposition):** `[STAGE4_DIRECT|STAGE4_DERIVATIVE|STAGE4_EXTREMA]:<object_name> | sign_policy=<...> | producer=<script>`  
- **Pattern B (stage5 interface):** `STAGE5_FIT_INTERFACE:<field> | PARTIAL_contract=yes | producer=stage5_fitFMGaussian.m`  
- **Pattern C (stage6 summary):** `STAGE6_TRACK_A_SUMMARY:<AFM_like|FM_like> | upstream=Dip_area_selected|FM_E`  
- **Pattern D (consolidation):** `TRACK_B_FIVE_COLUMN:<column> | contract=aging_observable_dataset | FM_abs=ABS_ONLY`  
- **Pattern E (tau):** `TAU_OUTPUT:<file> | tau_domain=... | tau_method=... | tau_input_object=...`  
- **Pattern F (ratio):** `DOWNSTREAM_RATIO:R_age | ratio_inputs=...`  
- **Pattern G (bridge):** `BRIDGE_EXPORT:<component_id> | branch_family=...`  

These are **patterns**, not final strings. See `tables/aging/aging_F7X6_route_display_name_candidates.csv` for **CANDIDATE_*** rows only.

---

## 10. Forbidden naming patterns

- Standalone **background**, **baseline**, **residual** without category + stage/route tokens (F7X5 R-BG-001--003).
- **`agingMetricMode=fit`** interpreted as "stage5 Gaussian fit object" without disambiguation (R-DIR-001, R-FIT-001).
- **`Track A`** or **`Track B`** as the **sole** semantic identifier for a numeric series (R-TRK-001).
- **`tau_effective_seconds`** as a lone column title or axis label without **tau_domain**, **tau_method**, and consensus disclosure (R-TAU-002).
- **`R_age`** or clock-ratio outputs labeled as if measured directly from `DeltaM` (R-RAT-001).
- Bridge ids (**`C_DIP_DEPTH_B`**, **`C_FM_ABS_B`**, **`STREAM_*`**) without **bridge/export** context (F7X5 forbidden terms table).
- Equating **`DeltaM_sharp`** and **`dip_signed`** without documented equality of `dM` and `DeltaM_signed` (R-DM-001--003).
- Claiming **magnitude-only** semantics for **`FM_step_mag`** from the substring `mag` alone (R-FM-003).

---

## 11. Bridge-only naming rules

- Any F7X bridge component MUST carry **`BRIDGE_EXPORT`** or equivalent explicit token in the metadata block and SHOULD use a display banner such as **Bridge export (not a canonical observable)**.
- Bridge rows MUST include **branch_family**, **component_stream_id** (when applicable), and **sign_policy** for FM-abs bridge per F7X5.
- **Forbidden:** implying cross-module physics substitution or "canonical dip" status from a bridge id alone.

---

## 12. Tau-output naming rules

- Tau dip and tau FM CSV rows are **DOWNSTREAM_ONLY**; labels MUST NOT imply they are pauseRun decomposition columns.
- **Minimum metadata** before display: `tau_domain`, `tau_method`, `tau_input_object`, `producer_script`, `grain`, `units`, `lineage_status`, plus consensus or half-range policy per F7X5.
- **`tau_effective_seconds`:** treat as **legacy**; **never** display without the full **tau_effective** disclosure bundle (dual-builder caveat per F7X4 / B-003).

---

## 13. Ratio / downstream naming rules

- Ratio outputs (for example **`R_age`**) MUST carry **`DOWNSTREAM_RATIO`** or **`COMBINATOR_NOT_DECOMP`** semantics in metadata (`downstream_status` per F7X5 schema).
- **Forbidden:** presenting a ratio as a raw observable or as interchangeable with tau seconds without explicit pairing manifest.

---

## 14. Track A / B labeling rules

- **`Track A`** and **`Track B`** are **governance route labels**, not semantic object names. **Do not** use them as global identifiers for columns in new UIs or APIs.
- **Required:** pair Track label with **explicit object names** (`AFM_like`, `FM_like`, `Dip_depth`, `FM_abs`, etc.), **stage**, and **producer_script**.
- **End-user message:** Track labels summarize **where to look in the router**, not **what the number means** alone.

---

## 15. Excluded / unresolved groups

- **Undocumented** internals of `fitFMstep_plus_GaussianDip` -- **EXCLUDED_FROM_NAMING** for LOCKED-style promotion (R-EXC-001); interface-level fields remain **PARTIAL**.
- Any object **not** present in F7X3 inventory + F7X4 resolution -- default **EXCLUDED** until surveyed.
- **Cross-branch compare** materializations without explicit bridge rows -- keep **DIAGNOSTIC_ONLY** or **EXCLUDED** for primary naming until F7W pairing policy completes (F7X5 B-006).

Detail rows: `tables/aging/aging_F7X6_excluded_or_qualified_routes.csv`.

---

## 16. Open blockers before final naming contract

Inherited from `tables/aging/aging_F7X5_open_blockers_before_naming_contract.csv` (not reopened here):

- **B-001** -- colloquial background/baseline/residual in human prose vs machine rows.  
- **B-002** -- fit callee audit.  
- **B-003** -- `tau_effective_seconds` dual-algorithm disclosure in all writers.  
- **B-004** -- bridge lineage completeness.  
- **B-005** -- Track label insufficiency (this draft encodes pairing rules; does not remove the blocker for **final** naming).  
- **B-006** -- cross-branch compare bridge coverage.

Until these are resolved or explicitly accepted as permanent **PARTIAL**, a **final** naming contract must not be asserted.

---

## 17. Recommended next safe step

**Close or narrow F7X5 blockers**, then either:

1. Draft a **final** naming contract that references F7X5 + F7X6 annexes, or  
2. Expand the **definition** contract if new objects appear.

Concrete near-term actions (no code in this task): enforce **B-003** in tau writers at documentation/spec level; complete **B-004** lineage matrix for bridge rows; schedule optional **B-002** callee read or keep stage5 as **PARTIAL** permanently in annex.

---

## 18. Machine-readable annex (F7X6)

| File | Purpose |
|------|---------|
| `tables/aging/aging_F7X6_partial_naming_rules.csv` | Partial naming rule rows |
| `tables/aging/aging_F7X6_route_display_name_candidates.csv` | Candidate labels only |
| `tables/aging/aging_F7X6_route_id_schema.csv` | route_id / metadata field definitions |
| `tables/aging/aging_F7X6_excluded_or_qualified_routes.csv` | Excluded or qualifier-required routes |
| `tables/aging/aging_F7X6_end_user_clarity_checklist.csv` | End-user pass/fail checklist |
| `tables/aging/aging_F7X6_status.csv` | Verdict keys |

---

## 19. Explicit statements (required)

1. **This is not a final naming contract.**  
2. **This does not rename** repository artifacts, files, columns, or code variables.  
3. **This does not declare physical validity** or mechanism.  
4. **Names alone are insufficient**; display names **must** be paired with **required metadata**.  
5. **`Track A` and `Track B` are not semantic names** -- they are router governance labels and must be paired with object and stage tokens.  
6. **F7X bridge components** are **bridge/export** objects unless and until separately validated; they are not canonical physics observables by id alone.  
7. **`tau_effective_seconds` must not be displayed** without **tau-domain metadata** and the full disclosure bundle required by F7X5 R-TAU-002.  
8. **Background / baseline / residual** terms require **branch and stage (or category token)** qualifiers -- never standalone contract labels.

---

## Cross-module

**No** edits to Switching, Relaxation, or MT paths as part of this task.
