# Infrastructure broad audit — canonical Switching (design only)

**Date:** 2026-04-03  
**Scope:** Switching-focused execution infrastructure, agent workflows, and documentation. **Excluded:** scientific logic changes, Aging/Relaxation science, code patches (audit and design only).  
**Method:** Static review of `tools/run_matlab_safe.bat`, `Aging/utils/createRunContext.m`, `Switching/analysis/run_switching_canonical.m`, `Switching/analysis/run_minimal_canonical.m`, `docs/templates/matlab_run_template.m`, and normative docs (`docs/repo_execution_rules.md`, `docs/AGENT_RULES.md`, `docs/run_system.md`, `docs/repo_context_infra.md`).

---

## 1. Execution stability

### Verified (post `run()` fix)

- **`tools/run_matlab_safe.bat`** invokes MATLAB with `matlab -batch "run('%SCRIPT_PATH_MATLAB%')"` — script path is forwarded explicitly; aligns with the intended fix away from `eval(fileread(...))`.
- **`run_switching_canonical.m`** emits `disp('SCRIPT_ENTERED')`, creates `run_dir` via `createRunContext('Switching', cfg)`, writes `execution_probe_top.txt` under `run_dir`, writes `execution_status.csv`, probe CSVs, and on failure still attempts status + partial implementation artifacts under a resolved directory before `rethrow`.

### Remaining failure modes and gaps

| Gap | Impact |
| --- | --- |
| Docs still say `eval(fileread(...))` | Agents mis-model debugging and quoting; execution truth is the `.bat` file. |
| No validator call in the wrapper | Documented “mandatory preflight” is not enforced by the batch file; failures move to MATLAB runtime or manual validation. |
| `run_switching_canonical.m` does not write `run_dir_pointer.txt` | `docs/run_system.md` wrapper–run link is not satisfied for the main canonical script (contrast `run_minimal_canonical.m`). |
| `execution_status.csv` column sets differ | Strict contract in `docs/run_system.md` vs `EXECUTION_STARTED` / `WRITE_SUCCESS` / `ERROR` in `run_switching_canonical.m` — downstream tooling may mis-parse. |
| Catch path can target `repoRoot` for status if no `run_dir` | Risk of status outside `results/.../runs/...`, conflicting with “all outputs in run_dir.” |
| Hardcoded `C:/Dev/matlab-functions/execution_probe_top.txt` at script top | Portability and traceability noise; not the same artifact as `run_dir` probe. |

**Silent / ambiguous paths:** MATLAB exit code and console output remain weak signals per `docs/repo_execution_rules.md` — still true; reliance on disk artifacts is correct, but artifact locations must be consistent.

---

## 2. Agent guidance

**Strengths**

- Clear hierarchy in `docs/AGENT_RULES.md` (documentation precedence).
- `docs/repo_execution_rules.md` gives a debug layer order (MATLAB_ALIVE → RUNNER_ENTERED → SCRIPT_ENTERED → WRITE_SUCCESS).

**Weaknesses**

- **`docs/AGENT_ENTRYPOINT.md`** is too minimal to onboard; **`docs/repo_execution_rules.md`** embeds a very long duplicated “master policy” block — high token cost and version drift risk.
- **`docs/context_bundle.json`** mixes scientific claims with structural hints — agents may overweight it for execution routing.
- **No single short “Switching infra-only” anchor** existed; **`docs/repo_context_minimal.md`** is added to fill that gap.

**Where agents are likely to guess**

- Whether `validate_matlab_runnable.ps1` runs automatically (it does not, in current wrapper).
- Whether `run_switching_canonical.m` satisfies `run_system.md` pointer and status schema (partially).
- Experiment folder name casing (`Switching` vs `switching`) when reading `results/`.

---

## 3. Documentation relevance (classification)

| Document / area | Classification | Notes |
| --- | --- | --- |
| `docs/infrastructure_laws.md` | ESSENTIAL | Architecture and forbidden parallel systems. |
| `docs/AGENT_RULES.md` | ESSENTIAL | Agent behavior; **needs correction** on wrapper implementation detail. |
| `docs/repo_execution_rules.md` | ESSENTIAL | Signaling contract; **long** — trim duplicate policy or link out. |
| `docs/run_system.md` | ESSENTIAL (strict contract) | May **overstate** what scripts implement today. |
| `docs/switching_canonical_definition.md` | ESSENTIAL (Switching science boundary) | Keep for canonical meaning; not a substitute for infra truth. |
| `docs/repo_context_infra.md` | OUTDATED / USEFUL hybrid | Describes wrapper steps (fingerprints, post-checks) not in minimal `.bat`. |
| `docs/repo_map.md` | USEFUL | May reference stale paths (`results/README.md`, fingerprints dir). |
| `docs/repository_map.md` vs `docs/repository_structure.md` | USEFUL with overlap | **REDUNDANT** with each other for navigation. |
| `docs/figure_repair_*.md` (cluster) | REDUNDANT for Switching infra | Large; low leverage unless doing figure repair work. |
| Multiple `reports/*execution*.md` | USEFUL / REDUNDANT mix | Narrative audits; token-heavy without an index. |

