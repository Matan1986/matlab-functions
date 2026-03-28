# Infrastructure laws (normative)

**Status:** Canonical specification for repository infrastructure architecture.  
**Scope:** Run roots, manifests, execution fingerprints, MATLAB entrypoints, output ownership, drift taxonomy, and consolidation gates.  
**ASCII only.**  
**Source material:** `docs/repo_audit_report.md`, `docs/repo_consolidation_plan.md`, `docs/run_system.md`, `docs/results_system.md`, `docs/knowledge_system_inventory.md`.

This document exists to prevent accidental creation of parallel execution paths, manifest systems, or fingerprint conventions. Code implements what docs require; validators (when added) enforce what docs define.

---

## PART 1 - Canonical decisions

Labels:

- **CANONICAL** - The only allowed pattern for new work and for any touched code paths.
- **LEGACY** - Preserved for reproducibility; must be explicitly marked in docs or run notes; do not extend.
- **DEPRECATED** - Scheduled for replacement or removal; no new dependencies.
- **FORBIDDEN FOR NEW WORK** - Must not appear in new scripts, wrappers, or automation.

### Run root

| Label | Path / pattern |
| --- | --- |
| **CANONICAL** | `results/<experiment>/runs/run_<timestamp>_<label>/` as defined in `docs/results_system.md` and `docs/run_system.md`. Experiment key `<experiment>` must match conventions in those docs (e.g. `aging`, `relaxation`, `switching`, `cross_experiment`). |
| **LEGACY** | Flat or historical subtrees under `results/<experiment>/` that predate the run-folder model (see `docs/results_system.md` historical notes). |
| **DEPRECATED** | Ad-hoc subfolders under `results/` that duplicate experiment names with different spelling (e.g. mixed `cross_analysis` vs `cross_experiment`) when called out in audits. |
| **FORBIDDEN FOR NEW WORK** | Writing analysis products to repo-root `reports/`, `figures/`, `tables/`, or inside module source trees (`Aging/`, `Relaxation ver3/`, `Switching/`, versioned `* verX/` pipelines) except where a doc explicitly allows a debug or test path. |

### Run manifest filename and schema

| Label | Definition |
| --- | --- |
| **CANONICAL** | Single file per run: `run_manifest.json` at the **run root** only. Authoritative field set and roles: `docs/run_system.md` (conceptual) plus the **implemented** contract produced by `createRunContext` / `writeManifest` (including but not limited to: `run_id`, `timestamp`, `execution_start`, `experiment`, `label`, `git_commit`, `matlab_version`, `host`, `user`, `repo_root`, `run_dir`, `script_path`, `script_hash`, `required_outputs`, `manifest_valid`, optional `dataset`). JSON encoding; machine-readable. |
| **LEGACY** | Runs missing `run_manifest.json` or with incomplete fields from older executions. |
| **DEPRECATED** | Any alternate per-run metadata filename intended to replace `run_manifest.json` without a repo-wide migration plan. |
| **FORBIDDEN FOR NEW WORK** | A second parallel per-run manifest system (e.g. `manifest.json` at run root for the same role, or experiment-specific renamed manifest files) for the unified stack without an approved migration and doc update. **Exception:** unrelated manifests in other scopes (snapshot ZIP META, survey indices) are different systems; they must not duplicate **run identity** for `results/.../runs/...`. |

### Execution fingerprint system

| Label | Definition |
| --- | --- |
| **CANONICAL** | **Provenance triple** recorded in or derived from `run_manifest.json`: (1) `git_commit` for repository state, (2) `script_hash` (SHA-256 of resolved calling script path content) for executed entry script identity, (3) `matlab_version` / `host` / `user` for environment. Optional `dataset` when present. This is the single fingerprint story for "what ran." |
| **LEGACY** | Runs with `git_commit` unknown or empty; missing `script_hash` if created before that field existed. |
| **DEPRECATED** | Relying only on folder name or wall-clock time without manifest fields for reproducibility claims. |
| **FORBIDDEN FOR NEW WORK** | A second fingerprint scheme for the same run (e.g. alternate hash algorithm file alongside manifest for the same purpose) without consolidation. **Note:** `config_snapshot.m` is configuration capture, not a substitute for the manifest fingerprint fields. |

### Execution entrypoint (automated / agent MATLAB runs)

