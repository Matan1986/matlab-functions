# Module overview (Phase 5A.2)

**Scope:** Structural presence only (directory layout and **filename/path substring** cues). No inspection of MATLAB code logic, bodies, or call graphs.

**Machine-readable table:** `tables/module_overview.csv` (40 top-level module-like directories under the repo root, excluding hidden/tooling dirs such as `.git`, `tmp`, `logs`, etc.).

**Registry flag:** `tables/module_state_status.csv` → `MODULES_DISCOVERED=YES`.

---

## Classification rules (applied consistently)

| Column | Meaning |
| --- | --- |
| `canonical_presence` | **YES** if any file path under the module matches `(?i)canonical`, `RunContext`, or `CanonicalRun` (structural filename/path cue). **NO** for designated output-only trees (`results`, `tables`, `figures`, `reports`, `review`, …) and for the root `analysis/` tree (cross-experiment analysis layer; not a single-experiment canonical pipeline module). **UNKNOWN** if none of the above applied and no cues matched. |
| `analysis_presence` | **YES** if `analysis/` exists, or the module is root `analysis/`, or `diagnostics/` exists with at least two `*.m` files (proxy for an analysis-heavy subtree). Otherwise **NO**. |
| `mixed` | **YES** when analysis (or diagnostics-heavy) coexists with pipeline/utility/infrastructure-style subtrees (`pipeline/`, `utils/`, or substantive `diagnostics/`). Root `analysis/` is **NO** (analysis-only zone). Primary experiment modules **Aging**, **Switching**, **Relaxation ver3** are **YES** when they meet the analysis/diagnostics criterion. |

**Notes column:** Records **INFRA_DEPENDENCY_PRESENT** for tooling/support trees (`tools`, `docs`, `runs`, `tests`, `scripts`, …) where relevant—still structural labeling, not code review.

---

## Primary experiment modules (repo map alignment)

| Module | Path | Canonical | Analysis | Mixed | Remarks (structural) |
| --- | --- | --- | --- | --- | --- |
| Aging | `Aging/` | YES | YES | YES | `analysis/`, `pipeline/`, `utils/`, `diagnostics/` |
| Switching | `Switching/` | YES | YES | YES | `analysis/`, `utils/` |
| Relaxation | `Relaxation ver3/` | YES | YES | YES | `run_*canonical*.m` at module root; analysis-heavy work under `diagnostics/` (no `analysis/` subdir) |

---

## Entrypoint candidates (filename patterns only)

Patterns considered: `Main_*.m`, `main_*.m`, `run_*.m` at the **module root**, plus well-known canonical runners by name under subtrees (name-only).

| Module | Examples (not exhaustive) |
| --- | --- |
| Aging | `Main_Aging.m` |
| Relaxation ver3 | `main_relaxation.m`, `run_relaxation_canonical.m`, `run_relaxation_canonical_script.m`, `run_relaxation_perturbation_demo.m` |
| Switching | *(no root `main_`/`run_` matches)* — name-pattern candidates include `Switching/analysis/run_switching_canonical.m`, `Switching/analysis/run_minimal_canonical.m` (by path/name pattern) |
| analysis (root) | Many `run_*.m` scripts at `analysis/` root (cross-experiment) |
| tools | `run_artifact_path.m`, `run_kappa2_phen_audit.m`, `run_phi1_curvature_generator_test.m`, `run_phi1_from_pt_shape_test.m` |

---

## Analysis-heavy zones (structural)

- **Dedicated `analysis/` subtree:** `Aging/analysis/`, `Switching/analysis/`, `zfAMR ver11/analysis/`, root `analysis/`.
- **Diagnostics-heavy (no `analysis/` dir):** `Relaxation ver3/diagnostics/` (many `run_*.m` scripts).

---

## Mixed zones (pipeline + analysis/diagnostics + utilities)

- **YES** per CSV: **Aging**, **Switching**, **Relaxation ver3**, **zfAMR ver11** (has `analysis/` plus other subtrees).
- **Primary “shared” layers:** root `analysis/` is analysis-only (`mixed` = NO). **`tools`**, **`docs`**, **`runs`**, **`tests`**, **`scripts`** are support/infra-dominant (see `notes` in CSV).

---

## Historical / legacy `verX` experiment packages

Top-level directories matching `* ver<number>` are listed as separate rows in `tables/module_overview.csv`. Unless filename cues matched, `canonical_presence` is **NO** (no `canonical`/`RunContext`/`CanonicalRun` path cues in tree scan). **Switching ver12** and **Aging old** are legacy parallels to current **Switching** and **Aging**.

---

## Output artifacts

| File | Role |
| --- | --- |
| `tables/module_overview.csv` | Per-module structural classification |
| `tables/module_state_status.csv` | `MODULES_DISCOVERED=YES` |
| `reports/module_overview.md` | This narrative summary |
