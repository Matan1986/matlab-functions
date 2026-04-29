# Switching semantic synthesis and rename plan — Phase 1.5D

**Naming and meaning layer only.** No file renames executed; no edits to analysis code; no MATLAB; no git staging or commits.

## Opening checks

| Check | Result |
|--------|--------|
| `git log -1` | `17dea24` — *Add Switching pre-replay contract reset design* |
| `git diff --cached --name-only` | **Empty** (nothing staged at audit start) |

## Input artifacts reconciled

Phase **1.5A** (`tables/switching_semantic_family_discovery_core_analysis.csv`, report), **1.5B** (`tables/switching_semantic_family_discovery_governance.csv`, report), **1.5C** (`tables/switching_semantic_family_discovery_replay_diagnostics.csv`, report), plus **`docs/switching_pre_replay_contract_reset.md`**, **`tables/switching_pre_replay_namespace_contract.csv`**, **`tables/switching_pre_replay_registry_contract.csv`**, **`docs/switching_analysis_map.md`**, **`tables/switching_analysis_namespace_clean_map.csv`**, **`tables/switching_analysis_classification_status.csv`** (interpret with **`CURRENT_*`** / supersession), **`reports/switching_stale_governance_supersession.md`**.

## 1. Unified semantic taxonomy (summary)

Stable **`semantic_family_id`** values are defined in **`tables/switching_semantic_taxonomy.csv`**. Operation-based names replace informal “canonical” where possible.

### Merge vs split decisions

| Decision | Justification |
|----------|----------------|
| **Keep CANON_GEN_SOURCE and EXPERIMENTAL_PTCDF_DIAGNOSTIC separate from CANON_GEN_MIXED_PRODUCER** | The mixed producer **process** (`run_switching_canonical.m`) is one **entrypoint**; **outputs** belong to **column/object-level** families. Registry rows must not treat the run as a single semantic bucket. |
| **Keep CORRECTED_OLD_AUTH_BUILDER distinct from CORRECTED_CANONICAL_OLD_ANALYSIS** | Builder is the **gated tool**; CORRECTED_CANONICAL_OLD_ANALYSIS is the **governance namespace / manuscript pathway** when authoritative artifacts + citations exist. |
| **Keep OLD_RESIDUAL_DECOMP distinct from CORRECTED_* and from PHI2_KAPPA2_HYBRID** | Different backbone formulas, grids, and authority tiers; merging would violate artifact-policy family separation. |
| **Keep GEOCANON_DESCRIPTOR separate from residual/CDF families** | Ridge geometry **descriptors** must not be read as subtractive CDF backbone physics (`docs/switching_artifact_policy.md`). |
| **Fold replay/visualization helpers into typed families** | e.g. CANON_S_LONG_VISUAL_REPLAY, OLD_FIG_FORENSIC_REPLAY, GAUGE_VISUALIZATION_DIAGNOSTIC, PTCDF_DIAGNOSTIC_QUARANTINE_REPLAY — **do not** promote to CANON_GEN_SOURCE. |

### Minimum reconciliation table (user-requested labels → taxonomy ids)

| Historical / governance label | semantic_family_id |
|------------------------------|-------------------|
| CANON_GEN_SOURCE | CANON_GEN_SOURCE |
| EXPERIMENTAL_PTCDF_DIAGNOSTIC | EXPERIMENTAL_PTCDF_DIAGNOSTIC |
| CANON_GEN_MIXED_PRODUCER | CANON_GEN_MIXED_PRODUCER |
| OLD_RESIDUAL_DECOMP | OLD_RESIDUAL_DECOMP |
| CORRECTED_OLD_AUTH_BUILDER | CORRECTED_OLD_AUTH_BUILDER |
| CORRECTED_CANONICAL_OLD_ANALYSIS | CORRECTED_CANONICAL_OLD_ANALYSIS |
| PHI2_KAPPA2_HYBRID | PHI2_KAPPA2_HYBRID |
| REPLAY_PHI1_KAPPA1 | REPLAY_PHI1_KAPPA1 |
| GEOCANON_DESCRIPTOR | GEOCANON_DESCRIPTOR |
| CANON_S_LONG_VISUAL_REPLAY | CANON_S_LONG_VISUAL_REPLAY |
| OLD_FIG_FORENSIC_REPLAY | OLD_FIG_FORENSIC_REPLAY |
| GAUGE_VISUALIZATION_DIAGNOSTIC | GAUGE_VISUALIZATION_DIAGNOSTIC |
| OLD_X_REPLAY_OR_ROBUSTNESS | OLD_X_REPLAY_OR_ROBUSTNESS |
| CDF_BACKBONE_REPAIR_AGGRESSIVENESS_AUDIT | CDF_BACKBONE_REPAIR_AGGRESSIVENESS_AUDIT |
| INFRA_SMOKE_CANONICAL_CONTEXT | INFRA_SMOKE_CANONICAL_CONTEXT |
| CLASSIFICATION_OR_GOVERNANCE_STATUS | CLASSIFICATION_OR_GOVERNANCE_STATUS |

Extended rows (core analysis / replay): **CANON_FIGURE_COLUMN_REPLAY**, **CANON_COLLAPSE_PTCDF_OVERLAY_DIAGNOSTIC**, **PTCDF_DIAGNOSTIC_QUARANTINE_REPLAY**, **CORRECTED_OLD_REPLAY_FROM_CANON_S_INPUT**, **GOVERNANCE_DOC_AND_PLANNING**, **CORRECTED_OLD_TASK_QA_DIAGNOSTIC**, **RANK3_STAGE_CHAIN_CLASSIFICATION_AUDIT**, **PHI_KAPPA_STABILITY_CANONICAL_SUBSET**.

