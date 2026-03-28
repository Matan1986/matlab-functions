# Root chaos map (structural diagnosis)

**Generated:** 2026-03-28  
**Scope:** Repository root `C:\Dev\matlab-functions` — files only (not subfolders).  
**Method:** Directory listing, extension counts, spot reads of representative files, cross-path search for duplicate basenames, alignment with `docs/repo_map.md`, `docs/repo_consolidation_plan.md`, and `docs/infrastructure_laws.md`.  
**Non-goals:** No moves, renames, or code changes; this file is evidence-based narrative, not cleanup.

---

## A. Root summary

### Counts

| Metric | Value |
| --- | ---: |
| **Total files in repo root** | **95** |

### Breakdown by extension (type)

| Extension / kind | Count |
| --- | ---: |
| `.txt` | 39 |
| `.m` | 35 |
| `.log` | 6 |
| `.md` | 5 |
| `.mat` | 2 |
| `.csv` | 1 |
| `.ps1` | 1 |
| `.py` | 1 |
| `.err` | 1 |
| `.tmp` | 1 |
| `.code-workspace` | 1 |
| `.gitignore` (file) | 1 |
| `.gitattributes` (file) | 1 |

### Role mix (high-level, non-exclusive)

| Role | Approx. count | Evidence |
| --- | ---: | --- |
| **Execution / launch** | ~20 | `run_*` at root (16 `*_wrapper.m` + 4 other `run_*.m`) |
| **Scientific / analysis** | ~5–8 | e.g. `run_threshold_distribution_model.m` (uses `createRunContext`), `run_kappa2_robust_audit.m`, `svd_projection_test.m`, `x_necessity_and_pairing_tests.m`; several `tmp_*` / `test_*` blur the line |
| **Temporary / debug / probe** | ~45+ | Leading `_`, `matlab_*`, `probe_*`, `tmp_*`, `test_*`, `agent*`, `codex_*`, many `.txt` logs |
| **Unknown / mixed** | ~10 | Underscore-prefixed experiments (`_loocv_run.m`), inventory vs. science (`script_asset_inventory.csv`) |

### Breakdown by category (classification scheme)

Categories are not mutually exclusive where noted (e.g. DUPLICATE + INFRA).

| Category | Count (approx.) | Notes |
| --- | ---: | --- |
| **INFRA** | ~28 | Wrappers, `setup_repo.m`, `repo_state_*`, `GenerateREADME.m`, workspace, git metadata, `run_dir_pointer.txt`, `temp_run_inventory.ps1` |
| **SCIENTIFIC** | ~6–10 | Non-wrapper `run_*.m` and explicit tests; some overlap with “experimental” |
| **DATA** | 3 | `script_asset_inventory.csv`, `kappa2_phen_inputs.mat`, `test_save.mat` |
| **DOCUMENTATION** | 5 | `README.md`, `CONTRIBUTING.md`, root `*.md` notes |
| **TEMP / DEBUG** | ~48 | Dominant share of `.txt` and logs |
| **DUPLICATE / REDUNDANT** | 1 confirmed + patterns | See section C |
| **UNKNOWN** | ~5 | Ambiguous one-offs |

---

## B. Detailed table (all root files)

