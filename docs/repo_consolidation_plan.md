# Repository consolidation map and migration plan

**Date:** 2026-03-24  
**Basis:** `docs/repo_audit_report.md`, `docs/AGENT_RULES.md`, `docs/results_system.md`, `docs/repository_structure.md`, `docs/run_system.md`, `docs/output_artifacts.md`, `docs/system_registry.json`.  
**Scope:** Planning and mapping only — **no code moves, refactors, or behavior changes** are performed in this document.

---

## Principles (constraints from repo rules)

- **Gradual alignment:** `docs/AGENT_RULES.md` forbids repository-wide refactors to force architecture; changes should land **when a file or module is already being edited**.
- **Documentation precedence:** `AGENT_RULES` → `results_system` → `run_system` → `repository_structure` → `output_artifacts` for overlapping output/layout topics.
- **Registry authority:** `docs/system_registry.json` defines **unified stack**, **independent pipelines**, **infrastructure**, and **active_modules** — do not treat every `* verX` folder as legacy by name alone (`AGENT_RULES`).

---

## 1. Entry point consolidation plan

### 1.1 Complete inventory: `run_*.m` files (34)

| Path |
|------|
| `runs/run_aging.m` |
| `run_activation_signature_wrapper.m` |
| `run_a1_integral_consistency_wrapper.m` |
| `run_a1_mobility_wrapper.m` |
| `run_amplitude_response_wrapper.m` |
| `run_aging_clock_ratio_temperature_scaling_wrapper.m` |
| `run_barrier_distribution_wrapper.m` |
| `run_creep_activation_scaling_wrapper.m` |
| `run_geometry_deformation_wrapper.m` |
| `run_relaxation_temperature_scaling_wrapper.m` |
| `run_ridge_susceptibility_analysis_wrapper.m` |
| `run_ridge_temperature_susceptibility_wrapper.m` |
| `run_switching_creep_barrier_analysis_wrapper.m` |
| `run_switching_creep_scaling_wrapper.m` |
| `run_switching_threshold_residual_structure_wrapper.m` |
| `run_switching_width_roughness_competition_wrapper.m` |
| `run_x_vs_r_predictor_comparison_wrapper.m` |
| `run_threshold_distribution_model.m` |
| `Relaxation ver3/diagnostics/run_relaxation_beta_T_audit.m` |
| `Relaxation ver3/diagnostics/run_relaxation_coordinate_audit.m` |
| `Relaxation ver3/diagnostics/run_relaxation_coordinate_extraction.m` |
| `Relaxation ver3/diagnostics/run_relaxation_derivative_smoothing_run.m` |
| `Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m` |
| `Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m` |
| `Relaxation ver3/diagnostics/run_relaxation_svd_audit.m` |
| `Relaxation ver3/diagnostics/run_relaxation_timelaw_observables.m` |
| `Relaxation ver3/diagnostics/run_relaxation_time_mode_analysis.m` |
| `ARPES ver1/run_arpes_dual.m` |
| `ARPES ver1/run_arpes_json.m` |
| `analysis/run_unified_barrier_mechanism.m` |
| `scripts/run_adversarial_observable_search.m` |
| `tools/figure_repair/run_validation_suite.m` |
| `Aging/tests/switching_stability/run_diagnostic_wrapped.m` |
| `GUIs/tests/legacy/RUN_URGENT_VALIDATION.m` |

### 1.2 Other primary entry points (non–`run_*` but user-facing or pipeline roots)

| Path | Role |
|------|------|
| `Aging/Main_Aging.m` | Aging pipeline entry (invoked from `runs/run_aging.m` and directly). |
| `Relaxation ver3/main_relaxation.m` | Relaxation module main. |
| `Switching ver12/main/Switching_main.m` | Legacy Switching pipeline main (`repository_structure.md`). |
| `PS ver4/PS_main.m`, `HC ver1/HC_main.m`, `MH ver1/MH_main.m`, `MT ver2/MT_main.m`, `FieldSweep ver3/FieldSweep_main.m`, `Resistivity ver6/Resistivity_main.m`, `Resistivity MagLab ver1/ACHC_RH_main.m`, `AC HC MagLab ver8/ACHC_main.m`, `zfAMR ver11/main/zfAMR_main.m` | Independent instrument pipelines (`system_registry.json`). |
| `Susceptibility ver1/main_Susceptibility.m` | Instrument/susceptibility entry (also named `main_*.m`). |
| `Aging/verification/verifyRobustBaseline_RealData_Main.m` | Verification harness (nested “main”). |

