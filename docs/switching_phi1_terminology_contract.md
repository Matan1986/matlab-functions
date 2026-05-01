# Switching Phi1 terminology contract

**Scope:** Switching only. **Documentation contract** — does not change analysis code or numeric tables.  
**Supersedes nothing globally:** This document **narrows** Phi1/mode1 vocabulary for agents and repo scans. It **supplements** (does not replace) `tables/switching_corrected_old_authoritative_artifact_index.csv`, `reports/switching_corrected_canonical_current_state.md`, `docs/switching_analysis_map.md`, `reports/switching_legacy_canonical_separation_contract.md`, and `tables/switching_forbidden_conflations.csv`.

**Machine-readable mirror:** `tables/switching_phi1_terminology_registry.csv`. **Pointers:** `tables/switching_phi1_source_of_truth_pointer.csv`.

---

## 1. Relationship to existing governance (non-duplicate role)

- **`tables/switching_corrected_old_authoritative_artifact_index.csv`** remains the **artifact-centric** authority (paths, `namespace_id`, allowed/forbidden use per row).
- **`tables/switching_forbidden_conflations.csv`** remains the **cross-namespace equivalence** ban list (e.g. `Phi1_old == Phi1_canon`).
- This contract is the **term-centric** home for **Phi1-shaped** objects: which phrases are **blocked**, which files are **manuscript-aligned** vs **diagnostic**, and **normalization/sign caveats** in one place.

---

## 2. Blocked phrases (until a future gate)

The following are **not safe** to use in prose, filenames, or claims **without** an explicit future **certification gate** that locks **source artifact path**, **normalization convention**, **sign convention**, and **allowed usage scope**:

- **`Phi1_canon`**
- **`canonical Phi1`** (and bare **`canonical Phi1`** without `namespace_id` + path)

**Gate requirement:** A future maintainer must publish a single certification record (table + report row) that names the **exact CSV** (or run-scoped equivalent), norm type, sign rule, and manuscript/diagnostic class before these labels become **ALLOWED**.

Until then, use **allowed replacements** from section 4.

---

## 3. Definitions

### 3.1 Manuscript-aligned corrected-old Phi1 shape

The **first residual spatial mode shape** under the **corrected-old authoritative** pipeline, **`CORRECTED_CANONICAL_OLD_ANALYSIS`**, stored as a **curve over aligned coordinate** **`x_aligned`** with column **`Phi1_corrected_old`**.

**Authoritative table path (promoted):** `tables/switching_corrected_old_authoritative_phi1.csv`  
**Index row:** `corrected_old_authoritative_phi1` in `tables/switching_corrected_old_authoritative_artifact_index.csv`.

### 3.2 Diagnostic canonical-run Phi1-like output

**`switching_canonical_phi1.csv`** is a **diagnostic Phi1-like output** from **`Switching/analysis/run_switching_canonical.m`** (per run under `results/switching/runs/<run_id>/tables/`). It holds **`Phi1`** vs **`current_mA`** (native **I** grid). Governance class: **`DIAGNOSTIC_MODE_ANALYSIS`** / experimental phi path per `docs/switching_governance_persistence_manifest.md` and `reports/switching_corrected_canonical_current_state.md` — **not** interchangeable with the manuscript-aligned corrected-old Phi1 shape.

**Required safe sentence (use verbatim when disambiguating):**

> **`switching_canonical_phi1.csv` is a diagnostic Phi1-like output from the canonical run. Despite its filename, it is not the locked manuscript-aligned Phi1 shape and must not be treated as `Phi1_canon`.**

**Filename risk:** The word **canonical** in the filename reflects **historical producer naming** and **mixed CANON_GEN outputs**; it **must not** be read as permission to call this object “the” canonical Phi1 for manuscript claims.

### 3.3 mode1

**First singular-vector direction** of a **residual tensor** after subtracting a chosen backbone in a given script context (e.g. **`Smap - Bmap`** then **SVD**). **mode1** is **recipe-specific** (grid, backbone, fill). In some consumers, an aggregated **`Phi1`** column may be **anti-parallel** to **mode1** with unit conventions chosen so **`pred1 = pred0 - kappa1*phiVec'`** matches **signed** rank-one correction — **not** automatic equality of symbols without citing the script.

### 3.4 residual-after-mode1

**Residual map or surface after subtracting the rank-one (mode-1) reconstruction** in the **corrected-old** package — e.g. **`tables/switching_corrected_old_authoritative_residual_after_mode1_map.csv`**. This is a **map object**, **not** the Phi1 curve table.

