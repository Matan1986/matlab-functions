# Structural alignment plan

Date: 2026-03-28
Scope: Surgical repository restructuring plan only. No refactor logic changes, no execution contract changes.
Evidence base: `reports/system_formalization_audit.md`, `reports/root_chaos_map.md`, `reports/repo_structure_recommendation.md`, `docs/repo_context_infra.md`, `docs/repo_map.md`, `docs/scientific_system_map.md`, plus live file-system checks (`95` root files; duplicate path verification).

## 1. Current Reality Summary

### Root chaos summary

- Root files: `95` (confirmed live and in `reports/root_chaos_map.md`).
- Root extension profile from audit: `39 .txt`, `35 .m`, `6 .log`, `5 .md`, remaining mixed (`.mat`, `.csv`, `.ps1`, `.py`, `.tmp`, etc.).
- Root role mix is dominated by temporary/debug artifacts, with transitional launch wrappers and a smaller set of canonical infra files.

### Canonical system (execution + infra)

- Canonical MATLAB execution entrypoint is `tools/run_matlab_safe.bat` with preflight validation through `tools/validate_matlab_runnable.ps1`.
- Run contract depends on `run_dir_pointer.txt` and run-scoped artifacts under `results/<experiment>/runs/run_<timestamp>_<label>/`.
- `Aging/utils/createRunContext.m` is the canonical run factory used by runnable scripts in strict mode.
- `docs/infrastructure_laws.md`, `docs/repo_execution_rules.md`, and `docs/run_system.md` define normative behavior; `docs/repo_context_infra.md` documents implementation deltas.

### Key risks

- Duplication risk: root wrappers duplicated under `runs/experimental/`; root scientific script duplicates in `analysis/` and `Switching/analysis/`.
- Misplacement risk: root contains scientific notes, tests, and inventories that belong in `docs/`, `tests/`, `analysis/`, or experiment folders.
- Transitional wrapper risk: root `run_*_wrapper.m` files are operationally useful but structurally noisy and easy to drift.
- Log/temp pollution: root is crowded by probe/log/status scratch files, increasing accidental-use risk.

## 2. Canonical Zones (explicit)

### Zone definitions

- `CORE_INFRA`: execution wrappers, validators, run helpers, environment/bootstrap scripts.
- `PHYSICS_ANALYSIS`: cross-experiment scientific analysis and query/evidence layers.
- `EXPERIMENT_RUNS`: experiment-specific code trees and runnable scientific pipelines.
- `RESULTS`: run outputs, manifests, tables/reports tied to run directories.
- `DOCUMENTATION`: policy, architecture, scientific notes, inventories for humans.
- `LEGACY`: historical/deprecated versioned trees retained for reproducibility.
- `SCRATCH / TEMP`: logs, probes, temp files, local runtime prefs, quarantine/work scratch.

### Current repo folders -> target zones

| Current folder(s) | Target zone | Notes |
| --- | --- | --- |
| `tools/`, `runs/`, `scripts/`, `.github/`, `.vscode/`, `setup_repo.m`, `repo_state_*.m` | `CORE_INFRA` | Canonical infra surface; preserve stable execution paths. |
| `analysis/`, `claims/`, `snapshot_scientific_v3/` | `PHYSICS_ANALYSIS` | Shared science/control-plane layers. |
| `Aging/`, `Relaxation ver3/`, `Switching/` | `EXPERIMENT_RUNS` | Active canonical experiment roots. |
| `results/` | `RESULTS` | Canonical run evidence store. |
| `docs/`, `surveys/`, root canonical docs (`README.md`, `CONTRIBUTING.md`) | `DOCUMENTATION` | Human-facing specs and maps. |
| `Aging old/`, `Switching ver12/`, `General ver2/`, `Tools ver1/`, versioned historical experiment folders (`* verN` outside canonical trio) | `LEGACY` | Retain for reproducibility, isolate from active flow. |
| `logs/`, `probe_outputs/`, `tmp/`, `.tmp_test/`, `tmp_root_cleanup_quarantine/`, `.codex_tmp/`, local pref dirs (`.matlab_prefs`, `.mwhome`, etc.) | `SCRATCH / TEMP` | Non-canonical execution outputs and local runtime debris. |
| root `reports/`, root `tables/`, root `figures/` | `DOCUMENTATION` now, then `LEGACY` for non-current material | Transitional tension identified in infra laws and repo map. |

