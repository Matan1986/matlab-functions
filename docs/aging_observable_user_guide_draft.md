# Aging observable user guide (draft)

> Draft documentation promoted from `reports/aging/aging_F7X7_user_observable_guide_draft.md`.
> This is not a final naming contract, does not rename artifacts, and does not certify physical interpretation.

**Anchors (read-only):** `36d817e` (F7X2--F7X5 audits), `e59244c` (F7X6 partial naming contract).  
**Basis:** F7X5 partial definition contract and F7X6 partial naming/display rules -- summarized here for readability.  
**Execution hygiene:** No MATLAB, Python, replay, tau extraction, or ratio runs; see [`docs/repo_execution_rules.md`](repo_execution_rules.md).

---

## Purpose

The F7X2--F7X6 artifacts record surveys, definitions, and governance rules in detail. This guide translates that material into **plain language** so a future reader can orient themselves **without** reading every annex first.

---

## At a glance: what not to misread

| If you see | Read it as | Do not assume |
|------------|------------|---------------|
| `Track A` | stage 6 summary / figure lane | a physical observable name |
| `Track B` | five-column consolidation reader lane | a full analysis route or physics object |
| `FM_abs` | magnitude-only FM quantity | signed FM behavior |
| `FM_step_mag` | route-dependent legacy FM field | magnitude-only semantics from `_mag` alone |
| `tau_effective_seconds` | legacy tau summary requiring metadata | authoritative time scale without tau domain/method/lineage |
| bridge IDs such as `C_DIP_DEPTH_B` / `C_FM_ABS_B` | bridge/export pairing objects | standalone canonical physics observables |
| `R_age` or ratio outputs | downstream ratios built from prior tau tables | raw measured observables |
| background / baseline / residual | branch/stage-specific constructions | universal standalone terms |

Use this table as the first screen check. If the row says "do not assume," the quantity may still be useful, but only with the required stage/source/metadata context.

---

## Quick start (first ~5 minutes)

1. Open **`tables/aging/aging_F7X7_user_observable_cheatsheet.csv`** and find the row whose **display_family** matches what you are looking at.
2. Read **object_kind** on that row: decomposition field on a pause run, bridge/export row, tau table row, ratio output, or a diagnostic/label-only concept.
3. Note **typical_source_or_stage** and your actual script/stage so **source**, **stage**, and **branch** match (stage 4 mode is not the same as stage 5 fit output).
4. For FM-related fields, check **sign or magnitude** using this guide's Sign section and the cheatsheet **main_caveat** column.
5. For **tau** or **ratio** quantities, do **not** interpret numbers until **metadata** (domain, method, inputs, lineage) is present or cited.
6. Open **`tables/aging/aging_F7X7_safe_use_matrix.csv`** and use the legend below to separate **allowed display** from **physical interpretation** (`NOT_CLAIMED`).
7. Skim **`tables/aging/aging_F7X7_common_misreadings.csv`** before comparing two columns or two branches -- most hazardous substitutions are listed there.

---

## Short glossary

- **`pauseRuns`** -- MATLAB structure/table of **per-pause-temperature** outputs from the Aging pipeline (not a CSV name). Fields depend on stage and config.
- **`DeltaM`** -- Delta magnetization step observable naming family in prose; in code comments **`dM`** often refers to **`pauseRuns.DeltaM`** as the pipeline analysis trace.
- **`dM`** -- In stage 4 direct decomposition, **`dM`** is the **`pauseRuns.DeltaM(:)`** vector used for sharp residual math unless documented otherwise.
- **`DeltaM_signed`** -- Signed delta-M field when present; may fall back to **`dM`** depending on run -- **do not assume** identity with **`dM`** without checking.
- **`stage4`** -- Pause-run **decomposition** stage (direct, derivative, or extrema modes, plus stage 4 "direct family" when `cfg.agingMetricMode` is `direct` / `model` / `fit`).
- **`stage5`** -- **Parametric fit** stage that writes fit-interface scalars to pause runs (distinct from confusing **`cfg.agingMetricMode='fit'`**, which still routes **stage 4 direct-family** code).
- **`stage6`** -- **Summary/metrics** stage (for example **Track A**-style summary vectors), not the five-column consolidation file by itself.
- **`cfg.agingMetricMode`** -- Configuration switch for **which stage 4 branch** runs. The value **`fit` here does not mean** "stage 5 Gaussian fit object" -- verify against stage numbering above.
- **`Track A`** -- **Router label** for the **stage 6 summary / figure lane** -- **not** a physical quantity name by itself.
- **`Track B`** -- **Router label** for the **five-column consolidation reader** lane -- **not** a physical quantity name by itself.
- **`bridge/export`** -- Long-form **pairing** identifiers and rows for cross-stream alignment (for example bridge component IDs) -- **bridge-only** semantics, not default standalone observables.
- **`tau output`** -- A row from a **tau script CSV** (for example `tau_vs_Tp.csv`) summarizing curves -- **downstream** of pause-run decomposition.
- **`ratio output`** -- A quantity such as **`R_age`** built from **prior tau CSVs** -- **downstream combinator**, not a raw pause-run measurement.
- **`NOT_CLAIMED`** -- In the safe-use matrix, **physical interpretation is not certified** by this guide or contract (see legend -- **not** the same as "false").
- **`WITH_METADATA`** -- Allowed only when the listed **metadata fields** are present or explicitly cited for that use (tau/ratio/bridge paths).
- **`WITH_QUALIFIER`** -- Allowed for display or use only when **branch/stage/source** context is shown -- names alone are insufficient.

---

## How to read the safe-use matrix (`aging_F7X7_safe_use_matrix.csv`)

The CSV uses short tokens in each **policy column**. Plain meanings:

| Token | Meaning |
|-------|---------|
| **YES** | Allowed as stated **when** lineage/config gates for that column are satisfied (read the **notes** column on that row). |
| **NO** | Not allowed for that column on that family row. |
| **`WITH_QUALIFIER`** | Only safe when **stage/route/source** context is attached -- **do not** use the bare column name as a full story. |
| **`WITH_METADATA`** | Do **not** treat the numeric cell as meaningful until **required metadata** (tau bundle, ratio inputs, bridge ids, etc.) is present. |
| **`NOT_CLAIMED`** | **Does not mean the quantity is false or useless.** It means this guide and the **partial contracts do not certify** a **physical interpretation** for that cell -- study-specific claims stay outside this matrix. |
| **`NA`** | Not applicable for that gate on that row (for example tau input for a row that is not a tau-ingest path). |
| **`BRIDGE_ONLY`**, **`DOWNSTREAM_ONLY`**, **`DISPLAY_ONLY`**, **`DIAGNOSTIC_ONLY`** | Vocabulary-style gates from annexes: **bridge/export** use only; **downstream** combined outputs; **display** only until bundle complete; **diagnostic** scripts or labels -- check family **notes** when these appear in companion tables. |

**Core rules:** **`WITH_METADATA`** means **do not interpret** without the required fields. **`WITH_QUALIFIER`** means **unsafe** without **branch/stage/source** context. **`NOT_CLAIMED`** means **no certified physics read** here, not disproof.

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

Use **`tables/aging/aging_F7X7_safe_use_matrix.csv`** as the machine-oriented summary. **Read the token legend under "How to read the safe-use matrix" earlier in this guide** first -- especially **`NOT_CLAIMED`** (not certified for physical interpretation, **not** "false") and **`WITH_METADATA`**. Distilled user guidance:

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
