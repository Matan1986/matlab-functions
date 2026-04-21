# Switching canonical backend definition

This document locks the **canonical Switching backend** for agents and automation. It is consistent with `tables/switching_canonical_entrypoint_candidates.csv` (Switching ver12 pipeline via the registered entrypoint) and `docs/switching_canonical_definition.md` (upstream construction including `processFilesSwitching`).

## 1. Backend identity

- **Switching ver12** is the **CANONICAL BACKEND** for Switching execution in this repository.

## 2. Status

| Field | Value |
| --- | --- |
| audited | YES |
| corrected | YES |
| approved | YES |
| safe_for_use | YES |

## 3. Role

The canonical backend is responsible for:

- raw data parsing
- switching signal extraction
- upstream **S(I,T)** construction (including paths through `processFilesSwitching` and related Switching ver12 code as invoked from the canonical entrypoint)

## 4. Access rule (mandatory)

- The backend **MUST** be accessed **ONLY** via the registered canonical entrypoint:
  - `Switching/analysis/run_switching_canonical.m`

Repository-wide MATLAB wrapper policy (`tools/run_matlab_safe.bat`) still applies; the canonical **script** for Switching is the entrypoint above.

## 5. Forbidden usage

- **Direct** execution of `Switching ver12/main/Switching_main.m` as an agent or automation entrypoint (bypasses the canonical Switching run contract).
- **Direct** use of `processFilesSwitching` **outside** the path established by the canonical entrypoint (bypasses registered wiring and run context).
- **Bypassing** `createRunContext` / run-dir semantics required by the canonical Switching script and `docs/run_system.md`.

See `tables/switching_noncanonical_scripts.csv` for explicit non-canonical identifiers.

## 6. Rationale

- The backend remains canonical **despite legacy naming** (e.g. `Switching ver12`, `Switching_main.m`); stability and audit alignment take precedence over folder renaming.
- Centralizing access through one entrypoint prevents duplicate execution paths and ambiguous artifact provenance.

## 7. Source of Truth â€” Authoritative Definitions (Switching infrastructure)

Normative table: `tables/infra_source_of_truth_definition.csv`. Scope: Switching runs under `results/switching/runs/` only.

| Concept | Authoritative source |
| --- | --- |
| **RUN_ID** | The run folder name under `results/switching/runs/` (one folder = one `RUN_ID`). |
| **PARENT_RUN_ID** | **Only** `tables/canonicalization_manifest.csv` (`source_canonical_run_id`) or `tables/canonicalization_l2_manifest.csv` (`physical_artifact_run_id`) inside the run directory. No other file may define parentage for infra closure. |
| **INPUT_SOURCE** | **Only** a field on `run_manifest.json` named `INPUT_SOURCE`, `input_source`, or `InputSource` when present. If no such field exists, **INPUT_SOURCE is officially undefined** (do not substitute `dataset`, paths, or naming). |
| **FINGERPRINT** | **Source of truth for closure:** `tools/run_matlab_safe.bat` is the **only** approved launcher; fingerprint **values** (`git_commit`, `script_hash`, `matlab_version`, `host`, `user`, etc.) are **read** from `run_manifest.json` after a run that used this wrapper (written by MATLAB during that run). The wrapper file does not store hash bytes; it **defines** which executions may produce authoritative manifest fingerprint fields. Tools and scans **must not** recompute or synthesize fingerprint values. |
| **EXECUTION_STATUS** | **`execution_status.csv`** at the run root (schema: `docs/execution_status_schema.md`). |
| **IS_CANONICAL** (Switching) | **`run_manifest.json` only**: canonical Switching runs are those with **`label` equal to `switching_canonical`**. If the manifest is missing or `label` is anything else, **IS_CANONICAL is undefined** for closure purposes (not inferable from folder suffixes or canonicalization CSV flags). |

Coverage of real runs (which artifacts exist per run): `tables/infra_source_of_truth_coverage.csv`. Closure status row: `tables/infra_source_of_truth_status.csv`.

## 8. Allowed vs Forbidden Derivations

**Allowed**

- Reading **exactly** the files and fields named in Section 7 and in `tables/infra_source_of_truth_definition.csv`.
- Leaving **PARENT_RUN_ID**, **INPUT_SOURCE**, or **IS_CANONICAL** **empty or undefined** when the authoritative source does not supply a value.
- Reporting **HAS_*** columns (e.g. in `tables/infra_source_of_truth_coverage.csv`) as factual presence checks, not as substitutes for SSOT fields.

**Forbidden**

