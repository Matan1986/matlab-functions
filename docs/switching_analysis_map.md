# Switching analysis map (namespace-organized)

This document organizes the Switching **analysis landscape** around **confirmed backbone/decomposition namespaces**. It is derived from:

- `tables/switching_backbone_decomposition_simple_map.csv`
- `reports/switching_backbone_decomposition_simple_map.md`
- `tables/switching_canonical_namespace_inventory.csv`
- `tables/switching_canonical_backbone_namespace_map.csv`
- `tables/switching_canonical_svd_input_namespace_map.csv`
- `reports/switching_canonical_namespace_backbone_map.md`

**No physics logic was changed.** No analyses were rerun. No files were deleted.

---

## Current Switching narrative contract

The Switching manuscript narrative is now governed by an **explicit namespace contract** (see `docs/decisions/switching_main_narrative_namespace_decision.md` and `tables/switching_main_narrative_namespace_decision.csv`).

**Statement (binding for documentation and agent claims):**  
The **current manuscript narrative** is the **corrected canonical replay of the old centered Switching analysis** — namespace **`CORRECTED_CANONICAL_OLD_ANALYSIS`** (collapse-style **`I_peak` / width** and **`OLD_RESIDUAL_DECOMP`-style** residual decomposition on **`x = (I-I_peak)/w`**, replayed or aligned using **canonical `S` data**).  
**`CANON_GEN_SOURCE`** remains the **source of canonical `S` data** (`switching_canonical_S_long.csv` and related producer outputs from `run_switching_canonical.m`), **but** the **`CANON_GEN`**-filed **`PT_pdf` / `CDF_pt` / `S_model_pt_percent` construction** is **not** the selected main backbone/decomposition narrative; it is documented under **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**.

**Formal labels:**

| `namespace_id` | Role |
|----------------|------|
| **`CORRECTED_CANONICAL_OLD_ANALYSIS`** | **Main manuscript analysis** — old centered pipeline **on** **`CANON_GEN_SOURCE`** `S` (see decision record for exemplar replay scripts). |
| **`CANON_GEN_SOURCE`** | **Canonical `S` (and identity) source** — producer `run_switching_canonical.m`; **claims about “canonical `S`”** use this id + run path. |
| **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** | **Diagnostic / source-layer PT–CDF** — `S_model_pt_percent`, `CDF_pt`, `PT_pdf` from **`CANON_GEN`** and hierarchy readers; **not** the manuscript-selected backbone under this contract. |
| **`LEGACY_OLD_TEMPLATE`** | **Historical template** — original **`OLD_*`** runs on alignment-era artifacts unless explicitly replayed under **`CORRECTED_CANONICAL_OLD_ANALYSIS`**. |

**Rule:** Any prose using **“canonical backbone”** must specify **`namespace_id`** (`CORRECTED_CANONICAL_OLD_ANALYSIS` vs `EXPERIMENTAL_PTCDF_DIAGNOSTIC` vs none).

### Phi1 terminology (narrow contract)

Manuscript-aligned **`Phi1_corrected_old`** vs diagnostic **`switching_canonical_phi1.csv`**, blocked names **`Phi1_canon`** / **`canonical Phi1`** (until a future certification gate), and normalization/sign caveats: **`docs/switching_phi1_terminology_contract.md`**, **`tables/switching_phi1_terminology_registry.csv`**, **`tables/switching_phi1_source_of_truth_pointer.csv`**. **`switching_canonical_phi1.csv`** is a diagnostic Phi1-like output from the canonical run; despite its filename it is **not** the locked manuscript-aligned Phi1 shape (**`tables/switching_corrected_old_authoritative_phi1.csv`**). These files **supplement** **`tables/switching_corrected_old_authoritative_artifact_index.csv`** (artifact inventory); they do **not** replace it.

---

## One-page plain-language summary

1. **There is no single Switching backbone** without a **`namespace_id`**. Under the **narrative contract**, the **manuscript backbone narrative** is **`CORRECTED_CANONICAL_OLD_ANALYSIS`**, not **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**.

