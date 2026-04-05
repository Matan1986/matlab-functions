# Infrastructure duplication audit: Switching canonical system

**Scope:** Read-only. Switching-facing infrastructure and artifacts only. No code changes. Aging and Relaxation modules are not expanded beyond noting `createRunContext` as the delegated writer invoked from `Switching/analysis/run_switching_canonical.m`.

**Artifacts:** `tables/infra_source_of_truth_map.csv`, `tables/infra_duplication_conflicts.csv`, `tables/infra_derivation_map.csv`, `tables/infra_duplication_status.csv`.

---

## Verdict summary

| Question | Answer |
|----------|--------|
| Single source of truth for all five concepts | **NO** |
| Fingerprint (hash fields) writer uniqueness | **YES** (manifest via `createRunContext` / `writeManifest`) |
| Parent id schema uniqueness | **NO** (L2 vs L3 vs absent in standard manifest) |
| INPUT_SOURCE uniqueness | **NO** (multiple meanings) |
| EXECUTION_STATUS semantic writer uniqueness | **YES** (`run_switching_canonical.m` writetable paths) |
| Control scan is safe (no new truth) | **NO** (see below) |
| Infrastructure at risk | **YES** |

---

## 1. RUN_ID

**Intended authority:** The run identifier is **created** in `Aging/utils/createRunContext.m` (`makeUniqueRunId`) and **persisted** as `run_id` in `run_manifest.json` at the run root.

**Duplication points:**

- **Filesystem:** The run directory name is `results/switching/runs/<RUN_ID>/`. In normal operation it equals `manifest.run_id`, but nothing in the scoped tooling **verifies** JSON against the folder name.
- **Control scan:** `tools/switching_canonical_control_scan.ps1` sets `RUN_ID` from `Get-ChildItem` directory **Name** only. That is an **inferred** primary key (folder basename), not a read of `run_manifest.json` `run_id`.
- **Wrapper / validator:** `tools/run_matlab_safe.bat` and `tools/validate_matlab_runnable.ps1` do not define or persist `RUN_ID`.

**Conflict risk:** If a folder were renamed or a manifest edited without matching the folder, **multiple “sources”** (folder vs JSON) could disagree. Severity: **MEDIUM**.

---

## 2. PARENT_RUN_ID

**Intended authority:** There is **no** `parent_run_id` (or equivalent) in the standard `run_manifest.json` produced by `writeManifest` in `createRunContext.m`.

**Duplication points:**

- **L3 bundles:** Per-run `tables/canonicalization_manifest.csv` under `results/switching/runs/...` uses key `source_canonical_run_id` (key-value rows).
- **L2 bundles:** Per-run `tables/canonicalization_l2_manifest.csv` uses key `physical_artifact_run_id`.
- **Audit scope note:** Paths `tables/canonicalization_manifest.csv` and `tables/canonicalization_l2_manifest.csv` at **repo root** were not found; bundle manifests appear under **per-run** result trees, not a single repo-wide file.

**Conflict risk:** Two different column names and file kinds define “parent” for different workflows; the unified manifest does not subsume them. Severity: **MEDIUM**.

---

## 3. INPUT_SOURCE

**Duplication points:**

- **Pipeline (authoritative for execution):** `Switching/analysis/run_switching_canonical.m` records **raw pipeline** provenance (e.g. `sourcePath`, `sourceFunction`, `sourceFile`) for what was read and how. That is a **different concept** from a single field named `INPUT_SOURCE` in a manifest.
- **Control scan:** `switching_canonical_control_scan.ps1` builds a column `INPUT_SOURCE` using a **hard-coded** trusted run id (`run_2026_04_03_000147_switching_canonical`), regex on `*_switching_canonical`, bundle `canonical_entrypoint` lines, and manifest `script_path` / `label` / run id fallbacks. That logic is **observability policy**, not a field written by `createRunContext`.
- **Documentation:** `docs/switching_canonical_definition.md` references **TRUSTED_CANONICAL** runs; aligns narratively with the trusted id in the scan but is not the same machine field as pipeline `sourcePath`.