*Note:* Many `analysis/*.m` files are **callable analysis functions** (entry when invoked from MATLAB or wrappers); they are not all listed here — consolidation treats **`run_*` + mains + wrappers** as the **launcher surface**.

### 1.3 Classification

**Canonical (should remain as supported entry patterns; location may still be improved later)**

| Item | Rationale |
|------|-----------|
| `runs/run_aging.m` | Matches `repository_structure.md` placement for launch wrappers. |
| `Aging/Main_Aging.m`, `Relaxation ver3/main_relaxation.m` | Declared module entry style (`docs/repo_state.json` / structure docs). |
| `Relaxation ver3/diagnostics/run_relaxation_*.m` | Run-scoped diagnostics aligned with `createRunContext` + `save_run_*` (per audit). |
| `ARPES ver1/run_arpes_dual.m`, `ARPES ver1/run_arpes_json.m` | Active independent pipeline (`system_registry.json`). |
| `tools/figure_repair/run_validation_suite.m` | Tooling harness; not a science “run” but a legitimate tool entry. |
| Instrument `*_main.m` / `ACHC_main.m` / `zfAMR_main.m` | Canonical for **independent** pipelines; results policy may still need per-pipeline alignment over time. |

**Legacy (deprecate for *new* work; keep for reproducibility until replaced)**

| Item | Rationale |
|------|-----------|
| `Switching ver12/main/Switching_main.m` | Explicitly **legacy / overlapping** Switching tree in `repository_structure.md`. |
| `GUIs/tests/legacy/RUN_URGENT_VALIDATION.m` | Path and name mark **legacy** GUI test. |
| `General ver2/*` as figure/export dependency | **Not an entry script**, but `AGENT_RULES.md` forbids **new** reuse for figures. |

**Ambiguous (needs explicit policy: wrapper move, run-context fix, or doc label)**

| Item | Rationale |
|------|-----------|
| **16 repo-root `run_*_wrapper.m`** | Thin, useful batch entries but **contradict** “launch wrappers belong in `runs/`” from `repository_structure.md`. |
| `analysis/run_unified_barrier_mechanism.m` | Valid science orchestration but uses **local `createRun`** instead of shared `createRunContext` (audit finding). |
| `run_threshold_distribution_model.m` | Uses `pwd` + **hard-coded** source run paths; not clearly run-scoped output (needs review against `results_system.md`). |
| `scripts/run_adversarial_observable_search.m` | Writes report under repo **`reports/`** (not `results/.../runs/...`) — **misaligned** with `results_system.md` core rule. |
| `Aging/tests/switching_stability/run_diagnostic_wrapped.m` | Test wrapper writing to `tmp_debug_outputs/` — acceptable for tests if documented; not a canonical results entry. |
| **Callable `analysis/*.m` without a `runs/` launcher** | Fine as **library APIs**; ambiguous only when users treat repo root as the “obvious” place to start. |

### 1.4 Proposed **single canonical entry system** (target behavior)

**Recommendation (staged, not a big bang):**

1. **Human batch entry:** All **new** thin wrappers that only `addpath` + call one analysis function should live under **`runs/`**, optionally grouped as `runs/unified/`, `runs/switching/`, `runs/cross_experiment/` — **without deleting** old root wrappers until aliases or docs are updated (reversible).
2. **Module mains unchanged:** `Main_Aging.m`, `main_relaxation.m`, instrument `*_main.m` remain the **canonical in-module** entry for their pipelines (per registry + structure docs).
3. **Callable diagnostics:** Keep **`Relaxation ver3/diagnostics/run_relaxation_*.m`** (and similar) as **named entrypoints**; if desired, add **one-line `runs/relaxation/run_*.m`** shims that call them — avoids moving large files.
4. **Tooling:** Keep **`tools/**/run_*.m`** as tool entries; document them in `docs/AGENT_ENTRYPOINT.md` or a small `runs/README.md` index (doc-only step).
5. **Legacy:** **`Switching ver12/main/Switching_main.m`** — document “use `Switching/analysis/` + run system for new work”; no forced removal.

