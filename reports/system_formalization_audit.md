# System formalization audit

**Date:** 2026-03-28  
**Type:** Deep survey (read-heavy); synthesis into four artifacts under `docs/` and this report.  
**Method:** Repository truth from files — no refactors, no invented architecture.

---

## 1. What already existed

### Infrastructure and execution

- **Normative stack:** `docs/infrastructure_laws.md` (PART 1–6), `docs/repo_execution_rules.md`, `docs/run_system.md` (strict validator-oriented contract), `docs/results_system.md`, `docs/output_artifacts.md`, `docs/AGENT_RULES.md` (precedence).
- **Implemented wrapper:** `tools/run_matlab_safe.bat` — path validation, fingerprint files under `runs/fingerprints/`, `validate_matlab_runnable.ps1`, MATLAB `-batch` with `run('script')`, post-checks for `run_dir_pointer.txt`, `execution_status.csv`, `run_manifest.json`, csv/md presence, optional manifest-vs-fresh-files drift, `tables/run_status.csv`.
- **Validator:** `tools/validate_matlab_runnable.ps1` — multi-state (`VALIDATOR_STATE` from optional `docs/repo_state.md`; default **canonical** if file missing).
- **Run factory:** `Aging/utils/createRunContext.m` — `run_manifest.json`, fingerprint fields, `config_snapshot.m`, logs/notes.
- **Tools:** `tools/list_runs.m`, `tools/load_run_manifest.m`.

### Documentation maps (partial “infra context bundle” in scattered form)

- `docs/repository_structure.md` — zones and transitional state.
- `docs/repo_consolidation_plan.md` — `run_*.m` inventory and consolidation **plan** (no big-bang).
- `docs/repo_audit_report.md` (cited by infrastructure laws) — historical drift observations.

### Scientific knowledge infrastructure

- `docs/knowledge_system_architecture.md`, `docs/knowledge_system_inventory.md` — layered description and overlap audit.
- `docs/observable_human_dictionary.md` — interpretation layer for core variables.
- `claims/*.json` — explicit claims.
- `docs/context_bundle.json` — minimal bundle (extended produced by `scripts/update_context.ps1` as `docs/context_bundle_full.json`).
- `snapshot_scientific_v3/` — control-plane indices and `00_entrypoints/canonical_resolution_path.json`.
- `analysis/knowledge/run_registry.csv`, `load_run_evidence.m`, `analysis/query/query_system.m`.

---

## 2. What was missing (before this formalization)

- A **single** infrastructure context document tying **wrapper implementation** to **run_system.md** and **infrastructure_laws.md**, including **doc–code deltas**.
- A **short repo map** that names **canonical vs legacy** folders without replacing `repository_structure.md`.
- A **scientific system map** that ties variables/claims/runs/query paths in one place (architecture doc existed but is long and multi-layered).
- A **single audit report** with explicit **verdict flags** for agents.

---

## 3. Contradictions and duplications found

| Issue | Evidence |
| --- | --- |
| **Execution mechanism** | `docs/AGENT_RULES.md` and `docs/repo_execution_rules.md` say the wrapper executes via `eval(fileread(...))`. `tools/run_matlab_safe.bat` uses `matlab -batch` with `run('<absolute_path>');`. |
| **`required_outputs` manifest shape** | `docs/run_system.md` specifies nested `tables` / `reports` / `status`. `Aging/utils/createRunContext.m` `writeManifest` writes a **flat** `required_outputs` array of absolute metadata paths. |
| **`outputs` for drift** | Wrapper drift check expects manifest field `outputs`; `writeManifest` as read does not obviously populate `outputs` — drift may often be `UNKNOWN`. |
| **Global `reports/` vs policy** | `docs/infrastructure_laws.md` forbids new **global** run outputs to repo-root `reports/`; `reports/` still contains a large tracked corpus and `knowledge_system_architecture.md` lists global reports as a narrative layer. |
| **Context bundle full** | `scripts/update_context.ps1` writes `docs/context_bundle_full.json`; inventory references it — workspace/git may omit the full file in some snapshots (regenerate as needed). |
| **Registry docs vs disk** | `docs/knowledge_system_inventory.md`: `run_index.csv` / `latest_run.txt` under results not consistently present; discovery = manifests + `list_runs.m`. |
| **Duplicate R naming** | Policy in `docs/repo_execution_rules.md` is clear; legacy code may still use `R` — not a doc conflict, but a **code hygiene** gap for new work. |

---

## 4. What was clarified (in new artifacts)