2. **Technical namespaces** in the engineering map still include `OLD_FULL_SCALING`, `OLD_BARRIER_PT`, `OLD_RESIDUAL_DECOMP`, `CANON_GEN`, `REPLAY_PHI1_KAPPA1`, `CANON_COLLAPSE_FAMILY`, `PHI2_KAPPA2_HYBRID`, `CANON_FIGURE_REPLAY`, `DIAGNOSTIC_FORENSIC` — see sections below. **Governance labels** (`CORRECTED_CANONICAL_OLD_ANALYSIS`, `CANON_GEN_SOURCE`, …) **map** onto these (see `tables/switching_analysis_namespace_clean_map.csv` column `narrative_contract_role`).

3. **Canonical source of `switching_canonical_S_long.csv`:** still produced only by **`Switching/analysis/run_switching_canonical.m`** — cite as **`CANON_GEN_SOURCE`** for **`S`**, and as **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** for the **PT/CDF columns** in that file under this contract.

4. **Replay / decomposition / figure-only:** unchanged technical descriptions; **manuscript** emphasis shifts to **corrected old-centered replay** (`CORRECTED_CANONICAL_OLD_ANALYSIS`) for **Phi–kappa / collapse** claims.

5. **Safe for manuscript (under contract):** **`CORRECTED_CANONICAL_OLD_ANALYSIS`** evidence + **`CANON_GEN_SOURCE`** for **`S`** provenance — see **`tables/switching_allowed_evidence_by_use_case.csv`** and boundary **B09** in `tables/switching_analysis_claim_boundary_map.csv`.