### 3.5 DeltaS_after_mode1

Informal **delta-residual** language for **what remains after removing the mode-1 layer** in decomposition narratives — **not** a synonym for **Phi1**. Prefer citing the **named authoritative residual-after-mode1 artifact** when precision matters.

### 3.6 Collapse defect

**Overlay / collapse QA metric** (e.g. deviation-from-mean curve on a collapse coordinate). **Not** a definition of Phi1. Phase **4B C02/C02B** collapse-defect and **primary collapse variant** panels are **QA / inspection evidence**, not Phi1 decomposition outputs.

### 3.7 Primary collapse variant

**Phase 4B C02B** primary collapse overlays (PRIMARY / G014 / G254): **inspection-only** variants for collapse QA — **do not** define Phi1.

### 3.8 Phi2

Second residual mode in **canonical-collapse-family / hierarchy** narratives reading **`switching_canonical_S_long.csv`** experimental columns — see **`docs/switching_analysis_map.md`** (`CANON_COLLAPSE_FAMILY`). Not interchangeable with corrected-old authoritative Phi2 (missing row in artifact index).

### 3.9 Phi3_diag / kappa3_diag

Diagnostic-only descriptors per **`reports/switching_legacy_canonical_separation_contract.md`** — **not** closure coordinates.

### 3.10 kappa1 (scale / amplitude convention)

**kappa1** **carries temperature-dependent amplitude** alongside a **normalized shape** mode in rank-one **`kappa1(T) * shape(I)`** constructions. **Do not** equate **kappa1** from the **mixed canonical producer / observables** path with **kappa1** from **`tables/switching_corrected_old_authoritative_kappa1.csv`** without an explicit bridge audit. **Normalization split:** producer-side scaling of **Phi** and **SVD-derived amplitudes** vs consumer **L2** renormalization of interpolated shapes appears in pipeline-specific comments — cite script + table family when comparing numbers.

---

## 4. Allowed replacement vocabulary

| Intent | Wording |
|--------|---------|
| Manuscript Phi1 shape | **`Phi1_corrected_old`** from **`tables/switching_corrected_old_authoritative_phi1.csv`**, **`CORRECTED_CANONICAL_OLD_ANALYSIS`** |
| Diagnostic Phi from canonical run | **Diagnostic Phi1-like output:** **`switching_canonical_phi1.csv`** from **`run_switching_canonical.m`**, **`DIAGNOSTIC_MODE_ANALYSIS`** (not manuscript-aligned Phi1) |
| Legacy centered decomposition | **`Phi`** from **`phi_shape.csv`**, **`OLD_RESIDUAL_DECOMP`**, explicit replay namespace |

---

## 5. Explicit non-equivalences

- **residual-after-mode1** is **not** Phi1.
- **DeltaS_after_mode1** (informal) is **not** Phi1.
- **collapse-defect** and **primary collapse variants** (C02/C02B) **do not** define Phi1.
- **corrected-old authoritative Phi1** and **diagnostic `switching_canonical_phi1.csv`** are **not** interchangeable.
- **`switching_canonical_phi1.csv`** **must not** be treated as **`Phi1_canon`** or as **`canonical Phi1`** for manuscript claims.

---

## 6. Normalization and sign caveats (documentation-only)

- **Producer (`run_switching_canonical.m`):** exports **`Phi1`** with **max-abs** scaling (per-channel) and **Spearman / Speak-related** sign alignment in producer logic — see script for exact behavior.
- **Some downstream consumers:** re-interpolate aggregated shapes and apply **unit L2** (`norm`); hierarchy runners document **anti-parallel** relation to **mode1** and **`pred1`** sign convention.
- **`docs/switching_canonical_definition.md`** is **DEPRECATED** at file head; do not treat its Phi1 norm bullets as the sole current contract without cross-checking producer + consumer scripts.

---

## 7. Rename / alias policy

- **Rename `switching_canonical_phi1.csv` now:** **NO** (this task). Compatibility and producer wiring remain unchanged.
- **Document misleading filename:** **YES** (this contract + registry).
- **Later compatibility-safe alias or deprecation note:** **YES** — recommend a follow-on task (wrapper export name or sidecar label) without breaking existing runs.

---

## 8. Audit lineage

Phi1 meaning audit package: `reports/switching_phi1_meaning_artifact_audit.md`, `tables/switching_phi1_meaning_*.csv`.
