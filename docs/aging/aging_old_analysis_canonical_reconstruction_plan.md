# Aging old-analysis canonical reconstruction plan (F7B0)

**Status:** Planning and documentation only (no reconstruction implemented in this task).  
**Scope:** Aging module only.  
**Baseline:** Aligns with `docs/analysis_module_reconstruction_and_canonicalization.md` and committed Aging contracts listed in the F7B0 task brief.

**Non-goals:** This document does not patch writers, run analysis, or promote any artifact. Legacy CSVs and old plots remain **evidence**, not canonical inputs, until gates below are satisfied.

---

## Four-way distinction (normative)

| Mode | Meaning | Canonical? |
|------|---------|------------|
| **`legacy_old_analysis`** | Historic scripts, outputs, figures, tables produced before lineage contracts | **No** — evidence / forensic input only |
| **`lineage_replay`** | Rerun or re-materialize prior logic with explicit sidecars, registry ids, and run identity | **No** automatically — may be `diagnostic_only` or `analysis_ready` **only if** metadata supports it |
| **`canonical_reconstruction`** | Reimplement scientific intent on **resolved**, lineage-safe observables and documented conventions | **Candidate only** after governance — outputs may become `canonical_candidate` pending promotion |
| **`canonical_claim`** | Statement that an artifact or conclusion is canonical | **Only** after promotion criteria and validators/readiness gates pass |

Legacy outputs must never be treated as canonical evidence solely because they exist or reproduce numerically.

---

## 1. Old-analysis inventory scope

The following **Aging analysis families** require reconstruction planning. This list is **not claimed complete** without a dedicated repo-wide inventory pass (file discovery, `results_old`, root runners, and `Aging/analysis` audit).

| Family | Examples / anchors | Notes |
|--------|-------------------|--------|
| Structured export / summary observable datasets | `aging_structured_results_export`, consolidated observables | Wide matrices; ambiguous column names without sidecars |
| Tau extraction | `aging_timescale_extraction`, tau vs `Tp` tables | Depends on dip/FM definitions feeding the extraction |
| Clock ratio / `R_tau_FM_over_Dip` | `aging_clock_ratio_analysis`, `aging_clock_ratio_temperature_scaling` | Requires matched numerator/denominator identities |
| Consolidation / pooled tables | Cross-run merges, pooling scripts | High risk without per-row identity |
| Track A replay | Track A diagnostics and replay runners | Must not inherit legacy identity by filename alone |
| FM lineage / signed FM | `FM_step_mag`, `FM_abs`, sign convention docs | Signed vs abs paths must be explicit in sidecar |
| Map-native Q006 outputs | Q006 map/matrix exports | Native-grid artifacts need observable mapping per contract |
| Diagnostic audit outputs | Contract validators, F6* audit runners | Validator **logs** are routing/metadata — not physics |
| Root `run_aging_F6*.m` runners | e.g. `run_aging_F6b_*`, `run_aging_F6c_*`, `run_aging_F6d_*`, `run_aging_F6e_*`, `run_aging_F6J_*`, etc. | Orchestration only; identity comes from writers + sidecars |

**Inventory verification:** Until `tables/aging/aging_F6Z_*.csv` (or a successor inventory) is present and cross-checked against disk, treat this scope as **defined for planning**, not **closed**.

---

## 2. Reconstruction targets

| Target class | Definition | Evidence required before promotion |
|--------------|------------|-----------------------------------|
| **Preserve as evidence** | Keep legacy files unchanged; cite for history or debugging | Provenance label (`legacy_old_analysis`); no model-ready use |
| **Replay with lineage** | Same or parity-seeking logic with F7A-style sidecars and explicit identities | Sidecar + manifest; `validation_mode` documented; unresolved fields explicit |
| **Reconstruct canonically** | Rebuild analysis on resolved observables and contracts | Registry-backed ids; sign/units; source runs; validator clean for intended tier |
| **Retire / quarantine** | Deprecate misleading or duplicate paths | Written rationale; replacement target; quarantine flags in status artifacts |

Promotion beyond `diagnostic_only` always requires explicit **observable identity** and **writer lineage**, not filename or path alone.

---

## 3. Observable identity gates

**Plain `Dip_depth`:** Never accepted as **model-ready** input. Allowed only under `audit_only` / evidence labeling with **WARNING** and explicit unresolved lineage (see `aging_writer_output_contract.md`, F7A helper).

