# Repository infrastructure context bundle

**Status:** Consolidated operational view of execution trust, run validity, and enforcement.  
**Scope:** How automated MATLAB runs are supposed to work *as implemented* in this repo, plus normative docs that govern infrastructure.  
**ASCII only.**  
**Precedence:** For infrastructure architecture (run roots, manifests, fingerprints, entrypoints), `docs/infrastructure_laws.md` and `docs/AGENT_RULES.md` override informal notes. This file **synthesizes** those sources with **observed code** in `tools/`.

---

## 1. Canonical execution pipeline (actual order)

End-to-end path for an **agent-style** MATLAB run using the approved wrapper:

| Stage | What happens | Primary implementation |
| --- | --- | --- |
| 1. Invocation | Caller passes **one absolute path** to a `.m` runnable script. | `tools/run_matlab_safe.bat` |
| 2. Path checks | Script must exist, be `.m`, be absolute (via embedded PowerShell). | `tools/run_matlab_safe.bat` (lines resolving `SCRIPT_PATH_ABS`) |
| 3. Pre-execution fingerprint | SHA-256 of script file contents; secondary fingerprint over path+hash; file written under `runs/fingerprints/fingerprint_<fp>.txt`; duplicate detection sets `DUPLICATE_RUN`. | `tools/run_matlab_safe.bat` (PowerShell block); output directory `runs/fingerprints/` under repo root |
| 4. Pointer reset | Deletes `run_dir_pointer.txt` at repo root before MATLAB if present. | `tools/run_matlab_safe.bat` |
| 5. Preflight validation | ASCII, header `clear; clc;`, no `function`, repo-local path, `createRunContext` (state-dependent), output patterns, etc. | `tools/validate_matlab_runnable.ps1` |
| 6. MATLAB launch | Starts MATLAB with **`-batch`** and `run('<absolute_script_path>'); exit;` (working directory = repo root). Hard-coded `MATLAB_EXE` with fallback to `matlab.exe` on PATH. **300 s timeout**; non-exit kills process. | `tools/run_matlab_safe.bat` |
| 7. Run discovery | After MATLAB exits, reads **repo-root** `run_dir_pointer.txt` for **one absolute line** = `run_dir`. | `tools/run_matlab_safe.bat` |
| 8. Post-run artifact checks | Requires `execution_status.csv`, `run_manifest.json`, at least one `*.csv`, at least one `*.md` under `run_dir`. | `tools/run_matlab_safe.bat` |
| 9. Drift check (optional) | If `run_manifest.json` has `outputs` field, compares normalized paths to post-run “fresh files” scan under `tables/`, `reports/`, `results/`. | `tools/run_matlab_safe.bat` |
| 10. Global status | Writes `tables/run_status.csv` with `RUN_VALID`, `HAS_OUTPUTS` (fresh outputs anywhere under repo after run start), wrapper exit code echo. | `tools/run_matlab_safe.bat` |

**Normative contract (stricter / different details in places):** `docs/run_system.md` (validator-oriented MUST rules).

---

## 2. Run validity model

A run is **wrapper-valid** when the batch wrapper exits **0** *and* its internal gates pass (including `run_dir` resolution and required run-root files). Separately, **`RUN_VALID` in `tables/run_status.csv`** also requires **fresh outputs** detected under `tables/`, `reports/`, or `results/` after the captured start time — so a technically successful MATLAB exit can still yield `RUN_VALID=NO` if nothing new was written in those trees.

**Per-run validity (scientific / audit):** `docs/run_system.md` defines a valid run as satisfying sections 2–8 (run root layout, manifest schema, `run_dir_pointer`, fingerprints in manifest, etc.). That is the **intended** full contract.

**Run factory (MATLAB):** `Aging/utils/createRunContext.m` creates `results/<experiment>/runs/run_<timestamp>_<label>/`, writes `run_manifest.json`, `config_snapshot.m`, seeds `log.txt` / `run_notes.txt`, and computes fingerprint fields via `computeRunFingerprint` (git commit, calling script path/hash, MATLAB version, host, user).

**Wrapper link:** The runnable script must write repo-root `run_dir_pointer.txt` with the absolute `run_dir` before exit (`docs/run_system.md` section 6). This is **not** written by `createRunContext` itself; the script must do it (example: `Switching/analysis/run_minimal_canonical.m`).

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
| `run_dir_pointer.txt` after run | Yes (wrapper checks file exists and resolves folder) | `docs/run_system.md` |
| `run_manifest.json` + `execution_status.csv` + csv + md in run_dir | Yes (wrapper post-checks) | `docs/run_system.md` |
| Manifest fingerprint triple in JSON | Written by `createRunContext` / `writeManifest` | `docs/infrastructure_laws.md`, `docs/run_system.md` |
| No parallel infra / serial infra edits | Policy only (not machine-enforced) | `docs/infrastructure_laws.md` |
| `eval(fileread(...))` as execution mechanism | **Documentation says this; implementation uses `run('<path>')` via `-batch`** | `docs/AGENT_RULES.md`, `docs/repo_execution_rules.md` vs `tools/run_matlab_safe.bat` |

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

## 5. Trust guarantees (what you can rely on)

- **Wrapper + validator**: A script that passes preflight and completes with exit code 0 has met a **strong static and post-condition bar** (paths, ASCII, structure, presence of core run artifacts, pointer file).
- **Manifest**: For runs created through `createRunContext`, `run_manifest.json` records environment and script identity fields suitable for reproducibility **when git and file reads succeed** (`git_commit` may be `unknown` on failure).
- **Fingerprint files**: `runs/fingerprints/` records script hash and a derived fingerprint for **duplicate run detection** at wrapper level; this is **additional** to manifest fields (not a second manifest system; see `docs/infrastructure_laws.md` exception notes).

---

## 6. Known limits and doc–code tensions

1. **Execution mechanism:** Docs (`docs/AGENT_RULES.md`, `docs/repo_execution_rules.md`) state `eval(fileread(...))`; the wrapper uses **`matlab -batch` with `run('...')`**. Semantics are similar (execute script file) but not identical (e.g. `run` behavior vs `eval` of text).
2. **`required_outputs` shape:** `docs/run_system.md` specifies a nested structure with `tables` / `reports` / `status` keys; `createRunContext` / `writeManifest` currently writes `required_outputs` as a **flat list of absolute paths** to core metadata files. Consumers should treat **manifest schema as partially evolving** toward the strict contract.
3. **`outputs` field for drift check:** Wrapper drift logic expects a manifest field **`outputs`** (array or objects with `path`). If absent, drift may be `UNKNOWN` — not necessarily “no drift.”
4. **Hard-coded repo root in batch file:** `REPO_ROOT=C:\Dev\matlab-functions` in `tools/run_matlab_safe.bat` — portability is not guaranteed by the file alone.
5. **`tables/run_status.csv` `RUN_VALID`:** Tied to **fresh files** in global `tables/`, `reports/`, `results/` — not strictly “manifest valid only.”
6. **Registry files described elsewhere:** `docs/knowledge_system_inventory.md` notes `run_index.csv` / `latest_run.txt` under results may be **absent**; discovery is manifest + `tools/list_runs.m` style scanning.

---

## Related documents

- `docs/infrastructure_laws.md` — normative infrastructure architecture  
- `docs/repo_execution_rules.md` — MATLAB agent execution policy  
- `docs/run_system.md` — strict run contract  
- `docs/results_system.md` — results layout  
- `reports/system_formalization_audit.md` — audit and verdicts  
