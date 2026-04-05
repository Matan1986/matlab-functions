# Phase 2 — Switching canonical definition audit (read-only)

**Scope:** Switching only. **Excluded:** Aging and Relaxation pipelines (except noting that `createRunContext` lives under `Aging/utils` as a **technical** dependency for run identity).

**Source of truth (code):** `Switching/analysis/run_switching_canonical.m`

**Run-backed evidence (example):** `results/Switching/runs/run_2026_04_03_000147_switching_canonical/` (most recent full `switching_canonical_*` artifact set used below).

---

## 1. Execution path to final outputs

Linear trace:

1. **Path bootstrap:** `repoRoot`, `switchingDir = fullfile(repoRoot,'Switching')`, `legacyRoot = fullfile(repoRoot,'Switching ver12')`; `restoredefaultpath`; `addpath` Aging/utils, General ver2, Switching/utils, legacy tree (main, plots, parsing, utils).
2. **Run identity:** `createRunContext('Switching', cfg)` → `run_dir` under `results/Switching/runs/…`; early `execution_status.csv`, probe CSVs.
3. **Raw location:** Read `Switching ver12/main/Switching_main.m`, parse `dir = "…"` → `parentDir`.
4. **Ingest:** For each `Temp Dep*` subfolder of `parentDir`: `getFileListSwitching` → `processFilesSwitching` → `analyzeSwitchingStability` → take selected channel table, column 4 as **P2P_percent** (`Svec`), temperature column 1 (`Tvec`), optional `resolveNegP2P` sign flip.
5. **Table assembly:** Build `rawTbl` (`current_mA`, `T_K`, `S_percent`, …); collapse to grid `Smap(T,I)`; compute PT-row **Speak**, **Ipeak**, monotone **CDF** along current, **Scdf**, **PTmap**, residual **R = Smap − Scdf**.
6. **Phi / kappa:** Rank-1 **SVD** on residual → **phi1**, **kappa1**; scale/sign; **Sfull = Scdf + kappa1·phi1′**.
7. **Outputs (under `run_dir`):**  
   - `tables/switching_canonical_S_long.csv`  
   - `tables/switching_canonical_observables.csv`  
   - `tables/switching_canonical_phi1.csv`  
   - `tables/switching_canonical_validation.csv`  
   - `tables/run_switching_canonical_implementation_status.csv`  
   - `reports/run_switching_canonical_report.md`  
   - `reports/run_switching_canonical_implementation.md`  
   - Plus execution probes, `run_manifest.json`, etc.

---

## 2. Definition of **S(I,T)** in the current canonical run

- **Point-level (before grid):** `S_percent` is the legacy **P2P_percent** metric (4th column of the selected channel’s `tableData.ch*`), paired with temperature from the same table and current from folder metadata (`Current_mA`).
- **Grid `Smap`:** For each distinct rounded temperature and each current, `Smap` is the **mean** of `S_percent` over rows matching that `(T,I)` (after collapsing duplicate temperatures per folder and merging folders).
- **Derived surfaces in the long table:** `S_model_pt_percent` ≡ **Scdf** (PT-constructed), `S_model_full_percent` ≡ **Sfull** (PT + rank-1 residual), `residual_percent` ≡ `Smap − Scdf`.

This is **not** imported from a precomputed repo table; it is computed from raw `.dat` via the legacy stack (see validation row below).

---

## 3. Preprocessing / normalization actually applied

- **Legacy pipeline:** `processFilesSwitching(...)` with fixed numeric arguments (window sizes, pulses, etc.) and `pulseScheme` from folder name/parsing.
- **Current scaling:** `I_A = meta.Current_mA/1000`, `scaling_factor = 1e3` passed into `processFilesSwitching` as in script.
- **Optional:** `normalize_to` from `resolve_preset` / `select_preset` when those exist on path (General ver2); otherwise `normalize_to = 1`.
- **Stability:** `analyzeSwitchingStability` with filtered/centered options and channel selection.
- **Post-metric:** Optional `resolveNegP2P` sign flip on `Svec`; duplicate-`T` averaging; **round** temperatures then unique mapping for `Smap`.
- **PT row:** Monotone adjustment of `s/Speak`, normalized gradient to PDF, `cumtrapz` for CDF along current.

---

## 4. Where **Phi1** and **kappa1** enter

- **Not** read from external phi/kappa tables.
- Computed **inside** `run_switching_canonical.m` after the PT baseline: **SVD** on the residual matrix `Rfill = finite_part(Smap − Scdf)`.
- **phi1** = first **right** singular vector (current axis), **kappa1** = first left singular vector × σ₁ (temperature axis), with magnitude normalization and Spearman sign check against `Speak`.
- **Used** to form **Sfull** and exported to `switching_canonical_phi1.csv` and `switching_canonical_observables.csv` (`kappa1` column).

---

## 5. Dependencies (used by execution vs exists in repo)

| Category | Examples |
|----------|----------|
| **Used for execution** | `createRunContext`, `Switching ver12` code, `Switching/utils`, `General ver2` (optional presets), raw data under parsed `parentDir`, `Switching_main.m` string for `parentDir`. |
| **Exists in repo but not as S input** | Many other `tables/*.csv` files — **not** loaded for `Smap` when `CHECK_NO_PRECOMPUTED_INPUTS` is YES. |
| **Technical vs scientific** | **Technical:** run_dir layout, path order, `which(createRunContext)` check. **Scientific:** `processFilesSwitching` output metrics, PT + SVD model for `S`. |

**Evidence row (validation):** `CHECK_NO_PRECOMPUTED_INPUTS=YES`, `USES_ROOT_TABLES=NO`, `S_SOURCE` documents `getFileListSwitching + processFilesSwitching` and `parentDir=…`.

---

## 6. Classification summary

- **CANONICAL:** Definitions and artifacts produced by `run_switching_canonical.m` and written under `results/Switching/runs/…` for that run (including `switching_canonical_*.csv`).
- **LEGACY_HARMLESS:** `Switching ver12` and `General ver2` functions as **engines**; `createRunContext` location under `Aging/utils` as **infrastructure only**.
- **NONCANONICAL_RISK:** Machine-specific **raw data path** embedded in `Switching_main.m` (not repo-relative); environment-specific drive access.
- **UNKNOWN:** Minor MATLAB path / name-shadow warnings observed in console during runs (e.g. `load`); not traced to Switching logic here.

---

## Machine-readable tables

- `tables/switching_canonical_definition_audit.csv`
- `tables/switching_canonical_dependencies.csv`
- `tables/switching_canonical_risk_flags.csv`

---

## Final verdicts (Phase 2)

| Verdict | Value | Basis |
|---------|-------|--------|
| **CANONICAL_SWITCHING_DEFINITION_CLEAR** | **YES** | `S(I,T)`, PT step, and phi/kappa construction are explicit in `run_switching_canonical.m` and reflected in run CSVs. |
| **PRECOMPUTED_DEPENDENCY_PRESENT** | **NO** | Run validation: `CHECK_NO_PRECOMPUTED_INPUTS=YES` for successful canonical run; inputs are raw `.dat` enumerated from `parentDir`. |
| **SCIENTIFIC_RISK_FROM_NONCANONICAL_ELEMENTS** | **LOW** | Primary residual risk is **external raw path** and **dependence on legacy ver12** behavior; in-script definition is still traceable. |

---

*Audit type: inspect-only; no code or pipeline changes.*
