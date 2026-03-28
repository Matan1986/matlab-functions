# Scientific system map

**Purpose:** Map how **scientific meaning** (variables, claims, evidence) connects to **repo structure** (runs, reports, indices, queries).  
**Companion:** `docs/knowledge_system_architecture.md` (layered architecture), `docs/knowledge_system_inventory.md` (audit of overlaps).

---

## 1. Layer overview (compressed)

| Layer | What it is | Key paths |
| --- | --- | --- |
| **Semantic / vocabulary** | Modules, observables, naming policy | `docs/system_registry.json`, `docs/repo_state.json`, `docs/model/repo_state_description.json`, `docs/observables/observable_registry.md`, `docs/observable_naming.md` |
| **Interpretation dictionary** | Human-meaning layer for symbols vs observables | `docs/observable_human_dictionary.md` |
| **Explicit claims** | Statements with status/role/confidence | `claims/*.json` |
| **Run-ground truth** | Per-run manifests, configs, logs, observables index | `results/<experiment>/runs/run_*/run_manifest.json`, `config_snapshot.m`, optional `observables.csv` |
| **Run-local narratives** | Analysis reports tied to a run | `results/.../runs/.../reports/*.md`, `.../tables/*.csv` |
| **Global narratives** | Cross-run or convenience reports (legacy-heavy) | `reports/*.md` (large corpus) |
| **Evidence registry (MATLAB)** | `run_id` → paths to evidence CSV/MD | `analysis/knowledge/run_registry.csv`, `analysis/knowledge/load_run_evidence.m`, `analysis/knowledge/unresolved_runs.csv` |
| **Context bundle (JSON)** | Machine handoff: claims + repo state + model cores | `docs/context_bundle.json`; extended bundle produced by `scripts/update_context.ps1` as `docs/context_bundle_full.json` (regenerate if missing) |
| **Snapshot control plane** | Deterministic graphs: claim → run/report, run index, report index | `snapshot_scientific_v3/` (see `00_entrypoints/canonical_resolution_path.json`) |
| **Surveys** | Rolling status / human synthesis | `surveys/registry.json`, `surveys/*/rolling_survey.md` |
| **Query entry** | Read-only aggregation over existing CSVs | `analysis/query/query_system.m`, `analysis/query/list_all_runs.m` |

---

## 2. Core mathematical variables (naming discipline)

**Primary reference:** `docs/observable_human_dictionary.md` (model variables \(P_T\), \(\kappa_1\), \(\kappa_2\), \(\alpha\), \(\Phi_1\), \(\Phi_2\), etc.).

**Critical disambiguation (`docs/repo_execution_rules.md`):**

- **`R_relax`** — Relaxation: \(R_{\mathrm{relax}}(T,t) = -\mathrm{d}M/\mathrm{d}\log t\) (time-dependent).
- **`R_age`** — Aging: scalar ratio-of-times style quantity \(R_{\mathrm{age}}(T)\).

Plain `R` in **new** code is forbidden; legacy uses may remain with clarification.

**Where they are computed:** Distributed across experiment pipelines (`Aging/`, `Relaxation ver3/`, `Switching/`, `analysis/`) — there is **no single** `compute_R_age.m` canonical hub; meaning is **document-led** plus **per-analysis** tables under run folders.

---

## 3. Where runs live

- **Canonical path:** `results/<experiment>/runs/run_<timestamp>_<label>/`
- **Listing:** `tools/list_runs.m` (filesystem + `run_manifest.json`)
- **Cross-reference:** `analysis/knowledge/run_registry.csv` maps `run_id`, `experiment`, `run_rel_path`, and optional snapshot columns

---

## 4. Where summaries / evidence / query layers live

| Mechanism | Role |
| --- | --- |
| `observables.csv` at run root | Run-level index of exported observables (policy: not under `tables/`) |
| `snapshot_scientific_v3/30_runs_evidence/run_index.json` | Run metadata / paths for snapshot resolution |
| `snapshot_scientific_v3/70_evidence_index/*.jsonl` | Edges: claim → run, claim → report |
| `snapshot_scientific_v3/60_claims_surveys/claim_index.json` | Claim index for navigation |
| `analysis/query/query_system.m` | Queries like `coordinate_selection`, `residual_validity`, `pt_vs_relaxation`, `list_all_runs` — loads **existing** CSV evidence via `load_run_evidence`, seeds from snapshot edges + context bundle + `run_registry.csv` |
| `docs/context_bundle.json` | Fallback context for agents (also checks external path `C:\Dev\matlab-functions_context\context_bundle.json` first in `query_system.m`) |

---

## 5. How scientific meaning connects to repo structure

1. **Claims** (`claims/*.json`) state hypotheses and status; **snapshot** links claims to **run_ids** and **report** paths.
2. **Runs** (`results/.../runs/...`) hold **measured** tables and **run_manifest.json** (provenance).
3. **Registry** (`analysis/knowledge/run_registry.csv`) bridges **run_id** to **evidence file paths** for programmatic loading.
4. **Query layer** composes metrics from **already materialized** CSVs — it does **not** recompute physics (`analysis/query/query_system.m` header comment).
5. **Human dictionary** (`docs/observable_human_dictionary.md`) aligns narrative and symbols when reading **either** run-local or global `reports/`.

---

## 6. Partial scientific “operating knowledge layer” — verdict

The repository **already contains** a partial **scientific operating knowledge layer**: claims + snapshot indices + context bundle + evidence registry + query entrypoints. It is **not** fully unified (e.g. global `reports/` vs run-local reports, optional runpack ZIPs, reduced claim fields in bundles per inventory audit).

---

## Related documents

- `docs/knowledge_system_architecture.md`  
- `docs/knowledge_system_inventory.md`  
- `docs/observable_human_dictionary.md`  
- `docs/results_system.md`  
- `snapshot_scientific_v3/00_entrypoints/canonical_resolution_path.json`  