| file | type | category | confidence | notes |
| --- | --- | --- | --- | --- |
| `.gitattributes` | git | INFRA | high | VCS metadata |
| `.gitignore` | git | INFRA | high | VCS metadata |
| `_23c_log.txt` | .txt | TEMP/DEBUG | high | Agent/session log |
| `_23cout.txt` | .txt | TEMP/DEBUG | high | Captured stdout |
| `_agent22b_diary.txt` | .txt | TEMP/DEBUG | high | Agent diary |
| `_agent22b_matlab_log.txt` | .txt | TEMP/DEBUG | high | MATLAB log |
| `_kappa1_pt_vs_speak_debug.txt` | .txt | TEMP/DEBUG | high | Named debug for kappa1 test |
| `_loocv_run.m` | .m | TEMP/DEBUG | medium | Leading underscore; experimental LOOCV |
| `_loocv_tmp.py` | .py | TEMP/DEBUG | high | Scratch helper |
| `_matlab_agent23a.log` | .log | TEMP/DEBUG | high | Session log |
| `_matlab_agent23a.log.err` | .err | TEMP/DEBUG | high | Error stream |
| `_matlab_debug_hello.txt` | .txt | TEMP/DEBUG | high | Probe output |
| `_matlab_direct_probe.txt` | .txt | TEMP/DEBUG | high | Probe output |
| `_matlab_direct_stderr.txt` | .txt | TEMP/DEBUG | high | Probe stderr |
| `_matlab_direct_stdout.txt` | .txt | TEMP/DEBUG | high | Probe stdout |
| `_matlab_ok.txt` | .txt | TEMP/DEBUG | high | Probe marker |
| `_matlab_touch.txt` | .txt | TEMP/DEBUG | high | Probe marker |
| `agent20a_matlab.log` | .log | TEMP/DEBUG | high | Agent log |
| `codex_write_test.tmp` | .tmp | TEMP/DEBUG | high | Scratch |
| `CONTRIBUTING.md` | .md | DOCUMENTATION | high | Contributor guide |
| `GenerateREADME.m` | .m | INFRA | high | Scans modules; generates README content |
| `kappa_physical_interpretation.md` | .md | DOCUMENTATION | medium | Science notes at root (also referenced by audits) |
| `kappa2_audit_status.txt` | .txt | TEMP/DEBUG | medium | Status sidecar for kappa2 audit flow |
| `kappa2_build_error.log` | .log | TEMP/DEBUG | high | Build log |
| `kappa2_build_status.txt` | .txt | TEMP/DEBUG | medium | Status |
| `kappa2_columns_debug.txt` | .txt | TEMP/DEBUG | high | Consumed by `run_kappa2_robust_audit.m` (hard-coded path) |
| `kappa2_phen_audit_inputs_status.txt` | .txt | TEMP/DEBUG | medium | Status |
| `kappa2_phen_inputs.mat` | .mat | DATA | high | Input bundle for audit |
| `matlab_agent19e_log.txt` | .txt | TEMP/DEBUG | high | Agent log |
| `matlab_audit_log.txt` | .txt | TEMP/DEBUG | high | Audit log |
| `matlab_batch_debug.log` | .log | TEMP/DEBUG | high | Debug log |
| `matlab_debug_output.txt` | .txt | TEMP/DEBUG | high | Debug |
| `matlab_direct_debug.txt` | .txt | TEMP/DEBUG | high | Overlaps naming with `_matlab_direct_*` cluster |
| `matlab_direct_probe.txt` | .txt | TEMP/DEBUG | high | Probe cluster |
| `matlab_direct_short_probe.txt` | .txt | TEMP/DEBUG | high | Probe cluster |
| `matlab_error.log` | .log | TEMP/DEBUG | high | Error log |
| `matlab_out_test.txt` | .txt | TEMP/DEBUG | high | Test output |
| `matlab_out_test_abs.txt` | .txt | TEMP/DEBUG | high | Test output |
| `matlab_probe.txt` | .txt | TEMP/DEBUG | high | Probe cluster |
| `matlab_probe_only_marker.txt` | .txt | TEMP/DEBUG | high | Probe |
| `matlab_probe_out.txt` | .txt | TEMP/DEBUG | high | Probe |
| `matlab_pwd_probe.txt` | .txt | TEMP/DEBUG | high | Probe |
| `matlab_r_debug.log` | .log | TEMP/DEBUG | high | Debug |
| `matlab_script_exist_probe.txt` | .txt | TEMP/DEBUG | high | Probe |
| `matlab_test_log.txt` | .txt | TEMP/DEBUG | high | Test log |
| `matlab_test_log2.txt` | .txt | TEMP/DEBUG | high | Test log |
| `matlab_tiedrank_exist_probe.txt` | .txt | TEMP/DEBUG | high | Probe |
| `matlab_wrapper_debug_output.txt` | .txt | TEMP/DEBUG | high | Wrapper debug |
| `matlab-functions.code-workspace` | workspace | INFRA | high | Editor workspace |
| `phi_avalanche_mode_test.md` | .md | DOCUMENTATION | medium | Science note |
| `phi_memory_mode_test.md` | .md | DOCUMENTATION | medium | Science note |
| `probe_path_check.txt` | .txt | TEMP/DEBUG | high | Probe |
| `probe_pwd.txt` | .txt | TEMP/DEBUG | high | Probe |
| `probe_success.txt` | .txt | TEMP/DEBUG | high | Probe |
| `README.md` | .md | DOCUMENTATION | high | Primary readme |
| `repo_state_generator.m` | .m | INFRA | high | Updates `docs/repo_state.json` observable defs |
| `repo_state_validator.m` | .m | INFRA | high | Validates repo state vs. runs |
| `run_a1_integral_consistency_wrapper.m` | .m | INFRA | high | Thin launcher; delegates into repo |
| `run_a1_mobility_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_activation_signature_wrapper.m` | .m | INFRA | high | Adds paths; calls `analysis` |
| `run_aging_clock_ratio_temperature_scaling_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_amplitude_response_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_barrier_distribution_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_creep_activation_scaling_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_dir_pointer.txt` | .txt | INFRA | high | Documented post-run pointer (`docs/repo_map.md`) |
| `run_geometry_deformation_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_kappa1_pt_vs_speak_test.m` | .m | DUPLICATE + SCIENTIFIC | high | **Same basename as `analysis/run_kappa1_pt_vs_speak_test.m`** (see C) |
| `run_kappa2_robust_audit.m` | .m | SCIENTIFIC | medium | Large audit script; hard-codes root `kappa2_*` and `tables/` paths |
| `run_minimal_canonical.m` | .m | INFRA | high | Minimal `clear; clc` run; writes `tables/` + `reports/` |
| `run_relaxation_temperature_scaling_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_ridge_susceptibility_analysis_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_ridge_temperature_susceptibility_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_switching_creep_barrier_analysis_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_switching_creep_scaling_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_switching_threshold_residual_structure_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_switching_width_roughness_competition_wrapper.m` | .m | INFRA | high | Thin launcher |
| `run_threshold_distribution_model.m` | .m | SCIENTIFIC | high | Uses `createRunContext`; science entry |
| `run_x_vs_r_predictor_comparison_wrapper.m` | .m | INFRA | high | Thin launcher |
| `safe_wrapper_test.txt` | .txt | TEMP/DEBUG | high | Test artifact |
| `script_asset_inventory.csv` | .csv | DATA | medium | Registry-style inventory (787+ rows); not raw experiment CSV |
| `setup_repo.m` | .m | INFRA | high | `addpath(genpath)` for repo |
| `svd_projection_test.m` | .m | SCIENTIFIC | medium | Standalone test/analysis |
| `temp_run_inventory.ps1` | .ps1 | INFRA | medium | Inventory automation |
| `test_execution_probe.m` | .m | TEMP/DEBUG | high | Test/probe |
| `test_probe.m` | .m | TEMP/DEBUG | high | Test/probe |
| `test_probe_checks.m` | .m | TEMP/DEBUG | high | Test/probe |
| `test_run_wrapper.m` | .m | TEMP/DEBUG | medium | Wrapper test harness |
| `test_save.mat` | .mat | DATA | high | Small test artifact |
| `test_threshold_init.m` | .m | TEMP/DEBUG | medium | Test |
| `tmp_a1_observable_analysis.m` | .m | TEMP/DEBUG | high | Prefix `tmp_` |
| `tmp_determinism_check.m` | .m | TEMP/DEBUG | high | Scratch |
| `tmp_runner.m` | .m | TEMP/DEBUG | high | Scratch |
| `wrapper_pwd.txt` | .txt | TEMP/DEBUG | high | Wrapper probe |
| `wrapper_test.txt` | .txt | TEMP/DEBUG | high | Test |
| `x_necessity_and_pairing_tests.m` | .m | SCIENTIFIC | medium | Standalone tests |

