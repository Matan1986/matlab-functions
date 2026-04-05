# Phase 3.1 — Overblocking Audit (Switching canonical execution)

**Scope:** Canonical Switching execution only: `tools/run_matlab_safe.bat` → `Switching/analysis/run_switching_canonical.m`, with `Aging/utils/createRunContext.m` on the direct call chain.  
**Method:** Read-only synthesis from `tables/system_execution_map.csv`, `tables/artifact_lineage_map.csv`, `tables/source_of_truth_map.csv`, `tables/runtime_stage_map.csv`, `tables/io_behavior_map.csv`, `tables/parallelization_map.csv`, `tables/system_reality_risks.csv`, `tables/system_reality_status.csv`, `reports/system_reality_audit.md`, and the listed tooling/script sources. No MATLAB runs, no code edits.  
**Date:** 2026-04-04.

---

## Executive summary

The **live runtime blocking chain** for automated Switching runs is **lean**: `run_matlab_safe.bat` runs `pre_execution_guard.ps1`, which performs a **filesystem-only** hard stop (exit code 2) when the resolved target is not an existing `.m` file; then a **single** `matlab -batch "run('<ABS>/run_switching_canonical.m')"` runs. **`tools/validate_matlab_runnable.ps1` is not invoked by the wrapper** and therefore does **not** gate execution.

**Overblocking on the live launch path** (unnecessary blocks beyond identity, determinism, boundary, and artifact truth) is **not** observed: the guard is minimal and aligned with `docs/repo_execution_rules.md`.

What makes the **overall blocking model “mixed and confusing”** is mostly **off-path** or **non-effectual** machinery: (1) the batch file **creates a `temp_runner_*.m` that is never executed** (dead / misleading); (2) the optional validator **always exits 0**, including when its internal logic would “block”; (3) **validator heuristics** (e.g. `CHECK_DRIFT` forbidding `fopen`…`.txt`) **conflict with the repository signaling contract** that requires `execution_probe_top.txt` for the canonical script. Those issues create a **false sense of protection** or **governance drift**, not extra MATLAB runtime blocks from the wrapper.

**Remediation of tooling** is **not warranted solely from this audit** for the live wrapper chain; clarifying or fixing validator/temp-runner behavior is a **deferred** governance/UX concern unless Phase 3.2 explicitly scopes it.

---

## Actual live blocking chain (Switching canonical)

```
Operator/automation
  -> tools/run_matlab_safe.bat "<ABS>\...\run_switching_canonical.m"
       -> PowerShell path resolution (cwd if arg empty)
       -> tools/pre_execution_guard.ps1 "%SCRIPT_PATH_RESOLVED%"
            -> exit 2 => MATLAB NOT launched; log tables/pre_execution_failure_log.csv
            -> exit 0 => continue
       -> matlab -batch "run('<ABS>/run_switching_canonical.m')"
  -> Switching/analysis/run_switching_canonical.m (script, try/catch)
       -> Aging/utils/createRunContext('Switching', cfg)
       -> legacy pipeline + analysis; errors => FAILED artifacts + rethrow
```

**Not on this chain:** `tools/validate_matlab_runnable.ps1` (manual/optional per `docs/repo_execution_rules.md` and `tables/system_execution_map.csv`).

---

## Table of blocking classes

| Class | Where observed | On live path? | Typical intent |
|--------|----------------|---------------|----------------|
| Hard block (pre-MATLAB) | `pre_execution_guard.ps1` | Yes | Invalid / non-`.m` target |
| Dead / non-executed | `temp_runner_*.m` in batch | N/A (not passed to MATLAB) | Appears probe-related; unused |
| Governance-only | `validate_matlab_runnable.ps1` | No (wrapper) | Template/drift checks |
| Pseudo-block (exit 0) | `validate_matlab_runnable.ps1` FailValidation | If invoked manually | No process-level failure signal |
| Hard stop (in-MATLAB) | `run_switching_canonical.m` `error(...)` | Yes | Data/layout/identity |
| Artifact / IO hard stop | `createRunContext.m` `error` on fopen | Yes | Manifest/log/snapshot |
| Soft skip / ambiguity | Manifest exists → `warning` + return | Yes | Preserve existing manifest |
| Conditional numeric branch | Optional `resolve_preset` / `resolveNegP2P` | Yes | Environment-dependent truth |

Full row-level register: `tables/overblocking_audit.csv`.

---

## Validator status vs live path

| Question | Finding |
|----------|---------|
| Invoked by `run_matlab_safe.bat`? | **No** (`tables/system_execution_map.csv`; `reports/system_reality_audit.md`). |
| Blocks MATLAB launch via exit code when “failing”? | **No** — `FailValidation` and success both **`exit 0`** (`tools/validate_matlab_runnable.ps1`). |
| Still relevant as governance? | **Partially** — useful as optional lint if humans interpret text output; **not** runtime enforcement. |
| Consistent with canonical Switching script? | **Problematic** — e.g. `CHECK_DRIFT` treats `fopen`…`.txt` as drift; canonical script **must** create `execution_probe_top.txt` per signaling contract (`docs/repo_execution_rules.md` “Execution Signaling Contract”). |

