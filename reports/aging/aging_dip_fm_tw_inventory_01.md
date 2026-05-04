# Aging Dip_depth and FM_abs wait-time inventory — Track B reader (01)

**Task:** `AGING-DIP-FM-TW-INVENTORY-01` — first baseline **wait-time inventory** for **`Dip_depth(Tp, tw)`** and **`FM_abs(Tp, tw)`** using only the validated **Track B five-column** reader.  
**Hygiene:** No MATLAB, replay, tau extraction, ratio computation, or mechanism claims; see [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Anchors / context:** [`reports/aging/aging_trackB_reader_validation_01.md`](aging_trackB_reader_validation_01.md), [`reports/aging/aging_multipath_status_01.md`](aging_multipath_status_01.md), [`docs/aging_observable_user_guide_draft.md`](../../docs/aging_observable_user_guide_draft.md).

---

## Scope

- **In scope:** Enumerate the **`Tp × tw`** grid present in **`tables/aging/aging_observable_dataset.csv`**, list **`Dip_depth`** and **`FM_abs`** versus **`tw`** per **`Tp`**, flag grid completeness (including **missing `tw=3`** at **Tp 30** and **Tp 34**), and record **descriptive** curve-shape labels only (monotonicity classification on the sampled points).
- **Out of scope:** Tau extraction, clock-ratio / **`R_age`** work, multipath overlays, Track A / Stage5 / Stage6 as science inputs, Switching, Relaxation, Maintenance/INFRA, MT, code edits, and physical interpretation beyond disclosure labels already in governance docs.

---

## Source basis

| Item | Value |
|------|--------|
| **Primary Track B table** | `tables/aging/aging_observable_dataset.csv` |
| **Contract** | Five columns: **`Tp`**, **`tw`**, **`Dip_depth`**, **`FM_abs`**, **`source_run`** |
| **Reader validation** | [`reports/aging/aging_trackB_reader_validation_01.md`](aging_trackB_reader_validation_01.md) — **TB001** cleared for thin inventory |
| **Grid audit reference** | [`tables/aging/aging_trackB_reader_grid_audit_01.csv`](../../tables/aging/aging_trackB_reader_grid_audit_01.csv) |
| **Multipath baseline lane** | [`reports/aging/aging_multipath_status_01.md`](aging_multipath_status_01.md) — baseline **Track B** wait-time inventory **allowed**; multipath substitution **not** |
| **FM semantics** | **`FM_abs`** is **ABS_ONLY** (magnitude collapsed); see [`docs/aging_observable_user_guide_draft.md`](../../docs/aging_observable_user_guide_draft.md) |

Lineage pointer on every row: **`source_run`** references `aggregate_structured_export_aging_Tp_tw_2026_04_26_085033` and MG119 pause-run labels (full string in long table).

---

## Grid summary

| Tp | Rows | Distinct **tw** | **tw** values (sorted) | **`tw=3`** | **`tw=36`** | **`tw=360`** | **`tw=3600`** | Grid status (audit-aligned) |
|----|------|-----------------|-------------------------|------------|-------------|--------------|---------------|-----------------------------|
| 14 | 4 | 4 | 3, 36, 360, 3600 | Yes | Yes | Yes | Yes | READY_FOR_CONVERGENCE |
| 18 | 4 | 4 | 3, 36, 360, 3600 | Yes | Yes | Yes | Yes | READY_FOR_CONVERGENCE |
| 22 | 4 | 4 | 3, 36, 360, 3600 | Yes | Yes | Yes | Yes | READY_FOR_CONVERGENCE |
| 26 | 4 | 4 | 3, 36, 360, 3600 | Yes | Yes | Yes | Yes | READY_FOR_CONVERGENCE |
| 30 | 3 | 3 | 36, 360, 3600 | **No** | Yes | Yes | Yes | PARTIAL_BUT_USABLE |
| 34 | 3 | 3 | 36, 360, 3600 | **No** | Yes | Yes | Yes | PARTIAL_BUT_USABLE |

**Machine table:** `tables/aging/aging_dip_fm_tw_inventory_01_by_Tp.csv`.

---

## Dip_depth vs tw — descriptive inventory

- **Low Tp (14–26):** Four decades of wait time **3 → 3600** (seconds in grid) are present. **`Dip_depth`** spans positive and **one negative** cell (**Tp 14**, **tw = 360**) — consistent with prior Track B disclosure (inventory only; not a mechanism statement).
- **High Tp (30, 34):** Only **three** **`tw`** samples (**36, 360, 3600**); the short-wait **tw = 3** point that exists for **Tp 14–26** is **absent**. Any later analysis that needs a **symmetric** short-time anchor across **all** **`Tp`** must either restrict claims to the shared grid or obtain **`tw=3`** rows for **Tp 30** and **Tp 34**.

Per-**Tp** monotonicity on **sorted** **`tw`** (descriptive flags only): **NON_MONOTONIC** at **Tp 14, 18, 22, 26**; **MONOTONIC_INCREASE** on the three sampled points at **Tp 30**; **NON_MONOTONIC** at **Tp 34** (mid versus long **tw** ordering). Details: `tables/aging/aging_dip_fm_tw_inventory_01_curve_shape_flags.csv` (observable = **`Dip_depth`**).

---

## FM_abs vs tw — descriptive inventory

- **`FM_abs`** follows the same **`Tp × tw`** presence pattern as **`Dip_depth`**.
- **ABS_ONLY:** Fig captions and later tau documentation must **not** treat **`FM_abs`** as signed FM behavior (user guide).
- Descriptive monotonicity on sorted **`tw`**: **NON_MONOTONIC** at **Tp 14–22**; **MONOTONIC_INCREASE** at **Tp 26** and **Tp 30** and **Tp 34** on the available samples; see curve-shape table.

---

## Missing tw = 3 — disclosure for Tp 30 and Tp 34

Versus **`Tp ∈ {14, 18, 22, 26}`**, both **`Tp = 30`** and **`Tp = 34`** **lack** any row with **`tw = 3`**. The consolidation still provides **36 / 360 / 3600**, so the grid is **usable** for partial comparisons but is **not symmetric** with lower-**Tp** groups at the shortest displayed wait time. This matches **`aging_trackB_reader_grid_audit_01.csv`** (**PARTIAL_BUT_USABLE**).

---

## Tau readiness (no tau computation)

| Aspect | Verdict |
|--------|---------|
| **Observable columns populated** | **Yes** for all 22 rows — see presence flags in `aging_dip_fm_tw_inventory_01_long.csv` |
| **Later tau fitting (governance)** | **PARTIAL overall**: methods/readiness are discussed in F7U/F7V and canonical re-entry docs, but **authoritative** tau claims remain **gated** by the **metadata bundle** (**F7X5 B-003** class: **`tau_effective_seconds`** / dual-builder disclosure, lineage, method/domain). |
| **Tp 14–26** | **READY_WITH_METADATA** per observable in `aging_dip_fm_tw_inventory_01_tau_readiness.csv` — meaning the **wait-time samples** are sufficient for **later** scripted extraction **after** metadata closure, not permission to skip gates. |
| **Tp 30, 34** | **PARTIAL_GRID** — missing **`tw=3`** may block **symmetric** multi-**Tp** tau comparisons unless regenerated or scope is narrowed. |

No **`tau`** values were computed in this task.

---

## Why ratio work remains blocked

**`R_age`** and clock-ratio outputs require **paired tau tables / manifests** and downstream lineage, not the five-column reader alone. Multipath status and F7V still record **bridge** and **cross-route** blocks. This inventory **does not** authorize ratio re-entry. See [`reports/aging/aging_multipath_status_01.md`](aging_multipath_status_01.md) and [`tables/aging/aging_multipath_status_01_readiness.csv`](../../tables/aging/aging_multipath_status_01_readiness.csv).

---

## Recommended next action

**`AGING-TAU-METADATA-GATE-01`** (or equivalent metadata closure): complete the **tau metadata / disclosure bundle** (**B-003** spine, **`FM_abs`** ABS_ONLY captions, **`Dip_depth`** sign disclosure where negative, **`source_run`** / sidecar lineage) **before** any authoritative tau extraction run. Optionally plan **`tw=3`** regeneration or explicit scope restriction for **Tp 30** / **Tp 34** if symmetric short-time tau fits are required.

---

## Machine artifacts (this task)

| Artifact | Path |
|----------|------|
| Long inventory | `tables/aging/aging_dip_fm_tw_inventory_01_long.csv` |
| By **Tp** summary | `tables/aging/aging_dip_fm_tw_inventory_01_by_Tp.csv` |
| Curve-shape flags | `tables/aging/aging_dip_fm_tw_inventory_01_curve_shape_flags.csv` |
| Tau readiness (planning) | `tables/aging/aging_dip_fm_tw_inventory_01_tau_readiness.csv` |
| Status | `tables/aging/aging_dip_fm_tw_inventory_01_status.csv` |
| Report | `reports/aging/aging_dip_fm_tw_inventory_01.md` (this file) |

**Optional figures:** PNG panels (**`Dip_depth`** and **`FM_abs`** vs **`tw`**) were **not** written in this execution because no usable Python plotting runtime was available in the environment. The tabulated values above are sufficient to regenerate figures locally.

---

## Cross-module

No Switching, Relaxation, Maintenance/INFRA, or MT files were modified. No Track A / Stage5 / Stage6 inputs were used as science sources for this inventory.