This satisfies a **single mental model**: “**`runs/` = how humans start batch jobs**; **`Main_*` / `*_main` = how module pipelines start**; **`analysis/` = callable functions**,” while respecting **no mass moves** until explicitly scheduled.

---

## 2. Results system unification

### 2.1 `createRunContext` (correct baseline)

Approximately **110** `*.m` files reference `createRunContext` (including the implementation and helpers such as `tools/init_run_output_dir.m`, `Aging/pipeline/stage0_setupPaths.m`, and `Aging/utils/createRunContext.m`). This is the **documented** run factory for the unified stack (`run_system.md` + audit).

**Parallel / partial duplicate**

- `analysis/run_unified_barrier_mechanism.m` — local **`createRun`** writing into `figuresDir` / `tablesDir` / `reportsDir` / `reviewDir` (conceptually aligned with artifact folders, but **not** the same metadata path as `createRunContext`).

### 2.2 Direct `writetable` / `saveas` / `imwrite` (context-dependent)

**Counts (indicative):**

- **`writetable(`:** on the order of **50** `*.m` files (includes **infrastructure** such as `tools/save_run_table.m` and `tools/export_observables.m`, which are **expected** to write tables).
- **`saveas(`:** on the order of **45** `*.m` files — heavy concentration in **`Aging/diagnostics/`**, **`Relaxation ver3/diagnostics/`**, **`Fitting ver1/`**, **`Switching/analysis/`** (survey / exploratory scripts), plus **`General ver2`**-related usage paths.
- **`imwrite(`:** **8** `*.m` files under **`General ver2/figureSaving/`** and **`Fitting ver1/`** — treat as **legacy export stack** for new figure work.

**Representative directories with direct table/figure writes (migration candidates over time)**

- `Aging/diagnostics/*.m`, `Aging/pipeline/*.m` (e.g. export / phase scripts), `Aging/verification/*.m`
- `Relaxation ver3/diagnostics/*.m` (survey / validation / visualization scripts)
- `Switching/analysis/switching_*survey*.m`, `switching_mechanism_*.m`, `switching_shape_rank_analysis.m`, etc.
- `Fitting ver1/*.m`
- `analysis/run_unified_barrier_mechanism.m`, `analysis/cross_experiment_observables.m`, `analysis/switching_observable_summary.m`
- `reports/functional_form_test_analysis.m`

*This list is **not** exhaustive; it is a **consolidation map** for where drift concentrates.*

### 2.3 Unified rule (what **MUST** be used for new / touched analysis)

**Single rule statement (aligned with `AGENT_RULES.md` + `results_system.md` + `output_artifacts.md`):**

1. **Create a run folder** under `results/<experiment>/runs/run_<timestamp>_<label>/` using **`createRunContext(experiment, cfg)`** (or, for Aging pipeline only, the **`stage0_setupPaths`** path that calls it — per `run_system.md`).
2. **Resolve the active run directory** with **`getRunOutputDir()`** when already inside a run context.
3. **Write artifacts only via:**
   - **`save_run_figure(fig, baseName, runDir)`** for figures (plus `docs/visualization_rules.md` naming),
   - **`save_run_table(T, filename, runDir)`** for analysis-specific tables under **`tables/`**,
   - **`save_run_report(text, filename, runDir)`** for **`reports/`**,
   - **`export_observables(...)`** (or an explicitly documented equivalent) for the **run-root** observable index **`observables.csv`**,
   - **ZIP** handoff files under **`review/`**.
4. **Do not** introduce new top-level artifact folders (`plots/`, `figs/`, `csv/`, `archives/`, `artifacts/` as parallel trees) — **`results_system.md` rule 13** and **`output_artifacts.md`**.
5. **Exception (explicit):** run-root **`observables.csv`** may be written without `save_run_table` so it is **not** placed under **`tables/`** (`AGENT_RULES.md`, `output_artifacts.md`).