6. **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`:** allowed for **diagnostics**, audits, and supplementary figures — **not** as **main backbone** without a new decision.

7. **Legacy template:** **`LEGACY_OLD_TEMPLATE`** / **`OLD_*`** — historical unless replayed into **`CORRECTED_CANONICAL_OLD_ANALYSIS`**.

---

## Namespace reference (main definitions)

Machine-readable superset row: `tables/switching_analysis_namespace_clean_map.csv`.  
Confusion mitigations: `tables/switching_analysis_confusion_risks.csv`.  
Claim boundaries: `tables/switching_analysis_claim_boundary_map.csv`.

### OLD_FULL_SCALING

| Field | Content |
|-------|---------|
| **Purpose** | Shift-and-scale **collapse quality** and export **per-T scaling parameters** (not `switching_canonical_S_long`). |
| **Main scripts** | `Switching/analysis/switching_full_scaling_collapse.m` |
| **Primary inputs** | Alignment samples + observables from an alignment run. |
| **Primary outputs** | `switching_full_scaling_parameters.csv`, metrics, collapse figures. |
| **Backbone object** | **Scaled curve family** `S/S_peak` vs `(I-I_peak)/width` — **not** the subtractive `S_model_pt` column. |
| **Residual / SVD** | **None** in this script (no subtract-then-SVD pipeline here). |
| **Coordinate / grid** | **`x = (I-I_peak)/width`** for collapse display. |
| **`I_peak` / width** | **Construction of collapse object** (scaling), not CDF row construction. |
| **`dS/dI`** | **Not** the defining relation for this backbone (normalized `S` shape / collapse). |
| **Claim status** | **Historical / template** for legacy collapse narrative and parameters. |
| **Safe uses** | Citing **collapse metrics** and **exported widths/peaks** with **`OLD_FULL_SCALING`**. |
| **Unsafe uses** | Calling this “the canonical PT/CDF backbone” or equating to **`CANON_GEN`** `S_model_pt_percent` without a bridge. |

### OLD_BARRIER_PT

| Field | Content |
|-------|---------|
| **Purpose** | Build **`PT_matrix.csv`** and per-row **`P_T` / `CDF_recon`** from saved **`S(I,T)`** maps. |
| **Main scripts** | `analysis/switching_barrier_distribution_from_map.m` |
| **Primary inputs** | Alignment core `.mat` or samples. |
| **Primary outputs** | `PT_matrix.csv`, `PT_summary.csv`, figures, report. |
| **Backbone object** | **`P_T`** density + **`CDF_recon`** (per-temperature on `I`). |
| **Residual / SVD** | **None** in this script. |
| **Coordinate / grid** | **Native `I`**. |
| **`I_peak` / width** | **Neither** enters the documented `reconstructBarrierDistribution` construction loop. |
| **`dS/dI`** | **`gradient` of processed** (min–max, smoothed, optionally monotone) **row curve** — **not** raw physical `dS/dI` on `S`. |
| **Claim status** | **Historical pipeline** input to **`OLD_RESIDUAL_DECOMP`** when `PT_matrix` is used. |
| **Safe uses** | Explaining **old** `PT_matrix` provenance; variant comparisons **inside `OLD_BARRIER_PT`**. |
| **Unsafe uses** | Asserting **identity** with **`CANON_GEN`** `PT_pdf` without an equivalence audit. |

### OLD_RESIDUAL_DECOMP

| Field | Content |
|-------|---------|
| **Purpose** | **`S(I,T) ≈ Speak*CDF + kappa*Phi(x)`** with **`x=(I-I_peak)/width`** on a common **`xGrid`** (legacy). |
| **Main scripts** | `Switching/analysis/switching_residual_decomposition_analysis.m` (function) |
| **Primary inputs** | Alignment **`Smap`**, `switching_full_scaling_parameters.csv`, optional **`PT_matrix.csv`**. |
| **Primary outputs** | `phi_shape.csv`, `kappa_vs_T.csv`, quality tables, run report. |
| **Backbone object** | **`Scdf = Speak .* cdfRow`**. |
| **Residual / SVD** | **`deltaS = Smap - Scdf`** → interpolate to **`Rlow`** → **`svd(R0)`** for `Phi`. |
| **Coordinate / grid** | **`x = (I-I_peak)/width`** for **residual** SVD (not for `cdfRow` construction). |
| **`I_peak` / width** | **Not inside `cdfFromPT` / `cdfFallback`**; **yes** for **`x`** and **`Speak`**. |
| **`dS/dI`** | **PT path:** nonnegative density from **`PT_matrix`**; **fallback:** `gradient` on normalized/smoothed row — **not** “raw `dS/dI` = `PT_pdf`” globally. |
| **Claim status** | **Historical / template** decomposition; still invoked by **`PHI2_KAPPA2_HYBRID`**. |
| **Safe uses** | Legacy reproduction; **explicit** `OLD_RESIDUAL_DECOMP` labeling. |
| **Unsafe uses** | Equating **`Phi`/`kappa`** to **`CANON_GEN`** **`phi1`/`kappa1`** without proof. |

### CANON_GEN (split under narrative contract)

Same **producer script**; **two governance namespaces** attach to different columns/claims:

| Governance `namespace_id` | What it covers | Claim status under contract |
|---------------------------|----------------|----------------------------|
| **`CANON_GEN_SOURCE`** | **`S_percent`**, **`current_mA`**, **`T_K`**, channel identity, **`switching_canonical_observables.csv`** fields tied to **`S`**, and **`residual_percent`** as stored relative to the producer’s first-stage map. | **Authoritative `S` data** for manuscript when run id + sidecars are cited. |
| **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** | **`S_model_pt_percent`**, **`CDF_pt`**, **`PT_pdf`**, in-script **`Scdf`**, and **`phi1`/`kappa1`** from **`svd(Rfill)`** on **native `I`**. | **Diagnostic / source-layer** — **not** the selected **main manuscript backbone** (see decision record). |

| Field | Content |
|-------|---------|
| **Purpose** | **Produce** `switching_canonical_S_long.csv`, observables, **`phi1`** from **raw** legacy ingestion (`processFilesSwitching` path). |
| **Main scripts** | `Switching/analysis/run_switching_canonical.m` |
| **Primary inputs** | Raw **Temp Dep** folders via **`Switching_main.m`** `parentDir`. |
| **Primary outputs** | `switching_canonical_S_long.csv`, `switching_canonical_observables.csv`, `switching_canonical_phi1.csv`, run-scoped tables/reports. |
| **Backbone object (technical)** | **`S_model_pt_percent`**, **`CDF_pt`**, **`PT_pdf`** (`Scdf` in-script) — narratively **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**. |
| **Residual / SVD** | **`Smap - Scdf`** → **`svd(Rfill)`** on **native `I`** — narratively **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** (first mode construction). |
| **Coordinate / grid** | **Native `current_mA`**. |
| **`I_peak` / width** | **`I_peak`** for **observables export**; **not** in **CDF/PT** construction loop per simple-map trace. |
| **`dS/dI`** | **`PT_pdf` = `gradient` of repaired `S/S_peak` quasi-CDF** (nonnegative, area-normalized) — **not** raw `dS/dI`. |
| **Safe uses** | **`S` claims:** cite **`CANON_GEN_SOURCE`**. **PT/CDF column claims:** cite **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** and **do not** present as main manuscript backbone under this contract. |
| **Unsafe uses** | Calling **`PT_pdf`/`CDF_pt`** the **selected manuscript backbone** without **`CORRECTED_CANONICAL_OLD_ANALYSIS`**; citing **`CANON_GEN`** without **run directory** + **which sub-namespace** (`SOURCE` vs `EXPERIMENTAL`). |

### REPLAY_PHI1_KAPPA1

| Field | Content |
|-------|---------|
| **Purpose** | **Replay** rank-one residual structure and observables on **latest resolved** canonical **`S_long`**. |
| **Main scripts** | `Switching/analysis/run_switching_phi1_kappa1_experimental_replay.m` |
| **Primary inputs** | `switching_canonical_S_long.csv`, observables, mode amplitudes. |
| **Primary outputs** | Replay figures, `switching_phi1_kappa1_experimental_replay_status.csv`, reports. |
| **Backbone object** | **`Scdf`** from **aggregated `S_model_pt_percent`** (read, not rebuilt from raw here). |
| **Residual / SVD** | **`R = Smap - Scdf`**, **`svd(Rfill)`**, **native `I`**. |
| **`I_peak` / width** | **Partial:** **`I_peak`** for **proxy plots**, not CDF construction in this script. |
| **`dS/dI`** | **Inherited** column semantics from **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** (columns in **`CANON_GEN`** output) for the residual — **no new PT recipe**. |
| **Claim status** | **Canonical replay evidence** (B03) — diagnostic, not a new producer. |
| **Safe uses** | “On **frozen `CANON_GEN_SOURCE` tables**, replay shows …” (cite run id). |
| **Unsafe uses** | Presenting replay as **redefining** backbone or **new** physics reconstruction. |

### CANON_COLLAPSE_FAMILY

| Field | Content |
|-------|---------|
| **Purpose** | **Hierarchy** (`pred0`, `pred1`, `pred2`), RMSE/dominance tables, **collapse / overlay figures** on **gated** canonical inputs. |
| **Main scripts** | `run_switching_canonical_collapse_hierarchy.m`, `run_switching_canonical_collapse_visualization.m`, `run_switching_canonical_ptcdf_collapse_overlay.m` |
| **Primary inputs** | `switching_canonical_S_long.csv`, `switching_canonical_phi1.csv`, `switching_mode_amplitudes_vs_T.csv`, rank tables as required by hierarchy script. |
| **Primary outputs** | `switching_canonical_collapse_hierarchy_*.csv`, figures, overlay status CSVs. |
| **Backbone object** | **`pred0 = Bmap`** from **`S_model_pt_percent`**. |
| **Residual / SVD** | **`R1 = Smap - pred1`**, **`svd(R1z)`** for **phi2** (native **`I`**); **CDF_pt** as **plot x-axis** in overlay only. |
| **`I_peak` / width** | **Not** in backbone column read; **CDF_pt** is **plotting coordinate** in overlay. |
| **`dS/dI`** | **No new definition** — reads **`PT_pdf`/`CDF_pt`** columns (**`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**) from **`CANON_GEN`**-producer **`S_long`**. |
| **Claim status** | **Canonical-derived** (B02) when **`CANON_GEN_SOURCE`** run is cited for **`S`** and **`EXPERIMENTAL`** for PT columns. |
| **Safe uses** | Hierarchy / overlay figures **with** **`CANON_GEN_SOURCE` + `EXPERIMENTAL_PTCDF_DIAGNOSTIC` + `CANON_COLLAPSE_FAMILY`** labeling. |
| **Unsafe uses** | Treating overlay **x-axis** choice as **independent** PT construction. |

