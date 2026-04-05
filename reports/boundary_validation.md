# Phase 5E — Boundary Reality Validation

This report uses **observed** wiring in `Switching/analysis/run_switching_canonical.m`, `tools/write_execution_marker.m`, `Switching/utils/createSwitchingRunContext.m`, and **tables/docs outputs** referenced in prior boundary work: `tables/switching_canonical_dependencies.csv`, `tables/preflight_isolation_check.csv`, `tables/canonical_boundary_violations.csv`, `tables/boundary_breach_inventory.csv`, and `docs/switching_backend_definition.md` (Sections 7–10).

## 1. Where boundaries exist

- **Canonical entrypoint:** `Switching/analysis/run_switching_canonical.m` (registry: `tables/switching_canonical_entrypoint.csv`).
- **To infrastructure:** `Aging/utils` only on path for `createRunContext`, wrapped by `Switching/utils/createSwitchingRunContext.m` with repo-root match checks.
- **To legacy backend:** `Switching ver12` subtrees added explicitly (`main`, `plots`, `parsing`, `utils`).
- **To optional helpers:** `General ver2` on path for optional `resolve_preset` / `select_preset`.
- **To tools:** `tools/` for `loadModuleCanonicalStatus`, `write_execution_marker`, and bootstrap `addpath`.
- **To governance:** `tables/module_canonical_status.csv` read before pipeline work.
- **To external data:** Raw directory from parsed `Switching ver12/main/Switching_main.m` and enumerated `Temp Dep*` subfolders.

## 2. Where they are safe

- **Aging/utils + `createRunContext`:** Path resolved to exactly `Aging/utils/createRunContext.m`; no `genpath(Aging)` in the canonical script (matches `docs/switching_dependency_boundary.md`).
- **No calls into non-canonical `Switching/analysis` scripts:** `tables/canonical_boundary_violations.csv` records no canonical-to-non-canonical analysis calls.
- **Science pipeline inputs:** Observable construction does not use repo-root `tables/*.csv` as required inputs for `S` (script sets `USES_ROOT_TABLES` to `NO` for that contract row); aligns with `docs/switching_backend_definition.md` 10.3 on excluding root tables as pipeline inputs.
- **Switching/utils:** Enforcement and run-context helpers are on-path and scoped to the canonical run setup.

## 3. Where they leak

- **`write_execution_marker` fallback:** If `run_dir` is not available, markers append to `tables/runtime_execution_markers_fallback.txt` (shared repo location). That is a **mutable cross-run artifact** outside `results/switching/runs/<RUN_ID>/` (see `tools/write_execution_marker.m` and `tables/boundary_breach_inventory.csv` note on `write_execution_marker`).
- **`tables/module_canonical_status.csv`:** Runtime gate on repo-root CSV; failure modes depend on that file’s presence and `Switching` row — not expressed as a single run-manifest field in the infra SSOT table in Section 7 of the backend doc.
- **Optional `General ver2`:** When `resolve_preset` / `select_preset` exist, `normalize_to` can change processing — influence from a second legacy module not strictly required for minimal path.
- **Ecosystem (non-canonical):** `tables/preflight_isolation_check.csv` states many `Switching/analysis` scripts read/write **repo-root** `tables/` and `reports/`. That does not show up in the canonical call graph but shows **shared aggregate surfaces** that non-canonical runs can touch; canonical runs do not consume those as `S` inputs but the repo is not globally partitioned by experiment at the root `tables/` layer.

## 4. Where they break

- **External raw location:** `Switching_main.m` embeds a **machine-local absolute** `dir = "..."`; canonical execution **requires** that directory and `Temp Dep*` layouts to exist and contain valid `.dat` data. This is outside version control and not defined in a repo-only contract (`switching_canonical_dependencies.csv` flags `Switching_main.m` as `NONCANONICAL_RISK`).
- **Upstream data semantics:** Canonical numerical outputs depend entirely on external folder content; the repository cannot guarantee reproducibility without that external state.

## 5. Final verdict

**Is canonical execution truly isolated?**

**No.** The canonical **call graph** is isolated from other `Switching/analysis` scripts (no direct non-canonical script dependencies), but canonical execution is **not** isolated from **external filesystem state** (raw paths and data), **repo-root governance** (`module_canonical_status.csv`), **optional General ver2** influence on normalization when present, and **possible shared-repo marker fallback** via `tables/runtime_execution_markers_fallback.txt`. True isolation would require those dependencies to be explicit, versioned, or run-scoped to the same degree as outputs under `results/switching/runs/`.