## 3. File Classification Plan

### Rules

- Goes to `LEGACY` when any of the following hold: superseded version tree, duplicate non-canonical copy, deprecated visualization stack, historical run/report corpus not required for active execution.
- Stays canonical when file participates in execution contract, validator gate, run context creation, primary docs, or active wrappers required for current entry flow.
- Ambiguous when scientific/test utility exists but root placement is wrong and no hard runtime coupling is proven.

### Decision matrix

| Class | Decision rule | Action now | Action later |
| --- | --- | --- | --- |
| Canonical-execution | Needed by wrapper/validator/run contract | Keep in place | Move only with compatibility shim + verification |
| Canonical-content but misplaced | Valid file, wrong folder | Tag for relocation | Move in Stage 3 |
| Duplicate non-canonical | Same basename/functionality as canonical target | Keep canonical, freeze copy | Move copy to `legacy/` then delete later |
| Scratch/log/temp | Probe/log/ephemeral artifacts | Ignore from code alignment | Sweep in Stage 2 |
| Ambiguous science/test | Valuable but unclear ownership | Tag + owner assignment | Relocate after ownership decision |

## 4. Duplicate Resolution Plan

| Duplicate cluster | Canonical file/location | Non-canonical copy/copies | Planned action |
| --- | --- | --- | --- |
| Wrapper mirror set (13 files): `run_a1_integral_consistency_wrapper.m`, `run_a1_mobility_wrapper.m`, `run_activation_signature_wrapper.m`, `run_aging_clock_ratio_temperature_scaling_wrapper.m`, `run_amplitude_response_wrapper.m`, `run_barrier_distribution_wrapper.m`, `run_creep_activation_scaling_wrapper.m`, `run_geometry_deformation_wrapper.m`, `run_relaxation_temperature_scaling_wrapper.m`, `run_ridge_susceptibility_analysis_wrapper.m`, `run_ridge_temperature_susceptibility_wrapper.m`, `run_switching_creep_barrier_analysis_wrapper.m`, `run_switching_creep_scaling_wrapper.m` | Root versions remain active launch surface during transition | `runs/experimental/<same_name>.m` mirrors | Keep root versions now; mark `runs/experimental` copies as `LEGACY_CANDIDATE`; move to `legacy/runs_experimental_mirrors/` in Stage 2; delete only after call-site audit |
| `run_kappa1_pt_vs_speak_test.m` | `analysis/run_kappa1_pt_vs_speak_test.m` | root `run_kappa1_pt_vs_speak_test.m` | Keep analysis version canonical; move root copy to `legacy/root_dupes/` in Stage 2; delete later after one clean run using canonical path |
| `run_minimal_canonical.m` | root `run_minimal_canonical.m` (infra validation harness role) | `Switching/analysis/run_minimal_canonical.m` | Keep root canonical; classify switching copy as legacy/test artifact candidate; move only after confirming it is not referenced by Switching docs/scripts |
| Probe output duplicates | `probe_outputs/probe_pwd.txt`, `probe_outputs/probe_success.txt` | root `probe_pwd.txt`, root `probe_success.txt` | Keep `probe_outputs/` versions; sweep root copies in Stage 2 |
| Basename duplicates that are intentional (`README.md`, `.gitattributes`) | Root docs / root VCS file | module or third-party local copies | Keep as-is; no cleanup action |

## 5. Root Cleanup Plan (critical)

Coverage target: all `95` root files are bucketed.

### KEEP (canonical)

- `.gitattributes`, `.gitignore`, `README.md`, `CONTRIBUTING.md`, `matlab-functions.code-workspace`
- `setup_repo.m`, `repo_state_generator.m`, `repo_state_validator.m`, `run_dir_pointer.txt`, `run_minimal_canonical.m`
- `run_a1_integral_consistency_wrapper.m`, `run_a1_mobility_wrapper.m`, `run_activation_signature_wrapper.m`, `run_aging_clock_ratio_temperature_scaling_wrapper.m`, `run_amplitude_response_wrapper.m`, `run_barrier_distribution_wrapper.m`, `run_creep_activation_scaling_wrapper.m`, `run_geometry_deformation_wrapper.m`, `run_relaxation_temperature_scaling_wrapper.m`, `run_ridge_susceptibility_analysis_wrapper.m`, `run_ridge_temperature_susceptibility_wrapper.m`, `run_switching_creep_barrier_analysis_wrapper.m`, `run_switching_creep_scaling_wrapper.m`, `run_switching_threshold_residual_structure_wrapper.m`, `run_switching_width_roughness_competition_wrapper.m`, `run_x_vs_r_predictor_comparison_wrapper.m`