### PHI2_KAPPA2_HYBRID

| Field | Content |
|-------|---------|
| **Purpose** | Call **`OLD_RESIDUAL_DECOMP`**, then **extra `svd`** on aligned **`x`** for mode-2 diagnostics. |
| **Main scripts** | `Switching/analysis/run_phi2_kappa2_canonical_residual_mode.m` |
| **Primary inputs** | Hardcoded legacy run ids passed into **`switching_residual_decomposition_analysis`**. |
| **Primary outputs** | `phi2_*` tables under `tables/`, status text. |
| **Backbone object** | **First stage** **`Scdf`** from **`OLD_RESIDUAL_DECOMP`** — **not** from **`CANON_GEN`** columns. |
| **Residual / SVD** | Legacy **`deltaS`/`Rall`**, then **`svd(M)`** on **`x_grid`**. |
| **`I_peak` / width** | **Yes** for **legacy `x` grid** (via decomposition). |
| **`dS/dI`** | **Same as `OLD_RESIDUAL_DECOMP`** first stage. |
| **Claim status** | **Not safe for manuscript as “canonical”** without revalidation (B07). |
| **Safe uses** | Internal diagnostic with **explicit** **`PHI2_KAPPA2_HYBRID` + `OLD_RESIDUAL_DECOMP`** caption. |
| **Unsafe uses** | **“Canonical”** wording based on **filename only**. |

