# Switching canonical reader hub

## Status (read before proceeding)

- This file is a **navigation and roadmap** pointer chain for humans and agents.
- It **does not** introduce new scientific claims or quantitative results.
- It **does not** replace authoritative reports, CSV registers, or decision records.
- It summarizes **routing discipline after SW-CANON-SYNTH-E** (`reports/switching_canonical_system_synthesis_E_state_and_plan.md`).
- **Overall state:** **`usable-with-confusion`** (primary synthesis label) — the system is **not blocked** for disciplined use; readers must follow namespaces and read order. Secondary operational note from synthesis: **`usable-with-gaps`** (health/git/process surfaces).

---

## Read this first (ordered)

Use this sequence before deep-diving individual phase reports:

| Order | Path | One-line role |
|-------|------|----------------|
| 1 | `reports/switching_corrected_canonical_current_state.md` | Operational **start here** for manuscript authority, gaps table, and pointers to corrected-old package and quarantine. |
| 2 | `docs/switching_analysis_map.md` | **Namespace map**: producer split, backbone ids, bindings to tables/reports; manuscript contract summary. |
| 3 | `docs/switching_governance_persistence_manifest.md` | **Durable facts** (mixed producer, diagnostic vs manuscript evidence, pointer discipline). |
| 4 | `docs/decisions/switching_main_narrative_namespace_decision.md` | **Adopted narrative contract** (`CORRECTED_CANONICAL_OLD_ANALYSIS` vs diagnostic families). |
| 5 | `tables/switching_corrected_old_authoritative_artifact_index.csv` + `tables/switching_corrected_old_authoritative_builder_status.csv` | **Authoritative corrected-old paths** and gate honesty — pair index rows with `namespace_id` when citing (human-readable mirror: `reports/switching_corrected_old_authoritative_artifact_index.md`). |
| 6 | `reports/switching_quarantine_index.md`; `tables/switching_misleading_or_dangerous_artifacts.csv` | **Quarantine visibility** — do not cite quarantined artifacts as manuscript evidence without explicit boundary and regeneration. |
| 7 | `docs/cross_module_switching_relaxation_AX_index.md` | **Cross-module AX / P0 / `X_eff`** routing — definitions are not Switching-isolated; see index for scope and blockers. |

**Phi1 naming contract (when citing Phi1):** `docs/switching_phi1_terminology_contract.md` — see vocabulary row for `Phi1_corrected_old` vs `switching_canonical_phi1.csv`.

For machine-readable registers used in audits, see `tables/switching_canonical_system_synthesis_E_source_of_truth.csv`.

---

## Vocabulary and namespaces

Do **not** infer meanings from filenames alone. Use the **primary reference path** when drafting claims.