- Inferring **PARENT_RUN_ID** from directory trees, run-id naming, or non-canonicalization tables.
- Inferring **INPUT_SOURCE** from script path, `dataset`, or defaulting to a canonical run id.
- Inferring **IS_CANONICAL** from folder names (e.g. `_switching_canonical` suffix), from `tables/canonicalization_*.csv` **IS_CANONICAL** columns, or from ad hoc boolean fields when `label` is not `switching_canonical`.
- Treating **`tables/run_fingerprint.csv`** or control-scan outputs as a **hash** or **fingerprint** registry (that file is observability; manifest fields hold the actual fingerprint material after a wrapped run).
- Recomputing or generating **FINGERPRINT** fields in PowerShell, scans, or ad hoc scripts.

**Automation alignment:** `tools/switching_canonical_control_scan.ps1` follows the rules above (manifest-only **INPUT_SOURCE** when present; **IS_CANONICAL** from manifest `label` only; **PARENT_RUN_ID** only from the two canonicalization CSVs).

## 9. Undefined Fields Policy

- **Undefined is valid.** If the authoritative source does not define a value (missing file, missing field, or non-canonical `label`), infrastructure and agents must record **empty / UNDEFINED / NO** as appropriate â€” **never** fill gaps with naming heuristics or secondary tables.
- **INPUT_SOURCE** is **often undefined** in current manifests; that is expected until writers add an explicit manifest field.
- **IS_CANONICAL** is **undefined** unless `run_manifest.json` exists and `label` is exactly `switching_canonical`.
- Bundles that omit **`run_manifest.json`** leave **FINGERPRINT** and **IS_CANONICAL** undefined at the manifest layer until a manifest exists; **RUN_ID** remains the folder name under `results/switching/runs/`.

## 10. Canonical System Boundary (STRICT)

This section defines what counts as the **canonical Switching system** for agents, preflight, and automation. It does **not** judge code quality; **canonical is defined only by the registered entrypoint and its execution-time dependency closure**.

### 10.1 Authoritative entrypoint

- **Canonical entrypoint (only):** `Switching/analysis/run_switching_canonical.m`
- **Canonical is not** â€œany script under `Switching/analysis/`â€, â€œanything named canonicalâ€, â€œanything recently modifiedâ€, or â€œanything using `load_run()`â€.

### 10.2 What is included in the canonical system

**Included** in the canonical system:

- The entrypoint script above.
- **All code files that are invoked when that entrypoint runs**, including:
  - **`Switching ver12`** modules on the path established by the entrypoint (raw parsing, `processFilesSwitching`, `analyzeSwitchingStability`, parsing helpers, etc.).
  - **`Aging/utils/createRunContext.m`** (run context and manifest), **`tools/write_execution_marker.m`**, and **`General ver2`** preset helpers when `resolve_preset` / `select_preset` resolve on the path.
- **Run-scoped outputs** under `results/switching/runs/<RUN_ID>/` produced by that execution.

A machine-readable **direct and sample indirect** call graph is in **`tables/canonical_call_graph.csv`**. A fuller transitive closure exists inside large legacy functions (not every callee is listed row-by-row in that CSV); the **principle** below still applies.

### 10.3 What is excluded

**Excluded** from the canonical system (non-canonical for Switching **analysis** scope):

- **Every other** `*.m` file under `Switching/analysis/` except `run_switching_canonical.m` (see **`tables/switching_canonical_scope.csv`**).
- Experimental, debug, and legacy runners listed or implied in **`tables/switching_noncanonical_scripts.csv`** and related tables.
- **Repository-root** `tables/` and `reports/` as **inputs** to the canonical pipeline (the entrypoint does not use them).

Non-canonical scripts **must not** be treated as part of canonical preflight, **must not** be â€œpromotedâ€ to canonical by cleanup, and **must not** be inferred to be canonical from folder names or filenames alone.

### 10.4 Hard rule (closed set)

**If a file is not reachable from the canonical entrypointâ€™s call graph, it is not part of the canonical Switching system.**

Equivalently: under `Switching/analysis/`, **only** `run_switching_canonical.m` is canonical; all other scripts there are **non-canonical** unless and until the registered entrypoint is changed by explicit repository policy (not by local edits or heuristics).

### 10.5 Artifacts

| Artifact | Role |
| --- | --- |
| `tables/canonical_call_graph.csv` | Entrypoint â†’ callees (depth and direct/indirect flags). |
| `tables/switching_canonical_scope.csv` | Per-file CANONICAL vs NON_CANONICAL under `Switching/analysis/`. |
| `tables/canonical_boundary_violations.csv` | Cross-boundary issues (canonical calling non-canonical analysis code, etc.). |
| `tables/canonical_system_definition.csv` | Named components (entrypoint, core, helper). |
| `tables/canonical_scope_status.csv` | Aggregate gate row for scope definition. |