### CANON_FIGURE_REPLAY

| Field | Content |
|-------|---------|
| **Purpose** | **Regenerate figures** or **fix layout** from **existing** CSV/fig inputs — **not** a new `S_long` producer. |
| **Main scripts** | Examples: `scripts/run_switching_stabilized_gauge_figure_replay.m`, `scripts/tmp_run_switching_canonical_paper_figures.m`, `run_switching_canonical_map_visualization.m`, `run_switching_canonical_first_figure_anchor.m` (each script may differ; see inventory). |
| **Primary inputs** | Resolved **`S_long`** paths, observables, figures as each script documents. |
| **Primary outputs** | Figures, status CSV, anchor outputs. |
| **Backbone object** | **Read-only** display of **`S_model_pt`** / observables unless script explicitly recomputes (most are **read/plot**). |
| **Residual / SVD** | **Usually none**; map scripts may show **`S - S_model_pt`** without claiming new decomposition. |
| **Coordinate / grid** | Often **Temperature vs normalized observables** (`X_eff`-style gauges) — **not** “`X_canon`” by default. |
| **`I_peak` / width** | **Plotting / gauge** context per script. |
| **`dS/dI`** | **N/A** unless a script explicitly recomputes derivatives (rare in this class). |
| **Claim status** | **Figure / layout evidence** (B05). |
| **Safe uses** | “**Figure replay** from run **X** under **`CANON_FIGURE_REPLAY`**.” |
| **Unsafe uses** | Claiming **new backbone validation** from replay alone. |

### DIAGNOSTIC_FORENSIC

