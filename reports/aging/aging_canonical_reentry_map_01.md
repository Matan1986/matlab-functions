# Aging canonical scientific re-entry map (inventory only)

**Document type:** Planning and inventory -- **not** a run recipe, **not** new physics claims.  
**Anchors (read-only):** `2af3d6f` (`Promote Aging observable user guide draft`); user-facing draft at [`docs/aging_observable_user_guide_draft.md`](../../docs/aging_observable_user_guide_draft.md).  
**F7X/F7Y closure:** Naming and user-guide track treated as **paused** for new governance edits; this map **reads** those artifacts without modifying them.  
**Hygiene:** No MATLAB, Python, replay, tau extraction, or ratio computation; see [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

---

## Scope

Summarize **which Aging routes are usable for scientific continuation now**, which remain **PARTIAL / gated**, and **what to do next** after F7X/F7Y -- **without** executing analysis.

**Machine annex:** `tables/aging/aging_canonical_reentry_route_matrix_01.csv`, `tables/aging/aging_canonical_reentry_blockers_01.csv`, `tables/aging/aging_canonical_reentry_next_slice_options_01.csv`, `tables/aging/aging_canonical_reentry_status_01.csv`.

---

## Source basis

- `docs/aging_observable_user_guide_draft.md` (draft onboarding and warnings)
- `reports/aging/aging_F7X5_definition_contract_draft.md` (implicit via scope matrix and blockers tables)
- `tables/aging/aging_F7X5_open_blockers_before_naming_contract.csv`
- `reports/aging/aging_F7X6_partial_naming_contract_draft.md` (implicit via partial naming rules)
- `tables/aging/aging_F7X6_partial_naming_rules.csv`, `tables/aging/aging_F7X6_excluded_or_qualified_routes.csv`
- `reports/aging/aging_F7Y1_docs_promotion_draft.md`, `tables/aging/aging_F7Y1_docs_promotion_draft_status.csv`

No edits were made to these sources.

---

## Route status summary

| Family | Short verdict |
|--------|----------------|
| Stage 4 **direct** | **READY_WITH_METADATA** -- primary pause-run decomposition lane when stage and signed/sharp rules are logged. |
| Stage 4 **derivative / extrema** | **READY_WITH_METADATA** -- diagnostics and extrema summaries; **do not** interchange with direct or consolidation without labels. |
| Stage 5 **fit interface** | **PARTIAL** -- interface fields citeable; kernel **not** LOCKED (B-002). |
| Stage 6 **Track A summaries** | **READY_WITH_METADATA** -- summary vectors; **not** tau-input canonical without adapter. |
| **Five-column Track B** reader | **READY** -- thin reader contract for tau dip ingest **when lineage satisfied** (best **thin** science entry). |
| **Bridge/export** | **BRIDGE_ONLY** -- pairing and automation; partial lineage on some rows (B-004). |
| **Tau outputs** | **READY_WITH_METADATA** -- exploration and ratio input **after** tau bundle complete; **`tau_effective_seconds`** **LEGACY_ONLY** without bundle (B-003). |
| **Ratio / `R_age`** | **READY_WITH_METADATA** -- downstream combinator **after** tau pairing manifest. |

Detail rows: **`aging_canonical_reentry_route_matrix_01.csv`**.

---

## Blockers summary

Inherited **F7X5** blockers **B-001--B-006** remain the spine. **Top three for scientific gating:**

1. **B-003** -- `tau_effective_seconds` shared name / dual builder -- **metadata disclosure** must precede treating tau summary columns as interchangeable (**BLOCKS_TAU_ONLY** class effects).
2. **B-004** -- **bridge lineage** incomplete / sign UNKNOWN on some rows -- affects **ratio eligibility** and confident bridge use (**BLOCKS_RATIO_ONLY** class effects).
3. **B-002** -- stage 5 **callee PARTIAL** -- limits **closed-form** claims on fit internals; interface-level fields still usable with **PARTIAL** honesty.

Full rows: **`aging_canonical_reentry_blockers_01.csv`**.

---

## Recommended next slice

**Primary ranked option:** **`TRACKB_READER_VALIDATION`** (rank **1** in `aging_canonical_reentry_next_slice_options_01.csv`) -- validates the **thinnest** tau dip input contract and lineage pointer with **low** footprint.

**Parallel high-leverage slice:** **`TAU_METADATA_COMPLETION`** (rank **2**) -- addresses **B-003** for all tau consumers.

Full candidate list and ranks: **`aging_canonical_reentry_next_slice_options_01.csv`**.

---

## Why not run physics immediately

The contracts and guide explicitly **do not certify** physical interpretation for many cells (**`NOT_CLAIMED`** semantics in the user guide). Scientific continuation **requires** staging **metadata**, **lineage**, and **route** context -- not rerunning plots without those gates.

---

## Guardrails for next task

1. **Pick one slice** from the next-slice table; do not mix maintenance or cross-module work.  
2. **Use** `docs/aging_observable_user_guide_draft.md` as the human-facing guardrail; annex CSVs under `tables/aging/` remain authoritative for machine rows.  
3. **Do not** treat bridge IDs, Track labels alone, **`tau_effective_seconds`** alone, or **`R_age`** without tau manifests as standalone physics.  
4. **MATLAB** runs, when allowed later, must follow **`docs/repo_execution_rules.md`** (wrapper-only automation policy).

---

## Cross-module

No Switching, Relaxation, Maintenance/INFRA, or MT paths were read for modification as part of creating this map.
