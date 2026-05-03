# Aging F7X7 -- User-facing observable guide (draft)

**Anchors (read-only):** `36d817e` (F7X2--F7X5 audits), `e59244c` (F7X6 partial naming contract).  
**Basis:** F7X5 partial definition contract and F7X6 partial naming/display rules -- summarized here for readability.  
**Execution hygiene:** No MATLAB, Python, replay, tau extraction, or ratio runs; see [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).

---

## Purpose

The F7X2--F7X6 artifacts record surveys, definitions, and governance rules in detail. This guide translates that material into **plain language** so a future reader can orient themselves **without** reading every annex first.

---

## What this guide is / is not

| This guide **is** | This guide **is not** |
|---------------------|------------------------|
| A **draft** orientation map for Aging observables | A **final naming contract** |
| Faithful to F7X5/F7X6 boundaries | Permission to **rename** columns, files, or variables |
| Honest about qualifiers and metadata | A claim of **physical validity**, mechanism, or optimality |
| A companion to machine annex tables under `tables/aging/` | An edit to router docs or prior F7X tables |

**Explicit:**

- This is a **guide**, not a final naming contract.
- It **does not rename** anything in the repo or in outputs.
- It **does not claim** physical validity for any quantity.
- **`Track A`** and **`Track B`** are **not** semantic names for observables -- they are **router lane labels** that must be paired with specific objects and stages.
- **F7X bridge components** are **bridge/export** alignment objects unless and until separately validated -- not treated here as standalone canonical observables.
- **`tau_effective_seconds`** must **not** be interpreted or displayed as an authoritative time scale **without** tau-domain metadata and method/consensus disclosure (F7X5 tau gate).
- **`FM_abs`** is **magnitude-only** (sign collapsed); it does **not** carry signed FM behavior.
- Words like **background**, **baseline**, and **residual** are **unsafe alone** -- always tie them to a **branch/stage** or contract token (smooth vs fit vs derivative baseline).

---

## Quick map of Aging observable families

At a glance (details below):

1. **Stage 4 direct family** -- decomposition of the pause-run delta-magnetization trace into smooth, sharp, dip, and FM-related quantities (`cfg.agingMetricMode` includes `direct`, `model`, or `fit` but still uses the **direct-family** code path -- not stage 5 Gaussian fit).
2. **Stage 4 derivative family** -- alternate decomposition with derivative-specific FM definitions.
3. **Stage 4 extrema-smoothed family** -- scalars from extrema on a **moving-mean** smoothed curve (not the same smooth as sgolay `DeltaM_smooth`).
4. **Stage 5 fit interface** -- dip-area and FM-energy style outputs written after parametric fitting (interface list is partly **PARTIAL** pending callee audit).
5. **Stage 6 Track A summaries** -- summary vectors such as `AFM_like` / `FM_like` for figure-style summaries (not the five-column consolidation contract).
6. **Five-column consolidation (Track B reader contract)** -- thin dataset (`Tp`, `tw`, `Dip_depth`, `FM_abs`, `source_run`) for standardized readers; **`FM_abs` only**, no signed FM column.
7. **Bridge/export rows** -- long-form bridge components for cross-branch pairing (bridge-only semantics).
8. **Tau outputs** -- tables like `tau_vs_Tp.csv` / `tau_FM_vs_Tp.csv` plus legacy **`tau_effective_seconds`** (needs full metadata bundle).
9. **Ratio / downstream outputs** -- e.g. **`R_age`** from clock-ratio scripts on **prior tau tables**, not raw pause-run traces.

Machine-readable companions: `tables/aging/aging_F7X7_user_observable_cheatsheet.csv`, `tables/aging/aging_F7X7_safe_use_matrix.csv`.

---

## How to read an Aging observable name

Repo names are often **legacy-shaped**. Treat every label as **three layers**:

1. **Headline token** (column name or field name) -- may be ambiguous alone.
2. **Stage / route** -- where it was produced (stage 4 mode, stage 5/6, tau script, ratio script, bridge export).
3. **Metadata panel** -- domain, method, sign policy, lineage (see **Minimal metadata checklist** below).

If two tokens share a substring (for example `FM_*`), **do not assume** they share the same definition across branches.

---

## Direct decomposition observables

**Plain idea:** Quantities derived inside the **stage 4 direct-family** path from the pause-run magnetization step features -- smooth trend, sharp residual relative to pipeline `dM`, signed dip residual, and plateau FM scalars.

**Watch:** `DeltaM_sharp` uses **`dM` minus** `DeltaM_smooth`; **`dip_signed`** uses **`DeltaM_signed` minus** the **same** smooth vector. They are **not automatically identical** unless `dM` and `DeltaM_signed` match for that run.

---

## Derivative / extrema observables

**Derivative family:** Same pipeline stage as direct in terms of orchestration, but FM quantities can be **redefined** using derivative-route rules (for example median behavior outside the dip). **Do not** swap derivative FM with direct FM without relabeling.

**Extrema-smoothed family:** Uses **moving-mean smoothing** then extrema -- **different** from sgolay `DeltaM_smooth`. Do not alias these extrema scalars to consolidation **`Dip_depth`**.

---

## Stage 5 / stage 6 fit / summary observables

**Stage 5:** Fit-derived fields (examples include dip area selections and FM energy style scalars) live on pause runs **after** the Gaussian/tanh-style fit stage. The contract treats **interface-level names** as citeable; **internal kernel details** remain **PARTIAL**.