| Token / label | Meaning (short) | Safe use | Forbidden interpretation | Primary reference path |
|---------------|-----------------|----------|---------------------------|-------------------------|
| `CANON_GEN_SOURCE` | Canonical measured **`S`** (and identity axes) from the mixed producer `run_switching_canonical.m`; backbone **carrier** for corrected-old replay on canonical **`S`**. | Citing **`S_percent`** / clean source view and provenance for **`CORRECTED_CANONICAL_OLD_ANALYSIS`** inputs. | Treating **`CANON_GEN`** outputs **as a whole** as “the manuscript backbone” without `namespace_id`. | `docs/switching_analysis_map.md`; `docs/decisions/switching_main_narrative_namespace_decision.md`; column detail: `reports/switching_canonical_S_long_column_namespace.md` |
| `EXPERIMENTAL_PTCDF_DIAGNOSTIC` | PT/CDF-related columns from **`CANON_GEN`** (`S_model_pt_percent`, `CDF_pt`, `PT_pdf`) — **diagnostic / source-layer**, not the selected manuscript decomposition backbone under the current contract. | Diagnostics, audits, supplementary checks with explicit id. | Labeling PT/CDF columns as the **main manuscript backbone** without a new decision. | `docs/switching_analysis_map.md`; `docs/decisions/switching_main_narrative_namespace_decision.md` |
| `canonical_decomposition` | **Ambiguous without routing:** manuscript sense = corrected-old replay recipe; deprecated doc body can describe a different (native-`I`) picture. | Always pair with **`namespace_id`** and artifact index rows. | Collapsing “canonical decomposition” to one pipeline without checking map + current state. | `docs/switching_analysis_map.md`; `reports/switching_corrected_canonical_current_state.md`; hazard: `docs/switching_canonical_definition.md` (deprecated — see “Do not do this”) |
| `canonical_replay` | **Replay families** (e.g. phi1/kappa1 replay, frozen `S_long`) and figure/layout regeneration — distinct from “new producer physics” claims. | Citing replay runners and replay outputs with explicit family id. | Equating replay diagnostics with **`CORRECTED_CANONICAL_OLD_ANALYSIS`** manuscript evidence without boundary. | `docs/switching_analysis_map.md`; synthesis E §5 (`reports/switching_canonical_system_synthesis_E_state_and_plan.md`) |
| `corrected_old` / `CORRECTED_CANONICAL_OLD_ANALYSIS` | Gated **corrected-old authoritative CSV package** and reconstruction narrative (centered collapse + residual recipe on **`x = (I-I_peak)/w`** on canonical **`S`**). | Claims when **artifact index + builder status** authorize the specific rows/tables cited. | Treating any file named “corrected_old” or “canonical” as authoritative without index + gates. | `tables/switching_corrected_old_authoritative_artifact_index.csv`; `tables/switching_corrected_old_authoritative_builder_status.csv`; `reports/switching_corrected_canonical_current_state.md` |
| `legacy_old` / `LEGACY_OLD_TEMPLATE` | Alignment-era **`OLD_*`** semantics and historical templates; governed by quarantine and misleading-artifact rules. | Historical comparison; explicit family labels. | Presenting legacy outputs as **current** manuscript proof without **`CORRECTED_CANONICAL_OLD_ANALYSIS`** replay on **`CANON_GEN_SOURCE`**. | `docs/decisions/switching_main_narrative_namespace_decision.md`; `docs/switching_analysis_map.md`; registries in source-of-truth table |
| `X_eff` | Cross-module dimensionless composite / P0 ladder concepts — definitions live primarily in **AX** materials, not Switching-only prose. | Bounded cross-module claims per AX index and artifact policy. | Replacing or equating with **`X_canon`** or importing scaling claims without AX grounding. | `docs/cross_module_switching_relaxation_AX_index.md`; `docs/switching_artifact_policy.md` (see synthesis E source-of-truth row) |
| `X_canon` | **Forbidden / unsafe wording** in artifact policy context — do not substitute for `X_eff` or manuscript variables. | Prefer explicit permitted tokens from AX index + Switching maps; **avoid** introducing `X_canon` in new prose. | Any claim that **`X_eff`** “is” **`X_canon`** or interchangeable wording. | `docs/switching_artifact_policy.md`; `docs/cross_module_switching_relaxation_AX_index.md` |
| `Phi1_corrected_old` | Manuscript-aligned Phi1 authority under **`CORRECTED_CANONICAL_OLD_ANALYSIS`** — **not** inferred from diagnostic filenames. | Captions and claims pointing at **`tables/switching_corrected_old_authoritative_phi1.csv`** (and index-backed paths). | Using **`Phi1_canon`** / bare “canonical Phi1” phrases blocked by terminology contract. | `docs/switching_phi1_terminology_contract.md`; `tables/switching_corrected_old_authoritative_artifact_index.csv` |
| `switching_canonical_phi1.csv` | **Diagnostic** Phi1-like output from the mixed canonical run — filename suggests “canonical” but is **not** the locked manuscript Phi1 shape. | Diagnostic plots/checks with **`DIAGNOSTIC_MODE_ANALYSIS`** / explicit non-authoritative labeling. | Manuscript **`CORRECTED_CANONICAL_OLD_ANALYSIS`** evidence without **`Phi1_corrected_old`** bridge. | `docs/switching_phi1_terminology_contract.md`; `docs/switching_analysis_map.md` (Phi1 terminology subsection); `docs/switching_governance_persistence_manifest.md` |

---

## What is already covered

