# Canonical Switching analysis plan — expanded legacy-parity checklist

This document **extends** the six-stage roadmap in `reports/switching_canonical_analysis_plan.md` into a **row-level checklist** so legacy analysis families are not skipped silently. It preserves canonical constraints from the hierarchy plan and legacy gap audit: **no width-derived collapse as truth**, **no legacy alignment as canonical input**, **no marking legacy outputs as canonical**.

**Machine-readable checklist:** `tables/switching_canonical_analysis_plan_expanded.csv` (same columns as below).

**Sources:** `reports/switching_canonical_analysis_plan.md`, `tables/switching_canonical_analysis_plan.csv`, `reports/switching_canonical_legacy_gap_audit.md`, `tables/switching_canonical_legacy_gap_audit.csv`, `reports/switching_canonical_map_visualization.md`.

---

## Column definitions

| Column | Meaning |
|--------|---------|
| `legacy_parity_item` | Legacy script family or analysis name this row tracks |
| `canonical_input_required` | Candidate canonical tables or policy strings |
| `gated_input_required` | **YES** = must pass collapse-style gate / metadata validation; **NO** = read-only or policy; **PARTIAL** = mixed or join outside five-file gate; **N_A** = not applicable |
| `width_or_alignment_risk` | **LOW** / **MEDIUM** / **HIGH** or short rationale |
| `carry_forward_decision` | One of: `carry_forward_canonical`, `carry_forward_as_diagnostic_only`, `exclude_width_based`, `needs_redesign`, `optional` |

---

## Stage 1 — Measured map, PT/CDF backbone, residuals, provenance

Concrete items **1.1–1.6** in the CSV cover: **measured `S_percent` heatmaps** (implemented in `run_switching_canonical_map_visualization.m` for measured-only; extend for backbone/residual parity); **PT/CDF backbone** (`S_model_pt_percent` from gated `switching_canonical_S_long.csv`); **residual** (`residual_percent` or derived `S − S_model_pt`); optional **CDF_pt / PT_pdf** panels; **validation** cross-read from `switching_canonical_validation.csv`; **caption/provenance** block from `.meta.json` (formalized in Stage 6).

**Stage 1 status (map viz report):** gated `S_long`, `used_width_scaling=NO`, `LEGACY_ALIGNMENT_USED=NO`, inspection figure written, `PAPER_READY_FIGURE=NO`, `READY_FOR_STAGE2_RECONSTRUCTION_VISUALIZATION=YES`.

---

## Stage 2 — Reconstruction maps and residuals after each level

Items **2.1–2.7**: archive-read **hierarchy dominance** (`switching_canonical_collapse_hierarchy_*` + gate status); **spatial pred0 / pred1 / pred2** and **residuals after backbone, Phi1, Phi2** (legacy parity: reconstruction / verification families); **per-channel** hierarchy extension and **`phi2Vec` export** flagged as `needs_redesign` / `optional` where the producer does not yet emit a standalone table.

Phi1/kappa1 and Phi2/kappa2 **diagnostics** are covered implicitly by **2.2–2.5** (spatial stack) plus **Stage 3** rank/variance items and **LCE.5**; quantitative Phi1/Phi2 RMSE stack is **LCE.1** (replaced by hierarchy).

---

## Stage 3 — Rank, variance, dominance, high-T, 22–24 K, regime

Items **3.1–3.5**: **transition_flag** join to `error_vs_T`; **regime slices** from `switching_residual_rank_structure_by_regime.csv`; **high-T (28–30 K) anomaly** narrative tied to gated metric interpretation CSV; **22–24 K window** reconstruction as **gated adapter only** (`alignment_risk_if_script_reused_unadapted`); **mode cosine stability** optional from residual producer tables.

---

## Stage 4 — Observable mappings

Items **4.1–4.3**: **observables ↔ S_long** crosswalk; **PT relationship** legacy tables **read-only** compare; **channel identity** checklist on `S_long`.

---

## Stage 5 — Robustness / sensitivity

Items **5.1–5.4**: **leave-one-T-out** on gated inputs; **ridge on current axis only** as diagnostic; **explicit exclusion register** for width interaction / full_scaling (`exclude_width_based`); **Phi1 sign / metadata** contract note as `optional`.

---

## Stage 6 — Paper figure spine

Items **6.1–6.3**: **6–12 panel bundle** with provenance; **legacy figure_repair** as presentation-only `optional`; **index markdown** listing panel sources and gate rows.

---

## Legacy collapse components (explicit)

