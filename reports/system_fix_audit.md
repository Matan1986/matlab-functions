# System Fix Audit

Date: 2026-03-31
Mode: Broad, surgical, safe
MATLAB execution: not performed

## What Was Fixed

1. Template repair
- File: docs/templates/matlab_run_template.m
- Converted to a pure script (no function definition).
- First executable line is clear; clc; for validator compliance.
- createRunContext usage corrected to actual API (single struct output).
- Required outputs now included by default:
  - run_dir/execution_status.csv
  - tables/template_result.csv
  - reports/report.md
  - figures/template_diagnostic.png
  - run_dir/figures_manifest.csv
- try/catch uses rethrow(ME) and does not use silent catch.
- Script writes run_dir_pointer.txt for wrapper link consistency.

2. Wrapper timeout repair
- File: tools/run_matlab_safe.bat
- Replaced hardcoded timeout with MATLAB_TIMEOUT_SECONDS environment variable.
- Default behavior is no timeout (MATLAB_TIMEOUT_SECONDS=0), allowing long runs.
- Timeout behavior remains available when MATLAB_TIMEOUT_SECONDS is set to a positive integer.
- No additional wrapper behavior was intentionally changed.

## What Was Not Touched

- No scientific analysis logic was modified.
- No physics/model computations were changed.
- No broad refactor across run_*.m scripts was performed.
- No helper library redesign was performed.
- Optional bulk script backfill was skipped to keep risk low.

## Risks Detected

1. Existing run_*.m population is heterogeneous
- Many scripts are wrappers or legacy patterns.
- Bulk auto-patching could alter behavior or assumptions.
- Action taken: skipped bulk edits intentionally.

2. Wrapper file had pre-existing drift from HEAD
- The repository already has many unrelated local changes.
- Action taken: only surgical timeout lines were updated.

## Validation Performed (No MATLAB)

- Validator check on template:
  - tools/validate_matlab_runnable.ps1 docs/templates/matlab_run_template.m
  - Result: PASS
- Wrapper sanity check for missing argument path handling:
  - tools/run_matlab_safe.bat (no args)
  - Result: expected usage error path still works
- Timeout wiring check:
  - Confirmed MATLAB_TIMEOUT_SECONDS lines in wrapper and no-timeout default behavior.

## Confirmations

- No scientific logic was changed.
- Changes are structural only.
- Fix scope was limited to template + wrapper timeout + audit/status artifacts.
