# SW-CANON-SURVEY-B — Switching canonical system health and integrity audit

**Date:** 2026-05-03  
**Mode:** Read-only audit (no edits to existing Switching code, data, or governance files).  
**Execution rules followed:** `docs/repo_execution_rules.md` (static inspection only; no MATLAB / Python / Node runs for this survey).

## Preflight: git

Commands run (PowerShell-safe):

- `git log --oneline -12` — completed.
- `git diff --cached --name-only` — **empty** (no staged changes); audit proceeded per guardrail.
- `git status --short` — **non-clean** working tree: modified maintenance artifacts, **deleted tracked** Switching figures under `figures/switching/`, and many **untracked** files including Switching analysis/diagnostics and `scripts/run_switching*`.

## Executive summary

The canonical Switching analysis system is **strongly governed in documentation and tables**: namespace contracts, quarantine registries, authoritative corrected-old gates, Phase 3 / P0 / Phase 4B status CSVs, and extensive `reports/switching_*.md` / `tables/switching_*.csv` evidence exist and cross-link in the intended direction (current-state entry → indices → gates).

**Overall health classification:** **usable-with-gaps**.

The main risks are **operational and lineage hygiene**, not a missing conceptual framework: legacy framing in `Switching/LEGACY_NOTE.md` sits beside newer canonical contracts; **`Switching/validation/`** has no validation package in-repo; **git cleanliness** (deleted figures, large untracked surface) weakens “reproducible from clone alone” for some visuals and entrypoints; durable artifact layout is **split** between policy language (`tables/switching/`) and widespread **flat** `tables/switching_*.csv` (high volume still indexed by reports).

**Safe to build on canonical Switching analysis?** **Yes, with explicit namespace discipline** (`docs/switching_analysis_map.md`, `reports/switching_corrected_canonical_current_state.md`, `tables/switching_corrected_old_authoritative_builder_status.csv`). Expansion should treat `run_switching_canonical.m` as a **mixed producer**, honor execution signaling (`execution_status.csv`), and keep run lineage under `results/switching/runs/`.

## Evidence map (scope: Switching canonical health)

| Area | Finding |
|------|---------|
| `docs/repo_execution_rules.md` | Read: wrapper-only MATLAB policy, execution signaling contract, runnable script template expectations. |
| `docs/switching_analysis_map.md` | Present; declares inputs/outputs per namespace, manuscript vs diagnostic split, producer `run_switching_canonical.m`. |
| Governance / SoT | `docs/switching_governance_persistence_manifest.md`, `docs/switching_artifact_policy.md`, `docs/switching_phi1_terminology_contract.md`, `reports/switching_corrected_canonical_current_state.md`. |
| `Switching/analysis/` | Large corpus; canonical producer and phase audits present; **untracked** examples in current tree: `run_switching_canonical_state_audit.m`, `run_switching_cdf_backbone_repair_aggressiveness_audit.m` (git status). |
| `Switching/validation/` | **No files found** in workspace listing — gap vs a dedicated validation package name. |
| `scripts/run_switching*` | Many **PowerShell + MATLAB** orchestrators (P0, Phase 4A/4C, coordinate identifiability, gauge, replay); several **untracked** in this clone. |
| `results/switching/runs/` | **Present** with **231** run directories (count from shell); aligns with `docs/switching_artifact_policy.md` hierarchy #1. |
| Manifest / fingerprint | `Switching/utils/createSwitchingRunContext.m` delegates to `createRunContext('switching',...)` with `assertSwitchingRunDirCanonical`; multiple analyses set `cfg.fingerprint_script_path`; `writeSwitchingExecutionStatus.m` exists. |
| `analysis/knowledge/run_registry.csv` | Indexes switching runs with `run_rel_path` under `results\switching\runs\...`; sampled rows show `snapshot_has_entry` often `0` — lineage promotion into snapshot fields may be incomplete (nonblocking for local runs if run folders exist). |
| P0 effective observables | Tables: `tables/switching_P0_effective_observables_*.csv`; report: `reports/switching_P0_effective_observables_recipe_parity.md`; script: `scripts/run_switching_P0_effective_observables_*.ps1`. Status CSV includes explicit **SAFE_TO_WRITE_SCALING_CLAIM = NO** (good gate honesty). |
| Phase 3 coordinate identifiability | Tables + `reports/switching_coordinate_identifiability_audit.md`; `scripts/run_switching_coordinate_identifiability_audit.ps1`. Status shows **uniqueness NO** but **SAFE_TO_TEST_SCALING_COORDINATES YES** — informative partial closure. |
| Phase 4B / C02B | Tables `tables/switching_phase4B_C02B_*.csv`, `tables/switching_phase4B_C01_status.csv`; reports `reports/switching_phase4B_C01_*.md`, `reports/switching_phase4B_C02B_*.md`. **Git status shows deleted tracked PNG/FIG** for phase4B C01/C02 — figure lineage risk. |
| Quarantine / legacy | `tables/switching_misleading_or_dangerous_artifacts.csv`, `reports/switching_quarantine_index.md`, `tables/switching_legacy_*`, `Switching/LEGACY_NOTE.md` (warns “legacy code” — potential narrative tension with “canonical system”). |

