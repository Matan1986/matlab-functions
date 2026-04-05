# Phase 0–3 Re-Validation Audit (Post-Patch)

**Scope:** Read-only re-check against the authoritative phase model (Phase 0 System Freeze + Boundary; Phase 1 Canonical Definition Switching; Phase 2 Execution System Validation; Phase 3 System Reality Audit). Phase 4 / 4.5 out of scope except where cross-phase consistency references them.

**Method:** Document and code review only; no MATLAB execution; no modification of implementation files. Prior audits are not assumed valid.

**Authoritative inputs:** `docs/repo_execution_rules.md`, `docs/infrastructure_laws.md`, `docs/switching_canonical_definition.md`, `docs/switching_backend_definition.md`, `docs/switching_dependency_boundary.md`, `docs/system_master_plan.md`, `canonical_state_freeze.md`, `tables/switching_canonical_entrypoint.csv`, `tables/system_freeze_status.csv`, `Switching/analysis/run_switching_canonical.m` (excerpt), `tools/run_matlab_safe.bat`, `tools/pre_execution_guard.ps1`, `Aging/utils/createRunContext.m`, `Switching/utils/createSwitchingRunContext.m`, `Switching/utils/writeSwitchingExecutionStatus.m`, plus observed git short status.

---

## 1. Phase 0 — Freeze and boundary

| Field | Value |
| --- | --- |
| **PHASE_0_VALID** | **NO** |

**Findings**

- **Freeze vs drift:** `tables/system_freeze_status.csv` and `reports/system_freeze_status.md` assert `FREEZE_ACTIVE=YES` and restrict unauthorized code change. The current repository working tree shows widespread modifications to tracked files (including `Aging/utils/createRunContext.m` and many `Switching/analysis/*.m`), which is inconsistent with a strict “no drift after freeze” standard unless each change is explicitly out of scope of that freeze—no evidence in this audit reconciles that.
- **Canonical state narrative:** `canonical_state_freeze.md` states cleanup and consolidation are not complete and lists open items (migration, replay formalization, kappa closure). That contradicts treating Phase 0 as a closed boundary for the whole repo.
- **Module boundary:** Documentation clearly separates Switching canonical path from broad Aging (`docs/switching_dependency_boundary.md`: `Aging/utils` only; no `genpath(Aging)`). The canonical runner uses controlled `addpath` and `createSwitchingRunContext` wrapping `createRunContext`. The boundary is **real at documentation and entry-script level**, not a hard compile-time isolation.

**PHASE_0_GAPS**

1. Observable git drift vs declared active freeze.
2. `canonical_state_freeze.md` explicit incompleteness and open migration/replay items.
3. Enforcement of cross-module separation relies on policy and entry scripts, not universal technical prevention of alternate MATLAB path setup.

---

## 2. Phase 1 — Canonical definition (Switching)

| Field | Value |
| --- | --- |
| **PHASE_1_VALID** | **NO** |

**Findings**

- **Uniqueness and stability:** `tables/switching_canonical_entrypoint.csv` registers exactly one canonical path: `Switching/analysis/run_switching_canonical.m`. `tables/switching_entrypoint_lock_status.csv` records `ENTRYPOINT_LOCKED=YES`. `docs/switching_canonical_definition.md` and `docs/switching_backend_definition.md` align on backend identity (Switching ver12) and access rule.
- **Alternative paths:** Many non-canonical scripts remain under `Switching/analysis/`. They are catalogued (e.g. `tables/switching_noncanonical_scripts.csv`, scope tables in backend doc) but are still **executable** if passed to `tools/run_matlab_safe.bat`. The repository prevents misuse by **rules and registries**, not by removing or blocking alternate files at the launcher.

**PHASE_1_GAPS**

1. “No alternative hidden paths” fails under a strict reading: alternate entrypoints exist on disk and are invokable through the same wrapper.
2. Canonical enforcement is **policy-complete**, not **filesystem-closed**.

