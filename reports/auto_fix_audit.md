# Auto-Fix Audit (Target by PRECHECK Fails)

Date: 2026-03-31

## Scope
- Source of truth: tables/wrapper_soft_gate_status.csv
- Filter: PRECHECK_FAILED = YES
- Target count: 1
- Targeted paths only; no repository-wide blind scan performed.

## Rules Followed
- Followed docs/repo_execution_rules.md runnable contract boundaries.
- Structural runnable compliance only.
- No MATLAB execution.
- No wrapper execution.
- No validator execution.
- No scientific/model/physics logic edits.
- Safety rule applied: SKIP > WRONG FIX.

## Allowed vs Forbidden
- Allowed in this mode: classification, minimal structural patching when safe.
- Forbidden: changing formulas, observables semantics, PT/Phi/kappa logic, analysis behavior.

## Per-Script Classification
1. tools/export_observables.m
- Precheck fail reasons: missing execution_status.csv; no .md output; missing createRunContext
- Classification: INVALID_TARGET
- Why: file is a reusable helper function (`function outPath = export_observables(...)`), not a runnable script entrypoint; precheck runnable requirements do not apply directly to helper APIs.
- Action: skipped, no patch.

## Skipped Scripts Requiring Deeper Refactor
- None.

## Explicit Safety Statements
- MATLAB was not run.
- Wrapper was not run.
- Validator was not run.
- No scientific logic was touched.
- No files were modified except audit artifacts.

## Summary
- Total scripts processed: 1
- SAFE_AUTO_FIX: 0
- MANUAL_REVIEW: 0
- ALREADY_FIXED: 0
- INVALID_TARGET: 1
- Fixed: 0
- Skipped: 1
- Manual review required: 0

## Key Failure Type Distribution (from PRECHECK rows)
- missing execution_status.csv: 1
- no .md output: 1
- missing createRunContext: 1