**Missing critical docs (before this change)**

- Minimal Switching infra context (now: `docs/repo_context_minimal.md`).
- Single “implementation truth” note for `run_matlab_safe.bat` vs older doc language.

---

## 4. Efficiency bottlenecks

- **Repeated audits:** Many Switching robustness and execution reports in `reports/` and `tables/` without a single maintained index — agents re-scan the repo.
- **Duplicated repo discovery:** `run_minimal_canonical.m` walks parents; `run_switching_canonical.m` uses `mfilename` depth; template uses fixed `repoRoot` — three mental models.
- **Long prompts:** `repo_execution_rules.md` master policy block + `AGENT_RULES` + `run_system` — overlapping “MUST” lists.
- **Legacy comparisons:** Scattered legacy vs canonical notes; `docs/switching_canonical_definition.md` should remain the science boundary reference to avoid repeated comparisons in infra tasks.

---

## 5. Guard philosophy

**Current system**

- **Blocks:** Runnable contract rules and ASCII rules are stated harshly (“STOP”, “invalid script”) — good for safety but can push agents into unnecessary loops if not paired with clear soft vs hard boundaries.
- **Silent:** `createRunContext` / `ensureRunStatusFile` can skip some writes quietly on `fopen` failure; wrapper does not post-validate artifacts.

**Target model (non-blocking, traceable)**

- **No pre-run blocking** except critical cases (non-ASCII in runnable file, missing script path, catastrophic safety).
- **Soft warnings:** Validator optional or WARN-only; document exit bucket.
- **Explicit failure classification:** `NO_MATLAB`, `NO_SCRIPT_ENTRY`, `NO_RUN_DIR`, `WRITE_PARTIAL`, `WRITE_OK` — align with debug layers.
- **Post-run validation:** Separate script or agent step that reads `run_dir` artifacts without blocking launch.

---

## 6. Parallel readiness

| Mechanism | Assessment |
| --- | --- |
| Unique `run_*` directories from `createRunContext` | **Good** — primary isolation for outputs. |
| `run_dir_pointer.txt` at repo root | **Unsafe** for concurrent agents — last writer wins. |
| Global `tables/` / `reports/` at repo root | **Risk** if agents write there concurrently. |
| Hardcoded absolute probe paths | **Risk** — shared files across runs/machines. |

**PARALLEL_READY_NOW:** **NO** — shared pointer and global trees need policy + optional run-scoped pointer naming before safe parallel default.

---

## 7. Minimal infrastructure package (design)

Delivered or specified here; **no code enforcement** in this task.

| Artifact | Role |
| --- | --- |
| `docs/repo_context_minimal.md` | **DELIVERED** — short boundary, allowed/forbidden sources, artifacts, phase. |
| Prompt templates `RUN` / `AUDIT` / `FIX` / `PLAN` | **DEFINE:** short (under ~40 lines each), reference `repo_context_minimal.md` + one script path + signaling checklist; store under `docs/templates/` when approved. |
| `tables/agent_warnings_log.csv` | Append-only: timestamp, agent_id, warning_code, path, resolution. |
| `tables/agent_runs_log.csv` | Append-only: timestamp, script, run_dir, wrapper_exit, classification. |
| `reports/system_health.md` | Human index: last verification date for wrapper, validator, canonical scripts, known doc drifts. |

**MINIMAL_PACKAGE_DEFINED:** **YES** (minimal context file created; package table defined; logs specified).

---

## Machine-readable findings

See `tables/infrastructure_broad_audit.csv`.

---

## Summary metrics (for automation)

| Metric | Value |
| --- | --- |
| NUMBER_OF_CRITICAL_ISSUES | 7 |
| NUMBER_OF_REDUNDANT_DOCS | 15 |
| NUMBER_OF_MISSING_GUIDANCE_ITEMS | 8 |
| PARALLEL_READY_NOW | NO |
| MINIMAL_PACKAGE_DEFINED | YES |

**Critical issues counted:** (1) doc vs implementation mismatch on wrapper mechanism, (2) missing automatic validator in wrapper vs documented pipeline, (3) `run_switching_canonical` missing `run_dir_pointer.txt` per strict run contract, (4) `execution_status` schema mismatch across docs and main runner, (5) failure path may write status outside canonical `run_dir`, (6) hardcoded absolute probe path, (7) shared `run_dir_pointer.txt` parallel hazard.

**Redundant docs counted:** approximate count of **REDUNDANT** navigation and out-of-scope **figure_repair** cluster files for Switching infra (see section 3).

**Missing guidance items counted:** pointer contract clarity, unified status schema, validator wiring truth, parallel pointer strategy, experiment key casing, single wrapper truth, minimal prompt templates, activity logs — **8** items.
