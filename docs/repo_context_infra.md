# Repository infrastructure context bundle

**Status:** Consolidated operational view of execution trust, run validity, and enforcement.  
**Scope:** How automated MATLAB runs are supposed to work *as implemented* in this repo, plus normative docs that govern infrastructure.  
**ASCII only.**  
**Precedence:** For infrastructure architecture (run roots, manifests, fingerprints, entrypoints), `docs/infrastructure_laws.md` and `docs/AGENT_RULES.md` override informal notes. This file **synthesizes** those sources with **observed code** in `tools/`.

---

## 1. Canonical execution pipeline (matches `tools/run_matlab_safe.bat`)

| Stage | What happens | Primary implementation |
| --- | --- | --- |
| 1. Invocation | Caller passes one argument resolved to an absolute `.m` path (PowerShell one-liner). | `tools/run_matlab_safe.bat` |
| 2. MATLAB launch | Single call: `matlab -batch "run('<script path with forward slashes>')"` | `tools/run_matlab_safe.bat` |
| 3. Temp file | Creates and deletes `tools/temp_runner.m` (not used as the MATLAB target; harmless). | Same batch file |
| 4. Exit code | Propagates MATLAB `ERRORLEVEL`. | Same batch file |

**Optional (not in the wrapper):** `tools/validate_matlab_runnable.ps1` for manual or CI checks — non-blocking.

**Normative contract (artifacts, manifests, layouts):** `docs/run_system.md`, `docs/results_system.md`.

---

## 2. Run validity model

**Per-run validity:** `docs/run_system.md` (sections 2–8). Run identity is **run-scoped**: `run_dir/run_manifest.json` and artifacts under `run_dir`. **No** repository-root `run_dir_pointer.txt` (deprecated; parallel-unsafe).

**Run factory (MATLAB):** `Aging/utils/createRunContext.m` creates `results/<experiment>/runs/run_<timestamp>_<label>/`, writes `run_manifest.json`, `config_snapshot.m`, seeds `log.txt` / `run_notes.txt`, and computes fingerprint fields via `computeRunFingerprint`.

**Wrapper:** The batch file does **not** read manifests or validate outputs; those are script responsibilities and optional post-hoc checks.

---

## 3. Enforcement points (code vs documentation)

| Rule | Enforced in code | Documented |
| --- | --- | --- |
| Single wrapper entry for agents | Yes: batch file is the only supported path in policy; validator blocks direct `matlab -batch` / `-r` in script text when `VALIDATOR_STATE=canonical` | `docs/repo_execution_rules.md`, `docs/infrastructure_laws.md` |
| Absolute script path, under repo | Yes: `validate_matlab_runnable.ps1` | Same |
| ASCII-only, no BOM (runnable) | Yes: validator counts bytes > 127, checks BOM | `docs/repo_execution_rules.md` |
| Pure script, no `function` | Yes | Same |
| First executable line `clear; clc;` | Yes | Same |
| `createRunContext` in runnable | Yes when `VALIDATOR_STATE=canonical` (else WARN in transitional/legacy_allowed) | `docs/run_system.md` |
| `run_dir_pointer.txt` | **Deprecated / not used** (parallel-safe manifests only) | `docs/run_system.md` section 6 |
| `run_manifest.json` + `execution_status.csv` + csv + md in run_dir | Required by contract; **not** enforced inside minimal batch wrapper | `docs/run_system.md` |
| Manifest fingerprint triple in JSON | Written by `createRunContext` / `writeManifest` | `docs/infrastructure_laws.md`, `docs/run_system.md` |
| No parallel infra / serial infra edits | Policy only (not machine-enforced) | `docs/infrastructure_laws.md` |
| Script execution | **`matlab -batch "run('<path>')"`** per `tools/run_matlab_safe.bat` | `docs/AGENT_RULES.md`, `docs/repo_execution_rules.md` |

**Validator state:** `tools/validate_matlab_runnable.ps1` reads `docs/repo_state.md` for `VALIDATOR_STATE` if present; **if that file is missing**, state defaults to **`canonical`** (strictest). Repository currently may not ship `docs/repo_state.md` (optional control file).

---

## 4. Sources of truth (by topic)

| Topic | Authoritative source |
| --- | --- |
| Infrastructure labels (CANONICAL / LEGACY / …) | `docs/infrastructure_laws.md` PART 1 |
| Agent behavior + doc precedence | `docs/AGENT_RULES.md` |
| Run folder path and artifact layout | `docs/results_system.md`, `docs/output_artifacts.md` |
| Strict run/manifest/pointer/fingerprint contract | `docs/run_system.md` |
| Module layout and transitional zones | `docs/repository_structure.md` |
| **Implemented** wrapper behavior | `tools/run_matlab_safe.bat` |
| **Implemented** runnable checks | `tools/validate_matlab_runnable.ps1` |
| Run listing / manifest loading | `tools/list_runs.m`, `tools/load_run_manifest.m` |
| Run context factory | `Aging/utils/createRunContext.m` |

---

## 5. Trust domains (do not conflate)

Authoritative definitions and gates: **`docs/system_master_plan.md`** (Sections 2, 3, 4, 7).

- **Execution trust** — Wrapper contract, signaling, run roots, manifest/fingerprint **as scoped** to the execution-trust program. Does **not** imply isolation or cross-module enforcement.
- **System trust** — Repository-wide coherence of laws, status, and absence of **false closure** claims; requires both execution-trust and isolation-alignment closure where the program demands it.
- **Isolation trust** — Canonical subsystem boundaries, module registry truth, cross-module policy, and **false-safety** elimination; owned by **Phase 4.5**, not by Phase 4 alone.

**What the wrapper alone guarantees**

- **Wrapper:** A zero exit code means MATLAB returned 0 from `-batch`; it does **not** alone prove physics, complete artifacts, or cross-module safety — check `run_dir` files and audit posture.
- **Manifest:** For runs created through `createRunContext`, `run_manifest.json` records environment and script identity when writes succeed (`git_commit` may be `unknown` on failure). Execution-chain audits may still report identity gaps at the **entry-script** layer; that is an **execution-trust** nuance, not **isolation trust**.

---

## 6. Known limits and doc–code tensions

1. **`required_outputs` shape:** `docs/run_system.md` specifies a nested structure with `tables` / `reports` / `status` keys; `createRunContext` / `writeManifest` may write a **flat list** of paths. Consumers should treat **manifest schema as partially evolving** toward the strict contract.
2. **Registry files described elsewhere:** `docs/knowledge_system_inventory.md` notes `run_index.csv` / `latest_run.txt` under results may be **absent**; discovery is manifest + `tools/list_runs.m` style scanning.

---

## Related documents

- `docs/infrastructure_laws.md` — normative infrastructure architecture  
- `docs/repo_execution_rules.md` — MATLAB agent execution policy  
- `docs/run_system.md` — strict run contract  
- `docs/results_system.md` — results layout  
- `reports/system_formalization_audit.md` — audit and verdicts  
- `docs/system_master_plan.md` — lifecycle phases, gates, cross-module law, trust terminology  
