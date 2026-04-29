# Decision record: Switching main manuscript narrative vs source and diagnostic namespaces

**Status:** Adopted for repository documentation and agent governance.  
**Physics:** No code paths were changed in this decision record.  
**Date context:** Recorded as part of namespace governance update (see `reports/switching_main_narrative_namespace_decision.md`).

---

## Selected namespaces (contract)

| Role | `namespace_id` | Meaning |
|------|----------------|---------|
| **Selected manuscript analysis** | `CORRECTED_CANONICAL_OLD_ANALYSIS` | Corrected replay of the **old centered** Switching analysis (collapse-style **I_peak** / **width** scaling and **residual decomposition** on **`x = (I-I_peak)/w`**) **replayed or aligned on canonical Switching `S` data** from `CANON_GEN_SOURCE`. |
| **Canonical source of `S` data** | `CANON_GEN_SOURCE` | **`Switching/analysis/run_switching_canonical.m`** outputs: authoritative **`switching_canonical_S_long.csv`** (and related tables) for **measured `S`**, grid identity, and observables tied to **`S`** — **not** a claim that its **PT/CDF columns** are the manuscript backbone. |
| **Experimental / diagnostic PT–CDF** | `EXPERIMENTAL_PTCDF_DIAGNOSTIC` | **`S_model_pt_percent`**, **`CDF_pt`**, **`PT_pdf`** produced inside **`CANON_GEN`** and any **hierarchy/overlay** consumers that treat those columns as a PT–CDF construction — **isolated** from **main manuscript backbone** claims unless explicitly reselected by a future decision. |
| **Legacy / template** | `LEGACY_OLD_TEMPLATE` | Alignment-era **`OLD_FULL_SCALING`**, **`OLD_BARRIER_PT`**, **`OLD_RESIDUAL_DECOMP`** artifacts and scripts **as originally run** on legacy inputs — **historical template only** unless replayed under **`CORRECTED_CANONICAL_OLD_ANALYSIS`**. |

---

## Why `CANON_GEN` PT/CDF is **not** selected as the main backbone (narrative)

1. **Governance choice:** The manuscript narrative is the **corrected old centered analysis** replayed on canonical **`S`** (`CORRECTED_CANONICAL_OLD_ANALYSIS`), not the **native-`I` gradient-of-`S/S_peak`** construction that populates **`PT_pdf` / `CDF_pt`** in **`CANON_GEN`** output (`EXPERIMENTAL_PTCDF_DIAGNOSTIC`).

2. **Technical distinction (documentation only):** The old centered pipeline uses **`Speak*CDF`** with **`cdfFromPT` / fallback** and **`x`-grid SVD** (`OLD_RESIDUAL_DECOMP` logic), which is **not identical** to the **`CANON_GEN`** first-mode **`svd(Rfill)`** on **native current** (see `tables/switching_backbone_decomposition_simple_map.csv`).

3. **Confusion control:** Keeping **`CANON_GEN_SOURCE`** as **data-only** in narrative language avoids equating **“canonical tables”** with **“selected physical backbone narrative”** without a `namespace_id`.

---

## What future agents **may** claim

- Main manuscript **decomposition / collapse / Phi–kappa** claims must cite **`CORRECTED_CANONICAL_OLD_ANALYSIS`** and the **specific replay runner** (script + run id) used (e.g. `Switching/analysis/switching_residual_decomposition_analysis.m` configured for canonical-aligned inputs, `scripts/run_switching_old_WI_recipe_replay.ps1`, `scripts/run_switching_old_collapse_apples_to_apples.ps1`, `Switching/analysis/run_switching_phi1_kappa1_experimental_replay.m` where applicable — list is **non-exhaustive** and must match the artifact actually used).

- **`S`** maps, **`S_peak`**, **`I_peak`** for **canonical** data provenance must cite **`CANON_GEN_SOURCE`** + resolved **`run_*_switching_canonical`** path and sidecars.

- **`PT_pdf` / `CDF_pt` / `S_model_pt_percent`** as **diagnostics** or **source-layer** checks may cite **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** and must **not** be labeled “main manuscript backbone” under this decision.

## What future agents **must not** claim (without a new decision record)

- That **`CANON_GEN`** **PT/CDF columns** are the **selected main manuscript backbone** under this contract.

- That **“the canonical backbone”** exists without a **`namespace_id`**.

- That **legacy alignment-only** **`OLD_*`** outputs prove the **current** manuscript narrative without **`CORRECTED_CANONICAL_OLD_ANALYSIS`** replay on **`CANON_GEN_SOURCE`** data.

---

## Verdict flags (CSV mirror)

See `tables/switching_main_narrative_namespace_decision.csv` for machine-readable keys including:

- `CANON_GEN_PTCDF_SELECTED_AS_MAIN_BACKBONE=NO`
- `CORRECTED_CANONICAL_OLD_ANALYSIS_SELECTED_FOR_MANUSCRIPT=YES`

---

## Change control

Any reversal of this narrative contract requires:

1. A new file under `docs/decisions/` superseding this record.  
2. Updates to `docs/switching_analysis_map.md`, `tables/switching_analysis_*`, and allowed/forbidden phrase tables.