| Label | Definition |
| --- | --- |
| **CANONICAL** | `tools/run_matlab_safe.bat "<ABSOLUTE_PATH_TO_SCRIPT.m>"` with a **pure script** runnable per `docs/repo_execution_rules.md`. |
| **LEGACY** | Interactive `matlab` sessions, direct `matlab -batch` / `-r` in old notes, or module-internal mains invoked without the wrapper where history predates the rule. |
| **DEPRECATED** | Entry patterns explicitly flagged in `docs/repo_consolidation_plan.md` (e.g. repo-root `run_*_wrapper.m` proliferation) until moved or documented as shims. |
| **FORBIDDEN FOR NEW WORK** | New automation that bypasses `run_matlab_safe.bat` for agent/repo runs; new inline command-string execution styles forbidden by `docs/repo_execution_rules.md`. |

### Output ownership policy

| Label | Definition |
| --- | --- |
| **CANONICAL** | All run artifacts live **under** the active run directory tree (`figures/`, `tables/`, `reports/`, `review/`, run-root metadata and `observables.csv` per `docs/output_artifacts.md` / `docs/results_system.md`). Creation flows through `createRunContext` (or documented module equivalent that calls it) and `save_run_figure` / `save_run_table` / `save_run_report` / `export_observables` as in `docs/AGENT_RULES.md`. |
| **LEGACY** | Direct `writetable` / `saveas` in diagnostics and older pipelines until touched. |
| **DEPRECATED** | `General ver2/` figure stack for new figures (`docs/AGENT_RULES.md`). |
| **FORBIDDEN FOR NEW WORK** | **Global run outputs:** writing new analysis products to repo root `reports/`, undifferentiated `figures/` at repo root, or module folders as the primary sink for agent-style analyses. |

---

## PART 2 - Infrastructure laws (strict)

1. **One canonical run system** - New run-scoped work uses `createRunContext` and paths under `results/<experiment>/runs/...` only. No second run factory for the same purpose (see audit: parallel `createRun` patterns).

2. **No parallel manifest systems** - One manifest filename (`run_manifest.json`) and one schema role per run root for unified-stack evidence.

3. **No parallel fingerprint systems** - Do not introduce alternate git/hash/host records for the same run without extending the canonical manifest (single JSON).

4. **No global run outputs** - Analysis agents do not treat repo-root or module trees as the default output sink (`docs/AGENT_RULES.md`).

5. **No infra change without discovery report** - Before changing wrappers, manifest writers, path resolution, or run helpers, an infra agent must produce the pre-change report (PART 3) and identify drift risk.

6. **Docs define architecture; validators enforce it** - This document and `docs/results_system.md` / `docs/run_system.md` are the contract. Future CI or MATLAB checks must trace to these docs.

7. **Legacy systems must be explicitly marked** - Undeclared legacy paths are a violation (UNDECLARED_LEGACY_PATH).

8. **Serial infra edits** - One infrastructure agent at a time; no parallel infra modifications (`docs/repo_execution_rules.md`).

9. **Analysis agents read-only on infra** - Analysis agents do not change execution method, wrapper, or global path policy.

---

## PART 3 - Agent enforcement (pre-change report)

Every infrastructure agent must produce the following **before** changing behavior, wrappers, or shared helpers:

| Field | Content required |
| --- | --- |
| **EXISTING_SYSTEMS_FOUND** | List: current run root pattern, manifest writer/reader, fingerprint fields, wrappers, any alternate factories (`createRun`, bespoke manifests). |
| **CANONICAL_COMPONENT** | Which single component is canonical per PART 1 (cite path or doc). |
| **DUPLICATION_RISK** | Whether the change could create a second path, second manifest, or second fingerprint scheme. |
| **REUSE_PLAN** | How the change extends or calls the canonical component instead of forking. |
| **FILES_TO_TOUCH** | Exact list; no scope creep. |
| **WHY_NEW_SYSTEM_IS_NOT_BEING_CREATED** | One paragraph: why consolidation into existing infrastructure is sufficient. |

If **WHY_NEW_SYSTEM_IS_NOT_BEING_CREATED** cannot be answered, stop: the task may require a design review, not a new parallel system.

---

## PART 4 - Drift violations (taxonomy)