| Field | Content |
|-------|---------|
| **Purpose** | **Audits**, **forensics**, **metadata**, **transition**, **residual-on-canonical-tables**, **parameter robustness on alignment**, **geocanon** descriptors — **supporting** evidence. |
| **Main scripts** | Examples: `scripts/run_switching_old_fig_forensic_and_canonical_replot.m`, `run_switching_backbone_validity_audit.m`, `run_switching_backbone_stress_test.m`, `run_switching_residual_mode_analysis.m`, `run_switching_collapse_breakdown_analysis.m`, `run_switching_canonical_metadata_sidecar_audit.m`, `run_switching_canonical_root_pipeline_isolation.m`, `run_parameter_robustness_switching_canonical.m`, `run_switching_geocanon_*.m` (see `switching_canonical_namespace_inventory.csv`). |
| **Primary inputs** | **`S_long`**, hierarchy CSVs, alignment samples, sidecars — **per script**. |
| **Primary outputs** | Audit tables, status CSV, MD reports, diagnostic figures. |
| **Backbone object** | **Reads** canonical or hierarchy columns for **checks**; **does not** replace the **manuscript narrative** defined under **`CORRECTED_CANONICAL_OLD_ANALYSIS`**. |
| **Residual / SVD** | **Varies** (e.g. **`RES_MODE`** does **`svd`** on **`Smap-Scdf`** from **`S_long`** on **native `I`**). |
| **Coordinate / grid** | **Per script** (native `I`, alignment grid, or audit-specific). |
| **`I_peak` / width** | **Where** the underlying diagnostic references scaling or observables. |
| **`dS/dI`** | **Only** as explicitly stated in each audit (e.g. monotonicity checks on **`CDF_pt`**). |
| **Claim status** | **Diagnostic / forensic** (B06, B08). |
| **Safe uses** | Gates, inventories, **supporting** paragraphs with **namespace + evidence class**. |
| **Unsafe uses** | Promoting audit CSVs to **primary manuscript claims** without **`CANON_GEN_SOURCE`** / **`CORRECTED_CANONICAL_OLD_ANALYSIS`** (or declared) upstream. |

---

## Claim-boundary map (summary)

Full table: **`tables/switching_analysis_claim_boundary_map.csv`**.

| boundary_id | label | manuscript note |
|-------------|-------|-------------------|
| B01 | Canonical **`S`** tables | **Safe** for **`S`** when run path + metadata + **`CANON_GEN_SOURCE`**. |
| B02 | Hierarchy on `S_long` | **Partial** — cite **`CANON_GEN_SOURCE`** for **`S`**; **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** for PT/CDF columns read from the file. |
| B03 | Replay on frozen `S_long` | **Partial** — supports **`CORRECTED_CANONICAL_OLD_ANALYSIS`** when dual-namespace caption present. |
| B04 | Legacy alignment / PT / collapse | **Not** interchangeable with **`CANON_GEN_SOURCE`** / **`EXPERIMENTAL`** without bridge; use **`LEGACY_OLD_TEMPLATE`** unless replayed. |
| B05 | Figure/layout only | **Safe** for reproduction claims only. |
| B06 | Audits / forensics | **Not** primary physics claims without framing. |
| B07 | **`PHI2_KAPPA2_HYBRID`** | **Not safe** as “canonical decomposition” without relabel/revalidation. |
| B08 | Geocanon descriptors | **Partial** — descriptor-only scope. |
| B09 | **Main manuscript** centered replay narrative | **Safe** when **`CORRECTED_CANONICAL_OLD_ANALYSIS`** + **`CANON_GEN_SOURCE`** provenance + explicit backbone **`namespace_id`**. |
| B10 | **`CANON_GEN`** PT/CDF columns | **Not** selected main backbone (`CANON_GEN_PTCDF_SELECTED_AS_MAIN_BACKBONE=NO`); use **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**. |
| B11 | Legacy templates | **Historical** unless replayed into **`CORRECTED_CANONICAL_OLD_ANALYSIS`**. |
| B12 | Side / parameter / geocanon | **Diagnostic** — not backbone equivalence without audit class. |

---

## Confusion-risk table (required rows)

