# Canonicalization state (Phase 5B)

This report classifies major repository zones using definitions in the Phase 5B prompt, aligned with existing maps (`docs/repo_map.md`, `docs/system_registry.json`, `canonical_state_freeze.md`, `docs/switching_canonical_definition.md`, `docs/repository_structure.md`, `docs/repo_consolidation_plan.md`). It does not audit individual files.

---

## 1. Overview of canonical vs non-canonical zones

**Canonical (infrastructure and policy):** `tools/` (wrapper and run helpers), `docs/` (normative contracts), `results/` as the run-scoped evidence tree, `claims/`, and `snapshot_scientific_v3/` are treated as the stable execution-and-evidence framing. The **Switching** agent path is canonical when identified by **`tables/switching_canonical_entrypoint.csv`** and executed as **`Switching/analysis/run_switching_canonical.m`** with the wrapper, as locked in `docs/switching_canonical_definition.md`.

**Non-canonical (by design or legacy):** Repo-root **`tables/`** and **`figures/`** as primary global sinks for new work, **`Switching ver12/`** as legacy tree, **`Aging old/`**, **`General ver2/`**, and the independent **`* verX/`** experiment packages are non-canonical relative to the unified stack. **`GUIs/`** and **`github_repo/`** are supporting or third-party, not the batch canonical stack.

**In progress:** **`Switching/analysis/`** (bulk scripts vs one registered entrypoint), **`Aging/`** (pipeline/utils vs analysis spread), **`Relaxation ver3/`**, cross-**`analysis/`**, **`runs/`** shims, **`reports/`** (global vs run-local tension), **`surveys/`**, **`scripts/`**, and **`tests/`** show partial alignment with `createRunContext`, run manifests, and execution_status signaling.

**Unknown:** **`archive/`** is reserved for low-confidence classification without a dedicated policy row in the consulted maps.

---

## 2. Clear canonical core (trusted zones)

The following are the **trusted canonical core** for automated execution and run identity in the unified sense:

| Zone | Why it is core |
| --- | --- |
| `tools/` | Single approved wrapper `run_matlab_safe.bat`, validators, manifest and artifact helpers per `docs/infrastructure_laws.md` and `docs/repo_context_infra.md`. |
| `docs/` | Formal definitions: `docs/repo_execution_rules.md`, `docs/switching_canonical_definition.md`, `docs/infrastructure_laws.md`, registry-backed entrypoint rules. |
| `results/` | Canonical run root pattern `results/<experiment>/runs/run_<timestamp>_<label>/` for run-scoped outputs. |
| `Aging/utils/createRunContext.m` (conceptual) | Documented run factory for manifest and run_dir creation (`docs/repo_map.md`, `docs/run_system.md`). |
| Registered Switching entry | `Switching/analysis/run_switching_canonical.m` per `tables/switching_canonical_entrypoint.csv` — sole canonical Switching script for agents. |
| `claims/` | Canonical claim store (`docs/repo_map.md`). |
| `snapshot_scientific_v3/` | Canonical control-plane / navigation layer (`docs/repo_map.md`). |

Science **interpretation** trust is separate from **execution** trust; `canonical_state_freeze.md` still records open closure items (e.g. kappa1, migration, replay formalization).

---

## 3. Main non-canonical regions

- **Legacy pipelines:** `Switching ver12/`, `Aging old/`, `General ver2/`, and historical `* verX/` packages — independent or legacy, not the three-module standard.
- **Global output sinks:** Repo-root `tables/` and `figures/` — policy discourages new agent primary writes here; many historical artifacts remain.
- **Non-batch surfaces:** `GUIs/`, bundled `github_repo/` — outside the wrapper contract.

---

## 4. Mixed-risk areas

**`mixed_risk = YES`** applies where canonical and non-canonical patterns coexist or boundaries are easy to confuse:

- **`Switching/analysis/`** — one canonical entry vs many other runnable scripts; high risk of heuristic script choice without the registry.
- **`Switching/utils/`** — evolving helpers; medium risk if conflated with entry policy.
- **`Aging/analysis/`**, **`Aging/diagnostics/`**, etc. — mixed script maturity vs pipeline core.
- **`Relaxation ver3/`** — mixed root and diagnostics entry styles vs full registry-style lock.
- **`analysis/`** — documented `createRun` vs `createRunContext` gaps in consolidation plan.
- **`tables/`**, **`reports/`**, **`figures/`** — authoritative small registries vs large legacy bulk; root-vs-run narrative tension in `canonical_state_freeze.md`.
- **`runs/`** — name collision with `results/.../runs/` called out in `docs/repo_map.md`.
- **`archive/`** — unclear boundary until explicitly scoped.

---

## 5. Readiness for Phase 5C

**`READY_FOR_5C` = YES** in `tables/canonicalization_state_status.csv`.

**Reasoning:** Phase 5B mapping and core identification are complete; the classification artifacts exist so Phase 5C can proceed on an informed basis. This does **not** mean full-repo canonicalization is finished: `canonical_state_freeze.md` still records **cleanup and consolidation not complete**, with open items (migration, root-vs-run consistency, replay formalization). Multiple zones remain **IN_PROGRESS** or **mixed-risk**; Phase 5C should treat those as in-scope follow-on work, not blockers to starting the next phase.

---

## Deliverables

| File | Purpose |
| --- | --- |
| `tables/canonicalization_state_map.csv` | Per-zone classification |
| `tables/canonicalization_state_status.csv` | Phase 5B completion flags |
| `reports/canonicalization_state.md` | This narrative |
