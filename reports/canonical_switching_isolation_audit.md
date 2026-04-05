# Canonical Switching isolation audit

**Scope:** Canonical subsystem only, traced from `Switching/analysis/run_switching_canonical.m` and `Switching/analysis/analyze_phi_kappa_canonical_space.m` via direct calls, utilities, loaders, and signaling on that graph only. Read-only audit; no code changes.

**Normative references:** `docs/repo_execution_rules.md`, `tables/module_canonical_status.csv`, `Switching/utils/createSwitchingRunContext.m`, `Switching/utils/assertModulesCanonical.m`, `Switching/utils/assertSwitchingRunDirCanonical.m`, `Switching/utils/switchingCanonicalRunRoot.m`, `Aging/utils/createRunContext.m` (hook usage), `tools/write_execution_marker.m`.

---

## 1. Canonical execution graph

**CANONICAL_GRAPH_DEFINED = YES**

### Entry A: `run_switching_canonical.m`

| Stage | Elements |
|-------|----------|
| Path | `tools`, `Aging/utils`, `General ver2`, `Switching/utils`, `Switching ver12` (+ main, plots, parsing, utils) |
| Run context | `createSwitchingRunContext(repoRoot, cfg)` → `createRunContext('switching', cfg)` with `cfg.beforeManifestWrite = @(run) assertSwitchingRunDirCanonical(run, repoRoot)` |
| Run root | `switchingCanonicalRunRoot` → `results/switching/runs/<run_id>/` |
| Signaling | `write_execution_marker` (`tools/write_execution_marker.m`); `writeSwitchingExecutionStatus(run_dir, ...)`; `execution_probe_top.txt`, probe CSVs, `runtime_execution_markers.txt` under `run_dir` when resolvable |
| Data | `parentDir` parsed from `Switching ver12/main/Switching_main.m`; raw `.dat` via `getFileListSwitching` / `processFilesSwitching`; stability via `analyzeSwitchingStability` |
| Artifacts | `run_dir/tables/` (e.g. `switching_canonical_*.csv`, validation CSVs), `run_dir/reports/*.md`, `run_dir/execution_status.csv` |
| Failure | If `run_dir` missing: `allocateSwitchingFailureRunContext` → `createSwitchingRunContext`; `writeSwitchingExecutionStatus` with `FAILED` |

### Entry B: `analyze_phi_kappa_canonical_space.m`

| Stage | Elements |
|-------|----------|
| Path | `genpath` on `General ver2`, `Tools ver1`; `Aging/utils`; `Switching/utils` |
| Registry gate | `assertModulesCanonical({'Switching'})` → reads `tables/module_canonical_status.csv` |
| Run context | `createSwitchingRunContext` → same `beforeManifestWrite` / `results/switching/runs` contract as Entry A |
| Data loaders | `readtable(fullfile(repoRoot,'tables','phi_kappa_stability_summary.csv'))`, `readtable(...,'phi_kappa_stability_status.csv'))` |
| Artifacts | Writes under `run_dir/tables/` and `run_dir/reports/`; `writeSwitchingExecutionStatus(output_tables_dir, ...)` places `execution_status.csv` under **`run_dir/tables/`** (first argument is the tables directory, not the run root) |

---

## 2. Isolation of canonical Switching

**CANONICAL_SWITCHING_ISOLATED = NO**

**CROSS_MODULE_TOUCHPOINTS =**

- **`Aging/utils` only** — on-path for `createRunContext` / `createSwitchingRunContext` (no `addpath(genpath(Aging))`; consistent with `docs/repo_execution_rules.md` dependency note).
- **Repo-level `tables/phi_kappa_stability_summary.csv` and `tables/phi_kappa_stability_status.csv`** — Entry B reads these from the repository `tables/` tree. They are **not** produced by this two-entry graph; provenance is upstream of this analysis. That is a **shared aggregate input**, not raw Switching isolation.
- **`Switching ver12` legacy backend** — Entry A; canonical policy treats this as the allowed backend, not Relaxation/Aging data.
- **`General ver2` / `Tools ver1`** — shared libraries (Entry A adds `General ver2`; Entry B uses `genpath` on both).
- **`tools/write_execution_marker`** — may append to `tables/runtime_execution_markers_fallback.txt` if `run_dir` is not available (non-authoritative observability).

