# Infrastructure overview — refined (Phase 5A.3 FIX)

Source: **only** `tables/infrastructure_components_map.csv` (no rescan, no extra files). Original `type` is preserved; new columns drive the execution-system model.

## What changed from the original map

- **`infra_layer`** groups components into **CORE_*** buckets (execution, identity, validation, IO) versus **SUPPORT_INFRA**, **GOVERNANCE**, **ENV_NOISE**, and **LEGACY**.
- **`is_live_path`**, **`relevance`**, and **`system_critical`** distinguish the runtime chain from templates, docs, caches, and agent-specific orchestration.
- **Run aggregates** are **not** split into new rows; each aggregate row’s **`suspected_role`** now encodes **ENTRYPOINT_CANDIDATE** / **ANALYSIS_RUN** / **TEST_RUN** / **UNKNOWN_RUN** (name/path-only, no code read).
- **Notes** were shortened to **structural** phrases (mostly 3–6 words).
- **Markdown** rows → **`GOVERNANCE`** (except under **`results_old`** → **`LEGACY`**). **`tmp` / `junk` / logs / caches** → **`ENV_NOISE`** where those paths appear in the original map.

## Core execution system (identified)

The following are consistently marked **`infra_layer` ∈ {CORE_EXECUTION, CORE_IDENTITY, CORE_VALIDATION, CORE_IO}**, **`is_live_path` = YES**, and **`system_critical` = YES** where the role is core:

| Role | Examples (from map paths) |
|------|---------------------------|
| **Wrapper / entry** | `tools/run_matlab_safe.bat` (also listed as `run_*.bat` aggregate row) |
| **Validators** | `repo_state_validator.m`, `tools/validate_matlab_runnable.ps1`, `tools/pre_execution_guard.ps1` |
| **Run identity** | `Aging/utils/createRunContext.m`, `Switching/utils/createSwitchingRunContext.m`, `Switching/utils/allocateSwitchingFailureRunContext.m`, `Switching/utils/switchingCanonicalRunRoot.m`, fingerprint scripts `tools/generate_run_fingerprint.ps1`, `tools/run_fingerprint.ps1`, `tools/load_run_manifest.m`, `tools/run_review/generate_run_review_manifests.m` |
| **Asserts** | `Switching/utils/assertModulesCanonical.m`, `Switching/utils/assertSwitchingRunDirCanonical.m` |
| **Execution status / markers / bootstrap** | `Switching/utils/writeSwitchingExecutionStatus.m`, `tools/write_execution_marker.m`, `tools/init_run_output_dir.m` |
| **Main `run_*.m` trees** | Aggregates for `Switching/analysis/`, `analysis/`, `Relaxation ver3/`, repository root — **`CORE_EXECUTION`**, **`system_critical` = YES** for the three subtrees; root aggregate is **mixed** entry vs analysis (see ambiguities). |

## Noise and governance

- **Governance / non-runtime docs**: Markdown under `reports/` and `docs/` (guardrail descriptions), plus `docs/templates/matlab_run_template.m` as **template** (**`GOVERNANCE`**, **`is_live_path` = NO**).
- **Legacy**: `results_old/.../documentation_guardrails_update.md` → **`LEGACY`**.
- **Environment noise**: `tools/_agent24a_result.json`, `tools/runner_probe_*.txt`, and the **`run_*.m` miscellaneous locations** aggregate (**`ENV_NOISE`**).
- **Supporting orchestration**: Most `tools/*.ps1` / `.py` “agent” pipelines are **`SUPPORT_INFRA`**, **`system_critical` = NO** — useful runs, not the minimal core chain.

## Remaining ambiguities

- **Directory aggregates** still lump many scripts; **ENTRYPOINT_CANDIDATE** vs **ANALYSIS_RUN** is resolved only at folder level (e.g. repository root is explicitly **mixed**).
- **`SUPPORT_INFRA` vs `CORE_IO`** for some `tools/` IO helpers is judgmental without opening implementations.
- **`tests/infrastructure/*`** and **`test_execution_probe.m`** are validation-adjacent; **`system_critical`** is **NO** except where the core list above overrides.
- **Figure-repair** and **survey** tooling spans validation + IO; only repair **validation suite** rows are **`CORE_VALIDATION`**.

## Phase 5 continuation

**Is infrastructure understanding sufficient for Phase 5 continuation?**  
**Yes** — the **core execution chain** (batch wrapper, MATLAB validators/guards, Switching/Aging run context + asserts, execution status and markers, main `run_*.m` trees) is **explicitly identified** and separated from **governance**, **legacy**, **noise**, and **agent orchestration**. Residual uncertainty is **bounded** to aggregate rows and non-critical `tools/` helpers, which does **not** block Phase 5 work that anchors on the core rows above.
