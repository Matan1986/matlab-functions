# AGING-BASELINE-TAU-SIDECAR-WRITER-01 — Baseline tau sidecar emission

**Rules:** [`docs/repo_execution_rules.md`](../../docs/repo_execution_rules.md).  
**Scope:** Implement B003-W1 machine sidecars for Dip and FM baseline tau writers only. No ratio code, no Track A edits, no `docs/` edits.

**Preflight:** `git diff --cached --name-only` was empty at task start.

---

## Summary

`Aging/analysis/aging_timescale_extraction.m` and `Aging/analysis/aging_fm_timescale_analysis.m` now call local helpers **`writeAgingBaselineTauSidecarDip`** and **`writeAgingBaselineTauSidecarFm`** immediately after saving **`tau_vs_Tp.csv`** and **`tau_FM_vs_Tp.csv`**. Each helper writes **`tau_vs_Tp_sidecar.csv`** or **`tau_FM_vs_Tp_sidecar.csv`** in the same **`tables/`** directory via existing **`save_run_table`**, using two columns **`metadata_field`** and **`value`**.

**Numerical tau logic** (`buildConsensusTau`, `buildEffectiveFmTau`, curve fits) was **not** modified. **Output column names** on the main tau tables were **not** renamed.

---

## Output contract

See **`tables/aging/aging_baseline_tau_sidecar_writer_01_output_contract.csv`**.

---

## Validation

Full **`tools/run_matlab_safe.bat`** execution of the tau pipelines was **not** performed (consolidation dataset presence not verified for an end-to-end run). **`matlab -batch`** **`checkcode`** was run on both modified scripts (exit code 0; reports reference older lines, not the new sidecar helpers). See **`tables/aging/aging_baseline_tau_sidecar_writer_01_validation.csv`**.

---

## Status

Machine-readable keys: **`tables/aging/aging_baseline_tau_sidecar_writer_01_status.csv`**.

---

## Cross-module

No Switching, Relaxation, Maintenance/INFRA, or MT changes.