**Resolved dip constructions (examples — gate by registry row + sidecar, not by string alone):**

| Semantic / construct | Gate |
|---------------------|------|
| `Dip_depth_afm_amp_residual_height` | Registry id + namespace + column bridge; preprocessing/scalarization ids in sidecar |
| `Dip_depth_raw_deltam_window_max_noncanonical` | Labeled **noncanonical** in metadata; `model_readiness` capped; authoritative flags documented |
| `Dip_depth_unresolved` | Must remain **unresolved** until bridge to S4A/S4B or equivalent |
| `AFM_like` / `FM_like` | Unit and convention fields set; not interchanged without sidecar note |
| `tau_Dip_<resolved_Dip_definition>` | Dip identity resolved; extraction recipe id; source table identity |
| `tau_FM_<resolved_FM_definition>` | FM convention (signed step vs abs) explicit; registry linkage |
| `R_tau_FM_over_Dip_<num>_over_<den>` | **Numerator** and **denominator** observable identities; matched `Tp`/pairing rules; no merge by `Tp` alone |

**Misleading names:** `tau_dip_canonical` and similar require **`authoritative_flag_field`** (or equivalent) resolution per `aging_unsafe_terms_and_alias_policy.md` — never infer canonicality from the substring “canonical” in a column name.

---

## 4. Lineage sidecar prerequisites

Reconstruction must not proceed to **model-ready** or **canonical_candidate** until writer outputs emit sidecars. Minimum writer families:

| Writer family | Role |
|---------------|------|
| `WO_STRUCTURED_EXPORT` | Wide observables / matrices |
| `WO_TAU_EXTRACTION` | Tau tables |
| `WO_CLOCK_RATIO` | Scalar aging ratio `R_age` family (not Relaxation `R_relax`) |
| `WO_CONSOLIDATION` | Pooled / merged tables |

**Mechanism:** Use `docs/aging/aging_lineage_sidecar_helper_usage.md` and `Aging/utils/aging_lineage_sidecar_utils.m` as the **intended** uniform API — **future** writer patches apply here; F7B0 does not patch writers.

---

## 5. Canonical promotion criteria (no automatic promotion)

Align labels with `docs/aging/aging_model_readiness_taxonomy_draft.md` and `aging_canonical_promotion_rules_draft.md` (draft tables where committed).

| Label | Gates (summary) |
|-------|-------------------|
| `analysis_ready` | Repeatable cohort; identities bounded; sidecars present; audit validator acceptable |
| `model_candidate` | Explicit caveats; identities resolved for **pilot** scope; no plain `Dip_depth` as model input |
| `model_ready` | Registry-resolution; conventions locked; inputs not legacy-primary |
| `canonical_candidate` | Parity/review staging; consolidation rules satisfied |
| `canonical` | Registry ratified; promotion rules executed; no reliance on legacy CSV as sole proof |

**Automatic promotion is forbidden** at every tier (helpers, validators, filenames).

---

## 6. Replay vs reconstruction rule

- **Replay** may reproduce historic logic and seek **numerical parity** for diagnosis.
- **Reconstruction** may restate the **scientific question** on **resolved** observables even when parity with legacy fails.
- **Exact parity** is **diagnostic**, not a mandatory requirement for truth or canonical status.
- **Parity failure** does not automatically invalidate a reconstruction (identity or convention drift may explain it).
- **Parity success** does **not** prove canonical status — only governance and identity completeness can.

---

## 7. Tau/R reconstruction plan

**Objective:** Safe reconstruction of `tau_Dip`, `tau_FM`, and `R = tau_FM / tau_Dip` (scalar aging ratio; use `R_age` naming discipline vs Relaxation).

For each tau or ratio table:

1. **Numerator identity:** Registry-backed definition for FM-derived tau (if applicable).
2. **Denominator identity:** Registry-backed dip-derived tau (if applicable) — must not be plain `Dip_depth` without resolution.
3. **Source run identity:** `source_run_id`, dataset/build ids tying tau table to structured export build.
4. **Sign convention:** Especially FM paths; document left/right or abs envelope per contract.
5. **Unit status:** Seconds vs dimensionless; consistent column semantics.
6. **Diagnostic vs model-ready:** Default `diagnostic_only`; upgrade only with full identity + gates.
7. **`tau_dip_canonical` naming risk:** Treat as **unsafe** until `authoritative_flag_field` and registry semantics align; validators should WARN in `audit_only`.

