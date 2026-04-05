# Runtime execution map (Phase 5C)

This report summarizes **observed** execution entrypoints and coarse signaling hooks. It does not validate runtime success, science correctness, or full compliance with `docs/repo_execution_rules.md`. Source enumeration: `run_*.m` (recursive), plus `*_main.m`; string presence only (no deep static analysis).

## 1. What actually runs in the repo

- **Automated MATLAB runs (policy):** `docs/repo_execution_rules.md` states automated runs use `tools/run_matlab_safe.bat`, which launches `matlab -batch "run('<ABSOLUTE_PATH_TO_SCRIPT.m>')"` after `tools/pre_execution_guard.ps1` checks the script path.
- **Mapped MATLAB files:** `tables/runtime_execution_map.csv` lists **172** rows: **161** files matching `run_*.m`, plus **11** `*_main.m` backend-style files. The `run_*.m` set includes roots such as `tmp/`, `junk/`, `results_old/`, `tools/`, and `GUIs/tests/legacy/` (see path column).
- **Registry-backed Switching entrypoint:** `tables/switching_canonical_entrypoint.csv` names exactly one script: `Switching/analysis/run_switching_canonical.m`. That file is the only row with `classification=CANONICAL` and `trust_level=TRUSTED` in the map.

## 2. Canonical vs non-canonical execution paths

| Classification | Count (rows) | Meaning in this map |
|----------------|--------------|---------------------|
| CANONICAL | 1 | Path matches `tables/switching_canonical_entrypoint.csv`. |
| NON_CANONICAL | 13 | Explicitly listed non-canonical Switching scripts in `tables/switching_noncanonical_scripts.csv` (`Switching/analysis/run_minimal_canonical.m`, `Switching ver12/main/Switching_main.m`), the duplicate basename `run_minimal_canonical.m` at repo root (same basename as the Switching minimal script), and all **11** `*_main.m` files (backend-style; not the registered agent entrypoint). |
| UNKNOWN | 158 | All other `run_*.m` paths: no matching row in the Switching canonical entrypoint table and not in the small NON_CANONICAL list above. |

**Important:** Many `UNKNOWN` paths are still **valid analysis or legacy code**; the label only means “not the registered Switching canonical entrypoint and not flagged NON_CANONICAL by the rules above.”

## 3. Where multiple pipelines exist

Observed **parallel or overlapping routes** (high level):

- **Switching primary vs minimal vs backend:** `Switching/analysis/run_switching_canonical.m` (registry) vs `Switching/analysis/run_minimal_canonical.m` (listed as misleading/test wiring in `tables/switching_noncanonical_scripts.csv`) vs `Switching ver12/main/Switching_main.m` (`addpath(genpath(...))` and local data paths in the file header — not the registered script).
- **Duplicate entrypoint name:** `run_minimal_canonical.m` at repo root vs `Switching/analysis/run_minimal_canonical.m` (same basename; different paths and signaling flags in the map).
- **Relaxation v3:** `Relaxation ver3/run_relaxation_canonical.m` (script; line-level presence of `createRunContext` and `execution_status` in scans) vs `Relaxation ver3/run_relaxation_canonical_script.m` (thin script that calls `run_relaxation_canonical(cfg)` — second way to drive the same logical pipeline).
- **Wrapper vs forbidden wrappers:** Several root `run_*_wrapper.m` files start with `error('FORBIDDEN: Use tools/run_matlab_safe.bat for execution')` (observed line 1 in scans) while other wrappers are comment-only or `function` stubs — multiple “wrapper” patterns coexist.
- **Many `Switching/analysis/run_*.m` names** point at **function** definitions (`function out = ...` on line 1 in the map’s `first`-line capture). Those are **not** the same shape as a pure script entrypoint under the runnable-script contract, even though they share the `run_` prefix.

## 4. Where bypass is possible

`BYPASS_PATHS_FOUND=YES` in `tables/runtime_execution_status.csv` means: **at least one** mapped path can lack one or more of the coarse hooks checked (`createRunContext`/`createSwitchingRunContext`, `execution_status`, `run_dir`/`runDir` text), or can run **outside** the documented wrapper policy.

Examples of **bypass classes** (observed only):

- **No run-context string:** Numerous `run_*.m` rows have `uses_run_context=NO`.
- **No `execution_status` string:** Many rows have `writes_execution_status=NO` (substring search only).
- **No `run_dir`/`runDir` string:** Many rows have `produces_run_dir=NO`.
- **`*_main.m` backends:** All **11** mapped `*_main.m` files show **NO** for all three hooks in substring scans.
- **Direct MATLAB / interactive use:** Policy forbids direct `matlab -batch` for agents; humans or external tools could still invoke scripts or functions outside `tools/run_matlab_safe.bat` — not visible from files alone.
- **Manifest:** `run_manifest` / `run_manifest.json` substring appears in a **subset** of `run_*.m` files only (not required for every mapped row). Full manifest contract is in `docs/infrastructure_laws.md`; this map does not prove manifest writes.

## 5. Trust map of execution

| trust_level | Count (rows) | Interpretation (execution-centric) |
|-------------|--------------|--------------------------------------|
| TRUSTED | 1 | `Switching/analysis/run_switching_canonical.m` — sole registry CANONICAL entrypoint. |
| PARTIAL | 97 | At least one of `uses_run_context`, `writes_execution_status`, or `produces_run_dir` is YES (substring/line-1 scan). |
| UNTRUSTED | 74 | None of the three hooks are YES, or path is under `tools/` (forced UNTRUSTED in map rules), or other high-risk tree (e.g. `junk/`, `tmp/`, `results_old/`). |

**Shadow execution (`SHADOW_EXECUTION_PRESENT=YES`):** Zones where execution **can** occur with **weak or no** repo signaling hooks or **outside** the registered Switching entrypoint — including `junk/`, `tmp/`, `results_old/`, archived/copied run trees, GUI legacy tests, ARPES scripts, backend `*_main.m`, and `run_*.m` files under `tools/` that are helpers, not pipeline scripts.

---

## Artifact index

| File | Role |
|------|------|
| `tables/runtime_execution_map.csv` | Per-entrypoint path, classification, three YES/NO hooks, trust_level, notes. |
| `tables/runtime_execution_status.csv` | Phase 5C rollup flags. |
| `tables/switching_canonical_entrypoint.csv` | Sole CANONICAL Switching script path (agents must not guess). |
| `tables/switching_noncanonical_scripts.csv` | Explicit non-canonical / misleading scripts. |
