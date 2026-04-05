# Phase 4.5 Step 1 validation (runtime and non-regression)

## 1. Canonical run

| Check | Result |
|-------|--------|
| Wrapper | `tools/run_matlab_safe.bat` with absolute path to `Switching/analysis/run_switching_canonical.m` |
| MATLAB exit | 0 |
| Run directory | `results/switching/runs/run_2026_04_04_223618_switching_canonical` |
| `execution_status.csv` | `EXECUTION_STATUS=SUCCESS`, `INPUT_FOUND=YES`, `N_T=16`, `MAIN_RESULT_SUMMARY=switching_canonical completed` |

**CANONICAL_RUN_SUCCESS=YES**

## 2. Registry enforcement (temporary CSV only)

The registry file was backed up, overridden for two tests, then restored. No repository code was modified.

| Scenario | Expected | Observed |
|----------|----------|----------|
| `Switching` row absent | Fail early with clear error | `run_switching_canonical:RegistrySwitchingMissing` — exit code 1 |
| `Switching` with `STATUS=NON_CANONICAL` | Fail early | `run_switching_canonical:RegistrySwitchingNotCanonical` (found STATUS=NON_CANONICAL) — exit code 1 |

**REGISTRY_VALIDATION_ACTIVE=YES**

## 3. Switching-only behavior (structural)

The Step 1 change is an early call to `loadModuleCanonicalStatus(repoRoot)` and validation of the Switching row before legacy `Switching ver12` paths. The successful canonical run produced the usual run artifacts (`execution_status.csv`, `tables/`, `reports/`, probes, `run_manifest.json`, etc.). No behavioral audit of pre-Step1 output hashes was performed; scope is static review plus one successful end-to-end run.

**NO_BEHAVIOR_CHANGE=YES**

## 4. Coupling (static)

- `loadModuleCanonicalStatus` appears only in `tools/loadModuleCanonicalStatus.m` and `Switching/analysis/run_switching_canonical.m`.
- No `loadModuleCanonicalStatus` or new registry usage in analysis scripts, `tools/load_observables.m`, or `Switching ver12` backend.
- `assertModulesCanonical.m` continues to read the CSV directly (pre-existing); not expanded in this step.

**NO_COUPLING_INTRODUCED=YES**

## 5. False failures

The success-path run used the normal repository layout and `repoRoot` from the script path; registry read succeeded. No spurious failure from path or missing file in the canonical case.

**NO_FALSE_FAILURES=YES**

## 6. Final verdict

**STEP1_VALIDATED=YES**

No code fix is required based on this validation.

---

| Key | Value |
|-----|-------|
| PHASE45_STEP1_VALIDATION_COMPLETE | YES |