**Conclusion:** Validator logic is **not bypassed** by the wrapper; it is **out of the live execution path**. When run, it is **not** a reliable gate (always exit 0) and can **mis-classify** the canonical script.

---

## Guard status vs live path

| Question | Finding |
|----------|---------|
| Blocks only invalid script paths? | **Yes** — empty/unresolvable/non-file/non-`.m` → exit 2. |
| Blocks more than necessary for launch truth? | **No** for stated contract (single `.m` script path). Does **not** duplicate full validator (no repo-root rule, no content scan). |
| Important gaps relative to policy docs? | **By design** — no MATLAB executable verification, no ASCII scan in guard (ASCII is **agent policy** in `docs/repo_execution_rules.md`, not batch-enforced). |

**Conclusion:** **Appropriately scoped** for a pre-MATLAB filesystem gate.

---

## False-protection analysis

| Issue | Evidence | Effect |
|-------|----------|--------|
| Validator “failure” does not fail the process | `FailValidation` → `exit 0` | CI/scripts using exit codes may **assume success** |
| Temp runner never run | `run_matlab_safe.bat` writes `temp_runner_*.m`, then calls `matlab -batch` with **only** `MATLAB_COMMAND` | **No** `RUNNER_ENTERED` proof from that file |
| Drift rule vs signaling | Validator `fopen`…`.txt` heuristic vs `execution_probe_top.txt` | Canonical script **would** trip `CHECK_DRIFT` if that rule were authoritative |
| Manifest skip | `writeManifest` returns if file exists | **Not** a block; can **blur** identity if folder reused (`tables/system_reality_risks.csv` R6) |

---

## Justified enforcement (and why)

- **Pre-execution guard:** Prevents `matlab -batch` when the target is not a concrete `.m` file — supports **artifact integrity** (no run of nonsense `run()` target) and matches **documented** wrapper behavior (`docs/repo_execution_rules.md`).
- **Strict `which('createRunContext')` path check:** Protects **identity** and **boundary** — ensures the run manifest/fingerprint path comes from repo `Aging/utils/createRunContext.m`, not an arbitrary shadow on the path (`run_switching_canonical.m`).
- **Legacy root / `Switching_main` / `Temp Dep` / metadata errors:** Protect **data validity** and **reproducible** Switching aggregation — failures are **meaningful** “no physics” stops, not stylistic blocks.
- **`createRunContext` fopen errors:** Protect **artifact integrity** for manifest, snapshot, and log.

---

## Overblocking (live path)

**None identified** on the **wrapper → guard → MATLAB** chain: the guard does not add repo membership, ASCII, or template checks that would block **valid** canonical execution beyond “script file exists and is `.m`.”

**Governance over-strictness** (validator rules vs canonical script) is **not** live-path overblocking; it is **misleading** if treated as authoritative for this pipeline.

---

## Dead, duplicated, or misleading enforcement

- **Dead:** `temp_runner_*.m` creation (`tables/system_reality_risks.csv` R1).
- **Duplicated (conditional):** Filesystem existence / `.m` checks appear in both **guard** and **validator preconditions** if an operator runs both — same concern, two layers.
- **Misleading:** Validator exit code always 0; drift heuristic conflicts with required `.txt` probe file.

---

## Uncertainty

- **Exact operator usage** of `validate_matlab_runnable.ps1` in external automation is not visible from repo artifacts alone; impact is classified as **governance risk**, not runtime risk for the canonical wrapper.
- **Whether** any wrapper fork exists outside this repo is **out of scope**; this audit is **repository-truth** only.

---

## Remediation: now or deferred?

- **Live wrapper + guard:** No remediation **required** from an overblocking perspective; behavior matches **Phase 3.0** reality.
- **Validator / temp runner / manifest warning:** **Deferred** unless a later phase scopes **governance alignment** (validator vs signaling contract, exit codes, dead batch lines).

---

## Deliverables

| File | Role |
|------|------|
| `tables/overblocking_audit.csv` | One row per blocking / pseudo-blocking / ambiguity point |
| `tables/overblocking_summary.csv` | Per-component roll-up |
| `tables/overblocking_status.csv` | Single-row verdict |
| `reports/overblocking_audit.md` | This narrative |

---

## References (read-only)

- `docs/repo_execution_rules.md`
- `reports/system_reality_audit.md`
- `tables/system_execution_map.csv`, `tables/system_reality_risks.csv`
- `tools/run_matlab_safe.bat`, `tools/pre_execution_guard.ps1`, `tools/validate_matlab_runnable.ps1`
- `Switching/analysis/run_switching_canonical.m`, `Aging/utils/createRunContext.m`