| Code | Definition | Severity | Required action |
| --- | --- | --- | --- |
| **MULTIPLE_RUN_ROOTS** | Two or more incompatible directory conventions for the same experiment's new runs (e.g. flat `results/foo/` vs `results/foo/runs/run_*`). | High | Pick CANONICAL root; migrate or mark LEGACY; document in `docs/results_system.md` or experiment notes. |
| **MULTIPLE_MANIFEST_SYSTEMS** | More than one machine-readable run identity file at the same run root, or competing schemas for the same role. | High | Single writer to `run_manifest.json`; deprecate alternates; update `tools/load_run_manifest.m` contract if needed. |
| **MULTIPLE_FINGERPRINT_SYSTEMS** | Competing definitions of "what ran" (e.g. duplicate hash files, inconsistent `git_commit` vs separate shadow registry). | High | Unify on manifest fields in PART 1; remove shadow systems. |
| **GLOBAL_OUTPUT_WRITE** | New analysis artifacts defaulting to repo root or module dirs instead of a run folder. | High | Redirect to run tree; fix entry script; document exception if truly test-only. |
| **EXECUTION_PATH_DRIFT** | New automation not using `run_matlab_safe.bat` or new direct `matlab -batch` for agent runs. | Critical | Revert to wrapper; update `docs/repo_execution_rules.md` only through deliberate policy change. |
| **UNDECLARED_LEGACY_PATH** | A script or doc references a second tree (`Switching ver12/`, flat `results/...`) without LEGACY label for new contributors. | Medium | Add explicit LEGACY markers in docs or file headers; point to canonical tree. |
| **DOC_CODE_DRIFT** | Docs promise files (`run_index.csv`, `latest_run.txt`) or layouts that code or disk do not implement consistently. | Medium | Fix docs or implement; track in consolidation gate. |

---

## PART 5 - Consolidation gate (preconditions before code consolidation)

No mass refactor, wrapper move, or manifest schema break may begin until **all** of the following are true:

1. **Laws locked** - This document (PART 1-2) is committed and referenced from `docs/AGENT_RULES.md` and `docs/repo_execution_rules.md`.

2. **Canonical components named** - `createRunContext`, `run_manifest.json`, manifest fingerprint fields, `run_matlab_safe.bat`, and artifact helpers are explicitly CANONICAL in writing.

3. **Discovery complete** - `EXISTING_SYSTEMS_FOUND` inventory for the touched area matches audit reality (no unknown second factories).

4. **Legacy explicit** - LEGACY and DEPRECATED paths for entrypoints and results are listed (at least pointer to `docs/repo_consolidation_plan.md` / audit).

5. **Doc-code parity plan** - Known doc-code gaps (`results/README.md` vs `output_artifacts.md`, missing `run_index.csv` on disk, etc.) are either fixed in docs or have a tracked implementation ticket.

6. **Single serial owner** - One infrastructure agent or human owns the consolidation batch; no parallel conflicting PRs.

Until the gate passes, only **minimal** edits (bugfixes, single-file alignment) are allowed; no repository-wide consolidation.

---

## PART 6 - Minimal rollout plan (order of operations)

1. **Lock laws** - Adopt `docs/infrastructure_laws.md` and precedence in `docs/AGENT_RULES.md`.

2. **Update execution rules** - Ensure `docs/repo_execution_rules.md` references infrastructure laws and forbids parallel infra.

3. **Update agent rules** - Infra agent checklist (PART 3) and drift taxonomy pointer.

4. **Mark legacy paths** - Document LEGACY entrypoints (`Switching ver12/`, repo-root wrappers, flat results) without moving code yet.

5. **Only then** - Patch wrappers, manifest writers, fingerprint fields, and output ownership in code to match PART 1.

Steps 1-4 are documentation and labeling; step 5 is deliberate code change **after** the consolidation gate (PART 5).

---

## Appendix - Enforcement checklist (all future infra agents)

Use before any merge of infrastructure work:

- [ ] PART 3 pre-change report is complete.
- [ ] PART 1 canonical labels applied; no new FORBIDDEN pattern introduced.
- [ ] PART 4 duplication risks addressed or explicitly deferred with LEGACY marking.
- [ ] `docs/run_system.md` and `docs/results_system.md` remain consistent with this document.
- [ ] No parallel modification of execution wrapper without serial coordination.
- [ ] If touching manifests, `tools/load_run_manifest.m` and consumers remain valid or are updated in the same change set (doc + code when code is allowed).

---

## Related documents

- `docs/AGENT_RULES.md` - Agent behavior and documentation precedence.
- `docs/repo_execution_rules.md` - MATLAB wrapper and runnable script contract.
- `docs/results_system.md` - Run folder path and artifact layout.
- `docs/run_system.md` - Run context, manifest purpose, tools.
- `docs/output_artifacts.md` - Subfolder roles within a run.
- `docs/repo_audit_report.md` - Observed drift and risks.
- `docs/repo_consolidation_plan.md` - Staged consolidation map (no big-bang).