**Conflict risk:** The same English label “input source” can mean **raw data path**, **trusted canonical reference id**, or **declared entrypoint path**. Definitions can **disagree** without any single JSON field declaring “the” INPUT_SOURCE. Severity: **HIGH**.

---

## 4. FINGERPRINT

**Intended authority (execution fingerprint):** `computeRunFingerprint` / `writeManifest` in `createRunContext.m` writes `git_commit`, `script_hash`, `script_path`, `matlab_version`, `host`, `user` into `run_manifest.json`. Per `docs/infrastructure_laws.md`, this is the **canonical** fingerprint story.

**Duplication points:**

- **Naming collision:** The control scan writes `tables/run_fingerprint.csv`, but that file’s columns are **RUN_ID, PARENT_RUN_ID, TIMESTAMP, INPUT_SOURCE, HAS_EXECUTION_STATUS** — it does **not** contain `script_hash` or `git_commit`. Operators may assume “fingerprint” means the manifest hash triple.
- **Known quirk:** `script_path` in the manifest comes from `resolveCallingScriptPath`; in some runs it may resolve to `createRunContext.m` rather than `run_switching_canonical.m`, which is a **semantic** risk for “entry script identity” even though the hash is still “single writer.”

**Conflict risk:** **Medium** — not two writers for hash fields, but **two meanings** of “fingerprint” (manifest vs CSV name).

---

## 5. EXECUTION_STATUS

**Intended authority:** `Switching/analysis/run_switching_canonical.m` **writes** `execution_status.csv` under the run directory with columns `EXECUTION_STATUS`, `INPUT_FOUND`, `ERROR_MESSAGE`, `N_T`, `MAIN_RESULT_SUMMARY` (including PARTIAL rows and final status). Failure paths also target `execution_status.csv`.

**Duplication points:**

- **Validator:** `tools/validate_matlab_runnable.ps1` uses **regex** on the **script source** to infer that a runnable “should” mention `execution_status` and related patterns. It does **not** read the produced CSV. Static expectation vs runtime file can diverge.
- **Control scan:** Sets `HAS_EXECUTION_STATUS` from **file existence** only; does not parse `EXECUTION_STATUS` cell values.

**Conflict risk:** **LOW** — one writer for the artifact content on the canonical runner path; other tools **read** differently (text vs existence vs semantics).

---

## Control scan classification

**Classification: PARTIALLY DEFINING (dangerous).**

- **PURE REPORTING (good):** Reading `PARENT_RUN_ID` from existing bundle CSV keys; `HAS_EXECUTION_STATUS` from `Test-Path`; violation line scan for repo-root `tables`/`reports` patterns.
- **PARTIALLY DEFINING:** `INPUT_SOURCE` column and `IS_CANONICAL` / drift rules use **policy constants**, **regex on run folder names**, and **fallback ordering** not defined as a single field in `run_manifest.json`. That introduces **new observability truth** that is **not** identical to manifest SSOT for the same English names.
- **DEFINING NEW TRUTH (critical issue):** Would be if the scan were treated as **authoritative** for identity or fingerprint over `run_manifest.json` or folder naming without reconciliation. The scan does **not** replace manifest hash fields, but the **`run_fingerprint.csv` name** plus **`INPUT_SOURCE`** heuristics can be mistaken for infrastructure SSOT.

---

## Final verdict row

See `tables/infra_duplication_status.csv`:

- **INFRA_SINGLE_SOURCE_OF_TRUTH** = **NO**
- **FINGERPRINT_SOURCE_IS_UNIQUE** = **YES** (for hash fields in JSON)
- **PARENT_SOURCE_IS_UNIQUE** = **NO**
- **INPUT_SOURCE_IS_UNIQUE** = **NO**
- **EXECUTION_STATUS_SOURCE_IS_UNIQUE** = **YES** (writer uniqueness for CSV content on canonical runner)
- **CONTROL_SCAN_IS_SAFE** = **NO**
- **INFRA_AT_RISK** = **YES**

---

*End of audit.*