---

## 3. Phase 2 — Execution system validation

| Field | Value |
| --- | --- |
| **PHASE_2_VALID** | **NO** |

**Findings**

- **Chain:** `tools/run_matlab_safe.bat` resolves the script path, runs `tools/pre_execution_guard.ps1` (filesystem `.m` check; exit 2 skips MATLAB and logs `tables/pre_execution_failure_log.csv`), then `matlab -batch "run('<path>')"`. Matches `docs/repo_execution_rules.md`.
- **Validator:** `tools/validate_matlab_runnable.ps1` is explicitly **not** invoked by the batch file; it is optional governance. If Phase 2 is interpreted as “wrapper → validator → MATLAB,” the automated chain does not include the validator.
- **Manifest and fingerprint:** Normative rules in `docs/switching_backend_definition.md` Section 7 and `docs/infrastructure_laws.md` assign fingerprint material to `run_manifest.json` after a wrapped run. This audit did not execute MATLAB to prove field population for a fresh run.
- **Failures:** `run_switching_canonical.m` failure path writes `execution_status.csv` via `writeSwitchingExecutionStatus` with `FAILED` and `rethrow(ME)`—not silent. Pre-execution failures are explicit (exit code 2, log row).

**PHASE_2_GAPS**

1. Optional validator not in the wrapper—gap if “validator” is mandatory in the Phase 2 chain definition.
2. Manifest/fingerprint completeness not empirically verified in this pass (execution-free audit).

---

## 4. Phase 3 — System reality

| Field | Value |
| --- | --- |
| **PHASE_3_VALID** | **NO** |

**Findings**

- **Execution graph:** `docs/switching_backend_definition.md` acknowledges that `tables/canonical_call_graph.csv` does not list every transitive callee inside large legacy functions.
- **Cross-module law:** `docs/infrastructure_laws.md` PART 7 states cross-module participation is normative but **not operationally closed** until enforcement coverage exists.
- **Determinism:** Run scaffolding and status writes are structured; scientific outputs depend on inputs and MATLAB environment—full deterministic reproduction is not asserted here.

**PHASE_3_GAPS**

1. Incomplete mechanical enumeration of legacy transitive dependencies.
2. Operational cross-module closure not claimed by infrastructure law text.
3. “No hidden dependencies” is not satisfied for the full Switching ver12 closure.

---

## 5. Cross-phase consistency

| Field | Value |
| --- | --- |
| **PHASES_0_3_CONSISTENT** | **NO** |

**Notes:** `docs/system_master_plan.md` records `SYSTEM_CLOSED=NO` and false closure correction at the system level, while machine-readable freeze rows and lock tables suggest a strong locked posture. Phase 0 freeze narrative and observed working-tree drift are in tension. Phase 1’s strict registry uniqueness coexists with many runnable alternatives—a consistency stress unless all stakeholders use the policy reading only.

---

## 6. Final verdict

| Field | Value |
| --- | --- |
| **PHASE_0_3_TRUSTED** | **NO** |

**Failing phases:** Phase 0 (NO), Phase 1 (NO under strict “no alternate paths”), Phase 2 (NO), Phase 3 (NO).

**Minimal blocking issues**

1. **Phase 0:** Drift and incomplete consolidation contradict a closed “freeze + boundary” claim for the repository as a whole.
2. **Phase 1:** Alternate Switching scripts remain valid `.m` targets for the wrapper—canonicality is not mechanically exclusive.
3. **Phase 3:** Legacy call depth and cross-module operational openness are explicitly limited in docs; full system reality is not closed.

---

## Deliverables

| Artifact | Path |
| --- | --- |
| Detailed audit rows | `tables/phase_0_3_revalidation_audit.csv` |
| Summary status | `tables/phase_0_3_revalidation_status.csv` |
| This report | `reports/phase_0_3_revalidation.md` |

**PHASE_0_3_REVALIDATION_COMPLETE=YES**