---

## C. Duplicate / redundant patterns

### Confirmed duplicate basename (repo-wide)

| Basename | Locations | Risk |
| --- | --- | --- |
| `run_kappa1_pt_vs_speak_test.m` | Repo root **and** `analysis/run_kappa1_pt_vs_speak_test.m` | MATLAB path / “which file ran” ambiguity if both are on path |

*Full-tree duplicate scan for all 95 names was not completed (expensive on this tree); the above is verified by search.*

### Clusters (same role, different names — maintenance drag)

1. **MATLAB probe / debug `.txt`** — Many files sharing `matlab_*`, `probe_*`, `_matlab_*`, `wrapper_*` prefixes; overlapping purpose (session diagnostics).
2. **Kappa2 audit coupling** — `kappa2_*` text/log/mat at root alongside `run_kappa2_robust_audit.m`; script source reads/writes these paths explicitly (not run-folder scoped).
3. **16× `run_*_wrapper.m`** — Same structural role (batch entry, `addpath`, delegate); documented as transitional vs. `runs/` placement (`docs/repo_consolidation_plan.md`).

### Naming patterns suggesting version / experiment sprawl (elsewhere in repo)

- Multiple `Switching` vs `Switching ver12`, `Aging` vs `Aging old`, many `* verN/` top-level packages — not root files, but explains why root wrappers proliferate (convenience entrypoints).

---

## D. Misplacement report (conceptual targets only)

No files were moved. Suggested **high-level** homes if the repo ever consolidates:

| Root item pattern | Issue | Suggested direction (maps to existing ideas) |
| --- | --- | --- |
| `*_probe.txt`, `matlab_*debug*`, `_matlab_*`, `agent*.log` | Noise in root; repo already has `logs/`, `probe_outputs/` | **Conceptually:** `logs/` or `probe_outputs/` (per `docs/repo_map.md` “supporting” zones) |
| `kappa2_*` root artifacts | Couple scientific audit to repo root | **Conceptually:** under `results/<experiment>/runs/...` or `tables/` only, per `docs/infrastructure_laws.md` global-output rules |
| `run_*_wrapper.m` (16 files) | Tension with `repository_structure.md` / `runs/` | **Conceptually:** `runs/` shims (already noted in `docs/repo_consolidation_plan.md`) |
| `tmp_*`, `test_*` scratch `.m` | Clutter; risk of accidental execution | **Conceptually:** `tests/` or a scratch area — repo already has `tests/` at top level |
| Root `phi_*.md`, `kappa_physical_interpretation.md` | Valid notes but scatter documentation | **Conceptually:** `docs/analysis_notes/` or similar (repo already growing `docs/` trees) |

---

## E. Canonical candidates (root)

| File / pattern | Why “canonical” or “stable” |
| --- | --- |
| `README.md`, `CONTRIBUTING.md` | Standard entry and contribution docs |
| `setup_repo.m` | Explicit one-shot path setup for MATLAB |
| `repo_state_generator.m`, `repo_state_validator.m` | Tie to `docs/repo_state.json` — registry workflow |
| `run_dir_pointer.txt` | Named in `docs/repo_map.md` as wrapper contract output |
| `run_minimal_canonical.m` | Minimal runnable aligned with execution-report pattern (writes under `tables/` / `reports/`) |
| 16× `run_*_wrapper.m` | **Transitional but primary launcher surface** for batch work (`docs/repo_map.md`, `docs/repo_consolidation_plan.md`) |

**Likely legacy / abandoned (root)**

- Underscore-prefixed logs and one-off `agent*` logs — session artifacts.
- `codex_write_test.tmp` — obvious scratch.

**Likely experimental**

- `_loocv_run.m`, `tmp_*`, many `test_probe*`, duplicate-path science scripts.

---

## F. Chaos score (0–10)

**Score: 7 / 10**

**Reasoning**

- **Density:** 95 root files is high for a scientific repo that already defines canonical zones (`results/`, `tools/`, `docs/`).
- **Signal vs noise:** A large fraction are `.txt` logs/probes (~40+) — low semantic value at root but high visual clutter.
- **Structure exists elsewhere:** `docs/repo_map.md` and `docs/infrastructure_laws.md` describe a coherent architecture; chaos is **localized to root**, not total anarchy.
- **Ownership:** Clear INFRA and DOCUMENTATION anchors exist; ambiguity clusters around **duplicate script name**, **wrapper proliferation**, and **kappa2 root coupling**.

---

## G. Directory structure quality (brief)

| Area | Assessment |
| --- | --- |
| **`docs/`** | Strong normative layer (`repo_execution_rules.md`, `infrastructure_laws.md`, `repo_map.md`). |
| **`tools/`** | Canonical execution wrapper (`run_matlab_safe.bat`) — not in root (good separation). |
| **`results/`** | Canonical run root per laws; root clutter does not mean runs are disorganized. |
| **`analysis/`, `Switching/`, `Aging/`, `Relaxation ver3/`** | Heavy but purposeful; many `run_*.m` — “overloaded” by file count, not absence of structure. |
| **Parallel names** | `Switching` vs `Switching ver12`, `tools` vs `Tools ver1` — duplication of *concepts* at top level increases navigation cost. |
| **Ignored structure** | Root ignores existing folders (`logs/`, `probe_outputs/`, `tmp/`) for many artifacts that match those roles. |

---

## VERDICTS

| Flag | Value |
| --- | --- |
| **ROOT_IS_CLEAN** | **NO** |
| **CANONICAL_STRUCTURE_EXISTS** | **YES** |
| **DUPLICATION_PRESENT** | **YES** |
| **MISPLACEMENT_SEVERE** | **YES** |
| **RESTRUCTURE_NEEDED** | **YES** (conceptual consolidation already acknowledged in docs; not an emergency refactor) |

---

## Related documents

- `docs/repo_map.md` — canonical vs legacy zones  
- `docs/repo_consolidation_plan.md` — entrypoint inventory, transitional wrappers  
- `docs/infrastructure_laws.md` — run roots, global outputs policy  