Count: `26`

### MOVE -> target folder

| Root file | Target folder |
| --- | --- |
| `GenerateREADME.m` | `tools/dev/` |
| `kappa_physical_interpretation.md` | `docs/analysis_notes/` |
| `phi_avalanche_mode_test.md` | `docs/analysis_notes/` |
| `phi_memory_mode_test.md` | `docs/analysis_notes/` |
| `run_kappa2_robust_audit.m` | `analysis/audits/` |
| `run_threshold_distribution_model.m` | `analysis/models/` |
| `svd_projection_test.m` | `tests/scientific/` |
| `temp_run_inventory.ps1` | `scripts/audit/` |
| `test_execution_probe.m` | `tests/probes/` |
| `test_probe.m` | `tests/probes/` |
| `test_probe_checks.m` | `tests/probes/` |
| `test_run_wrapper.m` | `tests/infrastructure/` |
| `test_threshold_init.m` | `tests/scientific/` |
| `x_necessity_and_pairing_tests.m` | `tests/scientific/` |
| `script_asset_inventory.csv` | `docs/inventory/` |
| `kappa2_phen_inputs.mat` | `analysis/audits/data/` |

Count: `16`

### LEGACY_CANDIDATE

- `run_kappa1_pt_vs_speak_test.m` (root duplicate; canonical in `analysis/`)
- `_loocv_run.m`, `_loocv_tmp.py`
- `tmp_a1_observable_analysis.m`, `tmp_determinism_check.m`, `tmp_runner.m`
- `test_save.mat`

Count: `7`

### IGNORE (logs/temp)

- `_23c_log.txt`, `_23cout.txt`, `_agent22b_diary.txt`, `_agent22b_matlab_log.txt`, `_kappa1_pt_vs_speak_debug.txt`
- `_matlab_agent23a.log`, `_matlab_agent23a.log.err`, `_matlab_debug_hello.txt`, `_matlab_direct_probe.txt`, `_matlab_direct_stderr.txt`, `_matlab_direct_stdout.txt`, `_matlab_ok.txt`, `_matlab_touch.txt`
- `agent20a_matlab.log`, `codex_write_test.tmp`
- `kappa2_audit_status.txt`, `kappa2_build_error.log`, `kappa2_build_status.txt`, `kappa2_columns_debug.txt`, `kappa2_phen_audit_inputs_status.txt`
- `matlab_agent19e_log.txt`, `matlab_audit_log.txt`, `matlab_batch_debug.log`, `matlab_debug_output.txt`, `matlab_direct_debug.txt`, `matlab_direct_probe.txt`, `matlab_direct_short_probe.txt`, `matlab_error.log`, `matlab_out_test.txt`, `matlab_out_test_abs.txt`, `matlab_probe.txt`, `matlab_probe_only_marker.txt`, `matlab_probe_out.txt`, `matlab_pwd_probe.txt`, `matlab_r_debug.log`, `matlab_script_exist_probe.txt`, `matlab_test_log.txt`, `matlab_test_log2.txt`, `matlab_tiedrank_exist_probe.txt`, `matlab_wrapper_debug_output.txt`
- `probe_path_check.txt`, `probe_pwd.txt`, `probe_success.txt`, `safe_wrapper_test.txt`, `wrapper_pwd.txt`, `wrapper_test.txt`

Count: `46`

## 6. Execution Safety Constraints

### Hard no-move set during cleanup stages 1-3

- `tools/run_matlab_safe.bat`
- `tools/validate_matlab_runnable.ps1`
- `Aging/utils/createRunContext.m`
- Root wrapper entry scripts currently used by workflow (`run_*_wrapper.m` list in section 5 KEEP)

### Must not break