## Task 1 checklist (canonical analyses)

- **Declared inputs / outputs:** **Yes** for primary contracts (`docs/switching_analysis_map.md`, per-script headers such as `run_switching_canonical.m` namespace warnings; authoritative path in `reports/switching_corrected_canonical_current_state.md`).
- **Status CSVs:** **Yes**, many `*_status.csv` files with explicit verdict keys (examples audited: `switching_corrected_old_authoritative_builder_status.csv`, `switching_phase4B_C01_status.csv`, `switching_phase4B_C02B_status.csv`, `switching_coordinate_identifiability_status.csv`, `switching_P0_effective_observables_status.csv`).
- **Reports:** **Yes**, large `reports/switching_*.md` set including phase audits and current-state hub.
- **Scripts / entrypoints:** **Yes**, split between `Switching/analysis/*.m` and `scripts/run_switching*` (PS1/M); **gap:** many untracked in this working tree.
- **Run manifests / fingerprints:** **Partially uniform** — enforced path for Switching runs via `createSwitchingRunContext` + `assertSwitchingRunDirCanonical`; not every script class was exhaustively enumerated in this audit.
- **Validation gates:** **Yes in tables/reports**; **no** dedicated `Switching/validation/` code tree observed.
- **Source-of-truth rules:** **Yes** — governance manifest, artifact policy, phi1 terminology contract, authoritative artifact index + builder gate.
- **Old vs canonical naming boundaries:** **Yes** — explicit `namespace_id` vocabulary and `CORRECTED_CANONICAL_OLD_ANALYSIS` vs `CANON_GEN_SOURCE` vs `EXPERIMENTAL_PTCDF_DIAGNOSTIC` in `docs/switching_analysis_map.md` and related CSVs.

## Task 2 — Status CSV consistency

Sampled status files use consistent **key,value** (or `verdict_key,verdict_value`) patterns, explicit **SAFE_TO_*** and completion flags, and honest **NO / PARTIAL** entries where gates are not met. No contradiction detected in the small cross-sample (C02B claims figures written while git shows deletions — interpret as **workspace / git drift**, not internal CSV self-contradiction).

## Task 3 — Report ↔ table ↔ run linkage

- **Strong:** `reports/switching_corrected_canonical_current_state.md` links to authoritative index, builder status, quarantine registry, column namespace report.
- **Strong:** Phase 4B reports reference companion CSV names in conventional paths.
- **Mixed:** `run_registry.csv` links run ids to paths; snapshot resolution columns often `0` on sampled rows — optional strengthening for “one-hop” discoverability from registry alone.

## Task 4 — Governance gaps (summary)

See `tables/switching_canonical_system_survey_B_governance_gaps.csv` for the full gap register. Highlights: empty `Switching/validation/`, dirty git / deleted figures, untracked Switching entrypoints, policy vs actual `tables/switching/` directory layout, `LEGACY_NOTE` vs canonical messaging, registry snapshot completeness.

## Task 5 — Safe for future expansion?

**Yes**, provided new work: (1) uses `createSwitchingRunContext`, (2) writes `execution_status.csv` and run-scoped outputs per repo execution rules, (3) labels outputs with `namespace_id`, (4) does not conflate `CANON_GEN` diagnostic columns with corrected-old manuscript claims, (5) tracks important new scripts in git to avoid “shadow canon” in untracked files.

## Task 6 — Physics

Out of scope per charter; no deep physics judgment.

## Deliverables

- This report: `reports/switching_canonical_system_survey_B_health_integrity.md`
- Health checks: `tables/switching_canonical_system_survey_B_health_checks.csv`
- Governance gaps: `tables/switching_canonical_system_survey_B_governance_gaps.csv`
- Status: `tables/switching_canonical_system_survey_B_status.csv`