| Treatment | Legacy / topic | Canonical posture |
|-----------|----------------|---------------------|
| **Replaced by canonical hierarchy** | Width-free RMSE backbone → Phi1 → Phi2 dominance (planned H1–H3) | `switching_canonical_collapse_hierarchy_*` + gated inputs — row **LCE.1** |
| **Diagnostic only** | Subrange/filtered collapse tables; alignment-manifest verification reads; PT audit vs legacy tables; ridge heuristic; high-T interpretation refresh | Rows **LCE.3**, **LCE.4**, **4.2**, **5.2**, **3.3** — do not promote to canonical truth |
| **Invalidated / excluded (width / alignment)** | Shift–scale / width-parameterized collapse, width interaction tests, scaling test CSV | Rows **LCE.2**, **5.3** — `exclude_width_based` |
| **Still missing a canonical gated equivalent** | Alignment-centric reconstruction verification as **first-class gated spine**; window 18–30 K on gated-only recipe without legacy adapter | Rows **LCE.4**, **3.4** — `carry_forward_as_diagnostic_only` or adapter work |
| **Carry forward canonical (viz/table)** | Rank / dominance from global and by-regime rank tables | Row **LCE.5** + hierarchy dominance row already quantitative |

---

## Next three minimal tasks (after Stage 1)

These are the **smallest** sequencing steps toward legacy parity **without** broad refactors:

1. **Extend Stage 1 visualization (same gated `S_long` entrypoint):** add panels for **`S_model_pt_percent`** (PT/CDF backbone) and **`residual_percent`** (or derived residual), matching checklist **1.2** and **1.3**, still `PAPER_READY_FIGURE=NO` until Stage 6.
2. **Stage 2 read-only visualization spine:** one script or recipe that loads gated **`S_long`**, **`switching_canonical_phi1.csv`**, **`switching_mode_amplitudes_vs_T.csv`** (and hierarchy metadata discipline) and writes **pred0 / pred1 / pred2** and **residual-after-each-level** heatmaps — checklist **2.2–2.5**; no duplicate hierarchy recompute.
3. **Stage 3 thin join:** merge **`switching_transition_detection.csv`** onto **`switching_canonical_collapse_hierarchy_error_vs_T.csv`** by `T_K` for a small regime/transition table — checklist **3.1** (accept **PARTIAL** gating on transition CSV).

---

## Final verdicts

| Verdict | Value |
|---------|--------|
| `EXPANDED_PLAN_DEFINED` | **YES** — expanded table + this report |
| `STAGE1_VISUALIZATION_RECOGNIZED` | **YES** — `run_switching_canonical_map_visualization.m`; measured `S_percent`; flags per `switching_canonical_map_visualization.md` |
| `LEGACY_PARITY_CHECKLIST_COMPLETE` | **YES** — checklist **document** complete; not all rows executed |
| `CRITICAL_UNMAPPED_LEGACY_ITEMS_REMAIN` | **YES** — e.g. windowed reconstruction on gated-only spine, `phi2Vec` export, multi-channel spatial parity (see CSV notes on **2.6–2.7**, **3.4**, **LCE.4**) |
| `WIDTH_ALIGNMENT_RISKS_CLASSIFIED` | **YES** — `width_or_alignment_risk` populated per row |
| `NEXT_THREE_TASKS_DEFINED` | **YES** — three tasks listed above |
| `READY_TO_IMPLEMENT_STAGE2` | **YES** — gated reconstruction/residual maps are the next visualization spine after extending Stage 1 panels |

Duplicate machine-readable verdict rows: **`VERDICT`** stage in `tables/switching_canonical_analysis_plan_expanded.csv`.

---

## Decision-gated scientific roadmap (strict)

This roadmap is **additive** and stricter than the legacy-family checklist above. Legacy parity remains tracked, but scientific progression is now controlled by **decision gates A-G**. A later phase cannot produce canonical claims if an upstream gate fails.

### Governing rules (hard constraints)

1. **Observable mapping is provisional** until **Mode admissibility audit (Gate C)** passes.
2. **Dynamic plateau-drift mapping is conditional**, not default; run only after explicit trigger conditions in Gate F.
3. **Reconstruction success is not collapse success**; map-level residual fit does not replace collapse hierarchy gate metrics.
4. **Old width collapse is diagnostic only**, never canonical truth.
5. **Phi1/Phi2 cannot be called physical modes** until admissibility gates pass (Gate C, then Gate D classification).
6. **No claims/context/snapshot updates** before **Interpretation lock (Gate G)**.

### Phases and decision gates

