# Enforcement coverage map (Phase 5D)

Read-only synthesis from **observable patterns**, Phase 5C runtime artifacts (`reports/runtime_execution.md`, `tables/runtime_execution_map.csv`, `tables/runtime_execution_status.csv`), registry tables, and existing reports (`reports/run_validity_layer.md`, `reports/phase45_final_validation.md`, `reports/overblocking_audit.md`). No code paths were executed for this map.

---

## 1. All enforcement mechanisms

| Mechanism | Role | Where it applies (observed) |
| --- | --- | --- |
| **Wrapper** | `tools/run_matlab_safe.bat` invokes MATLAB once with `run('<ABS>.m')` after | Any launch that uses the wrapper |
| **Pre-execution guard** | `tools/pre_execution_guard.ps1` — refuse launch if script path not a resolvable `.m` file | Only when the batch wrapper runs (exit 2, MATLAB not started) |
| **Validator** | `tools/validate_matlab_runnable.ps1` — structured checks on script source | Optional; **not** called by the wrapper (`docs/repo_execution_rules.md`) |
| **assertModulesCanonical** | Throws if listed modules non-canonical per registry CSV | `Switching/analysis/run_switching_canonical.m` (only when `length(modules_used) > 1`); `Switching/analysis/analyze_phi_kappa_canonical_space.m` (explicit `{'Switching'}`) — grep-visible callsites only |
| **assertSwitchingRunDirCanonical** | Asserts run directory under canonical switching runs tree | Invoked via `createSwitchingRunContext` callback (`Switching/utils/createSwitchingRunContext.m`) when that context path is used |
| **Canonical entrypoint restriction** | Policy + `tables/switching_canonical_entrypoint.csv` — single registered Switching script | Documentation/agents; not a second filesystem gate beyond choosing which `.m` to pass to the wrapper |
| **run_validity layer** | `writeRunValidityClassification` → `run_dir/run_validity.txt` | Called from `run_switching_canonical.m` success/failure paths; **detection-only**, never blocks (`reports/run_validity_layer.md`) |
| **execution_status system** | `writeSwitchingExecutionStatus` → `execution_status.csv` schema | Switching canonical runner and some other Switching scripts; contract in `docs/execution_status_schema.md` for canonical placement |
| **repo_state_validator.m** | Repo-level validation (infrastructure overview) | Separate from MATLAB batch chain; not mapped as live execution gate here |

---

## 2. Where enforcement is strong

- **Wrapper + pre-execution guard:** For runs that **use** `tools/run_matlab_safe.bat`, an invalid or missing script path is **not** passed to MATLAB (filesystem gate). This does **not** validate script semantics, templates, or module policy.
- **createSwitchingRunContext + assertSwitchingRunDirCanonical:** When analysis uses this context factory, run directory placement is asserted for that code path (throws on violation).

---

## 3. Where enforcement is partial

- **Canonical Switching runner (`run_switching_canonical.m`):** Combines registry reads, optional `assertModulesCanonical` (only multi-module list), Switching execution status writes, and run_validity **annotation**. Default single-module configuration **does not** invoke `assertModulesCanonical` (documented in `reports/phase45_final_validation.md`).
- **Optional validator:** Can surface template and static issues if run manually, but is off the automated wrapper path and must not be treated as equivalent to the guard.

---

## 4. Where enforcement is only detection

- **run_validity (`run_validity.txt`):** Classifies CANONICAL / NON_CANONICAL / INVALID after the fact; does not block, alter `execution_status.csv`, or change outcomes (`reports/run_validity_layer.md`).
- **execution_status.csv as audit signal:** Proves signaling for runs that write it; absence of a global verifier means “file exists” is not automatically guaranteed across all `run_*.m` paths.

---

## 5. Where nothing (or almost nothing) exists

- **Legacy backends** (`Switching ver12/`, `*_main.m` as mapped): Substring hooks largely absent in Phase 5C map for `*_main.m` rows.
- **UNKNOWN and shadow zones** (`junk/`, `tmp/`, `results_old/`, and similar): Execution may occur without run_context / execution_status / run_dir hooks (`reports/runtime_execution.md` shadow execution).
- **Direct MATLAB invocation:** Policy forbids for agents; no repository-side block if the wrapper is skipped.

---

## 6. Final trust map

| Class | Meaning |
| --- | --- |
| **ENFORCED** | Wrapper guard path **and**, for Switching runs using `createSwitchingRunContext`, run_dir assertion on that path. Safe **only** for those specific mechanisms—not full science or template compliance. |
| **MONITORED** | `run_validity.txt`, `execution_status.csv` where written, optional validator stdout — visibility and post-hoc classification, not guaranteed blocking. |
| **UNCONTROLLED** | Majority of mapped `run_*.m` / backend / shadow paths with no module assert, no canonical run_dir hook, or launch outside wrapper — aligns with `BYPASS_PATHS_FOUND=YES` and `SHADOW_EXECUTION_PRESENT=YES` in `tables/runtime_execution_status.csv`. |

---

## Artifact index

| File | Role |
| --- | --- |
| `tables/enforcement_coverage_map.csv` | Per-zone and entrypoint-class enforcement mapping |
| `tables/enforcement_status.csv` | Rollup flags |
| `reports/enforcement_map.md` | This narrative |
