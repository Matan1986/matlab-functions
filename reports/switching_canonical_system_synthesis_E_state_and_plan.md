# SW-CANON-SYNTH-E — Switching canonical system synthesis (state report and action plan)

**Synthesis ID:** `switching_canonical_system_synthesis_E`  
**Date:** 2026-05-03  
**Mode:** Synthesis only — no MATLAB, Python, or Node execution; no edits to Survey A–D outputs; no new scientific claims beyond summarizing existing survey evidence.

**Preflight (this session):** `git diff --cached --name-only` was **empty**. `git log --oneline -12` and `git status --short` were captured; working tree is **not clean** (unrelated modified/untracked paths and **deleted tracked** `figures/switching/phase4B_*` assets per Survey B/D).

**Governance context followed:** `docs/repo_execution_rules.md` (wrapper-only policy for any future MATLAB runs; this document does not execute code).

**Inputs:** Surveys A–D at the paths listed in `tables/switching_canonical_system_synthesis_E_status.csv` (`ALL_SURVEY_INPUTS_FOUND=YES`).

---

## 1. Summary of the current canonical Switching system

The Switching “canonical analysis system” is **not a single pipeline** but a **layered governance stack** (Survey A): a **registered canonical producer** (`Switching/analysis/run_switching_canonical.m`, indexed from `tables/switching_canonical_entrypoint.csv`) that emits **mixed-semantics columns**, overlaid with a **binding manuscript narrative** favoring **`CORRECTED_CANONICAL_OLD_ANALYSIS`** (old centered collapse + residual recipe on **`x = (I-I_peak)/w`**) **replayed on canonical `S`** from **`CANON_GEN_SOURCE`**, **not** the PT/CDF / native-`I` column family classified as **`EXPERIMENTAL_PTCDF_DIAGNOSTIC`** (Surveys A, C, D; `docs/switching_analysis_map.md`, `docs/decisions/switching_main_narrative_namespace_decision.md`, `docs/switching_governance_persistence_manifest.md`).

**Distinct meanings preserved (do not collapse):**

| Token / family | Role (synthesis of A–D) |
|----------------|-------------------------|
| `CANON_GEN_SOURCE` | Canonical `S` / identity-bearing outputs from the mixed producer; manuscript backbone **carrier** for corrected-old replay. |
| `EXPERIMENTAL_PTCDF_DIAGNOSTIC` | PT/CDF and related columns from the same producer; **not** the selected manuscript decomposition backbone. |
| `canonical_decomposition` | **Ambiguous without routing:** manuscript sense = corrected-old tables; deprecated doc still describes native-`I` decomposition (Survey C). |
| `canonical_replay` | **Replay** families (`REPLAY_PHI1_KAPPA1`, frozen `S_long`, etc.) and **`CANON_FIGURE_REPLAY`** (figure/layout regeneration) — distinct from new producer physics (Surveys A, C, D). |
| `corrected_old` / `CORRECTED_CANONICAL_OLD_ANALYSIS` | Gated authoritative CSV package + builder status; **authoritative when** index rows + gates say so (Survey D). |
| `legacy_old` / `LEGACY_OLD_TEMPLATE` | Alignment-era `OLD_*` semantics; quarantine and misleading-artifact registries govern unsafe reuse (Surveys A, C, D). |
| `X_eff` | Dimensionless composite / P0 ladder concepts; primary definitions in **cross-module** AX index — **`X_eff` is not automatically `X_canon`**; `X_canon` wording is forbidden per artifact policy (Surveys C, D). |
| `Phi1_corrected_old` vs `switching_canonical_phi1.csv` | **Different authorities:** filename `switching_canonical_phi1.csv` does **not** imply manuscript Phi1; phi1 terminology contract governs (Surveys A, C). |

**Quarantine rule (preserved):** Quarantined artifacts **must not** be used as manuscript or canonical evidence without explicit boundary and regeneration from authoritative tables (Surveys B, C, D; `reports/switching_quarantine_index.md`, `tables/switching_misleading_or_dangerous_artifacts.csv`).

---

## 2. Overall state classification

**Primary overall classification:** **`usable-with-confusion`** (Survey C — readers need the correct read order; deprecated and historical surfaces cause misrouting; **preserve as headline result per charter**).