**Incorrect for new agent-style work:** `saveas` / raw `writetable` to arbitrary paths inside a run, **or** writes to **`reports/`** at repo root / module trees for analysis products (example flagged in audit: `scripts/run_adversarial_observable_search.m`).

**Legacy carve-out (policy, not permission to extend):** existing diagnostics and instrument pipelines may keep direct I/O until **touched**; then migrate minimally to the rule above.

---

## 3. Documentation consistency fix

### 3.1 Exact mismatches: `results/README.md` vs authoritative docs

| Topic | `results/README.md` | `docs/results_system.md` / `docs/output_artifacts.md` |
|-------|---------------------|---------------------------------------------------------|
| **Artifact subfolders** | Lists **`csv/`**, **`archives/`**, **`artifacts/`** | Require **`tables/`**, **`review/`** (and **`figures/`**, **`reports/`**). **`results_system.md` explicitly forbids** inventing names like **`archives/`** for new work (rule 13). |
| **Tabular outputs naming** | Implied by **`csv/`** folder | Canonical name is **`tables/`** for machine-readable numeric outputs (other than run-root `observables.csv`). |
| **ZIP / handoff location** | Implied by **`archives/`** | Canonical **`review/`** for ZIP bundles (`output_artifacts.md`). |
| **Historical cross folder name** | Mentions `results/cross_analysis/` as historical | Canonical experiment key is **`cross_experiment`** (`results_system.md`, `repository_structure.md`). Name mismatch risks **wrong path** in new scripts. |

### 3.2 Single source of truth (proposal)

- **Source of truth for run layout and experiment roots:** **`docs/results_system.md`** (per precedence chain).
- **Source of truth for per-run subfolders and roles:** **`docs/output_artifacts.md`** (narrower, same content as the folder table in `results_system.md`).
- **`results/README.md` role:** Short **pointer** only — duplicate **no** second layout; either:
  - **Replace** its folder bullet list with the **exact** four folders + run-root metadata files **copied** from `results_system.md`, **or**
  - **Replace** with “see `docs/results_system.md` § Required run subfolders” and keep only **local policy** (git ignore, no commits).

**Do not** treat `results/README.md` as defining a parallel standard once updated.

---

## 4. Module structure cleanup

### 4.1 Active modules (from `docs/system_registry.json`)

**Unified stack (primary scientific alignment target)**

- `Aging/`
- `Switching/`
- `Relaxation ver3/`
- `analysis/`

**Independent experimental pipelines** (active but **not** required to match unified run helpers today)

- `AC HC MagLab ver8/`, `ARPES ver1/`, `FieldSweep ver3/`, `MH ver1/`, `MT ver2/`, `PS ver4/`, `Resistivity MagLab ver1/`, `Resistivity ver6/`, `Susceptibility ver1/`, `zfAMR ver11/`

**Infrastructure**

- `tools/`, `GUIs/`, `results/`, `surveys/`, `claims/`

**Also listed in `active_modules`**

- Same as above (registry is the union set).

### 4.2 Legacy / overlap “verX” and sibling trees (proposed labeling)

| Location | Proposed status | Action |
|----------|-----------------|--------|
| `Aging old/` | **Legacy snapshot** | **Isolate:** document “do not use for new runs”; no merge unless task asks. |
| `Switching ver12/` | **Legacy Switching** | **Isolate:** new Switching science in `Switching/` + `results/switching/runs/`; keep ver12 for reproduction. |
| `Switching/` (non-ver12) | **Active** unified module | **Stay** as primary Switching code + analyses. |
| `Relaxation ver3/` | **Active** unified module | **Stay**; `* ver3` is version naming, **not** automatic legacy (`AGENT_RULES`). |
| `General ver2/` | **Legacy library** | **Isolate:** reproducibility only; **no new figure dependencies** (`AGENT_RULES`). |
| `Fitting ver1/`, `Tools ver1/`, `HC ver1/`, etc. | **Independent / auxiliary** | **Stay**; align with run system **only when edited** and only if they emit `results/`. |
| `github_repo/` | **Third-party vendored** | **Isolate** from unified conventions unless used directly by unified stack. |