Per SW-CANON-SYNTH-E (`reports/switching_canonical_system_synthesis_E_state_and_plan.md`) and linked registers:

- **Namespace map and narrative contract** — `docs/switching_analysis_map.md`, decision record, claim-boundary / forbidden-phrase tables (see `tables/switching_canonical_system_synthesis_E_source_of_truth.csv`).
- **Corrected-old authoritative tables and builder pass** — artifact index + builder status (**verify live CSV** before release claims).
- **Quarantine registries** — index + misleading-artifacts CSV for non-authoritative visuals and hazardous reuse.
- **Mixed producer with `CANON_GEN_SOURCE` vs `EXPERIMENTAL_PTCDF_DIAGNOSTIC` split** — governance manifest and analysis map.
- **Phi1 terminology blocks** — `docs/switching_phi1_terminology_contract.md` and registries.
- **Collapse / QA phase machinery** — operational audits and phase keys documented in survey/synthesis chain (see analysis map and maintenance phase reports referenced from synthesis).
- **Cross-module `X_eff` and forbidden `X_canon` rules** — AX index + artifact policy.

---

## What remains open

From synthesis E and Survey D remaining-work alignment (details in `tables/switching_canonical_system_synthesis_E_action_plan.csv` and `tables/switching_canonical_system_survey_D_remaining_work.csv`):

- **Authoritative Phi2 / kappa2 under corrected-old** — index **`NOT_RECONSTRUCTED`** until chartered reconstruction completes.
- **TASK_002B** backbone parity bridge (explicit old vs corrected table).
- **TASK_002A** visual QA refinement — where applicable / documentation-safe refinement.
- **TASK_003–TASK_012** program — asymmetry replay through publication authorization chain per task table.
- **`LEGACY_AX_FUNCTIONAL`** — **`BLOCKED_MISSING_OUTPUTS`** for typical checkout until AX-aligned outputs restored or index refreshed (cross-module; see AX index).
- **Publication gate** — **`SAFE_TO_CREATE_PUBLICATION_FIGURES=PARTIAL`**; quarantined or non-authoritative figures remain hazards until provenance remap / TASK_009–012 closure.

---

## Do not do this

- **Do not** treat **`X_eff`** as **`X_canon`** or use forbidden replacement wording (see AX index + artifact policy).
- **Do not** use **quarantined** artifacts as manuscript or canonical evidence without explicit boundary and regeneration from authoritative tables.
- **Do not** merge **legacy**, **corrected-old**, and **canonical-replay** claims into one “canonical evidence” story without **declared namespace boundaries** (`tables/switching_analysis_claim_boundary_map.csv`).
- **Do not** rely on **`docs/switching_canonical_definition.md`** as the primary current route — **deprecated** and conflicts narrative contract; use analysis map + current state.
- **Do not** use bare **“canonical”** without **`namespace_id`** or file-level qualifier when making **new** claims.
- **Do not** treat **diagnostic PT/CDF columns** (`EXPERIMENTAL_PTCDF_DIAGNOSTIC`) as manuscript-authoritative unless a **new decision record** explicitly allows it.

---

## Recommended next work (staged)

Short prioritization aligned with `tables/switching_canonical_system_synthesis_E_action_plan.csv`:

1. **Figure / git hygiene** — restore or regenerate deleted tracked `figures/switching/phase4B_*` assets (clone-only visual fidelity) per governance gaps.
2. **Triage untracked Switching/scripts surfaces** — track or document intentionally untracked entrypoints (“shadow canon” risk).
3. **Central naming / namespace cleanup** — glossary rows for bare “canonical”; optional banner/redirect hardening for deprecated definition doc (**future approved editorial task only**).
4. **TASK_002B** and **Phi2/kappa2** authoritative follow-up — narrow reconstruction agents when inputs and charter allow.
5. **Later publication authorization chain** — TASK_009–012 serial dependencies before treating publication outputs as authorized.

---

## If uncertain

Prefer **opening the source-of-truth CSV row** in `tables/switching_canonical_system_synthesis_E_source_of_truth.csv` over guessing paths or physics. For live gate values, open **`tables/switching_corrected_old_authoritative_builder_status.csv`** at execution time.
