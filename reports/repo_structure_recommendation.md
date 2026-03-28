# Repository structure recommendation (conceptual only)

**Generated:** 2026-03-28  
**Purpose:** Describe a **clean mental model** of how this repository *could* be read — **not** a refactor plan, branch strategy, or file move list.  
**Maps to:** Existing folders (`docs/repo_map.md`, `docs/repository_structure.md`, `docs/infrastructure_laws.md`).

---

## 1. Conceptual layers

### `core/` *(concept — today spread across top-level)*

**What belongs:** Shared scientific logic that multiple experiments consume — cross-cutting analyses, query/knowledge helpers, claims.

**Current mapping:** `analysis/` (including `analysis/query/`, `analysis/knowledge/`), `claims/`, parts of `snapshot_scientific_v3/`.

**Note:** The repo already treats `analysis/` as a **canonical shared layer**; a physical `core/` folder is unnecessary if `analysis/` stays the hub.

---

### `experiments/` *(concept — today: versioned module folders)*

**What belongs:** Pipelines, instrument-specific code, module `main_*`, diagnostics tied to one domain.

**Current mapping:** `Aging/`, `Relaxation ver3/`, `Switching/`, `Switching ver12/`, `ARPES ver1/`, `MT ver2/`, `* verN/` instrument trees, `GUIs/` when used as experiment UI.

**Pattern:** The `* verX/` naming is already an implicit **“experiment package”** convention; the main tension is **multiple trees for one domain** (e.g. Switching vs Switching ver12), which docs label canonical vs legacy.

---

### `infra/` *(concept — today: `tools/` + `runs/` + root shims)*

**What belongs:** Execution wrappers, validators, manifest/fingerprint helpers, path setup, CI/editor config, launch shims.

**Current mapping:** `tools/` (including `run_matlab_safe.bat`), `runs/`, `scripts/` (automation), root `setup_repo.m`, `repo_state_*.m`, root `run_*_wrapper.m` (**transitional** per consolidation docs), `.vscode/`, `.github/`.

**Ideal story:** One approved MATLAB entry (`tools/run_matlab_safe.bat`) + run-scoped outputs; root wrappers are **convenience** until migrated toward `runs/` or absorbed into module entrypoints.

---

### `physics/` *(optional label — not a required folder)*

**What belongs:** Nothing mandatory as a separate top-level name; scientific code already lives under `analysis/` and experiment modules.

**Use:** If splitting ever happens, “physics” would mean **reusable models** (barrier laws, relaxation ties) vs one-off scripts — today this distinction is **documented** (`docs/scientific_system_map.md`) more than enforced by paths.

---

### `results/` *(canonical — exists)*

**What belongs:** All run-scoped artifacts: `run_manifest.json`, figures/tables/reports under `results/<experiment>/runs/run_<timestamp>_<label>/`.

**Current mapping:** Matches `docs/results_system.md` / `docs/infrastructure_laws.md`. Root-level `reports/` remains **global narrative + legacy** per `docs/repo_map.md`.

---

### `documentation/` *(concept — today: `docs/` + scattered root `.md`)*

**What belongs:** Policies, run contracts, architecture, human-readable science notes.

**Current mapping:** `docs/` is canonical; root still holds a few science-adjacent `.md` files (`phi_*.md`, `kappa_physical_interpretation.md`) that could conceptually live under `docs/analysis_notes/` (some analysis notes already exist there).

---

### `legacy/` *(concept — explicit in docs, not always one folder)*

**What belongs:** Older pipelines kept for reproducibility, deprecated figure stacks, overlapping module versions.

**Current mapping:** `Switching ver12/`, `Aging old/`, `General ver2/` (deprecated for new figures), historical `* verX/` packages — **as labeled in** `docs/repo_map.md` and `docs/repository_structure.md`.

---

## 2. How this maps to “hidden” structure you already have

1. **Normative docs** (`docs/infrastructure_laws.md`, `docs/repo_execution_rules.md`) define **one** automated execution path and **one** run root pattern — strong canonical spine.
2. **`docs/repo_map.md`** already splits **CANONICAL** vs **LEGACY** vs **SUPPORTING** zones — the structural diagnosis aligns with that map rather than replacing it.
3. **Root clutter** is largely **operational debris** (logs, probes) and **transitional launchers** (wrappers), not absence of design in `results/` / `tools/` / `docs/`.

---

## 3. What “clean” would mean (without moving files here)

- **Launch:** Prefer documented entry (`tools/run_matlab_safe.bat`) and run folders under `results/...`.
- **Narrative outputs:** Prefer run-scoped `reports/` under the run directory; global `reports/` remains historical/mixed per `repo_map.md`.
- **Root:** Treat as **convenience + session artifacts**, not the long-term home for logs or duplicate script names.

---

## VERDICTS (aligned with `root_chaos_map.md`)

| Flag | Value |
| --- | --- |
| **ROOT_IS_CLEAN** | **NO** |
| **CANONICAL_STRUCTURE_EXISTS** | **YES** |
| **DUPLICATION_PRESENT** | **YES** |
| **MISPLACEMENT_SEVERE** | **YES** |
| **RESTRUCTURE_NEEDED** | **YES** (conceptual; phased alignment per existing docs, not big-bang) |
