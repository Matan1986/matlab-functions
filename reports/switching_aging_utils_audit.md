# Switching / Aging/utils contamination audit

**Rules:** File-level inspection only; no MATLAB execution; no code changes.

## 1. Question

Does `addpath(..., 'Aging', 'utils')` for `createRunContext` **contaminate** the canonical Switching phase with Aging **science** or **pipeline** behavior?

## 2. Evidence on `createRunContext.m`

File: `Aging/utils/createRunContext.m` (read L1–96).

- Resolves **repo root** from the utils file location (`utilsDir` → `agingDir` → `repoRoot`, L23–26).
- Creates **`results/<experiment>/runs/<run_id>/`**, writes **`run_manifest.json`**, **`config_snapshot.m`**, **`log.txt`**, **`run_notes.txt`**, **`run_status.csv`** (via helpers), fingerprints (L85–92).
- **Does not** call `Main_Aging`, does not read Aging datasets, does not import Relaxation.
- **Shared state:** `setRunContextAppdata(run)` (L95) stores run context in MATLAB application data for this process — relevant for parallel **in-process** sessions only.

**Verdict for `createRunContext` alone:** **SAFE_INFRASTRUCTURE_DEPENDENCY** — location under `Aging/utils` is historical; behavior is **run factory + manifest**, not Aging physics.

## 3. Other `Aging/utils` symbols used from Switching (selected)

| Symbol | Role | Notes |
| --- | --- | --- |
| `getResultsDir` | Path helper under `results/` | `Aging/utils/getResultsDir.m` — can write under `results/<experiment>/...` outside a single run if no active run context (L26–35). Used from e.g. `switching_alignment_audit.m` when on path. |
| `safeCorr` | Correlation helper | `Aging/utils/safeCorr.m` exists; some Switching scripts define **local** `safeCorr` instead — check per file. |

## 4. Path scope: `Aging/utils` only vs `genpath(Aging)`

- **`run_switching_canonical.m`:** `addpath(fullfile(repoRoot, 'Aging', 'utils'))` only (L23) — **narrow**.
- **`switching_full_scaling_collapse.m`:** `addpath(genpath(fullfile(repoRoot, 'Aging')))` (L12) — **entire Aging tree** on path → **borderline contamination** risk (name shadowing, accidental calls), **not** specific to `createRunContext`.

## 5. Direct answers

1. **Does using Aging/utils contaminate Switching canonical execution?** **PARTIAL** — **No** for the **narrow** pattern (only `Aging/utils` for `createRunContext`, as in `run_switching_canonical.m`). **Yes/borderline** if scripts use **`genpath(Aging)`** or call non-utils Aging routines.

2. **If NO (narrow case):** `createRunContext` only allocates run directories and metadata under `results/Switching/...`; it does not execute Aging pipeline code.

3. **If PARTIAL:** Broad `genpath(Aging)` couples the MATLAB path to the full Aging module without requiring explicit imports.

4. **Is `createRunContext` safe?** **CONDITIONAL** — safe when **`experiment`** is intentional (`'Switching'`), repo layout is intact, and callers understand **in-process** appdata (`setRunContextAppdata`).

5. **Should Aging/utils usage be ALLOWED / RESTRICTED / REMOVED?** **RESTRICTED** — **allow** `Aging/utils` for run infrastructure (`createRunContext`, path helpers); **avoid** `genpath(Aging)` for canonical Switching unless a task explicitly requires other Aging files.

## 6. Artifact

Row-level table: `tables/switching_aging_utils_audit.csv`.
