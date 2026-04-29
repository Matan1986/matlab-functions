# `switching_canonical_S_long.csv` column namespace (Switching)

**Machine-readable:** `tables/switching_canonical_S_long_column_namespace.csv`

**Producer:** `Switching/analysis/run_switching_canonical.m` — **mixed producer** (see `reports/switching_canonical_output_separation_design.md`).

---

## Rule (binding)

**Opening `switching_canonical_S_long.csv` is not sufficient.** Every script, report, and agent summary must declare **which columns** it reads and under which **`namespace_id`**(s).

---

## Column classification

### CANON_GEN_SOURCE (canonical measured S + identity)

| Column | Role |
|--------|------|
| **`T_K`** | Temperature identity axis. |
| **`current_mA`** | Native current grid identity for measured **`S_percent`**. |
| **`S_percent`** | **Measured** switching surface — authoritative **`S`** payload when run path + **`CANON_GEN_SOURCE`** are cited. |

**Allowed:** Canonical **`S`** manuscript claims, corrected-old **clean source view** workflows, alignment inputs when paired with lock tables.

### EXPERIMENTAL_PTCDF_DIAGNOSTIC

| Column | Role |
|--------|------|
| **`S_model_pt_percent`** | Producer **`Scdf`/`S_model`** diagnostic backbone column — **not** authoritative **`CORRECTED_CANONICAL_OLD_ANALYSIS`** backbone. |
| **`CDF_pt`** | Quasi-CDF coordinate — diagnostic / plotting axis — **not** a substitute for declaring **`x=(I-I_peak)/width`** where relevant. |
| **`PT_pdf`** | Derived nonnegative density path — **not** raw **`dS/dI`** unless explicitly audited in-namespace. |

**Allowed:** Diagnostics, audits, hierarchy / overlay scripts with dual-namespace captions (`CANON_GEN_SOURCE` + **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**).

**Forbidden:** Manuscript-primary **`CORRECTED_CANONICAL_OLD_ANALYSIS`** backbone/residual/Phi1/kappa1 claims based solely on these columns.

### DIAGNOSTIC_MODE_ANALYSIS

| Column / artifact | Role |
|-------------------|------|
| **`residual_percent`**, **`S_model_full_percent`** | Diagnostic residuals tied to **PT/CDF** baseline in producer — **not** authoritative corrected-old residual. |
| **`switching_canonical_phi1.csv`** (neighbor file) | Mode shape from **diagnostic** **`svd(Rfill)`** on native **I** — **not** authoritative **`tables/switching_corrected_old_authoritative_phi1.csv`**. |
| **`kappa1`** in **`switching_canonical_observables.csv`** | Diagnostic decomposition amplitude — **not** authoritative **`tables/switching_corrected_old_authoritative_kappa1.csv`**. |

---

## Structural mitigation

Post-run **splitter** produces views without mixing roles:

- **`switching_canonical_source_view.csv`** — **`S_percent`** + identity only (per validated run).
- Experimental PT/CDF and diagnostic mode views — explicitly **`manuscript_safe=NO`** for corrected-old evidence.

See **`tables/switching_canonical_output_view_contracts.csv`**.

---

## Cross-links

- **`reports/switching_corrected_canonical_current_state.md`** — start here.
- **`reports/switching_corrected_old_authoritative_artifact_index.md`** — authoritative corrected-old paths.
- **`docs/switching_analysis_map.md`** — full narrative contract.