## 2. Stable aliases (per family)

Each family row includes **`recommended_alias`**, **`plain_english_meaning`** (in CSV), **`allowed_use` / `forbidden_use`**, **`claim_level`**, **`manuscript_safe`**, **`replay_safe`**, **`canonical_safe`** (interpreted as safe use of **CANON_GEN_SOURCE / governance canonical** claims — **not** “anything named canonical”), **`required_namespace_fields`**, **`required_lineage_fields`**, **`evidence_paths`**. See **`tables/switching_semantic_taxonomy.csv`**.

Cross-reference: **`tables/switching_semantic_alias_map.csv`** maps **current names, paths, and prose terms** to **`semantic_family_id`** and safe replacement phrases.

## 3. Forbidden ambiguous terms

**`tables/switching_semantic_forbidden_terms.csv`** lists bare phrases (*canonical backbone*, *canonical Phi/kappa*, *corrected-old*, *paper figures*, *X_canon*, *collapse_canon*, *Phi_canon*, *kappa_canon*, *geocanon as residual canon*, *PTCDF as corrected-old authority*, etc.) with **severity**, **required qualification**, and **safe replacement** language.

## 4. Rename recommendation plan (not executed)

**`tables/switching_semantic_rename_plan.csv`** classifies candidates into **`NO_RENAME`**, **`ALIAS_ONLY`**, **`HEADER_WARNING_ONLY`** (via **`header_warning_needed`**), **`RENAME_LATER_LOW|MEDIUM|HIGH`**, **`URGENT_FILENAME_BODY_MISMATCH_REVIEW`**.

**Special rows**

| Asset | Classification |
|-------|----------------|
| **`scripts/run_sw_old_inv_phi1_viz.m`** | **`URGENT_FILENAME_BODY_MISMATCH_REVIEW`** — Phase 1.5C static inspection indicates **duplicate body** vs **`run_switching_corrected_old_replay_inventory_and_phi1_visual_sanity.m`**. Manual reconcile; **not** automatic deletion. |
| **`run_phi2_kappa2_canonical_residual_mode.m`** | **`RENAME_LATER_HIGH`** + header already warns; registry REG004 notes conflict. |
| **`run_minimal_canonical.m`** | **`RENAME_LATER_MEDIUM`** — **INFRA_SMOKE_CANONICAL_CONTEXT**, not physics canonical. |
| **`run_switching_canonical.m`** | **`NO_RENAME`** now + **mandatory column-level Phase 2 registry**; optional distant rename only after alias adoption. |

**`rename_now`** is **NO** for all rows in this plan.

## 5. Pre–Phase 2 contract materialization guidance

1. **Registry rows** must include **`semantic_family_id`** and **`recommended_alias`** from **`tables/switching_semantic_taxonomy.csv`** / **`tables/switching_semantic_alias_map.csv`**. Do **not** register outputs using bare *old*, *canonical*, or *corrected-old* without **`namespace_id`** and lineage.

2. **Mixed producers** (especially **`CANON_GEN_MIXED_PRODUCER` / `switching_canonical_S_long.csv`**) must be represented at **output object and column** granularity per **`reports/switching_canonical_S_long_column_namespace.md`** and **REG001** style splits — not one row per run file.

3. **Stale classification keys** (e.g. `AUTHORITATIVE_CORRECTED_OLD_ARTIFACTS_EXIST=NO`) remain **historical**; **current** interpretation uses **`CURRENT_*`** rows and **`reports/switching_stale_governance_supersession.md`**.

4. **EXPERIMENTAL_PTCDF_DIAGNOSTIC** outputs stay **quarantined** from **CORRECTED_CANONICAL_OLD_ANALYSIS** backbone claims — **no** weakening of PT/CDF fence.

5. **Replay scripts** (figure replay, visual replay, PS1 audits) **must not** be promoted to **CANON_GEN_SOURCE** or authoritative corrected-old evidence without **artifact index + gates**.

6. **Broad old-analysis replay** remains **NO-GO** for unattended execution until Phase 2 contracts materialize (`docs/switching_pre_replay_contract_reset.md` principles).

## Deliverables (Phase 1.5D)

| File | Role |
|------|------|
| `tables/switching_semantic_taxonomy.csv` | Authoritative family definitions |
| `tables/switching_semantic_alias_map.csv` | Term → family → safe replacement |
| `tables/switching_semantic_forbidden_terms.csv` | Ambiguous phrase guardrails |
| `tables/switching_semantic_rename_plan.csv` | Rename / alias / urgent review classes |
| `tables/switching_semantic_synthesis_status.csv` | Gate keys |
| `reports/switching_semantic_synthesis_and_rename_plan.md` | This narrative |

## Status snapshot

See **`tables/switching_semantic_synthesis_status.csv`**. **`RENAME_EXECUTION_RECOMMENDED_NOW=NO`**. **`SAFE_TO_PROCEED_TO_PHASE2_CONTRACT_MATERIALIZATION=YES`**. **`SAFE_TO_PROCEED_TO_OLD_ANALYSIS_REPLAY=NO`** (broad unattended replay).

---

*Phase 1.5D synthesis complete. Read-only; no repository mutations beyond these deliverable files.*