- `run_dir_pointer.txt` producer/consumer flow (script writes absolute run dir; wrapper reads and validates it).
- Results layout contract under `results/<experiment>/runs/run_<timestamp>_<label>/`.
- Wrapper post-run checks for `execution_status.csv`, `run_manifest.json`, and run-local CSV/MD artifacts.
- Fingerprint and status side effects (`runs/fingerprints/`, `tables/run_status.csv`).

### Additional safety gate

- Any planned move is blocked if file is referenced by wrapper, validator, or runnable entry scripts (`rg`/path-audit required before execution stage agent moves files).

## 7. Staged Migration Plan

### Stage 1 - Safe tagging (no move)

- Create a classification ledger (`reports/structural_alignment_inventory.csv`) mapping each root file to KEEP/MOVE/LEGACY/IGNORE.
- Annotate duplicate clusters and intended canonical owner file.
- Add migration checklist with preconditions (reference scan, backup branch, dry-run path map).

Exit criteria:

- 95/95 root files classified.
- Duplicate clusters have canonical owner + intended action.
- No filesystem changes.

### Stage 2 - Soft relocation

- Move only root logs/probes/temp artifacts to `scratch/` (or existing `logs/` and `probe_outputs/`) and move non-canonical duplicate mirrors to a legacy quarantine path.
- Do not move any wrapper, validator, run-context factory, or execution-critical root scripts.
- Keep reversibility: every move logged in one manifest file.

Exit criteria:

- Root temp/log footprint materially reduced.
- Duplicate non-canonical mirrors no longer at active call sites.
- Wrapper smoke run still passes.

### Stage 3 - Canonical alignment

- Move misplaced but valid code/docs from root into target canonical folders listed in section 5.
- Update references only where required for path resolution.
- Execute validation after each move batch (wrapper validation + representative run).

Exit criteria:

- Root contains only canonical infra entry files and minimal docs.
- Relocated files are discoverable under canonical zones.
- Execution contract unchanged.

### Stage 4 - Legacy isolation

- Create `legacy/` with structured subfolders (`legacy/root_dupes/`, `legacy/old_modules/`, `legacy/reports_archive/`, `legacy/scratch_archive/`).
- Move all approved non-canonical/historical artifacts there.
- Keep a legacy index markdown with provenance and rollback paths.

Exit criteria:

- Legacy material isolated from canonical navigation paths.
- No required runtime dependency points into legacy.

## 8. Risk Assessment

| Stage | Risk | Why | Control |
| --- | --- | --- | --- |
| Stage 1 - Safe tagging | LOW | Metadata/classification only | No file changes |
| Stage 2 - Soft relocation | MEDIUM | Temp files can still be implicitly read by ad-hoc scripts (example: `kappa2_columns_debug.txt`) | Move in small batches; run reference scan and wrapper smoke check after each batch |
| Stage 3 - Canonical alignment | HIGH | Path-sensitive scientific scripts and ad-hoc calls may break when moved | Pre-move grep/audit, compatibility shims where needed, batch validation runs |
| Stage 4 - Legacy isolation | MEDIUM | Hidden dependencies on historical paths may surface late | Legacy index + rollback map + post-move run verification |

## 9. Expected End-State Structure

```text
repo/
  core/ (logical)
    tools/
    runs/
    scripts/
  analysis/
  experiments/ (logical)
    Aging/
    Relaxation ver3/
    Switching/
  results/
  docs/
  legacy/
  scratch/
```

Current to target mapping summary:

- Current canonical infra (`tools/`, `runs/`, `scripts/`, root execution anchors) remains active and stable.
- Current shared science (`analysis/`, `claims/`, `snapshot_scientific_v3/`) stays in active analysis zone.
- Root misplaced analysis/tests/docs move under `analysis/`, `tests/`, and `docs/`.
- Historical version trees and duplicate mirrors move behind `legacy/` boundary.
- Ephemeral runtime debris moves to `scratch/`/`logs/`/`probe_outputs/` and no longer pollutes root.

## VERDICTS

- `CLEANUP_SAFE_TO_EXECUTE=YES`
- `ROOT_CLEANUP_FEASIBLE=YES`
- `DUPLICATES_RESOLVABLE=YES`
- `LEGACY_ISOLATION_POSSIBLE=YES`
- `EXECUTION_RISK=MEDIUM`

Rationale for overall risk level: the cleanup is feasible and safe when staged, but path-coupled scientific scripts and transitional wrappers require disciplined validation gates to avoid non-obvious breakage.