- **Actual pipeline order** from `tools/run_matlab_safe.bat` (fingerprint → validate → MATLAB → pointer → artifact checks → optional drift → `tables/run_status.csv`).
- **Where enforcement is real** (batch + PowerShell validator) vs **policy-only** (serial infra agents, no parallel stacks).
- **`run_dir_pointer.txt` is script responsibility** — illustrated by `Switching/analysis/run_minimal_canonical.m`; not automatic in `createRunContext`.
- **Scientific knowledge layer** is **real but layered**: claims + snapshot + registry + query; not one database.
- **Canonical experiment roots** vs **legacy** folders are **documented** in multiple places; `docs/repo_map.md` consolidates the **navigation** view.

---

## 5. Remaining gaps (prioritized)

1. **Doc–code alignment:** Update `docs/AGENT_RULES.md` / `docs/repo_execution_rules.md` execution bullet to match `run()` / `-batch` **or** document both as equivalent approved patterns.
2. **Manifest schema:** Align `writeManifest` / consumers with `docs/run_system.md` `required_outputs` and optional `outputs` for drift, or narrow the strict doc to match implementation deliberately.
3. **`docs/repo_state.md`:** Add when non-default `VALIDATOR_STATE` is needed; otherwise document “absent = canonical.”
4. **Run index files:** Either implement `run_index.csv` / `latest_run.txt` as promised in older inventory language **or** mark those references deprecated in favor of `list_runs.m` + manifests.
5. **Global `reports/` migration narrative:** Clarify what is **historical** vs **allowed** for human-global summaries (without mass moves — policy already discourages new global writes).

---

## 6. Prioritized next actions (minimal formalization layer)

1. One **small** doc patch fixing `eval(fileread)` vs **`run()`** wording (single source of truth).
2. **Manifest contract** decision: implement strict `run_system.md` schema in `writeManifest` **or** add a “implemented schema” subsection to `run_system.md` referencing `createRunContext`.
3. Optional: add **`docs/repo_state.md`** template with `VALIDATOR_STATE=canonical` and one-line explanation.

---

## 7. Artifacts produced (this task)

| File | Role |
| --- | --- |
| `docs/repo_context_infra.md` | Infrastructure context bundle (execution + trust + limits) |
| `docs/repo_map.md` | Practical repo map |
| `docs/scientific_system_map.md` | Scientific knowledge wiring |
| `reports/system_formalization_audit.md` | This audit |

---

## 8. Verdicts (required)

| Verdict | Value | Rationale |
| --- | --- | --- |
| **EXECUTION_SYSTEM_FORMALIZED** | **YES** | Wrapper + validator + `run_system.md` + `createRunContext` define a usable, mostly enforced pipeline; remaining gaps are **documentation parity** and manifest schema details, not “no system.” |
| **INFRA_CONTEXT_BUNDLE_EXISTS** | **YES** | Existed in **scattered** form (`infrastructure_laws`, `run_system`, `results_system`); now also **consolidated** in `docs/repo_context_infra.md`. |
| **SCIENTIFIC_CONTEXT_SYSTEM_EXISTS** | **YES** | Claims, snapshot indices, context bundle, registry, query layer (`docs/knowledge_system_architecture.md`, `analysis/query/query_system.m`). |
| **SCIENTIFIC_CONTEXT_SYSTEM_DOCUMENTED** | **PARTIAL** | Strong inventory + architecture + dictionary; **some** edges (runpack payloads, full bundle file presence) remain environment-dependent. |
| **REPO_MAP_EXISTS** | **YES** | `docs/repository_structure.md` predates this; **`docs/repo_map.md`** adds a concise operational map. |
| **CANONICAL_VS_LEGACY_SEPARATED** | **PARTIAL** | Clear in **documentation**; filesystem still mixes **global** `reports/` and **versioned** folders beside canonical modules — separation is **normative**, not physical-only. |
| **RULES_MATCH_ENFORCEMENT** | **PARTIAL** | Strong match on wrapper/validator; **mismatches** on execution text in docs and manifest/drift field shapes. |
| **SYSTEM_STILL_TRANSITIONAL** | **YES** | Root wrappers, global reports, schema alignment, optional snapshot payloads. |
| **NEXT_PHASE_READY** | **YES** | Consolidation gate items in `docs/infrastructure_laws.md` PART 5 can proceed **incrementally** with the minimal doc/code parity steps above. |

---

## Related

- `docs/repo_context_infra.md`  
- `docs/repo_map.md`  
- `docs/scientific_system_map.md`  
