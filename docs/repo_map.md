# Repository map (practical)

**Purpose:** One-page navigation for **canonical vs legacy** zones, **entry points**, and **where truth lives**.  
**Note:** This does not replace `docs/repository_structure.md` (layout standard + transitional notes) or `docs/system_registry.json` (module classification); it **aligns** with them.

---

## 1. Top-level zones (canonical meaning)

| Zone | Role | Classification |
| --- | --- | --- |
| `Aging/`, `Relaxation ver3/`, `Switching/` | Active experiment modules (pipelines, analysis, diagnostics, utils) | **CANONICAL** for primary science work |
| `analysis/` | Cross-experiment analyses, agent-style scripts, `analysis/query/`, `analysis/knowledge/` | **CANONICAL** shared analysis layer |
| `results/` | All generated run outputs under `results/<experiment>/runs/run_<ts>_<label>/` | **CANONICAL** evidence store |
| `tools/` | Wrappers (`run_matlab_safe.bat`), validators, run/manifest/observable helpers | **CANONICAL** infrastructure |
| `docs/` | Policies, run contracts, knowledge architecture, registries | **CANONICAL** documentation |
| `claims/` | Scientific claim JSON files | **CANONICAL** claim store |
| `snapshot_scientific_v3/` | Control-plane indices (claims, runs, reports, evidence edges) | **CANONICAL** navigation / scientific OS layer |
| `surveys/` | Rolling surveys and registry | **SUPPORTING** synthesis |
| `scripts/` | Context bundle generation, snapshots, automation | **SUPPORTING** |
| `runs/` | Path/setup shims and `runs/run_aging.m` style entry helpers | **SUPPORTING** (not the same as `results/.../runs/`) |
| `reports/` | **Historical / global** markdown and CSV reports (many files) | **MIXED:** policy prefers run-scoped outputs; this tree is **legacy + active global narratives** — see `docs/infrastructure_laws.md` (global output writes forbidden for *new* agent analyses) |
| `figures/`, `tables/` (repo root) | Global outputs | **LEGACY / transitional** — do not use for new agent runs per infrastructure laws |
| `Switching ver12/`, `Aging old/` | Older pipelines and debug paths | **LEGACY** (explicit per `docs/repository_structure.md`) |
| `General ver2/` | Old visualization stack | **DEPRECATED** for new figures (`docs/AGENT_RULES.md`) |
| `* verX/` (FieldSweep, zfAMR, etc.) | Historical experiment packages | **INDEPENDENT / historical** — not the Aging/Relaxation/Switching standard |
| `GUIs/`, `github_repo/` | Apps and bundled third-party colour maps, etc. | **SUPPORTING** |

---

## 2. Canonical paths (quick reference)

- **Automated MATLAB execution:** `tools/run_matlab_safe.bat "<ABSOLUTE_PATH_TO_SCRIPT.m>"`
- **Run outputs:** `results/<experiment>/runs/run_<yyyy>_<mm>_<dd>_<HHMMSS>_<label>/`
- **Experiments (lowercase):** `aging`, `relaxation`, `switching`, `cross_experiment`, `repository_audit`, etc. (see `results/README.md`)
- **Run context factory:** `Aging/utils/createRunContext.m`
- **Run manifest reader:** `tools/load_run_manifest.m`
- **Run listing:** `tools/list_runs.m`
- **Post-run pointer (wrapper contract):** repo root `run_dir_pointer.txt` (absolute `run_dir` line)
- **Wrapper fingerprint store:** `runs/fingerprints/`
- **Execution status export (wrapper):** `tables/run_status.csv`

---

## 3. Main entry points (non-exhaustive)

- **Wrapper (agents):** `tools/run_matlab_safe.bat` — single approved batch entry for automated runs.
- **Module mains:** e.g. `Switching ver12/main/Switching_main.m` — **LEGACY** pipeline root; not the unified wrapper contract by default.
- **Root wrappers:** numerous `run_*_wrapper.m` at repo root — **TRANSITIONAL / consolidation-listed** in `docs/repo_consolidation_plan.md` (shims toward run-folder outputs).
- **Cross-analysis:** `analysis/*.m` scripts (many); query layer: `analysis/query/query_system.m`.
- **Knowledge/query:** `analysis/query/query_system.m`, `analysis/knowledge/run_registry.csv`, `analysis/knowledge/load_run_evidence.m`.

---

## 4. Stable vs transitional

| Area | Stability |
| --- | --- |
| `docs/run_system.md`, `docs/infrastructure_laws.md`, `docs/results_system.md` | **Stable** normative specs |
| `tools/run_matlab_safe.bat`, `tools/validate_matlab_runnable.ps1` | **Stable** enforcement surface (change only with infra process) |
| `createRunContext` + manifest writing | **Stable** with known schema evolution toward strict `run_system.md` |
| Root `run_*_wrapper.m` proliferation | **Transitional** |
| `reports/` at repo root vs run-local `results/.../reports/` | **Transitional tension** (policy favors run-local; global `reports/` still holds many narratives) |
| `snapshot_scientific_v3` vs full runpack ZIPs | **Transitional** (indices present; some payload paths optional per audits) |

---

## 5. Maps you already had (this file’s relationship)

- **`docs/repository_structure.md`** — directory layout and target architecture.  
- **`docs/knowledge_system_architecture.md`** — scientific knowledge layers (A–F).  
- **`docs/knowledge_system_inventory.md`** — read-only audit of overlapping systems.  
- **`docs/repo_consolidation_plan.md`** — entrypoint inventory and migration **plan** (no mass refactors).  

**This `repo_map.md`** is the **short operational map** tying those to **wrapper + results + legacy folders** in one view.

---

## Related

- `docs/repo_context_infra.md` — execution trust detail  
- `docs/scientific_system_map.md` — scientific knowledge wiring  
- `docs/AGENT_RULES.md` — precedence and agent types  
