# Phase 2A.5 — Switching canonical component classification (read-only)

**Inputs:** Prior Phase 2 tables and `reports/switching_canonical_definition_audit.md` (not re-audited).  
**Scope:** Switching only. **Excluded:** Aging and Relaxation science (Aging/utils appears only as **technical** `createRunContext` host).

This pass **refines** classifications: *actually used* vs *reachable*, decisive labels, confidence, and separation of **core / substrate / legacy engine / contamination**.

---

## 1. Enumeration source

All items from:

- `tables/switching_canonical_dependencies.csv`
- `tables/switching_canonical_definition_audit.csv` (Q1–Q6 themes decomposed into components)
- `tables/switching_canonical_risk_flags.csv`
- Output artifacts named in `reports/switching_canonical_definition_audit.md`

are expanded and row-keyed in `tables/switching_canonical_component_classification.csv`.

---

## 2. Separation of concerns

| Layer | Meaning (this repo) |
|-------|---------------------|
| **Scientific canonical core** | Definitions and outputs **authored in** `run_switching_canonical.m`: `Smap`, PT row (`Scdf`, `Speak`, …), residual, SVD **`phi1`/`kappa1`**, **`Sfull`**, validation/gates, and **run_dir** `switching_canonical_*.csv` / canonical reports. |
| **Technical execution substrate** | Path reset, **`createRunContext`**, **`run_dir`** layout, manifests/logs, **`which(createRunContext)`** pin, execution probe CSVs. No Switching physics imported from Aging. |
| **Legacy execution engine** | **`Switching ver12`** (and optional **`General ver2`**) **functions** that turn **raw `.dat`** into **tables** and **P2P_percent**; folder **`extract_*`** metadata. **Reachable-only** paths: **`Switching ver12/plots`**, much of **`Switching/utils`** (no direct call in canonical script). |
| **Contamination risks** | **Embedded absolute `parentDir`** in **`Switching_main.m`**; optional **preset** drift; **heuristic** `CHECK_NO_PRECOMPUTED_INPUTS`; **descriptive** `CANONICAL_PIPELINE_CONFIRMED` thresholds. These do **not** redefine `Smap` inside the analysis script but can affect **provenance flags** or **environment reproducibility**. |

See `tables/switching_canonical_core_vs_substrate.csv`.

---

## 3. UNKNOWN / ambiguous resolutions

`tables/switching_canonical_unknowns_resolution.csv` forces verdicts:

| Item | Verdict |
|------|---------|
| MATLAB “Matlab functions path added” / userpath | **LEGACY_HARMLESS** (environmental; not Switching-math) |
| `CHECK_NO_PRECOMPUTED_INPUTS` heuristic | **NONCANONICAL_RISK** (metadata; low severity) |
| `resolveNegP2P` IF_PRESENT | **LEGACY_HARMLESS** (deterministic `which` behavior) |
| `createRunContext` under Aging | **LEGACY_HARMLESS** (technical only) |

No items remain **UNKNOWN_UNRESOLVED** after best-effort assignment.

---

## 4. Switching ver12 — required classification

**Verdict: `CANONICAL_SUBSTRATE`** (single label for the **code tree** used in execution)

**Not** `CANONICAL_CORE`: the normative **analysis** lives in `Switching/analysis/run_switching_canonical.m`.  
**Not** `LEGACY_HARMLESS` alone: ver12 is **load-bearing** for the **current** canonical run (raw → **P2P_percent** → channel table). “Legacy” describes **provenance**, not optional ornament.  
**Not** `NONCANONICAL_RISK` for the **tree as a whole**: the **risk** is **localized** to **configuration outside the repo** (**`Switching_main.m`** `dir = "…"` → **C09** = **NONCANONICAL_RISK**).

| Criterion | Assessment |
|-----------|------------|
| **Actual usage** | **Used:** `fileread` **`Switching_main.m`**, calls **`getFileListSwitching`**, **`processFilesSwitching`**, **`analyzeSwitchingStability`**, **`extract_*`**. **Reachable-only:** **`plots`** on path (no plot calls in canonical script). |
| **Scientific role** | Defines **pre-grid** **P2P_percent** and **stability channel** feeding **`Smap`**. |
| **Replaceable** | **Yes** *in principle* with another engine; **no** without changing measured **`S`** unless the replacement is **proven equivalent**—coupling is **tight** and **explicit**. |
| **Coupling to canonical definition** | **Strong:** canonical script **fixes** metric column (**4**), **grid aggregation**, and **downstream PT/SVD** on **`Smap`** built from ver12 outputs. |

---

## 5. Final verdicts (Phase 2A.5)

| Verdict | Value | Rationale |
|---------|-------|-----------|
| **CANONICAL_CORE_CLEAR** | **YES** | **Smap / PT / SVD / outputs** are explicit in **`run_switching_canonical.m`** and serialized under **`run_dir`**. |
| **LEGACY_SUBSTRATE_PRESENT** | **YES** | **`Switching ver12`** (**CANONICAL_SUBSTRATE**) + optional **`General ver2`** (**LEGACY_HARMLESS** engine). |
| **UNKNOWN_COMPONENTS_REMAIN** | **NO** | Prior **UNKNOWN**s resolved in **`switching_canonical_unknowns_resolution.csv`**. |
| **SCIENTIFIC_CANONICALITY_COMPROMISED** | **NO** | **Contamination** risks are **environment / metadata**; they do not introduce a **second hidden definition** of **`Smap`** in **`Switching/analysis`**. |
| **READY_FOR_BOUNDARY_AUDIT** | **YES** | Components are **classified** and **core vs substrate** is **explicit**; suitable for a **boundary** audit next. |

---

## Machine-readable outputs

- `tables/switching_canonical_component_classification.csv`
- `tables/switching_canonical_unknowns_resolution.csv`
- `tables/switching_canonical_core_vs_substrate.csv`

---

## Layer 1 Robustness Interpretation

**Robustness is physics-based:** For Switching, **Layer 1** is understood as formation of **S(I,T)** ( **`Smap`** ) from measurements via the **ver12** substrate. **Canonical robustness** concerns **whether the interpreted surface and downstream canonical objects remain stable** under **admissible measurement and extraction choices** — not whether every **internal** **ver12** **implementation** knob has been **swept** in a **paired-run** experiment.

**Why implementation sweeps are not required:** **Implementation-level** stress tests (e.g. **two** full **raw→`Smap`** passes with **different** fixed **processFilesSwitching** filter settings **without** a **physics** question) are **engineering** exercises. They are **orthogonal** to the **repository’s canonical** question: **physical invariance of S(I,T)** under **definition-level** and **observable-extraction** variation **as already documented** in measurement/parameter/map artifacts (see **`reports/switching_layer1_robustness_definition.md`**). Prior audits that treated **missing paired-ver12-`Smap` runs** as **no robustness** **misinterpreted** that distinction; **formal criterion:** **`IMPLEMENTATION_SWEEP_REQUIRED = NO`**.

---

*Inspect-only; no code or pipeline changes.*
