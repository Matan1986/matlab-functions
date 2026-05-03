# SW-CANON-SURVEY-D — Old Switching analysis vs canonical coverage audit

**Mode:** Read-only static inspection. **MATLAB / Python / Node:** not run. **Git:** no stage, commit, or push.  
**Pre-flight (per task brief):** `git diff --cached --name-only` was **empty** at audit time.  
**Execution rules context:** `docs/repo_execution_rules.md` (wrapper-only MATLAB policy) noted; this survey did not execute MATLAB.

**Date:** 2026-05-03  
**Scope:** Switching module documentation, governance tables, and **documented** old/corrected-old/replay paths. Undocumented local `results*` contents are **not** used as primary evidence.

---

## 1. Executive summary

The repository defines a **multi-namespace** Switching landscape (`docs/switching_analysis_map.md`). Under the **binding narrative contract** (`docs/decisions/switching_main_narrative_namespace_decision.md`), the **manuscript-facing** backbone is **`CORRECTED_CANONICAL_OLD_ANALYSIS`** (old centered collapse + residual decomposition on **`x = (I-I_peak)/w`**) **replayed on canonical `S`** from **`CANON_GEN_SOURCE`**, **not** the **`CANON_GEN`** PT/CDF column construction (**`EXPERIMENTAL_PTCDF_DIAGNOSTIC`**).

**Already reconstructed / gated:** Authoritative **corrected-old** tables (backbone map, residual map, Phi1, kappa1, mode1 reconstruction, residual-after-mode1, quality metrics), finite-grid audit package (TASK_001), quality closure + QA manifests (TASK_002A core), and builder gate **`ALL_REQUIRED_GATES_PASSED=YES`** (`tables/switching_corrected_old_authoritative_builder_status.csv`). Index: `tables/switching_corrected_old_authoritative_artifact_index.csv`.

**Planned / incomplete:** TASK_002B backbone parity bridge; authoritative **Phi2/kappa2** under corrected-old; TASK_002A visual QA **refinement** (pending user run); publication figure pipeline (TASK_009–TASK_012; gate **`SAFE_TO_CREATE_PUBLICATION_FIGURES=PARTIAL`**); WI/X gauge reconstruction (TASK_005) and downstream gauge atlas tasks.

**Blocked / fragile:** Legacy **`LEGACY_AX_FUNCTIONAL`** cross-module family is **`BLOCKED_MISSING_OUTPUTS`** in typical checkout (`docs/cross_module_switching_relaxation_AX_index.md`). **Non-authoritative** corrected-old PNGs remain **quarantined** (`reports/switching_quarantine_index.md`, `tables/switching_misleading_or_dangerous_artifacts.csv`).

**Intentionally not selected / diagnostic-only:** **`CANON_GEN`** PT/CDF + native-`I` **`phi1`/`kappa1`** from the mixed producer are **`DIAGNOSTIC_MODE_ANALYSIS`** / **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** for manuscript backbone — forbidden as **`CORRECTED_CANONICAL_OLD_ANALYSIS`** evidence per `docs/switching_governance_persistence_manifest.md`.

**Quarantined / manuscript-caution:** `PHI2_KAPPA2_HYBRID` (`run_phi2_kappa2_canonical_residual_mode.m`) — filename “canonical” vs **`OLD_RESIDUAL_DECOMP`** first stage; Phase **4B C02/C02B** panels are **QA/inspection**, not Phi1 definitions (`docs/switching_phi1_terminology_contract.md`).

---

## 2. Old-analysis component inventory (repo-named)

Sources: `docs/switching_analysis_map.md`, `tables/switching_corrected_old_authoritative_artifact_index.csv`, `tables/switching_missing_reconstruction_tasks_aligned.csv`, `docs/switching_governance_persistence_manifest.md`, `reports/switching_corrected_canonical_current_state.md`, `docs/cross_module_switching_relaxation_AX_index.md`.