### 4.3 What should be “isolated” (conceptual fence)

- **Legacy reproducibility zones:** `Aging old/`, `Switching ver12/`, `General ver2/`.
- **Independent instruments:** keep **path discipline** (no new outputs inside source trees per `results_system.md`) when those pipelines are extended.
- **Cross-experiment logic:** stays in **`analysis/`**; outputs **must** use `results/cross_experiment/runs/` (already policy).

---

## 5. Minimal migration plan (small, reversible steps)

Each step is **documentation-first** or **single-file / small touch** when you choose to implement later. **No step requires mass moves.**

| Step | Goal | Minimal change | Risk | Reversal |
|------|------|----------------|------|----------|
| **M1** | Remove doc conflict | Edit **`results/README.md`** to match **`docs/results_system.md`** folder names; fix `cross_analysis` → `cross_experiment` or label as typo. | None (docs only). | Git revert. |
| **M2** | Entry discoverability | Add **`runs/README.md`** index listing **supported** launchers (`run_aging.m`, proposed future `runs/unified/*.m`) and pointers to `Main_Aging`, `main_relaxation`, instrument mains. | None (docs only). | Delete file. |
| **M3** | Wrapper consolidation (optional) | For **one** root wrapper, add **`runs/unified/<same_name>.m`** that calls the existing function; keep old file as **one-line forwarder** or leave duplicate until deprecated. | Low; MATLAB path/order must be clear. | Delete new file; restore old usage. |
| **M4** | Fix known non-run output | Refactor **`scripts/run_adversarial_observable_search.m`** (when touched) to **`createRunContext('cross_experiment', ...)`** + **`save_run_report`** (or a run under `results/tests/runs/` if treated as a test artifact). | Medium; needs run config. | Revert commit. |
| **M5** | Unify run factory | In **`analysis/run_unified_barrier_mechanism.m`** (when touched), replace local **`createRun`** with **`createRunContext('cross_experiment', ...)`** + existing **`save_run_*`** or thin adapters. | Medium; verify manifest/log parity. | Revert commit. |
| **M6** | `run_threshold_distribution_model.m` | When touched: replace hard-coded paths with **arguments** or **manifest-driven** `resolve_results_input_dir`-style lookup; add **`createRunContext`** for outputs. | Medium. | Revert commit. |
| **M7** | Diagnostics migration | Pick **one** `Relaxation ver3/diagnostics/*` or `Aging/diagnostics/*` script that still uses **`saveas`/`writetable`**; migrate **only** its outputs to **`save_run_figure` / `save_run_table`** inside an existing or new run. | Low per file; avoid batching many files at once. | Revert single file. |
| **M8** | Registry/doc sync gate | When structure changes per **`AGENT_RULES` Structural Change Gate**, update **`docs/system_registry.json`**, **`docs/repository_map.md`**, etc. | Process cost. | N/A (policy). |

**Suggested order:** **M1 → M2 → M3/M4/M5** as needed, then **M7** opportunistically. **M8** only when you intentionally change module boundaries.

---

## 6. Consolidation map (one-page diagram)

```text
                    ┌─────────────────────────────────────┐
                    │  Target human entry: runs/*.m       │
                    │  (+ docs index in runs/README.md)   │
                    └─────────────────┬───────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          ▼                           ▼                           ▼
   Main_Aging /                  main_relaxation.m          instrument *_main.m
   stage0 → createRunContext     run_relaxation_* →         (independent; align
                                 createRunContext              when touched)
          │                           │
          └─────────────┬─────────────┘
                        ▼
              results/<experiment>/runs/run_<ts>_<label>/
                        │
        ┌───────────────┼───────────────┬───────────────┐
        ▼               ▼               ▼               ▼
    figures/        tables/         reports/         review/
   (save_run_figure)(save_run_table)(save_run_report) (zip)
        │
        └─ run root: run_manifest.json, log.txt, run_notes.txt,
                   config_snapshot.m, observables.csv (index)
```

---

*End of consolidation plan.*