| Phase | Scientific question | Required inputs | Forbidden inputs | Required artifacts | Status flags | Pass/fail gate | Blocking dependencies | Agent mode | Parallel? |
|------|----------------------|-----------------|------------------|--------------------|--------------|----------------|-----------------------|------------|-----------|
| **A. Current canonical truth freeze** | What is the frozen canonical evidence boundary for this run lineage? | Canonical run-manifested outputs (`switching_canonical_S_long.csv`, hierarchy CSVs, gate-status table, run metadata sidecars) | Width/full-scaling collapse tables as truth; legacy alignment cores as canonical sources | Frozen input manifest, canonical scope note, gate inventory table | `TRUTH_FREEZE_DONE`, `INPUT_MANIFEST_LOCKED` | **PASS** if frozen set is complete and reproducible; **FAIL** if any canonical source ambiguity remains | None (entry phase) | **Narrow** | **No** |
| **B. Backbone validity audit** | Does PT/CDF backbone explain the baseline structure on frozen canonical tensors? | Frozen set from A; backbone terms (`S_model_pt_percent`, residual decomposition columns) | Any width-based scaling; ungated replacement backbones | Backbone validity memo, error-vs-T backbone table, failure taxonomy | `BACKBONE_AUDIT_DONE`, `BACKBONE_VALID` | **PASS** if backbone validity criteria met over canonical domain; **FAIL** blocks physical mode claims | A pass required | **Narrow** | **Yes** (by temperature/regime slices) |
| **C. Mode admissibility audit** | Are Phi1/Phi2 mathematically stable and empirically admissible as model modes? | A freeze + B outputs + hierarchy dominance/error tables + mode-amplitude diagnostics | Any physical interpretation labels for Phi1/Phi2 before gate pass | Admissibility report, admissibility scorecard, reject/accept decision log | `MODE_ADMISSIBILITY_AUDITED`, `MODE_ADMISSIBLE` | **PASS** if admissibility thresholds pass; **FAIL** forces non-physical labeling and blocks D-G physical claims | A and B pass required | **Narrow** | **Partial** (subtests parallel, final decision serial) |
| **D. Mode relationship / mechanism classification** | If admissible, what relationship class (complementary/competitive/orthogonal/etc.) is supported? | C-pass admissible modes + hierarchy and residual rank structure tables | Mechanistic claims without C pass; width/alignment-derived mechanism evidence | Mechanism classification matrix, evidence map, uncertainty register | `MECHANISM_CLASSIFIED`, `MECHANISM_CONFIDENCE_SET` | **PASS** if one bounded class is supported with uncertainty; **FAIL** reverts to descriptive-only framing | C pass required | **Broad** | **Yes** |
| **E. Static observable mapping** | Which static observables map to canonical mode/backbone structure at fixed conditions? | C pass (required), D outputs (if available), canonical observables + S_long crosswalks | Final observable claims before C pass; snapshot/context publication updates | Provisional-to-final observable mapping table, crosswalk note, exclusions list | `OBSERVABLE_MAPPING_PROVISIONAL`, `OBSERVABLE_MAPPING_FINAL` | **PASS** only if C has passed and mapping quality checks pass; **FAIL** keeps provisional-only status | C pass required; D recommended | **Broad** | **Yes** |
| **F. Conditional dynamic plateau-drift mapping** | Under explicit triggers, how do plateau/drift dynamics relate to admitted modes and backbone? | A-E outputs + transition/regime tables + explicit trigger declaration | Running as default phase; dynamic claims when trigger criteria unmet | Conditional dynamic appendix, trigger record, drift/plateau diagnostics | `DYNAMIC_MAPPING_TRIGGERED`, `DYNAMIC_MAPPING_COMPLETE` | **PASS** if trigger criteria documented and diagnostics are coherent; **FAIL** means dynamic branch is skipped or quarantined | E pass required; trigger required | **Broad** | **Yes** (conditional branch workstreams) |
| **G. Interpretation lock / paper boundary** | What exact claims are locked, and what remains out-of-scope for paper/context updates? | All prior passed gates, uncertainty registers, provenance bundle | Any claims/context/snapshot updates before lock; un-gated evidence | Interpretation lock file, claims matrix, publication boundary statement | `INTERPRETATION_LOCKED`, `CLAIMS_UPDATE_ALLOWED` | **PASS** locks claim set and allows updates; **FAIL** keeps update embargo | A-E required; F only if triggered | **Narrow** | **No** |

### Decision-gated status rows (required)

| Status | Value |
|--------|-------|
| `DECISION_GATED_ROADMAP_DEFINED` | **YES** |
| `MODE_ADMISSIBILITY_REQUIRED_BEFORE_FINAL_OBSERVABLES` | **YES** |
| `BACKBONE_VALIDITY_REQUIRED_BEFORE_MODE_PHYSICS` | **YES** |
| `DYNAMIC_MAPPING_CONDITIONAL` | **YES** |
| `CLAIMS_UPDATE_BLOCKED_UNTIL_INTERPRETATION_LOCK` | **YES** |
