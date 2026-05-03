# SW-CANON-SURVEY-C — Switching canonical system user/readability clarity audit

**Date:** 2026-05-03  
**Mode:** Read-only inspection of existing docs/tables/reports (no edits to audited corpus).  
**Pre-flight:** `git diff --cached --name-only` was **empty** (no staged changes). Per `docs/repo_execution_rules.md`, this audit did not invoke MATLAB or other runners.

---

## Executive summary

The repository has **strong governance prose** for the **manuscript narrative** (`CORRECTED_CANONICAL_OLD_ANALYSIS` vs `CANON_GEN_SOURCE` vs `EXPERIMENTAL_PTCDF_DIAGNOSTIC`) in `docs/switching_analysis_map.md`, `docs/decisions/switching_main_narrative_namespace_decision.md`, `reports/switching_namespace_governance.md`, and **`reports/switching_corrected_canonical_current_state.md`** (explicit “start here” for corrected/canonical state).

**Overall clarity classification:** **usable-with-confusion**.

A new reader can reach correct answers **if** they read the right stack in order; they can easily go wrong by landing on **deprecated or historical** documents first (`docs/switching_canonical_definition.md` is marked deprecated but still presents a detailed “canonical decomposition” on native `I` that **conflicts** with the narrative contract). **P0**, **Phase 4B / C02 / C02B**, and **X_eff** are explained mainly in **cross-module** or **terminology** docs, not a single Switching-only onboarding page.

---

## What a new reader *can* answer (with evidence)

| Question | Verdict | Primary evidence |
|----------|---------|------------------|
| What is the current canonical Switching **analysis** (manuscript)? | Answerable | Narrative contract: **`CORRECTED_CANONICAL_OLD_ANALYSIS`** on **`CANON_GEN_SOURCE`** `S`; `docs/switching_analysis_map.md`, decision record. |
| What is canonical **decomposition**? | **Ambiguous without routing** | Governance: decomposition claims = corrected-old replay recipe + x-grid; deprecated file still defines native-I Scdf+Phi1 as “canonical model”. |
| What is canonical **replay**? | Partially | `switching_analysis_map.md` sections `REPLAY_PHI1_KAPPA1`, `CANON_FIGURE_REPLAY`, B03/B05; `reports/switching_corrected_canonical_current_state.md`. |
| What is **corrected-old**? | Answerable | `switching_corrected_canonical_current_state.md`, `switching_phi1_terminology_contract.md`, authoritative artifact index tables. |
| What is **legacy_old** / quarantine? | Answerable | `LEGACY_OLD_TEMPLATE` in map + decision; quarantine: `reports/switching_quarantine_index.md`, `tables/switching_misleading_or_dangerous_artifacts.csv`. |
| What is **X_eff** vs not **X_canon**? | Answerable mainly via CM doc | `docs/cross_module_switching_relaxation_AX_index.md` (R06-style rule, P0 table); `docs/switching_artifact_policy.md` forbids `X_canon`. |
| What is **validated canonically** vs replay / old comparison? | Partially | Claim boundaries B01–B12 in `tables/switching_analysis_claim_boundary_map.csv` + `switching_analysis_map.md`; `switching_canonical_reality.md` for structural survey flags. |
| What is **blocked** or not uniquely defined? | Partially | Phi1 “canon” phrases blocked in `switching_phi1_terminology_contract.md`; gaps in `switching_corrected_canonical_current_state.md` (Phi2/kappa2, TASK_002B, publication gate). |
| Which files are **authoritative**? | Answerable | `switching_corrected_canonical_current_state.md` lists stack; `tables/switching_corrected_old_authoritative_artifact_index.csv`, `switching_allowed_evidence_by_use_case.csv`. |
| Safe **variables/scalars**? | Partial | Observables doc for coordinates; safe manuscript use tied to namespaces in allowed-evidence table — not one consolidated “safe scalar list” for Switching-only readers. |
| Forbidden / ambiguous **terms**? | Answerable | `tables/switching_forbidden_ambiguous_phrases.csv`, `tables/switching_forbidden_conflations.csv`, namespace governance “five forbidden sentences”. |

---

## Navigation / index gap

There is **no single** top-level `docs/switching_README.md` or equivalent **Switching-only roadmap** that orders:

1. Pipeline/channel system (`canonical_switching_system.md`, `switching_canonical_reality.md`)  
2. Narrative / namespace contract (`switching_analysis_map.md`, decision)  
3. Corrected-old authoritative path (`reports/switching_corrected_canonical_current_state.md`)  
4. Quarantine and misleading artifacts  
5. Cross-module P0 / X_eff when needed  