**Stage 6 Track A summaries (`AFM_like`, `FM_like`):** High-level summary vectors feeding **Track A** style figures. They trace back to fit selections / energies -- **not** the same contract object as five-column **`Dip_depth`**.

---

## Bridge / export observables

Bridge rows exist for **pairing and export** across branches (for example consolidation dip depth vs FM magnitude bridges). They carry **bridge-only** allowed use in the contracts.

**User rule:** If you see an ID like **`C_DIP_DEPTH_B`** / **`C_FM_ABS_B`**, read it as **bridge/export**, show **branch family** and **sign policy** metadata, and **do not** treat the bare ID as a free-standing physics observable.

---

## Tau observables

Tau CSV rows are **downstream** of decomposition -- they summarize **curves** (for example dip depth vs wait time) into characteristic times.

**Minimum expectations before trusting a tau cell:** domain (dip vs FM curve fit family), method/recipe, input observable identity, producer script, grain (per curve vs per summary), units, lineage/consensus disclosure.

**`tau_effective_seconds`:** Treat as **legacy summary**. Two builder contexts share the name; **never** use it solo -- show **tau_domain**, **tau_method**, **producer**, **grain**, **units**, and **methods/consensus** disclosure alongside.

---

## Ratio / downstream observables

**Example:** **`R_age`** style outputs combine **already-produced tau artifacts**. They are **not** measured directly from raw pause-run delta-M like a decomposition scalar.

---

## Track A / B warning

- **Track A** points to the **stage 6 summary / figure lane** (`AFM_like` / `FM_like` and upstream fit-linked scalars).  
- **Track B** points to the **five-column consolidation reader** lane.

**Neither** label tells you *which number* you are looking at by itself. Always pair with **object names** (`Dip_depth`, `FM_abs`, ...) and **producer/stage**.

---

## Sign and magnitude warning

- **`FM_signed`** -- carries sign information in the intended signed-FM path.  
- **`FM_abs`** -- **`abs(FM_signed)`** when finite; **sign is removed**. Never read **`FM_abs`** as signed FM.  
- **`FM_step_mag`** -- **despite** `_mag` in the name, repository measurement-freeze policy treats wide-matrix **`FM_step_mag`** as **signed plateau raw** in some exports -- **do not** infer magnitude-only semantics from the substring `mag` alone; check route and export policy.

---

## Background / baseline / residual warning

Without a **stage/route token**, plain English **background**, **baseline**, and **residual** each map to **multiple incompatible constructions** (smooth trend vs fit plateau vs derivative median reference vs sharp vs signed dip residual).

**Safe habit:** Replace vague words with the contract-style distinction -- which **smooth** (sgolay direct vs movmean extrema vs fit surface), which **residual identity** (sharp vs signed dip), and which **stage**.

---

## Tau metadata warning

Any plot or table that shows **tau** fields must show **which curve family** (dip vs FM), **which method**, **which input column**, and **lineage**. Showing **`tau_effective_seconds`** alone is **misleading** per F7X5 tau gate.

---

## What is safe to use for what

Use **`tables/aging/aging_F7X7_safe_use_matrix.csv`** as the machine-oriented summary. Distilled user guidance:

- **Decomposition fields** -- usable for within-branch diagnostics and exports when stage/mode is documented; **cross-branch substitution** requires explicit pairing (often bridge), not assumed equality.
- **Five-column consolidation** -- usable as a **standard reader input** for tau dip scripts **when** lineage pointers are satisfied -- **not** a signed-FM carrier.
- **Tau outputs** -- exploration and downstream ratio inputs **with metadata**; **not** pause-run decomposition columns.
- **Ratios** -- comparative downstream summaries **after** tau inputs are gated; **not** raw observables.
- **Bridge rows** -- pairing and automation across streams -- **not** default physics replacements.

This guide **does not** upgrade any row to "validated physics truth."

---

## Common misreadings and corrections

See **`tables/aging/aging_F7X7_common_misreadings.csv`** for a concise FAQ-style table.

---

## Minimal metadata checklist

See **`tables/aging/aging_F7X7_minimal_metadata_checklist.csv`**. At minimum, ask: **what object**, **what stage/route**, **what producer**, **what sign policy** (FM family), **what grain** (tau), **what lineage status**.

---

## Open caveats before final naming contract

Inherited from F7X5 open blockers (not reopened here): human prose cleanup vs machine rows; stage 5 callee audit optional; **`tau_effective_seconds`** dual-builder disclosure in all writers; bridge lineage completeness; Track labels insufficient alone; cross-branch compare pairing coverage.

Until those are resolved or explicitly accepted as permanent **PARTIAL**, treat **final naming** and **promoted docs** as **future work**.

---

## Annex tables (F7X7)

| File | Role |
|------|------|
| `tables/aging/aging_F7X7_user_observable_cheatsheet.csv` | One-row family summaries |
| `tables/aging/aging_F7X7_common_misreadings.csv` | Incorrect vs correct reading |
| `tables/aging/aging_F7X7_minimal_metadata_checklist.csv` | Fields by quantity type |
| `tables/aging/aging_F7X7_safe_use_matrix.csv` | Display vs interpretation vs downstream gates |
| `tables/aging/aging_F7X7_status.csv` | Verdict keys |

---

## Cross-module

No Switching, Relaxation, or MT scope in this draft.