**Secondary characterization (health / operations):** **`usable-with-gaps`** (Survey B — strong tables/docs governance, but empty `Switching/validation/` name expectation, git/figure lineage drift, large untracked script surface, registry snapshot completeness).

**Not selected as overall labels here:** `healthy` (understates navigation and deprecated-doc hazard), `fragile` / `blocked` (Surveys B/D still support **continued canonical work with explicit namespace discipline** and gated corrected-old package; cross-module `LEGACY_AX_FUNCTIONAL` is **blocked** in typical checkout but is not a universal halt on all Switching canonical tasks).

---

## 3. Source-of-truth files and roles

See **`tables/switching_canonical_system_synthesis_E_source_of_truth.csv`** for the machine-readable register. In prose, the **read-first hub chain** (Surveys A, B, C) is:

1. **`reports/switching_corrected_canonical_current_state.md`** — operational “start here” for corrected/canonical **manuscript authority**, gaps table, pointers to index and quarantine.  
2. **`docs/switching_analysis_map.md`** — namespace map, producer split, downstream table/report bindings.  
3. **`docs/switching_governance_persistence_manifest.md`** — durable anti-confusion manifest and pointer discipline.  
4. **`docs/decisions/switching_main_narrative_namespace_decision.md`** — adopted narrative namespace decision.  
5. **`tables/switching_corrected_old_authoritative_artifact_index.csv`** + **`tables/switching_corrected_old_authoritative_builder_status.csv`** — authoritative artifact paths and gate honesty (Survey D).

**Machine registry:** `tables/switching_canonical_entrypoint.csv` → `run_switching_canonical.m` (Survey A).

---

## 4. What the canonical Switching system already covers

- **Namespace and claim boundaries:** Map, claim-boundary tables, forbidden phrases/conflations, phi1 terminology contract and registries (Surveys A, C).  
- **Corrected-old authoritative package (gated):** Backbone/residual/Phi1/kappa1/mode1 and QA manifests; builder **`ALL_REQUIRED_GATES_PASSED=YES`** per Survey D (verify live CSV when executing work).  
- **Legacy template reference:** e.g. verified `PT_matrix` / `OLD_BARRIER_PT` route indexed for builder branch (Survey D coverage matrix).  
- **Operational producer and collapse/QA machinery:** Mixed producer, collapse hierarchy, Phase 4B C01/C02/C02B audits, P0/coordinate-identifiability **honest partial** status keys (Surveys A, B).  
- **Quarantine visibility:** Index + misleading-artifacts CSV (Surveys A, B, C, D).  
- **Cross-module boundaries for `X_eff` / P0:** AX index and artifact policy (Surveys C, D).

---

## 5. What has been replayed / reconstructed from old analysis

Survey D’s coverage matrix is the authoritative synthesis row set: **OLD_RESIDUAL_DECOMP** → **`RECONSTRUCTED_VIA_CORRECTED_OLD_AUTHORITATIVE`**; **OLD_BARRIER_PT** → **replayed into corrected-old** as template reference; **`CANON_GEN`** as **operational mixed producer** with **column-selective** evidence rules; **`CANON_FIGURE_REPLAY`** / **DIAGNOSTIC_FORENSIC** as operational/supporting; **REPLAY_PHI1_KAPPA1** as **replay diagnostic**, not manuscript backbone.

**Must not merge without boundary:** Legacy/corrected-old/canonical-replay claims stay **namespace-separated**; `CANON_GEN` native-`I` phi1/kappa1 are **diagnostic**, not **`CORRECTED_CANONICAL_OLD_ANALYSIS`** evidence (Surveys C, D; governance manifest).

---

## 6. What remains versus old analysis

From Survey D **`switching_canonical_system_survey_D_remaining_work.csv`** and report §6–7:

- **Authoritative Phi2/kappa2 under corrected-old** — index **`NOT_RECONSTRUCTED`**.  
- **TASK_002B** backbone parity bridge (old vs corrected explicit table).  
- **TASK_002A** visual QA refinement — pending user run where applicable.  
- **TASK_003–TASK_012** program (asymmetry replay, T22 refresh, WI/X gauge TASK_005, atlas regrounding, mode2+ boundaries, figure provenance remap, manuscript claim audit, legacy PT/CDF doc refresh, publication authorization).  
- **Publication pipeline** — `SAFE_TO_CREATE_PUBLICATION_FIGURES=PARTIAL`; quarantined non-authoritative corrected-old-named figures remain hazards until provenance remap (Survey D).  
- **Cross-module:** `LEGACY_AX_FUNCTIONAL` **`BLOCKED_MISSING_OUTPUTS`** per AX index (Survey D).  
- **Repository hygiene:** deleted tracked phase4B figures — **reproducibility / audit trail** gap, not automatically a “physics coverage” gap in docs (Surveys B, D).

---

## 7. Health and governance gaps

Consolidated from Survey B **`switching_canonical_system_survey_B_governance_gaps.csv`** and health checks:

- **Blocking (operational):** Tracked **deletions** under `figures/switching/` for phase4B assets — blocks faithful **clone-only** visual reproduction until restored/regenerated and committed (Survey B).  
- **Medium / process:** No `Switching/validation/` tree; large **untracked** Switching scripts — “shadow canon” risk (Survey B).  
- **Low / documentation:** `LEGACY_NOTE` vs canonical messaging; artifact policy wording vs flat `tables/switching_*.csv` layout; `run_registry` snapshot fields often unset (Survey B).

---

## 8. Clarity and navigation gaps

Consolidated from Survey C:

- **No single Switching-only ordered roadmap** linking protocol (`canonical_switching_system.md`), narrative map, corrected-old state, quarantine, and AX/P0 for `X_eff`.  
- **Dual “canonical decomposition”** narrative: deprecated `docs/switching_canonical_definition.md` vs manuscript contract.  
- **Phase / task ID scatter** (P0, 4B C02/C02B, TASK_xxx) — high context cost.  
- **Filename hazards:** `switching_canonical_phi1.csv`, `PHI2_KAPPA2_HYBRID` script naming vs quarantine rules (Surveys A, C, D).

---

## 9. Stale, deprecated, or confusing artifacts (high signal)

- **`docs/switching_canonical_definition.md`** — deprecated; points at **missing** `canonical/xy_switching/`; body can misread as authoritative (Surveys A, C).  
- **`analysis/switching/xy/status.md`**, **`analysis/switching/xx/status.md`** — stale stubs (Survey A).  
- **Quarantined / misleading PNG families** — registry in quarantine CSV/index (Surveys C, D).  
- **Untracked** `scripts/run_switching*.m` and some `Switching/*` audits — provenance confusion (Surveys A, B).

---

## 10. Blockers vs nonblocking cleanup

| Class | Examples (from B/C/D) |
|-------|------------------------|
| **Blocking** | Deleted tracked phase4B figures (visual/git fidelity). Cross-module **LEGACY_AX_FUNCTIONAL** blocked for AX evidence that depends on missing outputs. Manuscript-adjacent **TASK_002B** / **Phi2_kappa2 authoritative** / publication gate **PARTIAL** block *specific claimed closures*, not all Switching work. |
| **Nonblocking** | `Switching/validation/` absence as named folder; registry snapshot columns; LEGACY_NOTE bridge line; flat vs subdir table policy clarification; glossary/roadmap docs; tracking untracked scripts (Survey B). |

---

## 11. Staged action plan (summary)

Full rows: **`tables/switching_canonical_system_synthesis_E_action_plan.csv`**.

| Stage | Intent |
|-------|--------|
| **Immediate housekeeping** | Resolve **tracked figure deletions** (restore or regenerate + intentional commit); triage **untracked** Switching entrypoints per repo policy — **track or document**, do not delete without explicit approval. |
| **Central index / roadmap** | One ordered **Switching reader index** (hub-only links): current_state → analysis_map → manifest → quarantine → AX P0/`X_eff` one-liner. |
| **Naming / namespace cleanup** | Glossary row for bare “canonical”; cross-links for P0/C02B; defer **rename** of hybrid script to **future explicitly approved** cleanup (Survey C/D; no delete recommendation here). |
| **Old-analysis reconstruction completion** | TASK_002B; authoritative Phi2/kappa2; TASK_003 chain through TASK_008 non-destructive cleanup **plan** (Survey D). |
| **Validation / governance cleanup** | Optional `Switching/validation/README` or thin checks; align artifact policy text with flat table reality; optional registry backfill (Survey B). |
| **Future scientific analyses** | Only after gates: publication TASK_009–012 chain; mode2+ claim boundary refresh; CM AX refresh where bounded claims need new evidence. |