Ratios must not be merged across runs or temperatures without **row-level** or **manifest-level** identity compatibility checks.

---

## 8. Forbidden shortcuts

- Using **plain `Dip_depth`** as a resolved model input.
- Using **`stage4_S4A` / `stage4_S4B`** as **primary** column names without bridge to registry semantic ids (sidecar must map).
- Using **legacy CSVs** as canonical inputs without sidecars and registry linkage.
- **Merging ratio tables by `Tp` only** without numerator/denominator identity and source-run match.
- Calling outputs **canonical** because of **filename, folder, or runner name**.
- Treating **validator logs** as physics measurements.
- **Cross-module** comparison (Switching/Relaxation/MT) before **Aging lineage** is stable for the compared artifacts.

---

## 9. Execution order (proposed)

Safe ordering — later steps assume earlier contracts exist:

1. Sidecar helper committed (F7A baseline).
2. Structured export sidecar patch (`WO_STRUCTURED_EXPORT`).
3. Tau extraction sidecar patch (`WO_TAU_EXTRACTION`).
4. Clock ratio sidecar patch (`WO_CLOCK_RATIO`).
5. Consolidation sidecar patch (`WO_CONSOLIDATION`).
6. Lineage validator rerun (audit or migration mode per policy).
7. Lineage replay of prioritized legacy outputs (evidence + parity diagnostics).
8. Canonical reconstruction **candidates** (resolved observables only).
9. Model-readiness audit.
10. Only then: model analysis depending on labels.

This order is **not** a single mandatory linear workflow; verify repository state before re-running (see global reconstruction playbook warning).

---

## 10. Review-stage visualization and figure exports

During **Aging reconstruction review** stages (replay diagnostics, parity checks, human review of lineage replay and canonical reconstruction candidates), figures must follow existing repository rules:

- `docs/visualization_rules.md`
- `docs/figure_style_guide.md`
- `docs/figure_export_infrastructure.md`

**Export requirement:** Deliver **PNG** and **MATLAB FIG** (`.fig`) for review-stage figures where the export infrastructure applies, so reviewers can re-open editable layouts and compare raster outputs consistently.

**Evidence role:** Figures are **diagnostic and review artifacts**. They support human judgment and audit trails; they are **not** standalone canonical evidence and do not replace tables, sidecars, or registry-backed identities.

**Prohibited:** Changing **data paths**, **scientific calculations**, or **analysis logic** solely to improve figure appearance. Cosmetic or layout adjustments must stay within visualization and export rules without altering numerical pipelines.

---

## 11. Stop conditions

Work must **pause** or **route to quarantine** when:

- **Unresolved plain `Dip_depth`** blocks model-ready claims for affected tau/R paths.
- **Missing sidecars** on artifacts proposed as model inputs.
- **Unknown numerator/denominator** identities for ratio use.
- **Misleading canonical naming** without authoritative flag linkage (`tau_dip_canonical` policy).
- **Cross-module comparison** attempted before Aging lineage is stable.
- **Unexpected staged files** or **commits** during planning-only tasks (process hygiene).
- **Modifications outside Aging** when task scope is Aging-only.
- **Visualization shortcut:** exporting review figures without PNG+FIG where required by export rules, or treating figures as sufficient proof of canonical status.

---

## References (committed baseline)

- `docs/aging/aging_namespace_contract.md`
- `docs/aging/aging_observable_registry_contract.md`
- `docs/aging/aging_writer_output_contract.md`
- `docs/aging/aging_lineage_sidecar_schema.md`
- `docs/aging/aging_contract_validation_rules.md`
- `docs/aging/aging_tau_R_lineage_naming_policy.md`
- `docs/aging/aging_unsafe_terms_and_alias_policy.md`
- `docs/aging/aging_lineage_sidecar_helper_usage.md`
- `docs/analysis_module_reconstruction_and_canonicalization.md`
- `docs/visualization_rules.md`
- `docs/figure_style_guide.md`
- `docs/figure_export_infrastructure.md`

Machine-readable extracts: `tables/aging/aging_F7B0_*.csv` (this deliverable).