| Component / family | Role |
|---------------------|------|
| **OLD_FULL_SCALING** | Legacy collapse scaling parameters (`switching_full_scaling_collapse.m`). |
| **OLD_BARRIER_PT** | Legacy **`PT_matrix`** / barrier distribution (`switching_barrier_distribution_from_map.m`). |
| **OLD_RESIDUAL_DECOMP** | Legacy **`Speak*CDF` + kappa*Phi(x)`** residual SVD on **`x`**. |
| **LEGACY_OLD_TEMPLATE** | Alignment-era **`OLD_*`** as originally run. |
| **CANON_GEN** (split) | Producer `run_switching_canonical.m` → **`CANON_GEN_SOURCE`** (`S`, identity) vs **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** (PT/CDF columns, native-`I` mode1). |
| **REPLAY_PHI1_KAPPA1** | Replay on frozen **`S_long`** (diagnostic, not new backbone). |
| **CANON_COLLAPSE_FAMILY** | Hierarchy / overlay on gated canonical inputs (B02 partial). |
| **PHI2_KAPPA2_HYBRID** | Legacy first stage + mode-2 SVD — not safe as “canonical” without revalidation. |
| **CANON_FIGURE_REPLAY** | Figure/layout regeneration from CSVs. |
| **DIAGNOSTIC_FORENSIC** | Audits, stress tests, metadata, residual-on-tables checks. |
| **CORRECTED_CANONICAL_OLD_ANALYSIS** | Gated authoritative corrected-old builder outputs. |
| **Cross-module AX / P0** | `X_eff`, scaling ladders, CM-SW-RLX-AX audits (index + durable reports/tables). |
| **Phase 4B C02/C02B** | Collapse QA panels (terminology contract). |

---

## 3. Coverage checklist (task question 7)

| Topic | Coverage in canonical / governance materials |
|-------|-----------------------------------------------|
| **Canonical S map generation** | **Yes** — `run_switching_canonical.m` + `switching_canonical_source_view.csv` pattern; cite **`CANON_GEN_SOURCE`**. |
| **Canonical decomposition (manuscript)** | **Partial** — manuscript decomposition is **`CORRECTED_CANONICAL_OLD_ANALYSIS`** tables, **not** mixed-producer **`phi1`/`kappa1`**. |
| **Phi/kappa analysis** | **Partial** — authoritative **Phi1/kappa1** under corrected-old; **Phi2/kappa2** authoritative row **`NOT_RECONSTRUCTED`** in artifact index. |
| **X_eff / effective observables** | **Partial** — locked effective observables cited as builder input; P0 **`tables/switching_P0_effective_observables_values.csv`** is a **planned TASK_005 dependency** (may be absent until task runs). Cross-module **`X_eff`** role bounded in AX index. |
| **Collapse / collapse failure** | **Partial** — **`OLD_FULL_SCALING`** + **`CANON_COLLAPSE_FAMILY`** documented; C02/C02B = QA; full “collapse failure” narrative tied to hierarchy/audit scripts per map. |
| **P0 numeric materialization** | **Partial** — P0 families listed in AX index (scaling_01–03, activity scalarization, SVD xscaling); **Switching-only P0 table** path appears in TASK_005 row — treat as **pipeline-dependent**. |
| **Coordinate identifiability** | **Partial** — forbidden conflations (`X_eff` vs `X_canon`) in `reports/switching_corrected_canonical_current_state.md`; TASK_005/TASK_006 gauge program. |
| **Corrected-old comparison** | **Partial** — authoritative corrected-old exists; **TASK_002B** old-vs-corrected parity bridge **not completed**. |
| **Visualization / publication figures** | **Partial** — QA diagnostics exist; **`SAFE_TO_CREATE_PUBLICATION_FIGURES=PARTIAL`**; quarantined misleading PNGs documented. |
| **Cross-module AX usage boundaries** | **Yes (documented)** — `docs/cross_module_switching_relaxation_AX_index.md`, AX-20A package paths, forbidden wording list. |

---

## 4. `results_old/switching/` and `results/switching/`

**Policy:** `docs/switching_artifact_policy.md`, `docs/results_system.md` describe **`results/switching/runs/...`**, flat legacy folders, and **`results_old/`** as historical replay. **Authoritative artifact index** references a concrete **`results_old/switching/runs/run_2026_03_24_212033_switching_barrier_distribution_from_map/`** path for verified legacy **`PT_matrix`**. This audit does **not** enumerate disk contents of large trees; evidence is **registry- and doc-backed**.

---

## 5. Machine-readable deliverables

- **Coverage matrix:** `tables/switching_canonical_system_survey_D_coverage_matrix.csv`  
- **Remaining work:** `tables/switching_canonical_system_survey_D_remaining_work.csv`  
- **Status keys:** `tables/switching_canonical_system_survey_D_status.csv`

---

## 6. Biggest remaining gap (coverage judgment)

**Authoritative second-mode (Phi2/kappa2) under the corrected-old recipe** plus **TASK_002B** explicit old-vs-corrected backbone parity table — these are the largest **manuscript-adjacent** holes called out in `tables/switching_corrected_old_authoritative_artifact_index.csv` and `reports/switching_corrected_canonical_current_state.md`.

---

## 7. Recommended next agents (from reconstruction program vocabulary)

1. **Narrow Switching comparison agent** — TASK_002B_backbone_parity_bridge (after TASK_001 closure confirmed in environment).  
2. **Narrow Switching coordinate / gauge agent** — TASK_005 (WI/X under corrected namespace).  
3. **Broad Switching release-gate agent** — TASK_009–TASK_012 publication authorization chain.  
4. **Cross-module CM-SW-RLX agent** — only where AX evidence tables need refresh; legacy AX functional remains **blocked** until outputs restored.

---

## 8. Staging safety (survey outputs only)

These four paths are **new survey artifacts** only. Staging them is **low risk** relative to the dirty working tree, but **this session did not run `git add`**. If the operator wants them isolated: stage **only** the four paths listed in the final user response (exact commands there).