---

## 12. Recommended agent breakdown

| Dimension | Guidance |
|-----------|----------|
| **Narrow vs broad** | **Narrow** agents for TASK_002B, Phi2/kappa2 authoritative reconstruction, TASK_005 gauge, figure provenance (TASK_009). **Broad** agents for TASK_010–012 release/claim audits spanning multiple tables. |
| **Serial vs parallel** | **Serial:** infrastructure/git figure restoration before publication audits that assume committed assets. **Parallel:** documentation index work vs narrow reconstruction agents **if** they touch disjoint paths and do not restage conflicting figure binaries. |
| **Blocking dependencies** | TASK_012 depends on TASK_009–010; TASK_005 depends on TASK_003 (and optional P0 values CSV per D); TASK_002B depends on TASK_001 + comparison inputs per D; cross-module AX unblock depends on restoring AX-aligned outputs (Survey D). |

---

## 13. Scientific claims discipline

This synthesis **does not** introduce new quantitative or physics claims; it **aggregates** Survey A–D statements and points to authoritative paths. Any future agent must keep **legacy / corrected-old / canonical-replay / CANON_GEN diagnostic** evidence separated per **`tables/switching_analysis_claim_boundary_map.csv`** and the governance manifest.

---

## 14. Staging and commit policy (A–D + E)

- **Synthesis outputs (E only):** Safe to **`git add`** **only** the five paths listed in §15 **when** `git diff --cached --name-only` is empty before staging (same discipline as surveys).  
- **Survey A–D outputs:** Safe to stage **only** their **twelve** explicit artifact paths **in isolation** from unrelated dirty-tree files.  
- **Commit:** **Content-safe** for documentation-only survey+synthesis artifacts; **process-conditional** — a commit should be **scoped** to these paths; the current working tree has **many unrelated** changes — **do not** mix unrelated maintenance/Relaxation files into the same commit without operator review.  
- **Do not use:** `git add .`, `git add -A`, `git clean`, `git reset`, `git revert` (per user guardrails).

---

## 15. Required output paths (this task)

| Artifact | Path |
|----------|------|
| Consolidated report | `reports/switching_canonical_system_synthesis_E_state_and_plan.md` |
| Action plan | `tables/switching_canonical_system_synthesis_E_action_plan.csv` |
| Source of truth | `tables/switching_canonical_system_synthesis_E_source_of_truth.csv` |
| Confusions / gaps | `tables/switching_canonical_system_synthesis_E_confusions_and_gaps.csv` |
| Status | `tables/switching_canonical_system_synthesis_E_status.csv` |

---

## 16. Survey A–D artifact paths (inputs; not modified by E)

**Survey A:** `reports/switching_canonical_system_survey_A_map.md`, `tables/switching_canonical_system_survey_A_inventory.csv`, `tables/switching_canonical_system_survey_A_groups.csv`, `tables/switching_canonical_system_survey_A_status.csv`  

**Survey B:** `reports/switching_canonical_system_survey_B_health_integrity.md`, `tables/switching_canonical_system_survey_B_health_checks.csv`, `tables/switching_canonical_system_survey_B_governance_gaps.csv`, `tables/switching_canonical_system_survey_B_status.csv`  

**Survey C:** `reports/switching_canonical_system_survey_C_user_clarity.md`, `tables/switching_canonical_system_survey_C_clarity_checks.csv`, `tables/switching_canonical_system_survey_C_naming_confusions.csv`, `tables/switching_canonical_system_survey_C_status.csv`  

**Survey D:** `reports/switching_canonical_system_survey_D_old_analysis_coverage.md`, `tables/switching_canonical_system_survey_D_coverage_matrix.csv`, `tables/switching_canonical_system_survey_D_remaining_work.csv`, `tables/switching_canonical_system_survey_D_status.csv`

---

END
