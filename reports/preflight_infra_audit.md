# Switching infrastructure pre-flight audit (read-only)

**Scope:** Switching only (no Aging / Relaxation modules as subjects of review). **Date:** 2026-04-04. **Gate:** Hard gate before canonical scientific analysis.

**Method:** Static review of documentation, `tools/switching_canonical_control_scan.ps1`, `Aging/utils/createRunContext.m`, `tools/run_matlab_safe.bat`, `Switching/analysis/run_switching_canonical.m`, representative `Switching/analysis` dependencies, and `tools/switching_canonical_run_closure.m`. No code changes were made.

---

## Verdict

| Criterion | Value |
| --- | --- |
| **INFRA_READY_FOR_ANALYSIS** | **NO** |
| **SOURCE_OF_TRUTH_CLOSED** | **NO** |
| **CONTROL_LAYER_SAFE** | **YES** |
| **LEAKAGE_PRESENT** | **YES** |
| **DOCS_ALIGNED** | **NO** |
| **EXECUTION_STABLE** | **NO** |
| **AGENT_USAGE_SAFE** | **NO** |
| **SILENT_FAILURE_RISK** | **HIGH** |

**Rationale (short):** The **registered canonical entrypoint** (`Switching/analysis/run_switching_canonical.m`) is consistent with the run contract for `run_dir`, signaling artifacts, and **does not** consume repo-root `tables/` or `reports/` as inputs. The **rest of the Switching analysis tree** extensively reads and writes **repo-root** `tables/` and `reports/`, uses **hardcoded absolute paths**, and embeds **cross-run / cross-experiment** paths. That violates the strict gate conditions (no leakage, no ambiguity, no inference, docs aligned, deterministic execution, agents cannot misinterpret). A separate ambiguity exists between **`run_status.csv`** (always initialized with literal `CANONICAL` by `createRunContext`) and **`IS_CANONICAL`** as defined only from **`run_manifest.json` `label`**. **`tools/switching_canonical_run_closure.m`** selects runs by **folder name pattern** `*_switching_canonical`, which conflicts with the manifest-only rule in `docs/switching_backend_definition.md` Section 8.

---

## Artifacts

| Artifact | Path |
| --- | --- |
| Source of truth | `tables/preflight_source_of_truth_check.csv` |
| Control layer | `tables/preflight_control_layer_check.csv` |
| Leakage | `tables/preflight_leakage_report.csv` |
| Isolation | `tables/preflight_isolation_check.csv` |
| Documentation | `tables/preflight_docs_consistency.csv` |
| Execution | `tables/preflight_execution_check.csv` |
| Agent robustness | `tables/preflight_agent_robustness.csv` |
| Failure modes | `tables/preflight_failure_modes.csv` |
| Global status | `tables/preflight_system_status.csv` |

---

## Blocking issues (critical)

1. **Leakage:** Widespread **direct** `readtable` / `fullfile(repoRoot,'tables')` and hardcoded **`C:/Dev/matlab-functions/tables`** usage across `Switching/analysis` (see `tables/preflight_leakage_report.csv`).
2. **Isolation:** Many scripts depend on **fixed historical run ids**, **registry rows**, or **repo aggregate CSVs**, not solely on self-contained `run_dir` artifacts.
3. **Source-of-truth ambiguity:** **`run_status.csv`** vs **`execution_status.csv`** vs manifest **`label`** (`IS_CANONICAL`) — three distinct notions of “status / canonical” (see `tables/preflight_source_of_truth_check.csv`).
4. **Documentation / policy tension:** **`tools/switching_canonical_run_closure.m`** uses **folder-name glob** for canonical runs; **`docs/switching_backend_definition.md`** forbids inferring **IS_CANONICAL** from folder names.
5. **Execution / determinism:** Run identity and fingerprints are **time- and environment-dependent** by design (`datetime`, hostname, user); wrapper contains **unused** `temp_runner` generation with **`%RANDOM%`** (noise for operators, not the main `-batch` argument).

---

## Non-blocking positives

- **`tools/switching_canonical_control_scan.ps1`** (current body) aligns with **manifest-only** `INPUT_SOURCE`, **label-only** `IS_CANONICAL` for drift reporting, and **canonicalization CSV-only** `PARENT_RUN_ID`, with empty fields when absent.
- **`run_switching_canonical.m`** implements **`execution_status.csv`**, **`execution_probe_top.txt`**, **`run_dir`** layout, and **`rethrow`** on failure per strict signaling expectations.

---

## Conclusion

The system is **not** ready for the strict **canonical analysis** gate under the stated success criteria. **Release criteria:** eliminate or quarantine repo-root `tables/`/`reports/` **reads** from Switching analysis paths intended for canonical work; resolve **`run_status.csv`** vs **`IS_CANONICAL`** semantics; align **closure tooling** with **manifest-only** rules; remove hardcoded absolute paths; reconcile **conflicting agent policy** lines in `docs/repo_execution_rules.md` (master policy vs `docs/run_system.md` helper rule).