| # | Risk | Mitigation |
|---|------|------------|
| R01 | There is no single Switching backbone. | Always state **`namespace_id`**. |
| R02 | Collapse is not necessarily subtractive backbone. | Separate **`OLD_FULL_SCALING`**, **`CANON_GEN_SOURCE`**, **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**, **`OLD_RESIDUAL_DECOMP`**. |
| R03 | “Canonical” does not mean one analysis. | Disambiguate **`CANON_GEN_SOURCE`** / **`EXPERIMENTAL`** / **`CORRECTED`** / **`CANON_COLLAPSE_FAMILY`** / **`CANON_FIGURE_REPLAY`**. |
| R04 | Producer writes **`S_long`**; other “canonical*” scripts may only consume or replay. | **`CANON_GEN_SOURCE`** for producer **`S`** claims; check inventory flags. |
| R05 | **`PT_pdf`** is not raw **`dS/dI`** unless validated in-namespace. | Declare **`relation_to_dS_dI`**; use **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**. |
| R06 | **`X_eff`** is not **`X_canon`**. | Label gauge / replay scripts; do not alias. |
| R07 | Figure replay is not new physics reconstruction. | Tag **`figure_only`** vs **`physics_analysis`**. |
| R08 | **`PHI2_KAPPA2_HYBRID`**: “canonical” in filename, **first stage = `OLD_RESIDUAL_DECOMP`**. | Always pair **`PHI2_KAPPA2_HYBRID` + `OLD_RESIDUAL_DECOMP`**. |
| R09–R14 | Undifferentiated **`CANON_GEN`**, wrong backbone narrative, legacy-as-proof, … | See **`tables/switching_analysis_confusion_risks.csv`**. |

(Machine copy: `tables/switching_analysis_confusion_risks.csv`.)

---

## Recommended future naming rules

1. **Every new** Switching script, report, and table **must declare `namespace_id`** in the header (or filename prefix `NS_<namespace_id>_` for tables).

2. **Every decomposition report** must state **`SVD_input = S - WHAT`** (symbolic) and the **`coordinate_grid`**.

3. **Every figure-only deliverable** must declare **`figure_only`** vs **`physics_analysis`**.

4. **Every PT/CDF report** must declare **`relation_to_dS_dI`** (e.g. “gradient of repaired quasi-CDF; not raw dS/dI”).

5. **Every old vs canonical comparison** must name **both** **`namespace_id`** values (e.g. `LEGACY_OLD_TEMPLATE` / `OLD_RESIDUAL_DECOMP` vs `CANON_GEN_SOURCE` / `CORRECTED_CANONICAL_OLD_ANALYSIS`).

### Folder / report naming conventions (non-destructive)

- **`reports/switching/<namespace_id>_<short_topic>.md`**
- **`tables/switching/<namespace_id>_<metric>.csv`**
- **Run labels** already carry semantics; prefer explicit ids: `..._on_CANON_GEN_SOURCE_<run_id_short>_...` for **`S`**, or `..._EXPERIMENTAL_PTCDF_...` when the claim is about PT/CDF columns only.

---

## Quarantine / deprecation candidates (do **not** delete now)

These are **documentation-level “handle with care”** flags — **no file removal** in this task.

| Item | Reason |
|------|--------|
| `Switching/analysis/run_phi2_kappa2_canonical_residual_mode.m` | Filename **`canonical`** conflicts with **`OLD_RESIDUAL_DECOMP`** first stage — **quarantine for manuscript** until relabeled or revalidated. |
| `scripts/tmp_run_switching_canonical_paper_figures.m` | **`tmp_`** prefix — treat as **non-contract** figure scratch. |
| Scripts with **hardcoded** absolute or fixed **`run_...`** paths to `S_long` | **Fragile** for portability; prefer **`switchingResolveLatestCanonicalTable`** or explicit run-id parameter + sidecar. |
| `Switching/analysis/run_minimal_canonical.m` | **`canonical`** in name but **not** Switching **`S_long`** — risk of **grep false positives**. |
| `Switching/analysis/run_parameter_robustness_switching_canonical.m` | **`canonical`** in name; inputs are **alignment** samples — **not** the **`run_switching_canonical.m`** **`CANON_GEN_SOURCE`** producer chain. |

---

## Status

- **Narrative governance verdicts:** `tables/switching_main_narrative_namespace_decision.csv`, `tables/switching_main_narrative_namespace_status.csv`, `tables/switching_namespace_governance_status.csv`.  
- **Reports:** `reports/switching_main_narrative_namespace_decision.md`, `reports/switching_namespace_governance.md`.  
- **Organization map (earlier task):** `tables/switching_analysis_organization_status.csv`.