Readers must **infer** this order from cross-links. **`reports/switching_corrected_canonical_current_state.md`** is the best **operational** entry for manuscript authority but does not subsume the whole Switching module story.

---

## Reports quality (purpose / inputs / outputs / status / limits / next steps)

| Artifact cluster | Purpose clear? | Inputs/outputs? | Status/limitations/next? |
|------------------|----------------|-----------------|---------------------------|
| `switching_analysis_map.md` | Strong | Strong per namespace | Boundaries + quarantine list + status pointers |
| `reports/switching_namespace_governance.md` | Strong | Index of tables | Allowed/forbidden sentences; next step = template + allowed use case |
| `reports/switching_corrected_canonical_current_state.md` | Strong | Strong | Explicit gaps table + next tasks |
| `reports/switching_quarantine_index.md` | Strong | Points to CSVs | Policy and unsafe uses |
| `docs/switching_canonical_definition.md` | **Conflicts** (deprecated banner only at top) | Detailed | Reads as authoritative unless banner heeded |
| `docs/switching_canonical_reality.md` | Factual lock | Survey refs | Append-only scientific status; may overlap terminology with narrative contract |
| Maintenance `reports/maintenance/switching_*.md` | Varies | Patch/design | Not onboarding; risk if mistaken for narrative authority |

---

## Phase / P0 / C02B labels (docs-alone understandability)

- **Phase 4B / C02 / C02B** appear in **`docs/switching_phi1_terminology_contract.md`** as **QA/inspection** collapse-defect context, **not** Phi1 definitions. A reader needs prior **phase numbering** context from reconstruction/maintenance materials; there is **no dedicated Switching glossary** of phase IDs in the core governance trio (map / decision / current_state).
- **P0** is defined as **pipeline family anchors** in **`docs/cross_module_switching_relaxation_AX_index.md`**, i.e. **cross-module**, not Switching-isolated.

---

## Clarity gap list (no big rewrites — findings only)

1. **Dual meaning of “canonical decomposition”** between deprecated `switching_canonical_definition.md` and `CORRECTED_CANONICAL_OLD_ANALYSIS` + `EXPERIMENTAL_PTCDF_DIAGNOSTIC` split.  
2. **Single producer (`run_switching_canonical.m`), two governance namespaces** for columns — cognitively heavy; requires disciplined reading of `CANON_GEN_SOURCE` vs `EXPERIMENTAL_PTCDF_DIAGNOSTIC`.  
3. **`switching_canonical_phi1.csv`** filename vs **`Phi1_corrected_old`** authority — mitigated by phi1 contract but easy to grep wrong.  
4. **`canonical_switching_system.md`** (`S_canonical` / channel protocol) vs **`CANON_GEN_SOURCE`** (CSV anchor) — same word “canonical” at different layers.  
5. **Missing one-page Switching reader roadmap** linking protocol docs, narrative contract, corrected-old state, quarantine, and AX/P0 for X_eff.  
6. **Long `namespace_id` strings** — precise for governance, hard for human memory without a short gloss table in one place (partially in map table).  
7. **Phase / task IDs** (TASK_002B, Phase 5B, 4B C02B) scattered across reports; high context cost.

---

## Survey outputs (this task)

| File | Role |
|------|------|
| `reports/switching_canonical_system_survey_C_user_clarity.md` | This report |
| `tables/switching_canonical_system_survey_C_clarity_checks.csv` | Reader questions vs evidence |
| `tables/switching_canonical_system_survey_C_naming_confusions.csv` | Naming/file-family risks |
| `tables/switching_canonical_system_survey_C_status.csv` | Machine-readable task status |

---

## References inspected (non-exhaustive)

- `docs/switching_analysis_map.md`, `docs/decisions/switching_main_narrative_namespace_decision.md`  
- `docs/switching_canonical_definition.md`, `docs/switching_canonical_reality.md`, `docs/canonical_switching_system.md`  
- `docs/switching_phi1_terminology_contract.md`, `docs/observables/switching_observables.md`  
- `docs/switching_governance_persistence_manifest.md`, `docs/switching_artifact_policy.md`, `docs/switching_system_alignment.md`  
- `docs/cross_module_switching_relaxation_AX_index.md` (P0, X_eff)  
- `reports/switching_namespace_governance.md`, `reports/switching_corrected_canonical_current_state.md`, `reports/switching_quarantine_index.md`  
- `tables/switching_allowed_evidence_by_use_case.csv` (sampled)