**Not present on this graph:** Relaxation module data loads, Aging module **data** loads, explicit `cross_experiment` paths, or reads of non-canonical module **state** objects. Entry A does not load repo `tables/` inputs for the main S pipeline.

---

## 3. Infrastructure alignment (isolation layer vs canonical subsystem)

**ISOLATION_LAYER_ALIGNED_WITH_CANONICAL_SUBSYSTEM = NO**

| Mechanism | Alignment |
|-----------|-----------|
| **`createSwitchingRunContext` + `assertSwitchingRunDirCanonical` + `switchingCanonicalRunRoot`** | **Yes** for run placement: enforces `run_dir` under `results/switching/runs`. |
| **`tables/module_canonical_status` + `assertModulesCanonical`** | **Partial / not subsystem-wide:** only **Entry B** calls `assertModulesCanonical`. **Entry A (`run_switching_canonical.m`), the canonical Switching entrypoint, does not call it.** |
| **Manifest / signaling / failure path** | **Partially aligned:** `createRunContext` writes manifest-related artifacts for successful allocation; `writeSwitchingExecutionStatus` standardizes schema; failure path uses `allocateSwitchingFailureRunContext` + status writes. **Module canonical status does not flow into `execution_status.csv` or manifest.** |

So the **run-directory** isolation layer is aligned with both entries; the **module registry** layer is **not** aligned with the full canonical subsystem because the primary canonical runner never consults it.

---

## 4. Enforcement relevance

**ENFORCEMENT_NEEDED_NOW = NO**

- **Entry A** does not consume Relaxation or Aging **data**; isolation is primarily **raw upstream + run-scoped outputs**, enforced by **`createSwitchingRunContext` / `assertSwitchingRunDirCanonical`**, not by `module_canonical_status`.
- **Entry B** calls `assertModulesCanonical({'Switching'})` with a **single** module list; with the current registry (`Switching` = `CANONICAL`), this does not add a cross-module blocking property beyond **registry file presence and schema** (other modules are not listed in the call).

**Where enforcement would matter if the policy were “cross-module analysis only”:** only on scripts that **declare multiple modules** in `assertModulesCanonical` — **not** on the current Entry A graph.

---

## 5. False safety risk

**FALSE_SAFETY_RISK = YES**

- **`module_canonical_status` / `assertModulesCanonical` apply only to Entry B**, not to **`run_switching_canonical.m`**. Operators may assume “canonical module gating” covers all canonical Switching runs; it does not.
- **`writeSwitchingExecutionStatus` does not record module canonical status**; a `SUCCESS` row does not prove registry checks ran.
- **Entry B** still depends on **repo `tables/phi_kappa_stability_*.csv`** inputs; registry checks do not validate those files’ upstream provenance.

---

## 6. Final verdict

**CANONICAL_ISOLATION_VERIFIED = NO**

Reasons:

1. **Union of the two entry graphs is not data-isolated:** Entry B depends on **repo-level** `phi_kappa_stability_*` tables whose origin is outside this graph.
2. **Module-level enforcement is not coextensive with the canonical subsystem:** primary entry **does not** use `assertModulesCanonical`.
3. **False safety risk** applies if the registry is interpreted as protecting all canonical Switching execution.

Entry A alone is **largely** isolated from Relaxation/Aging **data** (subject to allowed `Aging/utils` and legacy backend), but the **audit scope** includes Entry B and the **infrastructure story** for the two mechanisms is **not unified**.

---

## Output files

| File | Role |
|------|------|
| `tables/canonical_switching_isolation_audit.csv` | Row-level audit items |
| `tables/canonical_switching_isolation_status.csv` | Summary flags |
| `reports/canonical_switching_isolation_audit.md` | This report |

**CANONICAL_ISOLATION_AUDIT_COMPLETE = YES**
