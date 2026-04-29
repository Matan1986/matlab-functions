# Switching backbone / analysis family tree

This document complements **`docs/switching_analysis_map.md`** with a compact **family tree** for agents. Machine-readable rows: **`tables/switching_backbone_family_tree.csv`**.

---

## How to read this

- **No single “the backbone”** exists without a **`namespace_id` / `family_id`**.
- **Manuscript primary path** under current contract: **`CORRECTED_CANONICAL_OLD_ANALYSIS`** using **`tables/switching_corrected_old_authoritative_*.csv`** (see artifact index).
- **CANON_GEN_SOURCE** is authoritative for **`S_percent`** (and identity columns), not automatically for PT/CDF columns in the same filename.
- **EXPERIMENTAL_PTCDF_DIAGNOSTIC** covers **`S_model_pt_percent`**, **`CDF_pt`**, **`PT_pdf`** from the mixed producer — **not** the selected corrected-old authoritative backbone recipe.

---

## Families (summary)

| family_id | One-line role |
|-----------|----------------|
| **CANON_GEN_SOURCE** | Canonical measured **`S`** and ladder identity. |
| **EXPERIMENTAL_PTCDF_DIAGNOSTIC** | PT/CDF / quasi-Scdf **columns** from **`run_switching_canonical`** — diagnostic / supplementary. |
| **OLD_FULL_SCALING** | Legacy **collapse** and scaling parameters — **not** subtractive **S_model_pt** semantics. |
| **OLD_BARRIER_PT** | Legacy **PT_matrix** + CDF on native **I**. |
| **OLD_RESIDUAL_DECOMP** | Legacy **Speak·CDF + kappa·Phi(x)** with **x** centering — **`switching_residual_decomposition_analysis`**. |
| **CORRECTED_CANONICAL_OLD_ANALYSIS** | **Gated corrected-old authoritative** tables — manuscript target. |
| **PHI2_KAPPA2_HYBRID** | **Second** mode on top of **OLD_RESIDUAL_DECOMP** — **not** authoritative corrected-old Phi2/kappa2. |
| **DIAGNOSTIC_MODE_ANALYSIS** | **`residual_percent`**, **`switching_canonical_phi1`**, observables **kappa1** from mixed producer — **forbidden** as corrected-old evidence. |
| **QUARANTINED_MISLEADING** | Artifacts that **read** like corrected-old or canonical proof but are **contaminated** or misnamed — **registry-driven**. |

---

## Cross-links

- Claim boundaries: `tables/switching_analysis_claim_boundary_map.csv`
- Forbidden conflations: `tables/switching_forbidden_conflations.csv`
- Column-level **`S_long`** map: `reports/switching_canonical_S_long_column_namespace.md`
- Quarantine list: `reports/switching_quarantine_index.md`
