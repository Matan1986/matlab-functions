# Repository topology overview (Phase 5A.1)

**Scope:** Top-level directories under the repository root only, plus a limited set of level-2 paths for major modules. No file contents were read; classification is by conventional layout and naming.

**Status:** See `tables/repo_topology_status.csv` (`TOPOLOGY_DISCOVERED=YES`).

## Level 0

| Path | Classification | Role |
|------|----------------|------|
| `.` | MIXED | Root aggregates domain version trees (`* ver*`), core modules (`Aging`, `Switching`, `Relaxation ver3`), governance (`docs`, `claims`, `review`), infrastructure (`tools`, `tests`, `templates`), artifact sinks (`tables`, `results`, `reports`, `logs`), and many root-level runnable `.m` scripts and logs. |

## Level 1 summary counts (by classification)

Approximate grouping of **directories** at the repository root:

- **MODULE** — Versioned experiment and analysis trees (`* ver*`, `Switching`, `Switching ver12`, `Aging`, `Relaxation ver3`, `GUIs`, `analysis`, `scripts`, `_legacy`, etc.).
- **INFRASTRUCTURE** — Execution and environment: `tools`, `tests`, `templates`, editor and agent caches (`.vscode`, `.codex_*`, `.matlab_prefs`, `matlab_prefs_agent`), temp and quarantine (`tmp`, `tmp_*`), vendor stubs (`MathWorks`, `.mwhome`).
- **GOVERNANCE** — Policy and process: `docs`, `claims`, `review`, `.git`, `.github`.
- **ARTIFACTS** — Outputs and registries: `tables`, `tables_old`, `results`, `results_old`, `reports`, `figures`, `logs`, `status`, `probe_outputs`, `archive`, `junk`, `snapshot_scientific_v3`.
- **MIXED** — `runs` (orchestration and run-related paths), `surveys` (definitions vs outputs), and the repository root.
- **UNKNOWN** — `github_repo` (purpose not inferred without inspection).

## Level 2 (sample)

Representative second-level paths recorded in `tables/repo_topology_map.csv`:

- **Switching:** `Switching/analysis`, `Switching/utils`
- **docs:** `docs/templates`, `docs/reports`
- **Aging:** `Aging/utils`
- **Relaxation ver3:** `Relaxation ver3/diagnostics`

## Outputs

| Artifact | Path |
|----------|------|
| Topology map (CSV) | `tables/repo_topology_map.csv` |
| Status (CSV) | `tables/repo_topology_status.csv` |

## Method

- Enumerated top-level directories via filesystem listing.
- Did not open individual source files; notes are structural only.
- Depth limited to levels 0–2 per task.
